# Flujo Object Model Contract

## Status and authority

This document defines a proposed PO🌊 object model for Flujo. Nothing in this document is implemented or authorized for implementation yet. Schema 4 remains governed by the [Declarative Constructor contract](declarative_constructor_contract.md); schemas 1–3 retain their existing meanings and behavior.

The proposal uses schema 5 because schema 4 already has an implemented, tested persistent meaning. Adding class inheritance, attributes, polymorphic references, multiple method outputs, or access control to schema 4 would silently change resources that can already be saved. This contract fixes the architectural decisions required for the schema 5 foundation; normal human change authorization remains required for every delivery.

## Terminology

- A **class definition** is a schema 5 `FlowGraph`.
- A **class ID** is the existing stable internal ID of that graph. No second `class_id` is introduced.
- An **instance** is one `PVController` whose `flow_graph` resolves to that class definition.
- A **definition** is persistent, shareable, and read-only during execution.
- A **runtime value** belongs to a runtime store or call frame. It is never written into a `Resource` definition.
- A **reference** identifies a persistent definition by ID. A path is only a scene-local locator and never definition identity.

## FOBJ-001 — Class definition, instance, and simple inheritance

Schema 5 gives `FlowGraph` an explicit class role. Its existing internal graph ID is the class identity across renames, moves, resource-path changes, and save/load. Duplicating a graph as a new class generates a new graph ID and new IDs for its owned definitions through one global old-ID → new-ID map.

Each `PVController` is one runtime instance of the resolved class. Multiple controllers may share the same immutable graph while owning independent instance state and scene bindings.

Inheritance is single and explicit through one nullable `base_class_id`. An empty value means a root class. The base is resolved through one project-owned, portable, exportable `FlowClassCatalog` stored with project content, never in the plugin directory and never through editor-only state. The catalog maps unique class IDs to loadable graph locators; a locator is not identity. It imposes no artificial count limit on classes.

The catalog validates unique class IDs, a maximum inheritance depth of 10, and all inheritance cycles before exposing an effective class. Self-inheritance, a missing or ambiguous class ID, an eleventh ancestor, a cycle, or a base resource that is not a compatible schema 5 class are deterministic errors. A derived class references inherited definitions; it does not copy them into its owned collections. A graph never stores a direct mutable reference to its base `FlowGraph` as inheritance identity.

## FOBJ-002 — Immutable definitions and runtime stores

Schema 5 definitions remain read-only during execution. Runtime state is divided into three portable stores:

1. `FlowInstanceRuntimeStore`, owned by one live `PVController`, contains instance attribute values, resolved requirement nodes, and instance lifecycle state.
2. `FlowClassRuntimeStore`, owned by the runtime environment, contains class attribute values keyed by `SceneTree` identity, class ID, and attribute ID. It is shared by controllers of that class during that `SceneTree`'s lifetime, survives scene changes and temporary absence of instances, and is released when that `SceneTree` ends.
3. `FlowCallFrame`, created per method invocation, contains parameter values, local values, output values, instruction position, depth, and consumed instruction budget.

These stores are runtime-only and are never serialized into `FlowGraph`, `FlowAttributeDefinition`, `FlowVariableDefinition`, `PackedScene`, or editor undo history. They use Godot-managed lifetimes; Flujo introduces neither raw pointers nor a garbage collector.

## FOBJ-003 — Attribute definitions

Schema 5 adds an ordered nullable `constructor.attributes` collection of `FlowAttributeDefinition` resources. Constructor owns declarations and defaults only; executable blocks, method bodies, locals, and control flow never belong in Constructor.

Each attribute contains:

- one stable internal ID;
- a visible, non-empty name;
- `enabled` and a user note;
- storage kind `INSTANCE` or `CLASS`;
- a type that directly reuses `FlowVariableDefinition.ValueType`;
- the seven existing typed default fields without renumbering or replacing the canonical enum;
- `nullable` and `default_is_null` flags;
- visibility and mutability dimensions; and
- optional accessor method IDs.

Attribute names are unique by exact case-sensitive comparison within the effective declaring-class namespace. Their IDs, not their names or positions, are references. Ordered `null` positions remain structural absence and are not nullable values.

## FOBJ-004 — Defaults, nullability, readonly, and const

A default is definition data used to initialize a runtime store. A runtime value is a separate value held by that store. A reference identifies the attribute definition and does not contain either value.

