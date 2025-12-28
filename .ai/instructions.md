# sibling-jump.nvim - AI Development Instructions

## Project Overview

**sibling-jump.nvim** is a Neovim plugin for context-aware navigation between sibling nodes using Tree-sitter. It provides intelligent code navigation that keeps you at the right level of abstraction.

**Primary Language Support:** TypeScript/JavaScript/JSX/TSX  
**Partial Support:** Python, Lua, and other Tree-sitter enabled languages

## Project Structure

```
sibling-jump.nvim/
├── lua/sibling_jump/
│   └── init.lua           # Main plugin implementation
├── plugin/
│   └── sibling-jump.lua   # Plugin loader (sets vim.g.loaded_sibling_jump)
├── tests/
│   ├── fixtures/          # Test fixture files (TS/JS/JSX/TSX)
│   ├── sibling_jump_spec.lua  # Main test suite
│   ├── run_tests.lua      # Direct test runner (NO plenary)
│   ├── run_js_tests.lua   # JavaScript compatibility tests
│   ├── minimal_init.lua   # Test environment setup
│   └── test_runner.sh     # Shell wrapper for running tests
├── README.md
├── CHANGELOG.md
├── LICENSE
└── .ai/
    └── instructions.md    # This file
```

## Important Technical Details

### 1. Module Naming Convention

**Critical:** The plugin uses `sibling_jump` (with underscore) internally but the repo is `sibling-jump.nvim` (with hyphen).

- **Lua module:** `require("sibling_jump")`
- **Git repo:** `subev/sibling-jump.nvim`
- **Plugin file:** `plugin/sibling-jump.lua`

Always use underscore when requiring the module or referencing Lua code!

### 2. Test Infrastructure

**DO NOT use plenary.nvim for tests!** The test suite uses a custom direct test runner because plenary's test isolation breaks Tree-sitter parser access.

**Running tests:**
```bash
cd /path/to/sibling-jump.nvim
bash tests/test_runner.sh
```

