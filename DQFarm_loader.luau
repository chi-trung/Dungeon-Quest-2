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
	{ seed = 4283945420, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 4281315802, exp = 0, plan = 0, hwid = {} },
	{ seed = 4280735167, exp = 1788089514, plan = 1, hwid = {} }
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
	"aYUOAOSrGAyRcJ+HoHzKzvTwZ9IxmXADwDhJnSN/YQsoq10Ig+0JTXpBUZ7CX7PbYfNUgX30tftchAYRw7OEaY3DWaA0vsBh1Jqc" ..
	"n0o/l8IMSMWQLp/48Tiyoo5g6GeOWZBTe5418+BmoFyA3cz1psWdEim/f2g/i/ZwZ9dJslRA5CagVG4A/d14oAugYQXB4I/5fZJx" ..
	"9NFM8KI7MmbjlnYDS6uk7WS+fPi1oxxXPg1prugmfz+S5z0t3+MjQbGzrHD9oFItUf77b3LV1fj3YLOx+cLLCCuDg9zDc4EcDeCz" ..
	"hv8V+7UYu+2hR3pZbvV3KrLvN6OQ3XnEYiZfMz7rrVXQr45eTs2rXyzPius79Oa7xrRj4u4PkrixyN+wPHfewQDBivzTRHzcmC9h" ..
	"NYsodZhLPAiAVnsWQSeHT3j6uN/L5mMjiUXs62kvPViftXUZ8qhe9bH1+OYHmBkFkp4CxOrP3jX/5XGVZYPbO9q0p+MAFlGDLQTc" ..
	"W72wDmOFjBSWzusnUbF4poQIn76WJTK4bIIPADj/IwHBxZrdzobLGDzAeiQLiA0DpPxQlTNkFh02uCz5imrXqlHwjQKifIkWugpa" ..
	"NvIBFd5hrJ49XCsw5/pSsa+fNBUDJEhjL/tzLk9jH8Wo13WwZS5IbDRjq3SSh5aV07sBuTwMFb9/y8Qmn9rVNrM2K6sjL1AuN4p5" ..
	"LUCZMvxb00W6NztVlcuYC7TrGoSrPipf62Q9waVtUIrlsMRvm2w730EHdbz1qeo1sg+fQaiThQNZoq63PuAyyxHYCPbWdFL3Sk0w" ..
	"nEAcLTDCJKEzgeC2wtfa0TBpthRB40DcuKfqDQQC4JwjXzf4Yu+hlH+MJVXF1XLkpsKHwh9YSkdGWQ73hwmrxBezYdEJlz+19bHl" ..
	"q2eDB7qPlI27gV0i/m2Su+PnKRPyxW9PWCO4jUMyEyuQvsk2g8YpNo0Vdz1jcelh4zGOpJEzl6aUhCSLX5QVn+VA9IL+Lp3N94bg" ..
	"y88oPVW1nGTWPyRuhI1wcGeYhz6m9BiSJawBQiL9v7dfesA2ozYWke1kNwQrcMflz6Ghj4GkLpkpQvYmjSNNMqOlZvmQ/Pu7eJ+f" ..
	"wc7NdIK+dFn252VVsbLL8YFqF9n+rBQQjdK0JnOW2R3xsinZ7NfrDYQ+JDm+0w8GvLyWiS+Vz77NYMkdpt1R6TMcDWLfQSQfq9JE" ..
	"8nyWnhilX7sJyeLEm9pr5gaa8TxzpK2XoF7yUUgc40tTg+QamHrg6CoRw//cv8YE2+WF3A/55j1LAXxLOIgnvAqQbxhIO03KaN6G" ..
	"Wf7j2k/8fgiLcPo+sqByz4CJxx6dc1krTOv2+L9hs1Zv5DKtFCItDykkX4izlCgLcDWYjMDVNcC4EYsfdNP+1k7hqTDsv4altTAo" ..
	"aI0rbukk0dXzNvCpT7Aip8VtwNbYMdCIJ5R4UNQMDVQ5D8SwvDXWSU4vNN/6OU6uKabLwjaONVXwhLewvVNRfFZh+1SjM6hiWRp+" ..
	"fmXIDIGD6kg1TPJ3SJxYdOEopc5Gz4wmYkLB3vCF4lr/4TZbMUfttTsePbgYrJeYN1GfWwNJNB25BrXJluCtlWjaoJUAGZ+bJa5H" ..
	"6psdsAG3ld+ZMoky5KDEjlzS8uJQj7PjejVy6/lxGSC1qhAlF1o1YTyIdp/0amtVzvLzAIrWR8bUhAb2mdg8AeORSvLzIzQLiuyn" ..
	"Fh0IZ46HFU2b9Yo7ATuR4pxKifcwHoWoCPN9VoS6etDlAtMnjj3oR+NF5poGUd3DGmUN/jJcnevG8coOObCUYKAHb57LAkZV4G4l" ..
	"LTQsze2O5HpyTEi8VyPwIhFWZLgrJatSi5m7evvbc5iZUruJiTEqpmpfTfMjdLZ5dQbPTPWFfbW1EoINRruxSvIL/2eqapZ5WQ24" ..
	"ZnOqQMvKPuCh2+kDhLb9IqqPlsPz884Pv8btZ7KEawGzVk0n1yRXw0w5iOgW7sjyOy+DiwAvGmvrTwKKDLFSC6XAa1hLJLYf4dyK" ..
	"wcSmD6+WEWk8DMg9dwbwy0SaHy226aBLkDzlOkdQba8+XJIjRVy0bWTUkBvVsqkP5K5rlAN5hFg2Olp245R9CqkN0ZKzsdVEBUok" ..
	"GyP+AAg+6Dgxn4/VSmELfg5kQRyjZi9SC7JucxCcrTZZSfUm+pMzt/XqIz8lT7rz5rERKqaykDqHCrpRVcgCFNpL/OdkKpf8WV98" ..
	"8Vr7w4ijIR45Uxjh0K2no0Bmm/CIiscOZ0C8Of/phqqrFUivnFX4kx2Z+nJS4cPLrT4FfJBppYKxTOsRKDkVMpVNieIyThnXGvrm" ..
	"tbjANp2mX08w19kjkN1/UAyWpId6YLXFxNQQ++Xs/Y8jj2TK0uwPmdoN6GGmHTsKDxAldMa8YAVVE4729cESUR2twhDwhvTw9lUC" ..
	"SAMBq4l7s2E0OlW+eaxIb/wRwFUzckJIvZtnXQUwTZMuSXjGhMDkTrEjL+8dXgyuOe8WxjBlvmf4YAVfB4U5zHKU/z1V+cR1BYB8" ..
	"PtPFdZKfu2vykHEOg14wP0JKTDCHYrwXw9E1imZx1d6L/jizLptNKV4mxZASDoyp6Uxan4sh0wjo6YwmbtITZuaByQTSpIK1jSJh" ..
	"cTzqJqneUu+YfUL28Mv7zsC4nMBaq/R/aye+155M0kcLuiT8PEXxLfp8pbe/yFjwqwbp536ansyt3JyQVMHm1sgCivWAypV8gwr/" ..
	"pPxCHtvg5hir1kbCtVetzwHTRez6RmKMQll0y67T6NEqYWSDwT13VqSIUfe/opOVDNawO9RncS33cV6vIwjqmHarBZoIKvCoAHQe" ..
	"vCiBx5RgZKSdGtiTMofZpZQ5FwC9X5J62onG8jGVhI0cDWdJc7YvNqk5BaiTtztzDtahoK7s55qlKpXXVagYMInSTS+iT49zyhBV" ..
	"MGdspl+dXaCbhbyr5bcpUOBjiDUIvtGUL74cRKZIv82ISnHY7K5b8JG0W1YcAJy1FywSZfviT+T6tRQPR9U45ypjXy+wW0dgvfQh" ..
	"I72E3tnA9jLkd2By8CliXeuqFPvvy7DYb0vVFiEOPGfSJIahlT88CuBsEGYMVe2M3YzGT889m/1Ul3NesDn5VxnnugPAkxsgmLJN" ..
	"/eWIIYM4glbP+DmzdngiDwDHGLFl1N3xoxfVi4FkNJZFJiUfIkkqPu8V7v1ggf8MQSI5vi8mVXZGa94v+AMjsmls22yiUOyELQkq" ..
	"AlrPdwTfrJENa4VZoNcIQfmfZWqiWRGThzNW/OZCxtaeLbveOmJCbkyCqnvBl8G5tw9GcVPTKs4TbssM8qy3WLtMaO5Jof/erbHB" ..
	"x3xsHGtZGODfV0yemA4WBSZ9+RQvjqm56ryIUzMEX4y+Of5Fah5PX4KyWPo1TxNqGpLh7wpzabL2TXSOGviDD1NzjNvXIqGix4cy" ..
	"9N8/Hm+BcgckGpOroLh61Iqtp/VNj7K7XJVVu+qU/b7Ml1sS8NZT1FzuafB5t6rv5+9/Kx9Fgo9RTqKwLQVXtSm59vTMof1FYrVn" ..
	"I5wFOYBCjhloODqAFBAP4WzVTTm2v/P3cpRwpOjPRfHO+SL9M0Ry1buDUPxZOsZBC4+wh6S+xvHtiOVjOQu5xb7TrhllQr3GkUvN" ..
	"C5iakhlfqS7wUzz9WH3vbv/zaVBq6/qHp751UGzRE/9kKQJgwGLvm+nYqdD/AEYr3ZYhpND7Gh/a32W+D39VA20e/BlIt/15TdMg" ..
	"GsqGKIpAFmm8ghVfIuQzMNEatSkP2u/DALdlV7AskRq462T+u5L3GvWeJyzfa7EbR33yh/C+LZ/vZi6n/qXTDl3YtXJ4DPxuLghf" ..
	"SsUZnXG9oO6rPS3eD7v1WJC+hSXY1aWC35np3Uejvf2F+kvrfBFD5umuAdLB85J1upTIZcSh1MBIjLJMeTWLDTLvtNMkYH3/CLyF" ..
	"MpNrg3CCJLqnTYLcD0xsbKBRq3hocepqyei08ErjRiXlLlqILOUBgnAiO7usUnxKmXeR1Jf7PdUnXoqVlTf4o6F6Hg9XDkpqXEoz" ..
	"shUumqy0FOt8fJGoyiLh0GhgI8fANtTgNQeL0CfPsP4fLo9WOKMvcw5qsSic8OdHrcKXwg3I6K5mtD+l4aV62mokdtTt58sgPMdX" ..
	"tmWLQYZtcT9LHWZzcc83DNevVlo4M+sAqpOSdtcVBjhwki7enGamd1ce8FefhDMiJhDpgF953vWZImCGxx0GqveeC+05vfVJFgDc" ..
	"Ir1gtL65BqONV1665Kx1eCTD76s/OLNR4FWG5r56nvBYj9K/Py+WZJ7DzUoZq8OzFHq+62j31V3Xvkjt5nCRAJiaIr91mCyIR+H/" ..
	"AEZL2c0GxEw7Z6RnXGx4yBQBSCjOG7htHVKLv4z65AHpTULYyuKmDNN5iVGemeF8yisL4s7xeoTE1sS7AlUnzzLoOUEtH7qwAwGm" ..
	"FmOV+qYSLrmhD+rfpVonLnFJDcHNeF4EX+otLCuobWw4U7KdVhWIJuD6BnVkOVO1+JlN598dGWND9m/UEzVEgHFnGksKxJTpAObP" ..
	"aCjjCKdeYTyls+LpC/ib3uEESw7jMJFcgLWvYhYi2jgM7ANuA6jVB5iS97aiQI9ePKA+nl7FUfg2J0SqubQrhXA5CNpCio6N7pFN" ..
	"xPB0A/S3fusWhN3fMP7RcqW7Vu1rR5s/X8JXSTCGrk7pQeTSbA6H4ePLRwGaJ7n8RIhOGMMZDT+sA5MvQ9CXRo6heXfGOw+wqGzF" ..
	"XSTMs4Woafc3k4M0ABTKALqP/KAVTzBzvEu296VoTtXJ8W782Y6VVJpCqblXeE2pJQLj7o1v7ADPcmvjxckLIneG8+MrYe8Xnm8Q" ..
	"EV0MQwsk6i4fWRTA6O4yWg/PKvBbfnuQh9rn7rv1IPK8uR0hqXT0Iq8g6TSZp36+eO85uDjwzdM1dlHdy5sN0FcACbueySmT8MNT" ..
	"JphMs/LWAZ0eF51GZPvhGOizglEg05C+DeVBcoNR2XFVq75udKGNrnVTt1UIabd8keyppEmQijyCpPF90dt/JRAKVbzs7KU9u+Wt" ..
	"kwehJYRTKVr3uuhLsCjo2uxq8QmaBq8t3sLOHehzGgNLJr48BWRwLmg/2mi3/3XrKHNWq+iBiS5MpEI71xBPlhty1FoNQqOjlkfy" ..
	"FcgvJ+ggjS/37fwmSnWh0oOJEf2dIR4BZ2w+Fmou2qbhSLSUuM//hdSMp43A1gpmvhFWumV6cE1+QulyAaSrEiMm48t1ZJJAy1ya" ..
	"V28c7GIQcmw5O6wsL8RNaESTILQ73G3Y25QZ3+SivlC1uH+QziSGARkSHxckg3k5kl6JU5kwEmSVMJqr87CmFC5UPE8JsNU2HeRJ" ..
	"oK0D8tj1l9ehJlRdWj34CSfAtcN+v3JLaLCEObHFckyuvHATl/RjwaBhCzkUYM+DTIRjSulC03lsU8lN1GRurI7rafQV7/8RLOol" ..
	"RmmnxDDX3blWTPnlWGC1K9lzXTCUtLNdZfpOZweb5yVZGkcFPywu5HV7+p/WS82EARa4fasbEX3RRSYNXSOUkSukLFeHOBgFzAJR" ..
	"Pp77cZUZM1/6Vo7LMZM1Es5NUnhF5+oYXU2w5cWR/4uFhDYhnI7OqH3loNZIZfMSpUyzNng9z/3nyNKfGEKDoaZPToq9QDCfU7q2" ..
	"EUHIk5vCSdCBC9NpJlp8qx7amnRHkrrrEwr03VAINfJCBGt5SluTkmz4h5GZo1tYMbAbWxRATBfuCuHbLn8HmM0aJ1240JvB+AR6" ..
	"1/ADGqzX9Jaxks8HeuWrIOmWh0pHfLSNcDBYUdp0BoAiBvn0Ig5uvFMeY4Zd/QN2m9Kp/q92jXrl8pgXIbFI5Hx97x5urH/erGwb" ..
	"vAv/c55MvHUC6FgRJDr86lM4JlxPyM23JGnGHVsMLo4wtH9ZAiu98DU0jW5Qllbk0GPfiusEXZmUW/vbQCNnbOAUG01mmNBVk3zW" ..
	"smQGm/p20kMvgAUA0jI0yed/7wAF2xLWw1IRmljsmCQYf1u8+eRT8CkM8hQiD4vgnvjdZFXV312Xc8Q9OGFFLzKccHmWrusqMWa/" ..
	""
