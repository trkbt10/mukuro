/**
 * SQLite FFI Stubs for MoonBit
 * Provides native SQLite3 bindings
 */

#include <sqlite3.h>
#include <string.h>
#include <stdlib.h>

// ============================================================
// Database Connection
// ============================================================

/**
 * Open a database connection
 * @param path UTF-8 database path
 * @return database handle or NULL on error
 */
void* moonbit_sqlite_open(const char* path) {
    sqlite3* db = NULL;
    int rc = sqlite3_open(path, &db);
    if (rc != SQLITE_OK) {
        if (db) {
            sqlite3_close(db);
        }
        return NULL;
    }
    return (void*)db;
}

/**
 * Close a database connection
 * @param db database handle
 * @return SQLITE_OK on success
 */
int moonbit_sqlite_close(void* db) {
    if (!db) return SQLITE_ERROR;
    return sqlite3_close((sqlite3*)db);
}

/**
 * Execute SQL without result set
 * @param db database handle
 * @param sql SQL statement
 * @return SQLITE_OK on success
 */
int moonbit_sqlite_exec(void* db, const char* sql) {
    if (!db || !sql) return SQLITE_ERROR;
    char* errmsg = NULL;
    int rc = sqlite3_exec((sqlite3*)db, sql, NULL, NULL, &errmsg);
    if (errmsg) {
        sqlite3_free(errmsg);
    }
    return rc;
}

/**
 * Get last error message
 * @param db database handle
 * @return error message string
 */
const char* moonbit_sqlite_errmsg(void* db) {
    if (!db) return "null database handle";
    return sqlite3_errmsg((sqlite3*)db);
}

/**
 * Get number of rows changed by last INSERT/UPDATE/DELETE
 * @param db database handle
 * @return number of changed rows
 */
int moonbit_sqlite_changes(void* db) {
    if (!db) return 0;
    return sqlite3_changes((sqlite3*)db);
}

/**
 * Get the rowid of the last successful INSERT
 * @param db database handle
 * @return rowid
 */
long long moonbit_sqlite_last_insert_rowid(void* db) {
    if (!db) return 0;
    return sqlite3_last_insert_rowid((sqlite3*)db);
}

// ============================================================
// Prepared Statements
// ============================================================

/**
 * Prepare a SQL statement
 * @param db database handle
 * @param sql SQL statement
 * @return statement handle or NULL on error
 */
void* moonbit_sqlite_prepare(void* db, const char* sql) {
    if (!db || !sql) return NULL;
    sqlite3_stmt* stmt = NULL;
    int rc = sqlite3_prepare_v2((sqlite3*)db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) {
        return NULL;
    }
    return (void*)stmt;
}

/**
 * Finalize a prepared statement
 * @param stmt statement handle
 * @return SQLITE_OK on success
 */
int moonbit_sqlite_finalize(void* stmt) {
    if (!stmt) return SQLITE_ERROR;
    return sqlite3_finalize((sqlite3_stmt*)stmt);
}

/**
 * Reset a prepared statement
 * @param stmt statement handle
 * @return SQLITE_OK on success
 */
int moonbit_sqlite_reset(void* stmt) {
    if (!stmt) return SQLITE_ERROR;
    return sqlite3_reset((sqlite3_stmt*)stmt);
}

/**
 * Clear all bindings on a prepared statement
 * @param stmt statement handle
 * @return SQLITE_OK on success
 */
int moonbit_sqlite_clear_bindings(void* stmt) {
    if (!stmt) return SQLITE_ERROR;
    return sqlite3_clear_bindings((sqlite3_stmt*)stmt);
}

// ============================================================
// Binding Parameters
// ============================================================

/**
 * Bind NULL value
 * @param stmt statement handle
 * @param idx 1-based parameter index
 * @return SQLITE_OK on success
 */
int moonbit_sqlite_bind_null(void* stmt, int idx) {
    if (!stmt) return SQLITE_ERROR;
    return sqlite3_bind_null((sqlite3_stmt*)stmt, idx);
}

/**
 * Bind text value
 * @param stmt statement handle
 * @param idx 1-based parameter index
 * @param value text value
 * @return SQLITE_OK on success
 */
int moonbit_sqlite_bind_text(void* stmt, int idx, const char* value) {
    if (!stmt || !value) return SQLITE_ERROR;
    return sqlite3_bind_text((sqlite3_stmt*)stmt, idx, value, -1, SQLITE_TRANSIENT);
}

/**
 * Bind int64 value
 * @param stmt statement handle
 * @param idx 1-based parameter index
 * @param value int64 value
 * @return SQLITE_OK on success
 */
