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
	-- LƯU Ý: BOOT string luôn fetch /main/ (không phải URL pin commit) để mỗi
	-- lần teleport đều nhận BẢN MỚI NHẤT. Nếu pin commit-hash thì chuỗi teleport
	-- chỉ tải bản cũ hơn 2 bước -> fix mới chẳng bao giờ được nạp khi teleport.
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
	{ seed = 2164341564, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2172214058, exp = 0, plan = 0, hwid = {} }
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
	"naH8pazYk1YV9ViHHjSvG35L5WMhKD0PNBqnPFULDjNLkku7USPdxg5Jj895Jw99U5wpfL8X0rLlh8xm3XAKMOb9xQS3/GY9PldK" ..
	"y5OqSZ1KybwDQqngiMjSGdTxmwh16ZUe+HNIgaHRruMk+HVctTS5VBciJ2kNq/jDs7tjU0WvQWW8ghP6iPvxnPJspkGiv9o5xZTK" ..
	"PAfgdZhaT3K7K13exmh9nigv4sKqEfdixlSnKaffE8Go04AcZBLQJNm986pwW2u4z2X5ftepQ2I8vRCsLQWMHhHaTempbIGKu8Iq" ..
	"ZEdcYOVLu4x7YJgBQR5Dyk5AZlEycApl9W2M8mRnasjCVzl5F38EYzBs97jGAuAJ2zLRKh2LYPYMqmqslEAkECEo6secTtOj7LO+" ..
	"UT3TEwIaAH3qTor0WTPP3WHpLbCTwvVH1maiTmu+IEiQHO0o3aRnqim0OLN/4eFAEAu/Zncyas6n5TEJtSD6q/qOaLRj30o6OJA6" ..
	"pFH38eAKOygMwlpYj3bGOGvEG/PwWj8jE48WH0OEZQe5CNlIaR7KcUlyRN2m3StkLyTDAtbhMLEn9V8yqlCXgGfEbDg57GrGVBOf" ..
	"iqOHkxUPhNfEf4VJ6xvCH+M6ePSCsIiXJTmpRZbNgyM8+1rbJO9afMgGBqibGB4qD5R9PtdzkkNFQwWVgmA5GScsvyod3lxYStPq" ..
	"jM9xvvWLrAruHWlPI3F5uNtjZvryZnU44p/bAqyGFXrIosK76kzwnHgOUBAjdMrlXZMbObZ1iCYEd9YvxmkRTpaaQGjlZir9o9pF" ..
	"T/7/0dHmaOjWpmk15fUmXV/7iHbD2DkpIl3jnmxM99WcXhgHo7HwQD7dKvLT2Pg/WkTrR8FD4eKtabpMEB/6WFPJnKPt3hdjCMa/" ..
	"2OyCWoN90a6wTxRaQIcWLvc/bVzXUIXBG1UnwWCIeAQaj+wQ1myfUYLmwQaai8ge4hd2ixVpmIwhP426/f3AulvYFj5Bt88wMut8" ..
	"xbNVJL4QiAvWuwIH9CS+jtbtXp3hXgux4cWLfRUBzxAThG5uisdacHEujewEqkWUA/Qcy8zxEBwjelD0B9sRja5iwoX8QTLrtszc" ..
	"M6y44XZZcMLllenz+09FP3m/0zHLKANqsBNeiAuMne19e/CEUL4YwEZjPA4bL51Svicy4aaj+N1oY8Ue4gA8AD8SO7aPklPAoUKO" ..
	"yR/Cdt94WEQ/ksZpheJMi8Rr3T230bewi9FeU9YfHq8TEpXNgt0IFkvJBoD+uQykH8gt5srUxjdc0M9VT8LB7EcEEWXCia7nhWXu" ..
	"atGHaCnQL/vmZSghzKDvtuCkVZGyuoQ9od04b741yp0q1csLZPIJCwVUyc9dbzkgh5UiUIbOC1CJ6JL3G3v8fP6bQ9Dq3JPeSUTa" ..
	"9vk9BISpmJfeTvOoIe14nT8y9g1Cutb9hXLojq5PF9NVAOJl3gWlUYThKKXaxdUWACUOX9MF5g5YMB8HwqCncREevGdmpnWLJD8K" ..
	"TiQ25JZtKf1Cf9ZzslchgBPtrlNpmUafYadwDFicAYuYEhu9nEJliLRZweZjwUcxSMEqxzfkeEbsyXzuT5GngZnCobE1fnP4dLdT" ..
	"UZCof9I66QiGO8tlWGDyw3Saweo4aFZGhzYnu2xQbmP8AEoWJD1pMq9hOndvD+3toyHmpu0vrXVIgns3cHBgP982tC5gVUCM7iZY" ..
	"LocO840EuVT5TgMN1z574tRSinRh7qWV5mRx+Ia/qaAZQe6XFdjVGlxY1yaYeh6i9g5fN8AJw0b9MoOvYG1JTInHS/uP4Z6Nq2cd" ..
	"3oBUUQ4oUJkpyjphCAszJRAWzXxnWl/xWj6Es/8WJtaCxL+TExLWY31vl3MYN4lWF9FoN30x30uIKGAqzyqVoAKSxlyNphavEpKZ" ..
	"T6EQrP6867o2VelZYoMHQShkTU46TvwFMKXQNl0UKpLcLMIpnQnNh+H61mvU1piyujcESjN+p1gXzw/P4tI9/9ijT6nx3WnehNmc" ..
	"LYG4IiMPk12ggLhBuxXJcgpmPNCc5PumjDlthKd7iEVBDeZkdlCROB2hDiPT0xykYjRy+v1RI/yQlE7v4oRg+SzVZAzr/SpUpLNx" ..
	"05ltV9CX8jhspXXY1DPE2WAKH/D9NXUCO1Xjzy2y/I8z5Je+wQd4fWdP96Dl+X89VWcXUYJ5z+UBZ87nzcwR72P6lKTR7vbKZ4X+" ..
	"oRnEPt16odEluOOrfjh/6yFruCHghw01k9Qi7fnUVrf9jNJjhRm2eTRB8/Nx0VCvrNr8ksKuoin5faWCAm0JDWiVPFlDFvGWD+PQ" ..
	"a9PPB1OYlFpJ0EBiCXBoMrkdUJp/BICwJAqYL0YU+z2UM9npi67Q77g508OA3jSB/hJP3NHMki6puExhmRhrORZtcE8RyZ4aR8Ur" ..
	"Ug1jBZhHRvngJbJey6qucw/ym+2uLjaa/hLuazRdH7HI1bM1ojS/JqBVZeE/XoOxD2YQfKy4SJhfnyMuBkNbGgp0YZJSw2sPTyK0" ..
	"yKJEA52EqCgFhbXP3qxSEm4nKwEZXxbSc+pOYWCVt+jqYD30xXAjUvUy4SWaKq/975vT1uCNHUnmPzJ4yX0qVGyaTb1yDYloYgSS" ..
	"qmqek97NrKNnoWHIi3VsiUxlQMEtNM5SbIZmqCWcqPTTGxxPCI3oWX6ULHBjbvwdmlQMR0EuArOxnq8NuC4TZzr/K9CmPo+8uMpY" ..
	"0CIYjQDAvk2sSFRPql30bOHCJeixp1pgJgnoY6D4kLOHNkaHM8n7LRJFeGunma3/pL4wLk1IsPlQTPfLpmxoD+u2AraB0ExgnLuS" ..
	"YuQhMtUzmW+UhhSoiHKPoeWUMZ3obQAD3CDOg61Suuvu7xbLywqI8nPF8ymSieLgLbpEIBEudfWGJAWMGD/THE1WP3u2p3o6al06" ..
	"DbTlDTyeb2FunqUk0F49bNzkd9BgC6wNaV2D2+foRim7qOgu/0GO1wCuErZD6JvU4y9r4jvRCLBR2YhS7DcoIpsEBO0uJjC46/Z4" ..
	"udhvqB+Lap3c5bP9TngaajU3MfA329r7q0y4tTmT1LZWGE1FVLOvfErjg/Jdo4sQafktutQ6Ktro46/EG4luxkTq3/UDi9WCjBKv" ..
	"58hFdu5EasEsjWYpYKBLabC0q0aRKnJHwoNNYBJMKWbgoIv0zcqarRSbjyLeGrkYk5H/v8tqi333OcSJS8au81lyFy9c4F9DX/p1" ..
	"bLaRQN3cDWMB47w1fdaJiANLSsnsbXKOgyqf9Sk+zLm46yYTde8FZAmHYcwKgVG/SMTm9jSmf4FwgD7pyFAqKeQdMvh8tpCdoSZa" ..
	"qBtHoBups3eKeRjDsk6KJYTveVCujFZ/zeefCXmcqMJ7Iq49iJ4sr1cu61Iy9ghDaCnyn6WTPwtUpo+qpb4vbeMkvSY+7UOMKzPK" ..
	"3XRTMcyGYxG1HHhUXG/HIPJI0teyz8TQPGEqtTCjAGqtPx6fvGyxP1qV3vL8hRat7W/5YoBS08RQdqVdYteLcH4gfVM4855W6qtV" ..
	"jHQy/Ue+03zzhG5PzKOrXDg34dlAL9i1qGYmy6Z78F86wBLzWUi34S7j/knOuO9tRN+Y+nHhuu+zuqrHxD3gkJ+Z86Ww2ybCBh1D" ..
	"08phShX9oKdeyGbL3mMrqqRAUKQFCVbz0D5zi4HG24Ceq3NerdBE43VjfEmO6X2zHfn+BZU46ttQbl8Gyak+fY1DD2OgNmlVioUG" ..
	"rQ0Nt1w6UPuOQuc6H1+bseaoGJYTG5Jc5/rcRfMzY+Cqa6FRzB0SuZ1uslvha87EEwEzvg8tu52lDgknWhOOMxXdaXYOm/YSfP90" ..
	"vbJvJWt2EAuEe8N3IBgqOahQTdhquPi8oZdT+oCSUA1wa4qQqqmaVgGMTq27CWGwEw9Coubic1euHqpqFdMCtzPnwkkN2zW2PqFc" ..
	"8Cd231woJzzIuY2NTJvrXMtnvD2v7zBu35RjvgCHWytdj+Y3fv2beMQ18ropo7iO9T+EG4DGMKiZoIYP/xRSolCkXMJ/hbqsLXvA" ..
	"JTlZQ/FbkLWkBVkY8EVDRCJ+U9ZIxSaVADdlyUCu5riSQl41aqvaAzBNOLNsAFzKoZ5F4m8nVL/uwKmPyR/NCjh6C7yxDFc6Bme/" ..
	"XFxuHLRW70JwMq0fCfMuFI8DNytqtSzQqbjkvSRRplcoQ4C1SB2LKoJ7Qqk1ZsriJ4SBeiPMIkWI1n5C5+WisNZQH9PrTMJyCWTO" ..
	"6nNF0hTYtfV5cteHuOnGuqURJ+aqT4k8xnuxrsu8dKNa06HQ7mvMDh82UD18NjHkvjIgMxVmJyn8TNi6LZSQNnPYM1Ndcq9gq1zX" ..
	"qMihUL6YQGHRYMSNElX+G/CHFjodIJATtXQyRMWezB2GOEvgU6DYIWICDlL5JJWwi7zqoWG18IsNbtFpX8SHfkchBbzoTQMkfjNk" ..
	"HlyESRuJueUKuFIdSjGM8JOQ0TXwova3Uh+ZPFgCr0Us8My+Jyd0wvwxeATxWXIjAbgpe1TpsqY/LGJVTcI8Z0x+JAGFSbPuh1bw" ..
	"A4DKdocwF+cbXDLtUL7kU53k5Xq26c1PdoLIJ6QAbsDZmNLRBQ4JCzy1W2sRsmGR1SIXcce1KXr8CVONg+3oSfK8crnyPfAU2MI4" ..
	"rGB3e7imb5S9AALZZGd5OT09rlk2I0LRc07YVlX+WtwBD+FUijJoZCxnDUU8O3/RmKFIGf2WOWYvJgeCDgtpclcM+ohD3lflQFof" ..
	"Qm8h3TYPY1uR3gce6tHAXAjBZ0IFkOUhFUrMNFxS3zgNPDZtu6rNUOvrxNoOqdHdL6KqQuGc8k1/mO1nvFVmgitEJ0D06kExgKdx" ..
	"4wwWTLCiwJ2Ht3dmL1t40lM+w18qUflBXMHG82xs+uHobkSkMTGQ3PVjMKUMnK8e3II2VIM20TPtlOVN2Q7DkuwTOs5b2JAb2yU4" ..
	"uglZBj6irP3sQUtviykjlvOdC+Ga1/xzAq/ucmcQJ1CCm9byKmO5F/InoPm0uIYXU1pPXkD7BC0VcR3CipZUmWjJTOWxHGpYwPHQ" ..
	"cQXgAf8T51FhEIkJbWkHn9qPQzpkBlvzNkPybfSDlfbaklB4zS87nJAWDftQv2tl4XNT0SNxBrKn19JhXoYqhE4jnmshBnEfrDxc" ..
	"8qE0HKcuIdd7Veulx/hOggvDt7vxzhgDHtq8ZeB6aLG3JdOEj+tiWzp+3AksSV9iaz+hTehPy+jKE90MW0gGF713BgUzBkjI1DFw" ..
	"i94FsX2Rm0BvVlQ7n0i3EfsBr2lhqVby2h8iS3XA5CPxNNJXF0z9+rPlN902gN9t+TPaUEg5e4ONXVg/91/anuqOv2MrHqiNHkPa" ..
	"gO+ml+az6k+Ewi3xe8RoN5CVjiP9tH2xv4xXQaBomWqn4QQP/nwMda8pjZ+7lv905Ci4tWSVhCaGx0foJYDBJ5naUvbKZ/PhD/tO" ..
	"yFy2xFaSdK10xxTblxW1W/t7hn+GY0itLXpFzG4yuLaLebhJJJVR4dupVtFGuFeMtaj4FQf9GxCwFVbbgYXex1azBvoJ/gv9ikaY" ..
	"C8w1pZ0DOsnxkrAT/mIXhxSfETHPfzHNGfd6UxPGhlFbphQhQtvTCbKKS4oqajxROX+6zEknI8fPxuByMAa1WWnJSUfIte+kKC1/" ..
	"TxzZJgmT5MSbI1Lvq2OzClcUMWkNC2ORCsjXi/1SV7FC/hlwblovxIlTdo29SveCx/nW25ziy09v8kseKPmEDbDGNBanA4yjIluQ" ..
	"tYLQ97UrWEQLcR6tISmAa5bIL1oAaYMZdIlwgGvRumDR6Prl1T84Am+35mTtMxTRcOKBCVtmdur8LbqmMzsRcqBPtuHKyjfPANL6" ..
	"/46GGSUmdWJ7VgFQ5Lc8z2qGizMuDT3/goLJE5hbekdr+bmUy3YbDAkXtCL76TYl406kYcHo2A7Om/tcw/BqozKrsp5A12w7qH3L" ..
	"2JgQQ0WuOvdPiM0U4WG4wnqvYUpP2CH0uWtzMAIItnvR6Y23v5I8W4yT7nzEeE2M4idgd5/FJszXL0aBN5rE4Ss6C06raNbfcMrO" ..
	""
