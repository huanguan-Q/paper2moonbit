// ZipLex-style lexer: maximal munch over per-rule derivatives,
// priority = rule order, memoized derivatives, exact print roundtrip.

///|
/// A lexical rule: name plus the regular language it accepts.
pub struct Rule {
  name : String
  re : Regex
}

///|
/// Construct a rule (priority = position in the rule list).
pub fn Rule::new(name : String, re : Regex) -> Rule {
  Rule::{ name, re }
}

///|
/// A lexed token: rule name plus the exact matched substring.
pub struct Token {
  rule : String
  lexeme : String
}

///|
/// Memoized derivative: same (regex-render, char) pair reuses the result.
fn memo_derivative(
  memo : @hashmap.HashMap[String, Regex],
  c : Char,
  r : Regex,
) -> Regex {
  let key = render(r) + "\u{0000}" + c.to_string()
  match memo.get(key) {
    Some(d) => d
    None => {
      let d = derivative(c, r)
      memo.set(key, d)
      d
    }
  }
}

///|
/// Lex `input` under `rules` with maximal munch (longest match) semantics;
/// ties at equal length are resolved by earlier rule position.
/// Err when some position cannot start any rule.
pub fn lex(rules : Array[Rule], input : String) -> Result[Array[Token], String] {
  let memo : @hashmap.HashMap[String, Regex] = HashMap([], capacity=64)
  let n = input.length()
  let k = rules.length()
  let tokens : Array[Token] = []
  let mut pos = 0
  while pos < n {
    // current derivative of each rule's regex
    let ders : Array[Regex] = []
    for r in rules {
      ders.push(r.re)
    }
    // best = (match length, rule index) of the FARTHEST nullable state so far
    let mut best_len = -1
    let mut best_rule = -1
    let mut j = pos
    let mut alive = true
    while alive && j < n {
      // update all derivatives with input[j]
      let c = match input[j].to_char() {
        Some(ch) => ch
        None => return Err("lex error: invalid UTF-16 unit at offset \{j}")
      }
      for i in 0..<k {
        ders[i] = memo_derivative(memo, c, ders[i])
      }
      j += 1
      // record farthest nullable position; priority = smallest rule index
      let mut i = 0
      while i < k {
        if nullable(ders[i]) {
          best_len = j - pos
          best_rule = i
          break
        }
        i += 1
      }
      // die when every derivative is empty
      alive = false
      for i in 0..<k {
        if ders[i] is REmpty {
          continue
        } else {
          alive = true
          break
        }
      }
    }
    if best_rule < 0 {
      return Err(
        "lex error at offset \{pos}: no rule matches input starting here",
      )
    }
    if best_len == 0 {
      return Err("lex error at offset \{pos}: rule matched empty string")
    }
    tokens.push(
      Token::{ rule: rules[best_rule].name, lexeme: input[pos:pos + best_len].to_owned() },
    )
    pos += best_len
  }
  Ok(tokens)
}

///|
/// Print tokens back to text: exact inverse of lex for covered inputs
/// (ZipLex invertibility, simplified via lexeme retention).
pub fn print(tokens : Array[Token]) -> String {
  let buf = StringBuilder()
  for t in tokens {
    buf.write_string(t.lexeme)
  }
  buf.to_string()
}
