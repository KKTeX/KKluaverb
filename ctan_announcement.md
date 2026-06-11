Announcement for package KKluaverb (version 2.3.0)

KKluaverb is a LuaLaTeX package that provides a Lua-enhanced verbatim command
`\KKverb` and a verbatim code-block environment `\KKcodeS/E`. Unlike the
standard `\verb`, `\KKverb` works inside table of contents entries, index
entries, underline commands (e.g., `\underLineKK` from the luwa-ul package),
and `tblr` environments. The package also supports syntax-highlighting colour
maps, text/character substitution mappings, and multiple display styles for
code blocks.

Changes in this release (v2.3.0):

- New options `wrap` and `wrapindent` for `\KKcodeS/E` blocks: when
  `\KKvOpChange{wrap=true}` is set, lines that exceed `\linewidth` are
  automatically wrapped instead of producing Overfull `\hbox` warnings.
  Continuation lines are indented by the original code indentation plus the
  value of `wrapindent` (default: 2em). This feature is available for
  style=1 and style=2 (line-numbered); continuation lines in style=2 do not
  receive a line number.

- New command `\KKvSetMapTeX{<char>}{<tex-cmd>}`: maps a verbatim character
  to a TeX command, which is emitted via `tex.sprint` (with expansion) at
  output time. This complements the existing `\KKvSetMap` (character-to-
  character substitution) and is useful in Japanese font contexts where
  U+2423 (OPEN BOX, ␣) may be rendered as a full-width glyph.

- New command `\KKvSpaceVisible`: convenience wrapper for
  `\KKvSetMapTeX{ }{\textvisiblespace}`, making spaces in verbatim output
  appear as the half-width visible-space symbol provided by `textcomp`.

- New command `\KKvClearMapTeX{<char>}`: removes the TeX-command mapping for
  the given character and restores the default behaviour (for space: reverts
  to the automatic non-breaking space substitution).

The package is available at https://ctan.org/pkg/kkluaverb

Author:  Kosei Kawaguchi (KKTeX)
License: MIT
