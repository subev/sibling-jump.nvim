-- Direct test runner without plenary
-- Run with: nvim --headless -c "luafile tests/run_tests.lua"

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
  print("=== Running sibling_jump tests ===")
  print("")

  for _, t in ipairs(tests) do
    local ok, err = pcall(t.fn)

    if ok then
      -- Format with fixed width for alignment
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
-- TESTS
-- ============================================================================

test("TypeScript properties: forward navigation", function()
  vim.cmd("edit tests/fixtures/type_properties.ts")
  vim.api.nvim_win_set_cursor(0, { 4, 4 })

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should jump from contentUrl (L4) to slug (L5)")
end)

test("TypeScript properties: backward navigation", function()
  vim.cmd("edit tests/fixtures/type_properties.ts")
  vim.api.nvim_win_set_cursor(0, { 5, 4 })

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(4, pos[1], "Should jump from slug (L5) to contentUrl (L4)")
end)

test("TypeScript properties: no-op at first", function()
  vim.cmd("edit tests/fixtures/type_properties.ts")
  vim.api.nvim_win_set_cursor(0, { 4, 4 })

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(4, pos[1], "Should not move from first property")
end)

test("TypeScript properties: no-op at last", function()
  vim.cmd("edit tests/fixtures/type_properties.ts")
  vim.api.nvim_win_set_cursor(0, { 12, 4 })

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(12, pos[1], "Should not move from last property")
end)

test("JSX elements: forward navigation", function()
  vim.cmd("edit tests/fixtures/jsx_elements.tsx")
  vim.api.nvim_win_set_cursor(0, { 5, 8 })

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(9, pos[1], "Should jump from HeaderContent (L5) to Header (L9)")
end)

test("JSX elements: backward navigation", function()
  vim.cmd("edit tests/fixtures/jsx_elements.tsx")
  vim.api.nvim_win_set_cursor(0, { 9, 8 })

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should jump from Header (L9) to HeaderContent (L5)")
end)

test("JSX elements: child with no siblings stays put", function()
  vim.cmd("edit tests/fixtures/jsx_elements.tsx")
  vim.api.nvim_win_set_cursor(0, { 14, 10 })

  sibling_jump.jump_to_sibling({ forward = false })
  local pos1 = vim.api.nvim_win_get_cursor(0)
  assert_eq(14, pos1[1], "Should not jump backward from child with no siblings")

  sibling_jump.jump_to_sibling({ forward = true })
  local pos2 = vim.api.nvim_win_get_cursor(0)
  assert_eq(14, pos2[1], "Should not jump forward from child with no siblings")
end)

test("JSX elements: non-self-closing forward", function()
  vim.cmd("edit tests/fixtures/jsx_elements.tsx")
  vim.api.nvim_win_set_cursor(0, { 13, 8 })

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(16, pos[1], "Should jump from PersistentTabContainer (L13) to TabContainer (L16)")
end)

test("JSX elements: non-self-closing backward", function()
  vim.cmd("edit tests/fixtures/jsx_elements.tsx")
  vim.api.nvim_win_set_cursor(0, { 16, 8 })

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(13, pos[1], "Should jump from TabContainer (L16) to PersistentTabContainer (L13)")
end)

test("Destructuring: forward navigation", function()
  vim.cmd("edit tests/fixtures/destructuring.ts")
  vim.api.nvim_win_set_cursor(0, { 5, 4 })

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should jump from currentTab:tab (L5) to setCurrentTab (L6)")
end)

test("Destructuring: backward navigation", function()
  vim.cmd("edit tests/fixtures/destructuring.ts")
  vim.api.nvim_win_set_cursor(0, { 6, 4 })

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should jump from setCurrentTab (L6) to currentTab:tab (L5)")
end)

test("Statements: forward navigation", function()
  vim.cmd("edit tests/fixtures/statements.ts")
  vim.api.nvim_win_set_cursor(0, { 3, 2 })

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(4, pos[1], "Should jump from const a (L3) to const b (L4)")
end)

test("Statements: backward navigation", function()
  vim.cmd("edit tests/fixtures/statements.ts")
  vim.api.nvim_win_set_cursor(0, { 4, 2 })

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(3, pos[1], "Should jump from const b (L4) to const a (L3)")
end)

test("JSX attributes: forward navigation", function()
  vim.cmd("edit tests/fixtures/jsx_attributes.tsx")
  vim.api.nvim_win_set_cursor(0, { 5, 6 }) -- className attribute

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should jump from className (L5) to style (L6)")
end)

test("JSX attributes: backward navigation", function()
  vim.cmd("edit tests/fixtures/jsx_attributes.tsx")
  vim.api.nvim_win_set_cursor(0, { 7, 6 }) -- onClick attribute

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should jump from onClick (L7) to style (L6)")
end)

test("JSX attributes: no-op at last", function()
  vim.cmd("edit tests/fixtures/jsx_attributes.tsx")
  vim.api.nvim_win_set_cursor(0, { 15, 8 }) -- onClick on Button (last attribute of Button)

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(15, pos[1], "Should not move from last attribute")
end)

test("JSX attributes: no-op at first", function()
  vim.cmd("edit tests/fixtures/jsx_attributes.tsx")
  vim.api.nvim_win_set_cursor(0, { 5, 6 }) -- className attribute (first attribute)

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should not move from first attribute")
end)

test("Type declarations: forward navigation", function()
  vim.cmd("edit tests/fixtures/type_declarations.ts")
  vim.api.nvim_win_set_cursor(0, { 8, 6 }) -- Inside RecentPlayedItem type alias

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(13, pos[1], "Should jump from RecentPlayedItem (L8) to NotificationItem (L13)")
end)

test("Type declarations: backward navigation", function()
  vim.cmd("edit tests/fixtures/type_declarations.ts")
  vim.api.nvim_win_set_cursor(0, { 13, 6 }) -- Inside NotificationItem type alias

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(8, pos[1], "Should jump from NotificationItem (L13) to RecentPlayedItem (L8)")
end)

test("Type declarations: interface forward", function()
  vim.cmd("edit tests/fixtures/type_declarations.ts")
  vim.api.nvim_win_set_cursor(0, { 21, 10 }) -- Inside UserProfile interface

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(26, pos[1], "Should jump from UserProfile (L21) to AdminProfile (L26)")
end)

test("Type declarations: interface backward", function()
  vim.cmd("edit tests/fixtures/type_declarations.ts")
  vim.api.nvim_win_set_cursor(0, { 26, 10 }) -- Inside AdminProfile interface

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(21, pos[1], "Should jump from AdminProfile (L26) to UserProfile (L21)")
end)

test("Whitespace navigation: backward from empty line", function()
  vim.cmd("edit tests/fixtures/statements.ts")
  vim.api.nvim_win_set_cursor(0, { 6, 0 }) -- Empty line between const c and if statement

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should jump to const c (closest statement above empty line)")
end)

test("Whitespace navigation: forward from empty line", function()
  vim.cmd("edit tests/fixtures/statements.ts")
  vim.api.nvim_win_set_cursor(0, { 6, 0 }) -- Empty line between const c and if statement

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should jump to if statement (closest statement below empty line)")
end)

