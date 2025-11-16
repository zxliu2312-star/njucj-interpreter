package cjcj.executor
/*
import cjcj.executor.Value
import cjcj.executor.ErrorCode
import cjcj.executor.CjcjRuntimeErrorWithLocation

import cjcj.visitor.*
import cjcj.scanner.TokenKind

import std.math.pow
import std.convert.*
import std.collection.ArrayList

public class BinaryOps {

    public static func eval(kind: TokenKind, left: Value, right: Value, node: Node): Value {
        match(kind) {
            case TokenKind.ADD => return add(left, right, node)
            case TokenKind.SUB => return sub(left, right, node)
            case TokenKind.MUL => return mul(left, right, node)
            case TokenKind.DIV => return div(left, right, node)
            case TokenKind.MOD => return mod(left, right, node)
            case TokenKind.EXP => return exp(left, right, node)

            case TokenKind.LT  => return cmpLT(left, right, node)
            case TokenKind.LE  => return cmpLE(left, right, node)
            case TokenKind.GT  => return cmpGT(left, right, node)
            case TokenKind.GE  => return cmpGE(left, right, node)

            case TokenKind.EQUAL  => return eq(left, right, node)
            case TokenKind.NOTEQ  => return ne(left, right, node)

            case _ =>
                throw Lab1TodoException("Unsupported binary operator: ${kind}")
        }
    }

    // ------------------ 以下全部是静态函数 ----------------------
        static func add(a: Value, b: Value, node: Node): Value {
            let tuple = (a, b)
            match (tuple) {
                case (VInteger(x), VInteger(y)) =>
                    try { return Value.from(x + y) }
                    catch (_: OverflowException) {
                        throw CjcjRuntimeErrorWithLocation(
                            ErrorCode.ADD_OVERFLOW,
                            "overflow add",
                            node
                        )
                    }

                case (VString(s1), VString(s2)) =>
                    return Value.from(s1 + s2)

                case _ =>
                    throw CjcjRuntimeErrorWithLocation(
                        ErrorCode.ADD_TYPE_MISMATCH,
                        "invalid +",
                        node
                    )
            }
        }


    static func sub(a: Value, b: Value, node: Node): Value {
        let tuple = (a, b)
        match(tuple) {
            case (VInteger(x), VInteger(y)) =>
                try { return Value.from(x - y) }
                catch (_: OverflowException) {
                    throw CjcjRuntimeErrorWithLocation(
                        ErrorCode.SUB_OVERFLOW,
                        "overflow sub",
                        node
                    )
                }

            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.SUB_TYPE_MISMATCH,
                    "invalid -",
                    node
                )
        }
    }

    static func mul(a: Value, b: Value, node: Node): Value {
        let tuple = (a, b)
        match(tuple) {
            case (VInteger(x), VInteger(y)) =>
                try { return Value.from(x * y) }
                catch (_: OverflowException) {
                    throw CjcjRuntimeErrorWithLocation(
                        ErrorCode.MUL_OVERFLOW,
                        "overflow mul",
                        node
                    )
                }

            case (VString(s), VInteger(n)) =>
                if (n < 0) {
                    throw CjcjRuntimeErrorWithLocation(
                        ErrorCode.MUL_TYPE_MISMATCH,
                        "string*negative",
                        node
                    )
                }
                var res = ""
                for (i in 0 .. n) {
                    res = res + s
                }
                return Value.from(res)

            case (VInteger(n), VString(s)) =>
                if (n < 0) {
                    throw CjcjRuntimeErrorWithLocation(
                        ErrorCode.MUL_TYPE_MISMATCH,
                        "string*negative",
                        node
                    )
                }
                var res = ""
                for (i in 0 .. n) {
                    res = res + s
                }
                return Value.from(res)

            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.MUL_TYPE_MISMATCH,
                    "invalid *",
                    node
                )
        }
    }

    static func div(a: Value, b: Value, node: Node): Value {
        let tuple = (a, b)
        match(tuple) {
            case (VInteger(x), VInteger(y)) =>
                if (y == 0) {
                    throw CjcjRuntimeErrorWithLocation(
                        ErrorCode.DIV_BY_ZERO,
                        "div by zero",
                        node
                    )
                }
                return Value.from(x / y)

            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.DIV_TYPE_MISMATCH,
                    "invalid /",
                    node
                )
        }
    }

    static func mod(a: Value, b: Value, node: Node): Value {
        let tuple = (a, b)
        match(tuple) {
            case (VInteger(x), VInteger(y)) =>
                if (y == 0) {
                    throw CjcjRuntimeErrorWithLocation(
                        ErrorCode.MOD_BY_ZERO,
                        "mod by zero",
                        node
                    )
                }
                return Value.from(x % y)

            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.MOD_TYPE_MISMATCH,
                    "invalid %",
                    node
                )
        }
    }

    static func exp(a: Value, b: Value, node: Node): Value {
        let tuple = (a, b)
        match(tuple) {
            case (VInteger(x), VInteger(y)) =>
                if (y < 0) {
                    throw CjcjRuntimeErrorWithLocation(
                        ErrorCode.EXP_NEGATIVE_POWER,
                        "negative exponent",
                        node
                    )
                }

                try {
                    let r = pow(Float32(x), Float32(y))
                    return Value.from(Int64(r))
                }
                catch (_: OverflowException) {
                    throw CjcjRuntimeErrorWithLocation(
                        ErrorCode.EXP_OVERFLOW,
                        "overflow exponent",
                        node
                    )
                }

            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.EXP_TYPE_MISMATCH,
                    "invalid **",
                    node
                )
        }
    }

    // ---------- 比较 ----------
    static func cmpLT(a: Value, b: Value, node: Node): Value {
        let x = (a, b)
        match(x) {
            case (VInteger(i1), VInteger(i2)) =>
                return Value.from(i1 < i2)
            case (VString(s1), VString(s2)) =>
                return Value.from(s1 < s2)
            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.CMP_TYPE_MISMATCH,
                    "invalid < compare",
                    node
                )
        }
    }

    static func cmpLE(a: Value, b: Value, node: Node): Value {
        let x = (a, b)
        match(x) {
            case (VInteger(i1), VInteger(i2)) =>
                return Value.from(i1 <= i2)
            case (VString(s1), VString(s2)) =>
                return Value.from(s1 <= s2)
            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.CMP_TYPE_MISMATCH,
                    "invalid <= compare",
                    node
                )
        }
    }

    static func cmpGT(a: Value, b: Value, node: Node): Value {
        let x = (a, b)
        match(x) {
            case (VInteger(i1), VInteger(i2)) =>
                return Value.from(i1 > i2)
            case (VString(s1), VString(s2)) =>
                return Value.from(s1 > s2)
            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.CMP_TYPE_MISMATCH,
                    "invalid > compare",
                    node
                )
        }
    }

    static func cmpGE(a: Value, b: Value, node: Node): Value {
        let x = (a, b)
        match(x) {
            case (VInteger(i1), VInteger(i2)) =>
                return Value.from(i1 >= i2)
            case (VString(s1), VString(s2)) =>
                return Value.from(s1 >= s2)
            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.CMP_TYPE_MISMATCH,
                    "invalid >= compare",
                    node
                )
        }
    }

    // ---------- ==
    static func eq(a: Value, b: Value, node: Node): Value {
        let tuple = (a, b)
        match(tuple) {
            case (VInteger(x), VInteger(y)) => return Value.from(x == y)
            case (VString(s1), VString(s2)) => return Value.from(s1 == s2)
            case (VBoolean(x), VBoolean(y)) => return Value.from(x == y)
            case (VUnit, VUnit) => return Value.from(true)

            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.EQ_TYPE_MISMATCH,
                    "invalid ==",
                    node
                )
        }
    }

    static func ne(a: Value, b: Value, node: Node): Value {
        let tuple = (a, b)
        match(tuple) {
            case (VInteger(x), VInteger(y)) => return Value.from(x != y)
            case (VString(s1), VString(s2)) => return Value.from(s1 != s2)
            case (VBoolean(x), VBoolean(y)) => return Value.from(x != y)
            case (VUnit, VUnit) => return Value.from(false)

            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.NEQ_TYPE_MISMATCH,
                    "invalid !=",
                    node
                )
        }
    }
}
*/