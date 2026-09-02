-- If-else-if chain navigation for sibling-jump.nvim
-- Handles navigation through if/else-if/else structures

local M = {}

-- Clause types across grammars: JS/TS else_clause, Python elif_clause/else_clause,
-- Lua elseif_statement/else_statement, Swift's bare `else` keyword node
local ELSE_CLAUSE_TYPES = {
  else_clause = true,
  elif_clause = true,
  elseif_statement = true,
  else_statement = true,
  ["else"] = true,
}

local function is_else_clause(node)
  return node ~= nil and ELSE_CLAUSE_TYPES[node:type()] == true
end

-- Collect all elif/else clauses in an if-else chain, in order
-- JS/TS nests `else if` as an if_statement inside else_clause; Python and Lua keep clauses flat
local function collect_else_clauses(if_node)
  local clauses = {}
  local current_if = if_node

  while current_if do
    local nested_if = nil
    for child in current_if:iter_children() do
      if is_else_clause(child) then
        table.insert(clauses, child)
        for grandchild in child:iter_children() do
          if grandchild:type() == "if_statement" then
            nested_if = grandchild
          end
        end
        -- Swift: `else if` is an if_statement right after the `else` keyword
        local following = child:next_named_sibling()
        if following and following:type() == "if_statement" then
          nested_if = following
        end
      end
    end
    current_if = nested_if
  end

  return clauses
end

-- Get position of keyword within a clause (else, elif, etc.)
-- Returns: row, col (pointing to first char of keyword)
local function get_else_keyword_position(clause_node)
  if not is_else_clause(clause_node) then
    return nil, nil
  end

  for child in clause_node:iter_children() do
    local child_type = child:type()
    if child_type == "else" or child_type == "elif" or child_type == "elseif" then
      return child:start()
    end
  end

  return clause_node:start()
end

-- Detect if we're on an if statement with else clauses
-- Returns: has_else_clauses (boolean), if_statement_node, current_position_index
-- current_position_index: 0 = on main if, 1+ = on else clause (1-based)
function M.detect(node)
  if not node then
    return false, nil, 0
  end

  -- Only trigger on the if/else structure itself, never on a statement INSIDE one of its blocks:
  -- the innermost line-starting node above the cursor must be the if or one of its clauses
  local utils = require("sibling_jump.utils")
  local line_node = node
  while line_node and not utils.starts_line(line_node) do
    line_node = line_node:parent()
  end
  if line_node and line_node:type() ~= "if_statement" and not is_else_clause(line_node) then
    return false, nil, 0
  end

  -- Walk up to find if_statement or else_clause
  -- We want to find the OUTERMOST if_statement that contains the cursor AND has else clauses
  -- However, if we find an inner if_statement with else clauses, prefer that over continuing up
  local current = node
  local depth = 0
  local found_if = nil

  while current and depth < 20 do
    if current:type() == "if_statement" then
      -- Found an if_statement
      -- Check if this if_statement has else/elseif children (Lua-style check)
      local has_else_children = false
      for child in current:iter_children() do
        if is_else_clause(child) then
          has_else_children = true
          break
        end
      end

      -- If this if has else clauses, use it and stop searching
      -- Otherwise, keep walking up to find outer if statements
      if has_else_children and not found_if then
        found_if = current
        -- Don't break yet - continue to check if it's nested in an else_clause
      elseif not found_if then
        found_if = current
      end

      current = current:parent()
      depth = depth + 1
    else
      current = current:parent()
      depth = depth + 1
    end

    -- Stop if we've gone too far up
    if current and (current:type() == "statement_block" or current:type() == "block" or current:type() == "program" or current:type() == "module") then
      break
    end
  end

  -- An `else if` is nested: inside an else_clause (JS/TS) or right after an `else` node (Swift).
  -- Walk up to the outermost if_statement of the chain.
  while found_if do
    local test_parent = found_if:parent()
    local previous = found_if:prev_named_sibling()
    if test_parent and test_parent:type() == "else_clause" and test_parent:parent()
        and test_parent:parent():type() == "if_statement" then
      found_if = test_parent:parent()
    elseif test_parent and test_parent:type() == "if_statement" and previous and previous:type() == "else" then
      found_if = test_parent
    else
      break
    end
  end

  if not found_if then
    return false, nil, 0
  end

  local else_clauses = collect_else_clauses(found_if)
  if #else_clauses == 0 then
    return false, nil, 0
  end

  -- Determine current position: are we on the main if or on an else clause?
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor[1] - 1 -- Convert to 0-indexed

  -- Check if cursor is on one of the else clauses (compare by position, not object identity)
  -- Since else clauses can be nested, we want the LAST (innermost) match.
  -- A clause on the same row as its `if` (single-line if/else) only matches from its column on.
  local cursor_col = cursor[2]
  local if_start_row = found_if:start()
  local matched_position = nil
  for i, clause in ipairs(else_clauses) do
    local clause_start_row, clause_start_col = clause:start()
    local clause_end_row = select(3, clause:range())

    if cursor_row >= clause_start_row and cursor_row <= clause_end_row
        and (clause_start_row ~= if_start_row or cursor_col >= clause_start_col) then
      matched_position = i
    end
  end

  if matched_position then
    return true, found_if, matched_position
  end

  -- On the `if` line itself (not inside its body): position 0
  if cursor_row == if_start_row then
    return true, found_if, 0
  end

  -- Check if cursor is on the closing 'end' keyword of the if_statement
  -- In Lua, 'end' is after all else clauses but still part of the if structure
  local _, _, if_end_row = found_if:range()
  if cursor_row == if_end_row then
    -- Treat as being AFTER the last else clause (virtual position beyond all clauses)
    -- This way, backward navigation will go TO the last else clause
    return true, found_if, #else_clauses + 1
  end

  return false, nil, 0