**Test structure:**
- Tests run directly in Neovim's environment with full Tree-sitter support
- 86 comprehensive tests covering all navigation scenarios
- Test fixtures are actual TypeScript/JavaScript files
- Tests must use absolute paths for fixtures (they're in `tests/fixtures/`)

**When adding tests:**
- Add fixture files to `tests/fixtures/`
- Update `tests/run_tests.lua` with new test cases
- Use the `test(name, fn)` function pattern
- Use `assert_eq(expected, actual, message)` for assertions

### 3. Core Navigation Logic

The plugin identifies "meaningful nodes" (statements, declarations, properties) and navigates between siblings at the same nesting level.

**Key functions in `lua/sibling_jump/init.lua`:**
- `is_meaningful_node()` - Defines which Tree-sitter node types are navigation targets
- `get_node_at_cursor()` - Finds the appropriate node at cursor with context awareness
- `get_sibling_node()` - Locates the next/previous sibling
- `jump_to_sibling()` - Main navigation function with count support

**Special navigation modes:**
- **Method chains:** Navigate between chained method calls (`.foo().bar().baz()`)
- **If-else chains:** Navigate between if/else-if/else clauses
- **Whitespace navigation:** Jump to closest statement when on empty lines
- **JSX elements:** Cursor lands on tag name, not angle bracket
- **Context boundaries:** Prevents jumping out of current context (e.g., single property in object)

### 4. Adding Language Support

To add support for a new language:

1. **Add meaningful node types** to the `meaningful_types` table in `is_meaningful_node()`
2. **Add container types** if needed (for list-like structures)
3. **Test thoroughly** - create test fixtures and add to test suite

**Example meaningful types for a language:**
- Statements (expression_statement, if_statement, etc.)
- Declarations (function_declaration, class_declaration, etc.)
- Properties (pair, property_signature, etc.)

### 5. Configuration Options

The plugin exposes these configuration options:

```lua
require("sibling_jump").setup({
  next_key = "<C-j>",       -- Default: <C-j>
  prev_key = "<C-k>",       -- Default: <C-k>
  center_on_jump = false,   -- Default: false
})
```

**Recommended lazy.nvim configuration:**

For optimal performance, restrict the plugin to TypeScript/JavaScript files only:

```lua
{
  "subev/sibling-jump.nvim",
  ft = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
  config = function()
    require("sibling_jump").setup({
      next_key = "<C-j>",
      prev_key = "<C-k>",
      center_on_jump = true,
    })
  end,
}
```

This ensures the plugin only loads for TS/JS files, avoiding conflicts with other filetypes and improving startup performance.

**Plugin behavior:**
- Adds positions to jump list before moving (`m'`)
- Supports vim counts (e.g., `3<C-j>` jumps 3 siblings forward)
- Silent no-ops at boundaries (doesn't show errors)

## Development Guidelines

### Code Style

- Use 2-space indentation
- Prefer local functions for internal logic
- Comment complex Tree-sitter logic explaining the node structure
- Keep functions focused and single-purpose

### When Making Changes

1. **Always run tests** after changes: `bash tests/test_runner.sh`
2. **Update CHANGELOG.md** with your changes
3. **Add tests** for new navigation scenarios
4. **Update README.md** if adding user-facing features

### Tree-sitter Node Investigation

When debugging or adding features, inspect Tree-sitter nodes:

```lua
-- Get node at cursor
local node = vim.treesitter.get_node()

-- Print node type
print(node:type())

-- Print node structure
print(vim.inspect(node))

-- See node in Tree-sitter playground
:TSPlaygroundToggle
```

### Common Patterns

**Walking up the tree to find a meaningful node:**
```lua
local current = node
while current do
  if is_meaningful_node(current) then
    return current, current:parent()
  end
  current = current:parent()
end
```

**Checking if node is in a special container:**
```lua
local parent = node:parent()
if parent and parent:type() == "container_type" then
  -- Special handling
end
```

## Testing Best Practices

1. **Test edge cases:** boundaries, single elements, nested contexts
2. **Test all languages:** TS, JS, JSX, TSX (use run_js_tests.lua for JS-specific)
3. **Name tests descriptively:** "JSX elements: forward navigation between self-closing"
4. **Use fixture files:** Don't generate code in tests, use pre-made fixtures
5. **Test from user perspective:** Position cursor, jump, verify position

## Git Workflow

This plugin is developed directly in the lazy.nvim installation:

```bash
cd ~/.local/share/nvim/lazy/sibling-jump.nvim

# Make changes
git add -A
git commit -m "feat: add description"

# Push to GitHub
git push origin main
```

**Branch strategy:** Main development happens on `main` branch since this is a personal/small project.

## Common Gotchas

1. **Tree-sitter node types vary by language** - Always check the actual node type names for each language
2. **Nested unions are parsed as nested union_type nodes** - Need special handling to collect all members
3. **JSX elements have complex nesting** - jsx_opening_element → jsx_element → jsx_fragment
4. **Context boundaries are important** - Single child in list should be no-op (don't exit context)
5. **Test paths must be absolute** - Relative paths won't work in the test runner

## Performance Considerations

- Plugin uses pcall() for safe Tree-sitter access
- Minimal vim API calls in hot paths
- Tree walking is bounded (max depth limits to prevent infinite loops)
- No async operations needed (navigation is synchronous)

## Related Projects

Similar navigation approaches:
- nvim-treesitter-textobjects (more general textobject selection)
- vim-unimpaired (line-based navigation)
- targets.vim (text object expansion)

**Key differentiator:** sibling-jump is context-aware and uses Tree-sitter structure, not line/text patterns.

## Maintainer Notes

- Repo owner: @subev
- Primary use case: TypeScript/React development
- Open to PRs for additional language support
- Tests must pass for all changes

## Questions?

When working on this codebase, if you're unsure:
1. Check the test suite - it documents expected behavior
2. Read Tree-sitter documentation for node types
3. Use `:TSPlaygroundToggle` to inspect actual Tree-sitter structure
4. Run tests frequently to catch regressions early
