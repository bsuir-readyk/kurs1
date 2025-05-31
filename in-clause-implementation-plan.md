# Implementation Plan: Proper IN Clause Handling in SQL Code Generator

## Problem Statement

The current code generation for SQL queries with `IN` clauses has a critical flaw when used with SQLite (and potentially other database engines). When a parameter is used within an `IN` clause, the generated code treats it as a single placeholder (`?`), but SQLite expects each item in the `IN` list to have its own placeholder.

For example, in the `GetWorthy` query:
```sql
-- Current problematic implementation
WHERE tags.text IN (?)  -- Single placeholder for multiple values
```

SQLite expects:
```sql
-- Correct implementation
WHERE tags.text IN (?, ?, ?)  -- One placeholder per value
```

This issue prevents queries with `IN` clauses from working correctly and makes them vulnerable to SQL injection attacks.

## Security Implications

### SQL Injection Vulnerability

The current workaround (string concatenation for IN clauses) is susceptible to SQL injection attacks. For example:

```go
// VULNERABLE approach
Cs_tags: "'income','expense'"  // What if a value contains malicious SQL?
```

A malicious user could input something like: `income'); DROP TABLE users; --`, resulting in:

```sql
WHERE tags.text IN ('income'); DROP TABLE users; --')
```

### Secure Approach

The secure approach dynamically generates the correct number of placeholders and provides each value separately as a prepared statement parameter:

```go
// SECURE approach
tagPlaceholders := make([]string, len(tags))
for i := range tags {
    tagPlaceholders[i] = "?"
}
query := fmt.Sprintf("... IN (%s) ...", strings.Join(tagPlaceholders, ","))
// Then pass each tag value as a separate parameter
```

## Implementation Plan

### 1. Parser Enhancement

- Modify the SQL parser to detect `IN` clause parameters with a special syntax
- Introduce a new parameter type for array/list values: `<@param_name:array:type@>`
  - Example: `<@tag_list:array:string@>` or `<@id_list:array:int@>`

### 2. Code Generation Changes

- When generating code for a query parameter that's used in an `IN` clause:
  1. Generate parameter struct with proper array/slice type
  2. Generate dynamic placeholder creation code
  3. Properly expand parameters during query execution

### 3. Runtime Parameter Handling

For each `IN` clause parameter:
- Create the appropriate number of placeholders based on array length
- Dynamically construct the final query with the correct number of placeholders
- Flatten the array values into the parameters slice passed to the database

### 4. Code Example for Implementation

```go
// Generated parameter struct
type QueryParams struct {
    UserID       int
    TagList      []string  // Array type for IN clause
    MinCreatedAt int
    // ... other params
}

// Inside the generated query function:
func (q *Queries) ExecuteQuery(ctx context.Context, arg QueryParams) (*Result, error) {
    // Handle IN clause for TagList
    tagPlaceholders := make([]string, len(arg.TagList))
    for i := range arg.TagList {
        tagPlaceholders[i] = "?"
    }
    
    // Build query with correct placeholders
    query := fmt.Sprintf(`
        SELECT * FROM table
        WHERE column IN (%s)
        AND other_column = ?
    `, strings.Join(tagPlaceholders, ","))
    
    // Build parameters slice
    params := make([]interface{}, 0, len(arg.TagList)+1)
    for _, tag := range arg.TagList {
        params = append(params, tag)
    }
    params = append(params, arg.OtherParam)
    
    // Execute query with dynamically built parameters
    row := q.DB.QueryRowContext(ctx, query, params...)
    // ...
}
```

### 5. Testing Strategy

1. Create test cases with various IN clause scenarios:
   - Empty lists
   - Single item lists
   - Multiple item lists
   - Lists with special characters
   - Large lists

2. Verify correct SQL generation for each database engine
   - SQLite
   - PostgreSQL
   - MySQL
   - Others as needed

3. Validate protection against SQL injection attempts

## Implementation Timeline

1. **Week 1**: Parser modifications to detect and handle array parameters
2. **Week 2**: Code generator changes to handle IN clause parameters
3. **Week 3**: Testing and security validation
4. **Week 4**: Documentation and integration

## Backward Compatibility

For backward compatibility, consider:
1. Providing a migration guide for existing queries
2. Supporting both old and new syntax during a transition period
3. Adding a configuration option to enable/disable the new IN clause handling

## Conclusion

Implementing proper IN clause handling is critical for both functionality and security. This plan provides a pathway to adding this feature to the code generator while ensuring security against SQL injection and maintaining compatibility with existing code. 