test("JSX cursor position: lands on tag name not angle bracket", function()
  vim.cmd("edit tests/fixtures/jsx_elements.tsx")
  vim.api.nvim_win_set_cursor(0, { 5, 7 }) -- On HeaderContent

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)

  -- Should jump to L9 (Header element)
  assert_eq(9, pos[1], "Should jump to Header element")

  -- Check that cursor is on 'H' (first char of tag name), not '<'
  local line = vim.api.nvim_buf_get_lines(0, pos[1] - 1, pos[1], false)[1]
  local char_at_cursor = line:sub(pos[2] + 1, pos[2] + 1)
  assert_eq("H", char_at_cursor, "Cursor should be on 'H' of Header, not '<'")
end)

test("Method chains: forward navigation", function()
  vim.cmd("edit tests/fixtures/method_chains.ts")
  vim.api.nvim_win_set_cursor(0, { 5, 3 }) -- On methodA

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should jump from methodA to methodB")

  -- Check cursor is on 'm' of methodB
  local line = vim.api.nvim_buf_get_lines(0, pos[1] - 1, pos[1], false)[1]
  assert_eq("m", line:sub(pos[2] + 1, pos[2] + 1), "Cursor should be on 'm' of methodB")
end)

test("Method chains: backward navigation", function()
  vim.cmd("edit tests/fixtures/method_chains.ts")
  vim.api.nvim_win_set_cursor(0, { 6, 3 }) -- On methodB

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should jump from methodB to methodA")
end)

test("Method chains: no-op at start", function()
  vim.cmd("edit tests/fixtures/method_chains.ts")
  vim.api.nvim_win_set_cursor(0, { 5, 3 }) -- On methodA (first in chain)

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should not move from first method in chain")
end)

test("Method chains: no-op at end", function()
  vim.cmd("edit tests/fixtures/method_chains.ts")
  vim.api.nvim_win_set_cursor(0, { 7, 3 }) -- On methodC (last in chain)

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should not move from last method in chain")
end)

test("Method chains: inline chain navigation", function()
  vim.cmd("edit tests/fixtures/method_chains.ts")
  vim.api.nvim_win_set_cursor(0, { 10, 19 }) -- On foo in obj.foo().bar().baz()

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(10, pos[1], "Should stay on same line")
  assert_eq(25, pos[2], "Should jump to bar")

  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(31, pos[2], "Should jump to baz")
end)

test("Method chains: single method uses regular navigation", function()
  vim.cmd("edit tests/fixtures/method_chains.ts")
  vim.api.nvim_win_set_cursor(0, { 13, 22 }) -- On method in obj.method()

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(16, pos[1], "Should use regular navigation to next statement")
end)

test("Method chains: starting identifier uses regular navigation", function()
  vim.cmd("edit tests/fixtures/method_chains.ts")
  vim.api.nvim_win_set_cursor(0, { 4, 15 }) -- On obj identifier before .methodA()

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(10, pos[1], "Should use regular navigation to next statement, not enter chain")
end)

test("JSX cursor position: non-self-closing element", function()
  vim.cmd("edit tests/fixtures/jsx_elements.tsx")
  vim.api.nvim_win_set_cursor(0, { 9, 7 }) -- On Header

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)

  -- Should jump to L13 (PersistentTabContainer element)
  assert_eq(13, pos[1], "Should jump to PersistentTabContainer element")

  -- Check that cursor is on 'P' (first char of tag name), not '<'
  local line = vim.api.nvim_buf_get_lines(0, pos[1] - 1, pos[1], false)[1]
  local char_at_cursor = line:sub(pos[2] + 1, pos[2] + 1)
  assert_eq("P", char_at_cursor, "Cursor should be on 'P' of PersistentTabContainer, not '<'")
end)

test("Context boundaries: navigate between object properties", function()
  vim.cmd("edit tests/fixtures/object_properties.ts")
  vim.api.nvim_win_set_cursor(0, { 12, 2 }) -- On "getPosts" property key

  -- Forward should jump to next property within the object
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(17, pos[1], "Should jump to getUsers property within same object")

  -- Backward should jump back to getPosts
  sibling_jump.jump_to_sibling({ forward = false })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(12, pos[1], "Should jump back to getPosts property")
end)

test("Context boundaries: single property is no-op", function()
  vim.cmd("edit tests/fixtures/object_properties.ts")
  vim.api.nvim_win_set_cursor(0, { 25, 2 }) -- On "outer" property (only property in nested object)

  -- Should be no-op (only one property, jumping would exit context)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(25, pos[1], "Should not move when only one property in object")
end)

test("Context boundaries: inside method chain value works", function()
  vim.cmd("edit tests/fixtures/object_properties.ts")
  vim.api.nvim_win_set_cursor(0, { 13, 5 }) -- On .input in the method chain value

  -- Should navigate within the method chain
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(14, pos[1], "Should navigate within method chain value")
end)

test("Object properties: shorthand property forward navigation", function()
  vim.cmd("edit tests/fixtures/object_properties.ts")
  vim.api.nvim_win_set_cursor(0, { 32, 2 }) -- On "registered" shorthand property

  -- Forward should jump to next shorthand property
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(33, pos[1], "Should jump from registered to scenario")
end)

test("Object properties: shorthand property backward navigation", function()
  vim.cmd("edit tests/fixtures/object_properties.ts")
  vim.api.nvim_win_set_cursor(0, { 33, 2 }) -- On "scenario" shorthand property

  -- Backward should jump to previous shorthand property
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(32, pos[1], "Should jump from scenario back to registered")
end)

test("Object properties: mixed shorthand and normal properties forward", function()
  vim.cmd("edit tests/fixtures/object_properties.ts")
  vim.api.nvim_win_set_cursor(0, { 33, 2 }) -- On "scenario" shorthand property

  -- Forward should jump to normal property
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(34, pos[1], "Should jump from shorthand to normal property")
end)

test("Object properties: mixed normal and shorthand properties backward", function()
  vim.cmd("edit tests/fixtures/object_properties.ts")
  vim.api.nvim_win_set_cursor(0, { 34, 2 }) -- On "normalProp" (regular pair property)

  -- Backward should jump to shorthand property
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(33, pos[1], "Should jump from normal property back to shorthand")
end)

test("Arrays: forward navigation", function()
  vim.cmd("edit tests/fixtures/arrays.ts")
  vim.api.nvim_win_set_cursor(0, { 4, 17 }) -- On first number (1)

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(4, pos[1], "Should stay on same line")
  assert_eq(20, pos[2], "Should jump to second element (2)")
end)

test("Arrays: backward navigation", function()
  vim.cmd("edit tests/fixtures/arrays.ts")
  vim.api.nvim_win_set_cursor(0, { 4, 20 }) -- On second number (2)

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(4, pos[1], "Should stay on same line")
  assert_eq(17, pos[2], "Should jump to first element (1)")
end)

test("Arrays: no-op at start", function()
  vim.cmd("edit tests/fixtures/arrays.ts")
  vim.api.nvim_win_set_cursor(0, { 4, 17 }) -- On first element

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(17, pos[2], "Should not move from first element")
end)

test("Arrays: no-op at end", function()
  vim.cmd("edit tests/fixtures/arrays.ts")
  vim.api.nvim_win_set_cursor(0, { 4, 29 }) -- On last element (5)

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(29, pos[2], "Should not move from last element")
end)

