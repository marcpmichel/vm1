import std.stdio;
import opcode;
import value;
import vm;
import parser;
import compiler;
import expressions;
import errors;
import decompiler;
import globals;

bool error;

int main() {

	Globals globals = new Globals;

	auto vm = new VM(globals); // initialize the vm to set the default constants and functions

	string program = `
		(if (= (square 3) 9)
			(var x 100)
			(sum x 1))
	`;
	// string program = "(< 2 12)";
	// string program = `(+ 12 (/ 6 1))"`;
	// string program = `(+ "Hello " "World")"`;
	// string program = `(if (== 3 3) (* 2 2) (* 9 9))`;
	writeln("program:\n", program);

	writeln("### parsing...");
	auto parser = new Parser();
	Expression ast;
	try {
		ast = parser.parse(program);
		writeln("AST: " , ast);
	}
	catch(LexicalError e) {
		writeln(e.message);
		error = true;
	}
	catch(ParseError e) {
		writeln(e.message);
		error = true;
	}
	if(error) return 1;

	writeln("### compiling...");
	auto compiler = new Compiler(globals);
	Value codevalue;
	try {
		codevalue = compiler.compile(ast);
		writeln("constants: ", compiler.code.constants);
		writeln("globals:", globals.vars);
		writeln("bytes: ", compiler.code.bytes);
	}
	catch(CompilationError e) {
		writeln(e.message);
		error = true;
	}
	catch(RuntimeError e) {
		writeln(e.message);
		error = true;
	}
	if(error) return 1;

	auto decompiler = new Decompiler(globals);
	decompiler.decompile(codevalue.code);

	writeln("### running...");
	try {
		Value res = vm.exec(codevalue.code);
		print(res);
	}
	catch(RuntimeError e) {
		writeln("RuntimeError : ", e.message);
		error = true;
	}
	if(error) return 1;

	return 0;
}

