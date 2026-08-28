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
	{ seed = 1104469054, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1101839400, exp = 0, plan = 0, hwid = {} }
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
	"hRvlncRWtpoTZoRwMQYkSzbbHk5KOxaOGqkutVEIgWUApYSoJSnj0Q1W/GwY9J9Iz4VNSr0jDuInS7VLP9i2+VS/o2yHCjA16imP" ..
	"S9u/9oQ5HDdznWU2xczKa7jTTpW26E5ydCPb2vUFf/xsuGB/Ri/pLfIj05tONe70BL+LuyHNon9SiQGs2JfzIsjEAN1FwkMZuMRS" ..
	"Dcj7NwKx/g9Y4hztJbgMOh6Uio1AnbNpgZ5WvY2xmbDOt6DJBi2jtVRfbSqF5zmmQOgqp+Wf4anCP7jI9CWqCSmM1ubA12bVN8sy" ..
	"geTi36bF287SyK+YFcHB1GvouBq+TjuC/+7iWGs27z78rBUiSBw2lnz2oPtRmBMaj6LKjavYo3o8oBnWfpNtbp6sAICUij/RtuRU" ..
	"/DRbC3ZVIwLLotxX0sGnG4jijkQ9bZWF87ZqW5UYdk0BJVJ5ouXi15wJmDd4KP7F88sTSeigntRCsuHw4cRFs4d2CTU4OcHEct0K" ..
	"kocLpndIglQ7HRaitsAnz+TWUuSAQP6iKosaUIgheKbZY0ixPVEoWuSbMP+dH5c/wevcX6X9uXHnVLIv7S40rQnhKCWt1taCq9ST" ..
	"gdBKmsmVbhW3PGJ/8dsB2XVsuCQsj4Cs7BVIu1H4lrtMdGB2Jsk84txJw6QmcUpQDCUEeL9u7VK8DpSVZcqTa6u0cl9LxbwMRAFL" ..
	"nOHHAJEPdhKghTTRrPVGXqDR+6YNS/Uv+X/0xJ1wXl3ix3Rj14mU9eKEvI0gTtyU2eY5CCbB7i7+q9gNWQmkaHfee97hzxptO5d0" ..
	"aBEirhcvzAxOCbwU2Te0fQPplrLIX/Q/01FI7SLw0npGZ6FBCYn3G9ukkc97/jZGGfQcatoFHh9tCxUUO8Tw8HdSfOzmLDSa9AHC" ..
	"9cT4OrbMyhJwnNhN0Mlb+zPTnBVuvWoCym3aYnfJrSJnxViH8U/hxf/eb1nNp5tQb8e7gL9DYs03peYJ4NAIjOvX7fY/ZT2cBSel" ..
	"b7ecFtuTmeZrE5lehNn+Vhimz+2j9a3i+vSYBtGwumzbTqpZHKMbJR7vhSqc8exfmAs+yQFHyetfbXUg8GbrgSAnnB/q5TZ8DS5O" ..
	"x9F4OynJrTiGaqXL3SYtmybcS3zpMp74Vp3zwSFG2EbpOy2tgtthLauVTc6rEi53H37bW/2wFBfVFBX4km1FXfC957q9WcHC3F3x" ..
	"WkqnpMLgMvPlnfndb9rLlri4YsZ7awnERkr9ja8OjwqeInbn+n68s4FZasL0CYpCUELcLJVUrrYlcAmqTVEvt+DYQ+HtjUi3olwF" ..
	"GM70V8nDBe66FVHsA5H7jJ78OvyGd51UBn1A0QNi5gyPAOuSdG6H+em/TURsxMLSHVNNycPnSODVicnq67vwImuJXvnEeXn8fKQf" ..
	"M91p11LuK1SvHBQ5evfuHwnfJu0flCTqfd68QDzPyhrLBfvsWh1lPk9bheTqB9mQdRDJZQxGIXJz+hRStRVYxyuMcpppR1wfO/DX" ..
	"lZoEpKYTE0LVoX3Z4enSu0u1IefhUiTKWnDMo/dHrEFPwdTokj7eKA+X1jPfBUkc+T4JxVAPGtPGtLmvOIOeTkr1NxuC2ZMAVRBy" ..
	"5GC+8Xp5lgYGjvpFqYnzjLBEyGDur3mttzD4FW0MoSaB+bnu4i4Vvx6qCixzEUaP41EptCsMj90dzMvWHdlpRpRK4ITnQ0V51SF0" ..
	"wsi/QndLidO6tQWjPddZ1h84nLB15SKT4zM5a3vglyyPOknQClCrR/jFD2+0Rg3rUznBlbE1V/uCJSDy1zjCHOAwVb81AuPACXjO" ..
	"NeDv+KQhPpYJeXCD8sTPJR27QTmf6qEALqKdOTu7wI5kk2RhokaAX2XJIHDv2dXwXbDWMZjNbg4s4jP+D7jScC6yxmm7h4NT0Twi" ..
	"up3M6doP4AeMJQU3JVntd8zn7ex3rdn4WV3z423NwW2IOS4qb7XP3wht3b/U3GFVCidmXdsg2lf8p8tzf01I2ZpszWr5u2F59WcG" ..
	"Q0quR2EnKEfoiTL122iofyanVs9LpptbsBghgTb6mi/2o6AjBfgEMy3S95XDieKtk0raEGigvbdkTO2PUMpaonaiS2I/MzN+dKS0" ..
	"Fimcl08R26ethDZdbA4QaSd0UwLzXoq0T22/vpsBB46I39bsAzCZsjD0/vSR3lJy/cV044Uv/vB72fqAhEtHCWLOZpRczYonqf8n" ..
	"dXpJoDcHK83978ywsof+zGuBIion1H0Ka7SloXKnAwbfAFGIY0ZrGvihCX8jknyRI3HObqS4KT0grYBdNhzCaWlq/tFeuO8fsdoe" ..
	"I1ijl5n/5m+CJjvqGS3TyvvAKXf3ZBZDHH15tLhQ9h29iCCIuDNJlb0sMA0g0AB+iHs30xJOJB0e9UCtxWhEXGIWprR+MjQ2T13J" ..
	"UenbrXYoDgkHZdIuAbpRHM2hj10MZz1gLTIuKNkAP/E8bvuy5iBzv0YlJ9hFPVX8xLEkN+Ohq60yfLrWGO+2eCgaJV53pVxoY24h" ..
	"I4GQ3A1HdRv1aPs2GLPsDWL5vVI5/Vp6jKPbPKM/9LUeXBy4BlM3cjfhdkTrFWY1EliFSf5tuhYlpmlv0bziupzDEULn1vzxCNDC" ..
	"0/5DPfi/np+eIR64XnczyfmBHq4U33eQ5YeK8yCg4RQJCIMTJN5kv6GSxWDPOtQ9z41CeeqSt8Q5q6Q4Fs+iHNISApDfuDczbeDY" ..
	"vwXqYW37oSrTD0sz6qFBCv8vtjvcNdPD/jCLjTpbsL4Ad2A5737oEp0PpBF3npG+y/WkqSJ74h7Aus7vUDVLAgkCwldaa2mTrY8x" ..
	"0tTPYvYx0BXU3gfsWEuFwYCRCi/+weqa3WEKdL+VkPkiVbafqm0b6YbaOcks+UMBkElE/oXx1xxNdoN78CcISXMhx1CW7whbYzyo" ..
	"apoDog6BvX7svKqwbMLv4sPSg4XlgMNEO5d4AxA6dZGLg3pEmn3zRY95l4YRwmNIAncNLrVcCkdKhGX6+biF9gfivgWIvB6bC0PW" ..
	"Yy4xb8B11EVVhLcvLm0j/swG+Loc2lq4h2OvUHdHaL4vSYXB9sib+f8NB3Hcgm4aH9FABM4o9DVHP+VmSK+REMxNB/taid2N6/I5" ..
	"lbj/EYn2yDCOOGZvVpPnhb81F2wcJUTmh259p4KO/d4J3VNpFmWumB6+7mKXZVGZGrDLH1Am+DMbOq01G3ZF+/EpOJ+SM3L8wigl" ..
	"MN2ZnHxUD9/udB+Auv1k7TdTGAosAgJAfagfOPX6QT+loJp3cW/3VnK84ZxPv8qqkI/2wGKmVkYXOh21gz0yZeSxOQWQ4lvbS93R" ..
	"WJ5EGKQFP5dWv2IIt+KfOK9ks4yR7DciRAq93XtBc6RMnFDgiD2RN+Q9WKNiRO5MVgj7j/lqNmXWKMmFz5c7F6M9Zo5EWCRxupui" ..
	"DLSCapCftgPVBQUSD/DL9njCf/RZJBqRPdQv2L4URcWtw3qVUV3zBZyHV8i2yYQ09ZVJEV2oTM4H4M8nEfhAJhH/Wil5rnyxwRj/" ..
	"vs5/b/YoRsDstViB8/gIsylEzbHLSVBiGUBAJEyRW5rurLE0S8cxpRSnxJXrxR7dk9lK8gHZfim3E5cGHB3xkE9WfiOr1W4A3oOY" ..
	"diWXuUEuaD4HtzYuTPWxF/PBMydt2eh7Vc5PGimlGmWDB2DtlZh4zIT2ns1Qq97nbbXB5tYjl2ScU/Wb4qJpUQ10ARy5pve1XTNP" ..
	"8CuSB9A43G5Ct0DcoQ9mIa6K/I2pSuWFH/qjgg7TzsPr0TfZKm7ZIrBOUY2PTeO7Vq8hH/MX5EKG6FT8FRtVWts3+9SDUkjld3Rb" ..
	"2ZMSwZJC4Qs7NHkZxA9JN9GJNNw3Fg1FLlruYOSPnpQDkveGLzLjoUNkd3gQeBa5HBQ+LhwHoVI5tKZmqTXpkH5CKBAbymiYeS4i" ..
	"j9gxan+AjCUp0RxriDXcyiTcGLTHHZKQDCALhaKaf/5hsZkV408n4owUpdX1ygrOv8QM08X0ClkPG+o0GjhitLd6V12Hc8eKtExO" ..
	"HJdd7yybVnGQzLhtCt/xxl9PI6spVcnLaJE8zwAlh5dpo1BbalFOJRTKDdBcmUKriwt7m7K3CLyNAn5Map+2u9drMYiMzKdZYRJs" ..
	"T6zdKiQA0BdNj5z1Y9LcZZOo6r/198g3p23TsekJ2OMbAxmEibwSEnv1Ae91n8TK+XAKRL5NiM6pVbOI9sWLdnoZ+2e8Lnyur6BZ" ..
	"HHAicWC4azfy0XVABRXE6y3qJsRD4EqlMs4y99ETBIkP0vI6PLeXYNel9XhoMlEqv0MXM/kJJmgU6k+Eo3X0reJjIG4w20YWRSaK" ..
	"bmGYcTDG2JGUCM91jYRHDUlx9mOIxrD8vaYF0ViTPTU8f3elJ1QZgSyGhPz1pFNe9nPPH60lhBS1Pcsjdz3NF6xuXZWrpB0Lb+0u" ..
	"2Nx3jekqmGw+9DXH/YiWbIO9Juh/PMvfMfRo2s3alpVdWShCd3egHmVrRKrQnKlJwy4THVuiOMyCMDXxhVYVOKpLWhwjTxt6Pg0M" ..
	"n1gzedOmP7OZaSYXuD62scRSQzbrFiBac171nTxu/5VGEbsbiwqIPkxvJmb4eFkLqKaByHFCWj+Sv3Fpg8unzmiqawjrgFBSJ9JA" ..
	"TR6mTqnPCKwiy52AzP/ljAiYAztxjcyDsTjzth2togbd7EnKyc3b9ZYxkzoTQV/ae2/3c8KUWvgv2fPB19/OF2uGSIle/yMfnBBE" ..
	"ePw9QTvPcPuMYf3St4y5cm3z9eCatAoI39sOwk8mOkZmrj5vhbtPBeewhTG6D7heU4MCcnRhh56ziAv/IcWbJL2fBngSb6oMJwEJ" ..
	"/Hnd9pELRLapSPFD4URfupoaZfJQjalcmumdX2Y6M/p9+XS/xMg8sTSvOfPHJsN8ValmDffMumlTGlG0eYNGxI2Q8K7Phk5RyeH/" ..
	"T4dbI6nolnbzyJ2jmGPiSjRqfAW+z17hJd4BJWuFs6aadcK6r0kYfttt85l3YF2pGg6ZF4kr/Ei7a+ORNqgzYnjbvoaglPc2oDBM" ..
	"Qv9tuq5Xay1sfKwcrxFuYzZISPzBKL0xcPu0jOfS+gxcuIZcvODb7lWxsWtEk+zGnftjw2ufkrP2VsG62mwTZs4B6y03loCotvEv" ..
	"ek6WlpUjhy7khhBFFoedkpnBSIuEAAiXSl2J4LTX8ozvS4m7M8NMjCpPrx92JIUnK17O48Dx5+bYjgfW7A81PGrsAa9WM13sc+YB" ..
	"wWjXbi5jFm2fTIvBtiMCRDHLO/cOi6yDzJpLXbKHNv4wZjgRjxWI3/Z/1y0uSR85f5p5hV0GocIb9LlHzPBdLtB2zNtT1gWbd1Hb" ..
	"IPz4aTGkm01qK8PlMW127TGukuB/+tuJ03eIgf2ybrUbyu463v3ZNs0eogirxWSaWlSPJnQD3qsiHsLKEbHzjtaxZApsPnUeU+Le" ..
	"gLWqkrEZCSnWmBe4oNR5KxyC9ue9QgbMb2rWh9t7sY8r40Vk3vm8ONeJno0XkZ4Ll9P2DP9uGJCYPDRVCB6x4e6Cc8FA1qODXoE2" ..
	"xwRIodoeZ2abKviyYmnGIk2GOaUXLQARhua92gR9SWrIcRzGp/WFIcSK9W/wf7Y0dEEpbO4+qoQLlOgBSgYESHQhaWDFxWqCTedy" ..
	"ogyqi+N0AsrRWyQVOA+h51GeJ/PBasTAdbTZRvfQBY5Df/IARY/5FcQQW7fQjL6fSqroCBL6iRczMrCz+rDygh01ZOwzmmI7Xdzs" ..
	"z3Vh8faZ6EZp93n3sEJmJFhLxxkv/tM6H/I8ninZOr2H0Nlgm3PmeCkfUM0zeo1AM8Ir7ZMGeEXQ+ZReO4jX0zbn6dVsm+br2kwv" ..
	"POf75EbgnHx2/6k67u8Afv93rh4+oa+q6CjO0RBmd3NXHIxX4sqK9EluDYuQbUp2/Vj3ub2fgImfWeVdQZ1Rp6vhB7udXqAnVtK3" ..
	"eG3xw6oT9PcmME++YitU6N2a1MX71OV8q6DEFpKWLCbMDTDO7I34RG4SUXijMvC5Z/alSBlABMKq6TUxsXT1GDE5BXyDkzfan1MQ" ..
	""
