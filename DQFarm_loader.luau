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
	{ seed = 1869472966, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1863681232, exp = 0, plan = 0, hwid = {} }
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
	"zpQbl/AnPbev5ZyAZh4UpZLyQlLukY6ErMrnl7CmTBH6gzspvK7rrf2yXbeZcdiiL8my16e/D9yUVmHaGFu+7EervzFV0wB90rzV" ..
	"peUWYl6GxsOXnWBfpa0Za0YHrz8K31E1wawnJ19ipJKfVhfY5qKk/wonPWI2aainzP0q5zhWbf96QJ0MXKVaTVo9bQCfh/pSSLkZ" ..
	"GCnQ6nhvy/1A373Oy9s1HBgBlgRQL7tDNfhPl170wXFuGip6aZk3qgE7tFwn4lnA/llGuZ7goXpkMFSCuvY+SrgJ+X9Exu4PFH/i" ..
	"BeNRa3hFLATD7gZZ2XAP/RpiLhZCKn/u2wmvbUfRep3G1jH0m8VrK1UBfyGGKpdg6TUx1+j4BEOAsCefFwbZGKXNgVuZGE6NiShs" ..
	"2UItf7ziSj+FXDHCPlRKrVCTv8a3XBjkOWqufxeAmGSRaIPCaBz9b4TPwAz233yDqeA+hdQLjmhQrlYqatV2olehfem1nF6ChBqo" ..
	"fdYggIhrfJvEYk863B//CYHudXRd+Z85WhPFiZuZFuhCtVdzWLJrCjQtJtW6iXwT8FpIyFQ3CRQHew6i78lx3ynkNF2bND7zD86z" ..
	"im16Mxq5DPz9NymPcV6afyq/pJVnpjgrDbWBGrNKNIkP5YonwcO0i3kERiYLFhagHBfXWTd+7mSPq8N8iVPVldlAEREPTG/F1OdN" ..
	"6RbawnIVmgQYC+vB2RF8/chuvDzjPtjTjOrkMjaidcOVWcadluzPmgTTS/IPrrYqSm/6dqakhF8atpQMgyN32AnHygiN7/AQhUYF" ..
	"ovu4db2ad0A6UDjxCJR7PWP8k5zINf5pgzJMB0jlifi1LsdkqlM8Q9t0JA1d/KsoujPWiBGuej8/GgIFD4ZWsOMXekR2kLLdi9H0" ..
	"OfBoBSo76g9mfqRjfTdVtOFDYYB8aY5rWF9dEvjUyj0WR2xDfrXbHK13btsoaGCvFGgF2iXSwpWjZYOJPTrcpU1GdAin7/+s6QWb" ..
	"EbinYdeRM2Uo1zimWaxRlMDAOMEMx2FCNfehvyeAGAOG80mYjezfT72VrncZ5SehA/7unb1ih4e8B/DbkwA3ix7tAFxO+otmo1IL" ..
	"0ZtQBCQOXFs/gHDMgDlr9x1D6J1D6yM2y1j5V5dRAmhgHP6E9TfYfEAE2e9d+Nex7lqHpc59NCtlxsfprosUIxYUN96lDCv4PZLs" ..
	"f2gODS2cc7jwheve2D52AHvrPbLK+0NGn0dSGw5Xmi2QTMTdRMqSSX4HR0W+BDOHCrlICZubmbjguY/+kJjscWm59Z04n/jhKZ0e" ..
	"vSk5HvsOhF72IBel/EVCQTjB+hTY+ogJfB/RPmG48BYslMsNISTcp81wBopBe1L59OCqq838CpbwLGiAOECLqMQYjdRPFAw1CWzs" ..
	"MvNTXYyYB7XW2kpCIarCwHR0Rdw5/lzWngtr1eR6YDVmUCzYzY7JQQ973FUy9LZVkpnHTItaXTlfRAoa9pu9aZUdv1HKH/mTjwIc" ..
	"suwATbIRhx47hwCVu/RAPoXgp29MO0GhjUqOod2SQdFScquzYmaXLK1cgGAscfhlKgpK1jJQBf5L9Mjva4jONETMQo2gnLxMaXgb" ..
	"rKi9+XxiIS1yB18tVowuvDSnc2CcLGPPo81/S3sp8lazW0hV7eTOqjtnjI37BBKLjkH4Il2W7P5BbkHOL0mD1Fva0ksYqLGzZpw1" ..
	"OC5g0ZLmcPyH/ywLDfAz53aVJvX/nah6fbwo2vqE/QE9BRMhFJP55KtcCG5IDuoKMdcExB1Fw2WTeAssC01Yujn0VsfGt1fIWIz9" ..
	"TAhCRF5PkwO1XOXMxszdcF6zeQ0DARyfsRJAFy60da6hqxA2Lw14HrjdTIycfyA4WwKKTs57OMLWKqHzmkIhVEv8IjfB1kFq6Ymw" ..
	"JZ3DXLyfHgnsho1CZVJTEJ54pzUj1/qrV9ysrCnVbrCxFH75nMP0CvRdMMjKEM6Vo23Bqx9VZiDmZXgrx/9hm21MeRoch3GLBJVV" ..
	"XWPAAKOmHj46VRHWomHSlFmG+GgtVC7A+GGIG+1BH20vbHy8CVetoqBOAF+/3hKbyIu0ENkAjxjUUTQLzsOrIOIrxo5t/p4fgkTV" ..
	"GKEAEL9hKV+Pk+b0z5Fps+qskHweHzeskyT4/kb9oR4JxKMRcHQ0q3m+X/Dnxn0OVkHPragQhqwvwfvVqVJDVDQlCQg0qHv/Fx4X" ..
	"+iGU2RuA9nKYOhCNjs3yBDjLMrRQyTtjbXAJz4ZxWHIyARYBp1hBE9B4uffFHhopyFkqV6u/9XTUT4XAMv6Y0FSIfsL/+FQg3sby" ..
	"UxvvpIdZz0s16lK62Gr4wFF21r7OzPnQLnv2+i52dp8YbrMgXtlceJxF8kwQu8vWGNSrKuMU9QkDPfPgnkJmHrn4/QUe+S3biKTr" ..
	"/56Aby5uxx5A5t4S88bI4yWo1lmH0OHb8VyZkeLcRADWqGXW8S6M0HH1oTgtIzwOMbPZgIBWSjgDXGnwp7GMGaoNzKwgQNyhfzto" ..
	"aYZmTYSW+23EePw4eUHyRCD47ZbObMvTXogOo6IXU9BuQgyFvrXtBmlXetmFkClLRZk7B3kLHMws515hlZl6TGE7h0x0KHyivbWe" ..
	"jD+ZJVpszJOw0SxBMLD0I9dPHOw4z+gWgxWQeLsHyTlr0AkazqptK6Dv3ag6BZH9LIQdYm07OKNVVC5I82VQFyKAdu2ELCvRgk5t" ..
	"ys076wDFZEfqikz+FiSfx50nsavdg15cezb7vgG0V6sO1xrlsCP0WPEqx4vKKBgf1LEz5ljmuSyDjpxZcNmQ4G1R1A2LXC8FeR42" ..
	"gWXj9hSBniwo9O4UMwhaUHlgqfdWTIRZw7iyPaHtEPX0bMaOflh/obcIlTWDSBOh6/2DVHYTsTxatA00dYEI8Ss9SA9DMkbM0FzU" ..
	"XovHLrwi0SvwYPvvq+0vZxF4tSYhYL6KFpUvHPz6cpRRDbH1v+1Q+yyWqRbeXa7M7PdELV1fd43iZpxoWFvpXvlad6m4nvaqmUZb" ..
	"+KGoSXMPrhc9fxX5Pc0l2qdWjEh6RSKMtbzkJ2ghplw4ft6s/xzKSRcr80dyl7ckI7EAjkixEFcyoXCdtJb1Ev4NzdKMRuQQCXLI" ..
	"34xdekFsrBiz+KgoJMuIFgyINfbRcmZ8NTL/CQSGksSELz2/8VTparcqsv2+yTqoPqs/CRZVnI1TZAm9yMhWJTnTprzYzpx43t11" ..
	"YB59Mx53/CfQ600zS+Rq8WMaHYTR5NXz9Zf1FEHyTA5Sxh8N5rswFyp2cjk+T2kkyiJ5u0ILoswPvOHHegnlqOdcPg3dd3SAphBY" ..
	"3oND8NAN0jj5mfJkgmyY77d+7cYIyq7rv4nIXo98H4xgQzNL+NBmy7rz7BtTumNcmggTxpZXjgqYDEFNFsZp/dg94/lfk+XJUhYB" ..
	"PILaDGJVI8illnEHgOVL3bVVnn3ZTnCex/R1xhGFcvslRBvsf+65J8RmlA9h6ZwQeS7PXGyutUs3DtH1Q8dUBkk0lSDbAmWACVuo" ..
	"As0D2ziEzxj3bMdVx+jQzi+92mF4Pc5Bt71zMazJbzleDVdXV9lgFPAz5FpEDtmeR/V2ftJDj51zsiguXFcHXmv5y6NWA9x3qHOf" ..
	"TkJPY6MjCQvoMUu0LN0wNfRRdbAxx2MCPxhjOnDgETP8FX3doyfQqk4crl8Ry3CJ3FXXfJ/OfvNIT8UVSiugKDguVX8IcDXYJLSD" ..
	"Q3ksdy7GRebT96VvTfOgaByIVPSPkREXvqBLZLaLBx0gzfmVWs9/hjf7lZSGbPo8EjeGAnYr7KKwbab1fFyBeQaDO3zLwnExyTal" ..
	"riMYscV4HGc17Zci0sUGpj/Tqdw8P5CfNcKXZXVmg/lr/RmALMqeM4Np+ZNQInIC+4aocrWfAWTN5lKuuzB77dA2YwyujHMHoHWB" ..
	"r5ozdgeqsD6kntLJCzshCtswEbT0vD0ZgL6halllECB4LRMYx5cUqum53DBQwZWVJ4RpQk82YCyUURNFOMC45QjCQ7Ep/W6CCbnP" ..
	"bmlm+13IBZT52PvnWkRp9r9aku/8W4v0L5NAPW/pHfrPR59OAMVSU6KQCRZE42Z2HK68ux8s7lck5gBiLYha0rqApy+kCb7lv/xp" ..
	"o6ydxq8nIT4lKtq1957gKpWkN5sZWdQaTaMwbQG68MZngiwRStlMMLhJy0juGhrEp7NT68SIz55Zx6/w65U5v74uMBd2jl7O3XBO" ..
	"fstpSTuuGk10HDcOL3f7EOqmg+x9t3p0q99B8c2mQGu9uVod9NxyOQ7m2ZsPhZxwuDTME8P5RwJC45cO47ogNidwI1Y8CDMj+dGU" ..
	"FCk+FTYR0ufOxkAKLCixlW6cj5eBhEshdTVA7+RCaLLHTKefsM+cWc7/AvXfT7l9vhnjlIfhhMNxZ9UGD7ewR0Eh9kd7Kg1pSTwP" ..
	"5yBu4zZ9sf15OA86xibm0coo87WUqJJk6OiZDpm5dcUoVJffB80rEStc/zUnwrQTmbdgukeq/fqLEiRgKrxt1H33t0WyBbS44JEh" ..
	"sEEjOFRcetyKXw3IDwnDjPwxf1A3ELCfx4/jQcTzN86xWdW/fMb3n2JOHMAO335T+zQravHoYEaUPrNsXMn5vg5qhyzn6ZIIZDr6" ..
	"L6UnU2NkWHpMGc1ZsvUeKNW3xIAmfG7+b7GrcUNuCFGX0E80XHhCMXiLVWCMRsojlDnctkqs3XeEuuXIdEADVmZ3PjwcHjT4+bLZ" ..
	"NIDUkX7ZhGg4dVzlNg37V/6IHJ23/3cCUR6Drc+3F+sk2dAnAznamysyf8tfOvIXLad4ECQZA/s+xuu0obV1qv8PL00ZrbbNce33" ..
	"DvdeOXaa4Pn+MYt3UIfvQOzjEhFSqF81YwtAZ/0w5KhSi0B3r2Vj/SNo4TgTv3pN+vyQE7C+zMCFIrXgg4XYWTpDFupO1TaLmUzT" ..
	"AgaF0+OprFI6w5MmtsnlCBdbb0OTxR0GV0hpcVjw8cXgjoe8XslWcWyaT+OpTXeXBNUbzXt9FzbzfCp9+mLfXoikGIkEb/kBR4JR" ..
	"6UWoACrsM+01syCMR4hA6lR3jwIr2J1aTV2OS9GSkMrbpnhVNBv1VXuHJ+8T7p1OT34ohXpYgJckFDpKKD2yMvahTrk4khgAsPsb" ..
	"vaJ1jF7OE3AqNBWt1JJm0MsqyKBwyN3ZetSq1Or16pPLrnktqeOEeI0yJR0PkwCaG/ebK5V1b20SeLis/Pw0xyY+19nXifJ6KxUs" ..
	"I5L4E5CeCGLv3TxrCepwni13JhZIH3VPWH/7Uiq8hP9nFUuwQ0MjHqTf828Ly7NQ1++Ku4z+Li5FnS25jU08xNhKBm1YQXobYC7X" ..
	"RLoBpmG96//+r4Ldxjmw67LVgKro/vnHwLP/zYj/9pH7E/YDfAtp7E9INQu5XX/kLxf8oLBhY1xSu1Sm1UQkWqXAodvJm9cdrSIx" ..
	"drhlSUwSOjTaEcox/LgwM2TuiICGA6G0sNMzmGGDtHQ5itkCczJV8SB8maHzgaxc+r4TLMrbeO0hMRqAuyG29K06iRojkUsekXKD" ..
	"TZ1tmACx4p7ZIdvOVmrMffVbF6oNgQumKc0eg39YtGXTSGeW6KIUwGKxEOtJ8Un2FD7rv+Mh0I59JROa0D+sxITHnhtYez/Vacv/" ..
	"aQNJxt6yCqk9rGlDUbP/yEpWKQHPrmB/f1gIJIAiour4+FvOTJGXk3/iPefNJet5Lc2DC+f70POB+QqrFnfgInIWbDpYCTwcK24W" ..
	"ipmQrI/bZpyRj4hGpqirnzuaE81QfAwbB8EMNdPL3hdu7QRNrgOpPHOmMJ5gjXiGerv7BKZbJiM0wUf6qyspbTJ+tA9OppkpSNvk" ..
	"vzAP1VyODQnDuCXa9y3R/drvXQaS/KCeZpPaBAmxgYrSgUIXDjuw2ToanbQmraJ9bTUNKb3N9zrAupkYFl2MY9YVfmdh7EOtKchQ" ..
	"Rhot52ER52XXl04i9lypKiv9DnzfaewKQod6xYKivG7kLk9rPnzxUBTr/uramuKIvcnV3gL43Jf4aeVtfLFAebDXz2pX4N5PQd2h" ..
	""
