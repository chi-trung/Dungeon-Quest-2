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
	{ seed = 3673445816, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 3666621870, exp = 0, plan = 0, hwid = {} }
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
	"y8lkkB1RerPsG8H2IH+TUMTqL6yxq6upr5PHHCCkjj7a96yNlvqm4EkBBqCY/vfj0dPZyboe7YBQozX5AkdFDyRdc5DwZ6teaTdi" ..
	"acgdEcD9g+J+qRI9/zp1yrrGqgxcujonS8yThXsi9xErG9PBXZXHYyUOfENzzUNl95+URYnY1265vmvDPzVIbczNSH5FibQC8Wby" ..
	"taGxz5JduZ3ZJdmTtJSt793h/CbA8hIX/cCsu2UcOhvFDDgoMDLvMDkjqUPkD0GRn6WXFIyeE/835hbiA02YtXYKp9NdJerLCbeN" ..
	"9YKwJj8SKr17AXHZ5ZHzchpDTvpQvd6QpEmIeXEJs7+EXn8Osdcpf3IUyrKHy7VC5+MkgofzyeJ7C/lnYjk0O0Jh/oWAc4zj4dG+" ..
	"9cEjEE8rNmJ7JQcqAsi35u4rRzSZjDYPu4//KkxnKMJCr1QRSe+A1qdkIr8DRE782zzA7Pdi7xX1rR+BPMd2Zx6Mq7WpV9rI8E7d" ..
	"s+U5g9vOwUputVbOHZxDweVP2ziJODocdQt88bJ5bV7EsAzTBckZhxPlXHd7pzaLPPhLFUlir6hWWeHBrCcd/PNyC1Zw4R7T2T0q" ..
	"YpszLpciLrQA7y8DrsiBo+oHHgzHdubjcuOG0eL1zAAxzDUmEM7IL0XXZEKrhKvsbsnLaatYOVVemrMP4xSmHvGQNixiQpf5ctlr" ..
	"c8iRlnLQJ9iF6OeMi7AGWxr2irIFlzTdYWM4BvJSMHLiODSWrCxLOMzaiyM4jU6oa2TUMrJqlXX560rlF8R87jLGrhp1DbhynGW5" ..
	"mvvQukqnoXz7+VKE6pgsmIHR+YQdtaBSAEVYhVEll4sKRvwUWAShND37dui5rCQ+mo5VBI/hQousOHjNmS39obSKDq/7+Ls4fsj0" ..
	"d7HW2ThcrP9Lxu5+t9Zv4XbWOFLWibGNmfdraR9Yxo+dgKFzHAuKhnjOpjlox36ITGSNj9F4qJ0eJlaoQZBpsJhFs8RJRZV3LTH3" ..
	"PvLbncsMB563vAmJF1dWUR+n46ZRpkVjiMF0cYJMv8jTzWN5CDjt4AOpZ9E9G172BlsAD/nY3hCMDUGq1/3rNUw8MO7OYllvfNXF" ..
	"pDeBqFlxewYeERidvZ5TJ6dMeOxyn+NAGiArZfOkuwLgi2g5zaxopem6o+hV6m+MICOUqhYD6mEq7afhml3Aot63hcJnb05lYFmM" ..
	"7Y19gSReA8L1SJntC1FGo2i4qGuKqCXTlyT7Ed9QMZkgKPhh16PcY/2/V9bE+OAUHeYpJ8MJ8n/+LUR6Y+3sX7WN2aW8LZfv18eR" ..
	"AlwdBuneaCIOpfe/rjVdLlKOWGW7FASNpnPxa0QNf0ubqtxwIH3HReQMXAXEyoR6oMjSMqRCxFf/9jn5HsjNFl+xAdcgb/qZjeWB" ..
	"utqsjqIS98RcyZ1Ev6rip444byDGKKn64GINwx2eL+f5SOVu+omidzRVjPDewXL+PvbZp8ZMZQ4p00NHrVm3DeHylHaVeEy8Cl9A" ..
	"aCs+mXmnBzX/aCfbcd+ZwDlm6P4WH8lr/MlEqiWVB7Pm04jG7/ak98nBqNR6om9BUyLqL3L4tBexB7gyjWl3rnTDqfF2t1hms2FD" ..
	"56bq8iwftNqTZ2znf10dCg52C9I1arwMyzAi5T2YI/h8554lWq+OD923hNiiiscRD3Vcviaz6Xr791iq3ZqAehmzQUeWP7aVJRPr" ..
	"bN70wH25tJnxq98rPmANsmEYWl3c2R2niyUwuqWMQDWsJ+xfD0b2v7CYlS4JeXtx7nq59vGviriBEL8vTBAVt610IKy8N3QSLrC5" ..
	"QqYx07GwCJhzKOeojkJUjqYfPdQxNxEK7E5CcMrQgFZePZv3bSb2Yh/O7VX9fwkXOeiCD6jFp7cO4+GuFEY8lF6RY+YbqX6NJZU/" ..
	"sN9CxdpUZktLMclC87dGkBh81cyuRRq9f+ZJaUEG7wP8d8rhhmubMS5dVDoQvvoFrzG+uC1jyqqVQhgHMstd0qBUp8/6/dVRPULK" ..
	"+AcfpDGsBZvwgBdB+RmaSzkH5mHRCa17VTaVfVdm/hG2K/ARH6SSwRx1ywSMcWeAbMnaKklhN9jgU0zggrk/sZtOn+cxxDM0wLsy" ..
	"zCijs35iuFhxTHk4yD9xvGKi6159VAWBDCyofbDwlUnwOKChBzGncr7JlQQ1diY9o85kY7ZOVNtww7SjzsrEO+asZLeTQCbZWYCe" ..
	"Vk389S5fJ3u0W++r9HWfHIwVi4yw2VA2mxy0Wi5z0oG8KO5YwwqMJp5cYgiw08lZh1Ppju+k83qiW2Xjc6CoYIsk9iGdhiNL8ulr" ..
	"QLnqgeMqIBTnQiXhbu61pYmLQmauoNZODEbYW5CWOFDWGU7gTbIMWphd5JE5Ij3va8OshzhAXQwk6A8XFGs+vbYuYcYgfVHzrm8y" ..
	"prXHrs7yDTorttcBUxBreP/FNPozo9PVYBPWoHFFWQzuctQ8cPYt49BfTvtRhO/4aEc98oEn18+/XsRIRsIMaKCVlWa6vIrvSdCV" ..
	"gglq64X956T0J/X8JLnrNaZJNYZ4mce8LQ/UU4XeBt+hN9IIm5ox6p5sf3epv7GbXNU0m0xJgVOFkcX9n/SQ39xMqHMcqTNN5dwz" ..
	"fuHsN3hfbBowLXRRc+RmQmJXRMVAHgctnWwaW1W7mg2NWyjoz3PACeKkZrSxDfoq/VTeft8mMoFER6HGoRyejWfMoES41V98UPG8" ..
	"F7Zo2VSESvbFwO1977+vLFozRSqBKsZt6la8XSyfQHupiYVTCBh+7Ldc9BjHwyuZ+N5IJ1DLT8tMfTAzO5BMGn4EbyMZ6CU6epyt" ..
	"J8mZV9wCuJq3nPj5P2XnQqedn24N9+myvvXTNgVdf6X39HPfQ7ovgdna4pzwPApQDqlJvkeiwCM8/UUFSJw7hieJ/23F6SphYyFV" ..
	"FNKAHHm0/7bysCQTNKYZWACueqGEtXAiMMPKbSAj8lCUCJ5FwJMlQ6dGgzf8IfLAcajiLVF0uZ32lcNXs6d4iCAGQUCS2QvY+i9D" ..
	"9K4i+umrBia8qLXpXT0B52rBOfStTqyyN1scKbjga4e9lPIwJkhRSmWHcyogP+Jwz5lpPKmwqGP3ZDOFf6YD9XW3Vkb7eHuc5hD0" ..
	"X+dU2Lal2/xCPGFQIdMgLQHmkZsKGCCPXD4AjS+ZNiBpJPcb8q3G9Wps71Tlcf+7+WwmVuC/Uws4u6+jQg3+Vql9Y7c8sEkvZGOH" ..
	"7GqBWYrXQiJcT9bnL1ZtUa1UeDj+vO5pw0GpvrtMDxW2lWoB8gmfgjo0qriyxAmZSXiJ8GlRRe9dujGJscXJxKQRmdWtKjuF0oI9" ..
	"+YUGyvFkewCmAK/DhdppATXoNU0B+BrenODEEK3D75YlvvgVR2QRv6otqVxpSQKns0k3Tc77Lndlftypx/zdQ6OrftWK69maNp5/" ..
	"337pcVOuhnFLXlfe7wBSJmJTld53nHuloPGE1kFAYGX66tBX245vlDybJgPA1CpPp39gxendE5ZKu8H4IXAludVXOONKVq38Wgf/" ..
	"rS2ys4pePiKse5Sr1+DVSzmJMA1I88yv3ppuob/LLc6ytnhmzxcJtUOqGcIH05z4gSIFPiEzIKetjby1AyTYfWQ+hlnd/Novyfhu" ..
	"GXNBEb+ga6TOs/b629Hgf95dhAi0UYyu9z64dXOIQ1nCW585en+vyC06k6ZxbrNfxuCYuKDTOHkGW1BYYjrg88kLNAu67+313WEn" ..
	"avXXDik2w9tNkXXprvA7ZhSJxkL6jvv7+LTl3jf+BPz5D1HevIe5J2ROxlarq1Tq5Pz6jjM+w9cFQG+rYmN8uHtrvEXsU6EZYQu3" ..
	"EHQF58uWdzlqdnRYyX4UGSqtVPelt9/n8ex0gGfSJ+hyPnMvg4GVu1kBR+qWE2cfqUx5Ld7MeArUgWVmnvsua4V3dx8Dr2w1iYzv" ..
	"fDRMO0OBdftB1HH8I5nfh6kk9VT2SrpWhct4xBE1ONH7ZA/r9LHKkS3e0vZvvKmzxwmMhTy0VXOokL85gcLBvijWcfI/hiY69leV" ..
	"gpcxCZTwBKktmvBqEEI4FJtG0sQ2AvjulOCdlMTPxIQv43LzeumWQ8fdKQyDzkGkNFfjurYdJuDGpdRCCWQazCTxGbVFxn99WF8z" ..
	"M40Niivrt8VwJM4fyYRmCWp0F3EhDmc+j2toJJTr3B6i7xCH7luDURMhp1j9r4igR0RgWuH6ruChdEXGvHfMl1E6LJ6/ghJ+jXlk" ..
	"II4QIQtel451VgBbRbXqx5mIFYfgB65YoHtK6oFtJFNX8Nd9VeCa9dAn98ItppBPliJ0VnH/nvL73hEfHReHlbJ12kPcx8XxlYkb" ..
	"tgwWuVJvoiiLY6QagVvih4bmM+RJl5rse4vPPSUkIsHQb6UAaSvI09S4ibv9haNNkpendWsR6GipFwt12bEA9xiSFS3bfIcDLIot" ..
	"nuuZlhKye+gNlOhQ//Svsuviw4VqK9rDhdmN2RaClbn6ZBlLYwK2FHLzto4kqenFwWX5rQe90ZntYtnYB65bWjyLP0BpgK/oThI/" ..
	"ghHqdsYjEdO6xjJNglrjbEdCm8aIkx4u0tkzy8PJ/sCKldFcBqFMUgqGZ7n9ByicE20VSLdU3FFR1YCR+VaqhkFISxpEPUXf20vg" ..
	"ierl/CxrbEc3YZSpN3WePbyf6nM+WiIOkJhWCe2V8aFFUwpadlR3BKOaV5UpjXD4el1BlMzGjDiEiuKsbeto08nrMeNR5u7JQzI8" ..
	"9tbaJr8dWBAfq6D4crxvzrYrFC9Hwi56NRNjbNOuZFBKjS4dC5VOZjMMZKfV8flJwrFq+2Sjy1QSUlqtjkWRGzecEzhbg58Whdq9" ..
	"cLiog4mR8gpxPZMbPe3xc6xIGkR1JNgFlOR7gmS7Oe1qI/7xa5BKUJD/oILR3bpbo05icwPD35FGu/fJmz+jUYlR5zII5gc5dQlA" ..
	"KFv58DB9hMwa+6CKvUNlabw5olVPSUwKAIaZSRZPVBffca1jpO0SA3em3A04GA6Gsuw/ChmdChxU636yX6EgwYsOeMIQNW4KGzwe" ..
	"p56ybJ4aHoGdG/NZTYPxfm+KE4Mcsg/U1xBbrsAjp8rUgRgGgjRcTja5g/09VkITcKHjQch6afw0hIC3OqUcF5xhJ4WZpY/iRlIA" ..
	"rfNi6whFe2nPjstVwDDxcFTwcyFSdl+fqdLqFxdbJJE6Go47GZKp4A1IWBejMG1MWoZts4FD+1YunmK83dBF+gZZq1fXkovvBr4b" ..
	"MmZn+KNfAKI/7oXxffeIyeeY6HHouS48RiXfUFXZa337u+co5TJi4DrR4m13KD78UdbrI2KyUhdPkgT/Y2G2K2Uzm2zsoEJkrqN/" ..
	"zl25t8zxBxSXMme/YSUhbsTBfWIgbXcKdjWzIfLTJwZawa8+68Ci6vW3jOf0wFAVk1HXdmQJWTId/ybI8Rkr/urIHNiUxAczdy5p" ..
	"9nsS3AJ9U4e+MhU+XyIRVQv/E56lj4Ybza0wjG3XHl2YqzdKtpi0w2hnvaVHtdHhnfFJdxnsk1GUDBJSiboQ+hwvf2dyWowAzLsq" ..
	"jWmOmr0qy3X8jkggpfB+3Tm1fVUbjhZm9RktlGe2oa4XlSweNH4sFnKReQqVw/481HKukX8sO582fimpbwT6PGEdstrqvdAp2SaD" ..
	"L0Kyhrpp4Tl1nlpKDaS7n9jobUFJn+ZDeDIZX4Ufega8Cqqvq7c90QrFYOFHnbcsAESH0buh/0ELpVwADlzNDvIgYnnmvIyxv/SG" ..
	"mQ+3mSGPJA2HOzlU+fqMO1RPZ05Zjyma7fPibMtfjZet8jPLmmwEbnmTmBCNRb32FAbtM7xJwt0lx7q/d/WgOVZOiOw6AdxGpwi1" ..
	"t0N9WsnzxWRgjS9rRFPK2XEo7T88NXsI+gF4q4XTmTl8d2iQ98Qi9VNHpPI++xlBdM3dXEMLQQ1sI/xWFoVpQECZZIVe/cPtsdQS" ..
	"bhN0wIqSuWLeBYAt8AicE9ePjrUr0ywojiqLYUhPqad27KtpcMu2YXRmYTL5oxCJMyv/vFiKQMIvakxDLHgqmo2aPDqKu6hjtucw" ..
	""
