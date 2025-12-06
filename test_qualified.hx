class TestQualified {
  public static function main() {
    var name = "bd";
    var text = Heredoc.hxx(<Heredoc.heredoc>Hello $name</Heredoc.heredoc>);
    trace(text);
  }
}
