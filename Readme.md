# SQLRC для Pascal

SQLRC - это инструмент командной строки, который использует SQL для создания структур и запросов на языке Go. Эта версия реализована на языке Pascal.

## Описание

SQLRC генерирует файлы Go на основе SQL-файлов (schema.sql с операторами CREATE TABLE и queries.sql с запросами к базе данных с параметрами в нотации "<@arg_name:arg_type@>"), которые инкапсулируют логику вызова базы данных через стандартную библиотеку db. Сгенерированные файлы предоставляют функции для вызова базы данных, структуры аргументов для этих функций, структуры результатов и некоторые общие структуры для работы с базой данных.

## Установка

1. Скомпилируйте проект с помощью Free Pascal Compiler:

```bash
fpc sqlrc.dpr
```

2. Добавьте исполняемый файл в PATH или используйте его напрямую.

## Использование

```bash
sqlrc --cfg <путь_к_конфигурационному_файлу>
```

### Конфигурационный файл

Конфигурационный файл должен быть в формате "key:value\n":

```
schema:schema.sql
queries:user.sql
remove_trailing_s:true
pakage.name:gen
pakage.path:./__gen/
```

Параметры:
- `schema` - путь к файлу схемы SQL
- `queries` - путь к файлу запросов SQL
- `remove_trailing_s` - флаг для удаления окончания "s" из имен таблиц
- `pakage.name` - имя пакета Go
- `pakage.path` - путь к директории, в которую будут сгенерированы файлы

### Файл схемы SQL

Файл схемы SQL должен содержать операторы CREATE TABLE:

```sql
CREATE TABLE users (
    primary_currency TEXT NOT NULL DEFAULT 'BYN',
    username TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,
    image TEXT NOT NULL,
    id INTEGER PRIMARY KEY NOT NULL,
    balance INTEGER NOT NULL DEFAULT 0
);
```

Поддерживаемые типы данных:
- TEXT
- INTEGER

### Файл запросов SQL

Файл запросов SQL должен содержать запросы с комментариями в формате:

```sql
--@ sqlrc:GetSingle:one
SELECT *
FROM users
WHERE username = <@username:string@>;
```

Формат комментария:
- `--@` - начало комментария
- `sqlrc` - префикс
- `GetSingle` - имя функции
- `one` - тип возвращаемого значения (one, many, exec)

Параметры запроса должны быть в формате `<@name:type@>`, где:
- `name` - имя параметра
- `type` - тип параметра (string, int)

## Примеры

### Пример конфигурационного файла

```
schema:schema.sql
queries:user.sql
remove_trailing_s:true
pakage.name:gen
pakage.path:./__gen/
```

### Пример файла схемы SQL

```sql
CREATE TABLE users (
    primary_currency TEXT NOT NULL DEFAULT 'BYN',
    username TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,
    image TEXT NOT NULL,
    id INTEGER PRIMARY KEY NOT NULL,
    balance INTEGER NOT NULL DEFAULT 0
);
```

### Пример файла запросов SQL

```sql
--@ sqlrc:GetSingle:one
SELECT *
FROM users
WHERE username = <@username:string@>;
```

### Пример использования

```bash
sqlrc --cfg example/config.txt
```

## Сгенерированные файлы

### schema.go

```go
package gen

import "database/sql"

type Queries struct {
    DB *sql.DB
}

type User struct {
    Primary_currency string `db:"primary_currency"`
    Username string `db:"username"`
    Password string `db:"password"`
    Image string `db:"image"`
    Id int `db:"id"`
    Balance int `db:"balance"`
}
```

### query.go

```go
package gen

import (
  "context"
)

// GetSingle
const GetSingleSql = `
SELECT *
FROM users
WHERE username = ?
`

type GetSingleParams struct {
  Username string
}

type GetSingleResult struct {
  Primary_currency string
  Username string
  Password string
  Image string
  Id int
  Balance int
}

func (q *Queries) GetSingle(ctx context.Context, arg GetSingleParams) (*GetSingleResult, error) {
  row := q.DB.QueryRowContext(ctx, GetSingleSql, arg.Username) 
  var i GetSingleResult
  err := row.Scan(
    &i.Primary_currency,
    &i.Username,
    &i.Password,
    &i.Image,
    &i.Id,
    &i.Balance,
  )
  return &i, err
}
```

## Ограничения

- Поддерживаются только типы данных TEXT и INTEGER
- Поддерживаются только типы запросов one, many и exec
- Поддерживаются только типы параметров string и int
