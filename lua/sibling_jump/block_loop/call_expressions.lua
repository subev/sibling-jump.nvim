-- Call expression boundary navigation
-- Handles method calls and function calls: foo.bar(...) or bar(...)
-- Also handles await expressions: await foo() or await foo.bar()
-- When cursor is on a method/function name or await keyword, cycles between the start and closing paren

local M = {}

-- Detect if cursor is on a call expression
-- Returns: detected (bool), context (table or nil)
function M.detect(node, cursor_pos)
  if not node then
    return false, nil
  end

  local current = node

  -- Case 1: Cursor on 'await' keyword
  if current:type() == "await" then
    local parent = current:parent()
    if parent and parent:type() == "await_expression" then
      -- Find the call_expression inside the await_expression
      local call_expr = M.find_call_in_await(parent)
      if call_expr then
        local await_row = current:start()
        if await_row == cursor_pos[1] - 1 then
          local context = M.build_context(call_expr, current, parent)
          return true, context
        end
      end
    end
  end

  -- Case 2: Cursor on method/function name (property_identifier or identifier)
  if current:type() == "property_identifier" or current:type() == "identifier" then
    -- Walk up to find if this is part of a call_expression (JS/TS)
    -- This handles nested member expressions like analytics.foo.capture()
    local call_expr, await_expr = M.find_parent_call_expression(current)

    if call_expr then
      -- Check if cursor is on the node's line
      local node_row = current:start()
      -- cursor_pos[1] is 1-indexed, node_row is 0-indexed
      if node_row == cursor_pos[1] - 1 then
        -- Use the current node as the start position
        local context = M.build_context(call_expr, current, await_expr)
        return true, context
      end
    end
    
    -- Case 2b: Lua - cursor on identifier that's the start of a function_call chain
    -- e.g., cursor on 'vim' in 'vim.keymap.set(...)'
    -- or cursor on 'table' in 'table:insert(...)'
    if current:type() == "identifier" then
      local lua_call = M.find_lua_function_call(current)
      if lua_call then
        -- Check if this function_call is inside a variable_declaration
        -- If so, skip so declarations handler takes over (consistent local ↔ closing paren navigation)
        local is_in_var_decl = M.is_lua_call_in_variable_declaration(lua_call)
        if not is_in_var_decl then
          local node_row = current:start()
          if node_row == cursor_pos[1] - 1 then
            local context = M.build_context(lua_call, current, nil)
            return true, context
          end
        end
      end
    end
  end

  -- Case 3: Cursor on closing paren/bracket - walk up to find call_expression or function_call
  -- This handles the case when cycling back from the closing position
  local parent = current:parent()
  while parent do
    if parent:type() == "call_expression" or parent:type() == "function_call" then
      local _, _, end_row, end_col = parent:range()
      -- Check if cursor is on the ending line of this call_expression
      if end_row == cursor_pos[1] - 1 then
        -- Skip if this is a simple call directly assigned to a variable: const x = foo()
        -- But allow method chains: const x = obj.method()
        local grandparent = parent:parent()
        
        -- TypeScript/JavaScript: call_expression -> variable_declarator
        if grandparent and grandparent:type() == "variable_declarator" then
          -- Check if this is a simple call (first child is identifier) vs method chain (first child is member_expression)
          local first_child = parent:child(0)
          if first_child and first_child:type() == "identifier" then
            -- Simple call: const x = foo()
            -- Skip it and let declarations handler deal with it
            parent = grandparent:parent()
            goto continue
          end
          -- Otherwise it's a method chain, allow call_expressions handler to process it
        end
        
        -- Lua: function_call -> expression_list -> assignment_statement -> variable_declaration
        if grandparent and grandparent:type() == "expression_list" then
          local assignment = grandparent:parent()
          if assignment and assignment:type() == "assignment_statement" then
            local var_decl = assignment:parent()
            if var_decl and var_decl:type() == "variable_declaration" then
              -- This is a Lua declaration like: local x = foo() or local x = obj.method()
              -- Skip ALL calls inside variable_declaration so declarations handler takes over
              -- This ensures consistent navigation: local ↔ closing paren
              parent = var_decl:parent()
              goto continue
            end
          end
        end
        
        -- Check if this call is wrapped in await_expression
        local await_expr = grandparent
        if await_expr and await_expr:type() ~= "await_expression" then
          await_expr = nil
        end

        -- Find the name node for this call
        local name_node = M.find_name_node_for_call(parent, await_expr)
        if name_node then
          local context = M.build_context(parent, name_node, await_expr)
          return true, context
        end
      end
    end
    ::continue::
    parent = parent:parent()
  end

  return false, nil
