# Steering Principles

Steering files are **project memory**, not exhaustive specifications.

---

## Content Granularity

### Golden Rule
> "If new code follows existing patterns, steering shouldn't need updating."

### Document
- Organizational patterns (feature-first, layered)
- Naming conventions
- Import strategies
- Architectural decisions
- Technology standards

### Avoid
- Complete file listings
- Every component description
- All dependencies
- Implementation details
- Agent-specific tooling directories

### Example Comparison

**Bad** (Specification-like):
```markdown
- /components/Button.tsx - Primary button with variants
- /components/Input.tsx - Text input with validation
... (50+ files)
```

**Good** (Project Memory):
```markdown
## UI Components (`/components/ui/`)
Reusable, design-system aligned primitives
- Named by function (Button, Input, Modal)
- Export component + TypeScript interface
- No business logic
```

---

## Security

Never include:
- API keys, passwords, credentials
- Database URLs, internal IPs
- Secrets or sensitive data

---

## Quality Standards

- **Single domain**: One topic per file
- **Concrete examples**: Show patterns with code
- **Explain rationale**: Why decisions were made
- **Maintainable size**: 100-200 lines typical

---

## Preservation (when updating)

- Preserve user sections and custom examples
- Additive by default (add, don't replace)
- Note why changes were made

---

## File-Specific Focus

- **product.md**: Purpose, value, business context
- **tech.md**: Key frameworks, standards, conventions
- **structure.md**: Organization patterns, naming rules
- **Custom files**: Specialized patterns
