--[[ DQFarm Loader ]]
-- Licensed to: GNURT (1 thiet bi), Gnurt (nhieu), 1 (1 thiet bi)
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
	{ seed = 72776732, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 70130698, exp = 0, plan = 0, hwid = {} },
	{ seed = 69695599, exp = 1788089514, plan = 1, hwid = {} }
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
	"RDtp/SFVR2sSIbffOH4WjLMjDBEkXTB6VVGTVu6U+rizs6S8C7iXjufoJDZ7JAN3bzmqe+Uuc841rcx7h0u0kdoNW86/zoBN230N" ..
	"heZ1KlBXfjJKO51SykPWBV+Ud5iKsK5hOhRYwq93szoHDfW1GQYbZJme3BYELfcWPughGePi/r/hOHt5iqlpepQRtgnvp2x09ZI8" ..
	"8ac47yNIMDv+TAzHClPTWRyoVswRUh7s5BkbJLHxi2ZrYpYs7+5ZKGztjZgXZ+yvgz2yuTUAtOknXVnrKAp/5W5UNlbm67oSnO2J" ..
	"seqRAMbEo49sFnb+r/YvWpUNhKeUv0BCJcjwSA3BFORXk/tO8ZbV8Mh+GusYZb2r/frH/lqddb66wf2U9kn7v1miRNGhWvkhqyrK" ..
	"lv/tJwetiXGBtX/zWlmqIalJ6+nLDQr6pQepRs6sXNbk44PThAKRt6NG7Vi4O1/y1IHBd2UTcvVzDzdPExTXsus6pf1hhB8+80Yw" ..
	"cb528qhSi1vaT/6SiQjsHpiW+8cqfmrOa/pgIbWvSW2/xTS7CP8gqcAyUQ+brxba/M1iuNb6dQLUq99wkU362mIANzcrmzKQYwPB" ..
	"gJhvd8bEOe2mFQAQYGBmfChU33ZSeDKvL8f+dVeWJgOPMZsyAFbEcNFamuXBuOFQJ/Xw5kdEtV3lUoYnXwkgTXXLmwSX6nkvd+93" ..
	"Yulcki2N+rvuesOQf7ZCLLWoLDGWjkeBi4BAsAUrXYlMjBQo8zL8qCe6uQf4/CHthI6qX+RQxf2aeo11QhYtbpGL01zT/JjUNNz6" ..
	"aE2Lf+kzS1UreQeZ61idfgtQbsJSgV4LAROmQlzY4tFtlh1SdcP48eA1Vk/ejA8BAPfyWgWBecY4rxiGXzPljfbATlBNGns2Aa6H" ..
	"E2FCL78CSE+RVPOME7VbPqsEknqEJ3WHGMQNgc2dHTy1+EyoQv8LloSSODAFa+Utezx1R2udwxX+RL7mrcsEo4LVYnSJVdPHCp43" ..
	"9tyIqAuns3Nvzy9iuEB4UspRy1i0EaoqD0oQrLzIULuXEvPYXIlKn3LlNUSPs8u5uRKCKfR1FFuq3noITt4WMSczSfr5XEhzVB/v" ..
	"0LaBbbowdCn/7WLnnPPcJ7d43jrgGoByES+gRXf3sNRd9qmx1poxqsGlKqq/rteAWGRxNO2kBUGYYfWZLZzZR4a4Zl99j54KVzR5" ..
	"3nQRoNE5NzjT/bUvIdkI5UgSwNjeC6siuvQb/9VT+iH7/ZQ1eUmLeV8HfsKclOTiGDEkItwkapzjeU2jZ+lw4y69mMiEkfwryCwm" ..
	"LOh/wia6AI25gMycs42S7XAytn94suMYTv9ew41nMvoxG/vxmDWkxg+A8xXicrL1KMt4AKIhpRv206H/SxfqGwrXfOfWJyMXE1qp" ..
	"zLoMIyFAQ+nRq6RpwHBOItRJHNDCUTzMLEhNhiAeFYQXMItViLc4l83kognWcQ4SoPhBX2Mj8FQkR8JfvIH/0k0ijjOFoG7rDLsb" ..
	"4kR8MB+kJrFfpcTva4jULLfhFR4qi9UftruUNHRN6HPxiG/oRJkABcMKwQ+bSBOw/YFWpgUajtZ2yNffxvNBrO13rIzL73al2jF8" ..
	"g4n3AIQw6oDe3JqeVbqxCMfEJHA8mLqRfrQvZQJVvwPK5l6RVg5DsWFsvK0edrJPoTYNKD1ig+piW9AF6+XticU1hspImHcYZICD" ..
	"+RrSkZZPphl42+xwuyE0w1lbdmNkv/WXFuv0quojehsJZXxBLHwhOlbpnZlyr66S90v0QjC4gEkcj4V26noWEJvmop6xATbiJOHo" ..
	"ps1QZdGRITe17m1BDZSH3HeuLkTkAtIzKHKgEf7fUGJq/ucu7qsAPSpQCQAbTE23e37wp5G2CKRusRY2SnFQMfUKZc6N+yJMuQHy" ..
	"DbkMToSOoAoPQhIvxs1Alg6lCwQfzjJq3jUi2XB6d4DaSvobgmenGqX90WkWq5S1XfGJnFWecvxQCRl5NpTqN8UZ+JfCAPe7q9AM" ..
	"zKlQZ1ZFrKKeISlempau6tax6eaTEYo2HHAVD1GNBd18j5BiB1TZCd+n3d5AZPQAafq+i1kskbGpCNZnwnIBZlRA0O28ndY2Pe2F" ..
	"b6h8rfo4XStEhY8tUqIeK+LH0d+7MlS1Oj1Z/UcqtqabaoBCRbLT/bareYf3mPepwqB5COkhKyLyEjTGENLVSvhbBssArAS+qUiM" ..
	"WMVa6Q0Cd1mLV3RNNojFqQWALjsD0cdyxRAQMPmp0cUCVVi0YYqC0BSE5NZ9i/8HuIGFLz7VRzUkIa+yYD4msmaOZr4NIhUuGnAi" ..
	"EhJoUKoVFg+WRfySL9jw2KCDbRMY4PTlLIvzI8OdkvMOtOhklXqv5rt2ggI3raSCALM7TmX07aEVXaJTuKRusPN9JjM5SdMqZoYc" ..
	"INSYGi9mbGx4Zo0GQlbJ/MQTjEcROMiW9vZ2c78TfYncE2MqYpkojfX3LXy2UazL1zbJ3U+T5h4MBkK95bxopZDG4bdfZGQOAgl+" ..
	"DRk2Hv5yeLM4FAnVLaYh3pz3WR+x5XMucEJ+LicqSliztBnqeAnpHOg/C0FHjsQVN0PhcFXPo/5xhtff2HMJCmJqi8qVd4lW4iBk" ..
	"LdRqN7g7lKoxv9wokgeGjg2YAfhwwBYMLdd6eC1MNQZ349pQrfxBn4HQpWWAMvI3Az1nRFkwtYcNEsVcC7Dk8G1GRVPivwAM16Gp" ..
	"Qs/DgF0+ihuuQUQYs5XkkGmgcT2cBFVZ5HLI1uSHWMmXPC3qULkJqHbq3YxhM53z2iXwM+fza/SqkgfHBwoWK6LXKOM9ZxCGmXiM" ..
	"MkcNK0TGQLbMFm9fh70UgBAg+Alm2QwIRoMWvyJiu+7VfD67JHOqnf98AGOHi8W3MnUFTwTdpzWQ1qafp5/rCLAL4M6982ztaqw0" ..
	"SePhQpS6X8twrpZwiXTGgpxRCg+CVH7l2W39VJ9XD2ZoFj6tXRkpmzU8EJJdpdSCO9fTQV04pB4oFSL0QE+jKjQ55ErVzBZoKW4T" ..
	"pNX7bTLfFkDwNe5Oj3BqoomSuw0OLYdIhen9zCn35+kYDc+SgLINCLXlE2+5h2TAt9h9tuciE66UUIvjNWFXK6UN9u60Rcv4vzdg" ..
	"Vgr7gCNCJPI3iTvPZiC7Yib4VhT6nHo2H7xs4uGINZrFtZeQCDhXwXx46FgLGsNSn9vq9rGnSqWAAsWQCyL/x5Js5cwKFntMnmme" ..
	"TZ8NxAKoupng0UHXvDpzRZOtHUp0HV9Vsd+XSQG5dsXA+iHAG+TGnYYk6rYT0/WQEuq/A8GrGYXTIk3TpS/yfVfnVpodZrMOepf9" ..
	"xfL+DnuQcG7uZJ4cduI88rHW9JO+J9xHrcstQ/VA/IovCf7DpDUBTcDVcFGL2cRUWLZ8e5b8E52elnKJ8h/SLIECPHsZx+Vhm1b/" ..
	"N4CHjTbZ3IqobVB/kFA5hA7Z3zL+NxT9a/7iXjgoy64IHOYVgcZspe0VM9xcPvABMvX0qMNrcxfk7Vcjgw9oU544WwzT8tJtuatE" ..
	"FQKZbPOl9Rna5lDIpR6TmOhwHXqvpsq6txbQm0no7KZlj02F2C7OW6xXNj0foOkZrjoEEB+eWV3zPY4i6q4Ruf+6x6Ar9DdKsC6G" ..
	"1mwRc5MTJ8z3KxFUUnewXct597DHI/YxJDRi8gVqodnGT4WDW1R1ZmjF5ACJ/CxMOQc4dVGpCwLIt6mayRv/eOBeUMSK+CbrbAQc" ..
	"tju69Ef8m974cSXB/9+5X76kezDkyb1GAD8xEmOVottywQBN88ARtZQzEW5v3duPmC1e3++hdIdK2klS5hWIP4S1apZJSdoLiG7T" ..
	"wDdOsiSKSTwzJEczfJSD0nul9xPr8tqkTqTTavZJEY3u/eubM7kvAq/g8rZ4yvgtgmOjAPeMNu/xXUVjeJ6sGTY3w9V2LkgjC3+z" ..
	"ATKaAmVVw5rtGAjiwgK1KzhAQKQdmBuvroc3LaFx3WV9nUpnvBYP5+MMohgiDG6RfmsIsSxkoJuZUzF0n5Tzfl8fB6kvfbBX+XYb" ..
	"iDB9Isr/jsZ/ZlAO+nQ9T1akI4k4edabLSJRmSQs1IM64hJqBhEU0SmZYeXRIoRnSN7PpmwtgCEq+A7J2/Eh6JiKAI+LAI+J8eJx" ..
	"1rLKw4rRzHtznGt4FJMLIjfBdfouq5U7KsboSxt64EeGUXWsvkwN1g8RyvwBImrF6ksXtdqj2lBe+X/amM1GPA5ocO53LWhu94+k" ..
	"OyO04QUtR/w+7pwqO5o2cEx3VIIUU/CtAvxNuxxrRpVvXDXXaeHPeSBj+SraCP/NP5FFqz7t2dpYuqTWyhgGbckPzFheCucHWnnc" ..
	"Do02hMMZdh0+d6LtuPwgxGPO9KpTOMrJ05Td/oFE+IE1DrK88vz28q9OGspWFbJberAr+4TbX4vGyoXZWa/CxV9dGywJhDVgUTKb" ..
	"fHNriUwQqdXKBS+TYchUG4JxFkQOU3CSBJ2mOb15/AbrHAct0S5xDJ9APGbZEd+cM3MbE0Sw1GoUQhtWxpgdaHDLodfJDqrDzrYJ" ..
	"Tk5QHYHsOonE4KkBH1XBHuVwb0Lhr3dRj/D9JOq+Bptf8W8Lny2owyL4mUaPzGHGvW2caQpSfvkQUH2e8DlwmZpKCyXUddj79eop" ..
	"1xWUMuLfaQbF9i17jrDpdayjmHtK+9MS5jVjjG6jRwAPxZBFSq3JJUjondZZmXjKfaWPzfD+1tcuBsJcgh9b/6cAdJB7rxirVYtu" ..
	"tIghPihL4Y5WMmP/Pj0xITk0qDRnPqLvfUb9pgb18eGhJsDl3QcvP6dkTUVN16vX24uYyHQTFOAprzPPDfuQuv4lVxZF313rEKDw" ..
	"MHWepJLNauwqiZR7Ll6mLy0QeeI6a901aMVwJ8rLUMIw6bnoMvJlWjP5qyiFpQ+LM3wqVZ26cR26xRMA9VXjWmH1cek5tQM483uB" ..
	"SLdcJ+bP53txTfMXNbitZaJTTBJZG6auyql18kJRcw1WC3qTByWTnIjZXk0Oht8JAqmcw8iGbd96nq+Dlt8MnW4xhEHYoOAkm9ZS" ..
	"4QSqDCK58ZN7kbenQ5hH1oLJ2AJeXatUzkMEGTXk3dUCaf/DyGvLmIIUYrtj9i+yvldeiUNEcH0HGYw2yHb6tssKwOSU2J6Wvw/X" ..
	"LQijtgXTNFwV24i918jXZ9/nGqOyjhKSYBSOjYzjxC8uu0LmuZcFHsH0rsj1S4l8fUObGMNB4ykRoc3VpCIl3lnAKHuG/dzx3Ya4" ..
	"Az6j+n5x2IwmjbGx/yrdyelsGtUypsMc9CKK2dgRJBAAtScovQPmYp9yHvGd1vPwDbWXC6X7qmZ1ldqZXMZrG95KBSF1ImgoC57N" ..
	"q+AzPDt03sfycEMsb3VU7ySuu1/50PGpd/q6OVAnwOKtkFgy4vXR5xvYja/8ootX5QSvPle7ACWkcoghHCfjfF4exIEZk+gTK4pJ" ..
	"sZbK/p/XqYiaX9zbmdPHWGUZvTDbPV4NyjwLmUJ1fFbLs1K+2KPKVqOJ1tWBS8nHJPLixnHzY1/04GhgDkIHO71264CaLjjVYxc/" ..
	"WCmaA/w+wzL/uWodp601RLYxwh128g7W2p1cn0JWg0JTtf93h/yQZgJskB42sM8/9aDDHqwqiH8WrzqU1c8srfwX3hJnxgpN3GOV" ..
	"vNiGpcBRgR+p+OTm+gav4iHnb+hfoDyQS8CwpkALoL46g/k4NXp5PMtscDmYVM6a6Y8J8f8NatzVQexyn60u0ti648iTPlR6mzEo" ..
	"+D1tQRZCMOFgTvSF9PVBzm/RTVOtwhFTKkKGUsG4kuL8mHo6+5XivGeMtqNFbFLS24AvF6/4McO0co8O4kAFw6qIaVjaM7BDWH28" ..
	"ypYhCzJkqogRpgn3AhVyQRFm3wdtt7lqmxPwi9jtHBfegczUUF2e2cjOH4XKCHbEcaR/G1TEddzBpiW08O5qGU4HXOdbCh5+x9H8" ..
	"+XxCb8kC3JShAyHbKB9xrmCOR1s697zNiSpmO+rds66cNwq11BPgkmhQ/NuG8AcEq4I2FnOO7/hYDsvEK47cLknBXTprWz2qZ5fi" ..
	""
