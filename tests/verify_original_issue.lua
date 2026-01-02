-- Verify the original issue is fixed
-- Original issue: From 'vim' in vim.keymap.set(...) at line 191,
-- pressing block-loop should jump to closing ')' at line 193

vim.cmd('edit lua/sibling_jump/init.lua')
vim.api.nvim_win_set_cursor(0, {191, 4})  -- On 'vim' in vim.keymap.set

print('Testing original issue:')
print('File: lua/sibling_jump/init.lua')
print('Starting position: line 191, col 4 (on "vim")')

local block_loop = require('sibling_jump').block_loop()

-- Jump to closing paren
block_loop.jump_to_boundary({ mode = 'normal' })
local pos = vim.api.nvim_win_get_cursor(0)
print('\nAfter first jump:')
print('  Line: ' .. pos[1] .. ' (expected: 193)')
print('  Col: ' .. pos[2] .. ' (expected: column of closing paren)')

local success1 = pos[1] == 193
if success1 then
  print('  ✓ Jumped to line 193')
else
  print('  ✗ Failed to jump to line 193')
end

-- Jump back to vim
block_loop.jump_to_boundary({ mode = 'normal' })
pos = vim.api.nvim_win_get_cursor(0)
print('\nAfter second jump (cycle back):')
print('  Line: ' .. pos[1] .. ' (expected: 191)')
print('  Col: ' .. pos[2] .. ' (expected: 2 = start of "vim")')

local success2 = pos[1] == 191 and pos[2] == 2
if success2 then
  print('  ✓ Cycled back to line 191, col 2')
else
  print('  ✗ Failed to cycle back correctly')
end

if success1 and success2 then
  print('\n✓ SUCCESS: Original issue is fixed!')
  print('Block-loop navigation correctly cycles between vim and closing )')
else
  print('\n✗ FAILURE: Navigation not working as expected')
end

vim.cmd('quitall!')
