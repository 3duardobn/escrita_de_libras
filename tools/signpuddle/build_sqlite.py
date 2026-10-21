"""Constrói o SQLite pesquisável do app a partir do JSON do SignPuddle."""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from dataclasses import dataclass
from pathlib import Path

from .config import (
    DEFAULT_DB,
    DEFAULT_DICTIONARY,
    RAW_DIR,
    SCHEMA_VERSION,
)
from .normalize import normalize
from .signpuddle_api import utc_now

SCHEMA = """
PRAGMA user_version = {schema_version};

CREATE TABLE meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE signs (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    swu TEXT NOT NULL,
    is_signtext INTEGER NOT NULL DEFAULT 0,
    source TEXT,
    description TEXT,
    signtext TEXT,
    detail_json TEXT,
    user TEXT,
    created_at TEXT,
    updated_at TEXT
);

CREATE TABLE terms (
    sign_id INTEGER NOT NULL REFERENCES signs(id) ON DELETE CASCADE,
    term TEXT NOT NULL,
    term_norm TEXT NOT NULL,
    position INTEGER NOT NULL,
    is_title INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (sign_id, term)
);

CREATE INDEX idx_terms_norm ON terms(term_norm);
CREATE INDEX idx_terms_sign ON terms(sign_id);

CREATE VIRTUAL TABLE terms_fts USING fts5(
    term_norm,
    content='terms',
    content_rowid='rowid',
    tokenize='unicode61 remove_diacritics 2'
);
""".format(schema_version=SCHEMA_VERSION)


@dataclass(frozen=True)
class BuildStats:
    entries: int
    terms: int
    with_image: int
    with_description: int
    size_bytes: int


def _as_text(value: object) -> str:
    if value is None:
        return ""
    return str(value).strip()


def _load_payload(input_path: Path) -> dict:
    with input_path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict) or not isinstance(payload.get("data"), list):
        raise ValueError(
            "JSON inválido: esperava um objeto com a chave 'data' contendo uma lista."
        )
    return payload


