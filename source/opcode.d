
module opcode;

enum Op {
  Halt=0,
  Const=1,
  Add,
  Sub,
  Mul,
  Div,
  Eq,
  Neq,
  Gt,
  Gte,
  Lt,
  Lte,
  Branch,
  Jump,
  GetGlobal,
  SetGlobal,
  Pop,
  SetLocal,
  GetLocal,
  ScopeExit,
  Call,
}
