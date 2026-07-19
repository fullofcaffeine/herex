package herex;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;
#end

/** Enables direct `<heredoc>...</heredoc>` expressions for the compilation. */
class HeredocSyntax {
	public static function use():Void {
		#if macro
		herex.macro.HeredocBuilder.validateConfiguration();
		var registrationDefine = "herex_internal_syntax_registered";
		if (!Context.defined(registrationDefine)) {
			Compiler.define(registrationDefine);
			Compiler.addGlobalMetadata("", "@:build(herex.macro.HeredocBuilder.build())", true, true, false);
		}
		#end
	}
}
