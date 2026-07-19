class InvalidNewlineCount {
	static function main():Void {
		var value = <heredoc newlines={-1}>text</heredoc>;
	}
}
