// Regex AST with Brzozowski derivatives and smart constructors
// (Owens-Reppy-Turon style simplification keeps the derivative state space finite).

///|
#derive(Eq, Hash, @debug.Debug)
pub enum Regex {
  REmpty
  REps
  RChar(Char)
  RRange(Char, Char)
  RUnion(Array[Regex])
  RConcat(Regex, Regex)
  RStar(Regex)
}

///|
pub extend Regex with Eq::{equal, not_equal}

///|
pub extend Regex with Hash::{hash, hash_combine}

///|
pub extend Regex with @debug.Debug::{to_repr}

///|
/// Smart union: flatten nested unions, drop empty branches, dedup structurally.
fn mk_union(rs : Array[Regex]) -> Regex {
  let out : Array[Regex] = []
  fn go(r : Regex) -> Unit {
    match r {
      RUnion(inner) =>
        for x in inner {
          go(x)
        }
      REmpty => ()
      other => {
        // linear dedup: skip structurally equal duplicates (r | r = r)
        let mut dup = false
        for x in out {
          if x == other {
            dup = true
            break
          }
        }
        if !dup {
          out.push(other)
        }
      }
    }
  }

  for r in rs {
    go(r)
  }
  match out.length() {
    0 => REmpty
    1 => out[0]
    _ => RUnion(out)
  }
}

///|
/// Smart concat: empty absorbs, eps is identity.
fn mk_concat(r1 : Regex, r2 : Regex) -> Regex {
  match r1 {
    REmpty => REmpty
    REps => r2
    _ =>
      match r2 {
        REmpty => REmpty
        REps => r1
        _ => RConcat(r1, r2)
      }
  }
}

///|
/// Smart star: empty* = eps, eps* = eps, (r*)* = r*.
fn mk_star(r : Regex) -> Regex {
  match r {
    REmpty => REps
    REps => REps
    RStar(inner) => mk_star(inner)
    other => RStar(other)
  }
}

///|
/// Does the language contain the empty word?
fn nullable(r : Regex) -> Bool {
  match r {
    REmpty => false
    REps => true
    RChar(_) => false
    RRange(_, _) => false
    RUnion(rs) => {
      let mut any = false
      for x in rs {
        if nullable(x) {
          any = true
          break
        }
      }
      any
    }
    RConcat(r1, r2) => nullable(r1) && nullable(r2)
    RStar(_) => true
  }
}

///|
/// Brzozowski derivative of r with respect to character c.
fn derivative(c : Char, r : Regex) -> Regex {
  match r {
    REmpty => REmpty
    REps => REmpty
    RChar(a) => if a == c { REps } else { REmpty }
    RRange(lo, hi) => if lo <= c && c <= hi { REps } else { REmpty }
    RUnion(rs) => mk_union(rs.map(fn(x) { derivative(c, x) }))
    RConcat(r1, r2) => {
      let left = mk_concat(derivative(c, r1), r2)
      if nullable(r1) {
        mk_union([left, derivative(c, r2)])
      } else {
        left
      }
    }
    RStar(inner) => mk_concat(derivative(c, inner), RStar(inner))
  }
}

///|
/// Canonical rendering: used for debugging and as memoization key.
fn render(r : Regex) -> String {
  let buf = StringBuilder()
  fn go(r : Regex) -> Unit {
    match r {
      REmpty => buf.write_string("0")
      REps => buf.write_string("1")
      RChar(c) => {
        buf.write_string("'")
        buf.write_char(c)
        buf.write_string("'")
      }
      RRange(lo, hi) => {
        buf.write_string("[")
        buf.write_char(lo)
        buf.write_string("-")
        buf.write_char(hi)
        buf.write_string("]")
      }
      RUnion(rs) => {
        buf.write_string("(")
        for i, x in rs {
          if i > 0 {
            buf.write_string("|")
          }
          go(x)
        }
        buf.write_string(")")
      }
      RConcat(r1, r2) => {
        buf.write_string("(")
        go(r1)
        go(r2)
        buf.write_string(")")
      }
      RStar(inner) => {
        buf.write_string("(")
        go(inner)
        buf.write_string(")*")
      }
    }
  }

  go(r)
  buf.to_string()
}

///|
/// Public combinators for building rule regexes.

///|
pub fn range(lo : Char, hi : Char) -> Regex {
  RRange(lo, hi)
}

///|
/// Union of the single characters in `s`.
pub fn chars(s : String) -> Regex {
  let rs : Array[Regex] = []
  for c in s {
    rs.push(RChar(c))
  }
  mk_union(rs)
}

///|
/// Concatenation of single characters: the exact literal string.
pub fn str(s : String) -> Regex {
  let mut r : Regex = REps
  for c in s {
    r = mk_concat(r, RChar(c))
  }
  r
}

///|
/// One or more: r · r*.
pub fn plus(r : Regex) -> Regex {
  mk_concat(r, mk_star(r))
}

///|
/// Concatenation of two regexes.
pub fn concat(r1 : Regex, r2 : Regex) -> Regex {
  mk_concat(r1, r2)
}

///|
/// Union (alternation) of several regexes.
pub fn alt(rs : Array[Regex]) -> Regex {
  mk_union(rs)
}