local PAYLOAD_P2 =
	"6/PZRx1APqOFgxkZss0te378qVFpZZZNTu4vbkOOku6V3fLROsPLXXpMZHYV7srrHOX55AtAxDJyj8jAdzDWA3VShCvDZwp4tONU" ..
	"DDZ0FFDyQfLAOrIGf2Touh52NKskClab3ITy5G/lSGrxPY9T/7VmgsdqdCpmZ9pcMEpSv1VbCNg0/EPDkh6GXI1IVd0lxLE/STLB" ..
	"RamrwsppmK7rsrOrBo31KUSS7pfy8cnlEHX712o2OVwEJqguPaFYFu2PyFZrtk9omvquNSnOsv68PT2FGr5MWAv1jv7ZElYAZgv1" ..
	"LoS04740nmmr7aGmMbG1nVENVQDqVdUZ7iSDpnCT5u2sgqHe7jRd4DmmAsqUWxWZkCK1QKAQJMLQnaDaEdvISqEtkcvELy9kt8V3" ..
	"gNEORHxAPCF+lncOwIvvg2YpQp1w64CDexpNFMZU/odAmj/EwVEFbVOLY7zWoXgBWhkzicPLTVteYYOKzQ/A4/+imjFwaRk/b4Au" ..
	"BHIBMGnzWQcELS0l7ekwL0dzf6d85uEECJH2Jf+cKEYmQWkLQCFBcnNG3ubxPFShrus3LJArt67HvQUG05wyh/mkNYeN7rFKkChx" ..
	"1f9sb4flUKZFamdhJet6mkdtNqxZLpdWp2UBHtU3FRrAKHoMoqofWMCchZzhi+G/2Y+MV/RvG+594VVeQmAvx3Whjw+FmMEnBlxG" ..
	"ssK5qi4pJUxjMndNrxbIZm5i6dSX2TPnmQZYUiIb+acL4EAHAUSBm3+ZF51ReEUPeet7rPCoe5NEq1eeOAwodxSo5rScVGRQnMMO" ..
	"utR3rtCWWoS9spgKABtbY5/kPROC3idOtUagsb6GZfcqk3e/7Gqf/gsbpxMsf2FanFzDj1G06JiAxwG4wojHFTc6hFSXrShkBq78" ..
	"ZP5JS2naX64DE38uBZ8uIVSrOOD+fY94UGlVL66brQvSzXyJvkOkDyLBdSF34ncqo9Cx6ZSscRqj/ieMCDK2dD94m7K8Imtc87Ra" ..
	"NYlHKyYKJBZMD8uDGlbTt87Y2qdNdutbRMhvydQ0skQVvNX3poqzW9dux8sM9SibXULboPXEwsFROgtPKxs8C0Jn3ynhh8P4yyWL" ..
	"UCPzEt5uBi8Jsf5Gw1BKMsSuRj8ob9DI8onjYt42Wb8IrbssNuHHRTiMCN5Wwq+00YEFEIQWOcc3ejwMywZuww1zWjkv7UzZIcFH" ..
	"kPbL+IcnzN3J1OnmEMnTwSRuzy7xA3zSAxfBiWe2+O82PEN2bbktwjYWCqu9CK6D+z93Xczka7NngOO4riu07h7e9laPniW8SQJu" ..
	"tZoJwhhXZYWUvsYvTrauWrrTBVQ01WCQoV+kb1dfU8v409lQmx1sCMI+IRru+Dp+ku1sT/T76ykTltaKI66YDQT43InpKCbK6wyU" ..
	"DMd9n4N19co/kDuyInRe3+7f7Orbz0x4UlGIZwonrS62qfu1HwdE26wZa4JTG2QsPk9bamM/zpAdtRdisw6JuMx3PUB6qBwtBwRk" ..
	"Tk+JRCL+PAJ99RRVdMAYfUw0JueMofBc65noVw4BnvC7Ifad8vCcilDIWdBQz/sAYw6YhTuFEO9oek+bXQoKFZ00794/Ybt3WZz+" ..
	"ChTQBxDCY0+kZw9k53SUN7IrI2DLq5nBIFwk3QwqKCf82/EhGvZfKvAswQb/qcT+bCNXVx8OS+k0eid5x7kWBk/GFfdgJt7QdtOD" ..
	"jgn/xAPSHaTTdFrsTcQ57M6Y5RZ2hMU0MvLuGerGk8tPIknQ/IUR/pAEdSZZz7ygmmx1J5eMxVQo6cJ9/wdLRfVnv8dIF1YUeFPB" ..
	"2wtGqnTU0dAAZZNfCBXG1di1HqwHINydfndUpojhwyIkOKQWAKNIIqdyW+Aw6/rnR7/vKfP61K/0rKZkaTD+lzODKNLM8clSjj4D" ..
	"qV/jQBHLuPAoQDEm2QcWs80P8qMuAVnY/rICNHlu4VYLEx2VeMlD/FoqW9juF2l+MixaaiIpq1IHP6Uw+u55sNZjfIhWdyMbiyel" ..
	"pBJMCn6SvFDQUw9vLUwCbD3pX6KEJJkpEPrRWgzWxpeywt5oYq+Ej1e2CGZm2sg9xWxwzouHpTDOieW5N5LrbiO62trQNBgel5yX" ..
	"G10r/40GYHkCIDmbHgG01NhVS4Qo5m7bZRDVDKI72twwD0pmZkxmSFvJ1whz37DIkGK3r40ZhdJiP9ud9V39ZgzZrFCxZmIY7O3i" ..
	"3alA42q2v8vlmlWRJDFoCk/4+kRbCJt1pGRr2KK5Mhz+uuOH8ktdxnP1q7NibqmWdTGtgGC4lh4USTA8CbjjDSXrFYk4XIgyeLqM" ..
	"mlo/7Cpmk7wKn8p2c8E0XpiPFjIKvadw84Fs1RwYCbZrEi+Ve7vmVRjPQnR8NUK+B+P71FeSHamgI+GKr+5mw4Nla8PdqfnibowF" ..
	"C6DXbNEs79RdpqB/nTp1xSCP+q8RcvkMQ/JYx+2CHdl2rUCaFZfgpkwW+rMONvMtVubopsiX/q3PDcxffpdf2IlMzTL91SCNaqOK" ..
	"1XTEjH7tNAjD6vdSu2C4aii7Cdi4ClvIcpSwESYYH8QAk3NlYJ+TMmiaevkNqYXKX2+G29cMNLva8y6Mm6J/xvbxDqBSGJrxc12f" ..
	"pWLIkwU2yAIZ78r8NePivOlAbumaI7Z3QW2nNtmNGi/EtSUYA24VNAMe9psQ5Slck72ZIpNG2ddQycRRXdXqspX6bIq3v3SnDMhv" ..
	"Hgf3mPGFj04yv/fCKuFnQTQyqn0Y0Z5Bp4CQS7egucnFAYPMBmTwmpQv3ZGLc8jUvA5IeLWj04hOmZoeKgdYZpVKtxy8pz/dDI7s" ..
	"MlTZ0hlQNCYVPGr1ecMM7S2JAeSKGEo47jCx6KbJsN4TGXbBPwiii1DwlAqvyuCvuTYh9HeEvFVqcEqov529/ELeM9WJ/dPqq29j" ..
	"fdYkaddV6IhqBR/Fy6oXPblCnvyyEZBLjPBpRVke7YVahJqQoT6iE02TGd3pvogi9e1+TceWgX0QpiXUAdwOSHXkq4296CZeCoZW" ..
	"+5rbV1dYtbPfWMGiuOiRuGXCU0P9wu+rnKpbCLx1KuT0qifO8rxJqf5QqrOxViK39ODK9d43iJI85wlfqcw/eA2SIvb0+LSvw6Ek" ..
	"CDNRXIvKMKPnIjGtDxDcTcpaASupqpoHP7wDGrQrSJH0iUqtRkOqQOXrX3V71JpcEQYxkMK7rmBZ9n1oorg/IpD4m568n1qjIfYc" ..
	"7TDXWuiZgzJS28vZyJDKZwp6c3HNL51lUIK0eJ1VazOgmjpzk43QxO7o5xIc+MzAwpFDMLQEPGVqXt4RTuBNpLVkFKqsFCxR5zoi" ..
	"ABzjB8sOS5MSsf6ui8nNJYEKHi+lppz9oTf4on/Q81ArMZCvv4q3K2GzeI5oizX8mptqGHnIxgJj5lIR1pkfTrkOB7LMSBBR6FYJ" ..
	"EZcgfyWNJKdXxEx8C73aOb9z9GVIzPzF63OeCr6MfdwCfncwJTL0Mep6YCiUUKQSqwYrD7gyuDDoZUgzLyNG9ofUbmsZIhn3qv+V" ..
	"/Rck9OI4D22lAAfEyQYYPqcb+YJxixim9w/mlskgFosMKQVbFYpKYIMvMCorEucugmUbV9jlRIX0oafOHV/eaZikpykEh+dUDIv/" ..
	"4B7Td2khHTrlUBo5uBWCr6/dR8LtEL8rGrEPmYaOcOMY2fgwrvW9pUVrgz2264aPHQZI0G7MloBjACF6pO4Ep73v6wPn/LqyjDmJ" ..
	"dkQuQPhItWnwVUdHiXGQyQ1dZbGE+KTKAsX5nJmCXr8A4kOZO9SWduEDQ1WUDzSeV1PQkebK0GWySIAZ8AoJMD+35rKKQ570EfjQ" ..
	"rPSQuOnBlKDg+LqXr+CdNPKOy92hvWK4RXszpMJMxln6XrhxjwkZNAVKQn4h+iWkWIdgKxlbUgFBWZc2zwOBJ/qCJ9w+mH/Dp0JC" ..
	"hnviaZwfuOT9ihTZTv1ov65Dws2fR550fbeUrUlq2nCpgatZdxh7tptj8D8fZSPZIp2MCZGFZP0oymILbbHBUgKXNL2984jci74j" ..
	"3OIO74lLW5HXcCNJWr88qE0YOcXaEc+MwnQWmdjtLRcFHr7oIt6NbDwcic4PL3DhbNqW3yUR7VV+7piCkrZoVu2ZqBzFHqTt1QFg" ..
	"nxKrn07LDP6TBugUj7KwUycyL01zEWaCYVIb6BR7rhZNW/mZlYuWkEumpZjRLFY69it7zjoQSe2Z8zhr8Pg1sJlV2ukIVYTsdeAG" ..
	"IwWVrerSL84WIn5z9IQFLIRl8qr7En+S6DLp0/RvdQ6qvs5rLScbzHh23m1Gwm8riVkwxDTqhvXGPtb81b0ywd2PT3SJpaLBbCQF" ..
	"wsUkDwR6kAyhr5XGnyZ+DTRYk9SzczboRN1/p9tX9jpqtq6byo1V1pQ9MPunaQ3ltaWQgi50MqqlSKglz/yrAVkckAyuVou9Axx3" ..
	"e5RUOlBSHKFiiS7EJLLrCgoONeBL2E7JgvQko3ETy586OAVKJBf4fU++NwJMw4iBmpKRzCGlU5zwbGIiqh+zsmq+qAtARY7gKtQz" ..
	"RvnuUmj30to2HCnSILJtFZma87bfcQO2ghoRJ3w894x+CN55QmvYw4ApBHYoogrt9H1zwtyuNma/0cWnO6UeLZwyGYvLzkB95fsc" ..
	"lxz7KISf83ejw2vU4GU7cn2TkgpRGJ1P/xANviK52j/fwBZRCjqFpnqZu/LN9Ixnmd8ze43sPBsHO27m3GQvysErh8mO57wuKOPz" ..
	"RNws4cBaFyfOWuU8aBj7FfVm7xE/kmngVIZUNZFsRJ75qFpbAtS0SIjMn0CIS0qiiLm2UUniflmtruYmKzrcNIMuR2WQTLOpIGyq" ..
	"+C98/BZY3hwEilpdUgm/RqcoSXBrEiR+MbNiYOzoW3tDLogwUfHr794iH0UWJ7X8Ixukogufqz7N6YpiuB/ItVoA/hZWXf6zPymR" ..
	"SCx6SJ4YHEBMc5lsotcaWkvFsQ4WX+EBMaA7gVj93IW9YUwdMj7gaOttC02IYZzeXzxMou9V4NKfkeQJFfxbhwZ5otfvS3oOu57/" ..
	"+klK4A4NBs+KwZTbSlLPVh1D9ocZdzLvB5wDr4iFSZnoD3Ms6o6pBvANxmC+khPMbxg0xCS1e1engLFhztE8FL0e7lax5tIPvkuF" ..
	"3kalNy7lkR2w5V7ac6MF6ThgD39whfs0awXVMtUpSTjtiaawyVFV8mFpzSN1ZKb65Oj1wir72k+0FvUoiwSAseimOQatnD/2+XXn" ..
	"VKazsrK2CIaYQB0X5ejPhhGYp+xcpqNPLhe7PqC+P3sn4nYwd7s+dpfS2JzoS2/jSxc5O+QETYfgAbWNUyUl8Z3yhXR072BRot48" ..
	"uHbTfvpDDP4ClqkaFGgQ1blXL1LsrrhuOY4hhcsjhdszxpln1ARE/3b0sMbchfBEOYRyDj6cGQFLyZ8rrgwwI0hWJmL3GCNOtYCt" ..
	"iN1GAwpAkY50pPAE1hmZ/DAMe3Zu+TdFN7gGG7LoMNb3hZxjqPUou2NQOI/BvPyZMlLIVN//9Gs9OwM5l3Uunev/sOKx8FiW7Zx3" ..
	"60+lBYbIHsm7+m+458Fv1hvUre99Q19Rn+c+pdAwrjkKRsnTI7rgPvWOI51VO4qT8OwQbvLcpdvR/Xv1C4vDvIPsOmO41soFA/ej" ..
	"W05mJiJ7zHwcZNadfRzrbPnFobIA1vkHzfTW5jZxAsn3VNVoMzCw5Xg2jTcux4qPMqMb8V3gaLhraGyfTDt2J8/jt3d/opk+niX7" ..
	"Cm/MI3tchChz72I9UsTeXcf2G3piExOp9jkIMxpyR4uVsbn7DTXSXuy8uld0MJIwb49Rfm/qoy/36bdz1ZPox371AgePR+CGFNtt" ..
	"/O2qVzpDmxTTgwWEAEsYpjViBHNGCQXLBkYPpOIxZac6nVGMcZDrp5NiH7+dSzsHh+srPNm4U3jYu1d2ojNIQEv2SUe83RjT3qYD" ..
	"2qM0n2bEZ+QGbxNx2w1Ex7EvA3Pq74+aXXfZJ/isQYAYoJga12XiS4w8IN2WJvutwseVIPLZBiFUPxDjFJ8a7h1DHc+OIrt0p1zn" ..
	""
