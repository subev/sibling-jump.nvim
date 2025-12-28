#!/bin/bash
# Test runner for sibling_jump tests
# Run with: bash tests/test_runner.sh

echo "===== Running sibling_jump tests ====="
echo ""

cd "$(dirname "$0")/.."

# Use direct lua test runner (not plenary) because plenary doesn't properly
# support treesitter parsers in its sandboxed test environment
nvim --headless -u tests/minimal_init.lua -c "luafile tests/run_tests.lua"

exit $?
