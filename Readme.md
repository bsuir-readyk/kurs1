# SQLRC для Pascal

## Описание
SQLRC - это инструмент командной строки, реализованный на Pascal, который генерирует код Go (структуры и функции для работы с базой данных) на основе SQL-файлов схемы и запросов.

## Установка
1. Скомпилируйте проект с помощью Make:
   ```bash
   make build
   # или просто
   make
   ```
2. Исполняемый файл `bin_sqlrc` будет создан в корневой директории проекта. Добавьте его в PATH или используйте напрямую.

## Использование
```bash
./bin_sqlrc --cfg <путь_к_конфигурационному_файлу>
```
Пример запуска с использованием конфигурации из директории `example`:
```bash
make run
# или
./bin_sqlrc --cfg example/config.txt
```

## Конфигурационный файл
Формат: `key:value` (каждая пара на новой строке).
Пример (`example/config.txt`):
```
schema:schema.sql
queries:query.sql
remove_trailing_s:true
package.name:gen
package.path:./__gen/
```
Параметры:
- `schema`: путь к файлу схемы SQL.
- `queries`: путь к файлу запросов SQL.
- `remove_trailing_s`: (true/false) удалять 's' в конце имен таблиц при генерации имен структур Go.
- `package.name`: имя пакета Go для генерируемых файлов.
- `package.path`: путь к директории для генерируемых файлов (относительно директории конфигурационного файла).

## Файл схемы SQL (`example/schema.sql`)
Содержит операторы `CREATE TABLE`.
```sql
-- Пример содержимого example/schema.sql
CREATE TABLE users (
    primary_currency TEXT NOT NULL DEFAULT 'BYN',
    username TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,
    image TEXT NOT NULL,
    id INTEGER PRIMARY KEY NOT NULL,
    balance INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE transactions (
    description TEXT NOT NULL,
    currency TEXT NOT NULL,
    id INTEGER PRIMARY KEY NOT NULL,
    owner_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,
    is_income INTEGER NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
);

CREATE TABLE tags (
    text TEXT NOT NULL,
    id INTEGER PRIMARY KEY NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE
);
```
Поддерживаемые типы данных: `TEXT`, `INTEGER`.

## Файл запросов SQL (`example/query.sql`)
Содержит именованные SQL-запросы с аннотациями.
```sql
-- Пример содержимого example/query.sql

--@ sqlrc:CreateUser:one
INSERT INTO users (
    username,
    image,
    password
) VALUES (
    <@username:string@>,
    <@image:string@>,
    <@password:string@>
)
RETURNING *;

--@ sqlrc:GetUserById:one
SELECT * FROM users WHERE id = <@id:int@>;

--@ sqlrc:GetRecentTransactionsByUserId:many
SELECT * FROM transactions WHERE owner_id = <@owner_id:int@> LIMIT <@limit:int@>;

-- ... другие запросы
```
Формат аннотации: `--@ sqlrc:FunctionName:ReturnType`
- `FunctionName`: Имя генерируемой функции в Go.
- `ReturnType`: Тип возвращаемого значения (`one`, `many`, `exec`).

Формат параметра: `<@name:type@>`
- `name`: Имя параметра.
- `type`: Тип параметра (`string`, `int`).

## Сгенерированные файлы Go (в `example/__gen/`)

### `schema.go`
Содержит определение структуры `Queries` и Go-структуры для каждой таблицы из файла схемы.
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

type Transaction struct {
    Description string `db:"description"`
    Currency string `db:"currency"`
    Id int `db:"id"`
    Owner_id int `db:"owner_id"`
    Amount int `db:"amount"`
    Is_income int `db:"is_income"`
    Created_at int `db:"created_at"`
}

type Tag struct {
    Text string `db:"text"`
    Id int `db:"id"`
    User_id int `db:"user_id"`
    Transaction_id int `db:"transaction_id"`
}
```

### `query.go`
Содержит константы SQL, структуры параметров и результатов, а также функции Go для каждого запроса из файла запросов.
```go
package gen

import (
  "context"
)

// CreateUser
const CreateUserSql = `
INSERT INTO users (
    username,
    image,
    password
) VALUES (
    ?,
    ?,
    ?
)
RETURNING *;
`
type CreateUserParams struct {
  Username string
  Image string
  Password string
}
type CreateUserResult struct {
  Primary_currency string
  Username string
  Password string
  Image string
  Id int
  Balance int
}
func (q *Queries) CreateUser(ctx context.Context, arg CreateUserParams) (*CreateUserResult, error) {
  row := q.DB.QueryRowContext(ctx, CreateUserSql, arg.Username, arg.Image, arg.Password)
  var i CreateUserResult
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

// GetUserById
const GetUserByIdSql = `
SELECT * FROM users WHERE id = ?;
`
type GetUserByIdParams struct {
  Id int
}
type GetUserByIdResult struct {
  Primary_currency string
  Username string
  Password string
  Image string
  Id int
  Balance int
}
func (q *Queries) GetUserById(ctx context.Context, arg GetUserByIdParams) (*GetUserByIdResult, error) {
  row := q.DB.QueryRowContext(ctx, GetUserByIdSql, arg.Id)
  var i GetUserByIdResult
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

// GetRecentTransactionsByUserId
const GetRecentTransactionsByUserIdSql = `
SELECT * FROM transactions WHERE owner_id = ? LIMIT ?;
`
type GetRecentTransactionsByUserIdParams struct {
  Owner_id int
  Limit int
}
type GetRecentTransactionsByUserIdResult struct {
  Description string
  Currency string
  Id int
  Owner_id int
  Amount int
  Is_income int
  Created_at int
}
func (q *Queries) GetRecentTransactionsByUserId(ctx context.Context, arg GetRecentTransactionsByUserIdParams) (*[]GetRecentTransactionsByUserIdResult, error) {
  rows, err := q.DB.QueryContext(ctx, GetRecentTransactionsByUserIdSql, arg.Owner_id, arg.Limit)
  if err != nil {
    return nil, err
  }
  defer rows.Close()
  var items []GetRecentTransactionsByUserIdResult
  for rows.Next() {
    var i GetRecentTransactionsByUserIdResult
    if err := rows.Scan(
      &i.Description,
        &i.Currency,
        &i.Id,
        &i.Owner_id,
        &i.Amount,
        &i.Is_income,
        &i.Created_at,
    ); err != nil {
      return nil, err
    }
    items = append(items, i)
  }
  if err := rows.Close(); err != nil {
    return nil, err
  }
  if err := rows.Err(); err != nil {
    return nil, err
  }
  return &items, nil
}

// ... другие функции
```

## Ограничения
- Поддерживаемые типы данных в схеме: `TEXT`, `INTEGER`.
- Поддерживаемые типы возвращаемых значений в запросах: `one`, `many`, `exec`.
- Поддерживаемые типы параметров в запросах: `string`, `int`.
- Нет поддержки сложных типов параметров (например, массивов для `IN (...)`).
