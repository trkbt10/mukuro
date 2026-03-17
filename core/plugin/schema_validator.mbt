///|
/// JSON Schema validator for plugin tool arguments

///|
/// Validation result
pub(all) enum ValidationResult {
  /// Validation passed
  Valid
  /// Validation failed with errors
  Invalid(Array[ValidationError])
}

///|
/// Validation error
pub(all) struct ValidationError {
  /// Path to the invalid property (e.g., "params.name")
  path : String
  /// Error message
  message : String
  /// Expected type or value
  expected : String?
  /// Actual type or value
  actual : String?
}

///|
/// Create a validation error
pub fn ValidationError::new(
  path~ : String,
  message~ : String,
) -> ValidationError {
  { path, message, expected: None, actual: None }
}

///|
/// Create a type mismatch error
pub fn ValidationError::type_mismatch(
  path~ : String,
  expected~ : String,
  actual~ : String,
) -> ValidationError {
  {
    path,
    message: "Type mismatch",
    expected: Some(expected),
    actual: Some(actual),
  }
}

///|
/// Create a missing required property error
pub fn ValidationError::missing_required(path~ : String) -> ValidationError {
  { path, message: "Required property missing", expected: None, actual: None }
}

///|
/// Schema validator
pub struct SchemaValidator {
  /// Strict mode (fail on unknown properties)
  strict : Bool
}

///|
/// Create a new schema validator
pub fn SchemaValidator::new() -> SchemaValidator {
  { strict: false }
}

///|
/// Create a strict schema validator
pub fn SchemaValidator::strict() -> SchemaValidator {
  { strict: true }
}

///|
/// Validate JSON against schema
pub fn SchemaValidator::validate(
  self : SchemaValidator,
  schema : Json,
  value : Json,
) -> ValidationResult {
  let errors : Array[ValidationError] = []
  self.validate_value(schema, value, "", errors)
  if errors.length() == 0 {
    ValidationResult::Valid
  } else {
    ValidationResult::Invalid(errors)
  }
}

///|
/// Validate a value recursively
fn SchemaValidator::validate_value(
  self : SchemaValidator,
  schema : Json,
  value : Json,
  path : String,
  errors : Array[ValidationError],
) -> Unit {
  // Get expected type
  let expected_type = match schema {
    { "type": String(t), .. } => t
    _ => return // No type constraint
  }
  // Validate type
  let actual_type = get_json_type(value)
  if expected_type != actual_type {
    // Special case: integer is a number
    if expected_type == "integer" && actual_type == "number" {
      // Check if it's actually an integer
      match value {
        Number(n, ..) =>
          if n != n.to_int().to_double() {
            errors.push(
              ValidationError::type_mismatch(
                path~,
                expected=expected_type,
                actual="non-integer number",
              ),
            )
          }
        _ => ()
      }
    } else {
      errors.push(
        ValidationError::type_mismatch(
          path~,
          expected=expected_type,
          actual=actual_type,
        ),
      )
      return
    }
  }
  // Type-specific validation
  match expected_type {
    "object" => self.validate_object(schema, value, path, errors)
    "array" => self.validate_array(schema, value, path, errors)
    "string" => self.validate_string(schema, value, path, errors)
    "number" | "integer" => self.validate_number(schema, value, path, errors)
    _ => ()
  }
}

///|
/// Validate object value
fn SchemaValidator::validate_object(
  self : SchemaValidator,
  schema : Json,
  value : Json,
  path : String,
  errors : Array[ValidationError],
) -> Unit {
  match (schema, value) {
    ({ "properties": Object(props), .. }, Object(obj)) => {
      // Check required properties
      let required : Map[String, Bool] = {}
      match schema {
        { "required": Array(req), .. } =>
          for item in req {
            match item {
              String(name) => required[name] = true
              _ => ()
            }
          }
        _ => ()
      }
      // Validate each required property exists
      for name, _ in required {
        if not(obj.contains(name)) {
          let prop_path = if path == "" { name } else { "\{path}.\{name}" }
          errors.push(ValidationError::missing_required(path=prop_path))
        }
      }
      // Validate each property
      for name, prop_schema in props {
        match obj.get(name) {
          Some(prop_value) => {
            let prop_path = if path == "" { name } else { "\{path}.\{name}" }
            self.validate_value(prop_schema, prop_value, prop_path, errors)
          }
          None => ()
        }
      }
      // Check for unknown properties in strict mode
      if self.strict {
        for name, _ in obj {
          if not(props.contains(name)) {
            let prop_path = if path == "" { name } else { "\{path}.\{name}" }
            errors.push(
              ValidationError::new(path=prop_path, message="Unknown property"),
            )
          }
        }
      }
    }
    _ => ()
  }
}

