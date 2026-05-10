#!/usr/bin/env python3
import csv
import sqlite3
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo


ROOT_DIR = Path(__file__).resolve().parents[3]
RUNS_DIR = ROOT_DIR / "results/pyrit"
OUTPUT = ROOT_DIR / "results/reports/pyrit_guardrail_summary.csv"
LOCAL_TZ = ZoneInfo("Europe/Budapest")

RUN_IDS = [
    "deepseek-v3.1__no_system_prompt__guardrail_defaultV2__pyrit_guardrail_benchmark__20260501-225817",
    "deepseek-v3.1__no_system_prompt__guardrail_strict__pyrit_guardrail_benchmark__20260502-091040",
    "gpt-4.1__no_system_prompt__guardrail_defaultV2__pyrit_guardrail_benchmark__20260501-222347",
    "gpt-4.1__no_system_prompt__guardrail_strict__pyrit_guardrail_benchmark__20260502-084811",
    "grok-4-1-fast-non-reasoning__no_system_prompt__guardrail_defaultV2__pyrit_guardrail_benchmark__20260502-013642",
    "grok-4-1-fast-non-reasoning__no_system_prompt__guardrail_strict__pyrit_guardrail_benchmark__20260502-110934",
    "mistral-large-3__no_system_prompt__guardrail_defaultV2__pyrit_guardrail_benchmark__20260502-003433",
    "mistral-large-3__no_system_prompt__guardrail_strict__pyrit_guardrail_benchmark__20260502-100829",
]

SCENARIOS = {
    "airt.jailbreak": ["prompt_sending", "skeleton", "many_shot"],
    "airt.leakage": ["first_letter"],
    "garak.encoding": ["base64", "rot13", "leet_speak", "morse_code", "ascii_smuggler"],
}
VALID_STRATEGIES = {(scenario, strategy) for scenario, strategies in SCENARIOS.items() for strategy in strategies}

FIELDS = [
    "level",
    "model",
    "guardrail_profile",
    "scenario",
    "strategy",
    "run_id",
    "ok_strategies",
    "expected_strategies",
    "total_records",
    "attack_successes",
    "attack_success_rate",
    "blocked_or_empty",
    "blocked_or_empty_rate",
]


def run_info(run_dir):
    model, _system_prompt, guardrail, test_group, timestamp = run_dir.name.split("__")
    return {
        "model": model,
        "guardrail_profile": guardrail,
        "test_group": test_group,
        "timestamp": timestamp,
    }


def rate(numerator, denominator):
    if denominator == 0:
        return ""
    return f"{numerator / denominator:.6f}"


def selected_run_dirs():
    run_dirs = []
    for run_id in RUN_IDS:
        model = run_id.split("__")[0]
        run_dirs.append(RUNS_DIR / model / "final" / run_id)
    return run_dirs


def load_strategy_windows(run_dir):
    windows = []
    with (run_dir / "meta/summary.csv").open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            scenario = row["scenario"]
            strategy = row["strategy"]
            if row["status"] == "ok" and (scenario, strategy) in VALID_STRATEGIES:
                windows.append(
                    (
                        datetime.fromisoformat(row["start_ts"]),
                        datetime.fromisoformat(row["end_ts"]),
                        scenario,
                        strategy,
                    )
                )
    return windows


def pyrit_timestamp(value):
    return datetime.fromisoformat(value).replace(tzinfo=timezone.utc).astimezone(LOCAL_TZ)


def find_strategy(timestamp, windows):
    for start, end, scenario, strategy in windows:
        if start <= timestamp <= end:
            return scenario, strategy
    return None


def count_run(run_dir):
    counts = defaultdict(Counter)
    windows = load_strategy_windows(run_dir)

    query = """
        select
            a.outcome,
            a.timestamp,
            m.response_error,
            m.original_value
        from AttackResultEntries a
        left join PromptMemoryEntries m
            on m.id = a.last_response_id
    """

    with sqlite3.connect(run_dir / "state/dbdata/pyrit.db") as connection:
        connection.row_factory = sqlite3.Row
        for row in connection.execute(query):
            label = find_strategy(pyrit_timestamp(row["timestamp"]), windows)
            if label is None:
                continue

            item = counts[label]
            item["total_records"] += 1
            item["attack_successes"] += int(row["outcome"] == "success")

            response_error = row["response_error"]
            response_text = row["original_value"] or ""
            blocked_or_empty = response_error not in (None, "", "none") or not response_text.strip()
            item["blocked_or_empty"] += int(blocked_or_empty)

    return counts


def add_row(rows, level, meta, run_id, scenario, strategy, counts, ok_strategies, expected_strategies):
    total = counts["total_records"]
    successes = counts["attack_successes"]
    blocked = counts["blocked_or_empty"]

    rows.append(
        {
            "level": level,
            "model": meta["model"],
            "guardrail_profile": meta["guardrail_profile"],
            "scenario": scenario,
            "strategy": strategy,
            "run_id": run_id,
            "ok_strategies": ok_strategies,
            "expected_strategies": expected_strategies,
            "total_records": total,
            "attack_successes": successes,
            "attack_success_rate": rate(successes, total),
            "blocked_or_empty": blocked,
            "blocked_or_empty_rate": rate(blocked, total),
        }
    )


def rows_for_run(run_dir):
    meta = run_info(run_dir)
    counts = count_run(run_dir)
    rows = []

    for (scenario, strategy), item in sorted(counts.items()):
        add_row(rows, "strategy", meta, run_dir.name, scenario, strategy, item, 1, 1)

    scenario_totals = defaultdict(Counter)
    overall = Counter()
    for (scenario, _strategy), item in counts.items():
        scenario_totals[scenario].update(item)
        overall.update(item)

    for scenario, item in sorted(scenario_totals.items()):
        ok_count = sum(1 for key in counts if key[0] == scenario)
        add_row(rows, "scenario", meta, run_dir.name, scenario, "__all__", item, ok_count, len(SCENARIOS[scenario]))

    expected_total = sum(len(strategies) for strategies in SCENARIOS.values())
    add_row(rows, "overall", meta, run_dir.name, "__all__", "__all__", overall, len(counts), expected_total)
    return rows


def main():
    rows = []
    for run_dir in selected_run_dirs():
        rows.extend(rows_for_run(run_dir))

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {OUTPUT} ({len(rows)} rows)")


if __name__ == "__main__":
    main()
