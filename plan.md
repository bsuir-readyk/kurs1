# SQLRC migrating from js to pascal (fpc, mode delphi)

### Config

1) resolve config dir
2) parse config params

### Schema

3) get raw text content of schema.sql
4) parse schema.sql into data structures
5) generate schema.go content
6) write schema.go into file (fs)

### Queries

7) get raw text content of queries.sql
8) split queries.sql into queries
9) parse params from each query
10) parse sql result data structure
11) generate queries.go content
12) write queries.go into file (fs)


## Data structures

### Config
```ts
type TConfig = {
    schema: string,
    queries: string,                // may be array in future
    remove_trailing_s: boolean,     // for table names
    go_pakage: {
        name: string,
        path: string
    },
    format: boolean                 // flag to run `gofmt -w "$(pwd)/{gen_package_path}"`
}
```

### Schema

```ts
// supported sqlite types
type TColumnType =
    | "TEXT"
    | "INTEGER"

type TColumn = {
    name: string;
    type: TColumnType;
    nullable: boolean;
}

// <table_name, <column_name, TColumn>>
type TScehma = Record<string, Record<string, TColumn>>;
```

### Queries

```ts
type TQueryReturnType =
    | "one"
    | "many"
    | "exec"

type TQuery = {
    sql: string;
    name: string;
    type: QueryReturnType;
}

// supported types
type TSqlrcType =
    | "string"
    | "int"

type TQueryParams = Record<string, {
    name: string;
    type: SqlrcType;
    positions: number[];                // named params may be used several times
}>;

type TQueryWithParams = {
    query: TQuery;                      // link for initial query ds
    params: TQueryParams;
    resultSql: string;                  // params in notation <@name:type@> replaced with ?
}

type TReturningFields = Array<{
    rawName: string;                    // may be field of table | alias to field | *
    returningName: string;              // alias replaced with actual field, * is saved
}>

type TQueryWithReturn = {
    query: TQuery;
    result: Record<string, TReturningFields>;   // <tableName, field>
};

type TQueryCoplete = TQueryWithParams & TQueryWithReturn;
```

## Notes
- config probably would be text in `key:value`
- in `TScehma` column name is doubled (key is name + value.name is present). Its done for better DX
- usage of regexes are questionable, so probably need to replace w string_utils in some way
