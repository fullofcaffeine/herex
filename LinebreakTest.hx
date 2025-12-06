// Test linebreak handling in heredoc
// Verifies that heredocs preserve newlines like Node.js template literals

class LinebreakTest {
  public static function main() {
    var name = "World";
    var passed = 0;
    var total = 6;

    // Test 1: Explicit linebreaks
    var text1 = Heredoc.hxx(<heredoc>Line 1
Line 2
Line 3</heredoc>);
    if (text1.split("\n").length == 3) { passed++; trace("Test 1 PASS: Explicit linebreaks"); }
    else trace("Test 1 FAIL: Expected 3 lines, got " + text1.split("\n").length);

    // Test 2: Linebreak BEFORE variable
    var text2 = Heredoc.hxx(<heredoc>Before
$name</heredoc>);
    if (text2.split("\n").length == 2) { passed++; trace("Test 2 PASS: Linebreak before variable"); }
    else trace("Test 2 FAIL: Expected 2 lines, got " + text2.split("\n").length);

    // Test 3: Linebreak AFTER variable
    var text3 = Heredoc.hxx(<heredoc>$name
After</heredoc>);
    if (text3.split("\n").length == 2) { passed++; trace("Test 3 PASS: Linebreak after variable"); }
    else trace("Test 3 FAIL: Expected 2 lines, got " + text3.split("\n").length);

    // Test 4: Linebreaks AROUND variable
    var text4 = Heredoc.hxx(<heredoc>Before
$name
After</heredoc>);
    if (text4.split("\n").length == 3) { passed++; trace("Test 4 PASS: Linebreaks around variable"); }
    else trace("Test 4 FAIL: Expected 3 lines, got " + text4.split("\n").length);

    // Test 5: Dedent-trim preserves internal newlines
    var text5 = Heredoc.hxx(<heredoc mode="dedent-trim">
      Line A
      Line B
      Line C
    </heredoc>);
    if (text5.split("\n").length == 3) { passed++; trace("Test 5 PASS: dedent-trim preserves newlines"); }
    else trace("Test 5 FAIL: Expected 3 lines, got " + text5.split("\n").length);

    // Test 6: Complex expression with linebreaks
    var arr = [1, 2, 3];
    var text6 = Heredoc.hxx(<heredoc>First: ${arr[0]}
Second: ${arr[1]}
Third: ${arr[2]}</heredoc>);
    if (text6.split("\n").length == 3 && text6 == "First: 1\nSecond: 2\nThird: 3") {
      passed++; trace("Test 6 PASS: Complex expressions with linebreaks");
    } else trace("Test 6 FAIL: Got [" + text6 + "]");

    trace("\nLinebreak tests: " + passed + "/" + total + " passed");
    if (passed == total) trace("All linebreak tests passed!");
  }
}
