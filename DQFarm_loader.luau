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
local ok, s = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/chi-trung/Dungeon-Quest-2/7d5c268b8e680e88db7fdc3f80780475bbeac598/DQFarm_loader.luau")
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
	{ seed = 2343548995, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2346178645, exp = 0, plan = 0, hwid = {} }
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
	"YvHQ9dKZD9NNhvSUUZ43DfJd6QyFa5y6di+C983W/jpHVCp8amTThlKMwM55QqYQrsuTd9ULCUgxRBuGJrGSn3W4D2g9k6n5c/4J" ..
	"fSIvlZueA2YcGIdfIKLgjSsb4DcgvYtNlZvTFnxV3DcLjTbCL1SUBSCOJMr+FcaFTmig3lX+xhjrSDTlPgkj7/h4aXz9n9vuUzne" ..
	"XhON/UvSM3Ou0Vp5O43N9W/C9NKQeTUffW7mlqGAs4suewg+BdhqVLP7LpSWmQsaM8OGeXWm2Z/E+AFb0P2Z1trOBoB6lnT31qqe" ..
	"Gc1Ab3OqDOtXfvY2xljFDkwWXfd9M6yEKEOC6u0vP/eTJYcUw3z4yXIzfUwuIsZqTR3gJI/9bnpJfTzcAkgifGJaMyC7RXjlSsm6" ..
	"LueX1nRfY25phn/NQ3BtoVIHSomtLWL8vKbmwKD5mdb7dwohKr9oGkxJSB5HiTpeOuJm7phDsTDQ37cpMSvYhYAFt4TEO+gNWSgG" ..
	"SpFKhGjq8LHZ585WjSqBQ4PC49PR8SQw6Gb1zj193wLRH/OdQE/Bsokz4678/1ylGjML+AozvmZU6z3AzQJujdjxeg1Byd7UFqOp" ..
	"MF8sfg8VXtrdwXOcwmmhH2B+1/7EehAUTdOR5MBPHSPszme1TK69n0ovEDe3SdpKLya9L5Y5tDpfxW6vRi5yTfVQSH1qPEivvKn+" ..
	"Ssevkrldq2W2VAnFZsF1quQPe03vo+SQ+Qajr0TEUrhAa8sQonWHl5/DuK3taviH9cFX1VwHNrulfpoO/2L9zp78vsQCETFwUbY+" ..
	"WWpXGlwxuuBmJu7ccHW0R0XN/fyYjKX9VzgNHNQKwlOWKQio2noK3pU04rqDql/McDNtCmCYrdm1qo29iJtvXNjMclGSjRK3HTa3" ..
	"tLxp7U98EEClJhrz8/GWKUUudy6bCKT+bdA4z6vPo2k012AKv4gjKwCdyHz9JzoiAcIzqkyhYm/R6SARebyt5Fwj/dAeMXqTm1TM" ..
	"udEpDjDLI8jTjQ2H2jkvGrdgTSpGo8ltML3eSmp90h2E44hX+P8GRG/u2e86jI4QOqMCxhOPV/hvRyEs9sCr6Q8tWEVDwEnQ6cch" ..
	"YXBXK2rvaBjQ72PfeCG0zPRtX2FvKBM5VOvLofx/zSvl4e7qK+snvlM5zDPPVSvviQxwQE8xC9k+/XHu/h6FXHrnPOUwj/YCBko3" ..
	"vhRUl1rEiYaMUIDbCMReCIo8gv34eUcCVX0siGRg/+TJ2H4QYAxZjTc+AEnol0MLaJpDnC4+I/JjgyD440X/vpN0PnS646Oo/v5j" ..
	"Ok7Q5Qgh8OIXHxdanx1tSMZFmreXJjCLor/tLRVAVyQSUEw50U+C/L5+LwUmt0cUa6BXcuYB71tLCf9M7eA6i+DLDnE1NgY1DJs2" ..
	"pwpcKZ34bj/4Oje0BDePIs8swF0LEuusBX6HBtF4saRXaoo89ykSUoTE0RYIVFxgTvOwz06bukyMoAHiRcGoGYXHcmjN+Zit6FYN" ..
	"LWbtsONkhw8hbW/TNApUe1vCeAs5PFi3yfacYAGzJnedzf/v6bUS9Bw3UCw4CqzWf5A5jShxoAISdFd8/3PBIgsrHXwJCYx/rBr5" ..
	"RqjRNOx+I/J/5vyqFDi44UTeP8VW/s4r3nyb5GpolK35VlMi1OeoWDpzVGv3xypMJLn4ntyaSFMmBVsDdl7IuVUFRD+PV+cCXFdS" ..
	"sBlO1cbwgHz1eDRcOdnatwDSmsHuw9k2UCtdop0dFmr7Om8yIOzZxC5O7jVzeF35OgBMjWfe/ziIGm6pPFfETb4p4fngapqcczLj" ..
	"fCt13V7es9OKAW0kjosjhJzfe6mvdsjI0GO7618g6AP3T6Ltoup/jgU/m62w9baF6z2B/EskYzLrryRuZqiMDI9qQFrkJ3qY0NCc" ..
	"m7cOrlxeH7TcfxBuvsGEcvCz31ERjnZR4uBey6Xm6/fXyiR/gKyNRb1PLM6Sq1bg5xw4jhpYfOCxPTd8kQPEd2ZejtGC8VVthczL" ..
	"LbXprVAR1J8IThPOCx99AfJb+swaxw/NAAxaH3dJ+oNNUHPYe/7OGtgBNU/9ChlNOEqQ0OEJckROsNv+Tz3PeMH/+9GHijAvR0Hr" ..
	"u9kF5kDljnXj0Mgm9iENDCT6KzyIZ6iDY7NlpbXcegphx42/tp8HI3Ge4xxRYFsX/syvAnpD0WSJ90OU6GJSShMlKgZ9T7JBhPkU" ..
	"Tjax/rd3hl2Djl0pccADNEqhPHWE4PQONHrqW8zblWe5D7ey1dkOugw35NQ4tupfJOuUaCAfkxYNOfVqNv6sMVhKWEf+vZQG6XzT" ..
	"hR6tbvhPzzx9rJBJAtYpthUns8inqWXof5O/RG1Qp8VmQai9NcGnbvBen43p2sfwDN5vUPkp2Zwi/UPwFsSGq9t7gUaZh94cQepq" ..
	"U0frjh3sFpHHB4ShRTGBXAn/2H3hie3VVO/F40i5P1+NCASKPXgdJ/flTJlEm0pY590mICz6ZVX0S/MLZvyLWm4F1OKWrd6mdNE8" ..
	"pGKFyOYb8EOkFert/6zPw6vO4cubkIWaz2z5CIqUiG2mXg+Hz05qrkhHs0CpCqVYznhMQNZC1ve/YaufVeKehaC1fyG+F2h0YGXx" ..
	"d24sjkdL7NYHu1BZRCPazP6fTFmCgi5sgwE9J0AqJeLQwUhZYva5RwycmCM2vIXLXdzxnw9nA9ouLuBhJ8TR92W9ph6B8T9stYuX" ..
	"wkUiaFENxBgRA7no/+PhBUL7ko4oiXKsC4cWd5XJHHWHbcmMifCPHwdTqVKh1vBNtwAr9+PbMaRbUJ5MwET4NifRNOI/WBWDCmL+" ..
	"Fa7jIjAn64t8duP3/n5qFWcGXleHrU10rwtN232hGUjSxyxG0uBjRgWxbzx3pDwNpew12Q5AhyIUy9t+UcaumXI4FYag5m6vwhEQ" ..
	"FzL7qDkdHgoLVeAMxrpNtou6wk+APVOyEJ6jzcW8b7ITjrtSvT/WaIil96+IN/jfD5aYuppnsmEjbppe/VsdrA2ZtxXlZ7XyBvAm" ..
	"TZRMCAKNTKakFHVZrK5S2+PAPlUEIZh4o6dNTTpp+rAY7z4OKxh+ElP9/BMsiw15JQ1LAcPlTn9fSw8vIUgErstYXv33lSVdPssq" ..
	"m7XdZQQX7wtBKAW4iiVoRQ5fdnkKkdMOGXMFHyuUJFeahU2NWwSsY3+G5Nze4nj3guEAYT+pV42MN9H0WB+s6kDG4KTid1x1BdwI" ..
	"xY1Ehz7lzqDHeQFUSjL4ENznlLFPlBTHgEdh7FFyVNjxcyp90aLz8oNawbWZPiwedooUDD2D8Ws7FDl/OzB1PDCGD2dRsNyc6lSu" ..
	"CKvRVSvVFO6cx8bse4z7E737XWF/67Ti6qwH0MstdgYym9Rhxddy11KkkTuiHCTBecmms5sxS3XRazCygv+1lNSc4Md7DgIR5M/Y" ..
	"Khhv8cTv18wjbAETTF2JFQgdYFt9e5egSBMGOiApr6X1Loj0UEaOeL/wotPqSAYlfPUsUMbFA7gBaVjkzXgwB0j1ayj3g5ivckGx" ..
	"aeQyLlwrXZlqACZyvBj2I1gscLjvAxPd+NKpA10723WfWowuKrt+YBpmIeQ6OpgKA6a7LFimYm+bfCedjD3jaoQ+Kk2aNqtoPegI" ..
	"z8hjq7kMTkKjWRhVvmrpS3E7nIxcPiT+3A7b2LxNpR8v/oXk5uePZTPtx4tgJ2p/DvIC9BHtcU/tuQ2WQUB02/Uzyq0jlu1gq/so" ..
	"kAWQdNvR734mOGXVepF+5u/bGwFpt68L2cSmptsvDTLRRSp/VQGH21rqxQpHphAaq0PkLx54/uflX19T9G4ShD/HZNQQ8BaIuCW3" ..
	"atK6a8Ax2XU24WXO7N9wftYy0JwxdB7XgB0mhVE41jjFQhZMU0GFy/1xzq+pcZkTyr1SZ0nxfkW3TIRQeoqXB+TNrWKe2Wqk51Oi" ..
	"V6MkpRN0RAVwQRGuew1Y4ftkgQ6qJiOIPodw0QhT/iyu8hZk+xPWu4pPjhJurh7C0rgPFbXVZG3K8QkZevCSvlr6U0SOQoQcemg8" ..
	"VhMatfVEyhHA392Yw/P26/BIRb8u1DFyGo2GyuAO5MFFKvOXYj3MJX0x35bcAqF0XIX5t9J70eyiSNp7N4fi5dUdSg77y76HEshm" ..
	"b1m9/55/Qae4v+TqVTB+rxYMaaVBkDCUVKY3UmGCpJECCiB9plxXNvkCQs1amq619usJUuPgaGxwWokCViyICkmFuZ1iBSBXWfbr" ..
	"LRxWP1+i68ZIKHYDIyVQQ648W3GLoRD8MCIFoCd1/Xv/YSDNO/fqdArJuIlA0TAbQ+W7Iv+ZD7UVpa8cs6Eyy7lNiYlGYxKYT2qB" ..
	"gXT9TuQEnH8zLj+ZzGfNI4CVy32lsDC5aqlLPUnGknSWO+ZcwpViw6JWWrsWjQtSBwvCJRC32iB4MEM0GPOZM60PzKOAwoho99Jt" ..
	"NPbHIt09Kh7ZmsLd2ZgykZB7gy++hrXIJsGDjy1FiNKhMjj/IjUDggOXaqoFZKKNT/mSI45hoWdKi/RsLiPVxp6sVh3EMXBYsZXV" ..
	"H0Hc8PMH5kBdZ5J/FKh4x8OWleDVQifaZe2fzjPDfrtXXBGOhZq38G4WlWHSSPI4KVHZF4xC9X4gGS2yyH008TzQZIMNdxEEOJgg" ..
	"gY2TSgcHaGVeiIDc95w6o/XT/GjNxyXTb/NRloMT+YDo2I6kD1KTG8jo00x8LgPZ2PBpfnJV8gfOzdQgcOA6G+Xz6MAoULLCLMvh" ..
	"sCAhpNgVARvFgtfxB4whopPAM5DHO0APcqWByIb2suowzCd19uDCO/T26Kh7xrSvvy7TOO+5b5a44fiKB5NaHrekUG8kLv/gzBQ5" ..
	"PsdjOS7acOafZqRzdbcpA1j12ulE+hI6YW5AJ9rzpHV1Vh/gllHVdjMZ+0JGe+yFuSAPdths5bWiWpSngBt6gy6aFt2iJ5keV1o7" ..
	"PU3UsZElGjN6QVRnH2ijk0M3IKurihRwkMLvb6G1ksmRXhJF8wISuLdS6FoVvmuxRBg2R/McfyjKCscFGkqjSZgVCEh7mS5Tfiee" ..
	"GfCcA0VZuLG17lA4PqvwKegpph4ukBDlgAHWozYyawzpjPijkkBVjZN8jwQCnxe9gwN3j/bHQGHrpl6ysL1Y87RLcGa4RUcwzc3c" ..
	"f5JItSQvjDCeHmESDgQDgTx3aB2Utyn32Pi5br5zMftDGwHbW/cHi5jbbPidfNkdJ+RbpKLtsG++mPjJ0a8knlCa7Q/Q6JMt0U2Z" ..
	"bput/xOHsTK3llbeF1ARgn42V1izgUKyBsY/WVaz/BPPMGrs07Z8ACiV7l8AJrKcoOso+Z0tCHONy6URdk1HC/vodPbKn5orZR3Q" ..
	"7oHB8ERft4UYlkURFJh3yU0phbUhO3PxYvIljNktnnNTzvUkl7rP2iOR4sVv0ljyDf2Qtcul6wcCcDXsB5YCLFWCmBnt/JnbSskD" ..
	"HawtYyeqxpLalUH0gpvoFXpXU6AmBZfuPqb3Kb0ztrlNP4oZsUGlI8G7pAk3s9bPU2t83Jx5ueef/RpTcurWfyWQUOs+/yYENxsm" ..
	"cPaYezJN1UkJWBgQJr3Z1MODUxar+K29Zsl1xCuFDoICKqHD1bn9e6k15blimswkORqOZqyc6pByIv7SUibu7YHl237jghLRIJ4v" ..
	"Q24x/UXK3oSVV2N+a1QRf0eTH5fsC+V+q+D8Pe6ELYVhL4+fFOS6IrsQHdGkiiELW4VF3EXSDiG7lAcxWzxGDhs3adrLvN9Ooq+K" ..
	"ugVI6Hhmv9dYxbNHK47A9kqsFqFliTbL4Q2iLNYVWpxz4npuRuJwbfwHtB4w/8UtztXLu/qEqB0twSTzk3WRDVtfjsHJJRy4lVfd" ..
	"i2r//NSxcNeInH6JxeFeZ5BdbX+pujEKaCrq3xrb7zxbE06EtQn/gf/0H/DQcmKGXwrGhAG/zZcYWXi3JBBgIaZ9Z61GEHJIb3VJ" ..
	"1MRoby+8S3XnqG6XyKQfR7uJWzLwxFQIwdZRlDvHmjtpRGvcoQ39zuHUD9v7socIJuoteKG7UkqOtYFPvG1ZJpTVkzaTXaAPB3PP" ..
	""
