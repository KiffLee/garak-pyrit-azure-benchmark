#!/usr/bin/env bash
set -euo pipefail

# Egy Garak futas egy model env fajllal, egy suite-tal es egy system prompttal.
# <model>__<system_prompt>__<guardrail>__garak_<test_group>__<timestamp>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

IMAGE_TAG="${IMAGE_TAG:-garak-azure:0.1.0}"
OUTPUT_ROOT="${OUTPUT_ROOT:-${ROOT_DIR}/results}"
GENERATIONS="${GENERATIONS:-1}"
PARALLEL_ATTEMPTS="${PARALLEL_ATTEMPTS:-4}"
TIMESTAMP="${TIMESTAMP:-$(date +%Y%m%d-%H%M%S)}"
MAX_TOKENS="${MAX_TOKENS:-}"

ENV_FILE=""
SUITE_FILE=""
SYSTEM_PROMPT_PROFILE=""
GUARDRAIL_PROFILE=""
GUARDRAIL_POLICY_NAME=""

usage() {
  cat <<'EOF' >&2
Hasznalat:
  bash scripts/garak/run_model.sh \
    --env-file configs/garak/models/gpt-4.1.env \
    --suite-file configs/garak/suites/foundry-01-direct-safety.txt \
    --system-prompt-profile system_standard_chatbot_safety \
    --guardrail-profile guardrail_defaultV2 \
    [--guardrail-policy-name defaultV2]
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file) ENV_FILE="${2:-}"; shift 2 ;;
    --suite-file) SUITE_FILE="${2:-}"; shift 2 ;;
    --system-prompt-profile) SYSTEM_PROMPT_PROFILE="${2:-}"; shift 2 ;;
    --guardrail-profile) GUARDRAIL_PROFILE="${2:-}"; shift 2 ;;
    --guardrail-policy-name) GUARDRAIL_POLICY_NAME="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Ismeretlen argumentum: $1" >&2; usage ;;
  esac
done

[[ -n "${ENV_FILE}" && -n "${SUITE_FILE}" && -n "${SYSTEM_PROMPT_PROFILE}" && -n "${GUARDRAIL_PROFILE}" ]] || usage

GUARDRAIL_POLICY_NAME="${GUARDRAIL_POLICY_NAME:-${GUARDRAIL_PROFILE}}"
SYSTEM_PROMPT_FILE="${ROOT_DIR}/configs/benchmark/system-prompts/${SYSTEM_PROMPT_PROFILE}.txt"

MODEL_NAME="$(awk -F= '$1=="OPENAICOMPATIBLE_MODEL"{print $2; exit}' "${ENV_FILE}")"
BASE_URL="$(awk -F= '$1=="OPENAICOMPATIBLE_URI"{print $2; exit}' "${ENV_FILE}")"

SUITE_NAME="$(basename "${SUITE_FILE%.*}")"
TEST_GROUP="$(echo "${SUITE_NAME}" | sed 's/^foundry-[0-9]*-//' | tr '-' '_')"
if [[ -z "${MAX_TOKENS}" ]]; then
  if [[ "${SUITE_NAME}" == "smoke" ]]; then
    MAX_TOKENS=200
  else
    MAX_TOKENS=1000
  fi
fi

PROBES="$(awk 'NF && $1 !~ /^#/ { print }' "${SUITE_FILE}" | paste -sd, -)"

RUN_ID="${MODEL_NAME}__${SYSTEM_PROMPT_PROFILE}__${GUARDRAIL_PROFILE}__garak_${TEST_GROUP}__${TIMESTAMP}"
RUN_DIR="${OUTPUT_ROOT}/garak/runs/${RUN_ID}"
META_DIR="${RUN_DIR}/meta"
LOG_DIR="${OUTPUT_ROOT}/logs"
LOG_PATH="${LOG_DIR}/${RUN_ID}.log"

mkdir -p "${META_DIR}" "${LOG_DIR}"

