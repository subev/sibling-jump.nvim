-- Block-loop tests - separated from main test suite
-- Run with: nvim --headless -c "luafile tests/run_block_loop_tests.lua"

local sibling_jump = require("sibling_jump")

local passed = 0
local failed = 0
local tests = {}

local function test(name, fn)
  table.insert(tests, { name = name, fn = fn })
end

local function assert_eq(expected, actual, message)
  if expected ~= actual then
    error(string.format("%s\nExpected: %s\nGot: %s", message or "Assertion failed", expected, actual))
  end
end

local function run_tests()
  print("=== Running block-loop tests ===")
  print("")

  for _, t in ipairs(tests) do
    local ok, err = pcall(t.fn)

    if ok then
      local status = "✓ PASS"
      print(string.format("%-90s %s", t.name, status))
      passed = passed + 1
    else
      local status = "✗ FAIL"
      print(string.format("%-90s %s", t.name, status))
      print("  Error: " .. tostring(err))
      failed = failed + 1
    end

    -- Clean up between tests
    vim.cmd("bufdo! bwipeout!")
  end

  print("")
  print(string.format("=== Results: %d passed, %d failed ===", passed, failed))

  if failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("quit")
  end
end

-- ============================================================================
-- BLOCK LOOP TESTS
-- ============================================================================

test("Block-loop: Simple if cycle", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {6, 2})  -- On 'if' keyword in simpleIf (line 6)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(8, pos[1], "Should jump from if (line 6) to closing bracket (line 8)")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should cycle back from } (line 8) to 'if' (line 6)")
end)

test("Block-loop: If-else cycle", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {12, 2})  -- On 'if' in ifElse
  
  -- if → else
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(14, pos[1], "Should jump to 'else' keyword")
  
  -- else → }
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(16, pos[1], "Should jump to closing bracket")
  
  -- } → if (cycle)
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(12, pos[1], "Should cycle back to 'if'")
end)

test("Block-loop: Arrow function with const cycle", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {37, 0})  -- On 'const' in arrowFunction (line 37)
  
  -- const → }
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(39, pos[1], "Should jump to closing bracket (line 39)")
  
  -- } → const (cycle)
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(37, pos[1], "Should cycle back to 'const' (line 37)")
end)

test("Block-loop: Regular function cycle", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {33, 0})  -- On 'function' keyword (line 33)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(35, pos[1], "Should jump to closing bracket (line 35)")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(33, pos[1], "Should cycle back to 'function' (line 33)")
end)

test("Block-loop: Object literal with const cycle", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {51, 0})  -- On 'const' in simpleObject (line 51)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(54, pos[1], "Should jump to closing bracket (line 54)")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(51, pos[1], "Should cycle back to 'const' (line 51)")
end)

test("Block-loop: Class method cycle", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {113, 2})  -- On 'regularMethod()' (line 113)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(115, pos[1], "Should jump to closing bracket (line 115)")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(113, pos[1], "Should cycle back to method name (line 113)")
end)

test("Block-loop: If-else-if-else full chain cycle", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {20, 2})  -- On 'if' in ifElseIfElse (line 20)
  
  -- if → else if (first)
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(22, pos[1], "Should jump from if to first else if (line 22)")
  
  -- else if (first) → else if (second)
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(24, pos[1], "Should jump to second else if (line 24)")
  
  -- else if (second) → else
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(26, pos[1], "Should jump to else (line 26)")
  
  -- else → }
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(28, pos[1], "Should jump to closing bracket (line 28)")
  
  -- } → if (cycle back)
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(20, pos[1], "Should cycle back to if (line 20)")
end)

test("Block-loop: Switch statement full cycle", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {92, 2})  -- On 'switch' keyword (line 92)
  
  -- switch → case "one"
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(93, pos[1], "Should jump to case 'one' (line 93)")
  
  -- case "one" → case "two"
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(97, pos[1], "Should jump to case 'two' (line 97)")
  
  -- case "two" → case "three"
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(101, pos[1], "Should jump to case 'three' (line 101)")
  
  -- case "three" → default
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(105, pos[1], "Should jump to default (line 105)")
  
  -- default → }
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(107, pos[1], "Should jump to closing bracket (line 107)")
  
  -- } → switch (cycle)
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(92, pos[1], "Should cycle back to switch (line 92)")
end)

test("Block-loop: Function call with object argument (router pattern)", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {65, 0})  -- On 'const routerExample' (line 65)
  
  -- Should jump to closing ) of router(...) call, not closing } of object argument
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(73, pos[1], "Should jump to closing ) at line 73")
  
  -- Cycle back to const
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(65, pos[1], "Should cycle back to 'const' at line 65")
end)

test("Block-loop: No-op when cursor not on keyword line", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {7, 4})  -- Inside if block body
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should not move when not on keyword line")
end)

test("Block-loop: Type declaration simple", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {154, 0})  -- On 'type' keyword (line 154)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(157, pos[1], "Should jump to closing }; (line 157)")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(154, pos[1], "Should cycle back to 'type' (line 154)")
end)

