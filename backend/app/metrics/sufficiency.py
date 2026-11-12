"""Üç durumlu veri yeterliliği. Eşikler sezgiseldir ve yalnızca burada durur
(docs/metrikler.md'deki tabloyla aynı olmalı)."""
from enum import StrEnum


class Sufficiency(StrEnum):
    NONE = "yetersiz"  # "Yeterli veri yok"
    LOW = "dusuk"  # "Düşük güven"
    NORMAL = "normal"


def continuity(active_days: int, days_since_first: int) -> Sufficiency:
    if active_days < 3:
        return Sufficiency.NONE
    if active_days < 10 or days_since_first < 30:
        return Sufficiency.LOW
    return Sufficiency.NORMAL


def rhythm(commits: int, timezone_known: bool) -> Sufficiency:
    if commits < 10:
        return Sufficiency.NONE
    if commits < 50 or not timezone_known:  # saat dilimi yoksa saatler kayık olabilir
        return Sufficiency.LOW
    return Sufficiency.NORMAL


def anomaly(active_days: int) -> Sufficiency:
    if active_days < 10:
        return Sufficiency.NONE
    if active_days < 30:
        return Sufficiency.LOW
    return Sufficiency.NORMAL


def sessions(session_count: int) -> Sufficiency:
    if session_count < 3:
        return Sufficiency.NONE
    if session_count < 15:
        return Sufficiency.LOW
    return Sufficiency.NORMAL
