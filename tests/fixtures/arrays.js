// Test fixture for array element navigation

// Simple array
const numbers = [1, 2, 3, 4, 5];

// Array of object
const items = [
  { id: 1, name: "foo" },
  { id: 2, name: "bar" },
  { id: 3, name: "baz" },
];

// Array of function calls (like zod discriminatedUnion)
const schema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("sdk"), gameId: z.string() }),
  z.object({ type: z.literal("app") }),
]);

// Single element array
const single = [1];

// Nested array
const nested = [
  [1, 2],
  [3, 4],
  [5, 6],
];
