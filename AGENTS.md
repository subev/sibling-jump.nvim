# AI Agent Development Instructions

## Overview

This document provides comprehensive guidelines for AI assistants working on sibling-jump.nvim. Read this before making any changes to ensure you understand the architecture and development practices.

## Quick Start

1. **Read the architecture**: Start with `ARCHITECTURE.md` to understand the codebase structure
2. **Run tests**: `bash tests/test_runner.sh` - All tests must pass before and after changes
3. **Check current branch**: Work on feature branches, not main directly

## Project Context

**sibling-jump.nvim** is a Neovim plugin for context-aware code navigation using Tree-sitter. It allows jumping between sibling nodes at the same nesting level.

**Primary languages supported**: TypeScript, JavaScript, JSX, TSX, Lua
**Partial support**: Java, C, C++, C#, Python

## Architecture Overview

The plugin uses a **modular architecture** with 9 focused modules:

```
lua/sibling_jump/
├── init.lua (397)           - Public API & orchestration
├── config.lua (153)         - Static configuration
├── utils.lua (144)          - Pure utility functions
├── node_finder.lua (420)    - AST node detection
├── navigation.lua (62)      - Sibling finding
├── positioning.lua (36)     - Cursor positioning
└── special_modes/           - Complex navigation patterns
    ├── method_chains.lua (118)
    ├── if_else_chains.lua (276)
    └── switch_cases.lua (230)
```

**See `ARCHITECTURE.md` for detailed module documentation.**

## Critical Rules

### 1. Testing is Non-Negotiable

```bash
# ALWAYS run tests after ANY change
bash tests/test_runner.sh

# All tests MUST pass
# No exceptions
```

**Why**: This plugin has complex interactions with Tree-sitter AST. A seemingly minor change can break navigation in unexpected contexts.

### 2. Update Documentation as Code Evolves

**When making significant changes:**
- Update `ARCHITECTURE.md` if module structure or data flow changes
- Update `CHANGELOG.md` with user-facing changes
- Update `AGENTS.md` if development workflow changes
- Avoid hardcoding numbers (test counts, line counts) - they become stale

**Documentation should reflect reality, not history.**

### 3. Never Break Backward Compatibility

The public API in `init.lua` must remain stable:
- `M.setup(opts)` - Same signature
- `M.jump_to_sibling(opts)` - Same signature
- User commands: `SiblingJumpBuffer*` - Same names
- Configuration options: Same names and types

**Internal modules can change freely**, but public API is sacred.

### 4. Don't Use Plenary for Tests

❌ **DO NOT** add plenary.nvim as a test dependency
✅ **DO** use the existing direct test runner (`tests/run_tests.lua`)

**Why**: Plenary's test isolation breaks Tree-sitter parser access. Our direct runner preserves the full Neovim environment.

### 5. Module Naming Convention

- **Repository**: `sibling-jump.nvim` (hyphen)
- **Lua modules**: `sibling_jump` (underscore)
- **Always use**: `require("sibling_jump.module")` not `require("sibling-jump")`

## Development Workflow

### Making Changes

```bash
# 1. Create feature branch
git checkout -b feature/your-feature

# 2. Make changes
# ... edit files ...

# 3. Run tests continuously
bash tests/test_runner.sh

# 4. Ask user before committing
# DON'T auto-commit! Always ask user first.

# 5. Commit with user approval
git add -A
git commit -m "feat: add description"

# 6. Push when all tests pass
git push origin feature/your-feature
```

**IMPORTANT**: Never auto-commit changes. Always ask the user before creating commits. Show a summary of changes and wait for explicit approval.

### Test-Driven Development

1. **Add fixture** (if needed): `tests/fixtures/your_test.ts`
2. **Add test**: In `tests/run_tests.lua`
   ```lua
   test("Description", function()
     vim.cmd("edit " .. fixtures_dir .. "your_test.ts")
     vim.api.nvim_win_set_cursor(0, {5, 0})
     sibling_jump.jump_to_sibling({ forward = true })
     local pos = vim.api.nvim_win_get_cursor(0)
     assert_eq(7, pos[1], "Should jump to line 7")
   end)
   ```
3. **Run test** (should fail): `bash tests/test_runner.sh`
4. **Implement feature**: Make it pass
5. **Run all tests**: Ensure no regressions

