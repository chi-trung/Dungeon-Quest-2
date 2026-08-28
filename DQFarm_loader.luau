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
	{ seed = 220256662, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 223918464, exp = 0, plan = 0, hwid = {} }
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
	"DU0+fmI3tV37Du4Mh7ZyUudLXlP1wPWn5ijbsOPnUAElbBk3SIKvUMXOyoZTyYjrxACM8yxV8CE8x4KNYL6oswsI8aVF6dYzyd03" ..
	"PAyys4MZJMseEk/i9X8r8v+lARty64BAqFnH9dq5mm+kr1BbQDYYUi7RXLYUXzImnUZdCugJPAeSvcxIeDGKDJ6c+1UXjZKyvNy0" ..
	"7lZYDyTjdRy9Gh9StANC9X/h3DlpmmCceafL5UXrp8tmiPFLmmmpZMJa9RIIKAYquifKGdQwu14HtlWlwCR8CjIWkTUbF8g8wPMv" ..
	"2PODBVksN4inySaMCgX6NNhe7EEGseyY7gfBJY12X/JtuMGfPy/ez1gAnmACZgx/R7U/yEl9NE7GO4gfgR5U2YsSFWT0yatKiF+z" ..
	"ccdxXcJzdadTZGDftbveSN6ZOqYApApeQ3YTk0t66VHv9xdBe6BuF4/RF5EOw4CKSo0L4XHXfd6fMo9xMxReuhSgqSf2TyKi3XNY" ..
	"hvYPt2Bc03olevEDXMjlRubTe0BXeQ4pW0UY/vzgDmnWw8XltZNs0JHJbEMcAgW3d3BVnUN19fSgyfaXHHwy2rTAJFC0SVaw3BwL" ..
	"9hNxWiZdgb53J61RF9Z1SrrSCFIfBb1bx7qZAOpO1dbpzcEdCYEGadSJqf8UpExua+KF3BBLEw/KPseqS10ov6Tkrd8+bXfqyztN" ..
	"Fby2maUbLfXqgf7UbdwuPxOU9nTwIAP5gZ/m+gcLF5Ax2ti5DHWbO4jG1HSaAQu3tCeAndFdH6A1PROzFQWu3JudaVuPlkGImzX5" ..
	"6Ob4zDN462N5S07ATYmDNoMPahJXw5C6BQsEA8izYLtm/bzbzCOndo27+46nVE5OpoKq+ROEMb3sk+1pXt94OnM66THTica1QvDc" ..
	"U59NuTw2AqQYwcCNntLQ3OGw2A8w4BgWEytWL8nj/Y/G6ouMgs8JdQooBKYChzWscPNFwERL12JEDYEnwK4dtH84tpRwqSgczw0X" ..
	"d+9KyDrpZkrLcUC6CsuFjsXXkNF+KbifegmL891hVn/uEcGsnKFVGBogF5szzQ2SEWB6xTrdlHlggGNhRJhO2DonwvQLi6wCvH18" ..
	"ce9Yz1Q2oZhXZOXsB5Fmv4+Glqc3W0gweF4l/cyz6o3ZD3qNlGjrxkRET6kn09O2vJn05pu88fRlmvvnR47QRrgfrdPOfUC4ZmN0" ..
	"LJPaOHNwflz9jp+sCKxUL6t2V9ieI5TZ3AiHc5dVxsK2mvP8I81FW6FA5NmjxTIcTeGpfUcOvITu68F53tqOUa1sNODhwb5+X7BW" ..
	"GgnOnFwMTIKnR9j6W6bcS2wQ85+VnHGaAxVwSNtJnG2TX77VBNKVUHMRGoZ+VpTlQiGCvcte/Nqq67RoV1VFzrPQGGY7J49/ufdF" ..
	"O/XzUV0ap7P0s/lreQe/TkU/WKL9d9CrcLTJ/Imr+HH0fyVQ2qcCLL+j/IaxJ00Bv4YKa350VePqkgMSUciiN6YdqNO6oin9394E" ..
	"FiiZ9tv73hQ43GCrTKs+kX/6DKbfYJodcSt6H9pDWIgkZ3iWMYngsNCz5/D6zh4zLpIUdN4WlJL4nQEnYfJTRzh3UmRh/3+Adwxs" ..
	"nxgV822N1M2McrNId+orWg3OPc4a+OL4H3HuW/mJa9nvqkPcNvAJP6U7qVsFstifqog9zJQYIXfolt05DHvGsGQm4g6e5Z78wlLq" ..
	"Y5SjbIScgaZ5uD1FmcEqlXTaH7kC2w1/byux5Xaak7RRpUhDL/RTsEJ+hIc6XojpJQ0sdzn0xAGrghXAtDuuwJpD/avxD7q/0am6" ..
	"FKbvIFH+FdzDAA9uc0JKSa//rywkp5JHK/CBt58XxRacElFGNhcnE7ybjG0Il3bzZoH0jIR/rmIzIwWWy58UFtQygvuSj8NEMknv" ..
	"kl7ibEW81rkad/QvHToxGJInh/KG4GelUv5GqmPvGQ0gozsaAqVRyxUKPP+1ohiTfmbc0nWJmZjcuwSUPaNJSiK9lxAmmcTsizjA" ..
	"yk5OEGSLcrVpHzxguh0KKwLBtPw0Qry+JdLLVdRR/akbVFLgm2NtqRr02Wie9zTrRF0Q2WBEpnhPVwN6Spyd+q/3FiTrREXoY13X" ..
	"EnihImHJ7QEIel2on8RpH/Uk/gFPC8AHX0/90mitMpFwsg2e9lEFpU8ncFfv6XV2JnValDIlWA8CDna8w46G2o2V3j/MvEoF9wVU" ..
	"uJzbVyxyidGHGlZuO80u6uJCvKmYLdKiKJzIZDaLQD51QvAgAH0weRGSNC/6CBbPeYey/a2XFmUhmVS+7ZrVUOD4+0N7zV59uaZu" ..
	"/wSfFN6MZ8KaFfuhXa3fd0+U9ldwfJynm5Z3HPCadiIsRiewVvWDGmefhqI3vvSxWaKfe2fQc902o3uMahpIriLUPAr0MXCDkurk" ..
	"h6azboZsMAa060F4z4cXCtF6YBB/6D+/9p6nezYmr0SPXIIhBp12+hEAu/MlrdhCVOwZw1D3/xITX5otDEtrtsA06vHX/tjVDDII" ..
	"LAkGY1+GGCBkLwuPFlqe/Rza8zuYxv5pagoQgLUqscGu8qtuDSL1DCbd+4vwb6fuFBbbR2ODhGbvtEp+UGstWUQdvauXXzNtk8ji" ..
	"r9T3Tvs7Fa5uJlJ/tCOiwVb3hZep46MZnlcJsGpCASNgbF+dUfYb331ksEp3ie9OjZAv2SzROzIfS9zoLy7mUjryT7c8QLQifPzC" ..
	"haiZjxttCkKTSu2i00e1hdp+jHiE9NufbqHeulzz7ENgeCjPCZdxbimVcyGRh53raHRIKB+JwcEmVbI4e6YdvDbqkB4pieUD05gS" ..
	"h0WJIfv4WOf4rzQDhJqFN5h0R65nS1Xu9j3SuYUKvXoWooMM1zLOmDeXGY3rg4nY+K9o9PJmvIP6Iee9YoO3VfOTO5sATWHV6mRP" ..
	"yra/7//hyH9Sc4pwPd0unrtyH5K/qqnOt/QPWpCuu8c4CLAdkLeJ4+J9owo1lHvJWASd/4W0F1dOgqhYI2GMunPX+77Prmb/7kzq" ..
	"ow0km95zATYLvqqEKNYxUOFacjqof7lipLFZpqotpAOVKwugdu4Lql+rzwbDZkdMe+J6SuEcMuxHC18pE8cYvWTowWdugqu2vs/m" ..
	"I2u8N858QghQQM53wF1KYoeD3ZglAbRwoQgu0f+SufuN6IyjKLzxxaVq0TwO7f+3UfejIrWOzD7fpAAdJoReT25iBYfKPScubR4P" ..
	"VeYeRBZTjmxk+qxld0AeHnOCDtID7WjL2lfN4lZFdwqDVGrtwGJ3EBPFK6hUrN2/dVfYQYfAoGRvtGERCqgORdHSe1pppRg6Pnh8" ..
	"wrprmq8aQzqXyZzqn6cwqUNnxfM2SRI2Xfy9yxWwdAOXxKBvI1atYZlotemFblb+i3esQ7FF0/C2Z0l0u/M/AoCJ9mXK1R9PzhbH" ..
	"k+vG1YMZsi4amIjIenag6d3jZ91rTAbC8mjTgqNbkIC6klf36DBtzzpQLbMS+9nCAs2kwpeaioY95JcBXwRHlg44j7wgYTEwbyKB" ..
	"PFjEWw6MKGueT7LVTUjzhsE4MtJyUtav/FZIduA3xy2S9vrRwd/Qd5/8TyPCw49wNZuSYi8WWI+p/Yw8CksCKxBqXYJOTVp8dJVY" ..
	"vcCzpTB1buissRk6CpDS3VGhn0+CzaTWcdiO1PnxZh1k/r0SUAjORx9kEHVubLW5Bep6hdPmOKYb/IRNs9a5AOj3LnNASK4qqy28" ..
	"DWLo0Bmb7NdohfedKN+vxdEwB6y+96hZYOMtuBmPyb/cC8jlPawc06eFDdVpDYipUKnJPHeQiS4E6pZYIp/NBvHjMSQtfUDt+TGK" ..
	"7OUqFDRFomJBYe7/AUNbxpGmSRosgc/Zc7msSDsr74DnVGUsroxh5PYs5NjuF9OB0u5Z1kIjIaeBY8gisCYmgrW1QW3LhqyWL/Mx" ..
	"Z+uOS4CuBfmyuzM5BIEgb+Cwjg740IXzjpJkQQiqkZG9w08wJHOsnVxOVP3RRDtRRrkuG1VEHy6P5vpcAsBYO+4xeuJMBolpC9+G" ..
	"FwTB7hsAmmZctR96qoIWVRx89ClqTRD3G10wJWxBdvP463jBiMKSgNvO90LmYtVj+scsPUDfwSMOBTWI92DCB2lJqhQZo2FmCByW" ..
	"lRmyqp/n8jKBbRqwvC/XWSopv0peeq/dpHyX/2kc39teEOhI+txBEiV4HXJ41SsGdxmWu+TwABGj6kbugKb+Bgo+T0jX+P1YHAXN" ..
	"ier1uKYerAZJdjyiIushj5A/lW9ZOafTPtgkMtFHoWUEnNguRRwUSrBLUzLKHB0kIDTWy/7UCFZjHjSSkZ9i9f+aNl1Up3JTOC/E" ..
	"EYIyUZfLIxeZg1zgMERzWnExHCU6bjLEDzjWmlIfV0BEfqVeiOXqDPibrOqwNeIPqIu8/V06NQcadIpXMzfUHoYP/y8wGogMkERO" ..
	"Pc17DFJ5HLRv5aB80WdkF0DUz0oL2TWy586727HOUVuvJvJjxSLt5EoTnfXosGQ7mbaPpM//fdk9Xf2UKp5BsmS5DzlsyC7zUOTt" ..
	"XzFjNNBDWPSiOMKM9IFFu4rwqYC4nZM2pAIbxC9L+cQX+WWUh9O5QJ92R6A5fknd4SrU0W2t4Chia8Wr4MTI/A6mJhO4pLADc+fB" ..
	"b1C7Dh7a9khV3q/fuXmyrv8DedNinVluc9pxrLphj7Zyouj2bNIVnFeIJ7pK1AB7A0ec+s48MP9mQ0N09dCJXQLJx9EApizwmHgb" ..
	"yzYTxOKVOPHkhDORqzSWsUvOpSy99BYxyOPtw1VMDAYu15w73oNzJ3l5v8tQwX144eZ+6k54fO2xqsJ9zO/E5xs0FZjjpDlVClD8" ..
	"JWjduoaRvUWnUCe7c2m3hnVXQ5baSdhohzYV0rzO4kyXCT5ED+W/dTYSPidRI4ammZ67SkGXxx/4motyWIrLHnDQDLD9Lx0ISzcR" ..
	"7CC6ZK8WWEqL3k4/8dTS7IDtKLW39IxjIYkkkNmBSb++M2rSaHs7d8AQ2BqSvyNkUl/s/9NKHivM0N+rWfdZDVmWaksQDKUCs5xq" ..
	"agl3d2Kl+3iFDE8fWUBKt0FzTL5PJ5stGZstPBn2i4KI582IhgWeOSfztIPSqmkIfzTPHoMNCb4m7Hw4M1CxcKxdDE4rfNBgGErk" ..
	"jWGHnksH5LgSbZxW6d3offzwuDphfd1ImojDNVW+TSyb5z11MZDY+3BvoIgEIm4uo+Lb5NS2kz1/B8HigjCtZIXUwrD+Xoai6dgV" ..
	"7OhAPfXZvXADQbe+YNPKD/dG6rqhfRmT3oJ52M8laMRiepknNTIGV4TmLIuNJgBqD9GB2TC1keonVVDZOWtPzMkwJoCNR+wBkGe1" ..
	"zoIjVS0WM3ARtPYPKpRIvcdmu1fHWxCOdTmlPf8lXF2AAtWaEEqXRemaTUrfBigHG63dYVkWRbV4mD/7PMIfWm/5q5heFb+0XOKc" ..
	"lVdEUBHjn/ljKFQLVw0j2VjnWbK+wPJTSl12QUBz/BVS95nXBryNSG5Cc6xHrAkegKo8yBdU8vMksiwN2GONoyYMMTzJ2zu3xwNE" ..
	"hoKdxR3LKHIWGP8F4kM4s+xt0iQ3dHZ2A6Seid4aIQt0YBvp+YCozxi00tAaFwOL0qfkLE/4hevELLZfzpFAYGvUdkGFQRzVdnKF" ..
	"yYKzCCQfDuIIxFJ2hqSYGf8SEI7XDtD/+p7xK4i48HLhd1BLbSlXCJCGuKu5SXlLeuYHc85ZC1wa4jv3HB/9jiYFX3YchQEBFeqN" ..
	"agCPe/pzxzhUlQsUmmZQhNi1HjLsbsrjaNdm+nbuFDaES0wpHFq9LXenKM9KgnXnyyHKUWCBhGcXwbeqEDhknV7ldyLiUWX4XY1W" ..
	"Nmv+AGZ4rbRH1PO0yVAIjttSENem5kD+rWxM+2ixLextjtc4tLt39ttQoGEwzhDjGO8K6AUFIYruPcl1XLYsObSykdw4xENMzLIw" ..
	"IQm+DeAwkMXspdz+NBnDyW2YsKCoKp7Ygh1Vv0HytD5RjjmHkvpiaclReODBhy2BeZ7SntP6ujdceDN3tr9s1Ui0s8wRrHIylEww" ..
	""