test("Arrays: navigate between objects", function()
  vim.cmd("edit tests/fixtures/arrays.ts")
  vim.api.nvim_win_set_cursor(0, { 8, 2 }) -- On first object (on the { brace)

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(9, pos[1], "Should jump to second object")
end)

test("Arrays: single element is no-op", function()
  vim.cmd("edit tests/fixtures/arrays.ts")
  vim.api.nvim_win_set_cursor(0, { 20, 16 }) -- On single element array [1]

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(20, pos[1], "Should not move from single element")
end)

test("Function params: forward navigation", function()
  vim.cmd("edit tests/fixtures/function_params.ts")
  vim.api.nvim_win_set_cursor(0, { 4, 14 }) -- On first parameter 'a'

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(4, pos[1], "Should stay on same line")
  -- Should jump to 'b' parameter (around C24)
  assert_eq(true, pos[2] > 20 and pos[2] < 30, "Should jump to second parameter")
end)

test("Function params: backward navigation", function()
  vim.cmd("edit tests/fixtures/function_params.ts")
  vim.api.nvim_win_set_cursor(0, { 4, 36 }) -- On third parameter 'c'

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(4, pos[1], "Should stay on same line")
  -- Should jump to 'b' parameter
  assert_eq(true, pos[2] > 20 and pos[2] < 30, "Should jump to second parameter")
end)

test("Function params: no-op at boundaries", function()
  vim.cmd("edit tests/fixtures/function_params.ts")
  vim.api.nvim_win_set_cursor(0, { 4, 14 }) -- On first parameter

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(14, pos[2], "Should not move from first parameter")
end)

test("Function args: forward navigation", function()
  vim.cmd("edit tests/fixtures/function_params.ts")
  vim.api.nvim_win_set_cursor(0, { 7, 4 }) -- On first argument '1'

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should stay on same line")
  -- Should jump to second argument '2'
  assert_eq(7, pos[2], "Should jump to second argument")
end)

test("Function args: backward navigation", function()
  vim.cmd("edit tests/fixtures/function_params.ts")
  vim.api.nvim_win_set_cursor(0, { 7, 10 }) -- On third argument '3'

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should stay on same line")
  -- Should jump to second argument '2'
  assert_eq(7, pos[2], "Should jump to second argument")
end)

test("Function params: single parameter is no-op", function()
  vim.cmd("edit tests/fixtures/function_params.ts")
  vim.api.nvim_win_set_cursor(0, { 10, 16 }) -- On single parameter 'x'

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(10, pos[1], "Should not move from single parameter")
end)

test("Function params: multi-line navigation", function()
  vim.cmd("edit tests/fixtures/function_params.ts")
  vim.api.nvim_win_set_cursor(0, { 17, 2 }) -- On first parameter 'first'

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(18, pos[1], "Should jump to next line (second parameter)")

  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(19, pos[1], "Should jump to third parameter")
end)

test("Imports: multi-line forward navigation", function()
  vim.cmd("edit tests/fixtures/imports.ts")
  vim.api.nvim_win_set_cursor(0, { 5, 2 }) -- On UserRepository

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should jump to timezone")

  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should jump to username")
end)

test("Imports: multi-line backward navigation", function()
  vim.cmd("edit tests/fixtures/imports.ts")
  vim.api.nvim_win_set_cursor(0, { 8, 2 }) -- On UserLifecycleService (last)

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should jump to username")
end)

test("Imports: no-op at boundaries", function()
  vim.cmd("edit tests/fixtures/imports.ts")
  vim.api.nvim_win_set_cursor(0, { 5, 2 }) -- On first import

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should not move from first import")

  -- Jump to last
  vim.api.nvim_win_set_cursor(0, { 8, 2 })
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(8, pos[1], "Should not move from last import")
end)

test("Imports: single line navigation", function()
  vim.cmd("edit tests/fixtures/imports.ts")
  vim.api.nvim_win_set_cursor(0, { 12, 9 }) -- On 'foo' in single line import

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(12, pos[1], "Should stay on same line")
  -- Should jump to 'bar'
  assert_eq(true, pos[2] > 10, "Should have moved to next import")
end)

test("Imports: single import is no-op", function()
  vim.cmd("edit tests/fixtures/imports.ts")
  vim.api.nvim_win_set_cursor(0, { 15, 9 }) -- On 'single' (only import)

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(15, pos[1], "Should not move from single import")
end)

test("Nested contexts: statements inside arrow function in arguments", function()
  vim.cmd("edit tests/fixtures/nested_contexts.ts")
  vim.api.nvim_win_set_cursor(0, { 6, 4 }) -- On 'const parsed' inside arrow function

  -- Should navigate to next statement in same function, not jump to next argument
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should jump to if statement, not exit to next argument")

  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(10, pos[1], "Should jump to return statement")
end)

test("Nested contexts: statements inside function in array", function()
  vim.cmd("edit tests/fixtures/nested_contexts.ts")
  vim.api.nvim_win_set_cursor(0, { 20, 4 }) -- On 'const a' inside first function

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(21, pos[1], "Should jump to const b within same function")
end)

-- ============================================================================
-- GENERIC TYPES TESTS
-- ============================================================================

test("Generic types: forward navigation", function()
  vim.cmd("edit tests/fixtures/generic_types.ts")
  vim.api.nvim_win_set_cursor(0, { 5, 14 }) -- On 'T' in Generic1<T, U, V>

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should stay on same line")
  assert_eq(17, pos[2], "Should jump from T to U")
end)

test("Generic types: backward navigation", function()
  vim.cmd("edit tests/fixtures/generic_types.ts")
  vim.api.nvim_win_set_cursor(0, { 5, 17 }) -- On 'U' in Generic1<T, U, V>

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should stay on same line")
  assert_eq(14, pos[2], "Should jump from U to T")
end)

test("Generic types: no-op at boundaries", function()
  vim.cmd("edit tests/fixtures/generic_types.ts")
  vim.api.nvim_win_set_cursor(0, { 5, 14 }) -- On 'T' in Generic1<T, U, V>

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(14, pos[2], "Should not move backward from first parameter")

  vim.api.nvim_win_set_cursor(0, { 5, 20 }) -- On 'V'
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(20, pos[2], "Should not move forward from last parameter")
end)

test("Generic types: function generics", function()
  vim.cmd("edit tests/fixtures/generic_types.ts")
  vim.api.nvim_win_set_cursor(0, { 12, 18 }) -- On 'A' in identity<A, B, C>

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(12, pos[1], "Should stay on same line")
  assert_eq(21, pos[2], "Should jump from A to B")
end)

test("Generic types: class generics", function()
  vim.cmd("edit tests/fixtures/generic_types.ts")
  vim.api.nvim_win_set_cursor(0, { 32, 14 }) -- On 'Alpha' in MyClass<Alpha, Beta, Gamma>

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(32, pos[1], "Should stay on same line")
  assert_eq(21, pos[2], "Should jump from Alpha to Beta")

  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(27, pos[2], "Should jump from Beta to Gamma")
end)

-- ============================================================================
-- UNION TYPES TESTS
-- ============================================================================

test("Union types: forward navigation simple", function()
  vim.cmd("edit tests/fixtures/union_types.ts")
  vim.api.nvim_win_set_cursor(0, { 5, 16 }) -- On '"pending"' in Status

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should stay on same line")
  -- Position should be at "success"
end)

test("Union types: backward navigation simple", function()
  vim.cmd("edit tests/fixtures/union_types.ts")
  vim.api.nvim_win_set_cursor(0, { 5, 30 }) -- On '"success"'

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should stay on same line")
  -- Position should be at "pending"
end)

test("Union types: multiline forward navigation", function()
  vim.cmd("edit tests/fixtures/union_types.ts")
  vim.api.nvim_win_set_cursor(0, { 25, 4 }) -- On 'Circle' in Shape multiline union

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(26, pos[1], "Should jump from Circle to Square")
end)

test("Union types: multiline backward navigation", function()
  vim.cmd("edit tests/fixtures/union_types.ts")
  vim.api.nvim_win_set_cursor(0, { 26, 4 }) -- On 'Square'

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(25, pos[1], "Should jump from Square to Circle")
end)

test("Union types: no-op at boundaries", function()
  vim.cmd("edit tests/fixtures/union_types.ts")
  vim.api.nvim_win_set_cursor(0, { 25, 4 }) -- On 'Circle' (first)

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(25, pos[1], "Should not move backward from first union member")

  vim.api.nvim_win_set_cursor(0, { 28, 4 }) -- On 'Rectangle' (last)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(28, pos[1], "Should not move forward from last union member")
end)

test("Union types: discriminated union", function()
  vim.cmd("edit tests/fixtures/union_types.ts")
  vim.api.nvim_win_set_cursor(0, { 52, 4 }) -- On first action type (object type)

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(53, pos[1], "Should jump to next action type")
end)

-- ============================================================================
-- TUPLE DESTRUCTURING TESTS
-- ============================================================================

test("Tuple destructuring: forward navigation", function()
  vim.cmd("edit tests/fixtures/tuple_destructuring.ts")
  vim.api.nvim_win_set_cursor(0, { 5, 7 }) -- On 'first' in [first, second, third]

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should stay on same line")
  assert_eq(14, pos[2], "Should jump from first to second")
end)

test("Tuple destructuring: backward navigation", function()
  vim.cmd("edit tests/fixtures/tuple_destructuring.ts")
  vim.api.nvim_win_set_cursor(0, { 5, 14 }) -- On 'second'

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should stay on same line")
  assert_eq(7, pos[2], "Should jump from second to first")
end)

test("Tuple destructuring: no-op at boundaries", function()
  vim.cmd("edit tests/fixtures/tuple_destructuring.ts")
  vim.api.nvim_win_set_cursor(0, { 5, 7 }) -- On 'first'

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[2], "Should not move backward from first element")

  vim.api.nvim_win_set_cursor(0, { 5, 23 }) -- On 'third'
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(23, pos[2], "Should not move forward from last element")
end)

