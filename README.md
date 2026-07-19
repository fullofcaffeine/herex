<p align="center">
  <img src="assets/logo.png" alt="Herex logo" width="132">
</p>

<h1 align="center">herex</h1>

<p align="center">
  Readable, indentation-aware heredoc expressions for Haxe.
</p>

<p align="center">
  <a href="https://github.com/fullofcaffeine/herex/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/fullofcaffeine/herex/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/fullofcaffeine/herex/releases"><img alt="GitHub release" src="https://img.shields.io/github/v/release/fullofcaffeine/herex"></a>
  <img alt="Haxe 4.3.7" src="https://img.shields.io/badge/Haxe-4.3.7-EA8220">
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
</p>

Herex is the comfortable way to write generated code, SQL, templates, documentation, and other meaningful multiline text in Haxe. It keeps native interpolation while making indentation and final newlines deliberate.

```haxe
// Before: punctuation-heavy and easy to damage.
return [
  'package $packageName;',
  "",
  '@:native("$nativeModule")',
  "class LiveReactAssets {",
  "\tpublic static function vite_assets():Term {",
  "\t\treturn LiveReactReload.vite_assets();",
  "\t}",
  "}"
].join("\n");

// After: the output reads like the output.
return <heredoc newline>
  package $packageName;

  @:native("$nativeModule")
  class LiveReactAssets {
    public static function vite_assets():Term {
      return LiveReactReload.vite_assets();
    }
  }
</heredoc>;
```

The body is text, not XML or HXX. Haxe generics such as `Assigns<T>`, comparisons such as `a < b`, entities, annotations, and embedded HTML remain untouched.

## Install once

Install the immutable, versioned GitHub Release asset with [Lix](https://github.com/lix-pm/lix.client):

```bash
lix install https://github.com/fullofcaffeine/herex/releases/download/v1.0.0/herex-1.0.0.zip
```

Then add one line to the project HXML:

```hxml
-lib herex
```

That is the complete setup. Herex has no runtime or macro dependencies, and `-lib herex` enables direct syntax automatically. Releases are Haxelib-compatible archives consumed by Lix, but are not submitted to the Haxelib registry.

## Everyday syntax

```haxe
var user = "Ada";
var count = 3;

var message = <heredoc>
  Hello $user.
  You have ${count * 2} notifications.
</heredoc>;

// "Hello Ada.\nYou have 6 notifications."
```

Interpolation follows Haxe format-string conventions:

- `$name` for an identifier
- `${expression}` for an expression
- `$$` for a literal dollar sign

Expressions are evaluated once, from left to right, with normal Haxe string coercion.

### A shorter spelling

`<hd>` is a built-in alias with exactly the same options and behavior:

```haxe
var compact = <hd newline>
  Hello $user
</hd>;
```

Herex deliberately does not claim `<h>` by default because short markup names may belong to HTML/HXX processors. A project can opt into one additional alias knowingly:

```hxml
-lib herex
-D herex_alias=h
```

With that configuration, `<h>...</h>` is a Herex expression. The alias must be a static tag name; output behavior remains controlled by attributes at each source expression.

## Whitespace that does what you mean

A bare heredoc uses `smart` mode. It normalizes source line endings to LF, removes at most one blank framing line from each end, and removes the exact common indentation prefix from nonblank lines.

```haxe
var text = <heredoc>
  first
    nested
</heredoc>;

// "first\n  nested"
```

Choose another mode when whitespace is part of the interface:

| Syntax | Result |
| --- | --- |
| `mode="smart"` | Explicit spelling of the default framing and dedent behavior. |
| `mode="preserve"` | Keep logical source whitespace exactly, apart from LF normalization. |
| `mode="dedent"` | Remove common indentation but retain framing newlines. |
| `mode="trim"` | Trim source-authored boundary whitespace. |
| `mode="dedent-trim"` | Dedent, then trim the boundaries. |

For visually explicit indentation, margin mode requires a marker on every nonblank line. A missing marker is a compile-time error rather than a subtly malformed string.

```haxe
var help = <heredoc margin="|">
  |Usage:
  |  app [options]
  |
  |Options:
  |  --help  Show this help
</heredoc>;
```

The marker may contain more than one character, for example `margin=">>"`.

## Exact final newlines

Generated files and protocol fragments often care about their ending. Herex makes it explicit:

```haxe
var file = <heredoc newline>one final LF</heredoc>;
var section = <heredoc newlines={2}>two final LFs</heredoc>;
var fragment = <heredoc newlines={0}>no final newline</heredoc>;
```

The guarantee applies to the fully rendered value—even when the last interpolation already ends in CRLF or several newlines. Bare `newline` and `newline={true}` are equivalent; `newline={false}` is an alias for zero.

## Multiline interpolated values

An interpolation that is the only content on an indented logical line is treated as a block. Continuation lines receive that final template indentation:

```haxe
var fields = "name:String;\nage:Int;";

var definition = <heredoc>
  typedef Person = {
    $fields
  }
</heredoc>;

// typedef Person = {
//   name:String;
//   age:Int;
// }
```

Inline interpolations are never reindented. Use `reindent={false}` when a block value already contains its final indentation.

## Raw by default

Backslashes are literal by default, which keeps generated code, regular expressions, Windows paths, and shell snippets readable:

```haxe
var path = <heredoc>C:\work\new\file.txt</heredoc>;
```

Opt into regular Haxe escapes when they are useful:

```haxe
var escaped = <heredoc escapes="haxe">first\nsecond\t\u{1F642}</heredoc>;
```

For dollar-heavy shell or template source, disable interpolation entirely:

```haxe
var shell = <heredoc interpolate={false}>
  echo "$HOME"
  printf '%s\n' "${value}"
</heredoc>;
```

All options are compile-time literals. Unknown, duplicate, dynamic, invalid, or conflicting options fail at the relevant source range.

## When to use a heredoc

Prefer Herex for meaningful multiline text, embedded code/templates/SQL/docs, or blocks where indentation and final-newline correctness matter.

Keep ordinary quoted strings and `+` for short single-line text or a couple of small fragments. Keep arrays/builders for conditional line assembly, and use serializers instead of hiding structured data in a string.

### Guidance for coding agents

A compact, copy-ready policy lives in [`AGENTS.example.md`](AGENTS.example.md). It helps agents choose heredocs without turning every tiny concatenation into one.

## Compatibility and limits

Direct syntax is recommended. The original explicit wrappers remain available:

```haxe
var legacy = Heredoc.hxx(<heredoc>Hello $user</heredoc>);
var namespaced = herex.Heredoc.hxx(<heredoc>Hello $user</heredoc>);
```

- Herex currently supports and tests Haxe 4.3.7.
- Source line endings become LF. Interpolated values retain their own internal line endings unless exact trailing-newline handling affects their terminal run.
- The exact closing tag for the chosen spelling—such as `</heredoc>` or `</hd>`—closes the literal. Construct that delimiter through interpolation if it must appear in the output.
- Attributes are deliberately local to each heredoc; there is no project-wide output configuration that silently changes source semantics.

## Development

```bash
npm ci
npm test
npm run format:check
```

Use `npm run format` to rewrite Haxe sources. See [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`RELEASING.md`](RELEASING.md) for the complete maintenance workflow.

## License

[MIT](LICENSE)
