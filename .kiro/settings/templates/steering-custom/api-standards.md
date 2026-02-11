# API Standards

## API Design Philosophy

[REST / GraphQL / tRPC approach and rationale]

## Endpoint Conventions

### URL Pattern
[e.g., /api/v1/{resource}/{id}]

### HTTP Methods
- GET: Read operations
- POST: Create operations
- PUT/PATCH: Update operations
- DELETE: Remove operations

### Naming Rules
[Pluralization, casing, nesting rules]

## Request/Response Format

### Standard Response Envelope
```json
{
  "data": {},
  "meta": {},
  "errors": []
}
```

### Pagination
[Cursor-based / offset-based approach]

### Error Format
[Standard error response structure]

## Versioning Strategy

[How API versions are managed]

---
_Document patterns and conventions, not every endpoint_