local PAYLOAD_P2 =
	"0d8TFicXY2DZr3BLD6pUKSfU7ln1symKE8fBxUplbDiuH4N/StctEejVEDeURHpy2kUT5IBHjBdMAcI2tBGXzAMFAiII3iyclmy8" ..
	"lF4sOc2uHT07FIkHboM6F1QrghagPlGKJtYdlML98obRiwUuZ/XeoWS6Pq2tjWvHQujOMW/1QEkAYX5aDrjjl42WtYCPYXe/NL2R" ..
	"fndKFbMpNnp8tI6RApMWaJGL4hUK//JHSfTT03JuALdH1/uPrEYqgeMo46sxOWebV2tBCaLs17kLvfPBfbGG9JmaqO1NLYRh6Qt+" ..
	"SnefFUicj9rIw1+SkWTg8AJbUiVXfUR5BApXzJ9NiZAhUowzXNI47HTtEl4A9m24ZZ2mUA529SsnQMJCSNxSoTA60zuSs0dHQM5g" ..
	"Gjln4CXuRbPu+BaquNnXsDUPKGLt58NFA87M78WX+L3JpLBvVYXdUxKKE6LW5RiBpAXiLbWqdJiuEYOQnb9ZIMpzI8muPtSg2YXm" ..
	"DNc1UqOFZAKnScERcU9r94FeGkW8Wn8AdArFzXzKG5VQiaC6CDtvZrrnEJaPL5kXOy8wBOK9Hy6Yc3nnvaZH4Ti2UVPxq2g0SFoN" ..
	"YOOrWFYZkEIbCFnSQNzMT1ipeczqtSa5kp0WJ2BKKD0egKq+k31dPgF32LkA986POG3KZK+Zntw5Y92LSY6xft4goIxjSS8sChLC" ..
	"sB5rZZAMHZCiM5ejgB31RF8ez7gwkJWcoqoq4M4Uq9yprlYyIUS/f11U82eF6F4HLQVYgnAj4N8UWiiVhksqkEcE9B5AJW3A6Unk" ..
	"gOlHRqOd7p+egL4vV6zK6P1yKMLFW8FQu1vh4VGLfL0uIK/GRRFXhh9LUQjquwnaSBbpYiLq1zEnOQb49FescovlBiIpFw//2BE/" ..
	"BrhyxkodEvGMi1maaHoJfU5t7ZGDpw9XH5s3a1h/wAaABvX4P16ZrQefue8tPzXXAn6d4H+uMo5dybLBVrDpQpkn9sV03vnE3Asc" ..
	"PMvl0OOGoavgObLc4LfcbWuu/99Pb40ifQDn3FBDgreDIm+lem5Wt3AJrGPLyTieXafjCSh9jfLTtKsy/t6nhXsvCXvyHzcsvO+W" ..
	"eIBFTjQPDiDeRNiOaO29iYjfBw7hzYDdWfOaR6Rw0pOU7oOwx2UchSqcvZ6W4Lc4/sF6fQ9w44Y+OtTewcHptW0Fn/TdxB+2Yd6f" ..
	"4TT5tME0GcTK5OrwNwKFzuYGed/S+UlBTys+f/G/HlGhkcFbCgOOTTYE4oFVwuJvhwtHyW20+545Q56oAkFYl6egdFSV1kzvlVgi" ..
	"D7yShIXxxGP4XlaWLDYRNltXD9OwxkPP7SIlalgDSiUCeKimzz3cWQcgDhStRnX/ueRhRllusNf5G+AlED2LduiAtiZkOTIUOJbD" ..
	"StbiXjXq5Po5n468gf5Nw2bvInbOObe6+dz4buD6Zva2FQz8SB00zO3+f9PxsaPGVi84QO8s1vIDFDDmmhlm7UjeJT6Qse6YUjJX" ..
	"FxKayg6RyhSjirPh4yfYk6W02fE+1yoJbU6EQ8gCf6gF61mW64h6JuIJaw38tprS8uStGsEakprS/s1u/0DNekzSYjaq/vqExzae" ..
	"gR2ilD+ftWnHPH0J2zuERbGgWnEkMrPxCRgpb23reEOgofVdtrmYYl11TsUKkt2t3WYV9xRHoWjDzhBgszLkxajgnFlhPcUZ9mI6" ..
	"pLk94F9numnZNqkuBAxK8tWaLAXjCVbSG0Ye/Wpe7PTmtIaZ1BQjIdQkTDMmlZ5mLwXjxYuTQ5dUUGFFWkSYsyQkK0f+GDHmtPSY" ..
	"cIKZMgkX+OOhfjJj0wUH3v77rTwWe/36KmZ5Q04f402t/INSMItcfcEtGzJfn/i0WlweHmilf5v872zjiyaG21aCB+iD/yoEtfN6" ..
	"d7se6VxTvFNgbqN+5tTGQ1FduqY8gTD/MmFMbiYG0DXViuuUefQ3XRfxxHIgTFp+vbHwfCCTwS/w0Zoa7kgfaISho1T1KJE/YEft" ..
	"cUDbPRkjkwLccGz/Y9BjPgF79v3rMiwLG4A4Y00Hw0OCnP6E6h5pR8Zxx8XfbOpK7Oq9raHy0j3hEEauSGuYBoIfXyKyw5PFEBL+" ..
	"9NZCyKfvYfmhfLWKhkFblYwFQ3y5mJuAiVIauapmwhqJ/oa2lqX9alEe+Mq82xNx4Xlc/JYx0T9d23q0f4EK4Ygv7CdzNKeLD0S3" ..
	"49xes1azRc6ghIE7XBpCdJLstzowSQc/df/DSRkjpylK79amYJGstHwCdd3062kUaaaYkXZNT6hl4UUO337IwjtyxLThTqSNA3XS" ..
	"trfJYz7zoS7tksqjxseJGM4jljDy/hCaj20dIb7XZf3f5fg/DbIhTn2FpG2oKj6yWf8BKGP8Rrmf+sYt8s//YBCkP5cZFkTXcxIX" ..
	"W9zynZMI6Zbf6my+o0mqJv+l3J7rL/O1mhZpOSwrp7q8wbC8LaS8MePhywUQkGEOKQXDXP1CDaDXwM4zI4LyB9xWczNUOk1M74O2" ..
	"MujYLnsB3/gn9RyOtFabOnyQXYXJgULWtiQqe05i6J+klrO0OyAWtcFOP1tyY0KE8Grd3cmKx7sEXjv4sSlQE07IEkSmPqosgKQ/" ..
	"NyCpbANH6r93cxGkYwJVhpzXwlw6KaPgK2szovC/G6wfkiYooKEc6Vo0mMOKzMoeaKpektkyDn18+W/BsZc+qH/kBIirIUqNShsy" ..
	"8qMieLEeJ5db2HrHqkSMviBMJA+EeUxLeiuWplqamo68Yp7IlwIfx7vscOlaLqaJsxyTl+xbQl4RkO/igqJyPPTchthS8Vnyisj+" ..
	"nhFwJqHXVMa8rb9njJQV/AsJBiBQZAojNE/ALZW4UyQ1plnZcSB2571CLu9U+iGke1a65bCRKyUfchMQBx1NUwzx5KITAfKSCdrT" ..
	"QyFV/DlyjuvItvJsey9prIxu/TGg86KGWczOFJCR0i1ADfwdmerqu6BlTjLGU+Ad9mCpMx40YW12MWNvgRwKpfuu+HRrGGWOzSn8" ..
	"6cGMDZgtskbj6tNW0HF+ObiGPAQIRNMb84EMPvvZMi5Afv/MyLdDx3l7RGI12Ej3kPb2HL6O3UzQBYooyDHrW+umbNJv6rNhXw08" ..
	"Z3crjYs/H8A1jlKsnQWLv7N80ss9dLXniEyI8WPa2BiACarQZ4cbNl+yPOziPA7qKCQWkW9gQYWUxZc7JtgvexQXL+Rso3yjJBoH" ..
	"IpHA6EDNCAlytW5NbnrMpUpRx2mWR69do160O4ZBJyP74ptUgnIJCjYTOSI3+kFYDS/jTeGL+ZWzG9am3ebn4gTynQny52X3NiAy" ..
	"My9im96LZI93ZfpK6n0Xq0UT3hzLPmk57URnf3dw/7yMyPXUapstcgsEaQVfgjXaAfIn8mZdPUQVqhLj2sqou0aUsnDDlfZmss/2" ..
	"OttLkRqmd8DRTreY4kjaASdDJyCgbrLeMGIjjlyvkqVoiryNtGxvkR9FvLcHamdwqvSpf7QAYXaszS7C0B9zp7RitM7jMnsJQBDr" ..
	"4mXSqx+IFAEhgj3GpWot88sj857wimiUDLev8jbwb4GtUOt3PwI6peq6cvp9xkjac/p2kd+w61QxzoYqxUuuGvtaJPOJNvH9N4B4" ..
	"TDInEjzPAKciHLfC0lVvMPgTeawA5vE9T/wEfbzuxcM1L8ra7+/yBmmNPkjIY+VziisLiHNoTsBZ40SI9nOQjh4oWjRj+e9R8eHn" ..
	"bXa6adOUeakHXUAhNYjkVGM+EPdYVmtWl4K1O3IW6qluBUS+6l/14s72yU7DaZI1zcP8fENyJ5fIvWQ0c6DCHOV3cKgHMZZJUS0+" ..
	"8oU555VJ8rw3jZ+qMNEpbdkchZh7aZmlGlfO20nJbxS427GNl64ad8I0rgMhpRQju8yLAi2SyEDDVP8vHrz5WT0ieyGrZ5Jsl9iB" ..
	"I+WXtqZkdXWj/MaaT4fw37dZ4UirvmCSSXjkvOD7MZB80qtaF4wcMp9mD0PucwSA0dViuwPHMMMGbSyARfPzIVby/gOq7rjdgOjL" ..
	"1kSca89mQlpgkKSCax8s2esJabQz6OhwZrjtRCZgwvPreyq0f/Rvs89FFl2m3IOurN9m6ai39itz6T6jGFZshJuB9m//dgKqeVOk" ..
	"1l81XHnzqLp+/vhXumFWSdSFdJi9weWi7+X1BaFspRSfgdJS5SFKVn1pxsUN8SLzi0BYBfFc+DstvqougMmv/u4g01bXjGVpqNas" ..
	"zZu0E1kdfLw+pIneVCBpnKssEJp82shhJDTdlOwqpfKNflXdLycb3lVmwDsm6TyPsWlUhI8Zo3dIAq66pORnziymIPtBLimSgb7C" ..
	"7rH/IlOOmwyI2UlMWuLI7OA5ZimcUFQvLdo4WuuqW4FBDyE5RiZ2WdYEm/wdtsBd7uogw6Ir01C+ujc54d9jBRKN1CFB2elq0Zby" ..
	"e3JGY3FwWyYwwGw+H+gwCYMYOm6S8ee1v2uiE2NN5lXsKd5wu/eWN+Dm2lNw5QtiJozvt8qqfc5kLKFB9YwB5Qe/mjz2rMcLZWOV" ..
	"TCg2u77WUcPFDHiTzaYguW3DQoJr2/m7U6OI1+Cc2x47zP1S99b7L7C6ZpmeIbWdmfDOktON630hZMhVYkjjejeJZNnrsxAgwBto" ..
	"S0B+NsUPrY0u0PCUsQs46R7f0H0dzA81JVzXtn48mNlMkfLoUCw+O8ZTB/Ji4wl0lIdF5uN4mGEUvOk22FKvMr/vM33xqtz8RJCL" ..
	"hfaJUkxRGFcSy/cw67SYKZhpCMWX+pmNPKrH0MItQaUG/MiteEayFbr/hc9JDAo5xUQHl5H09zn7QL2wlSxs8uS/LSXNYCL1orSY" ..
	"RTKB+52CGQAjxbtyQk19ofF5/+ssDr83jiOB1gWkBuYzKiaXLfBwmmWboqPeXZVQyEsu6RDF6ANpKRE57h1xk2Vm//gxhw4DEPdX" ..
	"t+/O3bzmhthitIhA/a/sm8oMPunBzht1lYAb36ZJugHia/hJ2KiVWVdYQ8GlIBfLPPKbSZjtcMgwJmYqRV7U1J+iZn+F1/9Phbz1" ..
	"4nct9Viklotgdaq6CwWB0zBXZO30mlZJ8m87dbh7JKq6TBNyX2vdUVee0/KIKYU3yc7kqJEE7AZf87btJPrU2l8tN22+63jB7Tdq" ..
	"P66sZc+C++90dOVPczMFtR++Y8/oXYgxRlhkd19LjlhpBu2JaL9KlX40nXHtSaMLip4lbHoPLBrFFiPIw3EMwBXeu0oqDxIcBfhy" ..
	"xjLXvKVVlJS8Bl5wVqCP7XqrlMoZFRFdCpdjL+0yHQrha1vOsvCNHLuUw1gCHQUhUB4e6OgMIhr60l+T1xg6dbC/kn2OsoQlBjYS" ..
	"IbwLsOrr/pMAOey6M2d+frj2xdRzZSBkY+sLDPd7tPF5UJbwOEdLSYMDePU+dLAkt5lUrKXhdk5JfjJi1JG6qBHxcgfQ04J2P5zs" ..
	"jY6ndRjTzc7x+y/zjpFmUIPG3EEpP+L5Lh/jMS9dt9+Rhu8VLIpdzdDS8UHxo5x6vL3FpS+Z3Kn4JPLqs5A+kfRlfzAJs0jKv1sv" ..
	"9ecpVyxECN4WkDgHraUvYAzNtYcDscA7sWmX/EYP967ZCgKnUwnqTasAzPYgt9m+VT42nWqO2s4sTjiigrJ80CyEdnUUxYiCquwY" ..
	"FtzkEyZ5bt3GKxqO9XumPtXtaNBDFKMjxkjqC9SGVsPvx55GzXNRlLRc5LwgOhwhFwKI+GtJoYL7KdV5odK53IUSDhHUPZ8UDU8q" ..
	"U0U5P2Z87DuAnjvM0A9yArcr9mRZRyFFmbVrDTWJs567syWxzKYXioziWjI7jsMIzbgXEgnfDa0S4vOADcypr26SZ57pt7IGq+Ld" ..
	"kf9q0qksiNBpUDbdzFwvuE0/N4PRe8o4bnXU254IsBVbTHCV6ncK0Xd4N+KJjZ/ivsN9aSCNfH1OFPkKdDYqjDFLieYpoeve49EO" ..
	"/gMoW4rk4OQGK6DsfbtFg6Fuuf7+W9GLq3eZsnZM9f5bKFeM5b70+D/x9cDIRGeZsZU9ruEUErUg+2vTZLJTJFwcQFb7PfYkxJco" ..
	""
