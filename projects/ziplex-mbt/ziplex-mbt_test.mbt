// Blackbox spec-level tests: ZipLex paper criteria (arXiv:2510.18479).

///|
/// Demo rule set: keywords, identifiers, numbers, punctuation, whitespace.
/// Covers every ASCII char used in test inputs (roundtrip precondition).
fn demo_rules() -> Array[@ziplex.Rule] {
  let letter = @ziplex.range('a', 'z')
  [
    @ziplex.Rule::new(
      "KW",
      @ziplex.alt([@ziplex.str("let"), @ziplex.str("if")]),
    ),
    @ziplex.Rule::new("IDENT", @ziplex.plus(letter)),
    @ziplex.Rule::new("NUMBER", @ziplex.plus(@ziplex.range('0', '9'))),
    @ziplex.Rule::new("PUNCT", @ziplex.chars("=+(){}:")),
    @ziplex.Rule::new("WS", @ziplex.chars(" \n\t")),
  ]
}

///|
test "maximal munch: longest match beats priority" {
  // "letx": at len 3 both KW and IDENT nullable; at len 4 only IDENT ->
  // maximal munch emits IDENT("letx"), not KW("let") + IDENT("x")
  let toks = match @ziplex.lex(demo_rules(), "letx") {
    Ok(t) => t
    Err(msg) => abort("lex failed: \{msg}")
  }
  assert_eq(toks.length(), 1)
  assert_eq(toks[0].rule, "IDENT")
  assert_eq(toks[0].lexeme, "letx")
}

///|
test "priority: equal length -> earlier rule wins" {
  let toks = match @ziplex.lex(demo_rules(), "let") {
    Ok(t) => t
    Err(msg) => abort("lex failed: \{msg}")
  }
  assert_eq(toks.length(), 1)
  assert_eq(toks[0].rule, "KW")
  // "if" likewise; "i" alone would be IDENT
  let if_tok = match @ziplex.lex(demo_rules(), "if") {
    Ok(t) => t
    Err(msg) => abort("lex failed: \{msg}")
  }
  assert_eq(if_tok[0].rule, "KW")
}

///|
test "token stream: mini program text" {
  // note: IDENT covers letters only, so "x0" lexes as IDENT("x") + NUMBER("0")
  let toks = match @ziplex.lex(demo_rules(), "let x0 = 42+") {
    Ok(t) => t
    Err(msg) => abort("lex failed: \{msg}")
  }
  assert_eq(toks.length(), 9)
  // rules in order
  assert_eq(toks[0].rule, "KW")
  assert_eq(toks[2].rule, "IDENT")
  assert_eq(toks[2].lexeme, "x")
  assert_eq(toks[3].rule, "NUMBER")
  assert_eq(toks[3].lexeme, "0")
  assert_eq(toks[5].rule, "PUNCT")
  assert_eq(toks[7].rule, "NUMBER")
  assert_eq(toks[7].lexeme, "42")
  assert_eq(toks[8].rule, "PUNCT")
}

///|
test "invertibility: print(lex(s)) == s (paper core guarantee)" {
  let inputs : Array[String] = [
    "let x = foo123 + bar\nif (y) { z }", "  let  x0=1\t\nif x2 then x3", "a+b+c\n\n\td",
    "letletif iflet 007zz",
  ]
  for s in inputs {
    let toks = match @ziplex.lex(demo_rules(), s) {
      Ok(t) => t
      Err(msg) => abort("lex failed on \"\{s}\": \{msg}")
    }
    assert_eq(@ziplex.print(toks), s)
  }
}

///|
test "lexing error: uncovered character" {
  // '$' not covered by any rule
  assert_eq(
    match @ziplex.lex(demo_rules(), "ab$cd") {
      Err(_) => true
      Ok(_) => false
    },
    true,
  )
}

///|
test "edge cases: empty input, whitespace-only, single char" {
  assert_eq(
    match @ziplex.lex(demo_rules(), "") {
      Ok(t) => t.length()
      Err(_) => -1
    },
    0,
  )
  let ws = match @ziplex.lex(demo_rules(), " \n\t ") {
    Ok(t) => t
    Err(msg) => abort("lex failed: \{msg}")
  }
  assert_eq(ws.length(), 4)
  assert_eq(@ziplex.print(ws), " \n\t ")
  let one = match @ziplex.lex(demo_rules(), "z") {
    Ok(t) => t
    Err(msg) => abort("lex failed: \{msg}")
  }
  assert_eq(one[0].lexeme, "z")
}

///|
test "JSON-shape lexing (paper evaluation scenario)" {
  let json_rules : Array[@ziplex.Rule] = [
    @ziplex.Rule::new("LBRACE", @ziplex.chars("{")),
    @ziplex.Rule::new("RBRACE", @ziplex.chars("}")),
    @ziplex.Rule::new("COLON", @ziplex.chars(":")),
    @ziplex.Rule::new("COMMA", @ziplex.chars(",")),
    @ziplex.Rule::new("NUMBER", @ziplex.plus(@ziplex.range('0', '9'))),
    @ziplex.Rule::new(
      "STRING",
      @ziplex.concat(
        @ziplex.str("\""),
        @ziplex.concat(@ziplex.plus(@ziplex.chars("abc")), @ziplex.str("\"")),
      ),
    ),
    @ziplex.Rule::new("WS", @ziplex.chars(" ")),
  ]
  let src = "{ \"ab\": 12, \"c\": 3 }"
  let toks = match @ziplex.lex(json_rules, src) {
    Ok(t) => t
    Err(msg) => abort("lex failed: \{msg}")
  }
  // invertibility roundtrip
  assert_eq(@ziplex.print(toks), src)
  // spot-check the string tokens
  let strs = toks.filter(fn(t) { t.rule == "STRING" })
  assert_eq(strs.length(), 2)
  assert_eq(strs[0].lexeme, "\"ab\"")
  assert_eq(strs[1].lexeme, "\"c\"")
}