local PAYLOAD_P2 =
	"ja+czFpun5EdKB+VIit/bLKBUH11KIS4sAbIUqCeD/yxGTTYrbIvUGfJ1t4YQgyIME3el78ta+dbwXQu7Nts4jnfbKYoOgBYPmlw" ..
	"Mgg/iG9J0Igy2K57FbeITTG6sn+9uQTROgZeMxn9WLXZzC2HubsM7HpqxLxtaUtc5snBB+yiJWkib7gzmVnsbdm4k+xaUvLvnhIm" ..
	"zknqPG3JNRVRyA1JJQ70L9O2T3MokguELmG1H1EgRirxOJBKaATpvkHg2cSJAgH9JyPy2oLje91inW8aV5Pv+WiWKxZp4uaj7lxN" ..
	"FPog3dHUb7uUE5dYTZhHOpMr+tPOcPAQEQYRRYYge4+dPPN6UQXGtaZx+1nGv4UGBkYoK/VEN+vIDs553JezzF6uRGc2tmvFG0YM" ..
	"H1CtqThWbEU/2jITmN9WqdIBXsqWTNwbofcoi9MKtAouoIUxiJxsyzQ6r25nPl0wUclPMh+5I3Hcd0Qr5J8eV15i/LNTCRodp4dd" ..
	"sGhIYKxMoV7Ztx5LLvzTo2ffy68fjqZVp/B/32IF+Ti25/1aUsQ9VGVEjWFBDHmaFwZ4lnEz76s0kD4RUpH2Ge6ZXH/PmOQjAgr1" ..
	"RgqLU04PivN13xEGIo/qTBk4AKWixQAXLD1XAKtAwMJYWB2ToZ+DYhuXlNbpn/y9AzFQ0JDcUBuYUC6F17xGUhcE2PdtS96+YANJ" ..
	"YaCcr3onCcZ6oskB9Sl57bdyfxrih8J2FxFJThwKapbO8tDhpEeroiT9G87KheaWgFE9Golg8+PkKEiqfJVGLbIU9FnCHF0k1xeQ" ..
	"fy3HpvMuCgnsVT4W2dzLvkLCwiJjHWvlktMNguperVpYi3nV0MNT0FhUwuXzjcP9Nk+yQMH8ESjMnXR5xAIC5AdbZrIqomQ7j4Vt" ..
	"cmzatD8g4xpVvUT/tpvT2OSv6RqvIg6SoKFwCLMAujyFIWNbpEmU+p7W8dJqEqziLchPIrbX2Y20DRP9XoC6aWFJ5r4Ucdelo7vU" ..
	"4FcwRJg+vI48JvgDsrzf4QehgL6eJoY4mFv2sG3vzbsPpSsw9WTxdSKurCInjd8WtKkRCpxjunXYXEMEvsyZI/6Qb5DWZP7qtIU/" ..
	"bVoa5txL+JR+tMEl+h2RB8tE8z/xrxvF2vx0tReLEQZfZBF7popdQKg1W8iU0AYpdLuYJGIyAW9F0yBAEc6OulH+p59+vR8NOKVr" ..
	"Ki7i5bjynlghj4ChoTvo5HWPf9yZF3Cq/O/jeNStVJahBFr4Qt8pOqOuzZiJdySiardwuuOqCzGmQx5FBWYebG2u8C7VZQYWbWN4" ..
	"DOgNejpX9mrZEd/3ov7qe/0ZgniFGbxe32Nynh7/cYEDABeLdD49LTAbAJh2/E4bLWCAzdlpG6fkRRol6AqVNDfnBojg+VuEnUe7" ..
	"vjQ7S9JhMNlbtR0br0SYBXcWtVC25UGsUnIQt8QulV4mjUdR99uEE6QvbxVVOQtQNZ6jBle6gwOel5DABYR9l73HkkJeS1iOJ49y" ..
	"mG4+ve4YWhv7WdSMUt57PW98PGlx/QMLlY6eIGOkzhhDAGT2Du+vc7sgCpSMdhiKS6Fn+GhMM/70OdDDMOEPC7oY06jn6bJV8Fxl" ..
	"KN/tMpJT3NZxaDAetOxEUPuRWYaSbnmkZXRn4x9V4g2gFwq0wVwPicXaQQRK5iVXLpvrA4HZSTQeqbEAX9My2gVqGDjqtS7kzwGm" ..
	"E51Dmp9D8TW2COFLzYnO45DN0xB26/fW9t3/QbT9r5s+ywkOliZiTaInA+R2aGmnpJ9E9NwCTB86LnJ0mpFJSAmaOVZfm3wQf+MI" ..
	"ikXZWxtRljIfZRq+zgERAs4DbcrDqknke31rvQfKQlZegEDQmlAD46+8ykE4hJr4TB86ARMwyJnc8VIrG9U1OV+40O6qLGs+5YFK" ..
	"SKbUZvq0h9K+I6qiZCraKOcQM6dvBJ/OkZ+miy7HkP3JTtCu8vBEump2joQQl+SpgRSMWVYg4Ussc7D5LPOZEhwxJ/Oj8cY0s3qy" ..
	"Az/UrcNBpm/Jnmr2Re/NrDrM5/BsqWIYzmblIeAPV1mGzFT9Xk5Kb/AzftD4HhisZkLUVdCRuAlDrJaHr6WW54dU/xBLivx+w51O" ..
	"7PXEX2Q0d/gPNHq9Akb8wB2NlmOaDEs2eiziZroq5kc11BzisALD9TqFUycI5tmCa/Vo0H06AxwBpV5P9eebU0wLZIAVlPE1kM+b" ..
	"uXAbCVZWbcdZcxxLtf50V6LdNR3iwQKsrJPqEqiagi44AdCVPB0eGheV/h5JgK9kOTyodKYvf1JG3+wTSIsv+npWbXLa1zow62hj" ..
	"eOVZU8lYOrNms2/XW1YhzRDiHhrdUiq0wXhI5V1IfskQj+sW1E+jfuXGDe4lv2A3Xz9emKHp/a4HX2oTQPJWPhfkOaxUqRLF23sE" ..
	"ckCrin4MWmUk4+Z7Jol1fI2inhTzP9Smn+zYx5oxnsqrNT8LFRywwbbaLHoqdcSnxZyGVXpfUtWVh+HH3w6w9v73Rx5rQA9niJRT" ..
	"CilC1DmrOOOLO/KmnJhnmrd0yLf+T6v5VhE7deM9HSjgV5+eRcce5XYX5zfdVSMhuzcce/8R8j8IL3ojPk4kVLX80cIT3Lwog59U" ..
	"GAxqs5T8cXmzZqOjyf/Cne37sfWWnBOq8KRNMXfVJEsw2BZtyUTPkxDvo6OtVQay4h3E1Q7HRnkKyULLecWI/zQ7FEps7Hr13z1W" ..
	"5OAib172K/9D8tKiqxxuwc9y4hHGCMsW89Nuv8ZN0G2v9WbIQkGJGnuiOEv34mgiJ7T59Z5+i48F1LwO2u/iFqUA04U0BQop05Lj" ..
	"vvi5Shu7r26iC7uxA8qk3/GZuH/vGb95BN7BCT7EJYuFZh50sqhEA0iXzH6bzbxULPeugRccadmkMpChPKwTW+nKRra2gdeHZ0IO" ..
	"jFTfnyjgwpA3Rwp+3BpDM7M2zAYA01hbNh5fGS1iOhBGNFVHeyVsy4qThXftKaOOTuUkHgE/mKd4Nc+haWfzflWhuYS4eE2Vx5fX" ..
	"XH5eXQ0N/XRwk6W1dZogVrOBaWSdutD91P7Iregg5t582GH8PDeK9PFXNDerTiovmMJUw7IXtsm82v8QduWdDYg9A3hjH6ozyA6D" ..
	"BueXeugZCfFNR/1TepbGh5ZKnH0JUf4vcGS/AJ7uecSLRzvjOqu3DdXhss+4//rc/hbva5SZXOsU5yf6CYmwewpyJdkAaze1RZko" ..
	"pmrUlJ9NFw930jOoCsGZfrYrsnugDhbq6TsA8HWplrCg47ZT16poCj2xBl6n8jzO6Q32DoIXAwAUP7kg2/ywIr+8gBzNvVsAv9NS" ..
	"SoVmSpATj/IWxDGGYyqqGqf6gzbdfdGAHU5E2i+/DeQ1Bi55I95CFmqIEtdPo47LOzWdpQsQsePHbo/P2tETRO1REsFMDuIK2Yer" ..
	"r7YfCaZar30jQgg6mFp1erPfv/87x1084vua3TUKRx7b7yKqyQOVAxRBK9MKGD1XNnoYxWBzspDvt+fG+mtzwc0hZ6Hb0wGi95FO" ..
	"NhZaVJ3QiG3YoN/4n/TKmo0/zqX/Y0KBBdKtIVNrEchfk2wh4OgjIsG15ZkocA7yqEF52dUM1zlRg96u73nI6Gpz4Fl0J4pnRCXf" ..
	"uWfJoZwmXM++NBA1n0kxVUbU9FPHOw9w6TkogrFgeibR6HN2Ct6w4bQi6t+PMCKQ7kgaaEphqTClnUdEJVH7M5NEGcI2maOjiJ7B" ..
	"XOr9Prp9RwSHNpJi6kJWrJ4XKSlkb/xT2v8XpZJC0qG+oVPBn/fRWc2OBtZEypmy/RdszvrCCAeZBUUP4RVWTk8sP+X+A4fHkQId" ..
	"jMioBozjs+pOyHbCT0+VA8sFUFZV8ngNXZUbQHviyZOfUmh9ow/JILzNw0an0TPShhDzbALNlfMeXRLAOjSUiU0VngDgeS23TkSG" ..
	"dBQgx7o3ew2RARvIXr6rBfwhJZTxnv+OFnqeQph7O6V582mYMcZXdEj7B9slIs/OJ8CMP8bzVFTO7h9+BBWSZOiPOMwhZeaZpLWN" ..
	"TMaY+99NZqzuZQ83VLG6T8hEbcKYmTJhnxMFZal3WrFCdFwMyz2IHMs4hPgXYTC66dvJu87ZVTc6NftVTyhErsL6xw3ITtjMzsUj" ..
	"XiHVt1+xkAqF3CToLf4OHTzoSzgyrgut/I7l9FnsxEslhhsixmW3dI3b5VF6R5JTL5nFt6BhOiE2c2xj2LiaFLf2XTQmlxWuiunA" ..
	"J6eaIUmViNVua+02+9C0vi0Gm5Nei2OsiYW5KLFWCcKGyR3JWch44eu7TQAu1+tD5kxXhDAe6z121wbKsrLTQ7umF9wtnRnl59y6" ..
	"/sEJDpDFmWbvMvsVQbNXvoKg+7jMN/0ALCO5AsRRNKS7dUROCoIerdUnt1APInt2V6tax9/7pFElXZyAMZWgacdSRk8w53bcaUuW" ..
	"CW6euEfGNDnz8YR7DFBWLIeM8oQGvlY9R1N71BACVJeFvR+SBENsz9zgp8ka/1QhAF5cOASuCdR4NVr62RlU9dAdbyMoPLOjBiFu" ..
	"A17ZZiGfYVvYQSjH28+3X4KwcVE2olU1nFzx1mvGJkCWUj5vpPCOHUcdIrhZ88HUlF8lh0gtxJdFtlpWTVvyrbB0mRxOoRoYaP6O" ..
	"s5XcnELH5lkJ14NS+UA1ByotlNSxeQOTVF2lbakVbbxCjxIQP8HaUsGBRle6Ab26ltgGN33s7FFPHREsEzk3JiDs8cpHngTrNxqI" ..
	"gun+UroZREgQZH2UIX1+oO9cYGQF+vOdruINE9Owwk2olQRKNMLPOJNFJ2z69YLEWnfqRRQeF8BR6x3W3WPmhablAqFkDWYWWT6j" ..
	"yq/Qh6C4F7rQlVN15iT4qBLY5b7jBseM4ViKOfdsyjBH6vfPKyZ8n9cNLvipMYRp7JWEIU8cqRVXB19XIaI8gva0SY0ehvu/wjn/" ..
	"mnAodlhQIYyIJMr16KjaMS699NOdlbNtNQjZ42heL12Zs+sZJgDvZiP89am424dYnu6RH42PcVfmMNYwqJSDZzgqZNzY9yo6lNp8" ..
	"gz+o2Qmw5tVCzE0O68dXpNP3iG9o3elXqqzcy3g9dKvaP6tZbPsx3K5M3dGKBICJBn5U0dje4gzdpI77cXZjcn79uK1UlxmyRXyz" ..
	"GJue2zIZXlhMc/Fvxlja11SPpZ6gKCK9G+W2/WkPvwp1Zctziw76jF4L/PGoJV0wEUuOc5EuCOQhPZYP+DTCebEWdDkXJ+PNkOuk" ..
	"F/fgXH3sN2QVAAqairz7Nd14qdaj8EpS1EVRCKtCHRS8fEzl5icxyG/WCldsFsGGkdsIZS7XdUOFJcDihOvgvDMy3pKLw+jQL0zL" ..
	"bne7FRLsLKs8n3F4N78z12yhZ0pv1sWpQCSpundFNK/gF5URSVlMw7FasuragrSHuCW3PN7OCyA0LODX51AJ9QD+UkYebm76m7L1" ..
	"+bGfh2NMDTw+4gHL5MRWBKrvy/N2FI18YLcCadnmy1h3piklL5Vwk7QQeKcM6b74ZS2sxFA+oqp05Rpmf5SxnNJ9nrVs+cxlfeG1" ..
	"HNmnmlLhjLXRFJ2pGAqfZlmeFbAVe1By6sybHU/RURJcHayQc88/Kk6WybwjSCBiRduRUg7IMaJENUV5t5MV0XeIr2FSkQNDQ5Jg" ..
	"jaNBMkcXmLMPNEm0bE8h5PDJ3Yo9yMDjI+L7j1VL8FxVuXn1/l3UA6bxyByzsjCS25ayKjixux+pdvJNvsJQ6f9PzwfunGKp3212" ..
	"cOOFBF8N3VvjZAu7iFb/bP4WphmIEU2H+/t9jzfo1YtNf9UZ9FC9GRRNm0hPOHK3SMONWzrI0FRhBo9xX5fs28uRZ17kZjKHIN96" ..
	"W32sToj3pPa0EbKTpoOAk0Ju78Rqmx8m1oY6SFpsS0wxWuF2Gxsiqe2XYT3M5gF1B7yT/RUPlpDbeXNoTI0Puqv8upIxG1dltNcm" ..
	"Z5louZ7hXEqKcizzloEsDGsfBG7+fET3TzOVX44NMQm9FCx2yYAq7mCs59ffwgVuNKFgUtMKhIAx8BuladyVKSEK60MjWvq2WYm9" ..
	""
local PAYLOAD_P3 =
	"YXqcSccNJ/ZBSCRe1hah3L12fL8icH413OrKGcU/sR38EeVDYeGPexXFT7gByoRiN5T7xydunfNASg2XyxvV/rmdM6Br4VyTjZs9" ..
	"xsCqlVtBA/oo1RhIcLlaSrMN+74aScA/iKpTLglJFKziaMdeJwNEcqRM/5vCY82Hz4zkBFoz5I5DdWCnkKToXsiCvN1RMT0EFpM3" ..
	"YqTGA5sR38bXGhnEl6OQDVzLdN5eBqirJKqNfFsM6+88Rlf3R8B+8UhyyBYQfRuhfij/MrwcEiS5xhTYpKVHZJrKRYJwVfCMIWQC" ..
	"tNRQGlChgGTNvzbm1wIeK2JIl8ECvl2HesDPDdhE90deeJWlrUoiO6AUDLb6Wn7Lzarva1mym4UAnFk+Tr/2G01Skblu0pBDrm40" ..
	"zLCBXaujq2LMFG/5b6+HljbqArwGYhBAngEv/r1/ftUwXjXnYRPuo32ZmlZU/kawy+toyq0Qjf5dbXQYkRjaLz+2KmTJUW1W185x" ..
	"xFVdb0JMqzX3CJyo/zqq+DEikhfNFA95NMfV4kF8zOR23HSTJVPnnD5KM32rwW6X9W6vlBlzadoLekOg/xTNkNtZynGFcOFj4E7a" ..
	"g3NN4+GtuLi7RWuYtYMJOmY+DzxGo+oUoEMp+ftpMuCd1u0KibkJUNhd8F8GbeHJFAF5NNGbQeaxZL14LiwTagveq1uUeEKFB1UY" ..
	"M5l83QDcdkU1Yet+S0ktmpS4nQRbMWuXaVBiQjPZChjd94gW8Hc4wv4A+bl+vtoSXNOQ0V1nsk3fzq6TAJAoJ8FERkt3qnbnDc4C" ..
	"EZSS9rSRJ0JX2u0Drd2F4+uLtI6+FP8JAtfH0c+2l06rP8kgMJsPAvT0V1SG5GhC6hfsKRjvpkAAJ01VGMG42BfczuRtG1b6aU6P" ..
	"5OWZG9DTkIeJtB0iPD3dDQaRSCn5zc7Z5M7ybGtgFARshKz59SyxJOSsG1q2YGdqgmyQFLJeS0mG2h0xIhWYzdyZaGgZSgBgX0um" ..
	"zG9xTQ2sZCBZqRHf4dd5FofAGxjvI+PFAFDtbZREGDNc2hZI7U5xn70eHKSOFHADLD3H4XGcSyYEO0LEfqTemN2sKqYMQqbCuxTO" ..
	"qs1JyR56F/LM6xad8pzZVYqC0vMOcJFF2fBVzEgUpQE4EmfYc1UI33HdYQI0tHXE+i+r5sut0pPl12c/dIStkZuC+BJdQcbO7nhL" ..
	"pPjqFjy+reBQRQ/mRbDbQPxvvs4uLjUnksITFsWXhbB9LMC+4eS9Vm1CwqWh24wXsV2LKj/PnKIS/zS2VurHp5WffGwnYW/o+2it" ..
	"FMO8MvMMq7tLiGLBdknv8WkS3JAUpe1lyowoh4cF11rM4sXIqzxhlaSNMptLGUix8GsFRPtu0gJcxiQd5UK67mxtAT+8J6vNKCO1" ..
	"HX9F3KI5zJ+h9PFVVSHLQCuKoZseR7d5HzJI0iuaiAUdszxMGPqsZoIrWsvamQd1n3bg8fOJmnBh01Rz2BUh2xHx/ogqbY9A8inN" ..
	"iNvwZbEvKDSvyuU8iwsJDZ0doi/WHPi2nrZecyioQq8cys60vzePgj5e/u0zV9JPtkzskybFAGAltNqqRfGRjkS9BLFg98WzWaFC" ..
	"GSU0Pe0rJdfPdic3NaICePpgaEFO3Tv7P6H7h5OEChBQdYi/ezf3kHUpdefnVvEaBLtwgMyJQDIrJKNQUYyDUX1V6jLQhQ+7sj9o" ..
	"FtbudjtS8F6mYj//jBD+Y2jxWeHwNMcJa1GC+/43qY65Kuh8QRm8RasOtFc2QmrJEhCqjJ3fgzHpSEK8f/h2ys2LTaZfGRp0WdAt" ..
	"VpZCUJtvwEN0HgOBEGZOuKh5mN93YOox/f9UDZqPBK0cJEnoRO5q6bI1PduzwtbB12aZ3opuRhsBRrNUBgvLeoaDDVjmQbe6s9Wk" ..
	"IiB6SSLwZ4yh5V9Ys1rjry+Z2RGmUeHXWmrT6aYfFYA/9o2ZkGQouXL20I9QfnSJG9kNmQU1VnLRzb1BLkWSsUSQdWuIyVB24fIY" ..
	"LzBTNtxGjQA0RUzK3G3yHjqQfRFn0ft1dS9Eoa14fi9XQG1j3v0bSI5EbPTA7wIDl9PbWBMkbLI1o+sie+UETE5sWmRxsJkcShkI" ..
	"qUVKgTkk+7F14zpHS5YuOFtKdHGQx2HyfWD1mIkEF1jG+Lntm+YVWR6yJ2vBYJEynJMUj2XrOcTf8y6tK/DJwjwGG8p6V33WJVdE" ..
	"wX1C8u6KUxft8vrjpGmmbRh6W5vTz7PQk638l6cU5esomZYqB2wL6VG1GOqSDaeoQ0kvKZWuNlL4j01aikodyMClfOGE7hX4rn9n" ..
	"DNMjmtw+0+Cor7gwDTskcfbuB54RatqQYhBL9CmKI99ZUUhpWRvsSXSrA5zAJ6BHLhS5PJEL0LSzgp/g1MZSHYzWK3y2TttuKwKG" ..
	"0u8OO9OwWFpPPGs2JGMUOiAfIy35et2rtTnZKR2f/WUlqpBehgDbuRLa02YF7Y8336CEuOhrFLTUL9ebKlcFX8bilJ0h25r6vzSB" ..
	"nxWJldPpeM+cDhXe24pgyD1nh4VcZH3BsCI3JUwAh09v88+MY8gctJ+LNUOaOYG/VGkFdMpz2+QuPYqcuzdc8wQqKrCxhXCAj4B2" ..
	"0Gapll4oKoujQxZEuL7SV9anERFt2U3SeANMNjnONslH2YnjtHlY/To1oIEsrHMCAm8PZTSd8lTkBJgcdPnsFKnmhZxBD9Yb1dLp" ..
	"JS/k4fMkEjCoBpFerwtLdGWuHJMZ4QK451HJTAo5hbFzr8ZvJLHqeEcm3Y2Dd4TAVufU261lnPYOI2YscEGodjXX8Gs7xCtbQuXQ" ..
	"UBD/piR8GxUKZj/6cpAT+2zA6rOoYgUxWlBtYsncqOzbX8IOotkXIeDO+kGGZfzov29rPTSdxMXlc5hiULHxOncWDj6QyfEh2T1t" ..
	"cApBz+XAauRUzTe1HQWTYJMYdDLHOMGzqbs5Km1jJYnBb/n/mi6omHWJyH5zC4jH0osEhD5+MtDdU/UvAx0wsdO4tYvnsOQxOOC1" ..
	"d0jnmqqHDo92WoDWMx626BeXF44Y6ugi5IPtnoKpAoH3SlvZnidqKjY7awEUbl+t6WTYdd4XAyjQFiJSq4gcAl4hGhevfOiEILYQ" ..
	"jQifpStxL8cJzQTaR0A1HXgBwj4czGPPfVdfOIqe+fIDqGiQko72i4d0ridOC3Il2V+95iFe6oVoHMz7hM4NlWiZOpUkuwnuI0bY" ..
	"21LgUqrjXX7oc45py9/4EslR0/nMjaxtYboGAIFrxuhNAYfwDaQv4IsRbHJPC86SqsvfvK4GzDyPIt3rjM3aF9BNePymHifRaqsI" ..
	"WUd7d7C6RXDzJh72qdpOJMbTfDYQVOxtFb343+clDbfkzdvsugiCdXsY9dNWjY4lGVwgNyTlOQn/pGx+Rh0kqGif5LtAB1w8NfJY" ..
	"0ZM7r4e7seHel/zJ25MtXlp0UQyebQ/lRV3tZGxpqVQHNCGCO9vKssAXBzieXMV+uOBvSseX6bdFb8DIalTMQ6jOstqqZa5siwO4" ..
	"w+8Xi46tdTqdcVWy0wNNIQVJpUte6Tb0ROvBXgi4gyGOrlPR+8H89MP+x29BwJmrZNJAj1GKEnn2Tkb3aSaFQx90cogxR4jNSsS8" ..
	"UL47f8whwfrpFXPpCcTVIayJO5OkaH/twXVJaH315Aq27o5VuzdRZtxqjktod77I3JMJ5SEu1rYgX3sifvodgdJt4fqmQjhhDbTT" ..
	"FvSEkQUop8ytXHaKRzVubhXaWwhAKituRne2vN1QpvUzXEpGDHCoI/1gA0YoMwPeP1ZQl8kAw3FLHu97IXCwPgF9cwpGVg93zZMX" ..
	"xn6EjxlW7QM4G/Mr/nN3FosysbMXY9ipUfSzs85Ny7Fn1PT2RPFuQjxpdp7tNCJF7Fj2bKUkdNkI6i3nHBILOjK/NT2JE5aWbRSG" ..
	"86IN8MF4yK4PUIUjadmVgrmTYOeXieOspW4ja+1uciyemtTsVx0zmslorBXAmzPR4ZC7JabijuQEOU+AWyTEoud3REcKyfBmoraT" ..
	"5LmYSuAArHL9qkokSQrMN+NXpNRO4Ed4st/YXwiDJ3iYVUcVeN2kNm2vTYmnO/EX/76bwhR8z9nFcItqo848pCSwlry9IQgjI/gC" ..
	"SiVuXRz6nreGlpzCwO8q7FwGsa8aK7h+kuFIqITq7ZDUWXT+pWxxriRL0Mvua9bSdwybiPkBzbNMwXAZk6D84Wq2jy+tnboKRzay" ..
	"jXOACQ8tdZ1542XgQG5FRx1vbCv3h6Ik08FFcH2C6k0Qef60pE710y2fphKxk6S6U6J3JAw8w/IkRyYnmt9OLW3Pi36v0DewwZO2" ..
	"29srSAH155K98n1zPUnUnPrFlGRc7F3AtwxjLrW8wjbaYCNddspt7TpOD9XI7hbRvEyA7JzoRGx5cN4McVFiZmbRvURuobLOko5z" ..
	"g45MpwcLc8f6HwE3SRN42sCyjCC31dJSswCRvtN+9pr+lrUz9hgon3UhaNnx5SM1pY+duT0WscOUKsw7D+u6VFFPnlyeNgYX1Wes" ..
	"++L9mtvJ58k7CTmOYSi/gK0eMUpYc68SVn+Rvi6DPQ0EyVVHena6DYoajQPWHL29cczVKs8eLNzYLCFVAFGGzcf1G7c8b2OFokxE" ..
	"73L23xFlM+D2NnN7ZUwkXae9MospAAO4RJCL6jBeCx+zjyeW5m0nmVbCd0MrLTxzrXlhrzbU/Z/PHSSM9XkgcCVz50ETVXqoQp70" ..
	"8XT1zrWcbIhWg4hMHTkNwOxQstL1d9myPHtNwzsH3DNbUAV7dYUxAqk1sgujEXFcI1/2zu9jVJbOm0CwVk4Go+ICTvdINxv8AzhU" ..
	"H+50uqHcMT+i05wmjJX/tc2Ev8CGWR2FZrqxxlHlCCoYUl7u4SA/7h3ZKHRKeYDTROPexJ5Vt1Qmzf9DEniCefLaj7Np4mOUJMhR" ..
	"355t0ndEMzXQFG58nWThYwKlWhMKSQJWHm/xihvUi7LH+SYfTmXJiRu26ytnDQdEj6S8D+lXTjrqI3Zx2lO0Xymz6jMBmil0R+HR" ..
	"aEtpIjVIjquCdUFMOm6w4UHgOqGZbbNag4XLl/Bgl+pe1X32PHIBZvIrgSOFr5P5yRdncgQd9CFMzf4dtiyksEroiMJKXjUzNS5T" ..
	"raWKc+sIJVl0/EhjU5UGdHDjRSbSL56uczXeTsDX+6dbgcG+XDC9V0kJUefYpnPHDc3iF0HfBJQ2uAFmE004bPMNlw6dqEaJudTj" ..
	"Dj2im9NKXu9ztGQbIADyXwllw8xqLsK9nKgE0o5G8g15XHhiu3kCbSr+WsKgha2PKkATc6FI2GlqsT/CjSrwk3rIgzxmyrfbwtf3" ..
	"cdYxYGLNauIbh+Y9UcDFx1XNXtUwwdX+HMXkj4klIURgibiUgZowPCMCokhEowsJh9yG5ibd9KzPXOlW4nIIGTbMn8zqTA3zqpew" ..
	"8ygLzzNMLWHbY/ln+jpMO6KJ/tDDTP9nG4Qe0lNlVLyuNVkEi11fCvJeRqn9tMxEkAQ5Ohr3p3funRpYAg9Wts797E96qVAgHeJ7" ..
	"FoVDvu60O2EEtlM4aXn+xQixeLOt3A2LgKLApiQ9j4iyL2owmDdqgGfK2ESQ1zdrZyu5UsnTC8Zzo7D2em5CT21CQaYz1jB0aFiR" ..
	"9brra8aRkXF+nwwe7rlUoy+Il5tXOh0vffAiOuWm71kot2FEo2L5Hfu2mP21qtrhygWwCdpCDxXCtds1hmNeClMYNO4cN6J+86lU" ..
	"9iNKJGLTvqXfQx0clgkjXlui3SYIOaeoI8HX3l9CdyExh+u4Fhh/C6GIsFmFgz0KrPThioXCTwsa2+doBY4S9ItxU8wHRa/w1Tl0" ..
	"qLFK0Akfac+jtplDBinQlDAi2R4d+dPsgAhYHRDpp5VBxB7JVEdQddLCuKQTKE+KprUUCEhYFjEtRJv2gh4QcPxmcO74JKQnl/cF" ..
	"8d2wkBmVd9xXl3XhOMyAnv6iw4QUIT2f3CuQ4SRgB5LmVWsFzrTME7nB1b6+5SALC1Pol+xKja7OfogJRSeg7E+SKsAueAgXVjmU" ..
	""
