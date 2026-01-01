-- Loop block detection and navigation (for/while loops)
-- Supports both TypeScript/JavaScript and Lua

local utils = require("sibling_jump.block_loop.utils")

local M = {}

-- Detect if cursor is in a loop statement
-- Returns: detected (bool), context (table or nil)
function M.detect(node, cursor_pos)
  if not node then
    return false, nil
  end
  
  -- Look for loop statements in ancestors
  local loop_node = utils.find_ancestor(node, {
    "for_statement",           -- TypeScript/JavaScript (includes for, for...in, for...of)
    "while_statement",         -- TypeScript/JavaScript
    "for_in_statement",        -- TypeScript/JavaScript: for...in
    "for_in_loop",             -- Lua: for i in pairs()
    "for_loop",                -- Lua: for i = 1, 10
    "while_loop",              -- Lua: while condition do
  })
  
  if loop_node then
    -- Check if cursor is on the loop keyword line or closing bracket
    local context = M.build_context(loop_node)
    
    for _, pos in ipairs(context.positions) do
      if pos.row == cursor_pos[1] then
        return true, context
      end
    end
    
    return false, nil
  end
  
  return false, nil
end

-- Build context with all positions in the loop
function M.build_context(loop_node)
  local positions = {}
  local loop_type = loop_node:type()
  
  -- Position 0: loop keyword (for/while)
  local loop_row, loop_col = loop_node:start()
  table.insert(positions, {
    row = loop_row + 1,  -- Convert to 1-indexed
    col = loop_col,
    type = "loop_keyword",
  })
  
  -- Last position: closing bracket/end
  local closing_row, closing_col = M.find_closing_bracket(loop_node, loop_type)
  table.insert(positions, {
    row = closing_row + 1,
    col = closing_col,
    type = "closing_bracket",
  })
  
  return {
    positions = positions,
    loop_node = loop_node,
  }
end

-- Find the closing bracket of the loop
function M.find_closing_bracket(loop_node, loop_type)
  -- For Lua loops: look for 'end' keyword child
  if loop_type == "for_in_loop" or loop_type == "for_loop" or loop_type == "while_loop" then
    for i = 0, loop_node:child_count() - 1 do
      local child = loop_node:child(i)
      if child:type() == "end" then
        -- Found Lua 'end' keyword
        local end_row, end_col = child:start()
        return end_row, end_col
      end
    end
  end
  
  -- For TypeScript/JavaScript: find the statement_block and get its closing bracket
  for i = 0, loop_node:child_count() - 1 do
    local child = loop_node:child(i)
    if child:type() == "statement_block" then
      local _, _, end_row, end_col = child:range()
      return end_row, end_col
    end
  end
  
  -- Fallback: use loop_node's end
  return loop_node:end_()
end

-- Navigate to next position in cycle
function M.navigate(context, cursor_pos, mode)
  local positions = context.positions
  local current_row = cursor_pos[1]
  
  -- Find current position index
  local current_index = nil
  for i, pos in ipairs(positions) do
    if pos.row == current_row then
      current_index = i
      break
    end
  end
  
  -- If not exactly on a position, find closest
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
  if position.type == "loop_keyword" then
    -- Could be 'for' (2 chars), 'while' (5 chars), etc.
    -- For simplicity, just add 2 for 'for', adjust if needed
    return {
      row = position.row,
      col = position.col + 2,  -- End of 'for'/'for' part
      type = position.type,
    }
  end
  
  return position
end

return M