test("Tuple destructuring: nested tuples", function()
  vim.cmd("edit tests/fixtures/tuple_destructuring.ts")
  vim.api.nvim_win_set_cursor(0, { 11, 8 }) -- On 'a' in [[a, b], [c, d]]

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(11, pos[1], "Should stay on same line")
  assert_eq(11, pos[2], "Should jump from a to b")
end)

test("Tuple destructuring: React hooks style", function()
  vim.cmd("edit tests/fixtures/tuple_destructuring.ts")
  vim.api.nvim_win_set_cursor(0, { 30, 7 }) -- On 'count' in [count, setCount]

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(30, pos[1], "Should stay on same line")
  assert_eq(14, pos[2], "Should jump from count to setCount")
end)

test("Tuple destructuring: multiline", function()
  vim.cmd("edit tests/fixtures/tuple_destructuring.ts")
  vim.api.nvim_win_set_cursor(0, { 61, 2 }) -- On 'promise1' in multiline tuple

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(62, pos[1], "Should jump from promise1 to promise2")
end)

-- ============================================================================
-- FUNCTION PARAMETER DESTRUCTURING TESTS
-- ============================================================================

test("Function param destructuring: forward navigation", function()
  vim.cmd("edit tests/fixtures/function_param_destructuring.ts")
  vim.api.nvim_win_set_cursor(0, { 5, 4 }) -- On 'dateOfLastReminder' parameter name

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should jump from dateOfLastReminder (L5) to context (L6)")
end)

test("Function param destructuring: backward navigation", function()
  vim.cmd("edit tests/fixtures/function_param_destructuring.ts")
  vim.api.nvim_win_set_cursor(0, { 6, 4 }) -- On 'context' parameter name

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should jump from context (L6) to dateOfLastReminder (L5)")
end)

test("Function param destructuring: no-op at first parameter", function()
  vim.cmd("edit tests/fixtures/function_param_destructuring.ts")
  vim.api.nvim_win_set_cursor(0, { 5, 4 }) -- On first parameter

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should not move from first parameter")
end)

test("Function param destructuring: no-op at last parameter", function()
  vim.cmd("edit tests/fixtures/function_param_destructuring.ts")
  vim.api.nvim_win_set_cursor(0, { 6, 4 }) -- On last parameter

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should not move from last parameter (should not jump to type properties)")
end)

test("Function param destructuring: type properties navigation", function()
  vim.cmd("edit tests/fixtures/function_param_destructuring.ts")
  vim.api.nvim_win_set_cursor(0, { 8, 4 }) -- On 'dateOfLastReminder' type property

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(9, pos[1], "Should jump from dateOfLastReminder type (L8) to context type (L9)")
end)

test("Function param destructuring: multiple parameters", function()
  vim.cmd("edit tests/fixtures/function_param_destructuring.ts")
  vim.api.nvim_win_set_cursor(0, { 16, 4 }) -- On 'userId' parameter

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(17, pos[1], "Should jump from userId (L16) to timestamp (L17)")

  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(18, pos[1], "Should jump from timestamp (L17) to metadata (L18)")
end)

test("Function param destructuring: mixed shorthand and renamed", function()
  vim.cmd("edit tests/fixtures/function_param_destructuring.ts")
  vim.api.nvim_win_set_cursor(0, { 29, 4 }) -- On 'foo' (shorthand)

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(30, pos[1], "Should jump from foo (L29) to bar:renamedBar (L30)")

  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(31, pos[1], "Should jump from bar:renamedBar (L30) to baz (L31)")
end)

-- ============================================================================
-- IF-ELSE-IF CHAIN TESTS
-- ============================================================================

test("If-else chains: full chain forward navigation", function()
  vim.cmd("edit tests/fixtures/if_else_chains.ts")

  -- Start at if (line 7)
  vim.api.nvim_win_set_cursor(0, { 7, 2 })

  -- Jump to first else if (line 9)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(9, pos[1], "Should jump from if (L7) to first else if (L9)")

  -- Jump to second else if (line 11)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(11, pos[1], "Should jump from first else if (L9) to second else if (L11)")

  -- Jump to final else (line 13)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(13, pos[1], "Should jump from second else if (L11) to else (L13)")

  -- Jump to next statement (line 17)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(17, pos[1], "Should jump from else (L13) to const after (L17)")
end)

test("If-else chains: full chain backward navigation", function()
  vim.cmd("edit tests/fixtures/if_else_chains.ts")

  -- Start at const after (line 17)
  vim.api.nvim_win_set_cursor(0, { 17, 2 })

  -- Jump to else (line 13)
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(13, pos[1], "Should jump from const after (L17) to else (L13)")

  -- Jump to second else if (line 11)
  sibling_jump.jump_to_sibling({ forward = false })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(11, pos[1], "Should jump from else (L13) to second else if (L11)")

  -- Jump to first else if (line 9)
  sibling_jump.jump_to_sibling({ forward = false })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(9, pos[1], "Should jump from second else if (L11) to first else if (L9)")

  -- Jump to if (line 7)
  sibling_jump.jump_to_sibling({ forward = false })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should jump from first else if (L9) to if (L7)")

  -- Jump to const before (line 5)
  sibling_jump.jump_to_sibling({ forward = false })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should jump from if (L7) to const before (L5)")
end)