`default_is_null` is valid only when `nullable` is true. A non-null default must match the declared canonical type exactly; no implicit conversions are introduced. Nullability is never represented by a false enum member, an empty string, a `null` collection position, or a second value-type taxonomy.

Mutability is independent from visibility:

- `MUTABLE` permits writes allowed by visibility and accessors.
- `READONLY` permits reads to authorized callers but direct writes only through declaring-class initialization or an authorized declaring-class accessor.
- `CONST` permits exactly one initialization from the declared default and no subsequent setter, reset, or unset operation.

Reset restores the declared default. Unset stores null and is valid only for a nullable, non-const attribute. Neither operation removes or changes its persistent definition.

## FOBJ-005 — Instance and class attributes

Every controller initializes its instance store from enabled instance-attribute defaults. Mutating one controller's value cannot affect another controller or the shared graph.

Class attributes initialize once in the class store for a runtime execution. All instances resolved to the same class ID observe the same class value. Derived classes use the declaring class's class-store slot unless a separately declared attribute introduces a different ID; name shadowing never silently aliases storage.

Class storage is not a static field on a `Resource`, script, singleton, or process-global cache. Different `SceneTree` instances never share class attribute state, including in tests.

## FOBJ-006 — Coexistence with current Variables

Existing `FlowVariableDefinition` resources retain their stored fields, IDs, `LOCAL`/`GLOBAL` scope, bindings, defaults, order, null positions, and meaning. Migration never converts, renames, deletes, or reclassifies them as attributes. In particular, an existing `GLOBAL` variable does not silently become a class attribute.

The Variables surface may present inherited and declared attributes as read-only editorial projections. Such a row points to its attribute ID and declaring class ID; it is not another `FlowVariableDefinition`, is not inserted into `FlowGraph.variables`, and cannot edit or duplicate the attribute definition. Authoring remains in Constructor.

A future explicit **Promote Variable to Attribute** operation is separate from migration. It must construct an atomic candidate, preserve the source Variable and all of its data until explicit user confirmation, report reference and name conflicts deterministically, and use scene-context Undo/Redo. It may never reinterpret a Variable implicitly.

## FOBJ-007 — Polymorphic reference definitions

A future abstract `FlowReferenceDefinition` is a persistent `Resource` with:

- its own stable internal ID;
- `target_id`, identifying the target definition;
- `target_class_id`, identifying the declaring class; and
- one canonical expected target kind.

`target_class_id` is mandatory even when the target belongs to the current class; an empty value never means "current class" implicitly. This keeps copied, inherited, and externally stored references unambiguous.

The expected kind is `ATTRIBUTE`, `REQUIREMENT`, or `METHOD`. It is not a value-type enum and cannot substitute for `FlowVariableDefinition.ValueType`. Concrete resource type and expected kind must agree:

- `FlowAttributeReferenceDefinition` may additionally constrain the canonical value type and read/write intent.
- `FlowRequirementReferenceDefinition` may constrain the expected `Node` class but never stores a node or scene locator.
- `FlowMethodReferenceDefinition` identifies a method slot and is validated against its complete signature.

References are owned by the definition that uses them—for example a call block or value-source resource—and participate in the same graph-wide identity and duplication map. There is no central duplicate collection of references and no resolution by display name or array index.

## FOBJ-008 — Reference resolution and diagnostics

Resolution first locates `target_class_id` in the class catalog, then resolves `target_id` in that class's effective inherited definition set, and finally checks target kind, declared type or signature, accessibility, and ambiguity.

Empty, malformed, missing, cross-kind, incompatible, inaccessible, ambiguous, or cyclic references are preserved literally and produce stable code, path, related ID, and order. Validation never repairs them, searches by name, selects the first match, or mutates either graph.

Requirement references resolve only to `FlowRequiredNodeDefinition`. Runtime scene access then uses the owning controller's existing `requirement_id → NodePath` binding. `NodePath` remains a per-controller locator relative to the constructed object and never becomes graph identity. No `Node`, `Object`, or `Callable` is stored in a graph.

## FOBJ-009 — Encapsulation

Schema 5 introduces one canonical visibility enum:

- `PUBLIC`: accessible from every otherwise valid caller context.
- `PROTECTED`: accessible from the declaring class and its descendants.
- `PRIVATE`: accessible only from the declaring class.

The dropdown is presentation only. The validator, authoring catalog, and runtime resolver independently enforce the same rules using declaring and caller class IDs. A statically knowable violation is rejected before execution; a dynamically discovered violation produces a runtime diagnostic without widening access.

