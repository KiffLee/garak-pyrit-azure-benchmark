#!/usr/bin/env python3
import csv
from collections import defaultdict
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[4]
RUN_SUMMARY = ROOT_DIR / "results/reports/garak_system_prompt/run_summary.csv"
PROMPT_COMPARISON = ROOT_DIR / "results/reports/garak_system_prompt/system_prompt_comparison.csv"
OUTPUT = ROOT_DIR / "results/reports/garak_system_prompt/summary_notes.md"


def read_csv(path):
    with Path(path).open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def mean(values):
    values = [value for value in values if value is not None]
    if not values:
        return None
    return sum(values) / len(values)


def as_float(value):
    if value == "" or value is None:
        return None
    return float(value)


def fmt(value):
    if value is None:
        return "n/a"
    return f"{value:.3f}"


def main():
    runs = read_csv(RUN_SUMMARY)
    comparisons = read_csv(PROMPT_COMPARISON)

    prompts = sorted({row["system_prompt"] for row in runs})
    models = sorted({row["model"] for row in runs})
    test_types = sorted({row["test_type"] for row in runs})

    asr_by_prompt = defaultdict(list)
    filter_by_prompt = defaultdict(list)
    for row in runs:
        asr_by_prompt[row["system_prompt"]].append(as_float(row["attack_success_rate_scored"]))
        filter_by_prompt[row["system_prompt"]].append(as_float(row["azure_content_filter_rate"]))

    lines = [
        "# Garak system prompt osszesites",
        "",
        "Ez az osszesites a vegleges Garak futasokbol keszult.",
        "A Garak meresekben a guardrail beallitas kontrollalt korulmeny, minden futas guardrail_defaultV2 profillal szerepel.",
        "A fo osszehasonlitasi dimenzio a system prompt.",
        "",
        "## Adatkor",
        "",
        f"- Futások száma: {len(runs)}",
        f"- Modellek száma: {len(models)}",
        f"- System promptok száma: {len(prompts)}",
        f"- Teszttípusok száma: {len(test_types)}",
        "",
        "## Atlagos tamadasi sikeresseg system prompt szerint",
        "",
    ]

    for prompt in prompts:
        lines.append(
            f"- {prompt}: ASR={fmt(mean(asr_by_prompt[prompt]))}, "
            f"Azure content filter rate={fmt(mean(filter_by_prompt[prompt]))}"
        )

    lines.extend(
        [
            "",
            "## Ertelmezesi szabalyok",
            "",
            "- Az attack_success_rate_scored a fo Garak biztonsagi mutato.",
            "- Az azure_content_filter_rate Azure vedelmi beavatkozasi mutato, nem modellvalasz-minosegi pontszam.",
            "- A system_security_hardened_no_code prompt kiegeszito kiserletkent kezelendo.",
            "- A compare tablaban a negativ absolute_delta javulast jelent a baseline prompttal szemben.",
            "",
            "## Kimeneti fajlok",
            "",
            "- run_summary.csv: egy sor egy Garak futas.",
            "- system_prompt_comparison.csv: baseline-hoz viszonyitott prompt hatas.",
            "- probe_summary.csv: probe szintu Garak detector bontas.",
            "",
            f"System prompt osszehasonlito sorok szama: {len(comparisons)}",
            "",
        ]
    )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