## Common Tasks

### Adding Support for a New Language

1. **Find Tree-sitter node types**:
   ```vim
   :e tests/fixtures/test.py
   :TSPlaygroundToggle
   " Navigate to statements/declarations
   " Note the node type names
   ```

2. **Add to `config.lua`**:
   ```lua
   M.MEANINGFUL_TYPES = {
     -- ... existing types ...
     
     -- Python
     "function_definition",
     "class_definition",
     "for_statement",
     -- ... etc
   }
   ```

3. **Test thoroughly**:
   ```bash
   # Create test.py fixture
   # Add tests
   # Run: bash tests/test_runner.sh
   ```

### Adding a New Special Navigation Mode

**See ARCHITECTURE.md → Extension Points → Adding a New Special Navigation Mode**

Example: Navigate between class methods

1. **Create module**: `lua/sibling_jump/special_modes/class_methods.lua`
   ```lua
   local M = {}
   
   function M.detect(node)
     -- Walk up AST to detect if in method definition
     -- Return false if not in mode
     -- Return true, class_node, method_index if in mode
   end
   
   function M.navigate(class_node, method_index, forward)
     -- Find next/previous method in class
     -- Return method_node, row, col
     -- Return nil at boundaries
   end
   
   return M
   ```

2. **Register in `init.lua`**:
   ```lua
   -- At top
   local class_methods = require("sibling_jump.special_modes.class_methods")
   
   -- In jump_to_sibling, after other detections:
   local in_mode, class_node, method_idx = class_methods.detect(node)
   if in_mode then
     local target, row, col = class_methods.navigate(class_node, method_idx, forward)
     if target then
       vim.cmd("normal! m'")
       vim.api.nvim_win_set_cursor(0, { row + 1, col })
       if config.center_on_jump then vim.cmd("normal! zz") end
       goto continue
     else
       return  -- Boundary
     end
   end
   ```

3. **Write tests**: `tests/fixtures/class_methods.ts` + test cases

4. **Run tests**: `bash tests/test_runner.sh`

### Debugging Navigation Issues

**Step 1**: Understand the Tree-sitter structure
```vim
:e tests/fixtures/problematic_case.ts
:TSPlaygroundToggle
" Inspect node hierarchy at cursor position
```

**Step 2**: Check what node is detected
```lua
-- Add temporary debug in node_finder.lua
local function get_node_at_cursor(bufnr)
  -- ... existing code ...
  
  -- Add after finding node:
  print("Found node:", node:type())
  print("Parent:", parent and parent:type() or "nil")
  
  -- ... rest of code ...
end
```

**Step 3**: Check if node is considered meaningful
```lua
-- In Neovim command line
:lua local utils = require("sibling_jump.utils")
:lua local node = vim.treesitter.get_node()
:lua print("Meaningful?", utils.is_meaningful_node(node))
```

**Step 4**: Trace navigation path
```lua
-- Add debug prints in navigation.lua
function M.get_sibling_node(node, parent, forward)
  local siblings = M.get_sibling_nodes(parent)
  print("Found " .. #siblings .. " siblings")
  print("Current index:", utils.find_node_index(node, siblings))
  -- ... rest of code ...
end
```

**Step 5**: Remove debug prints and run tests

### Fixing a Bug

1. **Create minimal reproduction**: Add fixture file showing the bug
2. **Write failing test**: Test that reproduces the bug
3. **Identify root cause**: Use Tree-sitter playground and debug prints
4. **Fix**: Make the test pass
5. **Verify no regressions**: Run full test suite
6. **Document**: Add comment explaining the fix if non-obvious

## Code Style

### General Guidelines

- **Indentation**: 2 spaces (not tabs)
- **Line length**: No hard limit, but keep it readable (~100 chars)
- **Comments**: Use `--` for single line, explain *why* not *what*
- **Function names**: `snake_case` for local, `M.snake_case` for exports

### Avoid Deep Nesting

❌ **Bad** (deep nesting):
```lua
if condition1 then
  if condition2 then
    if condition3 then
      if condition4 then
        -- actual work
      end
    end
  end
end
```