local PAYLOAD_P3 =
	"641+oILmQ82GrZBbpyK3CY97Z24HJSPqa084eU7HwW+QK6U6sPJPX35DeZ5IjsO+o/62zuFpko74Cte8edZQO71gaDKbk3xCo5eM" ..
	"aIK/2YNYbJbgmvJMyVsyGBrRWGVu890DcGhbxeQYdthPLE81d/gv+Yu4A8ixok9Lo9Y4k8K8IAGigF8VBZ4NnZjtgMjqTCPuVOzX" ..
	"4Zr3QC8oK1ow5js3OFXdIFht0QrPONDZUGG9nR51ttVSdJMHRCbl3rxwc6sgqZZZOaNBGSz0rRCgr4zntQc+pwLHDyuTQTPvG1nA" ..
	"R70jRCOuZrKiLON8dL6ZDTPOgj8xovDMY8bQJ3vOcc8gcMaGgmdIEU0+Ppb2RGCZFN38lCzqBChgkOf9SdZodsF788/xDihBhIce" ..
	"fKJ/RMEZZKz8DgvX+CVm3dk2nMaL5GvPdbJwzdYhJstL4g/eFDVyi5XxXlhmI9/QWrh3q5QP8mhvrDn+6968mZGW4ZXpm5/fIlb/" ..
	"rCt7i/sEupVy1ixtXl4/G8X17+toVzTa3D96k3QHsgOtc5vscDJWWZUpUGdUGtu+Eu6TwdyHzj6KALidAIFpLyS/QChD85aXrBye" ..
	"vqBFUoqPQKZ+khp746nuqnzsvejPS7Xe5qira2xiOA84g91ybty+Dh1rwSpe4I02pCq6b8526i65kMikKCOTGgItDz4kiHbY2tVI" ..
	"GUAVCzWAG8BvHZ3yhyzawoNyMX8U1PpUJjL2rzmYRBZRIPr3NjZoyOQJqUvRwrKxtAnvhFPq2l2ZjjyBoOU01vj7+saTK1WT4OgG" ..
	"LyLiUpEcu1tHE66Xd8d+U0O2GfZI5Yn+CNhKlwEqsYptXsNBAaGDwbL4bPlyuqawOg5TzUzku3YmRguuYTeHSVmxOY9kyXiEbAaL" ..
	"cEwh/JXLLs5C60hIe0XP1QCE0rzWZ6Bb3MfxTfrAJPHIFkGOExtRzw5CwX/2o7GoJznSjbIb3iKIJYWcQq/johjAO6qXDfyBSTEQ" ..
	"t0a5Mv4I5x+mdnjttsgjsrcsd+B8AYfF3T89M1jYQn0NLs8daoqRDBNSHHAUDPQXLiOlD0O5Rl1DM4rtq0vM1QsWS2lanC5SXJAq" ..
	"RFJA4mvitNR17l5uekBL3nHRUmLkkZmiIKUEG+AuOccfybjjSqYAuo0lzviN/aSS4DUnoAzrWwskIsP4+3ZwqDaae7gsr4mjkA84" ..
	"VlV8wxL2i0ujBxbr0wrnDBLVSJx3dscavklJnsvUdzgZqqLpecXv3C3/O8vjJFGY5cwjpIsFGVz3X6lTV4Ugeof7vFcL8MlS6UCU" ..
	"gblvzI7mhsx+3FzDlQ6O6jtDzCCrMcJ3UsJKuptKgNKUQthEQLxyIn/19ow7yvoMKr7Vpb/QNpC3ljMMvjX+PA++ocBtTpvracv+" ..
	"LALvBWf8kWMKFwVpLx3mjhc8NJG92TsT0AYRRXNsZSUTA0U/LmijZlXUEQ/SyM2p9WHkhAGsnYoeU20My8u4Wager8xM0oZyGmXI" ..
	"bnYpCEPno34eNaUa9pN4ZFq6g8GyqVgAzFvzicX2t9Eg1wMfSJvrLMTvVOPzwrG9dCzXE9dBGJG98Ya/+axJL9u7+NWcHEGyu67r" ..
	"20fCujZ9Fto1Q9w436fp6+zGqX/4jh3pC2jBvOPoci7GLCJvqoROLOoIMeEJ9asXmh/pxLPvDGLvSyPMBraT/TIkMiHvsw32Qu5R" ..
	"13V1LZ5lvNEVEjp3AlsPtQoysSVfSYBxsTe+SJhSVKwXXcrILoUySboGaC7wAcvcT/UrhliUE0rIFclndrj9ai1D9aA0aT45HarE" ..
	"eLRP8kPUv2mqLVhSjDD3hd2u8bNC87KEgfkN/9g+ykSOuvdN/LJ33hvFjb7OKhpGNlZvD0WxOOkZV0ATkSEb/O0uDUwgqdTULZGU" ..
	"DSqrDlZU6gRMSdtofr4l/+TLCrp0u+YrISK0+rxmIpvbXzyx9rGo5cVlNtf6+G/UBRqB6xaTAnfYZ3H2iSiad3P6T68EY2JFtFe3" ..
	"7ARglCqhhuERMkpJq8tzEdoYCAlaJ16JlNKHsoDNAfRzJnonbcIg+2SJPS7vJPrOUcGNGsn4REMO9QeMYCeVvwbR4vMqu20RBAnU" ..
	"TvuHZgLTd4VuCqaqnDlfwd7jMNRbbN2l1anVCDYexAk4fvAwmLwu6f4sFbUuUL9DAuvpLG3SEAyzntUt0AOnp+RNLRW3S0OOoQPM" ..
	"ZHt+HpE6u3esVbGls1SlAUwtWKnfQ/f78ZwRBLJZX5ggfFyu8zsqKUL7Q+FiMUXfp3v/NaKQKauv9gMpH7B2FeSUxJFH+1wOz1sH" ..
	"pK6C4SIz31O8Vv6NnZOy8GUYEyMewUM7ycvBBkuf+sDeDHBF4u7IpruQIM2gC0vE93o8CqS+qFOKdfK3IAx0v19USD0BEhDQUYkw" ..
	"aeX+MOjtQ5/yK2VvT8Zq1xCyYdzwdtIeMnS1DCkx+mRwDXz/bK3ue2PTdwVqKBetR6W7nER0gq2WBVV53f/fMzEVRYOZhlGrzjf5" ..
	"GuRPRSjr3VxtoFPnQa5d6Vm0z0+kKaq4LmDLPD5FQWhu0YE6C2qcwwqYK1GbDn28+7oeTBbVugjf8wnBf66VDe1q83Y/0b//jBdv" ..
	"/n/jlLwz3hp8RETFYiHDfhDrHbnezP7mXO/C6vtilkrOKDsXdXz5OzPggC/FTbzh3dXzMEc6eCGPNSG2TKUoMaQFU63wJdXojogI" ..
	"aLQiJ/9/L1qiVVPJx58VKJpYA7s4CQFQzuNZ+qfcIWxFLPH04lWI8uqtMUeY4+7J527xrjia159ZgZVDEkpfDOiln+UGEPSCfO+M" ..
	"qBtnOZTlcD2g4rPcdyPk8vTNzWSb3wvxKyi/Ux1TwJCBvjOaOwyxUiVNAyQW7rJ1evx3d1H8W6s+tJ01TQt0zdc2+RgpocuHH9Qj" ..
	"6gZ5LJ4anIcw3qAeJmf4R5968FKKacrqs+clUEIByX1ABBVK12TjsA/UqPAGUvi/8KLEfGQ9KY6/8ggyC4DYST2gW51X3I8npqMz" ..
	"nylvvElXlk/uPJEPyXQp2bInMuD6ccMdzM10nc0r9kGYJMy+k8+cLuaPAsRalK3lQCCdQpLT2jDf5o0jR6IQ2h6gxOSJjGz2gEBb" ..
	"ZCch9ZCsN00CgwbVoI822Xo3xygYlIZkTHLlJrylUwEVT2ydal+QEoUXtAzhYNm8vIk4MT+dhsGFjbrGRGiuFuesoWAkGIyREBEG" ..
	"9f1T7eRwBSGcJMm6o4osa/l5xZQmODwQgtplndbX+TLG7Um9Xf5aQpVnDUqhuMjewe8RCLuDCBweic1K4Q9T4JdM+67UWw8EXlX6" ..
	"pafp8E58m75bRxqbQ1V54djpW9aUJOkS1vAJ7fZbjecamcqNbnRmq9TaHao8UX0FcU3w1FZwgp4jnKwMusthmTUyUcw+0sVAc1s9" ..
	"cLtqbSz29YSbUg0ZdQDxolf8VtdObBeKcbOt9Dlrd8zPESJpj3lDa8VnOYYRRwHh5XnbXz29PVuvCpFz+xJQbR1CMaAziE265uri" ..
	"m6SKORKKoI8eNQnxKfIuvJK6VF0DoczLsNXYNVlcaYvRBpKJL92iALRTN2lI8vMN8M2YsT4aONSAcTPPeSm2lQjDSoOYwRI3v5Bp" ..
	"6YRo+//dOeSEXWYAPn6P/FDPwN2Bz/YpOAEdCQAPy7ZmXiJ71ZeU533AlztWKNg4tt+3NhgglBXnk97KnZtiiW4dmnQRXsLesz0i" ..
	"06vAr2kKyBbrEuKdVb1DOZ7OfVCh2nh06TbwlTqDhDzVjgR9a+1FbQyKqv71COxH7Jb8YvqMAx/+W21qXnFFcI7BRJpQuwQ9bvXb" ..
	"6VOEN3dS4iG2WrBAYKMQFWLBwc97Qips/wt0jbL9Ey0/DM37VTvlr1awnFL5RcWmH0E4SUBKm35Xf3uuckqARBFZq06pBS5+1O++" ..
	"ctE8DTXfuEq3tUTMQhRWqgtRt27hf4WlgARih53dxaWq0Johak5wbD23DfP/BTeji1b2gR3cpR1qWMQuoVo8HTnIbeBbVFCp0uTx" ..
	"0qFd+j5bSRHqm2SLuF4zxp9vBa9rXCUxHTjm6w14hkBeXyialqpfqPCfQq1ymIdyxHSl+mvSVXzPuccvupnltd7F3ausu3BtCass" ..
	"HUsPWqyLgIusU9vhSWzBg9pAfslP9+9yckC0tXriT9uT6kgWxS2sL0pTePqqM5VikpGOM7laKsRhZM0pQ2q7HRxo6M+bxoMmRUR6" ..
	"2loG+lMxQMR4enj8JLODOyxm5POWnW7KLYBUm/YzDYsnu/SdfRuWNvNUmqCi0GJ279/61Mg03EU5IIda3c4CaZOKTkay8C3YYmWy" ..
	"nDQN7mmqwGhoiMGm3mJMasyIyQP//cO37OlUXhajV2WDNeNC4J6LnIDTmzv4jaMjXdej2GprSWZwOktKOzomYGodnVye7nMeUnLt" ..
	"5JIpeIWcRvEPgKaU6mflFPxgUP8dQjFm7u3Jp6zitzdgD2Il8dUQ3qZEoI2YiPpe3OjmqUWKFhW476V47k/PO5lnTtalUxj9w5n1" ..
	"FKPeV/SD+JpH8CtkzOt4YdpnuEQsswSZpV2CwG2S5P38/cyodfRAzdnxdxWO1vrLtiCiySbsEay1WPnHY0SVpKELTx8eRgVl8Rxn" ..
	"9/vW8SVhJBobot0H+eQ/+SObhISIPBrvhjtZK48TUon7WckgNkz9qNAdm7d4Fl4BA36yM4wnTCbjOKekGt8OLz5mcYTTb/skJaga" ..
	"fUbXsjNQR2IQb8s/sjw+tfcPOU59dqpJTg3n4F8UdsCPAdudcH5KOIrTUcafhBoykrGnF6whry2KnnAYPKM6ktLs95ASLyZrgLrn" ..
	"jSBkaEw7MxgUfXUXf+1mTnSqSsfyIBzFg/4Jd8But4iKyBPQtxA3zr/WSiVqCIq0OY3bUsaeRQ5pFSDVMuhbaYIB5E3OYZJezA1e" ..
	"eJt1FjTMFtdNtb2BNz2LgS1l5nwZzzOPOcctI/7v6cfQgqXgZhN0H3xlK6SjwjWh90eDpf499fbkv2uGLhE4NUAjrQMU7by0FhMI" ..
	"Ny6WddKsm2W+qVFALB5b8xIVbe2OY0AbJOwcq4ajnVYqkqGOpZZRud2MS15lcLkSygxyVD5i0sroDPBHeXwkh/SPLeDt2h8CQr9j" ..
	"zCmON2Co4qI1mLAvkafqS3tFUegt5wT/AZckJelQvcatVKCJ/YoF+eYnu6qXZGKubPHJqCcmeEwYCVb8ASQBdCxDnsN4XBWW4rLB" ..
	"LItERCjai1FqQkfaWz0kodipTynpEAHHHkGCL5Z9TlrC/ijPY58wQ5R2CohzhdFQe3ehUKJnhuGvMyREimxTbCFK4zahptpQ1yZw" ..
	"8cluiJRczudFlsFJWVWk2U68WRjp5fWZcaqKvm/Ja7hwEYlaVAdirzcs91+WpuuinRJDDixklRfzKROt5nxoz5qZ5n3/pLHi0fmE" ..
	"hBBwUgHPyMall4Kw6bagYMUZ56cFU7QihTmjx8I9q8KJwFiwl3rAUlHcfkglbdNk8DQM6TZon8LnHxbr/i4Tc5E9XKWOF5BSSaw8" ..
	"6xhx5Gw47uWO8OyB53tyYDV69ZYoBwtsIFf35dZ89uf7/M7vhpSMe9gZUEfQM+j7DAxCM80h/mfYXiXIBkvbsL0NCapJ2Y6ONIMx" ..
	"Y9Ju7dOEiKynuJRMT6KKv02DvitO77+5PX6rBBHzMJ1wPF5GGO3pnE7o+kshZc1fhftK0PD7u7q1D2ANY4kMEnqpSeXtVZy5Y1jF" ..
	"7t8wB1VWz4b1MwA0mn/SEgj8+aq2Pe7aahpGbKvRy+f/IkgCeJcF5O3h74MWNLztoFms8QoDBATvUwn4CO71dt0BW6Jkok8VZiwd" ..
	"+fFtrGgMoc1zmjpvy4OWLt8upANd+12uNR3LnrlOQ5cplIyGV6JvAGHQaGJGhqgwN0LCQX7hY/xCxTqUsSPmkFMRksGnezFjuyro" ..
	"Qz4p9aQ5HI9nzYBi9T3arflTLDBs/euRS0nH9pPQ/fQYvrut6lECTEKBh5Qznn0ffT+f4a+vS/Q8kL3f2W7uP/NpUvEyP34vMnLJ" ..
	""
