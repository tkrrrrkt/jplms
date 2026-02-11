# CLAUDE.md
# Claude Code Project Guide: Japan LMS MVP

This file guides Claude Code on how to handle the "Japan LMS MVP" project based on Moodle 4.x.

IMPORTANT — SOURCE OF TRUTH NOTICE

This file is NOT a source of truth.

Authoritative documents for this project are:
- `.kiro/steering/*.md` (Project Constitution)
- `.kiro/specs/<feature-name>/*` (Feature Specifications)

If there is any conflict, ALWAYS defer to the documents above.
This file exists only to help Claude Code navigate and comply with them.

---

## 1. Project Context & Steering

- **Project Name**: Japan LMS MVP
- **Tech Stack**: Moodle 4.x (PHP 8.2), MySQL 8.0, Nginx, Redis 7.x, Lambda Theme
- **Key Features**: 420-hour time tracking (`local_timetrack`), Stripe payment (staged), Certification
- **Framework**: cc-sdd (Specification-Driven Development)
- **Target Users**: Chinese nationals aiming to become certified Japanese language teachers
- **Architecture**: Single-tenant application (1 company, no multi-tenancy)

Product intent, scope, and AI philosophy are defined in:
- `.kiro/steering/product.md`

---

## 2. The "Commandments" (Fundamental Rules)

1. **SSoT is Specs**: The files in `.kiro/specs/` are the Single Source of Truth.
2. **NEVER Hack Core**: Do not modify `/lib`, `/course`, etc. Use `/local` or `/theme`.
3. **Plugin First**: Custom logic goes to `local/timetrack`. MVP payment uses standard `paygw_stripe` + `enrol_fee`.
4. **Security**: Use `$DB` global object (no raw SQL) and `required_param()`.
5. **Language**: Code comments in English, UI strings in Japanese (`lang/ja/`).
6. **SDD workflow is mandatory**: Do NOT skip steps or hand-roll specs.
7. **If unsure**: Stop, inspect `.kiro/steering/` and `.kiro/specs/`. Propose spec changes BEFORE code changes.

---

## 3. Common Commands

| Command | Purpose |
|---------|---------|
| `/kiro:spec-init "feature-name"` | Start a new feature specification |
| `/kiro:spec-requirements <feature>` | Generate requirements |
| `/kiro:spec-design <feature>` | Generate technical design |
| `/kiro:spec-tasks <feature>` | Generate implementation tasks |
| `/kiro:spec-impl <feature> [tasks]` | Implement tasks (TDD) |
| `/kiro:spec-status <feature>` | Check specification progress |
| `/kiro:steering` | Update/generate steering files |
| `/kiro:steering-custom` | Create custom steering |
| `/kiro:validate-design <feature>` | Design quality review (GO/NO-GO) |
| `/kiro:validate-gap <feature>` | Gap analysis (existing codebase) |
| `/kiro:validate-impl <feature>` | Implementation validation |

---

## 4. Directory Structure

```
.kiro/specs/     # Specification Documents (Markdown) — SSoT
.kiro/steering/  # Project Constitution (product, tech, structure)
local/           # Custom plugins location (timetrack, etc.)
theme/           # Theme customizations (Lambda Theme)
docs/            # Project guidelines
```

---

## 5. Required CCSDD Workflow (ALWAYS follow this order)

All feature work MUST follow:

1. `/kiro:spec-init "feature-name"`
2. `/kiro:spec-requirements "feature-name"`
3. `/kiro:spec-design "feature-name"`
4. `/kiro:spec-tasks "feature-name"`
5. Implement **ONE task at a time** from `tasks.md`

Before writing or modifying any code:
- Read `requirements.md`
- Then `design.md`
- Then `tasks.md`

If any section is missing or ambiguous:
> Update the spec first.
> Never "fill gaps" with assumptions in code.

Canonical definition of this workflow:
- `.kiro/steering/development-process.md`

---

## 6. What NOT To Do (Common Failures)

- Do NOT implement code before specs exist
- Do NOT infer missing requirements
- Do NOT modify Moodle core files (`/lib`, `/course`, `/mod`, etc.)
- Do NOT use raw SQL queries — always use `$DB` API
- Do NOT treat this file as authoritative spec
- Do NOT generate large refactors without spec updates

---

## 7. When in Doubt

If there is any uncertainty:
1. Open `.kiro/steering/development-process.md`
2. Check the relevant `.kiro/specs/<feature-name>/`
3. Propose clarification or update specs
4. Then proceed with implementation

Claude Code must behave as a **strict cc-sdd operator**, not an autonomous designer.
