// Test fixture for call expression block loop navigation

// Member expression calls (analytics.capture)
analytics.capture({
  event: "welcome_modal_primary_click",
  properties: {
    registered,
    scenario,
  },
});

// Simple member call
foo.bar();

// Chained member call
obj.method.call();

// Await expressions
await foo();
await bar.baz();

// Nested member expression
analytics.track.event({
  type: "click"
});

// Simple function call (baseline)
simple();
