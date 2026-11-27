---
name: oop-pillars
description: Apply when designing object-oriented systems from the ground up or evaluating how well a codebase uses OOP. Enforces the four foundational pillars — Encapsulation, Abstraction, Inheritance, and Polymorphism — each at the right depth and for the right reason.
license: MIT
metadata:
  author: beskar
  version: "1.0.0"
---

# OOP Pillars Skill

The four pillars of object-oriented programming are not just language features — they are design commitments. Used correctly, they reduce coupling and make systems easier to reason about. Used carelessly, they produce brittle hierarchies, leaking internals, and code that is harder to change than the procedural equivalent it replaced.

---

## When to Apply

- Designing a domain model or class hierarchy from scratch
- A class exposes internal state that callers use to make decisions
- Inheritance is being used to share code rather than to model an "is-a" relationship
- A method handles many unrelated object types with `if`/`switch` on type tags
- The codebase conflates interface (what) with implementation (how)

---

## Core Rules

### Encapsulation

**Hide state. Expose behavior.**

- Internal fields are private by default. Expose only what external collaborators genuinely need.
- Do not expose state so callers can make decisions — expose methods that make those decisions internally (see [Tell, Don't Ask](../tell-dont-ask/SKILL.md)).
- Encapsulation is not just access modifiers. A class that exposes all its fields as public getters is not encapsulated, even if technically "private" fields exist.
- Invariants live inside the class. A class that allows callers to put it into an invalid state has failed to encapsulate.
- Constructors and factory methods are the gatekeepers: validate and establish invariants at construction time, not at use time.

### Abstraction

**Model at the right level. Hide what doesn't matter.**

- An abstraction hides complexity behind a name that expresses intent. `processPayment()` is an abstraction; `connectToStripeAndPostJSON()` is an implementation detail leaking through.
- Match abstraction level to the layer: domain logic works with `Order`, `Customer`, `Payment` — not with SQL rows, HTTP responses, or file handles.
- Interfaces and abstract classes are tools for abstraction — they define *what* without specifying *how*. Keep interface names focused on capability, not on the specific implementor (`IPaymentGateway`, not `StripeAdapter`).
- Avoid "abstraction for abstraction's sake" — a one-method interface with one implementor that will never change adds overhead with no benefit. Abstract when the boundary genuinely exists or is likely to flex.

### Inheritance

**Use for "is-a", not for "has-some-of".**

- Inheritance models a genuine subtype relationship: every `SavingsAccount` truly is a `BankAccount`. If you can only say "shares some behavior with", use composition instead.
- A subclass must honor the full contract of its parent — if it cannot, the hierarchy is wrong (see LSP in [SOLID](../solid/SKILL.md)).
- Prefer shallow hierarchies (one or two levels). Deep hierarchies make behavior hard to trace and changes at the top ripple unpredictably downward.
- Never use inheritance to avoid duplication. Shared behavior belongs in a collaborator object, a mixin/trait, or a utility — not a common base class invented to share code.
- Protected fields in a base class are a coupling smell — subclasses that read parent state are tightly bound to its implementation, not just its interface.

### Polymorphism

**One interface, many implementations. Let the type system dispatch.**

- Polymorphism eliminates `if (type === 'X') ... else if (type === 'Y')` by replacing type-tag branching with method dispatch.
- Callers work with the abstract type; the right behavior is selected at runtime by the concrete type. Callers do not know and should not care which implementation they hold.
- Prefer interface-based polymorphism (many classes implement a common interface) over inheritance-based polymorphism when the types don't share an "is-a" relationship.
- Duck typing (in dynamic languages) is polymorphism without explicit interface declarations — the principle is the same: if it responds to the right messages, it can stand in.
- Overusing polymorphism for trivial variation (one method that always returns a constant) adds indirection with no payoff. Use it when behavior genuinely differs and the variation point is likely to grow.

---

## How to Use

### Installing this skill

Copy the content below the YAML frontmatter and add it to your agent's instructions file:

- **Claude Code** — `CLAUDE.md` in your project root, or `~/.claude/CLAUDE.md` globally
- **Cursor** — `.cursorrules` file or `Settings > Rules for AI`
- **Windsurf** — `.windsurfrules` file
- **Any agent** — paste into the system prompt or custom instructions

### Related skills

- [SOLID](../solid/SKILL.md) — principles that operationalize these pillars in class and interface design
- [Tell, Don't Ask](../tell-dont-ask/SKILL.md) — the practice that enforces Encapsulation at the method level
- [Composition Principles](../composition-principles/SKILL.md) — the alternative when Inheritance is tempting but wrong

### Example trigger phrases

- "This class exposes too much internal state"
- "Stop using inheritance for code reuse"
- "Replace this type switch with polymorphism"
- "The abstraction is leaking implementation details"
- "Make this interface not care about how it's implemented"

### Violation checklist

| Signal | Pillar violated |
|--------|----------------|
| Public fields or getters used for external branching | Encapsulation |
| Caller validates object state before calling a method | Encapsulation |
| Method name reveals infrastructure detail (`fetchFromS3`, `postToStripe`) in domain code | Abstraction |
| Interface named after its only implementor (`StripePaymentGateway` as an interface) | Abstraction |
| Base class extended to share utility code, not to model a subtype | Inheritance |
| Subclass overrides a method to throw `NotImplemented` | Inheritance (LSP) |
| `if (obj instanceof X)` or `switch (obj.type)` in caller code | Polymorphism |
| Two classes with identical method signatures but no shared interface | Polymorphism |

### Example output with this skill active

**Without skill (Encapsulation + Polymorphism violations):**
```ts
class OrderManager {
  process(order: any): void {
    if (order.type === 'physical') {
      this.shippingService.ship(order.address, order.items);
    } else if (order.type === 'digital') {
      this.emailService.send(order.customer.email, order.downloadLink);
    } else if (order.type === 'subscription') {
      this.subscriptionService.activate(order.customer.id, order.plan);
    }
    // adding a new order type means editing this method again — OCP violation
  }
}
```

**With skill:**
```ts
// Abstraction: interface defines the capability, hides the how
interface Order {
  process(): void;
}

// Polymorphism: each order type owns its own processing behavior
class PhysicalOrder implements Order {
  constructor(
    private readonly customer: Customer,
    private readonly items: OrderItems,
    private readonly address: ShippingAddress
  ) {}
  process(): void {
    this.shippingService.ship(this.address, this.items);
  }
}

class DigitalOrder implements Order {
  constructor(
    private readonly customer: Customer,
    private readonly downloadLink: DownloadLink
  ) {}
  process(): void {
    this.emailService.send(this.customer.email, this.downloadLink);
  }
}

class SubscriptionOrder implements Order {
  constructor(
    private readonly customer: Customer,
    private readonly plan: SubscriptionPlan
  ) {}
  process(): void {
    this.subscriptionService.activate(this.customer.id, this.plan);
  }
}

// Encapsulation: OrderManager knows nothing about order processing internals
// Adding a new order type = new class, no changes here
class OrderManager {
  process(order: Order): void {
    order.process();  // dispatch — no type-checking, no branching
  }
}
```
