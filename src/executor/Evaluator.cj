package cjcj.executor

import cjcj.visitor.*
import cjcj.scanner.TokenKind
import cjcj.scanner.Token
import std.convert.*
import std.collection.HashMap
import std.collection.ArrayList
import std.math.*


class Lab1TodoException <: Exception {
    public init(message: String) {
        super("Lab 1 TODO: " + message)
    }
}

// Control-flow signals as exceptions to simplify propagation.
class BreakSignal <: Exception {}
class ContinueSignal <: Exception {}

// VarEntry stores info for a single variable in one static scope.
public class VarEntry {
    public let mutable: Bool
    public var initialized: Bool
    public var value: Value
    public let decl: ?Decl
    public var annotatedType: ?Type

    init(mutable: Bool, initialized: Bool, value: Value, decl: ?Decl, annotatedType: ?Type) {
        this.mutable = mutable
        this.initialized = initialized
        this.value = value
        this.decl = decl
        this.annotatedType = annotatedType
    }
}

public open class Evaluator <: Visitor<Value> {
    // How do you get and set the context when executing an expression?
    // You might need to add some member variables to do this.
    //
    private var envStack: ArrayList<HashMap<String, VarEntry>> = ArrayList()
    private var loopDepth_: Int64 = 0

    init() {
        // 初始化时创建一个全局作用域
        envStack.add(HashMap<String, VarEntry>())
    }

    private func pushScope(): Unit {
        envStack.add(HashMap<String, VarEntry>())
    }

    private func popScope(): Unit {
        if (envStack.size > 1) {
            envStack.remove(at: envStack.size - 1)
        }
    }

    private func currentScope(): HashMap<String, VarEntry> {
        envStack[envStack.size - 1]
    }

    private func defineVar(
        name: String,
        value: Value,
        mutable: Bool,
        decl: ?Decl,
        initialized: Bool,
        annotatedType: ?Type
    ): Unit {
        let entry = VarEntry(
            mutable,
            initialized,
            value,
            decl,
            annotatedType
        )
        currentScope()[name] = entry
    }

    private func lookupVar(name: String): ?VarEntry {
        // 从当前作用域向上查找变量
        var i = envStack.size - 1
        while (i >= 0) {
            let scope = envStack[i]
            if (scope.contains(name)) {
                return Some(scope[name])
            }
            i -= 1
        }
        return None
    }

    private func sameType(a: Value, b: Value): Bool {
        let tuple = (a, b)
        match (tuple) {
            case (VInteger(_), VInteger(_)) => true
            case (VString(_),  VString(_))  => true
            case (VBoolean(_), VBoolean(_)) => true
            case (VUnit,       VUnit)       => true
            case _ => false
        }
    }

    // ---------------- visitor implementations ----------------
    public override func visit(prog: Program): Value {
        // 只需要执行 main() 的 block
        var mainDecl: ?MainDecl = None

        for (d in prog.decls.iterator()) {
            match (d) {
                case m: MainDecl =>
                    mainDecl = Some(m)
                case vd: VarDecl =>
                    // 顶层 var 定义
                    vd.traverse(this)
                case _ => ()
            }
        }

        match (mainDecl) {
            case Some(m) => return m.traverse(this)
            case None =>
            throw CjcjRuntimeErrorWithLocation(
                ErrorCode.MISSING_MAIN,
                "main() not found",
                prog
            )
        }
    }

    // 双目运算
    public override func visit(expr: BinaryExpr): Value {

        let left = expr.left.traverse(this)

        // 先处理短路逻辑（特殊）
        match (expr.oper.kind) {
            case TokenKind.AND => return evalLogicalAnd(left, expr)
            case TokenKind.OR  => return evalLogicalOr(left, expr)
            case _ => ()
        }

        let right = expr.right.traverse(this)

        match (expr.oper.kind) {

            // 数学运算
            case TokenKind.ADD |
                TokenKind.SUB |
                TokenKind.MUL |
                TokenKind.DIV |
                TokenKind.MOD |
                TokenKind.EXP =>
                return evalMath(expr.oper.kind, left, right, expr)

            // 比较运算
            case TokenKind.LT |
                TokenKind.LE |
                TokenKind.GT |
                TokenKind.GE =>
                return evalCompare(expr.oper.kind, left, right, expr)

            // 相等与不等
            case TokenKind.EQUAL |
                TokenKind.NOTEQ =>
                return evalEq(expr.oper.kind, left, right, expr)

            // 未实现
            case _ =>
                throw Lab1TodoException("Unsupported binary operator `${expr.oper.kind}`")
        }
    }

