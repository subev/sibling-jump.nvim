// Test fixture for if-else-if-else chain navigation

// Full chain: if - else if - else if - else
function fullChain() {
  const before = 1;
  
  if (condition1) {
    console.log('first');
  } else if (condition2) {
    console.log('second');
  } else if (condition3) {
    console.log('third');
  } else {
    console.log('default');
  }
  
  const after = 2;
}

// If with only else (no else-if)
function ifElse() {
  const before = 3;
  
  if (condition) {
    console.log('true');
  } else {
    console.log('false');
  }
  
  const after = 4;
}

// If with no else (should skip to next statement)
function ifOnly() {
  const before = 5;
  
  if (condition) {
    console.log('maybe');
  }
  
  const after = 6;
}

// Single else-if
function singleElseIf() {
  const before = 7;
  
  if (condition1) {
    console.log('first');
  } else if (condition2) {
    console.log('second');
  }
  
  const after = 8;
}

// Nested if-else inside if block (should navigate inner block's statements)
function nestedIf() {
  if (outer) {
    const innerBefore = 9;
    
    if (inner) {
      console.log('inner');
    } else {
      console.log('inner else');
    }
    
    const innerAfter = 10;
  }
}
