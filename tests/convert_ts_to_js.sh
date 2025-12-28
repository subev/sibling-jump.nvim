#!/bin/bash
# Script to convert TypeScript fixtures to JavaScript
# Strips type annotations while preserving code structure

if [ $# -eq 0 ]; then
  echo "Usage: $0 <input.ts> [output.js]"
  echo "Example: $0 if_else_chains.ts if_else_chains.js"
  exit 1
fi

input_file="$1"
output_file="${2:-${input_file%.ts}.js}"

if [ ! -f "$input_file" ]; then
  echo "Error: Input file '$input_file' not found"
  exit 1
fi

# Create temporary file
tmp_file=$(mktemp)

# Convert TypeScript to JavaScript
cat "$input_file" | \
  # Remove type annotations from function parameters: (param: Type) -> (param)
  sed -E 's/([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*[a-zA-Z_<>[\]{}|&, ]+(\s*[,)])/\1\2/g' | \
  # Remove return type annotations: ): Type { -> ) {
  sed -E 's/\):\s*[a-zA-Z_<>[\]{}|&, ]+\s*\{/) {/g' | \
  # Remove variable type annotations: const x: Type = -> const x =
  sed -E 's/(const|let|var)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*[a-zA-Z_<>[\]{}|&, ]+\s*=/\1 \2 =/g' | \
  # Remove type/interface declarations (lines starting with type or interface)
  sed -E '/^\s*(type|interface)\s+[a-zA-Z_]/d' | \
  # Remove generic type parameters: <T, U, V> -> ""
  sed -E 's/<[a-zA-Z_][a-zA-Z0-9_,. ]*>//g' | \
  # Clean up extra whitespace
  sed -E 's/\s+$//' \
  > "$tmp_file"

# Move to output
mv "$tmp_file" "$output_file"

echo "✓ Converted: $input_file -> $output_file"
