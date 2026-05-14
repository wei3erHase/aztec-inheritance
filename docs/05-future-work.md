# Future Work

> **Status:** Current  
> **Audience:** Aztec/Noir contributors, roadmap reviewers  
> **Last updated:** 2026-05-13

This file is the decision queue for **what changes can be pursued without breaking current shipped behavior**
and what requires upstream compiler support.

Use this as a triage tool before opening a new PR:

- **Can we implement now?** → PR candidate with proof package.
- **Needs Noir upstream?** → file issue first, then track as blocked.
- **Should remain design boundary?** → no implementation unless product scope changes.

---

## 1) Feature evaluation playbook

For each candidate:

1. Classify as one of:
   - immediate PR
   - upstream dependency
   - model boundary
2. Add a passing fixture and a forbidden fixture when behavior is constrained.
3. Update matrix + gap analysis + authoring guide simultaneously.
4. Record decision in this file with explicit "done / blocked / out-of-scope."

---

## PR-1: Transitive composition -- flatten transitive dependencies (G-1)

**Status:** Implemented.

**Done because:** host selection now recursively resolves composed IDs and deduplicates template IDs.

**Current reminder:** keep recursion behavior as the default unless a future syntax introduces explicit depth policy.

---

## PR-2: Event struct auto-replay from templates

**Status:** Implemented.

**Done because:** event structs required by composed bodies are now replayed from template declarations.

**Operational reminder:** avoid reintroducing manual event redeclaration requirements in docs.

---

## PR-3/PR-4: Virtual/override + abstract convention (G-2, #10, #16)

**Status:** Implemented.

**Core rule:** single-level virtual override only.

**Template side:** `#[template_virtual]`  
**Host side:** `override_template("template_id", "fn")` in `AztecConfig`.

**Open follow-up:** multi-layer override semantics remain a separate design decision.

---

## Upstream-gap item (currently blocked): storage field injection (G-4)

**Status:** Not implemented.

**Goal:** auto-inject template storage declarations into host.

**Blocker:** missing Noir comptime API `TypeDefinition::add_field`.

### Required Noir change

```noir
comptime fn add_field(self: TypeDefinition, name: Quoted, typ: Type)
```

### Design sketch

1. `#[contract_template]` registers template storage requirements.
2. Compose hook detects requirements and applies field injection before host slot assignment.
3. Compose rejects missing required storage with deterministic errors.

### Tracking

Issue not yet linked. Keep this section as the single source for upstream-ready design.

---

## Language asks and upstream asks

Prioritize asks by blast radius and clarity:

1. `TypeDefinition::add_field` (highest impact, unblock storage injection).
2. Hygienic cross-module `Quoted` that preserves crate identity in replayed references.
3. `Module` reflection for globals/imports/events to reduce host boilerplate.
4. `#[immutable]` template constant intent (Aztec-level macro attribute).
5. Compile-time compatibility validator that reports missing storage/imports/override mismatches earlier.

---

## How to use this file when planning

- If a request depends on unsupported compiler behavior, route here before touching vendor macros.
- If a request is executable in current model, open it in an implementation PR with evidence.
- If a request should stay out of scope, add a short BY_DESIGN or OUT_OF_SCOPE note with rationale in
  matrix/gap docs to prevent ambiguity.
