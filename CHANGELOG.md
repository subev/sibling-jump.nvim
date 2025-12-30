# Changelog: statement_jump.lua

## 2025-12-30 - Fix: Switch Case Navigation Respects Object Property Context

### Issue
Switch case navigation was interfering with object property navigation when navigating inside object literals within switch cases. This caused the cursor to jump to the next/previous case instead of navigating between object properties.

**Example from real code:**
```typescript
switch (type) {
  case "signup":
    return {
      title: "Welcome!",        // ← cursor here, press <C-j>
      subtitle: "Let's start",  // Should jump here
      showIcon: true,
    };
  case "login":                 // Was incorrectly jumping here instead
    return { ... };
}
```

### Fix
Enhanced `is_in_switch_case()` to check for higher-priority navigation contexts before enabling switch case navigation. Now detects and defers to:
- Object property navigation (objects and object_type)
- Array element navigation
- Function parameter/argument navigation

These contexts take precedence over switch case navigation, ensuring proper navigation within nested structures inside switch cases.

### Test Coverage
**Added 3 comprehensive tests:**
1. Navigate object properties in return statement within case
2. Navigate backward in object literal without escaping to previous case
3. Navigate nested object properties within case

**Results:** All 112 tests pass (109 original + 3 new)

### Impact
- ✅ Fixes object property navigation inside switch cases
- ✅ Fixes array navigation inside switch cases
- ✅ Fixes parameter navigation inside switch cases
- ✅ Proper context precedence handling
- ✅ All existing tests continue to pass

---

## 2025-12-30 - Feature: Switch Case Navigation

### Overview
Added comprehensive support for navigating between switch case clauses, with intelligent context handling for both case-level and statement-level navigation.

### Features

**Two Navigation Contexts:**

1. **Parent Context (Outside Switch):**
   - When navigating from statements before/after the switch
   - Entire `switch` statement treated as a single navigation unit
   - Cursor lands on the `switch` keyword
   - Preserves existing navigation behavior (no breaking changes)

2. **Case Context (Inside Switch):**
   - When cursor is inside a `case` or `default` clause
   - Navigate between sibling case/default clauses
   - Cursor lands on `case` or `default` keyword
   - No-op at first case (backward) and last case (forward)
   - Does NOT escape switch boundaries

**Intelligent Sub-Context Detection:**
- Statements within a case create their own navigation context
- Multiple statements in a case: navigate between those statements first
- Single statement in a case: navigate to next/previous case
- Empty cases (fallthrough) are fully navigable
- Block-scoped cases (`case "a": { ... }`) work correctly
- Nested switches: inner and outer switches navigate independently

### Examples

**Basic Case Navigation:**
```typescript
switch (value) {
  case "a":      // ← cursor here, press <C-j>
    return 1;
  case "b":      // jumps here
    return 2;
  default:       // press <C-j> again
    return 0;
}
```

**Statement Navigation Within Case:**
```typescript
switch (value) {
  case "a":
    const x = 1;   // ← cursor here, press <C-j>
    const y = 2;   // jumps here (within same case)
    return x + y;  // press <C-j> again, jumps here
  case "b":        // press <C-j> once more, NOW jumps to next case
    return 3;
}
```

**Navigation from Parent Context:**
```typescript
const before = 1;  // ← cursor here, press <C-j>
switch (value) {   // jumps to 'switch' keyword
  case "a": return 1;
  case "b": return 2;
}
const after = 2;   // press <C-j> from switch, jumps here
```

**Empty Cases (Fallthrough):**
```typescript
switch (value) {
  case "a":      // ← navigable
  case "b":      // ← navigable
    return 1;
  case "c":      // ← navigable
    return 2;
}
```

### Implementation

**New Helper Functions:**
- `collect_switch_cases(switch_node)` - Collects all case/default clauses
- `get_case_keyword_position(case_node)` - Gets cursor position for case/default keyword
- `is_in_switch_case(node)` - Detects if cursor is in a case clause, with intelligent sub-context detection
- `navigate_switch_cases(switch_node, current_pos, forward)` - Handles case-to-case navigation

