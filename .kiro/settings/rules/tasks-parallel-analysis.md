# Parallel Task Analysis Rules

## Purpose
Provide a consistent way to identify implementation tasks that can be safely executed in parallel.

## When to Consider Tasks Parallel
Only mark a task as parallel-capable when **all** of the following are true:

1. **No data dependency** on pending tasks.
2. **No conflicting files or shared mutable resources** are touched.
3. **No prerequisite review/approval** from another task is required.
4. **Environment/setup work** is already satisfied or covered within the task itself.

## Marking Convention
- Append `(P)` immediately after the numeric identifier
  - Example: `- [ ] 2.1 (P) Build background worker for emails`
- Apply `(P)` to both major tasks and sub-tasks when appropriate
- If sequential mode requested, omit `(P)` markers entirely

## Grouping & Ordering Guidelines
- Group parallel tasks under the same parent when work belongs to the same theme
- List prerequisites or caveats in detail bullets
- When two tasks look similar but are not parallel-safe, call out the blocking dependency explicitly
- Skip marking container-only major tasks with `(P)` — evaluate at sub-task level

## Quality Checklist
Before marking a task with `(P)`, ensure:

- Running concurrently will not create merge or deployment conflicts
- Shared state expectations are captured in detail bullets
- Implementation can be tested independently

If any check fails, do not mark with `(P)` and explain the dependency.
