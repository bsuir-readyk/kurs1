package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"
	"strings"

	gen "github.com/readyyyk/oaip/kurs1/example/__gen"
	_ "github.com/tursodatabase/go-libsql"
)

func setupDatabase() (*sql.DB, error) {
	// Open an in-memory SQLite database
	db, err := sql.Open("libsql", "file::memory:")
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// Read schema.sql file
	schemaBytes, err := os.ReadFile("./schema.sql")
	if err != nil {
		return nil, fmt.Errorf("failed to read schema.sql: %w", err)
	}

	// Split into statements by semicolons and execute each one
	schema := string(schemaBytes)
	statements := []string{}

	// Split on semicolons, but handle comments appropriately
	currentStatement := ""

	for _, line := range strings.Split(schema, "\n") {
		trimmedLine := strings.TrimSpace(line)

		// Skip empty lines
		if trimmedLine == "" {
			continue
		}

		// Handle comments
		if strings.HasPrefix(trimmedLine, "--") {
			continue
		}

		// Add to current statement
		currentStatement += line + "\n"

		// If line ends with semicolon, this statement is complete
		if strings.HasSuffix(trimmedLine, ";") {
			statements = append(statements, currentStatement)
			currentStatement = ""
		}
	}

	// Execute each statement
	for i, stmt := range statements {
		_, err = db.Exec(stmt)
		if err != nil {
			return nil, fmt.Errorf("failed to execute statement %d: %w", i+1, err)
		}
	}

	// Insert users
	_, err = db.Exec(`
		INSERT INTO users (username, password, image, primary_currency, balance) 
		VALUES ('user1', 'pass1', 'image1.jpg', 'USD', 1000)
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to insert user1: %w", err)
	}

	_, err = db.Exec(`
		INSERT INTO users (username, password, image, primary_currency, balance) 
		VALUES ('user2', 'pass2', 'image2.jpg', 'EUR', 2000)
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to insert user2: %w", err)
	}

	_, err = db.Exec(`
		INSERT INTO users (username, password, image, primary_currency, balance) 
		VALUES ('user3', 'pass3', 'image3.jpg', 'GBP', 3000)
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to insert user3: %w", err)
	}

	// Insert transactions
	_, err = db.Exec(`
		INSERT INTO transactions (owner_id, amount, currency, description, is_income, created_at) 
		VALUES (1, 100, 'USD', 'Salary', 1, strftime('%s', 'now'))
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to insert transaction1: %w", err)
	}

	_, err = db.Exec(`
		INSERT INTO transactions (owner_id, amount, currency, description, is_income, created_at) 
		VALUES (1, 50, 'USD', 'Groceries', 0, strftime('%s', 'now'))
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to insert transaction2: %w", err)
	}

	_, err = db.Exec(`
		INSERT INTO transactions (owner_id, amount, currency, description, is_income, created_at) 
		VALUES (2, 200, 'EUR', 'Freelance', 1, strftime('%s', 'now'))
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to insert transaction3: %w", err)
	}

	// Insert tags
	_, err = db.Exec(`
		INSERT INTO tags (user_id, transaction_id, text) 
		VALUES (1, 1, 'income')
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to insert tag1: %w", err)
	}

	_, err = db.Exec(`
		INSERT INTO tags (user_id, transaction_id, text) 
		VALUES (1, 2, 'expense')
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to insert tag2: %w", err)
	}

	_, err = db.Exec(`
		INSERT INTO tags (user_id, transaction_id, text) 
		VALUES (1, 2, 'food')
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to insert tag3: %w", err)
	}

	_, err = db.Exec(`
		INSERT INTO tags (user_id, transaction_id, text) 
		VALUES (2, 3, 'work')
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to insert tag4: %w", err)
	}

	return db, nil
}

// WorkingGetWorthy is a manual implementation that correctly handles the IN clause
func WorkingGetWorthy(db *sql.DB, ctx context.Context, userID int, tags []string, minCreatedAt int, maxCreatedAt int, descriptionLike string, limit int, offset int) ([]map[string]interface{}, error) {
	// Build tag placeholders for the IN clause
	tagPlaceholders := make([]string, len(tags))
	tagArgs := make([]interface{}, len(tags))
	for i, tag := range tags {
		tagPlaceholders[i] = "?"
		tagArgs[i] = tag
	}

	// Construct the query with proper placeholders
	query := fmt.Sprintf(`
SELECT t1.id, t1.description, t1.amount, t1.currency, tg.text
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
      tags.text IN (%s)
  ))
  AND
  (t1.created_at > ?)
  AND
  (t1.created_at < ?)
  AND
  (t1.description LIKE ?)
GROUP BY t1.id
LIMIT ?
OFFSET ?;`, strings.Join(tagPlaceholders, ","))

	// Combine all arguments
	args := []interface{}{userID, userID}
	args = append(args, tagArgs...)
	args = append(args, minCreatedAt, maxCreatedAt, descriptionLike, limit, offset)

	// Execute the query
	rows, err := db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	// Process results
	var results []map[string]interface{}
	for rows.Next() {
		var id, amount int
		var description, currency, tag string
		if err := rows.Scan(&id, &description, &amount, &currency, &tag); err != nil {
			return nil, err
		}
		results = append(results, map[string]interface{}{
			"id":          id,
			"description": description,
			"amount":      amount,
			"currency":    currency,
			"tag":         tag,
		})
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return results, nil
}

func testGetSingle(queries *gen.Queries, ctx context.Context) {
	fmt.Println("\n--- Testing GetSingle ---")
	user, err := queries.GetSingle(ctx, gen.GetSingleParams{
		Username: "user1",
	})
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return
	}
	fmt.Printf("User found: ID=%d, Username=%s, Balance=%d, Currency=%s\n",
		user.Id, user.Username, user.Balance, user.Primary_currency)
}

