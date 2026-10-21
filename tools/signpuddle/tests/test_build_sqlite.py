from __future__ import annotations

import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

from tools.signpuddle.build_sqlite import build_database
from tools.signpuddle.signpuddle_api import svg_url

SAMPLE = {
    "name": "bzs-BR-dictionary-public",
    "data": [
        {
            "id": 1,
            "sign": "𝠀sinal-agua",
            "terms": ["água", "water"],
            "signtext": "",
            "text": "Líquido",
            "source": "Fonte A",
            "detail": {"video": "https://example.com/video"},
            "user": "colaborador",
            "created_at": "2020-01-01T00:00:00Z",
            "updated_at": "2021-01-01T00:00:00Z",
        },
        {
            "id": 2,
            "sign": "",
            "terms": ["pecar"],
            "signtext": "𝠀signtext",
            "text": "",
            "source": "",
            "detail": {},
            "user": "outro",
            "created_at": "2020-01-01T00:00:00Z",
            "updated_at": "2020-01-01T00:00:00Z",
        },
    ],
}


class BuildSqliteTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp.name) / "signpuddle.db"
        self.stats = build_database(SAMPLE, self.db_path)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.db_path)
        connection.row_factory = sqlite3.Row
        return connection

    def test_stats_and_meta(self) -> None:
        self.assertEqual(self.stats.entries, 2)
        self.assertEqual(self.stats.terms, 3)
        self.assertEqual(self.stats.with_image, 2)
        self.assertEqual(self.stats.with_description, 1)

        with self.connect() as connection:
            meta = dict(connection.execute("SELECT key, value FROM meta"))
        self.assertEqual(meta["dictionary"], "bzs-BR-dictionary-public")
        self.assertEqual(meta["entries"], "2")
        self.assertEqual(meta["schema_version"], "1")

    def test_exact_and_prefix_search(self) -> None:
        with self.connect() as connection:
            exact = connection.execute(
                """
                SELECT s.id, s.title
                FROM signs s
                JOIN terms t ON t.sign_id = s.id
                WHERE t.term_norm = ?
                """,
                ("agua",),
            ).fetchall()
            prefix = connection.execute(
                """
                SELECT s.id, s.title
                FROM signs s
                JOIN terms t ON t.sign_id = s.id
                WHERE t.term_norm LIKE ?
                """,
                ("pec%",),
            ).fetchall()
        self.assertEqual([row["id"] for row in exact], [1])
        self.assertEqual(exact[0]["title"], "água")
        self.assertEqual([row["id"] for row in prefix], [2])

    def test_fts_and_signtext_fallback(self) -> None:
        with self.connect() as connection:
            fts = connection.execute(
                """
                SELECT DISTINCT s.id
                FROM terms_fts f
                JOIN terms t ON t.rowid = f.rowid
                JOIN signs s ON s.id = t.sign_id
                WHERE terms_fts MATCH ?
                """,
                ("water*",),
            ).fetchall()
            row = connection.execute(
                "SELECT swu, is_signtext FROM signs WHERE id = 2"
            ).fetchone()
        self.assertEqual([item["id"] for item in fts], [1])
        self.assertEqual(row["swu"], "𝠀signtext")
        self.assertEqual(row["is_signtext"], 1)

    def test_svg_url_encodes_unicode(self) -> None:
        url = svg_url("𝠀água")
        self.assertTrue(url.startswith("https://signpuddle.com/server/swu/svg/"))
        self.assertNotIn("𝠀", url)


if __name__ == "__main__":
    unittest.main()