local PAYLOAD_P4 =
	"Z+r1POwAiTVmaUVUZQUSGelMwIVLUxUNdF81PejjgQ485gsOUjM4tEYnB9FqNlzb0VAmnJd/2JxnvU8cjBVynbIE0uwvUylPCjgk" ..
	"YD39sxkiTsqU1cqjDK+RTXIumZJEfv/7WqM7A5hiFPwY2CnOtmV8hWsp7k7gSyWvbQ37bn8xPf52hr7Co2z3cl/a+3eR0Xro9IWa" ..
	"MSCLJfQPgjgFfJCxsiZV3pGNQBJDYxpIwBFa2onTGuiRhRWD5WqZJUGu7mxZrBa+jjiEPWoN6oYX+KlnthLiOd9YwdPwJeI0tbDw" ..
	"634wukO2m8NYe9jk1cBk2vaRidDXlOtYX+MkcOTnyiR2oJm7uT1x4rWU/uRy5WJ6EC+3au47dL+46uCSzE7Bfar10jSiblXJQHUF" ..
	"+0/TbWTRvrslXHcL5TfmSplgaelGwjDx87j3j+hTHHjDBYE4+bZUYHSFS3Kr3L628jmKInJJMZZg4uAKysI7g66x8Vnit9rPTdSv" ..
	"eaA+TFPlYcd4ooDBf3A0Zka+q6WUbhCIa+6ZAYz31lLlMPOqodFgUzmqRcaGiLtfBHr+VcNirJHvZDO7FDCSqM+VgRwysI8iOWBw" ..
	"pK04r/ETHelKNv9ROCW88srcH0JHDnuNuoPXvKX3x8ciia8M64sXshEI7fE2N+LoOuR0tqTQz4Yg+AhOFI8rImtfMcTYMJMtEp4Z" ..
	"pVw7kvZ5wetz2cB2kqPHglcZdm4VbDOVSwKeJwuIZw7MqqQuQOKPpwm2cbj9BnrWmGOWvZbidXM5QAPko6842DFHepGkL2L7z2FW" ..
	"hEFP4f8zktapnDBEuXD+8gL1tSD6PLJu+J/LnhRpIuIrsXRMmQQ2fpt1ZP1sFyk8h37rEbzA5XH6M4YcZ8XawKcsDvvvjTrDLf2u" ..
	"gpQ4sJegC5run44Aj6sIONgYFx+DBlZJdea83PmDeHnXoosbMEzSnk73VUxzdAxlFQWcIoZwtBFb99HFAoxtINqQtjmVYeHvnvir" ..
	"4CKW37z1neusO9rKwu8hK60aCzbJhOOKuL9mFud8E3dmDH/1MIbONv7OnUtv4WOAwiwax2oDVUiZR/qrIiAgyXAh1t5UEoDauIUM" ..
	"GrGouF1n7KrQoW5MbUbGxp8JEXt4qjqEH1xE/wilXPzH2Y+15suLqvS6T+B2cl78qca+gY4i3G+zff37pv8c2nEJj+6PsIAhJ3QR" ..
	"o5KOPv26wkWEowCjpGshIpMd+d+N9rwMdlHlmjPxYbIsR8gC4nlpyrEzDCQSNgorCZ1/utCbsv7afUcbdX0A3BXsuOA1Z2Ad8Amo" ..
	"Ij+HRbEBtEKCOp2O24w+OdFn5wQcb/h1B48SS55NIauKRWd6quIAoNsgyQ6HiewWzq5e/GXrQKxOv2vmunSlDcC+ESfk5eHzrAH2" ..
	"wACdg7FzY8K7SCrTlKLDfurm6q8Fev7FbIl6MP40VH3esFwq2kP0D4PeOtQNZ6fglu+Y1IFbQw55VHMxG6Mjgd4LZxCHfdrcPC18" ..
	"YR/JiA2H4JRVWe7/kbgc4yt+YVYbB/WOEObn4AtvsFrYrZKW4SNHVBsm29CLt1Cz5HC+6Z1T5xNFO/96K0R8cCcT3CWTm422jng5" ..
	"kD2Lj5n+BWGjD8MV5TAJ0OapVAlfETWvULhrd/cR4tJRbSKyHOjrlejhvbsm+t7dld2t6BAiLX0jC8i+mfCcY0SHQpjTpxCIuVID" ..
	"pTnjKsqGU01IZJpMP2w5OVbW4T+MwhWaoSV0YYIJAdWuftRGBlxCzJxFNtQdIzteWJQxadVoRXDd5bi/melCzdDKz/S/miJf+Nta" ..
	"24sZ+nbCmfPq2/ey70BEy7n9HMyU6FGmMjZASGIuw3qjyNDFF7BpEg8sZejCxAuDM3t2ZAXjJ+74Q2AjqHUYTLO+adAvDI55LyRz" ..
	"uRcbtn0FOsPvcOcDTSUlGCCsozvTOietlOXOZAre/6KZji81wd/8KVw6gUdvmZhYW0uGKtdHg7nwYMl+fi0u9zFb1eqZsIMUQAv4" ..
	"yfN8WWNfZRg1Dw05P9vRcPk1Mixf58YKnTJizMFAFkjMIsmqAui09i3OST2ZaO3+1e6G3TgepbiAbVEymjqmKh0vQxzdHaWEh6Hg" ..
	"0bU/pXtAAKRGdKNc9hkBtcc8iIeHzDtW58RNaiUlu6ZKgDVSAW4rk4Fv2wYfDPyD1+N49JLWKjGkA6zojWFk4x9RSjE3+FatRvXA" ..
	"rTJncZeRBQNU7IenfbgnNtB1l7cMNPLEyw/n6mS8FH4frb+6LIF5f5vwfruxV6H/NO9DuZFBjNqB9x88NKllSQTxLTGgKums9NjU" ..
	"RDT6r/1stg7ZaU5FSouzilormEDnw8N8ZaA+xIaPr1J8iWkJ4ToRvy4eJIEGGWcfQZA+DjiXFjsPSVJkxt2l6Fxfq/cEvpcBjrjT" ..
	"kkyKMeeolcCpZcyAcwD63E0CMlWutLEcTaFK2cZ9K48VpZ7dwcSs8jLqTAREOMQUmjdta+1wjzZzIcHgNcpv7hNmH9jPKQQ4bvY7" ..
	"VFwrmJ3tuCFwwQAQfqx+s1RnV2G5kYisxxNaG/bTI4OPZBXUQ55J6EZOC4dawosEbJ6qic2zKvEBiqx5VhrdMoa5JA9XRZfbtG3y" ..
	"oXjQmyz0y/xyk3BcH93SeYRrKxTYWRyYT8TQ3wOl6SaRhiUbmRxvOUoe2XdZmH24qFAdv8t3eUYfiAWnTKoRMDIx+sqtxmhEuIU/" ..
	"pTp2QvR+KjtciZPsjmk7njdxAQSgBiyKRx0+0NhLZ+dNwrRgj/CpKqm1L1s2tBQ/qR6qkRL5TYxrLINirK6kiImwKEZvGCixg4V/" ..
	"O3mEV4cSLgOn/q7Njp5HNwvFcJvLF/VKHxX44QopOPIsBN+k4N5tEsTOI4sLBA2RSatxyOfSoAY6LCRmwAt5e2X0Az8Kk7WMFscz" ..
	"DGBAzqf7wQ19jkblxG1Ox64synjNSxz5rzpNRJWJXGPYKUeUPPsigfbDW5kfbWfF0yFGH4MYFNxZiwGTi/jbLEVeqz9Rk+vxaZtG" ..
	"Ov8gpx+4FBB7sKNXArOStsOPoHp1qigR2qBtKTA1DFd1CfxaGVJI3akwAUpqdDYGrnP3A+6XAZpQTZ6Fbin1IeSdTHznmISIDISa" ..
	"aelIYqeFVR+pfkHsxPa+7lsRJ6fIyY5e9t/NpmssRqXPcAmQ0uEBz3Ec5mIrJO43O2rT8OokVIuZuVsEoIYZaeuV2uSAxi0EwNYY" ..
	"/1L7zONoCcRjzBMs/tN6In65XlIURBP4WeJAGIBtBVehyr+rBAfCWHODYXeVpAUpAl4F11+aMpCWXuA5yY61BbvbVQ6EYWn8qnZz" ..
	"sqZo1IUl3lOsMpeWD2i17UJTkn9QdYgeBklzUNk2KvNwqIqiAcijcFsBtQ4zTT53/jKSkjQ66SDgomFk1Gdcay8uYj2mCxVONdU9" ..
	"tFdkOHbKYDkK4a9v27geWI43HHO68qVGRL92sBScxye3VyGZv8EhwO72QgKwepSzh0VUl/vuTgwn4xenoh9yTGahg/ICCtv0mV+V" ..
	"bBphxzcSFnbQ7zk89NTxD6Xk74TlOpq3sC1hicSHGkj5PYUx5XpL2OAaMJvCB77Tr8B+9xvwM42INQs9OGNLm+Lx+zbzM9O/nN8b" ..
	"pGBVT8btQOsGd1jtpliHtFhnZmhhPYnU82tO/PRbsdFtEalLfbhqssgcAJVlmicvmLMQrSEgQT7/WrcJeqorsghj89uRC/IvOEKV" ..
	"ljlH4cJOJifN/k6/0kokmcLaZxJLZinmk2tXXkSGfDGGPlKwmHAy0KpwBUGh+X84i0pnXVF1k5tPJZo3dj7cufAAttIt8pw0mleU" ..
	"MUJ0aqFkDkiSjN1DAj/hd0nr8H43ibcHExPl8jW27lXI8IHbj+mwzA1aHa8BclBc8UyJKbrBmI+D8XpAcSDVJ8c3VFWdw3I7uGQw" ..
	"xRZhsy2GXKookNeeWidTQML4t3l2RmzdQqpgcyTdzfKZ6c8fWXdZyFp5PqRv+xr3Ut3BIoCt5sGtJALzmvu6p/HtOCFc0v0zST14" ..
	"2IDpzQHRNHWXQTkJH9Cxt0N28EFnoppPDKqlV5HNBRKckEbl7Bv+w7D4jhAiLxWU9Cug9FyXlmQaPaj6TF3tgvGuQw3a6/lxHCEm" ..
	"XbxohC3eC9jS6/pYHEmuR1Hy2QG4pGRMXoWa6BsduTYPSSFCZNXpnwHHUa3vB3w3gBDEYh5zQuZ4Hk9nqq35qoPIoz55z6OloD65" ..
	"RNs0vOYgAEzHFvM8MA6i8cB20sqXM20/AADEld8l58jCqD7WQA4UDatrnGnUzP3TyAnOWR7ic0qAAFUXNhJxIKYZr4WJH1AXcq+O" ..
	"rXTgCMIyHNR+rPUPEoV0FeSwURTnGZ9uDC+Y1ZBMb6MgndoUZonE95APjuVRh84gYGbMifOUCIkxHOns43s4HHbYqBEJxHQ2ApZK" ..
	"FsJGS5GeNXu26v6AHe83PFeU7mwR8oROWgah8ILM9bUnmPGOGVfbR/jWWrxTDCZYCV2QipHlL6bYGI3H24Ww3XDjs//SBd3HCabc" ..
	"+W/KInVA1nuyK4DJAJdTplc02WlZjVVwdrS8JTxDBlfyEUN8wsiTSoOtYXZuJYZRjPv5kLC8VPx3iOwpO66HNOqgpE1V7nwz5HnD" ..
	"rp2t6U8ITHthJnVqXxEb8JMGa5FxKEqy7U9VzbcuxN2BJxD2ssILD5wXolopb8pSeX0LvJhWYJu/DzMQPiSRQDzfNBWgXLrnoahA" ..
	"cnPzbjDdo/5cnU4yW//0vi8/ypBHLyN82NFE37VVqmnV4fHQCggzStdoAqAQCFJXg029vTiqrxLo0g5QJmhMvtZ96wXl2B3ZQRcH" ..
	"nx0Dy3osIaNInQhYm8uO9HRkJq+dZx/dFWclTh8maXD1ffLhzK4ISl0Ed8pby7FHfz/sSebuqhDQwuCUkm3l6kQS8QsDoIVoqPZ8" ..
	"q9fcAL2TbJR4/e/jk9SLHJ674DrPHUMytWMOSIU8jElJQpMueDbxyGB/9a4oZx2JeetGUWxTBWpO8QP4CyRhArY3vlvihzi7LNkf" ..
	"GajjYo6s8o9t9jJOo5xLo4cz2FopMVox/m2dDtmCjkyTb1qtgjoS8C5JJ90Jzz3PrXXfqeZrCaIzKUgny0NV5+wtkSmnL5NuIxlh" ..
	"6ZZydk9pbnuknUsbm/8CiTPu7bL1Jh+jAQkAPpNdV3GJ//IaB6sIXS3PeCBVKXk95bgJ7F6Q4yZJ/h/V6l/wDpvcMS9YD5BSggQ5" ..
	"n+eN1nHxqEdbGNhyn10LYUx6AfXulcBIKp3CKrxSVrPuKfSW3A8C1GQMs0njbCmPICcIL+6KbtmhDc49MJoPd0qUCVyvedsrh6b0" ..
	"lpmZAVtXQ0IkHSrnEHP7BQeJFcouZaL8t+bvw2Yg+xcevRpl+l7tr/n6ksR/recO/fQbyf1EzAS8+gBzEpCz3ijt2IKUC/XPexQH" ..
	"rsVpTtVrR1uTJJzwyeNLn54CQxDvGrXC7JkNqDCsrb/PQKiqRIuejs58woQ4q5eC1Mat5mtEyabpDtVosqUHyJEM1SC3+7XF4O5T" ..
	"UZNOUVOLI13P+NBec4BFo6K5mTCcsut428ASI4/gMYgyCweN76utm3Q30HgeQdULngPCTCddsxF70CkX50pZ9cLLWa+8F2KXYy/u" ..
	"KhSOCFPpWQbIG2E/NX29po9GPvhYS4Es2tG5oAiGj1nfGqFpT/CwRtsFrYz/ewdSNY/UeXbJgD0ZJbLI3AIWQItQYK5eZp3yeSGw" ..
	"uAwy/p4MvQizDD25PhAXCk0XCTCDJ7ZtoesVXGWg38DaIhcFJIhssF27gfk1IToSltp9xadmmhw4pMXQ7yqhJpwMDxdH1V+0UvHL" ..
	"JxUE/CnuX178oaI0HypwQdzoOBqtPFMc2vpP+JmK4VK7z3Cpj1R+8FEcPLOq4BnBJlesvCWRJU/SihlxHmosvv0P9NiXcOmssMUa" ..
	"LoyoAbSUX830WviPvWuF9zQRSTMLm/CUy1XYmMj5i8SJezzTONzQmzVAw/ApApXK1Lu5GWygp4UZoi/8QZV4PNufPWcXJwEzqq7F" ..
	""
local PAYLOAD_P5 =
	"tVwh15tE3AqQ2t6q9Vf+Q36On/OvCbslCESKpyRzWLlv60Wn7i7S91QwQYEF793ulEfEv5yvshrF502cmYawwr29a3VtosyjepfR" ..
	"f3b52O7daDvlX6W+cgoT71bytEYPxxJuh/3EdbaF3PQvGtrgfbnT0geLumcFJfL/C7BYWCKxe8NrV/5By04Nd249A8LhauAVoewz" ..
	"gV//TwplUcQA0j7rkg3pO/mQbqJdTuqUO1W6j41I2P9gcN3XRr38YbuQCiaAqwBN7wKTeIiicJBdyGwq/npvmXYG02SB9Rd02rXe" ..
	"S0xbs983Zm6nvNbS+xQ/fYhoBJETZW/TjTkYmubE309ksOaZvApOCP73MAn1YkbvEXeIc9whFMHug5Rd/OC80kovYeXirP0nQr4r" ..
	"qhTDYydduxqR574fWDI19tyutJFdHo/KhnvilfuxOIWSBP4+X/0hOFXoAi9hsnGHr/rDWIY1pNys/tnQ4aWhoVPyn136u9EzkewH" ..
	"Kqq2RPeko68srwNG5hJKbnnO3SeQJniD6OQVLbgTGSON2uvwWonTAWs0HsEw2oZDjVvzKMRVjOzsoYOxZ01vKBO8p/ceayPBqPKK" ..
	"Jo5D7GRyWBfguvEkl0+QTSHYvv5dk0oJcL62wil8+QkZiwV1hjuTNFfX2CKha2UvM1Ge6NPWlWgw7vBPxrzI6ivLexvUjUPjy0aM" ..
	"wXF+9b+eVMBHLFns6uO7j33FKzlUzv+zV8hPjuWPEMbYRI8gBkIT9Qmw0tEU6Ja7FtOvdzr9lSLeEVkqbzO4w4Jk51otNtvD/4Rg" ..
	"kvAecjxp0so+u3RuXMog8Wu/hveXEeW8URc7zwnx3JZ1paNBlWaMT8ujv79bPx0kVnjLS13GvP4IxOKvjA2GwCf/F47tqA08g/ZG" ..
	"UtIA9K9VZEk+raKu+lbp0NA4Rmv9w/n29P2mPunliZCVs34l0hJDsYsGMcUIHl0slebVOJfA6Nu9yxSvNdsFbdqyL9jyYkeSmpCo" ..
	"URtjR+1hn3zvCEU2LLAilXzaNumBtZGCBROOv2IMVwBfiZHYRZu0ww42AYcAZaHLiO1rAai9EShYb9P/r7AJvClGGlTwzjRkAJyk" ..
	"9NqX8WYUvceF1f6/IdAiR/mULWM+zkUHCnO2jxOEwZnCqi571xd/UfXcIo8CfhQ8vJo45kZZwoB27bz49z2mo1sFxjO2RUwXP3a5" ..
	"wgLjbseQTFKKK09yjFB5J3yvq38LKjfGgfTgdNHQE5Wtxmv5j/+dd/k/5qeee/AUbewtnH+ApY4CsYKRPq4dcjyA4j/MLYHDpFG1" ..
	"mgfBnMzED9NjbMhYZ196aweN3mX2jMCccc80p7I3PNHjdln/o8jEQWwu6XuKvEZsXleA12QNRnJNn27gRTbfyyO8n/xawXu1OotM" ..
	"7Em4G3HWEBA3y9CcknU4J/LP2mqiqTTGQF67D5uOqbZs09fidq2VPJvgTTMhnxRlvBTwJfxsqhqfXMh27a08mWi3zGpjuhcn7yGG" ..
	"o7oWPR4RGEKDF3qgL5UIGKmqwnAJqBWh0DiCtWP4FyZmJDDAsmWbV1NrRnrhL7DVxGtCWh7U3h23FOsei6URFRRSjaNOfhAd744J" ..
	"2xyQqkZYo3TMQAf1OQ/LrrNIoOSJUlI6N2VVn5tK4T7VshaHZkY8xi3wwsGeGC7YNUpuUXsuwonWfytday4+ANb/wgh/dWGvJWYu" ..
	"DKsDHrWNuwWfLaIXp1qy5BMSDmvf9BVzSwI4SOcWkSTVxIuIjfe9aMuLpXeDkN0uBzhs7/BVOd6OJLmDICbMbnc6xl8+/Zpi3Bre" ..
	"nE7BRpq75WmBRoQ3OzvgxtNB32Yj2c60LbieJ3ZTG2YmXgUUrWJK9nwTshzSmT33LveTy3YQJPM+l0eqYh0hYjjG9Fv4waowBg5W" ..
	"F2+MziuqfyHUpdIUy4sMGnnBomhruv9APABrnqhxBacFfYr31Qat4sdoTbvPCyZ/lFhDZor+1UdRKFhrVelCFbWsuNHlwxoY5dlz" ..
	"f4sJJu7gvILHqKu/LJmrD0WbmurQMR5Z5IsAGSBvmmGbZb/k+sE+Un9CmX6O1Yk/WksLmz0R4R7HVaKrd31jBvPJwLLr1T9ukIHF" ..
	"lJh/tB/ZMpnbYtssOUbHjZsQTzvVRBnxvztvBKN7+nPKUWq1MAoQF3ekNbsgGt6ekp1HDKpx4reTBbKQOr2bt5PohZ+z0SKTnSBP" ..
	"cpv008HEjWpaF3wLHHLIe1PBljmSdFFN5b+T1ulK1fTj5UIm6AwIo3x3HmbD1mpCdxHwtdEU+RYBULNt/Z5pllAgBuBiRNadYGMY" ..
	"qbXe43nsSUweO++2YJcpdWTC6l5unS1bi1wbLJEFqkdhDGe+xLBaBixvEk7E+UnXb0KmtHRV5WgWJXZIHVfQcKg6AQ7hyDZauuEl" ..
	"NnK5kHV+okhzwwSKNpOTnHlGXxkCu1gOl5ibLuhWtT3lTZQlDrhcDFd/BFB70yMyEwqoLaBeJlPuoaG4J/+sMawZIatqy9nDFw3N" ..
	"XxocO+oi4mhXuFenytLLA8VJyX3jndM/adgD2r56nggUnrpIcIZj+uvd0bompPNz1VvvpyiOArybLP3hLT8KybvXn77e2dvDzCkv" ..
	"S73E38m9zCt9yZbzGgLFXFeG4rR76aaqerTTLP7VeoTJAeCSeX/t1jQDZxkOXwKt7lWSJxIXRjglIH08bWRQ7V9KGSfBKkRwSwEC" ..
	"3Rz7wEvXcTPzE5DfxSR4wVQ8i3CBpDx/4SljmZ6ItGnhrqx2AQQkbxWOd3Zic0MN6CXey1p7d6IMjToy8q5M2TVfaI848xGeA9wp" ..
	"HZOr3D2iW9B6N8P7iwcp5P6Y0JaJ+FcIi5fSKHeA2tqKNGEQbs+E7uKXAfJVQgsBiDB9L2twHplnpr4d+iH7EscoV0lkpx3/rbtl" ..
	"adbMrTZPY+yg8W+RaqcHiEkLs3eGeIk1XMnREZzJuRlzTaTYAKtGUDynOJQ9zO/YFzG7FtXE6jYclNk5qy5Fn16BnymTie4+95Ti" ..
	"c6NtDbqWTr8Q7xzpm0MakbZ0rf8g4iY29hV5rCgbCj3f6NNjPtgxe4GXFoqddoRQTvdHkg5tI1Ljpyrg3gT1lsQ7gk2IXXVZaKLl" ..
	"kZKt3dWTn1aYaZdxs90e/4qYOTB0/OOIV6Vd8q954y69L/1zp3rviuLRE9GIhWJbEEOwlMh8rLSc32vuNg+YtFuNu6kqhYtW9ig2" ..
	"8gIKYY8GFP67CYziyYTeOKse5z7gxw/HK+HnkcYrJAy8BnSs4HKHRICPox0qQGZ9ISQy7BN0oRiAor8tIAZ3GzzimS1Bqx4TbvYX" ..
	"VhJsGOm9v7iWWQZid8sECapGa76Lj1lMTofmNCVJnn2OO2WUQ/PvxvLnP/iYovFCz1iaCHwiBumfmZCs6I9zOaeZDST7sq8WQwhM" ..
	"Vd2zAtbXVGYpL6XhIMTdjtmE29zzZrbwHyKpQeBeq1w+IkiW+mRroAcLl06YmZtymZ1HSgLN86OKv9kGate7YtDOpYAiOQ5TovRi" ..
	"JqJjs0iZI2x/crfnRLqcg4uBk+XPJnnxUmCuHVgJxm52/QnzpYMK50ztCJ9kKNyxDGtI+S/znQrI7zDnWT6OwvFOU5Qpm4BYKsZl" ..
	"xIA9A3UWsC9lMGazIHMkoeiKx+7vesjcgrUmKl4gOPLuvvgYULgpa00S0lhRPzu82xGLsLuJc338GzRKsNdjYEMP+mv3X0kFW8VD" ..
	"sJOoB1eWCPwQUJdjZOcHRrXt2uvmsd42veNcAlioxoYrx/kCP1F/4So/MykvoZhE3O4V6TWmzLaAUE81nU9zO28mv6EsxOO92MFr" ..
	"BtT4g3mBYKv3sAI7BnxxM6sVdioSe42C78oeUSrj24KAF4yzO8Tbz+WnbNJF0SceGogqO2IyiSvhphcDrrtd2nJ0qdpG19hwCzi+" ..
	"BhS/83UualDG1eW4JBVInLEIL2tgqPO5ctds3MFdKZLihbzg9lPfeEuGBY/7+eCQV5diCwZLQlID0gEGy5H1EjUkwCmG6z7q/J8t" ..
	"GO9Lf/erVOzULqF/vGnxOfqPxyrR/1Bs1CguaiYTn+L8yqVarRd+Z8uW3uW+2TnMe56aLSElZQ5L7P+tLrXz7ddmOHmAxccPWqly" ..
	"dimB246ijSxRvKgWngp8SK9uPwSzIly/xWwDB10tFLS213BNSnLBS5P1GaNe3KGw9kQ/qSncN3Jx4uAO37JfUdue8FtXtsJPapDX" ..
	"H+U5aRjuyV3AHXJU5skRQ4N20jZp11mCu29RtK883z2HMg/RsIgTNWUh7f5ep2NVwKn6tDQKoJqwzFzrpcOKJD+CSXLd42+3vdXN" ..
	"S7+nAvyGee5PrLkh3UU/1aMvzjcltxSBKSATjS/9/yUx4n69xgXkA7GniCDUzHyDskI0X+nuErjPA9cyzBAVTRj824okEJmW6cJ+" ..
	"Tyoh3WVZqzRruT5i8yHGC4ZC8keI1HiPMRx96UHVHm5ZwG/LMz3Pb4h6jDoI86WBn8Ld5LgeLb4/IL3pXAtRQpujONuBjBALSadQ" ..
	"d8PNTJWLxr0QvBvfjE11miOnPeJfZXWOBsu52ou3h8+uFupMd3e2k/NA9prj50ToD/hDkis5EmKxyt6A+xTmsoVJh6bt5areYCFj" ..
	"Am8uiJvWzwc1NwOyqACTp72NdGy76m3pCU11UY97zoxoGw4Blr5smzxoWkc2+NIL0t64P94Ek3uNAFoNb0fbF37ZWZrkwX+gs66o" ..
	"7t4XTYWAfMj8A+JTDwvnMsSfMBelxDX3qElC935hwLuqXx+P7tfQ6axdEYKRTQZwVBcgqjlAP6h65eSaSBHRGLtDKtxXViok8zcC" ..
	"1fAy4uDAaJL05mhr68rdZ+UtviohdLARcKfX7kR2Wk9yg6qPgctDogBK3RaNlTZiGI7add3CiNeuYi1X+TN/hkmJGb0EkoptCkQk" ..
	"erfYDQ+GMnFbQco6eo+F5gUuMsEVC4Z/PBdIGFkS2mDxkNLFSBj+JUkd+GfrgMIe/TxfNPl5GmBWtfQ/g/x1QhkwgKm2Xaes/6Pk" ..
	"upOEIFSY7TupnKnx77JNyk+J97V5FsZYiiCH+CHT+oGKMk82e1MYkFpF74Rhj/XPx2S4JapNiUIBAzQ+N2BqAsXdY9knE1YrBXgv" ..
	"uIYBzhVpTlS4T6Ik662HroQDeT8TXO5D19XsoafYYwnd6rILi8oJR2UJtcMkkmD8td9+BxLOV92EhI6im4GWQmvRWH+nZJ9DjERm" ..
	"wjSeL/fxvJFJQkxh32UDq19IivyjBHbMlzzrPNzte0U+gDe27F7dIzb8LBr/jykn870wuE1+sI0pDZ8cJCsDVk46w1PkaUxyXYZw" ..
	"RVoyJhhamLOiizG5HNHJFDA9EApGqQjCVDO+qsnY/MIXA1zHy3ewWu7VhGtBtwuseAEmd3DzOVvGB/X/jhs0uxf+TVS/oSq8r+DK" ..
	"zfSgF8w3xZ3bK0weQ1WhQcsZg2WwkiljHhJAfXm08QYUc+rbvhSs3ZfZ5edkHalv5gnH70SDKD55eMbfhdNgzHsGB1ipcz1OEXet" ..
	"+iFUdu+hrNKtTl7t0SvQ++8sQQiIfUZEZJA+8MJD3xDyAC1FIe1Us8VV+1t0cnzUSgEc+GjNgimQO4LNU655rFxSa5+FjLcUv4h0" ..
	"h50uzky4TQzhlKb6wsqViDZdv3n5ApZdZORbB178+QMBDRcnn3N6sIrjU8dw+aFGNr2sR73/Al7PcIA0CJIDMmoKsCmBx06lhfJc" ..
	"nRgDOIrF5JP1cMRCs0VYuBcuQqcYBGRo/7bgVVkccMBSbRBkzOs3P97mwLS1EfqzHV2V5TcVxW/cyqckqdK4BMq/Ob7tH4qq9W7a" ..
	"kNEsfxd2wFxeIZ3EpDVFMz83B/96ArxHdK6RLLYFSgn4Pv1tFbw9c2EOX7r99/9pNEk+j85PfmGCdWDTI+qu8wksZ9iGHQfv6kN0" ..
	"nWl5M19Kwod70HfdlrYB8mzfcDLUgfj+OraEUoKsV/yJv0S74Uus9/L9YT2C/aV/SMfBfj8RDrEzh313pPW37uplUgQVudfO/N6v" ..
	""
