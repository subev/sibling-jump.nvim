-- If-else-if chain navigation for sibling-jump.nvim
-- Handles navigation through if/else-if/else structures

local M = {}

-- Collect all elif/else clauses in an if-else chain
-- Returns: list of clause nodes (in order from first to last)
-- Works for:
--   - JavaScript/TypeScript: else_clause with nested if_statement
--   - Lua: elseif_statement, else_statement as direct children
--   - Python: elif_clause, else_clause as direct children
local function collect_else_clauses(if_node)
  local clauses = {}
  local current_if = if_node

  while current_if and current_if:type() == "if_statement" do
    local found_continuation = false
    
    for i = 0, current_if:child_count() - 1 do
      local child = current_if:child(i)
      local child_type = child:type()
      
      -- Handle Python's elif_clause (direct child of if_statement)
      if child_type == "elif_clause" then
        found_continuation = true
        table.insert(clauses, child)
        -- Continue loop to find more elif/else clauses
        
      -- Handle else_clause (Python and JS/TS)
      elseif child_type == "else_clause" then
        found_continuation = true
        table.insert(clauses, child)

        -- Check if this else clause contains another if_statement (JS/TS else if)
        local has_nested_if = false
        for j = 0, child:child_count() - 1 do
          local grandchild = child:child(j)
          if grandchild:type() == "if_statement" then
            -- JS/TS: else if is a nested if_statement inside else_clause
            current_if = grandchild
            has_nested_if = true
            break
          end
        end
        
        if not has_nested_if then
          -- This is a final else (Python or JS/TS), stop here
          return clauses
        end
        break  -- Break inner loop, continue with nested if_statement
      end
    end

    if not found_continuation then
      break
    end
  end

  return clauses
end

-- Get position of keyword within a clause (else, elif, etc.)
-- Returns: row, col (pointing to first char of keyword)
local function get_else_keyword_position(clause_node)
  if not clause_node then
    return nil, nil
  end
  
  local clause_type = clause_node:type()
  local valid_types = {
    ["else_clause"] = true,
    ["elif_clause"] = true,
    ["elseif_statement"] = true,
    ["else_statement"] = true,
  }
  
  if not valid_types[clause_type] then
    return nil, nil
  end

  -- Find the keyword child (else, elif, elseif)
  for i = 0, clause_node:child_count() - 1 do
    local child = clause_node:child(i)
    local child_type = child:type()
    if child_type == "else" or child_type == "elif" or child_type == "elseif" then
      return child:start()
    end
  end

  -- Fallback to clause start position
  return clause_node:start()
end

