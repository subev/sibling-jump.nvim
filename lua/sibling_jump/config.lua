-- Configuration module for sibling-jump.nvim
-- Node types that are never navigated to (comments, punctuation)

local M = {}

-- Comment delimiters for various languages
M.COMMENT_DELIMITERS = {
  ["--"] = true,        -- Lua
  ["//"] = true,        -- C/C++/Java/C#/JS/TS
  ["/*"] = true,        -- C-style block comment start
  ["*/"] = true,        -- C-style block comment end
  ["#"] = true,         -- Python/Shell
  ["<!--"] = true,      -- HTML/XML
  ["-->"] = true,       -- HTML/XML
  ["comment_content"] = true,  -- Generic comment content node
}

-- Punctuation and delimiters to skip
M.PUNCTUATION = {
  ["{"] = true,
  ["}"] = true,
  ["("] = true,
  [")"] = true,
  ["["] = true,
  ["]"] = true,
  [","] = true,
  [";"] = true,
  [":"] = true,
  ["<"] = true,
  [">"] = true,
  ["</"] = true,
  ["/>"] = true,
}

return M