test("If-else chains: cursor on 'e' of else", function()
  vim.cmd("edit tests/fixtures/if_else_chains.ts")

  -- Start at if (line 7)
  vim.api.nvim_win_set_cursor(0, { 7, 2 })

  -- Jump to first else if (line 9)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)

  -- Check that cursor is on 'e' of 'else'
  local line = vim.api.nvim_buf_get_lines(0, pos[1] - 1, pos[1], false)[1]
  local char_at_cursor = line:sub(pos[2] + 1, pos[2] + 1)
  assert_eq("e", char_at_cursor, "Cursor should be on 'e' of 'else'")
end)

test("If-else chains: if with only else", function()
  vim.cmd("edit tests/fixtures/if_else_chains.ts")

  -- Start at if (line 24)
  vim.api.nvim_win_set_cursor(0, { 24, 2 })

  -- Jump to else (line 26)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(26, pos[1], "Should jump from if (L24) to else (L26)")

  -- Jump to next statement (line 30)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(30, pos[1], "Should jump from else (L26) to const after (L30)")
end)

test("If-else chains: if with no else skips to next statement", function()
  vim.cmd("edit tests/fixtures/if_else_chains.ts")

  -- Start at if (line 37)
  vim.api.nvim_win_set_cursor(0, { 37, 2 })

  -- Jump should skip to next statement (line 41)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(41, pos[1], "Should jump from if (L37) to const after (L41)")
end)

test("If-else chains: single else-if", function()
  vim.cmd("edit tests/fixtures/if_else_chains.ts")

  -- Start at if (line 48)
  vim.api.nvim_win_set_cursor(0, { 48, 2 })

  -- Jump to else if (line 50)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(50, pos[1], "Should jump from if (L48) to else if (L50)")

  -- Jump to next statement (line 54) - no final else
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(54, pos[1], "Should jump from else if (L50) to const after (L54)")
end)

test("If-else chains: nested if inside block uses regular navigation", function()
  vim.cmd("edit tests/fixtures/if_else_chains.ts")

  -- Start inside the outer if block at innerBefore (line 62)
  vim.api.nvim_win_set_cursor(0, { 62, 4 })

  -- Jump should go to inner if (line 64), not outer else
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(64, pos[1], "Should jump to inner if (L64), not exit to outer else")
end)

-- JSX conditionals and expressions
test("JSX conditionals: forward through conditional expressions", function()
  vim.cmd("edit tests/fixtures/jsx_conditionals.tsx")

  -- Start at Header (line 8)
  vim.api.nvim_win_set_cursor(0, { 8, 8 })

  -- Jump to {registered && <ConditionalComponent />} (line 9)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(9, pos[1], "Should jump from Header (L8) to conditional expression (L9)")

  -- Jump to {!registered && <AlternativeComponent />} (line 10)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(10, pos[1], "Should jump from first conditional (L9) to second conditional (L10)")
end)

test("JSX conditionals: backward through conditional expressions", function()
  vim.cmd("edit tests/fixtures/jsx_conditionals.tsx")

  -- Start at {!registered && <AlternativeComponent />} (line 10)
  vim.api.nvim_win_set_cursor(0, { 10, 8 })

  -- Jump backward to {registered && <ConditionalComponent />} (line 9)
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(9, pos[1], "Should jump from second conditional (L10) to first conditional (L9)")

  -- Jump backward to Header (line 8)
  sibling_jump.jump_to_sibling({ forward = false })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(8, pos[1], "Should jump from conditional (L9) to Header (L8)")
end)

test("JSX conditionals: multiple consecutive conditionals", function()
  vim.cmd("edit tests/fixtures/jsx_conditionals.tsx")

  -- Start at {registered && <ConditionalComponent />} (line 9)
  vim.api.nvim_win_set_cursor(0, { 9, 8 })

  -- Jump forward through all conditionals
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(10, pos[1], "Should jump to line 10")

  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(11, pos[1], "Should jump to ternary expression (L11)")

  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(12, pos[1], "Should jump to wrapped conditional (L12)")
end)

test("JSX conditionals: ternary expressions", function()
  vim.cmd("edit tests/fixtures/jsx_conditionals.tsx")

  -- Start at {!registered && ...} (line 10)
  vim.api.nvim_win_set_cursor(0, { 10, 8 })

  -- Jump to ternary expression (line 11)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(11, pos[1], "Should jump to ternary expression (L11)")

  -- Jump backward to verify it works both ways
  sibling_jump.jump_to_sibling({ forward = false })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(10, pos[1], "Should jump back to line 10")
end)

test("JSX conditionals: parenthesized conditional expressions", function()
  vim.cmd("edit tests/fixtures/jsx_conditionals.tsx")

  -- Start at ternary (line 11)
  vim.api.nvim_win_set_cursor(0, { 11, 8 })

  -- Jump to parenthesized conditional (line 12)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(12, pos[1], "Should jump to parenthesized conditional (L12)")
end)

test("JSX conditionals: map expressions", function()
  vim.cmd("edit tests/fixtures/jsx_conditionals.tsx")

  -- Start at wrapped conditional (line 12)
  vim.api.nvim_win_set_cursor(0, { 12, 8 })

  -- Jump to map expression (line 15)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(15, pos[1], "Should jump to map expression (L15)")
end)

test("JSX conditionals: function call expressions", function()
  vim.cmd("edit tests/fixtures/jsx_conditionals.tsx")

  -- Start at map expression (line 15)
  vim.api.nvim_win_set_cursor(0, { 15, 8 })

  -- Jump to function call expression (line 16)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(16, pos[1], "Should jump to function call expression (L16)")

  -- Jump to Footer (line 17)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(17, pos[1], "Should jump to Footer (L17)")
end)

test("JSX conditionals: no-op at first element", function()
  vim.cmd("edit tests/fixtures/jsx_conditionals.tsx")

  -- Start at Header (line 8)
  vim.api.nvim_win_set_cursor(0, { 8, 8 })
  local initial_pos = vim.api.nvim_win_get_cursor(0)

  -- Try to jump backward (should be no-op)
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(initial_pos[1], pos[1], "Should not move from first element")
end)

test("JSX conditionals: no-op at last element", function()
  vim.cmd("edit tests/fixtures/jsx_conditionals.tsx")

  -- Start at Footer (line 17)
  vim.api.nvim_win_set_cursor(0, { 17, 8 })
  local initial_pos = vim.api.nvim_win_get_cursor(0)

  -- Try to jump forward (should be no-op)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(initial_pos[1], pos[1], "Should not move from last element")
end)

test("JSX conditionals: plain value expressions", function()
  vim.cmd("edit tests/fixtures/jsx_conditionals.tsx")

  -- Start at Header in PlainValueExpressions (line 53)
  vim.api.nvim_win_set_cursor(0, { 53, 8 })

  -- Jump to {title} (line 54)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(54, pos[1], "Should jump to {title} expression (L54)")

  -- Jump to <Content /> (line 55)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(55, pos[1], "Should jump to Content component (L55)")

  -- Jump to {userName} (line 56)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(56, pos[1], "Should jump to {userName} expression (L56)")

  -- Jump to <Footer /> (line 57)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(57, pos[1], "Should jump to Footer component (L57)")
end)

test("JSX conditionals: complex nested conditionals", function()
  vim.cmd("edit tests/fixtures/jsx_conditionals.tsx")

  -- Start at ComponentA in ComplexConditionals (line 33)
  vim.api.nvim_win_set_cursor(0, { 33, 8 })

  -- Jump through complex conditionals
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(34, pos[1], "Should jump to optional chaining conditional (L34)")

  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(35, pos[1], "Should jump to range conditional (L35)")

  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(36, pos[1], "Should jump to ternary with parentheses (L36)")

  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(41, pos[1], "Should jump to ComponentB (L41)")
end)

