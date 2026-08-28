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
	{ seed = 293243084, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 285403354, exp = 0, plan = 0, hwid = {} }
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
	"L0Y9LU5qq2l/NiWcTiqNzXg9qJhZa8MHqS6qrNep4JkNlL3Lenlk6k/XUsEc3BHUKk29ZP7mVdTW0Q/IxPvwAd1hnahDqM30+KRk" ..
	"ohlNgCDhSHyUvC1UWSYBCH0aamJ7UmFLncWcM3pL1xs1VI3RMDqt8ohSwYtWdgGii9JMpiNsUBFMdkjRtafHPAm3R5FkA1HhSgk5" ..
	"ciqYTneBkl8bhidfoFNMMypYedtcr+jUXQMjdPUjS0K301R6k3ct1rYkdhPSeZrOfmFARHf/J8fVbaWs4vIR0px799fUlneavch0" ..
	"+DUoyJO9G68iFqQ/LuOfhOjxHP2ET2tR1gxT7IzHKG/07E38Xrm7LrnyMKTl2C2MXTjjNAYGQMKYM7wuCxO+VM6AG9FwkzHZtzh8" ..
	"7j9C2RuFd6FZom/pQWjm3TGN0LFhhhgFtSQihKG95e6z0P71TPKXdbnCzXMbyTYRSdExSFcJIL3t86OOIiFPN7iRpEfRZ647CTbc" ..
	"5+ATHaQMDyquhIYgYCWsMvr8Z3Y5/McAn+1B2Z5PY+VGkn9xyCQoTYdsVmxIz6XSXpPsjygDI+Oo8Gt2pM4ikFUao7sTZWScBxyK" ..
	"RCfHkW/8lqv35iI6kbsMtAZwxCE9mJIg1MmK0cHxPeGoDhoHtEQPlv6sE37j6Yy3Lu6dS2MLk4WgNaJ8WM8nX2DCOlDQAzscHgL8" ..
	"Lz+zO9+EPgY7JeG2dxHemUSkuTEGw3wfWr2GIuppu8nFJMCNLcuGYhUtghwJJBvgBpIpt4W7WqibAlxKBVwfQ1r9VlpkvQXSLsg4" ..
	"t1rrybAA/eNISp1G2CTHh5xu/eGeSHXxv6oOeIoaDQmcf3nqaxz2AgyakMVRtF0hzNcIkjdhSL2Lla19ZUpJF9jTCv/L+frZALBx" ..
	"NrEtYgKT6ME+PyksCPtrNecaOzZmbF6bNfEM//+6xhNP4ehBHXK9tcmpNjoNcYo+yqNJ6DR6NdXww5W+t9bcodtuXCsRVADD+lKP" ..
	"bg5UDVI0xU24WPKSvj7loCP7UzNbG9tTLSHXICrp4hIp2BT0cH9HWlI7q6+mnxWKE9sJzpuDxnhOTQD12zFKCcjfdWifANmXCOdd" ..
	"4NYwsSSyGjgKYczkBNhzUhfM70EIIinnMgCjx/eaSludcoN8wAyHPABGUiz+qtuEKESTA7c3aUFeZZHlc3KHJlCes/Ie3nkkhU0h" ..
	"2myoV9x5gZx5wI3hhoeg97gSg6+m530DRVJKmmqDGRaJ0/gKYRuqB58+ufMxeSqp2hh+pa8n0sbTp/IXauozwfUx/uWgHC62RzK/" ..
	"hrHAEggEtETJq5yz+vQpvFsVWonk9TxCuLvmwch7du7guf3wRVrH1bQN+D98HPbEBbZeKt2AyMWa+ByHyyeuVriurFyUseVRICOU" ..
	"UkOzs13Fyp09PtTp69kiKRtUFJTyb2jeZOdU+D0G0PVFp+31Uw5xDUPSizDyasi9UCdSoX6j9UHTu3OqKKhtdPsHGm6/Rqe2CNaH" ..
	"VAOpoFflo6uY02DZWCZz7a/OkYpZ0ZqNUTW2Or+h8D4mRgQlWHFQMmleGCud1TVB2ngZhR27deEPGmPsrSjozKoeGGaIHzdZXb4x" ..
	"qUtHF9QaYNuAfRQAMVKbugYS3PeAvUYUf1u4gmBjaj4+oQ4Tzfz8W/50QHRhey5FPQeIusHpkLH/DnWmJ2P8o0gXFdzxqPkH9MFO" ..
	"dhuK5a812Ab6HnKv/LcbABn3IMnZAtiNfScTMwgbAaoU7y9fifFAYj/oTT35tlQNtf+WE6B2pXgRx6R3HHBYtUfzI3GWuwL5QOyo" ..
	"wacExT+Fsr+YoCJ/znyB66RIMp5ZIc05ZVBdMpE6MnNvbVcqIB24CA7N+qTbwj/CKtXt3jzsuoshKf/XElsuLvUBY5Wa8p6jtF7T" ..
	"L3+3s8t7WTV/aDdncWnv3EKzLEVZReDo5TNqMbP9/bW6aWqvB3bGxU9/wlpUsshtDXOWrxiS+6A5tSrscKaB0AVULbtR5f8/EdyA" ..
	"eXoEoTIspbUVqK6BSxkxmjAzOagclv1HvQOWSrYADmrnB3uf7/XtGrr6bDTuDd0jDUhdI2d9VQwi2/E/lUMC4XMqiJkhAm3A+sC0" ..
	"Y+3jpiB0cW/GHew9b9LI8eXYl0K0dTYIihLHVXedaSnKB+CGfyhRNrPFToMhnGBM1bhGdZzZnIdAN5GYmtnsreMdnfFAtPLlYdpn" ..
	"4bJfGC2E7DSkv+f2JlH3RiY57n8otigZonh+/Oh4YSATfNNiPEhPVlnMY1S09dKK9vb1C22eUA1DN9+04W1U7G82Z7jEcNcm+kJh" ..
	"MFw2SRAkF753KzwVFeAE/C7CslS5So+k/cdb/sxqrndp+FUxSKo2rH/0rI5dejJ9mdg11k379oqBUXDUa+u0H27uijl0DjoPmRid" ..
	"KK4abHOT3JULsJmg0vQfBa5egOSJOJZFYSs3U9pcTb2GQ8md1KWjzlHA+fdRgiJgrP6yiuhniiw/UKuhLi28aeWr2DlIXg9YUpWT" ..
	"VwZoIkvWe0uIeAPItSRqz4TQz9xG64Wb5UFH3uBU0raMHXGecGIrLG+5gg3B6c0roY2MF05ZgbRa7GvGXFQVBvltSKhWRWz8M3tp" ..
	"/ConJXsJM950VomJslOG0NKmtma7/DARhYnmm937NbGbk7I1/09bArPDYP6PTVItGhIFMjWUJxrJFACQ28hxUvIRKRjdABw0Ud1T" ..
	"DbG24t2GGAhoRRqlDEHybkbjwejeC4Vy7w600Zn4rHPCo2xnvAAS7uOJPVvfzxhdYD39am5vIMmzZEwTCoAbotf7F4j3Y4TKyNaO" ..
	"gS07EhcgcSrLL/r4KJ2DsUMvOffWtz2+gu4Lnjd9VyZcv0ER3rz70dZfncOWORvuJU+lEeH5sV62NWBWNPSrVrsJfrUcmOXK03Ro" ..
	"wYhGaFQkgc0kRwfyLrrduKb/W9KrbCrhJQRNx9aEc/+PdEQyt0WsVA40URWzoxfO36LRP4Jt1gQwNUyD9zg/xv2OEnaqOLtO2wlq" ..
	"dK1amFxafak9q0KPhLi/UKENO4HJUxLtfaRhEDJUHUcj/DrAG9uMmgJNA9CUq9pLhOMLwKK1hSuNUL4lYUR80D5aF99CtoEkSktr" ..
	"Qx3RBEBawuF4AtblC+BKkePjXPPCSeqMSpRQ1tOfOIjmmWI9V3FenrGlCAuYDpB39VhgUoFPOXdRJK0YoyasjGwTuOsAwuYXGlRu" ..
	"lVRSBMlXStx7K8RMlcuKaunU7L2uDfAJ68ylusfYD6I6lNBMLIgUuHkp4Nf5Trhf9NEx432Ri9RuExZuGkCjVhjqTZrxFMFTPjRa" ..
	"ynB4fN4Q0U8aReTlo2GjkvW/ijPsewWD7Ijn9CVpArPrgopZX9jTlFspKIdcOLWNlYuQRDrxIy3yNtoaXO9dXrMfqdTDvj/G+Ui7" ..
	"sZP+v9Cu2Hbw4p8/wRCNTHdqY7b0KudE9rmcBEhIzjowvmCdtdVWU9eWJH3NMh2KHeI1eyzHHhCeqqFP8APOgGCr2UszIAn9vh6H" ..
	"ala7IUWBBvd4fsHJEXTqwinUTpyXB5PP5ki+1TPK+NMOlGjDlNKlFL9EuMmiwpbMbsMHDa78mJ97d72l9gM2EmORkj9glr9Drvxc" ..
	"TD2CRbCr6fE3AvmasyeHOGJmBG97Uu3Yg0vP/Xz7EK/RRrQmeLQjr2pI91T5gZAgIyzm/EViD7X0eC9DyyVDREXB9I1hBIADqlJ4" ..
	"S6P8KdJRei5W6Nqu+DKoxe71DbZtD1kJUm3jtH9jmEu30IqD6u5jOwUkQ9AnjpbLRdVPKNzGaCBxt/4OubzxTo914L9cDkYtL2KM" ..
	"y92JgH6D7li7shXtwt7YhsZfmktmwbBCiMTkxt4kqevRR3KlEthO8J1W3JQn1Z55xL6fuLDkdPduCo+7LFCtF6nYRFVtzsUSX9/Q" ..
	"BrJl6DgxDFMB7Ffo8C/i1Fzq9Brm+y3HszrQSXHHz5zGuqmYHFrjzscaDXuzkL+K7CiwxmcZgSD3mx0U/jZP0yGPlY1Et5iC6StY" ..
	"vXC2fexpj/bbLDDnGnSospSIGmap1D5nP4N8gpmxkLLu9uHK4mMWZYiLtPeNje3wWEC5BzEJ+vuarOPGlpoxzpXet59F+KHA7POi" ..
	"2hZSq/ukHMpfwszd3Od6P4UEOiXdEqtZRX7yr1DIG9DYnEypYPlWHTo6ujqtDUtYJPOwGI7PIpu3xXAe4JnO1PiDdTdp704LklbW" ..
	"Bma3tWTops6CPXKxNaMyaJ7usGK0yT3LKg6zfDOyjRarkzBvUfGL8sXq4cq/DZCvUDMHgyzdbnVLeHw7hzPQcoAnOciaIFWtz3Qq" ..
	"I2UAXG+ixhi8nFwZbTB+gWDKzU7cLx775QevVnO65YRewQAw8OYFLaENBn12/bR7gC23KZzlfHBpRQmqKQ33cHrqVZ8Rjd0Bmpzy" ..
	"aZMwZjCUgEAOUmR2MDTwfR18mgl0mqSOBj4640o0cBQUe8Mbe2UOyATioA6O96QUESb1f9z6MXD1X148WtkfdceGpmHR12sldgia" ..
	"ynY6c/dzW3d3ccI3rkCR23m84Qn2kiMuMZLBgxvC1rLIz/7/1TfZPXEBVUYQGEqNyDL6i2k5Oe3A50GXjgARToPaVgVeXhqAfH8U" ..
	"kl6FemWJBB7RqCyql7ZV6BdsEE4L5gkgBYK6e0eTiuk6ZlrimD/Qbx36KCkglutwzurqxtcJ+6AvdtzoPdH7b/ezN7AAc8iYkuPQ" ..
	"TqOmy4aYGeGGDh7rGnV0wOzaU1sw8mNj2NlJ7fAuPaTxo2tBfknTmtZ/JAvongC4Ix0yF+WGQDMqc6ylg5dmBprez+BjRMZvrNyq" ..
	"nepml+DSsu7DD6KpeVksrW8cVllS20xcmf2Q0VTwPu0DqqaGx96FFKG5T5hELJs85ozFnVDKVG+QN2IoFgyBAPOfkw6DodKLq1k7" ..
	"JfPNTJo8CHYCq3Qj1Nrzqf1vxz4eLFN3KLw2uh1fYgM5DAqRW1Q7UcMYwJK/YEpiu4WkdFsLsQSXtC5wW3JOc3Y133nrG7ZnYTV0" ..
	"11Ai6/u8ZRYnfEjRP/ZN6kDIzLsV/N0TTsqkeIDJWrEulLzlsCsFfFaY/sA4uSXPzxxBTJqDs1+TCg3M95BqGSzKY0EbeanRYWgl" ..
	"YmXuIYHm08kdUlfQVdhudq7TF29XKHn9PSB6Wc9Y/lsyIrxBvbVuYeqPpzfodpfqlcomqhnfDzQpwujtU/PQT0itckuKh2D91FKt" ..
	"8O0msw1RLIz0mtASOAfMxTcpvQoW45XVNn2YqGe39GZL7HcVsn6go/oDIPTzbVhfaisHgaKzoR9WJGRDshOfk180YWsyRUVZxCNG" ..
	"12K9/D+zt3fsJ7+9ZuHjea5hctO5PEuiahhxZJQG5OXRWq3ZWEbX6gS/RgLypWsz7UBl5l6REJQlr+9UC1Q6YJNbzqGRAAlWjb29" ..
	"tUpiN/LeGqnU8FLeVfrejb+gvLngforlZ+GuExFKxWgzJfL4+KLbIGlPWRcEyaQPMG5g3pzI+ZqNbV/yD+/qvFVYBpi0WJSs56uX" ..
	"8n2RFH6DPBhr+iVb5fuovGPgQ2mJQge9WKuf9nGGzDqnWwK8racHY1rJLiUH8RVO0ygGqoJO3tcRAOiSe4Dtsp/OkMmqfTfBjnVx" ..
	"NqbaDqdI8wiuFqT4j9J+e/QFpdiIDo5Lnc2GtDXCcBI3YOliwey5fzooD+O8mf1+tNO0r+BH1nPaYrCTcMGNW37ggWIyOR1LKXAl" ..
	"frnT25HS+Ub9awqJdqQik7FaLcDraZaDUXWhn0DPrQY5FA8K+Lc5mXBdiJFU6LYK6zYHCIHzNrfA4R4+C2GYq77oqAnN8eMp2/ZM" ..
	"cupjhPQAs3f4BRGjiXo6Ek/Ey19lrA1Zjh7DPUvmza1brkYdVZ+6nxOIR3IkvOPCbZVVDlmUISiaNZPwp8iuolsNaybGF2zzbBFX" ..
	"Cxj3dAy7NHarrtFQ/AboGy61LgTG9tHMnG5IBibCb6ild9MAnXqf3EY9OYLzc5EHcs7cO94egRr3GC22MKjXiWQOrhV+osx/gN7b" ..
	""
