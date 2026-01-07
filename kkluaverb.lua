-- KKluaverb.lua
luatexbase.provides_module{
  name     = 'KKluaverb',
  date     = '2026/01/07',
  version  = '1.2.0',
}

-- Main
local KKV = {}
local in_process = false

function KKV.check_delimiters()
  local spec = tex.gettoks("kklv@delims")
  local ini, trm = spec:match("^{(.*)}{(.*)}$")
  
  -- Prohibit blank
  if not ini or not trm or ini == "" or trm == "" then
    return false
  end
  
  -- Prohibit numbers and alphabets
  if ini:match("^[0-9A-Za-z]") or trm:match("[0-9A-Za-z]$") then
    return false 
  end

  -- If the result is false, 
  -- \KKvSetDelims returns error
  
  return true
end

-- 1. Encode
function KKV.encode(str)
  str = str:gsub('[ \t\r\n]', '')

  -- utf8.codes
  local t = {}
  for _, code in utf8.codes(str) do
    -- Except for (0-9, A-Z, a-z), encode:
    if (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) then
      table.insert(t, string.char(code))
    else
      local formatted
      if code < 0x100 then
        -- 2-digits
        formatted = string.format("*%02X", code)
      elseif code < 0x10000 then
        -- 4-digits
        formatted = string.format("*u%04X", code)
      else
        -- 6-digits
        formatted = string.format("*U%06X", code)
      end
      table.insert(t, formatted)
    end
  end
  return table.concat(t)
end

function KKV.encode_tail(str)
  return KKV.encode(str .. "\n")
end

-- 2. Decode
function KKV.decode(rstr)
  local chex = function(s) return utf8.char(tonumber(s, 16)) end
  local decoded = rstr
    :gsub('*U(%x%x%x%x%x%x)', chex)
    :gsub('*u(%x%x%x%x)', chex)
    :gsub('*(%x%x)', chex)
  tex.sprint(-2, decoded)
end

-- 3. Scan
function KKV.scanner(line)
  -- Get delimiters from TeX token register
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
        table.insert(res, line:sub(pos, s_idx - 1))
        table.insert(res, "\\KKvPrint{")
        in_process = true
        pos = e_idx + 1
      else
        table.insert(res, line:sub(pos))
        break
      end
    else

      local s_idx, e_idx = line:find(trm, pos, true)
      
      if s_idx then
        local content = line:sub(pos, s_idx - 1)
        table.insert(res, KKV.encode(content) .. "}")
        in_process = false
        pos = e_idx + 1
      else
        local content = line:sub(pos)

        table.insert(res, KKV.encode_tail(content) .. "%")
        break
      end
    end
  end

  -- Return a flat string without raw newline characters
  return table.concat(res)
end

-- Make KKV global
_G.KKLuaVerb = KKV