local PAYLOAD_P2 =
	"krwAF7C0hSLBQ168s7FsTQjLq7gUBEP1UY5Kvn6swbyq1NkgecXicb5WPNQOWkmrUOTMyTCG3kT/+lYxUs+wnzUrJYS33vigwKkp" ..
	"jlwQkQbQ+XMFy6/6mcqrZ11YqrNCYE7ltvr8Cl9YW2GTDPkybN4ydLo8abnUGJ2/iiiVtwagsUIFUSuXrJRfreB0eRU+Rluht/Yd" ..
	"cP1kQ+BXs0lpt/2gZXWA4OjseYW7eAS+eLTYmD1UFK1HaVj3KNLJsbSJblq50S5l4yF/k6unv8DGwvycV+rI9NP4Rcy6x0Jrn9ce" ..
	"+520y2B2fmVfXgB0WBSYAaA8/0ts5tqRQ2vvxT6rJ49X14VDI68nO7gxDLV0N3FWncPUTLfUqmt742ej5FDAeeEKQ+1o/LmG9Gcg" ..
	"5Da4Mejuyxgs3eT8IVCYjXgeqIZx9qlUIeBGFLAHY0hJTPFolCp9Vz4taLoDWqxpTwZN9Pp7Dr7Uew8Ydh5gj/EoiYl5SeqDZy6M" ..
	"O2NeqAKRJddE+y/LMCy47tAmhtrN+Ht5ViT4olFCopHb2JypkQ+8574NjBlq6sMkwPtQrpHBszJz8RyLUNrFEZa12DWe3tsuARXM" ..
	"MqQa0nXvRrO7eijSDFFhO6AV5rkmEnkSqKxDjynsuFJTwVhimxvd3mC2mwmbf1hYxtdpMyOjES9UlJHin4LZ9G2sYP29PpZCvbuj" ..
	"qkXjb+UNKftEMMHvBY9osvbEa8EiqkMBTL0kJIC/Rq39EkgTaLnSFSvkkcFcmApvVPn0ulp5fcC/mwOfZ5Hsu1rrRYCHwi/xoxfc" ..
	"+oZZc9wZ7u0jQ6J5IpYYkzcLNXCM3SHtiili0P2FBC832vFkQfelKW5FjdlykCMN8mmS4KQFKEF/NGCsmqA0CgwkuAdhedNIgXA3" ..
	"ceaoKFNyFfKrk5w6M6x2mu/eRWitlizF2JFQrBNqto2SkJpIHVitk8dV3AYJsTyrHCZuMMKCBamhuA6+VTgcRpZWgEB6SBMiMzNN" ..
	"9uCw+R9hwYImXzBNwGJYYaxV01kZyTHRiYn4eMIg4cSr8oiSRJ0LWYJCqyUzKHZM/1UJpbXyJkCrEKTPrZULK2T3USVT9ZAZO9wx" ..
	"S3HR3TTRqSfKda5bbwbTRkT7yIrz3wI1z6tlo1Yd4lMBfy0d+XYLXZUlCOFIbZGzFciaahGwmnWJbon6KT0/8Jt2tReOcyFzPOi8" ..
	"u26bU25WSxfB7jAPr00PfUAfZAccdTawSBBE5/n9e91WI85idiTuTcSGaYiAUNwBlacb39a9kEvylyat4BTasSN9p3/rHGIjWBrw" ..
	"rIfGS4QJg41h9Og/0f4zjydiRJaNA9+Agd3/lfD5ExVauM3M5xu+3pXgP8YCfk9ovb4Cj18S7BPeBKt88m5COHMvanyC4G2kWH9D" ..
	"R1iIqQYrMXiY84Z03YWovRboeGuUEjAxKYMFGCuDbj9vQI/6T1rNv2ca/VUVFYJNhnKuEV9jIuKXomDTeUHiu4o5rSA+j2nZOeCK" ..
	"KMj2DRqnQIWjmyotfgxcPUSL7yC2Tbklwo/cQbAf/bTpoOVxOsTTuA2PIC8mZXrIM1zyd8vHfQpt5zuyMUiaMDG/9JZuoM9/uZUP" ..
	"n1otKocSAO01lWZqYJnuHko4ylrizgFHflMrMymmgvwIdDTVnB2HVnaWTltnW12rA+X6EC3B5irPRMAq3qNY+vk6HQoslYRJtghf" ..
	"Kx3bDHqVGZIos4jXwyDs1TTcY4wbxOSBPHj4Q8dYg2bQKRPk09kbVqKID4CNheg9Oy5ma1depMgsQto6qu/Txl33FQvpoBOdWzEP" ..
	"GjFGHB8L27xJkeJ3+VrJIuvzIIJ1UD6pCs4fdN3lfcmKyyPXb4KW23PFLnQ024seyYe0vOW8TKjA/fI+v2ReJ+FNLL3WPmjX44ES" ..
	"POv9t4qx3+z8LWSM9PHLppRaqEd5OKp5u2nu6Fy6SgPtltfIzklQxxoHGQ6ABgEaGdc2RMw7kdRKqzRzSyUgXp0s3Up6V27QAbr6" ..
	"c2WOaHW2ZUjdWv49emmK2FsG+V77PZphX/yk1m2hm3tcsn/5chSbcpsy9OxcesHt88q8DAVvAJbugn9pfM3usKezxeLd4bmQW2Wg" ..
	"rwGxROLH+9bhCXBWwH/t8xR6H8O/adxPYqgo3Y0thnZa0qj9O2h8/n8GxCgN2D6ufk9FAx+SEue+5uToxXtBq3u6nBZhKZ0dqABA" ..
	"b6hCwOEWlFcZbVZ22BsQjiFKNv4jQNFltbimtEpAkoM7TLh6x8NYDPfDs5FoDUJi+bN2pJ708/2IsIbQX8alzmic6r7T0Dcmsru7" ..
	"/iGbFNeJV8Nt/WUlfoah1Tcwl9jwpwY/HVtKgoQuIqjDbtjg1Nom19C6KCvLAdjvQNXdTT47CzriNpRKp0ILb7X2rFcESWMPNxiZ" ..
	"pmWB+svob4qOPlV5iJNPW76hYrukyalBFr4BOOKOr0GZeaxOEpnYR8QZZdQW9q0cxnuFy295/hM7ZquX8SemsOdZbnBDcogPKacu" ..
	"VDp6eyltOXSsiR0NiuCvlQSIthegjG2WTA0cX17eXHjfC9+tR4v7ZNu23BTA8MtOw9SHFw1wGNuDcsQr9x2Al0+qrvKS46XuLf4w" ..
	"iS5/4lgYgBm48UTWy5TWi0g6jNsKHKmciEtVIcP3Konydoq6fn3RNxeerfK0x0wPPyqJaNVSJw28O2AYxTTFYPagyUZx70300YkI" ..
	"7b0aw9g+9CARe1NtL8IQkIvAuO1AyNIwKOPMoMD0YfvZk5/RxkQhPuJx48UZ8YASDsNMidFMtaUAH5VnuKQS98CmaIxS0KlzTh7S" ..
	"NZ/u1kOBWdHSI+2+687oYS9rpdCoVPX/qdT1XRGOhFNe4tmpMG8rDqJMV2wQM50vUV46g1P7E/bCTWFaMMVygIGXsmF3YKQVZ+B1" ..
	"pauPxxnTpA11EcrYudQ6FTstiW6kHQzBqJOe1M/CHngreCttbLtTJm2yAlPliURdbeV8uu55y78ViSouY64qugmXl2eKY2L0o644" ..
	"/gRbEHNimdygBgbC7FBAiTFyhoTNNZnXp6CX/sXw85EzZyI5uGPpGrYUtPYBUf/BbG59SrRJuAS0TcGkxe6gOCk3Ob5mBGv/vblg" ..
	"bnRL0pr9ITWDqFmt1SWWDpVUn6bxl3EG/Clr77/9Jqxh1X+43h/5xdAejrTI+ftznXYntiBo1gcmEQ18W8IQT70J8tTXdQo8RN4h" ..
	"w8PWiKfPDrncCPhwzn/hFMRPOrDZ4LkICf+uQp18aCnFS/+afrvV4jNLhvAY2Tw9HRirie6hCt2Wc+FDVTpMunlabwv/v2TlYUoI" ..
	"RU2rqoO53bssSLgqZO1XQvYb8oOx/oCUFPesR3RbNxPtILZW3KAJ/XSecQI+4DxTYwGKMDpV6zHQcwCur7ZLjLn6RwGB8BkgfVr6" ..
	"Aj6f4eb7GO9WIvcKGg5TNlnkzpEZnkVwAZR1J13M/K0EzB1bfsJzzYTxF7gAOLgtpuU/GM/gE9KYEG5h6dJe98ab9TrCB3KDZP7T" ..
	"n/2mmojKV7zV6NXduXVe9/cDuDaMBVJgxC7Xxa0i1ni0xNEmOu8JcSBnRBPrY98+oitSbhI0bes68g6E5Ye38gAw93t3GxVCA6zN" ..
	"u7K7Md2Y/PjQwzO0YS/pzcoZqXW3OMXoLSZAcA4HIfnH1p/ZNnVhzyU3EHAEomWjTY6f6Vlls0vcOGi2BXp/0LxiYM6QyOCn6XgB" ..
	"uylp6ebGg75wjSLS5l+VJbMVTWNfwBqXE8+qXOmcOYG/zgLDCz5RAQXyuvyNNRr7zYXa2H9M1or405ZCOUMntzz5Mh/evnPyr2sG" ..
	"7sVn1xi9PG6TKKjp/9yf3uFqAZlN01GGwv+72gTp11LGA1PHtmQO0r/6QFyAqppL0qY4rltbczcrEnXRDUw6Cb+CTS2Afyx9XQ/E" ..
	"PULUqYLihG6BBv4MX6r8IEdxYB/9HyIqvopZRO7tfX7RTfXC1/cHGoiWy5QtTbY/1tCoHuClr4tlNHWwL+cRi8FgiF1zZEMG1eOY" ..
	"GEiWkDd7nvcvxcWWPqIH1ezgGtvf/dcg5XnK/7bpymvNMHPwZ3WO90EeV1BCyLC0So0GB2Z66or+0XJa+Gny3+6SmbLrgqc3H6Um" ..
	"vV7YpJT0+IbQlfdI8W9pzZwryTbJ7/lGZKPaIEq4ygMp03XMNwF9DPAhAzV0hHwhLSOH+bUXfGCLnUojmPMnhbLDTB/nXt4oUUko" ..
	"FhV5Z85Xxc4UEDGr5WzxKIuwQlGqwYkHdLPxQSCGOPyK7z+ky3UPi4Lyv5sbY9o4RNgko4mDKVzoi46rDtoODe0uSwsoqxFjoohq" ..
	"2K7qeAElFXMaZ1s9hKXuhxaK+BHgZge8GmBr/MEzKdUPZCOTupqulcfRq0B2AzS/MMDjTtcDEgZ3CReKvaPcBTjyzazUMnTG8oSt" ..
	"4ceXQ4CfVS4tU/ZimnCk3LaJoEFthoAV3tD0FGpZdyzxR+u2VB/nL8cbQ8qpDW5P92VDzdBAz89xq+60sefcyKmTfqsNdZ8qU3pz" ..
	"bKBj8+XmuGpHbZ8dGaDAfEnrGpvK1JmRnbjaA+o/FWBZYF/B1q3o0MZAtt94AcFx0a1rFOrBGSTIcOMcp0FrGZqBTMQCfI9V4p1G" ..
	"Jj+RS5K+hfo2Uv7hZfMM0Nafc4CypESvhP6SF39YZRgc92TvLVoi1QIl6YfuY9eYZl/37qh6oDfYIEKdOVsV5fmtMVYcyW2Eftpq" ..
	"9NcUvTku3D7AwKB/sAOGk8I0KFshxpZSOjhJkdd+H6AETTKZz3b36uMzokkmYlk42x3Mrmwau+OuYwp47BPY/qgy9OO9PPH+SKL8" ..
	"L1HLECeCzb0R0rKrr5K+Y5s10vJrlqiQtrSAwF8InsObZW2sE3a9aOaBIt4995wWU4VOQt7IG9u1g6jt9yA5Zu5uGdPj/meAOq0U" ..
	"Dyvjq7cfPFo/yo7cpjUI5kQtLAbHmaN0duW9MIJbcPsD751jhPNWlSc1NVW1idj3w8E8wv3/L0hp2ZbhOO94TSnyMAXmR/GSegqQ" ..
	"zGUECpgjOZ0czyInDD+HHp7RmFi6rEdDgAAUBqsj24S4P39dO71arkg+y/J4nPBhUAbjnC6xFUN7V2eNCNbfXcDPxjipekB05SHm" ..
	"CoPSntVUvZ/m6HKfhLEWDUdjWBaVoOHYlVYuppPdLR50krgWcIuVr7Gf2WmGODj9GxcPZrzCh86Xq77ZwWrpxZlQfzg1vEe2QMO5" ..
	"IVNRyuTevZEKe0YCEm+f79lE2f30q9jOEDm3rJMkvZOeHI2R2yVk+XzuYUeQlNs4k8ARZpzRNjFZhLbtI1QhMiMsQt3z7qla3jlE" ..
	"+UO+VGUhb5qJ4QnD259ZrUNu8ucjh0PpiBq34dKxSQyiQ9V2j3X+cEx/5V2iF9WnNuWAxtmMas9qeElAveWFeaXvZt5tbWLyLArb" ..
	"dCJcN89sGW7GpWxyA7pEJCxmbCtEd7k8OlQdCoT/qG/Hiju3M1FPwEB+nGZ1aZuGTHR3tvwlQoVpgwcu6/uIou5Mta969vybOmBG" ..
	"bWEtwiv/fn4S/TeJLop+2AZvjHmdUBI6GRbWqu1LbjdVVqovzMfte5SttlTMZu++CBvIHfW6HOQnvNUozuxEDBoBR8euUCkWDxSr" ..
	"7c3XKrHEE8rjGS9wsQSAB31Usp9Eo/VCHrZoM+vkrVafDLM4MePTgndl1OlWTbemznzhnafqTQOWYj0hUsMbU1IuGlK0MZ8QBAXT" ..
	"56Hg3rNRbkaw9mWkozXoqjGYeuor/Z7qWKVZyJMbreqz1xC6YWRf5zdNdqnyUOF3LefFwD+15l6+f/sebV1k1ltNhpHmTm/QIZuy" ..
	"XrQQWfuxEKd4rWJcptTzrAo8jw8faDVvqG3xnrUOqYYuVXgFb06sHGUFhzQs/ZyEBJN9Lm4W8GK0TGCgXQwkZVyjZ6cH9Bp0Q979" ..
	"z2ZGmH157vNlnF21O5XTNKKy01yIpcgwsoCHQebzGfgpUGorXcdCseIbCSzURLCF+BlYxDPPSGHKCLpbn7uzYxuMZZXTqrMWl298" ..
	""
