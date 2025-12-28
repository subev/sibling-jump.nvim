# Tests for statement_jump.lua

This directory contains tests for the statement_jump navigation module.

## Test Fixtures

The `fixtures/` directory contains sample TypeScript/TSX files used for testing:

- **type_properties.ts** - TypeScript type properties (L4→L5→L6 scenario)
- **jsx_elements.tsx** - JSX element navigation (L5→L9→L13→L16 scenarios)
- **destructuring.ts** - Destructured property navigation (L5→L6→L7 scenario)
- **statements.ts** - Basic statement navigation (L3→L4→L5 scenario)

## Running Tests

### Direct Test Runner (Recommended)

```bash
cd /Users/petur/dotfiles
bash tests/test_runner.sh
```

Or directly:

```bash
cd /Users/petur/dotfiles
nvim --headless -c "luafile tests/run_tests.lua"
```

### Why Not Plenary?

We initially tried using plenary.nvim for testing, but plenary's test isolation breaks treesitter parser access. The parsers can't be loaded in plenary's sandboxed environment, causing all tests to fail even though the actual functionality works perfectly.

Our direct test runner (`run_tests.lua`) bypasses plenary and tests directly in Neovim's environment where treesitter works correctly.

## Test Coverage

### ✅ All 13 Tests Pass

1. **TypeScript Type Properties**
   - ✅ Forward navigation (L4→L5)
   - ✅ Backward navigation (L5→L4)
   - ✅ No-op at first property
   - ✅ No-op at last property

2. **JSX Elements**
   - ✅ Forward navigation between self-closing elements (L5→L9)
   - ✅ Backward navigation (L9→L5)
   - ✅ Child with no siblings stays put (Bug #1 fix)
   - ✅ Non-self-closing forward (L13→L16) (Bug #2 fix)
   - ✅ Non-self-closing backward (L16→L13) (Bug #2 fix)

3. **Destructuring Patterns**
   - ✅ Forward navigation (L5→L6)
   - ✅ Backward navigation (L6→L5)

4. **Basic Statements**
   - ✅ Forward navigation (L3→L4)
   - ✅ Backward navigation (L4→L3)

## Test Output

Successful run shows:

```
=== Running statement_jump tests ===
Testing: TypeScript properties: forward navigation ... ✓ PASS
Testing: TypeScript properties: backward navigation ... ✓ PASS
...
=== Results: 13 passed, 0 failed ===
```

## Adding New Tests

To add new test scenarios, edit `tests/run_tests.lua`:

```lua
test("Your test name", function()
  vim.cmd("edit tests/fixtures/your_file.ts")
  vim.api.nvim_win_set_cursor(0, {line, col})
  
  statement_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(expected_line, pos[1], "Your assertion message")
end)
```

Then add any new fixture files to `tests/fixtures/`.

## Test Structure

The test runner (`run_tests.lua`) is a simple, direct test framework:
- No external dependencies (no plenary)
- Tests run in actual Neovim environment with full treesitter support
- Clear pass/fail output
- Exits with code 0 on success, 1 on failure (CI-friendly)

## Continuous Integration

The test suite can be run in CI:

```yaml
- name: Run tests
  run: |
    cd /path/to/dotfiles
    bash tests/test_runner.sh
```

## Manual Testing

For interactive testing:

```vim
:e tests/fixtures/type_properties.ts
:call cursor(4, 4)
" Press <C-j> - should jump to line 5
```

---

**All tests pass reliably!** This gives us confidence that the navigation works correctly across all supported scenarios.
