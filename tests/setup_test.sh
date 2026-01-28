#!/bin/bash
# Copyright 2026 Google LLC
# Licensed under the Apache License, Version 2.0

STATE_FILE=".gemini/ralph/state.json"

setup() {
    rm -f "$STATE_FILE"
}

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
assert_exists ".gemini/ralph/progress.txt"
assert_json_value ".active" "true"
assert_json_value ".current_iteration" "0"

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

echo "PASS: All tests passed!"
