// Test fixture for block-loop feature

// ============ IF BLOCKS ============

function simpleIf() {
  if (condition) {
    console.log('yes');
  }
}

function ifElse() {
  if (condition) {
    console.log('yes');
  } else {
    console.log('no');
  }
}

function ifElseIfElse() {
  if (cond1) {
    console.log('one');
  } else if (cond2) {
    console.log('two');
  } else if (cond3) {
    console.log('three');
  } else {
    console.log('default');
  }
}

// ============ FUNCTIONS ============

function regularFunction() {
  console.log('regular');
}

const arrowFunction = () => {
  console.log('arrow');
};

let arrowWithLet = () => {
  console.log('let arrow');
};

var arrowWithVar = () => {
  console.log('var arrow');
};

// ============ OBJECTS ============

const simpleObject = {
  foo: 'bar',
  baz: 123
};

let objectWithLet = {
  key: 'value'
};

var objectWithVar = {
  another: 'obj'
};

// Function call case (like router({...}))
const routerExample = router({
  method1: () => {
    const inner = { nested: true };
    return inner;
  },
  method2: () => {
    return { value: 42 };
  }
});

// ============ ARRAYS ============

const simpleArray = [
  1, 2, 3, 4
];

let arrayWithLet = [
  'a', 'b', 'c'
];

var arrayWithVar = [
  true, false
];

// ============ SWITCH STATEMENTS ============

function switchExample(value: string) {
  switch (value) {
    case "one": {
      console.log('one');
      break;
    }
    case "two": {
      console.log('two');
      break;
    }
    case "three": {
      console.log('three');
      break;
    }
    default:
      console.log('default');
  }
}

// ============ CLASS METHODS ============

class TestClass {
  regularMethod() {
    console.log('method');
  }
  
  async asyncMethod() {
    console.log('async');
  }
}

// ============ NESTED BLOCKS ============

function nestedIf() {
  if (outer) {
    const inner = 1;
    
    if (inner) {
      console.log('inner');
    }
  }
}

// ============ NO-OP CASES ============

// Cursor inside condition - should do nothing
function cursorInCondition() {
  if (some && complex && condition) {
    console.log('test');
  }
}

// Cursor inside block body - should do nothing
function cursorInBody() {
  if (condition) {
    const x = 1;
    const y = 2;
    const z = 3;
  }
}

// ============ TYPE DECLARATIONS ============

type SimpleType = {
  foo: string;
  bar: number;
};

type IntersectionType = BaseType & {
  extra: string;
  nested: {
    deep: boolean;
  };
};

// ============ METHOD CHAINING ============

const chainedCalls = foo.bar().baz().gaz();

const multilineChain = z
  .object({
    value: z.string(),
  })
  .refine(
    (data) => {
      return true;
    },
    {
      message: "Invalid",
    },
  );

// ============ EXPORT DECLARATIONS ============

export const exportedConst = {
  foo: 'bar',
  baz: 123,
};

// ============ OBJECT PROPERTY VALUES WITH CHAINS ============

const routerExample = router({
  consumeToken: procedure
    .input(z.object({ token: z.string() }))
    .mutation(async ({ ctx }) => {
      return { success: true };
    }),
  
  otherMethod: procedure.query(() => {
    return "result";
  }),
});

// ============ CHAINED METHODS IN PROPERTY VALUES ============

const multiInputExample = {
  getProd: baseProcedure
    .query(async () => {
      return { id: 1 };
    })
    .input(z.object({ id: z.string() }))
    .input(z.object({ id: z.string() })),
};

// ============ SINGLE-LINE DECLARATIONS ============

const singleLineCall = getWelcomeContent(scenario, username, gameData?.name ?? null);

const anotherExample = calculateTotal(items, discount, shipping);
