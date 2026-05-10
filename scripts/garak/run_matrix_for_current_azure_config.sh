#!/usr/bin/env bash
set -euo pipefail

# A megadott Garak suite futtatasa a negy dolgozatban hasznalt modellen.
# Az Azure deploymenteket es guardraileket futtatas elott kezzel kell beallitani.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SUITE_FILE=""
SYSTEM_PROMPT_PROFILE=""
GUARDRAIL_PROFILE=""
GUARDRAIL_POLICY_NAME=""

usage() {
  cat <<'EOF' >&2
Hasznalat:
  bash scripts/garak/run_matrix_for_current_azure_config.sh \
    --suite-file configs/garak/suites/foundry-01-direct-safety.txt \
    --system-prompt-profile system_standard_chatbot_safety \
    --guardrail-profile guardrail_defaultV2 \
    [--guardrail-policy-name defaultV2]
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --suite-file) SUITE_FILE="${2:-}"; shift 2 ;;
    --system-prompt-profile) SYSTEM_PROMPT_PROFILE="${2:-}"; shift 2 ;;
    --guardrail-profile) GUARDRAIL_PROFILE="${2:-}"; shift 2 ;;
    --guardrail-policy-name) GUARDRAIL_POLICY_NAME="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Ismeretlen argumentum: $1" >&2; usage ;;
  esac
done

[[ -n "${SUITE_FILE}" && -n "${SYSTEM_PROMPT_PROFILE}" && -n "${GUARDRAIL_PROFILE}" ]] || usage

GUARDRAIL_POLICY_NAME="${GUARDRAIL_POLICY_NAME:-${GUARDRAIL_PROFILE}}"
RUN_TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

MODELS=(
  "${ROOT_DIR}/configs/garak/models/gpt-4.1.env"
  "${ROOT_DIR}/configs/garak/models/deepseek-v3.1.env"
  "${ROOT_DIR}/configs/garak/models/mistral-large-3.env"
  "${ROOT_DIR}/configs/garak/models/grok-4-1-fast-non-reasoning.env"
)

FAILED=0
TOTAL=0

echo "[matrix] Kozos timestamp: ${RUN_TIMESTAMP}"
echo "[matrix] Suite: ${SUITE_FILE}"
echo "[matrix] System prompt: ${SYSTEM_PROMPT_PROFILE}"
echo "[matrix] Guardrail: ${GUARDRAIL_PROFILE} (${GUARDRAIL_POLICY_NAME})"
echo ""

for env_file in "${MODELS[@]}"; do
  label="$(basename "${env_file}" .env)"

  TOTAL=$((TOTAL + 1))
  echo "[matrix] Indul: ${label}"

  if TIMESTAMP="${RUN_TIMESTAMP}" bash "${SCRIPT_DIR}/run_model.sh" \
      --env-file "${env_file}" \
      --suite-file "${SUITE_FILE}" \
      --system-prompt-profile "${SYSTEM_PROMPT_PROFILE}" \
      --guardrail-profile "${GUARDRAIL_PROFILE}" \
      --guardrail-policy-name "${GUARDRAIL_POLICY_NAME}"; then
    echo "[matrix] OK: ${label}"
  else
    echo "[matrix] HIBA: ${label}" >&2
    FAILED=$((FAILED + 1))
  fi

  echo ""
done

echo "================================================================"
echo "Matrix futes kesz."
echo "Osszes:     ${TOTAL}"
echo "Sikertelen: ${FAILED}"
echo "================================================================"

if [[ "${FAILED}" -gt 0 ]]; then
  exit 1
fi
