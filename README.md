# sibling-jump.nvim

Navigate between sibling nodes in your code using Tree-sitter. Context-aware navigation that keeps you at the right level of abstraction.

https://github.com/user-attachments/assets/62c59d9a-8593-49b2-b124-1e547c2853cd

## Features

- **Context-aware navigation**: Jumps between meaningful code units (statements, properties, array elements, etc.)
- **Block-loop** (separate keybinding): Cycle through a block's structural boundaries (start → branches → end → back to start)
- **Visual mode block selection**: Select entire blocks with block-loop in visual mode
- **Any Tree-sitter grammar**: navigation units are found by tree shape and indentation, not by per-language node names; tested with TypeScript, JavaScript, JSX, TSX, Lua, Python, Swift, Java, C, C#
- **Smart boundary detection**: Prevents navigation from jumping out of context
- **Method chain navigation**: Seamlessly navigate through method chains like `obj.foo().bar().baz()`
- **If-else chain navigation**: Jump between if/else-if/else clauses
- **JSX/TSX support**: Navigate between JSX elements and attributes
- **Count support**: Use `3<C-j>` to jump 3 siblings forward

## Sibling Navigation

Jump between nodes at the same nesting level. When your cursor is on a statement, property, or element, pressing the navigation key moves you to the next/previous sibling.

**Supported contexts:**

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
- Lines of a chained expression (`view.modifier()` / `.filter {}.map {}`), flowing into the next statement
- Class/struct members, enum cases, switch entries, closure bodies in any language

A list with a single element (`foo(x)`, `[1]`, `import { a }`) has no siblings, so the jump moves the enclosing statement instead. A block with a single statement never escapes.

## Block-Loop (Optional Keybinding)

A complementary feature with its own keybinding. When triggered, it cycles through a block's structural boundaries instead of jumping to siblings.

https://github.com/user-attachments/assets/de9d8239-0e4e-4a39-8f33-0b77bca87876

**Supported constructs:**

- `const`/`let`/`var` declarations → cycles between keyword and closing `}`/`)`
- `if`/`else if`/`else` blocks → cycles through all branches and closing `}`
- `for`/`while` loops → cycles between keyword and closing `}`
- `switch` statements → cycles through `switch`, each `case`/`default`, and closing `}`
- `function` declarations → cycles between keyword and closing `}`
- `type`/`interface` declarations → cycles between keyword and closing `}`
- Method chains → cycles between each method in the chain

## Supported Languages

Sibling navigation does not know any language's node names: it decides what a line stands for from the shape of the
syntax tree and the indentation, so any grammar Neovim can parse works. Tested against fixtures:

- **TypeScript / TSX / JavaScript / JSX** (extensive)
- **Lua** (extensive)
- **Swift** (SwiftUI-style file: members, enum cases, switch entries, modifier chains, closures, guard, do/catch)
- **Python**, **Java**, **C**, **C#** (basic)

Block-loop is still driven by node names and covers TypeScript/JavaScript and Lua.

