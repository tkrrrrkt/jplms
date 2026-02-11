---
description: Create custom steering documents for specialized project contexts
allowed-tools: Bash, Read, Write, Edit, MultiEdit, Glob, Grep, LS
---

# Kiro Custom Steering Creation

<background_information>
**Role**: Create specialized steering documents beyond core files (product, tech, structure).

**Mission**: Help users create domain-specific project memory for specialized areas.

**Success Criteria**:
- Custom steering captures specialized patterns
- Follows same granularity principles as core steering
- Provides clear value for specific domain
</background_information>

<instructions>
## Workflow

1. **Ask user** for custom steering needs:
   - Domain/topic (e.g., "API standards", "testing approach")
   - Specific requirements or patterns to document

2. **Check if template exists**:
   - Load from `.kiro/settings/templates/steering-custom/{name}.md` if available
   - Use as starting point, customize based on project

3. **Analyze codebase** (JIT) for relevant patterns

4. **Generate custom steering**:
   - Follow template structure if available
   - Apply principles from `.kiro/settings/rules/steering-principles.md`
   - Focus on patterns, not exhaustive lists
   - Keep to 100-200 lines (2-3 minute read)

5. **Create file** in `.kiro/steering/{name}.md`

## Available Templates

Templates available in `.kiro/settings/templates/steering-custom/`:

1. **api-standards.md** - REST/GraphQL conventions, error handling
2. **testing.md** - Test organization, mocking, coverage
3. **security.md** - Auth patterns, input validation, secrets
4. **database.md** - Schema design, migrations, query patterns
5. **error-handling.md** - Error types, logging, retry strategies
6. **authentication.md** - Auth flows, permissions, session management

Load template when needed, customize for project.

## Steering Principles

- **Patterns over lists**: Document patterns, not every file/component
- **Single domain**: One topic per file
- **Concrete examples**: Show patterns with code
- **Maintainable size**: 100-200 lines typical
- **Security first**: Never include secrets or sensitive data

</instructions>

## Tool guidance

- **Read**: Load template, analyze existing code
- **Glob**: Find related files for pattern analysis
- **Grep**: Search for specific patterns

## Output description

Chat summary with file location (file created directly).

```
Custom Steering Created

## Created:
- .kiro/steering/{name}.md

## Based On:
- Template: {name}.md
- Analyzed: {relevant directories}

## Content:
- {key topics covered}

Review and customize as needed.
```

## Safety & Fallback

- **No template**: Generate from scratch based on domain knowledge
- **Security**: Never include secrets
- **Validation**: Ensure doesn't duplicate core steering content

## Notes

- Templates are starting points, customize for project
- All steering files loaded as project memory
- Custom files equally important as core files
- Avoid documenting agent-specific tooling directories
