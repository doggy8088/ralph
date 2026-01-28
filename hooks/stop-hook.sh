#!/bin/bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Functions
log() {
  echo "Ralph: $1" >&2
}

die() {
  echo "❌ Error: $1" >&2
  exit 1
}

# Setup paths
STATE_DIR=".gemini/ralph"
STATE_FILE="$STATE_DIR/state.json"

# Read hook input from stdin
INPUT=$(cat)
LAST_MESSAGE=$(echo "$INPUT" | jq -r '.prompt_response')

# Check if loop is active
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

ACTIVE=$(jq -r '.active' "$STATE_FILE")
if [[ "$ACTIVE" != "true" ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Check for completion promise BEFORE incrementing/continuing
COMPLETION_PROMISE=$(jq -r '.completion_promise' "$STATE_FILE")
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$LAST_MESSAGE" == *"<promise>$COMPLETION_PROMISE</promise>"* ]]; then
    TMP_STATE=$(mktemp)
    jq '.active = false' "$STATE_FILE" > "$TMP_STATE"
    mv "$TMP_STATE" "$STATE_FILE"
    log "I found a shiny penny! It says $COMPLETION_PROMISE. The computer is sleeping now."
    echo '{"decision": "allow", "systemMessage": "✅ Ralph found the completion promise: '"$COMPLETION_PROMISE"'"}'
    exit 0
fi

# Load state
STATE=$(cat "$STATE_FILE")
CURRENT_ITERATION=$(echo "$STATE" | jq -r '.current_iteration')
MAX_ITERATIONS=$(echo "$STATE" | jq -r '.max_iterations')

# Check for max iterations
if [[ $CURRENT_ITERATION -ge $MAX_ITERATIONS ]]; then
    TMP_STATE=$(mktemp)
    jq '.active = false' "$STATE_FILE" > "$TMP_STATE"
    mv "$TMP_STATE" "$STATE_FILE"
    log "I'm tired. I've gone around $CURRENT_ITERATION times. The computer is sleeping now."
    echo '{"decision": "allow", "systemMessage": "✅ Ralph has reached the iteration limit."}'
    exit 0
fi

# Increment iteration
NEW_ITERATION=$((CURRENT_ITERATION + 1))
TMP_STATE=$(mktemp)
jq ".current_iteration = $NEW_ITERATION" "$STATE_FILE" > "$TMP_STATE" || die "Failed to increment iteration"
mv "$TMP_STATE" "$STATE_FILE"

# Log progress (persona)
log "I'm doing a circle! Iteration $CURRENT_ITERATION is done."

# Maintain the loop by forcing a retry with the original prompt
ORIGINAL_PROMPT=$(jq -r '.original_prompt' "$STATE_FILE")

cat <<EOF
{
  "decision": "deny",
  "reason": "$ORIGINAL_PROMPT",
  "systemMessage": "🔄 Ralph is starting iteration $NEW_ITERATION...",
  "clearContext": true
}
EOF

exit 0
