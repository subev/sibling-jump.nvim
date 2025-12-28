-- sibling_jump.lua
-- Navigate between sibling nodes at the same treesitter nesting level
--
-- Usage:
--   require("sibling_jump").setup({
--     next_key = '<C-j>',         -- Key for jumping to next sibling (default: <C-j>)
--     prev_key = '<C-k>',         -- Key for jumping to previous sibling (default: <C-k>)
--     center_on_jump = false,     -- Whether to center screen after each jump (default: false)
--   })

local M = {}

-- Plugin configuration
local config = {
  center_on_jump = false, -- Whether to center screen (zz) after each jump
}

-- Check if node should be skipped (comments, empty nodes, punctuation)
local function is_skippable_node(node)
  if not node then
    return true
  end

  local node_type = node:type()

  -- Skip comment nodes
  if node_type:match("comment") then
    return true
  end

  -- Skip punctuation and delimiters
  local punctuation = {
    ["{"] = true,
    ["}"] = true,
    ["("] = true,
    [")"] = true,
    ["["] = true,
    ["]"] = true,
    [","] = true,
    [";"] = true,
    [":"] = true,
    ["<"] = true,
    [">"] = true,
    ["</"] = true,
    ["/>"] = true,
  }
  if punctuation[node_type] then
    return true
  end

  -- Skip JSX opening/closing tags (they're just delimiters)
  if node_type == "jsx_opening_element" or node_type == "jsx_closing_element" then
    return true
  end

  -- Skip empty nodes (nodes with no content)
  local start_row, start_col, end_row, end_col = node:range()
  if start_row == end_row and start_col == end_col then
    return true
  end

  return false
end

-- Check if a node type is a "meaningful unit" we want to jump between
local function is_meaningful_node(node)
  if not node then
    return false
  end

  local node_type = node:type()
  
  -- Special case: identifier is meaningful in some contexts but not others
  if node_type == "identifier" then
    local parent = node:parent()
    if not parent then
      return false
    end
    
    -- identifier is meaningful in array_pattern (tuple destructuring)
    if parent:type() == "array_pattern" then
      return true
    end
    
    -- identifier is NOT meaningful as the object in member_expression
    if parent:type() == "member_expression" then
      return false
    end
    
    -- identifier is NOT meaningful in other contexts
    return false
  end
  
  -- Special case: type_identifier is meaningful in some contexts but not others
  if node_type == "type_identifier" then
    local parent = node:parent()
    if not parent then
      return false
    end
    
    -- type_identifier is NOT meaningful when it's a member of a union_type
    -- (we want to navigate between union members, not individual type_identifiers)
    if parent:type() == "union_type" then
      return false
    end
    
    -- type_identifier IS meaningful when it's the name of a type declaration
    -- This is handled by the special check in get_node_at_cursor
    
    -- type_identifier is meaningful in other contexts (e.g., as a type annotation)
    return true
  end

  -- These are the types of nodes we want to jump between
  -- They represent complete "units" like statements, declarations, properties, etc.
  local meaningful_types = {
    -- Statements
    "expression_statement",
    "if_statement",
    "for_statement",
    "while_statement",
    "do_statement",
    "for_in_statement",
    "return_statement",
    "break_statement",
    "continue_statement",
    "throw_statement",
    "try_statement",
    "switch_statement",

    -- Declarations
    "lexical_declaration",
    "variable_declaration",
    "function_declaration",
    "class_declaration",
    "method_definition",
    "export_statement",
    "import_statement",

    -- TypeScript/JavaScript specific
    "property_signature", -- For type definitions like `contentUrl: string;`
    "public_field_definition",
    "pair", -- For object properties like `key: value`
    "type_alias_declaration", -- For type aliases like `type Foo = Bar`
    "interface_declaration", -- For interfaces like `interface Foo { ... }`

    -- JSX/TSX
    "jsx_self_closing_element", -- Self-closing JSX like <div />
    "jsx_element", -- JSX elements like <div>...</div>
    "jsx_attribute", -- JSX attributes like visible={true}

    -- Destructuring
    "shorthand_property_identifier_pattern", -- For destructured properties like `{ tab, setTab }`
    "pair_pattern", -- For renamed destructured properties like `{ currentTab: tab }`
    -- Note: identifier is handled specially in is_meaningful_node()
    
    -- Type annotations
    "type_parameter", -- For generic type parameters like <T, U, V>
    "literal_type", -- For union type members like "pending" | "success" | "error"
    -- Note: type_identifier is handled specially in is_meaningful_node()

    -- Python
    "function_definition",
    "class_definition",
    "decorated_definition",
    "assignment",

    -- Lua
    "assignment_statement",
    "function_call_statement",
  }

  for _, type_name in ipairs(meaningful_types) do
    if node_type == type_name then
      return true
    end
  end

  return false
end

-- Get the node at cursor position
local function get_node_at_cursor(bufnr)
  -- Get treesitter parser
  local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
  if not lang then
    return nil, "No treesitter language found for filetype"
  end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok or not parser then
    return nil, "No treesitter parser available"
  end

  local tree = parser:parse()[1]
  if not tree then
    return nil, "Failed to parse buffer"
  end

  local root = tree:root()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- Convert to 0-indexed
  local col = cursor[2]

  -- Get the smallest node at cursor
  local node = root:descendant_for_range(row, col, row, col)
  if not node then
    return nil, "No node at cursor"
  end

  -- Special case: if we're on a jsx_opening_element or jsx_closing_element,
  -- treat the parent jsx_element as the meaningful node
  if node:type() == "jsx_opening_element" or node:type() == "jsx_closing_element" then
    local parent = node:parent()
    if parent and parent:type() == "jsx_element" then
      return parent, parent:parent()
    end
  end

  -- Special case: if we're on a container node (like statement_block, object, etc.)
  -- where cursor is on whitespace/between children, find the closest meaningful child
  local container_types = {
    ["statement_block"] = true,
    ["object"] = true,
    ["object_type"] = true,
    ["array"] = true,
  }

  if container_types[node:type()] then
    -- Find the closest meaningful child node to the cursor position
    local closest_before = nil
    local closest_after = nil
    local min_dist_before = math.huge
    local min_dist_after = math.huge

    for child in node:iter_children() do
      if is_meaningful_node(child) then
        local child_start_row = child:start()

        if child_start_row < row then
          -- Child is before cursor
          local dist = row - child_start_row
          if dist < min_dist_before then
            min_dist_before = dist
            closest_before = child
          end
        elseif child_start_row > row then
          -- Child is after cursor
          local dist = child_start_row - row
          if dist < min_dist_after then
            min_dist_after = dist
            closest_after = child
          end
        else
          -- Child is on the same line as cursor, use it
          return child, node
        end
      end
    end

    -- Return a special marker indicating we're on whitespace
    -- We'll handle this specially in the jump function
    if closest_before or closest_after then
      return {
        _on_whitespace = true,
        closest_before = closest_before,
        closest_after = closest_after,
        parent = node,
      },
        node
    end
    -- If no meaningful children found, fall through to normal logic
  end

  -- Walk up the tree until we find a "meaningful" node that represents
  -- a complete unit we want to jump between (like a property_signature, statement, etc.)
  local current = node
  while current do
    -- Special case: if current is a type_identifier inside a type_alias_declaration or interface_declaration,
    -- use the declaration as the navigation unit (not the type_identifier)
    if current:type() == "type_identifier" then
      local parent = current:parent()
      if parent and (parent:type() == "type_alias_declaration" or parent:type() == "interface_declaration") then
        -- We're the name of a type declaration, use the declaration for navigation
        return parent, parent:parent()
      end
    end
  
    -- Special case: if current is an identifier inside a JSX element,
    -- walk up to find the jsx_self_closing_element or jsx_element
    if current:type() == "identifier" then
      local parent = current:parent()
      
      -- JSX tag name - walk up to find the jsx element
      if parent and (parent:type() == "jsx_self_closing_element" or parent:type() == "jsx_opening_element") then
        -- We're a JSX tag name, walk up to find the jsx element
        if parent:type() == "jsx_opening_element" then
          -- jsx_opening_element's parent is jsx_element
          local grandparent = parent:parent()
          if grandparent and grandparent:type() == "jsx_element" then
            local great_grandparent = grandparent:parent()
            if great_grandparent and great_grandparent:type() == "jsx_element" then
              -- We're in a JSX fragment, navigate between children
              return grandparent, great_grandparent
            end
          end
        elseif parent:type() == "jsx_self_closing_element" then
          -- jsx_self_closing_element might be directly in a fragment
          local grandparent = parent:parent()
          if grandparent and grandparent:type() == "jsx_element" then
            -- We're in a JSX fragment, navigate between children
            return parent, grandparent
          end
        end
      end
    end
  
    -- Special case: if current is jsx_opening_element or jsx_closing_element,
    -- use the parent jsx_element instead
    if current:type() == "jsx_opening_element" or current:type() == "jsx_closing_element" then
      local parent = current:parent()
      if parent and parent:type() == "jsx_element" then
        return parent, parent:parent()
      end
    end

    -- Special case: if we're on a property_identifier inside a pair (object property key),
    -- use the pair as the meaningful node to navigate between properties in the object.
    -- But only if the pair is NOT the only property (would exit the context).
    -- Example: { foo: value, bar: value } - when on "foo", navigate to "bar"
    if current:type() == "property_identifier" then
      local parent = current:parent()
      if parent and parent:type() == "pair" then
        local grandparent = parent:parent()
        -- Check if this pair is inside an object (not a top-level pair)
        if grandparent and grandparent:type() == "object" then
          -- Count how many pair siblings exist
          local pair_count = 0
          for child in grandparent:iter_children() do
            if child:type() == "pair" then
              pair_count = pair_count + 1
            end
          end
          -- If there are multiple pairs, navigate between them
          -- If only one pair, it would jump outside the context (no-op)
          if pair_count > 1 then
            return parent, grandparent -- Return the pair and the object
          else
            return nil, "Single property in object - would exit context"
          end
        end
      elseif parent and parent:type() == "property_signature" then
        -- Similar handling for property_signature in type definitions
        -- Example: type Foo = { bar: string; baz: number } - navigate between bar and baz
        local grandparent = parent:parent()
        if grandparent and grandparent:type() == "object_type" then
          -- Count how many property_signature siblings exist
          local prop_count = 0
          for child in grandparent:iter_children() do
            if child:type() == "property_signature" then
              prop_count = prop_count + 1
            end
          end
          -- If there are multiple properties, navigate between them
          if prop_count > 1 then
            return parent, grandparent -- Return the property_signature and the object_type
          else
            return nil, "Single property in object_type - would exit context"
          end
        end
      end
    end

    -- Special case: if we're inside a list-like structure (array, arguments, parameters),
    -- use the direct child as the meaningful node for navigation
    -- This allows navigation between elements while staying within the container boundary
    -- Examples:
    --   [element1, element2] - navigate between array elements
    --   func(arg1, arg2) - navigate between function call arguments
    --   (param1: type, param2: type) - navigate between function parameters
    local check_node = current
    local list_containers = {
      ["array"] = true,
      ["arguments"] = true,
      ["formal_parameters"] = true,
      ["named_imports"] = true,
      ["array_pattern"] = true, -- For tuple destructuring: [first, second, third]
      ["object_pattern"] = true, -- For object destructuring: { foo, bar }
      ["type_parameters"] = true, -- For generic types: <T, U, V>
      ["union_type"] = true, -- For union types: A | B | C
    }

    while check_node do
      local parent = check_node:parent()
      if parent and list_containers[parent:type()] then
        -- Special case for union_type: walk up to find the outermost union_type
        -- since union types can be nested (A | B | C is parsed as nested unions)
        if parent:type() == "union_type" then
          local outermost = parent
          while outermost:parent() and outermost:parent():type() == "union_type" do
            outermost = outermost:parent()
          end
          parent = outermost
        end
        
        -- Before using list container navigation, check if we're inside a statement_block
        -- with meaningful siblings. If so, prefer statement-level navigation.
        -- Example: inside an arrow function with multiple statements, navigate between
        -- statements, not between function arguments.

        -- Walk up from current node to find if there's a meaningful node in a statement_block
        local test_node = current
        while test_node and test_node ~= check_node do
          if is_meaningful_node(test_node) then
            local test_parent = test_node:parent()
            if test_parent and test_parent:type() == "statement_block" then
              -- Count meaningful children in the statement block
              local meaningful_count = 0
              for child in test_parent:iter_children() do
                if is_meaningful_node(child) then
                  meaningful_count = meaningful_count + 1
                end
              end
              -- If there are multiple meaningful statements, prefer statement navigation
              if meaningful_count > 1 then
                return test_node, test_parent
              end
            end
          end
          test_node = test_node:parent()
        end

        -- check_node is a direct child of a list container
        local element = check_node
        -- Count non-skippable siblings in the container
        local element_count = 0
        for child in parent:iter_children() do
          if not is_skippable_node(child) then
            element_count = element_count + 1
          end
        end
        -- If multiple elements, allow navigation
        if element_count > 1 then
          return element, parent
        else
          return nil, "Single element in list - would exit context"
        end
      end
      check_node = parent
    end
    
    -- Special case: if we're inside a jsx_self_closing_element or jsx_element,
    -- and its parent is also a jsx_element (i.e., we're in a JSX fragment <>...</>),
    -- then use the jsx_self_closing_element/jsx_element as the navigation unit
    -- This must come BEFORE is_meaningful_node check to handle JSX fragments correctly
    if current:type() == "jsx_self_closing_element" or current:type() == "jsx_element" then
      local parent = current:parent()
      if parent and parent:type() == "jsx_element" then
        -- We're inside a fragment, navigate between JSX children
        return current, parent
      end
    end

    if is_meaningful_node(current) then
      return current, current:parent()
    end
    current = current:parent()
  end

  -- Fallback: if we didn't find a meaningful node, just use the first non-skippable node
  current = node
  while current and is_skippable_node(current) do
    current = current:parent()
  end

  if current then
    return current, current:parent()
  end

  return nil, "No valid node found at cursor"
end

-- Recursively collect all union type members from a nested union_type structure
local function collect_union_members(union_node, members)
  members = members or {}
  
  for child in union_node:iter_children() do
    if child:type() == "union_type" then
      -- Recursively collect from nested union
      collect_union_members(child, members)
    elseif child:type() == "type_identifier" or child:type() == "literal_type" or child:type() == "object_type" then
      -- This is an actual union member
      table.insert(members, child)
    end
    -- Skip | operators and other punctuation
  end
  
  return members
end

-- Get all non-skippable children of a parent node
local function get_sibling_nodes(parent)
  if not parent then
    return {}
  end

  local parent_type = parent:type()
  
  -- Special case: for union_type, collect all members recursively
  if parent_type == "union_type" then
    return collect_union_members(parent)
  end
  
  local siblings = {}
  for child in parent:iter_children() do
    if not is_skippable_node(child) then
      -- Skip identifier nodes that are JSX tag names (direct children of jsx elements)
      local skip_jsx_identifier = child:type() == "identifier"
        and (
          parent_type == "jsx_element"
          or parent_type == "jsx_self_closing_element"
          or parent_type == "jsx_opening_element"
        )

      if not skip_jsx_identifier then
        table.insert(siblings, child)
      end
    end
  end

  return siblings
end

-- Find the index of a node in a list
local function find_node_index(node, node_list)
  local node_start_row, node_start_col = node:start()

  for i, n in ipairs(node_list) do
    local n_start_row, n_start_col = n:start()
    if n_start_row == node_start_row and n_start_col == node_start_col then
      return i
    end
  end

  return nil
end

-- Find next/prev sibling node
local function get_sibling_node(node, parent, forward)
  if not node or not parent then
    return nil
  end

  local siblings = get_sibling_nodes(parent)
  if #siblings == 0 then
    return nil
  end

  local current_index = find_node_index(node, siblings)
  if not current_index then
    return nil
  end

  local next_index = forward and (current_index + 1) or (current_index - 1)

  return siblings[next_index]
end

-- Detect if we're on a method call in a chain (e.g., obj.foo().bar().baz())
-- Returns: in_chain (boolean), property_node (the property_identifier node)
local function is_in_method_chain(node)
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
local function navigate_method_chain(property_node, forward)
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

-- Collect all else clauses in an if-else-if chain
-- Returns: list of else_clause nodes (in order from first to last)
local function collect_else_clauses(if_node)
  local clauses = {}
  local current_if = if_node
  
  while current_if and current_if:type() == "if_statement" do
    -- Look for else_clause in this if_statement
    local found_else = false
    for i = 0, current_if:child_count() - 1 do
      local child = current_if:child(i)
      if child:type() == "else_clause" then
        found_else = true
        table.insert(clauses, child)
        
        -- Check if this else clause contains another if_statement (else if)
        -- or a statement_block (final else)
        for j = 0, child:child_count() - 1 do
          local grandchild = child:child(j)
          if grandchild:type() == "if_statement" then
            -- This is an else if, continue with the nested if_statement
            current_if = grandchild
            break
          elseif grandchild:type() == "statement_block" then
            -- This is the final else, no more to traverse
            current_if = nil
            break
          end
        end
        break
      end
    end
    
    if not found_else then
      break
    end
  end
  
  return clauses
end

-- Get position of 'else' keyword within else_clause
-- Returns: row, col (pointing to 'e' of 'else')
local function get_else_keyword_position(else_clause_node)
  if not else_clause_node or else_clause_node:type() ~= "else_clause" then
    return nil, nil
  end
  
  -- Find the 'else' keyword child
  for i = 0, else_clause_node:child_count() - 1 do
    local child = else_clause_node:child(i)
    if child:type() == "else" then
      return child:start()
    end
  end
  
  -- Fallback to else_clause start position
  return else_clause_node:start()
end

-- Detect if we're on an if statement with else clauses
-- Returns: has_else_clauses (boolean), if_statement_node, current_position_index
-- current_position_index: 0 = on main if, 1+ = on else clause (1-based)
local function is_in_if_else_chain(node)
  if not node then
    return false, nil, 0
  end
  
  -- Walk up to find if_statement or else_clause
  -- We want to find the OUTERMOST if_statement that contains the cursor
  local current = node
  local depth = 0
  local found_if = nil
  local found_else_clause = nil
  
  while current and depth < 20 do
    if current:type() == "if_statement" then
      -- Found an if_statement, but continue looking for outer ones
      found_if = current
      current = current:parent()
      depth = depth + 1
    elseif current:type() == "else_clause" then
      found_else_clause = current
      -- Continue walking up to find the parent if_statement
      current = current:parent()
      depth = depth + 1
    else
      current = current:parent()
      depth = depth + 1
    end
    
    -- Stop if we've gone too far up
    if current and (current:type() == "statement_block" or current:type() == "program") then
      break
    end
  end
  
  -- If we found an if_statement but it's nested inside an else_clause,
  -- walk up to find the outermost if_statement in the chain
  if found_if then
    local test_parent = found_if:parent()
    while test_parent and test_parent:type() == "else_clause" do
      local outer_if = test_parent:parent()
      if outer_if and outer_if:type() == "if_statement" then
        found_if = outer_if
        test_parent = outer_if:parent()
      else
        break
      end
    end
  end
  
  if not found_if then
    return false, nil, 0
  end
  
  -- Check if this if_statement has else clauses
  local else_clauses = collect_else_clauses(found_if)
  if #else_clauses == 0 then
    return false, nil, 0
  end
  
  -- Determine current position: are we on the main if or on an else clause?
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor[1] - 1 -- Convert to 0-indexed
  
  -- Check if cursor is on one of the else clauses (compare by position, not object identity)
  -- Since else clauses can be nested, we want the LAST (innermost) match
  local matched_position = nil
  for i, clause in ipairs(else_clauses) do
    local clause_start_row = clause:start()
    local clause_end_row = select(3, clause:range())
    
    if cursor_row >= clause_start_row and cursor_row <= clause_end_row then
      matched_position = i
    end
  end
  
  if matched_position then
    return true, found_if, matched_position
  end
  
  -- Check if cursor is on the main if (not on any else clause)
  local if_start_row = found_if:start()
  local first_else_row = else_clauses[1]:start()
  
  if cursor_row >= if_start_row and cursor_row < first_else_row then
    -- Cursor is on the main if part (before any else)
    return true, found_if, 0
  end
  
  return false, nil, 0
end

-- Navigate forward/backward in an if-else-if chain
-- Returns: target node (if_statement or else_clause), target_row, target_col, or nil
local function navigate_if_else_chain(if_node, current_pos, forward)
  local else_clauses = collect_else_clauses(if_node)
  
  if forward then
    -- Forward navigation: if (pos=0) → else if (pos=1) → else if (pos=2) → else (pos=N) → next statement
    if current_pos == 0 then
      -- On main if, jump to first else clause
      if #else_clauses > 0 then
        local target_row, target_col = get_else_keyword_position(else_clauses[1])
        return else_clauses[1], target_row, target_col
      else
        -- No else clauses, jump to next sibling of if_statement
        local parent = if_node:parent()
        if parent then
          local sibling = get_sibling_node(if_node, parent, true)
          if sibling then
            local target_row, target_col = sibling:start()
            return sibling, target_row, target_col
          end
        end
        return nil, nil, nil
      end
    elseif current_pos < #else_clauses then
      -- On an else clause, jump to next else clause
      local next_clause = else_clauses[current_pos + 1]
      local target_row, target_col = get_else_keyword_position(next_clause)
      return next_clause, target_row, target_col
    else
      -- On last else clause, jump to next sibling of if_statement
      local parent = if_node:parent()
      if parent then
        local sibling = get_sibling_node(if_node, parent, true)
        if sibling then
          local target_row, target_col = sibling:start()
          return sibling, target_row, target_col
        end
      end
      return nil, nil, nil
    end
  else
    -- Backward navigation: next statement → else (pos=N) → else if (pos=2) → else if (pos=1) → if (pos=0) → prev statement
    if current_pos == 0 then
      -- On main if, jump to previous sibling of if_statement
      local parent = if_node:parent()
      if parent then
        local sibling = get_sibling_node(if_node, parent, false)
        if sibling then
          local target_row, target_col = sibling:start()
          return sibling, target_row, target_col
        end
      end
      return nil, nil, nil
    elseif current_pos == 1 then
      -- On first else clause, jump back to main if
      local target_row, target_col = if_node:start()
      return if_node, target_row, target_col
    else
      -- On an else clause, jump to previous else clause
      local prev_clause = else_clauses[current_pos - 1]
      local target_row, target_col = get_else_keyword_position(prev_clause)
      return prev_clause, target_row, target_col
    end
  end
end

-- Adjust cursor position for JSX elements to land on tag name instead of '<'
local function get_jsx_tag_position(node)
  local node_type = node:type()

  -- For jsx_self_closing_element: <Button />
  -- Structure: < [identifier] [attributes...] />
  if node_type == "jsx_self_closing_element" then
    local identifier = node:child(1) -- child[0] is '<', child[1] is identifier
    if identifier and identifier:type() == "identifier" then
      return identifier:start()
    end
  end

  -- For jsx_element: <Button>...</Button>
  -- Structure: [jsx_opening_element] [children...] [jsx_closing_element]
  if node_type == "jsx_element" then
    local opening_element = node:child(0)
    if opening_element and opening_element:type() == "jsx_opening_element" then
      -- jsx_opening_element structure: < [identifier] [attributes...] >
      local identifier = opening_element:child(1) -- child[0] is '<', child[1] is identifier
      if identifier and identifier:type() == "identifier" then
        return identifier:start()
      end
    end
  end

  -- For non-JSX nodes, return the original start position
  return node:start()
end

-- Main jump function
function M.jump_to_sibling(opts)
  opts = opts or {}
  local forward = opts.forward ~= false -- Default to forward

  local bufnr = vim.api.nvim_get_current_buf()

  -- Repeat for count
  for _ = 1, vim.v.count1 do
    -- Get cursor position for chain detection
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]

    -- Get tree and node for chain detection
    local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
    if lang then
      local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
      if ok and parser then
        local tree = parser:parse()[1]
        if tree then
          local root = tree:root()
          local node = root:descendant_for_range(row, col, row, col)

          -- FIRST: Check if we're in a method chain
          if node then
            local in_chain, property_node = is_in_method_chain(node)
            if in_chain then
              local target_prop = navigate_method_chain(property_node, forward)
              if target_prop then
                -- Successfully found target in chain
                vim.cmd("normal! m'")
                local target_row, target_col = target_prop:start()
                vim.api.nvim_win_set_cursor(0, { target_row + 1, target_col })
                if config.center_on_jump then
                  vim.cmd("normal! zz")
                end
                -- Continue to next iteration for count support
                goto continue
              else
                -- At boundary of chain, do nothing (no-op)
                return
              end
            end
            
            -- SECOND: Check if we're in an if-else-if chain
            local in_if_else, if_node, current_pos = is_in_if_else_chain(node)
            if in_if_else then
              local target_node, target_row, target_col = navigate_if_else_chain(if_node, current_pos, forward)
              if target_node then
                -- Successfully found target in if-else chain
                vim.cmd("normal! m'")
                vim.api.nvim_win_set_cursor(0, { target_row + 1, target_col })
                if config.center_on_jump then
                  vim.cmd("normal! zz")
                end
                -- Continue to next iteration for count support
                goto continue
              end
              -- At boundary of chain, fall through to regular navigation
            end
          end
        end
      end
    end

    -- FALLBACK: Use regular sibling/whitespace navigation
    local current_node, parent = get_node_at_cursor(bufnr)

    if not current_node then
      -- Silently do nothing if no node found
      return
    end

    if not parent then
      -- At root level, can't have siblings
      return
    end

    -- Special case: if we're on whitespace, jump to the closest statement
    if type(current_node) == "table" and current_node._on_whitespace then
      local target_node = forward and current_node.closest_after or current_node.closest_before

      if target_node then
        -- Add current position to jump list before moving
        vim.cmd("normal! m'")

        -- Get the appropriate cursor position (adjusted for JSX elements)
        local target_row, target_col = get_jsx_tag_position(target_node)
        vim.api.nvim_win_set_cursor(0, { target_row + 1, target_col }) -- Convert back to 1-indexed

        -- Center the screen on the new position (if enabled)
        if config.center_on_jump then
          vim.cmd("normal! zz")
        end
      end
      -- Always return after handling whitespace (no sibling navigation)
      return
    end

    -- Find sibling node
    local target_node = get_sibling_node(current_node, parent, forward)

    -- Jump to target or do nothing (no notification)
    if target_node then
      -- Special case: if target is an if_statement with else clauses and we're going backward,
      -- jump to the last else clause instead of the if
      if not forward and target_node:type() == "if_statement" then
        local else_clauses = collect_else_clauses(target_node)
        if #else_clauses > 0 then
          -- Jump to the last else clause
          local last_else = else_clauses[#else_clauses]
          target_node = last_else
          target_row, target_col = get_else_keyword_position(last_else)
        end
      end
      
      -- Add current position to jump list before moving
      vim.cmd("normal! m'")

      -- Get the appropriate cursor position (adjusted for JSX elements)
      local target_row, target_col
      if not target_row then
        target_row, target_col = get_jsx_tag_position(target_node)
      end
      vim.api.nvim_win_set_cursor(0, { target_row + 1, target_col }) -- Convert back to 1-indexed

      -- Center the screen on the new position (if enabled)
      if config.center_on_jump then
        vim.cmd("normal! zz")
      end
    else
      -- No sibling found - just stop silently (no-op)
      return
    end

    ::continue::
  end
end

-- Setup function to configure keymaps
function M.setup(opts)
  opts = opts or {}

  -- Update configuration
  config.center_on_jump = opts.center_on_jump ~= nil and opts.center_on_jump or false

  local next_key = opts.next_key or "<C-j>"
  local prev_key = opts.prev_key or "<C-k>"
  local filetypes = opts.filetypes or nil -- Optional filetype restriction

  -- Function to set buffer-local keymaps
  local function set_keymaps(bufnr)
    vim.keymap.set("n", next_key, function()
      M.jump_to_sibling({ forward = true })
    end, { buffer = bufnr, noremap = true, silent = true, desc = "Jump to next sibling node" })

    vim.keymap.set("n", prev_key, function()
      M.jump_to_sibling({ forward = false })
    end, { buffer = bufnr, noremap = true, silent = true, desc = "Jump to previous sibling node" })
  end

  -- If filetypes are specified, use FileType autocommand for buffer-local keymaps
  if filetypes then
    vim.api.nvim_create_autocmd("FileType", {
      pattern = filetypes,
      callback = function(ev)
        set_keymaps(ev.buf)
      end,
      desc = "Set sibling-jump keymaps for specific filetypes",
    })
    
    -- Also set for current buffer if it matches
    local current_ft = vim.bo.filetype
    if current_ft and vim.tbl_contains(filetypes, current_ft) then
      set_keymaps(0)
    end
  else
    -- No filetype restriction: set global keymaps (original behavior)
    vim.keymap.set("n", next_key, function()
      M.jump_to_sibling({ forward = true })
    end, { noremap = true, silent = true, desc = "Jump to next sibling node" })

    vim.keymap.set("n", prev_key, function()
      M.jump_to_sibling({ forward = false })
    end, { noremap = true, silent = true, desc = "Jump to previous sibling node" })
  end
end

return M