local PAYLOAD_P3 =
	"XzIatBREuzHKNlMDZBtpZ+9u3RPOM23aCnLJAMDtU2DUqA81Q8RAv6ru5u3GsE3FoUqynYl14q7KWCrl1DLo4V/dzqPNun7P1HUG" ..
	"vCbRgPWdSjRxAy5wDkeUNdUz6htTZRB7qrBcwJmAvB/KD3biLATl7q5UqZ7xO4TlKdnblp+J76P4r9rJWKbQA65WNrB9txv0jz6H" ..
	"UlDHDLjOZaS36/WofobbN5GphIrQDqFvDBwTUb5zqwcWnxv9Oy7qxqBzl/H5XrX9guewUvsWZNv6DUR8razyRELtaPIjlxJUQcwU" ..
	"H4eC7yGHGpOmncil0DT7qRC/I26TcMoJFNUPYNxirdeVLUNZtmtONnZomjISmNZGsi0u5I//1jD4o4qpuTzrF9VMxEoO+wOaItpU" ..
	"dLl5h7MgXelcc56+LJeke//dEZG/EI7xabvFCsLCtEAwhvrA2jwRoXvU2FtU3l1yN1Z9zeoUSmNGpR+KWRWoyM65utWK2tEbTv4V" ..
	"ms4/N016nZb/BGfsClOq8I0QcjzjIxqwJpdS1ynXU2G9s4wqSqA2NTwyW7ESIdOBsUIjNy6XQfYnHlPUPIss6AA292VXTBahIWwp" ..
	"lX2O0CCZ3j9K6vajwpA71BUl6ig6ccxHJ6Hs/agpLdH+dZThjvB0WPVY/UMMzvHSot8fR8CDm3RD46TuqrmncmgW06JCcyU8nGP+" ..
	"1vFSZGhONhc5HiLBrnwCz/hgVhzbLwv3crFxcvOWuLqkCEe5EyvK8ASfTTn5LqOt46sfabVd2gPs4g6NPsCgX4oWn17szkUIR/7H" ..
	"Fq6fy8MOYvMznaSxDZmp86Xr1HZk5Sn1I1LQxjn0894lscgT/7CvhbmQGqSIHK0CCYKNMLBQsoDYD9nhwBDnZsXHYFwhVtdfwKpI" ..
	"vFYzbrDeI5uGwGV++zRVkDrmduuQ3kxdfZm/i44Bj53asMqfDMT2HGIEBBpDIOTIkScNjWnFn8n7MtGJaYkRkzACXZy53/4qbDJl" ..
	"vq1DwkkS3klknvCPblwp5G0A6tqZ3P6PautS4caNh/ojTkPHu1vbtlNIYccibw4qKLxGbruKewAtAm9hk9wtpAnSDhZtc7rgjC+W" ..
	"N1TdzplFia7v6IqSM+JKL/ROHEVpPK48Fv6RSiPxSQFiVsSs1AK4L9y9HhwehZBnW7mznYTFKivlzwRoYnP33R8KcIiww9EPMRmH" ..
	"vUAdOuAwQknFTUTjLpw+6dMfLjX10wKOiPVbwDWuAKdoO2tGdb2HC5OMCP4O/UADHWFpTz2T3p+bhSyCquuCZplHralAXR7+rrk8" ..
	"IouSSsazaZm2eeyXGGl0okHaUxHGcKttQ+yFPqlpqi/mIBiIAmM/s3VwAWfyQFd+NxWUzXDJ/zqel3KhzNfpSTrZjS4aJ9nTrz78" ..
	"IOC4RCm7EyBvk6a0yAjIt3PaaK4p6+TkpinmpA5pHfwhD6n7SXmU9yY30SeR78S4VsquEM0xQhJ+0TBqQuY3YVPRlvNF9f/FSNC0" ..
	"JFvtepvZ1SBuX8x4xQjhf1nlftkngSONz/+UlG9TqLGLi9Wlk+N3vx6ApX4y6IVmPfpBhwUBMaXsxiSlWepHVdZXPBsn3z3NamTQ" ..
	"D+mzBWI7KW14Mv2L7jooXppc1olSmf7gpLhbtdtlV4+23GI/7XeEN45/61VPONI5HbOQglk5yi1pVHuA0Mu71qIkwtOS6fPTBaxP" ..
	"ZGAyKurMakTr8qW7zHP5Ld/dsDO1uOX+eC9p9NkPWNUfTz8Kf3POlojR2PelZaT6rXwAMPXAVcsd433hIA4Nh037jUP2MUHMpPcE" ..
	"VRpHyYyVUxhTvxinZGo4VavBfIZ53zYq8yR+uduTLqAbgIiTSEXhhlr36JrqXjhUhqQjAVb9WXstVTh5aMkg6QT6r8wIHmJq2+pa" ..
	"CoZaCrMoLtX8HNIkAOy0Sj9JiRxofspFpc0KblzaUrEyuzWF+13Or5NoIDy0PRk+DDrmnElT1e7fYD0fs2RE9dYmuyjgQpbDdHEF" ..
	"8o7P2WZjESVXjKEroRnSzyaIbQUkm4LwVId1th+BhS0hw+ix2BNQJJ4nvlcZyTwFxoBxsWWtb2xUsPA16X02AlhyYuk4/MVysk8k" ..
	"O+9PylUrjuynmRFNtazCCL41ZToT7Ry8ycbl4shIKjULEzlpkoFT0rJ1zYtplcPNUHyTGHkepvwXKdN//ZkbUOaNfFsJ/F86ImeB" ..
	"ob+WYPA7MnK9I9IhVNVxQwFPmJy+53ijCUS+qLbMlQVmtxxaEmspZLpJ23CdDYBTEaFQFZsNgNbSptkvfIfu7qH9GQmHC6x8SII/" ..
	"m1R/9nJ/tttwhUwCcOnURku1Eitv56dmX4pMoVcka8TzaAjiK9QkO+RA2RxVgjbGmbRYv6+rvFg8kO/oPAONCB2nr819JS/DS2Mh" ..
	"jO2gbB28b2ilwubjOXJZhoAwMQtuiv2UsArwmLSvAqZdSev+gwYVr6hi0Ir1m0vBQXLw5hamKj+OsA0aPaxbWZiQsVI+gz4CT3jp" ..
	"2KuaZSgAYUT1sjYH00Hza4O0EIfyIHFVHQSrL1Q3A0vM1mEPlzmiMmIXb2UztV6V3fRhYfRT9CW10nHEQwWeTN2jClWiBFMuRnr0" ..
	"r2IH+xVW9KqBtQQXqPEfvpZLJ87qXtaLwXXv68OTGCofKFafnxEFGIo3EyIgncOwfmF1c6R7DZge+Eq5L12KKqMFrtA9fOsrGsIY" ..
	"qPKSeM4xqp3DavaRK3y0VvHOdBuu848dQMvSPIIiImiQ1H051D2sv+JgNqZ5brgM/57tpfSWaS9e2YxRyGgb7AaTu1fHKINleNjd" ..
	"la/5TWtQVQqXlYlRiJmJuU3IlyxFgpUGJyjaCDSkGFSiLrBw3MMqdD6ZUT9LSQtGaARZkuncX2rM7qpxI6cEx6OELVy8EdxRmFaS" ..
	"X3sysDJvjZJj6rVp9j7UIgSt3Is8y7LF5F9PnPbLqsDefbfPw+xubtFzLQ0CCa3V2WWj/UOzIuI7rojYITtrH6yWtGJe0NlL6B2N" ..
	"Vfwkm7uRVnc6gdgkwilSBe5vdiuQ8MiQio4/USA1iLYauY0bzuL/WaoHMYtgXP6auhefkDaj9bP3UEqbYKF0r2qATK3d/qb5lri2" ..
	"2CXSRSzDLlxJJhVT1kEJlz1wHDqLUx43xytgggPYdR4jZAs5f/fGBiSzn9bq4WvxzugwCcZ1XdAjVwGyDy5JBks57JoirqGv87pk" ..
	"1bOhAjMrjz0choKeviT9oN/iaJIpelUwO2mX9yipj9XC+at64OEeXHboGcwkEhmJ+MYq34RORHn55u9OggiTSkaRQhgQu++sGyEz" ..
	"s8s7v0q9EQp2s9oIJbEpmtrCUXiH4GnjlIRfqHSfqPQ2IHlwCOVdTkYeHjhXSU0HC0A7Wc8CZCd+UGpXA2JH6hebTIj9KQ2X13oW" ..
	"oM+fnTr3/Wx6hW0OTvAxYVX3FhyrPEcGnOqCSLYIPQBqPtg1uYxC1+hOWpHP4Qtgbucv3F+oBWvmg4yURQagHsTYEyRyaSfjWh9c" ..
	"nmxEHhVTL5Jl+7yps2x5X9FVWc/zFLVN2TPpq/o2v9rOW8ha4c2AZHXmwgRIxHoRk+ZBgFdqepoLcsm0s75TfZOyt4KSHAvqQjd4" ..
	"6r23ohyLiwoXsToLkZ955rLv/SbLaGUCEgldKJHdUDryyXhbABU/zbHRgom4ZcVlPQBqL5tNBuwOJkObMRAbnEhQRk5HbDR1VsLg" ..
	"sOYfQifjZa99GpBd7ix7s7D9dfy9ii8o0Cyh6cNPzyQuVZn7RrTCmjx6lLSp5mNA9CQ7d/nfl+J6Z6uh1r/jE+QcknCmD7tpX2oN" ..
	"mp/gBVHZQj0bt/k8UuRL56n29Oe4Rs7pRxxO6IsDQaBmv8Vlfxj6NYoHPlDbT3va3AngMuyHmYFNtk+JJgtAMMTEJvXWTjZK92WI" ..
	"eqQPh2F1SzocvTc6wKzX8CAj+y7c1c6t+o8eUtUhT9ZIEyeImD7weeVIPwQ6ZmOJ8NjorAaVseNLzcSRd1lwcW0l9Dba9rYZ3vhg" ..
	"shhPEXZJtvGATi9AcLILTNZhfVSD90POMmorxXvPRDlVc+D15GeA0HLfvDHIqfPqcrmBe+E8FyEIJkNFbm+syLGCpnAkFRRPK1Ww" ..
	"nXc0H7oUA6UGehKCmCBr9cF1l8xdtbYNwj82MM6tuR2viOmgO397KNIwDbrDlHuLL4bqxiQ9Or5x28V6Dfqyh9tbO+ygsafbZQ/F" ..
	"P++W6wEy66cdB3K7uUKVXM+RqbZCrW+sVuWnmQpmWho6UYESvVWSQ1kpJia36pnuFVAT8sZ1sYO2vu1SH0fyaeIyhsDHdnTu7cQ0" ..
	"qkYfdYQ0CbESpDddyPPug+reA7rPmw7cLrYFrEcFrwJXQHF6TcjtTt7q92hZDP6yUEP4ucSJIDIlU3yWJloqQUxQcUBAdN59xz/4" ..
	"g40aG31Et/edwd7e/n5a8vag4gGGWGsFmSwErJxxTg3jgdVo2qZp8iJh99G/n95F6IgVWwVmdvT3ne0nsd4K7KIJsgYT0LHOu8CX" ..
	"U+ev0wqsOdTPc9j+o6bAokmsRkdrpP759uhotNHtbCBjVvT2qsj2bNlYdZA0oAynXpAy0FcEPh0gp/0WVPVCyL+zUe1dw+TW2Fzo" ..
	"TDbY8ZGXOBJpCZkj/D0Bd0F2LwuDbF5JklIiCJWkFniP6czA1K1uupSej4/1GjexySC7PPdW1/44XFb1/GKO1oB6Weip62Yl4qBS" ..
	"HCIyd6beYxpglj+M+xIDjrwR8mi3GEv5+O/2xUtfJmM5AlJ8pa8+pJFp3QtaypMDkmkbdgGgf7wQgQ3XtJNCs8bia41SO76tpFDs" ..
	"TuZwd+gZ1jBjCkT4g/hq8MQlAyi6ENQQEWoTrb1t3H2hzBSmj9TwvesVTNCexKYNnY8csS3CxDzZV4TnhLMN81Y/xX0a9zTiJJap" ..
	"O02CtWmA8DC6I9X7ZZdmZntSE/Wjg0109Xe6awSDjh4maXAogA3kf6ViubxmljyKScagOqlqa8A5AupSy15U04572Q/DY/+Spt2C" ..
	"9QafOAa7a9wZrGRE12zSNMkJG4tZ6doeNnc737xlpa7unr46iXVZ2JZTe09JXSFzoXgQUSIHsi7QXc3OZf3q9rVRtc2gbFIXKkyx" ..
	"KsNVPy2N/ilmT0NXikt4uwN5HuTxwfsI5PJ/PTBcrBo+/TpPdFi1LR3A56BPDcGs9F+oCXIJLGDgHps/lg3IMURppcdNJf9GTqF8" ..
	"3m15RKQZRFww4D2BY5STcSq7EN8So6io89ZjHnVGGA2hJIcYc+eb14hLCiWhP5uWaRBTrf/RQq1vNHqD9Gj79+yzf+8TtKQLr5bs" ..
	"/KGZY0W8NG0laSit60pOmNgy7mHTkgqLjj6CoodjgZDrYR9dK3skUBN7DL5Ouubf63p/sVXL/dArKmTGHw2buunzS7OEy0uFFyrU" ..
	"BytYfZACK5/yo+4Of3TDjPnn3mTOBgnpFAuOEg/UF9gQPNj1ShJWj091BsA/B+0RZkG0bT0rp5hfrG/koZ152HqbSmtAuMCvkIvm" ..
	"2K2+Tl6SJHCdIDPSuUV1o/w9itAzhw1gP4Io1Rs3HhXKXxKpYB3pUY2hJ+a8q1Vl+d6ZBE8bkSGZ+9z+QaPV9tmYrdeYqlSpt6Kv" ..
	"VKpFGEc+J+TiclZCqvyiAX+RP1bjFb4fQf7LV2ZazVDRQUFnndFtxWx9H2t7YcTjo51UKTa7MClE/hos9yVIBOVxuGrGwY30L3ab" ..
	"C1feJtTERrmQNfz5SGGXsvXbHb2JWzaaqlTBMMqhXQH0cQEqohWwpOMdJcaigw2TBxOIZ0Qcm74huYs4K3IWsDZmInoJliT+xBdz" ..
	"HGnlXaRqV6oxHHzmyXaXGAS+V0WzNHDQhsgOwt3xaYn+AMn0PHZS3Zr6eFXV+OvrAEu3nrunnGS2TjkwxQF4swTELlUilfs7J705" ..
	"4JgTtmlv5cvpS/UGyAVoWVSFYVkgkEGrMTqSESw2PxkzCwvjkyrGuTHfVqaxif4n7Rg2GJzb2j1wHaGaUEO1LyWaV5DAl0G+FUS1" ..
	""
