# Future Work

> **Status:** Current  
> **Audience:** Aztec/Noir contributors, roadmap reviewers  
> **Last updated:** 2026-05-13

Planned extensions beyond the current PoC. Listed in priority order. Each item references the gap
or milestone it closes.

---

## PR-1: Transitive composition -- inject or warn (Closes G-1)

**Goal:** When a host composes `mid_template` and `mid_template` itself composed `foo_template`,
the host silently does not get `foo_value()`. Fix this, preferably by injecting transitively;
fall back to a compile warning if injection proves problematic.

### Option A: Transitive injection (preferred)

**Feasibility:** Yes, with moderate effort.

The root cause is that `#[contract_template]` runs before `inject_template_functions_to_registries`
and therefore only registers a template's own original functions. To support transitive injection:

1. In `#[contract_template]`, also register the template's composed IDs:
   `TEMPLATE_COMPOSED_IDS: CHashMap<Field, [Field]>` -- stores which template IDs this template
   itself composed
2. In `inject_template_functions_to_registries`, after injecting the requested templates, look up
   their composed IDs and recursively inject those too
3. Use a processed-set for deduplication -- if the host explicitly composed `foo` AND `mid` (which
   also composed `foo`), inject `foo` only once; the second encounter is a no-op

**Collision handling:** same rules apply to transitively injected functions -- if a grandchild
function name collides with a host function, it is an error (same as today for direct collisions).

**Effort:** Medium -- new registry key + recursive loop with dedup guard.

### Option B: Compile warning (fallback)

If transitive injection produces unexpected complexity (e.g., ambiguous collision semantics when
a function appears in multiple transitive paths), emit a compile warning instead:

In `compose_template.nr`, after resolving each template module, check whether that module has
any entries in `TEMPLATE_COMPOSED_IDS`. If so, emit a `println!` or `std::compile_error` warning
listing the grandchild ids that are NOT flattened.

**Effort:** Small -- one check + message.

### Decision for PR-1

Start with Option A. If the recursive deduplication logic is clean, ship injection. If the
collision semantics for multi-path grandchildren are unclear, fall back to Option B (warning)
and leave injection for a follow-up once the semantics are agreed.

**Doc updates when done:**
- `02-feature-matrix.md`: entry #8 status changes from `KNOWN_GAP` to `IMPLEMENTED`
- `03-gap-analysis.md`: G-1 decision updated
- `04-template-authoring.md`: update "list all templates explicitly" rule to reflect new behavior

---

## PR-3/PR-4: Virtual/override mechanism + abstract templates (Closes G-2, matrix #10 and #16)

**Status:** Implemented.

Template functions can be marked with `#[template_virtual]` and replaced by host implementations via
`override_template("template_id", "fn_name")` in `AztecConfig`.

- Single-level override only (no `super`).
- Abstract templates are now a convention via `#[template_virtual]` on all external functions.
- No storage/events changes were required for this PR.

### Evidence

- `composition_override` test package
- `composition_fixtures/virtual_template`

---

---

## Possibilities with Noir support

The items below are blocked on upstream Noir API changes. They are documented here as design
sketches so the work is ready to execute once the language support lands. None are required for
the current PoC.

---

### Storage field injection (Closes G-4, matrix #14)

**Goal:** Host declares only its own storage fields; template fields are injected automatically.

**Blocked on:** `TypeDefinition::add_field` does not exist in the Noir comptime API.

**Required Noir change:**
```noir
comptime fn add_field(self: TypeDefinition, name: Quoted, typ: Type)
```

**Aztec-side implementation (once unblocked):**

1. In `#[contract_template]`, register storage field names and types:
   ```
   TEMPLATE_STORAGE_FIELDS: CHashMap<Field, [(Quoted, Type)]>
   ```
   (The foundation is already known -- `#[contract_template]` processes the template's Storage
   struct; the registry entry just needs to be added.)
2. Add a compose-aware storage attribute variant: `#[storage("template_id", ...)]` or auto-detect
   from the compose config.
3. In the storage macro, look up registered field names and call `TypeDefinition::add_field` for
   each missing field before slot assignment.

**Design questions (resolve when filing the Noir issue):**
- Opt-in (`#[storage("template_id")]`) or automatic (inject if compose config present)?
- Slot ordering: template fields first (lower slots, safer for upgrades) or host-declaration order?
- If the host declares a field with the same name as a template field: error or silent shadowing?

**Action:** File an upstream Noir issue requesting `TypeDefinition::add_field`. Link the issue
in `03-gap-analysis.md` G-4 once filed.

**Tracking:** Noir upstream issue not yet filed. This PR serves as the placeholder; the Aztec-side
design sketch above is complete and ready to implement once the Noir API lands. No code changes
in this PoC.

---

### Event struct auto-injection (Closes G-6)

**Goal:** Event structs referenced in composed bodies are replayed into the host automatically.
Currently the host must re-declare every event struct used in composed function bodies.

**Status:** Not planned as active work -- inconvenient but not critical. Revisit if a clean
implementation becomes apparent.

**Approach if pursued:**
1. `#[contract_template]` registers event struct `Quoted` definitions alongside function wrappers
   (hook point in `template_registry.nr` exists)
2. `get_composed_templates_quoted` replays event struct declarations into the host module
3. Event selector registration is already idempotent (same-name same-signature is allowed)

**Complexity:** Non-trivial -- event registration (`events.nr`) has its own global registry and
the struct emission timing relative to `#[event]` macro processing must be verified before
committing to this.

---

## Language asks (upstream Noir/Aztec)

These are Noir or Aztec-level improvements that would simplify or improve the composition
mechanism. None are required for the current PoC to work. Items marked as "Noir" require
an upstream Noir issue; "Aztec" items are macro-level changes possible once the Noir API lands.

### High priority

**1. `TypeDefinition::add_field` (Noir)**  
Enables automatic storage field injection. Single most impactful language change -- see
"Storage field injection" above for the full design sketch.

**2. Hygienic `Quoted` with self-crate path preservation (Noir)**  
Helper paths written inside a template retain their original crate identity when replayed in a
host. Would eliminate the need to route constants through `#[contract_library_method]` wrappers
and would allow event structs to resolve naturally without re-declaration.

**3. `#[immutable]` attribute for template constants (Aztec macro)**  
Today, the convention for template-owned constants is `#[contract_library_method]` (Pattern A in
`04-template-authoring.md`). A first-class `#[immutable]` attribute would make the intent
explicit, enforce it at the compose layer, and produce better diagnostics when a host tries to
shadow the binding. Until this exists, `#[contract_library_method]` is the correct pattern.

### Medium priority

**4. `Module` reflection over all top-level items (Noir)**  
Today `Module` exposes functions/structs/child modules but not globals, events, or `use`
declarations. Broader reflection would let the template registration machinery migrate more items
automatically.

**5. Safe cross-crate body reuse at comptime (Noir)**  
The registry-and-replay approach exists because later cross-crate `f.body()` calls are awkward.
If macros could safely inspect foreign function bodies at any point, much of the registry machinery
could be simplified.

### Low priority

**6. Quoted `use` declaration replay (Noir)**  
Would allow composed bodies to bring their own imports rather than requiring the host to declare
them. Removes one category of host boilerplate.

**7. Native template/host compatibility checking (Aztec macro)**  
A first-class validation pass that checks required storage fields, events, and collision risks
before the user hits lower-level type errors. Today this is purely implicit.