local PAYLOAD_P2 =
	"BQK8Z78wFFVhXOi5EmDbnioY9M52x3X4wbNLRbRoCjYFN48km4pMUoRJ/w1OH5DX7icA8AKaoTOrhyl9SeH/YpvexBnUigCoDH1X" ..
	"jTnJZbpht9N8xJj+beR/MEjxVeME8dGDJ1kyi27bxIsBGspPYYXvGV4+WVjdq9kI5trDCMwN9nixXhObfU8t/E7rE36Hg8RNhOSR" ..
	"rMbKyJX+ZfziFyluV5m0sIVK+YE9KF2rN8FrW/SG40M7eB8/F39vwSw9xYszC65BSpF4IHejzA8XcNCiyu41ko/nTAvFYugZJW64" ..
	"VAPt95WkDGgywZKBjz753pTzI1eD8huyeigR0RXQxj+CsjwPEuX/gGqIng2iJmO5+XpLzUR/CD1CBjJ5UT42OjeqU55lhHepIcEG" ..
	"uYjcGe8mLAwmJoB3WAY4Ou51MFoG0GkcJzpeLQ7S4LhJU4P7+RqePaRLy9061U8eV4TJNdvx176fclax9GKKGcCQXGdT004/Q0Oz" ..
	"ECex0sc/NSD2UVNwDsbeQQh9GTJ5NXj0j72QvoAdFhLcHuf9tMWsT5uZg7slxi/CaPpwhq5T96SKyWTQTiKJy8x2mVRrpBxa96Xs" ..
	"x2xinNzWjaqm7LrmJQZ7ZQpAajOm2R7zl8+bFpVFt11FbWuibfmv8nA1iuZ6xEnBulRYCV8s1ngHMbhqk5uA4gb0kAj6YcM+Wo5I" ..
	"Bd7R+iStnerp3h2iYDLYgtETtjpn6xRwAnoTPnbYjYckfultMZOYShD2QlGfpfJEHlpceHTOpTcHAvvEu6vxuegJGVnNnDbLAdHJ" ..
	"qYQltvdfgvfOIQmutUxhhNKWiw16lFHkdzit7cAObfZQQUZ8S6DePXgRf592mZ4Kg3giyfCvUHLgfSNuS1PUrOJO95hQcxcV5iuc" ..
	"jDV/agiCUaLpefJoFQWNYhApT1SSBoMEztOGQ+tVodfhf4SiCsh4QzIRZOVMSsjCgBlOGeF+BXeNjTp2XAqso1EKb807In4lmjiW" ..
	"HFWaDg/H4MTV5KVe/xSdb8o7Dr9nWor9Q2bHlb+ZVBq+KKtvvQNb6tNoR5t8Q6uNqd2byUsuMj5n7CTHTFoCEaDu3ttdW/k90DgG" ..
	"qzgKMf1DsGJnIAEtX0hBLw+60YikgvPUIyWTNkoceUwNoR8f+dPFubvbdhvfaZO21kjrqsPngxuknxg80rnxsS0U2HA9W6OfnPcm" ..
	"fgz0Ul5JY5NKdTEmxCUvDego3i8r11WC1KWIsZ8HtF5CbQPlj0eiZMSmCEZVruXu4rha6a5VbDbmeJqQCS27nt45/awcxESMpyNZ" ..
	"aZbFAWU2/D6OmbNAeqheSvhfomi+gDs+Khtbh8Ali8rSB/9JK8pJwPWLLtcs16lV6Cfg70lgzKHG5C2HjFcZBMvhp6TeMD00hVU+" ..
	"UUh+yAHGmPvez2xOjFViO5ndzIrsN8LI0hFAw9n3YdZbH4f9+1kuL++C3/WdBp/tM1f9jm8iP4v3iN7hMIH9xuAs+mDKoJ5Qtu4m" ..
	"10JeJuMsP8mInzcqMciyPUsjj/5KvgPCO69n3juzYKkeVUYdhiF+/0jtvoXbA0CGh+FSM71TVQ6pQWPS625KOAeMFv2dn/+StZ2q" ..
	"cY+KCKPGi2vDz2nDPGe8K9njG3PuODxdTWKVbpxNBZ26rRCGuNqZjNXx6aRGVY0lO22g/Sj5lPUJYd7eic1AHJqEcwCKk9YXZu+R" ..
	"u/hfH9hULtpKnC3jyVSWTtynKlyebEMRDWpMmFD9MqecOyJYtMPA4WHbaAnU5NKrBS0LZGns/0b21nAihXHAYE9kUuov96Hyryuo" ..
	"4/lr3F+coTWzMh0n6cDyjcZpTBsxWycK/5Ren0H4SC8moV7uyG8o1Mx59hlrqn9xih4QoiEpH6Wn17AP0tmSdZ+JNdCFzTaheQpF" ..
	"J71iR/bGSOm0uVYX5oaype1oKU3jxLwIXmK8JHR6JHX2w7fAb6HBFB+cuK2RhXBBXymNIL33pZGukJK6/PyMDWkTA/9gCYBHjsef" ..
	"2teI9/0IcYx+oVFUBWuVg/kgTayrEUblr3uP/0GVALMxX4n3L0pN1qjcbUxzNpvQZuRWAGb0XmretA9yadb7IfGIYL/4hHZWnMVv" ..
	"7L2e2ftwpT/GiD/Z14oZk6Muvvv4tbmnemu/24BeDw8VZMQm6x5QrRTNeD/UQEI8CFhRnsfTvMSnho1yDOsYQWL8daXlh61qpqxf" ..
	"Ep3ushAYWi6ZXjHU8ArCxxiZ5Ba3H8BQ0Gzvsd1tvOXo2m2191khkYiS2l9YqvvFFjs1jCZqGEvTVxJvqKt37/X9e4fpwi9sOK5Z" ..
	"UEQUp/z4gSOMW86qIvh07B5WBstn0QL7BuV8CeYI6x01CKz14OjSamIVx2UEgURKZk8V6Fojd0V5LmzL80UVhH4pF8oybgrqJlbw" ..
	"Riizls0SepymHVNq/su+EsvZCvyAOI1iGsjC3yHB0wc1gYLGvSnoqV1pahhylQp2MCcszu1XsCKuZtxMJ72l3L6hPSWIiErM/h3Y" ..
	"KwTFnDde2jhfUKvksm4Y9r295cUOOIXzXQb0Cq6qBZaREs1QpJDsCmRRP9g3F3SDR+iGINosXn9giSN7RQJV3RqAWISOIRenPyVi" ..
	"hL0IKivBQMdpvt9KdQDNyhp/wuBdiwd46EpNpbTnOxSa6WR87EtYwDjjPL8o8o7gUUatmJ/eykcQWW6avfFKgkZ467UDxxVg2AmZ" ..
	"ze/1j6uKOX6eGpjCKgoC7aXKy6PEe2a4K9lQtZGcWGc3uRysQh7ifJ8Pwy4jAFA8fgeRVt2x9/vb8lGFHF2szmcz5d3Gi/bX/dZ0" ..
	"TPu1xG1l11GSGcXVT8VDKFja65Xrcg9d/ia4en9f5Erz/GmBzPQg+fZJ0fCaBZm3iy8TXR1mn4cRQmaW++FDG1Ekj/vThttEaLQG" ..
	"Wl4lEOOCmsibe1waZnLlo6csnTD2aXg9ChpY8V2heRKGN3B7aKwP6SVevor4YHioRtJOTsrNKHm+iRg/1ysPu6EitpYghY/fF1N+" ..
	"shcZer/Pv5KanZE2jHrWPO9GGDDhHNwtUrxAhcoeGMrE4w1GUozZC3viDoKLDEVnBkSP1Tq8c1/zKVw63hPxHm5E68xIZnD3nPxB" ..
	"7BM+o4TJIRG/8Cq6tYTuRwF2kMSnjzggFrEMuJxccenkZq8qTHXqg6Uz4z0kyFHz0kvEm1+ObddqvHzhcqDx3yQGL9Q9J9ZEVLI1" ..
	"3Oe9uAzPyHTxcAZgC8oRAme89IId3x86i5G+Z0oPg/OBisWPVUe70UwrjecU/TKMFAZUwSSfp7XNAGcElhfQPm5VK+6DzeRBr7/F" ..
	"i3i+3hCzrat7tysmxoPla1ppwW0NBlYXmLWIxmQXxsLzUoPwJqNZSCIwhdjHP7SBGn1kpQo7AMjQlM+Lb+8ALjKPQHGIb+NFZWV6" ..
	"I8u7UvXBB9il6uPbHHs4YPnkvw1NN0OoShL0KjorXSaDEQZj7I3UArGS8/AcwlwS4fgr3R32dAmSaD7wLi+wYCBZYRUUSBrvqigR" ..
	"695qddYI2sS8Cc+x2sZQbsyVm6FUvkS00ROSPgOVETxDmK9dNrtsBvnPogZMJ3nKUtdFqC9LJjkA8S5q0/XfbFZRPxfziF5o47Iz" ..
	"fPEeX+/2ZI2tfn8ansSk8qj2lvOyYJGvZtiIDs0KmdsteuY+xgkC/ky6ZWHbB+NC/MBBuzOmAydVWk66RqmcLic/h3SO1WQDLUq8" ..
	"sa4Vh56AcuZV4c4zyzy/KvPlxjfk21RtxU0ZgMQVJtvHny5a/zC4EWnGOaya9wOydqnSRYDDzepjx7CUmEJpLswtEM2komp00s4B" ..
	"v7+A7veBFlFx+ipuGMAXATjYb9PDeKp2lem/WwSZ0P7xAcs9CJ1Dm5yQSR20+raEEVF7C1lNVmxkH1jDxQW5uTE1UGS7AqhMYpE5" ..
	"izTYjOjhz74AoSTv/eVx8JOf1zVX2ry51DUcQPZ0/M223MRLj5IJAPAb7+NzT1VoPtUvG1rd2Og/gZY1tn9J3zB2NoGRtunbnKNI" ..
	"AaJLwxrn1cLN24gnBBtGPqP+zcvPH1l0mAk9vINWVpMNmplMQS8bgTWBxm4hXNvza62d0W1Tt12amtB1LCs+WnzguGqlxC2WkWtg" ..
	"UA2uaPIVL/T6LTGP9NXqvzeU8tf9xiCFX/iRUfLzfPcnuHMGz7/I+66W+ArbV2qc2rl5Dkw8xy5tw8QLTEBL4Zcj7VXFIaloMD3/" ..
	"IlM0akjBo2aYI0lukbT2fPuFVbyuY9hFsir4hkszb76INouOxrj9BelI+H1Z7g8WkobApIMRe5ExQAGhFh6qHuw26e+O4KwFi47j" ..
	"aiIhlVV41h78hnn9hKwe2mFmgO2pJT2EwNHEMOfEPGQUAqLZTZ5I5BZegmVyajTKUpvtP4X2C3LeA+86a5EwQ6U3QXd2TpwAi9vt" ..
	"nI2to+QNeSIvP/VBTtdUhVPzVt65aNabOQ9nH+cQb7qFd2PycmPe5RflK/hZJzPFh/fV5apmgDTgVjjTB6ORiax6Jt2qZLbdnegQ" ..
	"IB0Q8gbOHcvvamGTmE+R9XvqscWQJ9TpBpTAIQ9/zPs2OcCXuMcXJrjpcKT1oHb+QUc+FZ3ntgLA+nr32hSA5RRJZewKFtWk+g0t" ..
	"C8hcWZCzzvPR6svv/ePlQj9K8xGp6jEF/cBuF2N/yB9NPmwPygV86pQYPWcqNT8QrOoQWbW88bO48sssFBqKEjA6dr+zBh6AMVB8" ..
	"H76CtW8x7UsgGak40T5qySFO8a6PXoIfJNS2RGWoNdi89A7doI5ymE9p1GXH2kVd6RClHmdrJseaZu8jEbUY7j7DYIE+Xwjcl8Ss" ..
	"1AG87V05D5zJacV3AdSmj4Vo5SFCuGYx/MlS8/cgEheZGzo7Pdv7OZmPZtEZAtxP0u949lqPrUd2Mb8EYobRP5cCq17YRe54Ayom" ..
	"WoXCV3TnFOcpQWhtJyvxDj+WrBD8xDcDPBer11PapLbDhTFcPBFLojn9RadWINf6+BAmF9LeQmB6lCTbZd6Q1fXKnjLgh2vsCJEK" ..
	"rWs/lrMFtAVBGmKITsakJMXOoYzYf3gepsqTIxmzcCZcH6yYnwZM/j5ipmeHYvwf9bOp801jcM5OPXDW1f4Su29up65+UNVizgrt" ..
	"frHo3kP02dh0zIHR8ZfEcmZD7BU0JEUj5e8sDUj9JcEeSMKwg+FcJZMWwNlRIRlHaOeU62tGdiRBvx6lEeBNYhc8APPyVU0vuPjw" ..
	"F+Njy00F8yjSpgdi6eJE+MbV0D/Y/xz+49Z3PXiw8A67woMH94Fo7Mp3E5vdnLk6nM/6tPaLZQIC/bgj8dMwRHvnnHL3cJDxheqc" ..
	"AFkUn2T2xcJnzz2LTxfcwHt9hsonAJ73jJebmhp6v58PYdPyPL6ndRVOVMPQHP7uvrtysrgkdp+tEyrOCcfs2Wop+OJ/Qb1X7c6t" ..
	"ckKxRgmPTUF8c5XL2AEGWZLzSbo5YKiduKFgzEljOXiHIumhCrLQ6n8xkX/H9B/z0eLld5nqXmpbBcp91f/NFpSG6Qxe9xVefCS4" ..
	"j1N5cdHf9G9ggoR2zECQaCAnkUkClnSDGzr40sdE8lEY70aTkH1N3TlrMu/WW+3CMSmgWVHu5bXDM1CvLxSKrLSFgghFw3cgg/Bp" ..
	"QGXcY+05w0gQDOHE3YhAxomAP23dt0kKNvu/PIKkxlOc8UFzm1nWJpCHat+nhpDMgvE0K2cF85XPUewo6QGb6z0QOzPbIDsdwdOq" ..
	"Y0WYIgKp3EKTxbrjG8RhMaiUNzyirFm+KrcOD6aiaJiUTRDW1quxyhAFAgxHQY+LNCl3WXWj7OEDaWXUafWXypRa7h4WEfQyuo53" ..
	"ekMuBBYpyK2XmT5XfuvEonA+K0x5tsXPmn+6zfcLeKLpZSHf7q2FTbShO2erEVweuUumn0CXiOJ+tlDaqYWsJwyNF66xoV160L/+" ..
	"QKHOTEsWMsYhESzFoH4fTp1dCK5wXMKOqbTIj+WwqnRGUNYAxjZCQYDao5FzJQB+wG1OFNt3C3BZzuNba+ACx31vZtCHPQmVM2jF" ..
	""
