
module expressions;
import tokens;
import opcode;

enum ExpType { Empty, Number, String, Bool, Symbol, List }

class Expression {
  ExpType type = ExpType.Empty;
}

class EndExpression: Expression {
}

class NumberExpression : Expression {
  int number;
  this(string str) {
    import std.conv : to;
    type = ExpType.Number;
    number = str.to!int;
  }
}
class BoolExpression : Expression {
  bool b;
  this(string str) {
    type = ExpType.Bool;
    b = (str == "true" ? true : false);
  }
}
class StringExpression : Expression {
  string str;
  this(string str) { type = ExpType.String; this.str = str; }
}

enum SymType { Error, Identifier, Operator, Keyword }
enum Keyword { Unknown, If, Var, Set, Begin }
Keyword[string] keywords = [
  "if": Keyword.If,
  "var": Keyword.Var,
  "set": Keyword.Set,
  "begin": Keyword.Begin
];

class SymbolExpression: Expression {
  string str;
  Op op;
  SymType symbol;
  Keyword keyword;

  this(string str) { 
    type = ExpType.Symbol;
    this.str = str;
    Keyword* kw = str in keywords;
    if(kw !is null) { symbol = SymType.Keyword, keyword = *kw; }
    else symbol = SymType.Identifier;
  }
  this(Tok tt) { 
    type = ExpType.Symbol;
    symbol = SymType.Operator;
    switch(tt) { 
      case Tok.Add: op = Op.Add; break;
      case Tok.Sub: op = Op.Sub; break;
      case Tok.Mul: op = Op.Mul; break;
      case Tok.Div: op = Op.Div; break;
      case Tok.Eq:  op = Op.Eq;  break;
      case Tok.Neq: op = Op.Neq; break;
      case Tok.Gt:  op = Op.Gt;  break;
      case Tok.Gte: op = Op.Gte; break;
      case Tok.Lt:  op = Op.Lt;  break;
      case Tok.Lte: op = Op.Lte; break;

      default: this.str = "?"; symbol = SymType.Error; break;
    }
  }
  override string toString() {
    import std.format: format;
    if(symbol == SymType.Keyword) return format("Symbol(Keyword:%s)", keyword);
    if(symbol == SymType.Operator) return format("Symbol(Op:%s)", op);
    if(symbol == SymType.Identifier) return format("Symbol(Identifier:%s)", str);
    return format("Symbol: Error! %s", str);
  }
}
class ListExpression: Expression {
  Expression[] list;
  this() {
    type = ExpType.List;
  }
  void add(Expression e) {
    this.list ~= e;
  }
  override string toString() {
    import std.format: format;
    return format("List(len:%d) => %s", list.length, list);
  }
}

bool isSymbol(Expression e) {
  SymbolExpression s = cast(SymbolExpression)e;
  return s !is null;
}

bool isIdentifier(Expression e) {
    SymbolExpression s = cast(SymbolExpression)e;
    return (s !is null) && s.symbol == SymType.Identifier;
}

bool isKeyword(Expression e, Keyword kw) {
    SymbolExpression s = cast(SymbolExpression)e;
    return (s !is null) && s.symbol == SymType.Keyword && s.keyword == kw;
}

bool isTaggedList(Expression e, Keyword kw) {
  auto listExpr = cast(ListExpression)e;
  if(listExpr is null) return false;
  if(listExpr.list.length == 0) return false;
  auto tag = listExpr.list[0];
  return isKeyword(tag, kw);
}