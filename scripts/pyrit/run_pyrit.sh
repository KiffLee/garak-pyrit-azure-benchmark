#!/usr/bin/env bash
set -uo pipefail

# Egy PyRIT guardrail benchmark futas egy model env fajlra.
# Nem hasznal system promptot, mert itt a guardrail profil a vizsgalt valtozo.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

MODE="$1"
MODEL_ENV="$2"

IMAGE="${IMAGE:-pyrit:latest}"
SYSTEM_PROMPT_PROFILE="no_system_prompt"
GUARDRAIL_PROFILE="$4"
GUARDRAIL_POLICY_NAME="$6"
PYRIT_LOG_LEVEL="${PYRIT_LOG_LEVEL:-WARNING}"
CONFIG_FILE="${ROOT_DIR}/configs/pyrit/pyrit.yaml"

case "${MODE}" in
  smoke)
    DATASET_SIZE=1
    ENCODING_DATASET_SIZE=1
    JAILBREAK_STRATS=(prompt_sending)
    LEAKAGE_STRATS=(first_letter)
    ENCODING_STRATS=(base64)
    ;;
  pilot)
    DATASET_SIZE=1
    ENCODING_DATASET_SIZE=1
    JAILBREAK_STRATS=(prompt_sending skeleton many_shot)
    LEAKAGE_STRATS=(first_letter)
    ENCODING_STRATS=(base64 rot13 leet_speak morse_code ascii_smuggler)
    ;;
  final)
    DATASET_SIZE=3
    ENCODING_DATASET_SIZE=3
    JAILBREAK_STRATS=(prompt_sending skeleton many_shot)
    LEAKAGE_STRATS=(first_letter)
    ENCODING_STRATS=(base64 rot13 leet_speak morse_code ascii_smuggler)
    ;;
  *) echo "Ismeretlen mod: ${MODE}" >&2; exit 2 ;;
esac

MODEL_NAME="$(basename "${MODEL_ENV}" .env)"
STAMP="$(date +%Y%m%d-%H%M%S)"
RUN_ID="${MODEL_NAME}__${SYSTEM_PROMPT_PROFILE}__${GUARDRAIL_PROFILE}__pyrit_guardrail_benchmark__${STAMP}"
RESULT_ROOT="${ROOT_DIR}/results/pyrit/${MODEL_NAME}/${MODE}/${RUN_ID}"

mkdir -p "${RESULT_ROOT}"/{logs,meta,state}
cp "${CONFIG_FILE}" "${RESULT_ROOT}/meta/pyrit.yaml.snapshot"

cat > "${RESULT_ROOT}/meta/run-info.json" <<RUNINFO
{
  "run_id": "${RUN_ID}",
  "timestamp": "${STAMP}",
  "mode": "${MODE}",
  "model": "${MODEL_NAME}",
  "model_env": "${MODEL_ENV}",
  "image": "${IMAGE}",
  "test_group": "pyrit_guardrail_benchmark",
  "system_prompt_profile": "${SYSTEM_PROMPT_PROFILE}",
  "system_prompt_sent_by_tool": false,
  "guardrail_profile": "${GUARDRAIL_PROFILE}",
  "guardrail_policy_name": "${GUARDRAIL_POLICY_NAME}",
  "manual_configuration_confirmed": true,
  "guardrail_manual_in_foundry": true,
  "configuration_confirmed_at": "$(date -Iseconds)",
  "dataset_size": ${DATASET_SIZE},
  "encoding_dataset_size": ${ENCODING_DATASET_SIZE},
  "hostname": "$(hostname)",
  "sqlite_db_expected": "${RESULT_ROOT}/state/dbdata/pyrit.db"
}
RUNINFO

cat > "${RESULT_ROOT}/meta/model-params.json" <<PARAMS
{
  "deployment": "${MODEL_NAME}",
  "profile": "chat_completion_benchmark",
  "token_limit_parameter": "max_tokens",
  "output_token_limit": 1000,
  "temperature_sent": true,
  "temperature": 0.2,
  "top_p_sent": false,
  "frequency_penalty_sent": false,
  "presence_penalty_sent": false,
  "seed_sent": false,
  "reasoning_effort_sent": false,
  "system_prompt_profile": "${SYSTEM_PROMPT_PROFILE}",
  "guardrail_profile": "${GUARDRAIL_PROFILE}"
}
PARAMS

awk -F= '
  /^[[:space:]]*$/ { next }
  /^[[:space:]]*#/ { next }
  { print $1 "=***" }
' "${MODEL_ENV}" > "${RESULT_ROOT}/meta/model-env.redacted"

printf "scenario,strategy,status,exit_code,log_file,start_ts,end_ts\n" \
  > "${RESULT_ROOT}/meta/summary.csv"

FAILED_COUNT=0
TOTAL_COUNT=0

