"""Metrik kataloğu docs/metrikler.md ile uyumlu mu?"""
from pathlib import Path

from app.metrics.catalog import CATALOG

DOC = (Path(__file__).resolve().parents[2] / "docs" / "metrikler.md").read_text(encoding="utf-8")
HEADINGS = [line[4:] for line in DOC.splitlines() if line.startswith("### ")]


def test_every_entry_points_to_a_heading_in_metrikler_md():
    for entry in CATALOG:
        assert any(h.startswith(entry.section) for h in HEADINGS), entry.section


def test_entries_are_complete_and_unique():
    assert len({e.name for e in CATALOG}) == len(CATALOG)
    for e in CATALOG:
        assert all([e.definition, e.unit, e.interpretation, e.reliable_when]), e.name


def test_catalog_endpoint(api, demo_auth):
    assert api.get("/metrics/catalog").status_code == 401
    body = api.get("/metrics/catalog", headers=demo_auth).json()
    assert [e["name"] for e in body["entries"]] == [e.name for e in CATALOG]
