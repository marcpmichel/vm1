module decompiler;
import opcode;
import value; 
import std.stdio: write, writeln;
import std.format: format;
import errors;
import globals;

class Decompiler {
    ulong ip;
    string[] lines;
    Globals globals;

    this(Globals globals) {
        this.globals = globals;
    }

    void decompileError(string errmsg) {
        throw new DecompileError(errmsg);
    }

    void decompile(Code code) {
        writeln("========== dissassembly of ", code.name ," ============");
        ulong offset;
        while(offset < code.bytes.length) {
            offset = decompileInstruction(code, offset);
            writeln();
        }
    }

    ulong decompileInstruction(Code code, ulong offset) {
        write(format("%04X", offset), "    ");
        Op opcode = cast(Op)code.bytes[offset];
        switch(opcode) {
            case Op.Halt: return decompileSingle(code, offset, opcode);
            case Op.Const: return decompileConst(code, offset, opcode);
            case Op.Add, Op.Sub, Op.Mul, Op.Div: return decompileSingle(code, offset, opcode);
            case Op.Eq, Op.Neq, Op.Gt, Op.Gte, Op.Lt, Op.Lte: return decompileSingle(code, offset, opcode);
            case Op.Jump, Op.Branch: return decompileJump(code, offset, opcode);
            case Op.GetGlobal, Op.SetGlobal: return decompileGlobal(code, offset, opcode);
            case Op.Pop: return decompileSingle(code, offset, opcode);
            case Op.ScopeExit: return decompileWord(code, offset, opcode);
            case Op.SetLocal: return decompileLocal(code, offset, opcode);
            case Op.GetLocal: return decompileLocal(code, offset, opcode);
            default: decompileError(format("cannot decompile %s", opcode));
        }
        assert(false,"impossible");
    }

    ulong decompileSingle(Code code, ulong offset, Op opcode) {
        write(format("%02X       ", code.bytes[offset]));
        write(format("%-10s", opcode));
        return offset+1;
    }

    ulong decompileConst(Code code, ulong offset, Op opcode) {
        ubyte arg = code.bytes[offset+1];
        write(format("%02X %02X    ", code.bytes[offset], arg));
        auto val = code.constants[arg];
        write(format("%-10s %02X (%s)", opcode, arg, val.to_s));
        return offset+2;
    }

    ulong decompileWord(Code code, ulong offset, Op opcode) {
        ubyte arg = code.bytes[offset+1];
        write(format("%02X %02X    ", code.bytes[offset], arg));
        auto val = code.constants[arg];
        write(format("%-10s %02X", opcode, arg));
        return offset+2;
    }

    ulong decompileGlobal(Code code, ulong offset, Op opcode) {
        ubyte arg = code.bytes[offset+1];
        write(format("%02X %02X    ", code.bytes[offset], arg));
        auto glob = globals.get(arg);
        write(format("%-10s %02X (%s)", opcode, arg, glob.name));
        return offset+2;
    }

    ulong decompileLocal(Code code, ulong offset, Op opcode) {
        ubyte idx = code.bytes[offset+1];
        write(format("%02X %02X    ", code.bytes[offset], idx));
        auto localVar = code.locals[idx];
        write(format("%-10s %02X (%s)", opcode, idx, localVar.name));
        return offset+2;
    }

    ulong decompileJump(Code code, ulong offset, Op opcode) {
        write(format("%02X %02X %02X ", code.bytes[offset], code.bytes[offset+1], code.bytes[offset+2]));
        ushort addr = cast(ushort)(code.bytes[offset+1] << 8) + cast(ushort)code.bytes[offset+2];
        write(format("%-10s %04X", opcode, addr));
        return offset+3;
    }
}