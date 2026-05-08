import Foundation

@main
struct SQLPreprocessorTests {
    static var testsPassed = 0
    static var testsFailed = 0

    static func assertEqual(_ actual: String, _ expected: String, _ message: String, line: Int = #line) {
        if actual == expected {
            testsPassed += 1
        } else {
            testsFailed += 1
            print("FAIL [\(line)] \(message)")
            print("  expected: \(expected)")
            print("  actual:   \(actual)")
        }
    }

    static func assertTrue(_ condition: Bool, _ message: String, line: Int = #line) {
        if condition {
            testsPassed += 1
        } else {
            testsFailed += 1
            print("FAIL [\(line)] \(message)")
        }
    }

    static func main() {
        let db = "testdb"

        // MARK: - FROM tests

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users", database: db),
            "SELECT * FROM `testdb`.users",
            "FROM: basic (no backtick)"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM `users`", database: db),
            "SELECT * FROM `testdb`.`users`",
            "FROM: backtick quoted"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM otherdb.users", database: db),
            "SELECT * FROM otherdb.users",
            "FROM: already qualified with dot - no change"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM `otherdb`.`users`", database: db),
            "SELECT * FROM `otherdb`.`users`",
            "FROM: already qualified with backticks - no change"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users WHERE id IN (SELECT id FROM orders)", database: db),
            "SELECT * FROM `testdb`.users WHERE id IN (SELECT id FROM `testdb`.orders)",
            "FROM: multiple FROM clauses"
        )

