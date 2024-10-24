module tokens;


enum Tok { Error, EoF, EoL, Blank, 
  Number, String, Identifier, 
  LParen, RParen, 
  Add, Sub, Mul, Div, 
  Eq, Neq, Gt, Gte, Lt, Lte, 
  Not
}

struct Token {
  Tok type;
  string s;
}