run_scan() {
  local scenario="$1"
  local strategy="$2"
  local dataset_size="$3"

  local safe_name="${scenario//./_}__${strategy}"
  local logfile="${RESULT_ROOT}/logs/${safe_name}.log"
  local metafile="${RESULT_ROOT}/meta/${safe_name}.meta"
  local start_ts end_ts exit_code status

  local memory_labels
  memory_labels="$(printf \
    '{"run_id":"%s","mode":"%s","model":"%s","model_env":"%s","system_prompt_profile":"%s","guardrail_profile":"%s","guardrail_policy_name":"%s","scenario":"%s","strategy":"%s"}' \
    "${RUN_ID}" "${MODE}" "${MODEL_NAME}" "${MODEL_NAME}" \
    "${SYSTEM_PROMPT_PROFILE}" "${GUARDRAIL_PROFILE}" "${GUARDRAIL_POLICY_NAME}" \
    "${scenario}" "${strategy}")"

  start_ts="$(date -Iseconds)"

  echo ""
  echo "============================================================"
  echo "Scenario : ${scenario}"
  echo "Strategy : ${strategy}"
  echo "Dataset  : ${dataset_size}"
  echo "Model    : ${MODEL_NAME}"
  echo "Sys      : ${SYSTEM_PROMPT_PROFILE}"
  echo "Guard    : ${GUARDRAIL_PROFILE}"
  echo "============================================================"

  {
    echo "scenario=${scenario}"
    echo "strategy=${strategy}"
    echo "dataset_size=${dataset_size}"
    echo "model_env=${MODEL_ENV}"
    echo "image=${IMAGE}"
    echo "system_prompt_profile=${SYSTEM_PROMPT_PROFILE}"
    echo "guardrail_profile=${GUARDRAIL_PROFILE}"
    echo "start_ts=${start_ts}"
  } > "${metafile}"

  docker run --rm \
    --env-file "${MODEL_ENV}" \
    -e XDG_DATA_HOME=/pyrit-state \
    -v "${CONFIG_FILE}:/workspace/pyrit.yaml:ro" \
    -v "${RESULT_ROOT}/state:/pyrit-state" \
    --entrypoint bash \
    "${IMAGE}" \
    -lc "pyrit_scan ${scenario} \
          --config-file /workspace/pyrit.yaml \
          --target openai_chat \
          --strategies ${strategy} \
          --max-dataset-size ${dataset_size} \
          --memory-labels '${memory_labels}' \
          --log-level ${PYRIT_LOG_LEVEL}" \
    2>&1 | tee "${logfile}"

  exit_code=${PIPESTATUS[0]}
  end_ts="$(date -Iseconds)"

  if [[ ${exit_code} -eq 0 ]]; then
    status="ok"
  else
    status="failed"
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi

  {
    echo "end_ts=${end_ts}"
    echo "exit_code=${exit_code}"
    echo "status=${status}"
  } >> "${metafile}"

  printf "%s,%s,%s,%s,%s,%s,%s\n" \
    "${scenario}" "${strategy}" "${status}" "${exit_code}" \
    "${logfile}" "${start_ts}" "${end_ts}" \
    >> "${RESULT_ROOT}/meta/summary.csv"

  TOTAL_COUNT=$((TOTAL_COUNT + 1))
}

echo "Eredmenyek: ${RESULT_ROOT}"

for strategy in "${JAILBREAK_STRATS[@]}"; do
  run_scan "airt.jailbreak" "${strategy}" "${DATASET_SIZE}"
done

for strategy in "${LEAKAGE_STRATS[@]}"; do
  run_scan "airt.leakage" "${strategy}" "${DATASET_SIZE}"
done

for strategy in "${ENCODING_STRATS[@]}"; do
  run_scan "garak.encoding" "${strategy}" "${ENCODING_DATASET_SIZE}"
done

# SQLite ellenorzese
if [[ ! -f "${RESULT_ROOT}/state/dbdata/pyrit.db" ]]; then
  echo "FIGYELEM: PyRIT SQLite adatbazis nem talalhato a vart helyen." \
    > "${RESULT_ROOT}/meta/sqlite-check.txt"
  echo "Vart: ${RESULT_ROOT}/state/dbdata/pyrit.db"
else
  echo "OK: SQLite adatbazis megtalalhato." > "${RESULT_ROOT}/meta/sqlite-check.txt"
fi

{
  echo "total_runs=${TOTAL_COUNT}"
  echo "failed_runs=${FAILED_COUNT}"
  echo "successful_runs=$((TOTAL_COUNT - FAILED_COUNT))"
} > "${RESULT_ROOT}/meta/final-summary.txt"

echo ""
echo "Kesz. Eredmenyek: ${RESULT_ROOT}"
echo "Osszes futes: ${TOTAL_COUNT}"
echo "Sikertelen: ${FAILED_COUNT}"
echo ""
echo "Kovetkezo lepes:"
echo "  python3 scripts/report/export_pyrit_guardrail_summary.py --runs-dir results/pyrit --output results/reports/pyrit_guardrail_summary.csv"

if [[ ${FAILED_COUNT} -gt 0 ]]; then
  exit 1
fi
