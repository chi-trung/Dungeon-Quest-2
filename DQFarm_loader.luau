--[[ DQFarm Loader ]]
-- Licensed to: GNURT (1 thiet bi), Gnurt (nhieu), 1 (1 thiet bi), bakuru (nhieu)
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

-- teleport-persist: MENU tu arm queue_on_teleport (armSelfTeleport trong
-- dq_menu.luau). Loader KHONG arm nua de tranh double queue khi re-paste;
-- loader chi can luu source da giai ma ra file dqfarm_source.luau (xem tryRun)
-- de BOOT doc lai sau khi doi place (Lobby <-> Level) va chay lai menu.
local KEYS = {
	{ seed = 2776144187, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2768304429, exp = 0, plan = 0, hwid = {} },
	{ seed = 2768870728, exp = 1788089514, plan = 1, hwid = {} },
	{ seed = 2770071117, exp = 1788742721, plan = 0, hwid = {} }
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
	"5kV/NrYU/JZQDGEHLtCnBMFo/35qBpAyygMoBre1q3bslIuwqtt2l3yaR4J0H1/mN8Va18phqZhA0jvhkqQITnf6etOFd72N0BOT" ..
	"Te5+psN2JXf9SRtGTtrkxR2KOaEK8XKme7LezueYzW95y1eJtXQsWNLea14yBMOYoBRpaOAN7JTvPOGHNZ5nnh57SjIK90LKudrn" ..
	"fYhbzQZx2YErhKHnu8y56tCB36wvkphcByaNXPd/UWxvqyYiGBpWfNK7vbqTxk+EYVJOLJ0U5uaIESC/WbK27N3XWD6m+xD51+Gd" ..
	"9cW/LfCgMhVIrsnthCKCvV6QDu4wMmDNJTtQzVJGEtFKF9IH2bSmhqjGQ6OgH1wDTf92NG11Tw9H/AEF8y5tvGYw6tCIP6vj3zoT" ..
	"ULaFpi/X3ev6xAoTkOoBqQ2deO5mB6E0KopuyQ1+ncZMU+5aF2g/K9KP8Ayf/crkAglwg+zq/HT8aCmpwcfU0ZsXK5+NahkhaP2z" ..
	"G+P4HfcJxkuXZcPYa/RBaPj067hgE+Y/zvXX0Q3A+8oafrkRf1LIjsAmhJEz1Mx8bO+4VG8aS6/DgYBkEnDiHSHEmTguO/2JM5Mm" ..
	"x2ktUnJXj4Q8TbL0b8s3on2xU/FaGQYOFF8Wbb9hCHAEyjcaJU1BmdHacoKaA0wIvPYT1Iyy8A2TxZe2F3r63f+iQ50txnml4Mqy" ..
	"VB0UqweEo0GOINapoSnDk5jqUaHHGerBoev14IZ4s6+DIW06Cpt+PQuJ5PJNz2gWyKLz+Ot0KgHN8BBWtaRZo8U+31KJ661sicCh" ..
	"Mh4H/eSGSIj/njS7weHfIp6GJmxv3wJgBxUXJp27+MNjxi6FE5wsbJb6XE5esXh1jqgq9UkJouJcRk6wH9hiz1lra4PKUbreQkZO" ..
	"Ecw/IV6g4KaSLLh2qBLwdDhb9JW/3csRzIQxOd8kncD3QXCFWzHkOrA1dkNuTohYnUqtB60FDMqDz8qorvr0Rx8thujaFQ7u2lS1" ..
	"rsVMAGJXjK2F8PewDceMGX2hNrKmqnYpH/FVEu4uzInv9BTdSDU83j8VA5q6QCzG5dKJneSliN36h2h/dk7GhaCH576GeubcrCN9" ..
	"lc5H4Od1kKTqGHOo4NbP0/i4OgT7b7LP3WqMNwpLmf0g92HnjgcOAhG9js2rSfx8vbcHIWjGG60Nlncw1KUE5lI4Kf6bfjQ5FI19" ..
	"6fM2DlyhggzN0sc8DHJhwWN4xsMvyfcYCawnlLausKZox0ngpnBHCpnyPe2kXQzAzqdaD76MP0wM2jymvZN0sDVbP3alGGWo1uUp" ..
	"EGyTh2u86cpCzRVpyTAWlHn+70RlkBN+VgBEja4M1Lv8axyBgTrdISEEMQ5UF3YdFWikQ4lxqS/fNZZw+LQHumiKJCx05tFWB/mP" ..
	"eA5IyO3bgA3oqNiMyf8htIXXsRm6DOOsTD49RUO57aHF+q2pnHgWH38mg/SOvSZKOqTKkWUV+S8lA+zmjjbhpRi8rYRmAa3bt4wr" ..
	"NN/1mSJJEFb5sPF+KMKdukUkH48ILeDLEIVNzlx7YAoLloNtQM99IlFjFYpkBFaXy7LWggjDt909lHhua73k3dHTdK4+AAppop5I" ..
	"lsIR+HhrwVcBablPMSLyyeMj4rhY8eyUffomK5cUPXq9dk7u6m+xxr1qhtD5P/uMJ4TdzzZNSL9XXbN/rIeL9re7lCTmYdW7d528" ..
	"S1LRMRKWyK+aDt2zfv1ZuKyFkQ9yC0x4Kyyzn1eTZbU+pWLBZJQtGiW4HrnBimtKRaJG9J7F49Isjql14xZ7mneEKYvdixetZiT0" ..
	"qYrQYo1KGK5F/Wf2NqZUEcVOdMdp+JWqFeM6vm/c7H9dG0jH5ctE/6/sVSrcDPqQs/MX+x59TCKZhBPOrWrtdEVuYZShMC/nsXGi" ..
	"+f246I2Qy90wPe/ued7TD/zrIDLTLpg/Tx1g3RBUgT6I6vMI6QCXowzUeW3UmHw53oR4GzcjFEPnFr1/MjA/munVgGuap95nOzzY" ..
	"nXNXrZQSaSAvH3854Ey9eQcReLvx+DWMv7vVQM+pzQNGbJmsvkTMU37vYIqoNnYIgFSpzBdfu0lJocSLDL+Cmkv1aa4UBsDMbs1Q" ..
	"Yp1K0xMBYUeHEtSb1lApJXGdFxvu4+nFWXMh1X9xS5xiHUmg6N5A7cfKz1VjSrlFhee2rJgMSeD8MK4aliR5wX6wd4G9wboTYMFn" ..
	"BdOJxad6aFOLFV/bOUQ90YqDkkof2yAAdmK2rJ53HARSwg0z90w2vuanwg6x1TVn/c+4qjWhGgE62f03ggpDZIS2j7vn8WObzjP/" ..
	"mHsO/iKAocy0FBmInkyQaM5GbBTDuuhYzqC2ru7Vn2Owq3kIejowsBkF2mMgYWc4zR/HfVa7bZKRqVQEq6UkS9wqjixR9XUCIagQ" ..
	"CjLl6/YJRSIPNVami/A10FFV4GHDGXPdQEwMKDOuGriL2mK2NctEwXcfTI5YHsn8F+Uqwp88JMe9Mb7UpRBYbROZwoCVCB7+SnUy" ..
	"kIGPiSQWHidK3HQg6G0sJiCgDnekAYRadZhS9PnvM1MHohJvgBBaIwt1Pu1TPzkZBUG7G9uUaIUsAZIcRwQblJZeT3mQ1Du4E3Nv" ..
	"ANWQhbg6Qo4ueohurKvALBIloFp4UJ6CfSAovEndExDAHZO+FTzHpervmQ90lU4TXoFG78uGtseipRWI+nVzt6uzRnzXZp0EEM9y" ..
	"0bhcKSLbjjz3NjlZL+dVLFwvxaf6mT/2vKIQswAj/tu90Ii6buM/mBYU5/OrYZnipFIKEmxSnWjCtM/1R0H3WhG7MMvzxBudS+cZ" ..
	"G+LRJxF09kzys8UoLzw1/3jfKPG4XinBrlo/RCMeFSHqZCIsVGsVZyAdxeO0MIavVcFN0+i+A6IGcOwf8aIjZYTBTJFYF1DdeuVG" ..
	"kR03WAIY4XZSM18Fg0kEqmqyO3bY3WiNPbSVbdUKdz5m2VW84XFREMQAMP0rKZrAcavL9zk9WNFHFU5ajiqlsrR73HhqGUGGm75o" ..
	"L1UnWHDr0/f4InWhRe9l4BN1gQlKwodBgn4MNuz54W984TBwxG54cTRKUkn2l7+6LLR5lbfA4ie3qj8T7Nr+ynAtnXD5VDRIBsr1" ..
	"kbzUWPlNIALtX7jwqLeFzlsoPzX5WKRdS9v2yScM+4AI6avJr0dgrFth8W8QgHd8CdfS1Y8a6LmRFYu2bKmpPCSxT/coPd98WIY+" ..
	"jwov0vBzgS/sObn+iTkcJ9st5n6Kx9xIcB7czvtEihfqcxYjrVJzLszjrj2lq9IXNYgq+VuPQZKNnIvg9dJ1iRWe+kRvFtCpieVq" ..
	"IYeY9ZsLR6kwk0uofYQrwsafZaEwDBdvQ1iF2vsFDAFEgu20lub9GDfeDW3VbmupSphpu3CbO1QdAOEFhO37mWJcb6S2u6uOB0DR" ..
	"cBskLAbavZA7J+92ZWuvaMHOdxqAW8CNZ5kvRRxqqjJk3f1EaVZfAqwWHB1RXJKfOcO3Bu4aGwZ9S9DnIVoxgtMcIIqWr0Qn1ktP" ..
	"x92YykFr4lun7w6dke8UUML96v101+vYi3h/6YMWfA+GfrTQlI5/9EsAgQqtsK1cCbERekMEC5OqS7kzvSrTKY9o2N6RzWPA0b8o" ..
	"4yvMblq6ZWJojBP1OTLY/Ulg4qv+sgJ7DgZfzwKQLORlmJQXnotuGoKwHTgohQ4VgiLVJju20z+2QMl0GpJqTOyY6cpPT8tMLuT+" ..
	"rRbLwP/P22ufYaskMLvacpxZQ7iTfQVBvWSRElRckEKxNeK/gjwlFpbS5Viz2/1ZxNtnejUpeIQPd1+kMtocshwM5qVjPqmVUVS5" ..
	"1RBQK6hNcB2yu6lf63/U5asDnbm5q08BELsCPN+YSrFkrLOOeB/IdeWmgOUcqSdecU8Z/vgfRTHgUEwO/2tnj2Rw8qky3mAGDKnc" ..
	"XXaupAKq6wHsCq7gn/Af9LIfSjiPhqiuxOKFi51SzwJBJk7Jg1pU26uUhR/Q6DAQVz72ylGivv7WTXxWme2eKWUmlxDyDyFsl8Zi" ..
	"tbhpQVp8mbniVsdTCIJcHqhB3BQUm/1PaO+bao8/sw0b712WKcMKAo1HgmCa6oIplcwMrEXs6Em3FQsGl6Rt+F5RPjcu4KsPYvKv" ..
	"D1T6S9UxS5QkM0slld21wm+FSPxMX5TzKgPBK4VDP8cvTuJeie5erxdB5jScJrnuu4H+dxqJ5AmlTjo0ZiniMffk90NGHULMx2UW" ..
	"jgS1LumpjvJC0lQNlQO8iktgxIh13EytbSDip/pEeRdi/zeBwYC825vxzWgmHNHgFwQzR9O0ox7vZjjx11eYL0XOP1ayrCRxlj3d" ..
	"mUXhd3i6B8Wr+XW+ZS0B7SN+s0Cg3sAMpgQwQ3hG8Jw9UUUeQsBPIw/ZrzFboxsaB2aOweBCz9yYgBapoYsXPXWfORkL5v1HX4Kf" ..
	"XHlkrZERzx8psjOrIZnr+QRSmB5dM6iqlT/oTBNf/C6r3uMiQwO4c3fVfyO6SuooBuOB6QyDTOgqz696lpPARAYhrx7vxEk3tv3v" ..
	"aUtB0Z2bUfrmGR8KYdzapkfyxg9IlYsf9ENGDqomoqSMkmoPM2DFWvDoEJhoi4xhS0fAFMOIVs+E9WAsBCuuUIk/nAEmDVw7K6Gy" ..
	"mjIsm/2kw9Jh3wvuovjf44m/L7v/0EXZgB4a1MJwt3LrWKJuLP1exZvtN3vV0FAuMrewdnIDpFom4uIZ1ptQ1niKFtJIKtIKnIdS" ..
	"e1GUtcWvujTzKQD9dWH3kDAMybXidtSucCPCVZiX2hJc1tfLuzy4tayKbw/0JQCfIUxoEv3QW1IMTFSf7NGcEdLjOoY6/UQeFScT" ..
	"jZbHJYhk1dCJGS6/s7vKI+Bex8mOxaWKleDJWIk6keS8UOqKj8Vh+fVs/RmRCA2/rWrnVMjQL3md3jmMd8OaSvjD/TZAItIfHVr0" ..
	"yXbz1AidtWE6WY0nhutXGT2xC0cZ5BV6acokMt0EiyRKKbdPDjgfbvBTdlygDxrI7x8dElXbT18HJL/ARdhYRCPzJWO444YieXuj" ..
	"VkVHA7BQHPRNCKnRfL/Ic4CCIYoUfFVkWo0bHXULTXLNMDfIwGTNJ5UTexbf7Z/ePrlZg8l4ZTaOvPzjFUg3BZnSWNfFO2noUFs2" ..
	"7rCV0GFI/sWMUzjUkCR52TF8AIPYhJXwUBYggRmdad4MiBMBUKv/QINALWFW3ZxfaAdniPlLXOeWW9kGrpJRu0X2atE3zr0pKMyW" ..
	"4k7FHFNDScCrmzw3gPEogTbH9pYSg/s4P1nConIkIFeEBxw77rj4UY7SJJ4i0bhf6zEWm50kBgY0Hq5KoRFDqVDpw2iIVpo1fsZc" ..
	"vvAhJr/vsI5MrKiKVvpWuy0Kj1qVpZedbrD36Z5MbhX8M9oFJJ0lVUjEVHaDYYBPatVOI87sM4FSC4Qflrpzak4alTYcoMfveI5u" ..
	"5VtoBpJ3QJWkajukb1DPdybirjuzs4ZLqA64uHUG/8RHyiZ/pgPMbw+JCyyhjy37jYIj0G9Yec7hxK89cbVGreUZdotk6pjV/GE/" ..
	"Ut04gt7RdDgoqSgU9AhE0x4zolJB1T0Wd5GEIo3nNhwYMe7EEpSzSAM73nKVcErSY7U82HtetIbJaUe7DVRvhnwvtB3i4lOuNHGg" ..
	"bMOf8xz9F8fCuBZre/PPhd98EL1CCAFXGtnDDpIS1oMZwTkxubL6XuSFBOATVQ5TtcslWsSYzJC+RnFcj08zC5Xdf/a8Nev2k12Q" ..
	"ws1tMkfxRZ1O0KjjudC9lJhhYuAQ6xiuCyCNvQF6OTxHvvJ8h0kqAQ2mDj/AgwL+REWuXLEjQM5KsoWIy7Pl50FgsKaEZZGjfc9d" ..
	"7c9KnTIK6VFndIkHb0SlSsqxq/z/qVlt7K6i+ehi9QpC/sguOAfrp1YYPDscJ72lqyYEh7TdEIu/Yp/e1wqdCyKUQhpBWSXkgeFu" ..
	"BvmUjcjaOxD77khGWO3lmFevXdNRikJ6ZyEcZZL+Yks3QehfFIlfq/spq7cGM2EaGcdlPJp2aM/45m/paLAfVWWMGmA3f/dFdgSv" ..
	""
local PAYLOAD_P2 =
	"u6F2feVY2EHBivojBF8XnJsEM1SSTDvbbeBnqvqElkS91He6BdQkCHfOoRW3la0uMCyuXYGpXLsHjS6soPgPqnHz06Fsmk+QFDt9" ..
	"/Ype48RjtGh3SjGy9lP1uJWosTYS1TWOx/3vQWbkPiPF+fC3QkQ65SBCJQnxqucmrFV7HrLU+WepKH7KMdYpCDRVokZxFfPgLIJs" ..
	"XGReNViIbEigV9LWgyx7qIJnh7hqX4YzZBVdmBDVBqCYUonlY2fC60tTGlA1Jtuk4/4eV+It17Z/Ey1orO4V9Rr+OMxIUxInaF5/" ..
	"/4N5RzbqFSkX+dBlG7nH0KiNjQi7HTUr4Mvg4u6I79HbOr/SiwEDwtKFip+xghJ7idHnMjpiAq5EjwyzwoN2FiR/Pj1Sl1x95QhQ" ..
	"kCD/rPuqtLMEgF4hu0+nysVxw685zm13ORDidPIL1pZoCFbcTk3H6IABshIeaBBKDVkHhNrBsLU9f5esK1elMRJTMIa6yzHa6VwN" ..
	"qB0XiTDunvCjE90zMq5IhTLMEr2O7MBX/vwOwWj4sxmNpCsasRH+1TK+wwNIzxg23zGxEqVqp5QROJ71iB5aCeS6Pd0hPunz2BVR" ..
	"B85FQIpFpaqSGscUsg/2JQq7My4R4VfUUbDzXzugS6sVdyQYjEZ8KYeDc6KV9RWut96tiWFNwD9Mdaxv9udSz+rxA9iRQIP6ZSP+" ..
	"kLP5A0Bzru5XkoLLcq9Fa5b6owP6adWmUvJrB8/39TdDmZxtDMMMFQk2ZOxMGSxjkhKD4CTqWVKq7LFe8AolSc7W7/3idXEvw26R" ..
	"rZW34bsbiiCKJvXi3m8HpK5KMyTjegALbc9OCZfMGX9m4cXQ+/3nqgHPqsmu1Vk/lr0Udzcj7/c0ho2vK9t9aqmSXFsrNA69+5v0" ..
	"CznRHts2Dhhr37CqWKPRLj6tccWY1cw1lGxe2rhn4VNh0r9WuXhFJZrUX64fZ8glnqx2EH0vHLyYQWwAPigAYNhqNVyaNVQHedYT" ..
	"+cfH2KE+apj5/UPMwvNJ6xxI2yTd8YiZhLs7eRSZ4y8j3JC3C3GZRqfJHKRxrk9QSG7Ki9Y6H071huPG7OQr0b0I84edKRNgbLva" ..
	"AybR7FnJQRe8T8DjKwNmJc1TczuW4fqub2TRQsm1J6pYwxeNMFB4hhEcrXKoeb59igf8upUstx0IyByAOE26BEIcIr6ywlCwWuVD" ..
	"20VK/L/S7UTu0z8wrFANiXZ2Gb8TSaBEwaTeDdlv+96mrpyinyBfif8DIy1cTWRVCjNpVO/rUns/8QIHDLLf++MFb7aMLaL63zAD" ..
	"Ms3X1VGGcT+9TYs0sKrSE/D3s1F0wM5EkHj8rLcGkR5QtRL52ZH7oBmfEnKktDqQjfMQNUoOgDcF5ZAmeEWNWJzNf8j8e0Hqyot2" ..
	"4WQPz1hj7Ex2KlfvBWgzT+XFL6ANM4na/3CcB9WMBe/IDNJ4IVAuHU0SK7xXMn5z+R2B9W9Q1jU8CjXBYsPmMxHXH4DefIMojx/m" ..
	"mxIqKptwpd11ZvlW2xnWF7qbEdQnZjs/zyPWpwTYZgpHwxFIsFWi4/MIaMTriaFVx2xZTPiDaZ+XQHacNSuUvUaEGNy46dQfIxyq" ..
	"LzXyKTaIGPRWDPk8ZHGRYHRnXfKFs8oY/F9ktRyeUKspIM9P3EJ6iwO4QPFD19+JOP1TWfybG5WEX+lDPbaquVwfDB7mKjPht+I7" ..
	"otrRtXv77OqaSCR/To684EqyloF96midsxMdK6yN+LM5KU5YTJ3Qhh3dYrml8rjDhZbH6Z7VB98oRRdNK9OQ/ui54MbULl2T4CC+" ..
	"F45Xwbirt6cxaowp6v4uXbt7c+glEQFqdLnBOal0DHRfm8p3gMt1d+XYfRt02xIHtEdkwZyA2WJnOwuS4ByGoOIMsXpbtoCLcDRG" ..
	"K0waxWQ1apkcz3hRwYQNATUglJ+P9sr8fYmQbBHNuUacHOY/sQcjXcs5YjeFEoFz2KWo+c8UxfZNIBiF9ouguWwtqlQvpGGqmia3" ..
	"o4R7ne8Puf5n2Uzbw/IwQ9mY2urk4qqyF6BClCCMbnnarZ3Qqzz9xlmGalNwS3jV4DNdP/w5OVoEz4nlC01zsLzg/53x+948rZBB" ..
	"o/SuapuHiT2f2PS/j3IK6VdSi2p30Lg0H1yiWd5i2CzaLFqwQhVH16mCriSeTIwrhUxJ3BWEVQAWGdHEFRnKEh6NjgNnemmdmkbE" ..
	"7kzNFry64AeNiy5y3AISCLewc1smdkrahOPiIdP5AFyJh7rYYtcdt4QXljzkC5sxLKcHpfNF/qXs1y4db+hvTIM+sMU7HtogzoH1" ..
	"2M0A+4AcISPY9dzJ/QjuVoyjreYGLEpBvSj9Cfd+344twLBJpqLARvZP1CdYaPK6/756ZdPiM0W4v3B8LYXd51QLW1TU+Qsb4RDo" ..
	"ejdgUzF9c88oRum6Wagm5hgIaZEETj+ZaW1m8Uq3OdxSefDKc4uRgvYqpvHg9oUlfRKBJ745Imwa7CjfBoY6omlvND8VtJQ51ZeU" ..
	"54S+bs/N6Ao3f98FUA3BIM3iz/Jq3ULnewyGe3N2EM/nX2Q+C/EnrHnwMQOxxmcYoSIIvz31Bf5mE4oKoyy2mytYK1IPAnQug53Q" ..
	"U8D/kSrn60KMz/rZnr4MSjZOYkVrI2InEZBjlLeIv35mEcLo2N8YVpjdd5V6ryXqZHocTVNpcP423QqkG3dsglCIBYZwMyT3e2C+" ..
	"s4xxXuQDmCaYOEIYW9p8NfUz4bCugsS1Do2ob/vwhMM+gZjvMHIM+YsA3J7zJBRENPM58f9y6wwcJtSByJzI6ZgD9a+mwFHj+t2c" ..
	"xuky0TSaORnF4Gc+WBATRJOSLE7B/4M2etiKtyIYyhmoyHd1oJ3nUG1ta1lQg7KT/gJl017z8KBgrdvupBly+C99gMjIsqIP54d0" ..
	"DQmhRsptN+xSw9zMpJGnNbb+Q1I/H7w+akZrZOVGszi3PYZwA9i68VivDc6CI1uLv9odhc1hOT0wacVgmhrKyLPgIh+n6rBh2frb" ..
	"CS4DgpdrvdOsXS+XG4lmETI9tw2cQlEVqRGE0hTslq+e0OUrU3bj+y4E9IFR0XIuROXXe0PCCZRgRhMjr8a9JKaBmmGPK9MCc+0c" ..
	"UCYfRqR4BfrTPs2+/nGf/13TJqJC3gid6JO+B7Cw4gr+ohLUx9PHXnSenEmAx8qoGjfL736J7x0xgx1SRIOJ8Xzwzi5j8t0bIqYP" ..
	"WMu0r26MZmRA1i5piCRcbXme3mt/Bvg1I0cFXJt2Xe+cwrJFFgSLDJTIMhucMPGgZMs1uAuw+rRO8n/GtpJ6vSmnxjKg6cTy904L" ..
	"1G70zny7/UZeeDEmbYslexpvI6eP/NnkfIAjPgmfDyz1VBqBVwaGE11GrnbMe5xy/iqljgJzZlvaOj9GhqNiF6B3XUIArLSb4BAY" ..
	"4DDoFJ49qiFyzsq9AJF/tEonuQLcaPw9oigOTzmgc/1xlSO7aEs1tmroeR4bKe7nM03MEJnUFmNr4h8LXNvNBRxZErS/7QHs+J71" ..
	"UlrvF1vi4u7x+Rgb/sfiCKr9+lRuw0MB9woH/MPinCgtA95MAKq88liRFRxxmHi0RlZL3FVgTx8ytKA6hLKCrwG3FJTTISOYZyNJ" ..
	"b4x8imMgR3c0eU8fWxzJHh13IAdOkz9+Xx8JHmUnHs4hFKwDqJHB3+8toJdXE9rPDIcMeZgr/5wG01FYl4EKc6y2jgCIv8YGIhxG" ..
	"vq2FLEMzyeispkW01O3CJlpGeHlOb+PAtF9XX1om85E2npfMSMwlIHhZvs5cDX7nkvkDk6WUlQXVYaEL2LDuCccCc1yC7s8QpWXj" ..
	"O47pPLDpf8trEy0PoEIbXHohKqaZfwiz3t5INXY/YjkBUVEUryOlmCdPjyWWpHswLE+lg9xNJpLn2gsHMBs9FVsU3bWWnGSd0lj9" ..
	"Jx2xVGDyokxURQfsWoZWB41434k3bZgHFbXEw1FTaCWdFW6V80mVppDb/W5iBpAlbgq+BVyjCpdKg9kyf8bY7K1NeLYJZlz/Muse" ..
	"IfJmYoI0DWUy1XcUq30xfMrhIggGaOZVqNsXr+EoctlU4+aM11M2J2NjlvreTLo3zeocwTx2gfE+EkutWCJeL47j47rDXo8lGtrl" ..
	"I7Z2M8C7a7jCX0cYR97whhMVcTamRH6Wvm0oJANJ03znIpLpWYd64LtGY+RANjFAMZjPWjtWf+sfak1yEE0mLKpGiwM907S490IH" ..
	"mWFskwt9CZHIvpZ5QaqLC+QqfosF8OkEMI7HPoUST4a3asEJfIL9aAbkeLodvYa+VnmHAM7Vc9QPdYIW993weUg63/YUQWkWhSuY" ..
	"IJ58lkCybmOYDojLn8KN/RTErGkx5PzubuPYG45WqZeTdVOKoJRLUxUNu02tbWRriyadT4SvWtqdRkcwTyG98QSQBJkXDYm9uRur" ..
	"7XbtkfT2HWFgno3ojCffHAYaXJN5h1K0zh1PTXKnt3W06+82RGcrAreO+kZk9SO1wMWFVE7y4HNIZJsG2Eix9Vmiatb3RaW1trxz" ..
	"LeeIF1oC/qUDtJO69sFqp5MjrPV914ZPbX3gw3BZFs6UA6Ml4xiB4/VXr84dbQE2wEPZmzgrIOxgh88UKK9S5ZZEeelWvLmLug9R" ..
	"Cvx0iTMiTPqEWPcHAbp2vEYEuVgWsAvUSMc6HlJT/ZZy2Df4SsQZZDOqXUG8NVhmdLWFoajYsxzdTuq236OFO0hKtTKOPL3jh4nI" ..
	"G2Qp2p4qNKfCT5FMHrv9Uu816hde8EOpHtHujgCLrOV66/4WT1rL1PPU+/Gi//wVcymgusFfIEoKIH7bCMrk+V6aDF9VqxNeI8E1" ..
	"gCF8UWgPA6q49E9WazV0K2OCFLB9Uu2isZHSnAaXkKGvNVDBTRplsZDSVhe180WPiwTuEX4L3FBdL0g9oFbzqAaH7pq9ryyQxI55" ..
	"1pjBrGmA4U+dYn74joxlv5ZRAg8QMdhFuixWuZnCpieDK60W0GKqNvR0F9nKnAOPpjDk53rEwx5MuzJ+KJhWmEJRqiiVMvXVY9PE" ..
	"cc6FiZYiJxgbvEv7b7Qd5oVOEjgGzB7cOg0Xnf4WfpIbOWzQwTesQUNJqYqEVwlOeVzyIV0Jm5/rvTwqpZWPHRnBmToJhBjD/HYe" ..
	"uC33PxwaxLwYEIg8Q5KA3/2v9QkYoxOz4lFok0raB9CASP2YefBZWZJ1HDImuvWDifRw/8Jf2JYKgAic13fzq0TucfHV6fk5SNTX" ..
	"eDNF48ua1g8cJ//E291ZzfUyaGxtp+KLD8uIJMCq/mIfB4tMk0UlCMM4oUUJDPpyGs6Or6khA2tdrJbpzyzuBuUl2/XW7EAzlIoE" ..
	"zZwhIpt9lC6x/iNKCAPoI4NzuA2+eYUtjKDn9iGYCeII42jltwkfBtwXJKAHMD+XxCksAp9j5suKGa2Qj5XsBA3gb60+al44tVU4" ..
	"dMX3bimAzD/P9mGIM5qMj4pdxCcl6bHE/QRVdJihQybPx5lTrcglXSHpjsIDzZ0G/kG+Jv3rtQOhcic4wy4olG7iL8RT8XdUD0ih" ..
	"y6YOkN8Y7U1yl6uwHtLXtKz9uPoFtpcEYMhNJGo2r2kHaZmAL6z53fyfagWu4C690y8xDC4pL4EBvRGprtwkTWCBzdUOL+3GJ0ef" ..
	"xWrlaTxwGV28H6Qguu86VMUOPJdT+I6Zf1lqlDboW1OyH1z3yn1RYnOky5rtG8bD0Uk5BXcK06ini2JZ1rk3UG6FARAT7mqGsSiq" ..
	"FWk5LJjvlrTBBnDZzNtNiYX6EvyUVQ94Am+4LcdK3FKgy/klB8B0IVFErvB7v+7F52vbkmBrRkFKZ85YKKiQl/OBz2KVE5Qn6gy/" ..
	"XptQh7zkSOu+rpDQy0zBOwFqa53gKS8be28olF2TC+yg72EamS9rgB/b3aAUnAQFgQP1BLtF+TgZbINwm6gDwVCCbkfrUWlpaKTs" ..
	"L4ek7fWt0pO3HrYueb5/lWPvnQmTovUj66fEKd0+BjmdBtNtfkz5F5jM66QOIPLPmEQML/0LHDXwBF4jLbWfuWccJ7s/ibgvU7eB" ..
	""
local PAYLOAD_P3 =
	"lfk9RuWUdO3LAyJpj3Xe3zLwhkVdoQEc6n8CQ93a6Ms3f+pxs8pPTyqRhLAThFw7Y8EYWcyB4uyjFcyuM42gCym9fTLrtrCoJg47" ..
	"SJHJmUNw4XdXDqhqVl2WAVfWjawIMJix+brKMKi+nE7Q7DJ8DvJZ1FMqu6HLij9KjLYoEGAlLjXULrNOfxXYeqcA8uDV7HSB/0Ne" ..
	"nQCKG3fn39p4iHDNXxhrxnDXJpu+D+yMiAPeWekx3Eqogl2E7N8bJ5BJdiHl/1zt+Kdy5Wo0Ackm2y3u5/zznXfIgpfXgbQQtvWF" ..
	"pO8AnIVxx4/3JHDmvVcR7dLKJl80oslwLX4em6SjtQy1IV1t7iHQYpMfAL8bEZxQVk9WOJiLPP7c8F3q9xRY5+BuyjaRGNGQWwrA" ..
	"Vz3f19lnAnpLXCCAHsjyaHVJgjCYDgh9NHw+Ncku25mILrLwtcDSIxnBgG1wN7DlTN5NqSspIqN3Ja2btejLzPLfYyhrndfWojTW" ..
	"kYimo6RuiUTnXBXpri4wDZ9I0o+vTAkDXbcA/SjcvHSIqCZVIHDb5BIqL2+16mgyKQ1Yyhg53XdxXpZO7sm+HqwNBk3QjPmbTWRz" ..
	"lJdvwkg1raMMjyN/F/dyur+qyDXXL8qe294ASuwgW4IJeYs+FATdWNxPlQIDytabiQpTdhdF2L58gVNzVf+vbxv7jUsJU2gSllpy" ..
	"SezcUVxUTJYBqPzixEUH8VyRPyRPRXYC0nHk/k9Zidb168p1Z7FekwttcV9VxTQ55mYDwz8x9+YNCAopXNrzpF+rYhv7wBdrNjkS" ..
	"G4t0SRv6pbolCvcPWv6blVGKJz8GFK099M2pmvxjTcvSvxthxu2ksdLjFdA9Kj1YdsLPNn86z/dw3pDIx/KL9oLK6ZcF3nZaj2gn" ..
	"vSksCn1abysnHSp8JOXEgF5rtNbpwbS/dET5xMsvJ4TSZYnLS2AyVgZTcsY5ChC6BSAFiHnlToD2ir8yWsZCQXO88iyRfGhRbK0V" ..
	"GAfTcctpIaKoVKRE6gKHDMjAkIP6l/04YoHv5JG4OecDBnwBjHweIZ6PObubod/M7APb3Pb85/gqiXkxfd2cauCfEfdUhBCWCWGO" ..
	"LvpysaDQES/X99ZDFYKP7Q6eKSPTUQAiuL2E6es8dc+EKpzawQ4sV8ohdsJcDfwD7PGbzuMWqo4kURJiCFf6QlfgtROdLz19qemZ" ..
	"dojDl20veuTgLdmZogRBwqcPwgXbonwHbB+//LayFvURaT2u5It7DYcWMVjV6KCC14nvG0Su1kABr5SwpmOkcu+P/VQaxTpiAyuD" ..
	"cj0E4EmPrt+W+kI2s+5iwMj2dfXgZg8Wr5WPzZFO/QRakqYebF8MWl/jrwyUmhzE0s+znDwGhN+i5IUp/6Q8lfiVL601MVWQ0GN7" ..
	"m/mepSlOXjAtoehIHhgGSg18ya7hGUUxQk/SqtilRMTNhvFb3C5WRxJtZxWw6oPG9o4qOYtqg/byZyVHAozq2BcWEArmbhegkbTT" ..
	"rVZErKODedOhlxcLSxVeuWnDadrMZPCBgAjFpy0kGlMDrl34ys81434cid7eOwGcsDzFl/vDJdt9HL2sijSp67b1On8WV5kuD4iz" ..
	"truUfNMWvpgiJDDfg2DbnaNPcTJkXsAwUlGm7blBCoUI5iI3fn2rRflGBVzpw2svEdi+BuetT5ZFIXFjz1lMIal2mwdRUq/wGLio" ..
	"Txd47pjfoFIiydUnjG96VdPq7UgeNTB7td2mWfAQVIJhomEN4XWL1Xibc7+H56LxxaMMBhUXSHJc76glpaSIoLZ/nIWHIPoLem4x" ..
	"xUlAjY+jeGaLsBRZc9CIXAQ2wrS6PjqbpDR32IKzOpxRh2Q1P0sIXFirbE7bSPCeFQgz9p94xXBMiW44gFzpKtyW11CSy23pAXkx" ..
	"8BLsdmTLeecCKp57nM3IswVcnGIG1cDZWtdjx+1dhxbpEVS2oYoIjUItzA86QsENNrrrrNOdNH/2YfsVv1Q6G55XKR5ofQ+GVTFb" ..
	"9h6dR+hgvAvshXjuVi+PzQT8sMIWhML7yjFFR1R8zMGn4EDimzf8g59pEYY9NSxpFvt1D0bbDdp1KHApMw431VeIlEmhCKQ+0tCS" ..
	"39WicUp/LPCtWDxf3tSIxUYIc6jLFEzW5X09WTc/awKw1dJTadzLvK2vUhWX10qp1No0rfQQVe7jwXBHVLWnkvMihnTSRumBx1aY" ..
	"/IJJUM463KDKdT4rL7grnVLSqwLtDsjKGoh2uTL5XFRaPP+uAkl16JXgoE22Ot9zC3oUYoAl8H0B/MqD/hXOI4McmQMAICto1gLt" ..
	"HZCRNIJjwxdhEArmWQFRv0E28amzBbWaSk2iAcLSCyD3Bgtg0H2zpIM5pi13ZJJvJdfhNh+lByLWMGbUD8g0DUJBjXH+E0oxiy9U" ..
	"Il4Ut8xWqirSiC1kHqrtwjQbTzzYncDpv0Rct4KvmzdQeNXvbKrrUf909iRGLc6QtPr/uYOlyhcvEA77WggNYRlNQV7t9pdE1dhp" ..
	"BYnkK+ZlVOW84xnloS2asGnUW2QjL7iZd6ewz41Jev5pWk34UE5yOaQXFBFWL5t7Ihv/e7b7Unp7KxsKs8R6Ft3d7U8Qokx7jnj/" ..
	"8SOPmYWjbascosKoJ2loBkHnfRmYTijoE/SLs/BCsEV/p6SHXwr0rhV989cr5nY56UfgdXItMUzIckaQHaPA0XDtu6QmOvXmCvn4" ..
	"GB5a9T0DW7ITVYVSujr1BXURvobmv4+OfWofSZQuPXPIj172aSrabvleRIpMFjZ/qVlFQ151aTtDuUQI41HTd0Q0qd++RyL0u30O" ..
	"DOKksClt0cjaypB2WUGX8GmzkrXSPNYrh62VWjun/q7jOAvQsvo+p35Mzz01fW47EWXN6BzLr2UyuEiK1C0jXHEJMuwGXIQsIZfR" ..
	"N/sMSUHZSD5ByGosZxuuhsjkA3xv0rAwKR3ZCcwDIqHVs01gXW2IjOVL3vLomo8CSLI4mQHt6F7GUcjmUqOHXx4xKqxqBAGvqYgD" ..
	"iA+egc29vCGkcMqMe26WUXFvsuY4ThX737XJfc/a1pPAqOkJLaIjCmWxfdAuTVzL5hY6pqf0GzITd6F9M6J0Slp8a/KSHVnVBC7q" ..
	"VUhUtav5SX0j0bmutFvQTK8mevO0v8uEJuoxht9Cv4J+Jr6L20fvsMjvZ0rjhuu5OhLiU4T1xMkBBYigim+UJLZpcjMj12mHuiS3" ..
	"gu1h4lzkJpcN8TPqv6lYP/YCkoJgEwIRYMau1oxYa3NIossnCNhQm1XovQagT/Rn2Mu5hMJMxBeKeha1ndFJZ4JULu07p4wdRA45" ..
	"wp7JHDH+ZYmj+MO56F9Kdb5sXiwQGHXdkdT6vN23uMweeboGCQY4lfZ/maVc2KxExhfp5dT/bfddnb7OouARb8amO0Ta+CZgSgzP" ..
	"iaYd7NWJtDoSJ0+9rm+tKAd5nKx+a/ivfO5hF90iFpT7az/PA9hno6zmPLsUgGdQpfEpzh5BnNKjweDub+H8xHbK67Y9Hfp3jCf3" ..
	"CPHX5LutrJ9ld2IjD6kz7qybUvp7fvwAMdYFqskXWQ8OIPNnREehJZqov8tQ8T02Yd9KTnf9JemvZWQBRd8Cgg4FOOGYqAuiS2lr" ..
	"GskHeYNjDszbTHArRr+S3cQjnGpOoErLSuaEJa4HbinQ1TSnCGEtR0LvDlhVsfPPduROdr3CTrJw/0JCzKUJ6aoZBAZrJUugJYdC" ..
	"+EgPzldPFweJNJvs6ejYBCqF4hzDuAGE9FyxDxo4w1RvOAI1DThwZNCCouGKYYu5zutyvS7ufQE2wgqJ9wJotDD2CAYyrB6aWdmT" ..
	"hkN2Dez20jX3wiPVIJd1HveKxw8Uh2dL93gK4R8HgDgE/nRplFW/AddR2E8Xq+uleM4eZuoFLiuXXxDxnlO1sf4QmrNv8Jwnhcsc" ..
	"STTa8jTQh161qXGVm8v/YPrtsLqSnRI8kE5EP6GX/69RlQ9u/W/atfc/oq/gLkJhkhlf9frH11skFYe2S5hc1CVk9bJjCHwvptEr" ..
	"jiOMGD0TluzhgbeIx5Tm42zYV7UOV+LGEr7jOPCv3f7n5ImGVd7EkVi54OuVg5HLE3cG+N3USCoPz0mxSBFLMG+HKrLnT1zF6/0S" ..
	"Tmvd15ekAybWCuHMZmDPXdBvEXB0fWxCDdL3JhDnPaYp+kXXQHCVuqiQYEBbtogB5iDbVBrjKTTWEtmjCoNbzocBEhy488zFjmLk" ..
	"xFudaqY0HSiuWsY/ZBK37tOIGppDg8ExMc9AssYrgMP45MC8J0X5zQrex2SQfG6N3vhPPmYiIENTp/Ci7/TLxvV3D/ebY8ke1GfD" ..
	"OtNK4+RTmvQtoZgZbhfIOAvFFUhojdzlmIxZ8BjfZ4b0PPoD1iVhcGWi3tAy+r5KmpzHkC87hNpfBo3/jw6c9L2CqYjFhGY+a1+/" ..
	"wr5izouhiedkMP6BR9x/wljlUPZ6FrVW71kQszejX7eMcno4MOYL2RkYG/ZRQK9O7Ab1sr5B/BGsBpC2VLQDu7oxlWwvbSch9ZN6" ..
	"TzNGaA0rCDb9HNQdUxC/Z0CJ8MTTN058KLBRI6AZIH/IQlqDSj9lZ7wmQJZc8LNibGdFvr0jXgSe/BI667rof6LJGintQc4VPxeG" ..
	"c+UiKXCFn4g3lVU2SWx4J4b+y4pijS36hVpxKTZpEzxQLw5Vs7uERWPKrj/9fZl6yc3w+e3eFlRCstpyYUVgfIlWxhEkf4Jcxwnm" ..
	"zV8PrktC1pTrdLcIrIlixSaoz4bak0j8xg8/ywH9yJAzukI5gzUehfTU2MUXBL/pd08j2cVyvEjCSdvye12p+Zu60H2W3+z1iGcg" ..
	"TBVTG9zW4x9Ynzx0autUZcPpKSwFv/273AD8urJcVSZUi69ZN7I6EHJlBIcCfhAun7tNLOI0Sqr/F1Xdb8IKESy8PBQVilbicjHR" ..
	"uwNlekM7YKXlemVeSXkrb8NIVvSeAXjWymuEccZIBUMOQe2mhQNk4HFchq990Rnd2C3/+GUe7oBNFg9dBgXUtq4Ap8bV1ent7fcw" ..
	"evpDG91pbtTSwbTewtycOFnLk/51IWe0RqB9CwpIIu270Qo+KT5GbeLWEkZbcvx0wkPbcQhPtykYZAZ5PNI9sSBvqsdjNCk3G8nr" ..
	"AIy1qoSkgRjfJagwAyppQ/WbhHdEWJzohEN4LvG41BLW6l8HOSXSGW8UGs3OjKfHDzDivwUS8ROYFWGR3+91UGHlp/sAAf3HEfAR" ..
	"FCqCm2LkakDgSu7cFj4mvDcJGydTpJ1qG4x1TjVebaaLSRBm4qBu+vPvMPoWqSIkvgAQ9VT7DIB7MtNIBXroWQsmLaHei+PfwS7e" ..
	"trP+WUOaPIQfTTl90oR7CajmT5/rQG8/my487FNTHMgJx/8UyxRQ2w8Q/L0cPVFFzG7a29QEqk/wu8SBJuC909dBfS/Ila2ijibr" ..
	"QfpAR8+ZdFHhwr2U+nNqyC53TArAaXGWLcsynOgra/UYqaZZ6I3cm1hbx3laXi8aqe4XtKDExA9Z/P7X74VM+BHfUe1u7vpeLbuH" ..
	"facrSgX/Pp1LilBQTsdEfnNedb+FXsBhZ7q9ZgRjPdrupbGES0eavacB5ZwV1UEMCjb35urBU7JFAjzCd380Axzynbh/wmly0fHD" ..
	"68OBhVivXJ43psXYuT8pWZid/u+SFazSzMGd1uDehOJffcngmf0U2hZhJMDfoBwfXfOEFsrM49pmo51mhHZ2x32qjDpe8fQJJSlY" ..
	"ZwWy6V7IYgJfxIzYxeTjzZBRVU6rF/ou8dh9eR2YG7PTyoDUkI7fGx9pWi9kuOGCwaPbXUS2MnZt0bl9g0ECkdmPT3XPfKdImU1T" ..
	"KCvMlJnqV5kn7DZZnPP7Lg6alNXuIPdWHDjFVp5A0O48sujr11+N6Nr3YhlmN9TSq/xbHBjcg9JgUwE/cLixTVpxpZdx+0NvVmwx" ..
	"6R6Eg/D5Q8v72QlyhdxHiBnIB1+6ddsc+YpQw2TEDGFh2jWQvgmgcmErr4JTdEuxGa1zRkhzntPmL5vZTxkEmnpZOcituCH7nqtJ" ..
	""
local PAYLOAD_P4 =
	"f7vD/SJ4xruN53We/N+7gXHOIRUDvhgngxB/2GIqHhZoM4pXmLIqiu6Y+Vb4Z/Ds/VPTGLw+cP7IfZDif4B9W9JxTBFjQ2Ffk/l3" ..
	"c2ZkfqkCzklKcq75/lkL/An9XtW7nZuRNkd/AYeL7xhsJMCfHlAhaEVb8WZmKeCIyfghcL8qiwx0zrslfCZBCLgBTTy0kPvYBEPf" ..
	"2GB6q9TAfbDfqFxv61+Tm/quxnk8oNHbQs34ptfxaUIFiPnbT1YNn6tf45w1asVC7sk2l05RqMxObjKuAygNF/eyUl81KJDYg0zi" ..
	"rW7PnC1pukrWGQsml+DTBu6vMruSdYiOMmNamHj1tsx6xEw45Fv5SeYx6LF4c1tqzZCarrZKRFAD0QnyBTk/gqAtR/DkAgE/6N8A" ..
	"CiQ+GYCylSZIghu/z7cOFiviT8YvDdfgXK3Y7DrCo1DBhtGtoG6eI0dMZp7b0+Y0198fjBkpkYDUsr/QGdnUqk9t030cvpjOMgp/" ..
	"7yGP3nya7/lsRgn0j37QYSKEohiadn8YWbBHhGbLUsVqoDfsfN/0856NTkBijF2aruCaYT9M1MTa/s1tr5RoycdN1cIeDAENECE1" ..
	"6oMho3NxiWy6JbRt1/J8ayDMFec9lX0FExLkOIgxZj/sfUh5JAtrfjU6wHhVfUdUJPDEEvIhA2CLj1TN1nAJIIqpQUfoExoicFhi" ..
	"iTMfcjvJEqRzFdBUUNzimDxgBNVHrJlWsLzEckEzXtEhDPsBRG+zuSMiAibv9K8eA8aI5hb3mBYV/gEMds1GhBJI732DwYZUIrD9" ..
	"x3+S0bX7JotzX9bS/4tcTQfKLRjKzUFB2YCh3SFtTNLk/xF9BQeRffdtu+630Rs79q4scOkBuAe2zGOliOeU+M4xuzLj8ggqTjqd" ..
	"hT5vVj5AUPnLHHiomwjtYKjajAsFvgi9tPxNrj1fkjeuaBkAzZAnHXadkO5crO3TgJgSu2Ao/G4/4HFXdubFRC2soLUpKz1NowdH" ..
	"wJlnzkaG7HymAfrJY3Vz2SyG1dqKYZYD5bK/z/zDNkbkvwQHF2zpeXm41xkbPI7HkmUj1qUjHpf55JGLhIr2TpBvRmGvk0lV+p2t" ..
	"/8yTDHPgzaBDTWPK66IKuaT8bZUINQ842f9Fs6OFO0ff0PK0edY2lJTe2An2lTnbd5DjMuB8Q+Ctrc2F4QgodXMxuiphPwX0txCU" ..
	"ugp7b6xLMRf55wvuO2wHPKipbJ+hqXhUMLxmoyEgAiMxeudcVEoGPCEaFH5po1RIrHiJkk0+Mim5wMKpxRAsN2u+m26BFBiuQ5Zp" ..
	"901I/lm8s3mxTSyTMb3gag5gJt85NNYXT4psNZc3japvZzcRDV8nAoIW1N1EfYe3M8g6PYHIP5jxfQTuaWXooa1DOpZWpDiQzIf8" ..
	"IdlTaD90Pjy8cyNbxivPpwBhfRYf6c62XVr6MLM3yYeaRDVrszu6dm2sj7BtnKCyIE6z2MMqPIvnCKsRGH2SuiZKdncuBixkw+Rs" ..
	"JT0Zo4BASig/4BsUr48WVBulIzGf5xVRoVInXakb2JWUlWmlP15RanMnSlpMRg5tJyZCYED4N7SO7Rv5uWMH+yPpkKA/07yVjU6a" ..
	"7x64HHtBnx3n/peVg0HcvrAtmjzFJAacIl2vEKQwsh41gRgWPdcFj7AVq/V8MImdReUTdpGg/FjxneRtXnJ9ekZ/wGVjX11nuX9Z" ..
	"4lI0zDfT4vH5HTbCBE2ECC/g8AB2UQilzVSvoz/E2dafGDPyhV+zVoyN8MuSGXJxHinBuRIVQO6m3eDTcgm/N9H7NBi1UaMgtIFQ" ..
	"gvmRy60Dt4wREG8QqnEYsiP91MnV8M0S4zNhjsLTSzhYPCx8GUFT1RJwStBqpKFdOfMsQDsr7hpYXY5j/IAt1OHPSI/fIIXtEVsI" ..
	"stJH/x2pJSWMMibTZlGTCm+edauBvDxhRVfSIO/pmj6krftK90+McdI5MQqdKMGnoehXuwToq5pddVBUHeiFnM8YALPCBLCtSw3j" ..
	"9A3VTKBC4IFSIqok65bvswxOOlggR5h3pSf5wAKvbZDHHv4EUMi6FMtDq/5hCxI4VVaRunx2QxS6jngaXD1K2Wn4HwaDmbAlHiTf" ..
	"qYyEPsLbRhUQFsnxyvkcB/ofwcJV/G3m5aKH8EkIPzsePgDys7DYZ49vU5z1d6OhyXFR2PrikjvG0gR9UdTbibJxQ00wyPDy5RJc" ..
	"PVP8kKwvbMvikZmU2btFwMd/r3xhQJ85PoZsKpWevTqpQcS2XNKNEr0dISbtMt1nkZzMAG5sNwP72dGLFUuHEeoUDcbX6XvNF9rb" ..
	"5DfD98xfXB4rhIInrcx/dv5iD/8fTIEub1sKSvraBRqzEWoTyGrEcdvawqOaibmjsPzQzmDN1gs0AHI1Yd9Kpf+jm0asdnp/0C3Z" ..
	"8v/Na/B9q0W8pg8BcJjnPAdi4BYJ8aVrBD3++8B89oZ8/77X95xj5LVtNTHeiI/OCsOI3FRYeWbTaNapjsQMOXB/UVARJUOWtkcs" ..
	"LU/miPj7HKBnL3JUYUc+q0sy+xGf+IQ7BjwthNsD9EpBYneEHgUP6YJH8CPMMJmkB64RlFwGhuE0BRVuLlVQ3QtprRkZ8WbEXgXs" ..
	"eXowtklf38oUQ4GWVwIbNLHeU5vDzBcV+9uWoFtVdu206FjRK+GPNZASPuAwAdnh1/UmXU0zc3MsNdHBAKcRnpCKZmABal7qLCJm" ..
	"L3x34WP+AzQL8GQIYTCX5S5OjBIG+TQ0y+YjuCx8Eeyki9m3WQGqfMXwOuktx3jgoLfxza0sSdB+Poo8OLFTIShqOWVM1cL1lXeP" ..
	"z41r611ikTTQnSa0Rv1S0LitcBwtwdYc5SYQbWzUXcVqjT4bC8Avhz5XC1MLQ/vBwZ1VirkRUwmg810/3vWMjLZrY47aaTfXlbBT" ..
	"RSCR7awj78EvQH9/ctFD+J2yL5J8XuM961Dhex9edz1xqqUXuzQZSLSuwDIt3Frm+huJ3W8m796kA9/mgMsY+VWVa40NoIqk5ptz" ..
	"RXaEP64ZMTuSCxGHM2sVRLBAKSGjBNj0jvKB2WXmkqG0zJJLyYkQR5B9iWTg+7SMy+pLFUDvULwcdtbvMm7MqMOCfEKGHC3hLaqX" ..
	"k30l0W6ePqfgiMIFxB7qqf0uHSoiqWdtxbXHTCLjr5+upef6NLMnBvt7qzFNwPvpEDvIrBCIMu+xo/i/DuOE0Xhpld0mr7sM9QpZ" ..
	"jMVZWKYWgiZ2vQlBltUJGN/P7XWyACxFD0CjktUlV+MsYeGA1T3prB3pNPzfgP6cj91z3pwOe5nqddV2Mg1l5AYAYOAGyoCsOoyB" ..
	"tD+4DnhMNrFXyvm3p1whQWTyK4MR3E+qIY0bGGCq/gWknUZQW/sUktkaLchUgnk7QypNSVdv87lkrCnWY7l3HZymZG1LqiB312xu" ..
	"ZzoLrL05KEVRD3yCsaG9Pze0vbEBcoYiySacb2Rs+d4dwMA2n9qAu4hiqQIHWOKhkyC6/dZsrDveNgyUBkPytMYydbtd6srdgza2" ..
	"GuuuHm38VLPwWJzP5Ecr5uUduZeDvNpRB6TCbtIZZrD6cymkcrRposNDccc7vacsLZjgOhw0mRXJwrJaFKJ74GDIKKGH6N8LxkZb" ..
	"dbw216bC3+hqEWz0q3j5SyzohWn32IDFTpSw0Gta/64Zdk1eZBx6bvesSruPSmFgJ157awLvyJMpIU1r0OPnkNMnxXGTY3UKunRr" ..
	"ilVJd2x99bWuORFgqw8UxIrmivEbh75N5Cgyb/s+V85BjOH+1zywoT6hBRSG54ksgeT0MROMX3WBBXVTc/LQbjW3oalKVUmYfztY" ..
	"Pih9khsIwVMqQVOZ2bZQSEbHc4VHSd0lFRXcXFO9eZ3HZhT9+4M+O0N3feq+7CnXdGqpXK6D8hi+HMKxYW7YFzyrj11R/Wtlw8Xw" ..
	"oE/JYycP1Ka7MP14BQlZup/jhclaIViv3i9Me86IaosMXswmLWMxjDRvjoLF4/kOYLiWUoy1hwWevcmSWAk/cqLFlRhJ+3XQvMKd" ..
	"my1N9gOjFZgOL9FqSgHLTURQ0xIJpORtF4EWbwaJ4JEhOocLeoOEH/THKCVOQkW76qks4XZ9SxmdvhG/8kNaROrSU0yj+9YcNBI1" ..
	"ONejn0+6SWDeW/xXVGwHeSIQYG3X5UuUazdP1SlqibguqAziD8naD3Vv+r+l4VhaXtu7mbkCERhlhRCNefIRmr3nD/v00NvqfY5n" ..
	"z/IAYsBY09LcwGsT2HiPU052RKqYhfCVdQad5+j25sTdL3CUz5SeCnR2Gaw163Keme2xN2Wyvk3NosmaRCVe680wNR3ZuBhyVLAG" ..
	"yqK5wtIGWR1xOvi60TN6Qmn4lZYkVepAkq9+hdmwSlotVzOeXrqmaUn9v7hDK/tD6ixZxKmddyD9AijmtII7+jvFn6pRJKFdu2jv" ..
	"2AzjM+/uZeoGio7CuCVd4yshxGf+QoG04I2ZMhNBPNm0Xuly3NL59PhT/HTtcFCvvJs2+7aTf56yZgpeuF9xHSuuLFkl62PKzlzV" ..
	"cpzSbvmd+hx4MkI9CI5qgMwhEnFLMtMEhbaDCgRIxfWu9QTjGWx3JfJTbxiCbaLmZaV3ZL+jZPraGDBMNNna0SPHO7tBBfulj5iU" ..
	"zjWO2W0W8WAvRUXgrw81qEAIZhOU6F6ji8sGrG8/qyf2kpIAX4O7JZfFbolb88GHjdSQ4/JxQV1rVue0O8pYcCOvMxudWPJ6mzl6" ..
	"YQWCQ25bEdPqETIwXdllIHsd1BobrhcZMw/RPBGU2qi4OONxjX0QEaWOQh23Svj1UYrMrPfZ6zuirwskmVuyARsI0cfIBgGNJ7mx" ..
	"wneUEKS6PZzDMwecuBhikI0L4ZU2LT09i4gADintoZJ13OBcB1tUDp0uCDN9+HNhahar6iWBQkvcuXtVaKd8ztXePoh4Du8bw50N" ..
	"6qAxD/yW+ZN5lWSoAVSh3OhcnA3t6RLTjm4+44wi1uSB+T3UeaYV2KPNJDh9A2aPu/0w0Ise3uqKUP9lhIaa8pG6hVOxoM9Tma7p" ..
	"u9JqG99ImRWm+L6uTV0aqQzoYiE4M+UNEpB7e03RNPyPMmTBNYO7OMPOGxGUqy5TumQFEyVqho1+jFBh1qzr15tDcY10XmiTMKMm" ..
	"ZY08FVksVNTORB6B2lNAJ2HAM/7iezTSWDOqJcHJmQ3RZ3l1ecEThVLPVnOoR7K1Wa7ZMD3Dcn1joyUC1BNRPM8YWeX04ApRXk9z" ..
	"PmYUTM8d1atYfbzNIX+DjzRZPE60oy7HvuxgAQsnlnOt9hQtNGq4ctwIQ+5npfxe2PRnRNVWVNpxxb08sNwXI7TvRfLMOZKgFB1m" ..
	"QRtTPtXI3XguHECBCclHICopCP4TTbm1Tv5Yl1QumPoxX0F3clR1HAS+xhP2DFXJE27zR85CGEUHUaTwaeE/mSw1ow1GNMlquX4D" ..
	"BkGKP8Q/T/GlVJ5TlnJOZ9PqGHm+9Gzr2tFuwC0Vk2v8m7YLeiDFNLZSYZcD45AN3Orknk6JR8M2JOHEXypXpZPSCG+n7dmiOW1G" ..
	"yZhHhEm/fmYFCtahE5mP0zNauSMWIrRVEMLCZJPCl10OqVfe6j731VJznGLM3MZGckkAe61a81CQFqVlcbrUwo+5fc6Ft/bGVS3C" ..
	"PbAAjcGT1TDjqSk+UdXHUYNBViTxn8dxrOVYtvJEw7GLmq9MShQjSyz0j2RdxvkiqPwyCOSEyKEpUXD7xI5jPmRB5lT3TksGj6bJ" ..
	"IOXwSSgRazwr6gUYMVqRL1IFYuOEE3mP3zgH8HwmTAw/9h1M78NJFalk67EqrG6vpvDE4Z1H2fa0UwGTkLWKCKMKWCMDjMFVswcK" ..
	"geP05Zsl+CXV3TjuXSmM8ISg9VWsyW9Xey4r9WGP+DX7H6BtxoPAiY81dxt8b9bbuzSQG+CWcfSHPVvHlBl8NddeGYvc9oVI9lAo" ..
	"hGjqCDs8dwj88TnsZjvajZhk8aKxetvmyc2C1fsYTTaTXXopXqnu11hsCWxtzdTjb//mJ/PSYi4pJpEmTZWWbXGRjQjMXMgiPKYX" ..
	""
local PAYLOAD_P5 =
	"z1Rsz4VO93IbDIP4GKKWpJKHfngudRzo9tMJ0+7fKyKJ+EcIE8AmLIQ4lDFg3XuNPESE4vyvZhNtIhiZifBnOCu4boCkniJ6errH" ..
	"rLby+AJS1wfT9DdRTD7yZDyQBK4AgyI+gMgSvL1njuCnkJDFPVD3wBGwvmtVP4/I8tx/f9kihw+c8zlcnMTg+/SnyN9oeKqW7EnK" ..
	"S5XZp4f+ieU+dpEyc4aTpMipHaPYXum/gn7JdiFzRBRVoMHyRSjKfWZuGLNaoEIBcYNXeC6OwkIVwV9McBIPplJmMcBz3gaYrBCZ" ..
	"QmsNORrOJ5Uaed4XpYMaLq397U3hFzz01YnxkkZD3K5nYCXi2RZuaN5xXVfyrD1FdtStn8vtANrqeikLiHpusdvH6ACsGGW/7++A" ..
	"QXDc/6zA5UvN5iPhkUbHFjo9avtN2EEG8YkVI+BHDYmiPM2zqErCIRCp5JwH3i5OoTidFlY9fqVlIprMUJkuGBKiTiyzlClSaAp+" ..
	"jvXKjpN1VbmKp2/F2QF/HfX1LWQxgG6R6QKs6l6dzpJIUfmGLV8PGXj3BUW3XM9dz3JPEhW6rLKp0tayfd1+Y3KcUalgabqa0OOr" ..
	"b+t896alXGDhqaxCyhmhB1yBV10TKkXZjinU830dDhVaQhsvPgzyvaqhitJbnmrzNU8koNPKWYo8aWyIgYt255p79BBdIr8JAdtj" ..
	"iPlSYppZXrvMZf7OHu2McH4Aq3X/dzLX9N4Q1f8Oe4q4/APJmxfRpzLqhste4vw8thuouHI8gxZTryN3ezl1I3noLRCy6B/Cq0uq" ..
	"qMpKQXcx2nEw/YrMYaQRJWv6mzRV0gCbLnlZLhq1ydVELDguBamMKLYvXlUzYhajwL39wlZxPSaIFQY9KIuNmakPdffE6JUq6f1J" ..
	"3Mg/Zf5e1qmUGwlZUncc5lxaT5sB84xq9JVLELSF9xLYI0q3RSPHN9qmGbl9yyD3HI9svpyPLaFsUKeV/jqulMEKHtfCjJ/1Y2CO" ..
	"QvxjhZVqR6YHBvrqu+CHfni4NW57WDnMzRxBozjSnAt3k9bSiCICN42shlDO1BzO84SGePryPV26hnCERpJTMlT5QU2n7bJb2hxv" ..
	"WnGy3Cz/VbUX/fWAB1RsjQRRyVLUpwOgYb2EMIn288elSYEk1ig2yKprf+zR3cbkjTAnbn/9ClGbwEtogF6F3k1ptc/nd9KcCGsI" ..
	"9VT615TijYgzL22DAmbItZAeMXhP3/C4A/iy1JptJoe+4hQRlYbGZLvvlCdJXSTkxYsJkeamWpIaStj3aiyAgAaR2eSlt7AcqSQO" ..
	"lmofGqRejVD0o9Si8Dgw1NpvpaFbrtQwDuall+xjOVe46zrBZ8t9BAt/cG75+4hhyF4PGcaepNxj2JV0h+E6gsbCmmcmw4ytdMAa" ..
	"ziSfyQYZE7n0rBfRaiV6LkorTVWzbOeYwOQVBlQgGfLTuvVV0ouGzyNpSbDJ11/wr6xnZp2fSqQ0h6C2R4Kvfo7jpK/ENzyTlxnk" ..
	"3Ansi3WbUd+8FgWZ+0apL20U/iiXPpTyzwM6GmGGTHkBF0CIDIN9o5tmIq2j4aPnnsqujU6mxDLhZMCy8YhNXSvqiuJVhW/uCfxk" ..
	"4Oa4KKdJ4pd+h8Jlzc/50GK3vGK9NDF/xXrkdZlrRcAUNoEJ8CRA32MHDaZ9ErxWvfYlc1peuvvP+c/0eyMmJhmTf0bWhJ/yi1Mf" ..
	"PJKbyIl+BZDcxYLlk0h8NMIrxJm6nFZ9cIke/pFFAo3/OrwlQQnSV1J55X9ZA4y/HSAGg8gE2IJE44dSuJUwXRigrLfx004skL2y" ..
	"vK3MXAuscjNzCtUtYAbNsLfF/zcfMk/5bZxkxLIyqivBxmK+cixUaWxYDPaevlDbySfi3LLdJHLYchEUgmv69zTv6BHeHey7yIxX" ..
	"rF+j3eYCdyFCFZWATDTxbB5JZYFFxI+aqvtGL5QE6B8uXlPGWv8NoLtzbA8tJSMhnJFUEw6sk+eq9UD9SKdlJWZ0dhW1kZKilTm9" ..
	"2eFtLHavwC1Auq+wHU5c66WHSrLBYBym6njqdJdSahbICkvDavRuakselz4vkdQLqH0K0HRNsHuf9vxEDO/kwLE9k+8Fj+Ilji16" ..
	"GraPKhMNl9grn1N+frAMcQBhL/um4Ckba6fhMwUu8ee2mm+fRmCUjmygJglwa869uNG1gRdS8ontJDHQJN3YZ1PM1NGppKX7NRhA" ..
	"3psPXx0d/vKGWWOcO793vHoj/c1jUJPkGOFDEFJe9m6kRYroGdZCBl5fgwChAHW9SJNROKrR28bODwiT3F06o6b5UwC9naal+4mH" ..
	"3RErBGn1206/QipuKbS3to/hDIUrwZRVD2nz1dVse37x8qELjiuvsW5+LonrwO+cdhCImj71pluiS8plG9BIjrP8YV+lKUajUH4w" ..
	"2sOKgv3RyL5D3PM277W7W44T3IZxer/TZyMDX0XRaAQgt7793pt3Uzqw+GJvsi5Tf4Y7cJRno2yaKEl5/x8GjiXKMQyfT33Rm5E6" ..
	"NsOQ48LpyPVjWlv7AaDeJAY6ryh5VPL7+MyZruB87d47uspS+tfpWNqf7dAeniqtBRR03hgCH/GHA+w95enDVwhWAuMao1u658jv" ..
	"nvEOihwfWK7aWZirz9GwO2uS8glWmXYr+bvMXBQvi0yG5e9Ow1Ti5W269ZV4nmoXisUSpNHApkY2T9gWoLfINzQ1eSMUqG7qb/Re" ..
	"tERHNcJcyTzarKMn1qTHO9D7aQ4egbCW2uxZ/zIm+PaaNNvpFFytWgc7C3icrE3ge+BDw0sKU5T8FwW77ql1Kd8ACDnaZDBL6nzo" ..
	"MT7MOcWfRgDI4N9Kj+pEh/GFgzWCZLy/BoBvKZ34ipEdteMavVATYrMGd4ffuVi2QSy0z47qAbC9A3Cm2ajLSuBNy2eMpoD20i54" ..
	"INjrAWRDU0flWWGT+yvYWX0W9hP6s0cY1hW0D4PotrByaeBNacHojhHbmUJt3+htog8yQbzxFt3UKRx+gVkVK7zDp8AMqrmVrYIy" ..
	"q87NZxhIVBvVmfQZRp6b3wGLt81LWmB8eQR41s8D2QG2mHuW4K5KU8C16MyEfuutNn/CNEpLhnr2AGxvQIrJsOrPo4Lps3P2DD0V" ..
	"+njDyvmo7X3RPb2FXHcmWXwB0usyfZunYNWhCO4ks102fgkSy5sJVlG9spKtMgoS7RaCmNFul2uwHiq1zEdqrxo4zlMFYXTMpNnh" ..
	"Ty56Th0ydBi1kPLT5C7LDsf9bR9AHAfPq0HzzQw1fOajSKmWxum+KyCa3vCcbAXgUSnFBQQSX31Rgdhutk4NrtqUdCU2EZj7nrk/" ..
	"RUQUOqCIIoIrmHeTVw9V/QzsFQHyNaF4PDu6Na0K4/JJf30/WPDVVUv1pYjcFeFiV8xq68pfyigQldUkbfwkCg1y/ZFgI4n8OeJJ" ..
	"IrLKr/EIz7HFbG+5KMVqrNvbBb3H7LkUsZyoGdFPeGY3X/tyoZGi5xxRilNU6ZWNAHLSbDfnMquJdmiJ3BfyG7XP1knKI2l0Y+Cu" ..
	"5TK1A2BGMgI+TzOLrtB9GQLxqpvYQtAoaQNKES4wSUHvY2PFMGgSOD/E3yb5P8FpCOa6vrT+pw+OlvIgs8JW0DFbh8iltBsVllKY" ..
	"7Vvd4E63msa45JQg9DZoYKvl2Vl7YwvUWK9ZHtXurlaGT/4Gef0BMkccSCmiZsocnKbsXLLLFYwKBO/CBz6LCDQWUUXfglAs7uDi" ..
	"MilAo5IerV+w6KnA8b7gvSWK6+1biWbm3Vmjpm/EAKlh9IvckAVySFgoT8R3fzi/GRmo8f8ELm5Ln5DHlH+hPQYnAiSGBi39H98T" ..
	"sgPcc7eS8/OtEVlTcDEQLRClbfh400KGdL172ssc9hIqpy+XX3ritdvYlLIUIwYIq00QiO+0BerD0UZEy8sAhT06+i7hfoG4uuze" ..
	"k99YRO+zg8EjiIrntQkENMWKXC1dZuRQ138Nhf9/pRQmO8XGziBWVRjvr7lnKEtVzu9vgZAYy2ierDclRwAZSiW0XBUnLpgIrumE" ..
	"hcA8dzQQie8gZ9Qdkc7iiowbxQDP0qQE12c0zfSJCpZ+h0xjOh+JOBnV2Jzw/oW3ohoeSzgVupi9hbCuW+gw3gCWypi62cXhn/pB" ..
	"WxB74ebaHRwUxdKjQKlfWuysMl0bI6Zid2L4BKedknF3k38uLhTrjI7hsHRK98fHJues1wwKXL67pidAUkPGGetvKtCpuaYuySKM" ..
	"YuVmS1GCj5khPEYly7BzJiw/VCHRDcJbQL/fOTih9GkSRQmpmcyXom2V8LMCmcdOefjt1G6oqWuxO2Cta97SBOJayqd0bXJL5xdC" ..
	"xEbS5qViN6aLMvf4elKVyGCFdJPmUsoLZAlxG1oIl/UNFvwyEs9tSzhaJMkFuEfRtx7skcvJMTe4IbPQTnEqpI51BXL/DApdW8GL" ..
	"lS+vh/DCPP5I8bi4qQ4A5SQEmh6yYt3AeacEt6fIoTOl4ndBQHSr3oS711Og6mVKYTdhHtrOvcJS9SpDMIUq/5k1eh1E0lcNxih9" ..
	"GpcRt90QIwZl9zt99py8AsRD92B9vFtVnyvUUq5/u2aYJrmRd1PjxqVaCOiySMk/cKd0pjlwEaJFXIwUsTfdHMthFBxa8hmVUX34" ..
	"eEwNBHVm5fQSg841D+0aH415TAds3K/1zBrRAC8d+7j69TXVJ0KNvdDF/wgsMO9zHxYwY3BcKTeLnGAfQoZnulOj5L6brqDDRu6S" ..
	"66qfTGHqSJW+/iXUtspuwJ1Mmvm/sR6ASXFiqq/6OViDFwUtr/JWdeux1rJaxJq73n76174G5yQgwMk/dDhgUoKMVWSxOgy0vWoR" ..
	"pHjMCX3ljqZMWbabkV/vgSxqKT6VDUyRg534oWjxh5+rLXvivFsZnIVwqM9HD1Bii0f+C1eHPUXBflIVNaagF7IS9gh+Kqkvo4h2" ..
	"zZp0NpVy6nARw6Rx0ovPW4KSw477eQNHuxsbjLhNDSHdg2XxLtJGBcLmdIjQQ76ozNcHc8R8sBUvCpRd0vZyTJYChPkGq+JtzYnj" ..
	"uwHratb4AkG3NvnswIyoGfHLCs08hasvZzsQ0Ddkru+eH/dK9cRR93WQBtdFjkmeUoxpkPMEicBxgsnXP4KmzLsVtJQyERxLh7pS" ..
	"tlRIpR9uuLVQzpL1B9QGn/ArHscXwxr1WXBJxKxDYpx/WNNI4ruPILGoZtT4C3p6zzNU2IJ49eBXoDXdsm1dZg4VPMOygwWQdgOg" ..
	"bmRUASw4PsULPLkWsDzdnP6NY/c2OFN0ZTxpp3XJQLBqhZozLw/i0z7EQ6mTiKwmXRly3u8bLvKU1csSC5tZpptHpYHrQqzegNym" ..
	"lo/eMGXOb1O2yvKqzALJGHC3Ay8GFcOntSVNHbjf49cyj3EoBwDIz5EVaWH0hVEfezVDnHZY0siyrvnLOP+VfB0BOGQ5RsXNuxE8" ..
	"W9fND8/h/H2Ettvn5CCbx9xsLGNVMdk1HmUMhRW9GVJhqarTkVslssQBFmxrcNshaq3Sya+lMEIqQas3lLy2d2I8jyGvGr8u2BfY" ..
	"LLqq9ZaF85ScXQKbyuTIDXeOV8VJOZlvRF58nOW+2oCFpIz3cI2oyfcelHNwWmkB+8LnYfenn1Th0IxfR3SG0AMO94pZSkyz/mk4" ..
	"XOcDOsvvvU1rdoV9VFZbh5At6nh83UGEdKrZkNe1L9NkRNz0a2XRQAG/i5BGaW7m7k0QC2Um5HdOhNvoc3kyGvdSRaGCAOr3e2dZ" ..
	"HuvRQznspWdmfq/U/jgokLKKjyy7UAiQK7KH+L0pwcGCxdiqFTGhB3HQOIkEdRujx/tujBDNKJ9bccpO9ZIKhdICgPPnlwBAI0QG" ..
	"9KF8Jt17fnNmywqwdDVgY6+G7eckbOq4V75ruVRbDMjQe38fGzcGv+x3iKo59lF6HQZ4YxxJZrh920LN+5pxzKVKnvMZwomGUkot" ..
	"V2w2hQmQth9xLF0BgAuKgcgzBP23K3VOwS+arJh2Tar7CZI+VEfl+VK1BeH/Qw91qZjxyncYkaZm5/sS3mdvuCGohxafcMNQSbTO" ..
	""
local PAYLOAD_P6 =
	"fNlqpcvBgjPuQUBExptj0nqoDBHSIqmdxcSONAvPUzo4fIyWXfVr0fKo9c/4vuOs6yh697mD6FCBpZ7kKu86rENfa+6T9hr48y8B" ..
	"HjbclmOA6yAntCFCuvMO/IbOltN8kpzJiEprm9tqwjC7HZ+z/8Xa+NsCWC5SXZx9kQ3/Nm5Rcf0Heyo4qZXi0HLjU5+OlQXu8oDh" ..
	"XNpZtPqo5mBeYbFarExjRCzutKZ+6UiAB0e1LkRgePfvqT8QEhLadOy73zKoJFW+EUgAe3f3JaH3cDWnQPYOOfYA4fR5d7uzE3QX" ..
	"Lbyvrs170yXQhuz8qpq8TN6ppC27PULiJqS+9CITGbJ8jb/BJHvrppqpiUxGlJDdQ+c3SivU95NVHoTRWY1L5Hs6dXOuYT1qMgFy" ..
	"fco7ICG7kSX4NYu+tYNZKlJmMulytGMENilVcASe+jvmB3EOaqndY2RfXEqKYnYKMbnLm8q13/Wk/l2KTuqRl9vmFUvNqVb8IVn4" ..
	"x8eVNYHwcXQaKCCis0iIwlhK18phUzxGpEo/73uM5vuoQvigbYBXUItwRfOJXSTJzrh1M5onV3dS/3Rxc/qXRAGGSHreAB8EaZky" ..
	"GA0Xg5K8f1+8zfVsJslF81mtEIZDWUExC0L36t2dJYF50YvNSePxUSltXaGVlG/V1MGoMBbLLNHUnmtGbNZxdoD8CNFU17DxJLNf" ..
	"uSCJ392dMDSgdfd/1sXN7hZfpeOdkxTKuxEI99Cg+smmIT/vL0OyinEMW0Zh8lmPseWoKdFo6E7rqj8TzZKuPAxyEyzrbaWBtyg3" ..
	"DqF+9pWy8r9g54DEMtG9OKLWVDdpzIpUmznKWlfZ0Mn4I/AHAlpapZCUS6Alf79j0KqvlSKWFJCGUxfNmg1+0+O6ZVSUuSQlG19d" ..
	"uEtxcOLxLoqcmPaoEd5y+a6iO55AbmYztVSVAa9wl22w5t6psO7FTB8EJxsKm6kuoVq2yKYm58H3kMvNEfcAjSxkdVFQ3ObBxDar" ..
	"4L+88zKLizpavMDYbKqbCRiB0stNnyL6fBugOAjMOudOsBUYDFY0y7DkNtknNuOGAn2MNqlP4tMIsnsD16rA5og8/aRPZmRbr8rQ" ..
	"LaYLhhg49OFia6Vg+mmmLmj0TDf2VuTZqaOgVbVXb0B2+TilkNvdIt4lMvqftxcbf9R5rVoEbDsM7h589cnR6IF+OqZ0DMSRrqAg" ..
	"FcIjlgwcyQc2JRPzSOIRFN+aAHVPqEvNWDjRTsFMIvilreFt/p458xGpziroZ2fUYn2iQdXP5xeiuplUwY/TbyRbVcLNNIHPjR08" ..
	"AhbMM+7MbH5ByojwmdRg5zBhwwk9yJOkHQLr5nsfNrrSH6nWb4zC8lff42ZVXEtqNVVY5UHmJPPBGEMek0YvQbqZnf80KQaN4K1W" ..
	"aqbDs8yRxh8B39O3KWLsYFNgacbimEp1Tty7Wg+IoGJbmoIOlr2LwUEmoFX4T7pQV+qjWoNKEa96ZbGS9QIs57B6rHwYgEJdU8VQ" ..
	"1hN2Ge57khPw2LMco1unJ9YHY8Q5ATIdsbV8kIf1TDtN8LS9IQHUqziIr/2GAMTxN0HP45G1ouxPQy8wx64+47pQOlgnaLXPCKL9" ..
	"SjdbZU1HFQTDoh3E3LcQdjxp0qdzidtjxNSnNNJsnluqm4Uj4QqVIH6Q1nOpcnzaACzJn1lX20Gp4lsGRmONui44xfdakdauHOnI" ..
	"XMc4zAmYlrstFEWv9zGtI14ikWuUijOUX+RlJwzbi8046+JezxIQm1tZngHSqcdHjT4Hoqz39V5WL9J0CXWAYIKbzjuF8pawG/1u" ..
	"fvWrzV0T79GMf/7lZM94cUypGz2ap+iDICWtBzNjmyP0FgKuIUMXrMhtY23W9RmeOy5/12XuvcJiqYsB7i5OWNBDQGA2xw3TWWBS" ..
	"+EVEMeCqFPCA9WuL3x9usqbIG/XRZ8Vp18EVQv8Z+hdFynvah7GSTPdz4PTmvTJBV7Q3Z0gW2SQXK6b3PDLEPqKN31AjuYvo73Sf" ..
	"By5rfNvzkUKPtlJ7HUnrcOCZrrqL40Ll5HXwCWweiNIoqT6p/2u5gEqJBvUbDtHWHqEJH+PEa6Y5lgvNXCOgQOBZjeQi4rMi3r50" ..
	"dtTpOzU+gPN8LXuTGyYj/Joo+MxPeyRizh3yY381Tw6vQPGDIIxbA3swc5nzWPU4Ha2hVMKWIPoM0QMvW5j0VfegVv6eRPVFcuXV" ..
	"Fibqf1stjb/526mmbQDp+lFbnlf5TfX75y22pfLXJKAPRERd/q/YHiLAZxX2NRwXMyIyR3pzQgoTNZMyP/d4NGMRBQj/O53kH96k" ..
	"JuwjmXu91vyZ+LcF+LUxfm4U5vwAZ8oRe5qAcBJDL1cpL7LaHblRgAvL2iPfRXl/h1RR2AVPqjtV6GgHc500z3qGYXdbdS8t5g5b" ..
	"vBtei03iiMcSFKk7/QOlh+xNNPxhJTgXYjmfqfj8rGWpzEhbFWDJ2bAJzNnhCNrxr6fBaMQD3ompLvid0s3dQf0nnKTn+3W7xfH7" ..
	"JZd8Jk+pQn10wCMrHRTpVnPvF7hFyRh1fufI5AmR/6iasoC/pZNpJA+2Or0898hbEQddODE8oMfDIqg+/w2/F9pEW53ziuiP6VfR" ..
	"0vqIttXnyrAhOvkbCwDIpOX+trvMtzOj7lGz0zg3vhHm7PW6oY4vddqKAeCxVqaBinhtZoz24/l8rq8DHAri6Xl8O6a9LrOjdKQ8" ..
	"dfu83evnDSRyGceOCCIunftSOc5DmM/0xT6PQLIA856HpbbtpKLVWWdkmWZVIbXu6KWotehDDOHnHPg0bde6ThCICHEl7FPDl4Yf" ..
	"66T74MgkadaWow+x5DsSXEmZf+3fHbFAXIiVY0DrU23+gvYlQDAgPxTg+tbwoYMDKlIIdIZ2QwkFlN0W8CJLoXLy9/HTnBEYAqII" ..
	"JjmVjS2mR3RzR+2OFMu04V1Lurmq22FQm1xDIPGG8wplWpezFkR5PbhVbYxHqiyHykHcJqUetYVnbLOMe27i9Mea84Yc64ef1hYb" ..
	"HPk38xEFYQ9lAjCHD4xWgLM9fbE6qPySdBxorntAhrGiYtlMII/HfXaG3lUfuwny67nVo73chGUh2T8cs37rLVXr2hNqMx78uJwy" ..
	"LkOPR3nvvO1/QZsD5EHarYWcjkt4TxwfWn0uRwUyGsu0Cah0PphzCgIQtH7y7W6/L+KWOhuvvD+RjWNFNRDR9vbtMVvaIcGgoxiv" ..
	"u4Ym7KQqictHo7irTydxa2qg+tVWIikXefoRpUtMgyh+m/IekZSA3+Vf4FYT7wUBJueUi8eQkWdmaXbLu7jQ/FMXkaH6ZTxvYanB" ..
	"PQZmQB4lxxtPre1Ys/5hg6oyxYDrO+mSx8uic65Dxm8DCP5N3hkauYqtFJu6xwXhxk5Nw6jQDz65jN9bFfqcD10V0n8/JYn0SXlM" ..
	"0x4wtQ4GYansOnYVRlPFL/sMxTIaeM3m/PTImjhdCwO0EOUT9g3w+pKnfZwePgZ5jwP0FVBUfD65lJIxy215yiO2IqE7dmpnPa+w" ..
	"0D6JFpWwwQPYk9CCrkDHPCbA5Zl+VWJd9KZfkT56arGF+pWtXWfmwM0rbu45cFHD+EAEyquMY1i4acIhGs0BkT7x2GyB2hGznVu1" ..
	"1rdj0K0xtIbGjc6UCmdWG1fFmaUBxsF9Kg5HeyNcraYOANNZQ59P2ZjLVfRbM5Vb9U2Hmkvc1tem86sUCEjU3STGph6z0ICSKW1v" ..
	"mjED43npvpV0u6VuRiE6yg9oCCXkPxctU4WVR2msBSadBfeFTX2Q7Msemc6GGsy56fE/hQjjb67maTKhrvMwoPdbcmji5LcE7XEI" ..
	"IWSrTB1Rqm8HIbrsR6aGj6s7oeicbgwUSxPzG772sAo+A5oXP+MAVmYOIhQ3jJQ5eZVPGaT8PkIWrtw/IePrqQtKa9DIwDMj0aoc" ..
	"jrqz+pxhQehv9g1+C6HEhn2G9DTbioWKcvSeL6ggk/NZylhRkj433uj8AuJHVGOQO7ZHRpl5BwTh9+5BLc/0L3NhbnT12a4Qj05n" ..
	"p/7XT5c02DXPVElQQgjkVDuNH8qwfAEFdgJrUpZDzcte66VfYcksqmkhTsLrHyCAxjmRf2YGqe2q6416QbRRbHdP886u1UIT/BEe" ..
	"YR0OSiDlGO/OHM5oWafmqlvafwTFmTi5QiSOdkosdS3RgtpYddu0d5Ct1xBPVwX669wT7YzyXtZ4pPjKQVd9Pj77ccb9Hjv/Ruyf" ..
	"RCKIU+JsIzjr/acLkdhVg26puU9Zi9QNHFX/X92oVDNUPYEJX7LrJSd3sBPkI/Qgu5eoZYf7GtbEGdIPy8AFOhe1YfzGWai6ahOC" ..
	"4lsLyEJcNPjBe0GLvwNiDkkhWQnhWiI1Rz/3ADDRGfs/a9rtC8jOP9RtTPNHWezAJxqVHhf+S6p74gVtv/UQica6oAZ9k6GtAYNq" ..
	"VmHUYlKXOBOpQQbBOzZnFESt7Wi9Bb0vprArfk6bpe2OFHWtzqxbPHb/wzHH9Ai+rlZFzd/WQ09J9Wjmk/rQFCZbKv90Og1aADEL" ..
	"2KuOOp1ll2runV0PxHp47x67fnQlUrWtirqP8egROFPLyfMosoV8SWnyL8Xva7shNbwMVCS/NWPB1daPxhjGsWOmx70aUoxzg6Mo" ..
	"khQAT+eMi6A8v0yZ98CtfjxAUCVz49fWMxrJe8uu3sZDam6x3JB6jehTiWlxdSDrNlpbfNE8Eft9ESC2G2erkP+MSbJsCSswYage" ..
	"qFz52DLU9KQO1al4mIUsYp+bSpDrkXYN6yv5kH4TLrdQdLVV3oSzC+6ydYeT1sQVlfBelNX9Gm9FwlrZrMI35O6pMki6Z+bLF807" ..
	"QNAoy2IdKjgAeNKRIGxgNgsy7p0qFAd+VkqgrNz09g58AEZl4L1LxxkET+mPIzydrqry7kkF6yJR5TuTP7/6kFUxwjusvlPqpLTj" ..
	"AX9guLpzub7nGqFxllfeZxmvNHv5wEIoD1FAZdIA2p68RQhayh/UL6szwCmzmamSUNY/EGL/eoHfCB4nzGi2//6ZLBPag9rN7P+F" ..
	"tdesB/CNpsvtmmuH62LC6C8M6xOvNuAKkXhwhSK8Fn7EI6BEUFZ/eplPtm3OPs28Oi9TFB7wzf/t9ZORVjUzQygriZV+TghImoxx" ..
	"eCipEKtJG5G4nqTwyIJ/A4wAq061+eQJas6Sb3bBl+43Sis5bdpoERBYgsff6f86b7ji5Xi89XbWp4bdmkxwpLHEkxZaZBNysv7a" ..
	"0CDHRq+l/+9AUZP1vjWMlvUolpIHHsBMAr/uGdQbKUxN47TfAcidII4GrR4w68QfrJDQYQEgy00GKZGBBTFFxH/01QBPHtm3JKkI" ..
	"geJXCGbOj5w65EiNZDPwUIJ5X+CBpDBfTdsOhuU9B5igGL+36FrfKCv5dxh6JPrTUwLSdvV1fftKY9bAFsLFc430k9/kLDlvqACH" ..
	"uL/5fxT4diU9WCw3rl01wJKY0POI0r2K1WrBZaBwUqfIFwtzAd/KdKd08lw4/7ITGpfWnuMVXz412oTvSC166fQFItWcb6QCZqSR" ..
	"JoSA1eU+2lsDljxq3vlSYXPmFI+I86n2rZJ4BasGAeIKh77eLDWjFoRtmu4Y2fvpQz8529GLNMcoT36fr9eENQVg4kv9xBASEm5C" ..
	"4DBMamprKOf6TUYCGSsIyHpU71TUPkzE+LBKi+Qw76pbAPtwIQlq48HAC7EovINCa8g6qIGaCkddCqQuEoeRqHZA3kf/wv9nmxYb" ..
	"wfrBk/6TwfpJy/63ap7oq2kFl3OPjmVq8M8/YMGfwpJovStPoDsAMUibxa5fhAy3tXReANaLIV3ztTeZPGHUUGBmCyZnbE0DJOQZ" ..
	"LYSh/iT7GAyFNCWaAPBBbk3CsLoQ4MqJBH9CbpFnx0ksmh5yTJFCZehD/wZ2cLmsLOnCqi8y80Pu7cN5DQnwMfkHenx1m2Q4T+Wy" ..
	"4z5JYBJpQAXOxezOkpOgYlOivCOMyboGOcpr24719PDs+lKKTYaxEHBJ/papU0Q0qhCdsJ13VYARxD/khsHAEP0FxLvmMidKsioG" ..
	""
local PAYLOAD_P7 =
	"+mZfsQcqpd0pmqwutjmgmN2be1mVSsjMEOlADvUGlj7+feOHcLEdwka3qw6WqdP4txJMwXTiFxlU/dbkFPfAp1hJMQzhiwKLoWQx" ..
	"85Pp454vOHQSpFdBzO4Y3DGI4VFa7/kYLB6CKssMc6AvxAT1qyce7xmwLzRPizDalf+eX1qDXvARzf5IivyJ0hXsmHYQtHMWQwwZ" ..
	"1AaA37Oag+TX/EQNdf5IHtLXQGBnl3YezxOQLQIJENCq7Xy2L8AFtuqjPvdnlOtn7E16la1dGr8TRR76kX4UVJeuc0/JGvaGznoi" ..
	"N6ZWUd2nQzqgDuZsnQXSEVzwMB3/jy3mlqXgPtFT7oZHcbRebNu6p/+AeO+NRU0O38VJjxI/6O+4x9/VWs0UDBRWJnWfFMTJKThl" ..
	"mySBHpAukLHgbmQmEvcMOAU4GfNV5maljcnekLqNFIcG6eWI3PfEPYk53tUmmMDmvWXfz8Kxx+A8DdR4wj94wpnTmgh7S0IleumU" ..
	"QX5zEajHg6F3ZbmmBPamI/ouYGsefNLhaw2Jz041rsE4IzEFrDQwQ7RV1w5MvsVFlw0BGUL138neghksSzkS/iV7vEYRlCBus2+Q" ..
	"Gy0Tfe5aCn9MpK3lVlqzUG4Ko9Ba/LDk1TJ0O8Qc4HvdgNVCIFKZERVm2XqRp20qdhSvvX4fr9vhXotZOODCnxWwMPDdg60SSl5C" ..
	"OrNb1U7I9/HO5G0e7ryyLocqCe4fWpqk4kGXjSuSolomjO54lME3jOywQ/Uto5oE36hr5NoE3CyZDEbj473aJspFWIqH0dyUqh6h" ..
	"5U2Meixzfn2qmDckkLi3jkyWZL7pUzmnb48Pegf3tbKSpHiCcZCKLA7q/LYmeXMMJa6CuBLbmSA0F1fQCwQB0pAB9H/rVtv2rcNr" ..
	"RfM93SluSRBU+69UyWEMsawE8JZEOr2IvqZsz0RhSMFjlimr5ao78jxsyn789EDaf7J7drfHE1U7BHyw2zkQ/FAksMsIR5v31bd0" ..
	"QU7f3T6Z+w+YhbKtm2NYvqhEo4VvjSefvc0abPQCasRDJd66pWuWpgYciiILFcwYOAxEiFxupt09ZBL3LrGW7b1gZ6mcN4+7gwA0" ..
	"KoNDb6XxUAe2w/mOCQNDy7YiN+CjfbYst1hjhwF2HtsugREdn2o/cdEDWKrFu4dgiEIMMlaHocakWdyGFh5R8sLrzuF0YTvJAwl0" ..
	"teRaWvdnQRa/y3xVhC07h5xRK1bT+GpyezaXZuTMH72nnH8CVR6tXHLgThToWBWIhBma1c705ZxDEYOKwmjKnkQYJvTw0goL+Rxq" ..
	"uJRQ+o2pScLg3HyfmaWx+yUK9qhpgEiLnuF99r779gnEJovqKM/sg7Kuuyfb/dVS21s3VVmbA4lgXKbgxRD03ZRi4/dofBPFHD0R" ..
	"49XVyqC8VnabKJsoOZneUTWjT+TBkIWMXPrrvurXSJpPU3ACKg4y+X3Pjc+tRCg4+AoFIfW0gTeVJSHPGBj3oPBK1UkPV44JGhQ/" ..
	"2BIvfZjbbT8kpWnks0G8i8YuS7nfDWYe9ZE2naaYm956czR+Wro6quCc953a5skS8ANCXXEvFL1Oj0ik4J2pUVWfd8AP/zNe8xKT" ..
	"i5fbQGhcqEPUMOrgs3tpk6tSq6iwx9WmfiVQtcPPmHnyo+4WKLSv4m/xmxZ3ZLWQeeCX3tu8X7lKOSc24REsVWpvfAGajdmyKeXd" ..
	"/So7J5RD2lfQeeSCA9DtqDRmRHulLlsPXW3UYbf35/FbkZ0xOmlNo97dmsAMbI9TaXA8RjsxnzyHSeKiNuJK90t3qOcsKBRU5rN9" ..
	"X4WB1+ENh3OPDIkTJXNgPrWu5g3TYZzocz17cq9Ub4aM/mlIP6KHh/6rjI3/GvYN3A3R9NIL2O1xMEmzxAUoWl+/iaUqBEdnXZAX" ..
	"HzJ6kcATbyIci8kBQxZYqUipz+qlIsi5FnhZopdWPJC42WZCCP5zRMDITuaT9UO3BbpFYLbHb4t/De768IVNEn15ZtLVdMXmS2Ca" ..
	"S3TBQ/3XKCGfbEXi6cd7EBg9K/2m8TJ2cazfzSZw6rOV0CX5hnAFhw6zKsNc575Wu2E10TdrWq7eghJ0ffv3W8eM96HdvV1IzfYe" ..
	"0CkfOvzjHDS1Hb+fiJ5jAruqiLcA5Qw0E2Q2kkR0c67go2podLr6WIZqlxrIave8Ffht3Iv4fCRD/6Z48N5+8SgPgxZpft8f6lYx" ..
	"36gUS03G7MQ3MeVA8It+CXn66FK5TfnlEybXvUqd75f6MSBEi59uymx59qopRN9ups4d5tXw+mcf6GHXYaEnwzKV8lZp7REzL1CK" ..
	"EekOL0K/Z73rQe08WeW936JmEVLS+j5OOULkQmjCa71h4DgOmgha6HXjcRPouen9Q8yoxpNGY5iZh3SeAwcd5PI/TLHMEMzqmgrh" ..
	"h/aFf5B5+3xp8M1T/7RrtTOwMz7UYK4WrV+xMDGK5hdA5242hk50SHQQPLqFDb5xSKzBZqcLx6qYumYChG+Ddj5pqJUPjcg6bJcJ" ..
	"Q+JJSAQ7MpuSNEo6u4yVyDCdCCKAHj6yOJpuZDFJY6wZREpgqV6gjZlOSk4tRRtfz++R6CkkQoM8CsQ8NCRmfw8Z47Nv0r+KcKZy" ..
	"Ay8vokdd+9jx8RGcVeHOKQ8RmmRMt+ytgf6BUH7HJGuxYu2LwopUlptuxa3qNDSRPuSxW8si5gPE7q84FrV1i9dOGZt+tW+qTqaN" ..
	"cUGlzof+LgfF5xNstfhtvh8NwOWESWhpof6PjKgtpdy/VXQYfS/YXes2i+XclXYfgmKjjH/vqHCbyjb/gdxsCLBWU50fjRg7Q7wk" ..
	"/hoRTZW/uAooSz2BuoImwx0mYMXrMKP2XLcKUz95FWvUabl6Sa908YNcA14b4COXYlyNDJA3Yl1462o6YgJwtElFkU339KboFTVK" ..
	"k2DCpOPTpYJJkeSwkHWjEckQmeZPn6IFarDq7MTVHqP53GAv+L9Ed8ExW63s52bg8qpWgFwOqDhuVtTFwl3qjTaHCdIo/0ZZZcd8" ..
	"FmJ8RSW/tEFOLg+RZJ3g1zoErq13eNyszaDM2NS8w+PyYmo/vIjl33yfRziycFFReJAaxXpkoYZnVEEz3DxWT5/cCfZyG5X/M8QF" ..
	"t97lsbSzoOyXYQOiXubdZsXErXI/Ee+y0CwoMyCR+uaOgY9TNynD+yOovwgz3JRmQGU0Z/uD+gssO0rkT+fKcgU4O1EJxjXeYWks" ..
	"/xlpzOyu0vgLeT9bvq6nhkV7/nLsXGRLOwGlsPQ+f5U9TcwCxHod1A7xiA2D7p/BtyNWV42oQLTdBNvakSxTy79o+HjZ4W9GmRsS" ..
	"Kx06hQlJDuIwEhQrLwQnoz/6XNK0Ih0Y6o+rS59JoXCzYcNQ1C7iJqJ6D9YZJDmUDG39mYbm/7mKDb2d+aO8X3c0ENKE+NJfOS78" ..
	"RAFMMRzIyx0mn7FoxfhANijr95iBb5IUzxg0x1fkOFHt9A/XnmlvDAuIjWGRdbMb0lg2lozO9zaiUe9oWjT6lYdHsDhHtrISeJ2T" ..
	"uPCtwlvxJvclF+C1sm8mvNT7Q3MmV4f/ERwdR/sktEqd4VKtTCMZ+t5/nlRy1dMXwSNLc5Kn9ynOQfWYMWVPjWiFCQTC657c4eN+" ..
	"S3Kbf2EVwaduo/KcZzczdpLu+M3QXnjCFMuOQABjNuMofcCBxR6vA2xXyRG3+s2mFm4h7dQl3kxOgFFWyrDS35anQ2gk4vFusSv5" ..
	"pxMr5vg4U1ynlinKipJp4WIsjcB0GQhwLc6/c4QdM4TA9csaumZueSKmVTM8zrLN1uRMJMESPkb4jX3l9Ru8XVp0TQciHc48hwss" ..
	"3w84kav4BMhBxgGezSADYUr/LCL/tuBvC46xUv7JN+2tSKG7ZACHbn1FQ7Uv/uTo8dq9cxjSQS3sErlYYfCKBoNirr54L5ehY0E9" ..
	"WEZo6xQVNSm/ScuQmRTvOKJZeI4TnEugQbic7o7K+xrzMR0J7y1LJAd7MoDapN2RchWCXjI6qNQB8NNPtToEkGH01FcuWcDrAYeO" ..
	"qOVSPrq+wy0rzG6pMu2+/xSDNOoSxJIFdnIdkbTKXCZWsOxs1tMksyKoU1A8hNd/vE28ybL1V4FuReiVLFhv/CyPCb0rEN1BLowg" ..
	"+2LccItm+6/xuPOTcJG2P+lsPcUIZegiYrMdn1oLRqyOnTFHZInEAvAfVB4HoGkFNDHxALnIX1ieJuH+ZkNgT8J25noSdVeS8HR4" ..
	"ufJrxQ702LKL2kOnK0xGGiznDSqwQTw9+ryEDljKOhuVigygFDz9crcln8F4Tver99GsWgJY6FbT+bzeC+BmoUcCi4iUAQMxEmbB" ..
	"arsvlXHpRvXRN1dO3rIOZl8fcIjqkAck3wUk2Tk6QGjlqGWxHG3E/SIe7iyNgCGoesnnRXQUcxTUeN14bRFEx42ChNgAdL1UbQbq" ..
	"KUfEnkB0uXvoDItIg92ZpHaOU9CCLwya490WMHpNx8o/e2xtKHa6hLojEcyHYULiimywtQpgB+QtY0fF6WuvuhTDpYnx/JoeAWR/" ..
	"B2qCHEYaouH+M7JgsT2iDwnEXxhplS38uPIrZghbtLpwqYmIxCEeUqq+9QzMdDXioRJ4hynnroB1PYyEVVpmGnOZgHdtAC2psv8X" ..
	"xeLs4Cxo2IOPz7SkwC3zhgvL0lKG7bOJWvVtV8ClcaTjFEK9EA241E8v5WVsB1acMBzwdt3t8t+oNhfz6+iFeO8uNSmiyC3nXDtV" ..
	"B/0ibG4fXENmV6Whyqejwp+vYMq/BdQJbvOPaMtxUQhkYhwpgYKZ/HJUcxXPmnbJefUbTR8RVpX/QYDhQjTXr08lni0cY0NdIB2i" ..
	"FWqXwe+zwoCJCqc9kYzgp+oWPxIpPzAFyDZ8s6NCYHuTRqKfSeqdOH5vuhCBv8WUXJU0AiMYs+zBmRo5XyNzP+eiVmEEFVg2sfTX" ..
	"gagjOEGVy6S0TcSn/ymvu94ewOu5Ou8YwYYTAX8o71K83zqsTFku11tDU6265sgwRBtDEIb5kNvgYVYSgkFXu3ilqa/4AOVcXMj4" ..
	"SmoSWXtQA8a26zhVN4/zIjvV7soIi9G/+XgSF7b5ZJF1nwvWq6CQGstO4SPIOOlyCLrPxvgO6K+JzlfKhJjWHAxFQyIILID0vr0J" ..
	"BvCxr9qg+OMiJCPHNZYiC8hZZkhGapReVA/KrzaKvqCPd34h2EbRXm4b0FYbeKs9qpVJGK6cGRGevu7CPeZy2hpwIiCgjvVlJm2A" ..
	"ZblXUTuOWMo008ht9kgUQ8e9oTHKPMU62pLBBy4moi5Fjg34lEGlFhb4ntPiksjuiptmTaR9r9CCCx+OhnfplBQiJWN8YYExDeK5" ..
	"V34Mjq0BeOoI083lWKrr6fBBZtEYpW7gdkgtF16KqqC7I7lNcnXeAqqnY8nzFWRZPdVXGpaWL1vLyotjksf7NQJjYE3U7rjvKC3j" ..
	"SJET2850hbIPL0nqp0CMfM5f26Q+zK/d1RTOeSygX/Hj4DbfpeF+MKPWnMl708+fzKOiyxV7UUw+L5Fpdxrp6sIVmSHrzwKmZNf+" ..
	"C/JFar8B4K29wucXqZqfgsCTJRkNTNU7N2a8kfRmKg/dNXB8OpKh0t+iPzIJzskJuuaT+huJGOl3SFnnG4R0YgqwH4/THSS5D4RQ" ..
	"B/FqyK8FOGwsYlCiAyPd5csqtgWf+UH3TOV1hqpsrDD0Rub9084twP09jUW027fK03/WjFRvX0/1fZsNdUzixcojF24M8waI8pF0" ..
	"b3GE0HwnZ9k0khq4QsLfGJ2kOhzvnnjUivwtb4ts7YagH/mS5nm52rXrU0MCJHrfpAo1pO82I6Ho+Z8IZHFiwV6KHfWlEYrRBML+" ..
	"b/DC1IIUMjZTe1iMky3ozwAh7oj3FIZxwTi7fooEY7XDXqxv0/WuRiG0OAb8Jg+L5utfVWqUKORTu+naAeHJGHnvkqobM3nVStvV" ..
	"7uEIk4JV+RB2H+5aX8DGp4h+isRwstpYR1C7g25twhj6PxpouxGZTXPA8qVMZ1nGDWLxvtmPlZmFZ8TDuHflmxP7VMI7/QVolOq0" ..
	""
local PAYLOAD_P8 =
	"T4+/eGEQtjObcMCCabOBHS/ihKwke//JjfuLPkZlrMnV2LXVJS3bhu3MRfI9B6ALp2HLteMDUxerpZwVFgeF/oMmF5k34sTyG5tp" ..
	"4LBGhjUnN43u5cSWGooc0fzJAbsTGhirbt8Ix7Gp9OGVdiJatH18LNC8tSzvsf2Al5Ty9ZxVIMGUq6yI+OXemz1gAZoy2Rm9/Q90" ..
	"D8Ve3bdUJjwXxIeqmS92PHgX7WjJX8/fG4jdtenV0g+19ETDUCc3looyAFY/avbVtRgUnBPSdHecISjGXbiWI4ohL5S2+S61OoR3" ..
	"pvkoFBf0Qexf8Y7GVzep/uj5YX5N6R8qJUVxdXTpojtIEMmRp1y2kftSSO6daq8bTXzzBz+ANwZ4x4zRnt2R8iKpQSYnDEtV82ci" ..
	"0rLxiG8wfdBC1VdvUvuZ7GObriYb86+LSyKE2SqGf0jJIdh0mlNxuntvuJMG9cj7I+/9mymA/ap9eg4slyPF3tq8joRAhMzQpvSi" ..
	"NSa0OrueELUqiQJgj9xFIwCsgXjsI4rTb8MZk7kbqkcWeJmHAZiHXgVkYt9ZDo65PkXf/eg1WB+4Nkrqe1Mmg1RjWke6KugfaB40" ..
	"joHx59N3n/ytIfb2CmYrgD+449R1xKVU+cMuIZc+ZSdBeYzpvjt9sRxMo36TnD0lhQ+1DPbl5la2cpastFAzbZbv/LTKMHGBVt+D" ..
	"aZ+7fPtunwecf7JZM8L8/gEdTNXPeW7E23FvQPda/jz+rzf2+C8VByfJ6Idx71el+84BOXjrU4N3Kw3oDgHQSSaS+qOYH29S/2gP" ..
	"S9ts6lCmz6LwTTQFRhrmfWbzk3sD8BISwjMwoOPw/NWoBczmmKS2vWyZzulPHZpl2pE52Vpbvt6GRCDkjt0lSChK45RiXp82fEvt" ..
	"DWYLLRvogHftDiW6BqgHTX1HVx6mP65kSp3wdc/aA6gqvHTeMh1gtYGKELW3wEX3LprUrR3n5bb8RWXClJ+WbA7UnWji/mHkYVZX" ..
	"fM1d3ZmJ0Qwqecq99emb0qeqYcoFEA/3G9Q4IgiYNVom6NINhuStgvOme/wxAzLfHu6pODolfBIKebmUXw91SNuGHzzwAJhje6Xr" ..
	"ZIXNV0kY1k0lTlaC8+9NRqbFnp0ozUst6AF4OolYo84Uu+5EqD/lmLeRJ1ciVOvkFaX1bmy142uPY4r3hWMysK0KeqTCUM80Eb3N" ..
	"GaIbf4b0bvTA9L2y7c7Nn59HURcPALal5snaDFqc58xU0g9VBQsWnDJ3cmYBv4ehat+B7M5IrB/0sAiS3EDl5W/dU/tScA4UeBFr" ..
	"f4pGDjUqr/abSfHuF0+9CYKp8EO50S+JlubeLybH1j0q8ax9OIjFHZULCdhC2Q5JW0W3VrRl2h0kthtgfmvq2JjvbBQxrP5kCqPd" ..
	"fHqqH4/OHiYW91NN02/hL42AIsUSY2YeVBUUQpI4SmK+gEsUT9u06PR9WeVTF76K8aROdKscoFrosVFSCtRfeuoT0MtVnoqqW88r" ..
	"CUhNz151uGVayqG7sUOVqkSVnIRRJgxnfalMikfu6Q4yM+gIo4bvIY+fonrfmnFo9tnD1rvIkhFvi9dp1o47Ml/3ek4ryCW1lD8v" ..
	"YPTJZKbQ5B5mbrMxQHpx8eudTHU7oQLpfRmVpnrUKuLBC456L29IRUrETT0i1BiHLBwx1DjsVLHIWZvidZyL9ABx01tAUD8Hca52" ..
	"2CyUs5c7fp4LJ2qpTiFXqx9QNOh+mCJcUgXXFqgYRViw36pNASPZX9LOox65iTLvWDBd2xqPd4Aq6jpBESHZ5u0em01nPxQTV7Hm" ..
	"7uBBGVaXWoiDuv7OiamuGPu/3uohh1mAq4YKZodaA1U+Tvjj4a2WpBzfzU9+WFnPm/YKoHSJsg4EB0OP2GSIH3TOuZ/OsIHZrekU" ..
	"y1+fTJAMX9j7x44q8JSZVAVsybB979CQmUecp+850Z4uLBy50CRMSfkK3j3yu7qU7pyiFJDybnbbQ48H8s0LE3lO5JRqf0l/Jl7Q" ..
	"u9f9ZWuFI8wOj/KHO/PbvSN5b0w/z1teov1I4S2piWr78PnE8uwkM/e5nEXSHX+buJxsCxZCghpuEknNOzfU5k3qOUshpGp6jbni" ..
	"+aDVFVFy6MeXD7tCYexofFh0vf/NDS5GJjc8jNz5HOazvJ8B+VDmw/QNh3zLpJDkw9LtFKn3TujadtREj1yQ9d8cTq5K8PPQwR++" ..
	"q1BytUPfBOnRpTMhmv9ga3G0ro5cePxVOeHq3J8eMau+u5xtWvqFK3l2OZlOGqWxRmAWkVzisJGqcp05nubISQNHI0Sv0/YeMJqq" ..
	"tyhMelYD3nvK41aiRuSbTo6jbBkFtHlSifGHly1RyQJhl97H7XNfEYhn3b5EW5Bky/fAsy/LjjoQJfUxdUqQ7Po6GHNrxY9s+ki0" ..
	"x6lYnzd+A9L2Gds2rP8oMUTPpAE82gC7fe1ClQUc+bGX68mtleAKEzhfsUOClD94zEEntJa24oiWAgqKKnJIMiFtJ8d6mDd9Jsfj" ..
	"/iWijybcUrNZ7dk7qIalqciaKVZQtvf3Y6CYDZ3kX302FXGARUYgT0ZOp/JU4qMPci7YFYLdJHng3J3SuNEObm55Hy7jbTbdsYaB" ..
	"Rspefid5KSTVcidzLcpdEzKy8z3fkBT7zhLt3QX1oPuQPKOlomCvE4H4oO//Y1QZYbOtPvC/7ZsPplvRaTJmG5Oh7nshfGXnH7aO" ..
	"1VEaC0DDjv1qLZ5hSp/yvuH/Azu5o2Hs0uVV3halVoGcHtrfQFk9tCao02Cs5QqT6jKgu1ZpLAUpvl+R7EWNx7Ea3Xb8D2kXzXcB" ..
	"kCENPK1IAlRDFWTTnGqkdMhld/VqAw67bzsGHMv6RvmNYDYvvnM0T0i5075TdEuFzWV7si/tOkKI3zqS3k9djKGCfOxbUMp8yvET" ..
	"y8FgxwWlYWkHJX65bzos53NraSgERcYSPqwz4KQpEuA3wSFfAlfHXR/xFwqoqqglRyveay6NB76Wm3soh3jsTemLZVxFbiSGKgMR" ..
	"XyDaovnpas1J1sl/TMstR4b7ZmalKYS/bjKHtI61l8yx1FcP9ooepYnwlhvKINLbtZMAWLryrhk8Ep64+zG8yuR/DBsWnlmJzxVX" ..
	"sZkXi1TA2RZj1MPF8iQLRm9kz6yw0ZY9KrwLQxd7pC3bi9K3ZlXHk3bNKMF6fZJuUiZ4RAJ5HnQgyJHynhRIuXdYFRDpbwe7yGh0" ..
	"uKSvncjguJbJpGgclQkotOfko6+XGVTQts5yEHwhd4sq5K57DgT2aQOeqiVDc9V4tYhN3RfGoAu7tlvLlzrYvQsBG85IoOuvXoyp" ..
	"5EZEPTTB81V+jhYKyeXYqRIBpwLCKEnLHDKKHo+fkCLB5HqcmNIv1ZgZsw2H/h++nB3bUbR3Rr0R7N+9MV9jHULybbgGldcqyptZ" ..
	"g7v6LbWx+nr0+8Jmlm7AKM0Xjj3J6VIsgZduCvRn0yr3IYRdZ98Opl6RAoiRTYiNiaXp0vBZ1Z09cxy+COp11A6sFf5lg9ASTTqR" ..
	"/lTWgSMVHBlsxFrtIKuOPoSIoqb6slS1brHdlilw8RwkpHntYqg6aht19i5s5IpmUb/VDHq2KZN1c33ji15p3Qkq9MGnpLIAghRT" ..
	"21vBBwf1N3d2rFIa5e6jd3ANTqs+M00DGNId60fyuQxhm2lbvgr5i1Mtkdrkz58XM2TjF+4MZ/Zy41K5QwkTQzPItkU7nw44D6aV" ..
	"7BUJrQEukggLdNFoonGijtpiw5K4GYmGZzcM6DMa0vSOl/buWDEm/Il2e3YTR8kKXbCSw84taAYA3w8RF9A7SD00KTlpTRQP1Uj/" ..
	"9osKFkNB6ExODTjxixCnVH4SFHRuWPtjgXRG9w1UnTrhtFfEPjYTQcCisYkAI/hDCihIo0ZL8EIZCgB9IW+b7aGy4ThsFd9wXMjb" ..
	"I+9tdc51A5hA5GU0rzdwP/PVHBOYfrjY95ghbAymT0X0i5Pwnp3Jg8QeDt8qRZX+ejQ/JDaQT/HoWSxr7nTOiOcavSVF36x2cO9t" ..
	"9EuaclcoKX5yMg/YUTdEbxy9eBKvi5CQBwjErvU+M3ZE7evu6JXWizEieYM2ulTWA3/pj7cDBHGnAZHNaLNrtshudzSMGAi7ngOU" ..
	"fT+EbOU4N3luptGJAUqR1eXSKR5ab2tegjI6P31qHiFHwTXc4JxFfxvM0iis8uis4nq95IQEAGcbNj6CD174nXbnyoLcXlv/bKYD" ..
	"4hyGGVfTF07NyzHhHm7nFSVV4kjLy1ZLJ8HrRYq6SvFkkYpFrjQfHVC9WYYPfKi/nhK3tobX44iSxLJ4Y2+pGoEpJ517xegpi57b" ..
	"AdkilHd7HhOc2eiEElnm2lrmfvz3kIzuWvL/EIoIHzyMnBSBeTR54l+YCLFc95b7brlbjeF0oXKf3UTJYo7Wl5otzULA/MkCT1m3" ..
	"JdZZMeK0kAAD2LL1Or+dhSccKHWje2ppV1xoD387xI2BOidU3XeI1fCX3M2LfmFXmwk2M5SNwp3pT6L9khDHNe46ladANwhXbZBD" ..
	"ZB84emyOokVqtKqnzYHnP/4i1au/5h3yCfHAP11pEKv/Lh9Zwl/jmCEPhEcLUObXKU7i0DzgVn32jCUPrF3fVORQHqunN6DWtq9D" ..
	"wMLjE5kkKYSfiH/cUfL+tYBnMD5b2CAVew89xRelZGBvbnlG00r+phNrmm7yGwpnH0sVzagLoXp4qpk1+9pqHLXDnLafzZvbnous" ..
	"LuQSnT31wJ0DUco8fjO649/pKwtV0x7KUeUSQ/HPj8jgBlRUeDzvyxT/rq6nJFOQN+XYBzIeAX/pJcBOl4g8snJeTLPM5r4ob4vi" ..
	"bNcYD59c5V1bZZ0UFdqU3469eBrsgpM7BoQta1q+BCpXyegMO22StuBiZGGvMMSs5pn5ZVQh9j5xEBvZxW5+nNM9lkQ7PArCK83+" ..
	"sKZS840pVh/+THMyUiChVShMyBy0HLch/3SMiyz+GyD5Sr7aXJ9BTwK8ng3UGFOMN6ZGeJZoJgAr5E/g1pCHzOCozbRYsJnbw0Sy" ..
	"I7zvFYvg6NFoX54Q8tV4fckeXDLzONkYlG2z1ml31qA/egxZ6v0668ZdT1jLhmLya0/uKIb4M/ep0vrymNOlcDu+MxjMTLdXodNE" ..
	"IVS819I8ZV1BW4FWvQ56MtVmAEqq97CwynVdz790OkZTxSTMcjgiUzNe2DU8eYBCYyAiD2t1r2uQalA94i8l9OSVvdW5wbbr60Uy" ..
	"o5VZ10fG+nIpEaMdZW+oJPzrtIwtvTMkV/4J3TqPcQ2tWhA1riFQm0F6AxKX7a5joPQYftrEup6QpBqfc8WQLjVOrkk4zwtdGTdH" ..
	"hKnS2FqOetCy3lEUj8SgAdjU+jN/QT12To292GHMEHl0cguwg8rsK4T3Q2rZI9DDzUcOs4lYFQiQOuXlU+KMT1gsYLboEd9hmoho" ..
	"UbCYWiV9OsJv7azN63aVA76DmLYhs225WpkB1wGv4KMY2cB1Q6XF3hlcOjUCIH/56EpSxozegWECVcdSA3LHs78+LazC9JG+Bew7" ..
	"8ZjoKhDTgHj1qq6aSo+vxO+lKgvN1T3uFOVaQzh9meI8cz7j0E8Gd8NLsRuXto6HJ6cdoc18YzcB1QIB5Maro45kO3H7dW3eLGTA" ..
	"abJVd5l4KaflpCDkKXPm1haHVPZSv6fADCPl5p8bjpN7OLOBhXneaFKxnxfZj01cckFAzrIpBoFGgdFVMZbpIC/TKelgo3r6C/ig" ..
	"98JHjGG3FDD35OaH1OMJdROUIZXV4V2/F18LkgJWkYML7I2klezN/DRW9roqoiIojQm5oX1ZO5m2ZLR9NvTBKfQ50gbbEzqm+j4p" ..
	"quDgVAQSoMX3imBjfUxUCZYt9DoA8nQvAF7nxYY/qa3VmWfbG5AmaVN79d1SbP/+TKRkkIaxxGd9FBCIrfgQW7OrNOsKEg41ZUvu" ..
	"O60t2j2WqxzxrVbUYtyRfGWwVQOD5Bz9F8xhMdmaTMxH0hIVaDahC9JDGYlhFd+f3Fgz0iH+QrGMvmQywRPQu6KRNuOKWGytgrvk" ..
	""
local PAYLOAD_P9 =
	"KO4TjGTzs3WEIwudC/PFSNujkf1wogjTek3fTfl4HvUH7ffqoEVv5ANsQcTzeOHSJMa8Ylhj1bYrTmewObNgFnOknkZPfSylYcsb" ..
	"ydA8uizb7mmoIp9Q1uqtlcA1XpUSrPyGUyjdfi7rnwAan0FTrebk5yYoN42KUVOd7L125Ee98iaGXMihm36rgF7jsU3XVf8gj36Z" ..
	"1XMEFfvAI+DtL6HpLFCWKHkNpU/T8Uno/bQPXDgp9RjKl4/y3oTLQWA+L/KxNfpItKxBLKjYnBhChrOiVp3Hr2iBhgxPxp4CvgBc" ..
	"Mn8wCM84fnQxzu9fV9Bv043+zntWZT51/3Atp/nARz50DXoF5KDf/ArtTMv9owgvrgr/vu6AJFv1YXEI0l6GGEZ0mhI9jOkq0oi/" ..
	"TG63qD9txFJMFQi4k3XIAW6Fz8/eDBTgStu6xw9i1mlS/AFJH4TUn2H0bzlhQHwaAPHSsSbb5Sm0NmflV0meEzLkHKH2Mtlhjgaa" ..
	"ILNcHB9s8WzthihpN5SokGQY74lxM18VOldxpUT421qenlVKN80wkwFsnrnTqwPRHumLbS/vwVUedMOInPmnXl6Skhc8QNhagot+" ..
	"wV+8rTfWpMjv+P00J/wDaPTAxMoZsby4qWSb6w58kKLi01QdN044QuhKNNt+TWLsw8OGJ2qnz+JowqMwkYq5EC/92rnrTFwC2AKF" ..
	"Qc4LY8pF1iR68xu5OSGuKWHZm+QBEn6Tde+AAaB9lKBwbEP69SESq1jDTfKeirc0LQmAULPFQfS3AWjUjLxfmCUm4wzKU2oI8IYV" ..
	"Y3b/9vSbfb3JJxmYnVPNbgVSDgtX7iS6fKgf1BOlgTyFvtfWy+z5Sx4BX0rQvoOWLstTv1wV6myY4RUl6ILDp/Nsz7uFIqrE47Ht" ..
	"ylI6Kamu9czqkm4KMPJVW+Wqkyv9oG7zQfVGDEA713wegD3GYLRc0zvWqROk8Gz9w7xp2FJN67IXDufTOEtzwFRtFbShxt0eg6Og" ..
	"83b/36MwKr7KJZ5lk60uXvo+VKqikZQg5594CisFpBEG1FFehGFO/YQlbVRNjvVBvGz9hdeJQDJOPp9aNiifmr9/PF22Y3BmsK2c" ..
	"gesGHJb0SrgxwkeUAR8n7VXmoO24BjTrRom41avWqvN+qjj7pVbrYetRVjtiDauTrh4GgWgo+GOok2ZRfewM9LciEUR2dwXFS7Rw" ..
	"Iyb1PuDCCokPRWFP25TKPUx/6tKx6CwuWBD3WFFtf2ISM8gjdomcaoHg6lTan0rOP3LgiTWY/NQc5ApThykM82hIh8Iikib41cAY" ..
	"BbYEJcNfENKge9OSFGbyPN5/ynblQgrXl9EtcZUEajaX/z80QXk/nWKAkRNJ35twEaMK0x0km3hlbLc3cK2YJjBnm5CpFQ3Drqch" ..
	"bYqq7qPtuVt+tw6vH1b9K5kC2H5l+NY9Ow5FyF65Exy6nsOiID7INjRaualR91VkqDwPhBvr/aWaPiSu65nl52Fe2LyS4aXkglzM" ..
	"6YluQ7MLuokB4qv2aLzG1JT7Q+MoBs7fD9zZ6Bu80AeihUEqmZ1lqH+qocIn++hLqAJSA6Bqg5nKBnEOOk6MzBN8jPJhnv+FtV/d" ..
	"Jw7VVXK7M4HpykkUjz4GmrzKaG5ISAldDO/vuHje/6P3nFjdwYXZ0RN1eqxWpui+PlxNKUh54PILaPFb2iHfXkJwfki1e2Kd4PU2" ..
	"fkDgmuLmLgoBTgUvNXaiHdYXWc0SQVGe1aBwJh5OeFM5MXHNw3hMmhAO0KYwejRN2vIPLv7Hmq8oQH+SDxcZ194ggQGwQwXYcHdf" ..
	"myTtyz7+EyiPhwj0/tcvRvCfzts7WqaCSSalSaARCdqyQmfgrWfjk0DaWy2BJJrc4E8s1ebgM7rJ5XIQeBAp319b0XJXz7W5Qhfk" ..
	"0gaYzPhlKlOfSEq1USXWf2ugJeppI17rp95T3Eu2+etUgSRj6UV+/buFrx91YTCE3FOxFCGpM2BWNyC4XCN5VmQ0PEzrLXs/Usvj" ..
	"UIeT9DKXyo8B30tEY3KUmP9PduJxS3WLBMXcb1N6cOjxoGqi5jygeAs7V0oROzu0P8argOHmH5RdMzHAI6SatDUJ93Dyi0RYCDme" ..
	"4lT1+2P7BSJRL+vh7GBVpWLFfhCSBWwzlhMAlVOcpTtwj2mXd1aMa6eSwZnHih4MiKSPxnGTR4DymRbQ6HqeKXhXwm152b/tO9Ao" ..
	"+OEVkEqOih7CqSzTA+tHCsOPdAEzS/fWbLmLhB2AUMRs9SOmRQD+G32BgUGS+eauB3ty1ebTaRd+V+FfCFM7ut1OrM1aB1SgDurH" ..
	"IOrQBr7Jr9m+CpJSTPgE+y4dISA63dOinW+5wGIs1ADpRIYw4craw6VRXs/JT5voh9blSAv+CvwWK9M6rwooadOb9+IM/Dm3KLcZ" ..
	"vE0xiHit5gndSmOGkSo1OVP/qCDZlqesuI4E0DwCVrk/CPruY/Az5i5pS+Dwdbh6eAsGK99P4i4Jxy7jJ0QbYjfIWjIpMwM2NNpo" ..
	"q+K9o5ybZW4WFnDR7fnMWBbYsz/+rSs+wNl48fjbxV14FYXsRxtzlBfhw048UuSh7J1nUmjgNzyi9rz2lUsRH9LwHNfXO4WuSQmc" ..
	"SZ+13rVhGIXimkK1LP05ikDJTITr0VruBvRKZxgiPBQRdDgjHNK1FwOhVBbeDEFZGEATWiSdAqn2EUBE42in9urzQN3swpSqAtBe" ..
	"Z1yTYMgmqDY3j+87yL6S/engR0izyLJI3RpMq2kL4rqKfE3dJEz4LmK9yy+3W80pMCIEg00Ej4Jt0c5kLntbn01kDq8JloO9/jUz" ..
	"qG4451LrW5oRT/5HY185WOvNXf9kL3Fr61Nach4SdVvZJPTrhtn9tcyuZDHft/y+kIH9w84M+01fdSKDiVDT/4/Ps/zpt6dpZ3cd" ..
	"Y9s3JaGIOF2+lrmhBEmuXFyu9XGZE8N3gIb0f41Lo0+VluNPXmk7rtcB5HS0Ijbr9w7JbKMixCA+ZYjQ2DlfYNDeQzGNxZQJ9J1m" ..
	"1Hxwgbv26oB44POAtNBQdq/DXJeQY4B07XG8E9TEEj+Rq3J3I2WQ1V+aa8dqoWcpsRIvF+tPRimNSEBH5MEmUJgBiaRz+p/zOVZS" ..
	"ylNre5AbiS2r2a5723/62TfLb19u3Infh72lOSN0yckI8jIufXvZGhr6NYIYfcuD0D0n9VkZ4mT1MDX2/2mClPUyObzcjH+T9sik" ..
	"xWEdAxQtRMYxlQyzzgLCrXou5WX3M8itaH7yaWIC4hoH71tQqSeTj0FZzGnWqBtHfC+udBiCEhGKG4/fBN1tBKmQghtxaEgN2ZwL" ..
	"qDu9CAkD9pmq6n+KypcQFktaExpyMdIW5wYOvWGI3HTFRlJSoPBiewsY+vU2TIFyxOOqv92APYSIA+fZICJe3bnU4opAj0slcR8b" ..
	"Ki7Pg9s9JPULheR6meUwbPHFOexsK64HOJivXKwskALgsObsfTGF+5hYcE/3NsdVEYSuVjDtECvqaZGI9Z00YcjZ5cnmmsqBJ/KQ" ..
	"oVAqGHN7m161snfzYlHkCW3bggImy6/Qlr4z0y+IuOz3miXzXitgjC/1dOF6PcLMHfa30BIN5u40+S6KPMlqtvYZ/wOTGxdCqDu6" ..
	"aZYLWpuiM1uG4w+afzloKBVJEf3NC0FX1k2l5VIneovqtg7p3g4kvKhfKfzd4LqEas6irPru1Wg079e1rc4EbEcS9suGm4AEpHa0" ..
	"gRIJTX4BzhpzdJngdZmlLNZguFfBxMQ9z1vJ1Nd6zFJ4FdGEIDR0OaNdGbnYR6ne5tJQkrHkaqgygpLqqblmIG/Nu2sd41QqpXtf" ..
	"7ln5lrql7cqkM9ok8+9dQmeapmNKVR1bkVtpLJdrSYg/rcGU93eUKLeHIZcc36PQ2QFSLJelMAJde9LwpRVcSAmJYk/IOnVoid3X" ..
	"HE9dVjrNHd1haCCMr/s41+5A/+6cD4dH3G4w65yuxlxku5ihIQPqqFDKaDn1S2/+hEOAAD7rq0E5NpS3LkhTwk1XwyrNwcgSgi3f" ..
	"UoAqfB1UyDHIc3VTW/73bD97ITz8BR3mWxIF4P/j8s7Wxg4daRX6pivnbF6MmdJ6taVV5/t4HbaGdsprGaeo2V4SGh/gEtoZ0LK1" ..
	"YhINSdifHAQnH891z4SxLCpBWLQS+Z+TcNlnVsCuL5vOhOxMABdlx5V/ek7a00Maz/KX/BssIVHbuF+Dr+SVOUX984CcsJd66YBm" ..
	"84bzhlothL5vx3Xom0kiN77I0MN5o2IjPaJHe8oxANeWPDNH/4JHcT1GsB4usj6AYvFzhSrS6xPjsvMohFz3mYsDBAgXz/aLiR3O" ..
	"DFZdcnjYdKDD7GJRNyWd6DoK5eGhjzYATmCyZylZfMbZJihz8Y1VuOQxR3rvs0xdhYTwgOw+pQajpYRnXV9ihqgcH0+9mdv/nZ6I" ..
	"YMymuqsgh/Hqh3FTvcRfVN05FW2cyyze/79qojGcSekvzBPWETw5wrn/OgM8RBb3t5+hPRI1VWdgGF+J/zL1zxKSlVWeXzA6MRSX" ..
	"JNgtQcRbdkZqqw8fJSgNNBUVCS4CUyxpGVbrgyQA5+rLuiXnk9IqD0Fj7RV9xj2dTU53nM3FGOdm0JRbEBHD7souUyK3FhM9v2PQ" ..
	"M5HVYbALxF5umv1chwZjQp910H6/027o8t47T9v5YCyOpQ4jygz2xxx1QPyNmcD26jmnAASgFwrDSRZ9/4ydHFmSKHyNM2WwghiY" ..
	"DJ4IL02AK3UXNAvJQofM/YK+o+53cejSjIJ8gxylfXnNUEzkvmqpeLVsCv14p98UvTCrvgbTXX4V3i31fNniGk1/jt0afl+Zg2M5" ..
	"WcbZOKPWXBSelXUlwXMVjNRqg4/GhJYFUL9kXsGaETo8ZJ0kfLm649ii2woXU1Qnu7ZoRnVXtS0HvUqjBFrYXrpHnt3woL2Dibm+" ..
	"SPX3lrdoz+6Vy5S1yZomfijTn/UNMnQrJYmZixWLX23e0s+OT1Oiv3zMhh21Z9G3YgOuNJUrm3dGV/7LeaIe5qPYvmPgFmF6zhcQ" ..
	"nw4Kkib1isR0nYCgaR7+xf/NBHjEUQ5qtpgIu/x0MJOQmjKK6k4DHYHyt5lvysYHP/IGmkl+i/Vuv4GNc3owU4JAZPrtymzwRAI0" ..
	"s4/fbZD2tkyWGi794S2QpghlQTrXGoYss2//siXol3vzUqlJwZbeHAZjNRZ09tz2kEM4X05HmmZ9ssA7BKuTJnvcmrQu23C/2zJP" ..
	"e02KphRVKRZA8k71NqcZr5r8PCeVKqcKPOtRemwakOpduI+oWYvgQiVHS4JUc+pZC0U0QC7TESiY/NNc07uLWqTYXHM4KQxLZanO" ..
	"Ca+LODSVPLjJ2y+sx58Fi0I+bU3PgemgjqwSwIu42vcVFeHJYOoHRZtd4ZNKxL2I6btWo1I85kS+BQFjOPQiNWfl4QLeLhVm9s/P" ..
	"rhr9K2/05Y6FXSIYizjscEoz6j8OXqblVIk5CbTJaNsY2h0TDekvd/40KWHJZGhZip2tteD7uZEufx2YR7iVUY35LOfamPleN9aW" ..
	"8S56FZKG0hjpImIQRzp1zNUVxF00bro1yYdKANANzfMfCeeG12JjmluVHGOxskBdOAzNpQ3EDnZ7CFlgq4/vBi8ngIL5hQQEGt1j" ..
	"993CdgroAm6M/uP7wfJAwPU7yD7haZIbO5sm96GvBTK+qkXcqca/cyd3U28MIWEfhc8WLM01QydV1kkzMaC8QyC2x5MM9tQO6jVM" ..
	"xqmc9sPVt1Rrym6kIBvAxwd0zHeWjeCh9vT6Fp3v5AFLbzlr/rJsIcuDhs7U6cIk4AVp/HMBJyKttKnG1b9ycJn4MsRXs9PbnUk/" ..
	"D3U4DIbp9TcFmq0W3im0+iXvXDbvWVsG9vurl3JTc2F3gyn9SEF7E9TEN2EZBTQRmcZCxdBLWS/4EDJmIu710XdllK4diXYr+wMg" ..
	"2J9YzOAS/+gvV8B98gA/RYZ4d/pdudQlOd8d11+07Q9Wj0NpIPy9FziHgqJirFk2RGYnrkwV/mSARtqsfMC13IQ7j7iCX0qwAkbi" ..
	""
local PAYLOAD_P10 =
	"MlEgmcYdK04Cl1Tp2gidt/AMGCGwEdokU6MRYMleKT9TTVnGt60tJDGCmSKIHhyqRd6VWGEACHav2WOa3IKmxhyJmW36hKM521A8" ..
	"IaE16LLLcb1j256fvpsmTZoA7mPYWZbFxT1Ma5sWZI+u6P5mlGotcpCbj9T51NGlcNa48W9KKfK2EglzWX/i5+jLOSHz3lsIeFuv" ..
	"xiEyygDSOEwU/IPb7MJdpOaE7szTUDN1vzMnY7/fsUiDWvH12eFqCp7Gt72XQi8jJi85D5lYzgFM6VJmvFnZm+K40dh10c3MKaml" ..
	"vMfFq4pxEgmajEAhjYrrMqocRG4vo1GZVgA3c/Ya0dcngO2CTF2qRCALFq+ncJWAWaWKPp996yi0q9IPVg3l/nP6v/l6wY0B8PJh" ..
	"4mKpAwAktAp1Wolk379+Y7ukF9udDH1BCFt95ujJAbyMQMfB7B42R1H5kAvnt7rl+gAFXujgzfU8XYOw8waj8xpVZ9dFmee5FvB6" ..
	"tS13Gxtuco5y39SntMnTL2TxGJJY1rS0CxrQCTR8Qxdj+gp0Sn94l/eCMJZyQ998LYUMWi86gmRGf9KU144umt7iCZD6NVfSS9Er" ..
	"0XF/ztG2Sx054qCECwkxqaa5eGIHF7nINHVT4vDf8eEiSqorCe4h/CTTmT2OauWT2WNXuyzNqCAuyIjti+hc/rv3/CPXK18/rAwx" ..
	"FGIX5/nu0QaUVg7fuLDvw28jtqUaip+4Di2QhZkAH1VBkmEWpPjOUeZ3na9zCVVQZPQxthVk02JhtMg4oonLBaNkpSP0Nu9CujNF" ..
	"LR4SJrbbVIKj/C1wZTb+ceIOu1GceePuPBy1yqs+GV85+9WcQBsdIoA/5d9K9saP7HE0SslBi18+d8KBAqD7q9EQMczA+EPuY5gD" ..
	"gWg+QRb0XjqL2mnslyi74jmcdauESpYmwPc0Yne+jmLcPwsqJXW1rxrj+KA9WguW5+lJU5inxwC3cRNrnX3lm4r8WFYEX85UvpxA" ..
	"2M4t0Qy/HHgNDt8AFKfFV40e4vQpvvYUDMoYFva3qACerjRaopdpOqMs8619s4tpuq+A/qqhpRjCMpULb1qV/toIdmZfOAFFpgAm" ..
	"5gUJFWMLV8Y0kbhZjOS5HXK8HFoGb8fXvub+iRchJdBOxaFtS34D4Jf9vi/TeO/KkeBPprmGb8AFFiQ7FI9ktYALAmlKPr27wE7h" ..
	"1avPIA1o9qJT2Z/iIx6K/tlyVPxJfHY4JECtiYN3aUoeCHXDXHdYkDvgrIYo0rcXUGOvsVfoycnduGCw3UQGX9slxKf0roc6EWIo" ..
	"finwGxJ3twyXIu0KVq2G3Zr0jwRu5T5hKDmfJ/cFglsMhvzdUFM6pOiJCG3k+e8brRwG0G5DPIBde74Lh2Zf+YR0vR2ve4qu6S8i" ..
	"dkQgVakmxn+g21nKXix/IEAOsabdf88DkdiTgiFsmGD9Sf/5a9lQw9Rn107+OSCKcJyQFIMM0aGJRANE2YBl0poZHXXH8vl3fETh" ..
	"TqhwDf50+Dg0TutBmUeRj1nky1SQpfGyOvIP8Vpr2piQxs6c0PEmXVLaqQ1A7FNHxxCU3ZnACsnd+jyjsodZzyKYQe6cejW+nIvE" ..
	"0RRKkFJkPdv4KFBzQWTi4S0d2yKZc+OiuvfPPZbVLNqY2WgzuslaBSHS3rwT4zYtdFEOoencD805nemg3Ar24aiy8Ab9uF9K8QWo" ..
	"YO+65kv1ztBR50IlGJtgRWom7ZKlxqDR5Ol4nKxNAlUxywpAdJCcO89Uw7wCTnXAcL4nhAK2QG3pJ+h2QSOCa4zK5YgZ8YbTwXq6" ..
	"NX+ZdS+WXXpb2STxpYmMogwOpS1vd0GrJWtXTAQ7lKW5R89iHOFUYwryI+uXuOCckipTvWFgbldJBk5LRdCszogVHMCKuQAIH9QQ" ..
	"RPxvwn7qqbrUaOoJyNiBFmQ/kfMd4ykvXuxq01rquDpCRxaHtCI6ntFBPfDhnJ2zmIZZmkrrdR9hTTHIenZbMWab6uTg1yhvLdp0" ..
	"5kuCLj/70HsQY65ER/Zwdol1MVfY2ZccfX3/DyYZcd8yr99RJxfik2UXSvO4kXDJAxzgv93Dg2nnG3mdWNn955KdZDkZSr9OdHKb" ..
	"G+8bGaIAMKUIiGTXogAUBXvABDof4L+QWAd74kd70NXb65tosQHYCKQm9T17Mg18KLJ6HQmimV7+6ODN/z5R9gfADm0NrW7V4lE1" ..
	"0axdc7exQyrzCmQBA4pBPGqZ37o+TzKzAzEORLK0XWT+ZbMh3Q5TxSJiVIqPCLCDBTAPbNHxjVF8CoKHA5vcawL2uzAI4xkbj7en" ..
	"aEmhZw8oQqmXqD7F6fG1eo/m4rX/T0IUl8QCqvWGFracp5iSp//HzNMP0lNwAKNEQ9rZxrXyfbGl4Vu5A41ZZhNe0heT0ZB0H3hr" ..
	"BG7GSCaeFp98uV7sVZ7DR95+RKRLPr5hB59Kx53C0lqZ15qu2sOupzNSokCiCiKmyQQrHEYvPKCkMTMEte8l1vs8YXXzvu9+L4i3" ..
	"NYeQmMEpdkeBTQmBW5r17FXZMTVoie70T1nm40QMFExFM+yr1t0AE1XWWOXnLDG1paHnT8T5vCMnKR4aHObOsxwRnaCES8raJ0KM" ..
	"m8cVlvMGBg3nzTwStA4+V7MlZnkp2u4qPAs2oeUllLYAy6qOM1FAWKEt8LIgnO/zycP+Ha1GQa6EjhrM/q4dNJVHoU8vPkF6I8m/" ..
	"jE62oMSbXUWDCZ9jD5sqNftY1RgdNdqP+65QPsaX5FgSONrlHLaMUQoKmCmWjPXxhNK3nK5ZRUMvOdZOo9sgNI0YguQm9vwqnp6M" ..
	"D+LY+pNGkI1y2Yj/KrVs8UwvC+OUghwSvExM39j3aDIXgq32HzQXUNh7RyJODFXR/HYO06oYAA9lK+oJdSTBF4WvqRu49+lkQYqA" ..
	"FhqyKV8QbMQ5ZZ0h13XuE712ZxH44TKoPrGy+CCiKSuIm7B/GKbHS3kktPmOG/uhlSnT9QRnx2rHYm6ZijPm4BWF1TOWB7KuGTl+" ..
	"aXU/yTPWXKvpxNngqohy5b4jLAVcbkO0QpyHoKWN3SI1BgFsNakTz54wuxHlU/LkFoHfo9DAwSoMDobHbwb54L8cDmXOTW6tTY/K" ..
	"R2s3E7kYorfsQJckmCrvE6rF5ZIXx1tn4uGg0fxfP/IRdfDZ6YHTN637WtYQys6RimjxTaD59c/Kpl/ODOjUBJFtNzFHBF+j2AFs" ..
	"LDuPnB4EX+Ctf8WdQiOPJcFRnbLnkIV3sUVZtjkXE0i+RV5hOHgLegf4iOVSJ7HjUpsFhFIWNkFZopD/5WTpkH2Huhyt0R4xcXbX" ..
	"vuyWjeaQETL8sx06Q2IUF9vmkYyJfkrnDTuyKkZMvk4B3Kl6X5evLHHutQFjfm+Qqk5r1X0NipjPIvrMgKUOkkZzpTTpRXh0QxEw" ..
	"VBdb6ZXevJIlzXkVRKPAy+xZFbdJol8lQT28M5PBaalj5uupXRFCZ2OboHHmFPpU7zldd8sGTyYXpN8C4dhfcdk/qCxDR2p11jmf" ..
	"eSiidKvKjqIn6x3XYEPCh0OTkP8LlW96EJMIKEbLY0JmhbA9htslqn8B5lVtnyttnzeN2E9OYY8U6YqQqZlPjVogdgLOohCPREJm" ..
	"sqG1Im7Xv712I+Rb91IqcMl+EKVo6nKr3PvBIva/IagRbdtsDUiBm9vMB93DCIQtZq/PgJ+dR7tjZif1+LrEpQ3PEMAQ1jMutIVl" ..
	"3xsfJa/OmsqTL2k7NWWaqqEnhkupq6T/K52tdFwdEkquqSGPB47Ab2dUYAepqUq5NXYqcc7XWYId/hFuy1L5mvkqsOV6RMc9k25S" ..
	"SbYknzm/PsWcsviTisI0m75MDIWOxzoULELkfpu/0QjEeUezXtr+D6V+jScEp03A+tqeR4QwTajMNnOAcsUr+Z3eU5i0hta8FLfi" ..
	"2WdylG6JNHG10SrNlXwIZt4qEx3zLEw2E3T9AaAB5/XmWUkiJrGPj5Dkq62n0EmboPMBi0PY2mcjpRu+GkfcN9nSXn34QqlB8qUS" ..
	"ARaHIqCRqB8i8yrPfjIE2qsjzXDOB3cV+t3f1vYP5GbaJVhjLFCNXitoMqrzU6JuvPzY08m/e17kF/x9lJVpW1zEB2p/IT+WjIGj" ..
	"GSqpij8tP0avKN7DHUetxekYJf8nYFAxvA74e9ZMZ9akK6gemIC7BX0HOsSrifThrIOpMV0dl72pQLl4/Hqb1xRVEERUrzAHV+Ca" ..
	"fKrSc/KT46J0uPN4qXdH7i69p52AElag8sIBZNScUyLn7qvqg2KiX/eKe062Q9B99r6U5grwMsTlWJVS1pfeoOT0tjEJ8W33ILMK" ..
	"AxqKh/636tZ7YM9MQPdqyxMNcgYwihlOcwDEkU5EZHkxI9xSuKMroGmcH1C3Xpj1SsnTVs9f5px8ARfej2zCAnTPfr9acO8ZbWu/" ..
	"HF1JxTYpYsD9lQeBrj9KXVAZbT+KOdZtw9g+3cjPiQZhCGWqXnbcTUtA8QCKQ+twhTLMjUsvMdVWipyYoIcnsNpy6UuGac4gHPMO" ..
	"V/PWZ8gBzUDxWchOmLUBKwXNV/cXi1cNenpuPGjqJk69+Gqq+AYHDFWlh5VyYNyB80yQv6wnTZVF7Ru0/5SluDxyeBo0RHxQ1Yp/" ..
	"2emCLxCE1CqrNPYlSHJ/T796UzLXMRTUBRty0VbOkPB17tiAtWQRI2X95cIQshLWFcmWmGSQ43wx01gOoQr8MbwjiW3OlQlvco/J" ..
	"Im/rUeHQ0GlV6IwpeGgfImA49jO7A7TRMidiioxnyhqhrZnJ5UGaN1VFGRBplgLtAdx6IqGx3DThCDd+fnl+IXjuXsH1EkgIQaEc" ..
	"EkgL6FpIOInPwMqrPDfWolzhmtcbIvbyD+uBHKQ9gWbtVAVmVB6EFetooBtRmbxIjUBKkTAtwPwCS0yqAdUY5f1s5+mpNPC8rzIa" ..
	"kuYF6gKyhQWzXBLG6RJJ8YEljWN62E209J+OZVvDKO/R9bEac0g6C84MtQQgp3QzjW+5zPPgE22rsOxnTIx0+p5a+3tw30C6eDFy" ..
	"HcjXE5L7jTB37lQJYMsLPaQgX2SHEtRsqFy/L0VWsX1ZTdQwvPqfTxav2Hs99NVnUiaeLSzRRAF4EqniSRVu5p7yFo55kYBp1YzH" ..
	"VIaRu+5L1zehk76SMWWE6URrDaosu7+6RcxN4gbKL/sNcMT0X+yKi5ufZDJk2DKpDgzz5HbYMk55OZMyf7TbenLvOy58yBUTnD3q" ..
	"5CkwFrrXOLRsQFkn/QXcVByGwWc2NvlxAn4sm4DLxbA8qnlsk7toASzn1sWVE+08SlatBLPHXytmrmzv+OQwzc/7o96FhJwWkeQJ" ..
	"nCoHyuG89VJRA/j74DokzYNvOWh30NQDOlM7Aei4zwJkxgEZWPxTGexu1hS/evS7n4tnEeIgn74bNnE/jlWNDyUBB6OGu1rJaxBj" ..
	"HmXu32Qx2TUmJAvNV8HWlZe36MsKdBxaQ+tBLhkjdCRSJ9biDBKEltguurXX+qvgaF4Cb7m1Ttw1mtXmA0pGE+ykBtaSXuBDaHOZ" ..
	"/RNBUj9mbk1/LwPSs1L4AgURhvtbHNCn8fw/h3BivmJBtEHVZaK0J+CcwaWliCs6AHayX+XaNyeGWiNnYsgRneXbEfzuRImTORcE" ..
	"r4U0KNh3ygIz28Q45XoC1i6olJGMW6rfO6Ro7U+jaj5wx5WUovDT9hwzlXXT80Ny/N0MVM9P+WhoNq7wRTByvrNgztcWX6cUXx4N" ..
	"iJxV0rnF5W1anKaqMPij/NwJAm30946B0j3KlfFgCbKTrD/KyAgqOmPmHEIcgBXaChpk1WWL5oIdelJ1nUxjobqvAYgM9IIimRXK" ..
	"vC6KXp7PXMQ2JZum8YjiT4yvRxoawa5ALDo4hw1kTn9gh1Fw6irUS0DR9GVbL2WrO9Ykxn9dGvRW/0gWxaosQI0CnJLUjGNr/OaQ" ..
	"9Qk3ZiWhwCTbZvnHJ4jznB/Q9AiU5+xxLOSmUen+uBQnLSXWEYluBF4UhBjRV8faoH3SzuprbxmAd/KxcchYeb8bldUiNAwYJGh5" ..
	""
local PAYLOAD_P11 =
	"WxJAGkHOBPAjkzYeFLzao19NE1WG8pGZZ9UaJ3hjhhDC4kf5khD1nCh3GhFFwWjrSc44i0Ei0dDD6ClK6h6C0sWfArzkypAZj9lZ" ..
	"RS08KcdZUq1131PZLJDWt1fqXFSHV8mJKeRDasCOIHWqFMbF8gg+neecgaklrWNBmUZZU/wCP5HXlhXvHGNjYKJ2LoJw7KUlV03y" ..
	"NXnHZYVN6FyRFUhtgRyGfVX/Oj83zf25y5Q6c/Z6tw9ARkkWA9B4v5sDbDW49drUeIKFptY51CDGMIs9Zb5VNxZCtiyOrPycBJza" ..
	"ZmYsOKsLKmUAfL43/eP5jkg/8d36BFmPJhPVluhx40f+q+YGdNZSIey4j57pHtuUPKK2fXCHUlkoaTPMelTh5IWD9KGV6ig3D+8R" ..
	"tgUbAjqGquIyO3bVCCmLLt/c/eXIfwfe32sFX+ESFeuulmnGWdwNAG8k6FY09kVoygZPK4hxEUEh6fQUnAZUqTZ0bX/ddfn8yxmb" ..
	"93LWx4tLYYUwptPlDalzbuFa2uAwbPeYvNnmSkXeIN0TbEh42LAMi7V4oNcAcOudI6fMdtpjLVxyvahbLRm5uJnnd7YZdHfz4V46" ..
	"HRUVR+zVi/YA51qjUfw+3NP2/24Vlv3FOvk+h/aF9apVUkEW9IJYHbhboKBMfDTJy7tewfBCOWLKhZn54IM3r1GoaarfynTQPub/" ..
	"TL8t4zCuAdZ565ss/MJxyo9RrhU1FOaILEYEZYHIN76qY2ASK6Et9VNsXPPun9fmRPF/3y6M9EBNsuTBZmpGkHinVHoga61VgcGH" ..
	"NT6rLp24zObTwUkB618vGqFTuzipwuQz1Ye30aZqpn2x9UfrwvPDwFNE4e+UlvTKhDkKBAW1YRqG6PIVo9IaIiXiMLZKh92URmEI" ..
	"CDRBKMDpXRsgUXvA9SIZ/eR+18hKAZWp128ck6TaS16P1pr9FmLh3pr3Vwd7s+b2rLwe940uiCdG2oe6v78gyBLg2c9/Bhki2w33" ..
	"rrVSe+ro04ENHDofjjulcVWXScjI179NgybLfsfA+AStRKEfmPEzAGfqmNAdL3f/jzgY7nCJ4nWyi7PIi0DLn/p9RTf+pyhG1eOe" ..
	"uFz4hBam14sZZtbwVg230vYj2hVJeMEy79pDKIwAh83rCB1PqUYqLmWo+3dL8HSXX+4i0N9mKbLnPg7Hi0sH3HAMd5oKRpkEQxQs" ..
	"JVbpuJA8pHjCgJAXG9OCUnDI9gAolzZfsKO9QKf5JKkU4H1uhAPGX44lfSYxWOCsEfbKLgZTcZysfidkBx1d8Z/sjypuqnakWBYJ" ..
	"s1U3UZ5TMSlagfkzdBUKv2MESD7ACONlTNpjY/OOVvNCEAumBofMzQZVrbRHyP6Z/WQm+2c8yc6x5riNDtOlCi48/3280fBJrd0c" ..
	"x2oFKhrQJZ7nlmp+79EvXlRQsedZ6FnBy7EJfQHPesLVIhwVhrv59hrrj1M6Jju0Ww+Oa5IUQJX5O8QBg248ezCbPJeR7HtK2eHe" ..
	"ieJtnNkmyQnJQb6di0amSp6zUe/ODgfiydHDI7YCLtwGmuhAVzb62PJ72LFt1tm7nQBHOS5bTYyD/xg5GPsz+dGVyUujyvaS2jtK" ..
	"th68mer3kLgrHT8433YVUnlGL645JNIE2hoXgtxVWjmvks5RQGld/dyjKUgKjysRl1u7FHNAi9uKGETaVBduQefP8Kr3w5MRFqqc" ..
	"pC0o8we+k/fKnycy0iYUztaXjpLjL2iaEu2F0WGcOEgydxvBTVFO8IaLr7/ien2ytABBLrZ6ha/dTPMGAjZ5pJhlPKNXPHXZRvFA" ..
	"oQuViB5L0EyN9IGrRoLtifsze0kmp6U+zTACG24efkQRwwGAuGlsjvmGpfAKzrdPq1uhZDL1xWPoRBO5wuXpqWb1xRKAVb4HDM5n" ..
	"gJsdJc2sU3H0cy1F0IwbYrujfSecKTicA2EedRiMBUGLoLco3qO9PRd5TjYmBVKfz4KLnKQiAMhxgXU9nT9kZv4qdG/rlNCARCo4" ..
	"4WKURZMkCIpAOJ/5FZLQVQNRF3Z7g8zKo3uYm0pH2/Jn5HAdRMHFTGqnkf3ZLGIcN2ybiHoEW+3TunbN1cQGzqhd/ltaPjI2gTLW" ..
	"61ngftmqS5OyknZk9+XF7fHAY/fVJiFuVr7STD5GYywVOJKsM3hrmG9UNDUVjlHGrrXQtUkUnuPZVESD0ljv1fmOeHDe5QM56FkY" ..
	"mcK9EWyW2vfCkTjBhPKiE+994JjF6VSwhDjKOgsut6KKk/WAvYBKq08iaQMnmMPZT3UmKPXjA4WaDgqLaG1dGzWpUoFM6/AVfvyn" ..
	"C0Hxj5wm3RoApwmGjlUfPGVnMHUPGu/F43E5ORvIA4MqtyyA+uG3ezI3ct0Fm5uF9GBtN3G3jRc8fAfoHNVDluJY6/1pptZL3oWG" ..
	"GNq2GcgBYB9273czHHhD2fM0+lR42inhNFhYwvhtjqnzOsm9VQfoRZzqmKUZ1wS3eEsK/Mya9YouLdEatFZ478t+RwcZjudr59wb" ..
	"f8DFQOBxFfeTEjExQmCUh02lAVtv8tZebj28OzTOmiexhUmPmd9NkCz5lINIkHXQJM7czHzdNN1GFnvS7qqi8+3JsCaEaVihrvZc" ..
	"Zspbummm5Iv6GKZJjJ5Hv7E4oP4XRY6w1eA/lX8qkZ1tz6g425t1Sudre417Mg27CqNSxmnHMzJeJcvd0eNtE4CnLY0gserOXx9P" ..
	"QJ+1nwa+Q/orKVVZyLtaDTRbr+xP4lBHs/MM6DCNpSP01i3hcCs8QMC1SgVCCjuuU4SX+TJMTaLFAQ9CDK0vg76BmTF+SB9UavF/" ..
	"+e4rDhWhcvNPSAzwZl2epiYOhuGgwqDa2CI794Hz1t/fFizypqyyvYCSpF6kn3KWlK8am45vJJokn8oAYjKrrhCL0IQ3XuL5zBf7" ..
	"fKMr67P9vnALnE8zd1emzyglIGmX5edGovJvnzGdpmDxRBa2KwT60p4tpK6bZYzPYtkPc1wNnOXujbaO3E+4soFZ6xG3kDakmtzl" ..
	"Y2fIcHXMSDHnfYvIOyGyuwd18wA3VVBoq4TIk6+ckbu9o4BqDhP5wuULcBFk1J39v7zYvmLxZ2Et1StrkYUaSTWKcp/tsE47EAuL" ..
	"WyMs6UExb7hp2iBJ72S1Bnd3KUldp31mRqjiqYWNfxLgN+h3C5affmrzGsAlHqEA0t9H9GIpeS2vfPdx5kLE5XBUyNMVRd0XCt9C" ..
	"QYiFrHvPJ5kfgTLsui3pFpDLFqUBsHOo856lZkJKRIPZ3rDk43YDbIgsmwZl5NGj3WSjBw6zdxJokLm5NceBNaN6apo208Q1fgtG" ..
	"6K8ncUe7+XjImJVucDfvu/p/5puwBS5lgvAYveq0EJl7k3t1wWFPuRXI8IzhvBHWrh5MfmG/ndJD2fSlRMMC8aTzlYqsie9aFHle" ..
	"MULXh3+h24t4KeE42qrOzERL2IftXAyVbO0iWT14GVFmNgapTiMr+oT69zsnKFYxDxbuXI/HCnuMZJYyySZj/1LA+l8liTLk+eYy" ..
	"JaZFpHgJBPQIxlR3OMRLsBEkt+QUVyPu7T+UCbtpPqce9WT3yXh5ntnTQfo+s5n6XeAYEZSa63kZcBBMYOm/Q216Zj1zQI8p9wZk" ..
	"w5ODmi1TMKRwOxDGodXjkJ2pXTR4/C9kQMMVhrd/WgTNfWG1pkNqQNVy9X8OUcPpD4YuzMHvO9gj1WuQG8oy1gbLeJ+Anre2QiRZ" ..
	"qkx5HwAHGJnLWArxVYlUdbmhpkmw/56CH1Bp1uEVJwgb4+GRPFY6in4BmqCwzg5Kpj7TUSGIpjpCLgMvHpWG6UmupZzodhrPWJ3e" ..
	"W6pl46lYWrpI9cVxaVJF6poTUVtca+SyPRLWWBD5g2o/M/51c/jAIDg+G96ZlaYgi99MjY5R9A65roM07edfgKEnup6onFWgjWP2" ..
	"y9uSO2ZdcxgQOrb10l3Z70YlJv2pK3B15YAzggSLTTmQ0xY/ig37hdPjp0NeV+wKgeTsDR37mMv85BgUjxgPLH9tpmRwvOGLJtyK" ..
	"dRnhjL6CC5XM47qChiXVfsigJxoaPXIf6GOLxTbg/ji2Hp2NWJ/Q4F7HcR8INX4Bt2YRFE4DCRAoQl8RxngZd8Da/46zlteHD0WD" ..
	"EkbLreDtOQwakkxNr1zMNHRxI/uV9F/yESzSmdfEVoA+5nvYl7QzSOsa/kRQmwJP0rxiPGyOgs7EZq3cP3UIVVAPEPTojQ84r6zW" ..
	"IHQaWblAInOZsf44t77N4SkTjVkWuM6aHLIKStafDODwtA0lVT3zoclBuYrNSL7RZGTQBAGMunVwLnjvya8IcX7pPG5zwN+sW/Vw" ..
	"mjR1RyOYDlTEovB057Q4Jn1jepkXhwdxglkInBHpAiAfy4gD3vR4LJM7o/Hq4rtiHvvOUHLejCZRpej/5k/TTDPnJ7TuY4TWat6U" ..
	"JaguLOI/6oIb0vdkL9IUoMgVHorikLKHef/cLc7s/PRxkmHeXmfHTDe7f78V3Mwd1/Pt8kn62Ikf5B3JJw8g9akL8KO8TcYSYn63" ..
	"476GRo7aTnT/vBfHfb7cLJlZTHLoylhY18Fos0T5lc+8P1ZC12qcQ9W6iL0OuYhg+x+cdIdJHb3Owgb9CPMl4WAMgZDSHjBVQJsa" ..
	"sfO/15q2yKBgLLouTuFaIxtJQ3u9diYtHj0WjLYjNr5o45BYsw2VVzv5uezMPZW6UyprhOaaVo0iuRtJr4hMBIMF5yS1LQpweS8r" ..
	"U+E4dNUhOA5R4qiDLTQj2wgcMx+yvORFNu93SUomURnqUI1IQ6crwLzK5Lv4Yp/kFcn6KBdn4On9Z2ketdQ+eNYUsqsgD2RG42mE" ..
	"JQMWF55M3mJB+oZtkkV/H6ahiuVi4R0e5ZEhK2cRXfwksgUprZ6MfC+dYI/47ncGAbEJdMYSlO6p8Sf9NXZp0QvGjbwA/KLx8n9N" ..
	"zUFHIVHykKu6+Ycj56EGuMiuc8ZuSKPkyM6cqNF+42cydGJyg+9yx3huBM19EA5MIpeMDLh/Puwb4VZ4aoPOMuHkEgJp6tFeQnez" ..
	"+6nUq72GSIlGIbyeBukO77JBgKq1WPI7P0A9IBlMCX1ZtmF80xvwNKZh/Sk3A1HAJlhgyaVfeYaZLThPPU3MnlXfPfzPUe7LYIsG" ..
	"Qut2tjaygn9NtbrWk2Ab5/tjqOWMWFAQn9755zgaaYBVHewkBMnkPJhL9yObN8ZxcybCVm90Woxm+1xlJwYEuPA+h9M7XjvJPBDK" ..
	"pG6JGds8pFPqtdhQF3qKlIZVdM6QUxcnRePKeB9aKSCrwKtCBuPYxXCGDybcB88LhJ+81pr9uP6E8aWIxldT2thOH+zVv57HEKPJ" ..
	"xPNlydeXpqr8mRyoYcmDUhMA0Rkaiz9ENupLfuDbgE0BWL4d23nQ1/S2D/xTDDL2J4kepWXzaLrblmyWyfgd4jRA8Ll866kO+a60" ..
	"fkbyEzjZmoKslPMqtuZ4O8SpH6jl6QFoZqb6Kl+ThzANe6Cl3cAtOJdwaBKDNXxE7Wakfrj0xGB2dFH6h+3Q0pvjaWd72Gjw1I8l" ..
	"+Am2cyqJW+UqLQqwVnDPy+iRFZxl+dKYn4ZIrProWgD/aIlOoh2iBUIvlb54Y3KS78cX8GAblmPnglEHTNVrJTUk0v4u4gdxlXzR" ..
	"V5bVqsMqUNOq9Ycd1yqJZO54SdKvTXl/JpRTr3iruXsyGZw6R15qEPZ6mQ0wHTHgFOWKDQZtJ/pMRjLITXEnmqTWfs+7nI2eLUih" ..
	"0scC2J6DHL7lADY9gWYDPgEMes4wcqUAB6mWXl86e1UYNpa9NoifNViDFVcJznUZwoq0x1KDiu/2uF+fzNTYWW/ztjA8WwY76BBt" ..
	"intT6kIi0lIepjM9UDqaxfLDb1QwsnOcd7ObdFT64IKI3VOPvzvyybpi7O3tZcoHARXU5blSm7tTkjAszeYbg5MDYWUyct7QqtRI" ..
	"wA+5bjSjXmjlDc/+1mIPsD8gn7I4PxVl34S9dpfJXobr07Dtpci+BkTCt0rrtHkVXC6Jxv2s02WH1+V4GZByRzzlhkU9RD6PhfM6" ..
	""
local PAYLOAD_P12 =
	"IOwQYTTOAcY5PjKjY+4Zg5P4QKfXxEt4irqtptlMxyTua0fP904IPccvwRwj2FbEvnHlVH1PJl0AHF2FlTgjT7RfuMkBcCQB2R4L" ..
	"Udn/UWDBgXLTl7ZR8mwHh0e8ZOIHpSsNBS8HusGELWgd1ZUk0UKs/42YlfHl/G4BuiGzCg5pxfxb3bNKcmNFHP4/J5nJv9d7sB7Z" ..
	"DjGojLx3mDfKgKjQFruwsZte0cTHPX4yLyEAb49NOTKxBywZp1OG6I07VmshUGyWGfe4fg4gNfhDftwo01Chy6PTmY6uCw3Awwm1" ..
	"E20DjaxcWzxfw0hfHUA8KPqMmWUsU529DTkF6NSgVleEy15VM0ZTGR8FEFbKrKqJ2qoCDY+YKR/b2J2Rb1G42jvnQ9QJ2l3hxqoa" ..
	"FM74+UeZr2XUvsyTbaD7iKzstob8YM/jGx4q1FaItppDaaTvUfGCHpv9+23atNfkk//FljLBA3pb4NJ5Eo9iwAdfFDE66GebVKRi" ..
	"yVn19o8gO/AH5PP/WJuKuT2ptwQNPiFqP/2wrDOJU9fOwo9O4TfbVdoTVUej7H1hExhKUrL9UDux4oR8IYzersmZ5U46KzP7+ynC" ..
	"xSEclr1rB0fE7gpdOjfCaaqTgGv/F/EIDX5OvbS3C78TbJQplxq7xIKTuc8f3UrBwoysJqKLyxhp79zuesru/4V7CT7z5LpUl5Os" ..
	"2Q1gdkKvq17jnFpfWbHI/OyGq4bSMwIzKO75IdZ9/MsBNlqPSgbbnoxZjddV0NzMlapx2xQ9Z6uxXc3N9ZgtYE53QZ+QBH6BCT/6" ..
	"bG/X1eGqsimssAaI463Ey/pkF0GKh0th7c6DRDBcb4uw1tNAjquaZoiPFx05NkiwngFx7utwg3kGmWn1xqjtHbxrMY6AlZdQY1Ju" ..
	"2NMGYzIwuVuaJIZIl1BIH/Kuw0WcT2QQ745l4DLNIYe9sGTHNJ3eJb4hTJmGQd2F/TEwFRHmtw/U17IRl59mpc58z6jljlUxyecK" ..
	"DFRo5sWn3A6GBl1NVZsj5G5b3jBlMXIO5fAEpT0++QieEH/XgNxh4Xqd5uSCNGs61p7zVkNwOxR9lwy7Pojqq7N0+MFCLQRMOtDf" ..
	"78f04rtnyGISArNeGUBNCfHjhPoKG88K48JbQxb4Q+fPOunGuxLVAmX88IBH/+BW1esChrP2FSAV8nc5g5b2iTmT36U+gHX2gntq" ..
	"VcPMJzdChmUUzvHhfr2EM8qkf5hV5P9yr8vJaxw0MuJkNcDi8OSt+4bDcvKGz2WXGjg9HBOlDEOZAW/JyYbFWXzaCf8tuwkDG8z/" ..
	"EwblOvJLfbjgNC1lCAF/C2z2E95kW5uwgE1pu03a+1s1rDV6kw+eT2zP87pA3NTFVTf8QJEaxgUrJNEMrXeRH2QuzRmT/XlNHV2Y" ..
	"1bmiOEivXYoLR6VGZtbPXKDdM2ITYWFNMdEZ7ZLfaFzmPbvxk/xZNnPSVJurxyasGnXgi5J+8xEzz+BaPFMPvR2dzhlMpawS1XKb" ..
	"5cgtR60DpGe5C/gVfY64o2kmqWvOlMBubeUPuHuubH2U5QwVgEIf/nR5MT1d86kEXhUFKLYOuQTUXPyuAhT64rk4b8NchwoQKUVr" ..
	"5vMf/QbZuNj3KZ5zbUILVRqCxDXaDxez9oBLX7tk8vvCiCdZi+6zOK+qeIjnxkrkPdi+iNPs1W8TZ69ANSpzHJfo0M1MZQo3ARie" ..
	"83U7tw1P9WqxMrTp9ddZrvunXRng+Lr0fWTTzDKE3C0tex7Pz5ReS/wMhUECPTofDydQz2j7sM8ZVaXDI3mo9Ew3gDhKplITxj79" ..
	"3fhiy93ozBcVc9MGIgeSLwl+IZo2Wz5lgtUIHvs/UE5q46QEu7KPuK88uxCOUj855y99A9vFFvl6FVyEkus3aIRFSxoX1CK6rmSf" ..
	"ZPfgs71GpWpZhYHWwS8XBRfZ5sE1PkNbW43bpcXogFCATVb3w3CXHk7r+ja5jB2sJh9s86jrA2E6ePXPQ6EtvPC8xdnDzMwcyd61" ..
	"+lHkp0ccdKCMyVzaC3yqU6FeEzlki2kA5LjUW2yoyEVfvdlM5acuaIGawfjBjE+R3UdcQxwAQtxM+v5lyJYeAhUi0f+z9K6mKTnz" ..
	"w4in8olVhN2vpM8Hs38EiEnw3l7zMaLq65mj66ZgCNSE3TLrzE67m2EtMefMRtRpBE+GJuaiEthjRCP+wWlsAD/GagI5TkBTJF09" ..
	"4bSKpWLW+89d8xJMsCoFCW58C5tcelOe5LMT/zKHiBcMi7nhRsspYCtUBa63msc6DS7AiVH2VolLOMqakVve+Qh8uOm+bJbnqRvK" ..
	"waXmePjc2TDQL/SeF/NM8+kEh/8AzLY1NYnVmTF8ZMcGG5nOQGQO86FJEVGIY6YaQRN46+qNFVoimdGNBNjq1U875w61/hS9CW00" ..
	"Xc7Y4/ogpnVwXLZDozKEwHxD1LS1d64vbsaRUbpYhX8K+hD/L386HIew94SA3MpEpQXejO3NcPSRxDaqQwBXvg7n1h0hyYgX4NS8" ..
	"AB5/MBJ3hnGnIiu2d6n4KxwxWXj8MyCiL+Hrqe55WJvL4TMq0Ekhr7gBbvHoSqzgOs3iRzAiAMYBieN2u2Q14tsRKQRSv9sK1/uR" ..
	"+/ma3DWykxr/wB3Y0w8BL3xoH5+Y7PY6WoCZO4vO0o1rwN4aOIY0wEy/dDy9yEaWj06j7NsQORsEZsAdeJM4y9HmcBCmXkwnVv86" ..
	"/p7PyN8OfQGFXB1ts66nFrIG+5ZdqLnBQmMeNhPvjg6XMfUk1XPXdZIceOlOPrUkuP9D20TcaiWnQ2upzTXHulXbiusjDw6UwDPJ" ..
	"2biwVjhzS9xCWqNebF1SprrjYbMqNZh5QF91ciExyS4D3t4xoHOCq1RjGFJs0RXcKiBbSLY9k5HluiVn23HdaPv/ChZUzggfds8B" ..
	"wOsX/b7ig2lxszazfm9QbVDlLfuONozQ1dy/7M4JWz8jfQ+LCIGbcp4MgxANOAJZOg+KZlTHrsqtk7Vpj+XA0c9bWRCMcVQItKGy" ..
	"96CZwBXHjwUQLklMff8HDJeoDXoNagR8LQXzsZL2I563BONDoGWthYAUpV38Hqd9dsXgC3JfIGBqyYC/llOHybGIxqY+rd/MxtAe" ..
	"9COziJ/PQxhVetv+Pr9X/ukXXfJkXhsb8zsKGxH3KT/zC15h12pgkcS5wYE+7mOAG3N7BQGVSAI0pSrRUdN9A1kboleyalvAYx0H" ..
	"6p2QcKrpLtt/zTyszkRfDzGOHvornl4lwOMJVajF0IXrZLGW37BlnVPQ4G1TMhh/8bVC+DTG7J+y35pnbT8R0Oli7oBU1PLKwXMz" ..
	"7Trk1pG8iyKBvcplOe4WUV171TLUeRkx2zkwjJoK9/Klk+iskdA0cPtPach+X8Hw5BJhS+q4FABd6Uk5lbxDRuf4bu2bkgx25bkF" ..
	"FVPf4qxdTdteEO7X0u9XwiHB/GXNB7UEsu0w7zH9IGsrWYbhtMMzcKvLqp8eOFV6A/04toRS7DIAggAFk2Dn7QE//eGKdkGl2doN" ..
	"6CJk4weyrb6BBkcp/CS/+yMebPvVww//3K4O/1JIv5/hnPl6kJa1+LbRVov96fRjlM0ygqVD/TLc8a8VwS9QndkPbk54qVtJ2wZ6" ..
	"TG5Y5gfjuP6FBbfixawWDEf1PR1RMM2cZD1+lokIZ10wn52NV2Bq1iyanZTSFNXNWT0dVhXkE6woMjzbX6S44GOFcKKk0IbVTj6b" ..
	"CsZZLcJpIf//mhiKGSx0x3qtPrG193+RvPzezDLuwLRyIYFVR88SJYg5tDdF96Nv0ArV2jmlBoh4olSJDgzvTB/3ApDbqEv4ynIK" ..
	"JYm5RsqRLp/zJdtfZKyTtrQ2ufQhYIcHkbWZwXDN1KQXW4vUMtX4ety/2PJohYlbfDFjFFyOxI+KWMLfLO14wTG9Mk9RwkMCsU6M" ..
	"Lhy7jDkLMwjCNTTfhGzML/ZGNx5GJjxJPm0hoRx0YD+JuCpqe2QXUtn6YT8RxJxzKeiTSjSKeKmPsuLJ+LempD2Eawhskw/U1IOH" ..
	"xF4oAJCvxgoJDq90otNoihGqu8P0XAd4xV2C02wWYOHOj43kbs2CA+fLvMnh5mcMvh9wK2EgFBVgrWb4I+z2kOu5AojG7iBsLzfm" ..
	"LO8QymcQk0ERl69apFT8djx+q2T/owUdG7aH1nLDfBgW63BpE16jEZmQPCjNUxfaehtTJSO/QbJJue+92DsQ+geVygC29xvwHGI7" ..
	"CXmYtootb8K/GBbkTadyfhpXn3d5eAuTo2eBa0vKcK+QNjk3wkSWDBGO9/eAtwgiPBieCFMM7Tiz/TedvvhptQjiPenCS/Apz22t" ..
	"7ml+sapABPMBWDyJpeZp4juq6JgbHN87ni4r5UanHvWPvQUaPFU3yFbG2OP2yHn33JMMyu1UVgQMWhQeD2WIJHzJsDaw8bLj3LAk" ..
	"D9rv5qwWpIQjs1+bpNQLQZFzJ1fB0W0/FR1elc0GU/pWxffjtQmtZlGQTAnlSVngbovYvp4SDOVBqlpMTw5DpcvdmKrs4PKjqioT" ..
	"O1uwY6/mD535ubJ1LLXdWQY402sY6oGkQCRI2ZWGay/IWfJq/nth2vfhDOP0ICriT0Y0GE7albn7tZmBYcAp+df7rHfQyaUNB7xj" ..
	"qXFvmAs01wArFQXylt67Z4RLbiJVbP7blQZ/tse4Gj0UZDS6TyBMagX75ua7CPvfzxGIudscuCPYXFC1SgK51Db6t4PiEbwGqiau" ..
	"ew29Xu9M0bU4iJez8Vi+FQ2jqzRPC/XA+EIMbo2X9yPSZKvZfqd3J3/ViTbXlaxg7gK188kkopZRkChHpAtBm3ICWtnpsU3P7yxI" ..
	"VrDwZgreisKd0B+5PcgbeCXoyje8FnIhmkWT9G2CUXT8KfL60KfrqcMZh0PXfMEGMXjyU7DXXDoQAibuegwImBko/PVpbay1lwsw" ..
	"P+kW2pzBUovEjxS6NLBGz2Oib3L7mtSyw5+vowr9GDcosieo14HaQMJyqmNGxCQ9HtT/oon/6YI1kyre/h++hqJ5qajRxMwBQwmp" ..
	"Cp+/QNALAU0ZZJNLhwx915dtEyVdSYw9AysjtHxcHyw+/y4EK5Di34nYqccRY2R6UdXXmfs+fcNfJ8JXhf3Ky4DUYbeLPVACge8n" ..
	"GuhgZyQwjYzcoRkdEbLFNnt+LON0Bh4hosw0Hh3xDzcXqG17Z2T8emifLCxy08rocL7SRbFiua62wmT9CCVNyv2wbu8iQIPcdyVT" ..
	"36on5ZCfRiBGNywzvTFoJ0Nhzhj/A3eCvuSYA36W1rDUjgMI9y5mszBBxYBVAnRkj5MGWnNzwZAek7E4EVPShD2U5vm7mYSnnteP" ..
	"RTe+t/Ue+mFZHm5fYfs3i7Tzz2NW10a/WjlOwCKLz5WBbdaVjefxdDt20aC7JXhBzdyALYnngRfCuxjNbVMoOXUzg2jFH8MKQvWw" ..
	"VR6WIVCBfaFiRSoWut1qVBAcum/+8MLhPB8OlPIL6fGkk9payFe6Dib7a/w6nssOUzQF634Oap423858p+EEDcQjZDjBUEFkFb80" ..
	"R9RlpM84Ly0AwwDh92y1FteSOI5GlL+y90XQdVRrI0Gjr8oTNPzow9gLuB3Gk9uw5ace10rtj/SErqu3Q1C5yOdJD3xJKe3FNmwG" ..
	"Y6ycK6/AALd1saOyWkSfu7CJoriXRucK3PVOLPcj79692OAGvnBWSI13GX2QXJbMd7+4+9HAraRJMIykv9H0xEykNrRoN4Hvs1Yf" ..
	"ta2RRmPxO10S9ogLb9lRSqQ4bYK6wfqx+rmcBlQikLi9oasVSApD6grKyHxyMWZBko16rK2/81IV7pMAJT+R1y4a3PeI7wllHL0h" ..
	"HmXeNcPsm6+ZRsHxfspbwpBlg3ijHhpHv6fJnLTDnWUpIM+nSHryY0lEFrmbibUXqTKtT3o2Yh1gGBKCMzqxKpxs6dgQGp/aNoTN" ..
	"s8encXBJbEeWhs56PlQSZ9tSaryCB7OGtwvd8V61j5RMcpfD4yDS8UagA+DkcRh+v91qnFr/IBWG4cKJR9GoOshUeTvusaaQ3mqb" ..
	""
local PAYLOAD_P13 =
	"1YJRSgmVX/jzL0UlL7pQ8K1dGoDEccNF7K6ogJfR2olVuc6isZxVpo6nxeMggPcuEV+a7LtWYAhwysWQ9aRlDrJa7igMgmJZpAsh" ..
	"4KtlebnhRURgGDZmMFudRBFJ69iZXCpqr42X/AC62O+4VTCq4LqLHJwa5bzm7yFkc+M7DvmQUGGDre7Yv0KtR6j5rHxFV133W6gr" ..
	"U/mFogY6DKrTxZuzndkNCi4OuAC8p8VOZLRY+5RY3iQxo1+0CCjryrO4x7RpHyJxlwMMaDOvgvyxi1vjRCHQVdQjBxV+3E3Zsutl" ..
	"fnsPPl2M+ZofGVjPiDX+r67+pOiRNT7Cn2ToYJC+AbrYNxAPV3yX+nqkJRMAbLxgO02/RQuZYukM51MgAAghohOwNQVT0Ge4hr4T" ..
	"LRFJTU9Xt0DeZz+5R/ANOh9FrdTTjyt8RqQr0Mp3L+bgMLHJ9G3d7XKzhXTC9n2FuRbFgwEyKZQ51SBtdzsznVosNtH72KEtQXu1" ..
	"cvOy3ul1DsDX53JqthdJzQqdZAWuTrHMmkVaZo96/TEU0gJyZmO4TZUmvjSLeyMkvpile442Ev4ZtV87T8enuguF1Jwqh41Q3FAd" ..
	"IwEt2KJXjddU7zzUuZuWfNm/yV/6YJZpnMHyuL2qwDMZsb98AJGAiQ825A/8hXH+2pPLpKnFgqkQRgb8N8LL8K8Ifujvwvdx+yuB" ..
	"ZDzAS4qfOYqYAlMEvGVjsnXVFJjm9LN62AxSO3A8R0THFNQfqpv6VuBVHobXR6h5JgHpf+YTjEw/kebzbNG/zeL18D8ksA1ipeuS" ..
	"CeWCufq4s9+Umu4EkSxpJPURkG4ik1pvjAGZNAYMTeRoIEMS8pmA6GNcJzye/IXTBv0hECBQXfTo5e3d6rU58149Qk7SUUryEYVI" ..
	"Af4Mtnf+rmlzfSWAXVXLSCQ46cEwvsW9c4jsQCGPpl7g6t7yMT2ReCmKbiKwPInIXiWemTeZFG6EOfaB+c2/5VHOsXFafq2Z64zG" ..
	"8OWdcIcCUWiakjTywXpakaouvGL9wLmm5ZAe2aBlbOAd1H4/zEgvtX6obf8vsa38R75Z1eD/zqEufoq9IEYbUoS13wRsjBB5aMp1" ..
	"0O3MDrIFKFYsx/gyfORollTU44CpsClLu93xJrGyjoQLgZV6D+YSDPUQRFi3lHHmHeRn70iHRVDDTYcsBkM0bRcX1RA9LaUYte5+" ..
	"eKq3omHRVkZO5mlHFeDtTb0KY5iMKwoYVZkMLLIxXnByCSOQjI0mSeI5JtFDrTYgt5GTAT27yeIlZC/NSYi4ZZ1OmxRcCfa6RL5o" ..
	"0ngSNJYs9drex38lApfgeYwkRBR8H92w8QyFIjWRpWds0Ds3xPwBTVtMOJh4B1GVNEELjqYiTRlRreq1i/VbyKRL2KX8MKgktJ9A" ..
	"cfo8nSvfre2zNW7tHc5G1VmQfAOD9DdK2ofoQ7gD9Ku3naOPaWTOjq3diPtA1vYPQuVDyQIerDzZsjCMje6EXg7CCNNNBTbWRSkL" ..
	"b12Oq/yvYN+frD+C2YYRUX6aW5N4zCrdLFwLDhQBCYMy5tRPu3HC2sRhErBw2HtGdDo6kkqkv1mBZtnd0wgPBOSEIeJ45K58gi5J" ..
	"Atnnaqww1ossurh42+7JxJKOIpgFtY38GAdMA6OVKfjWTIRH9h23Dh+OSNuDmeZSjrjBhUFcRtCpXBQ2ySDIwqTbbAQw4zhcE0ty" ..
	"JHy2HlXauKI89v+mzyACd5K46b23wzoUD70ZHFUqCGq8s54q8YmGKzp0forONm/QSA4+wmOc37Q3LQNGMnwSDobcXF3GgLAaJymE" ..
	"amxhwfUJrNS/AUc8l4Yjm5O+pdysi9OCFW1WNFakrV2DbjNdiT4256WWE4UxhlwuEjVCc412RgDdNYuTKyEskMUDtuPiLFe0+WGq" ..
	"/miGyoZMOmkaF0s3W5FfQmE/ejcPpvjwdl+efKMWFmMrGz9JkIaNzVeLlQYTqlVNgIg3u/sr3rbBteDoPrVjHpgdFX9sLrAr7G69" ..
	"fVOwd/PfoXQ5wXLlbw5sw/Sq5mXE/qHRheeSkGTb/nWxTW92uTOO9timfVeEcnSYRfRg7qNB+ningkRKRdvzaMT9Xu8bMIuJWJgI" ..
	"x+Lmm6UaZ3oT4Wxeubo08w1SOXaDCBWeYisjzJwFI4hXPeQdZk9+C6+otR3JgDiFFkqWooh0AfVtj8nbDPPPhqKIDifyHehY3sW1" ..
	"3MDUeAGASDkiDow06lys3lJS+NVpcArDAmJeVLDwm72FuKa4SyKYkB4BfvaL3L7PoSpMVYQMZA6nxfsW5z8ZjYDzE2LwcLCYHT2w" ..
	"n+6HdOzN9g0IO34esCTLcayTYrJHVNta7tSVaDXN2wPxJ59gq9jdnjgOJjvP939n1+J75z9bBQqGfUY1/MkfliqDVntLNUiR6rdw" ..
	"yRcIo5xa70UYKN8LCGyPMCCo1MU3EWCZICbsePSCcL8cqjh57M3Qey1HXbdfJT977Iy4Y+0bmOJhOLpXbMVnf6KheKOSwZT9hMd4" ..
	"6eupFJxDbYghiqaV8XunrgBGkcMHmRwOhS6RGwl5XwpxyuX3IhdFCOcOD9uGVycyOoix1jBPT9sdtFiIfbI5mH0ef7MvQRn14pyG" ..
	"5OzAehL0ajJdrBwcjEFTTls25wbICBnv1sKu/NLz5ng4/PFHbnDFqQmgd1HA53GuNB9vQZ6+z4pUm/htdQOIHtxOrW7+y2IOK4AO" ..
	"tBIRCiBdWWG25HGH4C4jbQJSQkPERq0hUGUgPH7i5x0gCGXGIHiPdwokw0WoRMWpelT6dRO9f/W6jAyGtF7WpoYI2nJEB9pgTKCC" ..
	"/qYXR0462JEBvG7XwfBTKUvXqAdwbXxvcvS3/e7KDxO9q2Q76rmiQQlBMb30gF9uDVCAdWaaIHCRINK6fpEqsUfvHVagTzX97pcP" ..
	"K24rk+WkkUIT6hTO4jo64a814qUI4gsrnfPb17JTyGA1lEx9BWQQ+1EJn7by2iCobr63z8oFqPMnMAqB7uEqb8iIjNg1YpFEaY/W" ..
	"yI78EumG4+JwDsefDarjE4mB/UAj/JMhP58S0xsiz8U9wGoMnJNykKL8KNFAOrY6XGcdRTHbL0KVCEW/tZNMhZT0ruzKcPO6HbAr" ..
	"YtogGQ7hokxMnW5+T5G+ME94jVvvpFpxScjK5n3MkuRtjayGiGeu1sMByjuQVFCKbd55U1ILl6tqYEATN3O9dhg4KjHMh912JPUJ" ..
	"aDdrxa8Y3b2UjxNw6wNg2gsT0ixsNkPz3/eoBLCjbRWlkUK5Ta9XBI4rBbLpZJpSU6lS7qZ4T6tMp8vNkVuQB/eRfdvKJllVH73u" ..
	"VkI4t63+a/u/dz8TTFK2Oz/N4gImT2p6zeeFR4t2wELVBnN2c479wlngFEQWrs/Cnuc2jo4UcSEMDzHmmPzjtFizJ7dsaDmX21fS" ..
	"IZP9mpjuoRTlu2OJcg69GEtyDrIzxh1/gIa3HAyp20lR7utctA7AfSFOLTAvpuMzONqLkXpDzyiPidr4yhY4hZkD2QmYwEwuRjaA" ..
	"C+BtBdeGij0TosMzR7qZHA7RCJDH+ruB5t5MT56rQbfuHQiPnwZETurykNBDBnYNhgJCsaRNRsFKg8xnYXaW3GYtYnShVz/PFB4V" ..
	"f72UwmeEPHsZ59TYYVpJNKaNvRjm9dFKEHuzOInrhYLSzqz6W4703IRBNPNL0mGKdEvQrPFos1JGBtekMRJfnwTBZkoPYf6bNnWd" ..
	"N79uxEHioO4wYAYqs5mloxpKFbTSeqaoi5+aNd35jXSyBmRudcs/5sK4XPO4Ey+xb1VyMZk/kXF57Z7KTk8w5z4WGBV+GiOP3Q2f" ..
	"4nuMJtaHR1LsfhJOwXyFhoj0gffBHpWF6ZvBi/mTotCidlGe+/It+hHb7d4fyUaIQEZWDcDj8aexcL8BAT3AK9BL7IrisWFzkmar" ..
	"pmfm/FB8u98zFEuGoVseogJEUZJNFvivp86wPl6o4fM7X4BNg58AJGUldU6oBPyTsjuAthsOpuAiaztzchDppZEXH7OncjvzO/rY" ..
	"0TrNkQzodTUePkKZnZnCvn3hUrBBh3pXt5v1f0MUFmQty939ra9KwTT+3wEhRxPLYw1g2C0Rj6zyBhSmREMzMZAvXf5BskYqrv1w" ..
	"vRhqu2LTSf2pESO0QYG+bHMrjp4C1mGJp6+QFx7R+xONQJ3wiyukf0w+y39drhUKkeo+pLJaZ8rCNHZFptdjpe1+Ze0UUwipg92Z" ..
	"LBpn/3a0pdKEUOCizEqFrOc37ayI3ZyDl5n7YAvFvhk3+XgE2cTC662F9yppdxdlUS5T6r6StR+ZtnFyWFL1XtU0FjZ70euaxyHh" ..
	"A05DsOOflGa3bhe5jG4/1NlBvtZrJfCybEYcfNmZ53KREcL1suTHE/c5K3DzILHfVgOZvYvIAp/T+SVJY99NwbUGmStYAopDB8kS" ..
	"KZKxXpwPFUdisse2YJSAyAb5xFbWgs78tTn3XPpZ0COSiqIOcadIYWRuEKkahObjhDfuN3pKJEiDFUH4OoO7xQ4Y2VLRVf57ngkV" ..
	"dM24cXmRTvhhc9jHJ6bs/7n58VO40zHFitYHrMb3U4FnUJlHjOambbfsTJjpl4wpGdYcrLEQrQMPElQT4B+8OFK79Ih7Q5nF7c/H" ..
	"kLX8FROaHnOg54bbaoKpIVBN11besTEm1fkzXpVVtK887/uCJGRHp32MJfw6w5N5dLDvk7ykblYFGgg5aexyLtNa48333edUgqlB" ..
	"Op6lXG8UiV1GRRtE5UIADGIO+W4BShkF2Ksswo5J0sNoSISQoTjVRO+TSybc4zu6ZZ8yJO7L4lduHkJz3vJ71TQCM8kyHJZR2EO5" ..
	"zS88mX7COCeooqcBy6fUXd7JUzxCsrnawF3YumUyYqaQaBNFLnIix7yU8xxb306S6eJxQSIaX8Sl0xpcpKWulH8qSjOB6zUgbvw3" ..
	"OuY6X7EM/okpg9T7pG3ziTw97Rv1B4yVe2xXoGpQbrwEhQlvwche4jeg8b+jbrb9l1M0G3XIaj0SNM/JaenSPgkk1aOGfNuNYVyH" ..
	"RxDMG+TGh5UILzW3r4FSOlNkhCwjehSFP9+LAZAWpXgqCpD2pIyozCL/r6RZNlgsCrU27OehphgyvizqPliYHnl9v2x2ddSOMpe/" ..
	"yZ2wfvlSq62Ut+uMmW6zo0FtQzO3IiwDDFLaPlLZj3FlmXrSSDe2G0rGsOSKRev/gpmiUF2N93GxM7ODeGsPa6XWlFHuoZZB2hoz" ..
	"Mqj+DPUd8lNM8aQz3YQEAFCccuycCihiNe4AtC8O3yb8dGQjlNvH3ryWrYxs3i+4Toth/G1y0sz2JC5VQFuMyhyLMLTlLy5PE7um" ..
	"ar9UOBZvm3SzE+KjRnmW/p5jhsL3KswiP2AGp45T5cYrVyPHK80oeKuj5ZdvB4DFNus0A5RdZ7do0SKfgZGTGvupt+rCvGYNOe+7" ..
	"5h0q9xkxNhr1oNhpWxP03x8hoQcwbyKSuDIM+SS8iMclPYKPiY9Z67bgCn6T6nVxh8XxjRBkgCAJBGG1dNrYbuqq+uQmZzoOeFsB" ..
	"TtXpKwnccT9OQgG/cc8/Pm8Me58lNf+dQqoDJaNlUhlFbvbMmhUI5+hMiY7aM47080rJvMiEj28Yx2JLiOSbmXS3kcXEKKcgw0JJ" ..
	"9+ul5UqoxKqP3mLMSRppfHAHP27z/5NllhA6XIY3vtlrP1dtSUoO+wwwRkyZXEoiucbFysvRyA4jhI64kVv+epFb1/ETwSzLhtIC" ..
	"x+c+n6PE8oCGNI2BsxjkC58UoxInqhJyJw9niklCIC89Kcw415zZsX9f2DU+u/M4ZvNXAy7oWTxbn6p1s9S8ySiC3uxL7tkahG+e" ..
	"HYAmGM84eGp7PdHN+JMsmGwmyYF7LlzDX7i00HjFASqk8MnV4rYie89v3uWOYTeiDcbehwLclklYReEVFtEP3xi461w7mRXQjiFD" ..
	"28/fYbDk2SZ5MLJ4lrqRQvWGPn5/sPnrvfL72Bx0ks2A4DY6dK0maoiZ7kZL5o/ywjvFL1lEbREfW/UYMhfA+pfaWXqw6F6C97NC" ..
	""
local PAYLOAD_P14 =
	"X2OBcoMknzms+YtERKg9HcIbW4e58WGM+54m/9PHisavnNbNFNC6hgPTLdih4bVOOPMxbC2cAHOtI6kc/ODoogf1DVeL54oApFSK" ..
	"svOpoBGICONkqQS/n1jgP53YgTNRRnR3+PfsO2JQjSKRGmUNxWVhvFLNYxqaERtmP12Qv6gTsJihxDe/Yiwe6pita+2MLAD7F/vY" ..
	"Ww5wI9FlsDqBalt8T/gxQzaTpPbPm4MgTwV8H5DhDaYouXXwdJiZH/S/LPjTR0YVq7b6FbH0r7avRJ/eXjYx70FaTGjs87Lpkblu" ..
	"K69L0VLOquolKIflCkucSgjRvOR0sEWYdgbUJ3lRmose9CibX+lbToSIg3mY2lepSJFPZ1m8YEO7Dw0rLG5Sf+YUZBUSWyVUSEsA" ..
	"GJ3Z2IQF9WDn1yx+OmjUh6rbtZTZEef+k7P9FZ3vWNJ8nRJ0lV7JSpwepIOmmN/lBwKP0sgrjKHrOIq7NpMHuQSlUicYdRrA/ecx" ..
	"vYt+DS7qmusPD1dYAwiox5OMG/2TkHgUI1aUL3ZMOjsoj9GFQJHPJOQZNNDypc3I4BNOW6J6972+eTZFt4oEDWCwhEZvhH/RK5gW" ..
	"Kqy92LDFr3emAXzytHGg5uoDCoFB0RQCleOJT+mtFPma1y1i77ylIUnZ/uXlgjSWFJmL6MvV/k8kI5CTB4m54eu9kflKF6DuIPnD" ..
	"Pfx9AvQsXCmkAfGO99nDOAVkNfb0g03lgoyu19EW2EurrxUGDgaPj5MtFcnpgp5x0oqlZ9h+v+S0eIh9BtSsxXSPTQy9pE8/u1XQ" ..
	"t8m8a57/Bepx9FC+ldJMb6IbesmnwqMZY8wibJcREXWT6ZLeGQNbob02WL42+HaCTP416NAXh79/BBqtChrnjNwTJvY9/X9dlnYr" ..
	"OlX1/mb/YWGAVTlUCBNjgkNF6UXfsmuS/lk6xOctNSUjVptXNhM5FggDlhOCkUQIpFCdBgSgW/8fP0qWtYpnkAIlcnbQhWDOEcdj" ..
	"8nssWbkeZolvdv3dpb69oVBcMw6BDqRZMOnWDGLU7BwizaWoxga9IMzvwe5Rw3iuwjaIyM6zUeFkAzMBdxlIh6wchXUCnrQl5DP4" ..
	"DtlZk4bRGdbN6AgPGTerxkWt8hf3Aizsc0DkGYBfhmywaey3bufNMjq9mUuG9VXIFYK/pjuN5kYjDenljx9uq8ubLJQMJ2nKrR4e" ..
	"Q5Rlh8c4e7y+8/ZLa7qRHy4zaZPS/Fistd4FAutTaL+NZS/7yFXYDZdF1ONQ4ZRZzzYhhKLUoIjlhFjxLbLOanxH2rXhqeymm26P" ..
	"vJDVKIIcCyuIVuzOVGSp6mNBR1izuUkQXubsilpSRzaA8UYYt1fp4Gj6dBNI+khYnTFcRNLBfzeWRkqIlPz8gynOG4zcFD1/TN0h" ..
	"uxJOeIJe6Ll4+4eYulmYl7pAUR6LTX3XxgVfg5IHJ7S9KHfOCMee10RvK759E7Fm218av9g8vklOcuH165Ms+5YWSd6y5+wcOb56" ..
	"vJG+ZkzDpUWbtbHLTHWySKfyJU735E5bFkzzJfWhDQT8dc4qwfw7Ccy+riypn1+788tUyrzxQ1P/ysUd4bNjd+SMxO3l+FGaL8NA" ..
	"gipREcPTYqdmjhR0PVNr64n1KQbRl8ZMfDzR8ciL7QuOp9yHVq2CCjZ4sZynfXx6oIMf0OBytbU+BcL5rsHm48ppOHczgXnx214o" ..
	"5ZrRYcf2HU/wGmKM5LofgMFK4K1L19dKPcnbf/13vlyUhbJJwiLR+JOCw2i8Tz3LpvhyhFNP50TtWGCzS/JMOXmDc7zr2p7ohtQG" ..
	"BSU3xwFuhUSItY8XhsGqLMjBoQBs6OVDpWyMvW5eBn0lkOcmEzcYtzXOAjNE2aYOJ7z08wBZvq+NIT/Ma76+tazI6QQegd6OOocv" ..
	"rfTn52RM7lAAeOBWE8K3W3YpEYeUNN5zm2nntdqKmmzo9QZr4ieGTWUKiGF5SnBmajJItmWlYUjE4TY6WiWVoWozckZAghaH1DUv" ..
	"s8Ttgv4eOeej+07ZNUkmLG3Dxv5R22raOn0XpkKMnj519bthksO8y5FHB249n3triCOfWlP/SrS5MhXwMTFD/vKK7Elq8L8k12w9" ..
	"MUtY2OriL939NHGPv6RzH73E7hWMRGpaFIosy96poOnwGLu5eCVgKn6tsv780rLeKd9Dg8PExWQiTkSAPMRHAR4SZlxkysatQjpr" ..
	"dGPFzxvABZ9YyzFvfyQKT+GSbgGfa7DsZSTW8gRm+weSR743hXaxwuO5lgpTk8utvsqGZpKXmCiE5p676vLoKkQXO0dTSzWqb5Cb" ..
	"dWEn2JjVsZvcyRPBua9mmUp2LteyjhaMIW9GbsVYyA+rNoAqQn8H+9FIbpbdp4pSzBy4XCDJvlZZDdK/PBEF6rQprIsv0jWK9aBI" ..
	"R5OoLMQ8LEcAiUwBiwFJQ9FtyknuN9QzpjrSu5RGgKD5/FR+J0nNWHy8KE5sz81owBRymBJzSoJx6uMFTqcE6dXKsTRt1ChhgBKL" ..
	"549owmAYMblMgirgbwZiBGiMpXhtAe3Eaau+DlGZu8tDVitoJf+EPF9JTbW5/84a5w/D9gg9BjqjIod3n5oOny23uNBOb2SECsBt" ..
	"4yAOnZq4BtL1R/CDiq37B4Zgrcn/fQ3N75nvAK9beCDJd5XaweIf7F+MEkwnXIQi/GOC6P8BaifHm1fpX65CbiHEql5ZGwWrX78X" ..
	"vH5z6Wd5kteRitGj9pDQiD1FoUfouO0cUN7AOVTMN5IxqpzCIVW3QGeSXDG9+9I4BbB0Csdi4BbnG3SFNnqI0peTZrKsMM43N2Uf" ..
	"xFHIKXN0WPzZ0fJF70zsdgdAO9rbfc3X57+z4pMNuESi/BwdSjXe92mgohZzqGMSdAJXVPUx6pdsIHfXxb3RJcY4YmRPyG79vmvT" ..
	"LEjIOwOeiDkVErhb1OWQT+iivtC1eNcQVkxlwVPDc74RakrF/5hLWt6zQjHjrJz1UL6ABh7ZPYvO2p2q6Ikz6HSyBhTuCg7s1aRf" ..
	"lqp7PVZl5l9+/xk/BeSKa9rgEFb7osijK1bYEAG5/mtZThfdzvjSgz8tkqRsTQTlhpLAF8NxDwQHr9af4tCZQYo989H7jFIkIdjl" ..
	"jguDacaGr0GTzkF/Psb9/LvWFsolVjLEsSuunBJep3mRIjA821ur+welCWHrvhq1s81W0k8Zo3O6wG4ewTj0cHDl1XqutCsAXZcV" ..
	"dIU2DmzH3YVNAcuvV3IEvxBJ5aiMk3wPVSyIoVV8X0Y5rjYxl4epJZkid5F9pZvZYbnyA59zN3jMt1JAOS4T2hAg9+Sadt5Z9Eqd" ..
	"HY8nXZ849pzCcIlSK3OdWdzfDObLnQAALtQ5AiL3y/MKJCS3Nrv8M+cr0mcXxRs5rkS7LQNo3URlVRuiOea8jla/FU6tMVtToxJ0" ..
	"rAZUfFG3i2a8L9BWSiDnr9jxusGJumltXz8M7oevWAaBZXqt8xV8fLpE3xFA/nKku1ixtC93L42NgpwaAmE+d3Vg2q90RKErxQUk" ..
	"Qa/5eFRyzePI78pXeL7cR1nwg9+4g+2VfKwn05Xqf3pmXLndsROoArU5FuZ6Ys/RgE5MU6FeLMcjohHc6PapXjAXRR4/6nvtjJSR" ..
	"3n51z1bHABY48lHGGTUWjvtmXj/VwBvtPussn2hNVdSFKai8ceXszHUQK84aCblYCXkyhmIfWXA7vLWVzPSCa30zd0r9W0jdB8d2" ..
	"Kz1o5qvn/V4SHed6LsLTOVhLxIUgGU66Oilqu1XMPkbeNqasTWSJqeEPt2E5weNuPNbJIL6hquTZNwlcCzq2vpN48TPoX6gxK8dN" ..
	"kfpUhbjobD/jcW2Kxw0s2LtkMUPctKy9GGpYC201xmTHWmwvl+7NiADIHA/g3JGKy26BplhWQPBbSN2WVvCNWz96pC8VOhsI4o40" ..
	"+ZmR6wfhpiW6Oy6pus7T9aIon0u1QMNvAm3Xpg/dN0EwCi4AFqI37zF/2qY3J7aDHTjEhoL71N55hnOo9bO3sQqLIJqwfrrDYtf4" ..
	"GBJN12FqcumfRmpuVXaQXruV4fNhR2Mq3rsysDW+UE1MMCAQPjVLbEIcaChAeK22uuGL/AbgbaGSkPZN3BMMivQcl4kuxkM1ecEj" ..
	"8eMnghqkwgNzzv/J2uHQuPSlWK9vgfPFjiS7Sc3+3JqDgVcIA0F1WF9PHYAqH2V4Eo8P4NWqbGZrExKBploEgA6Krqq2ZMn6/2I2" ..
	"PRss9gb3Wn3QDitybfo5EJOgT9NTwX+phL0cqKpepwyHkvtJ4Y84iJd7H1vxyksH/Z7NzBp4zaOUv8n/ydOoSh7/0UuaMuzlt6ec" ..
	"IIeYrx6/N/552qe2AhIQNpqIfKlchYXHEzXklpQkF1xDwwIh+Qhoj6v73BFu5tgzsEF5WzUbiVKnyhg5CwWhKjfuhlbIznmepNAH" ..
	"AMsuQKhKDvRpcOzX9wLDRinSlodZISwVzx6EbpyxFqRMUVwsOqGgH0DEQL9yNtoaSQcJXX/uNVa0IiU7lzrsJtmM81oqDXFMPXTX" ..
	"KHhIr4O1OwV7ONnIyA99jMpel0Oq8YsFw0l5/91bFL26EjN7iPhp+KSLDF6esI29/qlI1ZVgNIS00mLBuu8A/MiDAFwp+/neYvUW" ..
	"hQ/FBZuzb73lATN4y6KY2R4tXwALXgY2Fj29DECKI3X8AX6dXvKmzjWegvkICxJMfvix97Dtw9WyzvNHOiknoUvVut548c4Pne6K" ..
	"I6OVUPitPmPBPCZwg6uAofRmn8h+eab/pGMiOEcmeygAVQDS0VtIbUItgxs54tRiXPIJQIa+wTWLuMADPK/8VRUfSU7HQbBrSTGQ" ..
	"KAyhhuwxHu7kOdGyg+s4NulR/A8JNwISlbXVgRk/Eq7mAx1IQDpG4PD8u9ZtIiPywbY/Tv5zrxKWcH0wcqsR+sBdYNLPL+URaUjW" ..
	"J7uazE6FetQ4DwcM1NGlm0ZkmcL3AIkIz8S5dqSlXe+fkR1hWFBm/V0PPbDVxu6kOYKy2FuygQlHl9CeZMWDZK+cjKBQYAPU22OE" ..
	"0dAMI1s4kkREEPvoBjTaF0Rr1Tkbt6NZ002v4ySWqMuUo7ch15nrqIkcBBWYtSEQnbi3oqGBGgmBdodQ0GXGocqJ5S5Mn2rETNdB" ..
	"oHNrTTtTTh4fNkNGamsxAgIk9QNUUXMUjGtuRq2vBPkbyysuL7bSagUaYsAp10brnJyeOoDyW0PLr9sulPOVizAbnO+EF9yrkZaZ" ..
	"qGLQOHb75XbA85BuH2JNV4jPS9miEDAt8futF3l5du42OVZGSUWjVHuVYshiHkaPgxR6jVt7nOMrkBjIri3Zx2E8of8uttPr51Kw" ..
	"8pn3q29aMuVSCqNDousFMffaEqN7Njf6EUb1EDn7Upu7rdhNbtDlJnCfjMBHAnZYig5z7Qm2zzzdSA8r2xcaXYt2ZXfoq9PbIer2" ..
	"hgF/RwkUDW1BSUMMeVe/nqx1AGTr7l/SzMUbJnyI3jL/VGdYWeVwAnOz8vm32UciNumiThU+K7e6P3u0w+qyR/w52eAmvtqoA0BN" ..
	"VcSypVMr0U7aeMeWWkqjmys3Pi7BbVni5dF0kW+I0NIXC9YlbznNshdIiAMdBXuAPjJuX7DJuxLTxIj6y9+qVnNKfiefsy9vePPC" ..
	"NMcT/iKzuVFcoRp459AsAZfeRgyqJ8R5D3rAv6LUYryjF1RSMqi8KLAeexGV+MoFXerXo12lwCaAr3pa+yzpbt5Su3jVb9IUPiqb" ..
	"2+7jaHzQtpNJdd2usJNgec/TWpcB3KKVpD1Gb/DEIBeuzFgAohH1hII9EIOhTJxINNVqhg2CaqErodUHMhXEUkZnTE2BBABrN8ap" ..
	"mHZ6MdfrEOfnH4tebkmQM6MCIjnj1mQ+kwGudhl1JQtwpADrYrUvzbEf2gX5uiwDToC2cEn3ZQMsookxInzhv/6U/8HUyRaaNfot" ..
	"T2dsn98aF55/LWyNpwKeV4wPZr5ci6/5kN7TJ3zPe6fc1AYDih5WhBZrdg+Tvh0TDqrrstC9GhfF3i8ISEX8fjcZZinbJZLFbMF6" ..
	""
local PAYLOAD_P15 =
	"Z3GNxSC394ztfTCETU9+1v8doisnQ8A3J85w7wUggGmK+4DFixsssXEeXWapfH3HS27i06K+6WRNACGTfiL+lC42ghnN+K11SzBM" ..
	"pHlcpdRD7qGHOKqrgrI8vTxJLDtI5fDJKZw8KBmA1FgN7ZbpgTFqva5lChmZ24JI5Bx5BYMGDFyqpZRYfr8ft25VMWJJ285Eqp6u" ..
	"lnYxcVIEcLR78VJ4luGzfmW5LM/0eM8m1ogQ7YsFPT1tH3sIyRqh3hNloycgu/Uw/OG/dIud5WeHygBMXqgBJHC+lzQXv/2Jl5fK" ..
	"VjcxxoR/QnvnJGlVdCYbbPXJc40avane33ny/fFk4NjseMhFO6itj50jhXBKROyfDCEh/Ea7vS2WNdlIKfdZnyFqg7fDJM2biyqG" ..
	"/2xYxor3cPdprpyDxafoG/sWXY91aEYShCy/DbIOeT0oVO9I+nGHFI57iN9Ue6vjkDvVADEY0T9Vm+CtuVd4ADqyr2P1op1yvZOW" ..
	"YFrRNVn+pUMUW175wvbUYI2Clhqe+0B13uGu464PdjtgFH0l8vobAUu6gVqf78WAERLpEl3A0EORugUNM3X3fMfBUlRhp9nDkc4Q" ..
	"wGarnguLgMRsu286VkdwfpFUOg9V0LK8fWRIxwgLuk93Canb9tVF+4V3jeOXQuzq87GVnbBoygqatzzBE3yhNXBfULvbTVtJRpnc" ..
	"sxIwgd5GvoT0nEumoMsguweTP1Ow7y1ADPIlozJ+0tO+Hot3YOv//VBIerFCYjf5xCzrpMOIZF40qdfsztZcNJq7DZELcJa00UIf" ..
	"kM3rT0dufvq5yTp+UCUA9GerV/LY4shfVOI4OBmDDyuH8/nsRXRJcaHWlJAU8EHfwSef6GagvCWzVcFTOz7J6XB0iUDq/W1dx0cU" ..
	"fvoPUiSxoX+KMA3snJolvZNKryNEPO7fnrI95rS+mavt3rHyPAW6jahhH/N2gTFsf0VpyGxYc0OgzpnaOmpdK4L2JxQkmbZVAJdF" ..
	"DAagbL/YYgKHbZYLU6J5wkoK6RI8CarYjUs69a8Q13h6IRAZxG4CnNSOrxvkmyQstT6DTd3xgbiU+AnbQMGhxBbEQ3T244sCL9pA" ..
	"ikoppn8Rp5+Us290DHYezcdFCsb+3QVKPpcqE2FB1GKpf8l0rInQSAfMYBe5Yp8bGuoifoCf//ohLmQ4bSd3C8HpbsJf7+wZRzsv" ..
	"qGTiE1k6M7ivE/LKvyUoQWa+YP8c+rLdjXvjp0KNaI8L8GwFWXx4Mf76ALD+vkE65HbTuXg33UQL9U563/GGZvmH8VzqA2XajrpB" ..
	"GiA/kWH1wrxxsql5B1LtDveaoyR2yXVo6h/OGnyhtZZMhK56MjxH0SxUUaywVK0mrnh0iyag0s1DMi4wWLnCYppU4WlO4KA1D/0W" ..
	"F+7vy7KF4I5pgB8iKWotSlCBefqIW7tqC5o1VKHHyIPf9H18/VckrYA5LdEYcDjaKngojQpW8kdCl07DzPGk0eDqIOkESsLvYISZ" ..
	"nRVKY3UqE2sx+NaaW5P9Mhnnam9svkk5WsaY6ijE8x+/OoCuI2w0zgCs6YIfjO8gDI9+wyjtLbRW8cSPTpOGLw==" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9 .. PAYLOAD_P10 .. PAYLOAD_P11 .. PAYLOAD_P12 .. PAYLOAD_P13 .. PAYLOAD_P14 .. PAYLOAD_P15

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
				-- caller destroy key GUI khong bi block boi task.wait trong menu.
				-- Khong nuot loi im lang: neu menu source loi thi IN RA de debug
				-- (truoc day pcall nuot -> nhap key khong vao duoc menu, khong biet vi sao).
				task.spawn(function()
					local okm, errm = pcall(fn)
					if not okm then
						warn("[DQFarmLoader] MENU LOI: " .. tostring(errm))
					end
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
		return
	else
		print("[DQFarmLoader] " .. msg4)
	end
end

local sg, tb, okBtn, errLbl = buildKeyGui(function(input)
	local ok5, msg5 = tryRun(input)
	if ok5 then
		saveKey(input)
		-- dung FindFirstChild de destroy, khong phu thuoc vao upvalue sg
		local _pg = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
		local _g = _pg and _pg:FindFirstChild("DQFarmKey")
		if _g then _g:Destroy() end
		if sg then sg:Destroy() end
	else
		pcall(function()
			if msg5 == "key het han" then
				errLbl.Text = "Key da het han! Lien he nguoi ban."
			elseif msg5 == "thiet bi khong duoc phep" then
				errLbl.Text = "Thiet bi nay khong duoc phep! Lien he nguoi ban."
			else
				errLbl.Text = "Sai key! Hay thu lai."
			end
			tb.Text = ""
		end)
	end
end)

if not sg then
	print("[DQFarmLoader] Khong tao duoc GUI. Dat DQ_ENV.DQ_KEY roi run lai.")
end
