package herex;

/** Runtime support used only when a dynamic heredoc needs post-processing. */
@:noCompletion
class HeredocRuntime {
	public static function reindent(value:Dynamic, indent:String):String {
		var text = Std.string(value);
		if (indent.length == 0 || text.length == 0) {
			return text;
		}

		var result = new StringBuf();
		var index = 0;
		while (index < text.length) {
			var character = text.charAt(index);
			if (character == "\r" && index + 1 < text.length && text.charAt(index + 1) == "\n") {
				result.add("\r\n");
				index += 2;
				if (index < text.length && text.charAt(index) != "\r" && text.charAt(index) != "\n") {
					result.add(indent);
				}
				continue;
			}

			result.add(character);
			index++;
			if ((character == "\r" || character == "\n")
				&& index < text.length
				&& text.charAt(index) != "\r"
				&& text.charAt(index) != "\n") {
				result.add(indent);
			}
		}
		return result.toString();
	}

	public static function withTrailingNewlines(value:String, count:Int):String {
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
}
