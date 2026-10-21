"""Baixa o dicionário público do SignPuddle para um arquivo JSON local."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .config import DEFAULT_DICTIONARY, RAW_DIR
from .normalize import normalize
from .signpuddle_api import SignPuddleClient, SignPuddleError, utc_now


def _read_meta(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def fetch_dictionary(
    dictionary: str = DEFAULT_DICTIONARY,
    *,
    output: Path | None = None,
    force: bool = False,
    timeout: float = 60.0,
) -> Path:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    output = output or RAW_DIR / f"{dictionary}.json"
    meta_path = output.with_suffix(output.suffix + ".meta.json")
    meta = _read_meta(meta_path)

    if output.exists() and not force:
        print(f"Arquivo já existe: {output} ({output.stat().st_size / 1024 / 1024:.1f} MB)")
        print("Use --force para baixar novamente ou --refresh para checar atualizações.")
        return output

    client = SignPuddleClient(timeout=timeout)
    last_modified = None if force else meta.get("last_modified")
    print(f"Consultando {dictionary} em signpuddle.com…")
    result = client.dictionary(dictionary, if_modified_since=last_modified)

    if result.not_modified:
        print("O dicionário não mudou desde a última sincronização.")
        return output

    try:
        payload = json.loads(result.payload)
    except json.JSONDecodeError as exc:
        raise SignPuddleError(f"JSON inválido recebido do SignPuddle: {exc}") from exc

    if payload.get("name") != dictionary or not isinstance(payload.get("data"), list):
        raise SignPuddleError(
            "O SignPuddle devolveu um documento fora do formato esperado."
        )

    tmp = output.with_suffix(output.suffix + ".tmp")
    tmp.write_bytes(result.payload)
    tmp.replace(output)

    entries = payload["data"]
    terms = sum(len(entry.get("terms") or []) for entry in entries)
    meta_path.write_text(
        json.dumps(
            {
                "dictionary": dictionary,
                "url": result.url,
                "last_modified": result.last_modified,
                "fetched_at": utc_now(),
                "entries": len(entries),
                "terms": terms,
                "sha_normalized_terms": len(
                    {
                        normalize(term)
                        for entry in entries
                        for term in (entry.get("terms") or [])
                    }
                ),
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    print(
        f"Baixado: {len(entries):,} sinais, {terms:,} termos, "
        f"{output.stat().st_size / 1024 / 1024:.1f} MB"
    )
    print(f"Salvo em {output}")
    return output


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Baixa um dicionário público do SignPuddle 3."
    )
    parser.add_argument(
        "--dictionary",
        default=DEFAULT_DICTIONARY,
        help=f"nome do dicionário (padrão: {DEFAULT_DICTIONARY})",
    )
    parser.add_argument("--output", type=Path, help="arquivo JSON de destino")
    parser.add_argument(
        "--force", action="store_true", help="ignora cache e baixa novamente"
    )
    parser.add_argument(
        "--refresh",
        action="store_true",
        help="checa Last-Modified; se não mudou, mantém o arquivo atual",
    )
    parser.add_argument(
        "--timeout", type=float, default=60.0, help="timeout em segundos"
    )
    args = parser.parse_args(argv)

    if args.refresh:
        # --refresh preserva o arquivo, mas permite revalidar com o servidor.
        meta_path = None
        output = args.output or RAW_DIR / f"{args.dictionary}.json"
        meta_path = output.with_suffix(output.suffix + ".meta.json")
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            meta = {}
        client = SignPuddleClient(timeout=args.timeout)
        result = client.dictionary(
            args.dictionary, if_modified_since=meta.get("last_modified")
        )
        if result.not_modified:
            print("O dicionário não mudou desde a última sincronização.")
            return 0
        # Há conteúdo novo: grava o payload revalidado.
        payload = json.loads(result.payload)
        output.parent.mkdir(parents=True, exist_ok=True)
        tmp = output.with_suffix(output.suffix + ".tmp")
        tmp.write_bytes(result.payload)
        tmp.replace(output)
        meta.update(
            {
                "dictionary": args.dictionary,
                "url": result.url,
                "last_modified": result.last_modified,
                "fetched_at": utc_now(),
                "entries": len(payload.get("data") or []),
            }
        )
        meta_path.write_text(
            json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print(f"Atualizado: {output}")
        return 0

    try:
        fetch_dictionary(
            args.dictionary,
            output=args.output,
            force=args.force,
            timeout=args.timeout,
        )
    except (SignPuddleError, OSError, ValueError) as exc:
        print(f"Erro: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
