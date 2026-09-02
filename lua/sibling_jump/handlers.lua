-- Navigation handlers for different contexts
-- Reduces cyclomatic complexity by extracting special case logic

local node_finder = require("sibling_jump.node_finder")

local M = {}

-- Handle the whitespace/comment markers returned by node_finder
-- Returns: nil (not a marker), "no_op" (marker without a target), or { row, col }
function M.handle_marker(current_node, forward, positioning)
  if type(current_node) ~= "table" or not (current_node._on_whitespace or current_node._on_comment) then
    return nil
  end

  local target_node = forward and current_node.closest_after or current_node.closest_before
  if not target_node then
    return "no_op"
  end

  local target_row, target_col = positioning.get_target_position(target_node)
  return { row = target_row, col = target_col }
end

local function is_inside(node, ancestor)
  local check = node
  while check do
    if check == ancestor then
      return true
    end
    check = check:parent()
  end
  return false
end

-- Handle entry point adjustment for compound statements
-- Backward jumps land on the last clause of an if/switch we are entering from outside
function M.adjust_entry_point(target_node, forward, node, if_else_chains, switch_cases)
  if forward or is_inside(node, target_node) then
    return target_node, nil, nil
  end

  local entry_points = {
    if_statement = if_else_chains.get_entry_point,
    switch_statement = switch_cases.get_entry_point,
  }
  local get_entry_point = entry_points[target_node:type()]
  if not get_entry_point then
    -- A statement that continues over `.modifier()` lines is entered at its last line,
    -- mirroring the forward walk through those lines
    local lines = node_finder.chain_lines(target_node)
    if #lines > 1 then
      local last = lines[#lines]
      return last, last:start()
    end
    return target_node, nil, nil
  end

  local entry_node, entry_row, entry_col = get_entry_point(target_node, forward)
  if entry_node == target_node then
    return target_node, nil, nil
  end
  return entry_node, entry_row, entry_col
end

return M