local PAYLOAD_P3 =
	"/NHWOEC9emQH0rcTKbxm26Lw1YeKRB6nNVFt9/U1MUrEqS7wQIosCg2dKhp5+Z2ebL/UjHvninwmDK1NPW7+pz2UP/5UHVUoWify" ..
	"7tPBJiJGuJZ/fsU0hwduQ8pV48h5pTQFZOF1b417+WyI6zG0kDY3k27CTm9zsUM9PpJJGPdlAXGIt1Rcw1CexCjJU88MsLWwoWvs" ..
	"V6GwvmMU90eYNC09wkw3opYG/T2BeFgDeHHXkz/bVo4hnWF7oUofmjXLBQfN9SZ2Y9u7oOB1IrbBPWU8TWeGW+iVMtEqU1mHS6TX" ..
	"PJWdtq2CSkuqQMmZoyfFjHKDxcZiBQqVR58oIDfIxZCqugW1Yw5QvSefH92Yg/YJrP2RbXw6LVPVzJlCr0DHGpQphVYyvUHglw7V" ..
	"//fqCwXLoaB/tSlEJ/wXHxkbw5j/c8Js3gYJ5jeuEX4qfBGx4N51++iSZznxBOpkIeGz/OJkI5otEZjHwVE3mGQnhcY0aukd1T9U" ..
	"xdLEv0rxzl6eDjZ9jhy62LWwmLipSgHSHFd0RmHkEl9rYoBL9bu/rK1m+N73ZdpeakfkjYW8cG700zEHhFqMcnIXCPPZ6HaaKE8i" ..
	"tliZF46RwEh6Tq2RFZJlWU2Egrp7jvK4xPoas5pH78w9vdRWBbhf9hpvCRFxiq2N86chvPQDygPpR5IuKy2pHZ/NKBRdjUl3A1Yb" ..
	"8Ep0aqGBN3PC7YnqlVGVAqBn5zV6vZTZXbT9aK+iEeqD7iMv3equIRx4U5Ic79P++tZYaTLtYH1viA9CUf78G0AHOn9MLExMCatd" ..
	"i9J6IEv9ymqmUZQ+M2LWpauLy+aeeKH4Q91a2hZ8NjMJBtiuS4tsQLME15pJVMzjDetd5qMVqNwJJaEDip7Vf5aHA4wNfFj2TSqv" ..
	"Z+E9FVWzLdRpjXgSmlV6wJuu9+jRvVTqDVAbCtyBPpmhywpGcc5BG/IKo0K3s2vZAmcPVaRvhe+gacaz1QGlJ93+iHLLCXWp1Lr8" ..
	"j+yTkW0V4hWBujiVpgWW7jeDywWyBBwWWisPgYDdo8y0stpCknNFULJhiVkIc8xzewaTdpIoY6P2je2+YyzP0Rg1+BOXbL0Im99c" ..
	"qNHQMaCkNoxBY81xs00zKjFe+vGObILZdARsWiqccCb+SdpaQYnThzEC+HOwYHhmbguI4wpRH7e5ThfGVvE9ZPIshmARmFO6V6By" ..
	"m5WFWtTBSlHVNhx5nHBD3rD0t6ObOBLrA/FZJUoUn0bU5FPZjXj20bD/HsvfqQtqFG9pNCE+Vbx3kpSZBDYiAZM8+JTmJhvyhKCs" ..
	"yg7BkI1Ph9D2jtXYCQzCmX3uTGBl0LFOFjClWaVHR8JKSNTpDfqB0PweX1rT7pPoDXT8afvzSWAcDze6A3zKrlfCPL/Llz9q6Js2" ..
	"XLjygK3/r05zdcZxun2UlUHHZn2oP68dcX/ggu4RrZRxgZSECl5QkkZERg8irc9jz/RKH49ZbR529lrwEQO3RNdxV4tDzLnsPvKI" ..
	"EbRlUdWhkF9JGAJf9NsG3AHkkCcBbVHpewL6PqFreWtLPfi3qDVnP5ojYTuXpH87h8TeP06rk7VTdmQPy1FHU6Z9/NUhbzzUNunT" ..
	"GDfqF/0rjxoZgnXQ3FgscKJ+oY598vz4DXAggFFyduH4HY7JPdU5zIkVRSNLhXXMOj8SeJ9j/yl6FPGfy9GH1hE90zUjar7yK3EK" ..
	"pnnYrjsMDOBHs5GE/c9ybt3Bzm3J1OdMPnoJTOkKZJZ7oKkbgOHLEe7CbeX0TasulxyGhEfMfyj3FvQ7TQL04BHpIYu9aM4AqrDq" ..
	"J8M3bmQkwn3HuW6TqOEy/4UySouyp6MNTl8D8hIURGgH8ZexeAJ/7MjQ0nxYHyyxuV195j7VvpwVfWk8GIomuUhJ8qa+wJowdlfa" ..
	"IOQhx0307UbP8OC6N8Xor/k4zqWgSRiiyJ1oRpb8uMyb9WoVuncAoCsatRIioXz7Kmw7TdZbhhBfrvChZ0SiyN8SRCXAYpduRhOl" ..
	"RusW+gSDpyaW8tk/anm3QHhOnSVFq8LmLfFP1+9CmtPLzXs7etfHup8abJ62pkNfHMW39RdE65LKg58npYnT5sLYShe5DkzJYJvX" ..
	"l3BIHmt8KFRMVIUCeMyrPlSGFsaooVMOjtHusOUYH185dRYEaG8k7R0FTIj/b+1u1y64RKCZ1xAz0W9TW7dyO05E2qYV50+7dySa" ..
	"cEcg5ls4xTwaYDVmtUHAUQjte3LOBHOikLtWOrbsdARug6QoicFWkGAEZ6vGoaqsodGg6qdep6ZJt9qZ8TfQJkQHE3D0u5FoFdUU" ..
	"5YxwZ+0rGLkdmdZZHqf4sMxah8bnMBrEjHKLqOP5qk7uX3SMaMDkaPTXr2+OxzUx+vW8JZX+lWT0jgel2ilBUw7aEmLnvquYmOd/" ..
	"80nyTU/2ety3THEoBwJjr2Dhw2hAKyYfVWjRZINbOM4tLtjcoEK06rIYaHDfdVU9GCYphyUVfCvRnuAs/AxjrOvH4KMPVPaB7cSE" ..
	"3VDPh9BiszwtTnZ4rcAuu2on2RECIG8xISlEzSUIDYepogk8EO/AzKCyBzPKT+vMC/ythHiP9RAy/1soVH8OTLls+5fHuYGW0zJ0" ..
	"Uu/CJArNKVU61wTyH4teho6RY5wjIrmc5HSPbmjJHDUHaM5afLOgiCuIZ8jZpUfErAb3maV63bIc0LrArquHEKAOy2VkRmg78uij" ..
	"SN0+WMqUOdSxYcWSq23LcQHpolNldpH6H5lG+6ZEUVG6m6PAFw0klUQpN56WWJcuy9Bg8+OUIX93C/bIWWfuoWRAzugVtdLnVJe+" ..
	"GVmc83RC1+eGEBvPHXsjze1YjwnuKYpXqLyuwKY/xbRQQG6TSzDoVDWso7b98GIkMW3n2uc2R71pRFT5RNam9IgyPF6EBawE03p3" ..
	"HKUG0W+/tLFjNNP5Y5xUWOr/3UN5HBrWO9qe8ELy24XygyFBwuzAazUhlHBcaK7AxGPu8HrZK3IND0mhti1+BtLKoR+J0n1rikSu" ..
	"XoepfPflFXO7BDYGkNCa3BGqwhs/palZFRhsTZw1kBYhQ4FqqiD7xpke/8+ifaINxwymPyu9h6DztU9UGt461zm6nxYmXBc9cfi/" ..
	"Dg/JctrltjB+xGiJOjR3eZTJVEioCZGV1EWPCwXiafB7VhupetrnbILaHjbKQeDS15RY2WlE+MdyCu+0wUOP6iAnGT3JeW2mWepg" ..
	"gLQ0IY3T/o5CpK/aebUtvTPzHibfIsFCCIvSDesZYnpgdwdEhF3NXYYWiXanmDtej0ZJuzlhr00Kyz/Fe6q3CDJEATsVm0vr0I6A" ..
	"3DTbnliyxcjp6AqCcAjJsiyCFpeVANWg3HAMysH9/tgtmGmyeH13uhlD99fWpllpu1nCLH7gJflhFloGsHEidW9xB4WkZpyCVLf1" ..
	"AZd0tqrzTPVoX7ChvMsgmMeezmGdPpY4cq/aJXi5g+0SFKQ6TUrUYeGlDVU9xFQCOYk3OZBGTQN56nI874O+2BX5KaB0ZrvxtRzd" ..
	"+3z8IRHJDBVmFARwgoXnbzzvrhxF51YnudsyMxqkbGWnFfTnxR1OYFCDz3HR8eDpc7zDhWLTm/GJdNSfMZbr0BlgGJyRF/4ItL+b" ..
	"oilG6vLz0lwoZNGbgDn9+K4/Y73ea7b5B2ZvyWoTJkECKhOrneg7iTnXERE59yiP6iWma/OsruOdImIISXV2wL/gvkvx+bkNAcCh" ..
	"iLYQQb74s/O8oLuKGPKE9fG1k+7FxakIPiYH8hOc3wleOGxJjgzkPyM2ObyYysedN5Yy3JSn1lGdUb8jpamCycDBCS4vv8k1AxQL" ..
	"00RD++68UJfDmr7s2qbs3lki3IS0dRKkNv8FUQQbsb/Xfo5mxa1XI/DShTZ2w8WQXawEDsHjc7pW8Khy1Vz8NEcsVlcx2qXBBwuP" ..
	"oO5rJnBZGR2ewZXqLRB7TpBn7QWVBVTgNyy4rDfIUI0dtLgC+ws5uM0z5vU0VFIs4M/P+UbPNKg0NZStu/caIQqgDAdPUgp4w2hp" ..
	"5wV4QeVirK9Qz435dTcnOf04qbV8oCdwh8+EfLHqm8QmAG0RnIeMjBvno6xgYNmFccEQmWuwfE2oD8jUyQZoq5vpOXvVeyAkwkTp" ..
	"4voliStAZPuuLj7wiJ3afkyQQJy9rqe67mm+PKgYe32ysuC7PeREp6/yCUVtoLIs+1TgrnFcBjP3ebHoPGDcr7n6SeuWqkUxrVL8" ..
	"iPtCYxpUGr+ZrMasKDb8IpTtlBVYgMNGQrgioKJeAElXrSrl812irp0roE5RHg5/SWuUgH0wb9k5PzlAXrNXpe/JqJ6xehXB+7VJ" ..
	"sYmKoFihXAxoeIMTgzt1b5uIb8qFAG9ang31PVr95MFY09Sk358x99oe80B7+WLtINgHiX8wYVplasPyMCWXL5W/HEwbsY1mDVh4" ..
	"eoYCORjsx6Z7re/dXjrLvneU24aocVDDLTmBCxNWoEYlzsrZDs3PPlYqs7xNNiCJzviR3iMrwZPdtx0RnbsJjvKZ9Re/gJj9ZiAF" ..
	"y5yqq5YcSTuqnt/StO4yeSeOHGkLyJ61EZF84kNEItwRZvruunzMwymEVm9S/WAjYLa1sszkzp44+MVTi3ZmdOYMjU46GhaHG9PI" ..
	"OHw684Ss06CMmSzkScz54ojEsD1NYHNPXjyuORciLHFfPTIM90LJWQxs6b0hrOBralvdIV73vMNVVGY8Ey/oiF4HL3jsS8vW9uKJ" ..
	"wE8Pqr4yU2ELSEVZAC0KnqwWfgyvQYl82C2oHOAKIYDCLPYIiBl3yoB/eJPqo7DTs5kP5eXMmjShDUlcARohAMfv7DF3d7M4TUbr" ..
	"SUxowjBSPQ1437d0miGICs+Da1IG0hpJjEcYC17ruipVnKUDgG/kvs0nw7uvtEvO4lm/RbbThGzEsfqHY+hGzvK39j1nYLPxBQuL" ..
	"nuzWHYd8yb7IGZLaFj1TSB5hsOew3lhEu3XDew3iC7oN4k9tU8nbQYNF6oJRjjNDpQLAmUVUqyc6j0QNgvhkmtBbjgtosQaV66S4" ..
	"OhHHoZNpJUTxbB49dmcgBdmsk04k7UCL/9DMIDTbuYDwhyckZX/Z2VU0OoMmVMNjuAMbBHQ5jog49GLBu+vhz8Bzf1/TiE9Fxc3r" ..
	"ztwUAkaCwV2yOVemlrZssCMWnj4NX0PrCFb2Fkwg09AClsm/sReZMdm6DhgFtL9vIfy3o2kbIm2KoS3oMb9OjGrfbYMEJk1xYfpr" ..
	"WZ3o3CYYybvr7ZcvhYT6zjGnccLH4r+XzPGtpytljTstYgXRXC59HnTNFf6EqzXCeRnEBEKB3nIkX5L4yuaPC019xG9GgfoQ9FhL" ..
	"gMkMoc8GW230YLnLFW7/MnsaX21/9XVDqRw/3LkDsQqBqdKEIuPZXCdr4AuyLimbhsf41iMj+IMjtQQ+3qHIsGfoGXE5jOYqOyB8" ..
	"eRhFwG2L33xjsjseRtT2obmBzcViKYnjlwU6M2HjRsfer4uQCU0UGs0C4wO/i2jjRlirEyy8Pl7Qal66YcgmJy/7oY7ow4Qj/rAs" ..
	"oRkPexGO1yluzPiJQ6WLTLrHToTsscYQm/s0SsVS3bVWMtpF3HOii+IXa6LI4fXboLJvJvh51HbJ+yd1GNxu3beBxdzvLQQiT/Xf" ..
	"2ZM5M0gPAOgSxmtZG2Qf6ea815DTGU6bvoWZPZMw8AeIh/wV0R4HSLgoE/P2N3rMaR6R6yjnDfP7+DFmLgJk0fTZac8pDOG/9D1K" ..
	"r/zizrv31V71AU0ecwl9Hul8qHIWIjFjbmL0lpC3mczfoLLLQqxxTDAHFYzoAfx6wx2o7Joas40Ls5QUJDbFPWYaMqisSHCobuHS" ..
	"yT2xdsMDFhZw+DIzBXfwPOEhxeg6qU97sRe8TkDQp7lcYwUy/hXlQtBW6+fQj8aecix9NkDQ3eBZPY5Vh1hOJiWhQoTidOfWS3KO" ..
	"Er813qFuk7KjcXa0Oc4h3Fy3i5BCZ7niAXH5hbo7lzOpUQr4RPLRJ4HOBmWDx3cgdbEKylgxv5fur4F2B1TnypBovbxQs1f6d5LB" ..
	""
