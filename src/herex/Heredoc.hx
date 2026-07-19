package herex;

#if macro
import haxe.macro.Expr;
#end

/** Compatibility macro for projects that explicitly wrap heredoc markup. */
class Heredoc {
	public macro static function hxx(expression:Expr):Expr {
		return herex.macro.HeredocBuilder.transformDirect(expression);
	}
}
