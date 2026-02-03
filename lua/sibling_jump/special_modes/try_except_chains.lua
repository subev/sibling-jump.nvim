-- Try-except-finally chain navigation for sibling-jump.nvim
-- Handles navigation through Python's try/except/else/finally structures

local M = {}

-- Collect all except/else/finally clauses in a try statement
-- Returns: list of clause nodes (in order from first to last)
local function collect_try_clauses(try_node)
  local clauses = {}
  
  if not try_node or try_node:type() ~= "try_statement" then
    return clauses
  end
  
  for i = 0, try_node:child_count() - 1 do
    local child = try_node:child(i)
    local child_type = child:type()
    
    if child_type == "except_clause" 
       or child_type == "else_clause" 
       or child_type == "finally_clause" then
      table.insert(clauses, child)
    end
  end
  
  return clauses
end

-- Get position of keyword within a clause (except, else, finally)
-- Returns: row, col (pointing to first char of keyword)
local function get_clause_keyword_position(clause_node)
  if not clause_node then
    return nil, nil
  end
  
  local clause_type = clause_node:type()
  local valid_types = {
    ["except_clause"] = true,
    ["else_clause"] = true,
    ["finally_clause"] = true,
  }
  
  if not valid_types[clause_type] then
    return nil, nil
  end
  
  -- Find the keyword child (except, else, finally)
  for i = 0, clause_node:child_count() - 1 do
    local child = clause_node:child(i)
    local child_type = child:type()
    if child_type == "except" or child_type == "else" or child_type == "finally" then
      return child:start()
    end
  end
  
  -- Fallback to clause start position
  return clause_node:start()
end

-- Detect if we're on a try statement with except/finally clauses
-- Returns: has_clauses (boolean), try_statement_node, current_position_index
-- current_position_index: 0 = on main try, 1+ = on clause (1-based)
function M.detect(node)
  if not node then
    return false, nil, 0
  end
  
  -- Walk up to find try_statement or except/finally clause
  local current = node
  local depth = 0
  local found_try = nil
  
  while current and depth < 20 do
    local current_type = current:type()
    
    if current_type == "try_statement" then
      found_try = current
      break
    elseif current_type == "except_clause" 
           or current_type == "finally_clause"
           or (current_type == "else_clause" and current:parent() and current:parent():type() == "try_statement") then
      -- We're in a clause, get parent try_statement
      found_try = current:parent()
      break
    end
    
    -- Stop if we've gone too far up
    if current_type == "block" or current_type == "module" then
      break
    end
    
    current = current:parent()
    depth = depth + 1
  end
  
  if not found_try or found_try:type() ~= "try_statement" then
    return false, nil, 0
  end
  
  -- Collect clauses
  local clauses = collect_try_clauses(found_try)
  if #clauses == 0 then
    return false, nil, 0
  end
  
  -- Determine current position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor[1] - 1
  
  -- Check if cursor is on one of the clauses
  for i, clause in ipairs(clauses) do
    local clause_start_row = clause:start()
    local clause_end_row = select(3, clause:range())
    
    if cursor_row >= clause_start_row and cursor_row <= clause_end_row then
      return true, found_try, i
    end
  end
  
  -- Check if cursor is on the main try block
  local try_start_row = found_try:start()
  local first_clause_row = clauses[1]:start()
  
  if cursor_row >= try_start_row and cursor_row < first_clause_row then
    return true, found_try, 0
  end
  
  return false, nil, 0
end

-- Navigate forward/backward in a try-except-finally chain
-- Returns: target node, target_row, target_col, or nil
function M.navigate(try_node, current_pos, forward, get_sibling_node)
  local clauses = collect_try_clauses(try_node)
  
  if forward then
    if current_pos == 0 then
      -- On main try, jump to first clause
      if #clauses > 0 then
        local target_row, target_col = get_clause_keyword_position(clauses[1])
        if not target_row then
          target_row, target_col = clauses[1]:start()
        end
        return clauses[1], target_row, target_col
      end
    elseif current_pos < #clauses then
      -- On a clause, jump to next clause
      local next_clause = clauses[current_pos + 1]
      local target_row, target_col = get_clause_keyword_position(next_clause)
      if not target_row then
        target_row, target_col = next_clause:start()
      end
      return next_clause, target_row, target_col
    else
      -- On last clause, jump to next sibling of try_statement
      local parent = try_node:parent()
      if parent and get_sibling_node then
        local sibling = get_sibling_node(try_node, parent, true)
        if sibling then
          local target_row, target_col = sibling:start()
          return sibling, target_row, target_col
        end
      end
    end
  else
    if current_pos == 0 then
      -- On main try, jump to previous sibling
      local parent = try_node:parent()
      if parent and get_sibling_node then
        local sibling = get_sibling_node(try_node, parent, false)
        if sibling then
          local target_row, target_col = sibling:start()
          return sibling, target_row, target_col
        end
      end
    elseif current_pos == 1 then
      -- On first clause, jump back to try
      local target_row, target_col = try_node:start()
      return try_node, target_row, target_col
    else
      -- On a clause, jump to previous clause
      local prev_clause = clauses[current_pos - 1]
      local target_row, target_col = get_clause_keyword_position(prev_clause)
      if not target_row then
        target_row, target_col = prev_clause:start()
      end
      return prev_clause, target_row, target_col
    end
  end
  
  return nil, nil, nil
end

return M