local PAYLOAD_P4 =
	"AqpndwQy5SY9w5BIxmVimMx3LDP6LJ3jMg5zon/God18tGmWvIZfWKPE+pYVKawRqqteWNj2mV8cWRPAJZvk3AUZfdq21HVhfsqM" ..
	"Sc8ZcZ4LuYN8gJbGuCG6ubJoG7k92S64viN43oATtIZCADSR5gXTsL6JKXOYFvsXDDHwf3THIL6Jjjhgl9W2PRSk7XfguL5nw2dN" ..
	"IUgmep+sxJYVqVFL/DsOFDJ4GF80QU7CwBodpenZTqczG6UVyhWOKYmFX1ikrW6rOfZdkSsp/Tw7ITjmjGpL6AWbH9XqIr1NMB4J" ..
	"TKqKlUJvZZ6B3U1eQgaPektnqUR6VgqLxXjXulP/SHfb3dxDLRkHaFrQxpkfE2SWCAKBWHn74TG9iKGiWxV5xP9XBuFvrCxKQmr7" ..
	"ylkY6MPOi386l1jwCufOKszaJLVx5sX8siCVgDlunZGaT4GapDEuoGgmASogdFzt/ht/LHJTWkDW8kdC2vjKSW2CPXmZM6esptUE" ..
	"YMq92B3+YeaPr1uSgipE8uAEbHXaZ8pTCGREfkZjw0+/Lnil6zHe6lCjRijzouOv+mngnMRFZ19pDe7ZYoj9bmt1zMlRbXfbDfTx" ..
	"Mn7Fw9Iw9Xmn1nfv1/bYYH054Qy4MX4HgI2In816+EuwHTEq6UH0QWnis+lzkHdwjjBHPn0nrI2IHNYq8cxeMdHJKj5k0Who62/e" ..
	"yS7Uhh91GBNiaHNgiKf3G1h25fcdKAu6d75x6fupZZclV4lDjlUKPmzRBB6cMiPNDgKP2I+9TzoDMK7tyR34AGalLa86hiBPs9sV" ..
	"bqfxMNUZ6cXjCwgTIZXO4GLH2qZTyHHpaufunNZHUmnQH0E11ej6vl9hXPbOwwEIjteQpwOQkUqaudz+BVN5Sk4qTQI+sKHF3G2r" ..
	"VJ9pI0waPGARph2KupqUxI5dXkedKSoFyL3TF3l/TsM8B+EYqls34b8+LOmu30Afi2mH0oe8/KDkU9xnbm3NwHHVneMQjwP4Ctvp" ..
	"9cPSTiVdTA2Xg0nyVoWgIqXol5f5uSfkOwSRm5+kTKttYbpUsWGMWHiRK8gJYLwRD+dXwDSslNL4b0p//6HpbGao/DpLGT5KKl6K" ..
	"80U4RQUA/yNCA7VrF/+1wBD31BGQaqcH5hMwBpzCK3/A8sum6HF5Fs/hTIN8RQgbzpd+8V8uefQP6ZcrxKlUd12h3mcInJsv5OT6" ..
	"UONpoPmITsoemyiIKegMAq3/0itlBvaMPTuOQJs7riCS2qZFg/4xUrEigGfArdKk6f+BPBUscSqZV6wP4ARgo9GyeUuPAmjn9sXP" ..
	"EOJ02BfPSYOtW1T/SfjdUSUziSlVv4Gq4Fsded//Y3ut4u36oGhPhu6QnS2R0pl094pUOWrIUm2nl7Buk1RYYC1czgszQl2/+UZz" ..
	"VSa9lwHCIhepPc3KANCt2ZoWBkoy4awmFNTLmpEvUdZWIcs6hgS9OJwDcnqhlARPWLcNpwqg1f3uYSpEBLjnk3vcl1OPWaVH32aX" ..
	"bWu/nqh6aW8mM0OmxVg+J1yOZUV0kRoyfc3zybD0/lkMsD5Bvby0xyy/PAc3V+CYw9x9wxlnndgPQjHyfhcVpEPWTZbSBLBS+Rnn" ..
	"8xydv29YKdXYjk03pIh05XIShHbmkNmey6fBk/fdjIp9FQjU4GXf20Nux6l8CDWWaxHM1Ed4lJYPvxZeLx9b2zomHQmQpwrNzKVc" ..
	"90L/NXakPxhZGURvzXx0cioTNnHb+gxoYYS7rJY4XXecDvzPRz5xqw3b+aOpNb8nvGE6S1IajN7x97YFdcHXEuMvv2zApNAdZlwM" ..
	"Bt1T+QKA6LD+nYOjCk9IEULB+ee5fxCOUtOeBkmCbzlkJiZuurzUkR6WUUiV8voDgRS9Ue9cRgL1mM80XWIeKpplGeDfYzBK8h+4" ..
	"fBYIZTHtnbniW7oyQlXUKeZhvsu3vO3iVPZPMfKhTDK6J1pQOmeiAT59bMNurL85sLEx8fSig9S+8gZ+Nsae56kmWjodzJc4R7yf" ..
	"Ci8KoptCcOtu92J/52nbO3qd48wUwUOdCox9A/KTMSFObV6MdlVIsJqlARaj6tOt30Rdh4l94p0cH/TU8qdZaldyuzTnJcFvjkzF" ..
	"PfVR9JivvDmojcDqXECj8rAadK0GobRftw9pU3DHZzJkmVufEnY8ZCIEnwC0iU5KCMuFciONRYCDoPUJ2vAUveVaq/OmT0gwShJw" ..
	"mYf+wvzATt4NKNg8gF3Ye0eLewritGjlhVtInY9qWxXEl5bb7Kwf1dUcKD/Agzf41bo/6GpqzaCn/QaNkbc3TCRbrFDjb1oZED2r" ..
	"NI00U928d8+AFKAGGog2XUS0nj7OWhQIUSBiMStix9eEpumcXxeXJT9EiN+rUyuFxCyzxhE4svwvqpDQ5Mcud57HR+0BEcx1yLut" ..
	"Ads2MbbZlmlHMi7/OppX4+zvrCPSkp1xdYXUNhOsqM0I5lCmEjBgf5W38gTv3dQU+ETl2nFoqo51q6KkDipyvnMoyRj4VYBXzJtk" ..
	"8uxzFjURfDhf2JJOPXBn20t/9GWRf1n4WS+k2UHQ73CmpjIRmZX3CFU6FYnHf/ZBCC6HGpx9jszNoteXoAgIKqBPNHgL6ipe0jsV" ..
	"WdUYnVn1LNZfHA1U7F1j0AoLfbn+8j361QZZ4nFZFulSaBh1AKLpIRcSSD5Zt63KZy1e1OzgVKS+vPZkII24UTN0OnA2LE/X0BfR" ..
	"5TqIXvQBR0A+iMkBzE8Hm5hKigDAmpfmjXdSHJK8vnEYsVcwlBly0xdADxo1X+mmgWy9bM8VRkR/AWraHbgfIggGFzNtT6aGrWLQ" ..
	"Jd/mvUTuwlzkxfaloeMiTQ7nIXf2FdYws+ZnYu9HiRQVEC6D73/9qfc+vzMTXKBd4S23HLvyG8urt7xNI9zCo4MIsTjEC84ADgLb" ..
	"jbdsl7t0oZHeb1k4l3zWVUXDn0TYijG5JFa5Qq2bNkqOZ6rMzwbDfww/WuVS3Hss3aPoCaceC3gXpvBmhtSll3TzP0Q2p7v2vze5" ..
	"K36Qt3DkAks5gZWzOPEYUnSN8Q6B6054NNaxa2WuisG0C076GvUjRftF9jhgRL/jKrjTVd/3xnvtM+D5r2hO1G4ntqLQwxX7lMGj" ..
	"DT6oGXzFH247IQ1vKC78E4SjjZoSN4/Qu+Pm5LG9GHwDRDBS0SJZuoHDMnLiQs8QTJkZowv2C++03aZKiGRiiUzvSqZdd33pVW/0" ..
	"VcTivR3QyuNctwfhKO7hzV3t3o4zFC+j4AFPURZCptxGMBK3KohnkH4z5OFHVwxpg2HIlZvjZio5zTse5ijtVlk25GXhgSBFapR0" ..
	"1T+TAEikSH8s9j6REF2lqezzar0hQhsl8qYSz8T9Nv2hDRJ1W/Y+ptCHaVM7Ch84wQk+0yKBHu/odLjSUcBLqFwC2FQN4al+g0U5" ..
	"vUaexGFiLPRZs14+yE7bTjmy26VKNKT5GqaRQBtCcez5JQZSnKJ+4Y4KCPprpWw82r5AtkvlzNumRt7UiOp7lg2+Uruz67KIDlLM" ..
	"a4gArX7rAEzcQoyKUeHXrnOGJoDAjqepMO2oI8ZfJW6ueuZZaxCf2KyDyXAggMg/xhX2j1YUGySsiQ2XeYy1OPSxu+VgfAVSoPE/" ..
	"jWMn/+U/H93Zx7p9LX6kcM8H8tWWHrnt9jiGhokt/kPY0rilSc0wxRq0X6YdR8NxOuKEVKCBteSHER1wu8VzJmgqk0jxJr2jL5cq" ..
	"9b1e3CjNj+G/HrwbnovjKPMgXOn9+6evtp5l3H2IZL4IAtKZMxF9VP9fRXe5M8uOVgiDeK5kpkAuGYNKklLxhBdDAYVxeSn6jJa4" ..
	"25UAgJppqoW+CQVap0rffvxIvucgV5H2f4HvnpC7ulCmBdHHbi4+oJeyvDLh0dmuLtC6Ktr4fYUGF8/WhcCiAk8pE3LCCb1YRJ2u" ..
	"HZ8OqKJJ9yuahc9WebGgoaH2dAA5AIwiSgNxjHBpdxywqQhQNBn4bNbuv372v7/a4KV42LfhYm4Bpe3IeSBwqvecBICD9XZsblw3" ..
	"Z41vXB3K+EekSxWQ6nSLJbedUoy443mcjJDvScxIUaAyxyU3ze4nXe5ZUZ3gIlcGbQVxuz6gJ4RAin+AjlqGPiGOrJvHgfwR9xWT" ..
	"CfUug06QOTDOwFfnd8NTEKI4wP08AyZclpoV7HKWK9LsN1AHpta0ymCgws68/ZZojsAmPZ8P9mZ/YRhhtf5I03e3vLw4oPKMtoD7" ..
	"ID9UFAfgapvYsV9SS82xtxTogg/8v5GX4o4x21f3DUG/eXcn6d/C7AzufKHfMep+DC1bmkktPh4Vl+/o++Zy2ZFMMC2AFMbsded7" ..
	"p1mvmOeZ140Gm5UsnqRqs7DwQvDqpQBgmCN4jtbN3BSyShmWVn+sAvI/ndLQ/voWYbfyljjP4gnWRH/M3dL3lgfWvSYJsiVHtGj+" ..
	"jQGngqF+2Jn/MXYGkPXNYfBVsFEjW9ItbTLz1EQKTSlR+NYp25r7McEeJHG8m7G2wc4qSxK5uXz8U9xKke80+lj/S0d6kR7Sqebr" ..
	"E1K/9Glv2n07yNlyb1KGDB31jY/NB5aiPjawKqjcOFOzz0o6N+a4UX70xzeT/M90KXy6F97g9ogRfROviKf24qQph6261pvbXNiP" ..
	"Qt5UYlU1BXzMqixa+W6KuBY7NU3dyx7/CgRpQuuhkFHU0/Xe0pAMjq7f6kHVoGNf8oSyHxDAwXUqTzwyp+M7/5W1KRepNXt8pxLV" ..
	"66tJ2LvsYyZ3FVXiGX5fcc95KGwXl9IoEuHF/9d5NtUQeXH2HpsU04PB4I8fLPJ6THVuswG/48pzt1UTjppL9FapfYkEmv6rvXEs" ..
	"5kSojmFGuZQCJr7CJ4+1mMR+5Fnp5pWDUXePHlo84tfRTNkkNSM1eEGYEnETFmvS1ZJ9plbJ2aEIMULIEpGjQTeIvvRZti1Kp0XV" ..
	"+Ll705fw2EaS/1St3fhWU4Q2UROh+NLhyO5NUgsxehjt5ptSg6Ogb334iBlLg6EkxFc4ZNCOoz18xAf6ZuWOhzABl0NY5rAN10/i" ..
	"sOQ57UkN4VDWJF1lPl7/Lp9FN3xhKVZgD+pekeCf7M6do6M1XVhmHuxDX0c8FsErmrU4JIc3mOsJ2f3Q+Bo7F54hHlweLv9z1m4T" ..
	"CmyMqcoX5e/kZ01/e5+ZD+QPURXH6arKxjhEffsu/hyYqNke62x7l/0UfAR+47uTcRy3ezqa+ZO86db5maYUU5VftMVPRffrpECg" ..
	"sw5jrOtYN6Ry9/Rpr+nf1VVa9ZM0sTE+JD2/Du9jyNuyDlrpX9N91qosu5eCCN6QX6fPm80ft1qmrB8C6e6GFILLM7ZzCoHnnULN" ..
	"cC5w69zATaKyPgfv6mXArvC6sCDuTwTwWygwE9j/5zih5WoK15YUjkNHZ74lQexJ2vl/lWKS3P9Hys8fR4c52uxSthUEfjBpmfji" ..
	"9brJMjyHVoZbv2g4BbQW/u69gU0ZEF7fgR9zgSmo8VyprT+XIL1XqXAZkn081Z7l8+NI3gfy9cVpCeTLgzSMWHFCGcR8G6whh1Qj" ..
	"aRA9bSMfyvcxVgOWxzOCsbVSA/mxz3kmgA8ovxilnmQrYPQ/m7mH1KC/PBWTXB7a6GJNvgN+2nEPdAdeHrXXDgWModSKhOSQzg0Y" ..
	"OnXVHcg1k2t7iRrhH7JHVin+pXP0UJzVs1hcS6+GH2bOrFLJQdpTc7InglRPla7fAtZuZ+P040VYLj6Xgf7GTBN6yLFweUy0tMb0" ..
	"mwEgEVh74dAKhXLRvJO1Mr626RNDcZ3lVTpEzCZ1kxJdDswUM11WqP/584Zox7lHYvO6ojcZNfBqmKe2dAI+ErwfVBBvVADm+91e" ..
	"rAQ4+bbFb2MSHSgWoefI7bw0ZcPpbsti/es7Y2F7jBL+qU+AEd/q07U/E55iBKPtJbL49Jrcz88zmLb1jyQs+AtRqyYfm4SyWOKm" ..
	"GKGs15h5+l56CZjNHVA0RZfCJEKCa+NgpD+KhQX8RBnPg0KkZaPuzIIiu2+NUdqk9w0p9CAx1oo9h/qJnd/Xnefh30yIkba798yP" ..
	""
local PAYLOAD_P5 =
	"nz65fdPtCvI9WSl46lB0hDcFCp0P8h2EibstQVOQA5ppOh1oYLI0F6gGxbhTQ/hdifskV/ye/QXdXOa4PaNl11WPqrxu5vx56mYJ" ..
	"UBRzMOu+2hdwnKV6GB1VGxQYQMm06A4Dl6EaJBAPIXzi9m3L3hgqvTspAcA3IHixBCxqxlOP/lOsg8C+099onQpMEloKLebBX57X" ..
	"orE9UQJIIDJQzpjGx2yFcSrODw10lEeVXajKC6gKqMqp1mL1RPOzXEvnqyHB8su0NA2Miawx3+COejf9fwlJ82XqbQyIyLldZzaV" ..
	"etwH80/5hrO2+2f8xpMiRKTXSXdaL951kqiFHfhLrW7xGatjVVKQEy+S1sVxUoxmvbLoIVcjvc1kuKFEqUJrQBBFUs6SN0S22tEF" ..
	"8UN9eB+wzXeQrb3/O4hMhewZObyct1cb8vc/u5XHwwiEO3ILTRT5j7eBs7jhWjQnmROAJxsWM2ZVe4n/BQfv3FIyl9F1MUtcw+DH" ..
	"BioM5O/EIaUL0BEe2/rmYGi2/WY3kLWAR6+EgUwNqW+jT1cPujRUuLBHy4z0xfZ8G6iGTevXZT8wQeAox/mtVGipjqHeDlPyQaIt" ..
	"5saEv5iGhvfbyCmae6ZURlkOtRzeh0jJbAQbYsx53PcXwnZRpHguOruotMOPl4ZsCurlVfY+4AnBnBDfb+VAtdrz8rjfUKKv1JVc" ..
	"+oL2bYKylrrWFZj060pNcnIsqPilDA7ATfo1hbrTToCfMGU6FRwgUCm8xJtBuE5vYKPr5OS29XZTslZ0yHcrZIwbDjn6vPXAbvIp" ..
	"Dc7MuO8Ooibzl8cz8amWdRAxhKdinZfziN3VD6v+TvskBCBqVtLC5HfQ2aAZhKbBUbjPFQmUNsSQ/kuPCNWbQ9+OKgy4SfAVFz9c" ..
	"C5+d8jNky4AccNq4zRcsPBPTHiFJGVdQFTi9Q0COk+43oPzA526OeZakFGRXHtJMf9B4kN0NY38+H6ocxLYteAO6kRAiYbpOOz2f" ..
	"keYaIu4hGAD9hxrLgrZcDDblleFzR2Q8/tVXA/Esd2bHlBnbRhW8dgksUORq8DVu01V+jmgPBt+Crzu5YyyigKbPYKb9l62kvXfn" ..
	"192X8DJpp4dV/mmwJsCzrcx4ofVDcUmc9K5j08EUGzrvfZ3uUwgAh+ydOj7wIwqQJBEOGNXaFPIVoD5FwumCDf5zsmGpuiwm9Hlh" ..
	"YM5wK/qy/N09/nV3SEkTQUQVD+NkuUu1LAk+iskCjFl8GZTdTcR+V+2gMgz1lUQ/KHS8l/goaJplK+0SHp+mM1D1ijon8i43HWWd" ..
	"Gz3UjElRM4Rn23pccE4/0UG3i5G/lCMMebsIYrBrn5q7EIIzLqgdWrXgn8ekJdGCh5zSbbPD3ty8QK19++sGBAuuwfggOPAHKy+R" ..
	"ZSwVcbHfUuBwdByjLwwcqQjNJsVpoWiPze1D41XXh3otRsp8BidNqsIDPMYsTcNJm7zj9xjM5ggoDbea6hsHArgmLQJ6qIzj3A5S" ..
	"0LGo9DKo3BMYifgxHYhIt8mtdbepdDZAw8hhxFIRwiT2RfWr1JNtsbDF/cubR02+0nHk+50O5cPGxerzBmNzTABBLRNu9HPKc7dD" ..
	"d2T9aDEvvfFt9fg33i7MivrTPXiitFRnNcTIALJHQVCMNKPtj1+QaNtXFnxz5l879sEAeEaqxowrBOeJvEdvLQ/Y9cvQs7hVCoW+" ..
	"+zoqZBp5dJ/tR0BcGDLocnqlAAuFk9U8o0DNlnFxADeBTxmXnb4nQ6QBbPY5wOUA73FplMs9UUNL3YnMqLyaypeONYhYT/RZXg2a" ..
	"azizfvl+7NTitZauDP1g6/LuSwdyeWScqJ6u0Pv8P5kxcF8RP92fG1oRFKIDu6lzBxE+G2plcfjq9rhxKRutB03RaiXEP1j1h5uh" ..
	"N4hyZfBi9ErLbSz7lpHNuX62vaz/AgGGGKZuQTJXa1+t6XHaSn0cD9K6P+VAIkF30WImBnm57Y7MnqvUUofgC4YBNmKkIFWaj44A" ..
	"YAck/iXvdPp4yviUglhpzIV2BPrLdkx7I7LowTJEYW0xIxxlzQhPz7BNwzyyAohS7hPLhDO3VZOQXWFNpikfwBhgpsLrWl3qSHZW" ..
	"Ykw0NuaahqyL9FYuujDeIc3jy9MY8XZn3oMd1sYOyun7ptd5WsQMo3NcWgFfGQkIhdbLspsTOnZGKZ75kIRLlpwv87oddKPgqb4n" ..
	"iiIgpmEp6xVHo342V0ki6crGVgXYY0n1RU46SQUWVvdU2FeDvjVpqnjoEeZCYq0wwfI1l0wmkc18RSiKIoLyxlrIAJcTzTs+Y9sD" ..
	"yZhZblXdinK+OUXSE7acZNNSNI6PygjfMURdX4lYXb0o65Slc14VUwJ3AgryVAIx5XVPccd2SwM6vxvHyqYR4KHm6PvoSnd5D8Na" ..
	"AUhoCHGKur/V1ixy60jdxdUlBDX0TsVIGcj2/xNugBY/AER5LFliFhMRpdChLJU4N7dcVL7e9MYAsy8iDB6iwiQNAmubNI+18lMI" ..
	"PlTEUKz23ISuZBCajmmu/BZ/rpC8w29JYbP5qCndbBLZBR9moNNiiWDMVXanhFCBwDUvmF3LN98NUiiCQx35e8ukRDyExdPOMbNg" ..
	"BSQt0Gqtmvc8EMIo9sdcwGcUtDbf3R2cjZDvgda6On3kyZtDPYgMIF4PlDFY4hxA4Sik+c/5V235CrOrXuUPdsbnljBzpc5Cib50" ..
	"Q5UUkQVazrlTV+P5x99/ZqFjLZ/LmwE0DI67cFZKMGoKiN0kmsd5QniLBQpDGuw+XjD3R/eNzAIm3clUxGB3MNDBJsXhQ2jW518K" ..
	"2N5vP4moQyQM5p90GzyQ9vcQg8/QczbXPfMQ7GPOgmvh9AJGdWb63vjOkKcx9zCrC84RLzSIjFgUYV9l/oPppCcX+QtIP+2X6a2f" ..
	"eisMK6RAIyW5dtqA/LiJ369mzkClPZNL+a7VhCyd0OFt2c+xtelAH99QWnH6Ny3If2tCAlS4joq17IWXDmcKq4yqqyhDMyE+aYFO" ..
	"Ze5CtzKghkrSmMSsZC6kvAx4KSAH0hu0RgFswdizRKXkRxh1/xfUjzleuoWMNx+5R5H1af1Zfazx9EqGpoMQbxzbH0MO9VK/c4YZ" ..
	"KdbR1WSx+F20v/IQ+CvHd64Ttw2bKVp6UfoxNApvE1HHlCTix0NHAcQwlrN3C9Arxbydb/oIInyY84mUujZeDuvqtsrRDYkX44xx" ..
	"s4nT5yED/ETC6yrqRMnn9tIOO+0/gxGHqGgRuFT2rdXGz4eG7dErnNSyoKeYMWUjHPcnk4mXFs4dqWJJxegdRSIxMOtuDaM8OD2O" ..
	"TLUS6OsgfC4KVGFE/u11RjF0Kjqy6B34ZYKMpd10nNRkxPWV/kKXfdS95QD9gYYzus/xo/vKPDaPO5Xy4NQqnwHGwVa348C7mNA/" ..
	"Qw/IkR4QiU7Ov+2GhxlK3W1WA8IDhmgJc320jsA3GQiyYOcI2d1Vd2ysRnqGk+7T4eAHhzJvBVKea45scYCUVzrbEQoE1xoBa0jl" ..
	"O6J26M4S8+Sw9WFjHdGCOfSUVyQRTW+skoluZHCUiDtNpk3JunA3hxOnnRC3trpfTDD6IzUvcdUuGcXv88hI9qRly/eExQLrYMmB" ..
	"pYJidciYTo3wkyQOLOdl8qjd9sNxeq6bbJdXYFhA0lMMxjujgOLopLjyLO2kyq/kCwmUYwqwntQBiEzdtbOH8ls4w4CoG9+uGBgj" ..
	"GcCejp2RIzgHyuWTYreu2YZzufjO3zeHM0AR6aBCCaOOMe91pnj5+lM0Q7jAytHIamw4Yz+v7aOozBZrSc3Q5uIh2JP6P8YN57qD" ..
	"DhtQoOSigsLOMwcx8f8/ajMKRJjdM5F1CShtJRIlEgTGKzk6ZSTxqHl77XYrB3PD1xGV0dTWisLnXDv1pg22f/OHWkimwrKRUoDk" ..
	"IDvs7KxVuN3W6WX/F2ZO5HHc+h6PvhQR+ggUbNMYQIHT1CXwC5+EO5XvlWj2O0k1OV+gnQcQb6pxe4hculy9sJhBj75B+sXRdAGS" ..
	"C8BCClmlpre/8JxvELokUoBro/N/zrylNy+eVv1zjwb9jl9GkK0BCaB/mlLAlGpfmHhq6WvfKiUeimMzphIJruKYHAlrqo7hn5FM" ..
	"V8ZqJueQLbZmlr9iXpf2iac9jekEqvouUnfW1IWgPCQ4l0YN+p1rUFj9BfE2a1TL7eKAkDFhKDTg7T0ESGIFzcnjNCOcsezeNDvE" ..
	"k2JKquQZeyLtu25n3F0eJM7DMWKZcGYpezFJlb9UToIueAflpOHPkk/RNi7BwEAZoRM9yjY0L1TAJ3pmCn5CppC5S39k15x5ZR0q" ..
	"HnPi8Z5HRagya8ds4XXjFgdeAq30KQ9X0pISyKOsU5rjF4MwxsaFuJEVeVSvSvjRxwfUre/WCW0K4NkfPerGGRb0FmjQJe3u0tON" ..
	"lbD7FEr08b+tm0B8r5iuFbf714jNbq6H2ztXqeSAc1gTySsIM6lVgzPpagXjOFbMboFKw9mN6rnLaKrsMCuMCxPvcHryrQoniIlR" ..
	"SAXAnxq+jd7B0yS7ae7m5+GzIPSTZEgPK6Ez0RcHgjKaxp5Y6GGh351rlGswgPZ3XoNYPIKvC1o1hmRrxsfwtVH9z4OfyH3NKsgI" ..
	"nYlPL6gwW/Kw/zOd8Bsh0reMXuGvgNwDkf67dcOzUd/jRSLPI5fMWssr14QmiwkdD6+DVuqOvJ3dTkAvajb7pGL0w33BFMQNaFlV" ..
	"mNB2lE9+Vo5q8GppPRGXkgq24UkeZuea/avdwICmMoF+9aWTphQyvuOeJRtuFyei6/ma/OJvr2to/c1N2T39tAJonHykm0wYVFxQ" ..
	"z3cYXn1bGc99AwYRAFZyVOxaCOjGg6Nn8x5c9cqD/K0KM8UdSHkI3Bb+Pe7z+JqjsiWVbd2FZEP58CWmtOXGET81qifn5NghlECd" ..
	"IzK0j9g9a32bH+Cgn+Q7WyOPVcqb8L91Qy0p/YiiyiRs/C4JH041nWgMXUww40YF16aYaIAttodiTNFhKgV/y7gNi75v+FFsDL8y" ..
	"xS2HIpnRFJyfnjvA7cz6hUm8VzgW04WznP56sHKh+utWDLm84siX8i2jCnB4EXB1T2v/P6dqHLjFVg3dXxwmNiOa+2l6NabyKsIZ" ..
	"rYuuaeIBy3Jhw0L72Xym7nGY+bbSvtJtVAwr2nOY2O9AupyG7Op5wOsxk1t55a8xB03S8uMummTfxH8zuRZSQkHxhoJL+5kY/JGs" ..
	"9zhECX9YU1oQ/rWHXUOSQdf7kx6LSLp86hvp1slIPBVNwPRCbAJOBysk1sJ6qMPwc6cRhqZ5aw3Z3sRDJncEsbDZjKGbu99bZbnO" ..
	"jAFIkb/sqMP7nMxyfVBs95g/DRZLXCq3PbI9dS1Q9XZGD6u+UNN5t50lM13uf9tcNDrE6u0qolXXfS1IwGDeLSLE02wiMpAcMzhB" ..
	"pAQXok0AETj79yODI++oKDlJ0hX8RWWc9VaJZrQgQOTPfWVYYyx3Yphi+15zAWdl30C7O8dIQ2UL9uoTmSlkw7o/gz2n9aIHC9LL" ..
	"RV9/oNoz8uU5HjIzbRl3CNv2lFOWnJ5gKOIEz/MTte3U1A661BCH1UO7LOSy9zBMbqdUUksddLClv6okiTzy3pmt/BPA9QHl8blL" ..
	"o7UhH+yjhqoamMyZARCvXxXhWA+hDTa/Qzf2vGk6rwxtjwuP3sE6Z7hBrYNCsvGvmPNfrPol/Rc+OBkUWfhYZHIy1cix5audPLXQ" ..
	"+Tth7ArCc797IJcvMt1nQ0c2sQG0aVR6uHCnCBwQqUdsed5E2MdJn0oVTql+p+H4blHGWtrJTZJOGvnuAZfmxG8VDUzJGS78YIL1" ..
	"FMXwQu+KgV7RgwLvLu2gFIUHdwUyiRYF8+mtH+J4etaZL99fehvWse8DkgtTvaC1S8ZJfrROe2WcxKCz2o6Nvcx2wzesSRpfgX3E" ..
	"L6YSl9qbKyer1vKG+RSm5ECYgfVk+hXys9ZHoAOPuG1nvPdqrslx6oJO8Su64uaF1kTzG9fiql6Mb8fk+xtbsbGTdnjbG67XUmwQ" ..
	""