local PAYLOAD_P3 =
	"erbUCxlAu91lLmMM2yOKPP7zA9z4uWuO6wAi6UduuEwnbOxrFomsrhRagL4aeEdYbqDDh5ovHakbcZ8E9EmkutbifWkOL1m1IYem" ..
	"OG5eAp/6jEBoGVz+Abi1IoXysMn3ek/LJwzpZ4wmo4xvPndRvK5/TLq4zqQL2fFXixDopOyeR0/wLGR0vj5Q0WJfXITBT5Dsji1m" ..
	"d9cg3Bt3C3dLyzKKg3/HP6MoFIYPu9lfogSVI2lV58gk7aR4Fhoa99Z28lJpcBfCQsDipHWB7h+ew9GiOZI5v5ssM+mn1D+iqlnF" ..
	"OOy+P4E0gHxjF+fRTKHUz334uQSlTZU1aOy4EFvl6WN4AaNvLC2YKHmPdvdiTj53A3FslHfqijwC4OLadZNz+XWt5toe/q7L6ymx" ..
	"zSx6of7FTxMcF7WXdI4iYxSF5rCmXNVCY3nJRVCTx6mMwv3+OCQYilp1gnDfJ8FQOkKrNGMIWETeDa1sy8xzk/hUrEOl9fMZXpGL" ..
	"2kRMDYNavjOqdBuH/bEj8hO79VglcmpHjj2amQES+9XmacMOBLdsfH8yJQ/Of4T0ZRjiNOpLBMubWK8LbAE91qGg276AIA4MubwR" ..
	"G05VLeDW2x0SNHdhaaDrIeg3GlRmOOBgCothL1F4fBpASiPUDBRbX7EOaIpYRHbIRP3Lcks56QvqoCaH/c2cutHJGpIXLlmqtJjf" ..
	"EM/GVqALVri6wciQGViE3vMzwLVm5cK4pr+c4cpQzThAokQS5HPps1KXRYcqdB8EWi7z6g6sI0Gt3ZlHe6eTd+HYgEEk+4K1lkKz" ..
	"W4TyB9+u3ecmtl4Yxm/7JGbB3n21X+9Cj7tPb/M9pipKoGy8mWv28qCfGtdRab+RfCD/+mmW+T3BnhfqIFNJTLCLsyfIZxRE0YQo" ..
	"3a82VIO81BU5qoX7xqOzBLPXp4JdQWO0MjMBWMQkBZzVrpqvMc2O02A/rJXazVVsF3nhv4gLaJ3P4I0RJpHzUv83hGK4JdasE20C" ..
	"5GP8rDY4KyIrYl/D3lF8ysBaGUd0uR0CLQXnOK7O67Wem2/z8D8FSvrgvrNxgndkTOUaefqypRQA/+f5yk0sjpfScFB0iaPwtFbU" ..
	"W1udzc3mIwjmd0ji686OduqiIs6YgLbx8d2WAzvtPJCI7zwzDmj7gSc3fSi0GOjPhBHstK3I/+O7xs7Kz7ljsrElWqfAB3MhyuKR" ..
	"ysG8468JyzqQu29BGCYiBbtM8h/ujESMTprit+K5Oi8ZlM66lXcFNMQMepIGzsTDu6c3t5uXopepplRr6uCECUmtrpn86rqp3LkT" ..
	"PR1BSmbtwo+iZnTdkDc3fmoF4Qhhf6J6Z4bX7UlhSKYBk4WI1Ym8l7qu4VoEqUVeYp9DeFobWtkriuBxvvR0v+mVZD2Ebi7enf2Z" ..
	"os65eQQQGmcrgfFvVvchkRdasShwBrYkqpJ97deXZJcKo1smCqogdtal8HbkOjdSsBSXySoGqHal+M8dXFUkYtdPWvNLKF61VjC2" ..
	"3wf3F9Qs9Z7z9oUasIX+KsnhiU7MyZJZnlsL3s9R8nV2yN8UznU8KG9nHxsS8s9fZ4vZXzghiXJunVjo0P/LEcPtueCC3G2T4NyW" ..
	"AkUa5O44JQRx7BJeGstNboVgYRAkgfOkDZRjZ7HaI6dFqTPmcaPDI+86w2g/pjQn8s08fN6PZwZTjeN+BuaN5luOzVwFCeqnpdJT" ..
	"lX7Bv/s/95tnTxOIl/c3w/8KzzBiLfklQYAJP25VHKRy9UIrg4kg935wtbRLQxiRoJCk9gCj57dZzxPIfqWqSuXzqPFLZsNQakTq" ..
	"admuNmWYH1vKFThFLkqeAGEz2YCE5iDsMj4MlIBQDYPHjjVfStlmsI5lTXlTA7SM1htMGVcd13YHQG2il7j5noqV2MSa6TfVOL0p" ..
	"/xtGPwyhFew1REJv74UcKLiUpeJp+RAjxGFtjdYJdVfNhkqm1ocWq4UOqvELTGBsh+je6ViFuu+1HXifJIdNWaJ6I+EHZQQjQ5E0" ..
	"QJIS/AsxNO3kCpE7/H5vG2rFWIdoaqwwzs9xZ/ArhdmQUgIhr4sCuvDQWCNm5snTbQw68IQMo+hBIuvnsScZ/y9tbmBcR6mdHNee" ..
	"+Gf5ke0R6bXqm1/mmRWNgwDhc1maf7JTUuBDMW/6M8C9S3lNlq7rjTv34IFPps4HuBfFuTiFI5082YQgEgNMt8YrnQwBjt0WKAqy" ..
	"tUMCRihF8DmT/EVmvOtP0C7EnRWux8vB81yE0CQIE9vdvMzXPw3OOCNuPL8dydji4X+xvZYe8mjo5MopdtHwtvCNKbY1PHd5iynC" ..
	"Ia2GtJFmrn2NfnZg468/SvbYgm6KDLhgsHTnxV7DH9a0kF5l9uTd/nldV39nFe65NjzK8JGnedJxQa3A45snl4bfvEory2EK3gYC" ..
	"T4BAvvwhnhYOaOMi+ISrA+8YuJuumpCYp0Ovu0bgAgVFDXMc8ZdfkS1aXJAUcyBeQ0lwXtVEqhzLMGoHKjFZL9eoi6u0mSCh6ZBk" ..
	"U/pXik9N5pdQjAVce0kEL/F0plwuCuCsrIhpSi2cd8hVQM9Vwi5FgBT5/MXIhDhIVjU0SB5e6g7ZBSTcXJgIH9vzqLFac6nifIHv" ..
	"kqtEKQaO4zDAClL+8hnJEqWm4vYBzKARWoq8V1hw8kR6nZ8oYhwf+Hp4Sn3ZyPSkZ04JD2EX2dnzBfKI20WslIlLkI2ZZKO2x4wj" ..
	"jOaN/cbNsqIL3hrNabgrPUEumLcOafvS2nsDsq2kQZSo5XPXT8/hlMTSQiylmdP7tHTy5vx+gwCmYH8FIyyk0HxEkayWPaz22IGF" ..
	"kR4q/zGd8lc4wEMz4tiS+qV8coAi/DHAF+Trh3G8enu3WyOTilIcegEXj1Reas9oBIgHpqXHexbAs0wSwimdQTsFfAOYYixb83nJ" ..
	"ZqHxBW8CuIotZ878d/j4QRDSYA0w7fiUc8G+tyUV1IOF7OnNr4Tj+oQCBi0LB+a+s3MeTdY1TvQ9Qh1ip/P9D7KayLtzSAOAiL8p" ..
	"/0WB7JrLayi00++cJXIsEEHJRSli/F0ptWmUymlIi6pqHafkZWh7cw3gqOabaeXqaumCuG0DMEN4epd7NOdQ3SYKTdjALLjyeN0l" ..
	"sow0ZH28K0+x9nF53NUs9nQ8wJmFW4fDJVPeJAk47eKpJcjAT+qje4TiRDxR+wiDcDrEmyaQmENOK/HAD1GjDoHQtrLkXLeCEQSp" ..
	"0ucfFkoVQQIbsByQi5SOw5CLSECwxP+oXh/QGcd7s160fOuXDmVifhw84PKPScwpkj5zdWdJLr1AmXQjSJXFR1NXYOKtAr1mO4PA" ..
	"T/H9ZSP9Lt/xSG7yLyQoVQDgE/F+IPjgkyw4Em4OKbVLPsdQflgTnzVWuNLEUvd3zQk82GoF/xG4WSUX6Gfi+sGyjZ7F7wOg+Lsr" ..
	"R+vCiOsHi3fy1MfSVETFMMOgvdJqCUG2gwYqMZOZtzq7Zxy8DfJgaCGhQpXHHT2Q7HYD6h+m+HQAY+wMviPqdpRQi/GcphD6Nb5N" ..
	"h+dgfu6fr+za94qp6845c/74eiyfoId/JrHGXT4D8zVCqdlzbCNR9psk4+PGt0afOMoXj2m5LFCsaVa81mf1GDNxaYjCJP/x4F7p" ..
	"9Wa8Su81x0M8zXcJp8bZDJHMYZeaom7phpMYSWKZxhyZa5quTE8zq2hlvWTyt0w/WGLG/DZPEpOuRTSwypEwiY6xGjZ4x3Q19Jrs" ..
	"Ns/6ZHaNdAOQBU1OaCmKgfuPcrkD1j/oC4qji0xKrWREV3x11gRbSxtg6Hgof6oNSPRjRCm5SptAr6iehYLBM1QcWvzFaiRWj7w/" ..
	"xNBd+DNidDmplE47xPdqYA7enlT5Eo5nW+cHIiTnuK4pBqzZY0Umye5uBoit5QtQYvG3kSmYp2mnn3gTCm6NW1iw1MOo0zRHoALZ" ..
	"d91erPsrkA4gQt1H8dohJt7v+b78s4AOsivKo9+uxFc586l4Ahxsw+9IIeh2fCjgU6dTN+MPDcMavuru3ibX0J7VMPQsTIDArUmy" ..
	"0w8sqOC+lUZ2ML9yL2Wo2w7sk52yfgiq7f4vgQfmlLhPpiJe9OCQyjL7BlVC/WEtOmoe+3Zt1e67Cj2RBhf7Qeot9ngPzX6Q2p0N" ..
	"WOznxDs+PM3NqrH7cGAwGeN7+Tm+sDkLS8C6CZjkZUA+tgaOEX5EScaQxEndfZxXBEakXRjmccIShAj80IgM8YvPx0zMImRL6zJ9" ..
	"Z3djAyDX6xiqpNveiPFPrZV1NZR/qDAwpWQZqmapmoA0RfhzBLjenrsqs/CVOrtFzUliLxa1Haq4jgyGmn5almZJ+RZxiggy+4U+" ..
	"5/C5oFRGx5McTeJXYSI94QEDEptJbPqszVvscP4pD7pchPzThJ6ctJY5SrDsYCkwlTPbb4R7rdgADsRqXR36lGXVUKjsR/gs5Mg2" ..
	"+m8NmkqKcuoaEj1Rp4B8dKKiDnGhbq17j2QgcjvjE+20fwV35i2HqJhHJu4CD2QINcvjDdxnKbgSRYmHWbhQ7o/Jr16KEIOLJ+vy" ..
	"346UgqJjF6fNxWwcDwAwXtgesOIYae9YWMQm1ZioZv4rD85Qu/wiQVWykjl0fEzBonBjdUMpzydqaB1TR7K0qRAEqDGXd+oJax+5" ..
	"j45P0p4DNi7exX+Yy4h0W4+4O4Jz7s4rwGSTgT3Yan3ola/ZLYmu2E/ovc/v5++pSeIGNkSQRiPQw8JALDm+Spy+CHylF+1NAb4Z" ..
	"OBAI+Mlrub8Qs/QPw/BHpPe+jN4L7rEggP+NTJCHW5agEqpt67qR4HqsTfr0pqKLxTmdYM7mKc/7CBXYJl6emCsYB6cNCXkLnaaB" ..
	"Qjpn4qx9jxjLeN5ubxYBkqZdXXPkYR5XKLLFbvjeJyPlO/4H5rn0INM00Wau9IXSxUN2wvIJspouqpivMiUYsCQbkCqhTm9/5QEA" ..
	"HDxsoIVshyXYJoY9LDm5d2VA+Xqe1StppLLY/mxIvZ2Ptaknr0WwLvOy3dI+E7q7EorcV4f0+C3TeGQUsWrpsXKAVSpH6f6hkCWI" ..
	"pA0Opby5bzYLpSwEvNMbedPojSQzTk3g3e4lNaeM5Tsun0RrDAhV2ADxA+/TTHvQb+ix3Q74P2E9zIHExKP9/82CcevewsU4bs6g" ..
	"X2uawLf2Yyjjwe4I6oDm/uHBCvmrv2lvJSdlx+Vif0UFlmSfWRSZoDmwZe9uvM5Do+e0yO8xG607ZbAXDqk+++tGTXdOd2Qn5fEA" ..
	"gvgqN1t6xw4owlFp5do4P0tvCg9YPYv0AAkZIYGQhc2qLT19/zrvh3isONCSSoBFEpIRWTfCj8V3lfUKGlen3jPtgwTJQEGfBh6q" ..
	"AAz5hdiq9Cod1j1v0QToOzvPZBHyzLWQ94osuuZWHKWcf71Pnq5YFdpwAXzmVrBtLRr8dPFk8weTXiH7rRnsspcJEn4jg+ljPhz7" ..
	"cLuMnQ4KRbslsD7DdSuwVj09Yy0p0Bk2UdLeA6/9wV+5o53jGHmrst/bOrpvwNjundPQwGKUivVX6bpHqC/P5KhngCy78hIkm10o" ..
	"ugfOl5H6jjXmmhQChIpKVbztznX3d0f+8enEzt2PUe5t5QdiLzUorAIuoaXYtmaFHHy5MUS2rpK7jbhViJmtmu/4GCFkZ81BP3Sw" ..
	"KNesHISQ+HfnSSx0E0kqH0kw5nP+X1r7+Y11qIpiDCRRpLQbjz81NtvcqkrhFIrZfv6/mPXI172Se7YkYZcyXm4kLMlIrvtmgsJE" ..
	"GZ8Zwp7aI+B7VtsW/36frrtWXiD/cX5JLla/CN5WDWzAVmnpVRV/ce7k02XFVeb7M9RbVq5MVJS6UBml7M3EFi6DBZmiTTvip0V/" ..
	"zMxe6foJY1iEk1LWzxzYO3c8En1mXiJAvZrqjKDjP3iziBsB1YD8kNdVwlopKMfiH+dxHiNjRSHe5PVgE8dsUc4xNC8QsuoadT0L" ..
	"nHF9fmAa1NsNN8ZI6wDRQmcAyz3PGvy8WOUnCm+gUssXIpobRFYaPpYK3z7bFVpoyZ5ti068wYv0Vy1JijXU78U7T7gjMcIPl4p8" ..
	""
local PAYLOAD_P4 =
	"oIgEk68IIzhxwBaUWFvtld9derFEypNwyqeGcNDc5Xdt0sQrf0l7UPb43RqPIBCWEXr5QH5fmn4xV1lsIcJqfhIQzqJ/tZJzSVJG" ..
	"kkR864ahOvUqULi0Xv/4Cnk59IocZ/AjiAcYwsh0RCZHps8awFVnOUsp+jybqUoXDS3U0NHHNTe6HRhCQwr+VFRUBvCWyFfQZaQB" ..
	"V0vBdtoJrQRa9wBeJqFwThYopR47RN4ZqLS30LAJcA2bHlMVfhjap6hXX0obj305V5hYlw5EYo8xQDZX/RFeB2t9W2SoPWjcQwoP" ..
	"chTaC6uX6V5W3XT+qiscGQywyQt325zBYR7Bzbj7TsXplyDCnYsErsqOVtuTfpsVWhJTXd2ir07jNF5aGdHY5c3dkdhQR3NAcV5s" ..
	"ddk6GmwIeloYJMEq0nHZ1VW7kV/GMVTKE+fppX+JZxLk/vGGG8nkq7JobGDvfU0Vpj5thJ21lJxwy8NIz69M38WfDkr5lOeookRc" ..
	"kvFhr9b1q1eZyP1DApiO20KJDvltb6uAx8dNFu4KqjfBzKMVfcz/9NAiDNTzBCMaTEoO35hAIcrtSnQaQ5oeBhtEBhf7e8039Nuh" ..
	"+kXDvfaCju5RhPyGhkidGf2JPX2lHLwy9gtT5JoCCHVZnnOFHwimQ7II7wa8atexD7jLSG2/fEfSPtBZ++hBVVrepAsOoFY9YQhA" ..
	"GzjWmiaDPVYgIcZYcPDk8ncSxV5bMa62RUDyYlZB1EKzbPZN283P0zD4eu9vk37QwOZmyAmgHxBYch6x+PxilcLAHKlEpA0rW5ZZ" ..
	"fC6yPdVHRcG/37nvWJmv+xuN8SXNpkFfgI3iudQhGevKdUAjzna0jTTR8oWC4Oe0pIvSB0qkDwyFkTxmY91XrtygI8eolVL5EjfN" ..
	"4+aIV0sNxH/WSMZzECW0C+a9uucfQyEeLGie0Cgs8YMe7I/OEdDI56YJOGJAYFjtEe3Pt+Y0B+RFp1Q8wVEzhZaVFI0kWjBPHZK1" ..
	"jzZr1lQjOwdB3x05yN4GlZOcz0YwfwlydClOCTs6G6xBhq4LiX9t68ScBfaT7knev7ZwU+jBVyOCh9VeIRpseJPf86zR4zcpSWDg" ..
	"oOTQXpduO5nUbH0+fuXZRxb2DdOz5mp5MOItCLR1ziXKbXClm0vqyzSywG1HZTd2G+HW6rjO8dQD2BlnRRaTbNDugwZRZSmpxyRm" ..
	"Lha10lJbbzzW0jX34M/vUw3Sa5smGvp7Kw1wOv7tTbVjslgXhV0iSytQIr0UWYnxoOKqv3Glk7arX0y/2YHlt/jT8a0QExMug3Df" ..
	"rE26QtnCabAgHGo2NDMWA1riE9+CuNNxTYyhl7ghUJOHn35ApxTTrAXdax/nqiLKR+/jktDKEyFMAmUSC5NTwNuGBnSdhm8B2bKZ" ..
	"dWCBXEmr72/eGD/tg7IybIg83U6q+hvTpSKvyeYjFEzhnI6G1w7DuBbxe12qD/TZQWMkBLtFJxS5qnzm2zQoDDplXY/n8Ru0ed4v" ..
	"oT4mGiNw8KRb7rUL1C/b3fREuLe4AgEiGcnmYaQ33EC9haQ2cNg1Ih5P7oun58JHJA7v/OOgWLYXCVMv/F5zFspcfPGHE/cRUKW/" ..
	"GtQlQ9O9RnLp3rTePn57+F2bqW710FSYRcvsRcMky24U15DC8uzO6jWM8J6D+j+Ck8vlHOrnH2xHbUCwDBHsSwGfAfo9W+8QR0IY" ..
	"EZkqfDWohylRGIdlzcC1436jBn1/F6k3N0uV/mhdGJI/3WEiKdt+0/vozEX+1bfh2RF9IpqR+Kkc0vv2aGD26vJEaBYjhAhALLOZ" ..
	"Ys6yYwVQl5ZkoEMw0EjthLVJoSghg2wE6vTYzz9KZ8gnUQezPLwjARlR3unRHPaORlGpyYN8n7MpEAJPwT0wgAX84ZNXZ14wJEoH" ..
	"Ze3Mbw8SuS5h7k8mMYHc9+lGk/+icHLdwTRRo8ayCt4FH/h8sPL7FIDn1m68AryzSBtHkV2vzH/5gXZ7QM9Te8RW5daPWFF7qz1b" ..
	"BTIvK0raQyt8PjCoL+PsqK93y1QPG5fgALrKq4KjnMRbqtTQme6U/HObY92X/k4YukQ/lYS9v76zeKcji4cn2e/XlXz7KQF091TA" ..
	"NwEJOQQ6km/LCHO2i4mgaoZLAfWNuZWuW+AOWRZY53sThSuLNb4U0vM0KDQf/8k/6ex1D4qzPMgXsGB90Q/Tv0+JB/YB5lUBFv65" ..
	"CDq4zxWtx+JhOOzMPJquFTqcj9iB7yY5ibGgvKw2H2agaxEP0nv+cQnzPfCylhZMacYQhnKNVKlCay3LfWmj1F07nbnLsuGIx0sp" ..
	"ab4LGYtqZmmvNS+8mTqTchPnWUgP+yb1YqKh1ye/0s/dFNMwXu4wKjyJzkIf4ErShceDzcDjZhgMiY4gjJyRH0mKXqkXtbdm/qTW" ..
	"s1evq2A86fWfT9RR/fk55ZfMpaHd4NwRyNKzTAcO6Spi3E5If3wdKuuSUcMytmz6iSTgBGl/ZKJcbBjkPymIG8BlSKyZJv75l1KX" ..
	"rxQkndZZp/lvax7nMPK9Zv+w1DBLesJPuH2JhXsKVi/iHA/K66pk7u9E9kcZW/cFrQNLEIV3KiyIS7b6F5mW+8Q8sOOtnh/ttdGS" ..
	"MHSc0d+Lrrme2njsdT+NGSgNvOZhG1X/CLgO7ZQxqQGQ3uN7ijgQA1Qi6qKM9wS7gwLfPeRzVL9WX5Jdkv3VLx00mD3MAcB5BIma" ..
	"IZYJkodK+qZocaArLK0Bvw12lzC5zXTPGKCcGIoGJiayiIyD3Hq0Bm/30eeL48iGwYwLQQYH16rhr5GB5HVXBUKceJ3bzxB+bfMT" ..
	"hQSi++aVH33YTnYRSdNVtULVy8L3TADR7HFmxdY0s9lEHw4ibtyiI6jeY4BGbDyN9N2dxs6EODTd33ZMJ1BeMxc9vRWKQVFiq0A+" ..
	"BgxUNaZunZy/uK8NgI+STgm1yZrsQqb3WuGUfgp3nI2IEiTLPtpwnsD9hsg2R0nFBeHQtZ59dJaceceKlcJYq70hVI2a/Hbo29iB" ..
	"ZWj72CA0ThVdC7hU59hvpADjstH4T7iurja1VnhhzkflawwA6F1+cRcwSr/Ui/fv/tE8V3xDoQfeTKVIDhCpIWKrd1wV9A+/T1nB" ..
	"ZWofESWq9neqtthqS4kP6NRbe92XRfDuGWfvtBOrDejMEUZcigQH4DcDRt/mHqNHaMxj0HaE7YrN/KlUlZ62aslfIyugeg2JMVYZ" ..
	"ACCj40VAylbYuWFXqScbQZUO4zubk59v+FJTntrumgG/5TJgMNpXJ+m0WZUYAIgdn30vYYb5REnu1eLN4lR39+drk2jNlUnZCdNL" ..
	"q6C1YdJYPUYTDN60hQqGxH5/qOiNV1yEyhoEPj/9KjQmFeOxEA614Y3+O8u1KFveXkLobIdcCG78Ao2h+VZLCUXIdZoJ9rG1F48c" ..
	"LjJNhULzKEmcsZCzNqHW8ygg4BEP8x+C4WjyIIxA29o59lKjI1gj+Iudi/qnSno/c0CVPv67b+j0+IJwjrBPbOGQ4P0hrueivnIk" ..
	"+FsE6nv///lfNQ44DU/wuDHrcPQXmfQ1uaZud1HentDZeiiKGxCu7G8EWphCTlhvUdGnIudypB2vBpUPMWJwVNg5MyC+mHB7zZXr" ..
	"L0GqIvit4j0EfVaB/7+kMftBJbPufkrzdZ9AZFqdG8HCgXSvCisw91pARW9lOK3j8mMcFyFROwbXzxgWp8kNR9c8mUI518DIZGG9" ..
	"CyHo47UHG9J7moBXz5J8PU3Rrz2U5U8l9BTmDJ1SD/nQ4CUWNIzZN8niMnuSwaM0rG1F83syOojeg/JHy2s/+adZXu4HeVUfZNPZ" ..
	"vyN5+A+RbnvnkqwEQ9zqAy7VeXPldsvk2sxnXOLT5PyJxtrDRpchp1Js5lrdDC2lPM5FMAI1fApScj0eSKTbsO0NfMeXlEq4cMk/" ..
	"3MKATlGBP7G0kf8fLl/eHeUDQTyqb3yyERih10Jegdxov+DaD6hCd73Qkl2cwtNxy2pSYfVNu3Nk5t9fdCd7y7K8j8JvAEmE8n53" ..
	"iI9f70nMqQv5FpfsFhBzrjiCFOlgwUkTleirjBZYr0FMw71nynngruGTX8mKpU6g17ZuZnsviteKm4c9UH9SUUiRuyMYd+f0Q5Gp" ..
	"U9pdh1f82grBtwlTi4ZqWxlrT5/bVZ32jH7CtqJkw0UrIumAmVOgsp23nHXsmG5/fcBFucL7hGxHq5uGhjR7fQjKyqKsLfDoovxV" ..
	"UdJbqczplKmpNK5FXQVCF1hLL9ZXVEHFcJ/5YrBHcZGFO4GI/TT9hCbeOlHgrGQOzRDvFaq6n5MC/kvTkzSugQWB6xySTqG3jMJO" ..
	"plI29v2I9aHwoutthZKAc0wfiu/kETLq8WPhvaLtZDTg8lePvr3Vf7cPb42wWDxBRc+m38WJyXOg/iZkava0EPpuxDSpuH8viDOx" ..
	"ljTSap1n2/gw6IYtUvkIi0rH/TErBcwx3GDfxJGndy0Q/fG3CIeB0xgtmXCVcuY+iydwQJjIpd8KugRAfS+3SmvDKz69QXrIH25b" ..
	"81LSPnxtNu5DUV9Lcqo8Vqx9FPJzmq/ZZHIwRR6JVbSGogfsvNpAkutWU5f9E2c1gg9QBY/xw/RLxd4e9Mtx35IqoQ+n7VTN/S2m" ..
	"c1br7c3npgT9545ierBsLV3Gmeu4+PqGUUaAaBji23KvPBhsVkajfwpQF0sS1G8JAaKfOTDb9n+Oq7j6UFFHwfX4wc9mNkeZjAFl" ..
	"lcDYsCAUDvPg1o/1RjPMP4p10Ly7QqenOBFp+X0bJV5fXnJAoDu9G+4MPnhp8pWXx4QdSPRrqKJ3hk9S4qiVLf1wa0qVnr+6EPfU" ..
	"+rGzTdw+UKh0GWN/kyE2bDlkVd+NtjFHe6+cHwaP6vMZnC6qTRnmO4Gx2H+rLf/42QnwupyYLFddNr3aYihJqB4qxF8tWtBPEIvK" ..
	"7w8YEKG1SPna+LtofXRIZOHOtzKm+o5QNHrF7SfFX7JvvBtHlX5WAjemmZDXYXhmjmAvL0OqM9DnGR2vty/lG2FlWY65+OqH1mEZ" ..
	"qD/Hr4u4u9ZMrRxR0lucQwdSJ0pDAvUYja5ViEeIsTsjAWvUGtGUi4TJ/JsArbxY7aRQ/dlr0fp9om099fI0LQNPE3BRHQ4JPmZo" ..
	"K6tEiMi6DHWweg4Blu2N218c3EorYi3V4R0/T559SUS4lyHtp1oYAfoFu1YD6A8pPmCWKc2PYa4AjzEI0/uNLayQkF9Uv2yxCb69" ..
	"Ke5kWwSGlSt2ZxRmb03ro3L/82UygRB7Ht1E9T1I7qN1hfcK/Pzh95MVFrQX7IaLRFqVAQlaTbztc6Bmtneu+skSm1c2iCvE/6l2" ..
	"QxBadqoklOJqG45IYLBs8QEGQjuIBFyB01Uq3IgtDogsq0q+YDfVAXiKI2ey+zC7L2Il0T0MSaTJ7EuNmcvqBvy8F84bafQTnFYF" ..
	"Yu7/giVMQzurmwoXyFFO29hfivZu8K2wqxDbEpa7WK5HvE/6B8Q8+QqGigkVFIXHrlAHnd+8DlZ7RIYFi0A3TySS7RNGHjuyNEcH" ..
	"0Mnx6nvWH+d7EDWdbnWacN/mOEoUiutQTEbb4x4/zbV5h7vUbVGx/bS3qcLcjRgdUcHNlldMhrWDrFJoG3lfr0nruRB3W6eXBJkX" ..
	"EGhsPJjRnaZAGNVtrEip228yt0jf8FOkaT5um3LXON2PYRCvatAN++vL4ts+uwkrxRh2VhKUVjAvoCug/HwUGepbfaMvsa7UY/fE" ..
	"e6EmltFDFQv2r8zBTS1Ssh3hkgZbJuJZbsoVignKxXAOLDETdOSt3qash+yrTGa2nVF1IusXLptGwzMG7VPXQIPU/XrR7T0VOHmE" ..
	"UvCVmE+9plAMgGlIStjW+NFngoUYN3rhvn8K6HoIKkVc0O0ShJqVfa/M8joHxJHLQZVlrVyqIyMtymg+DeUfVOLHJ7mIIjuZTOVG" ..
	"joBdglAmxz2hISL+gr1MgXqODK+niwT6ckCJL4VZEt/20Y0/Pc2IH955muwk9puaImtS8mEaWIiauaikIHy8f9suiUIoQYWiIScB" ..
	""
