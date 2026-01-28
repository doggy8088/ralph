#!/bin/bash
# Copyright 2026 Google LLC
# Licensed under the Apache License, Version 2.0

STATE_FILE=".gemini/ralph/state.json"
HOOK="./hooks/after-agent-hook.sh"

setup() {
    mkdir -p .gemini/ralph
    jq -n '{active: true, current_iteration: 0, max_iterations: 5, completion_promise: "", original_prompt: "Task", started_at: "2026-01-27T12:00:00Z"}' > "$STATE_FILE"
}

assert_json_value() {
    local key="$1"
    local expected="$2"
    local actual=$(jq -r "$key" "$STATE_FILE")
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: Expected $key to be $expected, but got $actual"
        exit 1
    fi
}

echo "Running Test 1: Iteration increment..."
setup
# Simulate AfterAgent hook input
echo '{"prompt_response": "Some response"}' | "$HOOK" > /dev/null
assert_json_value ".current_iteration" "1"

echo "Running Test 2: Termination (Max Iterations)..."
setup
# Set current_iteration to 4, max_iterations is 5
jq '.current_iteration = 4' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
# This turn (5th) should trigger termination
RESPONSE=$(echo '{"prompt_response": "Last response"}' | "$HOOK")
assert_json_value ".current_iteration" "5"
assert_json_value ".active" "false"
if [[ $(echo "$RESPONSE" | jq -r '.decision') != "allow" ]]; then
    echo "FAIL: Expected decision to be 'allow' upon termination"
    exit 1
fi

echo "PASS: All tests passed!"