local PAYLOAD_P2 =
	"Kf8GkXx3Tf47zlCgIQXF7p3y9Oj4xT+mJ1ZD4i5LeWZFLcerQIeemsFY0PbEpLFaFCDIZQMbB1SrcFU257o3ZWO/LTi+zdvaBFVJ" ..
	"OcGeBrOADxmNSAbj6Ow+MDorhKWx9fTyk41I2bttVLW+hi/kBKymobhNOsQwD06ta49nNzQ2qRJI/VhXUg84y5hF+qJf8p+g88tq" ..
	"Wx0ejMnTDNhdUdHRY1CFcsreFq/gz/DgpAafyT3/dUQ52RsfPtAoHBLMVuqcfgklAMPjBhpJcObA9JMYVyfQiNrnMooFwGRwBVBN" ..
	"4Z7A7YWeD66LW/gwzJE8kgwr2uNcHiYGk+VncgwfOsdcYdG1+4JvjoNhyghe36OD95fViaL4fBwUlAFDBfVd8lxb8sPPsd40XaTj" ..
	"5ugJPZIXqmsJZkCzEUtsCY6dBdXWsQyTe1ePZb8UjZR8jI4ZZ9racR1o27S1cQMFVMjNAZ51hmVE5bTpdvUKwDSdwuw0b2JXSQfg" ..
	"sa/nQmJJzBTInKVSRoWhh7uvvkLAXfUpVyZjr8wq3FYu2TyUCoQnxR13tyQyKNwNEp0EAhnqimhSlgcjoKf954k0PvkKbT0L4W8k" ..
	"wR2j0DMhY9jjVHpuWWvK3gW9P67Ov07BRnDqbuxYppbGvb4lAEKkDzq+A751lDWHTU57l9RPSW5SprhIgePz5g8439Mi6jPuxO/N" ..
	"TXkxvmOa19/c7lb4rg2UpEPUQGWVZeYkp3dUBCQxpS83bOyfGge9uW9QXUoY7lDedX8j4bZ0KYPLsJczpKh5KEtcJC+GxnD3xaVl" ..
	"SbmOh9E9qbd8RQyg88m3zxPqsGE+MnTFShXcTBbrYv4e9VTDRznEh5mzRMo06EZ07U3tXMS2+hwrpGAbnwVFZ5rIIkPtVnCWP++S" ..
	"nBjwGTGiSY6U+9iURmmucSeht0CfXMhI7yHZ9O4UAYUls11PAINMZ9R7m1fA8YQ9GgWzcTTSDTWmB/wQ6e7kMdlkU2uAE3OQpgO+" ..
	"ldyKs480jdNjWWOo99u47YAIg3LbASMvjXbOLw0sGLbCD64GmgWSEss5G7fuCT0BvLaeuIeOlBfcLDXJeer8+s6Jur9EpFz2P5Yf" ..
	"gl2ULEhzDOrL5O3s9R9BhAm9Q1uZxcrqvf74c+iwCW7AsGM/r+czwlzl5bZ7lfprd6P/eBimOu/JBNGEsDFwcRK5W628jXtVFrMu" ..
	"boxQrYNnKACbFABrwMSWiAFb6YeZCnJodx3fs5GlwbnF4diZ/tjIPC2mEMYFuPBiGOh0JB+4I/mYBnBFMLjBm+6y4qaZHJkUgDeh" ..
	"I0ko1NO22gU3Yt0YHF9DX1npLYeg9MRrgsDE5nAx0NyT3JzDRRqds9XkSup20IsWVjtUm9SHbbKz614zAVDGff4bE4OOwcNT4WwI" ..
	"/hMO8AnwLT4Q55PBUy1TsnmmMt+LpxY9RvE/TlzbwrQwSiHSgWmHq0HHcK4i0h1x6+8DgTLinCpb3n4vcUmV3a2UJITA/V4C9T2n" ..
	"d6L59k0V3FbPQqrJ1Tw0J2CHENHSVgVruHuy39heA138ajb8tH2xztqgWxIQ9XkD64eY94sov0P4a2aKLkwYjT/sagKcKMoPzzsp" ..
	"wuok0RWYCeySo96jvcR+jAGpWVRAI/1MO0nfUy596t8rij86Mz5OnHXPG/sdDqK0cyrxej5o1+acms2oDtC7nr7eJxY77VzsihU7" ..
	"5x2Zbp0gpeW83HMREv59qU4o45KeCCJVqwnxcBVObfkBssiAt11Lgc5I8CsHgoZzQ0YLnd2b4H1Qe8wcRLHG2YDiUeKfPwgveY6n" ..
	"G7+9h7BVjepbVRet8ex83aaoacU/Pm83h4vixg/NYnwiL6r05EQKHLAO+/+adENYOdm71EVRphR5F4iC8/mDmeTNMAioDHiRHcwC" ..
	"bhraIIpHCcxKFNZv8po4zDzqpMI0PHQxQXmB3nBtsRe5Kef55nRYYcuzTi8EGPJgOxyXGM53170C92kAYq+hXYTPyQiRgIVTFviV" ..
	"otC8/EeFAT5AM7sF4lD4ex+ROb5LiGv1TQ+KoqkkbLLjB7u5LZfuQm5S/+5aEpFKZrzJxsmdjFT8jqCQihjjpw0Cr6X8uantzw8q" ..
	"V3L7GGotaQCKKQmzyp1iKpoqbOaXG/nsLA/EX6ZjC7AacEs6Y2ZDv+HnU5CP2V8W6Zv3Xb7mnansdhIrt99Bk9FXUJI09PS0MRTx" ..
	"gAKQr4GLw/9VRsxBVVYNQxVgVzTnmrtSNhq7goL09sLn8oY4fRtsryTDmXKGZ4+CgAR3ohPqy7oLnZwYMet1Z46ewMvhZqWi2N+y" ..
	"zLLeQt5Fu4r4tjXvcEha6efDyp0hw0EnK1iLRjmDwSfP4k6BVRhlLgRIYHG4zgI5gItqgSpM8EVddfRJAcEfEkI+AQZ2ywZM5hlu" ..
	"LmAn0PM9zTnFQRdFzgu4dJWUjor2L8HOjTIvcPKHF9ZIiAFMOzpZqFl2VMo6zYZZ8g18Q4rpqZfQscMU10q538RULPNuDkbZTaQn" ..
	"fqcn+qc0sQG3q8nQK+GF3zswigKWfS3aJ5nvi2MU4IBp7B2LNwbLexqpuiVUmiEtkrShnZoo9ksqQT83APpTqVyLlgH+t0D23Ln2" ..
	"aRt92GursI7brsFBu2Qh+BUPtQ+Bum9oY3J0QWQ+v5YMed9XkzCoWZIu99mozPzJAEqQSmF506IMdS0uKW5m3HMyiwp4R1sYXJcu" ..
	"PbpXe2yZ9r+XF+fhgxvFEf/UWen8itT0wQBLiBM2Jck8V4CJcE2RPjqqYgcsmWhu1QsasdW+rYoc/6d10ai87YrEh3laNlWfJDeP" ..
	"cr6uWEmA1Kp6tlCO4FyODcdZta46OeYKI2BE2XMcnXWoA7wIzr3AGMkGCcDpZ5kCKPtDFSjWrXRYnI4otsQwB+NtMF82b5ntWr6/" ..
	"ycfYHqUIRrF6kcQUw/Bv9+OLa5iVplIc5jWOhpRZlkyqXD5NPkXUcjar5EMGAJmbTCV4pA4dtlahQLilVp/zZFMFJt0g1clApewU" ..
	"zGBx3eR1GpZko1emTaLJme+6dID7JQ0zMW0RRgQAz8OmkuwKQQZ8XIESg+2Cilr/Efe9AY7CeOtKvAifJ58qExcK6jFTR+BLCbtn" ..
	"4p2zRUAHKvXIvFdbacuSEAXp8xws97gH7cbSlSjEidY+3tgyZP/ReGiqVVADr45JggkxrymvJlAQ8VsVzU9wKI9wGRdZM6OAlWNf" ..
	"yScxvGxebKUtzXwdNY+jKfTrIzQh95ntyqX7waWfPXTBaL7EF3A0frbUfxn3WN0zwQlUVxPJexC/s5yxVL1g2EkLeMvyd1paYeUg" ..
	"BRJOKdzZAnoxfsWFcEUMRtkrNpsoy0GRYt7A/nQ4fe9bWY4dJELlxVnnCCIUadh5ApfLo73Z+cjClYianABtcBtC9jzIVU8VFrzu" ..
	"oBPhlB1slyD9XOc1EuI20ySdxR8ih4XiAn2J0MblrrYJwQ1ZXf5AMDEbEiZxr8+Yu9oTnZ7pdd6dsHhusukKXx5RW4cc3218Kql4" ..
	"nWXGeYEyCNNnprYBuQj7jfqqmcgF0BFmCoFsyXNWm7NS55zUA4ag8GnqlTGff+4lCVT+vm5W3fykuQUnDqyZ4PUhbITvtKcwgFnt" ..
	"01PMOSe2mYVe4i2GamUMtn9AgmVv0axbkpLNjDGJvtkm+UPdmxiMiLkVUhVD/2wkrd1XdyMQ28lmn0/czMpyyhYejWv2/RDZVhQk" ..
	"s+9N5euZLghzQIu6g7nHNTb+I95ti9ZViA38R+fNwMPU5OkOhtUmSWHzjVYrpsJ5l+ThVd3IgLAm5Mb9WP4hHoqy67tA3TrGGgLD" ..
	"Jdx6YmXi4e3v2MtsL1HmR7ToSjEXPCAZA4QSjC4dsC4UEZMBfcj1eIzA98QkmUJi5SbUgK5nv1tMLD+CERP3gdZU1hfI+79/8mxm" ..
	"y4orPTTZPW4yntECQkeLFmV5CCicGdN934orjY9/G9p3d2sTPVZ/mapIaBYpDnOj+YOVfoiTjugbDBDlNkLkY8jrtloW6+iRl/jG" ..
	"VE15sW0IUrJPvgpwm33lOvBx2/bVYss4XTmi1MtEOnDTKSt2orE+NIWIQSC7xFI9Jwan4JJKZpjZpD7e/lfYfrS0LgyORyu1qfTf" ..
	"Yjd9TA5k8+jNNqKAZvE849019EUdlOO3sCgsmtqrWXnaFW2j5+mCXwno69MmnbeynQMaIoeO2QoqUOUNJ5E52OLVZJO6fsy8HQd3" ..
	"TqWilqYD5u0075IAOmEM81k1m/E6KJxEI0748U/EGpmtw7dRYbIB9+WtHpxDwMrhBUv7TaJMuXXBzVgQMPg7sxQCwsGovlGeyJUn" ..
	"mfdlXj/DqAlrJNc+Ae/0mnnoceGbo4R9UHPgs5rH1lAS/d8u5X5pSvQZewpxLHu81k31A5WnSms5cumZbFG4RVZkvdiLIuQlg9D3" ..
	"iLHDvFyjvtVhXwIRi/qTdV+rpgeLq3N8iB1EOrkNvdZIBlx3mnYTv9BUGg6RsCVDgPjHt/Hj5yuf/3i2MVPVjw00xKQMKBdVqh7l" ..
	"CNL5uK7t1aWm7MW+JWm+UPyClgcxBMF1q+nMe7p94JzRfVBzFdFTsqE6wTqot2bne/vomkBev5JBhGBKbXE+tIwrlqX/iFlwv7c8" ..
	"XFINoI2mOYFRgAB7za3tLJq3yFurNhyPJYozOJ2iJb/WHEm/zfc6zzbnhczdmOxROrP8Hs6vO3D9JP5xxdjlNr92TFq4wwr6amc7" ..
	"l1dX5zvK5trNUiCARFjtNMJIQYdQw4CSl9x5BZrYhZC+2YG/OQTH5oTXYpQ4HeNGBjosI9O+xv2pqV3SPL4wNlPC8oeT4pRpm6lW" ..
	"UXAT1/iqZ52hAZ6lcVkU7Ierm5dw3vMmluW6iHaIXiVY/1Iv0yKgpgUZwXJvIzGU0YfyXj8A4QFNQqyvgdPTjwyq/NVlSyYjVACU" ..
	"4Z0llF+xeq0Kq8+EgrIpjGCcCHtH5LiQAXw9wwnKxwqUHtz5n0jasY1XbO4KccsXqYVov2x+4Ag3yNwdjuVQ0N4CrJM0MoslE+Bk" ..
	"BwEq5Fp/ypCpL4lvZuvSG2QcX4oM59EO27i3hT7VZ4wVfG9O4AO1BkX1/6ASUNgIFQkjH/G4c86TugnLki/W1JLPfZAuYtqNgmS0" ..
	"uiNOT2uWnPcy6ghMQKhYWACoZ7xzpyHs55mU2xP1L/JDhhCSdmuKpLTcyJNY0+/+Y1xqyFZ7a2l6J+p97n8o4vVRrfqRS+DF1Kdn" ..
	"Ej8qML5iqpXHEwbb7QgBYWnT+cQ7UqrToG59Le5srzR6V6WizmqFcP7pTj+vdrEEuWOupmhfn8NVt927U+m40tF7+Oe+iMFODSpc" ..
	"yBF1MJcUhLdjmZss04Ij8D5oG1W4Xh2IJVHLjAS/7Rc4ya9dqVmUm2cSVOUqiNdDME4ZuYrnV7sbjouq4EhU4Ks+LCIm24ckyRbG" ..
	"tkrrEm9zPYGiU1yGyeR3dRgRI6habKX2313cI0FLsfULjQ+gEO87gyY5LA3/OH9PV5SCBhycJY3i5aE5+O5dC8AR8d3Gs8YD5vrd" ..
	"kgzkJOkLQk1JOf0XLXGXG4U8nE7moIJd+9VZYB06yZ2Hvj3TPlGZxIVcr/AsoGAaMqOZ2KYbUH8r+D0n7ak6Lbj7B+opDN80O3gz" ..
	"lXjzHzHlG+LAWkF/akX3ZP4zVXd9AD29cgqY0BwueyhKQhrU1XzFN+HJd7Qjopss4Zcml+dOBtsJYq904H6FrlmxwaN5CxJgDvXz" ..
	"5DqFJlIUaSRMjhH+OHuR3ETWGgrfBz1LJDGcnJd7xgsAdAT/Kjljmp9gxUWYgwmGAeSP+KYJEf2AxQGwmr4sPbRdsJXTnJ4+zJiI" ..
	"MMM/udu2an4+PMIE56J7pSfp5AZ3YSDJJZWUkoRy9/H8aWrUNFtFrxGnHvrdf81dXES8oEXS3+aHY+VTubH4Szq7ikR76dp4GiD2" ..
	"mtUTYT6k38Ih90nE8+grmkH7zMy8fDK/p/+LDoY4q/5bE6iqPiRedPUBVD7XOyyPqnj0hLSA0+nezrDLS/UOKrywCg/wy662qPIf" ..
	""