local PAYLOAD_P2 =
	"ewu/PlwyUfowMB2jmPY5gwsIRAqxGXq9Xeaynm//7ejTC/mDiQZUgAtGgRdbXGQIDYwBA5qOVh748Ooalm6/W8Kc4ce9cka2hHrm" ..
	"8aClEE4TZybLYMRuk1pYyuOkqDPOp4BXWzo1414Akn0hEdd1IxquJh5ZQMqvSA1nSZGLGspjEbEolXJA4asnhEp05MijUoJY8UNg" ..
	"wQT7ohiRg0IlBgaC+fGSyBri6TlB/hOShVjfwe2Mk+TMoo72lTscALuaDFJKV9sZaSHepXHY8IdAWmu4zQAhyQLNNzACJoV3IfVh" ..
	"BNsZ6Gu+uWwGA3s9QA6Ns0M39eNFFFYTwtmWAeCMQx3OEJabBByied94hZQMIXUIi9qPKQElfRtIg+dUL5Ddfyy1gIazsNuB61jf" ..
	"BvHQVSAQoqwbKJu+e8Kt8NHqGJ7RZlO6iB/tuv2THp1huYV88O2+g6rEZeyL70QabUxWDFhkPD4xqmh8reZ114zgTuT2/AyvtJrA" ..
	"waFJf1ivwonxZDhpq16vgziIdxL0WNuq4P3bMyIm6ZhyawvywK4X0kZw67ThzLFFJtu/rG77RUODmjXQzfpnuNqjOZVs5FUr1hDr" ..
	"b3lk5B8gsOTfLaZmu+5swo1r7pITfG8Gs4U1fTjZHqxrua0kFmLSMVZAmRbLlp01pL7pbL07cQgqQuNkgRRWFUubokNCGi+ryZzO" ..
	"d46OeQgoYivHNw69YZYy5m7HYj5sxGVgu4Cpnk4qcs/U41sk19pwwrPZUiU6wBI4OQ4BmElmSY8ost1xUYMj8MbLQRZsebJ0VjbP" ..
	"ddzViYXKckHY6+weg7wPsVOtwufq+DFHGmXveaAoeBoeZ4QK1DaqdXjj7z5vL48MQ5306Pe3DM/2msJ44FligUKVRsx8qNKNREMl" ..
	"B7BRs1WWpZDJRA9uUvGaUTqe6m/Y8vPX8QrrE9KBDa4ZW0BNX/0//j1+eQe9WyyK5qZS+Zpc8AG46Ji5rbAVXFB62el81/gC4EaX" ..
	"Ab5bHvh9DhVE/Nf8pQEFKbGZJjkPXUhEi4+/g6Nyt2n63cspTmzcnRiB4dYeGvEEQa9VGY456Pd6WGzix9qzhDf+wdhfVRJ1qa7B" ..
	"hqU8J2QgEgrr5JGbsW+2KAcIB+0lJlpPlXYT3dwY7GEI5bX3kzSvihG0FuBuNbYj4UPYh+GD4drdRXkJuTxR0qsvEyKsuPN7IXNI" ..
	"syiZaEEG2sXNZn63O08mcrgf1VHu0QLUo0srfF37AiEulGMBiTKLtfo5NHmI5Bz24epBvpqm9vdeDkkUN25rdVwMKSxABCLKbxYq" ..
	"GkylEHY4cOhve0VKn3Z3k/KO78pE/TS1U8AZ38Hl/RPmEkn69oF8Z3KA8zTj7afxbTU/t1Spndur5/UPZesvXSfbe9X3MdtCTjbp" ..
	"z89l+PG1joqjXo58e7k82tQvLc7h4kFyJntaUkFlG7WllE8QhP7HvmE1j0lANpsgQB/U7yZM2mw59pSKauDXpO+R+v/eqUapknGB" ..
	"BqJElNCuq0CtmhHovnrMyCSuLx4j4JBMvptiAYY+nFbuKMOwKTIBONc335bJ/8UDxWHVe6y3TeuPiRdUJuOxFe7n0Kyep57EIHDS" ..
	"RZfT1diILAm2ybVg72KjLh/WCNBaBBPHOhH3OiCXhigkP7YrkaZavUyn5hhnlIu71U/+0FjroEnhh6BLJ/u/K/MJSxdZA5mwSH+m" ..
	"W93VLmmUIkLd2G3Ux/INDrsgHuO9HyjfbKsEZMR/Lqw5AztXAxptk0259eUQTfreNS0MWhReT/nO24m/K2A7zW6lNhyQS7yFjejO" ..
	"c6YN8vovWfDa8cp1q8CICH/9yHQog+ikilp54HPnnFnJIKmSezK5rs3pO5las1gzpudtz2NT7p+KmC4fgB1toMclWjACBTakFxk1" ..
	"MDZxc6CMzvRtpt0fQzZvc/HuhTJDkrt3uJ7UN9oCI3xClAy5RsOBmPxKVPkPwsQIphwY1qIGeBnYXR6expH5lIfvxb9GUzpWHDF2" ..
	"Wo2kWEQlqunwaC9xRocv0WJEHwqqhpoWpPtskolSVAE4QeKDcJk3Rr4dp8gTxr1M7B/w6kURG7LSH7ig+0tEfjpFu2T12LvIg6YM" ..
	"cPpA+hxRcBhKAkI4aj6oM7Vc8evikslEhmMuHTDIDQDw9EfjulK+QMaWRUrglvfzk4FTWMtytDkoRUPDcVrsguqPnqMkviJyMJic" ..
	"SDFiH4LR4R8z2eqlbDLfFRByusMdb5xhs9iYqHiGPTOy6EOfviVJ3FGD0o2P2SAjebGgnWbXT/071ps3XeXJys7Da/tPv15hXzu7" ..
	"GQZDgRBxOTW8o5XpXXyfPhpkU6SmoAVzEHos3PuuciA8upW31Fvh6qxVpPzn+uYlTlp+D+MAfneIYRnafCRscLddXW9AJcQ7iUXr" ..
	"oPugnjtOQXwL/H3fPGQXFKQALRUkfadqo+htBLpX3mxC33Ip3E9u3qF71EZkGjILAqUOGzK6cE2YWaqRxPYBA3YY9M0tdX4/TJTe" ..
	"CjK4OqAEPb9HjMzl51edkLrnb9Oakwfaw52YrKsdc27luwyXsBO4Rc+yk7o1jfLhp7zTpApcQfPtPp2wHCeCyDhGcUPydhKNDQTG" ..
	"qd+omHRg+vygJZLAH7vfrjP90UcGoeojVpjcZ+cr2hatNR/wC5qdYHVICACbCkaOt9lBqwi3b/6Mc1zd2ibRA8Crhyr3zJSKNDoo" ..
	"88xJz8kOJpz6cBE8nbcaEY10oF78Y9v1c6dsBDP3xtRaLXDcF1UclNHFrDixqnuL6q24oGUcVmT6k+CudNZZaATSgz1FKUFMf9ed" ..
	"iTyBwHh8gmLeGQgmraI29bsW8ckDo2TVLVE82bjCtU5pGON/WoUZrTW/Xtlp/Gv0N1uTImmt4QqWNdrWpQfXoCLoEPTmy8pNAW6A" ..
	"3p++K5KYNCi7MJrL4ybxMGWBYKj/c6U3g14bc1oGFei9ifKbzZjtUgGBDeh+caBHg0ycWXUZLv+PUcXmuFrHu+jLac82UJ6F+Cp/" ..
	"UrxusdTQE1zKiWhx2U2Lhgh/BB4SCmjDcuNb4HHWytqeMxFU9wewQ2wIzKEpF7C2AopfvFzXFldN4Wup0xyofoFQeBvGRpAVynBH" ..
	"IUXO3JfMaABRXUrr6NgWyg3TJoozBsww47/59WF/RhKOgZ2QfbZZCeZFfq+p+WdSImweT/7Gf/uTErsEKa8bEp/FGFtiDCtXLTob" ..
	"xCu22Mi98YSYpqfkXF6zWrJaoA/WIAfn8DQYhW8PY0Nb/UZHvSraJCqodiW7RSD6iN8Gttgbb26zkMLyroNsTSzhMoA90SsCa4rA" ..
	"Fal69vTMPdqVAxI4xos5QQQdw6WloFP0dpLla03fm4QsXsB8ywlB+I/noTHx88qx0snABvSOFzNFgs1VgZfSU4PAKVlJJVHrrb0J" ..
	"OROOSX9Dk2PMJbgzIIpGt9P0LcEizRkVWjzW4hEMDN7/2xx9C2IDu59TFixsIdGN40m9802eKuwiMoskVZ7oTTL7mPMlGkVJ73QP" ..
	"sDMvIMDlZ8IO8QA0RNzVirYwBRIohe7NVsvDBc8bpX+xzTVPcH70KRxkOo7HFaylt0L+KGyT4rT7eXCDpLGphm9DlALAwIALfSrq" ..
	"4J1CCc6OOB3lakTQ9hTRvxHHEjZMnrAg033pDLaxC6/QDPuXeFKU+rjRP7VFnYXzV4n89CRQuHJ5k51ayCpa21CHdsaiVy0ahsl4" ..
	"c2Ak8gBDxHYFURExREgoxm7J/UR18ag+rf0hpWkoKFrGeshBp6JfsEMG5KlOQDt6sri9+OjHGWQ3u2MdDB9eRTKBn31J/PoxYqlC" ..
	"Y6XnqYnAS2VnivkRQ4++r5YxgVaQWJd/pHoan7iyMCqKlngMNexQYruvNC+zVwKMZ351LeOG2wp8PInj09ZZquTAbaJLMzPcInYc" ..
	"LTZKk0QxYbaCxnNEYC26HM82RJj43PAAuc9PsZ+c/t28ekYQ9jbcDcZ5qq96ziU8LFPGCgrv6AsxFh8OOjV9Mz9SXJ1RERXOE/O6" ..
	"i341hntLmZ7r4v/07XRjdolpnSPw2LORcUskHW9EyPtTltVAoS/iVNgXaGQd8feX2+BWkx7LJJ97iixtVtyNzHmtrrBNY75RHmMl" ..
	"ofQC1+rFA4vVO1YY6JZD6/6ys0Wxrr3e/wdv4osSK8NjJbHzzIjSViRwrX+CBmpk90SRjf8gErQ+OE2C7e3PHXS9wNOEEJGHFBKW" ..
	"YlcbjWUV0OKnD5Z4FbBeL9/vYEFUEHcOulDXCIggWoA/rPn0oW7iLDj9/xi7o5W7Zv7viNn8xmHzd6oKwOGm658LZv9oFq8aLxb6" ..
	"fV/7i/pWStnb1NMBAOItSXnENZgQPBHUyTp98nByy5z5l6a7Yqm5dATxXWCKGXNJJnq++bSknG8d5lFEUBN0nvh8haXj8ueTHxi1" ..
	"Y7GbiZS0+JXqRzxvgMN+ZvtAY8xg4iuBePHqL/hHQznUqEZNEdQwoqvveBrC7T/+B2gpurVE0gmj94DgdQWnl5RmZ6Pn9b/b6XVp" ..
	"QwPyRU3pxWDNzyO4Fz9KEhVCDrUZonPJ1UdrBtwr3vWsUh7iyILEKjrtTRClxYkJZy99ik6mRPVvIGPFXHbd9n8R967hftmY7iVh" ..
	"KViVzonlZMhd9hlzOB4euA4Bvo0gxvA/KzvFFnOelaO6mfWCmR5AbBO3z5VPkE5QoU407U+ptR4R+yP1YevQRz1cXj2DJcZBMn2s" ..
	"QTTZ/X/MJ4BLJHv7kEpBb3Vqoap52wLazErZEtpnawWEEoRFyErNqszhvQWlCFDgNQlRgiWnfdEfkhL1UYzOeV+15DxPw60gkico" ..
	"5in9PmW0N0Pcv7TVQvWP5iPXS0Lvn//vLFIoKHkAO87XX1N0O+/U9R0mWyFTBCJU0soD3E6y2VCmburZ9BXv1aq1qHpfGx1fvJ0M" ..
	"rjD2rSubxV7ZGOjdw37KtyZk2jhg4DM3UevESSMId5Dh1DN1cqxWuBnE8vOot2kMZW66KCtlQlWf1huPXfBQAbgnokOuQXPWsaK+" ..
	"HbcX4N7ewlHBj1q0Eu/ZIVk9J6ROvczpAUYAyJn2YXT1A3b2VXdh/PfLc0U+VRVdX8I7VtYTlN+mnkEmCWfwQyragi0/1H8k2pAg" ..
	"QKY7KajQ9UYNTRq2IbI0MpiVg1nukmSc1wy3HNM6KFSDsSQvJWFgb3+6jDm4PZNfJiFWO430+MTliLWGplLwacv1TL1q+2DRuZ8v" ..
	"DqcfthZdwMlsiqp/Gjego+8agu1Znv4dzJ++Lfa2Y0GuhAl2wjM/V0G80U+de+UrZHRZNsURAsrpLhMCFqJBLwNNiBWkkKp/W9PG" ..
	"RkP9yVDKzRNllQy/MEyTgCEfcLvsB3lsT4MAOGB0/A6OqCb8WNu4inSQ8uq6X6+b2Ax0SFxLiKQVVO6POJn65ZBVGaqDFmDGH9og" ..
	"df2RclsvHdAe4EO305gpR4zPJTE5V3/ll5aW7XcjPF7q57t/Gn+rE9SVgoFi3XkdDbSwGTvmp3FrVi2c8iySxJ+vDuSGBKv/quL4" ..
	"CZ5lhwMHaTkOhnIpUuM1R/HpfWRU7hYC1puu1QRqLxHKl++iQKOx4y9GPROf4UoYeoZvlsESNRIMyJ0wAWEAGYEV9HznHSUX3N9k" ..
	"22FIc+aOhJZaS5OU52hrcBCP0uj0DCuU+szaE/hsfDfB9CLpe6A1oqeG0tHv4aC1v5Wnz/OKwwKutakX0RLjDawBKR2voszbaACM" ..
	"BCLK9vfe9VLnOru+ENFDXr8gngClygxlJ+bYGgRUkfSW2rH2thnHZv7l11h0vi4dh77zDhFxW9YDOzJJS0gVwabBWtC5dF28ogc6" ..
	"jadHTAvEP8G38gKXcqyCuoxVUobQ+T4ExmBDvkkH+dXqXiKn4aM4/EMB28TUXVxa9dW0D2WKRfRMkE2Plib9/A2x+mdFQoGgJGjo" ..
	"fLlxx1YwWbuoDoGDYV2jHhCd7hh0qmSqI7xREie4Ro0wufm4iJdcnBFWOakWRobxPjhkfl/U33u6IlDed7CFkDDi60R6Gq0GF4E/" ..
	""
