-- Utility functions for sibling-jump.nvim
-- Pure functions with no side effects

local config = require("sibling_jump.config")

local M = {}

-- Smallest tree-sitter node at a 0-indexed position, or nil when the buffer has no parser
function M.get_node_at(bufnr, row, col)
  local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
  if not lang then
    return nil
  end
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok or not parser then
    return nil
  end
  local tree = parser:parse()[1]
  if not tree then
    return nil
  end
  -- One-character range like vim.treesitter.get_node(); a zero-width range misses tokens on some grammars (Swift)
  return tree:root():descendant_for_range(row, col, row, col + 1)
end

-- Check if a node is a comment node
function M.is_comment_node(node)
  if not node then
    return false
  end
  local node_type = node:type()
  return node_type:match("comment") ~= nil or config.COMMENT_DELIMITERS[node_type]
end

-- Check if node should be skipped (comments, empty nodes, punctuation)
function M.is_skippable_node(node)
  if not node then
    return true
  end

  local node_type = node:type()

  -- Skip comment nodes
  if node_type:match("comment") then
    return true
  end

  -- Skip comment delimiters (language-agnostic)
  if config.COMMENT_DELIMITERS[node_type] then
    return true
  end

  -- Skip punctuation and delimiters
  if config.PUNCTUATION[node_type] then
    return true
  end

  -- Skip JSX opening/closing tags (they're just delimiters)
  if node_type == "jsx_opening_element" or node_type == "jsx_closing_element" then
    return true
  end

  -- Skip switch case keywords (they're delimiters, not navigable content)
  if node_type == "case" or node_type == "default" then
    return true
  end

  -- Skip empty nodes (nodes with no content)
  local start_row, start_col, end_row, end_col = node:range()
  if start_row == end_row and start_col == end_col then
    return true
  end

  return false
end

-- Column of the first non-blank character on a 0-indexed row (-1 for a blank line)
function M.line_start_col(bufnr, row)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  return vim.fn.match(line, [[\S]])
end

-- Does the node begin at its line's first non-blank column?
function M.is_line_leading(node)
  local row, col = node:start()
  return M.line_start_col(0, row) == col
end

-- A named node that begins its line: the shape every statement, member and clause has,
-- without knowing its name
function M.starts_line(node)
  return node ~= nil and node:named() and M.is_line_leading(node)
end

-- Find the index of a node in a list
function M.find_node_index(node, node_list)
  local node_start_row, node_start_col = node:start()

  for i, n in ipairs(node_list) do
    local n_start_row, n_start_col = n:start()
    if n_start_row == node_start_row and n_start_col == node_start_col then
      return i
    end
  end

  return nil
end

return M