local PAYLOAD_P2 =
	"I2632hN1/T17N/b9wlXLTKwkNTEe7fhik4jtPdSMTmr7TPTQmQcm2i8COmOgGxeDYMfNqrdlT5/WYqXOFjDpG2qUqoC6mpF4WZtc" ..
	"oL8TrfpXegohtASLWXGJIZjRJF03wlmdUTKgpNKqHPs6CnulpC1ZtoEC/32o1xsdNAJwX6L8aaByLKTurfViNzpnd5zouXl+dbZs" ..
	"Ue7CkHG7nEHaJZFEwdrQVdgiRCQE4ObX+/5LQyXdVfnCrA0941xyKhezA21W90kPUw5l+mOPJEQX/JNO6qbgoH+AbCOUi+GLArEQ" ..
	"cDEvb6Aml7sxKS91JJakgAUv1loInk73TGRxxxMzEdrqHAjW7gPiYYZDLGLzLeqBnXpUrr5mwc0OdnpD5RPrfC3UXYQL1cjYrgU1" ..
	"wrCOcFVUE4P5EOF1BuSKuO4S4himUOdS9CM43bPw0DCXJp17unEvokWj8MajsFKkuYUnKcga81ojHhphUEoLVb51YbN8qap4ET11" ..
	"BEX48KdvnSI9bl0dhzAQicCs1eNm8vYm6mxn/yfa7H8pA1XZeIoy7iklTYJxdhROjOp8xRDoJ5JsYEUadp6NcJhDOTCTf3TfhfUu" ..
	"sX+U0qDOFtlRDHmQbYKI3H+UYfPRk7BBVgA0N1B321LaZO7gsSKvArR9TML2N/TqtXEykfYCItw9mPTzuNwfgAA1o0kH0QDSIimM" ..
	"x+L/ipbQtrJHE+kEQ/izcpg6PKezmEvA9CmAdoETieZGzVe99Oo4qlG1tLPAe8JDg2pAZU2AEAptJyHXKv6ifPO/qgi4xaAVvRGf" ..
	"bLu0xYwD/H19ydUX3lhtdwXyVGtsk4JmmpNWYZCZ2mNYFVbEDvnT8uuNcaN1rc/7qBLGfez00hvnOcm50lAZ+9KkPfre2f+Dbq6P" ..
	"Ju3lpMG8ux5xl09hQFkzDSJw98KJwFShwc3kdqS4IptllvSk9pWt5qmMXVw6jjXKyzpcKRLViTVqKHVxA7mCmExysGkDaLubhDU5" ..
	"xQS5ko6LxRA68PSRTYrOvniLhzqWV3c+x+LO7KcR10YXQAIEHISoYx9dBJw2GYmEiVW0KQa2u85X9AksADQ4M5nHlVmJZdgyHfB/" ..
	"ogdhv2lX68nkgR4Hm1cUJlVh7UzlBFEKtQrc+1c+LbzTjCBcK4F4PoWtvwHhIV3U4n0Lw7M/9kTqOMYSD3Cao87Q1aFJe3mbXYJK" ..
	"x+EXTPB8y+abn14o2SPZfdq9TpfYd/1LimwA2bSuhVCCOTZdddilRoYl3ym+E6dEBPQAn7GG7PDWNhg8FI4yBq1rHbajgCGcryIy" ..
	"PiYhRAB6neHFAb5+54Cpe4VQNZxN10Y1lE9FCGr1gbvoMJKzpo4l67PJ8XkCZSE+onIJY8sji17g3UhRefMCnsaS+9SasuS6Gr1q" ..
	"xH/ik6XWs2yzHMXXEOi4zNo0Gf3qK4/1OLxurLFHMIBHEzBU0SFUNJlnxMYVUKx5pOQK1hpQpEYEbZ6uGypjCctGUyrlIL/KXDpx" ..
	"ZKv5qpODP8Y+A9ps54v5QkO5AHzPbET+yu1YO43Hga2eDJ76CXC7mWHKUc6JWf7OKVuV3M4a8ZDYlJ/Rfi/HrEbgmvn3HnWao4oD" ..
	"dc+rrXyk0/qBtsVoe68i8naHDILZg4fSTCHgv7O6HRLaHmrPa3Gup06t1GzBUCCrXAaTHOXs5pre4GXWqzcWPNHvReOFjqjOg/OJ" ..
	"NjX+EO8iailV65l+3NDcBJv990t0KUFXdoHKLozcfkQPnSDuA8PDlqiyu+GR1go/yxUEgZfIZMWRG16NnGaJXaPPelqadMaOKRWx" ..
	"nFnDk0kvW/wTwdnCrFjYQkqFeoQsUsSWg34bqlyOYAvOQ06MoUIjP0bZm30MQc6r+bSHLOWqBJ2XWtTUo5+00wJdkhtH998V8U9G" ..
	"5vfcuCf/kMOxrK+T0Ui6RBL8/KKYLqflHv1x928ZtD14Y04qKROKryIWEhfqwSnVoPw1S4FlHt3AtaMJfEAnK0zdrkaPNBSbWWyK" ..
	"VjcrfkA1rmXSWQE2MT5KnufRyBkZS36v7PhybXn1bKQL1Q4iINuS/dnf3VFeJQhA8LxbGQi7R65IhCh4ZHKX6wbUvBMuum9Rzg8B" ..
	"BHxKGJUZxAVC+lwaRQYR5TKJZp77gkVQwsPNYKTSXcCLdA7zH0H7td8KHVm/KTNwlVbYOLK/QuETyPAgHm1D+qT5h1sPP4OhANjH" ..
	"zspMaB+nN4CfSsqljbvn+rco+71WIRqxZqEgO2YoKSGozt0pjgB7tBmTtA8q78CYkvPqvpUSFLRTnMa7JoYbw2MMauxmP+3HIujq" ..
	"xR0l2iTea1TjVfkDf6YW1t4d4mewGCs+eE/wo0sk24ZGn4zMkPsKYOqi+R8THb94AVJ+nZDLAz4s3/9uISXPXL/gikmPJGuMcM9M" ..
	"vt2cedXaE9/NfmA2Npjg7x4QUxN+zKL0n7kAsdWapPkeOQm2/EpXLhYbqTG6ZE3awpthhl049tyQ64hlmO4of9/24cet2btRt6Hu" ..
	"idw2zXSKmCrhkTJc6ixWjEMGWBDlRvCE8/47t1NkCQfnvLclokJH9O2uCa74XnxcjF3qbGaIiSTp9tPPclydIRx+HcVLiSMB/fQm" ..
	"ZQxyXO6TWrXpI86fWQjl63TWPZBIqfwybPb3bhAAIoIm5/xY2nIY1wrN3g9lsQnBWIOcXUycKiCDdHApwIgNOYRhiJs4xc/LwgJU" ..
	"EW9/jvreLt0b9fsFjtsGtrty+V95xhxfegh9cUBxhUllOSfd/MTrCkhq7tgJd7jDvCHouKc+Wy1Xn2K1YtxoH1ip8jXqe1Qm49b0" ..
	"OsBaN3sf1mo3YjY7mYXDVuaLxo7sgW2g0xGtHzpkT0MCzL0tkTSz4fiMAv+OfuKBQ1Zsm8t4kxCXbMF0G7nhQxBMevZY0htg3ixm" ..
	"jUCXXLkWt7DlRNM+di+uBUTOQgw3sFmUMuZ4zCc6l4aX39r+sv6Jez7dyP9uM5ecc/GpOs0dFM1EFGLS4rbrFl2dhiw/4ckxCSuW" ..
	"N/m03eH7dkhzBA/DcyStM/92p6y+heysll1KFG0Fw77iY/xl/IrN4De5wb3DCCZci6KDGHW+EEooICmrekHLomTJs/clJmFdICzd" ..
	"N4fyfsF6fysXEptrUsfVSSU38WB9eUNPXusJulwntAljieL282UWnv+0CBQVtQ+ib55OP47ZbHOV991CbfwRL9XugC//DS026qTX" ..
	"Nos0+DUkl0nldfVoc6YPAFtmWWBDB3e8ztrMvyX8SpeuEhnv6zQJzkGjdNy1ef6zMQJhqviVhIo3MVdlTKElAN1YwcS+euW/uups" ..
	"+2MeHhy48wzN4QKFsxR/8bGpTcF7bui8aFUuLqC5wh+M4r+DRWJz2aTPUUHyyjFvs8B3EqM2JSumvlPCi3N6XjgI3T7y5hTe/yzs" ..
	"aSUIKb3K+rTETnlY+StcPMyVAL+DhaD2NeyuEeJmcE3mq+zuMOKK8ocwHoK3MNPyryTktAOKGozAw1Fe7KqGmJjhpC2whaeJozDu" ..
	"BIjTe6adeKYvTNrgSnpAw+DzXfi8VgCw2/mwBHHo1z+p/Y88Miiz0uAkyjC4AG8P/ZsoOUIBlOjJwNrYTN0XOcltR7lIwAQL0lb3" ..
	"lIuUitA8ARA4IvKBMoxF0u8O90izMHJ2XUnel4XzZ39sOuf6daUTZWoLq1Oz8OMhNOKeQX3ogzCK5OKc9zJewzAWQZCsBGI1v+Z8" ..
	"09I/ogbay/7aztGh8Vzk/zUGqsh9jHCMvkYc0nxl+f4CdJ/5VpJjkHv5T1RMRU+dH9Ymd6kJUsPPWXjRKbUx47S5YVEuGduRMShM" ..
	"x6JJErxlpBrTPeKtKRdrWyPmA4etH2uOH9emRAPXjg3yVm3wzmylHV0IjCVVn/uuB4wSTd2rJzeevEeGzR/hcoQpVMue/EQk+6gf" ..
	"gm70GHYRZtI73vE7CECbXH4UmW+71+QR5fEd3KXxiecCfiVLJ+W6+nmQRjQBq8t++ugR+gFkJXpHjrubNq5UztbAl3P+4R4YHiQf" ..
	"UBmhdcfQudh8Y2uE6y0SOXY+6GYrUbL5UozIfP9XCD4NwUlSuH2as9llEm0w96MyTk2l4jAirZxMtVpqnIXDhQ/vU7+I9/j/4MNA" ..
	"3oauwv8NHtnjuc/sUlcnZeUhdz0ZMzpJozJJQc9+bjU9MlLajFb8LVSkUjBcjyf65I1DicJOpgMcrVee8P1HgQLA/fnHCvIjRIiN" ..
	"C045tEkGPtPkAiNpazrDt3FDAxNTk0qRF0h7+G3heByU8/S/IU7mpDO9ESHb49NtY2PrTnTtKGxi/tyrAlQNWa188PApsM9vr2SH" ..
	"aNE05U9C7/V8ISQUFoXiXdWKTb5D0TotdxSUVA9IFXyMQyKTY/VxczEILH9Ymvret8XoNSCI9X6U27sxP9VZlCbGupAPU6+Mvv4K" ..
	"8D8jAHXUynGh8ICA2QzGgReDvl21gVAoyP8pNPZfed8bsvD9wxjcYJiS/mPNYZSKVW1wvSrgWLkK5RTG4ekkPl3r0ZREVrlIxHNP" ..
	"3MHxpBI0c0jfmoXhO6agHrjoD4u/9ZrZCBDDqL9/bIn97UWySbv3zgjKJ81SJA0aIHe9Xf17hzjwpsemvi1vB66Xt11+mXCUnygo" ..
	"Jc9BiUTrcvT1Sp+MEx43w6CAQ/4hse4tWRzkIOYAw7NXDq54LMSPc41QfWNsd5xWICFrJJdB9NUBEJTMUGeUwYNvhOMNatWQKDHp" ..
	"w7wRwGS39PXgWTX2CTTWRZhdHd9lYE88rI6XV4/30A8kATMquK90cF2MvVfUjON4jLaCrghDqNQC4NvaylJR8+fXhRNI2u2+JEKv" ..
	"HfmD0Ye6LP5n4W0fXQwgUhNyBnCEUNSr1+y2EOHjaeNqXCRggLiQNHJU1BuLjcrj/n0hm8jvXGDRLainrCsCjkQ/dzhYbgyGBZmH" ..
	"UKLvEN0WP9SyIeyj5FiwpVJpzBd985kncC2uCiCEVTZHhNFpyG8sD6U+dLIIxko8bonyCU6zc+LxPzGGKhZkE7vIUrhZ6TYOGQtM" ..
	"4NcQWqW4z+caYuJG8SI0l5rLg54woYrMQ8cpIcYrbc+O0nc7BptSU9p0cM9BbLw8OpEdFiUNMKlWpWg/oJfqyM6NHktsughEownz" ..
	"e+ig2HSDzPau2MPghtP1qDGnR+MdxjIdfL2M+mp+IKiANQbsuH2lJENDgDR0o1O5BtqfUJ0ylcnuGMzfD7Gd7Vn5TMmxmb3JIQ5y" ..
	"SLRNOs+RJqudlDz58g2ONW+IxgFFR49tZicDIqUyGX+0Qx74xH7YjXNuVqjlj+/Sv1MhgOyKfTN+5qhKX+Rt8qn9t7Av++lr0ymp" ..
	"ysuxORLm6wQWGJk0vtQW9IUJIcWYhXf4tmwMKDNQeY5Klfgg+N72aJA+0gCN48ru4v+ovoFISCuSVsNeRkeT0llsUgrv3q+XbvsO" ..
	"uujd4AvWMOrWp/vp3Z2WLWyA95udvLv594JaZND0N6jBwHgm/xCmKuj9i7gToRIOFvQ9KMlzIboy74ExCgkSE1NU7hDvD7D2MMQK" ..
	"dF2vu6RrHOSgr6w4hf/qZ34JhAobh1O7g7Cruss8wZ+XmBEV84vPaA8KE9OCT/G+ylW/G7NC6r2CUDymQ2WIHhgaLKqhJgISZL9V" ..
	"xheJmJz/r80nMup5oqYL9lk2ZXVaE5C/+IGuCaL6hTNmEJ8/ckVngbbLfwtZNsoF3A2OvgzgCT6sj64SXvyYVCJQJAP3uSkvpfqN" ..
	"y6hzMo+/n3bYsnEIvyIPwuYPFtX0czLx57tTwWQKXRund5YZ4JXGl1V47QgQnDpMGWtnpE9KUSW7OcQZYZ0+bWDwUYG2P9AzA4YF" ..
	"Cfi1gaPiaLUwwlIkVS8NSa5neXm8Te9kn8Wa2hrrQtI8wYXx/qyYzrY06fWXAd/AxEqpgX43whRxLXOf6tKLvIznWX7Gnmv+cjP3" ..
	"CjWtfvWpPIUbt7BnQ2ggd1NDdn3EvXi8AFbb1uwDEkUwZ2O5pg7ioDicdR6/xQAKUArQyGddpr2Pv80yG/uaS116+T4z5nIc3WL2" ..
	""