local PAYLOAD_P3 =
	"gfX2QhOJqlAKoGI4oAjWbnjEH5TRYPpEidUj4X9qBYneQsc1V6QQQKu6tP0GPqPr48UCpuNl2zt10ig3RI5XPpI9BGYO06LlG+nA" ..
	"N1bpE9EwfR+RZUCdEtl2VXt9jzbyw4dVobUrsnp2aM+qeD7zn5XgI1HuF93S7iTPOSlNGOYsUCQTgKZaa5AzOLszdBKUnz7Vzjoh" ..
	"e2RQ8UGjPi6YA4kBTpt2XYSo8nuIYDc8LUQOylTZBObBUAdokVcC2Dr2yZzyZTb3whLXK0Cnb0KDl4fQTDAh2YkYoNcHD6qnznJj" ..
	"qLppTB79btXlf0xEwJzQB7LvFK+4Dy0pi5mGPVe8U3Dss+9aU8/0AHuB/kvEgiLd/kvFY961oP39ohGdXlHH6qdqOTZyR/CFO/OH" ..
	"z7hqCcjWPj6PH7Ug6HgqvB0Q0UiwU06dSFhLBRfN4KRj4PAWdqokQ+qdCjsAXzy0pHHnAG/jG9yJzIUAACpF/HaR/4jFkFmHU0En" ..
	"vYyl9bhH6/U+okTtHBtfx1nvkJD/ywqgZkhKAaMLG0/R6eb8xGS89MKoPLhvr4TJBML5eILeTikOeGZ9wLE1dpENVnZWtFdM9dxS" ..
	"c1vhw2vf5OvlwfQi1GOOkAtO49eGHPiANXCY1+GsTgHx3gbxpZ2JwDw7+q7hfUkI2cWY6/o862I9fqgHNHq3fT5xdVi4eChY+9tS" ..
	"kCL5+nNCjFvWNQGW4wM8VE4drt7DLysmYfvrvXtaA0CY0fEvnskajAuAiOxI6Hwex/Kc52b8FM5UCanSxz3fWCKzy8OoiTbYn5kT" ..
	"5i3961fv0elNxHLgsAh4+Ox/QdZYoENLyrvDYAiuNqlO99iHcXuNf7iZJo8XCe/AaZBMX+zxIvTxLsVS34l4wYwGt5+fH7kVxOcF" ..
	"d4Bm7TRg8PScaSPd4kiP/zJ1+sEruP41jy4igZYXOVRssLogkKEhNMHBJHXAAD91nsV1qTqmcnhZhoMs26rw9UVRJld8ZkOGCJu6" ..
	"ujAnu6Mf5MxBY9clNIVX8jwRC9sqILDizV1NM2a3Wdgfjpk820gmafVpi12DGZNo6k7kxb/Fj/d8RupXJt+87o8hLTbIDMk5Wf8e" ..
	"eQqUQaTSdjPW9PYYkGsS3uHzcHD83deOGK8ejUBkB7XMLDyKSO2mzkIXj7XWDoYZO/E2dKN6ZsGDzq9grxa2RHYNOllBVf93lgVq" ..
	"+2OV6XlhmGol1ke6X5/9gJsaC56GDyT2tt4MjrPVLgmJGK88j5puJExheWKusemkEagZyuU4RCn7NCSdVPjckBib5iD+MTfdnAmW" ..
	"aAwDDijsbvvtU0KRAMGHGsUdWq3GjV4ajtSZIZHNaSVKvB/qkB/oVWUafCg1Tll1xR6eeIxDaCnX+X+4c+HUo6cIOTZzksci4J2B" ..
	"QVZaAkyKEkk2fyydlsNp/R6PshEq6v95Wj7YLrFQHMhiaBDnNQRVnCkmBOzuFK+Lq2DLS9W4sUewh0AjscTFlOPe8O+MNFP73z7k" ..
	"YX2J2AK6ncjJeanmJEU9qXbPfGYDQGzLw5s7d6gz5wvakfRsUfqTFYjY/jSfn4xGlznXx7PY1RV8v3GTqP5RdnM5yU31DiGMxLDQ" ..
	"K/VZ7EnnOlzFW42AxTTXZ/T5L5plZRyE7fH+1vfdtYKvKBLb3CQmEZ/xYY65MtxhDfWI+PISDNDuEEjJX4Qnk4jMNRGuHpRtAg35" ..
	"ZuHix9qiY/EyxBOYJyzXmKyWyFBBJsP+QgaL96XNEHb2fUI5cUFjIClqRhb3E5+6MWjYqjqmNVvtIahCucsNo3MoaXRbMq89Cm7j" ..
	"LUD/Li+go5SAoceXnCzIPKGrmtmlFvHsOlyWHv2FCKuywf2SyDz//wEbThqAxXwlpb/L5v4J6uiYv6mf17gi1Bi0ygZy9m7fPo4q" ..
	"6YAPqX6HTRzkgP+FHkfmqWwf2SR+5d7spnxF2AKCk2kGequaAzb4SRteqP6DCcnBHSb2DUID23RRyq/iuCFkJk1ghWEWklH8B4Jq" ..
	"GBs2QomRs0XfbVHRVJvvPWAxSfvtTMtz+9A9fzxdRG+0NvIHTfqVDmrZEQLsCxUlSbfQ4SzOYm70hlpQzBR7X5V2hgx1lbmJStvI" ..
	"6ZOFqDH2EG94uQUIvR7VwlVm+ASP9Q7CXGjREpTmU6Gg3kTC7I5O84W28RxOIK7+paLlABWMUvpWpvi/z7hnsq75oA5/uDWgrzHF" ..
	"k6enitndrEL2/RHc3w3lILUfjJyoVkBwYy9ZPL3ND8MomNKOrA71bxPeLdvfkxfPdcmoKCBIyuZx1CU9HQkzELYCgv0oR5+3DDG5" ..
	"Cq8Jf1yW9yug3WPyrZldl2gTKezlKOCJsnunDbRLRTdzqEPbqfUwE6nTQhjigtWTkXikLNq7pSH/1K5QEj6mAZKrUSNsJg9uDPek" ..
	"5jYsG8OC6M9dxU97o9GDt/jFk4M8dmiLcJd72BueVkU72FL7APMf9yBsqM/+Zodn6n4QhVJgLFHZHSJKjD15Fm7h1b3P5WdFPS8j" ..
	"07RDzK9QXOpns64KWrOl35ciSbQ/iX/VlW0H26ZNSdjCRBb5zWnm1XIC4LwWd10EXW3yy+mmC/OfN5GupV0bWS9SrfNvgdkc8qMU" ..
	"XklbLgUisZzrGmUCxYsFiM96balKnPdvWH6xeKwPJku1iIxrm0ZRizV8wXBtmwO0k5yshyT7aHpoRzUwcuoOZL131CmyBeUwhN7h" ..
	"85Ho8m8OLALZo3BFrYC4sAmBhizkFAR+BgjXl67dCWSXcPTIsE5Tm4GPs7uYdr4ruzhjmQfagJrz92uGUT2zMOxCPp1mjWOZRrHR" ..
	"NvGGeO4pUVd1HujQNLyMXRsBms5DULxMfkUAuFCh5ajC4GAsWRaTvGcUU+SHEuFpCtAWKKZXXOkKwTYaiQV+LLmAeq6AL93dXKnM" ..
	"7i7scU+shdGU3A3c5+yjJTiFi7McvcpXOx+WAqfotdjKrCHrOoyedvw+NYp1VZcqftVNM3yEZF4hMnYJrVF768kgUa33xUluf9xk" ..
	"/tjcn00CX3bJglxn1BnH55efIAxd/2AutOc6eKwLzCw4Dd8DnLDh+OP4kkHQlus/YObBYB82jzcOSLJn7aiacP4XLdrdXfKiwTRk" ..
	"VmWr8NRPRNcwt4Z7GFR99nhv80Qv3XyTIWgJgE+BwRqjltEybH44GRtk0gqHyvblh9tSQH05scDttY5s23kUMlCQk5wTaAOcisr1" ..
	"Ge+batRWzU0dfNROu7/rszRwW4qRTLP+tBFJlWmnQa6hG5Gm3BGgJfe6XgSdzGX+/MB61sgW5KP/27uly7nEkdj8ECuYw+B0952w" ..
	"lieTnZUqTL0/4afwp3H7JVfuPcCDCJ4ULW7DZqEGCOE+yEpQDQfbDb6CLV07kLDFnEAt4rOb+bV4u7M+wCueFXjKw8jUjfiM5g8p" ..
	"Yjoh4P8yNryO0DTBwPbJiE6Ul4pJfmVHBIv85zbyiSeBufBcgqpeYPOxVR2ii9jq7qedmyG15ootTMbi6qnmkAw1UsuMFCT5Bo/x" ..
	"SVbtfSJioePKDdjUQMJUxOYEsi9gS6bG72pT2VAdPtWBFFJQVC3tSjh9YU0Sqys31Bv5mkF434SoT3qH9YoayhNXCdNb/TeZJ6d4" ..
	"e1wF+iRsry9NWK8CtM7OE9y6je3m8HjVR+ADYwJBMWssGRzHC4/GJaiA8oDxWPzz6myTXfj/lHozfqInaKdmJ9NwtG4SY37VS1Ht" ..
	"jnrNo/eDxLxcp5EnPDkSGsdRXKspsfRwccw4sNFwWdtCnADQrzdtdYNm8dIp6owo6jUm4N5C+hYsjTM9EaVB4U0q4odZbsH2ZDAs" ..
	"GQ0uKVZt1joDOkBc4oTYOY1SPSfMfQ8PQjzS4gZ5gTMVB90F7yceIeHb4nxVblXEXRoSWvLQNauAcrqJvqONHzV5gvj3U6PnhkKk" ..
	"zL0UH1tUd2HjKkf6RK8HVqmKp/+7o6hkri7C51zO9o92AdskGa0mQIfl2Tz2gotGlfnXe1/avhTwC5ur0R31YMwuJ7gXMDl56dl8" ..
	"1epLFqkLKs9vNWCcrYyzExXaymx8B9xavb2h7Upo4mMJDf3LbSbToECYIqbMj/sKpel1dAweZBtX5MNWVvhdRF8sdkkRL1O+nYvg" ..
	"67urbtERZPfFwDPCSHvd2rRs4xvX/N3pqzgXKxskO22bNDq4CH23gwazOc6oabmSrnVOWc/eclkvWdOwe+xSjiwXVr+S8yTYIJ5s" ..
	"S31Yx5m37VMGy/lPETnsJc6DlA4LMojJMLYINVOPi9R5mGYs8BMXmEyM3jtKMYNQ+hmWdqH5anL6LWw1fWSy0G/8MYJMEhrmRp48" ..
	"UkwSrGBHi92iJD7hjUDVIA3dvARZXV9wcTML9HPbwn4r0krOowS3OhOOI0YmrzzuHVhpaCfH31evkEMHhH8TYITqk1yo0YwpLYsq" ..
	"muADBaEplRPMDlIvMDZ7+b1sytjsd+EZhSpWpW8kUsRSgaEZyg+pHNUJlzZeCyTuejQYPVGCyMFCDlLM8FZMGvPZ7oa+T41S0VrD" ..
	"NjZmcMKMPk8EK5ONkqiBVwDXZd5MITkU/fhZRzP1m1yBUs/uLie7mFmPK3VsrvlYY+rGgCDtQwItqO2qZk5d018aSdzTHf4k9UEE" ..
	"C8Af24ghep68NUa1lHiyTOwKNbboo0JnimK1GYZ/wcZfRkOfCUXCcz0OC1CeFJdfIRjX3WtpNBNomBIbcZdGQzlw5KqmiYjDkHeW" ..
	"XvYSNHqyzUY49UeLVEk/un2wOpjhyLRYq9kbS7HpnLegE29S9NVEtKEIkYPrWN3VAafIz7cC0qZ3fnq9jZINVYKXmmtGsekhLhKQ" ..
	"VSrmUPlHQQdR9ucrWh+b/u5HxjTu97LHXzZDjrheB4UexRVYBlj6kdcssozz3lKuaKme7ggg3Vbe/5BbN0fhd5+ejrLjSgZTsdPq" ..
	"WT7qWUGAfGxo91HTfwmfJjtcTkNJ7FF61Rn7HRYhHCbrPI0BiB+uKmiVXRK9Kh+icRhV7uSoxghNjH+bgbwJ9Q7GRgnEZp5Tobt1" ..
	"RIeC7tjOpymMiX8C5PwrW6RF/fAFzPY7M5bJ1hzYK2GFp5OzxLERhOKU/TYlhI9QCbnurqkm6O5BagpgvVgCfjd8+PNQi/RPetXJ" ..
	"W7LYioo3KjKth931p1aXcGqo4IXlcKn1v/LziBQyIj6PtNAczeiej5i3JnsBUi6eZivg5yI2ZwinR6HTuub2bCHd+Ytsa9WHvaB3" ..
	"SlBdyqFTJYDJHesedjVcAeF3KsR6+Gl7B5FfK7X7u4IRyy95jF0bjAPIWNbvjBLUV0GOWqnEcA3ub61sbr3BTcxP1mPSIlTHUePi" ..
	"fZQsIy72hUQETejJfJEFMRARCtXmwzKeOt1ue8OhFJuDS3QwnjiCcX8VhP5DsDbH9FPisg4mWs/9/S5Yis4haDdjdiR2iyiVyvro" ..
	"r+Q48jPHE5L3hCvighTn1yDHT/WAiZ3HBXC/ghr7aYEs3GBIIVGcxyQcWFuX9gZJ6II7Jaxqvs8cdY/nIBpo5dvXmHf/IjISVSi2" ..
	"BS98gdXmVS/zasGHug6ahNermLZ08qjbLLRmd71NqRYtxAe7YNSkyK/gR/iNpvLBk/51BRSJy9VniyiwfxeKDyhinLziQ9e4rIIZ" ..
	"PWWUN0jvXgPuvOXxSAtKyP3dAsmedOfLUtK46tSoi75YYCX6xMsfB5YdUlDgDAk1Ppg6n4HjTv9bK3Pm6UGeNljBT0YIN7+r+BQ6" ..
	"KPahfpVH7WIIYQqYCj9RKY83fXnluyfcjgScATQaTkaKLDxpQJZeJyCNW2Tm+87pXAGAt10BI6g5yeH6d1nbhEepMSu3XBRp7u2+" ..
	"YYRYVn2tJA6Q3nyq9YS4Iqwzc5T57jxCQ5oXD+7YoTLFw3tqPlE15bsJApxuAzPNdNO9eCwCJgd/SVQDRZfagwYs7C2S0M219XfL" ..
	"x7gPeOT8YGq9M3CxiOh/gc7VTcrcOqZ1HL6zneKfaAUGnorNQxvoJSRN+Zl7AzmmpbfgF2Ha/QevLzdzJUze0L18ao/wgpiYUaVQ" ..
	""
local PAYLOAD_P4 =
	"+JAIl9Eg83EzCaxSuc+6HzSe5WY8FYclkwGMfH6DYurdo1XkBuvL+jBYQ5Csn5mkpv78eNNfvoeskOfGn8aeEh1kaIKduCkFNvuF" ..
	"ZZGOHcZwSL7k1/w5LZUZK2//F6un+GtdumAJ4C6CzNilNk7OQ9N7igOLmD5VOKdBUdQrgxuCioOiLDMLTRlG22mDv9ItMaMRfMQm" ..
	"a5OfBrDiVBU2K0aBCx5CowMrnV/J6VaTDTIgVCuae714x7RXGBsGkmphWSWigBC97sm1u0NZDI5G1MS65SYdcEtV6l2XIyTIdlCJ" ..
	"XEnv8o5h+WEj9HANdPVWB2ig/YJiRmH4rmXz5GYe2YiPQyJrMhrKOnrMw+NySZKdI3n+c426NBUMVj7xXbS7dgapr3OLtIEb6wRZ" ..
	"bmwmgOSxPSZBfj37ff3KtTzsk0Y7hC0KOC0Z9W3/r4CV6LNmFf6lrRi3b24crFCeq2DtxUFHKqYyT21lscC3Ug1bULBUwY8F2YGf" ..
	"m+Y4YHwsEHP+XzYvwWFE2/JozsfuywFaeuSy3wbxdFUW98lFUR/S1+rpsX7JchfcN9P3sAnNOx4rF+l3Y2UxKsvMo8JSAL/F3z0i" ..
	"lF9zFyqXcmMXMYGQTgh9/h21A11U0Zlr+FmG9z1EEjZndC8eDc+KuyEOpdyKSi7IOUumuU75lb54Z3leMt2H4cTZ8OFP3PTo4923" ..
	"8VWf1ibzla/afD1u2wB/+gwzUvOSmWiTjbFxuE7ky/1F7QYLmC3gt4YsqajQ7cqAuBI6o5kyT+DE/y3zcvxwneq7WBK+zl9he8ta" ..
	"WWcyx8/sbyNEjFy8qsYRKgTu98w+5D5zr0hu009lUznE1B/Qeh8shb0lJkahsIixSWqAinW4IStBUsTNv3AS4Sfi4pofzdzomo87" ..
	"supJ1iNPosX50YMhbKGGBvSHchzNt22N0zOTIhuyI9Cq4CCYn7qUrfFQraYmDuyVq3Mczhjox0i/zDtyIleQyNuomGZhb4glaNmX" ..
	"reZRRJu0SUjY2ZeiPkcKRP+q6eVd/iiZ/VOI+zibbUr/Q2Y6x0bIdL+aEJ9t1sQ7GSzyyBCn/wT6OC0ODVJS3tmI1l6s1w9gPv3o" ..
	"yCnXPYWSsGKicXevD4QSVwnciL4ytDAYFfG2q5Fkwqkl/pPtI6T5dzFf0kJE0hUN0aX31PXvN92RQquWfAmf66YmKT4UZPxMtJaT" ..
	"fB7/r9vkhsmpdpqni+yBPrzOb7iPQe5csXPS3HqBWbCrXpM5GJNjX4WruxHjRdnUgEoM7IsSOA6OLfnFWftWplT41mr5aRVB2ynk" ..
	"CiT2QFFG98fK4bHH8UOmsp/SZBgySeVmNqEt+LpNCwwWlQ6DsXLF28dyViWO4EiHIDd84qFLzHJ41sO+32j70lE4M4rDlrwhskkv" ..
	"CpSIVH+/cY3FDXQAWVzJ4ftRorScmIOAw4dautmdqcVCykFOjWnICzIfmiGPv7e/glEeAtAdgqm6ch/XbQUHyCk6RddD5IOOPRbr" ..
	"CZE4jbHexSSdhPaGkprWMHM5pkaHniicY/8tZGNSUpdOmYf22jklxjaP1wK7RuqnDvmm0/A4vhHn29mq0nPNRJ4l/F6b7MrK2WHr" ..
	"7kDi3yJvnWPS7KdvP8A0drN0GHrjruzVNUhqwoBQRuaRiIwi8L6LUPxOwBKbNNu/g7pmiKw9gokXXPRmGRF2RoOsDrat1AOEGvun" ..
	"FFwYf55b2TKHH7AV6CYyteQ03NKrXlZ1nv46rFbM3zG3LgZ1Cn/aURYJLcZgVtnxx3/v54XpgwkAqxR2KavGs3v1GDCbHM54Rkxp" ..
	"NTmvzU3k/z2170i3aXdWROUo0HOb4JS4rXxA+G3PD4myuxFb8y8qxPpQtsnKx3UvkCD/TSpli9aon86eIf8Lxz5kgrZ7OjV78XXy" ..
	"lRLA3TVe6HCXwj+XwxoHATVj2P/4Wwc09bs4ZQZdt49709kzNfb+F0cn5/Lchn1wV3bhKXCqUO8gmqENwRkQbI9VDzUS8nOuGknV" ..
	"v86/7l4GABB82d2gOLbhXHlI3bMgSaxZ4xe06DgT24SSoWPQOg2amXhFeJalQpDxyv8zIHPsPEes9K85n3MfQyuFaOOOtZjL3isc" ..
	"xkQABXRXKbUhIAAAEc8BKRuoAZv4N+Y11abldsVSGzApM1wyjgd2yYiTIJ6MbFcpiaOlAaMYuj6PsJ0TbeZCiU+Of6GXYvslRuWx" ..
	"4mSfxuiDBzkjCZF8tZNO32gvzxAJ8M88lDq+TZccSk8budFGmmLrB/vDjmGcjuVIJin5CJhRZPSdJzzUjWphm5ZSFhRtZgRNkhj2" ..
	"AdmWGyvw4VE8WKZ1pQ3nT5ucvl6DtdrND69SkzryAfZCvYa3EjKq1r0uT8vfrS2j2GRdfaoxrDI4a3Usu5ygjMogbQ1e0gPnIk/x" ..
	"kqQUlSS4sZKjQPPWcKAjHzGD5/P7JoEXAiNX4AbqpG5uonWChKDIaJ4r8LmTLC6ZT7rIN26kOK1TQqN21xlEJvT/3iL7UVja/5Uw" ..
	"qikttEPwS/B00oh09EnHIaC4DQe6UgHju7nE0iVW8dGuEm7qqlIjWIn8OUhuIKS2hA9h8HtMxwi9KPzQ1scCHIAdSENu+0izbNWG" ..
	"gbKkcx3ULwRH3z9lhIjciLE/Nms6xEEiKnIX199L6X5C54MXZfgZ5XD0uCejcjqsT0zgGxOslSjCQ90mfFlde0/fBm0loXEqW4lq" ..
	"gsR7qPxHgXVku37JyfbuV77r0dAQ1FuP5SxuxKYNP1UM00IM7rFqVoJFirWahU4dTg8zOVWYPnt5zgsFkwCgtPy0kmzojLlj8lCq" ..
	"TELbDYhXGJMpdWd5n9HqaW3ROszyZ092srm+ftXRmtQb2nyuRLe3BFeSv24tZsGgWmqHUv2tg/QmVP6dhH2B19PJdJjOF9KuRniW" ..
	"WzC2TbIKrjbx6h55cQw0hCrqHJvZEQqs12TPLymsK6VEnSDjCJ4rQ8MmXs59pingUWwPYQsneZ8GDEvyfjROfcZfkGxrlo4Iqvyl" ..
	"JhhjxJZ2xnVAvphlzJ4Th7h+WGqnOFYSCDF0OU1/Q0FwJlQzousTdyBdDc6i7vgZukc1CDSipr6jV3aK3DUaIQGNiftlKJzBz2tl" ..
	"XDwrKYvVOwY66jI17l/04QpgJ/WKgvCK4lsEBz4BO0Zb09ORfJxaxI3lsIWCUZvReW/dJM+7Co2GgJRrFMU6draXDXC8EsMT0AR8" ..
	"bg4GZ/rpA9c8tl7KZMXAYy5aNwHVkazwh7Wp/zxkZu9WTihO8GrknFWQFg9/KeBTSm4CGuu06JGYDuqzheKib0kI6o/IQqyowhqd" ..
	"TQG4l/0+4FlH/kzrmnato1K4KxN+ykQ07fU4rCuqEF7Nu51kYaKA8iUrVjOUkv3XNlTtLdT5w0wRCO0GrzT3j4XocbdX81MeWsrl" ..
	"ehC8kRZnzsGFiv0dPv1kFOEUOZEXMC5vwCLfeCekoq/NJj6Sb8XH/q/hyKz9/Dq85G0triW6mIPq5bQpKcO/S0vI7tJCHUxgcqqo" ..
	"qS5s13vrUMo08r9CxRDCxuLMQcou8hgmUNMwXTg31SLpRWfrSSJhQ729mGhbqcHeX4wV9slqygNXsNalwUbCHunaisnnMc1yQHAx" ..
	"mOWDqczAxmaAm5YhVTtmRg91EAV4b3DewhsXr64S417+WbNxUeYf0h0Xoue04yRKs2nRJcFpm3OYV2y2rV04/tgK9d+TrX3N1A13" ..
	"9MGcb/CJPjZkRcoezOnr5C7gnSL9/jhJgj4AlCtjPUDFFw5NDlteGepm/viAyO42Rn453SBnu/jGRmnHa4ClW6jht1c0TDdxTZ1H" ..
	"UzdtJyV/tSLs0LRXe0jGXPsdLradKxbzXui1VueU9+DCafPSBE6/BKp5aSXOcqWOKLThHrBhoCXXM53+nkbEXcFhrOCr1fT2nfFj" ..
	"eSAwSbhsdqi6kgWswpv8SR9xAAOswVV6trCHYTxGvR4V1AWU6lFlLlp14vur0SNl2/x94KjJn6eJvMAy1dGxrka5Z1S0SrMsigOv" ..
	"4d6iE3DuNVXOu3DihEaCi3jP5h0s2WCiGvrlcQqDMzysTxsmIQFp3s5VCE9q6yBF5meT1nncCzl+Ql0QL6jVyiXnGUJf17lwfZjc" ..
	"l2b9hnrYo2xGQ6i9fe+IZS74H08L5tadqDxKDarhz7rsn0MHahoa/SrZPZjEYBluMQs+nHT5+rq3O3XnB+VDhNFDZ0GkeqG3yfQc" ..
	"FfUofXupzUq/2EdlljM58VWJ5GPG6AMS0HFuSUA4aX3UjLAxWKM0K96GbkB2vXfNXaRkTGE4fQh1a1HKnWDPR4o4rJO+1aR2u6u/" ..
	"M039OchtgRx3pZyXnR973KsZqRmtksvE75OB/4nfm0+vxjQ+qB91No/ou6OwKE/vGsn5Hhw/Q4sXELOVM/jrYjwU0HtivqjHlXm9" ..
	"hl6jB/dPTz8B1N0QXpsckX+mWiT+RqBLT4KB2dGgKWxdj4BgKjcuxaCTwp3JS/660CXxRrhHAMyZByrtkM6MRpBB4TzZCu893l+A" ..
	"O4SyMAuntU/jZYoxzGY9yG3FMbe/UnHQagEyl6q0PuQD7SBS7dG9yDFDniClbHE27nDByBg7Mc2+DkXdT3I/a7dfAXTgwCuC6N+8" ..
	"od8NAHTL1QbMmAoY4NVz7GTBYENwFFFceevu3KmrjcXediW3JDf+BszEZvkg4pWwljaLjedrvZBpRA1Og6m1AdQdAOIxJu70KWC+" ..
	"r5pUEIKtk7MI58tqRVtqtxUNur1DmOSkJoPfR1uc7HKKE0KrFpGsGIqC+79AAixs1omLJ0DhTM7O5VdTOJNn566GJLabO0VBZDCI" ..
	"/sVpzhPZ9MbNdykiQmcYtRvWJH4w82V2dtgY/tBP+BiacAza/3dQJ5FyyxpxYNXO4LI2inSZpxByDRCNQ6V94SaX/kxI4QpX/Jrw" ..
	"1GPgG4McMSzBKxphaO4KA3SSoKS4UDog4NdHSwSm8kzWsyWuUBseebs0wUD3/Jl5wlHHOR4nPbMqUR1IIgHKgfN/onN1IChQmNod" ..
	"pd3z8/p/dAdX5MRMOMaee/XZFA+iOuPEsmKNkCjMxe/vtib0HAuzOfD755HshScMM4NFmff5JaSPIkB7ADaFKd7rrEJukhm11mJC" ..
	"icZls3VN4IhYnm5lP2o648KvhuQcnwOKGY34fRitPHdvip0cxiwq26xKaEnS32sD1OIw3Y4b/F9iPlSLO0+5OOwVjGgd5bjUaF87" ..
	"SUL/jduDnZznth2sw0kZf/Twf2VQVu+50ud48XxU9FrMzPaql05MfgXRyaijfo7JJANxY+oYgQiVOLwviZBSSIXZfA5eD4Q9xjFi" ..
	"doQGTOYs2komwXayzxAQqc/Di+OlxRL3hjBb7Gppubsgjao7abYPNb+IVID/APcwVIf97NbQn3RlIbXWloLoOIdSBKo20uCHRpvG" ..
	"Pw5+NfFnWq2yXhI4SLV2yG5Ypa3UMdG9VwpcT7dP1jkuaOslMUudTECpzuJDUxi1ooRUcmMdg9qsnqh2yekQcT54a+eYHTwCwaQd" ..
	"HVUJWaSRn9NdvHvASjJ49CM1TI2G0L+jHKfAyJUxlpBAEQrNZiIIqnLTCJP/arNpnWXdbIlDYwffYDzAJ3LuctfB+w6g9RMXReF7" ..
	"mKVvV/TBk+mtset8E8jDOQR8S48C7RUZTJF+5bTJ7zIcvI3JrWE4taGxdQ5swJ4LHFjMkIO9cL2TuMk0dZsHGGyyWOlKAfEC4kLo" ..
	"IbhiayekNafGwe4VYzzYpwnYzZult1j5OjJvbxcFmU0nKnBFZPw9ZtdxMvJN2ajE/u7tEzt+tVWI9dK1yh3VdmPj4kiXt5uL2FOY" ..
	"3102/BBTBSVb46AzU1u+SywO/tmrEbSAIm2qwpaBIHlOlzWegOhw11FH7yUlL0ATUN+mx4fPe6scD3/L4auGoYqtikpz8qJGdl5J" ..
	"ewTPOrZxxIX0KPcwMTkb2Fi98izD+AceLgeHYpvQ4yVhS+5lNgerN4M8WALCiky6G2JFK3AIdyEUXOrQER4NUivKTtmC7/WhxrPe" ..
	""