Visibility does not imply writability. Mutability, accessor availability, method kind, and caller context are checked separately. Static methods have no implicit instance access; class methods have no implicit instance access; instance methods may access authorized instance and class members.

Private members belong exclusively to their declaring class. They are not inherited, overridden, or reachable through Call Base/`super`. A derived class may declare the same visible name with a different ID; it is an independent slot, never an alias or override.

Only `PUBLIC` or `PROTECTED` methods may override an inherited method, and an override must declare its immediate target explicitly with a compatible method kind, visibility, parameter types, output types, nullability, and accessor role. Call Base/`super` resolves only the immediate parent implementation of that explicit override. A longer chain requires one Call Base at each level; arbitrary ancestor jumps and Call Base cycles are invalid.

## FOBJ-010 — Optional accessors

An attribute may refer by stable method ID to an optional getter, setter, resetter, and unsetter. Accessor definitions remain methods; they do not replace or delete the attribute definition or runtime slot.

- Getter: no input and exactly one output matching the attribute type; nullable attributes may output null.
- Setter: exactly one matching input and no output; forbidden for `CONST` and constrained by `READONLY`.
- Resetter: no input/output and restores the default; forbidden for `CONST` after initialization.
- Unsetter: no input/output and requires nullable, non-const storage.

Accessors cannot widen the attribute's visibility. An accessor for an instance or class attribute operates on that attribute's storage kind; it is not automatically an instance, class, or static method merely because it is an accessor. Signature and context validation determine the permitted method kind.

## FOBJ-011 — Node requirements and equivalent authoring paths

Schema 4 requirement identity, validation, bindings, constructed-object placement, and explicit atomic application remain unchanged.

The class selector creates a Require Node declaration by choosing an instantiable built-in `Node` class. Dragging from SceneTree either adopts an existing compatible requirement or prepares a new requirement plus a binding to that existing node. Both interactions produce the same `FlowRequiredNodeDefinition` and controller-owned binding shape, run the same complete preflight, and enter one `EditorUndoRedoManager` action only after explicit confirmation.

A visible future `FlowRequirementReferenceBlock` owns a `FlowRequirementReferenceDefinition`. It refers to the requirement by class and requirement IDs and never contains a direct node. Selection, drag, scene opening, validation, or runtime startup never applies Constructor automatically. Existing-node adoption follows DCON-005 and may not duplicate, rename, repair, or mutate nodes implicitly.

## FOBJ-012 — Processes and method kinds

Processes remain engine entry points such as Ready, Timer, Process, Physics Process, and input. They are not methods, overloads, or members and do not participate in visibility or method dispatch.

Schema 5 methods declare one method kind:

- `INSTANCE`: receives a controller instance context and may access authorized instance and class attributes.
- `CLASS`: receives class context and may access authorized class attributes only.
- `STATIC`: receives neither implicit instance nor class state; all data must arrive through parameters or explicit references allowed by the call.

Getter, setter, resetter, and unsetter are accessor roles. Their target attribute determines required context; the role does not automatically classify them as class methods.

## FOBJ-013 — Initial special methods

The first reserved special methods are deliberately limited:

- **On Initialized**: an instance method invoked once after requirement verification and instance-store initialization, immediately before Ready processes. It is the executable initialization hook; declarative Constructor remains data and it is not Godot's native `_init`.
- **To Text**: a pure instance method with no inputs and exactly one non-null String output. It may read arguments, accessible attributes, and local values only. It may not write state, nodes, bindings, or timers, and may not call a method with effects. Validation rejects an invalid signature or a reachable effectful operation with deterministic diagnostics; runtime enforces an instruction budget and reports deterministic exhaustion without modifying state.
- **On Dispose**: an instance method invoked once during orderly controller teardown before its instance store is released. It is not guaranteed after process termination or engine failure.

Their role, signatures, uniqueness, order, and runtime guards are validator rules rather than editable names. No arbitrary Godot callback exposure, operator overloading, constructor execution block, or implicit hook discovery is introduced.

## FOBJ-014 — Signatures, locals, outputs, and call frames

A complete method signature contains method kind, ordered parameter types, and ordered output types. Parameter and output display names and positions do not define identity; each definition has a stable ID. Overload selection compares method visible name plus exact ordered input/output types, with no implicit conversion. Once selected, calls persist the exact method reference by IDs.

