/**
 * # Heredoc - Multi-line String Literals with Interpolation for Haxe
 *
 * This module provides heredoc-style multi-line strings with variable interpolation,
 * built on top of `tink_hxx` for parsing.
 *
 * ## What is a Heredoc?
 *
 * A heredoc (here-document) is a way to define multi-line string literals with:
 * - Preserved whitespace, formatting, and linebreaks
 * - Variable interpolation (`$name` or `${expression}`)
 * - Optional whitespace normalization (dedent, trim)
 *
 * ## Why Use This?
 *
 * Haxe's built-in string literals have limitations:
 * - Single-line strings require escape sequences for newlines
 * - Multi-line strings (with `'...'`) don't support interpolation
 * - Template strings require manual concatenation
 *
 * Heredoc solves this by leveraging Haxe's markup literal syntax and tink_hxx parsing.
 *
 * ## Usage (Preferred: Direct Syntax)
 *
 * With SyntaxHub configured, write heredocs directly without any wrapper:
 *
 * ```haxe
 * var name = "World";
 * var greeting = <heredoc>Hello $name!</heredoc>;
 * trace(greeting);  // "Hello World!"
 *
 * // Multi-line with preserved linebreaks
 * var poem = <heredoc>Roses are red,
 * Violets are blue,
 * $name is awesome!</heredoc>;
 *
 * // Expression interpolation
 * var math = <heredoc>2 + 2 = ${2 + 2}</heredoc>;
 *
 * // With dedent-trim mode
 * var sql = <heredoc mode="dedent-trim">
 *   SELECT *
 *   FROM users
 *   WHERE active = true
 * </heredoc>;
 *
 * // Literal dollar signs with $$
 * var price = <heredoc>Price: $$99.99</heredoc>;
 * ```
 *
 * **Required build.hxml setup:**
 * ```
 * -lib tink_hxx
 * -lib tink_macro
 * -lib tink_syntaxhub
 * --macro tink.SyntaxHub.use()
 * --macro HeredocSyntax.use()
 * ```
 *
 * ## Alternative: Explicit Macro
 *
 * If you can't use SyntaxHub, call the macro explicitly:
 * ```haxe
 * var text = Heredoc.hxx(<heredoc>Hello $name!</heredoc>);
 * ```
 *
 * ## How It Works
 *
 * 1. Haxe's parser recognizes `<heredoc>...</heredoc>` as a markup literal
 * 2. SyntaxHub's `HeredocSyntax` plugin intercepts `@:markup` expressions
 * 3. tink_hxx parses content (with Preserve whitespace mode), splitting text and interpolations
 * 4. The `heredoc` function receives children as `Array<Any>`
 * 5. Children are converted to strings with `Std.string()` and joined
 *
 * ### Why Array<Any>?
 *
 * When tink_hxx parses `Hello $name!`, it creates multiple children:
 * - CText("Hello ")
 * - CExpr(name)  // the variable reference
 * - CText("!")
 *
 * Using `Array<Any>` allows us to accept any expression type (String, Int, Bool, etc.)
 * and convert them all to strings.
 *
 * @see HeredocSyntax For the SyntaxHub plugin that enables direct syntax
 * @see https://github.com/haxetink/tink_hxx The underlying HXX parser
 */
#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;

using tink.MacroApi;
#end

/**
 * Main heredoc implementation class.
 *
 * Provides both the runtime `heredoc()` function that processes content,
 * and the compile-time `hxx()` macro that parses the HXX syntax.
 */
class Heredoc {
  /**
   * Runtime function that processes heredoc content.
   *
   * This function is called by the generated code after tink_hxx parses the
   * `<heredoc>` tag. It receives the parsed children and optional mode attribute.
   *
   * ## Parameters
   *
   * @param attr Anonymous object containing:
   *   - `mode` (optional): Whitespace handling mode
   *     - `null` or `"preserve"`: Keep all whitespace as-is (default)
   *     - `"dedent"`: Remove common leading indentation from all lines
   *     - `"trim"`: Trim leading/trailing whitespace from entire string
   *     - `"dedent-trim"`: Apply dedent, then trim
   *   - `children`: Array of content pieces (text and interpolated values)
   *     Automatically populated by tink_hxx from the tag's content.
   *
   * @return The assembled string with all children joined and whitespace processed
   *
   * ## How Children Work
   *
   * For `<heredoc>Hello $name, you have ${count} items</heredoc>`:
   *
   * tink_hxx parses this into children array:
   * ```
   * ["Hello ", name, ", you have ", count, " items"]
   * ```
   *
   * We convert each to string and join:
   * ```
   * "Hello " + Std.string(name) + ", you have " + Std.string(count) + " items"
   * ```
   */
  public static function heredoc(attr:{?mode:String, children:Array<Any>}):String {
    // Convert all children to strings and concatenate
    var raw = [for (c in attr.children) Std.string(c)].join("");

    // Apply whitespace processing based on mode
    return switch attr.mode {
      case "dedent": dedentString(raw);
      case "trim": StringTools.trim(raw);
      case "dedent-trim": StringTools.trim(dedentString(raw));
      default: raw; // "preserve" or null - keep as-is
    };
  }