local PAYLOAD_P6 =
	"F44RCCBtXKcWK+m7Nq3gVOiwl+5a3lqmm3r+swUVI6Gf/HaoTVorGB7dTNlXp+gOXGeMqPXyNkssbDBmnLFOhnZlPve/41KN9HGT" ..
	"Am9f92b1a6Ek1bhWTE1/f6OSnfUW/gFtb8EJH0lDnoLz+3MGQ+s4Hmu6E4WyUwhN6wDQmgRG0mKXHGhi1urcfTLm5DknvslpE2eV" ..
	"EgTqXyT0bVrwC8/03IntuFhR7wWqEahek/mxDsvxUJ8b29SlkDwoEa8HnVUJE6BtGI9037roEyY7uPDuHpsr1RUti0230vcOyfso" ..
	"cep2mNIxATlTcKtP0+Zj3009LxvpZoKLxK/4eXBi0UjEjcsaWLMLwDb1Bsn5AexfSvz9lCeRjQCNemQVuZEv+cgiIZiWdY26oMyo" ..
	"LH/kXmw/F+pzY2xWbiqR6nrrahF9Gvb5gI5pmq0PB5i1qlgdIvTNRIXKr/80UhYblWhJUnLFcUpZ23P94+nmNXMYPhHR2jjOj9G+" ..
	"0hX4WW/fQGhlmgBpRwhsCRkQ74WnWlg2bIqLp8xQm5Xpj4nCw4cwazZFYo6cCc18BvyNp/t02X1uQVLuKFFzy0/8cCFiOt4tZla/" ..
	"c+zHDe6+23nBPrD51uN0sPmi9muXwcxQDvqqIRmDlBAZHBZtxV7LG360qPIE0AnZ+kv84Nwulvx3Ac5BunfioAvieZuQWajVZaYh" ..
	"Y/OvPd7nHWcuMEYSFMspVNxKmKmg7k/iBoac1q42M1IKLjVd+CVIkJyU0SlrX/sv44l+J6Kybyj9oxB7gLJBh5WIuK2wPW53Y17U" ..
	"mtXg+S3vU5HMTgjF7jcVcISt60RfLXw98N3GnetNzG76be+64fj5sQIgXfIG1U1m0D/S410JjgBX5Z1OAaOdrnmp9/82BKYHB0RA" ..
	"aXicvL8WuEro27tvJhWt03KMXf5lycXJcWiCPPaqYXa12v5nJdeHVmcSX7H6Sv1ZAcZ/frxtCcF/CsPOehnMi4wgl1WiECdegdea" ..
	"032S/Q7YlsPx19/qDHEwrjG7dfljnFjskN+uEGMTUNViBfOhjC/Fs+jve79wQd2H5Jgd21CDUXjM+wdSk3kLDxVQX87QR+RMHU2V" ..
	"s5XqDHsbP+0t/vaGw4wIcaQ4Z9e0Q4eXk52MPHt2epwxgyWqOoUH+iqxqUg6svLskxL6uiyYMIFq4yhvxI600SG79SMHJsQzLIiD" ..
	"5MB4N69c/QRRxGOKbaMLXwQ8S+/Rfe+BroUV6bwsN3qHIf9+joedYIsu60WqJd6MC2gCTQThL5JMB+9qMmgp65Uq+aNsNS7XscJc" ..
	"k0X3AwYKpejrGorH7T0i5is8TOdIeIZc5gfflfLLzQgo3/2jUNhMXWjUk8s1y/z6HXPEgBe9YraUgOejXSW/nx4s7jA9e+54ywqn" ..
	"7x52A68h5wmqXHR9w5NLI+WwdQcecpAjkn0R68jykvzxYW9BTjdpMEug/hcTmW8jVuyJrxtKnnT62MACIsjQ6ZhptqvkzPeSu3W5" ..
	"nTmg2IxP7jpyV4Ao4JmCA5VS1gssGmgI0r8H2Hz+7poM6WtiG+yY8WOHZ27a3ENxMtPHjZjpWeJjpdyNxL/8m5h68NhgcjjP5jbu" ..
	"0o9bEn3ewtoD/Kcp/9UwRW9h4jhe5Ac8easSxXBhbwbjvvhWwyPByQ+igENz1ezpIUi5PHzxNQpCGb5HwUu1z+Z0QqvjLh/L+U9k" ..
	"tSz6siZUyZ9KQmJ+gyUovqCKvUkTTwYdS3N+uKAHMbD0PN5IlB0PNeR3Igve0BkKRI5JHknXWNlHuyRsaw8VH4r7rTXgc36tduGt" ..
	"+AcEbv8pg0O2s7De4dPTZvOb+qeWn1Qs/23gkNTfWb24LbbH8l+egMGkYUAa5BWqvHEq2egAObbixMR0Cn9EUzpAv0Q32G6E23uR" ..
	"7Pc7UHWctclymrLaIr6pxx6Jx1RH8dl2laAE4bxPe2xzrP/K5XxCCE/zo+3jBkRbkvi5mIfEwNCuhrb9mdu71voSCBB0B0RP9EUX" ..
	"Rj/dn+z9cyZc7HYBXdRw8sNZwKy69VvIAh05tPv0dRdYUU4kFyid/jKg840oeCqdmGh0KvgczTmw+cy/2LjGVzdYdABWOK47EndA" ..
	"1BcByxZ8Y8TAA8m4yQ6b/wzS1uDfsAWMNHuUtqCCFHgjxbjixH+aixT9+DGLoXXEDOTotXRk5xyczh9MEoEhHh+bTdkTOrmAULeK" ..
	"0C1B3uNThSey3sOul+DZmeiynlEEOGvRKNrOiWXUfY/LEaRxTIv0xXGrRYWOtER67CxEvNlD8EBs2FL068XGTt7hfzZnRrX40JHd" ..
	"vSALtG78Mv3CGbeEzLdgvCvuXczr4yjoToz0wpYaiMQQKqtGC9s0nuF5+lROrs8t+VuPsDpwQkRHPlT0vr4gMNz9WrM12PDGzhNW" ..
	"46QiIDxYIE2PRJzbuZ5IoPPVm/OaHowZHfW0lrTY8NUND+v/XwEtnyGx9u2bYVX0vp1Fo81MiZZsiDg5htvD3KHoC67mMNOWTVBy" ..
	"4BbkbIRWynCv+NFbqwHg/UmhAMWT8QUt0hgAoijKmOGX4Ron2lOrtKgcuSMxUBEUI8WKJZkrksoeCwhQKAD2sJ06iOzPtuIFXoDd" ..
	"+iy9FZjZ1QdkBnLl1ESrJjUEQRW0pk82q0HUZTg5pmeLTlM9gWIe0H+YDKjGcuiScMEVTQXDFkpBPfWEb58FPlqRhjYaqN1Wq9MK" ..
	"XDOPbJirqSn7sbybuhS9qHE9yqrB/PGUUlvimALZGARToV2ijl0oD/u0U1rCOEFjWjWxTl1WYrDyFI/gaWrKdClcMnc21IDFL+ew" ..
	"Vbsj0m8/Ix+sjDY3J6kxTdG4yx5tvBdxIc7V8Tdg6xNRfSqVIR05FpuobyyIhr7hZoOnbBFgHLQ1iQ9ZCwBUzbNZlC509n0H5wA5" ..
	"fy1WEHyVZuIY/97ES0abEmU2yG1xF9CtAVj5crCBlUjMBpyUncVIDUzIDTiF/qAbOMnzV1sdjA8ub52ASisxjYBb6lU7XKZmg1F5" ..
	"djQnQA2VeUuBpgU+6fDUxVIuIRhDWHuYFEhGMmTo4S5RBMhap1Xz9Ulf3KHJonq8tmnoXErAShKGfkl8KNAuqwogMAArEPLhxguc" ..
	"n4hvJnYpHSXSKvDAL2EG4msOUMi579iJmiZ9YVKsQh+Nw6ORFXLJ+i49SHA4qZNjaa9yshR4H13YHE/NIb1QHumB+Kq2p7Y5TeUk" ..
	"nk0dBOXzIoO7Ue8+d8RawEBvzimFS3armM4kp0Kepk28HCtemqfxQgz7KdPKAgpoC/TVTp7oEkZwnh4t5yDuNr/qeVcHaI/C81Pg" ..
	"wRw8dj7ng40McTagila1yuqJyK5tJw1HNOf/u9P36k07WF6SEoAOZrqxBbSBlunfonBHX9sVfAtn3nzWXss7MMM7CwLkY2HGJjUr" ..
	"9nnlagbu0CsFO1lwe0R/OciJJ4RL7sit0I53cP04+a1LJWQIM5b5K8g54se4gzH0DxAahFP47uReFkisms9miDGcvoX96zakZGZv" ..
	"uwKqF7EAenyXyUKlP4jQBHRzX6i/8yEt2pIc8qTbLwsvY0RyZqoyak8dIGEBZkjekY2XdVU7OksHuI34H2p8LRN3BiRmy11EJhbK" ..
	"K/PRW+M/KNKgIyBLNwAb9ndqoL6QhtONS3//zkBQtSOIsQ3Q00zpyn4Ap15vyr3r8Ce+JGVy4iRo4wuibc+8v21701vj5rRAsQqA" ..
	"oneJ91s6hvR4+iXHd+YeZgongaElJaWfmRxWeMs3ub1IdTW4TqubCnUYcqHq97CSRBq03sRuO1UAou0hp+bwcKagDyRFJGoru0hR" ..
	"is8i8i0vJHlIidIyDso9N4AJcd6BR9PzN1oU30+WMf1SYfKcWj6E6Z/unmwQJG/LHDa2+BXJWWQFtzobwoRWWUgzWrhSjyguY67+" ..
	"hPY1Z6XmIGUfJ029i3pO4hg4eMDSbAxMuxZMpUYGTPuwIIaGOi4yUeOsU2ZQ9++qyzdrnOgp2+jhrIEcnhEt9GajmTYTTAW1+KnQ" ..
	"RIrp6/T90obExcTkoUCWCVLSLbH3Qounhkq7kxAKhyzDEWR9bt61uCeospLUpxVJkkbpA7oj6rCKVq+KYUUqKBiONp32HOuG+W21" ..
	"Fzs0fgzAhWLgXH4/C/A5nHE/+yIj5nm4n5TZXHzSqfuGd3GCFW5tyhSsi8B8oru1STlEmLCCKLzZnz+DBOGqUJqKfLQ7B5cqf+bu" ..
	"7webn2gnu0ohNJ27oymAQvHFU02SYf3jXYBE77WBq2BeFk9zuE8VyfBGjmRvpOjcNbY1eySDgxDwfR8DFjQ1zL1veLGkZu/Ngfhq" ..
	"4VEDdo5FkmPzwxtiKSUxpr2I892LG9Nf7OT/FQ70W5rxlpxEUP+FWpXF/onJhFRqfv2Ljtg0spRmXEt41nKJ6LxSuMO2waT5ZSal" ..
	"kMrd9C9+K9pJWGg2JRkHdIN639MbNgcWCflvyxxpnI0EWhf0rCwxyKZRQt3pLXXJNeIsgmIIA8/MSjn8vIocqlWCN5cEnBdtcACR" ..
	"n8WZqXqlxftOwPbOTFlnwbktQeV4r/Mt5oEpmxn3anhSSHWqVjE3ljDy87G95DGzNOlP3EBkwprCUWZfm1xs2VH5pPxcsHfUaPGF" ..
	"RvXQYpRKLYV0t0qwwpYU9RMRHLKZRNguZmwlOseZgUI9ac6zzjqAEYrZKIWlDE9ICtAa/AFMW8TPVVWoD1unFxUzK4BCGAjIFqmZ" ..
	"E1Bz9RftZQMsuXy9Du763Ls6tXPBouYzwZ77adn8H1tWZpHYR0aGwF9iBynKUTuMHBtrOxSUl77aHTVGclPq8C59tqyd3Z+Kn3M+" ..
	"b8gZudFPce0yp2ED26we4ytuy6g9YHM78KGH57PrYLzzie8wx+xxxpzPCEihR7Yj2+TgIjMrkBadEhf3Q9EFCdNSyhSH/l7uK2Bg" ..
	"hZy6iECjoooOO+fji4NKmhjTh5/YFSoe0/LQoH3Ykr+lSJ8VqD37Qd1DPSPqNfNRdjtnL+UFcUInRvNSLAArxb63vlK697Mk2mG6" ..
	"1Pc8hyvGKcWE9dxGCHWG2qUCCNkM7ZjdxYXJy6JjJTz/4WhZdMmdyNykde9Z5gsNfebSrNxxsSgCoZdg7KlruK4pX7R4FV9T7UkX" ..
	"1uGuFfTB3/R6RtjWc27U+gHmJskotGJP4R/rOu0vvU5yP0FXbuENyhHPttOXtFAwRe7aShGASI0Fn9AkKRwTQzRGZWR2rav1EjDz" ..
	"kpXt0Y+DG852f6VIenL8hGSXamUV69eRRyFEYBGRufyICTgeM1NXZy4bIUmPRkM2HhigLzM37FeLWSi2s/17Pej5DXyZ60KcMZ2K" ..
	"Ap837xtvKnOdRVR7a5fTVuYt9dAbZV2W+omMAhVd3r6kETc3On0ShpyiQs7dixCaFRBGKiA7nQeDmFEBk6uNqJHSvExLVjQlwQ1O" ..
	"u3tEHKApjKGljx2sVzKTZFzo9cZIblHUcB72/J5F2KD/gppsAMlMcsCbmYP7bL1dufDTNaiMlzo5j8GtSxvXebP1FIGr7gcSkvrs" ..
	"3XKKgiAYDurpZRPkT3gpZpqMGeYGxKl6VADEnWy8j4IVtwwgxF/2Hg53IRnZW7WUR94eR4md9OoPyz0niQj9DSnhhG6jjsQscw3/" ..
	"wwbrVReWTwTRffZAiC2Pct3o+/xRnIkhesWglgfflzB/PM+REVbNLHrvlu+h8Cm5BLtUTyOlFmXZeuRIBeOjStaSeQIzow5Smh9x" ..
	"TtcI85+2CEnafrRXxhS3ArR4iMiHjOyPqWXOZm0ckaDIf69OcSAnrobgLNqqYxDNisF+Fwe7LjlSfr4x/LQoA5RTc1LFK16fwtqe" ..
	"VKU00+4sBoxQqF0SeyfqoQcY6I9xKM4HGiR2gaO9WUefQT8qRtItT9J3GJp/3SXAQB4yL6cyoaI4gtPyqrMDKJbizY04ohNdfS4E" ..
	"ut36RBpQarDxcw0yQhvRWEH+5HggoLfFzi9IKYr8pBHIhlgDnTn7ivMrDLQe82HFHvS8OgI6XTrsFtEawkH1SqsrzPw1mmHYH2Se" ..
	""
