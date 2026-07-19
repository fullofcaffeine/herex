class MissingMargin {
	static function main():Void {
		var value = <heredoc margin="|">
			|valid
			missing
		</heredoc>;
	}
}