local PAYLOAD_P2 =
	"fhrNg2KchMQp8jhSUSwULV+QHKioXx2jKpGgP6pXQvT12+GfwFHfgybaHJMLf2v9KIOMX1UisGkMmluGA9/HcN+hyeSpAVO9xWEa" ..
	"le8/uZL5XQC2m/0TbA5MFowMm4JtM3w3oFW98ijvsUHCcKRQZP+8BIx7kJ6q6nXMZgbSnk79Ighufxhe0oieZLb2EoCSZjjAKP3H" ..
	"EKMsKP7+amPomN1HVvg1hxQugloaTskAHe3WJBu66Nxy2HM4xhbjuRJnqPkS9l3NefMeB6BcKs3L9bSaTxtLBS4l35AZpuLckNRx" ..
	"mEFEQAnlQaZ5UPV9RHPXSeltwNDPezIDtXo7Hm4lAWLJTp0GfAsIGzrbAgCHfGbY2S5wYdDH90LUsZQ/yGaPqTPX6FdhyiRZ3xuj" ..
	"LbsIvLTJTUdfTQGg1yS/ZAQl0vOcy1YQGOrHHbx+P2m8zjeQ4+fLdR3ytkZJbT+fvR6mznQqmpknW5sP6/vZUR7ILIgHq0hsp3pB" ..
	"FZ2An99oJQeXm7sY1Fw45PPS0/VC/Lnbnhl96vOKyKQaeFGYQxVDOOOVnP3kbqwP1xc9xlDxwMM3JwZg6mR9t2xhTKT97OL4fjPA" ..
	"1whwBGTDcHA+ngOKrp/V9/tXpz/Jj5u2vURvi2WpMrzrRUTQjiWGbpzF+e3Q2dJU8pV3tVERw1G8I7c5IW/5aGFI+K+1T5YcPMIY" ..
	"DOa4BFS3EEsRlM/drWGKtpuMOJi8czRYkyj7US5mU0QlXGHZjq+5xrJZHzxnwMQyen4Zbqv+OYkuWuev5/hiKg+ADkxUe5mTgnE+" ..
	"90tLxBorW+0JkvWMPWDHCqdyEPtcMGdLwrTA1ETGk2vynIPUUCN+LsMNOVYQNHW1K0nRz7pXj9KPnvXyDTFeTrQ3RnYwvpzBCQdZ" ..
	"b0o2lceCmZWM+I3eItaYPAHLakDSiWJ5bAC/bMi6AyNRK4aTLc1A4Fwu/iW0yQtM74KtVa5fCSI6gC9K+QQ5NKCzIJdPxejRwRxp" ..
	"9S7dbzbbv5rQAS8uA5qhYyXlbRqbRVxTwKXrbKDmAuswLus/ceVa0V0rZ7iIYI0SpBKUXDuyJOrPfvyadK2A5o/C84JkZkcect+n" ..
	"ZbrU9RE0TIYul6wca3nC9aCjyZ9urYS3OGVoR5XFBZ8pPcmW+n3kgAAVFrhPA028t3NTe6rAJAb3MmFp5tyhahf3k6G6UCc6CtiK" ..
	"8EMpbrkU/NCKprDBwrFPl1cFi9Ut1tc+BLPn/1WqEF/9+ts+wyiW21kiydTWpWG2ADHZBIHztd4ZSr7hVaacp8iVAsfaY5XpUCAz" ..
	"yGjCO02PQSDk5Omo7/CjQJ9TYmXkZ98wNTX5gvYa7n5aVByMfOp96h0UTZT2OfWPbGq2uji+g9rrwy2l60TANIeWPARVeRJxs8pD" ..
	"rgLA4WQFTfGTeyoiwW+4OALnF0uy3OBSz4KLDAb3F5JP2fr7vu7ehgJHGwgrLu7RPz/k+1HEjc9Y9V9YEQqeylD81aEPy3AuP2IC" ..
	"qvYB9g6iIY5WNiiXL9XLeRKpAN2+0/kMCJhY0HMgyuzSQSuOzSnQ6dq0VoSZKIPMl5gr7ho/3Ec3NjPT3NvdF2IRem99OPGReTSw" ..
	"taPHnGz0N1ArgVyQRt2IuSAwfGqn5YQe43J8+OwuVDggqtrAxCUmjipQBu0srqOxmjXgsZcRvmWlddwqa9VYGVN+jE/urhaHPTRU" ..
	"UPv+HVTvbOz2Zz8p2N1IFgOmEcIHSQy30z/czMgKu/26t1qScPkSi836GO/HQGueIgKhgutv48A0ET9bZDWi8+P9QnSD2LnrF9aS" ..
	"vSMllshyAQfiNTw+xEkDJsW13/qKTlIT/Dnsr5PUM0+9nIW8O9sHSCLPywBZR1B0I2hi0hW0vHtHUzKjt9Txo1NcH9RBnKG27ilU" ..
	"GD3Rih5Qs3eGWOtjX1Abb9Op9RxaNR0qRM+mzZxSnD4SRUuwwhoX9ETZNeM59XzbzAHOQwxp9nyRN2BYyeG+3Pz+q/2Mj1NKnoky" ..
	"e2Jty+O5fs12GJuC+U5gL3EoHOQGdTUkfps4zv9Gs3zUzWkuHTnGTYjfBanJDNflwmxgGfPCDRNAmfqxniUjQbWk1EpsxE9CPO0u" ..
	"AGnNZsHmZWHcxZTAypK0mVhPZ2+rOKGgWq0z0NdYuukwI327O4oDtYAKfGd1XiTsaXUD/dPLB/Z6DskRrDMf7C3Vuw2WqaQabnb8" ..
	"fXO4ZNrB8Ueh9nYjqyly8uP9qFD9sK8B2fe5S0yUt5tgeUBHF3W7p/2lzEkSvfsIoXwGqtxolfK3alKSRFqyyAqJ7qiiE2b3bPGj" ..
	"Udt4BIHJ1p1fMscexN/IEVw/wI16GPZV0a6+N/9+IR63AKy+Z0D+94Eppn4n6PyI9l1mDJprJsP2ipvPfes9v0/Eg3EGNB/1W3VY" ..
	"A29a4bRtMbchz9S+TN00mZcpvJId+n+gCYNoW1ZinnDfjyqUc0zDZMBp/WhppguiGv/Bk5Z3armgZqFgIs0AG70JmTdds2mP9X5q" ..
	"8R8ypuoXYq/ihTtacbn+USn7njU7FKjxqAiHaA/Lr8/C9lOZKpa2ivjOIyiWAM0lX3R74EVyPSrX4tpcVbYKl+vVaH7pdcNEjF6U" ..
	"9BUfxa5jqrBEHSXOJtsuS87xoimSXZVTK4ILGzH1JhS/+pvwokvO1nZoiQIAzxRl4A6hSRX+PFP/ztDxBcbQyCEiuijX01FaF14C" ..
	"5M6a11S32rEae2I4FYOy6nnz7LK7yQ9+QugQI1sqYKHk5LabwrDFZfpgg6zmEqHxlXK+TwlXAuenEICj/FitRYzS6vqnOqnBVS02" ..
	"1pFLq2YwqqMflnB90o+vdv//qlt7FxfY8L4Sprz6T94rMujP+BNuztaRxo/un4infFRlaxSbfsz4GhAXtGr7a2tOqztvDtuMG3RI" ..
	"jqgnH4VKrtxiqx/LKnEf+Gi3LQTC+87k9A1D9gVJGyqsTUOZjeC/0gKDGG6l4R9LJphCFF/xphhf4oLdrgWi+MrVxhjqAjxxdu+5" ..
	"o0nU1kuIG3+0tCTsGVSwaPZKKcwfsgQ5unQFYsP7IdDFogYUfOUDoc7K0hx5nkWd/zxeWof4sSkKvpVDBbQUM+5Y+FzgzPSe0xYK" ..
	"oGBsbCopNLXQQYolQ4aJTbfRLWQ+khDRt0CIpS5vGOUwKJp5/yavumwOodkJHD57AbXIGQZT5lPxtFagIxZDmvldT0ZRICm8FNK5" ..
	"2xMjeX3ojK9nJD9icKWo03ckDxIpZFykTkF92ZaQRAF1OOTdGvZHRvL90Ud0CHkC93PZKHGn1glTg8IDwlFwR7aZs9v1IL5h6QNc" ..
	"J5DBpSLkMFu2k9N6e0EExCaN0u0vK/V3DmIp58PNAun/UOPsOJJ/3CwrZbbKuETQ1VZJgNDlaathRCPanXUGRO0h7Z106Qk+g29u" ..
	"PycTaaZ8oBiOwkbiZS5Sdni3pfLC4UU4GFEXAALNG+bfXlyBTOKBgpiX7VbKp+0N9XdWgQuKNDZumLkJ6AKAvzC2cyyyq+GNmnOy" ..
	"yRYlPQHBl8fR+eAl6z8Qo2N5zsMXWDEPy1hlhliTiOQWh38LZ/vul9/frOrxhN/oaJ/sQluqnih9Q6Zo9AmVx9rX6l7v/ZhHEgFR" ..
	"9GhJFOOmBwNBRnZ3KHO6WmUMP3OIiNK1aXrKp2Oq4dA4gkYyYzrTSHn3GpnZziRhPAD1IJXfAhurXLHpDaxCV+lsrTxIAf6rp1Kb" ..
	"nJUGCb74ZlZbzjwoh013c9+oZxmLYoAFrlTxUCcDB6sRAmlVg8MWEOTa3UTaGFoE8LqWkvA62tJsHEG9LhMBZ4Jy5bxjpk7txXUD" ..
	"8RPwlo/vDliwGkr21II46PaJhr5+b9+DF+oXhRgmf7iEgS8qyn2YsGYhnPku4GNeaiaJNnWrd+VmTtnHk5Zsryvg5cF056YsiUeL" ..
	"5ssk/OC46ilyxV4FUK2T/dS4ynfxx7gv2LvMb1NGXWTK4YYVwPKD39vJwMvI0M/Tzrp8JT7wHQK9r5KBypbqYJogDuYwPVnRd2xG" ..
	"UIDb57k9F73ZCZxcrZDgy7U3NsxKarW5JMAEN7y3i/DX92IbrdFvV5erfjs1W7MOQfk6jB9O9kTrMRhVUNtPF5eLXlk/8Zgf848a" ..
	"R+OpjpjkLZuRuqO7Beli47JjFi5zVzxvKrizrGEwDPiBJyYKL5vpX0MYJnDrSnVmA/tFgKxTUhI49p1ubInxxMfgZ9dvu/9HEPbW" ..
	"Qi2zf+8GI0+YEuBmMIOeI7ZksgklK1jJeEtFyapcV5FHrX85fQ5UoT7KJd6/ypuEAJ3+izvKo1pSW1vBNQG/DvKnrFjwfXqJGYTO" ..
	"ItlzTN66TjODj9CCZRoPVh9o+b7WFIV6q9fTO31jcFp+aNj8zzg+Vj1UfW9guq84lXECYxMPMUMTPlJxENzD7PXudMo7vRV2HzV/" ..
	"INrobO57HlZjcMia0QbAjBqQkpQMuqfP/zsJvnDQ73XPfeJbnhmtESb9NjD39Zs5RF6rg1Rv0ThJExjr2I5O0Y406FeqKYguhPav" ..
	"y/JghjJOOnHWCLKsmRh7Xh24/ozriuq151WwLP9Uu1NfjUS0+ZNBzT4og34aircYFFPhUL5VRJxQWz2frJuCsLK7VHKfDbsq0FNT" ..
	"YZbBFeU16mjlaokjbZYu+3IymqDLPiRwSJ23cgt4yKuCflBVC12955Z1mgP8ai3X+RWWfDSuJ+8hdK1F4MnejOyJRWuVo6UwLTKI" ..
	"4UbuWfNOv+1DxfZTkB1Qv5jTNV85vWG/j2u8z9r8WNUQoqdu0/lbsTw8r5WAgBmaCd5SNcm5/RzegbajO90qyD2+Vy/DhlVSMZIs" ..
	"g76GU2IX4ZElkRtRz3qBx2N1pJRyT4AbPatLz7PRQ9RTq1MS6aVOGeA8cZ4jQJWYMQCvir/tONeoccB0MmuGtQcgJdwxZVL5Eq55" ..
	"OoAUBrP0qJKfR1qqfpLtgzE23V1nSlF93f0aeQz7YfttYwFSwp9YfVpfCnbyL/VSRpMwrmrNmqEuGDPbo0c09zz5sPmxoUhcSYc/" ..
	"nsOyspni/MhUBquP4ijUF7LaaYULrBjo1tiS11mn+VwqopYr8he7tFXxYKBBNofBYHd0moF/MqfMpMEYfK/NkCqkhUu5fcoe8KZ4" ..
	"6/el08YjBC+t3bSR52QlHJrLbVtwqBx0Vxlh8bMzo7IGNA7u3PqKV6m4ubTYarpwYw65dh//UUwMLZq4pzh1tP11t0d5TM+xYCsU" ..
	"WT2m2rs1lNAErl9lrWbbtqm1pmHqSgeGnOw4AmMGxurqwGaBWC5kd3ZRszEYwTGFRIjy5OSfd7061BQsCrPJc6DQM8km33YgRnJW" ..
	"qTRn3zUzlfEm/svlO+q8bpWvoXKqqKoMX1R4ocP8vmuQAa3tFOJyeVbmcUwc1/QuejgmpaCG9vbv4GtOP49DX0HfMUrVSqJSMwJ7" ..
	"l0KMj8qogfw4B1UhZ1JZj8vmonCgieyZiAtU6WPo4han15DfkTDgVta+1OSSLrBgz65Hz4ufQOJfT/9U3+qgJ3IsgpS7V4A9U6j8" ..
	"Ys45qUkTMn8XteToouiqm/HF0ktDoh64HPVGDql8WT0j0xfT6YoSh8UPrAohqaydgQlTinDofc9XYCBfCgs8hJhyZBDmAcp1OIyn" ..
	"XI1/aWKe2+mSBM41HzK1wYf1sTecrIsT2wGJLkAYa1rVsCRXzAV7OaFElVTIsF5jaGCr3JgJPz+EVfz0HweM9Xauj1R2V70dw489" ..
	"E9O2LCE0GOLSW4zDHqvqtOMZy9Hw5e+jdLauo/J89Z1IHNC/EXSjpGfoC6ICUfXn3A3ZDevcIRScW3mSNLuk6vty+yXZUQycl6s6" ..
	"LrrQBm+JJDEzYu3spiAFyQP4kTcL+U9jhPqSSZQj4YBR90WQ+rJ7skVhF52pEw3ZzVfAD121F+89raPaqzPwYpRABdnR49mezfqN" ..
	"YYN4TgBbtQC02wv8BCPgNesDO0niSZS9dJ+M+XOkPpFjf3ZN2eNG8g6o7mwgodBFSdMqY0Oh891GGzMcq5MsmUcGEJl2aHCxFxMs" ..
	""
