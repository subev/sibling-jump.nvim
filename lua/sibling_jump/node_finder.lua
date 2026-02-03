-- Node finder module for sibling-jump.nvim
-- Handles finding the appropriate navigation node at cursor position

local config = require("sibling_jump.config")
local utils = require("sibling_jump.utils")

local M = {}

-- Alias utility functions for convenience
local is_comment_node = utils.is_comment_node
local is_skippable_node = utils.is_skippable_node
local is_meaningful_node = utils.is_meaningful_node

-- Get the node at cursor position
function M.get_node_at_cursor(bufnr)
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

  -- Adjust column if cursor is on leading whitespace
  -- This ensures we get the correct node (the statement, not its parent)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  local first_nonws_col = vim.fn.match(line, [[\S]])
  local original_col = col
  if first_nonws_col >= 0 and col < first_nonws_col then
    -- Cursor is in leading whitespace, adjust to first non-whitespace
    col = first_nonws_col
  elseif first_nonws_col < 0 then
    -- Line is all whitespace/empty, keep original column
    -- (This will likely trigger the _on_whitespace or _on_comment logic)
  end

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
  if config.is_container_type(node:type()) then
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

  -- Check if we're starting on a comment or empty line
  local started_on_comment = is_comment_node(node)
  local started_on_empty_line = node and node:type() == "chunk"

  -- Walk up the tree until we find a "meaningful" node that represents
  -- a complete unit we want to jump between (like a property_signature, statement, etc.)
  local current = node
  while current do
    -- Special case: if we started on a comment/empty line and reached a container,
    -- stop here and handle in fallback (don't walk up to find meaningful parent)
    if started_on_comment or started_on_empty_line then
      local current_type = current:type()
      local is_container = current_type == "block"
        or current_type == "statement_block"
        or current_type == "compound_statement"
        or current_type == "chunk"
      if is_container then
        -- Don't continue walking up - we want to search THIS container's children
        break
      end
    end
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
          -- Count all property siblings (both pair and shorthand_property_identifier)
          local prop_count = 0
          for child in grandparent:iter_children() do
            if child:type() == "pair" or child:type() == "shorthand_property_identifier" then
              prop_count = prop_count + 1
            end
          end
          -- If there are multiple properties, navigate between them
          -- If only one property, it would jump outside the context (no-op)
          if prop_count > 1 then
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

    -- Special case: if we're on a shorthand_property_identifier inside an object,
    -- navigate between all properties (shorthand and regular pairs) in the object.
    -- Example: { registered, scenario, normalProp: value } - navigate between all properties
    if current:type() == "shorthand_property_identifier" then
      local parent = current:parent()
      if parent and parent:type() == "object" then
        -- Count all meaningful property nodes (shorthand_property_identifier and pair)
        local prop_count = 0
        for child in parent:iter_children() do
          if child:type() == "shorthand_property_identifier" or child:type() == "pair" then
            prop_count = prop_count + 1
          end
        end
        -- If there are multiple properties, navigate between them
        if prop_count > 1 then
          return current, parent -- Return the shorthand_property_identifier and the object
        else
          return nil, "Single property in object - would exit context"
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

    while check_node do
      local parent = check_node:parent()
      if parent and config.is_list_container_type(parent:type()) then
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

        -- Walk up from current node to find if there's a meaningful node in a statement_block or switch_case
        local test_node = current
        while test_node and test_node ~= check_node do
          if is_meaningful_node(test_node) then
            local test_parent = test_node:parent()
            if test_parent and (test_parent:type() == "statement_block" or test_parent:type() == "block") then
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
              else
                -- Single statement in block - no-op (don't navigate outside the block)
                return nil, "Single statement in block - would exit context"
              end
            end
            -- Check if parent is switch_case or switch_default
            if test_parent and (test_parent:type() == "switch_case" or test_parent:type() == "switch_default") then
              -- Count meaningful statement children in the case
              local meaningful_count = 0
              for child in test_parent:iter_children() do
                if is_meaningful_node(child) then
                  meaningful_count = meaningful_count + 1
                end
              end
              -- If there are multiple meaningful statements in the case, prefer statement navigation
              if meaningful_count > 1 then
                return test_node, test_parent
              else
                -- Single statement in case - no-op (don't navigate outside the case)
                return nil, "Single statement in case - would exit context"
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
      local parent = current:parent()

      -- Special case: For C#/Java, if we found variable_declaration but parent is local_declaration_statement or local_variable_declaration,
      -- use the parent as the meaningful node instead (siblings are at that level)
      if current:type() == "variable_declaration" and parent and (parent:type() == "local_declaration_statement" or parent:type() == "local_variable_declaration") then
        current = parent
        parent = current:parent()
      end

      -- Check if we're inside a switch_case or switch_default with single statement
      if parent and (parent:type() == "switch_case" or parent:type() == "switch_default") then
        -- Count meaningful statement children in the case
        local meaningful_count = 0
        for child in parent:iter_children() do
          if is_meaningful_node(child) then
            meaningful_count = meaningful_count + 1
          end
        end
        -- If single statement, return nil (no-op, don't navigate outside the case)
        if meaningful_count == 1 then
          return nil, "Single statement in case - would exit context"
        end
      end

      return current, parent
    end
    current = current:parent()
  end

  -- Fallback: if we didn't find a meaningful node, just use the first non-skippable node
  current = node

  while current and is_skippable_node(current) do
    current = current:parent()
  end

  if current then
    local current_type = current:type()

    -- Special case: if we started on a comment or empty line,
    -- we need to find the closest meaningful node to "escape" from the comment
    if started_on_comment or started_on_empty_line or current_type == "chunk" then
      -- Get the parent container to search for meaningful siblings
      -- If we walked up from a comment, current is already the parent container (block/chunk)
      -- If we're at chunk level (empty line), search chunk itself
      local search_parent = current

      if search_parent then
        -- Collect all meaningful children
        local meaningful_children = {}
        for child in search_parent:iter_children() do
          if is_meaningful_node(child) then
            table.insert(meaningful_children, child)
          end
        end

        if #meaningful_children > 0 then
          -- Find closest meaningful nodes before and after cursor
          local closest_before = nil
          local closest_after = nil

          for _, child in ipairs(meaningful_children) do
            local child_row = child:start()
            if child_row < row then
              closest_before = child -- Keep updating to get the last one before
            elseif child_row > row and not closest_after then
              closest_after = child -- Take the first one after
            end
          end

          -- Return a special marker that tells jump_to_sibling we're on a comment
          -- and provides both direction options
          return {
            _on_comment = true,
            closest_before = closest_before,
            closest_after = closest_after,
            parent = search_parent,
            cursor_row = row,
          },
            search_parent
        end
      end
    end

    return current, current:parent()
  end

  return nil, "No valid node found at cursor"
end

return M
