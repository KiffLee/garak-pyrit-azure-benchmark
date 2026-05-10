#!/usr/bin/env bash
set -euo pipefail

# A PyRIT guardrail benchmark futtatasa a negy dolgozatban hasznalt modellen.
# Az Azure guardrail profilt futtatas elott kezzel kell beallitani.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Hasznalt hivas:
#   bash scripts/pyrit/run_matrix_for_current_azure_config.sh --mode final --guardrail-profile guardrail_defaultV2 --guardrail-policy-name defaultV2
#   bash scripts/pyrit/run_matrix_for_current_azure_config.sh --mode final --guardrail-profile guardrail_strict --guardrail-policy-name strict
MODE="$2"
GUARDRAIL_PROFILE="$4"
GUARDRAIL_POLICY_NAME="$6"

MODELS=(
  "${ROOT_DIR}/configs/pyrit/models/gpt-4.1.env"
  "${ROOT_DIR}/configs/pyrit/models/deepseek-v3.1.env"
  "${ROOT_DIR}/configs/pyrit/models/mistral-large-3.env"
  "${ROOT_DIR}/configs/pyrit/models/grok-4-1-fast-non-reasoning.env"
)

FAILED=0
TOTAL=0

for env_file in "${MODELS[@]}"; do
  label="$(basename "${env_file}" .env)"

  TOTAL=$((TOTAL + 1))
  echo ""
  echo "================================================================"
  echo "Modell: ${label}"
  echo "Mode:   ${MODE}"
  echo "Sys:    no_system_prompt"
  echo "Guard:  ${GUARDRAIL_PROFILE}"
  echo "================================================================"

  if bash "${SCRIPT_DIR}/run_pyrit.sh" \
      "${MODE}" \
      "${env_file}" \
      --guardrail-profile "${GUARDRAIL_PROFILE}" \
      --guardrail-policy-name "${GUARDRAIL_POLICY_NAME}"; then
    echo "OK: ${label}"
  else
    echo "HIBA: ${label}" >&2
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "================================================================"
echo "PyRIT matrix futes kesz."
echo "Osszes:     ${TOTAL}"
echo "Sikertelen: ${FAILED}"
echo "================================================================"

if [[ ${FAILED} -gt 0 ]]; then
  exit 1
fi
