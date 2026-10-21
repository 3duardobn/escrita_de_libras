"""Normalização de termos usada tanto pelo Python quanto pelo app.

A mesma regra é reproduzida em Dart (`lib/core/text_normalizer.dart`). Mantenha
as duas implementações em sincronia: o banco guarda `term_norm` já normalizado e
o app normaliza a consulta antes de comparar.
"""

from __future__ import annotations

import re
import unicodedata

_WHITESPACE = re.compile(r"\s+")
_NON_ALNUM = re.compile(r"[^a-z0-9]+")


def normalize(value: object) -> str:
    """Minúsculas, sem acentos, sem pontuação e com espaços colapsados.

    ``queda-d'água(1)`` vira ``queda d agua 1``. Assim a busca tolera
    acentos, hífens, apóstrofos e parênteses usados nos termos originais.
    """

    if value is None:
        return ""
    text = str(value)
    text = unicodedata.normalize("NFKD", text)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = text.casefold().replace("@", "o")
    text = _NON_ALNUM.sub(" ", text)
    return _WHITESPACE.sub(" ", text).strip()
