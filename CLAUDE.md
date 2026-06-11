# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Note
In order to maximize the cost for your inference, do your tasks which consists of "the core part of the project" with fable5.
And do the other marginal tasks by sonnet and opus, defining sub-agents properly.

## What this is

`KKluaverb` is a LuaLaTeX package providing `\KKverb` — a Lua-enhanced verbatim command usable inside TOC, index, underline macros, `tblr` environments, etc. The package is distributed on CTAN.

The two source files are:
- `KKluaverb.sty` — LaTeX interface (pgfkeys options, TeX-level macros, `process_input_buffer` hook registration)
- `KKluaverb.lua` — Lua implementation (scanner, encoder/decoder, color highlighter, presets)

Note the casing: `\usepackage{KKluaverb}`, and the files are `KKluaverb.sty` / `KKluaverb.lua` (capital KK, lowercase rest).

## Build commands

All compilation uses `lualatex` via `latexmk` with `.latexmkrc`. The `.latexmkrc` sets `-halt-on-error`, `$pdf_mode = 4` (lualatex), and `upmendex` for indexing.

```sh
make doc       # compile kkluaverb-doc.tex → PDF, then clean auxiliaries
make sample    # compile kkluaverb-sample.tex → PDF, then clean auxiliaries
make test1     # compile kkluaverb-test1.tex → PDF (test files not in repo, created locally)
make test2     # compile kkluaverb-test2.tex → PDF
make clean     # latexmk -c  (remove aux files, keep PDF)
make distclean # latexmk -C  (remove everything including PDF)
make zip       # distclean + doc + bundle CTAN zip (kkluaverb.zip)
```

To compile a single `.tex` file directly:
```sh
latexmk -r .latexmkrc <file>.tex
```

## Architecture

### How the scanner works

The core mechanism hooks into LuaTeX's `process_input_buffer` callback. Every input line passes through `KKV.scanner_for_verb` before TeX tokenizes it.

The scanner rewrites lines containing `\KKverb|...|` or `\KKcodeS...\KKcodeE` blocks into an encoded form:

```
\KKverb|some text|  →  \KKlvStart*<encoded>\KKlvEnd*
```

`in_process` is the scanner's state variable:
- `false` — not in raw mode
- `"verb"` — inside `\KKverb|...|`; only the delimiter (`trm`) terminates it
- `"code"` — inside `\KKcodeS...\KKcodeE`; only `\KKcodeE` terminates it (the delimiter is treated as raw text)

This two-value distinction was the fix for the v2.2.0 bug where `|` inside `\KKcodeS` blocks would prematurely end the scan.

### Encode / decode

`KKV.encode` converts arbitrary UTF-8 text to a safe ASCII-only form:
- alphanumeric ASCII → kept as-is
- other bytes → `*XX` (8-bit), `*uXXXX` (BMP), `*UXXXXXX` (supplementary)

`KKV.decode` reverses this and runs the replacement table (spaces → NBSP by default to prevent TeX from ignoring them).

The TeX-side `\KKlvStart*#1\KKlvEnd*` macro calls `KKLuaVerb.decode([[#1]])` at expansion time, so the verbatim text survives TeX's tokenizer, `.toc` writes, etc.

### Linebreak / block mode

Controlled by `kklv@linebreak` toks (set via `\KKvLNChange{style=<n>}`):
- `0` — inline, all newlines stripped
- `1` — block, line breaks rendered with `\hfill\break`
- `2` — block with line numbers via `\KKlvLineNumber`

`\KKcodeS` sets style=1; `\KKcodeS+` sets style=2.

### Color highlighting

`KKV.output_with_multiple_colors(line, color_map, allow_comments)` tokenizes the decoded string, matches tokens/delimiters against a color map, and emits `\textcolor{...}{...}` calls via `tex.sprint`.

Color maps and presets are set with `KKV.set_preset(name, map)` / `\KKvUsePreset{name}`. A map table has shape:
```lua
{ map = { ColorName = { "token1", "token2" } }, options = { ... } }
```
Options include `word_boundary`, `delimiters`, `forced_tokens`, `comment_char`, `escape_char`, `word_components`.

### TeX ↔ Lua interface

- Public TeX API: `KKLuaVerb.*` (the global exposed as `_G.KKLuaVerb = KKV`)
- Internal Lua API: `KKV.*` (local module table)
- `.sty` calls Lua via `\directlua{...}` and `\luatexbase.add_to_callback`

## Known open requirements

`kkluaverb_update_requirements.md` tracks pending feature requests found during `ocr2tex` integration:
- Line wrapping for long lines (`wrap` pgfkeys option, `lstlisting`-style `breaklines`)
- Escape mechanism for literal `\KKcodeE` inside code blocks (implemented in v2.2.0 via `KKV.code_escape_char`, default `\`)
