-- Minimal init file for running tests
-- This sets up the environment needed to test sibling_jump.lua

-- Get the absolute path to the plugin root directory
local plugin_root = vim.fn.fnamemodify(vim.fn.expand("<sfile>:p"), ":h:h")

-- Critical: Set runtimepath FIRST, before anything else
local treesitter_path = vim.fn.stdpath("data") .. "/lazy/nvim-treesitter"
vim.opt.rtp:prepend(treesitter_path)
vim.opt.rtp:prepend(plugin_root)

-- Ensure lua module path includes plugin directory
package.path = package.path .. ";" .. plugin_root .. "/lua/?.lua"
package.path = package.path .. ";" .. plugin_root .. "/lua/?/init.lua"

-- Enable filetype detection
vim.cmd("filetype plugin indent on")

-- Set some basic options for tests
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