local PAYLOAD_P3 =
	"rmn6mvs0HOcLfvTXEocReZTQfrmfiiEg9iSmsbz5z8vzSsuaO5Dpc/s31JeSMfPAUgN/I3HpWQ5p31G48MLZQe2bWtnWKEBwHKRF" ..
	"fJDdCA/ik4F+lGTjbPrhl/BKSdKm9NtiSi2FQrrAaSfkBMUTddennNrWfmVyXiGddPx0l6T2HRy+0Ooq9ydmsVLFeoUzRLN2tNn8" ..
	"Ljo6p5ZN7WMVHSmjVrjYfKLNxydk/yLEzHM2+rQUQW2TvtgCbx7OVcHvPAiuCDbGpJ4Qykvs336J6aYKt/mCfcwgoDjBnrbv+7bm" ..
	"oUFZThWT3kuLTjHhSc4f+V22/UuVrvXPc9F0hh9Ot7uiy7EjPh2jhTn8F6idCChIIll6/aUnxzWhMxJHbdJyr6Ck+LTTnyeLL51s" ..
	"1p5bi8mDJuVU9lW7BVI/84tHAmcZQdnQJ8F4tqR66iD330wmWK4oSaEk+YImdjFPSY4l03AZMTYMdfvJvHabXpjADsJ+KViL/2au" ..
	"QKdqCB/XGeG2eXI7MY8b95zCDxI32zaLayf2TSo5nheF/ZGKkN9am2JdQBqxtt0B0TU4wIGqkirAv0904yPacryAYh+Zm+0zY55Y" ..
	"/IqxpQ+nQmPSEIEWeXzgReJn+QPjS3RA96vtuepg52UirEQIXTa5QA9zvc/pHHfFbBK0F6pJxRWFEmujcoR+PFVLubo6Qm7BhO0o" ..
	"jD2GUP3eVrCQ5eqnY5KSUOHqWDNZKyMemdg2ZpbjChtHoqeTxuRGOFwGJplCDGpM0pHTBoXu7o6QwVCUvuffGk7b2eaGj4XMliQp" ..
	"mDkKqigKH8SKZELEHuuf3KNqVrlLXcVVlwkzGxNDcSxt6AL01lcIaQPx6mJJEUcBcr4VIpEZSbNnKq2DUtaiwnzjI6BkiGVpA9uc" ..
	"OuoYRKGa06CYBFD+h9qNOXQfcMp9u4v8ZPl0yEokf1hPjQcFm8ALEDJOsGRs/6ugtN0BytJBFt6uc6ZsiW52vbs3h2EA6+q3w6wM" ..
	"coh6kVApX7LGHmNMhPVETp5iBn8lXJQUxSWcrfZjyqo+ReISwYleLp2rSgTD36gUtZ8/5LG/hBuDdE7Arh+guQX6Te52WZz6K829" ..
	"6A5zBfZjLQnv6CLXADcUMNlmBXe5+7RbXpJNe80StHlMF3JHc1iJiluJNLcX+z58ZO0+NEuPzNFHF8dcQbsrKHSnsbxLXwDplCO3" ..
	"P14VjM8n8vAOSLF/CeaD5yPlGBhX+F9PoM1PzmY57j+EWAYjaZxcF2VojEhAPkXsqNRpC+BwSbGiGHJBrtBKdm8LQ22hFU3dbs/J" ..
	"LuLJA3EbmsTQZRLRxhl2uMh/Yv4wd7EIPIwCboWOcGKXTC5mgnFU7rebirigBYVkdU/dUjO+Np/JgkPgBaEtzrsQeWXb+1nMU39V" ..
	"v4Hcv5cN+f5v1lW6LL+FLiRw7I3WbPVzEhiSnaDDrLywQ+PFkCckOT+0H129mwx5bxG9SiLz2lImGVrj02yjnkeZ8gfljrz+qvVw" ..
	"rPgQNbLYx+kABDzlC8M2guCv1BUciy0GVX6vYNfMAKh9DFCxc/o4bAHdWUjM6Dw8VciFCsyBPGesmpTiDptrKePAwZwhbrZHvNjk" ..
	"bScsNXsIZj30msisoHueLI/bAsHuvJut+2Jwqvgn0UF1cD1UlKeS4ZSwMFKhEGHXztRps31ZNMAJerEWYQ3GEQ7KUjDtD17D3a9j" ..
	"pXWa0fFxBs7HKfiMI27j7xduV/CzFobUKPBfMwjcpTaOaNUgaNZzq2hb2hGJjAWJkm7e4pmBBRm8aGu2TKFNJAreMQ3v0zcxfGG2" ..
	"N8YqJnm+HmxXv26giNIHzWQyXXB0KYPT64jhrDK4HlxMkJvtqsrkETrXCAn7wefxjJ/JLt+AMFZaw6mgurq6xwZq4ZWIT6MHZKyy" ..
	"Ox3ge/A/gieLZIgtd4MZW1xuszclwiUVTHy5klgE+eOs9dBBx9yyEfW8teD9otDCGtKisLmllLFa6FklzhjRcFOGLkBbfVVt+g2M" ..
	"TmLa42N1eHrcOT1/0HScziI/9dIhCr+v++714usdQuNiD7A5VumQWFuAAnqvMNGw9wHdYojLk5M1xeMeP3Y2xVHyObT9/F6miIpf" ..
	"D+5xoKYXdVS82g8BYrffIvSXe4OdJk7zzmZUZ4i5Da7wZFl0stDMcS7oDwye8MQsL9PTh6a1ucQ2nXb5muzDtP2xG7FIeizmtKue" ..
	"cu7u3N2lxjBU0mYwMJZVJg+GTxy+yMsyu284iuw25JpAsNbSC31fkLNcFG2QAGlaI/0zrS2xwzhTHhAbq37OiYlotoCvuv5bMmEe" ..
	"XHg/lSzbb9ULeIgw/8EQIfWalT4V1rD2YiPpAnjsG69FmUmqKV9cOLthfT3+OdpZ84u8MT+inhVPNog0wbNMT03VvVG5oNmp+DCj" ..
	"WAQg++FpVEB+8lTmuELbG+wJe+wlXjrSs7t2O0Y0USuWPhm2t018rbTfT7Y2SiZxN2H6z3ur7crOvFphvFvaFAo4fW8U9NGMSRGk" ..
	"6UJlYEJ1TE4P95XMIUqZtFI60HbZYNjTU5fQONkKQq30a0X51r7+NxwYMcwyepguOBEU9uSEc/poB68oKDIMqAu58X8X5ZcA+EUW" ..
	"BH4eV6kIY7ZJF7utZz2lo0OzjGNbPZEM51N94+lCsrIKzK859QGPiYdJFbmvo4JXOa7Go3EY/SA/TpQXYSlm7v7zZySwsuD5Ldei" ..
	"DiomPOiQ72R5He9EmfveqySp/kWzum4SS5hE0CvcRl90pfDkR0DfN8UtFCxKWGV/BH7dzz2qssVb72hgugRT4j20LuUkR0lTrro0" ..
	"h3PymN2M79Ct1DwDA0E9xlu1klbr3EEmvsnD0kphLo1yr8aKqrgPL6BVfsIjU46mpO3HbUDh+unwQCFk2PbJieMNUPsXe2qz1qIg" ..
	"rjWr6Pe5z97mxwCjD3IpT+mSZkDnR+O9ECHL8SpUrOjJPQZMoTr04WupNKPCpv1e84X1fhLZa0me9OLKk5R76i5GgTEoXR9XP2Eo" ..
	"AGBj7QIAW7ZCj0GWyMFeVAaBFxYlJBXsMmbqcnIbZfHCJPuef2ESZfOa2FHovLZjkeNGRh1xxCgo/wUSegJVYXHd45xih+5BCR8N" ..
	"cGpAEj2cy5JxzpLjoHt5+Y7BE5zCnSeEpkDUGmcghGoHqLgiNLMp9IyphnzkZkkywUYnZYA0iBtCufrJ6NGRp6l7iVRcIkCpv56L" ..
	"AU2/H4J96ksHbLCqqMdbh0lWez3/IZgfJd5jYyAPIHqdDnhNLOMhCORmgSgUdAtiyUyJ3JE61MJw0yRpA5MCDxohFXthBYGa+aLX" ..
	"q3EbkOX6YreGANRweWDR2MKK1kBpfpsFrRimCW+1Ps6ne0mtJpUzLU8J1vpHleqpPckfyS0bBt3gRAvqwGZOTMifINwfhyAA24kH" ..
	"5KJbSOO36jC/K2uUxe3UixxrGdnZhJb1g60Ba8w1GFDICLBfQ5w7SH9gPb+mciX8OWms1LarF+a/WmA7vmlxZ2fL5IUYHGKYNZjs" ..
	"12CLCKBnUPy60vsMApc3BHK85khlTjAQuK1wQuhWc/YuyNwxbR4U60Nqg2zCt3WRQK4SigUiBAMim+bye8EGbsDq6npw/ePBh039" ..
	"hUg1MLFtNhBvrcCDiccNg2mWNjHWpbDB0oaO7Cetv3to/EdTYtWXjYpWMYvnlXF37+YkXpplm7wrJq6hoD9sXqat4vDMJUbm/B++" ..
	"AKTmsMcyljNYdFtGnbyRTweYsAADTWdm431ngdXq3aIyJTTcLU0Abvlvf/J8gMl00K4OB+EYTfw8l7g6aH0X2skuYzzOBVlIEVee" ..
	"8szTg0o+awwIIFgR3T6fdd1yg8CWA/sCQ4ISEqlV6m/JCRV8gKjtOAovFJFclB/VNOHHyxr8mmb19ts1miP38XfSz88ddsEx6g67" ..
	"DCmDkNrV8ZF8/c0rVV5uZzznOLZMhBQ2wNFy+RlyB+q2R59nNudeo6QaZG2cheiyJkEqj+F2opwzaFbSgOOvJyS3Nj7Zr5TzWops" ..
	"e49lg7LkKSItV8pMXdu+wlU2UNIFJhRWW4bOPdcvn/UH1J7SglnJNXX8l2AjpxIF6noX1PQOsdU+0WJW5uaugTwcGtac4hPf87J0" ..
	"MqATVDY/vUPfhSc2UiihIoSVJw1UIq58low/BUWk9X5vqQ913WyhGDlWmxGX0fv0Lew0NFgzqXrdjlbHsHdR0X0OPx8JGRd9UGkP" ..
	"L83z6CDYDRMXA5bq7N697pB26+YsIoQlsSJn2UnkRF4rg6e1VgteniDNDXrHIpxSyUECJpQzvYLRFlgcy5KOkq+igIngz3/N9lZ1" ..
	"ckXpXl281c70+YDSkaWpBCcDiWTaZD2rI/XH8NkfdRqNQ8TT9+G0NZN3fV7d6P0phlq7uOTAGRvMQZAsLjB4KLmhRDcABgSDjpfT" ..
	"t0JYPzZ4ePkUhdz1gnVC8K0xQG62i4hhac+F7MegyLmthLebZ8emISK9bZvZMkscqLp9IDBfVMROwkW0Qc1GPRl1y4NlWI+13247" ..
	"W49WO9N5pUKcF51Frb6TQerlH8eftmYNZOMKaCF6brJUCBEXSgjHZFBLuCW59Ov9soXb8C2gU4BxBlRAW6aLsp9n7dE0y7HMDOY4" ..
	"k6F2zMUtRnvzuH2jGCwj1EGTzI+2/pmc3lfQ2C6XbL9ohgu62fzQysETwySD2X6UWmbM3nFej7a0bV3xTEf1FRifQ28SjHLTR3iX" ..
	"pPRhIm8WQiZTfFiB96sqfV3ZJfjLZXr7GUff6W2yQ7pN/6chooW5/KwIEwpEKEk2sCQ9CxOIiIeXcxwm2/G1J3GDOFGQDFlewurX" ..
	"9HhMARuHE7FDyGHFPjyt3J9TeiA5jXLdMdTGZtf6W18Dg/zC8Ca6W9XNky9nlumWKnARJUl+Lm+M7Ybu+L07vKwmdx66LyV8hneQ" ..
	"EWLHMnRkeS/GUQHtLjHZ9mH/Ijh5AkwodwNiGF0i2uo37RMs1NVoeha1nhOASUvZ03KqoOF6teXtz21iojyuEj2XzDPDkj37/AA+" ..
	"4q11YJW9x8qf0hjH7eBMOfawgNUdlZCHIZuuDRFi7AHl5wYQRkDmReExor5Y3u8kNX62CFfe4eNsfnPqvFlqHufGZJSmEt94ZYE4" ..
	"YgZ9c8jP6sjn/0b/lxN4oMROS0w/xXR9doBwjGkFTHb4LigoGh8ppaBiSxbZJQhActX2eELZiIiDqhi6PhVVndJXdFD/Sw5b45kC" ..
	"Bz6rLGnBYae5sOeMSLecHZo0WVkPO3ADAcpkIfP87W94WGvCMBh13We3dUN3sYN4ZARXSQkvRmvanrN3EzHAKaslAnfozQaIKWol" ..
	"9S8NS2cVV8QTUCDu5w3E1/5bT15lIMCI8iKYxIGND/oj4zEeFCWcIjHGb3fmn6xv1IzmmJrd21L7LW1Jz1k35cLBi1eGOMspNAYW" ..
	"BU49/iYSCFgzztVQE7/AL872H7jIxKDY1teiypIQRwtVcM4bEezYHMR19M3+trU3REFcrfhPWO+xrt+TO6YQk60S9bnXbPDE8oj9" ..
	"np0tfh7KAa3cu4aAokNQXxRy8Eta8Nrk6r4rJy8j8IQPAvgRcsy/SVj8RZ29OTmvQaoFAEOAAUO/yeTSTKHX9B6X+fT5roHYGRq2" ..
	"uBP6dNDYUR2obEwZU877k1D07yzyoqjFSyn9XSx11TeUh/UGqvbtKCWrx/toAUSsDTl7nE0/FPAW2oeRjN89Qs9MLWr9YgEsDqIK" ..
	"Z3QECnYYKcgzh+f7EbSftO+dcjcI5DbXUV/bM53WbV2O3dtOdRISG2ARK3X6254l9LwP+fmZ6D2fbvO/Dor6Zx5QyTXiVTPUSrQu" ..
	"61REbDegNBVeDF7/98OY7yyc81eMhp3MOu0yA8AAbmjk6zjMPM48y2oZURbgkp7ThfVB6BGxEWQBpEp9pXOZFyN6bwIqIRkRSLeG" ..
	"AvhmJOzFr3Pz1T3rpCDzo8H1RCEn9TREIb1w1jv1WWRQP5k+sipoGzI/Pmo0KbaCR5pnriGYqYQS4DYDaW4W49IAeV56lx+V1Qep" ..
	""
