# Design Review Process

## Objective
Conduct interactive quality review of technical design documents to ensure readiness for implementation with acceptable risk.

## Review Philosophy
- **Quality assurance, not perfection seeking**
- **Critical focus**: Limit to 3 most important concerns
- **Interactive dialogue**: Engage with designer
- **Balanced assessment**: Recognize strengths and weaknesses
- **Clear decision**: Definitive GO/NO-GO with rationale

## Core Review Criteria

### 1. Existing Architecture Alignment (Critical)
- Integration with existing system boundaries and layers
- Consistency with established architectural patterns
- Proper dependency direction and coupling management

### 2. Design Consistency & Standards
- Adherence to project naming conventions and code standards
- Consistent error handling and logging strategies
- Alignment with established data modeling patterns

### 3. Extensibility & Maintainability
- Design flexibility for future requirements
- Clear separation of concerns
- Testability and debugging considerations

### 4. Type Safety & Interface Design
- Proper type definitions and interface contracts
- Avoidance of unsafe patterns
- Clear API boundaries and data structures

## Review Process

### Step 1: Analyze
Analyze design against all review criteria.

### Step 2: Identify Critical Issues (max 3)
For each issue:
```
**Critical Issue [1-3]**: [Brief title]
**Concern**: [Specific problem]
**Impact**: [Why it matters]
**Suggestion**: [Concrete improvement]
**Traceability**: [Requirement ID/section]
**Evidence**: [Design doc section/heading]
```

### Step 3: Recognize Strengths
Acknowledge 1-2 strong aspects.

### Step 4: Decide GO/NO-GO
- **GO**: No critical misalignment, requirements addressed, clear implementation path
- **NO-GO**: Fundamental conflicts, critical gaps, high failure risk

## Output Format

### Design Review Summary
2-3 sentences on overall quality and readiness.

### Critical Issues (max 3)
For each: Issue, Impact, Recommendation, Traceability, Evidence.

### Design Strengths
1-2 positive aspects.

### Final Assessment
Decision (GO/NO-GO), Rationale, Next Steps.

## Review Guidelines
1. Only flag issues that significantly impact success
2. Provide solutions, not just criticism
3. Engage in dialogue
4. Recognize both strengths and weaknesses
5. Make definitive GO/NO-GO recommendation
6. Ensure all suggestions are implementable