local PAYLOAD_P3 =
	"T14Y/AElOm9WzpjsAcLVUuvGC78t+wqSDhCF/3JoHVWHKkC4rptdr9YPSiYTa101X9Fd2vU3BiW9VAABPS4Y/3+LRFLdNUcQG8O7" ..
	"jmKdnOfst6jPEtODkkLD6naYZaaWyUzKH8Hlz5XPg/BsdTgpCEywFKe4cKHWuRAG2OIWuxBtpY5COBzFh2B+agGXzMBkT3eIPBg9" ..
	"o8Hb5qCxCwnU+/0XmJ9rCJDobnjDivvVWOsw1IBWsGeDUxYp6ulx7Y6DDEyjPDAzY9+NP/3j+hAsC0Nd5qo0xWTPzrk9vuliliGm" ..
	"1gixwOAWbuFWxeOMGYOrCIEUxPrnSYhDdvzj81Y9QNhnu1ublbwwgNN3POy3G9alCKeCl2TX3Qkm14962aeJ2WzBBghlqOloHyMx" ..
	"FDpk4qhMxAEfaIwzkqCQ8ojfvLEI3dfubkt4KEJ6W1WyjBSDJhKjFCPi3BD97YGaLZqU/MCZoVBjJZqFs/YgWWJ80l8D9JxR+aXN" ..
	"2GgJjRfothMEWn+pqEyJiaIcH1f6L6TDZE+xoZ57bcfjF5HjF7LazSemEUzeK2paJ2MLkzffEVIMD6qzrvv94ernvAgWqujEaUU4" ..
	"FMAHTjXWGj/KKKRpjKk9o3RRFegfGILibjuoYZZufHopzzarnqFZc2fXbEngb8whqP9b+toGK4ZUp2ojWQI6fH37wpTzGHmEE7Ec" ..
	"NLcoYrD0OGWoqCPMAexmaaVVOe7L754qmRu9tE/MEdciNwnrULcJ1pGG0M7I6Oie0djc0j/rpOljc51BU3hW4dG4rKeNPgPmDrDG" ..
	"5lsRgNALi0K/pSLlqGtRhhewYTW+Syv6Cjzp8sOZRSpqX0oBsA7JQEaHWHBFUW3wFDMpVQuHItN1LNJS2mZoU7/7L7AYbdfgSsKc" ..
	"xU7xyUlXCrjd4zfxodNA3xZxAyfjYSFt4Uw8z3LXoWbhJnu5tmx7F90SFYusTYs6nl2Gq5ThVeuo8XdqLUP8vcnAQsypI0U/yArA" ..
	"JEWps9wEeRT+2DVYYbRHeDVy7tAjt9u8nqEz9yPmT75neBGRgr+5K159ApWrijXoYHTbtGfy8XOKiLDpaMpmitDhAT0hiEvxs2s9" ..
	"Pc6fUQ3fatFtg0uX849XwfGeVYbSmAOaaM9rbiAi0xYcrTgBmSwqqOlKEvUGQdqaoM3JKpaQabog6UfAyX+JZEnn8qnTpjgbuQKX" ..
	"Vaee5atfMASki/Oi6PybFTH6O0t82+bsu5MXrnwjAb5HH/EhTBlQKeRp5G8ljzGHBzo59Th+LYWheZ48VrvJcQXYERi5Igj6RST9" ..
	"4WIchRjQ62BmjjwMDFN4rveKIjCjua4hauf7LfVHs8GJjPI2VuRhvkMquBXX7+bv96lk57OlH7FHCqWFU0o55jQmJrX4RcwBaH/2" ..
	"9L//3NlkD3yOG1Mr0KPGAf++2YI7g6IY/MbwFcb9cajqvNrmQWNcX8xLf2GP5lGnnZY0wJGAG1JuecvPBW18xjJhmIPlpgTlPP1N" ..
	"Daa8H70Q9dnzxFWkinbiVTqYhTC7BwpRcZVQs/VGTcYGQajw1iKjLxFnWkFbHGDV3z678yQtm6f17TRnB8TYZguMl8viodw4Xw4B" ..
	"hWK0yyCEMPyLrBoFjTC2SsJ8tnOh1eFhPC/Fkia0Q30FCV7XpIT3e2Ot07spPRkNo89v/uW1aARvBljryQxXtBeNJYpAHnEErPgu" ..
	"nQSNt709k/wECfqw6BjK/QpvFTFKEewCtngT4JXQxvt6Cr4hL1f49NZ0xZ/EZqGPZONKipE/81HyHbWjttgSUnEK1qp134FafgF3" ..
	"ZEeKDtpnXJOvnqnT2eEHGeS+kBruIVsWmIhbj1G5hi12/mV9VUvJeOhKiCNSA9cLVwrfZF+gAQTKZlFuUnoIl3IWKZ8uB592Oz/j" ..
	"7ti2g+0XlhyQQEbsYCscCrVf4s2DlmF7ByAWGaaYC2IrIZsRNLqkq8y+DDHQswHo/95WuFyP1XvnzoC1imiKFi9AzXAwOgkkmYGb" ..
	"n+DPB/7OqQ/NH34m9Kbkgv1by8WfYWa6/XVl/zTsEp7MTgjbFXz0NKE3X1gmk6LC6o54w5ckX/i3BUeT34PQJ+liWbZ+/3X02YTy" ..
	"FjMTviEWulK/z/Vx4fN/nVSLQgBJ26p3/PD/xaR9ilr/dCanNCI2Vr78CEsXVZVlehhLrCt27kJg0nPJyeaSi37xgOOeEFPv19l7" ..
	"48aXwZ+HALajSxWrjFvnwCnVm/BtaAZnL674/P8i05DFiPE8ATqJjIURdkU+SXrT80B2Mp3ZReYYxX15DcIwVp8ENI2w/2AINMmc" ..
	"c4PY5kH0iWn6k+x5uXaCUNdFBk3v+thwydVqAN+NkWWlRk3K1Q4mS2+qhhr+XFXkcOEX4kkz27iIxZ+kC64aDKpPPMaZfsKbv8U5" ..
	"rK1ETXUzo4Yg+u0rRRGIKdihsJA1A+3SqmhsyZd37pDXf9fAC3YREFqUX9IwRCQt1/QSRd30vk9aR/CXQgghYp7DEjQ0gAsOUQQD" ..
	"0+oY2P4oel3leH0oQTbj4S1PwHy3t4zrg9nv/WA2vgQKBQ0vlvsjRs71XTrZ3vP0iyr6b44Hy6CegMNii+DFoc6JipiDeYeLZrKl" ..
	"Xm5ITum3IyfLdtXNd6+D51aawijdTg6y+pj9cj3dQy2JKePtg1skCKVxCtN15+vcLu2/IGynxtSecjZUQ4OPzk0szbO3hElqRHl+" ..
	"2bD9AHjOjeDneRWJ6pWVaz8nlB292Sfqyi7ga++aIlVR2FBF2vOqDW1i07JN7lzI9aM2jOFruyIgtm95aXsJH7biKt42CE0wiK0z" ..
	"xBClIHji28EXOZF/Qn4md2lIijehzHydnNiyw/Wq9aTNmHvPexxck29rLTjSJFCGqennOtGd6EOqKPDSVJSk01ZSu0AuCvmXx/Yx" ..
	"CnK1Ti32pLwXQ6mdJB/ISSI9zm8n2KoL9qAlnm6uitBk4mMFLke1eoCkpoiuxmmtzWmDEkbZK9us/gdE8NYt2ZBp8ze3N5IN1PL9" ..
	"OlqGd8HgSNBx9kcXyZJBnFdj2u5mOf/l820eO2BnXocnwAZs4bJ/U0DMr6ZC7Khz4h7gWwqt9Ow7/DWRMhllGxREh8omDVpFiWx4" ..
	"QJMZe42CvKX3nDE39JI6PQYyOyA68s6EhAwg8CuAaJGkbykuVkVMTuK/M78vrncIVKPj1dJr9EQ/IrqKwG1E2DFsc4cB3ZLrSdRv" ..
	"Xj4Ga5N9b3/d7MNA4MYMEZHE8fJkNY5bajm/pNk6RXpDpo31LKSVEW2JkP+Yu0XzT2lCP32HLyGPvO2BmYT/cnoDwJyj/kvqglHO" ..
	"MnnvTGoq8DawrxJZQoBoCERY3QganFHFRZhADIqFPmRwOXcY709edLHnqN3CB4zIPxxaMtjERrkPckgn8KG0hbN499Y0aYJclE7V" ..
	"l0nBguoSNZYqSQvTgsijnhCvoBSHujfoyMOQax5mqg2aiFwH/6xxHYtW05+BFvDfz1sRwSiNgs5oPpSGCt8viO7N5hRl7h/f58gD" ..
	"91ilkEdhfaUN9KzAvtWL9NChC6WCCBWHup7F1s5vWyuAaPD5elhMbJe66MZtfeXWPSoEilm9x0NyaGewFXNjsXHjDQwvWtKmaIAd" ..
	"Zy3etqPqGhkRuKtDLpYpe+AzJFq3XDuaT6fgIXQIcEY3y3RI/asGCLiN5MlGPK8jvmT31o0YdR1lubIwkhQDq/Efzo60pLFGrXIZ" ..
	"vhn402aaRi4t0nFb+8Onm3nTgMjFbDQxIORkGTTtGMxVAl9AKKJeH2Q/FcAf83phtfYKtLlByLVAKhtHsERv/Z0A4EgmQjsfYS4G" ..
	"cnu6SFEV0YGfMDSZHNSrGeFJZAilONkXRjlPtLQnsbLka2EsBBCNQvuuoR4Z1rI7S86uh1c7SquJ9/K/9Hz004jXXO+8cCEuNztT" ..
	"r6UktB95pqOKABNdZsa5HsIyaHCjzP2MotjCWawc34PiRGgQQPSn4eSINPjCWVVdYy2MD/1nHDr+NmsUrHwa2uOk1pddFQ/0VwW1" ..
	"ruTWk+FqW3ZCqysrK8J8hLlQEXzc8L8X7rhoeNBIOGIjHXCU8EYhczVraBpg1v1p/nrzA0lGFEiHtJKJvLEJRWN5FF+Ht5WAWn7O" ..
	"80MZvlaARS2VhRHicVsDZZxDoivmVWijJ3c8hUEkdypmoYvhNlrYCPtQBQeh7JSXURjiO9snuFsOpu/ujmZVg7rhHIh/G6iwVV0t" ..
	"R9yNMXvtTBhSd7eA1rHiLk4oA1jtpoUPWno+B9H6Zzylq40NB4PEIVdX2/nIT7TraG0RzsX7g5Lizdu3pQC5dLWigijoZzrzrbyd" ..
	"0uZx/HgFoSFwRlkdkkcNp49pUIPqGcfEetdqKdIOlBTtN72iZ4IiBCEFiLnBYE6r2oDd5Unm3D1utOFLS5LGrQzZo1UAcIzJoc+x" ..
	"t2JtAFnU43bw+//2evj7OiPPkN9dC2C/UXMr7sJqjlvQjMB7rYes1D5HyvqpJHaN95JuRwQifLyLrUC5ZBba5Urhxy6p9J2KK5eQ" ..
	"mveALXATpb/Hiu613WlWbfUi8WyRt3oACA4NKs6iktNX2VStvRRgZOftdEuDcxwgSvQFYbYs7Wc5sStPGQovC4q6Enfz9tFnY7Du" ..
	"H76Hg+3bt6KtWBzIP1CofvXQ0H/OR749upzLrUb+JnGOYcNDzXJtx0/iobvLBvnF+oxNWHbWOC9n7uQZi8p+viCk9w9fRrcLepZI" ..
	"vx1lb4+Lx2H7g8RWITl5VTkDIFvAh1+ydBa/AEjFQ2hWCgspKUjDU203xOY47RUOUarHRG7Flkb0ZyfSTue1Wte8LeQ38T/5a9O9" ..
	"1r0QQfvnHwL7yO8z+wMoQOqGOgF1bSRRVmX/SLqgpMTstZ20ZG1k2uDKJ5fsQ6MkazhO2I7NCFEa0Bx/BuoNiFjyY/LDokLeWUxW" ..
	"gNjfCbJsKeQQiyv0dJJZ8bRqDxbHqF76VvRfAH2I2fyMO3fvV8nR4t3wv7qvIaBC3fln7k1RydGeEm91ueq6Yj/N1jQCMGbUhSC2" ..
	"gTsIGpGe+YYxd3kLmVfcm2/XYChm7mQqiRwlXdpwv10EqU0k58y+M4AG6vNc1sBLHEDYF511LIOlhwmDF0xYbxsXFxabhQ4xlBtZ" ..
	"8TZVjw30w+tA36MrFDdShRjV7XGO1mRfNfOVk3hpW2ZfctEFES6WpQS1i29CDUTDQxRlQy800ZdkHpp1xREsfJs618S1ixJ6N5Ao" ..
	"mUUs5Y/ajGwy8+YB3FyCv/dLMgyBtxrpclLNpYx/lS6S7KzcRNAGSDZhga7fbsHpDX6C6yOYqUkeTV2pCyqmqXtEqOwvNQLs08eA" ..
	"l03F+4O72hoYxU3rDkwL9e0hWBqcoxjLjb3xOnNJQ1NdQjUT87h+sZOy/FsRHlwRJBJ7tUh3Z9AMQuaraxzGtHrP9HkJaPe7U/GQ" ..
	"tvBCLfBUnE+rshzWCRRS63318hMzWeZy68XV7UqblwwwMVbCnfZTheBdmHWmiD0uHKCD8HqRCfUFbq7yKqo3JjGHn3/0bMLJJJBb" ..
	"mJeNZ9rvEipxc0wCTvyVN0yJfxUNsWiv1VXsy2AabQdzTUUQxbLok7QmGGmXLFbtDVgJp5k5Ff975mo1ZMb8EQVtO4Zr0h8leRtT" ..
	"eqwXF1E2nyD1VB/0P1AAXdpNFH/Ldg3XFFjDYXX0p/U226NW8BVuVWU3emi7J27tRYdRrhw9ebnjqqhZmUt6lcDrNWuc/DYag6bS" ..
	"Ua+XtealwLPBbFXG9RqVa7UDcE3Pjq9bHz4IxLWkyihYXJ2F2N6rHilZorfGsHQq546CozfVLBMy4XAYVU0XYYygH9P+JihMBa9u" ..
	"Gc5GqeWzeewTJnEqoc+MEcrdRo2M0msjW/cjSsqYSaCJUsPX8I13ZMNmfZHbKBJFg8g1jR0sNV4hSMDhLF7xOfIfac1aVYrdbNcn" ..
	"gqp+K5D2zNKkuDWFt3OOh9IleD2JfO+4P9KoWV0UabkNShvRczqk0ll32uDIKeVo5qyNobsR64Lc/d5+6CRy4n2x+ybT28a446Sy" ..
	""