    // 单目运算
    public override func visit(expr: UnaryExpr): Value {
        let rightVal = expr.right.traverse(this)
        let kind = expr.oper.kind

        match(kind) {
            // ------------ 取负运算 ------------
            case TokenKind.SUB =>
                match (rightVal) {
                    case VInteger(x) =>
                        try {
                            return Value.from(-x)
                        }
                        catch (_: OverflowException) {
                            throw CjcjRuntimeErrorWithLocation(
                                ErrorCode.NEG_OVERFLOW,
                                "overflow when negating",
                                expr
                            )
                        }

                    case _ =>
                        throw CjcjRuntimeErrorWithLocation(
                            ErrorCode.NEG_TYPE_MISMATCH,
                            "unary - requires Int64",
                            expr
                        )
                }

            // ------------ 逻辑非运算 ------------
            case TokenKind.NOT =>
                match (rightVal) {
                    case VBoolean(b) =>
                        return Value.from(!b)

                    case _ =>
                        throw CjcjRuntimeErrorWithLocation(
                            ErrorCode.NOT_TYPE_MISMATCH,
                            "unary ! requires Bool",
                            expr
                        )
                }

            // ------------ 未实现的运算符 ------------
            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.UNSUPPORTED,
                    "unsupported unary operator `${expr.oper.kind}`",
                    expr
                )
        }
    }

    // ()类型
    public override func visit(par: ParenExpr): Value {
        par.parenthesizedExpr.traverse(this)
    }

    // 字面量
    public override func visit(lit: LitConstExpr): Value {
        let tok = lit.literal

        match (tok.kind) {

            // ---------- 整数 ----------
            case TokenKind.INTEGER_LITERAL =>
                return Value.from(Int64.parse(tok.value))

            // ---------- 字符串 ----------
            case TokenKind.STRING_LITERAL =>
                // tok.value 已经不包含外侧引号
                return Value.from(tok.value)

            // ---------- 布尔 ----------
            case TokenKind.BOOL_LITERAL =>
                if (tok.value == "true") {
                    return Value.from(true)
                } else {
                    return Value.from(false)
                }

            // ---------- 单元 literal ----------
            case TokenKind.UNIT_LITERAL =>
                return Value.VUnit

            // ---------- 未支持的 literal ----------
            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.LITERAL_TYPE_MISMATCH,
                    "unsupported literal: ${tok.value}",
                    lit
                )
        }
    }

    // 赋值语句
    public override func visit(expr: AssignExpr): Value {

        let ref = match (expr.left) {
            case r: RefExpr => r
            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.ASSIGN_TYPE_MISMATCH,
                    "Left-hand side of assignment must be a variable",
                    expr
                )
        }

        let name = ref.identifier.value
        let newVal = expr.right.traverse(this)
        let newType = typeOfValue(newVal)

        match (lookupVar(name)) {

            case Some(entry) =>

                // 1. 不可变变量不能重复赋值
                if (!entry.mutable && entry.initialized) {
                    throw CjcjRuntimeErrorWithLocation(
                        ErrorCode.ASSGIN_IMMUT_VAR,
                        "Immutable variable `${name}` cannot be assigned twice",
                        expr
                    )
                }

                // 2. 如果以前没类型 → 赋值决定类型
                if (entry.annotatedType.isNone()) {
                    entry.annotatedType = Some(newType)
                } else {
                    // 3. 有显式类型或推断类型 → 必须匹配
                    let t = entry.annotatedType.getOrThrow()

                    if (!isSubtypeOrEqual(newType, t)) {
                        throw CjcjRuntimeErrorWithLocation(
                            ErrorCode.ASSIGN_TYPE_MISMATCH,
                            "Cannot assign value of type `${newType.name}` to `${name}` of type `${t.name}`",
                            expr
                        )
                    }
                }

                // 4. 更新值
                entry.value = newVal
                entry.initialized = true

                return Value.VUnit

            case None =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.UNDEFINED_VAR,
                    "Variable `${name}` not declared",
                    expr
                )
        }
    }

    // 变量引用
    public open override func visit(ref: RefExpr): Value {
        let name = ref.identifier.value

        match (lookupVar(name)) {
            case Some(entry) =>

                // 检查是否已初始化
                if (!entry.initialized) {
                    throw CjcjRuntimeErrorWithLocation(
                        ErrorCode.UNINITIALIZED_VAR,
                        "Variable `${name}` used before initialization",
                        ref
                    )
                }

                // 返回变量的值（正确方式）
                return entry.value

            case None =>
                // 未声明的变量错误
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.UNDEFINED_VAR,
                    "Variable `${name}` not declared",
                    ref
                )
        }
    }

    // 块
    public override func visit(block: Block): Value {
        pushScope()

        var ret: Value = Value.VUnit
        for (node in block.nodes.iterator()) {
            ret = node.traverse(this)
        }

        popScope()
        return ret
    }

    public override func visit(expr: IfExpr): Value {
        let condVal = expr.condition.traverse(this)

        match (condVal) {
            case VBoolean(b) =>
                if (b) {
                    // true 分支执行 thenBlock
                    let thenValue = expr.ifBlock.traverse(this)

                    if (hasElseBranch(expr)) {
                        // 有 else，丢弃 then 分支的值，返回 ()
                        return Value.VUnit
                    } else {
                        // 无 else，返回 ()
                        return Value.VUnit
                    }
                }
                else {
                    // false 分支
                    if (hasElseBranch(expr)) {
                        // 有 else，返回 else 的值
                        return expr.elseBranch.traverse(this)
                    } else {
                        // 无 else，返回 ()
                        return Value.VUnit
                    }
                }

            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.IF_TYPE_MISMATCH,
                    "if condition must be Bool",
                    expr
                )
        }
    }

    func hasElseBranch(expr: IfExpr): Bool {
        let e = expr.elseBranch

        // 情况 1：else if
        match (e) {
            case _: IfExpr => 
                return true
            case _: Expr => ()
        }

        // 情况 2：Block 情况（包括 desugar 的假 else）
        match (e) {
            case b: Block =>
                let nodes = b.nodes
                // desugar 的假 else: 只有 1 个元素且为 UNIT literal
                if (nodes.size == 1) {
                    match (nodes[0]) {
                        case lit: LitConstExpr =>
                            if (lit.literal.kind == TokenKind.UNIT_LITERAL) {
                                return false   // 无 else
                            }
                        case _ => ()
                    }
                }
                return true   // 有 else（有真实 else block）
            case _ =>
                // 正常情况不会到这，但为了保险认为有 else
                print("对else的判断有误")
                return true
        }
    }


    public override func visit(expr: WhileExpr): Value {
        // 进入循环，深度 +1
        loopDepth_ = loopDepth_ + 1

        let result: Value = Value.from(())

        try {
            while (true) {
                let condVal = expr.condition.traverse(this)

                match (condVal) {
                    case VBoolean(b) =>
                        if (!b) {
                            // cond = false → exit while
                            return result
                        }
                    case _ =>
                        throw CjcjRuntimeErrorWithLocation(
                            ErrorCode.WHILE_TYPE_MISMATCH,
                            "While condition must be boolean",
                            expr
                        )
                }

                try {
                    expr.block.traverse(this)
                } catch (_: ContinueException) {
                    continue
                } catch (_: BreakException) {
                    break
                }
            }
        } finally {
            loopDepth_ = loopDepth_ - 1
        }

        return result
    }

    public open override func visit(call: CallExpr): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Call Expression")
    }

    public open override func visit(_: ReturnExpr): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Return Expression")
    }

    public override func visit(expr: JumpExpr): Value {
        let kw = expr.keyword.value

        if (kw == "break") {
            if (loopDepth_ == 0) {
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.BREAK_OUTSIDE_LOOP,
                    "break not inside loop",
                    expr
                )
            }
            throw BreakException()
        }

        if (kw == "continue") {
            if (loopDepth_ == 0) {
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.CONTINUE_OUTSIDE_LOOP,
                    "continue not inside loop",
                    expr
                )
            }
            throw ContinueException()
        }

        unreachable()
    }

    // 变量声明