local PAYLOAD_P7 =
	"RwXWACAVJFdGmXwtvqgWIlup+PXkTYuTHhAim0ak3hb9WCfuzz0Lq7NNON43e83qCIYiaYRWgcLnHA19ORXbS6JdendgcWzgr007" ..
	"4GCmBB8BitZYsI4gSIdEDP/Av4/E+AfLulKkLBaCA09dlMHZot0VBCh8zzK4EBC7JtoklWgwlr4ytj3in5OlpZexj6Qd/+IBiwA6" ..
	"zMLYJ8xQVgteeZdIPH/r37psQkR2H4sf6IBa9Kd6qB3t2dsNvT88DK6PzABj887C3ejsIJljInMOEz7cTujZlfthuRtdYevZ8l1/" ..
	"HBN3ReYr96N9RpP7dIgtpnHPyJ5KP7Hz7lrv7VQopyXfPdzbEofc8MOawxcnDiNHANYeddI1oZ7GO3LYC1XXwXBrDkHEfz3O5BFY" ..
	"fz56q9xeAHIrUFJN6iMSOuHJJTv6tDSliuVYndJ+gREevuGg9uiIV6hEEpzwoiRlfpSME5Y8K8iBXmQ58x9N32iPdUUWOS2YkLEm" ..
	"KrZGMKfOL5kZ62x9vVpqbI+5eJjgUXdY5jJAowUupZ1epTfosHh/BVwoJm3m7gbzflS0mF54S9W/hGwNd2TYB5MxBL3UGJusQMV9" ..
	"ykYHkkoFrdmCAzw+nkgOzrr1FUM3quEl6zmJYDRXUPzIvqYvj7BJOX229FIslWyt1ZDfK0cmfH6LXtDJqTBLOYTu5SK28mBhCojh" ..
	"WvV/WXyfRJzwZk6GssyITuDCydVmQwXoAERCnV18eMY0jks+E7TxUtKAQuHc1FawYP+LkVU7vqdLziBQujUdvjy8e1A3M+tIDKkd" ..
	"sAFfVn55LKv3QSn5OFykcBcqlW6jXVTvtBp1Qnyr/w0L6WxppM6meG/enDVAVtXJQEZxarvZG11OPoZhMzSagi3RCbb1ZZZYdmHD" ..
	"JcT491uL1XHMAleloCz3u4uacfUwft/gneM1do5ZiOed+R0Y1AkXspz+8uXZ+xcfx9nBnOMa/pavSjWyfPraSVYFcR0rTt81Ee7A" ..
	"38qwrZ+8iGciS4MM02j2GS+3fUsKBCnIrK8kErm6IihsJ5Ge79Co63VP4mB7bCHNurxf3X6l47EQdSlJpnArduz6oNYHD0/7KvpK" ..
	"5pRGDwfNh2aFfFP/q+QBw32UpJObQPqk0z0DMDZsjv6USseOQ+812UquYmK0sBJlPvhkI1Mp5/0ks4OZebehaJB+KlgGl6IzuydR" ..
	"NUHI6Jl9JV7EDKS8Kol2fGNgIejwg5+r6c3wJv60nbhUbOaAFXdwghjd9DyniKhHGYWavIE3YrusFQCBYmudoySokgERydwMYzEn" ..
	"CUWDcHKDWWboTKkvgrzxrSVECgSspAqWjDRHDGTDgss9VaO5jpwHnlCuxECqO85bFXHuOdf7NQxvHkqSXMSpk+LcmA0uwmGR3/mM" ..
	"y+oFwh2mWVPvyrSJUfEleawQ5P+1M3cze5yplQTW52z7VOR7znATqa0GnM1haAHOpRSUbjxzweoGJoXk08F+lOYgRqmADn88qs4z" ..
	"cUrtC77OtTwXz6NEthP25mRXhHugvUdqTv+9SoS/PZFIYjPktM4H/z9OtlwWSH6NmY78wxGnDo0ZL89XJEKxbp338Zl5YGkOwIp5" ..
	"Eh+L9vj+UH4ow6QZXypSA2Dva1uJBPyLKxpr8mqe3peV56RtMG+Jc4D5lRtItZrVoRBlYSVbhaE6LmkyN8RT4IeMhNla/auqrFsk" ..
	"yz8IFV7QxEZH3EMW9hHxYlj3d5J/ZEOaQjDSckjY70wb/vY1bNQd6u3DkVj2YOY5T6DZI8Hb4Y5QCoXS17qsfXjHt3vdJxxg7g3A" ..
	"QXs4wgfygUT5lh7EJLwZ3jkXdpMOEmLuHNJAmS77yaUANjfsFK6enY9UO+8m00aoEXv9AjMYpCOIXSOnsYQI470BhuRUbLbrKp55" ..
	"bV5OwAnpUtYdFOuzopY3Lmb4lWouaVS97lKgJMDmfnSRKwbG+2c+Px1pZgbAc3rsUVCYAJEpR2hM4PqQZ8J0bH/B5yC8pT7nOMPG" ..
	"IiaLaeruJnJZg8n6ffXjbgwJ5vx/J0+9/LrD5eyLk1p8tyRHZkOyZ43zAwklaJ19lPTkc4XBxIHSqCzoJD5pVPEXzWcIHsZN49tG" ..
	"BUckxUsW3e1xlNzu6M48JPv1A1OzZjSdROr2SazMd3tLP4RoT9w/TjTQzOqxp4c9P96HLF5Yy67H9FWhYhRZwyOEyOC5htPkIse4" ..
	"FN83Z81vCKa3AI7aD+8lOfUTwCZcLl92v9gpU8Cba7WYh4AHUNxMKjZf5lfbTnCRNXTR5+eRC75Fvoprwx0wxXuP+bVQQelHeMqx" ..
	"+3Sf8rLXEn4pNPrqjWSdk4gqHOFkpkEx2Dw36ME/Y+KU1aEGksqN4JdTnigZuBCWcDpUr6zv8IF1M3hBCzLbVDEeg1yi0rpQpMOC" ..
	"LCLx842lr/9eVOAmNenh2/VZeLK1r5eJ/9CWsMMvv75hTOtDq//AHfv/7gjNFVk/QLTPNv59Ia9KLACjo0maQ5nI5H9NtsxOoCJf" ..
	"9BoCTgkrAEkhg35QHCbBki4vVPvdmgtNgbSPJBjsYdffN8FIJjV9XnS2snCcSxZHtnBhoo7bpJY1jBgjofuTJqtWvSoxzpbi7K/W" ..
	"QZ5UIewLsGEaXJqm8lgppy5n7YnJJ/pKSwx8CgJWAWeJ9ho9vnhgzeVsM8wfcPo1zQz5kLiE5pepP1ks0lK6SVhKaV6pzF17z/vR" ..
	"D8k2ZFzKtUbnY2OvCvm0x7Xwi1D8q1NKKcZY1sw6dsWOnijGxBiCXGMn2xev8GYxHfQCwg6RavoKldCi5E6RYkjGsrbXtm+Fv+qg" ..
	"ZkDZszXxxApVLoKY6Da8HlkVMxoLeDaZar7e4jYFMqYEsu37pVtq0oq4Z3efQScsXkzhSRQj1lpJPIvmuNNg0T4b7qfWAbjZAwVi" ..
	"VgnHrkrQJFS3OZfGXtCuTdeSuJ3ZZ+TOMNalnZ1BlePeYbBZ35T316FMWKkxvLY1ctGlmMZuXxz2Oxodmp6+/PUREH2wT8BUv8gO" ..
	"OtlvIfTm5NHL5I/qWNL1vvAAyWTMrpP5aep0uPTBmKLV+84WW9bpChYDbyMS5P2gQgUMDL5sc4lhz417bDiIiamttVq0yDmQMOSV" ..
	"/YlxXpXFLi1sGiTP/DZSgNIZVzThX3/SgHt1veQ+yzYI3NjkacCKKC6g0zTNG+21S5b/tu+Hc0ksy0XaTlzeFzxp41xbZ8vkqPV5" ..
	"7iN9+sJ3hv7JM4eeUGe6AGNK0pwOvc60Z5nW+jr7ZJG6pnK1AexuWEWEKXV2QPWj69qsHtw8JaNDkCKQlEOCU+CsCCsap7vvh1jj" ..
	"eq44gWZLVIwfQdnFdHXeVa95FUe56103sLoouHsB5nAmnAofQ9IEUqRNRsco67odzRzeFhLrrkV7or8kSn9Uvw4lIKkjRI4CTRgD" ..
	"UtdinyHPVljNr9B4WhtAvifSMrFXHB6HkH205seNSqVnboOiWPB9/lL56muZ2zzjT6uHcdLcE+yPUqH8JF3YGXwyqR/6tlYAuTOU" ..
	"VuRJ43aPN84hf32WHD+96fGuNxcWA7khtdQzVX48wrPFsQKpKYOcu6iW38oTQTYvKo/mGMvRG1GJtVR+6NGfAAv/z9q7VI3Xvufo" ..
	"RpBQLC5mhpIND/JEMDQdYuowBR7GmcMsJywofYrignU2ATu8lk65kqejByJsQ+qqhaRtAeFu7NPgDnVojLYgcp4jE2n/f7jD0/Cp" ..
	"cgnavGnWoDPwhZmAfZih2rHp+9jUhiy+HrKZBXNCpWAUUx9UeSD/J53NCTNsayx49p7l0x+KbcFFm4oAOgYL83jPvoeF9kJwPNQl" ..
	"+EeAgxfGR9s7Wq2p3PQAUPeA2xkazHk7vDjgeljpoaMINcg9W+LjEH0dyUV+URuyd7dzsmojTKQQqndYLWnfiIXpG5EMHZe8zO4m" ..
	"A1OZia3jWELwUXT1fTbbXUZ5xVuamJrqmU3BK/4JwKLAJOAaM65GTSHcp+kXJ42IPvsPJkkhOrpQG9qV+r0dcbTHlhjXH6yIdCok" ..
	"fmWqdqXUMWJG7DBCM3Sa/NLcHLHG4WOnu9GTPeI823uo7NhiYyOpPVOlUb/jRP227AktSeNC0QHz/75lUEsqkh3AwIaGsbbWdyMA" ..
	"vhkoLiWKsZSqx3l+sP6e9tbZDgCT8GflbWR/2bBaHNkq9VNu0WqnaDPJO0Hxz0kme9hJBaOsaAbV6ONw8/gZe/jMrlX6d9Yk+P9o" ..
	"v2b0RZUUJtPszs60OmOZu5HO7MayGI6CvoFMgKWANZcAW4qiIyZ0zaYKnbVGL36nNtzXHiL04PxHoCyiYj8he1sV/0Fsfq6gLUEG" ..
	"FAShL8j5Kjhgif1cU9LGUGIVFU4EZRdbCqUx2EpRrUUl3fpVndw75+DheiS29TQUxvsR5eyFTKS6HgrGBG+Gt+kDF6JqkwokSJUt" ..
	"vzgJ2MLMHaVyStxykETnROHYXmPIUWBxn2eb56WTe/NFWdH6mfvYXU6t/2qsDISPXl8brkMUbxXs1k7Xf2B+SzRDpkronSuEnRnm" ..
	"HCF65BG5pO+l/MPObAPEQh/VMGzFD5AP7IsVGqEN4vL/Mt8LzUZtzmt9OWjSGWS6MqAGvSY5IQg3nPzcLqyrBB48AFlxx7dBuVYQ" ..
	"DR6aUvn6xdvU3x2C/nuNOKSHpHjiHdZqP9qAvGDpUI+G6wb7rk3kWFSs5H4ttsH48vHwTTBF7fXP6p7WFyYlW5NzbsZPduSW1fzO" ..
	"UzhUaxdZH/UiQv2HRddbnMOGxhMr1tnKfsTgjb1A7cpitDiAr7ob5cyRk/ynpZc5kI6R3BLxc6l+r1O5QPSr4Eip8ddGVfdK9QES" ..
	"eECtiH23Z/dWkVVQU3BXW8N9SmW4P1kJ1E4Yj5u0SblN+oAN/LvjsqK5CgNAyEPdaZ+KB0QbnfAlmic+S8wMabyb3LlBU1xZeNpW" ..
	"fwKceEDFtiCzGFx9e9nsJHoSWl0xU4sVbyDOLgwcczU2+679b18VvGuac5dvfX+tJOHYyeKueV46m5WHRpb9EpOxSEIlgjrix8uG" ..
	"WjSwNmxkWRE0yLbNDAnz2M/nn/0HVQUXMs/L1U/VHQZspLbpc98dGWIWddKvIJTqH6WdgbgUdmnT1kCsEw7tcXGvlU1Kxh33Tfep" ..
	"tJL8KNbUmFAO7LK0ufqZggcw9Y2frUkrFLR0JhouionD0r6AY6GrkCQbwXbwhuEopP9mSTbhkn0ddx4m8HdZp+oWBWd3/Ae3QKZ5" ..
	"eLHf1csOCm4cnnBYf77y+VdTGJXEoNOXR7FVY5bs9EI7SWMqyFCgx1ZZspqQ9qKWXafODSEqUn/1pZcX2xBfJbJhODUH6QhU1+hp" ..
	"G33Bmelnf0k7CTIOUY1Wu2XheHAiEJ7rAmYr0lx4ogdkdlQmJUSQgnN3AmRIR6pKH7s8yeNJXmN38UZRRSSCHMoXlKdoYilcUkQn" ..
	"ycKagR9Qth34VtcOT34agoPKYfmeIFkl2B9wcNiUe6NJENnjZIZPkid6nOJBAQDZkdcqwmGdDnI5rMSQaSmo7Vh9K79u/vQiDm3T" ..
	"UPlvMC1iBykpO3+rOSZzy94kqU8vvgL5hjSvIf58nbrxkgE9b13uw7fTrnKysekURf5ska2QX/CnlKYMih56yhY3M8XI6zGRLUaS" ..
	"dkZNbxf/1uzLsDLrMJgDVr4bF1cbu0ZHKTtRvqYpsZceg0jV52CrDBuL2OGa8kuV8lH6TzStlpNMjZ5t2zlmifx0X6bWZic9WxrY" ..
	"PieM9ZUtLRH0JwvxzGSEYK+P1lJlCmsMHGebH+ay2mueiJPxvUeOrtdMuQw9iT94ojRP3rCHZN0YVnelfRLI0Cvodx+WaEhrtwcU" ..
	"rI8jWSYPa/RTenLhTdaDqV6p/to3odS+Muu3WNNGHeKVxUzU85TcrZTZSdZn2OV/2Kw++bHx54tA7ChplSQuu1DM1q+MBfuZ+tjG" ..
	"LbKpMK5HvP7wnWl3XecAQaMwWhHnt4OV2BeaCQLJycYQFb1Gom666/4Emqq8486caeScFEQUQSvb+urQDrKLXUGvW0p43JlRnClO" ..
	""