local PAYLOAD_P4 =
	"++0QqQ0dNu5qNjAAZWrWdGVqgnKrdz+003x8o1ga2DgoWTOb2lNY4NygtEexVH5Ytf8ZrcJegLldSDYQxh647QpsjvXJeu4ayRN4" ..
	"meoNAE68us5SgO5lnAf3OMzSgE8uyV5yg4gR/afM/PaqRPN32AlmuRT68sQCT1PNFI0M1zCVyMVXMzGXDDItt1td/oxxY1czL187" ..
	"gJfxaiRD6h4MUMXC56T8Oo8Za46qRV1P62eScHOyCJPtwdreHTvxMdCOaV4mGGB8x2Dt0ilmw55kpYivErPvoYmaGoyzlZyjs4Pp" ..
	"MnHaIGrOdDmu7YQxKWaEWJMpZ69PoDKfqARfOlHFmv534BEJGzV3X2GRNKhpLlvm7FE9TfvepVbSqewENe9EQaTrrddS17vqZJg+" ..
	"S5QLByW2eOJii8Q6f1AK/Ge7EQ0XBAsxbkDA2uYibCS2Bek9iV3lITS6tm6sJO0XGjdoVRKLYt8nf5ZfQeM3895SoGJbnIRuLXjr" ..
	"ABC/UHK/utezu7aIA9538dZmxfwn97X1Xts6U7GKR4NMLRmaSg/7izRgudNB958zkA4wuSOYI7Sa819UNFBgrUnf3haFYPMRnyI9" ..
	"1ZCXmPZitjvBuxBNnUJtLAZ5RX77BVyBeRWXx94oKzlACB2+XZs8usiqeeWuNFSrcDsQD+WWUERHP8M+BnX6jndFQZ/FE/m/YzNy" ..
	"0dZfmbxAsA6vnUUx6qmTGi9atc/2SiLXPbKxlLLrmiePDBJHbB6rzQNoHpGBHmzpfEGY4sM/6XDKT4iTwiAHvQdgXowyd6NdEinh" ..
	"tdi9b/roUIaASzukcROKe14cphG4ARxYF01vJRrbiAMTTyMjEluIusC2fVKRyKBC97+Lo065hNV61abLB/0Rr+NsyNX5HMtEyFtv" ..
	"TDSQ5zye+QYnGicg+lQxQ97RYRZsftGq/sh+uj4fj8ptctFPCoYK5NsKEVwiqbmyvpZJwhBp9LxDzkCH+kbJRgbM6uuVLz7Uf8xH" ..
	"d/whB1R3+LzJFh7B9rtIv5bXO7bUef66JFTDlkklWUnCsV2rFGWWZV1CpOvrMegvf0Pm+iwEyRqvUjaZ0Gq8xLWJzPWVr30DEMHF" ..
	"7+yErqRLCGwoHx9/FzfXXYJi2IJEIa09gGRfWJ0arKtk2lhqyD6KYsNLOsAlOj1gMq7QB2pUVJ+D1CwHq2YwKus0bnrDKRznwnbd" ..
	"qSoR1vtjB7LgOnA+mxxGlmKED7Jq8PYbSbCKwLHpCxfDo56oq3k9lmWgqVHT605WQRADrHKhNph+RgKKIbbYMW70R9dzXVkfpdbF" ..
	"B1G7AJrZPkhQ1MGNoPu+xLB5vF//+WQPzatx/0y+Wmu6+RHplEq8wMy9H9aKYAlk+CilC+gWxp+GxlIHWuDlP/JgO15lR2DIlHmL" ..
	"JN6hSQ4zET3YCXwoSDgEQ6MeL4WUKsgBl5DmTI5BPOB3hTXwHTRgCfbgaNewuuaNXcSosLS9MTJDqsQyAdV3LQAFP4WpGhJtR6SF" ..
	"JrYff+avPvv8+eHKRKeg0ViUdUEYKxbWG14WyIFxLkdeCHKVQRWZayHTtL+AhR1erXDHE7GcCikwHdYExi9RBaypSTBvqbHiEHvj" ..
	"lnQNfeWTLm7kkwmJle3tbnU4TGJM0QBOf1IlH8q4y5t7pviMr995wg8DPIVjeefknujlXO2CX4hlqGiyOxXHzCvQvQ2tehLP3dGt" ..
	"b0fSR1vV/d5z7CtiSibPyvrxu43id2msX+mmCrHoqxVQCDOBItV7yYowJdd2lk9GibpPJZcOhoUkz8wFeLiNF00y5oh8uB4k50EQ" ..
	"w45mthnvMEpyhNNRAPZdBp/OdMnyz+NJ5d9XL3BuXV4SmmS9+fsvNuaTXyQYVStGNiICHocGGNyjf8Cejo5quWPC+iXzPTuiIXJD" ..
	"Dp0xMdY1xLCrPMibSL+LKYTu+Az66Ueb7ECQEHFdKpFooBV3Lp/HPbpT/R20ySaonUEBtn0vtghU34wnEywcmlVwV2kmSVkaC30f" ..
	"F47sfMmwSOfFxYntV9GfYBxW9yt37fNolPDP52oMY8Ul+EdlVetF+oCRt9LzAYu0q2+EBC/dY9XrxJ+G3W2TEMC2yzn7ROpFDcc/" ..
	"sBqbvJoCdNJeYo4DCKaJQRQFg2PqNWg6S8zFjY5GNPzcflEYVJszVKQ3qFctYH7MG+caeR3XqmrZDkGRABA7Yk0Vs9BVqdiC6+kz" ..
	"O60OcmijYqliYgYNDXWK1lCbxH9Y9IXAeWbdB1NaOlQyaKNF0ZgPiY4PgL1qyWfKG95MaVGXkcPCMdRVAyUDcay6yq7bY/d99yMc" ..
	"L0/awHCzRFKlg9zfVxZIBKRPR1BuDA/7A9Y1KfI30e/NPbej2EAv73BMYn/Ay0bpuSJxmPJPTd8UaM3Yj0lLkCv/lRdvQG5iDOee" ..
	"dLPHVJIUPDROQ5kCLd3D45HwANlI6B8OVpau2MQFoSj5JYoUZDLPsgvEqF+N+VDEUdwLSNWQR4vrc1ECd2I2tcejv8LI85cXPQmv" ..
	"bqOC33xym9TWmJIlHCwQuzEtHzAKKH+cXx+//uGFQkOoc/q9JyGseSTVcCAcVACAF1gSywovFZdUlKDIvSZNnesTnKTbGWQf1Avp" ..
	"sRoLGLy0mEdbCaFngisZHv3gkF1lfCLoQSULSwc62+osuftyPi6z+QCsENOdbRLZ4pwSPFJQSc76qGvakFMWnGBjoorYRc4+3y9F" ..
	"04Fkm8U5x8xKIJiyyHSSO9sRb8eSFj7I0wuvyVjjxW2vZY6IrfLZs6oZqhJm5JnYNDFhldZE7aBSJrIjIZV9MG4SWApnx4BnOkKN" ..
	"tjjuF29ANBKvuCoSRl6ciHQ80wcRooGKpzMQRaTPYhBQTK4Ivglie1/0wFD80ukblf/Jgel8r/GYxirskle4kD53h0a82lnPqtrP" ..
	"B6IkXwIsDAEqC/9NgUvX4cAdpi++QjQ9Obl1yom1pIBccLZD+TEwZydPjDLaEovTgbsa/6Jb25sl4uIDB7TtFOsPGYCEQ4+KxGWH" ..
	"31FOBLF1nSPaBWgUy2pY+/Yr00O0YH7YESevPhwowDk40zO3RFahXDCttFbOK3Zrha9Y614m2a0QKNt9USib+0pdbbZNDDqEEszu" ..
	"QkftpPz2RBG4yfdvg/xaxc5dxfE0jrgvEfT1LjfiuQH7caE0neeSCXJNVR22uOWPewDACnhLk5NztjU+7Qq1Ot058Kf+Wo2DTJOV" ..
	"aeVoBEYdLFpB16afGyJEiArU/AUWLssYL8CnvxDM+u4a7bcnSXpHGCL6DIWbJWDoUweIlmvnJGfN3M2jpJqS1omUQL+UwvIL8YQ3" ..
	"SjnZSfDRtNd//BVSWB4yvbdSi/Fl99tE/cCE+Qet9WcZucWumCvtFYh9s1+7dQ6vAvn/yEFYbqV1mbUucNvhQuu7y8Q3TlMjG3HH" ..
	"UOK3LcuaJGJLQNDyj5udOEDk+5ch20zVSe4tLLmvOaXtzBv6JSdTXwZKL8LIVkSNNr0wP1NV4bmZQejMOFrNOsqDD0jA3UQSsyKl" ..
	"4EibxEPvNyRzhaUcDmSjf+l1gg8ySqOkbcnKMZSnb/Foc1a09R3o6+YlMpo+41r2PFOzHnq/65FZTQDRTFaiNDn2+95QkevmaKxd" ..
	"NZUmdhU7w7LpQY5r8VTX10CW0nAuTa/35Kq+V4YwKlWYPhZ5aEvtaUgnI/onxADcZfoIhi+QgWIXr8Ff6CpBlEBN7vPtt5tbkagE" ..
	"J9IEQ4z/GEcZv2f6p9SmIv7FqkKvMW8IyIA7YSD28cmvSUULvEQgAWLOJTZETefn1VhuNNHipeKP3mi3tAwoXSHptAU6SfLYQASx" ..
	"y7KvJY/8t/0Zo2bcr2pVj3lnEH8rG4R+SI9N0C/r6H95pOvQhym83IUVaPDsEnHLm6DrEt9bTdplUHaxgu9GiLOXz95o7p7w25QK" ..
	"pqqODrS2I43GA+8KuHvEmI5HQt7NH1r7WvF8lfquTRGeaRvLmTPXTc42ZE3MznHmRbXcKLH78HuAVS2qHo8t7qjurWcw1M3suYtX" ..
	"2lqTH6+YM2M9GgyO/ppuPFlXyQP2WcY4IED9Tbdz8R+dwDZKO66XJvNjVHVuDmCHXiv8qajEDRb67VFtx5ZqkfMkcRvyiXQCFf1h" ..
	"XrANiXUGF6OnVqXU8f5eKFb+Lyb8RhAj2fkYMyQwym9pLy3+dCMgVOF5OcASCAPwvDNRB6iCTEaT30oZlG3+vrI+o0XTTci86npI" ..
	"pUG9qa5hoIX363pzCnZYChCJeA16bfMc+gQk9/0QiiI4YROSzmPYpuuIRPxJAEIBVXUupbVV5VI7rTzZQ7BjoG5MvBkTpGIB/c+T" ..
	"j73bMRm2hhv9cSTz0Y9Woj/ew6ju/XoMfliQb2SKyF0nU/rDD4c0rgKhiXc7Sg4COuMHN2wHYyIKm4Q8EomwShsAFuFRn1y3QkUM" ..
	"peeHU+1tOLaSxbvUL7aCMMYhD8mHsYC18IKMypPlsnUEd+kj7Y34faYj6YqH/HwThkyHMdvK23XV4d0plRsmQW00lngS2M9K+GuX" ..
	"sB4N58mGPV57XRMHhX055hVR52NWsJqbqn3CaHDeIq4sJImuHowUCwUg6/YPgt8hunE4Fv6luIZGHJBh8vlUFJj3jJKnz3szbEEz" ..
	"XYAh+8u2gpiRNOV1jWDnElnBL+Q8pBpQNQ23/Urs47jf8Xw1eXKXGz5zSQrQcOjw1JhD2ag3yUcjhbIgffggApNeghL4dARxAsJX" ..
	"LnwKv5z20mpIiQSOk4CK4OC46EsYWCorLKKR5qeOGBYU3eGoCe8QE+Gj3H1thX/gdO2vR+uBq6Vqtk4GlctzEDC5k13qqO6B3RYM" ..
	"+l/KZwtDHWm9s+m8R9xGjbK1G7RvUlvSLT3tSXQNxQVonYi5UldooBIFkZUfUeX6zogq2PgV9eKcsdWB63lj5rp5cjlnqK0yU05o" ..
	"DjkjH9riq8CkZyZUUDYg6Yq9qrsaQ1Xh7NAodHDSilWl8P7IYmdU6LJgdsV0xy76oy+gn1cCj9HCsdtr8Bem8XXGiOq5paoKC8aX" ..
	"BZ0BD4UBNPUBUEeoCb2bx3HhyI7FM6EifBCjf4GTV7dirL0SmQKt71feL4r8tOO1uVi/6O8S383gybwXw2oZ2+5HksQk1wsKXc4s" ..
	"yL6nOYzG7cLkcxFKQ45/XJpw6eikqp09G3UxHzqasYmMNg/1wgSck/E75PvxzX3Jon891QfGQVnlppdwlpcsspUWinaVhcZh6+9A" ..
	"9Cd8zckgoqFav6vtsEFmg1aL/U+4nfVp0sLvaCQwrZJels9kA5o7Eyk7kt73unai9muzbHARXuPfaXVu3KKGEYqR66fJYViCulWx" ..
	"jPmkNWe/F9EBUCDrJFneQwWDHkXF5LTMqHS+hTGLA1E9mKjLYSosRJHkrJNqef10+A4b3xx9R63hg2G0Q1guW51Agi/kyalvmvPY" ..
	"XNb5+TIyMZrG8lZ73ehaON8Fgdl1HlSJQTZUesUhH7DrqNiFPRxlcsw3ZaKPnZwbsdNhnM5sBNRgo4e12Q2tbKlRErA+nkMwT6wq" ..
	"d803YZiIRy05/lDj5o4/HJ0TMXHdBS92n9K4A33y0jlS/PNjXya/xpyhtgHEajPy4q5cVDtqYmECfpVV7VER5g+4Ha2K6HVwZkBh" ..
	"XwC+am9wMytk7VU6x1s+zqGnqx9H/itciclWeAbZmM7EMywffSzRO+QicZRR64MkHte9158At2VHLJqshbVTXbQldDN0I5II+SO3" ..
	"oR8IHHQIUC6TCaR063uyIkxEaIhocwGvyDY/0NKi+UpDFX5L8ChB61KBnGs7qMfpo2kzjFgmd2v6gXO9m5GubaHUHaEEazdGmasE" ..
	"M1KwOpX4fN42UprJYfPA9R+raQClp3hxkUQ+mewWPynGBGvuhYuLVZpRn5QrKDsMfzaOUCAs264dj5jJo6Lcu7K3Od6m5g4dPr6r" ..
	"hpd/elj8cBEFnovkmQqOOSlmm2HMhA5fIk4P5jBRTWnxi5UnIBPaDBHGr93ukqhD3J3lbR7YgkuyHy8piPUBHFTWKbm4A7C0V/O+" ..
	""
