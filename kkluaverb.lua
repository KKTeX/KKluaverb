-- KKluaverb.lua
--
-- Copyright (c) 2026 Kosei Kawaguchi 
--
-- This package utilizes logic from 'bxrawstr' (by Takayuki YATO).
-- package: https://gist.github.com/zr-tex8r/c7901658a866adfcd3cd66b6dfa86997
-- article: https://zrbabbler.hatenablog.com/entry/20181222/1545495849
-- Copyright (c) 2018 Takayuki YATO (aka. "ZR")
--
-- Released under the MIT License.
--

luatexbase.provides_module{
  name     = 'KKluaverb',
  date     = '2026/01/08',
  version  = '1.4.0',
}

local KKV = {}
local in_process = false

local CMD_INIT = "\\KKlvStart*"
local CMD_TERM = "\\KKlvEnd*"
local ltjflg = utf8.char(0xFFFFF) .. "\n$"

-- encode
function KKV.encode(str)
  if not str then return "" end
  local t = {}
  for _, code in utf8.codes(str) do     -- discard pos
    if ((code >= 48 and code <= 57)     -- 0-9
      or (code >= 65 and code <= 90)    -- A-Z
      or (code >= 97 and code <= 122))  -- a-z
      and code ~= 42 then               -- except for '*'
      table.insert(t, string.char(code))
    else
      -- Transform the input into hexadecimal.
      local formatted
      if code < 0x100 then
        formatted = string.format("*%02X", code)
      elseif code < 0x10000 then
        formatted = string.format("*u%04X", code)
      else
        formatted = string.format("*U%06X", code)
      end
      table.insert(t, formatted)
    end
  end
  return table.concat(t)
end

function KKV.encode_tail(str)
  local s = (str .. "\n"):gsub(ltjflg, "\n")
  return KKV.encode(s)
end

-- replacement
KKV.replacements = {}
function KKV.add_replacement(from_char, to_char)
  KKV.replacements[from_char] = to_char
end

-- decode
function KKV.decode(rstr)
  local chex = function(s) return utf8.char(tonumber(s, 16)) end
  local decoded = rstr
    :gsub('*U(%x%x%x%x%x%x)', chex)
    :gsub('*u(%x%x%x%x)', chex)
    :gsub('*(%x%x)', chex)

  -- After characters are decoded, run the replacer.
  for from, to in pairs(KKV.replacements) do
    decoded = decoded:gsub(from, to)
  end

  -- How to process linebreak
  local lb_flag = tex.gettoks("kklv@linebreak")
  
  -- If lb_flag is "1",
  -- a "verbatim paragraph" is produced.
  -- Behave like an environment.
  if lb_flag == "1" then
    local dc_lines = {}
    for line in (decoded .. "\n"):gmatch("(.-)\n") do
      table.insert(dc_lines, line)
    end
    local last_idx = #dc_lines
    if dc_lines[last_idx] == "" then
      last_idx = last_idx - 1
    end
    tex.sprint("\\par\\noindent")
    for i = 1, last_idx do
      local content = dc_lines[i]
      if content ~= "" then
        tex.sprint(-2, content)
      else
        if i == 1 then
          tex.sprint("\\hbox{}")
        end
      end
      if i < last_idx then
        tex.sprint("\\hfill\\break\\noindent")
      else
        tex.sprint("\\hspace*{\\fill}\\par")
      end
    end

  -- If lb_flag is "2",
  -- a "verbatim paragraph with line numbers"
  -- is produced.
  -- Behave like an environment.
  elseif lb_flag == "2" then
    local dc_lines = {}

    -- Separate 'decoded' to 'dc_lines'.
    for line in (decoded .. "\n"):gmatch("(.-)\n") do
      table.insert(dc_lines, line)
    end
    local last_idx = #dc_lines
    if dc_lines[last_idx] == "" then
      last_idx = last_idx - 1
    end
    tex.sprint("\\par\\noindent")
    for i = 1, last_idx do
      tex.sprint("\\KKlvLineNumber{" .. i .. "}")
      local content = dc_lines[i]
      if content ~= "" then
        tex.sprint(-2, content)
      end
      if i < last_idx then
        tex.sprint("\\hfill\\break\\noindent")
      else
        tex.sprint("\\hspace*{\\fill}\\par")
      end
    end

  -- If lb_flag is not "1" or "2",
  -- any linebreaks are completely ignored.
  else
    decoded = decoded:gsub('[\t\r\n]', '') 
    tex.sprint(-2, decoded)
  end
end

-- scanner
function KKV.scanner(line)
  -- When the process_input_buffer runs,
  -- a chunk of text on a single line
  -- is passed to the function as the argument `line`

  local spec = tex.gettoks("kklv@delims")

  -- In the .sty, \kklv@delims is defined
  -- as {token1}{token2}.
  -- So cut off the brackets.
  local ini_raw, trm_raw = spec:match("^{(.*)}{(.*)}$")
  local ini = ini_raw or "|"
  local trm = trm_raw or "|"

  local pos = 1 -- the character index
  local res = {} -- a transformed chunk
  local start_cmd = "\\KKverb" .. ini

  -- While the character index 
  -- <= the length of the line,
  -- scan the chunk:
  while (pos <= #line) or (in_process and pos == 1 and #line == 0) do
    if not in_process then
      local s_idx, e_idx = line:find(start_cmd, pos, true)
      if s_idx then
        -- Found the starter
        table.insert(res, line:sub(pos, s_idx - 1) .. CMD_INIT)
        in_process = true 
        pos = e_idx + 1
      else
        table.insert(res, line:sub(pos))
        break
      end
    else
      local s_idx, e_idx = line:find(trm, pos, true)
      if s_idx then
        -- Found the finisher
        table.insert(res, KKV.encode(line:sub(pos, s_idx - 1)) .. CMD_TERM)
        in_process = false 
        pos = e_idx + 1
      else
        local sc_content = line:sub(pos)
        table.insert(res, KKV.encode_tail(sc_content) .. "%")
        break
      end
    end
  end
  return table.concat(res)
end

_G.KKLuaVerb = KKV