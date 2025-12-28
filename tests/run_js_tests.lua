-- JavaScript-specific test runner for sibling_jump
-- Tests universal features that work in both JS and TS
-- Run with: nvim --headless -c "luafile tests/run_js_tests.lua"

local sibling_jump = require('sibling_jump')

local passed = 0
local failed = 0
local tests = {}

local function test(name, fn)
  table.insert(tests, {name = name, fn = fn})
end

local function assert_eq(expected, actual, message)
  if expected ~= actual then
    error(string.format("%s\nExpected: %s\nGot: %s", message or "Assertion failed", expected, actual))
  end
end

local function run_tests()
  print("=== Running JavaScript Compatibility Tests ===\n")
  
  for _, t in ipairs(tests) do
    io.write("Testing: " .. t.name .. " ... ")
    
    local ok, err = pcall(t.fn)
    
    if ok then
      print("✓ PASS")
      passed = passed + 1
    else
      print("✗ FAIL")
      print("  Error: " .. tostring(err))
      failed = failed + 1
    end
    
    -- Clean up between tests
    vim.cmd("bufdo! bwipeout!")
  end
  
  print(string.format("\n=== JavaScript Test Results: %d passed, %d failed ===", passed, failed))
  
  if failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("quit")
  end
end

-- ============================================================================
-- JAVASCRIPT COMPATIBILITY TESTS
-- ============================================================================

-- If-Else Chain Tests
test("JS: If-else chains forward navigation", function()
  vim.cmd("edit tests/fixtures/if_else_chains.js")
  vim.api.nvim_win_set_cursor(0, {7, 2})
  
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(9, pos[1], "Should jump from if (L7) to first else if (L9)")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(11, pos[1], "Should jump to second else if (L11)")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(13, pos[1], "Should jump to else (L13)")
end)

test("JS: If-else chains backward navigation", function()
  vim.cmd("edit tests/fixtures/if_else_chains.js")
  vim.api.nvim_win_set_cursor(0, {17, 2})
  
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(13, pos[1], "Should jump from const after to else (L13)")
  
  sibling_jump.jump_to_sibling({ forward = false })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(11, pos[1], "Should jump to second else if (L11)")
end)

test("JS: If with no else skips to next statement", function()
  vim.cmd("edit tests/fixtures/if_else_chains.js")
  vim.api.nvim_win_set_cursor(0, {37, 2})
  
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(41, pos[1], "Should jump from if to next statement")
end)

-- Method Chain Tests
test("JS: Method chains forward navigation", function()
  vim.cmd("edit tests/fixtures/method_chains.js")
  vim.api.nvim_win_set_cursor(0, {5, 3})
  
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should jump from methodA to methodB")
end)

test("JS: Method chains backward navigation", function()
  vim.cmd("edit tests/fixtures/method_chains.js")
  vim.api.nvim_win_set_cursor(0, {6, 3})
  
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should jump from methodB to methodA")
end)

-- Object Properties Tests
test("JS: Object properties forward navigation", function()
  vim.cmd("edit tests/fixtures/object_properties.js")
  vim.api.nvim_win_set_cursor(0, {12, 2})
  
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(17, pos[1], "Should jump to next property")
end)

test("JS: Object properties backward navigation", function()
  vim.cmd("edit tests/fixtures/object_properties.js")
  vim.api.nvim_win_set_cursor(0, {17, 2})
  
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(12, pos[1], "Should jump to previous property")
end)

-- Array Tests
test("JS: Array forward navigation", function()
  vim.cmd("edit tests/fixtures/arrays.js")
  vim.api.nvim_win_set_cursor(0, {4, 17})
  
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(4, pos[1], "Should stay on same line")
  assert_eq(20, pos[2], "Should jump to second element")
end)

test("JS: Array backward navigation", function()
  vim.cmd("edit tests/fixtures/arrays.js")
  vim.api.nvim_win_set_cursor(0, {4, 20})
  
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(17, pos[2], "Should jump to first element")
end)

-- Function Parameter Tests
test("JS: Function params forward navigation", function()
  vim.cmd("edit tests/fixtures/function_params.js")
  vim.api.nvim_win_set_cursor(0, {4, 13})  -- On parameter 'a'
  
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(4, pos[1], "Should stay on same line")
  assert_eq(true, pos[2] > 13, "Should move to next parameter")
end)

test("JS: Function params multi-line navigation", function()
  vim.cmd("edit tests/fixtures/function_params.js")
  vim.api.nvim_win_set_cursor(0, {17, 2})
  
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(18, pos[1], "Should jump to next line (second parameter)")
end)

-- Destructuring Tests
test("JS: Destructuring forward navigation", function()
  vim.cmd("edit tests/fixtures/destructuring.js")
  vim.api.nvim_win_set_cursor(0, {5, 4})
  
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should jump from currentTab:tab to setCurrentTab")
end)

test("JS: Destructuring backward navigation", function()
  vim.cmd("edit tests/fixtures/destructuring.js")
  vim.api.nvim_win_set_cursor(0, {6, 4})
  
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should jump from setCurrentTab to currentTab:tab")
end)

-- Statement Tests  
test("JS: Basic statements forward navigation", function()
  vim.cmd("edit tests/fixtures/statements.js")
  vim.api.nvim_win_set_cursor(0, {3, 2})
  
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(4, pos[1], "Should jump from const a to const b")
  
  sibling_jump.jump_to_sibling({ forward = true })
  pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should jump from const b to const c")
end)

test("JS: Basic statements backward navigation", function()
  vim.cmd("edit tests/fixtures/statements.js")
  vim.api.nvim_win_set_cursor(0, {4, 2})
  
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(3, pos[1], "Should jump from const b to const a")
end)

-- JSX Tests
test("JS: JSX elements forward navigation", function()
  vim.cmd("edit tests/fixtures/jsx_elements.jsx")
  vim.api.nvim_win_set_cursor(0, {5, 8})
  
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(9, pos[1], "Should jump from HeaderContent to Header")
end)

test("JS: JSX elements backward navigation", function()
  vim.cmd("edit tests/fixtures/jsx_elements.jsx")
  vim.api.nvim_win_set_cursor(0, {9, 8})
  
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(5, pos[1], "Should jump from Header to HeaderContent")
end)

test("JS: JSX attributes forward navigation", function()
  vim.cmd("edit tests/fixtures/jsx_attributes.jsx")
  vim.api.nvim_win_set_cursor(0, {5, 6})
  
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should jump from className to style")
end)

test("JS: JSX attributes backward navigation", function()
  vim.cmd("edit tests/fixtures/jsx_attributes.jsx")
  vim.api.nvim_win_set_cursor(0, {7, 6})
  
  sibling_jump.jump_to_sibling({ forward = false })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(6, pos[1], "Should jump from onClick to style")
end)

-- Nested Context Tests
test("JS: Nested contexts - statements inside arrow function", function()
  vim.cmd("edit tests/fixtures/nested_contexts.js")
  vim.api.nvim_win_set_cursor(0, {6, 4})
  
  sibling_jump.jump_to_sibling({ forward = true })
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should jump to if statement within arrow function")
end)

-- Run all tests
run_tests()