test("Block-loop: Type declaration with intersection", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {159, 0})  -- On 'type' keyword (line 159)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(164, pos[1], "Should jump to closing }; (line 164)")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(159, pos[1], "Should cycle back to 'type' (line 159)")
end)

test("Block-loop: Method chain - cursor on first method", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {168, 25})  -- On 'bar' in foo.bar().baz().gaz()
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(168, pos[1], "Should jump to closing ) of bar()")
  assert_eq(29, pos[2], "Should be at column 29 (closing paren of bar())")
end)

test("Block-loop: Method chain - cursor on middle method", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {168, 32})  -- On 'baz' in foo.bar().baz().gaz()
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(168, pos[1], "Should jump to closing ) of baz()")
  assert_eq(35, pos[2], "Should be at column 35 (closing paren of baz())")
end)

test("Block-loop: Method chain - cursor on last method", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {168, 38})  -- On 'gaz' in foo.bar().baz().gaz()
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(168, pos[1], "Should jump to closing ) of gaz()")
  assert_eq(41, pos[2], "Should be at column 41 (closing paren of gaz())")
end)

test("Block-loop: Multiline method chain with complex arguments", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {174, 3})  -- On 'refine' method (line 174)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(181, pos[1], "Should jump to closing ) of refine() at line 181")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(174, pos[1], "Should cycle back to 'refine' (line 174)")
end)

test("Block-loop: Export keyword on export const", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {185, 0})  -- On 'export' keyword (line 185)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(188, pos[1], "Should jump to closing }; (line 188)")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(185, pos[1], "Should cycle back to 'export' (line 185)")
end)

test("Block-loop: Object property with chained value", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {193, 2})  -- On 'consumeToken' property (line 193)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(197, pos[1], "Should jump to closing ) of .mutation() at line 197")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(193, pos[1], "Should cycle back to 'consumeToken' (line 193)")
end)

test("Block-loop: Object property with single method chain", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {199, 2})  -- On 'otherMethod' property (line 199)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(201, pos[1], "Should jump to closing ) of .query() at line 201")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(199, pos[1], "Should cycle back to 'otherMethod' (line 199)")
end)

test("Block-loop: Method in chain - first .input() cycles", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {211, 5})  -- On first '.input' method (line 211)
  
  -- Jump to closing paren
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(211, pos[1], "Should jump to closing ) of first .input() on same line")
  local closing_col = pos[2]
  
  -- Cycle back to method name
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(211, pos[1], "Should cycle back to same line")
  assert_eq(5, pos[2], "Should cycle back to '.input' method name at col 5")
  
  -- Cycle forward to closing paren again
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(211, pos[1], "Should cycle forward to closing paren")
  assert_eq(closing_col, pos[2], "Should be at closing paren column")
end)

test("Block-loop: Method in chain - second .input()", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {212, 5})  -- On second '.input' method (line 212)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(212, pos[1], "Should jump to closing ) of second .input() on same line")
  
  -- Since this is the last method in the chain, pressing again jumps to property name
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(207, pos[1], "Should jump to property name 'getProd' (line 207)")
end)

test("Block-loop: End of chain jumps to property name", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {212, 39})  -- At closing ) of second .input() (line 212, col 39)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(207, pos[1], "Should jump to property name 'getProd' (line 207)")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(212, pos[1], "Should cycle back to end of chain (line 212)")
end)

test("Block-loop: Member call from object (analytics.capture)", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/call_expressions.ts")
  vim.api.nvim_win_set_cursor(0, {4, 0})  -- On 'analytics' (line 4)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(10, pos[1], "Should jump from 'analytics' to closing ) (line 10)")
  assert_eq(1, pos[2], "Should be at closing paren")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(4, pos[1], "Should cycle back to method name line (line 4)")
  assert_eq(10, pos[2], "Should cycle back to 'capture' method name (col 10)")
end)

test("Block-loop: Member call from method (analytics.capture)", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/call_expressions.ts")
  vim.api.nvim_win_set_cursor(0, {4, 10})  -- On 'capture' (line 4)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(10, pos[1], "Should jump from 'capture' to closing ) (line 10)")
  assert_eq(1, pos[2], "Should be at closing paren")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(4, pos[1], "Should cycle back to 'capture' (line 4)")
  assert_eq(10, pos[2], "Should be at 'capture' method name (col 10)")
end)

test("Block-loop: Simple member call foo.bar()", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/call_expressions.ts")
  vim.api.nvim_win_set_cursor(0, {13, 0})  -- On 'foo' (line 13)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(13, pos[1], "Should jump to closing ) on same line")
  assert_eq(8, pos[2], "Should be at closing paren (col 8)")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(13, pos[1], "Should cycle back to same line")
  assert_eq(4, pos[2], "Should cycle back to 'bar' method name (col 4)")
end)

