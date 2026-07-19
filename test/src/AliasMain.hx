package;

class AliasMain {
	static function main():Void {
		var name = "alias";
		Assertions.equal("configured alias\n", <h newline>configured $name</h>, "configured project alias");
		Assertions.finish();
	}
}