  /**
   * Removes common leading indentation from all lines in a string.
   *
   * This is useful for heredocs embedded in indented code blocks, allowing
   * the content to align with the surrounding code while producing clean output.
   *
   * ## Algorithm
   *
   * 1. Split string into lines
   * 2. Find the minimum indentation across all non-empty lines (skipping first line
   *    which tink_hxx may have already trimmed)
   * 3. Remove that many spaces/tabs from the start of each line
   *
   * ## Example
   *
   * Input (6 spaces of indentation):
   * ```
   * "Line 1
   *       Line 2
   *       Line 3"
   * ```
   *
   * Output (indentation removed):
   * ```
   * "Line 1
   * Line 2
   * Line 3"
   * ```
   *
   * @param s The string to dedent
   * @return The dedented string with common indentation removed
   */
  static function dedentString(s:String):String {
    var lines = s.split("\n");
    if (lines.length <= 1) return s;

    // Find minimum indentation (ignoring empty lines and first line)
    // First line is skipped because tink_hxx often trims its leading whitespace
    var minIndent = 999999;
    var isFirst = true;
    for (line in lines) {
      if (StringTools.trim(line).length == 0) continue;
      if (isFirst) { isFirst = false; continue; }

      var indent = 0;
      for (i in 0...line.length) {
        if (line.charAt(i) == " ") indent++;
        else if (line.charAt(i) == "\t") indent += 4; // Tab = 4 spaces
        else break;
      }
      if (indent < minIndent) minIndent = indent;
    }

    // If no indentation found or only first line has content, return as-is
    if (minIndent == 0 || minIndent == 999999) return s;

    // Remove the common indentation from each line
    var result = [];
    isFirst = true;
    for (line in lines) {
      if (isFirst) {
        result.push(line); // Keep first line as-is
        isFirst = false;
        continue;
      }
      if (StringTools.trim(line).length == 0) {
        result.push(""); // Empty lines become truly empty
      } else {
        // Remove up to minIndent characters of whitespace
        var removed = 0;
        var start = 0;
        for (i in 0...line.length) {
          if (removed >= minIndent) break;
          if (line.charAt(i) == " ") { removed++; start++; }
          else if (line.charAt(i) == "\t") { removed += 4; start++; }
          else break;
        }
        result.push(line.substr(start));
      }
    }
    return result.join("\n");
  }

  #if macro
  /**
   * Creates a tink_hxx Tag definition for the `<heredoc>` tag.
   *
   * This is called during macro expansion to register `heredoc` as a valid
   * HXX tag that maps to `Heredoc.heredoc()`.
   *
   * ## Why This is Needed
   *
   * tink_hxx resolves tag names to functions. When it sees `<heredoc>`, it needs
   * to know which function to call. This method:
   *
   * 1. Looks up the `Heredoc` class type
   * 2. Finds the `heredoc` static function
   * 3. Creates a Tag declaration with path "Heredoc.heredoc"
   *
   * The full path ensures the generated code can find the function regardless
   * of imports in the user's code.
   *
   * @param pos The source position for error reporting
   * @return A Tag definition for the heredoc function, or null if not found
   */
  static function getHeredocTag(pos:haxe.macro.Expr.Position):tink.hxx.Tag {
    var type = Context.getType("Heredoc");
    var classType = switch type {
      case TInst(r, _): r.get();
      default: null;
    };
    if (classType == null) return null;

    for (f in classType.statics.get()) {
      if (f.name == "heredoc") {
        // Use full path so generated code doesn't need imports
        return tink.hxx.Tag.declaration("Heredoc.heredoc", pos, f.type, []);
      }
    }
    return null;
  }
  #end

  /**
   * Compile-time macro that parses HXX heredoc syntax.
   *
   * This is the main entry point for heredoc processing. It:
   *
   * 1. Registers the `heredoc` tag with tink_hxx's generator
   * 2. Parses the input expression as HXX markup
   * 3. Returns generated code that calls `Heredoc.heredoc()`
   *
   * ## Usage
   *
   * ```haxe
   * var text = Heredoc.hxx(<heredoc>Hello $name!</heredoc>);
   * ```
   *
   * ## What Gets Generated
   *
   * For `<heredoc>Hello $name!</heredoc>`, this macro generates approximately:
   *
   * ```haxe
   * Heredoc.heredoc({
   *   mode: null,
   *   children: ["Hello ", name, "!"]
   * })
   * ```
   *
   * The actual generated code uses tink_hxx's optimized array building.
   *
   * ## Direct Syntax Alternative
   *
   * If you enable `HeredocSyntax` via SyntaxHub, you can skip this wrapper:
   * ```haxe
   * var text = <heredoc>Hello $name!</heredoc>;  // No Heredoc.hxx() needed
   * ```
   *
   * @param e The expression containing the `<heredoc>` markup
   * @return Generated code that evaluates to the interpolated string
   *
   * @see HeredocSyntax For enabling direct syntax without the wrapper
   */
  public macro static function hxx(e:Expr):Expr {
    // Register heredoc as a known tag with tink_hxx
    var defaults = [new tink.core.Named("heredoc", getHeredocTag)];

    // Create generator context with our defaults
    var ctx = new tink.hxx.Generator(defaults).createContext();

    // Parse and generate code with Preserve whitespace mode
    // Unlike JSX, heredocs must preserve linebreaks around interpolations
    return ctx.generateRoot(tink.hxx.Parser.parseRoot(e, {
      defaultExtension: 'hxx',
      noControlStructures: false,
      defaultSwitchTarget: macro __data__,
      isVoid: ctx.isVoid,
      fragment: null,
      whitespace: tink.hxx.Parser.ParseWhitespace.Preserve,
      treatNested: function(children) return ctx.generateRoot.bind(children).bounce(),
    }));
  }
}