local PAYLOAD_P4 =
	"Cfnc44+DbeXRabIked5tYez5HATngft1eSRrlvneU52OwLWM8ZzvmjGgZTMPfWuNXRdey3nLiehzsnqHSVp1jUVV3s579xaielNT" ..
	"dofRU2cr/wm1ehBS895s/4hzi4jaF21Pwl2JwcKSbB7SNZ4GJSeUQpeTWaVLO6mTcg261asIWWdFeI4/kADO9HEXt79Nyy1TcF8T" ..
	"FACeM3HjieoswXDu0VDr1FZ7BcOT1y5+NthTMaCRaReZ2/51lRJIaTsKJEWVxIe5b5a2b9sQJOe/quVgQCVe3VJJO2FTCK9FkayE" ..
	"0lJxMRAUjYPihGrrBOaebhqeIZRZZIc9LVEnUHCQhl4Zx9yh83+S5pus9SuKYt55BrGCucd0BRuHMJYhQbLCIZtus9S39puhvwKZ" ..
	"ZmgmEsLkDHmO+NmoZfQoDadYul6TT1af9kFOKY/ou96UFqNSTpZUwO9TKWeSL8EjBn6QpkjErCw9V2d3UAvITK6llSBwDmKG4V9m" ..
	"PX81Ifo6U0bHzx7BEJm4lxBfuifzFxmhhDpf28GrLtSdvDe6heGwCXpt8k0iKqHC7Jm75s6jnApRmVemhRpqfNL7Ala0VgAgVXZx" ..
	"v7RZ+dGKhsTbqKo45r1bl7sj6DCPl8G1s0uIX7ErDW1lZrXuF2s3urPo1C+enHkxDG4Q202FeuQGU3USWkc96sIZitygZevfO1nt" ..
	"R3z7nOEk2cCZbSdhGXlL7ZpZIqg/8paQkca5XFYJ309JAODyliqKz9OtqZ+ocs7zv2mI4Pvz0L4ndnGwCSV5Wyb20iXaR4Dis5cH" ..
	"Yt37qu/pLwylb6qKq2cWZvKwgMjBA/Dv01FLM5egnY4A2olC0Z1RVldzRvVCyK5sVEaXP1MfeHLZp7hHcWZF7VMjaxuce/tW9Mns" ..
	"f/hzdGaUMxQITqHZq4y0GNpNZgG7qT806341+yr4jDCXijLdsvdImTzDxE0S11aZDfd9cob36NqRKvTi4qmtPR3rgCrKBtB83oB1" ..
	"Bz3uNybnJoFlv/2EkG6HfWQNAfDVq1GSNpsK35hqbFm1kjeenfp8z8VjvbfA38TLgqiHY6uG8e9MJz3w3iA2acD8TR/jASPJm4gT" ..
	"hTwxcNdpemGdYxuFnBr8odjofG9ZW7r8n8g3vEWbXAgv9juWgR5ypFK+sTks34xrHkxeQ3BGmDExgWiZ8J2Ldxlh2tKTnlJkLY0I" ..
	"KoI+3rWGAhSFwOTTZ+EC98g+XnLCY29brNDZz3cP8JfXgzMX23wfOypK7KsweW5kRTDmi3JEJOqNWZcjbmNkxq9XvrIrxLRAU2cr" ..
	"TQ4tkiweaCpXqGpRCnjmbNGD/gsoI/cHBJJzGefZxhopmdyN56f6YA3f89QmjjgqlT8SiUZR8THXoAU5i6C+fKTDpRTfUfQfJKA/" ..
	"ZC1Ztsf8WvibECduPpftBWeyZXgk+ODEoqo+LxqCq7TWquIr6V4Dcfd+0lFiuJsv0zVxmNikp7eOoFgZ78upheSCUZP4lJH38tnv" ..
	"knEngQmQuTyTN4Qn1zuXNQH1h1Ci3z7zw1pcGaObGvLmS4dh78ttnBCkqHVkKC4PeM8ggWS2+kpTABGivl9EOcbx6XC90hfwXvkS" ..
	"ijv2NcqnmACsfM+mJ4YTsvcmZai/Mc7v9Ug2hTdnGwC6NhBTxdIN1glx64lw8okpDAx3QvoZSbGZmCDMpFXcU6X7lKpB4LRx6rIC" ..
	"NwLlNFBOVsfyrHlIYDc51jwUpnsnaFk/IY5wu27rRSuvqRU+UrnN/XiiwJPT+bsCx/a75fG1ymU9p2ds93SAUaWKj8nwpfCu2kJd" ..
	"pBhMg4Da1mgKiOq3yZE+D7hrxRVZsp6A4PDW1AXC8UWO26dj6PYeHkYt9Gewr4YlYw/iuSfBei4oA9blox07/af4z5cwGADxcHec" ..
	"fgEQ0/xh9zXILNITaZ33x5tQeRt3ZRAaVYONMS+tJ+a/0wqXatc7CNnH/cfdLx72LY5BOCohSAGAZ3LruTjpV1zBVGG9u0u6xNrt" ..
	"RXo092G4B0DMbMR4Cl4kZM4RR7tOiNjlODsvAZ/CAvO+xk8laiBCDu4fcFdSzcXEtm52MCHKhdVwOoedkBT8iWbQ4P4ycrfpv0a5" ..
	"RUUVkSDkaNh+BSgRF68YAcn++l7b0NbqipAN1aXI0v0bDncM0TJV54+jfZ0vfquLaDmi2dqfS/WccanXMqp7beFqElZYxZ3TfnJ7" ..
	"6DOm/J7T468uPinwQ4JmboylBlVYcpN1Iiv0KurL9k7m6P7W52UScb1GZJ6o53aLwEYc+9x70pad9CoSbkHCllRNATq14AemYhty" ..
	"6c3K8kqFdj/Sm51aUAa6XNyVCOTfF5/Z3MYG5tZBpq0TIDzRCwX4Gz01jTWUeQuQRIZvFquXM1a4erohR/QNl+AQ4xajsrz/iQ0J" ..
	"LU7J/OJ4WzpQOuOXkXtqBRGGGk+cqXLezqtfOd2ajiGQyBu4ZoMiRuXgGHZ8Wbia4Jfo2h+YNBpUtSy2P80Oui0Km94CYWdSYY01" ..
	"Q/tZz7LGd5n8US4DsAqN8UE7jbzBkiNe1H25/+388jA1+FVQvEX/P0UWMO8ysrG8ldA2xGbQxKpTgYu+7rrh2FcUqkmylZdnqooT" ..
	"PCxyNUoKJUdghr/7PKIBxa6SVUcvTsWGmyPNQkfl1rHmJe7Jyucp5tyteOu9Z21/BOwD93kEMR41EqOiesZg+B4v1GdaHcqI60xy" ..
	"z/FHgTg/t+a1X1RC42CU5oJg6IppwN14YxMKe1onGcWbRuG4GpARTbwIg0a4mfiFFtpZCEdsu+v+jMWeot98NAKylU9JsqWJNOkz" ..
	"j8dnFJqUcByBpxl765/65048F/xUoy0sliwEJ4e+VuAFdf8w6HsXYkObzv1Vv+Y3hONbDuNeXh/pano5OqMBQlLlhkI4DTH17rAE" ..
	"KQDp4gmkEPoLC+3n4dvtPdJELgOBG0xAK7G/2kdSn8EvCzLhxVv2HzueYGK0Q3Hhc9sAnKon9qZU4JyeOv5vCVYNGHxTYBV29jh8" ..
	"nBRP68noddjdditHdNHKKqSG9Lj2CD6mpZPVCoMdrZUigQptvnW5odF2/b2IAE5gQBsKDbxE4zUm7GZs06FD8hH/QYAoMH8r/DeZ" ..
	"GmEcE7nfYwdTD8ekoT83zhsNH0XPHnvrSHnMdGNv+roaoueLrbah5GVwldf2MCgSxU1GIc9GYTm5TDbGnefRcG2xQzjkELnz2bj8" ..
	"4ZhBWP9SDhAdXFKvk96U66ZV0e/W3PNAszMtMkWfSfLCR1Jpnn+/uLs2yJgQ7ZMkMhM/rvN2zR547KRfQCNucZD+lQQojgW+nYLb" ..
	"gbM+hpTUPTGCg3aKxWM0EcPZvpQxPn9gihCzwZC+6IqtWvsBMNZn3VBiHDx/mZz1ny0CiP62ULRwu5fkoy5Coy4EEenBuLU7T/km" ..
	"lHSvSTkE6rUTQ0ZG0To58SjJnzf/TOTbjTxyqNH3Tqsnm52Iexn0tFTXvIoHKgsR7wOortRFlnSJp87WknV61KdBXyRPzRwryzth" ..
	"9+JsDwnlAqDT2rTcUIaIpJ9sN0rYfQm+L/XIMq2bsv5gVlqYVEoia4Txukc3Tyl0ur7AGD0/Mnfd/IJkdTLb6+6rnrD/ghXdtXGT" ..
	"R6TCA2Kz+wpu2JtZe8wuRFMe6tYLm4xufd5io8aYQKFqS+2Ud3HMZfudpVwA5XeCVxxNPadu72d9NGppyIqfMohCiNuyk3MS0Bxm" ..
	"tj+hJI8e1uAdUEPqilhmdpgQy6SbMSegTIcuTiWoZ0+DN+7PelKEBdtbQWKg3Vd0PdJB17M2Oh4qk2PwmjSBH8g1qg+3I/PY2ooo" ..
	"iQCGvD7k5VVsrHh7Y8oa0riN/+Cusa1wW8KXrnlsSMoeYsvjNFPcwfKd+8kTNl5BEW5xhjYgSBQ++QBoCQZjUgBnlvgJepLEmmZ3" ..
	"FyZhela07/kPshMy1d/yCRHtTIVpfEzrOh+/PgsmayGB2rGdWugGgvq/t4GkReMDQvnafKX0CiRjzHr1RApcTcoocfIBguo+oZKA" ..
	"x7dOELCVqmdNBYTdG8OoxlEHoBV4Xa0Vt7A7335l7ZDa3BfNlletyHT6D7J0vq+sqtOmkBagGgxfM71LWQul4Nzz8b3bT0mpgag6" ..
	"NIyQT1P99yQ4GMq1BFwcw1dAfbetEZBaM3wP+EEc59QfSq1ns68GZnuvkRz5dcIgb0bVQBWpMjYTycN1E99KWErXMAnxHkCYczP4" ..
	"33ylvgXGcGxe2QN/zPZRMHLcMjEyWswa08TkhZf7wGjVprxTELueie6oBbipLe4dLlK5Q0QzpEl+ke2Q0lEFC9QvYwbzPI5lyNaw" ..
	"lfkMvHbgEaXtIjae7Lh04MrPdKrDcsxRc6u2ICXYJ1CbkMnNVpazXQecXu2BLzdipvmCbHq/GrynWidd2V8wElUfaVIKNZx2nqay" ..
	"sMWae13v66WYroWX5o/pnMV9DlPbi/ef6eNvzWOoBfy+QyXkxhz3OoZSvldw0qv2ZyoFBNWwhUYNLmF8P5CzhhqMKEi4/waac54m" ..
	"ZLDH7XI/2zJw/Kc2fQjgbwJASSM2gTK+wXlnYgmhw6AtzZmdOJIQd8rz0p7ZZ4y3YdZcIxwhEzbRrbEsvvs+4UmXAqHoU2Wc3mtF" ..
	"noDxFDL+e7lAgBT+AI2wGtYqyZR4nbPAm1IO5h9vbGf41Q7k9pb6sMUsQOEymctIVAqRhhwVoZ5tbcmA4Jbsj9z3feqdKjYL42+h" ..
	"2RxzExLxIG0rWeBO5TRTHgiSbXZ//KjpTwnstdm+fsBxci9x+ZEd4NnUfF749Wv3VJeFPl1rYzs9MEYW4WyKoBsvQesmlum6zicm" ..
	"2/KfULWh31j7X0eDFUngmE8iUG0XMqRK3kklUWkVMZ7GhkkGQO7HU6wAOTSEKvglALnf/HTSRyffEiznP95X4+YYbMJDUD6bhP0E" ..
	"U6IW1RmtfiXIOFciEulXKsEh2B+SIbyXVDW/wERoSBM1j8OdcMkXlJQ6Y3IUkKzvSL8M+KA1K8LEqjqoG2zrnYaIaqO0oRaYFIc0" ..
	"VafGwsuv1xBFohWH/eQhmc59YirvAw/bcpXr/fFaPBwcfpCJAj8fB4Y7I6nIa+2HOj8bDvzgjjI8AdcSndt81GUhT8oKto9FHQz9" ..
	"Sqj4G0xs1IC5Mz6vtHo7eK36VoMCJmthAilmF1quqr2CAG88rBVKKc4uxHTKAdleUQ4d8Uk0XdWNwAJ2bPU1H6kbhfJN3Gtn7cnc" ..
	"seStCZw6slq5LVOQ/HXTPLWSML/fqCaaFXVPua+fRuTzif7AW5JMd4wvLLrOpTx4Mf7LGzM+vNxIOE4IAihlBNL5JW48Om4ZWXck" ..
	"tXpf/E5nqqqmMHYMrRM2/RbCHc5ro5BJ2rzREx7987UQj+9opO/eLGjMSn2Ybh4OOt2V7l6mudJqTqJTsYpXwSeuA/0626tIFn0T" ..
	"07S1SQ75jfHnoL2+ZrhKow5RW0ZHLo6QRlm2aQOJ7NUx8dvVDecUCOR7VNH6eFFzpBn/bVLjjgdYjOKQSXpa4Er+OdGNHIgBhQur" ..
	"1Pr7A8BrLe+fXEr6GJ4Jr67NTS2mOVydCjyeog4cIhh+Ji5aCs1x+fogw4VKERahZY3DaFonQVZZ8MX70bHChD1SGyBxyf6qZa9O" ..
	"CuFj5KTbQoa49vVgu8lslm1e5srOfStF3Vdsi0LZlz+qisJgAjODEraCRB/arJXw67F8/x3TSV6F8e0sR6WPa0m2ZsjdtrVjYA9B" ..
	"8D8Ybxa4Mll+lu6/RPAshuH+9/P+p/v/3XtlS6eqU+QbDANIKsS/HYjFsjVl+tlGEPoY4l/u2svLxlxHCDCHuzkYHwgupdHFHHBo" ..
	"Abv5mfqUpVu7ugJ8dHRuc5E0DlQPeIMe6mgTi2iHMfEX+ipR0bOkeyJElWADO9B5Z2JpGu5g6RAz1OTn4cjFdok9fX9ZKO6BrewL" ..
	"g6OLuueOkkbju2U41NGo4fCiOEKlVMOVH89S6Xcq6oKd86Ts/22xo7uC/Bg6fgPl5gSm67Xn6WsbJvijG6v4AmV65lJwbFxAvvI/" ..
	""
