#!/bin/bash
# Test runner for statement_jump tests
# Run with: bash tests/test_runner.sh

echo "===== Running statement_jump tests ====="
echo ""

cd "$(dirname "$0")/.."

# Use direct lua test runner (not plenary) because plenary doesn't properly
# support treesitter parsers in its sandboxed test environment
nvim --headless -c "luafile tests/run_tests.lua"

exit $?
