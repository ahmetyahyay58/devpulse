"""Canlı GitHub istemcisi (GraphQL API). GitHubSource arayüzünü uygular."""
import time
from collections.abc import Iterator
from datetime import date, datetime, timedelta, timezone

import httpx

from app.sync.tools import detect_tools
from app.sync.source import (
    CalendarDay, CollaborationData, CommitData, Profile, PullRequestData, RepoData, RequestStat,
)

GRAPHQL_URL = "https://api.github.com/graphql"
RETRY_STATUSES = {502, 503, 504}  # GitHub büyük sorgularda ara sıra 502 verir
MAX_ATTEMPTS = 3

# Repo alanları birden fazla sorguda lazım; GraphQL "fragment" ile bir kez yazılır.
REPO_FIELDS = """
fragment RepoFields on Repository {
  id name isFork isPrivate isArchived description createdAt pushedAt
  owner { id }
  primaryLanguage { name }
  licenseInfo { spdxId }
  repositoryTopics(first: 20) { nodes { topic { name } } }
  readme1: object(expression: "HEAD:README.md") { ... on Blob { byteSize } }
  readme2: object(expression: "HEAD:readme.md") { ... on Blob { byteSize } }
  readme3: object(expression: "HEAD:README") { ... on Blob { byteSize } }
  readme4: object(expression: "HEAD:README.rst") { ... on Blob { byteSize } }
  languages(first: 30, orderBy: {field: SIZE, direction: DESC}) { edges { size node { name } } }
  root: object(expression: "HEAD:") { ... on Tree { entries { name } } }
  workflows: object(expression: "HEAD:.github/workflows") { ... on Tree { entries { name } } }
}
"""

