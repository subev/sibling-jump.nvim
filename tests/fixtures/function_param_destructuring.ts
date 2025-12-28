// Test fixture for function parameter destructuring with inline type annotations

// Function with destructured parameters and inline type annotation
function isHelpReminderDue({
  dateOfLastReminder,
  context,
}: {
  dateOfLastReminder: Date;
  context: TaskDeps;
}): boolean {
  return true;
}

// Another example with more parameters
function processData({
  userId,
  timestamp,
  metadata,
}: {
  userId: string;
  timestamp: number;
  metadata: Record<string, unknown>;
}): void {
  console.log(userId, timestamp, metadata);
}

// Mixed: some with renaming, some without
function complexExample({
  foo,
  bar: renamedBar,
  baz,
}: {
  foo: string;
  bar: number;
  baz: boolean;
}): void {
  console.log(foo, renamedBar, baz);
}
