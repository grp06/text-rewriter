#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "OPENAI_API_KEY is not set."
  echo "Example:"
  echo "  export OPENAI_API_KEY='sk-...'"
  exit 1
fi

payload=$(
  cat <<'JSON'
{
  "model": "gpt-5.2",
  "instructions": "Respond with the single word OK.",
  "input": [
    {
      "role": "user",
      "content": "OK"
    }
  ]
}
JSON
)

curl -sS \
  -w "\nHTTP_STATUS:%{http_code}\n" \
  -X POST "https://api.openai.com/v1/responses" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "${payload}"