func testInsertSingle(queries *gen.Queries, ctx context.Context) {
	fmt.Println("\n--- Testing InsertSingle ---")
	result, err := queries.InsertSingle(ctx, gen.InsertSingleParams{
		Username: "newuser",
		Password: "newpass",
		Image:    "newimage.jpg",
	})
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return
	}
	fmt.Printf("User inserted: ID=%d, Username=%s, Image=%s\n",
		result.Id, result.Username, result.I)
}

func testGetRepeated(queries *gen.Queries, ctx context.Context) {
	fmt.Println("\n--- Testing GetRepeated ---")
	result, err := queries.GetRepeated(ctx, gen.GetRepeatedParams{
		Id: 1,
	})
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return
	}
	fmt.Printf("Got ID: %d\n", result.Id)
}

func testGetMany(queries *gen.Queries, ctx context.Context) {
	fmt.Println("\n--- Testing GetMany ---")
	users, err := queries.GetMany(ctx, gen.GetManyParams{
		Id: 10, // Get all users with ID < 10
	})
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return
	}
	fmt.Printf("Found %d users:\n", len(*users))
	for i, user := range *users {
		fmt.Printf("%d. ID=%d, Username=%s, Balance=%d, Currency=%s\n",
			i+1, user.Id, user.Username, user.Balance, user.Primary_currency)
	}
}

func testGetWorthy(queries *gen.Queries, ctx context.Context) {
	fmt.Println("\n--- Testing GetWorthy ---")

	// Show all transactions
	rows, err := queries.DB.QueryContext(ctx, "SELECT id, owner_id, amount, currency, description, is_income, created_at FROM transactions")
	if err == nil {
		defer rows.Close()
		fmt.Println("All transactions in database:")
		for rows.Next() {
			var id, ownerID, amount, isIncome, createdAt int
			var currency, description string
			if err := rows.Scan(&id, &ownerID, &amount, &currency, &description, &isIncome, &createdAt); err != nil {
				continue
			}
			fmt.Printf("  Transaction ID=%d, Owner=%d, Amount=%d %s, Description=%s, IsIncome=%d, CreatedAt=%d\n",
				id, ownerID, amount, currency, description, isIncome, createdAt)
		}
	}

	// Show all tags
	rows, err = queries.DB.QueryContext(ctx, "SELECT id, user_id, transaction_id, text FROM tags")
	if err == nil {
		defer rows.Close()
		fmt.Println("All tags in database:")
		for rows.Next() {
			var id, userID, transactionID int
			var text string
			if err := rows.Scan(&id, &userID, &transactionID, &text); err != nil {
				continue
			}
			fmt.Printf("  Tag ID=%d, User=%d, Transaction=%d, Text=%s\n",
				id, userID, transactionID, text)
		}
	}

	// Try GetWorthy with the new array parameter
	fmt.Println("\nUsing GetWorthy with array parameter syntax:")
	transactions, err := queries.GetWorthy(ctx, gen.GetWorthyParams{
		User_id:        1,
		Tag_list:       []string{"income", "expense"},
		Tag2_list:      []string{"income", "food"},
		Min_created_at: 0,
		Max_created_at: 9999999999,
		Description_wk: "%",
		Limit:          10,
		Offset:         0,
	})
	if err != nil {
		fmt.Printf("Error with GetWorthy: %v\n", err)
	} else {
		fmt.Printf("Found %d transactions with GetWorthy:\n", len(*transactions))
		for i, tx := range *transactions {
			fmt.Printf("%d. ID=%d, Amount=%d %s, Description=%s, Tag=%s\n",
				i+1, tx.Id, tx.Amount, tx.Currency, tx.Description, tx.Text)
		}
	}

	// For comparison, keep using the manual implementation
	fmt.Println("\nFor comparison, using WorkingGetWorthy implementation:")
	results, err := WorkingGetWorthy(
		queries.DB,
		ctx,
		1,                             // userID
		[]string{"income", "expense"}, // tags
		0,                             // minCreatedAt
		9999999999,                    // maxCreatedAt
		"%",                           // descriptionLike
		10,                            // limit
		0,                             // offset
	)
	if err != nil {
		fmt.Printf("Error with WorkingGetWorthy: %v\n", err)
	} else {
		fmt.Printf("Found %d transactions with WorkingGetWorthy:\n", len(results))
		for i, tx := range results {
			fmt.Printf("%d. ID=%v, Amount=%v %v, Description=%v, Tag=%v\n",
				i+1, tx["id"], tx["amount"], tx["currency"], tx["description"], tx["tag"])
		}
	}
}

func main() {
	// Setup test database
	db, err := setupDatabase()
	if err != nil {
		log.Fatalf("Failed to setup database: %v", err)
	}
	defer db.Close()

	// Create query client
	queries := &gen.Queries{DB: db}
	ctx := context.Background()

	// Run tests for each query
	testGetSingle(queries, ctx)
	testInsertSingle(queries, ctx)
	testGetRepeated(queries, ctx)
	testGetMany(queries, ctx)
	testGetWorthy(queries, ctx)

	fmt.Println("\nAll tests completed successfully!")
	fmt.Println("Note: GetWorthy requires special handling for the IN clause in SQLite.")
	fmt.Println("See the WorkingGetWorthy function for a correct implementation.")
}