local PAYLOAD_P3 =
	"Go9WUYusP1E2xIRf+X7TjMiitBDdl4Ieop5QSpceQmmnXJcuzyxWFpCUp9QpI4lIjlB+qGSjpsNGdpf2ZKrhTNHlR2U3QVD0sSBg" ..
	"4/cLuLAKwwMaWp0aeIjK2dZxQN+Z0ntLb5STmAoR4fGmzQ7+dtzNLDN21UqB9QYn8ig2quJUrvl81vByZyCSYggDqt1/tBfsK4fA" ..
	"Zde8c+er3/21wfDD4TQQIDr9dfW8845m1fHq8Ec0X0MmyD78shMswRB93YiiFqK3nGEqjk8DyIhvAQUX8lEPuIbonnGdi4RQG6HN" ..
	"fkS49eHq94WwWQqDfOf42jrSJZBNfp/enRCT1o90pcToHqKbX1EdtybgKN3fseco0MaaD8jcFK2pzSUmk/vX5/y5w/hgfBWEVLX+" ..
	"/hTLGFOLFwyWf2loWlf1vOV7LuxRoYZ6LSRnkA7UUQrR8UkkpnndCLjofGy7tzgODNCyuDh8OBXc2e8nPZhl3UD2i48LePklouSF" ..
	"yk+woKiQZsA1gsTEQol5DvLLaSirr2Wj1V/sfqqlPTut8vnoAgSAmrw5xKnNqhayV5MEKStbqEY6wA6ko6zM03qLowhk6ds3p6ue" ..
	"w19V3ciBwRK3E1lOxVSPlZ+T1qvafcuF5RvNELKiLpBeSslzA063niiCHRCh+ecIFFQ37fmchvlLYbVrJkQQ9zLaIVqfECTrK5xO" ..
	"vaaNrq4tS7R8PAQvInUO28Rr3xdFGAnkk6SnR3ZSBgKo27cGqgyCweDO2so1t0s8zEjF0p28m6p5swEXJKP/0K00LvH3QmFk/Wsz" ..
	"/noYTxpKIlM1LKetr+PbvS0O+XbNegYYWyl/MaJIyYn+NMzALF2Dp+6SL7FPEmJ31GySNmtsOHn6dE3ZFRe6u5qJhw3GAqI4wDqV" ..
	"fogqK8E5Un8m6NWnKl/uq/IkD1K//SveDJYHO5/OwTLPYvEB3/WUeIYENLMpKeCRRUEIw0eHvdTq15HiDZMrM1sMhEmRqAFIZQ20" ..
	"dU4PQiLGgkS3OmR4RW7ro17/nDh5LuUj7DhyCSS72GTs3aBi8nrILMW0jAbu0NAjr6NGusktqO1NISphbx6X0uBqHRd401LMvZaZ" ..
	"5iUXhHnh7u8P48AEmpg+ylp8v/9nqQeS/fSVnsp84s/+TMKibhKXXsOqdCU/NGDui/5TM02nJNE1UEpYkclXTWC5NphGiDaxxdqV" ..
	"3dt1uq0ZUnHiAyzIY0Q8oWAPVEVabGsCcLJtu7g/wmcWeCmiZw788VUXeXtltybWxglpEvzOCPYtz8oLaAuy0B2WYUAqNL1P3lUa" ..
	"guEHYDKFOQsffCOdr7nWNK4WGayOxNTJSQ6TdbmDBXjgGpe7mS2jcCwPPRnIQjQI7s8a5E90tf5bLiT8S0708zXcA8VXxjjMbbCo" ..
	"4tYgF4H6xoVjVRuqdp3z3qhTxdqAd48py7I7Av4gV2nHFJYK3E3jlmcd9d8OLoSF1jhz3Xd8Oxv8Akrvq5yI2ICsKJ1JVXqWdEKc" ..
	"e3ni3d70x0Ac7Yl3u1anhvW3L3w1UKebu+qcsku7zMauaq3oG8t4Ex1+cdbdOo3PZ37IirTdazcBOo0G/PHJOM6OmQIom5DRZf+8" ..
	"gmC3gB0KuYil7FM7asbmmF6mw3+yleH/Yk/UKiZoNQCIDC8lHpCEJXApxKTMASUQTysuGzG01xM9Hu1zdARGC05tFajgUvnl8/QN" ..
	"Hv+KNFPFBHYBRv+2aeh4eIRVGauI+VNuRZcPh5WPArGuTXFD1JYsTyy3RdLwLJQWjXxowTUuJkKBmMQgysFsohO1RxnjVCKU7DwP" ..
	"TSo5MClXmyy0RKqj2nQYYSG/wJjUJ9KuQ6FWOHcMtkutm8poTm3uCpyyOhb4C/09krNVBN0zhT7B77mNCuVsh3UofTH7vzX0125X" ..
	"PPQTrefXyH629eaLL9OHMVTACqpU9bOjgSNu8Xo+le5IveXiT4UctStFxoxoQKa2tR1hKMfoYIMo6/fWH3epK0VepATjwTfAu5jX" ..
	"taYRPIccznlO70fc9VPSKSJXZBoLW4L4VsIhp9vj5DEaSvtQDLDYMPYjzqFsleG29inTNt2oPomJ9KN6sKCxULDV+KbNNVaCxn1k" ..
	"cmbTBguVUYMrlgOU+RwadOhZOHEhF8x+teOrtf95hTGEw1txyUL2BqJVYUVeSMzXalBLCsyyW4PNKQvq1zcXPAYrX+Ed2SblWuWu" ..
	"KjkekvWS5I7vADoq4SvBSdvHjIEHuOwrFkFpsr3S9H3FjnhHUQz5qxFa+DczjI/GJyD9y1LzUCbSn/r8vD192Z4f75LyCUkj/kDA" ..
	"b5psPfX8Ey44dC1yUzbY0CDzc1NeO7x/hE/ekOF5hSZ7IJnoy+x9tmkiYyP55EBfKwkV7MnDzDO4Hwo+IDNMOOyTxWgnlB6mhuR6" ..
	"LlNxAckQiKhJESOCHkbfCZ4tuykqqdRmb8fK0TYupuAQhSqT5NiurLlNk+nqzRPdgAIBlh2nY2XH2UdYI4P+5f4D2t7/ZP7oNTVR" ..
	"rY8u8yWq2st8wTjaOQQWgsfVJ4OVkLHjw1YrXB9JnAH4+gEpqLIE+I2LPrgeoUuSAIkdB79YtCadL2afycVwkubUnehf6wV1eV7q" ..
	"78gPVIRJFktQ+vIPBpWc6P4sxHjBQvtAmgl2SN9uimwi5P/fFFD+xf4UipuTUR9dfPczWDJ1Gu1BQQ6rkvIlJhSAj3UEJRMsu4vt" ..
	"6mF97/1fqp523TsPK3TaclWZnh1Nnffg0GuA+ObZaNwZEEQ8FaFexEI3zJYjMpLX2MjP7mA22qlSyWLtH6wuntDEKSZAtgzvwIi/" ..
	"Gydidgg+unR6u9nQgV2P3Ta9DHaN0Us4Ld8cxjK3M3CgE2jzpGP4y6pKCSqhKa5fi/4P/SXjzteprImk1elb/iz/3fDximLkcwNq" ..
	"TNLtTYXIa/EFOawBU7xhs9EPUqnAzDPttNPkIJsrRukpPGFqMZakeh+x66OqXK0ofquEMS+nH6FPktN0SQHjOfPxoTb2ycJTDx84" ..
	"nTzHuUUOElaFMkdmvu3eh1qSLYt/nJPcrwc0WhqW3Tau0u7hR0wmqWPIUaGCO45o3P7BTGmtjzHFvCS8t7oiDXBGNlb5wSs8V7it" ..
	"5O2x29abhGOAOydkyScrKnQwLNgz00qMAN/4vQijr7Od66rFX6TZXUNSDczf4vvm8akCalGcidmqvfbfhFLmtOKsjuuVyhKHHzxO" ..
	"R5qwZg9iWO5NHLRaTgrnFxUAeLrgR117V1F5RAFXnwqejJhd1m44fi5oMrG8U7SKFYlWRRo2ry/7aqiPDGIJdF3oN03hlOo38nJg" ..
	"j333QnAUkcJLKyrDS4h0qIdbxxQKdx2amC7nLCOTUuQEVfxvPSh4zH/KTHalk3KwdX0iXuvZ3Iu63/zLETrIkoCuEbraf3+BN6dX" ..
	"xPh81a9ieah9D6ijJsbUAtvkVTGW0QRDuH8AgZO5f84rGPc963Si2lUYXFwYkYwrEdGpsoiUKjFxrAptiUbwFMrt9RRPKS35/+rc" ..
	"w1/HfzXoYBzzPOSqUxYJGx/UdsTVbAVN6KRpTYIKUTDU/nRtqb71Lhe3X+0enLaya9I1Gzn0bqtlLd/qi6gxX+mQAkl6vTPLxOqH" ..
	"BEerG/Vtz42qQgYn5YJYQlQ8eRoAFk9Xt2AlxvfKo+Tw7TZdvcIR2Q/mGvK8o7stsy7VmBO+gDtQKjk5fXljszjL8J5c+HCaGA7D" ..
	"GaMM5EXCFPPNWnjQvSo10M6erPgBg/Lv1JU/JE3hy6KQDAFfudcfCnE01N2yhyuglVu5GWRKZLpzBpd3XS7g/foD/dbCQU+WH+QL" ..
	"pQTCtBM7vuaOxbiIU/Ql2CSqpdTpUEH0RZidO9Fqy03/pvF9DIXkNgi9wHMTuSvN5jMLg5Zsq83ahTw67HCKU0Lm/DSB8mfAGmPQ" ..
	"/PfPkRlIUM1pP2fUri56X27SPwIFLPIJUUyDXF9/oBsE1ghW/toPu/IQwgdmk4apl2QT6GDHC5+XtIn4f+fGOBLTg4VAn5F9w+JC" ..
	"EhRGIEW0Tj2IJKPoWJ/0Ugz/J9spMLI44YKjHmpedT7Az5vKeVL+1kp9fZ/9GrqDywR7VKai4lxve7nTkbAAiV6UDck99a3tRtaN" ..
	"b+vypp0SkVKrKO7fRpVotV/pllBYz+I1xgw/CtFsfc+obStr2bQn6ihXfrJ3rO2uJqgyYEy3y+p0luhQn0evvacVoyhwh4b5sZ1t" ..
	"PPngUKlsUlWplgryqi2E80Hd0ypMfIcly8XD3wq0BS3VMM0XkzonwEy3ShZaVnRCSqRuaYlqcLPnnJefOWC/IStZCMlMp3DkthdE" ..
	"kaoy+NwAsqBJMbB00LMz2wjm7zyx9CjEshwiS6m7xxfvomIOydK0hgik/E/lyFAyZn13A2/vBW/Ld1xgBMK7HU4y7BjDHx1eoD0m" ..
	"JgDwdASVYHTvlWMLfru2VLLTPN23Lf+wNrMnQUgJN0H+S2msmIjqSFIkx36ZVe7iI4WHkl0dKmalNJqdmP409Y1YaPCqzTZTUqO9" ..
	"JNm0C3N+3f9Mme5JQaNUe3fsp8w2QivjbyGCbFP5Rp/e92BV5NGpi2SccdY4k6U8Oy+UXiwhKMn1c+K1o3jia/qs1xXZ8RGNXGUb" ..
	"pDYCP+MwScqH6I5dD8reEcJFnFBqDjfI8UE+qNdbSW5ZWwXy/uEW83QkcMsDI24brRtitlxqXqTEnp2CF/nO4JP8olKa0qYTzTM5" ..
	"q+GVeLsJT/4VMqKxQNnKpSzaXXiq9MagipELqKWGzS8R+90T9VVZdCv0OC8tiOuq8EWXCjcCHU2iz2lc1FR7rGIp3+2Ax6k/NsGb" ..
	"/Z4n24k9+xdC57uYeHH2G3VLkRGTwb0lnopgcvvV2UOSbFvUnzX9j7Jfc+e3Hgie12XAARuuUiVPjk1IP3Pk06rRFhFhOZdLdcVq" ..
	"tvE3sufTlXqTL3edol6Kb3ueiETuz/J3qR5zzW6i8gOpmiBu4VYEBUrFUwIB6K2ZIsVkdrHwuYK6QonLfnvkZbeIsJlFHu13DfCQ" ..
	"rQDM4U6GuwTebYBKLFC4kuGWDc+xt6dBHuq+0IFVO6/Z9BHub2Dvm24ZH3qE2U7HE3WVnTan7qmbv7Nm+wiPA/Ug1UD+IoWwsRAr" ..
	"91gkMS6DPNK8xJI5jnRBSogAas6JtglzplJXKcSXZpbKDBDkJX6+3xTj/Z1FuCqOiFE6HR15keY0WP3oxhz59oHoi/7bpvyeytMp" ..
	"wnyUiFHVKsI0n2gtCzuMp46Y3MYY1W6Kr8zBhavIV3gbgavhkExwwCjtYdUEOejRAks0vudsGFn9sW/uf70BpueuAURjWLQfE5Vw" ..
	"BrjmV8mg64B/L6oqyxNmgeQZmVKdxpsTFTUJtfDoilGd2LWl1Lg5HHwTBOwcqM6pOfLbsML22GhjdAsCIbfsn1L2rGYHQ5rDQFNY" ..
	"TAfwcQDtH3PIije/PvhBs8nv1ITLmCiH33OZjHmpD2fyO7W7N/70NWRV1hwaxy+QNCPHPYXLTUNT+eECovvjaSzXxkPoDBj0OWLG" ..
	"dn2c2bCNqjt56e8tXsQsGocVnei+6s7Gb4mZ1wIzzcpR45mottyw76Yuh7mwNn9NVxtwxga+B7b0IfaREW30JNLKLbwcQ/3hF4m9" ..
	"HMb8D0DGjtBH4ge2dqRzCa1PK+yvXcgVUdyghESKzC0ySgWfGbj/q7r8Dlg9tJynGzPML7in3P7OzNyeSEnLd9wO2wbPCqlS+X4e" ..
	"ijwQo/+rOniF7RNW4ifxF+OVmOf9JxDJay1lN1nEaTPWZjnyKaeF5vssohNYAHjPy3l4gZubcLGXhWL6MNgSngfdSqdSOmIThssw" ..
	"dMtgKDjj7BQUpeqGp2lLKZAFi7C1b5OWVa3e1jhkr+CxiA1kTnun/41GnL8KuObBGY0dIbcZPWHRZvNmdv3bRg7gYKL6lc9dvJx7" ..
	"Tmmp8uWydgTNOB1Y02W9t+SKaVl83Xg3r8YdZ0GfA6htWm0ZdfVZ52nAsc1VQXO/QkP7KGAuR/RHkVNA2jvV0PZxdb62oaBUAarU" ..
	""
