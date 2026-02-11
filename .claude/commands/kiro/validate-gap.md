---
description: Analyze implementation gap between requirements and existing codebase
allowed-tools: Bash, Glob, Grep, Read, Write, Edit, MultiEdit, WebSearch, WebFetch
argument-hint: <feature-name>
---

# Implementation Gap Validation

<background_information>
- **Mission**: Analyze the gap between requirements and existing codebase to inform implementation strategy
- **Success Criteria**:
  - Comprehensive understanding of existing codebase patterns and components
  - Clear identification of missing capabilities and integration challenges
  - Multiple viable implementation approaches evaluated
  - Technical research needs identified for design phase
</background_information>

<instructions>
## Core Task
Analyze implementation gap for feature **$1** based on approved requirements and existing codebase.

## Execution Steps

1. **Load Context**:
   - Read `.kiro/specs/$1/spec.json` for language and metadata
   - Read `.kiro/specs/$1/requirements.md` for requirements
   - **Load ALL steering context**: Read entire `.kiro/steering/` directory

2. **Read Analysis Guidelines**:
   - Read `.kiro/settings/rules/gap-analysis.md` for comprehensive analysis framework

3. **Execute Gap Analysis**:
   - Follow gap-analysis.md framework for thorough investigation
   - Analyze existing codebase using Grep and Read tools
   - Use WebSearch/WebFetch for external dependency research if needed
   - Evaluate multiple implementation approaches (extend/new/hybrid)
   - Use language specified in spec.json for output

4. **Generate Analysis Document**:
   - Present multiple viable options with trade-offs
   - Flag areas requiring further research

## Important Constraints
- **Information over Decisions**: Provide analysis and options, not final choices
- **Multiple Options**: Present viable alternatives when applicable
- **Thorough Investigation**: Use tools to deeply understand existing codebase
</instructions>

## Tool Guidance
- **Read first**: Load all context before analysis
- **Grep extensively**: Search codebase for patterns and integration points
- **Write last**: Generate analysis only after complete investigation

## Output Description
Provide output in the language specified in spec.json:

1. **Analysis Summary**: Brief overview (3-5 bullets)
2. **Document Status**: Confirm analysis approach used
3. **Next Steps**: Guide to design phase

## Safety & Fallback

- **Missing Requirements**: Stop with: "Run `/kiro:spec-requirements $1` first"
- **Empty Steering**: Warn about missing project context

### Next Phase
- Run `/kiro:spec-design $1` to create technical design document