local PAYLOAD_P5 =
	"wkjyYTsv4Ics9UPnD6GMBwy/psskixXquI4CBB9oDnNpJRUl9HbpxxZb2bRXX1uyegrq6wmPM1rQYAbp5TToc8Rnkp1s/cSdfkJT" ..
	"Zs8kXK9420BbzXGUCNykCOOPqMmx9BAVNLGJ0mM2AOA3fn/uf2F+XtBA7iieYWYUZCOeujX/98lJuxX1kvyZXsqs5mD9KvG1iR/p" ..
	"vjV/Le9q2uCOs0TdrRdCJuxCN4729GtTnDHGsZXX8+Bh8yziM+eUi/tnijEdemJb4ggyzqgfC/V1b9CoZiSigVwo7ji7SAPCnEng" ..
	"KdeFltz4ercKfQomztLQHE4EwUn9xJLqKFYwP5Zd7QccMMO1RXeJlin4L9Xr+qW1HJ/ef73EfAVqIvSwku//AfkYMh8nTdkrsa/+" ..
	"J37F2YCbRnOzJ4NxdItM/LBEp5mw/aZSzKdyNCSaq0Oveogelzuncwjrh+bvYEFkXSmgtuwxzIrLjkYH17iD2WraAvkmgUt87vA4" ..
	"vT822/fXFuZiZSzgNbHYEfJvl0wqO+Yf6jIbfbQGDPmSL9xegufVD+jvNHCncrQuAHtlLeNirXA4iNBpb49qqKYLbnrEVdzlGt/+" ..
	"Tqra/qgetkIFHPJ5XVSCi5S+XVM1kXI+VP+O4LIrvzjR6y+bbJJNUnrLIGV0xbEkLL2/YF+ElcFM4zrh000V4ipSLaMMynAnh6EL" ..
	"Yzulz0bs+mdmdMAyTUyVjaUzCt6LRG0MIKgLJS9mZsy46U8VvJYqHhniwnLjWO85KjAzwa6cu/MSmUIm2H+vtT9ewwuwmI9PuWdC" ..
	"phctDVW3addIhe3/nJuOc3q3fEQKYZQrHuWZJ13eOFM73LkwdDzf82Hn9L1beg2kV26rkHYlmdkegSZzQ/JoGfyClHRIqjSsIpMb" ..
	"IiLCpvaRJ8hX+2om9x+ykE0zvbwaYkgGMghpiLGYmRePTBonmN7p4CuHoR4pqQb4iVHsGK/SKDRgmnWFXtb09rHnvDULlh0SlArM" ..
	"TAr1Ye+pcJiOwIsMzDFTe1opP0kRGyDvBXhABf5/zdnREJLIvQ9rCrEhbyM2uza9hVTZMMVXOuoKFKE+k2kyLDFlomkJ3Q8MbZh8" ..
	"s18P5dLtfXcnYmlEHMnttUSNM7rbmd3qGKlyql9tF4mGKpoNEN/ZLWlsb024aNIim+JqkC4ER2kj2K4brY0HKrIfCB8k32oxGo3Y" ..
	"BCq9aS3nSAYRSwphqbWQFCymRGbudy1E4+pNq6i0SW78wON26PiKxTBl6Hjdbdob4z8OMDDPzmMhHKqXLqsl1FNQYMc2e/og2OiS" ..
	"hhHIE4YNN5MKG8NRc6/g+7Rjd6ZIig6p3ho23g15/OrkNuPT/m8lmTm1i+1fL0l/EYGyBEjCRP+4lKYjvHTz9dtdskHOMlnVRFT7" ..
	"XtW4nzRqStVgswOGFM/mgNguotvChOPC//4mdsllOwF7651QiGTii6iMYAlqfrZUutfR6mltd1eEK3OgqbA9RyGcpW5yl+GDC0E4" ..
	"yjvcimJlUo7fu5BAECyBhCx2gE8AOXW1t9jG8es2iIbOHd3fmdRrbrjG7F4LefjwhDG5Glu31DBSC6LL4IitGlNPp9KpSEBf8Q0J" ..
	"LQuVvegeM2wa1RVpL399duOlfXEgwnPJbhRn4u4MsibPd4i+lNzMXEfzV1UPns85cnsXsseNN+tYkpbrkYtHooqGi+UIkaJ8xg9y" ..
	"8JVvQF0gamlVN9LBL2JVNdAp3f2qt5/2Oia9bf9d/QSxYOXIKFQrlSSKz16HWRPC+88bJT0utf+2Bn2sRe5jCFbw0PcM1of2pgPJ" ..
	"SnUdyUZONcYqvVPOR56moQZlzSj2OWM5lNuy/6cnUNDSTGy0ZTUXuML3rJ7AphQ+nGs5Rn5QtUKeL0RmyVtXe04OLMNV+DZvocsL" ..
	"MM+cIhleb8PlSMyGQS+96tjQ6V/8AkkMMU657bb/QVzzwGrSeGVXqpYt4KgIZp2d7UpmW0DYub8Uhs5nJnihyHDMCEWDdq5aVi3V" ..
	"wMFxRuvDqpJMDJHxmQTWD0Py+IRwubQ0b4IdMdAKSin4ienznz8P1v8QfpqJXmc5ZpQjYnG+EVYYWdj1IkduMpXvzj1UCnsdAjqQ" ..
	"B00ejWdwZ9QvPf7JIljfuRfSS9IIQ//TjMIR15iKQAUfj7/FDIryR294spHrFYYERhlooK8R2vQrPniufDt1J3GPKNtio+dgZE6d" ..
	"JakpkVhKfOJKek+rvBCuvPDrp1C8uVpVqPAtAYcna2RDiIzHd/EKcmx0B4l8gHoHbVfzo2000FYfedJ2/J2ven48FLBIiNdbP7Yw" ..
	"iVz0xYBJDigqS3f60P+5sHp4ZKH0bRC+tP0oSbOhPCTV6snSFrN/WcaIlxJYSeOntfWYiotkt/801U1GGKenEEYfAs12pzOIm1dv" ..
	"pYq/uXRwX3yuBU3IVPOAWIdg97+gNNJEGMitRA9VKbL/f8xWrrbSpppyHiVbENCpgvVbX/YSRQYUftAddruY1VZb01b3E1rnh3pG" ..
	"c3qI4azDiGgFaUEgZJ5v/5wGn9gK/awdWaaqRGRNJseGS8gynrbgQ4yTbnLiXKac1KmShxnFYmfHWY00csvsft3zIXXHuwxs74C8" ..
	"ngRYLkHC4yDzwzgoniLv4dHoQsVmofeFPf7O5PzXCdMtyvMmtdxU12SbmwuwtdhJc7i5H2lbKFkAP8BlwKQUegQFXlQVg39nqYj5" ..
	"eXcJrIH2uhubh5v40S3uiqGumxzIsNFbKjkopaF49WcmrNde3ZpurHRAz4F1LP4dykd/aVkApoOTli97hPp8gIjW07U2koFCCSS4" ..
	"cRNE8wJ02H1EyYm1WGC0+Jdk9o+TbsbkihMRfZGyWTTVqjSYYtKWa6y4RYpltTJ+9IO/cpoSdHAk/Hp1Rax+ilVlu6zkCtKOWO5C" ..
	"e8zH5QcWIcWwnJYhALGTid3kVRVQ+MccufQ/fTTTHq5scL07Wxc0Y/zUIMoUdcczw2j3tIXnqcK46rNvEwI7WS0hEUP4y5RTeKay" ..
	"O0KbiULDs1gfYbqWvJDPt2PBnSG4pOsSR/ae6P0CiRvSz9I5mDDft8J3mCkiVT7AJWCXfC9KD0Gt23WREbPITVfKfj3tCcMpGTpK" ..
	"1pm2UV9BnLOvHxYaI9o8uLMJKgDquIK9CdfYhFN4sq0aLFd2lYDNiajRyNjZlJ5hvH+bK/u1pA9y4ooHEUjcKlXHByDaigSR+XNK" ..
	"xF8Cwz7dmrlpwo8il07yGj/txgj7yVCk6/1GQP6yN7goyTjACRag+gJbFg4D2z3yLa9rp49U2/GyTNeSZJav9aUzyxL3bpdUJ/xT" ..
	"4C5/ZZGiE7RCZ57wSavxsJQ7Cv3ufN2Tknnw6/AY6Fvnw14bgMUWZx7RmxbXYRsDGaBFrSG0JUIlNAYfLDHcsf4F20FWT16ljRxY" ..
	"DsylxxKHQ11voTPegF6JsDRA8MpR3ysjdDJHsianX3ZPqgWx8GoobPzwzR8iqVZ79iKSWlOvIDVKn1yZoxpKO4aQtSJApaAMEQjv" ..
	"iO5JY1OydSJCuCoHWv6KkoghKFua5yZXzK0M4Kb8sDdLi4UrMa0pn9ri1uT8P2WfJzjipJq368wgv55RcI4kgkKpUYaWMMffKVXG" ..
	"BZczcg1rGRAuZEnH+5bWjCXOb6n301hl9EqxDgzo+FM74NOyZVl7Mx2Iamwc8U47LGfnpR1yCqV6SUD1CNAOmYEvpq+2mmlbpf+2" ..
	"pdqfvGU8Q+q8R2FceAALLbcaZIe5i9xCMJ1XGlX4B6Zsm6RMchyrkmO2x3hZy8kpQOHOK23i1XJGz+nThLxe+mw6RoxkLdosXQkT" ..
	"Vi7Nu6Etm3aVBm+1GlMH5EjpHUeLkaj0wrRmgF+z4qTICUO7CiJ1q8M2Pj98/Tya4eeh+KdEOUoAyBmm4ipReCogxR4MPimERarl" ..
	"dxbcABqJjmt127GDKkbk5RvxC21fAG0Auq8OZxPXkgKRFvLh258BUVS4103UodtHf3DdN62JRiEERx524+r/wU50rGuiyueKg9qm" ..
	"sF2lDqLw8JqZZjqv8e3mlA/u2aArUY8iU80iMUgF3AWKg3JwXG9eI7f43/LxB7VKECC6YCosgXtjcEPvhF6eswtAkW6egVjKkfK2" ..
	"EsQeaLp4W64iy9SDvak7IQmb/SGx3MZkfOecGMuktqey/PjA8LKWrF8rAG3gV2wC591NFAJXbqWEO/Yq9Rja5zqGWtW539SyYLEj" ..
	"PKCczj1c0FqHLCKR6NLmDNIgx9tVRgdbjWdkcUzmBgkfbflAJ2vPi7nNAhbS3rPBHxEu7AFAwMNSNxzmH6+SRdMfwBk8CcsZcXcU" ..
	"ha3zz5KDHqDaxPAfAtbYcn5BUNRja082+T8uscEVKukzOpzE3GN8/j00M0VXUZB3b1WFhI0WJkhGZTK5rcQClEIwoPnmplTicyHr" ..
	"eXG0/Cz5yFBTP8pBqbxswEUN4IATonyC4lSSXwbvpMDAtABE24y1ROLyEojAJ5c669TsPFgSKqn1yNZC3B8evzPVlQyF6GK8kXvv" ..
	"J/hgcj/Dr0cK6XaygJv2tupU2LwuRhz8Rgj28fIFfsMvjBFwV1gVvaHhjgoyLOESh9I73RyLWSxzhw5Kg9I0JOY8tNQU41ekFuMU" ..
	"g+YbMquW3AxtARO3XRHrSx33xbGUShuj7i8p9N+WiVKbeZPQt7fcswPCYKemeHT4tEGkmyiodkGycCZpSkQaYYo2zhePVLQFKy2v" ..
	"MAncdWK3MdIpc1QfyirFZQsxuEjB8afsKBh0387d1dcroJh4GOeQyjBKmYs4+GKoboM+XkVunie7LfOGIpnZV+72DrMoxdxqqVeN" ..
	"TQNgTbuDT8YrGgZRCPg9qf16AA0oMe9O4d25hUGRpk3EOUFSqZOXQ5NMN7DdmzZUabpeoaDYyP0q2lEFX98BByYSeknnpxBKLn6o" ..
	"p5+PioIkXC84l4XsdxInpzwaimd4b5M0Ib5m+iUFhzNElPUrtNq48NSlG9cXvgO84TPHdQq0s4rSWbS9DJvXipug2k2PY+wtLv8P" ..
	"YvNMOLTmiqFshRoEYW2Eg4IRo++MjNp26ojy2lDF9CJyrahcojBPBSQAm7WSRo02gv2Jnwa0WhoPB1P9FLaz0pdxJFSBhdiITHCq" ..
	"MQG+E62AWaTuWJuFwPQ54WW1lXk+Ei/srpRJD1+WvhX7bcjJoObAEJ8zyGufLasNKXn2H3kZWjXgfM9iZ2MJRV5JEQ1Hf1EL/rQt" ..
	"zIonptMt5g3UphTwEAkewxoOyjXsTB4All4hGi5bwiXzcLPiEDdQwY/7x/5kSBHO1uZF7C5rFuipgQCZxBLxSZJ+hhjXJpusON8D" ..
	"kLUYBigUTjFd/OkamGqxMA5YUpPk74XJowsnbalF1qdCUNCfbyevAzPHKXlfWZ+o2qrUU/H1J/Ewx2VjBcjKMAXMKZ4QYX3d1ig1" ..
	"lvJZJA+Q/2xLsMWW0b22A6GFaqNozwxlZYgIhUDZzUq6o4JWv/uMsuUg8w+ahe2utSmK3FhZqpbRWG349Lnw8XoIXZVNJT2eyF29" ..
	"YSCFKfqg6rwafHZZKtzZJeVUYoAR7726YsxfLhg+2WYjxli0vFNTDD1ZXwam8kCTwbeuXMYHKll2qktiZwpUi3OA98dBDEXAIwbp" ..
	"KgEzoAlNLSxPK62Yh7k2RarZNOl+BKUu0c5KTFSBrNo0RPyiXqa+7xGgNS4tCT+eCmjoQJ6A72K3NvQ60Z9YUQMXFu8W53FIJI+n" ..
	"d0pDIuq/xCEfbiPcUNKCUWoh3NjL9i3exEkU4X5tz6tWbZiuz69YC9O/0g2Cfx4JAyZG1yJlfn21ikGvnkMtdDoq2QO3YApWFD0g" ..
	"IVhcfJKdNfCHgExMUtwoo2k89bx7YMIqm1BoWociYvljpZBtCBp/zLHSUlK5ul8jXXx4FAnEbNBwLkdUqv7AuWOeSUWfi984a/AE" ..
	"OiXUzKW953eLQ8CEnbfpeYSqFJ/SzVJFF1io/xeklC1H8AbX+gYZ7kZPLEnipKcw4iGzcugaTWzwNcSAjDPrprqea4duPPSXWHVp" ..
	""
