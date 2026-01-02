-- Test fixture for Lua function call block-loop navigation
local M = {}

-- Simple function call
function M.simple_call()
  print("hello world")
  return true
end

-- Dot method call (single level)
function M.dot_call_single()
  local buf = vim.fn.expand("%")
  return buf
end

-- Dot method call (nested chain)
function M.dot_call_nested()
  local buf = vim.api.nvim_get_current_buf()
  return buf
end

-- Colon method call
function M.colon_call()
  local t = {1, 2, 3}
  table.insert(t, 4)
  return t
end

-- Multi-line function call (the issue case!)
function M.multiline_call()
  vim.keymap.set("n", "<leader>x", function()
    print("pressed")
  end, { desc = "Test keymap" })
  
  return true
end

-- Nested method chain with arguments
function M.nested_with_args()
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  return true
end

-- Deeply nested chain
function M.deep_nested()
  local result = string.gsub(vim.api.nvim_buf_get_name(0), "/", "\\")
  return result
end

-- Method call with table literal argument
function M.with_table_arg()
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*",
    callback = function() end,
  })
end

return M

-- Test table for block-loop
local test_config = {
  option1 = true,
  option2 = "value",
}

