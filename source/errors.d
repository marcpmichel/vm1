module errors;

class CompilationError : Error { this(string errmsg) { super(errmsg); }}

class LexicalError : Error {this(string errmsg) { super(errmsg); }}

class ParseError: Error {this(string errmsg) { super(errmsg); }}

class ReferenceError: Error {this(string errmsg) { super(errmsg); }}

class RuntimeError : Error {this(string errmsg) { super(errmsg); }}

class DecompileError: Error {this(string errmsg) { super(errmsg); }}

void referenceError(string errmsg) {
    throw new ReferenceError(errmsg);
}