local PAYLOAD_P6 =
	"WBDm/eOgqn9z7v7eMgAXYgYfLGZDxaOWr6+WMMDL2/zsrucZ9507U3rz4Xa9gYQwdPOvVOqiq//irhfMr81GopBZYprQ7fj3YZTk" ..
	"x/J7XykzY6xst37gx5VWpu1pHgtGp+x/S2ret8EpJr4WSyw3m870Wm/rLn24qwqxlLUBEyjgaTFN9cT7ZbEorZXdoGUsxuUwntCF" ..
	"T0Q95HB95Y9yxxrssjtsxM2Jo33n8+R4Ti8d5BqCYkVskDl5kJsc6wNy9MXzN/ed7ZGZKyIFrBMYNeoC1Fl0FpmtTl0Gvdzg7k/H" ..
	"uK1dKoYiwyUZ7WnGnXGKR3Ay4zYLyxAL7Ut5T/guj5FIrg7DB5QOz0KTdRNSeIOD38srdy34rRT0vTPsevXI0d0GN0JI8qzCeF3D" ..
	"OXTfAgVchixUHgfHgEm6HOVyzF8iia3Huehyb8Z8y0gtHwwHLVJfVr2IkX4wyOf3SoEBxHj3pizHkqWdfvz5p2LRs/foeEb5btJ7" ..
	"Mt4LRP8KXzk7KvO11WCsrzB9e5vai7UKR450Qvsmnri7y8dZcG+5DnONPYxyIakuK1rULFVEiCTXox+EdXIsmruujiZevG4ZNWdH" ..
	"FYdQjWxCTj0ZJ6anr7vOwkasZOOXtdUT+9rJNlcbnZUe6B/Pq2WiPP00M6BwUKKpyyGQLLV6l4LXpn/UGPKrAtFDAGVQjcOIto82" ..
	"K64hi7K2S6KA3Ea2cwWHax8O3LHNCtqS2klw7Tq/0x7ZYxWOYH0lcT3F1NTd9kK+YBhVY2jxDPmnSZtvxOMS2IBpRS6nvM0TQiPA" ..
	"GYG7hQGh1pdzTYGrzQbwJl8kaevt+jwwQtMun+y5/fo4Ii7t3auDoFE0znxEYmgU1QVTLz5eNz9Wt7/3udZb3KUwKbaAI1K47ZcF" ..
	"po6bkx35luEPQMpH6YBR6ib14jP4T5avTKBdqFyGH2cCYWQpoSbys+9DQzcj0n15uSNaz26eQVRk5KcuYwliyeM/yFAXqG0bBGjR" ..
	"542hHeZ/rtn29QNKvzCnMstlVBpgCEKFwLHouPELbmwGFBSIK9oVOvsHTORCetly9s4R38RH69k4KWNP9JbrtG4bM2xCRHxIMW19" ..
	"pc+rGyJ68AC8EclcO27uOUtq8kaOkrjzY5i7b1t/Y97t8cpxie64Okfhm4MOh6rNx2F8ickVr159VXubPZklzbQKkTApsa008jSD" ..
	"CgWvYdG45WR+ooaQK6TvY/26rVWhSWbVhXqFw0bQ0VsRJRYAbNQl1HlzHmvP2hj21maBPuG7QQa12CSSO+ay81Ymw8qmI6OJ0Xnb" ..
	"7Mr3+BKNv5Qug5NYP35De7yzhiE0E33dRe2EtXA0BK3LszS/SwWn14+61YZuOsCQgf+D+ECNXdMQ4371D0wW3uVilCoOhiTmT9Jt" ..
	"4oPWxmOOGcf7aUfmMuYxFCIgwgWGr+Lk2pRPf6+fWIw9HpqK2aG7kWei2h1G+6ArmeSKpWW1Z1YAyFwuHqbTMPlHlsiTRNrwQFUg" ..
	"0oXU7bpsZzdT6QOa61/RxYmNxj7G+VOQ0b+4EYVyefACUNOxUtwLFy6e/LWkspvJJpAFax9uLVV1PkkE7Fou3G5Uo08FsX0j65Lh" ..
	"IBZ3MnmPYZgWN7sXKw5WI7OXdVKYsT8Eud+kfU7ZbIa9hyA+UPDZCEm4U5AP9u+g8ATxWj27IHtDgNQTL/QsB9StsdJp7+7wYIKs" ..
	"/CxSDZtHK/QMG2KT03mkBFv/Jq0uzBc0rYnCcXsfXzG51G9R60OD4nF0we77zvv03+t3C+esAKZ/r+pS0/Taz/u6J+9pCTaYnSmn" ..
	"VAVak6tPSBzyLReF/Eh7WgNDfxwubnQmh2dyEh5ZEHESBJJrVTEX1pupt+zSNo85gpnJkfMU//IIC2aAl90gJhxQ0R8p4nReGJD1" ..
	"nABLItX1BGGyJMZcc+F8pg9zvzSQ2E2OREiyuFh5XphZeg4d5La3ByAasYJfq7EK4YZXV3PcC0rz0Oe0AyJivUov0ok/BFV/MfnC" ..
	"K4CbCSGyIV2P6sju1QX/fVFExh/JtHeInn+QRsf/nvdRqNnnwSvHv5yonsan2Hxn4ggtGMod6nmy/c49IlkyUcI/uU70PhkzDvZ1" ..
	"YKkL/meuQQrScqe3614dCSoK87VQ0ChZP+tyiuo5f0PHstUenLToZwDDpfepdXLdGMKVm+qtL5JM1+/J7V456pju9PD79o3QM6FD" ..
	"ZCXff7X8de3RGv9EjNrVNa1rnpVbpJ+XezP7r7dUa+wFl7+9Sk6YJe+lZfznI8BuNi2JWAU3Hgq5H/WiYXxkfnRulrkQc8vUY+pJ" ..
	"DVlaqL5FHBibMrMLOkiXpA76bLdyAHXyu99E+f0M7h137XVgCuHwcosu/hbnmzlWb36K4NOhHTy+pt6eE9CpKdt0G8S4RAMWkSGU" ..
	"LViSf+h8RSUGx8K/Ykgle4Cx+GLfc/l6aLkgGfXUHbZPkHP2iA1SIK5Ubb5RaCxx6y9W+xzCGqBTeqeksH30YXtnP5wsGEy5kJPM" ..
	"aSpu2YHv19wj8iLfdVIqQUt6CGwQaYjZf47pe+hlqWJQE5Q3f1kxgtaTqJVsCvl3Xcb71OOK3ejQoZLHPU/9BPnFqDBt8Ja2E+wB" ..
	"sbuVKihF5l3mkXe4yYoTCszUaXTiCc7pwJu2NEmPtqzVZXeI772pB6JbKvYd4hYVMLUsnLqBfoe78hZ2JdaBu16hpCTIjBslxxUR" ..
	"vp9XMMWvelS12jriK60wdMmSkmkav0K6EHggyLvg6S8Wq2rb6wZBFT5CL0CFbk1Yp78pXNsMc9lg9SPxo6QRALPzpeMxvKAIne5v" ..
	"5zAECcQNK96AY4iLHZ8b1NOCrGPVXK8bHkvdlP0GnEA/Vth9HGmY9r1zkH+Pz+bt2RnBxF/r/DDF7DefiabWQcmksCGmWJnQsqby" ..
	"vDncUpDiRC38Xd5ItrCqLl6mgc90ZZ2IJnqKQ8/S9FXcG2Liqw6fcX5ojRxTCF+dROSGIlnEf822nXnEGCWSEiV9/VL57M1OL3HF" ..
	"/nTNNS6RCV3L1mB+klLOCskSte3HpQVoaydqkzcpQi6JxWCqgw9I0qS5iCtSWa65R6Pjlqk1ri4jTTK5L94WWQJorkzlBaiQSo0M" ..
	"gpYJRUuwOuOTIeeIvvkzqZCJMFTFhhfv9ZdMm3STy3uGvq4HFzhNlhNm8OHtFTo75TjqaRzZgWmAUondUb3cJZGu5JfyTqG+OXl9" ..
	"nrFKhZDIJa6vWP0C45njwsXewWUEqcs5Mv67ilageLQNJKtEip13JgPWUfDc7iK92jU7Qt0zVNs0di6vTfPy5Yv/tFW1d8OrjAKX" ..
	"feSWvMB6F0t+Gryiir95cX6NlzAi6Azg0pNjZHEqwX64HZfXSleyCNZ3UNGtLn0BFmr7awq/IiXa3sTALaDAWlABdvUfK+/Y5jzK" ..
	"nqJxYpeGtGdSIWIPC6k+XYScIU35lEY8U28ngd1wDC+VBFKKggwZgtsbwSfbTnlY2TnxJCOLiCHUeQGyrU+T0fssJHpBTjqdO5Ls" ..
	"KKMm+H4aeO0lYDUnE22CIcGngRL5aMx/q5JXmV/UvTRNYE8WJeA3Fzr7UsBZ3cez12YTXHqgG1qOPusPCfkbNFXB1KqekDnH0pCQ" ..
	"mUmj02ke82QSD+WbQsGZjx3u8n2CBPMde4LGJFlsvAiD/Zbz1DyIAZBF4s36C2yH+Px4MntWqD8ACfZeKpF14G6oOELa7GWy64Bt" ..
	"ps6NtjhIwEq6PS9gQmiR8Qyg1hbxQJMjqT8k79SlFf+ewaVIzCDlJ70g1UMyoFSwzTc0snzRbcCr4mDnQNWvPHO8V+8CPCAWtrWc" ..
	"DVQxkJOYTYSqtrPC2qFRroIRTeIEtN+XJfK7snweCzIl/dFhWdmhMxXViMrjf/1oVf5NJ+u+n9PwuFVJTuEjB16K1/sMg2awQH4k" ..
	"8dSI9PXPKDQUkOJx1/BbjFiUm62TSBNYGRWUqre68EjwID1VuHuDW5BkJd2fcT7KTtj72oeBTV9kiB9kD7HEyRKUVpnOEytFWCn8" ..
	"kcsbg9wBDiYclvMfcthRiW43FwWOReKQn1zaGI5Gl6o6h/QUcubwrSLD5ew73xyQeEKWCL1or7eZabXrsW/TjQrMb7ziuorazFxg" ..
	"cKtLoqdFYMDE/Xp+BxSmYDcDWIGCZj2SNnfjvR6d80NZBltc6pJw8hstMkgqhn60wTsEKM5wg6vAbrHfPcYAMTPlZowDymLye/W3" ..
	"j1dHXfU6n4gY3LAUcFX/EjafTlHcLgCpOxhwzCeuSov2ufzkcw2NB1Livkic7Hi4JTDL0l2BDTGeVG5dzTMkVQ2dJogixNmEE+6W" ..
	"7K9qIHMWipqjL9fB4yN8OoVTvC4uQiwHM7MUVn66wLRiWcprizfO0u/T9fw0GnR7LXsyXsXfCdd80kMvjrVZZl15Dnpdz99CFTFy" ..
	"gJES4j42VdaqYNKb0R4dPiia3ztNEap0r1W0ZdchJvX+RIIeig/gR/zZ0PKtdhtl1O88tJdWbpYKGSpASa9T512ulqO/Y8j1g86K" ..
	"gctiXUTb/wtjxMO90oZxNm9jm6dW5uTMOqD/G61vi3DRaof+moMLD2WH1DvQGQBm6GRDnwpPxIecQFLUyPeYvWiJPmVMNurh+TMq" ..
	"rkFCyJx0EYCsv+muhHGWWHCY2sPVxyJrEejPBU5c3ryB4kwhxH6WySxCP5Z2dcCz/9kOOb1v+HogdUaaxvfNPq2Sz2SqfLNSlXhi" ..
	"bDipLoSXn8g4wtUs9hyVb1yes9QdZF9UoaY92qtTF09ZE2aSVjW/vTwZbN808QriOecOfNC6jUOvWfk735Jmf9hR6mmnWesiEfSw" ..
	"WXI6kaVQSqqOacHB/NWVM4GGs/k1lfpt6V0UAYvN9RP8WGS2ed43ZDfx+dU+TRK5gdhWCRSRAZ/lT6strCFp46XdFH4qp7b+jees" ..
	"B7BbGCWIjmPJIm9tsRvn5e+JW/IpjYXtYxW7BH3VDNoAE4rbRnZTR6JqH3HoFlyUvm3N1b6/1xmHJYeAgj7NFaL6x7nqgvG7u8Rd" ..
	"oVEhe4hirH3mtt0cFZ1L389lnx3HbEqiAG4K7euXbtA4wC1Hm1GXEtmEMm6ypU0DVjHsB2BwDmSMj6bgCy8og+xVqiJ7pKUnawtE" ..
	"2+nq50B398dcIFNdp5VnvMGOWXprt0yw4IqAcJ1g7aG1O6ami/4hVKu/+27LzBE+5gUn7z+s+Znbhtc7oHCxC1I/N7HGCAtWY/EZ" ..
	"IxSYkGX+dNEI1LFDIFu0srhQd+m292afgPw3/S1Y0Z5k7kYEJOe8R3MHrcKmkqvcGguOkt9tbojtdzVmNz6XqXKfVdkArq4Kzvh3" ..
	"PfETPBTJQ+ojwTIFUsC5N3BzbqlE3NkIqLAfk3w+AX0AlU4S8A5ZnomxnEgl/9icw8KGOarjewSCDQtibxLo/Xbwq6/fUOiSyyK7" ..
	"QPM7vWhAxbH6q5eb7DMKTC1wk+Q1pfnuwqoVVKxjRU6RnA3r1QOQSNxaaaT4xKyujxOlnk18e1NVL6BHfIPA/PluklmTn+73ZtUs" ..
	"dN99NVe0+csw3VgIoO4cmlICFkD5+SS9uSH2FmXR1qOaofJcfJ89r6XZew4KSNk3vDC/v2i0gWTr1fEvH0mwsG6gBbl632rjnMlk" ..
	"F2isGL9DNiEiQ0cJmDbbXgSOcAAJPuEB8t7n9E4edEA475Azfu3M0zfbvMAUINHJidAOKzSHVIbGJoe6IiprGHwvNadeYrxA+UcI" ..
	"7rvgqxN3pjU5QZs8icC1/RYzU6tyBu6EOrUIge5WbIbm2S9cUvQY+Cg2RX/DD0bt7UjCEzhagkagf//WDTbMT8AmJAb+E8lct0Bb" ..
	"8BIR+5pwbjbfhYJVShiIAj3EXk125RzzXXTWnsoBRKiaI1//Y5kANoPyRpPeHx2t6MFV2f/3Kd/zZ2LJJCixlbSuWQp/K8xfEEJb" ..
	"eOQwwEde/JCeDhDhTs6Gow0OrOSfXFvgqaNJ9gRpqwgzUabMVuzH/ZEPvljpscHKodGGo8wFx36wBmmQQjfDjkkY/Eb4KLY3I+bd" ..
	""
