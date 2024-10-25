module compiler;
import opcode;
import expressions;
import value;
import errors;
import globals;

class Compiler {

    Globals globals;
    Code code;

    this(Globals globals) {
        this.globals = globals;
    }
    
    Value compile(Expression e) {
        code = new Code("main");
        gen(e);
        emit(Op.Halt);
        return CodeValue(code);
    }

    void compilationError(string errmsg) {
        throw new CompilationError(errmsg);
    }

    void gen(Expression e) {
        switch(e.type) {
            case ExpType.Number:
                emit(Op.Const);
                emit(IntConstId((cast(NumberExpression)e).number));
                break;
            case ExpType.String:
                emit(Op.Const);
                emit(StringConstId((cast(StringExpression)e).str));
                break;
            case ExpType.Bool:
                emit(Op.Const);
                emit(BoolConstId((cast(BoolExpression)e).b));
                break;
            case ExpType.Symbol:
                genSymbol(cast(SymbolExpression)e, null);
                break;
            case ExpType.List:
                genList(e);
                break;
            default:
                break;
        }
    }

    void genList(Expression e) {
        ListExpression listExpr = cast(ListExpression)e;
        // import std.stdio: writeln; writeln(listExpr);
        auto first = listExpr.list[0];
        if(isSymbol(first)) {
            genSymbol(cast(SymbolExpression)first, listExpr);
        }
        else {
            compilationError("first list element is not a symbol");
        }
    }

    ushort currentOffset() {
        return cast(ushort)code.bytes.length;
    }

    void patchAddr(size_t offset, ushort addr) {
        code.bytes[offset] = (addr << 8) & 0xFF;
        code.bytes[offset+1] = (addr) & 0xFF;
        import std.stdio: writeln; writeln("patching addr ",addr," at offet ", offset);
    }

    void genSymbol(SymbolExpression symExpr, ListExpression listExpr) {
        switch(symExpr.symbol) {
            case SymType.Operator: 
                genOpExp(symExpr, listExpr);
            break;
            case SymType.Keyword:
                genKeyword(symExpr.keyword, listExpr);
            break;
            case SymType.Identifier:
                if(listExpr !is null) {
                    // check if it is a function call
                    if(!globals.exists(symExpr.str)) compilationError("reference error : undefined " ~ symExpr.str);
                    Var v = globals.get(globals.index(symExpr.str));
                    if(isNative(v.value)) {
                        // TODO: check arity
                        Native n = v.value.native;
                        if(listExpr.argsCount != n.arity) compilationError("arity error: wrong number of arguments");
                        genCall(listExpr);
                    }
                    else {
                        compilationError("not a native function : " ~ symExpr.str);
                    }
                }
                else {
                    // check if it is a global var or a local val
                    // find local var first
                    if(code.isLocalVar(symExpr.str)) {
                        ubyte idx = cast(ubyte)code.getLocalVarIndex(symExpr.str);
                        emit(Op.GetLocal);
                        emit(idx);
                    }
                    else {
                        if(!globals.exists(symExpr.str)) compilationError("reference error : undefined " ~ symExpr.str);
                        emit(Op.GetGlobal);
                        emit(cast(ubyte)globals.index(symExpr.str));
                    }
                }
            break;
            default:
                import std.format: format;
                compilationError(format("unsupported symbol : %s", symExpr.symbol));
            break;
        }
    }

    void genKeyword(Keyword keyword, ListExpression listExpr) {
        switch(keyword) {
            case Keyword.If:
                checkArgs(listExpr, 2);
                Expression cond = listExpr.list[1];
                Expression thenExpr = listExpr.list[2];
                Expression elseExpr = listExpr.list.length > 3 ? listExpr.list[3] : null;
                genKeywordIf(cond, thenExpr, elseExpr);
            break;
            case Keyword.Var:
                checkArgs(listExpr, 2);
                if(!isIdentifier(listExpr.list[1])) compilationError("expected an identifier");
                auto name = cast(SymbolExpression)listExpr.list[1];
                gen(listExpr.list[2]); // init

                if(inGlobalScope) {
                    globals.define(name.str);
                    emit(Op.SetGlobal);
                    emit(cast(ubyte)globals.index(name.str));
                }
                else {
                    code.addLocalVar(name.str);
                    emit(Op.SetLocal);
                    emit(cast(ubyte)code.getLocalVarIndex(name.str));

                }
            break;
            case Keyword.Set:
                checkArgs(listExpr, 2);
                if(!isIdentifier(listExpr.list[1])) compilationError("expected an identifier");
                auto name = cast(SymbolExpression)listExpr.list[1];
                gen(listExpr.list[2]);
                if(code.isLocalVar(name.str)) {
                    size_t idx = code.getLocalVarIndex(name.str);
                    emit(Op.SetLocal);
                    emit(cast(ubyte)idx);
                }
                else {
                    size_t idx = globals.index(name.str);
                    emit(Op.SetGlobal);
                    emit(cast(ubyte)idx);
                }
            break;
            case Keyword.Begin:
                scopeEnter();
                checkArgs(listExpr, 1);
                foreach(e; listExpr.list[1..$-1]) { // range to avoid the last expr
                    gen(e);
                    bool localDecl =  !inGlobalScope() && isTaggedList(e, Keyword.Var);
                    if(!localDecl) emit(Op.Pop);
                }
                // do not emit a pop for the last expression
                Expression last = listExpr.list[$-1];
                gen(last);
                scopeExit();
            break;
            case Keyword.While:
                scopeEnter();
                checkArgs(listExpr, 2);
                auto condExpr = listExpr.list[1];
                auto bodyExpr = listExpr.list[2];
                genKeywordWhile(condExpr, bodyExpr);
                scopeExit();
            break;
            default:
                compilationError("unknown keyword");
            break;
        }
    }

