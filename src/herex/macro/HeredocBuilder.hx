package herex.macro;

#if macro
import haxe.io.Bytes;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import StringTools;

private enum AttributeValue {
	Bare;
	Quoted(value:String);
	Braced(value:String);
}

private typedef Attribute = {
	var name:String;
	var value:AttributeValue;
	var start:Int;
	var end:Int;
}

private enum WhitespaceMode {
	Smart;
	Preserve;
	Dedent;
	Trim;
	DedentTrim;
}

private typedef Options = {
	var mode:WhitespaceMode;
	var margin:Null<String>;
	var interpolate:Bool;
	var haxeEscapes:Bool;
	var reindent:Bool;
	var trailingNewlines:Null<Int>;
}

private typedef ParsedTag = {
	var body:MappedText;
	var options:Options;
}

private enum OutputPart {
	Text(value:String);
	Interpolation(expression:Expr, start:Int, end:Int);
}

private class MappedText {
	public var value:String;
	public var source:Array<Int>;
	public var endSource:Int;

	public function new(value:String, source:Array<Int>, endSource:Int) {
		this.value = value;
		this.source = source;
		this.endSource = endSource;
	}

	public function boundary(index:Int):Int {
		if (source.length == 0) {
			return endSource;
		}
		if (index <= 0) {
			return source[0];
		}
		if (index >= source.length) {
			return endSource;
		}
		return source[index];
	}

	public function slice(start:Int, end:Int):MappedText {
		return new MappedText(value.substring(start, end), source.slice(start, end), boundary(end));
	}
}

class HeredocBuilder {
	static inline var CANONICAL_TAG = "heredoc";
	static inline var SHORT_TAG = "hd";
	static inline var ALIAS_DEFINE = "herex_alias";

	public static function validateConfiguration():Void {
		var alias = Context.definedValue(ALIAS_DEFINE);
		if (alias != null && !isValidTagName(alias)) {
			fail('-D $ALIAS_DEFINE requires a tag name such as h or block-text', Context.currentPos());
		}
	}

	public static macro function build():Array<Field> {
		var fields = Context.getBuildFields();
		for (field in fields) {
			switch field.kind {
				case FVar(type, expression):
					field.kind = FVar(type, expression == null ? null : transformTree(expression));
				case FProp(get, set, type, expression):
					field.kind = FProp(get, set, type, expression == null ? null : transformTree(expression));
				case FFun(fn):
					if (fn.expr != null) {
						fn.expr = transformTree(fn.expr);
					}
			}
		}
		return fields;
	}

	public static function transformDirect(expression:Expr):Expr {
		return switch expression.expr {
			case EMeta(metadata, value) if (metadata.name == ":markup"):
				switch value.expr {
					case EConst(CString(raw, _)):
						var tag = detectTag(raw);
						if (tag == null) {
							fail("expected <heredoc>...</heredoc>, <hd>...</hd>, or the configured Herex alias", expression.pos);
						} else {
							transformMarkup(raw, expression.pos, tag);
						}
					default:
						fail("expected a Herex markup expression", expression.pos);
				}
			case EConst(CString(_, _)):
				// The automatic expression pass has already transformed this argument.
				expression;
			default:
				fail("expected a Herex markup expression", expression.pos);
		}
	}

	static function transformTree(expression:Expr):Expr {
		return switch expression.expr {
			case EMeta(metadata, value) if (metadata.name == ":markup"):
				switch value.expr {
					case EConst(CString(raw, _)):
						var tag = detectTag(raw);
						tag == null ? ExprTools.map(expression, transformTree) : transformMarkup(raw, expression.pos, tag);
					default:
						ExprTools.map(expression, transformTree);
				}
			default:
				ExprTools.map(expression, transformTree);
		}
	}

	static function detectTag(raw:String):Null<String> {
		var tags = [CANONICAL_TAG, SHORT_TAG];
		var alias = Context.definedValue(ALIAS_DEFINE);
		if (alias != null && tags.indexOf(alias) == -1) {
			tags.push(alias);
		}
		for (tag in tags) {
			var opening = '<$tag';
			if (StringTools.startsWith(raw, opening) && raw.length > opening.length) {
				var next = raw.charAt(opening.length);
				if (next == ">" || isSpace(next)) {
					return tag;
				}
			}
		}
		return null;
	}