local PAYLOAD_P4 =
	"4ruGdC4gqfK1sIPaWl92PUK/3dJGpNUMUlb5QfIqEvjy15WlL6jwFhvGGVQ9nvzOsIpOmFzLIkeLTnRmpMAkjrvXbZ+jLL4Locif" ..
	"s8j6FTT4UxUt3X2duxYXxAp4AL6cbpKnhIQJXEMSMmZTbEYXoQhV/tpH5HsPqHCa5xTD1Y1MQvSqDTnlCUVCITS+ArwHwV0eMJNc" ..
	"zuRu8nYA5vUmbFtQyVsy1dSabz6L8J/9ohf6hpyYK0fKMAw19vH3b3A8ecyuFAF/pXHuGfXMkWuGBYz4YHTfbXGDgu5zFKxpefD2" ..
	"mnJhsopj7QrktBLomMX85rrW7tu0vhpu1qqpTewQT5pUfuo9sGOYLTGd0kZ2tv6MEimzZH92gkwI1fPzFNcs+uUgxHal1aXzmek0" ..
	"y/Gp5NnOCIDnGZbvAvP6XN8rYHJAB5BcWfo03jv4PofawdizAaf6P2I8fun9CYoSp+NG/hck+Kxpz+YahI0RGQDJp2hsK/gwBhS7" ..
	"oQqHVR9f4SI0dC1+2d2lt5kbV01qSxcwuJjCAouNdncIN2076DZs2UoYw7F6znCA+S0cfdidHdR74CztixftqONRRwzg4srPgR+T" ..
	"Sq356Asw0vIuNYPLrqWv3osKVT97FVDXp/360ba5SElP6DXDhLjzDwLM3r+l24iELR9TXee6oOYPgPvdpYdeCFFiSTqOE+LAVIiZ" ..
	"NvhL8ZABYUbINtZCebWaMnuLRt7V3MC3NnF5aUQU/465R/M4Kr/0IX6hx3bYwW+yBF5uYqa/L8apnZNhkEl3Jw6QDZ3Ul8ldO6NH" ..
	"fO5WYPBHheCnC/prjJXR6mdNUtQFwvy1d8ATFS0WOok6eivV/rR7TtBZrXOcMrFEFGM+AkR2pATQ/3lPrj6DYaDhlpQZsw9KwxL+" ..
	"9s2sG8OIgYJPtq5RhOhDFgfPX5f9fvz8agULKTsZ5Eb/krjP2aNy7GTxpl6+RU4Rp/VDEw0BLUAMRm1/p0IrgoJd01MREEhfYCiK" ..
	"js4kJnWqnQPDIFgvJu/Fh3MHVIilX8jgHje5XevJhDs4wXDw8/LUJbjodOf2jtxLtFqCV+0swFg41zD2/uHg7n8bVk26I/5Irag/" ..
	"hxD4J04qmMVF1UIpn56ZDwnYjepZmtSk20rtTL6K2uaF1lDcH0Oi68eHKamvh16j+2JkZYfMRsMOTLtwfx+l1GAZBW/IFtYbIJ2A" ..
	"Ksbj5lfkwRZChwV0jqDM0KbCAPXWVj3OkIfpssseK83yohux+2tnPOmvSpLTBVdDiQ8zkeBzzY8lBgG+FBIxZUDAjtcOwD0QpCy7" ..
	"IXL8QcL+tEcj7y+hv9MbBUlLVuyjgkMoH86A/4T6Wd2biL5I2CD1Lrz6Ji9yBoYg2hDtSdEvl7Llho0IM77KUm3OZikUnUKA9vm+" ..
	"j9SF5hh/4sLIme2MIMdXpTB3brRblH+bDut2iz7Mk1RLKnMAD05TrJstc2pcDW81bZFgSpOTfaQ6yePYumqG+LWHzxuPIQgqy4Sk" ..
	"D/n2hyYUmVNKp6dNNj5c6xZm1KMKPEGwoQjYMbu5W8XfybvIilS+1S8AVewmLUFH9HQ9839Nut7yXybIIqEgwvWNdlmznDfxakwN" ..
	"CPBl+t5w2Kqp8aT4oxJlPRBZeJiOZB9ck1kb06YkIKEqx3yWCgGpWI8XfEYo+onAzOCr/lQMiFkpJ7ohItY+JjwGmBEOdZNHbwfa" ..
	"yZZAoqC1S0q5MnSyuweeusM7pE7tCM5R4+OPnI7ImNDMF5QPviqsunBVRuFynqyir1mlW26PL2hD9R4cvPvJgz3UbAfWnGogWeQg" ..
	"XC7zm1Lg8T3BvCj1jTx43is/NXY1vpRS3JmrjEqhnDks26k1HBhcJBzj9cqn+fPk/2iJrEfeYpsK/6a9i9u2j0/nEvOaIqD06rWU" ..
	"m9Dm9pyhBo1r4C1YJvjZoSqY6mmKAPM/fC8FwaNH54buPkQiWjr0+OhqVyvbzJigi0KZGiDL6hikQG9+gDOgZhpzMqmv352ldYdv" ..
	"OUBMiS5eScnj9eIizNgy5OCvdbuyhMBZ+BzArF6gRFFCc8QoSOunJgE9S0nTnbXcPKF8XlDxcwEVY9+PaG81Tuc0zaMzvlpwYpX7" ..
	"qr18BLvSDnEy0d9RahIEk0hp7aWVw9fhmxodvYg37OqKQtjrcWIFhWENmNwuAJf82acGA3MYEiWJMcHWTmuoXgF8CJR7JU7LENKm" ..
	"CoZbeg7guHe0LGSMkkz0JJbWdxueytqqOsRKLiQSG5XKz1xqRsVzfnbtniq9exzqfoacoKubs3wiBQSQFFrUHDok/PDEc+KalrZj" ..
	"+ruWiBLih1s4z70KzvnQi/9frcAkUzhHBUihr0oq4n7pdsI9ExyOP458/4NSPtSEfb/0eUytxfDmL6Rq/TF0cZfmE3u6GOYG/eXJ" ..
	"0d5rNep/27FFujPCk58aoYU+s9T8iDzLdu5ViscQwxHaUbb7qVsSOEW0ZWdh4+Bj4qW+b4aAEyGYZ4JCWdDI8BPGb+LpyMf3HYq/" ..
	"dyUQTf3T0lnjLUhAWy364HDY/LuRU/LTgUrtVWlsPMJm1b/AeruKu0c40su385yg3l3kpeHKYJmbids3X4nGaWpNya5oags1NABZ" ..
	"bzN7uR4hB/Or6bxFd3a1oatJJ94eu0tLVSDN3Gg7CB3NckOu09R6qm1FNjtd0o+KLoYMOkeIviVpthnC3QeVQ6I9kgrnPU2xSUIa" ..
	"4GTCIEC7GSKMQ8uXM1OUl0XGMAyYyps6U1PkvToGfZYd/Kwf8m7IC1fi1PzY8/fbl2QiKOAGTbjtpPsN3BS64JbwuqkZiERR5tb+" ..
	"Ni+896da3f9K+YNrGXWRkdvi907Fz7i+ZV2zz6Og7sQJhO42fbsCxps2O8hnwmgH5gtP18Q1LgeSwPaH1n6vXbdcBUHgR5+KHNVk" ..
	"mj2d8jTcKkroRg3nTaXacReyv62Zdfo0yK0gugcHiYZJp7fZ7ISytbs0377BNN89LSYddQzVlPQjyCw2liS5Fz9yxW6T8TDI4/hz" ..
	"saAKNfkZFz1pX+PL+O8V5PhIC5FFiWpSH8YRxADHh49AVjVmWrGKeDPCLYoAidnWB4s4c5qmOinwEanKQD8BtJFn9KkFRpEIUpOP" ..
	"2GxMJG63acbY4pze17N6ylYQ7WYiQtQSUoZFtsdTS+spoNo2+GIWV/rcii+zgBB8GeR0Lr/BlzaeygS6plo61GjYEKq4Wjf9aF9w" ..
	"rtkFvLU7EhCjr4Vhfu9HlzoWfAa5jmVO1UBHIX24qiozcfKg0me5whpN93VFXMwXTXMYtZ7djYqNUVbGvwAnvqsjEXnfVh8fkTkT" ..
	"biFIZTyeME5fBXzin6BgBtsazVDDoSo2lnmR1H3+A6D1NjftJeQ7BuXKgCZFTcG+aOMnZ8Fri2WbBJeI+8pqdAgoaxi4HOnaDPPE" ..
	"m/rBIW1TeOB+HRn1PWzC42Ee9sgT9mcoWS1/H51Zsm0eGnhg4MkO13Eyoc6rn0AyyGBU3lGHNihb8r2QPsCgFj/oGFMBvqrzPQu2" ..
	"2Nu5BCHZypVu5Sg4SkVMay169N4ycCZdGKSG6cUHhkGBMVpy2FZgkiQM0fCOiW275b3QhSfo1lTRw2DX++mhKXgYWWkDYi+PasiY" ..
	"dokTvmMusV+1kKQFzYb9lkgZCKh7iFEr/3VzGo8axphEL7Qz5AgCjs8QE6iVpJgzLEHcPlTzhZptcTh60cCL/jWUe7zoJLlvMaTY" ..
	"+SWKfplIGjAeP6j8M8AOVYWjvWjk/IffadIV+HfokRygbDPFKD3mWquS6v6X4UEPRGShrLBCKBFZD15Rcyewrchkc4ijBwbSlPJb" ..
	"/pWCAQd9AJt+mmJsiBhw3QlWaV/XJ+4jH1wGJI6eQLVt/NV1tAOhp9QGvkUgh2um+wU7gxnGs2aQKe9qLmpi9Q8qLaCNdPKv35+U" ..
	"IcFXaoqsgJLMHS7UskLaHnFm0zghSogXjp9Qp3dX4ffyXL8M2RzgtOZ53YAdXSrVL8n9HWLp/JkKmzQ6/8QuPS0PzdSsGba51bgP" ..
	"qOOE3kS3GeHsjfXKyzgAlH8rc4fz5ef1Ce2qCDm2wSonM22LHXqQpwIZgl+1hTSMWz+1YiN2osIZn/JAr00QNbThG95SdUke/puU" ..
	"Ge6q4QldJnofOV7sEJV1JlNOy0r8rZsdojTuPaBft2bpvdUR1L4LQrTTkUwXz8mcWuEUcCx34qVHmIW2EszVi6BK8RZHVIq9y4RW" ..
	"h26RaK+53kTi+CU0kG+ipJg4VbSXysJ4U2l91BITZAIfDZmAepdoDi2hxaT0Thxm+5qrwPCSxpI3AgOHTA+MKCbb4e5VHZs3CdvB" ..
	"Qx1ZupNK378S2eX9W7vuQUbeN0QjIcSTZ26sN6DcvDASvQW5xpCtrqoKQF94qwyQA4gs6rBZWcng2sYgsOnALLq5/Jc0vp5h+M4b" ..
	"YMf2M1lIM0J8xdEvTeWAiWkCTfVSoY5nEVLJiM/FCdG1c1n391V3NAQ0QIMqjhFhO7sKwK9jh4Rulpe9IlEHozCQZ9oPu8ypC+l5" ..
	"BgosuH8hvTRTreCsS29BHAnGFiWNYMgwGkgr6zcvLCl7iymDdabdQNsyetx6soV5Y1GMU9ddE01qa6DqllRzcjCKvzb5Y+pyg3d7" ..
	"HjjDBw4V+pYeFSSP86EM9qb2pocB4pGksvQX4bY43WLvoFc49kIWrPflUjbL5IWpfccMQ4bOAXRkzyrBrjcgXUYYShCvJWkozbFx" ..
	"LrqiijxrIOc4jyOTHruR89Vx0MNEOqmgm9bTjvTPfSRuHfg0/CNL1Zey/cEmwfQqxaKTYNQLJnis8+vWcVrMo3ozvGL5+Bhh9Frg" ..
	"QwoXtda+wWuvp7Y0FtOgTTGc6+b9cJ82bZbUQnokzcVH0r3Dv+aCzrBsaP6f2VpAfsWKRQyzQb8KfpHthFd90q0CJFxZuZPCLz9g" ..
	"WrmgzQSfQ1ffkt/yC/+46E+ul1caDyqrOOoGjay9qDE+nPO1B55wNFKXOh7gAieaRrDx5XLcMPb5WZaNSXk8wi08pZd39kYoRR6N" ..
	"7/QVj/l5c/xH9faOUIhfc22mXD3rR57lO87bJ+FuQC0b7JFOgeS8SVxelj93mfWjPdsXhEcxKHAzmsrKgUS5PLDaRjH21ABWOEkf" ..
	"w2YZLx6fJAWzV0/x3VY8M6xqrUMitHT6bipH6s5G9AvsisJ/w99YXlKMMibQFbgeTYM52WFzxrQSpVsX46LvIyrQa2+aNYaMXfM3" ..
	"dCH74pgUQDxMrWj/wNCW2/3MlhpJCkf14T6Scv4lAJjJksi7n0bEwz7MwXFvEB2nLH1O1kHG6pZi6V3cD9HH7Z+7FZTxgMCf9vI3" ..
	"gs2IbCedD1e36C44Lzc9l2jO6oyjmlvxlyFjB7FrHT/hIrjfTeCPNOQ96NuHr/FqnxKmKlQvPPgV972PXtwHps3r0ESWXC7Luq0v" ..
	"L3MxsNZ1LWQZIrTTvYZ+VXjZiIanu+SJgJcWI4kK+JvwS8KrHf0hSbOnz08TBI027NeoGCJw+nRRedIF8Ktn651M4KGoI7cE6vnt" ..
	"NvTC/+AuN9P2tCDWxq7NqPA+qSi7MRJ1Ge4sizYVIpaxAfiqcnjQn3gAeueozzcoiI5QY7wDrGGhnasA+Qjg1RpUfHJmSx1DohdA" ..
	"DwKzoFWEnNSbolZPpqvzIvaaNSHHxjIV4Bx08QCS+8MITBqJ50BcL7nkRZZgKLx57ytiMYqn0WYCc8KjyILMjE1zE77hjyNm+zhg" ..
	"8wCgc5CTtiJqGBf6IO5cd7KnVwYPQ/D+HXkf1XiwQFC7aE3RT37cbInE3kv3DWjmp44uPclOQVM50xk0FrkaSQUhJoVyHbFWeoQI" ..
	"Hz0C+rDZth5o/fPWoxk+NH9Ro/t3vadFj7NF3IrS1M37pha+YRl4W62m54KJW2+KR8Jt6w/0jruCXIdA+1yOZXwFk2sTU3TeZ9+B" ..
	"jnma8+mdeiQzE849VuQKDiMLDrLlbp4JlW2c+tKdZoyvAW19I2o0Zv+M7TTj18HDcZ/kuNgPZFmTNVq5XUdgV2noRgi8M+WIaPRg" ..
	""