local PAYLOAD_P6 =
	"yXX+KxfqrWqpOcUG5U5DGqGjSRy257pEubWqSmloo4aDithA/krla73cSsrGToCIJbyLSU8UO3G61lk8xL8ltYObdcd+EPzyRzOR" ..
	"1gEG3AEyqaSCSS/Q4WgzF5zts0njcGL4zq/j7S7M73y3dH7AbQUXK+6wNledzI2GHMPRA12mZkm/waF3PsY45ajUieWMWhbpR34F" ..
	"Hyf/muJzpfaOjT/GAB1NQOr9GIfQse+8xogNjdaE8NkxaCVzo6aNP0Kb/AaqaL2jzHXdf9XKkMd0wkZ8UapBe7Gq2M2hPIsc5958" ..
	"Shp5P1qUdBYDomJ5CKOCH0YzRA/hf6swAOGyS4VDJzjNBEXupnyO/fHRB+AbILyZJ8ikWvlCzqAn5m0Kqfzr9CeqNNzrW4xeLICi" ..
	"YPmTc1GkbYn181hZS/O6FJN6Gt9n3gnpNLofSbJR48FCkTGIiu3PcdJ3cAoNRhqxOxO6a288kwfI8vP4mQBbetlZbUbElxxIYBB7" ..
	"PVQtOSoGKh8+bwE0Ac6zHG9mLqytqSw1/JqTVVifeCccvKCC2y6k+VSAITAYWW+84oArplhzucWdr1GbAU82x41WcVNr00MT6Azz" ..
	"Op2Yh/r+7Ghe/ISATQpSdRKfwJd3751XE4UB2vHqIhvi/naNry7ImWJwLYqmOgfOVZEu7gudsXAm3Xz121sX5yxaX/CuueT8G7CD" ..
	"Z/s0gXOzFQ0ksUvq+BbglLuZUMUwEzre+jj8CrY3o3jnPviqS4Ec1Gk2hH9gZ8z/JfTv4SW9xxg9QOOkGvtez16KCrg1zc4fKlCm" ..
	"fRs8PE9s9HmBlA0DqnXPluBU7QQx8gzWXXIJxdRw/ui9UBsg2QxFqNDroCjIxUnFAt26ayM6FuO3fbQF9T5zJ4sluDl7kPaBzRbX" ..
	"Or+0bSULlqjGXj3HJQo6SxCyeQVyiZT1EbauZU1DTOOEHfFeXbHN9TVqFV1DSE2+vyUawIaMQEVuOPNmEotQxHVDgCoYe6duP+h6" ..
	"eD++YA/9bYX4cKovrIKb2vaYE2u4t0e65ruryymR37WDF41+aKTSVU6IQi1NfKaQPGbvct2O5htQAcpDIqr80kX1c82ovZezGkig" ..
	"yctPSdeUd8uVwc+lBY6azEKyGAcxZn1UpSt/TlETrR/2KqKbET4ihOd3iWRILEoBvl1G2ACKn94CJ5QJ2moa+PcviiHxM8ZYoP+z" ..
	"fm049WWluNtd91q/WaHBycw15H6wg45MIw09GkNXFNn4msYAWO06603XX1DgX2jNEhbkTq/eqEldNhoj9JwFNnKBSi2l8CJm7c1c" ..
	"z8n1aYM0cAS86V2ZQvURZgehPP3MJL2h/e1WVkKPkNL4QWZ7i8YQfUmzZEZzCMfiHHhNGWnu9oyehXs6uun+ypPLqIZ1TqC5Ef5s" ..
	"Dxv0hv33NUllH2jH9IMwbAFiDtZo+oYgxhBRaO2ZtpQ/yvjwGsaRgZAFe+87HXHe66B3FJFY6qtagFHH3+HTA3coMsf1KFnW0yMg" ..
	"+1S9P6vf19kgCYR7VqwFJyWa2wciEKnfyq6+VNQcZ0OuYG/ghogMA/JGPeOEsdIl+ZlPhduok5Iw46YQOYNHH+YCXEinM0S3iR1n" ..
	"XZSauMcQ3ol3JlQJDsX6iZOpMuMyr9J0CHf+KFJ+LCPdLGAXpkhodmdAGZyyNHgQi3gMVvcW57VkDQzlF8vSIkfToT2JS3+rblM6" ..
	"Tpj93M8I5CQ6bEDIvoCKZ6uhr6aL5CECrE3qQaBtsvrCTbWmZSRmAzy/TnqEjZ1c3QR6xKYWiNLaxu67niOrU4Ate6U0APxeofOt" ..
	"doSsQkHanLPdQrO1w+T+uGKwLM0y2z624PhZ2Hn/gsNPBObT6KgdUIZwV19xLiVb6JzoG7JRazgCAFSeONvZocyihVxBAwJ3YEOJ" ..
	"SLsSFpn9eV561/oaCgMyoFUnZxDlNAIL1nt629j3CbuVJdjSrb0e7tNTG/xr7+C+sx6+JrqYhaBOlelfMrk5bn6iSjWEEkvoo9Te" ..
	"y5n6oZWGlSncGD21/4tEDJbRo0g0k7b5MuoKgIJ5nJOUqVe+kuZw3rzKGYtHS1Vkm4sbpeQ/lVuTttaakQUukbFPpknjHOd8orOm" ..
	"dUGlr258srHCewvan6DILRd2Nbn4kBl1Ht1SZU4f0GTMSgBKAdXdR4/406xgdJ35uar0l/lH9sqDgHaXx/oeW/X4eMCjiPl+5UIq" ..
	"5O5FIPrPi58YNe4jNo5xMhgi3kHZe4zpfy/e3cfjR1MQGvVfavn4XE1FM2RgkukWn9EyAGlaq10A2PwA54yH8L0gYBiS2cAY+RFa" ..
	"K/sw+W6f2BcIyzUfKu+UtWKjfpG/6Xtrat9uacF9IVkphwHVNeHhYU7LxD1jdudrDH5tDITiOiM12JRRfZFWnct3LF2ggraBYv49" ..
	"YsEB8Fg7QYGPvMLSHwXcmkAMk+JsLEh8BmKJW/SB5TGBcaWL9AFysd6OhxK301/PH/ulLbLeJzUwcz1UBRozy/Mh9uqn733fGO0a" ..
	"FOkNkWLZ4H9DV5LjG5JvanWw0OzCxH/2550eYPg1rlskH++7XFH7LbYDj1j5i3YO6utlcuEdpNpqPTIRVMOs6IxWplg3twr3rsGe" ..
	"Xu9BSytNdssO1sSzZoczed3Oj3FpKpT6su0V+wnBGBu1nS23nMw1gZ85Znd3WneXeH3OP3EoDuiznldsM3xSkPYkd36yAAe3kTyN" ..
	"r7US823UOdAlORl6fNxkp6NwiaPGtBXk8XkdKtDgAZ84Ao1IPo29RNFPTj8zzWeqWYN6fwKlMNuQLoxKICbkqH5V13UgXScYdfmj" ..
	"SyIHjIjYqb/b5iKE2QEbJomtb/qduL7qbb+NHP90K0aQWuplQc+0uFuHi32uTbLbjX3cHZqZfZ+ebV9ApGeFsX6ZnrqOn86Yh4x9" ..
	"U0GaTQxnuFEsfRicxvHLJUjn65/bndywdk2wbAXFMrIqNGnvrQWdX3tSaD/W0drOGPV8/Ps4R6DMAwBrV1zqDkKhhhf9jJy/zxJj" ..
	"RwljjK12q7QCNWlWSxgU2wvcT55EPF4Cng1ktzRqYs4OHT4pUnzGwI7ci4Tw9vfcNTbF+30eQe6RhQfbx9osbqp0qIi5TA2TcirJ" ..
	"z5JQ1Z8aLIfinByLFIeoW5Q3Tfgkf3pfROBs77kn9yuvik0g4QYxBS+Q8P4bX8jcg6xMIxC+GkNdmS1JfRoV1fhfBJaF67jqXaJf" ..
	"AKlo/P3hANHWUxnYdj4yaRGHj9gCzG8ZlFjsDBOmwo6wiF7lHYrfVZa5aViMi10WPt/FXvymsNlQA53d41+WREekO/sJ0gbF2oEG" ..
	"P+lDn7lV4kxXGRpbrE3Oaf6OT0XHRzzh+RZYhaYjdEtwSOhJ04Pvi6ztDCbIRsFO7jq8gvgHVSZHCyfLs9Cxa8Lil6g1q52+azyE" ..
	"He6V2LIqR6bhDFgWMHB/LUYcK0x6v+RUqrU4CIAmDtERfMDFVx9yptkujun5BV5i7ML2QjjhkS9Xsz7Y/0Bk7W/jdQz1ta7QVUBc" ..
	"0671q01nitVAgkxtbxSuq03SPxrOnatXNgINDt0O24Hm2G25vbF9zSDYmBosWWhrmj4A1THG9wG9kA853doKx7SFvHicqpK1wuxQ" ..
	"wNsBspp9dm4MtLQRXjmPBnIqLPSdjcqqL8DSG7JPIP10S/BHZzbvriF2G3hsyQ6GW7LhxjLvYDDo184Bkl4p/ACUJkY/ODX8NM6M" ..
	"1biSpFKpg3jrhU4UHXsPK5//wGHvnzvoEq0Q7YXLP5y3iaypTV8AmKRoAPjzd5UUTC8ucxW2gitqERNaT/VxrO43lyJQtW2xF5Nf" ..
	"cuFxqHxAFJLBqbXcw/33iSwYnWcRTs+LZPzMXx12LnOJd5bOFc/KetKRN6hfu1JesPkgyL7WFmG+u97SaBillDiSVVD5bPDDQbEI" ..
	"/JIq/bjkMsjrNLzlqLyP8zItpAMa0l1hAOOuPoPVNf/npqhwFH5UJ0/I2yS6WZ11XyqTHyePWq4meeOSDBMF+MJg0psbnO24MuHL" ..
	"1Jg9Zx9IiD5pkcAhQnk2KXpsi0b/r/QNPwQSLSOhfME1eBf90DMjbXlq1C5BgPHs4z+pwRk4GSRgr7okFaH74hbVBuodGsN2ciLx" ..
	"YnXOnBM0v532Ft+FbdGWd118KXToKrquUvCjWCnlMTkpnp0X4l3IiZQBAZ1UrBPAazoAEW/lvw6tqpHUJZXY0PVyQI8ijfMdZSan" ..
	"CoeeZMCt3KCOnVmLL5zaIKDPpA49vRdo53IfdkzL7NCqdtK34mBtvUnKd1mOuMZ0JafvQ5xVhEIGN/shhh2yLmcJY4EwYfGEz9gm" ..
	"/XByOVO+a3JJljA2ZvnBo1mqC4rqk/Jtdyf9jDRU4RpqqKCLLzTA+7v1/XvwntR2w63eKhO5reNeh8F3EbL6CFqconLU3TvaA0XA" ..
	"uvnc9yYsfIBF9JNgcf9Mnhty0ma/fiVlt2wu/5Ddb1rLCzLyFSkKydqrqxlaFfLF+iAh4lMBy89vc0xFiK0BWbhmxwhYQwdpFpjs" ..
	"kWaMGDeSrqPOwW6TTTMSXTXqm8UHZ1zmupA47XEG4jQTsDzg+xiWF40OiykdadWTh7mVKdDeknuKDR6Tq8UiHuIBVfkEfzdbwDQT" ..
	"sN5HNmOw5Oo/SHN4tYOTlO0xsVIA5k6CE3yuEtagOPNzb/MpTHYrZcJbIRRcFXpXmSbyrXEKnv1DtlfV7JOzr2JRAI3bU97//Xhp" ..
	"ycxwgBbH70yymqKPHr7c2PJVmJXVYxUlrXQdePxywPrY8lP3HAR5Ji/SDu2teSBeuXpXa57j/6WDNH+R7gXDSN0+OjMh0WpMRHKk" ..
	"JwRtwj1q4Wc9E1ydWAYjJ2Jih0CCcWWpksTOpkH386dw51J4VXT8BtPNSf3wIp5eDFelfFTMYKnZH3OhIwylL9frawp7dEWCZ0vO" ..
	"/5x9IJcOPmtn4Kyulu4OeNfxwlzrMZ/iPMOVmaktSzafST24m0orLLA+rcZDLOQ0izjpmunUlZnx2XnOPuePCUgmKngbFT1bOoGc" ..
	"8ZtbYT8osFmU7qwO0YAIAgsHBtKVXHynKqnfG1YfBP8bdpzLU/sqM55WpZ+rVNo6reKhvtWIwtPpqwLUL/C/5wA6yl9ZjU0SdT0V" ..
	"jhClMFL8Hv+ThAiwx4yarRK4UinLmzxPeQsIBOPw5vgRuyLeCkQ3YZbxArFtiaEUV4YmmKS3lz6/k1gogc9wyA2ovMJl10gS2yMJ" ..
	"4GmcUh3JkTbxG8kJPCxePvawwGyjlCXS5dmtE7HX30U3udwsRg7yCNCZ5d1BJ11E7MNkMvtyrKK3zV9oce7BfADzU2WdQak/Cpsi" ..
	"asG6PvNgXzASCB6hh6qEOHYmS4ybpp1rsWI0aQDNvy5njxmHXhdSAYenZmub97sOQYva/uGG6TkBFjHpzRdjhoIJCCWlLR3/cH5H" ..
	"iz7R1d2BLttbE0ZGZ+f0h1dY8D6QNX0LbeiqUQ4dspLzKEL+JeAHbtBN1U/we55B8PRmp5hlequzUw5SuPHnVZMxF0YjE3rgB+v8" ..
	"JX8DCi9etMbRHXR0veo6PQb2u8CerzPJttCuCM0Gp484klmPjzhKj3d2NJfHfVsnZHx6U1X387lVgCmqVZ5ViZJLWtbVVpCBwI5T" ..
	"gGlw8cqCHftu1UDagjoDz0GWB6/kUjKfutNglqDKeISWmaKaRpyDs3wmOmjYAhzBa3aeXOgFdngc4s1XZBpugr5Vwmsd+rfQRzpI" ..
	"BEfR9dGkXQVjbRq8ShpZUaoh1ABbrhcuHx2Tqa+ZFBYpGvc8PmZVwit68SQI8Rid5xFPdvH5dRCMhBRV6GBzd3IBCVElN5ZjUWMH" ..
	"qBQLAZDjxUHrtW1dc0aSWRiazk8M5UKrLyYjIOFxyMOfDl2VEL6RDcLFoJ3Dcxs0RdHXCtv1g65+/1ON4ldtRazeyOIYYYXUufcJ" ..
	"BlM3m9LnNMvilMiU21KkQUHURs5ig7cAjjI3LDJ1R42S+2i1VyPZfhpxYi/u9oqucejlojmCK4zSICy1BYM0dHrLQKtBfeMV/2ZA" ..
	""