    void genKeywordIf(Expression cond, Expression thenExp, Expression elseExp) {
        // auto ifexpr = cast(IfExpression)first;
        gen(cond);  // cond
        emit(Op.Branch);

        auto elseBranchAddr = currentOffset();
        emit(0); emit(0); // placeholder offset for branch

        gen(thenExp); // emit "then" code

        emit(Op.Jump);
        auto endBranchAddr = currentOffset();
        emit(0); emit(0); // placeholder offset for jump
         
        patchAddr(elseBranchAddr, currentOffset());

        if(elseExp) gen(elseExp);  // emit "else" code if any

        patchAddr(endBranchAddr, currentOffset());

    }

    void genKeywordWhile(Expression cond, Expression body) {
        auto loopStartAddr = currentOffset();
        gen(cond);
        emit(Op.Branch);

        auto loopEndAddr = currentOffset();
        emit(0); emit(0);
        gen(body);

        emit(Op.Jump);
        emit(0); emit(0);
        patchAddr(currentOffset() - 2, loopStartAddr);
        patchAddr(loopEndAddr, cast(ushort)(currentOffset()+1));
    }

    void genOpExp(SymbolExpression sym, ListExpression listExpr) {
        switch(sym.op) {
            case Op.Add, Op.Sub, Op.Mul, Op.Div:
                checkArgs(listExpr,2);
                genBinaryOp(sym.op, listExpr.list[1], listExpr.list[2]);
            break;
            case Op.Eq, Op.Neq, Op.Gt, Op.Gte, Op.Lt, Op.Lte:
                checkArgs(listExpr,2);
                genCompOp(sym.op, listExpr.list[1], listExpr.list[2]);
            break;
            default:
                compilationError("unknown symbol '" ~ sym.str ~ "'");
            break;
        }
    }

    void genCall(ListExpression listExpr) {
        checkArgs(listExpr, 0);
        gen(listExpr.list[0]); // fetch NativeValue and push onto the stack
        // arguments:
        foreach(argExpr; listExpr.args) { gen(argExpr); }
        emit(Op.Call);
        emit(listExpr.argsCount);
    }

    void genBinaryOp(Op op, Expression a, Expression b) {
        gen(a);
        gen(b);
        emit(cast(ubyte)op);
    }

    void genCompOp(Op op, Expression a, Expression b) {
        gen(a);
        gen(b);
        emit(cast(ubyte)op);
    }

    ubyte IntConstId(int value) {
        foreach(id, c; code.constants) {
            if(c.type != ValType.Int) continue;
            if(c.i == value) return cast(ubyte)id;
        }
        code.constants ~= cast(Value)IntValue(value);
        return cast(ubyte)(code.constants.length-1);
    }

    ubyte StringConstId(string str) {
        foreach(id, c; code.constants) {
            if(c.type != ValType.String) continue;
            if(c.s == str) return cast(ubyte)id;
        }
        code.constants ~= StringValue(str);
        return cast(ubyte)(code.constants.length-1);
    }

    ubyte BoolConstId(bool b) {
        return b ? code.TrueIdx : code.FalseIdx;
    }

    void emit(byte b) {
        code.bytes ~= b;
    }

    void checkArgs(ListExpression listExpr, uint n) {
        if(n == 0) return;
        if(listExpr !is null && listExpr.list.length > n) return;
        throw new CompilationError("wrong number of arguments");
    }

    void scopeEnter() {
        code.scopeLevel++;
    }
    void scopeExit() {
        uint localVarsCount = code.countCurrentScopeLocalVars();
        if(localVarsCount > 0) {
            code.wipeCurrentScopeLocalVars();
            emit(Op.ScopeExit);
            emit(cast(ubyte)localVarsCount);
        }
        code.scopeLevel--;
    }
    bool inGlobalScope() {
        return code.scopeLevel == 1 && code.name == "main";
    }
}