local PAYLOAD_P5 =
	"EQ8eaYOgrIN5vPCKD/v56OI9f+6TU30rOLyul42fL/FUW7Rpfj3oBZI5+366WuCUIEy8jjlw82nTZo0y8JOC9hufgpRkR8Nh1bDk" ..
	"q3bYmIag7sUEfeiY2jMgZI9o3pvxqrNKblgQjEEkIF2IsEMjInWHVfssWWP/9PrP92+y1rh0RJajzBcq40hBV4uWaFDzB9uoUcBR" ..
	"bQk8ufaaNO7UTCrQwX1BguSaGRp734LH2MG5HL41+texo/49T4bjFKpU8TlBhtLFInVCii7Dkc3B8lZXMFgEtj4l2Jogs/BJ4t1Y" ..
	"sY6N0bQUXDQj1FQHKQ2Ii/LuTkquuvinh9TSatzcmTAkDZK/N12gJiEDQne0foatYmbcSHFINGAqFd2yFLZvIXQm9b7lDrUiN/AH" ..
	"DO9HX7WlxovPBpQfbtpWgTw/C+hR9N2w/bqeAnZsU2YW2rRrh6/66/pBNzLBoKFrNmgli2+g7Oli2eaeQ96tqnLjWGzFr+zibZwQ" ..
	"0HTKqcGZXCvqap7FTd17NmUWJq9WY9zAM1Z6SE9MPxlFjjzoKIDCd9izDZKgBLxiZD9HqbIs2cW9DGxA7p1eybMSSMdYBszLUJ+0" ..
	"VQuUATrumdUCUcUjE1UeaxzqNv2DEI7R/2BUO6wAWfEc+VaY4GNoIl/52xczwmM9lr1EX69zWNYdBVFr4545XXmnMwF2TRfREVPw" ..
	"G1IHDdoiZba+NdNkNveNyFWsLywhzdLROxrXazY7gPENyMSgOmOdruJPQgRlKQhVMt5Mj6/jBYq2I5MDEG7I2UR1g4+oNv7VNyQ2" ..
	"zelUL/B+x2ArHX8Sqdc7mOtfSWo04TJN5os1+WtG8DssYVWqgUv2WGAdxGFf8M50oKjX+XmPQQWUPfVV4xCYNTH8OZ+TLDsrGs56" ..
	"B7TiGVH+Q9El0MS2RjYRnzyIIlF1eAdzgbvtCyHgJAeJb8OM+6tJWFrKcnbscgnAxp+sVUmEwKKqqnCgm64gfyGOD/D59fe2vFQG" ..
	"BhsAsO/bN6JTMdpH7QpncUn9jcLdyl5TfDyFAnOzXu7NcVd/iihL8OfwJwyxkEkcVtFSTz+a6cQxkXERFa2fTher3UME1B38fQKD" ..
	"JMPNMfJIDfrURU1sr2Nbzdf1AvhurBuBtLdfjcgUv9piedjtahGD4zRadbWWS8FfAgaCBmUXDyppiUijCTJT6f8tNdA9wSzQ3keC" ..
	"Y/q0bCMJAT57I7yI5QHjj0WmKrVbDVUN+WListY/Unc5SSWrv4CRdIP7qzHUqdE/kFlFfnyTdVtG4vohGZ59qC3F7TveZdGK4rqi" ..
	"S2Qa87khiiHckd8DjLiv12iZqZ0uULu5DYb8cmV7Gf6o9dqSc3kgPe7VVN4x2s+XJbUJpN6knMB88MjWco9JomAl15I+eYYstiWR" ..
	"4N5+tsG/yZnU6Fm5+g9x5n6NYFIVr8PehrPVNF6Vhn0shW4WPMMybNn2fQZN+5lhg3i/G8xKI7mmW+P6Lx4S/RNLUp9cVuDlukBn" ..
	"miuzjkbx6ljTCO9eMbUiPjBN7hqWkjzf9Mx821JSALXfXnEIj07TmKIheZvuVaZJHx+Hd0mzRhoegkmQrhpSVK7Up7SDTSCgruuc" ..
	"bkfdfgWNEODQ2zsqE+o41Zix7X9frdyqmR9IJdyzzprPEoPRYyEA/WlAd3QJ9ZQSRSTutEgaSLptyEBSBy2iqiiYs8/AH0Hur8BY" ..
	"5y9fPZm8y5W1nVdAGrAVm5PoQl3FetneQnil1lvapitS1l22Dp4/FoTTYfeezbWbN8pa5NlwWjk4zqFyzId847qpibkFmructne+" ..
	"NzGJnypVP8C/Nxrfi1mEBMR6tW8ERDIzVCcgVCs6G4LbmIa5M3rMSnyiBeG6fcjRygP8Y3I1FMc3f/WLn5gGmtO/ePErWjtGw6Xh" ..
	"Uz+FeL1Aga+25IrxBTIM+i3av+KJdkwHiHoUGPQv53ukPAOQ7xQ6qPQSn12BfxVAwDYI0Bdkq2X2JVtTiLQ8kRywZ3CI/jP4bu70" ..
	"+wv/TS8N7N51PnDM6ujF5q5nb8Xup8sCXQbPydMO1zPtkM1pJDH1ZsWmiSy2/118qzF+Fmr/khmc1B+rhdwVlnj/7/ZAzgcldN9W" ..
	"VhyHWhBvdZHk1WbR31EG1Twf34MoSIfmOKAU8YkWaNIe8wyY9Izb6EIBik33Ebs+t3gCez07nfqmVJLOk+cUZySwtM2OPGK/thtF" ..
	"y+XMg0Yd/VU5LfM5yWOu+mpcLNpji6df4PGbiYd87TpBNDiXESlJ6yYgimT/p7yTCnYTO8x3OHIbVSB81RLu0Potw61GbJXUGstL" ..
	"1lkttJAgqzB3EfXdArvBAJRDdkvaywn6KTTfEk77KUWiXJZmgdy0dXmklPV5yyOUB+EDEu7V3gbtdmTav7kFW7yILTYjjzd61E7k" ..
	"GqF+/wrk2sNHF1yPHkQxKWY/SCIgGsdkEJaQqjcWlWyq2kQcSYB1uDeUw9ChsAzBg7CWZ0/SQl8Icr5U3gsiqXGzJYImjGUbvbsE" ..
	"/mBDJUeIuy4mrE1qCN3DoaKTHkwpk4Xd5iQkgyAgisSwRL14roEYB9xT4gnZ5tvFiNviKLwgXR7MzlIpGUAe23X5iLYdmeoMRtP/" ..
	"ISBxJdGGbxiBCENcJvAaoLiqObgvb7+bmNU9+YzV183lLANkrA/ZvTXH2O6lMYM8SDxMVRGVRAxtrM8UGN0SRMHrJ9Zwa6Q9B7GU" ..
	"vTAnusCFD1CUwOW/NJcs5Quk+/Y7KlV6cYXqRmy6hP1UQxtYSaCKpqR6J5iNERCpJMRVd1ky+F+RY+t2M3P9DbuRf1V9v59pRANM" ..
	"n6NOadFVw8jY5SX14g4Dl7k5dDCj7304XDvRvtSLqrNWCoAEbb/nPbLyCpSkytPUr8v1sSJqVf46mkiMzoh13OJV8qu5b0HhTcuD" ..
	"hCiodUsBoh0R8hukFoaYkMkbHxZzAgTWCFhM7uK8WEi0RFJTVMppWeIKIh+HarvpOeqs75xBsR/Biv873jTEh5qk+S7fAkzKggEl" ..
	"QPYItN2ZZQ4f1mFM3+yTYRXnMFrkWuOCBkqpFf7KHrwG3kG4GStdIIX61DOPjhfkWtl7wlJFbDLsguhZ/oaV5ChfkKnsZr2PQYJr" ..
	"n9lP3acslLO15nUbi5vZi4hu9ERsaqJHd1kUmP+xSoo8aOnIEEBADVEjiPqifjNf9ObTa4jl7yCT77ttI/Igh3tG/mlSQidxjUsg" ..
	"qX33fmi1SDbqzC8eo6s/By4jpMRKDo3HiwSIgrzAZ45jnoNwVAfgaZ5/Ew3jAz9mEOPHAI+2V9l9QZ/k2ebQ/cEvVD+JgMsCzMqc" ..
	"H7fESbM8EDKa/Bet3Cqu18KnJ0FGNdXk9/Tne3iAR4EDZ9oowsw7lEcxyixotqI6KlV/w5nX6Nn7/3/Nl4TBY6VpOQijS9xxAZrA" ..
	"OTA3rBFFvF7URC+yWqAs0VSfXMfkKBxBtoy53gsMM3lVXdFAFYY5onk2hXQqjeLeIdbnHXdviGZKHx3DrE6B1iquidxYxXK76Yv3" ..
	"GZFaWIDJvkIVL71w/nok7bqNtTmvxqi9KZm4bHfM6HS/PPBqOSxTrUzlg44LqnW8RRyuyQ5iD7NnJiJH+Sp/porCX6zF4jLfJMcu" ..
	"NTQxK7+Oao1IND59IsM8Sb9yJ50OIpD6Z88RyErgIQ+9RXl/CZ/uCunmno+T/453MjgtrMH5EmwLkqwalM7tXLpd5T/B0Urxa+MN" ..
	"IwZzZluRtUKt+5mVRd2HkrzNqzzyC1LeRBrFcP7QWBWo6QXnC3+CccP2WeyYDzeRnWKRepxdcRHEmmTtX0x8QGCrYAagK+RA57ho" ..
	"qWcWfy50VTS6ebo0dIvb8TaBVjZXQNpduJvCmsBBUXFD0+GazqT9wTSF0QaGQMRShuk9Ga7GnPL/d74WoGm49jHpqsAC+tP7IG5L" ..
	"VlgqfiBaF04OnI+Z59/rEOemeUKBx/erN4gy+vLRPtO256rXEXtLrVS/+k/DUQEL2nHdnyYBbjjtXQA1XpzHeXlN/uZdP0fgqZtn" ..
	"VlOA06YzL1FEDIbs8oqnJX45AQPfZXznIyP8mGfWAM9UNGwSIJmUgZV1cd3DtbW+ILh3B6getuCQq+epL63ejvNFS03QRXRbocc+" ..
	"5/dQZFUdD7xybfol3YpSOkEot+IhsoloGoU604LtX6YHxJNxyoZAqfBmgBmPdZ/rg2hEysBXaulAOGAbybxllS2aIIN8/Xng90pM" ..
	"HREmSju7WV1dZ/GOfTrPXCnrtyEcjuZ7+LigSEHpdRx9f1/fEKRl3mUQboUQqrVtLw655IKyf/ofpsgsWLNfFubt5MoUG5XSvZB5" ..
	"oxu1EUc3bDqFRGjAXMUTgMqH0/bN4oIMivJJOYtZHD8uipc0kijdrvEourOWX1JCenpbgskSl5OPoeRMBOxgjPlKyuC7FZyxFSUB" ..
	"jc6nzzU6XER5gCK+QAtS02skZ09UAbVFQsS8L070uV/9vOvGYnLs8RLL52uK8rjgFNnav8sOUBVFrnynImlIINWYLTjjNhJqOFYc" ..
	"acr7SRXinfIWok+eE/Xu3i7wYCuxGr4OLQfNkbPLYtsyxbleA3fVEb56Fvf9nsRTZafO42Dl+v7PjRWpOu24n0KEarFep/RI+d2g" ..
	"ABh5+OXCZ85ihBBr0UxlF68j+odxl8ibmNXK18SHum+FSpR7pN2tgC8tAHIClv272LY6NT1GyefLjd0rKADakKM7/nI3yk/8IL+R" ..
	"Hwp8teH6txcY2kUyzsJzso7UeJFkQeegtPxjPTc/YE2eKreayD80py8ge6Ji4hlCQBrvtLfcUc1ox1wxv87pb7b4K9ejlx+cZ5uB" ..
	"vBkqm9EDiqXNV/3/h2a7ChTAutXyTF1skU+5HbzWyNeg48s4/RH4cho51ZQb3EK6kqRFecd8hNSChvVbG2EqytVI/43H0esM7nzI" ..
	"sqf0GHAKIANb8p3eORhX2lvkRKnTI1oa2Pyo8ctc4S1o78opAzNAmPzAm8JNWjytBMMCpgY3G2TSVsj0fN3pxzTr2+mpXAw6ja2j" ..
	"FH9aqVV1M97/dbarVoz5kSyoG2SDlh/rIHsKDngL816E8Ue+BwsI1gD8eKIHSn1shgEoWlr/5DeKJk6gcLTosd2gEsnxsJcr4Lci" ..
	"pqxpqm8+OQjhcDz/HZOb/DWeSEL27s4t3Yo+8YIeKY43qHdPiEkRtK8uunQXJPffoae+II8mwgJnEpq7RZYOy+kKjmtXNzzg7/m1" ..
	"dRirYUotqHvQl+MdmjVL5g5dfWUWXc/CmpF4an1G6wLgsHmVwxBChBzuX/knFxXVYxFzBJ3PrCplst5kBZARybgvC6Rv4ML2Lwzg" ..
	"jffprc+HUfMDrKlHkypTNk6xqmXwuPrtIcfdadZG+ftLw178vAYNMFdro9yzgw7O+XtRIrreNW8zcCuvJr4XDIUOUS8za4sod645" ..
	"WfG92g6yF+eNVHDdyDv4qUyJLoCHLGJTzmIClQFxFxyirQKuClOv81eTmVojBf7BbWClcZoQ1Rwu1O50kfG7746hYaF8roejffVh" ..
	"UIw1WG6DaZRrSPJ2LAhO6QDxJ5Q34oQC70tCXPJc/YkDvVwVpCXFtvEXdWspDrVw9m3uqv0WC0meTRoG73UostZXX5x7QfMcoJea" ..
	"FKsDBJyPPbZ0y/rDQ7ZbQfdWMgrs7/OILKbS+q+5kePqmXuh+cZ487PBbYgI+YIJ17ecXbh+tL80VOttbPZOmVG+44GWAehvxsRd" ..
	"1GlTMf9BFW+yqe/JY2Qkwknr65ngUhYJdrZ/HOG0D6tmFxRHq37bF/mZEdvqklSnkAC9I4Z5Q1jKBEIl4tIXHuclVOA6gNRMp3JE" ..
	"0FiDkayVe1dtKblzKg5Ngg760syM4qBRRRhoC66y0Iqx53IKUlzIuBatY6mvvQIGRQnpzbXKYnBX1ocH8Z8nhq9zKOfO+Cs/drP5" ..
	"T5T6Y6/WTZbbK+VoIUqQ+7JuRaMiGxTq/YIFYhHIBVjrcuFJHBI7Efg+QdF96c6d4PlIN62pCP2uTURA9m8OcSxNDNYH8qCozk2l" ..
	""
local PAYLOAD_P6 =
	"PJEMvkrmnr30QlaIE/HLFWx433CivlO/Z0NHNs4y2KSJkeC+Yc0IZm54uDlR9KYUSiSJLjBTWCBmpkpAVMH084i333Qsx6INjfq4" ..
	"1VJEGvoAs8QteZBWHV9PyywzFBy+ktnuQf+9AA6EDiutbl8QUqCa6dRq9+QjOkoM9oRC0ZLiBUBdrkI37INLDkJ11MFp5121/05W" ..
	"MyT1j1zKJbm2rAt9jmo3HOZY06I0aeE9ZiqC5wnUpb3l0ZrFuGLFq90+G4vjfWWjeuJ1o72zAjYMdK66StbNnuokl7aMHdV1pPjO" ..
	"a3otSWjdFcyOIaaXbREvicaE1+O1Jxg3iX2vWABW/mDAyiIUZ1RBHbq9+nf/RJGjq5wTlR4L5uQpcorLhLwS/Dl0Q/hOsa2Z1Man" ..
	"7KyHe7nh3sNoasXE/+j5Pd00mITMP/ycnGtTCm/lZSRAFrI/dhKlkDpyzNKbYZ3lwLMhH+rfP3VQTTn4jRGyNAQeJR0P1QyIUn+n" ..
	"0VrEoqTRZ7/utefvl/XvQwFWu9u9YuSFV7qGO8L0BBxxFa3vf+jQXHgi12ZCsMq3vxsRIdnsVtXc9svXGVLf2Y+3wIkT/Neo+W+c" ..
	"f8qpLSB8HlPwfG2alBAtEMwfhrLnwd3mbKUSHUHBcy9c/ZpEWDP8eYaUHx7s3hnCxvr4SFJAtQ0noUmtWfEGlLRh6bS87h57vDaj" ..
	"rAGDFZNF8QnD0/C9WL22DIHDnaTMUnMRT1OILfmUErYq5+h63ZCnTm2DQLzRYOUhQJ2S8tbBdQjO/aHmasrDvyKXPrtAPTriWfvi" ..
	"R67yHB2xDCkmEKMraF4Pidmcf8PUV/4yXLetGqW+iSBL3ieMaV1hkRX0279PqbqCVN+5vmeOIzXZJ40txtrhkt/XKkYnknNl2CD2" ..
	"BzXGW+519qqoVSvB+t8LkQljZB2+s2urodYbEm2/vAtNPhvGJc13tEalRZJZNCA4TK0E7xWjOM20u7DB5mYZxxX1lwGo70vSECdE" ..
	"Kr9Vo44HzipIXGme2jEyXhBIAsAp5z8+E6VQzwlSnd2Unc/lSayyjz4Yt4XcnoZomA7316LbgAc1k1uU48TpP+fc0wHeiGgYbJF9" ..
	"4DP+zJwnOBjYgqZyrYyTaZapKOmqrcQSiskduDCup6isG3NkEiAikOvqnrW2z5DYh4hkPrDE+aMRoVle7ej5HRpekctkXlzIJFgP" ..
	"anaBkZTXhzQOMdo1dnq5btp8KWF7BDYfsXF/S746oYLIuM5Pf3KLz9lPETcMGSAT75dZ9vukHGXNn/YUheQKyZMze0MpqSv8tiMO" ..
	"r1I/ymqycHd/4evOvz2udRc/JxQvTaw3SIIS1OzK0/UUqZIewHZqbPJu4bkIQevCdHJuvh2Jw8uT+30pQqakanbF0aAZmpO8yzFK" ..
	"SeQT2BP/fYrNr0pbqKGQ2NBfRn1K3qqOKtIsAypGt2v40Ifuo05KQy+INY6LSDFT/rLMF8VG27ChtL54YYYYlGbxNQiYSPrgOrE8" ..
	"dH6b9UpaN7cD4SVG1wPsJ9daOCzjrkbVQsFPq0SJ2ppDrnblhpblJFColHBHiA3cqM7kavyb8WtMLRNWN4m08ex4MmO45I8DQG9F" ..
	"dzpzHWSStDov5Nh03D5iA1OQZ++ypORv1F+eM6rm0Q0k3cifoVs0pfsbLD8KQhsxbs+s/Zkp1nBHlIpcgzNKq0IrEpCrzZnWQbc5" ..
	"KoobKxpP9V6bg7zgGEtdEuPWH6LCI6z3giNqlekDaufpClZw6Wb/0Gm7tTLCaNTmBg839Rwyrnp2+Z32NQDh8W3BebLUrTDcyeBI" ..
	"BDV6V9obmlL8XNWHgD98hfmz3FDm73JbYuaJkitBvrZbLV3l7GAZ3tSbTvWprNORW9j0SQI7R3poBZXbh6hBLsqimPqDhQ+f4Ibr" ..
	"dahmtu+I92qPE/X6ktRRWf1S2sRl/VA/QPx9Axr1xNF2C4VFzyoOa875vttJmNOnU5QZ+kN2WYC1IxgG561/b5fXESB/p+KweFrK" ..
	"g6eOdJw1wG0gXdPbQEDaiMyLZLHrvm9zZNeB4TtriQw9pOin0wrZ7Zd+KWP0qvWS0DVrPJR0nZVRx5sY7XuDmBA9K9zrfNDE4PHS" ..
	"PDr9YxDgOGB3sW4KkkBv67ED2NyQ6n8CPgfm1cLsLkE6X4DU3ENzgmXfrhFOTalTfU7N5rPC5/SBPg7OUVNRHgeYFCgrMbHvZ7ZF" ..
	"yGISB/wEP04NQ6t9dB9EiTxGpiNeKjonfM5NdftBOpLm2Xi9ZuZlFx78RzpuJLpa+IlfRZN2XrERy0FSUiZJZo5xPi9e+840nJYk" ..
	"lQD8kMJJvy7vVLDlqLd49lbhmozeXLhA1GZXGFubWeh24GiaJ2CLDx8WDYnsNnpwlj7yb7eGjRo5zZJfe+UtT43tWjREYLYYDS80" ..
	"iRXutWG/KFeWYh6M6ymScOLizPhVnZ4Sosk6e4osFohn2Q6Ms7kGMYbwv7J76jApOABViem9WSCputdXhtGfzuEoZuNocsv/djPu" ..
	"t2EAjFoGANokBm031ERUHXECNPGCEzxwk06/WVdrYCJpmv6nHBopHqsSFFfc9i1s/y/VJxm1jBNcT1+k3WJZ7w7OKT7W/Z9nDPoS" ..
	"QnwThO9FTGW/v8Vcu64OpHxDpNzN0MZF3qrchvNP8p0C9fBcrRtkHG0fCHZfleeQw2q0FrV3ISguxBrzbHJzBlmmqG00+GwI8tPj" ..
	"bacfR+rgPS6ivht9v0+gN4+31i/xHEZ1VkakeDgLHF/1GXmpJRCZDS3+uF1M63xHWbkEyoMgUhFEFZGujbjUcyu6zDiPp0AQ8Rtq" ..
	"LZDEmd72rEuIHWleAQnhICQ1GEiDJwytUiVq1KBpnXjkXxPsYTx3AfkM0TiCf3u9Dp/AAuSBzuv51qcjHr7kHg5UbrOoGAvwhL2Y" ..
	"f3QgCIOcoplirm0I0ZUNmaFfe9XAly/It/1ERcP5XWYHNN4vgmFA5B5WXA3Oa8RNNpOee3eDuaXg7lTkWfLgzBBJ4cHm4VQKjx8i" ..
	"/t+MRaZuoRLj+lVAKJaRG9Ekcrnyc7cW+8cPYiQBA0N02Q8pc1Jl5T59RyThX+hBNXSFQUSbf+5zM37D386gIukeLQ31ERE3jiZW" ..
	"PcAl1aEYpge8GveRlBq/qo0CzikePhUy+DdL2pbEhWEW65ULHPz6Z6ufkl0B2cDSJY0wTeK2fQYNUAw/2UZMfVYBGZQfqlFHS5p7" ..
	"7quonghMTRbpZIcg2fr51K4jAJM17KUqAExctbmqp2PcBuq0O2AJI99tIdN1lH8RXj6tmRs8Mem2G/eNw1YqzJGB2UsdgDlTjxmF" ..
	"1oGVMMbxnf+PtdIahHTUoPaxX9O46SDWO8XKIPv8xXrXVF4ISuU7Zy3YvQhtT3PQYvtiDuIVOTutLn/E4vTV+4SSDX9qp3yPbtqh" ..
	"vEwVHlZzUywjwa2NMOwfvgBJZWinQ0JY5nMiGLZ5gO9BgzXt2JGDuLn7l6WE+bNkPK7ek4NmrJgcNfWZm9Q1kvKuhUDnLRYt0oJm" ..
	"LAOc/6btlcQsTTxVyOTLnX2xBBfiRwbw5FzZ+0u8j7Gr0nQ8RzdvvzXzualxC4hQ1p/UCZqeqX3PjKx55Fz2Q41dUdNg+s5zUXc0" ..
	"Z4kJ3tpsdyJ74h3FTj6qM68T3dD5xt1mIGSgf8DhAJk+9i01uS20yL/00FsZyDJF9iefterIBaM9v0dnbmNu2nk5bO0UQMa5nae0" ..
	"vP7WJXIcUwOADuo+reIyNRvfRw5/ImOfGx9y4PKhXXBDfzXws6+n0w9KA6Kj4VWajEcNpd3cm03AU9sLGfiI0sKEYylEqq64rK40" ..
	"+i6f6qBqiFBbfHOS5gxXQeRvZtJ0aXWvDKjLAQNWlBnQc8HpXIHmzIG+Za9FDWBRD+3t3TsJ1svThgWCB8S6mB1cvOxF88m4646D" ..
	"QeE70qjYxvuGUzjYT8VURoW/5ztU0KY8lPjZyiS21IdHE3ZV91tm77F51tDF0VqbIU6vZGuf0qWmCTVoM5mOFNMD7HUQDvqmByE5" ..
	"WTjHJ7/qc/jeYW83R9nBkesnlKVRx+7FdYYJSY5JhLrF591qCiwLsy/YPYtRxY9mllQcI8suAjBu69ugQolalTZ4QUQHtW5Yq1S/" ..
	"BDbid+l5umz5sMJOQCLoS3ex2QWYna+ZpdImEGLzyT/blq0RbjM4X+IFmGd6vLKi/npVQz56u9u+dNZgTS1oC8t5c0Xp8ifdpRPH" ..
	"cJnEEp6y+YA8DLFURWsSvcqaRz4CuM6Sv+EcsLT7jRc/jnCBsN3CT8L1KKSKhM4eH2OE62NHqVYUIsWkoLkCPLU2OqesDBV3Zv43" ..
	"6EkykR/wHSSzhLk3XCVURDt3jCK7q7I90pBvTcrv9AOdtxuDPrxR+fJHSnNr6jO9S9HwanG5lWOnKdf63ZJSxpZ4FxKyfakNpuOH" ..
	"deEbVjT1KF5AmuSOlIR73laqB+EIgqxV+levgEL5L9T/K8hLP0ArfvNrYw+AwBkdxKW9rRmo2jC1oMsDAaJ/sJTy5ENGbnSxe35A" ..
	"bWyz29wDKxM4PUzSGZV5mZWkWgURTgIrdSGMgrWirIYjBxdONRnbh/8Mafzv6tCorlyVfNHDt558udo5d2vw5XeN3TAYi0+cXJNn" ..
	"UfxoZ80KxUS3YFDKAb2cK2MDVcOfBNLHTwmSYTUrKwHcz56ShsqFXVzx1rsI69RpK+lHsUKWfhGEKiTp7JVY5v5d/6rRtK5zSEsB" ..
	"181SL0TVTQGsBqf/m+HTCoHVhotFwNHPsOS0tpoNcVlAe0bzEEVNMqA9yWdcdvlxvtN5GL4gv24qdHwVeE3vsRzVmvUFtvp3hP9j" ..
	"0e3+tWQYVRnPog/flgBT60dDH0pE1Tz03+90wzvRXD0Eq+KwMFzdsI59Yj7arJtZ7AFb3NYsAYQ54LR6KEEJEDajK46GVaaz6Bcw" ..
	"O9xJZ5XXg1mN9cOiH1lU3uHij5scyHRI1cZgW7uFNdxuoRSTwyctWLKJGhsnGwAm0CU9gMR+UUzOEcgb5ZJmeULLy3KmTuwvAfmr" ..
	"Yvh5ZDCFDEHRubN/4Fh93ufrpa6xINgJ1tW2EoAFd3WvlA0L0Nnke5DyvXzKMHsdAtNj8aB0+LHGHp6iTHOlx3U880BabhWWg+Hb" ..
	"Ag0cKHEMZrQKIroOPoCdQ4/fNcLgg2RwTr6llfrzoQ2tZtFVInX+PP/ETQURkkWoAsjaK4ccNX2uczN8ztXopJ8dovjL6nDzC+JX" ..
	"yeoyDVARhn7QuvLCioQ3TGtJSMD3P5S2BMTH6T7gCH+EgVeYEZrumNeh/TlJEmhPzmX8yoiid3ClYIzZW0XoVcsbJqpDy2XlPh5+" ..
	"kWzXgS4Mpu/8RYkYhl/YhkUjZZYqY3et0FDs2hWhxff2KvxVSQXz+1lmSLF0+6ipPwpptyvsnnzyNBWmrnkE6ULY+9CqtvLUk46G" ..
	"upEelgQmsXKIdlplUUTJaROeFFKHOe+36qfwYYi0m3dAmvZPj2nAvR/0O70emtKJKGpFkQM5whK3Eyn3P6qx1jPUQ4ofuC8AXC5I" ..
	"OfKMKWZ8AJ36KfzuZAn7MHCH83nAFYcnlhE3LT5SGNaoMidcHwS6v8j8uC68zAddIAYmTlaFxZhYGeGxh4PIQhBpuPkk7pS9Ux0y" ..
	"lCS9v/DxKP0iBoQsQDVWf3+j9940WcU7CkoURjIJ1vP6slngwxkF+w4nZ2bHxf00NZqhQHGlXIpWGIo9PqbEkUJzE75I6bko68cK" ..
	"bffyvcKfF5WGaXncQ3fwxrtUtjfd9D490eb5jr6UcIC2yjzut3bg0+dtvtYHCotcH8VnJ8T8j0fbYG7Rw7+76HKJktjNkN1V1OKv" ..
	"p2LQVR1k34Dmbv316Ul7tFzleGHiOwYC8VdtNZkV5w+oYfN+TKPNpKlDHkqXT2i7zOD2CBFrZNnhGBX1GFL0+sYr7o+/hUM2LDqv" ..
	"QVvxmLiiecTqw65dBkK9h+/79fgS5FIUAbkJfPUjyD2VKXps/4d6RtTS8b9t1JqcoH6HekIWdH28ilb2bSnB0i7OB1DRsSrRTHRN" ..
	""
