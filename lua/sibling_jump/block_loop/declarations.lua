-- Declaration with value detection and navigation
-- Handles: const/let/var SOMETHING = VALUE
-- Where VALUE can be: object literal, array literal, function call, arrow function, etc.
-- Also handles: function foo() {} and class methods

local utils = require("sibling_jump.block_loop.utils")

local M = {}

-- Detect if cursor is on a declaration with a value
-- Returns: detected (bool), context (table or nil)
function M.detect(node, cursor_pos)
  if not node then
    return false, nil
  end

  -- Check if we're on 'export' keyword - if so, look inside export_statement
  if node:type() == "export" then
    local export_stmt = node:parent()
    if export_stmt and export_stmt:type() == "export_statement" then
      -- Find the declaration field inside export_statement
      for i = 0, export_stmt:child_count() - 1 do
        local child = export_stmt:child(i)
        if child:type() == "lexical_declaration" or child:type() == "variable_declaration" then
          local value = M.find_value_in_declaration(child)
          if value then
            -- Use export_statement for context so first position is 'export' not 'const'
            local context = M.build_context(export_stmt, value)
            -- Check if cursor is on any boundary position
            for _, pos in ipairs(context.positions) do
              if pos.row == cursor_pos[1] then
                return true, context
              end
            end
          end
        end
      end
    end
  end

  -- Try to find lexical_declaration or variable_declaration
  local decl = utils.find_ancestor(node, { "lexical_declaration", "variable_declaration" })

  if decl then
    local value = M.find_value_in_declaration(decl)

    if value then
      local context = M.build_context(decl, value)

      -- Check if cursor is on any boundary position
      for _, pos in ipairs(context.positions) do
        if pos.row == cursor_pos[1] then
          return true, context
        end
      end
    end
  end

  -- Check for type declarations: type Foo = { ... }
  local type_decl = utils.find_ancestor(node, { "type_alias_declaration" })

  if type_decl then
    local value = M.find_value_in_type_declaration(type_decl)

    if value then
      local context = M.build_context_for_type(type_decl, value)

      -- Check if cursor is on any boundary position
      for _, pos in ipairs(context.positions) do
        if pos.row == cursor_pos[1] then
          return true, context
        end
      end
    end
  end

  -- Also check for standalone function declarations: function foo() {}
  local func_node = utils.find_ancestor(node, { "function_declaration", "method_definition" })

  if func_node then
    local context = M.build_context_for_function(func_node)

    -- Check if cursor is on any boundary position
    for _, pos in ipairs(context.positions) do
      if pos.row == cursor_pos[1] then
        return true, context
      end
    end
  end

  return false, nil
end

-- Find the value (right-hand side) in a declaration
-- For TypeScript/JavaScript: const foo = VALUE;
-- For Lua: local foo = VALUE
function M.find_value_in_declaration(decl_node)
  -- Check for Lua assignment_statement first
  local assignment_stmt = nil
  for i = 0, decl_node:child_count() - 1 do
    local child = decl_node:child(i)
    if child:type() == "assignment_statement" then
      assignment_stmt = child
      break
    end
  end

  if assignment_stmt then
    -- Lua: assignment_statement -> expression_list (the value)
    for i = 0, assignment_stmt:child_count() - 1 do
      local child = assignment_stmt:child(i)
      if child:type() == "expression_list" then
        -- Get the first expression in the list
        local first_expr = child:child(0)
        return first_expr
      end
    end
    return nil
  end

  -- TypeScript/JavaScript: lexical_declaration -> variable_declarator -> [identifier, =, VALUE]
  local var_declarator = nil
  for i = 0, decl_node:child_count() - 1 do
    local child = decl_node:child(i)
    if child:type() == "variable_declarator" then
      var_declarator = child
      break
    end
  end

  if not var_declarator then
    return nil
  end

  -- The value is typically at index 2 (after identifier at 0, = at 1)
  -- But let's be safe and find the last substantial child
  for i = var_declarator:child_count() - 1, 0, -1 do
    local child = var_declarator:child(i)
    local child_type = child:type()

    -- Skip punctuation - we want the actual value
    if child_type ~= ";" and child_type ~= "=" and child_type ~= "identifier" then
      return child
    end
  end

  return nil
end