	static function transformMarkup(raw:String, position:Position, tag:String):Expr {
		var parsed = parseTag(raw, position, tag);
		var text = normalizeLineEndings(parsed.body);
		var needsTrim = false;

		if (parsed.options.margin != null) {
			text = stripFramingLines(text);
			text = stripMargin(text, parsed.options.margin, raw, position);
		} else {
			switch parsed.options.mode {
				case Smart:
					text = dedent(stripFramingLines(text));
				case Preserve:
				case Dedent:
					text = dedent(text);
				case Trim:
					needsTrim = true;
				case DedentTrim:
					text = dedent(text);
					needsTrim = true;
			}
		}

		var parts:Array<OutputPart>;
		if (parsed.options.interpolate) {
			// Parse expressions before decoding text escapes. Backslashes inside
			// ${...} belong to Haxe itself, while literal segments belong to Herex.
			parts = parseInterpolation(text, raw, position, parsed.options.haxeEscapes);
			if (needsTrim) {
				parts = trimOutput(parts);
			}
		} else {
			if (parsed.options.haxeEscapes) {
				text = decodeHaxeEscapes(text, raw, position);
			}
			if (needsTrim) {
				text = trimMapped(text);
			}
			parts = [Text(text.value)];
		}
		var expression = buildExpression(parts, text, parsed.options.reindent, position);
		if (parsed.options.trailingNewlines != null) {
			var count = parsed.options.trailingNewlines;
			expression = switch expression.expr {
				case EConst(CString(value, _)):
					Context.makeExpr(withTrailingNewlines(value, count), position);
				default:
					macro @:pos(position) herex.HeredocRuntime.withTrailingNewlines($expression, $v{count});
			}
		}
		return expression;
	}

