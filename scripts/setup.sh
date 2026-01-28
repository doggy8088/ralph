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
die() {
  echo "❌ Error: $1" >&2
  exit 1
}

# Setup paths
STATE_DIR=".gemini/ralph"
STATE_FILE="$STATE_DIR/state.json"
PROGRESS_FILE="$STATE_DIR/progress.txt"

# Ensure directory exists
mkdir -p "$STATE_DIR" || die "Could not create state directory: $STATE_DIR"

# Defaults
MAX_ITERATIONS=5
COMPLETION_PROMISE=""
PROMPT=""

# Workaround for LLM tool invocation passing all args as a single string
if [[ $# -eq 1 ]]; then
    if [[ "$1" == "/ralph:loop"* ]] || [[ "$1" =~ ^- ]] || [[ "$1" =~ " --" ]]; then
        # Remove command prefix if present
        raw_args="${1#/ralph:loop }"
        eval set -- "$raw_args" || die "Failed to parse combined arguments"
    fi
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --max-iterations)
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        --completion-promise)
            COMPLETION_PROMISE="$2"
            shift 2
            ;;
        *)
            if [[ "$1" != -* ]]; then
                if [[ -z "$PROMPT" ]]; then
                    PROMPT="$1"
                else
                    PROMPT="$PROMPT $1"
                fi
            fi
            shift 1
            ;;
    esac
done

# Initialize state.json
jq -n \
    --arg max "$MAX_ITERATIONS" \
    --arg promise "$COMPLETION_PROMISE" \
    --arg prompt "$PROMPT" \
    --arg started_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '{
        active: true,
        current_iteration: 0,
        max_iterations: ($max | tonumber),
        completion_promise: $promise,
        original_prompt: $prompt,
        started_at: $started_at
    }' > "$STATE_FILE" || die "Failed to initialize state file: $STATE_FILE"

# Initialize progress.txt
echo "Ralph is starting a new loop for: $PROMPT" > "$PROGRESS_FILE"

# Ralph-style summary for the user and agent
echo ""
cat <<EOF
Ralph is helping! I'm going in a circle!

>> My Rules:
   - I can try $MAX_ITERATIONS times.
   - I will stop if I find: <promise>${COMPLETION_PROMISE:-a shiny penny}</promise>

>> My Thoughts:
   - $PROMPT

I'm starting now! I hope I don't run out of paste!
EOF

if [[ -n "$COMPLETION_PROMISE" ]]; then
  echo ""
  echo "⚠️  RALPH IS LISTENING FOR A PROMISE"
  echo "   You must say: <promise>$COMPLETION_PROMISE</promise>"
fi

# Output for persona (stderr)
echo "Ralph is helping! I'm setting up my toys." >&2
