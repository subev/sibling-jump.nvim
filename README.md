# sibling-jump.nvim

Navigate between sibling nodes in your code using Tree-sitter. Context-aware navigation that keeps you at the right level of abstraction.



https://github.com/user-attachments/assets/62c59d9a-8593-49b2-b124-1e547c2853cd


## Features

- **Context-aware navigation**: Jumps between meaningful code units (statements, properties, array elements, etc.)
- **Multi-language support**: Works with TypeScript, JavaScript, JSX, TSX, Lua, Java, C, C#, Python, and more
- **Smart boundary detection**: Prevents navigation from jumping out of context
- **Method chain navigation**: Seamlessly navigate through method chains like `obj.foo().bar().baz()`
- **If-else chain navigation**: Jump between if/else-if/else clauses
- **JSX/TSX support**: Navigate between JSX elements and attributes
- **Count support**: Use `3<C-j>` to jump 3 siblings forward

## Supported Navigation Contexts

- Statements (variable declarations, if/for/while, return, etc.)
- Object properties and type properties
- Array elements
- Function parameters and arguments
- Import specifiers
- JSX elements and attributes
- Method chains
- If-else-if chains
- Generic type parameters
- Union type members
- And more!

## Supported Languages

**sibling-jump.nvim** works with any language that has Tree-sitter support. The following languages have been tested:

### Extensively Tested
- **TypeScript** (.ts)
- **TSX** (.tsx)
- **JavaScript** (.js)
- **JSX** (.jsx)
- **Lua** (.lua)

### Basic Support (Lightly Tested)
- **Java** (.java)
- **C** (.c)
- **C++** (.cpp)
- **C#** (.cs)
- **Python** (.py)

The plugin should work with most languages out of the box. If you encounter issues with a specific language, please [open an issue](https://github.com/yourusername/sibling-jump.nvim/issues) with a minimal example.

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "subev/sibling-jump.nvim",
  config = function()
    require("sibling_jump").setup({
      next_key = "<C-j>",      -- Jump to next sibling (default)
      prev_key = "<C-k>",      -- Jump to previous sibling (default)
      center_on_jump = false,  -- Center screen after jump (default: false)
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "subev/sibling-jump.nvim",
  config = function()
    require("sibling_jump").setup({
      next_key = "<C-j>",
      prev_key = "<C-k>",
    })
  end,
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'subev/sibling-jump.nvim'

" In your init.vim or after/plugin/sibling-jump.lua:
lua << EOF
require("sibling_jump").setup({
  next_key = "<C-j>",
  prev_key = "<C-k>",
})
EOF
```

## Usage

Once installed, use your configured keybindings:

- `<C-j>` - Jump to next sibling
- `<C-k>` - Jump to previous sibling
- `3<C-j>` - Jump 3 siblings forward (works with any count)

### Examples

**Navigate object properties:**
```typescript
const obj = {
  foo: 1,     // <C-j> →
  bar: 2,     // <C-j> →
  baz: 3,     // cursor here
}
```

**Navigate array elements:**
```typescript
const arr = [
  element1,   // <C-j> →
  element2,   // <C-j> →
  element3,   // cursor here
]
```

**Navigate statements:**
```typescript
const x = 1          // <C-j> →
const y = 2          // <C-j> →
return x + y         // cursor here
```

**Navigate method chains:**
```typescript
obj
  .foo()     // <C-j> →
  .bar()     // <C-j> →
  .baz()     // cursor here
```

**Navigate if-else chains:**
```typescript
if (condition1) {    // <C-j> →
  // ...
} else if (condition2) {   // <C-j> →
  // ...
} else {             // cursor here
  // ...
}
```

**Navigate JSX elements:**
```tsx
<>
  <Header />         // <C-j> →
  <Content />        // <C-j> →
  <Footer />         // cursor here
</>
```

## Configuration

The `setup()` function accepts the following options:

```lua
require("sibling_jump").setup({
  -- Key to jump to next sibling (default: "<C-j>")
  next_key = "<C-j>",
  
  -- Key to jump to previous sibling (default: "<C-k>")
  prev_key = "<C-k>",
  
  -- Whether to center screen after each jump (default: false)
  center_on_jump = false,
  
  -- Optional: Restrict keymaps to specific filetypes (default: nil = global keymaps)
  -- When set, creates buffer-local keymaps only for these filetypes
  filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
})
```

### Recommended Configuration for TypeScript/JavaScript

To avoid keymap conflicts and improve performance, restrict the plugin to TS/JS files:

```lua
{
  "subev/sibling-jump.nvim",
  ft = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
  config = function()
    require("sibling_jump").setup({
      next_key = "<C-j>",
      prev_key = "<C-k>",
      center_on_jump = true,
      filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
    })
  end,
}
```

This configuration:
- Lazy loads the plugin only when opening TS/JS files (`ft` parameter)
- Creates buffer-local keymaps only for TS/JS files (`filetypes` option)
- Keymaps won't interfere with other filetypes

## Manual Buffer Control

You can manually enable/disable sibling-jump for any buffer using these commands:

```vim
:SiblingJumpBufferEnable   " Enable for current buffer
:SiblingJumpBufferDisable  " Disable for current buffer
:SiblingJumpBufferToggle   " Toggle on/off for current buffer
:SiblingJumpBufferStatus   " Check if enabled for current buffer
```

**Use cases:**
- Testing the plugin in non-TS/JS files (Python, Lua, etc.)
- Temporarily enabling for a specific file without changing config
- Quick experiments with the plugin in different languages

**Example:**
```vim
" Open a Python file
:e script.py

" Enable sibling-jump manually
:SiblingJumpBufferEnable

" Now <C-j> and <C-k> work in this buffer!
```

## Requirements

- Neovim >= 0.9.0 (requires Tree-sitter support)
- Tree-sitter parser for your language (automatically installed for most languages)

## Language Support

**Primary support:**
- TypeScript / JavaScript
- TSX / JSX

**Partial support:**
- Python
- Lua
- Other languages with Tree-sitter parsers (may work, but not extensively tested)

## How It Works

sibling-jump uses Neovim's Tree-sitter integration to understand your code's structure. Instead of jumping by lines or words, it jumps between meaningful syntactic units at the same nesting level.

When you trigger a jump:
1. It finds the Tree-sitter node at your cursor
2. Identifies the appropriate "navigation context" (e.g., are you in an object, array, statement block?)
3. Finds the next/previous sibling node in that context
4. Jumps to it, staying within the same level of abstraction

## Testing

The plugin includes a comprehensive test suite with 86 tests covering all supported navigation scenarios.

**Run tests:**
```bash
cd /path/to/sibling-jump.nvim
bash tests/test_runner.sh
```

All tests pass with Tree-sitter support for TypeScript/JavaScript/JSX/TSX.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

**See [ROADMAP.md](ROADMAP.md)** for planned features and future direction.

## License

MIT

## Credits

Developed by [@subev](https://github.com/subev)

## Development

You can develop this plugin directly in your lazy.nvim installation directory.

For AI-assisted development, see [`.ai/instructions.md`](.ai/instructions.md) for comprehensive project context, architecture details, and development guidelines.
