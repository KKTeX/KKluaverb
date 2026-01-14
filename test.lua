local KKV = {}

function KKV.cut_multiple_tokens(line, targets)
  local parts = {}
  local pos = 1
  
  while pos <= #line do
    local nearest_s = nil
    local nearest_e = nil
    local found_token = nil
    
    -- 全ターゲットの中から「最も左」にあるものを探す
    for _, token in ipairs(targets) do
      local s, e = line:find(token, pos, true)
      if s then
        if not nearest_s or s < nearest_s then
          nearest_s = s
          nearest_e = e
          found_token = token
        end
      end
    end
    
    if nearest_s then
      -- トークンの前を plain として保存
      if nearest_s > pos then
        table.insert(parts, { type = "plain", content = line:sub(pos, nearest_s - 1) })
      end
      -- トークン自体を保存
      table.insert(parts, { type = "token", content = found_token })
      pos = nearest_e + 1
    else
      -- 残りを保存して終了
      local rest = line:sub(pos)
      if #rest > 0 then
        table.insert(parts, { type = "plain", content = rest })
      end
      break
    end
  end
  return parts
end

-- 複数ターゲットのテスト（ここはOK）
local test_line1 = "A \\section B \\begin{center} C"
local test_targets1 = {"\\section", "\\begin{center}"}
local res1 = KKV.cut_multiple_tokens(test_line1, test_targets1)

print("\n--- Multiple Tokens Test ---")
for i, p in ipairs(res1) do
    print(i .. ": [" .. p.type .. "] '" .. p.content .. "'")
end

-- --- ここから修正 ---
local test_line2 = "Before \\section Middle \\section After"
-- 単一のターゲットでもテーブルに入れる必要がある
local test_targets2 = {"\\section"} 

local results = KKV.cut_multiple_tokens(test_line2, test_targets2)

print("--- Test Result ---")
for i, p in ipairs(results) do
    print(string.format("%d: [%s] '%s'", i, p.type, p.content))
end