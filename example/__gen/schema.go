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