local PAYLOAD_P7 =
	"SwNMvX8QXRYZGoE/cfN7qTJl4YnkcGVZb8oPF5GR5OZGzFWrVDFYfufMzRv7ex8u55a+3n5BH4rJFg8UxbZiueMgyeN+HBwEmyOR" ..
	"z8jS7f1fagNzJunB9aE4HPi3a/5NUCUrfknqD153eIGpPZe6Vqt7vSTCZ6k55H+A1NBPD02KnH56i9sFneGT3lxWcKNxkQBvI3xJ" ..
	"g5qhIuhHYxR8Zd/z46GKhK8LzC7kn6jKHXEcUgKWU6Epplb+tLvdFFVgTs+iX61/B71rodKQ9bIP3xWR5Zh0jynSuvrMWDU0tFFP" ..
	"Fb99fqe9YA3uokQBOJyrU88fJ5JXLoO5THDvsoqjYPXVRe9h6u10Y9Qs7TJt82ipgjhd5zEb7qhYgzH1Qig+j+WNef9pOSmn0sFf" ..
	"jV6osBYuVbvPb5FwpJ69rqvOCAd0Lv/aO8j0Vw318PRvtSXPrYWdNgrFVW1W5AVFyArM0DTiwuW3k1r+8rIZC4tPspP3CW9EGNrD" ..
	"JYHSH9FPrSi6YH/nLsrKdNFYuFqs6xUKTpsos7ql9cm17FqOmHfzJS3Q72FagS+uj9/1lrY63805SKBoMpQFuzsQK9X2k/hktECd" ..
	"m28F+AU1FPnhhr+Zj+WmifpAd7bWDTvkpvFPanujJ+xZeCE7C/UslfeWzNb8ivrHYKXzpkBuqlrJ79IQqbq8EDpssV2lduu/N3ia" ..
	"trJhRDqV6rH+6qk//9001l1T4lCcH8Ij3aw6+ORqmR4o+PdoQMmY8+aQHEjrvR/uDan+ZdEIRbNzD4YBOuTXYFfJ8yH3Owjahoom" ..
	"s3okhDNrxyOj3oG4kLeIvkgkANvQORng/v6BBxLlpsGaF8w4DBNrOX2k8NqL9LAlMborktAfduhJqvMql0OpDGRo7AdJXN00hoeO" ..
	"kOkSSkQeKAJ0c9gZlWti9Z3Klr/Tr2u4wPdH+UpqL5y6PJXhZCkKNER1/Emkt0VjGpr4Hn0yyRCMmFOzmGIbFeU6NJYjV9jGbqdb" ..
	"LSUVZIsDGwgiotekT5ns3rszfuwFsFTj+9/IQCCIpRcotxiLdgVKbtAl96Xj7L+ZjBNtQWLR+jGbyGmWB+nYTLgT3sd2kDOnQaCz" ..
	"6Qsf1HG1TVonRIBrUkJg1dkS5pabbwEhxFZ8ptAmgh/nUN1REhxnahhHtxN/SzmvuQAqvz3QIzzxGkRapzUIIWHaXkgzcbcSt++K" ..
	"rW2RHjoa06fl++qEipkjT02wDCBz57ZFY0QD+b375kvKM2OnDSstUzCRjF9PHyqvkuyi8JVZRBLV4WPpxQNGtPMhfh6WBaXnfDJC" ..
	"cQmSVSJ/5bVJ01EoJX8odd23wPi4g9EBiOibtlQt6ZrrnaPcJxq8V8Vkv+FEZW6tJ4ycFW+144AhRRJFtRJxEiZ2i1LM+zvUmXsD" ..
	"onfv1zlA10NwZQC8FK9ATqGa5kvRZnLlm1jFT3+TUNDZpg5jIdX7eWGKTrUhPSooJLtxvGBLEsCsQVwvhmkMaKEncHbiqYFfwim5" ..
	"V6bH0vQ6KYpYgRHgt43QVkU3t7N5GIFeVjH0hSYWRcx+6nWpsOya9nFark+2MxyyJdvK0N1ZWIwYdTgvpwzj82nfajAo7vpTTgrt" ..
	"v2Fuc52LtfX2LyS0ppcS3F39Rlw2YCLZ2m3XqYCeG6pSK3szF/2IZMoyTOg4z3T2HgiijwqlkPwkIr9k8dV68lQi1OjEl/IOfEuI" ..
	"vPTvENgJvSuYtHDGVeTn6Fhr2pSVUdDMzXWREfgESROP2qoxsRAyk1mbs59b5os4LeNjZvdLi7TnXE4Rnb8TZIu8WAg0PcWKSaYX" ..
	"QLjFhCUyf45Pr4ldIr0um+vPpwgYwfEOd1hL0KDu/i/7IYcduN3y99mMEP8IszTETFS2h69hQ+FB1GroZsLOD8+qBnJDfRYzm5Gb" ..
	"f3sk87atCDFoE4mOB1c/jtRGcsL+w3Ftzu3VNYXD85hQEpQZWphnDlRV8gzK97VzMWEhqZyxG1qzxGJdF9gxQ3AFUjBYToZEhV2V" ..
	"j7Ahwouqm0U0b4Fn1/B5nsgAMlcBDmodriruF+7XntD4mfZOxlQF00aNDrvu3a+DaeyPodu8j5yCXHS8qfSFJp31B53l6E005eyR" ..
	"h5nQajDIMpSuZeS2VOL3AxsA9VQ5ojhFr8ud4b6P2k9GEIhAIj+yLWXRum9bPoI6S3CR8RJi4xB97xVaWgPqsad7ue7/bz5ksfnf" ..
	"DnEopp/QoTq5dwM0CKp+PUFdgi16VAOjHVrraQ8UDsgj2SvESNK4Ns2HuX8muyMKb033d07hoHf6OYQZ4sxzjz65mEpnNDpK7lnm" ..
	"NRtb7/R2jrNHBtrkntLFADE/2qOxm1pkfYK7i3/vMBljQgeh0ET8Jd8siopD9R0670S5+mHSCPFhqKmgFEmS9lONQw4UoiAy+5fg" ..
	"4IxwjtkQZ0G7WTUmkDX6xvDkBxeLNUVNy1ecMzaPWV+PO3itPn61zL83kMQE9dnHcPnv8JGrKwosCVNTAVck8/rkbqP2Qh2kg2Dq" ..
	"ruK4cVA42UGcPW97wwLOY+cafQuj6R+xSSliblj9VobtVlMPE/byTgQqtUftWySygJ6ncTPjn82Or/Af+MzeyRsUoYD9QSvahTB+" ..
	"hZGjFh1Bm+sSZhTN4H9oc4G9bsyxUKMjMP3f4f4nhmi4e7cltHB7s1cSMGLsmSgTIYlIOSZ9LFYNxEM9XB01I0zRaU7koVn4EU2x" ..
	"PDt97U9BgQWLGfV8RZ8xwFI/NmEPMZsUQS/z1zSlZ8NpmorDkRLUYgmQejIfoy21cnDGIDvxaHhzZ7P6T1+E8OlRwtQ8ugvzRaTp" ..
	"ZETQ50/8JxyneKa1Y/4VBD4Q9YG2YKw1BlL5BJ4TR+VaBnCHt1UU+8wxFGr9g8uypMXCNUoqFe4gdhBecqCl8DKCIXNrxhPc5bel" ..
	"byFqdJJTfgt0ttNnXZ5AmUT1ZK5vSAuvS5Uq95fjDH19xtW2MsFHFRsGHkPNWQLsr60DKxoXFEp7s8ypYxoO6wTYgfDb8/lXYq1G" ..
	"b/42AONXUFoAGIlHOQBrlyreZRmkmwv5URJBnblY7yw4ZmUBD09leLbGtQBwUTnUCx/+Rau8Bwp5bL5gi7Z9mAD2rzF7jTb75YTZ" ..
	"HXbwIbTA8L8Ym8EqQ8HQM9P0eMJnd9X6+CfdY9Tk+tSXb2Bz9Qycub9XXEXXlBnw9tHH1y804lZMhmm4odDh31F9pQ9BUXjQ9WMM" ..
	"TTkscjpqrLAOczfuMSCIxo/5zyJ4GOc0zKONpRVT3XnEmzUkdj011zgC91Jw3oi83bNc+H1dlG8htJPkWg3Kt6OXACH7p2K3DXTz" ..
	"X1spAu8wIUEM99dLmnMBiIqnuwi2ZQK2kh85KobVHraryAjsvfqtjgqYTho4FDTjnvB9XsDsc0CnWRsvpacw9H7mUht5ZDj+bEOm" ..
	"MyI5Sc6Puua+CCcRLOqcQIc7yzKU6Ot8fSMX2C3gTR6+4rxBaTerfudzvwU3lmXmSZgnoLXmr4E1GiqJjX5t58SQQ5Q+fwXda0P9" ..
	"uMVKzf9AuukcjvF3679XYjV5psDfscmGXbCUWc0oGtCKDJht+i3Zk/jExz8F0gcv4ZXkavTZXCmQoYyEJnI9vZRZKnyQaOUW58dX" ..
	"WURFmjU9YjIpwXdLAecb11GaSKF3nOd3+AEfb8ZRm4/cHF9N/tnNjbD6uad+puEKiUpc8+ECQM4A4RlVlS5zf0qFK5dE0i/2jPaO" ..
	"Q59VAQCAqAWQfcgYMazNcNygC4WkCWfyQ48FsISLtt771l7ark7xgn/el20QDrMkof3VrBMAIXEkilqxp+CJQvxB5zLF7PPXPhYA" ..
	"ZqRNjIkQDONogrh0lyqyArjTLD0Y/+Rsjum/W7CO6ahbPVepZ6bKQcEUWIBxHpTfs1drgS7mRb5hpgG6MtZyM78OM4N+VxlST3C3" ..
	"Ei2TqL26wqJRfHXiNAwb/x4xw6Tmhe7KGyC2AE+Wwy7qIOhpYcpBMmVDeyhYlnA9VPrGVoRmiVud9lV8giDiN0pRFmUvzRBYikKX" ..
	"TH56UJebOwGB73xBvlI6GaltFq4zjy6P22HwP7OTSPSAQgWFu/XnwMsPjXkqamV+2lnZmf2e3sgjSlyKQ+CSiVVIkXz42/nUjOL3" ..
	"cxRRh4WQDXKiVcUf38M4CZ8P9zUmaRRuAG77DsymaVW/nn7EXxdjUiNNZFsKE6RFj7sjaOLS5X3MkCvwFY4PVvzdkA4hwMNRevLt" ..
	"g/q8VxsZhX7HQtTOdEtWpF08vg4YZrgq/8f4MGNs6uUg6UfHo8XKUSaOvoXWKuUIVgfJ5696gSkjblQgdD2eAm1FXGj0YPDiFIGY" ..
	"x7q8O1emfSlXeyUm9VnJbRhGOkIaRnYME35Ha2ZJxFMjXJp6fonEcNiv1ffH/lx4kT+jhRQ1ilOjanPW5Hl4zG6ietxuuBnsKhRv" ..
	"9A8oR41Je5kPAhlQsUBhNh7Tiwk8w5/7ms5qwgUPqZ3yba2f8vfETdqRhmztlGosBEZCl7QTNJ2R+DCLFwJiHvEqdNaMJqr32vpn" ..
	"865zQEboNbf3RjtrLaO5/CNpwjELAgUHOvOYs5EX2u0GtioGnHkOHAdb951IXicOg44Se8kQoWRmBGvXp6dPSjqDwrqA0VMYj8/+" ..
	"xqeVfo+Uz6oy8Fd5zWw3gpSXPOKPuTj6yOP5YYp/Kndks4W9UrP9vv5Ih8tgTWImaOtzlAtuP3I8LVA4W3KrKLgpsxIbruGTYfbC" ..
	"IXVXU6PulGvs/KU4iMSIqDYORWfSJav5dF3SHVQjyVTyeRucnk4BhKbCQn8Beca7KfM5gFVh9Sy/67E4il1mHnEYPbSOSwEAmZwR" ..
	"Z6vupUlvLd7NS0fFhjvRzKaGfI+4B/cNXPtVl3R7ukXOjUu6kR/7hzOYwkC6FI57pdPcCoRetKDJx745QqmRu6C2/PHvliauI5S/" ..
	"Toeq+A48eBDgy7vtWlhZDL8AR5YChDET2OD9MPFDiWyQZP0xwpJpfC2Xq6SEND0oPrddw4ahqmmOiuzTpkVz629iWeFdsRBGr5rn" ..
	"7TTrKamkTpYM+GmixLAkHBTFlSPNUUkIHRxA0VtTFT6vMf99Qdv6mSy5hSwNI7VFXsg/URHGRNFbAuAW+LkhyEDkWGOVL3gIO8Qc" ..
	"gNnFezqiyTX6yJbE6op2xV+gwiYU4nwgXZmIXLNYQ7iUz/St8kkJl6f50zamGft1UoQVykN4ezlW6UXbFFPYNNfg99Roaj5saa4m" ..
	"BsvbqrS8w4exZ5n28c/FwwrMfdtFZO2I3Tertx3Ncibx4U6Gux6Cws5B+9XwtwlDloNkm83Y6La+Zk3KdE92xi5WLJEcAxYrqeKc" ..
	"IUI3d1NPbsI184Ojyrw3joRvYxfW0BlEXWaTa8K1XlcLXzB+/L70EpHKVfk4VqZwhyrp/PKVBTmX24Fnphty55DtPJNcZE5gzu94" ..
	"wnj829qMDLC3+3itGNVUkXw5ErEhkYVwDrqsJ9VsPBit9310H1Nb0bIX9IhBdpAUrkOBfNIsVGI9IZFFxFTD+QRTWCQvWXsgZjCN" ..
	"NCiOeI79ZtzYAR3LruOeiDyA0XPonVFLcSki38Nl8gYRj2KIVSCXitjaqo4otLjVk+NyiXDOV/VUHL55I5exM6z3nKbZ1+fJagea" ..
	"aAh0i7+G6ffD/qtJe/Qrs228c0/UuOJ7Ah0BHSMu/hYJT9JHusECBIb5Y4ZnZDr6lzF8O5LOThaTtAck9IAbChZBIwVy0amXVriM" ..
	"312j3ViWL1qBE5tDVfl7Qcvq+mjimOZe/9vIP6RN/jG3btjHjD6RfjvXJLboJpX/vqhBmVQI3KMR9k0j+QH1VblqgDSxWb9bIeKb" ..
	"WYUfrqlIc/M07ZKhVamimHGa3c/uKRNHwKwnP2B4EN+E9iELuXxkauJw4Cs6ib6JWB6xnFvNXdJgI6shb8b0Pxh2Jv+idGuG7yg5" ..
	"x9fDYmTdQg9u3FwWkJf2F2H+zlRlod++8PzR23yIWJRccZFQxdnH+ySO2q3k0ajXR1C9C46hZRZsyvcCgIl9MtE93FT1l7YB1SFz" ..
	""