local PAYLOAD_P5 =
	"lGt4Pr/2mILGWBpEIf9hALzQfthzJNnS0pHNMcyJXHw0HxxL/ePvS1eIJI0cOfPSrlIEIfqySQAd6fr3BXqbYGANfaGeRoGfGMgK" ..
	"hTs3zuO8N4dsR2MA7v0wIW4O8m6S+GmY524UHYbsBH1GZtvOUz3Hrb/zzdk98BLrdgyanzfSb/rYFX0OfjmZMBx5EkWGRKYSUzwg" ..
	"U5Tm+bsXkwGezA6ygufgDtEi3a7VYlijVYvpWMeQN8Yk4p9yVMoK07oWSe97UErWF+5OV/URQbaTe3BuNTjQh6c4QA8t1y8y31/0" ..
	"dafIR12NpNZm8bYIYKHdRAPPenpn/ODVczFN4VYwyKejrcTQ4TYguc05JmJ+GsHQ5+AEzm3j+M3TzsJaldKnBhCvH0m61B8AyLTd" ..
	"A/fx+PjcxAmC316C/t5uwa0ke0k1VZCIwIxeuRCCMOvAYAAmYSamb3w2V7uqqzMFT2oMFiUXhk28uTmwNjUcZRSGUaUufIXngDzL" ..
	"I/hLTtNDUl2ubGp5BESQGPdmEzJV/fowY/Zdy7mGVy1Ba1EkN9rU+EVUnsMnCrsxPjJAZtxNmUz1Jy9sNafhQDoqcAPnMXDjCUO+" ..
	"rZFoQptAsx9p12Qk2jlkS/QLUF32laD/fF2OGuxQbOHkUP51Z4dEkXrAmta3OfTDXF49FUmeeHKw+Ym5JnDVuk77ZFGznjUrGpd2" ..
	"GGFjpMH9WOJt4c0RvBbxYBqDoIK6hWMBRPR6e7cy6mTR/SoSW8P7ujyjhGMNxZrnsqWDOw3wW/i54f1jhz7Wo57UZo/zJ5GUCH6x" ..
	"ue5QUHF9Me8ncuXPWOMuLfUfjI6KxqSEihrcDWzn3cEB/t+wkErL0SBJj0GZF1pHhZoAqLA2/xIk6Cpap480FGd/EdlXMBtu1ag6" ..
	"Xj+HKtLvAJ4juupZr2vPjC4xuBWUoufgafwaH8m0M3Et76zg8npvlQFiOVeaajSnCEHgD8gpGIHDIIcD6f7TGs+WjDRpL1UVH2kd" ..
	"arTejLbITzKNZYv2faRZbBl8q2wPyCb+UvQOd+jJ1VFaOeMr2nSmSqej2+sALDjiHlqMdoKtFdXe7wNynIUB90zQZx/P3dJQu/JY" ..
	"P5uYNGWT82fZNew2zkPvDBzq7R7YqnQ2tx8ryaxqBmkrsd8uBAoPXtl8TuLuNdF0QQcPCOGGj6AimUA8Etr3g7c224IsR7HCXJwH" ..
	"qmHzXHgDOFMBrk3YYApy6UEDjwWiNpoS69ek8JGnkU73DxdhHVaclvnhSbJyasVQR/LZ2X89s2stazMlygsAR5G15lLddeRWgqmU" ..
	"fj0sGVfziZX4NLI9l4N/9sEYHYsSr/FefXvCVTc2Nq7qtsHg1b7dtx7Aw2+j05/x78JB0/a9slDzsHa7eedyQbvL0k16nFYYS5eT" ..
	"lgyKQdM+D7SOmxmvUEnptzxBVQHtLuuBHSP6Xl7mJ1uNYFRvvVl1xj20vamKZIQyX3XgK/sWUO6z/jOmm/QDxsFI0BcvcDipa7f5" ..
	"gF/ofgHXMdRD025xQETNDLISDWv/HrhLyTaT78Bkg/BjOTwEaDF3j6deUJslqDcHJk/I5FNgRFnkmSIz6he5vQGRiRnCRHymyn1G" ..
	"9UfHOYBbztAx6QJMLiC5BT5cfIBNDfuHhwa4/c3OjTzij2oA9jypZrkJEfUtr0gXXpgubH/gmE9+7f1AIG01gR/UqO/7H0LM2vp3" ..
	"5yG4GNfHfQMIMgD1/oi2rAT2R/00NcB5giAl120k9s+foPJuwTsGQANsuqlnho+YdpiEToBhoM8XLrbkkOBeT1B7aaJ7VIbwB/lU" ..
	"UzQtHfpawKPU/qB8KsqgP5qnbosJXzYv5PRu/xcB0AGhbnubG319GOlo0h7mw+omZI0mi0DcIQGRGVz2AUa3rP25T86Alw1cGpAs" ..
	"cL+J+55jKY8gt3kWRVQh/DAXxX40YSuNs9IRMXW+g5r8LW2TtbVIrf/ih9jslID1FRrp+0fVds9e/tbbXokWnoEKvDYH1toC5q0a" ..
	"ESJPeboarpxSo7pWngJWkeNBp9VwE2swM+N+/JNUD4PYZ0nytWng/7a16hrf9EAc+LmEn8+qHuYIlEoTJcILZIaay0h4Taqos574" ..
	"mo+On1RT4XzPKqXIcWgQXFSxfyEpP7fu3aBBwYoBwX+Ipz2rqMSVvd+pAmU5Q74ggPfyRiFcziIaUNNY/EVtUAfccNjxcmT3YDo3" ..
	"muSlFN/ZUYBU7IztKqVSAUXfdZhNH3jWvwZi/tZoqXJVH9MwbpPT4ywwBmAfNIbj5cb0BXJM16Ez9U1lnnESg96Kzih0tTeFABdm" ..
	"3XpJkyDnR9N8ncAldu77RRwxK8L6JE2IAYXwfpPDsuIMMmQkUO1pkAx5xFUtAsXenOaul2Ou3AdADoeenMDXq9z/8gUQgPj3CZE3" ..
	"6NXbmff+1F01qNu3XFYI+GpJmN1NFTqwiV6eZDe12aMDR9DydkimKeZqHfadP6AbLBEWE0Zm9ETwAyMVmHYAz3/KSRNoNOGlRGSn" ..
	"96VqGw6yKXE/CrlsU9OZXX5Ie7JvTqPejH/+lY/mGvXDY87LGbEGGqhZrp2oPS2g7bmLz2pVnD4/cP7hXRkdmbQfsrUV4lgruXbh" ..
	"qFkNMQNvq4w22VUV7gWX8jngQXljfothpFQ3YPJjL+B5in+vR51VNSEv59eyBIlQtTFY2Qs8MSirwTTXfILV9w9W6NFyHD5NYh61" ..
	"5MjG3KZ92/bNnkmeRWUOU2HVcbL3ZEcHGaHe+bMQTcwTfgZR8/nz/AYA/vvTYM/ETX2s0Kul98LztOQeJFlFecZ6Va6Kfp1q4fNI" ..
	"5fTImCYaW2XVNDyl0jMq4KqDgDZ0rBLcvfAmyZsXYB636cbtzhfFY00mopR13kVvWecsYMdvPJkRnXeAO2XprG+H3XrYTvrIOe2q" ..
	"HDoIzitpa7cq6ZHdcwQdNS72/i1MU9EP6bOPwnBGZsHeY+AIrKBxPsHzpQDD14xRDPpigsPihgPtb926J6bAd7udo6TRizRXtWVf" ..
	"CUNktPzawJJ4gVhRLZiTaxpj8VqNIbyMrgStV/yVJouaJcDrHtXGARmCeziSAtXPki03BwKOytZ7XZCgefzNKAxYhjCjvvrKN9QA" ..
	"syd3AG1ySLzD3pQ5YKzzsbeuDsUVd/620iS5h/tv5zwYazLsbSaWcVFT3g/LAyZcXecPnqS98S70X57OlhJdnPiOps2a7qwOjV9f" ..
	"COQ6xaS0409PtVN6jnv4rsGK+KDzOyo4zv8Pes6K97E4WlWPg38nEIGhQNKqQhUDaiA3j43jcvqPj7iBKGZ6MQbZZKAF61O+w6dG" ..
	"at23JEE/Vkdhmgtg5gPbDYFiWMs5ZYqzsaxi710dPuOxdZC6gk3y1ahdXOgzeVWaiM74gJ97eLFvapkRv5Sv2e8YNLgipdlnLZEw" ..
	"9DOQy+2DJI8JrCK1o+oJfbXlAvPsv9rOurL9YzPDIRBjeuOKUYDZHkj64WUDWITuK7QsmBDIUV0OX8pNW179S7ssA1zCMU8Uokjl" ..
	"QRmoWbxhcG2LPNOwiNXl3wuulM2JUr6oKNktcPCc4kx6dEw6OaulC0xSYsgPm5LPYg3E0iorZL4YFXTYaBbp4K75qHEerhZ/mpM6" ..
	"N0kEI5y8/bCIDhZQire4IMXSIGGJOvJjlNbA1NpS1a8PFe36+faP/mK1g/uL01uitCmg2xcCiF7VdaQcNKP0QNnx4Fv9KLxJ1L5E" ..
	"1oPWX1B8gUooQsvRj0PipYRMvbmKudS+SkKrjhE8IYpc7ncgY+Isxc2gny21l5i23DWrizlnxX46x/24OZ/PF5UyADYbJPDO7IX5" ..
	"kIxqsTEJhcizfrEnCeLO7MQV/2vkB5uaHDkyjxf0KccsNIKHpgK7mirGmYE70PnBRhdHeovv+GoXmiKYETMmMylO2rEZljdJeaKv" ..
	"8h1+HXeD5a5RVkejH8JHVPn44VT0k9o8DdpJMFeNXywfj/RaqBf85m1EKBwRVu7bc2kYcUzl+viRP4iULAi8yjhM2FRXLshUsMqc" ..
	"jlXk3CRUZlSBeBLKs3EYMJGPhdyvXMg33oDk4XarFoLouXSissANQ4yk/A8gcxASBuc+OblX5nJjv25f1KB7mFsbJvOzMfMwhJ2Z" ..
	"Hmgj5L5xKWUQqPPayKU6aD5IsiAKDe2d+1+7UufgiqQ9/eXfjvlzmY5dH0W9+9mtP+S0maLOpp1GoN0jvOH49dBLMB8TbOGnmtRk" ..
	"jHeOnPJ0LHEQ/BjB4zrkAh/HmBSVBzf3AwsMuu2YsSQFHvjoqXsZSTrlanyjWIuFDKNb9OiBwmbF35YzhxUwasrHZjR4nvkOBLpf" ..
	"YreGr5EshYF0tcVr4FN39hhFLLxMj4BqzGz265wgEcrC3yw8WH2w33oBJjO+iWneumBpqrcRMM8qUboaNER7lLsQZv67VAo1WMDU" ..
	"QncptQ0ea9JfMW9RM172+UkZxhzeOmtT5FfQDEkkcikWbudMP1Ic2UR4h2Nnu+Se6Se4DGM7N8wViW20PRKEH8m5zXmgszrffbTP" ..
	"0Ows5HHt6Pp+aEZslunxsDeddKTOqNL6FEbkiktW365IwmmIyutRcmS9OvqOyCEA18fvHL4BfMx3NTCfnRzasR80gIMaf2BlX0eT" ..
	"TbEmJ6Dv74UKzgGFht0F/50gUQCtJ08LA8makuS1u1HQy8P7w46qro0sVYNYU/l2Vfi1lZ5lwvxIyYpYP4ffBzpjEH07i70xZ4UJ" ..
	"7UbfExdRv9FrRp5QGq3Lcm1Y+iIY9gKg5exqODOWB4CLZ/4n/TyEhTdZmVGKEiwNBzVV50H+YB/ncgi3Q/EABGcEm7jyUM9DC+qx" ..
	"n3G32g+qZdsl3NFl3lD5ivkcqxHnW/AcUZwGkyQheDUOsbKFzvKfoXocO3sLpN5E82IcwGTa6hEsWUKVY+ta8n8cJwJiPqBFcjSO" ..
	"QQSTyXrYKRdwBTWJvtZJefZsbwIrUJmAqs9rAtVN5j4aD7ic7SwpHTZ62jwgjC72ryyAbCYvaHosfojPdl5FhGM5VCpM2Ld3FgVL" ..
	"cA2W7vrHSjV47CwLP3mfbaTuY7ZQHKdh5gxb3bkMT6li07zjfsEymtQhUMGYriMslccPivN6p1VAkOfW1ehBXL8vdKUZg59IOXI/" ..
	"RJx6g/aWacfgL8nHvFGQDdvQRqvr4gKccU8egiIjdo/SZLJL20EJ2mYz3dOMXRVeJ3qUlvdoiFbgukuPs8FQQrpQun0ZTtZPMpr4" ..
	"E16enTT50dyTpg9NrtTFfUj2bd7JAbJgEO9VpozSXTB0SAF3B06fTR5QxeaRkkL9GzsKbbXwOb7ojkqMn/mQB34/UvUT/OBzx9zE" ..
	"WP9Dv30hbNSh3XbuZSmFtpQdGUQLCJUkGP2bKn96JFjwuDXOSumMi9C9HyqJyjcWAtdfMYzgvRoi9tcQ90c3jz2Al5cD3Svtbau3" ..
	"F68WfGDrWTVstsX+VPBXR5+oobcR/Pbwk1wBouNDNdDCmv3cDxssyZ1T8ONDx9hRUxjSb0h+0sFXdHqKLmnYovfjxQ63XQc+0S9M" ..
	"YH40Ee0Q2rpHA11xoAnawQrKqZgPQY08n3aLcvS643cDmqXUp+jG7Uqi6p8LLFFaoqRSYlyOHTRJLgOnqVeatzqMikPte/rczHlk" ..
	"pekAAstk77SnToU5HCBea+7GLG3SBWg/Oi4jqGADbUZ54CsXHt6UgdOQ0lJNJEnihJbbuSkurrWR+/Jji/IMSkcVNybm82CpHES9" ..
	"vL6YyV3Dv4MjfNbkCi6U/x5zrdYQf1Tj7bhVFeJjKvtXehMCHcToahfdAkB3uBICs0kgrKpxcg8Zn2CxIB3lIkLilReoT3EQXobW" ..
	"1uJ97mxuDbaa9pxxGRs5Obd8W8lGbg+7jPkTFRVINHjm3z0Qt3K+dq/htF8XstoUMCbCQ7m1FXE4+aYz/OH658zQhnRIZaL3MCA7" ..
	"MlfmOj2E+tgQf2GNzqvJofa4xy7fc4vatxnJN9hJs4JKFOuQi2DSlQSVjKWIcbM65RFZiPGPHVp5gwURMhsH2x4EbrDw/ppUD7Pl" ..
	""
