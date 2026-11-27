---
name: object-calisthenics
description: Apply when writing, reviewing, or refactoring object-oriented code. Enforces the 9 Object Calisthenics rules to produce highly cohesive, loosely coupled, and intention-revealing code. Activates on OOP code in any language (TypeScript, Ruby, Java, Python, C#, etc.).
license: MIT
metadata:
  author: beskar
  version: "1.0.0"
---

# Object Calisthenics Skill

This skill enforces the 9 Object Calisthenics rules — a set of constraints that, when applied together, push code toward small, expressive, single-purpose objects with rich domain behavior. The rules are intentionally strict: the goal is to feel the constraint, understand the design pressure it creates, and write better OOP as a result.

---

## When to Apply

- Writing new classes, services, or domain models
- Reviewing or refactoring existing object-oriented code
- The codebase shows signs of Primitive Obsession, Large Class, or Feature Envy smells
- The user asks for "clean OOP", "better encapsulation", or "refactor this to objects"
- Pairing this with DDD (Domain-Driven Design) practices

---

## Core Rules

### Method Design

**Rule 1 — One level of indentation per method**
- Each method body contains at most one level of nesting (one `if`, `for`, or `while`).
- Extract nested blocks into well-named private methods or collaborating objects.
- If you reach for a second indent, stop and ask: what concept is hiding in this block?

**Rule 2 — No else keyword**
- Replace `else` with early returns (guard clauses) or polymorphism.
- Guard clauses handle failure/edge cases at the top; the happy path runs unindented at the bottom.
- Never use `else if` chains — use a strategy, lookup table, or polymorphic dispatch instead.

### Type Design

**Rule 3 — Wrap all primitives and strings**
- Every primitive (`int`, `string`, `boolean`, `float`) with domain meaning becomes its own value object (e.g., `Money`, `Email`, `Percentage`, `UserId`).
- The wrapper class owns all validation, formatting, and arithmetic for that concept.
- Plain primitives are allowed only as internal implementation details inside a value object, never in method signatures or constructor parameters of domain classes.

**Rule 4 — First-class collections**
- Any class that holds a collection (`Array`, `List`, `Set`, `Map`) as an instance variable holds *only* that collection — no other state.
- All collection operations (filtering, mapping, aggregation) live as methods on the collection class, not scattered across callers.
- Name the collection class after the domain concept it represents (e.g., `OrderItems`, `TagSet`, `UserRoles`).

**Rule 8 — No classes with more than two instance variables**
- A class may hold at most two instance variables. This forces decomposition into smaller, collaborating objects.
- When a class needs three or more pieces of state, identify which two belong together and extract them into a new object.
- Apply this rule strictly during design; it reveals hidden domain concepts that deserve their own class.

### Object Communication

**Rule 5 — One dot per line**
- Never chain method calls through objects you do not directly own: `a.b().c().d()` is a violation.
- You may chain calls on the same object (fluent builders, value objects), but not traverse object graphs.
- If you need data from a distant collaborator, tell the immediate object what to do with it — do not fetch and act.

**Rule 9 — No getters, setters, or properties**
- Objects expose behavior, not data. Replace `getX()` / `setX()` with methods that describe *what the object does* with that data.
- Ask: "What does the caller *do* with this value?" — then move that behavior onto the object itself (Tell, Don't Ask).
- Read-only accessors for value objects are acceptable when the value is the entire point (e.g., `Money#amount` for serialization), but treat them as an escape hatch, not the default.

### Naming and Size

**Rule 6 — No abbreviations**
- All class names, method names, and variable names are fully spelled out.
- `usr`, `mgr`, `calc`, `tmp`, `val`, `i` (outside a loop counter) are disallowed.
- If a name feels long, the concept may need its own type rather than a longer variable name.

**Rule 7 — Keep all entities small**
- Classes: max 50 lines (excluding blank lines and comments).
- Methods: max 5 lines.
- Packages/modules: max 10 files.
- When an entity exceeds the limit, it is carrying too many responsibilities — decompose it.

---

## How to Use

### Installing this skill

Copy the content below the YAML frontmatter and add it to your agent's instructions file:

- **Claude Code** — `CLAUDE.md` in your project root, or `~/.claude/CLAUDE.md` globally
- **Cursor** — `.cursorrules` file or `Settings > Rules for AI`
- **Windsurf** — `.windsurfrules` file
- **Any agent** — paste into the system prompt or custom instructions

### Example trigger phrases

- "Apply object calisthenics to this class"
- "Refactor this with clean OOP rules"
- "This feels like Primitive Obsession — fix it"
- "Wrap this in a proper value object"
- "No getters — redesign this"

### Violation checklist

When reviewing code, flag violations in this order (highest leverage first):

1. Primitives passed as method arguments → Rule 3
2. Nested conditionals or loops → Rules 1 & 2
3. Getters used to make decisions in callers → Rule 9
4. Collections mixed with other state → Rule 4
5. Multi-dot chains traversing object graphs → Rule 5
6. Classes over 50 lines or methods over 5 lines → Rule 7
7. More than two instance variables → Rule 8
8. Abbreviated names → Rule 6

### Example output with this skill active

**Without skill:**
```ts
class OrderManager {
  calculateTotal(membershipLevel: string, items: any[]): number {
    let total = 0;
    for (const item of items) {
      if (item.quantity > 0) {                        // indent level 1
        if (membershipLevel === 'gold') {             // indent level 2
          total += item.price * item.quantity * 0.9;
        } else if (membershipLevel === 'silver') {
          total += item.price * item.quantity * 0.95;
        } else {
          total += item.price * item.quantity;
        }
      }
    }
    return total;
  }
}
```

**With skill (Rules 1, 2, 3, 4, 9 applied):**
```ts
// Rule 3: primitives wrapped in value objects
class Money {
  constructor(private readonly cents: number) {}
  add(other: Money): Money { 
    return new Money(this.cents + other.cents); 
  }
  withDiscount(rate: Percentage): Money { 
    return new Money(this.cents * (1 - rate.value())); 
  }
  static zero(): Money { return new Money(0); }
}

// Rule 3: string enum wrapped as a type
class ItemType {
  static readonly DIGITAL = new ItemType('digital');
  private constructor(private readonly code: string) {}
  isDigital(): boolean 
  { 
    return this.code === 'digital'; 
  }
}

// Rule 4: collection gets its own class with domain behavior
class OrderItems {
  constructor(private readonly items: Item[]) {}
  total(): Money {
    return this.items.reduce(
      (sum, item) => sum.add(item.price()),  // Rule 9: item tells us its price
      Money.zero()
    );
  }
}

// Rules 1, 2: one indent level, guard clause instead of else
class Order {
  constructor(
    private readonly status: OrderStatus,  // Rule 8: two instance variables
    private readonly items: OrderItems
  ) {}

  total(): Money {
    if (!this.status.isActive()) return Money.zero();  // Rule 2: guard clause
    return this.items.total();                          // Rule 9: tell, don't ask
  }
}
```

**Violations flagged (before refactor):**
- `membershipLevel: string`, `item.price`, `item.quantity` — raw primitives with domain meaning [Rule 3]
- Nested `if` inside `for` inside `if` — three indentation levels [Rule 1]
- `else if` chains for membership level — use polymorphism or a lookup [Rule 2]
- `items: any[]` passed as a raw array — should be a first-class `OrderItems` collection [Rule 4]
- `membershipLevel` and `items` are two instance variables in one method signature — caller owns state that belongs on `Order` [Rule 9]
