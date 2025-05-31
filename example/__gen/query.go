package gen

import (
  "context"
)


// GetSingle
const GetSingleSql = `
SELECT *
FROM users
WHERE username = ?;
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

// InsertSingle
const InsertSingleSql = `
INSERT INTO users (username, password, image) 
VALUES (?, ?, ?)
RETURNING id, username, image i;
`
type InsertSingleParams struct {
  Username string
  Password string
  Image string
}
type InsertSingleResult struct {
  Id int
  Username string
  I string
}
func (q *Queries) InsertSingle(ctx context.Context, arg InsertSingleParams) (*InsertSingleResult, error) {
  row := q.DB.QueryRowContext(ctx, InsertSingleSql, arg.Username, arg.Password, arg.Image)
  var i InsertSingleResult
  err := row.Scan(
    &i.Id,
      &i.Username,
      &i.I,
  )
  return &i, err
}

// GetRepeated
const GetRepeatedSql = `
SELECT id FROM users WHERE id = ? AND ? < 10;
`
type GetRepeatedParams struct {
  Id int
}
type GetRepeatedResult struct {
  Id int
}
func (q *Queries) GetRepeated(ctx context.Context, arg GetRepeatedParams) (*GetRepeatedResult, error) {
  row := q.DB.QueryRowContext(ctx, GetRepeatedSql, arg.Id, arg.Id)
  var i GetRepeatedResult
  err := row.Scan(
    &i.Id,
  )
  return &i, err
}

// GetMany
const GetManySql = `
SELECT users.* FROM users WHERE id < ?;
`
type GetManyParams struct {
  Id int
}
type GetManyResult struct {
  Primary_currency string
  Username string
  Password string
  Image string
  Id int
  Balance int
}
func (q *Queries) GetMany(ctx context.Context, arg GetManyParams) (*[]GetManyResult, error) {
  rows, err := q.DB.QueryContext(ctx, GetManySql, arg.Id)
  if err != nil {
    return nil, err
  }
  defer rows.Close()
  var items []GetManyResult
  for rows.Next() {
    var i GetManyResult
    if err := rows.Scan(
      &i.Primary_currency,
        &i.Username,
        &i.Password,
        &i.Image,
        &i.Id,
        &i.Balance,
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

// GetWorthy
const GetWorthySql = `
SELECT t1.*, tg.text
FROM transactions as t1
  LEFT JOIN tags tg ON tg.transaction_id = t1.id
WHERE
  t1.owner_id = ?
  AND
  (t1.id IN (
    SELECT tags.transaction_id
    FROM tags tags
    WHERE
      tags.user_id = ?
      AND
      tags.text IN (?)
  ))
  AND
  (t1.created_at > ?)
  AND
  (t1.created_at < ?)
  AND
  (t1.description LIKE ?)
GROUP BY t1.id
LIMIT ?
OFFSET ?;
`
type GetWorthyParams struct {
  User_id int
  Cs_tags string
  Min_created_at int
  Max_created_at int
  Description_wk string
  Limit int
  Offset int
}
type GetWorthyResult struct {
  Description string
  Currency string
  Id int
  Owner_id int
  Amount int
  Is_income int
  Created_at int
  Text string
}
func (q *Queries) GetWorthy(ctx context.Context, arg GetWorthyParams) (*[]GetWorthyResult, error) {
  rows, err := q.DB.QueryContext(ctx, GetWorthySql, arg.User_id, arg.User_id, arg.Cs_tags, arg.Min_created_at, arg.Max_created_at, arg.Description_wk, arg.Limit, arg.Offset)
  if err != nil {
    return nil, err
  }
  defer rows.Close()
  var items []GetWorthyResult
  for rows.Next() {
    var i GetWorthyResult
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
