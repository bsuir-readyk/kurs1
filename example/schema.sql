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
    -- * 1000 for ms-based
);

CREATE TABLE tags (
    text TEXT NOT NULL,
    id INTEGER PRIMARY KEY NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE
);
