// Test fixture for method chain navigation

// Multi-line method chain
const result = obj
  .methodA()
  .methodB()
  .methodC();

// Inline chain
const inline = obj.foo().bar().baz();

// Single method call (not a chain)
const single = obj.method();

// Property access (not a chain)
const prop = obj.property;

// Chain starting with identifier
const chain = someFunc().then().catch();

// tRPC-style procedure chain
const procedure = baseProcedure
  .input(z.object({ id: z.string() }))
  .output(z.object({ data: z.string() }))
  .query(async ({ input }) => {
    return { data: "test" };
  });
