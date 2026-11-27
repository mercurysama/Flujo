---
name: tell-dont-ask
description: Apply when code asks objects for their data and makes decisions externally based on it. Enforces the Tell, Don't Ask principle — objects should be told what to do, not queried for state and acted upon from the outside. Activates on anemic models, getter chains, Feature Envy, and logic that lives in the wrong place.
license: MIT
metadata:
  author: beskar
  version: "1.0.0"
---

# Tell, Don't Ask Skill

Tell, Don't Ask (TDA) is a fundamental OOP principle: rather than *asking* an object for its data and then making a decision externally, *tell* the object what to do and let it use its own data to decide. Code that violates TDA is fragile — callers become responsible for logic that belongs inside the objects they're interrogating.

TDA is the underlying principle behind Object Calisthenics Rule 9 (No Getters/Setters). This skill applies that principle more broadly — to services, controllers, event handlers, and anywhere behavior leaks out of the objects that own the relevant state.

---

## When to Apply

- A method reads several attributes from another object and makes decisions based on them
- Controllers or services contain `if` branches that check object state (e.g., `if user.status === 'active'`)
- Getter chains appear: `order.getCustomer().getMembership().getDiscount()`
- Domain objects are anemic — they hold data but contain no behavior
- The user asks for "move logic into the model", "better encapsulation", or "fix Feature Envy"
- A class uses more attributes of another class than its own

---

## Core Rules

### Move Decisions In

- If a caller reads an object's state and branches on it, that branch belongs inside the object.
- The rule: **the object that owns the data owns the decision about that data**.
- Replace `if (order.getStatus() === 'active')` in the caller with `order.process()` — let the order decide whether it's in a processable state.
- When you catch yourself saying "get X from Y, then do Z", stop and ask: should Y just do Z?

### Name for Behavior, Not Data

- Methods on objects describe *what the object does in the domain*, not *what data it exposes*.
- Replace `getStatus()` → `isActive()`, `isPending()`, `hasExpired()` — predicates that carry intent.
- Replace `getTotal()` (data) → `chargeCustomer(amount)`, `applyDiscount(rate)` (behavior).
- A method named `get*` is a smell — it invites the caller to make decisions the object should make itself.
- Acceptable exception: value objects whose entire purpose is to represent a value may expose it for serialization/display (e.g., `Money#amount`), but only at the boundary layer.

### Command-Query Separation

- A **command** changes state and returns nothing (void). It *tells* the object to do something.
- A **query** returns data and changes nothing. It *asks* the object for information.
- Never mix them in one method — a method that both changes state and returns data makes the caller responsible for both understanding the side effect and deciding what to do with the result.
- When you find a mixed method, split it: one method to perform the action, a separate query if the caller genuinely needs to inspect the outcome afterward.

### Detecting Violations

Treat these as TDA violation signals — each one points to logic that has leaked out of the object that owns it:

- **Getter chains** — `a.getB().getC().getD()`: you're traversing an object graph to get data you then act on. Move the action into `a`.
- **External conditionals on object state** — `if (obj.getX() > threshold)`: this condition belongs as a method on `obj`.
- **Feature Envy** — a method that references more attributes of another class than its own. Move it to the class it envies.
- **Duplicated state checks** — the same `if (order.status === ...)` appearing in multiple callers. Extract it once as `order.isActive()` or `order.canBeProcessed()`.
- **Anemic domain models** — entities with only getters/setters and no methods that do domain work. Every `get` that a service uses to make a decision is a behavior that belongs on the entity.

---

## How to Use

### Installing this skill

Copy the content below the YAML frontmatter and add it to your agent's instructions file:

- **Claude Code** — `CLAUDE.md` in your project root, or `~/.claude/CLAUDE.md` globally
- **Cursor** — `.cursorrules` file or `Settings > Rules for AI`
- **Windsurf** — `.windsurfrules` file
- **Any agent** — paste into the system prompt or custom instructions

### Relation to Object Calisthenics

This skill is the principle; [Object Calisthenics](../object-calisthenics/SKILL.md) Rule 9 is one enforcement mechanism. Use both together for maximum effect — OC Rule 9 prevents getters from existing; TDA explains *why* and guides where to put the behavior instead.

### Example trigger phrases

- "This service is making decisions about the model — fix it"
- "Move this logic into the class"
- "The controller knows too much about the domain"
- "Refactor away these getters"
- "This looks like Feature Envy"

### Violation checklist

When reviewing code, flag these in priority order:

1. External conditionals on object state → Move Decisions In
2. Getter chains longer than one hop → Detecting Violations
3. Service/controller methods longer than 10 lines that operate on a single entity → Feature Envy
4. Methods named `get*` that callers use for branching → Name for Behavior
5. Methods that both mutate state and return a value → Command-Query Separation
6. The same state check duplicated across callers → Extract to predicate method

### Example output with this skill active

**Without skill:**
```ts
// Caller asks, then decides
class OrderManager {
  confirm(order: Order, emailService: EmailService): void {
    if (order.getStatus() === 'active' && order.getItems().length > 0) {
      const discount = order.getCustomer().getMembershipLevel() === 'gold' ? 0.1 : 0;
      const total = order.getSubtotal() * (1 - discount);
      emailService.send(order.getCustomer().getEmail(), `Your total: ${total}`);
      order.setStatus('confirmed');
    }
  }
}
```

**Violations flagged:**
- `order.getStatus() === 'active'` — state check belongs on `Order` [Move Decisions In]
- `order.getCustomer().getMembershipLevel()` — two-hop getter chain [Detecting Violations]
- `order.getSubtotal() * (1 - discount)` — pricing logic belongs on `Order` [Feature Envy]
- `order.getCustomer().getEmail()` — notification routing belongs on `Customer` [Move Decisions In]
- Method both sends email and sets status — two commands, no separation [CQS]
- `emailService` injected as a method parameter — should be a constructor dependency [Program to Interfaces]

**With skill:**
```ts
// Objects are told what to do; dependencies are injected at construction time
class OrderManager {
  constructor(private readonly emailService: IEmailService) {}

  confirm(order: Order): void {
    order.confirm(this.emailService);
  }
}

class Order {
  confirm(emailService: IEmailService): void {
    if (!this.isConfirmable()) return;          // guard clause, decision owned here
    this.customer.notifyConfirmation(emailService, this.totalAfterDiscount());
    this.status = OrderStatus.confirmed();      // command: state change, returns nothing
  }

  private isConfirmable(): boolean {
    return this.status.isActive() && this.items.hasAny();
  }

  private totalAfterDiscount(): Money {
    return this.customer.applyMembershipDiscount(this.items.subtotal());
  }
}

class Customer {
  notifyConfirmation(emailService: IEmailService, total: Money): void {
    emailService.send(this.email, this.membership.formatConfirmation(total));
  }

  applyMembershipDiscount(amount: Money): Money {
    return this.membership.applyDiscount(amount);  // membership owns its own discount logic
  }
}
```

**What changed:**
- `OrderManager` is now a thin dispatcher — no domain knowledge, `emailService` injected via constructor
- `Order` owns all decisions about its own state and pricing
- `Customer` owns notification and discount application
- No getter chains — each object talks only to its direct collaborators
- State change (`status = confirmed`) is isolated inside `confirm()`, not visible to callers
