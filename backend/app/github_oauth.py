"""GitHub OAuth: yetki kodunu (code) access token'a çevirir.

Akış: yetki kodu + PKCE. Telefon code_verifier'ı üretir ve saklar; GitHub'a yalnızca
onun SHA-256 özeti (code_challenge) gider. Kod ve verifier telefondan backend'e gelir,
backend client_secret'ı ekleyip GitHub'a sorar. Secret telefona hiç girmez.

İki OAuth App vardır, çünkü bir GitHub OAuth App'te tek geri dönüş adresi tanımlanabilir:
- web:     http://127.0.0.1:5180/auth.html   (GITHUB_CLIENT_ID / GITHUB_CLIENT_SECRET)
- android: devpulse://oauth-callback          (GITHUB_ANDROID_CLIENT_ID / ..._SECRET)
Hangisinin kullanılacağı geri dönüş adresinden anlaşılır.
"""
from dataclasses import dataclass

import httpx

from app.config import settings

AUTHORIZE_URL = "https://github.com/login/oauth/authorize"
TOKEN_URL = "https://github.com/login/oauth/access_token"
ANDROID_SCHEME = "devpulse://"


class OAuthError(Exception):
    pass


@dataclass(frozen=True)
class OAuthApp:
    platform: str
    client_id: str
    client_secret: str


def app_for_platform(platform: str) -> OAuthApp | None:
    """'web' ya da 'android' için yapılandırılmış OAuth App (yoksa None)."""
    if platform == "android":
        cid, secret = settings.github_android_client_id, settings.github_android_client_secret
    else:
        cid, secret = settings.github_client_id, settings.github_client_secret
    return OAuthApp(platform, cid, secret) if cid and secret else None


def app_for_redirect(redirect_uri: str) -> OAuthApp | None:
    """Geri dönüş adresi hangi uygulamanınsa onun bilgileri (devpulse:// -> android)."""
    return app_for_platform("android" if redirect_uri.startswith(ANDROID_SCHEME) else "web")


def exchange_code(
    code: str,
    code_verifier: str,
    redirect_uri: str,
    transport: httpx.BaseTransport | None = None,  # testlerde sahte GitHub için
) -> str:
    app = app_for_redirect(redirect_uri)
    if app is None:
        raise OAuthError("Bu platform için GitHub OAuth App ayarlanmamış (backend/.env).")

    with httpx.Client(timeout=15, transport=transport) as http:
        resp = http.post(
            TOKEN_URL,
            headers={"Accept": "application/json"},  # yoksa form biçiminde cevap gelir
            data={
                "client_id": app.client_id,
                "client_secret": app.client_secret,
                "code": code,
                "code_verifier": code_verifier,
                "redirect_uri": redirect_uri,
            },
        )
    if resp.status_code != 200:
        raise OAuthError(f"GitHub {resp.status_code} döndü.")
    body = resp.json()
    # GitHub hatada da 200 döner; hata "error" alanındadır (ör. bad_verification_code).
    if "error" in body:
        raise OAuthError(f"{body['error']}: {body.get('error_description', '')}".strip(": "))
    return body["access_token"]


def revoke_grant(access_token: str, transport: httpx.BaseTransport | None = None) -> bool:
    """Kullanıcının DevPulse'a verdiği GitHub iznini kaldırır (token'lar da geçersizleşir).

    GitHub API: DELETE /applications/{client_id}/grant, client_id:client_secret ile Basic Auth.
    Token'ın hangi uygulamadan (web/android) geldiği bilinmediği için yapılandırılmış
    uygulamalar sırayla denenir. Başarılıysa True; hiçbiri kabul etmezse False
    (silme işlemini engellemez).
    """
    for app in filter(None, (app_for_platform("web"), app_for_platform("android"))):
        try:
            with httpx.Client(timeout=15, transport=transport) as http:
                resp = http.request(
                    "DELETE",
                    f"https://api.github.com/applications/{app.client_id}/grant",
                    auth=(app.client_id, app.client_secret),
                    headers={"Accept": "application/vnd.github+json", "User-Agent": "devpulse"},
                    json={"access_token": access_token},
                )
            if resp.status_code == 204:
                return True
        except httpx.HTTPError:
            continue
    return False
