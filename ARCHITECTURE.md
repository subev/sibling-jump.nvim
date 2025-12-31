# Architecture Documentation

## Overview

Sibling-jump.nvim uses a **modular architecture** with focused modules handling specific responsibilities. The codebase was refactored from a 1,719-line monolith into 9 focused modules for maintainability and extensibility.

## Design Principles

1. **Separation of Concerns**: Each module has a single, well-defined responsibility
2. **Modularity**: Features are isolated in their own modules for easy testing and modification
3. **Backward Compatibility**: Public API remains unchanged; internal refactoring only
4. **Testability**: Modules can be tested independently

## Module Architecture

```
lua/sibling_jump/
├── init.lua                  (397 lines) - Public API & orchestration
├── config.lua                (153 lines) - Static configuration
├── utils.lua                 (144 lines) - Pure utility functions
├── node_finder.lua           (420 lines) - AST node detection
├── navigation.lua            (62 lines)  - Sibling finding logic
├── positioning.lua           (36 lines)  - Cursor positioning
└── special_modes/
    ├── method_chains.lua     (118 lines) - Method chain navigation
    ├── if_else_chains.lua    (276 lines) - If-else navigation
    └── switch_cases.lua      (230 lines) - Switch case navigation
```

---

## Core Modules

### 1. `init.lua` - Entry Point & Orchestration

**Purpose**: Public API, setup, and navigation orchestration

**Key Functions**:
- `M.setup(opts)` - Plugin configuration
- `M.jump_to_sibling(opts)` - Main navigation function
- Buffer management commands (enable/disable/toggle/status)

**Architecture Pattern**: Coordinator
- Requires all other modules
- Coordinates between special modes and fallback navigation
- Handles vim integration (keymaps, commands, autocmds)

**Navigation Flow**:
```lua
function M.jump_to_sibling(opts)
  -- 1. Try special navigation modes (in priority order)
  if method_chains.detect(node) then
    -- Navigate method chain
  elseif if_else_chains.detect(node) then
    -- Navigate if-else chain
  elseif switch_cases.detect(node) then
    -- Navigate switch cases
  end
  
  -- 2. Fallback to regular sibling navigation
  local node, parent = node_finder.get_node_at_cursor()
  local target = navigation.get_sibling_node(node, parent, forward)
  -- Jump to target
end
```

### 2. `config.lua` - Static Configuration

**Purpose**: Centralize all node type definitions and configuration constants

**Key Exports**:
- `COMMENT_DELIMITERS` - Language-specific comment markers
- `PUNCTUATION` - Skippable punctuation nodes
- `MEANINGFUL_TYPES` - Node types to navigate between
- `CONTAINER_TYPES` - Nodes that can contain whitespace
- `LIST_CONTAINERS` - List-like structures (arrays, parameters, etc.)

**Helper Functions**:
- `is_meaningful_type(node_type)` - Check if type is meaningful
- `is_container_type(node_type)` - Check if type is a container
- `is_list_container_type(node_type)` - Check if type is a list container

**Design Notes**:
- Single source of truth for all node types
- Easy to add support for new languages (just add node types here)
- Grouped by category for readability

### 3. `utils.lua` - Pure Utility Functions

**Purpose**: Stateless helper functions used across modules

**Key Functions**:
- `is_comment_node(node)` - Detect comment nodes
- `is_skippable_node(node)` - Detect nodes to skip (comments, punctuation, empty)
- `is_meaningful_node(node)` - Detect navigable nodes (with context awareness)
- `find_node_index(node, node_list)` - Find node position in list
- `collect_union_members(union_node)` - Recursively collect union type members

**Design Notes**:
- All functions are pure (no side effects)
- Used by multiple modules
- Special handling for context-dependent nodes (identifier, type_identifier)

### 4. `node_finder.lua` - AST Node Detection

**Purpose**: Complex logic for finding the appropriate node at cursor position

**Key Function**:
- `get_node_at_cursor(bufnr)` - Main entry point

**Algorithm**:
```
1. Get treesitter parser and AST root
2. Find smallest node at cursor position
3. Adjust for leading whitespace
4. Handle special cases:
   - Whitespace between statements → return marker with closest nodes
   - Comments → return marker with escape targets
   - JSX elements → navigate to tag name
   - Container nodes → find meaningful children
   - List containers (arrays, params) → navigate elements
   - Object properties → navigate between properties
5. Walk up AST to find meaningful navigation unit
6. Respect context boundaries (don't exit single-element containers)
```