**Node Types Added:**
- `switch_case` - Individual case clauses
- `switch_default` - Default clause
- Already had: `switch_statement`

**Integration:**
- Added as THIRD check in main jump function (after method chains and if-else chains)
- Prioritizes statement navigation within cases over case navigation
- Falls through to regular navigation at boundaries

**Files Modified:**
- `lua/sibling_jump/init.lua` (~170 lines added)
  - Added 4 helper functions
  - Added 2 node types to meaningful_types
  - Integrated into main jump function with intelligent precedence handling

### Test Coverage

**Added 10 comprehensive test cases:**
1. Forward navigation through cases
2. Backward navigation through cases  
3. No-op at first case
4. No-op at last case
5. Navigation from parent context (lands on switch)
6. Empty cases (fallthrough)
7. Block-scoped cases (`case "a": { ... }`)
8. Statement navigation within case (multiple statements)
9. Single case no-op
10. Nested switch inner navigation

**New Test Fixtures:**
- `tests/fixtures/switch_cases.ts` (125 lines)
- `tests/fixtures/switch_cases.js` (JavaScript version)

**Results:** All 109 tests pass (99 original + 10 new)

### Verification

**Automated tests:**
```bash
bash tests/test_runner.sh
# Results: 109 passed, 0 failed
```

**Test Coverage:**
- Basic multi-case switches
- Empty/fallthrough cases
- Block-scoped cases
- Multiple statements within cases
- Single-statement cases
- Nested switches
- Parent context navigation
- Boundary conditions (first/last case)

### Impact

- ✅ Adds full switch case navigation support
- ✅ Intelligent context detection (case-level vs statement-level)
- ✅ Respects navigation boundaries (no escape from switch)
- ✅ Works with all case patterns (empty, block-scoped, multi-statement)
- ✅ Handles nested switches correctly
- ✅ No breaking changes to existing functionality
- ✅ All existing tests continue to pass

### Design Decisions

**Priority Order:**
1. Statements within a case (if multiple statements exist)
2. Case-to-case navigation (when single statement or on case keyword)
3. Regular statement navigation (at switch boundaries)

**Landing Position:**
- Case navigation: cursor lands on `case` or `default` keyword
- Makes it easy to see which case you're on
- Consistent with if-else chain behavior

**Boundary Behavior:**
- No-op at first case when going backward
- No-op at last case when going forward
- Prevents escaping the switch context accidentally

---

## 2025-12-30 - Bug Fix: Navigation Escapes Single Statement in If Block

### Issue
When cursor was positioned on a single statement inside an if block (or any other control structure), pressing `<C-k>` would incorrectly jump to the statement before the if block instead of being a no-op.

**Example from real code:**
```typescript
const isExitPopupOpen = currentPopup?.id === "game-exit-confirm";  // Line 288
if (isExitPopupOpen) {                                             // Line 289
  return false;  // Line 290 - cursor here, pressing <C-k> incorrectly jumps to line 288
}
```

**Problem:** Pressing `<C-k>` from line 290 would jump to line 288 instead of being a no-op (since there are no siblings within the if block).

### Root Cause
The navigation logic in `get_node_at_cursor()` checks if the cursor is inside a `statement_block` and counts meaningful children. When there are **multiple statements** (> 1), it correctly returns that context for navigation. However, when there is only **one statement** in the block, the code fell through without returning, causing it to continue walking up the tree and eventually finding the parent function's statement block, incorrectly navigating between statements at that higher level.

### Fix
Added an `else` clause to return `nil` when there's a single statement in a statement_block, preventing navigation from escaping the block:

```lua
if meaningful_count > 1 then
  return test_node, test_parent
else
  -- Single statement in block - no-op (don't navigate outside the block)
  return nil, "Single statement in block - would exit context"
end
```

