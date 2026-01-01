-- Method chain navigation for sibling-jump.nvim
-- Handles navigation through chained method calls like obj.foo().bar().baz()

local M = {}

-- Detect if we're on a method call in a chain (e.g., obj.foo().bar().baz())
-- Returns: in_chain (boolean), property_node (the property_identifier node)
function M.detect(node)
  -- Walk up from cursor to find if we're on/in a property_identifier
  local current = node
  local depth = 0
  while current and depth < 10 do
    if current:type() == "property_identifier" then
      break
    end
    -- Stop if we've gone too far up
    if current:type() == "statement_block" or current:type() == "program" then
      return false
    end
    current = current:parent()
    depth = depth + 1
  end

  if not current or current:type() ~= "property_identifier" then
    return false
  end

  -- Structure for a method call in a chain:
  -- property_identifier (method name like "bar")
  --   └─ member_expression (the .bar part)
  --       └─ call_expression (the .bar() call)
  --           └─ member_expression (container for next method)
  --               └─ call_expression (previous .foo() in chain)

  local property_node = current
  local member_expr = property_node:parent()
  if not member_expr or member_expr:type() ~= "member_expression" then
    return false
  end

  -- Check that this member_expression is the function being called
  -- (child[0] of a call_expression)
  local call_expr = member_expr:parent()
  if not call_expr or call_expr:type() ~= "call_expression" then
    return false
  end

  -- Verify the member_expression is the function part (child[0])
  if call_expr:child(0) ~= member_expr then
    return false
  end

  -- Now check if this call is part of a chain
  -- A method call is in a chain if:
  -- 1. Its parent is a member_expression (there's a method call after it), OR
  -- 2. The object being called on is itself a call_expression (there's a method call before it)

  local has_next = call_expr:parent() and call_expr:parent():type() == "member_expression"

  local member_object = call_expr:child(0) -- The .method part
  local has_prev = false
  if member_object and member_object:type() == "member_expression" then
    local obj = member_object:child(0) -- The object before the dot
    has_prev = obj and obj:type() == "call_expression"
  end

  -- It's a chain if there's a next or previous method call
  if has_next or has_prev then
    return true, property_node
  end

  return false
end

-- Navigate forward/backward in a method chain
-- Returns: the property_identifier node of the target method, or nil
function M.navigate(property_node, forward)
  local member_expr = property_node:parent()
  local call_expr = member_expr:parent()

  if forward then
    -- Navigate DOWN the chain: .bar() → .baz()
    -- Structure: call_expression (.bar())
    --              └─ parent: member_expression (.baz container)
    --                  └─ child[2]: property_identifier (baz)
    local next_member = call_expr:parent()
    if next_member and next_member:type() == "member_expression" then
      local next_prop = next_member:child(2) -- child[0] = call, child[1] = ".", child[2] = property
      if next_prop and next_prop:type() == "property_identifier" then
        return next_prop
      end
    end
  else
    -- Navigate UP the chain: .baz() → .bar()
    -- Structure: call_expression (.baz())
    --              └─ child[0]: member_expression (.baz)
    --                  └─ child[0]: call_expression (.bar())
    --                      └─ child[0]: member_expression (.bar)
    --                          └─ child[2]: property_identifier (bar)
    local current_member = call_expr:child(0) -- .baz member expression
    if current_member and current_member:type() == "member_expression" then
      local prev_call = current_member:child(0) -- .bar() call
      if prev_call and prev_call:type() == "call_expression" then
        local prev_member = prev_call:child(0) -- .bar member expression
        if prev_member and prev_member:type() == "member_expression" then
          local prev_prop = prev_member:child(2) -- bar identifier
          if prev_prop and prev_prop:type() == "property_identifier" then
            return prev_prop
          end
        end
      end
    end
  end

  return nil
end

return M