-- Detect if we're on an if statement with else clauses
-- Returns: has_else_clauses (boolean), if_statement_node, current_position_index
-- current_position_index: 0 = on main if, 1+ = on else clause (1-based)
function M.detect(node)
  if not node then
    return false, nil, 0
  end

  -- CRITICAL: Only trigger if-else chain navigation if we're ON an if/else/elseif keyword/structure.
  -- If we're on a statement INSIDE an if/else block (not the structure itself), skip detection.
  local utils = require("sibling_jump.utils")
  
  -- Walk up to find the first meaningful node (statement level)
  local meaningful_node = node
  while meaningful_node and not utils.is_meaningful_node(meaningful_node) do
    meaningful_node = meaningful_node:parent()
  end
  
  -- If we found a meaningful node, check if it's an if/else structure
  if meaningful_node then
    local meaningful_is_if_else = meaningful_node:type() == "if_statement"
      or meaningful_node:type() == "elseif_statement"
      or meaningful_node:type() == "else_statement"
      or meaningful_node:type() == "else_clause"
      or meaningful_node:type() == "elif_clause"  -- Python
    
    -- If the meaningful node is NOT an if/else structure, skip detection
    -- This prevents triggering when cursor is on regular statements INSIDE an if/else block
    if not meaningful_is_if_else then
      return false, nil, 0
    end
  end

  -- Walk up to find if_statement or else_clause
  -- We want to find the OUTERMOST if_statement that contains the cursor AND has else clauses
  -- However, if we find an inner if_statement with else clauses, prefer that over continuing up
  local current = node
  local depth = 0
  local found_if = nil
  local found_else_clause = nil

  while current and depth < 20 do
    if current:type() == "if_statement" then
      -- Found an if_statement
      -- Check if this if_statement has else/elseif children (Lua-style check)
      local has_else_children = false
      for i = 0, current:child_count() - 1 do
        local child = current:child(i)
        if child:type() == "elseif_statement" or child:type() == "else_statement" or child:type() == "else_clause" or child:type() == "elif_clause" then
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
    elseif current:type() == "else_clause" or current:type() == "elseif_statement" or current:type() == "else_statement" or current:type() == "elif_clause" then
      found_else_clause = current
      -- Continue walking up to find the parent if_statement
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

  -- If we found an if_statement but it's nested inside an else_clause,
  -- walk up to find the outermost if_statement in the chain
  if found_if then
    local test_parent = found_if:parent()
    while test_parent and test_parent:type() == "else_clause" do
      local outer_if = test_parent:parent()
      if outer_if and outer_if:type() == "if_statement" then
        found_if = outer_if
        test_parent = outer_if:parent()
      else
        break
      end
    end
  end

  if not found_if then
    return false, nil, 0
  end

  -- Check if this if_statement has else clauses
  local else_clauses = collect_else_clauses(found_if)
  
  -- For Lua/Python: collect elseif_statement/elif_clause and else_statement/else_clause directly from if_node children
  if #else_clauses == 0 then
    for i = 0, found_if:child_count() - 1 do
      local child = found_if:child(i)
      local child_type = child:type()
      if child_type == "elseif_statement" or child_type == "else_statement" 
         or child_type == "elif_clause" or child_type == "else_clause" then
        table.insert(else_clauses, child)
      end
    end
  end
  
  if #else_clauses == 0 then
    return false, nil, 0
  end

  -- Determine current position: are we on the main if or on an else clause?
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor[1] - 1 -- Convert to 0-indexed

  -- Check if cursor is on one of the else clauses (compare by position, not object identity)
  -- Since else clauses can be nested, we want the LAST (innermost) match
  local matched_position = nil
  for i, clause in ipairs(else_clauses) do
    local clause_start_row = clause:start()
    local clause_end_row = select(3, clause:range())

    if cursor_row >= clause_start_row and cursor_row <= clause_end_row then
      matched_position = i
    end
  end

  if matched_position then
    return true, found_if, matched_position
  end

  -- Check if cursor is on the main if (not on any else clause)
  local if_start_row = found_if:start()
  local first_else_row = else_clauses[1]:start()

  if cursor_row >= if_start_row and cursor_row < first_else_row then
    -- Additional check for Lua: make sure we're not inside a consequence/body block
    -- In Lua, the block starts on a different line than the if keyword
    -- Check if cursor is beyond the if keyword line (meaning we're in the block)
    for i = 0, found_if:child_count() - 1 do
      local child = found_if:child(i)
      if child:type() == "block" then  -- Lua uses "block", not "statement_block"
        local block_start, _, block_end = child:range()
        if cursor_row >= block_start and cursor_row <= block_end then
          -- We're inside the consequence block, not on the if keyword
          return false, nil, 0
        end
      end
    end
    
    -- Cursor is on the main if part (before any else)
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
  
  -- For Lua/Python: collect elseif_statement/elif_clause and else_statement/else_clause directly from if_node children
  if #else_clauses == 0 then
    for i = 0, if_node:child_count() - 1 do
      local child = if_node:child(i)
      local child_type = child:type()
      if child_type == "elseif_statement" or child_type == "else_statement"
         or child_type == "elif_clause" or child_type == "else_clause" then
        table.insert(else_clauses, child)
      end
    end
  end

  if forward then
    -- Forward navigation: if (pos=0) → else if (pos=1) → else if (pos=2) → else (pos=N) → next statement
    if current_pos == 0 then
      -- On main if, jump to first else clause
      if #else_clauses > 0 then
        local target_row, target_col = get_else_keyword_position(else_clauses[1])
        -- For Lua nodes, get_else_keyword_position returns nil, so fall back to node start
        if not target_row then
          target_row, target_col = else_clauses[1]:start()
        end
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
      -- For Lua nodes, get_else_keyword_position returns nil, so fall back to node start
      if not target_row then
        target_row, target_col = next_clause:start()
      end
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
      -- For Lua nodes, get_else_keyword_position returns nil, so fall back to node start
      if not target_row then
        target_row, target_col = prev_clause:start()
      end
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
  
  -- For Lua/Python: collect elseif_statement/elif_clause and else_statement/else_clause directly
  if #else_clauses == 0 then
    for i = 0, if_node:child_count() - 1 do
      local child = if_node:child(i)
      local child_type = child:type()
      if child_type == "elseif_statement" or child_type == "else_statement"
         or child_type == "elif_clause" or child_type == "else_clause" then
        table.insert(else_clauses, child)
      end
    end
  end
  
  -- If we found else clauses, return the last one
  if #else_clauses > 0 then
    local last_clause = else_clauses[#else_clauses]
    local target_row, target_col = get_else_keyword_position(last_clause)
    -- For Lua nodes, get_else_keyword_position returns nil, so fall back to node start
    if not target_row then
      target_row, target_col = last_clause:start()
    end
    return last_clause, target_row, target_col
  end
  
  -- No else clauses, return the if_node itself
  return if_node, if_node:start()
end

return M