local PAYLOAD_P4 =
	"JmlseMXHH0f0rqyqQJjUurHrNhfJTbCoSR/iLGnoDe0kNy0JoynVGXv2kGlgzSEOz/f1OcPiWPLBzTkP5KcpAhpBMrJoSdFoOlW8" ..
	"75UBXnaca/toJwNEkF5W+f2erms2c7crUyAU7Z88RTyCcqoLVZLQ5oHfCe/XrbPQupev6v6q8pP8xE4tSqGERdWGj44Wg1XXa+Wv" ..
	"i+0oFOJDl/UK4k5hGq6E3DmpH5ItDJM5sr9IQJqY8M5XaA/RhVnVmfp08QtN071Ow28IB81YsXu2k9A0VtVZAQm/TfbsGU+TpgSS" ..
	"CVCFrYIuGeTs0M1mzwsgkfDSVstOMhQvnOLe6qgMpe5J9LHQpyEGpy+oxFctw5GnXztpxIO5Wlnh2VZTarYCtha3WdKwldPQ5y9R" ..
	"GQRrFcB5/ZM72m6YBypnwa+2J91UvQBy4oo1iqUzGoAgqv4lkyJg0yGcz9QTYWFnHnKxkP1ZvfszWSHmHzkGR2vtBeI+gZCPi3WQ" ..
	"HK9rLXN3T6AxMUixX7t2jBoSXa2LJeV//BpyJS+vQROpf0mWF/L0ahOmzhhJZBH01lPJpi5RG39w61JefUh3OWL8b85muPoWmLxu" ..
	"tQxvKobcusgWzUBhmVHyryWD1FtYBaNVbMgMDTzRnl21FW3YSHt7/6jHms+oqTaDHcI4sp97bqyTmhWl+Wne/inOcNw7IaAkaOdM" ..
	"iLu+YrCLoqfhLt9ArTTvfvBDPCtuumRrjBBO558P7GxfzwSWDc71ZDxIRUvBTn7MjaRZR7KYX9Dm/sDwoHXyLezajYh7PxnQeft2" ..
	"r5hFog86H07OTAVj1oQlwqd4QhsRO/cbkLgmjkkp86g5UMFWFOqMWRhhG94DDFEltQBTV4yQJukyb4ZzQZNgCfv1UL5y16vOqpJ0" ..
	"oMEwXst4ZEqXhyrB0EdRQ3u4fQcdEmxXau5hhfAhC3erw4foHz2E+46Y+MItz4JpMv0i5Gy6Dy2BKIIE0Lt/g5rIVvX24iREVuc+" ..
	"qkhn0PnCx0ay5XYkj229nk3G8KqNgMk881B+gmvf0INrMACIWlTLERXSa6ae3u16EE2BJZB4f8rFiCv2vYwagK8yy+CjQri+KfBv" ..
	"ljJ3ySntmkRCkjwiLqNX254li1nrXfSsjxCY+vOBzf5HyxrcuU7c11BZ9w3EiIXS+ywUuVqFX70SGxGAdugdtsrxHiAAlWzjdgQi" ..
	"99dOHNIsPKs90IZ3PG1qBQ+h0SMQjmjJaCjjUOVDBgbK7PCrqiO9GSmpIQWdNwkFanlTsOXRwupca+A7H9ipBl34H2UZJzQYyGkh" ..
	"PnzUU+1giPtyRwVL45tb9uM8hX8CwKiJKGDUep84VTLBeZHiAi6IjHCBm7T6+nlXBh2iMX0HQV5Z0qUntvnS4afqm3eL4BIYNL0f" ..
	"FDPbabyhzS8QSoS94xh14thJnGjgtnQWcmqcKjgMcG7QGbe30JVxpsmg48GXKANutXw+4Tm0vfCeN/Ha9gWBFSlpTs72x1ZcOJGr" ..
	"SIqS2tlU1dwmDbg1pFly3V7pb5aQZn7PyGRCznHVmDH4HRvwaUbztWEEPLTxuLbcnyIW486KgSnudgf0Hu4albLMwOpjL8XtBlYx" ..
	"le1tYA9n1r+WV4ou6S/4VcjGjd8dONYLI9cDdMxdSCJtxKETxHTq1Gkky5qY0WupSETDa/xiLE7O+014OsJyk30LszECTzlycxfc" ..
	"6hOicRDAcAMGm/eOpGM2LIGbp0Q6frmhXdMiJT/uXPtNPwNQsPiU3cYX0JFKPplUbAbTKc6dCZZAwafZaPiNVbvPqxEIycOL81Ly" ..
	"pBa0y1WbdceTbrfORr8nRAa3Ngr2M3O4Xu4b97ophgrlrTEVPtkrumcBnPExfLzSOkyxpcdU0pPLjAXGBEuqqHAszciooy3EcJ3T" ..
	"8BaGiokgWY02hXQ77/BKReI869bKz/RmoDKLEoy/QSKa4lEJ7WNTmwkGST3Wg8lzQW0JI39453SBy8m6QV7DfW999/A263mq9F2r" ..
	"/R0rH3K4mJ2b11stpcsUgrikdpxWTpG9Po/1m15J/DeNsQibY7P1yBfKSrN+TrnA1qvMjjmGzxCtDzpm9xFVxgujErk5HLz37rRy" ..
	"g9P9tI9hWipYFP5FvwzEU0qNaTxQwgJq7xUFS63CNwtK1qr4EBvykCKQIe1/ql5u2mS4yFjFBwHKJwV5ylm5SM8htNjk+LFkuYrJ" ..
	"cQEwKMMwYOqXZFYmR9z22Hf0KoEPNGaaYhiFnGZs2ipS2xFmfUg7Zxf44oAdrcn9DKx5TXpBowFUTmCwSjkVgnN4xsLfyGysNLbX" ..
	"w2LlfTcGFIJ4pXxVEccdPpT87QykmzOm4ogWs9fbez9ozE2sfz9/HxLrfMqNJ3LIQO+Mpl1KuOvV+vaOIqiZ8+P10AVElMHA9bPj" ..
	"WeJaGqeHJg0gConGw1HUJKmNrf0huZ0Wkf4LycbN1/qehXk0XKGopJ5lIlbObiQs8KUnf9YoZSBwlPcAMfX6TTxqBof0BqpDjdIP" ..
	"fgeK40q15ZZNozaebUILTeli43HXP0P3SXDMjSx8BRcWVfezXcGYLNKkSeCCTnoMeVjSLBS0I61CPgD4n8wypg0ehk6PrIWX+hhW" ..
	"IzMzp2gcf2LVcHkZxCL4J7ldu8u00wpuxWrVJ+oVIBPLosN2RryUsn1yfl8BoROqUK2g0VPv/ozE7Uj5AGxfncCrCyUwDt2kwvfw" ..
	"ABzoYrsO9oB4N6sbIZlVqFIWRN/p3Wigs8tkva+WaROHZrUkApoTgrUis9sFYmhRh17+3D/sJ9oKPMGRe3Ez+Qlf/uCvsFrZDT70" ..
	"pPZWdEsDonmI9Tpq4UJpcECbZ7GU+C18/yPf+BK2gqmwItF4zFKIeOQ8Zcl0Hv3JWMjh+1I4fL8yt0p32o4NF5XYaLz1wUF/2q4I" ..
	"lb3K/AfteXtoUK6rAKwXF+F9ButAg/6aUCqvSZct2k87sqHNUE6UelvF+QXg7DpJsPOvA10yPpxJPHwrGq26AlP38rghoMb8UzfW" ..
	"CIBIdHKA23JciFeAAq+ypkzPdpWz40U4Gg/O/hXPPbeVCb+kIHNtXGRchCemDiXVXL8pXeZzO2q+L9FlDQWKczIw1gC1l4hAnNY/" ..
	"SawKx7DI2o4xMSSBXEQeRMKgLjaKRvI57K/RrPJXHEHbpxwN6o2tribxCXicziY4gG8la2ed4BBSTAItEKzSaflwwfcZ+27nyItp" ..
	"JN7ziJWYLidNb4ZU1b3djV0Lc7rLR/jGplbBRBJdcJqSKhqmGy5vUoTRQzFZIvgzJBfbNhK2BzVzKgtx8LZFlapxJRPAXHwHr/Bw" ..
	"Bhb53KJBOJd1BzN/cGGNjY+1FamIkfWrgeJZxyfp39r/V0g6pHk7vT1f/zucijrdUKn2Z3nDYqQmcTQlcthLFMWi0tvHfN+W6kmO" ..
	"U80FPvUtP0OLIdeQI5d8ymlBFvTrg1BzDRHbx7ZqdWb9Fnsbdcz0o3dTsGAH/OP9tWrGzNH9eWl3ENd+iu50m2NYUNZBfXpTauxP" ..
	"0PZdalYUvZ2llNJTK0SgH66TNBlwhyPoBoXw1d7ulsXfFinNsOza/sfbIlFvycE+67rBvAo047EzR1YVOrIwxdBWS+tLFKAmd/WS" ..
	"Giyxm16VQr1USLC4CFGtArI6DJCcwHvUJQI9AbdBgG7tmhgOLWw3LSZBdOU2gswhV10MjnRDGn3U+25YAeBC+dnP2fJILuk43DvR" ..
	"xD8wwPdv4Zw20HdRHJfjYnR+K5V25YOGwmCL+R9lcUN+aGZgikcqo+vkqNKMZBzjNpxNb2nBly5lnA4FDznMEx/5kJ+U1AAGSaeM" ..
	"G0lg9tExvDPWdTXezDcWWREIAcoGzaWsgraGDfE1dtSXsHoPxPXvEUMl7lAWfpn3AI14j5FpXo05ekfkHRIlYdivdIx5+/XwfKD2" ..
	"kIFwMVTTQdW1fhTuKOhQ4hFSFdU63ON5GOYHcssn+I46M6cTzeXfCSuo/KK30vbyquSN/VgQcx/xaA1dET6OJuKm5ocggiLRG8+Z" ..
	"JMBKxJkRv/rs9oBj6ujVbHlJGKIPo30uiqfG+H1lJemAwvfsx7WTpJZKJy6U9murs0etq7euy9sW1u6djg9vLYjfK9AY98GSmUm/" ..
	"opyKWL8VbTVJkv23deHyW2gTiiFwy7+YdE4pwEBmoGnPhIWdmzysIXfc77Im7gC4DR+VPD1blWeuciOv2+bSVJSo37gw00DWFEEv" ..
	"hBgYUzZDfm+a2G2HYcaKo1Vcq6GdkLLIAUtQBKUgGXUfAblgCQEgdPjoJ/1shbT5YEnzFCzj3kmIwHMbTHjgD+hylLMXszK1XJO+" ..
	"X3O1UZIIGjYZlkeYPhHIyxf7M4An8K/NlP6FN2V0uKuPiUPOLalPesPfwAfaPJpS/dAX/D2asVCAESmPf5cNl1NGtEjtnZ0QGYTy" ..
	"BdpXnaPQelMKJK58Q3OZOHa+FQJYFiW0rKY9jLyzXF0fj2aZw68DSVeLehhrK7ScakjD5k+oM79zAxCJmrcMY1yDljOOaUFwAk9r" ..
	"mmmAXsauJeB+iaiF1i2xCEtJNXx7+duWiuq4FwkXKt/XhXtv+WAt/AFRXhyPFLoL3eKem0+EMbpzmOD0I9YndDcQDNjH4rbAR7LV" ..
	"qNvYBZG5jGzdsF2O9dZzevl3AFFuZOTWT3sm3rpRTTTmKjaPt1zvXAbEW0vASBLjh5qsLeUZCViQuoGZ6Z9iIIQz49hCWCE5SFJW" ..
	"n2RPZS13/tivwwE1rRPlNcQfjrN42tsXn0qYG3mztPmvHYQRsdKCELI/SYgFDtbXh75YB0rNeRBc3DQSgbvWJQCxIX2baD0DUVO1" ..
	"d1DhFlrTGCw0qEm0PUK/5MJsaWrr45L7KbNOSXVXG9Dlj56QcYTKQ3nx758A/SwHGKGj9EDjPrxsUqs8S99pEv+HMEYzvwODJbjW" ..
	"mQh4FTRk648I9nqwoMGMJq4aGstnjlHH1W6isJ2NVrh7b6fchWq9RnX9r/l8ZtIQwtaHpXu3ODjznfNjklDwdbmYVGSOTJtIcuId" ..
	"limBacVYK0jglv0XedWqpPwXRFtap+GAY/iBg+2gBk48ipJY/zM09iC0oNn47kN5YQlngfwjMwAjmFr+C9XGyZ3mUr4HhXlgCHeF" ..
	"FuZ71fLarOXXv7FvLSLYmq6YERLSuIkz649y/YnDCemNVUOVfE+4RWoCJrXJyqFmycDIzWZzXaXiUDuRQKpxo02Ptxr12tYouf52" ..
	"LRN9CPInqJyjU+O5Rh/C18Ad9IYY0g964QLOF5fpkpE02IKVLM3gGIiJTjrXM/Z7hQ5MiQEs9ClEsTXIqgUGbiM97RTEwz32b8OR" ..
	"Qw2aoSgipUWNceuS129w3miTCozh9rACzbMhzTxxqcdoG3+yZ3oistNNjWuAzY3PsMFpPHXA/4pRR0WhAnzAV1JcMVypgeQHFCp2" ..
	"e1gSJDvbvCGMTsrsxiVfPt7P8YIhRGtdHYhxdb4Lz2ZcK9jUG1XShXraU5/lIeeIqH0MCYyragcRck2+S+mQtk/N/86jnj9hkr6r" ..
	"yeWfrCJ9m7W4ynuwy+V87Eb36ObBZBJEr37WguEVL5pvcTfFSsqKAOO1vRWsqmT55w8urJYKfWdemKb8R+T06ePPJm9gp5CWrkUi" ..
	"2XnL7pJDhwLRlrXyeRbP5oFQUSEUZuPcG4Q32LLV+cDsUmdzqLm4mUfNL6PKERfo2wtgaLAqLG8butt+1QshSd805dE24FH37USt" ..
	"JYHw3yf02mBJoUOYnHhS2PMD2Im7Gdysa1ti9DwPl1hL+dfTdwBWu9QfHK6BVLHeTrPH8OrqWiTlARzQwcPeGZ25rZUr8gHOIc04" ..
	"gx/5NJDT00pcsxjnkrZ+YntbZWCs8lf+pgRjIY6AFpeko0CF4IEToRduLEXRhBr6qEJ8wu6v7K9lNiH5yv4sEQiffZdHD/jVUa1L" ..
	"dhXARJ8L/ru7prmaFrhNCbZJOwPbPkvuWVZ0fh6WuF66AhGjD6mpgowkM9XCvPMoDfX8f9nCBGcvIIbf0hs79Mk4u1Tmji4fMyKm" ..
	""
local PAYLOAD_P5 =
	"nuh0SXdUl6g0Myd5le+fPQ4DSmFnriZSjAjVNyWj65cQ4If4vce69awiLXa43wsbnPal7kCsk+CXKaqXh9CAbOzvQRUNriIcVCPw" ..
	"kG8ojholAFoHdVXkm7plO4LMsvUZa4U6kfnZa93S1EDJE5RP8ax5HCHHrQylVTxce0IaD1AJFlvbQD4cHFQtc3VW5xeywo2r38ce" ..
	"xLx2+xkBk+JnZ8tKePDuvQm/N42tXaLpTot+VUs7YaDfnfHPAH2OQ8gcaeC+7DH5I4VxCcq5aDXKt7d2pjNrtBh8HmMygSwl2wZp" ..
	"g0q++qDJciYdQGvevaooVkTXNJQsNay6lTAuv86lxBzlBUBmbhdyp0RmM3LX+UAgOcIz4m3BwDeO4oqCv+tq9SM0I+sPyXbx0MS+" ..
	"ZwVcI1WV6dt72M44i3ywRTGd/GGP0Qkzqt5aU/dN8kriws/IhvZUrATC0GYoi8kv8zV6+GmiR0mxPYqXyKJXv+cCfD4AvBVYqlUv" ..
	"j0RalTT/DxQ2O8ap1G5hpInUMvb6vc8WgrMZEAzn9oEc18qcbZYr1D15OK8rNw9PtJ77HSxBjbej9VNmx2jlqlmNFnjDCO9Y78c5" ..
	"BQ7gTT+zieFNz5EMYRsW+IcoVyHVaOrtojp6wbhQVuY9BtmbDPsWVhApJJIsukhSNLZM5Hh1vPiIapNfbN3ehjhyPqnJwvtbuony" ..
	"U1azK/ImVvPeiqvisjB3IpNIi0Cn498cnn6rPVmUeZduhtDYbuOXZ0mQ4czfYiRx1Sh1EVS0dbbBu8+txVQ5tpYMlmHbN2ivwmTb" ..
	"KU2A2JyofJsZNgEzfA4jbdarAmpNGZC4y2TXdtBADkqvzNKAJcPqOZhplCj4i3LfXlZEHUsJkM4NtrHFMk321qdcTmfKhf7/I4vv" ..
	"khIb0iJ/3hqIrpwE4GwduIuHDLctR7NHq9e9XtMPV9Nr1ZNloaNYaGWSw4pNfhiGOFhxokSCBROZ5w+XPRmP7xrVELMN4sBiZ8Kw" ..
	"McS1+RcHMlyWJJgI+CR/uuoWSAedwFKyj4fiQhk4AQ+vHhR5zIo75lk8FzAPn+OGU5emVx/TwfiuJrYxjjgKvgi/CHH0CJu0UUDG" ..
	"RNW/o50RHi/8mZJAcbFVwqD/bVOWSKvlPxnUI9NA+ScnOIgVsR4v2h4aAdxO4h8njMx7H2663ih+FpOofs1C9ENpBPRoyZfEu+Qh" ..
	"1vcr0aerTONNNKadi51IU0u/1dJkJA5zOakYRgh6ZKgTmbFfXy5R3WDBWi5Rqf8GLe6qq+Atz/wDc8wKAtu7oD9XMW/PM4w/ES54" ..
	"CcqAqYsUC/LmMs3mQnIkytfdaYngKbaYe01xbibLR6hVTa+0gfH9ufLj0qFFZxyK0VuJzbHl2U3KI6H5RvhSmseNDLPtj93Zr7Lp" ..
	"dXhcXBC+40qDosFOqgRCzHhNnr7XqKKUbobK0Sm+wQLjpQKd5smB4Yp3UC3uDlxK0aP8BSBX8NetLpuO6+CX73Cty+KtkHasZCaZ" ..
	"ehLO5e21KGABICC5Z3potTRfzkKHRnGeBD9bBt9PzAKoxmAdz1al9HSbIL59B+Dq5wsw2xWQuuZwlIEjoqoRzJnpeUw6/Tqc+hJf" ..
	"kC4GqqN25T7bttKhHN4uWJkO/C2Dhv//2TfPrvtOYuEME7pwFCrROz/tZfzbIP2QDtZ/1/dSg5+4+hP3f3EXEhLp9ruqYcisksGt" ..
	"qdM/yCeOTpSnzSBKttWs2BhUZOo0Dlkt3MSei/2OoBBIuiWgX2/5EFxfwOAG6DwcmyGl33tQaTIRFMs0yL5Rbk5zH7zmLGk97knt" ..
	"Pvf2go+7udYSGWgGcZXzweOhDIw6IXH533ADfa2mvLS/9487rGqMNrht7TjScQBg+eYcY7/P1oYmMu/5Ei0QcjbvDw3wgnIaOIvH" ..
	"suT/j8K95CCsC+o1YnmhrmwsHdtLJjjrRAwU4Jx7d8ncEyxOS1oyRqQ91J+1/olHwbU2g+CdoDFQ8WN8vr2qLEkCXOo1TXdzk6Ck" ..
	"1VTz1UutWd0QxG5Aj75beuEoGUcoOz+WPoueOzNE4RsBJ/kv00YY7ZVl1O3InDeTuEcDvD3pipIsJlBkZjVccq/JISz/UnagqkfF" ..
	"T1OEnvIBsxTcSc+cH2TBgGDEjme4d+bB+OTzBIhbHm1Cmp3ImH6ziTYlbQKbWKFYIonW8UdBDJvekCEJQxEWeZYAd0I61rGPDt6G" ..
	"xYdqzC8xmg79Iz2GScct8jzxg1JWb0hp6i7eadVelYHzqMZ65vQcLTgWSdsJzZO+A4UM/P8YrveOuhChLGhOoxm/gu6o8R+lRRXl" ..
	"hbf6g3ZV1YKMsuuznYzCq73fY605N2N65zY+ZtJm8p+mFRzlRkNOlj/AjQY4bZSLTj9Ip4rwnMXkGqJeTakoO6CQw4xRrFaR8kIu" ..
	"IMGiJD3KSGQ9IpOG9LzRTARNEkhsq5zeuI2diZ490L8I3DEJWsZVPuhSVp8fnLM2Bglk+5VNSQXdAbwQ32P9m5nXC03/hfwiIhiQ" ..
	"0PzvIcXKHmEcDAoPSCeiFtHD6Vch3kUegzT//P8lEDrbTy5eDixdLLD+XX3Pvo+ftZlJOr0evCF7SHaSYYuoPFt2p4wT72hpatZV" ..
	"ehTgjOYhZNddKk79sOZmEkvcrwtqQYq/UU3VTI9I3eIqk3JI+48wIylNTR1hWJVo1QFZJHwRwk8WLFRoBnCXJsv/NOIA33gmXs4t" ..
	"SJZTBh02/zIBsra1DWfIXqkD5Kn++mFa5I8woCaECayChbenQARo7krsHDmeGWftRx/s11/95BegnZOjF/zck2PXQOUBkeOrpyzf" ..
	"/qY8FLa9iyvMlkuFx0TCZzdMdpfuhx1uEcP9VzHY3Xm1Z9Ihapxk8MJYBKg4KI2za26FcM1kM6z+aFNSjZgyv5gf8GyZGRGNuxsw" ..
	"MydySln5meSS5M6lWcTVWVoYgMtdFdsIW3aRDyjF/rfGY2sLT866zq6eLm+FKyhgkMzV5Ar5W+0QrtGizVeiqcf/OFqW8q+r/oqc" ..
	"tdfDrIq1GFzqSPzaj8fAzC02LiS3uBm8RoHdfD86yH6FqTjKLuKGGe4dw3R7GUpooXHp9yVapSMNvSTA1BBJwSROKPiHadetstLk" ..
	"/+Tk1iQMFyq79C3nX7XA8qigp5lH74+ZJZBDqWJfpFkGt+jhpGmDYNUZ/DHmy7XTWFII2G9TT78w5E02zYouEDMifLMlb9TTFya7" ..
	"9k2H9qoF9f/qGVkA9Yovr0aPEkuya4VM+nIEs+fwBL+fGuh0QIhARWzcyy2l3SfpOON6v7uQEg/F9L489CnyUsn60m46RfF0THNl" ..
	"u2zK2fRc2yQxbNcfwnntcwvK8ADbLZb6nAApr29pZR9mc5NCA4J4tr5Y60iPxXRzuGaTOM4LycOjVeOQyorRES4tSFV5ICY33ULx" ..
	"/m/3KJvnPeIOIkzIhtgpxcwxmMNaX/3cHTDaoXEUOEINCEkoTQOdQhqX1W4zC8aub++KMLwJkH6XRiDCJpmZGKm6uFsTccKsi+6V" ..
	"iGRAPLRaZPbf0PkCxT3rxbgCl6REf2OZ4AstUsYXGQ4JGUaWW0JnTWwlmdFsSwimHlv/bJNl+P3vfcdPWhBXAI6BDyqVGqOqn7gD" ..
	"bySDW4nnncn3WOWruG/ieBMBwGkndEnVI3dI/W04yCS2vwqMLmgDRDhrprl0QZhY1qas9Nt9QGkQ3VGbqzvmFhUywB18x8w2mW7j" ..
	"RZWnOw7rfEaEvZoW4KcGwq1ov6V+Jv2rgCNcVWSmALwJoFE+kYhVbBA5ViPn7gqgfEDtOCPGFnVD6aXkuzygT808lOf6zW46ZjNT" ..
	"kZp6fY4FeW7QGKJEJslABiTfNIxxFpEEXCs5WITsY0KHTQ80kiMVudpqXjZf15OTOuSR5eOUg9oMR7UKgcXn0CfY1TPEI7sTJLqS" ..
	"osIsaIIQzRVGB0yKo/+k/0RUDr0aEjSiDxRC+VTkSCSzr9gGHl2aaD8Jm+qbWkuIRSRPGfTwRvuKNleWXn2hZ+6q0neicVund0D6" ..
	"ppP8bQAW+Bxq7otuSA1Ep8AVYmmZmb8QUtyLMOPAQVNt8tcjyQlE03hGBWXfAZg6tGNBO6alNSKViuHHG2xXw5vrIRc26c6yDImd" ..
	"pccDmz3M/uKILTNxoGKSG7V0iDH6kHL4tJZprx8rwY8pEdKwt2peFOS9NQ0oemQrx6/EYrqsULqjWrFwqgf/VqJzmlvteuiv05pN" ..
	"cbA47gVs20RNhrWlbwevSF1oJtFA1i8NLiYKu2vuI1r0Toyx8vntCZGoP6dxTZ9mTQ1HEd3W2qq0VDgFG9iyS1WC9qWEiJr17Y6P" ..
	"YAw7jUH0JfyWmfSatZnCRnfUFH238dwvL70WJZ4EtLairwbM+1l0QleF5GEB2J8kr5dPVYdiJcLQpsm7G0q8T6krPEwiMU5KR0hz" ..
	"Dns9Ze+0bc6cAwo8FxC0l/8vlai/V0p2vs2SXU9WMIT6TSLeque4mjcir60Kpf/+Ec4IDiP5f4AUzub3lFbwtHlxCVlNXZLEiztc" ..
	"qPDOePLrrtHXSQ6RySaoArYWvaKyiQmmyVX1URepeL7KnUBWa2L0xuax3mtrLsSIrqom5PJAtuwVpGZ9rGmO9gJ4p/2dJba76NLZ" ..
	"fXVJwfBWxiZhzlB1sZKQ0ohipvmmXm7fR/hIGJd7eMW7tVEWYLsNIG7Upe+QD6jhkTEdnI5pIfPKfHvwhqtRbyVjvbctqW9ovKv1" ..
	"OoIg5NEnNkyYruyn+VOedl5MvID7dDniiD2EB/pDpjPw89bYH/rM5PnTzGYzTQZf0IFCJJyeCbC1HKFeUXkKhmdZkKUE5G7fEHVm" ..
	"a+1A7GuWjw+XI8rCqZ6KDJyF7Lw8HOiIpzzKTC9xQAHNCc/bshjTmnR2eAtyuMfwiWihlYcf7v8XUDqM3CWWKKP2G9FlioszokaI" ..
	"KfIW2NM1+qln+kenob4FDy87l/59mEPrE68yE1g7bzvK7HIlzWXtCx7JHcXzJaZu9Rv/rnVt7APkU9VGmIZL4xLvGvmNK0igdR2n" ..
	"OKiTG65L2CKshYTXf504wyeEWQlYzivs8tuwGIo8din5JEOV9vvXL11yXyyyoDRnDUIBnjgLwvFp0/Od46IAx5xznUUXc0wvt9gz" ..
	"azJSI50W9hrInMSc07Ij6cgx2P+WoJVG8NF8y5TYJD32V63B3Ut4LhqdKnxtmk98DSlSgoH9NIiewlUAk1v+rInz8FPnq+zuy+0E" ..
	"dYMUg4a9isZk/uGj9b+ANcjTripz4kpe9qiLrgOQPTJDGkKk2wb3UQlBOY0kA8yxYLZ+8iSkOafut4lGXYIyv3bssfgx544nAfDC" ..
	"FOMrl+Vya95el6NV4xM5aiH1jvrrlykFmS8KdToRza9p/Ss9PLVOwusmyVkZD+BgI/HVgR+vi77piDDuDrXF4JTGUkVBmJNSUQcP" ..
	"ESLXcS5tBsXI5jDfvuGGSrEc33UPoIJUz8q1a73E+pFylmAUOBeCoJeHwsU4K6HSPKymM3LAG3U/lEvxKMeLwaILYG9skZN4GG07" ..
	"7u15Bm+QUxvKrXqnKFZVx0nwgmJ6stj5kNWktHv5gkOWHQ21IvPQdjxq6JZ/d/GNeVQKvHKu78FP0G9g13LCPgs0OP3wPcuzkKwC" ..
	"UpZb6SNNSaH4rVsh/E2GEuzRqnae1thuc2agl3Ifo6csSnRIuwXazR5q/W68c+d7ATQQyChTEOleTJpAABMzt29qvdvfey/GaTbR" ..
	"U8s/Z5AIorG8SkNIBk1HK1yie0ACbW03hmy+cIKyOVS8eP0cqFV/go4xx8jInEkaj1kVF5qo/lrIMveoGiWqeBZ0bflrCuJrfcns" ..
	"3+CZcN3E9KZhTkKZ3HSFQQhuEpEN9NYgStdBLLNBxQL+prrhpBUNLmc8Ys7KF6e2q7mIxHu00jbZwujYYveEWXEXAk4zXuLhwp7q" ..
	"QMJmO41Ehlov5VFKRkYYBsKZFcXlKsM2tV0nxEUFbUb2vo1lI0BFjmNTPd+ETSciLtmwIZsf/6jGZ/fJrj8GiAP1FawFD2l3TBZX" ..
	""