local PAYLOAD_P5 =
	"KoqwJIvir7gPAbKi1pwrK6k9sBWc50wU/FO/yg9SEfFiSRBSXaDMXJPlenKoXsRPSSELdGlmba/MqDB8Vihs90hx78wkEN5ABYDN" ..
	"Wbn1NZl+ktCkIR+p/lc5vfa/SUTqCqPPtGkpE9FKy4tOX2MxTKIPkKbjhhOpAR2kqSObQYGeIEle4wL62WhkAuTHR8lpxBNvRuXT" ..
	"XSst1ICRm0luIaVHD8TU4dWB8cJyEcyAv27ASLuPcRsYUbcw7hQHarjc9YX0roKa6P4fJdC8ms29Q6C+gwIVghls2JtY4I4cMwvy" ..
	"PUBkEvQ7JUrbOuafdM8i9IULkMzKTRrwny2nIwJ2EQ8b87+FK6Syxyi1sV/q3wi789Ockt5lqL1ZdVHIbe9Vso69gRUnSJPHj+sZ" ..
	"8zzTbtGJpbWAGVlJlP4ZJbc0XCSH0jkXXxExGufQnDKZB0/MBPbGziN9zAsrFIyKOBXqHRQHJfINgh2fuAcq7ZpUqusLSNUel6+f" ..
	"D1/g1i1xEpWitROHYVrhfazkfYn7xNTouw29btpxyoVNbkxzhQHS+dEyUppm4qM80ERzNuA5j29eVfEh6W3iRcB/6131ifxMxrW7" ..
	"P/tfuXgmIz0/7UTnlsqMRfnWiLJJ7vjdMiTpnd5ywNxQW+obVT26rcHvOgKzfN3q1iUbTn34Wsn2I39f1JO9Pudg66v3ojCBtOni" ..
	"CvJy889/FG874nGZJVZVoAhYrZJ5zdEhqI//eL24jojlYBZZnGD2bfMWywKoRyjozdWGPSpLBz3Po46/n6/Y9bElskf8sbsl0lDa" ..
	"aQ4Tvuq2SOufZQ8xcV8wkjTecB3+DocurzoXqP1NJtLXJErS4XZ4/ZtEAt2ptsX+TdwYST2HsgjVmGVFfh5a7Nx+oQhNnZh03S3K" ..
	"lkq0WtXYFmPgVRlQB4KHxhyJHAtpIXmJ7dQf4nZHQxo0kTb+rN7daS8zkQQR6ifUm64m1uQFYnK02OeHvVb1iXbsnwjjLZ7iW4KG" ..
	"HYSUv63WY/VmcGaGVlyHnYUpSmvqidpKvBwbExakoapcH2C2GPF5Vxgf/Gd+D+SbkVRDioQRQAGWT3zaa1YEXxCtzteUmQ66ZMaO" ..
	"/DpEyhN7PqVORzp4UQO3OEKHOejXkQImxApQ3JKWLcZPXHjt0Dd26PNhIJ0QNgbZ/HaL0vBjF8CkH2NnKgs4CnoXTu7a0hjtKGTn" ..
	"aoX89xRhUnMTEwMIEb24fIk/yXfbqj5u3poULYAxv2Ev7CCchy1HYoQdowJIVbhYZWLa14UUbDdQGIdT189m9mfdhKFyR14toiHC" ..
	"nOusBRMjSf/xQJTM09zqSCK3+zCf9wPpgoAewRk3htARQYm9tCXWPAekdFtJgj8+GoQrHbCQm4LsWPVa3blhF9D/OUMNmhghRk3d" ..
	"ZueSdtLysU3TVjZPecad/g+rwTe9Ku2q2+y8oijH20FNsDcig2c+K71B5FgS2ZIs7AbuLgCoIm2Q8mH/JAuWrJu+obK1oQxzQwG1" ..
	"M6/TJnOObxCGyw4ubhUXAJazqyUKo/5GnA7D4CungxR12lIeXGhfVVnl3ynMW2anSBQXgtvevFwAEzART7xMbNKIaaADoWANLqPl" ..
	"kd9B/lk4jjj88ELn8f17S5DERufFS7JZCbdnkX4LccoO1ZsuWtTb2fxL8eB/4Dcou7btfkD/hNJ7doXQj4XKsTvzba4c3oAbc9nw" ..
	"knXrQ/va7jtlcvTK6KSz5mEBpIbH3THkAUC3KWLOqVXRtgyQVOOtYw/E4t51y1sC2mD0/pcCliWtvJ7CWCVcfCL5JDs/RBdAU+Bu" ..
	"EjtXnC0sxIGDptsryZ9tKqZxmuMo2FNfBQcp/Puw2c7tjvZw2t9YWAUEOJPuhRaI7d4VU9Bcqf3wkqmBWADOfi+MqDkBShWXTxuQ" ..
	"P60UFcAXeUF6GHXfwkuTwbzFZgNot5/znRpTTmMfy0ob2iBpzprxWlExlsdTgpUmMtCbXArKrpDILczcBq+o3aK2oDI5lUU4vspu" ..
	"1fcwg7MuqUp/xF84PgF3WxcWJ3W7DbOICPDE5fuVgFLQGwLtRKUVu7Js+o66G6s3iyYDvxqiGOV5cM/HdUsphA4CHA2SGvtlxTqD" ..
	"xALY+ZztOzqPjMP6W5mDJ9dF8loUKK9cSUUnvBhGMjlBWf5nQVbRp/PKstXqzKnlysgeX0IiUMpt+V1iIpK2uwU6Ybl9Fy5+u3pq" ..
	"oMULcytbmrCdqoTMoy1Y6c1Fn9/MvCYhlWjb6Ab9268IK9MaxR0q4rZpfv+z5H6oZ6fu4Bx24fIqOkybZ6Am7vHFDRR5vcsgpt8l" ..
	"lti36p4pto9aGApqjB92IyTzj5uWhNw97rkVSh4a3HXu2gBHl6UXvoyTSIFvqa56CBD47716g9HpHi7jFoceoHlPHFjhTDecAAKv" ..
	"YQKIiaPS2KHen1OzpUrxnNgWai0PZyoHnTukC9bhtcZY1Dgsc7byprTxSGxfar/TyynKPcuER6U2fc/OhRmbnOLI05/qz7AxfQCx" ..
	"aDiauxJB5xByK9KPr9DR5EWSWEi2riS4eWquQ6X0avRAIz5XFoa8LVO/BKPU80GBClZRgF+Mqb2zLx91ydpZPvVhxVZSODzfbTMi" ..
	"fyx/xQ9H/pF12WqV/AaMDL4hVYBVsA7SgkfTJzV+GZ//Yrd6Hjw/o+srS0/iNNsR4aBZharWyi7da/zeQ7ueG/Ifx7w7LY29n27V" ..
	"kK+ENU8JddQNy/3j7dlXacPg060H78NmtfezpYVNhLq3EaTwKldlXiO4KQUUg8DVPCxpdBnJeSniYl/RDUZVCGYGrmNok9gAduVz" ..
	"3PmCtY1Qdvt3yXQtX3zpUZbX7QPm+xGYgsMQmEfUgDgQk77eGVcba1MIGEV0CfG80dzbSKKJgLF8yjOqnZXcedQKtuIhTNxjCxze" ..
	"3VMBdH81p+a0M/ZMDGIW1VJD6FrQai7eVnaK22G6w3DsgNXRp/lM5tzzCYS61OwbMs8lTaCGcnftqeuAdmVrAiNpZcXF2bbwA1i1" ..
	"3mc9zV5LPaLpMJjLP/SrcFctoDVu+AQisAyALc0LiMEuGMlC2VbcO1zzjI/h6GbgdPg5Jw1TTYRXeWpk3pxG/TFsVV4ovNezU4pg" ..
	"tqfsEw33/G7JY6pV5hNxfRjcs9CxZdJKmFLgzGlDqEBpJQtc6ywuQ8iWwl77fKfJrvQ7u1s5ujeUXGM8zJmOYGRvktfIJsxXRO6j" ..
	"jCwMLaSgRYp2d1J9pDdLiKIYm0snCB3T+RhXtBOgvi+kn0oVVSRgg8iJxvWaRCEFuBZRi0AQtURBkvwvhn22jIhc/aQA/rZMrDSc" ..
	"teDkkjkYnl3PIZ2G4SjzHzkLFva8JCkvNqWUyFIqNZGYKpHtyFgrpJQnrhvc+gYFnlrIPwIko0occhN3Q35yl226IRWE/ZBpWfiZ" ..
	"twc9NmRhUcAKgEzt+M/VT2zFg0U9ZNYWAoiL1BGBX+rr+b3EbIMJDvvJbtJY7MfC9qgQvtVwcXRrrIbOY5qC26G5pTHi+6ydoBi4" ..
	"jsYz38kqM5/ACdPhKbHBgIF6tMkB5TdJlHxcdPO16fBwe/tRo0KtGzsMW8flRNvymwQd2pBFZh7Q3HavI84SxqDECYtTyjyRncm8" ..
	"Tu6y2DsJYv4p1itC0SgYCnUiLZGWUkKc4Inbg7OIGKak/QZlY0fJktddFSLbR0f5OiavMODPoPNZ3oYvRNrVo/bWnVnvoEK4fQ4f" ..
	"zK4/wBwFgVFNNGEhMeuE8lG8l6tshSzx2YwTIuglquhI53w96stN4+AMPI2WN6F+IOEvJuCx7ah1gDxRkQ/mcg2+tgmZ3M+1r8eK" ..
	"IC/DP7rOcoWU8QsYVacuHJ7MZxTSZxezbnxLqHSqJLzMyGobx+OOHoNdYYC3xEhmu6Evi6oW9SbJlpVt1VocY72T2/ElFyPJIcr0" ..
	"lhy1KeUbioIPBD9ZMvNKwouKmeaU7eyYpyHlSfsUMJcZTUuaEEZlWwTOOZmnW3L592udOiFgbscpsMSAUfsPR6qqDu4fKxQ/knxr" ..
	"KuDVVO47tK0wqXkxTjOri+qw/aIkbpptP+2l+6SUI0jsIu68JrUTneBVWSB12wsrtGz35jEOQwlZrHBOIqs3HEsfppFQSUwGMkbk" ..
	"WdKbn1GhvcWLNUI5Ruh8V57x7PNATmqOvCmyR1IsUxM9+Lojh+wpCg+Tk96ZjJlO276kuXu9hgUJk1pGFxXW/U3cxQV+Qc3YQtlo" ..
	"yHOuHg/gPGB2XYmrl55EiAUPxVmc1qgK8IiWnowhtR+qR6o8v6FYFfbxC/awgguQX8MhKSo6jRJwTUYAhEZXQTsLnHzEpHqLf+zJ" ..
	"voJPBoBuKZiyCBww+uu7ZsRvCQLWdr5kv/s4YQu3SmGPylp3zvJ8Nr47UilkQPfwU6jJzlFEanAxglZ/R6qLRg0cnRcOLRKJxGF5" ..
	"Ws2Mm2eMfnfYOOgh31vkOl5KP3vtuE0Z1rxbTfd27yf3DgXmdsSbbFK6uIwO5ojFeBnkFqwP51Ku6K+ggh5OisCUx2RKAJuuR9kI" ..
	"jDtRndXErsFONW5va2pyFhPSr5Paqu0+sdpjIbkPba7TW5DR6VL0BVao/QQmXEElRKFAYIRyFGJrZ/GLHatT+/1jngQpI08rOwkK" ..
	"GM8xTGnd+S/eOaGrgJWhG09FVLSnp/ZJWACWw26wRSkIoirJzZqFeXr+ROSdFC59qn9EqoS9J3kecFIcGTGmXKzizYJkH5wqZGsq" ..
	"uhJNvOu672fQFXgjV7BjQI7uKBZPM06+iA9a/PrkfujEpXkaWNUUgSKCftjmDT05LdURUwORTL5LZUdJWzii5mv9arMkhMQEfNxR" ..
	"OqGUYW7bX2LYY8jCxUr+OfzLetaPEsygVGDHJ5z18t9If8fIPEcebCSYsya3JjUxcjHUpUUxjLdDUnD+tEc/jbAMAz/bw/rlffUz" ..
	"BBpgexMAMIY8S8NZ3hSpZIYLVmCLd2xG0S1tHE/NGu3NV63UX5/W2NRiBehZ2F8RGrzb0BX29DFueICJAO3sZEK9Uk/uzxL+ZZYS" ..
	"eYeAsQIFPy0jumrMubrIp/Mc/2NVu26HbWeiqc8PDHhcrpFpGznb8ro4sXSl1v96xKB0ueOHCMXiScFGAAah+tmoBtsYxQs9DGFI" ..
	"cEW0Da5E9mZ765lEhFx1GFyvvgz6z1J4qbadOLt9GdVtCG2NAhi37nO3kXHeCUG/gOqFRGxAwBco4eXLuphuaahLjSZAqCuy1ZQm" ..
	"K0m8ITrWlMAy/XYNu86CxTsjINhVKBF+T8bAUnzaNyRKCEAccFY5fUdxqMriOE7bLGRhuXyjwJZiv6M0FPf8z4XkydhepelMI4Hl" ..
	"KFHbd2jOmipWooDL+zBVAgALukQMeXDYuq0LRXp59uaEB6/Z3tDvM0K0pYbyL4xp83aHk6xyBlCPy0ZDaYw1kPCqyxx/i6WViyfB" ..
	"fD33tvJ1uspu2HO6W0QX2JScDO0ol6uvASithif7X0VDaj5Ky8k9LXE8ZAc9tm8dIc/389q5rtX8qQLU6qzUUvb+dcLk7QBoPyG+" ..
	"iuP5VKSUNtYA+fu572LYnGYOtyABYgq/aPNTZCPx4DziqXCmG8ZCZRwiDuxl9CcuzD+WxKoQQtpdghnLTJbvZkq6lU3SLQAlKaA7" ..
	"w+EGjcPsW8ioC3L3jNfbl6rfHzipmzgvFVIk5ggNsD/j2x6jpIQIexuTpuwJrs+7ZvJntI8lByfh1bkugNROieJKCEmxm1z+tVrs" ..
	"/PdSG/B+ljgz3+erE1RzJHIamqnMz0xBv2VwCPkogjnSLxlp3F4o0M1CfaonDaFZzgybH3sbU7ZCIR/7Mmg1ixuaELYDEmaoNjMx" ..
	"jX3acig+HIHcn96a4jWG0r+42+rHXb0exNKPYBpKNmzUV/E9ztdZ9c2HcYzm8p9ewb3W1qwdmh5bqb5LarId2QWuIMeeM+7lmSeE" ..
	"ORym3RMFHRqDdnrJUw3i+LT5aFhZ/Nuc0sfjm5nPq9yh57uelGIs99Qa973SWYe75Y8lvN4IdgRQ2dpcsqCo56cUkd7/MGUiLdCr" ..
	""
