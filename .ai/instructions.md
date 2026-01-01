# sibling-jump.nvim - AI Development Instructions

## Quick Reference

**sibling-jump.nvim** is a Neovim plugin for context-aware navigation between sibling nodes using Tree-sitter.

**Primary Language Support:** TypeScript/JavaScript/JSX/TSX, Lua  
**Partial Support:** Python, Java, C, C++, C#

## Essential Information

### Module Naming Convention

**Critical:** The plugin uses `sibling_jump` (with underscore) internally but the repo is `sibling-jump.nvim` (with hyphen).

- **Lua module:** `require("sibling_jump")`
- **Git repo:** `subev/sibling-jump.nvim`
- **Plugin file:** `plugin/sibling-jump.lua`

Always use underscore when requiring the module or referencing Lua code!

### Running Tests

```bash
cd /path/to/sibling-jump.nvim
bash tests/test_runner.sh
```

**DO NOT use plenary.nvim for tests!** The test suite uses a custom direct test runner because plenary's test isolation breaks Tree-sitter parser access.

### Development Rules

1. **Always run tests after any change** - All tests must pass
2. **Never break backward compatibility** - Public API is sacred
3. **Always ask before committing** - Never auto-commit changes
4. **Test-driven development** - Write failing test before fixing bugs
5. **Use underscore in module names** - `sibling_jump` not `sibling-jump`

## Comprehensive Documentation

For detailed development guidelines, architecture documentation, and best practices, see:

- **`AGENTS.md`** - Complete AI agent development instructions
- **`ARCHITECTURE.md`** - Module structure and design decisions
- **`README.md`** - User-facing documentation

## Quick Architecture Overview

### Two Navigation Modes

1. **Sibling Navigation** - Jump between nodes at the same nesting level (horizontal movement)
2. **Block-Loop** - Cycle through structural boundaries of a single block (vertical movement)

### Project Structure

```
lua/sibling_jump/
├── init.lua              - Public API & orchestration
├── config.lua            - Static configuration
├── node_finder.lua       - AST node detection
├── navigation.lua        - Sibling finding
├── positioning.lua       - Cursor positioning
├── utils.lua             - Shared helpers
├── special_modes/        - Special navigation patterns
└── block_loop/           - Block boundary navigation
    ├── block_loop.lua    - Orchestrator
    └── */                - Individual handlers
```

## Common Commands

```bash
# Run tests
bash tests/test_runner.sh

# Check Tree-sitter structure
:InspectTree  # Neovim 0.9+
:TSPlaygroundToggle  # With nvim-treesitter-playground

# Debug navigation
:lua print(vim.treesitter.get_node():type())
```

## When in Doubt

1. Check `AGENTS.md` for comprehensive guidelines
2. Check `ARCHITECTURE.md` for design decisions
3. Use `:InspectTree` to inspect Tree-sitter structure
4. Run tests frequently to catch regressions
5. Ask the user!
