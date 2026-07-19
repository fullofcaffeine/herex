#if macro
import haxe.macro.Expr;
#end

/** Backwards-compatible default-package facade. Prefer `herex.Heredoc`. */
class Heredoc {
	public macro static function hxx(expression:Expr):Expr {
		return herex.macro.HeredocBuilder.transformDirect(expression);
	}
}
