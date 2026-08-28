--[[ DQFarm Loader ]]
-- Licensed to: GNURT (1 thiet bi), Gnurt (nhieu)
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

local DQ_ENV = (type(getgenv) == "function" and getgenv()) or _G
DQ_ENV.DQ_LOADER = true

-- ===== luu key theo thiet bi: chi nhap lai khi het han / bi thu hoi =====
local KEYFILE = "dqfarm_license.key"
-- writefile/readfile co the nam o global, getgenv, hoac trong bang syn/fluxus
-- (nhieu executor moi chi expose trong getgenv, global khong co)
local function fileFn(name)
	if type(_G[name]) == "function" then return _G[name] end
	if DQ_ENV and type(DQ_ENV[name]) == "function" then return DQ_ENV[name] end
	if type(syn) == "table" and type(syn[name]) == "function" then return syn[name] end
	if type(fluxus) == "table" and type(fluxus[name]) == "function" then return fluxus[name] end
	return nil
end
local _writefile = fileFn("writefile")
local _readfile = fileFn("readfile")
local _isfile = fileFn("isfile")
local _delfile = fileFn("delfile")
local _makefolder = fileFn("makefolder")
local _appendfile = fileFn("appendfile")

-- diagnostic: biet executor co luu key duoc hay khong
local _exeFn = fileFn("getexecutorname")
local _exeName = "?"
if _exeFn then
	local ok, res = pcall(_exeFn)
	if ok and res then _exeName = tostring(res) end
end
if not _writefile then
	print("[DQFarmLoader] WARN: executor (" .. _exeName .. ") khong co file API — key se khong duoc luu, phai nhap moi lan.")
else
	print("[DQFarmLoader] executor=" .. _exeName .. " fileAPI=OK")
end

local function loadSavedKey()
	if _readfile and _isfile then
		local ok, data = pcall(_readfile, KEYFILE)
		if ok and data and data ~= "" then
			return tostring(data):gsub("%s+", "")
		end
	end
	return nil
end
local function saveKey(k)
	if _writefile then
		local ok, err = pcall(function()
			if _makefolder then pcall(_makefolder, "DQFarm") end
			_writefile(KEYFILE, k)
		end)
		if not ok then
			print("[DQFarmLoader] saveKey fail: " .. tostring(err))
		end
	end
end
local function clearKey()
	if _delfile and _isfile then
		pcall(_delfile, KEYFILE)
	end
end

-- ===== teleport persist: menu tu dong hien lai sau khi doi place =====
-- Join/leave dungeon = teleport giua Lobby <-> Level, CoreGui bi rebuild
-- nen menu mat. Giai phap: queue_on_teleport (neu executor co) de chay lai
-- LOADER o place moi. Loader doc key da luu tu file (dqfarm_license.key)
-- nen KHONG can nhap key lai, va loader moi TU ARM lai -> noi chuoi vo tan.
-- Dung string (khong phai function) vi la pattern chuan cua executor,
-- chay an toan trong Lua state moi sau teleport.
local _teleportFn
if type(queue_on_teleport) == "function" then
	_teleportFn = queue_on_teleport
elseif DQ_ENV and type(DQ_ENV.queue_on_teleport) == "function" then
	_teleportFn = DQ_ENV.queue_on_teleport
elseif type(syn) == "table" and type(syn.queue_on_teleport) == "function" then
	_teleportFn = syn.queue_on_teleport
elseif type(fluxus) == "table" and type(fluxus.queue_on_teleport) == "function" then
	_teleportFn = fluxus.queue_on_teleport
end

-- GUARD chong arm nhieu lan: moi lan execute loader deu goi armTeleport -> neu
-- execute nhieu lan thi queue_on_teleport bi xep chong -> khi teleport tat ca
-- chay cung luc -> nhieu menu chong nhau. Chi arm 1 lan duy nhat (theo _G).
if DQ_ENV.DQ_TELEPORT_ARMED then
	_teleportFn = nil
else
	DQ_ENV.DQ_TELEPORT_ARMED = true
end

local function armTeleport()
	if not _teleportFn then
		print("[DQFarmLoader] WARN: executor khong co queue_on_teleport (hoac da arm roi) — menu se mat khi doi place (join/leave dungeon).")
		return
	end
	print("[DQFarmLoader] teleport-persist ON — menu tu dong chay lai khi join/leave dungeon")
	-- BOOT string chay o place moi. UU TIEN fetch LOADER tu GitHub: loader se doc
	-- key da luu (khong nhap lai) VA tu armTeleport lai cho lan sau -> noi chuoi
	-- vo han qua moi lan join/leave dungeon. Fallback: doc source da luu local
	-- (chi khi GitHub loi / offline), luc do menu van hien nhung khong tu re-arm.
	-- Chay bang loadstring de an toan trong moi executor.
	_teleportFn([[
local ok, s = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/chi-trung/Dungeon-Quest-2/main/DQFarm_loader.luau")
if (not ok or not s or s == "") then
	local e = (type(getgenv) == "function" and getgenv()) or _G
	local rf = type(e.readfile) == "function" and e.readfile
		or type(readfile) == "function" and readfile
		or type(syn) == "table" and type(syn.readfile) == "function" and syn.readfile
		or type(fluxus) == "table" and type(fluxus.readfile) == "function" and fluxus.readfile
		or nil
	if rf then
		local ok2, d = pcall(rf, "dqfarm_source.luau")
		if ok2 and d then s = d end
	end
end
if s and s ~= "" then
	loadstring(s)()
end
]])
end

local KEYS = {
	{ seed = 222628597, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 222128867, exp = 0, plan = 0, hwid = {} }
}

-- ===== base64 decode (an toan voi payload lon) =====
-- Cong thuc chuan: moi char la 6 bit, ghep lai theo vi tri, khong dung so
-- float lon -> khong bi mat precision (truoc day buffer*64 la float, payload
-- lon ~2^54 bi sai byte -> "bytecode corrupted").
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64VAL = {}
for i = 1, 64 do B64VAL[B64:sub(i, i)] = i - 1 end

local function b64dec(s)
	local res = {}
	local j = 1
	local n = #s
	while j <= n do
		local c1 = B64VAL[s:sub(j, j)]
		if not c1 then break end
		local c2 = B64VAL[s:sub(j + 1, j + 1)]
		if not c2 then break end
		local c3ch = s:sub(j + 2, j + 2)
		local c4ch = s:sub(j + 3, j + 3)
		if c3ch == "=" then
			-- "XX==" -> 1 byte
			res[#res + 1] = string.char(bit32.bor(bit32.lshift(c1, 2), bit32.rshift(c2, 4)))
		else
			local c3 = B64VAL[c3ch]
			if c3 then
				if c4ch == "=" then
					-- "XXX=" -> 2 bytes
					res[#res + 1] = string.char(bit32.bor(bit32.lshift(c1, 2), bit32.rshift(c2, 4)))
					res[#res + 1] = string.char(bit32.bor(
						bit32.lshift(bit32.band(c2, 15), 4),
						bit32.rshift(c3, 2)
					))
				else
					local c4 = B64VAL[c4ch]
					if c4 then
						-- "XXXX" -> 3 bytes
						res[#res + 1] = string.char(bit32.bor(bit32.lshift(c1, 2), bit32.rshift(c2, 4)))
						res[#res + 1] = string.char(bit32.bor(
							bit32.lshift(bit32.band(c2, 15), 4),
							bit32.rshift(c3, 2)
						))
						res[#res + 1] = string.char(bit32.bor(
							bit32.lshift(bit32.band(c3, 3), 6),
							c4
						))
					else
						break
					end
				end
			else
				break
			end
		end
		j = j + 4
	end
	return table.concat(res)
end