	static function parseTag(raw:String, position:Position, tag:String):ParsedTag {
		if (detectTag(raw) != tag) {
			return fail('expected an exact <$tag> tag', position);
		}

		var opening = '<$tag';
		var closing = '</$tag>';
		var attributes = new Map<String, Attribute>();
		var index = opening.length;
		while (true) {
			index = skipSpaces(raw, index);
			if (index >= raw.length) {
				return failAt("unterminated opening tag", raw, position, raw.length - 1, raw.length);
			}
			if (raw.charAt(index) == ">") {
				index++;
				break;
			}

			var nameStart = index;
			if (!isNameStart(raw.charAt(index))) {
				return failAt("expected an attribute name", raw, position, index, index + 1);
			}
			index++;
			while (index < raw.length && isNamePart(raw.charAt(index))) {
				index++;
			}
			var name = raw.substring(nameStart, index);
			if (attributes.exists(name)) {
				return failAt('duplicate attribute "$name"', raw, position, nameStart, index);
			}

			index = skipSpaces(raw, index);
			var value:AttributeValue = Bare;
			if (index < raw.length && raw.charAt(index) == "=") {
				index = skipSpaces(raw, index + 1);
				if (index >= raw.length) {
					return failAt('missing value for "$name"', raw, position, nameStart, index);
				}
				var delimiter = raw.charAt(index);
				if (delimiter == "\"" || delimiter == "'") {
					var valueStart = ++index;
					var escaped = false;
					while (index < raw.length) {
						var character = raw.charAt(index);
						if (!escaped && character == delimiter) {
							break;
						}
						escaped = !escaped && character == "\\";
						if (character != "\\") {
							escaped = false;
						}
						index++;
					}
					if (index >= raw.length) {
						return failAt('unterminated quoted value for "$name"', raw, position, valueStart - 1, raw.length);
					}
					var encoded = mappedFromRaw(raw, valueStart, index);
					value = Quoted(decodeHaxeEscapes(encoded, raw, position).value);
					index++;
				} else if (delimiter == "{") {
					var valueStart = index + 1;
					var close = findClosingBrace(raw, index, position);
					value = Braced(StringTools.trim(raw.substring(valueStart, close)));
					index = close + 1;
				} else {
					return failAt('attribute "$name" requires a quoted string or a braced literal', raw, position, index, index + 1);
				}
			}
			attributes.set(name, {
				name: name,
				value: value,
				start: nameStart,
				end: index
			});
		}

		if (!StringTools.endsWith(raw, closing)) {
			return failAt('missing exact $closing closing tag', raw, position, index, raw.length);
		}
		var bodyEnd = raw.length - closing.length;
		if (bodyEnd < index) {
			return failAt("closing tag overlaps the opening tag", raw, position, index, raw.length);
		}

		var known = ["mode", "margin", "newline", "newlines", "interpolate", "escapes", "reindent"];
		for (name => attribute in attributes) {
			if (known.indexOf(name) == -1) {
				return failAt('unknown attribute "$name"', raw, position, attribute.start, attribute.end);
			}
		}

		var mode = Smart;
		var modeAttribute = attributes.get("mode");
		if (modeAttribute != null) {
			mode = switch requireString(modeAttribute, raw, position) {
				case "smart": Smart;
				case "preserve": Preserve;
				case "dedent": Dedent;
				case "trim": Trim;
				case "dedent-trim": DedentTrim;
				case invalid:
					failAt('invalid mode "$invalid"; expected smart, preserve, dedent, trim, or dedent-trim', raw, position, modeAttribute.start,
						modeAttribute.end);
			}
		}

		var margin:Null<String> = null;
		var marginAttribute = attributes.get("margin");
		if (marginAttribute != null) {
			if (modeAttribute != null) {
				return failAt('"margin" and "mode" cannot be combined', raw, position, marginAttribute.start, marginAttribute.end);
			}
			margin = requireString(marginAttribute, raw, position);
			if (margin.length == 0 || isSpace(margin.charAt(0)) || margin.indexOf("\r") != -1 || margin.indexOf("\n") != -1) {
				return failAt('"margin" must start with a non-whitespace character and contain no line breaks', raw, position, marginAttribute.start,
					marginAttribute.end);
			}
		}

		var interpolate = readBool(attributes.get("interpolate"), true, false, raw, position);
		var reindentAttribute = attributes.get("reindent");
		var reindent = readBool(reindentAttribute, true, false, raw, position);
		if (!interpolate && reindentAttribute != null) {
			return failAt('"reindent" is only valid when interpolation is enabled', raw, position, reindentAttribute.start, reindentAttribute.end);
		}

		var haxeEscapes = false;
		var escapesAttribute = attributes.get("escapes");
		if (escapesAttribute != null) {
			haxeEscapes = switch requireString(escapesAttribute, raw, position) {
				case "literal": false;
				case "haxe": true;
				case invalid:
					return failAt('invalid escapes mode "$invalid"; expected literal or haxe', raw, position, escapesAttribute.start, escapesAttribute.end);
			}
		}

		var newlineAttribute = attributes.get("newline");
		var newlinesAttribute = attributes.get("newlines");
		if (newlineAttribute != null && newlinesAttribute != null) {
			return failAt('"newline" and "newlines" cannot be combined', raw, position, newlinesAttribute.start, newlinesAttribute.end);
		}
		var trailingNewlines:Null<Int> = null;
		if (newlineAttribute != null) {
			trailingNewlines = readBool(newlineAttribute, true, true, raw, position) ? 1 : 0;
		} else if (newlinesAttribute != null) {
			trailingNewlines = requireNonNegativeInt(newlinesAttribute, raw, position);
		}

		return {
			body: mappedFromRaw(raw, index, bodyEnd),
			options: {
				mode: mode,
				margin: margin,
				interpolate: interpolate,
				haxeEscapes: haxeEscapes,
				reindent: reindent,
				trailingNewlines: trailingNewlines
			}
		};
	}

	static function requireString(attribute:Attribute, raw:String, position:Position):String {
		return switch attribute.value {
			case Quoted(value): value;
			default:
				failAt('attribute "${attribute.name}" requires a quoted string literal', raw, position, attribute.start, attribute.end);
		}
	}

	static function readBool(attribute:Null<Attribute>, defaultValue:Bool, allowBare:Bool, raw:String, position:Position):Bool {
		if (attribute == null) {
			return defaultValue;
		}
		return switch attribute.value {
			case Bare if (allowBare): true;
			case Braced("true"): true;
			case Braced("false"): false;
			default:
				failAt('attribute "${attribute.name}" requires ${allowBare ? "a bare flag or " : ""}{true|false}', raw, position, attribute.start,
					attribute.end);
		}
	}