Schema 5 supports zero or more ordered nullable output definitions. A schema 4 optional `return_definition`, when present, migrates into the first schema 5 output with the same ID, name, and type; absence migrates to an empty output collection. The source remains unchanged. Schema 5 has only the output collection as its source of truth.

Method-owned local definitions are persistent and ID-addressed. Parameter values, local values, and output values exist only in a `FlowCallFrame`. A Return block binds outputs by output ID and terminates that frame. Incomplete return paths are validation errors when a method declares required outputs.

Each call owns ordered nullable argument bindings. Every binding has its own ID, targets one parameter ID, and owns one future value-source reference; parameter position and name are never binding keys. Missing, additional, duplicate, unknown, or type-incompatible bindings remain literal and produce deterministic diagnostics. A call may ignore outputs, but an output can be consumed only by its stable output ID and only while its producing frame is valid.

Set Variable/Memory blocks target an explicit local, current legacy variable, or attribute reference. They never write default fields in definitions. Initial support requires exact type equality; conversions need a separate contract.

## FOBJ-015 — Controlled recursion and execution budgets

Recursion is disabled by default per method slot. Enabling it requires all of:

- an explicit authored flag;
- a validator-visible path from entry to Return that does not traverse a recursive call;
- a positive maximum call depth; and
- a positive instruction budget enforced across the complete controller execution.

The base-case check is conservative evidence, not a proof of termination. Runtime stops the affected call with a structured diagnostic when depth or budget is exhausted and does not corrupt caller frames or persistent data. Indirect recursion uses the same call-graph and budget rules.

## FOBJ-016 — Overloads and inherited polymorphism

Overloads are distinct method definitions selected by visible method name and exact structural signature, then stored by stable method reference. Ambiguous overload sets are invalid.

An override is a new method definition in a derived class with its own ID and an explicit `overrides_method_id` referring to the inherited method slot. Only public or protected slots may be overridden. An override must preserve method kind, visibility constraints, parameter types, output count, output types, nullability, and accessor role. Parameter/output display names may differ but cannot change the signature. A private same-name member is not an override.

Runtime polymorphism begins from the referenced base slot and selects the most-derived valid override for the controller's runtime class. Every variant in that slot shares the same inputs and outputs. Private methods cannot be overridden; static methods are hidden by explicit new definitions rather than dynamically dispatched.

## FOBJ-017 — Programmer mode boundary

Future Programmer mode may expose method signatures, parameters, multiple outputs, locals, Return, call frames, attribute/variable references, Set Variable/Memory, recursion controls, overloads, and override relationships.

It must not place method bodies, locals, arbitrary control flow, engine hooks, runtime values, or executable Constructor blocks inside the declarative Constructor. Constructor authors class structure: requirements, attributes, defaults, and declaration metadata. Processes remain a separate engine-entry surface.

## FOBJ-018 — Schema 5 and migration

These features require schema 5. Evidence is structural: schema 4 already serializes a declarative Constructor and scene bindings, while this proposal adds class meaning, inheritance, attributes, reference resources, visibility/mutability, method kinds, locals, multiple outputs, and overrides. Retrofitting them into schema 4 would change the interpretation of saved resources without a migration.

The public chain is explicit and atomic:

`schema 2 → schema 3 → schema 4 → schema 5`

The schema 4→5 step must:

1. validate and preserve the source without mutation;
2. retain graph/class ID, requirements, bindings contract, legacy constructor payload, processes, timers, state machines, methods, variables, order, null positions, and invalid authored references for diagnostics;
3. initialize no base class and no attributes;
4. retain every current Variable unchanged rather than converting it;
5. migrate the optional method return to zero or one output as specified by FOBJ-014;
6. translate each current method-call target into an owned method reference without resolving by name; and
7. publish only a fully validated independent candidate.

Invalid source resources remain intact and diagnosable; migration rejects them without repair or overwrite. Older validators and executors retain their existing schema boundaries. A schema 5 implementation must not be integrated until its complete persistent shape is frozen, otherwise later method fields would require another explicit schema.

## FOBJ-019 — Validation, duplication, and persistence

Schema 5 validation is deterministic and read-only. It builds complete class, inheritance, member, and reference indexes before resolving references. Diagnostics preserve invalid values and report stable code, path, related ID, and traversal order.

Duplication uses one global old-ID → new-ID map for every owned definition and reference resource. Internal targets included in the copied class remap after the map is complete; external class/member targets remain literal. Controller requirement bindings and all runtime stores remain outside graph duplication.

