"""Configuração compartilhada das ferramentas SignPuddle."""

from __future__ import annotations

from pathlib import Path

# Dicionário público de Língua Brasileira de Sinais (ISO 639-3: bzs).
DEFAULT_DICTIONARY = "bzs-BR-dictionary-public"

API_BASE = "https://signpuddle.com/server"
CLIENT_URL = "https://signpuddle.com/client/"

PROJECT_ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = PROJECT_ROOT / "tools" / "signpuddle"
DATA_DIR = TOOLS_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
IMAGES_DIR = DATA_DIR / "images"
ASSETS_DIR = PROJECT_ROOT / "assets"
DEFAULT_DB = ASSETS_DIR / "signpuddle.db"

SCHEMA_VERSION = 1

USER_AGENT = (
    "EscritaDeLibras/1.0 "
    "(ferramenta educacional; https://signpuddle.com/)"
)
