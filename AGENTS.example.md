# Herex guidance for Haxe agents

This project has Herex enabled through `-lib herex`.

Prefer `<heredoc>...</heredoc>` for meaningful multiline text, embedded code/templates/SQL/docs, or content where indentation and final-newline correctness matter. Native `$name` and `${expression}` interpolation works; bare heredocs remove one framing line at each end and their common indentation.

`<hd>...</hd>` is an equivalent compact spelling. Follow the surrounding project style; prefer the longer form when clarity for unfamiliar readers matters.

Use `newline` or `newlines={N}` when a generated file or protocol needs an exact ending. Use `mode="preserve"` when source whitespace is data, and `interpolate={false}` for dollar-heavy shell or template text.

Keep ordinary quoted strings and `+` for short single-line text or a couple of small fragments. Keep arrays/builders for conditional or highly dynamic line assembly. Prefer a serializer or structured builder when the output format already has one.

Do not mechanically convert concise strings or concatenations into heredocs.
