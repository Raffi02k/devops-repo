#!/usr/bin/env bash
set -euo pipefail

url="${1:?Give the address to check, for example http://localhost:3000/health}"
ATTEMPTS="${ATTEMPTS:-10}"
DELAY="${DELAY:-3}"

echo "==> Checking health at $url"
for attempt in $(seq 1 "$ATTEMPTS"); do
  status=$(curl --silent --output /dev/null --write-out "%{http_code}" --max-time 10 "$url" || true)
  if [ "$status" = "200" ]; then
    echo "  ok    $url responded with 200 (attempt $attempt/$ATTEMPTS)"
    exit 0
  fi
  echo "  wait  attempt $attempt/$ATTEMPTS: got status '$status', retrying in ${DELAY}s..."
  sleep "$DELAY"
done

echo "  FAIL  $url did not respond with 200 after $ATTEMPTS attempts"
exit 1