local PAYLOAD_P6 =
	"P4hCSdR4j0bZzxK8uh4veNggvbK+UojAyPyQYWbAZQDnRLiTiQHPuX044Xm2UkJTfZ7AKMbpZnDguhTSxRPboWWoM6k10KsDXq2U" ..
	"QqW+5ftExMW56OjimHZZVxK8tdBV7xUj2t4vBiZ3h9psB3Css2++P8wHSZKr1nScirGWzJtyEVN5XiL35wibNjTsc+8emd0IIJLz" ..
	"p85vX1WZnZxrqFS3uGavFxN2fXgSbgbkSt6nnJ1iWrTXfnlqivGciVUYBbjpzdXAQ/In3E0wEUcG7Kj1abBfg6i1nBb2upKfbG73" ..
	"vcmeET8jJ9suJo9z+L5lpxPytIMbU/swreTIbwRm/qDb7wGT/e/Hd2LzR1TogAvhN2VFaZjCgMHeb6pEpQ/2Hh2wAn5SFkISf4m0" ..
	"DpGgP6zQczJHyQF2EMapsoG77K3TxelYaxYn8sena6Bkbr4mSOB8aRZ2Qda0qH4Nvnr+G2hStCbIrI8OOqIzx8q1LG74VSx3VXiF" ..
	"OK+Tft5hX/nXaVxlQPi3vnXHRX1HXf3R2OUYt83c5NTiOr5NdPiG+N2f84rJM4EcbJxqg7WR8VRK4HLcnACi5l4vNRa/yiM+4lLU" ..
	"h6J8KO5ELZ16qkxArAlWKbGZCZ+l21YaCiwV0WcYashOdfHwgj0bczgPLLJraCtn++Hqlohkj9eV+RbkHJvoaSLNF7nL6sqaUnLx" ..
	"CJiqnRApOcTKO97dV24fVcRAecL8xZXy/YU5PYz6q/6fEIMDhNDqmmn9l2DShaTCAM8jSJaMFER/aVTaa2H1GFqOfsQ3qAVwsjDP" ..
	"j+E0MO5xsSzwXXUo8bsbmeuXmKl0/DOKtRQcWyL3AdOBdmcWtZs2PU/mtAM1Pg9JG2SK3p42mRjOcAzIZmCSh86vgsx5z4rdZ7AC" ..
	"YjUCOh7nC/YUqj/ARyj6kn3CAhnokh9ShsnKVydHWjQQByqDjPE7+XtJTbtXY4rMYaSaf4heQxvFaIzvhUuX7Od02MrrAcTfnrnc" ..
	"RRQO3LzVNVkHVIe2iHU1k4xXrrYldChq8M1jBEv44uOUqMJRbaoGx37ccCP2aOuvu2ESJZ2UTp5QBLFd7vTOkAwgz5Vl4SrzkcLK" ..
	"IWU/BkNodOqE0ZGpKX6uCSM67FM5vcAOcFC43zpPsU1MvXh3ZFbHv9Sdq+99HTmex0OxOPhFNLi/RMgdbIGKWvOd0ukY5So/XErv" ..
	"ezYEn2kw7JkBCuRGoE3tfI8G2BSHdkEIssrZXfvi2Q3jSJ7CN+fPjAE76ddnOt4qcFn4Blu0v0gJOfRwFGHv3+eVUwETxp5kr/au" ..
	"oK6zKhzKm9dZhBfsVW8LmBwIOxhzUR0RSkjJSDZJlxsD3Q21CumIVap/zd6zJE8iZQVBK7fqCB5lb9zL0QwRx7o1eTpKT1YiFuko" ..
	"AS1kEQmdxH3ezKqyDfvxi72/W6T4e69IZ7IrSHECazmMOpRM9Nd3cZYQecvZzHULJOHbRm8FpKmoKsSQw0z+hP0rUikyBr50vJnO" ..
	"oPjrb+CyOaunMSulEmweVLNdOegdPS6kV5flLg6O59NTJGrnQTvICLIxfBRG61+ny/BWF6xkH0uwJI/7MTblL1D3TXw3mFHUE6Qj" ..
	"AjdlagE0lOrmjjzxSuT2OpgYbIyduW09AIhbN/ISk2dIzC/oT4RnSlzY3amr970OcwfV+2jziJecfGlcY7/U0Zof1TAk/jteMRgd" ..
	"varDAmOPmzKNxBMaec7xcshz7gadBuJclZrles1OuZ4Wjou1BYTMmcXmwgfGdXpi7KODRzYuZFEwlsGkENl0cp/wuapDTwey/Rsk" ..
	"tkS0hor9mmERRKYw0ZxPPOT2K2GudIBNZPxhAvo0xdg19vZfd79eqHuE11A9dqcWW/kghq/R+e7ObifiavCU5QmGkQmJCVmBUIUq" ..
	"neJ/mRBpaG3HHNnTeiEeE81qQJriJwBwXECD2d2izXRAdFw2PLcalLTBSf/RObETBu9JYniEyHAkubnR7f8DVgz5ojwdhuFN8wus" ..
	"ErNED0/4/GHFrJ1iH1xPVs5iCUeOkNuGvHazGDVkeWZTNMXOTRxkhGsR5qHEqCLdmhHOfZ9JQwp4SCsKJAAEVe6pmkmpgmdRHIeT" ..
	"W+oGvRpXwVGf3Sj3IqXZRl77rT6qG47DDWfDsbLuSmJ/uJ46JBYtmJZKeupi83GyL3vCKxGCkrlfqZOXCMxEwqJNbxx31nSq0URd" ..
	"ZJDDIxB2lM18ijLeK4g6henUXJvUXGcfYmCy7dUkbJh4ER3ABX3HNlih/kjtmRQJjOy9xbTnezqkLPUr73t4wMIN6j1EDwc3591w" ..
	"OXFBzRSG089trKtXgU9d5smjYc7vj1roYakUq53U6fi+pzTDo+YEMFSU+y4trx5VZMlMZKHKblv1Kghxr4U+pKdd8y6p5YwV3Vyu" ..
	"EG6ACy5Ir8kDK80Den/Z1es+PTBQltMi9VLK4ti//oUDKhjaEUFsWUWdAMMc0ZJ4+bfH0D66ipbwXDfWZLpJuyuq8S/mN10lLjQo" ..
	"ewn4N2Nn+L00Aa7QNeui6UfQhREK1H4IgJ15GvIRtQQD3zFpdH6ZBwnikpJRffrg61hlSjeBMUv+Ci9FKJ2zd86kp+XB3GmbHPTX" ..
	"UvEDbD6WqYO/EqzcZpVkTAH+MxX5fA4nK6F9xCqBYiDeUwJGwQMMP9E9JADK5pm+PLOTypWnUx1opGRlNzeH2RnTyogJE/OdWMtl" ..
	"70UhQFIlkqIvJTYCpALi/Bm860uBVIM5t890ARktWS7ZyJwCDtkuLCP1WyEOB/CWySOZBXbiq9qatBGEojO0CzNFtxhbFWnKH05t" ..
	"11qCOcO1G1FxGP/tCZaZm21boZVdzZvauecZu4BO5ftlz423pq0SdFkGZh2CIMPXzppNo9pC+U765K0NWWqeu4iNeusW/PDlIt5b" ..
	"CB8Y93xxeHu7Y/bQmszn9dOOgKb9OOH+LPyHVC4I24+S6bRhMPJpLehG1SWpSsE6oYPImCBq0k0XGFdx6slTS0W3n0hdHJLFg9Ds" ..
	"ucyBcoDe6fUEMx6+27xsigDnuIprvWiJEotgsrJBCSBr9R9Cs865xcmJ6R19mZLCH7m+HO875ycxc1tCzDpnrU7pjV4fIxyJlkns" ..
	"o7dodvhU66K0TybtenEUQWAN09QJS/oS+jWh6/WUQ1tmnCGt8NltVgtgogfs/Tqp8hPQy1AnuxHioK88Wzij1+e5roJEauI0ro+z" ..
	"28pB8cI7QTEAJWtJ8BRxp3LbEPCJxrc3dW1L0036XgNmdfQZK4Pu9ES9l8xCbJY45VxP555nNkXGitSYbu/2pd+UpZgPKlhE5wbr" ..
	"ENOHBPjHrPPYJoGeuUupt+g14yrkVFtP8lqF36lNAOj2mb83ZE7BUM9YaR67Kr24Y/kN/cf6szA7wlSgvpUMEDI/zeMv6J/wazej" ..
	"lmqaCbvtwpGJ6C5hsrF4V5WuFpz+ZOSJWVVaXlpf1CdXrTxWsoBcIlXlhL7PrNebESCVAccFWWPjiUYFdPYm4MGRaNodY4/lvYjB" ..
	"anN4uHdZM7K8oQyEdmBQ6zgxzJc8qqlF0m6Tqe2d4QLRVYBkgN73zxD3SX+B2SIiumgs966RDA6aS+ZNlkrllW2sxNa8mVPuV8sF" ..
	"1CrEWYJffwSlomvC1pWSa4JXmAb2SxtQf+cefBHBC136togeZAvV2zr+0ezSJkwoOcvJoSI4NpS3MlZuXzbs73aB/H+jdyBLHd/m" ..
	"aaDlaqbB2CST5CwDAxwsnifl2bCwaJKnTZgR1LKjOdsTGOZcDyDyxY3owUvgezXQmVzGQX2mubinf+5pu0LfAwvbtCYS/D0+FoyS" ..
	"4ZxD/eI5436K+Pc/+P5FDq5F0c0ZJSzqKdYIlu9Qozl3hHiKxRlqzwWLDipFllcaM/AfW+kNCiig2YKztRrvwcjqd59+XNzrgAQ8" ..
	"HWntHo2bNMU7FQZMgUXwS6Z6tTTWOIya+lxO5vaftayh7tRIhxr6Vyv69FNDVfCxxTPinNhNTAk3AEdGMCl/B0P0EMkJk/P2u+Lw" ..
	"vVsGLow6gBso0DkbDwQC4HKWl+5+rfxqUf1UKoX3UUp36SviIaEiePyPZTYgeyXBnPF2Ev4spygFQV8Y0vnygHm/wpaysyOBqa2O" ..
	"dWwbr4vBdL7dPICgkb9x3sHtB8TtHqvE0h/WEX6GwzEbkDvDoBMNGU1gchzQlvLTdtAw4C/9Qvm7vEo3O1HPCZB0OCeh9y0qC0EE" ..
	"Ek9ijWdQpkFpkqdYvC0Af2qlK4p15lAfCN5M8U4s3waA3Z6CISW93ZjZ+2FjFmxSpqVzuizqTMgV2UWoLhydOgQR4MPJgpWQiSMu" ..
	"6fka0L+kswtbG2z7OLHcHCrNSq/IfG52rCJGhUJgFEkGkhlJXlw1nY823uJjEax6jNIgE9dzSsG679fRqCWKq6jtSHcB2BOZPit8" ..
	"3nhQuyodeQH8YIGFKJiqJ/sRSpdeNO8JjYWVJS18ttaQRLKrc+DKJMzBvlY48IDSHpyPTsZIf399iRCnpGqUM2gzScsmVp5TeDy6" ..
	"7eEBKqKR0nyn1JjqNfUhKJMxkghnRJzC4+6/uLcKD2ZfsI2rMZp5O+70dRhCLqZOl5FNcTMUsCOZe/XlOGgijKjuqO9tmaT8XDok" ..
	"D7Z9NJz/JQaTExEjINkdtKoX1ddWSa3byDBoeNfcSxyyOYxyg4C5uJQ3z+TJDNFhwi2iQE7lLKYC4ZO8qNz/84KvWWgwBdizP+I+" ..
	"eF15isGo5QPq9j819sV24DvSTlFVUHXVucTmq0zHEEgFmIFBkFIcDjxWFFuvA4x9fXXO3hO0PoXlYxou5DcuxBIXFvZSMwryzUc/" ..
	"MRGQvv0Q9zsu7VwVUPze2u+pESo9UoGkapb+cPTDtQVoOiTF1I6zLAi13vDO5Vhh2KsNjYQV9Ip6Arq+V8GHKGUqI9JJgyenYCht" ..
	"S4mhYYeQ1GvsTTPoCwLg2eCzHmry1rVgcCCdxCA1BgAPBnBIhB4P1gj0QGzccWWMpqrecjb2UkbdHn94ip/F9c3hzBZjw27chLge" ..
	"ZShPXgwpk1RYBKdjtaZi3TwARaQOd6aH9KANPk7ES+awEZA2o8ApD4QS2IfIDJ19AtQzP9ZhWZbj/egTSEVr8WoyZP7XMFTYVeAh" ..
	"Wu2OvewzTnGuqHwzjM9e6kmnNACS83yLHak7Q6wfKxyAKiS3/ZUrA5ZHbC42Woi9jM3gyQ9NhAe8XzqoKjZ6zUKhcFmzlOTowNJH" ..
	"P27BBWQ21rsjvzhi38WsuHl5LluKrYYJYqFzQeSuRF7RaDdq2SiwfQG2L1UOx7tSLKklDcBA3PJIkDuez9VnvzdjEycMDlzUcmWx" ..
	"cWkP5Kfg+6gaXcGxiyTsVJ1NqeJCDhXs/Q1h5fSovqobqpwfSXxfEbf5+IZfI9f3I5YV6/4Q1hQ88Be9jSZamYQyfiP4lrRCINb3" ..
	"9SyBh8NAV5oo0XE/5YIEuoI3Cq92RzOgYVZUtRrpYQcuOiLedAT6io445+50hgCQ0ZEvQnsO66oCu1JKk8jCzdV16gsFWn/sktak" ..
	"6u76IYC06NNo1fPjhYKLq/Pf8VxYBezW+IJJQ+yvTgg60ZLrZP5Ev2NNkuFudBNHq36w6MQmDXotAGdIupaP9OCljOUJ4dcoMz1U" ..
	"EbvIdvlTjO+Dh9QSZKgyUdUJWDTU1Rain1hYh7vAmu+nnaWlfB+9O0daDbASHSvOqpisjwDFCKkP0A08Y0xGUr5G0foa1e+7S+Nv" ..
	"c1s9ot3i2LVpB3OPmiEPzqr5zagB3lU/L/LgQG7ntshJPU1U0KMAGB5Wcu9YYYJY/MnprN4qfbTGcV5/t3ZTAWxlo6XFkB8Nrae3" ..
	"jn+svOy8W/4KmxH5WY77T8OcIQXalvSGEGRCf/FzHCtS+wWxyQeDPfI7sAkjViM0Tzl7tDMzUOhJHz1JLhGB667mqjpgJHNmKTIs" ..
	"9wFw2Ut1I3WciK5a7Klryiisfm5Y3UhsA1W9gxlaM4HRrJXhk5HlNHBIm26KFvf8JaHe38EdJM92lDjtCf999CRo+TpJfptSLt0k" ..
	""
