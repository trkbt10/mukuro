///|
/// SQLite FFI Bindings
/// Native bindings for SQLite3 database operations

// ============================================================
// SQLite Handle Types
// ============================================================

///|
/// SQLite database connection handle
#external
pub type SqliteDb

///|
/// SQLite prepared statement handle
#external
pub type SqliteStmt

// ============================================================
// Result Codes
// ============================================================

///|
/// SQLITE_OK (Successful result)
pub let sqlite_ok : Int = 0

///|
/// SQLITE_ERROR (SQL error or missing database)
pub let sqlite_error : Int = 1

///|
/// SQLITE_BUSY (Database is busy)
pub let sqlite_busy : Int = 5

///|
/// SQLITE_LOCKED (Table is locked)
pub let sqlite_locked : Int = 6

///|
/// SQLITE_NOMEM (Malloc failed)
pub let sqlite_nomem : Int = 7

///|
/// SQLITE_READONLY (Database is read-only)
pub let sqlite_readonly : Int = 8

///|
/// SQLITE_DONE (sqlite3_step() finished executing)
pub let sqlite_done : Int = 101

///|
/// SQLITE_ROW (sqlite3_step() has another row ready)
pub let sqlite_row : Int = 100

///|
/// SQLITE_NULL (Column type is NULL)
pub let sqlite_null : Int = 5

// ============================================================
// Database Connection
// ============================================================

///|
/// Open a database connection
/// Returns: 0 on success, error code on failure
#borrow(path)
pub extern "C" fn c_sqlite_open(path : CString) -> SqliteDb? = "moonbit_sqlite_open"

///|
/// Close a database connection
/// Returns: SQLITE_OK on success
pub extern "C" fn c_sqlite_close(db : SqliteDb) -> Int = "moonbit_sqlite_close"

///|
/// Execute SQL without result set (for CREATE, INSERT, UPDATE, DELETE)
/// Returns: SQLITE_OK on success, error code on failure
#borrow(sql)
pub extern "C" fn c_sqlite_exec(db : SqliteDb, sql : CString) -> Int = "moonbit_sqlite_exec"

///|
/// Get last error message
pub extern "C" fn c_sqlite_errmsg(db : SqliteDb) -> CString = "moonbit_sqlite_errmsg"

///|
/// Get number of rows changed by last INSERT/UPDATE/DELETE
pub extern "C" fn c_sqlite_changes(db : SqliteDb) -> Int = "moonbit_sqlite_changes"

///|
/// Get the rowid of the last successful INSERT
pub extern "C" fn c_sqlite_last_insert_rowid(db : SqliteDb) -> Int64 = "moonbit_sqlite_last_insert_rowid"

// ============================================================
// Prepared Statements
// ============================================================

///|
/// Prepare a SQL statement
/// Returns: NULL on error
#borrow(sql)
pub extern "C" fn c_sqlite_prepare(db : SqliteDb, sql : CString) -> SqliteStmt? = "moonbit_sqlite_prepare"

///|
/// Finalize (destroy) a prepared statement
/// Returns: SQLITE_OK on success
pub extern "C" fn c_sqlite_finalize(stmt : SqliteStmt) -> Int = "moonbit_sqlite_finalize"

///|
/// Reset a prepared statement (to re-execute with new bindings)
/// Returns: SQLITE_OK on success
pub extern "C" fn c_sqlite_reset(stmt : SqliteStmt) -> Int = "moonbit_sqlite_reset"

///|
/// Clear all bindings on a prepared statement
/// Returns: SQLITE_OK on success
pub extern "C" fn c_sqlite_clear_bindings(stmt : SqliteStmt) -> Int = "moonbit_sqlite_clear_bindings"

// ============================================================
// Binding Parameters
// ============================================================

///|
/// Bind a NULL value to a parameter
/// idx: 1-based index
/// Returns: SQLITE_OK on success
pub extern "C" fn c_sqlite_bind_null(stmt : SqliteStmt, idx : Int) -> Int = "moonbit_sqlite_bind_null"

