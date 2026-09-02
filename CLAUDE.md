# sibling-jump.nvim

Neovim plugin: Tree-sitter based sibling navigation (`<C-j>`/`<C-k>`) plus an optional block-loop keymap that
cycles a construct's boundaries. Pure Lua, no dependencies beyond Neovim >= 0.9 and a parser for the buffer.

Read `AGENTS.md` (rules, workflow) and `ARCHITECTURE.md` (module map, handler priority) before changing code.
`ROADMAP.md` lists what is next: block-loop is still name-based; the JS method-chain and switch special modes could
retire in favor of the generic rules.

## Commands

```bash
bash tests/test_runner.sh   # all three suites; must be green before and after any change
```

Suites: `tests/run_tests.lua` (sibling navigation), `tests/run_block_loop_tests.lua`, `tests/run_js_tests.lua`.
No plenary. `tests/minimal_init.lua` loads parsers from `~/.local/share/nvim/lazy/nvim-treesitter` and disables
Tree-sitter highlighting (ftplugins that start it fail on Neovim/parser query drift; only the parser is needed).

## Layout

- `lua/sibling_jump/init.lua` public API: `setup`, `jump_to_sibling`, `enable/disable/toggle/status_for_buffer`,
  `block_loop()`; user commands `SiblingJumpBuffer*`. Keep signatures and option names stable.
- `node_finder.lua` decides the navigation unit, its parent and the member list for the cursor line by tree
  shape and indentation only (lists, same-column peers, chained expressions). Never add node-type names here;
  ARCHITECTURE.md explains the rules.
- `config.lua` skip lists only (comment delimiters, punctuation).
- `special_modes/` run before regular navigation: method chains (JS names), if/else chains, switch cases (JS
  names), try/catch. if/else and try/catch detect clauses by shape and cover Swift.
- `block_loop/` handlers are still node-name based (TS/JS/Lua).
- `block_loop.lua` + `block_loop/` priority-ordered handlers, each `detect(node, cursor) -> ok, ctx` and
  `navigate(ctx, cursor, mode) -> {row, col}`; positions are 1-indexed rows.
- `utils.get_node_at(bufnr, row, col)` is the single node lookup. It uses a one-character range like
  `vim.treesitter.get_node`; a zero-width range misses tokens on some grammars (Swift).

## Gotchas

- Tree-sitter rows/cols are 0-indexed, the cursor API is 1-indexed; `end_col` is exclusive.
  `block_loop/utils.closing_position(node)` is the one place that converts to "land on the closing bracket".
- Fixtures live in `tests/fixtures/`. Never point a test at a file under `lua/`: source edits shift its lines.
- Fixtures: TS/JS/TSX/JSX, Lua, Python, Swift (`swift_reader.swift`, SwiftUI shapes), a few Java/C/C# lines.
  For a new language or construct: write a fixture, walk each scenario forward to the end, press again, walk
  back, press again (`assert_walk` / `assert_round_trip` in `tests/run_tests.lua` do exactly this), then fix
  the shape rule that misfires.
- Debugging a grammar: `:InspectTree`, or dump nodes headlessly with
  `nvim --headless -u tests/minimal_init.lua -c "edit file.swift" -c "lua <dump script>"`. Swift has no keyword
  tokens for `func`/`let`/`for`; `else` and `catch_block` are named nodes there.
