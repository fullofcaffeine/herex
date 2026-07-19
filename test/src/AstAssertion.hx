package;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import herex.macro.HeredocBuilder;
#end

class AstAssertion {
	public macro static function preservedMetadata():Expr {
		var expression = Context.parse("{ var @:herex_probe local = 1; var closure = function(@:herex_probe argument:Int) return argument; }",
			Context.currentPos());
		var transformed = @:privateAccess HeredocBuilder.transformTree(expression);
		switch transformed.expr {
			case EBlock([
				{expr: EVars([{meta: localMetadata, namePos: localNamePosition}])},
				{expr: EVars([{expr: {expr: EFunction(_, {args: [{meta: argumentMetadata}]})}}])}
			]):
				if (localNamePosition == null
					|| !hasMetadata(localMetadata, ":herex_probe")
					|| !hasMetadata(argumentMetadata, ":herex_probe")) {
					Context.error("Herex traversal removed attached AST metadata", transformed.pos);
				}
			default:
				Context.error("Herex traversal did not preserve the expected expression shape", transformed.pos);
		}
		return macro true;
	}

	#if macro
	static function hasMetadata(metadata:Metadata, name:String):Bool {
		return metadata != null && Lambda.exists(metadata, (entry) -> entry.name == name);
	}
	#end
}
