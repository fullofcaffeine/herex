class HeredocTest {
  public static function main() {
    var name = "bd";

    // Test 1: Static text
    var text1 = Heredoc.hxx(<heredoc>Hello World</heredoc>);
    trace("Test 1 (static): " + text1);

    // Test 2: With interpolation
    var text2 = Heredoc.hxx(<heredoc>Use $name for tracking</heredoc>);
    trace("Test 2 (interpolated): " + text2);

    // Test 3: Multiline with interpolation
    var text3 = Heredoc.hxx(<heredoc>
      Line 1
      Line 2 with $name
      Line 3
    </heredoc>);
    trace("Test 3 (multiline): [" + text3 + "]");

    // Test 4: Expression interpolation ${expr}
    var count = 5;
    var text4 = Heredoc.hxx(<heredoc>Total: ${count * 2} items</heredoc>);
    trace("Test 4 (expression): " + text4);

    // Test 5: Dedent mode - removes common indentation
    var text5 = Heredoc.hxx(<heredoc mode="dedent">
      Line A
      Line B
      Line C
    </heredoc>);
    trace("Test 5 (dedent): [" + text5 + "]");

    // Test 6: Trim mode - removes leading/trailing whitespace
    var text6 = Heredoc.hxx(<heredoc mode="trim">
      Trimmed content
    </heredoc>);
    trace("Test 6 (trim): [" + text6 + "]");

    // Test 7: DedentTrim mode - dedent and trim
    var text7 = Heredoc.hxx(<heredoc mode="dedent-trim">
      Line 1
      Line 2
    </heredoc>);
    trace("Test 7 (dedent-trim): [" + text7 + "]");

    // Test 8: Dollar sign escaping with $$
    var text8 = Heredoc.hxx(<heredoc>Price: $$100 and $$name literal</heredoc>);
    trace("Test 8 (escape $$): " + text8);

    // Test 9: Mixed escaped and interpolated
    var text9 = Heredoc.hxx(<heredoc>User $name has $$500 credit</heredoc>);
    trace("Test 9 (mixed): " + text9);

    // Test 10: Complex expressions
    var arr = [10, 20, 30];
    var text10 = Heredoc.hxx(<heredoc>First: ${arr[0]}, Sum: ${arr[0] + arr[1]}</heredoc>);
    trace("Test 10 (complex expr): " + text10);

    // Test 11: Multiple types (Bool, Float)
    var active = true;
    var price = 19.99;
    var text11 = Heredoc.hxx(<heredoc>Active: $active, Price: $price</heredoc>);
    trace("Test 11 (types): " + text11);

    // Test 12: Empty heredoc content
    var text12 = Heredoc.hxx(<heredoc></heredoc>);
    trace("Test 12 (empty): [" + text12 + "]");

    // Test 13: Consecutive interpolations (use ${} for adjacent)
    var a = "A";
    var b = "B";
    var text13 = Heredoc.hxx(<heredoc>${a}${b}${a}${b}</heredoc>);
    trace("Test 13 (consecutive): " + text13);

    trace("\nAll tests completed!");
  }
}
