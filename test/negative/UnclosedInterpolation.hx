class UnclosedInterpolation {
	static function main():Void {
		var value = <heredoc>${if (true) { "value"}</heredoc>;
	}
}
