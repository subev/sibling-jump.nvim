-- Navigation module for sibling-jump.nvim
-- Handles finding and navigating between sibling nodes

local utils = require("sibling_jump.utils")

local M = {}

-- Get all non-skippable children of a parent node
function M.get_sibling_nodes(parent)
  if not parent then
    return {}
  end

  local parent_type = parent:type()

  local siblings = {}
  for child in parent:iter_children() do
    if not utils.is_skippable_node(child) then
      -- Skip identifier nodes that are JSX tag names (direct children of jsx elements)
      local skip_jsx_identifier = child:type() == "identifier"
        and (
          parent_type == "jsx_element"
          or parent_type == "jsx_self_closing_element"
          or parent_type == "jsx_opening_element"
        )

      if not skip_jsx_identifier then
        table.insert(siblings, child)
      end
    end
  end

  return siblings
end

-- Find next/prev sibling node
-- members: optional explicit list to navigate (node_finder supplies it); defaults to parent's children
function M.get_sibling_node(node, parent, forward, members)
  if not node or not parent then
    return nil
  end

  local siblings = members or M.get_sibling_nodes(parent)
  if #siblings == 0 then
    return nil
  end

  local current_index = utils.find_node_index(node, siblings)
  -- A member list holds one node per line; the unit may be a smaller node on the same line
  if not current_index and members then
    local node_row = node:start()
    for i, member in ipairs(members) do
      if member:start() == node_row then
        current_index = i
        break
      end
    end
  end
  if not current_index then
    return nil
  end

  local next_index = forward and (current_index + 1) or (current_index - 1)

  return siblings[next_index]
end

return M