int moonbit_sqlite_bind_int64(void* stmt, int idx, long long value) {
    if (!stmt) return SQLITE_ERROR;
    return sqlite3_bind_int64((sqlite3_stmt*)stmt, idx, value);
}

/**
 * Bind double value
 * @param stmt statement handle
 * @param idx 1-based parameter index
 * @param value double value
 * @return SQLITE_OK on success
 */
int moonbit_sqlite_bind_double(void* stmt, int idx, double value) {
    if (!stmt) return SQLITE_ERROR;
    return sqlite3_bind_double((sqlite3_stmt*)stmt, idx, value);
}

/**
 * Bind blob value
 * @param stmt statement handle
 * @param idx 1-based parameter index
 * @param data blob data
 * @param len data length
 * @return SQLITE_OK on success
 */
int moonbit_sqlite_bind_blob(void* stmt, int idx, const void* data, int len) {
    if (!stmt) return SQLITE_ERROR;
    if (!data || len <= 0) {
        return sqlite3_bind_null((sqlite3_stmt*)stmt, idx);
    }
    return sqlite3_bind_blob((sqlite3_stmt*)stmt, idx, data, len, SQLITE_TRANSIENT);
}

// ============================================================
// Stepping Through Results
// ============================================================

/**
 * Evaluate a prepared statement
 * @param stmt statement handle
 * @return SQLITE_ROW, SQLITE_DONE, or error code
 */
int moonbit_sqlite_step(void* stmt) {
    if (!stmt) return SQLITE_ERROR;
    return sqlite3_step((sqlite3_stmt*)stmt);
}

// ============================================================
// Extracting Column Values
// ============================================================

/**
 * Get number of columns in result set
 * @param stmt statement handle
 * @return column count
 */
int moonbit_sqlite_column_count(void* stmt) {
    if (!stmt) return 0;
    return sqlite3_column_count((sqlite3_stmt*)stmt);
}

/**
 * Get column name
 * @param stmt statement handle
 * @param idx 0-based column index
 * @return column name
 */
const char* moonbit_sqlite_column_name(void* stmt, int idx) {
    if (!stmt) return "";
    const char* name = sqlite3_column_name((sqlite3_stmt*)stmt, idx);
    return name ? name : "";
}

/**
 * Get column type
 * @param stmt statement handle
 * @param idx 0-based column index
 * @return SQLITE_INTEGER, SQLITE_FLOAT, SQLITE_TEXT, SQLITE_BLOB, or SQLITE_NULL
 */
int moonbit_sqlite_column_type(void* stmt, int idx) {
    if (!stmt) return SQLITE_NULL;
    return sqlite3_column_type((sqlite3_stmt*)stmt, idx);
}

/**
 * Get column text value
 * @param stmt statement handle
 * @param idx 0-based column index
 * @return text value
 */
const char* moonbit_sqlite_column_text(void* stmt, int idx) {
    if (!stmt) return "";
    const unsigned char* text = sqlite3_column_text((sqlite3_stmt*)stmt, idx);
    return text ? (const char*)text : "";
}

/**
 * Get column int64 value
 * @param stmt statement handle
 * @param idx 0-based column index
 * @return int64 value
 */
long long moonbit_sqlite_column_int64(void* stmt, int idx) {
    if (!stmt) return 0;
    return sqlite3_column_int64((sqlite3_stmt*)stmt, idx);
}

/**
 * Get column double value
 * @param stmt statement handle
 * @param idx 0-based column index
 * @return double value
 */
double moonbit_sqlite_column_double(void* stmt, int idx) {
    if (!stmt) return 0.0;
    return sqlite3_column_double((sqlite3_stmt*)stmt, idx);
}

/**
 * Get blob size
 * @param stmt statement handle
 * @param idx 0-based column index
 * @return blob size in bytes
 */
int moonbit_sqlite_column_bytes(void* stmt, int idx) {
    if (!stmt) return 0;
    return sqlite3_column_bytes((sqlite3_stmt*)stmt, idx);
}

/**
 * Copy blob data to buffer
 * @param stmt statement handle
 * @param idx 0-based column index
 * @param dest destination buffer
 * @param max_len maximum bytes to copy
 * @return bytes copied
 */
int moonbit_sqlite_column_blob_copy(void* stmt, int idx, void* dest, int max_len) {
    if (!stmt || !dest || max_len <= 0) return 0;

    const void* blob = sqlite3_column_blob((sqlite3_stmt*)stmt, idx);
    if (!blob) return 0;

    int size = sqlite3_column_bytes((sqlite3_stmt*)stmt, idx);
    int copy_len = (size < max_len) ? size : max_len;

    memcpy(dest, blob, copy_len);
    return copy_len;
}