local PAYLOAD_P6 =
	"OTL1VL4zwKV8yEPD0q4WTiheeg70SZ1M+cEJKZOKc2Cg7w6ero2SFBU+PFcR1FggS5nFPKfWUTZnZ+2dccZz6CFpuJQErJJkPhXs" ..
	"/l9OxzYakc+UmptmppWQP/pmm6KTtZ3I9d16sTFmCXlIJMCD5LhDRgqpayBx2+Chp60PusC1bOfMQZ+OrJgfy6napPAurJPM03nK" ..
	"m6JQeDlf5DlKkYjw3uqgBWVwBuiItG8DIxbFkLHOyJ6c2FEQL+B48JlfmnDyTqbSJwysVV0BBEryAwBW5PvwgF/u7OWqq/fcJWk/" ..
	"Yi+r206WFCa+L9uT3CiXkroggGZvHhUBKMDYIG2PQPzteEDJ/cVJm4Y9tF9xMsO6YAYckwXdU/tKayIQVzgLhaK7RfKtRuA3mxOk" ..
	"Znt3M21ecZfgty8YtJ3e2oKPz+udvddzwYIQj7jQRsgnSY9d1UH2mxasM05g2AxUIIMijlEwL9rT035eE7/hViQdT1wiaVoUb7SM" ..
	"Ywi2PtdRL5h7LtUkGI7PpQGb2HUNRTq+NXyG/xYo/edLU4LwkcxyBZ9qFQ+qruzfCXL6A7H1Aj3YAtZU3P5lp6vbkQWxsSOSqwRU" ..
	"IpQheFbj2e5AoAUw++JXY/wducXwvsexkatuMG0SxQg+ig+I79FIRxSt4qPIDTmdnffKgI6DdraALh+DQATF2DV29BcdktdtdM7y" ..
	"Wn/I/vQ8wG0qxOetUQcc9/IXPPBbLkjOrEDqph+Tc1KEsopahG7Nl8aKPGURbji4C2esmSFnKHBZuHH3rEoJBxVajRPtz7CwhjAa" ..
	"riqCDleSx7zLeF9rlfJoPG/vyCmVYIKX3laIabLImqC0FXrA3HGeZaBsglEFH0PdRCX61QEYfawOp+aImfmVLrD/uYGMlxNxx15C" ..
	"ts6jiMCV3iTRqcGcvvCUvWPMXF8Sy/V9Y2BTeRAxsqeXsRFamjR7uRbKt+FhTGQ+iB4rjmdfnh9DSZjT/kuqiKxbagtGa20Pfvbe" ..
	"NoGI1jI3yT9zZneEZO+HIBSvv3U7Wwkj3LglqpAXYPgQNMoxP1Jwt7Vat5bt5zIRsMYGutV0DWg84E/U2iUx4auM+clERH9tnyfh" ..
	"x98dqDVn0x1CZAvLohVrIZU80VB7pPglyaVv9XjEkZ9zllxYwDlRC2/WnsQOvY1+1SeumHAnNDL9WiIpzqMSdFrZ7vR3K7IM+LJl" ..
	"m5qcRest7IAWGiIMBoyX5swra5YA/9NJU39klLqPy0UthshU8MxakfO5RKHdFe7Bjs6rYlfFUHZOUFpTIm11TyxkQIzjxZjP27nB" ..
	"bJZxOHgw5Rnte3tjXdQdDQHVA6pHEdm45A/kw8/uPK+x37xluPmXalVXchxL5egCNu7f06GKz68rQyuYesXmU1gH/nquC8omDrIx" ..
	"evAkno5q/3YggGSKiinJfgJcDITrRJDREjj+RRjTIJKVTJYyKLfwRvw86ka79Z7OKJGlyML5gRNvl6PNoJ8ZJDXUoypxV9jPKevE" ..
	"5kALUaLr+00OUClINh3CbWyhvZ+teGwB8FkH5OqCZAwDXeARDSbe7Mycsh1DXW806QU8pm/4rfAD4ajIdDi0VsymtoNBfjoSdbFU" ..
	"xM+QhOmBHzB8trK7eHp/5VfwgeWTkK3ngVyx+BrMPdMIQhWKNTG/4n1CFU4LTaW3oAoMq2Xu9/7l6jpX5Xl3G6JA+5VUZwSk1AWg" ..
	"3xHQDwi/Ik5bdPU+yoOVyt9tjPuaFwkzNRzqEysHeS5kLW2qfZV5oh3ZpU/KULZr8fMrlDQCJThDDJf/yqyDjRM9mkoob8fXMQ4u" ..
	"SAAXvJBmzNj8+E/mMsZhhOm0EWYp52ik7GU0FSUzIHD2Xnh8/avcxssVc6QufyfJtlVpw2bCxEMHqB6RcADsTK8UPmXFwrA8Vp/H" ..
	"d3eS4bgWeIPV5dnVxP8ts9nHamg1pN/txLcEaOF3K/tgEggnH9F+NVKmY+mmAbir5hlk3nNbPLZh9tvEfNEn7yPKONTR8XgbBFs3" ..
	"yz06Som9ZfrVK446HUzbB9hvVdysJEI45IkabFFCWkUWjhoLuHi0KJ3Z1G2rL+yUPUokBR/pe/oInLT640jRCv5P+gO0cAzu58yC" ..
	"8T/e7hg+zgBjhyrfTC9euVWqovGnnFdAKDWxD7vplte5gHV3mD/C8VOet8pjJ1ndXVVWFhyeyDulGOXuOWQF8ctwuD32PS5nzIEY" ..
	"HduQmUoM3VqzIbT0aG5H2SJLjqUZCY4vkYhwqAN6Y+NkEZNYB+vtHSRMV//KmXaY9FWK3fMdMUSbOlGoGilAvfKCnXM+rRdAlR2K" ..
	"E0PfuOrGGw3re9A1Qj1k2Pigwjfx8guP8DhQEkd32bicE/P2PkG/stT8q96xKwjDneUMHppqKhsZ/cLdSL9U6U7GPI8dMtG5J7Yn" ..
	"kCfPxC3q74ZnzLZCIDxvFW70GMePsjnBNsPKnNL1bWCvtAtcpxqMH70xetBVtgGq2RLTkoXLWwkFNwUdv0MSC9G/fPX94E12MLCX" ..
	"fAf9+2iSgM5RdPXLan/W/7oywCz0lTVOW7RRS8xMBp+TI38AfKEbfS6stwQuq4bEb8SPw+T87mqq99XYr1v1HIT5vaMZaY56tE6p" ..
	"qYLf8EhNP8eeQvPLkO2cGk4LJ/ncekBQ4h9C0u/5aVroteG/r1yYXQgvPe1CWLHhD46fH/IatUBknaKnCyEUA+HH59wvAnZ0EW8h" ..
	"BaXbarvxo8qSQzKYDIsxCEqUJpXmhxeybaapmOnLilb1kQU/WZj/4FtNUI/5oD2vFhAl/HT4VMf6yWz09+AdptWQQThhMVza+jvS" ..
	"KKDYPmui28cqamUqYV2WdS6zrBjz0TNUEiePYY1imX6YYurwho40c3254JzjBCZFsZKWRFVoXXiHGWXBkVlAR0vjVkNi5aYn+4jM" ..
	"nHbkYRnfmUGXA9NxBq84XheJDAUbxZP56hBriB8WZ4t44J232I5va+32QGJzfU+lmMBjZ5ydjWO2k6dnmE39v9FqZhAcgERNhcOj" ..
	"XIhQaPqk6dMA9XlYslyJpEswH1RIujoDNpS+wD6eV9t8QE0ie2DjXS9BmYNPYrxW/nXtFdf71koXLGI5B2bbLkNT02QHbMD2ZKnR" ..
	"JhdikqBAN4t0zeSo0PPsaFVhkuyz1/HEPhA/kXWV8gmpRb4UZcdJO8PmhV4mwJXMiMzKH8apNL6vUyWSjT8URfybuDFz39lVxEsb" ..
	"FltguvFHvZRYS1b/4rO/kh9gCma7ouHhHeQtFdyLxZdWlkeFqDk4u/zl1C5LuLnYBiVKh0hpFBPlinzcUwPANnvX+HQgZ2peqNZE" ..
	"3DydlKWMB3h6+ckuXnLrathcRlsuKApMxA3gsJ2jTwfMyCsdMe2ecFRUj0TMa7YyGrM5lRHGQM1RxnkifBETq4FYh6r+6WbALw/D" ..
	"dftOLb/fFrO3o3pDBVKKa4MWBCPXZtPqndKRB/TfG9Rp3TbwWSLqt2hQPY4we2A3wyrw18iuKywfsiwrsDb0kat2+SDfIUgt7J1e" ..
	"CYSCc99AAC9oorrKHR/hsPhuAWY4UGbPWgOXK5+KLtyplCEzNXQIbcB1jX9kH0sgvxSTVTOPgBWRvUxqz6AFLjLJECl2DTA0xFvX" ..
	"oRlTL0OoyBwkI7k5FkVeE9nZXELWpIPzUnuTce38B9Cu4PNXq+S5IwhZLXzMBn5/oMieNx/l/x3Au6EI6XjWt/mw7WFf/1PLvOpV" ..
	"mAKl3QtDWBa+H7obvPdJqgpyankHlidmXP3LRphwEh2+297xOUvh3iSGxTD4iIlWG5mFIhECbK/IysQiflDGHGlXnLAitW610EBm" ..
	"SS+/V1moPEkY/v+Ptax+tQssbILpMIDKuMOiNtvDfornhSaF7DhBfEizCzdZBcU+lzy6iZgkQQUyLoz/gAAvKdXNUiwZNMsB4mSo" ..
	"skyBypubFxCWIwwxSt69rBB5RV2VRFclqhEpyobhQTw4S6ZWdhoEKri2C+NTLZsC7s0whPW2IXvxemoZYKKoJAB8POGAmurDGOFP" ..
	"1OEoLna25z/ZHt0T3yhSlUwuaqt2DHM3CE4f+sjX8KN1uBQdBZWSsPBG5zjEKgNyR3h74x+08ooUwCHoyfdnSuaDkp8IpDGAgoOH" ..
	"1XobU7NaglcG/LSi4b6S6YFH5oC/mvzJ5rj9NOq4KZCP/SArtSP6txrISa7lcXVsaJ+ZfjMraEejSAd5vlKq4PL5nSDs1IepzC77" ..
	"HyNrJhCZh0GDArbOrFMJjhesjYTSH2bvkIUNfVbkFuBEsYUhhaxFPaVF6vSKH6pCR09CSHWmV8mbXG7vjRF9M23T+Qb0w8k4kQlu" ..
	"eQNo+9Qpp3SNZ+daavCn9opJPSXwXw3JxeEIrc59Resmd2sKdtfdUXzkmxEVRK9uOT4HPEJwh8EQTF9POEY6w/QuYpSmZ3eS+0sh" ..
	"ISmvhqEux02ipCib2XnvEi4MHRTZZqsf5w9FFgh/CaUUX7JDvY9kUbQAQa8tnFPkkyuoa1VAHrWPm1cTYRnRZ3+qv91imUZI+qR7" ..
	"ueQwE3DJAbLmtGhOe0u/gHlKmdNXBKoY+sUNHegp/olTYepZmiqEmpJjLhC1TGeIOA72TEiJZ+f7F83OkmxTkQh1I5643wd104sv" ..
	"ixLNT5VtIix59AjerAd1t7TFvLHYwLiD3B12+s6xC6FqzaTQ2EnHQB4o4GjkxiUb/bKxYJ5x5JpRx6HqfLw7DHwnU7Xg84gChYzJ" ..
	"6eq+UJdh33vikRDSiidxOboihC+mMuBBB0SkPnkiuJlJdtI4lI2W/MvjAjq8HE0zHIU+xmcLuTwzUD3NnaxDiQnDq94BLUpOQySp" ..
	"XerT3HVjUs3OMHs3teECjKxuyfAjAii3UK5fUQH8uVG+JIMIt8w3LReqvySr8EVoGK1/oSkBA8b982eM4pxJTANmfNSBleGTLjq3" ..
	"RPcQB1kSXorZj06Ha68ia2OJm7iUtFiMMjzeJjfnvyZIGf11WTgGhNI+wsdvW5g7nDd0RLf7rb99kiY9JhOsE3XCwBWrBUymwHmz" ..
	"u+N6+0k3oE0l92WW8NhGuD73Dx4Fg63n6udGMGfQVTKIzyj+TMCepfl1KcsHE85xvfuenO3+8f7vVDZ2uBJxVlYTbhLo6IX3ZtbF" ..
	"w/tTtzX8r8O/8VXq0fAb39VdTzXj45s2nXPZwmY/DkY+w1zYYSBgHACT7Z/yOuPSGCwQ6hTcZWVBJYDaP53QNYyA40/DVOeGVG3u" ..
	"lTNww0YokjV7kcEgmxyEMvXcwh/fE6tHV6irCvHaWWjU9ljYEtzB8JCWht9NDrEZdlWY7P4SWFkcL41l4G+OLMlxHADPGOf8dOUw" ..
	"TmghK6YIFtrp14wquhj+Grl77HysHzRGqF4orBBHGZEAo/miIeVrSZI78E/YBBUhcm94FLAIIToFn/oGkUu2E9zo0eBoEzrCPNxY" ..
	"M7aHArv4BV/RMWaLygL45RzUK7vBZG+pwanw4NagVC+qOdDnypZJl7e3ZwnKkVqEgnDTKsBTIpfNTHTMfhD7ELrsp+GTJ3LM168I" ..
	"qBF6ZSVC2hnYXP2ml0IrsyGKga6Xp80xQZiBnqivN9wO7cYGeyg3L19A8QBA3m3MnXCQ/hWWdSqxqelIdxDFnleubpnQDfpFf/Ed" ..
	"5efhz+W6gCX17xcFrpJr2daMFlyvfEvxcVCzVL5NoXhI8oN/Dc2uC6B5CIpluvkHAyAHaHaoOmaqEiDgQTLvFanTHp0fa8s7KLJi" ..
	"J6PVXJNPpayL26SFkxJnpMDRG+78NS/H68c5zu7avJJvZ9tli36rZx1Dn+590YkQdpfxl8wk3g6ztqodJZ1seFxE0LSuB77I0HXY" ..
	"FhZ6rP0dj1b/FGfwJX5zrEe3QqwD3ovKqEcPzEZZAXSrTJ0LCa4ZB7st5ezZmtrHwJsMcvBs88n2/tzV/0OS0PO/MjQ3xA4r8Nkj" ..
	"2uI8mYmXHbjmnHX3vFUZc4gaJlRBhJXeMXGtrLCFo7jNgV0tacK6tsbVZaXmpDjsTjE5Q762YYA4eldu8trxsCrKm5zVYVJPEGZT" ..
	""
