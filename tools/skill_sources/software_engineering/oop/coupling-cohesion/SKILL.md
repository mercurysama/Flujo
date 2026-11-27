---
name: coupling-cohesion
description: Apply when evaluating module boundaries, reviewing how classes depend on each other, or deciding what belongs together. Enforces Low Coupling and High Cohesion — the two forces that determine whether a system is easy or painful to change.
license: MIT
metadata:
  author: beskar
  version: "1.0.0"
---

# Low Coupling & High Cohesion Skill

Coupling and cohesion are the two fundamental forces in software design. **Cohesion** measures how strongly the elements inside a module belong together. **Coupling** measures how strongly modules depend on each other. The goal is to maximize cohesion within modules and minimize coupling between them. These two forces are inversely related — getting both right is the essence of good decomposition.

---

## When to Apply

- Deciding where a new class, function, or module belongs
- A change in one class unexpectedly requires changes in several others
- A class or module is hard to test without pulling in half the system
- Two classes always change together but are modeled as separate concerns
- A module is "responsible for" things that have no clear relationship to each other

---

## Core Rules

### High Cohesion

**Everything inside a module should belong together and serve a single, clear purpose.**

- A cohesive class has one reason to exist. Its methods and fields are all directly related to that purpose — none are "convenient extras".
- Measure cohesion by asking: "If I describe what this class does, can I do it in one sentence without using 'and'?"
- Low cohesion signals: a class with methods that operate on completely different data, a module that handles concerns from multiple layers (e.g., parsing + persistence + notification in one place), utility/helper classes that accumulate unrelated functions.
- When cohesion is low, the module is doing too many things — split it along its natural seams. The split usually reveals domain concepts that were hidden.
- Cohesion applies at every level: method (all lines work toward one outcome), class (all methods serve one concept), module/package (all classes belong to one bounded context).

### Low Coupling

**Modules should know as little about each other as possible.**

- Coupling is any dependency: a `new` instantiation, an `import`, a shared global, a database table accessed by two services, a type passed across a boundary.
- Not all coupling is equal. Distinguish:
  - **Content coupling** (worst): one module reaches into the internals of another.
  - **Control coupling**: one module passes a flag to control another's behavior.
  - **Data coupling** (best): modules share only simple, well-defined data structures.
- Reduce coupling by depending on abstractions (interfaces) instead of concrete classes, passing only the data a collaborator needs instead of a rich object, and keeping cross-module knowledge explicit and minimal.
- Coupling is directional — it matters which direction dependencies flow. High-level policy (domain logic) should not depend on low-level detail (infrastructure). Low-level modules should depend on abstractions defined by the high-level modules, not the other way around.
- A module that is easy to test in isolation has low coupling. If testing it requires instantiating half the system, coupling is too high.

### The Tension Between Them

High cohesion and low coupling pull in opposite directions — you achieve both only through the right decomposition:

- Too few modules: high coupling (everything depends on everything) and low cohesion (each module does too much).
- Too many modules: low cohesion (trivial modules with one line each) and paradoxically higher coupling (more seams to cross for any operation).
- The right decomposition: modules are large enough to contain a complete concept, small enough that their purpose is singular. Changes stay local. Additions require creating new modules, not editing existing ones.

When finding the right cut, ask:
- **Do these things change for the same reason?** → They have high cohesion, keep them together.
- **Do these things change independently?** → They should be decoupled, even if currently colocated.
- **Would a change in A force a change in B?** → A and B are too tightly coupled.

---

## How to Use

### Installing this skill

Copy the content below the YAML frontmatter and add it to your agent's instructions file:

- **Claude Code** — `CLAUDE.md` in your project root, or `~/.claude/CLAUDE.md` globally
- **Cursor** — `.cursorrules` file or `Settings > Rules for AI`
- **Windsurf** — `.windsurfrules` file
- **Any agent** — paste into the system prompt or custom instructions

### Related skills

- [SOLID](../solid/SKILL.md) — SRP directly operationalizes High Cohesion; DIP operationalizes Low Coupling
- [Composition Principles](../composition-principles/SKILL.md) — "Program to Interfaces" is the primary tool for reducing coupling
- [OOP Pillars](../oop-pillars/SKILL.md) — Encapsulation and Abstraction are the mechanisms that enforce module boundaries

### Example trigger phrases

- "This module does too many things"
- "These two classes always change together — should they be one?"
- "A change here broke something over there — reduce the coupling"
- "Isolate this so I can test it without the database"
- "What belongs here vs in a separate module?"

### Violation checklist

| Signal | Principle violated |
|--------|--------------------|
| Class description requires "and" | High Cohesion |
| Helper/util class with unrelated static methods | High Cohesion |
| Two classes with methods that operate on each other's data | High Cohesion (consider merging) |
| Changing one class requires editing several others | Low Coupling |
| Unit test instantiates 4+ concrete dependencies | Low Coupling |
| Domain class imports infrastructure (`import pg from 'pg'`) | Low Coupling (direction) |
| Two classes that always change together are in separate modules | High Cohesion (consider collocating) |
| A module that is touched by every new feature | Low Coupling (it's a hub — decompose) |

### Example output with this skill active

**Without skill (Low cohesion + high coupling):**
```ts
// One class handles multiple unrelated concerns
// Directly coupled to infrastructure concretions
class OrderManager {
  private db = new PostgresDatabase();
  private mailer = new SendGridClient();
  private cache = new RedisCache();

  createOrder(data: any): Order { /* ... */ }
  processPayment(orderId: string): void { /* ... */ }
  shipOrder(orderId: string): void { /* ... */ }
  sendInvoice(orderId: string): void { /* ... */ }
  updateInventory(orderId: string): void { /* ... */ }
  generateOrderReport(): Report { /* ... */ }  // ← why is reporting here?
}
```

**With skill:**
```ts
// High cohesion: each class has a single, clear purpose
// Low coupling: dependencies are abstractions injected from outside

class OrderCreation {
  constructor(
    private readonly orders: IOrderRepository,
    private readonly validator: IOrderValidator
  ) {}
  create(data: OrderData): Order { /* ... */ }
}

class OrderProcessing {
  constructor(
    private readonly orders: IOrderRepository,
    private readonly payments: IPaymentGateway
  ) {}
  process(orderId: OrderId): void { /* ... */ }
}

class OrderShipping {
  constructor(
    private readonly orders: IOrderRepository,
    private readonly shipping: IShippingService
  ) {}
  ship(orderId: OrderId): void { /* ... */ }
}

class OrderInvoicing {
  constructor(
    private readonly orders: IOrderRepository,
    private readonly notifier: ICustomerNotifier
  ) {}
  sendInvoice(orderId: OrderId): void { /* ... */ }
}

// Reporting is a separate bounded concern — lives in its own module
class OrderReportingService {
  constructor(private readonly analytics: IOrderAnalytics) {}
  generateOrderReport(period: DateRange): Report { /* ... */ }
}
```

**What changed:**
- `OrderManager` had 6 unrelated responsibilities → split into 5 cohesive classes
- All infrastructure (`PostgresDatabase`, `SendGridClient`, `RedisCache`) → replaced with injected interfaces
- Reporting → moved to its own module (different change cadence, different team, different concern)
- Each class now testable in isolation with simple stubs