local PAYLOAD_P7 =
	"U5fE+i34eab4MeEakprrwHeO9kCSZ3EVgbIuW7aHRSiCYeCE+nttC6yz3LcnUKkqlKU3blZmzvMRvbZJjt/1rDwf13oiypdRIXbk" ..
	"fEX0SbJTFnE495hTCPLQiOjckm5JKYsCXfX8SnADRtCoNJXP0MAUElojA9imic/xplg6M/Q0xpYdDwg6Jyv/RYyik6ZBBjLdmqIF" ..
	"EzAMiGRDX7XSnQU0dgoCz8AhaS9/NcWau6oU1moeo9+wRLlJjjv/kDTCqHpEPi9BpaHfblrYN5UofsvwuQzTFwFDkcZPM0jkNt4m" ..
	"2ZX010IMqFfxz3Hp+C9qoVZa5cAk/nZLJAa+tBH8WEEEQyUt+rGnMBp7AwgBkc1kyKuGLE43JWStWb/SFNWiINtRHD8JCicEGTYQ" ..
	"drfhrvkfLmk3/RncLp86e/D4e+n21SLHi09x9bwKisf06xXfHcOJHkh+lcseCp8TE8K/7hwP/1BSbX5FLPqu1x7FJfHiLf2ttZSy" ..
	"4qdny8uQ4ZcGoUbeWvbDDI7ayGqTJeHJUc7Oa+4ONXGo4b1rdC/HfLAB+20GcuM8ua4zjFlRBLoyfP1gN8QsPUWLow06Vq1N4hc5" ..
	"QTrJupvwSOTyz3fpNLk29N+FFaeEcLI1FeliX/s58/ijewOmhA+HR7caDVPOusHm02pPWXrp3nRCP4kAn2ANqMZXYg8xhptcwfXq" ..
	"UZjoSdREo+Id0LixxPKl3okAqZG/BzEsgDPXL9EqoZftZsi+GUs6PMOrmvEs0rhvg4dhAzziBJohlwvKP912Zs7DwYzhJHHSiASL" ..
	"r66G55Q+AhYUp5T+/VrdC0swWZpmkafNcZpKWrLA6fnmwwtBsxU+bXS1nrqKvulzTQSa9CKX56z51yi6lop0vDkf499ujGX3noAq" ..
	"hGeWrrB3xj6ImBBSGtNdvrQCC/otI1RRxq+N6+v3TXLWy2L/hHlsu12izYSWLIDYjjPmXbk9I2+tHQ6WOD1oIHT4hTVUbbZMQd0j" ..
	"ewn3eTfsXvvxS/rnCvhTF4WH3nc18iSNuD2qRo4dDlGy+Lr+RYQ5y/KmWP/RkiwY57/0FfaIEq+qHyiu5D0dywVJTOqovxqFs23e" ..
	"xb0w6Q3+Kfz63uJsJL2grRRrG2lyzOcJX5EgYjEgifb+Gtofz2rm3myTfVtMSQF5Ar4z2EcQr+NpADULIDDfx5Kw/h9X2kAW05mJ" ..
	"NhDR22ATSda+LhNZIcNL0ZiJAw2MuACEhsr7ioqCN0FfgbljlJQr32ePSUP8qFbmYhsru7T7x44X8KOfkf1yOearW3qU9G0A/9T9" ..
	"M6DsFl7U+93Lc0XEZNq6QWt9vfOi4A+IUijQkoi3qzQLJYE115B4f8eYhHA/e2bzM5MCUdWhEQH00k3KSdp0ca4yu9a2AmFR2Ofl" ..
	"q2eRtFBpsLRFLe7QBKPkvDRZDR7fEU0blQJ5KBAdAxeLdOj3y1dWo+ZXEZi8s7QivCzrJLseSEWqw+TQillFQUU/2ffKGCMuXKnD" ..
	"7GxF41SPLrFkppiTiST3vQoUsZF3xyX09fGW2Ng/b+XgKTupg3dJ2EMdxG6o0WMMDjfd+4cjm3W3BPLPpfcP2BVEg3+Hu5bDw0WJ" ..
	"7mHS6XjBaNgaXR7FUlhC1jkdev72hIG50ERmUZUHZPAINNWsI9H6IKPQcftBBCTrMQqhkpmbPqKepjh+Qj3c86a/wNsY+SkfPcI7" ..
	"2DKiI9LVb3In6uh9WV6nByeK3fastb6RwPgKDmLRmRpVMRwOlTesjom4wL9PYJJ2YW0SEjB6JUAW62H8F7hPq5Sp93hFVKg8Dxd0" ..
	"VoHbRSAAKFIg6ySBcwbPkmV3ykj8/srwzdh4yA8sZI02DC+rD4XV1rYvPR4IweUfoarZskhZ0lVnTXZt3CsRpt/hpSFWZNCW6HFi" ..
	"QjBmZamsjbWNPvHDirZHlu2xnmVNgFZ+BhSI9S8WeTHwf6EOreUCVFBNk3UyZivOW2v1ud4Wn+u+YohETGFYepU3rZqO8KXL++zA" ..
	"6vUq9AKMA3fsw812vL2AbwZ2G6VDwSEA89o7i/s9V1PIQ6OVQ/CFc5RBYZ0eUPffds90oZjzGriqwizkiRyfb0M0cUuMCUmKsj0Y" ..
	"TYQvF5OppCNIoDgX2l4Uvp9Tfup2z3CCOSX2ICXR66Hv41pfeQMN0P0m7eMSwtoKUmCYdGa+lxo+5i4xPHMh5CAnSvAPaEuaUNeK" ..
	"29ugx0MbQJkQt/Uyfj0Oe4RRky3gqtzLd2yhVizDR17vAQTYsBgs4k/u53rbba68H5iVFhdd3AhIHag1eb0nrDiNP2ZenqPw+46T" ..
	"TmXlXNxwjZP8mLSUDkuv3dCl8VdUaLd2f5QhvBpbtWALGB0S/HZd9wTj5G/eiM+e6RJflgNQ2sllNpTiwzg7KnwdGH9Bi+W8Gnvu" ..
	"X+2xvNq/aQG1Mx2A6eLAtrun/RGkcwBNQ4RkaoIa/5i92BC+QZdZaf1bzlRDZsOPm9+q6XsBjS/GqKLy1W8hGUSxsY59zTxwtkze" ..
	"FRA/j5DXEkMuG+Sr0dWTVzfv1KOMUcCH6wAvG9EvdRLIlGhqDR90LYYdRMonMgTaSbw2ZE3BDjCiNwdLArgKQAvpUfo0AJ489rsd" ..
	"3K7/hn4CpR/Uiqj6eda/oYhp535yjPbOKEMXHItYi4eAuusPWzFtzuQf2fwgJ7caSRYqo+Ot1Y+7ji+PyRvsuu6bIaTpFRCW7upe" ..
	"iCsUbJa408DHg1YmuXvFNnqAMiSw6ea8fd+eciil0uqkdBiGh+fnoGzGYWysH/IYyId3kkG9FI6KilvbE47dJ4YbsNeZgyw8Yzvh" ..
	"uXWtfLKQUo9kI1lhYgfCsfsnyN2MaS/RcnL666dPacJwI+GdE1aLoPYrg3sd/p2rWzDwOqpQ8RUH4WegJd8mN98vYG2BBKvaMhJ1" ..
	"NGE7PGP3gD9iGBHf508mnJAILXk03c12+vnGN/TNizWcIQdRDlC6iv45M581FutLRfBFhcjLo7bY9LvQfst3tey4MTkztAuK8qEd" ..
	"Bf0sporLbTxwkfw9nPZsh98mnS1BdniWeZcSOkU8vxmZkmzyaOVy4iGZCvHwWyjSGjxgHwkGL0MSDiQC1ggm8oLl68A1Izl67dNR" ..
	"UlybSs5UJ5p7Ue9ao5UZQm57nI1FiyAfPoQzPIbK7q2f2GAzMwT40qBmql4dRs9xiHmjvF8KBITApAqFklMc+3CJMTa1oZUMAJTF" ..
	"UHySkzSBTsXsDexCT9X7BH0pZnpc7OLi1yZ48oYon97glP61PrF5tQjxKCoZqBXLvTiipKp7J2AEJ6RceV7QqlDVe0qwKME05qQZ" ..
	"ae62wja8GVS+zr8/Y3CaGYGMCkjUHL/7UP5UTivSrVw6geBgHFzToOgz9ZSrRj5AeGq7LByhp+Gc75vKiZ4Wb8U/bzb3R2w3VZ80" ..
	"L7sscoHpP/Kp2VsYz+B90ADlwiJQPYoYY9KJRgt2b4sb0/KJ9CN/or1aMy6J+Wecy3nII5BckWJzsV0UaL+cLtqJ28GxvSTdYj89" ..
	"1TURHgGB8dUbET7ucCE8yK2GQ3Qmj77MLoUNUEaFQJrTkmFaLdrYhfH5XQfkceL7Iki4OjGdV2/pGlKbhBE16eCSYbqN0jz3XRwV" ..
	"xMT5Uo6MycWr35VwVRrgepDGpIV5/TcIVwz6HfL1ecgfzhl4q3Szzz+fR6JCKJokRaK6T6SbYRfgPVhqdk8frJrfXzwdInjzI4JE" ..
	"3Jeb2xwAkZcwmNASbexTNo8xndJboYJNyW53yZZrR2tZDeo9t8gmJLLTSrPUd0tTl87PbWi/jqwwf0abYKjvuWN5f+mXJiUeKCTQ" ..
	"/MQBc5sLzBnpNBTAmUhUNO8+fDOD31XNuIANEjhJqWR3UQrchYKQRszjYlmA0d2VT7ObxSTdVwg9otQwgPYTkDZmdhJIuRb2xhWU" ..
	"VUttPOyoZeFVjGoZRUyNnJT9JVkhvibjCeI89Czvl4LjNgQaFCqWjjVHHWo1W5m/Ls8Y/aXiPD36AM2Nw5Xikz/3ITbHgullMfW7" ..
	"ifkoRuDbbQFpC1FQUSFotmNXPfdE16eZ56PSADntzWikK30eGlpZYBQNSUbahCLK/pJfyaS9y3moSkeuVi0G4w0RPESWV4SCkN6y" ..
	"2iqnTV8JYIir03NJsaBeXLPLqO8G1aPimo/FmbmgSfB0NVIFdDe9Ho0tTXewXALoUKxh4yckCbGbfiS6qfNzMx5HCSXu0Ra3Z3zQ" ..
	"3qKQ6WpccO/q4kwDGzczHxxt3SR5ZqCc5JWpXlEyYZOHIn1Fg+gknpvoyR8w5O2exj4uoonnAib53Iy9PvNUCMHxqQ+s0fEULhSe" ..
	"/T0AHlRhE7+9D5A/a9cI1wcBfZ74/M9mjBSjMrWTMLSPtpp4fuD/34igEW1HgTmTsyw3ObLMxiqbj2rdjgiOd2tMnIlxHeKBcgMN" ..
	"rRKLVTBDtN8k/ViMbL+XrFLDtgyb4+BRZxtOEm4fmhQQwek2SuJB6itQ1OahcVIiHk1liMULU/ya9wsiLNi8TFftcbO0P3/aubY1" ..
	"Lo5vvbgNMF7a017+zG5kE7HTMN7ehlrqS2G30lxCA83xviNE5yt5bbJBJjq06UAb+sn7esQ2uvmccz2OHRggr/o9XViqA05AE2HN" ..
	"EmnHHfpL9m+QhTClufrIZR2FEWdiz6GIrs8BvVHpprfze5GUbcu3kMQm/D7HPEFemDh8vWOIKdUphGWlGE3JKdCIZyHU7u2JS+YT" ..
	"gE9gT1mxvGhdbHorOc6CUJbb4/KJkJihtwr+r8fUsbJ6YO+2lFpvViEpo2WMt6U0sTOZdZ5JNOO6S/Q/IbdhgqtmHYsb0se7Xl1B" ..
	"+WQUQmJmLG3ae89tXNuuGY/UAzqsB35oQR/tOBmtWyKjLgc52PcSMcsnfzBm+dQ98zq9ZDp3vhM6tO5Qk6yEPfHc/F2jmFRS9fO1" ..
	"E2ayCCgjubq1LJf6W86K75wnCO6tLXM3eplAtMHbeyAEnVzHKL16ayGoYioqJuRGrW73Zx/KLjrcZ+TkjzS5EDP/0fuVuSnKu9RV" ..
	"ASy/AAXDd2svVUsIGin+yvL2aCDOEyh2RpEZQy0iStyYM5dJfNwb2L2eZDzZhq7l+WnE0eUmr/mYv4CJ3pk2cnfaZBXNgXYCDJ1E" ..
	"ckFEgl8jCE7cZZmo0nMGYCTLUTMrB2220hKc4G/j1ZHsEVIwIzadXSCei5eOSHDUBt/uHXrsw0HOxlaXEB9D75LFRZxI1BheZxBH" ..
	"qV1eGx0Isi15ykJTmTxPtaD7vwxhmK509xZkfD++/p75rjBWmTZX+LK7RyekOq3RxuVmWImBtDjmAj4jsmu2qM1HjI62FKNTuBeL" ..
	"GNjpdDzT3dgAVs0Fzh9lye44XrMFhWUSbmMLedrVo0drvxQpnTFPHUMtTNfVDPBtQewIIuWyuPhX4eMAXbcEy2EkRjT852FAt4yv" ..
	"s4IEna7sPhczHsYoLiuB0bcyLljBPDF7gWDFA5aCebEM/02f64RQQFCFOL0Tk+peMpeOewmHTw6UYmvoU3VDCqzJr3y9XP8AkgQr" ..
	"wriQYVXSksGg9ZTi0Qi69nm2A5nl6K5X3Xrx5szu3WaaTS+l9xlozUpywlzHPVoFQfc9c4SGqAiG8mROwp1v6j+7AJIQQZkZA7dx" ..
	"BT03MIA/UZIafzW9X8334iT/BCE1QZR9mV06hbllAJiWPeoiAJCASj+zsCLZkPji3qHhJzRgABwWTyYA6vRzsNdO0nCTbYrnAu6R" ..
	"t56ZVLMwdLTu/6aR79uqDkpUP9+KKUCsRxXTGzrZIgLD4ysH8w8u2eE88sXZBjYHCk49YG3tg8fO680De4olkYhi5Cq7dVzgGA8/" ..
	"yLBjU+2/YvkxmMPsrxDZeTajgislqbN3tyzfG2eVij9LfmjxMSpFIRH/Uto0arD316o8M6Ll7QhmA1E2XDXx/DRtD2GwDdXkkSlZ" ..
	"Ms3LHkowk2dS26gydi5M73BvtP+imwnDkzJP80h69KLPtN14GCmEsUanB3PH1FSFdMDn88RO6f98sfBzR5kveRDJUu9yY+zwfwmt" ..
	""
