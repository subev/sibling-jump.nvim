-- If/else/elseif block detection and navigation

local utils = require("sibling_jump.block_loop.utils")

local M = {}

-- Detect if cursor is in an if-statement block
-- Returns: detected (bool), context (table or nil)
function M.detect(node, cursor_pos)
  if not node then
    return false, nil
  end
  
  -- Look for if_statement in ancestors
  local if_node = utils.find_ancestor(node, {"if_statement"})
  
  if if_node then
    -- Build context first to check all positions
    local outermost = M.find_outermost_if(if_node)
    local context = M.build_context(outermost)
    
    -- Check if cursor is on ANY of the boundary positions (not just if keyword)
    for _, pos in ipairs(context.positions) do
      if pos.row == cursor_pos[1] then
        return true, context
      end
    end
    
    return false, nil
  end
  
  -- Check if we're on an else clause line (TypeScript/JavaScript)
  local else_clause = utils.find_ancestor(node, {"else_clause"})
  if else_clause then
    -- Check cursor is on 'else' keyword line
    if not utils.is_cursor_on_node_line(cursor_pos[1], else_clause) then
      return false, nil
    end
    
    -- Walk up to parent if_statement
    local parent = else_clause:parent()
    if parent and parent:type() == "if_statement" then
      local outermost = M.find_outermost_if(parent)
      return true, M.build_context(outermost)
    end
  end
  
  -- Check if we're on an elseif or else statement line (Lua)
  local lua_else = utils.find_ancestor(node, {"elseif_statement", "else_statement"})
  if lua_else then
    -- Check cursor is on the keyword line
    if not utils.is_cursor_on_node_line(cursor_pos[1], lua_else) then
      return false, nil
    end
    
    -- Walk up to parent if_statement
    local parent = lua_else:parent()
    if parent and parent:type() == "if_statement" then
      local outermost = M.find_outermost_if(parent)
      return true, M.build_context(outermost)
    end
  end
  
  return false, nil
end

-- Find the outermost if statement in a chain
function M.find_outermost_if(if_node)
  local current = if_node
  local depth = 0
  local max_depth = 20
  
  while depth < max_depth do
    local parent = current:parent()
    if not parent then break end
    
    -- Check if parent is else_clause containing this if
    if parent:type() == "else_clause" then
      local grandparent = parent:parent()
      if grandparent and grandparent:type() == "if_statement" then
        current = grandparent
      else
        break
      end
    else
      break
    end
    
    depth = depth + 1
  end
  
  return current
end

-- Build context with all positions in the if-else chain
function M.build_context(if_node)
  local positions = {}
  
  -- Position 0: 'if' keyword
  local if_row, if_col = if_node:start()
  table.insert(positions, {
    row = if_row + 1,  -- Convert to 1-indexed
    col = if_col,
    type = "if_keyword",
  })
  
  -- Collect else clauses
  local else_positions = M.collect_else_clauses(if_node)
  for _, pos in ipairs(else_positions) do
    table.insert(positions, pos)
  end
  
  -- Last position: closing bracket of final block
  local closing_row, closing_col = M.find_closing_bracket(if_node)
  table.insert(positions, {
    row = closing_row + 1,
    col = closing_col,
    type = "closing_bracket",
  })
  
  return {
    positions = positions,
    if_node = if_node,
  }
end

-- Collect all else clauses (else if, else) recursively
-- Handles both TypeScript/JavaScript (else_clause) and Lua (elseif_statement, else_statement)
function M.collect_else_clauses(if_node)
  local positions = {}
  
  for i = 0, if_node:child_count() - 1 do
    local child = if_node:child(i)
    
    -- TypeScript/JavaScript: else_clause (nested structure)
    if child:type() == "else_clause" then
      local else_row, else_col = child:start()
      
      -- Add this else clause position FIRST
      local has_nested_if = false
      for j = 0, child:child_count() - 1 do
        local grandchild = child:child(j)
        if grandchild:type() == "if_statement" then
          has_nested_if = true
          break
        end
      end
      
      table.insert(positions, {
        row = else_row + 1,
        col = else_col,
        type = has_nested_if and "else_if_keyword" or "else_keyword",
      })
      
      -- Then recurse to collect deeper else clauses
      if has_nested_if then
        for j = 0, child:child_count() - 1 do
          local grandchild = child:child(j)
          if grandchild:type() == "if_statement" then
            local nested_positions = M.collect_else_clauses(grandchild)
            for _, pos in ipairs(nested_positions) do
              table.insert(positions, pos)
            end
            break
          end
        end
      end
    -- Lua: elseif_statement (flat structure, direct child)
    elseif child:type() == "elseif_statement" then
      local elseif_row, elseif_col = child:start()
      table.insert(positions, {
        row = elseif_row + 1,
        col = elseif_col,
        type = "elseif_keyword",
      })
    -- Lua: else_statement (flat structure, direct child)
    elseif child:type() == "else_statement" then
      local else_row, else_col = child:start()
      table.insert(positions, {
        row = else_row + 1,
        col = else_col,
        type = "else_keyword",
      })
    end
  end
  
  return positions
