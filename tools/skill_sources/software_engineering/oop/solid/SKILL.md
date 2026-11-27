---
name: solid
description: Apply when designing, writing, or reviewing object-oriented code. Enforces the five SOLID principles to produce systems that are easy to change, extend, and understand. Activates on class design, dependency wiring, interface design, and inheritance hierarchies.
license: MIT
metadata:
  author: beskar
  version: "1.0.0"
---

# SOLID Principles Skill

SOLID is five design principles that, together, guide object-oriented systems toward low coupling, high cohesion, and resilience to change. Each principle addresses a specific failure mode in OOP design.

---

## When to Apply

- Designing a new class, service, or module
- A class is growing large or hard to test in isolation
- Adding a feature requires modifying many existing classes
- A subclass breaks the behavior callers expect from the parent
- Interfaces are large and most implementors leave methods empty
- Concrete classes are referenced directly instead of abstractions

---

## Core Rules

### S — Single Responsibility Principle

**A class should have one reason to change.**

- Each class encapsulates one cohesive concept. If describing it requires the word "and", it has too many responsibilities.
- Common violations: an `OrderManager` that handles order validation, persists to the database, sends confirmation emails, and updates inventory.
- Extract each responsibility into its own class (`OrderValidator`, `OrderRepository`, `OrderNotifier`, `InventoryService`).
- "Reason to change" means a change in business rules for one concern should never require touching a class that serves a different concern.

### O — Open/Closed Principle

**Open for extension, closed for modification.**

- Existing, tested code should not need to change when new behavior is added.
- Replace `if/else` or `switch` chains that dispatch on type with polymorphism: add a new class, not a new branch.
- Use the strategy pattern, plugin points, or abstract factories so new variants extend the system rather than edit it.
- A sign of violation: every time a new `type` is added, you find yourself editing the same `switch` statement in multiple places.

### L — Liskov Substitution Principle

**Subtypes must be fully substitutable for their base types.**

- Every place a base class is used, a subclass must work correctly without the caller knowing which it has.
- Violations: a subclass throws on a method the base supports, narrows accepted inputs, or widens return types.
- The classic violation: `Square extends Rectangle` where setting width also changes height — callers that set dimensions independently break silently.
- Prefer composition over inheritance when a subclass cannot honor the full contract of the base (see [Composition Principles](../composition-principles/SKILL.md)).
- LSP violations are often a sign the inheritance hierarchy models implementation rather than behavior.

### I — Interface Segregation Principle

**No client should be forced to depend on methods it does not use.**

- Prefer many small, focused interfaces over one large general-purpose interface.
- A class that implements an interface but leaves methods empty or throws `NotImplementedError` is a sign the interface is too broad.
- Split interfaces along client needs, not along implementation convenience.
- Example: split `IWorker { work(), eat(), sleep() }` into `IWorkable { work() }` and `IRestable { eat(), sleep() }` — a `Robot` implements only `IWorkable`.

### D — Dependency Inversion Principle

**Depend on abstractions, not concretions.**

- High-level modules define what they need via interfaces or abstract types; low-level modules implement those interfaces.
- Never instantiate a dependency with `new` inside a class — inject it through the constructor or a factory.
- This makes classes independently testable: swap the real implementation for a test double without touching the class.
- Violation signal: `import ConcreteEmailService from './email-service'` inside a domain class. The domain should depend on `IEmailService`, and the concrete class is wired up at the composition root.

---

## How to Use

### Installing this skill

Copy the content below the YAML frontmatter and add it to your agent's instructions file:

- **Claude Code** — `CLAUDE.md` in your project root, or `~/.claude/CLAUDE.md` globally
- **Cursor** — `.cursorrules` file or `Settings > Rules for AI`
- **Windsurf** — `.windsurfrules` file
- **Any agent** — paste into the system prompt or custom instructions

### Related skills

- [Object Calisthenics](../object-calisthenics/SKILL.md) — structural enforcement rules that operationalize SRP and ISP
- [Tell, Don't Ask](../tell-dont-ask/SKILL.md) — operationalizes DIP by keeping behavior with the data that drives it
- [Composition Principles](../composition-principles/SKILL.md) — the alternative when LSP cannot be satisfied by inheritance

### Example trigger phrases

- "This class does too much — refactor it"
- "Apply SOLID to this design"
- "I keep editing the same file for every new type — fix it"
- "This subclass breaks when the parent is expected"
- "Inject the dependency instead of instantiating it"

### Violation checklist

| Signal | Principle violated |
|--------|--------------------|
| Class description needs "and" | SRP |
| Adding a type means editing a `switch`/`if-else` | OCP |
| Subclass throws or ignores inherited methods | LSP |
| Interface implementation leaves methods empty | ISP |
| `new ConcreteClass()` inside a domain class | DIP |
| Tests require the real database, email server, or HTTP client | DIP |

### Example output with this skill active

**Without skill (SRP + DIP violation):**
```ts
class OrderManager {
  createOrder(data: any): void {
    // validation — responsibility 1
    if (!data.customerEmail || !data.items.length) throw new Error('Invalid order');
    // persistence — responsibility 2, direct dependency on infrastructure
    const db = new PostgresDatabase();
    db.save({ customerEmail: data.customerEmail, items: data.items });
    // notification — responsibility 3
    const mailer = new SendGridMailer();
    mailer.send(data.customerEmail, 'Order created!');
    // inventory update — responsibility 4
    const inventory = new InventoryService();
    data.items.forEach(item => inventory.reserve(item.sku, item.quantity));
  }
}
```

**With skill:**
```ts
// SRP: each class has one responsibility
// DIP: OrderManager depends on abstractions, not concretions
class OrderManager {
  constructor(
    private readonly orders: IOrderRepository,
    private readonly notifier: IOrderNotifier,
    private readonly validator: IOrderValidator,
    private readonly inventory: IInventoryService
  ) {}

  createOrder(data: OrderData): Order {
    this.validator.validate(data);
    const order = Order.create(data);
    this.orders.save(order);
    this.notifier.confirmOrder(order);
    this.inventory.reserveItems(order.items());
    return order;
  }
}

// Concretions wired at the composition root — not inside the domain class
const manager = new OrderManager(
  new PostgresOrderRepository(db),
  new SendGridOrderNotifier(mailer),
  new OrderDataValidator(),
  new WarehouseInventoryService()
);
```
