-- Test fixture for Lua if-else-elseif chain navigation
local M = {}

function M.test_if_else_chain()
  local x = 10
  
  if x > 20 then
    print("greater than 20")
  elseif x > 10 then
    print("greater than 10")
  elseif x > 5 then
    print("greater than 5")
  else
    print("5 or less")
  end
  
  return x
end

function M.test_simple_if_else()
  local y = 5
  
  if y > 0 then
    print("positive")
  else
    print("not positive")
  end
  
  return y
end

return M
