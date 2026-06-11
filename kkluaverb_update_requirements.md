# KKluaverb アップデート要件（ocr2tex 連携で発見した問題）

ocr2tex がソースコード出力に `\KKcodeS`〜`\KKcodeE` を採用した際に見つかった
問題と、パッケージ側で修正してほしい要件のメモ。
対象: KKluaverb v2.1.2（TeX Live 2026 収録版）

## 問題: KKcodeS 生スキャン中に `|` が現れるとスキャンが終了する

### 再現最小例

```latex
\documentclass{article}
\usepackage{KKluaverb}
\begin{document}
\KKcodeS
def remove(list)
  return list.map { |word| word.gsub(/\d+/, '') }
end
# この行以降が生テキストとして扱われない
\KKcodeE
\end{document}
```

2行目の `{ |word| ... }` の最初の `|` で生スキャンが終了し、以降の行が
通常のTeXソースとして解釈される。上の例では `#` が
`You can't use macro parameter character` エラーになる
（実例: DeepSeek論文等のRuby/シェル/パイプ演算子を含むコード）。

### 原因（KKluaverb.lua）

`process_input_buffer` のスキャナが `in_process`（生モード中）を boolean
1つで管理しており、**どのスターターで生モードに入ったかを区別していない**。
そのため `in_process` 中の終端探索で

- `\KKcodeE`（shortcut_end）
- `\KKverb` 用デリミタ `trm`（既定 `|`、`\KKvSetDelims` の第2引数）

の **両方** を探し、先に現れた方で終了してしまう
（`KKluaverb.lua` の `else` 分岐: `line:find(trm, pos, true)` と
`line:find(shortcut_end, pos, true)` の比較箇所）。

## 要件

1. **スターター種別の状態管理**: `in_process` を boolean ではなく
   「何で開始したか」を持つ状態にする。
   - `\KKverb|...` で開始 → デリミタ（`trm`）のみを終端として探索
   - `\KKcodeS` / `\KKcodeS+` で開始 → `\KKcodeE` のみを終端として探索
2. （任意）コード中に literal `\KKcodeE` を含めたい場合のエスケープ手段
   （例: `\KKcodeE` の直前にエスケープ文字を置けるようにする等）。
   現状 ocr2tex 側では文字列置換で無害化している。
3. （確認のみ）`\KKcodeS`〜`\KKcodeE` 間の空行は段落維持で出力される
   現挙動で問題なし。維持してほしい。

## 修正後に ocr2tex 側で外すワークアラウンド

- `ocr2tex/texgen.py` `_preamble()`:
  `\KKvSetDelims{<@KKv@>}{<@KKv@>}` によるデリミタ退避
  （コード中に `|` が来てもスキャンが切れないようにする回避策）
- `ocr2tex/mdtex.py` `code_to_verbatim()`:
  literal `\KKcodeE` の置換無害化は要件2の対応次第で見直し
