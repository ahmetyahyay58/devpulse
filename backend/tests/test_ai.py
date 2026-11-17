"""AI katmanı (docs/ai_katmani.md): gerçek Gemini yerine sahte sunucu (MockTransport)."""
import json

import httpx
import pytest

from app.ai import gemini
from app.api import ai
from app.config import settings

DEMO_REPO = "hava-durumu-api"  # tests/fixtures/demo_small.json
DEMO_MESSAGE = "şehir bazlı sorgu"


class FakeGemini:
    def __init__(self, status=200, text="Düzenli çalışıyorsun; seri 3 gün."):
        self.status, self.text, self.requests = status, text, []

    def handler(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        if self.status != 200:
            return httpx.Response(self.status, json={"error": {}})
        return httpx.Response(200, json={"candidates": [{"content": {"parts": [{"text": self.text}]}}]})


@pytest.fixture
def fake(monkeypatch):
    f = FakeGemini()
    monkeypatch.setattr(ai, "transport", httpx.MockTransport(f.handler))
    monkeypatch.setattr(settings, "gemini_api_key", "test-key")
    ai._cache.clear()
    return f


@pytest.fixture
def synced(api, demo_auth):
    api.post("/sync", json={}, headers=demo_auth)
    return demo_auth


def consent(api, headers, enabled=True):
    return api.post("/ai/consent", json={"enabled": enabled}, headers=headers).json()


def test_requires_session(api):
    assert api.get("/ai/status").status_code == 401
    assert api.post("/ai/ask", json={"question": "ozet"}).status_code == 401


def test_status_lists_questions_and_starts_without_consent(api, synced):
    body = api.get("/ai/status", headers=synced).json()
    assert body["consent"] is False
    assert body["llm_ready"] is False  # testlerde anahtar boş
    kinds = [q["kind"] for q in body["questions"]]
    assert kinds.count("sor") == 5 and kinds.count("neden") == 5 and kinds.count("ipucu") == 1 and kinds.count("hedef") == 3


def test_without_consent_template_and_no_request(api, synced, fake):
    body = api.post("/ai/ask", json={"question": "ozet"}, headers=synced).json()
    assert body["source"] == "sablon"
    assert "onay" in body["reason"]
    assert body["answer"]
    assert fake.requests == []  # onay yokken dışarı hiç istek gitmez


def test_without_key_template_and_no_request(api, synced, fake, monkeypatch):
    monkeypatch.setattr(settings, "gemini_api_key", "")
    consent(api, synced)
    body = api.post("/ai/ask", json={"question": "guclu"}, headers=synced).json()
    assert body["source"] == "sablon" and "anahtar" in body["reason"]
    assert fake.requests == []


def test_with_consent_llm_answers_and_only_numbers_are_sent(api, synced, fake):
    assert consent(api, synced)["consent"] is True
    body = api.post("/ai/ask", json={"question": "ozet"}, headers=synced).json()
    assert body["source"] == "llm"
    assert body["answer"] == fake.text

    sent = fake.requests[0]
    assert sent.headers["x-goog-api-key"] == "test-key"
    raw = sent.content.decode()
    assert DEMO_REPO not in raw and DEMO_MESSAGE not in raw and "demo-gelistirici" not in raw
    prompt = json.loads(raw)["contents"][0]["parts"][0]["text"]
    assert json.dumps(body["facts"], ensure_ascii=False, sort_keys=True) in prompt  # ekranda gösterilen = giden


def test_same_question_is_cached(api, synced, fake):
    consent(api, synced)
    for _ in range(3):
        api.post("/ai/ask", json={"question": "ritim"}, headers=synced)
    assert len(fake.requests) == 1


@pytest.mark.parametrize("status", [429, 500, 403])
def test_llm_failure_falls_back_to_template(api, synced, fake, status):
    fake.status = status
    consent(api, synced)
    body = api.post("/ai/ask", json={"question": "gelistir"}, headers=synced).json()
    assert body["source"] == "sablon" and "cevap veremedi" in body["reason"]


def test_too_long_answer_falls_back(api, synced, fake):
    fake.text = "x" * (gemini.MAX_ANSWER_CHARS + 1)
    consent(api, synced)
    assert api.post("/ai/ask", json={"question": "ozet"}, headers=synced).json()["source"] == "sablon"


def test_revoking_consent_stops_requests(api, synced, fake):
    consent(api, synced)
    api.post("/ai/ask", json={"question": "ozet"}, headers=synced)
    assert consent(api, synced, enabled=False)["consent"] is False
    body = api.post("/ai/ask", json={"question": "ozet"}, headers=synced).json()
    assert body["source"] == "sablon"
    assert len(fake.requests) == 1


def test_unknown_question_404(api, synced):
    assert api.post("/ai/ask", json={"question": "serbest metin"}, headers=synced).status_code == 404


def test_every_template_answers_even_without_data(api, login_as):
    headers = login_as("U_bos", "bos")  # hiç verisi olmayan kullanıcı
    for q in api.get("/ai/status", headers=headers).json()["questions"]:
        body = api.post("/ai/ask", json={"question": q["id"]}, headers=headers).json()
        assert body["answer"].strip(), q["id"]


def test_facts_have_no_names_or_messages(api, synced):
    body = api.get("/ai/facts", headers=synced).json()
    raw = json.dumps(body["facts"], ensure_ascii=False)
    assert DEMO_REPO not in raw and DEMO_MESSAGE not in raw
    assert body["facts"]["toplam_commit"] == 6
    assert "gitmez" in body["note"]


def test_busy_model_falls_back_to_second_model(api, synced, monkeypatch):
    seen = []

    def handler(request):
        seen.append(request.url.path)
        if settings.gemini_model in request.url.path:  # ana model yoğun
            return httpx.Response(503, json={"error": {"status": "UNAVAILABLE"}})
        return httpx.Response(200, json={"candidates": [{"content": {"parts": [{"text": "Yedek cevap."}]}}]})

    monkeypatch.setattr(ai, "transport", httpx.MockTransport(handler))
    monkeypatch.setattr(settings, "gemini_api_key", "test-key")
    ai._cache.clear()
    consent(api, synced)
    body = api.post("/ai/ask", json={"question": "ozet"}, headers=synced).json()
    assert body["source"] == "llm" and body["answer"] == "Yedek cevap."
    assert len(seen) == 2 and settings.gemini_fallback_model in seen[1]


def test_bad_key_does_not_try_second_model(api, synced, fake):
    fake.status = 403  # anahtar geçersiz: başka modelle denemek anlamsız
    consent(api, synced)
    api.post("/ai/ask", json={"question": "ozet"}, headers=synced)
    assert len(fake.requests) == 1


def test_question_sends_only_related_numbers(api, synced, fake):
    consent(api, synced)
    body = api.post("/ai/ask", json={"question": "neden_ritim"}, headers=synced).json()
    assert set(body["facts"]) == {"en_yogun_saat", "gece_payi_yuzde", "hafta_sonu_payi_yuzde", "ritim_guveni"}
    prompt = json.loads(fake.requests[0].content)["contents"][0]["parts"][0]["text"]
    assert "toplam_commit" not in prompt and "eksik_proje" not in prompt


# --- Mülakat koçu (docs/ai_katmani.md, "Mülakat koçu") ---------------------------------------

def _project_id(api, headers):
    projects = api.get("/cv/draft", headers=headers).json()["projects"]
    return next(p for p in projects if p["name"] == DEMO_REPO)["id"]


def test_interview_template_without_consent(api, synced, fake):
    body = api.post("/ai/interview", json={"project_id": _project_id(api, synced)}, headers=synced).json()
    assert body["source"] == "sablon" and "onay" in body["reason"]
    assert len(body["questions"]) == 3
    assert any(DEMO_REPO in e for e in body["evidence"])  # bağlantı telefona döner
    assert DEMO_REPO not in json.dumps(body["facts"], ensure_ascii=False)  # LLM'e gidecek veride ad yok
    assert body["facts"]["commit_sayisi"] > 0
    assert fake.requests == []


def test_interview_llm_sends_only_project_numbers(api, synced, fake):
    consent(api, synced)
    fake.text = "1. Neden bu dili seçtin?\n2. En zor hatayı nasıl çözdün?\n- Bugün neyi farklı yapardın?"
    body = api.post("/ai/interview", json={"project_id": _project_id(api, synced)}, headers=synced).json()
    assert body["source"] == "llm"
    assert body["questions"] == ["Neden bu dili seçtin?", "En zor hatayı nasıl çözdün?", "Bugün neyi farklı yapardın?"]
    sent = fake.requests[0].content.decode()
    assert DEMO_REPO not in sent and DEMO_MESSAGE not in sent
    assert "teknik mülakatçı" in sent  # kendi sistem talimatı


def test_interview_bad_llm_format_falls_back(api, synced, fake):
    consent(api, synced)
    fake.text = "Tek bir uzun paragraf, üç soru değil."
    body = api.post("/ai/interview", json={"project_id": _project_id(api, synced)}, headers=synced).json()
    assert body["source"] == "sablon" and "biçim" in body["reason"]
    assert len(body["questions"]) == 3


def test_interview_unknown_project_404(api, synced):
    assert api.post("/ai/interview", json={"project_id": "proj:yok"}, headers=synced).status_code == 404


def test_interview_template_rules():
    from datetime import datetime, timezone

    from app.ai.interview import ProjectFacts, evidence, parse_questions, template_questions
    from app.metrics.commit_types import CommitText, build_commit_types

    at = datetime(2026, 1, 1, tzinfo=timezone.utc)
    types = build_commit_types([CommitText("fix: hata düzeltildi", at, "x")] * 12)
    p = ProjectFacts(name="x", url="https://github.com/ben/x", language="Python", tools=["Docker"],
                     commit_count=12, active_days=4, months=3, missing=["README"])
    q = template_questions(p, types)
    assert "Python ve Docker" in q[0] and "en zor hata" in q[1] and "iki dakikada" in q[2]
    ev = evidence(p, types)
    assert ev[0] == "Bağlantıyı hazır tut: github.com/ben/x" and any("README ekle" in e for e in ev)
    assert parse_questions("a\n\nb\nc") == ["a", "b", "c"] and parse_questions("a\nb") is None



# --- Hedef koçu (Başarımlar) -------------------------------------------------------------------

def test_goal_questions_templates_and_subsets(api, synced, fake):
    badge = api.post("/ai/ask", json={"question": "hedef_rozet"}, headers=synced).json()
    assert badge["source"] == "sablon" and badge["answer"].startswith("En yakın rozet: ")
    assert set(badge["facts"]) == {"acik_rozet", "kilitli_rozetler"}
    assert all("/" in v for v in badge["facts"]["kilitli_rozetler"].values())

    week = api.post("/ai/ask", json={"question": "hedef_hafta"}, headers=synced).json()
    assert "seri" in week["answer"] or "commit" in week["answer"]
    assert "yil_degisim_yuzde" in week["facts"] and "kilitli_rozetler" not in week["facts"]

    proj = api.post("/ai/ask", json={"question": "hedef_proje"}, headers=synced).json()
    assert set(proj["facts"]) == {"puanlanan_proje", "ortalama_saglik", "eksik_proje"}
    assert DEMO_REPO not in json.dumps(proj["facts"], ensure_ascii=False)  # repo adı yalnız şablonda


def test_goal_week_template_rules():
    from types import SimpleNamespace as NS

    from app.ai.questions import _goal_week
    from app.metrics.sufficiency import Sufficiency

    def ctx(cur, longest):
        cont = NS(sufficiency=Sufficiency.NORMAL, current_streak=cur, longest_streak=longest)
        return NS(overview=NS(continuity=cont))

    assert "3 farklı günde" in _goal_week(ctx(0, 9))
    assert "Rekoru geçmek için 6 gün" in _goal_week(ctx(4, 9))
    assert "en uzun serindesin: 9 gün" in _goal_week(ctx(9, 9))
