#!/bin/bash
# Copyright 2026 Google LLC
# Licensed under the Apache License, Version 2.0

STATE_FILE=".gemini/ralph/state.json"
HOOK="./hooks/stop-hook.sh"

setup() {
    mkdir -p .gemini/ralph
    jq -n '{active: true, current_iteration: 1, max_iterations: 5, completion_promise: "", original_prompt: "Task", started_at: "2026-01-27T12:00:00Z"}' > "$STATE_FILE"
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
RESPONSE=$(echo '{"prompt_response": "Some response"}' | "$HOOK")
assert_json_value ".current_iteration" "2"
if [[ $(echo "$RESPONSE" | jq -r '.systemMessage') != "🔄 Ralph is starting iteration 2..." ]]; then
    echo "FAIL: Expected systemMessage to be '🔄 Ralph is starting iteration 2...', but got '$(echo "$RESPONSE" | jq -r '.systemMessage')'"
    exit 1
fi

echo "Running Test 2: Termination (Max Iterations)..."
setup
# Set current_iteration to 5, max_iterations is 5
jq '.current_iteration = 5' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
# This turn (5th) should trigger termination
RESPONSE=$(echo '{"prompt_response": "Last response"}' | "$HOOK")
assert_json_value ".current_iteration" "5"
assert_json_value ".active" "false"
if [[ $(echo "$RESPONSE" | jq -r '.decision') != "allow" ]]; then
    echo "FAIL: Expected decision to be 'allow' upon termination"
    exit 1
fi

echo "Running Test 3: Termination (Completion Promise)..."
setup
# Set completion_promise
jq '.completion_promise = "DONE"' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
# Agent provides the promise
RESPONSE=$(echo '{"prompt_response": "I am finished. <promise>DONE</promise>"}' | "$HOOK")
assert_json_value ".active" "false"
if [[ $(echo "$RESPONSE" | jq -r '.decision') != "allow" ]]; then
    echo "FAIL: Expected decision to be 'allow' upon promise fulfillment"
    exit 1
fi

echo "PASS: All tests passed!"