local PAYLOAD_P4 =
	"GacnNc9GubHZz28YAtRiH/dvEzPUCDcbjyk7l5miXfKOOIykrlgGFi3WW8RAHYA5gKL/laEqm1mLHb/wYLC1ypz6rP65ymv5NvTJ" ..
	"d2wgUELEUKomZo600moFByolCOAmZpH0Fy3yHhEYXrykfDbAUx3G0LJmpHFzdgVVmiVfF7CN8pLxbnk4Uth8dksYYwiFW9beA4EX" ..
	"blH5vwzRhmTC9r0nH9OE2OVkpyg/14mlp3hmlBcq/wcGMT3w+5geaqHW85tDO9IKOgNFVq3ZpXVWvt/vTKEC9bLGYg9jFuwrFZbN" ..
	"STmMgssgG8v4Cj6wIxyhjB2sxqzxhVv+STy8v0Frc90xK+Wlo91OyMt7MPfbj0aAhq44A9uCW5IqHgZtPHQg0gx2MJJ/KcJQJAB+" ..
	"JE6GsYYxf4rhyzKh75O9YG4smWUXfeQ41NO5OOgwQQ9/fRxss2faY+YXv32JJUSo+u2GAPCFlm8tGUM1Y7z/RpphrW/ASK4Ql09/" ..
	"A4hWGki91H+kjfDEv++FZ/J+sqn7Wod8zEZ+wtISoRSMV4BKz97XgmtJ1QU+F6gjmVZvoqINO2yB6Z3hlvxgL/ofIbJs1uFRuFeU" ..
	"rzu+JkXSyHSusWW7KvCFTd4QU27FtvbCjxiG/HTRH4tgYgkmjHHqk4N7oqTSBesVKI2KPBLyxJs/ubjRAMeviYnpX3LGTr5WhXN2" ..
	"cnFZKQ1LuRaLUR58pMPs1uLDvgxEfiUJiYuabvdKL2nB//RWNTs7Vii6SInxmLnIa29MLInL4UtvIEVcGnuBj2KEz+eYbji1bdtH" ..
	"WrpwTrC6FikH80jbVs8VSQm/QwCDo0NBKMa7PdMTMG4xuDNQDLZJ+lTwfj+uwuNmzs22nZWQM4fUqLxGROmTXZn6ECW7B9LaIMYx" ..
	"9BuebumuKvI7TV5UZmZwTy0vaIqhgsJYMJ7OYfLPk2wQ17vVK4vqARdymQGZYhervamjDX+6ZSTxhdlNNjzGehoa+DOhr/9yWJ9B" ..
	"5Kq2u0x+UYx+nPiRlFNp5uwo57CKYTRI4phI1daorzOGA07j32XbVtq4GRetwqal66zGxo5NoIv540pStT1iXbJSnu0AqYhahXnT" ..
	"0+V+0Mou8FfJBAh+IcPf82lqwwH1VoiOBSGMZYhMEFMguD+w8+mOSFjo9vfNdQ5dvmMSrWuKjcNI6IR5zOcPmXoiTjy/6zI+YaLj" ..
	"V+kofNEsxzGNQya0GLA/MuWAHrhjTD740ZlIUlIhX0TBqgjYOPNRVWhtJgJUExd/367CPg7Tt9lpmQFKtiWbIknAthPLc8zo4wxF" ..
	"CzDtd7fr4MgdSlCxqtHp5pE47haUUFcyzb3v8H8E/2e3xEgxmJYjvjcVgUGI2ld3CHtNq36afhjJrHto6+0p3rX9DtnnYWlKrafn" ..
	"81kdGtPUf/c6DhXnDKSFQxrASigYMD5l9GVAvL5J54idjzJygyZ2rQFF2CrertXJTisdNoHe8P27Wfw84t9FCNawHB30cLOnDnB6" ..
	"lijF5OfkpUvFyXPBxhVjM0nJmtc5uOWYSa4QJIZf4omZPXZZxD/HE3X/68QHRR4AuFx1+mgN7DSjfZZqWr0Yh1ZhVrPBgs08s0RG" ..
	"Ia/S7UUiZYXWYn/t6GXTDn7fFMvmfIJKyapLLjRiVsRUzrloatYVfYmEMI256t6mfEuUR9tpMbYIZ7oVVbFZ6PhWpeSBZa4p9VE5" ..
	"bX19eWwXFNtuyVTm2/C3Q/X0FW9TWumDYA2eDMID70TygaDFhLrFT1avnG+Oq7lcPeI7WGx+FfrtwumApYmDC7WsVtJMHsm86sHR" ..
	"wipo+GweUHUH5oQfJbEVW3wu3+GB5UwqAZPM7qY8NC/HcU+OMTWhOSJmbVjAsEPCeGbIVhpo0p3ntExj5q1fHU+dDGA7QXaI2hBa" ..
	"sWFOe1eB+gztmkefIVQUKB5Ufy3RiwienzxnjdOGP46/dKyfwqlpB+h6ix+CjUm0yvg04ClZSqhhOBK2BFHQpGQYdDeFyQLdbiVD" ..
	"/RaHOcn+xVIRXC3TpD0SjstXNta8YTTMhB9L1vbm934W+R5IC4oRdR4qq9dd/zWUlSNnYrmXIHBte3XSIZCodw9XVGV0anyvQYPh" ..
	"bdRuZyDtFtf3oEGBLoraVpcVAaaFDB1GmhR3YEt3Il2rsU6RGpOHVFBzq7AVkBhfB1k5cQek1N0Ktg7VB4jEYON9AWEz/vvRnz6Y" ..
	"vd6D5AENQJ6U7Jtpwa0JX/qcTwGl7V5jM+P1jFL16EOjUypQIIln1we8E+zHO45cGAUP6xveTkqLs0MZlGVwpsq5w3MnaW2e6qDH" ..
	"8OsXBOcXpifEUd7Sa9wvZpxJQsNxI6+NS6BWgJ5w27Hu33ZJ5exxEVoWQD707IQVWM2hQrDRlk007ERtjmZvwUi7Bl4b8i714A7C" ..
	"zcTs6UaemHh+MxN7tRbi6TwrqaiNcGeXq2U0TdX8diDd5xtFVkpTRWxffAzvGtOy6xMPgwFqjwqucWPeH59SsXHP1LXscjBNU31K" ..
	"HNdUQ72KK5827s65Fuv8lVi5PPA5IoSt6Efor+A2e43ZQZOClnC8jebJCAQNX802pYa8rPTk1fUn3BHn/GUjbqKkgnTWaBqFM97b" ..
	"i5+12oZtjUCHK2vnVKhnv6oticd9Awjkr0gchS4G/xjP2Uk1STLQObli9ZXiDY+1xbZJXA3o+YKB/g2VEZLyF3IFl0RET3gyUGeH" ..
	"kNpWYhHwwD8kfRicoJD9TA+D2S5qpuoWhpj2R94mAxhBHxEHaeonz3JqoptD/xs73qUaX4DQG66Pt56p4Md7j4mVKvdsqsvnqn1F" ..
	"+MgcE09IahCHd1w3JihzCY/e88dm3ozCX/Hs7KxmB8uVR7OYa7yPozHBHRQLu2Zxv5TiyK4cYLdgttEEONFoFLrfMWb9Ep/N9d00" ..
	"G9g1mBgASlng2KkLtvLuP9vcG0kekvjHJ2VlAG5YrMdLvlq0g46gQdrTL6m2nrbxP4fB7su8qdiVDT6PGXh9vOnhADRICW2SB1RO" ..
	"yZOYBfOZTSmkG5psS0b8pnQ9CgRZCE4LJjdfvT0jU7nB8AsxE3RmkN1ytT8/cWnsU1cwixpLatCkZb0NWv2lsoGTmjdNFi29UAM5" ..
	"yWBKBrFkzS1UPB/qWMV2NREOW2Ewmj1cviPtbsYwLNmOyQdXTtkC5AXY2JO00AkA0mzCMDow6C8iOigDMUfch5dNgyVWrZg44ucB" ..
	"GeJpj85A8W8h8GSYKGH1Wkns3mkT5dmU4jycgrbHX+lxEKA5MDNFFCIW2nd8qWgF/7LpK/X4PKKyAiF8MSgkPU3tS2wz2ngkXK7Z" ..
	"T8U7muvP8zNc+9/TpKyRB5p2wz6HA5UcQS6GMRewCaDTK3VRh1kZM28YCiZBGrS+NSWwusq/wT4bECe0NVocusk4TTGzbinI1+PJ" ..
	"/IKTCWKAp6p3ONBtUTTXZPPiw54MpN+r+SRdYbgicv6lQuQ6pSdKKJBDNzQ2DV2l/g5BzVCJiq7uq+q0IFk1aBrwkRedINO3NK7E" ..
	"WG6vzh04qnipqOjEFuwPeZnX2vHv79FpXu/92J5nU225svCjuWAsOce9OZlTSmFI0koCrg1yOA/bekTlDsqH/vv4qciAtUKq467J" ..
	"tDy7FTR+MmXB3xVPjG2GMGyhs7eN/kRDPDQ1dZJF/na9bfDrniSsT5UJ9RT7D46HFbk/g6HgpCM7mb/Hak3n7KPsh9N8LatPNgho" ..
	"vlbZQYFrFveOr30KnyrIkINfJ1LmjSYooVu6qXE+pjFCsP+8nyvyJB0APoIIddxnf8t0BvwaAgSBgVUpNfmK+n1SAlriarXFSPrp" ..
	"yqo2Fg+YMOzcMRBfNn/cyfJ4njPr6yTglOP/J2krvcJugayHyNKtRegYka4NN74B13qao/OaMjVwtuCYIAeyHEeN5Q9t32Pei2VK" ..
	"7wTaaHJv/dPvY9th9NV6C5W2xx56C4yBq2zULWFpL49fk2gGenmuUd5te9miO51QEZ94tJ1HCt7BwuSfzOSECdXNNeVXOgHKn9T4" ..
	"uc8BeUNX4wsTrbNODzEw39gZyDy5hL7EcmXW1yy0fze0P6NzhUXhjKWfdFEyOcR2bngP2gKBnSPoSYBeDdrBzgIm1CbnogDe74T6" ..
	"L+nVADI+8EgP6KhnZ629nY7KonFZUEeAOh+ixSe0YlcUzE0qILXvECCiYruNmE+itcSg6crg3f52pVWnbSPXjFplF0LrlisVuy13" ..
	"bHIwv0KQuUGLqafoq6Z1U28s5NZdg45MPB6XcGACcvyk8vtgCNQxKvbb9QaDvCB40rZmy9p5YRG3LSM1O7/bKZyWdokZL6TBwhMt" ..
	"qtzPx1YRcxWpVMSHDTpuozWRftJz2MTcIRKXZwjWnKeqbyO8+tYG3STxAxHOlvuYQzrJcgPOd8pWWwc7eXdljX3Iwc9kb/uTAEQb" ..
	"Ax8kKv9OuNBoSGdiBu6gH3OhwHTKZVk6dIN+PVJ21/Lbq2mQOdHs+I0Ixw6L1U58ajzTHg1S/gOwtZ1T7gjW14z1M9gmycSl5LNo" ..
	"DJzb9f/zbFnNqWniNBvsgb0AIs0/s4zzuXSaqJdO65T/JUJPSXIrg8lTx3A9zVtbqQpjF/xHDjKoFlTS72wQgHsQeAWLzBvhX1Pt" ..
	"sGBiANKwt7cmyljQu2AIGMrkjFZXJcAth/voX745N7TNQ0ET81r5z/feuuKscrW+/1BmQ9Vc4avVZnOjFhzagUZyF2PQacve4hkh" ..
	"Lg44EhboLcV1aCzDk0iPpZ/yvvMOIDMl8o5kufZU5TyekzE9Q3mHG5Zvz0RhEhS7aqMIBQqQoBCKq9kXDq+jPtrFVG2GLQjJJrSN" ..
	"MBBcyQHvCKl9XDmLJk0Vbhf0R7TPCm4b4wgpF27sCOvezHFESvppFhJiNCQxqFclwWHMRUBxDb/XsD/swNVUPGEKHUpH2JeWxwyx" ..
	"nHeNir96hBJZBow/s4A+uO5QMguN6QOIJ5JXrRYKum2giIKfZ7YD9vxbnztCd0Tnm90SYwetar8J8mjYAATPOAIPQWoyivDBhEKJ" ..
	"z9AfwsRdNmWTNIHH6E6Xsb6S+9hJy2o8RyQSJfLS8pX2yhrBqfbompammfQPZvY0sJAJMffMmmmtMzl1leLShPfD3pSlGgRXVMHu" ..
	"aw6WkrIYcsAlwVUkDi/AQ+ZMme++ZqR+c7ndJvAjdAKgGqPjjQ+PFP1tHMCczTlFLDeb7VMbudNxMoS4BqWjVj3hXfRS+/duCUd4" ..
	"LPxIfnTP7Fduqw8gtmuB6wnIAjl1/7IupD2qDxf28+VIXttR95YJU9J8XPQMGUK7ExTKA6wzEAqfY2wqdjcI8b67UOzaK5WYvqNa" ..
	"MGjsiDETyyL5XgPUJDrOI5XhAbFlG2ZWALhk1mKIMZlhFVhCV1vIxF91XovAnpCvl/eaEJOIilCUqf0qbpeHverPX/s4k2p6ZiII" ..
	"p+8LvDZ9TVPigpcH8NTADb/5oJT05y7AYPJPysUGbDc/reRlvbBTTovpAQrZfDwYR6fWdO7x+oeLes/zAPFh5aqel8ZpcvLD3+5G" ..
	"Va1CBZeeXBn37+zj4TiV3juUK5DqwHUHtL1lfaNRMFT3Sy8FHowkKPh+r0OW2H1lBcC255Sedfwf7iu64/Sdo1PtVB3mmnjdgwAG" ..
	"rEu2ILoQwV8CyE6zut96EdkwP2wg+Ktng51186/nH3oNpOOnMjYGJ/vILly4CO9jd3QFp5CAEDE54cXDuxgEUeoi26+kj3CYQR5f" ..
	"q5rlYevLXWudUfj4Gn115grpz9Fvfj4FRPOeUf9Q9fTq4fcJzfuMir6xBGsyksAfnyKDBeUb5ok8xFs9PwgsQmMGb7RqeHH0hJcw" ..
	"CfIsGvteNYbHwC9TN7tVmJz/FKMEx8HmN796ccoZMraPwJeaxio37y4Q2LdSPvehKYSy9KbtgmYPqLum1BFYNBjw80/Ly1Ltyfu9" ..
	"II5kk49cmx/g+bNOwr3ddnrI/8Lz+KflfmjN58nlUe/hNpIkfV4pIeKTwK2RDiCiWJknNFVEvM8s7rRBVeDDIWK2drSp2IUfLoDQ" ..
	""
