<p align="center">
  <img src="assets/logo.png" alt="herex" width="128">
</p>

# herex

Multi-line string literals with interpolation for Haxe.

```haxe
var name = "World";
var text = <heredoc>Hello $name!</heredoc>;
// "Hello World!"
```

## Requirements

- Haxe 4.0+
- lix package manager (recommended)

## Installation

```bash
lix install gh:fullofcaffeine/herex
```

Dependencies are installed automatically:

- `tink_hxx` - markup parsing
- `tink_syntaxhub` - direct syntax support

## Setup

Add to your `build.hxml`:

```
-lib herex
-lib tink_syntaxhub
--macro tink.SyntaxHub.use()
--macro HeredocSyntax.use()
```

## Usage

```haxe
var user = "Alice";
var count = 42;

// Basic interpolation
var msg = <heredoc>Hello $user!</heredoc>;

// Expressions
var result = <heredoc>Total: ${count * 2}</heredoc>;

// Multi-line
var query = <heredoc>
  SELECT * FROM users
  WHERE name = '$user'
</heredoc>;

// Literal dollar sign
var price = <heredoc>Cost: $$99</heredoc>;
```

## Whitespace Modes

```haxe
// Default: preserve all whitespace
var raw = <heredoc>
  indented
</heredoc>;
// "\n  indented\n"

// dedent: remove common indentation
var dedented = <heredoc mode="dedent">
  line 1
  line 2
</heredoc>;
// "\nline 1\nline 2\n"

// trim: remove leading/trailing whitespace
var trimmed = <heredoc mode="trim">
  content
</heredoc>;
// "content"

// dedent-trim: both
var clean = <heredoc mode="dedent-trim">
  line 1
  line 2
</heredoc>;
// "line 1\nline 2"
```

## Without SyntaxHub

If you can't use SyntaxHub, call the macro directly:

```haxe
var text = Heredoc.hxx(<heredoc>Hello $name!</heredoc>);
```

```
-lib herex
```

## How it works

The macro parses `<heredoc>` at compile time and generates string concatenation:

```haxe
// This:
var x = <heredoc>Hello $name!</heredoc>;

// Becomes:
var x = "Hello " + Std.string(name) + "!";
```

Static content compiles to string literals. Whitespace modes are applied at compile time when possible.

## License

MIT
