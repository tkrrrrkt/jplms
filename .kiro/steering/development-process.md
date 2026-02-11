# Development Process (CCSDD Workflow)

This document defines the canonical development workflow for the Japan LMS MVP project.
All feature work MUST follow this process. Skipping steps or hand-rolling specs is prohibited.

## 1. Core Principle: Spec-Code-Verify

The project adopts **Specification-Driven Development (SDD)** with the cc-sdd framework.
The fundamental loop is:

1. **Spec** — Write/update specifications in `.kiro/specs/`
2. **Code** — Generate implementation based on approved specs
3. **Verify** — Validate implementation against specs; fix specs (not code) if misaligned

**SSoT (Single Source of Truth):** `.kiro/specs/` is the authoritative source for all feature requirements, designs, and task definitions. When in doubt, always return to the spec.

## 2. Development Phases

### Phase 0: Project Steering (One-time / Periodic)

Maintain project-wide context in `.kiro/steering/`:

| File | Purpose |
|------|---------|
| `product.md` | Product overview, core capabilities, target users |
| `tech.md` | Technology stack, development standards, key decisions |
| `structure.md` | Directory patterns, naming conventions, code organization |
| `development-process.md` | This file - workflow definition |

**Commands:**
- `/kiro:steering` — Bootstrap or sync steering files
- `/kiro:steering-custom` — Add domain-specific steering (database, security, etc.)

### Phase 1: Specification (Per Feature)

Each feature follows a strict sequential pipeline with human approval gates:

```
/kiro:spec-init "description"
       |
       v
/kiro:spec-requirements <feature>  --> Review & Approve requirements.md
       |
       v
/kiro:spec-design <feature>        --> Review & Approve design.md
       |
       v
/kiro:spec-tasks <feature>         --> Review & Approve tasks.md
```

**Resulting directory structure:**
```
.kiro/specs/<feature-name>/
    ├── spec.json           # Metadata (phase tracking, approvals)
    ├── requirements.md     # EARS-format requirements (SSoT for "what")
    ├── design.md           # Mermaid diagrams + architecture (SSoT for "how")
    ├── tasks.md            # Implementation tasks with dependencies
    └── research.md         # (Optional) Design decisions log
```

**Approval Gates:** Each phase requires human review before proceeding. Use `-y` flag only for intentional fast-forwarding.

### Phase 2: Implementation (Per Task)

```
/kiro:spec-impl <feature> <task-number>
```

- Implement **ONE task at a time**
- Follow TDD cycle: RED (write failing test) → GREEN (make it pass) → REFACTOR → VERIFY
- Mark tasks as `[x]` in `tasks.md` upon completion
- Clear context between tasks to prevent context bloat

## 3. Workflow Patterns

### Greenfield (New Feature)

```
steering → spec-init → spec-requirements → spec-design → spec-tasks → spec-impl
```

### Brownfield (Extending Existing Code)

```
steering → spec-init → validate-gap → spec-design → validate-design → spec-tasks → spec-impl
```

### Validation Commands (Optional but Recommended)

| Command | When to Use |
|---------|-------------|
| `/kiro:validate-gap <feature>` | After requirements, before design — analyze existing code gaps |
| `/kiro:validate-design <feature>` | After design — GO/NO-GO quality review |
| `/kiro:validate-impl <feature>` | After implementation — verify alignment with specs |
| `/kiro:spec-status <feature>` | Anytime — check progress |

## 4. Moodle-Specific Constraints

These constraints apply to ALL implementation work:

### Absolute Rules
- **NEVER modify Moodle core** (`/lib`, `/course`, `/mod`, `/admin`, etc.)
- **Plugin First**: All custom logic goes to `local/timetrack`. MVP payment uses standard `paygw_stripe` + `enrol_fee`
- **Theme changes** only in `theme/lambda_child/` (never modify parent theme `theme/lambda/`)

### Security Requirements
- Use `global $DB;` with Moodle DML API (never raw SQL)
- Use `required_param()` / `optional_param()` (never `$_GET` / `$_POST`)
- Always call `require_login()` at page entry
- Always call `require_sesskey()` for POST/form handling
- Use `has_capability()` for authorization (never hardcoded user ID checks)

### Coding Standards
- Plugin naming: `local_pluginname` (Frankenstyle, lowercase, underscores)
- Class naming: `local_pluginname\classname` (autoloading)
- Variables: `$snake_case` (no camelCase)
- No hardcoded strings: use `get_string('key', 'local_pluginname')`
- Language files: `lang/en/` (base) + `lang/ja/` (Japanese)
- Code comments in English, UI strings in Japanese

## 5. Before Writing Any Code

1. Read `requirements.md` for the feature
2. Read `design.md` for the feature
3. Read `tasks.md` and identify the specific task
4. If any section is missing or ambiguous: **update the spec first**
5. Never "fill gaps" with assumptions in code

## 6. Key Files Reference

| File | Role |
|------|------|
| `CLAUDE.md` | Project configuration and AI rules |
| `.kiro/steering/*.md` | Project memory (persistent context) |
| `.kiro/specs/<feature>/` | Feature specifications (SSoT) |
| `.kiro/settings/rules/*.md` | Generation rules and principles |
| `.kiro/settings/templates/` | Document templates |
| `docs/01_system_architecture.md` | System overview (steering input material) |
| `docs/development_guidelines.md` | Moodle coding standards reference |

---
_This document is the canonical workflow definition for the Japan LMS MVP project._
_Referenced from: CLAUDE.md Section 5_
