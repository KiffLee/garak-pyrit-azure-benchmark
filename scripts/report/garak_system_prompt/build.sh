#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

RUNS_DIR="${ROOT_DIR}/results/garak/runs"
OUT_DIR="${ROOT_DIR}/results/reports/garak_system_prompt"

mkdir -p "${OUT_DIR}"

echo "Garak system prompt reports"
echo "Input : ${RUNS_DIR}"
echo "Output: ${OUT_DIR}"
echo

python3 "${SCRIPT_DIR}/summarize_runs.py"

python3 "${SCRIPT_DIR}/compare_system_prompts.py"

python3 "${SCRIPT_DIR}/summarize_probes.py"

python3 "${SCRIPT_DIR}/write_summary_notes.py"

echo
echo "Done."
