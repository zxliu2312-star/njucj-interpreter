package cjcj.executor

import cjcj.visitor.*
import cjcj.scanner.TokenKind
import cjcj.scanner.Token
import std.convert.*
import std.collection.HashMap
import std.collection.ArrayList

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
    public let node: Node

    init(mutable: Bool, initialized: Bool, value: Value, node: Node) {
        this.mutable = mutable
        this.initialized = initialized
        this.value = value
        this.node = node
    }
}

public open class Evaluator <: Visitor<Value> {
    // How do you get and set the context when executing an expression?
    // You might need to add some member variables to do this.
    //
    // private let context = ...
    // private let static_scope = ...
    private var envStack: ArrayList<HashMap<String, Value>> = ArrayList()

    init() {
        // 初始化时创建一个全局作用域
        envStack.add(HashMap<String, Value>())
    }

    private func pushScope(): Unit {
        envStack.add(HashMap<String, Value>())
    }

    private func popScope(): Unit {
        if (envStack.size > 1) {
            envStack.remove(at: envStack.size - 1)
        }
    }

    private func currentScope(): HashMap<String, Value> {
        envStack[envStack.size - 1]
    }

    private func defineVar(name: String, value: Value): Unit {
        currentScope()[name] = value
    }

    private func lookupVar(name: String): ?Value {
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

    // ---------------- visitor implementations ----------------
    public open override func visit(prog: Program): Value {
        return prog.traverse(this)
    }

    // This is just an example of how to implement the visit method for BinaryExpr.
    // You may need to modify, split, or completely rewrite it depending on your design.
    public open override func visit(expr: BinaryExpr): Value {
        let left = expr.left.traverse(this)
        let right = expr.right.traverse(this)
        try {
            match (expr.oper.kind) {
                case TokenKind.ADD => match ((left, right)) {
                    case (VInteger(a), VInteger(b)) => Value.from(a + b)
                    case (VString(a), VString(b)) => Value.from(a + b)
                    case _ => throw CjcjRuntimeErrorWithLocation(ErrorCode.ADD_TYPE_MISMATCH,
                        "cannot add left = ${left}, right = ${right}", expr)
                }
                case _ => throw Lab1TodoException("Unimplemented Binary Operator `${expr.oper.kind}`")
            }
        } catch (e: OverflowException) {
            match (e.message) {
                case "add" => throw CjcjRuntimeErrorWithLocation(ErrorCode.ADD_OVERFLOW,
                    "overflow add: left = ${left}, right = ${right}", expr)
                case _ => throw Lab1TodoException("You need to handle overflow of ${e.message}")
            }
        }
    }

    public open override func visit(expr: UnaryExpr): Value {
        throw Lab1TodoException("Unary Expression Evaluation Not Implemented")
    }

    public open override func visit(par: ParenExpr): Value {
        throw Lab1TodoException("Parenthesized Expression Evaluation Not Implemented")
    }

    public open override func visit(lit: LitConstExpr): Value {
        match (lit.literal.kind) {
            case TokenKind.INTEGER_LITERAL => Value.from(Int64.parse(lit.literal.value))
            case _ => throw Lab1TodoException("There are more literal types to implement")
        }
    }

    public open override func visit(expr: AssignExpr): Value {
        throw Lab1TodoException("Assignment Expression Evaluation Not Implemented")
    }

    public open override func visit(ref: RefExpr): Value {
        throw Lab1TodoException("Reference Expression Evaluation Not Implemented")
    }

    public open override func visit(block: Block): Value {
        var ret = Value.VUnit
        for (stmt in block.nodes.iterator()) {
            ret = stmt.traverse(this)
        }
        return ret
    }

    public open override func visit(expr: IfExpr): Value {
        throw Lab1TodoException("If Expression Evaluation Not Implemented")
    }

    public open override func visit(expr: WhileExpr): Value {
        throw Lab1TodoException("While Expression Evaluation Not Implemented")
    }

    public open override func visit(call: CallExpr): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Call Expression")
    }

    public open override func visit(_: ReturnExpr): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Return Expression")
    }

    public open override func visit(jmp: JumpExpr): Value {
        throw Lab1TodoException("Jump Expression Evaluation Not Implemented")
    }

    public open override func visit(decl: VarDecl): Value {
        throw Lab1TodoException("Variable Declaration Evaluation Not Implemented")
    }

    public open override func visit(_: FuncParam): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Function Paramters")
    }

    public open override func visit(_: FuncDecl): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Function Declaration")
    }

    public open override func visit(`main`: MainDecl): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Main Declaration")
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
}
