--@ sqlrc:GetSingle:one
SELECT *
FROM users
WHERE username = <@username:string@>;

--@ sqlrc:InsertSingle:one
INSERT INTO users (username, password, image) 
VALUES (<@username:string@>, <@password:string@>, <@image:string@>)
RETURNING id, username, image i;

--@ sqlrc:GetRepeated:one
SELECT id FROM users WHERE id = <@id:int@> AND <@id:int@> < 10;

--@ sqlrc:GetMany:many
SELECT users.* FROM users WHERE id < <@id:int@>;

--@ sqlrc:GetWorthy:many
SELECT t1.*, tg.text
FROM transactions as t1
  LEFT JOIN tags tg ON tg.transaction_id = t1.id
WHERE
  t1.owner_id = <@user_id:int@>
  AND
  (t1.id IN (
    SELECT tags.transaction_id
    FROM tags tags
    WHERE
      tags.user_id = <@user_id:int@>
      AND
      tags.text IN (<@tag_list:array:string@>)
      AND
      tags.text IN (<@tag2_list:array:string@>)
  ))
  AND
  (t1.created_at > <@min_created_at:int@>)
  AND
  (t1.created_at < <@max_created_at:int@>)
  AND
  (t1.description LIKE <@description_wk:string@>)
GROUP BY t1.id
LIMIT <@limit:int@>
OFFSET <@offset:int@>;