local PAYLOAD_P7 =
	"P0gvMCo5r6sNZlufHjQToQf8aX76Gqf1X80KzZFNxURbBbJQ4JJmjim7NEstuRBQPLJ/IbyyTdp+aGwgop3sfy7njcwOx55zMbjn" ..
	"5ByVhwTLXXzayFb6i73JvlxlGD1q13XdEYgKFBrCP+GXDc6bFrzui7VK5LL4TpZM5af0Tr5PebjguGwKmaPrMRCE94Ky8DvTrlmX" ..
	"3KIjEegnd80uvESM8Oa7tNReYS0W9cgf59VzZQUXPijKFgSIGJiv2+Wdj5Lk+vuoiUYA4QDhsi9KNZzf76dAHqvdI8TXRxFC9RFF" ..
	"vqPTEvTlNIiXPt+8qXZECZ3QsYCAneuiI8A3uGYcnZRL/XTxWOQMCyVZyQaEQfQsEb+rNcW5OEUy5ZbEaddNOIzPmgBYlwI0KAMY" ..
	"SSRKOtQm5PJaoAfO75I00ctCPqUZt871TVBvXgDF5PqTZyzzOhvmuaaa89QQGs1y/axxNz90hxRqAktQqvwvnY96lV4I9v4LbZvt" ..
	"MPr9S/OMR6941bpm84rp43aKXc9QpTPm3vNH9c9VSG4ZafNfREPg5jcSQzY2IvDdCGNqii5/G6RbffzBZNh0uKjBWtxn2n0CQEyZ" ..
	"hFyxPGQVyeqmSG9xWNIpMSk8EV1BYp6zDJ+0f9vrNqgLEjlOKXAwcfEwbsTQRy/f885B66Ohm7NgrOOblnuiN5EZiSPyh0mPCz13" ..
	"Xl/9t3Dcp8Xxj7n4iczcV4ToHDsW4JZtybZLG/+l8FHzguz+CXzpPLbDdF7jQ1JWn6XmQ0/1VGyZbc4vQRUShDG7iyg9hpSsjXSu" ..
	"tJvJhMfHRFFUjQ1E5x24jyrsNrI+1vfl0+CS0ty0cdlNpsGKnPKBWBbjLiPtdsT1fQ+euYg4AiZQnOiOaTuNV3fjJMZwf+nWZjSq" ..
	"jJXGcCRnsjSH65m8I1g6icW9LV1l1e12WuihY8DTxi47f5Z4BibZcu1WLrsqc8SBpUfpuJ9IJQnU2aPJa9C8JwPhVJMmwdO2a6aE" ..
	"FQh9wDI0NhkwKcpOz/NBDqzaUlJTSisXmmNd0+sSjR64ag4B9MaukaBOOwB71TcWJ7bzcDEwixf8xO+JQ+AL8mu/5GEPrOYPdxvm" ..
	"qABjME84Abq5RyCrPHjSX3yY2xf5KNGoDRByIoOUlgNWjEDcB4/oSGu9ywHjYjmaQV9k0pMfo6/pTUcOFHcgz3t4ychMegk6BtDQ" ..
	"bQdVjS9zTDBsDqYm0doE2afEUHwTwGiz1lADnMjneUf+LEsaxDgIZZg+R2fkBlxWaXIO0CIklLpVK6iy6EvMRw8lOJELRnh/Vcw8" ..
	"qjOJm1KGty453C5l4Wv6H/Vaxlq5MEjTofaqZkxBbsNN+36gX9XsAHCkeijLJ1/aEChHByrNrtm8s5QiO3hCIlhpydLSUyXVJYJi" ..
	"b7Qf7Wq06Wo+i70a3WHd34ZA8qMr4zZb6VW4l3fVbZKwh54Lp5atx2uZ3WDtYA1IPMiispCqHfSsih4TddNIVEbDZzIAWMk9fIGa" ..
	"cZxyTEtWzx41elxpUhupZgEqVFv/ghSe5F/18r8f/uxNpKkGy4GQ9olerLU5Zbx+ML+LFK4OHwypo2y8o5jp8Ki28Df8G5WOgBsY" ..
	"4JCyG54QDys0CAsQRQ0fDi3vjHSFkqe7jwfv0tW4kMXgvmyrV4YZXLMBQkurpEKDTdnyNwm6SvsyAbSjpSFtO+jpYDccfH6nEyKS" ..
	"SIQCEsUk4T55lJoSOLvbxX8SR5CYnugnkA5GB2TN10nAeomNVULGEWuJU4Ex4yi8pu4UIBzlrf24VBc8IcPc+SStSfHHCZn2dnTC" ..
	"6LKfv2aheQZgF8AXTMuV1rCgqABdnpq2Rhv30sQ7kNFvkAE7HozIovTLR+GyzfoYVi5EI0TQOaoMvOR45EcC+C3MWSZQR14iakrm" ..
	"zJoq9C6r5f2mqy4HBU9ZGN0jJcG7/1SUCtJg5mKd7DIBWQ62UaMKpcy3JHUP7G9I685u4trVe+AjKyoJcAxutPiylAFWGtAjgiiy" ..
	"ayQTR1hUNp2aUAO4ka1wXXl1U2hmGuyXU0ta2jWQntF8Vz+Y38aNTtBdBBnHI/uJzv+LSouPWUMwVDoveaOdY7/SvJskwdkgxNlt" ..
	"MihSKk4fsRcWh3A0F0V8JlSrWsYsTJRQp5kTcpcs68fAwYC2NdQ/zfiQxMX9+NMNy53ReYIpZ0XDuSGVUgTK02tKoMVTtlUJV/8V" ..
	"jB9jMXquuyCkEbdIw+f0MpXkPs8z1hHaeIVlnBVMJkMpq6C6r7KSJEq0nmvUsNRjhLgttMm1SBDS+Aed43tQz4xOZaeZYP6g0HJa" ..
	"OKgdIbOuJP6GsInwb3XM2IDtLIxdjllrPhbODHtbIGVxvW+JM8/ta0XAj8/DMZ4KBZQca52qMzJ4UHPGuygyG29hVQlmf4HwcKbA" ..
	"TM45rPEUAbuNEFRyW9d1Lk9L5fqFKY75YQXeR1l2DVfBC8WNaP/qFAGJj+PYkIbAR4XEP4R29ycWQtZLFzfheUeB9LpLOdTGC7cv" ..
	"16/958yPsescv7lCEjQHSpGfoCxBOKFmrciwMkyPBxjKJS1yA6NiP4bwtddCGEW8SjkhqsHxCax0fju1aeoAPGaHG3s43Ip6LthY" ..
	"mGHzeQAm1XhsnBGYBpFQwn16/47NPqZgQHJJMCCKqZ9HQIqRTWAIdOCpre6d2zUDDvlPiqqcKCH3NQ09/N7GaL1h9q6eRI+0oXhY" ..
	"xvxmxoIRiSZDsPBe07SEQDixgUJs+lEcTrU04UmOSCrHNFoY7AqntOIgHJwTmJdlrceg/37c1k2hm2JqGnvrRqhq+emAqxQVuUhl" ..
	"D7EfpZ2dQtx0SG3GNhbwnOfNsK+R9j9L7WmKpIqxD9zYa5vtbiE4lrC8PsjPWRZik6Q0uxAIdCL5PjmaliLZi99+vutQkQK6RZR9" ..
	"B2FAeBqiBZnPcj4yHMqDgFo0WNex9/3vLB5jm6F6WZT8Mm00jGSrN3dbEEtR5SVaiexXBjBieq4pSDpRA9lPJ7mUwUTv4CxMrEAm" ..
	"u5JmqP6CehmKBSosy9itLRlDL9LtcjtjpNHq3ZApbBJ4u7NDguB5YlU3kUkuMd1oojCi5RusFWfbcxYwea0Yh2dGcZAiD2aeFv9v" ..
	"cyZuVlLJTndgXnaRDK81CErj5VlgzdhJESgfkJztZ2KJrwdwQrtr4dIEqfUAPj8cmYhUl0/3om1GBNssHkoQyQyA3dRpsnvxXPBd" ..
	"QQakBEvaTTqoFwTkAgBGPRV4SQ3jBJBdjoCNHxvrucOUIdXDvYBtC6ks1mGuyBeNP/Xx/NytPi/5y/HIYwgzbbACGrQmPWZ/04fU" ..
	"0hU6+bREC/vDqHxH8TLbRoZ/xLTNm5SX1N42lyoL2uTMjNCoab6YnCVl8u8FcnjF8YXS0iywcTO3W3/V9bmQK901JY/gce0iPrhF" ..
	"TG6/F08Do7NnHanmSZH/YzjW6eCpUb/Q/oDaGxPQC1t+D+g0XIUGVdLqv0DOHI/wDb/VzNyOt9oAC0GCRD2u3QSFOyN3Z0X8Vl/A" ..
	"VpJKsR4UyBq2CM87mbnVRP7arL4mWIQu6hLrGR24d1y1Uvhmb59N0k04iXvtkj5zFq2rb75tQg0LNxHC1dc3k0MBR3aCMuNhuzTg" ..
	"wUvdOxuI2yR+rWyU17wTljtTnKHXmcoio+QVRbizovwHzEzs2UekRSzGjUQtjeJL/Fyr1JE08HbwuWNgZXYGuhnCSlxxdhvd0eYo" ..
	"gMmPCgK3hkz0dqYFULy39KkRdmtpRr5D8aKWTDrSO8Vc+C1MqE6VD1ViZy5TcQCkCl1rLsMK5jPNVzzrtbx7cIowTPDqo4sRX6Bu" ..
	"YYIs8ykY3IVCcd+oM1wjgOEOoCQx2Yyhmj10kjsExgsuJvRnChx/LpkHrBVWbXuBPWCNYgLz2Zfer2Hk0hhlkWYz0MGkcj1mMZYB" ..
	"HjuvKuNnSzGe53rtNrCFiDr6IjEYjC1V+uG9D9EHHoWNekSpFTe/qV76IbiF15OCBGPGCHCqExxPcCs3/9TC63V3hba5YYTBnbxf" ..
	"ebbmTYVRrp0x9gNZdtvXXsxTqI/RTMKE+480e0QANqaQDNsvFZq0raJHiqMtowtvZkaaKUHXXe+ZXuSdCh2452zRGdIabDiloIg9" ..
	"ZumD0SHq/EwqZnRzx7uK30wMVR9c5JSwaQRFApjdgWaDnX3hAU2NN7DiRz7QAcDkCNvi2xbNulcPSSrnaT6LGb4SH32FEgmQEzX0" ..
	"9AUHaSGv4bRQQmDlFsSXHUTTuujUlJUXIwg2QTnG0mEqJTrbrgCnBVfAnJciWT6pGh5ZhJ/NtcLtcGoh1YpfBSpoboaKM3VxbGOr" ..
	"dALfkWrMs+f+ix4zje+N1YAiCTHy7dHTOH2RUH0Q74kdLNCHBwuBCdy6rADIg2+veTAm8faJ8l4FJojjJR+PhjUHLGGRXNWtU7n5" ..
	"IUoGJF0gAE8B9EJXxp3DJ1zIwZdWpsxCXJIQkSgIJid4MiZxZgtylcbF4SodXOqbUI/9SvtmnfD82z6UOiEI1X1C1xyDfHHdgnjR" ..
	"cKtpIjSWmRfQkNkE89bDpA5+0tUxNJweGU9qpm8UCqo54USS86qgvNtGaqJysoCHFBjNPvAC337DObWr8c2CKJVL2EzeOR07fpAx" ..
	"QPE+JghEGtLB2MzOm4l3chPq7BRN4y2TD6RKKQaV/ggtW9J56xTq3ifUtn/PKgcGR6U54wWSi5DnmX5btIsrCx1h1xupczJdRxHT" ..
	"r85ZDfkzXkuofL/t5yPK7QOZYhb/yeE4Cc1PHpXoDaqopaWg8olbtePDiJrycyfIZtW/Nra6hdHJYVOlN5HBnIKFFGd+sZ3cc3mN" ..
	"2fq968x3A3eP1Lpb8BF6BA3JTJYiQBXfPJK5/5EOwFwQH7GBCTNKrAzwQkoXQBALCtubGCLW6OP9JJunrxQAMzKTERkuoMlgLe4s" ..
	"zAHiMMLt41oq4sQbVPHAZCg6DyWZD1xiJ7O0Qlzh6dWNQaQr1XeiUlgpcWlq43bQ6w/Y60x1M5D4VXZKDeCHoL8WIbEA4i/kVEwI" ..
	"X/D983HuqSyKHMyK+PrM0UT2Jcr649Z89plFTVgJTqbWmQL0pTOkO7x8jDXfIVLlnAMflm/4keyy+8hUT6FDPDkutcu/gXQkShWB" ..
	"Mhq4SsuhZF7cwAESRKkGGNVTVar20NsomYp0ege2Oux1orqrvy0ZZkznO2owAguCHw8m/5hgNwq1s8YBbdm7wiNNmw4puo6c8nQU" ..
	"UWVrB4GdkGejQwpKDCH9jS3SjxoPTHDO4nMzOvlKRe2VUsoRZxY5ZO3N8UujGjkHL+iLkqTRonkwyHTraNUnSOIw9MZ/PYhnDQSv" ..
	"wgC+gPY52p4k/Nbh5GhIDrWiEmicHSmHpxC2M41puV+URiH6LaFIjh4kxvha5fEsNCfTh+44lswRgga8PH28GDG1SSrJShPCpDiS" ..
	"jitkrUZ4zEJZK3n+l9Kg7XF9AlH6UnOYVfF3DIaZY0lgrii28LCO6465mQ8Izg02pxa34Ovc9yzJLml1ietsi9kVsakNxnHubtGs" ..
	"rs3Wli9e9AaZhpdPhPB4p+gIGZDD5PO2PT1e+wSOO3epRiW8LnK/yZvtnpb0nvaLxQyDSuUGU8bWpYQIDL01fvQ2qcVt6RgwJfHv" ..
	"Xq7v7lKvHr26zrztkvtjkSlfF8K+6c2I0X9oXH43N/Ffq0kU1IwXjJkd0qjdZJ8aReh8gB9yJFTYAhtORH/AFO2rLnM+py11+MW1" ..
	"EmsGl+mcL6fJrEj5x3lW7fcw9G1brSs6+K3ZbM8YnaVjxRss5fAfYv0QenOSWoVs9m56J022CbFDAfS3Yr7ls0nTqiRx7+zMDiIq" ..
	"NIzuhN42tfFHVFo3U7zXyQjiaVBV8W85IycgpfHo6/a5fbbBkv4CmsHX9HE++PhsUpF6S9DCU17e4qXTF5HeZsXS4FJm0zkBqQlO" ..
	"MMrsox/Oi/R4Lcy5WfvILgVFc2pIwsx4e2NKIGnVaeVLd7aSvQmUDbXTdCpruHUZBybWmmxMdr9O+o0EmfRh+hxXQwIJP4qhjBXT" ..
	""
