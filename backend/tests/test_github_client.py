"""Canlı GraphQL istemcisinin testleri: gerçek GitHub yerine sahte bir sunucu (MockTransport)."""
import json
from datetime import datetime, timezone

import httpx
import pytest

from app.sync import github_client
from app.sync.github_client import GitHubError, LiveGitHubClient

ME = "U_me"
OTHER = "U_someone_else"


def repo_node(node_id, name, owner, readme_key=None, license_id=None, topics=()):
    node = {
        "id": node_id, "name": name, "isFork": False, "isPrivate": False,
        "description": None, "createdAt": "2026-01-02T00:00:00Z", "pushedAt": None,
        "owner": {"id": owner},
        "primaryLanguage": {"name": "Python"},
        "licenseInfo": {"spdxId": license_id} if license_id else None,
        "repositoryTopics": {"nodes": [{"topic": {"name": t}} for t in topics]},
        "readme1": None, "readme2": None, "readme3": None, "readme4": None,
    }
    if readme_key:
        node[readme_key] = {"id": "blob"}
    return node


def commit_node(oid, authors=1):
    return {
        "oid": oid, "authoredDate": "2026-03-04T21:30:00Z", "message": f"commit {oid}",
        "additions": 1, "deletions": 0, "changedFilesIfAvailable": 1,
        "authors": {"totalCount": authors},
    }


def page(nodes, cursor=None):
    return {"pageInfo": {"hasNextPage": cursor is not None, "endCursor": cursor}, "nodes": nodes}


def history(nodes, cursor=None):
    return {"node": {"defaultBranchRef": {"target": {"history": page(nodes, cursor)}}}}


class FakeGitHub:
    """GraphQL sorgusunun içeriğine bakıp hazır cevap döner, gelen istekleri kaydeder."""

    def __init__(self):
        self.calls: list[dict] = []

    def __call__(self, request: httpx.Request) -> httpx.Response:
        body = json.loads(request.content)
        query, var = body["query"], body["variables"]
        self.calls.append({"var": var, "auth": request.headers["Authorization"]})

        if "contributionsCollection" in query:
            data = {"viewer": {"contributionsCollection": {"commitContributionsByRepository": [
                {"repository": repo_node("R_other", "katki", OTHER)},
                {"repository": repo_node("R_a", "proje-a", ME, readme_key="readme2")},  # tekrar
            ]}}}
        elif "repositories(" in query:
            if var["after"] is None:
                repos = page([repo_node("R_a", "proje-a", ME, "readme2", "MIT", ["api"])], "c1")
            else:
                repos = page([repo_node("R_empty", "bos-repo", ME)])
            data = {"viewer": {"repositories": repos}}
        elif "history(" in query:
            if var["repo"] == "R_a":
                data = history([commit_node("a1"), commit_node("a2")], "h1") if var["after"] is None \
                    else history([commit_node("a3")])
            elif var["repo"] == "R_empty":
                data = {"node": {"defaultBranchRef": None}}  # boş repo
            else:
                data = history([commit_node("o1", authors=2)])
        else:
            data = {"viewer": {"id": ME, "login": "ben", "createdAt": "2026-01-01T00:00:00Z"}}

        data["rateLimit"] = {"cost": 1, "remaining": 4999}
        return httpx.Response(200, json={"data": data})


@pytest.fixture
def fake():
    return FakeGitHub()


@pytest.fixture
def client(fake):
    return LiveGitHubClient("test-token", transport=httpx.MockTransport(fake))


def test_profile_and_auth_header(client, fake):
    profile = client.fetch_profile()
    assert (profile.node_id, profile.login) == (ME, "ben")
    assert fake.calls[0]["auth"] == "bearer test-token"


def test_repos_are_paginated_deduplicated_and_parsed(client):
    repos = {r.node_id: r for r in client.fetch_repos(client.fetch_profile())}

    # 2 sayfa sahip olunan + 1 başkasına ait; R_a iki kaynakta da var ama bir kez sayılır.
    assert set(repos) == {"R_a", "R_empty", "R_other"}
    a = repos["R_a"]
    assert a.is_owner and a.has_readme and a.license_spdx == "MIT" and a.topics == ["api"]
    assert repos["R_other"].is_owner is False
    assert repos["R_empty"].has_readme is False and repos["R_empty"].license_spdx is None


def test_commits_follow_cursor(client, fake):
    profile = client.fetch_profile()
    repos = {r.node_id: r for r in client.fetch_repos(profile)}

    commits = list(client.fetch_commits(repos["R_a"], profile))
    assert [c.oid for c in commits] == ["a1", "a2", "a3"]
    # İkinci sayfa isteği ilk sayfanın endCursor'ı ile gitmeli.
    history_calls = [c["var"] for c in fake.calls if c["var"].get("repo") == "R_a"]
    assert [v["after"] for v in history_calls] == [None, "h1"]


def test_empty_repo_and_coauthored_commit(client):
    profile = client.fetch_profile()
    repos = {r.node_id: r for r in client.fetch_repos(profile)}

    assert list(client.fetch_commits(repos["R_empty"], profile)) == []
    [other] = client.fetch_commits(repos["R_other"], profile)
    assert other.is_coauthored is True


def test_every_request_is_logged_with_cost(client):
    profile = client.fetch_profile()
    client.fetch_repos(profile)
    kinds = [s.kind for s in client.request_log]
    # profil + 2 repo sayfası + hesabın açıldığı 2026'dan bu yıla kadar yıl başına 1 katkı sorgusu
    years = datetime.now(timezone.utc).year - 2026 + 1
    assert kinds == ["profile", "repos", "repos"] + ["contributed_repos"] * years
    assert all(s.cost == 1 and s.duration_ms >= 0 for s in client.request_log)


def test_retries_on_502(monkeypatch):
    monkeypatch.setattr(github_client.time, "sleep", lambda s: None)  # testte bekleme
    responses = iter([
        httpx.Response(502),
        httpx.Response(200, json={"data": {
            "viewer": {"id": ME, "login": "ben", "createdAt": "2026-01-01T00:00:00Z"},
            "rateLimit": {"cost": 1, "remaining": 1}}}),
    ])
    client = LiveGitHubClient("t", transport=httpx.MockTransport(lambda r: next(responses)))
    assert client.fetch_profile().login == "ben"


def test_bad_token_raises_clear_error():
    client = LiveGitHubClient("t", transport=httpx.MockTransport(lambda r: httpx.Response(401)))
    with pytest.raises(GitHubError, match="401"):
        client.fetch_profile()


def test_graphql_errors_are_raised():
    reply = httpx.Response(200, json={"errors": [{"message": "Something went wrong"}]})
    client = LiveGitHubClient("t", transport=httpx.MockTransport(lambda r: reply))
    with pytest.raises(GitHubError, match="Something went wrong"):
        client.fetch_profile()