def build_database(
    payload: dict,
    db_path: Path = DEFAULT_DB,
    *,
    dictionary: str = DEFAULT_DICTIONARY,
    source_url: str | None = None,
) -> BuildStats:
    """Gera o banco em um arquivo temporário e o move para o destino no final."""

    entries = payload.get("data")
    if not isinstance(entries, list):
        raise ValueError("O documento não contém uma lista 'data'.")
    dictionary = _as_text(payload.get("name")) or dictionary

    db_path = Path(db_path)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = db_path.with_suffix(db_path.suffix + ".tmp")
    if tmp_path.exists():
        tmp_path.unlink()

    connection = sqlite3.connect(tmp_path)
    connection.execute("PRAGMA journal_mode = OFF")
    connection.execute("PRAGMA synchronous = OFF")
    connection.execute("PRAGMA temp_store = MEMORY")
    connection.executescript(SCHEMA)

    seen_ids: set[int] = set()
    next_id = 1
    term_count = 0
    with_image = 0
    with_description = 0

    sign_rows: list[tuple] = []
    term_rows: list[tuple] = []

    for raw_entry in entries:
        if not isinstance(raw_entry, dict):
            continue

        try:
            entry_id = int(raw_entry.get("id"))
        except (TypeError, ValueError):
            entry_id = 0
        if entry_id <= 0 or entry_id in seen_ids:
            while next_id in seen_ids:
                next_id += 1
            entry_id = next_id
            next_id += 1
        seen_ids.add(entry_id)

        raw_terms = raw_entry.get("terms") or []
        terms: list[str] = []
        seen_terms: set[str] = set()
        for raw_term in raw_terms:
            term = _as_text(raw_term)
            if not term or term in seen_terms:
                continue
            seen_terms.add(term)
            terms.append(term)

        text = _as_text(raw_entry.get("text"))
        if not terms:
            fallback = text or f"sem-termo-{entry_id}"
            terms = [fallback]

        title = terms[0]
        description = text if text and normalize(text) != normalize(title) else ""
        if description:
            with_description += 1

        swu = _as_text(raw_entry.get("sign"))
        signtext = _as_text(raw_entry.get("signtext"))
        is_signtext = 0
        if not swu:
            swu = signtext
            is_signtext = 1 if signtext else 0
        if swu:
            with_image += 1

        detail = raw_entry.get("detail")
        detail_json = (
            json.dumps(detail, ensure_ascii=False, sort_keys=True)
            if isinstance(detail, dict) and detail
            else None
        )

        sign_rows.append(
            (
                entry_id,
                title,
                swu,
                is_signtext,
                _as_text(raw_entry.get("source")),
                description,
                signtext,
                detail_json,
                _as_text(raw_entry.get("user")),
                _as_text(raw_entry.get("created_at")),
                _as_text(raw_entry.get("updated_at")),
            )
        )

        position = 0
        for term in terms:
            term_norm = normalize(term)
            if not term_norm:
                continue
            term_rows.append((entry_id, term, term_norm, position, 1 if position == 0 else 0))
            position += 1
        term_count += position

    connection.executemany(
        """
        INSERT INTO signs (
            id, title, swu, is_signtext, source, description, signtext,
            detail_json, user, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        sign_rows,
    )
    connection.executemany(
        """
        INSERT OR IGNORE INTO terms (sign_id, term, term_norm, position, is_title)
        VALUES (?, ?, ?, ?, ?)
        """,
        term_rows,
    )

    meta = {
        "dictionary": dictionary,
        "source_url": source_url or f"https://signpuddle.com/server/dictionary/{dictionary}",
        "built_at": utc_now(),
        "entries": str(len(sign_rows)),
        "terms": str(term_count),
        "schema_version": str(SCHEMA_VERSION),
        "generator": "tools/signpuddle/build_sqlite.py",
    }
    connection.executemany(
        "INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)", meta.items()
    )

    connection.execute("INSERT INTO terms_fts(terms_fts) VALUES ('rebuild')")
    connection.commit()
    connection.execute("ANALYZE")
    connection.commit()
    connection.close()

    # VACUUM só funciona fora de transação e reduz bastante o arquivo final.
    vacuum = sqlite3.connect(tmp_path)
    vacuum.execute("VACUUM")
    vacuum.close()

    os.replace(tmp_path, db_path)
    size_bytes = db_path.stat().st_size
    return BuildStats(
        entries=len(sign_rows),
        terms=term_count,
        with_image=with_image,
        with_description=with_description,
        size_bytes=size_bytes,
    )


def build_from_file(
    input_path: Path = RAW_DIR / f"{DEFAULT_DICTIONARY}.json",
    db_path: Path = DEFAULT_DB,
    *,
    dictionary: str = DEFAULT_DICTIONARY,
) -> BuildStats:
    payload = _load_payload(input_path)
    return build_database(
        payload,
        db_path,
        dictionary=dictionary,
        source_url=f"https://signpuddle.com/server/dictionary/{dictionary}.json",
    )


def _print_stats(stats: BuildStats, db_path: Path) -> None:
    print(f"Banco gerado: {db_path}")
    print(f"  sinais:        {stats.entries:,}")
    print(f"  termos:        {stats.terms:,}")
    print(f"  com imagem:    {stats.with_image:,}")
    print(f"  com descrição: {stats.with_description:,}")
    print(f"  tamanho:       {stats.size_bytes / 1024 / 1024:.2f} MB")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Constrói o SQLite do app a partir do JSON do SignPuddle."
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=RAW_DIR / f"{DEFAULT_DICTIONARY}.json",
        help="JSON baixado por fetch_dictionary.py",
    )
    parser.add_argument(
        "--db", type=Path, default=DEFAULT_DB, help="SQLite de saída"
    )
    parser.add_argument(
        "--dictionary",
        default=DEFAULT_DICTIONARY,
        help="nome do dicionário (usado nos metadados)",
    )
    args = parser.parse_args(argv)

    if not args.input.exists():
        print(
            f"Erro: {args.input} não existe. Rode fetch_dictionary.py primeiro.",
            file=sys.stderr,
        )
        return 1

    try:
        stats = build_from_file(
            args.input, args.db, dictionary=args.dictionary
        )
    except (OSError, ValueError, sqlite3.Error) as exc:
        print(f"Erro ao construir o banco: {exc}", file=sys.stderr)
        return 1

    _print_stats(stats, args.db)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
