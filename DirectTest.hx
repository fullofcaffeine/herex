// Test direct markup syntax: var foo = <heredoc>...</heredoc>

class DirectTest {
  public static function main() {
    var name = "World";
    var count = 42;

    // Direct syntax - no Heredoc.hxx() wrapper needed!
    var text1 = <heredoc>Hello $name!</heredoc>;
    trace("Test 1: " + text1);

    // Expression interpolation
    var text2 = <heredoc>The answer is ${count + 8}.</heredoc>;
    trace("Test 2: " + text2);

    // Multiline
    var text3 = <heredoc>
      Line 1
      Line 2 with $name
    </heredoc>;
    trace("Test 3: [" + text3 + "]");

    // With mode attribute
    var text4 = <heredoc mode="dedent-trim">
      Dedented line 1
      Dedented line 2
    </heredoc>;
    trace("Test 4: [" + text4 + "]");

    // Dollar escaping
    var text5 = <heredoc>Price: $$99.99</heredoc>;
    trace("Test 5: " + text5);

    trace("\nAll direct syntax tests passed!");
  }
}
