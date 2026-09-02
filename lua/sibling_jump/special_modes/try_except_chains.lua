-- Try/catch chain navigation for sibling-jump.nvim
-- Python try/except/else/finally, JS try/catch/finally, Swift do/catch

local M = {}

-- Grammars name the statement try_statement or do_statement, and its clauses *except*, *catch*,
-- *finally*, or (Python) else_clause
local function is_try_statement(node)
  local t = node:type()
  return t == "try_statement" or t == "do_statement"
end

local function is_try_clause(node)
  if not node:named() then
    return false
  end
  local t = node:type()
  return t:find("except") ~= nil or t:find("catch") ~= nil or t:find("finally") ~= nil or t == "else_clause"
end

-- Collect all except/catch/finally clauses in a try statement
-- Returns: list of clause nodes (in order from first to last)
local function collect_try_clauses(try_node)
  local clauses = {}

  if not try_node or not is_try_statement(try_node) then
    return clauses
  end

  for child in try_node:iter_children() do
    if is_try_clause(child) then
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

  if not is_try_clause(clause_node) then
    return nil, nil
  end

  -- Find the keyword child (except, catch, else, finally)
  for child in clause_node:iter_children() do
    local child_type = child:type()
    if child_type == "except" or child_type == "catch" or child_type == "else" or child_type == "finally" then
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

    if is_try_statement(current) then
      found_try = current
      break
    elseif is_try_clause(current) and current:parent() and is_try_statement(current:parent()) then
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

  if not found_try or not is_try_statement(found_try) then
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

  -- Only the keyword lines are part of the chain; statements inside the bodies navigate normally
  for i, clause in ipairs(clauses) do
    if cursor_row == clause:start() then
      return true, found_try, i
    end
  end

  local try_start_row, _, try_end_row = found_try:range()
  if cursor_row == try_start_row then
    return true, found_try, 0
  end
  -- On the closing line: a virtual position after the last clause, so backward reaches it
  if cursor_row == try_end_row then
    return true, found_try, #clauses + 1
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