local PAYLOAD_P5 =
	"RTT+tMsiTyuEVK7z0vNLS/5J7l93vE0QkDOXpsU6OnM9bYeJevrE1n3M5YL4dr0QN77O0Pf7SjGkYne0gaexOVhoDkORSCy36fns" ..
	"eW5LesUEFOnwoQYWA8Lli/mtnDk8qzLhSQX3NREzGJNlhIPQ4r4i4dCme5j3Disq+F5ZO6x0n0DxNWmbY19B7Un3Glv61W2S4YVH" ..
	"slB0sKpmgE/EkJgxbO7QhRytAKDi/zxZ8rB6Gw5+aB/fvv8EkvNkahDKWhPUndi6/8LyA0PyuSSpqgwd8EvZAdUt+Kuz37CT5RW/" ..
	"2PAFuFg78lJPZnlewaFjcmapKJZpE32ei2O3B4vsNyEMVMSlPECtMrC7Gw+meaILOAXYrYRr/Q0XQHnPmzyqmVV5pV/wR1n9s8e0" ..
	"es79+LuIzCxi/II2AAxkFLRlk2eIZiMm5HsX5aHmPbhwn5fBbsh+ZMNRuwy6+pe8Y3gn4Sc8mZGS9EWi9PljDJnb4fDPyzpyLzzG" ..
	"SpEHcXiScMLeXUoVttpK/2WOjPR21B0DK7sLPCFXxxvocaiROEfdlKjz7sskDZxhToC5E0o27ih1kz3ri1YHHRJQ7ORFJv2otmoY" ..
	"J112EVYkEbBEiK9saXgoY6LAW//9OUhZeX67ZZ6zyI3HuiuTHAYwPdUbNI3fr+TyqHIAotfZG++oaN47GfQEjRxe7wLf+PiksdHg" ..
	"//pxMmyxl/v19/c+we7Ov8kfg60b5/HJQWZzh4CzGVRW0kNrhvREwrycOXZDQ7GJ+q874KpQwsPoqnKgSqdml1zR6zQxDS5GVRWC" ..
	"/l1Fo5BOGvIG4xI/PVOfNyyXnh1aBsuqDVhDUvDXUnnv8wMqVRk8BoxrjlwnINA2zN/o2U02B6lk8Yhi2qwLLeOMmp+L8tRcMu4i" ..
	"T4n3NGvTob9/v2FKhIVnbzZi8jQ1HzLNK50G+DFEY7qpgwgSR9fQfAAgImokrebCpcSe2mNtI/1IoWjImjQHeRDsqVzgJHUB4lxh" ..
	"2avClb15Ai6BQwMe7+xQh8a9Atqp3WDaGzB4TQFO0nkRSz0u517gochwCtLnblilLU/S+MmxyeH5XgdIXplXuAWsOWZbkhapGXsE" ..
	"7X4q9AWBbX04dfJDMqv9bu4h930qKugk98W9J2QH7I7EZ04taQXORnVdPN6Pkfi7lFBHFXpehwIJKeCp9gyKThyai0E9QMAAiZ9J" ..
	"HZGDaGfr/Z+oqvkISB8EhjjtsNvGwlyEShrW9NasI3gNArRH95TauMoVj4LiAIL4mLU7JFqOpSvPqSuN41JRp4R42rQ4IOtRvRP5" ..
	"bapbVBcyM4D0JDT7uHN0X+CvJNJ0QXCpzoSwWLTO07NBOTplbyyLVYAuWFnIg9LyIrZoP72vqseD6/o1zKdwhIcEMYUy5YPpV402" ..
	"tObon00uO9PUFlMZ1BQeuBGOtUKZA/TFGQWDqAd66k8GecfAd7ineFs4XJX4qmv+H1Y4rU+9aNYPDeWDhh8xQH6sBWdrb9/VLjC7" ..
	"+R8/DtehsGaKzEJfCa7unpaTh2/7bQf4gkOuxdstlk994sffG6uIeLSCR5VZWjI/+vMFGx6mCfqoAJF43uMsr4SQwhLZVWwlkZrL" ..
	"gUF8Dw4r3LYTaCqGVmdUpWiIz1dlZpZxGD0wk+Zz/aZy20CgQ6VhM7uhBph+B7S1MFJicCk9qxBlNlDykhNFd3FcXyjWG86sEuqK" ..
	"V8uMFO3TnBzv3ob8FOUbuB3DF3AyyKj+g3a33EUzGh1peZj8LZHnVSGkGnooaQ0Gx8lD2u1o4NbXmnRUhjXuZSbafZsbJhUVp+MN" ..
	"shbdQLaT4JWhHASoTHRTQvQPA+0h6xIuyGXVVz0CmRcmW0YOSPUOhA/hdobpbnTG8RfunAsnPWth6p9jV/DuZh291oL08CNfiQPB" ..
	"3ik7c/Jcx8+ee+md4BPp7yAtB0nEs9QEHkWynC8TTiBgH8BFdLZ+OhXYCK74NfCSwungKSgqP5rKOOKxaB32VopstB2nuO8eEV8J" ..
	"QqZyxwMHAoQG6/JEkzb2ENaNQfxupfh1H28PVC3SJBGPcO6FkmWr5G302+fRldD0IV3RaUwgwX8MHiQMewHwwHWZ5J+9iJdv0TnA" ..
	"IJ0cQ8WLBmmjL6y9O92H9CHIGBtypMN1sgChUsxVRoDAImMEnh6TosVzhOzODeaf/F/Q+SN3InxT58EoG9yyJWhkVU2aosg1teQI" ..
	"1NlTWhOLQ1AMaPrd28h/wCaA7Ebe8Mw4dI0EGgA7N4dj6O5SPejyNsEvzYSBlmIzNd91SbthLmlMCg0Icl+RDuu9v8JN2ueWAPZc" ..
	"8QC7yomEA32f1odl1fLc90rFLV9vO+OZO3zsPVvXS8rQ5pw0+us+gY+xmLp8VKBNREOqS8WTpC3hmhn+uWzuV0CBGjTfpufJJ0Mk" ..
	"gbixMPMx5TH4Z19GAAfoDzF+qBdIGhTyXn40N53cU+UMKtwViEY4p+Ygob2BzkihoiPtzjZkmgeVTtIyuEwyG6zMfDvNuDyCRpS9" ..
	"RsIw/YGEI7VsJkvR1k1+UiMkhjh1jrmL8opP3fwXhLtChgnmpEM589BVV7j9bahZjQS9dZL5rV9g185IHU8nATmlP0GfGaF+5SkZ" ..
	"Mtg4gqKhjx/vGjOVvKcVmCBGcDjvyb43rLAxa2IrSG0bmsVMNmThrplMGZ38aozkTBc/ySoid8GKorIPPIKVNq6CDVmfoxgNDGYY" ..
	"+Hfo8TWxCdidUlb8ci9nCEIkNd5uWMZBFjwVPcxh75BUiKPvciERabDE6UyLBurlHgH/Au+5rk/hzVuuHgW8PSiJqAdeqYCg4BS0" ..
	"jxGcYkxAtcaFGsxquz2n7ksZNCRvs3yIVp1dl6/QqJqfBHiGZI3l1+RMmW7Cw8tjj2JAXyZhZyATMF4pTGmieqWCAUJgBD3WI4L4" ..
	"MiQE242C94hLWQLIz6uhD2CT8CcVZZMfQhu5QVfw/BRi15+NZNXUE6sUQP1X65DWbhLRxtN0JvH45LcTN9vD+zzrRvBOmtMxBv1p" ..
	"gDbSgnkSe2mKxlZMXeOMYjh3sshy5uuKUguzCa7iPdggQWUzR/OF+udXaEreubBC54l9VQJICQp5Z61LSSTj3/9twX2Km88OckGe" ..
	"hdjeTVRbbDgFZinOLxsIlniIz1qxSlbtCxhwygIb6h6zYIpWeo5W/fOKNqR9CEZei9q9BCmowTVYfXGzrU64scKuu+ifgnQw57WT" ..
	"Cspda7aw4rQZiUpLP9KpMG+GRIC6Egn/jb1coQgISttOCE2jOYp41fQJryhvUJdPBpWS+KmX20jnY4DMNwJCFRPiLsN8qLVeSn8d" ..
	"3plwO3wu6OAxhETQFpBOVazAWcAAABxvpsaZ7BQs1TL1Yy/fJIS49ybYJl9R/XJLwmn292Rw/EIOrOh5wWsl7LSh+Hye24jrDybx" ..
	"4cQa/hQG6/ubmR17SHE607nrBEHWnVewEL6FPmPJcI2uC9iqMWBHaKHXqjd5246Vp/WX71tyz02oWonM5EKiO/3WSl4qDmo7i7+R" ..
	"tDawP1I6nUB6yLp4iyC3Q67NqMFRWUllm/nBUP+HJNm+2PoGfhb87W9XGcVOpyna9mE9/NthcGg7KLdRLc/mms4zpbxNG0J8TgKT" ..
	"pN4DRkqi9z594tvIpDGz5eqTWhcSF/Eru6cUhq/ERbdQx0i8KFsqH7V0PlvBix6KHNs3CdPiO6lP4OOsCdU50ExjpVc/Mmjl56B5" ..
	"NFUp8Ryu/mlB4N9XHlIpNXRmbYrmDRtaDfQAA6/iQ3ZL7SvbTpPlmvhmUKbuW9i5Y/fHZR0PrgAgp2A5qgaIfwcRsAJmhyMAC5TJ" ..
	"zmAnnQfboIhBE79WpiW0dC2DcOSQHXGzVTD87UTYd+lkXMPL8okfAi16EKjNKKqpiUyGjQ79Qh6tRl1tiS5ouOnkAwZMOFM5S/um" ..
	"lV3DEtS7jXc1T8he4MaO8MZVKeBYgpXuR5w89rV4t4dD5Tzy9pRMsGgaTBGH80IlVsayd9p31A+A4ZxcwDD6cJPcKNWTaIELPyOI" ..
	"Nk/va2ShlPMca9Fs0E6G5/NNC9rM5I9FqKGv16Jy/TJ4CSjzDwuIqx9eJvLRwB+7+pOVkNA7RLjcpDOpakmBNTEBOIUSD3ZnZXRD" ..
	"h2oYm1QQ0w8scfyfK6OO7H+9b15n6iszwg1rGjk2qs4sutZoe/QfjBuYO05+qghpnVxSAk9lbAxFBF0kRYRFb7eQa/H67F/Swh95" ..
	"HKyCPa75aES8zTcXhHZqGnok7/ETNRjjPi5hDZbkISX8tCh8FcJgr3bu0a7OIo7qOdKJk2iydxlz1m9njZgkhTeEKO21s39N8P1y" ..
	"DDwGADJq5+bLpNUjU3fO24/VLieRbeHWCNHKiatS0KhTV0u3PweQl4fttphEqnX6KVET7sJXASqnw7vvpL0eT7PnJASDC7mQ+bo5" ..
	"W+OnDFzxqqpIP50eZyb03VNL4G0h8tN/FVC2RdxDMZfsKRwdSBw9+zVEJZbOc07zHt+XZj7q8fupI1eWOGqHzobf4lII/AQv/YzL" ..
	"ZjVw5lD98C4sr2Whvv14whLseyslimlVOXSg7Asbv0tPnbkJJhnzYatXqfj+d+DQF07GPaU6a+I7WmGXegeM9W9QS7C3036ac+7w" ..
	"vQqAyp1hDA7qYUGs/xBtl+qkT/Fw3JxaDxLVS42v3O7Zvg6HbSYAhlPSNFtqzUjwbPlCcZ72/46DkApceH+7Hh9jqVx83BR7AY6e" ..
	"HT1ssaSfGC+1PjJgRA4zkJY1lXpHQ1qZylVD6oBRwck+gv4bUaYqVVCpeuu7J6GdPSuAefK28/Yp8OsJBIId2UYeL6PpeYlYH0WL" ..
	"IytgIZ9czO6PnOQDQzqWz2ba91oBkQc48KUJc5hsdHdIHuecPQ5eduD4Y+wgHXCtvfO7BWYARfufPZv9ZSxDY2aBFCqTKadkzfxz" ..
	"HeIXTHbVp3N4mb1fdA+pZbjv1d+42xLs2BimZf8cffcyrMM2XyAdeE9PfdMS0vJQuABCaZu4zQcv4UBBNZUd+fyQWPEP4+ibK7h5" ..
	"LPDc97q+sj7ZlteBKDQzuIZjOa1Cu2sriXssp5vMzAu4DSxVqn2OsUvEVtLi9sD5jMRn6xGyySozt6B67VHwxmoCKK0hLS1TJ+5C" ..
	"gZE+LlleQv6dkBaXlUFexU8LdU1NRGPPpTYNLgeJWtCW06I6bJhOGeWp/TXZOQglTNg5LdPw12WVsCdaG+pf4t+NDqaSmMNPrK/o" ..
	"FgYSQI37p+ADjpGcndcC9EzCxYGTKB6Mivwg2kmc+L6kAqKDYrQgxr1XNkCo2J/RV/nVNd3SNwaiR87KHKbDcp6vyZ0H6vZWHcJo" ..
	"Nm+jvr9cCtyxtmpNOEHb3HraWLJaXuGz6lWkcGKh1AgVgXGYRro7zPSkBSCAOssk+edmegAzaTEesoQ6iJcKZWkvAbn8Te2rmbiW" ..
	"BqqNaMxr4RhxzPdBRDp2h0W5HTEeX5dZURN5ZL04eU8lUa7Ev80fF/6vezRC9NskiYfP3IJEOoYnSu+KpvVDvi0htW+cByHsEsJo" ..
	"dcUu5csVFkPZChWPEtKasR5HbrGgdlWLHIklx4p9mLlycY2onErJSUTcKDeNpo33QVofTJwxRTrXGU6Fq/3bDbcyba261TFNIdXJ" ..
	"pNLzHbFSS0/q6F4LvuZBsvlF43Ye3iVKFQfNpgkqrqStq018GpbeWyPgaBuBGZmJ7HxSacVypB42LYwnyIw52MBcPVe/EyxLGo/V" ..
	"ePjtAqt3aAlEl8eu4E7uH3HhoONCdkCyjTwLffJRCzcPonm3G9tQQU4ml/R49SlQj/eu1uFYddM5tyevpTSwZ3bocf03oJMyUniA" ..
	"wXCnRcSmZj3dSnBoDX5Ik5hOJL2CjhgR7uYkNpA79kSo3KCiPaMbfmZFC/BX/sYp7HV+ZY3MOpRhlPR/ZjCD2VkRMsOTpKniUJIf" ..
	"RTmvk0KkjLj88Zq2EdXFt7WjUnDqKYgxaVx6xivQHsxoMv7kw/9qu0YBtI6g1FONgEvCJDjL6JvJnvu35K+Om4aKeYT9/15I1+uQ" ..
	""
local PAYLOAD_P6 =
	"OFsnzcCJ7Ct5WWwM07Oc0y+7QZsz1wdNyucI+8Sfx1INzuHwYLyebQlKkqEE4xl+POIzrZFjK+jntpMT6IR31A1+M5kcICzgBYL/" ..
	"TekXYfSL/4IyKmyNyv3k8KO/uGtlOQNAFn+O7XQS8MWHzN6e5GTyvgyxexwgslGymDE66RzPBb4nViOmWijKfDReoUPnEbO6KZhz" ..
	"p+GiBrsRMBKGP6xg24aD4BFydINKlyT9qv16DyPKezSJ1eknS8xwe7pR087/5gajAjFMEiqQRUVR5SevNhrby4YqASkW2/gCrp3p" ..
	"zG7MW3gmWTsjf7Etvmf9dvFLdR45NTxVzYCNCOU2B0vk+r5miXpSD9tb3ea+KwXA/+bYPqriVGca1dE7GB0ClcRx8Vbwn1ylR0tq" ..
	"3AvQIF9TDMKloCxQcR4E8AfTAn4+QYaAk4Us/56iSX5ek8eYJBoJyNKH3UrTh0x+mji6JG5vEWGh8pHRyq7lXmz2qdyEsKEoAS9O" ..
	"9OYDtJAKGTKzf/tX42fsRhYe8JCXzgTOddxDa0INFro/QJBhgb+ZLQoMce5nwNXfixRUEhKWfTGzVhX1x5YBrwnKXEUaAMcTBrpS" ..
	"E9jD47XqbBGU3v5kw2RLyFzsda8FmLveeqP/iYd8mQ4rketJN9RtJhK8XihFKx3sPK/I9XD45trOwDyqVF+WQKATP1+fDyFDYcsT" ..
	"V/kPoB1eOUvV3fgofIAu83HPcpSqIIgvfd/trMKoZODiBoDS3hKBG4kj5dKBZ8UHdYJO2GhtPDBnbpjdiQzdoWJj7Fhkfp8Ik8QH" ..
	"v8xrvEUcWl5CpqKiJCyftmkNrsvrq4wG07aOz+86GDQECJes1STpnhLWY8RZ+uwvjryAtKKgd5UqUWRPpZLJo185DZxF4y7BjEto" ..
	"0eLlxgmfiV6GSus9CenSaj/rhsJcDkpPqM13crxTPReeCF8EQ2sfXu6f24L2XdHoTf2xKiO+92CxbXYD0WT+XYRfAgV6ivGGZH4V" ..
	"pJlUH5VG3kL756UVikQ8WewsB28HK/kRznNwSev89hzfeNtzBnCfUz+3KFwrnQ+BVrft02CtrGTRCDyHna9zIA2J4jMd5ftmnp/o" ..
	"pcXzOTY7Dk+YLEDeHQFOsgEicZshmlquskXfmpr94KYcFTrfAP0F3TFfmypW9rk+AeKEMJsVkCDJph5dYrbSrVag6UsyEZySmlh1" ..
	"eJMxeo4gEiym1hMkdZWgMOBUwoOil2ZPbPDjneZxbTCrERGB+jpBhgPe6bmrUyP6BQVf+KKtbca97aNIXR+/fBx3vL2h5gfDrHnV" ..
	"2zXHabdnJZSTsvgr9SuZA43+7KMYmuO5uhRw0V7saCuYpDoBne7ntgag7zYhjv8TdPt4ZvvKXuPPEQT/0UU1FVV6ztKvtxU60cfo" ..
	"p80S2wXPhc5Rdr2RVX4ifufHSwKzcylhHi1hp4EXLu4jhSPDnozzdYxqssb3KkFGbmIVRj+MyTjiy40jbVCqU96WZZ4kBG3yK1Tk" ..
	"dBkJcfNijfurMVpbQOg9BcAAE5NmlwGZA8ZFoB5NNf7II7HUedGuD5yhCXNC7E3KwIF7rQS865gDMNZyjhma0t2gODkeG8GJvQTo" ..
	"0MRUdiyyosoNfS0Q2quN54/zY0FLLnPqbrCx8KLMPMKnIZlhDJ8JuEYwSBv7ijlLBGG/baHObVqPR+es4R0aRxwjem0xqwRAGB+a" ..
	"Ciruh7v287qamHCqJvEjq2mOeY7HzKyTVKu08jwg7TiO0hU2cPmt2IxDcDcPoegGWGkVPdZBCsUpGzUSbc0L35DQr0knspwa+NVJ" ..
	"ZkW4UznGrcPvyhbeY8+3Fc2s7pXsgVCUAszfRJDGxzi1E5k2SZaNIuRpw2P6QHTLa7lvNQMLajtgutIZwOgnJdxKEM/5V4d4fN99" ..
	"XEY+OVXDveiabViRZaAn25Fz0bf3kj5Xj/Fbd7TpkXzhYr+isc+SR/uRnsY8eWEZHRnJnUxZauaasxjezMWNUvW0h5ljEaM8xgcm" ..
	"PyQNFiuX6e/a7/DG/NUEyUdnfUKuu1CJCKS0ILKxl0IPjwRDENFygwiSnpWkz5JHUwurBbpBQQf15TQQlSDregF+U7zC+A1WXgE9" ..
	"NB0XsEZvwn3YK1KJJtrX38ZZiJ0144o1JWe+2PbXQHF34FNIk2Uak0643x2XZ+qk4mcZOOT1LmuvOL1aNtImWq5EeA3lRTeYeRo3" ..
	"CSYgRHVi6jHz38IBA2jAID0Zf9Nm7BJLsbFVX46PwxU0zJCFawb0z5CaXByiJ4RgZEaH0Fffv65irFqfiuo4rpHEPBCnD7hCYRhF" ..
	"ZqUdNji/QXalAkABunzHw6N1l6OZ+sCSwVz8r+YbEsuhG3iTsVgjxbX9vX62Y3H5W9gWnH297FHas8/IxHEnMT1JSbK8N1jGp6ne" ..
	"2kpHfD7D36Ah9jTyxaI6EcSl/CWLj8xBBg0b4Ewi0/MA/WexvhMMsPCmK4onoNGL3dQWoxeMhlOk9PevSjH0NVEZmA4/NMn4xvyn" ..
	"76f+O0SEbgfZaPS8VDqNuLMP7qJkSWlYMVHpsIbixisXh4XUzebLohlolM3igVYEI458QIDOj64zfp+0FGu4eqslrxcwEOZhrp7i" ..
	"1u47tnCtTNGRU/L09R6EZa6o/FjFTZpYBx+56yUVSOFmcMbcTUpMHb8ZN/GAezSL7lr6KQ4KD3Xx5VScvwZRu0eGEBlnimtlAQ7P" ..
	"4DeAbmXPaePk6zEivgL2D8khgzrQ1c/T3EpaLr3bS0jlAe4Kwk+XlINE8OLi/WyfFqeLPpRBnuFY3CNpIK0c29rRal5EJ6KtdWzD" ..
	"xsWoHp+OOJIrW31m69PsYiajd7C8A6F96n9u/UjdtSdDxVV+TZLhR3kOiRBdEfDsl5ACILl6B+dE0qcGPRgxuANNL7ohHDbTrjdP" ..
	"f74vlMVq89s/lyvePaPtxV3RrhNiBKCEM8rOPRpdjI0gYGcmfasDepE2X4+hg3G6okVE2+xbdBSc83o2b2mAVtIE5HqSbxSUEvVq" ..
	"eYsKoRlcLbb2yh9zU53yND1x9MPgenUz+KYn2C7KE43MEVdwL/nrrhlxTlhJKD3WWU76hEfoMdQQaqU4K+jHVz/C5OWLgXBTVrka" ..
	"yCLToEMFp3EwbJK6J/m6WTdssFU9chkmliP/fZqiEDe1UMQmG/nwjva9SRUjMA4p8QmoDeXsNdeAQpLjKg3TXbVAGw+knVWetJoP" ..
	"TDN9hXcJtFdsQtiZ42i/BOATgnM4FAnw+rdmzuQCteqrmo9CIYQi5WYaKL0VJD7CKAxsDZvgxtHvULilvBT4A/4Qlof4IYnuhbn+" ..
	"vuxbFmLOn0TXv0BQYn5Y8mhnWv32ddihiNt3UNzKp/Nz8Jmvv8ZEPzb6m1gzv1cd4WfMv0bNz8k+gJpaNy8+LU7pajW8NCViFtvB" ..
	"pnwqEeHHscwb0R0B/JrGf0ntAK8gSvAdnLQbrjUTZrD1y5fQWNYlurrrpk6uMwnXU0tpFdw0lEQdejBYgGNRyv7UzAVhWxJoltDT" ..
	"Mnq0Z/qUadtDlcbS1jEV2wpV5lxHqnvWKyVathy9zCoyWh7x/tXtCl8EeH2HizTmDVrwXVh1SIyF+Gq01EGuRNMnWA980GU30Rf6" ..
	"3Np/jaBWvedgMSH8Kj2NBMHzUU6KQaJ5i1Vy3a0HwhZClfdMpVBoEtLIM8qbu2OJixlFZZT01raoTPxg1sSgPTmoDf4vjooPHzP7" ..
	"QjVE/LOJeBMmgTcXrQro2F8Wh/IW6PgcTQkss8m/oFJM7lnNmFHl/vlIcbnREFJ510wbAfdSSm9qOgaY5vpqG2yAwdnrliBCBjCd" ..
	"n3tFW0AlI7Q7k1O/deUm5ImvIRsRgP4Po5w271gTJ5Tf6Yqr0QdEvmLkwPIWDRMJIlh4Y+2IkKYru6ofJOxXjdKxCZSicG+IK0oS" ..
	"QlBt9pZGBfKgKS5dsxNwKZINKoN/IKch9+R1wS3WwgfrYK6u88zGLlxcU0IW3PiflgUX9Cln3nNVnWKeAZUnnHLBjdDRuWHlKjp/" ..
	"RpMrNMSaX3FryHTcw707OjjvuL6uuWTlZZIGnrl90ICfUjKX/JhxxucTNG/xRJQ/4B9hdMXftVTjlgrk9OVyWtfTLoJJpRrCYfso" ..
	"XwwRZy6w+FISPupjeOB76xA9bhRIwcu1zhh/RzJduWn4gxwVdwotyl5Fgj7fzpJ3z0+CCkEsiFzANqTJi+zP8ZHj0aThAWW+d4w3" ..
	"o3xpdIfblryTiNSVnBMdwZT2alTCQ64p/vpnTq9U6HMdl1oN8TJ5jpShnNUrcsDHWSISx9WvR1Dwd6hJ4vS1SByGhFzqVJ/46qJ+" ..
	"WeC0Pm18OPgdJtCqoSav6p/wKH/jLfa5BYRCn0DkGRkZAhTjAx87kBDAa7IdPGwJcANn80/le0BSg9vP/pGXpVbY3yho61b1jPF4" ..
	"gqRjshHTpDZPuhpItlZXTzw0+HLskqspMRGWoq76PMe6+w5o6XL1CoftMnvrORFrLKMDnxHnYPl+A40WM6fNVmaoMnvJmgRlizXd" ..
	"xW3AI5an5iRPz0kEdPbuSfLbsSpjq+xQOgaqtidj1vqNBYfTk3bP9K/gfJDgEQqdt+B+P62dMp2F4Jh+mJY8/0X12aiazFvtYZnm" ..
	"IKp1GU+b80PEhIJgV2pZDCvErhy10x5VqW24O7UkoWfc+O7h5CmfGEObs6vm9A0Ukn/eIi4Chfq0uuScs0ZSSkiLeGT3PU2CnRGZ" ..
	"FKjg97TwBq+0m6BKbwyWHfZCpGOeLtP9cMN4ajzGe99Sg2dieDPlajQFmGBYjl5q19v3oexTq2NNZaYuXZHYzKirtlPPAsEILwte" ..
	"7+t2Vk2JyLOt/v5Hgco7WhUlhplMjnhMohy8D43qgI8zWbu6T3XLLG3I9trwV5gOAaYOTS4ctgPFGAo2HJq8s0FKaDHhUt8ZAznq" ..
	"81fLkF1RBYlAWSiIIQullyR1mBt/+JJuAEOOj1S478aI3D9gs3U93eBTJFHaKNOn+BwTeEYjrz5hwWmgnIc+WYWNqn7PmiY5lTO3" ..
	"XpIOQm6MLZahWUBbQ5fJsxeRPbS6j5ZAwAi9Z9Uf6yZfqnqf3JKS2zToAJM3K/33OgeLoJTBtXPNtyD3mndBpwgqrNzfe/PJiApm" ..
	"9wIgPBdPv7MpOuCapCZ9jR1FziI0FiL8Yp5mN3IidbdSaBK1AdyeDS6fz+nxxL8ANeN/u05Uh8Vq+C6rEzdxNI/A23BXl6sGGZMq" ..
	"e0CRwc61F+g0OomIqmAg/ZIc9mDHyTTRqMfaFSIn4lB7knf31L9WS60dmJ1JNUnB6Ixt++ht99GlPIKfG7tEV3b0bTFQQk7TzBw3" ..
	"ig5iFiKHr0Mwv8p3IXPJzMSiav0ZpMNlmWB39fsMLM1FRbmIjMnzD9XQi/ysK50d15JRyjg/vqUluEPzYqSRqd1oOUBK2NNuX5RK" ..
	"ynBT4ds7aQxuJD/7iTltlBF34izxhxTvvkRwMgq96Vy7BwHhlAIyYzxwyJd8X8ww6kv/8sv9p9EH/ydJVkihnXTpsh9pyR5cVbNq" ..
	"mf9hZWZ3SMXZcYT2s93SMh9psGRDZMxXtPaqT9quZ1rxAjbNO7Ijww9V86qBY8rJ9lh7e4FxdMyb67mscGXAobaKXTaI+D06yz/f" ..
	"IQInLCXpbGu1FsSb7BcLjZyhoA/h91pi6wXkYGPM1v6xNX5RLowmZRFPKxc8l3pPIY8r63cJXbzRYKL20QBK3Jb/68g++w7Gha2B" ..
	"1d44tY7gTO3ltD1yGY513VgJ4mQJtCAGcT7s7iIuU6CygQVyRBUA2qyAJIXho7UlEIro+yrk6qRnjCtrcYwv6NAArILqYUbNnhpI" ..
	"Uj52iWNNm48J4pbRbeVHTXzvt3pSf6s4xddTufsjCsJ8a+4uKHRGiO2oKbf9beMdQuJWhChOvVyldsYzpCZHqHLyd+mOf5bKBB0K" ..
	"sSS0wh3DUz06S0cBY2r/zJLr/E5rCokI2YFEStJ9NNjdJ1eZHs235Z4wr96vZN0xJH7DO6r4H+NmfV70jXKaf0nv7DNa7W0c3/Nw" ..
	""
