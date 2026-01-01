-- Test fixture for Lua loop block-loop navigation

local M = {}

function M.test_for_loop()
  local sum = 0
  
  for i = 1, 10 do
    sum = sum + i
  end
  
  return sum
end

function M.test_while_loop()
  local count = 0
  
  while count < 10 do
    count = count + 1
  end
  
  return count
end

function M.test_for_in_loop()
  local items = {1, 2, 3, 4, 5}
  local result = {}
  
  for i, value in ipairs(items) do
    result[i] = value * 2
  end
  
  return result
end

return M