local PAYLOAD_P8 =
	"n6Ya/m154+y6SnNObh0KwF06DrUtm52zBepkjl6yraaKQMUD3hlQyRCGaOEovcOWNfQ95DQATZ35jDkAONvyzhXV4FUOTm1m3SUp" ..
	"aVIzG0acMCeFiUdA/dRO2CI/SqmDex9wltnJUoS5GdU1xYNmQ2YwybdDKgPtejuBGrO5oV8MMKFQX2HlUvpw7yHlnXKZZ2hqodQx" ..
	"xFDn2M17sym5C3ia8ncYdfNH/vlw7Uy9eIT/9b+6NDW5Xc6neOj9EIUsLnPKlViuy7tq7djkkOjf/Lf8qLQ23qcy0lqecUSP4sso" ..
	"PL8HnPRziaTwjlTKOE2FhzC2eJ7jLUdWPb0giYmhH5GJ64NQrZyjQvjYLE/nohtDRsBOl7iwKpvqQcJGuQC0v/h8yL4NeOD+91Hj" ..
	"+1jHmHE2SvwXwvxENMpeusI23VweLcsLeTmhHD7QtEI7BzR85obauROi72cDXuNO6R11LwDh557wXxT0dl5rTxtr25MPfB040hJM" ..
	"sxcfk8OXOvlRkTCOmyQo3kKKWPSLPv6gh8I+MVpRayAhpXRhYD4cYk5yym0k6qjCpy8G+IGrT1JrccAIyPwl1eumJndedCT5MQMe" ..
	"YTpFuKmmn6oDfAaxb3vTFyKJMfuLgheSt53fDpKEY75FAVdqSRcmvbjBWtLmZU6ZqekQkq1Z8Hq710qqDaA42mNo2iGlGnC8yVtb" ..
	"PFwjRsPlX6SL6L49pzfTZHjpDRx3LCcDSFoNxu1zQnywGiyedD0w87eij/fopydT3fIcnmEoQkNSMuFZa5lFqH9em0205Gk4doDD" ..
	"syFOorqrHUlUor8c0ajOgBC4jMGCoMZmoX9EwlQYchfVxdvQGSN/4hCBZu5PunzqYwyhWvz8euhcbSdxmb1Vp1wbzV4n37swbZAS" ..
	"pR5HKuCGjm23iFHRQCmB2luuGIl3RjNAK8HsZzPoHeNmPDGzsk9xpb6vMEy9kfbLhl5qgIVVz+esFZYiE0iHhcgSetdXuQpGmjKv" ..
	"8qddeboJLyGZ0ejKULitytQdT2I3/aHb+OkzjeF5/0WIr7pCnsQQPZpWx6s212iqW0ACMM+MsJKsoVFsMSBnI1l651TPgT6wiz6W" ..
	"BiGv3dn+nI4Ik/AxNkzDaUknnrJxKIwjYUVhKrfDMq+Z1pkqsh3GsH4x9xGPxNyo3JcP2W4fGZxt1ek8e84YUWZbk6gmghqkf3it" ..
	"QdK4mn2zOoPGPeC+yw2SsrcybTc1Fvjt9f/BXgchfvEHeqqDQ4rDi4PWWMzeuF3KdwbenMyioOm6YF0xPXn6ExOZ0VBhzNsNLcJt" ..
	"svhyVUHZSseZl0kia/KIvARN1qWviZG7ygrddWy+ApIjTUnQvikxTEOwrsQUFVlQGf1hRL1eXjPqN3dPDfLMuPz/L1MbGxeM/KO5" ..
	"fABovBiA+PdtZxQvanSSRhj6U/RUx9j92Ywjilj3N7T+NOdUHaogIItHRvD/UxO4vXYWhGjSkauceo0MpMJaz1a3A4PAmXVGM1cr" ..
	"rSr6GPijGfrpT+5tAnuBl4YqZH1oS14Jpiaxn3/rf1+7QdOoowhssfjb97Q1zLz/RMleOd7QIzgZ6sST9TPQ/NvOI/aR9QmJrhgE" ..
	"t9KU5OO3oKnmLMremyIRrSppOmCa2AZs+7WHsTM8fP20epXUnlPhcRRepkBlX+3O2P5mS78rmaCujbhgdA4hi2uIXCFHlpjbSx+k" ..
	"gYeH04d5TvTduddNekcyJWpmXwqU8xU3O/zR5uXaG9xSz24nPojiSziAKnk+HMK3Lw9T828rc0a78X/eQSk1U6q4/0i13puNxVBS" ..
	"Lp2Ka02f3D/W1JmIY/lDf1TNeayHQW9VyIxw1OB+i8aOXgBS+chIJqf6d9qhxUSmPiajmcQcYRH3XT3IEozFj8GFY7RAkNcTmIxy" ..
	"I5VTAxv9vMyv6e4Fxv3MnCvYY7y7ZtFmx325JaDhmtNuZcFF0xQQ8tce3dRMdPltD/wSQoSS8I9p2hhakud6V0gspLeJ9BYAezLb" ..
	"q0894crV+naTjyHULEUzritrJbijMx0daoS0lkbrz7YN90E+aX37aThfytGwqAoAhQJPkjFMJ6aYE95sKM8dWwC9/Wpq+bj1wVAK" ..
	"+/nXqWb/aISBN3VshmcQ7DUtDlGvDQug+r7ofxRp2xzOEupUdgrLoeYKqTIy5Esj2PO8U6iGj00dCSCDMQt7VM3Rt+AoKLuqw5dR" ..
	"wsYz0OigSQVEsqOLZUwDJK2zhlh92tWQXn53Pxgl1BqnbjTNIWIW4NgdvkoC9KoISxUPA90uLBpY543uqBz9IoutbAPkFTQoJA7D" ..
	"IaU2vmx7nFhlOQDh215adg1Cq1xLnvOpGS6uMrPUUSTxAVo+AgDkNvCXM/YmpQHelyPS5ZFX77lchftg6luwcMN/p4Iv1ik6c4T2" ..
	"gCLuPOyrMHm8ZWUPa/LStOtTUN1ycBR+97wPm2nSMIg5qFjCicsOpNYxpLF1rpxg5yud4coGyIlaOsyqLD1ltQEYkou+DV9AKwHX" ..
	"O2IHBJ1gNkOdUFoUS6LHgm2KFulXU5dISbpAHo9lTlYB02V7tDBxiXPDAQff15PLvGSjfRKyVeJyiNQPMzj1S3egDu4zZT+uDQ9b" ..
	"IoAU5kCk2nsmRvG6A0w5Xx/mlISCo50bhAhpZOr33bAx/i7cJx9OVguctYMtLFIq18MWvC2TX1BNpLNExP5sbgeJpR0lWci2rF16" ..
	"HS10HxkKJsJ/DHrlzfcGT8JysjlVBwNKHXznKhrp6L3b+ypsLX4ER0hyBVFUpztxOv3omkWJziXNbtZfDsGauLjpdJQtDPasWPu4" ..
	"DVrJybG1du41dLyThEmOs8DxxA2fr3EZIOjkqZBOMcUAgwUyuTr52gu1Cuv5A4l6vNgKaYo3Jz1TSrkAVfvBp17IGgIVlA3K5CQY" ..
	"i7Wx1dzvvWaDRCQgFxBHgvZrwmYqi07QyljO53n9kHgS74w39/d6XUctCUvQrGPnil8zXdA4TPeP4EWo0N18dGaeblpHXbWnW0ba" ..
	"QCSgI8dIhzRR5OwhsA0BXk52wGvLiZogUw4Pbz+LGfbc5azOltuzXMA/T9dmWncUIJTT5o1SZDKmZYAmLyq5x9c0dgEXj6yfwC4v" ..
	"GTf6WXLhtClXEBKBe6MvaLWhvSlPCR7cEobMi1PxfHwkSYaOxv+JfvaY9Kl8b2gaQApaIR7tG10ogOFL4Fz2WfyGrrWQSQglDTxN" ..
	"1iSNt+QoSfRWmgfIFqJDLu2Srdf/aRoo3ulsY4xJbBMZMCEXxxNGDGdHduTZ5QbjZDMB7jl77h6WYLjnN249MnBx9N0yL1ogVBQh" ..
	"57p0iLnRlLf+2JsnMzR8ZHKPRrIT9OE6Q5PFftUJHj64jRqADAQcuXC4tjquQohadBzaNFzNFrsE+85YatEdozPXqq6lYEnykkaX" ..
	"fw4Qznuy/GiejCu9IL9CQg9qR0kXgnI2l1CgnBKCCIpEIK6EJkfmRKpJhp34Njb4EQjFNru5bxEmaFvUm9xRq9REngxus17MaU9v" ..
	"MoIihzc7aTlv9XXYUUdCiS2nvCZwq2zsLsCEW6w9Cvjeoc5OLAWkSYbxpL803apodKOnuMp6qiXJiO/J/VNWD0w1QNGxRnfbd++3" ..
	"v4auO/DeJFr1UqBNXVuD+A4aoXicckY+bEsUlYZ+lRKbs/owsYMYDil6Bk81D8CFrl9B0642/xH5Yji5iqj9UiZZ1WWmyIXc4s5X" ..
	"x6QpVjDY0EbT4i+IUlvdi3labJQEjeHnoXAZZ+beLzo3FBU+JER4XGOOZWHKL1nCg5AHASuq2tChWNwOiNTM+X6H7BKPgBxmUE8F" ..
	"6ryWJh02zAqYJqLc34G90LJmG0WvajJUgWsOSfp0gEBdLlwwbfpsN/ZaJ5WuM4pFUyT1POob7yJIr2V7Kr/4xqUASMbA7wDwsQec" ..
	"xSmYeWTQbBzT0Bj4FPhUsAARhGfszJRILnuBs80nZNsGloJJWW1NdJN67WHm8FtTTS05439HOmiVsxgdGoPOGxrikglXKNNKlSwP" ..
	"nzmu31eyYA8AFtzADAQkuWGTMBV44IE831fB5fAZLXo6YWyzYa7NhNAbo3T09uQdxIBFI85fKBVmM78OdfR+zOpjtBFYwhD8mn2O" ..
	"EADeUbWKrjn/IiMmPinxELH7qE3+1s2U3qrJod3zVXTSGzGAcTIdrH36jLNtiBpQ6Q25noK4LwI/vFi9no89H6o+IG+A41s8EFy7" ..
	"9AapL3DegKRrfO/sqKcNkhE63Ao2DhayN13r4BO33TDHQrfX4rLa+W3R1N5r1mk/ijkxMV8HX4JjNj06PLw5eLXqPcdHg85kfHqE" ..
	"mx5FXOkssczwClGXvtVUXgGzAaYBuJtzSkJc8RMGe8drfNh9EomHtz6iC79YYPZwDotA8zYwdPf/NJWnwa3ARieeVuU+ujhkIbCL" ..
	"4UZTR6BCV/ouq56SluokdRxmTxRcHCVqva6YQdQJwyKqz/i0vx1p4EO+fD50XqOz0ga3RoNBcO2V6gluhI0MlXwOOdZQtwNNpYtk" ..
	"GXiHEZ05F7MNc7KnBCtoxd52afjAI2+2oE/HQ9hNUbzYEWXe2AWA0IWPazHiHDChTegEKqwjSAudW410sr7uVHiN0H8a0jsZpsU1" ..
	"DZFL33ZeFJ22gaK4Yw4FsyohCAwg6BLL2M4XzwYK739GrGKm5lCR89ADwEIsh8FgCOLEo/9C3IvuEdbQpB/MrqkSyKD8Qp10TG7D" ..
	"Br+lcCmEQD4w9BH+fQaFmglJzo2o6UQJLXCslfW5119ejIvsbzWwSmfPdIHxB1bfBSpeIsOHh8F398MCa+DGo6te1nxIIDGc1VUF" ..
	"MH8BbuIoaovPF46LuZ8EdnY6rIX/eZX/daJxxgm6rRw6Zm4TaMtG7tn8nkSpreHqPaqFOba5VJM+qy/b6uFi7oRKqIwM6b01TskR" ..
	"k85K/AmPd1LVh9rPagcrV7IP24X8BL/AWdkSCu3nfPKPg4/yYfhz38bL9BJY/+V9I+BTcGRYfpXc5eGyZhaDdvd3vBNrIljEORln" ..
	"WpLAhQnjrDM3Zj8ruLUQzO7ZMklC1l8Sb/O4DPwhq0xhh62bwCb8+0EMt0ZW6kB2Im8SRqfbYlNUzN8Sd1bACNpLfvVJ/qSRrKxA" ..
	"mnzlbzOXyjpyeZJqRMrC6bkck/NSeqVlesKFVnxGdkL+v2EgLnwo+1ynDWmFVfXBKHFJR4TLkDkuRaj8fq4MTqkJ2lLsGBoFd4/q" ..
	"WyIrJrNsPm93SLk1tIAyGGtxJiMJ+W/d4ziursBrWAP9m0dJlc1WxIXdnLNkb7OV92Goky8EmdDAKe0yYI+uhuiSdGvUKD9AiM5X" ..
	"f13xEmeYQkz7eUerPyaTPNqiuW86dDFOwO88TCMgMQGBG8Jws9mpuI9v44y83gsrFdu62Gf10X1B35c9g9l0BhOJ+SS367qF6Mas" ..
	"pdwEzLM4Uz7AqyhWr6jZlSklzAgN1PD/DGpNEynXortlhbUZFAgpUcLCncMwYFLk4COtBRcj9m/pnGTxuaydjOBmBOO/eSoEYLMC" ..
	"6jyGRTsTQfi4ifljYaRXV2g2YD0U6sPoXVZKEWR7+hUHG00xS4LzZrMfvuyift+Z/TtsOvIDYaE64CfW+OUuC6wBCdXkvEJp7Z5h" ..
	"FxhOGQrWwbaeRcmgW49NVAJesfBuWtxDjikVI0VY5dDajiuDCbFAbh309WukyFfJJVxGj4Mb0ZCMMSkYcPuTxapkKodhULLOtB4Z" ..
	"7I1UKgE0tJE2Rai4lgGIq/oU1cdHxXNCruSkpSFrDxKGZkd8dW5RvxW+Aj941FMqIHGs5YxhdAYS3Figq8pwca1fMthAlsPxNZ/Q" ..
	"tBH4+eOpV6Mq9DMAtCduzq4l6QfL1D0aP5LqLP04lKQGGjSyJoilRkyCyorwzTCu3uPsnWgt853tNju5BhHaPnljb7YSALv/+V26" ..
	"PzoQtZA+G7+ho3BBQ7psIGPG0+fnOiHSMiQAxGPZlyjHUuVzWU3Y8o+YYN2eIwSHJm9cvT1TISdAWb2HMij+XsIe0YhsdTxHcm/e" ..
	""
local PAYLOAD_P9 =
	"YSEQq7Gmdb+O0Y9ungjDRlu9qD5XJhtsGR/k4QU2MmlGs2e07uEhJdBffwDgb/LXFMw9FUJkzesPwAFTC/g3BZGiH4IotFJozrQC" ..
	"MSuHOoCiROJ1hogtPbO4v0Mu31dQ42jHDNeFkNswPBCyFoO6BkpKXZ1Cgt0Mknweyri6ibr43JPVlt4Hp/ORNNqlVeEy+Ner4Y3Q" ..
	"4hPM0ZDt4/3wK0XGJSKlPAJzXCaaFwffn5iLZK6FGycYNbkmM12pdyYtTNDMiU7sOIDyqWXFuSx1vAIk1DVj4Kwbq+dc7DU6nb8C" ..
	"sLr3p8y2eYBE2MmvpfnHNmYq3EoPsL1x9k5IFDG8hRE5/GeBZTYGrJV2G2RLnPMlHGMs1pg5+xopanje4Yu6kPWQCUCxx2fQrcX6" ..
	"QU9isAFze9iH11zE4CN8cC8tTWAiDFHpYvkdq6LnoRO+i2s97fWLnYCNfOET9v4dDDC3eELFhAafY398qcisgV6tQcxv7Idao3iW" ..
	"8yNhSzA3OG/42XmaF2MD9gNSQ1zQlt7Rtpp23jfzs+7gJgQiujf44W6xQsNdhLHK4I1ZF7CmL0KKDUKyD/OadTmv2sV3fFZdOlXU" ..
	"4v2VOBuXwQwWVv0lJaSQX04CCtO3SBf337qid6lJJz2vNEb/XAkE+INqn4ZCEg3qRTcE8s195/A2rEIbCN2j1xFMMnH6blSPpBUG" ..
	"YPxGMhjYpTTEeFGIWvf5WpJ3dLv1age/SNpfZ23H4sxnTloGOaBF6LveFzmTIYIujpcZfthGwQ8bB2HK9z2dKBtf2g9YW5LM+DID" ..
	"X1Ric3og/oxpeX/+oxIhKyAlHKd0CtrwHcjfOOOefRS+4JEmX6OQT7Y3v4je9KAmLGhNPBDqu3wlCMm3EZtVHIUiYtJhls+6Jo92" ..
	"Pv6+MUStlz5MeiYzqmVXxG6sbV4dtBXjET61EmKmS1sDNEPpyPgRFEVYECI0Q5NFkdS1jlSjNcGgDVpeGEGak1Pq30AzveqCkwqa" ..
	"+7v2o9UBVBm66C4KvKGuVwfYpkL13RgwAQ0Rj5h30bmtVZHcQFUGFJfEZXrOgdOrVMU/yaVATV5AGV4AfIYck6nJg95xlMLkNo26" ..
	"5pVeeQCe7SEEJulyWI5TxsI3/UpRotilEoMwdiw6kvuivScDxy/FwaFA0AA1LWN1jKMlAZLKI7eHqkJjleKnpOxFfptfBnBqCo4o" ..
	"BqFNqi3C/f5GR1imunJXrREThuyBhJUu8qBDkIBcSXI5B4+uMtZE4R6g1FU24Se54J1tF2cqYKm54CFSNzOPW4AbJoPNan/ZqsC+" ..
	"eGOvs325tIR3BeKzwAooaT28k9BLWB45D1cIETqCEjysTAvL+JUTBSliNRir8DcfZiZC95XXdNjDi9W1+6MHVUQmhaAchlMUPT1z" ..
	"V9RxPROGyICQplLuqjSnndm7sTLsihbm5yRqnXvAxdqTD2nfT2A60Y4izNZRZXoorMhURyk5vrItgFeQX+gm1X04e6G7jKtSUsKz" ..
	"vJX7DXxRaB2PQeA+k3r74WWsBl8N8/NgrUuCnqBCwkKlbPheF4sscqiSl2d5U3DuTLoZdRBkdo3almIHVZo2hTAH6Tp0jp6xZvn2" ..
	"FFVMKU0RMCHha1LyLrfS+VPzRga32SyP+uNHIF0hfDGFtjX3gkA0d/ahIf7ltn/wNLLyDheOCCtUqm83ZhpxOWkBI0n/KTrI+5Dv" ..
	"nK3bU9BMW/cmliwXsT7QJlUaAGZxNsFLzFA5056BbhnTjmdUy72WyefsZ/LCtceUBjlC+GUpODlRc0MPJGw7/RUI6RfNcNVeHQM6" ..
	"dQNp6I3wHmYfVREmuIusGwkBFrGGghm5flxF3PniA7crmhni9ILpe6gArCcPOQiEtlJLjXunDlGphuFB+bwg8DJkZ4hikR0T5bQ9" ..
	"tQySfR0qW6GXU7WUlyyqVMPGDuerKOkUmYI6y9xbVqmSY310n0XPDw1owiHCaYpgWRHYZDf/KEUX0+cFy8Fi9MSgitsMBgUr+AMd" ..
	"A/PMt526yX28PRLjy/5U6N2kHlKOsN2c+JGIyViyHs7yMIXnLeXEYEYRXHeLjQi85oVGbcdN0SRpxySJRrKjafAm4/KjPlLksAuW" ..
	"UN5r4rjBjer2R839qgGDe5FgaZBqvAl/jFnNUDzP/RYnatYWtiO6zFhUYQGc/9kVZxAorYvuEpQEoH8f5nxffKtKz114rnWQCDOO" ..
	"SZuTWqCBDa5mE+wl6V9IOZTxLCVzCT17GI1m6k7PkDyYLp4f3kqqFUL1f6SANqCP4awFDwL26AaalWv4Fjtk84A8RXWd1rc7tV3T" ..
	"w+44pc4ZQQC/1BmMvvvKJjeqn0guJJhR//22givj5yab7xDPHxD5VXC364hvUNE8saGGtJ0DdXfaRSMU0xyoYHZ1xwEKpYLEptAh" ..
	"4VogMoVONvSwkscvnGFkPxqRGpC9v0+C/RvPzOv2BkZ26wfeeMvyeaurVIIdCn63wgRiWyApkZeoEFa2uFVCqeI96veOn5v03ALo" ..
	"dNsjSE+ZGC+XdPksy/NiZoydPMriNc9XiTY/N2Ek3UDPcWjk0biNWt4JwQCwxf+vZlFZvMIxlnJPqtM3394pDHmfEmIdgmDi9j7j" ..
	"qhX+2aM1LonVBZyjm+/ie+vMot0NxxgHyJ5ZQjEJTTojd5sta+lPZgoisdK79SPNaMSrRxVL0RvQFhcpjP60MrVrEobjMORXQHvw" ..
	"adfFLJYyjV7n6cFImk3U/OTjPKB+5sS2Mqj8mhxhCknAuUBolC05dGPgzxB0zn7Ck58VWAreJCtJuI0Rxd7EsY3q/uSVWncA/Hj7" ..
	"Lv7q4NAlqQN35QjzgtQtBPaLMiwRy6orjmjARsqs6F1rWVGZsV/Xrox28naDG+lXh8Pf43cULbVJ/LL2nDcEfev9uuk3tVsVHJx4" ..
	"mCxKhT5w5QpY09Izmvdqd0Q3GbpkaZBwrIJRGUOCBA9i2GmJFGl8ZeXt0nz3XYV6f/yVQy5FYt/t7ZrDqx/5KSi3icG+2x+ZIDBJ" ..
	"hD7FNXS2gH6Gsa7F0SPid+TlbpGB/bG5YmAqtm244AofCHLfpSVX3DlN7kSvbieCy+aZyneTPoQGIvKF571tFZZHpQzAgeI04t9H" ..
	"jDIKKeipcbPFghZ1znDp8qNxB8kts5KrL5doje/GDTmTadWmdxRuVtZQUX6lOJYv7yKRkX5D/tzd18guIz4v0X0AYHVmiLLCiNv5" ..
	"iIBzeK2GdFrfNpIs5ocAf/wQxAfheYJMWaW6tr+PZwudOy3Q8O465iPVo4hZN2SkqtKuCoJ10fLkIXdYdefEplIyEIKkNhMZnAKB" ..
	"nkLU13QeaNbpF/sygJBplytm2Jx/eyfXth5ybnuFdqlvkEvbJKhv2uKkqy2LZ7HxXX5phjSNUNthdWYSHtJu/qJuXr9pNnt4BBlB" ..
	"sM22V/oeTWLDbHQU1ZdeGZWf7z/ItVzWBHVJ/FcUfS+w0ZEeyULlRwqsPPdhiJzofShdCwXb/ti2bRPVxkmFD2xlu50QyGQV+uxr" ..
	"tfM1vBvfMlVUnVpuJL2nH/9M8sG01Bu55Bwq3FOHg5uUUK+MWBzRiGjL/cWwtnTR3T3yLOE5n1/a08udOVT57gnq1ZQQX1BcSJfu" ..
	"bMilj0NTS/yQ6/QfluyDH80uBIsDVwPaUFx1v4ktTxiarJceJpbp2ukP1kYCnk2IQ4QdSM+g9nykoX+VqdMc9AT+DNMG5NlJh9eF" ..
	"Qecvb0hb2gIPgb/5hniLBcBxkUnUirUjPvL72UrBSs0GzKtcgBqCOibje3J/iiP7moq//h+QOYBFRVXPwx2pNf15LsM0TN/6Acj2" ..
	"YupFHZiEi3o2MQlqDSSsnTr8RHhy9zBwJhJYybYZQDPxtEpsBHZyujjVY54tMQ05p2c3nmgbboszI6FA3mivAeB6Bkx5agVcqJEl" ..
	"76YBvnEbv4K4ioZ/ZnBf98dxCw0dPlYNJjwjNochkfxKzL8J8W7kQE7Gu9ZSJI0caoI/BuT/JTcypno5JXY/P7E328ajG2MNs+PH" ..
	"WOqcrCfwfgeUXfpA5+zDjoBa/UIyi0uspta/Lq5DW/QFzRdW0gjsXqfgCkv/VplPDVbNZRHH1uT84POpCTCEAMsgaKHlEiIi3edy" ..
	"a+prHTSVrwqCIsQJrkG9MsJSDj4z4odGVuTKlyPS4Tue0zLpf44dL68UPIxCidEZ/G+DCc6aUswUzoGSzxE+pfXEPpDs/HqNpPyJ" ..
	"rO8cEaqMhUujgUvWJmSGHDi8L+2ofRzWbPpQIOe/Trqe+V1Wd/w8NpkC7V0EtHejYob/fFkCqGyDlkk7AXFRCwXcsVpgC4UZV4XN" ..
	"VCpeJBcP1Rgh2MPXiMy1mJCgXL0OjI1dqVs7Kqr6w3aMU3pfYt+9GYsj8H/9FjQxTxhYkQzO/4Ps8cgCiM28xnVy4IfUyLMT7QRT" ..
	"TmJfMJdrM+UQ41AXiPV+R1glgxu/d6cthV4Wn8Sqy638c0scvcpgaGz1fHfvgP3lqHxvjnxIHMOMGwNaBfSIZZr1sz7ElhK7rACa" ..
	"79lbKxx8wRa8v6cDF4YdD1TzTkL90nqTwK/uXEjAVaZjL+Q+LZSLskGW7hJp9qMNDawAlwLguzdphSxQXzcHYCus0V8A9J2ZB4PH" ..
	"GDr375iQVCXMz5GtUZOqZb/ReOpVqdxhFKiH6qp14TnCFwPAfgoNDEvU8el54V2Qd7B8Ja4gFmkCRCg/ptPelzNJhuSeJg373oWj" ..
	"N/HAZ7bWK7xZXSHED+sCJvCm9d1Q6004RiheEZS4NfpIekTX2YStwJ3C7fErYRhhG6/P2PdnYS24ngVxu+4WZXYIyF7pXVXP1fSS" ..
	"2EmcLUPSGSK8KOPSxCqs6mdf6Robq0a2kyf9kJCZQMQxHnSYOTm1Yf0mr0Xfbvk35xoOqEGuuzOdpJaJ6HW1Qcx5SvbmHglrkqnt" ..
	"dEBaZS5JW5uXLwk/Ij+78FgPT3TmDMlBnqLeWjq29qQ6PXIiVJSUn09QjcJXXGzi/V18hSy0o2r9I/o4kakdrSeUvWxHmfgpkR9U" ..
	"I13Je+Q0GzRf2MQ2X+VjsNVnLySWasfsVd+85ee9aj8xoUsgDPz2VvhR+3Cf7fo+qoaEi5EJUvTJCcSSGAOheUFKafCuWs3KJGls" ..
	"9uPFO8hP0TLdrYWbFAguJCFpebrfPxx8v3ADLaMcFchH/+DEAaCv83eboqvtFSK+AD7hdQiagn/vV0yJhR2kZ+74gpy+VmM+ox3/" ..
	"ucIOGZPe51GIBMEBl/Oe6vQ0N/0Q48QT3YmnM2UmqVy0gn75PEjA2Uhlf2jzXaTBWae++lIFZIO1SGYQGf2KBt5r+yElNE+W/eoq" ..
	"8yEiWH0+8P90s1fiCOVtpl9ySgMC/zAMn3D0zl53IKmvnSbF+dQeJ3y1kU1HukGT4VCzhE8J6xee1iY4qRxqZP2c78x8icoW4LwP" ..
	"uYe/rRvq/6kRMGV5/OiuHG9/ba/mMvhry5AM+HGEodijkHnj2+kPQcNz32vYJevGPIXeaZZvJ2XXVxDZnIlt9lS9kilCD5SZKgZo" ..
	"2j2WsvrtUzyeq6BqyTtrXxP6HetRbZfl4wa5/PO3X3NjunX3RUXdpmnweEqw0oYIo/kMx3+uDcP+aFimFhrO/AlpOeyoIkeXkNvA" ..
	"tOxW9fR9fw8ybg2QUwmEqy62vVZZmevqNb7w08wVSPE5xaFO13xaD+9TF+WXM+SHv5tT9fJGkS3mgpMsEPM3fqY1YK98R2X+/HS7" ..
	"mwEzxP2vqGJSCu84Kz+p/iR5dJChu3iWqtDj67W4TtaqMntYXEQ/GA+5L3j/MLbXqIYhE/1qmy7O/5MvIQD2J2Dd1ZXWFIH/RUCd" ..
	"mD3o2P6wmse7m2FfaR7x60eSSBNmCs60S1kCxpObFfHezuSfRj3edVQi6/KkvDxiyK2DEg+D0GnU8wWxs0cU7XG4cahMT5nNyYfi" ..
	"ROHGLCIAYe1qzKZ4R2jWuB6uV2CI+CGhbt7GTW1fQhpPEY6Xc5c0EK5OaQU1yJ8ZGHQ6FAS8brGqg6ZZfGS6OyvtVmXeIef1vibn" ..
	""