///|
/// Validate array value
fn SchemaValidator::validate_array(
  self : SchemaValidator,
  schema : Json,
  value : Json,
  path : String,
  errors : Array[ValidationError],
) -> Unit {
  match (schema, value) {
    ({ "items": item_schema, .. }, Array(items)) =>
      for i = 0; i < items.length(); i = i + 1 {
        let item_path = "\{path}[\{i}]"
        self.validate_value(item_schema, items[i], item_path, errors)
      }
    ({ "minItems": Number(min, ..), .. }, Array(items)) =>
      if items.length() < min.to_int() {
        errors.push(
          ValidationError::new(
            path~,
            message="Array too short, minimum \{min.to_int()} items required",
          ),
        )
      }
    ({ "maxItems": Number(max, ..), .. }, Array(items)) =>
      if items.length() > max.to_int() {
        errors.push(
          ValidationError::new(
            path~,
            message="Array too long, maximum \{max.to_int()} items allowed",
          ),
        )
      }
    _ => ()
  }
}

///|
/// Validate string value
fn SchemaValidator::validate_string(
  _self : SchemaValidator,
  schema : Json,
  value : Json,
  path : String,
  errors : Array[ValidationError],
) -> Unit {
  match value {
    String(s) => {
      // Check minLength
      match schema {
        { "minLength": Number(min, ..), .. } =>
          if s.length() < min.to_int() {
            errors.push(
              ValidationError::new(
                path~,
                message="String too short, minimum \{min.to_int()} characters required",
              ),
            )
          }
        _ => ()
      }
      // Check maxLength
      match schema {
        { "maxLength": Number(max, ..), .. } =>
          if s.length() > max.to_int() {
            errors.push(
              ValidationError::new(
                path~,
                message="String too long, maximum \{max.to_int()} characters allowed",
              ),
            )
          }
        _ => ()
      }
      // Check enum
      match schema {
        { "enum": Array(values), .. } => {
          let mut found = false
          for v in values {
            match v {
              String(enum_val) if enum_val == s => found = true
              _ => ()
            }
          }
          if not(found) {
            errors.push(
              ValidationError::new(
                path~,
                message="Value not in allowed enum values",
              ),
            )
          }
        }
        _ => ()
      }
    }
    _ => ()
  }
}

///|
/// Validate number value
fn SchemaValidator::validate_number(
  _self : SchemaValidator,
  schema : Json,
  value : Json,
  path : String,
  errors : Array[ValidationError],
) -> Unit {
  match value {
    Number(n, ..) => {
      // Check minimum
      match schema {
        { "minimum": Number(min, ..), .. } =>
          if n < min {
            errors.push(
              ValidationError::new(
                path~,
                message="Number below minimum value \{min}",
              ),
            )
          }
        _ => ()
      }
      // Check maximum
      match schema {
        { "maximum": Number(max, ..), .. } =>
          if n > max {
            errors.push(
              ValidationError::new(
                path~,
                message="Number above maximum value \{max}",
              ),
            )
          }
        _ => ()
      }
    }
    _ => ()
  }
}

///|
/// Get JSON type string
fn get_json_type(value : Json) -> String {
  match value {
    Null => "null"
    True | False => "boolean"
    Number(_) => "number"
    String(_) => "string"
    Array(_) => "array"
    Object(_) => "object"
  }
}

///|
/// Validate tool arguments against tool definition
pub fn validate_tool_arguments(
  tool : @llm_types.ToolDefinition,
  arguments : Json,
) -> ValidationResult {
  match tool.schema {
    Some(schema) => SchemaValidator::new().validate(schema, arguments)
    None => ValidationResult::Valid
  }
}