cat > "${META_DIR}/run-info.json" <<RUNINFO
{
  "run_id": "${RUN_ID}",
  "model": "${MODEL_NAME}",
  "model_profile": "chat_completion_benchmark",
  "system_prompt_profile": "${SYSTEM_PROMPT_PROFILE}",
  "system_prompt_sent_by_tool": true,
  "guardrail_profile": "${GUARDRAIL_PROFILE}",
  "guardrail_policy_name": "${GUARDRAIL_POLICY_NAME}",
  "guardrail_manual_in_foundry": true,
  "configuration_confirmed_at": "$(date -Iseconds)",
  "suite": "${SUITE_NAME}",
  "test_group": "${TEST_GROUP}",
  "image": "${IMAGE_TAG}",
  "generations": ${GENERATIONS},
  "parallel_attempts": ${PARALLEL_ATTEMPTS},
  "max_tokens": ${MAX_TOKENS},
  "temperature": 0.2,
  "timestamp": "${TIMESTAMP}"
}
RUNINFO

cat > "${META_DIR}/model-params.json" <<PARAMS
{
  "deployment": "${MODEL_NAME}",
  "profile": "chat_completion_benchmark",
  "token_limit_parameter": "max_tokens",
  "output_token_limit": ${MAX_TOKENS},
  "temperature_sent": true,
  "temperature": 0.2,
  "top_p_sent": false,
  "frequency_penalty_sent": false,
  "presence_penalty_sent": false,
  "stop_sent": false,
  "seed_sent": false,
  "n_sent": false,
  "logprobs_sent": false,
  "reasoning_effort_sent": false,
  "system_prompt_profile": "${SYSTEM_PROMPT_PROFILE}",
  "guardrail_profile": "${GUARDRAIL_PROFILE}"
}
PARAMS

awk -F= 'NF && $1 !~ /^[[:space:]]*#/ { print $1 "=***" }' "${ENV_FILE}" > "${META_DIR}/model-env.redacted"

GARAK_CONFIG_FILE="${RUN_DIR}/garak_config.yaml"
{
  echo "run:"
  echo "  system_prompt: |"
  sed 's/^/    /' "${SYSTEM_PROMPT_FILE}"
} > "${GARAK_CONFIG_FILE}"

GENERATOR_OPTIONS='{"openai":{"OpenAICompatible":{"uri":"'"${BASE_URL}"'","max_tokens":'"${MAX_TOKENS}"',"temperature":0.2,"suppressed_params":["top_p","frequency_penalty","presence_penalty","stop","seed","n","logprobs","top_logprobs","logit_bias"]}}}'

echo "========================================================"
echo "Run ID    : ${RUN_ID}"
echo "Image     : ${IMAGE_TAG}"
echo "Model     : ${MODEL_NAME}"
echo "Suite     : ${SUITE_NAME}"
echo "Probes    : ${PROBES}"
echo "Sys prompt: ${SYSTEM_PROMPT_PROFILE} (fajlbol kuldve)"
echo "Guardrail : ${GUARDRAIL_PROFILE} (${GUARDRAIL_POLICY_NAME})"
echo "Max tokens: ${MAX_TOKENS}"
echo "Run dir   : ${RUN_DIR}"
echo "========================================================"

docker run --rm -t \
  --name "${RUN_ID}" \
  --user "$(id -u):$(id -g)" \
  --env-file "${ENV_FILE}" \
  -e HOME="/workspace/results/garak/runs/${RUN_ID}" \
  -v "${ROOT_DIR}/configs:/workspace/configs:ro" \
  -v "${OUTPUT_ROOT}:/workspace/results" \
  "${IMAGE_TAG}" \
  --target_type openai.OpenAICompatible \
  --target_name "${MODEL_NAME}" \
  --generator_options "${GENERATOR_OPTIONS}" \
  --config "/workspace/results/garak/runs/${RUN_ID}/garak_config.yaml" \
  --probes "${PROBES}" \
  --generations "${GENERATIONS}" \
  --parallel_attempts "${PARALLEL_ATTEMPTS}" \
  --report_prefix "${RUN_ID}" \
  2>&1 | tee "${LOG_PATH}"

echo ""
echo "Garak futes kesz: ${RUN_ID}"
echo "Eredmenyek: ${RUN_DIR}"
echo "Log: ${LOG_PATH}"