✅ **Good** (early returns or scoped blocks):
```lua
-- Option 1: Early returns with guard clauses
if not condition1 then return end
if not condition2 then return end
if not condition3 then return end
if not condition4 then return end
-- actual work

-- Option 2: Scoped block with combined conditions
local result
do
  if not condition1 then goto skip end
  if not condition2 then goto skip end
  result = do_work()
  ::skip::
end

-- Option 3: Use `do` blocks to scope variable initialization
local node
do
  local lang = get_lang()
  if lang then
    local ok, parser = pcall(get_parser, lang)
    if ok and parser then
      node = parser:get_node()
    end
  end
end
if node then
  -- work with node
end
```

**Rationale**: Deep nesting (>3 levels) makes code hard to read and reason about. Prefer early returns, guard clauses, or scoped blocks to keep indentation shallow.

### Commenting Philosophy

✅ **Good comments** (explain why):
```lua
-- Special case: if we're on a type_identifier inside a type_alias_declaration,
-- use the declaration as the navigation unit (not the type_identifier)
-- This ensures we navigate between type declarations, not within them
if current:type() == "type_identifier" then
  local parent = current:parent()
  if parent and parent:type() == "type_alias_declaration" then
    return parent, parent:parent()
  end
end
```

❌ **Bad comments** (explain what - code already says this):
```lua
-- Increment i by 1
i = i + 1
```

### Tree-sitter Patterns

**Walking up the tree:**
```lua
local current = node
local depth = 0
while current and depth < MAX_DEPTH do
  if current:type() == "target_type" then
    -- Found it
    return current
  end
  current = current:parent()
  depth = depth + 1
end
```

**Iterating children:**
```lua
for child in node:iter_children() do
  if child:type() == "interesting_type" then
    -- Process child
  end
end
```

**Getting indexed child:**
```lua
local first_child = node:child(0)
local second_child = node:child(1)
```

**Getting position:**
```lua
local start_row, start_col, end_row, end_col = node:range()
local row, col = node:start()  -- Shorthand for start position
```

## Git Practices

### Commit Messages

Follow conventional commits:
```
feat: add feature description
fix: fix bug description
refactor: refactor description
docs: documentation changes
test: add or fix tests
chore: maintenance tasks
```

**Examples**:
- `feat: add support for Python class navigation`
- `fix: handle single-element arrays correctly`
- `refactor: extract positioning logic to separate module`
- `test: add test cases for nested JSX fragments`

### Branch Naming

- `feature/description` - New features
- `fix/description` - Bug fixes
- `refactor/description` - Code refactoring
- `docs/description` - Documentation

### Pull Request Guidelines

**If creating a PR:**
1. Ensure all tests pass
2. Add test coverage for new features
3. Update documentation if needed
4. Describe what changed and why

## Performance Considerations

### Do's

✅ **Early returns**: Check cheap conditions first
```lua
if not node then return nil end
if node:type() == "simple_check" then return result end
-- ... expensive operations after simple checks ...
```

✅ **Bounded loops**: Use max depth/iterations
```lua
local depth = 0
while current and depth < 20 do
  -- ... work ...
  depth = depth + 1
end
```

✅ **Lazy loading**: Modules load on first require
```lua
-- This is fine - Lua caches modules
local utils = require("sibling_jump.utils")
```

### Don'ts

❌ **Avoid caching Tree-sitter nodes**: Neovim handles this
```lua
-- DON'T do this
local cached_nodes = {}
```

❌ **Avoid async operations**: Navigation must be instant
```lua
-- DON'T use vim.schedule or async
```

❌ **Avoid deep recursion**: Use iteration with depth bounds
```lua
-- DON'T do unbounded recursion
local function recurse(node)
  if node:parent() then recurse(node:parent()) end
end

-- DO use bounded iteration
local current = node
local depth = 0
while current and depth < MAX_DEPTH do
  current = current:parent()
  depth = depth + 1
end
```

## Troubleshooting

### Tests Timeout

**Symptom**: `bash tests/test_runner.sh` hangs

**Causes**:
1. Infinite loop in navigation code
2. Syntax error causing Neovim to hang
3. Missing `return` statement

**Solution**:
```bash
# Check for syntax errors
nvim --headless -c "luafile lua/sibling_jump/init.lua" -c "q" 2>&1

# Add debug prints to find where it hangs
# Remove prints after fixing
```

