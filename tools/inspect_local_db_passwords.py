import argparse
import sqlite3
from typing import Any


def is_present(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, (bytes, bytearray)):
        return len(value) > 0
    text = str(value).strip()
    return text != "" and text.lower() != "null"


def quote_ident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Inspect a local SQLite DB and report whether password-related columns are empty/present "
            "(does not print password values)."
        )
    )
    parser.add_argument("db", help="Path to SQLite database file")
    parser.add_argument("--limit", type=int, default=200, help="Row limit per table")
    args = parser.parse_args()

    con = sqlite3.connect(args.db)
    cur = con.cursor()

    tables = [
        r[0]
        for r in cur.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
        ).fetchall()
    ]
    print("tables:", tables)

    def get_cols(table: str) -> list[str]:
        return [r[1] for r in cur.execute(f"PRAGMA table_info({quote_ident(table)})").fetchall()]

    pass_tables: list[tuple[str, list[str], list[str]]] = []
    for table in tables:
        cols = get_cols(table)
        pass_cols = [c for c in cols if "pass" in c.lower()]
        if pass_cols:
            pass_tables.append((table, cols, pass_cols))

    print("tables_with_pass_cols:", [(t, pc) for (t, _, pc) in pass_tables])

    preferred_idents = [
        "id",
        "userId",
        "userid",
        "user_id",
        "username",
        "user_name",
        "name",
        "fullName",
        "displayName",
        "email",
    ]

    for (table, cols, pass_cols) in pass_tables:
        print(f"\n=== {table} ===")
        lower_to_actual = {c.lower(): c for c in cols}

        ident_cols: list[str] = []
        for preferred in preferred_idents:
            actual = lower_to_actual.get(preferred.lower())
            if actual and actual not in ident_cols:
                ident_cols.append(actual)

        if not ident_cols:
            non_pass_cols = [c for c in cols if c not in pass_cols]
            ident_cols = non_pass_cols[:3]

        select_cols = ident_cols + pass_cols
        select_expr = ", ".join(quote_ident(c) for c in select_cols)
        sql = f"SELECT {select_expr} FROM {quote_ident(table)} LIMIT {int(args.limit)}"

        rows = cur.execute(sql).fetchall()
        print("columns:", select_cols)
        if not rows:
            print("(no rows)")
            continue

        for row in rows:
            record = {select_cols[i]: row[i] for i in range(len(select_cols))}
            summary: dict[str, Any] = {c: record.get(c) for c in ident_cols}
            for pc in pass_cols:
                v = record.get(pc)
                summary[f"{pc}_present"] = is_present(v)
                if v is None:
                    summary[f"{pc}_len"] = 0
                elif isinstance(v, (bytes, bytearray)):
                    summary[f"{pc}_len"] = len(v)
                else:
                    summary[f"{pc}_len"] = len(str(v))
            print(summary)

    con.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
