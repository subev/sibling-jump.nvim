-- Configuration module for sibling-jump.nvim
-- Contains all node type definitions and static configuration

local M = {}

-- Comment delimiters for various languages
M.COMMENT_DELIMITERS = {
  ["--"] = true,        -- Lua
  ["//"] = true,        -- C/C++/Java/C#/JS/TS
  ["/*"] = true,        -- C-style block comment start
  ["*/"] = true,        -- C-style block comment end
  ["#"] = true,         -- Python/Shell
  ["<!--"] = true,      -- HTML/XML
  ["-->"] = true,       -- HTML/XML
  ["comment_content"] = true,  -- Generic comment content node
}

-- Punctuation and delimiters to skip
M.PUNCTUATION = {
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

-- Meaningful node types that represent complete "units" we want to jump between
M.MEANINGFUL_TYPES = {
  -- === Statements ===
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
  "switch_case", -- Individual case clauses in switch statements
  "switch_default", -- Default clause in switch statements

  -- === Declarations ===
  "lexical_declaration",
  "variable_declaration",
  "function_declaration",
  "class_declaration",
  "method_definition",
  "export_statement",
  "import_statement",

  -- === TypeScript/JavaScript specific ===
  "property_signature", -- For type definitions like `contentUrl: string;`
  "public_field_definition",
  "pair", -- For object properties like `key: value`
  "shorthand_property_identifier", -- For object shorthand properties like `{ foo, bar }`
  "type_alias_declaration", -- For type aliases like `type Foo = Bar`
  "interface_declaration", -- For interfaces like `interface Foo { ... }`

  -- === JSX/TSX ===
  "jsx_self_closing_element", -- Self-closing JSX like <div />
  "jsx_element", -- JSX elements like <div>...</div>
  "jsx_attribute", -- JSX attributes like visible={true}
  "jsx_expression", -- JSX expressions like {condition && <Component />}

  -- === Destructuring ===
  "shorthand_property_identifier_pattern", -- For destructured properties like `{ tab, setTab }`
  "pair_pattern", -- For renamed destructured properties like `{ currentTab: tab }`

  -- === Type annotations ===
  "type_parameter", -- For generic type parameters like <T, U, V>
  "literal_type", -- For union type members like "pending" | "success" | "error"

  -- === Python ===
  "function_definition",
  "class_definition",
  "decorated_definition",
  -- Note: Python 'assignment' is always wrapped in 'expression_statement', so not listed here
  "pass_statement",
  "import_from_statement",
  "with_statement",
  "assert_statement",
  "raise_statement",

  -- === Lua ===
  "assignment_statement",
  "function_call",
  "repeat_statement", -- repeat-until loops
  "label_statement", -- Labels like ::continue::
  "elseif_statement", -- elseif branches
  "else_statement", -- else branches
  "field", -- Table fields like `key = value` or array entries in table_constructor
  -- Note: do_statement, function_declaration, function_definition are shared with other languages above

  -- === Java ===
  "local_variable_declaration", -- Local variables in methods
  "field_declaration", -- Class fields

  -- === C/C++ ===
  "declaration", -- Variable declarations

  -- === C# ===
  "local_declaration_statement", -- Local variables
}

-- Container types where we might be on whitespace between children
M.CONTAINER_TYPES = {
  ["statement_block"] = true, -- JS/TS function bodies
  ["block"] = true, -- Lua/Java/C# function bodies
  ["compound_statement"] = true, -- C/C++ function bodies
  ["object"] = true,
  ["object_type"] = true,
  ["array"] = true,
}

-- List-like containers where direct children are navigable
M.LIST_CONTAINERS = {
  ["array"] = true,
  ["arguments"] = true,
  ["formal_parameters"] = true,
  ["named_imports"] = true,
  ["array_pattern"] = true, -- For tuple destructuring: [first, second, third]
  ["object_pattern"] = true, -- For object destructuring: { foo, bar }
  ["type_parameters"] = true, -- For generic types: <T, U, V>
  ["union_type"] = true, -- For union types: A | B | C
  ["table_constructor"] = true, -- Lua tables: { key = value, ... } or { "a", "b" }
}

-- Helper function to check if a node type is meaningful
function M.is_meaningful_type(node_type)
  for _, type_name in ipairs(M.MEANINGFUL_TYPES) do
    if node_type == type_name then
      return true
    end
  end
  return false
end

-- Helper function to check if a node type is a container
function M.is_container_type(node_type)
  return M.CONTAINER_TYPES[node_type] == true
end

-- Helper function to check if a node type is a list container
function M.is_list_container_type(node_type)
  return M.LIST_CONTAINERS[node_type] == true
end

return M