local PAYLOAD_P7 =
	"FXBJhh9zTCxCDMn2BoUmwOTaJ0prxomWaoceoD8QI4zIxzP2ew2nfKPukvaBI4SBfmOtGy6pMSw4/Sy+Vd2CDY/ZmpoWjwj+tGfg" ..
	"wh3fXnBLZ9wMAsnGejyAuB/YJ35kpT3sGz7j3q/QoMfVC7vD5Q77xZW8IUyWJHccxrxySxL0Id6FyG7qLRESbZacAZnugstRxF5K" ..
	"uZKQbnA3jBJSHUFe+1SHMZE/jVQdn+F1H0I8gOEEhfa8jjkSkxV2kkYt2REe3aGCStExWt8aYnyaxkvcCrpcrdTLfuKpVL3Yjw8K" ..
	"Qq6KnKS7SQZKaX8pyxSgz3g6hSHXJRfJgwhRdpsKOQYKR/0+HKuAAv68YFs3JOzcMWwV5gmhCd2B2yLny7pjUxSP43TjNtvG0ukc" ..
	"mVLiDMgsRnmBF48tGqktgUHjY4rm7JbF08hf0yn9P4gMYxhTzBf6ZoDTpPJNvT3TTuoa4b+PjvhJIJoKrJvZPqYCcEDwdHLk2IfN" ..
	"I4ILsUzHyKeAfJeViu3pMG/cVCgxq+3wIo0mjYSI+hcNlnACRjxnyd7QECRoR+EXXl6SVv3jcLxxc+jP7dmxoRn/2azyakNecUhW" ..
	"OlXyPln4/yy8yOkC7Ox188jN4WxPxN1ieqhAdeY96RV/UcrexOr4cbjn1H1z/fR4IW2O4EYMha3yJa3AaFi9MaE8sSxU4b20faXH" ..
	"i8jDbWUTH5+wb0w5M9NPF9LaZjcRxXrZPL0sILVU0MydA2/Hd3maX+Hzt3wFgLg8mBsF1NwfFjjoER7Alq9pnMd/TxkgvsEhzGd6" ..
	"EbzuHHrxOu2BTdpvvRRwbkKyJcYz7wyZyweGR4Z2q+3KIAuEOlkF7meR9YRUTnF4D9vVyVX32yw61tbUM3brLcpRYVzPakpbWqgH" ..
	"VBzcij06Z8JRjDnzBPrVh/Id02E3xr8o04ij5yB2Py69Taw9Rys657QoNCmt2aSuK+Cee1UTweABu6Lm8tIx2+Bnu7KdzASSPenH" ..
	"uZ6cfD+l7dg74nKqbmN4wrAH/oLQjWN69LD7IHypcDQzaBG/2Oa9D90PuYQAtOZl/OANTdtL/SrfOyCOqIYJtldONNzTZGFYkVzF" ..
	"E8rnE5ZfoHaOFrw2DzaOHlVmcSFu8hs2pcyLYQFtx0LbGCZQt5DTYbFSQzrdOvMg+MqOi5jTbCf1oVPK/IPPWKWPXtxK6sVlOjLp" ..
	"z8Rrlbxve+lgxXgFntKVFmgLY1dDU/CfUvP+kzu0HqjttU7vj+KbDbfVD5a/JaKaq23fAo9+67vwFOcgopvrrJ1VbFjWKrKKpZZz" ..
	"NOni5QfRSn3V60vfwrZR+lZU5OvhKZ5nd3XuWTdKFRbmTgItcXAQ87BFn0BxTV8Sm2/HqEahDrwwo9ciJXBHa2dEvZNYG3OnZtAk" ..
	"XbhuyeIgf/M/3Flht7KbFFKy10yy+xOQ8VGRWgOu5ZEP/S6eQZN16cTvATkKGIEthldtVgoPm+61KOUqrjzv7DxZY5DiRI89d1uQ" ..
	"XJIEqX8gH1WoxJOlGZ8lYTaLXT1cx7xdEnmr+DCQQmavDcOHMou483N9j4S95DDVasQxZ7Ms2/sQFL/k+LzdJ+jjbGACK/NexZaR" ..
	"dsCFKMjIji5ECizQEKRz13V1EnZGjsMauzCM66A3cr7DDQzBxKM1qk2JU93vR0Fi0X7HU7YACKvJSl7GJ5kmTNFpUpoGyJV9w/UV" ..
	"KauG/QGO4CS8qV2R1yDrCd9eHW0EawhefrxChjCzUZ2CBnxTVnj7SoRSMMc3dyAlUrAlJr0A8ny1xfQhLzyXOPuP8QuPM9AlhSVC" ..
	"k2/yVTYVaIdF3yxRKDH6hqvT3lsVKuJfEBYFrNhdlGR4k0oBfGVky4oDFfcH2dfOIrs4Ri1piHGZg4HRekvLaLURUcEYToTcg4o5" ..
	"QRqayKgHkl4ZFOFET0+zPMVatuh92s+QeKcks7VTgWPHRVagGr+jUjinmkeaDNN/IpAC/WCcmKXcCrWcwKZvcso6kEkE05ReLbIE" ..
	"oWNqcq+Z6d74A2ic2gMy8WGbx97Z8vTe829cMUhpJwYDzyRI/+LjIjYRF4Jt9La9P/Jjze8ctapxOhiUIVQrOJj9+kQyiKKh9dJz" ..
	"gFDVSRvL4Zw3f5mJ4DJj3SGa/VcdKScUPvaQhoIc06Re+efulq9eCEq6JSGK8S7m8Ceesw0gXNwvPLguyafM730bd7I89WlWQyWt" ..
	"p8M9Zzg8qX516WJtcX4N7S4nGo1Qpb1KAK5sEByn5mROyNK9MSdNBPj0+XqFm8JxHpJAgzskE2FCpyBW/c3Oxr4ghUkJlgukUnun" ..
	"zIrWO1GF6/dIUsoqQj8TWmUMU7ISKuKEACUdCFTgM5CjrE50MQZvP+JdI9EqibiBhNcM5yKYaMnr8AOScliBiAHCu0BGEWkaFIyW" ..
	"sKLa9EUzf6dQea8m83YD1deLOwklWwMLldU9p7G0aq6nlPYIl3euB6WKcXh1NX2rOXVD05OGqKUMUXrP/s/dO4c/jfWZRQlIWvrS" ..
	"9qHmuzCb7C9Xy5hu/W4+/H4Lol/+dQOyvdvU83z8OwJZnfza7QjsIJtRh2BYqmG/jTHhDssJm97k1a+Fz2Kf2kj5A20JXCkkmUFz" ..
	"Ak+Q0ntGoAkEq4M5DUTiMAAIZZE6FPkHqJtuFyRfkhCkbf1Pk2nUOXUS/iFn2Q66BBua/cLwV1MuGc4m98wmEhbgONl/tJZqyZQp" ..
	"Q9xBXUkXoYhHGoSSqDi+pk3FK1XxU8Z4MTtTE47soWNLHCvnsVnGmoM/FD1M5bRxNH0kHEof85Ps7oL1jaLXN8zdW6+Gm2ifvI91" ..
	"WJkwiCKf1d4YA+0hzpvGP8LUViAax5o7aU1uxshCF6+oJn7AhkDBjMBaf+MSqaQgAlvvN1/yr7TL/jIoUco50JttJYkeRacln/26" ..
	"kI8fl8YYrXrTTrmPFpnk7uU0v8NKgKk6PT18VwObWfL9JN8B20x3mmzoxkjRWKgSlwtrezWqf4U8b0kQdXYVtRooRHxZadObJUy/" ..
	"h7283rI43EoFez0DgXP9nJZrdo9hX67c2RDewOh492as/K2U3QimYmKaEEAjDYQAn/ylGtFOWUr0WvkMqy2s0ItGPHb4Hz0VBH+h" ..
	"+ZAtyWVW0EMCMLuXZ7TOzVDWWGLDBqYBzhFFtHt2of9IwTrCV5yTGXU05ZJ5Cvy4aPM56jqQpy4Tcz7fMiB6iFIUjA182nOhSTo0" ..
	"6aDf2ZMsSdMjk8S1q1n7w9Ud4tVNrW0dV3YsYfzV/HzvPZyPp8Ceb4hiWr5f6gZBFxJO7SsSlF4eau5KwG0UKahpgnEazSdHQz5f" ..
	"UzBeuGSJQBN9sQibXDgxlD2bf6Utt8sPdbaQBGpgo5GOBLfGeABUTUJxGY+pFz1LYBAdyPnupPWyzsKABN77uDEHzOx3HxNMIA2T" ..
	"u6QxGRwfzZja4ddsscw4I4p8Tqy9v7q5eFDXKfTI5FAtPvQdUMghozgFN66zSbJv6mUzjjOkvbQW+0W4B/u7dPWl+UrHges7ASA1" ..
	"5sS5Y7RbVSyIRcxE+w350UqrxEKUq0CkngUJq9zPn/vGBFKvYGqjJ44D8shAyByvg1N7s8qKns9Z0wTQVWLFj+BGc//6lxMD1F8k" ..
	"T8ekiinvMZ7DrvGe8VKiXwTYCBq1vJ2POjX8CdtEDDOF9FDGHEfiD+HxXXijnZZw7ysW8Ki9jDmAbIaAWnb1GdtJZwdFaPvw/KrX" ..
	"dSpcgHuLsK5XZA6NmCQsxZMIu+CFFJbWj3INCvxUl177tG7bmKh+9KJxucGnPSHi5aAagfkzLsCLxVJzlR5tZ6qtyGYzkC3F9mEe" ..
	"TujsA8KviZY7ni8Bh/sE04be1vWX81J2TlPNu8y00vlveCkthj/q97sAlc0rWm+kVtbMM0gDraHT7U5wkGJzcVzSvYX19wB8m0lm" ..
	"J3grtDLh0EM7KoZ6UXmwKJIE3K3y6SgmPXuIphb3/T4xlaD5iNd7lHrl/vAaRGRI07qjFLfASK3TNiZc1GH1KQ8TKJUgjnVaY050" ..
	"1KxmmpAK1VzRfeaPZb31j9suGMeIU5CWLURqGKVvALRZ1QyVjdWwuyEnaxkafpDQekt2CjDoFWbCvArcN9Rc58ARZ0LAtyjeCMcP" ..
	"utsgP7Xm4JAiSuTkhUwk2oYyBdsuNqRvcv0Oei25ihJtptLjTD3+4jZbJFcg9FJVn8blWSETES/Ahrxd8I3A+Q2MK1YF8NJjyRNv" ..
	"bZ9vkwmzY+8awRE+M/2DW8qDLHQh7BH0ZiROt7bwP6gvLkjSq7vxAFKOvmYoOWV7jY65HoSQARrbdV+Z1i8VHVjrL9a5h+mJifra" ..
	"30j8SrXVl9D59I8JK36yPX0e6wFBIZvVZfmpjL9kBP3oHntJekahdRAcjdKhz+bjqJ1Iwwfpgn3C08jeFZ4gM4MVMI6R/mM3kbf6" ..
	"HGXIVoclJVnFAdccWFxr6nAyvmQcrC3vkoH++emlUrPaCRFl8FrvPLNVj3aOCK5imzUM5iJm2adrf9s0PNxQ9CtPmMOXuXTNQNDu" ..
	"YdQVZUOF+TzVqugUPXiA149IgxLgLBHeoYKPgUCnkapAnEDW05+L9eJJ0MzzvFbbrbjY8tPkRoTP1BPI5ZUqscnj8NapE6+t5bEz" ..
	"7W/17ANc5S0I3Yf5FNVv5DJOmaDoKcevi18XGPenFtvKLaQNzbt1BldjWkWOPAHiBE1/YyAdWGwp0MekjoRrz9LbnfETUelPcWwe" ..
	"zVX/oFeHgBV7verBKhtCdeaU5NcgAtHu+PFOdSRmItFwqLmaz6JIN8OzzCCN+HAJ87MbIyvgF/kSmAqcvk950GQM3JT0nRrtHOdH" ..
	"G9ZZ3DP/i1Q8h4+/CTUBMNhIePj1KnEsQW5z0J2wKwpJlZUJnIU0jdmLfgUllVf3R3OtsPRPMOMPQTKIWe0G8dT07KSG4SH9Tsnc" ..
	"W+VFAEBYnp8/OL3CjsLGemadC1mfHJIDjpAvo3ONaFb9ATL7VdMe+nWsF1X3yiDRWgysRMNyNtCsEG4URB7qL9RyBPtzBPj4lREf" ..
	"wyHaELURamqnqbGn7SJjLyf7VcQuaUK9hpbg5IgCLLJHJHKsjc+Xg/l2hiIBbFN9s1H7IwHqxPCjztb+crdl/t1MpA2aNitacd0G" ..
	"MXd55RU4hmwrVWUFO1kRcHTW4UG6CA4THNbjUpUg344eEGs3TqohmVQ4GYkPtePSVnGBQBMt3HMVNKWRIyyPzPcaVmq3gIWqaYDe" ..
	"6jgPhzOrUp9d+rdgLhjTrG38tLMC1CxLOa1ttUymTiA0XYn6wV4cbOmwnPUMxXcgJWE4ko2WxPcberflRoqtOEnyRFziC+6sEWaV" ..
	"gExiJIENRqjrmJ7sggjJqfKAiWaPEOtAsyKae9TJnvSojX+osRn4MbhOnd5ncFFYrL3mrEQp9348RZtnspxhaqcJPlLrDCNB+7Yw" ..
	"vA8h87/YROn9cfCICIsBPdMnGl9T3+lfC3EGPsI48FBQb1/f3uFIKhyal08BBM8yTz7POCEb+Ue/pwner870G1EdzNNCp8vRgRIN" ..
	"C3LxoYhpFavYpU2NAdpThR13K0GaOFWLt7Ss1/xwe4GCkKio5XK5u22zhOq/9gGXJDco1+31xKXmJUhfJrcveKEzqh5CLPDHzfZZ" ..
	"dW3FhHwyJTvX4cB+V7bXoqzNqZjlsEqJE/o291nb4zRz+DCrgfRWJEkj6JEe9FKLhcuS3v+3vkB8ueMIt1Fp3sAM5t6UpLiA3tZJ" ..
	"mIKEal07WiW64ZXJVWT65ba+dyMvtT/HqsAsNOBhYHtCh9wKS1TegEn4pGd9xs1BkOMZSTCoGETLXX1gEoCpF4xr0Tx/Tyuz7TJk" ..
	"qq3gcKDjGz+ryygJ6X2uWpa0SmsqnnS24pgTsjbbXdGU5tfUMoBik6r3HPGJkE7S/8msVoxnHXfCIR7E/EelAiItpTYuqvnOiHf/" ..
	"5U1F/9pACFKEIK7cClhRdvLx/viJmf1KJznDRDoeioNi6uM2eLfpAOQdXCeXM4BrjnXa/Kr/xeqqGXv1X9hXg5dvsDK2XIiKGO8D" ..
	""
