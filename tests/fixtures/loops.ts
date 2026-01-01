// Test fixture for loop block-loop navigation

function testForLoop() {
  const items = [1, 2, 3];
  
  for (let i = 0; i < items.length; i++) {
    console.log(items[i]);
  }
  
  return items;
}

function testWhileLoop() {
  let count = 0;
  
  while (count < 10) {
    console.log(count);
    count++;
  }
  
  return count;
}

function testForOfLoop() {
  const values = [1, 2, 3];
  
  for (const value of values) {
    console.log(value);
  }
  
  return values;
}

function testForInLoop() {
  const obj = { a: 1, b: 2 };
  
  for (const key in obj) {
    console.log(key, obj[key]);
  }
  
  return obj;
}