**File:** `lua/sibling_jump/init.lua`  
**Location:** Lines 435-440

### Changes
- Added proper handling for single statements in statement blocks
- Prevents navigation from escaping the current control structure context
- Maintains no-op behavior when there are no siblings to navigate to

### Test Coverage
**Added 2 new tests:**
1. "Single statement in if: no-op when navigating from inside" - Tests basic case
2. "Single statement in if: complex case from real code" - Tests the exact reported scenario

**New fixture:** `tests/fixtures/single_statement_in_if.ts`

**Results:** All 99 tests pass (97 original + 2 new)

### Verification
**Automated tests:**
```bash
bash tests/test_runner.sh
# Results: 99 passed, 0 failed
```

**Manual verification:**
In the reported file (GamePage.tsx), navigation now correctly behaves as no-op:
- Line 290 (`return false;` inside if block) → Press `<C-k>` → Cursor stays at line 290 ✅
- Previously would incorrectly jump to line 288 ❌

### Impact
- ✅ Fixes navigation escaping from if blocks with single statements
- ✅ Applies to all control structures (if, while, for, etc.)
- ✅ Maintains correct no-op behavior within block boundaries
- ✅ No breaking changes to existing functionality
- ✅ All existing tests continue to pass

---

## 2025-12-29 - Bug Fix: JSX Conditional Expressions Not Navigable

### Issue
Navigation would get stuck when encountering JSX conditional expressions, preventing navigation to subsequent JSX elements. Specifically, expressions like `{registered && <Component />}`, `{condition ? <A /> : <B />}`, `{items.map(...)}`, and plain value expressions like `{userName}` were not recognized as navigable siblings.

**Example from real code:**
```tsx
<DiscoveryFooterButton />           {/* Line 149 - cursor here */}
<PlayFooterButton />                {/* Line 153 - <C-j> works */}
{registered && (                    {/* Line 161 - <C-j> works but gets stuck here */}
  <ProfileFooterButton />
)}
{!registered && (                   {/* Line 167 - UNREACHABLE before fix! */}
  <LoginFooterButton />
)}
<span className={...}></span>       {/* Line 173 - UNREACHABLE before fix! */}
```

**Problem:** After reaching line 161, pressing `<C-j>` would do nothing (no-op). Lines 167 and 173 were unreachable.

### Root Cause
The `jsx_expression` node type was missing from the `meaningful_types` list. Tree-sitter parses all JavaScript expressions embedded in JSX using `{...}` as `jsx_expression` nodes, including:
- Conditional rendering: `{condition && <Component />}`
- Ternary operators: `{flag ? <A /> : <B />}`
- Map operations: `{items.map(item => <Item />)}`
- Function calls: `{renderContent()}`
- Plain values: `{userName}`, `{count}`

Without `jsx_expression` in the meaningful types, these nodes were invisible to the navigation algorithm, causing the cursor to get trapped.

### Fix
**Added `jsx_expression` to meaningful node types:**
- **File:** `lua/sibling_jump/init.lua`
- **Location:** Line 160 (in the `meaningful_types` table)
- **Change:** Added `"jsx_expression"` with comment explaining its purpose

This single-line addition makes all JSX expressions navigable, allowing proper navigation through:
- Conditional rendering with `&&` operator
- Ternary expressions with `? :`
- Array mapping with `.map()`
- Function calls returning JSX
- Plain value expressions
- Any other JavaScript expressions in JSX

### Changes
```lua
-- JSX/TSX
"jsx_self_closing_element", -- Self-closing JSX like <div />
"jsx_element", -- JSX elements like <div>...</div>
"jsx_attribute", -- JSX attributes like visible={true}
"jsx_expression", -- JSX expressions like {condition && <Component />}  ← NEW
```

### Test Coverage
**Added 11 new tests** covering all JSX expression scenarios:

1. **Basic Conditionals:**
   - Forward navigation through `&&` conditionals
   - Backward navigation through `&&` conditionals
   - Multiple consecutive conditionals

