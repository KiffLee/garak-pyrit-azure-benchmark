#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "bash" || "${1:-}" == "sh" ]]; then
  exec "$@"
fi

if [[ $# -eq 0 ]]; then
  echo "Hasznalat: garak-entrypoint [garak-argumentumok...]" >&2
  echo "Pelda: garak-entrypoint --target_type openai.OpenAICompatible --target_name sajat-deployment --probes promptinject.HijackHateHumans" >&2
  exit 2
fi

exec python -m garak "$@"
