from __future__ import annotations

import unittest

from tools.signpuddle.normalize import normalize


class NormalizeTest(unittest.TestCase):
    def test_removes_accents_case_and_punctuation(self) -> None:
        self.assertEqual(normalize("Água"), "agua")
        self.assertEqual(normalize("  Queda-d'água (1) "), "queda d agua 1")
        self.assertEqual(normalize("AÇÃO"), "acao")
        self.assertEqual(normalize("ser  humano"), "ser humano")
        self.assertEqual(normalize(None), "")

    def test_at_sign_becomes_o(self) -> None:
        self.assertEqual(normalize("amig@"), "amigo")
        self.assertEqual(normalize("casa@"), "casao")

    def test_matches_dart_examples(self) -> None:
        self.assertEqual(normalize("PÃO-de-AÇÚCAR"), "pao de acucar")


if __name__ == "__main__":
    unittest.main()
