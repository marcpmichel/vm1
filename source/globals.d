module globals;
import value;
import errors;
import std.format: format;

struct Var {
    string name;
    Value value;
}

class Globals {

    Var[] vars;
    size_t[string] indices;

    this() {
    }

    Var get(size_t idx) {
        return vars[idx];
    }

    size_t index(string name) {
        if((name in indices) is null) referenceError(format("global var %s does not exists", name));
        auto idx = name in indices;
        return *idx;
    }

    bool exists(string name) {
        return (name in indices) !is null;
    }

    void set(size_t idx, Value value) {
        if(idx >= vars.length) referenceError(format("cannot find var at index %d", idx));
        vars[idx].value = value;
    }

    void define(string name) {
        if(exists(name)) referenceError(format("global var %s already exist", name));
        indices[name] = vars.length;
        vars ~= Var(name, IntValue(0)); // TODO: default value ?
    }

    void define(string name, Value value) {
		define(name); 
        set(index(name), value);
    }

    void addNativeFunction(string name, NativeFn fun, size_t arity) {
        if(exists(name)) referenceError(format("const %s already defined !", name));
        define(name, NativeValue(new Native(name, fun, arity)));
    }
}