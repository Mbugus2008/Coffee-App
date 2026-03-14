import argparse
import sqlite3


def main() -> int:
    parser = argparse.ArgumentParser(description="Check users table password + Updated flag")
    parser.add_argument("db", help="Path to SQLite database")
    args = parser.parse_args()

    con = sqlite3.connect(args.db)
    cur = con.cursor()

    # Print schema
    cols = cur.execute("PRAGMA table_info('users')").fetchall()
    print("users columns:")
    for c in cols:
        # (cid, name, type, notnull, dflt_value, pk)
        print(c)

    try:
        rows = cur.execute(
            "SELECT id, username, name, length(password) AS password_len, Updated FROM users ORDER BY id DESC LIMIT 50"
        ).fetchall()
    except sqlite3.OperationalError as e:
        print("query failed:", e)
        rows = cur.execute(
            "SELECT id, username, name, length(password) AS password_len FROM users ORDER BY id DESC LIMIT 50"
        ).fetchall()

    print("\nrows:")
    for r in rows:
        print(r)

    con.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
