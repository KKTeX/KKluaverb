-- KKluaverb.lua
--
-- This package utilizes logic from 'bxrawstr' (by Takayuki YATO).
-- package: https://gist.github.com/zr-tex8r/c7901658a866adfcd3cd66b6dfa86997
-- article: https://zrbabbler.hatenablog.com/entry/20181222/1545495849
-- Copyright (c) 2018 Takayuki YATO (aka. "ZR")
-- Released under the MIT License.
--
-- Copyright (c) 2026 Kosei Kawaguchi 

luatexbase.provides_module{
  name     = 'KKluaverb',
  date     = '2026/01/08',
  version  = '1.3.0',
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
  for _, code in utf8.codes(str) do
    if ((code >= 48 and code <= 57)
      or (code >= 65 and code <= 90)
      or (code >= 97 and code <= 122))
      and code ~= 42 then
      table.insert(t, string.char(code))
    else
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
  local cleaned = rstr:gsub('[ \t\r\n]', '')
  local chex = function(s) return utf8.char(tonumber(s, 16)) end
  local decoded = cleaned
    :gsub('*U(%x%x%x%x%x%x)', chex)
    :gsub('*u(%x%x%x%x)', chex)
    :gsub('*(%x%x)', chex)

  for from, to in pairs(KKV.replacements) do
    decoded = decoded:gsub(from, to)
  end

  decoded = decoded:gsub('\n', '') 

  tex.sprint(-2, decoded)
end

-- scanner
function KKV.scanner(line)
  local spec = tex.gettoks("kklv@delims")
  local ini_raw, trm_raw = spec:match("^{(.*)}{(.*)}$")
  local ini = ini_raw or "|"
  local trm = trm_raw or "|"

  local pos = 1
  local res = {} 
  local start_cmd = "\\KKverb" .. ini

  while pos <= #line do
    if not in_process then
      local s_idx, e_idx = line:find(start_cmd, pos, true)
      if s_idx then
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
        table.insert(res, KKV.encode(line:sub(pos, s_idx - 1)) .. CMD_TERM)
        in_process = false
        pos = e_idx + 1
      else
        table.insert(res, KKV.encode_tail(line:sub(pos)) .. "%")
        break
      end
    end
  end
  return table.concat(res)
end

_G.KKLuaVerb = KKV