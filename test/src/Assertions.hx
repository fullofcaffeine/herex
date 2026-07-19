package;

class Assertions {
	static var count = 0;

	public static function equal(expected:String, actual:String, label:String):Void {
		count++;
		if (expected != actual) {
			throw '$label\nexpected: ${inspect(expected)}\n  actual: ${inspect(actual)}';
		}
	}

	public static function value<T>(expected:T, actual:T, label:String):Void {
		count++;
		if (expected != actual) {
			throw '$label\nexpected: $expected\n  actual: $actual';
		}
	}

	public static function finish():Void {
		trace('Herex assertions passed: $count');
	}

	static function inspect(value:String):String {
		return haxe.Json.stringify(value);
	}
}
