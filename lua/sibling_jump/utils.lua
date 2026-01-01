-- Utility functions for sibling-jump.nvim
-- Pure functions with no side effects

local config = require("sibling_jump.config")

local M = {}

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

-- Check if a node type is a "meaningful unit" we want to jump between
function M.is_meaningful_node(node)
  if not node then
    return false
  end

  local node_type = node:type()

  -- Special case: identifier is meaningful in some contexts but not others
  if node_type == "identifier" then
    local parent = node:parent()
    if not parent then
      return false
    end

    -- identifier is meaningful in array_pattern (tuple destructuring)
    if parent:type() == "array_pattern" then
      return true
    end

    -- identifier is NOT meaningful as the object in member_expression
    if parent:type() == "member_expression" then
      return false
    end

    -- identifier is NOT meaningful in other contexts
    return false
  end

  -- Special case: type_identifier is meaningful in some contexts but not others
  if node_type == "type_identifier" then
    local parent = node:parent()
    if not parent then
      return false
    end

    -- type_identifier is NOT meaningful when it's a member of a union_type
    -- (we want to navigate between union members, not individual type_identifiers)
    if parent:type() == "union_type" then
      return false
    end

    -- type_identifier IS meaningful when it's the name of a type declaration
    -- This is handled by the special check in get_node_at_cursor

    -- type_identifier is meaningful in other contexts (e.g., as a type annotation)
    return true
  end

  -- Check if node type is in the meaningful types list
  return config.is_meaningful_type(node_type)
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

-- Recursively collect all union type members from a nested union_type structure
function M.collect_union_members(union_node, members)
  members = members or {}

  for child in union_node:iter_children() do
    if child:type() == "union_type" then
      -- Recursively collect from nested union
      M.collect_union_members(child, members)
    elseif child:type() == "type_identifier" or child:type() == "literal_type" or child:type() == "object_type" then
      -- This is an actual union member
      table.insert(members, child)
    end
    -- Skip | operators and other punctuation
  end

  return members
end

return M
