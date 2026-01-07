-- KKluaverb.lua
luatexbase.provides_module{
  name     = 'KKluaverb',
  date     = '2026/01/07',
  version  = '1.2.0',
}


-- delm changer
-- escaper
local function escape_pattern(text)
    -- escape all
    return text:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
end

-- use in the scanner
local function get_current_pattern()
    -- get delims
    local spec = tex.gettoks("kklv@delims")
    -- devide delims
    local ini, trm = spec:match("^{(.*)}{(.*)}$")
    
    ini = ini or "|"
    trm = trm or "|"
    
    return "\\KKverb" .. escape_pattern(ini) .. "(.-)" .. escape_pattern(trm)
end

-- main
local KKV = {}

-- 1. encode
function KKV.encode(str)
    -- utf8.codes
    local t = {}
    for _, code in utf8.codes(str) do
        -- except for (0-9, A-Z, a-z), encode:
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

-- 2. decode
function KKV.decode(rstr)
    -- the rule of decoding
    local chex = function(s) return utf8.char(tonumber(s, 16)) end

    -- main decoder
    local decoded = rstr
        :gsub('*U(%x%x%x%x%x%x)', chex)
        :gsub('*u(%x%x%x%x)', chex)
        :gsub('*(%x%x)', chex)

    tex.sprint(decoded)
end

-- 3. scan
function KKV.scanner(line)
    local pattern = get_current_pattern()

    -- encode
    return line:gsub(pattern, function(content)
        return "\\KKvPrint{" .. KKLuaVerb.encode(content) .. "}"
    end)
    -- \KKvPrint decodes (refer to .sty file)
end

-- make KKV global
_G.KKLuaVerb = KKV