2. **Ternary Expressions:**
   - Navigation through `? :` operators
   - Bidirectional navigation

3. **Parenthesized Expressions:**
   - Wrapped conditionals: `{condition && (<Component />)}`

4. **Map Operations:**
   - Array `.map()` expressions in JSX

5. **Function Calls:**
   - Function calls that return JSX: `{renderContent()}`

6. **Plain Value Expressions:**
   - Simple value interpolation: `{title}`, `{userName}`
   - Mixed with JSX elements

7. **Complex Nested Conditionals:**
   - Optional chaining: `{user?.isAdmin && <Component />}`
   - Multiple conditions: `{count > 0 && count < 10 && <Component />}`
   - Nested ternaries with parentheses

8. **Boundary Tests:**
   - No-op at first element before conditionals
   - No-op at last element after conditionals

**Test Files:**
- **New fixtures:** `tests/fixtures/jsx_conditionals.tsx` and `tests/fixtures/jsx_conditionals.jsx`
- **Updated:** `tests/run_tests.lua` (lines 1021-1210)
- **Results:** All 97 tests pass (86 original + 11 new)

### Verification
**Automated tests:**
```bash
bash tests/test_runner.sh
# Results: 97 passed, 0 failed
```

**Manual verification with real file:**
Navigation flow in Footer.tsx now works correctly:
1. Line 149 (`<DiscoveryFooterButton />`) → Press `<C-j>`
2. Line 153 (`<PlayFooterButton />`) → Press `<C-j>`
3. Line 161 (`{registered && (`) → Press `<C-j>` ✅ **Now works!**
4. Line 167 (`{!registered && (`) → Press `<C-j>` ✅ **Now reachable!**
5. Line 173 (`<span>`) ✅ **Now reachable!**

### Impact
- ✅ Fixes navigation through all JSX conditional expressions
- ✅ Fixes navigation through map operations
- ✅ Fixes navigation through function call expressions
- ✅ Makes plain value expressions navigable
- ✅ No breaking changes to existing functionality
- ✅ All existing tests continue to pass

---

## 2025-12-27 - Test Suite: Solid, Reliable Test Coverage

### Achievement
Created a working test suite with **13 tests, all passing reliably**. Switched from plenary.nvim to a direct test runner because plenary's test isolation breaks treesitter parser access.

### Test Infrastructure
- **New file:** `tests/run_tests.lua` - Direct test runner (no plenary)
- **Updated:** `tests/test_runner.sh` - Uses direct runner
- **Result:** 100% test pass rate (13/13 tests)

### Why Not Plenary?
Plenary's test sandboxing prevents treesitter parsers from being loaded, causing all tests to fail even though the functionality works. Our direct test runner bypasses this issue by testing in Neovim's normal environment.

### Test Coverage
```
✅ TypeScript properties (4 tests)
✅ JSX elements (5 tests) 
✅ Destructuring (2 tests)
✅ Statements (2 tests)
```

All critical scenarios are covered including both bug fixes.

---

## 2025-12-27 - Bug Fix: Non-self-closing JSX elements not navigable

### Issue
When cursor was on a non-self-closing JSX element (like `<TabContainer>...</TabContainer>`), navigation didn't work:
1. Pressing `<C-j>` from a non-self-closing element would be a no-op
2. Pressing `<C-k>` from the target element would jump to an outer element instead of the previous sibling

**Example:**
```tsx
<PersistentTabContainer>...</PersistentTabContainer>  {/* L110 */}
<TabContainer>...</TabContainer>                       {/* L113 - cursor here */}
```
- Pressing `<C-k>` from L113 would jump to L81 (outer statement) instead of L110 ❌
- Pressing `<C-j>` from L110 would be a no-op instead of jumping to L113 ❌

### Root Cause
In the previous fix, we made `jsx_opening_element` and `jsx_closing_element` "skippable" to avoid them being counted as siblings. But this also prevented us from detecting when the cursor was ON these elements.

