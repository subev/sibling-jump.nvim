# Architecture

## Core Concept

Two navigation modes with different philosophies:

1. **Sibling Navigation** - Jump between nodes at the same nesting level (horizontal movement)
2. **Block-Loop** - Cycle through structural boundaries of a single block (vertical movement)

## Sibling Navigation

### Key Insight: Context-Aware Detection

The plugin walks up the AST to find "meaningful" parent contexts, then navigates between siblings within that context.

```
if (condition) {
  statement1;  ← Navigate between these
  statement2;  ← at statement level
}
```

### Special Modes (Priority Order)

1. **Method Chains** - Detects `.method()` patterns, navigates between methods
2. **If-Else Chains** - Detects `if/else if/else`, treats entire chain as unit
3. **Switch Cases** - Detects switch statements, navigates between case clauses
4. **Fallback** - Regular sibling navigation in any context

**Why priority matters:** Without it, `if/else if` would navigate between `if` and `else if` as separate statements instead of treating them as one unit.

### Module Structure

```
init.lua           - Public API, orchestrates navigation
config.lua         - Static configuration (meaningful node types)
node_finder.lua    - Walks AST to find navigation node + parent
navigation.lua     - Finds sibling nodes
positioning.lua    - Places cursor on sibling
utils.lua          - Shared helpers
special_modes/     - Priority-ordered special navigation patterns
  ├── method_chains.lua
  ├── if_else_chains.lua
  └── switch_cases.lua
```

**Data flow:** `init` → `node_finder` → check special modes → `navigation` → `positioning`

## Block-Loop

### Key Insight: Handler Priority System

Navigate boundaries of whatever construct you're on, from most specific to most general:

```typescript
const router = {
  method: procedure      // ← Cursor here
    .input(z.object())   // ← Or here  
    .mutation(...)       // ← Or here
}
```

Each cursor position matches a different handler.

### Handler Priority

1. **object_property_values** - Property names whose values are call expressions
2. **call_expressions** - Individual method/function calls  
3. **switch_cases** - Switch statement boundaries
4. **loops** - For/while loop boundaries
5. **if_blocks** - If/else boundaries
6. **declarations** - const/let/var/type/function declarations

**Example:** Cursor on `.input` → `call_expressions` wins (jumps to that method's closing paren), not `object_property_values` (which would jump to property name).

### Module Structure

```
block_loop.lua                  - Orchestrator, tries handlers in priority order
block_loop/
  ├── object_property_values.lua - { prop: chain() } → )
  ├── call_expressions.lua      - foo.bar() → )
  ├── switch_cases.lua          - switch → case → default → }
  ├── loops.lua                 - for/while → body → }
  ├── if_blocks.lua             - if → else if → else → }
  ├── declarations.lua          - const/type/function → closing
  └── utils.lua                 - Shared helpers for block-loop handlers
```

**Data flow:** `block_loop` → try each handler → first match wins → navigate within that construct

**Modes:** Block-loop supports both normal mode (navigate to next position) and visual mode (select entire block from first to last position).

### Handler Interface

Each handler implements:
```lua
detect(node, cursor_pos) → bool, context
  -- Returns: detected (bool), context (table with positions array)
  
navigate(context, cursor_pos, mode) → target_position
  -- mode: "normal" | "visual"
  -- Returns: {row, col} for next position, or nil at boundaries
```

**Context structure:**
```lua
context = {
  positions = {
    {row = 10, col = 0},  -- 1-indexed for nvim API
    {row = 15, col = 2},
    -- ...
  },
  -- handler-specific fields...
}
```

## Key Design Decisions

### 1. Why Two Modes?

**Sibling navigation** is for moving *between* constructs at the same level.
**Block-loop** is for moving *within* a single construct's boundaries.

Different mental models, different use cases.

### 2. Why Priority-Based Handlers?

TreeSitter gives us nested structures. Cursor on `.input` could match:
- A `call_expression` (the `.input()` call)
- A `pair` (the property `method: ...` in the object)
- A `lexical_declaration` (the entire `const router = ...`)

Priority ensures we match the most specific construct.

### 3. Why Column Matching in call_expressions?

When method name and closing paren are on the same line:
```typescript
.input(z.object({ id: z.string() }))
```

Without column matching, navigator can't tell if you're at the method name or closing paren.

### 4. Why Separate object_property_values Handler?

Property names need different behavior than method names:
- Property name → end of entire property value
- Method name → end of just that method call

### 5. Why Language-Specific Handling in Declarations?

Lua requires special handling:
- **End keyword detection**: Lua's AST exposes `end` as a separate child node, unlike TypeScript/JavaScript where closing `}` is part of the block
- **Table literals**: Lua's `local config = { ... }` needs the closing `}` position from the table_constructor node
- **Assignment statements**: Lua uses `assignment_statement` → `expression_list`, not `variable_declarator`

Without these checks, navigation would fail or jump to wrong positions in Lua code.

## Extension Points

### Adding a New Special Mode (Sibling Navigation)

1. Create handler in `special_modes/`
2. Implement: `detect(node, pos, cursor)` and `navigate(...)`  
3. Add to `init.lua` handlers list (order matters!)

### Adding a New Block-Loop Handler

1. Create handler in `block_loop/`
2. Implement: `detect(node, cursor_pos)` and `navigate(context, cursor_pos, mode)`
3. Add to `block_loop.lua` handlers list (order matters!)
4. Place in priority order (most specific first)

## Testing Philosophy

- **Main tests**: Comprehensive coverage of sibling navigation patterns
- **Block-loop tests**: Focused on boundary cycling and handler priority
- Tests document expected behavior, not implementation details
- Fixtures use real-world code patterns
- All tests must pass before and after any changes

## Common Pitfalls

1. **0-indexed vs 1-indexed**: TreeSitter uses 0-indexed positions, Neovim API uses 1-indexed
2. **Node types vary by language**: Check `config.lua` MEANINGFUL_TYPES when adding language support
3. **Priority matters**: Wrong handler order = wrong navigation behavior
4. **Column matching**: Use ranges, not exact match, for cursor positions (users won't be perfectly aligned)

## Performance

- No caching (Neovim handles TreeSitter efficiently)
- Early returns on failures
- Bounded loops (max depth checks when walking AST)
- Special modes checked before expensive fallback navigation