local PAYLOAD_P6 =
	"OUpYhiDNDWJIhgDbcytGtgyfujKDAKe1tlKJ3zuiHvhaTdu1ggU9N429ZELn7aDG0lF4Mu1gg9FAVc8Iw7RLEQ4uECh2SAYN+3J2" ..
	"rGRBXVKTGhp0e+YzUrjlS1a2nuv0MEkLX6xURQvYygOWj9VZ5BkAQ+kfYEf1OyAiR990M4gODsgq8F/DgIDTto5p7ENgxz0PHmQS" ..
	"Hm//UozzvD196OfXZ7dnjn+PCcaJG3Cyc7VGZkmMeqNZ2HEhhOGZW+VV/fBruKrU23hIN54aOczdMMbsvo8G7kymCVo5mM81yeqx" ..
	"0foxIE2Ch6ddUe8Ql4JiHzwM3NhJcfnLSSS0mCkjdsIZulVCxrZV9OGsq1CEtuJ9xiGKP2M5zApgt6zcF++uIVXEBP1qRwJQZIGB" ..
	"Ngh3mqbnBzPiROw2ACcu2BMGiq/TrJm0kcgVIJchCDKZEjpwpRc8BRoBUFmhBHTBWFBE31VBKQXwz8qaGaih7uqGRQw9Em9ys5nU" ..
	"a2I/GQKvJ0z6qsMm6p230BVm/NEIKEQsvegalV/wBgWP+Oims1gnEC34R0dx5obwQ2sySLq9z8OMydNgeACk8sodVg1172RSVl8O" ..
	"Qus1ji3E5DibvyXcJxBF5UnSiFCYLTIdG9Jkwg92nzSwTw0X47Np13KKLuQ5+SNWjKVYNxS0kpL2V/A4Htbe269yViWL7uCE21fn" ..
	"POTc/fMqR2ZWPW4w6/WpH+viaW3Lknw84q/3Ve83clpBrDrMhJGWxzQX/u+/ER3p3mf9UuEqqKHTKFa5dLyHs3mUR9HfGpCM8cFy" ..
	"Vq0XnWxuU7BNkToj+cDgjIophJ1xec398JRWIFCx1pL8KsH5Tvt8GduVqAq1y6f6kMuRXhYKARLHCGqHV3huDbKRLLZoqEMoVr8g" ..
	"G3xgj0P8Pkf0ymqVwogguVur+FtlZWAspuwtXm6cve9PTPbO2V2VsEr9a15Znzn9u4Nv1qouNpcPFF9lGG2skb147Eft4GL66SF2" ..
	"SMuqpMh8pXwoxyMI3g+9Hpei0b4FZKntH1D3G2eNdSCE+LRDL78WdzQj7FvAfVJmbvw5hR8kau32W2FW44WGCYZAakHf/FVCXPST" ..
	"PAdJDXOP9qrHRHcQ1f3sM6KUeP49QlGkaDoU0ztL4koAe/tQdc8Pq/BIKPB0MVvWOFH4mhOgiizizOI4Z41lStao107iw8CsRJmX" ..
	"lNYQw4Skc7e+rous/8tWS36OG3jkjv5sbn2RAPKZA99T8eAgTbGkL1IsHVaP37Nt2KHXKO9pMH+hbzxXPNql/Akv563P5u9h08Pc" ..
	"XgdWUzj13nMroPIG/roCO9k++Nmm0rFLPU4jj2oXiYn/Yir3Zu2L1nH0FpA2KbDoIJRYmXuWUNulqJ2Wd5QCGlp3VFy9au76Mvry" ..
	"eJg1Kcaawc6PjbKD5r1MpBQ02pYRjZJzITPoX+YbQwWwMpZXwUIHl3ADdIwCiD5GZ2FatWFfeDbMpCeMrVJEOwUKdfMCSeClhaGH" ..
	"m5RGPbrErVptygmmRp8WjqZKzVd1/hIeVSOdokXqT/3zSExdcGo7SLIoTqF7Ox5hYc3f0V8e/N+PJZfWW3mKR8yUbsfYFhL1j8xK" ..
	"wHYwHVjpKUP3y49alkTmbIBw17Mgik7T8Oyjva+Xr00Sks8oiYX1ji6QtPxPKSejukUgicYerrZD5h+pt+zak0d7/RVE93AwFhLv" ..
	"R81GHgumXL/iCjcjYEsbHB+dFgtdri/hBoNIOJV1pPJWwm75rc2x7pbPyIBxnOyWyuOqHXZbuDJVnoBXgxybIbG0XNCYDKg1hFFE" ..
	"wCejLowMDtN6xN4mFQtWSoLJWvaF+lhMB4Nknb6GrOpq6NyWI+fIjJJoD91lhrqlziMF2k9p+N4MXRbeiOWy6MVpGqVYY2dIcLTl" ..
	"/RWeAt2NwBc5Ui/UWJ7Is3WZ3xPCgeArwtF9RZFOU/CVORJ+xBU6pXMYQJaj/vCX9uw/R27QUe/boFt39A+w5vnkKjAZwH98VNRr" ..
	"hECdIZPj/wuyxW7crYL6b+rhmnZ+75b4Kn2eWmk7Iu/zcAc/PbH5a0WZT3RybX3GfA2ZKMw38ACghOsmK/kVz81j0wF9dzjMn0tm" ..
	"cQ8Y9Y8xPjicVY8q5d/9owNJOqbIMfCiymetR3YqLqsCxyhLYZexJ12yMvapW0ZEMrBz9TJ60tAI2k3VMhEdAkIn4A/wfkrgKznu" ..
	"7G+i87HnFpA9PNhhl+U+cj1SFh9TjqaVvxpfDgBIE8WTVCh+MOCSnEPu92Sws5A5nqqUPtRIQtGsyS321XHxu7Q5BYLKrFVcGycO" ..
	"MlCNbbSIf0x3/w0WrraE7AW0cRUz09yfB6KTCQSyXpRHLz8JPljLySNA0IOg1MRpptxAkUltPtf3qK9cZ0pcGa97e75wledq3YJu" ..
	"WsjzU4DXNcqrQ1La7dcZJ4EXUyBfGKqsrjjAWpQOLl5Gd0WAccS2Lqkx7Gy2RmRpuIeOYhmJTcAyqxcqSVFdX5wkZWU/gp1y/siL" ..
	"g3b1O4bCKI8/N5BOLTAY/OhN+bd85G9EjAIXYG13qLbrklkC+GedM0E1fSnD7J2eqE/M1kVG8AeRArMMnt69rOa72IIUZY3WUV/x" ..
	"aGs2WLvVSAMmdQGomZAYNCo+3vxsYDU6C1kpe/A9UkEFYxNgbfxtxFD2yWi1UHebRFxEikiYxjIJ+087Mr0jgWCw+BNk7KtiigSd" ..
	"ZBcyLYgtJgZuHqT2oaOt5ra6oEnZWZycd1SzCtOwrecmrrRUnMgDThLRLELd8xzf1Rdt+gPWZYLuYsGQZgGE6TL3p9V3sp8c39h+" ..
	"/feBo9+g9nwdxobBtQvh7CJyUyEkk2vKEuY+QXuCFwooF37xjNAufCE7zaPLfkufBVvvjqJbVFjqWm4gRnzTSzqW9ZPunm/7dC1h" ..
	"jh0uaf4lR648ijxEZPzDi70OSqfP3a2lUTFOQ53qANfzsmDsXNg1XoC+sojAwZURd6EKznLJe/x4nHoLjyEvrBg8KUtWf0otTrXG" ..
	"hep3A5tjsDHy+/XX5EDGMWL3Q11wNlPsgy07blzXBHzae2rZQzgMtuA4oGe97s4brz4RXmcavReDelbSe+JXPxdkuhEWs4Eeis7r" ..
	"q4N44dF521x6HpMoZWlOX0vy+uUPE9j9dniAdTXc6DvxzTHyJh72IP2nZ/10nf60bHyTDW6ADYNUF+WabbQOfvRXVNdrdhZtLKQz" ..
	"R33lsuqhZkN3A27fUgxm9HUu9NCkTM4juhrAZXIehlJp1t6Qocx+wzLSlF47tT+uhKCif5Anb57CYLari+s0C/Grs5kvlRL2Jb9J" ..
	"SSJ1f6KhvSvZE1Yj+HRhirxZobNowoeOdSwAZFvglsP7Ixe9QCjV4BKC+gjdv4Aoi8612M/Aw8DsEUFL61VJJt09rH8naD715Zzt" ..
	"STJcGB6LK2WwpulZ0nQ5lqVN96pPpXrPKCgP5tvFVyCrDuzm0OfzNuLEQpc8yHmn4pek/7LmHEwDVJZ9Nw37MswDe1Hpu6lLl6jr" ..
	"T5Udad9+YJvDAoj1mZzrRZ+LFEktri+R5LEAMnNX5EbdrF+0wv/eBpPUud6VK7Lrzef3J4JLD4zls/19x+aQ1g8kEwWyt4Y8J7ux" ..
	"S5mqw4ERS020jOU6gUj5Z+ZK141xfNePhdTTnvgxtSFc78oiDIg24wbFuJA55cQ9qA8nmJvpp5R2/fqHD8CJY9QeJpX2+Qlao3LL" ..
	"mSkCN1Gbe9XYcq4Z0vh98jQ/v7OsNM9P/oQxHFVUY6/9z1aFuV6+xNLo6SWdQqIoBbouq1m63QvSpDBu/PqkpetznOjTv+kw4c5J" ..
	"ul+BpV8MHXYzxrZk6H/G3z5m9psDWXUu7fv0f10mv4RIKG/srP+x3f5ZMmPo9a74Siz4ohwyuhdDkdyxUDBn3eHhuBhUGRpiLTVV" ..
	"Ms4F7TqeFlIgGtNNdxiHEdDk9nzBm+35F2QgIc+f1WX8tyLMq7KpZgr0sF8epBfRkLq2yzqNOf9tS8rXr/NQbBmw4TTuKCl1dW8H" ..
	"KAMV1nRa0QT0vM5sIMpBF0E874pA73aScB4o9HS/0VjRY1mpNH1fq1FnwqdUkFSWDIeySI5ooobdF6BwhjgafrkfyNcnI+5auRXi" ..
	"ab7Fffqn58BaZG4EGvqqo7TNthmAgEllwILAw9OcogP+4cuJICoUwPZI0hAT0mmTVbb5VdSDZkNhjtCWKY88pQ7XVxbXxmVHgOn/" ..
	"EDS4sOD7lYhqcMQvXN9Nrt9F4Y8i/T4dwqZC0o0ZZiTFA0wp8mmoYi6yXXuHEEJP114Y8OGs+8jHpmXZSGmaUxlukxU44kV6fq94" ..
	"1wyG3EFG6J8CKTNrGtKvZyQJSUu0ScX6ZH/4U7bzja921w1f09R743H7QRX5dthYSoZemlo9+/aVFQf/K1F6lQFSdVLGKnga6SgV" ..
	"erBst3KiIdiI26tEhw0stspkBt+VgfkSjaj/H26shsyUyWbvPtm8tvwTS6t3dTwwGyDTwzwKIgJv74X1KJR5gg59hxrK5Vw03HyF" ..
	"oIN8xvfxkjpi3jg+aYsVIud228T4IBsbYNHPnP3Mu7RiosYP/JD5csWyNduIExKVOxdR5mwU7txrVRUjsOKTKixsPiBFqlti5FVl" ..
	"ZqUVuICGVrh4v3AygQv5TRG7HJIef1ZJO8u7kMGgjB0N8wRXwvsAxs8/ICEeymA+4ieGJ53dudMbI6yUEKwcGbLkUvQVn9iwJvGh" ..
	"I+yrU5LxRCAMKpqaELkguXHLdKH8xL/TZoRQWFDUTX79lm2/RYKOH+rhZSIar252zRScZ7L9HbNH24QgoueZMB/E9FqgwxQ6K8fu" ..
	"UFXZbRSUsDE4P56MlI0l9Ffyo/FIpYMqBvvUd8Y8qGoBISTXjlU8V+CllQa61WW0vw+MgCmvUX3BwrvkqZVB04smSG0xCMgBeTmG" ..
	"a2ITKvvqPNZZtiKAJLrAu0J4rcsMonCDb9C7Pp19NxR4tBBnxJ7xI+t77hQSAi8OVfrDcHeh4OOsoE/hb+DvJXHkpBM95hv20QFI" ..
	"FVrvFxsyd1Zit4oWMM32Ks6v97IIa0swtm8Hk7DEiVmpXDQe2LJypJOPUt6OQUmuEyWeccd+/e9Xey3kHKlxfZzzt2Ej/5TSgU8b" ..
	"URX0WKRk5/EJhns7IhNzBnv8wKciR5hCgQsG/IdaoPOOLiC17KTH30U7ObDt9HmAVOCsFB08ub2Zv0WYPMs/s5IWFeStVLAkTjfz" ..
	"WCWS11SQv+qo8KFX9CKUQkP35kFDdW8UXheQlbdlPxHDstWjALc2OHmLu1UP9kV7CHsuFYJhXFNVkOfRt5TjoIfmaaLvEkvVyHTA" ..
	"Mu+Hw1lis3EDU4EU8G1Qs4T6ki7nPGBLq5irtz1578KXEE4TWQ1fhB8duri9HKJTBVfuBcMITxRirOcF3HwsK3JiN57z9DwiHPzz" ..
	"lMz1CGgGH0Qb5n1zzJu2OdOkrrWFJ0/xdj4vbp+coGLShURJRkG08YJlxmlyYMBy5h/DN4e2X27QZrdLR7ECzWr1Z28ydpTlbHqc" ..
	"AlpNq2nC++ynrUi1hLdfblJdHYr3D2BgMWx0Vzd+PH0Y5kJGHHfmK/qqmDp4jxSV19BITmASzRzCgk16xhg7QV/oRkvqhkE6qmPY" ..
	"+7h7GC1F7D4uV7COiImAszuG14e1ZwUVDtGmB2YDcuZ2KhAOiVpHvnDFGiwY5d9EowvARk7/E63MjDaC68rTnmEB3qixYK9jfS0+" ..
	"mg9+ip2TBCeNf1oNDROMOcMMt/8lQ9gMzakWe49ZDGQuc0x3JiYr0PLlzn39uS+24jfTju4pHWxpO9hl9XPEbtT2XmxUiX7Uxmr2" ..
	"z1MJLTlv7+ht3FQB8vhOCQXz30n8Cp+3yzbzhdSD1d80dQZJ1trgwLHWBNrhJN4Rubm2Xj3UjEKuDUAMbTSx9UCrcqC84CXkbEBg" ..
	"FzkDGit+8OsShomBt3VYzEhBpIjpHQ/Yv77PAkGBmPRsCVAhO8J9fSkf/fwEhW5tQkLvrnkFZ4yOxpIJJLgQ0E2omLqF4wpGPMgQ" ..
	""
