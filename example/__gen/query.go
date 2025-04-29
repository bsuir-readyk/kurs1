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

// GetUserByUsername
const GetUserByUsernameSql = `
SELECT * FROM users WHERE username = ?;
`
type GetUserByUsernameParams struct {
  Username string
}
type GetUserByUsernameResult struct {
  Primary_currency string
  Username string
  Password string
  Image string
  Id int
  Balance int
}
func (q *Queries) GetUserByUsername(ctx context.Context, arg GetUserByUsernameParams) (*GetUserByUsernameResult, error) {
  row := q.DB.QueryRowContext(ctx, GetUserByUsernameSql, arg.Username)
  var i GetUserByUsernameResult
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

// CreateTransaction
const CreateTransactionSql = `
INSERT INTO transactions (
    description,
    currency,
    owner_id,
    amount,
    is_income
) VALUES (
    ?,
    ?,
    ?,
    ?, -- TODO: float
    ?
)
RETURNING *;
`
type CreateTransactionParams struct {
  Description string
  Currency string
  Owner_id int
  Amount int
  Is_income int
}
type CreateTransactionResult struct {
  Description string
  Currency string
  Id int
  Owner_id int
  Amount int
  Is_income int
  Created_at int
}
func (q *Queries) CreateTransaction(ctx context.Context, arg CreateTransactionParams) (*CreateTransactionResult, error) {
  row := q.DB.QueryRowContext(ctx, CreateTransactionSql, arg.Description, arg.Currency, arg.Owner_id, arg.Amount, arg.Is_income)
  var i CreateTransactionResult
  err := row.Scan(
    &i.Description,
      &i.Currency,
      &i.Id,
      &i.Owner_id,
      &i.Amount,
      &i.Is_income,
      &i.Created_at,
  )
  return &i, err
}

// CreateTag
const CreateTagSql = `
INSERT INTO tags (
  text,
  user_id,
  transaction_id
) VALUES (
  ?,
  ?,
  ?
)
RETURNING *;
`
type CreateTagParams struct {
  Text string
  User_id int
  Transaction_id int
}
type CreateTagResult struct {
  Text string
  Id int
  User_id int
  Transaction_id int
}
func (q *Queries) CreateTag(ctx context.Context, arg CreateTagParams) (*CreateTagResult, error) {
  row := q.DB.QueryRowContext(ctx, CreateTagSql, arg.Text, arg.User_id, arg.Transaction_id)
  var i CreateTagResult
  err := row.Scan(
    &i.Text,
      &i.Id,
      &i.User_id,
      &i.Transaction_id,
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

// GetTransactionsByAndTags
const GetTransactionsByAndTagsSql = `
SELECT t1.*, tg.text
FROM transactions as t1
  LEFT JOIN tags as tg ON tg.transaction_id = t1.id
WHERE
  t1.owner_id = ?
  AND
  (? = 0 OR t1.id IN (
    SELECT tags.transaction_id
      FROM tags as tags
      WHERE
        tags.user_id = ?
        AND
        tags.text IN (?) -- TODO: array
  ))
  AND
  (? = 0 OR t1.created_at > ?)
  AND
  (? = 0 OR t1.created_at < ?)
  AND
  (? = "" OR t1.description LIKE ?)
GROUP BY t1.id
LIMIT ?
OFFSET ?;
`
type GetTransactionsByAndTagsParams struct {
  User_id int
  Tags string
  User_id2 int
  Min_created_at int
  Max_created_at int
  Description_wk string
  Limit int
  Offset int
}
type GetTransactionsByAndTagsResult struct {
  Description string
  Currency string
  Id int
  Owner_id int
  Amount int
  Is_income int
  Created_at int
  Text 
}
func (q *Queries) GetTransactionsByAndTags(ctx context.Context, arg GetTransactionsByAndTagsParams) (*[]GetTransactionsByAndTagsResult, error) {
  rows, err := q.DB.QueryContext(ctx, GetTransactionsByAndTagsSql, arg.User_id, arg.Tags, arg.User_id2, arg.Tags, arg.Min_created_at, arg.Min_created_at, arg.Max_created_at, arg.Max_created_at, arg.Description_wk, arg.Description_wk, arg.Limit, arg.Offset)
  if err != nil {
    return nil, err
  }
  defer rows.Close()
  var items []GetTransactionsByAndTagsResult
  for rows.Next() {
    var i GetTransactionsByAndTagsResult
    if err := rows.Scan(
      &i.Description,
        &i.Currency,
        &i.Id,
        &i.Owner_id,
        &i.Amount,
        &i.Is_income,
        &i.Created_at,
        &i.Text,
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
