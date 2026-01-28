#!/bin/bash
# Copyright 2026 Google LLC
# Licensed under the Apache License, Version 2.0

STATE_FILE=".gemini/ralph/state.json"
STATE_DIR=".gemini/ralph"

setup() {
    rm -f "$STATE_FILE"
}

cleanup() {
    rm -f "$STATE_FILE"
    # Only remove directory if it is empty
    if [[ -d "$STATE_DIR" ]]; then
        rmdir "$STATE_DIR" 2>/dev/null || true
    fi
}

trap cleanup EXIT

assert_exists() {
    if [[ ! -f "$1" ]]; then
        echo "FAIL: $1 does not exist"
        exit 1
    fi
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

echo "Running Test 1: Basic setup..."
setup
./scripts/setup.sh "Task"
assert_exists "$STATE_FILE"
assert_json_value ".active" "true"
assert_json_value ".current_iteration" "1"
# Check if started_at is a valid ISO 8601 timestamp
if ! jq -r ".started_at" "$STATE_FILE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T'; then
    echo "FAIL: started_at is missing or not a valid ISO 8601 timestamp"
    exit 1
fi

echo "Running Test 2: Argument parsing (individual)..."
setup
./scripts/setup.sh "Task" --max-iterations 5 --completion-promise "DONE"
assert_json_value ".max_iterations" "5"
assert_json_value ".completion_promise" "DONE"

echo "Running Test 3: Argument parsing (combined string workaround)..."
setup
./scripts/setup.sh "/ralph:loop Task --max-iterations 10 --completion-promise FINISHED"
assert_json_value ".max_iterations" "10"
assert_json_value ".completion_promise" "FINISHED"

echo "Running Test 4: Complex prompt with spaces and quotes..."
setup
./scripts/setup.sh "/ralph:loop \"Solve 'The Riddle'\" --max-iterations 3"
assert_json_value ".original_prompt" "Solve 'The Riddle'"
assert_json_value ".max_iterations" "3"

echo "Running Test 5: Equality flag parsing (--flag=value)..."
setup
./scripts/setup.sh "Task" --max-iterations=15 --completion-promise=FINISH
assert_json_value ".max_iterations" "15"
assert_json_value ".completion_promise" "FINISH"

echo "PASS: All tests passed!"