local PAYLOAD_P10 =
	"5ha8qKI2Bb0HeqCfo0jIblqXkyx7tZelTkugnBLI+3vU/xrpVLOZ4ZpUOAWHnjdKgNp5mtuiJK9hEC2VfHLRjTs3gR8pN3r2EoXO" ..
	"K4QzbaRdemCLJ0RJV+qok/XSSpgv4mtz4iEfOGhSvsHzkdaa/teZI/zbnV7g1yyyGQaTih52FfJEA6+vm4SQezD1ZIRRYlFRNot9" ..
	"lRab/8TQbps2GgkfRncCT9tTW8fca3bsKZwzmPumgEmbSs7Z9aqF96wVoSxQ809RERqzTay1i2LStIwUlX0ApB4dwgcXRDcg/4G+" ..
	"6gWI3wlEW1cvq+ieu66yis/At5+KteLyudqXjP3q9lSVP0ldBV/yYgn5Bw5sT/hNLvzSmOFXQvEhdHzQJHkOxqPS2WqIhN9LEreK" ..
	"PASFfi+SVznK8CSGNOvJjTy6B+6q1FuTW5/RU2IfPMXrNPTuyYI0XH72DcsWkCOLJxz4OYL5PaltgZaYQyOTE1uVTKGz9J+niyxQ" ..
	"zUiWYgbeRP4GWlRZqvRF2U8EOC7K+0e2EXZf1fBB8ou+cXgz6QGNlpLyboQNCy9J0+fC2u1OqFqrdTYtLYqvmYJNin/z+sRebCD0" ..
	"+/kJ57F8vDKSGyk7vh3oVVDbzSulipFfFso3vmr3mMaoGnChvalvKETVXp6VvNMGRRnIEvks7yT0/kDCT0aSLJWgobl/6+DKd5ZV" ..
	"yXaoeQrhyOIu+RjhwRSOrJ45Sx9oFTPP8tD0dOA/36zwxxhfp+K3SeGAAsgFQdfdm8MGFQPvy0hA42j2WwRpDZkm0KMRTIL8JAWZ" ..
	"3vYM7YKlSO8hqhQ8EDqlHx80g+1o3qXU9dzanVoRtFqqoNF5pgbsoSaBEYD/qkPMJuibA1a0tFNPoQyN+TYXIvJ4n1KUsy6paoct" ..
	"0RI/aOeyo9y5B83Pw1nkv/QpifVs7FCWeLKi9xErP2rxSbkTp6fiFfaD9HkinYZj8w/pDSEy9yb6j3F9I4evnehZ2FjUSjZQm/jY" ..
	"qtkRmA2pHjJvHsKI5W8sKjvFrgkZD1Ktma8vshoCYQiThc1U+L+A7isPJWnKDkDvr7bKgVxRwbbocvI/jip7+VWDfyAabB9mxVL+" ..
	"acDrJZ4oJpA8eDDLBfOYi/pC/mgiBuYoGjsvPyx9Suj/XCVic/GUHQwYec6GWr9IFDw0PDSsONn2dnJ1tkfVyVbI+2j24oGHrAs6" ..
	"Bd3nDhQHdlVDtTBL6LlRrQF6bKLbMptAJRScs+DmVBGwtzU7tXnAWny4SQ3LjmXp1WnspYYYKOlAAnrumgpQAbF0CtdLmFPlHMKI" ..
	"jdZGFtwkb0hu6R3iwvCyxtT2HRatr+Md341EdORZmkDuGAfKdX4lyPjio9danOt0mPISXaW/+czKv6OUi5ObAD0HKjO6OsoeF1Zt" ..
	"WP+QiuzXtyV+erXHFb5J5PMjoYcky2ZVuIFk8PMkc8CJt+p2QKI29qOqJv59I5xtFj6aSK7Dj6y4q+9gwutdb2EG1aghn3PgHNAH" ..
	"C0G568WCmcyYRXPKZwXkaeIwxNKFfD7K1aLLi1BbDJvMj/OnF4GseWKQOS06TXmnh3sNEcRW9+4l/aKWO3JELfub1tmBELnao/rP" ..
	"WWXecU+tifuvZCglSjRBHaSevqxyOiLYJZu3ZpXsNN13SjmWBNUzuOGPYQFIzP0YkxYERb4UC8D/VA142CC/l/ipIMnguIjIBaqb" ..
	"6DV0N2Wxv3FNCfZrjXZkANIwip99lInMzxC5RF1Cps2UNKAiwi4bg7bqTnG0LXctEiz68LxWcYv1xYbTwA90pb8fuwpXJLtdBJ5M" ..
	"TWcOBKn1YMSJ6a+uIcS/Im01Cx6PIYcpVw7HLfUNIIjOZieONj8Tl43vw03NkT02x0egSfUP37JF/+nAN0gEa/XsegNx7ipttSZS" ..
	"noFgxIzA/tX552gl7MER8tP7JyiAAK5TFot6ANWwJwj6X4KcO7uttfJlr6vT+YFPGTD9FbNx921jgsUOyqI0b9q7m8efj6lkwFRQ" ..
	"zVZFSz3/sqoiHU1WJ4B3w6RiohOoY8HNDIQlcUSx7JbkHh9ryJG/wS/1uCeSuejpkV5/1iVt1H3H9T5PNX1AIRwbyDWwfKYutNeu" ..
	"r/RmAGLAm4Pmm1WS+ae8OvPZHWX7knF+LstFC2nkbw4XglbiUwndMMPdDfrVaZ6sH6oAMhaRaR5GzGXwwKHHmh4zbrse/THy+r3C" ..
	"xqAK5xReIb94FJv+qjoVNSGgEPiv9cOW19rOq2pyEXrNtX1md4hC3VFf8qOMFV8Gzm4PJmRIjbxJCwVsF00S8Kd7eTsSofJwwmxl" ..
	"gb2PmotiPBk+VJtKLb9lsxnsVhTxoKo1fZzBJDYZbs9j5PTQDjmL/UpM5rBv6bmkNzxuin+BtN0bIxSRJfAISqGTNCkroOrjxnxL" ..
	"uL0zlYWwT1ZSo6iKNo+7EFC6xCaEfs1Pz3ri+7QGNRtv4i6oWtB8LxcpLZRPhfmKIkYj/V1HfURculGTCjDfbuHRUrGfisDqgr8N" ..
	"dwZjUU9k+iIMSgCEo7eKFkNL1wGVYpIdJ7vieVkud3Us/f4fOVu1HhxevUgoIHMfSd3pHjA6MH6+g9IEx6dePKzAYKIgymsO3bi+" ..
	"LOfM5polohKcOH2dvRY3hOLgUtZid8rjNd5dpck3hPVtkCvcnP9enJbUrzrHyYSInFEHTZl9oX3yfrZwkfifxnHpRUmQct6nTJe4" ..
	"EnxfBTAkZbfPVgbrE+CBMkZK4qqbOWptZN458VHvzfZCSBtFY8qgDOIaZD2Lg29qB4sbmYkMwPY9rJO+gUeuuFLhS4LMvsgoE5Ie" ..
	"wBo5fDhYS1K9JxD4srSSdB8iQ+TTp/oD+i/9MTKLCeqOzpQzw3eip8e6M+9ZnRCY6pogdRcV86QozyfKNxAkxqA1G4hm1bzT0f0w" ..
	"or7XLpBGUb4LEUe+hsKLEjiZoHbFBtrgrN77D47K/9KsgG5UrWYDfH/u14iB5M0p8eFcjDgcotqV/esq8Qg4I/x3c+DupDMiLZUm" ..
	"5Swo8bO76im3FTtjKehGOFKv73cUxqSVZLNTlhfuLR2m8E70GC9gtK9gsfNgK9bBK9Twx9G/fSR78hG1hgjuMURfXwh4qLney0iL" ..
	"s3BuRlJA/t+PsnSTEVHS9KJAWJNdEmHG/mo1lIYMLC1z4h51Js3UVn2EV9bEZUsriTz97wYdgvs7odE/qyJxTev0eKYw1+d9m25O" ..
	"3tjkH1Y+TByZ1OyNHKu1mH/DgWZ5jlTGMeyENS72DNGo9lzwI+CPN4IADL/1CtFa9jVngiQhJBISPsckB5/nNh6xdlno17ROF+RZ" ..
	"DIzkhUqBIjbVsjPmlD2q/NQ6jkM5kMfur0N6mBje0N/MJeYSjnxm9FhNBeEdVzN/O9w5xem4xDAmWAUYy+vpYLrZtwQm/ITLk60Q" ..
	"dHcPBTu5JWU9MUO8e7o1+kAE1oY8E16EsaGZFBEbFbYxp59cBVy2rLKyOxUEU//dL3i2cZ15IlPA/WcaMIh0EbG4LMoxYDSUJqg8" ..
	"3LI8aJohpD+IWfg0Sm0F6R3vmUqIhTb8yfq4JSlxS9SR5y/8BLtAZ1C/OlOQPH88y5lrF3Et78RozuEnv3ORV+zsIhvvpCi/fLwk" ..
	"SNOOSh+TGK9eKRZMhFUBxEp0sZwT9ClnM0PX0HfnSKFobvnzqvmpZ4e4QcOCPRsO4uUzQ3qFHOZm53DrnJBj/SIxwhp6dxuE74Y4" ..
	"Pc8liNtvCQek5a7184m1oMJgWX74Fn6ttAlUzeXJP/BZiNhXsK5rrmaD06WJNVFVdYQERlbrYdGaQr9sQTJT84VshHOjz8RO+zKK" ..
	"jb2sWbo0uv+D2J9bXXq1uciqcrkZEWbi1sxUOnhsHFj9clMEDMusRtg0yJ29bZyXr5h677XDIUeiZX6FkO7n5A919YFVOcTpUxOD" ..
	"7Wg2wNivl6HOJt+BW38BNtN14r5UgVKMi6Yrde+niW3xIGGPTFP9Yq1zNTycDYRYHBSGmVjxWn1Aa9wqG2BzIyu2kimkhUo+vhjm" ..
	"nvbrhR4zB0Q0aGKS1sX8bBtxkuogy7PwGaSQaE8SLdW8vG1f9vCe3brIienoyAGnKrrSETvOp6+wXY4PixbnBcBPBGFeWsMeu8xM" ..
	"BEo9Qc8RbO1WAY8tpp/0qK2eIGmtmraop3+urHRdHevVpD6q0VJVIRq29P7eTaLxVtofaW4fcCxuxgBK/QMOutqlQBXUro0dHPlp" ..
	"RiIBwSb5f5lbusLJVK70zb8uG4Mh8FwCeXrAlJ+RQaj3cT/EcJkIuMVP8R80HFaSPJvPwh0IQLtQCvrLnbeUEZO6bXxPPRVToUB7" ..
	"I7QUldpLM1EZ0PVOsbSbRJm9B5Hu3SRwk17HftMtdz0gJbiyVIHWJzZijB3oIKYwFR8ApGtkjSUtdEGQ+mYls4aIoYjoMbLrdsU6" ..
	"dMYlkIkdX9aNmvIH3ljCbm6Tj3F5cazP9YshBB1ApW1JoatpEWRF4rV0sweoCgTbpCvQ9PgKWYwpwgwsuUQH8WbWZJm7mBF1LOZL" ..
	"TQZfcUK80khsfLJUekB9pj6XY+pXz0ou6ncaDhw6RbAZ37zK2yD92WKPHojXsEiLqfG6pk94jcStR9hNHXnl7FKHyuZ5qw1lDeOG" ..
	"yy/UxiNgy/11ny4fjNlFNI7hmGHu2i2XgukrATg95w64kxD5OE7BbdjrDIpYfPVav8krW8Ip1RcbHEc2aDPU4ld4UfXiQTFwbG+j" ..
	"yxCjaqM5TQ6TKyzbaAMADRl8sIq4WUy8IJPZmgQ2tIIS2leX2VW8/Om24iRss79DRX7Hjc7jfoPI613WgRJHoYTL1fb6Xo/cOHK9" ..
	"qT4Xh7R+loNXhLov8k7qStml16W19RFfZmaNVUD75UFvAwjkj0ySVxPVHQ2KwIyJyaW0ztYjRcFXVgp6T4zTwL8f5JvQ2a726VF5" ..
	"pCrzaDm0bRcMfyUT+lUQAMIXQ29FJWNkteozyYYaaLNZS3J0vLxId77MXV+JprK5SIoG6fJ5McQ0MHPyWT7SEtI/MXlJoqb1uOG0" ..
	"0u2s/Nr+Y1PlYrV9KVE/N6nSjfrUjFV9IaT7e334zk3UcW6eFcdhnACC3X514i0rB2NUTD/AyTnD8Asj4yWG1FN1GT7kYd1e+iEt" ..
	"LeNv/pSRlTZ1FVL/oFxIEEdwJUsXPPo/N6LGOHaSXdW0SuFdGUEJhaEyfqt9JFf/DN/3veL5gIjkNG3v/PQM6fAlxXbcCI8KvIQ2" ..
	"I+t+AqXGZP01dxDJZOKAgJXan4jVwIWdtEokhCVIRCO0Qpo8vxWZTBJFAGhpWaFBybS+VIdbbqQCA0NyRu5kwD3d3n/03KSicLXq" ..
	"HCyf91V4mWpn7vkvMGpD81gvfhEwAalqVS4MLgHMKNPE7WyfCed0ijvl0ZVuQPCuhlu8uL1FyAe+sz8TJeSQr4qIm310OB6nIkhQ" ..
	"pDyw8qre+LFakIQ68DAIC8K/laNzxTlE2b8vtIDyOB67o8lPnBRWJgRNxfyLwVGlJlvvHA8+6ydNAofgVRfyEC6ib9WJK5Kxd8Hd" ..
	"DBW79bM4/yrPQG5+OOXU1EBUW/Z5k9eb6v56KOygxJl2QUbYGVJxFtP7Nolv/wIXLTjIcCYJzRRJc+g0TVvJoHzdOUzJug9FIxjf" ..
	"JEtt6ytwmAII9iqNoAdx8IsFQN3U/hxxIgFMMLNFYCBnj+/BZKX1x+WKh6vKWNrToy3pHXSZiu6KpbeKaCqahXM1y1jBCqZorCql" ..
	"gZmYZzKHN6Lca5NTH4I11FKB6NJGT7wKad8m/hM8CunRmJTMfBbm1qG0jnPncKjvCn79uQnqDTN4eY7XAyjooF/2ZPY9rks9BjGv" ..
	"q1GpRpjBBN/2g6I6vuUyyjc95Aqln1xWV+XcI4qhCjlgd1OhNhg4O804fOblfzhVA3QvlOLQgGRseLGfcwN8jfgKZJCyze9EMQqJ" ..
	"6mubfh318B5F6VpAtlR1t5NG53RtHcfFS3bLylGbHzeWY06x2TZTCYPXpO5P7AWjNe+yJJVjRPRlN1ZU/iXLlXN5+n3Q9oE5bHMT" ..
	""
