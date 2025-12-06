/**
 * # herex - Multi-line String Literals with Interpolation for Haxe
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
 * ## How It Works (Compile-Time Optimization)
 *
 * The macro generates efficient code at compile time:
 *
 * 1. `<heredoc>Hello $name!</heredoc>` compiles to `"Hello " + name + "!"`
 * 2. Static heredocs become string literals: `<heredoc>Hello!</heredoc>` → `"Hello!"`
 * 3. Whitespace modes (dedent/trim) are applied at compile time when possible
 *
 * No runtime overhead for simple cases - just plain string concatenation.
 *
 * @see HeredocSyntax For the SyntaxHub plugin that enables direct syntax
 * @see https://github.com/haxetink/tink_hxx The underlying HXX parser
 */
#if macro
import haxe.macro.Expr;
import haxe.macro.Context;

using tink.MacroApi;
#end

/**
 * Main heredoc implementation class.
 *
 * Provides the compile-time `hxx()` macro that parses heredoc syntax and
 * generates optimized string concatenation code.
 */
class Heredoc {
  #if macro
  /**
   * Removes common leading indentation from all lines in a string.
   * Compile-time version for use in macros.
   */
  static function dedentString(s:String):String {
    var lines = s.split("\n");
    if (lines.length <= 1) return s;

    // Find minimum indentation (ignoring empty lines and first line)
    var minIndent = 999999;
    var isFirst = true;
    for (line in lines) {
      if (StringTools.trim(line).length == 0) continue;
      if (isFirst) { isFirst = false; continue; }

      var indent = 0;
      for (i in 0...line.length) {
        var c = line.charAt(i);
        if (c == " ") indent++;
        else if (c == "\t") indent += 4;
        else break;
      }
      if (indent < minIndent) minIndent = indent;
    }

    if (minIndent == 0 || minIndent == 999999) return s;

    // Remove the common indentation from each line
    var result = [];
    isFirst = true;
    for (line in lines) {
      if (isFirst) {
        result.push(line);
        isFirst = false;
        continue;
      }
      if (StringTools.trim(line).length == 0) {
        result.push("");
      } else {
        var removed = 0;
        var start = 0;
        for (i in 0...line.length) {
          if (removed >= minIndent) break;
          var c = line.charAt(i);
          if (c == " ") { removed++; start++; }
          else if (c == "\t") { removed += 4; start++; }
          else break;
        }
        result.push(line.substr(start));
      }
    }
    return result.join("\n");
  }

  /**
   * Apply whitespace mode to a string at compile time.
   */
  static function applyMode(s:String, mode:String):String {
    return switch mode {
      case "dedent": dedentString(s);
      case "trim": StringTools.trim(s);
      case "dedent-trim": StringTools.trim(dedentString(s));
      default: s;
    };
  }

  /**
   * Build a concatenation expression from parts.
   * Optimizes by combining adjacent string literals.
   */
  static function buildConcat(parts:Array<Expr>, pos:Position):Expr {
    if (parts.length == 0) return macro @:pos(pos) "";
    if (parts.length == 1) return parts[0];

    // Optimize: combine adjacent string literals
    var optimized:Array<Expr> = [];
    var currentStr:String = null;
    var currentPos:Position = null;

    for (part in parts) {
      switch part.expr {
        case EConst(CString(s, _)):
          if (currentStr == null) {
            currentStr = s;
            currentPos = part.pos;
          } else {
            currentStr += s;
          }
        default:
          if (currentStr != null) {
            optimized.push({ expr: EConst(CString(currentStr, null)), pos: currentPos });
            currentStr = null;
          }
          optimized.push(part);
      }
    }
    if (currentStr != null) {
      optimized.push({ expr: EConst(CString(currentStr, null)), pos: currentPos });
    }

    if (optimized.length == 0) return macro @:pos(pos) "";
    if (optimized.length == 1) return optimized[0];

    // Build the concatenation chain
    var result = optimized[0];
    for (i in 1...optimized.length) {
      result = macro @:pos(pos) $result + ${optimized[i]};
    }
    return result;
  }
  #end