-- Single statement inside if block
test("Single statement in if: no-op when navigating from inside", function()
  vim.cmd("edit tests/fixtures/single_statement_in_if.ts")

  -- Start at return statement inside if block (line 9)
  vim.api.nvim_win_set_cursor(0, { 9, 4 })
  local initial_pos = vim.api.nvim_win_get_cursor(0)

  -- Try to jump backward (should be no-op - no siblings inside the if block)
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(initial_pos[1], pos[1], "Should not jump to statement before if when inside if block with single statement")

  -- Try to jump forward (should also be no-op)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(initial_pos[1], pos[1], "Should not jump when inside if block with single statement")
end)

test("Single statement in if: complex case from real code", function()
  vim.cmd("edit tests/fixtures/single_statement_in_if.ts")

  -- Start at return statement in complex case (line 19)
  vim.api.nvim_win_set_cursor(0, { 19, 4 })
  local initial_pos = vim.api.nvim_win_get_cursor(0)

  -- Try to jump backward (should be no-op)
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(initial_pos[1], pos[1], "Should not jump to const before if when inside if block")
end)

-- Switch case navigation
test("Switch cases: forward navigation through cases", function()
  vim.cmd("edit tests/fixtures/switch_cases.ts")
  
  -- Start at case "a" (line 8)
  vim.api.nvim_win_set_cursor(0, {8, 4})
  
  -- Jump to case "b" (line 10)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(10, pos[1], "Should jump from case 'a' (L8) to case 'b' (L10)")
  
  -- Jump to case "c" (line 12)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(12, pos[1], "Should jump from case 'b' (L10) to case 'c' (L12)")
  
  -- Jump to default (line 14)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(14, pos[1], "Should jump from case 'c' (L12) to default (L14)")
end)

test("Switch cases: backward navigation through cases", function()
  vim.cmd("edit tests/fixtures/switch_cases.ts")
  
  -- Start at default (line 14)
  vim.api.nvim_win_set_cursor(0, {14, 4})
  
  -- Jump backward to case "c" (line 12)
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(12, pos[1], "Should jump from default (L14) to case 'c' (L12)")
  
  -- Jump backward to case "b" (line 10)
  sibling_jump.jump_to_sibling({ forward = false })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(10, pos[1], "Should jump from case 'c' (L12) to case 'b' (L10)")
  
  -- Jump backward to case "a" (line 8)
  sibling_jump.jump_to_sibling({ forward = false })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(8, pos[1], "Should jump from case 'b' (L10) to case 'a' (L8)")
end)

test("Switch cases: no-op at first case", function()
  vim.cmd("edit tests/fixtures/switch_cases.ts")
  
  -- Start at first case "a" (line 8)
  vim.api.nvim_win_set_cursor(0, {8, 4})
  local initial_pos = vim.api.nvim_win_get_cursor(0)
  
  -- Try to jump backward (should be no-op)
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(initial_pos[1], pos[1], "Should not move from first case")
end)

test("Switch cases: no-op at last case", function()
  vim.cmd("edit tests/fixtures/switch_cases.ts")
  
  -- Start at default (last case, line 14)
  vim.api.nvim_win_set_cursor(0, {14, 4})
  local initial_pos = vim.api.nvim_win_get_cursor(0)
  
  -- Try to jump forward (should be no-op)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(initial_pos[1], pos[1], "Should not move from last case (default)")
end)

test("Switch cases: navigate from parent context lands on switch", function()
  vim.cmd("edit tests/fixtures/switch_cases.ts")
  
  -- Start at statement before switch (line 5)
  vim.api.nvim_win_set_cursor(0, {5, 2})
  
  -- Jump forward to switch statement (line 7)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should jump to switch statement (L7)")
  
  -- Jump forward to statement after switch (line 18)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(18, pos[1], "Should jump from switch (L7) to statement after (L18)")
end)

test("Switch cases: backward from statement after switch jumps to last case", function()
  vim.cmd("edit tests/fixtures/switch_cases.ts")
  
  -- Start at statement after switch (line 18)
  vim.api.nvim_win_set_cursor(0, {18, 2})
  
  -- Jump backward should land on default case (line 14), not switch keyword (line 7)
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(14, pos[1], "Should jump from statement after (L18) to default case (L14), not switch keyword")
end)

test("Switch cases: empty cases (fallthrough)", function()
  vim.cmd("edit tests/fixtures/switch_cases.ts")
  
  -- Start at case "a" (line 26, empty case)
  vim.api.nvim_win_set_cursor(0, {26, 4})
  
  -- Jump to case "b" (line 27, also empty)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(27, pos[1], "Should jump from empty case 'a' (L26) to case 'b' (L27)")
  
  -- Jump to case "c" with body (line 29)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(29, pos[1], "Should jump from case 'b' (L27) to case 'c' (L29)")
end)

test("Switch cases: block-scoped cases", function()
  vim.cmd("edit tests/fixtures/switch_cases.ts")
  
  -- Start at case "a" with block scope (line 43)
  vim.api.nvim_win_set_cursor(0, {43, 4})
  
  -- Jump to case "b" (line 47)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(47, pos[1], "Should jump from case 'a' (L43) to case 'b' (L47)")
  
  -- Jump to default (line 51)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(51, pos[1], "Should jump from case 'b' (L47) to default (L51)")
end)

test("Switch cases: navigate statements within case", function()
  vim.cmd("edit tests/fixtures/switch_cases.ts")
  
  -- Start at first statement inside case "a" (line 65)
  vim.api.nvim_win_set_cursor(0, {65, 6})
  
  -- Jump to second statement in same case (line 66)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(66, pos[1], "Should jump between statements within case 'a'")
  
  -- Jump to return statement (line 67)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(67, pos[1], "Should jump to return within same case")
end)

test("Switch cases: single case no-op", function()
  vim.cmd("edit tests/fixtures/switch_cases.ts")
  
  -- Start at default in single case switch (line 106)
  vim.api.nvim_win_set_cursor(0, {106, 4})
  local initial_pos = vim.api.nvim_win_get_cursor(0)
  
  -- Try to jump (should be no-op since only one case)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(initial_pos[1], pos[1], "Should not move when only one case")
  
  sibling_jump.jump_to_sibling({ forward = false })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(initial_pos[1], pos[1], "Should not move when only one case")
end)

test("Switch cases: nested switch inner navigation", function()
  vim.cmd("edit tests/fixtures/switch_cases.ts")
  
  -- Start at inner switch case "x" (line 85)
  vim.api.nvim_win_set_cursor(0, {85, 8})
  
  -- Jump to inner case "y" (line 87)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(87, pos[1], "Should navigate within inner switch cases")
  
  -- Jump to inner default (line 89)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(89, pos[1], "Should jump to inner default")
end)

test("Switch cases: navigate object properties in return statement", function()
  vim.cmd("edit tests/fixtures/switch_cases.ts")
  
  -- Start at title property in case "signup" (line 134)
  vim.api.nvim_win_set_cursor(0, {134, 8})
  
  -- Jump to subtitle property (line 135)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(135, pos[1], "Should jump between object properties, not to next case")
  
  -- Jump to showIcon (line 136)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(136, pos[1], "Should continue navigating object properties")
end)

test("Switch cases: navigate backward in object literal without escaping to prev case", function()
  vim.cmd("edit tests/fixtures/switch_cases.ts")
  
  -- Start at subtitle property in case "login" (line 146)
  vim.api.nvim_win_set_cursor(0, {146, 8})
  
  -- Jump backward to title (line 145)
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(145, pos[1], "Should jump backward between properties, not to previous case")
end)

