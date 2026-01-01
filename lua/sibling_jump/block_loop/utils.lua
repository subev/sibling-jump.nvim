-- Shared utilities for block_loop handlers

local M = {}

-- Walk up AST to find a node of specific type(s)
-- max_depth: how many parent levels to check (default 20)
function M.find_ancestor(node, node_types, max_depth)
  max_depth = max_depth or 20
  local current = node
  local depth = 0
  
  while current and depth < max_depth do
    local node_type = current:type()
    
    for _, target_type in ipairs(node_types) do
      if node_type == target_type then
        return current
      end
    end
    
    current = current:parent()
    depth = depth + 1
  end
  
  return nil
end

-- Check if cursor is on a specific node's start line
function M.is_cursor_on_node_line(cursor_row, node)
  local node_row, _ = node:start()
  return cursor_row == node_row + 1  -- Convert to 1-indexed
end

-- Find child node by type
function M.find_child_by_type(parent, node_type)
  for i = 0, parent:child_count() - 1 do
    local child = parent:child(i)
    if child:type() == node_type then
      return child
    end
  end
  return nil
end

-- Get all children of specific type
function M.get_children_by_type(parent, node_type)
  local children = {}
  for i = 0, parent:child_count() - 1 do
    local child = parent:child(i)
    if child:type() == node_type then
      table.insert(children, child)
    end
  end
  return children
end

-- Find closest position to cursor in positions list
function M.find_closest_position_index(positions, cursor_row)
  local closest_index = 1
  local min_distance = math.abs(positions[1].row - cursor_row)
  
  for i, pos in ipairs(positions) do
    local distance = math.abs(pos.row - cursor_row)
    if distance < min_distance then
      min_distance = distance
      closest_index = i
    end
  end
  
  return closest_index
end

return M
