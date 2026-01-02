-- Object property value navigation
-- Handles: { propName: value.method().chain() }
-- When cursor is on property name, cycles between name and closing of value

local M = {}

-- Detect if cursor is on or inside an object property whose value is a call expression
-- Returns: detected (bool), context (table or nil)
function M.detect(node, cursor_pos)
  if not node then
    return false, nil
  end
  
  -- Strategy: Walk up from any node to find a parent 'pair' node
  -- Then check if cursor is within that pair's range
  -- This allows detection from anywhere in the property (key or value)
  
  local pair_node = node
  local depth = 0
  
  -- Walk up to find the nearest pair
  while pair_node and depth < 20 do
    if pair_node:type() == "pair" then
      break
    end
    
    -- Stop at object boundaries to handle nested properties correctly
    -- If we hit an object that's itself a value of another pair, stop there
    if pair_node:type() == "object" then
      local obj_parent = pair_node:parent()
      if obj_parent and obj_parent:type() == "pair" then
        local parent_value = obj_parent:field("value")[1]
        if parent_value and parent_value:id() == pair_node:id() then
          -- This object is a property value, we're in a nested context
          -- Don't go beyond this - use the inner property context
          pair_node = nil
          break
        end
      end
    end
    
    pair_node = pair_node:parent()
    depth = depth + 1
  end
  
  -- Check if we found a valid pair
  if not pair_node or pair_node:type() ~= "pair" then
    return false, nil
  end
  
  -- Get the key and value
  local key = pair_node:child(0)  -- property name
  local value = pair_node:child(2)  -- value expression
  
  if not key or not value then
    return false, nil
  end
  
  -- Only handle if value is a call_expression (has method chains)
  if value:type() ~= "call_expression" then
    return false, nil
  end
  
  -- Now determine if cursor position should trigger property-level navigation
  -- We want to match:
  --   1. Cursor on the property key (name)
  --   2. Cursor at the beginning of the value (first identifier)
  --   3. Cursor at the end of the value (closing paren)
  -- We DON'T want to match:
  --   - Cursor in the middle of the chain (let call_expressions handle that)
  
  local cursor_row = cursor_pos[1] - 1  -- Convert to 0-indexed
  local cursor_col = cursor_pos[2]
  local key_row = key:start()
  local value_start_row, value_start_col = value:start()
  local _, _, value_end_row, value_end_col = value:range()
  
  -- Case 1: Cursor on the key line
  if cursor_row == key_row then
    return true, M.build_context(key, value)
  end
  
  -- Case 2: Cursor at the end of the value (closing paren)
  if cursor_row == value_end_row then
    local col_diff = math.abs(cursor_col - (value_end_col - 1))
    if col_diff <= 2 then
      return true, M.build_context(key, value)
    end
  end
  
  -- Case 3: Cursor at the beginning of the value
  -- Check if cursor is on the first identifier of the value
  -- We need to find the leftmost identifier in the value
  local function find_first_identifier(n)
    if not n then return nil end
    
    if n:type() == "identifier" then
      return n
    end
    
    -- For member_expressions and call_expressions, check the leftmost part
    if n:type() == "member_expression" then
      local object = n:field("object")[1]
      if object then
        return find_first_identifier(object)
      end
    elseif n:type() == "call_expression" then
      local func = n:field("function")[1]
      if func then
        return find_first_identifier(func)
      end
    end
    
    -- For other node types, check first child
    local child = n:child(0)
    if child then
      return find_first_identifier(child)
    end
    
    return nil
  end
  
  local first_id = find_first_identifier(value)
  if first_id then
    local first_row, first_col = first_id:start()
    local _, first_end_col = first_id:end_()
    
    -- Check if cursor is on the first identifier
    if cursor_row == first_row then
      -- Allow some tolerance in column (cursor can be anywhere on the identifier)
      if cursor_col >= first_col and cursor_col <= first_end_col then
        return true, M.build_context(key, value)
      end
    end
  end
  
  -- Otherwise, cursor is in the middle of the chain
  -- Let call_expressions or other handlers deal with it
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
  
  -- Cycle through positions (works in both normal and visual mode)
  local next_index = context.current_index + 1
  if next_index > #context.positions then
    next_index = 1
  end
  return context.positions[next_index]
end

return M
