import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import nibble.{Break, Continue, do, loop, one_of, return, take_map}
import nibble/lexer.{type Token}

type Mode {
  Plain
  AfterEsc
  AfterBracket
  AfterSgr
  InEscape
}

pub type AnsiToken {
  Text(String)
  Sgr(String)
}

type RenderState {
  RenderState(html: String, style: String)
}

pub fn ansi_to_html(text: String) -> String {
  case lex(text) {
    Ok(tokens) -> {
      case nibble.run(tokens, html_parser()) {
        Ok(html) -> html
        Error(_) -> escape_html(text)
      }
    }
    Error(_) -> escape_html(text)
  }
}

fn lex(text: String) -> Result(List(Token(AnsiToken)), lexer.Error) {
  lexer.run_advanced(text, Plain, ansi_lexer())
}

fn ansi_lexer() -> lexer.Lexer(AnsiToken, Mode) {
  lexer.advanced(fn(mode) {
    case mode {
      Plain -> [
        esc_start_matcher(),
        esc_bracket_matcher(),
        plain_text_matcher(),
      ]
      AfterEsc -> [after_esc_matcher()]
      AfterBracket -> [after_bracket_matcher()]
      AfterSgr -> [after_sgr_matcher()]
      InEscape -> [in_escape_matcher()]
    }
  })
}

fn plain_text_matcher() -> lexer.Matcher(AnsiToken, Mode) {
  lexer.custom(fn(_mode, lexeme, lookahead) {
    case lookahead {
      "" ->
        case lexeme {
          "" -> lexer.NoMatch
          _ -> lexer.Keep(Text(lexeme), Plain)
        }
      "\u{1B}" ->
        case lexeme {
          "" -> lexer.NoMatch
          _ -> lexer.Keep(Text(lexeme), Plain)
        }
      _ -> lexer.Skip
    }
  })
}

fn esc_bracket_matcher() -> lexer.Matcher(AnsiToken, Mode) {
  lexer.custom(fn(_mode, lexeme, lookahead) {
    case lexeme, lookahead {
      "\u{1B}", "[" -> lexer.Drop(AfterBracket)
      _, _ -> lexer.NoMatch
    }
  })
}

fn esc_start_matcher() -> lexer.Matcher(AnsiToken, Mode) {
  lexer.custom(fn(_mode, lexeme, lookahead) {
    case lexeme, lookahead {
      "", "\u{1B}" -> lexer.Drop(AfterEsc)
      _, _ -> lexer.NoMatch
    }
  })
}

fn after_esc_matcher() -> lexer.Matcher(AnsiToken, Mode) {
  lexer.custom(fn(_mode, lexeme, lookahead) {
    case lexeme, lookahead {
      "\u{1B}", "[" -> lexer.Drop(AfterBracket)
      "\u{1B}", "" -> lexer.Keep(Text("\u{1B}"), Plain)
      "\u{1B}", _ -> lexer.Keep(Text("\u{1B}"), Plain)
      _, _ -> lexer.NoMatch
    }
  })
}

fn after_bracket_matcher() -> lexer.Matcher(AnsiToken, Mode) {
  lexer.custom(fn(_mode, lexeme, _lookahead) {
    case lexeme {
      "[" -> lexer.Drop(InEscape)
      _ -> lexer.NoMatch
    }
  })
}

fn after_sgr_matcher() -> lexer.Matcher(AnsiToken, Mode) {
  lexer.custom(fn(_mode, lexeme, _lookahead) {
    case lexeme {
      "" -> lexer.Drop(Plain)
      _ -> lexer.Drop(Plain)
    }
  })
}

fn in_escape_matcher() -> lexer.Matcher(AnsiToken, Mode) {
  lexer.custom(fn(_mode, lexeme, lookahead) {
    case is_control_letter(lookahead) {
      True -> {
        let seq = lexeme <> lookahead
        case string.ends_with(seq, "m") {
          True -> lexer.Keep(Sgr(string.drop_end(seq, 1)), AfterSgr)
          False -> lexer.Drop(Plain)
        }
      }
      False -> lexer.Skip
    }
  })
}

fn html_parser() -> nibble.Parser(String, AnsiToken, Nil) {
  loop(RenderState("", ""), fn(state) {
    one_of([
      {
        use chunk <- do(text_chunk_parser(state.style))
        return(Continue(RenderState(state.html <> chunk, state.style)))
      },
      {
        use style <- do(sgr_parser())
        return(Continue(RenderState(state.html, style)))
      },
      return(Break(state.html)),
    ])
  })
}

fn text_chunk_parser(style: String) -> nibble.Parser(String, AnsiToken, Nil) {
  take_map("text", fn(token) {
    case token {
      Text(text) -> option.Some(wrap_segment(text, style))
      _ -> option.None
    }
  })
}

fn sgr_parser() -> nibble.Parser(String, AnsiToken, Nil) {
  take_map("sgr", fn(token) {
    case token {
      Sgr(codes) -> option.Some(style_from_codes(codes))
      _ -> option.None
    }
  })
}

fn is_control_letter(c: String) -> Bool {
  case c {
    "A"
    | "B"
    | "C"
    | "D"
    | "E"
    | "F"
    | "G"
    | "H"
    | "I"
    | "J"
    | "K"
    | "L"
    | "M"
    | "N"
    | "O"
    | "P"
    | "Q"
    | "R"
    | "S"
    | "T"
    | "U"
    | "V"
    | "W"
    | "X"
    | "Y"
    | "Z"
    | "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z" -> True
    _ -> False
  }
}

fn wrap_segment(text: String, style: String) -> String {
  let escaped = escape_html(text)
  case style {
    "" -> escaped
    _ -> "<span style=\"" <> style <> "\">" <> escaped <> "</span>"
  }
}

fn style_from_codes(code_string: String) -> String {
  let codes = case string.trim(code_string) {
    "" -> ["0"]
    _ -> string.split(code_string, on: ";")
  }

  let #(bold, dim, colour) =
    list.fold(codes, #(False, False, option.None), fn(state, raw) {
      case int.parse(raw) {
        Ok(0) -> #(False, False, option.None)
        Ok(1) -> #(True, state.1, state.2)
        Ok(2) -> #(state.0, True, state.2)
        Ok(22) -> #(False, False, state.2)
        Ok(code) ->
          case dict.get(fg_colours(), code) {
            Ok(c) -> #(state.0, state.1, option.Some(c))
            Error(_) -> state
          }
        Error(_) -> state
      }
    })

  let parts =
    list.flatten([
      case bold {
        True -> ["font-weight:600"]
        False -> []
      },
      case dim {
        True -> ["opacity:0.55"]
        False -> []
      },
      case colour {
        option.Some(c) -> ["color:" <> c]
        option.None -> []
      },
    ])

  string.join(parts, with: ";")
}

fn fg_colours() -> dict.Dict(Int, String) {
  dict.from_list([
    #(30, "#94a3b8"),
    #(31, "#f87171"),
    #(32, "#4ade80"),
    #(33, "#facc15"),
    #(34, "#60a5fa"),
    #(35, "#e879f9"),
    #(36, "#22d3ee"),
    #(37, "#f1f5f9"),
    #(90, "#64748b"),
    #(91, "#fca5a5"),
    #(92, "#86efac"),
    #(93, "#fde047"),
    #(94, "#93c5fd"),
    #(95, "#f0abfc"),
    #(96, "#67e8f9"),
    #(97, "#ffffff"),
  ])
}

fn escape_html(text: String) -> String {
  text
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
}
