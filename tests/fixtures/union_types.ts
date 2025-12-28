// Test file for union type navigation
// Should be able to jump between union members using | separator

// Simple union types
type Status = "pending" | "success" | "error" | "cancelled";

type NumberOrString = number | string | boolean;

type Result = Success | Failure | Pending;

// Complex union with object types
type Response =
  | { status: "loading" }
  | { status: "success"; data: string }
  | { status: "error"; error: Error };

// Union with function types
type Handler =
  | ((value: string) => void)
  | ((value: number) => void)
  | ((value: boolean) => void);

// Multiline union type
type Shape =
  | Circle
  | Square
  | Triangle
  | Rectangle;

// Union with literal types
type Direction = "north" | "south" | "east" | "west";

// Union in function parameter
function process(input: string | number | boolean): void {}

// Union in interface
interface Config {
  value: string | number | null | undefined;
}

// Intersection with union
type Combined = (A | B) & (C | D);

// Nested unions
type Nested = (string | number) | (boolean | null) | undefined;

// Union type alias with generics
type Maybe<T> = T | null | undefined;

// Complex discriminated union
type Action =
  | { type: "increment"; amount: number }
  | { type: "decrement"; amount: number }
  | { type: "reset" }
  | { type: "set"; value: number };