local PAYLOAD_P7 =
	"weP+P2vhqwAwBsbxC24cHHYPDtnM6UNEb0iFZ24ad7Hhvd1q+KoGRfux4MTE1IeAkCUweVLNuKJyc7fBK4nGIJtT2pY7U3NYssyX" ..
	"rKpdb+zp+OkaVOPkb4boIjMpGTpONHveb1sy1KleZVqukUTZDEj/XFXkmMmorT3/9pck5LzNYEhYFd6Zj6dHBxrLyBesXoRjdaoH" ..
	"oOswJZcTvhs9+q7+ESSx/eQlBEtgGs2PxTRTtZz7ZFgKtnF7mnQFmYwt4lNQOw3TFMLKABeZRZrnmskdiE7kYCCRhSUNlP9uBXcT" ..
	"t1DGwudJZTfH9LAJONCgDnD2mUrDxtmbBBYYr51/w8wEsJvB+U94ZgaU2JgAHiQU/VqkIlT05AL5JaVWmQphiY1/6h4DO+YXiPmM" ..
	"2uG4NCRcggB27duqzNT+5X0rK6uzIAhWA+XzWTgD1fvL5xibE11Ozt4i26x7AUq41hAmxdbFjgS2bj9JVnne8PDB9pOc9h6+FLk3" ..
	"5IyfAYbGZ78KaQn4k2MF6MNKKAL9JQ6VRPjQ+TBdDIfruKW33CC8tHB/X2E6wfB8mh2VP2LX8PhAI+spTdUcPFZVsIZHMXUdgIZo" ..
	"qMttngp0AfNybtXRpWdmYP6aYaZ9nLUtw3pNbUhGVIgL/hAxjln5wA/rvsQbU0ZGmz3PjaMdtkiXJEEvcc8DZ4hZTFi1omJoUp+Z" ..
	"J7wG02l43BcNNFROsAJkqQQv7QjPnunzKfZPzGaTJWLOk2EAqk7h+WMmE92OS3l0LDeITT2y0JFv2Qiy6fpkSqYqO4YKSF8eHOUa" ..
	"03Mw7yyh7DYt5Tlv6yaRmzeyCRhqrUj0nW8ID3t4Q+yyPd/kmHsDcbVQB5Nax2SaF4RUrpleHDfRoEDxumrWCczoMWus09TT+oID" ..
	"/i6XIB2mkVzkXtnnVxH6jVlxMfNrPQGTF05CTqfwpSyWtvnd7ejEg62Yn9kxYjl/GeXdRp/YAabOxmGdOW6GVJWsUyb81b5X/efw" ..
	"rkwpCWGvxS6T2bOJ7fRYT6F4UEgw+zvC6c/RlTGF6iyYbWRWI5WpahXaAzIDodwSqH5MbxHh+NU8QOQgp1WMdlbgFg4FtrQf3JSt" ..
	"kcrE5I6obEg1TJHpijz9XNZxhrzezAU6b9rZT4J0yWAZhJuAnk/innK02yd2mUZcyo7lhKpM55PzgHtAfZwGdSA06nz+J4NT+9sR" ..
	"ClB5Clv1321MWWImu/2dDaemNrqCnsORW2Xw/at8D8pQ2ZQaxvrQ+s8SvLFHIdoDkigkseac90rMp3wnznh75KYdR2Kvb9az6wuq" ..
	"dOSzlSiEY6ClJnCCzXIa92ncgsyrmiiLM+zIOnuXV4Vfo1Dt2/LZJiHbBtDZnRNxSjMGYcGc8/YAxVnvmZ/sKgZp0KJZTtV4Wz2Z" ..
	"C9kdDpbnWeMcqATDsjsGl/Oj3YKQdFvFcXoi7NA7eNEHqTN9YpeVTVxQ96KXy6xJTM+EzaXmgF1BLScFpCSJGM21AV9eQCwkSYV9" ..
	"akqpiVrgb/iMe+agTWkNEZch4r+CPDQjHrq7JZk1oBfXGCHhE2jkjU9xZvJwW1XWJhLl8O8VxJ4Qzbm8v9GCiG4P5eLLwegVxxv8" ..
	"PX3jzR4rSnk3UZaVEmr8lNINENOR7LAD+2vm53ISgN7jpKqC/b8ARQH+5RbBNoHCrt+6zAvxOpJys+uRnuEZlg6IX/OdFq5rS0d/" ..
	"c3+VnVJQ2W1VUO7AyJcyLoptwLcgL9ZLb2AcypM/tRzty45R0OvDqugvKUgm0Q7jj49SueB9HHv8RWBZu340vkwKSOw0V1XJp8v7" ..
	"bo15dp6FiLZ/5cMnF/n8193tNi4YUbyrashdAida1lqRG2JFfMJ/sKkhUR8aaN7IyByrRMqUPFU2XQufNW7RW1xhePgakQts+Ezb" ..
	"CA9SsmtKCAMXEXmO6UTEuInNWP7ZmgvoqCYCHrQqv3xCx6OOGSIrYki59epXkYe5wyi5DB7RRXGR/WnXD1L6Rfc9S4MpDPIB9gcH" ..
	"FahP2mAQ4DjR2wLgRkkTt8YPxj3BHenK8wCgqJbb8F+tCRCHc0uoK8ZbL6VPsVxcLv1hqXqDL2rCgEV/QK4SOfRjtnqgTFBHfG1S" ..
	"uYUJrVLobMFWf2ImNcvkX3FMHyPmqkrm3GVqldVZE3hCJ+PCGo2qEjQwxnRodhIazd/xbJ++qRbPYeD6Zefk5+8GDPDkrwMV7hWI" ..
	"vBXAxYO9nIGkG/fTP+kKRMUoSRnOnczPGgp1QVPAaRRDBgamIMFWngQ1rqdJCQrMC7KpY6g8p4mAg8dAoWw0bBRX89E1IVg0Ng8F" ..
	"bSi66zpEqObEar4AtisdNHPXU1edisXK+9GhNshituxiqpQEXHEmlP/WDM0lCGaCbPCsYE6L3yh8bfjHhFHlMp4FRbW+7VoLIsLi" ..
	"AkWe1DmiNBqASqUoEzPjeusY0qr8wzzxtmpzsOgXenSBJuElUXP0z8DeYbV5ohcmBF5XayBM3UFu55LEFCkeYbozQmmSXk9bs/5u" ..
	"KvBd7xuli+a9+l1GeFRZIDxjRefl8RrZo73tN9NRviXp89IUgBv+rFTzqZVCGoveGWYhBd6cgd6z+kCHtXe3VjxEwXc6RzRXbewy" ..
	"kYEJDIfhhpNoRXOmPaMAJUKdXzWsJFmxSt/QiFnG6DJw3TOWaBZ4hD7WRLuDZ/9JMQg5jVzghsA43nnqO8kkHFqy1mzdbYfTdQws" ..
	"yqWPj7iHCMusDcwIqGXWjwBRHHnhcughHWORQgc3MlUfUHxHRYm/BPEfw15TPkPQsg/4XwgKZgBD51sHczDfWsYkQbihIu8qWZhC" ..
	"gIRJHpPeW+mVmLaF98CIVKLIqGO87/aaWIPIRzzbz0Q5zeX/Ex7nJ4buKZoQHWCrMU2AeJq6I0URnQBf7RzN9iboMnQ/jVN0sJot" ..
	"3Eny5yfZeyqcKTJflkx5FE21rNPmOnCmdoSFxc4i8nQxx/KF9CfVf+rhiQgqFbNEHJ/i+l53B+e2gEF59CgnOdzVe1h4lWW9Fbm9" ..
	"gQVNhiQXouSlbCnLlhRRcbGdADpI2mLh9VbpoD/T7mt9KWxv8VtIKUFUnBJWI9eW30ZtN6pqJe5NLgrRymdpKb02bUDUIc1OC4Pz" ..
	"GeQ6o7RoCHSTfBxWsCnetPuJzTh+HAwBwJvHR8h/v2wm2t5ou0eYi9srBQvYPSh0PdDWvt1XjCoPjPG3JTMbnJmTBM8QmMUERMXJ" ..
	"dmulSGv9WPU95qI/wEesN/pslGQkLGwY1cBZAvVdl+y/Jkw2bESt0dejz/qedn30UrL0lyF3rsE+rhVN+BzeutJPVG4vzPwwXXgS" ..
	"179aao+oV3iVe262NgMgd52JlM85flFDWyNrFnFAxXo4B5Yy8M93z0gC/ZREwobB6URpxeVDkbPxeCttexPPSQSxhCGPXTr/hhOP" ..
	"sjxpzml14DYSD48TLSUnrBr61H/C1neLfp2dEVNR3WvWhxtAwgWO7wb35xd5nTh/NmlXiar6buGvWDGxJMHb8kROFYa/DDbhsH/I" ..
	"bpjk1VMVfsFfuUneqAy76R+TtEoHyrZbG8dQjCoz52dlCKmtSgDyvv/p2kCxTJLF3yiShUrg6etR8jWAqqPM/LN95eGAooa6VT2X" ..
	"bTgTKgnYSg0dTH/OCALNeXbNeEG5Ez3tJVe+c/ulu7CM/RXermyCNTvMFLRh9ZIHxDrFDHWrs0oYKIUbjq2fngWda8eTQ89EolTf" ..
	"L6VXdRGZ35yn2tQj9swrOPAIo4uAHebFbt4vqQK4YAygYHdptUhsB0bVf0vXrHXRDuI10OXyk63rqd8WlwNbP/GkFy89xFuEG2YK" ..
	"KdBBnPBU76Y/HwhkVxMo6U+g2+5a/TrupIWM5uvgUptGDG9V/uJSkrtw+UpKeweZHzF7kMMjubu88NNQCQcPwNxO7SSTVgyWiUvX" ..
	"xPPNmujLMURZklWwTxViLITbx0BwCm9EqHFzFDgFVqx92B7tg8exQsLTx9mOVJ4NLE+PkPww19m6AU9ae2Azpk81d16YOvMBK2Ac" ..
	"keOZUCTFHSr/UysfO6tluH2sR8gaPHv8Azo+SrIvTIJ/8OFMsf0PUxOBj5ZTCIsJ60u0K77EluFPpdNB4g6QPui+1V6gWOM+GArX" ..
	"0gZsxGG1G580V5rn0ZfQKY1ygSb2iAp/iTZ5XVs//YeHHRhK/MkPq5+a4PQDEyKZ0GMQXf3CQC4u7PqZscnwsd1gwc4N0yrDAtZ5" ..
	"x6AE8dT9LN2aEwNCA8LFRUXGK8Q6LKhe+T9kW4SpFzQLc+2ghdzMkpcmze+qRYpgTx3Aj2IzmUsaTyPmQm9fMdl6UZ7OHIF0vgML" ..
	"egpWNYSEzXWT7BFvaJdOZ7+og+Uk6SnaNM++7BDEVrU/ER2CoudMd8cwbfpYF2wCNbL6s/T32vLgaUUg9a9cjY3nIhTD3A5efOTZ" ..
	"jlYG2k32a2LNEhQ8sL5jPB1uBtDBCzBmktZBWUY8PiuNc/lhL5BIjzLBuq9WM/3cxc99wL2FucfcY9aKZvaSRjc91/par8a/jx2o" ..
	"OLiJZ8kOix54qxPdiNRyJ9AxUmO8F+4N8Iii/verQV/vf+7A4gPsMSVrffgZ1VUhHG3aN1QUNtX95Y+CMD8dnYCpPvK3hSCMkjm3" ..
	"DKOV9xA6NGL7NmzCu0E+yvDehWhUr7KUmoRlhD6BKS5H2idnCNgYB8eIXZiMqkgp0uAmbU13ET4eI1Si9tvHzvdetQpmEGL4OPRx" ..
	"W7PLglQteNjQMj5LAfFdyfZHKjuJh+FZFF4ZH//Jmwvq9BgSxX+fS3NcLL/AQL7MxrEmFd1THPj/xf5uQB0iewooxP4mpDhO0Dmt" ..
	"zgbIgF/PY4AzI9Ui02KXTCb0ntB7tTRDWHSwjcUrokwxoEGDbD0bzu+Lw0nY1D4Zo7imlaB1s0bd/HuBtss24tA0BBbn98ZUgUTP" ..
	"3hCr+yBxJa2Ou7dWz96a/a9vtwF9hJQMoqyiKxr6Rxdrwb2rgdpGEHhQ9d1fMO4eAuFLguhjqC859X9bM8GJpjq9R0vLzXUR6DkR" ..
	"nw+kiHv6Zod5fpwzMCY6fMW786eN+DpxZTHCJeTDwyhXrBDUFg+U8Xz/S2xPArjsF3nO9qV08Py4OudnnxT2K4nnUpHBhlGcvVdU" ..
	"mrxy7rA0PWOZJY7ibEe3Hb/1n0dDpTu9PapaxFT8AcL92Xr3WgcLRagvNQbldYTPk6jy0cM1YulMk3VddwtiEId1UHZ3j90+jOSt" ..
	"PpscGWaAxzG1shV9OwsXEEVwTD0gRWGdZV+Fpptiq4Mm8zo/3+d18vlgT2nXn3bFyrKZZWWdTFbVnemZQOLK2y0CX5MRLqEQPf26" ..
	"ZGZz8R/wrfxos+LxVtRXW/88vWM+hni5Pqo2q6m4l9gcp1rkCXbxkIX3V2f8QDXnejwgCkpL5S173/6dWIRSTf8GaFHYY9c1vIbi" ..
	"oGArV49OCulYUT3rlkSJJOpJua1DIIEV66cAmCkXvIGC5c90zZ9BeROHmbqS6Kjeme3pYRomldpeYOIcxgfZSBLFurHIA6lJg6qp" ..
	"t39MELMdLllEJEIsJi9ZXHtI2jOMqpeRTKg91FNl4NpLOgPYTTKMFxkrbXKXKDeQ0CE7C6D1E/iv/9whU7YpmQxFWUdX2MfXXq7W" ..
	"xsWQZjIvlUdfsb4pQSHImyTjqyq0yk98/HXlQnvKI56re2dcdhtOoioAcTRdZ9SSiEZxiURkNyZcyXuYnmN6PgsLXiY9mtD+SbmQ" ..
	"Y4zsFeWeBAgEVNjFkR+hW6ArcZjzEDAlxQAOz9tzft0Xku2mTA14bPt4I1/4teAcraDWkBuxZ8G+o5XXdMS0tDV5H5NYo4ikO/P+" ..
	"stsWwlG4co+ngk1ipEikqBbTE8p6dX/KTwFlN95olsKSkYLP77UFIpLjXP21eOjV9Ss5CQKuiGvg0DzJL9X6pQFoxBdr7oE700VR" ..
	"dfXypJ9J2+FyY9BqUSSJA0PNo9H6e0SuMEM9QQJa/gj1UPGr/BVnsNn0eNpcgfx4Qr6wlovWBTJSRNVz3BYiCY5GIudQiu7BMNiZ" ..
	""
