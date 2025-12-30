-- Test fixture for basic Lua statement navigation
local M = {}

function M.test()
  local a = 1
  local b = 2
  local c = 3
  
  if a > 0 then
    print("positive")
  end
  
  for i = 1, 10 do
    print(i)
  end
  
  return a + b + c
end

return M