-- ===== giai ma payload bang xorshift32 =====
local bit32 = bit32
local function unmaskSeed(masked, key)
	local s = 0
	for i = 0, 3 do
		local kc = string.byte(key, (i % #key) + 1) or 0
		local mbyte = bit32.band(bit32.rshift(masked, i * 8), 255)
		s = bit32.bor(s, bit32.lshift(bit32.bxor(mbyte, kc), i * 8))
	end
	return s
end

local function decryptPayload(b64s, seed)
	local payload = b64dec(b64s)
	local s = seed
	local n = #payload
	local out = {}
	for i = 1, n do
		s = bit32.bxor(s, bit32.lshift(s, 13))
		s = bit32.bxor(s, bit32.rshift(s, 17))
		s = bit32.bxor(s, bit32.lshift(s, 5))
		out[#out + 1] = string.char(bit32.bxor(string.byte(payload, i), bit32.band(s, 255)))
	end
	return table.concat(out)
end

local PAYLOAD_P1 =
	"itjPzItB6fq6AUgLYSWhjpV2qE1zNUXg3JyE8pxmGjRYfXsZ8J5uv8o/TS05uHGrNETK0PRpk/+1CnlCMVo/FDoj+cKrXncjimtt" ..
	"ieY/K55qRF4pSbwkGMUK/Yi/f7neIkMZX4GOBfgUTfenIRwZtFAwtFa0ZZSY2HIarGO3tBu7NzSHf4zYhNo4/pzePl1Ua3+gnDwS" ..
	"zbnD5yhxVmHAVl2lzwiczKp1NhPTXPEUqcK3p0bA/mzlme5fdZK3GJ/SaYcmqvwBa2JCcH49OmnQFYOh6XNErPXaqozEVOUQm6yb" ..
	"8EhqM5GTwfx1JsCq4LZLHDfNf/9no0aORwtHXWFXnBkIotHKhEfU6CsbEb7hEtaPqqSpEefwVKRGhDUC5h3fmqixJGfD2uThwQeG" ..
	"ndS/VjI8Cu9JoI/c+Kv+DlMACf56bfKFSXkBou9IbQSfqBzz8NpUcbWAXltWE1Sk9ooz0d/sC7dI4IxC9EUitm+pU/7NrKcXX1BN" ..
	"qc6Vb+XGt+WZ1+NI2uG2lrQOXUgIAW9OOXd6BzU56d5nnA6uC3LVLxz7zSs4B6eTpshUbj++PPHmvx5q3PUKQfW464lr+Xh8rSyv" ..
	"b/smfM6RWWl5P6Ic0IBOk8ndCuPhggr7Aqe+OTfXXeyXKnZCQ5zfsL79c/H6jCbfWEjqwLusB6gGZcy+go+u8TmpBOw2jJKajXjo" ..
	"BA/64CmRbt26GIVvg0aWhCTRREgEN7wpBApqgprhw8XRZL1Jh8dab1xUOnEQR37gOubNCregqC76SiLin3GrL4q2p1IKFZAMK2fv" ..
	"FQRHoV8qZ9AVm8qFH9kmXDZDtSaUV9nIkJ4jcAYcl7f4AoteMHpiZ5P7F/LfaeRS3NsGMTmLwNQwTQA8xg18i8bu6hgPk5E/G0Mq" ..
	"JfpT4LLuYNID06pz0kvNnY3CfH9AEQ1Rqy4dDsrV6IS7/s02NVB3xnZqxUIwaLSl0lFOfdmxSqaK84LRWAluGcW56wfMGQvY/f7u" ..
	"CptTd5q19ToVEM+fcQorairvLnb3j50s/EWT9aoC5SwlguqwkRwRZoKX6GSVbLHkY6iK81c1dBJM6bEOdHqDokOSDOO4Mi5v3amI" ..
	"jHXFyG8cghXHA6Wd6vC+cNdgPpx8UT5AVfx7Ou9r5hxDa8QknkzNOyx3QnVKxrNp8EUUG+VTbCNhS9b7FacBHdgJEcex1HbYYyfw" ..
	"PxWhDx6SK0as4kVYfXQRjiQ68YZM37KeSOJzmIrb9b6NG4BcFO1LI7Loh/lrfh7GGHTfB8LSPYWAk26EwgERQWo6mZXRTEmN5lT0" ..
	"W23gSPqCSbxHbQk/d95QgU3vjOIkG5r+DxAWLs4C0W8rFmxOXXQbXGjsukDtwUYtjo9pbf2qVqjg187ieQ7/qlRMkh/vQ8RqhXYc" ..
	"E/L9WpREiWsNgJCyGGmOOmRPu7dEqBaklGwn2L3VAo6gS/pgWuHxJUuIMiFJkAsa+0//NP9JRCMGVhYCpc6Dq5uU+rLM4cfss/lK" ..
	"npZwe/tY+7pLZAAn/dDQUYNIl4oIxGSmBP7W1FxxITXYjsuoOutu4TxBzb6Z86Cqa8QK6oMMQk7TZPOPDrowVOLoxDLo3jFvBTCK" ..
	"yXTbLEh9HAzRTnGWsWaMhKVXKNuIdoD6RcpLT6VRG6ZmbHT7kE6GRo3h0ouuq7eTkJh+jqk4crn5+H8B6nj0K1S3tlLnMHbE5glE" ..
	"yHl50zoP/aEmRAgr6LgEzsL6/XQghMHxZEnLevRQmBkWQ/X0nd5alNx78mTo9hVF1bfJfgi8qP/1I6SSkrwged1j7kMPw0GDY9QJ" ..
	"8LQ80IE2dgE5YV0gvMqT6eIHz60gDRKdOqr90Z4nXvC+zLUkSKA+L0xDXoScBdkPSkXUePL1b/boCcYm7QVH0bk+hy5DxCYWQfa1" ..
	"bx8Ny37gcHiT9brdo/wZfG0Ga2UKEyqcV3uyTyup4iT9s9Rtow2KfXrY4oMbq/F1O1ZnQ8+JOuLohkcwuBeGtmFV4dOjQDaIBapa" ..
	"MNq7r2ITzHOKvwmYtXW8nu/WcuQu/FEf5kKQWqsuQ+qOiN9pout7uvrWkjMpRQuCc9BLTQcgLOLHrvXKNnltR2pxc0Tavj+CUwsf" ..
	"hhis5LyP/74n0tUZiB+T4mWNYabiCywDnlvcAPQfNbAH6Sp7AjFhSXjAs5YaTLagJudpgOkZkqv/b9/HOji8+SYNZm66FHI5Heog" ..
	"NhKvHDVqj/kOpl9NSRg93ggaG+K0HARQSdgiCzswTibzJfZ0WuJOPdsvROuYpqGhpowmk2Tchu6lsOWUNU0pqTK1/nabqUp5f4hU" ..
	"v0PO0G1evPkQJ3JLN+MGqg9GdEQfSGO0ZVqcc7rfZ5r8Bn50Hz8ydAqLxo0qdL+x71bQv9Vb2TSPY0bWfBNHPP2s2dOuUTQFu4b8" ..
	"mg9GDb9XS7XB0wwK6fc0cm0LVCk4PT1NEXKgb8BDjdsr1bxEEq89bKF4my7bZhfhuW8c6ByGxTR75BGBfoKs7raRFY2bM6DjxWcI" ..
	"3HHHpzASwYz5xmtH9AClN+ADnOEfn/wOnxxbolu1h7bxGkWHvSagI8FN3g1ucYOtVLSzPGQgiJJlCYH0C9PplVlUY6S2N8qGGeXz" ..
	"01ht1bCXxj2+KTKka27Gc+RqO528RS30Wsn+YaS0dry1nxmMFiScSqdue37swq8AzgRAXAKuikIxVImRNVaZ9DsMNRqK9t1/jbNX" ..
	"6Xe2cYJymCoL1pGqsqppUZGYarATDlOh3Coc6FJqsiTxuX3rBEWeMtnfZyj/ImD+IsBwCTsXBX4HSFv+Q+YJO7gsKmtRRAikA0dQ" ..
	"sHNpl0J9a/mqbW4EvGa/FeAgfHRkZGa3b/tciRlvTNYPlujFp13iZ5No6X2OXdK+oESl7VRROQJD6PyYvAZ70f+NKxRJ5LpzIz4s" ..
	"ndH9rx9OLyaswubED09JOSFVStKNzcDcoeawVtzBcwBtN234H1ueOr0zNwuwS4afs/+ALlILSyX2NNhyuncqahC9GoSyw+AS9gID" ..
	"Ei17QVB4UKPEmoUlmKQPDFnMfms2+vvt1R5w6mZzpgoR/NbWGuPnbKz/Cn2MWWtJLzMG6nrSISUgxF4JPNblqQTHZw3HhGxTscOA" ..
	"RiAR+cQi0NVWdVozzzu9cGbQptsX0zHuBNp5v0+kwvxrPgcQZ2UzbVfSWZqOURGK8/1QBSg/vdxgTzalQif1ucfl6PcC3VqpQ6pq" ..
	"uH3dYQVzp35r3/cshEzf1Q7a2HTRiQk9Nno+ggd6yyn650ds8xtBJ7Wk23apHWgYkeafrte+UMzU4m63yESlAN3cz3G8VIZkmkS+" ..
	"dteQPjY3f6D8sYK1VYpnRYEoyMew0FBoDG/4CQtKmHzIaCJwo0deQbq8IXQM20+6QKH3yrw9pNLGFJe+DQSFZYBV9ZoSHCnv9dH8" ..
	"076pVxIJP8zJsP0E3Hm/Wq4yPHeDZXu65aCqDIdMGtpUu4TzbA19aieWQdwld3AiH4joKuQb3VCowq8uYiHTmie41ZOOoQE1nEbu" ..
	"rt689/+NCr+4WM/gQ946fKcW/dhJKy0TxPrhkfMM7g33mOqO+nN98Kjes751fEaPds2ZcqEHvzMIgXwHu/t4P2pYEe0hGHlUVe5T" ..
	"PpyztkSszfSUfl5J/fe0swvefm9AvuJtSBxPmefpcjzbIvIvWBMeBGfthFZcEgunI3UaTFmBtzVcCpRpN9zggAeTBueQvcCzFpdD" ..
	"573z8UaM1i76zYSW1qt0vk1iQICWzzWO+ZXojCYKvIfTE7fU/3YxeKzlvLTwxlR6R8nm+3l/G9b1SiArgPSLVLSpZ9n5CO3Bp4Az" ..
	"RDh8MKd1Y3T2SOmfBAIV13c3NeJ0LSY3OBD9WgWDFg08puVOnpBOpp+ArdjXgNO9ARV5xeH7xOTNag9B1aFtQR4xcNROAShrECHm" ..
	"J7R7CsUKFSEx89rNHvY9jv+pZzTuttXAA2ZU/B05vZKy95N6KVWQsFyY9g88ZjFABA2UUbr9tsIxQElrOx+b+DvQ6W+orRioXRHA" ..
	"242Ts7a64a3Rfcf/6eM/nmq3rg50XcUDhapMdTPVyFnje7Uxhpm+ntPD/k3u0OXxdWmNo5T1zggVLuywAEV0uv4hInPNT/NF8bF3" ..
	"LKBvBTONgsoRmUOHxJac+uty8P8NclonSiY3GklMbiJLZPmslgnego7UCZJkp7YhWDLNbQEewH+9MmEUVdV/UnbEb9ObPSwheBxl" ..
	"SunXNNssUM0hUnoPaTUwN6g6p450BJdIpK0EwHZiyuB/Yhu+ZlfkA8U+wcoaqU6jKOzdNKAI0AcPCf0k6QWuJJ6s8/d6LSJc85nB" ..
	"x6zwbm7500dTPYZ2BpklHV2q6NcJNUsNNBtikYUPr22WMvUKe0dwr7tD11UMjYreLMgb6d7yXesVa6GOiKVwatIznWOxyUcFaSzz" ..
	"Cq9KsjG+8nKygiByMyFTeVzGl/1upSrIs7xjFE9uvzAkWcXsNvTi6BSvYf7YwKqdnxlTSUJvHU4lmeBT5NYkXF/g5Jcj06UcpI5F" ..
	"hHgVC54WtgqALQ+DKD0eFNJPEtAg4XcOEiML0m1+WvoA26avoT3cjGPcEgp1qEHNXIkpGbPgNSu8WxVxbhqiJS2SWAYeDtNeth0Q" ..
	"1NDvG9ZdS52R/TEXeIMLjX3JzEqD3q8nQm74DkJ/Of7I+QdK8+4epip85KQu1gq2lkhZMB0Ulj3y08NDN/eBamNz43UkSja1Ausy" ..
	"rN5DWv+wAVmI+aMNIU/q6GZ5+Vf/63YwfqLOf7flGJiCBctNpK74WjQPiqVvdKJZjJGAbkp7AHfCDWYaE5pER5qMdt4MakIq8NxL" ..
	"TXIJjJzKwaY/PNM4QOY1cqEyyyDG4sJzOrwZADPCXcFo2yKCv3sgZKID7D/jG/Ht/KJgAwHD+UmRctWn6oC9tF806hO8HwvFe80E" ..
	"TIJg3uA+0E1a9hJKhvCmlBi6y0YQn9N9elUikJS+gkf2w6uspAjEylSrNZZvQ/yFPmB9ZktqZMUAJzgixD4Xj9+JwttWzYIXi1oM" ..
	"PrXqAJKjsNsZg6MsMEHgPfqFrw81iRNYOTeMqElDwZc3eiQnUaswzx2dmGhA5H8lOHgbHQFNqOapAvwlsku6g6jkSQvPnv9JZhrw" ..
	"3r+bkpQasmf08XOG6TcMxIkbDqeq1z1M6GAE8zRyoeTOMpVRMWruVWW4EvAMf2RLOT1OsivtqF2GrPwsSiovVoaD6Ra1POydsJXf" ..
	"FlTnqVyD1TkTSZEwuLi1bs4mFIapfPRLy8U1Y4l6958xqfSuC8DfE379Zb1eVqvmjZT5uUYSfjM98ODgWG5nlcLmjwipQtZo68bQ" ..
	"ECkc/7cbw33v/kv7tk9MD6HvEhskExWQkcPP6LD2mF7/j6AzA/e7aHkV3GTBVhQpCOIlWgehqMFroGzv7kuBEvxErIcqXyxpXEF7" ..
	"D0vG7oO0q8PsMEH0KY4U2HD0wjs/DvAkAXYi934Vm73ePb5dRQ9ECVS6JT3ZZbcH7N5sNJrfjL1yGUbNHOeIiaUQoA/e3IRiYCJk" ..
	"DU7mm3VLYvoOGbJShgqTnAkKID2MsXuU5EqkkVA70x7dHdxdN4ZsJfdETtkCwUzks7DrdfK6hZNs0iriAfBqCxnxLA1pVl4mUcai" ..
	"PX2CzdIafvPeYcz6YB1/D885QmgICOOwdAz3vGKwcMoUZEKmLyeAowl6tBNI00MVbbU2G6vleUhUa/zkjwC5RUpXiFyfeaE6fmlG" ..
	"2lnsp2eW+opQFY/Ub3UrMuirDjjW+U1QBOvb3Dq2nlrpngp9qu8pbLpgSFqgADdgPYCdh9bzioK9xw8DEVRTEERP2ws+n3Nt5a6n" ..
	"lr313K96Wdqy8jdtn3hC2DPA9rWZJ45B//eH2tJSRwvp3FN+Rjv4q6rKkU9YXzR8rgrKvR8ka6lMdR32ovkOArwgQ5huQqIi9H4E" ..
	"6DcTua1daPdrNVaGJ0jcDspZvWv7+o73v6puOuk4O1GcVmS6+4jTzo5NV/nm0XisIWQUoBEK9/IML+gfs+Uz5tuq9AWsfImEYLiQ" ..
	""
local PAYLOAD_P2 =
	"DsuZOc5lwLJxkCuHfnIIgvba+s4f7IMGkU+BVqNUxyNSTnj+h1UxTzJgjszFMo3UROblhFxWIRMzkjSnlDmnPzuWy6ITTajd6zin" ..
	"xNw8xfpMJvLTT1JWMz9zpgweDTZ2EExlYoABsaYIQ2YgWMpi6EBGXLqPkOx4isml22TVhlscckLingmpu4tCwGPQqOevsqxoF1AX" ..
	"DQ9StQdZhsN3K75Ho/3s+ceZsksBzsByNnSK2HLhZn01dvCOlxJpRkaYG7XnZR25XVqDdgXU7DqqonAOnupnTMLcQvqKg+K1xmuX" ..
	"jXIx+qxKR1kaWVMZYMsMBt5KXREEvzymCAYwXX1y9GVVyMxzjB0XF+X/y3XU0BRzaQBxTKU3RqBogBlv4OUWsxnBNm+U3G7+2gHg" ..
	"xTxJUfuMAESbjmpdA21r3ulCFNsKoJzrvrn0AWWDXMD7pVKYvJJtF1I5ToFF23tEcrMlkUHzpbZyK4q3Cxt7oi4zKb8oQHekgMvH" ..
	"C0Xb4iv03aLWr4U3Oj7Lq/HA9EF9MhMDM9iaQfq2C1FOLjSL1afUPa31cDZQKEt6h3WfP05JDvBNLwAzcSfxMu0tlQvDX2pLBczX" ..
	"L8/8xq4MkE9ZSUd4Y++2lneOFvoqPYOwIvI9UEJWc6v5L5IpE6IopeUQvhkPH7nf8kCza0XPb9ImzU4mbmFUarYd5qzQSUQbJKvG" ..
	"OeZz4hmw9BSQr5kGMZGg4l+6N0YK00yXasIU6ooC6trB1F1nECOa7YPXuMkKUjQTiCOODJBdm3AptHPpBUAi0LbH3hAaCkyCC52x" ..
	"h4p3xeEYxZ5gLx0iqBtjUMEBBOtcRLUcxrTNHXxXAd3TgZVVstiCL+Is53STPn3jM48eS+t8cgS4Jeq02whhmJcedXzvNaRavMny" ..
	"DqRGcAEGLfxj/DhrWL1l1LoYv98I2utViQAuri5AtvXZRQlmzqYKFNmWPfcUTKC8iW8E3hCzNm+VBa6IV4Be5e1iNNkqNFseRPV1" ..
	"ZlA2UP0k47XzX7SAgm4i1r8PuUMTH5Vn6yHMEBkV2GS3Rfn3rfxWp4d8RrxZh5f3jcT59aRF4JVJxjbM4+GO/7KYv7X7viszFl2K" ..
	"7p99bX9pYBhcy2pnY5N5cRO6ggcARfW6Hax3jD9t/dKLpgT7KzwNgl2Hs2V+jSFgnXYyO5QyyItEyia2W+twf71YCsNQE19FK52k" ..
	"gPW740i0PC7igvbF1kmJ8zOd8uRRhKIoz602iY1juYXnW8x8x36mt/FqtoCbo6RjM2nhVowJPhhbeR7RkCck/POospyLH6DmwFiv" ..
	"1sMtdtdP+lQ4LZ0zEnB/uofjYkM0AKe2EgNpYL3xI/Vl9N1IPkm3p1yeZ1Lzq3RagdH36hL5r0OkIVvnKdppis1ZI+09rM34KaEr" ..
	"K4E0f7u6f35/TRGXBrnCoKAj9sKGAEQxwdC9WahSGFkvlusNQf4CUVGZ8gukU10KW0BGZncdp/lPAulGDnEQVbFnfC62p65wAmnN" ..
	"6bWBdm7F41u4uHhWuXy3iCzgg75jXCmmAOmFVyAK7093ak+/9wm2jgpdkq+QTeBggp9NDwQmJD12Iew2Wp/TAfQrFIe9Wiy0I1Xt" ..
	"TDybQUYjaG330HtwgbD610WrUYJ8tLPhG/jioahrmgIuHNtELv65VPZptfN2pnqAYkh8q4h/FhgLdCemtob4a+++5CfyRDenrRQm" ..
	"qxUoO8GgZeBa6hgW2phbBVRtAtmvr3AXc2VYBe85qPh4vr9kOj0G/WvGk38jg272shx0XE+9CNdRQt2WXckKQOyd7ce1bHRY7xn6" ..
	"l7RCxZWdcvifXpwvKRO/drNtL9gylHLJUfaNZwnixK+ZGvWXTVKJhzktxujoQS0QpI1ytApzWYWRe6qW0vRpGR9FJ/0j/hApLRSS" ..
	"ijbRM6WY6EfvPaoE7gH+rINiDdiCUP5eeDJbTTvfxINyTyjzGcADCW2CPVAJPvBDKKo2Htj3ObMETs4k4z0ggZ58ekE6tXvluwFO" ..
	"WXXHNCZLa5VfjPWrdQw5VtfK2JQYVpUBWXjrtArQoSgybHBbJDRTt8J4G7LhFcU1vXX5hyBJKhk8icgU8FNX3OxoMRmAkrb+jb3p" ..
	"U7I7IjvyDmlVZBRu/opd5+YIkycqu9O7IRNjP+D4cbLRXkIjVO4i6LBL9jIUyUp+JiwuL8KUJjJE2GZWJb7mA1clP8iEjKiFmzxX" ..
	"sI3nUvHUtiJVwPSuAviamcftSvWcUEz0Y72XHOQjQAirhZ0O0xoKuzMeUkSIo8pOSWIknzh/Abf/Qk5DDqrh7onx6eyp1q1cPp+2" ..
	"49BV4+e/IMMm3ks85MxCixQd4lgQOXdjMUFT7sW2sMhEBIXCnZ1rLFhweXt/Q3HwyVMqbXCaDDLjDMBYyDPJYYd6oo8nlGMmuiJK" ..
	"aUwZLfqp8DASikDY7Wx25EkPaSLlUzaJzFqaKaO8iiYrVf+Rik2Tl10HUnJFvCO5ajyZ677V7arNmiPaRYmWemXuKczOPgzqnNd2" ..
	"A3pQsUdD57ldNRTwProwHoMOgPd0Nx+/KkW+AlcGUnf8YzOmJhG8bw3lI+6PqIhlMrY1URD5JjbrLzkGMjaViA7F8zKvtXfkRIbs" ..
	"fMONDisEoJ66BXsedDQZpg2Tj2kLGMr4cLvsDH0n1DYYyf0KIR2UakLHRlhQJLxOuoSNXXb1P9UYx5AlUL8+QxR+/pVdVJ0xfJ2z" ..
	"Txrn5w9ZY5fnALdwsijIs1MztLw/VnVS6r+dxgCVFvIhs7B0x6VC+F9IqATpw9dgEeyD4qZC2z5BeH/4NsXRfe+C2NwUt41+yEfB" ..
	"jP9eiFJHL6tg8Sz9Rg9fUKvz27GTpvLQ5+eJX+QlmWmeTXHJrDoOJSP6exCepJVjaF6mcDabHWPUVd7hxyL7/K9xzh204vhOX6/0" ..
	"qib/21jytrukyJORBa5LP+W3buKJ0sAWqQLG++u9Jw3sp8LtfKFtnS2KK4AlSYauCRS8wT0b7FWHXs7qvAUws/rDhSrpxiZFZDAN" ..
	"iS4YJgMJf+hqxkAM5+j8gpMwAXptl8YFco2OeDokm8H78KICfEaXtDM8db3Zp7Q138wm03NeQh2lE1asFybMesx8iI2+SgDrxe2+" ..
	"DRYvYGi1znHVqza+RIVTLu1b6lbw7z6AbY0qorr3H8LmF3empNUZCUcRLplHk6zucg5je15806YOqgXqca7Ga5pM5+b/UVA8P6on" ..
	"oBZ6Gcgyoy3Se9kqoP/ltiQVv44JUIc2MgY6M12H3PhAk5W+AMiTMWJM0/dZwEBe3KGXrN9Xw+AjobQS9f1NFKCWaSrRe4cO1exa" ..
	"N49wAiOMFtfZTRDa73fPjqgbmfRTheSruCu/QfSV4yu/N45PXAhp/YdKYHbGCyroVRQOzttDJqEMHbtB7LOR6xUMtaBvcKWFzxHI" ..
	"OIHE5edjDeFvYg31Si1EzuNst2+6F+ySBj2kw/N9rmnO4SeDbNbMUoy1QzMgD1KUMEWqotR7ijsEpQxIjytXirpWD85CyBS3DntR" ..
	"i+Ob4PjzOZuhBic0ZHXxtNf31JTNpL2+ugZclsoG6E55n91ImZpZ1bHZHSjA1CCYhcLFfkywlp2UzsUIptG5O/PWvC8AIYOvQ+sP" ..
	"nijGdGNiUmoeSI6rXmzSkoxQ6rSJKlRLq3p3scfdlII5DaCvesQhfiK5pUyPcf4QfWKcAXTLrpzdqziv5YXPVzseWET5En8A+Xr3" ..
	"OzlNOeFJXQljDVKlLsSBZUuBWc/smpITOKmVoBwwUR3KanoCRZHeGmtMogoLyvpKkeJ/Zjgd9kXzRBSmLXu43kvRh8VIXNrfPb5Z" ..
	"1nGH+trvh0lY4nzIhzQTeoDa4jk2amDvF9Tk/xahAGyLIYMxTptdLGYAUwFX+mu7KwIlpVrq1VvmoiviAiXAkCwMS48l9ZwfrWBd" ..
	"424PX5JLaIGwdSC1Bz0CEkmnmxfJN1ZZ3JpVLDRDQhZ+xQYGN3DI9LhCMSJl8GNzI1i52BvBQ0D8ZC5aqiItN2rZ3pzWR6qgENv6" ..
	"qai4KwkfKa/ll+4njb1ez07r5XA1SLeS8AmmfMQR6/WWXIdt/YDIFg2MclsHbp8qwksbQSX6I3T6MnYu60Z0Z98mEzAMwfZ5N/7S" ..
	"JxR6z5Zo53id9mdQuCfv9WBUB9i5YFdrAr7LAjfOXn0HMKJInhOETutFPUaqWOehwlAe0RMo88Iy/a73sh+cydjy9lEICMIFn6BG" ..
	"f+upwt+tPEefqImmD23MFTR9/mj5T7G9qZOydf6Lvd5lnGeat7O8w0It+Dgg6UtUYYRS58UK+Y368pJh8iprABIy2x06NQuOaWW6" ..
	"3YLrdACuLDbxUResUjf4Rglkm9H4+qLvOPZqC9+fHfd8ofctrzl0e8h+euwcLp3fPbUrWVAP8im8xCL5zdI6Wv3GthhkBCShIMBK" ..
	"syxMDAMC5GZ8d+OagGLtrNQgGSH0RDsXJ5ewGwMhiDMq6h22hgH/t9qWA++G7+a0bT6eMLLHnf82sf2Iaa7fpuKfIV/jy/3rKiG7" ..
	"FEiah9W54w0FUt1GUh5nq3LmAqQ3FDvefkDKNUQDOUV0tEKpNkI9iMLBQyVOHtzkGAOtUJ1kz9z6jE9Da0qBFqdwcvmAklEs0yUb" ..
	"l1DMnm7aqBQxCWlLQXpqXnz+G3PLMCrjrZXvPbZl5XOGJErEuFAtPc/vBef/mO2jOAIFH/nEn0VPYVQLhLHjCDNxvjsnMj8oprni" ..
	"5hPrmc2LsViV8t0P+o9HIx/WcRy0623MIn9Uiuik1nQVnBWut/FAb1V7j4o6+W8k7pqcYh8YhbhkO0ZmV5vwLOGH1zl4I+wiAuIi" ..
	"hodtGXYkTbIixQsZlC2yc5N784BehyMvCpSr8REzhZugjy1YuyauQl1nsvoZzizTE9+9PV1TAilZ68Bx0KgqC5wgVlKamBNei5hr" ..
	"1HO+9n/X2Cve54UHe6+997yRpM4viyDR2jR9TBtfjy27UvWy1mYCvGMLjJvhEcMLGBys+Ah5E2lJ4/ogFLn44t+yhG8fUqeOH0EE" ..
	"657Scaju1MQdhv6qkqOXasdtSXcV+zsLP/o8kz26jRjX4XDwhQrLcSB/SNH1huHVYC1pd/5aMoZU5P+hU7SLp0thSQtxblxPGgvQ" ..
	"dsE8kESwyn9Fu8UcBd9Ws3w68g5htoACJAJfhBJT7C7ihQoyLId8e95o9PK56w5g4ZZwaBPwfPvuxiOfzZ1Rs9SCQHq8RVrpgtXU" ..
	"zNj31ocuEodJbqmQivXvXpE4Ln6UTKKL59ULsMlHIOmcPiUf8YYxYHpKrhRSMwXyMN6BRGndTE9cn10slpBIY8J6S7jeBqj/MWMA" ..
	"om8tdRK8mQ2hB4sjI4G5mzRxJsTA9wfQRbiGpnighAbR6+E6qHRE8SCsyMtgzQQpdwpDujefW8fMAElh852sRhB2MQcYEFykPw7W" ..
	"zJW0JKtRL2zWQuXHa5S3TwbsLkkNv0hQCvy4sb7MqdotsfAZkndUWliphnLj1x9yKKy5h3xFtgtzVCjpnArY1FmFWvEEDBE6WrBZ" ..
	"N2VccL+EoA/XNiAO49+gip57cr95K25coFLJQ+WZ8m4Kh5glSpHO/dU3KDiEV78yvQ5N9GmHvZJd90tS0QX5YnSss3bfjPpziV9x" ..
	"fwQSInClnvpn0x8QHpDTsbnFVdk7Ow7MUASkbiMSXHkoI3jxu8YEenRsASj4PpD5VkG0jOoUP4fJb4Aa9t73p/Bw3HD/py3y+Bpf" ..
	"yZlqWsiK9xz5tTHD0ZwtSF/MdEi8oVKfN/TlqpmZJ6ZJ2FoX+Q4EWzserG/CnRs9OrqaGdQ5Ckw4wqVXGDbJ74xhEVXjg3/y79Ij" ..
	"oQF1n/v+B+fDePTNoRQ+2sCN54fOjby3iIU76JgRZxpZ8sm8T3NYJZ0XRUH37hs5wORRqPXkM2abliqCpWduOTZgslbOHUPtBDo0" ..
	"tQ46f0JnF+hmupOzLJFWvZEI98U9kFhBTb9Nzk12OrcBV2GEZ9ZyHOsRKqJ7O2jLnGd/5juyZaP6ZZL/cOpnFViw6X8NeLJ0IyXd" ..
	""
local PAYLOAD_P3 =
	"/+BjcyKLYGFVu8/GXSrKKZlShU+Y7ZABXF0dehlZIR1134k+EnZeNJ/shqCxjSx5t3Nf0OSRz11GCDlgfBDgCoyHCo5m5AkR3Pab" ..
	"vdMDZmM2VDOQWeEuhSiSu70OAn0MkROqE+4YUANRFzhmDOV8IZPnG+iAvdpt8OHPUX81nZm2oLWg2WuwtFDBQN9ivt3j2Qapug5l" ..
	"gSTK2p3se0Ej0uT7+I3YQXXVF2zwqSqkWOdTsMmHE6oRdUhcuruu0rLkLbOSK/wm83Gn36Mki07frbUX4r0wT20cVA4i+h7VqXln" ..
	"XwHJeDtpFRlORluH/uF0/fLxxj3kcX3dsDf1M6efRo0LSHkbf8ptx6bKzomZOFNo4KMlBOxLJRXZFx/Rq6c7Q46i5KCGpuQPDzFK" ..
	"cOFvVEkd+WsUJXqX90JQmCobo51isXU70qB5OAvNbV/GrrhfmT1g/DJ8B2ATJkJgDc5rB/PafXqOtPRDAybfYnpsb1ZSTu2T9qCi" ..
	"kbOiiPF3os9GGKjsGZNBJBow68O+imi88U55wcbLYJU3tXp9IY0/UAkFgPAXGX1vncOqPpSrz5JcxKtVM6fAIEWCoy0fpe2ROajz" ..
	"7g16w4anNYgNKWUTgbxH4VWRuqVexVxNBEBU+8uc6BU+xOeZgx1a0npdkyvJ+LVEp2RSX1iPII12BjlWHNh0oCDbfzmvOrR+njok" ..
	"Apb2sDMLVtGGKm3L+7MTsbAviZTMkCZerPlzUSKoaL2tW9WtIx/KsWFBZu0twTHyAFTQpCvDHChHCfsTtC9zRaMt37O5wTUjhdg0" ..
	"NPSwVusqhcNtYgf1wl+NPXTx+wUt8LtuzgWvSug+igbLYVx+kK6mNbzpbe0HGLgXq3d+Ihm2zHJyOFltulQnPlKxlxrrkyWZHLCQ" ..
	"0eFhUcJXRrvfOlytX2ODZZo4MH1uuEBtNl2WJAGKMAnQNVGsU7kxQyxpDAg+vQxynDTWniwj3Ifb62Fy6llKt+dJHLmEDaxqMQAa" ..
	"bcoU6jcdXTrbGscLLfouRNFDUrvct3QzTQ+vguwxgviFJLOZNLEcUnUSg3swZnmffhcfBK/uQM0dwFmhuURZ7llYWiNyKwJWKxKy" ..
	"PLDiKVsXUYRQpKKDzIDNJQfHWIobqLIYhjeOZTtthL7IEAJ5ZUB7RR5n9llPTblSxhB/ro/t+Gvw3+PojCO177MPsCg92QJwIaXA" ..
	"y0QhBLyq6lrUsauu7pDfrNc3PLBC49C869b+fupLjqrkMKtPntQNaN/VZMwxMF/hbNIDvNe2YXlT9hyQRPuwMrwc7l5d3uPmycql" ..
	"xqfTPTd8xK7DfQNl4Q9AV6ZJMPAlZnphyYsDaYlRtQ/bSEsFkpgHzcLFe0jKDwQQ54b/0G+KLNX0I1cHU3YoSyfbWLUiVzlikw+H" ..
	"4yAA/G7102uPJ3ugVgMzMCjDgO+qiJ0OuKV8GKVAtpfX/smMNqmQoqJxC3F7HcyxNecN2YNHLGK5KqrTRc6pz+CEoAlkUGkfPkBo" ..
	"rIjUg+0jviatU0FdYQdl3z5ZSxSfy94nU2Id6ATEUSbVhrVpsVz7tzi9aoSY6fmRegMZtWwamQuaNqMI+TpqwlTlOSK7cYhIHrFh" ..
	"aBsaUik5Fnqn+pSsfSuDMc66+2CJzKlEGfIOiYivJWZkPusvguUdUGK4WBhLI7cubhwL6MIHhYSdmAtiWCsiWiGt0PVSfWv2eq6B" ..
	"YosGT2CukFiLoFqJ0I6J4OJmMRjAlQyuBG7c09hpHmO3BnufcFo/6lW5nTIiXo0GMA4NMjpSNsaVcBKWlGUSSdU4wKDYK6dXgGZ6" ..
	"YeiuzM6iWK4Siw8N9DJrPDqmpcf9ky2IJ6wQsOyBPxMideoSej+9EUsu+y8oBRshHlDFZ5P36OglG6LyHXnWM0fG6DbRCjgMl8RG" ..
	"q+W52gqHH2SXb6qlpVPx4dEAgegJ8giQdIq191q/9+Z0bwDIPeohU85pQ0Qg4XotDS2qKU9fHrMcT2aHR7EvloQcgXOOzMU2BzhR" ..
	"fzi7CR2BIzCCDihO7TF+/MFQrnFQc/uJ++zwCnwDiVqXxr5mFd2YLnARO4BzX/OXkkpbKutc5MNHy8W3srXUpqXDL6gsK/RpORJ+" ..
	"7LS2j6pz8M78d+wI5AowoiPMuA2tCQO0eRZAMYsjnWsDvKODsbAd9/rkvrT5O4IG0t1dAs9Y92YswyTHfUo9qaSyhxAkEQ/0XDLO" ..
	"faQPE3XdwhpT/QzyekVHuZyUF+J4h60ZL7bxsvcqL244rMuPedyAgqbqQTBgo3MjfXJN9hANjDXLwPFjWGPrNLcMRmOfcRt6fDwb" ..
	"W//TuZSmGsuO1FdQLXkSeLU8T8tWM4SKGE8bkfFWUc2vwxTQ9L5KH1HcayqaKImadeEw5rAWCXf/gyfb/JGuJSw3m/92zjYUT528" ..
	"HaiezzoxwUr19F1I3X60cM/GTKlYMh25YVKdtWk54mB2aXQyJszLbX1TJhWfUQnBkn+dPEIHv2Xtcq+k+/S+FJUIzPvfL/RPB+J5" ..
	"ghigwQ6NnXgdNE/v5EpAR/K3idIFvFNm4Cs/1N6VGIFMSlx3PyjAkyG43440OqnlMK/9eSYAFsZHlHmEIdlgEB00xFlCe6z6NlMs" ..
	"OeZ2J5xHJH1fBIjMAcxPVIRmd9lRgTGWQPIIZaQaY6lRwc4dzyeY0oMCPCbIctVMDL1f2mP93Bwv1vQuShf4wZaOCTS/ye2kYD5W" ..
	"QcAMRMj0yhiwVJq+NJQQO6UT6QyCA5y4ocw0N1BdCFb8DXe/eqPJ81zhJStq3R+Ss62ILCZhZtGr3qBq+2dasSZW6S3NnFaA1pb2" ..
	"+MYrRkpNroi+KKCJulQszVAoDAcyoC0BjokRPzr2ckwA35eQSIFUZ+CbCPIpUlem3NV30nQISpo3NLIaCUoZrgV4hXYx94pzWwfU" ..
	"bSykzQN99UVheCOyA6iUzolP3Bf0mQP++bFjpkaSQHoB6yIpXBs+AbdAhAyNmYKEr8RCn8EIJ6WnR/AOC3x0upYFMLTlaHs2p3r9" ..
	"0hVsU6dc7F3MK3e1m/lidLt1Z0EXbRtKj27XcIWXFVx05sIxrKVxjiVbFg4iLBvniAzcCbkbdQn0Cix9uCDIXr0Zg6yWu6w5k8ZK" ..
	"Pelp25oVRZBY7XviIs1XpsKwKf3cgGNI9VBi3IdmiG/Cpw2CA27ArII8nrhNKXl2iHdO1RhWZ2POrtgRGpEOSXws1qAYBq9hKXV1" ..
	"CT31ZHJzpHlMPkmdCQ5V+lWE+aH9p8npE24NLZ+1JTNxNCcSW0y8bdcXycgL8pPSlP99oVUW1q+EV4MygFbpdCPzFt0WzVGF1hxH" ..
	"t/J8CZ9EwVnYd3nOeWM/1oo6Nq+4mc/sxk0wf342iyfD6GjKWx+2sAfKhMzfXNrBwl+yyKruImD+xVKCti52msyIzMUmxgBWTbtS" ..
	"F8toeXfYQ2XowH/7xMIvv880HjGqS2/M+VNSyXU7o6ftG7iyJGw4kbWmOZQ/MJPTqWZiZdbiL4IgKqlvwdH9q5rTMsF86BVFdK27" ..
	"JLn8nv4hdQCcId/yqGzWXsFVvPzleGcuEvJfHc9vT9JeHnEm1eeJizssPdGJ3gKmjUPUjUKHGDC6ECTNDSYqRs4aN04/QE5Q9kVV" ..
	"GKlLshOBy1EIsc6onh+ySyaiFsXOplqBCX2m557MhpOi63LaQdK7MbD5wOT6jYM9pFEEdyVrxVcA2MpdoNB2ZW88O3RqNnFis1K1" ..
	"0eOdkN6u3Cv24yG1yhqQ5mQhvgq3szs60TsQMas9Pl0CiMToWtljqoiuLIhB+0UDMc87BfGIG1FT4vTqEtiD0ltbcMaBsNdqFprz" ..
	"GH8+HI0L84GIC/u1rH3Ug1L9TbDd4FGqmWiMK9yWTeKpIHwrsnDcM4DDHNFb+acd3f/VXiRI09I0wbjjI4Uj6URdMhUm7tuD6Buu" ..
	"cONpKyQ0AIMYOe/Lt6nk5wvPYWX4Nna/LMxy/2leHTTTLo7DNKMxpRlC/LTUAnBCIh/wd9cIQF4rEX6sIX/JmLA2tWoK1aJWy+he" ..
	"wQ3YJd1P3Kh+L8vsJtOCL3ghlvZ7vG57MCCRpqLfeDJzzQ0LHgxSPJHMzREEt0q28p/ifVvrUmQA1dmsTc785tR0GjalQ5Qeb4eS" ..
	"gV32tRKGM5apBfHsOxAMRavadxgbt2aeJ/t40QpSO4KyUZgSCkE7so1Y1K51X36oJf+qconf6vXB2nSh1ikGmXK9a7qJXuTGz1hx" ..
	"UrTwYHZDM02xrqYdZHA6OPBAm7CJKowqT28dkBaDg4pX8B8eVcVh0zaztABwESj1N2WAW4HIRlzIjibs0qw1MZH/cM7rbQwKc45t" ..
	"jGx8ZT1Ju/NHFKJmaQhFOTCe7vRbuL3jhK6dzGmfq6g7Ns5qPH2jscnTZmW2ICG//meWCZeTgDcJG/n+mS5z/ATRCnqx+b3czwMt" ..
	"dL67JQVf/JDrdwXSDInTMNdWPOK6GMES99qw/RrGaHZtOqDBiBxXaMZjPqTwlsLgeDNA73FDegRKgQR94iLXLecgbTd+K4LkQuE8" ..
	"nsjLy59aTseEzAEwjfNSg/TNaYTFY6tnea+hWCK6qCRxq6hmjaTSE1j4kzzNBQtxHgsT+J6XmCA/LbXGo/gPqMZp8rCh03ub1uYN" ..
	"f9CJnDEkv1HviPkJeyzBE2xz5Dd63wl/LLCAXwTuNZP2eecXX90Jn8ROTNGjMj05F+L2Qv2OjZfYw9f/YEoTF3i8CslvsoCIyl/n" ..
	"AIntmVAz9lPPwxBU9y3BGXOv68oiXlrW4ZlCjxm1YGtG/PngvNxIhaRWtae3L21RTWErBBJHBvUPmniTbkC1OFnJXbl0LWO7S4U7" ..
	"hF+cp6dlFHHExLDN5GnzeztbGYpTX4I7RlTNrOsoQd9StoEMAs6LYmRPgjrhsoEX0pJJXwDQ13KSWTnnMoJvOCPfpN/FZdM+xY7h" ..
	"Kevn0JLSfsPyIThE0bFj2fnbFbfvJRgpQg2NQgMyp1gQYP0gZt704l176KXpBGwf/O18o5pJPWq778sxEEtfUUCwfmIi/QGEn6Ms" ..
	"jxpH10a6KR2ww6R/GSzWGf7K/9AP5nt/Y3lGPy8Qsvacw/+LKobfHfupsysmWRJ0q7EbSlfu+nnBVEBi9E6VpLribSdlg4jSH09G" ..
	"+6Q9LqEDrRnfyHwNusFWOaGA0HStDq6I3Ksy+EnzDGNJyy1Zg97HQ7g/z2G1X0RIJIL6a5DNrNCGUT3htO58tbBIBAqmr8jjgmJh" ..
	"MYDvBeEtqQE9FyXNktX8toH4pU2bd41gl0EqX2jex0pQJi8gl5XyeBfMM7F8j5XC+jTb999RpP4tvZtXDJzK0d0MS4KO10Szatca" ..
	"IwIsygEY3GzTlv1wrJwt5YfAer1RijrI4NHLdW5g7sQW0FXbvsV3Tq17rPxOgyqXP67RXgoLIeYLYWnPX4sqQu8GElHY/uAW0L2M" ..
	"QXPR3S5EEBpirwirFmgjzC1Cui7CwOm1lXSu2K2Q2LTVi1IE2hO4OGB+Qwae9so7i2rWCiTRHIxUPO3GPh1rpeFTjFrbjAaXDhSq" ..
	"pqqijFf9gGIYaI52BqMNc6xkqR4caliFStIHfEY2zpS/PqXChbbimnP5nz064ofEKQSzZx2VUks+pRsZR9wg3tKiP0kjwHIAlF42" ..
	"KxU02+kYoF8RmX+aRcFjMdBlXjhS5XVeY1+nXMK5rir6Kt7Rxgrog7uCXUXki+35mwLqOWcrxmNVRrHPIWtH8mLHbJIItZBT1c34" ..
	"IRfDf700404iagNi3KlyNArpQKDjVpfCrnD4UIABENxJoGcFWGcKz9QsSp5WLcIJtn2F0i4laq1qlQG6SCJpe4nOwElqks4Ai8h4" ..
	"wD+M94G2/H2zhWRLyrlI+vkdCbQoIZM4kS8O5swOmp3QOZ2jo1m1UV0y7wPkvuCq1Rt98JM+vDVMNFszv3bdEGwD+BPhUV8HwOKx" ..
	"42I3SjXWH5v6T4eyIC03oVWqlcVcHyfeTWJoF+rLfVz/zM6MBj1fA5qjMN11+doj5/ESyY6CL0Vw3ZKW/RdohaDuPLFbEeiYzl5G" ..
	""
local PAYLOAD_P4 =
	"XxrY40y5UgjRSUZnikUfWI4fJQkrenBZXMaOkQpJPodzoLpWquFYQxIhHcyTJsmRlfs5v7gRY+LNGdTU3z92wNqugMVedPj7GFFT" ..
	"qSfrm2eQTYhZMC11bXYSIe1/PHDEC07RPhx6Dx4WUpZtt2bLl4odL5vtL3YdaqvUW4RNa+96ymsQ28iKZSu7BIILa5uLRKx0yfOa" ..
	"LEwOZdmidc8gO2KRmWH1PjKQt4SCg8hbsWutDXpRysQOQhD+Vwet9VlHdCUBWVwHZaO2rOHlnrJGV2UWmESd6lsWFu66YmNWa0BG" ..
	"+wOAyG3f4+DjUAGWPrg+VT5yL4SeTA3VwSDJ61bH4O4PlD4OQpE376RFcxYENqVwEj3PqFNUQBsoWZqPKp4kQKVAN5lTJzul1z3+" ..
	"rrfwd7/3lbiW1O4oZ80EAF4kN1uh/WbIgz9viqwJ4cWlyeDTMSxvHjw4eroyBwz6mKeilsIO2t9I7x5QThl+OnrFTyjZahPqF9Es" ..
	"04bY8YXfL9Zq7m1KNLHAVNeSbg2PxbiLFF8MGAKvtl1Xo1/R7QqE99fvuePLQf9qOjE9OvrnjlfSz16EAGxWlyL39EBq3DgPCVGv" ..
	"xhUCaIvh3ioXm87NniLNE4reeKDaB9JgvZ08Sjdpnd3I6mM4Gn2QYHvT/pfqHL1m5Y24GqdvlBFwacvJpwozho1H4hoo+7tfvWVz" ..
	"a8k9Z25mdEvWWuicug1ET3atdHxiLP1JPVF2SYABRhaIxQe0WiP4H0nAHCStMGXc6R4q8aXH7BV53aKA0MtYsb7uhTZErxHgMyaf" ..
	"hX0Rjxq2qpjJD3zIiROcXasaH6rH/eyyShCVz/83Ga1xJ2JdWUn+qPY1zJDNi+HF9hGftt9prUl6NOKv5uPNMzVuGSqZFFjgpd36" ..
	"HS1KIylMF1yVDoT2WXm0rAwqwnEC3cxN3Hs16NL1imIink4Y5y0F7z+IXCkIlg67ZPEZH4VcjAJGSL0QIpgjqwy97HDB3pEBPVRl" ..
	"hWj3kd5TwRX7RwCBc2jki+f0VapMnTyuBJOfm0LTiMu0NyUwwkLWhSck+BrekpZ1+Ofzt2n8N2hHi66uqvCN5tIQFHuAdn99/Ubd" ..
	"Df/ItNGV0g7m5C+l71if+UfVIEQYKiy2tsiYGmk6euyNQbZTCLOYhRyT9UJ5rqJiLwyfxUdui3o6vfQvuZc+B2PR6OpdP65Md6+V" ..
	"CR0GJz3EPlUyc3ojcRiWoG97YsK3uQK4eBYE8LUDn5gBe8YUF62ArCZwjEKDioaM+it4XZraTUxuozSdAJgHB94gfoEPVfxGdPzD" ..
	"f7Oq44S8/jkZgxJPCYeD6EZ0WtLvmkOxHFeapd5qlUHC0/XvuyGa9/D7fJRCbhVL+46BARuOIisQI1Hh8iVvIHiDaKy3j/aBTCmF" ..
	"6WLumyqkljIvNNR4PneSHrVmbtieYJY33VewrlpgB0qt5dR4lvcwWcLA+IQJrM3PuRy9xslf3CJHxsNAD8I+QOZF4QGeUx2XKc2P" ..
	"cRqnwMPWDgTNI1uPPgpIePtGKENC0y1YNv+idr/DqgaELfMp9VWelKIkjNmfN3kZqrsW00G1OKNHqu8QbnvDC6GpHxcg6iGUlZTm" ..
	"cw8ntz+F/jlr8mrZN6jnveDstjBumQaupVeUmHi5JoeAfOTX8VS7J1gLlU+Ulvs0uczildV8u2+UFh67InLEVsVwN6qszuuHczFC" ..
	"RME6YalOVq/ixRptFbwIHC4V86d7IKckfpc31WkGGsSIzqWV6Zkql3lyt4UPAS598PCnoShl3tEGPT82Up0zzAvX3CirhLGDW/TB" ..
	"B2+K+i+skALGcPSwHTQmvsGAvh3PbpF2BVS9clzCkrqbQ4/JxOkp3p7BoWQTt3CQZSBV75a0WwWBFMiBiO0CajZm2O4F9lXa2tw5" ..
	"PV6+siiUa+QX8yG8GyPVLqQUvHzzEMvLuUeF/yYTIt4K9geqYnrleNcoP0TJNVfv64kj4adk8whYltay/3WcbdAQXZ3ek9ggjqwM" ..
	"9o9oFPW+8X/z9IPNn+4bDAsqhqwcRjbF6wDuwVeeRvToBwyGm0lAVZ3HGYyupIPNzkBCl4qCiIv8a2h18+UmiroJGHyk3WYRN25O" ..
	"TMoTwBbEght1yzDy5SKOkiiX8mRTcaKotRyjhJIsY0QEKWgbXuaivbZzoSxjvNhtfbF8/qfQTP/X1EVKepc6t0rBAoPtsyGdDt8z" ..
	"5j4+iSgBKXpiUuxAyIiwZkCPQgvpz4SOzNQtKJ0GRHqyRbd8iFZRYgbQZafsrj7ZNMzxWLXS/qel6RvyKpwcRvv7qJdNQFoeHLtT" ..
	"HZtMnVD5n37Q3mQslQFusBZMbwqRIT04ZGH+KWB3i6YNw3hUfe3n5VYXa0j84J/gNU9acfOBkPhijaS0d0C73PJXRb2j//rZG6QC" ..
	"Ktxrb3uSfITnzyZ2Foh7gNcPuqtzRP75ECmnZ9KC51hm1rAjmfHNQBdPzXDKtsAzmmD747RPvR5T4WPX+hKY6Lii93TuWM4o9A8B" ..
	"Ve0Y6KY1nTU4N9fmdlQG2h+02YQ9UiTeeeLcnXDe8teY0AkCX5hRlk3y8SE2d96q4TZCxs2lliybydigrEuYZcmcseQ9O5O+B7d7" ..
	"ahZG0nOXqafSusV+hCtckbqvKWQhgPW5tkypIS0cRXj/SWUl6dLDT/3rs9dFPEnaCLm1Qe4zpkH7ymt5vL1GyonsgR5Gb+g5HXVZ" ..
	"Hd5Vsni2tZHTaZXZKjGXvgiB0YgQsycxr6/35g+ZhlqY3OO6I+aoK/L8u61YB2aAF7A0o11skzXq4dWPWhd8TSiAOs671S7J7R0E" ..
	"W/tf6VB40fuIFQt6LHYs6PFx7xsjtnwXP93kBGaxSuahLBzTDAZuogRmp+sgcgkoehi++ueG9vu+2BkvopDffr7fVPoviOsagSuO" ..
	"tHN0mJNKr4SfFloRB0y5M23/GcdTzphp3VTJ/jOIS4BbasaCq+aqdKN503qd2sNnRkoiWMjwPxP6/UBGxYWoe1eLYrpsrFGLuREi" ..
	"uYwEbSTHXYoKScjdzUnJWblyC8xrYVlEaY2pvjWCMVmO8vXQmipz0be9JIdyujNvTJ1e/ZNh87j1OoCPaReezOnhKY9F2Pl1WwiZ" ..
	"u1lHTI0gXoQY8M/baEno/lYjo+0lE70j5bxdCVRElhMGc+UT9g+QGOiezK5RC1mB5r0aOmhuBtJ89SLGJqW54H6GIN5ftZ/SEBuQ" ..
	"IbY1iNrCZAaCyURZMV8eJqT5snxevOqQiyEugih2Qgol1DN4FRZS3JjSi4FZ+kHwqgXqkJIvXtuM4K2DkQgeDPl+NdKC1qBJGU6V" ..
	"I2rDpZDN2j5h4I4A12g5PMs8ApI8l5Dd16UDAHAnUF8nryCAGlRD3sPioMTK46At1gMmtxowJk8uE9SFq63Q2NWMMKq3J79wQV9l" ..
	"2mxf6FUedSzta/Anai+mlhzMrtSzyqu1DxfANCnUFQot7LDWGFT1l9nNzAnVdZJwaCH4SdHthqhbNWTw/XLEOUiySDKebjWxKl92" ..
	"y0Wc6wVGGcpmb/qQerNvn7xvmdvVt8T3XXnLa4SXdeACsn8nwEuIwapnNVk1FhHogMTe7F+fWGHh1YIWOFC7eWD8uTBIWQlgXteH" ..
	"a458e1Lchct+3iBj3AstiKZ9W6kpSvbicbyzz4VzEkNgagtfKxaBwRYljYawcT6dyauc8tpHoLf9oU+6LZzDnWpIgvWHkC4jI/jX" ..
	"pFgcc8CeplL6aC3PScHTOlypIhXHZuRq0Tce6psQEuzID44HdUAyzHKYR2vP9QO2lV0/g2qs6PzR4t0k6+Y6NL1VY2T4P/DFtBev" ..
	"u47QUhx/wvIdm7Ez2LP0G11pcxAfpBvZM43E7YedOTfXNo4xwFCd198m3Op340uHjG7+6AHDf6q++UZP5HPA81qpvHv9oX2wFx8g" ..
	"udPdioNHlUU17HESc/djy2Z7w5oOdgQvR91s6GNx2sZYCBav9Ft3/VPt+J1h8C4PuJXPdZy1YYEOeSE83IfCXrApJsk9luTtWXDZ" ..
	"l816B/00AwtwSCHnCRYzqfDNWyW1uXwUyFEn0pgHKg2hxpsNiba4y9lWO8FF+9OilUpXEE5UGvIgPVPOF8G13lR0vZrHJlx648bj" ..
	"BiuTYV1Tpoecy7aZsQKQdu0YcWaCEkR5ZY/or+xWUd4gFMzsc9BuWQhAbV5xYXdxFIaUb+Na4MApqULjKuAll8XGghMS+zb6CwRq" ..
	"bVMJlFM/DUL1i0FSLkiqF5v4VFOQaGzV0zyzq2waHrZzEY01C87uNHG6R07n9r1nMJgVj2z/k9Wg49rUyS84QUGCbb33LEg3NEDd" ..
	"cLsNnead+Zb3ZIYDkB5iK/z0O437LuO8aGixKFKyP3zhMsh9ZZVlOL2dflvReeK0CkxOaF4pHw8746rg1ps1H/cERJUjJI4zu2ue" ..
	"9XhZfe23PYRBUDBW+aXNqf/bYMzFBjVG6NExEJgxOwLefVUNQykmJIxLHq2BWBjSaR3NcupvFiXuXQqeSZy/lYJZ9KrEmRFIU96N" ..
	"iAMor7s0XzpEFVlYREkgYiKmxX2YNCmB6IzyzV5UpSJ42SjIvP957mrA3nD3PQ1iZNnZ/0GU79X9EeGsMSl2Pzl5rnXSkjt6pFM4" ..
	"rsWWK3HLya+42WtQl6b4SHosWzvdzPxRPhdBTHgUqqwI0FhlbH7pl/oVd96A8GveExNtGUv4gl9owLJtH8lTzGNlhxYgseOgQzVN" ..
	"SyvraIYh8/aNd+RPtIrx6EvyA86vMVHGcA7frfRi6m6hBbSmaVT6MdWNVz3Z8iig9oDdYC9R+zj6E04iXaj23gENyfsaClw8Nxat" ..
	"OavaSF8VbsnjoJrJuf60/LCrbIPpC1wzb82mY2Vp5nBUsdxUR1HW8IANxHAI2B4U6XWJ/mmwyr52O9cfcZdPhTpU/WKaXSk74029" ..
	"0tbXU2vh1FAGfA8TSCyTuOho9+jrlTX4cXSoSbMsc7tx4XcbdBlrOVz7PAHXFVum495nptAfiNKYUyGRIUvljt5sR9p6ww08IU9m" ..
	"hfQVqaYsWpEt1K1utxFLT2E8L0OVQVl2fdGbpaF6ttSzSJpXiffnmliXR/ISGrN3Y/oU6fNqrNCVOuIgcGnzdJ8e+AzTqr0noMLc" ..
	"G8nJkKLLDcwUl10jQcwrTCqqYrripoJp/cV8pRLPBXriH0b20w3Fjop3tZQR2EYHGf/9aikFTix+a7lAEQHrIx/rr786UlmAyeBs" ..
	"RB9nw0VFJQ1qTISlcQd3+slwUX1R5wJ2HlK5xq+A8plmBp4XflsTv3hY20Uy5meSAJlqnzuyB111n4FqTpxvJBXLODHm7HSYSdQe" ..
	"OmLWC+IlACdOuFsr/DqgaYrcPQb56w5CpEBDzN4yhR3v34J/1IXSrR/usatSQmWwand/+3YQ8g1jIWgfafu9Ydd3UnF9NUZDdUJR" ..
	"fjyTcAlmjNyZqviYiUutO9HanUfFDoclpRTJTqK1S3zLMApnx3NDZHfJls974xbv3om+zS3CWfY3za+qPeqYZlZj6u06DFRx4cNz" ..
	"jEuqxNpAxtXeeypFvG7IUwLeHGIzmVeJ73t6eHoHUvYMxuYlE44KXgXToOPh8rVy2jN7btWZiuhZXP2I+Dn6uBAGp+rFamhhc9LJ" ..
	"dbDa9D8mgTYhcO+gE2Ik3DaA5I7K/OfmpaUxocUKCpObtCHmStrRLBslLbk+6YYdRyI5OYcvzWL8DU2b9c9C91ywahybSxmhzw76" ..
	"9LcOBcCaPrLFbVmYkUcT2M6qtRAlgztxYh/3vTOPl0X4H65asJ2f+4clUgA8J8qqwvyXP9fTWKi/f9PjecKAhURrvDOhEFYBiR9D" ..
	"LvFhHtOVAT2luYGrI6dMYODVKyXkSUrh3pNzLEssMWvQewTqTzVBAAmFWLypa2Oqz3z5xJkUbOFOvVMu7mGeFWXiiw9agaH9jx2+" ..
	"v12c9QwDPf/JC/pLAv5KB1iJGsZ0hizKjmTfn/jmTMJKVGnQADfN+K1g9/zluZ99T1qD7CLxXNOuKIzV8sv8WOGzuCjlRN27pD6j" ..
	""
local PAYLOAD_P5 =
	"R9dCnBYtCltZQnmzmakwl0MENzMvl3xOZtKz6nqv0hFZ5nfFh+1H/ijwW672J+OQLhIJiDfopdwg0vPqJzws99V4mlEaLOx1JOQ1" ..
	"5zdnoUIWI/UsJ1gj456+rvbkaM7VuJGRWg1xR9gAeUuR9JCP6a/eRISg2mxTk237wVkuP+68l4CUPlaCugJVyle1m5z41bGwligD" ..
	"yXauxpY/whFdge8dwWTSGRBIWpbBW4io5ZIAXx2H9MZmA5CljN8D3enf3ZQq071EOTHrrhny87rLtCGsF7k2q4IN/ZpuNML6hBcq" ..
	"YxCNnswon+GV8eTFN667Y4ZDJq6ftdl/gLJktPKUD/54A07sA+Izbm87bZeJHGgS6k5dbiSg8ILuzkm4zxWQRj+gvoAZ+YHLfs7m" ..
	"lwEFTh+I1VfmCyALiGuJMJ4Y4IiDIsbnM1isXoZx3bnMAaNotYGdDlamv1MXvtxJvgnDAiOolA6z/cVAh0yLHlKIPqheEvYL2zVX" ..
	"LsPAX/FfssawXMehwgQSMHVdbrSlSzhdnFPFjt1PO+iO27bLM8gx2HtdJSUEzcD4iSGlcxTZZzxroXwIpfCpMvJmxbtv2PRFSLaX" ..
	"gdKmJtkdqvHsEELKL7gMgqweKev/+Lik3wFWZo4S6HogHbDztwdHkUC40zAGUI6nHWYLk/amSMv2IDbLodCY1X4FiRk22h6b+htX" ..
	"0fp0xhY4HlgyQ8YFWtPsQvaJe9gJHmI48fD7zUjcWvRwJ83xjrBJVBxQGoQ1l/uoyJfXp5HrPZ+XOyVjA3yI/v9CTsfW4+0X6Pmr" ..
	"aZXgDZJcYMyNOQsSH5G+tUxGgOcvX1wPqqHfAyU2uQ1iwPFjLJwyvjjFEOFnveuavom+PPqYa+rsZxNBcy+K6sn5zLm/L/Kt6j5E" ..
	"c1RRY5v8FSocdOpDU8pZMTHoOrSSVKM1rbLYULoqYOyOPDJsnvBLfJarTuXnDjCwzT0Yd9TqR2U4qoe9qm4f379w3y6m7KIOppS/" ..
	"p3LCxOUb+6+25/9d8o4bF4GOGhmNRHNDnW3xm5hIsQ/sQus3Dc82tNNQVCv0JRVFXYiLxWAtUmQDdnpqb5ROgB6FAdcqWo+m81id" ..
	"0b7RVb/we6nlltiRIZK9cU62GI2QZwOGpHsegiscpQkqhtywFrUlW6v6x2aOczev39+xxC0xNkY9JdXLc2/fJs571MaB7yHVRXD9" ..
	"EmnDxDsE9eDYkCII/xSu/6pTE4WBBpfHrarVw6IcxiViB4j0mgeRGhREx+plEAFtwH/LC/NXj13ce6gah+ZJzNbIw8ra4T2AQP0h" ..
	"8n8OAPgSzFwlV1ksxpRwNVrDXqP2QPxe5eERwCfr8LAQ5jT1b0hs6Q/0Gvi2CMWgNHI11JXn2kDCICAEzn6RPwfR5/JDOvGs1rIg" ..
	"dEdPAPq86t2suPD4mDatOQ+YX9pSUrwtgv/GCAd3QbD+KTGG99VHr3Tax71lKZf4zVnPDMqYMw9Q6tEQWwaGR9DPfuvTWcTA7t0n" ..
	"UQqdpJpE0tMNx0lXfHLlAgtyStUxQNf44V+bLe0jayAb3lHk2CtYqdTzpCEmNLNCJEXNQqdYgyGkBYrgjraTSiZSxhigiE1P+z9n" ..
	"zsuFjtiALLPVWDFS0NNpwPlw6DU9meEEXgmNKeBY+mcVQi81iJFns9iik2wJ2U+Ca7lDlxklh13WLMi4XT/Z+xi6D18Kii80nFwh" ..
	"MPSBEm6WezQ23qJ7w8ZeA7b3UgAnOz/b+2V1AQw0S2N9ic4qvOro9S3bw7EDwnocXPQ5VAUGmzP3LJfFSCXUCYD00USUja0IuFlT" ..
	"UhsQePWD5e3+2FDWMwFBARzzSXV/ApNNcg3zhGolYFCFFeecARqgQ6iKnK2wSdMBUD0WCA3wE4asH6w0+fCyTP3h+ii7CyU0iX94" ..
	"2xkC69E9LHHBYvGZEI59R80FW4Y/svFoatq+C/Olyn3ImyDktf2S83gmi8B+tfelD1OYJgTcjGL2Crl5u5BcRwSL+c6BduHHzTlH" ..
	"WYu1Dnaa6Ifvrl+SahzX+Lad6Ve8+PrnMU+KFVIIuKhrYerBO8x/5HcSyGftPE6nvtFogB3r9iVj4CYKP6Kqm1Kqf66JZQuoH5/q" ..
	"mj2wKeBobBu+LaK4TrFA2XdBaB6JfLUCn6qLYW5uUh7iAoipAUivjle9yOsTUHSRGOWc81uTuNZpMtPuoTWAR6XWxHuzLeUlNQK+" ..
	"feBXdwgTKbtYNz3PyT+xmGQEI/h8DyvZarSEnfJZ58YWq5aNGznP3o1+zP+h4KK9eLzGhwIOyLmof2ESnHqi5Nhgm3Z6mIGnrGko" ..
	"taBrSjXa3c4EGhfNqBoya8ltYygXKQsjtkOlzKWpzjLLuG5PROv6rnvHpNXGjAijnHtkm9gF63+txLrzJ+soAjQxEOGZrLZwoHzj" ..
	"TKvaVi1vqAvNQbJvPXBeNjtEHks3DKVWlk4389PQRU0xjsoRrkV34FcB3sM22Y3yDVwK3wHwDtCiaRAJmjnduAhzlLvt9dYYCkFb" ..
	"WmNM8nKV3fNnQnbMF+4OX1WICyJSwtP2YnqqXaKNzSrVpfnYzW6drGNOIyh+hNWMlZqiFeP90A1tFZj08KNiHI+lrXfZjrqlAljN" ..
	"hlgx+Yott1nkc5h7WsCCkjU4V9pbv2aon1SUPfZPWMA+FgcC0/8DvablutLPejMlgPdzZ7INuOhhar7SXyyyV63TnwU/IPaKXvE+" ..
	"WlhSq3n8K/UdG9bxAJqWdteMJBjvXjEPoLZ+vCXftC/pRQloUGQnFKxU2Pjg76ZzxlZ7tb9+hknA59LCtQCgZq9OnfV00Aeiu8xn" ..
	"HBAerOWfZ/D07lrnOziENhht1TbWg0tP4dBkLTnh/yQk+2RcfRwxsWdi239+6lB0F0uePLWAnnsuuvFaxIapAbAv4CnJLkK/jfCB" ..
	"50qeSFOdzw50KFSKHBFdmB0uvWhVJS9uZxhDRMqc4EygtWh886CKA/zkaZMe1IgP2ffmkFWDBvMQYAJF1Knhb1rYj5IgxZo0Yxff" ..
	"veYl/QBUC/Yj6dgbq07DfXs6g74Wp8zOOLwWHSkFThRqjkrpxdkKOxXxudFkrwoeX0/ezNrFOYakMVuqWLw1gNMv4uZxXLBr4XYz" ..
	"hix+03z1Fzo5W43YW8qnnZINWeMHVJcLER5hPZV0e505rmp+Iq3mA49Du6RLXAZ/tYb4HtCej/tHA3ObAbeU9JuMX0LQrM0yBqhw" ..
	"/Qo1D1ru3/xl4VwzqpxahsJTbvNgHWCscwdmIVpwjlq2HNLTiJVqjfVLhl3ByB9oSX/DQ+o093zRQd4wCtcC4uO9X2Vr9xyzF2c6" ..
	"7vuT3htAZQXbvaixkHVTdl4zAFdu/iYk//vVFm6T/r+HxGeIPVm8aA6iVtk4ENCo+6bPrbXm9OIPe6PEx8BkuQ81VDbhts8YTmMf" ..
	"4WjsCQiU45rjrgM7lJ7Frgx6TmcqhUIN/P4lYehGIRBVuKpqBQYkZ3EpgEycIX7m06c4cfl1TC8mpYOyLuLA78DMX+DiGNa+c3pg" ..
	"DpyFIeoiTPQFOI3PvXHutjkdzk72K5VM1RgQvD7JkAzcsTWBFbDWfU+awJjbYCZLbgM7bVrivNLfSkKxXLc3DV+j10M4XUZoC8d8" ..
	"Er9MWZCpf61BhJkvUTh1w1yUg1Wb2yFAh19q9m+WU3N+u80kmbKKEq4jIpu2+wugUJvtQSLlNEtTqO1vfYozm/kJrV+kfWh33Uu8" ..
	"rqQ6RycAMp5PbiTfI6m4yLOXLqHlQIQiWBLoritDNed77xe9vTk2Rcr0T/YjCNRpZOVefb/oFJf7E0DI3lduiMypRc0ToKYqL7Uw" ..
	"F6HLRNFN7K4Y0KJpTwrQf3myNtoiH5WlwmOxMAXbzo+cgqGPIi0OZXUnIDhfhjz3Wqg6sRVuRowOkJGWZkbkOETVaN81Ftwe56he" ..
	"SWn+2BRRoVKqh2FTdZ0Rb9irUTU9U9IsosMXNQujcDeUIcrqQIr+odKTXEo4bXyCTEJdKyfz0xwVcLp2qVYhf7NaFChI/XKJJlSS" ..
	"lOmEMqY0qvqE35Ej3pWLZnS48KhB4vFWjhur4RjHmO1f6zXXJ+FkyevzlOePw4wVLtazzZN5ea+dMHq6ANid+xB7VCBh8uMfNqmO" ..
	"HQP6ufX7tKv7pZEeRhBBSeiZkJnVhoLk4v9n8NaujSjrDaXZkO+DKTQi1oJD/dsFY2Ne7gzbCLxDPrW//atjaP+A9u93Fb2dAqjI" ..
	"0VyGKFX/G0Vr6b3slt6lEhgl07yk+fOA9/1jZYB16B9r5JYnnd9/HwuSrOZuffZ6fo1J+wcPwO+csEUKJbxGz82CZFJkJpMmK3kP" ..
	"3g8KW8AD/irPDHW6l/PQ7yG82mg33C/FgcS0ltyXB+4nNbBE7OnIYSqzhTjoijJvnB+OsqhMBJ8xM0beEu8X7u/7zaA+H5yP9uhV" ..
	"a73ZMq65A4MRPgl6kTw1tfpfkU3AuM5K44pSd/KB0kFUUtluZZs1x2wmVNy1S1BsLUZ6hqzzlHv89Xa1PpxttcH6PPThmwAVb+V6" ..
	"JvFQFaW4kI7dzu66/iPu8etagr3PWCPFi45g0DLJcM3EOVMn9pVv4mywptRm2lZgJjgPZfbr/sRKLprDNxcVzX6qUgtwimTz58Ad" ..
	"c52cJO9dC8x7NzZAqE2vkEPUPPLEMTjdpYJzfOcUPevw3MjmCLRwPm0ouOtj8IhWjcS0SErV9Ok5c/fhp4ySMcY9HGFTwjCp0AeZ" ..
	"dd45upM7C9Z7f2wSRSdT6eJWNVr8UrRRG9K6GeYE8EPTL7xlqq8ezk6Nkok+sRxOtrOTz3+04rTttImahqZWXFdUqKNhORRZzFTQ" ..
	"Icn9emVPbWkWeeLCbUWa8Rd81T10OZTjlAdSbKLqPL75Xo6zqISWn8dP/5ZH1GrZVntGkqw25G0Or1UR6vaAZ7dUQaBXS1yuu18x" ..
	"6aQdxZoaNbbkxCj4ukAawLt+rAv+IFJGDXW1fl2FNAuVIDPOC9wO9oboBbr5mlZQ8R3u4kJe39nStHArOEQnEHLJOuOSsgRmOSMU" ..
	"d5MfkkfObxinAC7y3ajhqMGVNzkEA0dwvht3OL/TtAWF0FBCIlOuS6/mrHm+xfQjmZRmZBLYHbcO2BPxNS3g5HYdrICl5kn5Uy1a" ..
	"UPWnlflVpsqIMR4Wjyech2Qpcomv0l1m6HVq7A+Y1AR7Lv+KGjWHCnH34KH7Xu3D8rEy/0OQyTy862qGv/ouaow/hW+s8sDQwkB4" ..
	"ZqBlG66UppUV6hMKwyaMpyb5skZju2A4U4AFJ4TBp4I/Me0eK8jNxTjc3l41Cr+OfXVVQFgLMNzDB9DnFhPN9NtiJBGyil59Dx1x" ..
	"9K/+pUyN/f/LDS7jc9Sa/jv72RjIPkF7R2jhbCVi0oqrYRaiPo+ATTDNFA9tCZ25niom3pF5ChmVIKY/j84NUsKVJi+LzhfHv76m" ..
	"LSRkdjKzoN6pziwu2MOOkGC5dG32zvarGWdeOiQHI5mGjI1jAJ0kc/6h5E6gR5XZnCmWNvkcFuFpFz2gA8EJ82dc/q/rBbQVr3Ln" ..
	"hZqThezebJcbVHqt9tlm0UH82kooCY1NL6MFaE377vJ2z2eHyHW+MmB1BktbtBML6dv3dNdD2QNPpz9qplA6HVapBJy+/pWzMjW+" ..
	"cT5kH+Pm743/8JH9aK7YXLoVNpI0u7ArOLeyoctG1yCWL4tEMFBmacLQx8pnxitmoNR7xDNoYYStUBOBnYvl+w+pmCniTKnzYOSl" ..
	"NvgJZCKnzNit2t14GCOinaBjxs/j67Lp1ZaRhHC/StOqDqza4bKlAp3FV/+FstFqXdy+v4bVFmn0U+MiMHoW/6wXkxtM1yBsCA/7" ..
	"TlvOpCnrSxuJDjmH/IbHdyoTGZw7yyaVw7HSy8JF7BCQIkiAPD7735gyIyc7PKHxxuh4Xd7o+SNgKB8urUviv+NKTPVyrhebisMX" ..
	"AUrzT4lii0kPGj3iI095UYilm+ijKZKyNlwtAppVbrK+wVq+largmHW1BwViLZRv0EAxlXqyvMYC5l3wJAgYsg4v89MCOsY16L+Z" ..
	""
local PAYLOAD_P6 =
	"f6DvoPVQlZTZhqbUTLRfnYZ+q0Q2vPPy6slyAlStp+j2Ypi12Ns/wrDy0mAIWAyZ6pfCLM4fNO+XCb20R3eCz1tyHsOWvBKI8zsu" ..
	"2IjOKM4H+lmrYBn8Q/bSV97oQGRJ0EnqpG4EjY5yuIxgO/u/Jm5y1ENip05O0UrcjYLg6t1eYHs2QhZkHYRhEGVwRP2j9NpRkmhm" ..
	"3gBmw4S2QPnxZUgprUi5xm6sBccFghPoifKr8yQvMfZEUbZqeI5MZe/75Br1dWVyXhX8m9DGjy1oGz9T7wryCNsWFQ+EJvqp1hg0" ..
	"eo6p0iWR9JkfRTWSJbr73bK+YlATsAhJgmesL4IOqd/H1v0TqcD+3Gb/lfxLzQ8N7G28wXDRMEeYD4pOo1zhJzrZzx2/rQPDUV8j" ..
	"bYsCmD0rS1K0P0ghBcFTuDQbUpL9IqgJTPCAoO5i/VL1uk2dDe71DDvq9De9mAs7bvY5GDVqwv6P6Mae9bvzUZJ3UqUdRV4RuCOr" ..
	"Iql3adOf4nwZBFpUA3oE9eMePadj2cpUqhV22Gz9+4hLDyFt1bwERnw+1OYFwTyy9IC12NgAY+bh8ytMgv/DeTasKH4GIrgQr4wn" ..
	"CY87AEYpS3vNSQ9uy2BjpGCoVKMIfYpffT4yFZ6r4MKxLJul7W8vESNIbFs1X4upHwKnzhGlYQk1zKn38/Z8JWQXaom3N8bcQqs4" ..
	"Y9LUQb+EPnBjE4QyfJ1lUtQbfDQoVFgUz0DnB0T5fJ5TsBG4SK53XEuy+u53wk5a4AsMddnA8rZXc7HJrwYHrIchQniVD6z4yNLX" ..
	"ZaIX27t1U4rACRgk5ftm+YVE1l+kztPn7nDZwnQkLHAGdxk5j98ND/9hhwXq5QZmL3ib3BrX8fEEfjqmmTKc8vzvvcJjQmbW8OIP" ..
	"A3YUtgUO/RBi7dkSdhS2qUJNyN7zJiaPsTsbGGV7QCK2q9Ub14/Kvgj+6mq+HXlxCH8vxGi6j/+Te7HIjiliEahwrSDTTZv5nHjO" ..
	"75pcUpCGEzXxxceUhANdVT8u2nxQAAnakVX/IRRTpE3Ep7fvhoBIe9RR+ykgMpPEYKq43e+3Y7JaFg+jIpYr/nffiTNHtPhoNcDa" ..
	"F3+79IlbTtqwTL1HAsyRQolNuxGhZ9KoG4X5EfFRPrAF5uKmdvW/b2Ya2f5Y5t5uKB4GO97dCxYu7YFTIKN+EdhKnI9eaynaKe/B" ..
	"2XUxcwfda/qu208IHRS78krFLPMyBigWMZrnzyxzQcCPXButuLMvITJGKLKA6qlK8uLDCP/OWxfqM4VTROxOfR9z9/O8PuX9eUDr" ..
	"yZ5c/XUsSVA6r1Z5uWxsn0BEM5sQlMliVcnihWXLnxGyoqWhdV5SvcUj9L0fgo9kbmnaaHGR4vNeEuubsrkLKV5VI6pnvXmRNjRf" ..
	"E+J3y/PvYurVzGFRQk7knXknSwEiqHLFb6IJuv7iayImROFvxmguSZPY3XQ9t7uW618WMWMtlPPJnb3EORI4knOUeeOnG6TB4/o8" ..
	"/w97T84HU+bRvpfpubSnV+TR9lciZ82jAs/fAKl5j4/D+OlTJmRmjXwAQYXEfRYB/t4TgJ9G0/VuO++TdvM/hz9s8xRABVeCQcUC" ..
	"RBRGNfUCY2OugKWtP0dBxtxqmk8YRGz0wjqEmbtup+ZXuIlWnmmRwJat/OZ/CMQWa1f9yWYFFEFYh6xVi3ncm5u8b0HB0dEz9sFl" ..
	"1hEN4n5laUol5/nwF7zMUz1O9AbPHAi65efUogqYuiKClJhiXmX591ZSClgXQpYzAFFvlTP8HraGJMOTW5/eJhLQ4Zisjw54KOtD" ..
	"ddUj1kgoNXzalT1XcM12oeYQFS7VBXJ2V99nOP21J6Ea+4zRanraBHoQ76zGu+G+fG6BtLXEb+54UT8oxXaFdKm4Vypf/zOR7MpI" ..
	"qgc6Qcms+oUfj48RINTf8hd21SBhlehVfnMyejSKIF2pHkhDI+vYLfYsCB1rquJCIa5PuUPd//djxEgkDhnMCVr/Hx0jTRwnKA7g" ..
	"4Z/KnrwKXM3WFZjfdZ27JSLmu7v/f7NFBWP5SoPlpVqEtynk5OK7l0IFJailk6JYI+1qA0QjXmXVtZiUdOcDGgwDGHBIbHRxVxFr" ..
	"7nQVCwrGKEWvBpK2RU5BdnlH7EpzHekr/szdlfVV/tISWvhmTrlZVAIAUgnNvRIj9LfDBootlcicvL4LUmYP55ETI/pvIP/zZqiz" ..
	"Ea0oyLUwu4C25zJa6U+nrLVdOZhTrkOpFAb10aGxIgUsO8/KVxWCZen44PCdE2LrXWJyu8/6wQv4uIM8hss4NTZB88GPxCaFy4+s" ..
	"4IoI7fy0BEQ5iuTT/wAzHqt5jqy1tM0+64BWatxSC3o0XENbO66gMLh/XHfG4nc6Kh5tGjS2eXdtaOwevTdXm1TbMk0ZADAc6VMr" ..
	"2c5V0RxYZqWSVlErrKHHxN7rboOiyKIHPbiFQdzb9ILKQ6tcsABrfCqPrtrza8Do/DsKhcxrdr2okeH07D9q4+X7lECXTSBSElJs" ..
	"tM5K0YzdnlaOIMmU1nl+S57k61ogz7Q84orSAZqkanYqoLY2kmsyTC8XPGh0OmMOEkEUhvlA0pV3XoY2NodNcENx4YgU+PAORJAp" ..
	"5HvU7PYMX6IkW7ljNlAgkw9yvswKSpO4Xa4ATryKXgsab0s6gny/Yvr18uEx1Pmsgu3vMBH4gLKgAzL+Jk1+D4g00vYiz1QTalsj" ..
	"qDq6zkKUMH8XweGzHY03uxc4JFahLmsbhQu9U2CYLOo1uZ9dpsZnjFSpFe9GUO41tfHjr8jECnrD+yjWFmEKeaq++jRs1oM7KADb" ..
	"+b+AjIDc96dtTiGLc5yTPXLfGndPeyjo7gsmx2WuA9QnMCBGRJZaHIzCv5SluWyo8DWWdE3xWcnSR54XlY6aHRt2jVb/OdMnjY87" ..
	"EYOSQq9bnCL6+Yi14U601vicYRsiRztrSVyrJVbdNdKYWFBu8kGh/MhacIEHt0QGuXo0V4gt9rVk5IuTkQ8jm817deaTG0on8ULI" ..
	"ljVDPbobWDUJX+zrhH+KLg0UkHx2iQ2OZmIBMMqV9qhK0t88gOHGeU+Y5OCrvrA9AiWdQ/9M6kdO+sn4mX+LMsHSZ/lDi14vZxqB" ..
	"9sKtGCppMWYyQgPQkB72V+yx2dMhwtf8QIxd3yRIy9alf1YrZPRrjD+WyGTqLPp4m9uyNacdYgVN09ojuJC+uTPnLTenkGnwIHBW" ..
	"egONi4NQBiCglnv+/IjDOt8+/16Ks73ijfQgENAZ19qoC5oTem3fdTYsM3v0Yne9TDkLNTUOYnoezYrsN59cH2DjufBtpHiR05GW" ..
	"oRqumWADHAZm735L5ARcaH4jh9sMd7422EdDzwOW9hrAamXdnNiA0aL7iM1r+996Y3CC1F0fjq1jVqqsJap/AnLcvOrK2jGP9gdx" ..
	"+/EXLKd2YY2XqetBfQfvG6AuPRf4mMQSwpGdWSPf5QX/5snSNgfFxXyXOGZf4oYOkbwWmRcQ5Ful53aWszYKrBqXjbXnuxFEFlWS" ..
	"IOBSJ8zdYkXjkSoZ7FOyk6sXftO65FSWcbhotygO4YMWaTOZ3wr7b7alVjHuN7DQPqEO8ZN+KZN/7wA18HlGStSotVkPkWQTQvR/" ..
	"Y6W8wnRs2oA1/M1zGozkoKEJzi4oQqiFUDaRvTttrMl/4kLipXTBQK7S0owyNenCoXZGVdFBomlvoMZRgyII4cQmnEJyLqnpVzrs" ..
	"7oStTMOHk4+Bkrpm02JffL8grFS6XWIOaxlOzsYfrFvsIRxCsR5rH6iq0zrcOqu2xXF8w7kItsRJDnZVjzlBrHFaSY6DvhLAmSmB" ..
	"rSl3VddszUkClIKB8KDjD4UIPw6NSFD9kpztshpTP8fCgiWWINs1NPCjGXINjtB5fEtjcwlgOuJemPeqgkD2n9++ZITT0TmP6TfI" ..
	"L1+TlIayzcSb5duO/uHX7ntqH7lFDnJGJzHB1XyOc0TeSnTpcKygQergJzmwUm1VbYeJFvjAgs+eGlS3OUu4hrZLeQaflIsfmTVK" ..
	"gYbwJ47iqM46XC4Tl2j9UjF/yCe2jZLlXfMazd3HSl1wJOYqJyCtS8iVFE7kDwGFjPKW5XXWOhPoJW+1x5xVtvn7YyNBXibUlJy0" ..
	"nzcolmSFs025aTumZgoQvx1koi5GgCwUnLr0hBY3xWnyu4FVLq3toQ0WX5iKsOG03b54GI6koaA+9qy8b47nRtavTkeXPoU6RCGV" ..
	"PRhObaI0Gt9vJQP6xAhr5uJTKUfDCIksq9j4yrg8kP9+pT1QNhbAHoU47s8qKip7SrcXiT+bWQcEvv3KIaOregUM3hlvSr1gHxAU" ..
	"BcU1dCrmGSdYFngPxbnIWo1fXf/4grS6jJOdUxTOUTFCNJbQOebCIceC1ggvh72284u/TGe21aOpLFXHdGU3hHXyNNhbHFWijsxr" ..
	"Hk2P3iCZg1AmCs+eURETqk20nc5tefkAeU59TZV+9LoscV8026Tbv59AUA2HLg1uPxcHuZ9sFQrivimEXojDlKq9vb2/eAKgnqbv" ..
	"qo/fuNwE6ZbbGtACodQ9ysVnX/EZL0KHaWcwuewaWWT5NrL14KUu9Bg3rre+bMj6G4tS2MmaHV8qsIhReqSFtDfAn06XljAsZ7Yb" ..
	"XmhLZOtLCLvUHUTZD4jJLew9/BCHPtDR1DDXAERr7tYOLFzH3EZbILqWm9FCUFj3f8dlZV2wnR49QtFB7KKWGEQKDWJThrmvwRb+" ..
	"Adfvxb4eB4gYNt690xu9NEMZ0n9NxRjZH2blvFdVfIlsKbRaxMit+rrk0D6Ha7ub6RbUCzU9h8OTNTcU+/KIWMAggz1yhcWNPycB" ..
	"dP7ibQSisXKt1I5PBysrx4pLu48fa4l/D51iZ0AYHKHfp5em6Eny7qqPrMxrH4soAwyKF0byNX8XOV2HFoT3fwKvARd3VPajfoAz" ..
	"3wmPh0hQyqHnTWyNA6ZkcYEgBH67FvdBzdKop74UcjCoThZfOVlfyz9H4iiNz6MSmzYk46KWXcncZdsnkIvF6ukm0cYCGg+khSF0" ..
	"w7nq5eaSe0Sm3uHPPFswq4O+ls7WeLhK4ApfeFf9cv3wFWO1YCqi8TKkanonEfDPWpIHixBcJQEU79CM/0tZVa26c6QuU4TBU7UB" ..
	"/ACUsWmTqHQCzbcGNzKHpjpfCnimzPmaiInswxEkCZy39KHMdWvGLU8SjpIkRyqjStN8f/CQQPuR4Z8g2cRE7n2mOx2SLQuNAGcA" ..
	"fOTXVwcd9AqwWpAFlb2mginu4UpY6DsLdBrEI+sxx+NI73PXgtc5UBd8//MBxd0/29b/bJRoImKfATz9iY7xXhVW6PiuBNf+t9sE" ..
	"W7FMT6JXVyOisM5PQIvUhppwaqaX2mZCRGqieuv7UNYisLzzEReDz6KjiP9AUbQfShvjiNIkvEP8GpU3iGGeDD2oGGST01+FhFqG" ..
	"kh+9VgmuyziB2Yo8A7//HLDq5v/tf4H8HoN49lhQjgFBMlNB3NrjsbX9UXXrmoobdcdmxFDUMUwnNp5MBkWVRD3icRdYVTVbJJ5a" ..
	"up4yYN1edMpmR8pv6boW5HtdBk/eF1XYIkp2ApMhbCT/iFyoKEk66Xy/df3daQkmWMMuhh/8fvXUpc6K7zRELahCgaOKAuj+Rz7I" ..
	"RZT0p205Ct7a6/FWgzgx8CClsQnq81z0OFa6LZaBTy9fTzpxWBoPhTRqDj5wqclfe6bkQuJTbwgxMjAJxfiZzEb/AZE8p+vY6jpf" ..
	"qN7IAluN1MYDrrbVnI7/H4BjYyHHHDkw3c3+cTZpyQZgnlscOp5UPphupNZu763lvnfjJG/IVl9qSB0F0JiEf0QKU1oYlw8DaKvk" ..
	"ZRH51Cjy81kt4Rd2K3CHteLrWzoeba6juJiAJlRADKjfubhMcLJMoHXiPpBqtBGT2K+HlbRDQMEpSjrMqNu6LbGHse5gvGGGzRFV" ..
	"nBgwJ9F7epHw6qS2KnkwnfichoqEWnOA+2Mo5n97zHudt7hfbsXwOQzOeqHOYaYf+iWdiPV83IjNfKhgxgDaZvtHpIXpU8kAm/jo" ..
	""
local PAYLOAD_P7 =
	"K8wy7IwAKIuMXeszqHNfnfRwJAmqidt74hCiGE+nILiW8m8TJrZmrWToA9AIm8i8uCnJwr0TwK2GNWrVwPhQbgJHxULgNd1/xbCk" ..
	"0y1XkFU1VzY4tPgS2uNdDFQEIEQ9450l/brCVBpQH4jPiCt56E/onnQlJT07hF4pkQgAZFhGKIdLhjMhr1WmevSPkdnhmZiszIjx" ..
	"20ccCwNClB2jWhEHzjN4dpDv6QLIxiMXUn8gIzpGl6XmT0P6Afrd9FDZSuAc4F6wUmN6yEw5bnIKcVEc4sfDLNn/0ZtVoCerHrOB" ..
	"xeZqnQY7S0DOx5FEPK4BIz4bBuaqHbGHsIjhrdghmyGhaP64CiTEE6aajzAYFRerQJ4DM4tZPYiYBAXDID/eb+zTnVyeyncUlPhc" ..
	"KgrRz9uMX0L2s5xQiHdi78IA63BF6WoQQ+oGxCprqMNmdHFm0yQFZqjVxWcYXKFPw0655N5NFSQ7UhYN5dhmVSmVnbE2wGIeIrW1" ..
	"5ikU/Ww0HNwPxIv1m5y+vXMHmdyqRm0z7WTvkjIiCHJ+KxXo7hbGZ5VqVgI2siQ4GKb2cEYgFsLR3VY5umaqOLWgNjNrw5NmUV1s" ..
	"285LCPBXC1uHCbpRDHOSHPVMc3B36GqdIfRwAastaL+YHzl6v4LHEdBJug+S3cGS5gUrTdTqcqE8hEr5xNCD52753H1UuCMnljwY" ..
	"Tu3jXxSMFsJdtkN51SMoucmRF9zeXjyAa75P2cX3a9C2YXPr9LhZ4Qk2zKCZv6LCa/AnQrjo1+DeJ/PgTc5iQT8IGx7NWAyfqUU4" ..
	"luXjAsY9FkyTjfmJsqL2P5+wZRUefCmeJVHsDlwQm6tD/kQ9RmX4qdNmJ6L9QCIlHvCvGyAubNFXsGJ/Qai3d92iTDXZuG8p2F3x" ..
	"HS/bGKWF1pKxlGsXJUFfVH4ep2E3c/Hf2tu8WFf8rD3BuEuOSECisjmVGM5leMNE2KXXRFHfKy71bXN/WXDYUorOXVa128MvbSGG" ..
	"JaDPsjHa0ZhYKoDy/84PKPcaOa4SQzT9vDbNOgfWmKYguvFD+iKjgtPDuakCJp5wD1Oc/dPsqJJ32KzJXK6SFPo7K2VyQMtrKstc" ..
	"/6iqsk2gIhSAmLuYrW7+5EI3P6Kpm9ykF3Y75WWIOiNrZ0Wdbm11hEir6sG4Yl6LFyXc2nT0bxgVukmFNkdYsfdaltwsa/BmJxsD" ..
	"cc0w7JxhqIb6sxcMGB+Dv9pbEBpF19tYN8dXSWhNWAFyDAg63XNQH5x1ozjrdARqfYvz9pFXVVUwTDr5zZy9S8FU9/EHpexFJ3n9" ..
	"b7aNCQY/wM+zjVePujmmoKJM5YSujTOkCqdoyYxPuyniaMwS1hVBoVCm/LyjLlgV4E+BFGO2IVp9LVYLvGwDUDm5MFJs/wJFobC+" ..
	"SVkNYDP2qZ9ixn3GDIV7ahyopModJRyOAQsZJzSfMTyfnyxsTUdtPI1yFTV+f3Ok0Nj/r0e9DK55nJGR293noQj8Lf4f3WwwKkuf" ..
	"wBr59cAx3SuEHPgdO3p7CA4hHc4Tgd12sHtlREBabPRTNoIoR9KHgQfGeK9RBwauRDt1+5QjXx3GIMt7N9XKYNEnWOQDA/yWRDZ2" ..
	"RBm5XFlcV66+LySs8PcbJMvVCvD6KmDM+TkhLQxaE08=" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7

-- ===== build UI nhap key =====
local function buildKeyGui(onSubmit)
	local pg = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, c in pg:GetChildren() do
		if c.Name == "DQFarmKey" then c:Destroy() end
	end
	local sg = Instance.new("ScreenGui")
	sg.Name = "DQFarmKey"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = pg

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromOffset(300, 150)
	bg.Position = UDim2.new(0.5, -150, 0.5, -75)
	bg.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
	bg.BorderSizePixel = 0
	bg.Parent = sg
	local uic = Instance.new("UICorner")
	uic.CornerRadius = UDim.new(0, 10)
	uic.Parent = bg

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 22)
	title.Position = UDim2.new(0, 12, 0, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "DQFarm Key"
	title.TextColor3 = Color3.fromRGB(225, 230, 240)
	title.TextSize = 14
	title.Parent = bg

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, -24, 0, 14)
	hint.Position = UDim2.new(0, 12, 0, 32)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.Text = "Nhap key de chay:"
	hint.TextColor3 = Color3.fromRGB(140, 150, 165)
	hint.TextSize = 11
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = bg

	local tb = Instance.new("TextBox")
	tb.Size = UDim2.new(1, -80, 0, 26)
	tb.Position = UDim2.new(0, 12, 0, 50)
	tb.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	tb.Text = ""
	tb.PlaceholderText = "key..."
	tb.Font = Enum.Font.GothamMedium
	tb.TextColor3 = Color3.fromRGB(225, 230, 240)
	tb.TextSize = 13
	tb.TextXAlignment = Enum.TextXAlignment.Center
	tb.ClearTextOnFocus = false
	tb.Parent = bg
	local tbc = Instance.new("UICorner")
	tbc.CornerRadius = UDim.new(0, 6)
	tbc.Parent = tb

	local ok = Instance.new("TextButton")
	ok.Size = UDim2.fromOffset(56, 26)
	ok.Position = UDim2.new(1, -68, 0, 50)
	ok.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
	ok.Font = Enum.Font.GothamBold
	ok.Text = "RUN"
	ok.TextColor3 = Color3.fromRGB(8, 12, 16)
	ok.TextSize = 13
	ok.Parent = bg
	local okc = Instance.new("UICorner")
	okc.CornerRadius = UDim.new(0, 6)
	okc.Parent = ok
	ok.MouseButton1Click:Connect(function()
		onSubmit(tb.Text)
	end)

	local err = Instance.new("TextLabel")
	err.Size = UDim2.new(1, -24, 0, 32)
	err.Position = UDim2.new(0, 12, 0, 84)
	err.BackgroundTransparency = 1
	err.Font = Enum.Font.Gotham
	err.Text = ""
	err.TextColor3 = Color3.fromRGB(248, 113, 113)
	err.TextSize = 11
	err.TextXAlignment = Enum.TextXAlignment.Center
	err.TextWrapped = true
	err.Parent = bg

	return sg, tb, ok, err
end

-- ===== lay HWID may dang chay =====
local function getHwid()
	local env2 = (type(getgenv) == "function" and getgenv()) or _G
	local fns = {
		env2 and env2.gethwid,
		gethwid,
		get_hwid,
		getdeviceid,
		getmacaddress,
	}
	for _, fn in ipairs(fns) do
		if type(fn) == "function" then
			local ok, res = pcall(fn)
			if ok and res and tostring(res) ~= "" then
				return tostring(res)
			end
		end
	end
	return (getexecutorname and getexecutorname()) or "unknown"
end

-- ===== kiem tra HWID co trong danh sach khong =====
local function hwidMatch(myHwid, list)
	for _, h in ipairs(list) do
		if h == myHwid then return true end
	end
	return false
end

-- ===== chay: thu tung key trong KEYS =====
local function tryRun(key)
	if not key or key == "" then return false, "nhap key" end
	local now = os.time()
	for idx, entry in ipairs(KEYS) do
		local seed = unmaskSeed(entry.seed, key)
		local src2
		local ok2, err2 = pcall(function()
			src2 = decryptPayload(PAYLOAD, seed)
		end)
		if ok2 and src2 and #src2 >= 50 then
			local fn, loadErr = (loadstring or load)(src2)
			if fn then
				-- luu source da giai ma de teleport-persist chay lai khong can nhap key
				DQ_ENV.DQ_FARM_SOURCE = src2
				if _writefile then
					local wok, werr = pcall(function()
						if _makefolder then pcall(_makefolder, "DQFarm") end
						_writefile("dqfarm_source.luau", src2)
					end)
					if not wok then print("[DQFarmLoader] save source fail: " .. tostring(werr)) end
				end
				-- kiem tra het han
				if entry.exp ~= 0 and now > entry.exp then
					return false, "key het han"
				end
				-- kiem tra HWID (plan=0 = nhieu thiet bi, bo qua)
				if entry.plan ~= 0 then
					local myHwid = getHwid()
					if not hwidMatch(myHwid, entry.hwid) then
						return false, "thiet bi khong duoc phep"
					end
				end
				-- chay menu tren thread rieng de tryRun tra ve ngay,
				-- caller destroy key GUI khong bi block boi task.wait trong menu
				task.spawn(function()
					pcall(fn)
				end)
				return true, "ok"
			end
		end
	end
	return false, "sai key"
end

local saved = loadSavedKey()
if saved and saved ~= "" then
	local ok3, msg3 = tryRun(saved)
	if ok3 then
		print("[DQFarmLoader] OK (key da luu)")
		armTeleport()
		return
	else
		-- key da luu het hieu luc (het han / sai thiet bi / bi thu hoi) -> xoa, nhap lai
		print("[DQFarmLoader] " .. msg3 .. " — key cu da duoc xoa, nhap key moi.")
		clearKey()
	end
end

local preset = DQ_ENV.DQ_KEY
if preset and preset ~= "" then
	local ok4, msg4 = tryRun(preset)
	if ok4 then
		saveKey(preset)
		print("[DQFarmLoader] OK")
		armTeleport()
		return
	else
		print("[DQFarmLoader] " .. msg4)
	end
end

local sg, tb, okBtn, errLbl = buildKeyGui(function(input)
	local ok5, msg5 = tryRun(input)
	if ok5 then
		saveKey(input)
		armTeleport()
		-- dung FindFirstChild de destroy, khong phu thuoc vao upvalue sg
		local _pg = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
		local _g = _pg and _pg:FindFirstChild("DQFarmKey")
		if _g then _g:Destroy() end
		if sg then sg:Destroy() end
	else
		if msg5 == "key het han" then
			errLbl.Text = "Key da het han! Lien he nguoi ban."
		elseif msg5 == "thiet bi khong duoc phep" then
			errLbl.Text = "Thiet bi nay khong duoc phep! Lien he nguoi ban."
		else
			errLbl.Text = "Sai key! Hay thu lai."
		end
		tb.Text = ""
	end
end)

if not sg then
	print("[DQFarmLoader] Khong tao duoc GUI. Dat DQ_ENV.DQ_KEY roi run lai.")
end