test("Block-loop: Await simple call", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/call_expressions.ts")
  vim.api.nvim_win_set_cursor(0, {19, 0})  -- On 'await' (line 19)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(19, pos[1], "Should jump to closing ) on same line")
  assert_eq(10, pos[2], "Should be at closing paren")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(19, pos[1], "Should cycle back to 'await' keyword")
  assert_eq(0, pos[2], "Should be at 'await' keyword (col 0)")
end)

test("Block-loop: Await member call from await", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/call_expressions.ts")
  vim.api.nvim_win_set_cursor(0, {20, 0})  -- On 'await' (line 20)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(20, pos[1], "Should jump to closing ) on same line")
  assert_eq(14, pos[2], "Should be at closing paren")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(20, pos[1], "Should cycle back to 'await' keyword")
  assert_eq(0, pos[2], "Should be at 'await' keyword (col 0)")
end)

test("Block-loop: Await member call from object", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/call_expressions.ts")
  vim.api.nvim_win_set_cursor(0, {20, 6})  -- On 'bar' in 'await bar.baz()' (line 20)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(20, pos[1], "Should jump to closing ) on same line")
  assert_eq(14, pos[2], "Should be at closing paren")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(20, pos[1], "Should cycle back to 'await' keyword")
  assert_eq(0, pos[2], "Should cycle back to 'await' keyword, not 'bar'")
end)

test("Block-loop: Await member call from method", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/call_expressions.ts")
  vim.api.nvim_win_set_cursor(0, {20, 10})  -- On 'baz' in 'await bar.baz()' (line 20)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(20, pos[1], "Should jump to closing ) on same line")
  assert_eq(14, pos[2], "Should be at closing paren")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(20, pos[1], "Should cycle back to 'await' keyword")
  assert_eq(0, pos[2], "Should cycle back to 'await' keyword (not method name)")
end)

test("Block-loop: Nested member call from first object", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/nested_member_calls.ts")
  vim.api.nvim_win_set_cursor(0, {2, 0})  -- On 'analytics' (line 2)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(8, pos[1], "Should jump to closing ) (line 8)")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(2, pos[1], "Should cycle back to line 2")
  assert_eq(14, pos[2], "Should cycle back to 'capture' (final method name)")
end)

test("Block-loop: Nested member call from middle property", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/nested_member_calls.ts")
  vim.api.nvim_win_set_cursor(0, {2, 10})  -- On 'foo' (line 2)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(8, pos[1], "Should jump to closing ) (line 8)")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(2, pos[1], "Should cycle back to line 2")
  assert_eq(14, pos[2], "Should cycle back to 'capture'")
end)

test("Block-loop: Nested member call from final method", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/nested_member_calls.ts")
  vim.api.nvim_win_set_cursor(0, {2, 14})  -- On 'capture' (line 2)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(8, pos[1], "Should jump to closing ) (line 8)")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(2, pos[1], "Should cycle back to line 2")
  assert_eq(14, pos[2], "Should cycle back to 'capture'")
end)

test("Block-loop: Deep nested member call", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/nested_member_calls.ts")
  vim.api.nvim_win_set_cursor(0, {11, 0})  -- On 'obj' in obj.a.b.c.method()
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(11, pos[1], "Should jump to closing ) on same line")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(11, pos[1], "Should cycle back to same line")
end)

test("Block-loop: Await with nested member call", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/nested_member_calls.ts")
  vim.api.nvim_win_set_cursor(0, {14, 0})  -- On 'await' in await analytics.track.event()
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(14, pos[1], "Should jump to closing ) on same line")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(14, pos[1], "Should cycle back to 'await'")
  assert_eq(0, pos[2], "Should be at 'await' keyword")
end)

test("Block-loop: Property value from beginning of value chain", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {193, 18})  -- On 'procedure' (beginning of value chain)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(197, pos[1], "Should jump to end of entire chain (mutation closing)")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(193, pos[1], "Should cycle back to property name")
  assert_eq(2, pos[2], "Should be at 'consumeToken'")
end)

test("Block-loop: Property value from middle of chain", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {194, 5})  -- On '.input' (middle of chain)
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(194, pos[1], "Should jump to closing ) of .input()")
  assert_eq(42, pos[2], "Should be at closing paren of .input()")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(194, pos[1], "Should cycle back to .input")
  assert_eq(5, pos[2], "Should be at 'i' in .input")
end)

test("Block-loop: Property value cycle back from end", function()
  local block_loop = sibling_jump.block_loop()
  vim.cmd("edit tests/fixtures/block_loop.ts")
  vim.api.nvim_win_set_cursor(0, {197, 5})  -- At closing ) of .mutation()
  
  block_loop.jump_to_boundary({ mode = "normal" })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(193, pos[1], "Should jump back to property name")
  assert_eq(2, pos[2], "Should be at 'consumeToken'")
  
  block_loop.jump_to_boundary({ mode = "normal" })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(197, pos[1], "Should jump back to end of chain")
end)

-- Run all tests
run_tests()
