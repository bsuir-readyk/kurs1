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

--@ sqlrc:GetUserByUsername:one
SELECT * FROM users WHERE username = <@username:string@>;

--@ sqlrc:CreateTransaction:one
INSERT INTO transactions (
    description,
    currency,
    owner_id,
    amount,
    is_income
) VALUES (
    <@description:string@>,
    <@currency:string@>,
    <@owner_id:int@>,
    <@amount:int@>, -- TODO: float
    <@is_income:int@>
)
RETURNING *;

--@ sqlrc:CreateTag:one
INSERT INTO tags (
  text,
  user_id,
  transaction_id
) VALUES (
  <@text:string@>,
  <@user_id:int@>,
  <@transaction_id:int@>
)
RETURNING *;

--@ sqlrc:GetRecentTransactionsByUserId:many
SELECT * FROM transactions WHERE owner_id = <@owner_id:int@> LIMIT <@limit:int@>;

--@ sqlrc:GetTransactionsByAndTags:many
SELECT t1.*, tg.text
FROM transactions as t1
  LEFT JOIN tags as tg ON tg.transaction_id = t1.id
WHERE
  t1.owner_id = <@user_id:int@>
  AND
  (<@tags:string@> = 0 OR t1.id IN (
    SELECT tags.transaction_id
      FROM tags as tags
      WHERE
        tags.user_id = <@user_id2:int@>
        AND
        tags.text IN (<@tags:string@>) -- TODO: array
  ))
  AND
  (<@min_created_at:int@> = 0 OR t1.created_at > <@min_created_at:int@>)
  AND
  (<@max_created_at:int@> = 0 OR t1.created_at < <@max_created_at:int@>)
  AND
  (<@description_wk:string@> = "" OR t1.description LIKE <@description_wk:string@>)
GROUP BY t1.id
LIMIT <@limit:int@>
OFFSET <@offset:int@>;