`ResourceSaver` and `PackedScene` coverage must prove class IDs, inheritance IDs, attributes, defaults, visibility, mutability, references, requirements, current Variables, method signatures, outputs, order, null positions, independent controller bindings, and no shared mutable runtime values.

## FOBJ-020 — Delivery plan and acceptance evidence

The implementation sequence is intentionally reviewable:

1. **Contract:** record this frozen schema 5 architecture. Commit: `docs: define Flow object model`.
2. **Schema 5 model and migration:** introduce the complete persistent schema 5 shape for inheritance, attributes, references, method signatures, locals, outputs, and overrides; implement atomic 4→5 and chained migration. Tests cover validation, source immutability, duplication, ResourceSaver, PackedScene, old Variables, and invalid-data preservation.
3. **Runtime stores:** add isolated instance, class, and call-frame stores with no executor expansion. Tests prove controller isolation, class sharing for one execution, initialization, teardown, nullability, readonly, const, and zero Resource mutation.
4. **Attribute/reference editor and accessibility:** author Constructor attributes and ID references, and show read-only attribute projections in Variables. Tests cover scene-context Undo/Redo, keyboard navigation, visibility labels, save/reopen, selection, and no duplicate source of truth; manual visual review is required.
5. **Methods and Programmer mode:** implement method kinds, accessors, locals, multiple outputs, Return, Set Variable/Memory, guarded recursion, overload selection, inherited dispatch, and pure To Text execution using the already-persisted schema 5 shape. Tests cover frames, access violations, SceneTree-isolated class stores, To Text purity and instruction budgets, exact signatures, overrides, Call Base chains, and structured diagnostics.
6. **Updated Apply Constructor:** only after inheritance and reference rules are operational, implement the common selector/drag preflight and atomic scene operation from the declarative contract. Tests cover adoption, creation, bindings, inherited/instanced scene ownership, Undo/Redo, and runtime verification.

Each delivery must preserve schemas 1–4, runtime/editor separation, stable identity, explicit migrations, null/order rules, and human authorization. Any implementation that needs another persistent field not fixed by the approved schema 5 contract must stop and request a new schema decision.

## Rejected alternatives

- Extending schema 4 in place: rejected because schema 4 has an implemented serialized meaning.
- Treating every `PVController` graph copy as a class: rejected because shared graph identity and per-instance state are already distinct.
- Storing runtime values in `Resource` defaults: rejected because instances may share definitions.
- Converting Variables to attributes automatically: rejected because current scopes and bindings do not establish equivalent semantics.
- Using names, indexes, resource paths, or `NodePath` as class/member identity: rejected because they are mutable presentation or locator data.
- Storing direct `Node`, `Object`, or `Callable` references in graphs: rejected because they are scene-instance state and are not portable definition identity.
- Executing blocks in Constructor: rejected because schema 4 makes Constructor declarative; On Initialized is the controlled executable lifecycle hook.
- Automatic node creation on drag, selection, load, or runtime: rejected because it bypasses preflight, Undo/Redo, ownership, and human control.

## Risks and fixed invariants

The remaining implementation risks are catalog corruption, inheritance-depth and cycle handling, accidental cross-`SceneTree` class state, effectful To Text paths, duplicate attribute projections, and accidental conversion of legacy Variables. The model protects against them through these fixed invariants:

- The project-owned catalog has unique class IDs, no artificial class-count cap, single inheritance only, maximum depth 10, and deterministic missing, ambiguous, depth, and cycle diagnostics.
- Class state is keyed by `SceneTree + class_id`; it survives scene changes within that tree and is never static or shared with another tree.
- To Text validates purity and its exact String signature, enforces its own instruction budget, and cannot mutate state, nodes, bindings, or timers.
- Variables keep their existing meaning through migration. Promotion is manual, atomic, reversible, and preserves the source until confirmation.
- Private members are declaring-class-only slots. Public/protected overrides are explicit and compatible; Call Base advances exactly one parent implementation and cannot jump or cycle.
- Deterministic diagnostics include at least duplicate or missing catalog class IDs, inheritance depth/cycles, invalid base class, inaccessible private member, incompatible override, invalid Call Base, Call Base cycle, invalid To Text signature, impure To Text operation, and To Text instruction-budget exhaustion.

There are no unresolved architectural decisions blocking the schema 5 foundation. A future proposal that introduces a persistent field outside the frozen schema 5 shape still requires an explicit schema decision and human authorization.

Everything is Flow; everything flows. 🌊