If a construct in your language navigates wrongly, please [open an issue](https://github.com/subev/sibling-jump.nvim/issues) with a minimal example.

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "subev/sibling-jump.nvim",
  config = function()
    require("sibling_jump").setup({
      next_key = "<C-j>",        -- Jump to next sibling (default)
      prev_key = "<C-k>",        -- Jump to previous sibling (default)
      block_loop_key = "<C-l>",  -- Cycle through block boundaries (optional)
      center_on_jump = false,    -- Center screen after jump (default: false)
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
      block_loop_key = "<C-l>",  -- optional
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
  block_loop_key = "<C-l>",  -- optional
})
EOF
```

## Usage

Once installed, use your configured keybindings:

- `<C-j>` - Jump to next sibling
- `<C-k>` - Jump to previous sibling
- `3<C-j>` - Jump 3 siblings forward (works with any count)
- `<C-l>` - Cycle through block boundaries (if `block_loop_key` configured)
- `V` then `<C-l>` - Select entire block in visual mode

### Examples

**Navigate object properties:**

```typescript
const obj = {
  foo: 1, // <C-j> →
  bar: 2, // <C-j> →
  baz: 3, // cursor here
};
```

**Navigate array elements:**

```typescript
const arr = [
  element1, // <C-j> →
  element2, // <C-j> →
  element3, // cursor here
];
```

**Navigate statements:**

```typescript
const x = 1; // <C-j> →
const y = 2; // <C-j> →
return x + y; // cursor here
```

**Navigate method chains:**

```typescript
obj
  .foo() // <C-j> →
  .bar() // <C-j> →
  .baz(); // cursor here
```

**Navigate if-else chains:**

```typescript
if (condition1) {
  // <C-j> →
  // ...
} else if (condition2) {
  // <C-j> →
  // ...
} else {
  // cursor here
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

### Block-Loop Examples

**Cycle through a const declaration:**

```typescript
const config = {
  // cursor on "const", <C-j> →
  foo: 1,
  bar: 2,
}; // ← lands here, <C-j> cycles back to "const"
```

**Cycle through if-else blocks:**

```typescript
if (condition1) {
  // cursor on "if", <C-j> →
  // ...
} else if (cond2) {
  // ← <C-j> →
  // ...
} else {
  // ← <C-j> →
  // ...
} // ← lands here, <C-j> cycles back to "if"
```

**Cycle through a switch statement:**

```typescript
switch (
  value // cursor on "switch", <C-j> →
) {
  case 1: // ← <C-j> →
    break;
  case 2: // ← <C-j> →
    break;
  default: // ← <C-j> →
    break;
} // ← lands here, <C-j> cycles back to "switch"
```

**Cycle through a for loop:**

```typescript
for (let i = 0; i < 10; i++) {
  // cursor on "for", <C-j> →
  console.log(i);
} // ← lands here, <C-j> cycles back
```

**Visual mode progressive selection:**

In visual mode, block-loop progressively extends the selection with each keypress:

```typescript
if (condition1) {     // v to start visual, <C-l> →
  // ...
} else if (cond2) {   // ← selection extends here, <C-l> →
  // ...
} else {              // ← selection extends here, <C-l> →
  // ...
}                     // ← selection extends here, <C-l> wraps back
```

This lets you precisely control how much of the block to select - useful for selecting just the if-else-if portion without the final else, for example.

## Configuration

The `setup()` function accepts the following options:

```lua
require("sibling_jump").setup({
  -- Key to jump to next sibling (default: "<C-j>")
  next_key = "<C-j>",

  -- Key to jump to previous sibling (default: "<C-k>")
  prev_key = "<C-k>",

  -- Key to cycle through block boundaries (default: nil = disabled)
  -- When set, enables block-loop feature in both normal and visual modes
  block_loop_key = "<C-l>",

  -- Whether to center screen after each jump (default: false)
  center_on_jump = false,

  -- Separate center setting for block-loop (default: uses center_on_jump value)
  block_loop_center_on_jump = false,

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

## How It Works

sibling-jump uses Neovim's Tree-sitter integration to understand your code's structure. Instead of jumping by lines or words, it jumps between meaningful syntactic units.

**Sibling Navigation** (`<C-j>`/`<C-k>`):

1. Finds the Tree-sitter nodes that start on the cursor line
2. If one of them is a member of a comma/pipe separated list, navigates that list
3. Otherwise takes the innermost one that has peers: children of its parent at the same column, or the
   lines of the chained expression it belongs to
4. Jumps to the next/previous peer, staying within the same level of abstraction

**Block-Loop** (`<C-l>` if configured):

1. Detects the block construct you're on (`const`, `if`, `for`, `switch`, etc.)
2. Collects all structural boundary positions (start, branches, end)
3. Cycles through them in order, wrapping from end back to start

## Testing

The plugin includes a comprehensive test suite with tests covering all supported navigation scenarios.

**Run tests:**

```bash
cd /path/to/sibling-jump.nvim
bash tests/test_runner.sh
```

All tests pass with Tree-sitter support for TypeScript/JavaScript/JSX/TSX.

## FAQ

### How is this different from treewalker.nvim?

**sibling-jump** stays within your current context. When you are in a function you are jumping only inside of its top level statements/expressions. when you're in an object, it jumps between properties. When you're in an array, it jumps between elements. When you're in an if-else chain, it treats the entire chain as one navigable unit.

**treewalker.nvim** is great for full AST traversal (4 directions, moving between nesting levels), but sibling-jump focuses on "just working" horizontally - staying at the same level of abstraction without accidentally jumping out of your current block. The following shouldn't be possible with sibling-jump.nvim

<img width="1496" height="955" alt="Screenshot 2026-01-04 at 15 45 13" src="https://github.com/user-attachments/assets/e5d785d7-1840-4c15-8be6-0a2424b76528" />

sibling-jump also has a **block-loop** feature that cycles through a construct's boundaries (if → else if → else → closing brace). In visual mode, it selects the entire block - useful for quickly selecting an if-else chain, function, or declaration for deletion/yanking.

## Alternatives

- **[syntax-tree-surfer](https://github.com/ziontee113/syntax-tree-surfer)** - Publicly archived. Had visual selection and swap features that inspired many Tree-sitter navigation plugins.

- **[nvim-treehopper](https://github.com/mfussenegger/nvim-treehopper)** - Leap-like approach with label-based jumps to annotated nodes, rather than direct next/prev movements.

- **[tree-climber.nvim](https://github.com/drybalka/tree-climber.nvim)** - Fine-grained AST node navigation. Gives more literal syntax tree access vs sibling-jump's context-aware approach.

- **[nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)** - Node-type-specific movements and swaps. sibling-jump is node-type agnostic.

For more Tree-sitter motion plugins, see [awesome-neovim#motion](https://github.com/rockerBOO/awesome-neovim/?tab=readme-ov-file#motion).

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

**See [ROADMAP.md](ROADMAP.md)** for planned features and future direction.

## License

MIT

## Credits

Developed by [@subev](https://github.com/subev)

## Development

You can develop this plugin directly in your lazy.nvim installation directory.

For AI-assisted development, see [`CLAUDE.md`](CLAUDE.md) (entry point) and [`AGENTS.md`](AGENTS.md) for project context, architecture details, and development guidelines.
