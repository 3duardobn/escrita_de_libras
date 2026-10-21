"""Sincronização completa: baixa o JSON e reconstrói o SQLite do app."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .build_sqlite import build_from_file, _print_stats
from .config import DEFAULT_DB, DEFAULT_DICTIONARY, RAW_DIR
from .fetch_dictionary import fetch_dictionary
from .signpuddle_api import SignPuddleError


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Baixa e reconstrói o banco do SignPuddle."
    )
    parser.add_argument("--dictionary", default=DEFAULT_DICTIONARY)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args(argv)

    try:
        json_path = fetch_dictionary(args.dictionary, force=args.force)
        stats = build_from_file(json_path, args.db, dictionary=args.dictionary)
    except (SignPuddleError, OSError, ValueError) as exc:
        print(f"Erro: {exc}", file=sys.stderr)
        return 1

    _print_stats(stats, args.db)
    print()
    print("Próximos passos:")
    print("  flutter pub get")
    print("  flutter run")
    print("  # opcional: espelhar imagens para uso offline")
    print("  python -m tools.signpuddle.download_images --all --into-db")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