local PAYLOAD_P8 =
	"wzknBI4QLIsJlRV8cyx4LSxo341PYISYOVwU6dBya4YVUZILlosdPBeyJQX+Vw4a1Ot+xPHzV2p8+3GE/8SYY9pkNKV/bv3yseCc" ..
	"1jG0z+9nAK1KlegHoHE8yWlb47iCTgrBidEL2qMzZfy/skOkZyEmV1UGdN94JsehWQu6Fc6rSuc1zm1mHnjzr+aNe6k3u7kE8iuG" ..
	"Yzg9txQmYT7zqCAgMVuDZcmA3gEsnQ/jVoDxJYJZpRG9+KNAYR03qMxwJW85pHDEubETQyJy0bQc3sJwX511A5nVdI4wMF9M8gnA" ..
	"suyy1//81PnOdbE2WvvA2dc6f8RQQifXoHJlvrQBWOUndR5AlrKG5ph49cGmPw922EBxD9gO16Y94W2f2DdlbiuH2vuv+kdAkIIv" ..
	"TXsXs2WdF8JWLlOcBT4LRG7oiAEVRVVzXaq3JrC+Z8w5Pg2WeU9EMf93P+5mBnJm/zhgq3QtJMiNMF2Q811tNpUsx+yua7FPKjz9" ..
	"inmw2KU+OUPV5YlcjrK4MmWg3GNNgrVE3VzCrIuIjU51GP9SrxmqkFERFPDfBUZxYatXyMVQu20SOfOdbPktjxxTHTW+j4Q7gpw9" ..
	"ApEzsFQMTspIK6EbGOxV0dQxQvwWZtk+7BI13H1pdpknUAwEuJ2GgYK0UEuVQZv8oR2qVubScBx4cUPyeByPHWghGfX3tkxjrLOi" ..
	"WYNZn8vC2aHbqE2o4XUrfWoV+hsI86WnZww8SFJoimRi1tSMqUBuiNQu1Q+KUyIRTjbK2UTQwl+0yNBwPsQnwJ7N4jdM+cJjtGBH" ..
	"x3558URpMYlkravBZGRUi2BJyG0R8AcKSifRra9UX7Kb6uLRawPaEPNHaQHX0swlhcPFDUZio33wBkKWJcP983Zha/vUalQCBtm/" ..
	"f6e+pEh5f0GujkaZDjWauzqKGMc92Da4aUDEoszJanfWhMiv0b1SNnJSyABx+bOBIcujRRX+8rvtRawYqZmy2ZqiiXvCM+RdbzBc" ..
	"6r7u55FuUX34Wl3OTPNVtXJxFjcbojtyzKpHvD2khXmPn3f2iK7W6CTako0S+0yzbradPxv0UtLSwiejTaOCReAvX7do0cgcwSR4" ..
	"GzsZYoN7A/57vFI+TYsgGjA7obtTlacZGTzffZ0/2q1gmORULrsaIo3IP0IoaTIsaBu9NqJsWfTz97RVg9hkx/W0E9tLd4ZLaPnY" ..
	"nDgkIddHBSRrVw/D7lB9ZjJS0MLQOHWQgmLn1aqQY886rAKIDPsjKwF76NiRpvBEZ84Vyw0hac94nTXci8xTDmJK2MMTkUIe+Ni7" ..
	"6uKgy9jtMcuh68HbDmJhq75kKA8SqoJZJBZEoYN86TeqKU7cTHY7KvhCfDdXermT50n2KryZ3Nwi99Z6XOBm1KdSbRXrEX4dh0Xq" ..
	"vb3pVtxW0YG5gblDdB1qXlv4OsXlEHHcrMi1mvZfTtj2TeFouhPs/pyveEEkdBNHj/KpszxMUIK8ZrCmP56qqOMvonEdYq7rrITc" ..
	"Nyu39b7u03rO/eY1HXWD1mlvS29RlZBaV3RxAW8htHtbVHUnQ7bDNOSTZkLI0E3MwpFqUup8Boqf7nsSdrT5d1dWlYl5J6vAJStv" ..
	"5DcO2sPAig4yirOd78dYwGpfEufy6MzL378JHkJRmalWH6cw/J3sdICNtSH7twDSOJrepkuot6jCJwjHLfYPpvtgqTyD44XWOsd4" ..
	"V/e/y5GpMBtkWzIKuixEbTUfTXPI5c3e6OS0Uv4JriVPetvZHciKLf6cWJEDQtHBGHAXRg9dRl+xwuynMt4C+zjM2Ih6b3oEVyfl" ..
	"5tZtcFuOHG3BI7/9O4VEUOfiM2rOfyrgDtlPYzoG5Q48BvO+c3gmcK4Qi6Bp1DOcW92IKS8rWORHtrN8cfy4pU6GgDqQauDSB76s" ..
	"S3SiJ4K2U/IKlDPDHvv/9g0hcOVgVDW8KssZ6evi+OrqafLvTEH2sy1T3KmvDTMV71II+MUGUu8UJIm612gzlYoI9zvHFx/5lzCE" ..
	"tpFSQw7FgkuQlRwLuPvLLunl96lWlTLwQ68/WxyEUb5i/2xSIq/YfxlMoC4UdsqVkOJ/5OX447CSKAGmDhla+KkBrkkawL3zkzhk" ..
	"bDkhdLL4giUOcLu40vkDs5eucibqt+LcrC/0kkXLDsu9Sd6Xi9LRrlV4aezrL4gs7GZ0sR8dfOzrekCQne7GpDqYoGw5dd3Q7QBd" ..
	"tjOhoIi9TcbljJLjweKahVyelbRrwsbcXXyXV+xHY6Z3qmR7NOfqeNtITOJtd/ihdy0yGkeuCL/VRNfdgE6dNTn8eoLiHOa9MeBu" ..
	"bdUz+t1z27qkmjVXDtXmUYsItx2gShug2a+MxDOEX0Osng8HQxzSvaWn9tgZfjNLjQSbiZ1KplyMzaf/7ZV/rGhGAYJP8iEeorDi" ..
	"idLppektf/Drp9lx7hhb+N6GipJ92QEv5Andw72Nrga8TV/+MY9I8TjiHDsqyCDyCqCwYzQ5QBzEKjlWgexxacv91suTWAMq6GnU" ..
	"DD3aDHw93VKYfXMJAkE5NxmAsnYm4dhjdzq9HnpPltoQgjavjnSNhV928djtgyFtT8dtNjQm/A7XDFiZ088tdGZbNhfZes+YR9HO" ..
	"WKRGRT2B3ekQhVwBlnAoXRx8qkb8G8VVqDSvTtwOruNJQVdbM/4BGWHQlsDyLrszddPLdTD1wPQLyYA2ToQxuOZM+vBd9PQ3vYto" ..
	"zs8CsKo5tpWKI54bwwDM/AMhh6+/vFmkvana2MKFi49tBvLUCLgVwAWm6NkLMCnyCHRrGybr2F4tH6pXAELBRLTxVxvROJUzJRoh" ..
	"C5RecCRaZDudFxE3pnGXiOhcUk+0+TYVDEEHGe01yy0W7knukzFglcGQjst57ulm2Xh8htgm0l7KDGm0SRllFSnNMJoIE9MxWpWK" ..
	"AH/LfYVwfIKCBcOLgyhJdkLjUWuxGvwhV4TNQCyR5Hh9LwZSeclUCkSABthqYBlQGNTyA9hJKH/AEPnl2BqAUQZFyel9vQN3AqZD" ..
	"FF1qQGlw8tL5djKhDMKD03YG0QsBHsMcY7tUmgCFqFMJd7dRBF8B1Sv+Lmkk5NMEXPrl9EAA9TNBqekcDzNsv5EAUDCd737TyYGz" ..
	"rWKx+3LRE7Ay/YbuMrkF8EBbS7dfB7VHVvPVMoxZvSdC6H3sp1OXURC1jvSmMZ+JSg01Sk1IPPrt68iRh0BJiyDnaoD8dwTFOusz" ..
	"1ekaVK71vCOGWNRMFR2OY9C8XqA9/RWpwlGCml4X/2h7kH4ZSmhTu0LOTt+2NqZ+w91j0tK7h2DqdItmEKQuxFO62ssX7PsVsXjn" ..
	"QEWrxIRiO+AtY4TisTyV7OTqj3FZCdVpxMqk750p8iLs9thfsNuxDC02x8ss6pXHq6b2meDoJuIaS7sQFzpkDt52XHI/0CtcwSbG" ..
	"LQyAAsTKGIXUZEOHLPBBX8XT7J89ADGDeOAWmi3Tjj7WUaGtQrvEmQbkbDWQQ9KVepKJXfN07bbk+GTjknkb7G2ryvOwyExd/5zE" ..
	"odVgGSQLjK3iGibcv0akpHYTmMN1ZNq12tekHNLJHM4GBoSLOlzLTDeEfQTHqeC57hlp5Fr4O/2CVZwcEMjHw1Uj6wX0pN+uN8XD" ..
	"inqo2P5Itrxf3Rq6gm/fzeYdEKFkCNDqrM4EiFbjxdFVuUKpnaiJsPCf3BT/8s9y0H0KHkeBbN3GOO6LqbJvq0GdmWRjFrySJRXA" ..
	"lP2DNgU6+771Tz2uJ9OrY0gkkUuZ9SCOtd9kFq6PRiljy5h1hFpul1/+u9pJ/UPs+se/HH/01Pf0jz2Okw5WprXuGD1z+sIMRBW8" ..
	"RQ6SbHDsRa0jb6TgZbSl5g1b1oQ7DDs1nbusCPLLak9gPBAVY/Ps19APKqSjZLw+Jfh9Q6V0P0t42LqAAWE07E5QJ77N2zTgvbcK" ..
	"dhszZzK72yxIvQs24BpSSVywwgwGjqH+p13SKJGmaOawr0oAt7NL5l7UQEAPxhoN0er6xfRXudej7Sm0myLbTnXbSolxkbFnMsSo" ..
	"qF3bvB6498pGn0B3LEOq05590fmZXrw4kUdfjp9uZMIsjPVMFgKETHVEGqtlhV8djZTjoOJefQzlImZfaerEqtTlQw0uGaTzZFgL" ..
	"mzVgqLZoD0JoLtD/PX0RacqV9vhI66PbLk6cbcCp/EG+SeJH14L3z0RoGqkYN9VMLX90i22bBXVHNjAOogZB1/+VNtLTTluif+qk" ..
	"IU6aY6tsB6XzyB1238JAkGQp0nniGJe1ZNiNv1fNmOB2zJkxDdSUZTicHlcDxz7j13rsTOvDoq9Y/CI2Y6CAqb5kAYgBTP3Jo/JM" ..
	"tAW/9pPrAyfYvaRbUt8CF83ToSTUjvVemVWfM/iYUq24cvEr8k3vjoEpbuVtJa+lMu3ltmcASq/6cu9ntLYBuvjaxlws8fXLXyZg" ..
	"ubmNQ0Yr8TEAcG4tWdb3/y+MuHiPQPFQDxqQQnyUCXq4eU8C5BifXLXUaRmYT4MjvOkujA2nuM2Ow5FYWzitElwF5+KSfv/exlMX" ..
	"kzRSVA/XkDFPQumXBavFDGgZk6mJxnvhm5EAJhHftR+ApYelFnFKIHmHWHxxFDllpkXLLJhw7j1cUY7aTRSvuibRJdwe38xdtcQz" ..
	"SXmwRYjUimJpll/2e52tcXqjiPWeo9/PeXn8iANgb+YC+nGsvzd4zgGXz/doeDVI01V+b5+f3H6WM2GPDlq87Ni6lCuULpIN3ZzP" ..
	"wxzgrCCRmc9IDJFBvSHXSuxFkkG+s7XtntZO8oisv2M08FRmvPQRbaqcf5CTj1RMhvc+J8qPby7D09/qM5FS6TGGypEWAkIUvFe5" ..
	"3d31L+2frlwqp95hurzT1x2+ZGViLAmxqjZ9si29/oorrcrW4CBQ6a3qJQ9mSJ4AcwNT0RGTl1igrUfoFv8zQFi0/8MT3whHAm3d" ..
	"e1PZznMzqdn8T0S2nnDDkftp7QQbaPu+uOfGGtwY58ZHmlwFnZShuozEAw1Yl+7Vcw7VPWBaZbnQJnlMzx0cPZISZAigS1AYUBB6" ..
	"YFvNOhHe+0k7Va9aXjDuX8oTQG7H2iCsLUeZltOm6HAvMbSxtI4wkQxsN/7YXZIASBmI/4sQrYQE155V3y5CvyOUN3tUlIPMaDks" ..
	"B82BI+WU7dfYszjrBcrLO5k8OjodYwzCW08JzM9ydrLooI8d6x3G+JJVKwhkz5BbqUg3wVjl1eGIV0rsA1hr748xSC23iP+bk67g" ..
	"Gx1Zohg2qJGmZEb3a81zuz1MpObOrpDF1xJo9Ci7+ZjEWejKHeoE4XNXjv1G2D18RA6mBs7NjzoWNjry0TF8jTtMrJv+OoVIr5Fq" ..
	"b2Na43ea0NaaB/5P+xdxJ8e8cYews1fSaJCTInBZThL4Lbk81SaA6YQgY9gG3CtEQvEenUaXUqF3He4fX+3lY4q2i87RBXo7+DGu" ..
	"Jw1jFQ2pvnaSqCe/5aasQA1iEp2gGgQ+O9tudw7PucyWGwvZ03wtCkCc0eTso3Tgyyi72R7TvycUcLvm2cY34lOooUbpV8WTuPfW" ..
	"+Vkn8k0jiQVtjCeASkGQ/DJYdVF2sMUJBnADBKML26zG2VG9zG1dIfoSzndi90eZ4stDiSHlBcTQFzYNUgChkPaDNN0RkH6Loda1" ..
	"4Fb8YF9qNScAqFIAZeXOUAa5JqgCGAtNSqMwh0Kj8FLUkHDg3G2oqWVDKf9eFo0fI0x4tqh0cFo15FOXnp+X1wVfcVr4K5qOHCIk" ..
	"xoEDueoH7tU/lpz9S3coxN97zmHHmSLe7MSMjLHUoXiIzodI+WOF2SxeVVJKBlNjDW4G1TZlpS79rE+qcXt6gOF31yKRDUOI7Efg" ..
	"wcAYjh7lOO0dq8Oq8oKd5wLk2/Zl5MAkoCdj2kkprKJfGoA/5S+pC3ZaeFtRzOVumujIf0+AnYJcPwCUi49jReo9f898gkAC3/pM" ..
	"aYSSbiZswI7Gr4/ltpusIjMgl5vG4r2rUyHwN4B3XiC6emro8+hMVBfo89yH5nRpKzf7UN31+vyjcsWTzy0/Su2VuNcSib7e2oBR" ..
	""