local PAYLOAD_P8 =
	"4nW3vhOApBbZbLp/aUfNkf5hW5egp05dH19Sr0Yth0DpE1DYvkzrys/b/q8oei4vZQJ9iE9nceLAr/ZjTddEFi2OilzUyQcSFnMm" ..
	"8vG6+3VzNLgnJRhkxTzFqIkP+QqN5YZuIFYK8AGPKMEnN88BqKW49AMjFZxCcNLRZ4MdgQ/MNn3n0NZFMVDTjSg01tmx1DazL2CG" ..
	"HDkdBouShfcpkAS9RkqJvh0Z+ctAYsnhvdHJOsqPqv8XuTiH2K5+Z4a1/IpDPYmFQSUM3E8KpeYJce83TNBZv2G383Co17QTYN5Z" ..
	"NGrIbu8T7HIgL7/riVrbadvULwhWwzuG7ldACX8erL92pTCT7naotK3V+FnqrfdaPXt+vfzrOVStiS3PzzU2FgI1TT/lvJmz0RsI" ..
	"74h35eLmmFk82npD4Yl9xlzt7xokuEBbtpT50s64Uz+8KWb7dwBVpS4WqXe4N0BmVxlG9VGz2RA6CCupWKyJvve8qFJUT7YK27sk" ..
	"ZhE6412rdRrUuFA5v3xiH/7BdeV1fXwEY9vDBKTXsfXeDgO1LpJmhUCF+3yfmMEyF3+Rc/n9UnGDFLO2bxQIFqgF7iqDFTfIOQoR" ..
	"4RDm3I1/kTa9vSyNKBM7nePxRnVsXLL4z1OtJ2rYVBlMYvf5n4iZdW2VOxdWn5IgSx4RJFIdmcx1Ym6xNugiO+N4zf2/y/zgfsOL" ..
	"RALs8CjbIQScBt2KegS0YZUOFi8ZZ2WTk0WYsTi2sjLG7wPlDFSJZkanhdMeRTcBrEFBjV7+ikOvrr6omF9I+RN90VEhEVqJ4P45" ..
	"KVZ9ETRmRrIFKKxqjfkJTfkQLZ3tkGPAqV7DktMaZ9PXRb0FzPh5sEuNuYOqmyF/JV0MRs2/r+M6s3gyjyoqjLg1V1EQb/5gehtg" ..
	"JTUr03zh2W82sbYnAKGvWWcNOvt77tonROF1tnSNN2/2Z9kVaNQjsarAtvEOIRMQUNIfFRg+g4x8ZgDg1o0J6uLVQiqRe0oam5fo" ..
	"Q8V4ZEpXumkO252Uv1g9KhOh1uJuq7Y7yK/YUPhAjVUtfJ+wu2gCGNJjG0GNi601T/ByT1LPUi9hWyFQxT6uVduGDEDL6ReYHUZN" ..
	"ScvlQ+tlXdLjEntH36LTPrg1nCZfUIEvKdaJOYN5EOJtnnCF4Fy8mV+8bC7VmO/ApsdfGdakQosnM9gpCMatfZYCvcF1N8Pl90C6" ..
	"LzV7prhX5E0JW/m+RmiCGtyGKSXcbqDBXxP2ug2Nyq4yRhe9MmqhPcYWhTWGNUS+1S+QB8gq+pOdNuD69R//4T0cpSQbZT9AWoFe" ..
	"jgjbE//PMMQfzozKM068IyCvOJGnQs+GuM0ZFEzpyYEX9s4RhqwvKDrmxfxzEZ89Rx8UTNR6pipAFYSinrJqHLRidrr5U5wVV6ws" ..
	"HQ5aaSbfp+rWAv8QFlAxZS+LM9MhjHFlsmWzJooEdGA9VSy1dUEX+Revd+tpAFP5o6eUnBp3cC5SHK60uyIxQqHLCjFwlIbmdTJ4" ..
	"gPTshtOJjPQfC/kQ+BP12NUiYM0GpDX39pYgd69rPDEr0b6pgz7NNUM3SXOqQGy9RrOziZ5SQJA0se8cWGZOT3TE5Ua4/ZL49LpF" ..
	"NB/lHwv5+2YJYTw8yfkFgGTmUmflk5sQ4ZcF9M6X4QJtRmiXoyOqUu+XymfMcExzTzej8ExOTbCOm+aHnPXIQygnlOh+oq9gnoNT" ..
	"5HHJlKJmP1mdjIHh5pothxfJGwTRDVF991uqOlQ85e+T9EvA56oGZc48ejRbm+cky1v4bsWm+afn5hytOdOlL9jkuQdJoyTDzAMZ" ..
	"4aX2sbPAFPRMSJjahYpD9taYnNIP5proGAuIpusox2YZjXn6OCQuB0j0CLfM1Qa0zFx7/P2/BxU2tOae4Ol6Ev9XjOg13oe70jhU" ..
	"nSFZPwD/UX5nohTHWvT3sweGqXVRmHFRPcvm67AiE6j72JEjS9LPVhI/NK7fxn/6q75schyPeOOKNxQDBG+f1pQER8MUPS42FFk3" ..
	"5bZKLRQQ6eZH3PA8CeISWdtDrc6o+dQwxVYA38lRAXday9RCkBDUBHIy9trCnI3jLM+Cf/gbH7oXkUAHC4KOPiLg+C1FU981Aldl" ..
	"/cPuexXVreh+QBAHicvNZ+14IzB4BHj9EJOVxazNrYjuuW9KoVYv4uis86D5BEauKNm4LroTIgSvp7y+ETgwU5S9HjTpTsKyxMmA" ..
	"Y4rdamtBgl5KAWqG+iyjTQ+Zfr2rvurrbd2CCnMCwGTq51MM3ddyr5YFtIY/Pys+uQZvNi7F78p3P3AyUdKMvhKK0aiYqQIWX5eL" ..
	"52kEOZcF4CXhgXfBz5WvzI8iA7HXY1rLsaanqpED2LhXvpxvcV8X0CX82IBsILZ02pc07YMr+mdz4Oh9V/iM9csoWEWwkeX+aO8J" ..
	"ADzaL7lesqxTLBOnPo7eFI8/W9lfv0PgoHf/RfxEMO/b6N2/otIXTRlvm++/yt1ZOhcXDkx/F1BMmrMR0Q7wSBsRFAxZvcEke4Y0" ..
	"s5XHaMX3sTcsMscT6CERVLH6D0tq+OzVwevYLfx/iLR2+kpLoD2n7mH2mHoIk0bb8yKJfGLy/TImvibr1FCEWfY7zCWPDKB7YlJj" ..
	"Hczq0XoW4w8TF6LZOpGEVrDVjIMFHki14mfdkTFC+8b2Pkq9eowqj0Ert6PPP1ckJbDT67xY+Xwa7aUCK4OUOip66MQ0IJs07I7b" ..
	"8nYt1oltZT++/8Xmtl0EccmzKVNcUZ/H1SAC3SlrdBnRyk7owlhy+S9lXwZEM/RTf5zFLq/OSrqzWlI8OfxZ0sHPcIxJjpPtgyM/" ..
	"FeFUVblzd6w99iLUOjamhpEmLH/m8Rfk9cG51YjCRt/Fd96g8aEfSPdGuyB8juhz5lRmJ+QKMya+mkZ1qQfb4YyTO6bl4M+8PcLS" ..
	"czQOnjcuVTGZYYb6sMe0As0T9Qg6BnAPDAvacV8uzTYendKjgtovw4mBrtm4fUakpLgiZJ76kGOAfL2mowD14/oNQ3XPIJdyZ82w" ..
	"Tf4NOle9dd3Kc5EiiQmvCXX7BFtsRKgk3e26+FmYQvJndbRcATOELBZDXOa/YjvPC5vT2X1bjwUugFa8GqbvDMpvvVZBIuGtguec" ..
	"OAZWw7x0No1uMJLqEd14utAH0TXou3hy1vdBBTpMkbRPtBKgrDaTKNIQRKyCdiWqwxgXxAUWWCJB9bbCnDULC/oDTDv5ZhG5mEyN" ..
	"7QxzXO2lgGhqyJo2f8CD674dGbdpsjQBOI7tkpnY7Frkt+52XYY+1RmFfXqEHm20a0mopkicWYjoKMqrcxkEvhtwElDrytzYvodC" ..
	"Sx+MDQuFDJALUN4Kn6YYIuO6hkWhbhCQDFi8ieKmB44CAj4EmgIyURky1sFLor/I4w/CQQuvs6oYkEpMMp4MrVlS4T/VUyKkrZCy" ..
	"KjRGQs1odi6tf+r+83pyCTJ028MhT9YcJZSqVjrAb91WFGnvO4KMiYrL7YKnlKwrhJe+ZHJVUCOnuCYexJkdH/1gekSO0zssBr4P" ..
	"eHjKCjVEeJJNwBdVVfkzw4yKBNEEOyCwJwhQXIj1jE5RY+vizncIBFZDwENFo6IAkuMCfYNmje35FqKB0JOGm4dCGldwAa35VIcB" ..
	"KmvwgVUKDJ2INZKKnn4k9WrkC+qpuotxpBX1TnyqfE2uwzr9gBJntJ5jUGk2H4sDXOhyp0G3CdSavu7UeyZgfO5e3ZphegMr5mIb" ..
	"VVRsgNHlIy0+SnjG8KdDGWcxCSbYlfXqO5Zy18FzqdshmM1oZysLHpEHwwouMm1SKbElnOz2hLO86pSpC6TaizwBOEqM7aEMCjdu" ..
	"r3epB84kr5r0ybTwvZhdak/oJq2d1QPsiEfOAbUhFpeClUaRhzSOQ5KE2+J9ArMJFQBoBhLPjtZn3pWtCguWx8EL9csaFQHouPaB" ..
	"dnQ2KtVWekcGMQl84WgrKTn4VvxZwfmijX2KMTKvwofAt8tRJN6QOeC6s2pL51aiM1jLWP8mWXb32DPcxRALIGuRoC+fWlvwfnPO" ..
	"tqrvZYQ8Lm0FrnTG5Z+xa5crpb9OG3WYj64r4wCfQwzsBs+GrkjLv5ByFDqcrCpOlyUCqwZ50UOiIML01+JhUaAS9lgYzxp3cfkw" ..
	"b6scwcpB7+PQ+vGTKsyK9ehk7pHfVtELfMCxqkcNppjrMAOPqFsHYR+vmPp+HN5j/+VK5kUVKCeSS0JE9Drj2C7sCQxVmW+vynMt" ..
	"jzVczWd+52Epn8ReUiRoiUeu9slbaETfkISNsxpyaIKGLp8GeaL3F/uSM7KmrXdpDV0AEidrpgEnstp6KK9nCObhZtWgwwAYwep0" ..
	"wuAKe+0ShMnZFF8I7VcJddkMrDSjLTuGcwkmFKGnPjk20Gc81E0t5SoXuaIFPeru4igFUM7Qrn86L6ACQug3e+Zz8epPrimoPpxy" ..
	"3BuNfJcxwrTslOJkA9dXmpEYO1K+MgYeBBoXQ+Q4NLtTV8KlWKTeHwlCVdYVGNxGyoNgTDl3JikBLXY+FaOl9kaT+aPC4eX3iral" ..
	"11XQCTrn18aBCOoYujDZNnnNeZFKTanwyNXcX4jTx4uaQJArxr8sCsyCFOFgx20vuO9kSvxCgX1iiRivZzk5rkTC64CndcnEBGWO" ..
	"wm54JIKH5AQwOmMvFwIqjvZt/Qj8tUG1UmNmkc4bGbYmhrVOtPEr0Bt+5UiEYJXZ0R4YwwvkPmZeCTMEYvbyaA6dFmUeplRyuInG" ..
	"A7bVy5sQhXcObad8dACIY9UuhNqa+AzEUiL/tk5RyR9Ujj+0Y/0oIAPb7o9ebvA8qXrOsPtVcd67iPRkrPZHA6oP7iBW8dP6BNO2" ..
	"rGUcyyICSAOQdxBkbREI9+Fja2qg+La0n0Cc5d2fziwN8DtiA4rR29M9UpISkLMH7wU3MekVFl3rosS2YfYKGpEcBGy//Qy6SCii" ..
	"JwKKT2VTHl8ZrAg7eCxT6yi+8sHyJ6ixptTHTnGAQOFG8ieQDqpHQj658lD6WBrBAHaORVj2nyOHONi0r5OBhyEELe27LhVL0taG" ..
	"rEaER9niJIrpr1Nx+2zx4ZhtY9jv9xRgy8pzdLZNSk7SegX7mmpYa8hQErSGQy4UMjNMilT+hEY2cFSlCVJso0ejq7nuFUtQecqs" ..
	"OkKGusNXUA0wjNtxAneRqXCXxvoFLtT9F8HibdtDeLAKn/yKD+IUoyqMK2JGhrqrSjarvZvRv1MBnNLby75EaeODC14uuNiKeoSd" ..
	"5WPQmN/mosLbeL9oS2uMwYP8YZo6j6q1ay9Z3ax/c2Vedf9CQmOhROJTe73cqQJJCKwRqmXgF/9Sz6PMAQaYsskQ6HXghsFesX/N" ..
	"ub/fNNkYoObM1JULEAN3oV22YzwUNQHO2BWZL2tpO/XdGHNRaLmo9DCGgDKBecSBY7fQvIkPkL0N1COZvl1IirblhKNsnOT4qyR1" ..
	"FD0+kLefaxX9p/9KmNN2lcYh7wbK4pDn5nyfJntxYAuKiHOxCzSGR0ZYxaducZV0kFOWL3QI8+SN+K6pY6zuAVPLGbmi0waIaxIV" ..
	"IIBL4wORBYnFnNwDROlvPVGSULQSyrQELvHnAOBtM/M7Nv7eBYy1wRGYNS5tO3jOfrdOhWTR4GJ8hBTCS8T8zz27l6G/gpL/3mQi" ..
	"t3MTZiBljQ5f2G+3dJoewGWBCy6u7Ax5uZEAHL784brsyDnQKUVqnWYdF4EIUvlT9RzRFQAnJdiSkR20YEsoOoAYsSA+hjGcMVpY" ..
	"nbrUT9xifFVM5lT4zZhZo3H43Rvw1G6n5kq4ckn5ZBCtnmFEFYqYeU78IxrD+/pDFHwnhCK0erZ8xkqPxCv+QgTZxwivqgrIgviq" ..
	"+63SvsI6LL/HiiBXp13Op/E1sSzjBMwLpsRUs8mHtFMX4d6Yyu4q0IEVwoMNeZxc3wdwbdnKfepwph5I6/hm4+whlAjVWX/nBc5a" ..
	"z30fet23xte7kGUmpdfQPRAgado8phvwblgj3QvKeP9o0ypIyiq7aclVGiGAMKxNWcWbYhHp7xC2StqgMjkru+01JJaC/5a45uXh" ..
	""
