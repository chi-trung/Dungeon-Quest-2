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

local function armTeleport()
	if not _teleportFn then
		print("[DQFarmLoader] WARN: executor khong co queue_on_teleport — menu se mat khi doi place (join/leave dungeon).")
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
	{ seed = 953250571, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 950604573, exp = 0, plan = 0, hwid = {} }
}

-- ===== base64 decode =====
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64VAL = {}
for i = 1, 64 do B64VAL[B64:sub(i, i)] = i - 1 end

local function b64dec(s)
	local res = {}
	local buffer, bits = 0, 0
	for i = 1, #s do
		local ch = s:sub(i, i)
		if ch == "=" then break end
		local v = B64VAL[ch]
		if v then
			buffer = buffer * 64 + v
			bits = bits + 6
			while bits >= 8 do
				bits = bits - 8
				res[#res + 1] = string.char(math.floor(buffer / (2 ^ bits)) % 256)
				buffer = buffer % (2 ^ bits)
			end
		end
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
	"QWQuULltsmIzub+01luZJLd+mNozdDDfqMxZs02IkeRM9VqNw1GuJsp+DidKUvBLqeNiyuUeik4KY5ff9mrv+b3BPBqKgVbB6Tgo" ..
	"/1ERaA+7FFTkt8kIVHIjQVosLuRaGSZuZYcVNd+Bj/nKUWK9/ujPNSwx7SFR79N9iajZMHKVyvc3kKzCRy6sySu1nNkEa89GUFrq" ..
	"NoGJFhv4OPtrMS2zbgZMPix4iqYitw5tKQjqAKIx7hsr07vFFghZSkr9tUY4G41RwyqCZDACGqIruT/6ryiuLjZjhc6dJE+yyjOC" ..
	"kQfPT/oiUYVtVIpzkBtXc0Y/rS8vix45AN03NBlhItFo+mlcXKUEzbPNOiMK0KXJb/002J7RW2Rbc3zPGS87KK5nW4KiCm98Anod" ..
	"A7NwqbWqzjBFQDAJi0LIVImwWUiKrWoAvVl/uq5ABKYvYfumzl6+Ni1dw6Jp2DdenjG0p4dDrPr8qcboM/ke2syJbdzswS8hJ66y" ..
	"OFYPkTpgHC/1MB7WHWVxaZtCpBVZ4t2723IWhoPveT7YR63SSk0LozQQNG7K7P/RND36/KUZVQFToDTy3OVXxJGudKaQysNfDJGs" ..
	"3AibGerDVOeMmJO3g6VSUl9iXiitQQyyq2kJ/rBGS4v8J7dRB2GR2A9f2NzI8voDESA6oMt3pQ/6wnE84K2Vmc1LtoWSc1q6Vcmg" ..
	"zG5RDqLsyL8kUuNVTXC3qstrspFjqSoWlzSqlFwpN2SWgG6s6duhYRZGinReyz0EiPp/0V9KyNrpdngLplfeOPSx2MBgnasTOh2N" ..
	"gZzEYu+uiLVkJWmrBQtSfUbgS/Kb/bABkTCAk8dtKHBE61VgftM1TcsdlAmN15Tt/Tnrf25NpLpobEcful2URNRmgV5qnMlJsmGX" ..
	"FApO/fliadweFJy/Xh7rj+uYLrR4xKeL3P3Fl4py4UZenGuChckyIRLvTy6Rb8CeX1BKDlY5q0Tx82/xBVVWId6Rvu128Yc3IynA" ..
	"HxTd2wAcuY2pE0uUDe/hXf9p6m42OcAboIgSWqYhPnavKoVg+9fpudTWMUA1o2U2Ea7JPXCk6/WX3jDgnMSpoEs4ZYJM9XZoL1aR" ..
	"SVy+Ij1/i8yLhi4N3IVzughTXrqg1LCQ72qOjHVXseQhlK6Tgw/etrOAowLUb2yq5FmS+5iKrZ27I8KGjURcXJxOoIKWe/mzOr5N" ..
	"dkFi3rAIa01/F0eXAMlC9xAkpFDngaVPkdq+gv0d7plcc+8bvGiaOvjrMJkK7kosTrOGZV2VgQVhKI1Iq3WM2Z+IRcrd4snV9K+0" ..
	"/5qpoGTbWiz0ruw9M/8pvl+SHPob9NRFNmbGS9s56hJnWQWsj1bUqpu7RAWvjA/wZc1kSjwWTAooA8uwKuyGsWBeKzNnzqgwzVwB" ..
	"n3UZbZ+EvNqCulAcsoGWWKrppUBacsGn5uPCpOy/hfMWaqqs8fX4z16ET7DN6LhC9sdSoDjveo4cCeOsHXZ84SAzrATKcW9T/wsc" ..
	"INfkd55QdDBl2TnIqDzUpb/3Cxl7PqqITuSI0hzb3sosYxacCRc6pGHIZpUoe7EoE6qPce60vC9z943CtycemxHk7+glZsvIxOZD" ..
	"r2QohQgccC+JFvu5IffzSDk4WHkR89h91eogb7EiT7zxskB+MdTHJrNapb4rGq9j5AL2Ud8Kkh3HfDA8bfMU4dslyw1ldJzuG5Kf" ..
	"lTxXFHJLIILmJHwkZTDU+TmMFOXG70/QMDlTth+FrA75rBhEqmbBy02NOd9z/ye99NZz+NCGIEnVrO+Tqg4J2jimSNs2Ch/FqkLM" ..
	"nqQnnd66ZoRKqQdaYnxBg/9gmpV6evQ5I0BJgGW8X4Wds8l6fuM1I6ePurkMipuRUDD8w8RgwLnNpb3KqspNGvW393pkOK/Tlpvl" ..
	"yQ1ncmwH8IxcFB7dHbZkzD/6qNuPlOWPtjVula9f+VwZr4akuDbM3dPXj87NT3ULDWYBKeQFINSVNuFgNiJdCpV9vXdZ6D2PwyoV" ..
	"a9QXUOkbllEiFl3R/L8x6xAFzWGG8KHd94G33iEekL6MYMT+fNUa0c7V/ddy5Filj6jTyiU3HoCOIWExCzYwW19EsHZv4sBc2qcw" ..
	"Huj6DqmlgEqT14vOJvAZv9cwsU76pkkq0ep2C4kjUEZgrG7P/tU9RIyZ43TT+xktPYZIdJBdR/EJz/tcuLtijPeObj3kk5ZWqMDq" ..
	"AEHOrC6rTMOhiKuUOL0wDKJQxdTqKV5ZA0Fhw3TAVjUCKBcLDmdlaZZesaLBi1KExzYgROWMlJVPy9A92YsKbcgIgfMNJePGydCU" ..
	"sprQ4kqkXk0n6oC+7vqRk125xSOwcjhkCqk3c4ovY+yp9ygsbrFhgQEQTr7MzB/1VUr/lxVYuU6oFvEHth1bwfvC4lcA5G7SwYXL" ..
	"QADdnHjXy4/EMaSlOxzDO4dngClpcQnTnVG63r8be2vHkea+OOO3hDHUf/BTD5Modp3SyqgxYvEZ3VK8iOTQRzFqtzx9BwklmGef" ..
	"fGGd1nhsUGCOOffC7fVV+TCWCAY0KQfkYSgmQ4WhdTimcv29DbRQNVM4erzUFAJMTaa5wW01PVkwOVhYgwkgnuc7+IrrFfHMfYWz" ..
	"YT1MTcLofMRutgN5FzQsVI2PyfwyNzKia8a3F1uXuidcCU8Jk63NcM0lyedmBHyLkR4cN4u+jNlEClwGyPImS1w6qgH+quFXmW5f" ..
	"RCDWj8ntvtQbXxKdnj0DdqRjijDix2J6Au4lU3rw01FDtvLpXDT6YS70ePo42Y4/CcdyaDz2AzN57sFxv1XzzK1xaEr4JmOU8lk8" ..
	"Nv6+CG831fDq/rbj83M664qwhFmRcRqS77O7LNRuX8sk9Zjigip4OxHWlyyGE2niYpX5zu7X0UbYdhIHBchfofrSUZIAEQ9/+LyP" ..
	"G4J3dOfJUptqzL+9kwv6j2MN4frSqvdbIgs6AKZ0uWkZXRnKKQk8pBe34m1rd7zlM4OV095QvjG+YG86hfJ72vKaIubCmalq5h4x" ..
	"FOp/HtE9sRHcIW9oTTnVpQ0bdPTb4sGkt/Nfxaz1O7+ZeTbBLg1lgSJyIMbvT5X0wimecgys01Hj0mv38Z2KivOBGiQfhftjwUCT" ..
	"B/RxpmIJKVkySXoQ16wgykKeHAnE8sJ5bNo34oV47q/ckdl/FOxv6cvyJP4BimRjue5cca2mJBqfb/Wree/fX5493kD32Y7TrtK1" ..
	"3ndu+PFvnlkOUjAR0LXLSErKwObOZc0UBsq1cdyp3u7Hfm7qBbXJVii3OU7y+CY8KzBkUWv53JXfOSv1pI4frmH7zd1in1uraiCx" ..
	"qBB0CAx96V/4/OnirfLIQOJkQ7PYXah79JwWcGr+K/EOlATFbuC7nZ+ggtpZ3zsn2zdctkBEHfBG/frHybA1JfqdoITtRJScrmq7" ..
	"XYGWzw1y05Sq5rnb1lsf2v925bzQMSc4PQYu4CUZe30dIAaBoonCtBEDJkT1dzW3ZUbU6O+Mw4XQG48hV7ZMThrw2ki3zkGJI0zF" ..
	"rHUb78XL0CEnMCl9lcTLKhUOfq1CiNWN2ts2Bi49ePWPhmJhQ79mowBCJKzIK+dH0UCepjkM49uaSTMGEZGoO0lw6sGJtawJKbK1" ..
	"hHksslioWkfgXmFq3TZXBJ9IT3I8T8/T7Ba7+Xfq5QfQHxiMwrzJnjsps0QEEiZPDv8OVw27nhbzMYKCgQkNHkcH7dfgYpuVjGcT" ..
	"s5Qlp4FVCRJpBekWBZRvsbKIKjINLvk1eYFuskfS29b/g5C+02SiradtljZTZkwCsqL6lB4fbYm1R6ebLwnfHL9tNvh6Z4zB9ghN" ..
	"UJd11winI8NQjS4Nv8Y+eTkuY4a7tRUgO75StLWIU2QrrdqxPHfTXHgo7hO5D263cK0YfdvDAz10A7yg4gmjCaH0dvlhN/9eCap7" ..
	"Y7jMpkSMjMCah0hjC0+i1tOyu/mXTf1kVH6ZV3jbvEERa+4WvT0+eBFxGeEccH6xmD8pvmNBryBqF9TYR32RPVtuzKSRC+841RVr" ..
	"25fWRvEzo03VmmVxJPmHl8mwItr7k4FEof0oGR8IMIjzpggUw21+BYbBssQvc6Y2TiYw0Jm3mpbpL+r4pktTh15arRKNdBUKuW92" ..
	"v19OMVhGicW0bFpS0zJ9zEcjvXOt/hkXqAUdSY+AE4MA1ZP9gzdgMay7OWVNVrgx5mS74l2l76+eKzfFYoM0Valmg7O+mnfBMViY" ..
	"VpvoCdcqXQ+o2nWgVLPt6GCpFzIPYy5GzZGhWIEvb907A3edd+kzq2S6LX9ZzFfVI+oQa5iuyC19R9fzoKFlv9fVM1jZZ8DXbDB7" ..
	"84LaQRAPeg64yuFv01fJrNuQbf5q7aOORHMGTuil5uS7gG4t0QspCKNEiS3+qIThbL+fqiTmNB+Nb2WmPRxLgKFCWZzdsIs1JV3y" ..
	"n3PfIDEEpRofylaw5K84eHqFM7vWLpmCShdDbAMic+4Z4N0PO546J9pkHTyvXNhjzrUJtHP3R3l82qNQiDV421sVE77R90WZIV6d" ..
	"yzu+C7ggN2wlNLut3moD22g4tyq6XO9scWXeZq1eOfUv6x0xKHJxjKAZx7iuJh5qtXbVUmjU6gu3GmMLQGdGSF2R3taThYnaZQj0" ..
	"zhmyvz6u4kkbr1tOMPwuY0V6QeM1LPToUFqjon0UUER5B0R4I9MRaCY0ZNtQZYxWN4hySXjvvq2QZ9VRAIGa17ktrusClmFhX/sA" ..
	"ryvQ0YgPemUjcQ+dfaWDGR8FxoBJUmujCT5anX1I5GdwYhC64whgfc0nqwvTVObZs/Vx+3kYn2mkXerMlGPk/WHxyOWTiux+tW9O" ..
	"uDxzWN+jM6EBemHQB/Bj2K4cCtvxlvS0bHz4g/kjFKXRudNTZsRIN+KJrwgB9pDgZCcnZ1vykW5HNv6lqlwvksujfbx2Xyl9GpoC" ..
	"DgiKG9wvb3kN6RkNGLM5TJW3JxWMbfqvfE4YR36DA92PxEDqZZwg/cSuRC+JLhlydI9NoKGfwrPDOEACWIERbDzPPqnmwoeOWvDh" ..
	"Yvg1bs0zYwNAl1cNSA8e3PHvrJqEqlBQYk4As0k5YezwOF6Yhic6AeZta0PQJtq4mjIrMwMWBZJwPTKE+vuGHrrPsJDokYFfXjYN" ..
	"RqisorqZXaxSNWSr+ZwZNL7sl36T/SH3cfZTI1h4CV7YtcNvgpSG+a+oJRkxXUVKEE5NXK75NG0XGQ3Dzzr3pw8RCXnuESXWkPcC" ..
	"fgd4Jzu1G8FL/XxN9/syyTqR240ENidpwQDnLEV6oUAiOZprbl7vZpjAT4rTRyOfw0FA+kXARI8vCjs5X8/8z8sPmB21uIVE6ILN" ..
	"+2/Vk49PsQtJQ9iPzynp3Rl+G5Egv2+vhumKDuKaiNMVPfiT+co8yCC7NO0D/bRDl6bsuc9eopsa3FyIJaF2zmJ4MYeUASxpmPc9" ..
	"XgnSRf4DwSFOhZGnAH8IvcCiEhatx33HaEj2pApluudzzaT+b07bCTBJ0xo2l2RTe6Nc8spKdv6dOqsMTOEX/XVSzsni0bvuJBOa" ..
	"h9ZMWNaKmntPLegfgH8VlOKwZCgPTesGoHBXwgm5iRtKr9hKJOS6TAWgI5q/wOdqChm9QLWLukV2v6lj1RsWueyrjgHrNa4uEwXG" ..
	"+FVt2qM84eROGgZixht3c2+Q0nznG9Fn5/WLE7lxQ4Pw6nnjWFX8Dc/0ggq+CBiSwfSFIUDgBurxI/q+GB2TuNBkwU9JMsowYS1y" ..
	"13mEMzsK58Ba510TTMlhY307BVevtSULYt311SDdbHT674mx37RQTktS3ORcjSn3Pgw29mOzNqNN5l5Vbms3zlu18oCpnTy9IjkI" ..
	"777O3HHrNp66ByLCNY4+0Go7U5muwz3qshrH31GgXJn7N7nW99qBetxCvi5OP7x84LyDI0X0+oHv5fm9cawNmUbu9O8c9OyCiF7e" ..
	"xOzy9yUwT12XRojiPiMZpE8ALRF7Pzx6R4sLL51mpGccm5GLdzgPI5iWf0g8K0mhsRpCqhQ7viqr6nMq8g41wYUXWJhrAo0LQWFD" ..
	""
local PAYLOAD_P2 =
	"JVgehNrrnR2OUWjYs+s9Px9IoTWEuTaKhIvEjwXBMXqLsYDLpPgBmP059xXMezlUAA9aia0bOIpEiDCkqE1QBr+PfPIL4Bx6aTC6" ..
	"SlLZI0tkvuAEIuRkQ7iV6muTrX9Iqt6L8LGcl+lPkZ5LZAgOcQWpsig6OBJ0S5FOvnp3rIXq5nT7Jx54dvgfULj2TKBqjAR7cauR" ..
	"f1lyqADMmbhU9DxwCPD7k7bbs5MSqxUAQANm7yjwGRcdW2mkQp1c3GzTJjof//cbq4fCoIe32ZqInlnlh0IMV8rlo6MDNDvb1nJX" ..
	"kOQzZTIw0d22nOnT/6p33f4J2P/5Y5DfwhujokuSjHGl+tyUpakPiESXnEEdarOMKarhRkbnAUYVWkrAbkgec+0qnvwMH5rZ8hQb" ..
	"W37UReUw/3F14zxnkq9O+tx7XiEi4PLn6tomyPyqo3YDV6gd4jAoD0E1wR67FXKWKJmtOWeGBz9HUWPpw4A6BF8Uqx8jCEvwfqMg" ..
	"l6n4sUKbbI7PIhQ+Fb1dyHdbbm+EaiVXLVHv4eguWDeFMv1t9/A6iDtZOGC/xVZB/q2egL7aT+HGeBWEPgd5iR8dkKbU/Ex0wwmS" ..
	"7fqP/75X5xuhsjNTKMI58Zh1Vz5cgj9jlbXYQAuKT33CPQ5iqq5+H3nLTUN4XgkrVwkav1DRkzMb7u5OqfhaUjSZzdvUxcvizzxk" ..
	"FS6ExU+sGWleNRMxD31UyM4k8DHVGZriyRPgq+y/qjqHg/FfWhYPRQ6mZC6/i/uJtCePw8y59L9vOpx3LSqOe0CYXywlMzvJJ0PO" ..
	"2sqCp/OFcuW6ivIZMzSdkHesmkImF3ZqszdaEpPvs2IMgvvON/Q7ucaq/EthVVGrj2t2LqtKCOknB1GMH18EOPBhwSAd0EaXvRfN" ..
	"bBTyFsb5ZAhb3n05/YuMTPNHVnqmhcTM+c7NXmNue1giOVGwsxaCgOVA0o+qX3ghrrzhjEXbZUhhecE2OaG8/OUeX6TgiQ05NDxk" ..
	"gyFsVWojuqfSSz56bF8qcN/g+O7wEEWopO6hwyZE7DlmgD+NyVyQTlxcXojQZ2KsIzCt0xK8AjoH77eSJXsQN/TpiFShf48ciybd" ..
	"UdK36w4b/liQNVr+l/32fqnWdInYhx5oxWFeSQpp8j4ok1UOCbvrdLMNYlVDSdFOa9sj3Ggxb4AaEwBh+brRhyEYFkNsc0CHX1Hb" ..
	"qP4p32FPkuL/JrzJ3NUmyOPPI1CL321ogM7THY7nPR4+2Bh/j9QCdRuDC9Ga62t+hk0A+4LqxvgTbIdq7S7IxV1qyR0x6boZPsrH" ..
	"NuTA/u4uJS2aaLU5OEBFHnjKbIPlM0b0t3OFc4xhHuqlMhyTmJkZ9J1uzFjVCQBMKykHGzKRgjc08r/N40fq2kFFgx3MfOnBE1xM" ..
	"xxg5ozYC0EEDOnkaFV9HktTzYHXxjIivlaCCgEv8mKdXqg77jBmdzsHy/omuy0dRPvO3DkJkQD5QA5HgW5DBhRgt/JRPD1EruXTX" ..
	"K4vrWCsXptoai9G8YWQYwSAOqPJ5YeJ0+/LDawioddSBxikuJ3O+6VZ7A1pcjzWiLnpO8gEKpqjbKwubSJ14qzKImMa3FfqhCLLy" ..
	"OQuCduFjV+NlGvAdxdv4cIZXtsfKi3XnD2eDxwIzU5C2hhK5wPsEASlzgAA/IoKKI7eOHT+reB0j3rtgh4IKlmzRbW+HXCUQMqi0" ..
	"CFz7yLAqSbZLgG/m7R3M0sL8Uw6ekHv2zOg1VBPKsNcssbsU6C3gnb5rKYRzWL4+xSCLvzEwka152oIlL21Pb1lskeVpn3ihJNCj" ..
	"4naKEBBQnG/iSTgJ7ZVhpcdf3CpE0tPS0J85QN6jF/TIjwBZh3mB3wE2Y6nTewu8tVmC0nbSXTZRz0LHt34+WTft7hW48JhUwfpb" ..
	"5ExFYoCYx9LBpXmiOxpPBMIa5h+O3ulckjfcasrQzPZCJEMYo2KCVw/+f6VyUjHKmy/Mwp36eLhraPYwUWmGNoczfj3q+lMLomyg" ..
	"p1HBdlHTiAEqeG72e8CUR/HvZv7zBCpTeh6pw5EYJwwkkC4lUyUzrPiZSfbZ2iPHLl6K878MnlNa/dF1BFx08t6JqOGXT+WhaySQ" ..
	"U1bkMzCNrZSCYuuqzq4oYJz6tc8vEXmm95kloUAzyE0i9NLF4ksLKPbVgy+sVwF5+PQGbXOXYp5owOoohLDkvKQMa+QII7BeuCkd" ..
	"oBlo4Uj+YXcAT3sGyM6NGA7eXadP7Kc3XCL+WAaYQ9JSZDL2Ih4D845y+PGhRHOgoNHMrgyVFhulw+n8CrdJ4drbYy43Fhp/dSkK" ..
	"y5S5UxNRRvinDH4ONZ/iuXIodi5k3YYdr4SScDctm9ci+V3utO6F2v43d3fg1yL4KR2jwTjcLEWsQUbUz9U0R5J0t95ZylMfY3+t" ..
	"4kh/m9OYKVcmXjJD1M0+s7oaS5gN2q99MlLN3QEj3d9HtyRRKpat1/JBOgR/YMjdx9tXZIgwsOXwjPTJjJbA3IdMTt16fV0eaxZk" ..
	"vnI+Xg46AWtea+IKZve/P7Vw8saIOuNo+vHZZ3K4awfAEAEVr6A3TLUVBLsmJQ86hyWi9cwDybYDjUg3mmB2OSCpmXocn/gV0ety" ..
	"CQL75CwgxL3oGhl/QadoXTu+RXWxhqOReC0UEgaP7sy9j33xmdpxVKDhrFdUE6dUozOg+9G29hSEzSKYbUK1Lu4cni8FKE029OvM" ..
	"s2UCB9H1WVIAFmbOxr377eq2yZ9MpgIPAvMpK/sn3lX/gvg9KPQ/8xcolgESnNMtHD3VjZNFboGWNY93QUFX704XNX9Fa7UF3t8p" ..
	"KAlvMsgqX3jegpGn7579/hs79NxxAYZxHgpG4dFn4KDyhG5VMD+XSfRiJM/10MhVe4HhwW0m6qtSUQPGjFlBrDZjL7iAtgUlwmMf" ..
	"AFUk0m/9P6Kp0XVmmwICZIogFhVNcB33HddurACx7NxY9KN5drcgjYdZdxxQfFOG4O7udOxPY2Pvp+5rfQ3Ak13fYhxRKTT1zlg6" ..
	"4iHK9E34imLGzAK+qW+C7VHzZz5afzwCa/t2W+Ndwypbx1Bi/0AGIbJ5nLr03tBxLixDus1D+n9mnKhgpey9w/3D6PvUOVyfb5Yu" ..
	"fbK+xSMBzDpkCZMgpLhTLOPBRZgaM5S3GFmCjDqheq2zaAikjSw/dVswUakEmAm3yfB5mnyMRwVLSmcOWnBeE92FqaBvLLfDJ4fD" ..
	"jeRlvOWWSq+oGUOqShGlUXgpR7qys1FhMzAWTnIGBnkUhgwXeNdrPNMTOwbQHUH8FSebTpaiM+wQsKGPD+/M3prhRiSBdanQKvUN" ..
	"WY0e9UeyEqzRK2p2tcp96MkNDTikLi15Tycd4dsKGUH3YcvMoXZFw6KRtraDzYyHB2eFsFqVvSpDI8tp7XXK9pj+XS7h9QVvqyr/" ..
	"L3sB4AtQrdgK9JiRFvcnMkv5sgK+XG69OifW1QQneYTHRU4rACXsOEKK6D7LLzamokFj3XhQwtjlaec4O/rsM0zNrPItQM2yH6m9" ..
	"YtLlWOCoBK6N7d+0GHnU2Ncy5tFUlZjGbFdcZBOuOx2QjTPIrxXsCpWHceOMGRSIqeA6yvFR+nvCsb4CIQhQ5OQvz/DAkr6BoFne" ..
	"+yrl2VJ7vOlYYyg3DRfX7EP/F97Vr9FX6vyNza5hWNsUGylo9uUIGJiAUVcX53Q+nfM4b/DVlo/jeHW96Fw5uWtjw8kigkREvyQ9" ..
	"cqkHLW1+jVCDmYe3PC38nUmqBRuwHgwmh+Uza1vx3LpKQHox2LuqC/H5JOqpawbJyK9W7hqFOf8qpcDKr7eLAiASz7/0ZwlgZxqL" ..
	"8We22ZQue7ujMG5FCSI8Ig7rBFc9Fke5JLWTkzVBr+Ao0zv8lpMHcxIyYcbLUmZxsZCGdKV9Yn4vIkvYC1ATJrArEYAb5dg3P2Iy" ..
	"aXAF51ytqVZkVYCt+Jn5rPYz8ik+kPvTBsSvpMkOzaaTX9Ah7sZoX4y4+cYi9+laQY9J9Wap2JlOaIcSU8dmOiTnPrxtLXWtIrwr" ..
	"5/5E/U7jS2y9wbFh7rJzaNQc3CjONtev5S6p++1/MduSYZAC4fmYn1ic1TzH6JlaEkEtjtXALaKV90TM2My5S7i600+3xGF9E+7Q" ..
	"i6pknpIFnVqx3Ze6jS77IlCwwI6Vuuy1UR0XCAXeAkCmSRXytkqSPLNy88uF9zWY1Y7Q+ATjiFHh43c5AkLemUR/Y7irlt2hrxPn" ..
	"0I2EKxJWZPWEarrnWFTUYAUH4qOEJZ2grlKJXEJUwxXS1MMKO6Esk0JG5EjiYwMeSE5f32pANV0VJ1SmVGqbitZ7HYibnsdzP+oa" ..
	"V928os2Nhi27+KQNi5a1RIecSdqTcOs/vOmNiM2ysGsn9k5yvETKs3xozP4o46y5dT1z+fszDhQ8VITfHeo3KOd4Tw6lkM8lMI6n" ..
	"UiSYL/hCw09IweAMQHt8XmgB7BScgjApE01G486G49nCo+e28zHcptRlexU7woyhjWlu0PW4RVeFCW/FSHOav67TT1qnDGc4uDNS" ..
	"NG3UkNjUuOdtcpSIDC8A+tLux6D/AR2JWc/XUah7iSRipbWdVI1bmYkhQrxcSOQ49RqpZJAbrAWdQHFVrcQkeaSRS8xnm4ISb8Jk" ..
	"003nCkrfV/V+Qvr9RwsY+Rq7asEs7s1spUgO9kb3npOhcQI26ch/l3mu8lQxNcP726w7ITu58uCDewv4fYJfiHUyhk4GyPwpGjBu" ..
	"gHkPy9T2chnzK6c+1MEioHdmfN3R7WlvxDmBFgPgqoH1z0/uJ6QQd+3IWWZIFUZAq87THoa8cZcAdvqbhq81viD9QbrXF8PhwL3K" ..
	"N9oAo7iGtspqF52ArmwthNISu/wopQUwOhBljVAwR/qYXAZm55HRTPCb2v0SWiw4B58nw3i9qPVKM1dvacaW4C4754sC0qxzj2+o" ..
	"kw/YntQ7gq1j6UZno2dmyFM0ZPvLv01bshEuvJauKTiWzmO2DltUTG5OrKVrlHLT9fNxsf3fUA5w8r8HFTM2rbJpyXAFr7wTEu7W" ..
	"s7vnMISGN7yMT8/WhZs0nPENDTugnrYW/ENUGG2OP+gcmxjcVNG0MLfwVru3CuTgmX7LxkNna8/OSZoY65ds2vbNwIBRTD3gDYX4" ..
	"/zc0iX/IwYElN77B9nk0dA2PzhMc/EzNwpAxOqB5kGvDF0b3V9MYnVyUoEiUniT5CP4xQFZQwk/CsGmlBChV2XkoZF7RN/gdbh+H" ..
	"vtQ44Y0sA0e63zCDdN08JQJT/n1Go9IqTORsnm727DNKQEKCddDY3tj2d37HQCdC69d2+7snuzaaTlBPqhE1Rr68dNi3+iSmN/NJ" ..
	"D5LUoOIWy74mwwcSZWR82vd+UKlxrPoOALtm6StVNm+0r4k55pShWf6ZTUgWdYUusrxvVPJ3jtqIAhlIyUG3QQpkyCsvP1R2NoF7" ..
	"HtF21Pk9w+cWqlqc/Fm5XVH+3eBAAXOwzim62P68hhcMbFzUxXQT9+P+aTA0TrGryI806jyh6TcChB9s1RrV8AUpTOrmN9xxfWlS" ..
	"k7eXXp701PavNMrOhPPkhZYnFeh4LRGYNOi9sGRVz3rkawp4dOi2bRuLO9Sx5rjMWf4YekI/ouZB/1JZHBjRZCohFfJBUbbTlX8T" ..
	"CR2wrbtaX4xcJZGSugiY6q2usYtxrtZp5EK0hEHtdLkHcsXi5n9frWF8gq/J/YKQGHAIO4cGPUpjaPGHGX6aA6gxlezaCs9GvEvx" ..
	"o8P47EcjTK5IQNN+GV6bDVHnQ5JE9c5SD2r/TGR11HnCEYgHUQ8hVWdP6jR7hfQmoFiMJXGeei+hUxBGkMJRaRYCpPavOBix2Sm6" ..
	"C9mKsBoGt9+ymkjOH9fmq4xgDPmQ+g5K01iwd/u72eGiu4uuACpFieyq3XeENIeAc8PGD0KoNHaPgEdXJdcb0+lzGMWOj/w1uP7w" ..
	"/wVh64Si8e6nXKJfg3pw8lGH4sSxJcD5SE5d1ROB9BNzZTKw0KJiR37R2ahAA8CLqO60rA92KecpQ14Y1QYYkDKO8U/TUmgI603I" ..
	""
local PAYLOAD_P3 =
	"RzQO4TbfiHnw5ilz72FBt0Tjs4VO6/OVRbp6h//+l5vC7KdwbDoCdyI47ncm+i0nLYlXV7nX6uwFTay7LsWxfE+zQivfBbCGic3I" ..
	"9/fxyBMLtfwAWiyVReJM4LkhU2ERZmCqkheLQubuPXX9tfHE9W0somz/XtNWQzWjoa3Hu4qlWRPe8msSSIBV2xePI2hkUUiclvOR" ..
	"h0fD6bO9k0FSrnH04snIklPiPc8EAHJSIb2QEnEcCWEf7kennb5GMc2ndMzgZ3vfmP1BjlF7p6nq2sCXYw0jShGZivjfAp9oz4px" ..
	"f3LISc9FNFchqLRf9Nx9pRAipmNP6pCbPFTlwYwZlVtebVmCcg6yrhIoSVDPqXghX/3wYSWkQD49t2Tqz9FPLr8IRo468vdDsQtD" ..
	"oGFDC7Z+PAbS6zm++DPuJ1CeaLNzxr/ZNNDPYFFhS/1UZEX1OVF5QDGjXFMoPz/Yw7nTQPI4BE6kCAew3dx/0ugp2wYXJX8gSI8y" ..
	"OI6yMhQrpRQbaljwOnAeS8diBWX89ITh0HgN5vK4WJslqsQoxRlJ4UY9gmczlzS7uKO1uWaEZif51HK7gPYKQgRUuvU3K8194QQu" ..
	"Nsyk6G3rvd5be3d/NlOiNXIr17B666BsKkz38NOI6U1pjw3fEFtNzXqzlat3gaP3eaybnnk5fg24AMot1tqxdAJAOjKe3grNTe9B" ..
	"OLrxu9N9xXjYsXyUXVhn1eNBh10dVIR5uAIr7PVjl8cZ/uOpE74B2SWYL2eZ9JISeVudyoTyYb31S4QShWVz/RJwxHAQshoQXU07" ..
	"Tbv7UrSusJx/LrqV/dg6A2nFvDZwNslp9g1ZmTmSYV2ovwrxHDMq/DVHWkkcpTDsgeDuAMiCXho2bmqXTF4ftT+oTuzsnX+tOvqj" ..
	"i6hnJ+Nu2MJz5sDh3S+Xy4mSUgjTV1l6+MjCB8yhjYXaRivmARieKDygDEZtbNAFhn8ii24mkkcD04vZyuq0ZZ67lY+jhjVg4B7d" ..
	"F1ZYtLT8ZDl1P2B2itOKQp2/+XtdmBYM0OurttOxXoBSmZcYSsp0edMUgjFUBm26L4q+J6cX9mHS7aIuPFiMN3EJp/S1COREkNV7" ..
	"tLiTxENNGfjCtnSB9PfWAu9zRxBrcy7sbj00xZk3zQKh+5JjRrGhspefRWjfpQVNx7BL1y9O9I+V3PYxBWGqQKX8wW1V0W3aPIm9" ..
	"tcLlG4uASrlx3Ws4qJy0rZiD/5LbyoDUAV/eDRIeP5yaiBMyr44DTOa8zJu5UBPlf8usmJilOFnBi5RK3JwX8nWpJ9PFrLPcVL7e" ..
	"FIQ1dYByjltBQdDEYZneuhieYsGAhSzVqQrj6+GLqYcZDS1xQJMgdYkaoK6jx/AeSftr0xLfxD4uT6v3yx6zVKzL3a/e5IP489WV" ..
	"JfIVyrSXx/Pd4X35vEKsR3F/0zbVAOE47OP6eoXC71lsxgyOdPZbyP12ptWrKMz9ZZBbhfn5h9BoQ6lNTS9gO+YF3Ui3QajVF48I" ..
	"4EJfE4+z+85doeAqNUGvMBBMlIuKW3geGBFe6z9HffAO61f1cyNc07dIpIKX6KNahVE24ADCKOxMSazGhaNJQ680bAiiCbdXhCM/" ..
	"tCUQ8/ZlFPhXXOvOr4XAgGY/2FTTcZwFmYJeTCXFNRi+efQbZJCJQyLb0trHYAlKMKwG581AEhyn2lBshLV9G5PqbN4XdG8JO28u" ..
	"qhkLYbzKrQ5CwaQXi+p4WMawE62N54ABYr5kFM0kfi6sJDEf/7GicFFwobjmoO+u05JfLpNJRXepeH+++Jh0Y0h7XQhw2gm+sfMM" ..
	"9Im7bKIJG2cGayVaWEmHcqPVZDuiZ04TbB+0Gbk9YD0en1lTgZxAzSJDN18SQ1odR2MliGkjTrEg4qFmSAmlQ4PRfvVyterS/J27" ..
	"bR9FMUG7bSGM8b3pz3YBxmT/rR7iekCFY71inxVH9E3pIqh5C8I8KOdQIF6jH1YFC89zFwalTZJ+Oqhkyj/61oSVwmEvt1KyylDu" ..
	"IKEWBL+wjijOHn59OKN1VQxxK1IOWGSw7LoNsaGw1vjtgK5pb5ouVlbSwotJoPoS4uNaF3rgkOMz+rvtyqWhcJ0FgkRcWcKz8vrm" ..
	"W2H3KTwcWzGVwHqdy8OhuqC1e+XlBWOG28/AtY/kVqCM3JjRom9QGiDdf+ixNXAV7BpsS3JFuzOpm35VaY/FAAvST+dbQoUfqh7y" ..
	"IHuo5cAxATVXY/qSHGrJtMtHuO7+H7uy/Z5vdxbM9V2l+t0CcUudNb80sF+Mdb2KDknWSL0fmI0wfeHdfghKGDsuhKw77cX1V6Ry" ..
	"PWfq97U+QEZxFod3eS8vbKa3Apn90d4rhCIPAv2dr2x9Jas3ASbIp1MJxZ2Oj3W5Pfi7zs+on4I8F2RkguwE4Z4tJe2r2V6olsXa" ..
	"+j8w1m21wT5is9hISx4IGaG3SgrgfaJb+N5N2r6A2/yhfSRqO47OUn9x6FmVZ+s1MPaoDBpunFfQ77ZM7nc6gNjwdNLeSPnzDW/h" ..
	"PBTnPvxMtiUkap17+yKSqru2UKiyhuqMPnSvtuFhNxeh3TsebG0/D4n3wZ5AVElq8WqPO2WOJn4cw4WMY5N/1FKbdN0m5GeblPJr" ..
	"4ceVXDsTM0KDtycSaTK8kpP2Bm56tWAOOcw61U+dW1JBL56ZUVxUZmZ2Pa3VbQTPdvFpP/7PgrZuMXG2HQL3bgwbr9n0UBC+fSUC" ..
	"SGVdUG6ZrAbkcg/MoxNOj+a+xD7xRytvXwxr6k7y6AefUOENrM73FSDVRUcsPhth3js8Lxar4tjb/Q5PiruqMlykqdofgOUPhBUk" ..
	"GDuMasdgjsniMb9Wk/lAcOZsMkBLc/4hahJ2dmptwqLYbmYLerpLVm6fEfGSXqtFxtejDLNoqHYEBP8O993WoKkEx+VZlARqGYa9" ..
	"F15an/o7GRgBme7kYh5mHUtiFHPpsGl31YhU728DSRvp8suYxBDhPTX9FiALSvuD/pP80tRoIYpbi5mjos4XYKpyXxb5HKaFZDEw" ..
	"jPZEd0qwB2IekURkIxkLGRuEtAhHm/XNS9EvgZBiDpemMgZgiTdcrmOfR/29kXmpGquxTmKY+J3iXWohoae+L2zI6WS9N8IM5HU/" ..
	"3Sl8qjY8bmcGaIMHJawn1xzGKH+N7Ej+LDUMgRNBtqq0WM2Fic12I26IawSnHQUywxtqxw8YUFc5+zl5lWuh3ZED5Yyy4zX2aDX9" ..
	"rZkRKOHGgoVSyMt17hWJGiPgsxNleKSdC+D0BICprs0TzbxPBnju91fkOfSVDe4OTBtIV3UPPWWfveY6LPbRROhbFaJUq+Y8SbMd" ..
	"dawEer8zhbv9C0R6ffovF5229VgF14BZV7L97IcRncM1HekfI8bvlsTLfD8s4+DP8mTpu/qx5FOL6RgU5KXJ8AA03wTIrA5dBPJ/" ..
	"JdGJD54/Yj0xqwlfYsTVbbiw84lijw4OTBEGDY4uzWgalY5P2UuIBK8qBZp9HSi51XIEubK+TMwhmbJStSPiL5haBsfoZ/DI/amw" ..
	"u2Usy3OlUPWV85Cp3AoCqc/0EHMCLXxcnr+dEZWmCadgUV7J9oeFMUM6irV0enKFSazD5rBxSohzAjT6RfL1SAi7t5WB7OeeCT78" ..
	"37/+A/p44R+ml6Cni3Ntn9rpkBvGCRlf8N+XO8icHC7mbAtMv7G0mUPHMzO8fVysSGGMBpFVqgrqrKgFp9HLiArgBmeJb6B9wysg" ..
	"y8mWvisgLt0UvjI6lM2fZv96cu0PIb9k4BNWhxGovkVDjzGFJWmzIle5e3jgTGHg4HqllUDbMVkpjmYoIahLsnQ27YkuI6zkLBzx" ..
	"qJq7LKb2WUmE/KFHiRUZ66tWgWHspoaf//ilOngpuUgNRMcwT69kb7zmoxis3MGTez/7QRWM7WQI4cJtSAn0j7qmc9cwzsfGkuED" ..
	"+i1ksyfuQd0sgZrAPHUUoTdNbFzH7pUHIOgcJ+Us1STAdlKfPpQB55wrBjz+SgXUwLgjzvPz6T3yRs6Vy5v5TGLlqJ8TUoBE2/an" ..
	"ENnXDjwb88lfNBngARybTzGETONmZQwyLeEZ/zq6NXhZ7Bjfd2W42ewmbieCr3WNwu/QE5vFUFXJ5P1sFQ3TWQe+l77JSCyYZL9Y" ..
	"sEEiOyX0j0rIVFRQWiYHPF4KQguGgBeWhCVESH7Hv/Z2F1MfvgPYFOxaB1cCYBbCoBmE8luDgnSaU2LgbOYI5etngXAZj/6OaI1/" ..
	"vU9PdSv05t27Cp5fcoxzhqfpad53leBo6Cj2hIIs9CQKt2VnU/B/ti0/8DXH7QbCur+xw/X38JjjBT/wsZ7jmx0RzB5IUvQMWVX6" ..
	"aMV/GDHmr2IuOKA5lJMy8RjGwi3u69vO3lfBK5PByT5m65hey303GXFq7DvWdHAo39ACD0ReBF33mj+chn2YJPOw8clbQ0+WQWG/" ..
	"75IctEEOTT+Z5c9VTqefttHHYBztyH7Hwdfoy9+iUsz1d13YRlE9N55nbh1kwT5rBWIqh7BoxUA2FtFdM29RzrTHW9WLOBrfmKEF" ..
	"IXUT5WKBy9nWUKAr1rg9Oq6Qh2DXnFcGiDpoXhDSjrKmCqPYqqeVzaQxIXOQ409p+28kTSfHvzcTPOcxba1t1JJIpRks/0INblLp" ..
	"a0m2CCbk+R8EI2UPFGNjh6Ik+K7QHzXj3zJyKU8kLC2ymvFQfM+gVsxN4QCeP8G4cJ18FvDVwOrN27PwG+3sitVCgNUsf1Jap7ZN" ..
	"1NxKMBBuAelihMtU5Rnk5y4ijy8LzS9nbotNTV8AOwd88kd3aLMS4QIqGlLl4d/IhEmTsQcnNjytJj/RCoaHP7ivK0pMptbXaolj" ..
	"eTCqgZym+Qzxz+eb/MT/lYE0VLXezyWs5NbE0MyJrrivT3iPGp4jH0zyDLZ69lfM7q0NGS6RpF/7V+4U9oEyI9k/zguzt0YTIr2f" ..
	"0unMJLFV2fMX+lrRqBLnnAI6MEPhB+9Rk/+RUH34v68IiQSacq/a9uJCuPBbaQFDpORUFntMrnX0MELCxy5+4lOz3hLBCK0Bmd40" ..
	"EvwmOwohj8IHA5ZjFcoMo+fsOGgwp6V5YAlTY/LIT74fpWetdKeGIF3PgDwQ1LXWG9kRf6v5AOnsLoIy3QnNePXYHsTxXtutqaAZ" ..
	"LcTtpiEg3K0s7FPmUXe7YH4CR/0g2N1Fv9FECASzlyT+0KiH6lF9+BNUl/+eHBassEoMdQpihu/EYLpjmQw/sA4oo9+Bw+oZJqLh" ..
	"YqUKqMqKT/f9KLTgLaXxNvf5p3lJjqao1R1vydMHmnEgrPucXgpWX8wmb3SwrAItaRSvW8G7mJjubX1jxPoDL6T/cQ1SQ4ffsu2W" ..
	"WECtX7sRsWT6DXoS66UXwIj2QptdJ7k9L9EZDGhxQF41Vx3b5I0SU3HU5HHog5HfA1TaXKNMoS8Kq26L2MOXtNqhSSAqv4PqE9ec" ..
	"nFIvgboiEvsVJXYKq/gMhxxlThh6i0asTk1ou8niSHxEj/mVhb7w0TRioWQDfrMEbqOV9XpHZhQbBnPSDmKamvSLz4w/+Xk78ce5" ..
	"DTCsOo4tewbhiFygnYqmEhSuIV5c2hklIMHH+M/kh7Y/190JIXy8NjBUYV5/zUj8jbikxmBoIDI7f8aSSBOtba/nS2b7Ak1YyIwu" ..
	"cXJeP7JPJ5Vuye2H8q7KsZeXYAuPBi7kmm2gmePoKdXV9MZJQ38cOG0w+knaWrN4x5uLKvnU7uZoK+TTJU8VY22tycDap1ybd2/h" ..
	"5SZ1RLjO2tGFFTIOcx1sbAGra+T6Uoet7AzTv6FlG0DyND7E4/BOCI/bF7aWr6EYdKE7nzWyw9zj3vAkabbNVCmB72gHiw5Oa3OQ" ..
	"Cjs63lZktejBVpXwYR5XHILCHVKvsgP9AeYzImPsvfgKg+jRcGu2H9iab7+be5cqwFqvpfcvR8UY6ET9cAOIpzvas0IwAUK4nqZb" ..
	"xFRib/EdqVF4g8K9IIMLMRg30hVwswqA0S9ePVDki6S2wIDVSNdn8Sn4PrkqFGzrpoZ1LXIWzOASMSrAVE29wSeTM32ATKw6JaQp" ..
	""
local PAYLOAD_P4 =
	"dzP12nl6p0jSF+NF76WU2WPR18vzYN8Vx4UVARnjlsOyRCuZmwQSaiqyu7Uvf1qbZJfOh3KQI4iDDdoXEEZXCfKO8uqxkIv8qFLC" ..
	"dehYo03Wxulk4omEuAkjbH0OpR/zmiZlLX/dr2kotnGgY8NXmiIpCk+wnuPOTtLi0DUiIhswKqKR0Ip5XtG2BTCTeRCWNkQmiONW" ..
	"7M9mIGmf6+UBb3o/AVUriNnXYEklzaw6XGpvoFWnguOLWR/MdU8wiHZpg9pq/j0C0HZA+bx6uxWA3zxhKy/E5uJQk3d7WsUTH1/k" ..
	"PvHcKStSMYJ03PjuN1ky3pelsS8cm6NM9P/sGBuulnS9HDxHddy/8+fjbZYAhXBSyaVwrYV6HNO5yFnt5bYwoCp6uq7I+A3yhjFu" ..
	"qadCyJOkrWQUtpvtLw1SAXBWcVyt6EV/UOKwYhheh1rGJP0bGKi610fEq3Zmzqw2MoVW5uxOC68kJoYCVoapJJghuzlFNDr7v9Aq" ..
	"XDOWXgEJ40ZOhC+uqEsfiTardFtNEO91qaNxvqNASttidFqzxnwogO/CgZugO+t14VikjQWW5roYBnqixwx3EZK755X52GZbStra" ..
	"0GCzmF+hMdFcN3CPcvT9dFVt/G+PGOYGraxdJfogZmwbJUmWlqDPBxj0mCqVvjnI0V5ilPzOG4k6QOqZCuxmoGdyoRMq5Tn0ZR9W" ..
	"NiqQtk9XlbFbLrjo+FPR8ZjOSkkbRGuFtCFdwCELjtQCcfjLjFNFSAzhfFBwS/AjFDthWtSd4w/Uz/Q5WAhdoGD5Y27HGbbsN6X4" ..
	"O3HgIGX0YruU4wdA3bLOyGuToywJ8MsY+2cCNPne69JR3Nnr7y8pWQmLicGlkaed1OiVLEhis8NwmsadjKkyTO9hX8qHQEK4/GI7" ..
	"sQuTO6W0ZSSpjv4tsqKrvJDO8W/tryHqr62hZa+E4AJUbacfAr8P+EzsrfB3UQVYndhDoYndIwtrw9vSo1TehJAGliEzR9XOHVa1" ..
	"/1fmbqzUWmdtGtRJgmQbwJpGcIHn54Zgf0Mvt8kMrKY56q0FOmgn5ZhlUFJ9VeZFKj0M7M0ELQLnt0IwTBOO/8dDKTb7w7Hvsy+r" ..
	"8uwnHHfMpGnrhzKa39zGATH61Yv54l0zVrsrf3S+5cvJ3WYU4GuQ/M972lUwZWUykuQjs9H78L/sjwYFvxUSQVgLYUt3G0y3I6hZ" ..
	"cLGq0yDwby19walT+Ny7Ir0fmxMxexo0Tq6x3orf1vmWOmd6CEtDfVX0X7h/acHpbNucaeKIHz6yDRQNoDIvj3R6ZlDaHzqAqo+6" ..
	"k7gccDh63zQ5JzZtziRaRR1gsXOqfRZxPvwMOYML4J9f7afMV3NFZnjmKf6Yy3hNYr2NCVueCKsgCKk004f1cgCioc9Z5S07hf+Y" ..
	"Q8fKbBiJDnmEuT+UnDCMeXtPWMs6qhmqHk9MWAhDsuIJ/WIzuoHBlbDltLOYZ29Z+57j2+kNBi98KV5dqlJ1G3aaCvh6C+KZrfpK" ..
	"WeCADFylrO8AaIYkRl15vKZ4anqOzctmZLmkjXt4dOdPIu+nfury2CTQxw1lVQhW3wjfgGSFaRgGhup3GCo4leNYNxncKjfxcIDi" ..
	"aoOQRuFuNjFx8ueoP/pwSUOkefCI/T3IU3vQv2Q7+J3Z4JiwcanmR0Wpw4WWfoEZYY4xo52H9RiKcqBOMTI0Hht32SHvO3ZaePzp" ..
	"L96suwLPU2WNKXpN3oyn8v+4zZpUm6RHE+1kD4XDCeog8NElS7IHToQEKuhg1XuI3XWwiD1wLWfKFm0G5eXTiZLh/g5hCS8hjGip" ..
	"J2dTe5Sy+VGSxYQMDSluin0uHc0LUorE3JmFEKXsqgZBACtNg/ZTh8Mfg+j/IvrcpiQt0Pj3ON1QylJlmza7K6jdu2Fl8w7D+lNf" ..
	"Aec8r1Z1JhMxgXZp6Fhgc+lpRoc/3fo6vIFCJlt5nBWL/SlX+R0CjwvW8oKOjQ4EKz256Ul4NsGYWMpVlKDCjUSY9ICRyGygpr40" ..
	"PcjwhqPEufudL7h20eS4IQzgL3RKTF1r7Ig4TMyeojnk2J4b3wFdun4XRmTcJEHqkSDIfv2D25bwXLaiCb3bz614YtksnQ348SIz" ..
	"I9z3Bb48PYHXjUSQZ9qpuEm27/XZpDh+VFfEUbtR9d050LnPtIxkhbhXYYo3zfeElZBsKOFyrtze6PcqtUzjNms9KBszqkxlDyyM" ..
	"j3IiJ5b0eGGL4nLUKCWQyJlz1yRPzkX/MBKR7s6BXlMUcYIzEcLU0vQsfQy7q8oD0OW6HvWpAhAxMeKypZlGIkXFHM+wZRvxqddq" ..
	"lv8VY5h8MAqOufgyiMdJ3XWpjNinpxUHhah807W8NTlEstu2I2qrGyHFjoZDOC7eeDwAWmQ1MOpZHAH+nMvgE+SblbIJDjcfTebU" ..
	"g9I0s9xyImzFZ7JPj0rkisULVCctLLSbsbk+lWuWul3z2yuhNOUeidd7g1E4whizkBXO6uNksi8QpaEg8ICyqqbO9R4wASTkPlcp" ..
	"QM7ioGumRFRmi1EQz57tE3Fl6tHf1EZ9InOUYboOEZj2EV9A/VqdfXUG/kqLyKaoLc9/UWh/ZsogOFSdumSdkzDISxyoM9bgw7sK" ..
	"BBaZWO3AjEZj1QZN6ErQy33p8LRgjoGd+iDPlvGI7cyTdiZOdveJRbeLf6sXuRMGZv3p9NOVE3E/UK8gO03TIP7tQTik3ayNZ799" ..
	"+ZAiMHZdOXfUFl6vA0FbxnvzyTIZeSJaHw+s49P24JZpeRqh1C7vPdhdS0FjoF0ZBtgoYtxMPOWaiPsCLmj1tyB8RyQbJX0I13pX" ..
	"zJoKpBor85B2fgdPBpRABZnCMYAOXkr4a7Q7QM/O5Wh8VP1T88JnasU9X7c+qmM9WqDI+HPMz4IIbfs8u8jHX6Gb81zgoTRGR8/z" ..
	"LSansWafvPUK5u4lRtIZyaZuP6hZt9yl2ppvgmDsU4RmapyI15jUudn0jpd7KQuKSrg2mf7b9FRT6LiwCEi8S+njAkwPoPs1afCb" ..
	"9TUijJOv1bnep0ryDCceT92UtzP/i1oP63ZwWVdWWp3/qmzubA8SU0iHkPjU7sSxDF30tudWW86OWk+79U3MZNU0Aap4dykdO3ZF" ..
	"1poJc9AK5tgBa9kWdERf6e9aZ9BHppD+5HR6sbPn4zrIN5ob3EsS9+fPYivXi/UgkW64U+KKY3YiDlm5nubjDD+45NMFAkZo1Hjm" ..
	"f/IQnkSsCkEZhT3qayjYMQOb6bt0fJqnZa1+oXVe01DgM9xat+qdvifDPOs5RwcwTKyWhvALcXONf+7kSgAp7MgA0q5kWf9inalv" ..
	"WKv5jlnstTpO29X7qd4YFw/zRgjl7QYM/sSODRZUKHi+I5efjGW/3J/KsA0YzlIlJZpkOhd4naF6aWYmSe9m8F3H5oeaXnmx/u2N" ..
	"8ZW1HsIHfh2PFUAOmLI40o+oy1ID4fiegEjxCy0QN1yPLfXgrV40I5WXLc2QYBv6x6D76LH3rBArfE2RsI2xYRCnlnS9d5HfPPdq" ..
	"X8DVmId2Nl3xa6X7Pue5gRWWoqCxAF8ZzoF8sh5LouVORTTr4W/cBcCkxUA4hDer3fMi1oNE5gpruPmi1r7zji5YfKZcrSLYINnI" ..
	"TkE36kuSrHOA2wGZ1DbRe5XShUrKziN3shqOxZxuBF9EYc7vO1A2fcvDPYZb9GOCnt7fagvDctKNIT9CHsu5TwhnQ+vkW0EY5gCL" ..
	"nAABbSftYU/prHqowkZr+xIesU44yFUeYBPEEVvrWUV8JqQINIaGvrYINxZw1gs7uNXOWe8z3/xd/8FKptbMFjT9wQuf/uE/NZxH" ..
	"zmghIwOYBWIpVVuoNCSWXuMzhcXZvYvx+rm92XIHgwB6z96X1zICxjtsnMBAOA2MeFDYMSOSu31GW/R3G9Em9r+4+QO3wZo5jFPp" ..
	"wlC+o2fCoUwQbUkEpqXY40YO3twXG+A+/ymBw/Hp9ksIc4mn5SVKTTNqGHFlupCAk33wdg8u1IX8x5ZEImMSZtQHQ/mqDeFI5/nG" ..
	"4Py3YbbOD2Aa23sDW5Ig+Nm+JvwI5gYc0VoT605IvDl6q7wU6Yhw1g/L/S4VFBHhIR5EQyWjxZ1ByEdgE+xd+9p8cg0EXDB5Ez8b" ..
	"cDCLAzX6j7aro5IiuYvWah2pa/zyHNFbX/Cn4HIJk70ZmlrF3NZmLukpH0lg8LUMFg+UMYSa72HL2Z3X6epSgVnfZxqsxXo5RkEU" ..
	"FL8AeJYIHyDSAMrxhZqNjMezlzyxh8M0sf2HWcjX/oRtR4v0Ba/eUA7FW5mJdb3CL96elk7wd2piWMdvj/IXN2UeoTb3+PaTqQz6" ..
	"9pXCHNi3YtEFtSL9/EzAGV4fi44red7W6ZBoIdbJpa79xOYjny8eywX2/qG9NQ7bnplRkgKhdPJz/J6E0SdVSg2R87B3xte4ZzQ4" ..
	"tu+9z9w93C8WVO8oiRvG/FFQsrgFhkKxu1YIuOZc0YTkFUBV61fFRHaqiHSQd6IPyPFuVhOaqVEnUBuhwO70AzgoSN9UMkPsJt6Z" ..
	"x9IRJ8Pk0fTHnHO2CLIGgcqY8tQeAlSqP5pPMoSRJMrj+HDZUf95XfX/sUoCRq3vo8rTI7omHErsUKYvNEL4+k03e84weImeyw9N" ..
	"K5xmox7TkxLcDrw+EuOKOZQiZAHi1SY6nH5uQfB+fqSYPd2g7nJX/Opb8Ur6ntkx7rHHtbNHU0rcaXNrniRvojgrRl9PFPTeIZcH" ..
	"fqFLBdI/tHhrFN5ZurDeg+6uYF1/ypHjdh0RtKFw9C6gI9P6aMhTV2uemgr9xW8JCz0qk09G40v5HeTA5AVD6ZTy1oauplNkQOAp" ..
	"Ll2TFieT0tJHrmUF0i/KxCMufduXyB3mXIeHTFQLlAPFxtHYT+tgG0SRotNG+Ky7MSBa+HDib0EsaDFgmGMyGBXKYflWIhPxWaO1" ..
	"O3MpA0FD7sNT/Z03Z29ReZXsxIrIvSSZHYDGn1F6fye4/xIEC5GPH+LS9947TXDgPT0aTDFTlXLqGhThFeyGeiQX3PnjcHeaZlWK" ..
	"/sl765b12f+pMiCXeH0d8a+OvpXH3rpywL/7bhT3imFN4GCHzUKB6UspHP5nWDtckKK3eCc1NJhrho/Q6Lxki7kILUkccO4zqwNS" ..
	"EGBK5Tn/MDoNFoONvLc7OdGhAM01Dr/rNkonySUQn7o3OxmwkN+vLVWCSHcjLJH7sYjWEjFdnEm1bmlypNdwYW01rEwuIN8L1GBA" ..
	"+xGqI0y5yOphdgNSQg0q1m8rGVqQnTeKTxFVPraUNkPPfxrJe627+7NeJAuhd3e5Nveq1KjbV8Gv95IYYa15XBoOZxxxg6rhTkJ4" ..
	"1PXGog9d/JeiW7C1Ny9r+Yi+0gJnOf2ZkfIZ8sTY/1L4ytpZZJoPtC4+L4dPvHLBjeXBNDOdtM40pFKPFCXQ1/blprYX1aLDh7aF" ..
	"XIMfD8XFeDva3+DNGOrzH5/AsCcymOD2v3A1Ck4TCxrWVry4YGmz2uRh2vurIZ7jbjlDM50fpPAVqtNrmWn/wrb5ZIJAj/LpppCB" ..
	"XzhvDr3r8jFy23tUlzX0J/Yi3GAE3KAh+4laEZQsxHJ9lSn8xtDxEIsiTrzHYUgPBWiZ4WtrLMYkCweKgpbiPq23CicjME1yjgOV" ..
	"s8Je5ScER2NLNVEL1pEmQXsfVgYSe2/Xpg1BZ342ZHbUimRXvopToh/YMsnUqDijaCBuUbbpuBD/bVEhJ6rQrPEeVDyokfq3JvEo" ..
	"QnX3T7PTtAdObTt33UOkfP6n0takuIfByizy5S5Ri+2KcXRRjCE4Lj5DdV98UZvjuEi3bBsiy3p2JQb/1UCkJCRdRGbGFQcOAK9B" ..
	"Tap+EqJHpNA5iyvZvW/k142VCCqX6OEYFgR0h5z5o/33gu23NdWq4HUcEbOTt7IAaI3tOLowF2W5gnPauFYihF4fTk0dHkUstjeK" ..
	"Uh9sfPIccbShFuk1WRxiD8upYsZlYcb5AK4ZEeLErpUiuAD2d/NwIzwGWvf+ogWkp6nax0KiVMdMBNrpqN0uDCld6LsDNOrOXPEj" ..
	""
local PAYLOAD_P5 =
	"j74zoL2beBWMYcGO18xw6lLDd3Dvr7O10EidoLjufv71B2UOga3KHX/RtVB48WkXPI/Jz34pxaRJoQ4uSWKWq6Xc/1vmmiWhnxWK" ..
	"sBXJFx9b5MzkHHiRWX4w8yRz3mkw7E4ViFPt1jrnhsrgOCuDsq8Qp2LwyjtpVxE+iSgWvnM+fLiWhE+Eo5DDJeMrrU5qmmcC4c2o" ..
	"jUgJjd+6Jw0F969GWrMHUVYa3KLJbMZnduLZM6vIoyXqgLrmy0ns2e5YR9EYeavL5Ta34wxWRsf2H6f6dGj6mgUcTQ3BKwWy8alH" ..
	"NOwbiiZRSotlbijeE5Dnhpfa/us2zPd5ifXDndJ5D3xv2udZxuEkhGJbCZLdSYZ8/QRioPpeXvHTPnAzlIMvHn6vqiCGzsgZMpQx" ..
	"kUm3Ldv6vVJ4G7XdxjIiowKeuYDUwmuXMXAh6m5e3xEW8YfP8XVAN58oqwz4oH4WqygdOhW9E0jBXU3ddArPnwm/y3bH8CvPQWUp" ..
	"S0A8tWJKcvgPKHkv/DrU617niJ8l7Naf+t6UwjF9qxStf1sdDNaE2KJCGzUjUpLG7xkL7ksUQvNTsFXvodPYqrqqtT5xjDQbI6UA" ..
	"yuCSfX+yP61WTWk2wCyEtx1w4rJ0D29/K7NzV44qekdzrMjImBVrpoMuvEaONPuStui9Dc40WywN0WHJS0RcLrnz5meVXZbx0zmZ" ..
	"SVgLU4UGOaJI6fzJJ7qbutjpHuVFvispcy3eMEj2Wtf9DWJleH4v+tyHgJHiIoq7mRNHNkgW295oHZ+noU1zci/3crJp8rQ6vXVo" ..
	"3R812qvH7MCk70a8w9Xia+zzJdUg4spn7Uu2oGc5rNSo3L3jc/hnCj+ZfXFQ6jrcD8t3T+2IS/XzuUTG5LxS0QtQ8dK/jcolXr41" ..
	"cxr++4ldDzASv0yg+3bZuxJf8ovY4f4KncRXrPshGCY+qHhBw4YHVHKjs9joreFpKatJ2p8D4tqply48b2HOuCqYx5fzxOYqGbF7" ..
	"bUK+iZDEQ+HX4tLJyrxgIcd375s4yW1/+b1UL1Bqvi2ahS+NrM8AzQm6/7H1ObIA7GjTbx3uBCViPA9OMn8slv1+Iw/VojoRZ4wO" ..
	"R9cVC9ljhhXbldcvdMeR63Yd03JUKot1kLn+FLwof6snDYJBiKWuYTUX/0fdxCIQZmzAExrGBRSiAKlBgc4DRNGXMQB0156DjbEg" ..
	"bP5GMu5DIY0eyu/MhzWATA+3vj52gLW788C0iYoqK+DSB5oMatKWUl7yLvXiHFpBiD0+8vliaNe744EosjTE5cHLIL9MQLbFVSHu" ..
	"Wws6rtV6dSUbptsZfE+x3hYOWKnPfzYi4NEJDi3NqG+mHX8kpfZeRtWkJoee5GMWKo0/h8lzkbVb2H1bWUZiD6j9hhcvs1rt62Fc" ..
	"hcIDhvyGvV7YxB75HwHTBOufeX/QM6xJKqjNjH+xkw4tCH6V0+SB7Ba5kq1DtGYAo2E33mIy7XiG66x6xpQ0ZISUUD/zqz4w9sjM" ..
	"MUFMOKsee/qSz2ayUXyx3a9fvU3DbNxYWHMImnFUHyW0XqlcrhiiGGBzB5LmZExKdni565romy2y+tz5UTsA+ymbLAmk7jIzKiGB" ..
	"/Jj37Rt4ImD6sgQgJk2lvejE2WpOxDC3G5T5+e5wOm2lgws2KzNTqL7vUkXfadY3n11SAvpspSKHipRdktIUzEU/RxbHw/Whcf09" ..
	"+OaVLTLAHzoC8nkABjX0zN2haduy3sEWsOr68Kz+Ihcsa4TV0ZEGrabAbRkzXExhWtOS4rfX2H3DcAH+TAfwdwhWlXk86wLmIZcr" ..
	"5jzzSn1i3KpG5feRwTs+wOGcmZaQgr7+mIMhsqqyI4jtrJawY+jKZIF+1XNwNtJiETJOdJ1fa9FjJUxinDhfrwWZZoo+PrvEMU2A" ..
	"sQDztlLtCQ4EfjW8Ch4pPclTgvQRfa/mBJPSO9l4hp/DWi8DtremlNyQSuynVQyY3YNddi0dmjwWed2gS03IhrlJ/QIoU+iGjJh5" ..
	"Qy1y7iL6fiFWUl3uZwfLjVnZqOI2NMptVisJ7iT2jK7xT3Vj5bpoSfj12zYGd0e56a3pEntnlgGL82siy9YnIIqaPKVnNrSsMDkY" ..
	"1Bh2h379Baf9eLABfcAIZbRGvCgXYFs4KE08f9WEXNJrD3pboqVNY/fptMKlz+IJZsKQOzNoKbnw0x8GyRWXyQ0eah3FWAghPCJg" ..
	"MDtgMLYmM6r7LHuHggw5+xxXMK6kni/++9d3mx6C/IoVmwTdehtVsawDsx7sjWmd6v/o5OfAMdLHkPip/6X2E0Khvk8vY8udSbzT" ..
	"9BiSGq6ev1eam5TbdbZkzJZrOe3HofwvA3Q/701tA/+E2WhMXP+TqIjflgCClDspqVsBbjP9pNzNBcSzAeQk4khfsUAq4o92RQYX" ..
	"oF3rbdtA1CGv/sY8rtXf9+v1Mqx/nZxH8CSFq6imj4fi4tw3DQp5fKy1q48yIL5Fz9Wd2m9GyWCAIscLq5q9qkh+hUk8QEjrZ/YE" ..
	"d/N74HQstY1y53e6eiM69HdcoKPQwz6XxoNz5rDwhbSj2vXSYGlqZYuGSCYMabGcdeYkbxwEIcxr1iujhbiVe8oyYA1k7zyBJPjz" ..
	"IH1uxCPBKlBeG5a2VQZ98J6HtcnhW/+kwtIvvaE1J9m19rWD/BleR1JrMPCGSl6xQJyrIdHKwQE7vcaT0EO3DhF3GuL+6MJkGUvN" ..
	"cDhnkYpNUS6oqkOV9tLf3gKElG+9TlWvOt+Os/PSQH5gl7k3RljlK2oMrWv4UBag6pN6906zVAA0DhczdKaQUcwrZNzheGbD03zS" ..
	"gtNWdgAUNWAtlHSXYnWCmC8epH9T1FNFEiZXI10xsNRid5ZQqE9mcZ46jJ4WYk1jsuNXhu3DALeAHyrReoM7kgpHVArCylObh8Pf" ..
	"sgT2jYDq1shhP1d+PS4C5Ia64eOb8or/fyJhLD9E088eloDtVMYjs51QESq5vA+df0UJrqNaAjcKvL/V887BB7zQF9H5alCh1smG" ..
	"k8jANY78uMJIz2Kquw/c78aTdNouHn64Ic1cxBUcdUeXwGtJCBlfOKY3HWxeZ0WFqu74bvtM4on/Bdlq7BIJmssiejkxrazOFRQO" ..
	"aEpS5rRz1nVUr0LLW6iKdCrzPrHyYwjuaod8s5yrB4AFcJT/lgzQA7OqBd/vOUFdzIw55YAiCqUpC+vG1evYJoC+TBTV7HwH+vxB" ..
	"SJNbVbmkK/lQNZfh6XooL75r4hIZykTfO/TWmGjFDeRdSAwZC9QleZm6CZucOIota2HSr5dE/dC+WU8U+pDqiZtJM+OFHx/ReqNi" ..
	"uA1DfwunjlkMxanvzffbSZZd6Yxh/rajLQNXNuopO3f2ZgdmoRRk5c6F29Vlkh2d5IB2AcCu7SMFDyw4BglcS+EY6hjqKHHGcM6l" ..
	"tyB1BBvSvlFLQuUW4JjTry3nuhon/cgz3VC30PJdLHoBoN8vOxw/kaYmNZ17ZLkZI5BhC+WfJiKm1NcnZYsXm22pmhhC0p0kwEL2" ..
	"7iABaYLhsMGwsGcplNiiQbEK8vW//3j/CbWSCCUQ+yJL+EtG0LNsssou54K0iv5U8EWcj8jG0fHgINl8l+RKshWjFfHlZS6coqUo" ..
	"1NNPbjV9/cqs6BFWa2PqMQSeEWQEj7vpOmxaoOw4vaceW5Lzjrs4i8H1cSQ/bxLkqNXTOTJDKQHkfRHwUe2zGRZxOeSFKfVKMefl" ..
	"8n8cCkhnWgM3AaY+jVMl3wh4QFNnh1SBSybhdXsCvKWwgFy7qi7uSWwz+Geoa6GmqYy7yeJ4icHMCCldL/UA4QJIMW6qK/SLOF6o" ..
	"YVLPsZYd3TSdtMNnuLOe0hFNanQ/5n7bsyT5PW/vBz+qoGEycDaNJ+07taQq1P00mU9m/SrJRTxr8EX48LnTB9k/bw08Tqi2koir" ..
	"ZOQUGZAALV0MORb4rchy4l2J7PKcSAph/lto/TfDY2Kprj3LsBHYwp3uXbRN/vbdoJieN8iH2xGT8mpzQrT2zZ5A5VzbRijfMm8w" ..
	"YSZqE3ib6fgmZj4vU/lP3QvEaU9rsui7v6F2Y6j4Vb48fgauJ/VH13rIpJq3RJXC0tlLXKGMBoUKriQxeUzbMlABAJtKNhd2GnMd" ..
	"2ZSqclAvp4znEt2O8wIXYhqh0nAjRXIG9XQB4Rm1Q/sMASRotSMptWZr7g23PS2ZDM3uQ1ACcYJYK0ug1LEQvf9LATdevSOJ+32c" ..
	"yjoarowmzZEvQ0nylKtJ7He4QwFgr9TGqsXbOJWCEvHXcsaQuwdIIrkWjQJcYKtcbmY1hOX+QELjJuMT3E67Go4rHAye3gc0dW/N" ..
	"t0Js1e4gihXNNSc+iBF2UuCQqfdD6v6eCF7Fmz3CgYH+bJP9qKfvChaw0rM5FNj5W1jbnRTCbmvC0oVqBfHD4AiGS66yogddHofc" ..
	"A6Js3zGesmju2Cmr/xqq2PDnCXyNzloSs3c5NSFmudCVgwWuRoAYzYlHCCFzK0yrH+xyRrC2JYA+2iJuufA/m+3y2feQBL02WCFl" ..
	"gJT87kQJPbJUn2RHPcH9cba1mmWL7eHa/5nlcOyztmCexuOLvqp16FEvbRzNoreTqG12pLa3q/5vIqCt1jJydTlT+nQJkKMVG7Y/" ..
	"5jYT1Ihh25yJZ3S514ig+jD6z4ERiSoGBD6pEGZUXrfAo3ZJbJc3kgbpE21/FTFxLDLk8EQaHd83ZBJKxsjJlULtIu84qZeQnck9" ..
	"tA8Nz9j4nyo47cB9dJ1SBYM/JdAUOnyIWtxSQmc/IfpvvjkINc9/4ZRKLHS5JOfoE0MH1iQh/1wX8lnhTo3l2DSyTV7RM8qGqUuM" ..
	"XIPlcMc3ik+Upsx6yi2vvZzrOp4fQKRUQRn+9c8TBZYisGz0cHrpAPPSQ2u0V1IH5ulr5vOkhj4z84ufis93DxMwsv9ivMGSZ69H" ..
	"HuDFlzJNbsn57Ei+rPMleKylIP1tE6aJMGarPgCU45f4zX0hLvqR1TnT7aaYiqo8Q5vR4SS86b/cj9g7c47JpUKOGmWmsc6026Gy" ..
	"/09dum2uttgThl/hYw2TqgkCkiUUDLEV9+GNDtaqcBFhDlzNfdbFOmK3btqQKyFqFRa+GE/3/lWkuuYgjkE6KAq2l+Shf0VbA4+M" ..
	"DpYmdiVsdb6weoboqJUIKJepqh4ZHFzrAWZY/sSU0G4ir+sRamea8iwOLIhncrtwb3Hm7gdFnATURHOOOLxxnibSOtJ7mqwRJxn4" ..
	"huDKogauQaYbWmOQfc5NheUeBRAJ4bnQx4QC9Dt1JBuafWXTcyg2BnEWfrSVEqbCA4Erz/+1CHqsNzIpEkciPbsu6UkFUWAqJilC" ..
	"RIW6MZ0bUKtYmSD5+UeNReOjZeYOHbyAjy5aez4UU1FBBV+1JqiW5SzH0+1ub1xvreFoCwL9SQoz4ADQfu3WwJDd2LKORwoNUfno" ..
	"8RK92Izt9UDFxe6InUGY5OW3NSeLBnTxrlpHoVsMdd34FZLJHWXd1qrZ94cbPpy2Aaw3eev5Z4prgo32ZjeC9DfityhMGWXA6y+V" ..
	"y2amDse8x62UhyTaCGM71H6xr3FkxP9FQPOn+zNRp6etz1nV+asVN0J6f+sxc0XiW8SPc6CE7PzJ2vFbILfjhYCPpwDMV5HLX/a/" ..
	"puBbYES9GqMrZ94Lk5QCB4v3RF6Rh4a/iRDYOn6VyS2QUgHShLuYaz7gx4t4EwnqInaLMdU1MlO1yAUQbelC4AC5MFNiQktiFXiQ" ..
	"ljqjormU1C4U8qa5yPVsV6mQAPZcihDkTncifC+dQu1noDl0DB0gHFhd0KuvAIsMy0E5vW5HS6g0CP80/4cTE0UGj7lEbMepPZZa" ..
	"Z92xeu8EDHSS8Tb2xPEDCQNOw/mnnIyZiPf6PUDpa7+qNBUoxB3dO1I/4OjTjMH8eHf2Y0cVyIJu3Npb3+uaJJEx2xrIIWnb1bmv" ..
	"zkx8Q2bhqnZKc+bFp98shNLeTNvieEerCnVEcNWgh9U/iBp5WBxSDgBqjIhkuI6MmwoZbRh0EnmXW3CZFvW3NPakKtVE7yr6RLh2" ..
	""
local PAYLOAD_P6 =
	"qMzevHdCDsX1wfIMXyqrun5/KHFJpVEaW92ZxNqenyacoJ6hg4WHP+SsHC+WYsvpiv2UQg9KmZqJx0ox2+bRN7j3am4SBnXWUyQO" ..
	"eknlKxz52M4eFEagmoiVDqwzbAInibhDth0hA7bcVBTZEo0BXvkY+Bu5LjRspMSBZdwnG/yrk1tDJIx5qOqSdcPd+yRzEh8P+kdK" ..
	"duK7RtiCVbUOSFEGY7fC9nYBk2IZoH+xBJt/xeIM5w5Up9+QDDzAJvYgGPXPAzwZ50/SJUZuqNGj/UdIBlJ4uHsoPw/n1Ur/9cQv" ..
	"54lbYU4yhc5s4YFfStVUwKfng0bTKu8Thn2k4Jmzq/uhABIT3zE1MHOpzNt0R3fv4OeqOFE++1PuCkO7vUOoE66F0iz8tqJVvlKk" ..
	"NEUNsT/wfQ2wHFxTkeVoxllOvkujeA/KMHSiIZKhZt5i0NvwsPYPhc/jFmCqx2JFBNtNiFV/aTjCqIBAl2dNwXwVMesIw0mV9N8g" ..
	"gqqys6JYmswa2GahpFGdxcuIhpyk9A4qm0/oe/q4ORHcoFzsOKwPsRfop+6jC7B37fw4dY+WtDG6ax5rOTFFnxNmRDOmNICQ3jPg" ..
	"cE1LVZ8cJ2BDCJYbyT2PguTlGMEl5bZH2x/WLbXtgMdgAnHcdHHa65UyvEFqaHN2YqrTePe0vMWUjSSbEHTGkEI5QBsNQLqmzWTx" ..
	"CZFKRSlPjM3WlnCTaabI23n/MDIlour+NY302gIHg0JkmgNOO9q4StfhiVisz9lSXrh0RmDLwtTnS0hdPOsn9lXlAymBqmUdPjF5" ..
	"v44IzUxPWDTqf8Fb/2E12qw3w23VFkuX38N7Yvuf2oW6aUAT60fviIT7lVkAopPUVO20brDSucbixpt+joYOJMa/KZpDYhCjP2xI" ..
	"PWe97vcarh839X9WVvCklclRMION9mWTGOw6+36MfvPRYaAGfk/lq7hwW8XAC+h8LqAVoizPAOfkyDrqeDIF3VwzkT0jSk2vcFwX" ..
	"YeFrM0JTRNhpp66PdSsMArDS47z28f7jD6rFOxl/RS3tse8jr5rCtS9CwkI+uuPDN1sCwfcKQ0Nu1ayUQz0ID4dSbHYF28eTEkYP" ..
	"bwL+34J8+p+6dKNOUcQckehX7MTjD8ooKlTGlU46ftwKO11MJjoZjW/Ef9b4TrA+hm+1m/Wp7z/zmMD25KYV7RzKB/1sKl8PvFO0" ..
	"2Wom1X6EErZhoiX6KGgsXchJ7VxDAURZvAr5rQaJEK+OBXugrtY6hCPzNgvS39FnDPI+4GTgBj5rZF5q8afoVRCq1gE5UAV5rqYJ" ..
	"SYx4O8cAxXhBzXNYZ8KwsnZSWWWd5nR++5W5hUbZSqGd1m4Pg6fM45AujgqzRkSldeuokg8cjZtkNk75jwOmVnpjCpjMtLUpLZfE" ..
	"DYtx/g1Uy3AsaJHW/KeL1HNXPSxXnqrftiWmwzgl7HiAoMC6iG6Cfp7l6AcqzypR7mG15KBbqNJmY734bBfJA+lP/OkaJlNKMPqU" ..
	"Pusp0FnWcL6ztSx0AndBEXMfWrY2BcLfEK9zlhuVlTEP7P5kH4p16g4oghUkS4kUB7oDcIYXxJ0QCIU6z4LtB9XhZ0FElyM2NhgO" ..
	"IyfsifXAMLeaUDIgmnvSSZd4G8HotLL8SloVf8Is0+CTY9LD+hT3RaO9X/fR31qCyGvKKbo2bWWWmZdZacBDHUOw9KCC7IqnCjhb" ..
	"1DjUpLjeNoIHa5OOVHBMEEiliav4SXil1krN8y3g6CPu8pSJN5wOlagfR2Re/tI1YQrqayY7pDXR/+3T3Sp+swid9Tikw0oMVytd" ..
	"WTUAElHxOmQoGe1qoYhMf6bzFI3PpYK/6JUmqsUls50TqwlRjDDzeF3x1vr0YMMS9obtFELdAtv4I7NdF3Ks/O6ecGn8E4EbgfO+" ..
	"iSDvfpUWrFpHrmVBfS+lv9Ad036zta+rBtLhBNlGkJ8T7MuZrH3GkQRuDD5NbpEjtRKdvnngJUDJo/nK02sXR7bb7GIEok9AtCnU" ..
	"GHnzu9VHg6/unaROuu7orXOhGh65FmZF3LtBcRflf60sgNfeIscba1OF/r1Bcq2x9EvJzswk/eVyQsItHiSguDfRck9ALMuXLQS6" ..
	"0EhTeZQe4XlK7LFwVsnNmwscpIKR9OBlTa6gA13aw+FmSccM8+KIjKwtnv/kHcaD0c5N9TPiWOSq1KELNsZ1tGQpCabxjMnWJKeO" ..
	"qzUqgETS1QpGabSzhib5J8E32OS70wmL2P4HAaV/mIHVWPXxBl+wiEK+ulcRiTK4inYjEiJ5PKfFMd6QW5hwK2psr14FyTB9Ur6/" ..
	"IojZml/9NcNjg7CIK6vnq8dp+iNKiBOgg5SgvnUmZhrZ7qF8kZzdTOKnpz9ck+W6JNRYvbglYIo8N7Ux+CqSfCYX1Z7RRJ6G925c" ..
	"a9YW2zjYvVaPK877QRPZwrkz8MGkn8Kqk+HI7/bu53WJkSGfxB/C6xkDNYLqOIv2eOdkwha++2QJlV3OJsW3W6zNS+cNqz6wbm6x" ..
	"sYh43K5ESe3n47qg0Bt6ZXORcsoOg2KVMNkCx8LaNlnO5FmUq03BgpA8o11XLfxm8pBvzlBlUlHerM/Y9TGBl/7ItR8R7OzK3SqH" ..
	"NY5o2oxFUXM2lan+b7f0Hp0MfiZJpp/YbQ0nz++UNtewNHWIybqo4ZwrcNMmK6WVquxLNkS9IpdYKQkBKan6+estROImwMuvLDxY" ..
	"774Bt6b0KuyRhmBGzFJzensFSOwIJBbH+2vr4ZXb59PgyiWFMca0t7e+KQTVJZsNBpBCwqMqlGWKuWv7Sg406+3Bz8WwSvSHT9Eg" ..
	"GOSenXvkc8Sb4ITYN4nRCkqW0OVuT2SS8IE1RBk9ogPU6rdaVEkymxLDdVSYJEwmAPa0dMKk3D5XeDPxUM07LVNXoo7bouQ0kxhe" ..
	"FMHWXBgsMBmfuucK4FWaZv8UY+2bgPGSe7aBCyiYVA1BkV8di1iA2mIlrNY+BSwE9H1ahQLPagRHQbt/ADTlLONUcfSXEpCx4SPw" ..
	"1D6TLBiPzqvpM9IlOizlG/zrXWIFMmlZ9XodriMDABwAJMkvuQuwk+uyCwHLv9Y/aic5KQBbvB24/qy1nk2Ql4Wl/eGWmwRFnJ35" ..
	"90Hrjek+IjyqPNfN8Ec6sDvx5LErZXYwgeX1av07v3CGROzmm2Nh7RSag8YlaMDfuxuefeta7KGeIlanUaRC0oem1ZcPuh96PpaJ" ..
	"jXvMCCjYGo6PYf85Nz/Tu00jbChfCZdJcDWj/ogzAsRHfZjeUBzKkDZ5CLq13LDAB8whW7Q/qaf5w8q0lv6ki90UXNC+E8pJ2DSF" ..
	"JZOcBbRVOl2xC/9uUtcpnDJYx4upUT8sTL4Ob8FZG4nzRX27fpp9wucAmjrF7Hxq4Qk+QFvxOeGh+BzVeeoY1ATi1b5eK3RdO/aj" ..
	"aq5Y2uUYa7HnztdGpVetxvmxzHUJ1pGpnwriEaWjI06+EPy1e7Dl/5qc+rQKhwYn+PWgVlj07aith7eJEwk1vozseT6abgrynlVE" ..
	"dqbgrmcxecan1J3xF9aZPQj7PmLORLCEmN7u2AYAYK1MH0Akkbw+6Ths3pLUkrBVHcD4pC3QyixzS9i1zKKkc127ktycOWwh2hGz" ..
	"eNd23aEeXWi0/rE/L7sjmuamz6ioPN4R1dXsqDURCHCVA4m5PTgjfzAfiuds1dYqiCh6T/8Ettd2L2fWnt24ZJZTaQ5YoMSKH/FI" ..
	"LgpEbY4qL9B5XqHTETqbhuTuWlc5E/EFe2UZNYHsLMDbvCBS0aKyJPvGyj423GWuJTD6RpaGJcSFQOtXrlM2MIx9IQagrIL4Jq3s" ..
	"ZUqASpIpXfHuHzs+aCLisJPdk39UQNjPPV5i6FXAgR8M0DNXMbmWcZNCdryyQBI90yOWLCw9C5LQ+JZi530ZEQeBSAhYRSz39d9T" ..
	"Zwke4U/CV3O1XoptmWJ/ZBDeeJ86JYSFi/aCLxgMBFxMir1zC+CpJzCUI/itIY3InhFBK9cQdwdArQk/aHD1FMoQePGOlJobapnS" ..
	"mYNJMI8Q1ZBLiVKQ6GNJUK7U+DhA6NidAPzODqsQzTd0BTbyUcJG0mlaBF3+5OP/Df8yP2RRDPJe2Hdgb7lgSvl5NQ2aLST6mbAA" ..
	"X7xVKRMoBshFKF1JNJhZLu4SwScF4DOWEtOWj72knNRO/q+++JWtLEjw3VpW0qOg0lWTzIZiIw8CbQbgMqi/UNPQThHgYEX45yxQ" ..
	"TUEiuXcaQ2y4GY6btt2kyU7dJXOlWtLQLt+N7vulEKtLe1U50YDUM0lQOk78oQ3ouckahb+BhYv4MEoiP12eoyVnxbiFft7lzGrj" ..
	"JSpzwdjWp5oCCGE1OtNrb+NL2qsuvN8VQHg5K0a1SyMSEnJzTsEb1WY4ia3S6s9m993Qgp203uvaC1Xx6aCpaGpDaD0ZXyRxrKot" ..
	"ZmA4ywjIX5KRF/gvGtwF+HyeHweElHsYUhNhi5UGmdtE/ndsiyt74Wxak9OGOnGfE6k6SXR3Avxuv+Jr6D53f3sBpb4K5SDnzG65" ..
	"6RNaNuIcy3rrunNEM37anIOcMuZ1Oi9hyfL1DodKjWFbwNqduK/hbP/dwkr+wGFWg4wV6cL42s71RS6T8vX8ilHZmdkAaKfT88XP" ..
	"Zcu1fZ7PcVraMNHxmN6cPjt0A+nXtR+ArgjOvvZM5ep77ZKzixq1RU9R5RCCIiyFCtIiI6S9FRp4QCYcp8b0leOSRMOhsc1T8CHe" ..
	"lPTtlzlQnH5OPaf6Pfad1i3prvlO7E69P477NZdCyANrI3LDpkUxpAoYrXgNc1WrTOcpv4JjYCKX9suQFoAf+jWgpUKp/S634fTU" ..
	"Fs+wsRZ9dAJLOD/qau/4bEmC0BLqcD/ZTS/u1R0dKCMykJvp9aYMx+wR/zIrWDwN5KWHV8wwxjr+X6LAzS+1d8KCVx+eummEFD0f" ..
	"MDwfNMlTzCbxcAGlQxqK9zsGNhzFZITVaTzzmkAyIvgkrdva91sr/S45BA475Nj9Uj6OdOQBd4rO7apDYUfyvEyFxPdtRE/xa1lT" ..
	"wKyP53Z+ho9MyZOqg/1CEjXxC3QXiUrOoj4RsQTsXhXqXvHIhYlDmDOhOzKoB+uffKinawZwJk91IlVg4dgUWXGII+0uK7fEV6kC" ..
	"jXxHivHu9N5uhqobHIohCxYtlLC+1+E+plKemYTTkAd2jOOKEGO2cteF9szob+fii400kD/pO2eCg5dcotPG8dvq0XlshBCagJhn" ..
	"IsndMuRYllQV2NcFPcyO7IsoKgdTJ674RE2bHt/akbIU4QPxrV9cmE3QDubML5so/K03VebY3b5+gRQA6vwmgPZThEmrCooJzAGQ" ..
	"ZquYULcRwf5M155qynnqsvQmSxNYzIRqFdFv7scblqXG1RFfop8Mpu32nszH0b5RIEMD1DY7d+0b+IZlDKFCIi5+fYVNpgNcbAVy" ..
	"SrhpJC+5RG2YZa/rCqAb7lYbXfKVX1E2shivXK1r1t2Q6htDTVtOerLeXsurkLu62/mgJwqqg7fjSc7yvpv67pc52iMhCPg31T66" ..
	"KoFCnIKe4boT8BnVysMVPBHfEl/c9SXji9XoFghn0aivNsYJWd9yFFWRElAa48Dm1M+Rrra59FkbmTru+Zyz9O3A6VgiMcPXndhf" ..
	"X3M1V6WOx3cW6/Nevd6xW5mQo86Q0HW/I3UVVd2dHTNwena0rt72bYey8VEfsH9RJFbKZJy0YdJzlAFFMTC4sZ90BHWyJcSsg0F8" ..
	"9oASITh6kvP/bnfSJfYoXE0Kyo2o9GCExYFa+9hlWOwoWEXgqiSdiLinBNok+8R2aYyunx4Xg4pQiGfP4UR7nA1xajXNcWVbceq0" ..
	"v8N/X/BaBflDgTSz4S6yRRgyDz2Xcp0kFw6olGfvGftAYeoSbMBCGpxprMCHBsgVZDhb9CfMVzS+joMb72xdr5TSsMLgtdDtuv5l" ..
	"PEpshOD8fmRJGtPe3MQGvF4jzXHdCwJdRdJaNjxnUSbvZGgsnWtkRKwUaQb5eS+LdDGa4wBrCOeeyxi5lvq+5zbol2UTHVJbB0AF" ..
	""
local PAYLOAD_P7 =
	"3pPSGluR9FvfO0T4Ch8YmtZVviDtDh0t6ZgEvcq6jvfgnYXhtbYPpMbKDn7tjxWL5Ty4XD2wijyVsN9sdRl+T8uu1fz8r3cqVtvm" ..
	"8TGWBmA5R5m86+ZswCPeH+S9vlqVQ1N1SgEDlIbSTdQ++fHSSE7WKF/YSscR0wt3+q+1fAdhZ1X5OnmgR8YC9ViOY6W/LLdcz8zD" ..
	"a8lid+6OlvVVlefPFmRtpTcafyVmsyEsdIGNCjBgazw+/VpfFDDxDUKUc8bdxZ3pQVE51biRZW9q1utpMc1/DOipGj52WuhNDTWk" ..
	"E3JSobtjlekjY6z5TpDGdkBlQ4qitAq2+lcqnzd2BpTTr5ycyDFn4LKEgEiWoX//kFGCLAFpdxem5oX57aTauSpmju8YyiAZZKCj" ..
	"f6lZjD/IzKocFu6Ri59jiWLv59Nb1t8ZsWp9wT2geB0eA5Cpw8N0BQ+xoPv9n9bIlJlxY+Z8WiFjBPC3knlGLt8579b9jfeW3LJl" ..
	"bTXPbLn7UoX1lbciwXdCnl4N15H0YqvkHl7jKLcZ5qSF7yYSCTqMH67I0kTK+D0fNb5dm8KWWa/qqULwf87EH4XqNuad0jLZJjaB" ..
	"A+1RVx1XHCF+xrQBXGAXzKMFp0Z/84hhMce3sAy+orMukdcog5+9W87r3pEcI2fBsxhBreJlEZoYGuXlKNqISuVkuKscQwmQ0s0D" ..
	"MdqqVBU81xNlSxrOTov4ml6pWsSh9m11fzouHt57hd239HOmlQhP/oOIYufH1KnO0Y6EEprj0s2726YspQyJch90I2B9LmD9VUPo" ..
	"6vAtFiUVlfaIgEH0JBulpUALNVdXVWvm1pAgUk0xDfWz/OvRk96yzDguminFC++Ex0xop8Db01AC28HrIVQveMH4esJP/y+V8cff" ..
	"Ch/qo7M7LUUb+JlXmfldB6XJy8+ufm9KN5fEPk5uEfq2/u1YAFwUQfeZozx6XZiyyMC6+ourAUaTFRVPXJyZcqcZ7zS7Jg60CXoX" ..
	"iKAejkQnU9B6bAzfaaWBWJfj6r5Qvo3DGrW3MQEqNjQh3OEzzI5Dq1O/pyco9mAUimyrk/rSV2yJy6cv6VF3KL1g3PdDMfMw3txe" ..
	"5CfytMsM+u9shsN9wu0wiDDazTwWg0zQXbtKu9uJGsmKmSS+7iHeBWO5SQ5mSq60w3EexnFmEk4Ai6iX915c3JZfGQIvVOInqE0i" ..
	"ypLlBILGdO9ek7AHi6E72XjCYt07qET0uFwZl8UsglulyQgzn01YZF/KMEdkuRb15zzTLbaezcf1pGmWV4hAJhnu/vdy79urqpC4" ..
	"+cahMu6O02rK1zSxv+N//CQzQs7nPX2KSCEXy3D/FEsLF3hZG95hai7C8L/mnpJs6y8JeX2GesGW9di5DofRU8KUOol45fH/aMet" ..
	"bjW+FaRaEWGh+GwljnllOiITbNMONw29GHBjZla9ZNgCn1qF+0p1W8OhqF966us2UyfjJTCQ7OhS19wG3xqGlQTBJAdTuHNx9D2m" ..
	"4XV+o6pJALbAp3vA9nZFJIjdGDiO6Zg6R+xSeS/KZILnw4YhP3r/a0+qtg5J3iMgolvyXeg0Bd687sGWOUW00dXHDIIIuqQGJb62" ..
	"b5QZDtunvISG8bjwn8kuHb/VCmDqGG++cq6JJxE421tGGOYIfvFO8QCfBzoeM2usutB+0qNntvXRiOen4OpSkpZW0wm2etNQNiAV" ..
	"X4mRn3EKadAh6N123Hp7vNEt6lfzZeJOoqlHpUTF+otqZA+ryUhWc0zUHsogGAdht5PecmW10YRKxIR24nn7UBEKOsxv4xc6YWoV" ..
	"eG3Mz84z7auf2Zf1Xm6d4d4qvE6FrnfBRkK6WjXCzq/sha57zpp/Vf6/iN9Twk8Qgq7Ty5xs3y9hWTkO9vDqEs0uFrY4833cluGZ" ..
	"1O3QO3mls+0E2cq/3A4bEVejcGEehOHfaAkXSu6V26jiUZu1AzCPFBuaaZRt0ag6zDWNkbFMU1GB5Y93PyeXbiTGSwC+hYEOhq6V" ..
	"Sck96SUQWjXINTasMqeFoznsyUULP0SHUCrax9jQl3MWu1VRsElwWDcnazkgtLm83UUy4nL4EXO6TG+egHxtBR2DlRPR6BgJ4Bub" ..
	"j7EYPHecuY2vvMMH3u7J0lXc4H6KpOaSuk9N9T6vPjn+bHKjzzobG/aeNxoUSVPa4elRLbFteb4i/J+mwsEPIq7vh7feX3DcYtD0" ..
	"nKvrH40f5UkAnzIctNzuBSD3ewK9srGWkU3xaP5G9+jKTgYraAb7F08rT9ZgGUUO/BLETOvyEHctAsXs6XvyYNRULL8tronsn+5J" ..
	"LBsiHD0fwqKHWTnHg2Zzyg/rTK/PfSHJSArRsz0IKBKTAhFXecOk2sxCBsEQ1aZ21Fex7koMdkpttXxAhbrk05w4estEk13ds2+4" ..
	"kchBL05MKZQkv6/0q/71kiAi7H6eFgBBUZYIizd+p7d3TXdeI2rRbe/V1/T6JagNwn7dsTEblhZuoNo+SjGNKNqBumTkBy4Zr0uZ" ..
	"vzQJJ5fWHEMC7iP7QnG28YiP20OmrhkYb3uxv3m7ye5u2uWz24KyCYHw+sR/lKBZVwmcDaHi0qi53MmpHXxX22wZtSr172Tfw3aw" ..
	"qIXanExzbxV9dFNJeG93ZFQ7jCfc21S52InqgzvU9+oqPisFpquarbj2YAHnkg/AiXzUDygcGf6FD0iyJQ12I3A2r/TayQLi8hOH" ..
	"XeO69fWE68v/5Qm6uv7BXil5tfq/I2YqVK83IkidGEVzsZuKqhlNmEPmkhx2JCGp5+GRdX/0X8ZIbuFc4BVguK6E7l/fMUPmTiFJ" ..
	"5AK1XxHjh7f7+dy4wxzrOkU8M7+MKGjkAiA7dUggj7c/DWB7nHIahNeXO3jBxAwynKxaAxjDtgHln1WaoZD43YAOnkgRtYmZxBg+" ..
	"tvh6zEiDOl3UF2Sr7HUh8yVOEu43XDrQjKiLQmHd+5z/umZsUpcc54dJGtSXzcRwp4StJ9O7jIH2ecvKLp3rqADFLmZ7ZvMPZfBN" ..
	"3NswcOi8kpNmhIR1b4G/zTYMOESzkCzF9ieTNoyi+yCtHO3CUhDFRZoc/iyj1SwDsRYeYORavZU7430FjaheFdoNX6n8DPPAI8D/" ..
	"4KJWYHGVhPOleBjbJgHPo+P8YOFxDQr/RDSk9u0fcocd7EkCSSW13YnS3Y5A2eFLobRiQYUNhW6CgU6In5MI59NHY9jnSr08fYEN" ..
	"Jm0C3PZhbiVj5tX9OuissM7VxRCEzBG4TpwmBJfnrkb9d3OEyM+c3B7BaH7VSrLPeIXAQd2g8dzVRBHh4ULbsrdS9AY9IX0Jb2m/" ..
	"IPOHlTQAznlSPhpZPLJHefgZ7iQ6x9QVx8VE+LR3zif31RS4FLuiMUKpUEYq7DhA5GZzllo+SmFDBweEKPBqSWnXLjADWje6faUk" ..
	"r8UGJxl2EeSwgeTFTbiYu1rHEmPTubDxzBC1Ff99j8mQxMirUIIb3smTjwdHZMZ54HAZam/X/ZT3Hj7aQpXbiXvOQ78Fa2giZyFo" ..
	"ghs2xp/leoafQGA9Eo6cbsJo29qnS4zR0VrZTHMSTxCYb2NBpBIBW/gFq8HdVWuH4T422sHy/TEpXC6wR03tM/K6iRD2Ff1545rc" ..
	"FVTfMeFfT4RP8Wa0s0g8zZ9As7deQDipxiJFa0pSXAI5k6WXv2BK4ezfq9nL5VsH4G0vfMccHncivGaHuhfxGEzxhRUliF4UVA0o" ..
	"zAZ4Juc7K9Gj7wKffsm4T7rPwk7YgffMb9vizPHdDdoVtcwLlqEE3kUm2LnuqWGlKpf9eOgjyIG6gWQbzZV3pWYr2Io+LarOYEdY" ..
	"HfoZz4kKL/OYuulhBY2dGJ26OPSBefXEJ2mSmMZ91Fn7qk5GBpkHGPhLzsXZF7WDKGL5jNtAyba24F0qQ5Ja1GaYQx7MqYasBOdh" ..
	"NkpSCx664XMIZEkfr+MurYsopua+lBLt0um64CW1MA5xIDKSSR2Vt1rlZzumXVjntMLhg6ggO6icv8W9xQSH84BignvVaLD8Obh8" ..
	"FJ6+dW0yFKTfJBjUnbgyncH4xOMA21x3FMXLMLAL5FyEr9cezyjdmfeLoYnFpg27f2ok7Xs3zcLqGXarPWymzppSNtfEgn77Old2" ..
	"duD2cnoBOO9r9d/fePQQIjxt1znHc+fd2UgMJK8HtcjQdcBjFd+Yzb58v0cS2Thgkw9KDA6j9g9kSOjLeFgL9/Ht8wFA8DKmU1wZ" ..
	"oxzmQ1MT+vlcLdrRjh3/f/GV0SSVOcpH8hTZEd2Bga0VRCgweR75L1B+rDMjHJupHT7qEz+gWq8BsJThbc3RuNF4OJ6AVP1kd9QU" ..
	"F3ZVbriI9kvPt7PYgvg+v8q1QkbDbHTFSkIWQJl/6lDBL3SZyvc5jiiDaDD2AtcaWmxqrP07SBlIOaBkZkoGyg4w6MwRKgqiXlng" ..
	"o1xNR2YWcOnFZpb4wg9Hnar22BzmThJZbDWVZI/a1tcaCpGuohtcZpObAHxe3llwmx1uEgAI+8OHtg37heNjXa9MWmmxKW7rtzdF" ..
	"KejIXmgar5CH6QzY1U6aBQzjOuQgytNSfOz9GMJQFGcZh97+IEHkVsXBh8V+5/VHk8adhS4zLPAd+dYCT9TE/Tqrh9xLCTpc7XCY" ..
	"vBhvv7mlGsmjpzZGyXXifsZdl7ql6sraCcdzsYRPBk726t8Ox7QZxML+ozEpmNfZprum83i8e1G/xVOl4vViTzQHeZcTyo52r/w+" ..
	"SVYUfPhaFCllQCN5xuV7ZpSGHs1/lotdS3ijiso69TDpStMd+OUV9fYB06xHXdHGKhvKyrjRavx7XDOjnSkBU6vzx2tIeNAcwMgQ" ..
	"R9U+hPURUaoL94jTUyVDFDsU4ZRkdmPacZyM6wIxm1KIgP9JA/pCKiJOyOpuAgstm6bf8IKP4PBgBfcXU3qGGS8Tikd47goiLQlm" ..
	"pgIe+pjmmHuCSUrDqwTtQO2ctrrYFj2DpQ/xQolUD3zcWLLVqgtq54GDDB5W919DOebmrF6beVX68Jl5nJZfcchkEjlY5cwbpVoQ" ..
	"KRzXHadHblkr7fQy5Va1W41vnuM8blIOLmh7gLyNYivtLKlCo/FHczQn8ySgymZmJIUMFpumSuPKf4KHH9cVbSvIi11twLaeooxr" ..
	"Y14Z1JupIwdn2GNVEOQb6GnYx/Popctq54a7i6bdnTa2M6NEZ8qaYOCA4GSBMLacrUgbykuxGkt8AuyktW2S9piWgY39f0HusyD2" ..
	"zzxIpWT+LwPC+W7SHYGTFXYrMIg7Q/erQSf+mcN+HxwpCZMsOJym8YWp9MxySEWmrbopsPk4EYX7rKHRDoj4WjxjWYDACwVYnC9P" ..
	"21/rOTSQjncn18eMSUQvtVNis8Ch4SztkkwI2q/Q8Ag5KjRMT656JzaRhx4chCv0ArKCCrATbeLQ1VNp/heXEkVAfSm9m30b2Cny" ..
	"eGSNcEvWs9l1aF27X2wtBWBaoC86ekl3xblKeLQzeKwycn4A63TuGDngTiAZaTMYn/QuBETHKCTFVfyx48rfqns0qQuHcLJ0r8ij" ..
	"ITDeL3WYBRq5PVsCxWzPKVvLxOqCzcHzPmnNpxinqX8E33T+y5F9BFdHMOAHrE1QMGI4J5ukElc3ZztV3J3F7GSpnsCrpweIVf8v" ..
	"WdMT8fOEstIz6HQtT6Ka7NjifEO5VUg7+n0Bg9JOiwEtutPMvmO6DwFWhRb0bFnzA9h/3xYy0uZFqJEw5J48YW7v4L4FjgkO+P3k" ..
	"6TWDbZxhTNmz+3iJq9ItjsW8ww8U5a+dpr8jRHaSqgAhCitSEogshTu438KbgWy+gs8R83CtIZc/A7Up6zg8ntQjW5ntsYReX8m9" ..
	"ZsLf0YXludz5hgs7k/+sMwEfLwubzjKgX3XVqDghl2yyKJ9fKt/tidSRQU1Tv8cB1n+k4V3VN0H32lOY8Bw65tOA0hRQ7ddQreDl" ..
	"YilsQPxj4KoykWgvINqwZtEdQd4v3u4d5RFFN+U/R/jS6UQoZTXoxv+rpPwZ+Px6TLr9DRsRIBk4sv9L4L10LPXcdagjrlP39CF1" ..
	""
local PAYLOAD_P8 =
	"BZXGSbBY3JmqM+q3/1/BleaLnfzDRvoO3tR3Qd4q0CCgusV1F8yDw/oQ7pdREHUNlw623Tn8LB2sH73RpK82MOn8yG0a4tseplmn" ..
	"ZgDX3VFliY+SII4SQuaY8oWSuFH3hrKIA597enbc+ECFBUdoci1Tkv2V8FCbPlIJyD1IB+rsqVL/u2jzHsWM1T0ob2OQRlyKvdkH" ..
	"X87HX1s0xnwGVcFvjyfS/lkJna8J2k1qxr8EKmhWH3nZiiAnKzHAfamIKS/dyfL5RjK/8YoqQJ49lvQO/+adDUbcCKjfC+gW/DLO" ..
	"PnXI+xWUwO+AHCQV2prTphgkgrnem8699X9ckKu7VSfm/85a7KJKoYjw7WrnAVFPjqhHd5yTCFc28k+lHCHDmokAIqZ46OWbL90J" ..
	"aQ9BEUF+GFBCW78vVE63n0Wza0V0XBXq2BTqPJ/4m0WoZyPL5Vs6o2aOqUBo0TXc0xfgirNRwYlg6zdcjchayQkotlxft3xztgLq" ..
	"vfZzVMZTSx87xU6Lqru2DuEWGn5Cd2EPqNHxpyzzTw+CZh6WD/3ONe7Zv6DbtysrN6x8YLZC0c7DZ0GOyiSN1syHVj7TUBGwQWl6" ..
	"n1ZVaenDm3B3GDdwwa+L2t+2IUralGtM80ikXYcBRB2aT2DCO7mrSXURmc1Fv6X2lWW+8ZtDNfTma5asJrim6cl/85hJTLOK7lVy" ..
	"9bzZK8mMnPKvAQM7y9W6IfpS7oC4XfP0RWbRmglD0xR/7q7iG7gqAGiZRpw8+0xh/Ni2eTVnO33ej8nyMYm1XVNsONhSomdp99HO" ..
	"1MrD40XBE5tBFkGaI8S/PDszjvgHWcKP6BJaUdF1G3inNjLSvpADfWVyhjOb980eYgo1BlxxbUus7gSGDnhc/zG8LamlRzo80V3H" ..
	"bUBDGBSvkZE7QdUgWtcKQ5X6RkCv1NFQmdScpYFeAGsMXMbMEVzDbmkALrTw+TRXh+ECS6wTuuO+isojSlZaRbupyJSJufdhrqz+" ..
	"G2WdYgh3xOa6Kyxpt2jIUdO4G6gTAEOJ2oJ3HD8qckR0sFMyDJaXdoBVSxZgccAlLE8BNqcHCHJAE+HEF31jQgH8tQJA1UhFi4My" ..
	"sIeLmENTKtKYeQdvNMLyAMNgUTlYoDvzGT5E9f+uLTQfiX2i4/g7dDeEuL15UqgN3cBL7gVDO3Ms2A46wWuyRelTwacnghr8CJN2" ..
	"ZBnA+CYOM+RW84xPhvltkI6F1tSW+OOpeobsmXADQ8uf6edjwEMg2dEzKCJalJawaMsvAE9e6SDM6Xdbbl7X91hyMsy0X+3I5fMM" ..
	"Q2keoJEYgO0jGGF55MKJkladqk1Xt2Lw406BOU7IoNxkbLSv3Lf/gT01Na5+k+3SCYeHEwR/ZF1BRA//4wHpeQLOaarREPHfAIGc" ..
	"7J3eXE2aoziGsC1jGknLkhpuexyUY910/+iG0rSOIp1eYntX2JfxOgj6cjQ+Z+hYnfqHgncbZlqA0LHF2gidhV+y/Q/pSaQZWvMx" ..
	"Ohi5lPOucQuZWPB4Lg/8jA4dNWGze8UEIMFawZi+xi62JkO6f5UCY9D5awVl1yrLpdQIAn2fgqLZ+TGOM6qguN8MLYAEsEvmw6O1" ..
	"AAQO8PqaDT1CEXH7k8QBAS/pqlexSdEmpS/Hif1BVk3g8zjSolyLb8rm0wIFefGReEcU7iGiDeL66N3nbCDpqcvIeNuQJHascNm5" ..
	"0uQpLX0pEcG7TF8oEl9TARIABne6VNonT3tkhKExOvR8Q44L83d6AFgY6q1zhxoxO/sugXLvIGOe2AhoQ1x3M9Djn9KrcPxfGKlw" ..
	"MpLaCufLaxJ7YpdTGENyHe1J+68foOM754wVrWaDMV7Y92NyhVL8xGV5PLGe72kRW8PS+ZQ8nop5KgmarGyUAr8rFpgQwvlaqiqA" ..
	"KLTiqi4lF4VPN6MlQqKJE0w8ezi3woRX90B5yGvZJFCwZ3ritAxILAP1AfNPSuVt+Y3G7B+2QAa4etONVsX5iqIW8i7IsG+X7vn+" ..
	"/GYDyLYssIQ6nz8ZpUqhvBibATi42r8XlYFOKIOfL2mkLMVK1D3IUEJDLUyyUZqvNCVTAiYjFcx7uEULil1qwIfu3PA6R/msdVDq" ..
	"4BNf+EHXbDcSOJ5P9QSPPwghpAK/rTWN/iKouexxepCTbp2X8R312dxZ9KGB4E4TFzxde4M3yb2tXY682jJVCMgsPjIrG9r+UsRq" ..
	"qgqsIneeBZOAhzL4pw7z8zxCWu+lImhSnjfTjyc5rfR9R85me9k2SH0OgsiEwH4saVmR7EyiFk1eEQ5u1NXDk7BmXO/wyyDmBS1+" ..
	"M6Zi+mjXpw2RKoTpDcwJHQ3hNvhPr/HKLtLByxVX54gDx6Deu8AhNOECekNZJ4pWrzevycc5/cFuyWOFEkOxaB9t4YM9wgcJI2/q" ..
	"lpP09vmhNw9yIARygevFfd02GaMHM7EuGYUHC6kPp2//Kg2QootdryIi20jaARspyQfnNt+pMFEpe70kNCt9S3lA9yjfxkp87Zn8" ..
	"hy35XiGo6DGqDKlwM8QiDcOGLi5k+2JvRdclHqUi7m0RQv628ooAcAMTixQEBqDjsPrHgLeLSTl7dIf0bTutlu3ACY3FvIc/RIRS" ..
	"E358BOOKOma5T6psaxTD4F6cD+MBLtnZmUVSgKCBoPcFI685P0wOVVHkI/8Ts3ivIDc1zYTFqC37PDdMw88FeeqnS4fTym6myZtW" ..
	"vmcoDyWAZdPR8j0CE6jZgXkf6oYMvWezq63AN5ITM3jyg1XO9P8MoRG1MEzJ7V6WyQ4/puCnltBjV/2/3wnQ6CgUFbcqJPwzyO1c" ..
	"snul+iWUzaUWQ/dJiPS31YN/2NCcSJptqGte641IK6b6PNF5cigMwSr7v3ebTUQheb/hAAltGUqL3KcSM80dyjagbMsZ0nAjY4+e" ..
	"tVRmdGzerIOKhYjK/b9bWSqWQyaEHA0wrpqrWNFl4lGAhh3haAtRMZKsgg2+t8LJX3YIAdaifrfAA7Dpr31lBR7KHJrBj35raIp8" ..
	"veIka0N4nVhG2racx/obq91XO/7SYx0Nl7fLnorXBCIBbT5ZpRVL3ojcVRwaac0fyQpvSAy9ldzcbQP3yZnhgv568cORHG2V9NLl" ..
	"1lG6OGzJHyCOStXy1K6pFwkBXi3PJEQNKuNpZZZpkxHkECBfrZ/+uydaLj7cAhjMC0uOBV8kegZq04rLvAUzDWCFdQDnpkviQon2" ..
	"nYPQZaYzoXcuFu6XmoIYVV26MkvoCwPT7sKi1nEgoRNqu/iIQjx7mauD5z397PmAppuk6ufJR/pNeQvTlo7dVjHMHVMTIj4O1R6n" ..
	"tKIgLvyoVqM5+454QdNlSla4aqZ3ePfk/G/rqHtSlL1+mmaixmgGYd1cBmWksTS9aRH3OJrvbMmhAiNrO1EOkiSOFfhe3xyRFRJw" ..
	"M7ei0ogfY37jLezf9oPLuapCXqutTxEnA9tuaXoncSt2Ewnw0Ok43ovDd4iLds39w7cwRWCIRJpEMLNSKcxBn5YqHXr5//gLbffc" ..
	"bR8e1pQVOHCc1r+5jPf6i/V5W9GZXmbRIUC2zzskiOqF3jOVxnA1W7BTSSHgvZIvIQ3DPmS8s2ATutwaDGu1hwU7q/sqNwW65dPG" ..
	"chDgM5Xp/tJABblfxpq3jYCiSRhg+RYQfstOK3x60OUcsR+TUkFioqRs4hGFSA3dHt21b+gEKqG+2/DrOD2TxgsCdOtMsYywtSye" ..
	"8AFTI2XHc03Mze3g0Z68zBOvqIQQLLxyePLVqFyNDmq6k+qFFNCu03BFrh6CxBMMItslu4zXDBEbOqy5iYT05hsPkYgRQwxu2+HW" ..
	"0LXnQ78S6n0s28gwaT/YP3jrHOawsRAhLEiS1yBZFe90nq4dDDPXqzDFAzjo5tqo2uIomn6ZhrVGf0kuCE3ya4PQlgXAVLj1K06q" ..
	"ofHr4dYIWIlwnkWmMToU5U1zW4dHDKFXSESCY7F7ai0s2qutkO7f2BiO/Kc7+LZi4S1OfaA8Nee0cQiAYu5R5wbKxqyhEJ3KCYky" ..
	"QnjDEX8vb/XMnnFUQVMl2f5hWo+QztHaYgiXXjlOmwq5vEilSdb2ky+Sh2PCwuh7NHNs2JO24d1SjvZ8Cg+tqIWY2s2aILth9mSN" ..
	"QIUWMeQ6KYyfK+zlT79OHIHqg8flkM33Zo7JIaiaPzMqEXsY18ynwXmWvHCD378RUbEDOm3+k9kKbcvoJCcX18YxHjbQhiSP1c9V" ..
	"rtajFIOHPBMO9mRO7vgTMdG6cCIwbwLs8QufF0hHCnrKTyeJOxRzXtcEZrGyH8q5OYeAwaBVUpu8M23TaYPMC8Q1X4EbC39HS4vd" ..
	"Iy0iEisjfvfETuIb6X2N+5CWruB/nDGKwV8Z4IsFJq5YvnM9AQBwfWgXuvMh5elrqehqhQHQOeO+9J4hnkU2LUenN1bIv9SuMwYI" ..
	"oMl7Lg/9SQ4GYhb51x1egFJcTh1C0TdyjITIC3PKOO3f4Gbt3fMldoNgTRqXj+x5IABM8cZjEZocSLb/oFt9kBiTRCleOZFQd/DN" ..
	"eWO6ioYIKsU7U6XB5MxPKKy2H42xieAMq9UWxhtCCT7nfwp2b6ei8Shd49wRgYkHLE26mO77vVEh0OJHfKEwViTuSSvlT0iDijc1" ..
	"2gPG2f4Syid9/zNVfloDymJGhl5S2bmRWRNw3/KeiOJWEy9+8kmvCvB2iAAv2ja8A35dZ4G7M4sfZ82yHZ92FAxjJrDSvLk79rbq" ..
	"6g5GHq3hcbQXWXMdVhOcWxHaeNrYXVbl1h3ak/o5ipYoQC5JS/x2mgHJooufWTYupaLumje0wFCNh1/TMIOpF8jHNb2IUZz2ymFv" ..
	"fAAyCRz1Nz8W5mJSHq6l4xtVH64kKFmi5s+5hsZKXoukyPqL7r7mmIT+E7K7N3H+vsXSEyCELl6/+3HRs16YAJV3Ca3OQNaym+Zy" ..
	"QDY5+pG4pGZvpozFNfk7XEHDfD2NYXwUvUIu8CGGJwsFecGtM0VgqMh1ZlcAlDk1LLtg305TLHSST5NRH0KsdT0WyyaRzEYdOZ45" ..
	"ezLLHJiqsMRm+PTJ/aOfertvL1q7nH20PAs/+GMv6i/bXO7+9yysEwf9Mb0QCfqyIid47qk0OkWRLtX/b6K/eTPBZyvtQCugNd6p" ..
	"9uspYUj+OfJKkmWMyy87PJeOwGabtdn2IvgjOqrmVlcYxctD1gONFmHlMy6tRAzobN8MbckHOvksm5rJZbwEMre/M5erShD1UxTq" ..
	"Ww+jBwFtOU5YhtORQy1ZXNkrRNQX2VefF+AsgLEHd6ruDzqW/UxR2klWo81VLmuswoMMGhUtVzNUUV36wkTxxN+tVLEUqy54tx9T" ..
	"mSzI/p9gZpoh3KZtJySW7LFTMSxzu1mB3aaUlZ84LPAIvBLm3MXyzcZrIoTGJTXqkqvwRu8YMXWOsvorExwyQFm+u2/7O+R/4IOh" ..
	"u+VoUR+4KXOUJsGQzgkK84fDbUggYIv1IxthQMN2lh21ooJfoqZoD0bv8gHznktfZsaZNwXkxOtOVi4vxOQTANrJzwIztyTmAx5F" ..
	"C3wc63yU3/HuBmNmE0PFVuoOvelpgug0N/QwYGixKQniO+A6+c+3gOpgZ5UsMhmbHrcpGQT1CgG2pWxyufVS/73qlOx5YKO9uyKh" ..
	"o4f6lG7jV1LMfTRr/xRYl2uw1+pZCLYwn2D4Z6hfj13xxss3JN8jHYR1N4UCiFQh5fCPbmtjoQvTO+muwB3uEZk+IEMCsbO1cG+u" ..
	"ftwtfOpVh6IBee21hBnoQm1xb+2OMDldK29BJpBLocX82+UV8cabXMG8evE3FLizP9pH4CHq5w/RxnrKgdLrEGX42plAgVRwFNWL" ..
	"AN3yLTb3TIYCulnJnO7YdtRX+NLQ/g2KasNKUlymtAF58tgqXpuE6RvHyIUM/CXQWCyYy8oDzsYlPAPWV4hX7jleVZcXCZ1/TSOJ" ..
	"fVem8aqtZwUkenSxd+BDYTDYIYIx+UR09TO8zuKGRLyKLuYZmtIWZLrFFp4VsPRtW+zHPWXRq1EdAPnwgfZLhiexFbbbrslgflZy" ..
	""
local PAYLOAD_P9 =
	"SL1cUu9o+tWqscLQQvhsXtconxdA44vMMkb1wnEG4h5v6FPnwE6NiMNucYIJg+XWbozkt+Qj2XVQv/IQ6dwg/Jb2AI0C0spbTcjO" ..
	"v23AcLQiywUF6jP4tgGD8eTrJPTdWsXBS4Db0WbrvTJJ2AE7sEFS0Gz6Oc4qldbAUDwj7/uwsGtQ/CP+aHF7Ry3xsBFcX7F+eLLx" ..
	"5oZqYw1lZJ2qWaQCwy3okLy9QNA+2O7Dmgqx8t36kiUBeMxXegbXT7YdUqFxZewmNMuRxYL8f7UQAS5Y6WpCBq0jMt9erVJ0yIFB" ..
	"78rzWq8Gk2Rw7gCOw25daHxStWW1l9wwvPisFzfCU3oOybzqcBSE/m/9nc5z2dAx+l50tCYT7og59C1pLQ4QHHVMYDskd+6HA20m" ..
	"TUb+bTX+YgdpTHEYJdXJtEc9B5FlzBOzqp+8czh151cntmWfK/ADlS3eeNpZCnB49h/W+6SWWmkAlAyClGiSqbyXyK4mgXp1xODX" ..
	"mP8QshxHqkXiQdL850ML1wqfyClOXPkYssLwbgQ27FnZ6G4g8dEKN+/PQHMJW39VHft3hwtS3ChYUEOUE/RQRAb/KzI5DbRmPnxV" ..
	"T7Rirc4j301vVZIurpBR+llPYZvY1T8NQWDrB93ncRU0VDkkqQw/j5vvMIx8AifmvC6AV4+WTg9rVTnMAf41ZW7ASZip+NiTLaCt" ..
	"Q28O3hIUpYxhobAjMthYYEWra/+fvAPdq5bfsywiD2IDUaahxOzl9YDIIbJTI3rykThXWNCqYJCfgUC9kjVmJ0NbxVTZcMBmnBrd" ..
	"CJGmLbUPhtw+xexSxMRcmJQZo6wUVnTQJXJFkOlaoDyJ36jFQT4W8v0uTsvHngdwPJ2SQaVHRNIjwnR014k3LsOT9Rdu2chPCweo" ..
	"EZ6tqPG1LcxAwrJHoR7htXZQa3T2W4nEbsxGFoX/8hTJRapZX7oiUSS4qInSW78r0NVc9/N5OyMpvnyk+LDJZF60hZMWFIQT+GaM" ..
	"1hf2R1pryqQMDfMNiW8gkjMt9JygW0V9kuXQc4mY6QxFRccSlYLD/C2U4zWESyMZ5fV0RBVJUEOX1OvMM+xTrfSz5QBxDDwDzNf6" ..
	"CNmY4tuat2xBvRtgDH4mPbn8IvKJZ8b6dys0eiL90h/j970vCsnNYGoVX+1gNUWdbiYv9oYQlXc+EJgdQRz4z5zzqi4BO15PIZO6" ..
	"EprbhrXZYHfzfJpJL1MCtkoTYX22eGw13XTLalcI51U/KcPw7Eg9eRArrat8MKR7NjqCRGJClB5ocwqkURuqaU+H9ZJC/qkqpIX7" ..
	"PV+uTjVuFyHPDZiJrxtaL9Qsdp1OccktpX09JEl6OTvfLib4YX1b42r0fVMW60LypwhQZfL42HsZRO0XgsM/+P9KNteXrUCLJ9UB" ..
	"YOqPdzpaEKlO2YaXlUw3HUGuOeGx3qgTOgM/WNjV+87G/6peDF3ZFj0WZECXLfsRgNKR1GC922M22mIoustdZMgULtNd0aYpMl18" ..
	"dfez/WKLQRe6ZZIK9XglYclnnttK2Luu/Vd2IwopAxwi3HVZxBT6yUpw8qXzTc+/aoDvaf3WX1odw89rKBXqMDz9IL6LFP/eBjbC" ..
	"t0uEGfGwRO1797iwzt15SNzGTa8O4tsEr0CprWZGrjSbMpVP2wqFDATmZ8IbgVdVhXnLQVohKlEZnqKMIB7pxjQR1wBavHXA7JCN" ..
	"gLjIDD47UjaIJB2eSaatFJi4dIatTFL9aV8BEqKttzuRAWji6r9C1x09j8HDz4WdhnWH16+jTupFO7HPPAz94oQJZEnY1pYBE2sK" ..
	"IS8cif7XlBRSDN6sAUN8VqaswdHzfmYlmPz0SdE8zyqI+5+9UKeJ1BS1zTbBBROJVIQ9HkEptxAqt8HXIfa+iTv9ZeqLV+nT0UDu" ..
	"vCcZYIVkKjHOB9LipFZVBjuQVQo2Q7J8K0tTung8FMpynxv7SgACfLmw89CDm63Q5kLZYUNmxwYtrEvWd9OK2KLUXM+fSla8eDKd" ..
	"IDK+Jf1VHa91zy2E79zvOEWfWCkPZ6DTLQXY1T1m+wjtfcajeLdxnWffTruZe89XwPbKqCeviif1wLuOAYTNT9U6rF48cSh1+f7S" ..
	"hEREQGDQQHpQ+FHQc6fj5SYF4U3P1nZVC2s2J5XqEmbnXao721TR74CZEdpNGzFbahrKRb5wD1Y9OGMCp1fs4p6uDJgGJE4XchSF" ..
	"JJXWMi989W1gerH0h9xdQi5r0VWVxgUd3mmI9O7wvGlD+DLlpb6Pm7RBmmAn5+F0PiNS7wIdt80TaJbUPZeX92rSk2hGgb6HeOPJ" ..
	"kAjxznGcZp9G7YQsS0xIakZv+COxLg+ztlTlnQWqDYWvuHEPzieicYKfR3QEXGQWhZ5CK6FKZSgMeC/e1FM1BmrqBcb3dYeVkWdR" ..
	"wWGaJE6JO/cPCei7syXlqQ46PtS7dLhXf6gfRaz5EHRLlTSpHJkqPwHZVJ6g7vcbU8hDQk3Pg6bU2UfUhey4PL1B8ZRLhB8Tg+HA" ..
	"XBzU47b0vI+NaNNCcEkViYAHQStAQVonKD4rfZfa8zuEQTEj9DD67C+bQAiiNryH9A5t+p4MeijWYmGsm1sFR0BncjMNp+VuY/61" ..
	"SQzd8QA+JyQ5fGUZSO6Ig66QYrj6t9Nhdze+wW6IU9w1ELqBY9bHQQ5Q2sSkTGDAZalEMYeO9l4znpZ2B4nONcvAeAkKfJUg2kdI" ..
	"O9QhAHI2dZw15w93nSrOSAtpCrHwPePRcsq81vPAg9Nl1RPLSPJiRE+d2LOrpHg8zc0w9HyCzvyCTTiC4j9AcUIi0TXMe/3C6+0U" ..
	"678ktD50/+WqwIOrRnwTqaD6UHpNN3BPmcE6Ugrzu4vt5WRsnpNHYTjGk4TMTTHW6O6jaaofZ7iLr6++XryCFgpV3Lgjjlr/XK+U" ..
	"mzbAji1xVyp8ODL5WtPiTMdGefrYJdzvIaph0iw8MyEUE6BL26Y2/b8bL5XvqgccQlgu289fUt0xqyEDTlfbrU6ObfWiYmPKs0g0" ..
	"rSK0vyxkEXoKdOGM0YKftU6mgw5kIxi91ODb03xHimXFtkUCdXj87lel5krl5ROpp8zLEjM9vwOI+nlU5k57MTHFiGoFhObNRPDq" ..
	"94/IqRZYEyfK4x6NabE/+iSxInDd7zDTyLVx9XAQS581b9wnNh3yqx8NQYWCdK4EODmngEsh+75DZRKzXgerGsFqBZFSqmKtsKbJ" ..
	"8NzysdqDxqNxpI2v1b6maooeaSqtOPv+AZ/7e6S31vRwqGjt7htI/if7gu+IR/41VAOXBGceKWm59XWcDH/96Uh16z0add2o1iV0" ..
	"B1TndryVIOgRFUwRaU+H+s/gz6MFxrN6BzyFQHc0cRZyQMbOL+dXr23Rb9Cf4i/GIN0Ody5lqnzqpKI3MPOK/ZfyATdYY+cR21eC" ..
	"Cr0AfiOJwS8KUT8nPlLMX2DZvzg63bzADFWPkoCIY+uhciPPZ9KS2XZRDDyi7d9QdQmPfWyH5iMNhsvEi1MrmvlVHN2QPWq3pr5I" ..
	"qN9sfnDUdKhNF0a98GdMRUs7rZIOln2FDXy7WrtHwZEl2mdSMO52C5T2f+7w/y3tWznN9ksZM1IE/Lvdkz4EYRU+07Ji1vau5DdH" ..
	"T3yB1tQ91Xo4pJce/aYYDXznxgInTms1LFSWKdg9r+1ARByc" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9

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