local PAYLOAD_P7 =
	"+8c3CaLTyf1Yw+K2IWqyDLHyUsWEhgCYq3E6f6x/tztAIXyVNZ+2TCSaRuynk3yiZxxpn0/5Xc/KJdYs1M8Jup8Fv6BLV4nMX0Qq" ..
	"d7Tv/7GGKdfByBt0vHVxq/qlqwUDFhq/I7R3AhFemPLn/6ZnpRnnkTYn/7p7Hs1IunrYG4rvlxefj+XjvbSjo2pPWvbqrsK/4+HI" ..
	"b4TdVBYgQBCIjyiowxKycHF2r7NBYYyOBbAb3DlCeVfdmvxExjbvnT2Do/z3eTUuZ8tuz1CDb16P/YStx6miVsKS1P05BGHT4S7t" ..
	"8z+IPb+8lnfAUECAesqim4Nv5DZVOVMfvBk+zFqt3D4bstrkCuMsbbPgo0pTDhXTcGMpflLFwL1cYkgYjiYMtnBZjg8CD8dGXOtj" ..
	"gz3Q46uSHK77suBT/QcMmJMw90W5FgZFxkZTwTIMKMapbKGZYl2s5ddZW1xXiCLhTLhwZnXGeZOw3ArvO5qQvaGgfNOe0RTz4TsT" ..
	"cagWGZ6XhFMM8eTbTvHx8jB4PeAFyttwlIUzh56nCCs0VRJFbvFu5DRc7lWy6ZIpuK1EwOVDnzvtIJ4UrZYmwQgY/dGBggv4W0Te" ..
	"KQpx6L+VzNcVslnL/LbuM5Mo9SuEy5Akt+aoLifgW+MQcK8qrAKMYs3QoGRQR8qrCLVR1KlZWJYPHe7Jv4FnVKktQ3liiG+AMcqL" ..
	"ch0jefSq63U0JSmgR5k5H6dYfkSHOOKWBL/Frq3nMY5InYzXiq4V/Oe1ZpuRy0+Un8ZKatgyxfFZWAgHHOSIjBAnQ8I7+UhIuNAg" ..
	"aBUWmVVzunN/AgCP0nKSYl+/QQO2+IJSy/ToHODCqYyKjdnYCYu0cInSYFcj7olue0ZWwKw2XSt2QbRfsybbkUWMEKIIp96CAgsw" ..
	"xEMCXozcmOhGNQuQ5ZXrFeJa1kn3HzufMs4LRUWlgnrSAyNe6lOpXrc9MclguR9MuS8fC7GLT+cXwLj779GhtDKHnlIkDzsp8BHI" ..
	"ly1qns87VUz1stWWe7QYKKIgNtfA/ZElZm1t0vuv/WKOzLli0Lq5+zYv1weKc7IRorqMREGEdVwRl/+4l7zMullDVlmZWT6ipRNZ" ..
	"1VVnSk3lPAiZKBY1rsKUt6vf7YgD1bqRGMhNr630kivYf4Up/ApJ024s7nbjDyutJqeIn9py1oWbI+BN0uZcmd+Q9adhdAO7z4S7" ..
	"wrwsvS5Dk0FZ5AaYFN8lC6JWdgEooYQwfgyUqxw3+UcB4S75W8YN2NwRgfAx7ffar+aSmnhw3JxiBszjDVi8KCs2539QGHzbLlW8" ..
	"OArmAXY4EHKo0BwndqSLO3/UgtJ838FDnB55MCeZEjAkZc643KSWsp1A3t45+QkF1Bupu/f7i0VkZygeEi8BneVkcI+0mc6gd49v" ..
	"OCuhL1t6cOm+bgkQHwq9SKo12pGSs4CF97KQmEivmUah+nt54WSVBFLkxENDbQCOd+yFytWFW3AcWDJP1edKLcKRDIzkM0NHua8s" ..
	"mLQicYuceOKujoi4DE/Tgkwrpguu1AfvyxcOa6/RzZz+8r9iejvRJ65/MqmtLKYLPrG1v4NWfNd/RJzHv8+jnupLyb69G2LIO7sN" ..
	"nyvGtFyuPlXUlUJ+oqFYng83m1stizVz6KPfe44CwUHQ2exflwMcekzZJomYEh1athW1wOI5M18lOZbCexMJXP69ynLuCT3VA26i" ..
	"XXjRKkE2PkrneSKDX3BNoNeQaHBnQIP6sKjCPB9WkDxumbl9djqAyjHmAKyLX5LGN7Yu5L0iVqYhRiTT4AZdTPamNp8q0gT58dbO" ..
	"zyrwmh6TyWE2LFnlnhF4qo4msqSP+ZwA0SwP2EXZW0QbMvw+Qtrz8ftXGm53l8GlgfdTDopI0Te5CdHF3iBMv9uGNFNVOuRqoq7K" ..
	"0v9/0U9wAhxR/SLfCEgMXj73EVOihFZF8aYbJZoR4f1eZlyybV0sRp+FDiCDBfWoxCzlyXNarb2bv/qMyQjNtUg1Pu54WVoj3xQi" ..
	"MJYJ/tncrj6p4fC8s3+BM/ZaeCePkQ1PxFv29ru53Kz4lbB2eFCgAzyyL1mA6Gn5hOvsCwaP4dHxMXOtYM2e7pcNcjZk8OBz2Xpl" ..
	"vHArdGSmdyffNLyFnWjB2yGqFsj3BR3V7I3yiwB4MDRedWjitMpLN7jrv43MBCpEKzyL5UMPOcj5hgSgwAZIZKWvHW+DDdhewTx2" ..
	"ZLynQUX5DJnzWi/Str8fWW3BPyrwNfnmhYcuZ4ZlCshqUPx47+amIm3VSmcJtpSIfeNXdfHyMVV0k3b2ymFYP9K4UmMFPAaAzQax" ..
	"gxmenwYTEjDxrO/vHK/nmo6mIciErORlLpFCZrmgsQQK4NV4NiUEapTp155A11tpeDvtKZHFfrwcExd6g4/Me1qdPZ2S8IDHKyA3" ..
	"4vZjLSSMwb9QAHr/GQi5sxCzOeAfzd8esW6iTDrmMU+/Vv8FJZP0l5Foy6N7dT5Q+EHbV+2uRfb4iz8n0qLl6rFh9cYNLFdn4kx4" ..
	"Mw/lY6NxnkY80TT7CMGo4kW8dLAyLJfguapKcn9a7OPjlVaoQMSSmdTT1XC0GSJmfR2hlO0SPlzAXn5V6oiQXHz7PCZlFj3kNLjK" ..
	"PZkcNgtvZQxxNg1hbpmrfUvj1DiFW5pJ99fBXMjJO98qEf1H0zx0jxVdMELYKwLT3c+M+YOr2Y6aIXztJ4srgUCKjaeEnBPGLRTn" ..
	"qgDSL1iXCLrMsSGx+Gl06Hpox2Cb1Cf+2/PZ+usYVusdhnnk+uOU1W5cuCbsAnc+d/LRtjz3KoI8yPGxRfRfl/QHRAXF2srmat5B" ..
	"KF8wMgwRCtxGU1rxB4f0xqnqr5zFTPKlK/aH458RLbcnlKDsDCp3TwIrEbiHAkIGu2J+smQdAMX6iT5KER2/u5XA+3IDjyTSE454" ..
	"v/xxydCIj+E2Xa2LPuX+J3GBoZxkkJZ2gaFD8cgFyhqfsLxS9JKGOGeOhydPm5213k0cUwOmeaL4sqfWGaUDqXvTcTbYEGDF+9Se" ..
	"EiwcimJFbD/CZ+q3J07aVpyKxw5jC5KF0lEQhQdwjV5I7E0rtNrzg1JThtbWAR/bUpHK9X2RfPikXBPQ+p3ay7ShfSjBD2jx7f1o" ..
	"15F8q+WTa/ptw3p6hrYel9LC59k6jvNK1aqgYdSnEAFYtCdnZCoB2Erwf4lO2eCJDGxatSbaubtJpCaIplhs9NJeiFF4RaqVa6Lg" ..
	"9xZQT1Jw5ydsXTDMdKRcuvPAymoWSKEDSY0dYgpHaqL3FFzdKub5BIQ6pu+9Y+yLXlGhCGl9N44jspYg06Xj6ufatEAJIjfdiZ8A" ..
	"V11WZGzcuQE4eE3jykjtd81Quw8c11t/MbfylfriWGUO6siC+ZZiBhqQs9fgEXp/q59dVWAGeGWv7JqWqQgxxzrBCuFKp7oq1IfM" ..
	"JNcJSt8KEFdVYyUecFjnQEQMKj64m8rrvEVefPYjbJylKnic8osccRj/8C2iNuj47irg8Bz81yQBfUihR05CZ6WINXZcPFwJrUl6" ..
	"v1qDyAGJ9QLD6eD1q7RD+L2zeyTJB3LhH1ogRCAJ1QYvZ/sL/22xRpce3l1n86l+XsEhOACKlXU8lIxIw5FLbzb27YUlQgIXVtw7" ..
	"hXfseNjJXh91r9dKrBZIU4QSvsm7CKEG2sKTkTTDapmEAPBH5KQFKLocTErqKM+2hT1hdXnlqfBoe018lec95QAGDUMCdhglAT63" ..
	"JY2I9tH4B1qy2O2uaqVmSLLUpieoIyF5mSPjVO2t4dkXWGPmSyIn1oyQZfrlFX70A9oRghoz7pEazM/MbwBJeFdAKzA7YioxO18C" ..
	"z5XxhjCYsPLxH5Lvy/SkDXU4Xpt57iQ3MIpfLpOsf2cathnt+Krp+dyF98IpqzT15WPs6qI1zCFnOWbVvMqQ4SXeScwv61lZxsN2" ..
	"ZHpvMpzE+5jhYdBrBMlNRqz+Q1D+P1mYU37nSogLXhi+GO7eTS4XtJ24+II5FFPdoQTDcevkLHNikaIbOqQCb2nfUb1vMigUkGiu" ..
	"06elZ4Fml6rbSXGyte3xBzHACw5ojoEMJFNdtq7ojJ82fCI/aRnsalxl7XPlsjrVFjyVpFkEeRgltgK4+6KAhzjbbL895SorM9mc" ..
	"QuMA6ioL4bPo3LED5iUFDTZ3IWHBnyPbBrnC+V14CfYXtzowfGjY6PsiGgpiSPNU6hEm0P7zh+uRoaMGK6SLDM/w9uQ4YpjWsolk" ..
	"HjJTAk6jMiSW+q0wG2xb5fR4SFxCAEc5Ki3D3cqT9ZcGjBXbhAfAAvKr9rsFpZx7XKzV/Fl24nyNS/+aGdV9y1DfwRrzbgH+zwh4" ..
	"rijT3OzvyBZxmxwotsvkXqmCDhHPQ8WC/FmMTZnJqxN2s22JrUbVEFBgwUwSIyMFz5fikpkx01iwD1M10q5gxTqVJtyMT9Zo3Wcn" ..
	"XvIdsErzaUcBfVjm1keTDsIBGlJDmIV9ISzoK3w9B+8fSzl/Jbn/VKjXVrAIVDCOBzl48o0mTOybtY4r+alTobf10yAKU4Q1cMsX" ..
	"aqNBXCgkMC5CR33YfrxjO6dC0rHwzhoZP2sSLs3YuuAgMbHBO/d2Jz8rbRWhJTXeBFP0X7Psgrpk2+VSTOxMXhmekPD2JY4z55UA" ..
	"LC7eE5MpPr49TlJo01ZiH5jLkj7VBtCJOWWQTp+nzQCWwCVFfQ8P6AJ6LcXC/iYvPUkt/AxnPYh2XdDWuKiLMmuU8kr7Px/1gDmK" ..
	"72WljrtBcWGCzBAdxnn9NpzVDkrhWWMMN2Iws8YWQib+DtWn+SPviNySjFjlA3VOJj9pEaMaexrQ6YPd29P6Yj2vtekBUtEsFv2x" ..
	"ETj6YmWod5ungU3YeeJfcCHXp96k54uTCnZ80dG/Uz82HcvbKkN8YoZ+brQDTHUzmxb+CJ4eNjqNoJYwEv9bPCPqtE393A8FfA44" ..
	"1SkCcq01UScke4GE25yJgKVQZhfdBcnbRheLcgucLS7HYGe6TvEem/Hp/0CVmYPBsMD7QzrZbYlxNxJwqf0p+UDzxq0Z7IwtL9qs" ..
	"3YMKdv4r5e7B3QRYfUu5i/SixWBVwnzWRFUC2EQOjU4pWNeHa0XFEukCmVIZ20Hcauw0uzn8Z3QOVCcsvFv1NuE8oftfoubjh7x1" ..
	"V4E5Hjk3EteWscjucbghmBPYeL3k5gIKZ8YUAWpiLoIz9ltyijQPW/AuAOalE4wJFMhDoimUKaKNFmMa6GdDqR6ReZSHjFeTksRm" ..
	"bHQcV4TlOAKN6Fubcz3JHOkrgZleX4DVDDWZXtWs0XtWH3IT8f9wOamk7KBXAkmSrTLhkpPWV/tQxNr6PP9fdTb5m9bYiYGqMn7W" ..
	"AOymLdD5Eb5k2KH5MPczzjoQ+6psapa58U98RicleXJb9GKf64+v3CXb3O0iBLh0nxrzEDCZ02ydpj3+f/QXzNcG+d9z7jkhSlVe" ..
	"3t0vrgxl8/1/HgBxjVPki9q3+BT79QvczVMiXqGDqm1N8K6cPeVzutJqX0pvY0TgjDWiRvCFeTtTNrx+uHcjBcCeHcpXSzu3dyks" ..
	"jsnjqL2Dnbb8wQ4ksenIBnLNaUj5mf9brDz6IDOX9W6VywVKo0syP2GQozWi4cnyGntVQSblbbvHUYknB2epVuhdSKJ0CmkwhCzd" ..
	"x7nQAFJvNKP29t+pNCGKw4v1PKS1qBUvJY0WCZMnsvs7YhZ/L4tEwtFKkL/eK1u/wsouWHu91rPJyj9/2clNqpR1vVFPZCvqj8T0" ..
	"r8/yDTLjndKmrY1VXp6OPe/HKOEKuPFU+o28FXiWa1npkMyS6r7TZ8N3de/EMT9YXTH1Ufe3/tXZjXf2nlWRAauLxRSO6DUsFA+O" ..
	"e5W8WPzqqOZ/gIH0gFK+AHBZ9hYARkHs5T7MTOG7XFF4QczviDqRFfbhUREFPaxvIG+bxVBIGPjnaIwZGhW2z5RkmPNco9B5v++1" ..
	"5Ti+WIkjZ1LNZdMoUsxQMyZwStYJ0pDPXK0RuS3uzGc1U1Rv6YSALm78gPO5U8+NKBp49taSPjgcNEIyEBMAVu2ltmgI8N3Di3AT" ..
	""
