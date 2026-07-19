package;

class TestMain {
	static var fieldInitializer = <heredoc>
		field initializer
	</heredoc>;

	static var property(default, null) = <heredoc>property initializer</heredoc>;

	public static function main():Void {
		basicInterpolation();
		whitespaceModes();
		marginMode();
		escapesAndRawText();
		blockInterpolation();
		trailingNewlines();
		arbitraryPayload();
		placementAndCompatibility();
		Assertions.finish();
	}

	static function basicInterpolation():Void {
		var name = "Ada";
		var count = 21;
		var nullable:Null<Int> = null;
		Assertions.equal("Hello Ada; 42; $", <heredoc>Hello $name; ${count * 2}; $$</heredoc>, "native interpolation forms");
		Assertions.equal("null", <heredoc>$nullable</heredoc>, "native null coercion");
		Assertions.equal("short Ada\n", <hd newline>short $name</hd>, "built-in short hd alias");

		var calls = 0;
		function next(label:String):String {
			calls++;
			return label;
		}
		Assertions.equal("AB", <heredoc>${next("A")}${next("B")}</heredoc>, "adjacent expressions");
		Assertions.value(2, calls, "expressions evaluate exactly once");
		Assertions.equal("}|true|{ok}", <heredoc>${"}"}|${~/[}]/.match("}")}|${(function() {
			/* A closing brace in a comment must not end interpolation: } */
			return "{ok}";
		})()}</heredoc>, "expression strings, regular expressions, comments, and nested braces");
	}

	static function whitespaceModes():Void {
		Assertions.equal("", <heredoc></heredoc>, "empty heredoc");
		Assertions.equal("alpha\n  beta", <heredoc>
			alpha
			  beta
		</heredoc>, "smart framing and dedent");

		Assertions.equal("\nvalue\n", <heredoc>

			value

		</heredoc>, "smart removes only one framing line");

		Assertions.equal("\n\t\tvalue\n\t", <heredoc mode="preserve">
		value
	</heredoc>, "preserve mode");

		Assertions.equal("\nvalue\n", <heredoc mode="dedent">
			value
		</heredoc>, "dedent mode keeps framing newlines");

		Assertions.equal("value", <heredoc mode="trim">
			value
		</heredoc>, "trim mode");

		Assertions.equal("first\n  second", <heredoc mode="dedent-trim">
			first
			  second
		</heredoc>, "dedent-trim mode");

		Assertions.equal("one\n\\ttwo", <heredoc>
			one
			\ttwo
		</heredoc>, "default mode keeps content backslashes literal");

		Assertions.equal("\talpha\n  beta", <heredoc>
				alpha
			  beta
		</heredoc>, "mixed tab and space indentation uses an exact common prefix");

		var padded = "  dynamic value  ";
		Assertions.equal("  dynamic value  ", <heredoc mode="trim">  $padded  </heredoc>, "trim does not alter an interpolated value");
	}

	static function marginMode():Void {
		var name = "Ada";
		Assertions.equal("title\n  nested Ada\n", <heredoc margin="|">
			|title
			|  nested $name
			|
		</heredoc>, "strict margin mode");

		Assertions.equal("a\n b", <heredoc margin=">>">
			>>a
			>> b
		</heredoc>, "multi-character margin marker");
	}

	static function escapesAndRawText():Void {
		var name = "Ada";
		Assertions.equal("C:\\tmp\\new\\$name", <heredoc>C:\tmp\new\$$name</heredoc>, "literal backslashes are the default");
		Assertions.equal("line 1\nline 2\tA!A🙂", <heredoc escapes="haxe">line 1\nline 2\t\x41\041\u0041\u{1F642}</heredoc>, "Haxe escape mode");
		Assertions.equal("a\nb:\t", <heredoc escapes="haxe">${"a\nb"}:\t</heredoc>, "literal escape decoding does not rewrite expression source");
		Assertions.equal("value", <heredoc mode="trim" escapes="haxe">\tvalue\t</heredoc>, "trim applies after decoding literal edge escapes");
		Assertions.equal("$name $$ ${name} \\n", <heredoc interpolate={false}>$name $$ ${name} \n</heredoc>, "interpolation opt-out");
	}

	static function blockInterpolation():Void {
		var block = "first\nsecond\n\nlast";
		Assertions.equal("root:\n  first\n  second\n\n  last\ndone", <heredoc>
			root:
			  $block
			done
		</heredoc>, "block-smart reindentation");

		Assertions.equal("root:\n  first\nsecond\n\nlast\ndone", <heredoc reindent={false}>
			root:
			  $block
			done
		</heredoc>, "block reindent opt-out");

		Assertions.equal("inline first\nsecond\n\nlast", <heredoc>inline $block</heredoc>, "inline values are untouched");
	}

	static function trailingNewlines():Void {
		Assertions.equal("value\n", <heredoc newline>value

		</heredoc>, "singular newline is exact");
		Assertions.equal("value\n", <heredoc newline={true}>value</heredoc>, "issue 1 braced newline form");
		Assertions.equal("value", <heredoc mode="dedent" newline={false}>value
		</heredoc>, "false singular newline means zero");
		Assertions.equal("value\n\n", <heredoc newlines={2}>value</heredoc>, "plural newlines");

		var ending = "dynamic\r\n\r\n";
		Assertions.equal("dynamic\n\n\n", <heredoc newlines={3}>$ending</heredoc>, "dynamic terminal CRLF normalization");
	}

	static function arbitraryPayload():Void {
		var module = "demo.Native";
		var generated = <heredoc>
			private typedef Assigns<T> = {
				var values:Array<T>;
			}

			@:native("$module")
			class Boundary {
				static function compare(a:Int, b:Int):Bool return a < b;
				static var entity = "&amp;";
				static var html = '<div data-kind="raw">unchanged</div>';
			}
		</heredoc>;

		Assertions.equal('private typedef Assigns<T> = {\n\tvar values:Array<T>;\n}\n\n@:native("demo.Native")\nclass Boundary {\n\tstatic function compare(a:Int, b:Int):Bool return a < b;\n\tstatic var entity = "&amp;";\n\tstatic var html = \'<div data-kind="raw">unchanged</div>\';\n}',
			generated, "arbitrary generated Haxe is not parsed as HXX");
	}

	static function placementAndCompatibility():Void {
		Assertions.equal("static", StaticAssertion.literal(<heredoc>
			static
		</heredoc>), "static heredocs fold to one string literal");
		Assertions.equal("field initializer", fieldInitializer, "field initializer traversal");
		Assertions.equal("property initializer", property, "property initializer traversal");
		var closure = () -> <heredoc>closure body</heredoc>;
		Assertions.equal("closure body", closure(), "closure traversal");
		Assertions.equal("compatibility", Heredoc.hxx(<heredoc>compatibility</heredoc>), "default-package macro compatibility");
		Assertions.equal("namespaced", herex.Heredoc.hxx(<heredoc>namespaced</heredoc>), "namespaced macro compatibility");
		Assertions.equal("coexists", <dummy>coexists</dummy>, "non-Herex markup remains available to other build macros");
		Assertions.equal("heading coexists", <h>heading coexists</h>, "h is not claimed unless explicitly configured");
	}
}
