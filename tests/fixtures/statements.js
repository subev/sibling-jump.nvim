// Test fixture for basic statement navigation
function testStatements() {
  const a = 1;
  const b = 2;
  const c = 3;
  
  if (a > 0) {
    console.log("positive");
  }
  
  for (let i = 0; i < 10; i++) {
    console.log(i);
  }
  
  return a + b + c;
}
