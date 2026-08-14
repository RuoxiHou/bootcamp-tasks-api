#!/usr/bin/env python3
"""Create Tasks API records from tasks_labeled.csv."""

import argparse
import csv
import json
import sys
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

DEFAULT_API_URL = "https://api.ruoxi-projects.space"
DEFAULT_CSV_PATH = Path(__file__).with_name("tasks_labeled.csv")
VALID_PRIORITIES = {"low", "medium", "high"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="POST every task in a labeled CSV file to the Tasks API."
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=DEFAULT_CSV_PATH,
        help=f"CSV input path (default: {DEFAULT_CSV_PATH})",
    )
    parser.add_argument(
        "--api-url",
        default=DEFAULT_API_URL,
        help=f"Tasks API base URL (default: {DEFAULT_API_URL})",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=15.0,
        help="Request timeout in seconds (default: 15)",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=0.0,
        help="Delay between requests in seconds (default: 0)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate and count records without sending requests",
    )
    return parser.parse_args()


def load_tasks(csv_path: Path) -> list[dict[str, object]]:
    tasks: list[dict[str, object]] = []

    with csv_path.open(encoding="utf-8", newline="") as csv_file:
        reader = csv.DictReader(csv_file)
        required_columns = {"title", "description", "priority"}
        missing_columns = required_columns.difference(reader.fieldnames or [])
        if missing_columns:
            missing = ", ".join(sorted(missing_columns))
            raise ValueError(f"CSV is missing required columns: {missing}")

        for row_number, row in enumerate(reader, start=2):
            title = (row.get("title") or "").strip()
            description = (row.get("description") or "").strip()
            priority = (row.get("priority") or "").strip().lower()

            if not title:
                raise ValueError(f"Row {row_number} has an empty title")
            if priority not in VALID_PRIORITIES:
                raise ValueError(
                    f"Row {row_number} has invalid priority {priority!r}; "
                    f"expected one of {sorted(VALID_PRIORITIES)}"
                )

            tasks.append(
                {
                    "title": title,
                    "description": description or None,
                    "priority": priority,
                    "done": False,
                }
            )

    return tasks


def create_task(endpoint: str, task: dict[str, object], timeout: float) -> int:
    request = Request(
        endpoint,
        data=json.dumps(task).encode("utf-8"),
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        method="POST",
    )

    with urlopen(request, timeout=timeout) as response:
        body = json.load(response)
        if response.status != 201:
            raise RuntimeError(f"unexpected HTTP status {response.status}")
        return int(body["id"])


def main() -> int:
    args = parse_args()

    if args.timeout <= 0:
        print("error: --timeout must be greater than zero", file=sys.stderr)
        return 2
    if args.delay < 0:
        print("error: --delay cannot be negative", file=sys.stderr)
        return 2

    try:
        tasks = load_tasks(args.csv)
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    if args.dry_run:
        print(f"Validated {len(tasks)} records from {args.csv}; no requests sent.")
        return 0

    endpoint = f"{args.api_url.rstrip('/')}/tasks"
    created = 0
    failures: list[tuple[int, str]] = []

    print(f"Creating {len(tasks)} tasks through {endpoint}")
    print("Warning: the API does not de-duplicate records; reruns create duplicates.")

    for index, task in enumerate(tasks, start=1):
        try:
            task_id = create_task(endpoint, task, args.timeout)
            created += 1
            print(f"[{index}/{len(tasks)}] created task id={task_id}")
        except HTTPError as error:
            details = error.read().decode("utf-8", errors="replace")
            failures.append((index, f"HTTP {error.code}: {details}"))
            print(f"[{index}/{len(tasks)}] failed: HTTP {error.code}", file=sys.stderr)
        except (OSError, ValueError, RuntimeError) as error:
            failures.append((index, str(error)))
            print(f"[{index}/{len(tasks)}] failed: {error}", file=sys.stderr)

        if args.delay and index < len(tasks):
            time.sleep(args.delay)

    print(f"Finished: {created} created, {len(failures)} failed.")
    for index, reason in failures:
        print(f"  row {index + 1}: {reason}", file=sys.stderr)

    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
