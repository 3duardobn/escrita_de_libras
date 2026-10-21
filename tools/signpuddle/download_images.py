"""Baixa imagens SVG dos sinais e, opcionalmente, grava os blobs no SQLite.

O app busca cada SVG sob demanda e guarda em cache. Este script serve para
espelhar tudo antecipadamente (útil para uso offline ou inspeção dos desenhos).
"""

from __future__ import annotations

import argparse
import concurrent.futures
import sqlite3
import sys
import threading
import time
from pathlib import Path

import requests

from .config import DEFAULT_DB, IMAGES_DIR, USER_AGENT
from .signpuddle_api import svg_url

_print_lock = threading.Lock()


def _safe_svg(data: bytes) -> bool:
    return data.lstrip().startswith(b"<svg") and b"</svg>" in data[-500:]


def _download_one(
    sign_id: int,
    swu: str,
    output: Path,
    *,
    force: bool,
    delay: float,
    timeout: float,
) -> tuple[int, Path | None, str | None]:
    destination = output / f"{sign_id}.svg"
    if destination.exists() and not force:
        return sign_id, destination, None
    if not swu:
        return sign_id, None, "sem SWU/FSW"

    if delay:
        time.sleep(delay)
    url = svg_url(swu)
    try:
        response = requests.get(
            url,
            headers={"User-Agent": USER_AGENT},
            timeout=timeout,
        )
        response.raise_for_status()
        if not _safe_svg(response.content):
            return sign_id, None, "resposta não era SVG"
        tmp = destination.with_suffix(".svg.tmp")
        tmp.write_bytes(response.content)
        tmp.replace(destination)
        return sign_id, destination, None
    except (OSError, requests.RequestException) as exc:
        return sign_id, None, str(exc)


def _load_signs(db_path: Path, ids: list[int] | None, limit: int | None) -> list[tuple[int, str]]:
    connection = sqlite3.connect(db_path)
    try:
        if ids:
            placeholders = ",".join("?" for _ in ids)
            rows = connection.execute(
                f"SELECT id, swu FROM signs WHERE id IN ({placeholders}) ORDER BY id",
                ids,
            ).fetchall()
        else:
            sql = "SELECT id, swu FROM signs ORDER BY id"
            params: tuple = ()
            if limit is not None:
                sql += " LIMIT ?"
                params = (limit,)
            rows = connection.execute(sql, params).fetchall()
        return [(int(row[0]), str(row[1] or "")) for row in rows]
    finally:
        connection.close()


def _write_images_to_db(db_path: Path, output: Path, ids: list[int]) -> int:
    connection = sqlite3.connect(db_path)
    try:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS sign_images (
                sign_id INTEGER PRIMARY KEY REFERENCES signs(id) ON DELETE CASCADE,
                svg BLOB NOT NULL
            )
            """
        )
        rows = []
        for sign_id in ids:
            path = output / f"{sign_id}.svg"
            if path.exists():
                rows.append((sign_id, path.read_bytes()))
        connection.executemany(
            "INSERT OR REPLACE INTO sign_images (sign_id, svg) VALUES (?, ?)", rows
        )
        connection.commit()
        return len(rows)
    finally:
        connection.close()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Espelha os SVGs dos sinais do SignPuddle."
    )
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--output", type=Path, default=IMAGES_DIR)
    parser.add_argument(
        "--limit",
        type=int,
        default=50,
        help="quantidade de sinais (padrão: 50; use --all para todos)",
    )
    parser.add_argument("--all", action="store_true", help="baixa todos os sinais")
    parser.add_argument(
        "--ids", help="lista de ids separada por vírgula (ignora --limit)"
    )
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--delay", type=float, default=0.0, help="pausa por requisição")
    parser.add_argument("--timeout", type=float, default=45.0)
    parser.add_argument("--force", action="store_true", help="rebaixa arquivos existentes")
    parser.add_argument(
        "--into-db",
        action="store_true",
        help="além dos arquivos, grava os SVGs na tabela sign_images do SQLite",
    )
    args = parser.parse_args(argv)

    if not args.db.exists():
        print(f"Erro: {args.db} não existe. Rode build_sqlite.py primeiro.", file=sys.stderr)
        return 1

    ids = None
    if args.ids:
        try:
            ids = [int(part.strip()) for part in args.ids.split(",") if part.strip()]
        except ValueError:
            print("Erro: --ids espera números separados por vírgula.", file=sys.stderr)
            return 1

    limit = None if args.all else max(args.limit, 1)
    signs = _load_signs(args.db, ids, limit)
    if not signs:
        print("Nenhum sinal encontrado.")
        return 1

    args.output.mkdir(parents=True, exist_ok=True)
    print(f"Baixando {len(signs):,} SVG(s) para {args.output}…")

    done = 0
    failed: list[tuple[int, str]] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(args.workers, 1)) as pool:
        futures = [
            pool.submit(
                _download_one,
                sign_id,
                swu,
                args.output,
                force=args.force,
                delay=args.delay,
                timeout=args.timeout,
            )
            for sign_id, swu in signs
        ]
        for future in concurrent.futures.as_completed(futures):
            sign_id, path, error = future.result()
            done += 1
            if error:
                failed.append((sign_id, error))
            if done % 100 == 0 or done == len(signs):
                with _print_lock:
                    print(f"  {done:,}/{len(signs):,} ({len(failed)} falhas)")

    if failed:
        print(f"{len(failed)} falha(s). Primeiras:")
        for sign_id, error in failed[:10]:
            print(f"  id {sign_id}: {error}")

    if args.into_db:
        count = _write_images_to_db(args.db, args.output, [sign_id for sign_id, _ in signs])
        print(f"Gravados {count:,} blobs em {args.db} (tabela sign_images).")
        print("Atenção: isso aumenta bastante o tamanho do asset do app.")

    return 0 if not failed else 2


if __name__ == "__main__":
    raise SystemExit(main())