public override func visit(decl: VarDecl): Value {

    let name_ = decl.identifier.value

    // 防止重复定义
    if (currentScope().contains(name_)) {
        throw CjcjRuntimeErrorWithLocation(
            ErrorCode.DUPLICATED_DEF,
            "Variable `${name_}` already defined",
            decl
        )
    }

    let isMutable = (decl.keyword.kind == TokenKind.VAR)

    // 1. 获取显式类型标注
    var annotatedType: ?Type = None
    if (let Some(tnode) <- decl.declType) {
        annotatedType = Some(resolveTypeFromNode(tnode))
    }

    // 2. 处理初始化表达式
    var value: Value = Value.VUnit
    var initialized = false
    var inferredType: ?Type = None

    if (let Some(initExpr) <- decl.initializer) {
        value = initExpr.traverse(this)
        initialized = true
        inferredType = Some(typeOfValue(value))
    }

    // 3. 类型检查
    if (let Some(t) <- annotatedType) {
        if (initialized) {
            // b 的类型必须是 T1
            match (inferredType) {
                case Some(vtype) =>
                    if (!isSubtypeOrEqual(vtype, t)) {
                        throw CjcjRuntimeErrorWithLocation(
                            ErrorCode.DEF_TYPE_MISMATCH,
                            "Type mismatch: ${name_}: ${t.name} cannot accept value of type ${vtype.name}",
                            decl
                        )
                    }
                case None => ()
            }
        }
    }

    // 4. 最终变量类型 = 显式 OR 推断
    let finalType: ?Type =
        if (annotatedType.isSome()) {
            annotatedType
        } else {
            inferredType
        }

    // 5. 注册到环境
    defineVar(
        name_,
        value,
        isMutable,
        decl,
        initialized,
        finalType
    )

    return Value.VUnit
}

    public open override func visit(_: FuncParam): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Function Paramters")
    }

    public open override func visit(_: FuncDecl): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Function Declaration")
    }

    public override func visit(mainn: MainDecl): Value {
        pushScope()
        let result = mainn.block.traverse(this)
        popScope()
        return result
    }

    public open override func visit(_: ClassDecl): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Class Declaration")
    }

    public open override func visit(_: Body): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Body")
    }

    public open override func visit(arg: Argument): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Argument")
    }

    public open override func visit(_: TypeNode): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Type Node")
    }

    public open override func visit(_: PrimitiveType): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Primitive Types")
    }

    public open override func visit(_: RefType): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Reference Type")
    }

    public open override func visit(_: VariableReference): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Variable Reference (ASG)")
    }

    public open override func visit(_: FuncReference): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Function Reference (ASG)")
    }

    public open override func visit(_: ClassReference): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Class Reference (ASG)")
    }

    public open override func visit(_: VarDeclWithRef): Value {
        throw UnsupportedException(
            "Unimplemented method for Visitor : Variable Declaration with" + "References Stored (ASG)")
    }

    public open override func visit(_: FuncDeclWithRef): Value {
        throw UnsupportedException(
            "Unimplemented method for Visitor : Function Declaration with" + "References Stored (ASG)")
    }

    public open override func visit(_: MainDeclWithRef): Value {
        throw UnsupportedException(
            "Unimplemented method for Visitor : Main Declaration with" + "References Stored (ASG)")
    }

    public open override func visit(_: ClassDeclWithRef): Value {
        throw UnsupportedException(
            "Unimplemented method for Visitor : Class Declaration with" + "References Stored (ASG)")
    }

    public open override func visit(_: MemberAccess): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Member Access")
    }

    public open override func visit(_: PrimitiveTypeExpr): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Primitive type expression")
    }

    public open override func visit(_: RefExprWithRef): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Reference expression with reference")
    }

    public open override func visit(_: ThisSuperExpr): Value {
        throw UnsupportedException("Unimplemented method for Visitor : This Super expression")
    }

    public open override func visit(_: ThisSuperReference): Value {
        throw UnsupportedException("Unimplemented method for Visitor : This Super reference")
    }

    public open override func visit(_: CallExprWithRef): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Call expression with reference")
    }

    public open override func visit(_: MemberAccessWithRef): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Member access with reference")
    }

    public open override func visit(_: InterfaceDecl): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Interface Declaration")
    }

    public open override func visit(_: InterfaceDeclWithRef): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Interface Declaration with reference")
    }

    public open override func visit(_: InterfaceReference): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Interface Reference")
    }

    // ===== 二元运算函数 ==================
    private func evalMath(kind: TokenKind, a: Value, b: Value, node: Node): Value {
        let tuple = (a, b)
        match (kind) {

            case TokenKind.ADD =>
                match (tuple) {
                    case (VInteger(x), VInteger(y)) =>
                        try {return Value.from(x + y)}
                        catch (_: OverflowException) {
                            throw CjcjRuntimeErrorWithLocation(
                                ErrorCode.ADD_OVERFLOW, "overflow add", node)
                        }
                    case (VString(s1), VString(s2)) =>
                        return Value.from(s1 + s2)
                    case _ =>
                        throw CjcjRuntimeErrorWithLocation(
                            ErrorCode.ADD_TYPE_MISMATCH, "invalid +", node)
                }

            case TokenKind.SUB =>
                match (tuple) {
                    case (VInteger(x), VInteger(y)) =>
                        try {return Value.from(x - y)}
                        catch (_: OverflowException) {
                            throw CjcjRuntimeErrorWithLocation(
                                ErrorCode.SUB_OVERFLOW, "overflow sub", node)
                        }
                    case _ =>
                        throw CjcjRuntimeErrorWithLocation(
                            ErrorCode.SUB_TYPE_MISMATCH, "invalid -", node)
                }

            case TokenKind.MUL =>
                match (tuple) {
                    case (VInteger(x), VInteger(y)) =>
                        try {return Value.from(x * y)}
                        catch (_: OverflowException) {
                            throw CjcjRuntimeErrorWithLocation(
                                ErrorCode.MUL_OVERFLOW, "overflow mul", node)
                        }
                    case (VString(s), VInteger(n)) =>
                        if (n < 0) {
                            throw CjcjRuntimeErrorWithLocation(
                                ErrorCode.MUL_TYPE_MISMATCH,
                                "string * negative", node)
                        }
                        var res = ""
                        for (_ in 0 .. n) { res = res + s }
                        return Value.from(res)

                    case (VInteger(n), VString(s)) =>
                        if (n < 0) {
                            throw CjcjRuntimeErrorWithLocation(
                                ErrorCode.MUL_TYPE_MISMATCH,
                                "negative * string", node)
                        }
                        var res = ""
                        for (_ in 0 .. n) { res = res + s }
                        return Value.from(res)

                    case _ =>
                        throw CjcjRuntimeErrorWithLocation(
                            ErrorCode.MUL_TYPE_MISMATCH, "invalid *", node)
                }

            case TokenKind.DIV =>
                match (tuple) {
                    case (VInteger(x), VInteger(y)) =>
                        if (y == 0) {
                            throw CjcjRuntimeErrorWithLocation(
                                ErrorCode.DIV_BY_ZERO, "div by zero", node)
                        }
                        return Value.from(x / y)
                    case _ =>
                        throw CjcjRuntimeErrorWithLocation(
                            ErrorCode.DIV_TYPE_MISMATCH, "invalid /", node)
                }

            case TokenKind.MOD =>
                match (tuple) {
                    case (VInteger(x), VInteger(y)) =>
                        if (y == 0) {
                            throw CjcjRuntimeErrorWithLocation(
                                ErrorCode.MOD_BY_ZERO, "mod by zero", node)
                        }
                        return Value.from(x % y)
                    case _ =>
                        throw CjcjRuntimeErrorWithLocation(
                            ErrorCode.MOD_TYPE_MISMATCH, "invalid %", node)
                }

            case TokenKind.EXP =>
                match (tuple) {
                    case (VInteger(x), VInteger(y)) =>
                        if (y < 0) {
                            throw CjcjRuntimeErrorWithLocation(
                                ErrorCode.EXP_NEGATIVE_POWER, "negative exponent", node)
                        }
                        try {
                            let r = pow(Float32(x), Float32(y))
                            return Value.from(Int64(r))
                        } catch (_: OverflowException) {
                            throw CjcjRuntimeErrorWithLocation(
                                ErrorCode.EXP_OVERFLOW, "overflow exponent", node)
                        }
                    case _ =>
                        throw CjcjRuntimeErrorWithLocation(
                            ErrorCode.EXP_TYPE_MISMATCH, "invalid **", node)
                }

            case _ => unreachable()
        }
    }

    private func evalCompare(kind: TokenKind, a: Value, b: Value, node: Node): Value {
        let tuple = (a, b)

        match (tuple) {
            case (VInteger(x), VInteger(y)) =>
                match (kind) {
                    case TokenKind.LT => return Value.from(x < y)
                    case TokenKind.LE => return Value.from(x <= y)
                    case TokenKind.GT => return Value.from(x > y)
                    case TokenKind.GE => return Value.from(x >= y)
                    case _ => unreachable()
                }

            case (VString(s1), VString(s2)) =>
                match (kind) {
                    case TokenKind.LT => return Value.from(s1 < s2)
                    case TokenKind.LE => return Value.from(s1 <= s2)
                    case TokenKind.GT => return Value.from(s1 > s2)
                    case TokenKind.GE => return Value.from(s1 >= s2)
                    case _ => unreachable()
                }

            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.CMP_TYPE_MISMATCH,
                    "invalid compare", node)
        }
    }

    private func evalEq(kind: TokenKind, a: Value, b: Value, node: Node): Value {
        let tuple = (a, b)

        match (tuple) {
            case (VInteger(x), VInteger(y)) =>
                match (kind) {
                    case TokenKind.EQUAL  => return Value.from(x == y)
                    case TokenKind.NOTEQ => return Value.from(x != y)
                    case _ => unreachable()
                }

            case (VString(s1), VString(s2)) =>
                match (kind) {
                    case TokenKind.EQUAL  => return Value.from(s1 == s2)
                    case TokenKind.NOTEQ => return Value.from(s1 != s2)
                    case _ => unreachable()
                }

            case (VBoolean(x), VBoolean(y)) =>
                match (kind) {
                    case TokenKind.EQUAL  => return Value.from(x == y)
                    case TokenKind.NOTEQ => return Value.from(x != y)
                    case _ => unreachable()
                }

            case (VUnit, VUnit) =>
                match (kind) {
                    case TokenKind.EQUAL  => return Value.from(true)
                    case TokenKind.NOTEQ => return Value.from(false)
                    case _ => unreachable()
                }

            case _ =>
                let err =
                    match (kind) {
                        case TokenKind.EQUAL  => ErrorCode.EQ_TYPE_MISMATCH
                        case TokenKind.NOTEQ => ErrorCode.NEQ_TYPE_MISMATCH
                        case _ => unreachable()
                    }
                throw CjcjRuntimeErrorWithLocation(err, "invalid equality", node)
        }
    }

    private func evalLogicalAnd(left: Value, expr: BinaryExpr): Value {
        match (left) {
            case VBoolean(false) =>
                return Value.from(false)   // short-circuit

            case VBoolean(true) =>
                let right = expr.right.traverse(this)
                match (right) {
                    case VBoolean(b) => return Value.from(b)
                    case _ => throw CjcjRuntimeErrorWithLocation(
                        ErrorCode.AND_TYPE_MISMATCH,
                        "right of && must be bool",
                        expr
                    )
                }

            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.AND_TYPE_MISMATCH,
                    "left of && must be bool",
                    expr
                )
        }
    }

    private func evalLogicalOr(left: Value, expr: BinaryExpr): Value {
        match (left) {
            case VBoolean(true) =>
                return Value.from(true)    // short-circuit

            case VBoolean(false) =>
                let right = expr.right.traverse(this)
                match (right) {
                    case VBoolean(b) => return Value.from(b)
                    case _ => throw CjcjRuntimeErrorWithLocation(
                        ErrorCode.OR_TYPE_MISMATCH,
                        "right of || must be bool",
                        expr
                    )
                }

            case _ =>
                throw CjcjRuntimeErrorWithLocation(
                    ErrorCode.OR_TYPE_MISMATCH,
                    "left of || must be bool",
                    expr
                )
        }
    }

    // ==== 类型检查 ========================
    private func typeOfValue(v: Value): Type {
        match(v) {
            case VInteger(_) => Type("Int64")
            case VString(_)  => Type("String")
            case VBoolean(_) => Type("Bool")
            case VUnit       => Type.UNIT
        }
    }

    private func checkTypeMatch(t: Type, v: Value): Bool {
        let vType = typeOfValue(v)

        // vType <: t   ?
        return t.isParent(vType)
    }

    // ==== TypeNode -> Type ===============
    private func resolveTypeFromNode(node: TypeNode): Type {

        match (node) {

            // 原始类型：Int64, Bool, String, Unit 等
            case p: PrimitiveType =>
                let t = Type(p.typeName.value)
                node.resolvedType = Some(t)
                return t

            // 引用类型：自定义类等
            case r: RefType =>
                let t = Type(r.typeName.value)
                node.resolvedType = Some(t)
                return t

            // 函数类型：Lab1 未用，返回 Any 或报错
            case f: FuncType =>
                node.resolvedType = Some(Type.ANY)
                return Type.ANY

            case _ =>
                node.resolvedType = Some(Type.ANY)
                return Type.ANY
        }
    }

    private func isSubtypeOrEqual(a: Type, b: Type): Bool {
        a == b || a.isParent(b)
    }
    // ==== 永远不会触发的错误 ===============
    private func unreachable(): Nothing {
        throw Exception("Unreachable code executed")
    }
}
