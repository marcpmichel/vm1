
import lexer;
import tokens;
import std.conv;
import errors;

import expressions;

class Parser {

  bool eof;
  bool error;
  string errmsg;

  Tokenizer lex;

  void parseError(string errmsg) {
      this.error = true; 
      this.errmsg = "unidentfier Atom";
      throw new ParseError(errmsg);
  }

  Expression parse(string program) {
    lex = new Tokenizer("(begin "~ program ~ ")");
    return parseExpression();
  }

  void advance() {
    if(!lex.done) lex.next();
    import std.stdio: writeln; writeln(lex.cur);
  }
  /**
  Expression : Atom | List
  */
  Expression parseExpression() {
    if(lex.cur_is(Tok.EoF)) return new EndExpression();

    if(lex.cur_is(Tok.LParen)) {
      return parseList();
    }
    else {
      return parseAtom();
    }
  }

  /**
    Atom: Number | String | Identifier
  */
  Expression parseAtom() {
    Expression e;
    switch(lex.cur.type) {
      case Tok.Number: e = new NumberExpression(lex.cur.s); break;
      case Tok.String: e = new StringExpression(lex.cur.s); break;
      case Tok.Add, Tok.Div, Tok.Sub, Tok.Mul: e = new SymbolExpression(lex.cur.type); break;
      case Tok.Eq, Tok.Neq, Tok.Gt, Tok.Gte, Tok.Lt, Tok.Lte: e = new SymbolExpression(lex.cur.type); break;
      case Tok.Identifier: e = parseIdentifier(lex.cur.s); break;
      default: 
        parseError("unexpected atom type");
        return null;
    }
    advance();
    return e;
  }

  Expression parseIdentifier(string s) {
    if(s == "true" || s == "false") return new BoolExpression(s);
    return new SymbolExpression(s);
  }

  Expression parseList() {
    ListExpression list = new ListExpression();
    lex.next(); // consume '('
    while(!lex.cur_is(Tok.RParen)) {
      list.add(parseExpression());
    }
    lex.next();
    return list;
  }
}

version(unittest) {
  import std.stdio: writeln;
}

@("can parse: 10") unittest {
  auto p = new Parser();
  auto e = p.parse("10");
  assert(cast(NumberExpression)e !is null, "not a number !");
}

@("can parse: \"zzz\"") unittest {
  auto p = new Parser();
  auto e = p.parse(`"zzz"`);
  assert(cast(StringExpression)e !is null, "not a string !");
}

@("can parse: (12)") unittest {
  auto p = new Parser();
  auto e = p.parse(`( 12 )`);
  // writeln(e);
  assert(cast(ListExpression)e !is null, "not a list !");
  // assert(false, "meh");
}

