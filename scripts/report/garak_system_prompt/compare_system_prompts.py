#!/usr/bin/env python3
import csv
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[4]
INPUT = ROOT_DIR / "results/reports/garak_system_prompt/run_summary.csv"
OUTPUT = ROOT_DIR / "results/reports/garak_system_prompt/system_prompt_comparison.csv"
BASELINE_PROMPT = "system_baseline_minimal"

FIELDS = [
    "model",
    "guardrail",
    "test_type",
    "candidate_system_prompt",
    "baseline_attack_success_rate",
    "candidate_attack_success_rate",
    "absolute_delta",
    "relative_reduction",
    "baseline_content_filter_rate",
    "candidate_content_filter_rate",
    "content_filter_delta",
    "answer_rate_delta",
]


def as_float(value):
    if value == "" or value is None:
        return None
    return float(value)


def fmt(value):
    if value is None:
        return ""
    return f"{value:.6f}"


def delta(candidate, baseline):
    if candidate is None or baseline is None:
        return None
    return candidate - baseline


def relative_reduction(candidate, baseline):
    if candidate is None or baseline in (None, 0):
        return None
    return (baseline - candidate) / baseline


def main():
    with INPUT.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))

    by_key = {}
    for row in rows:
        key = (row["model"], row["guardrail"], row["test_type"])
        by_key.setdefault(key, {})[row["system_prompt"]] = row

    out_rows = []
    for key, prompts in sorted(by_key.items()):
        baseline = prompts.get(BASELINE_PROMPT)
        if baseline is None:
            continue

        baseline_asr = as_float(baseline["attack_success_rate_scored"])
        baseline_filter = as_float(baseline["azure_content_filter_rate"])
        baseline_answer = as_float(baseline["answer_rate"])

        for prompt, row in sorted(prompts.items()):
            if prompt == BASELINE_PROMPT:
                continue

            candidate_asr = as_float(row["attack_success_rate_scored"])
            candidate_filter = as_float(row["azure_content_filter_rate"])
            candidate_answer = as_float(row["answer_rate"])

            out_rows.append(
                {
                    "model": key[0],
                    "guardrail": key[1],
                    "test_type": key[2],
                    "candidate_system_prompt": prompt,
                    "baseline_attack_success_rate": fmt(baseline_asr),
                    "candidate_attack_success_rate": fmt(candidate_asr),
                    "absolute_delta": fmt(delta(candidate_asr, baseline_asr)),
                    "relative_reduction": fmt(relative_reduction(candidate_asr, baseline_asr)),
                    "baseline_content_filter_rate": fmt(baseline_filter),
                    "candidate_content_filter_rate": fmt(candidate_filter),
                    "content_filter_delta": fmt(delta(candidate_filter, baseline_filter)),
                    "answer_rate_delta": fmt(delta(candidate_answer, baseline_answer)),
                }
            )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(out_rows)


if __name__ == "__main__":
    main()
