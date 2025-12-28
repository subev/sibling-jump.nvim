// Test fixture for nested context navigation

// Statements inside arrow function (which is inside function arguments)
const result = someFunction(
  (data) => {
    const parsed = data.value;
    if (parsed) {
      return true;
    }
    return false;
  },
  {
    message: "config",
  }
);

// Statements inside regular function (which is inside array)
const funcs = [
  function first() {
    const a = 1;
    const b = 2;
    return a + b;
  },
  function second() {
    const x = 10;
    return x;
  }
];