test("Switch cases: navigate nested object in return statement", function()
  vim.cmd("edit tests/fixtures/switch_cases.ts")
  
  -- Start at primaryButton property (line 135)
  vim.api.nvim_win_set_cursor(0, {135, 8})
  
  -- Jump inside primaryButton object to text property (line 136)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(136, pos[1], "Should navigate into nested object properties")
  
  -- Jump to action property (line 137)
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(137, pos[1], "Should navigate between nested object properties")
end)

test("Switch cases: return statement at case level should not escape to previous case", function()
  vim.cmd("edit tests/fixtures/switch_cases.ts")
  
  -- Start at return statement in case "second" (line 176)
  vim.api.nvim_win_set_cursor(0, {176, 6})
  local initial_pos = vim.api.nvim_win_get_cursor(0)
  
  -- Try to jump backward (should be no-op since return is only statement in case)
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(initial_pos[1], pos[1], "Should not escape to previous case from single return statement")
end)

test("Switch cases: return statement should not jump forward to next case", function()
  vim.cmd("edit tests/fixtures/switch_cases.ts")
  
  -- Start at return statement in case "second" (line 176)
  vim.api.nvim_win_set_cursor(0, {176, 6})
  local initial_pos = vim.api.nvim_win_get_cursor(0)
  
  -- Try to jump forward (should be no-op since return is only statement in case)
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(initial_pos[1], pos[1], "Should not jump to next case from single return statement")
end)

-- ============================================================================
-- LUA TESTS (Critical Coverage)
-- ============================================================================

test("Lua statements: forward navigation", function()
  vim.cmd("edit tests/fixtures/lua_statements.lua")
  vim.api.nvim_win_set_cursor(0, { 5, 2 })

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should jump from local a (L5) to local b (L6)")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should jump from local b (L6) to local c (L7)")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(9, pos[1], "Should jump from local c (L7) to if statement (L9)")
end)

test("Lua statements: backward navigation", function()
  vim.cmd("edit tests/fixtures/lua_statements.lua")
  vim.api.nvim_win_set_cursor(0, { 6, 2 })

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should jump from local b (L6) to local a (L5)")
end)

test("Lua function: statements inside if block", function()
  vim.cmd("edit tests/fixtures/lua_function.lua")
  vim.api.nvim_win_set_cursor(0, { 15, 4 })

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(22, pos[1], "Should jump from create_autocmd (L15) to current_ft declaration (L22)")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(23, pos[1], "Should jump from current_ft (L22) to if statement (L23)")
end)

test("Lua function: statements inside else block", function()
  vim.cmd("edit tests/fixtures/lua_function.lua")
  vim.api.nvim_win_set_cursor(0, { 27, 4 })

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(31, pos[1], "Should jump between vim.keymap.set calls (L27→L31)")
end)

test("Lua labels: backward navigation from label", function()
  vim.cmd("edit tests/fixtures/lua_statements.lua")
  vim.api.nvim_win_set_cursor(0, { 27, 4 }) -- On ::continue:: label

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(26, pos[1], "Should jump from label (L27) to print statement (L26)")
end)

test("Lua labels: forward navigation to label", function()
  vim.cmd("edit tests/fixtures/lua_statements.lua")
  vim.api.nvim_win_set_cursor(0, { 26, 4 }) -- On print(x)

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(27, pos[1], "Should jump from print (L26) to label (L27)")
end)

test("Lua if-else-elseif: forward navigation through chain to statements", function()
  vim.cmd("edit tests/fixtures/lua_if_else.lua")
  vim.api.nvim_win_set_cursor(0, { 7, 2 }) -- On 'if' at line 7

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(9, pos[1], "Should jump from if (L7) to first elseif (L9)")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(11, pos[1], "Should jump from first elseif (L9) to second elseif (L11)")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(13, pos[1], "Should jump from second elseif (L11) to else (L13)")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(17, pos[1], "Should jump from else (L13) to return statement (L17)")
end)

test("Lua if-else-elseif: backward from statement after chain jumps to last else", function()
  vim.cmd("edit tests/fixtures/lua_if_else.lua")
  vim.api.nvim_win_set_cursor(0, { 17, 2 }) -- On 'return x' at line 17

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(13, pos[1], "Should jump from return (L17) to else (L13), not to if")
end)

test("Lua if-else-elseif: backward from else continues to previous elseif", function()
  vim.cmd("edit tests/fixtures/lua_if_else.lua")
  vim.api.nvim_win_set_cursor(0, { 17, 2 }) -- On 'return x' at line 17

  -- First jump to else
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(13, pos[1], "Should jump from return (L17) to else (L13)")
  
  -- Second jump should go to second elseif (L11), not to end (L15)
  sibling_jump.jump_to_sibling({ forward = false })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(11, pos[1], "Should jump from else (L13) to second elseif (L11), not to end (L15)")
  
  -- Third jump should go to first elseif
  sibling_jump.jump_to_sibling({ forward = false })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(9, pos[1], "Should jump from second elseif (L11) to first elseif (L9)")
  
  -- Fourth jump should go to if
  sibling_jump.jump_to_sibling({ forward = false })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should jump from first elseif (L9) to if (L7)")
end)

test("Lua nested if-elseif: navigate inner chain not outer", function()
  vim.cmd("edit lua/sibling_jump/node_finder.lua")
  vim.api.nvim_win_set_cursor(0, { 188, 8 }) -- On nested 'if parent and parent:type() == "pair"'

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(207, pos[1], "Should jump from nested if (L188) to its elseif (L207), not outer if's siblings")
end)

-- ============================================================================
-- JAVA TESTS (Basic Support)
-- ============================================================================

test("Java: local variable declarations", function()
  vim.cmd("edit tests/fixtures/Test.java")
  vim.api.nvim_win_set_cursor(0, { 7, 8 })  -- at int a

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(8, pos[1], "Should jump from int a (L7) to int b (L8)")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(9, pos[1], "Should jump from int b (L8) to int c (L9)")
end)

-- ============================================================================
-- C TESTS (Basic Support)
-- ============================================================================

test("C: declarations and statements", function()
  vim.cmd("edit tests/fixtures/test.c")
  vim.api.nvim_win_set_cursor(0, { 2, 4 })  -- at int a

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(3, pos[1], "Should jump from int a (L2) to int b (L3)")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(4, pos[1], "Should jump from int b (L3) to int c (L4)")
end)

-- ============================================================================
-- C# TESTS (Basic Support)
-- ============================================================================

test("C#: local declarations", function()
  vim.cmd("edit tests/fixtures/test.cs")
  vim.api.nvim_win_set_cursor(0, { 7, 4 })  -- at start of line

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(8, pos[1], "Should jump from int a (L7) to int b (L8)")
end)

-- ============================================================================
-- COMMENT NAVIGATION TESTS
-- ============================================================================

test("Comment escape: forward from top comment", function()
  vim.cmd("edit tests/fixtures/lua_comments.lua")
  vim.api.nvim_win_set_cursor(0, { 1, 2 })  -- on line 1 comment

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should jump from comment (L1) to local M = {} (L5)")
end)

test("Comment escape: forward from middle comment", function()
  vim.cmd("edit tests/fixtures/lua_comments.lua")
  vim.api.nvim_win_set_cursor(0, { 7, 2 })  -- on line 7 comment

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(9, pos[1], "Should jump from comment (L7) to function (L9)")
end)