local PAYLOAD_P8 =
	"PGI+d052n9+P3aNvy7PwHerG3zZ68XKzTgdv3lXFFiMIoZt3pVf21nP6b1IbeqyoX8IygO0ljABJq+RpXKTiPJg1x3QVaPpzSP8/" ..
	"qQiOjsEsgDAtCbKizYPclR0/7KHkhniXWnDL7X5nIWLD+KK9QGsc6DNwZMOUzDftWbOgPp30DyypZBsyAuxsHFxIhsqzJi5NAWJF" ..
	"TmFaFq2kQTF/lx0ziZe4wiLeIuzGwJGGgD7BwHs46IpsodFjf/WmuE2CMC23c5WBH6erNKe8vXKfluUuaeB26EoIrnVi8p2ho7HG" ..
	"ZhCj75C0DvJxmC2FRy5xQgPvIswFAcGpVwJ/5KBn1B3jmGbJKrwMVPL7M+95ydVmx8m4rXb2VX7uVuFlhXFNQdmBBkugcPd3yoc9" ..
	"k7+7QbKGp20UKu/5FtRmbJorEW8wJ91GPOD/MXV/YaF4OX6Dy8icmsfke35Z2iZD9EODTIkFrHJFmMRP8CqT2l+/Zfy85Sb97965" ..
	"SdM33XD13TKQpZXzjguwdeEj8KktJE4xa9aEWV9z7aKg/TFWflAgt2BqF2mrpVGxpuRdeGUzDiPpvoq7TjOqdtwJM9Wp7F+hQv2q" ..
	"h5ZKTS9Oe5tJ4PIxI4GTFfvwaeGT2OTAk232By7wAduQBcXp9aKKikKwfVvlWgTztnLzTYRKdN6QGTCXJ6wy1kTkLswlFfAxzYKl" ..
	"okHlB+wXNhDpFx+9+ujkBX8KiMlQHovmyqY4hwyaQA19+CWWNpe0heuY4Mj2kLASzVhCjKyO8+LfJMddDoa/ij5Qcyu3pu6pJRmB" ..
	"bU6jrtxKW/fAVRYWpGbQc+G4vJAxq6ZqB4Sm3vwh8euOEtQXBcThA1+e8JwyHdNe6/fQCeoDqhiSEZXUYTIx/OHjEB9k1rS9leGc" ..
	"ViOWh+KyYC/g6zidCL5Tn20vKMsgtxrPD/LuijAbzPkPrkcaYltu9YYecyyF6roVNsyz0M0HgVP3i1QP4PAn/razoAJPt+qMPUdN" ..
	"prcKM8Dc1xSeA7T5IQaE7qshx9ONYKPqnOEZpi0vv8N6EEw8xC0wXksWcDPbo6UDEtz1Ua5mnJnMqaykR10+IwW3JkYbJqIgM7JG" ..
	"joz7iHbT6wcH9T1QUQQWULevaupdzf3qpVWS+T85yctfJkr/RFjInlDyKT3Xb062pYXzBSIB1yFNwB9sMnCdwgFGtKPhpwSR0fBW" ..
	"an5eaNHNpWD67Z0RRFbmUjGDOaCjV8vFXiQCJaDs/6eTo91dKvZLR5D9pC/GRgl85IpIIdyntTjPQxMdfFwI7kcN1WT7D1wZRavJ" ..
	"4q6E+G7mB1dvjzcnLQ/o7pcATiLP6oRjm0rswO8g/IpKbPRtzSE+8t6HB6+0f48BLQVhrSbTHgROwXqfO6HmT2WToeBvfV5d3lHg" ..
	"agjswEzDZ9WNXmU64nNObHfFosQ8p+XGvJ3M1IqNlB9+oo0Xst7jXIIPuzxu1KHOuIOI5QDEZCNlGuEd3fcxXsHCOtgJfiKyMf+a" ..
	"pzuODXrBPcpXi87kphVzH+SPvjIJwHs4hyQUDp74RLu6n4ByEeLysrbjQ2uG7jDpGSO2msbRPeH7Eqrj8vWC3v+jORCjfm5LGyEs" ..
	"mxyb4VK1kVdSzpdkMV6vMUCvI7Di1Fjtfvq+Jb7CqVQSQEcPjtTZhPv8ODBk9BbLEuAC5t861d5Fg6/l2nfKSz59/SnaypDyp+A6" ..
	"nmsuzWZl1KiUoWNUSH1TEji8QvITMqTccYtxOWpZXPdbFq0KFJq5TqVNChCMEi4LflaplcD564lnRSj0jLmPWK+gtXZgZBBQlVbn" ..
	"ilvU2htGWBzGX32HWerS798GykKuSL1Ut9x4dADy0YK0ylJ+ZOOvHggP4u4XTD8N/X9H0b+BVD8OxXuA5wWrBJCX1l1Nr6rOnv8r" ..
	"E7OJV5sVWK1PHWrUCExCu0q5FfjiX09ipHJ2IagPkCSAs5MDJs6epT2Byji9RAP3KxqJ2V50zuJC8scPx5vTHAJM/OWjPGl3xGc+" ..
	"39ZFw02zK8OI8Sc8k20o+6BxyrqhFKj8POkX0avu5Y2q/QXWbghGmuOO/yTMDvsCXyWXUEqQNyIWqKEARMvWWn6EV9CfF1KVFLq/" ..
	"fcCGQZoeH5U519tp83lDm0YicaE+Utf5kpAh4OMnV4MaXv+E5E42ogDjcoDhjCYpe+L/MU6HYLWsiPbtwM4CRTTcnzHUsdFC2TTc" ..
	"fbCU8znt5+M1FVj9tE7iyEAaoWjUesQfmbgLo+JdJ1Mn8UAkWovWE5LsmgoxFHf+e08Hg66S6qRJha6eRD0FoUYxAhe2KqVO+PC8" ..
	"CIb9N75Qrpe4k+IgXL1uPtUTje+cEw/Nxv7E0Xx2mqfSzDGaQmaMobacU3PcqRa4RiQxQ+fVOhF/NRFCQyS6CDCb26ZH+vnWwuOX" ..
	"NhYWbgfhNvURYUG970Qjly1eKSIhvxf4qDgn3i8OPCR3h+QtlXRaSVZWa4U58NRegucgo4q7ARppXcVmYSXhWonL3P8IhcVv/COt" ..
	"BtRSci9e8cgA1GTeRtw1ytk2qgP1+5jeikXKVCJnyso1bhTRKwqmxrG9Ju2JNRjK6Y/ToZviEUXG6KAnem0V92HF5+NlibdYTry0" ..
	"am1UaS6mY9r1PT9u7N/tISf3IBK/naIy8jr+JY9g4cRplJLtk9tj0nT+XzWF0mwXQQuYIkPyeGWZ2jMzyfpNI/8+JfPHK0xczdIk" ..
	"RqSdCmnglq4aL68fzwk+YZFOEUCO/PqBupb6WRlLBpyi9TAKPZUi6CXPovxNQow/dMvVYfgzujszEuhboDPSbC05ELvqQH0P593k" ..
	"fI2nAewWf4jMqgw+XPko2GdRW+qqyvufAhNslv1VO+LX7gMF5A7CJ8KSVETEmAslnWIyksWikmURHNRlJdkF7mYtPcZkXmvzP/Jh" ..
	"UACcX55khqpioO3fW9cKzht2+WlX+6DrdaNa5VBQrIQWFa2vTSg2SSEsZrUFUyrPAVX6QUO85ejTloEKLe+YPIfLkgwMv7sEAbXR" ..
	"a2NU/+oZlxbzn4uH18rAXyWArT0xdRrN9IBFusQE0vWGWWvwhNQF6YCImtoZUVKVR6FBGeNm6t0ZWQraCVaw6ZbNY0VmgshEjY5A" ..
	"ZkHbYW+lNUXw8M/6izzt1CBYmjxx6VP5V8LlLSInulg9PlpTVkX+f2N8r72/UVAPl1mZzMFFYY15zjqP7KDKZh2KuDbCoFkDhSFI" ..
	"RkNbbqzhTfATmVU/YXvgE8GlZLC71NwETLakCgMTwShSHTmN2NYfc9KzI/eeppEK0bKSjwcvSc36TTQAEIISTJeaQ+Ix7j4U1u90" ..
	"J5ZTPLeUs/LhNkcCH+TRJoKGbrqVP2zeP2ln3vW4+eXhBds7WWLuPZnlSwxCrxxgIXycjDKuZ0UUTVGD0PdhtlWTdYgfgfvp2frZ" ..
	"2QimaqYoN2LBgxtXLKrvvwwgGrXw6QMOvrx/72yzIndRfFDsCaeKXUqjcqylmmLJu9britNx0JkKBl1gxY99s+/KODpgrpQj1aVj" ..
	"1uNZ2FS0cClFTKP2Agt/5f/zTZOntFR92LPpW2XSL0iAXAbCaMbdzGT074P2JFwoO6pHGeGJc3OWxCDiq+VwGiaGPc/15Ob0qoDM" ..
	"DAn2Kz1qXptx9yXFXBWcZPeh8w2nFSv2l24NUQMklDyYF3sv7+2kytqfwKXXFBkxEyXugV3CrLwZvd5y1HFnaxEuVGYShgVrP79f" ..
	"JGjtNKK6twgj5jYUsh1zUGEzliepRrd1CyLvg1qUdIsms6L8hg+x7F/a/QuMzWGHazLy6Xy2RP20AUpyXCeTeALDWMsbvAw8wTdd" ..
	"qP4lzvz8ftxBkUmjvNNVva8TXV449/Pk2xoKf1bHpU8mfEXqYBOsrL8e1LzRbGHL8RawtxLuXOQkhe/D62bgIV3vZcf7MkeRfzvz" ..
	"IxEZVGVXE6vUCKqIsqVO5hkOV+aBijO2Lmn5YQHvoUHmgfPHT+xMcPxh8xO2EXfEApiK+7nLzuhLrW6L2SubzrTD2PjXJP5jGl+A" ..
	"WpCJ82D1gCiJi9SrB/QGBh6E9cRGTabM56QxlfncqJQYP/r21Eb3zQ0BKzZPlS83EGXdQNToX3fNFJkxQ5PLK0hnj6RJHSa0ed+A" ..
	"FfLLCX/TlgALmh+xW82g+/fH9XRh0umVvpriOv7jAsKkeIT9g3Hri/nKBg9dFggh1889nBmu6BssH2/11Bhn7iQ4VavhYm3GMiLC" ..
	"sPC0vEXLsxD353aZTLBoQoKtL6YYORkEV6kDt0FNMTcUlbSgap/fciZDDZbFP1pMAu+mTx7RCVAmffDSCxXfoSTGUe9agaHP3w2w" ..
	"kggDohjeDZLDTHoDnUcMjePZObbqRyDqp3YSf8QmS/jd7Vhv75necToEi5J3oHG+wrZEAaLdSgNjIWRyEq7hcQsT3JE3/kilBuIN" ..
	"5/ekPA6TEa/rt4tOhCv/tw/UCc8ThBSt4TfFVr15EabaUxVK9T5A4wh8xq64ZabWFSF2VWN+f+vyHHKnuhVeOoKRD5BEZ881QqRd" ..
	"kgcsavw4ZHvxvTSTxuP83gGVKVxbdeKfFqVGuanwGm7KLvKutbHH/JxrZTlsGLE1CgOCW/ZMflRp4QTWTIHui7msipiOTiT+oFKv" ..
	"XrdMRc265t8+M/fjguro1Y6wzVPpyWO2Jh+GSr3+LHijEBI5e1W+JXoYOZ811kwuwfD8J3t9d5upYTUW6FRAbGxCCFlW54R4nQU/" ..
	"Mk5AGvgaaUsgjofMm5giLghJ5i++3C7m8yM1ftzMro4OrrO1nX6fmtsZxWO+9Jg6/Ar5XaX5guPju/OEXMT//Lwb1D/K1+LBMmP1" ..
	"5eWDu4Y+aFU3GOn7XgR5IrpRrIWhTh4zjdFLsvDmW33m4YhSluKH3alo1FMMnKtRphvh/b4pyLJlxgDxaalAs61yTgtcSrOXw74k" ..
	"YODYpCaFNVoHSNiZiuKOquZGekivimD6QxhGfeqM4NYtNSbxAKvpSR6xWxLlA6yB3tWi7x6IDk0aueb/Tca7ll30cAlwwuqrKszv" ..
	"YfvoWp48rRoQbv/eU3lb9KHq1GB2iy+Hkk/eGaYZUDbQUQfVBVgJrFQ0NKBDRHe7P9+TOuKs1+Oef9zYX91ioB1PcDeodLsXTLYM" ..
	"QF/JNG0Wn5Zxre0/VDx/dj7yyI+GRIyvcwG3nPe6YMeDBTw9SB/c8nAz5YKXsq2YMp7+2Xbt95cITEkS/96QRIXoex6fDhmY2ReF" ..
	"q6u4iNtM+eUNPkYKRXy7RW/ZuSP7GT3MoBZlpGt56r/qHNcTNbdCOyxwSg6LBTjPpb37eRjj9g54nQXV60Tg1GOzby/TlxgWjDLL" ..
	"JOJz7CPPUmmrpv42Jpvr1NobVYNa4V5p2eMJTPK3DBGhCXpZRuZynf9423jk+exOEAAwml4JnNaT1POf54PVRWaKQmoBfkS88FL1" ..
	"MW4IdHFisKMoFRp80g42wrvXg90iW8xc2Kg75NHHmQcM+nTONqmexsbSI8nkeVjMPrRiDU+yvYgbDS+o5l6j/sBuYkgqueIIdyZ2" ..
	"bl1B//yffU/oag1BK2J5gSi+c0jVqoVCdrp03svx2w44MPP8cifug5C2sWA8w41bolBpO3yORsJK7YZUepggLyM0zm/6P7AENAY3" ..
	"65AxVFNI1RASUvlW5es41Sr086v6zL/6wDQLani9DNw0PGB4D728OXDB8GaLVCJvw+wN7b4ylpmVh3M8G8dhGpD8M6RMgQxBtSsT" ..
	"/jY0ApMgtNLXihkpPqGxzwRhUVIqcLrYjocse7ohLMSZhqhIFxSV+semUqVXO8dvQeuN9EvqfhKIXtqq0WIu07mQwGO/GCSuB1k6" ..
	"RXYjClR/Dn4cVurSJ8hHAK6sZvSji7G+wbIDhhGaTOoxZs9tFJaWUiFQ0HTy1bx3GJ6UMOZGBWx2ztcnlFonJE1GGr+ntiwcV9q2" ..
	"mAmvi5QY5ujH+4XAa3+yZCtDTZMAytEL4VLGeyVrFHN3hW2XYzdRxWbjv2/lxu9RlVkVzxqjWN7c3iizLm6PGUBQEUvihReZUfGU" ..
	""
local PAYLOAD_P9 =
	"XFxjUmWvvK/OpJO2e52l4PsUrrMcEA8H7hXjalYxt2YCMnPGrxJi4s1YpsbuoA/ORML4Hwwr9S2LQZTX20BYDuTwFyoOPqbsAEtJ" ..
	"13tNqkJ8Z+dxxJFUis2NNPDCXVmbFeZDwsdLvhi5gLaBvjzzzuyzlx7TiALwkte+dxeseIJqEWHnozcKbR6+MYc+n1QtUaSsrEF0" ..
	"l2LrV3rQ81BSP75+kx8LaOB5ZPowvMtJFbil28qhp0FHeU5lv5hd8czM5YOPQvX+GO7RMQmqoxKZlUlOe/rTGToVRqzAJk/ufoU2" ..
	"XIIm4YjYtSzJYVNp1LS/3depGNcGkTe3FIZBYQv2hbXwA4eNHu4Ihxnlbt0hwZsJkvuxDuoGVQneBzvldW4EWSRLAuxAMUr2tW1P" ..
	"Hfmt5NqZol5b9reBX1n8jtn7Wa6JlUuDGCWvtoaBco4B27OZuQHJye111g3HbKciagGUHEpwRweigMpHSPfygSYqLffEtDHBqeJ5" ..
	"0/zA/qTbsugM/7/r7pbeMdY+llkk5mcHQz89mcHweOCbicfrspnfmYhdPgTFHxp5zz5CEAbzKuOmNSzr/geCiObabnflml8Rcug8" ..
	"ilfMrWY8kmpULeBJ/FQF8VsW/GrUoEopO3vZkp7vOngZxfSRvSK3OkIMCjbbQGGNG+5czAuaLdyWWnnuI06OTsdj+zC+9IKzn85s" ..
	"yMzs1ulrjMmWaitXMgfzfMOe4vWiZAObd6CksMOA35bQSfFrArtRd4sQqYrz5hfoBWKzTawECdMa8S7mDuQrCEZ/TPOJfmfIXxdf" ..
	"/QCkGjyxbE7HKlyh+x0vo4iJ+v62Bu8AZbSSYOE9zZel0tI9mo0DHXEQ59xLy0krP/VTYOkQZjgbQxfU8mcOvobFBUwMQwDxVVt/" ..
	"upmP1UmnQa9v1hJ+PdVyLS5Ya8VJOgQKmKiZpuNnGXKmdzNQ+XV8K41rUe37xQLFatdRzRGgRic/2qufmmVNMq7wtNagN25scn90" ..
	"YTK/wZHEHIhvqH1p/TN5C4si/rzCir1sfTThYIY5fer2u2X33L0zdolXUPKaCEGEiVdJXJsln9/PJZSB1vpq7e7TSEJj7rB1jN8D" ..
	"uJwzo5SqNxud6XmZzRzOVJ0rrxPD9TmVsWx0mg3zuwxd9j9smHo3FZCTri/UzfwVUE6KsUrcWXCit6403Sh7mOmVov1qqpoFwcRX" ..
	"2NHVvVcs8ZsPmoEel5EHgZLdwwNUHybh84CsP2R1OwYdNXCAPCjwHWwPXNu66DCJo98hctsr+i3oZ2Yv2oPmFTwsiU6cWJTfILuS" ..
	"BNzaMQuLNz/zL3dEgnHtkEnEWfKPpF0clQNeiC0F/a1XyVj63PFx5Q0x2C4JweuiSN7t1EP3xHRjmmfBU9pcrEIiG69X5RFudQhY" ..
	"I4jlVj20STynv7DPhn8W9jTJa2BIxpA/TI4v92tM9uokxwe9NwjsefF0yZ0E7e7wjNYVdWdxlQQOmjBbXkwVrbt42jp+RdnjQNHY" ..
	"8bXIlLX4NvdozLZ35hhMUH6O93l+axqYf5Y2g+kJYz+Ke8o4GcnHs77Epx6kOM3Na+QtciUHtT0qZc63OeI3FR9LaC4YPbEE0aqx" ..
	"knsCZDjztgQzkqWLLWKJBjgdiApH85Hvpic4IU+kci8EBnZyd3gRwGyYznelurqH1Nat75AvMrsQqZzZKIYGquDQ2VgNLeUh5dLz" ..
	"yyv0CpzVupAmgL6QYhLEypGR9NCoXRg2cR3xtyw5YmqisCkKW1C3Ai+QGdWfaDK7PDHpvzGJef+cPH7eJ9ltYKaSFBepNbjbz8ZD" ..
	"hKt1DMZ7HUtD7IzaFch8UWwRuWVJfjCuJmcnEBqScSTqpU3u9wPk+lpJNpJWuYP8rK6NCCkHjrLnEDcBariYkj596ElrjCGNn07q" ..
	"vV/buv1z2HhVrFrHUHxh/WYWmpmNG7xx8bwNozFYFlqIpNtcUjprHvHLFFpKcRnJY0+v7hTki5qxxioUTnvsxgUlMD+Z7+MyAiq1" ..
	"qwAafoI+/qmmLZUdp7YjGKaH2Tf4ULDth/WgWD+nwfrtczrXMjS/5qsDtXHn0CfpIvobXcFcv6SHyPUZFGEDtPXfuIB3ahQmZFMu" ..
	"MdMGrmE87yH4P/Mf9eyhl8jsTcIDmtrMSbVfnRWVFG4XlPZqt5fnM24AdciPE+8ulUmhjGZdYA1H1pNt+oegpH8TQ1MALg5H0NOZ" ..
	"2QJ+GFp7V7t6fWBCm0iGGSfZtk3LM7wwaWm5ZCKg5wVggP1V0a+YLCyxb6L1It5ROfENOdN2UJK6ZR0ciwzTR516fyICUxs2Ho8k" ..
	"cxin1UmnlDTWSrCNlzh6tXDNDK2vKQXGELDmy4U8JWoos1WrFYQ8I6QtMfZrBqKiWfNtKu3xemYbIRdxBsMJ0vdd/WW7e9Dxf1Fn" ..
	"d2mhHEvoHjRt5Dabt8ApNZf85Rg5wnTpCahLq/2vsOt6rxcFg2DKclfN4uVYcbqYJL6k44+HTQwA7Tn1csMKK/DCvbIhsAran5f7" ..
	"JFLq+o/5y+OKOZP2L4qCqD+uJIs9DP6cnwKE1xX/kKW0WEjRXE2rjMl9PqhHoScGDh8BMAKyBkhlGJp83bJyDSDCrTMEeVirN1Rk" ..
	"KOACTOkPuld3phQlqeQZFTovpAWeU/Mh2z2oOeuzPD1xUsArARDsWSBx+VGmdmoAlI3zzT+IEFciek+hIVyjqzA4T05QhP73k+8y" ..
	"LEAXLCje8O1MUAhlXKt4L1qwCu5Rzl4MA3+LV6DtS2rFMiyg+78l/mRIUoE+9hwkMWfkWll2pB5YIJZKTRJAFl5sdPSJrEGgqTXM" ..
	"kFuNBRXaXawY9O/EnG9iKewNTLUX9rvvjA1zH3UrSD1IfIoiEnNq5WrSO5sa/kz6yjRq3pOlHobuD1Me6oaFXMRP69G+1M5lo8wW" ..
	"ZhNswes/jjrWQa+wkhOAITN4Juylf1jVLwAU2dhoGzxMoIo/WZ+fX/S/apnHzFAFnAoCqT4HsoRnlOwDAwxRqd8ouG6LufT2qP8Z" ..
	"mE9aA6jTed4b+MMG/mFPH16RpZ9ktyuyiV8pxRI51x0R63Pd6Ej3U489sio+B7UKLcCOgu1ezAHI2v2qxeiUcDZuyXPM5RcUtdV8" ..
	"xotHq99JjNzBou/SG6Yb6wPw/frzDzMyaDUgFYKMbF1rvbLF9v7StROAb8W20B8L4STMNkjcPHCPn1rVmt5WUCaadlR1o3Tq4yq3" ..
	"u09dKjtwQtm5KVMQCFeKoBWMCNwthB8sRedzbhE2hCSDKz9nkauhEYA+3AmQyDbfEffNMJNiHJ8kjivt1P+JXfS1pcXi1gafWc6N" ..
	"238O5n74AngvR+FUX3LdPnlBiMAIc75YfafJdCo6Do/MafJTo0vpQ7C31/9Gejm9is8+lea+sV+DmlljnFhM7J/uGC/LfkeCMuWX" ..
	"z8GZVHJyjB5BvsoUOzk7ivZkRLxZhppChsIP7MXnY4hSzOxhXzNZh+h0zFLM6b4mWXcH4k3LCRdpnkZe4/4k0LHdbHXVjMSjohlM" ..
	"kW5EeaOP32qc7+erFwfoZ1JqDWy8oyEWEMtrnt966wxHsEeTIJbwRLpd99U6YMNc/6yNHeO6/o2khVCo/eYX53nhZVeiKMyczgsE" ..
	"0kR/C09A4pjiggb07BvdgQht5ZYj+7Lnlb8CB+BmEBc4YOhsQJbxZxxBF8/FQ2UbUENnYp57LcwHFVrFaYW7XzTkEeLPa5FYcMr7" ..
	"M5awtas71cFrXFYIMneujU0fNrJ0PKswkLTrSuE2mDai0hyWBLiYY70K45cSoQbpc9dHrZOxBgbTzpgekof/dt5uSbMGjq0RTBms" ..
	"wuPt5682TOmfaoQNj8EOMurBLX+RlpADFJZ9srRqdns6/b9pMJLZUkl4lFVOIxv1TFR3IBc1HreJ2qlSlQq4vlqbbxFP4mQsYGtr" ..
	"5HZjIWyVds4+dNUBoS+JdA0ksLRdMXZt109134qXbCw4K4vqWRiEQz3JZHAtA49ZGY23YMsJGqG6TaDUYT1xWTIKOJjrtynvzQs7" ..
	"itqmGbG8HdQjLL3x+63ouUjWDMyfyHYlyz620vlQ8ynfgiWOQdmFstsXLPKK1H77R25qiuKU2zNiqEbGsvBvmWGAQqzoV7OOB5i/" ..
	"Egp44/X6wz35uxuzS9SJJX8SqxwLHxg9wl/mOrYZwVrhRqNQt93JEX376IkEvAdgjImjeMbYmro/2yVDpwid8glSAuZABlGwL5ZF" ..
	"53+Mwr8jU4WyYfVv/7xpXkvl21exRNQlf3/WBuFHv8Mg9udjleHivuhUaFYQorl3osRgPOmDzYimCl2aoV01e/kkaRo/H141gw4m" ..
	"Zorj+r9lzM4FAaf5VqgwctvL0q+cPHAsP8bfj2TkjzqXlWkhTOfeKuPX4kHIYjJLvrsCdv85KHZEWeoMEuJW9vpJKkv7/VwpTvgn" ..
	"NJ0fLpI4SqYwyQpDzHAg6RFaTRgLo5Vd7plssvAj1FDyhAnYIXbTjBNI0350b4akRkFbrE1D0WvDnxafT++/3awt/WqEO/kMxoqu" ..
	"v3O1v6wXRcLl7Ndgkd3snhLV+sUbCZe5f8rCdZFtA0VUHwsofwIMkS3+BYgjf1ak93hpPRyn/A9w3eqL77Y5h6iNylsvgxBIlkbN" ..
	"LvVE0zc8gO47bnQZxmhSAfDGviOzNOBnMCrJHRSE/DRuhUzXplhhAWEhHT1jtTcEXcFh5TxORfiydfWOVc2MvNyk0C/eZhsQxBRz" ..
	"Tu09Js/alNW4Bia+jU5ZlEoiEWUuzze6tqAObMGRBzPTKx5/5522rcqUdZFbRHxpndAS51IeuFzxWG/qxt3EloxRWUELhMYGPBAJ" ..
	"/eL+QVr+tYdHn8jfKjA6YHtF8HOoA9E3GCFTKCXjHb3JWgQR7R5IK0v7888ozUixi9PoiaGjVus8cbJkdyn8zRPv93nCnbIF7Gjd" ..
	"Ymla5hTaWofgYX/w+jPIscmGGp36fXk5mLCmpD9NXzC30XOf7Bf1ZEAgpAi7SPNA8kyuyRylATK4cLyV5hXFXktg4p5zIWEXdR7X" ..
	"xFCHVNYc+3LmquGOWLtM91/0a61djnbiJRcxyENttqOiPK0iLszk9TT7w+W01C/SP53l09LqbjIB7GoHoR4c4eWVHWcWvkC2hVLe" ..
	"2gwEwRxXAeCBf1hBaJH8S+aB/sdgIqJ5zHYZeGjrgOaDnf+uKcQs/Xy8MWN2TGwWAUPxetv/cfW9H5QpcREtQg/vx7HzrhpAMbmv" ..
	"GsFUb0PDVf3z6Wx4ZNdHIcxYLF8qpsyRyBymrIjDdvM16qQxK2qzsOfgdG18xQHln8GJY6t7A94otLttUUofpDtFSrYQNQP5u4f7" ..
	"sddpSnJDrcq3dr53ROTlCb/5kfXug+TknnlzrG10tr43uF7QT2Rejmeo91dMix22eysBkAn+l/OLaksJ+WT6jlOuBVCFHwwYziRy" ..
	"3wTdYjvas1ltHXxn560EliTy+XaiB8z0rTt5LI+ADaiXkxJFyNA/OHwwrShhOM0/FFWT6eAetRwcB6RnIyLZFkk23LYrihe5qadx" ..
	"Nv89cgGfBwlmRjxw2uUQvk7r/WQuC8V5yYga4p2vOBqwO+/Zn7zkUMJh0NXfMkBEByRPLNxAwF7J+zPlrwFYm2ABoyZnub3MUYds" ..
	"WO0fkWlJBL9vzc6AlpJzBumnDPbtXOcJ5QwJ2kmjqYsg4FOY/cUnPCWYLG91ktdXHok9KrWM/8GN6wUaCgF0MfFspz2J3tzohvAd" ..
	"fEd7v6XZ2D2wtyB0cHTU96JF9giMM7JV+bIHFz8e1AEnnpri3iXnEaxiM/4TtCf+Iw4daLjHHkTsDeztRkecWuCkLu2p54aZo7zP" ..
	"N0Nf7TgMIQXodBy9cTPI+kLpKkB1gk04ENEIx6Jf9m4EVjGST5FiEBxNBri93J98b9uxn11jvc4Rmb9AaXwsClHSq1EjYC8ZLvQz" ..
	"DxbjdCJIEARQpPFccYOOyuwNWPgO+ZfWQwI8dXOOzBHcAXACcwbsc3SMsshCzgPA7fdcb7H8Ss9bjZC9LCDPE/r4ZIfgoQZ3x0Kz" ..
	""