end

-- Navigate forward/backward in an if-else-if chain
-- Returns: target node (if_statement or else_clause/elseif_statement/else_statement), target_row, target_col, or nil
-- Note: get_sibling_node must be passed in to avoid circular dependency
function M.navigate(if_node, current_pos, forward, get_sibling_node)
  local else_clauses = collect_else_clauses(if_node)

  if forward then
    -- Forward navigation: if (pos=0) → else if (pos=1) → else if (pos=2) → else (pos=N) → next statement
    if current_pos == 0 then
      -- On main if, jump to first else clause
      if #else_clauses > 0 then
        local target_row, target_col = get_else_keyword_position(else_clauses[1])
        return else_clauses[1], target_row, target_col
      else
        -- No else clauses, jump to next sibling of if_statement
        local parent = if_node:parent()
        if parent and get_sibling_node then
          local sibling = get_sibling_node(if_node, parent, true)
          if sibling then
            local target_row, target_col = sibling:start()
            return sibling, target_row, target_col
          end
        end
        return nil, nil, nil
      end
    elseif current_pos < #else_clauses then
      -- On an else clause, jump to next else clause
      local next_clause = else_clauses[current_pos + 1]
      local target_row, target_col = get_else_keyword_position(next_clause)
      return next_clause, target_row, target_col
    else
      -- On last else clause, jump to next sibling of if_statement
      local parent = if_node:parent()
      if parent and get_sibling_node then
        local sibling = get_sibling_node(if_node, parent, true)
        if sibling then
          local target_row, target_col = sibling:start()
          return sibling, target_row, target_col
        end
      end
      return nil, nil, nil
    end
  else
    -- Backward navigation: next statement → else (pos=N) → else if (pos=2) → else if (pos=1) → if (pos=0) → prev statement
    if current_pos == 0 then
      -- On main if, jump to previous sibling of if_statement
      local parent = if_node:parent()
      if parent and get_sibling_node then
        local sibling = get_sibling_node(if_node, parent, false)
        if sibling then
          local target_row, target_col = sibling:start()
          return sibling, target_row, target_col
        end
      end
      return nil, nil, nil
    elseif current_pos == 1 then
      -- On first else clause, jump back to main if
      local target_row, target_col = if_node:start()
      return if_node, target_row, target_col
    else
      -- On an else clause, jump to previous else clause
      local prev_clause = else_clauses[current_pos - 1]
      local target_row, target_col = get_else_keyword_position(prev_clause)
      return prev_clause, target_row, target_col
    end
  end
end

-- Get the entry point when navigating INTO an if_statement from outside
-- This determines where the cursor should land when jumping TO an if-else structure
-- Returns: target_node, target_row, target_col
function M.get_entry_point(if_node, forward)
  if forward then
    -- Forward: land on the 'if' keyword
    return if_node, if_node:start()
  end

  -- Backward: land on the last else/elseif clause
  local else_clauses = collect_else_clauses(if_node)

  -- If we found else clauses, return the last one
  if #else_clauses > 0 then
    local last_clause = else_clauses[#else_clauses]
    local target_row, target_col = get_else_keyword_position(last_clause)
    return last_clause, target_row, target_col
  end

  -- No else clauses, return the if_node itself
  return if_node, if_node:start()
end

return M
