class InvalidEscape {
	static function main():Void {
		var value = <heredoc escapes="haxe">bad\q</heredoc>;
	}
}