	static function requireNonNegativeInt(attribute:Attribute, raw:String, position:Position):Int {
		return switch attribute.value {
			case Braced(value):
				var valid = value.length > 0;
				for (index in 0...value.length) {
					var character = value.charAt(index);
					if (character < "0" || character > "9") {
						valid = false;
						break;
					}
				}
				var parsed = valid ? Std.parseInt(value) : null;
				if (parsed == null || parsed < 0) {
					failAt('attribute "${attribute.name}" requires a non-negative integer literal', raw, position, attribute.start, attribute.end);
				} else {
					parsed;
				}
			default:
				failAt('attribute "${attribute.name}" requires a braced non-negative integer literal', raw, position, attribute.start, attribute.end);
		}
	}

	static function findClosingBrace(raw:String, open:Int, position:Position):Int {
		var depth = 1;
		var index = open + 1;
		var quote = "";
		var escaped = false;
		while (index < raw.length) {
			var character = raw.charAt(index);
			if (quote.length > 0) {
				if (!escaped && character == quote) {
					quote = "";
				}
				escaped = !escaped && character == "\\";
				if (character != "\\") {
					escaped = false;
				}
			} else {
				switch character {
					case "\"", "'":
						quote = character;
					case "{":
						depth++;
					case "}":
						depth--;
						if (depth == 0) {
							return index;
						}
					default:
				}
			}
			index++;
		}
		return failAt("unclosed attribute brace", raw, position, open, raw.length);
	}

	static function mappedFromRaw(raw:String, start:Int, end:Int):MappedText {
		var source = [];
		for (index in start...end) {
			source.push(index);
		}
		return new MappedText(raw.substring(start, end), source, end);
	}

	static function normalizeLineEndings(input:MappedText):MappedText {
		var result = new StringBuf();
		var source = [];
		var index = 0;
		while (index < input.value.length) {
			var character = input.value.charAt(index);
			if (character == "\r") {
				result.add("\n");
				source.push(input.source[index]);
				if (index + 1 < input.value.length && input.value.charAt(index + 1) == "\n") {
					index++;
				}
			} else {
				result.add(character);
				source.push(input.source[index]);
			}
			index++;
		}
		return new MappedText(result.toString(), source, input.endSource);
	}

	static function stripFramingLines(input:MappedText):MappedText {
		var start = 0;
		var end = input.value.length;
		var firstNewline = input.value.indexOf("\n");
		if (firstNewline == -1) {
			return isHorizontalBlank(input.value, 0, end) ? input.slice(end, end) : input;
		}
		if (isHorizontalBlank(input.value, 0, firstNewline)) {
			start = firstNewline + 1;
		}

		if (start < end) {
			var lastNewline = input.value.lastIndexOf("\n", end - 1);
			if (lastNewline >= start && isHorizontalBlank(input.value, lastNewline + 1, end)) {
				end = lastNewline;
			}
		}
		return input.slice(start, end);
	}

	static function dedent(input:MappedText):MappedText {
		var common:Null<String> = null;
		var lineStart = 0;
		while (lineStart <= input.value.length) {
			var newline = input.value.indexOf("\n", lineStart);
			var lineEnd = newline == -1 ? input.value.length : newline;
			if (!isHorizontalBlank(input.value, lineStart, lineEnd)) {
				var indentEnd = lineStart;
				while (indentEnd < lineEnd && isHorizontalSpace(input.value.charAt(indentEnd))) {
					indentEnd++;
				}
				var indent = input.value.substring(lineStart, indentEnd);
				common = common == null ? indent : commonPrefix(common, indent);
			}
			if (newline == -1) {
				break;
			}
			lineStart = newline + 1;
		}

		var remove = common == null ? 0 : common.length;
		var result = new StringBuf();
		var source = [];
		lineStart = 0;
		while (lineStart <= input.value.length) {
			var newline = input.value.indexOf("\n", lineStart);
			var lineEnd = newline == -1 ? input.value.length : newline;
			if (!isHorizontalBlank(input.value, lineStart, lineEnd)) {
				appendRange(result, source, input, lineStart + remove, lineEnd);
			}
			if (newline == -1) {
				break;
			}
			appendRange(result, source, input, newline, newline + 1);
			lineStart = newline + 1;
		}
		return new MappedText(result.toString(), source, input.endSource);
	}

