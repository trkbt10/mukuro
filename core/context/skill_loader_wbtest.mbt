///|
test "parse_skill_markdown parses valid frontmatter" {
  let content = "---\nname: MySkill\ndescription: A useful skill\n---\n\n## Usage\n\nDo things here."
  match parse_skill_markdown(content) {
    Some(skill) => {
      assert_eq(skill.name, "MySkill")
      assert_eq(skill.description, "A useful skill")
      assert_true(skill.instructions.contains("Do things here"))
    }
    None => fail("Expected Some")
  }
}

///|
test "parse_skill_markdown rejects missing frontmatter" {
  let content = "# Just a normal markdown file\n\nNo frontmatter here."
  inspect(parse_skill_markdown(content) is None, content="true")
}

///|
test "parse_skill_markdown rejects missing name" {
  let content = "---\ndescription: No name field\n---\n\nBody text."
  inspect(parse_skill_markdown(content) is None, content="true")
}

///|
test "parse_skill_markdown handles empty body" {
  let content = "---\nname: EmptyBody\ndescription: Nothing\n---\n"
  match parse_skill_markdown(content) {
    Some(skill) => {
      assert_eq(skill.name, "EmptyBody")
      assert_eq(skill.instructions, "")
    }
    None => fail("Expected Some")
  }
}

///|
test "parse_skill_markdown multiline body" {
  let content = "---\nname: MultiLine\ndescription: Has multiple lines\n---\nLine 1\nLine 2\nLine 3"
  match parse_skill_markdown(content) {
    Some(skill) => {
      assert_true(skill.instructions.contains("Line 1"))
      assert_true(skill.instructions.contains("Line 2"))
      assert_true(skill.instructions.contains("Line 3"))
    }
    None => fail("Expected Some")
  }
}
