-- Minimal init file for running tests
-- This sets up the environment needed to test statement_jump.lua

-- Critical: Set runtimepath FIRST, before anything else
local treesitter_path = "/Users/petur/.local/share/nvim/lazy/nvim-treesitter"
vim.opt.rtp:prepend(treesitter_path)
vim.opt.rtp:prepend("/Users/petur/dotfiles")
vim.opt.rtp:append("/Users/petur/.local/share/nvim/lazy/plenary.nvim")

-- Ensure lua module path includes dotfiles
package.path = package.path .. ";/Users/petur/dotfiles/lua/?.lua"

-- Enable filetype detection
vim.cmd('filetype plugin indent on')

-- Set some basic options for tests
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