///|
/// Bind a text value to a parameter
/// idx: 1-based index
/// Returns: SQLITE_OK on success
#borrow(value)
pub extern "C" fn c_sqlite_bind_text(
  stmt : SqliteStmt,
  idx : Int,
  value : CString,
) -> Int = "moonbit_sqlite_bind_text"

///|
/// Bind an int64 value to a parameter
/// idx: 1-based index
/// Returns: SQLITE_OK on success
pub extern "C" fn c_sqlite_bind_int64(
  stmt : SqliteStmt,
  idx : Int,
  value : Int64,
) -> Int = "moonbit_sqlite_bind_int64"

///|
/// Bind a double value to a parameter
/// idx: 1-based index
/// Returns: SQLITE_OK on success
pub extern "C" fn c_sqlite_bind_double(
  stmt : SqliteStmt,
  idx : Int,
  value : Double,
) -> Int = "moonbit_sqlite_bind_double"

///|
/// Bind a blob value to a parameter
/// idx: 1-based index
/// Returns: SQLITE_OK on success
#borrow(data)
pub extern "C" fn c_sqlite_bind_blob(
  stmt : SqliteStmt,
  idx : Int,
  data : Bytes,
  len : Int,
) -> Int = "moonbit_sqlite_bind_blob"

// ============================================================
// Stepping Through Results
// ============================================================

///|
/// Evaluate a prepared statement
/// Returns: SQLITE_ROW if there's another row, SQLITE_DONE if finished
pub extern "C" fn c_sqlite_step(stmt : SqliteStmt) -> Int = "moonbit_sqlite_step"

// ============================================================
// Extracting Column Values
// ============================================================

///|
/// Get the number of columns in the result set
pub extern "C" fn c_sqlite_column_count(stmt : SqliteStmt) -> Int = "moonbit_sqlite_column_count"

///|
/// Get the name of a column (0-based index)
pub extern "C" fn c_sqlite_column_name(stmt : SqliteStmt, idx : Int) -> CString = "moonbit_sqlite_column_name"

///|
/// Get the type of a column (0-based index)
/// Returns: SQLITE_INTEGER=1, SQLITE_FLOAT=2, SQLITE_TEXT=3, SQLITE_BLOB=4, SQLITE_NULL=5
pub extern "C" fn c_sqlite_column_type(stmt : SqliteStmt, idx : Int) -> Int = "moonbit_sqlite_column_type"

///|
/// Get a text value from a column (0-based index)
pub extern "C" fn c_sqlite_column_text(stmt : SqliteStmt, idx : Int) -> CString = "moonbit_sqlite_column_text"

///|
/// Get an int64 value from a column (0-based index)
pub extern "C" fn c_sqlite_column_int64(stmt : SqliteStmt, idx : Int) -> Int64 = "moonbit_sqlite_column_int64"

///|
/// Get a double value from a column (0-based index)
pub extern "C" fn c_sqlite_column_double(
  stmt : SqliteStmt,
  idx : Int,
) -> Double = "moonbit_sqlite_column_double"

///|
/// Get blob data size (0-based index)
pub extern "C" fn c_sqlite_column_bytes(stmt : SqliteStmt, idx : Int) -> Int = "moonbit_sqlite_column_bytes"

///|
/// Copy blob data to buffer (0-based index)
/// Returns: number of bytes copied
#borrow(dest)
pub extern "C" fn c_sqlite_column_blob_copy(
  stmt : SqliteStmt,
  idx : Int,
  dest : Bytes,
  max_len : Int,
) -> Int = "moonbit_sqlite_column_blob_copy"

// ============================================================
// High-Level Helpers
// ============================================================

///|
/// SQLite error type
pub suberror SqliteError {
  ConnectionFailed(String)
  QueryFailed(String)
  PrepareStatementFailed(String)
  BindFailed(String)
  StepFailed(String)
}

///|
/// Open database with error handling
pub fn sqlite_open(path : String) -> SqliteDb raise SqliteError {
  let cpath = string_to_cstring(path)
  match c_sqlite_open(cpath) {
    Some(db) => db
    None =>
      raise SqliteError::ConnectionFailed("Failed to open database: \{path}")
  }
}

