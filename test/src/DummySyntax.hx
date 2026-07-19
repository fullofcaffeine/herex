package;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
#end

class DummySyntax {
	#if macro
	public static function use():Void {
		Compiler.addGlobalMetadata("", "@:build(DummySyntax.build())", true, true, false);
	}

	public static macro function build():Array<Field> {
		var fields = Context.getBuildFields();
		function transform(expression:Expr):Expr {
			return switch expression.expr {
				case EMeta(metadata, value) if (metadata.name == ":markup"):
					switch value.expr {
						case EConst(CString("<dummy>coexists</dummy>", _)): Context.makeExpr("coexists", expression.pos);
						case EConst(CString("<h>heading coexists</h>", _)): Context.makeExpr("heading coexists", expression.pos);
						default: ExprTools.map(expression, transform);
					}
				default: ExprTools.map(expression, transform);
			}
		}

		for (field in fields) {
			switch field.kind {
				case FVar(type, expression):
					field.kind = FVar(type, expression == null ? null : transform(expression));
				case FProp(get, set, type, expression):
					field.kind = FProp(get, set, type, expression == null ? null : transform(expression));
				case FFun(fn):
					if (fn.expr != null) {
						fn.expr = transform(fn.expr);
					}
			}
		}
		return fields;
	}
	#end
}