### Tests Fail After Refactoring

**Symptom**: Tests that passed now fail

**Common causes**:
1. Changed module path (require statement wrong)
2. Forgot to update function call after extracting
3. Introduced circular dependency

**Solution**:
```bash
# Check error message carefully
bash tests/test_runner.sh 2>&1 | grep "Error"

# Common fixes:
# - Update require paths
# - Pass dependencies as parameters
# - Check module return values
```

### Tree-sitter Node Not Found

**Symptom**: Navigation doesn't work for certain code patterns

**Causes**:
1. Node type not in `MEANINGFUL_TYPES`
2. Node is being skipped by `is_skippable_node`
3. Context boundary preventing navigation

**Solution**:
```vim
# Open fixture and check node type
:e tests/fixtures/problem.ts
:TSPlaygroundToggle
" Note the node type at cursor

# Add to config.lua if needed
" Add to MEANINGFUL_TYPES
```

## Common Pitfalls

### 1. Forgetting 0-indexed vs 1-indexed

```lua
-- Cursor API is 1-indexed
local cursor = vim.api.nvim_win_get_cursor(0)  -- {line, col}
local row = cursor[1] - 1  -- Convert to 0-indexed for treesitter

-- Tree-sitter is 0-indexed
local ts_row, ts_col = node:start()

-- Setting cursor (back to 1-indexed)
vim.api.nvim_win_set_cursor(0, { ts_row + 1, ts_col })
```

### 2. Not Handling Nil Nodes

```lua
-- ALWAYS check for nil
if not node then return nil end
if not parent then return nil end

-- Check before accessing methods
local parent = node:parent()
if parent and parent:type() == "target" then
  -- ... safe to use parent ...
end
```

### 3. Circular Dependencies

```lua
-- BAD: if_else_chains.lua requires navigation.lua
--      navigation.lua requires if_else_chains.lua
-- CIRCULAR DEPENDENCY!

-- GOOD: Pass function as parameter
function M.navigate(node, pos, forward, get_sibling_node)
  -- Use get_sibling_node parameter instead of requiring
end
```

### 4. Modifying Global State

```lua
-- BAD: Module-level mutable state
local M = {}
M.current_mode = "normal"  -- DON'T DO THIS

-- GOOD: Pass state as parameters
function M.navigate(node, mode)
  -- Receive state as parameter
end
```

## Resources

### Documentation

- **Architecture**: `ARCHITECTURE.md` - Detailed module documentation
- **Main README**: `README.md` - User-facing documentation  
- **Changelog**: `CHANGELOG.md` - Version history
- **AI Instructions**: `.ai/instructions.md` - Original AI development guidelines

### Neovim APIs

- **Tree-sitter**: `:help treesitter-core`
- **Lua Guide**: `:help lua-guide`
- **API**: `:help api`

### Tree-sitter

- **Playground**: `:TSPlaygroundToggle` (requires nvim-treesitter-playground)
- **Node inspection**: `:lua print(vim.inspect(vim.treesitter.get_node()))`

### External

- **Tree-sitter Documentation**: https://tree-sitter.github.io/tree-sitter/
- **Neovim Lua Guide**: https://github.com/nanotee/nvim-lua-guide

## Questions?

When working on this codebase and you're unsure:

1. ✅ **Check ARCHITECTURE.md** - Comprehensive module documentation
2. ✅ **Check test suite** - Documents expected behavior
3. ✅ **Use TSPlaygroundToggle** - Inspect Tree-sitter structure
4. ✅ **Run tests frequently** - Catch regressions early
5. ✅ **Ask the user** - When in doubt, ask!

## Success Checklist

Before considering any change complete:

- [ ] All tests pass (`bash tests/test_runner.sh`)
- [ ] No new warnings or errors
- [ ] Public API unchanged (or documented breaking changes)
- [ ] Added tests for new functionality
- [ ] Code follows style guidelines
- [ ] Comments explain "why" not "what"
- [ ] No debug prints left in code
- [ ] Git commit message follows convention

---

**Remember**: This plugin helps developers navigate code efficiently. Every change should make navigation more intuitive, never more confusing. When in doubt, preserve existing behavior.