        // MARK: - JOIN tests

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id", database: db),
            "SELECT * FROM `testdb`.users u INNER JOIN `testdb`.orders o ON u.id = o.user_id",
            "JOIN: INNER JOIN"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users LEFT JOIN orders ON users.id = orders.user_id", database: db),
            "SELECT * FROM `testdb`.users LEFT JOIN `testdb`.orders ON users.id = orders.user_id",
            "JOIN: LEFT JOIN"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users RIGHT JOIN orders ON users.id = orders.user_id", database: db),
            "SELECT * FROM `testdb`.users RIGHT JOIN `testdb`.orders ON users.id = orders.user_id",
            "JOIN: RIGHT JOIN"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users CROSS JOIN roles", database: db),
            "SELECT * FROM `testdb`.users CROSS JOIN `testdb`.roles",
            "JOIN: CROSS JOIN"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users JOIN otherdb.orders ON users.id = orders.user_id", database: db),
            "SELECT * FROM `testdb`.users JOIN otherdb.orders ON users.id = orders.user_id",
            "JOIN: already qualified - no change"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users u JOIN orders o ON u.id = o.uid JOIN products p ON o.pid = p.id", database: db),
            "SELECT * FROM `testdb`.users u JOIN `testdb`.orders o ON u.id = o.uid JOIN `testdb`.products p ON o.pid = p.id",
            "JOIN: multiple JOINs"
        )

        // MARK: - UPDATE tests

        assertEqual(
            SQLPreprocessor.preprocessSQL("UPDATE users SET name = 'test' WHERE id = 1", database: db),
            "UPDATE `testdb`.users SET name = 'test' WHERE id = 1",
            "UPDATE: basic"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("UPDATE `users` SET name = 'test'", database: db),
            "UPDATE `testdb`.`users` SET name = 'test'",
            "UPDATE: backtick quoted"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("UPDATE otherdb.users SET name = 'test'", database: db),
            "UPDATE otherdb.users SET name = 'test'",
            "UPDATE: already qualified - no change"
        )

        // MARK: - INSERT INTO tests

        assertEqual(
            SQLPreprocessor.preprocessSQL("INSERT INTO users (name, age) VALUES ('test', 20)", database: db),
            "INSERT INTO `testdb`.users (name, age) VALUES ('test', 20)",
            "INSERT INTO: basic"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("INSERT INTO `users` (name) VALUES ('test')", database: db),
            "INSERT INTO `testdb`.`users` (name) VALUES ('test')",
            "INSERT INTO: backtick quoted"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("INSERT INTO otherdb.users (name) VALUES ('test')", database: db),
            "INSERT INTO otherdb.users (name) VALUES ('test')",
            "INSERT INTO: already qualified - no change"
        )

        // MARK: - DELETE FROM tests

        assertEqual(
            SQLPreprocessor.preprocessSQL("DELETE FROM users WHERE id = 1", database: db),
            "DELETE FROM `testdb`.users WHERE id = 1",
            "DELETE FROM: basic"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("DELETE FROM `users` WHERE id = 1", database: db),
            "DELETE FROM `testdb`.`users` WHERE id = 1",
            "DELETE FROM: backtick quoted"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("DELETE FROM otherdb.users WHERE id = 1", database: db),
            "DELETE FROM otherdb.users WHERE id = 1",
            "DELETE FROM: already qualified - no change"
        )

        // MARK: - SHOW CREATE TABLE tests

        assertEqual(
            SQLPreprocessor.preprocessSQL("SHOW CREATE TABLE users", database: db),
            "SHOW CREATE TABLE `testdb`.users",
            "SHOW CREATE TABLE: basic"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("SHOW CREATE TABLE `users`", database: db),
            "SHOW CREATE TABLE `testdb`.`users`",
            "SHOW CREATE TABLE: backtick quoted"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("SHOW CREATE TABLE otherdb.users", database: db),
            "SHOW CREATE TABLE otherdb.users",
            "SHOW CREATE TABLE: already qualified - no change"
        )

        // MARK: - DESC/DESCRIBE tests (only at statement start!)

        assertEqual(
            SQLPreprocessor.preprocessSQL("DESC users", database: db),
            "DESC `testdb`.users",
            "DESC: at start"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("DESCRIBE users", database: db),
            "DESCRIBE `testdb`.users",
            "DESCRIBE: at start"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("  DESC users", database: db),
            "DESC `testdb`.users",
            "DESC: leading spaces consumed by regex"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("DESC `users`", database: db),
            "DESC `testdb`.`users`",
            "DESC: backtick quoted"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("DESC otherdb.users", database: db),
            "DESC otherdb.users",
            "DESC: already qualified - no change"
        )

        // MARK: - SHOW COLUMNS FROM tests

        assertEqual(
            SQLPreprocessor.preprocessSQL("SHOW COLUMNS FROM users", database: db),
            "SHOW COLUMNS FROM `testdb`.users",
            "SHOW COLUMNS FROM: basic"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("SHOW COLUMNS FROM `users`", database: db),
            "SHOW COLUMNS FROM `testdb`.`users`",
            "SHOW COLUMNS FROM: backtick quoted"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("SHOW COLUMNS FROM otherdb.users", database: db),
            "SHOW COLUMNS FROM otherdb.users",
            "SHOW COLUMNS FROM: already qualified - no change"
        )

        // MARK: - ORDER BY DESC should NOT be modified (the original bug)

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users ORDER BY id DESC", database: db),
            "SELECT * FROM `testdb`.users ORDER BY id DESC",
            "ORDER BY DESC: should not modify DESC"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM `ad_source_pkg_worth` WHERE id > 0 ORDER BY num DESC LIMIT 10", database: db),
            "SELECT * FROM `testdb`.`ad_source_pkg_worth` WHERE id > 0 ORDER BY num DESC LIMIT 10",
            "ORDER BY DESC: original bug case"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users ORDER BY name DESC, id ASC", database: db),
            "SELECT * FROM `testdb`.users ORDER BY name DESC, id ASC",
            "ORDER BY with DESC and ASC"
        )

        // MARK: - Keywords that should NOT trigger table prefix

        // ALTER TABLE
        assertEqual(
            SQLPreprocessor.preprocessSQL("ALTER TABLE users ADD COLUMN age INT", database: db),
            "ALTER TABLE users ADD COLUMN age INT",
            "ALTER TABLE: should not modify"
        )

        // DROP TABLE
        assertEqual(
            SQLPreprocessor.preprocessSQL("DROP TABLE users", database: db),
            "DROP TABLE users",
            "DROP TABLE: should not modify"
        )

        // CREATE TABLE
        assertEqual(
            SQLPreprocessor.preprocessSQL("CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(100))", database: db),
            "CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(100))",
            "CREATE TABLE: should not modify"
        )

        // TRUNCATE TABLE
        assertEqual(
            SQLPreprocessor.preprocessSQL("TRUNCATE TABLE users", database: db),
            "TRUNCATE TABLE users",
            "TRUNCATE TABLE: should not modify"
        )

        // RENAME TABLE
        assertEqual(
            SQLPreprocessor.preprocessSQL("RENAME TABLE users TO users_backup", database: db),
            "RENAME TABLE users TO users_backup",
            "RENAME TABLE: should not modify"
        )

        // SET statement
        assertEqual(
            SQLPreprocessor.preprocessSQL("SET NAMES utf8mb4", database: db),
            "SET NAMES utf8mb4",
            "SET: should not modify"
        )

        // SHOW DATABASES
        assertEqual(
            SQLPreprocessor.preprocessSQL("SHOW DATABASES", database: db),
            "SHOW DATABASES",
            "SHOW DATABASES: should not modify"
        )

        // SHOW TABLES
        assertEqual(
            SQLPreprocessor.preprocessSQL("SHOW TABLES", database: db),
            "SHOW TABLES",
            "SHOW TABLES: should not modify"
        )

        // SHOW TABLE STATUS
        assertEqual(
            SQLPreprocessor.preprocessSQL("SHOW TABLE STATUS", database: db),
            "SHOW TABLE STATUS",
            "SHOW TABLE STATUS: should not modify"
        )

        // SHOW VARIABLES
        assertEqual(
            SQLPreprocessor.preprocessSQL("SHOW VARIABLES LIKE 'max_connections'", database: db),
            "SHOW VARIABLES LIKE 'max_connections'",
            "SHOW VARIABLES: should not modify"
        )

        // SHOW STATUS
        assertEqual(
            SQLPreprocessor.preprocessSQL("SHOW GLOBAL STATUS", database: db),
            "SHOW GLOBAL STATUS",
            "SHOW STATUS: should not modify"
        )

        // SHOW PROCESSLIST
        assertEqual(
            SQLPreprocessor.preprocessSQL("SHOW PROCESSLIST", database: db),
            "SHOW PROCESSLIST",
            "SHOW PROCESSLIST: should not modify"
        )

        // SHOW INDEX FROM - FROM refers to table, prefix is added
        assertEqual(
            SQLPreprocessor.preprocessSQL("SHOW INDEX FROM users", database: db),
            "SHOW INDEX FROM `testdb`.users",
            "SHOW INDEX FROM: FROM pattern adds db prefix (table reference)"
        )

        // EXPLAIN - only inner FROM should be modified
        assertEqual(
            SQLPreprocessor.preprocessSQL("EXPLAIN SELECT * FROM users", database: db),
            "EXPLAIN SELECT * FROM `testdb`.users",
            "EXPLAIN: should only modify the inner FROM"
        )

        // USE
        assertEqual(
            SQLPreprocessor.preprocessSQL("USE mydb", database: db),
            "USE mydb",
            "USE: should not modify"
        )

        // BEGIN
        assertEqual(
            SQLPreprocessor.preprocessSQL("BEGIN", database: db),
            "BEGIN",
            "BEGIN: should not modify"
        )

        // COMMIT
        assertEqual(
            SQLPreprocessor.preprocessSQL("COMMIT", database: db),
            "COMMIT",
            "COMMIT: should not modify"
        )

        // ROLLBACK
        assertEqual(
            SQLPreprocessor.preprocessSQL("ROLLBACK", database: db),
            "ROLLBACK",
            "ROLLBACK: should not modify"
        )

        // START TRANSACTION
        assertEqual(
            SQLPreprocessor.preprocessSQL("START TRANSACTION", database: db),
            "START TRANSACTION",
            "START TRANSACTION: should not modify"
        )

        // GRANT
        assertEqual(
            SQLPreprocessor.preprocessSQL("GRANT ALL ON *.* TO 'root'@'localhost'", database: db),
            "GRANT ALL ON *.* TO 'root'@'localhost'",
            "GRANT: should not modify"
        )

        // REVOKE - has FROM but it's not a table FROM (won't match because ' is not \w)
        assertEqual(
            SQLPreprocessor.preprocessSQL("REVOKE ALL ON *.* FROM 'root'@'localhost'", database: db),
            "REVOKE ALL ON *.* FROM 'root'@'localhost'",
            "REVOKE: FROM followed by quoted string - no modification"
        )

        // LOCK TABLES
        assertEqual(
            SQLPreprocessor.preprocessSQL("LOCK TABLES users READ", database: db),
            "LOCK TABLES users READ",
            "LOCK TABLES: should not modify"
        )

        // UNLOCK TABLES
        assertEqual(
            SQLPreprocessor.preprocessSQL("UNLOCK TABLES", database: db),
            "UNLOCK TABLES",
            "UNLOCK TABLES: should not modify"
        )

        // KILL
        assertEqual(
            SQLPreprocessor.preprocessSQL("KILL 12345", database: db),
            "KILL 12345",
            "KILL: should not modify"
        )

        // FLUSH
        assertEqual(
            SQLPreprocessor.preprocessSQL("FLUSH PRIVILEGES", database: db),
            "FLUSH PRIVILEGES",
            "FLUSH: should not modify"
        )

        // RESET
        assertEqual(
            SQLPreprocessor.preprocessSQL("RESET MASTER", database: db),
            "RESET MASTER",
            "RESET: should not modify"
        )

        // OPTIMIZE TABLE
        assertEqual(
            SQLPreprocessor.preprocessSQL("OPTIMIZE TABLE users", database: db),
            "OPTIMIZE TABLE users",
            "OPTIMIZE TABLE: should not modify"
        )

        // ANALYZE TABLE
        assertEqual(
            SQLPreprocessor.preprocessSQL("ANALYZE TABLE users", database: db),
            "ANALYZE TABLE users",
            "ANALYZE TABLE: should not modify"
        )

        // CHECK TABLE
        assertEqual(
            SQLPreprocessor.preprocessSQL("CHECK TABLE users", database: db),
            "CHECK TABLE users",
            "CHECK TABLE: should not modify"
        )

        // REPAIR TABLE
        assertEqual(
            SQLPreprocessor.preprocessSQL("REPAIR TABLE users", database: db),
            "REPAIR TABLE users",
            "REPAIR TABLE: should not modify"
        )

        // MARK: - CASE/WHEN should not confuse FROM

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT CASE WHEN active = 1 THEN 'yes' ELSE 'no' END AS status FROM users", database: db),
            "SELECT CASE WHEN active = 1 THEN 'yes' ELSE 'no' END AS status FROM `testdb`.users",
            "CASE WHEN: should not interfere with FROM"
        )

        // MARK: - HAVING

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT COUNT(*) FROM users GROUP BY age HAVING COUNT(*) > 5", database: db),
            "SELECT COUNT(*) FROM `testdb`.users GROUP BY age HAVING COUNT(*) > 5",
            "HAVING: should not interfere"
        )

        // MARK: - Subquery

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users WHERE id IN (SELECT user_id FROM orders)", database: db),
            "SELECT * FROM `testdb`.users WHERE id IN (SELECT user_id FROM `testdb`.orders)",
            "Subquery: nested FROM"
        )

        // MARK: - UNION

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT id FROM users UNION SELECT id FROM admins", database: db),
            "SELECT id FROM `testdb`.users UNION SELECT id FROM `testdb`.admins",
            "UNION: both FROMs"
        )

        // MARK: - LIMIT should not be mistaken as table

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users LIMIT 10", database: db),
            "SELECT * FROM `testdb`.users LIMIT 10",
            "LIMIT: should not be modified"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users LIMIT 10 OFFSET 5", database: db),
            "SELECT * FROM `testdb`.users LIMIT 10 OFFSET 5",
            "LIMIT OFFSET: should not be modified"
        )

        // MARK: - WHERE clause should not be affected

        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users WHERE name = 'from_data'", database: db),
            "SELECT * FROM `testdb`.users WHERE name = 'from_data'",
            "WHERE with 'from' in value: should not interfere"
        )

        // MARK: - escapeValueForSQL tests

        assertEqual(
            SQLPreprocessor.escapeValueForSQL(.string("hello")),
            "'hello'",
            "escapeValueForSQL: string"
        )

        assertEqual(
            SQLPreprocessor.escapeValueForSQL(.string("it's")),
            "'it\\'s'",
            "escapeValueForSQL: string with single quote"
        )

        assertEqual(
            SQLPreprocessor.escapeValueForSQL(.string("back\\slash")),
            "'back\\\\slash'",
            "escapeValueForSQL: string with backslash"
        )

        assertEqual(
            SQLPreprocessor.escapeValueForSQL(.int(42)),
            "'42'",
            "escapeValueForSQL: int"
        )

        assertEqual(
            SQLPreprocessor.escapeValueForSQL(.null),
            "NULL",
            "escapeValueForSQL: null"
        )

        assertEqual(
            SQLPreprocessor.escapeValueForSQL(.string("")),
            "''",
            "escapeValueForSQL: empty string"
        )

        // MARK: - escapeStringValue tests

        assertEqual(
            SQLPreprocessor.escapeStringValue("normal"),
            "'normal'",
            "escapeStringValue: normal"
        )

        assertEqual(
            SQLPreprocessor.escapeStringValue(""),
            "''",
            "escapeStringValue: empty"
        )

        assertEqual(
            SQLPreprocessor.escapeStringValue("a'b"),
            "'a\\'b'",
            "escapeStringValue: with quote"
        )

        assertEqual(
            SQLPreprocessor.escapeStringValue("a\\b"),
            "'a\\\\b'",
            "escapeStringValue: with backslash"
        )

        // MARK: - isShowCreateTable tests

        assertTrue(
            SQLPreprocessor.isShowCreateTable("SHOW CREATE TABLE users"),
            "isShowCreateTable: positive"
        )

        assertTrue(
            SQLPreprocessor.isShowCreateTable("show create table users"),
            "isShowCreateTable: lowercase"
        )

        assertTrue(
            SQLPreprocessor.isShowCreateTable("  SHOW CREATE TABLE `users`  "),
            "isShowCreateTable: with spaces"
        )

        assertTrue(
            !SQLPreprocessor.isShowCreateTable("SELECT * FROM users"),
            "isShowCreateTable: negative - SELECT"
        )

        assertTrue(
            !SQLPreprocessor.isShowCreateTable("SHOW DATABASES"),
            "isShowCreateTable: negative - SHOW DATABASES"
        )

        // MARK: - formatCreateTableSQL tests

        let rawCreate = "CREATE TABLE `users` (`id` int(11) NOT NULL AUTO_INCREMENT,`name` varchar(100) DEFAULT NULL, PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
        let formatted = SQLPreprocessor.formatCreateTableSQL(rawCreate)
        assertTrue(
            formatted.contains("CREATE TABLE"),
            "formatCreateTableSQL: contains CREATE TABLE"
        )
        assertTrue(
            !formatted.contains(",`"),
            "formatCreateTableSQL: commas followed by newline+indent"
        )

        // MARK: - extractSingleTableSelectTarget tests

        if let target = SQLPreprocessor.extractSingleTableSelectTarget("SELECT * FROM users", defaultDatabase: "mydb") {
            assertEqual(target.database, "mydb", "extractTarget: default db")
            assertEqual(target.table, "users", "extractTarget: table name")
        } else {
            testsFailed += 1
            print("FAIL extractSingleTableSelectTarget: basic SELECT")
        }

        if let target = SQLPreprocessor.extractSingleTableSelectTarget("SELECT * FROM `mydb`.`users`", defaultDatabase: nil) {
            assertEqual(target.database, "mydb", "extractTarget: explicit db")
            assertEqual(target.table, "users", "extractTarget: explicit db table")
        } else {
            testsFailed += 1
            print("FAIL extractSingleTableSelectTarget: explicit db SELECT")
        }

        // JOIN should return nil
        assertTrue(
            SQLPreprocessor.extractSingleTableSelectTarget("SELECT * FROM users JOIN orders ON users.id = orders.uid", defaultDatabase: "mydb") == nil,
            "extractTarget: JOIN returns nil"
        )

        // GROUP BY should return nil
        assertTrue(
            SQLPreprocessor.extractSingleTableSelectTarget("SELECT * FROM users GROUP BY age", defaultDatabase: "mydb") == nil,
            "extractTarget: GROUP BY returns nil"
        )

        // UNION should return nil
        assertTrue(
            SQLPreprocessor.extractSingleTableSelectTarget("SELECT * FROM users UNION SELECT * FROM admins", defaultDatabase: "mydb") == nil,
            "extractTarget: UNION returns nil"
        )

        // DISTINCT should return nil
        assertTrue(
            SQLPreprocessor.extractSingleTableSelectTarget("SELECT DISTINCT name FROM users", defaultDatabase: "mydb") == nil,
            "extractTarget: DISTINCT returns nil"
        )

        // Empty string should return nil
        assertTrue(
            SQLPreprocessor.extractSingleTableSelectTarget("", defaultDatabase: "mydb") == nil,
            "extractTarget: empty returns nil"
        )

        // Non-SELECT should return nil
        assertTrue(
            SQLPreprocessor.extractSingleTableSelectTarget("UPDATE users SET name = 'x'", defaultDatabase: "mydb") == nil,
            "extractTarget: non-SELECT returns nil"
        )

        // No default db and no explicit db should return nil
        assertTrue(
            SQLPreprocessor.extractSingleTableSelectTarget("SELECT * FROM users", defaultDatabase: nil) == nil,
            "extractTarget: no db returns nil"
        )

        // MARK: - Edge cases

        // Table name containing digits
        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM table123", database: db),
            "SELECT * FROM `testdb`.table123",
            "Edge: table name with digits"
        )

        // Table name with underscore
        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM user_orders", database: db),
            "SELECT * FROM `testdb`.user_orders",
            "Edge: table name with underscore"
        )

        // Database name with special characters (backtick)
        let specialDB = "test`db"
        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users", database: specialDB),
            "SELECT * FROM `test``db`.users",
            "Edge: database name with backtick"
        )

        // Case insensitivity (replacement hardcodes FROM in uppercase)
        assertEqual(
            SQLPreprocessor.preprocessSQL("select * from users", database: db),
            "select * FROM `testdb`.users",
            "Edge: lowercase keywords - FROM normalized to uppercase"
        )

        assertEqual(
            SQLPreprocessor.preprocessSQL("Select * From Users", database: db),
            "Select * FROM `testdb`.Users",
            "Edge: mixed case - FROM normalized to uppercase"
        )

        // Empty SQL
        assertEqual(
            SQLPreprocessor.preprocessSQL("", database: db),
            "",
            "Edge: empty SQL"
        )

        // SQL with semicolon
        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users;", database: db),
            "SELECT * FROM `testdb`.users;",
            "Edge: with semicolon"
        )

        // Multiple statements
        assertEqual(
            SQLPreprocessor.preprocessSQL("SELECT * FROM users; SELECT * FROM orders;", database: db),
            "SELECT * FROM `testdb`.users; SELECT * FROM `testdb`.orders;",
            "Edge: multiple statements"
        )

        // MARK: - Summary

        print("\n=== Test Results ===")
        print("Passed: \(testsPassed)")
        print("Failed: \(testsFailed)")
        print("Total:  \(testsPassed + testsFailed)")

        if testsFailed > 0 {
            print("\nSome tests FAILED!")
            exit(1)
        } else {
            print("\nAll tests PASSED!")
            exit(0)
        }
    }
}
