// Test fixture for function parameter and argument navigation

// Function definition with parameters
const add = (a, b, c) => a + b + c;

// Function call with arguments
add(1, 2, 3);

// Single parameter function
const single = (x) => x * 2;

// Single argument call
single(5);

// Multi-line parameters
function multiLine(
  first,
  second,
  third
) {
  return first;
}

// Multi-line arguments
multiLine(
  "hello",
  42,
  true
);
