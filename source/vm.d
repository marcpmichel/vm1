import value;
import opcode;
import errors;
import std.format: format;
import globals;

class VM {
	Code code;
	ubyte* ip;

	Value[1024] stack;
	Value* sp;
	Globals globals;

	Value* bp; // base pointer

	this(Globals globals) {
		this.globals = globals;
		this.addDefaultGlobals();
		this.addNativeFunctions();
	}

	void runtimeError(string errmsg) {
		throw new RuntimeError(errmsg);
	}

	Value exec(Code codeObj) {
		code = codeObj;

		ip=&(code.bytes[0]);
		sp=&stack[0];

		bp=sp;

		return eval();
	}

	ubyte read_byte() {
		return *ip++;
	}

	void push(Value constant) {
		if(sp > &stack[$-1]) runtimeError("stack overflow");
		*sp = constant;
		sp++;
	}

	Value pop() {
		if(sp < &stack[0]) runtimeError("stack underflow");
		sp--;
		return *sp;
	}

	void popCount(uint count) {
		if(stack.length < count) runtimeError("stack underflow");
		sp -= count;
	}

	Value peek(size_t offset) {
		return *(sp - 1 - offset);
	}

	auto binOp(string op)() {
			return mixin("push(IntValue(asInt(pop())"~op~"asInt(pop())))");
	}

	Value eval() {
		for(;;) {
			ubyte opcode = read_byte();
			switch(opcode) {
				case Op.Halt: return pop();

				case Op.Pop: pop(); break;

				case Op.ScopeExit:
					auto count = read_byte();
					// pop the top of the stack, pop the localvariables, then push back the top of the stack
					// Value cur = pop();
					// foreach(i; 0..count) { pop(); }
					// push(cur);

					// or... optimize by copying the top of the stack below and pop the same number
					*(sp - 1 - count) = peek(0); // move the top of the stack below
					popCount(count);
				break;

				case Op.Const:
					Value constant = code.constants[read_byte()];
					push(constant);
				break;

				case Op.GetGlobal:
					Var glob = globals.get(read_byte());
					push(glob.value);
				break;

				case Op.SetGlobal:
					size_t idx = read_byte();
					Value val = peek(0);
					globals.set(idx, val);
				break;

				case Op.GetLocal:
					size_t idx = read_byte();
					push(bp[idx]);
				break;

				case Op.SetLocal:
					size_t idx = read_byte();
					Value val = peek(0);
					bp[idx] = val;
				break;

				case Op.Add:
					auto b = pop();
					auto a = pop();
					// binOp!"+";
					if(isString(a) && isString(b)) {
						push(StringValue(asString(a) ~ asString(b)));
						continue;
					}
					if (isInt(a) && isInt(b)) {
						push(IntValue(asInt(a) + asInt(b)));
						continue;
					}

					runtimeError("Invalid operands (opAdd)");
				break;

				case Op.Sub:
					binOp!"-";
				break;

				case Op.Mul:
					// binOp!"*";
					auto b = pop();
					auto a = pop();
					if(isInt(a) && isInt(b)) {
						push(IntValue(asInt(a) * asInt(b)));
						continue;
					}
					runtimeError("invalid operands (opMul)");
				break;

				case Op.Div:
					auto b = pop(); 
					auto a = pop();
					if(isInt(a) && isInt(b)) {
						if(asInt(b) == 0) runtimeError("Division by zero !");
						push(IntValue(asInt(a) / asInt(b)));
						continue;
					}
					runtimeError("Invalid operands (opDiv)");
					// binOp!"/";
				break;

				case Op.Jump:
					read_byte();
					ushort addr = read_byte()*256 + read_byte();
					ip = code.bytes.ptr + addr;
				break;

				case Op.Branch:
					auto z = pop();
					if(isBool(z)) {
						ushort addr = read_byte()*256 + read_byte();
						if(asBool(z) == false) {
							ip = code.bytes.ptr + addr;
						}
					}
					else {
						runtimeError("invalid value for Branch " ~ to_s(z));
					}
				break;

				case Op.Eq, Op.Neq, Op.Gt, Op.Gte, Op.Lt, Op.Lte:
					auto b = pop();
					auto a = pop();
					if(isInt(a) && isInt(b)) {
						bool res;
						switch(opcode) {
							case Op.Eq:  res = asInt(a) == asInt(b); break;
							case Op.Neq: res = asInt(a) != asInt(b); break;
							case Op.Gt:  res = asInt(a) >  asInt(b); break;
							case Op.Gte: res = asInt(a) >= asInt(b); break;
							case Op.Lt:  res = asInt(a) <  asInt(b); break;
							case Op.Lte: res = asInt(a) <= asInt(b); break; 
							default: assert(0);
						}
						push(BoolValue(res));
						continue;
					}
					else {
						runtimeError("invalid operands (cmp)");
					}
				break;

				case Op.Call:
					auto argsCount = read_byte();
					Value fnValue = peek(argsCount);
					if(isNative(fnValue)) {
						Native nat = asNative(fnValue);
						nat.fun();
						auto res = pop();
						popCount(argsCount + 1 /* fn */ );
						push(res);
					}
					else {
						runtimeError("user-defined function not yet supported");
					}
				break;

				default: 
					runtimeError(format("invalid opcode %s", opcode));
				break;
			}
		}
	}
	
	string[] traces;
	void trace(string s) {
		traces ~= s;
	}

	void nativeSquare() {
		auto x = asInt(peek(0)); 
		push(IntValue(x*x));
	}


	void addDefaultGlobals() {
		globals.define("VERSION", IntValue(1));
	}

	void addNativeFunctions() {
		globals.addNativeFunction( "square", (){ auto x=asInt(peek(0)); push(IntValue(x*x)); }, 1);
		globals.addNativeFunction( "sum", (){ 
			auto a=asInt(peek(0)); 
			auto b=asInt(peek(1)); 
			push(IntValue(a+b)); 
		}, 2);
	}

}

/*
@("multiplying numbers") unittest {
	ubyte[] code = [ Op.Const, 0, Op.Const, 1, Op.Mul, Op.Halt ];
	auto vm = new VM();
	vm.constants[0] = IntValue(4);
	vm.constants[1] = IntValue(3);
	auto res = vm.exec(code);
	assert(res.type == ValType.Int, "expected an Int value");
	assert(res.i == 12, "not 12 !");
}

@("string concatenation") unittest {
		ubyte[] code = [ Op.Const, 0, Op.Const, 1, Op.Add, Op.Halt ];
		auto vm = new VM();
		vm.constants[0] = StringValue("Hello, ");
		vm.constants[1] = StringValue("World !");
		auto res = vm.exec(code);
		assert(res.type == ValType.String && res.s == "Hello, World !", "not hello world");
}
*/