local PAYLOAD_P7 =
	"fRCEQSAy9nS/lqxxVkGqrQLH7A1oxiAhP2P+SNFoAjzrDD4g9HcNlMvabXkdNdZAiwsWdXiYvfJpp5YKix/inzoaqTzK3x/CmOiX" ..
	"mjOD/C5BZoPFEqMJKlCfZR50gwe57YTAv2l/P2R+0WmFVz9I11FGDnd6WsKIyL8XyFMvT1RAod3gOJlOGE5gwAgHEcuZJcKgp85w" ..
	"qngKvzyzi7TzICMUgqwMwfvxwjo5nepy7zziDNF9Rh8jMcCpvDV8T6Cksppif/gbkd4NFsos9WN4xhTjjpSE90c7jboo4dXKYsB6" ..
	"cx0mz300fvImYDJVRzfooq5zyJQbAHLi8X9cJWbVTHFdiqIWXByO+On8QbT4g928ztvML3AFLfQjoqyUxba1fkzKTshoyo6JsN9Q" ..
	"prWGeK8pUf36VthrC2YjUw3V4eyAfEIL4BzVeirTeqyhWaIF73nGwlh+lzrnPOz45ox33DhTB7meQrVHBaTaygWfqxa19xNvll/w" ..
	"+iKta/a71gI4iGAUNEYl2U0JymPD47YAN5c+3JNqlxm7kHHw1j5Zrwo3XqNscdnMLq7B8/UdwyYXQpHawVbq2bbUxKV7UA6fb2rD" ..
	"XL/0Xz0dRheh8NzzgDsHgaURcuspdqJKMBneKzEufSSdZXKljhyx9O+HvObO/lMzL+nQp1DO9O6valC6bmuVo7oEkaS1ingUqGkR" ..
	"nvtx/qerNLuJLRlcUSYMui5f4IDpryC9nNfj5AR6lM4IuvZliaUbS4y9TLOHcMaD8h9oskRZdTBg5sUtGexPJ2NBjFSsInbDnlY+" ..
	"JedjzxJ/pDNZ85nU6DYvOteNND5mbSykBzcwhujv9EnR6B7nTygTk4xUKUYX7iu0UGHIFHWvti8CpMdtiXC06jQN4C+y5GKh64BN" ..
	"2+4ipon35Wr/U1C42MkO8XxNf3C2gatnI90lqe0V0W2L6Jb8/8L0LZEcAAoLOUYZcAWhBVLqr1Wr8cm11O342kgLb7016yeGlrDG" ..
	"Q6PJTPJQfm+spEAeS7PBk0WfNHFJAZf2yMAzOCBToYsRof2WZK1/bQbmeRHoSDRBIm0nTFa6LQbvRd/4TWs7V1wsdalr+Y42aEh/" ..
	"10bphtdgS+JqDXkP3h+3fC/HJZdCCwt5yWzJX7p03LdZI5h7lQzBNjJjs/9n73NYAxCTiNRemacg14KoiZmEySPCPjkXnnNxjMZo" ..
	"UvojEqIfKxIrbWgBDUgbtIuyibSQWGn5Nzh2FeiorI6CB+kAA92WGTBZYsC9Xti4rbly96BtGZxph/RbL35DqpxM4x7uULuM0fdk" ..
	"jChTfDmVYEKoyKNCUTxj45SorAnKErHM2dQs/A7ohQ8+OQLtOxUGppV0qORF7jSD3KXD1t1o7vAwGpiQPYIw4/UkHCU3K9Y3jgxV" ..
	"vlxsxp/Yd17pqOEFQg5XWQZ8cIBQ+9lyZAIqFyIgMuopd0orh9CaSiGngdkk4pRNV3nvUsmisZqCsXnA9GbfKk3ilq/6e9Sxd7wG" ..
	"zsWp77u3uim9dUtN3JvzrMAtKcjtIMsdFgDuGYEziP4bQy0cISy919ZSpe8YLT4uR8JFw9jp81etyI+WNNUL4tpY49JSnI+Lmgfc" ..
	"XUg1XFEzQdeA0/tVV1wjCGXKYuVfXmOaazyHg7AHxjnc2hSD5YO6ahhps6mFC6DK7DWFWExO4OtNYuMNjCMFaZYvVvbtRuRvz9Pl" ..
	"THmh5BMsf50S9hATCzcw8cp7dNj3etkIfl/hX/hc/U1dVuBaSHKt5O29PgEY5JflWpclMcGcgLGt3ytzdhSJ/u/OuJhCdJYDfa00" ..
	"B9CeRhvchuhVvrfElq7A8atjKBNIpBDCR6Zr4DhpTS65CYkOw/uNXSE+bPVlQTf9rjfCtIgEif5hrrVx76vCsCQcm0tSLmHWJNqL" ..
	"LIFLUkk/FGD8BVQt1aZI2OL1d28HaZHucCgolN1fAddlOKgygwhCg3AQMZ/ALgyPgOaXZX60TtDEq+bBN2XaQ3epPE5Myk+z35HQ" ..
	"zOD2dpbAXiXzwdhi9rC06DNBNvtBhDCgApxwZ5wfQEFX8q4u5Mm9Xb5cGwzz2/a5y5s66iQFbKl4YNeVRHz+56NQaPMJpTgZOcvQ" ..
	"yFoZpxq38zV1CLrgNgQFIKNDmtugwyiBi+8BP1KOND8veGp9iZxTIPV/URa5hZ8EKNEGtWPC7u2bzXxWWkz7Z0PUZC9F3r/JE4kU" ..
	"j1qrp4ofW4AwMWRXphWHVfDmSCdDiWmDi05d/kXJRDc/5XIWGcoz3eggU5TFAIU8qcumn5CF6uVnT9vmtYWmloIspv+iOVzwjfqZ" ..
	"t8dE3/T9ZiZDNvOhNRwE71nEk1oL8x9KlTZ8YF9542mv2Piv5rTyQ9EM/1nbYBnBFeBgApP3HTZOEZ23w7y7DTm8xceMzuJEGwyP" ..
	"GJDVdjAQtFVn/8t2iXkDXD18i6B9DSPtGojxuVWtyPtRE4hVkR5QnZGr8b+ovXJlt+l1AlHqvoPVxmGsXJHS95PXZq9Xr0FhnR4l" ..
	"3Ua1Vuh6VgZTdNCuY63lYxgcN8hpwjUNbZqKLJXI1rxHrGCvXv+0gaEf3Ksw2YhPC7i0Ppf2119NEMm/RO3MFSgdVnMClEn7eiIW" ..
	"HzPJdVG7lHZmq1D3C9Vtfe8oo+3+cFQwQuwW/RcxHnqTOY6GRDLrqs0/WkSo4UzSrOdcro/7BDT8OxMN8PjI+xjTDZRP6I3YSZpy" ..
	"3MK1a/gKU8fS3CddH57AMfSF9+JkEUCHKaF8xFIKVNAV52RPYHzY7WFyiPYkwy3cEEzXmVspAGlnJrDBejOFLmYtTfUK31ZCbNxI" ..
	"tRkKlvjvrUtGWWnl3OdONNdZdhlvcvn7FpRbUGXqpNt5XHF/udYRbnyQyMsIcoTjh04d/bVd6Udp4xNpC5LsXvYBo5m5oJCxX0hP" ..
	"QZeFcJ8CWA7QveEypbX4xjM8ChW+Ze/8MQdjyGlLdaORNrC7Vksl/wrpWiocoHov5naM7vy/puo8aKtyD9TDgZ5JlYHhrYRKlj+g" ..
	"xIuCuR8Kmj/d8v7A9t4KS3ffV5mvPxyDNFTtBe9u7MtaStQrO/yAl7yziosjA6ZsNpy9jElIBK0KxMfQ4/7V62QEY2XDg9D5kWJt" ..
	"CwOr+rzLsg0RMjUvohRC7waDTtjeZbMZb/0zfaQBsgyqKYiRCZXe6BfwfQCGNtGGEEb8iPfaiufWsANG2R5E/qPYL5u4L2lLlly0" ..
	"z1NOZbVRimMEqqrkyHvTolrxELY3jF/iHCtTONfGq2QLM8z0pHnRG781rMUwOS39XGqVMr+z4Tk2WiKC9Ec35PJFXbLikPgPJScV" ..
	"h+z9lqqHeuN/Y7s+xELU+If8VAYJQFJ+kTUaEvlFKVYJpv9Kho78ROCYPBRD82ni7OaDq91jwVKs5iddo7i8avSjqAavK+cJGr/C" ..
	"3sNJWgKQrWCn3YQNpkf2VxwQah9EtlZdCQqFJ5mVAgm4zV+ZNo0OroIzkGk7jTbY8hva1wWqquBiWwPIfe8/SoHiUZ6zMlE31Nnf" ..
	"DRYz7rugYnZ8VMK0BLjbE0UOrNmE00sc/lpHcs3U//nk41vZ2wO2ccnt96yVjHxm+baMEVtGh2DHfaenHAaDNMv3p/4xBI4l327B" ..
	"8rSvQyRdfKMD/hNmQFwno6lUuUtCAkJPH6+LjoM3Cch7m0t4d0RaPk052UjqS65WVESK+IJT4xaVmKmq0YHI8WAumJ9ThkQ0+enH" ..
	"ouTc0q7C8fdSWBoW7c+/9zEo5cU0s14/jHmEFJaxHgLZDLLwRON0DBM/Hl532jiBt5rRKdIRb5EZK93V+X+6RZQUtfS/CM2S89BT" ..
	"JYkGMG6SW5NucRH5Wo1fZITw0TKMWiJranB6UHW7Yy3q7X35U6+Hnws3Ycs31OhtTLGBDCLng6yHXtDEuagxvF7C4cAyigg/PMDd" ..
	"TIXuJzNgoClocqZGQVCo8wpIIscWubrPvxbTTx3pu8jCbuJ0IVpOPe0IZ/wWQHS3O5kIrH+MVZu7M+vCFFEvMu6wpX8HrC1HmdXh" ..
	"f8ThYVznDIuJ/LFQqAfae/eSsoepEtzZB/6MZSkYm+soUDGRY3PUysXBJV/Rc5grV2Mwloshm5WZN0i78Bhv95sFxtV1ZEbXBqiI" ..
	"IljIMnUzsIZ7/Z9MNoKoLhvqyAGJSL5TnBqnNWYi7VIe7htRwv03+HvdrQZHcYYmuFFyROONJPN11YFxOVd0DUs0WjHHKOXxdrfV" ..
	"2XY6ozXHVdFq/zXrncWgEtVzvg5zsQfdb5WNUlcEaRTQMmoBgXGpN21CMWymVo7G68YrhSmS3GFlg6jscm9tYqXrpF35qdJMb5IG" ..
	"Phx1WmT/tEDn/uNfHbME0pQKiyqy3olM2ADFJ6dU21xgne1RRuJ2vEuO9S7ZLWEGDb+53CC8a0qgJpgOvcYzadhuHSGfdVqFOWWy" ..
	"y1rCoaWmLIlz2jSAbrmwWWqAVW7gvtwJOfsQCcMxURMYeCMe+xXOHfACBYXfr+VXltYInKoQsX90JLHLXXUUifBMvixQPvzZJDdP" ..
	"FumpliwUVWZnUU4V7lZapm+14tZJpGbU4GLEURYDyZN7W0wpPKxUg7CDt7tIsw9J3/4JIdUC5marWqoFAP+asN3mWc1HDNoe4dIY" ..
	"ESdmDS5aa+T5h8tc0P8Vs1BJLeP85c6qqcaODLrELHKAsH7rEp1vFfXdCmsDQsvtuo75R5193l/G4MbxJvw00aIms4s4zHUsEOIc" ..
	"kT+7+0fz0CjZ6amNy3Nqx670Kmgvvtqim5M54dbih0QxiwQpcQ4hxSNxTgx50UhUqRyX8YcWrHn787sc0ZvsE0caE1NSOziREdfg" ..
	"cjrV3MzgVm6UTKR1WM9xBOjw8wyhUzuaXkErEIVQ09NxDwUXwMMOHxI88gRLGQObdquNYaZh3wUovxGueyeMge+hk4SmqprKksG7" ..
	"TqqRvTpIGxUOstI7/6bN6RAQtsIHQeG5gD3DFVJK5Fq7MrRd+uQud3vCMtoWEZXWWqhqJsmXXJyw/vZe8mMFOElustVcUkKsd1BJ" ..
	"hHBeBygCD68koongRNoNz3XijmNw5O+zSCXMdEcH9qFHft1dfw14iFdnj7b72JNrf6xEb4RfzgYqC6lxblm6vbRZlz762oAYPR3b" ..
	"3cYwwUY/VBYx6G0yLrtO8DXpR7VGfBO6t89Uq9C1JG+O0/K6pGOyvwLdLYgdnpI4pKoLHWxquSPDMyrFuM/ycJUFhcwrIPe8Dhdt" ..
	"VxqZYgTStThH+e+C55Dj9dmo64NAwZCMwCxLLwQy2K4p2zoPRu4rphQqdXNaN1vUUHLZZQrgCVl1Q75eRlYyyqGU6jsJS6vl+oOx" ..
	"yRZJE8Pttfz8VjEdPEFHD/0UVDMYothv/p0Kw86nWVffXlzWt3mCRzYidgN4UWtbwi0ba4OMxN0ilkDTYzFMNQwsEz0HPHvEfUe0" ..
	"bU7bv/MPLyKC0LHRiLqzIh+Uh72xG0n1UJwaVsWiQre0seBs3cV5QPN4vIa/pt7GHwG3+caVKxDWnF83su2/D/NO32xH3Vwo9T34" ..
	"Khltza78+NaXvEVUGTlkuDgTIH06MeaX6tbAqGMEr5rxlfTeuBOLL0yd39BQvQ4MJRLpvdu2FmYaLBBcd3eE0+cx8N4o14dASvt5" ..
	"4uNijdLYButPGOF9fq/R9J4dKrLD1zgrQzF4VGID2igLDyfwrD6YK9tGPTBm3LuoXsL2TnsYXkzPn5djVxA/6PQpS12CQ91wiVnK" ..
	"xmS+hVWDXNNrtjTW75HrNtKl5iTXk6td1UeNEIQIAUL2TZmnqrTSMsza71nvoVEoHkG+bh6jk4VlqOa4xEIlDpBT8OpDkafpn3o7" ..
	"fiMfim/D9LS74UrJkmy9u+85Qdc8siUzf84BRW1qztR8tvlW+42dfajelHbwrXQiC9lSPpa4JWS/gxd/5vHEXPtXqHB9Tl7cq+VQ" ..
	"3p6a4Cr9juyxZJnSWbdCrdPKwGyMyVQNrX5eu9t51tWZar8ptU8qkVgB44Bug7ffvvZlP70sbuFs2rCknOOKYLHufOPXveSrcMKo" ..
	""