end

-- Find parent call_expression for a node
-- Must be a direct function name, not nested inside arguments
-- Returns: call_expression, await_expression (or nil if not awaited)
function M.find_parent_call_expression(node)
  local current = node

  -- Walk up through property_identifier -> member_expression -> ... -> call_expression
  -- Keep walking up through nested member_expressions (e.g., analytics.foo.capture)
  while current do
    local parent = current:parent()
    if not parent then
      break
    end

    local parent_type = parent:type()

    -- If we're at member_expression, check if parent is call_expression
    -- Also continue walking up if parent is another member_expression (nested chains)
    if current:type() == "member_expression" then
      if parent_type == "call_expression" then
        -- Found it! Check if this member_expression is the function being called
        local func_node = parent:field("function")[1]
        if func_node and func_node:id() == current:id() then
          -- Check if call is wrapped in await_expression
          local await_expr = parent:parent()
          if await_expr and await_expr:type() == "await_expression" then
            return parent, await_expr
          end
          return parent, nil
        end
      elseif parent_type == "member_expression" then
        -- Continue walking up through nested member expressions
        current = parent
      else
        break
      end
    -- If we're at identifier and parent is call_expression
    elseif current:type() == "identifier" and parent_type == "call_expression" then
      -- Make sure this identifier is the function, not an argument
      local func_node = parent:field("function")[1]
      if func_node and func_node:id() == current:id() then
        -- Check if call is wrapped in await_expression
        local await_expr = parent:parent()
        if await_expr and await_expr:type() == "await_expression" then
          return parent, await_expr
        end
        return parent, nil
      end
      break
    -- If we're at identifier and parent is member_expression, continue walking up
    elseif current:type() == "identifier" and parent_type == "member_expression" then
      -- Check if the identifier is the object part of the member expression
      local object = parent:field("object")[1]
      if object and object:id() == current:id() then
        -- Continue walking up from the member_expression
        current = parent
      else
        break
      end
    -- If we're at property_identifier, go to member_expression first
    elseif current:type() == "property_identifier" and parent_type == "member_expression" then
      current = parent
    else
      break
    end
  end

  return nil, nil
end

-- Find call_expression inside an await_expression
function M.find_call_in_await(await_expr)
  for child in await_expr:iter_children() do
    if child:type() == "call_expression" then
      return child
    end
  end
  return nil
end

-- Find the name node to use for navigation
-- For await expressions, returns the await keyword
-- For member expressions, returns the property_identifier (method name)
-- For simple calls, returns the identifier
-- For Lua function_call, returns the leftmost identifier
function M.find_name_node_for_call(call_expr, await_expr)
  if await_expr then
    -- Return the await keyword
    for child in await_expr:iter_children() do
      if child:type() == "await" then
        return child
      end
    end
  end

  -- For Lua function_call, find the leftmost identifier
  if call_expr:type() == "function_call" then
    -- The function name is in the "name" field or first child
    local func_name = call_expr:field("name")[1]
    if not func_name then
      func_name = call_expr:child(0)
    end
    
    if func_name then
      return M.find_leftmost_identifier(func_name)
    end
  end

  -- For JS/TS call_expression, find the function name
  local func = call_expr:field("function")[1]
  if func and func:type() == "member_expression" then
    -- For member expressions, use the property (method name)
    -- This preserves the behavior for method chains: .refine() -> 'refine', not the object
    local prop = func:field("property")[1]
    if prop then
      return prop
    end
  elseif func and func:type() == "identifier" then
    return func
  end

  return nil
end

-- Build context with positions
-- name_node: the node to use as the start position (await keyword, function name, or property)
-- await_expr: the await_expression wrapping the call (if any)
function M.build_context(call_expr, name_node, await_expr)
  -- Determine the end position (closing paren)
  -- If awaited, use the await_expression end, otherwise use call_expression end
  local end_node = await_expr or call_expr
  local _, _, end_row, end_col = end_node:range()

  -- Get the start position (await keyword, method name, or function name)
  local name_row, name_col = name_node:start()

  -- Adjust end_col to be inside the closing paren (one position before the range end)
  -- This ensures we land on ')' not on ';' after it
  local closing_col = end_col > 0 and (end_col - 1) or 0

  return {
    node = call_expr,
    await_node = await_expr,
    positions = {
      { row = name_row + 1, col = name_col }, -- Start position (1-indexed)
      { row = end_row + 1, col = closing_col }, -- Closing paren (1-indexed, adjusted)
    },
    current_index = nil, -- Will be set during navigation
  }
