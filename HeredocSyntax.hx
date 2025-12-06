#if macro
package;

import haxe.macro.Expr;
import haxe.macro.Context;
import tink.macro.ClassBuilder;

using tink.MacroApi;

/**
 * SyntaxHub plugin that enables the preferred direct herex syntax.
 *
 * This plugin allows you to write heredocs naturally without any wrapper:
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
 * // With whitespace mode
 * var sql = <heredoc mode="dedent-trim">
 *   SELECT * FROM users
 *   WHERE active = true
 * </heredoc>;
 * ```
 *
 * ## Setup (Required)
 *
 * Add to your `build.hxml`:
 * ```
 * -lib tink_hxx
 * -lib tink_macro
 * -lib tink_syntaxhub
 * --macro tink.SyntaxHub.use()
 * --macro HeredocSyntax.use()
 * ```
 *
 * ## Why SyntaxHub?
 *
 * Haxe 4+ has built-in support for XML/markup literals. When you write
 * `<heredoc>...</heredoc>`, the parser recognizes it and wraps it with
 * `@:markup` metadata. However, markup literals **must** be processed by a macro.
 *
 * SyntaxHub (`tink_syntaxhub`) provides a global build macro system that:
 * - Registers expression-level transformation plugins
 * - Automatically processes ALL expressions in ALL classes
 * - Allows this plugin to intercept `@:markup` expressions containing `<heredoc>`
 *
 * ## How It Works
 *
 * 1. `HeredocSyntax.use()` registers `HeredocRule` with SyntaxHub's expression queue
 * 2. For every expression in your code, SyntaxHub calls `HeredocRule.apply()`
 * 3. When we find `@:markup` containing `<heredoc...>`, we transform it to `Heredoc.hxx(...)`
 * 4. The transformed code is then compiled normally
 *
 * @see Heredoc The main heredoc implementation
 * @see https://haxe.org/manual/lf-markup.html - Haxe markup literals
 * @see https://github.com/haxetink/tink_syntaxhub - SyntaxHub documentation
 */
class HeredocSyntax {
  /**
   * Registers the HeredocRule with SyntaxHub's expression-level transformation queue.
   *
   * Call this from build.hxml:
   * ```
   * --macro HeredocSyntax.use()
   * ```
   *
   * Must be called AFTER `tink.SyntaxHub.use()`.
   */
  public static function use() {
    tink.SyntaxHub.exprLevel.inward.whenever(new HeredocRule());
  }
}

/**
 * Expression-level transformation rule for heredoc markup.
 *
 * Implements `tink.syntaxhub.ExprLevelRule` interface:
 * - `appliesTo(c)` - Returns true for all classes (heredoc available everywhere)
 * - `apply(e)` - Transforms `@:markup "<heredoc>..."` to `Heredoc.hxx(...)`
 */
class HeredocRule {
  public function new() {}

  /**
   * Determines if this rule applies to the given class.
   * @param c The class being built
   * @return true - heredoc syntax is available in all classes
   */
  public function appliesTo(c:ClassBuilder):Bool {
    return true;
  }

  /**
   * Transforms heredoc markup expressions.
   *
   * When the Haxe parser encounters `<heredoc>...</heredoc>`, it creates:
   * ```
   * @:markup "<heredoc>...</heredoc>"
   * ```
   *
   * This method transforms that into:
   * ```
   * Heredoc.hxx("<heredoc>...</heredoc>")
   * ```
   *
   * Non-heredoc markup (e.g., `<div>`, `<span>`) is left unchanged for other
   * processors (like tink_hxx for HTML).
   *
   * @param e The expression to potentially transform
   * @return The transformed expression, or the original if not a heredoc
   */
  public function apply(e:Expr):Expr {
    return switch e {
      case macro @:markup $v:
        // Extract the string content from the markup
        var str = switch v.expr {
          case EConst(CString(s, _)): s;
          default: null;
        };

        // Only transform if it's a <heredoc> tag
        if (str != null && StringTools.startsWith(StringTools.ltrim(str), "<heredoc")) {
          // Adjust position to include the < and > that the parser stripped
          var adjusted = {
            expr: v.expr,
            pos: {
              var p = Context.getPosInfos(v.pos);
              Context.makePosition({
                file: p.file,
                min: p.min - 1,
                max: p.max + 1,
              });
            }
          };
          // Transform to Heredoc.hxx() call
          macro @:pos(e.pos) Heredoc.hxx($adjusted);
        } else {
          e; // Not a heredoc tag, leave unchanged for other processors
        }
      default:
        e; // Not markup, leave unchanged
    };
  }
}
#end

