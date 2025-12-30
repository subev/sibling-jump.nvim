-- Test fixture for leading whitespace navigation
local M = {}

function M.test()
  local a = 1
  local b = 2
  local c = 3
  
  if a > 0 then
    print("positive")
  end
  
  return a + b + c
end

return M
