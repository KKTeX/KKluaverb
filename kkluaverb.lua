-- KKluaverb.lua
-- Copyright (c) 2026 Kosei Kawaguchi
-- Released under the MIT License (see LICENSE.md for details)
--
-- This file is based on 'bxrawstr.lua' by Takayuki YATO (aka. "ZR").
-- Copyright (c) 2018 Takayuki YATO
--

luatexbase.provides_module{
  name     = 'KKluaverb',
  date     = '2026/01/27',
  version  = '2.1.2',
}

----- for .sty interface -----
KKLuaVerb = KKLuaVerb or {}
----------


----- for .lua interface-----
local KKV = {}
local in_process = false

local CMD_INIT = "\\KKlvStart*"
local CMD_TERM = "\\KKlvEnd*"
local DEFAULT_STARTER = "\\KKverb"
local DEFAULT_STARTER_flag1 = "\\KKcodeS"
local DEFAULT_TERMINATOR_flag1   = "\\KKcodeE"

local ltjflg = utf8.char(0xFFFFF) .. "\n$"
----------


----- encode -----
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
----------


----- replacement -----
KKV.replacements = {}

function KKV.add_replacement(from_char, to_char)
  KKV.replacements[from_char] = to_char
end

KKV.add_replacement(" ", "\194\160")
  -- Avoid ignoring space.
----------


----- decode -----
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
    local fl_linenumber = (tex.count["kklv@linenum@start"] - 1)

    -- Separate 'decoded' to 'dc_lines'.
    for line in (decoded .. "\n"):gmatch("(.-)\n") do
      table.insert(dc_lines, line)
    end
    local last_idx = #dc_lines
    last_idx = last_idx - 1
      -- Delete the last line.
    tex.sprint("\\par\\noindent")
    for i = 2, last_idx do -- ref: NOTE#1
      local content = dc_lines[i]
      if content ~= "" then
        local map_to_use = KKV.active_map or {}
        KKV.output_with_multiple_colors(content, map_to_use, true)
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
    local fl_linenumber = (tex.count["kklv@linenum@start"] - 1)

    -- Separate 'decoded' to 'dc_lines'.
    for line in (decoded .. "\n"):gmatch("(.-)\n") do
      table.insert(dc_lines, line)
    end
    local last_idx = #dc_lines
    last_idx = last_idx - 1
      -- Delete the last line.
    tex.sprint("\\par\\noindent")
    for i = 2, last_idx do -- ref: NOTE#1
      tex.sprint("\\KKlvLineNumber{" .. (i - 1 + fl_linenumber) .. "}")
      local content = dc_lines[i]
      if content ~= "" then
        local map_to_use = KKV.active_map or {}
        KKV.output_with_multiple_colors(content, map_to_use, true)
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
    local map_to_use = KKV.active_map or {}
    KKV.output_with_multiple_colors(decoded, map_to_use)
  end
end
----------