local PAYLOAD_P8 =
	"f86BP+UxsPSC1hqD+t14MEM6HiNp4io7IYfjhAh3ilBdetOn7RdZMV624KSc4uLJwvDYRpqa6yo2javMwmekGZ9TM93nkMH5FR5A" ..
	"X34Yg8QKWRAsceSu4JWj23tiUXNS5myK2kby9mWZYCT8iqnaR9Oxj79LP3bd26sEfLdjZRkr3c0rMufS/V8b1gznxtyw75MjNRyy" ..
	"ItnfoRDarzAKpdpJkNcuihlODKy9+vwN0lxSsYMKZIl3hOSFWe+kav6/P5zCSigGdpVkl4Ne7Q1w3aZfmMaUZcNxvRCf17pz/NOl" ..
	"wfx+mLYd93IFB3ww5QqkcWkQwsofDnrnKyDK8IMsuUSU0xNcMT2h7K4peGXYGdeqAGFkcnGHzZDzXnTZ02wII+TpFRuYIckOWTUE" ..
	"qYip08Z8gcOC82oeJ7zlw89QERQUo7vam++MkhLnOWkbh3jQS5CTFBPO5MDnRqhBR+E/I0JGgBSNsH4Fl8AQjQDvmBNkSmpQWXx7" ..
	"IhGhCFi6s30Jayaaq/t3kJOZuoA34uelAHZkJqWPlj4xUz8SdoXEvccfoLX1vaA4XC5jJN1m4G2E0pNnbfJJ9bZTIgOEIRkzPu3B" ..
	"v80WpGBmbehQb9t5EbYeR8zc3/OUtbt2xYvGEkRsqahMjWDjdiW4SwlG3yYWSieQ6qHwfEWq006S+JF7Hxb2C/+yD11LFkV3ccjv" ..
	"+lR9LUjI8xhCUgInVxK+NGsmvJN23qXEO2cfklHjyrJ6M28/pPZ2qviD+bpO3TUh0xS8pLwQsLl/dX9b1Vn0cBzjzd7cFDXjc5S1" ..
	"Z5r6NPDQTKlU1SEkMPSGpDJ2oXk8YNqVCk4bQluvOfdu+NFFkhRP1z77BGUjtRDa+Fk+d1TX8ac7ct5jQ4nCiNMBgET0u3sMBDQ9" ..
	"gBluwYyT3sTKX+b2jzhnl2yko+vJ2jUMhy6aNp7vuyE+qmfERDbghrevYsiaA8Pr1lp5Ml2Mkn5GmDwU/B6oz7wZ9tP0aOJN9WWm" ..
	"UpASReIYOwNTRK9bwcT+EC0NbaCJ5pYYauqykgjmmavQB4Z59pe8WkGYj+IqRvZGVfYCC5vn89DE13BawAzEzTkOGfBj7r1NAoXe" ..
	"LdBEHIRSTld5NFc6SEda5NCI58oMSoWk/ezohYVPSFqSDc3zuy0ngL7zH/pGQbEkJpeatzA6zdVCA3HQMv7mzH7PH6KlaBHlsAX7" ..
	"/9La9VeCfjN0Ax/6VK7Rf2NHdBPtZ9dadxvRkBBmEz8feuWkqCn2mVdsBP3DuP7BRTnecGDfebxl2QxYC0WbRxcPGbeFmOM8g1Ef" ..
	"r0cSgb6YpPWJTkw/9IUhjQsoaInSFV9MobSz8O72IJGkMr8yyhMalmhmzqgHygNkDdL4HYIlXxPcwSp/KlzE1A8cSHwXKKpAB/Di" ..
	"CIueZwnSl+F1r03QKaTPuLdxjgI51aEsgFGro9QpAHoiyKK4r0QnwvP4NvG1OIHpDWanQ2qM3zZhdxXyxHOZ35oHkw8HwyCohW9Z" ..
	"qsi8zM3wOf3xI++y1NkbymVfQykMevUUS9w2L6alkvgegFbowWXTidkLTgrEXL4ZkCX71K0TVRqnaGmqh+iPj9pYLeZbJOXh5jUd" ..
	"FOl6mqVTLqbkaDEK/oSwCG2HlSG0FhHakfHZLmNsYDwqPSyTQRg/xnllXSC/wxN4QVpoaBdHmHRzcDomm2i8lGkok50c8uxpQVnP" ..
	"ktk2B/wPq/M6G0oWnuPbYNrt+P9BJ9kTUuaY0X9uWMw3KW5wbY6QpxOwvhKKoBgpkfSMtebIXJRxT30mg5qYU+zbSt1RTqPQMSJK" ..
	"OspU1WJnvm2i5eAozI/YSpf95wShhZ2Q0IZ2CVZfTbKfHbUCNgd+G3dbbeLIouE7ofzb2+s4eVY9WLvL/2GC/IYZvBGkZ0W2mwm6" ..
	"OYxbHrWYTP6TbaOitLgJf9suTmvvojPNVTZgXAQm53R8bBh28gQhf1153pGrEjOAmjTB+YoTtV8/s4DpJ7S6MknT6Xtnfjj4iymn" ..
	"KJknKPlIbnxQYeQpA68KYLC7mGiKVq7r/LLvn58WgV3jXZ0WdjRcUN6czfG2qe08i5FnALqPFNiaJgy1Dqv4SjZdMLeWikKJLxcn" ..
	"ofOwz1Wc22mVt3vbPMFSighU6sB77QAox8w4p6wN3NWDMOkY1IW3UJuyHTbd1LlbfCaK+w8weqpvYM63hRXfMacBSKc7uvnKgldw" ..
	"Ap76u39xwo1ZdW9WCLQ27RAe1J1ECnwS53ZgLDvKzaNH7yCc47Desxjpv0hgjArGDnQIge5uzePAgKxxkvBrmQQM+nAS9yONF6Dr" ..
	"wF/zmxunbWDV1SAgGWEVImNyeTved4CrU83+6+al4Vq4f/S6kUEQFPaytbrLPZo8zx2CTlmYTfbA3Nh3olOOJag43x3mf4u6aaaG" ..
	"wZy8oFHTwNB3fEYyqLefpfQq5eyhuGTP4P7LlfSpsMpuU+4GWsUhPZjSO3Zq/ZwZcK5gwH8GgJJuR4hJMLEh2BlwPmAbO1WKpi72" ..
	"eJhYE/p+CdjsJ6bV0ZGBXNdDP+A4ONmoORKJ9jDNLDQ6cjesPBdhIr8h3a4dMTEqwa5hD21Tdr4Pm2qzAYlh7v8ZzLHW6Y78ONtr" ..
	"ehYtbc2Fo8kwtAf1W+xIcobmvS0y6RjXo1xE/3Tp0JD4JbYnEHuzRReMHxzHdsk8Mln7ehKWNGLmd19UDazy+n8JWpqnRn5PcplJ" ..
	"1hx1AX4Yzh2uvdRMqllzk1AIKHB4xtA0fhD0S2bO3qOoeqg5jS/T0US/a4Sn+Q7vsHMbKBcifXWpRMBmpTT9txLG3JiOyNZYfF+w" ..
	"gphE3vgu8AVK7sIZ7IRxIRIr9bK0VaUfuetY9V9u2IB+PJ7ZNqNBqKGstmvUjBR4nEthRk4uHeC+ZcnMU9O4vA6sqQbmtZ9LRqlZ" ..
	"QFEFDHBhEUpbspP5H4huP0No14rmGb9VgVDLEhORSSww7JuhW6NFlQYpwigz2SV6PgtL89/IGvPDWND9F1qyP7th89FoTDcslujW" ..
	"IbEzwR79oE/aMbrZfOaMt1qd2ovlCtXCoVsLnLYxdO2jh828/01b4p0kezfC8e+fcO1uhL6XbRM0SRCia8gYWxYiYWFtruKL7bxL" ..
	"99D4kDGqYGN2aZVMIzFGrfBGH9SjuEauey7Lhsd0hD8EN61QdAQOnsKaC/h5+kZDr/YtUOos9SFhKz1qJt6I6cZzyWBL+LhWUI1H" ..
	"oSx86idtP/WIDvriY3VND0JqmMnGxjLMEDi1Xgz9JX32V1PLxbN05F4B08CiPrbi1DQ/Qw3KjbdqnY41abjD8G4/p7IUuQtvE6E5" ..
	"KjR3d0YqGzXFP3wjH2i/tN1rVhGPE7UXAA8J75eh8F2NCDNTneSoc2jqxoJyro7hjXmBbZFW1cQVP3tNYKhdX4cOq7Y+ER3nXsGw" ..
	"VMZg9I9RL2VPLyZpcUKDYZpUpLWHXP+elWxLK8pJvmUSGKBmcRHdaGmP+fQzqPT0Id7kMk090dPIh43aWQCfCCJxvGeag7IQkA3e" ..
	"yw+Mxe0hvU0n9XQkBWueQAhxv+Y4nCIQJwq2JtdWIjHH2GHQlQlX5PFbnVRpiraKBYUqpByn/U8rNX8JmC5wI2NOM++IU0OFwk7l" ..
	"Grp6tluI2qGE7HIHpeLYZLDvUrz9hGcI88FBS3rCH/fdDgamg0U+VrWVF2WUBAcQ9O4GM5jGbKHCS6IlUs56huyQEBtgSkoH3+tn" ..
	"FZjqII6K0oMSpbTxfOplh29JVHTZ5fEPcsY/T01Tkq7egLVuP4zJiUHiFGGc6O85hdPuWFv77tK6tdpUB2/Il81CQDe18pYGG3v2" ..
	"EpOiQ+ajWT058oODYgu2v3T2XimC1FdVIHSlioFT/8NupP0T5cLMAOZ6/+dOVHJ6dqao7BbA1tL/vOoaMQbpRsB3MmDeOledNvGR" ..
	"VscEasAgn6txtSLEzzE008S6V6jSDyIRrLdsbNQyJuw9L9rGFdAGkIRJaCpxcZdDUO0DjHft1B8FN63nxOGnQVo2VwCh4vw8ALid" ..
	"sYzg6BMuyjvM5t76kOeZG92cSjU06/WhVuDFfIz5zW0ht0qtHQc+o/kPCo4phTq9SjiClJbbsieJ8k2heaZuoOF1P13CMnrrqsBS" ..
	"fx0jIDdujnOyhXxmFalflOebFknW0tZYOYAEApmS4J5ZrQXQPK2EM2KqRpj5RDE+avc6o2/aJyJjfyDTIg8oOcKpHJtl/mMzDggd" ..
	"wYle/kHVTPmcMsJcaqD0xYILSlvqwascw8OCQwhbLhjLZLWmMKwLD8SBChSsTt0Bc4Eyd/xBNv/2zKHiRUZomOrpksf+rI0y24JM" ..
	"BxCbLmz8QQThN3OKILyXSnMRszo9cGioFz6xn7xq8r42xS4JqYjwZjRjdLUrUKXGugox0tkbwlE7tW0rd4fgQL5Mz3cIgGmLSIDC" ..
	"G+TSqcpX89CeUW75PHaPT0/WQ1c57SVV3VD11fbUPGJbteJOiFrMB9+lKP+YSMIpmOu7YDU44T576yKoDU3O0+QuYO5KLQIfJArG" ..
	"O23JNP4GKgywng6WVYNMLTytEVBeMILPEKo9/Fkoz1IBkwdHw33nGxRvt3PanCWJnCMhWdeWwwlWfa42BT5cyRq6FSPj2HGzBxHM" ..
	"49ZZwQdgOg9CHxrSBJtiG+ch/eDp3jMZkSaCpm0eSgvVDX0PXbmHWG4uVnaN2mEg9ahA0n33XFkUgdP3qYUyzMj7mhqqaxe0RR+1" ..
	"515TTkgoaZGRFoR34cuZBauklQqEKF9oGYmoAd4h3QU2u10Xy8kyAknyHvpO6J9Z6sR/03aX1JmWC48qt3pSR+a6+WSvflqIf4gi" ..
	"wwCHGBieRMt6UQ5bOXY6w/Gchsrlj0rCEcleBk01/RymsPDJxYjHOfhJU4Kd/gIqVyDlVghBHaxtX0Fvc6fubspHCRVzpeO6qy17" ..
	"TOG+n9djF/xhi3mw1dvVYRUGc2ZkcoBkXBq9xfqwA10KjfZ/oV3GDzncpCd97n5tPB5JxeXF557zeTvHel+jmyMCRc/zO4gDEb17" ..
	"jO6fvNLG1re6dOHLuc+ixQQ/nsDWGxC4+MkyGc7mI/TI111gKhuE1jEguYdVMWajtQk4FFaw7gAYgKd85+aUcjztJVVuJ826v+sf" ..
	"UMU4rt65U980NRSXmn+rGDRsv0tHqx5MhDUW6mBdha2oFH+5QwIrMkw8fBrxfSDR0Xkbg/dRi1yxTHo1r0Z47P3iFbL+mm8PyQwB" ..
	"jYOgwOo6V8vQb6HI5LWaEqvhnF7iWXuAwvm0HyTiRzWVRrUTcW5wK6Ofh5m+41lapoaW8TeNR2pl+rHraldmMx6DxIccWJMorwm1" ..
	"XzuTi03S+fF7wBhlw312qAQqAy+ZtI8RkF1SJpC6o83u3T/FkjZBt61VzgniD/7ddW81i6Hcsoc3Jn9HPooU00VUAEEHlomi84x9" ..
	"l3bewduQQPHwsLOJs7obKLE70D/TCCFEpqQuvMoUtVkK6pwCJueToFVkuIf4SwlzFoKy0NOhyJRSOiBdA+QTmDJxMqEzF9fyWegb" ..
	"3tjIsMCDnxC+U/rFPxAXlyJV3b9XoVQEPzG4go1KwMz78MPIojHVBNj75RwntDFqLu4xdMQSua11HlD6m7yGU/rieOUFC3hxMSOC" ..
	"KCdg4JmQTLI8rrHryQRl0L30e7Y3slyQEndzPsxXmQd/kf5APD5tCPJxGCVcMNI4YA89DrtdNRdZ3hhb8PTAiEslitHxowxCgM/2" ..
	"GsEKn+SXzJoBiwSNbXaoS8QXLesLSlIWuJ+j9i4Cp4piSMyxaeWaDlqv/qsIpxAaALJUiW9lvdbVV5y8H9LKMH3SZniJkoJMtGGW" ..
	"AlMKltVuoYxggD/fG9b5IwSQLrIqME9msiN833MBoe65dY4NoJpndeULitkwsz0Zwr80RqOodLhmUTkLbjhGOqx9O0Es6h3+rMBG" ..
	"RkNG7k0+JdCwlGsW8VfICxI5ZKEEESAXMzRL9kQgY+L/T1LRskFcDtJOg1gPSw+uhgZHl2fFHe3viQOPg74ra1HH/WaNGFR2AQEm" ..
	""