local PAYLOAD_P5 =
	"gkuBdiMuNGvtDzQt9MA50vhVeUXA9+ncDEZVhknJupcajr7aH8RBqOa9q1Dx5uGBXqem7X93pt7cashTvZ8fWxO/VDX6rqdpb0Lu" ..
	"Acew4Y4qZmJOHYqlYzJ10qNTjj+LfM0+nY9NDdHXLlfsm9i6Ps95yGe1FWgvi5u6+wvYWo6hlQXLjSpxtGyuD5FrzuUbOugZQkCz" ..
	"rEg/M7Y7T71lSvlsBshLLib4i+f91R2ORktgNM1QTBJkes+Yj+v5FPXR9YAcYJgRHdKI27XY77RPgYNNzj4BoCgvwkEqw0fSa9/U" ..
	"lXPhYyfrMrQPPD8pkPOXfRj2rUDBVwczLEq6vR5QepTn/7NJXB8hQ2qNZc+Lcm/k8755TR0hpBhFDgEi9ZclsTVnhTLTCHWPXyQ1" ..
	"qeRrCAPnSCc5wVxt3LCrFptMCTy1rpKMWVLrCtuiwODAru0GM2jmLDxi/epreKhdIH7FD4cEvkOGt02737Y3KpveShSgReP+UN1d" ..
	"SriLDdRR6Whf+pfx3MFL1exntlHe1E6VcR6m2Jt6oVd+1W9Scn4oDyY4552pmU9O7mTGKXRFm0xlLlIjzif/8pz9x4BnLugGZMze" ..
	"jVEKa/e+2cxGXvUFoSE5sdnS5OkdhSxkEBuFDsVWjS2eh1pd4IiRwfmpqKK8po0kqGuZCW8TNx/QpycWpkKjKs3KkHllzAIvKuxl" ..
	"lZ8s2688ucKOknZzk3yLYZa/MX02cqg3WXOfb7NGCX6NSlO1Tfan9yXCSVLeiiMiHW3XQAgLk+DB0ynL2WQB7GnlW5FJ8ASA/ErH" ..
	"oLwqqpYRWKdeCrknd2Vxf1BzbWmyMW6lR8q1nSlpYWlLIiTvWwChAVON+r5l4YedanWULJOJ0rHJ8olZpVm7MvRBgAIrADOyHhW4" ..
	"5vgyQCFaCzxnST3p72YwPSR14Cb38d043YueOXIITxWtdE1l6Xz/5JYIx0IGlJltnS7MGUUiri6SSrP5cX7utheYhPYkQAfb4aUY" ..
	"zEe0mrvVRWluNCdyzZi6Zcl6g8SuuHCFNjb480g9yIVO6lkgFHho8SuF3hgPDJXOL9lZ3xc0L7nbD1wyKIi9IZmwvhV1JtsiCVqS" ..
	"aSDlOMruzDdNobaesjzk/NlEhutKZ57X1H32EbyGDjQ9PVchqCtutDVWSns0rF9i0rtzdZ1aBUWzHEeAHqX3F3Orp53ST9vTxT3P" ..
	"XDm4trBDrJ5yuCAbVoN28KQyzI0bD1E7/O4fYMMF9OO4kOpPab1jXG5AivLNTdEkrTfkNQgU+adJtBDA6M4Sz7vy7nbYOgD3utrv" ..
	"PsyOd8qxklyM7hlb6XtQEJGamEDMafGdn/32p5NNfpPx2cwKa64wlkrxFr2B0YcWvYWfDAL47HyuauWOGEBq3BtKZOyNFN4o/8FJ" ..
	"VkYgoF+1f02drtGVp+3xzsBPN8EuBtb61OYcIIm4JCME8UIpSawJlMQDkkyXze5wbCZsteV42lMiYY926mk7HD6aCvwqUpLxq9TR" ..
	"5FSkQAJsUZ41VYtv+QsuOHlWCo4fewj5Tiik4yJCjpBPG/mhH0Rpb9kHm66PQjMw83hKpnJ92P4Y54OQKZirzfKDySypU7Itygmh" ..
	"ZlI4VsqpbyOu0OJmE+5uGa5cvnv7/WyMLyCXVKFlSco+93c4ayDzs5DaK19t0i4A18DXSH7YBbZ5DH0JzsstjF2LT6nDwgMgr8Mz" ..
	"eqc6JWjIx7pxwVfJUnNY1t9UINyXlL5owIqxqCnmPk2zXYOfDesC5iXSoba+5llDta8T7nZ5VH0vaaDnOC1S/28N4XzyKME0ksHe" ..
	"GDIzuw1GyT02qMw1/R2foDn7a+Jd6keSUHd1PQSGqFbcaxZ7ccDUSsgPAOiFQclAXIEHBnX6XJWrxCw4sTFiiMyAgWQzVAHM32hL" ..
	"XIPXwohA0EcDrNpuILxPEeoFFd4UJ42I/qLFbalpHtmr8NGAbXq5sqrB8edpXOqA+q12a49lcaTZLgUuV4JwTL1Gz3SzxeXj4PkS" ..
	"5hI2SGtitmU6CZVaWtQJL1QcHJCFszu3DIqV+qtBucDJIESYbaqnXaP2vN1k8h1irq7pDaI/kgxPZL6X8zfVSFuOBQJgrHRBezns" ..
	"cqxpxzjWpHnQ5ZYzqxrnqzEeQNJLsF1FgMPVUT3YsL5JqujTohjLb/5BwZyEmiDIyhy4mDPCpkg0WqqQZEcmX5NnzbvsNnInPH0k" ..
	"lBlRzF2/otbyuxXGbeWkuT/tdZpKHMK3U1ReLDNRs0C0OyW/WgGQxIt8YXELpG1M2cMgV1mW9gJm4WQO6yr4cARF9npJfoSG2lQK" ..
	"C1mSctrC+GQNcZ93NVri/JsbakgxEBPlStBfUc6gtN20g+eQMXJU+qSazW79SuHXubclODUlH4dJCsvCj4l5o/7J8cwhuMXrGd1O" ..
	"GJkd3G1t94tdUP+TyMH2EPOdkhycluzi6kIzgeUvyGEtDebM22Klaw87Z4iOMDgWNFZnflQEZE2g58HTmCmpEb9jTNPHElOJA6WW" ..
	"Ms5P4ZIOTT5aY8TNTXCH7ZBlGIaIsB/Dgrt9am2f2fPED2qth7XDbvfpZvjAlyAfDngkqYsyCRNm6OKuzRsdUeO0W7uNe+YEJTMd" ..
	"T5vS463yOctx/6V2K31XWCmZZdE/WwznEZDQuQjgQPYSYGGW5nnp7ULV4W+m6/JGrGz0LD4MOSdcuXfIxMH0LYPmr0jbsvbXIAau" ..
	"qwYUyDXFn0MIcWIICrx8TVLjTDnQC5QoZ1qrhpYmof2AfzFLupOEdNmGyt4IRzI7ivHVGxaDZa8TPascFf3V7CtXGJekdO+uhvaC" ..
	"P9sRlB4kyhLqougVRlBmG/miKSJjuznyGsBX1WT9i+KyY8ytmzz66vwLvFBvvz+H+ERFRiO1hGrnhP4Cv4xFRUMwvDCLeVq1XutU" ..
	"DvxSizeJoIPJiHGX9TLGaJ76PpohDhq6mHZjsHzHESC9KDtEsRPATQG3iUAOyUY/Honosv70iR/dcsHqmj6ZzkF+8r4s4jWj0YDj" ..
	"IiYgs89hDnZZNUVYTOk5LME5j5cvsJ5LmhvcoJIlO7/b6EmCtGZwEGayXW+jaYB4RurYP7TdxpJGvVgA6+xG366e3cpq/v4onsY6" ..
	"p9c1I0LBPXvlGY2x56dpGx3IRYfr25Adqco1iv4zvB/qFe9Oj8Exx0YTvI/TOQ0kB+YP8h16maBhO+IjIf5Ct4ULMSPvE6a7yJ8l" ..
	"CfcFM/jzhA6AJ7xNm3sgaJKVY7qUvrUG1AZ6Je29XhaDyvlHdKHAlvyIeNPLayc88uwTUGvhvgTEi7sPOSVgcYyconFtFEL/tuuv" ..
	"4Jkf1dXVMDGd4elTceFFPIJz2JiZuyftmxGwJp1TRDdKyHvSHXHbOVx/x/dYTe1I1HS7Bicplx/BoWMssRJBtNDr3HenpeHGQKIR" ..
	"sSM7G4QSCgMn/B467C+Bckr9rYMxO1NxiXclPbrghdud+5+XGXG14tK5Xnka9SKf0wUPRR8jfOoMxRr2NmVbnOjiSuqBgyPsBylG" ..
	"xJXgeDCyqRs2UI6LynHdeovTFSh9Lmo8txc6udw+6Fu/bWynnhe9YyXTKauOZm6CRHHx9jOqpSi7gx3fzXQ8T7qtfKy+m7c1SCC+" ..
	"TEQTOvB4oOT9vHy8KDQFnsys4LDM/fJX26XYmGRJ5+B6fxCXrM1CXTru5/8N0o83RTwxZ82Q1lpbQCMm9/Wti3wLPIu4ulQwDwLp" ..
	"Wna1V9IlCIe4cbprlbvFumujIE/7I5vRva4iN2NPBWBosQoMhV529mzcodM02S0yKY8CHdlHWFrTgIuocWYsprFR3mfFyqArBFqa" ..
	"nF72R3SSJmOnsQiTk81XYb0x+kgzBqLGaIuFqsYaMReiqnmo/wuUlOQHCqggWplnVihn3tZMc+RMv1B35gqbLoRM16xYIWuApJ0J" ..
	"P06mp3sVbNgHcNcxWm9be+AG+RlkuY/2JfDwESYCBhcbI7ODDAE7NiKR53CeV6acgg1JNQNwgS/F/Htpv9iAKqg50ItuVC7sxBie" ..
	"gSKDca9jpTH367g5yFjPHMj2r1GDEBMTtEHwKkeHqa7oNLciXA/RiPhoLe3qHj++XCzoNrldMhkrVVN2p22tHeI9Ht75OQIBcF4N" ..
	"0EatCeK4nH4Pc7yvHd9VzBQh3SK2SkbT5sJYe0EIX1KFSTphgHRpvERih3McQtYiPNurvzPkgKD7MHT5i8CDAAlFmw5T4hkljLPS" ..
	"IqNK9I0IN2qSq10+h5SZyVIRbFLH1jrl6rMUit2e5czNWTHoF5M0KfNV2Ym1DG+Jhcu0eu8qZyzdWXGuqXJCuo+Z60abUoJRdJYQ" ..
	"NnBxZm3gPqqGDy9m2FljObnC3iRh/2UN9nMA0b9XU9DxEXTFowohNVMqlFU0VyTQN/FFdbDkUTxNZ6xIA8a87+thgXCTB2ocpkgE" ..
	"xwRH0qNILlDd03lMIi+UBMQWCDyXxLDAvI2UbUhhVjfmXDDEA/vO9+xAgF6dIKlN8ddpEiiZ9oCkGvk0isSRLhxJ15L6NIhfszxx" ..
	"yeBbS8Msw3PoC3btbbwHVKqho2zkd4JL4xZbo3kSqASZ2GTlg2wThHM+Ht0Era5nHTRI5cGPVsMitUk37qixS2PivL+gvKJreXSJ" ..
	"aua+za7MO+owLk9zbg0x/kcnWdTpXot061CbeaEFYSLaPFINWHx8zspGzG0sdo6NjTHyAmTFsc7FZsc2lj4aYeyVzr4KlpHtSRcV" ..
	"x8DMlqED8FU3AjivS6cZavd8q8ZysDEv1pqdt5bB0AiKrKk/1+U8M74KxT0gM49Kwe6ldWBOSAHwlmocunT8Ra755URyoT8ei4ST" ..
	"WEnK9ZYxGaRwDHHg/xMHaXn0pwbshs4uN4QMLfteLk8jsAuw9T93k3AZce4ptEhDtZ2Vh+N7/3rR1tdqMX57MRfYl0w6VdVfX9Q9" ..
	"5Ly/Hg3GTDg6hKcTIvPEbap1XUYzd1cqabDO77mYV8i/nZG/hO64XzaaXbC0CHym3yQVvE8qtTniQ9B6rpYDCDeRGHSxAMxJ1tBn" ..
	"lRIzph/NK9RWhrQkoQhuMJslWwNp34RAgRMEo7JtiyAzJUVXdYFi+kHh3chsFwN4I//7dIsetiPCeFnRfa4lJqQe7RthexTsWmpN" ..
	"UIlOswuWSHRE3Kvo8j7ImhdZMomCuCc1PkwviCgXHZpl3ReucLVVKk04VPW3etf0WMOdeP5GAu1zekTnD4Y7eDtGm6OQhCU0Fr5C" ..
	"l1fd7riCA80lDSpfXTpDGME+ghd+YpJ0aJ6kLDpquYzB3y6gfb3xIiiFpSGW9/EHFDMSEVMaHV2q9BErSeQ/8xL6ZYG9nm5vded+" ..
	"mCfamYajy/i/BoMoklbjRT1TljSuRli6tYl9xdTAPRaS1VUCe8it5hHT0Bns8ERrxf7kybJJsry77cRX3pdXHSNr6BWeVbh+h5uV" ..
	"niKP8Tpjm1SEQ6hM081zmLPy4rvILxGPzj4wSKzAJw5SORsiB19PvfTXI1qD8dwOvgCW679KZeBiYQYX1IoiaaJeoPnsKyLyp9RL" ..
	"DKLxquMmnTjuQgMX8eZvo7EzbKTd9HqgX80zl6pupC+zJyErHtabpKTlFgXgQFkeZkehwhRhGPWoFTiawh2/SseaBmDtQcSEbKUu" ..
	"XJIYOIOTVG8kskMurr1cFum+SX5U3pmJjbjN+K23TSDTKe6G1HnygUPvSl85P0HVKRL/Fcf51u4Iv5oAx+p1Fe5s1agnr5diWPWA" ..
	"PYJHsUT7poyjaYvLQgiOAYS8bvNUUDUDrXmWiy06r+E6rouXi05FZQ2kXLPp6B6FvR/5tWCoNd9D9QmHn7BgdGcLOK+O+occtZGC" ..
	"e4/GylhYnUenRquUKw26YroZ//1H+1QXOz37wq4T0/QPtyvYoYmGetWRm/AvC/75aIojxWVh2G1eT9/5j8w2ImjEj+C4eVchMx2o" ..
	"lCtKGlKTrw2TWnTr8sXZ49BelmCuXPvPwbbqojPaGJBQiw8BEvKO+hssVLsMBIPZUIl7pl5/7637iP55cB+8iNcVssuYX/JFlh7e" ..
	""
