-- Fixture for Lua block-loop cycles and nested if/elseif chains
local M = {}

local function navigate(target)
  if not target then return nil end
  return target, target:start()
end

local function dispatch(mode, ctx1, ctx2, forward)
  local target_node, target_row, target_col
  if ctx2 ~= nil then
    target_node, target_row, target_col = mode.navigate(ctx1, ctx2, forward)
  else
    target_node, target_row, target_col = mode.navigate(ctx1, forward)
  end
  return target_node, target_row, target_col
end

function M.find_property(current)
  if current:type() == "property_identifier" then
    local parent = current:parent()
    if parent and parent:type() == "pair" then
      local grandparent = parent:parent()
      if grandparent and grandparent:type() == "object" then
        return parent, grandparent
      end
    elseif parent and parent:type() == "property_signature" then
      local grandparent = parent:parent()
      if grandparent and grandparent:type() == "object_type" then
        return parent, grandparent
      end
    end
  end
  return nil
end

return M
