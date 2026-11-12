"""GitHub OAuth: yetki kodunu (code) access token'a çevirir.

Akış: yetki kodu + PKCE. Telefon code_verifier'ı üretir ve saklar; GitHub'a yalnızca
onun SHA-256 özeti (code_challenge) gider. Kod ve verifier telefondan backend'e gelir,
backend client_secret'ı ekleyip GitHub'a sorar. Secret telefona hiç girmez.
"""
import httpx

from app.config import settings

AUTHORIZE_URL = "https://github.com/login/oauth/authorize"
TOKEN_URL = "https://github.com/login/oauth/access_token"


class OAuthError(Exception):
    pass


def exchange_code(
    code: str,
    code_verifier: str,
    redirect_uri: str,
    transport: httpx.BaseTransport | None = None,  # testlerde sahte GitHub için
) -> str:
    if not (settings.github_client_id and settings.github_client_secret):
        raise OAuthError("GITHUB_CLIENT_ID / GITHUB_CLIENT_SECRET ayarlanmamış.")

    with httpx.Client(timeout=15, transport=transport) as http:
        resp = http.post(
            TOKEN_URL,
            headers={"Accept": "application/json"},  # yoksa form biçiminde cevap gelir
            data={
                "client_id": settings.github_client_id,
                "client_secret": settings.github_client_secret,
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