local PAYLOAD_P6 =
	"jbdiRNjsagE/D9HtEXzo6UeNYc3NUC9zk+NcQY+o59nL0K09NLl8kL2WXGx2l8s+RRiLNDnRVWHvBlofqiMmIsDWAE/XdBoET+Er" ..
	"iZrXSy9co7AMtQ+MymggdMAfSb0dzGl+B//XHYDqTJX3xOQ+yY/IMM7ckY24IIbhnnzNfSaS+HjRx6kuSDs0Pc241FI21WtPynbT" ..
	"wgRo+A0MPnVMoaPhgmgrvqPkOyEAd8HjUUanpLSIefx7bvUD7EWSlLHoDRWMvPQw2Mo7CtEUo2Ha3FWdHkJ578tpF22u0EXVKaLJ" ..
	"pifeds8a/XkKEtVQ4DpM/F505fsuwQ4pE4cXMAkfRZ5Q6Pv1FUuEF9p+cgO8Ox7KuAB1Slk8ROKJ8wM8kY26mDXTCk39m0MN2E2O" ..
	"xcdHkhL2RQgnmVjZxnyHcxQW3l4TVdkmKZnZFs4CIz4o8Cud6ingJr4fGxxKzmWPzz7+eWgYJgrW45LMJq3DG8dJLs+z3C4n2Kd/" ..
	"wSYnpsku1o5gUQ7bJGkpd+XLoNmWYJB/jKtlH+rFqdtvIxgFV3YTXLPcaC58qyfLyB19AVTZ7aVYKyJ3KbdOI4VduRl/WYIgI2JV" ..
	"Z4tAFbXWU10j1inOojxQ3PP+7ps4XHL3O2tCuqFYxbPB5o+rKiZNszNoixGJCJwtckUV6wHGLrYbBPjCjZFG6pI98LlZvkvhDm3/" ..
	"NNQO93zBYWAkNMernV2q8ZZVt91ys8u1QXTwjYnVrhLeS2uPWxJ0Izb0P10qsj6ers9sqv04/2YKEOZ5/8JxjkvzsrypNNz0m8u4" ..
	"FDH8zlXQxuoF0qkQj0rcYuP7138Jw+v/289ORd4PAwovT2DoiQFB+Ricst6gbVYlr13oKxmU4vVv1Tn6XPWaioxb8NYAiMeH21P5" ..
	"/dEF5U6Pk4g4d0VfuglMEFcQpHHST9K8wPQly2Tk7LqqwryAQNKdasPLG4dXTkdU9+lXqVhnCGTz6RvIRWYLyj1h5t6Xs2AMGQj0" ..
	"TbI+iKaRzuN4DFBJgO+g7H7ZvJI3ElyyO8a2Dg7agWG2aB4+0dQVluNWKuE5dpFF1N0PoJh9n9YiLfWZmYJItfbVU2AyTjs92cJL" ..
	"ImXtKqhqipVZ1eDiwd7tGrIKCzxMkFUxU5/SrSlYRYA3JUCyvkExrQHVlnaHnd+BlAJt9gG2idKWj+Op0LbG6Jri3o2Oli4jWaNO" ..
	"+pkF5SgccrCyXUrPjm1yvWPDSIvokj/ecdKC27jhWCMcCdBtJxNBHi8a+PC/NuMtDjv6f1Pu1q/eO3Z/49cfcbkL5QkGg3dqiaB1" ..
	"LdAAO4b6Kw9Q75rV75L70Um+NOAE0cPQkL3bBrM8t7wZJzW2sub19qSlio6tI6Jsoh1ZUb7XZwMpA9cXZ1C/S6qG4Z3FhaM5yOCk" ..
	"+XwVBLb57SNyXCZWmWM9rzrQTP8Qt0I0KqMgCcC/QTcI9L6gX/mLmUrpT15IYdYWvb79NbTEfDJTCphFQvg1eIEVqQEmBR1qW0AE" ..
	"8MRYtg9kR0qRVui+czFtliCKEmV2VZ/72OOOoGQpeeVvqbj+rlFFrpojjubMFfHcShgUePyiUS3rI7G4R/snZGuGMaePBVqh1dP5" ..
	"KU5pgsk4gehhsjaotZzB6Nds4AukfCfyp2PaSUIVONmFoB+JSI/ib28uWJHZlahRSfuavYuPOIAMBw3jazNnQ3AvjN40Aue8+czV" ..
	"KqGwcI5FYwIuCtpgtuwFT+vEyH3iYfznOmQ2zx8rxj20jzI5cFKyWj0EMRYjC0LZEzW1QCKMrbLuHAqMwY/4tIrg5patvQSB22w+" ..
	"vl0tSEYtycHZTd8LZIXQNsqCoiIip7I02yLjHWlC0yIpF6fFPDhmzMQNe7ovXPPurBJ06vKSRS5mmzap18evpOIuvvu8wbltd5t8" ..
	"OH3SHR4MgWGDxZS8/TNJbT6iNoZc7gufhU3DTl1xVYeDsd5b6uhLgD4oV+w21LALmw1wZizkmDO6fLD3WIUTi5z7p4GeSjoFgTLK" ..
	"y4q4kHyrCSBz8gcGbzV4a3BZIGQu3WrLmZKhC2ddJUjqHMeGErqKaL85LaXTHESlG/zOrkQXgLc2yMc14OHZwxtgmiqnl3U9LugQ" ..
	"RlwjoMDB08NypKhBUApcIvabJxS5nc2NsaivIU13iXiQU31Whe222t/3608P4qGEC6VHeadbltL/FY8JaVwJBbCDlDJJ2TvDEZUi" ..
	"YL2RUsZ9dZt0HSIG/BlgW9Nm8quQaQNebexzcva+kDqLRRjvR5DnIe5MCzTcIYc5nHm8DENWxiWbIpn4PNI9mQzzyLXSy6H8BPOz" ..
	"1vP1WzohhaxtYPcxn72mGpoN4xDQ+9e9ExKp4XqOMn1bJmgJe7G0gWWNTJFJkzQAuDHC+N70sAHQoktzP9TeUHukPVfYiNfcte5q" ..
	"v6qA5CqVuJdD2MztlPzGfohyQgQNitJB5Xs5TSnm5z+BW7sxoYoTPMp/jU6B9j7hEhYSc2Gvqy/E86iX48jymddaAV7vk6FEo6Ao" ..
	"bqF2l00CKTnXi6mULWnZlty6LtrTVVMMprs3IJgEd8PtZQh31362dfcITqwfk5ayCD/jXOvRZnYuK43SMO11TYglC/URQFUs7Nwf" ..
	"9VaZyo2OswOdRseJkfpyzTZW4boV5ohS5EOqngK5uIQQOC0XF0bUV6eCgpNRCm7AlZ0D4vuDHXBOHIPQ7ymrVdsJpH6NeGivhBii" ..
	"JDS44x0z4ARD0S+dwocb65xZxDJpWv1BPqP9nZ0FyQsp03rQ1mY8+ONNZKHEI8fBRlIYEMCDxzuwmJ5rrht5i8AbFYv2bE8anp6s" ..
	"+MWv8aWfUyOI50wIDt810mkKzj6i57EVxb1vl0lH++q32BWR9N0IHAJmOPfY/e1aJ2bKX7P+wERweHIURMOgKfC/Uhu5opqB26FX" ..
	"gMOkyDbHbrAX2KbATWM/p6jKm6KzscRxId9uF26w3WBwZRixcDt8+UmlSDFVke30umPx+/epl1sdK8KOP03zQ7l43EyAt4KDPWc8" ..
	"HAzJKVFuNu8jMUQGgHDipuejObnHjQBDDOt1lNxW3oEDP1Ym7BUJ7ImBIzUoW0RteW9PeJJnad+o/O2foOOqrr+2rTW2t/6Hb0WT" ..
	"XDunnW82n4LxCfQqSXOWNaPEevjXWWr3o2BeO2vQnS388In1N9lN0dVieskO40GjZXVIGcIUY1helS3qqSxfCvQtMhU9D1fUAofG" ..
	"yARfuRm3pszTmhrBFTqDHMkQ/Z9o2pcBwugJqdIt6u6STScFR62VHElheFJ5hTUQWxIEyWcSJZcQ8w8vzc6hAs+AN/Ucc7nkSQzs" ..
	"qydBIKBaboVPRMkGCz8De6gvU1yNhBhu1KaJCPO1h8HJzLyy2inDrzHEYhHnXVLtBtex+QCIvtPgtmvZLegnNQCGNLxsxzBwZZb2" ..
	"3QNsTQi8CRBEMrnSRL/plNEPZNlHUKQHyrQlw5hqyzof32wpcM5qkq3zAzHliPwzYf7TlFztTxqWN+4SvBWO1V/eH2/epn5f1XHm" ..
	"u7YWSe693OpV0PPS4QH86EKNfoeE3lwY99qrh0qHXEWMmfN1QUGrAEEaS6TiyQjpra2yxNCo4vkL4x1XA2rrdmkf9uDfBMeNAwQb" ..
	"u028DALeFKs7lV6tRDG08PFLuDt7lRjIKIp6oLCsdNEEyn9zwSUT/JFEkDoTvHMQCLZJqXQMkL55KixvhEJaRD5vQcvVUOJmJxJd" ..
	"vmCO8vUEcveNDd47lAxZglnqDqN8Dti0YxeRr2F4EeMUoz+u8jCnEGRjSKbL3QRYkbnwQNZSAzi0Yc0yarNISWB2PDpfU4Qq6TGg" ..
	"61rYBWyQ+rwrvaCK0u4ZS5LJAXhTsj0rue+/fZUc8tjERo7JyPFbLwD0ijpbRJfSBinmvcgRIkIOgTiObB2RKMS2oXq+qgxW4/Dx" ..
	"FoFp2TMYFjS/hkXSLLoatsYNF1PLopGotrOW2BmiE4pfE9eKG7xxBO+lIle43Cp+5lFMeQqCsXdVcmHMXiGxhl3Dgv3YX8aFqKog" ..
	"PzgTzcCfe0pGI2fgkzfPXJiujuBjVIWvned/+UHXJ7ipw2U30i4g4D1j7uXXRQmGMIn3JTPPrSu5niAuLJwWagtsNsCh1V8ppYXD" ..
	"jfpFwk85pD9xEyI+JOn4Rvk0m5Iyw5Fi/sND6/app6+io41CxLrv5EiTfj5QkSLR20L/fK5iMMrv5QX1BGyYphnNlzCujnGivxVe" ..
	"fBYWsNc22JaKpKyljuruKvSKXu4bv3Rbqj8M68VMzHcMyjUUIU78quXYkzTHVK8w63iMJgMs2Lhctm7yXJPNIx1lGoWiTMbtkw0s" ..
	"6OCIFFtXGCeC55PYUVEHzgxS/Q9NI+UtvvCJ8a80PTts7npSybqWUy3LsB0DS1Ey/EvgJHaoIHSGCB5fd+L2gTyPdUO7PvTgybhj" ..
	"2ByutwGSkXHGj/Zp9ngJ7QaQCIsvtlBLiuxRxhMs6QP2C81NviK6ZWjpG2On4WSkOYzIjshYeW1XCb1HZMNaowsQa4BEgpMfjJDR" ..
	"49m+O976dXcvJ9M+Wzp7eicwvEq9cQQeIsceKZgPoxSRVHZQJY17Q27oGrf72c4isy1dcEsVbOcncjn5Z7tc70xQpUN2WE+xqUXL" ..
	"mP+YSrZhmwvEjyOmNCqonNE47V53JRakCO5UrZV5v8MTQ/d6lQleecrPahuxInGgEoxnq/DI5cdMxx9Fqv7LxzOROKHV43jNoh9s" ..
	"KGVJ0fWBx352UuB+6X96vkCdi2TCLZXWBUD6UEvTTdlTUhwh6V4t66qvES2epwoKmIs8bwvfDPjWi6TmZ6qz2dnmZ+Tr3twtKu8p" ..
	"fYB9T72GEGG6I9IFtDaUjmzZXBpQ5lnD3uqFLfAPp8Q4mNY4gbW7FfDI+8zwXibJGHAECkJ7lxwY3ud/L2rLQJEdB+gm76iRDl+C" ..
	"8xnCPnef8sEtsqSat0S3k+lfTiYKAq30jOCjlCIMOCz9yp2x9kdLijQJ/gvJpHLbkjugqBTceQdvUDQxldEBP/A5KRkV7PeXJE+v" ..
	"hY1MhTNzgrqSegLqqdC1AoMFlp6fCNq8Tstpe4CaZ1AIwvQeGL/Qdvxy8stZH8a+IQBpaRmONqA7MQBAzfnTuWB73jn3Bjk7yu+/" ..
	"8BNab3smZdZ6a0H0ZQvp0p85tOaae+tqi4lk3S0pLnZi3OEGy879SWorso+K43OJ0VXizX0CyLOcPAVHwAzJ9GTlPs8dBOmklW/p" ..
	"Bs+oislfPidHGkQmkG78RTCdxc8f1ygymFqNuzNW/dXhCRQVimfLfmvNrp5YmJOVkDRjuuPTrYW24NVRDLM/VkX0kUu5uC+LIFpr" ..
	"znjoc+K7x7WOZ+ufXojQJpySSkFzmWuHp2Qk2ZP+wCrvX4hmOqCmxL8elCO3FkRPHR9BfijJvWpvya2eMoz+KKpQEeldUFgRBjyf" ..
	"3KNXrtJKsvGGn4LJsG3jhM33fj6id4TRWu5SfnooYjjFg77X9hRiBiOV+ov0S7gwhw0XHz4ogmOOeRWMr9vhAq0TBdtuQb/l+G/n" ..
	"kNKMkP4U4h8EgusnT453QS6x9am495ZfQEhMIrRy+T0OTsuL7hdCTNejqcmv6M3ZUxaoAST3aH0WTlNqlP4o14LoQ46lrL6HQdtw" ..
	"BivXFqjjTon7R7TP2c2Pu6NSP41vxUGO7ryRDcKZRg0UPvQFeiCgXvZB1bQ1HfXFzQksZ/EpDXgRZdlCpTIuJBMp6syUXk39fM7e" ..
	"U8hTpgpULMdDDNS0tRK29fI8aVkNGNhYgLjpH3QY+cAbS5AjPT7lDBVjWbkvQPh+Impwkf4xxllP7+WpzfU+HnzViU28rtaBvEOK" ..
	"VGVycwsr0DpaLwXd4gncBkC3i5lTzlj0ocsG3gmBRxuCRiotvR8mk2qKpSUEtRCt9ig9BthtBkQJMlwJO1LA9RxgcbIZcLpzb4zM" ..
	"hmg1uFhUGQWKyTQRwuCUg4vre2kgE/wTFT1lJjBBAJYY4yjtweYkbdAI3qHuxrttmR10rf1rLyYpshVv/dPBGCeEMbopbPh3mWBQ" ..
	""
