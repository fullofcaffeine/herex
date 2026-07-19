package;

class DirectMacroMain {
	static function main():Void {
		var name = "direct";
		Assertions.equal("direct macro", Heredoc.hxx(<heredoc>$name macro</heredoc>), "explicit macro without global registration");
		Assertions.finish();
	}
}
