#pragma once

#include <string>
#include <memory>


using NumericType = int;

class Value;

using ValuePtr = const std::shared_ptr<const Value>;

using UnaryFunction = std::function<ValuePtr (ValuePtr)>;



class Value {
public:
    virtual std::string serialize() const = 0;
    virtual NumericType getNumber() const = 0;
    virtual bool getBoolean() const = 0;
    virtual ValuePtr getFirst() const = 0;
    virtual ValuePtr getSecond() const = 0;
    virtual ValuePtr call(ValuePtr) const = 0;
};

class Number : public Value {
public:
    Number(NumericType value) : value { value } {
    }

    virtual std::string serialize() const {
        return std::to_string(value);
    }

    virtual NumericType getNumber() const {
        return value;
    }

    virtual bool getBoolean() const {
        throw std::string { "Can not get the boolean value of a number" };
    }

    virtual ValuePtr getFirst() const {
        throw std::string { "Can not get the first member a number" };
    }

    virtual ValuePtr getSecond() const {
        throw std::string { "Can not get the second member a number" };
    }

    virtual ValuePtr call(ValuePtr argument) const {
        throw std::string { "Can not call a number" };
    }

private:
    NumericType value;
};

class Boolean : public Value {
public:
    Boolean(bool value) : value { value } {
    }

    virtual std::string serialize() const {
        return value ? "true" : "false";
    }

    virtual NumericType getNumber() const {
        throw std::string { "Can not get the numeric value of a boolean" };
    }

    virtual bool getBoolean() const {
        return value;
    }

    virtual ValuePtr getFirst() const {
        throw std::string { "Can not get the first member a number" };
    }

    virtual ValuePtr getSecond() const {
        throw std::string { "Can not get the second member a number" };
    }

    virtual ValuePtr call(ValuePtr argument) const {
        throw std::string { "Can not call a boolean" };
    }

private:
    bool value;
};

class Pair : public Value {
public:
    Pair(ValuePtr first, ValuePtr second) : first { first }, second { second } {
    }

    virtual std::string serialize() const {
        return std::string { "(pair " } + first->serialize() + " " + second->serialize() + ")";
    }

    virtual NumericType getNumber() const {
        throw std::string { "Can not get the numeric value of a pair" };
    }

    virtual bool getBoolean() const {
        throw std::string { "Can not get the boolean value of a pair" };
    }

    virtual ValuePtr getFirst() const {
        return first;
    }

    virtual ValuePtr getSecond() const {
        return second;
    }

    virtual ValuePtr call(ValuePtr argument) const {
        throw std::string { "Can not call a pair" };
    }

private:
    ValuePtr first;
    ValuePtr second;
};

class Function : public Value {
public:
    Function(UnaryFunction function) : function { function } {
    }

    virtual std::string serialize() const {
        return "function";
    }

    virtual NumericType getNumber() const {
        throw std::string { "Can not get numeric value of a function" };
    }

    virtual bool getBoolean() const {
        throw std::string { "Can not get the boolean value of a function" };
    }

    virtual ValuePtr getFirst() const {
        throw std::string { "Can not get the first member a function" };
    }

    virtual ValuePtr getSecond() const {
        throw std::string { "Can not get the second member a function" };
    }

    virtual ValuePtr call(ValuePtr argument) const {
        return function(argument);
    }

private:
    UnaryFunction function;
};



ValuePtr makeValue(NumericType value) {
    return std::make_shared<Number>(value);
}

ValuePtr makeValue(bool value) {
    return std::make_shared<Boolean>(value);
}

ValuePtr makeValue(ValuePtr first, ValuePtr second) {
    return std::make_shared<Pair>(first, second);
}

ValuePtr makeValue(UnaryFunction function) {
    return std::make_shared<Function>(function);
}