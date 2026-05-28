#!/usr/bin/env python3
"""Import farmers from CSV into BC ODataV4 Farmers endpoint (multi-threaded)."""

import csv
import base64
import json
import sys
import time
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed

CSV_PATH = r"C:\Users\mbugu\Downloads\members_export_1779952342993.csv"
ENDPOINT = "http://test.trimline.co.ke:4548/BC240/ODataV4/Company('Rugi')/Farmers"
USERNAME = "Philip"
PASSWORD = "Password@2030"
MAX_WORKERS = 20


def make_auth_header():
    creds = base64.b64encode(f"{USERNAME}:{PASSWORD}".encode()).decode()
    return {"Authorization": f"Basic {creds}", "Content-Type": "application/json"}


AUTH_HEADER = make_auth_header()


def post_farmer(payload):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        ENDPOINT,
        data=data,
        headers=AUTH_HEADER,
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, ""
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        # If already exists, try PATCH instead
        if "already exists" in body.lower() or "EntityWithSameKeyExists" in body:
            no = payload.get("No", "").replace("'", "''")
            patch_url = f"{ENDPOINT}('{no}')"
            patch_req = urllib.request.Request(
                patch_url,
                data=data,
                headers={**AUTH_HEADER, "If-Match": "*"},
                method="PATCH",
            )
            try:
                with urllib.request.urlopen(patch_req, timeout=30) as resp:
                    return resp.status, ""
            except urllib.error.HTTPError as pe:
                return pe.code, pe.read().decode("utf-8")[:300]
            except Exception as pe:
                return 0, str(pe)[:300]
        return e.code, body[:300]
    except Exception as e:
        return 0, str(e)[:300]


def parse_acreage(value):
    try:
        return float(value.strip()) if value else 0
    except (ValueError, AttributeError):
        return 0


def parse_trees(value):
    try:
        return int(float(value.strip())) if value else 0
    except (ValueError, AttributeError):
        return 0


def row_to_payload(row):
    return {
        "No": (row.get("Member Number") or "").strip(),
        "Name": (row.get("Full Name") or "").strip(),
        "ID_No": (row.get("ID Number") or "").strip(),
        "Phone_No": (row.get("Phone Number") or "").strip(),
        "Global_Dimension_Code": (row.get("Zone") or "").strip(),
        "Acreage": parse_acreage(row.get("Acreage")),
        "No_of_Trees": parse_trees(row.get("Number of Trees")),
    }


def import_one(args):
    idx, total, row = args
    payload = row_to_payload(row)
    if not payload["No"]:
        return idx, "SKIP", "empty Member Number", None

    status, body = post_farmer(payload)
    if status in (200, 201, 204):
        return idx, "OK", payload["No"], payload["Name"]
    else:
        return idx, "FAIL", payload["No"], f"{status}: {body}"


def main(limit=None):
    rows = []
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)
            if limit and len(rows) >= limit:
                break

    total = len(rows)
    print(f"Read {total} rows from CSV")
    print(f"Importing with {MAX_WORKERS} parallel threads...\n")

    success = 0
    failed = 0
    skipped = 0
    errors = []
    start = time.time()

    tasks = [(i + 1, total, row) for i, row in enumerate(rows)]

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        future_map = {executor.submit(import_one, t): t for t in tasks}
        completed = 0
        for future in as_completed(future_map):
            idx, status, info, detail = future.result()
            completed += 1
            if status == "OK":
                success += 1
            elif status == "SKIP":
                skipped += 1
            else:
                failed += 1
                errors.append(f"[{idx}] {info} - {detail}")

            if completed % 500 == 0 or completed == total:
                elapsed = time.time() - start
                rate = completed / elapsed if elapsed > 0 else 0
                remaining = (total - completed) / rate if rate > 0 else 0
                print(
                    f"[{completed}/{total}] OK:{success} Fail:{failed} Skip:{skipped} "
                    f"| {rate:.1f}/s | ~{remaining/60:.1f}min left"
                )

    elapsed = time.time() - start
    print(f"\nDone in {elapsed/60:.1f} minutes.")
    print(f"Success: {success}, Failed: {failed}, Skipped: {skipped}, Total: {total}")

    if errors:
        with open("import_errors.log", "w", encoding="utf-8") as f:
            f.write("\n".join(errors))
        print(f"Errors written to import_errors.log ({len(errors)} lines)")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--full":
        main()
    else:
        print("=== TEST RUN (first 5 rows) ===")
        main(limit=5)
        print("\nRun with --full flag to import all rows.")
