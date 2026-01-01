-- Positioning module for sibling-jump.nvim
-- Handles cursor position adjustments for different node types

local M = {}

-- Adjust cursor position for JSX elements to land on tag name instead of '<'
function M.get_target_position(node)
  local node_type = node:type()

  -- For jsx_self_closing_element: <Button />
  -- Structure: < [identifier] [attributes...] />
  if node_type == "jsx_self_closing_element" then
    local identifier = node:child(1) -- child[0] is '<', child[1] is identifier
    if identifier and identifier:type() == "identifier" then
      return identifier:start()
    end
  end

  -- For jsx_element: <Button>...</Button>
  -- Structure: [jsx_opening_element] [children...] [jsx_closing_element]
  if node_type == "jsx_element" then
    local opening_element = node:child(0)
    if opening_element and opening_element:type() == "jsx_opening_element" then
      -- jsx_opening_element structure: < [identifier] [attributes...] >
      local identifier = opening_element:child(1) -- child[0] is '<', child[1] is identifier
      if identifier and identifier:type() == "identifier" then
        return identifier:start()
      end
    end
  end

  -- For non-JSX nodes, return the original start position
  return node:start()
end

return M
