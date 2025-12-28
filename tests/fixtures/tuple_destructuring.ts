// Test file for tuple destructuring navigation
// Should be able to jump between tuple elements when destructuring

// Simple tuple destructuring
const [first, second, third] = getTuple();

// Tuple with rest operator
const [head, ...tail] = getArray();

// Nested tuple destructuring
const [[a, b], [c, d]] = getNestedTuple();

// Tuple destructuring with types
const [name, age, active]: [string, number, boolean] = getUserData();

// Mixed tuple destructuring
const [id, { name, email }, isActive] = getComplexData();

// Tuple in function parameter
function process([x, y, z]: [number, number, number]) {}

// Multiple tuple destructuring
const [foo, bar, baz] = array1;
const [one, two, three] = array2;

// Tuple with skipped elements
const [item1, , item3] = arrayWithSkip;

// React hooks style
const [count, setCount] = useState(0);
const [name, setName] = useState("");
const [active, setActive] = useState(false);

// Tuple with default values
const [width = 100, height = 200, depth = 300] = getDimensions();

// Complex nested destructuring with tuples
const {
  data: [result1, result2, result3],
  meta: { total, page }
} = response;

// Tuple in object destructuring
const {
  coordinates: [lat, lng],
  address: { city, country }
} = location;

// Tuple array destructuring
const [[a1, b1], [a2, b2], [a3, b3]] = pairArray;

// Mixed patterns
const [
  { id: id1, name: name1 },
  { id: id2, name: name2 },
  { id: id3, name: name3 }
] = users;

// Tuple with complex types
const [
  promise1,
  promise2,
  promise3
]: [Promise<string>, Promise<number>, Promise<boolean>] = getPromises();