end

-- Find the closing bracket of the final block
-- Handles both TypeScript/JavaScript (}) and Lua (end)
function M.find_closing_bracket(if_node)
  -- For Lua: look for 'end' keyword child
  for i = 0, if_node:child_count() - 1 do
    local child = if_node:child(i)
    if child:type() == "end" then
      -- Found Lua 'end' keyword
      local end_row, end_col = child:start()
      return end_row, end_col
    end
  end
  
  -- For TypeScript/JavaScript: find the last statement_block or else_clause
  local last_block = nil
  
  for i = 0, if_node:child_count() - 1 do
    local child = if_node:child(i)
    if child:type() == "statement_block" or child:type() == "else_clause" then
      last_block = child
    end
  end
  
  if not last_block then
    -- Fallback: use if_node's end
    return if_node:end_()
  end
  
  -- If it's an else_clause, find its statement_block
  if last_block:type() == "else_clause" then
    for i = 0, last_block:child_count() - 1 do
      local child = last_block:child(i)
      if child:type() == "statement_block" then
        last_block = child
        break
      end
      -- Also check for nested if_statement (else-if case)
      if child:type() == "if_statement" then
        -- Recursively find the closing bracket of the nested if
        return M.find_closing_bracket(child)
      end
    end
  end
  
  local _, _, end_row, end_col = last_block:range()
  return end_row, end_col
end

-- Navigate to next position in cycle
function M.navigate(context, cursor_pos, mode)
  local positions = context.positions
  local current_row = cursor_pos[1]
  local current_col = cursor_pos[2]
  
  -- Find current position index by matching both row and column
  -- For single-line if statements, we need column matching to distinguish positions
  local current_index = nil
  local CLOSE_THRESHOLD = 3  -- Allow small tolerance for cursor positioning
  
  for i, pos in ipairs(positions) do
    if pos.row == current_row then
      local col_diff = math.abs(pos.col - current_col)
      if col_diff <= CLOSE_THRESHOLD then
        current_index = i
        break
      end
    end
  end
  
  -- If not exactly on a position, find closest on same row first, then by row
  if not current_index then
    local min_col_diff = math.huge
    for i, pos in ipairs(positions) do
      if pos.row == current_row then
        local col_diff = math.abs(pos.col - current_col)
        if col_diff < min_col_diff then
          min_col_diff = col_diff
          current_index = i
        end
      end
    end
  end
  
  -- If still not found, find closest by row
  if not current_index then
    current_index = utils.find_closest_position_index(positions, current_row)
  end
  
  -- Get next position (with wrapping)
  local next_index = (current_index % #positions) + 1
  local target = positions[next_index]
  
  -- Adjust for visual mode (position at end of keyword)
  if mode == "visual" then
    return M.adjust_for_visual_mode(target)
  end
  
  return target
end

-- Adjust position for visual mode (end of keyword)
function M.adjust_for_visual_mode(position)
  if position.type == "else_keyword" then
    return {
      row = position.row,
      col = position.col + 3,  -- End of 'else' (4 chars - 1)
      type = position.type,
    }
  end
  
  if position.type == "else_if_keyword" then
    return {
      row = position.row,
      col = position.col + 3,  -- End of 'else' part
      type = position.type,
    }
  end
  
  if position.type == "elseif_keyword" then
    return {
      row = position.row,
      col = position.col + 5,  -- End of 'elseif' (6 chars - 1)
      type = position.type,
    }
  end
  
  if position.type == "if_keyword" then
    return {
      row = position.row,
      col = position.col + 1,  -- End of 'if' (2 chars - 1)
      type = position.type,
    }
  end
  
  return position
end

return M
