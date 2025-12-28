// Test fixture for function parameter and argument navigation

// Function definition with parameters
const add = (a: number, b: number, c: number) => a + b + c;

// Function call with arguments
add(1, 2, 3);

// Single parameter function
const single = (x: number) => x * 2;

// Single argument call
single(5);

// Multi-line parameters
function multiLine(
  first: string,
  second: number,
  third: boolean
) {
  return first;
}

// Multi-line arguments
multiLine(
  "hello",
  42,
  true
);