local PAYLOAD_P9 =
	"vwgp4WNHCQ3qns3oex9avIhL7Ar2FLNbzUQ3JAb2vgpFt0OVfEmPxb7fUMlfvz8vn19PDM5c2blgfchltKEvVf+rCJDS4XoVRs2V" ..
	"VkLMmsIKL4h5Kkh4VVaa4a9ch0h58yxHoaAlWw+PRB0k++4toNM5iPpCI0c7WiS0QIVZ85hVDoOGNl6DFODt7ijpJD8SvZfX1Esn" ..
	"k9nDl9AT61UlTPjwqVWSa3oHv3oEgNVk4fBqHuDv4y+F3jIK48+8k8PPExqO7Zn/XUorPw/D85drS82Q9Zl6Bnu/Obfg9vuCSuqU" ..
	"+0n/CjvoZEzPGhdesaZThPXD50eHXeGD0MyMbWuB9HBYcRuyNVEWfl6fG3LFJmdTiUuHoAKVjT1lp1fXaYsoYNce2voXgxSHqR1t" ..
	"WZAl+7FEsHUatVxJHiOJ/gdWUpgvuLS965xxMJRgvdVgXiJKhKLLeC+kMaKIHNb2mFY4stMEovBIt0Sz6K5cmgoU56S/CYFy/eeT" ..
	"G1K0VUuV4oVNkvOhA5/6T3k2gcxVae3Z/X5f5eKOzBb2k8RwY8kVXH9JjdsV9ad01i1A/+LN8UgnyR4SO3gZMv2a/Nwo5I3FxHV1" ..
	"NuJlTtn37ipVrY8Vmj+2n2DANYj5HjG1D96TZ05fncbDlE7hyP32Sv+7pZAe4ckexfRpo4LN8kKchhKk8V0ukUqgYdpCPFwmwhwO" ..
	"YRPDTDoJ43WBhydy7I9BwZ6MH6JR8eb2u0eCirwkOq4prwifUL5vGOWvEDdVjaHsHGzx+475HGkYP4oMnTQSIbNQL4dlsXNMM/J2" ..
	"cisalEQMM0yip4WTprzXjC7CWsRrBi7jjxjkEUxWJP6u5eQqo32/ktLTQ7uNA009EUkp+iW1Q/L1c3gidJB0kbpmU9z/Nuu+sGkG" ..
	"fZfP0QHnPC6RsllNW+kwJKLuAk3trF1nLxk4kG59lGlZYm62THrsJrW787mF9nKozNn3L5wvQii2ZEkiG1iEexyitoYVEWgUdXGJ" ..
	"2O3oGiuB0aW4OrKoDKZMC/fH+ZLNRykSZkr8VUPXLMj2UsVPc26xqQk1zrbW74sWtqhqBy0mq8PcN6z2H4A/jivXvSkl1+8pegQi" ..
	"pwlrTnpLVS7HmhMRyCzYIGS+kuRkrN/2TuBsUgwmbuO5C2PdML1l032HuGH+N622kSvZai2YF08mWD0K3k3Fv3kKQIHiK55nGNHn" ..
	"ss6rEJCPOlC0iM430KjjbdgqZajZKAtf7UI5rA7nIQ/n77o7u9BFa3FgL9GvWjtElzUZzFfMYAVOn9ycOEg9vrX4iKu4zNrTofmo" ..
	"FHIrZYO8jFStEugbNA07PbFWyPsjSm0Cc4Sem4iOzBgxDLtarSczFYgV4bb0SVd1mvoSbyeXT/e6psdRcpltnFeOZ3KL+WMFU4Fn" ..
	"aHxwApP3dG77Q5mqJMhYyJcTbWLmQ7GqGdnkg9ENL+eHiWg2k+jRIDYlWRv8ys87EUs72wvFxgymfz0EDW/pAcsxgBQDVqHkdkXw" ..
	"Hgg17Yz0kw4U3Injqasashgs0O8J593ePI4GxC0PbLApBd78w1i+0y6IrqWNaS+CeEsGePVB8D52xYptcu8YDziwfo5/gh4BdR1r" ..
	"LwtfHSd1U7flnMa0z93o0WtC5igJCXyOgOqsiUDWH2sN9FwHsroognhe5CdX7YnPtJerIyijizbHWAydb73ldyZpWOoB0rK8pA1S" ..
	"5aA472uvBI09V8KhdhyOrmU9AbLtHLyjuEFVgner/ArZ2M320DSlDYsfPuCN41noU3ymGFcFf8vI1/xAEa5Htwv2AqRFueUB93cv" ..
	"sFai79aXSxWTEKVrLMJF+6Vk1zTI38jm8xA/FVuxpQKK4rOmYaLXhD1dyUFYNKuxpxzDL1gbO3yJyJunYxmvrAXJGyIWdjXKd4F/" ..
	"jRW5EucusLbfwQNDUWFtY55ZG6YSHUt+HZaliP8v8upFlzXti+swc9O6qKCvBEsJZMH5otv5FD49Tw7/Zkwoz3t4frDpRd43MGmy" ..
	"MKv82VXG+WFXJ8ILchesWQlAi8jsB8TzX7x5MwAdMLNBpVxW9IJUA3dEzdghWH3Jgdg4fjoeVO4zfgWL2MrF7KSbh4IM+pfn4VnR" ..
	"wDDNTNamWbOb6TFXgpSNEFUojdY+mjJUI0GvA8A1jtMp1sq0IM9khjb43pwC9lysW7WIUGQs6UD6L0mhQsBr/00tEkWtI9K8Hkqa" ..
	"XVdAOwqIcXm3ysKZrADvZgQ33XFIIOoZZ7Sd0Yk7OvrywZEFfmgAp9K/1TWZyQG+4De6NNzblclrELkaGE8MYTjRlJFvZnc+XLhq" ..
	"PMEwsNnrfNE83L5ftufltpKQLXVARgzLQ+mnvVOQ+ahnvLpj3/jgxCRAZuUr456ymadUuzSkrm5PcmwAC78mtr3QsSlJMhhP7ElJ" ..
	"qFJl/QaOMmUggS4/dwP/A4gteuaz0Kqf+Zk6p9RJWJ44kD7AIFck6SeMhyo4YJ5QaI7hs1RydZaS7J3aYVJwya/p+ywFDfe8DUBf" ..
	"pAZod1BT3MIwPa3ZD4bDhBfYU/Da6eLsjfCSu/vag+YInpFYZpSM7rU/0bKbkl+Ym45LhEXJEFqwm2m66+Bt+OXQ5HNOlYYqRJmj" ..
	"9aYyQtZhB3bMxu4MKpE3un8gv8hhpWrnhXQpw5FhX/cNbk24OfSJ9TyLEjUDpmch+ofd6oojxG+1ifEQgL59Unc/zesw74d7CUVW" ..
	"HaL+BI/HesANJIGMCzwFEHeFJ+bB3WvR+gZ64LwataLjYdC1dvZmBBfI5NCcsEaZJBDYqGVnNT9khAi1l3DCLm62PhVRQnjPIKn6" ..
	"0wMWIM1+k72pcISwwVoLiOLLdnbEXHEiQBaQmH0nyJmCvr35KYMMJxoZvavqWVM40fquxsZfP5b5oIf+RkQ+3ONzkowOdPLOhe76" ..
	"wxGvWij6FqBMXN5b1eoPv+/h7BCVid0Udj45DCcLBphHUk4K3/JVvQVdkbwbsHnI1Vs2xNFd86hsq9uvWNNnvDAQCYlfvEzCKYNL" ..
	"6kuBVCQE522mLI8DiVKemsg668B4Zq7AVIVb9+eUFs9iCz0PqbKrNrrsvJs9G/ksPlJ/1bQaHlVVxvJ0Ydh/U+BhEUmbhsfze8H3" ..
	"sT5AFeJnB0K16fjIitPzSbNaG4+pckssl7SYYmlXsVXqXlfhY7w4ktfcn3WyG5ZLs9KQlhFIrY2d5XNYdeY+DKg++qFNUcFqLit0" ..
	"Z3c+orykLaB/c4Y0QrRD3yeG+a2f67U1LIHO3ttEkRd/fYoIOWU0W0IUTBWqr9ZNOpYgT4WXHa2GxgpIqJtgbn1ngynzyirJSAkk" ..
	"rdffBpYF/nsvl6vr/rR3KSud4g1zTN3v4iItF123t76sH8C0jX1HnHQvo3U2fyu9Ta5Q8xD4+Ug8RuqbA2kVkrN8wzak4R7PWpBn" ..
	"AZIVl6W+18iZr5UXQuqcSqd/SFRA8/080DBn5zoFweAFB2l20rk3ghU6PQRXuYhK/1xOmUmtpT9UQf1lwe7Cie+9QPFEalX5u1kc" ..
	"Iq1v+EBHL13f5oWLOgriI68xM1TVsyzU71KFka/1yDkj0VQDQkAiS4kAkHQTHV/22D2llUuWuwVCA8+oLS76CV11iNnHmhe+EZva" ..
	"L/SfGli54wryLwU/UWfNptk2V1Hf7ixmZNkuaTJo6QWL6pUKOBHk0/IfsycpfKwb6cdUX4okkFThX5cwgxp7mdROJk/4hHtSVq/o" ..
	"Y5dgwKnrGUDWKef90HhYUPQEOvHjfg7mtQ+ViHUbjxZhxmKcyJ8Bfm3Jfh6uU36OHqVJB7qnxFOuq75yvlnE+/mPXnP/CaYC6lqQ" ..
	"R4Fk0IZpUcR9e3ADniIsTVNFnfodmEB+sWd2Xn5GlPn19BKWqkyT71aLEpGT/WOT0utmzQDN4/uSs8Wglf6j4s2piHdXjoYlG+7Y" ..
	"jOFy5h9MP1rbKUTw0RWPEi0Qq/FrlmjhVPaoAgiWJvP9L8OwoHfclFEiImidHcJA6FMWLxrpsJ+qJNgxs1IihGVlgG2jpzTzqwIB" ..
	"/Gg1tkd5Rm9G5U86FupLOCj1Qm/rMQR1ZSqFfoTGRZ0q70BP+257qm9xsyZIe6S9hwGJPRy94jGuV8t2mYrSCl0O5BteKxOqg4lU" ..
	"b5M9Tx5+QMI1KMWjVppqNU82jms5kjxKCkp5pBTUTFwi7DYHGv1wEhjloRmL7lLiQpBaStgxq+PxpRGYlGhiFGeDZ+wKdNvHyruk" ..
	"WFJ3DmcdGevbR3DEOwPGUH5khOwU7WOw1+EBimi1qAMO4hKWllcu70ThUd1F8cxdmWJSGyXb+YwL45+kqEUPUIH3X4qSi21spnGN" ..
	"ZTobUDUXboVS1N3Md0w6yu+xqocYzi7a1vwbZZ53yEVdSr/D+SiNdjM4I524QvlzkEm+MIKwCArSSEjA986mK/KMtFCWhkbtLEjg" ..
	"inZOiUOLbidR9M3N9ugg7Vv2JtvtS504N2qJS3tm8kJl/W6xemrRNuEsKsohO589neevVGKZI+vDKNyHE2pThrgqJ5uDP5LqRyub" ..
	"hQfrjiMlVTxmk7zsqDG04Pmwnr2t8nssXQviyNHbL8aQF2a3/9Og97cRBTslMJ+lDJ49XDFHIz4S2F0xUenGuhTadg5WeSzKQNjT" ..
	"/egR8T/J1+9Cya8CKd5fak/AibhRZnY4CFo6EdBnJhUqzGxXXSmTnnrH3xocIwb0rwRO4roJepj+UTmzMaM81t/5MToMMFQutk3v" ..
	"dLaVW4qyqx7KtMmpbNavmPOk/TOfTVvROapjFskkRdqcOaLBN0fbBRres+/AgCtq9NtObLc18O4WjRS6rQAvpaNwkdSA23IbHlAJ" ..
	"hU6eyFFpaJyJUsBrb05x3A5gH29Xzc4WmeGHG/RbFODvwQY2hnCi0pYTrtKBrU91lbIJ41Y+VQhsJQVKEJ7ZVzzSlh4gDF/Y9BfD" ..
	"TTDYvFdAam71DVmB5NRP3iVyT0FYJofN3wITrPm1o4udUa7+ED3xlQLMN34DNuCriiobChATwKeHepKRygt+3JkQDfaB+UnrRKWR" ..
	"d3PkSqAemPkv/0smtu8RARFqRxFNO9mDxVZcTYIo/xtUQ+Xh/Jl++ZvxuFM4rWbNA+u7HUzlbrkHwMP5tNcS8bDKpmrbZXyJ7Mf5" ..
	"L21UdzjeFi+weXF1UmIipw3qNc+sCF6BNZB3JqWlaYFgte5gJI228AiPNKUgbxKUZISfgczx3qYngxouy1cLPbvA7teFjB63tkyz" ..
	"jjxU+mHUF7lfB8Xkvxf3AuviHLApdqWfo5gLHNSZlg0I+hQVDjkaFs2iKzZJgqZXiho89IGcFSW3ckyKfastUI2kj0RAJgbwEwCM" ..
	"/+MWUiDqVqZfazjQri7d671g4jE0aCLBWOzL1ExftuY2o8yDryF78KlF45DN6ixBUXkrFOikU7j5nyEeDa6uQUzvKzrrlAaiT2L+" ..
	"8bCJZl7byrXaetukP0Jz6gMLDck7NWBZp/KWs3XcwisT40HGcBFQpp98jJaeeaUsFSqXL1FsSYjy9AufoXGR6GVC7yNMrhyjQhld" ..
	"vF2UbBdewZZNBMPAIK3gKRpY3QQ3pYgCTAToqDQG9RHrtKfWzZlkXfAr4V4/q4i0NJbsaxwN/xi5AiMY+MJNG+2kSjWR72kdKYBJ" ..
	"A0KZ02peaW8ZqBCXEFhfQZlGKREId6IStfsOVcHqJunPGC1c3XYh+AIdQnOlaXsDjORqWyldja2iZEWaqBLBikeTCcxuzEormMEA" ..
	"XroIlhe+v9FTErtLhYV5h2Lre9SjomjpdVv4nOcuj+I/h4VU5p4ldMIQIWvTVRYPLvot6t+Tzji/FY1pbVvxTGSmkH6adZ18a8nY" ..
	"DISQ5V6F6xTh5ipBDH/w2k4Vz/1tXrm5CePbijfkU5avK5fKxponS28e1VqY5WAmrkUdYRX3CWWW/BRDG9VqqcE6pzyIssE0fOG3" ..
	"RTxv8J9u0D6mZrT+akV03nsia49OuQceQqleNEdElO1o6ZDIfEXPHfWEti2y6e3v8APS4tUA0MhhracLOdurDUZnL05R0fup2CtW" ..
	""
local PAYLOAD_P10 =
	"sDqK+ezRCQ74MUBpNgScNGOO8q2LQeg11kpR8yWMlQYfZ2NFHMMQt0+MxVzZbxaRjNoO/nNoWVT5LO4+xP/hQuImijVUxTYYQqDw" ..
	"i0yPgrhl+7R3RkuoDAmF834GDc/F2YH8WNlXh6RC8kf/D/CJ4dBPpP5gdi/nDUKzh8oeBENRfQsyM9MmcRtH1lHCnJYz2FLbXuzQ" ..
	"OIfETjY1B3lIeIN/hjVxAS6nd5rhspWpoIPx5mVkOzEuNVxykeJxLmIa+0Nv+DqhIrKgLUz7S4WHCcDgcZCzbKuFqmtIYPP5ACne" ..
	"CyZ7i/UBaHdJgQhjwnfupyDdsX6Kx4XchApGYMMzv+EB8eb9aJu9SqHr2nPbm5GflPOvjiyvvMgHVWRwiaDjtYXtS+fEdKt4VIu6" ..
	"sOhRHHcf2jEKfp8v++q8SaqjL7cSHH1fHyha91ghGzFIChrVui8Df5cZCn0S93SDNb6L5R17XK7bGikqhSM/vAjjbONO27fYEbFX" ..
	"uuuYtRUhKf9a9WBfIThYUJ+dfm5R5js4oR1DQRWka0MkfTfiPKVHPRz7uW9AdAAkv8rD8hpGrQLnsgWcbtVUw0P/ahkjzruz7/NQ" ..
	"B4/TpfcOYIfICt5Qb7aQGuN4P3SH2UWh2VPuqDgPmcLeTWy+B4hc0e7eGrdytCjNpHoJxdTOYCIkt1n+szZYkAZwYzlSq9q6TnJY" ..
	"td3P2GVvx0ByXGqpfPmtPz4A8DP5/CXFCm4bQrPwKEsQMtyTL3cg8RhXXF3gyYgAX6KAtLvySMe5twDK3F5aS2ODAimKJb2YbOao" ..
	"eNij4gHaELXmWa75/XNcGr+Qg+j7d2TvC0Vykv9Uzml04QNYQ/NFVpWsTIra90xMT8JY1100yhUJIdOSr4f+/Jqf1ni/numZryFz" ..
	"I1lBfCPRBvXP/AbJ+3Jy5xFkLkyQx4KXUpZ+V1Bzgahg+X0lJjVhTlQc3Kn4Jzlh/WXRLaOhbhTDi1YgxChLf61BGqk842XLLEM+" ..
	"8C9+EMIUDqTTp/oL60hP9Q1yo4u9TZbXd91R55j9xLIEnodEaKG5OFhkPzjI1+mgL1mv+9MdHT0MG4j+StwyW/53E5Y1ADWvI28b" ..
	"W+a3o9czjEmwZc36+JdEofrtLWlKNiXNxsvtueQKT5mTB/1z7fv4cMCpjzZlckBbKiaydpa30mDEHO6chpoHUXLMe9vvIRjCXeWm" ..
	"XKsE/Py9eqpYRe0TRAk3a4337EfhqcUW3ijgY68eJElcINSIUeJR2jIQbz3jmUxC+euLLwDMF29MI037VPZBz+BAbvf3sJK9u/pb" ..
	"VMl+Jo6w9R3ptUBblh9vRLO9Kuf/0cY9UZ9KqRQy9awLasRCOcxQb3Ul1lYsduStDZuIRboAQR5oxRs+Llx9XPE+7qyWKZjJiGsD" ..
	"bBtQvbIkJkYhDbXf1xuo16qrOZI9vkLlfonR9LF6HFrDtlfHPUu1OvnOVRQi6QaWBRrqVLxsr8xSx9Wv/DCWJTWqIC+M" ..
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