-- Build context with positions for declarations
function M.build_context(decl_node, value_node)
  local positions = {}

  -- Position 0: Declaration keyword (const/let/var)
  local start_row, start_col = decl_node:start()
  table.insert(positions, {
    row = start_row + 1,
    col = start_col,
    type = "declaration_keyword",
  })

  -- Position 1: End of value (closing bracket/brace/paren)
  -- Adjust end_col to be inside the closing bracket (one position before the range end)
  -- This ensures we land on ')' not on ';' after it
  local _, _, end_row, end_col = value_node:range()
  local closing_col = end_col > 0 and (end_col - 1) or 0
  table.insert(positions, {
    row = end_row + 1,
    col = closing_col,
    type = "closing_bracket",
  })

  return {
    positions = positions,
    node = decl_node,
  }
end

-- Build context for standalone function declarations
function M.build_context_for_function(func_node)
  local positions = {}

  -- Position 0: 'function' keyword or method name
  local start_row, start_col = func_node:start()
  table.insert(positions, {
    row = start_row + 1,
    col = start_col,
    type = "function_keyword",
  })

  -- Position 1: Closing bracket/end of function
  -- For Lua functions, check if last child is 'end' keyword
  local last_child = func_node:child(func_node:child_count() - 1)
  if last_child and last_child:type() == "end" then
    -- Lua function: use the 'end' keyword position
    local end_row, end_col = last_child:start()
    table.insert(positions, {
      row = end_row + 1,
      col = end_col,
      type = "closing_bracket",
    })
  else
    -- JavaScript/TypeScript function: use statement_block end
    local body = M.find_statement_block(func_node)
    if body then
      local _, _, end_row, end_col = body:range()
      local closing_col = end_col > 0 and (end_col - 1) or 0
      table.insert(positions, {
        row = end_row + 1,
        col = closing_col,
        type = "closing_bracket",
      })
    else
      -- Fallback: use function node's end
      local _, _, end_row, end_col = func_node:range()
      local closing_col = end_col > 0 and (end_col - 1) or 0
      table.insert(positions, {
        row = end_row + 1,
        col = closing_col,
        type = "closing_bracket",
      })
    end
  end

  return {
    positions = positions,
    node = func_node,
  }
end

-- Helper to find statement_block in a node
-- Handles both TypeScript/JavaScript (statement_block) and Lua (block)
function M.find_statement_block(node)
  for i = 0, node:child_count() - 1 do
    local child = node:child(i)
    if child:type() == "statement_block" or child:type() == "block" then
      return child
    end
  end
  return nil
end

-- Find the value (right-hand side) in a type declaration
-- For: type Foo = VALUE;
-- Structure: type_alias_declaration
--   [0] "type" keyword
--   [1] type_identifier (name)
--   [2] "="
--   [3] VALUE (object_type | intersection_type | union_type | ...)
--   [4] ";"
function M.find_value_in_type_declaration(type_decl)
  -- The value is at index 3 (after type, identifier, =)
  local value = type_decl:child(3)

  if value and value:type() ~= ";" then
    return value
  end

  return nil
end

-- Build context for type declarations
function M.build_context_for_type(type_decl, value_node)
  local positions = {}

  -- Position 0: 'type' keyword
  local start_row, start_col = type_decl:start()
  table.insert(positions, {
    row = start_row + 1,
    col = start_col,
    type = "type_keyword",
  })

  -- Position 1: End of value (closing bracket/brace)
  -- Adjust end_col to be inside the closing bracket
  local _, _, end_row, end_col = value_node:range()
  local closing_col = end_col > 0 and (end_col - 1) or 0
  table.insert(positions, {
    row = end_row + 1,
    col = closing_col,
    type = "closing_bracket",
  })

  return {
    positions = positions,
    node = type_decl,
  }
end

-- Navigate to next position in cycle
function M.navigate(context, cursor_pos, mode)
  local positions = context.positions
  local current_row = cursor_pos[1]
  local current_col = cursor_pos[2]

  -- Find if cursor is on or very close to a boundary position
  -- "Close" means within 2 columns (to handle cursor on different parts of same token)
  local CLOSE_THRESHOLD = 2
  local on_boundary = nil

  for i, pos in ipairs(positions) do
    if pos.row == current_row then
      local col_diff = math.abs(pos.col - current_col)
      if col_diff <= CLOSE_THRESHOLD then
        on_boundary = i
        break
      end
    end
  end

  if on_boundary then
    -- Cursor is on a boundary - cycle to next position
    local next_index = (on_boundary % #positions) + 1
    return positions[next_index]
  else
    -- Cursor is NOT on a boundary (somewhere in middle of the declaration)
    -- Jump to the first position (the keyword: local/const/let/var/function/type)
    return positions[1]
  end
end

return M
