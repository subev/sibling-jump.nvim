// Test fixture for object property navigation

// Simple object with properties
const config = {
  foo: 123,
  bar: 456,
  baz: 789,
};

// Object with method chain values (like tRPC router)
const router = {
  getPosts: baseProcedure
    .input(z.string())
    .output(z.array(z.string()))
    .query(() => []),
  
  getUsers: baseProcedure
    .input(z.number())
    .output(z.array(z.object({ id: z.string() })))
    .query(() => []),
};

// Nested object
const nested = {
  outer: {
    inner: 123,
  },
};