**Special Return Values**:
```lua
-- Normal case: return node and its parent
return node, parent

-- Whitespace case: return special marker
return {
  _on_whitespace = true,
  closest_before = node,
  closest_after = node,
  parent = parent
}, parent

-- Comment case: return special marker
return {
  _on_comment = true,
  closest_before = node,
  closest_after = node,
  parent = parent,
  cursor_row = row
}, parent
```

**Design Notes**:
- This is the most complex module (420 lines)
- Heavy use of treesitter API
- Context-aware (respects nesting levels)
- Prevents "context escape" (jumping out of single-element lists)

### 5. `navigation.lua` - Sibling Finding

**Purpose**: Find next/previous sibling at same nesting level

**Key Functions**:
- `get_sibling_nodes(parent)` - Get all navigable children of parent
- `get_sibling_node(node, parent, forward)` - Find next/prev sibling

**Algorithm**:
```
1. Get all children of parent
2. Filter out skippable nodes (comments, punctuation)
3. Handle special cases:
   - union_type: recursively collect all members
   - JSX elements: skip tag name identifiers
4. Find current node's index in sibling list
5. Return sibling at next/previous index
```

### 6. `positioning.lua` - Cursor Positioning

**Purpose**: Adjust cursor position for better UX

**Key Function**:
- `get_target_position(node)` - Get adjusted cursor position

**Adjustments**:
- JSX elements: Land on tag name instead of `<` bracket
- Default: Land at node start position

**Design Notes**:
- Small, focused module
- Easy to extend for other node types
- Improves navigation feel

---

## Special Navigation Modes

Special modes handle complex navigation patterns that don't fit regular sibling navigation.

### Common Interface Pattern

Each special mode follows this interface:

```lua
local M = {}

-- Detect if we're in this navigation mode
-- Returns: boolean, [context_data...]
function M.detect(node)
  -- Walk up AST to detect pattern
  -- Return false if not in this mode
  -- Return true + context if in this mode
end

-- Navigate within this mode
-- Returns: target_node, target_row, target_col (or nils for boundary)
function M.navigate(context, position, forward, ...)
  -- Navigate forward/backward
  -- Return nil at boundaries (no-op)
end

return M
```

### 7. `special_modes/method_chains.lua` - Method Chain Navigation

**Pattern**: `obj.foo().bar().baz()`

**Detection**:
- Walk up to find `property_identifier`
- Check if it's in a `call_expression` inside a `member_expression`
- Verify there's a previous or next method call

**Navigation**:
- Forward: Move down the chain (`.bar()` → `.baz()`)
- Backward: Move up the chain (`.baz()` → `.bar()`)
- Returns `nil` at chain boundaries

**Design Notes**:
- Treesitter structure is complex (nested member/call expressions)
- Must verify we're actually in a chain (not just a single call)

### 8. `special_modes/if_else_chains.lua` - If-Else Navigation

**Pattern**: `if → else if → else if → else`

**Detection**:
- Walk up to find `if_statement` or `else_clause`/`elseif_statement`
- Find outermost `if_statement` in chain
- Determine current position (main if = 0, first else = 1, etc.)

**Navigation**:
- Forward: `if` → first `else if` → ... → last `else` → next statement
- Backward: next statement → last `else` → ... → first `else if` → `if` → prev statement
- Handles both JavaScript (`else_clause` nested) and Lua (`elseif_statement` direct children)

**Design Notes**:
- Most complex special mode (276 lines)
- Recursive collection of else clauses for JS/TS
- Requires `get_sibling_node` dependency (passed in to avoid circular dependency)

### 9. `special_modes/switch_cases.lua` - Switch Case Navigation

**Pattern**: `case 1 → case 2 → ... → default`

