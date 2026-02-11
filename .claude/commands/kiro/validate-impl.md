---
description: Validate implementation against requirements, design, and tasks
allowed-tools: Bash, Glob, Grep, Read, LS
argument-hint: [feature-name] [task-numbers]
---

# Implementation Validation

<background_information>
- **Mission**: Verify that implementation aligns with approved requirements, design, and tasks
- **Success Criteria**:
  - All specified tasks marked as completed
  - Tests exist and pass for implemented functionality
  - Requirements traceability confirmed
  - Design structure reflected in implementation
  - No regressions in existing functionality
</background_information>

<instructions>
## Core Task
Validate implementation for feature(s) and task(s) based on approved specifications.

## Execution Steps

### 1. Detect Validation Target

**If no arguments provided**:
- Parse conversation history for `/kiro:spec-impl` commands
- If no history found, scan `.kiro/specs/` for features with completed tasks `[x]`

**If feature provided**:
- Detect all completed tasks `[x]` in `.kiro/specs/$1/tasks.md`

**If both feature and tasks provided**:
- Validate specified feature and tasks only

### 2. Load Context

For each detected feature:
- Read spec.json, requirements.md, design.md, tasks.md
- **Load ALL steering context**

### 3. Execute Validation

For each task, verify:

#### Task Completion Check
- Checkbox is `[x]` in tasks.md

#### Test Coverage Check
- Tests exist for task-related functionality
- Tests pass (no failures or errors)

#### Requirements Traceability
- EARS requirements related to the task are traceable to code

#### Design Alignment
- design.md structure is reflected in implementation

#### Regression Check
- Run full test suite (if available)
- Verify no existing tests are broken

### 4. Generate Report

Provide summary in the language specified in spec.json:
- Validation summary by feature
- Coverage report
- Issues and deviations with severity
- GO/NO-GO decision

## Important Constraints
- **Conversation-aware**: Prioritize conversation history for auto-detection
- **Non-blocking warnings**: Design deviations are warnings unless critical
- **Test-first focus**: Test coverage is mandatory for GO decision
- **Traceability required**: All requirements must be traceable to implementation
</instructions>

## Tool Guidance
- **Read context**: Load all specs and steering before validation
- **Bash for tests**: Execute test commands to verify pass status
- **Grep for traceability**: Search codebase for requirement evidence

## Output Description
Provide output in the language specified in spec.json:

1. **Detected Target**: Features and tasks being validated
2. **Validation Summary**: Pass/fail counts per feature
3. **Issues**: Validation failures with severity and location
4. **Coverage Report**: Requirements/design/task coverage percentages
5. **Decision**: GO / NO-GO

## Safety & Fallback

- **No Implementation Found**: Report "No implementations detected"
- **Test Command Unknown**: Warn and skip test validation
- **Missing Spec Files**: Stop with error

think
