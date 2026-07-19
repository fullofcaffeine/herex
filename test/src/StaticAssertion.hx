package;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

class StaticAssertion {
	public macro static function literal(expression:Expr):Expr {
		switch expression.expr {
			case EConst(CString(_, _)):
			default:
				Context.error("Expected a compile-time string literal", expression.pos);
		}
		return expression;
	}
}