local PAYLOAD_P11 =
	"V/zEkGSy0kqYOcJIBAu8rrCNgODLx7j6+4C1VJiU8B8zgcZICK5hqr8eNr9WTLCfmNCVFq4JZp33fZ12QqV8s/U0yt2X3qVcemEd" ..
	"jcPVB497eY4A2Ll31/aPniHdkbnJ17HP1F8uikX3KWtMCx5+KpFeTNiKyYJ50VHDOxc+Qp/JsZS31UiYami2sLmsXQjXuhK4ryRp" ..
	"lir/iNdFyMhz/SBcVVzzrm6Qmlbg4kEFUS0m0c4HTZBiUDJC4E31SXjv2GdrgAH7UnEW09BtqsU0xYx+FQJoJ5rzDlW2JzFpXy2X" ..
	"UZqZHBldO4A4DiabTn9OKdERSip5Im+vlNDwXL1ta2kAxUoTx9QEWUESXC9meJumzjo96X/UlCxYSKfTsuJaG0Y7bEsm12w9ELj8" ..
	"5jtQ+96jcUDZYy8P6J3AikiFtZkzK21Hma4D761ufjpGnZqqM62+7l+p9bkxKfKkurlzVSdyfMuGP8+E18MPFq6ez5CdTHItrmQ1" ..
	"TZDfZG241k/wpV6hjSk9D0+vrRQ2E/0sS9Y9lCxGwgM//pqBh3QIqsg75HWcwsvY2iZNEzuG0YVHczn4bsu7Pb/4HftetbVacqjK" ..
	"voUOM+NVy2qhvumH09nmOCj/m55FJ7bnxO1rJut1ue6bmgXkz//a5oU5ucFXFp9oM0P+u/rM+aSrsrwagZXVv/Y6odD4MczYdbFq" ..
	"8/2U0X//Yfa0QeW6kHAEUjMfWD8iwCeI6OneKeXWpXNyCvG0mmdvGn4kERjho8je6PzBAXN4MbcIsWcjmysurTriaOeLgEtSxDkM" ..
	"WHcdZBa3crke4pD27uCOEO+OxplT/Spg/sV6Ju6I3uxHR41J7R8p/eQTtJZpBMYcPkBMg2xHmU3ST9L08eUKSlVPn3P76T5gkc5r" ..
	"bzwoVfZFo8feFd+M3LUbtUwaIWXtveEYIhXQ+d57PPstrIVrnvTOWYijQeCvGCtmmFCxl6IAeVPwkzzBZmWukgtflUoUXKbrAdPy" ..
	"XR/eZvWgv0fzaux/FDtmxOorFPlcJ3lQq/aiwyFhgie+DtxIb3xHV4d2Q9X5/JfATHbIJ85xYfZ/ggqiHbooV8iEVU4CzlkYsznY" ..
	"YgU48UfdLHTosYLmdec3lURMtjbg9XF7WBmd1iolHx3hevO1Ldv6AhO+LwbPoswqQSHDbXutE1D1cHE9+KhguBF0icciRkZOZY8s" ..
	"LOFO01xhKqZshYlr68ENYnhN7MhgDxn9VrQCHxMgmGA1YeLaKkzSw3E62sT5WedTjgXDd80nrDrj+aRqo0sRLLW1wkJQTanDa7FL" ..
	"2aEAMH/j8MJ3N8Spq1jGDpUrXKgtpmThE23tGV5fjWFK9jUvDsDXGvQS7pE/3/elg5unHdKeAAIfillgn9bvR4d2zlPgGA567943" ..
	"IESVclCIzqmBm8f+sM7zOKKqR+olRGXPYtNXHwCQ7O2QaLkhkR1LCWck7v3XHw2NIF9YZjGsH3F9eEl+enIb256zjwmPjIKHRK4m" ..
	"wZQZHwTxIEV7hYkjCT6VJtUyCVRPhrLYKM4vLsIYI9sE0yZmt9ijzZS0+eGrVMn0u9WWYoLnRQ3icB1ZWWiaTTAvSaT96xsGk4Q5" ..
	"EQ/FiyCGGP3L7U1NgR6r0/IxXH1yyk301DiqkZx94FwKXr5y48zmm0QByvT9NmFBtwwoDJuQYxzJhaWLEn2JpPyX3UqWRkj36HHn" ..
	"+zlQp6vT7mN9h90Kaj8QHJ2wu1xZSqmn8oihC4lQMu/sYmHfxEXaSzIsZ7+Dn70yC8Pr0fTsXTOq1CpYwQ0OvdYrr86PxspJT3rS" ..
	"5QTC0ocClBXFzCgIi4cNTbhzVtYt119qOiErvNJuS2N6wkRxjdRVMCVfcHRh5cSoWYiWZ1Se9DzP44PqFHWdhQREM2tFR1B6wL3K" ..
	"kT6O4sBQFAo7ojhszeTb7n/F36++ErVOd9HQWKHUHLRsmZXBYRLZyukF2pBtt3OnI0CMZwDqy+VyXxM9Jn9fVz+MbYxc8E592r/E" ..
	"1/PZhzle7E67I/cVgxt2pjo01ioBvGZDBrFJbsAcP+a3nal3dPSSiI+3XGVetObMnZN9Qjq4SNiw1GJaWcSp3efuDeiFizNDWhsq" ..
	"IX6q1+JJzDJ7+2a8Ii511bmU0/pCsT7FceCzH929aQbm6J03ILxVnyn+wNR6rS8f2mOhzV12Htlubq//iVmB7nY75byQ4bJycMuH" ..
	"1MqPtjHdbHdDDNblh5Gt0XBdTf2rE2Jr9nIVrbad30LHrGQ6exjqeTFeokRCmXtyVQarV8ltTkcuZxVysK3E6EwShUCDsUEaE0HM" ..
	"l2jAs1GXeMR2CvJ0bi1QlbJs3v8Z53F5NeoJgqBi9MydsAfYproyUYzVYte6kL/dCMDcuDi8hS1ZrfE5yJcePSZ4cY+O5JguLhR4" ..
	"RII+Q7G7PJAuhD96Tj0xDmIZu60CeGpxaDg8Qsm4BZz9M6EroCY5OCVhU1wlqcB5hQu1UFGhnRD0d4ABzUo9x0JYfWk6J83aaX0D" ..
	"724172vh7HSR7aKoOTQ9sBXB93lVNxj9aMliDHtgjGFF+SKODSMM52JFXoutAfJndKqZVPm1nTMSu50dZ3ecrZAjb9qnpDTbu18b" ..
	"5MSpFdmKCAGoGcOGWuVQBMqrbXrUO3Wv4jGvtFeT+iyTd398752zs1cO1zuNJk94WQcfkeeUTYZ1ycUSr100pLqFIyV8KaalF+f6" ..
	"CgKrdYyplwh2hZi75STTrBtdacjL+jd1DFO9zqjy0+eN7+0fGnrBZ7bPzWDeJDeuWuZfUMell4Zi7U5oiLBiRYN2mcyNAuYInYVg" ..
	"M2gx2aCp82N421DnL2FSbuJP1xud5gQTk2OtYvxieVG9RUY7/13zilyU3Ml6VozyIGkYeE7DJ1N2k4tUcbrb2C01YAPcUtxQk2Ph" ..
	"Czr33Eumh6ujlVUXHXDCftoQPNdTTokwjc5lMr7ju7l7wGqpSZqbzP50GbB4cZxVDDbjfRB8lSxRYqFdDF2+fM1KbT046TE+yyiC" ..
	"INLnN8OtiimTfi5VgBjEEBM2R2xCM9aTPBUMzGrO+hPRvUFz+D8LTbfRBpE2Fp9oXSJvDGpzIAs9APyI9V9DJUT8xkf8z4BDpQhP" ..
	"B1t6R8oajCmuOwYJPfnAW9btOMgF5TYjsVsU/w2dwbSTeQR2Ae4EkohvlhPCtAWmTmKiPWNxpzoIZs+TAytpiYqWRcxN1xu/WDXB" ..
	"tqg8djWs8sTZURw35JKAzMCFSA4BWg/kSRmpGrJideSeXhKbNm39rVJsiZZAGAq/obo/nDwPhfB2ErHxATiKL7sEEAE19qD9wba3" ..
	"4DP8St0eYvm6fLL8K9rLl8OyGQqM75LUgTTaw7o1mpF2zddn872kmWjEwYwGffr4dCqHpcVcoElWe5S+6OVQTcNMwQbKv87qZ+Kj" ..
	"GqN7NuR/L6OgXXLznZIOuy6dpQawKgwcc+MWVp2cTSdN1lpkWPMiMdIB/zp7rHTOwVLU5hIgdUXjE6G8TWjJbPtV9W6EGAXD7RgS" ..
	"rsHAqOJ7CEnuLqdaBePRr4TqlAoJju79mYHzfkVbFZG7/X0xDPMjr2FuPjCFN9SBP6CQ1KRxXCZ9uh7WUKt2qIZRpS3Nb9/TzhcW" ..
	"/lYvIYEoUktQrkWEDTPw2kK6qOkkr8KPalqLFEwNK5VCZK2tuG24bPf2MtrUpcv4CqFeA1+Az2GZZU2rmWBRieKqR9NcNIFVdMh3" ..
	"X4LD1sywVphv3Ck/ZzlERfdCyuWlFHMj3OCA9L/ocD4w3ScWDNuc7cChqew50l6tVJ2iey86/Z0XehtMjALq0ul2qOKlT5kasiBV" ..
	"MQGSGCAzTr/KbfGIP4xOQnTLyJfQwG7qvY+Lwa5Oo1GEHVNODtKgCdrTwhUMahMTwwtPKkPI183FhDNuPxdx0i409fMyvc/DUriw" ..
	"MTiSTSvfEsroTGkRuEsD3n2VMOF+jlXLAcNWvdDGWMX5IpugmCh10sMDQ22pg2IkWmaij7CIVQvshKRW8ix8ZZa8/iSM7i6+Vm49" ..
	"oXtWjm3oq4h+1sCX+GHS39581ekHS99TDqBR+W+QztAfG4RWHWTC55PMlp5rALhlVP7Knn4njs/mVAR5UxG0fJkvPVAiX+vCnadO" ..
	"YttCqLFPP9hcIpFUOFomCy8yrI2932MhVlmkYxve1otls+wD7Kq9izFpio639+h+Z2Flp4JhZWkNSa1jQ8pBXBncZR99dyu5qlHo" ..
	"TUvIZ0OwwDco89/4oy8ZvR0bkGj+pbHK+Z8BGnQY23ReZHcjjeY3XLdCT1MrECW+o4BQSOomReZSYSqwSY7jooeOjMF9+CtS4o6T" ..
	"bW9bPbPsudJ1pzyEhhUxkCQtHq6ba8ne6yf7cI2LQmrTjsEGvEHk8t/hZ27LUMzdBkM8C2SrQ5F9xqEuXuVWeDYhdh8VR8o0Fcs3" ..
	"9QJj9MKiz/gsQ71Y1pL27F13gjpeOKgn6gAT2UZtiyTpz6n/R1D73if7n4FIPWroeMUwmVRlyB9PedisIKzURklXbuBj+pAWs61y" ..
	"Zoags5nfdpmkkmJJeN+v83r8GJxA5aolS+LrkHfNtkxpMTm4Blye1FxD1MvgqNm4CX5iE6+3ZfmXgao+kOms2fX/YywVjYH5C8Wx" ..
	"3AUyd/+lCXQmsl7+GVO20dhomXcm/6Yh8Mp/dSiyvdMM+ni4DXstv1QPT/84IuuZ6GOjz+sxKQKC2BEVesg/SqmmMSxfNzF+0yyv" ..
	"myLF6tWx+CYa033UteJ9DzPvcHFe5RTcqNAZLY5DXyOgltu+Q+cBljcQ2K0E8QQLlTp0TRNUsw+L7VNa2cPe2tFfKUkAdWIJ4+/i" ..
	"KZRjWgA2k8CtzZroEhbY4o3R/MLqxiQMopvU1xMHZmqqZtTM3CKUOJzTY1KJjtAPUXYQ/q/iY5T1iOYKWhODevVqTAAihyBqJIb3" ..
	"AYDIN4GAtZyqP8hfhqSaZ84nbrtOXpSIQRtS1rFVuBN0sdCxv4qA4hESKV/BVNfKSikGFyJJcK4wFzoGqGdMB9CV8IeUpJtXAuWe" ..
	"YV1+lVHbqxnFUNPHA37XFzi83Svp9ThO0HLT75xS4qsqNYwnTTdonnQCD+JMypA+v1tR8T1ZS97mUFMbZMr3/FbhkjBZxiM5jlQn" ..
	"a08pCIx2JY68VyWJBffVWDyKqADB37dtnvPllAnrhE/Ev3oJmttgFTkgyDJyO+aEdMz2Gx6aQ3gR1noPyKqzYSaoMtPKtqOYoNTb" ..
	"+IWQiKs7/cpYtLJaEL0SRBdz4mu3erDnPSnRFC9ezBufWkk0GDs0KJa5XEUdeJwBZr8bxgzNmCQuVeBDHEekOlL9mDzbFEagodFl" ..
	"lBXK5IWBRotqkRoavTE5vv1I7NB6rj9TYkPuwbdJbiluYgPvUamyMvkAQwiy+kTvqmGdqdWGoCOYr27Gp0Io+2jRKqzcb3wytqrt" ..
	"IXS+1FbMoSwnUNO6/OFg0mkcXW03TvwJi8KyVzM4+HWGl8xSrjgLvs1YrWppCQgj7JVcQ2aSkjlfSYvz+gMHsa+RsN5tfmMCsRhA" ..
	"0qGqZtPJu0yYQeKJ51+cLwSRJ3zPrq66BRdfRM6rxBRbUweThjwubRDz+Jb8EqyfGj81SlcCkKZuNVVW9WIiivv286NzTqVFeXyY" ..
	"ZQYTS+ylb39ps48ZcM++rxjkNxOKv1IaHzUcn2TCDAtCQcUHd/FqindXlr2383NOXYeplucjCdqwFZA/I7IFOVjoeiJProwya4sn" ..
	"qcytFLNTpIZyPjX47OH7MO/iwJhgjiRp8DSYVKnhlFqaF3q9acpZgVWcUbG8jSh64CAQ6uMiOhCMVsvaqhlttSk3SnT41Ezi0BKI" ..
	"aZNhzxjAQJLLnZjnqNkL5UvDjcsZzX8LvyR78eMrYwCR4MJnMj/YpYKgzUS4uqsdFHjQ4vQE7m2Eg0dP0RfnC6o/dCgAWTPlj/pA" ..
	"srb6ytVegzhxxDHuHjEGMy1s37/1ycGeB1VU2WMkri7CRg8F/YzQ0PLge+ZU1PIwQq+Iay5r4ZZ4iBW8peJ1dwryu/EMOhJq8g15" ..
	""
local PAYLOAD_P12 =
	"s1MH2BmKEyH6KqUsOXXCbxWfr2JNwCsLReoYdjyNSaeA44ZcfNcKTYQLfqJsMxB6YYYPqn/7japTmMMhkoY6LuisWAvYzFOaWzCl" ..
	"SXjPXurTu05N1rKcXft9YWHwAffbebvSO3KHzZ3Su1Y86UnANTb85fdS4W2r8lFAabfyden1lHCW8vzAVm4KutOzgxCjylh/KxXd" ..
	"J3WcgUnG8vfWFxCv7l4GfYnoQRYbuAkNI72KPJIRbpXCpzYkDDvSXoAGec5afhCoUKjc6qeBVSalLbV0QawrfEIrEbNx4WCyUs3k" ..
	"kUjW7fUpMbCgkaDTmCC3isY6Lt4Drnu8QbWzqrv9KSofBk++ubw7kdPFd/8F9T5BXrBEWy0IbmgYiSZvx/mir3vcpdiZ+PxNuVeQ" ..
	"qBldO0ko+dcPOA+ZFJpfreVsGAiPpHK7p5HDOnCKPUc4bAdY4Bsr9iKbBEfZVA5uybni2T5/srbRQAf7+7raf4ohbuA8SnRJUjqk" ..
	"hmMcxnT14Gmm9hl0h2CrziWpTvBuHNFZ6TS9W9SmdC28Q7HuUKc3w3DkCo9fsgsHbCaTsOarS5WeU+OkRUZa4CvwU+kFRnWpL+Fx" ..
	"GVnjaHTU+6ZiOyozZq3w9QFEIs/N6gcPxSzOq0emiNJ/wTqUOBfhAVsHMLGkejzxHWWjwuGcFTZ/lLcHcJjjKHYeBfFLtZj/57I5" ..
	"NAxB4dktSf0Np9tBpxN0NvucAAeumO9zOZ0JDFrTf9QkEMi22vQcw2dX4adI+uebKwsM8Aa343BzDoij7MHmZsLOrIVZDzPjeke5" ..
	"Y3QTCwmRf4wKqCzaFetETu+co8N+NF4msBvXjIN93UqNaWVkEziMjtkO4d529H2IJ6viaUJOver2nTcVS9RPXYX18PbEpPy9AKkX" ..
	"0XXtXRaLY/eo+fp6rYPEtInIIhcaqOmiwlABRtzt1lVMErSFEuuR7anQCzVSzwq1aWyJUX+MJC5bJqPQ5r6SStFTlzq5RvVM8S5I" ..
	"ocYwVvHwy+7Ey3VdG3owfrpcQENZrO6wIPDT83jVudcHt/k8so46wbddSZjbUvw7gQD5plNI6jDvdctYgUT4oOMHTTLcyuIulZEK" ..
	"X0gdLnEPfyMSn5aEjkliam0Szig47cOolCQ/EBoDnJGSGFzpEjpOsC2TKARuWw/IOTKzLW5reolS+v5Tp9Qk0ko0GUIUJrT7laVJ" ..
	"KW9Dx8X/U+7VWN86Wf6tmHhtPAW6G8YInyCYXIyGIH5bghWTDaCN/2ULGCF8ytck9qd5gtl0hQ7Vs04zEXaGjLp7osKK03wWOQoE" ..
	"Va+fYVbqk4mtaLUHjE3dPzqjxCS/xFEIJcEQc4anCwkoVpPVZBKkKRLzZ8JTZjE5vkuVRnxHkXXYpZ1OGCQbN5qvFdR5o1P9kzqs" ..
	"YgL11UJtFqvRl3WiSIgqPmJn/Tm6lp88wBcOMxIr6JhVlhzDLvdk0z/WWifZoW1qxp1jJH+F58AW+oqAC2JP/Z6NBAVcwXddlTcA" ..
	"kH7VENEwNA91fewfVX4M/vD/jnKb5hl8r2/DpP7kCqXph1LE+OrRdvtUohjvBJKLp8yjRqxX8E1l8emO7oK4kEKszaDpyHUeBhLQ" ..
	"XjXtsW10p/yJFZ35poL6hSsrz9XRj61G5sdMo9Uv+3R/qX5O5AM17emtNgXsa791/rxAPGfDUs5Rke9GCIbSg+mRjI0P4Tx7q6yl" ..
	"+nm5GOBuZQyGi1dsDRCPZJZaQzBbvpL/on7jdfeyz1gdiWy1uuZGBJ7M1nvwEjHaxsf+yVfT/4Nd7yObYoAlYU9KqXMqyybgrEpd" ..
	"sfYt0F2YQwRnkAyzE/iVBBLG64KjGV5fTYiaX2osB//mWl+PPMWviD6MuOUkTZRdd8Bno6vYAWbRDQmDj8ucXmOAjXUSTtuJsFL6" ..
	"QsNDQljnmqELqTRYkdSYZ6TYT6L3mv3GPed1vtp3KNJVIk4F56zwASPT/M4MOpMXYmoTKWsmYHUT58Hp9vfx16TmoavKtRZdQVL7" ..
	"fqftdd9pyw9eptP6nrN8KqHJknq92RgBY+yK5GYATg5FR1IePRH8aWZrWqXvYPezftPKQuLBnPS1VZQmco1nSPz1Sz6TsxQ2KhtO" ..
	"BY66c8o6M27jM32XuxRxs5mo18Hfz0yX9pn+4s8N3hpFuaqrzvnMoc1siIqwTBNyaW/wUgWmkrxQu6Gu5ZGbiKpNDy+OBeiDX+GB" ..
	"YLpHm/zdGXuq3GLsn2NCOULoIYDXr+DO1cTMkR4niGq/rxDpsYELPs5SnL+8JafskOC2LtWoQ9kpRQISlkCyp+mmpb6FvoDUqLqv" ..
	"nf9pglFbqExIHampk3x2iUH8S7u6RZW86ZpduPzohENRSkiZZt8Dt7OySs1W4rmbzAOsDfZ5x25iKusPsq9dkowmy8ikQ/AjY1gJ" ..
	"xL9FO1VhrLUaE/vhv/sqlSJbpRycpOIbeUP9cjqehttIRGijnWk+l6uhQhfhHHwWpjhPxoSgUWhoSYhnlyxV+yG67fDhhl/Y7K8P" ..
	"NvL+DdnUY9swRBHwNu9R5I1VooEZ9Hw9EYgqi+/sDI5MoctPT29swmbOiZo8sb7eoBsNFyjsMQ4hW4hTGPJTI35yPUXM5/DmnRrS" ..
	"la+YWRyZE1niRnEo2Cxwp7rEkEvdHyqsaf/sgicfqfHT1kLdnqLUTGYpqYTRf7EoEhCGJe5YyBfIIIq0qTOWG5PRuScwfGCcdygA" ..
	"1zNmkDMfQIn69JqKMoCQOWVPL2jqTCebaSWFhmQ9OCkyKKbAOPYYk+7Z5A/WjCz9RlstJ72ihOyO6SrhQ9umk+1XxIyj7GRPSaGK" ..
	"QMuWD212WNHsSxBwwRf/YVFDXK97s568q5kGbwZ+/UlYzmLkIV4Tm/wl12kPW2tGT3dZ57zMXKGuCYGusgI++qohry1JgFW5cY61" ..
	"fSPMSFWhCBNYfNX2WILKqpkbYOQUNVR+Bbd9JfDXYii/SP9SI+0HDPR5mx5cuTnuMY1zbKhSb7K6EVfR/PIJDX0ZfHa1UW/c3bK0" ..
	"b+ALRnr3F6YXC3ygcDKVCwujyJAhy3Hjhub2WW+4UAjaalIKIPEIvHrouIUeuA/fG2Uy6+C5KzHJ3a23BoT1DAhwE7YGhyVn0vaU" ..
	"AoFCgCZ6zTI81csEdYLFEPsU/IfG3O4xoDf3HhsE+9PzB8a4iA23OaDgIPM/kQaI6bZU17/1bZc/7jjeeSDSswKJiUMc27HemIQP" ..
	"a6TVot/3YL0K/f+nBPkfT2EHM6VM3CEQ9ZqbUSiz06id3CtE/mM/TPzw98qfcSDylHYh1jZoYoeiEqLNG+4xeGLH5CuVpCxluLVZ" ..
	"goUmHGfjvoFbESuSzdQdixShOKzimSW32+V6Pe5NmfHdJAlmEZwVTyzWHje4MIiCHYD5Y/epbt9zd+NVtZqXXVovQYOW/QuufAri" ..
	"LwhYXxNsQ8cAF2GIaohpYEmfqmUyyzn1HaCwzi6JE2iovGpIkFGWCFb3qgu2YhKj1TQfRl5EvvS4rI1rwdVq7kmvoqg23dZGK87x" ..
	"osby2B8TtrdQ+CasDzx4u29FSWiCQo/D5xZ3feAw91L0ojO2+sOdMoZik5HRMt0RpQld33d0GF+MqYbKRQarbTy2DUAWDohWMjbA" ..
	"xlxjL3IgcDvR6TP4Ci5TtieortvzQlKzoJPhcXWCX8NZxhap/FPRfV4T2/TPze0XR/1o0SUo02QFxfOJDqLBO3AtvPquDc70znhA" ..
	"F9kqLbURD/2z1ZUMNXC69xw/FtkIVHrysI1mzHutNvV3yaTnKqaKekl694sUjfhiZF8WQ50kHgUs9yPbJ4i0mZyvw3LahSnBWb5A" ..
	"yiXOgRjMnhFgePMNnUjR5qiCoFRX5nQvc54/73BFIpWnyA3pEbkpay7+1gDcebziP+oA8fm/G7xanTOehdgAeiwSpK3af7tb+noT" ..
	"q3tQ+SB3WlKTLjBKzTvZUI87tCfZ2fj9za6iRzhUhLjK/A2UQKLCMuct0udkv/egACyKdszFgK0Dfiqzj3LrmIjgc7zPEedF/RK/" ..
	"MqNCBik0AXLaDeJaDS1VB+ui2mTEw4XaOpg3JOzhJ8Hom9IxHyQi0zbJqJ8mYAmPJOZf7Zks0m+KDjYuCT0oISXYS8UGpPKfZaS3" ..
	"o4HR1EYXfTfxWvtzIs4iU0KZxFEkuta8oeTKMfPjA9cK+wTwBrvmqH8qOyM2jmaTYee1fR46+SuYeyyb7x+f1nHfD6YC+wEsXlHu" ..
	"C47LW8JSYiKDMGTF/nBrGSeM8cAzE+z8TaQT9Y07+bWiSIrjcONGMLvAF8tqfHsDpOGvN/38wFCgltKbaNJ6hgSdJw3u6hmD7zk3" ..
	"x/xISQsta6wnOoqkqqraBt/o4L12Y73/sHO1pcWvWuuQELhOWWZuEG5AIVVLfGCGEopfayOXCieJjsBqVoaRo9xfPDN7XGbGE6w1" ..
	"9pC4AyjTshSVlMKhznzaNl3b1DKcjGt5CEPvOPC7yHUgmB515zGwBZTFOIjbzgyErr+BVnVO6FJBmfY4XrOw3NljERkJTjP3g/ZS" ..
	"IwCdQOu7W/flLOQELXWKSHU/dg97dojJ2ELNX26WC/CftAnCyoBuKyfAr3dFEcRltwBHB0AQa2debVRrW1gtb35Ek0YNvYFe0Jh3" ..
	"dL94cuq1qBcqT8QAQywR1kFjGqV+slynV8rg+2sZt26ByReZjUuO6Ro4a7kkMdIvW86/ABeKpzrdT3aQLAirRe1OBWqtprzdAo0r" ..
	"bc1mHOd3voKdH//u+2wRQd/TwkcbHkcf+bvXebdoCXSiCHNRu+RlIE3u5JpU6nSOwYaMfShUZAqCeiddPM7PewC1ePIm+Uzwg8pK" ..
	"OtGf1BZ+4Vffet+82u6t5hjbbYVT9Pex+W80CCwNuXkcc+Y95dD4RRtY0M08euIpCpQy8Zx2ju9EVSAj3Fa/GcWC0OjAEDUJf/8I" ..
	"NQR/YgaBHupKVz+PTaBAvIKboXTHDXvXoWzYl12nmSddn/3nbl8OB6M/yFFw5Rrb5Yr3sGj/O37ZfcAaQ0nmP/v3DdJIvD64xsWG" ..
	"NUfMgYXWv+q1P9qVqp3pHKDOW2FNHvX9Y42lLsI0zZCWTdHTE52fwTcJYwnatJoTJK6FXzxmtKzJzR6cGSdLKKfmA5pcFE1ybHae" ..
	"vcHPzXFdPQ4vyfn85gh5KzZEWXHdFpvfK+v6W6TuoGnjHrxVVBmsbXIsgyGAsFgbPKRDXfT3o16doS2J2zYO55ElzBMSCeKSmoIe" ..
	"V8Slq25coLtLM04epj84eZKznPEWdRhzkadRDX/S/H9YtX3EBsJzeq1OMQzymYapHZeXlQvxHGGXvw7T3NLVtlWfMStwlRcclJJs" ..
	"b2GjyAXJ96MjE+X1bb+0c1N+5MhM4NyVDEuA4npE/tOSRz6DiqG+CsS0zaL41vrwTCyE3G+bSaHV6HMINc7j8XXDx+z24KksicLY" ..
	"1fJHrLp8/NEb0lCnxw4Iye7Ounrt3xSYVqH38Q6SCL8U/EBd77uPUg1zRVgDz0JCbu0dv0xnMuhqeQ4d1nbTUjZLLI/ApdgVXwWP" ..
	"v6UQKlJkKFSPM4M+nEbAgtIhzTRRWxoXOz73vtNfM3L50N1u4q2BifJt9MUwoAUQ4OGJBMGNk6fu/80QHuJ9tgSH+syWey8G3VaW" ..
	"gd5QvwQK7hZe9tOJrbLwZxgdXCUdMnyEmwJrfKSjrVGK9p240ClzQf6JOKRUFQ4yoE3vxCRbXXns5sZuVMq+GDYGmnvnjdQIJFp+" ..
	"+xHiZMNHj61TiNOndMdWW8glVgOcDrdATBztBuWPfs0IluWiHhPYeV5ZwSY0OaF1LNy8KjnAVMb6EbyAo0ByUx/n+FquR3WkJUVD" ..
	"K6vdJmuO+GjOUBuo+AqhU5Q6tZE60HXmDW4zH2gkexWsv6wHRMVrS7F2AR7SB6twEz8gyuleat9sZTKYrH0QuDzRiv4PlyIY59tZ" ..
	"vj16X8Hx0St1J04Cn/cT/aeMtP2Lz9pg/gyNqtfIyqgyo06uiTpjDnEr" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9 .. PAYLOAD_P10 .. PAYLOAD_P11 .. PAYLOAD_P12

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