local PAYLOAD_P8 =
	"zTq8NoBfMGVygJ9hwYFuBORuvV3mF84EDwz3g2f+Dvv9nMQT78fyVZke6Eg3xFGedBveEgOnc3/N5Ta9VuGXW8iY2QBX2b6bCFm5" ..
	"7sOvMKJdZBY/IxxnsMqX/66rYfM5cB9iAsCRrcCEJPkUs+yj+IdgGtecp/+22Ii60zjMs9Voxz5zPF1mUxRFBuG0nEku9nVv6Tnj" ..
	"ZeaJSALd/PUWybolLIRHBkky+voMxtV+UpfZt22jkxkUXZeqQEet0Pc7dEsgcTvrIyCBLsNXUA5fjuHFqiSBrQcuLzp9/9t0C8Z4" ..
	"WXXS7Rhf4U3Ur1IsK5BqFNw+33z+3J4SBZiXcqUZa+SLtGILgjej8Ik/aA4lPP5GKrVgr9GOE/im8EG4puJXWJ2MTMRLGPlCf6xX" ..
	"Qcb7Ql783kG4+t8ybWWx5SJxP6jG+LDWJV9NNYXcoafOlf78mzTw124/Z0INKxue1PhBzlME6x09vtccwyiYQYEyhbdiUCoYjUCK" ..
	"e8oxULsIj0SJMiAWBvmJE93/Le35Ss0kair+623o5WaLgQizZrBTk/gZ019kkBDRK7gk3p5hrpKiIiO2hz5iTLveTilkWOa+oeDi" ..
	"XOe6tFhIOuFFjjbqjtBTElXcMc5TSS/l8Ah08bg6IQTBoiUXYZr/JiA/7FHDAXGu+2bVFnRrQ+qoMcdnmqDYBGVfFohAHtr4atU5" ..
	"3xzYw3Qhq6J3KqIGtc/csjEazd437vOcE76ktA0gl2GeO3A/K5hLbHaxRMoPhWnaQUKZ7tgBaILxcV3RMlKMIm146kq1G1Ve15rp" ..
	"PisUJP7iXAgA/mcaOgqVpxaNyXCEM2k2MKJKEWLJVilzuIA+k0gO/EcNUfF0lFgH4Q7osX8lYnYNu1DuhML8hvMrmpKXj2xKN/od" ..
	"TYU3uCsyljYVJ+ztCYUt9P7x3RFy6VmduQqpIGveaJtmpnBKXagHJRxpvTPiXuQlkDe/TsIBOjTIJ6Q710H0NuoXjWyPlKbazAcZ" ..
	"zqGGoGbWgAFZpEOpo6kiQoe8YONaGA1HCM5nAKJ8ddJmgez4srT9g03BmUlhaTJo5HBQr03pDORTLRDMAe0QxieodNZUmtR4ZAXR" ..
	"Xchsb/iuj0wO8eIqe7evnlZFUD4LBUHSbxcKJgZ+Xm46gfwzoDtAYe8wVgctPyBpuDz09+x8GuULDi7gEPZ0Y08JtMwLPGCCC3kP" ..
	"NfjAXFAiiwi1muOUi/5pipixG+1JQKmUBEEsnEY8LOupVWak5DG/cZV8kygwIC8bl6z5cc8MmlGbfZ9Quf10F5LMOkj3by+HXP2e" ..
	"mrIWfZ2vT2oY7ROO//PIJX4IBXfCs6HaDaiZkbzZB4SYQJ4kVA+V10QxpA2ktA8He0gXuXa28WHJoXUEI9ghjELiWHT6BL8tpGp6" ..
	"n6KPgrO99n0Ggi24/gKXGaJWBHO+6MHbm8pS5uip0Q8mk+5cNzFnl63O7UxfNelBXksxUyTiHOJFLrueQl02J/1zI9ylsQFO0lJL" ..
	"FEc8PTv9a52wbJiMfhSudOgyvWKKIpuPLSZamIGVnk7fX3NDRUmt679KGBijlwf6qYjVerizXhSsRt7fl8MqBYNJiBVKoRctDrLp" ..
	"B4Kh7DrjzqmfEwgIFpO7QyC9gIiNV28Qm3OeBuSusgnkBkaAsyGsUzfQ+QfLdwFF8zk/DvWrA0k0s89TLgqeNI+h1Mndg4uDNjjY" ..
	"uLDmdSNnjTNbLqH3X32nDWuMah2jKo/51UYhMxYo9l/CYnOIVjcMSnvc7e4d7NkyrUutUIZmc+RGCQaNuMhU9fxoRrteRP1n+D4b" ..
	"LeisZqTXgtnYoSWJDMk5QZuncZYczGkbt7Q9HVrgRmHvur5HeZ06cB37+P9DikY85Wk70UfOXzE6/LF18bvxGgyYxSjBU5z951MQ" ..
	"h13/4gq3UDdFqk4j/j6zqda0iwb03zZ7TN75dZ4Ln7cxUyIQv9qyzFWHkBv2S/GxYROFd1XEOhKhDoMEi5NrGlywMmNNaEeETaVh" ..
	"vXjealwpLCCUnhJ42hlhNYDboncBESajuyKkquwtJ1IYhPSzsTNoXfEMEpNPnArzkQYstEXu1z5dYws3MQj8fOt8142L1lwHP122" ..
	"hJZIyeDUiz4Tsaj8hxHXY2dc2rV5YxhavbYssClUFCvRDV7ppLCScSPJPq7tEOlthwQB91/pplkiedT++gqMiMlVzTB4me6GchSk" ..
	"4B0f316+hFoo6FmykbQdfilvrHpzweq7q2zVMnOQtn6W1U0yc3RMhTfy5OobsjQvhsn6XA30q1d5MMGX2tQwOfGDiPuWqMRbagn3" ..
	"N4iwLruDKEZbSTW6G9EWLWbZ/Rt/qIuKX8/bCddPKU5M0e1na8T6cHi48XClq/cG3FY/XJte0sdWjHI47cosPA+JDjY2rOGsSSOA" ..
	"fodYKFfymzs7xYSdOI8YqyiYrjLN0vqaexRI9132W5TrmCvlh8XIkrEfnI1cB4/TxSsimR1e+hhNRo8QQJg4rQnadnAxCMIIxf2O" ..
	"xqv4Jk527GEBKjWnlqqVscmoUp5k3gEIYJmTx6g4lMGo1iPL1HYHJRn1oedXR3U9dbHlOPx9jM9t0uq0zEmsNM1VI7m4Xdzn5UrS" ..
	"nyYlYT//vf1gr91aqMxHz38VA35eJxdu+6rcx6zDqksBWPuDUe6y+jzvR4jrqE1p9uYuB3x7nmoKSW/yx9YxEu67k6RpoZcL7lwi" ..
	"08LYarwcTBxnUyW2jOTh4NJqD7KDz72n4I/mK0B4WPQiy3FlBIsG9Opuzrjeg650cjcRIdwM/TXZrDquw6vPZzm4SW20tujh74TX" ..
	"EPIK2a9dx9d0kjUfllZy9kQR/fgT1mYDR1HbbZ+aI+wobTmNRW2ow+qGv6dDTs27Ig14SlJIVe2nT3Zh4NlCTQTkGkFb95sADpHi" ..
	"o6gZHWnJgQuu9+CVF3WN/YW6kEjeYl6L8jg3pZb11dKckAaexNTpxO3JezwaCSSaulU/9r8/rlvFUkmEh+sTX+x/NfsL2xrvLeWp" ..
	"ZbTjvfI0Oh/BKoXAhnUWGnUHxdvSghEbq7TSx2KGRAJZtWlfLsoTVb7kjc5rbKVejgVe5JGXOBhLAtI5X8UB5aVCui0Y4aP13D7K" ..
	"6IzI+b49tPeFp2MxBHyMPNSHqH7MB0RQNrJYM7Wfkaea79rJ7beANEL+UlwkVNLfsXDxzv2q9NNvV+gna48eX0fJ4pRn5y5i2yBo" ..
	"l9JgwSBscOWDTQyYHsga46WxVgxCScL6hHj/YUVwTDJkQCmuxeesm/toU7tjP0Js/UkeHKt3KRK8h7QOfNWZNQH9Oqc96GwZHWaS" ..
	"MD5zGcEQxw+nj88x9Vc3rY9IYV9wqE/62A6OMeFOXbRLQQ+7iObO/wxmvelUZCO2gbYS7epbm/yDYCg7gytcY5GUvTItlvH/TXe9" ..
	"qFwZArviVliF0Yl8Oi1WinzJAW58REEuJ8mkjZYKpVBZCAtU2PNidk1Z4LOLyMKfeySEcywCyimBBj7WgehiYNMWahYE0k2shjyx" ..
	"DbCYMxQyB2dsagwSJrfkF0Y6FOTt0BezRk2c9gUaUt9jDcHdHJr1QiHVhpcY+EeWA6InctQGzwfnhlfAl4PI7M0AlQjxJV5+R7sX" ..
	"uf5GNN0U5SlFC35g2ZndmZGm37FeZ5t+snmTiuO3vnC2WSuWLbgpw6EjlxjlnaQ/4YuJjF9FIh5wGtErg7kUHOruJQxXXj/uGj/r" ..
	"xAvi8Ldq71dKhRZFHYTqe4C3/DwUhd9RQezagShEmXTNeQEew91kv4QuzjNGTntGI+vEg1khyHeUo36BxUx4Ok4lwXq1RXlU7Cty" ..
	"dGR21V6ENCkxNN0moL93KVUILRT3HKdhvnaG8/qwKPG+XRyzQ4tegt0Ov6HClvcZPqczacA5eirsgSjFeTqN9qFq5bq6iSDWSEFx" ..
	"Qb5piPvPlKnXVJwZMpVNTgEKFPYNxpZJwOP14nyccZw5ciQXNjpnjseEJAyBuVvIzAndL8DJ7Xr7NQg2wLNNA7XnwOLPhaWuRVEG" ..
	"Iwxrt+znBeuxhafIY0KxP4Z/qRlsQtQDhmgOJijFOIia/wmC/ODwQRdNiWz/Xy01nGVBNkI5r1KGq8eOzdj9tzx6LG7C73D0E0C/" ..
	"DQbq9iLIecTdfcqDzJ9N0AQ+Rq+DcsXi0bP+XEGlFH7aKslS+N7TnB52EeBFjuZRPKY1w66dYa5jOpvxoj/TFGOUL3tlQ5+PKUEH" ..
	"4AbIBvQH0ozIAimNqaKTDGmoakszPjrce8F9EmfgS0gWK45Q6edPQ6hDRBl3vpWiP1ra/w8SfSgZltklr6koljgT+E2LRPfWsETO" ..
	"uNYmAgrujtzNFT8AEUkh4Nv+piBkCUuQEDXzahztxshJNvcEPnT79ZO7r6FIfRCw6ooMii4oDFZWBvgnFh4RDdNZISMyXTcMzQYj" ..
	"kB/5YLDEkMoTUw1E5V1sYu2lXTj8ZIvxtoVz3iT6ym9nQzgo+TOzZwHCF/1Q040CimFs31v4AMYqXgpSW7aRBf/XtNjefqqot3gl" ..
	"C49jvUV8WyvWFbXYPZGXi0xfyJuOrZ3O8Cd9Ey9gXiwGO+P5PNyZBUoEg0wOFIKQboTUFaoF/3zk1IThbGqnhSbOO3uq3oihYCZH" ..
	"H3S8I/vDIidFs8HeGDMmuUNMi2hjpnox1FECnTHR/H/oOG38huDraabDKtx9obS36iE44fJXmfSYLdB3FQ6TJC9fOBYxfFFrMnFv" ..
	"BhvyzkBjukP8hJKYH77/yMIPWHpS9nPu5QfNNZWQzgvS6o+7miY545peN0jGrOhOCg4z+xZkri40WDABgfKarJ/VTBUrq73YCBhJ" ..
	"2Bzxm3AWnJxcWRB602Zjv2dHUZdWmYygnpuf5aQla8buuspRTBvGGWl6JtyRaHge90G4EY2ZM/vHxW4mZ96zM4PuR1r4kfx9lMjf" ..
	"RqvG/KwEo6twcpuOhDA/pnVh9fcFYXOwpdzPTECJ0I0YYWzd3GiVNFSbxDsC6Vhf33vfMbs5G4V4UmeCyI3SiHYB7MWRNiMgRayO" ..
	"gPxPnJAatwbgn3VCYJBoB8Xo0hWoWRHqADKX+4vIRq95PYlFCU8AufWsnLdWhypwpWIlFsweW4Qkh8j1B+vj853epj61/QEG6jgz" ..
	"JP9FO8fvfDQQZDec6Kq/hb8bpCgGm8G05p7muZcHvJ5xVZ3FUbN8CHvcQCKlXbZM1DMdnZ4SQ9N+3XG95asIaxATnvtVlTA0UfhT" ..
	"O83LxP37Tp68058SOwBpXv7VfBiy2M0RHpg1VQ4t2r0oiTcwPkZX9LxDK4kHokQ7x6hNIlJ6XcEBPvyUUw8PPm84+HYnY1pfUZGo" ..
	"Y/IeekywoayAiA/GJqsHSZYF77CTp21HcTiNHHLEw3HyiQ4T0NrrG8LU43vwR15woIZYU5D4hRumdRnmIpRzkOfI6qmOGAFVEocz" ..
	"NrWRaXYlEvyedWw94ry7O1WpG4wWPEp/jkJKid8iTvjuE/RzWMhUNmfcUnj2CbEO7/iDjC5SBp5qqo3mp1grVC+dv7BxIF9dLByY" ..
	"fO2vb97/xh790/garGWIxdmmjWbF252NM1rxNqKZb1xhAX8hNHynqTefJrfTcLu8TQCw5Tow1UrRLhM1JqPHgAOA35pK4gPigUD/" ..
	"VF9KV7zPLyx9b7l1HIL8jjOFdFRbXDN2qzJx1+cK5gUMbv8jpz3MKX3uR6zuUPA6iyiP6VwSUc1x3H9UraXrc0K9yo9p4PTofjlG" ..
	"8Qgv4a646DbpaVn9jlDaM6rU1v6+6rjuSpeFUKz1pa5nnlQpCyuglBMCyyxHo0qhySQ33JGRLlJMtb6nxFFJdyJVIZzUVXmjqiMt" ..
	"1UXYNMAd+ZlU7Yf05Xr0fmJbQ+DCF34/PE0fsFXluW+TFJhZcsGsFvUC3dHxlsE8jXdc/2CTBBJRryY8qCygQLlRGW//+HGeBRt2" ..
	"2kCMqD7k3jwJd3GR5US7MgqeBTz6zI7qx/8bUgRPfGAFgdFS+lTUNNYPRReW3abCmdYcWVA5pATxc4eQUlVmvlkg3nY6DwoVOAJ2" ..
	""
local PAYLOAD_P9 =
	"qU+297woCHTwAM/P3r6gpwas/ewqfjdwG9oqV+qx8nAdLqFIKnq7kQiLRxVzwVF3jY3gVoJg4JGAR12c7dA17LizI9zCLt/IOvEF" ..
	"JyWuGn0blJ2gegYkoWDEJdKPvgnmTFe340jyd8NHTgboXgwl14Fy2yC3g6gvB83L+npkLcA+oTTtf1UFzxIiUOptBiYMTtLx1QID" ..
	"FN+6Jd1cdkFxVeMFSpBwkYqU3iYtF8l06f4XpcfINwynTgd1tu0VjEch0o93vJzRkXu1isNskpD/aZH2HmT7hV0GP/cN7yvH+7ej" ..
	"4PUnmFFAjQ4y0bxB+8bVkpn4yWxhpRJFPqY5XKmNngJtQeN5yAz19qk1bWpnLwqKS1NbgP5NimcB0/O3ZtYcxg/VWIcFUzwsW++X" ..
	"4iPj2tUqynJhMYofcoY99dCSj8Ahlpq5wh47FVwgU8frCm2Hge2+Se+KQhaExsoJSN3qSUy010n8sfiQUmLZsuP6dy3NEafL4jDC" ..
	"NNvBcVpSd0AEWVQVyG7S2SsiauaaeLsMbLXkuzB4gDFep0HxtywFYeVEcVGYvTvZeco/sjjC6E9vZD1b1UTeKwum78S+ObFkB4WW" ..
	"0lqmMIMRq2M6M6cbbLkrgCCjl7xovyRH7beHv9k0tb+kql4+aGua66nIVZt8YG59M9ze3IaVTKfj6a2plx7SYnxr/ZR/3Gfsmyli" ..
	"wsaoi+CmCEKQjFmHozFIGExOFd7xSRpqm3TPUnBr9B0hspyenil0VW1aiWA4eAwi9i8lBh51S8UbGDI2wn7JkwWL6yjrtK5kTvLi" ..
	"6P6s0weZISsoI8/ylAXZildjjbyVS45O5azBcGUQ/A5DvOkUb6lNLDur86+NzBKbH4kAhZnG1eUleicvsRckpV/AV4g3EOpEKk8B" ..
	"/BJQXU1qz+1L9NVz898jbofq0yoThFvD1W9pHSCzNll6xyrYPHDAt4uOImjCYGvfkVtGI11U+xAA9cmGfmI8NYK0pDNKqg9O6lei" ..
	"4fb6+wM8XiTvdMLCcrZa9FgJ29POXMg/XWXiRMelcDyX720t2oPUBIr9WFvWUtvcE7Nxi4UqdMUMla9V0xLjPkRM0/Yd+qrLwHgl" ..
	"fttFdEDRnV8OOskA5R2jFnpSJH0qwtVSraQUI84JIfgsHfmsA97ISw5KNoVfgCQZQ0mZCEtoFJpIG6Xb/YMmnQJSr7CO3x/MgQ6D" ..
	"t5/YP2daCGpxw6JpyltFfP99tdCVW1i83QDqca3nPvvAYMMrICEbOiWD6Ssyres/xI6b3vcRZc5OqfuymLGGSPyNSJgYD9BbLlEB" ..
	"L87WTN+FIgu/+ybpr7HRXQ8fXlFkh3qVaDEckP6R5R3lItZVbXpYal4+G6cedQztEoFOXEr6Sjd2Mo88qjGU1jdhSRzPJ5/VqASx" ..
	"PzPbaCOvhMOEQeRYOybI3zevTBDeoSk/m9PBbzlzmfhschW1oOLmsM81tFTvRWYS5TYbXmf6JRuwn+D6a3z6cAWt2kgHbYdMN1/H" ..
	"o6tHExjrzY1zeEHsVwmTITZ9dPbE3F8YNCMg3fxAWxZnxNYZN4Ip3+x6YQndoIEsUONzv1hyTABtdLMHuRODCZFOGt81FeAq2ySU" ..
	"AfukgwCSc8yq+qBfn8nF1mAsh3HUT2L0wLibsbLoJrq8uxPc1nFf6f2sXm8cI0MjrwddlXpOS8cGQmbm2KkJkA3cpifd0pkhFE5Y" ..
	"I3B1FT4yUkSToj6qp0AGUNP2NbLoMhefulT/BsMiFqglopZNyWWvHJnFrDUxwgVJw7JN2FbeF9ZU7lJMF6q4ILvKk1zVgVo4vUEy" ..
	"0ZYXjZffZA6sTjQ/vwxMPHtSFBDnZn0afYG3tdLpcdIzXAOLMwy5LEY8iRTFzvot8j+YhPN7vWU0Kdw/kOfQk5sHG/XDzSfZ3PLT" ..
	"34CN1/j9RXcbOJI+GNUTc0o/wrlzw4xhxagGMv+R4q55Lz/Z0975Nm7bZa+ZTDIMjKxIF4UA0WkwZkM6tt/0hmzUi1AAbLbYKm+Y" ..
	"v892NhIFIc+EgWBk+N5MXdIhjt8qThjDlNOgF7bfJDcRyh/9FuqG0kLId2DFX8o53KiFmLPP3cZAB5eAyToylppWPSm/KCPY3KOj" ..
	"fHDpz+q6ShEzqDWsDMJPqtqmEy6wfhoSQDFgXXBnSjl8vF2JT9NUZt1t5ObIntPkXvseMGpzYLfpeIbifa86Sl05rBYTtDvRD84J" ..
	"OMC86Z5RUI/4yg1AJoly53GkhMDM77ycMOQvKv32gk/zwaL5hQQuSRqmmp29dL76wnGJ1g818ini51qoubzYXwXMIOdgO6zC74vK" ..
	"xvLBqiU6BQyGrgcrGpASjfmBPKREOfpA2l1cY3qjVGyOzF+TTK86IFIQO7HFlg5b913p6tK7ms2fnOZ7Jga0GpWCmFUe4efIeNyN" ..
	"d6nn31qJIZD80Abh1bPUCMAF5qb7+B1quFhnxdIFsKwR0eX9pTjaiksilIjSTszfttFU4MBgN0Z6waFXX3EDI2vSVy07RHMImr7U" ..
	"8YFTkxfQHaSaHz7ueelQaE+98HYV7N9OcT6nM1JGGKM+8qGGMlcRs3QRyi6HkyhywsZtkVYYZXemJHbF/xQqwxL2rIzrcb4wwb/C" ..
	"+PXHeCvQjyMHExImixedIiwH0+6LtTsLitkGhuQgOIto/UaOZjawwpbo6gFCynF6eqe14xA+F1uARiP4C2q5DfjLk6mgEuVy66KI" ..
	"5o2NbsX4Cll+ijavsed7P4p/AC4m2R2RpRqK/6Ygi2Cp+pvxrfsqiWHKx4aC1UwTsPocLjFe4LnhKIkTNYn8euuRKfkwPHx4kUPe" ..
	"bkC/iFzPylcuflH/x7lQSMX9/ibJ9nOVrdopgx4ItIbCS/kLEyVlDmCNebjXQ+35vow9c9ddysmNQGEYL2HXgWFMrsiaCqvvN4wd" ..
	"l/svfSOBjv9xdgkPhI22F19Ng6lUDKym57NJj1h4I/TOou2SgZMfQZ88hvllCtEnPa8EpnmM/zQBtuXjWnrcbe2fmRG9G3r3ZkhY" ..
	"6ZCMBb8L6psimaNugmQUZ5jPWuNSjvMEph7d9HbKCiAXzSgQg1EJ//qAoUHum5usFTBuMG9s2iVG4Qg9OBa2+853jHSsuuk3VNcv" ..
	"K3ZMK/uyYmfkIAnbOsTR8kFlmKFw1WtO950pj5koIFu2TBuVtlKzRMi36z5b3VVW6kXHPRdkvrKdCbcVXkVHXQ06D3vraEixFfyo" ..
	"52Ap4mfkmQVjpBUST+Y/AsmuCSozb0B8D4w5y7VVJ5k0l2OWXSTRsnCrt0CAkGQs6gutxghiiQGeGE67R9xugkWWsVJpwk1u5fTo" ..
	"XgPKF1p0g7rk9FhY7regwPacnUM8hNJGeL/AXEgGU2deg1dd8yI05wrCfX5ZYG/nXwX7tDkPbL0wvngisOdvJ/j+i/HyD/9Fa0Vv" ..
	"G4eLIpPxqgzHttLbNu+LUdT+06upWIYOHEtUkGYohrK0PP60qVdhiunjJeJ4bGgXYXqKGUs21+k9KNSiRhepTBc/nSJls0MXBdgO" ..
	"aHfgUeR9bB+ykE6cSvjZxxB/hQ+vIIgfS/hEkzAlVxMbdM8Fwx2RV8F2j/XBaASZk7Ng6e7B285keDuMmi49hBbwE0cQ7vnYc21H" ..
	"lMJs2M3g0O9iIWoUiKH6VTHrCVduj6E0wVl0f7ffjBTgKdIw9CxxQvssd+iAI4rNUATLTdoj7OJC119MsTDsGeJsEZ6WEb2rIY/M" ..
	"Py1IbuitkRuKrese6K/afNvTofolPL1p4/yKLa9FEfhm7LF+e7Pto4O2pOfcgrqo0Q8Z0/WAk6bGeDQVwiEoMvGv6fz1HbWG2Iir" ..
	"IGziACJja+VjizL4ZfmemcZ832MMxAhucOaoDshgbeCT6Ab9BSw5jnGASit+v2eimgbdDF5JLTJAQF+/eVGCPHD6roMyD1M6obSK" ..
	"wAyi0rKQbiOefFdpPAMB6gvj3Y+9FfTaEdILdAKVM81V3acFJz0LYnEbZ5da82oLvR8sJeJ4nsKKz2mxSs1oE8orDVq4Ls5UkxnM" ..
	"qtNuJG5awCCoPeSFEuuxGRWiMs4Mi/SdfHlchKjPrqXXeo3G2/PG5DtFbMFN4YV/CGtDsI7PzypqlorYdCao4gFgEAwpe1tNpQim" ..
	"JpXHFb2dJx+oHaf+jmTES6D1TskEGvAlDYxXXpQSZ2ozz6zw3VR3LBTX5FQ/p+pLpifBS9hcjhooqjuic0s47hoHRv5xdqSXOfXE" ..
	"gvcvAbvAwuDB2kY3xltv8VvCOp58yZRqyDqmbRUfzNftcbgVi4kIpw/qI6VREJ6MIPn23su0ilWImSBZKvOKudWL4MeMJqbzo1k0" ..
	"WMpDnLMuiTJsk9zc/hNHNHiQv035iZ7fM8Fg2vBI/cVJGwhi+EHE+gZgVGM1Pe2MhANZKnH4i18FWxsSf2Kgd9WAYBSwlnNaAhqF" ..
	"RRQ0b0KBZYZ54TbrzqOAb6J0Dy+hyfFsh+Q47NCHWyH8srLo5tcl1TgglDuYm/PVBOQa3MfTr7vjgzungWN50ha776fSZosDTDK8" ..
	"E/gTEXB9U8rIPcVYhvanLZ7OtYoaTdNEYntKt+P7+UQ7zqk2nNBHGpu1zg5hb+Os2guQ+cIV3I9eFgxMr+8T8FJWyJ90JqSEZWpC" ..
	"G+jSGDyJk3ixWt5MOTm80efNS0ekKB9991WvbVEFUTOB7rMNouTPZMVGkSHLsJth2eGkl6hi2mE2oqExFc0iY3bX6fP0k3PqdFT7" ..
	"V4Yx4dZrtVg0ds65CZpEvn+ozl6+Y3ZLEfy9rRQhm4fq49JKpGBIf0CahS/37OktfjrOdWyZFnFFzFoGTO2MMdgZZHJsNbak/yI7" ..
	"ZRqermccP1hbC/pkIHODcA9vyJiUcQp5/+MS7FxBDVIuFsIb98lEtJDN8U1388m6UOBXnWYtSUmuwOWa+qV5XsRgP51UBc/2ELYc" ..
	"/s6y5NO6de30KiZryQrZ6yYTBusC3i/lfsvSty/L9nHQi7dj0OJdMtFc2rlBfzInNAyFkoUulO4xsjV/W+FHkBI3/AGFss1nx/KG" ..
	"9+kpk/wnHFEeLSQ1uOZofHQtXDoqz63xSB/XsAvQQojTP29wDJmltAWafA3n7mHvh1KCkErwugp0wcD33VzsAIj3qMaWoRE3WxsI" ..
	"VDPEwcw4EOS12SzW6wLhrburRi0zUCbszpxWJGThSiZK6MX2t+PHQ16ZUSPWgUQlWVlfAkkUVD5H75oLRusAGFr+KH1AunK7nc9/" ..
	"iQZTWgGGT9T+YevCyDEtRaDOAGGZfvKms5avxzHx3eLMwb9R4QeqvSxPBr4Rqu+dOF7AEkab95ua1wARlWNGeA5T+sBpS2zN+Lzu" ..
	"/F8m69IyzDGTmGH7tI3AbASo1lP8cGkVrDFz99l4OvX8PwvTQDPhhwRmZAXftQ22bel4vvnbRpLELrWwJoGCCFcKfBhEVE6+RVT8" ..
	"oQ1MrVGXFwPgdIzlRXok6LHGq8VOJkC0LsIOZrcnr5SNoxAf0Lngp5+c9YmpNNqItcC39q6Q7p4VEog1Y0uakmUXkE3oQcOcfiqz" ..
	"E1nM8q415hawwwaDptMbds8uH5InFD5T/Z05Zunx6veZCtcDwT8nzBbdSsjBwZdFaClXayJBa4LrZGCm9Q6Pzq+qsEd/CznrRmWq" ..
	"hzl56u0YYqNCd1XsS0ARTt9rNQr7fBuuGsLKF87PiNchhETVndgV/ZPAbFTIaLzQLkferEVXnjiBV5QFORqlPrt60wG/fCcmTkLL" ..
	"//mtrx9jM1TjerFkb1oqJfjRwaf7Cbl4fMOnTOSnbrfKdGXchc3VDdn4OwlXH4+BjDsIYl6aF7zRY8LUxuJeU2aPVsgwtG/hOoyq" ..
	"Mj+/QsGYuP6XDrw9SIQqVoYuGPyg0Jji4fLDE1Dw0Tpcm1+Z3RGbfg79i567reK0mOPNnUzSjZHSAQ2l6FbJISVuw7r1T+WVUWLq" ..
	"DaOGoI0JBJ0eaGGPbLE156whYoyYRdtxyVlDaFZqf9HvmA9B7dXvwKB0ESnCcnXGO4jyhrwKWraCSi438by/zsQDrzTKwCjy0+sV" ..
	""
