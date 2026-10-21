"""Cliente mínimo da API pública do SignPuddle 3."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Literal
from urllib.parse import quote

import requests

from .config import API_BASE, USER_AGENT


@dataclass(frozen=True)
class DictionaryDownload:
    name: str
    payload: bytes
    url: str
    last_modified: str | None
    not_modified: bool = False


class SignPuddleError(RuntimeError):
    """Erro de comunicação ou de conteúdo devolvido pelo SignPuddle."""


class SignPuddleClient:
    def __init__(self, base_url: str = API_BASE, timeout: float = 60.0):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.session = requests.Session()
        self.session.headers.update(
            {
                "User-Agent": USER_AGENT,
                "Accept": "application/json, image/svg+xml;q=0.9, */*;q=0.8",
            }
        )

    def dictionary(
        self,
        name: str,
        *,
        if_modified_since: str | None = None,
    ) -> DictionaryDownload:
        url = f"{self.base_url}/dictionary/{quote(name, safe='')}.json"
        headers = {}
        if if_modified_since:
            headers["If-Modified-Since"] = if_modified_since

        response = self.session.get(url, headers=headers, timeout=self.timeout)
        if response.status_code == 304:
            return DictionaryDownload(
                name=name,
                payload=b"",
                url=url,
                last_modified=if_modified_since,
                not_modified=True,
            )
        response.raise_for_status()

        content_type = response.headers.get("Content-Type", "")
        if "json" not in content_type.lower():
            raise SignPuddleError(
                f"Resposta inesperada para {url}: {content_type!r}"
            )
        return DictionaryDownload(
            name=name,
            payload=response.content,
            url=url,
            last_modified=response.headers.get("Last-Modified"),
        )

    def svg(self, sign: str, *, kind: Literal["swu", "fsw"] = "swu") -> bytes:
        """Baixa o SVG de um sinal.

        ``sign`` é a string SWU (Unicode) ou FSW (ASCII), dependendo de ``kind``.
        """

        if not sign or not sign.strip():
            raise SignPuddleError("Sinal vazio: não há SWU/FSW para renderizar.")
        if kind not in ("swu", "fsw"):
            raise SignPuddleError(f"Formato de sinal desconhecido: {kind!r}")

        url = f"{self.base_url}/{kind}/svg/{quote(sign, safe='')}"
        response = self.session.get(url, timeout=self.timeout)
        response.raise_for_status()
        content = response.content
        if not content.lstrip().startswith(b"<svg"):
            raise SignPuddleError(f"O servidor não devolveu um SVG para {url}")
        return content


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z"
    )


def svg_url(sign: str, *, kind: Literal["swu", "fsw"] = "swu") -> str:
    """URL pública do SVG, útil para depuração e para o app."""

    return f"{API_BASE}/{kind}/svg/{quote(sign, safe='')}"