local PAYLOAD_P10 =
	"7F+JqyUAf0ag03kG6KJcfmlvCdZZ0CgADLbPZaZ3s+TlmLfVSektkW8DMck7bVhgk2yWjLRn/dYbpw5wqnCLTVzv3pHKv97FZSf+" ..
	"god9NbrlG8uDXH/aATGL2WLMzkYCHw7W/zO4E6nfxEuRyw1Q2/Pq8ATrUq5furUeW7p3XkfaCvN3QjX0lhtNnad2Fg0aGEsjmeiA" ..
	"UNYxE3kJSlNp42vJJtfxytn6Wh1pahz5uF+5F2hz+LZdrgVu4sY+/OKJNopaEWCdMVZNzTwtSdUmO6Txojc7mgeGupy7jln3Af0/" ..
	"UGc7SOVXrUHfeIAN69a7T4W4/odX6Lr9DwfYQiQYQsMGUd4eAu2wmlaLPeKh3nJW5stMhHY0PwRqGJlMeN53YRbpqPVSW9Jkxbe5" ..
	"KHwpawcho6vvloqjviD2FrmxnPW365ZlUfm8K70toz0HRgmJVog1h5PmTJxKlKrjKgRpavZdju3OnNnYEi8GnLdO3K8oUCYRL4OC" ..
	"oob4EMeyFFpLPntZo+nEQsttJwWdSACsfE6ZFaSPNZtao1ilt/MMXfs+ZaOiASdTPxcY2wDzBmykUtaOm26TDwjTSWgrn4b4Fdyc" ..
	"SSXLRj+a4hdahJGyYkW9hWZr8Yrh8Yf71oqijdelZ0JX+uWXAy7n4yHJ6F5aWzyukdPRkBGyjJJiYjZnCJI9KvyE44lEjUxXPp4n" ..
	"i436bPcaLOhr565O4cdD2sXwQDp4b5HIWJg+L144HsQXfuahFM1ghBvPaZU5SFOMqQmcWNKVAWDKskyrqJFb3qgK5AhV0ALnPIO2" ..
	"40u0akyVUXWQY6CUJlOBV63zg0yyTg5R8Rq1gkCFbg5D/Jg1sknJpWzr6O59/x8fAB4cXBd08+Da9gLmgwXpnzxgi6dN1JnP3CGW" ..
	"b045fVAWmWH+s1QABhNgl8QER5HNGImluZvcpVzRXcWz5eZ/CuYZNJmv+0Rmv5B51VDOHIp7WofF/UvQOFWTbsGc7/MubryMlHx7" ..
	"fK8LpSoMiRN8Xx52nXlo/3LsxCXMMhEsarLVMoTuZP7HbTiyKIVi7uLqWHFhvXUfeXjZ+BB3NbLVlXEYkOMRXGz50/FKls+Xhl7G" ..
	"vZaPO8iCyt6hj/4VAHQzSkcteNQj2Wu8YI8n1uXF10Q5EInAU4A1BwgVyG0tlcxwRuSgskFItG/9FDNOiYaQP1HkWW/1X3aCUQSB" ..
	"JtAxjXJMdNtZCkAdSYPm6LLaMyZsavFMGiam1pUkZ9mhlwlFsj/06slFZFdcc+kEHlGd1H4+kCyVLW+zxbs2fViS6ivvnA1IEF2Q" ..
	"3nkGYZinVDkUNDfTzpsIitk4/8/9AzR/YH7HW7rqhvEwpE6qJ/hA6l1ksFQ3jLmKbG8/Wqwbyf+/gO+ScRBdrKYm+O88c7HBMPqz" ..
	"+TZ52dqU0jUW2m9TU2WkkgHto0rvp/6IUFyBo4dls0+e0roVmEW86b0Ky1ajuMzYmYWVi3ceKwiX5fzXDN8U24W4yTX0/+ay+mVL" ..
	"d17zWsTWToyQoYGgmJtL3FfSq6EZ6qpUNlGQt0lXITgCte119dLeBMa9v8dcNXmljzFVlA6c+h35FuLVCyoUHUZLbXt5PXVJCaPb" ..
	"yKQrkwcR5QyjtwhoyibjcBbKbtEBI1AbhzBzeSn4Idkdc7G5Ssfys0eFAPiZm8xaOwetmK5Lnx7/vz0M7+yMkn/y4ZtEWPAwxGb0" ..
	"y2JxKk/KRtnmJLUY6k4dsoLUOxDwFFT4A/xL1I/U3XxltdIbmGYPnIdu8HCe4FBTShMG34YMzukUlOwJCXABKVdAAxqXIfPE0DiY" ..
	"4k64BNihc4ZYiaFU0Ppm3ufnzHOcrp0xgeq6N3I5JuCLXS1XED+LO3KbsnlOLJlpRJwyazETOksvaB+PlKCN9dehwhTi3zdgwo9s" ..
	"OkG3j2dJW7UYpug97yuc2APv4W+wfzzLgzwimpD/PnctgloVG1t5IGYajF/tj25j5mFzZwJEIkm33wwQWIbqZQGy3X5JC+cVZNYf" ..
	"13Y+1bzDArkoRI86LD5BJ93d8naJMupb4QVLG3tWBb95LVAciSloaUQCS4d6HzYvF9z446ylGNIASu2hKbhfpfE0Jbfr5PWi+M9g" ..
	"wc1zV8cUryFo9VCA9bq5AZkHgbOoTgEpb4jwXZXR3AiOiVUc0H+IhIQXMmyDSl3IvyVdQX2OKbHeFZyZvfxLDz21VE1ryE21KO/G" ..
	"4QayHMuw1/swjeQKKtceqcdjIHNEBFuEX6erS4SuLyUPJdBNn3yaVsMQji5C9W8GXooiXO4odq2VmM+T1oiNFodx/xBGxoNQE5Ws" ..
	"d8NeNdcNivmzyZg7BXc8tY4GPzXH+BWdOL6zUJr5P51uk4psdqmJhuT+WZIoaYaJGN+LBoUq2AZsOejBEY66VhLFGFtIBBYRHfRq" ..
	"YMEtidYVXsBT2Eht8VCGc/HUsiBU+riAVixT9SyEJmvQjHBpeI+NPZw79SIi8faOhovlD93YeqBZaZRpEMgBhKW5gJ7egpaIUbUB" ..
	"tz8j1EPSGC+ztQrenw2bSNzBX5o/LPRJ+qksuuPXrlWumsk6XYEN8rVlyyl5bHN3IbFuQwVBREAqLYCevF/PD8SKjTYFaC/DlBLw" ..
	"pZz5tlfPvINMBHNW7ckRJfNvC897g2aGfbBpvAms+dszMOR3nf/CK2wRk8OKE5EdpNRL+vLyD4HgGQYq8ayEAnAOEq8OfYPFn60T" ..
	"YfxRlZdyOouoe4CNNXiKi+uCWrwN6QWmljd820KGeEN0kCktmgjzWs5gayUHqTcYc0KxDx4MSkxWFTYlue+w+Vh0mor2V4VvqmUl" ..
	"UhLz08HTuRL3lskWl8Ltm9KAgswY+sUIa/nnim/4bHsx3rHwZjSOuhJALUO7MO1yfcBCGl3ieNo1hRkRpGbYUD3hf8DUtaA8iPrY" ..
	"DjeP2PokQfOFhUYCBz6bM8dDi1C1pXrNHSSUhuWopGvO5n8LOUrLAYARjlFJ0pSU+VSwSe4f0ACmXzfODxriZC+YdyG3Ms3df7zr" ..
	"ER6Lwon1XsxOdI6j9zcdI5DzveUYa2wX5+qgyvwwFjbP2bWlb1ipmp3qlXwZAYGiphw7EYirkKhEbYGkB9+TS8c+yl5b3YcSlZGU" ..
	"okTmQ2urBSYDBOIssAqICJJZCog4Kp9iktV+o/kvfKqYDHrRwG1gepXGbFA3Oat+ZjyXudaOJac3Ce0OQf+pLIcN/0CV0EFxlnPr" ..
	"+TdBc1E/YzXTZrSZo8tlkZtiX7eEqzW8a+VeRwUGgMRt8cuOW7sDgDbgdqZca9tLglbP2MQb/XYhwjJtbevI0i18aVqV7umy0qTy" ..
	"ssqxt0ZUPK97Anf1zd4AU5/01dLfbbNqI6tcJXFnPZL/YMaW9w/rEycDZWaoRYSuRU7tnSuJ/otAiMlbhmrkDM63q1XrUNX8Omof" ..
	"3NfKBsY5P3sdbO7419VLHPHmXzaPbPG47R5mhLF5hA2ArNcQGOO7DNPaf2/fZ03sOwkrN2ap2c1Jk7bid/fPWet36vsToACtgu4b" ..
	"8/Lsy/x0I//oT5gVbj9CKhhPsbwW7MfR9CdIxtTR4+YFjD5DRAgAExv8Ix2Au4Tyd043hTNRAyFsX4H7On2IMmLA0QIszSnFpLjo" ..
	"YLRd8kioBgoRGRe2qSUf3HWg4AsT7nSF78+NkHnbF0LJgMs2m8Cf8xQOLM9MR/Q+XZG0dOhoKiaVxTlnbgsKIQxc2nxp+1fBo5x2" ..
	"WNpmF2wgD4PBf0KZncShjHIqAFpmDoFeRE3ExNW93oVVFO92PHM5Hrtf+UBGuupWB/my1VVHgabQKBVABxbX6iEYA6DXqhzqlxyc" ..
	"hsPvGxdgR2yHZFZNda7rkBsFxWu545/b/TMdX40k5iRnXip6cIbyg59c5YSzED0P+6bYoPdJ1/XkpouLSVvoiquwYqnx9wfHwnBA" ..
	"RHGCJkr+VfGuWQ8mCu/ZvO3g8IOO16zpx3SwWGAwxdylOfKupWo/7VVXvGs8r/4CvVtHDKgWy5jsY8/tOzsMhbqixPMyQgaOALlT" ..
	"3+a+Sf3S7+EyVDMWNN3XotHLVWuL2gEl2PsH8/zVPjNSpvP2Dv0pHAiGS0OwPPJhxaEXDMRR16IN12XUYRlQLJCx/Fj5klI6ahq3" ..
	"/rwnD2UjeAwtvhNOMn2i9soS7RiDiy7fMtydKeNDTQMlTwGDYRq4rxV3bpj6810dTNQ/s8yyOIb5ecTz/dm6VYr+tgaQYxbORhpZ" ..
	"uWsbYv1QuNuyJGnTPK2GPj/AYHTom5FGP6rfz+GSw8OLp2JixzSYho3ACncz1mkGFGyRbj0FpIFYQ1jpXc2ICWSmqtMVhwbLqc9P" ..
	"noESL99SevjHCOnox/PygRWPlVOV4ww6huykK2l7wmvBqPodqBqPgDJvGaghH15f4iEZ4c7gewsQYbbOuLv8JApwUBqNIe1VCvty" ..
	"R/B58oHAahgRuz1kGA7lmpwSxxiPChFGR0ffrTAy7Lm7NJpT509GrZ5OLlbpAg5cSQ6lG6pK3Ha8Inza3N3AF3gdNiBIsBBYFc4S" ..
	"0bs7tn8Ye3MqBoFkecbX2uUG04xiTM/MXlSmRZEvopvny/JtJyORnUOWKAbNuQ/Vz1BT9IS/hr2bfuVp2ZLFDQVXlQ7dPeh5FAoW" ..
	"j2HEgYCf9ZCvhXtbFvcil6YJem/XlZJna9YXSqw3l+MYfm+0s0XIsVtb1cPanSXIyTVX3Fb+y3/ivfEBUGQ3FgXLi4d2HcNjmYSA" ..
	"s0SgrDYTTUZ2Rjezspy7yr+CDcPsiaDqqnvYXMVYzpbqVOxaPg6G8iJcCShcbLQy1PQgyLB6FZAGC7wI6SL6aDoadL0q1mpohCdO" ..
	"kiWMjj1ggHUi+eFJHelNPCUmd7JjL0/J2vz43rTSJkMKPJsCOppuAAvUlTudviGwmFSliJ/KG0TIvI6LpopJE3mArCH8YRod/FVG" ..
	"sY1jofnQ8b6qwjp3NCojLc7aGfyvIx7YEOBQFZuX/xgrknCqHO8UIXeVfW24GBJ8LyTRhazsr5YbL7TeBDxFBvVgtW+hOlVqUvcS" ..
	"+Dj3JTCc4yisF0h5VPO44vrrp8F2CR27xaH7F78h8y+je0w0PPIiFryuQSQPqH5fFcJvoh2ZN8gm0IYjePgp8YEd9jOonAowHHwq" ..
	"cua3ibqNM8OHYQjD8k81G1cfaIaDvVBV+1ieEmquJEOTIBNfqvF1KdOiOGBqnKx2xs9ahkaG6ZuJtSYIOUqrpkLi4KucbAIqTQCk" ..
	"BBgE5+XyMtX2kA8jw5nUJAUMReGApi8HxPlwKHa/NQG9/4N3wPMgoQ6uOU/C2KXX3iUVB2o1q3IogOYV6uhT6PZ/5UCNo/3VwA6v" ..
	"x3Mr+kkudmANBjIZV93qX9KbAl3wPsQFuYyIdqHsLwYRQYkDAkY6ztpn9jRnAJzsN7Eotx20heL5K1zkXi99P5B/gIIozpz9AmJo" ..
	"GNSegSBR0OKVuMv12dnKpWPrTyWeD0WHmAyBQmj35PNesG3QH06kLkW/7K5A9ke5BW91BkOgXRGVDIthiebvJxDCakbzU34ARjW5" ..
	"lvOSdjvqKITGJkkZaJQkRWi4mr1Paq7hwyiYG1Al7K8d8gXDGiCA+d2DdHLIUQl7j0pnjE9+74DcM6dS7XSKJZTaiwB4pNwX5Tv/" ..
	"Q46V8IhuHp3NnHmCjM5OpkjcmXfftco=" ..
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
