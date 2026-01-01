-- Switch statement detection and navigation for block-loop
-- Cycles through: switch → case1 → case2 → ... → default → } → switch

local utils = require("sibling_jump.block_loop.utils")

local M = {}

-- Detect if cursor is on a switch statement boundary
-- Returns: detected (bool), context (table or nil)
function M.detect(node, cursor_pos)
  if not node then
    return false, nil
  end
  
  -- Look for switch_statement in ancestors
  local switch_node = utils.find_ancestor(node, {"switch_statement"})
  
  if not switch_node then
    return false, nil
  end
  
  -- Build context to get all positions
  local context = M.build_context(switch_node)
  
  -- Check if cursor is on any boundary position
  for _, pos in ipairs(context.positions) do
    if pos.row == cursor_pos[1] then
      return true, context
    end
  end
  
  return false, nil
end

-- Build context with all positions in the switch statement
function M.build_context(switch_node)
  local positions = {}
  
  -- Position 0: 'switch' keyword
  local switch_row, switch_col = switch_node:start()
  table.insert(positions, {
    row = switch_row + 1,
    col = switch_col,
    type = "switch_keyword",
  })
  
  -- Find switch_body
  local switch_body = M.find_switch_body(switch_node)
  if not switch_body then
    -- Fallback: just switch and closing bracket
    local _, _, end_row, end_col = switch_node:range()
    table.insert(positions, {
      row = end_row + 1,
      col = end_col,
      type = "closing_bracket",
    })
    return { positions = positions, switch_node = switch_node }
  end
  
  -- Collect all case and default clauses
  for i = 0, switch_body:child_count() - 1 do
    local child = switch_body:child(i)
    local child_type = child:type()
    
    if child_type == "switch_case" then
      local case_row, case_col = child:start()
      table.insert(positions, {
        row = case_row + 1,
        col = case_col,
        type = "case_keyword",
      })
    elseif child_type == "switch_default" then
      local default_row, default_col = child:start()
      table.insert(positions, {
        row = default_row + 1,
        col = default_col,
        type = "default_keyword",
      })
    end
  end
  
  -- Last position: closing bracket of switch body
  local _, _, end_row, end_col = switch_body:range()
  table.insert(positions, {
    row = end_row + 1,
    col = end_col,
    type = "closing_bracket",
  })
  
  return {
    positions = positions,
    switch_node = switch_node,
  }
end

-- Navigate to next position in cycle
function M.navigate(context, cursor_pos, mode)
  local positions = context.positions
  local current_row = cursor_pos[1]
  
  -- Find current position index
  local current_index = 1
  for i, pos in ipairs(positions) do
    if pos.row == current_row then
      current_index = i
      break
    end
  end
  
  -- Cycle to next (wrapping)
  local next_index = (current_index % #positions) + 1
  return positions[next_index]
end

-- Helper to find switch_body in switch_statement
function M.find_switch_body(switch_node)
  for i = 0, switch_node:child_count() - 1 do
    local child = switch_node:child(i)
    if child:type() == "switch_body" then
      return child
    end
  end
  return nil
end

return M
