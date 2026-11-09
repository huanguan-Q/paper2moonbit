///|
fn main {
  // ZipLex-style lexer demo (arXiv:2510.18479)
  let letter = @ziplex.range('a', 'z')
  let rules : Array[@ziplex.Rule] = [
    @ziplex.Rule::new("KW", @ziplex.alt([@ziplex.str("let"), @ziplex.str("if")])),
    @ziplex.Rule::new("IDENT", @ziplex.plus(letter)),
    @ziplex.Rule::new("NUMBER", @ziplex.plus(@ziplex.range('0', '9'))),
    @ziplex.Rule::new("PUNCT", @ziplex.chars("=+(){}:")),
    @ziplex.Rule::new("WS", @ziplex.chars(" \n\t")),
  ]
  let src = "let zip = 2510 + 18479\nif (x) { y }"
  match @ziplex.lex(rules, src) {
    Ok(toks) => {
      println("input  : \{src}")
      println("tokens : \{toks.length()}")
      for t in toks {
        println("  \{t.rule}(\{t.lexeme})")
      }
      // invertibility: print(lex(s)) == s
      let back = @ziplex.print(toks)
      println("roundtrip ok: \{back == src}")
    }
    Err(msg) => println("lex error: \{msg}")
  }
}
