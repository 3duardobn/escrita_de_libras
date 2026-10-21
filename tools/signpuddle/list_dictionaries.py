"""Lista os dicionários públicos disponíveis na API do SignPuddle 3."""

from __future__ import annotations

import argparse
import json

import requests

from .config import API_BASE, USER_AGENT


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="saída JSON")
    args = parser.parse_args(argv)

    response = requests.get(
        f"{API_BASE}/dictionary",
        headers={"User-Agent": USER_AGENT},
        timeout=30,
    )
    response.raise_for_status()
    names = response.json()
    if args.json:
        print(json.dumps(names, indent=2, ensure_ascii=False))
    else:
        for name in names:
            marker = " <- Brasil" if name.startswith("bzs-BR") else ""
            print(name + marker)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
