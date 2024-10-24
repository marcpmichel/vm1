import std.range;
import std.conv;
import std.uni;
import tokens;
import errors;

class Tokenizer {
  string code;
  Token cur;

  this(string code) {
    this.code = code;
    // import std.stdio: writeln; writeln(this.code.front);
    this.next();
  }

  void lexicalError(string msg) {
    throw new LexicalError("lexical error: " ~ msg);
  }

  bool done() {
    return code.empty;
  }

  void advance() {
    if(!code.empty) code.popFront;
  }

  Token next() {
      import std.format: format;
      if(code.empty) { cur = Token(Tok.EoF); return cur; }
      dchar c = code.front;
      switch(c) {
        case '\n', '\r': cur = parseEoL(); break; 
        case ' ', '\t': cur = parseBlank(); break;
        case '0': .. case '9': cur = parseNumber(); break;
        case 'a': .. case 'z':
        case 'A': .. case 'Z': cur = parseIdentifier(); break;
        case '!', '=', '>', '<': cur = parseComparison(); break; 
        case '(': cur = parseSingle(Tok.LParen); break;
        case ')': cur = parseSingle(Tok.RParen); break;
        case '+': cur = parseSingle(Tok.Add); break;
        case '-': cur = parseSingle(Tok.Sub); break;
        case '*': cur = parseSingle(Tok.Mul); break;
        case '/': cur = parseSingle(Tok.Div); break;
        case '"': cur = parseString(); break;
        default: lexicalError(format("unexpected token %02x", code.front)); 
      }

      return cur;
  }

  Token parseEoL() {
    while(!code.empty && (code.front == '\n' || code.front == '\r')) {
      code.popFront;
    }
    return next();
  }

  Token parseBlank() { 
    while(!code.empty && (code.front == ' ' || code.front == '\t')) { 
      code.popFront;
    }
    return next(); // skip blanks // Token(Tok.Blank); 
  }

  Token parseSingle(Tok type) {
    advance();
    return Token(type);
  }

  Token parseString() {
    string s;
    code.popFront; // consume '"'
    for(;;) {
      if(code.empty) break; // TODO: error unterminated string
      if(code.front == '"') { code.popFront; break; }
      s ~= code.front;
      code.popFront;
    }
    return Token(Tok.String, s);
  }

  Token parseNumber() {
    string s;
    for(;;) {
      if(code.empty) break;
      if(code.front < '0' || code.front > '9') break;
      // TODO: test for float
      s ~= code.front;
      code.popFront;
    }
    return Token(Tok.Number, s);
  }

  Token parseIdentifier() {
    string s;
    for(;;) {
      if(code.empty) break;
      if(!isAlphaNum(code.front)) break;
      s ~= code.front;
      code.popFront;
    }
    return Token(Tok.Identifier, s);
  }

  bool cur_is(Tok type) {
    return cur.type == type;
  }

  Token parseComparison() {
    Tok t;
    dchar c = code.front;
    advance();
    switch(c) {
      case '>': 
        if(code.front == '=' && !code.empty) { advance(); t = Tok.Gte; } else t = Tok.Gt; 
        break;
      case '<': 
        if(code.front == '=' && !code.empty) { advance(); t = Tok.Lte; } else t = Tok.Lt; 
        break;
      case '=':
        if(code.front == '=' && !code.empty) { advance(); t = Tok.Eq; } else t = Tok.Eq; 
        break;
      case '!':
        if(code.front == '=' && !code.empty) { advance(); t = Tok.Neq; } else t = Tok.Not;
        break;
      default:
        lexicalError("bad comparison operator");
        return Token(Tok.Error);
    }
    return Token(t);
  }

}

@("can lex: 12") unittest {
  auto t = new Tokenizer("12");
  assert(t.cur.type == Tok.Number);
}

@("can lex: +") unittest {
  auto t = new Tokenizer("+");
  assert(t.cur.type == Tok.Add);
}

@(`can lex: "abccd"`) unittest {
  auto t = new Tokenizer(`"abcd"`);
  assert(t.cur_is(Tok.String));
  assert(t.cur.s == "abcd");
}

@("can lex: a + 12") unittest {
  auto t = new Tokenizer("a + 12");
  assert(t.cur_is(Tok.Identifier));
  assert(t.cur.s == "a");
  t.next;
  assert(t.cur_is(Tok.Add));
  t.next;
  assert(t.cur_is(Tok.Number));
}

@("can lex: (12)") unittest {
  auto t = new Tokenizer("(12)");
  assert(t.cur_is(Tok.LParen), "not LParen");
  t.next;
  assert(t.cur_is(Tok.Number), "not a number !");
  assert(t.cur.s == "12", "expected 12");
  t.next;
  assert(t.cur_is(Tok.RParen), "not RParen");
}

@("can lex: >") unittest {
  auto t = new Tokenizer(" > ");
  assert(t.cur_is(Tok.Gt), "not Gt");
}