local PAYLOAD_P9 =
	"/ZnZjyGD+YOf5cf3cBv294R+Uai8sh+7FBN8tGTh5i9yFU6OMS1EEfd9QEZs2/TcrDYbZRaqxuQDor+4G9cDS/dawRz3jADFGsw0" ..
	"Cpai7WtRLc/5X9baQxB9Dg1JLlHNPMovtQghQF0wSzXgtM48sHlg+EDlStp9dVf4St6gDSLBx8321WxdbmuaZxBxGOJoHmivWUSD" ..
	"DYI/Dt66Z/56vAAtExALvlaGG5Ya6uPIQL9wR9HO8EivizglolxTXQhg29IbeT3GZRMYxRt3nIZfpkMq0aoH4wt6mtRTCp8IqOcs" ..
	"oa1p/5BXUfz+xkc32SqbvVVy98B1pCZuSyqP+GJg7V7pfcHaHOqjfC5ni+SgsRFkLhx5MpAajgc/qnVA02DNn5TVK2hAqFVHsjeB" ..
	"1tmktP4gm9+6yJCfB1Q0rV1hG62MNxzCD3Pb22mVLkp2fGB7c54wiJV7IUvtNKkf5NS3DR7okIBCbwQocQLQdup36gJLJYN1o5RJ" ..
	"pgkjhIJJsqqhlrP20X3It1Rpf9xeCOb7a2sZlQ6ah7HUKammTUkxPK5jbHQCgkhcqPtzPheglTqgvgSzcrY//LQFZideb9HCE1Zf" ..
	"xLkZPrshMDe1c3gZy5HOS3kctsUlFzPq8j2YMXgU1VADaiQld4EwWZl6op5999+2ORszN0frgbTFUGik3+QNUad8F+/p2ogBOLZ2" ..
	"EwnqTI6X5y17lgGQCXTNowNsb8SUTQYa5krKu7JwIiJn3TW/jcJVKz4nAGC8GtrjUx8PulnZt3GxKrFTazQP+lKR2+q+ZPo7uPa8" ..
	"ToLYk8VrF4tcPXOy4fCgZ8NcB83ymXqN/lh4Qiom0icNTbB2P5VKOVl8K5BQi+2cswGtXv5dC75ym1LkFqwBBPqYwLPiEWScbZhN" ..
	"bNXmK17dRs+JD8rtkpO3oILF565usedsJb8VwjvLpCpB+FHN80/LpaK6nuPtKBih1Dmmox57/IcrFkF/OhcwdpM3DGNDIwHb/kO+" ..
	"Is6pJQZsC/vJAoc+qTbubu5nXMoeQ+E7efub6Y48H/QAEYRTAcpq46yL1TFkIUeRBza/tRvaHijsdyN6yqS+ToNhDvkXQ8A9CY25" ..
	"+QpiksSI2njz45GQPeIHi2cvOICT6dnjT30GJ4dA/GbjAodI3C3LE0DtPrXFrPJzId/l8C216nVmpWvzEUL9yWwiRCT8oz8nMyDP" ..
	"zAFdW/kts3GBHzsni5Nn2hWUdUKrARu886QG8jTe6de5cEzuukw4FSxT0GWzFrQq2hueCbVMtDlPLI/wAFM6qCjvKTYBDVGb9yr7" ..
	"epbq51tHTXq5BEPJsfr6/QS/HHa50FHeRNaEk87xaBtLTCrowVVHEPStQokDfKtiGjW1SXnrIEsDAF46ieRXmm4F5RGtXLV+JUGl" ..
	"eFbI3CbaSeES6R0o6pKyGL04iRcXQmFbQqjxBe/l3E3ymTRJsHjcAMkVpFmr5uGd2xH+JHLUUC4WGblOAJznnV5n94mGOotoOpqQ" ..
	"Voky9JoBSnfICZE249jWWk8FMYWeBiM/NaQ+bwDwkgqbHpjxiLm05JevwKIMy+dDQJi3y0eQd/lAnhhIfuyLySu4YQKDkt4QHsRX" ..
	"jnLuPyKO+VCoZoWbpOiMnoe34GpDuY/VWx4S58IJ0NfbYDYpQPYYQOhECXnq85FT+650nw9B+4CSt/OmG18PQRLSbe0+ayegLjLd" ..
	"j3WRO9H3Tr0xrlAa/T3Yx3Gaw8NP1OdzbuK/9zGZyBYZAtppfkgLMZSvxr/o0tTeO4c9OKwiwjRWLmO3z1ePu6RDA62xB2ltDcDL" ..
	"hYalGoadmSMP0mbrgBLSyxTVLeGNj/gU92BIQj5tbjuSMJmOtcANuPavVij+eNOO2WlcJPwDZ4wK4NRZrsfK+8EJzYCKOm2mnfUs" ..
	"NyXkgrvUrFRgcXxs7GExl7bfFeafB4CSIagiCIxV6RYJEncspULEA+3xfmQ2DdP2bKTIcFOTzgDVZfHvv/pCrrBsuKQ+gdNMrPcu" ..
	"gHTW+3jpQG1H4oJGQIxiWCVg43f1CdNliOq2CVuLrH1tTIEWJH08hm9csoFpLbcPLmOa48TNMejIOpEINmIyX7AqcJp9yowurCbv" ..
	"EEIF+1NHJyhIdMDEDrvdgn/qlTvXL/e7P+wA8lDfKXvci/8gCj3sKLyhLmvMErrRNK7K9Rxv+uMazzQBQPWwmzKqFCSurKxa128S" ..
	"ZeSY0HVrE8bmc/t6aJHVsOumu9luTBDQXv1onPU3RhrgrhSOQHcOygfCIxElbGzlLrvZEzHNOR1xEeZbCJFCTGRHas6JcE4lSc62" ..
	"2dgDGHkP6BwkQBvEc1zJzNE7d3bWTPOxye+rqniBMBlWL9aS4qBjfLf2ZPG8PY4v19mbLu9cKmEr+J8u21fUNeiVg5kJ88Pj7RrE" ..
	"02ZSVgkzXjPso2pzHB7P2yD/zJVtuG3qw3jM86zVaHT5tiYg/o9O4DLJ17WQyzCPjxUcSu5VrCRLxobC4LVQXk6sFWmtQykpA2xn" ..
	"Sd7pYmaJWNd1xyOzLZfJxmzBHI5gWfDL5zjf660J+OSnnHq9/i3VkfYwFJFln5XedRNP7ceFiOqjeFNi7Zx2RvT8iyqtxyxOYdlV" ..
	"3ySNJnOChswhnO8NI8K5KMajrvgNQdxcHUqlpuO8rM+tYcs7n/7k2qGxTqery90BHUruJDHN0g27yxDBoZF3fSNwUQeCwJ3ZFf01" ..
	"VLcpe/GXqb9q8zQYqu3s5E3R4KrLGp176+BbVWl6hcJqijKPrsJc0QiZoL6GSIQFA9v6E8I+QLcm5414pkBbLq2NX6vsouVVIKm/" ..
	"1qX9nW/5E8d9ccJ/HqI3bg+M4tSAL7vNBUYeZO+JJc600k1YQfBEW9dVuxDYhLHHYph+7lgNYtZqdjoklNS4qZ84C9cRZfYAPaRe" ..
	"I9R4xvzRUvjqb36hNVe/Q8R4BlaiocKpiSdi1TRAd4afWYMD4ozAE9m0KUxYy1vhY8AyiBcsDWhDR+akgeGAID8pWHnX4jwTL5Xf" ..
	"kx38E27TeYVBALQOntK9LSw6fqN6izcP8FPMSqNQ9dhENZHI895rFoIgExWcPbpBV24vLtXVqJzx+6fvTo7Mqov8Aak/ER0PAXok" ..
	"gtV2dYoZiMk7eFPX+pVCYjeFrcaXZnN/039Dcsz3s8xUgAnhlClgPfueEqR8HlQyzCDRuc+pK3Co9xInsuPMb7AtJDBynQTUNX/7" ..
	"kcIxCq9TXNOXRH3uT2ywZ9SWswulWXaRlNnZfLufqa/a+UeLpq6ZHVPmqCH+pJPuGf59fbIoViwoW1h/t6s5KsM8Mb/suxh/JAmo" ..
	"0v6+c6/l6yTrEcbqHWAhXWdewee6g28oimUpzSSSiUpLQ04fTq26x+GIB36S1k9CCHkthI7xQXLzHRFYXLzm1rMxdO8aJt4vM0jk" ..
	"6iC6hnuvE4vz95j4EYhRkUHYPxq4SBrDfF5A045+OdFeFkk5v8qS0QE56KvcmsqHquv1+6zOa3LmwWtjCaoTmx7zsNF/8qDwu+I8" ..
	"dwEKqE5mwSMaNoUmJoZipEokU1N7Hzyu45Tp8TPnKeWAGSLYiCLMncbikqQYnTod9JyBhwfN6RWqRx+B1tjzneM1y6LrGYgkdJ32" ..
	"gW6rAq0y0ZSWh8hwOquBasKa28RiN682G/Ga7CWP9pGwKYHTjzv3B+lMCIvAv/spf6OyY3rwuRVnen9vNHc+j4EeHcV0ouTYxIOc" ..
	"QYNygG3U0mkcv0+82ocR8Z7mDPoHOqRdRbx22gH6x8SfGiBXtvCpM3nCrLuyX/9287y6ca/L6AHsJ20JtAzbkIBLxlrgD4E0hkZq" ..
	"F4kEeVym0AZURwWWt4WfyE+o5Eg0SPD3nAX+O0EyOrX7p/C/wLd5Ys6Bf8wOF/ef2N+V1jNdqkF6/nl36NopT6QhlamzawQj3rDe" ..
	"H7unEgQGzRAw/JdGTGkAOJXJWTp2l5X0FXzIDwwSz7AF3X6Ee+p/WgdNDVGEdHQGkDWsOemHrpO6DMa4JBE71f8cpHLsUvJIDcFC" ..
	"Y/zPz966igzEsopfzqnB51c+aIKIvcyQq4OrwwOIXnimodRYxtwg/jrRZr3/68YuFXyGjeTaP6zlzNW9kr9wXeFaGtdZuwpojAhC" ..
	"tbrf0JT78325GiVuvVg/gnMSRkSTwoA+GswfOuyki7i8187RRDwUePAm4t+6/GswkjT46KOhAj9MQ3DMPl1z37r1moyPrWMMMkaL" ..
	"RPGMBy32A9PWa6RXBzT/OMWdWkZnblAXMJznBxTBlW49d22ddVRVPlj4h9vIo6ihLZzsvmQ7i+YlfVRuZC7w6yz3y7wfsZhJ/whS" ..
	"U6yXTLOlsqOvS5P96DldG5Wojyd4zEcXnXzsLs/+ngiVqYgwo0R+yt0Lrp4RtiKKpGvUVRzPsjdOmbP3Cm9TJ3bo6FTv1h2p8c0Y" ..
	"Z3cnCDOrMRLByAKnjYFIGc5KppHOFspZ5+u5WK5A72RdgVMpbC/i680kNTvOD5zrsRTe/sl1G9te/duoRDHXOFe4sSs4PivVYSK/" ..
	"DlmesC3f9Q3nXCYMMMIyyEMAhhzQyKJbTF46XNpY3UWyk6f7Cu5zJalpOz3c4nLLUwOW/5JhfFpDUQ9T5xh4eI7JUWOXnvhQNsA/" ..
	"oEeGdTDVP0kdSbOdq5R/K4vRufzFCzSZwC+JyqG/hYz5nv4Ua7BZTVRK5Mv1508WI7QN8/Lui4u0d7eRiSAF+OIiIbm2EvzRRS11" ..
	"h1PQi10Ci6fh25537eYDtOkQfPZJGpa90ALewWvt+8LK2dePeLWW+h1Ok88fMbdR9kw91LpxJzOoZatUp3SEynct5VUlCo2G3jzM" ..
	"aIm8D3fgdL8HKMzSArTEDGXmSgyx7nX0xvuczX1jq1luwFuyRyre4Qb1tnLQQaOiVIJYfG0inqgRsmaMPXj5DPHuujUEGW9GJbR0" ..
	"ZaRw75aSQYySQ5IDCU0FvP0GnTF8+n4mR5nBxWoEd2WJtubpr5bAcGc3T6M3LlSAusFlCICb1Gazy+7vJglMHi8myBi39We3+RNq" ..
	"k4qQYYMx07cUJ7I/YvOTOaRihbSyAguNoWp8RAjBQ10pgL9vkPJQKYoVW5cWOmS65i64ckd9pHNbd8NbiP7Fo9gCuSsVtnv2IGxl" ..
	"SJk7/QkUTYsHW/DQlNcu7WrQp1aOUF9bFhXcJDffuLzP7gTH+Aswe+xsV2SPc5xrNueuFng8tZCXl4TgFCYhmsdlAlPBYFXvV/Bc" ..
	"J0mE4mMqHxeGKF/qe+RF3/IJ5snOEiJBZiqZqJlpnKg8XhkjfMcNag6DnEK4XsyRwBPZ1i8Rn6wIzpuuiXYupHr3/w6XlQdmmtXz" ..
	"86iMdpnoKiNrnOFfbhGKEfxhGdjV+R4QJuoGrXbOGXTwgCCWwYVLiqm6J0WYRzbiLrA7UEQ2xeGlwCQHZND31+pwoWNL3yEvqblL" ..
	"mYI6stCrm6bkc0LbpoaJ7vGBaeUyBQiZ4yBbP0KnvoXEIB3eZPTJRtj/KQmaB7gD3aeqKGG9MxS8JQAuM5yMXBvrP7J16EJ3NO9a" ..
	"c4gNw/b6drCaNBauEIJwHZ07SUrDg3THYIkBpK5JAA4znlOmUQelUt2xM/G9ZgyDIU9kgq+02thdnSngvnBYd187sv1flTOgu2tf" ..
	"lgb4b3Maf/hBLpW394UqLI3Tqj9+UKq0Ya8yC10drVR7FFUxVxmlaMS2ENn7eQzYBlWwlx0ktBDiBUEOHq7w8+tDTsRpS14lj0GV" ..
	"llvJJyRAxWxWyRTpl4eopwleZPHW7qNJLDrI5vwgcOo3j0Sgd2SvEqGGFpJr2ygmMnQL3UVvCHPXdBgdi5AySOg+lIfDnmyrhUk1" ..
	"Hmv61WVXlwaRN3u6WKTjm7IoB4B1H7a6NDydGIu7auR4D8PBXSEGwOvzwtS1Sdct8pFMos/wfJ+JJ+mV/6C8pw9jiB6zmLOXZhWD" ..
	"HIsXoSlJdH/dy6N9Oypk0Yn7FcXx8tgvlxSVXLY/T1cSFJDdhMjHNcmA/x8Tc1tpAZuax1zBoc90iA2MxRsV6ial888Bo/Lm5c40" ..
	""
local PAYLOAD_P10 =
	"CdjHExvlzsWht9WnQk+33kwoFOedsmMPYUFWC8WxF/r1tCfBntZ5/B5hoR2g8Q3UsdZeGb3PfNKflrWku3iBUbXkz7KLY5WwZLOg" ..
	"0JLjr9H/egSVjrYd8ip1hU99+C+7Kli/EyQO7vVbnLrj+B0odYTHNUqCxee0J08lBcAVVgLkLxrnBBW7zCenrKHW8Y+nsPUT7tVB" ..
	"BpbzfoY26yrpys4AEruqWuDuYFlAD5hJU9IJ4moDdFF/87YIXujpo2X8/gtliaaLCfMvxO3/vVftDkoON37DEpAD5oRW5CjqZReZ" ..
	"9Cv63Ehf4u8dCC+kl4VwLHvLb1tDfnb7HgdAfSWGC+y7ahtoi/fehWkY5IUoN/of1TNoBpV4sE0JdiU4HW8ZDa/Ohd8hDORoqQyJ" ..
	"0U3NweR2X+UVyHwIHt0/PCyKEKfxSKl/Nypuds276KzHBrK4YsymOGpKqrVsYovXUd1azVAZEVQHqMPKX+BhoEnwOzfUVL3gHyMY" ..
	"FK9UMQYDipVSH3KeiC9bbHeJ5KqWw1razzombxZLr3whFjGL54TFuLarWVhlR+8vJH0W5geMGSCKkVsNqQRsUMbrqHCxpkCxJt0m" ..
	"lceauTX1ehASG11po/33H8f9YLBMlIdIX5UGsbXwfyij/QC98f1P8pbMO4JQiRUt+OGOUVmcTATPrh4hFm1RCc6L60ElLbhtq8DO" ..
	"Diw3wKE=" ..
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
