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

function M.test_labels()
  for i = 1, 10 do
    local x = i * 2
    if x > 10 then
      goto continue
    end
    print(x)
    ::continue::
  end
  return true
end

return M
