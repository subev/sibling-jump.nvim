# Roadmap

This document outlines planned features and improvements for sibling-jump.nvim.

## Current Focus

### Block-loop for any grammar

Sibling navigation is grammar-agnostic since 2026-09-02 (see CHANGELOG). Block-loop handlers still match node
names (`lexical_declaration`, `statement_block`, `for_in_loop`, ...) and so work for TypeScript/JavaScript and
Lua only. Apply the same idea: a block's boundaries are its line-leading anonymous tokens (`if`, `else`, `}`,
`end`, `case`) and the named clauses at its own column.

### Retire name-based special modes

`special_modes/method_chains.lua` (JS `member_expression`/`call_expression`) and `switch_cases.lua`
(`switch_case`/`switch_default`) predate the generic finder, which already handles chained lines and same-column
entries. Check what they still add for JS/TS, then fold them into the generic rules.

## Future Enhancements

### Language Support
- Expand testing coverage for Python, Ruby, Go, Rust
- Add language-specific navigation patterns as needed
- Improve support for languages with unique syntax (e.g., Lisp, Haskell)

### Navigation Improvements
- **Parent/Child navigation**: Jump to parent node or first child node
- **Nearest meaningful node**: When on whitespace/comments, jump to nearest code
- **Smart wrapping**: Option to wrap around at boundaries (first→last, last→first)
- **Visual mode support**: Extend selection to next/previous sibling (block-loop already selects progressively)

### User Experience
- **Jump history**: Track navigation history with forward/backward commands
- **Preview mode**: Show destination before jumping
- **Repeat last jump**: Dot-repeat or custom repeat command
- **Count improvements**: Better handling of large counts with visual feedback

### Performance
- Cache Tree-sitter queries for frequently used patterns
- Optimize AST traversal for large files
- Lazy-load special navigation modes

### Testing & Quality
- Add performance benchmarks
- Increase test coverage for edge cases
- Add integration tests with real-world codebases
- Test with more Tree-sitter parsers

---

## Completed Features

### Core Navigation (v0.1.0)
- ✅ Sibling node navigation (forward/backward)
- ✅ Context-aware boundary detection
- ✅ Multi-language support via Tree-sitter
- ✅ Count support (`3<C-j>` to jump 3 siblings)

### Special Navigation Modes (v0.2.0)
- ✅ Method chain navigation
- ✅ If-else chain navigation
- ✅ Switch case navigation

### Language Support (v0.3.0)
- ✅ TypeScript/JavaScript/JSX/TSX
- ✅ Lua
- ✅ Java, C, C++, C# (basic support)

### Quality & Testing (v0.4.0)
- ✅ Comprehensive test suite
- ✅ Documentation (README, ARCHITECTURE, AGENTS)
- ✅ Comment and whitespace navigation

### Block-Loop (v0.5.0)
- ✅ Cycle a construct's boundaries: declarations, if/else, loops, switch, calls, property values
- ✅ Lua support (`end` keywords, tables, function calls)
- ✅ Progressive visual-mode selection
- ✅ Python try/except chains in sibling navigation

### Grammar-agnostic sibling navigation (v0.6.0)
- ✅ Units found by tree shape and indentation; node-type whitelists removed
- ✅ Swift fixture with bidirectional boundary-checked scenarios
- ✅ if/else and try/catch special modes detect clauses by shape (Swift `else`, `do`/`catch`)

---

## Contributing

Have ideas or want to implement a feature? 

1. **Check existing issues**: See if your idea is already discussed
2. **Open a discussion**: For major features, discuss the design first
3. **Submit a PR**: For bug fixes or small improvements, PRs are welcome
4. **Add tests**: All new features must include tests

See [AGENTS.md](AGENTS.md) for development guidelines.

---

## Long-term Vision

Make sibling-jump.nvim the most intuitive and powerful **structural navigation** plugin for Neovim:
- Navigate code by *meaning* not by lines/characters
- Work seamlessly across all languages with Tree-sitter support
- Provide a complete suite of structural navigation commands
- Maintain simplicity and performance

The goal is to make you think less about *how* to navigate and more about *what* you want to edit.
