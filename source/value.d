module value;
import errors;

enum ValType { Error, Bool, Int, Float, String, Code }

struct LocalVar {
    string name;
    size_t scopeLevel;
}

class Code {
  enum FalseIdx = 0;
  enum TrueIdx = 1;
  string name;
  ubyte[] bytes;
  Value[] constants = [BoolValue(false), BoolValue(true)];
  size_t scopeLevel;
  LocalVar[] locals;

  this(string name) {
    this.name = name;
  }

  uint wipeCurrentScopeLocalVars() {
    import std.algorithm.searching: count;
    import std.algorithm.mutation: remove;
    uint nb = cast(uint)locals.count!(v => v.scopeLevel == this.scopeLevel);
    locals.remove!(v => v.scopeLevel == this.scopeLevel);
    return nb;
  }
  void addLocalVar(string varname) {
    locals  ~= LocalVar(varname, scopeLevel);
  }
  size_t isLocalVar(string varname) {
    import std.algorithm.searching: canFind;
    return locals.canFind!(v => v.name == varname);
  }
  size_t getLocalVarIndex(string varname) {
    import std.algorithm.searching: countUntil;
    import std.format: format;
    size_t idx = locals.countUntil!(v => v.name == varname);
    if(idx < locals.length) return idx;
    referenceError(format("cannot find local var '%s'", varname));
    assert(false);
  }

}

struct Value {
  ValType type;
  union {
    bool b;
    int i;
    float f;
    string s;
    Code code;
  }
}

int asInt(Value v) { return v.i; }
float asFloat(Value v) { return v.f; }
string asString(Value v) { return v.s; }
bool asBool(Value v) { return v.b; }
Code asCode(Value v) { return v.code; }

bool isInt(Value v) { return v.type == ValType.Int; }
bool isFloat(Value v) { return v.type == ValType.Float; }
bool isString(Value v) { return v.type == ValType.String; }
bool isCode(Value v) { return v.type == ValType.Code; }
bool isBool(Value v) { return v.type == ValType.Bool; }

Value IntValue(int i) {
  return Value(ValType.Int, i:i);
}
Value FloatValue(float f) {
  return Value(ValType.Float, f:f);
}
Value StringValue(string s) {
  return Value(ValType.String, s:s);
}
Value CodeValue(Code code) {
  return Value(ValType.Code, code: code);
}
Value BoolValue(bool b) {
  return Value(ValType.Bool, b: b);
}

void print(Value v) {
  import std.stdio: write, writeln;
	write(v.type, ":");
	switch(v.type) {
		case ValType.Int: writeln(v.i); break;
		case ValType.Bool: writeln(v.b); break;
		case ValType.Float: writeln(v.f); break;
		case ValType.String: writeln(v.s); break;
		default: writeln("cannot print value : unknown type"); break;
	}
}

string to_s(Value v) {
  import std.format: format;
	switch(v.type) {
		case ValType.Int:    return "%s: %s".format(v.type, v.i); break;
		case ValType.Bool:   return "%s: %s".format(v.type, v.b); break;
		case ValType.Float:  return "%s: %s".format(v.type, v.f); break;
		case ValType.String: return "%s: %s".format(v.type, v.s); break;
		default: return "???"; break;
	}
}