	static function stripMargin(input:MappedText, marker:String, raw:String, position:Position):MappedText {
		var result = new StringBuf();
		var source = [];
		var lineStart = 0;
		while (lineStart <= input.value.length) {
			var newline = input.value.indexOf("\n", lineStart);
			var lineEnd = newline == -1 ? input.value.length : newline;
			if (!isHorizontalBlank(input.value, lineStart, lineEnd)) {
				var markerStart = lineStart;
				while (markerStart < lineEnd && isHorizontalSpace(input.value.charAt(markerStart))) {
					markerStart++;
				}
				if (input.value.substr(markerStart, marker.length) != marker) {
					var rawStart = input.boundary(markerStart);
					return failAt('nonblank margin line must begin with "$marker" after indentation', raw, position, rawStart, rawStart + 1);
				}
				appendRange(result, source, input, markerStart + marker.length, lineEnd);
			}
			if (newline == -1) {
				break;
			}
			appendRange(result, source, input, newline, newline + 1);
			lineStart = newline + 1;
		}
		return new MappedText(result.toString(), source, input.endSource);
	}

	static function trimMapped(input:MappedText):MappedText {
		var start = 0;
		var end = input.value.length;
		while (start < end && StringTools.isSpace(input.value, start)) {
			start++;
		}
		while (end > start && StringTools.isSpace(input.value, end - 1)) {
			end--;
		}
		return input.slice(start, end);
	}

	static function decodeHaxeEscapes(input:MappedText, raw:String, position:Position):MappedText {
		var result = new StringBuf();
		var source = [];
		var index = 0;
		while (index < input.value.length) {
			var character = input.value.charAt(index);
			if (character != "\\") {
				appendDecoded(result, source, character, input.source[index]);
				index++;
				continue;
			}

			var escapeStart = index;
			index++;
			if (index >= input.value.length) {
				return failMapped("trailing backslash is not a valid Haxe escape", input, raw, position, escapeStart);
			}
			var escaped = input.value.charAt(index);
			var decoded:String = null;
			var consumed = 1;
			switch escaped {
				case "n":
					decoded = "\n";
				case "r":
					decoded = "\r";
				case "t":
					decoded = "\t";
				case "\"", "'", "\\":
					decoded = escaped;
				case "0", "1", "2", "3":
					if (index + 2 >= input.value.length
						|| !isOctal(input.value.charAt(index + 1))
						|| !isOctal(input.value.charAt(index + 2))) {
						return failMapped("invalid three-digit octal escape", input, raw, position, escapeStart);
					}
					var code = octalValue(escaped) * 64 + octalValue(input.value.charAt(index + 1)) * 8 + octalValue(input.value.charAt(index + 2));
					if (code > 127) {
						return failMapped("octal escape values greater than \\177 are not allowed", input, raw, position, escapeStart);
					}
					decoded = String.fromCharCode(code);
					consumed = 3;
				case "x":
					if (index + 2 >= input.value.length
						|| !isHex(input.value.charAt(index + 1))
						|| !isHex(input.value.charAt(index + 2))) {
						return failMapped("\\x must be followed by two hexadecimal digits", input, raw, position, escapeStart);
					}
					var code = hexValue(input.value.charAt(index + 1)) * 16 + hexValue(input.value.charAt(index + 2));
					if (code > 127) {
						return failMapped("hex escape values greater than \\x7f are not allowed", input, raw, position, escapeStart);
					}
					decoded = String.fromCharCode(code);
					consumed = 3;
				case "u":
					var unicode = readUnicodeEscape(input, index, raw, position);
					decoded = String.fromCharCode(unicode.code);
					consumed = unicode.consumed;
				default:
					return failMapped('invalid Haxe escape sequence \\$escaped', input, raw, position, escapeStart);
			}
			appendDecoded(result, source, decoded, input.source[escapeStart]);
			index += consumed;
		}
		return new MappedText(result.toString(), source, input.endSource);
	}

