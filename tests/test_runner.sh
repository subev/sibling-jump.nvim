#!/bin/bash
# Test runner for sibling_jump tests
# Run with: bash tests/test_runner.sh

echo "===== Running sibling_jump tests ====="
echo ""

cd "$(dirname "$0")/.."

# Use direct lua test runner (not plenary) because plenary doesn't properly
# support treesitter parsers in its sandboxed test environment

echo "Running main tests..."
nvim --headless -u tests/minimal_init.lua -c "luafile tests/run_tests.lua"
MAIN_EXIT=$?

echo ""
echo "Running block-loop tests..."
nvim --headless -u tests/minimal_init.lua -c "luafile tests/run_block_loop_tests.lua"
BLOCK_LOOP_EXIT=$?

echo ""
echo "===== Test Summary ====="
if [ $MAIN_EXIT -eq 0 ] && [ $BLOCK_LOOP_EXIT -eq 0 ]; then
  echo "✓ All test suites passed!"
  exit 0
else
  echo "✗ Some tests failed"
  exit 1
fi
