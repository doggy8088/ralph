#!/bin/bash
# Copyright 2026 Google LLC
# Licensed under the Apache License, Version 2.0

STATE_FILE=".gemini/ralph/state.json"
STATE_DIR=".gemini/ralph"
HOOK="./hooks/stop-hook.sh"

setup() {
    mkdir -p "$STATE_DIR"
    jq -n '{active: true, current_iteration: 1, max_iterations: 5, completion_promise: "", original_prompt: "Task", started_at: "2026-01-27T12:00:00Z"}' > "$STATE_FILE"
}

cleanup() {
    rm -f "$STATE_FILE"
    # Only remove directory if it is empty
    if [[ -d "$STATE_DIR" ]]; then
        rmdir "$STATE_DIR" 2>/dev/null || true
    fi
}

trap cleanup EXIT

assert_json_value() {
    local key="$1"
    local expected="$2"
    local actual=$(jq -r "$key" "$STATE_FILE")
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: Expected $key to be $expected, but got $actual"
        exit 1
    fi
}

assert_exists() {
    if [[ ! -f "$1" ]]; then
        echo "FAIL: $1 does not exist"
        exit 1
    fi
}

assert_not_exists() {
    if [[ -f "$1" ]]; then
        echo "FAIL: $1 still exists"
        exit 1
    fi
}

echo "Running Test 1: Iteration increment..."
setup
# Simulate initial command invocation with flags (Iteration 1)
RESPONSE=$(echo '{"prompt_response": "Some response", "prompt": "/ralph:loop --max-iterations 5 Task"}' | "$HOOK")
assert_exists "$STATE_FILE"
assert_json_value ".current_iteration" "2"
if [[ $(echo "$RESPONSE" | jq -r '.systemMessage') != "🔄 Ralph is starting iteration 2..." ]]; then
    echo "FAIL: Expected systemMessage to be '🔄 Ralph is starting iteration 2...', but got '$(echo "$RESPONSE" | jq -r '.systemMessage')'"
    exit 1
fi

echo "Running Test 2: Termination (Max Iterations)..."
setup
# Set current_iteration to 5, max_iterations is 5
jq '.current_iteration = 5' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
# Subsequent iterations use the exact ORIGINAL_PROMPT
RESPONSE=$(echo '{"prompt_response": "Last response", "prompt": "Task"}' | "$HOOK")
assert_not_exists "$STATE_FILE"
if [[ $(echo "$RESPONSE" | jq -r '.decision') != "allow" ]]; then
    echo "FAIL: Expected decision to be 'allow' upon termination"
    exit 1
fi

echo "Running Test 3: Termination (Completion Promise)..."
setup
# Set completion_promise
jq '.completion_promise = "DONE"' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
# Agent provides the promise
RESPONSE=$(echo '{"prompt_response": "I am finished. <promise>DONE</promise>", "prompt": "Task"}' | "$HOOK")
assert_not_exists "$STATE_FILE"
if [[ $(echo "$RESPONSE" | jq -r '.decision') != "allow" ]]; then
    echo "FAIL: Expected decision to be 'allow' upon promise fulfillment"
    exit 1
fi

echo "Running Test 4: Ghost Loop Cleanup (Unrelated Prompt)..."
setup
# User asks something else while a loop is technically "active" on disk
RESPONSE=$(echo '{"prompt_response": "Paris", "prompt": "What is the capital of France?"}' | "$HOOK")
assert_not_exists "$STATE_FILE"
if [[ $(echo "$RESPONSE" | jq -r '.decision') != "allow" ]]; then
    echo "FAIL: Expected decision to be 'allow' for unrelated prompt"
    exit 1
fi
if [[ $(echo "$RESPONSE" | jq -r '.systemMessage') != "🚨 Ralph detected a prompt mismatch. Expected: 'Task', Got: 'What is the capital of France?'" ]]; then
    echo "FAIL: Ghost loop cleanup should show mismatch message"
    exit 1
fi

echo "Running Test 5: Hijack Prevention (Different Loop Command)..."
setup
# state.json contains "Task" (from an orphaned loop A)
# User now runs a NEW loop B with a different prompt
RESPONSE=$(echo '{"prompt_response": "New Task response", "prompt": "/ralph:loop Different Task"}' | "$HOOK")
assert_not_exists "$STATE_FILE"
if [[ $(echo "$RESPONSE" | jq -r '.decision') != "allow" ]]; then
    echo "FAIL: Expected decision to be 'allow' when a different loop command is detected"
    exit 1
fi

echo "PASS: All tests passed!"