  /**
   * Compile-time macro that parses HXX heredoc syntax.
   *
   * Generates optimized code:
   * - `<heredoc>Hello $name!</heredoc>` → `"Hello " + name + "!"`
   * - `<heredoc>Static text</heredoc>` → `"Static text"`
   * - Whitespace modes applied at compile time when possible
   *
   * @param e The expression containing the `<heredoc>` markup
   * @return Generated string concatenation expression
   */
  public macro static function hxx(e:Expr):Expr {
    // Parse the heredoc using tink_hxx
    var parsed = tink.hxx.Parser.parseRoot(e, {
      defaultExtension: 'hxx',
      noControlStructures: true,
      defaultSwitchTarget: null,
      isVoid: function(_) return false,
      fragment: null,
      whitespace: tink.hxx.Parser.ParseWhitespace.Preserve,
      treatNested: null,
    });

    // Extract the heredoc node
    if (parsed.value.length != 1) {
      Context.error("Expected exactly one heredoc tag", e.pos);
      return macro "";
    }

    var node = parsed.value[0];
    var tagName:String = null;
    var mode:String = null;
    var children:Array<tink.hxx.Node.Child> = null;

    switch node.value {
      case CNode(n):
        tagName = n.name.value;
        children = n.children != null ? n.children.value : [];
        // Extract mode attribute
        if (n.attributes != null) {
          for (attr in n.attributes) {
            switch attr {
              case Regular(name, value) if (name.value == "mode"):
                switch value.expr {
                  case EConst(CString(s, _)): mode = s;
                  default:
                }
              default:
            }
          }
        }
      default:
        Context.error("Expected heredoc tag", e.pos);
        return macro "";
    }

    if (tagName != "heredoc") {
      Context.error('Expected <heredoc> tag, got <$tagName>', e.pos);
      return macro "";
    }

    // Check if all children are static (CText only)
    var allStatic = true;
    var staticParts:Array<String> = [];

    for (child in children) {
      switch child.value {
        case CText(t):
          staticParts.push(t.value);
        default:
          allStatic = false;
          break;
      }
    }

    // If all static, process at compile time
    if (allStatic) {
      var result = staticParts.join("");
      if (mode != null) {
        result = applyMode(result, mode);
      }
      return macro @:pos(e.pos) $v{result};
    }

    // Has expressions - generate concatenation
    var parts:Array<Expr> = [];

    for (child in children) {
      switch child.value {
        case CText(t):
          if (t.value.length > 0) {
            parts.push({ expr: EConst(CString(t.value, null)), pos: child.pos });
          }
        case CExpr(expr):
          // Wrap non-string expressions with Std.string()
          parts.push(macro @:pos(expr.pos) Std.string($expr));
        case CNode(n):
          Context.error("Nested tags not supported in heredoc", child.pos);
        default:
          Context.error("Unsupported child type in heredoc", child.pos);
      }
    }

    var concatExpr = buildConcat(parts, e.pos);

    // If mode is set, we need runtime processing for dedent
    // (can't dedent at compile time when expressions are involved)
    if (mode != null) {
      return switch mode {
        case "trim":
          macro @:pos(e.pos) StringTools.trim($concatExpr);
        case "dedent":
          macro @:pos(e.pos) Heredoc.dedentRuntime($concatExpr);
        case "dedent-trim":
          macro @:pos(e.pos) StringTools.trim(Heredoc.dedentRuntime($concatExpr));
        default:
          concatExpr;
      };
    }

    return concatExpr;
  }

  /**
   * Runtime dedent function - only used when expressions are present.
   * For static content, dedent is done at compile time.
   */
  public static function dedentRuntime(s:String):String {
    var lines = s.split("\n");
    if (lines.length <= 1) return s;

    var minIndent = 999999;
    var isFirst = true;
    for (line in lines) {
      if (StringTools.trim(line).length == 0) continue;
      if (isFirst) { isFirst = false; continue; }

      var indent = 0;
      for (i in 0...line.length) {
        var c = line.charAt(i);
        if (c == " ") indent++;
        else if (c == "\t") indent += 4;
        else break;
      }
      if (indent < minIndent) minIndent = indent;
    }

    if (minIndent == 0 || minIndent == 999999) return s;

    var result = [];
    isFirst = true;
    for (line in lines) {
      if (isFirst) {
        result.push(line);
        isFirst = false;
        continue;
      }
      if (StringTools.trim(line).length == 0) {
        result.push("");
      } else {
        var removed = 0;
        var start = 0;
        for (i in 0...line.length) {
          if (removed >= minIndent) break;
          var c = line.charAt(i);
          if (c == " ") { removed++; start++; }
          else if (c == "\t") { removed += 4; start++; }
          else break;
        }
        result.push(line.substr(start));
      }
    }
    return result.join("\n");
  }
}