local PAYLOAD_P7 =
	"Da/IS7LfCdbVnu0/sApSZ+3A2WfyO2LnZcivzwr6ekKMVKElXfWmaEeGw555ShKXoCFf5kYEFC1YHcm5NcLc+eIYLLhvPxKpxgf/" ..
	"BznmddsFB3OFz2c7RSnYVmKW/pnPHqj5Q2m/5RJTMs0DSIxy1XwkUBcltigk46IhaEsfiu7LIj5GwupBR4VU/OAYXW8S8xXMbMDk" ..
	"snidXlc7AeZNybm+SPgOx/5j9ejO8j9BbDgwy6Yd2l7fazI+pcdkPG96P4yxdfOQKKu3eTtBDn+Uy8mjdiw7QrZjPzljC2tahZym" ..
	"hJRpV8/1+ikDuwgEMP/y2D2kxDITzSbb1YK4Zr1lUEJtMLFu2Bj3SUXigk2RnjmUkT1ooU+qKoUew6OMaG9k8NyxgEr6fBBIKMh3" ..
	"Kfvr524pFUnNhB+LEUsLGJv5bGKEvH8KGCJkh2Edh0QrCLTU8F7vgY/A2Eu47qSOqZWC3d4qvoCbrY/9gHYMSVIIWsC3S7my8W/S" ..
	"10DAnlXxEo2eJMPrvH2bFgRsdTcxu8ef7cVEOUbVM37EGw9GLOCk+j+iczNNGz4E+WSPPNdFLEpAVTxwKASREOlyIrmrf24Ef94B" ..
	"o7InxX014Gifq0DaICf0EFjd8PsOPrj5dV0nieo/IHYUojpKUPLQ3onaOYcfFL0cLYiZCvkU+Q5Gwi/ERcrSLg1H5zTxVRRl5z30" ..
	"MwVHBf2ecQmsebG16oe3EUzxBAwdsyu5ai6qdrA9GzHccrM+65kzkIttGr8HEt0DtoWhalud0N8yEwejpLsQA9Cr1BU+bu2GSiW2" ..
	"+686efoBahoZcnoMEqhcMKltai5y21oGalD3Iwur3OgCiFCZ4cM4Tg6iI2kjWjwBnZkAxLTxbfa+wiWoNaGuujIaWLFwjzcs9Tpc" ..
	"rcaNARNqnyCwsl/+iNG9i+Zz9exkosTj10AS6noqCT33PtS9dHE+dvBGk+R86juewuGMItOGhlvjf9R1IMaRXAancf5hpSHOckfN" ..
	"bhh7GOA6fS2HfbwRsNkqnKyfmTp2yUXjW/7hGWy98CR07tfdiJ4B6EZR0ZeRVepADsBxCWATtlpe++urfAfSinFJj77LYFv9B93I" ..
	"YLEpS5oBkMH0Sm6f4+boCL/ekZenymqeA3fuUNf8fDwZhcSnl1IkxXBS12kbu2lL9Sq4WF7ECPp+Y+3+nUuEz3IVVFJrbnjjPQZq" ..
	"KzeBnV2+ko55EFLVwL461XadQEAaqyhExuXZkLlX7pAFh3SkYZQpXOgjIffDex0EZuyEhHfwFJDR/fafMLXPJwPrF9JQ0l1E/1+f" ..
	"scbmlCeSinyosLoafgIUzvh92vo3Q7Vbxbu7Hou6kyjPxrQWwg3kJ0SSMSXnEOSZqZ3Y7iZp/CjsE5Bwa+R4eLhs/mKI7NvUCYX1" ..
	"GspjA2DJh8hXps1Ny3FhIbO9MXz9+HBCv9/lW4BLtMHdbQY8bOHx1lvMpmcwbgcUp03Tv3Z0HN0OYvWyYbz77IaQrukvLGMrOp+O" ..
	"kSKztHZkStnQ3OE6bkJ3omD07FxwrG6Flu3rlG17ljsDxunSEnHGXF0kzW5ADGO67TEqVUg97pS02L+kuflvxWvPYnzWh89VlFyX" ..
	"Npvzu8lCehzM0aJHXpSsVXbiF/Cn39PjN55PmXEPbTbdhZofxRiApCxl/m4igWiqjh1nuh8nLCSPvbei4JQwyHkm37IRJRwM/VKg" ..
	"6GMu/dCZaZvj3BrKF/WCHPaMhj2J8ZPOiwi9glKTOuicLiGbth5SXmmp/anplKVJo815ptt0ddlnYiUI2CXzoUkSVhSOjtS8jAj5" ..
	"9+HUZNJaa4pJrhIkEhMvukKJ2eVW1Lt/DU7TdKGDgLqN7j7wPEuk0ZfdLO6oSbV03Ywhc2reV70piDLWKUTBpRBLNCK/gw6nEYtr" ..
	"zpUh4yL24Dh8WMXWk4sXf8vYvbofCQONXGHTWhapWWoapKaEWhzad1AW57K0hRc8UEKHVKvEsZSn2ZE2ZRLl1AohKX0fogMbSNyk" ..
	"dGRj0oKcEO98fjqHZixpTpOsNgHbbIlesoWlKmgOsZETZdCSU9UDZ0XSlI3if2BlCAyfxjVGcM8/epq2DXkLZ6bZU8QKm0p4pbeh" ..
	"q39oW/6e4XJzxq211km1gUky5Pu5N/wswcnJVumnJgtaBhQh7ZO71BvkJW5SzXFHW00zuvEXGhrupuiQnAUiF221NOXIcwOCAPDm" ..
	"S80kiC9+yRD4e1iRs1FgZ88arxJYi9U3ddJ4qOGPi9BlYPpeFCbd8B/TN7R98/3aPpBkAxAVfkrunWIdi+AbRmRwWc9BvaG4soVi" ..
	"Wsuya9px6Tpzu3oxNKHx/euNhzRE06c6fYl+PdTcAZ2mplsMZrZoDnWsFkEueHzDedcVvULbMFd7XV3KUco5l16trCKh15E5ikXc" ..
	"olqc+SVUWW7Z+M2+okdwZmT8agpzJiIEZ4x2zYYR/e6Oyt2uyc/DPwOFm9fhebwheVkCCJW+FWmz1NT2UsqrI4jEjF+4ar6ZbGwA" ..
	"wdLu6oCA2Do3F7vCsiWv3CbCdhdG36QTV0k0E2EulyBXsba304v5WUlEnWIeiEd5/MBP0M1crQCjJGPffXqgnZvrSCSACXmQ12V6" ..
	"JyoQyUXkMe7KczynnQMpHBbulGLOg70Lxy2qBrwxPJUZg0rbhpS2MO0en0VzH6iYDsOMdCYP7jMNbL/3DhN9c8HZ3SxXPUWddGJA" ..
	"hoONDwuSCsbYrCaWp6y697cqAlqcU9/NcKkyhDCQ41jTRufTLZ4bd8Bcjyz3B6kDvKAbW0a+S6z0L7r5IHE57DbASBZtqpN62zrT" ..
	"8sN8accRbQFvhiWNZzL0IUam3A/GnRpR5P8xMLd6zuJKjhvvvHgtVR1eNcnfBAcZ3GKQkHL8OQsgugPi97P0GfJ0Yq9pT6ofAwlF" ..
	"Xm9LLw6Uw/HH2DlMPKdiMPbQQh+cbDl5oIjTJflqHzO5vSfEDxD01Bas4MgcSuGUVtD255BR5YvOGhEEPU66MzPHxGLWhk9dwAzW" ..
	"n1YZEg4MhJdaag0y7cdKBOeunyttUYq+drIqjMJPLdhDM2PPmYmJs1t/lRNizHRm8faZLCpdjy5O5hCBbJAyR7T6gFxqobZanYrX" ..
	"YsQiKV5jhlwyCMC2TuG5COhYHW7K4jqyXOZSRfDP78YR356k4/Wn7t8rhPrgeuGtiuQu+1wEMXqIpxLO+/0KoYRKHj7aCH9yvoPE" ..
	"5oCp3KBASmr6+NmO7T4XdnsZ8ewu+UfUe90+uLvTllz0vTgL6DTHLC+9q3EKZe5udAtPH9jPFV6P6tcSlbxWZDlJZVXX4RvC1aqU" ..
	"wc3jNFGUj1YNhER/xsbgbE/c0n4P+jZlTwsJzmMWsl/AvM/d10FanLINb8DweKnJlLmFzz/7Oh6DV+PgQUyLNIyRzQ3Y62ou+HrE" ..
	"pz4xPxgISZpDITOe7LswFm4CSY6veGPLDkvYeF6XRj2zjiyetZ8x4Y3pLZq+YgGbKFZCLBX6KzK/CiPGs8s0AD9d6cnWhIT8W2o/" ..
	"1FKMcfEUleKouFCHoBQTDH2aimCW/9Bg5M8EpCbz4KEE5HAisog+N0vvGer+SVKAa8/m61ebZZ9o8rcZBkxHiGili8w0WDBVakt5" ..
	"jx2R3Qnzp2bOY0vaSNqwqsnRdp207FYTNI2gcn+P2TA6uhN4e4EI3Acak87IDVf2oYvT/vEfbZ8clXbnZbhWRuIGR+TpMw958+lE" ..
	"GJTg7qQy6fca7ofkOZqZOYRbygkFItaY0r25m37XEjAuTcU+Kvw1NueLDVswPyvtiEtQWHubIs9yoBMfELcTkZH73/yT4zSme39n" ..
	"UPBdz0s61iVtuXQQ1a47Wl1ooS3Ud584U+zpbSUG5ZIeQmh7ZhagYtAnvrKMNkTJb8MNzwJuzcm+Y4XlR9DFSxNMAoC0YcFqzfQI" ..
	"rYV66V4tGfombamqywgHqI0OxVKvhJ+uvLzdUUD2Hffkj2tLmb9z4OgNKbQrT1G5gmuvchV5jmRHtIt5XPeNhuw9XzYpj9SWo/b6" ..
	"3HNpr2FA6fu963V+GmCVWMzcXrA1Zv+IOAMAcWQimG8LYH6c/gwP39Gq6V6cu+Syhnavc3zvMqcDbNMqylwNsJ0ZARli6IxhoUB4" ..
	"PGQajcL3MX1pfMwb1bTsuLSQKg3nvtw08B45SPG8GjyTYICuRsmRJfs4meZk4ICLjUH/4N2NKb/gXYKAh2S1ezqeFlCARUficUa5" ..
	"iCxFp1ZKiUjDvmbi1yxdoMj6585mdBtaK9nmZNdZCWajf7vWkjX/UYHmfz5XMm6DyrLp2laJG3xpUKrZhzoj+Dj1gzvjYRsRByxh" ..
	"zepZVni36euLtCLURoK9IgPQULJIQtuKQiTQVQZcpmkLLqc4p7TepQVQE0BdREbH8IjkT/TaaaCbUL8qwNjCOQ6S/IVLSKMDjEDV" ..
	"HPDSRy6DfqiRwUHrHO/ahqvaTnZUcYNLHdB99DN8+bMszjK+huTeKXtRvb9PTm2etS4Yxow8F1/5YfFXvr77mXxCHIZTCOJE2yl4" ..
	"+zRuqOAwe84LTwFEMA4pT3hMoap7DUYoRJErKV75bESF6vEiZwDpPzQL05QLeFtnu/ICijC6aoU3Hjmx/Pr7Krzq0fi1HVDn7y1e" ..
	"rKQPnRR4N06LKfCAGTzeLd/ucrkjilGeiQ2DbWlMVOzUI5/xD3Bh9fMf8t73azk9MWTrgfI12IA3XmNuik+RcSRnDzS5Ka9yRFaM" ..
	"M6Eu/9jPt1P9ch1kxJNd7SazTbbe0xuQyQEzZivJ64P54QxHEp1vvOsCr6s61J+rzCb8BbHTd4waZeob/YRw+THOfPMAqGoHIq6A" ..
	"Lv7jCqdeoNRZC1hwjY4JW7+zb7HXaRSFzx7b4p6dvKer2pZ+20gAmKbtJTg99BgmSjyZdjx/XNs2wvRdKu3WbIz9/dbrn+kvombS" ..
	"iQ6nVt/ybKPe4FS/bXcL0mKR2pnTaTXjVFgcCM2tOqizx7PfU9WLaZx4YtOsZ+Nz7yRy7PfYkWVWLUx4EM//zy9XdPzjTVruBhHV" ..
	"i9A1qrw55MXtPTECTd1A+raoO2rh6bDr/Mz777XJRWFdlLyD4lr6XKe7e1SzM60K6/pP90XY0k3QhwLHvo+kuE2O2Mw49S6CUwfc" ..
	"ReUqpPGz+U+C7i8VFW31OMYcm+/Y96HTGYTW3Uf9dHz6ysWFuUnzckcwxa/RawTxpdjWRlkAeOeV/TaGBv9MqfSAw0FVLvouu2jO" ..
	"O+CJSXXBYG/9ZieslHuDOHw6ne9WwoA+hSIGHi018eOJhdMAgkxeuIIz6KrLJ9A76iXb3RzopZk/z3j1fUGhfsatxnlWV4lXZxSG" ..
	"0Oio67lYBbGpIBPRC8fMgRtFjWcrc3ZI5S8CEWAuD3K3KUeT7BzNgyJp0reTQHI1KI9LSxbPr2V2RUl/Ki9DkN22LwsN1lbtZLqb" ..
	"xnbWCuOmaFzyGwARuEKq9Jrh9g8Zm+zQtsmFr8xS+D2PbL6XNDyZAefA8BeJYGdZDw8OYeOc5spOmzliSEA7BbI1YZ+2B2PucyU3" ..
	"8Ns4F3twQGKYhGRGFr5meV3foEwozOyoD+Bj5M8aihv6DvMsOvMuW/8+R6LRxQ40xogQ87Man1YFOclVz0c0iWogKkONa9n/kBEm" ..
	"PpLHxOpOqZMt+lxznRBHG4TYM5avbGtCy0HNXiR0UGOBlcpm84lHyXSx9X1aHTSeIUq3/+o5wWLjYD3A98h37YngZfNgN9VhPMKn" ..
	"i1Sh4G8XVPNSs5RAR7zQGiPxaBL3vZ+PP0qT9vH9DU+qUSi6hKHOsUS4U+ZFUR/UkPcKX638q5Y9spH6H9MNEb9+OAPpdVtVM2hS" ..
	"znX4c7vqVQV+3ezVIlv5rscOeQeMbaP9zenEEb0Zx0H9zSyMWuhpC1f+b5Q37bAxktXfbPeHjrQaBp6Lxxqsgchr12mk76W847uZ" ..
	"G5N8uLbX1a6EZM66CgKbjBkpnMsdx27NLP52Qxbfey5o9st01zanisR9RtJvjrwHSFj0UNezFe2KnwEGcYQK8vXSO7PEDn7wrwUQ" ..
	""
