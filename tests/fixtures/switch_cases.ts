// Test fixture for switch case navigation

// Basic switch with multiple cases and default
function basicSwitch(value: string) {
  const before = 1;
  
  switch (value) {
    case "a":
      return 1;
    case "b":
      return 2;
    case "c":
      return 3;
    default:
      return 0;
  }
  
  const after = 2;
}

// Switch with empty cases (fallthrough)
function emptyCases(value: string) {
  const before = 3;
  
  switch (value) {
    case "a":
    case "b":
      return 1;
    case "c":
      return 2;
    default:
      return 0;
  }
  
  const after = 4;
}

// Switch with block-scoped cases
function blockScoped(value: string) {
  const before = 5;
  
  switch (value) {
    case "a": {
      const x = 1;
      return x;
    }
    case "b": {
      const y = 2;
      return y;
    }
    default: {
      return 0;
    }
  }
  
  const after = 6;
}

// Switch with multiple statements in cases
function multipleStatements(value: string) {
  const before = 7;
  
  switch (value) {
    case "a":
      const x = 1;
      const y = 2;
      return x + y;
    case "b":
      const z = 3;
      return z;
    default:
      return 0;
  }
  
  const after = 8;
}

// Nested switch
function nestedSwitch(outer: string, inner: string) {
  const before = 9;
  
  switch (outer) {
    case "a":
      switch (inner) {
        case "x":
          return 1;
        case "y":
          return 2;
        default:
          return 3;
      }
    case "b":
      return 4;
    default:
      return 0;
  }
  
  const after = 10;
}

// Single case (should be no-op within switch)
function singleCase(value: string) {
  const before = 11;
  
  switch (value) {
    default:
      return 0;
  }
  
  const after = 12;
}

// Switch without default
function noDefault(value: string) {
  const before = 13;
  
  switch (value) {
    case "a":
      return 1;
    case "b":
      return 2;
  }
  
  const after = 14;
}

// Switch with object literals in return statements
function objectLiterals(type: string, username: string) {
  const before = 15;
  
  switch (type) {
    case "signup":
      return {
        title: `Welcome, ${username}!`,
        subtitle: "Let's get started",
        showIcon: true,
        primaryButton: {
          text: "Continue",
          action: "next",
        },
      };
    
    case "login":
      return {
        title: `Welcome back, ${username}!`,
        subtitle: "We restored your progress",
        showIcon: false,
        showAvatar: true,
        primaryButton: {
          text: "Got it",
          action: "close",
        },
      };
    
    default:
      return {
        title: "Welcome",
        subtitle: "Get started",
      };
  }
  
  const after = 16;
}
