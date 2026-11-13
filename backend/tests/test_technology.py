"""Teknoloji: araç tespiti, dil dağılımı, çeşitlilik (docs/metrikler.md "Teknoloji")."""
import math

from app.metrics.sufficiency import Sufficiency
from app.metrics.technology import RepoTech, build_technology, normalized_entropy
from app.sync.tools import detect_tools


def test_detect_tools_by_exact_name_prefix_and_workflows():
    names = ["README.md", "Dockerfile", "package.json", "vite.config.ts", ".eslintrc.json", "src"]
    assert detect_tools(names, has_workflows=True) == [
        "Docker", "ESLint", "GitHub Actions", "Node.js (npm)", "Vite",
    ]


def test_detect_tools_is_case_insensitive_and_deduplicated():
    assert detect_tools(["DOCKERFILE", "docker-compose.yml", "compose.yaml"]) == ["Docker", "Docker Compose"]
    assert detect_tools(["main.py", "notes.txt"]) == []


def test_normalized_entropy():
    assert normalized_entropy([1.0]) == 0.0
    assert normalized_entropy([0.5, 0.5]) == 1.0
    assert math.isclose(normalized_entropy([0.25] * 4), 1.0)
    # 0.9 / 0.1: H = -(0.9 ln 0.9 + 0.1 ln 0.1) = 0.3251; / ln 2 = 0.469
    assert round(normalized_entropy([0.9, 0.1]), 3) == 0.469


def own(langs, tools=(), owner=True, fork=False):
    return RepoTech(is_owner=owner, is_fork=fork, languages=langs, tools=list(tools))


def test_distribution_dominant_and_diversity():
    out = build_technology([
        own({"Python": 6000, "Shell": 1000}, ["Docker", "pip"]),
        own({"Python": 2000, "Dart": 1000}, ["Docker"]),
        own({"Dart": 0, "TypeScript": 0}),  # boyutsuz diller dağılımı bozmaz
        own({"Go": 99999}, owner=False),   # başkasının reposu: sayılmaz
        own({"C": 99999}, fork=True),      # fork: sayılmaz
    ])
    assert out.repo_count == 2 and out.language_count == 3  # boyutsuz repo ve diller sayılmaz
    names = [l.name for l in out.languages]
    assert names[:3] == ["Python", "Dart", "Shell"]
    assert out.dominant == "Python" and out.dominant_share == 0.8  # 8000 / 10000
    py = out.languages[0]
    assert (py.bytes, py.repos) == (8000, 2)
    assert [(t.name, t.repos) for t in out.tools] == [("Docker", 2), ("pip", 1)]
    assert "Go" not in names and "C" not in names
    assert "en çok Python" in out.summary and "%80" in out.summary


def test_tiny_languages_fold_into_other():
    out = build_technology([own({"Python": 9950, "Makefile": 30, "Batchfile": 20})])
    assert [(l.name, l.bytes, l.repos) for l in out.languages] == [("Python", 9950, 1), ("Diğer", 50, 1)]
    assert out.language_count == 3  # Diğer içindekiler de dil sayısına girer


def test_single_language_summary_and_zero_diversity():
    out = build_technology([own({"Dart": 500})])
    assert out.diversity == 0.0
    assert out.summary == "Kodunun tamamı tek dilde: Dart."
    assert out.sufficiency == Sufficiency.LOW


def test_no_language_data():
    out = build_technology([own({}), own({"Go": 10}, fork=True)])
    assert out.sufficiency == Sufficiency.NONE and out.dominant is None and out.languages == []
    assert "yeterli veri yok" in out.summary


def test_sufficiency_normal_with_three_repos():
    out = build_technology([own({"Python": 1}), own({"Python": 1}), own({"Go": 1})])
    assert out.sufficiency == Sufficiency.NORMAL


def test_technology_endpoint_after_demo_sync(api, demo_auth):
    assert api.get("/metrics/technology").status_code == 401
    api.post("/sync", json={}, headers=demo_auth)
    body = api.get("/metrics/technology", headers=demo_auth).json()
    # demo_small'da dil bilgisi yok: veri yetersiz ama çökmez
    assert body["sufficiency"] == "yetersiz" and "entropi" in body["how"]
