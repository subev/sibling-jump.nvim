-- Switch case navigation for sibling-jump.nvim
-- Handles navigation through switch statement cases

local utils = require("sibling_jump.utils")

local M = {}

-- Collect all case/default clauses in a switch statement
-- Returns: list of switch_case/switch_default nodes (in order from first to last)
local function collect_switch_cases(switch_node)
  local cases = {}

  if not switch_node or switch_node:type() ~= "switch_statement" then
    return cases
  end

  -- Find the switch_body child
  local switch_body = nil
  for i = 0, switch_node:child_count() - 1 do
    local child = switch_node:child(i)
    if child:type() == "switch_body" then
      switch_body = child
      break
    end
  end

  if not switch_body then
    return cases
  end

  -- Collect all switch_case and switch_default children
  for i = 0, switch_body:child_count() - 1 do
    local child = switch_body:child(i)
    if child:type() == "switch_case" or child:type() == "switch_default" then
      table.insert(cases, child)
    end
  end

  return cases
end

-- Get position of 'case' or 'default' keyword within switch case
-- Returns: row, col (pointing to 'c' of 'case' or 'd' of 'default')
local function get_case_keyword_position(case_node)
  if not case_node then
    return nil, nil
  end

  local node_type = case_node:type()
  if node_type ~= "switch_case" and node_type ~= "switch_default" then
    return nil, nil
  end

  -- For switch_case, find the 'case' keyword child
  -- For switch_default, find the 'default' keyword child
  local keyword = node_type == "switch_case" and "case" or "default"

  for i = 0, case_node:child_count() - 1 do
    local child = case_node:child(i)
    if child:type() == keyword then
      return child:start()
    end
  end

  -- Fallback to case node start position
  return case_node:start()
end

-- Detect if we're on a case/default clause in a switch statement
-- Returns: in_switch (boolean), switch_statement_node, current_position_index (1-based)
-- current_position_index: 1 = first case, 2 = second case, etc.
function M.detect(node)
  if not node then
    return false, nil, 0
  end

  -- FIRST: Check if we're inside a higher-priority navigation context
  -- These contexts take precedence over switch case navigation
  local test_node = node
  while test_node do
    local node_type = test_node:type()

    -- If we're inside an object literal, prefer object property navigation
    if node_type == "object" or node_type == "object_type" then
      return false, nil, 0
    end

    -- If we're inside an array, prefer array element navigation
    if node_type == "array" then
      return false, nil, 0
    end

    -- If we're inside function parameters/arguments, prefer parameter navigation
    if node_type == "arguments" or node_type == "formal_parameters" then
      return false, nil, 0
    end

    if utils.is_meaningful_node(test_node) then
      local test_parent = test_node:parent()

      -- Check if parent is statement_block (for block-scoped cases)
      if test_parent and test_parent:type() == "statement_block" then
        -- Count meaningful children in the statement block
        local meaningful_count = 0
        for child in test_parent:iter_children() do
          if utils.is_meaningful_node(child) then
            meaningful_count = meaningful_count + 1
          end
        end
        -- If there are multiple meaningful statements, prefer statement navigation
        if meaningful_count > 1 then
          return false, nil, 0
        end
      end

      -- Check if parent is switch_case/switch_default (for non-block cases)
      if test_parent and (test_parent:type() == "switch_case" or test_parent:type() == "switch_default") then
        -- Count meaningful statement children in the case
        local meaningful_count = 0
        for child in test_parent:iter_children() do
          if utils.is_meaningful_node(child) then
            meaningful_count = meaningful_count + 1
          end
        end
        -- If there are multiple meaningful statements in the case, prefer statement navigation
        if meaningful_count > 1 then
          return false, nil, 0
        else
          -- Single statement in case - no-op (don't navigate to sibling cases)
          return false, nil, 0
        end
      end
    end
    test_node = test_node:parent()

    -- Stop if we've reached a switch_case or switch_default
    if test_node and (test_node:type() == "switch_case" or test_node:type() == "switch_default") then
      break
    end
  end

  -- Walk up to find switch_case, switch_default, or switch_statement
  local current = node
  local depth = 0
  local found_case = nil
  local found_switch = nil

  while current and depth < 20 do
    if current:type() == "switch_case" or current:type() == "switch_default" then
      found_case = current
      -- Continue walking up to find the switch_statement
      current = current:parent()
      depth = depth + 1
    elseif current:type() == "switch_body" then
      -- Keep walking up to find switch_statement
      current = current:parent()
      depth = depth + 1
    elseif current:type() == "switch_statement" then
      found_switch = current
      break
    else
      current = current:parent()
      depth = depth + 1
    end

    -- Stop if we've gone too far up
    if current and (current:type() == "statement_block" or current:type() == "program") then
      break
    end
  end

  if not found_switch or not found_case then
    return false, nil, 0
  end

  -- Get all cases and find the index of the current case
  local cases = collect_switch_cases(found_switch)
  if #cases == 0 then
    return false, nil, 0
  end

  -- Find which case we're in by comparing positions
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor[1] - 1 -- Convert to 0-indexed

  for i, case_node in ipairs(cases) do
    local case_start_row = case_node:start()
    local case_end_row = select(3, case_node:range())

    if cursor_row >= case_start_row and cursor_row <= case_end_row then
      return true, found_switch, i
    end
  end

  return false, nil, 0
end

-- Navigate forward/backward in a switch case chain
-- Returns: target case node, target_row, target_col, or nil
function M.navigate(switch_node, current_pos, forward)
  local cases = collect_switch_cases(switch_node)

  if #cases == 0 then
    return nil, nil, nil
  end

  if forward then
    -- Forward navigation: case 1 → case 2 → ... → case N → no-op
    if current_pos < #cases then
      local next_case = cases[current_pos + 1]
      local target_row, target_col = get_case_keyword_position(next_case)
      return next_case, target_row, target_col
    else
      -- At last case, no-op
      return nil, nil, nil
    end
  else
    -- Backward navigation: case N → ... → case 2 → case 1 → no-op
    if current_pos > 1 then
      local prev_case = cases[current_pos - 1]
      local target_row, target_col = get_case_keyword_position(prev_case)
      return prev_case, target_row, target_col
    else
      -- At first case, no-op
      return nil, nil, nil
    end
  end
end

-- Get the entry point when navigating INTO a switch_statement from outside
-- This determines where the cursor should land when jumping TO a switch structure
-- Returns: target_node, target_row, target_col
function M.get_entry_point(switch_node, forward)
  if forward then
    -- Forward: land on the 'switch' keyword
    return switch_node, switch_node:start()
  end
  
  -- Backward: land on the last case/default
  local cases = collect_switch_cases(switch_node)
  
  if #cases > 0 then
    local last_case = cases[#cases]
    local target_row, target_col = get_case_keyword_position(last_case)
    return last_case, target_row, target_col
  end
  
  -- No cases found, return the switch_node itself
  return switch_node, switch_node:start()
end

return M