	static function readUnicodeEscape(input:MappedText, uIndex:Int, raw:String, position:Position):{code:Int, consumed:Int} {
		var start = uIndex - 1;
		if (uIndex + 1 < input.value.length && input.value.charAt(uIndex + 1) == "{") {
			var close = input.value.indexOf("}", uIndex + 2);
			if (close == -1 || close == uIndex + 2) {
				return failMapped("\\u{...} requires hexadecimal digits and a closing brace", input, raw, position, start);
			}
			var digits = input.value.substring(uIndex + 2, close);
			var code = parseHex(digits);
			if (code == null || code > 0x10FFFF) {
				return failMapped("unicode escape must be between \\u{0} and \\u{10FFFF}", input, raw, position, start);
			}
			validateUnicode(code, input, raw, position, start);
			return {code: code, consumed: close - uIndex + 1};
		}

		if (uIndex + 4 >= input.value.length) {
			return failMapped("\\u must be followed by four hexadecimal digits or {...}", input, raw, position, start);
		}
		var digits = input.value.substr(uIndex + 1, 4);
		var code = parseHex(digits);
		if (code == null) {
			return failMapped("\\u must be followed by four hexadecimal digits or {...}", input, raw, position, start);
		}
		validateUnicode(code, input, raw, position, start);
		return {code: code, consumed: 5};
	}

	static function validateUnicode(code:Int, input:MappedText, raw:String, position:Position, index:Int):Void {
		if (code >= 0xD800 && code < 0xE000) {
			failMapped("UTF-16 surrogates are not allowed in strings", input, raw, position, index);
		}
	}

	static function parseInterpolation(input:MappedText, raw:String, position:Position, haxeEscapes:Bool):Array<OutputPart> {
		var parts = [];
		var literal = new StringBuf();
		var literalSource = [];
		var literalEndSource = input.boundary(0);
		var index = 0;

		function flush():Void {
			var mapped = new MappedText(literal.toString(), literalSource, literalEndSource);
			var value = haxeEscapes ? decodeHaxeEscapes(mapped, raw, position).value : mapped.value;
			if (value.length > 0 || parts.length == 0) {
				parts.push(Text(value));
			}
			literal = new StringBuf();
			literalSource = [];
		}

		function appendLiteral(value:String, sourceIndex:Int, endSource:Int):Void {
			literal.add(value);
			for (_ in 0...value.length) {
				literalSource.push(sourceIndex);
			}
			literalEndSource = endSource;
		}

		while (index < input.value.length) {
			if (input.value.charAt(index) != "$" || index + 1 >= input.value.length) {
				appendLiteral(input.value.charAt(index), input.source[index], input.boundary(index + 1));
				index++;
				continue;
			}

			var next = input.value.charAt(index + 1);
			if (next == "$") {
				appendLiteral("$", input.source[index], input.boundary(index + 2));
				index += 2;
				continue;
			}

			if (next == "{") {
				var close = findInterpolationClose(input, index + 1, raw, position);
				flush();
				var expressionStart = index + 2;
				var expressionPosition = mappedPosition(input, expressionStart, close, raw, position);
				var code = input.value.substring(expressionStart, close);
				if (StringTools.trim(code).length == 0) {
					return fail("interpolation expression cannot be empty", expressionPosition);
				}
				var expression = Context.parseInlineString(code, expressionPosition);
				parts.push(Interpolation(expression, index, close + 1));
				index = close + 1;
				literalEndSource = input.boundary(index);
				continue;
			}

			if (isIdentifierStart(next)) {
				flush();
				var end = index + 2;
				while (end < input.value.length && isIdentifierPart(input.value.charAt(end))) {
					end++;
				}
				var expressionPosition = mappedPosition(input, index + 1, end, raw, position);
				var expression:Expr = {expr: EConst(CIdent(input.value.substring(index + 1, end))), pos: expressionPosition};
				parts.push(Interpolation(expression, index, end));
				index = end;
				literalEndSource = input.boundary(index);
				continue;
			}

			appendLiteral("$", input.source[index], input.boundary(index + 1));
			index++;
		}
		flush();
		return parts;
	}

	static function findInterpolationClose(input:MappedText, open:Int, raw:String, position:Position):Int {
		var depth = 1;
		var index = open + 1;
		while (index < input.value.length) {
			var character = input.value.charAt(index);
			if (character == "\"" || character == "'") {
				index = skipQuotedExpression(input.value, index, character);
				continue;
			}
			if (character == "~" && index + 1 < input.value.length && input.value.charAt(index + 1) == "/") {
				index = skipRegularExpression(input.value, index);
				continue;
			}
			if (character == "/" && index + 1 < input.value.length) {
				var next = input.value.charAt(index + 1);
				if (next == "/") {
					index = skipLineComment(input.value, index);
					continue;
				}
				if (next == "*") {
					index = skipBlockComment(input.value, index);
					continue;
				}
			}

			switch character {
				case "{":
					depth++;
				case "}":
					depth--;
					if (depth == 0) {
						return index;
					}
				default:
			}
			index++;
		}
		return fail("unclosed interpolation brace", mappedPosition(input, open, open + 1, raw, position));
	}