///|
/// Execute SQL with error handling
pub fn sqlite_exec(db : SqliteDb, sql : String) -> Unit raise SqliteError {
  let csql = string_to_cstring(sql)
  let rc = c_sqlite_exec(db, csql)
  if rc != sqlite_ok {
    let errmsg = cstring_to_string(c_sqlite_errmsg(db))
    raise SqliteError::QueryFailed(errmsg)
  }
}

///|
/// Prepare statement with error handling
pub fn sqlite_prepare(
  db : SqliteDb,
  sql : String,
) -> SqliteStmt raise SqliteError {
  let csql = string_to_cstring(sql)
  match c_sqlite_prepare(db, csql) {
    Some(stmt) => stmt
    None => {
      let errmsg = cstring_to_string(c_sqlite_errmsg(db))
      raise SqliteError::PrepareStatementFailed(errmsg)
    }
  }
}

///|
/// Bind text parameter with error handling (1-based index)
pub fn sqlite_bind_text(
  stmt : SqliteStmt,
  idx : Int,
  value : String,
) -> Unit raise SqliteError {
  let cvalue = string_to_cstring(value)
  let rc = c_sqlite_bind_text(stmt, idx, cvalue)
  if rc != sqlite_ok {
    raise SqliteError::BindFailed("Failed to bind text at index \{idx}")
  }
}

///|
/// Bind int64 parameter with error handling (1-based index)
pub fn sqlite_bind_int64(
  stmt : SqliteStmt,
  idx : Int,
  value : Int64,
) -> Unit raise SqliteError {
  let rc = c_sqlite_bind_int64(stmt, idx, value)
  if rc != sqlite_ok {
    raise SqliteError::BindFailed("Failed to bind int64 at index \{idx}")
  }
}

///|
/// Bind double parameter with error handling (1-based index)
pub fn sqlite_bind_double(
  stmt : SqliteStmt,
  idx : Int,
  value : Double,
) -> Unit raise SqliteError {
  let rc = c_sqlite_bind_double(stmt, idx, value)
  if rc != sqlite_ok {
    raise SqliteError::BindFailed("Failed to bind double at index \{idx}")
  }
}

///|
/// Bind null parameter with error handling (1-based index)
pub fn sqlite_bind_null(stmt : SqliteStmt, idx : Int) -> Unit raise SqliteError {
  let rc = c_sqlite_bind_null(stmt, idx)
  if rc != sqlite_ok {
    raise SqliteError::BindFailed("Failed to bind null at index \{idx}")
  }
}

///|
/// Bind blob parameter with error handling (1-based index)
pub fn sqlite_bind_blob(
  stmt : SqliteStmt,
  idx : Int,
  data : Bytes,
) -> Unit raise SqliteError {
  let rc = c_sqlite_bind_blob(stmt, idx, data, data.length())
  if rc != sqlite_ok {
    raise SqliteError::BindFailed("Failed to bind blob at index \{idx}")
  }
}

///|
/// Execute prepared statement and get column text
pub fn sqlite_get_text(stmt : SqliteStmt, col : Int) -> String {
  cstring_to_string(c_sqlite_column_text(stmt, col))
}

///|
/// Execute prepared statement and get column int64
pub fn sqlite_get_int64(stmt : SqliteStmt, col : Int) -> Int64 {
  c_sqlite_column_int64(stmt, col)
}

///|
/// Execute prepared statement and get column double
pub fn sqlite_get_double(stmt : SqliteStmt, col : Int) -> Double {
  c_sqlite_column_double(stmt, col)
}

///|
/// Check if column is NULL (0-based index)
pub fn sqlite_is_null(stmt : SqliteStmt, col : Int) -> Bool {
  c_sqlite_column_type(stmt, col) == sqlite_null
}

///|
/// Get blob data as Bytes (0-based index)
pub fn sqlite_get_blob(stmt : SqliteStmt, col : Int) -> Bytes {
  let size = c_sqlite_column_bytes(stmt, col)
  if size <= 0 {
    return Bytes::make(0, 0)
  }
  let buffer = Bytes::make(size, 0)
  let _ = c_sqlite_column_blob_copy(stmt, col, buffer, size)
  buffer
}