**Detection**:
- Walk up to find `switch_case` or `switch_default`
- Find parent `switch_statement`
- Check for higher-priority contexts (don't navigate cases if inside statements)
- Determine current case index

**Navigation**:
- Forward: case 1 → case 2 → ... → last case → no-op
- Backward: last case → ... → case 2 → case 1 → no-op
- No-op at boundaries (doesn't exit switch)

**Design Notes**:
- Priority checks prevent unwanted navigation (prefer statements over cases)
- Respects statement boundaries within cases

---

## Data Flow

### Jump Navigation Flow

```
User presses <C-j> or <C-k>
    ↓
init.jump_to_sibling()
    ↓
Check special modes (in order):
    → method_chains.detect()
    → if_else_chains.detect()  
    → switch_cases.detect()
    ↓
If in special mode:
    → [mode].navigate() → positioning.get_target_position() → Move cursor
    ↓
Else (fallback):
    → node_finder.get_node_at_cursor()
        ↓
    Handle special markers (_on_whitespace, _on_comment)
        ↓
    navigation.get_sibling_node()
        ↓
    Handle backward jump to if-else (find last else)
        ↓
    positioning.get_target_position() → Move cursor
```

### Module Dependencies

```
init.lua
├── requires → config (static data)
├── requires → utils (helper functions)
├── requires → node_finder (AST navigation)
├── requires → navigation (sibling finding)
├── requires → positioning (cursor adjustment)
└── requires → special_modes/* (pattern detection)

node_finder.lua
├── requires → config (node type checks)
└── requires → utils (node classification)

navigation.lua
└── requires → utils (node filtering)

special_modes/switch_cases.lua
└── requires → utils (node classification)

special_modes/if_else_chains.lua
└── receives get_sibling_node as parameter (avoiding circular dependency)

special_modes/method_chains.lua
└── (no dependencies - pure AST walking)

positioning.lua
└── (no dependencies - pure positioning logic)

utils.lua
└── requires → config (node type lists)

config.lua
└── (no dependencies - pure data)
```

---

## Extension Points

### Adding a New Language

1. **Add node types to `config.lua`**:
   ```lua
   -- In MEANINGFUL_TYPES
   "ruby_statement",      -- Ruby
   "ruby_method_def",     -- Ruby
   ```

2. **Add comment delimiters if needed**:
   ```lua
   -- In COMMENT_DELIMITERS
   ["#"] = true,  -- Ruby/Python/Shell
   ```

3. **Test thoroughly** with fixtures

### Adding a New Special Navigation Mode

1. **Create module**: `lua/sibling_jump/special_modes/my_mode.lua`

2. **Implement interface**:
   ```lua
   local M = {}
   
   function M.detect(node)
     -- Return false, nil, 0 if not in this mode
     -- Return true, context, position if in this mode
   end
   
   function M.navigate(context, position, forward)
     -- Return target_node, target_row, target_col
     -- Return nil, nil, nil at boundaries
   end
   
   return M
   ```

3. **Register in `init.lua`**:
   ```lua
   local my_mode = require("sibling_jump.special_modes.my_mode")
   
   -- In jump_to_sibling, add after other detections:
   local in_mode, ctx, pos = my_mode.detect(node)
   if in_mode then
     local target, row, col = my_mode.navigate(ctx, pos, forward)
     -- ... handle jump
   end
   ```

4. **Write tests** in `tests/fixtures/` and `tests/run_tests.lua`

### Adding Custom Positioning

Extend `positioning.lua`:

```lua
function M.get_target_position(node)
  local node_type = node:type()
  
  -- Add your custom positioning
  if node_type == "my_custom_node" then
    -- Return adjusted position
    return custom_row, custom_col
  end
  
  -- ... existing logic
end
```

---

## Testing Strategy

### Test Structure

- **Test runner**: `tests/test_runner.sh` (bash wrapper)
- **Test logic**: `tests/run_tests.lua` (direct Neovim execution)
- **Fixtures**: `tests/fixtures/*.{ts,js,tsx,jsx,lua,java,c,cs}`

### Why Direct Execution?

We don't use plenary.nvim because:
- Plenary's test isolation breaks treesitter parser access
- Direct execution preserves full Neovim environment
- Simpler, faster test runs

### Test Pattern

```lua
test("Description", function()
  -- 1. Open fixture file
  vim.cmd("edit " .. fixtures_dir .. "my_test.ts")
  
  -- 2. Position cursor
  vim.api.nvim_win_set_cursor(0, {5, 0})  -- Line 5, col 0
  
  -- 3. Execute jump
  sibling_jump.jump_to_sibling({ forward = true })
  
  -- 4. Assert new position
  local pos = vim.api.nvim_win_get_cursor(0)
  assert_eq(7, pos[1], "Should jump to line 7")
end)
```

### Running Tests

```bash
# All tests
bash tests/test_runner.sh

# JS compatibility tests
lua tests/run_js_tests.lua
```

---

## Performance Considerations

### Optimization Strategies

1. **Lazy loading**: Special modes only loaded when needed (via `require`)
2. **Early returns**: Check quick conditions before expensive AST walks
3. **Bounded depth**: Tree walking has max depth limits (typically 10-20 levels)
4. **No async**: All operations are synchronous (navigation must be instant)

### Treesitter Caching

- Parser is obtained with `pcall` for safety
- Neovim caches parsers automatically
- No manual caching needed in our code

### Module Loading

- Lua's `require` caches modules after first load
- Module dependencies resolved once at startup
- No runtime overhead for multiple requires

---

## Known Limitations & Future Improvements

### Current Limitations

1. **Single-element contexts**: No navigation in single-property objects (by design - prevents context escape)
2. **Language coverage**: Best support for TS/JS/JSX/TSX/Lua; basic support for Java/C/C#/Python
3. **Complex nesting**: Very deeply nested structures (>20 levels) may hit depth limits

### Potential Improvements

1. **State Machine Refactor**: Could make `node_finder.lua` more explicit with state machine pattern
2. **Strategy Registry**: Dynamic registration of special modes instead of hardcoded checks
3. **Performance Metrics**: Add optional timing measurements for optimization
4. **Language Plugins**: Allow users to register custom language support via config
5. **AST Caching**: Cache parsed AST nodes for repeated navigation (probably overkill)

---

## Debugging Tips

### Enable Treesitter Playground

```vim
:TSPlaygroundToggle
```

Inspect node structure to understand navigation issues.

### Print Node Info

Add temporary debug prints:

```lua
local function debug_node(node)
  if not node then return end
  print("Type:", node:type())
  print("Start:", node:start())
  print("Parent:", node:parent() and node:parent():type() or "nil")
end
```

### Test Individual Modules

```lua
-- In Neovim
:lua local utils = require("sibling_jump.utils")
:lua print(vim.inspect(utils.is_meaningful_node(some_node)))
```

### Check Configuration

```lua
:lua local config = require("sibling_jump.config")
:lua print(vim.inspect(config.MEANINGFUL_TYPES))
```

---

## Architecture Decision Records

### Why Not Strategy Pattern?

**Considered**: Full strategy pattern with pluggable strategies

**Decision**: Modular detection with explicit priority checks

**Reasoning**:
- Simpler to understand (explicit flow in `jump_to_sibling`)
- Easier to debug (clear call hierarchy)
- Performance (no strategy lookup overhead)
- Sufficient extensibility (easy to add new modes)

### Why Split Special Modes?

**Considered**: Keep all special navigation in one file

**Decision**: Separate file per mode

**Reasoning**:
- Each mode is independently complex (100-270 lines)
- Easier to test in isolation
- Clear boundaries between patterns
- Easier for contributors to understand one mode at a time

### Why Keep node_finder.lua Large?

**Considered**: Further split into context handlers

**Decision**: Keep as single module

**Reasoning**:
- Highly interconnected logic (many special cases depend on each other)
- Splitting would require extensive parameter passing
- Easier to understand algorithm as a whole
- Already well-commented with clear sections

---

## Changelog of Refactoring

**From**: Monolithic 1,719-line `init.lua`
**To**: 9 focused modules totaling 1,836 lines

### Key Changes

1. ✅ Configuration extracted to `config.lua`
2. ✅ Utilities extracted to `utils.lua`
3. ✅ Navigation logic extracted to `navigation.lua`
4. ✅ Positioning logic extracted to `positioning.lua`
5. ✅ Method chains extracted to `special_modes/method_chains.lua`
6. ✅ If-else chains extracted to `special_modes/if_else_chains.lua`
7. ✅ Switch cases extracted to `special_modes/switch_cases.lua`
8. ✅ Node finding extracted to `node_finder.lua`
9. ✅ Main file reduced by 77% (1,719 → 397 lines)

### Test Results

- All 136 tests pass ✅
- No functional changes
- No performance regression
- Fully backward compatible

---

## References

- **Treesitter Documentation**: https://neovim.io/doc/user/treesitter.html
- **Plugin Development**: https://neovim.io/doc/user/lua-guide.html
- **Test Suite**: See `tests/README.md`
- **Agent Instructions**: See `AGENTS.md` for AI-assisted development guidelines
