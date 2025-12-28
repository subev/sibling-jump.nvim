-- plugin/sibling-jump.lua
-- This file is automatically sourced by Neovim when the plugin loads

-- Prevent loading twice
if vim.g.loaded_sibling_jump then
  return
end
vim.g.loaded_sibling_jump = 1

-- The actual plugin logic is in lua/sibling_jump/init.lua
-- Users can call require("sibling_jump").setup() to configure keybindings
