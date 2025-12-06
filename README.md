# haxe_heredoc

Heredoc-like multi-line string literals with interpolation for Haxe, built on tink_hxx.

## Features

- **Native-feeling syntax** - write `<heredoc>...</heredoc>` directly in your code
- Multi-line strings with preserved formatting and linebreaks
- `$var` interpolation for simple variables
- `${expr}` interpolation for expressions (math, array access, etc.)
- `$$` for literal dollar signs
- Configurable whitespace handling (preserve, dedent, trim)
- Automatic type coercion (Int, Float, Bool → String)

## Installation

```bash
# Using lix (recommended)
lix scope create
lix install gh:haxetink/tink_hxx
lix install gh:haxetink/tink_syntaxhub
```

## Setup

Add to your `build.hxml`:

```
-lib tink_hxx
-lib tink_macro
-lib tink_syntaxhub
--macro tink.SyntaxHub.use()
--macro HeredocSyntax.use()
-main YourMain
--interp
```

## Usage

```haxe
class Example {
  public static function main() {
    var name = "World";
    var count = 42;

    // Simple interpolation
    var greeting = <heredoc>Hello $name!</heredoc>;
    trace(greeting);  // "Hello World!"

    // Expression interpolation
    var math = <heredoc>The answer is ${count * 2}.</heredoc>;
    trace(math);  // "The answer is 84."

    // Multi-line with preserved linebreaks
    var poem = <heredoc>Roses are red,
Violets are blue,
$name is awesome,
And so are you!</heredoc>;

    // Literal dollar signs
    var price = <heredoc>Total: $$${count}.00</heredoc>;
    trace(price);  // "Total: $42.00"
  }
}
```

## Whitespace Modes

| Mode | Description |
|------|-------------|
| (default) | Preserve all whitespace as-is |
| `dedent` | Remove common leading indentation |
| `trim` | Trim leading/trailing whitespace |
| `dedent-trim` | Dedent then trim |

```haxe
// Without mode - preserves indentation
var raw = <heredoc>
      Line 1
      Line 2
</heredoc>;
// Result: "\n      Line 1\n      Line 2\n"

// With dedent-trim - clean output
var clean = <heredoc mode="dedent-trim">
      Line 1
      Line 2
</heredoc>;
// Result: "Line 1\nLine 2"
```

## Interpolation

| Syntax | Description | Example |
|--------|-------------|---------|
| `$var` | Simple variable | `$name` → value of name |
| `${expr}` | Expression | `${arr[0]}` → first element |
| `$$` | Literal $ | `$$100` → "$100" |

```haxe
var name = "Alice";
var items = [10, 20, 30];

var text = <heredoc>
User: $name
First item: ${items[0]}
Total: $$${items[0] + items[1] + items[2]}
</heredoc>;
```

## Linebreaks

Heredocs preserve linebreaks exactly like Node.js template literals:

```haxe
var name = "World";
var text = <heredoc>Line 1
Line 2
$name
Line 4</heredoc>;
// Result: "Line 1\nLine 2\nWorld\nLine 4"
```

Unlike JSX/HTML templates where whitespace around elements is normalized, heredocs preserve all newlines including those adjacent to interpolated expressions.

## Complete Example

```haxe
class Example {
  public static function main() {
    var user = "admin";
    var table = "users";

    // SQL query with dedent-trim
    var sql = <heredoc mode="dedent-trim">
      SELECT *
      FROM $table
      WHERE username = '$user'
      ORDER BY created_at DESC
    </heredoc>;

    // HTML template
    var html = <heredoc mode="dedent-trim">
      <div class="greeting">
        <h1>Welcome, $user!</h1>
        <p>You are logged in.</p>
      </div>
    </heredoc>;

    // JSON with expressions
    var count = 42;
    var json = <heredoc mode="dedent-trim">
      {
        "user": "$user",
        "count": ${count},
        "active": true
      }
    </heredoc>;
  }
}
```

## How It Works

1. **Parsing**: Haxe's parser recognizes `<heredoc>...</heredoc>` as a markup literal
2. **Interception**: SyntaxHub's `HeredocSyntax` plugin intercepts `@:markup` expressions
3. **Transformation**: Content is parsed by tink_hxx (with Preserve whitespace mode)
4. **Joining**: Children (text + interpolated values) are converted to strings and joined

## Alternative: Explicit Macro

If you can't use SyntaxHub, you can call the macro explicitly:

```haxe
var text = Heredoc.hxx(<heredoc>Hello $name!</heredoc>);
```

**build.hxml** (without SyntaxHub):
```
-lib tink_hxx
-lib tink_macro
-main Example
--interp
```

## Files

| File | Description |
|------|-------------|
| `Heredoc.hx` | Main library - macro and heredoc function |
| `HeredocSyntax.hx` | SyntaxHub plugin for direct syntax |
| `HeredocTest.hx` | Test suite (explicit macro syntax) |
| `DirectTest.hx` | Test suite (direct syntax) |
| `LinebreakTest.hx` | Test suite (linebreak preservation) |

## Build & Test

```bash
# Run tests (direct syntax - preferred)
haxe -lib tink_hxx -lib tink_macro -lib tink_syntaxhub \
  --macro "tink.SyntaxHub.use()" \
  --macro "HeredocSyntax.use()" \
  -main DirectTest --interp

# Run linebreak tests
haxe -lib tink_hxx -lib tink_macro -main LinebreakTest --interp
```

## References

- [tink_hxx](https://github.com/haxetink/tink_hxx) - The HXX parser library
- [tink_syntaxhub](https://github.com/haxetink/tink_syntaxhub) - Global syntax transformation
- [Haxe Markup Literals](https://haxe.org/manual/lf-markup.html) - Built-in markup support
