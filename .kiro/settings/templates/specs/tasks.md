# Implementation Plan

> SDD 前提：仕様駆動で、設計に基づいたタスク分解を行う。

---

## 0. Design Completeness Gate（Blocking）

> Implementation MUST NOT start until all items below are checked.

- [ ] 0.1 Designの「Architecture Pattern & Boundary Map」が記載されている
- [ ] 0.2 Designの「Components & Interface Contracts」が記載されている
  - コンポーネント一覧、インターフェース定義が存在する
  - 依存関係が明記されている
- [ ] 0.3 Designの「Data Models」が記載されている
  - エンティティ定義、関係性が記載されている
- [ ] 0.4 Requirements Traceability が更新されている
  - 主要Requirementが設計要素に紐づいている

---

## Task Format Template

Use whichever pattern fits the work breakdown.

### Major task only
- [ ] {{NUMBER}}. {{TASK_DESCRIPTION}}{{PARALLEL_MARK}}
  - {{DETAIL_ITEM_1}}
  - _Requirements: {{REQUIREMENT_IDS}}_

### Major + Sub-task structure
- [ ] {{MAJOR_NUMBER}}. {{MAJOR_TASK_SUMMARY}}
- [ ] {{MAJOR_NUMBER}}.{{SUB_NUMBER}} {{SUB_TASK_DESCRIPTION}}{{SUB_PARALLEL_MARK}}
  - {{DETAIL_ITEM_1}}
  - {{DETAIL_ITEM_2}}
  - _Requirements: {{REQUIREMENT_IDS}}_

> **Parallel marker**: Append ` (P)` only to tasks that can be executed in parallel. Omit in `--sequential` mode.
>
> **Optional test coverage**: Mark deferrable test work with `- [ ]*`.