----- scanner -----
function KKV.scanner_for_verb(line)
  -- If the scanner is unabled, it returns nil.
  if not KKLuaVerb.enabled then return nil end

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
  local start_cmd = DEFAULT_STARTER .. ini
  local shortcut_start = DEFAULT_STARTER_flag1
  local shortcut_end = DEFAULT_TERMINATOR_flag1

  -- While the character index 
  -- <= the length of the line,
  -- scan the chunk:
  while (pos <= #line) or (in_process and pos == 1 and #line == 0) do
    if not in_process then
      -- for \KKverb
      local s_idx, e_idx = line:find(start_cmd, pos, true)
      -- for \KKcodeS, E
      local s_short_idx, e_short_idx = line:find(shortcut_start, pos, true)

      if s_short_idx and (not s_idx or s_short_idx < s_idx) then
        in_process = true

        local next_char = line:sub(e_short_idx + 1, e_short_idx + 1)
        local style_num = "1" 
        local skip_len = 0

        if next_char == "+" then
          style_num = "2"   
          skip_len = 1     
        end

        local transform = line:sub(pos, s_short_idx - 1) .. "{\\KKvLNChange{style=" .. style_num .. "}" .. CMD_INIT
        table.insert(res, transform)

        pos = e_short_idx + 1 + skip_len

        -- NOTE#1
        -- This part was added 
        -- in order to avoid being inserted
        -- unwanted space to the first line 
        -- when the flag is 1 or 2. 
        if not line:find(shortcut_end, pos, true) then
          local sc_content = line:sub(pos)
          table.insert(res, KKV.encode_tail(sc_content) .. "%")
          pos = #line + 1 
        end
      elseif s_idx then
        in_process = true 
        table.insert(res, line:sub(pos, s_idx - 1) .. CMD_INIT)
        pos = e_idx + 1

        -- NOTE#1
        -- This part was added 
        -- in order to avoid being inserted
        -- unwanted space to the first line 
        -- when the flag is 1 or 2. 
        if not line:find(trm, pos, true) then
          local sc_content = line:sub(pos)
          table.insert(res, KKV.encode_tail(sc_content) .. "%")
          pos = #line + 1
        end
      else
        local sc_content = line:sub(pos)
        table.insert(res, sc_content)
        break
      end

    else
      local s_idx, e_idx = line:find(trm, pos, true)
      local s_short_end_idx, e_short_end_idx = line:find(shortcut_end, pos, true)

      if s_short_end_idx and (not s_idx or s_short_end_idx < s_idx) then
        local sc_content = line:sub(pos, s_short_end_idx - 1)
        table.insert(res, KKV.encode(sc_content) .. CMD_TERM .. "}")
        in_process = false 
        pos = e_short_end_idx + 1
      
      elseif s_idx then
        local sc_content = line:sub(pos, s_idx - 1)
        table.insert(res, KKV.encode(sc_content) .. CMD_TERM)
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
----------


----- color changer -----
local function is_alnum(char, options)
  if not char or char == "" then return false end
  local p = options.word_components or "[A-Za-z0-9_]"
  return char:match(p) ~= nil
end
-- Enhancement in v2.1.1
  -- If you want to set a certain character like "\" 
  -- as a word component, use map-op:
  -- 
  -- options = { 
  --     word_components = "[A-Za-z0-9_\\]"   
  --   }

local function find_closing_delimiter(line, stop_char, start_pos, escape_char)
  local search_pos = start_pos
  while true do
    local s = line:find(stop_char, search_pos, true)
    if not s then return nil end 

    local is_escaped = false
    if escape_char and s > 1 and line:sub(s-1, s-1) == escape_char then
      local count = 0
      local p = s - 1
      while p >= 1 and line:sub(p, p) == escape_char do
        count = count + 1
        p = p - 1
      end
      if count % 2 == 1 then is_escaped = true end
    end

    if not is_escaped then 
      return s
    end
    
    search_pos = s + 1
  end
end


local function parse_inside_delim(content, forced_tokens, base_color)
  -- Only used in "delim" part

  if not forced_tokens or type(forced_tokens) ~= "table" or not next(forced_tokens) then
    return {{ type = "delim", content = content, color = base_color }}
  end

  local res = {}
  local pos = 1
  
  local keys = {}
  for k in pairs(forced_tokens) do table.insert(keys, k) end

  while pos <= #content do
    local nearest_s, nearest_e, found_k
    
    for _, k in ipairs(keys) do
      local s, e = content:find(k, pos, true)
      if s and (not nearest_s or s < nearest_s) then
        nearest_s, nearest_e, found_k = s, e, k
      end
    end

    if nearest_s then
      if nearest_s > pos then
        table.insert(res, { type = "delim_plain", content = content:sub(pos, nearest_s - 1), color = base_color })
      end
      -- forced
      table.insert(res, { type = "token_delim", content = found_k, color = forced_tokens[found_k] })
      pos = nearest_e + 1
    else
      -- plain
      table.insert(res, { type = "delim_plain", content = content:sub(pos), color = base_color })
      break
    end
  end
  
  return res
end

function KKV.cut_multiple_tokens(line, targets, options)
  local use_boundary = true
  if options and options.word_boundary ~= nil then
    use_boundary = options.word_boundary
  end
  
  local delims = (options and options.delimiters) or {}
    -- unique delimiters
  local forced = (options and options.forced_tokens) or {}
    -- forced to change color even in delims

  local escape_char = (options and options.escape_char) or "\\"
    -- Currently, the default escaper is "\".
    -- Is this a proper choice...?

  local parts = {}
  local pos = 1
  
  while pos <= #line do
    local nearest_s = nil
    local nearest_e = nil
    local found_token = nil
    local found_delim_color = nil

    for _, d in ipairs(delims) do
      local s, _ = line:find(d.start, pos, true)
      if s and (not nearest_s or s < nearest_s) then
        local e = find_closing_delimiter(line, d.stop, s + #d.start, escape_char)
        if e then
          nearest_s = s
          nearest_e = e + #d.stop - 1
          found_token = nil 
          found_delim_color = d.color
        end
      end
    end
    -- Enhancement in v2.1.2
    -- To make sure that keywords in "delim" category are color-changed, 
    -- I have to re-scan the delim part like this:
    -- 1. When the system find a demil-pair, insert every text between them into "raw_delim" category.
    -- 2. Serch for forced_keywords in the "raw_delim".
    -- * forced_keywords means that this is completely different from the normal keywords and need to be set
    --   in differnt part.
    -- 3. Cut "raw_delim" like this:
    --    $a + b = \frac{x}{y}$ (in this case, forced_keywords are "{" and "}".)
    --    a + b = \frac → "plain_delim" colored by d_color 
    --    { → "token_delim" colored by t_d_color
    
    for _, token in ipairs(targets) do
      local s, e = line:find(token, pos, true)
      if s then
        local is_valid = true 
        
        if use_boundary then
          -- Get the previous and next characters.
          local prev_char = s > 1 and line:sub(s-1, s-1) or nil
          local next_char = e < #line and line:sub(e+1, e+1) or nil
          
          -- Check the tokens.
          if is_alnum(token:sub(1, 1), options) and is_alnum(prev_char, options) then
            is_valid = false
          end
          if is_alnum(token:sub(-1, -1), options) and is_alnum(next_char, options) then
            is_valid = false
          end
        end

        if is_valid and (not nearest_s or s < nearest_s) then
          nearest_s = s
          nearest_e = e
          found_token = token
          found_delim_color = nil
        end
      end
    end
    
    if nearest_s then
      if nearest_s > pos then
        table.insert(parts, { type = "plain", content = line:sub(pos, nearest_s - 1) })
      end
      if found_delim_color then
        -- table.insert(parts, { type = "delim", content = line:sub(nearest_s, nearest_e), color = found_delim_color })

        -- Enhancement in v2.1.2
        -- Re-process "delim" part in order to search for forced_tokens.
        local delim_raw = line:sub(nearest_s, nearest_e)
        local sub_parts = parse_inside_delim(delim_raw, forced, found_delim_color)
        for _, sp in ipairs(sub_parts) do
          table.insert(parts, sp)
        end
      else
        table.insert(parts, { type = "token", content = found_token })
      end
      pos = nearest_e + 1
    else
      local rest = line:sub(pos)
      if #rest > 0 then
        table.insert(parts, { type = "plain", content = rest })
      end
      break
    end
  end
  return parts
end

function KKV.output_with_multiple_colors(line, color_map, allow_comments)
  local options = (type(color_map) == "table" and color_map.options) or {}
  local actual_map = color_map.map or color_map
  local code_part = line     
  local comment_part = ""     
  
  local all_targets = {}
  local token_to_color = {} 

  if allow_comments and options.comment_char then
    local c_char = options.comment_char
    local e_char = options.escape_char or "\\" 
    
    local search_pos = 1
    while true do
      local s = line:find(c_char, search_pos, true)
      if not s then break end 
      
      local is_escaped = false
      if s > 1 and line:sub(s-1, s-1) == e_char then
        local count = 0
        local p = s - 1
        while p >= 1 and line:sub(p, p) == e_char do
          count = count + 1
          p = p - 1
        end
        if count % 2 == 1 then is_escaped = true end
      end
      
      if not is_escaped then
        code_part = line:sub(1, s-1)
        comment_part = line:sub(s)
        break
      else
        search_pos = s + 1
      end
    end
  end

  for color, targets in pairs(actual_map) do
    for _, t in ipairs(targets) do
      table.insert(all_targets, t)
      token_to_color[t] = color
    end
  end

  local parts = KKV.cut_multiple_tokens(code_part, all_targets, options)

  for _, p in ipairs(parts) do
    if p.type == "token" then
      local t_color = token_to_color[p.content] or "black" 
      tex.sprint("\\textcolor{" .. t_color .. "}{")
      tex.sprint(-2, p.content)
      tex.sprint("}")
    -- elseif p.type == "delim" then
    --   local d_color = p.color or "black"
    --   tex.sprint("\\textcolor{" .. d_color .. "}{")
    --   tex.sprint(-2, p.content)
    --   tex.sprint("}")

    -- Enhancement in v2.1.2
    elseif p.type == "delim" or p.type == "delim_plain" then
      -- デリミタ全体、またはデリミタ内の「地の文」
      local d_color = p.color or "black"
      tex.sprint("\\textcolor{" .. d_color .. "}{")
      tex.sprint(-2, p.content)
      tex.sprint("}")

    elseif p.type == "token_delim" then
      -- デリミタ内部で特別に指定されたキーワード
      local td_color = p.color or "black"
      tex.sprint("\\textcolor{" .. td_color .. "}{")
      tex.sprint(-2, p.content)
      tex.sprint("}")
    else
      tex.sprint(-2, p.content)
    end
  end

  if comment_part ~= "" then
    local c_color = options.comment_color or "gray"
    tex.sprint("\\textcolor{" .. c_color .. "}{")
    tex.sprint(-2, comment_part)
    tex.sprint("}")
  end
end
----------


----- preset -----
KKV.presets = KKV.presets or {}

function KKV.set_preset(name, map)
  KKV.presets[name] = map
end

function KKV.load_preset(name)
  if KKV.presets[name] then
    KKV.active_map = KKV.presets[name]
    print("KKV: Preset [" .. name .. "] applied.")
  else
    print("KKV: Warning - Preset [" .. name .. "] not found.")
  end
end
----------

_G.KKLuaVerb = KKV