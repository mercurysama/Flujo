---
name: composition-principles
description: Apply when deciding between inheritance and composition, wiring dependencies, or reviewing how objects relate to each other. Enforces Composition over Inheritance, Program to Interfaces, and the Law of Demeter — three principles that govern how objects are assembled and how they communicate.
license: MIT
metadata:
  author: beskar
  version: "1.0.0"
---

# Composition Principles Skill

Three complementary principles govern how objects are assembled and how they communicate: prefer composition over inheritance for flexibility, depend on interfaces not concretions for replaceability, and restrict object graph traversal for loose coupling. Together they produce systems that are easier to extend, test, and reason about.

---

## When to Apply

- Choosing between inheritance and composition to share or extend behavior
- A class hierarchy is growing deep or lateral subclasses are diverging
- Changing a dependency requires modifying the class that uses it
- A method accesses data through a chain of objects it does not directly own
- Tests require complex setup of unrelated objects to test a single class

---

## Core Rules

### Composition over Inheritance

**Favor "has-a" over "is-a" whenever the relationship is about behavior, not identity.**

- Inheritance is appropriate only when a subtype relationship is true at the domain level and the subclass can honor the full parent contract (LSP). In all other cases, compose.
- The failure mode of inheritance: a `FlyingFish` that inherits from both `Bird` and `Fish` to get their behaviors, when fish and birds are unrelated concepts — behaviors should have been extracted as separate collaborators.
- Extract shared behavior into a standalone object and inject it. A `Logger`, `Validator`, or `PricingStrategy` used by multiple classes is a composable collaborator, not a base class.
- Composition is more flexible at runtime: a composed behavior can be swapped, combined, or decorated without changing the class that uses it. Inherited behavior is fixed at compile time.
- Mixin/trait-based languages (Ruby, Rust, Scala) offer a middle path, but the principle still applies: prefer explicit collaborator injection over implicit behavioral inheritance when the relationship is "uses" rather than "is".

### Program to Interfaces, Not Implementations

**Depend on the shape of a thing, not its specific form.**

- When a class needs a collaborator, it should declare what capabilities it needs (an interface or abstract type), not which specific class provides them.
- This makes the class independently testable (swap in a test double), independently deployable (swap in a different implementation), and resilient to change in the collaborator.
- Name interfaces after the **capability or role** they represent, not the implementor: `ICache`, `IPaymentGateway`, `ILogger` — not `RedisCache`, `StripeGateway`, `WinstonLogger`.
- Concrete classes are resolved at the **composition root** — the single place (entry point, DI container, factory) where the object graph is assembled. Domain logic never references concrete classes directly.
- Avoid "interface per class" as a reflex — create an interface when you have or expect multiple implementations, or when the boundary between modules requires it. A single-implementor interface with no test doubles and no plans for variation adds noise.

### Law of Demeter

**Talk only to your direct friends. Don't talk to strangers.**

- A method should only call methods on: itself, its parameters, objects it creates, and its direct instance variables. Not on objects *returned* by those.
- `a.getB().getC().doSomething()` is a violation — `a` is reaching through `B` to get to `C`. The caller knows too much about the internal structure of `B`.
- Each hop in a chain is a dependency on an intermediate object's implementation. If `B` changes how it holds `C`, every chain that crosses `B` breaks.
- Fix by moving the behavior closer to the data: either `B` should expose a method that does what the caller needs with `C`, or the caller should be given `C` directly.
- Exception: fluent builders and value object method chains (`Money.of(100).withDiscount(0.1).format()`) are acceptable because chaining on *the same object* does not traverse foreign object graphs.

---

## How to Use

### Installing this skill

Copy the content below the YAML frontmatter and add it to your agent's instructions file:

- **Claude Code** — `CLAUDE.md` in your project root, or `~/.claude/CLAUDE.md` globally
- **Cursor** — `.cursorrules` file or `Settings > Rules for AI`
- **Windsurf** — `.windsurfrules` file
- **Any agent** — paste into the system prompt or custom instructions

### Related skills

- [SOLID](../solid/SKILL.md) — DIP is the SOLID expression of "Program to Interfaces"; LSP explains when inheritance is and isn't safe
- [OOP Pillars](../oop-pillars/SKILL.md) — Polymorphism and Abstraction underpin why interfaces work
- [Tell, Don't Ask](../tell-dont-ask/SKILL.md) — the method-level expression of Law of Demeter
- [Object Calisthenics](../object-calisthenics/SKILL.md) — Rule 5 (one dot per line) enforces Law of Demeter structurally

### Example trigger phrases

- "Use composition instead of inheritance here"
- "This is reaching through objects — apply Law of Demeter"
- "Depend on the interface, not the concrete class"
- "I need to swap this dependency in tests"
- "This hierarchy is getting too deep"

### Violation checklist

| Signal | Principle violated |
|--------|--------------------|
| Subclass inherits to reuse utility code, not to be a subtype | Composition over Inheritance |
| Deep inheritance tree (3+ levels) with lateral specialization | Composition over Inheritance |
| Concrete class referenced directly in domain code via `new` or `import` | Program to Interfaces |
| Interface named after its implementor (`PostgresUserRepo` as interface) | Program to Interfaces |
| Method chain crossing 2+ object boundaries (`a.b().c().d()`) | Law of Demeter |
| Unit test requires setting up 3+ unrelated objects to test one method | Law of Demeter / Program to Interfaces |

### Example output with this skill active

**Without skill (Inheritance for reuse + Demeter violation):**
```ts
// Inheritance to share db + logging utilities — OrderManager is not a subtype of BaseManager
class BaseManager {
  protected db = new PostgresDatabase();
  protected log(msg: string) { console.log(msg); }
}

class OrderManager extends BaseManager {
  ship(order: Order): void {
    this.log('Shipping order...');
    // Demeter violation: traversing order → customer → address → city
    const city = order.getCustomer().getAddress().getCity().getName();
    this.db.execute(`UPDATE orders SET status='shipped' WHERE id='${order.getId()}'`);
    this.log(`Shipped to ${city}`);
  }
}
```

**With skill:**
```ts
// Composition: ILogger and IShippingService are collaborators, not base classes
// Program to interfaces: OrderManager depends on abstractions, not PostgresDatabase
class OrderManager {
  constructor(
    private readonly logger: ILogger,
    private readonly orders: IOrderRepository,
    private readonly shipping: IShippingService
  ) {}

  ship(order: Order): void {
    this.logger.info('Shipping order', { orderId: order.id() });
    // Law of Demeter: Order surfaces what the caller needs directly
    this.shipping.dispatch(order.shippingDestination());
    this.orders.markShipped(order.id());
  }
}

// Order knows how to express its own shipping destination — doesn't expose its internals
class Order {
  shippingDestination(): ShippingDestination {
    return this.customer.shippingDestination();
  }
}
```