local PAYLOAD_P8 =
	"Ic1TcPA8bdurR1KTauNXVZdf0lOjHMDvnYWd1gOjEOR7FWav+bVOYs1HNgy8abgipzlqR1Ns4fwE+oKOybHu1aYoOnVueo5O+GCV" ..
	"z9oXZd6/l6UTO6BIcfVlXoEndnftmCRx4hR9aDbrc4bwMz11ahjpUx3A11vALOLRbltE409n2n7ZPTXbJWETvdfN6EV3mAB2SS+y" ..
	"RYjVqf7NQpkIK09jZ4AaqjjRysBrfpRY4TJUJ/lbsUEjbye7M0lfsvOBSfUx70gquHo9ZxmyepgdGK+DH64zizui+RGriEZ2wLET" ..
	"H0iAg7c/cyGXmA+Azdq3QKewpxVC28IUu0DvGuK4bZwtid9sGIoEgxdDaORRFC0RPDXoRgu/YQi6hSFfmrGyhXyAELMJfv0B1d/D" ..
	"0Cy8kC9x0mPAcBffI6M9D2sltZ17nTTxmplI3F4hSr37kHDyqqlMzFxyl2ZOU8tFeVSea7oxhlkI69vWx47/ultZD2qTODM+knC+" ..
	"5HyMqPTmzMAAfc/KLDWYEN9p9+rv+Ak5N6dEVXz98P68xxwJKVd8Q4/N7uLGyRTCjyLQTi75gq3cmcGIhWct+v+BIdseZm+t4EbV" ..
	"eFqjNjpqpJrVQ2wAB6cYKIzs/7QAIKPbOZbbXgMagt4d+/qzA/9QD2jQAnadtPOjDZ9uZyEUVV2+SUs5DH1be6CQt7xC0CuZieOZ" ..
	"fO15jTZYj03pDL+ERSlmPZjgKCq9VUJlOBgcnIk3yIetMtz64y7+1X2jI6p+H1bYJaMR8k/CF1mmNPhC+fMywfdJoegYAYuFfEuY" ..
	"2uiVXJSX7KCdC8qyUsC6SCaZ1H9IkwaTiwDn434WWLA6HP1hnOrEd1Wl7fAcJf3sGXgnk7PbrFZkT3yrvcWu2wEwuIyUSoEafEAg" ..
	"sjB1uSpF38bxCkJhVe5YT5ib063G/AZAhAxwsyx+QMQXJeGnuKOhzyAqx5o707bQDyPkeBZnhovvAFt6EWty7iiU+AxM/0QfW9T9" ..
	"6gm+/U8rFjKqFc2UwhQmP/htd3XNPbU7QU18jDxU/CgMUFRSSNWtut0mF+m/p+LUZkILeYOygvFzJxum+qeWsKaeA4t1Gqg4rgWI" ..
	"1k0w2/+rybN/+fkBgvGGFSXg+7DAb7Gy+xdKzsCC4GcrWOXDCYVlLdIm+66EnZLwmY7RjlS5CedooPrQeswkIFJ/BAuXrN5cG1lY" ..
	"l16o0kdTcuakG0zpwrM2QR57xEG+OJdqQ6bY6PQQPl9tqs3/eOkLcSE5uqcT4KjBjbAIDsC3/ZhFYhw/0L3R0rZOK+SCwCGV+C+k" ..
	"+STeI9GARET2GqYhphbAJzhnr0FUlBWHJiXpeqE/X/CzgYbIMp8K9kCotaX/E5j6TgfmkFhOrefCv34QSVa5e+cuiIDJSshytSWW" ..
	"ZVWIg1tTq767lntn9hw7vwsTORxMv6b8OnS1LBN+tZIatZDhljsHZ5QhiFT7sd9cw/syrD9xhwp7Tatv5r2m7FMd6t2kk8Y0dRFd" ..
	"4zDpO5GMxTdut98aZJIMn1oY2su5IGhxFsz3qNaVz2j0c37JBkc75itqht9CWcmumruT/S0TxGUsDXU2JvHFslmGE9DYN2v0g7kL" ..
	"Q+1rkJNaXkDjQ7Jmy/emVC7XfdqhgV3HwhjmL0I/8rC+evJouK5ijT41RW92irz61koTHXn0EBK+YWOMGs5PijC3eOdWqBsrj3yb" ..
	"f6VrsEq4zIzpUbYZsB2KWA790fVqkUJBOGDDdBWKv94oYSTvJhp9koMU8oyz+BZz/G3musoAqPIKmk8FLCj9g+Hi/EaWDHqFdJVS" ..
	"NlFqF+EGzusIAgvf7UJ/iSLD+A+dx9lP9PlacGVtsGq7UZy+CCzeIAItPzmMlPxMRZQoipA155Q8De5wU40XUxFOWPFgVdhNx/dB" ..
	"AuLgblg2CyJn8nhpwJ4xc8dZPCEt8yVUwEUCZWwGRvTZrVDvp41MBNnRS98HOslAby10Rk3UYoRsbMjt7cU7JiWJ6+G6uP2KOK4A" ..
	"E9ex1DIzrRFeXPOaqJwYawZP3in3LikURrl9A5w6uWshpYQOMa85yguLVd9klU+qw19AWLrCos4e3GzAusrHNTGEyJWBYGdoE+tj" ..
	"O6P4wnAedEn/yBlPaoeb+d4lXP5dSrDKw9c9WvN6+cJuoVHUdAUdTjZS8FOw0Vvd2MjFA82kPMZy8ioLQBLmZob7i4cdrTQh9QYc" ..
	"2TL/cZPODpqj/Qff4ln2aDEaw0HQuIdxjhbwKS28TakTyTXo98W08u72tebWwB9WVScMGr4IklvNw+A0cL1+ibCqVHVumXhCnCDD" ..
	"nhv4iH2HAzIv0AADRqeEc+pDKS6O7GEoOX91YJodLxSw5XoEc5RUezNjXpa2JLjJt3WlrHuO8ECC8dCTZz+0sGr+seMhEcfcrFSn" ..
	"ihagnuEJ0u2THnkwbHze1Fq63/e/Pza9+durMIn/P7UswXRXdranrj6uVuWUbog7GA1aprrlCL3PcvlGZL+HmmXngTIkOJ4uaWXH" ..
	"Aprs/FwT5aMd+FcmxKdOGZPTN/ZtvCtYV/BUX26bNuCosofXHjjlasx6B1IAYgspM56coX3Cs8UIsPbkRVZitoSSVQ/Pu3xl0VvX" ..
	"CqnCnpaFQ0Urx9csqLLcivTGAvzPtenX3p4vu5kIgWpaJ4Dhfe6Eht8dD7DM3PvqD7q3HtiBfRSdRuaEBluVtJbGbP1ZMBRv0BwT" ..
	"89libtoel1g3Yaj4J9EM7hz5oQfVTjaiGb0R1dp7pTxs21FiImoNeoIa6E0Y5U+m3UXSVhI4pLM9dY1c/qSUVh0VPtDi5vT8Gb+6" ..
	"fGMSIaBqBh+l/bu6UPhKUWErc+mTHcIZIT66uWCkFdyDDsq6hvK0FZtjsEuA3QThbS5bRxchadIVbPJjtMZicOEih7tNn9v9uc7G" ..
	"TBEPK/axyahw3WlmaFINV2m19/AYjxzv/Vhbi8oTFJAYBWo8SzLL9CM6+7dzbvFUhm24fGLBnVrNuzN5zJbtDBBLSSdqoFmIgdrv" ..
	"6jHZ5Qy8gBOvmzpPfqnrr9gs7C91kpBKRpVW+JuA763HwdK623SD9ZjngVQ0tzXZ4QhqJJ8qVX/MtgIqcuBFsOx/Ajbsw5CkmGgC" ..
	"n7aDYYj+6xxeaQxY/xKAHddcgrsxRL+LtxkgGLgr35eol8fGcRcDfw+jG0sbBRsxhsHpaqqGPqs1P/PBb1xi5DykdMbKv7InX9O0" ..
	"DBfV+x9pFowyP6DOv+MbyNpCP5b275SC61UyEVzq3+YTMiuCwgUHG5j90t2/8MzbNACAoYiSiaCy2B65v/Sn77XbqPwpVWXdIcLs" ..
	"VY5fYL+c/8MyWYl6yzTg16hcop51jkQ0pV5eR0Lm7ak+GmIAV/Sxv9RJzImxGUHW20ea/3s+UNBiQIoBTYy+TK0RcfVLI6PQfiXC" ..
	"UOzHPvkSiJ4+n5kQQvOJDiB8YcqcDP5ncWj19eNbKEZGkWrfs+8lSoYIPdKhK+vwwBbnPbFdSlawC6jubKSzNiDqb8uVFQcW/5rp" ..
	"soznu5y8nEWpD9rOfitwpzDaS2cJcNPaH3rLHEoFH3MhKXQmYPY+T4C71bbQhojgYRG3bw7ENf3+fiISELAzsJlRagsDhon2TBtB" ..
	"FBbQoNIu+8EBRc/4kToUXqDE3tAC7tCIcqH5i699IcpK9BylchnZ8O793cwMS5kOvBu0c+780dZ++25hET+TmUJAIpRivdRQoQkp" ..
	"oXYumiklPR7z3l0EO5+QQK0inGYgiVU0dMIF9bMW6My3pgApLv5UdK738R55yP6ERqhisK25ijdpamD7HLlBEx4SaN4z+deYF9OE" ..
	"I2Ac1cKHmt5jquhWdIKlZbdfwtiJLjeFEA/S0ILi8tSYVk1zVLolfzSGpNnl+0drCr4+gd+bB5gvlbwRgIwICpzeE/avlZCbPpfy" ..
	"XF8H5PVE5VtNEcAVyu3wodJAbkLimfuRWXlPREJSd+DWQ6RnDkAfHLgbg+gX5WouMiS8LbLz99TyTwICInI54BGQ8nyNlyw58e2H" ..
	"h3r17NZs15S3qYgVaHy8d8whwiaJS6+o+OIx3SgL73lObzvY5UFXMQcpVqiehnEmOKvuJiY7xbG+SHMO5ssaoFhjKccqU5VhoIk7" ..
	"7nBYqI7I5mbUnzYoBw8HYhJlP0KL7GwhGcU78sbqSvrPeYwf+f34F58WvQHArxvI422383h9W8QOpsP52lnr1c77k5OoichHWJUn" ..
	"LS7b8JC3yx1AVHSm2vPHr25YAGlCVh+jQ3qTclxb98DxscuwmtvGEM8CYpYVEceHR1KpRhrYqn0YgYvFnNnX7YI31lUXE2bF6Fhz" ..
	"5GMggGYf64INpdmIjjwZI8CIjEWWpQtgVQawBZTEfTvvAse2mbjm4r+jGvELeNU3Y0Hh3CLUamSiikQ2Ut6lkQoXYwe/Ulz1BEm7" ..
	"rRBF7VCovvc6/HjOz7SLlfz5O+7tV+UmxE42Bs/GP+vXrWJfeI+JhPcHYZXVgHVeqxm6M58GA4Y+KYJOvvINfTqPKf0+uNk8WbCe" ..
	"hP94BHcpH2aEvT+zfTf8Y74h5m6BQv0SuRFboIhCsgz+4NbQ1fGyt/Izk6H3vuD3J3coHPxQW6bIOCMfbUMM2vyuiN20I1yYz7Ls" ..
	"U3mIV9bBZFmuQkkVt2MwCKKH3i3sUlmPqdJ/u4uVP4+u2k8G++0nxa9996iVk4HfBBg368+oahCjrJgY8NsWinrtndtu+fiWR4zg" ..
	"4U8h0cj1mqsJhVrG+5ekoLklGAAgsg2Vo8AORr/bgM12UXMXZVyN6ZjY7zX0KJDZU8mR5u6hVPWXtNmBq1wpRprjLS/ktGUaQOmW" ..
	"i0vag4Pdn3oMXK9/yZD38OpwhKql6iOZQYdEXc+YM5IDtg/w8/rE8PLzxv5Uw3sGlEqpol1LoDn4kKRPExIJrhCqz9gaxSKudE8K" ..
	"Tx9kWzx32gottDty8usbao3XWUUyMekVvB9dTlVoQan+Nc6urRPAVlcepO6DoErsGNj+wdA48KJWNX+rP/T7W4JWgOibjwHB6jzB" ..
	"OSDDKN9255Uer4hhV0a7xZMTiOMSOV3s7HtYPzE1BLVOISZeEDgk5G+P29dCPP1IDh2vRSzj8GyHg/OIgJQTmBmai7cHdN4VyPXu" ..
	"Sf5k4iEItwoq16kfHU7vPTSOHnXGEX3CNPLy9dC8BySI+/Cun5VvZm48hvW8nvYcc1kQJBs8lfzfzrye0PyQUJ2lMipv7c4DVKNG" ..
	"y/aebpOQ6EP4+xQKQ5P+qDYD5GjQ2ysAMDVaoO9rpKkJ3BNedAsHrdD6JFvH3BuvaQT6vNv6G6Jq77caV3sMOh35i29X9bXLWIRE" ..
	"k44YHlFQobiGlTATIg2MIsBk+7PnCKHirs+ji7dKojuX3HsDfTfdAWhTgQ8S0WgQh3tyh/hAgFhX0+60cnBmQQMHdw3PidhpNhf2" ..
	"+R84pu3DUDySITfDQr02My9G1ElteqVcdsRE66TvqY8zc9TviUpn2yeaUnza4/O1xn/c2JkbEZ+Xlx8pQsX/wj02m5PoLFraZOa+" ..
	"qN3XhJWJ4OP5DVhFNif4mXkKp2j0BW/E/AVBo0zioRZS63Ofpsq8XQWtoBxTcvkgg5t0grFrT3nhv4s8sJqrDrv8hur1tf0IF5IB" ..
	"e04CGrRuzwic5Drafqd4o4SwX3SoNHfiKaUAQSNHFWPzW5td5jweE1uZ0kLAf/oGxvzt/i3Fx6BCR+r4ToTzjkzcnRcDj2PuU6oU" ..
	"lckCyXJSKk7KoAt8AFdxZb3EZR6i53TfryQ/Zvu9gRUUmmHx91NI6b+AthBmlA1+ym2572A5uEW3OBQUBASahPq8fbu+iKfZdlFW" ..
	"5u3vCg8tL8kVfLNs+AmqzDWYmE5/Mhvo92SWVhKlx+ey1PzgekCplvj6wE5hzAhekADG6Grkz6wcUAjKVP0eRxs/vVPoqC0m9eLB" ..
	"wGfqhlnTUCiysnvM3Vl475PMMFfKGuR0TRchCFCYyQiKO4Z93E6pF1oHhTZ9QG5nqb+N5m8k93CRN6qeZeRdSdjQ7glyS2O31Jcc" ..
	""