local PAYLOAD_P9 =
	"807Rwqelx1d5U8Sq7g2suRj8WZxIh3T+BxAtP/tMNkFf8+oC46uv9T7zA0lYQ7WERp1xoeeCrQBCjG4j9JeEfvCqAD9qoU0Reyhk" ..
	"Ak/1lwhNyZlYOvgEbh3A04BUntWn+olNxB1eceoJgJ+XnyB6T6PCS8er0tdZ6iInQVoOE4hmWpkMi7s9zVVS/gjfJ5wQa9ZM42I+" ..
	"Wo1/ei0n4JbI6eusYapGWGBLmhtNMzlGQc5k8oJS2qLoclcPezPo6F+uVxaRHcBsurqoc6jmT2eU+FaTakIIcV3rf+k1KMQIeVUs" ..
	"EXyWFVKGMXyC4xGjNV5GsYlH4pjFWxd4xcEmD5N0t70XvGw0s2FxOWvtonc46wmnwT/ReOzkNqzc97EH1iPJk/OaoHdqTi02/+mi" ..
	"uu0PwKvOgbgzMqa9cRIOLp+CceX+5Ys3ZG8ZsyYDKacIxFvCPT2e5O6scpAU1KAQoB4AnqRjjnnRG/gkVAde6xFgQ06LMdi8iUa/" ..
	"955UOITrqJM2DHL/0TtRE9HRt7TxE7aYtgB/VVcg8+10WnYKLrmEe9V/55gzPPcl7adgIkhlHwbFutmwT5SWNNsJCyfVSsGnyZaG" ..
	"1+mft6FxuV3CF0R6Aoou2B8AqhinrgY8V5WhuFO9h/1KnlQYhsCGl+ZmxG53klNON+Oa69dDSeAnera9PUnzacEW+FcLxbNTxbIR" ..
	"mKUbSuOMz9fBkv8Ifftz/qZ/+fGh7kVmqgovboTuJpQMl9je/ArLafdYpHWWI9uK+ksrwEAo9s2NCmnPgw1N6VEkBWIewb1PtAp/" ..
	"r6WrX7HZr3qI2JwxIrSL6MGRJyQ2OJPasaCJo1wYlzcx0jiNupv81zDBSRN1gnlWCINeIjLjzA74mnXA/8Xe+RQ+hBR5f+cfPhrK" ..
	"YZDdDuWAe4grkpdCFFpU7mExBAjwskxkRQR7YzWI9YAYTreu5x7AXbQ0TSQTqbDc75vjfWwK6OvnnMb6MU+4w6RsQweAf9WjBqJJ" ..
	"KEsEe6FtmfZKZlubSsLSPRgyGHjVAlcU/738JU29Mfv4dQ4kW3em+EvLbMQbxuLrUn1d2mTtRLtZGbI6YZZRRJY1T/BjysAuA9wB" ..
	"fly0yLxZFC+CYWE8LoFSzXpxzpliazDswfyzSc3nFhbT609xvJPL7iTC1JvUkKtgCUwIOkmmuI7E9YuEHc8OoMTNJRsyVCI/3yMz" ..
	"VUBkROk7bFi+54eIRADrIpftAR46gjihpntr7POJqXE7sxGa3kJt14+q3KfkWTPTq0lHq766+NxmqUt83wmpFanSW/fwGHB78cZY" ..
	"KvkxAZijcmtOdnnmuHfbBFbrTctPuRwuo0maP1qfh20Psls7VWEI/SwrfZ44l5yXfHuGqa6DFHU4VN52OrU28GrHVbRPvHEg0kf+" ..
	"nl1aBP52MyQKeFSZvcp2i+JkfoPlqRU2EhVEgWO6Yo2RrtXwBoSscxfBiYm+r/iiEFxfl81U1gCK2TV+m+sbWaNjqkspAjyQ4/U9" ..
	"N4lbJ/u/G8Afc6fx4wnBgng+o77L7w5gDPR4GDcY59VuNGR+TyiMshW0qfLirtjP7D3BK1kc5K8+O2K5GqS4q/xlJ4OEKIO3zcQp" ..
	"1vxXGSAiMMUdUhDFNSaJXCz9eqjFPQsMOSH+NrSKRymVyuVLcjna8HNfy+JW5hKLfd7rQvU71jzdJ6y5O4cWPJiU6GWkM3SYw7VI" ..
	"ncP06PjeFhPWodHv7GFImaymC0ONEIrXxYYybkTFy1bn91Cu4BzqGbufjqktk3/KwMUTrWuIc32HVMV7zXmdXrk+cn+rMsZol6f7" ..
	"WWz0WzphmiFuXTLSiCj99u49SOAVKRBIYNvgz6nsp+Ey/W6isFJ8QqodG8ipt8sb5oisbblIR6Wpt9S9hp+tOJ6+arm1mtsOvn4M" ..
	"ESVi+i5NHxEQkCVq7QD91FLwwYWOu2KpEj11lbbfTogfnkaKdj48yY5O5H9xp/mpbrcpOuEoD8E8XJKxgL7FEOKG+pIgD9Eyf1wM" ..
	"BSFurQQlF4SuQAQ75iRlpCawkekSXV5irklNFc8LVPXrskXEMI8mzHUOW2LpY7S0lnt/3s8jXpkSZMvvwY6CKYRNZXl7dR+cPZYS" ..
	"PGu5RRoDupOJ3z+6BiE4ZJmFmUvIM8FtokmEZJOxpZXNlfpbtYd/I3GzJ7exh6v1fJERnGPYkjD8S3ewIkuoaZm7NwYYXLe5N4sr" ..
	"C0Hcuk3/p3xzgH2L5aivNRcDd5ihXdXXUtBZhBeZGP6F715PsCoEYQcxoUBx6vVK6HsEDiSqLn7h5raifazFbeE6XmU7CP341Mrc" ..
	"/x52m6ToytxqDHyW85cB7FJGTDuBik0OIbBy241HKHerK9UnDW+oLuCcwMJG025LXNLy+eUt9maVQtQXbWglC9vXqQJgcX84KSOg" ..
	"j0wpbTChf1aB4uOojj7J+qohFim0OYUkGCX6cBjBomi6z5g1ZV9SoZDUeHE3vx1b0di4S+1PWSqlXZACaDETa9WIkoj2zOSIq2pi" ..
	"cyZ3qgY2AOqLGpB344ZMptjKEwzXBtJdA62UZqi+9+dPD9mBwfeQ9IMu+YL0xvb+NuZkYdhYK7HLvF5fz8hcxB7THeCicFsCdCnE" ..
	"N7eTHGwuSI9rQVbLDXCuXQVdC/+xsFf58h3fQNsn/mnit5U77C4M/UFyMBYdsSrmF9zACxkA5m+/pDEr17PD6QLH7Sxw9/tesEtZ" ..
	"T9iytG7E55+YyuiW+E7SGIS5k4sFk8DVo7v+pLbdScrMJ4WJIOMIkitKgVRoxn8W3j+jLCDkNMwzX2RUTTpYqs3rQzzsck4NoBne" ..
	"QacWVhB3Ry2T4GcWvMJ1uXvGyM0P/jp3OYz8mP7oQBJX2lOQ35ZwdaiN56qb6A1m889wohuzq+UFMaZiiW07KRwOU4vwYUkDdC1+" ..
	"Y96SV7t1gVblKciMNM9912Rn6KKpnhwvSLYme8KYR1+sp9sg0l8wHMsA6hWU4IWfpj2n9A86XItdVVJgOGCgl+k/cYNkmSU0y0Bo" ..
	"OYtRJZWX4a5OF3CYijWblatq3umYVSvtWUmCPPNE5RUL7uFGHLpwfkN2GKv57HgL6QmT6zmWlgHBUSU3XwJP0MF8A4Yk7eyF4Rk+" ..
	"j5Tt8VH72u78545mNx6qoRxeTOd3OCesB7a7BD/WgHdQ0hOtT0zn+zQKl1wF9aHADCcxssKlGixR8cLtXI7BAyWpx/SnxfYp78tI" ..
	"7gQOR1HqeAdmu33Pbvdlw4ZK3udajxYhi7t09eiHU5M9nE5YNMWBySD9Vo5mD2KXiJfb07eQa85Q/U5fbKIMtCddpNHH6dTQiv/c" ..
	"YXNJ84VYRzKzDAJjYwUOKmK93smLUIzS51OO+Hv8QxKTtQRuLjf+BmOsva3FA3jt0TMmonFbq3oL3kIes4Sb5gpSrRQYLdMhslmb" ..
	"eSjLfOO0kHD5ZmHLD0E5M1EaFJkVFd5A2W17oD9pcgEmA3nVeSrlfWlazzk/OlFYzmDypdlZtHZxe6q0KAw52P0oWRdUUvkoHp2f" ..
	"qS7VPT0givuMehi5y79YRo0uKvwsIpLTbtAl1C79lbqSf8A7MKz2GUhGAf0rbc7mDJ5b1DPNw+GF2XbQH3T96h/1d3K5FjZP+LZ6" ..
	"RP1SPecTle9ITaO70i271mjeIPeBPZpwKZOX+5mj5hll6to5Lm0bDmr2c7RUy0UtPtUGWmHec8vQdBQ/cjmSCuku568KgtenUH0n" ..
	"JBVh8qZYpDqDgcHrBQqlhq7OYkSVmiCuvw979dLTglKHGL37kZqNpT3fZ00bOLStA3vPy9o/Lkrvk2fVppR5rd/4oaghqY4bVpWc" ..
	"IM13e9pSE18ndrKlKY+hZdXkZl/8lQ9yOoWzUycQ2PY3ykbKvzbv79nAwkX95tUecQQeAMHc7ltrAV7BdN7PyXTIW6CdbIHByc4E" ..
	"P/YQDX4BaDuJnvVLml0FPLQUUP8r1uX2YwSGade4f9i/cCe54FMjwX/DdPMsumyuo0tgEvCg2rU3dOvjxsLECNojQBSc9iEkACSW" ..
	"yj0BlGqI2zeHdsJnYfmLKvf4os6Goiy28AZVbz54oQcrSdH1yinnRHtS8OrrCulpqUj5XyAv/bJy0GKMqKvoroYAkIoe0O2BqA0W" ..
	"yYCnIZsQ8uqylTTHfVcs7V6sAgsU30OnRHg0yKbqEEgWOTwQnxn4akF0rT+vKbEFihuAsAqn8rGWxUQwTzDuZt9U4FCPYVOLbn8b" ..
	"6ZLbODo+KIbpWVxlQ1oCWI6Rk7mL4PaGInpsTxvipyo3JvBrxSiiD8oyXWYxfiCEj8XNs76Au2MzHjazZzP2GdiZK/7w2/0wSD0x" ..
	"FRw/dbCbQFegXmbDjt8i6arUWPbfaLIdNYpIUWahztRcx64llnJBK43LQs2QoKh7UywJX6wJFL1Wbx4+BloTvPta1je4adDm1CeF" ..
	"dpUHFYj2PUm6obGWchJRGYMebTmqS1XvAd/+cPHDXJNCI9ybUUhJbD6VB8TY/rXs3Ed2X3xrw10cswthW6zrwgluMRmp0zvDxg9g" ..
	"WeQXO19UeMOKVEnzounteAVJxdpMjENZi+HUBG1DW69Kkv975KTj/OaFnmiLZ8NIb81R9MO+T++5pEgEP/SgKUDxiO2D98oYT2Uz" ..
	"ieFscE/Mb6aaiGSG3Hk2HoH93KNgL7GciQtcas/1tdAfkkrSL4knC7ReHF2bBEdbVQ0itL3swJMSfP5atQ0c7PrIfHBsNdhurrSu" ..
	"1nonZurp6LmQ3uyslZZjVPdAJa6CirCfAoJI7eOHzYoFtxhAJciBNsQkg+LYG2tllAM05tt61ldpKPLQ5bxidpIfbKGfcdyHj/n5" ..
	"W/bujF8Y+Tn6QrpqFGYgE9dHSFZ6SdX/YGE8PxTIpRqBUe7ZhQ8mDyDnN5qLZf8KSbT8emIZAyN+LhA3eJ3Ao8X99c56PI9skz6I" ..
	"Hcq32zXuNo92pbr4Qg79dhPBhJi2UZgmY1EVuR9rP4kgsAd/ehFRomiDE1hJ4Fng2jA=" ..
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