test("Comment escape: backward from middle comment", function()
  vim.cmd("edit tests/fixtures/lua_comments.lua")
  vim.api.nvim_win_set_cursor(0, { 7, 2 })  -- on line 7 comment

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should jump from comment (L7) back to local M = {} (L5)")
end)

test("Comment escape: forward from comment inside function", function()
  vim.cmd("edit tests/fixtures/lua_comments.lua")
  vim.api.nvim_win_set_cursor(0, { 12, 2 })  -- on line 12 comment inside function

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(14, pos[1], "Should jump from comment (L12) to local b (L14)")
end)

test("Comment escape: backward from comment inside function", function()
  vim.cmd("edit tests/fixtures/lua_comments.lua")
  vim.api.nvim_win_set_cursor(0, { 12, 2 })  -- on line 12 comment inside function

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(10, pos[1], "Should jump from comment (L12) back to local a (L10)")
end)

test("Comment escape: forward from empty line", function()
  vim.cmd("edit tests/fixtures/lua_comments.lua")
  vim.api.nvim_win_set_cursor(0, { 11, 0 })  -- on line 11 empty line

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(14, pos[1], "Should jump from empty line (L11) to local b (L14), skipping comment")
  
  -- Jump again to next statement
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(15, pos[1], "Should jump from local b (L14) to local c (L15)")
end)

test("Comment escape: backward from empty line", function()
  vim.cmd("edit tests/fixtures/lua_comments.lua")
  vim.api.nvim_win_set_cursor(0, { 11, 0 })  -- on line 11 empty line

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(10, pos[1], "Should jump from empty line (L11) back to local a (L10)")
end)

-- ============================================================================
-- LEADING WHITESPACE NAVIGATION TESTS
-- ============================================================================

test("Leading whitespace: forward navigation", function()
  vim.cmd("edit tests/fixtures/leading_whitespace.lua")
  vim.api.nvim_win_set_cursor(0, { 5, 0 })  -- Line 5, col 0 (before local a)

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should jump from leading whitespace at local a (L5) to local b (L6)")
end)

test("Leading whitespace: backward navigation", function()
  vim.cmd("edit tests/fixtures/leading_whitespace.lua")
  vim.api.nvim_win_set_cursor(0, { 7, 0 })  -- Line 7, col 0 (before local c)

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should jump from leading whitespace at local c (L7) to local b (L6)")
end)

test("Leading whitespace: navigates within correct scope", function()
  vim.cmd("edit tests/fixtures/leading_whitespace.lua")
  vim.api.nvim_win_set_cursor(0, { 5, 0 })  -- Line 5, col 0 (before local a)

  -- Should navigate within the function, not escape to module level
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should stay within function scope")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should continue within function scope")
end)

test("Leading whitespace: TypeScript navigation", function()
  vim.cmd("edit tests/fixtures/statements.ts")
  vim.api.nvim_win_set_cursor(0, { 3, 0 })  -- Line 3, col 0 (before const a)

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(4, pos[1], "Should jump from leading whitespace in TypeScript")
end)

-- ============================================================================
-- LUA TABLE FIELD NAVIGATION TESTS
-- ============================================================================

test("Lua tables: forward navigation between fields", function()
  vim.cmd("edit tests/fixtures/lua_tables.lua")
  vim.api.nvim_win_set_cursor(0, { 6, 2 }) -- On 'download = false'

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should jump from download (L6) to vcs (L7)")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(8, pos[1], "Should jump from vcs (L7) to highlight_mode (L8)")
end)

test("Lua tables: backward navigation between fields", function()
  vim.cmd("edit tests/fixtures/lua_tables.lua")
  vim.api.nvim_win_set_cursor(0, { 8, 2 }) -- On 'highlight_mode = "treesitter"'

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should jump from highlight_mode (L8) to vcs (L7)")
  
  sibling_jump.jump_to_sibling({ forward = false })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should jump from vcs (L7) to download (L6)")
end)

test("Lua tables: no-op at first field", function()
  vim.cmd("edit tests/fixtures/lua_tables.lua")
  vim.api.nvim_win_set_cursor(0, { 6, 2 }) -- On 'download = false' (first field)

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should not move from first field")
end)

test("Lua tables: no-op at last field", function()
  vim.cmd("edit tests/fixtures/lua_tables.lua")
  vim.api.nvim_win_set_cursor(0, { 8, 2 }) -- On 'highlight_mode' (last field in M.config)

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(8, pos[1], "Should not move from last field")
end)

test("Lua tables: nested table forward navigation", function()
  vim.cmd("edit tests/fixtures/lua_tables.lua")
  vim.api.nvim_win_set_cursor(0, { 13, 2 }) -- On 'keymaps = {...}' nested field

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(18, pos[1], "Should jump from keymaps (L13) to tree (L18)")
end)

test("Lua tables: nested table backward navigation", function()
  vim.cmd("edit tests/fixtures/lua_tables.lua")
  vim.api.nvim_win_set_cursor(0, { 18, 2 }) -- On 'tree = {...}' nested field

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(13, pos[1], "Should jump from tree (L18) to keymaps (L13)")
end)

test("Lua tables: inner nested table navigation", function()
  vim.cmd("edit tests/fixtures/lua_tables.lua")
  vim.api.nvim_win_set_cursor(0, { 14, 4 }) -- On 'next_file = "]f"' inside keymaps

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(15, pos[1], "Should jump from next_file (L14) to prev_file (L15)")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(16, pos[1], "Should jump from prev_file (L15) to close (L16)")
end)

test("Lua tables: deeply nested table navigation", function()
  vim.cmd("edit tests/fixtures/lua_tables.lua")
  vim.api.nvim_win_set_cursor(0, { 20, 4 }) -- On 'icons = {...}' inside tree

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(19, pos[1], "Should jump from icons (L20) to width (L19)")
end)

test("Lua tables: navigation within deeply nested table", function()
  vim.cmd("edit tests/fixtures/lua_tables.lua")
  vim.api.nvim_win_set_cursor(0, { 21, 6 }) -- On 'enable = true' inside icons

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(22, pos[1], "Should jump from enable (L21) to dir_open (L22)")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(23, pos[1], "Should jump from dir_open (L22) to dir_closed (L23)")
end)

test("Lua tables: array-style entries forward navigation", function()
  vim.cmd("edit tests/fixtures/lua_tables.lua")
  vim.api.nvim_win_set_cursor(0, { 30, 2 }) -- On '"red"'

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(31, pos[1], "Should jump from 'red' (L30) to 'green' (L31)")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(32, pos[1], "Should jump from 'green' (L31) to 'blue' (L32)")
end)

test("Lua tables: array-style entries backward navigation", function()
  vim.cmd("edit tests/fixtures/lua_tables.lua")
  vim.api.nvim_win_set_cursor(0, { 33, 2 }) -- On '"yellow"' (last)

  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(32, pos[1], "Should jump from 'yellow' (L33) to 'blue' (L32)")
end)

test("Lua tables: mixed table navigation (keyed and array)", function()
  vim.cmd("edit tests/fixtures/lua_tables.lua")
  vim.api.nvim_win_set_cursor(0, { 38, 2 }) -- On 'name = "test"'

  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(39, pos[1], "Should jump from name (L38) to 'first' (L39)")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(40, pos[1], "Should jump from 'first' (L39) to enabled (L40)")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(41, pos[1], "Should jump from enabled (L40) to 'second' (L41)")
end)

-- Run all tests
run_tests()
