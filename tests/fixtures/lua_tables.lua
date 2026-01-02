-- Test fixture for Lua table field navigation
local M = {}

-- Simple table with key-value fields
M.config = {
  download = false,
  vcs = "jj",
  highlight_mode = "treesitter",
}

-- Nested table structure
M.settings = {
  keymaps = {
    next_file = "]f",
    prev_file = "[f",
    close = "q",
  },
  tree = {
    width = 40,
    icons = {
      enable = true,
      dir_open = "",
      dir_closed = "",
    },
  },
}

-- Array-style table entries
M.colors = {
  "red",
  "green",
  "blue",
  "yellow",
}

-- Mixed table (both keyed and array entries)
M.mixed = {
  name = "test",
  "first",
  enabled = true,
  "second",
}

return M
