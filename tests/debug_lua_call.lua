-- Debug script for Lua function call detection
vim.cmd('edit tests/fixtures/lua_function_calls.lua')

local bufnr = vim.api.nvim_get_current_buf()
print('Buffer:', bufnr)
print('Filetype:', vim.bo[bufnr].filetype)

local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
print('Lang:', lang)

if lang then
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  print('Parser ok:', ok)
  if ok and parser then
    print('Parser exists:', parser ~= nil)
    local trees = parser:parse()
    print('Trees:', #trees)
    if trees[1] then
      local root = trees[1]:root()
      print('Root:', root:type())
    end
  end
end

vim.api.nvim_win_set_cursor(0, {6, 2})  -- On 'print'

-- Try with block_loop's method
local sibling_jump = require('sibling_jump')
local block_loop = sibling_jump.block_loop()

local cursor = vim.api.nvim_win_get_cursor(0)
local row = cursor[1] - 1
local col = cursor[2]

local node = block_loop.get_node_at_cursor(bufnr, row, col)
print('\nNode at cursor (row=' .. row .. ', col=' .. col .. '):', node and node:type() or 'NIL')

if node then
  local start_row, start_col = node:start()
  print('  Position: row=' .. start_row .. ', col=' .. start_col)
  local parent = node:parent()
  print('  Parent:', parent and parent:type() or 'nil')
end

-- Try to detect
if node then
  local call_expressions = require('sibling_jump.block_loop.call_expressions')
  local detected, context = call_expressions.detect(node, cursor)
  print('\nDetected:', detected)
  if context then
    print('Context positions:')
    for i, pos in ipairs(context.positions) do
      print('  ' .. i .. ': row=' .. pos.row .. ', col=' .. pos.col)
    end
  end
end

-- Now jump
print('\nJumping...')
block_loop.jump_to_boundary({ mode = 'normal' })
local pos = vim.api.nvim_win_get_cursor(0)
print('After jump: row=' .. pos[1] .. ', col=' .. pos[2])

vim.cmd('quitall!')
