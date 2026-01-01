-- Call expression boundary navigation
-- Handles method calls and function calls: foo.bar(...) or bar(...)
-- When cursor is on a method/function name, cycles between the name and closing paren

local utils = require("sibling_jump.block_loop.utils")

local M = {}

-- Detect if cursor is on a call expression
-- Returns: detected (bool), context (table or nil)
function M.detect(node, cursor_pos)
  if not node then
    return false, nil
  end
  
  local current = node
  
  -- Case 1: Cursor on method/function name (property_identifier or identifier)
  if current:type() == "property_identifier" or current:type() == "identifier" then
    -- Walk up to find if this is part of a call_expression
    local call_expr = M.find_parent_call_expression(current)
    
    if call_expr then
      -- For method chains, the call_expression might start earlier (e.g., at the beginning of the chain)
      -- So instead of checking if cursor is on call_expr start line,
      -- check if cursor is on the property_identifier's line
      local prop_row = current:start()
      -- cursor_pos[1] is 1-indexed, prop_row is 0-indexed
      if prop_row == cursor_pos[1] - 1 then
        local context = M.build_context(call_expr, current)
        return true, context
      end
    end
  end
  
  -- Case 2: Cursor on closing paren/bracket - walk up to find call_expression
  -- This handles the case when cycling back from the closing position
  local parent = current:parent()
  while parent do
    if parent:type() == "call_expression" then
      local _, _, end_row, end_col = parent:range()
      -- Check if cursor is on the ending line of this call_expression
      if end_row == cursor_pos[1] - 1 then
        -- Find the property_identifier for this call
        local func = parent:field("function")[1]
        if func and func:type() == "member_expression" then
          local prop = func:field("property")[1]
          if prop then
            local context = M.build_context(parent, prop)
            return true, context
          end
        elseif func and func:type() == "identifier" then
          local context = M.build_context(parent, func)
          return true, context
        end
      end
    end
    parent = parent:parent()
  end
  
  return false, nil
end

-- Find parent call_expression for a node
-- Must be a direct function name, not nested inside arguments
function M.find_parent_call_expression(node)
  local current = node
  
  -- Walk up: property_identifier -> member_expression -> call_expression
  -- or: identifier -> call_expression
  while current do
    local parent = current:parent()
    if not parent then break end
    
    local parent_type = parent:type()
    
    -- If we're at member_expression, check if parent is call_expression
    if current:type() == "member_expression" and parent_type == "call_expression" then
      return parent
    end
    
    -- If we're at identifier and parent is call_expression
    if current:type() == "identifier" and parent_type == "call_expression" then
      -- Make sure this identifier is the function, not an argument
      local func_node = parent:field("function")[1]
      if func_node and func_node:id() == current:id() then
        return parent
      end
    end
    
    -- If we're at property_identifier, go to member_expression first
    if current:type() == "property_identifier" and parent_type == "member_expression" then
      current = parent
    else
      break
    end
  end
  
  return nil
end

-- Build context with positions
function M.build_context(call_expr, name_node)
  -- Get the full range of the call expression
  local _, _, end_row, end_col = call_expr:range()
  
  -- Get the method/function name position
  local name_row, name_col = name_node:start()
  
  -- Adjust end_col to be inside the closing paren (one position before the range end)
  -- This ensures we land on ')' not on ';' after it
  local closing_col = end_col > 0 and (end_col - 1) or 0
  
  return {
    node = call_expr,
    positions = {
      { row = name_row + 1, col = name_col },        -- Method/function name (1-indexed)
      { row = end_row + 1, col = closing_col },      -- Closing paren (1-indexed, adjusted)
    },
    current_index = nil,  -- Will be set during navigation
  }
end

-- Navigate between boundaries
function M.navigate(context, cursor_pos, mode)
  -- Find current position index
  -- Check both row and column to handle cases where multiple positions are on the same line
  -- Allow a small column range (within 5 chars) to handle cursor anywhere within the method name
  for i, pos in ipairs(context.positions) do
    if pos.row == cursor_pos[1] then
      local col_diff = math.abs(pos.col - cursor_pos[2])
      if col_diff <= 5 then
        context.current_index = i
        break
      end
    end
  end
  
  if not context.current_index then
    -- Shouldn't happen, but fallback to first position
    return context.positions[1]
  end
  
  -- Cycle through positions
  if mode == "normal" then
    -- Normal mode: cycle forward (loop back to start)
    local next_index = context.current_index + 1
    if next_index > #context.positions then
      next_index = 1
    end
    return context.positions[next_index]
  end
  
  return nil
end

return M