local PAYLOAD_P8 =
	"dmxKebjJ+rPa8YxqcvYYTjX0ac/mzQ46CcThX7Pdmit+xZpmQMjFFzqADPbSEtGsk/mToqBHa381gUsFU7W0wzlwZOypAYxdENBI" ..
	"q52WhLEUwSohrel/0n1ClhaubVSiy/Pxj2rVzl/3u3mjn6mLKTF7WP/i1iuSY56cy17n++K6GoKC/sr6xEy0Jo7puZZVYupFtZkN" ..
	"IcXzV0MzVVVMAQwtT54udUN9UWb7bBTDyjLoyjvr+MYdYbSp/2q6Q3lrtezJoywp2PGsywEiRWX1RuQjQmB1VFdLkf5+XBIzIv5Y" ..
	"xP69c6vLX7YMaA4m7stNlfTQEuPQ9eQ4IUsROAxY1BNNev3urEVxw0INxrXqm/A5T2GCAWFlyc5D3/XQ3OB7wGBWM8L+O4fGEEpV" ..
	"L3+TMM6gCzbjtqDNmrlMf55Wsx3FlYoTJpSmvuN9wmc8aO0+vnBGfgtRczhJUuFxZ565ZIIBx27rtE62F+AKTDK5U+uQoV69i/kM" ..
	"WGuMuYtJwyepebd9pFleqCp1tSMJl34IjMtgsgmQg4p3DFrqz3i4awzxv4j72krxua4WHabbBrar/1JgD6WvNLIt0vbRspnIIdOP" ..
	"8F0Hv3ej27O+8QVhnUpnelDFxdJjUtHOOcaHWk0+23enPXJ+ybwdFY/TC+9rSgIpT6WM36EVoZSgq7AoJJJuUEVkeu8RngiqcwpJ" ..
	"Gvi44Zl940hfpG8UJsawDhdLJLGmb7Y8fwuijFDn12mMWWpKa/kSZdjnVKuPL1ap2c+Y3hQwo/0Sqqr3peSxMEubrGjJxjMg14Dt" ..
	"7eGf4DQmULVpF0EzS8dP91vHrISf87qHBIGstXP0sD/pT4Ces0rghNT8++LfwTEQKwOs29sOzfMEOy9RQj7stT9zvNTk1U2+szAS" ..
	"PVMp1FLLUfwAL9ti9ET1gvEpc5x/oGbyHL2vjS0SilFVOC5ij0SMfpHKJOTal0peAXuanG/BUkB+40qWYkgYeu/TH0A18IZ++67y" ..
	"kC/yboflyFNMX36Vjln2cL3SvAHU+u5oMfz9qXhMCpjT95A7wMOaPTjDYI05cmPuaEz7J3GcWNwSeYjJfRHJ8GAwBmBJHy/4srbL" ..
	"SgzHGdFp1/tjcIGCWsuQr6UJ+QP70QcNIs0HH0+svDpqyPCQHDqowJYc+PnebN8S1q/DDeCeRzveLhMNm4nQp6UBVIgJbJ1QSRri" ..
	"hGZYA0pfAip4A4n6eAJAdrx8A9vRFRiaXN+ZsSVJ9l73UeZ3l3RgWVoJ1tu8FRTnmyfFg5UECG+Xa0qOGnkkcJd5nxPpHUN2DjDh" ..
	"4xASuaP20Z7jM9Of7KIeCR68VxbQm6MkD1MFIZP2xAuYzDRs0xAg8piPHc1KJqMMafZkmYwNkfX6Se4Gey7W0TKp/mWPe3pmZ4wn" ..
	"AzVoRboWT6A/bOFtB3wxvjt0KgQ0GQZ23MrP4XSLPUOWkkPAbv6r/1iAUbpk+gpXPoV8/dDFw2sRyT1KTrDdnVPMZd0X1q/YVerR" ..
	"SInpldL+oMaOnjTmKTdn27dHHISKopTxeOY6ZMZfH+4cEyvDUsEKj+FhsmQIgC1yxjW2p8yq7cJd/sL7NfV0aUUqxgMvMT8JP9VO" ..
	"mIzFcox2b9mfJMdGFm/dWJqKPDTaajJFugGMW1QkXbWOgNI7wsk6MvUVJcbt6+R2EdocBzZx6rK2lR8572F1VPMIS4Qi+hLQxJe2" ..
	"uT5HxpJj/+LNvckp8KQOjXqLW8/2q8HgcEIPEctsA3kGxNYpljIyuaUF1pfKN+OBZFfskUTwh7uzl6IaXNkloQRWjnWAu2IT9HED" ..
	"XfwutNPCgj510J7B0EwcRGjqFgrkrxXsyOh0C8+Djf6bO9yLJcYEKHIuCUQFud6oySXLY8tx9k+kDFWAlXiwwb+RbMk54gozZScQ" ..
	"k0hx3DnRTemCrfrwhwmMIlPLunXvNpTJeRcKWqZfBwR2xVQPXzTYr2hcUVj4o4GvQa46UOhg+rz2C0bm2ernXYSqbX4YmOUpz5nf" ..
	"DiuM00Rn7RiJY0VZHYBDtXVwXAhpevfo1zmIwd5rrYwvLmUPMCwxtcx+yk9d8g9atsB+lVt5359X93tuIC7y9pvU7hnr0LDoziZ/" ..
	"0En9aAbtQiK8u5qLSgiINBLHx3n3wq9I9DxeV73tcGrPw7TF8QHkQk6HXmSCiT4wLb1U6SyuDckS1ZZDCTcGD12t7CLuDw/ymFCe" ..
	"KvMdjUPfQCvFJOEWVXCmFV59+p2QFfEjjhOjhTFsNgYHjmwsECTVJwF1RlHZ+89AWvtrNxehOM54Z2v91zP24ydClwmyVPtJ7kfO" ..
	"6DAF1DkqLaLs6AdkUZH3qwKDKNoX6f8CbfVkEhuh6K9MY/i0zhKssXx99f0CALnmkRcgP72tAneh8RDWDZLHcfdwrzHtlM17RJqY" ..
	"BL4w4EMY1x+2UeMCjCL3OAvqmqwhobCMjU7mvbhN8wdrOx0srUD5UTyrTztg3cIC9+CcXahqcMqATTwDpYg/KlPyYh30OXgUompZ" ..
	"X/+HDJMIR1Rcw2mDfl+l8vlOXIezXWGEFWBW0AcyvZIma8AkBiHYBtTQlCkvqiAw+lstCZLSWOA4XUNY4c+97liouaNpRX5VPKNQ" ..
	"h4AqehFhYDWRzgZHlaBHKo6xS6Oj76HZXJbbkvmUBWgaTVirHwTEOIZQLw/jvOz7SdS65QjCy9qn9PKMsWY5XdjxA0oFl/YaoIbq" ..
	"uODymp4cIJ72xHCL1nzEvk27Vc67EsIqIcTK8eb2wHfoI9I0Dr9kN9utX9Au3m3FysHGCZY3DR1/k82bfhQikCMLSy3d1OTb96ss" ..
	"V0yFDEWCBWw6vG8MZ1elc5yYTzZBgv6PCeqxYhIM03tql3L8PhpPtzhxsDIqvBZmGUDH77XX+EHmUPXCBWGRXhU6WZlnB5mB4i1r" ..
	"5eywRdSPIpEw6jfWnPjPlSFx71hdg3JJ5Ek2z04wBwBZnaMcKZ4Uk8tXIIoKy2NPMSnqbtvb4yuVNIWr4dNMdgTuT9mzp0HifyZp" ..
	"hW/7xwjVKVbZcbgm7sQ0jxcz3dmYod+3dE2bWyV/kkVzuJmWkhlFYyKyj5dQYZn9MuI7L49Br3z4ZFQoD6Ag2qirmUEq7e5ic2cd" ..
	"Ly6tswb5ANg2x9uEE3wIoDnFhOjcGQ28UHuieFfOyaxNDgYQRQVPVWP1j4GF6wyvX0KM6ZgVhQsLGfyGUKYcPjIuEGVbuOcV+qva" ..
	"ZoxQajsHrMuJLK6Mx+TAHmhmZhjIC/o8A/AXu8dN+n8vafy/xZ8J+UL/1SG+KQGbK4EFaAfuQG72VwuI2YkzmMuko3VR3UpTjT4G" ..
	"Pf9iy0GMmuNqCF/TvQQq4eZvP89yaxXmDavy5U4TFAWwFHdAtENa3lK/LB2TZ7ZNHu7Dk0fdzJJ7ml9AtI/dbcTH8gS3yFGJznIV" ..
	"vt5+LGsWsAD2mDJneqs7csqqDALUMFxiOLCsZGYckvWOyF+9Q4oXOWXSfPrk6O99jH4H2fSPFKcZAhAXmoL/7SXKdjZcFCs8Irdn" ..
	"RV59vGYNY5/mzvznooA5IdpBt6SaMEGDn2pdhRr93D04bwCCfozE6AjX+hOLUWkqDxHtauaYVPjkiLJWG9QLiLipzjI0Dz+7IR/k" ..
	"c01htQsm5cowtd2gexhbqKlpXICsK57QfciiL/nkDEOClhVQ6m+HlHYnR6LyhBhDZVcKUUv9p2SSEFNS8hZXt8dfwHy26HpdDQPP" ..
	"UyBCbIXE0ywbZfJq/QCeSCzf9R1AHUOp9OvHQEyUT7wdJ2znJCM6+F+M+srUwOnfmYUtfY8fqDyGABmgz3MFNJRN5u1Tqvmm86mT" ..
	"/OVyZNCtcOcPFN4IZNh523aEzdtSIFqfWFQyM0pjKnrhLM7LWdtKDz2AJCgCHHVrrzs4zyUGVULi76sD/xBlq7RJit2Xqdnw8kJs" ..
	"zOeV/J+7KNXjvInCU3fhvw4vYUC7Dzo9Dc96pI3atkC0pxPhmsFcVQEAL7Lnq7HLUycFnl0XK8yEyc3TQnJXcBaiyA0AFcOGkekC" ..
	"3C7fOTGlIsafRIkvqMpGu7xGXcOX3HSI32/oJpVcyFGvzdrOdmHX6g9+IPVktr8uhQ4yFhe7jXGt9E9iTZxT8HbO1HmYwFGxOiTe" ..
	"ahbKpAQHPZ1pBFIArIziX9avsVCEcSAPqOGjam4kT5NeLg9rDfHIbmvxM/g3DIvQK/9AvbxAMBg4S6L+x++HB8GuMoCsV4iffuSW" ..
	"IHoH+Kc7Jf4rilis4gn/Bf9YX/6J1NTVIzPKYQGaV+/MA9iM8eijrPZbdCBRiytsnchIjaA5Q0SUtZ31gv0DeLlmUX/OZX8c06nK" ..
	"4TuKGSLGIxyimvNKIaqaFXnu4GWKorl0I4K8XXkqfHLgug5CAn9D2xPpJsLgCVOq2bsAvUSLIxeDCmv20x/aky+kemiMl+bWeCgs" ..
	"LYxnDN01kercYZLF2eTpvlbTMKEmD0EeRZDw0MdCY4MQi+Z8a43l1UZAJNNtAJrkxqV8jl+95gdPzat79AgEvM4P7++gLbRybRs/" ..
	"QtF3xtNWYOO9NYRSXUCjKT8SUECAw6I0h753qRhG/Tf6aVl453iFW53QxYhdEnqo0/brNWA7jVQZxgVWhSYvrJTxmgPlcv07j1x4" ..
	"g2akUIG0VJktcZV2u543ZkjYRZuN9bC7nS60Zwe0eFe+ZGSbHFyzRpyTrhf+jhzFSl270NxcGGmxu+k+pRwnHduWihmghZWk/qzl" ..
	"4uwKP9rwq+pa0wTLs6V3mteQSvw3gN/Da9C86rlbY9u27111XRrw7kMqyuACc0xPxo4Qn+Aa9bzfgW3ufoBGI6hCYHpmfNnvhh5S" ..
	"yGVf2qWSfPV/jQbVtM63rlA98zmWVy0m0qdY0BLpWrdRDSB6vwVZ6FkZ4Z3zpSc1kwfN5oFArChUycNsM4qjTvHsgl2+ECB0UgYm" ..
	"8pGg2U3RUGuTfxLQO49iShfW0EtB/hPeguy+e6Zqvt9d9WJQADeoRRxfgrAw7gN4Q6o6Lw1HWC6D8ffvit7fzD8MaTQbUc1cdmsu" ..
	"eKzXj/XfV/zSg8A7tvjEtQX/wNrprifKCfnv/MFsUyEje8UITqYSoA2w25WNxIfs37EpBib7JGp8VYswYmRdts7SyVCTJROOpaOb" ..
	"9TfPoxCye0DKwUm3pVwxm/QmpNG/kIogRA6yaxnCJImk4Q/lFibFJH+Vckpo7AU8lbLG8RcfzA5cYqYZ30v7F2G2Q4hFyh6BVdpb" ..
	"VjkfrYFjDK6exiXBezA1uzl9XbGGSPemhvcUn/+h5+4P3XkyGs9QfaI3MLKHwi6dDK+vuS60PgcKN7O/Bf1YFRDMKOvxWy48y/Jb" ..
	"hvkmvaSewYvFCvS8Mf0tcsxp0szitbGgiezqVnx8MGXLRrw1z2JE+Ad/lUShF0ZPKXj8Iy276LA6Iqq0BDeasCOwYfrRrw20wJGJ" ..
	"Fur/WUnEYw12zuhMbpY2Iyc0/3Iy4xRFEtCUHsNe23OSOBH0uPK3g/LoZ5OXPriZh2bMo5Ug/Zx2YLAnMyU40xrWv7ehW0IPoOvh" ..
	"SeCM97LnLC6ybqNB1fbqJN0Q5kp8plhwYA7KsxtCFcHl1kwDreYZoQjIYrtRyXoN9uPMCDOXHiWvSuEniUdjEo6/Lc+QC6iG5PmI" ..
	"ta4WWDJKfE0/BRaE/Gm6r/zxEqvgolJe2OvNMzvIWUHmdkmVJKWe8VXJrffKWvd/QlcANihb4AwvoPOGNUAxzEkxU7I/yHmoPA0v" ..
	"IcjrRe37a0U72c3YpSj3yL0LQNQf3F5sV+Dac2Ff0AfQppGEoZcoHFPiZPA/DWDVzhnxHuTOcjqTP+C0yYysSgQIighPnXAGCcp3" ..
	"fjIRRRt862HnVD7QxILDbSwKBoHA9TrIpIokltgEFumj5mXgPpdAHg0vVE59uBnQxLpP/vvu8s+qwWTwaEvy3myUnY2ck5ux4M3d" ..
	"o5FcbyQZdx/tIlywMdY5hTkZCINW/Y3qoLBJCHeZfwEj0ylm3keC3N5TXIKiT5Bna4+t0SC7/VwJOWsllpcwilhscMT6NO4LNoQW" ..
	""
local PAYLOAD_P9 =
	"1/JR7EQj8mREPNZPiG1cwR8A98dZMi4bQfZP/gqQIww9GmlofDbgKVvFRt8odgbhwygq6Csg3E6D05aDWvYkmnW2UnrjFcWBg62t" ..
	"2oeCIUuUZPQH6nTJHcQ64Ff8bpMWfg8pn9wFAPrRi9O99gVrolbUx/FIOIfifGSAgdgSeRIvHJhV74fL85wcPQjoIUGfG9EHyaH3" ..
	"0qhH8RgIL6q7LyO/X7iwgbLaXq2Yh5Nlnx4U01nJ6FHb9B+26RENN2ER8KW8XMicYRs1/NOO7bYD2e/ezHvt4doMC4EKCg59hvRz" ..
	"XfSPposhIOpf0OYVRF5pvG3yRcx2yVCfAT+dH/7GnYPapzoim9icbePf1oIa1aiJJXNDP8RbNSWUrrNFtibH0vylxK2F3lidjB/L" ..
	"ng7oU7b3VdwX8IS7moviP1Yp3Kj/tPrlNvDPMa6AYLTdtMuo6ZcYDZWj3GJrc9bkTI4BaymmjMdyi96lrSSS6NX3fkOU3x/g7owq" ..
	"rv7XnatoHPcdDOaDm2nKagL16c5XmVWFiONeeUeX1bem75JTVSHrqG1Oz8lITTxN7g2IqhARxXI6ediHzD/gfIt0vW0Th4MK980W" ..
	"Iya/anfxd77kWX8r4eminiIvRdQXT/0buTclQmUIgNhdUR3/k0aaef7MbDKPjOKSjy03YAFH/hdd5evzOzRBuT33wVgyZX8vbgwE" ..
	"4I9WYcdZlgPtQviOS5fHBQs9NQiqWsJg09ubtiazew0ZW1KuKZwtAfdD1vanmDPLB6xM+GkGlBLeAbqbD3jE+pgiopeTc8qCwPMK" ..
	"HHpMM+Nbc/ckrldNeqVzP2EDePJGfEfOq9Q9Im/pjhApCQGuFgDyb4fOucxf89Rlg8/YQ4cWVIqCCAfhRyb942ggRNrXiJYzuksA" ..
	"5BRIt1Qo0stGuX+ZvwhbUvUBYF6+pZpmAHpKAmE3wnTqwJBLbapgWqE+Vm6CpFe1H7arBUvjw0BIW9cr0T48iJ2Mq51N9jT61RpH" ..
	"krDtA0xCvERLG3qQrZ3O25FWZCfCWsV6D7qqYp3bcD76j6WnhSUpGwktccfyZxPErdUC95UuBBG/CFP0LO4gScboDbnVBafdljvX" ..
	"h9MF/egjwUtIP5qdqKtpnPaCQvi+VQBn5GxPb/ZYrhBJOYHE31LbZ212a68I9Xo6x64T/nYw9X/nOmdbV5W80Ja3JH4KKsOEQG4g" ..
	"eb1o0w4TfmPuNNp0OqSe5JWddulztkBau/e3fQFezB7pBVoQaAkRKakDx9WoyTJ+E6api5SHSXJQufucNGLioFso8amgbGgjfJRM" ..
	"iopZINE5oFUlnyS16HE1+bLDRal0LPK3Cg/BquQZU6DobEcovJKxW5v0GRYGka1yXrVgZ0u10ZoU+/i0OP/VSS7hqLea9IVa8nIR" ..
	"xi88FdQbVialvLGmTiRwi30G1nwQt0GscFcRsIxsvDusbGlZg0FflTnIfRC+Lv39aZv/8xJXLGxLhsMLRKhsJsl2dFQzbm/28eyE" ..
	"0MkAo51zYkRi1FKopOOpSTpjeVgb3M6YakSLadUT4WbtLFMW2WXJJabLecbMuhhdy9CsMhhJTeswE6mzgnuEx9JM3/QF8qv+Aa/X" ..
	"ytfYZzFygIq/remSA3mk283NMbSZCYzCQv7s5nsidI0LJZyr4AXzZCqpR0P+2j5HpDIJoU7qXQYYlg==" ..
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
