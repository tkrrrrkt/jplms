# Gap Analysis Process

## Objective
Analyze the gap between requirements and existing codebase to inform implementation strategy decisions.

## Analysis Framework

### 1. Current State Investigation

- Scan for domain-related assets:
  - Key files/modules and directory layout
  - Reusable components/services/utilities
  - Dominant architecture patterns and constraints

- Extract conventions:
  - Naming, layering, dependency direction
  - Import/export patterns
  - Testing placement and approach

- Note integration surfaces:
  - Data models/schemas, API clients, auth mechanisms

### 2. Requirements Feasibility Analysis

- List technical needs from EARS requirements
- Identify gaps and constraints
- Note complexity signals

### 3. Implementation Approach Options

#### Option A: Extend Existing Components
- Which files/modules to extend
- Compatibility assessment
- Complexity and maintainability

#### Option B: Create New Components
- Rationale for new creation
- Integration points
- Responsibility boundaries

#### Option C: Hybrid Approach
- Combination strategy
- Phased implementation
- Risk mitigation

### 4. Implementation Complexity & Risk

- Effort: S (1-3 days) / M (3-7 days) / L (1-2 weeks) / XL (2+ weeks)
- Risk: High / Medium / Low

### Output Checklist

- Requirement-to-Asset Map with gaps tagged
- Options A/B/C with rationale and trade-offs
- Effort and Risk with justification
- Recommendations for design phase

## Principles

- **Information over decisions**: Provide analysis and options, not final choices
- **Multiple viable options**: Offer alternatives when applicable
- **Explicit gaps**: Flag unknowns and constraints clearly
- **Context-aware**: Align with existing patterns