	static function skipQuotedExpression(value:String, start:Int, quote:String):Int {
		var index = start + 1;
		while (index < value.length) {
			var character = value.charAt(index);
			if (character == "\\") {
				index += 2;
			} else {
				index++;
				if (character == quote) {
					break;
				}
			}
		}
		return index;
	}

	static function skipRegularExpression(value:String, start:Int):Int {
		var index = start + 2;
		var inCharacterClass = false;
		while (index < value.length) {
			var character = value.charAt(index);
			if (character == "\\") {
				index += 2;
				continue;
			}
			if (character == "[") {
				inCharacterClass = true;
			} else if (character == "]") {
				inCharacterClass = false;
			} else if (character == "/" && !inCharacterClass) {
				index++;
				while (index < value.length && isIdentifierPart(value.charAt(index))) {
					index++;
				}
				break;
			}
			index++;
		}
		return index;
	}

	static function skipLineComment(value:String, start:Int):Int {
		var index = start + 2;
		while (index < value.length && value.charAt(index) != "\r" && value.charAt(index) != "\n") {
			index++;
		}
		return index;
	}

	static function skipBlockComment(value:String, start:Int):Int {
		var depth = 1;
		var index = start + 2;
		while (index < value.length && depth > 0) {
			var character = value.charAt(index);
			var next = index + 1 < value.length ? value.charAt(index + 1) : "";
			if (character == "/" && next == "*") {
				depth++;
				index += 2;
			} else if (character == "*" && next == "/") {
				depth--;
				index += 2;
			} else {
				index++;
			}
		}
		return index;
	}

	static function trimOutput(parts:Array<OutputPart>):Array<OutputPart> {
		if (parts.length == 0) {
			return parts;
		}
		switch parts[0] {
			case Text(value):
				var start = 0;
				while (start < value.length && StringTools.isSpace(value, start)) {
					start++;
				}
				parts[0] = Text(value.substr(start));
			default:
		}

		var last = parts.length - 1;
		switch parts[last] {
			case Text(value):
				var end = value.length;
				while (end > 0 && StringTools.isSpace(value, end - 1)) {
					end--;
				}
				parts[last] = Text(value.substr(0, end));
			default:
		}
		return parts;
	}

	static function buildExpression(parts:Array<OutputPart>, source:MappedText, reindent:Bool, position:Position):Expr {
		var expressions:Array<Expr> = [];
		var pendingText = new StringBuf();

		function flushText(force:Bool = false):Void {
			var value = pendingText.toString();
			if (value.length > 0 || force) {
				expressions.push(Context.makeExpr(value, position));
			}
			pendingText = new StringBuf();
		}

		for (part in parts) {
			switch part {
				case Text(value):
					pendingText.add(value);
				case Interpolation(expression, start, end):
					flushText(expressions.length == 0);
					if (reindent) {
						var indent = blockIndent(source.value, start, end);
						if (indent != null && indent.length > 0) {
							expression = macro @:pos(expression.pos) herex.HeredocRuntime.reindent($expression, $v{indent});
						}
					}
					expressions.push(expression);
			}
		}
		flushText(expressions.length == 0);

		if (expressions.length == 1) {
			return expressions[0];
		}
		var result = expressions[0];
		for (index in 1...expressions.length) {
			result = {expr: EBinop(OpAdd, result, expressions[index]), pos: position};
		}
		return result;
	}

	static function blockIndent(source:String, start:Int, end:Int):Null<String> {
		if (source.substring(start, end).indexOf("\n") != -1) {
			return null;
		}
		var lineStart = source.lastIndexOf("\n", start - 1) + 1;
		var newline = source.indexOf("\n", end);
		var lineEnd = newline == -1 ? source.length : newline;
		var before = source.substring(lineStart, start);
		var after = source.substring(end, lineEnd);
		return isHorizontalBlank(before, 0, before.length) && isHorizontalBlank(after, 0, after.length) ? before : null;
	}

	static function withTrailingNewlines(value:String, count:Int):String {
		var end = value.length;
		while (end > 0) {
			var character = value.charAt(end - 1);
			if (character != "\r" && character != "\n") {
				break;
			}
			end--;
		}
		var result = new StringBuf();
		result.add(value.substr(0, end));
		for (_ in 0...count) {
			result.add("\n");
		}
		return result.toString();
	}