local PAYLOAD_P10 =
	"kFlb1OK1pzW/9qI8dWOnIZL2oaJjSS2vpkZiBpWLAINUlBUwecCmsw5hS7ixT2+/lsRSMp2u6XADZKRy3LNFUVgT3hP8WGK0x99W" ..
	"fz/3/qgZ1/NOXWZ/q/tvR5nh9I15OofbTlP0EYwXURDj7m66Ux2JyFRps+r3zBqOnNvesSJoRKyh7WW4sS6FvLVPRHAjvw70/iGS" ..
	"563iD8o7fsH9fTJwSHxNk17h+SmHkmHdBiAgaAg7wfg6ZM4NLOHv5haUWTFiTdK/J2EIFSWfKn8FMuG0DM64vpyIf2nyuaJuWR8+" ..
	"wDLQmvSNay0scvcd3ahYAeNNDpGm7XJByN3ZO/SP5oRh7e7OtV4Q+QnKouzDkKsgBei2z/bb9PaG5uydqesJxP0qHAAWhWqLljZx" ..
	"i16XwH9iaCZSFiLcKkXOB/KNxyWAcXntmYeDDU2+zoX89isTEMOhH2dnV6GRc6mGJNFoFcBUkfgWmwyrPFAq4Axhstfxm1qz4Vh9" ..
	"76oOaIuQrAKA+Ag8LZDjuhuxuNDDJYOy/hyrNwJKCRzfJXfwxww9KWAwMDifSKLwuCHSN8gcQagQRlK87hazBPFP1cWyguyBJj9o" ..
	"ILn9tV5QqWg7SQxd7JeOwplPwx4dVfL7rZZ1mGCB4EwHjDRMXsGGFnuJG+Vk3AfKIokAWEF7Alqct16fzKF08ls+Z+2qMtvHwzhF" ..
	"AttAZMlStx8RpSrNLl+dWnmMP+5TSWQm+6GlyEKK3/aucdjUbFTIOQYy9UMMJxgw0KjePNetWStjP/aaFlNPxj+5iP/dSZcMz/9O" ..
	"ayJm0vUc2DC0qdJ/08ZPd3AWxm84HNTTqZuQZnuC8Z6/iO7jRdVnzD/tclJu/vqQfbjWl9x8k994L+nCWDDoKg3CK+Hl//KOAPy+" ..
	"U5ZWzYhIgyYasnx5ZaIkU1n0T1sRV+0FObA5p6/HGqXDTEkPJQCooQdRnl9HfEcWhBBqCeR/yFOAZ7Tal4pwgt3E3ejtYrPR2oHX" ..
	"SC2UGsjwjgiB1Uw1Kowhy2jHJvSJy7Yqy84OlX0fPbHYurMKmWy8ZMB61Zm+LZ72SilDyyUaRmw1bRTb859GYp1ER5mMvlRYvyGB" ..
	"QVBNlfWKceqkHoGZ7bfSln1SNYZuS4UUcc1OfkFhGy/N0RP4PAeXAV3a8cvi7kVMC+csM5sPEGHDrmDvfrm6lLWay1k5JgZVPqKU" ..
	"Hen+PhuNTEbeRALEuIATVN9i7Zb8KzSB9+el8rBxdtxwyjkDy117XkpulTb81MmWK383SLBskh/goxWtSqveb79mcZk5SzE64ma5" ..
	"au7RL/XZQhh7sGEtIt2HhxmYLxXCzpdn+KdlNuHeJ6QiCwGJzmgFwN7uduewpRD4jQgGzmFLnndDUCXEsf2P8b5rDX9cliTyFQeJ" ..
	"Thgc8yvvPxytyFEMUNC/GEhRTEUgBoJjzG8hkQTZtooR9dSXn/vMDPDQhS1n0loZsXlx0luckX6Xm5U3iHlHqSUQ56AikNdBR9zp" ..
	"IHWy2Rt64F49AnpaSuFM0dB1lP6NC1T3FLtpbqCOBVtBOM0/pFBOjzYbeyP0EXfehmafdq3sqfsF0K4hvKOu2NoX3W8yILQMs3Fr" ..
	"o0bbleAkopnv24F7L6YIq4XMHv+8A4wT9w+JMkXrfeJZkTP9o8MuTKmTaHJ9kmeOOwvovYA7KjIlmBC4vHTnwcejhjHRFQ5sWUAT" ..
	"KyT4VDJTOJIKJv3Ll+8QSyOn8mav8UcLiPT/1fZWp01zgN5sT+yFcdhjf7iJckOEyIRByAGqdYB8xbeIwmFCi5evKTtaXB5G8Mdy" ..
	"oZwplUJF0ujdxS3nf2gT9vsbw1HL8thmWfg4Bazt3WPrbz84f27BXNJjqq2Dd2eTYwKCbWXWhoWRm87YXDEGOeeZyyWzGtVyEzMu" ..
	"ZNmFEcCMfITNtyFfB+RX4LYGnI3lVQ1XeqxxqpfgkIKHpq2hjVQsQMy1Qe3p2yoTcdlPgEpsbhMv4ehy/Zlr9mZQ4CJnOdZXc1yp" ..
	"7Eu4HzvRrvXzWgtxPTVqqaOKLKAdYifHZzO87YJXnj20XD5CGA+ptgJfpckT9oXZbOsjQr2ufoVy4ymgrufMBP+8ux7WrPZA71Bb" ..
	"LH7QJQYsh01UPKvYUBlo1gv301ogx255FGkaJSt8OTaiE+MdlfaVU66d5F9gs/8pDGeoXBka+Msc+uB+DLQeE4Jm+fp/6qvHBBt6" ..
	"y2FyivIqqKtHQq6IBXJHribvIz4RmWHQe9GaDVODyMQceND2LQBvmpCRHFhh/MQkzXsNd/MWCV0E13MKCxVWK5nKLJFd2WxnwJVf" ..
	"nlmyi/Wd6ndZ1Zg5/S+oDFnCEhKep6boLHZWloE7AUPyeUI2/6IXHkNrmHNBapLRl4lTgGl/sQDbXadtyHmJlsnJP/z6fPav37mc" ..
	"SIDYJaTGuq+YRwRCHtRCIFkhsDeOkpA/VWh0KiKe6B5hSJdPlpP/AYGhde1pEpzLikcnxdgaAG9DYPv1HAKId3UMZTw8RJz/LZki" ..
	"tn3aKzw7YZzSuoAF2nLGS0Hkhh0+UdZI0OKVQCP1M0p14DMzQeCG3az2AZJKZhg+uxURPscPWJNZAfHoh/8IUygUlPEP+7j13eUm" ..
	"ahpxAZixmw/DWifUEL+N9LGm0ujs5ZVL6z8YaFVbXvMCyTYI1ZPj8ja6djgcwh28JMOEf5rzCLNVq+LBdF9mWJJjVxpu1x5xsWld" ..
	"mtzEgbc+lS2ecOOnAeRMNLh4zsNEQl9EsdMLi9QRvIRxl8SAwBlXJ27W1rmwRrYbSD4zHrN2D3vSgej/lhXXzv+S8Ng8M2Hzu0XM" ..
	"U+WIQTQlnw5Zeka8OrRUQt6NqfIVLjQ00iYsiDRlqxBtUqmHVo2zVnMlwpLP5D1364ItQHffi2oAQVHEzA3YQfyYEmmTUcUWbbSb" ..
	"eMV8R73+0E9B7QaQPbfkJ20385tnfeenHXY+laNQNdzNoDcwCVUov3KOwew645qfoLwPGr5aMvxl0JDeq0QPUP/U1iLDU5B7P2PN" ..
	"BS6kC99lN5oWUjSffPVU8ZFS0Sg7PXNc8fphHIErUBWk5efPmH5bOkWwoKohnEbL0v3GxQxeLPAGv0qVx4FyuFcdcuMFBLDORGCL" ..
	"esNiPxzfSsirbvIX4PAMZiU24taBGmctn825HZZqxpad4GtMSzONWrAbxKHtLmShDimPXIigmRG0dhISm7O76YQLeG5wpuwDeNtT" ..
	"9+NR6KHXnalGyP3HbJQ8x9cmCdq/T/CcvKCKLjHr7+MwbpqMtP+KeCVDMNF3gYTnrJ8jMNwW2J+bW8djNXQt+olc4j/JCi2DvzVN" ..
	"Z0N0Y6j5OQZffbfr6JGWcwtkVbHeHPkWxEl0geXrWG6VSk02IZDVQij1zUL2Dp3orQsuAQgh5982wuU7VzMrh5MsXZP0k8QugkqV" ..
	"tumPmVqZgyuIzVxyJFnxX4apJCsV5FUb0VYsgs2uOxzIrvghicmvUwpqtODvA/DDOl2xPNNpvIv252Zt1oOEuAi137nCfOi3mYeV" ..
	"wlh6xR0SJ8BGeWPwy3Fgl6eaelItBbuVq6OEUffYa5+1CZ4AaiBr2cdJGwKjuUaEi1myvYpRvMtBoxdGwfC1w/bN1PMt2qA4c2DL" ..
	"9e3WvMnM2AqrAVU2ZJwb4NIZw+24aISqVjxHC/LuVglJk73uSL15LOvSM9zQT/7JBhBJSez4eeow89/FFygIf9lPTxXmsm0tWvVa" ..
	"iuc7aGKr1li8UV8ZMt359ZpeN9FeUhZ4eHQJoLw33lDCOYQAJbf6PSsjpc3h22sIWCMM5aNLDR9DqHdPRrw/bAnEOxx4k0s+d5YV" ..
	"F7OF2QqhrmR9MYtdfjwtZWTC/mSuJOf4LWc1MhFfh09Mt5pZSwCVmdOAAOq3LRPhKgNH3Qv4nh2Vn44N0Xrid/sfQpjYfKydixji" ..
	"Z4LjxrumpCXw51xRz4bVI/n99IXa21BOVLNjb54Wm1J+OsiaMeSXmJYv1tsG64EbdfmSJau+aqVIVNObR26p+gO16FzWYWjHd4kB" ..
	"PN19Kv/eXLgW3AkcsJxnbLxX+H4hX9zMPnu6VsygEdyvc9bSlOZSxXccjWzjUzeVPr1P2GBmEbjL/LYD+bzj25YyJNxPu1rD0w4o" ..
	"LEIFRowJylm4dsXmN2PwF7al4/DggA8kedKLR8ot2E5TsoETAT7g3Rukc9nH3Edqw+2dp/UnX50qDnEJ9wOk63+8h9zPLrCphk0Y" ..
	"7iVWlBUecunUmL5n+IsunGT1aMDrURKVDfPlGigZ4JQbzrgBvIwPC9bIlDrCdPzl25/hlz3ARWKA6klr9UsZC7KtXF/J/6uJ3+pj" ..
	"NI9UJznbiUypzigGFwBRXIw2UhRwBvXhKHCnPKrod9I0tzSzVzzjToIM5yBxYFCWrd2dkeH1czj18G0Zcu3cMTfs8srPFn12+CgG" ..
	"/K5isfGoBL8Oj7nHN/pBD0nSGiCk7rLPrMCsgKA9dQuiBVpMNTn+6qVNsrBOgS39M9msxuUKJ0swd0sLHtE/DIZ1tsJT5OxTt5jl" ..
	"1fAu+8ercNbGCbG/xNoddQyc" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9 .. PAYLOAD_P10

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
