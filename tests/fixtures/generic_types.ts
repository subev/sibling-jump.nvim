// Test file for generic type arguments navigation
// Should be able to jump between type arguments in angle brackets

// Simple generic type with multiple parameters
type Generic1<T, U, V> = {
  first: T;
  second: U;
  third: V;
};

// Generic function with multiple type parameters
function identity<A, B, C>(a: A, b: B, c: C): void {}

// Complex nested generics
type Nested<X, Y, Z> = Map<X, Record<Y, Array<Z>>>;

// Generic interface
interface Container<First, Second, Third> {
  value1: First;
  value2: Second;
  value3: Third;
}

// Generic type with constraints
type Constrained<T extends string, U extends number, V extends boolean> = {
  a: T;
  b: U;
  c: V;
};

// Generic class
class MyClass<Alpha, Beta, Gamma> {
  constructor(
    public a: Alpha,
    public b: Beta,
    public c: Gamma,
  ) {}
}

// Generic arrow function type
type Func<Input, Output, Error> = (input: Input) => Output | Error;

// React component with generic props
interface Props<Data, Loading, Error> {
  data: Data;
  loading: Loading;
  error: Error;
}

// Multiple generics on same line
type Multi<A, B> = Pair<A, B>;
type Pair<X, Y> = { x: X; y: Y };
