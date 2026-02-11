# Design Document Template

---

**Purpose**: Provide sufficient detail to ensure implementation consistency across different implementers, preventing interpretation drift.

## Overview
2-3 paragraphs max describing the feature's technical approach.

---

## Architecture

### Architecture Pattern & Boundary Map

Describe the architecture pattern used for this feature and how it fits within the overall system architecture defined in `.kiro/steering/tech.md` and `.kiro/steering/structure.md`.

- Identify key layers and their responsibilities
- Define boundaries between components
- Specify allowed dependency directions

---

## Technology Stack & Alignment

List only the technologies impacted by this feature. For each, specify:
- Tool/library + version + role
- Alignment with or deviation from steering tech stack

---

## Components & Interface Contracts

### Component Summary Table

| Component | Domain | Intent | Requirements | Dependencies |
|-----------|--------|--------|-------------|-------------|
| ... | ... | ... | ... | ... |

### Component Details

For each component that introduces new boundaries:

#### [Component Name]
**Purpose**: [One-line description]
**Requirements**: [Numeric IDs, e.g., 1.1, 2.3]

**Interface**:
```
[Method signatures, inputs/outputs, error handling]
```

**Dependencies**:
- [Dependency name] - [Inbound/Outbound/External] - [Criticality: P0/P1/P2]

**Implementation Notes**:
- Integration considerations
- Validation hooks
- Open questions / risks

---

## Data Models

### Domain Model
- Aggregates, entities, value objects
- Domain events and invariants
- Include Mermaid ER diagram for non-trivial relationships

### Logical Data Model
- Table/collection structure
- Indexing strategy
- Storage considerations

---

## System Flows

Add diagrams only when they clarify behavior:
- **Sequence** for multi-step interactions
- **Process/State** for branching rules or lifecycle
- **Data/Event** for pipelines or async patterns

Use pure Mermaid. Omit section if no complex flow exists.

---

## Error Handling Strategy

Document feature-specific error handling decisions and deviations from project standards.

---

## Security Considerations

Document authentication, authorization, and data protection considerations specific to this feature.

---

## Requirements Traceability

| Requirement | Summary | Components | Interfaces | Flows |
|------------|---------|------------|------------|-------|
| 1.1 | ... | ... | ... | ... |
| 1.2 | ... | ... | ... | ... |

---

## Responsibility Clarification

Describe the responsibility boundaries for this feature.
Unspecified responsibilities must NOT be implemented.
