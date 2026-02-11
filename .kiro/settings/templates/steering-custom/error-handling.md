# Error Handling Standards

## Error Philosophy

[Fail fast, graceful degradation, user-friendly messages]

## Error Classification

### Application Errors
[Business logic errors, validation errors]

### Infrastructure Errors
[Database errors, network errors, timeout errors]

### User Errors
[Input validation, authentication, authorization]

## Error Response Format

### Standard Error Structure
```json
{
  "code": "ERROR_CODE",
  "message": "Human-readable message",
  "details": {}
}
```

### HTTP Status Code Usage
[When to use 400, 401, 403, 404, 409, 422, 500]

## Logging Strategy

### Log Levels
[When to use debug, info, warn, error]

### Required Context
[What information must be included in error logs]

## Error Recovery

### Retry Strategy
[When and how to retry failed operations]

### Fallback Behavior
[Graceful degradation patterns]

---
_Document error handling patterns, not every error case_
