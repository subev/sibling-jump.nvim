-- Navigation handlers for different contexts
-- Reduces cyclomatic complexity by extracting special case logic

local M = {}

-- Get tree-sitter node at cursor
function M.get_node_at_cursor(bufnr, row, col)
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
  
  local root = tree:root()
  return root:descendant_for_range(row, col, row, col)
end

-- Handle whitespace navigation
function M.handle_whitespace(current_node, forward, positioning)
  if type(current_node) ~= "table" or not current_node._on_whitespace then
    return nil -- Not whitespace, continue to next handler
  end
  
  local target_node = forward and current_node.closest_after or current_node.closest_before
  if not target_node then
    return "no_op" -- Whitespace but no target, stop here
  end
  
  local target_row, target_col = positioning.get_target_position(target_node)
  return { row = target_row, col = target_col, stop = true }
end

-- Handle comment navigation
function M.handle_comment(current_node, forward, positioning)
  if type(current_node) ~= "table" or not current_node._on_comment then
    return nil -- Not comment, continue to next handler
  end
  
  local target_node = forward and current_node.closest_after or current_node.closest_before
  if not target_node then
    return "no_op" -- Comment but no target, stop here
  end
  
  local target_row, target_col = positioning.get_target_position(target_node)
  return { row = target_row, col = target_col, stop = true }
end

-- Handle entry point adjustment for compound statements
function M.adjust_entry_point(target_node, forward, node, if_else_chains, switch_cases)
  if forward then
    return target_node, nil, nil -- No adjustment for forward navigation
  end
  
  local node_type = target_node:type()
  
  if node_type == "if_statement" then
    local is_inside = false
    local check = node
    while check do
      if check == target_node then
        is_inside = true
        break
      end
      check = check:parent()
    end
    
    if not is_inside then
      local entry_node, entry_row, entry_col = if_else_chains.get_entry_point(target_node, forward)
      if entry_node ~= target_node then
        return entry_node, entry_row, entry_col
      end
    end
  elseif node_type == "switch_statement" then
    local is_inside = false
    local check = node
    while check do
      if check == target_node then
        is_inside = true
        break
      end
      check = check:parent()
    end
    
    if not is_inside then
      local entry_node, entry_row, entry_col = switch_cases.get_entry_point(target_node, forward)
      if entry_node ~= target_node then
        return entry_node, entry_row, entry_col
      end
    end
  end
  
  return target_node, nil, nil
end

return M
