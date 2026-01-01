-- Object property value navigation
-- Handles: { propName: value.method().chain() }
-- When cursor is on property name, cycles between name and closing of value

local M = {}

-- Detect if cursor is on an object property name whose value is a call expression
-- Returns: detected (bool), context (table or nil)
function M.detect(node, cursor_pos)
  if not node then
    return false, nil
  end
  
  -- Check if we're on a property_identifier that's DIRECTLY a child of a pair
  -- (not a property_identifier inside a member_expression in a method chain)
  if node:type() == "property_identifier" then
    local parent = node:parent()
    
    -- IMPORTANT: Only match if immediate parent is 'pair'
    -- This ensures we're on the property NAME (e.g., "consumeToken: ...")
    -- NOT on a method name in a chain (e.g., ".input" in a chain)
    if parent and parent:type() == "pair" then
      -- Verify this property_identifier is the KEY of the pair (child 0)
      local key = parent:child(0)
      if key and key:id() == node:id() then
        -- Get the value (child at index 2: key, :, value)
        local value = parent:child(2)
        
        if value and value:type() == "call_expression" then
          -- Check if cursor is on property name line
          local prop_row = node:start()
          if prop_row == cursor_pos[1] - 1 then
            local context = M.build_context(node, value)
            return true, context
          end
          
          -- Check if cursor is on value end line (for cycling back)
          local _, _, end_row, end_col = value:range()
          if end_row == cursor_pos[1] - 1 then
            local context = M.build_context(node, value)
            return true, context
          end
        end
      end
    end
  end
  
  -- Case 2: Cursor on closing of value - find the property name
  -- Walk up to find pair, then get property name
  -- IMPORTANT: Only match if cursor is near the END of the value, not in the middle
  local current = node
  while current do
    if current:type() == "pair" then
      local prop_name = current:child(0)
      local value = current:child(2)
      
      if prop_name and value and value:type() == "call_expression" then
        local _, _, end_row, end_col = value:range()
        -- Check if cursor is on the ending line AND near the ending column
        -- Use strict column match (within 2 columns) to avoid matching nested calls
        if end_row == cursor_pos[1] - 1 then
          local cursor_col = cursor_pos[2]
          local col_diff = math.abs(cursor_col - (end_col - 1))
          if col_diff <= 2 then
            local context = M.build_context(prop_name, value)
            return true, context
          end
        end
      end
      break
    end
    current = current:parent()
    if not current then break end
  end
  
  return false, nil
end

-- Build context with positions
function M.build_context(prop_name_node, value_node)
  -- Get property name position
  local name_row, name_col = prop_name_node:start()
  
  -- Get value end position (closing paren)
  local _, _, end_row, end_col = value_node:range()
  
  -- Adjust end_col to be inside the closing paren
  local closing_col = end_col > 0 and (end_col - 1) or 0
  
  return {
    node = value_node,
    positions = {
      { row = name_row + 1, col = name_col },      -- Property name (1-indexed)
      { row = end_row + 1, col = closing_col },    -- Closing paren of value (1-indexed)
    },
    current_index = nil,
  }
end

-- Navigate between boundaries
function M.navigate(context, cursor_pos, mode)
  -- Find current position index
  for i, pos in ipairs(context.positions) do
    if pos.row == cursor_pos[1] then
      context.current_index = i
      break
    end
  end
  
  if not context.current_index then
    -- Fallback to first position
    return context.positions[1]
  end
  
  -- Cycle through positions
  if mode == "normal" then
    local next_index = context.current_index + 1
    if next_index > #context.positions then
      next_index = 1
    end
    return context.positions[next_index]
  end
  
  return nil
end

return M