end

-- Navigate between boundaries
function M.navigate(context, cursor_pos, mode)
  -- Find current position index
  -- Check end position first (exact match), then start position (flexible match)
  -- This ensures we correctly detect when cursor is on closing paren vs start

  -- First pass: Check for exact or near-exact matches (prioritize end position)
  for i = #context.positions, 1, -1 do
    local pos = context.positions[i]
    if pos.row == cursor_pos[1] then
      local col_diff = math.abs(pos.col - cursor_pos[2])
      if col_diff <= 2 then
        context.current_index = i
        break
      end
    end
  end

  -- Second pass: If no exact match, check start position with flexible matching
  if not context.current_index then
    local pos = context.positions[1]
    if pos.row == cursor_pos[1] then
      local col_diff = math.abs(pos.col - cursor_pos[2])
      -- Flexible matching for start position (handles "analytics" vs "capture")
      if col_diff <= 15 then
        context.current_index = 1
      end
    end
  end

  if not context.current_index then
    -- Couldn't determine position, default to jumping to closing paren
    return context.positions[#context.positions]
  end

  -- Cycle through positions (works in both normal and visual mode)
  local next_index = context.current_index + 1
  if next_index > #context.positions then
    next_index = 1
  end
  return context.positions[next_index]
end

-- ============================================================================
-- LUA SUPPORT FUNCTIONS
-- ============================================================================

-- Check if ancestor contains descendant
function M.node_contains(ancestor, descendant)
  if not ancestor or not descendant then return false end
  if ancestor == descendant then return true end
  
  local current = descendant
  while current do
    if current == ancestor then return true end
    current = current:parent()
  end
  return false
end

-- Find the leftmost identifier in a Lua chain
-- e.g., for 'vim.keymap.set', returns 'vim' node
-- e.g., for 'table:insert', returns 'table' node
function M.find_leftmost_identifier(node)
  if not node then return nil end
  
  if node:type() == "identifier" then
    return node
  end
  
  if node:type() == "dot_index_expression" 
      or node:type() == "method_index_expression" then
    -- First child is the object/table
    local first = node:child(0)
    return M.find_leftmost_identifier(first)
  end
  
  -- For other node types, try to find identifier children
  for child in node:iter_children() do
    local id = M.find_leftmost_identifier(child)
    if id then return id end
  end
  
  return nil
end

-- Find a Lua function_call that this node is part of
-- Walks up through dot_index_expression and method_index_expression chains
-- Returns: function_call node or nil
function M.find_lua_function_call(node)
  local current = node
  local depth = 0
  
  while current and depth < 20 do
    local parent = current:parent()
    if not parent then break end
    
    if parent:type() == "function_call" then
      -- Verify this node is the "function" part, not an argument
      -- In Lua, the function part is typically the first child (name field)
      local func_node = parent:field("name")[1]
      if not func_node then
        func_node = parent:child(0)
      end
      
      if func_node and M.node_contains(func_node, node) then
        return parent
      end
      return nil
    elseif parent:type() == "dot_index_expression" 
        or parent:type() == "method_index_expression" then
      -- Continue walking up the chain
      current = parent
    elseif parent:type() == "arguments" then
      -- We're inside arguments, not the function name
      return nil
    else
      current = parent
    end
    
    depth = depth + 1
  end
  
  return nil
end

-- Check if a Lua function_call is inside a variable_declaration
-- Used to defer to declarations handler for consistent navigation
function M.is_lua_call_in_variable_declaration(func_call)
  if not func_call or func_call:type() ~= "function_call" then
    return false
  end
  
  -- Walk up: function_call -> expression_list -> assignment_statement -> variable_declaration
  local parent = func_call:parent()
  if parent and parent:type() == "expression_list" then
    local assignment = parent:parent()
    if assignment and assignment:type() == "assignment_statement" then
      local var_decl = assignment:parent()
      if var_decl and var_decl:type() == "variable_declaration" then
        return true
      end
    end
  end
  
  return false
end

return M
