# Roadmap

This document outlines planned features and improvements for sibling-jump.nvim.

## Current Focus

### Block End Navigation (Planned)
Add a complementary navigation function to jump to the end of code blocks, inspired by Vim's `%` operator for bracket pairs.

**Concept**: While sibling-jump navigates *between* siblings horizontally, this new function will navigate *vertically* to the end of a structural block.

**Example use cases**:
- Jump from function declaration to its closing brace
- Jump from `if` to its corresponding `end`/closing brace
- Jump from opening brace `{` to closing brace `}`
- Jump from class declaration to end of class
- Jump from loop start to loop end

**Design goals**:
- Context-aware: understands different language constructs
- Bidirectional: can jump from start→end or end→start
- Works with: functions, if/else blocks, loops, classes, and other structural elements
- Language-agnostic: leverages Tree-sitter for multi-language support

**Status**: Design phase - detailed specification coming soon

---

## Future Enhancements

### Language Support
- Expand testing coverage for Python, Ruby, Go, Rust
- Add language-specific navigation patterns as needed
- Improve support for languages with unique syntax (e.g., Lisp, Haskell)

### Navigation Improvements
- **Parent/Child navigation**: Jump to parent node or first child node
- **Nearest meaningful node**: When on whitespace/comments, jump to nearest code
- **Smart wrapping**: Option to wrap around at boundaries (first→last, last→first)
- **Visual mode support**: Extend selection to next/previous sibling

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
- ✅ Comprehensive test suite (141+ tests)
- ✅ Documentation (README, ARCHITECTURE, AGENTS)
- ✅ Comment and whitespace navigation

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
