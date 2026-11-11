"""Canlı GitHub istemcisi (GraphQL API). GitHubSource arayüzünü uygular."""
import time
from collections.abc import Iterator
from datetime import datetime, timezone

import httpx

from app.sync.source import CommitData, Profile, RepoData, RequestStat

GRAPHQL_URL = "https://api.github.com/graphql"
RETRY_STATUSES = {502, 503, 504}  # GitHub büyük sorgularda ara sıra 502 verir
MAX_ATTEMPTS = 3

# Repo alanları birden fazla sorguda lazım; GraphQL "fragment" ile bir kez yazılır.
REPO_FIELDS = """
fragment RepoFields on Repository {
  id name isFork isPrivate description createdAt pushedAt
  owner { id }
  primaryLanguage { name }
  licenseInfo { spdxId }
  repositoryTopics(first: 20) { nodes { topic { name } } }
  readme1: object(expression: "HEAD:README.md") { id }
  readme2: object(expression: "HEAD:readme.md") { id }
  readme3: object(expression: "HEAD:README") { id }
  readme4: object(expression: "HEAD:README.rst") { id }
}
"""

PROFILE_QUERY = """
query { viewer { id login createdAt } rateLimit { cost remaining } }
"""

OWNED_REPOS_QUERY = REPO_FIELDS + """
query($after: String) {
  viewer {
    repositories(first: 50, after: $after, ownerAffiliations: OWNER) {
      pageInfo { hasNextPage endCursor }
      nodes { ...RepoFields }
    }
  }
  rateLimit { cost remaining }
}
"""

CONTRIBUTED_REPOS_QUERY = REPO_FIELDS + """
query($from: DateTime!, $to: DateTime!) {
  viewer {
    contributionsCollection(from: $from, to: $to) {
      commitContributionsByRepository(maxRepositories: 100) {
        repository { ...RepoFields }
      }
    }
  }
  rateLimit { cost remaining }
}
"""

COMMITS_QUERY = """
query($repo: ID!, $author: ID!, $after: String) {
  node(id: $repo) {
    ... on Repository {
      defaultBranchRef {
        target {
          ... on Commit {
            history(first: 100, after: $after, author: {id: $author}) {
              pageInfo { hasNextPage endCursor }
              nodes {
                oid authoredDate message additions deletions changedFilesIfAvailable
                authors(first: 1) { totalCount }
              }
            }
          }
        }
      }
    }
  }
  rateLimit { cost remaining }
}
"""


class GitHubError(Exception):
    pass


def _dt(value: str | None) -> datetime | None:
    # GitHub "2026-11-11T08:00:00Z" biçiminde UTC döner.
    return datetime.fromisoformat(value) if value else None


class LiveGitHubClient:
    def __init__(self, token: str):
        self.request_log: list[RequestStat] = []
        self._http = httpx.Client(
            timeout=30,
            headers={"Authorization": f"bearer {token}", "User-Agent": "devpulse-sync"},
        )

    def _query(self, kind: str, query: str, variables: dict | None = None) -> dict:
        """Tek bir GraphQL isteği: gerekirse yeniden dener, puanı ve süreyi kaydeder."""
        start = time.perf_counter()
        for attempt in range(1, MAX_ATTEMPTS + 1):
            resp = self._http.post(GRAPHQL_URL, json={"query": query, "variables": variables or {}})
            if resp.status_code in RETRY_STATUSES and attempt < MAX_ATTEMPTS:
                time.sleep(2 * attempt)
                continue
            break
        if resp.status_code == 401:
            raise GitHubError("GitHub token geçersiz ya da süresi dolmuş (401).")
        if resp.status_code != 200:
            raise GitHubError(f"GitHub {resp.status_code} döndü.")
        body = resp.json()
        if body.get("errors"):
            raise GitHubError("; ".join(e.get("message", "?") for e in body["errors"]))

        data = body["data"]
        self.request_log.append(
            RequestStat(
                kind=kind,
                cost=data["rateLimit"]["cost"],
                duration_ms=round((time.perf_counter() - start) * 1000),
            )
        )
        return data

    def fetch_profile(self) -> Profile:
        v = self._query("profile", PROFILE_QUERY)["viewer"]
        return Profile(node_id=v["id"], login=v["login"], created_at=_dt(v["createdAt"]))

    def fetch_repos(self, profile: Profile) -> list[RepoData]:
        repos: dict[str, RepoData] = {}

        # 1) Sahip olunan repolar, 50'şerli sayfalar
        after = None
        while True:
            page = self._query("repos", OWNED_REPOS_QUERY, {"after": after})["viewer"]["repositories"]
            for node in page["nodes"]:
                repos[node["id"]] = self._repo(node, profile)
            if not page["pageInfo"]["hasNextPage"]:
                break
            after = page["pageInfo"]["endCursor"]

        # 2) Başkasına ait ama commit atılmış repolar: contributionsCollection en fazla
        #    1 yıllık aralık kabul ettiği için hesap açılış yılından bugüne yıl yıl.
        now = datetime.now(timezone.utc)
        for year in range(profile.created_at.year, now.year + 1):
            start = datetime(year, 1, 1, tzinfo=timezone.utc)
            end = min(datetime(year, 12, 31, 23, 59, 59, tzinfo=timezone.utc), now)
            data = self._query(
                "contributed_repos",
                CONTRIBUTED_REPOS_QUERY,
                {"from": start.isoformat(), "to": end.isoformat()},
            )
            for item in data["viewer"]["contributionsCollection"]["commitContributionsByRepository"]:
                node = item["repository"]
                repos.setdefault(node["id"], self._repo(node, profile))

        return list(repos.values())

    def fetch_commits(self, repo: RepoData, profile: Profile) -> Iterator[CommitData]:
        after = None
        while True:
            data = self._query(
                "commits", COMMITS_QUERY, {"repo": repo.node_id, "author": profile.node_id, "after": after}
            )
            branch = (data["node"] or {}).get("defaultBranchRef")
            if not branch:  # boş repo: varsayılan dal yok
                return
            history = branch["target"]["history"]
            for c in history["nodes"]:
                yield CommitData(
                    oid=c["oid"],
                    authored_at=_dt(c["authoredDate"]),
                    message=c["message"],
                    additions=c["additions"],
                    deletions=c["deletions"],
                    changed_files=c["changedFilesIfAvailable"],
                    # Yazar adları alınmaz; yalnızca kaç yazar olduğu.
                    is_coauthored=c["authors"]["totalCount"] > 1,
                )
            if not history["pageInfo"]["hasNextPage"]:
                return
            after = history["pageInfo"]["endCursor"]

    @staticmethod
    def _repo(node: dict, profile: Profile) -> RepoData:
        return RepoData(
            node_id=node["id"],
            name=node["name"],
            is_owner=node["owner"]["id"] == profile.node_id,
            is_fork=node["isFork"],
            is_private=node["isPrivate"],
            primary_language=(node["primaryLanguage"] or {}).get("name"),
            description=node["description"],
            has_readme=any(node[k] for k in ("readme1", "readme2", "readme3", "readme4")),
            license_spdx=(node["licenseInfo"] or {}).get("spdxId"),
            topics=[t["topic"]["name"] for t in node["repositoryTopics"]["nodes"]],
            created_at=_dt(node["createdAt"]),
            pushed_at=_dt(node["pushedAt"]),
        )
