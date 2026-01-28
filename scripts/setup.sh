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

# Setup paths
STATE_DIR=".gemini/ralph"
STATE_FILE="$STATE_DIR/state.json"
PROGRESS_FILE="$STATE_DIR/progress.txt"

# Ensure directory exists
mkdir -p "$STATE_DIR"

# Defaults
MAX_ITERATIONS=5
COMPLETION_PROMISE=""
PROMPT=""

# Workaround for combined string invocation
if [[ "$1" == "/ralph:loop"* ]]; then
    # Re-tokenize the string while respecting basic quoting if possible
    # For now, we use a simple approach to handle the most common cases
    raw_args="${1#/ralph:loop }"
    # Use eval to handle potential quotes in the single string
    eval "ARGS=($raw_args)"
else
    ARGS=("$@")
fi

# Parse arguments
i=0
while [[ $i -lt ${#ARGS[@]} ]]; do
    case "${ARGS[$i]}" in
        --max-iterations)
            MAX_ITERATIONS="${ARGS[$((i+1))]}"
            i=$((i+2))
            ;;
        --completion-promise)
            COMPLETION_PROMISE="${ARGS[$((i+1))]}"
            i=$((i+2))
            ;;
        *)
            if [[ "${ARGS[$i]}" != -* ]]; then
                if [[ -z "$PROMPT" ]]; then
                    PROMPT="${ARGS[$i]}"
                else
                    PROMPT="$PROMPT ${ARGS[$i]}"
                fi
            fi
            i=$((i+1))
            ;;
    esac
done

# Initialize state.json
jq -n \
    --arg max "$MAX_ITERATIONS" \
    --arg promise "$COMPLETION_PROMISE" \
    --arg prompt "$PROMPT" \
    '{
        active: true,
        current_iteration: 0,
        max_iterations: ($max | tonumber),
        completion_promise: $promise,
        original_prompt: $prompt
    }' > "$STATE_FILE"

# Initialize progress.txt
echo "Ralph is starting a new loop for: $PROMPT" > "$PROGRESS_FILE"

# Output for persona (stderr)
echo "Ralph is helping! I'm setting up my toys." >&2
