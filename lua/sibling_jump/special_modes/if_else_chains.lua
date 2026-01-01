-- If-else-if chain navigation for sibling-jump.nvim
-- Handles navigation through if/else-if/else structures

local M = {}

-- Collect all else clauses in an if-else-if chain
-- Returns: list of else_clause nodes (in order from first to last)
-- Note: This is for JavaScript/TypeScript only. Lua uses a different approach.
local function collect_else_clauses(if_node)
  local clauses = {}
  local current_if = if_node

  while current_if and current_if:type() == "if_statement" do
    -- Look for else_clause in this if_statement
    local found_else = false
    for i = 0, current_if:child_count() - 1 do
      local child = current_if:child(i)
      if child:type() == "else_clause" then
        found_else = true
        table.insert(clauses, child)

        -- Check if this else clause contains another if_statement (else if)
        -- or a statement_block (final else)
        for j = 0, child:child_count() - 1 do
          local grandchild = child:child(j)
          if grandchild:type() == "if_statement" then
            -- This is an else if, continue with the nested if_statement
            current_if = grandchild
            break
          elseif grandchild:type() == "statement_block" then
            -- This is the final else, no more to traverse
            current_if = nil
            break
          end
        end
        break
      end
    end

    if not found_else then
      break
    end
  end

  return clauses
end

-- Get position of 'else' keyword within else_clause
-- Returns: row, col (pointing to 'e' of 'else')
local function get_else_keyword_position(else_clause_node)
  if not else_clause_node or else_clause_node:type() ~= "else_clause" then
    return nil, nil
  end

  -- Find the 'else' keyword child
  for i = 0, else_clause_node:child_count() - 1 do
    local child = else_clause_node:child(i)
    if child:type() == "else" then
      return child:start()
    end
  end

  -- Fallback to else_clause start position
  return else_clause_node:start()
end

-- Detect if we're on an if statement with else clauses
-- Returns: has_else_clauses (boolean), if_statement_node, current_position_index
-- current_position_index: 0 = on main if, 1+ = on else clause (1-based)
function M.detect(node)
  if not node then
    return false, nil, 0
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
        if child:type() == "elseif_statement" or child:type() == "else_statement" or child:type() == "else_clause" then
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
    elseif current:type() == "else_clause" or current:type() == "elseif_statement" or current:type() == "else_statement" then
      found_else_clause = current
      -- Continue walking up to find the parent if_statement
      current = current:parent()
      depth = depth + 1
    else
      current = current:parent()
      depth = depth + 1
    end

    -- Stop if we've gone too far up
    if current and (current:type() == "statement_block" or current:type() == "program") then
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
  
  -- For Lua: collect elseif_statement and else_statement directly from if_node children
  if #else_clauses == 0 then
    for i = 0, found_if:child_count() - 1 do
      local child = found_if:child(i)
      if child:type() == "elseif_statement" or child:type() == "else_statement" then
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

  return false, nil, 0
end

-- Navigate forward/backward in an if-else-if chain
-- Returns: target node (if_statement or else_clause/elseif_statement/else_statement), target_row, target_col, or nil
-- Note: get_sibling_node must be passed in to avoid circular dependency
function M.navigate(if_node, current_pos, forward, get_sibling_node)
  local else_clauses = collect_else_clauses(if_node)
  
  -- For Lua: collect elseif_statement and else_statement directly from if_node children
  if #else_clauses == 0 then
    for i = 0, if_node:child_count() - 1 do
      local child = if_node:child(i)
      if child:type() == "elseif_statement" or child:type() == "else_statement" then
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

return M