	static function appendRange(result:StringBuf, source:Array<Int>, input:MappedText, start:Int, end:Int):Void {
		if (end <= start) {
			return;
		}
		result.add(input.value.substring(start, end));
		for (index in start...end) {
			source.push(input.source[index]);
		}
	}

	static function appendDecoded(result:StringBuf, source:Array<Int>, value:String, rawIndex:Int):Void {
		result.add(value);
		for (_ in 0...value.length) {
			source.push(rawIndex);
		}
	}

	static function commonPrefix(left:String, right:String):String {
		var length = left.length < right.length ? left.length : right.length;
		var index = 0;
		while (index < length && left.charAt(index) == right.charAt(index)) {
			index++;
		}
		return left.substr(0, index);
	}

	static function mappedPosition(input:MappedText, start:Int, end:Int, raw:String, outer:Position):Position {
		return rawPosition(raw, outer, input.boundary(start), input.boundary(end));
	}

	static function rawPosition(raw:String, outer:Position, start:Int, end:Int):Position {
		var info = Context.getPosInfos(outer);
		var byteStart = Bytes.ofString(raw.substring(0, start)).length;
		var byteEnd = Bytes.ofString(raw.substring(0, end)).length;
		return Context.makePosition({file: info.file, min: info.min + byteStart, max: info.min + byteEnd});
	}

	static function failAt(message:String, raw:String, position:Position, start:Int, end:Int):Dynamic {
		return fail(message, rawPosition(raw, position, start, end > start ? end : start + 1));
	}

	static function failMapped(message:String, input:MappedText, raw:String, position:Position, index:Int):Dynamic {
		return failAt(message, raw, position, input.boundary(index), input.boundary(index + 1));
	}

	static function fail(message:String, position:Position):Dynamic {
		Context.error('Herex: $message', position);
		return null;
	}

	static function skipSpaces(value:String, index:Int):Int {
		while (index < value.length && isSpace(value.charAt(index))) {
			index++;
		}
		return index;
	}

	static function isSpace(character:String):Bool {
		return character == " " || character == "\t" || character == "\r" || character == "\n";
	}

	static function isHorizontalSpace(character:String):Bool {
		return character == " " || character == "\t";
	}

	static function isHorizontalBlank(value:String, start:Int, end:Int):Bool {
		for (index in start...end) {
			if (!isHorizontalSpace(value.charAt(index))) {
				return false;
			}
		}
		return true;
	}

	static function isNameStart(character:String):Bool {
		return isIdentifierStart(character);
	}

	static function isNamePart(character:String):Bool {
		return isIdentifierPart(character) || character == "-";
	}

	static function isValidTagName(value:String):Bool {
		if (value.length == 0 || !isNameStart(value.charAt(0))) {
			return false;
		}
		for (index in 1...value.length) {
			if (!isNamePart(value.charAt(index))) {
				return false;
			}
		}
		return true;
	}

	static function isIdentifierStart(character:String):Bool {
		return (character >= "a" && character <= "z") || (character >= "A" && character <= "Z") || character == "_";
	}

	static function isIdentifierPart(character:String):Bool {
		return isIdentifierStart(character) || (character >= "0" && character <= "9");
	}

	static function isOctal(character:String):Bool {
		return character >= "0" && character <= "7";
	}

	static function octalValue(character:String):Int {
		return character.charCodeAt(0) - "0".code;
	}

	static function isHex(character:String):Bool {
		return (character >= "0" && character <= "9") || (character >= "a" && character <= "f") || (character >= "A" && character <= "F");
	}

	static function hexValue(character:String):Int {
		var code = character.charCodeAt(0);
		if (character >= "0" && character <= "9") {
			return code - "0".code;
		}
		if (character >= "a" && character <= "f") {
			return code - "a".code + 10;
		}
		return code - "A".code + 10;
	}

	static function parseHex(value:String):Null<Int> {
		if (value.length == 0) {
			return null;
		}
		var result = 0;
		for (index in 0...value.length) {
			var character = value.charAt(index);
			if (!isHex(character)) {
				return null;
			}
			result = result * 16 + hexValue(character);
		}
		return result;
	}
}
#end
