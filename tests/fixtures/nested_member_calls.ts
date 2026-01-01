// Test nested member expression calls
analytics.foo.capture({
  event: "welcome_modal_primary_click",
  properties: {
    registered,
    scenario,
  },
});

// Deep nesting
obj.a.b.c.method();

// With await
await analytics.track.event();