local PAYLOAD_P9 =
	"J2UOGfY9Z2K1fGtIcDugh3BMK7Mkeimcxl6+p/eqBeuPTPchWbGIPO2YI/mbT/vTgYagMu4FRqiJLCorDoThPTVNv66acW14ucoX" ..
	"xxVZabvkwgqnONdZ/kvA+0HeYGUDiQs8ufvblu5ikS1Gi/YMnt87UZgKWdlPsGvMUZWL4DC6/LPI6sC73CajTf1SHwGRK4ghCFhZ" ..
	"mMAVXwkkFk36QqUoiT5RsJP/C+MhgBVcuFOsksA/UOz0nZAf+y9zN7gNIjwJN7AP7BbD8X9b+x6jSrrAi/BBEVTsRK8S1dtffsWA" ..
	"cukdg+Ttle+vu2VIq8hc4c9CgS6jF77GbWMp1RpQZb2FzpSqiFVnpnHg0plZkoRayUe1SfsG+ooz70F8P8iQKbjwNiCdFL6T9raf" ..
	"UcXZarc+AhQZQadkSxwtA4DaDiQK+Ls9uVwN6dDmQr9njZgf6RnILeBT0VnCePoCS5fANxRPRsfKKIFgihtbnVDjCOSlMN6grTL3" ..
	"XIDtTBgSsYdLHSGTDf1Bv9yB7+YdlnFVx5bvwtztCBee1i1lRbQfhJAC0ZVUtuudiybNHJOY6yVD2ic9IL3roZorHi99zHAA6b9V" ..
	"QPw/e9c3I+OuyYoLwY49CMzOIfR6oaX8N9jJQFJ1uvQqqONmg32jZi7jrv0m+1Fp8wH40XAJjwPbucXPSjva/C6Vrv6aJRKaBEDO" ..
	"MP+xdlFuKhIDNDqPUXgm+WOVXdY1F0YylQ1ETZDC65bL6morSZguCOerL86sIYMuLhBr9iy8fYhxhw8FaQWW6snDqxBEC38XNLIU" ..
	"ihoIaKCNcBVocJuIC1hwVD1RSz4TauCKf51AF5iz8E7iNG3BP4YgjJFesGDd9leTv7Rqvi8Bg240q9o+zSpVAWrkpPE0kIbH1hjg" ..
	"ci0Ri7QsCMMkna1Z+pGL0F0BuaKNHvX3Xx29I5FP0D1Okj3mtS+Y3tG3biCgdFTnwdl9vKmdZ+Uu2TQrGR0n/sDjgfeYKagXX8de" ..
	"84bL0J+BKNwGzfInUl7BHnNQRx1KVQ/MZsxPeERkvyKf2l22QzhlRIif7YTwlNsHar20j+KZJMWl2j4wxjpZ+3wv/aYuBvEqbuJ9" ..
	"yocah0rIJoZwCBbzsxR8EQIBJDVh5V8IwA8gizqXk72zLYFlU/sFVhF26JDM0VJTJ2VvGs5cMxF6Jig2xd/5HUNJ3g9Z0GQSXOR+" ..
	"l54YpX1oQK6DwkJkwl22OV0ZfzG2u6ZA5B175VccbVLvqk9tWLmk3m/qPwjTc1FH86MA2CRnvCtOQNSX2cjh5cRWi8f6HbBPCQsI" ..
	"TOEJWMUPyz52GhSS78q+gCkza+tTEi4ELejkkApeQDpts1uzUuRULNrwNgacHcWbARxL5lvlSZcXmpsf944mm7V1A5gLMVM/51aq" ..
	"HGgJnbyW4WBhFBUKjIS9dmYBKpSWeskoUXdjaP73QX858pQpJbbT7jpOpY3AN3SkB6c4gSGVJwVctqtwxxq6xLZg08td2nyeDwd/" ..
	"XA85lncYwABdmAYZVDr1a/q09/TyZUrB1NseyXJ5DiC9Mz1GSz4LeLuo9GisUjjy7QcpiNRkHD8GvmOuMEOrpmE0qgQ59vrYmwJ/" ..
	"H4sAeNIzaGdgI4epxv2sAFfNqxZrLLak3J/6hDAO9xa9ciohDsx+YdNmz3A8psv4JbPP4qVECoEmnF6kICwKJeXfikcySLGXFgcA" ..
	"dQQdCUDQ91VKS/Dmrrflyo+Zvc5bONohj82npbghoth8YMv7gUrrO/P78uhgRaFVCJtCuml9fotP2Aj8PoVEqctUAEmgyndKtDlz" ..
	"QC5sxeZqAx2/9spL5A8cIWDL4MRvGmfnpAadCi208h550G+tE1Q+Nb6SpV8HmizokyIQhbu/ta8qkUswbDv1ruNYjluFvdPzVVY+" ..
	"h2OUq0pnlZ7Et6Uw/vDFCdwrs60BFkQT0BMowMbfVSAusoGBJz4+1m6/ITHpfMjWf5K6OaIgzNRG6w8ln6i/cDqRAI6Q1mDLr8zn" ..
	"3yiPZXAIX6sAWDalDZ1+cgBflFCeCqOmTJrQ1CvuLnCzWO1D2RjLUQKq0QjXmZZ2SWX3byOvR+38ZwKtPeoxsXKxkCPtvXw6UkH3" ..
	"VtDuEmmC5gNE4BwI0pygNMQLOOIkPi3erB3caeFxXB0EpVUYBki4vFiaX2bMfh4MDblYgxqxr1sheNLrMsNWBoSKCK2UrPnzkV77" ..
	"N4WMLle0yrQDOWhAXbWiLJWtZWoOdQQJ0Fr1RQ0YcBC8xOl6E+IPUpgAS2HvbSuRlNQVbDz8A7/mFmH5V7vXmN5atOggAhsj9bov" ..
	"7yspuJNiE3hqJxNImjYFToVsfKsvWPc3SwVKEIAQe2EJDm4MingA3I5dmCMcRLHUx1SG9ESSrSpG2Lt3NpMSa8HZlaR9pgnYCG5V" ..
	"nfVCu297d8iiK03VMO+11TDtCUcFZGNX+NEWXngL0DCQNWpJGArSXJQgLZIFyk4cMZX6xUqrUj+kBSSk3SHN0XPSuCfOowrsLIBr" ..
	"ngFPBlIRzJaCIxWLvTpVfxW/pB36Fqon2NfAr9e8pzTvTZN9EXrDzCLjMcPuXOSlK6wx/svglkXbfu2IT8IVBu0fg8UFmCcyITJq" ..
	"WT+/VcdfFPz+IppQr0V39cApFRRitxM3JdEikQXsp2IPw0YoCPXb409jPLVa1ia+mwPStVSFVsPBfdur7GDhi/dz/YL37oMKBW0v" ..
	"T8OPzr0ZAed1uQj4FWbPz10CMmNkX2r+xZQrYHwi6Mq3kutzQ7xHmYubE6ot6WhEMOyZYYIBRwiovZeAwJHSkdYq6KgqIvzd9lfe" ..
	"Hcfo2xuflukkYb3RZdX2rFr5IZmVQBVWqaDaHYfxnukiedAqulpRLzUNV/x8AXdCxqxyvi1AN3zmfzN/z3upGGNqmzDX2N3CM/64" ..
	"OJsLBAeu88Ktx2YL7fJXPNNWsXcCQD06pRC0eQV6cA/jaUJp8ro4pl8KPBhdY+m28GVjqJx48xQ2EwI2VZ76oLFrKxDR4l+X97zd" ..
	"qUyRu+JETi/0FFLdlB3q4GZsECBH98e84MxIVMYyM8Me2GQtTHYn2QVgNlBdCtNibB2UCeQDU/bXQaoXE3cEa7R4AVGGmCaT5hn9" ..
	"pKv0J903628y3wwzywAYq/9VOHX/LS3ETFvadEPXFanuZ29KYKt6Oe6Y187nItHWwqRhTmmmb61kcwxiyJ8ddRAZS5y1XFLRQZsL" ..
	"BJ+nv5zjfo7xBpBpLnlrWs6g5jyDfkLL7c9RGRxoKy2oVQ9EHd9CYBafdi4+iKQrxC9SR8HYc0KZ2SEwelgo+oS30AUNnSW2OW0L" ..
	"K3v+arNOKKnJAiCYZ1r6/Z15J/2dZl6qBZKiCxU+taUTzZtuH9DpdfBVtm817WMGs2jcjW10ce3iZIpks/X/+pGq5Yszmn7qw7g1" ..
	"V7hhFIGtvN7nIOZ4rn3oXRyo+QMfAD690tiyF7DR/Bxe0HqkbE13KqXpN5EPJuRgquiocwmjig+R8horKoubyBfkhNUyTyXFb0LG" ..
	"81Khf0ChrkM9akDAGHtXeBiECR6Mx7kbUfCEXS4yVq3GUZ+5iu0qXP/Kgp9ueOq86pCq2Gr/9g5yhmsRymsEd34OvP/wFNTRGpDV" ..
	"JZ8Zhsx/sLy4dsMCljNcnU18Tj4uNXrjQA4Bauj0c2qUzDXGlu2IjCRUDTQpNsWJtB2Ib6DMmNTCv9T46xaGiHERxn8uHdoffpjH" ..
	"quVEdY/2/1MBrXjDsw3Wrikm5OhK4r1vSgVxDbxxKesovKyaGjN0KOnlQCUxERJvcJiElpGt+6h+ZpCKQBr+J6QuxsVUpToL+Gog" ..
	"58wJ+RZGSYrmvPJkfR5tPDFiHS3VisZnJnZPH/2kU6R393SYwGGnXGMM7a4PEE/A1X5FJhaUMAlb+6ij+BufZIfNvjx2lzt6Rfc2" ..
	"JhVGVi5acWP7CQLGy9Uq982mBkIUgLY8DQpXde/IOmmXSnVw4h6J/6qtwulUZumkq2RrwJWGZbSa0iYFcSiP1Fue7Z2xoqaaKuyl" ..
	"+lvEyiiLw7AVgmbEF4kLlvFxjOU/LKN242GJy6t7hGhPaou62DapC3NjBW5fwIhUV7UIhl2Pmb0kl1wPqVisdcGMLq6jymOrSPpA" ..
	"tz7ZCTvzZ0mbMT6ak2NZrJrB61lnv/qpfKBbzsgHN9z6sgV8i5gOW7bZxx7zVvGWiEtMUrpsbfInaV7SbG80UvL0YxGlTIkDPGfu" ..
	"MQb472O5ItLVdBAoIGPjgJI2LLKGtPpVkCRqLOkAS/nurpnqG1V1W3qwwyxdoii9byB/TEVL/L+Ce/6X+Ch3XfA+i8y2fLNM17Js" ..
	"sN4/qVuCDHy8VScNrvC4GOQl2JEERbiw2SFOTByBz5MEgVtM6AJoqlpMlAcGSC8SBepLFSYOX1uub9PlpNGZvU1GbfhJ7D+VsNEe" ..
	"ssOHi7g/DoqJKp/a09/u+hbmrWCpCkfTJvOXUTPWnZFBGoBwBMXhjPIiyH1RX2Ab/K8EFmXgojI4GwZT/wMVxvTYLY6XXXqFLLFO" ..
	"cUSs2bc43awdgrpwQi9uD23x2EYnXFH6XF5M3AxR1AE7w86OVt2/RtegqwtQGR4JgFxKkQyvNwCkqbPUac7Fa1HDzUjTimkFzXhy" ..
	"N1iasr2VVsOEyMukj2iur80D46ZnDTZDlRU6qNNHgSyOEK3AtdN61m7pjBD3aNyeYLlYc/G2EeVXmzyvk+IkX4aIh7OUtiUWgRLO" ..
	"cBCX6EYdQ0uYcz9w9d3cvHgKdIhqxyebTnLIirW+Pkd5YKVsNhuiTqq47Vfu09Yrj3O6qXzaUak9ETU/cXif+lLTN0eKn58BCB7l" ..
	"z6Ztnih5kIzbE6Yw2bil0brfIj5JBPzcY113TjKkeGrbMMLmduUuNR63tfDHfGDWmBGFJ/GezA1wIUmmP8QJFQulG51wINYGx/5c" ..
	"hGKnN9czH5WtRVsBpYzJEOOpCA5J6XQk2VrSa4r3o8Qx2sIWbOdipXjeVwywUWxfcr59hUol2UcxbaiAGoewCNAsf0ckWLpy3rhp" ..
	"h0aUJN9KAb7Nu4l2PJPw+k6owOaUY9e5hxoD2hvDB8gxyPr1f3D2v+ehMU6f9y1o9g125Jk4qCC4YecsK+NMhKibZnRv9zmKmZCa" ..
	"k6qbg+9ILUMrUmIl/ADJEPjlVBFZPbZEpJhgnyl/rArHa9wgW5eRLGkIBhhvJaLfPzXCDx8w21dOPqx12F/Td8tmtIkzABSTqjI4" ..
	"gK69u6YyQSukwbA5z/XA3C7Z2HlMhDjNcX5KqQKdvucqW+6v1Js3QQYY+9BzKl9RKEI/qxBU4HtZxzqDFOPTeOltT38ADAJgvmmb" ..
	"E6/dTb6J8hRd3BGhLeG9VR+eiosPVzUMyO1l1Z7Pvf8TjRD/2U4PlelvmdYBqSSirn6t5nbq7KXTRz1vyMoG0IBg1RdNoz7Vew0L" ..
	"Xx6/wiVqWgcQI9/32yB/mZpCi+mynIwR52PzEiyHOLaCbX5syXcBpHFfNCRgty8WPne732R/723DqcNYwmeUL+FDbb3HOIZdl+Gj" ..
	"4f8zsw3folXUEtQUcrrMGN9nrtm98ia+nFBzYLhcvpm3fOOJbbBlI1fIyDlkYwawMWLdl7n5XrdUJxmv0Rn6bziRlBvu0QgsxoPX" ..
	"gRjV61pBxIE0H45mAe4ZYzJiAUjQlgKXGEVmtdaTf2hF375SzQwh29vURE96yWlyJK0UxnSOUTtn4jTnukh5DiQvMQLLcfJjqu0e" ..
	"wxBBu00Kkfga4nfhcd4MNFxEvc71Vo/cZUrwtTm2kixj2MdIz1/NotCGCKUrp6Ghw54t/QC1JnOnfbdNl4FABtgcvg7Km4CjWyfY" ..
	"SlKCx9ZKj2zEH6H20q6ymukK7iLcvBEr9KkQfjA8EfNeKHtAxPyFvfasyS89f/gJrBN3SmeOsdXITKPgAc+24Ua23epxLV3CgOi7" ..
	"etls/c33+ug8zxpCdO6OyiN1Da2MdomnwxeAFrfDE3k8K0IhWXg1cjCNLA9VGeO9lljWWAn9/rwXuxwSHvbB+rKmDrrhNxJNjhiU" ..
	""
local PAYLOAD_P10 =
	"n665hFh5jKgB3zxMmSIji0XhpgXS0UzSUOmoD86RlCVeB/I4IjsS+lRNArci87ztoW0EBu/c6fwqN41+0dLpcVhjwE55cK2gNUoU" ..
	"NRLDSPBIWTZRdzzN7BKE9zg4vhOQNYnVZkBxkIDcHqVbLYmtJra3lkAiW/OChVkWiW5g+/5pZB7VGn4nXWHVDbIRzVi1qHdoelsk" ..
	"IYndrNPpNgRrxDsCMaiA1XGpwAj7e6cvyfHm2KvEuxeUNNdLdDqyBVoIBP23mzYVJGNlX8Oi9H1RHx9GYmvpDqPp58AcvyeEFIZh" ..
	"zI2VLw75NCeV+BbqVCaKX4QJ4GNOiiiGGh7Ym9t77NmhIR0+Fas7vn59+H4ENf1z4KovzsBCcLrFlX81pLJINesJaThgWvpIrXZa" ..
	"u+Nc2GX3cRLSHc0OfNafbb55euzW4I4xF9eRAIcIz62Q9kVHZZ09hkSYvvdoDCZZ0UMLf7vpZJo42TQc+wqHbTRQolAUtRzs4hvt" ..
	"6DzOFp39m39s2u5X4qXhaUufWkVONBAW2mR7Qdbff/fkjwy87lecgEZttqbOpQRUqeZR/RbtZ9IPb2WGhQMjGv1QYE68HZQYVIbB" ..
	"eBDF9rIW3yx0ZhpT7lum1+U+TRa/YgR9/soDUlpa7CMmkdFj92kPjkTiPJuXgSYMf1RS5VMdBJVnQhWygT9YeE+vINob0dIj0TOV" ..
	"V4zLKWbtcLkqYNIhYw==" ..
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