For non-self-closing JSX:
- The element is a `jsx_element` node
- It has children: `jsx_opening_element`, content, `jsx_closing_element`
- When cursor is on the opening tag, we need to recognize it represents the entire `jsx_element`

### Fix
**Added special handling in `get_node_at_cursor()`:**
- When cursor is on `jsx_opening_element` or `jsx_closing_element`, treat the parent `jsx_element` as the meaningful node
- This allows navigation to work from the opening/closing tags
- The tags remain "skippable" when encountered as siblings (they're just delimiters)

### Changes
- **File:** `lua/statement_jump.lua`
  - Lines ~130-135: Early detection of jsx opening/closing elements
  - Lines ~144-150: Additional check during tree walk

### Test Coverage
- **New tests:**
  - "jumps between non-self-closing JSX elements" - Forward navigation L13→L16→L19
  - "jumps backward from non-self-closing JSX element" - Backward navigation L16→L13
- **Location:** `tests/statement_jump_spec.lua` lines 157-187
- **Fixture:** Updated `jsx_elements.tsx` to include more non-self-closing elements

### Verification
```bash
# Manual test
nvim /path/to/file.tsx
# Position cursor at L113 on <TabContainer>
:call cursor(113, 9)
# Press <C-k> - should jump to L110 (PersistentTabContainer)
# Press <C-j> - should return to L113
```

---

## 2025-12-27 - Bug Fix: No-op when child has no siblings

### Issue
When cursor was inside a child JSX element that has no siblings (like `<DiscoverTab />` inside `<PersistentTabContainer>`), pressing `<C-k>` would incorrectly jump to the parent element instead of being a no-op.

**Example:**
```tsx
<PersistentTabContainer>
  <DiscoverTab />  {/* Cursor here at L111 */}
</PersistentTabContainer>  {/* Would jump here at L110 - WRONG! */}
```

### Root Cause
1. The `jsx_element` node type was included in `meaningful_types`, causing the algorithm to treat wrapper elements as navigable nodes
2. JSX opening/closing tags (`jsx_opening_element`, `jsx_closing_element`) were not being skipped, potentially causing them to be counted as siblings

### Fix
1. **Removed `jsx_element` from meaningful types** - Only `jsx_self_closing_element` should be meaningful for JSX navigation. The wrapper `jsx_element` is just a container.
2. **Added JSX tag skipping** - Opening and closing tags are now properly skipped in `is_skippable_node()`

### Changes
- **File:** `lua/statement_jump.lua`
  - Line ~80: Removed `"jsx_element"` from `meaningful_types`
  - Lines ~32-35: Added check to skip `jsx_opening_element` and `jsx_closing_element`

### Test Coverage
- **New test:** "does not jump to parent when inside child JSX element"
  - Tests both forward and backward navigation from a child with no siblings
  - Verifies no-op behavior (cursor should not move)
- **Location:** `tests/statement_jump_spec.lua` lines 136-154

### Verification
```bash
# Manual test
nvim /path/to/file.tsx
# Position cursor at L111:C11 (inside <DiscoverTab />)
# Press <C-k> - cursor should NOT move
```

### Test Results
- ✅ 4 passing tests (including new test)
- ⚠️ 8 tests fail in headless mode (known plenary issue, work in real usage)

---

## Initial Release - 2025-12-27

### Features
- Navigate between sibling nodes at same treesitter nesting level
- `<C-j>` - Jump to next sibling
- `<C-k>` - Jump to previous sibling
- No-op at boundaries (first/last sibling)
- Works with:
  - TypeScript type properties
  - JSX/TSX elements
  - Destructured properties
  - Regular statements (const, let, if, for, etc.)
- Language-agnostic (works with any treesitter parser)
- Count support (`3<C-j>` jumps 3 siblings)

### Test Coverage
- TypeScript type properties navigation
- JSX element navigation
- Destructuring pattern navigation
- Basic statement navigation
- Boundary condition tests