local PAYLOAD_P8 =
	"JRtTgeFQKH+P+xTo3S7BajzjCrYzgHUZz4SmoFfB6u/3PPxIwz1wt7IImxhuIa/Blx7/YofEtQYtqPZa95sXbS0GOUoyu7W69sG4" ..
	"mTUCVs4YwAYRXmw0sY2jmMNg34pp8zVqXUpG646Zce375oLcpH//bT1UQ/9JnsrFXNyX5mxPciKrtfk06K+ZwYqAOmt+Ngt3pl1n" ..
	"CBcV0cc+2dkNqnPa8q9/QjNI1A4RxgoUDImzitoOuH+M8W5ys5ahska4txEV+e2YELAl2dPPyG6GzX+peVQp0R9dUbGsw2B2LNEL" ..
	"xgCLnKxPzoT8PnxlIPpRrUXiOvdJpOp4YK7vymbfUPv/UBpLQqxrmoTCdAIRCkm6sotIvSi5McUvd9s0H2K8E3fuVQGnPXUhaq6R" ..
	"j2bwaN1nPX3yS+Q4IhKr8ToXTNEyDrmyPAQnEg17cX1eK5seoGMXmzVJJFs+8MO/6/J5MhYO/c4/TY75MXI5VMgD+dk4OkNZJmZu" ..
	"mvP8kw1gMr6UonIzbdGetl9amXG3p7EP2PqlqGRFbNDRuPGVWyjZQTV6B7jLo+WDKDWKWctJ52pD6kQL8Lgz7jzHFrhshNdSyVFy" ..
	"Uo/A8VsHTu92CP+ctXFx32gjde8oUgIRbeP8vFvFG4N10PVlhkCJZyQmNpiWcYfI9rpZPlu1/aDlSEJ5HmD4eX3CiiVrcsH5GJ2s" ..
	"G+Tl/rAt+jq6P1O+f6gjQW7lnqAAFUKrEVn41yvfrpHTORudZEeebMDIYUg+9Aa4SL+ayldfwVBi1L933A85DcUALbK/cb93iTjX" ..
	"Llwg5sTV41MAq/nNkhPfRM+kxaDI+DJQEKYPkWGw2C+6jU4iHbS+/R9HdhNw9f4WiYoXQcDaZDoV+8P0CZfvMcWGvaLGqmJg6mTt" ..
	"kKEKonUCryxq84XN9IbTk294My7T7sQSVYO57eCv1VvaIAIAoUsq28vYLmO8JP8zSI1s8TvcNIME/CKH8GI1dTaYx7eJWK/fkAB1" ..
	"yEzDPo7MRXKr0sS2frBEqXcj306k9Scr6H8GNpJrYoJNs4ikMQ8BK17zAV94gVNuK/FJmkyB+5xqpayFdwvGZmtsYkdY/IxAIrUi" ..
	"Kjy242oE77lyLPewJwzmanQ1JAbyXOWtl7l32m5mGEfjELT7trttxKm2cypDOX7ncSX4F4kqP87HGtpkwqZsRJppIicci4MCrRfd" ..
	"1jNDowSxl6pGVfX8LFRjnKSM6PgXT9UXBxzrDTQMDnxolN0NO+60MP7Fk47sYnWIu6B2bl1JKtou1Ftk8x4HL1JWJAyXePDA0zxK" ..
	"Z8a8JgbpWOBn4z96Kjje2k/gZjrSnnShixuEsHYcrxQI3NBzwDTU2vPU0izXGarXInUtGM7C4QchJ00rGyL7qlahvNMcs4mp1seS" ..
	"maDyV3aaqXjM4wA3pvJuPASS+8/ZGstWvYMwKIPI9MY0PLNWNE7w6nfoh1N1aD3MDQWWMiDGrdg36T5MkLDEFp7Bm22dvs0Zpnx1" ..
	"Z5Gzl4FNGAkIg9vHubs6bWsQ4I6xwDyTMmty1VjvqUBkQscAU3yk3Y+E0lbyLtn9jwgll8nq6xFRI6yCgwoT5aRo+v5SpOiPDYVo" ..
	"7g6+iOgGw3gUDX3X3vQJAfY0TnS3GsblCwUm8aj658T4kX6ueQn6y7eYFpCMDTrXNcQ0xNjBwn27ruT3RsxJkC61rwjyldKZzjU6" ..
	"z8QNtpm5t/nUKz+tQ08yB9685whAIpTkBTFh60XHqdp8qRP4BLvrxIZ/yuoJl3ZYo8F9Ss86eClI6/MdnDqvvvm7dbgaCa4L57Nw" ..
	"PP0dyo/r4sU5A78DDzJkBVmacmdPdLsJIWygNrc/GVYXbxv+v7BFNgZnMsfAElJGZ77Ly91hvN9ofDQeO5L2/39HIoz5OKaiUnUN" ..
	"OM0L8DuPLs4/s/8JNCoSg3diq1L38e6JnLrAwAqMi9LBSVx6qeZjpmWzyrolw7DKTGKWcFepPuya45PXKa8zzRatzacynuuGX3hK" ..
	"qJvSjJYb3lEXhIoFTc5duRudadIBEKjST8YH/DwPhvxtkNTspEzZZLegQWo0Nu0yP6ucspur53w500WFvufEyW95zfYKxIy6OFK6" ..
	"t1328c1moW0EMkedg1NssoUPBXnMI9eURkRaMimO6jxnPpeMFQv7kB17Z19VIGW+5dWBi13w38/h9zu4J5I4VYA4zjEBqaUAXtNB" ..
	"b9Qc4WEgaVQFNuVZtbdOJXKJmXQCq0FQabiVe179HZ+IMV7X8mBwf2D7dFC87HL1ZSQKEF1k1G7tGNyDfF97dIsxsvwOlKHnluFy" ..
	"eU/jmM59MK2XeWCq87fnCsrvsIJm3OWTAFEL7tkj4tDNbIWWT6rgVBXoRX32GdWeVuGcT0vIkXda7uchX4i8118NK7062ll9O3UF" ..
	"X62lf7Ea8LNcVMa+pWD3Yq9CKzfaJCQrOBagtjDtHKvYGgNP648N07JCjVd5F00PVa2IXhfBFsB1QpDNzZpBl30kYXfR1Wrn80Li" ..
	"tjPaS5PhQ+qxwGtQWEUplxzEubsPGb/1DIP4+OwoBCor4UW5SXTCODi+E0E+gGDdKtnHr0ddn7Z3XuHjKY3HM3q3H+dKxZ5qZpz+" ..
	"c3I5QTm0ir4ew9XChfuVzUEpJ6BA0Ylm989tCNjnPsxrckswBhSU6Wg2vIDqWp+OVxpYfTzQyV8sVER7ephk7ZQn+v68abAd7BDq" ..
	"CYZHKNzQBjwR60uYPf6jvt9xXggfKc779+yVeTjuGvnzfVogKhLFcWN93XtEFsVWfZjLJPUjjo62aJox0c0EswkIAiO/eK5Arw+u" ..
	"Xl3jRqaMN31ppBZG/UACANCOe16cpnwVBT411HULPag/m+auKhFL4jwdtv/CabUCwmAb2sQe7rLma79N6NxDDWmd2KltCvBy1Di3" ..
	"oiG1K4/ci6rRMmubQ+egDr7hxi8Y5Nny/EKGT24X7eSNLeJub+VjADThN58gFz5VuxXaK1KATOIrLG6vg2KBw98OiQnzcyPYWCHu" ..
	"EC4TLy9ym+qzA7pW11n/IepwQbXjvPcT68Lg83G0jMTfRWITKYzJB6Md58OU+SZmhT84EvOYHbIwE95KKzuDGHtuA5NzznYXppUM" ..
	"smXpBhDziUAqT1+aUXDTJcvNchHlATebPe41dxgW4tzZDg7lGwh6VgReZuzIvwqk9Ll+xDIofCFTuDoz733BiG21fbWUiqo4se0d" ..
	"WzFpSeRdeu8AhzxgTkuQGzXvdXCF0gpIaZO0OwT5PtugxZ01jF9lU930rrMiDvAI90nZgAHbf3Zh/29y++AKNztnbecHYjQkyg0e" ..
	"L61rFdLa8Q0BzcpKm5ioFfd6XABZRWN4bJO+Au6yED/0o8ekVfyGctk3yL44su4RwvFKHhk+15gyNTaVpIayazwY8gl14KnoP9wV" ..
	"/95t1fnElG/NBvR11BzM9n5oUPGBmPjH6zap/9rCiJPDxhKImTrTTnVTF+aNC9X5EZ+DlNR3jEdsf5dxvPCoUQgJiTYtVe2mcG1j" ..
	"xLapgUjHR+TXWsw0N0sqmDZUyZ69oaf9gGdqIMbZJ8ZPv9XO9FjBj7dDTGmpPwJIM3jqEvcbVvfNp4zFapc+SIVOIXey5SbCQUJO" ..
	"6GseKkC7vNZY/dpZ2si3msZNhfiX9sMuA1Pgl5oEnOrd5pVIdHqZDZ7D7EicYbQJV7CVO2G7ByssMkQ49KsciZ0zW8zQzcMgtUsy" ..
	"u0fWMeMI8nr/oYwyfo5RDYJgQenK5xt86+v6aWjULaEitGAGw4gYaGk8ruigXgLJElJ48SKwj8Sp1W3SMxAouelG9JZzkqSKXFR0" ..
	"ML9TwUszjM1F7/sk7nw2aJlfaABM/ln3tqR/Kecb/P3S9/cDm/F6Rf/spsh6LiaHN3SOtFogFfZEe6SUS7792sHso++x9Tdg8QhG" ..
	"SgSHoxejbs0pMpglj6GGXxSm4vLOc0uv+PLPfUYIYpW6wLi2gz8ht75yuC08R0MDd3Ggrx6tyBYCIgPvekxxZha9+TsOLyEcnFCR" ..
	"PETsceHHqLkeISj+MbBS9wA3fu7GilL9HsXaiZAYscGm9y/RU/0k8pMpbjutC5I7HWdypDksyMIrYF0fqONS4aY8IQS48VXvApsF" ..
	"ZVTBItlP9TGQBey9nO+mR2m40Wfmc4GsdkxdwaVKKzXqefQeeM3oXMs+yrkCYDs05wnYn99CRrLXX5S/bkLuY4PBl0GCjEhwCEuJ" ..
	"C9182Nrrv6+QC5AY3zzzGhsXyy0mzoC4OuqELvRTrg/Q6MdRQcGpqv9TfMhRbJqS5FPhCdh8gyiEksb32Tfj0tUCq25ZhsmIIUod" ..
	"Ee0l9FSuQnakL/SsrET1szsU/hGXcwRc5P41PEkk2fx1Yz/94scpRBRhyqzglV3XGfwJYZoC+kJ7zMnxm/G9oYQWOLccd02MO0OW" ..
	"ad5fyZaFizon7dTRCd6/TdTIzHm9cARu+PN1N3k0VZqdqGZjKfL7Jo0FV0sIrbyLeYNWBcdxla3ELb3FTUq19cIQ2ZRo1G1jEYQj" ..
	"BkNGkVAzcXNDG1/Fv6289cdMsZodceB+vLYxfzz6hXau8n/N4pMUcU4iZSHmxNE1hTxAQRW1BDUEO05xitOfgE9RDGZbTgVmJn07" ..
	"k5HOYGdxJzsya508s8n5Fi0Yp8IDgE7scg+vIA2XHBDXqTVuOHZhthk84OmZb/4xl6dNoMHu9Bru39DvvU7B6TF6nEYhKqGilJiJ" ..
	"D1qPsQZu036qxGbzEIo4/Mtqsa+WPvUpup8e6UTnRMA6EZ4IRxMWWspr7vAaAQNWj0jPakSJ0wW5AnC0M05MDgO4IVzYyvnU/uEM" ..
	"1lHD7HiWgjsH3IDlp9Oy58sY6r/sG0UjovDtGamT0ahaS6MhdHLXNule4RFzZSDauVmsRxw7fRN2sNzfjqt8P6pDna7QSdeCLXgv" ..
	"0uIhiH2xbP8bVNNH5jcBKdnzYaPwvWitqmnu6LY9rtjF4xuuumz7wuZIT4pD9qHkFVRSo3FrfcOvVVstoNtE8LB+LuLNmxwTvZHE" ..
	"jejYuysIeLz9jZsblWCDTxNKC/Yz4KQm+S/PrOdJIz/Sb+VU8oDEhS3eqpq/Xkn6e1KO8TixT4Df9moaZMVmpCyG7VRJFroClVhs" ..
	"l+j6DxKYrO1Shfj2Td9aQhb/XNVEo4+WcUaWIC9jqKVve3v6HTH+ITiq2t2WBA1VyKGtqqS4WiZF8mntHzay+oHPSywLxFXqijm7" ..
	"2N0JnlJtCa8S01Tkbaq/K5VbvlRTw9rD/di4v6xiJ4/ONbXDvJJRYZPKEVttlbcaZzyoJkEftbOUL9Hf+qGWQgs6DD9qXHgwJ6Wi" ..
	"bPb3FP1PXuvvxzFLgnSz7U8sahcX7J+9/06DbsHh/6E+wugcn6FaS45uoLWubdYbjjYyA6j5OYNt+OJT/ZIBZKvTlX3a4STqqyqr" ..
	"y2UdKHl6Jec20dOc6io8MoLB7OFSQOmijzKKPtUEFcTXB17iRVU3EMI6MRqmrYC8LyAVwooN4MWnk1JsZhgbfYTMrjJsj9HJqnPj" ..
	"zsfeei6NI73nxTOgnVhWV574hF7k/anD6KqbYgJ2qadNuGyNBpLHnPotxEOCUpYVVKjdwGnEhbA1+c2/6ISI+1m5CI/1pjFNvvlp" ..
	"0+DjyAAl2lWVYI8w/0CDROBSGU3Ru4dZFANjhV1O0ijUagKu8ZuBK2U2DtedMVbWEYlvn1EeDMoZPvcLE1x38vxvSx638MTDkpUx" ..
	"1ETfwfHIJPcgDKKOpcoDKy0ZQBvpmiU2KNcT+xgI9u64M0gOwADIzTRNvX5M9r96NUOiYpniD97uee39k9WZ/1zOwaz/qef3RDSt" ..
	"OGK1ixPaTajvFUUHqYF2C7/fL6Xlc3YMZ6TyF2pGUFusQdXcKpJ2lF7oqeo8Ju42I8k3rrMQNVaRr1C70oXLebceKG3hh2xAfbuo" ..
	"AqpuogATqRy/olDaurwrExQ++zmU7902StgAUGkdIGGiHdilVqlekHHx7+PrFATD8Ol12Vmg0iYDxHQFYhlebVL/xaydMtJEtiJo" ..
	""
local PAYLOAD_P9 =
	"wRZS6tQnNki2WavHL/Mow/aMqq8Pc2fsQ2J6h4lKiO38NtkqaZeQ5xTznj/oXdL43VNudgutU1faw0kuXaafGiTZzKOeFxEYOc/A" ..
	"vIaLOwGnNc1zQC0/TYoZ0PfYEcc1AA+hJVNtbBjDqPnlv+ImxrA4LKyNRxstBlcuK1RfTAI5pBBKpTMJ4Orux6CjDfqoSt88CNy5" ..
	"qnHZqMbMu/SSGhjyZepOvEUp41H9HN/icONEf4m9UnOeuGr1D37fkhC0y31sx7+6HxJhoXq+8SA43R94r8xk9fD/3UhGYkw00UMZ" ..
	"1K0vkw2yvV1f5yfcx6+QwW85dsZzf05aOyxANZisYHdb5BOtIgTaA8tM0JG1Pf0WJy24+nE0GgiczaoFV+ydOFwb5HHAMrH1vvk8" ..
	"q5f24dQMaZPlyUaXBjpFXl6nqQlTtn4/qcOxPBqFlJaBJp0Bm3Af64IK8iiBAT7ks1/CuMhYp676soH9YtUOP4Qttmxli1zg97y4" ..
	"wxWQi7PQyXV2To+NVAYKZeHdH+1wBDXlZzFE/YU7hKtbuGfFBlTVv1NlzpY2UOWjytK0nrEj9DhvlEdqq3yxhf2cS7TlACTe4Ff6" ..
	"e9O2hBV1n3/2OVj/B2Y+O1r7Fc0FVbMpA4mp31n7Zze4jgXW8NIFS9L9Y26DskH2eHRrbzD28R5/fjvVvBYQh3186d5/BkvZL06I" ..
	"dkM+Lj8Q0+e92+zZsmxPhHJXgzz60dWYrXzAbzTVJid97WsHNXNbkY3mcvm+TlgrnxN7zwO45LSTuEBlfTiSPRTrgLu3jP+6K45N" ..
	"2xboGjkhfO5QI3hrXM8fbhsWSy3quAG5GA+qr7i1Ew8cDQJ2xEgaz3HWLNhkvzsuGo8UfN5ZEjWOWsA6WckquNYDahyUP/f/0TYR" ..
	"dzgCgA7VL+mOrsh7nj86kLb6aqMJDzu68Vw3nX6VoC7ZBCe7QrryX0tZbpeikzYwRAb+5yuiinBY9aOulU+LPYU4P7xYZz/wr46x" ..
	"e6/07AgNmfXi5lIeiXm2c0Lz8+jc//r/vRHXZmXRf/0Y4G1gDtrSoopKK4+HLkgxSBUXD+wmHYILoHlyHxIxFyouxCVl1IlExoja" ..
	"gxXxQS1PYB/UZb3YrBzikXYK3DQQRL4DxIqkk/k6aS1Oe0cioTxZdMALlWQt8ACE2AgEOW8D9nXJQRcrwRompJtVlUPdVxf8kZ+r" ..
	"/iQPW4WcZkPHbrqI7OIjjqg27dQkxLE4nf05RLAsM77MhhWduCio8CVv2g==" ..
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