PROFILE_QUERY = """
query { viewer { id login createdAt avatarUrl } rateLimit { cost remaining } }
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

CALENDAR_QUERY = """
query($from: DateTime!, $to: DateTime!) {
  viewer {
    contributionsCollection(from: $from, to: $to) {
      contributionCalendar { weeks { contributionDays { date contributionCount } } }
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
    """Mesajı kullanıcıya gösterilebilir (Türkçe) GitHub hatası."""


class TokenInvalid(GitHubError):
    """GitHub 401: token iptal edilmiş ya da süresi dolmuş; yeniden giriş gerekir."""

    def __init__(self):
        super().__init__("GitHub izni geçersiz ya da süresi dolmuş. Yeniden giriş yap.")


class RateLimited(GitHubError):
    """GitHub istek sınırı doldu. reset_at: sınırın yenileneceği an (biliniyorsa)."""

    def __init__(self, reset_at: datetime | None):
        self.reset_at = reset_at
        if reset_at:
            minutes = max(1, round((reset_at - datetime.now(timezone.utc)).total_seconds() / 60))
            when = f"yaklaşık {minutes} dakika sonra"
        else:
            when = "bir süre sonra"
        super().__init__(f"GitHub istek sınırı doldu; {when} tekrar dene.")


def _rate_limit_reset(resp: httpx.Response) -> datetime | None:
    """Sınırın ne zaman yenileneceğini başlıklardan okur; başlık yoksa None."""
    if resp.headers.get("retry-after", "").isdigit():
        return datetime.now(timezone.utc).replace(microsecond=0) + timedelta(
            seconds=int(resp.headers["retry-after"]))
    reset = resp.headers.get("x-ratelimit-reset", "")
    return datetime.fromtimestamp(int(reset), timezone.utc) if reset.isdigit() else None


def _is_rate_limited(resp: httpx.Response) -> bool:
    # REST ve GraphQL birincil sınırı: 403/429 + kalan 0. İkincil sınır: retry-after başlığı.
    if resp.status_code not in (403, 429):
        return False
    return resp.headers.get("x-ratelimit-remaining") == "0" or "retry-after" in resp.headers


def _dt(value: str | None) -> datetime | None:
    # GitHub "2026-11-11T08:00:00Z" biçiminde UTC döner.
    return datetime.fromisoformat(value) if value else None

# Kullanıcının açtığı PR'lar: yalnız tarih, durum ve hedef reponun sahibi (kendi mi?) istenir.
# Başlık, repo adı ve PR kimliği bilerek istenmez.
PULL_REQUESTS_FIELD = """
    pullRequests(first: 100, after: $after, orderBy: {field: CREATED_AT, direction: DESC}) {
      pageInfo { hasNextPage endCursor }
      nodes { createdAt mergedAt closedAt state repository { owner { id } } }
    }
"""


def collaboration_query(year_ranges: list[dict]) -> str:
    """İlk sayfa: PR'lar + her yılın inceleme sayısı, GraphQL takma adlarıyla (y2025: ...) tek
    istekte. Sonraki sayfalarda year_ranges boş verilir, yalnız PR'lar gelir."""
    reviews = "".join(
        f'    y{r["from"][:4]}: contributionsCollection(from: "{r["from"]}", to: "{r["to"]}") '
        "{ totalPullRequestReviewContributions }\n"
        for r in year_ranges
    )
    return "query($after: String) {\n  viewer {" + PULL_REQUESTS_FIELD + reviews + "  }\n  rateLimit { cost remaining }\n}"


def _year_ranges(profile: Profile) -> list[dict]:
    """contributionsCollection en fazla 1 yıllık aralık kabul eder: hesap açılış
    yılından bugüne her yıl için bir {from, to} aralığı."""
    now = datetime.now(timezone.utc)
    ranges = []
    for year in range(profile.created_at.year, now.year + 1):
        start = datetime(year, 1, 1, tzinfo=timezone.utc)
        end = min(datetime(year, 12, 31, 23, 59, 59, tzinfo=timezone.utc), now)
        ranges.append({"from": start.isoformat(), "to": end.isoformat()})
    return ranges


class LiveGitHubClient:
    def __init__(self, token: str, transport: httpx.BaseTransport | None = None):
        # transport: testlerde sahte GitHub (httpx.MockTransport) vermek için.
        self.request_log: list[RequestStat] = []
        self._http = httpx.Client(
            timeout=30,
            headers={"Authorization": f"bearer {token}", "User-Agent": "devpulse-sync"},
            transport=transport,
        )

    def _query(self, kind: str, query: str, variables: dict | None = None) -> dict:
        """Tek bir GraphQL isteği: gerekirse yeniden dener, puanı ve süreyi kaydeder."""
        start = time.perf_counter()
        for attempt in range(1, MAX_ATTEMPTS + 1):
            try:
                resp = self._http.post(GRAPHQL_URL, json={"query": query, "variables": variables or {}})
            except httpx.TransportError as exc:  # bağlantı kurulamadı, zaman aşımı...
                if attempt < MAX_ATTEMPTS:
                    time.sleep(2 * attempt)
                    continue
                raise GitHubError("GitHub'a ulaşılamadı (ağ hatası ya da zaman aşımı).") from exc
            if resp.status_code in RETRY_STATUSES and attempt < MAX_ATTEMPTS:
                time.sleep(2 * attempt)
                continue
            break
        if resp.status_code == 401:
            raise TokenInvalid()
        if _is_rate_limited(resp):
            raise RateLimited(_rate_limit_reset(resp))
        if resp.status_code in RETRY_STATUSES:
            raise GitHubError("GitHub şu an yanıt vermiyor; biraz sonra tekrar dene.")
        if resp.status_code != 200:
            raise GitHubError(f"GitHub isteği başarısız oldu ({resp.status_code}).")
        body = resp.json()
        if body.get("errors"):
            # GraphQL sınır hatası 200 ile gelir; türü RATE_LIMITED olur.
            if any(e.get("type") == "RATE_LIMITED" for e in body["errors"]):
                raise RateLimited(_rate_limit_reset(resp))
            raise GitHubError("GitHub sorgu hatası: " + "; ".join(e.get("message", "?") for e in body["errors"]))

        data = body["data"]
        self.request_log.append(
            RequestStat(
                kind=kind,
                cost=data["rateLimit"]["cost"],
                duration_ms=round((time.perf_counter() - start) * 1000),
            )
        )
        return data

    def query(self, kind: str, query: str, variables: dict | None = None) -> dict:
        """Senkron dışı araçlar için (ör. ml/collect.py): ölçümlü tek GraphQL isteği."""
        return self._query(kind, query, variables)

    def fetch_profile(self) -> Profile:
        v = self._query("profile", PROFILE_QUERY)["viewer"]
        return Profile(node_id=v["id"], login=v["login"], created_at=_dt(v["createdAt"]),
                       avatar_url=v.get("avatarUrl"))

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

        # 2) Başkasına ait ama commit atılmış repolar (yıl yıl)
        for year_range in _year_ranges(profile):
            data = self._query("contributed_repos", CONTRIBUTED_REPOS_QUERY, year_range)
            for item in data["viewer"]["contributionsCollection"]["commitContributionsByRepository"]:
                node = item["repository"]
                repos.setdefault(node["id"], self._repo(node, profile))

        return list(repos.values())

    def fetch_calendar(self, profile: Profile) -> list[CalendarDay]:
        days: dict[date, int] = {}
        for year_range in _year_ranges(profile):
            data = self._query("calendar", CALENDAR_QUERY, year_range)
            weeks = data["viewer"]["contributionsCollection"]["contributionCalendar"]["weeks"]
            for week in weeks:
                for d in week["contributionDays"]:
                    days[date.fromisoformat(d["date"])] = d["contributionCount"]
        return [CalendarDay(day=k, count=v) for k, v in sorted(days.items())]

    def fetch_collaboration(self, profile: Profile) -> CollaborationData:
        prs: list[PullRequestData] = []
        reviews: dict[int, int] = {}
        after, ranges = None, _year_ranges(profile)
        while True:
            viewer = self._query("collaboration", collaboration_query(ranges), {"after": after})["viewer"]
            for r in ranges:
                year = int(r["from"][:4])
                reviews[year] = viewer[f"y{year}"]["totalPullRequestReviewContributions"]
            page = viewer["pullRequests"]
            for n in page["nodes"]:
                prs.append(PullRequestData(
                    created_at=_dt(n["createdAt"]), merged_at=_dt(n["mergedAt"]), closed_at=_dt(n["closedAt"]),
                    state=n["state"], is_own_repo=n["repository"]["owner"]["id"] == profile.node_id,
                ))
            if not page["pageInfo"]["hasNextPage"]:
                break
            after, ranges = page["pageInfo"]["endCursor"], []  # inceleme sayıları ilk sayfada geldi
        return CollaborationData(pull_requests=prs, reviews_by_year=reviews)

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
        # Bulunan ilk README'nin boyutu (yalnız bayt sayısı; içerik istenmez).
        readme = next((node[k] for k in ("readme1", "readme2", "readme3", "readme4") if node[k]), None)
        return RepoData(
            node_id=node["id"],
            name=node["name"],
            is_owner=node["owner"]["id"] == profile.node_id,
            is_fork=node["isFork"],
            is_private=node["isPrivate"],
            primary_language=(node["primaryLanguage"] or {}).get("name"),
            description=node["description"],
            has_readme=readme is not None,
            readme_bytes=readme.get("byteSize") if readme else None,
            is_archived=node.get("isArchived", False),
            languages={e["node"]["name"]: e["size"] for e in (node.get("languages") or {}).get("edges", [])},
            # Kök dizindeki adlar yalnız burada, araç tespiti için kullanılır; saklanmaz.
            tools=detect_tools(
                [e["name"] for e in (node.get("root") or {}).get("entries", [])],
                has_workflows=bool((node.get("workflows") or {}).get("entries")),
            ),
            license_spdx=(node["licenseInfo"] or {}).get("spdxId"),
            topics=[t["topic"]["name"] for t in node["repositoryTopics"]["nodes"]],
            created_at=_dt(node["createdAt"]),
            pushed_at=_dt(node["pushedAt"]),
        )
