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
	{ seed = 1321457570, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1320925108, exp = 0, plan = 0, hwid = {} },
	{ seed = 1320342481, exp = 1788089514, plan = 1, hwid = {} },
	{ seed = 1319149780, exp = 1788742721, plan = 0, hwid = {} }
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
	"6z4hGQrvek73lLH8jMjlovpAxme0a0MCejRWxNkNwwSgOtNU90RMhw8fPEZ+wQlOItn/+i24/brykfURrV7QPtBg+fur+fYrJyi8" ..
	"NckAFppNQsgPnuLASPK7gMYk9eALy+aqEY4POjybgwezFspDRMlMEohVVK7VemFxM76AsiJy03XhEcOqDbvoBVAY/boL31w5CiOW" ..
	"repb2CeRbSpH8SNKjvkuwqHnFQHciyXfUSlrOFaXerAqiYlZlx9NTbUZYJCPGY4cKY0KZV6Er/hrzo3btIbiFfneYIfdWTeeNiZt" ..
	"4XBRvayC/Nt6sT3MeKQ1KMrN67H747boXroiJEEq27hQ71Bele9fL+basCLdKirsGrP9ijpgfaN7PTIx/BfI+jtv3s9BKtT6xUYV" ..
	"sIrScpU4nc9Bp14tjrvoWz/DGHr/3yL5V0H9YeDHWi1/6cu/fDaSVzRmZOYefoHvG4lNrB+ZQTC4wMv2c7mGMr54zZKFvqvqZQHf" ..
	"kBQZb07so4+DvVw18/mpBWg52dZBQQj5Vq/L6mVFg5JL7skfsAsI5klN0UqIm8lWENnYX7rVB/MKbSGZ917CK7MC8HNq9pPN4pAB" ..
	"/U0WVWLwJWzjAHBpx88UOonMtOQ74zHkhOD+Ww79vBJ29pS0CTpbDMHVs931mei9fNVmlHMZW4pg8Qd6hOVhz8t1dI4vjvFiP7p9" ..
	"wgVnrivrV/5TXBT4o5v9XxOe1kGx1PsUziqcK3GPtLDHzvKilg4mnDuhMFXjnEa4amcTnnBEEG8VgGfNj53RHpm/KU7YgXRImXe0" ..
	"pl23r3ULfSxykRU/HAjwFspq0mLUHC1Q4HaSeGvCOOm4zUad6BHnMPB2mMUsg9mHcc1Oio4O3uFk83q6uCY22yhStOMpiIEgTVSU" ..
	"0RV0/i1qaSfpn2B6GBgostREJoTjMfLusrqXi5P+MRV/odicU0IAkHY9TvM/K2mrJX/3389eO+dLvaVcS/kyzueYLiz2Qn0x3asK" ..
	"BQ994MpH7pUHkZ2j2cAIqvOk4RwHRbkRf8ddYtIHMXRCqSiDuhRhXZDYeqv3pktOflvt+puu/HrK2ITLBIF4GYwwlxpfRZoYhM68" ..
	"UsK9MbNirCUR0rPTKEqxxmrXyVTAG0g5AGPQtJJYvlf5K/U2ifpdkKrJ3WigeC6zMu1FKKqdgg1Slm7nKhDdtTku37eIQAu4m9fh" ..
	"Z22/ZCq59GHGVj9jKgOlqmSnCuGit9eP6/jVwAf/+yd5nSqdyK8I7iypKH1GKeYWgm0MXhSuEYIcxHZu+2507knLxlZh4tSyhNkC" ..
	"LTdd2YPp0x3lNvUD7qQ68oS66/jnhg52PkQSkMKAA1kirZuqinhdnxSBdLuL+WbhpyuR1LFGjSjcTu0PUtH7urFwaQQajgZx8obb" ..
	"XG1SbpRT0rka+QTZVHxqNms33TBWOwVdWIT2PDvbiOBV5fuXcVltcyOxcXIzDczmF3ChtLXDOXSyDY9u+v4TpL40YCVT2Og6F7WP" ..
	"MiFMB4JRnuULQ1D9RFdlOIz30JlzVAV5Y88NzcuL8pECDxJWGu/XvLGqP8yU/qEd7XuM71R9/6neOxIcSaLqD9rPHwJNuhiryjv2" ..
	"aho+GB1k0z7nIAdzrhMbR5gllgdMoqLEslLawdxDAlf3TiA84ZvUwghzf+5gUKkz02+y7gwm8JHWZF6pJ12jzJiSiLRwIWr/vrm9" ..
	"HDpylqmCECzY2VmTiT/xhyN3CIgf6T3w6uAUjSiBEIaSmi+akbGCgNAtpuo/S/1ByIkhoiADHxvTEWiv5QHCBx6qf0XzF4c8jlgY" ..
	"bbpS0OCEddapBFsOASlRSixUzSl+nsyVB07buVQwwohvotQd0zlSvKbF2K9sxjqGTGZ7PsUmdr8SuhOxhq8ZaiLj+YIwi0gR5VHb" ..
	"b8BB+o+oeQIa8ySmPLbwSCpvehh4XBjNSXS6H/rBNJcre7viVxV7rf0hgHkaFEAEZcd304Jtm1l98n1mHY967S2GcwIzzIcXjXeX" ..
	"PT/81CP7QrnR8DZO7apqYCDujtLDCrGJWZMkRjPXHR9MFUuZhOgPuHSp4a2XqpwFz/tHboWRSIJtSSUCs8aBaJxHsONFQgLSXypO" ..
	"kQf8pS6XguXhwpgVlD9yHBPaFPfI4SadF/qXAatd7apMNm39S7EB/jkKdsP7ty5lr6Lpcl5Xqh3nmxHHA53EJD/ECQYupvEot2sz" ..
	"MfkSbJw5jfwyRimaJ52Zwi7AYmWbPzH4mHyXB8MTzmubKC8DQXk8vvxg4PrLeIpPkGiXnQRPsRogLkwI7qgK1XdX0ct1ZZwRy/tj" ..
	"eQbYKLuAOdfRNEfCcpUHkjKcEZElqczHibBCbzQOxOxTvG28Y5y2Aa4VvsdsNlNb2Vv0DglrdT5my7jnU5C/+XVIkX/KImVa8uqB" ..
	"dkU/1AAsSplM8X6cd7QOT9mxxbCGMCUu/PU5wQpmqu3k57UF0u5uKdqzxeILbdZfDnG71KVS0CsnlaZHyd5u7AFYAx9HTMk/+YIM" ..
	"6QxE7tTh8nOneJ5txeDcX09JpEZ4vweJi/ElViESpMuv/fwO9QcRMjZIlQm6bANHPZrjL0/6l/mI/Rbk/QGDVGG01pLE4mXNc8uP" ..
	"wzaWR4qjGDUG2CoHUih0uoAmuGTYeLDEOAOj/lgZfmF0Y5ueBmOUtyKxehBhi1qwx72+UISGzIIcxj8/TCJV9pF08x2cCjId0Gtb" ..
	"SAWpviwI+sC+bnk+rVJ0ceg7uoc/6N8JBLFPSHFGPcaLM3iPD3jQitZaqfXtZZuh4R3RhL5yPzDjkBjKWi4BjzcfkktKN7a8giTv" ..
	"BHnAqNNYAE1UjmXKGGNiXIT8eKqJl2yBlt65TQkACrAatw4fEqf8UMgPzVsm0zmGoDloZbY4CvH/6AyL8/KLTKqzCYTb75xkMd8r" ..
	"CtVlnSOkSnkMcRpi1Umr5ZpaHRnRHGJnSIL+CVjAK0adb2H+rquN5UOgrr42+NLZzH5PmjNZPetARGXZ2J0XhTDgGODujTO2xkWX" ..
	"KS11tcgwmiLCmCfajauUCC8fsODM1MwtGuwdxXfNncyyySubiWwF8m3sXOP2O77PgQyfrufwBpUrU4ZYB1VdBxQJbcnIHHli3+RJ" ..
	"/TnZGzSHR9TXqMRGVr2pN1uFWIld0cBMIaXLZnKmtTh6rWN7J1O6ToZQg+j4oOVGR6BQtwbuBk/Fi324oRemr/9i41g0824VbSlL" ..
	"qkZ41MzT3lqdd8g/442sO0FAn9gGXHXuNvq92DqhhhPX3LhLvWU+U9h3e4kl8zx7pLfueBITlvd17NHDuM5LutwjvFwR0zDqplJY" ..
	"XEPHf+VouMJAPKUu+z8cw68pO8AUwxrWRjLlo77ocmg9cqWllsqhUKldQrWoU9Ah1s7r66UE9P7W8V+v9pMdCTno1HvWkMxr+Fa4" ..
	"RYh8/6mVfIrRFoFAgPErOTja/2MAY4EU8JulEhTkO3wpmo0otpVDQlc6aSOCBNG3G9vZ+T6p3MyMT3Kz2HY3lC9RPvC+ZAmTXD+D" ..
	"rqjqhfxQskFmGXa5I3rLFoWfbm1Y5SmXN5E/Gwst/264oAUSOmpto1JF2KYivlARYKj28pprlAk/tcT1W8V6gJbalw4GOk82ZUQ0" ..
	"HNMRRAj/+BcLOt0f2ltupFWgI9qb98m1LV4nSBJoTwgOxUhv4IAjAN0HJVvxpIVdDk/c486WOE7oRRLohc7whsrRYqkFhq+zjCPb" ..
	"PcJzQcLf/7S4zH82krObySEBCwpq4Sgi92aBC9K8u/+VXhNAAyJfCovhny31+7w/OoI1MmTLzCA5EI6h9F4XgaaEM7EBnWFCtVxb" ..
	"3ryQHQTQHYQ8LiINs1jVi8XwkSBJL5hRZ0vFlFnTbp7qJFgOaX9fmEzwFcvlCAnQoQdH0AqW4+707azU0IaB/MhzKoY+UrcJ//qT" ..
	"b7WQTk6A40kg9g9IRAqfXgqjYsoN2fx377NCPVs2zY0WTbLr5hgiF1TJjWfYiSQv9cvAWvQemvpqUVZbjOeSOniPEiFkvvppjR71" ..
	"tryK+PXDBEK0ylYFI+4DKJsj9EzlriDX/38iCkVsb5Cm7TbEfCcIWnNWx+nYPDbhICXV0jaSqLjtOdM46JUblc/ZvOD2K0/l9Ic8" ..
	"LGTTEuo91fqI2gzdiKv645Tew861y8KxdTjIkE2ySC2aD3QF2ucFkAvjE020uKfoZgIAQwX2x0cwDrS5ZTHdxYo9Y3dzbs85c8OC" ..
	"CNlJihPjL7ry4mZqnZ1Kpi3fw789j9k9OLAYJXGePrA7rOzuNB4Pm95BWHoyGLccGEMePpcrQ0Z6fpl1SKiaaU3U4QEo71RyF9YT" ..
	"HW/vsHJD1xa6MHZ981aqFBLc8h7PWC9w1xqUV/YFWommei5uVTi6gudyymz2l9BBp5PRHJxvjqM2w07mdScebAYZAAQxoiowm5oF" ..
	"wLDDnQc3spfGJpm8AWgrR5un3p6zDT12VPPDyr2zOQ5Dl89NMvP3MMeO5ofn7pjTrqTDU3GeQwT0SjzeG4IimKx2QS/+DkCL/mQ5" ..
	"6axUUGXUEmDLl9a0lT+8dC5tZ/G3ZU8VjCAzlZoFNcO6CSVzm1ZQu3QNLYVd6/W5Q865A3qI+wcU19egLZASyjDSABFqkdy/saga" ..
	"L4y9Qya0yidC7VgqRAYP9zkA4PTXXTwTZuLiPGUdE2A7uILi/s/AJ0JWFYCK8SbWHSpR50+g0WXkxi+Fp52Ah3Dm49DmWP325i5C" ..
	"N/6sdLcXiOLbWlMHOa777Eun7qZFp7pZyX1vDyIvzBLI1xHvzhUrwhEP/YqCMiknwwSlJ1hSi2q1QQS0gtsDTFZSlKLs5MlvM9Zv" ..
	"mikpF/dt5K3VXr1ekhtrDzR3xMZutHtlB9cDGb2sPt3kuuvGKj0NRQ7/ZaD7KccT/HtExXmGVO9jNhv1nCO5WP1eZcXDUERYaN35" ..
	"Jfub079pCw74EN8Aj/kEhnHDehXNSBDGZrzGHpNlTZe0FJfFthxEDz1gNe1tvtSCrhOgDkgoRsJ0LZ6ghWCdkHKhUq9OdhKy0q3O" ..
	"5i0mWUmKZfJx29GfwV3XqI8cH0CPJAbP7TteJ98bhfq6lkTQ9gLEE6M0ByP65Di+CQRO2yasKOgoMRnOpwN0Wc5SUmmlJSMqUwHF" ..
	"UB3UgHjq88aUaX7fvzKSl1IwSSMG4POoWUBl/OkkmHI/eErM9bMWoyWsnsxLR0PGvwnjNhc4bI3h+0RnBKQb4ZyPmNd/5AxFxQp2" ..
	"x95Y1a77FEvG9jwX4Gag9ME8mAu1z+CnA9Uu7n2C7SWPnTI5D0rU8pHDpJ9Ig25tkdMHsi8LXw94HZhK3Z9moMXkj2OzwQPNwlAe" ..
	"kaiHb6EFg40qPZu1VfqOv4zoaeB1nCxjBd0R6rnP/fzKwEAtL2/VsX3wpyiGYXx130vAYh6A92HRkOBVmdnUjJfGliR7OWIv0ogW" ..
	"/rXvVPDvL16f/H54KMGDNmhUgzcited9L2XC11fSHoqocnIgjFf9xxHA1nD0kiJ4q50JgMG2dCUmxaq2epmtVttGr5w6NpzmvO/u" ..
	"sp9Qu0L4CJ0BxcenaNk2Xm2UarvCt4m/CJnFulkutBhws93hmT044y6C31/f7/d+nCnec3s94V7WlDapgsSeDoEroUSybgRdNMxj" ..
	"ynv2tEhHkPBygEXOdbSviZ9IidDqZ5KpcXumuxv4zUVr8fYsxslfAnwVuNJOgA1F/6PAhrt2zvORLNxd3qCOnAf7FHRZVR5hed1q" ..
	"JkbDWXqzf4fpbG9Bzb0G1BGlofKxpki5Yus57sRiW8gnTK0aafCaYmO/6KzBYY2lXGgnB5iVF6vvxuQXnodVZzxO0XTpMK6haOvn" ..
	"Q1hsX3OkiWZC4hmam8NAKRSvMQ+ROKkzMtZAPa5gHp4UFTSFnqY9bjx+2CEFH1IsOcCKL9+ZDh3H4dEAGOrjuk1etXkq87F5Vq91" ..
	"0zCWMLmFGjY9hS8t4WPSkSVDwn/XPqfp1L8RPnBY6Ft7VjG0UPYUuRxsurelVX4VlKvApwFW5ZIej7LtqkHW4N4SNSlFnaCFsXNs" ..
	""
local PAYLOAD_P2 =
	"DPa2YSUlm22AnshNNe0c//Fd8iuZAz6CoCj+zTLZYISWa8zO7XjThZtxR/AJ6/rXlSIb9AQkyCGFyzAOB80SMab7ZetHfBUAx+Pl" ..
	"CNz3gRKrGW9VPzshAkQtjtdK4flCw+JBpmBXq1eB3fE92NnZ5ARy6bsa0ZCcv7jZFQO1TL9wif4Dk9JqXuCUNR+PdG/2mATmuTAb" ..
	"eygBlKtVG69EZGSPRuFaRyakG80rktwA938eNx8/yc2TO5ybXyU16Ed1bO5nsQkFqckovf1qcGGV0Tk+pVkgLQAqIAVWxPN6zxuE" ..
	"9nbHJLmkmpFoXYbX8vLlW2Nqe7ws9QGKTDN/S2nr2ouKaL6rcqJSw9e21eB/CsNgkXBkpeyvpheKn35JPIlLyHPbbVNmaiwt4ZWz" ..
	"ujID9i6103BnV1RskIITU6/j2xW34YCqCo5dvx6ZeKROzldSTL23e2Ed7KaYqNSeM7CYexhH9c01yJ+J21G/Y4XTNZVC/L0WdLq2" ..
	"ofbiUo8zl8mMxQ8eQjaOAZX54PBMbmpkEY2VEDvIkuHT0tqWfjSkfC/KDtfDMuFUm8fA/g4MlU1BYoeNwv8mSansfV/EiSWWsU3R" ..
	"F/Uz+X+TwpHqpNq6JlnE084dcZgM84m9I6ODPL3Jf2pFfeilAgFtuDNaBJ6ETVbA+VlQkb6hJw677+Ts7BaS9Q4Mc8ViTEkqeU8g" ..
	"02q0C4PV1oa7/3fOpBpYtlBZYu2ihFrwFJgLKhQsxhns09+WuF791qUpparYgEwUd2YsAWMW/bwybmqsbSDENxldxz/s4wVmLaCU" ..
	"fpLvV9u+ZN6c8c6C3udLED56GB5/K2bPcutsFqhpxCCYvR7a8WmyQkomB+Vs2vvE1dC0uXYCvEiya0F1ohg0RtFujL1L6sCfIgVK" ..
	"fU4hlt/aAtRm0pFPtK38Rr9+O2znkEyCcIg8bVtujOFZ+FFPA9+VlYX61GztN5DXZBoZGGjJGMee5dRwa1EcXJbjzsqncGbAt+C0" ..
	"xuqiVEHYSl0xDMh+tHN/aIv0e6G5gKIj0rAFKHcBi3r0saRzeQHRnuoLT+qmAEM8XG6B4IuIS8aQERYUDFbIck8NiEuu9lLREyXE" ..
	"kiq+hMAAd8y9LLPHHwJjDPL5BIXUwe7F3ZuooDFKu2axzmvAAA+MeaP4p4YbAIxAXTAWpGJYr9DwzKaji0kKjfRhsNdYIQFbEn3R" ..
	"aQfF+mCvMWRT6KMA06pamqFjjSC/CQzYnLD+cBCgw0RF3x/gFFCLtX8dZ9dVg8x0jA0ed2sVSkakkakSd15an1OdUm753VxWpXJ6" ..
	"f9a4+sRhk+GN8VsWyHxSaxqlTgeNFlFNzSmWDPdWXQxtKThZrYv5jebkHDMSHmOgDwtQerLFxTYPVNfs/hNB0XW5qWAXdsHRPBpR" ..
	"Klrt1Tu8KqQHbCLzg8A6QHz2LINB3uvw14lDWL6TtAE32j1Ty7O7cUMfQS3WdmYQv5IHgz4CrPC5thI9CEZOBHGrbBc+kNDmISsJ" ..
	"X5oEhhr7JDjlmmACfWxvEgFM3gpT3SgrYtAFTAe2nTtLRIHDLhM9BawphrguCLTdEh1xi2vUmhnIaPmtyvmQ2TOOeQTzH40/1tNd" ..
	"Lvz3pu3oLNEczrwF76zc4cT847GR2H2m2+43Ux87YCQLjaf9ls2mPzT/n549Q0TOg+W891MZkUFLSwNXgvwrzE3DQt6hPwroQpw/" ..
	"lES9lr4qS7GaZwvdypKMcnqYRlSlplRAVUKqQzGyDY2ezDq5pTJAdMoDHsHUD8YPJQwekp8bIdnqjakVHMWmokT1leb6aVUP/N4A" ..
	"ZZJncMP/Udltp+q/K8weGXP6Jav+7l9j4AjFsq4DHEfCfEn6N9eR/xF1bay9oseM8iQdYxP7bk7ShB9c3X5spiQmmVO0YC4dk53F" ..
	"rj+tB6uFZ1/ckxA+DqLp/G3i8bwuBddb914C4iKn0QqHba+rYsuoeQX93xjksMGR3UyHeCJeBJ7kCUG0PtFcunrqYQQuG06Ch+hS" ..
	"g5yFgwP/fnGvx6tReYrZu+HajUXLnohyaLtMXXhEe5jblEWx2qdIrJTK08QiO44Df7nQymlujYDIsPMMeyzkeVRNMYW7xtcKj4SH" ..
	"iZXTmPmBKoBstEApU19k8wF1OBSpgIE2017LWJntRD4vcvgf0dcImYq1u5Nj50KLZPRjaPd1kL7a/HnzDCG6ociBPVB3bWAC70d4" ..
	"etSTLENTxc6e7IXZVsvJxsty3YviXs66hlPSqZm3egwa2Tpp/zz6J2a0haz5M0yAV1ZesqWWRMu4tK7eGchIaAhYjmfzkA6YqMIr" ..
	"0tfwFwgBn4jOWBYuiQybXu+Gh81lMOJSo1vERrDIgA4SBhipK4p1Yv8VWt38aTdls1YsKZ3P+sEl3YBfIdDvcg9ExkdTrg62YGJE" ..
	"Ed3lCiQselghL7ajXzqR5V+YKDU0j4SWxzhaWoRbbA9psFPGwJMPGIxA7r5pyaEen8OUp/3loqz3vNVnZwdt7WInziZlBB+77wxD" ..
	"ZFv5xsOM6NnHu/ocC6H40Xw/tqHmoMm2+j0PTMN7FPZuZt4Hs6wjKoVr8frQAjSXyPUpdQ4fOk1fFFT3a8fz8gTMtQsAYOkFcGd/" ..
	"tzXydKukIJ6r0+5Doalyk9rQbC4UN9ms6h4uFp4r/rRirDAebmRvTaRiEigBA1I1gpJFk5J0ZT7tNPRuqWwBXIc8r9dyRO0aebIB" ..
	"/UwUxxGQAA1QZODYCHrDGr6voIpNp5n9M5g/RWVm+HcFTMtKpO3zStWOzVjROrwNzz17x+i9I6y5ehZLhyKnfFG6jT8XQ0wMD8t4" ..
	"hXqlMu9sDhQU8dm1xiT4Q2nvO71aQeRS27Kk8cZQxP2ds+j0Y4WrDYdjFwPjur5eXW2QalDO05wHq7SK1Y0lVYkV9iVBWvXNmVMI" ..
	"5tlVZUKDrc0IevWt+DtW3/qtqO1l4IZeP3MkWttTmbrGiBakmTZC3JVSCi7C8Lnu0Z0seIImMbimOOvxQBxE8sO4zhMo0JgcDq1x" ..
	"hj0ehOzlZiFZNYsSTOBmP3Qh01ZqIGUfvzE/CMYkPYQ7YiPWsGOI9aLqO0o+jpPY6WAGue8HWoTQ3H4DytIGv26A29NDfj9qfgPn" ..
	"3O08y35XKN2+KnF21I6oODWjWcdzjEV4wFt+H7do4UiyaSKLXt+5zjn7SxpB+Vy/h+gniPIXTnMhCctJBseiH+zOGCtTU14CqKZg" ..
	"V5qoTtWDviOGqsoGq5axvBtaiMltjnKjjnIyYjJFs1ahZ4VCA4o8ocF1fVCUxRM04DbuwFFHuvH2qlq1WIafSJu+Rra+LLHBTAjB" ..
	"HbOfk+fxjeQvabtrHXpoLNhQjKvKg+375ufEz8p8+Hrhma2mvTQf4STrZ1ThT7R3S34sll6x0gpO7Sl107ThOvaKM9fiYKytsBDg" ..
	"sWF9DuttDzEr2kmQbDj6y2V2qVhKMhkorADW9EmamIK8ZNqq8XEfqhZKzBfMpQlQ/wLR89cLISQMLMcIDMoyZCkiHwTnle96CNMa" ..
	"plU5KhGvFTFSfvkNotPZssvYXDAtz0o9FZNNmejxMMOAbeexP+mKIl5vkG0/EuhnJs3Owdb8Jqo6ibSSE2i1+zvRfwwO4KtJevAC" ..
	"O4Lpmrv+dNPWkdWpmEuTYRvlMdQAPUdU3biBhTXMDKw7B5iLpsGympi5mgOqaYjeVF7tZYxl49QOa/jstdu5dmwoyt+RbOa8V+7y" ..
	"+FDFmiG2RWTVFGOKfe8NOMOcN0pVRMvEZTv7l60jZTAJKvw5wKX7EspvigNM/OgNu7QmU4jAReHkwRNJPX5IuL0/jpvbJhf6gzTR" ..
	"woEChHMx3L6r9XRMU6SsQnjReFq9Xr8leFMYIAi70jpPchOZVo0Wj7PaX2gJ/iXGHB9XiujIMNC7k7nQrUnLh4Fqyina7z2e/4t9" ..
	"hAJpDogzp2iozVcUeD8K248MpgPtirSk3xbZrKx0tSKJQvwQAIfrFMDqI5ISgDyJRIdVtcjzEIQjLz7K3driN+R1nLBl9/PTR3w4" ..
	"mapkv85uVhZbqMja98biRUY6lH+AC9REosw0V+JCkrTf1KXRA/g694TY0zLXO1ibv4gaksZBo353DRoKF4AtJAYlrBi83MQK1GXl" ..
	"IOzh4R9aDyUfLGzeAzdWT5OLdsISSXeWMyPR8C/Fp1ZIxESocHXE0pSP1e64G3cGAojOhPVPwyYs6mPwqu4mgmrlI/eLkbGUyofa" ..
	"lEN+Xk3XOWvHMkMhojYxX3qp6Ajo56Prl0oPCfMMFT2ECEVGt6rzJ8YvbTounXdP7XM9tVx0xp2cdq7+KTpy14jB0K0of4tcvA7u" ..
	"woJyRLU+22iXiebOuSMIgdGvGUf+nKrGmYplApvJ/Pz9zx4Z2SQBfc3nDeKXX+0h4oAsn1GRvugaZ1EUgE9TMiX/HHfF+P5JKsKq" ..
	"q/x7Je3J23ce+Y3e9CCteMm9Jc8IbNfXjQsOaGAPN3xd5nl8J8M5kTKKKisv58gKA6lyVK5FFpDn9JhXrJJ/nD7G+aU8rpqvzY4H" ..
	"McB+28Gkg9lu6htKemoUYws98WoqUIanCwSFk9WOZLcdnukm6WqmpC4rFpu2+Zbhhja9zCH5iO8mFa0vvrWFL4nmuQrvX6d/b4eH" ..
	"TQLS3JqY6g3QTvKRyCJTnCZm8Iyw076CWEpLcLZkxSq6eaNv/rBH24JnSHCaP4jkyhltuaJGeeFwPffVteL6cInTCASiT452W1TZ" ..
	"PGcpTu5UFRbCRr9aF76QeWwcgEzJjNCIWwR7IDp7DO7AlkDdeySpnSGpUsIadFTRX1hMfrz/tLBt2lmb0sW7dROOeRg4I9CkDuSv" ..
	"KTfCTD1deqPMKnGwtZ4mR1dLStN/VeXUxlrpg6B7MCZufJlHdWRFFqTx8WZV7GkgG+8Xago61XROPC47gIxl22s/CrajyELAk8As" ..
	"PzpeROqkyjGaYJAsVlL7fEb3qyMu0vGrIUbDu4OBXa2nZczhTHVnCd82k1g5xKTt+uwruqnAxD5jcy6i20lDHErXPlB1LuhFWt3K" ..
	"QPlZN/PRAkQfF21LVIrIJBCCFaw5ApnD9N07kUKVZTLgWFhaNH9xe5a8I2x7okbcLMUduxU1ucw86IRMecUTtIiqR/2CxsXdtDgB" ..
	"fv1VOU44e85SbkkLASB5Smx4lvlkvNMAsrgwTS6OyWBtiUAbdqH+QRxvpPXjUsaEilM4QEjIJxaWPdRTxMXGZ7Gpo+9MKQ2AU69h" ..
	"Pl6w2VtUkei16PgxvEn+gWfWtE8LFcCASi03jS6JVCE8iMv+Fu2Y2cgY5mf7ayuT0AivV/9t5+WrtnJUiOeS2lopV4JJIZNkQ7IK" ..
	"f8MyYPhRZyupnl0Mtt/IJMpZ4jfdq+2/RgOJPKZebxWIeyOsS42+YiiRWyTKcV/WGXaJpDFGMRrE6k+9sLsHnAT8+ONFD2ptfs3G" ..
	"d0kiTG/TrtepKxtBxCgOQaC7vFeDfOSoqEgaPJvyTa4M8XfITb2F/lbk5tn/M/oQVHibwfvzS1snaMKq25UsW5WbJhJoPDHQh1HL" ..
	"A3eMf2a8VdaXzJkwCgkgKvcY4M5gygPR/fp0nPeRJwcGOyP4srK7sjCNF90h22niiuJgtEfpcFk6WLYl86nU9x+vhikrEis9R2kt" ..
	"1HSy7jryM4JCxiKZCyL6TRtmz35Ii7GCyF6NZHpxE73zYZfLx/5uiEjDZG7HY1FhDRm+QkPba71DYKLuSI52nzW12i5X0sl1Qg+x" ..
	"7mhFhwYJWOoG5Esgc0HqvFjs4cDyAnGSGfMfVP3b1EIs7ENwJrwuiDDQ1EJxYVA0R5BKRfxy0arm5/bFA1OG4NeHUln94F59TRYV" ..
	"wzNmmPyzxWtjpOekEj5v4Rk/h7oYQCZKZZRcXgXcNNlKM0K8/Snvtj1O6DbzWZVJY12MgGm8LBMjCuwJQnP2K56jJSn7zz3XL87T" ..
	"q41Djp4ocnWAW2F0NQRI78eAEG2j7ctTVBScaUUriXsXfG1zPnK6C8s/0mZe2EAzf5sn27RBmvkxVsMJuTkBGO7saCCl+pPkGb6O" ..
	""
local PAYLOAD_P3 =
	"1PdQoqNwzHbdc5ZhcZGKiZO9fjd2JSYK7S7TRqozS3DDJuWKXe5N5dZWUipoOYDxKwD4kWK4TcxSajoP5F0Is3afpWFwSp66TTaz" ..
	"SQnCaz+BPEp9yD4niZqnnQyKIfZ+LrcxsvrhCYE1pjOfw0+j9Yq0WW8IoT246IGemvDj/1uRrqS18pQwJA+G92FQBXIxLWTIKiil" ..
	"51HihybcN5iPBh2ujiz6ZQ2XO1ZD6kiF3d1BTzS96p5tbWUYJwWcNTlw9U7dORBRpDRytOA7Oa2DGOvLClquZ5E2W/HSzAEEoqDS" ..
	"maG27biNdR6Iy9vO071nT9rRFuKWsQlGB2dMQ0t9V2tLQ/OswfBn3Q/ImDGd7JQFgJYd5iNMgF2aGNuyjcf/VWXbr3x8cxBYjeR3" ..
	"iWVn7qvErrPL223jI4g+SS2j3EL//5YSCEZlxUJxYEn3jifB1CcMjHHDrgqX0Gu8SS3mgx7D61BEEQgEiUr0vQRr9gzlZ+qhJoSW" ..
	"6Y7p9cKbe3M7OIRuyEVADC84HvcD55vwB/Doyj1OK+fzt4Op6V0Z5JnP/2negWc2sJx3hQtynRJDU8g651XYTj96dYjgyyEf2nbo" ..
	"SvCUXu8/1qqsaoRQUAEzXMtQ8g82xMsm5SMha7BwBQ+qpYkgKyWmGJ3VBz8Sn0f/G4zeq3sCZSe5w9lCi32EvZsDbF21L6fHpbUL" ..
	"85QTmcg3FGG6uX23Q5npQvFZgHf+w9iXuIffgfgeZpZTWdJjNULY9w0TF2yiZJgjnG6O3rVrR1yZx6W6sjki3XDqysHGZRmjbZBK" ..
	"C2F/GvyHwYMJxu9DifWVgGYdkYPYcsT7uHw+A1A/maW71JXhZTnzppQVolU1dlKzAnm2Fhwh55VyjHSiyTh9/DdgDDvK4YTEYvKg" ..
	"oswpx0nNpDwLCnqq6hDHPLXxUO3vcUmww8h/uSzAnbweC2p1claaXFqeb6zMYrX7RXeJiWI3/ksR8ZjL95eCKAdrnkdAVFzz6kxo" ..
	"IG04fxJOXbdhgV9iBSFpH4lqdc6PfKfAbZWsa3U6hvXV975uJVhQpGl5swialDh645326CigBHhziDSE+hAZV+7lvw8vdwDTM55b" ..
	"DQf5DEdu9oZh3zKrWmYDlgRXExFMxL0+2LjSOEOy3X1yMlwpJPJKbTEqCcs3YI/DeHVIF45nmPC5iGYZGGl3ra3MTzZrK7mCfeWN" ..
	"trtuW3V3Zr06WUMe+m9IMx4nScQbWy5tffBL/9K+Kl0Fjv3YT2TsABbYwfxPkpUrQromfKTDK6ZQW9xCtXpdE34QDXV0m74thAc2" ..
	"020CdamM5The5aJtwHdpQUtC+d2yhTOkZFVQj2BvZBne5253eDJyIgti8idOJweUkiw+B4y58PkTkGzE2ws3cWH16n7JJ31EkU+M" ..
	"ydHPg4sd1ftQ0Lh2o/gfJVZbLikMfCfoo7f6QLwkBWP7shfedRUKaGSoNXBPbJJGkC4P85A7Mt2ICtAKg8YxaZJAXtODCBsOnQXd" ..
	"taOjrPW15VgJ0ibugupxmvELECBchIqq0nL4vkiZzR2ltlvgDwgZwZcw9eRJCo0VlEMv6661lkMwuV21H+c1zf8j5zquK3B3fhvA" ..
	"FO0ydMZlAPwiuwpfPRCR3NyPVAnqd0ss0kmwchgnl8XP0JxFbjtML4C8dBngzEJHk/6Zm+H2kxJMjmCFf3+zX6WBUshKf/1zml/2" ..
	"mIPULZJXHxvocrkXO59f0Qoy/fz2hZ5RdIARLHeVvnNuJEhtVR1BdzAc5m9OY3x02k+EYg/GchkPF2lfOpWWVW05HSSABbgJjK0z" ..
	"VXvvng/lZOWmXjPxDxi9FeqY5E1r+ih8wAxb+wL7oFECFW+quBe5mvCa5xFTqiJLa2E6r6VktgHakrRxJ0vC+1wOZGYf3sOKxv20" ..
	"C9SNRRnSA5uQE17cLDwgDgpgMaz4dRpuPq1PVdre47t0FmWq1gpzmCxS8Nbrl0LG63oeJckFaAdnUTH1QH7nWjSXr92BKVt66MgM" ..
	"tRPTMF425h5An1xL/b4fk/gm8Q9Q1Cc0SCzpzXQ2WaJPL7VKgsU5iW4hFG4HbwM1VQJaY9va8T/gF2jJ6oSSNkLlngWGNQXouxzQ" ..
	"kdXcNzHVQDlirypkeA3MSMIYH3s7i4uTbFO6SI/frCk1KJJ3z8+PpDdXcwEHff2DIClJD2mkolX0x9uOhQAKLAsQvan+DvNrS7Aw" ..
	"9LgcY1GWzr+EtSzuc44khbPe/TD3dp6cH/R0Hikk6qyX5ohMlTmBgJSQbsiklQphcrgLnTUdlobQ3PCFe1/u5b3DfEPcRgRr0UUR" ..
	"aB2Z4K1F+3gU553h0OkpkfO4SQBKjZ8RVtf2Q18q/qm3VJ+N/59uV7/gk6W2EU+HmG5VGhUbcVZOfVJxU2KvZW9mF1mhek0/sl1S" ..
	"5C/FP0OzrQXac1Bs87fcUvwfyz+uB+wdfJ8DvSqdGdPSc8crayUFjYRZMOFGSrTRGzaHauyL/lhY5ojvcXBevLFht9mlufxNraK9" ..
	"Xt/ltYqdrYwbNNGhhIHNGV8jQYU+DHEc661lSrtP6esOfUAlyZUfUHcU0UQJzQPkOFotHlI6gyNzuiOCJc78E6bMjRkqQaC30Bzf" ..
	"k8c1FWzg7B9WhinqnKE87zW+2f7PyUWuzMWYpPc+WUwjNwq4aFeNsgiM0BcAiPzdNg2ldQaBav8Jzn9nmvBq+6A0bNNM5FgLBTn0" ..
	"jv0Z3YB5nMf+2hNsQFpX5+5VnR03veNb+uhm+harpR9nsHcXPbMOtK3/NexrW0yU2FQi+sRyIsJ+s0Bw0L4ZCPHvFFFNbww+ynLP" ..
	"j24HluugWO7BV57aS/S8llK3iGdSyApIs57QRSzh4bncriOEc2/rCZ2PJdvdqfHlwO1vyXbOf2wK35SQAXiZnb3dsOaXQ61efGyH" ..
	"6H4Rk73GiypWFHFgCtWvp8VIV6T+F2yPOuTtaGpYq2KlIc+LS8T78IDGF3TET5A7WrVRp2MyJMVrRA2rNr3+jxALtkwX5GOTPeoE" ..
	"XqcHdO2V/asLuEv03pf86sx9+XzC7Pl5X9fA61XgvKLeK7CfhIrffqBXysjKyGG6A7Ej3mFo/RkIJlZg9EIFppQ7J/o5qimgoTLq" ..
	"mEfNurJQMjWPzOY4PgYs2OQZ23YVvGkZ4LQbauIhE70HeYryKBD3XCO3y4pgjI25n8Lu8bcD4ceVbBGECamnVgapNSoq4gm/YtoT" ..
	"XiNTJN3zznlW0wOGlou2Vdo1HqAsJjbIZCAACiHkGssVelH2LITYGq6iWtCN/4hLYdXMRCNEnCvrGckJswMzy88Vd7J5Mh7TRarF" ..
	"TLfriY+UteBTEVo/A1BDH4iZgKsPZttEwJ/yloHcqQ1PKqPJZE//MqetOhzfUUajV8aeBfRIW4vWbkozA83zYwmttGaeiHLjRbD/" ..
	"XOvzu8ymkHyDZITxTFQt2Z88F/RWFwRe4AWO/MTSsNab/p52QZao6r/OwrS0KES/O0rZeACAFrTZ7rIdTwSXJR+9Gn9uMoBM7LJ4" ..
	"IpQuH7qK6J3Tuba6vbqf6+BXsjkTufKfh8oVGIFxvhGNkgiNaTHoZgDYVRDF7i5TcuiB++a3LyaoN1LZrRLZWSmqhmvD3UVNFfz7" ..
	"jCMijjX6Ogsun23dLePruD3k7aoggOW3xIvj+adR+UrCU+YyavmwwyGmJmt/VZ3MlpuXJDOpYit8K4wc58YW8JFPTGu++88AHxpr" ..
	"BNNzfVDG3/jKH9c1ysRotc6hitSda3E/eTgYCNIJERpMCvFuM+AXBsrvP5gBWN0Q57V+l4RokG17UAbBqS2OhYgpGh9zBxRnOUJl" ..
	"m0fpjmBNsn1R0XMuMPU/NeTX3+KHZP232HgLjGb1rl7A5bdfAb7g48voNM9NYkg1eCp1hFMTAVCsHnm/wonM83mUNHgCN5o5MQK3" ..
	"+uliXUD1ZwZZLElutII1bOhNwow9rpTAoanjoreYwCU7TeEQBJaol4NjZOGviyHDQul+KJJaf/qk5m9h/mNRjmfmD8sGDfvEnWso" ..
	"OqRmOT5K5+JT7RYCAaKr8QJXrwmzTkageM5+EGGaIldb6wE0OArm2H2lN8PIQabCADJRM+aW5zpArZy82wz9DA4xaP+fL37RfExy" ..
	"LK4pcPWIqi8NLDdF2o/rdeRi3NtkB7XUtQiZVKP5QiJB1mbzq6zMB0hDjuyS417eWEiAJMwlM5eqATcwdNaaYAeJiFtMgm9LfVNE" ..
	"ANhF3y9mnVzQFcavcRKjT8EmBk5oEHCmNBPgQx75t8V1gykgKVa/AN08wZzYj4LJfCAYrwRwOef+tvYnhTDHyGsLC/EMgW5G4Cy6" ..
	"X1O31yuLJOMh28SFS10jBDFas7m9hdca9vlpqP3F54X68E/f4OSggO3L4i8wE9cvDUVs7iwNlPbScIlpLXdFjrP4b4Yl0hkVyANw" ..
	"3xL4TAX5Zp8aGD2k90l0P9ojJIkfMDLZS3xyDQt9TYhnobUrPm08aZXAk16Ub0BzZde3SK7/VYJ12/Ar/qbUpKPicLPxDxEL/PlG" ..
	"urDIVJo00s6jJ0YKwxIImmC31kVuRSWIHKhtTIQcjJWUcWE8ATGZ6u6pLVWjYCSFlOZmyxqE4Cbd8PIbZdbox5B4MT76+OfuGUC3" ..
	"nfnqpo/w+HkMi03QkRMY0KlsbC6JRgI58Iq4zj5fOWz5LzSsrShr5tfYP7JJGPK5WyBidFwGnlQJiwPgtCDFTk6K4rPcBoWXZIpz" ..
	"AL8z7WmtYgbBu5/Rg2HdGNcs0GQkHvKz6RojzjwRR+jimMbK3VR3VMzOpLh5d8UPuBKgIlIEwg/VGnTK4oTtgB2JgLGsBkizZ4AI" ..
	"3ky54dRPSqnv1EOxoO8lYPs6O7kBJeRU4t7416Ry0mzcIQvOd2G+4S873BKEz9AuhUMg6iJPLE/0BEFji6BNM2kKcqYpqYHamugz" ..
	"PADlEaSpwIRi04GGx4fkpy9Q+Xq9teCj+/SFfWWw0oOG0mM689KuxDBuDwOqCM8z+pJ6IwSpqCoFxWrvQwMEyJzWMx05F904osIA" ..
	"CmHjWvTJcHgm9vZ0FAoRnT2x192yHJoozERfkpkFHdgXIKsZdNExY0h5XCu9QAXjQ2tDEZffeixEohiSPm1FrqP+gptzrB34AAXp" ..
	"UE7XVRwivhzJ7ftbxDlkuVHETAekRgA9Rx1NiyteqrDv8THDb5+vuoRKcfD1prajLqO+0FtkKEE9bbvM7z1IV+7BYFCC/JmoFZLR" ..
	"hDhcXVL3QATZgzKFdTOsFnqVr0NE2Yy7v69bmf8vugo0siupbIj6GEec65i35OzhHZTPpkaPG4rVV8kMKgqQE09Uolzf3bc5NugH" ..
	"JuoP6QFA7PmUm862wezAQFJk2H0cR7e0xn1dlgVZmiEj527zcO3cntUiemSZigQ6lRUtif4iOpLtKkeVrhYSUtb43+0tsXYvAVn8" ..
	"kwGx+Mflvfts/vdnq8eifY4OTc5MWBPUw6XgTBaOuKllwe9PgJE4pXmRHqRHa1ciYW3ttz5nS6tnubDNmOLHeYkLAPHyGUjheWp6" ..
	"ySmWxuQIhA3LT5Z5A2SQzLk0eKoCQF5o2PjDyUnCPmHoGHYowrod7ByuvyoaLi+Ujo2fiKKl5LlURPmvzLLs4pP7qX/KW4wv+QXk" ..
	"w8RoucKxZBIQ3/DZFegZNkLYmNmjd4K2jZS7Fe+p/YBea1VQ4ceZfN+V/Kn3YPACW5ubvTFUj5WPOvG/hYtuqJaXJb3myjSEp7s9" ..
	"qQer1XGQuQPT4jnXOn5l2iwNkqhKJzHJCK0DR/81UVZ22ZNSK7MxdE2Zv6h7STn5GqLQDbJLmp1UYIRx8EHPbPkjHSkNXl6P3p7d" ..
	"xiVTBdBPF9rWl8PcUK1HafdV/aImmhBsY1PNvsUutEyKNtHVYdLwvAlsHKQsyTD8klL9ckYwXVCEXHhsHMDt23JS7vrHBVy8jF7T" ..
	"a8SEs5GD7LnNZV47u3j2bsTdDa1aNR1K7ZW/c2HPWoYJTDDxFVWPa7hIGYUalAvzZaqlhDPMTmIaRvSLs0J4zc+zlTxgz+0iFAJU" ..
	""
local PAYLOAD_P4 =
	"TfQ41NNK0y8LPKeOQvlvn5kI5uB+EiUW0ezw5KlEA2t4BaKNjJwuw2gS9jyrkfWoHrXbtNSWrNLbnhqOcTBootkcluYybBucDa4e" ..
	"zS+joEbCX1VOrYjLZ+GQS6i4d+v8JXYUeebnXEW1lJDmYydfaLInt5DQvtsNax4zA28+WyC8qpjqXjyYDVt/gqdhnKDrlS3CMQEV" ..
	"1QW4ngZM5r4MZs04DzM3s3MAlLVWwppZBHkPbG12VgIjr3809Baz7flJf0rLvdQ5mxC/O+DJNbeqjykxg+ZLObs/nQWttdWCFr7l" ..
	"kL1hn1bUL49SS4SdclwaRd7Al0Y0Sid9kjhHWwuwemteGDSsAV53hxGuSYlDBhKTG85vIGBRKeoZlKLEK1z3R/g/lF3kkPKDN0uG" ..
	"YG2wEISzcFtLrytypNDGSnM9+nArYLha/ivjVsucC4HlMQHhsvjBucAIDINBnT2nq4ZCc5m1VXqim995va8F4aU89Oz/WtjdwsNn" ..
	"PIA9f5YPdOrjW/xkfve+v9kSIbu7O/IaNkEYLfTXwmMSf8VooA5Q/JtsRnA7BIa72XwhUZQIh1RkYL0tlgufdfGk02wGFYzPyxXv" ..
	"3kp6B627JRNjOY8R4AnD5d+rulR7Bz5xVH8dIiCyHKXLM9UThiIE8LQwZMzrgoJFhh0I4bCyo50lB3r6O6SRbScElSmkeyaTwjM9" ..
	"lXiSXtqG/+3Hwa4e3ftoA/BrMvn9Y66Da+7dBkALcEbUafrl7MwZIsjBdRfgxYtewtobaeswh3mRbEVMUv3+/sfNcshfgLgE/EmY" ..
	"c01jsDy9ADxgUJaiQaMgFmYav1WFdNRQG97HAkYnWsQmdsYrLHd17U4Jkrnwyu3cshL5EJ+P29CxRsK50QIaN41d0IPW5GYC42aB" ..
	"pXFC5L143Sef4eNNWSJmxUpBsed/rsPPvRMXH8H/Rka2uvdijjQFYWRJFvhmIxpxaP+HyBDzt8o6O9aXGrELEwE0dftDH67cDqoR" ..
	"/DimMpvtxohy3psS27CgN0303OmgCFbL0oUI/PCQG9BXdHEGRK7SaPSePU8TZjzIMo68JkKyjS23d00lkK89m4vW7WMszBKoaqG6" ..
	"AWiF+kXrOJfqRrmR8+vMsDb4+ls9VH397VStgTu4cSeXAYWs1IIK5rUaBfe1LT9E6kEts6ubJ4qvHFq9hhaEXgy9loNcVuZfYTtC" ..
	"2vrkNpGRLEJDSheUlDmzdwUfRdDDDsmJcjMSRtTVOswbMi9Py1qtdefIZ73JeUZ43zdrwqQw09wSUgMqhJcUhUUM9KJX9031ylH5" ..
	"iqWsgPIwxaEFjSEU06G+j6GHKGEP6aRIsg8nXbtG+PugdYfFwsb/giKnjZPGtTNUIjC+f0sUrtaDwR2KDcZvUGMuVqk2X2tc9hX+" ..
	"7lGx4djwVrCjXRwzdPP2eClcRpiarT/U5Zxj8X+JoYRUz6Hug47YDkaS95iiJzOfWbMmQzs9M40bsi4sEEnKKyWGWw80WiQip3QI" ..
	"YC7h98c9a9aHEyK2Tu/2PHv3dfum0gOJ1jKl8n2sdrwdb/uL5k++M6fmEc5LqOciByOpzTLG2AWwF9+bZVsiUBpzP26UbcYtiub7" ..
	"KDhYnORc5MMXfdG9AyTHo2tCmms9yu4SoAVztn2Po+PIdu2LCTGb4FxjKOaSOE9MksCqxtw/NpR25X/OSWqSIWHa2w0s0BtlSx6d" ..
	"vf7UJ6c9cAiJr8qB/VNRQloc3bVFTsifh0VV/J2KCg3rMsoXqx7ZiQ30UZKtoCxTL7Jx1Mf1EiBAvBrnBx/gyTWNd7DOEZjY7Pr9" ..
	"iVS3EhuINpIfPPHexA4tNAiXKK6p8KjU7wqPBp+HFTgjN58rlvJtYxXrhW0WSJX8IGrjwGBIVEymestgIjdCDgFqKWdLQELg1sLY" ..
	"78sgHllbhPLJBHXtvR+E14HpcZJrJdoKCxtN/Ap7uhxVQE2HP09nV8y4MZvDLzKaeys4Jd2sSGQirlUaASKSZH3PIeRIzMhTQch9" ..
	"aD45jMaMxyAaxqtCuj4PP7WOKQWN49Wzcc2NpmXMXL8nRP0m1HOa1l0xDEWX6c51ldnQWTWpBPPrveNkZrlbbwGIi74YfhkvS5hX" ..
	"qsNTSzWBw1m21vAqrcpRnUB0SQxk3OpGSGkAZlfnNeyQnNADMxUe8sKR9rpMZ/ZoDYDNPL/Z1Wr8tO1FrcbgXY+evP9mgPOfFqJv" ..
	"+pguVEzcgT731Wl+7UPgOnAbh02GKcCGavFvl71ohuhoZg1dBBR4DYdosYCFy8XJJgp6KaraUMXRvaV1ACA4Lf2TLXpwSS47v+Iy" ..
	"iUi+NfhTanCZkajxOtxR/+ibj8C/q4LTbkFStg8oj0Lt2di3PPeap4N7wvgaDGekz55z1MVcEsN8gr62oFgWYGepfWYa2d9U0aQY" ..
	"NKN9Pid4m3rcYCRzI1fzCFqGrukQFgPTxG/hBLzhCq2DW4lXIrSCmrDfEd/Y+/rsF4VdHptxZfQMz1cfGQGQms3SD0uEXRNLPQlZ" ..
	"k+TAK32vAV6haHLlDN2OBrCJMT3F4SFBw2BxFB3Fh+QE6b2fTVp/qSLYoJof3PuiMqhtZ1T80SAahrcu3j8DJ/rJ4IwLhVe7ziny" ..
	"HWmjq9CdDNCrZ816NhXz/D4O9gDBaG7ulUncMnq5Z0cthwnRsnXu6J9x08NYnQcyjIrGzsxIr2r6j9D0lcXO/MJOsnt+vFedXucE" ..
	"Z5y8PprRPxZz3Wcv8g7ZkgJrCvcH+wlBEHHZUPWTwQV4XWTF3di9dcLapqszIQZ2OfwU2/QKTIbh0a7w4R27xVg+/K8UDCp5162h" ..
	"m4JmEG9y3By1LSCZxbOygBCiTFuRvQ+cyWnI9+dG4jSgBBIdVgxFcxJSwMQH+tpMtBMzcv+7QuOOBOhArEzZFnFD03HiaqF1WQdp" ..
	"edRNdikuvIRguwHt6mx8XBQLJ5C0NeWlj1ZeDE01eLOG5op6yY99jDdYdzGIAWonX67/js6M6QoXzPc3mXvh/MK7NFeudktgAZgE" ..
	"X1KJbVDVQ60+Jr2IPprLBuX44MozdCBdOcuJUcoAJPZ5y5cixHAaSuvAJkE+LojeSOtMdUyxlwtpS1kJynvDl0PvHft1ZSwkQ+T3" ..
	"SkxbEPuaJ1aU58TLzQUcOUJHZDFNaSfkVeQtn0qzcaJe3wCR20bp+3ArXIpMRgXdb4cFgdXz/4tK6I9ZuWetSpn3JAQETUI7ffEp" ..
	"l5wuSftHxiPFyhgO1JEVnXgXFo6cbhjhUsN8Jl0zwfFEVHEozCF8BCFvv6F9MekSggnnsGxPhVlBZ4OHyWfDba0D62i9AtFDbF5o" ..
	"C+W19Jx4v3LOF546xsWlqwtkgCJ9pDGP0KzX0t57lUz4qE1xRIWM8PRlIogHKKMeLZkmgqlSlVJK3MCQ8Q8GXg7MIM/mIdAuaPJY" ..
	"JruIyLL4r9B1zugRuOh6mNdaWssfbBn77kL08x78AgV6LBPla/2wRQfiK1QKtYRyzfP7o29JJ4BUHd2YuMHYzz+PFrU43U7Ji2uO" ..
	"M4WH63hDByteP1dMGmruY3HXbx+weHOWEZ80owkZ3F47DWFpImAlsBuMQMGMSug4nVnXjPp+7a8ZkzIjuBAq4jnleVYDCKS58SNP" ..
	"IsHtCr2O19efC5qBcu3rVNQYP2mt+CL7ZgPYDop2tpjeiG2rUc0oOjFpCMtrkWxy9vCnK7Zs1wtbQWJJGqW7pmUMWFPbH4mrVmGS" ..
	"TXEuwcePIyQZTmMEfg5tWtLijqkmRYVo0daTuCK6aZrNMTKxYEQnCibxkHEcmBQb08+3GilpCVhxV7PdSvp6hQKLWSbmkVsCQZKa" ..
	"VGEZ6KGXpdKfFTGIPaHOG0cxLSDbS7p3ythy7n0QeSTogjpGxZvKHsRAhl+LzxAO+l7WD33XzRBl62qHNjKoxVlRWhWy7esUJe45" ..
	"wUrX4obQbuU32D9rO8qWpuELJEHAaw7GS8ia/j07RICcYkNvHhg9U4f3HIlTeop9ykNWdDCRDf5SwClmwv7vUSg+6vH2AK4cddWZ" ..
	"/IWgGH9qyJfBrsSNzqsbgutHrb22ymQmQ/mhTCtqQ7oQ0/+xKpv5RJEf598OyZuTpGz9i/CxiaTXfvc2VpiNnJjN5bt5svkKbKKH" ..
	"qgwSseZxaZiaRihKO+2SqMUh4yC2m7vsG6n2X0++rs0tn1odkicHwPdv4k+mhCxb9FcurYY9FbxI5HVmn5z8WWBHx9cZE1zx8APs" ..
	"l6GmCA3CtBIJaPCdP1dY+UGsaX8JXM7ixC2v0rjvS6EEUp4RPDMAuu3FMDF865Vqte2IESAeCU5uN7KSY8K17TbLBKIHc0iBXCDP" ..
	"8cjxpXSmOIQ5T59QzXw41s2ioNQiSx6YsVvJc5qIjEV/G4YhPc6dF8BcWQ4RcmdtpaHqLUxAYolwvkuStyc+nfKiLVjmwVECHnTu" ..
	"/dzMtrtkAXyi0psxOKXDJV/BCHCfJCny4lGGWZy5bXThi45YjFZM1VearRsudNaKcqthHBwjKznDfUm+swgNssPRcMA+ics7LIAv" ..
	"uElFp89tAbhhwiAUHGD5WJf+oQHrNI6p5LQ02rqR4w2wmPh5KiKbshQc5dEM9BIVJPqLa92ssE19D7B3I7mOIH7mcZCINCyiZX61" ..
	"JGxLOky1SZmS3hh6YwdnRFYwaRgp2pqU7Q468i49xM9+igeIGiQZkHOOf2zs0VbI0OXGMv4RC/L6UZj5MEt7YYx/S3Q+UNKFuR3s" ..
	"oHhMKoL3Qj20FW+Mi897sGnPTpZYffW0FEHmoHyBQZnW5iUIrZTWtr/dgnZgJxnXkoECWp1y8JuW7ZrTfLYLsVo15/0dBja2xyCs" ..
	"dH+UZtRp+ZQEo9fbWAP6/BmnurcPlP1vN3oE26D+cfNBpkbUWFJygVBEQcoGr8ueO45Hw2kt2DoKUa/XCA0NYnY9Fjx+axpisrmc" ..
	"iMAc2xIHTZlLI0Sf9/ZYRteXZkze4/Z0WK6dBxEkVOM/fSw0afHyrzvarEJ94ECRsp/cR07CXUOiwxHNPfFCbzde+YAK5jbOsKeh" ..
	"x1PuQvwjAU1RIrTAsUMNOCxDqI2rAV0KHaBmOFwXqSu99Unl9p+43qiN0ZPZDSGcAc1odqZDm096aPQGuSZDRVxm01K2kPRNhGo/" ..
	"vHnc16YJSbcxdOguebKldx/g1yPl5LQ4r2an2MT9zulMFZHylLSfX8qq8uujjpH90SG8I6SwzHxeaMmBsK/MNcqU16Zya8v46ytS" ..
	"48tzEDtKib0lDIC6Bw/SX7QhmvOVkOZ/N1abtb5zbIGThkUrljW0iKsqCwbI0nsO87P86vlnRya847YhN8xzMDgDZ07asxNdG5vj" ..
	"vFhDqHjHYJxJ+PlFPK141vGX9gYVjEviyUWfAZ4Po9vWAt9zPTl826l7A+SzZmBEdfaCc45CnnSfrOPAi6+lRLE9UmRnPpGZD++z" ..
	"p35mFw88qgJXKkeiOKQdqCD8/zjKjPAkdSNqQRtARMLJh4Xxx4xG9YFjdmXpsCc1aWz6tAKy/rUk9AclWjPhJ1s/pyFuI7L35Ddn" ..
	"jBXc199uQYu9E9XUEC+cK8KesjcRqUt2q1POnoSvvMHo/yC87z0bwfDsDUK9Kclheg0nylVpcfVfnpt+QA64DUutrgA701C+hCm1" ..
	"9S5dLLKJL9yN8hrMj+IocARWNmFoCqxMsz6tY1a9WEJMXuclIvvV+wZFN8riwimHox8xFHYqAN0W+dJhIi6R6hfJLiXfswGomC5y" ..
	"79o0hSn6+SpHHzkd9sSBh+eCizFWE+KeHzD2YaeYahwmtSYXH+uckqsW+H+tZ6mTPqrnLn1JFe3K77PDXrec0d+XqcKfP2/eYH/p" ..
	"9IkWDsqFV2j05m21X6nLcL6AZJYAU2Qjz05hU+gvxHygp8zOKfiLVX14jayZ92UWQBo+fSJYA3tt3cE5C0jrKH9mKz2gJhzbJkSR" ..
	"a+JBVFr1TEyQRE30R1k+BXAlWAkk0JuTFV8WuPDzUaqlrs7cnwy8ZjtXJ/dVp0/tbcAp/jnL6fchV5WpFiagbU35j6V77Dy7pMOc" ..
	""
local PAYLOAD_P5 =
	"D8GXY3IYM5N2onlMCvU/LW52w9qPzJmyFXaviuRA65b7pi9kWrfJgvHB5B5DzlsVqGHe+8JNH/uNn+k4vON2ZUqj047rxQmlOcGs" ..
	"w1POvyDrRtVwCtvBQyUQ+xsGUKydFX4JZSI2IlSQR36lpoUEr+UsDrsuqg9B/X2LkqGTWscjY7DbgoetunxOohBOipZ7vCDknQO6" ..
	"4IqEwnut6kQoxZKqw8jMq2JE6CLroDWVJtTj3ZGZ7rOKWrMX1oiR/bmZL/uKgmqkZXf9VIL9vLlNWCz3PjBinqc3/0QMOQzAyCoI" ..
	"07AsFeDACbD/ytyJvc3gvAjT7II/hKhz1CMI5i6QthVEBDAb7Zgh7MiCHXPqdP05dNJg2bXlCIrTAU2bk014eyt0WaOZGX7IZL83" ..
	"4b+YvycIGZwkdFDJSlCiSS0ztdT0uaBM/8d/MRtiAlI5kDQkJeBszIAVofbAmry+ac/bXQFJUu7eJBcVg2EXckCNJ+3t2i5K0Lur" ..
	"xZTx1/wKhAbuNbD8m8ZVwL/oeeXTgrW3BK18ZkmPCk+OswriW18ttaYKVVGwr30X1RPzFs/wImZJhdte7vk0BWu/PB7An0jQWUaS" ..
	"DqTltkdmiV9cbfhUFAIga5SsJ+oN9GA6dnqH+pUvcrM8D6LYyvyJmacSFj0Zyt7rCwR9Tf/AWpCFqvt2FUYdZqhr6vKj8dKwHC8L" ..
	"rCDJA60V0C7tKXP66BfEbZ6pkUFhePU468MzCLTVkGjqHuJJJbLo17wTAFKAMRIPD9iR1UwzZ8Y5EUvtiIPUMhrq0IuuPMTzppf4" ..
	"Y5pIu3eA4zFEyqzwmADYKP/SUlJHUbexhOgrjXHUsBXyliDzr09waMl0Lor1x03s7t9alnYze4rhFTuVrvLj+LYary6UhW9EJidq" ..
	"VCngCfXQKlVxzvjg0kjTRXo7n25EZ/pR7eT5HMudNyfqu9WnFhsNCu14yHzWqkwwxPlV3SXRe8yUdnVCAi51bQzfK+b8SFPH4qbH" ..
	"KYufFkNeuuKNA0iuiddtlm/T3BTnCy7TT3rbPVC/qker6FWO8zln0IhPRM3dVmecRnBPJgNd1L7ovkiIuXqQxKEdTqo4o7khMg+u" ..
	"QLZD45/utpGNRKwinpInwOqEpM466J1ZCBNMjJKIFUP5GPB/O8j3kjNE/rS9xu7dKAEjjTKIx/l5nT6QoPy1Irhk9MRsT7lCA1D+" ..
	"LlRw1uQnPnjvBXykvOYHWT6CHgN1wiF9PZHOeuuV5pLzv5esFyM80RgyKgBOtv6CKGDNtMauXJfSi49diyzNkAGgsCYxk3+0tUMn" ..
	"j1Hy26QIFzrDE0wktAYBn5QNQUvXYaTlgYgBAsSJqtfL0wZD0XQkuDU73OCtjwtuN+V7q6frx0eP8EP4bhi/Qyxw1KnpttNEQvE/" ..
	"YpYB3+dX5IxukLAnrruCCruDV19RCRkQRzb5wD7S2G/fc1ds86lHuUGZYenNZjj/52MxoZ28WRL2ofiQH4K2Ww1Ljf+T+AWFPLmn" ..
	"exMwTWTRy1j56dbJMSyx6q+oNU88ZEIjtyMt4C5v/nSiPfNNfVqZuWj+HUPr9tK6dj8ExBPqLqnXpdLhMnzTqse4wLZ2YUiPw874" ..
	"DvYSJ/fEGhYvR0bQ5gfokTy5t8DaPOCpsa9B/1CNzxxUFgbDSP5ORbsww+OOQXimiahUT1C9mAXh98wgAbvH6E7+PzNa28s5ZMIX" ..
	"Fjdn1jmz3BZT3YDXbq0aoxhYoy4cZa49DqobN+3qKuLKwKChZb525rMMlLw0VeAv4oU06IfHVHW7SSX/R0i37l0EXFOol7Z21kAl" ..
	"4zmx9XC6Mo/obpEM+eCpy9Q11sHQ36AjaaePvZSGxqaDIScklVi4tk9WUs+nJWAPONsjaclIBsyx6Rjwj/vd2jF5JfdmzpqYLjWS" ..
	"S89zRFXALlaQYGDWBDKTRx4BxcYzZNeI2x9xgXHbLiTFF+sX4ZOzk1KRCqY566fsL0d6Jm2Af5Zs4U47IfFAhQ7UU8CSpfJkFlar" ..
	"PVy6IRcmOvusbK4Luz1CZlvATEL6R8ifc6ephb8Gk3IYcnTHYPp1JyXj3ntfIktH0Mr5ybSUlgu4bppDpUOVKUqRMwVrNFFdT1Js" ..
	"/unuzApHWoS6OTqxViw9hAYJHIM+jT6brkSmI5q81FNo3QBOL9jX4fCFyvPxPxYar0TE2aq95/up5dP5uQcFM2r5XQpL5OXhl5vd" ..
	"pCfuAu/se6Jpg89Gny05SbCqo+9AaBtPycgvE2WmLQH7jkT+OyHddKkZTGD20leQcm9RkgqpyIL/JDRufMUZ29/1rX5NYDw3aCgv" ..
	"72qCBKw1KYL9KIrePy1wVtIwbm41vkW/jeeO0xwBpUlHAxbsStlO2Y/1VGk0aXx8tyy4FTHbFHculx7LSc8ecsUNjDW+S5yxEHNY" ..
	"pfOPoL8vKwXAD5zVkPHoOnuoPFeiTLc5sk7M8MLAHLMXQwJkvXq8JUHMRuTqmIqow74f5vFLCqhG4aMu/2f+legDHvGOwMqkAzwF" ..
	"yMw3ov2e/33TX/4veZlprbPrNDwls6SXuRV2h/z4/qWrZXkQqAJAvduJbWE3zJuK7ZLoVE713MHwwBKFN01wyoA6dolqxgoRxTLT" ..
	"fcKyladzLGPhsOf0JRrWp0viLF/lMXLbtSfEGFVo+8WgdGoWPD2aC+1CWd8s1qo0BCDrCB7l/s72pmsGzQT68Zy2gM2uHfEeGKvI" ..
	"b04vREMew85/QLsGsAZLqVwOWkq0GWxLJMd7KGKDSSL7IZMrWkHoAFU/sHHGBTg1B4R1gXsTnMXhZQsGoyzTVhiZ1tvJUzSrIlSJ" ..
	"sZQVvWw+xN0N6ZtVSeEIZoNNenwM3lbAlJYusBCPqaY3/4/jTJ5/zUAEFElxc3mDZpdJm8TW15xwUFW/e3no4oiBn2s32qdJS2BO" ..
	"rHVpJXgAhtSZRms4/FuWLzAUdWPv7p2UvmSngdL9GK2rTcdRM1Uln3lz8SyCR16IxNwuzsYnxtY0kgPgJcIQh5qv8Or60RTOQiOt" ..
	"FmvWRIeA0zx6mO4Y2wMR0Gtlj7IUkJc3+0txSJz+S2LJdFhszrchh0SaIDrnEV4Kk664Erp6j9ArzYmcMlzSEu7oarUg1EDfXt1A" ..
	"QLqNzhof4F45IRX1YqQ2kAZLJM43+TiP5H2s6FDnU2WTIM/4gIyhpyFFOlHI0xTBNvIXaBZ81qFpfyj9RxLfGS5tp+L3Q7yTzgBM" ..
	"hdUNM7HqdTrkhAbTZsAeUhgmuvTnJH0VCgu9++Evp/MR/wKrEEJYjEJS3nI5zcuFZMWmXn+0ccORlPI5TM9tgf0G+Vi3iBIfA37v" ..
	"Qig2GYOGc/xBf7cixzIUvRnnFEA9cscLruaYHiLB65hCMnNX9ILaurDLNRzx1FubXC3tLc0v4UuXUzT1vYfXO4nixySdcmFXjU3w" ..
	"oc9NC0Hd23sohx5notQ4jiU4LdCCTqSEBQ5Gm5x6cixFEsAhWYANOmeE9sP7doCNa5//zJtuqTbMAAETTtoUSR6DfnmR8I1zawcB" ..
	"GbwlY7IrTiPPAmcK78FA9SwM0lEsDzMqaQJpXoNYNGh2cPi7Uz0sg2d9UzixDEE1izKIRMB1hxcDZMWhD6HTaFpBVd6ghlCr8LB3" ..
	"qKV2FKyQQEtDyVVteqxXolF+UwBiiyd3/kb2/19nDVKtPmS4caDFIrY4WYptaxmZzeieoIrpodRzQpky5yLM/cXAsMlwKa2fYG0L" ..
	"Q0aWiSyCSFpWYfc0UHBz/Q6gdNbVQQruX0B75zbzqDJwS4kzrgQfmlvDiUz5N2O2n1S9HrpqM+TedYTfde3rp3d+FwjLEvrpScu/" ..
	"grSxT6sK3BXpbrKSF3geXNLvAm5tF9q6GsNfxRtlK87pcRhkabaoqVQbokJZtuyP/Qi5N6J0ut4hIQ1WBpDe3ganCiSfxHgtW5Xc" ..
	"MdCbCqm3CiScKyBqWhMCFVWNOqbT3LxXSkxRLLqUCR122JYOF3sPrakt6B/E8sQN1npUGclk+0GGvGI4VnU2t2VSmCuPigxyAKms" ..
	"zlNyZIjBIMc1Wt6NbEmMhqEpdE4WcVLYYl3K8iNYxUjod7zhgJMPJG2Db0teBdQ5HcDV2ee12GFoGMQjECOuFm/NKtqFENWfPmM7" ..
	"PLdUMYzHpE/EgEjjItFnM8iZNExE8ICmOx1CTAVSH6Q2CeTNu1a6XiFGUNA3BDZ5HTc5jZYSqSLowwrOPjDVrZOAkyO0iOnmWMxE" ..
	"HGFGSNKDtn18sidpRBPRR/TXVZ92Lgs4hE07nXwWFDVhfHTfvo11eM6e5p3rtEYiYwDLhz5G7t0dFIo8D6/N60pj/OyAljcWSBYx" ..
	"DTQusuOKiUy8HaZJ4RpZBEHDvJIAy53cSWss6RirF+OXA1EM6eavc97HTTCkMkm89Tt3bxDJNG63H9lNxHDZpJ328ACxszv+uRTs" ..
	"77Ubv26GfXWGyGVNBowecS7aYxW2B2s3+D1p/ieeFAwjebrVFbjrtRVx3Mtr8jF7xu1IJoPyZrcQ/qU09jtT9BKMmIj6PHn77e78" ..
	"9Ha09pqgzSza3aUHsESdYC+aOs9J4jyNPONx4EcD9QCbkw8nGo0NnCdjsFhewhs1IUbm7Ged2lb/IzQoyoinamea7FCGMAsAhK9x" ..
	"5rm3Xo24TDgrbII7u4nWAfEumEzF1Q4kwEg73XH1DQCHLm3CbEbS4b8JtKV80tfWLsC+qEmfcH0gDMK7KWIxDnVryhzmIe397iLS" ..
	"jl5UPB8SkLN7rOO1Y07X6J45Dikvnn/hj0nie3Rz0Nw27X0pIplRj41fyBjYzWjC0UtFA23g3r2bAaZVvNtz2Cn9sqUooVgBFE9X" ..
	"A10etJ22CCI/5xgH3TfeCWct9DaXwSUs1mOSCSg11G3RjXmHULeu8B3fbCOjiKMEd/xdZ90itZlhYcm8KN6z6nMQGrX0JRyWxwcX" ..
	"BmaEUGTmXh39FxG9n7J7Lm8ekA6nswCAW3oAZPUJmOTx8A6UaRwyy90e2kXCHZrUHHCLNG5m/Nz1cDmTTKLMAkBIizXXeYJ8F6bd" ..
	"PpxAGCcEKdnBAHFreXvWM8RmDIcbeMpV77VkfQZ1QZN88CMPEK0en1bXxGhXJdJbImtmz9KUHKP1pHo9/ZQF/c8Xe8F1qKK90NLG" ..
	"exguBdhpdUfOb+aTas6d46ZeUPwpPxh3hSR979joFV3FAz7gnhzUtdq/iBmWu+VQbbA+MlFrOdRv6FsIyDT+XOE6jGQNJNU5IYs+" ..
	"9SfGMegxalutkYnjjK3z+IFduIldMsDdznYjt5bQH411UAyVVglCvzIifj0bwZ/sjMSVcUt8/GNTzKKpFj/fnG+SkDvyXm47VsAg" ..
	"ObaNNfTML0DSImExYXRLEsC2tF6gb9A8J/aFq1px0VSQ2t1R0MjivoKTZyYEufpTJ6dA8hsDyzfBhdf8EAc8AZfjQvakvxtG1EUr" ..
	"2It60uNPZEyW4ElBNBE/8dTdwj/JfHZxJB44KxLG+Qf/qELOqnnQtS+xURqtAutYUaia84PLqfEtbzhC/5B/fff5XS8YMXg7lh1G" ..
	"Ee1zxCfe8BDDVQ7Do4F1NF5IJeGol8NQ8duB447aNf9E30Ho8QpTRJRsGWjJPuLhLsbtbzXtfLZjN3/NJ/IGFfvfZOpwHEoUq03E" ..
	"SzEWCz2d/tCq1k/uy50/V5EhHzt44v2d674/3BqYXL2EH1wXNz6gESwAsCxT83q8o80rQcBOSASiD8hGNZ7+8QuRf8sY2nqVAfDv" ..
	"9PXZ9ILBwUGPeCIIVdazuekbJCXp4wEG9K7NIM+D+pU+qo8blE3c91G0OHt+MKZX6rPpsfeFgliykZuK8e6dVdcTvYJ2OeXZkdOY" ..
	"AmJUaSGCgH4YaFqCUnX9gnBX0mCJY26MJIpvqqS9vza3t5umlj+0zLCMcA0yckKXeSEbiZX0jZDDMk1My2RDeZjv5614Huu8o8FS" ..
	"pD4vdYuXatHfmxydV5ydiQH+ZT69EGSJbE/hJWxtEGmc30zR4XyiZYVd6g4w2XTmkvzvcVkAjuUL6nJazw1tqNx55O2/42CzUhCp" ..
	""
local PAYLOAD_P6 =
	"6dhCcuNGLkF5PAh0GCuvzj5eSG5tL415HbpzUMZqFmjT8qf8//gVr3s2aL41nFJtgeQ64D6QU6JGlGt+qRAziDLg1Dxhyct4HTfR" ..
	"2982holfDvTm0bOcX4nXLeH7bG5K6zQVQoZxFACq1g32g6I+sM0v1vX9kzPs5fHamK6U7QOjCuPHMsb3bYQ5REp2u7URRLfBzGV6" ..
	"71Rr9j+jLGjHyWjL7Ei9s79RfvPDFKtASlMDQSnIDihB90GRUGPMDQf11amH8JZsTzzwk7cRdibu9F85LvgcrkmHl0E9Q8PN6Xso" ..
	"k/H0Cmdbz4fQSPtXsIoyQ91cW3pBwJjRaExpUcMNH+6FUXZHpUgiZVp2M8kQvjKnehNqfU8GhN0oxiDOC3HSLylJ4Qn5REI8FTvm" ..
	"xUquAWLhsxGdp1Uzvkj7IuQNg0n6mFXWolaZIHujrMGTDlvWRDfbY7DJyA4e6cR6EBXPcZ+MYaFZvc1kgqT0V61jXDompBHL94Gz" ..
	"2BlaJSCnLj3VpgynCOm+q6T3xUeAJG9VGo4d2AvOS9KIBLxnndliLBWrkLaC6Se/AHKqY5NFee7l3gSzcIeZjv10TplMjsEjxJmY" ..
	"no/5SbYRo2LNVEZfp9UzZaf256KqbIt/LjxUnIHYS8Saj+cn4d8lCNNgKr1usiPfGGuZS9IU2mZiejavdNRFCxt4hOxNgeiQMZLb" ..
	"uGBfyGYo/T2HJTl6Sxq4Y2KO9lI7Fgyrj4Z7dlcbpaIGTLLaSD9vHAgdEntgCAsINH3QX6R5EBnJWY1GjpgkJWxy86MMCYmD9pqd" ..
	"3GnQMI6Bi1ynqScdt2ZQqHzbswyQZSYTdm/W/u0EYYPwQwFSKKtdV5Hiy4WA4yBitBia7GtNkXVkWuCsrVKqdNZ2kXO3oIVI+pGA" ..
	"p64Tc9d1owETo66n3/stRuWXEohFOtZan17QXV0O3qMFHMvVAvBd5/03HqtxSdgWwGkR+XETW+IWILpZ3VA+AX7oHHR+EDJxpZ33" ..
	"/j2nR+I3b8YC6M2u06UPP42xgp0WjvhF3bHlHilzhkAhovnOglzNaRP8R7wbaZeIY0sXX6dKB7JKCRvSepCnE9PFZ3sjQtq1GUb/" ..
	"trNBea9/gLbHccjJutsrSos47/f/lSIW5Z6vs8CK67I3ZymKPioa0kDCRGNFX56usKq0Ni5hejUlIqv8y+ZbzsUfFmjyJ7PtebqV" ..
	"dXk/tUy+VDMR30UzlTIMSkIbXL9Rn1359vahhEso07D/U/l9yBKD7UVqcpHd5b6n1dAwB6GezqVMA9Gq9+o9p/0wuOlmTTLoWuEz" ..
	"iRPBCWIk+8uit3h6ermnqXDzV/lFWC76pLM/lzWnSR3aZqcl3ZJYwqCfNFCPMOsJpjvcIWB4bJi3mALsuOfoxAJLQBFELW6rTnF9" ..
	"nYeZWek2AgeIe+AcGVN8BT0RfX6wimr9ROxQrOMClDvZWcyWgprWPMBqsv8nsRVKL7sgmiZoPYT8Q9NVhUfyiGUYT00bc3Vxosxh" ..
	"M8G9oQYLCtT6vcVGdtSPHyiYt4/kQgFDU1qnobGgfa8SS+SDFlDY+ss7XmuMBOzS3QzWPR3OX3OtbDTfjnjO1szWdPSieywAMTc2" ..
	"MTRBJEUqC5f996/WvcGGPcasfz1u8Ue0nEFxZzODh6RoTn1XnkBzpdnED5uktATvRFLqsS5BNCLcAySCGCDOxgEcyndQXFaII6ND" ..
	"w3iwWM5uSRt+5E5EHiKGLr0D+3bjg9x5hHtdRJDFtLP4J9WXWKkzsUnwdRPnW8QikdaPjVbvxT4tj4fRcvBQ4Gbe3584PxEAcnkG" ..
	"5r13UFNnLon2gZ3z279oGWzoiZk9a5ooqYiPdqlNbozcMrTsHQIoZiqWtIafOsRBohzGH7Npt17JlZcDCjb6ll6iEUjbAvtiaFnG" ..
	"eGl0kiGohyyTuuwaIQOiFsB6SeBIoM1grIFF6Ak+LG6vysaUZxHzXsmwUU9CUOc1dGlWWYxPgB0DAYd6Kv1Xo6zICR3KE9xKkYFs" ..
	"nIF1EjgE3BMjeFYd78EUUToW857SasIejpabAdVjmFWhzIiLKAEEbCDE6n4CCx42J0vq1PgyH5SVoUCk2xbGluXgGUZm5pR7K/ow" ..
	"FQqTNATxl88NeWoNsFHG/YmQBecR+Z69C3VB9WhsnYsAbLKRNs0YgZwVoOrcTu2Xx1kl0fGE3TvzY1dV+yg21oAZLWi2lLI/PKdC" ..
	"312QyPmfvsaTCFWd1JQDXAg52ukbG+8HNefJPyzXiYJ3W64SMSk42eND1wgdX5T4mKdKk+Jcr6DCix0kCfULwbqWaY0i09jNrULI" ..
	"OHjkcBm497SEh9VK6mUsGAqXNQG5vnuemLeWeK1mPCIAYE1VhVcldEh6U75/i7wPB7inn2+auaYGBPz6EdnrZdaV+DhsA0W36Gkm" ..
	"otmCN0gxiMmwpohTamdHDQMOn8MsCzXohWyog4zw4LiO+H4GpwGPi2CYIGctq2BheBpYar428cLy7HfQMU8VlgkwxNA+r1oaCwVR" ..
	"miSqmJhi5D/MexVn2qI5jn2XhlZJWBulK2rdTQlpGQvTC06oNj6rXgx9HIdAcpHEpGp0nYF0gAV8Qhu61vYxSQSIYltK3XDCWHDZ" ..
	"layheoy4u5LDU+wK/WYKdRbxYr3DAx6s+j1B4infL0EVpw8GXMZQNvmXun9x1STlUpAmUMCy2kZrhYtyGhSTHAYUMtIl0GhwHECp" ..
	"9+Oycc0mLxNCODRlN4HHJFKzHwEfhHmFxmVKBj4i8Q5ZSTFM4ri88OCBcSRCXQpI08fnvpe9v5+LTFmFkBqbwsD0K1uLDUGvLKGL" ..
	"VJAKfVZU3pqijKfQ9NUMplH+gK/m8C0w8V1JX1tSZrg+b2zmKHYPQVoVWDkMs6xmBuP95Vcduwp894oGzlBnfmGMzi3tpkmwedTz" ..
	"UOpXHLxxxr0SpT7mWZiJTQ4LdD8Wlbh5uA+p7AbKf9xPMfM33vrV6p20CkOYhGO12WJWaTq0pCJGS1bR051W9DHFkGcQWoSc0s6U" ..
	"7TGvqLOq0iZTbdVFb+MnLCHImZIbe1cjPV//eFTEeGauz9Tw6d0CNd6hgkXZkrN3iLMrArydhLXbFzMQx2ft/BNzYYLbPbEGMfIP" ..
	"7RS4f5ELVS3FSFoSaDrZnXFRYs/JBSg9aAs5eeASPmuH1B/Pbphh6JABZt8bewECtJaxYtihvlGqlVBTzqAjN7WqoY6fdSa4QifH" ..
	"4f3ms1zPirtn0rpAg5ljF9oAAroYJN/4PqKtV2Nri6FaDePEJwrxDE9oJyEkLFXqknocQmj6HTF69MtI+A+XT4e4/FpHadKLsmQb" ..
	"/Ij6Y0qhQQ7i3IwItaf4dTeIJjeFgiJIvzdTqM1cxFgOWMAvPB2HwIz70UAH1UAkfsIJ3h4FlArrxYZrkhLSVV9SszMltSy2Jsxd" ..
	"mzNKdJejcocN3OtQ2oQ/KsZZEOEe9EAVEEPXNYBc61Nu8aukycqvMnJXzsCrfhNIn2npg4sm4qoeTR+tbhgBnn27mHdXBNe8xpXE" ..
	"1Jxr2WDDQ5xLDyjesYYU4OvbS26jaBVAYYNgJMqw/CgO32hQKlJltw03w+IpGW0OZ9oJJ4vjF5TPFuQyCIvBSZL9kKplrt8RFfxV" ..
	"n34OgXWJUy05Z5+HwgnBTw6VEBzskjEomy9PdvHvsi2p5gIxwtIdv2NEvKg6XEa7QHEwiw7jFb0U250LzdOhHBQrXU1bVuyg5S0O" ..
	"F2nf9B4u/DoOqtvdan+wLyoHWxG49ADrDEwZR4mLUByuhuOK/kZtBw0dxNwoP6G1cO1dHD9IEKLDT+uZikHnFQm6HXs1yOEPYdOA" ..
	"vkp6VkOGyrMdOqyDc5likLdMkHwZ3DWKXo3ZtWuSMJL9dQiDELHFlJAmUXC8ZvnunaqPsYQ3W+uuZtXy1vCU6k9UYOJIzSc3Hfh8" ..
	"mZfcsN3oCNPkRQqOLH3DH9DsOoir045G2Zh7GhzBMdEe/7A0K2UlREc7QkE9+3+GEfgfNfTIYcXUCReGE8aVRgN6kJ43qlgjEwUf" ..
	"DDd936cz9Chnyxnk53VgnJj017leZ/br/QRbig0a0l03tkIpcf83AFbFsK3C+xUF+7Kxn2cCvyJtQXf7Da6+HVJd/u6SQXppFq8+" ..
	"Euh29vIcRHXdf8ikwqDkjw3EuYIe6XnN0uH00THceHAlFxWpkJ1fVECpNIZwvG17Nl5pDobuhknVuph47gW1f40clnv6Md1EV9Lt" ..
	"k1D7LahWHTF9fJB/7G4uPbOrymiOEY/tNPzRikj2oGduj28W0Ac9CFEKZj8c3GapfZ3xogl5X6EbwWIuJEn3WHxYkb4twopF9XeC" ..
	"3QN7hTrBXS8r9bJpTH46GZg4hxOEazjLDutPZuIaMKFZ7rQpmv5Bj4l34rt/PEibRabr9K7s7KuKv3ItFx+hLRQli8/Y/U2Eobyl" ..
	"cdu82VSUovJtmOAqRzA31epgmqLww97daZRtivPVxObMJq5FXzH1il+Vs387gE7DPq2tkeJoSDI7OFeVS84rQ+zL10lEDzauFRvl" ..
	"UbI6z4ZdpBaffL4kKP3X2O3esp8J32c3C79DL/vcqm19bETQwCI6hr2P7OOvWfEa2k9eKNLzp4g8NnudzXFF2AWY0SXxSsRRQ0+C" ..
	"9KVlOmZAIgDC2kV1cen+OMy9D+SBnfbpCPNKItM89LrOG7k3UCewpW1opnJkgo+/KUvunGQxcePwZ+IAHxJkenZ5neeOZwHYnoAt" ..
	"u3VhibY0DmF4txaKPMn5AFW3qxGnuuhMcvlvR5lSwOYq4vok4qbBsrhkRuKIBUxhgpllnDxL6IsSKSC+nAEGF/qDroeU8ATaPfGL" ..
	"v638F8CV09qH1KYLz5kX6LSP6xSiP2xxfXrXgOrChqjaV4A8lxx8uxSZIzT8HqjPtlMe4tkWJa26VvR2QUio+k3W2URG1byvdJJV" ..
	"tO6JFiGRNuDBFOqpm0+UDb6kuvNrm4VXKxwjRhd334icSJRY852YfDj3fWNP5q5+TBWR+xACGE1Dluk/cKr5NrqYdJtiQBOXYm8U" ..
	"U2uyB+HugsNZsQejVNBcVgYvxQGoCGkFYBIgkabpx8teVQy2P3JU7VS36X2Fv8biSonCSvpW5Ed7VQmQZLCdVEZD9K02sX4twwc7" ..
	"D9Ce7Ki3R160RhzRZLOuTixOLRQEogqlXux9GtgHJEkYT7ff97vWCocgVsWejYNDgG1M9PPFsA8k8ELlvm7h+P7pStpM8DfZWMWV" ..
	"mfi9uNceHyAGg7d5CQBlTkCUr+zIJ1+qt9I8QTb02odns8/fk7pnGwxmzXug7cymL744ELVoWKwQjcn+vi9oJCcrdq/TY9D42OQJ" ..
	"hKS4z4H2QOxb+YMzeSHv3ngjWKYUkyXnH5qcgk0HoZQ/BjI5BEJ1rL8+LWCMBL213cQgI+G6q/DZFZ3XCs4ce+VSstAgGFjEVVMc" ..
	"6wQOl8dqROoRenLtW+RgXcMvLfMiV1rnXtIkmVGVpssroC9p3EvGmEVAxbb3ch5xYQfUa6ZDkAesdHTRaOu844sH+N+oDY4A2rck" ..
	"KpBSEZBOPv9a8pHhBch+MNBsM9JH4s7YdpaC1QetBoOdkE05VR2YdSOyyluXvst1mLtzSF/fMtwJEmMSuhVj/i9gCMJfCWs4BM1H" ..
	"3J3KlXbZVf3Yebx9BxSWJZ3KbO4C5kNqkLJNVlpwwn21O3ZO+LPQ2jMlXmKmzkz405xRT4PZqhQEOmSGvsdgp1giyMQkoymHqUq2" ..
	"tuFPIrdk9ErfnAt/S2j9xEPJMcVoEK9ob8MIvGL6LpmxIyulL0l57ptOv85Epb4/ZnoOVEHZKNgKE3oDEQ5adKjuC6kYjFzj6tzD" ..
	"CJu5kUD1Ebo1w3iwhHRVvu2F1b2zjNqeyNZazqQuHaP96PR0xEkYe2X58NreV5DWOJe0JvDbuF0U6X7FmK5pShzkOWVIXJ4uL8En" ..
	"BXDCZBr748zq09w4ikHNoPtnjRowuf78VmIGfqiH3/1qHG0UnuoUfGRY+1GRthKheLjjyTSrZwxqzl4orvknz87uXyV39vLicWEK" ..
	""
local PAYLOAD_P7 =
	"Wwbpld1ciwzraqwMYguCeQ5Q25NQ4aCPQycGBxcLli+9rhr7nBOkXX+vrULYx9tIvexdc9P3LhD4PXFcsVI74cyBArKjuqPeq6Pw" ..
	"qajQgWM67BygtlX2Y/RGCJ6xYElDywZN8Aq5rS4jApHK+F+s/4fDdgRFIYQUkiybvqk1f1TMIzeA+XDuc/o63O1qllEvw79TLGvx" ..
	"mtxji1++0MM7T7BCXX7faPKMU96lpdn7VJ0Yt/TFEYv8vQRMcZEKAx8LO5lbJ+QYnZbJidv89cAeVOThWKgHudndT+8IVPmB1amb" ..
	"zgNRa/KDj5L3Gnn6aRSogkWVQxE7yhMRqvLlIHdazZQZsAa3WXwF09k+d1eouWAUg3xgVEzWqHhaEppVP5PNdI7uUQCuTZtwVMeA" ..
	"KaqQ6F6IdFXQVHc2MeJwXDAhmAsywBUwiuqryLZW5pg7kcxvknWV2Ix9WZ+54mICVriQGo/aSw4gN9Lm4bTsD65Csh0ouEF3FnAv" ..
	"F+tiRCkuiwLevRtaPfirYaOYXTY2N5qxm7veiRZ3y8pEneydsCc9uGZ7apiC0gJE1Y80s3yHq9i8zrl86IllmdZlU6ZAhBec4OuU" ..
	"NnVwc6MJl+Z+hB9NoSCwPLeKvklvIrhXKShAimfCpImHcvfzykqyfIqH26rXfFoU/aB+Sh9NgUkKRX0uybqqHQvGe6WVTGnQhVOH" ..
	"iAR3B60VyX6ADHyIUuQ2UAmr7zyA/CLNWfkgbxqCUn12gE+5TA2m0NuzTPFfGKlS0STKksEdQhfLp8MUp8UELFxs8ZJsncZNa0EX" ..
	"YZjCCm237NF3iXNaTghWdaZQrPpCJK8DhEtrSN+rZVIxTwd2c1Ith+ekuwZv9lsMQCTXGDtNcnTrWa2Ouw//hhql9IwiW/VCWq1+" ..
	"OVSY75/I1H5R0q+fGB9yVZf4fpwj+zABY9PCm0voshHAaGsjypv8wbGimLQxbD3mzVw6mfOJ+WRQpgUwg7wxrqY/0UsSL+508Cje" ..
	"1i9HGabjJno7nwEhYsRYe+p1sg4VaXvCDimwi/S1DfP0TWb4fpgMEEHl77s3t2XYBdKm8Eq7A5N5S0L+jKIWqhteRyxYM/b0f5xk" ..
	"kcnJe4rZLwQpCY+vKzPPmgiefsarKbRZTgI2Wxk/k8BMVxz3ZSIIupRnYvQ6Wm3MYPspmRlRvmbSWRaoww3lSd1R6WydEOjTucvm" ..
	"0J20sRAB8QK0kSVxz79O15jQ/eNn1giiCi6ikAZ8KstuCPSc5sOewO5ibKVs/tVemrOwpprscf0sUwQoNW6yevMzeiUE0JPHyC9/" ..
	"pxJOjF5z2qyDhdNUdmxTQu8n9p/ZTuYpXuHBCJObEsxsrqS6wclfIAO4m2u9H5PjuyyfqdQk5rI/CE4vy5Mo/0olOrVfGXSP3zl4" ..
	"W3Q34cQ6ssU2ocPhg+MPULKi32xEKp/r5JqjZocbQuA81D12FJbl8wEUmdaYOexvcK5R/cCOMMo4+PPBKERhakvgn4qoUft7qhJc" ..
	"bL869pegh5nh1K6qCZ4lAIXyJRlWp5aiz1o3RQ49IjdllSm7K0bx9ZJdp7rpbMhAF9/IJDlRwOqGl3trNdGj6/V4oXOdWeZISe3B" ..
	"no2lGDdMoMCAjuihXUL6vQDRJwxXBnFb6Z8qK6xw1dzwOhcM7oewisYos0i6//MorjV2MwtXN2GdM1rrO2owFdvsdlZzmCO4wgZB" ..
	"23Rmra38RhA9t48EXkJ81aakIoem2Wi7ScuR5jiX+sHcQGgBL2Kf/1+/ZwTdgseQZAabxdoui3MuykiOz92gamdz97wP10KnjGwE" ..
	"S5jtvPyOPc4Z9kdNlFK+LDnBCRtqfHPL19pjpis7COvPXi/ZfMSJG+c8Cy4Uu7LbUro1aX02hYSB4kw12qzQYPFfP5DzBsLUF0uQ" ..
	"C6+ne6uKXyLJOnb9dae+9En/fky4HUvdatXbUCd+J5o/41uff6KunkG1WlXNtjO36S0ygaVqqFHV3QVhQ11OL76yqbKkoRqIvT70" ..
	"JeYEFqKvs5Dn75xFG5fD3WvwA+m54pnYJZ7/72yYkLmMA5Cz+cy8tlOIsLoPwaiIjGOfMIF5CuuowCQqtiSC9zxQeRKZs9UwRx6e" ..
	"+R5x4vS+9Sc6B8xRAr2OnCaRJxlcqiCB6tBguxGjBE6f2Jb2lt7hmR7o8W2Qz6HoeEqXwNQnlHXBMcHuGIWkGW4sN1uVyXabJfB9" ..
	"M8gjhQ32FPS1XuL8H34GkjGZdgAJCbBcLrOg3NutjoR9evYi2v/1pTgERZkPbD7zdQAFY5QgSpb90qx/BpfEQxHVCM5q1xNRqtqR" ..
	"ksBPk8DqlWgkbHr7CG64UJRDHiT+U3zQBEUMkPE3YMAAtOtXrMhwAawAnv7u5aDCPLMfhxbxblaZzpFHFFK+hmzP9fbiZ3nHrkbA" ..
	"NpYVKoHP184fvh42WhGw2me4j9+x557w4sHH2XbcvaVVqZCX2Oj0uolrU/kH2npfeH4834CEK6VSem06BqeXyYEws2A6pxtd/MOV" ..
	"dHoUmPQLTA4Ek4pcCX+ZCVxu6INrBs/G2Cqj/QNvkZz26GvSKYmvaBPUAx8a6f/J5xQJc4h7/ADV5ryXmHC8SItWGqndRhweK0iH" ..
	"thnnJg1TTfOBh0gFlyE/snD+h8bMTjX/GJyciNnPasJCfSbGxurhBzAOVafzhtcA6pKT4oIBQveIxqL3MbvUyegbYEG3gJw7+M41" ..
	"295kThtnxpul+hCBH/ANTPhmBsbsmhA9P1j/MKkmDUgVP/EiHVJXxuPHP1ZKaeNou4o60hcADJOLjbESR1p5vHqDbJ/NxlmFYiMi" ..
	"pkWvKD2Cifxhw59dpguzs+YbD0IMvvEZsmuIv2gxrYBWXSkjgH078rqDaW7LCpZzT4YU/RS3I4Gyjub9fsYV76vq6RMgQI9vERUl" ..
	"ck4v7j8g0P7DNa3SfLsH7MLj7tHV767G6fmMmQnt0bWpi9IPpkj0s3hzj5D8/9bSAWdxjh/JDJf5yqheEj7SLkZlhUMXh3gXdPfw" ..
	"YSc536NHHWxJH1jKWaT7XR3THxr+CJJuH0AXBn+ZolIQlp/Vz7itg2Ld9Ibg59G+rfR4Jvb0cuev5CIwO9RDtLXLepy6wJxSSTxz" ..
	"w4o6ZWm8qyh/IPGoI9UcPC0aaKTaWi/Zf09xDhA/AFJHIk8FAo+E3O+kXxLAlFpt+x5XeAhzqweBbXtW6nu4CYNEv+d1Zatq1c4W" ..
	"Eezw3q5iKJhnqWoxl7d2xL4+K65fbgeByYVEj5NLsQ/ZVym0xrS8YPpX7QQJnvL/MTy/0R2Tuzv32kVcUbdYWugRF/+tDZSY41vc" ..
	"iQIAaZthRYE/vrt6JrWpru3ERi2WFHlPjnjybabnZSJN4Y5jdnwrIslg0MqDMDi9xNg5IYRhJc/X2de7lRJdNoSD2b90VTBtlAwT" ..
	"n6Cj5Tb+JtGLpvnRtdXDSGpfcaWbVvbFCn9EL3mjVTb2TZBb0rH99P3P8jbwhCQfHw/agwMb+bRvVf6TbT8ozKjd7pHUxc6p7uF4" ..
	"+ItvFZGdtqMGR6NaUm82N4cqVZk4/gYudN4RziSIke5kKeainb9es+mQVXeTqAVAOeud3dVbUIqns9WiAr81UKpMA27vyflUjvTv" ..
	"IWtbMhTu4O5/wgnbAWWHEcR4wwtpPeGpjaRLdXs4U4t/H32Uu9EbqCpxbKVdGQaHsd1PWe/YW5vhB/fChcPVhWueLG0jSKO+Z122" ..
	"XYK6eh8y9ttFhwzeOF+2//NjrAu/SFYqQJQnkDyaf7QC62xQqiJWraui1cw/cOZb6qH9Rb+ib2R/1U2Ua63xwMv3R5L4CNfyS0Cc" ..
	"nzC5sa6OfwhKWR1MvDRnqiBMi0sNwOCNZoR1a7NEdG2WGEGSnwFItl37hxuSGn+LGHusKcoiJqxPMeeOm1nMc++VeidQ+SY7QRsg" ..
	"3+nO/FOZR4G5iHzyp+9vIkZ3jj+t0lxfMk4GE3lkY4qxy/N0rfzLtOdx2VQjhNrKxyeo1DBJUfn20PHjtffgPXScocVRxY17BcTz" ..
	"hDzah96XOaDOuVGP5yIUjFuLdDmatS6OSk8lg/PvR8ZFJqL55zB9dTRzZjHId75wfluFkU1klNaACYo7qs9ZQdeQJFVxc2ALbC80" ..
	"dmCmIhZ9mDqyVVpFh42U4Gy6NZ7fiHuXura5SM+5/UfRVph/JJncEBKFT18XK9CRc5RNBNs61AcjoLfMH/DIQIqqAhlzOxUroHNL" ..
	"s3OZq7JQs83FQfHBSgrqt+uLHDw/k29oWT5l+7Zx7n5yyG7pkwldm+oo2XN1QC8phbaf7OcPoH8IuTDqB2LuGBR6cKZBCIq826UA" ..
	"UMNLYEXziuygepIxQs9NcT1Pb5DGTfyZsWcyEkV4ZqTwFrVFLRIXcIw0C+cpB5aCkVsS18mdKw1wr4LRjG2fbwXiyn3+CiBqfLki" ..
	"fstGqVwjhLBzHrGyBwtUFltaYYWJnB0KB3JAPkPkqkAIemWK952sHLESABWEPcmISHg+r0l6uOPr8PR1vATjEk+PMptJKs7y/kqP" ..
	"CQPsy+mbHJyUlBvwcM4WNkVhCvKeWbqckASscYyPaH31e7ZQLWBIOh4RVEWhHkdPNC1oi1l+S14PRau8KQAMlkuyUHQH3f1yM4M8" ..
	"hLhThZM1Mi25K3uzqDfbFx0bx+VNRjnUmaI5gnjYp7SsIYdAgX+21C/2U6M/ZGnhfvDwv9ZuGArxVdL1c37cnlLBiegnkQcz8MyJ" ..
	"LUcmyQIwYyfFzX+MaPfc6/IlGVw4G7aRmfUooowsavvGuczvn0SKw94lBLNXOXuNZfYGSukPmNTZDf55rYtXEMbp+0MQRBf7xVnz" ..
	"3y+8vGKK0zHtd9FOCULKLb8si5Z78DmEcN931kBtjtVp3VsvZbG1BrAjtuF7pTaAGX+YFeoylhh8VUPDhXU+Bwv2vp5lAkOa3eqy" ..
	"2VgC5Xg2DWq0eLddSyvJyu9tbAw5sFE/mWvuWtLOTP4kpuw2M+l0Co9XMIRhikOy/QZHVJDB3NjtD0+/jORQvCou6P3SKs9DTmFl" ..
	"zg0lLmhfiOAxM4ezLB0Eq1/nkOjH1l3zr6UPCjTzwqgbSjXZVvs25paiXPtJrX45xkxIsVqsyVwea/hTGBrmFctLpmjdigk0TBfP" ..
	"ncjtm2k/e042xxyuqwc3wxT0cdUcjgyL9Jtk5Ju5zakPOiTih9W/l8S/L3KeJ3sEyOhAXvNMcQnEi44Ics/4eUlUsQnSNMPFi1Yo" ..
	"78keBRMMl/V00PaF/kbHpYJAhTYxkeIOM65MHNKHBjpRk0ooyhcFO3+0HnjzRUwONqU4PunqVvZ6mdAXcBgIFFl8gy+bcjV+098k" ..
	"MACMhJgREUnzBtkpQrr5FpvYqp82qclbkwdTzG5Vs4WTAskOMxHycegv8EQGDxen8siWZOUCM31tEdsa+uDvTmqI4p4mAlDTvC/T" ..
	"VIdANQOwJmHZsc4mTLG4G18UAPhJ5/k58sQAm/11MRYs3hRquhMZ6mIjdyaJVrVWMKyNQrwpcppwYWzR7zu/IBkh6PmzgwaZtd3p" ..
	"CGxVc32mR1dFyGKkuFBNi/jxWjdQWYID1UeTNTtZkw6y8HOpdqgHVpGw4Kr2CcldMJz6j+zGQ4exrnj1xGTyzVlRj9LfZdaeoZBb" ..
	"62l8pD19x4wXsfLy7nu8sGizM7FHAB/EP2X5i+kMDa2pqZ0uPty+LAiH7E0sIsrxSSwjgQv+gR7LN11Xn/3cLYAmjQvq0xytQULu" ..
	"u6eYPLXEL++I72KWfaNai14xeNpK1y0Bp4a53DQW97rn6K7nXjl05F8rQR3DE4MqPK0ok3nJS2fvZKwZkmrmFeQtVojRfnq/O2dP" ..
	"irtZOU3zieY5i/Ev1tKnvfJHSal2pcMaUioZULqXAbvGUQkWxFR7D2NnHEn2FZG3PtJ1jbkBU5Krm3d7DfSN8FjCJ8SRMk4Joddc" ..
	"Oek0xP4itHGjzd8m2PX/OnniX29zzYsGa1YJklkD+DndVEUgviUha7ed5pzp4GA167CobSHBOGg96U++yp/P4Pw9lcBRBGdYMlQy" ..
	""
local PAYLOAD_P8 =
	"HVOPATV6wnDCi043J2Ji0C0K6kPdFDYA63PyEC+CNv727eNCFJXVF4MZ/sEnYTB1TTd93+v3iuDW13oQTv6L06IsW9WwUm8Z8gHA" ..
	"7eKWUdRsi3N2RDQhyXCC+qrEHB91oGENLIh5GqfMxwMnGk6u+yitWuJVvd8SWhFGuiz152uzzchFb4arbASZKHU0grW5nba7loOQ" ..
	"sse0yOi6o/ftKzwlb1FKhJbHhhE9wjUdsveW6A3dtSobJ9ebtUOZhhnbA+VQieQXYDGTq6RkDHnNMF3dcDF9/D0ZXoPOznhXWTd8" ..
	"6IEKeYR+UAvBsb5byL3sKSWOZgQaWmDrFmqg0X6zF2QjN/xudqEo0saMlYcStmkpRILTPp++BZb2OYgKbxVwH7y2lqApNa7uCrAb" ..
	"7cx7KkWRvfsZtMu5csNHfzAJ5NZj3PKm2U94scbE4UlEr9JdV22V3NQ/zHxmEuZkI/kCteyh6qM8uG9psCJ3qnXLFr57M8iu2Wmp" ..
	"7IC705jctG2g4l+IPaS3i8p6ZKVWCWGLGns1W1zDs6UVXFP+ZtvwWmKswxDcSZAE+P7g3LeAav/BX2nXvBUaQBxmA61EUZSfhlFw" ..
	"gkmkoe8nBz2z8i1QXbXbQwXesCbCW6WsjnsXiYulYkPZ0YzPz8ZvhHcYSPFPJiIB7SKxYnaG0RV1y/gQ17k0+K829G+t05iorjKS" ..
	"1GfeiZykyUMmlVH748qDxgFVqypRJ2Qt26fU8KAAj448Whzi+iOAKZgYFSl+kE/xlZBtkRkSDjoHfsuO58epLGPWD1zCA1OobSc6" ..
	"6uo/z78s7x6znzEu+/QznnnuRPh55azjwwDbNC2DRDSthXk0yJSh2Wg49CAz7gvuFKHwf5z97QwTiADo37UznJohR8zGA0CwKYEZ" ..
	"/nBOLw7U2hA29GPNHdQOHBd18jYNLGfcIKRLZB+2sckZn1/qKQbmYLb6Zvfqf9QQzWFBEuGuSaREYjaEiN/J6u8tIhMPXg85Q3sM" ..
	"ltnQyGvVqFHXdea3s3eqssIMb2YGlQKtqHbUP9jw5Tu25VHtShqM4gvbTU27AIR/R70+Xh9lnRaElAA7+ncTEYDxFi2kCEeSpP2B" ..
	"Cu0tTXgu7sVpvOnHzCiOJuSa59wgNadiTc08AmwQ6ihpgPjw38Lljac5TntIiAnt9zLjMx9BzC1RBVrAFgVXjH9gb3LSWMDwuJ3g" ..
	"i0oBubsBNKelhWZJJU63k736utZsqWiekgSwnhY5NjcQw8b3xaarztDS2D+NcIrI/A12u9PJRZ1cxpbriWXiHQC8BQa/7IiH3Kdu" ..
	"mfJ9CawPwrZSQ7qqsQ59aOETSTN5oP5nM0Or2YbEikNlUCTdVzgh+a9cZg1SRP7/sPH233jcnAdaNRv6ornT2dwa2yx7Pvyx6q0J" ..
	"eLEXYVTh3Giw4OGXRRlQdtXAWXhY2Xp7kNUbuXcVDW4X7tGnT9q6IuCQEQVNNXjdfA7FgjZU2GJM0vTNcmxrkv76Tm4b4LdhoqfO" ..
	"UWVe7b4wZGkwEE3gGP5Z1IMoAFa4CMHAb3EbQ59//nBeYKjOn/WoMNErsBShjeOYtAxVMkBGX2KkTxOwFkpNkOuc+Klp3tN5ga/A" ..
	"HpJ5VEh3G6H7LQaKwSLnkZbCTKvQyJX/TU9hRdXfg+AFBfh3GjqYz4C6PL2karKV+a8kSd0TwLJV3Arq0ABNRjeGHCy/IolrW5wr" ..
	"+PF/2M/8Nx3ujE79v4MC3CTLPPlWTU04XqRAiNiq9/y3sEVuKjkqbyYHnX38aOWqKNLSBPf2/XMP7GFT4X+A2+mbQDrwB993pFPt" ..
	"2dU/RDF7gvQatgmCEHg5PFA6t4KkiriG+EX/g4Vw017+ziPKKKPn/9NSvzfS7DcV3AeMnt92FqpbyWdJyJuWgM7b9+t5tYvk8NAX" ..
	"o+oB3FkS18nfwwrPlOA5lyBKSXsEanxnv6rsAy9/8noBuhxOilRKuLWrxRhCnpf2XgZp+l8AmtetWQbQaFcyFGM8N2+K6TG7vrQ/" ..
	"V4JQLPaxzO+7P/wUugv8OQYdr0ETQEAPIndd2Xa/xziCN50f3nuzIQpXI4E8Mler92jM+KUFN3rrENN6cEVWFC2B8+tKh4fflie8" ..
	"ge/oYbLm06fIX4eRAGD8xj4bIlaDJKUfd7FtceGyq77HPKNsLH5rBRobJzYdMpr98ZGgiujwnwWKIuy0B2JdnEKepHfyDmM2o+2p" ..
	"VTcOqH8l5ve94hd03mqZKhNL1Sa/F89+9GSisdBDdeCBZ6+uvuMnAiIjPu0zU5+sSeCoNofJZ+NJOjkdzGxhVOJORCc7w2hXMXzc" ..
	"vZEci7atF/ZNPix8P+5SvO7NSTkRDmQx1dS56/pnFOi1STDfMCCjdNzbdw8AqlseHHmjAICgFmcjOyLvb4Q67yHSxLKQ/kaiqXCo" ..
	"vV3Yamtu75N6jO7N6/bpaYcOqZDtYNJwIcKkRb6KPq7l5DKbO42R+1GU7jn83nki1lKyvjvPxqr2eABDk1IFP1BI3VVH5+SUlsmS" ..
	"j6rDoq4vOprgUDwhZGV86QpjZywkG5cr6lrfWIy/AkRxCon06cSw1pK2maRzkjl6zwlw7rrkyN7mNxqRn4GYRov1gPFW8UNvYLlR" ..
	"BwWySnbUxwPKb91cr7A/FK5QI7nBrUQrFbYycduX2zIvgl3KtjvKgy3SuJXXr5RTBqvbnhQ3c12/20rUbSELqDLx/SXltundHUFV" ..
	"HsoiXBQ3Nxd2AVZ6rpdAP111eate5H0u61maAk7rRTuH/nv/TnH5LZ5Y5jpnvweQ/YWF6fdZnpCmNhMYGJjoSBQXiPG9GcDxXOqF" ..
	"emkYh1pHK+D06l4CavY6/bxlTbQ98MOTTvb5Yww12SIqQcRP7bgmIAlaCQDEFs+/kt81B1KjblPOnk7pSli2sdu8dT6U9IGbVzt2" ..
	"62ahBIowbaISASxo4f1jKqv0l5ydgPBoTLX/6QvXzsMZCgk2XHBCwgSnzyMkXyn6fYe3VtlE4nIyHuk40nMxfuC2tdBf3Gajk6Os" ..
	"BUSPVBCfZn5KHKXIysoMLf+i+fxP81+AtyI4SdlP6XuhYIoj1Js44pX2BI/ebi4ipEcj5L4Vl4pTmf8M8M8V1FmGDYbUGv5Vt8Ax" ..
	"35GK3SCtNm6Z4qTP0CHVFOTAmL65Y1I2nLCI5qQvP27KLvmZwUcpGbFx1vP7uBHr5FIQcvqYlLW1qSbXhdndcRxCKt5eW2dO9J0b" ..
	"Btj+/177GqWX2WQu3ZP9LkBuJ0+voCDKhQQwqAZIGORzEb2hZ+5SlFIZzW59XDxdN5OmlYrPMIuhZfNHBbhoOtZmWZApLKN3P+AT" ..
	"jJcukeKjKqocew1L/a75Yp4qxTmjMpOGS2Hr2RD2u1cbSC5rgUGULR5Nd14PcEzWFXFfGHUwc+phC0+L6dOiCgudhYxe1jclJE1u" ..
	"r3XpdUv8ZwY8EKrKMQ7Q10MBUM+Fh2frh1DJuUiJGB0VlzMAuj7bO80yyR75wpxKVHGIh9ZLr1RP2NLw7IHnefIhJDf/X2UdbzHc" ..
	"5/DbigMorXwI1maK0qBtCXwC58lxZ/z3JChaZqrhC0/wWbVZ73H68G23wmMxa9ZQkKCUaJqjYR1sb6KITk6f8RgHzqlt6vr/U8eh" ..
	"kEwKtSp98woKG2oIolJAwQxHkPl8ciQYXxDLjyCm9875qfm5PhP8ZupRpM+snUq/2W1jjHgbDPSl+nvbF5MZiQPYJQBgzpOU0+xA" ..
	"Y83PM0iYCCLkMtq1qfULaUfyf4ZWCjp8NXq47ocR0fM6s7gwmBv/AKRRIip5XRF0tFoVjTjhV26uiFpotyB/MeFK8T2YqxKQwVDK" ..
	"2msRleWSadEvCtGkySin/qNDxrz0r7yWJ4HufadO64btqtiya5fAoVQMggx6YMKmhgHVfMQxTv22GIHSoCbIDCaHJpk2QuJw9l5O" ..
	"ctRsFIpcABZ6p7tXHuV70lElY68hZWW0jXWtpKcAICLbARWAc3m1mgGF4s/y7WkjkIN8HO9C9LEln6gNUyf4H9vzUd3lQ2It71Rt" ..
	"6feJy+nxJ0kyE1dn7axSiIWkcFhAgLgGAA/gNUApe2IIwa3rG6hGvOsktQoIROOKJscktwOR5u/O5tchUwZiu6GXxzGUHTZe6yPh" ..
	"lYxzQoRJgjkh9FRpesTlo2uGe23js9f63PB3/bxNFdX2BHYOFXMTSM5o/zR4o9Cl2q3vfQM3su9O3AO4MLah+EU4i2UhADhKZNU4" ..
	"gCCIM4vWFGbAMSTmEMDPmVQpUDAMQzRngqQPzKWKXYSfXMbI1/UdZgD+bC/vuaQrgL2JHBZCw59OQH/kqe1ApauyjKzTUcyh9mzp" ..
	"gP02jieFLEXLVatkP25zBIQS686+sVwIiw6VNjAD0tXF6Y7OjY04ZyolaeLPIXIffbebzI91HHXEc9PFX8IsQ7YBhhJ4ZqnXFLFW" ..
	"UHZkQxXkij9DnQQcZztLgovEQNXW8b4Tz1gUbfUZjM7iFlcXE8z4n/jLCHB8Dwup6KfLYG8Ug7/9mhPwgZB/RHD3hArXmVPqB2c5" ..
	"ZRW8w1LbzM7kS8OWnyOnf0iw276nwtXx50tNmb3UmsWuheDj3HKvI2f3U3Ss822jzkQrCDihwGe4JHF7pmAdueHwWkOnR5NaKk41" ..
	"uNI6byvWB488kY+kPMWs/3v98Tsz7Q/abVB2iNDJqLqlMiWE9j8o62pFTpTlK5vjXiw1t7t034gR1ULqYzVBfPaqx/fC1g8wifCJ" ..
	"UnYh2jnfdAH9DG5MarvO1LnMzOeqQzoZo+8TaUv+2kEJptLyxUd6f5PcFYQhj3ky2G22EkDtYmErhJ2lbYL/fY5Kx3ug93x+9xPA" ..
	"JszU3Qwsmozii0lEXXKPLH5i4tYvYxulcgnp8kHE6qqUG0dVyyR61S2CwqGcxJEn/Yiey1I3TfPt86ZQYKrQ8UGx2zZtn8YrZ/t0" ..
	"3ckuIb2WmvliK6VHq+WnzMUGE0nsEst//7gjjwGHlsTDlZQVVDq/xKP0Cj7BEIiZgztJA483wxbpmAjmEG+NklcXpYWgoLoYlZkL" ..
	"Ji6chQeNX34+mtVEGJNnzCemfV+/r/2uqjzBpDUjcy6G1XIRWF26V5UQhAXymSS4aumA3lmj0nhJL3I9ab0OpZOT2dcuAWOZBqJy" ..
	"aMHrJ+Hur+Nq7XdHNJi4Zj3ywrRDZSw35D7oqT4rlBFlGq0Hwps0q1YsfI10xyk9Z9gEzRRpW3GRBOLXq1lbXAt/Wh5GhsQ3QSQ8" ..
	"FBhP+dH5YCBVlSdLATOr53HxVzVRL9x4q7WIoG4xiLkHKVmyO1D55H8XhIdeRc4S66yP+itfkJwLXjkxyKZPff4taOLR525pFkKa" ..
	"gd5JN1yzZYd8479vgreZP0frR3gBQIeXwukPBcvPFrRHJIItQwY4JNOdOL6j1VrxQAKNFGVBfgqLn3BE8PYmcJcTpQ9owUliBmBx" ..
	"yB4tdprViSclvkLQVCj81mut8scqcV155R8/MMQcqOlGruwSEM+IfPIbircLZ+7grOWOwkpMNJsaUTnd2/J7FyF0kOw9vh2ThBk/" ..
	"QfV8Y0p3/YxUSDQwzjsx3QxBnUcjQC1j0AG0khOWVu2gHVLSSEkmFekJJHqz1GSKbzqnilnpGiPZZZkKO8GHl9ZHv5qU6v9T0l/Q" ..
	"9lBx/ItiItcR+IBIl75G8FJOxwRf0q1sMFqwiL2JdpfTEi9bNjHm8ezs74MfY1lVWUmQblzpWqux4JifyQxAgMEDXKAbseKYH9RD" ..
	"CVo5tlgl/w+uXx/y50QvrZ4GTKSuT6gvx8lLCWNi/AgMkD+1KURCVNX8q3j/dq6GEP62JBD1Fd+jFWdDX1K/F1ii8X1FbSdbbi6O" ..
	"/fbNystrMlKxmM0fr2+g5VITH8dg2TRKTg/CuGwOJwxWv287XIXsx1kD1pDllCk8nUPN6WnxB9mYoPcFbzSZ727gwURCzFstKDUz" ..
	"JupaRzkZUj3imG9QgxNwWAwP2NMaGtNVywpfrRpc6J+hFdGxZLuy4bWXroVbgxSKAyt0K7URdP0licrcWXA9tYwq6kVpAIHmwcI/" ..
	""
local PAYLOAD_P9 =
	"CRCNqIX/EGuv/PQV/m7mpXX2WeXuEleEJIFB2ZJUM0pJG30RxVwz/Jir4C7PeaBqIdKBEw17LkIfoKileTK/esnoBOSjYqjt1oQI" ..
	"vBuz+8GkNGxYUzStq5Ra0GP1L3x44/7w+7NmwotIDfxK1zfuggugjjSD3/P5TdNCQWecLwsJDPbGd6DF9fA1+mkDnQFydYsAbl8E" ..
	"aM3jhvnzC8zBmAL+KLFtrwSzHIJZzRDMv6hHfWYMvp1sO3mDH8eofvpj3skhvGj5zqC7RzqMxpOaOwW60n8T0s56yPX2somJd7ys" ..
	"Qi2NG8VWRyrP7fjnClvaJveP3527sgeCQZYL9LM1eg2NPztc6LCT507Kei01Vr8XtetrNbTGEhu1N4vIku+1lM/4Fx8Yvh2Y8bCm" ..
	"SpkBxwEVvRP/WlKf6j3JFD3paLcOmNvrSPQvqUIa5fNBMppjFJl25SKZleh/esHrTarRuAI3lBjKCa23aRzqAN0LhOxaY3rD7ctF" ..
	"fTVGkDg4DmmQ+a4KGuKrwE+Wez8BH42OSvDydO2UWgQX0Bni24czl3Pnp4SMxo5IX3rRvEIM/i0D1C4rGVpkQJxCEyLG86MPKID6" ..
	"VK6ttIEFNSTiWigttzE58OK5pcEgLvSuGb72nK6cHOSG1UO0nV6rXZ5UywpsjJaX1ViHrh9F071MZf4/uPYFIthndfR7tAbuZsZG" ..
	"UVu/UFJKlPUjc7CQ8oMgrbG3zXJa0z96bW3OfoiRSrr5IaIxjVLhc+CDm/5L4ul6RleCSIjRDm56za7+7HxxZLlr5UM//xR8ebw1" ..
	"QIH72rP2MA9Dpf2GSLeRysX6KkWIEgccgKD/CgrYjnLGMQ2chynnBrKkDoNL9SDCUwBH6y7I5OS9WGkLx9G1/N7bGb+8gMVgrMLE" ..
	"GoI1WQKLfUpCv9pMV3KWY3faATGnEqODerGR1yrpF9RgYuhDf84vEfxjMc0VG5vwi6sT3k+KxI5u0XeCwr/mgGjHpbh5cIV7p/GR" ..
	"YBW/gVotWlX8skxIyh90d+R+2Y1acWj7s1HZQ0XjOs6gOdccNngrxI8ZjuMLQmoL9BXYXnCyH4K2KOJanW/EAjc+OcealXQgoEQQ" ..
	"zhO7Voxh5/pXfIugpPEOJRXtXB6fn6WKnGfhKGyJRtpEjQ9KZffF/dheT3Mjx1LwovcGPoCkOS4J1KZmyWMSCDHjX8ULim+qALsK" ..
	"oRr8MTXKLZFG3lu6Bex6VUYZ4qOhKrpJXCoCcC7gSOdGrud3ynL63m47Heb4UA5dEuBvaltWSd45NNg2mJh6+JeTSOTphlWerUA+" ..
	"go9ubrlNdtCLVVoZMq3tWjZDk9WvQ9JtYPWm6AMa3mHiNhm6DWwSWEAGO4HGSz+oPakuaMvveqXD5TfFtegsPZ2Xhul/63nvXgDE" ..
	"im3idXORSNZBZ7b7RDV9M/CKplQzm9aEC5ShHs1bHKsjXY7ZaWkzgV1U3gRfZ8ycIG3RRkp/jmQsXX8MGgD2+/udbcmNHXpPrHIK" ..
	"QEib3NlaXX2YJzYAv5S8G3C+gVdoP4ghX8twt6rhIdK8G3+DXuHNpgr7xqQzBh5x3s1yEnnzo2GC7ncpABlC7Y11fANqlmLyBzQg" ..
	"UgQWVIg5AjbF7rsz35G1kgrPgl3aJanKW0jOaFg5togRc0uOB4GmomV3f1rS4NWsLHhPlGYM93Ydxm3Gu05tjX+7h6Pp5lvnUjAl" ..
	"e+WKT403S3sFB85J2UOgd1ZfDk/aKa35Ds9oPpkVBzoKexFp8Oxtjsxm38B5kZJ6Mpr0fmwyUBtvBwRtPqkDFP4Jiqa+Cij4urlS" ..
	"UTkAcGX15ZB9A7Lt66TsTK69q3WU9FWUoMQnW2lOSJ3cxontbgrJh/K16CtNnFpv0x/2RvIvvUFeNdLRg9V7ZTi4fU/AXpFTmj/0" ..
	"vnPRSESGpjzY8G7cutMjF1i9M410ELq/v+jTRuggK2Pa/A06l+SlnPdyctZHC65BeR54HZBc5BpNsx8QgiWIAi0yN2rhV7Adzjig" ..
	"os/ntAFVLRvMhYgZ/UPywp2fX4GjwVeXoT6OeH8DLFEnmpwIhRjk18O0xJHcrXNT0/UGtHgCqSzUgdNdqtJXaJop5ROJPgbRMYfO" ..
	"posi/sVaqHV2RA0zCvEqHAbuuSGJtLdwsjpHEVZBee8GsOd8YR71ERptWxj6lEQfAmIb0b4LO2XlTy+gWU/Ce6OTxpa7kuiUpdo3" ..
	"p56vis9/Kc9jW3kBp9uKwT5P+9+LRB1Ba0eBmoFCGMIdD84xN2nb2UiyaRyIZPcVLDZmgzAIBKcYjUM99u6Vxyl3t+OccHCxrpto" ..
	"63PFt4MD3dikFD/Go9xN7bqyiQbifbjamc/bmYayzQEbegoQucbCk726wSRxiTC3Aimz8DteNsWFk+YEuQOkivPIhCkIJGwm5TiK" ..
	"L318H12GxElurcYJATDmxpbDCezwNYlNkbfejTNyCqWCOLaa1EPoD1mB+kdnZw0Gvh9Jggl0jl0pZkuS59ag9QZ0Mt4pRxw0AbtI" ..
	"QANRLKjbcwlNkD4xbwnAmS/NGZyBjegum7jABhXsyffpuPogJE1n8DcRCkzijZAYJ9NPg4Tg95Yzj8J1OG5ZAiBY/SgI+Ew+Mlxy" ..
	"IstWGwY634UqBNt9yoO4caHRyobZuSgbcckuL7tznZfFN4uMQEuXDRTUk+ER4LXmd0NcvIpx1LMema2a5Np1rPnMGPgMArNRZrzh" ..
	"fyBzvN/OE5GDJ9b1NhQ2ZNSAzEbCSHFkrNSDeLHgGPfp7erp9lxnWjTugO8j63qDpagWlXZdcL0tLtPJSUk/i/6VfGXzEG9KFJTp" ..
	"mbkBd3MvG02RbGzpUaMrsXASHNdWhgKGULPrnbhvZFc7I6RtpK1zXH3xcRS9z6AfP42tQ3dWVybg9sRfe06T+12wOeqJtG8ZGv1f" ..
	"iFpaGtKQCilxWgHBoL6Wkq1gZTLQWhwi2bWyEXyCSqdgsp2TS/9gxERehw3HBe41jOmC+aDjbC2Q/RC0d/RgaiINZ5ZFGGR76wbR" ..
	"T9kHTjqRVyXecON6F59i4RVua87MLwcJBh/ZT0AiuA2VqfC9/xPyL1j5xiQcTNfJhijEmnl06Ru49kC6wXk4Y+vyFv60tetqtXT0" ..
	"llpd73etnJgyVh3oapWl7xXIyg0X7aOa2TuOR3Bt2ETH7MXgT/kpAdYOIodkUzRwU41hB9wVUPJMkL+aUAugrrxlPrzd/PSllM4w" ..
	"bkMYPW+i8Dh2cZNv6MQG/4ZTjV92qlcGRa1iZnEyDzfsW7UzBuHV2irPqWtQJW76bsbm768G8FrmGePa8bvkpkEg5BTQAn/ZfYB6" ..
	"mME1Efu0iTod8d+c6EiJ3fvY0ChjUPC6bBMZysjxdT/wogP1fCfDBO6PtsM4k6eVUoJAVpJfOxlznwLRg/yqy5QzfmqiQsMq5Gi5" ..
	"j7dLfd0Y8VjcGA0285Aoq6nWeDYJ2ai3RrCb5SMGLsbKkBDmdVFH4aARPt6VHM3bbXWFY3u63sd0wA+vywkhNat6gSfPrwt+sL2q" ..
	"LerSz/mM5OJBMCq8pi/GzL+zSeHrIawpZ9wjP4O5Y81K6JH9bbvDlGP4Es03SXeZZHnUIVZB+oWTmi/U1yeK9zuEFAq3aHVCoGRY" ..
	"r4FEJp8J0fuozUBteui3c9R2pOR/w6emsvupDKbbEXeD2VlLu+ZgtjyQUos8d1sYRoHfl/RmuTKDymXqL1uKjjw+oidOgCL2Ma59" ..
	"ITU/1McXNZajjBeYCmaUrlswx/kfKj1BF1X0RHvcNkrCf/PNvmtWMU67b0kFmqw8jal/xtbyWqlIuFGZpKHNZP4AqiNk37sx8zq+" ..
	"icKll/nZHWq6L1uk2TJNw63VwBEAyIOMq4PDA3diE3GbVwdv/LzDLhKQisbmKXr/tehPIQr1HW4BHgpvOmjb31kmPgy0UEtV1JgN" ..
	"AGZ+6VVi3vZMAvRbLwGbwahRnE/r90XwJinIcweQ9mRfwR3FEGFqYlhmcWI3NH1cK6aFrxn1X3JcRCiMxCQE3UIZ7zi1hzys9aBr" ..
	"9kyR48dgiPuv5j1FaByCSGYY2/fZm5d6Fqdx2vCf6IDm3uoHcY2AAcoUrx0WHPK76uEyHehTHuGVoerGgFskw+Fk2REl40YRFRzK" ..
	"53G7+Dek03krEkzrxF6+7tedLLFRufh/zpLyFLsXhnfsjtgagBT2pxulcZJ9rtc8pm1VVeI8AU89PQYBfWuZcK4sSXACzTqL2StC" ..
	"Nw3hwVm/YdbpcZuN8uJdCtgQt1rOxDMgr4gJbIQpnC+UVAM8bozl3NhjUgDLHohMYYVhL8X4YbnIyQ14ekARvmH1pStker4El1q+" ..
	"YFTGWV8pr8btDy7eIOYKB+cFyTYWSp6+XEvDywGevXXmECrMcwoPJh+kLgTiPUNUEkXUdXnB2kJvC2vDEmdGHZGrVSarypqfce/w" ..
	"yHp1G20rEF6ATO6xOTfOs/WTXpVioyEw9VIut/Gouywo3TbtUFxw23AFWtOWhJWHGXOaVeWdzICx7X0u2rcrLJ746i+I+ITwFj5j" ..
	"DWhaTWQqEGIKHXav3DPawyLKBnjxGvvORVuWeerQqJJ78ZmKCx2rnM4vZ29VCJMjX9ETRS31g0UDh1RzGpGHd2V2xiOotesEI1zw" ..
	"PZyx4pJN/+ffDOc6m4MmQDaDwklxlNL2AT67Tnj4StVaSiuDuP2q2l0ZlQBXgE1z4hc7EVgjO4tVI9BKdGhTKrujOGZ8q7CLscJS" ..
	"OPeMiyu0jBb52Ieg+XvJiLKE1NzQpniLY+um3K/9UHrsPcYqntz4CMefEZmWwid3rsjUZ9Z6c+9ejxnGhXkSW9rYnH2FDqK6VI5c" ..
	"K/52SnHlPPrx2d050KJ6kEOUPTwD8d1WuRHvqELUJi1DTlB91wpApnBkOPmFnoTBb8tvbs0KLYa0oT01n1sqLRj+SM7yVnHsrE+9" ..
	"j2vHTfdTSvFmSOI6Hydt7ru7frbS31mM1vQaGTILDPdatfOrkJ9dtsGUYCWaCQWFAL4MHYMLY9Cpc5bEC3nk8CQOvPy9yYQDzJBy" ..
	"6/pEiUlksGb/cstkmz0Du5uPJO8DPAnvK3QdIQnkdAOB6eAbpAocgwvlHOtZKPIIcNghtEeCKZ9VHEg2FHN8mG1SZVZiXSlShzEr" ..
	"zHEQhub0xBlf3yrL4ZIfdfzKhoAoHGCg3YAo1qtFoGpHzL6UqGYUNuHg0O/SxZxWjO4RsjzVJ1MJd8TCUA33Jrneg6HPYXD25UPU" ..
	"3q+Wlc1tJiJx9VXpq6l8j3EI8CdfXDsSXDfJYahGk5pI+x4lzAav3hw5x4E5+41vIgSx+Mf+EfP9YFihsjxYUlHFvb4yfwQ0I9e6" ..
	"7VEgktWIzrwXDohSUc5/q7d3vwBje3KWMT5s38nAmLBEtQ7Flmxf5H6Eq0E7QjxTTw48MgzNAByM8AnoHGfolyco1W2LeHKhBntG" ..
	"3lEYWp3BlS4nX/sjhD3QFTLfaDq08HN43V21bcMw5gwBmY/oVKwsAkpKZZeiUngsu9doDMjZt6yDhgO9XKZ0NL7zSTneyp8tWCOs" ..
	"fCZw6zQZBfDOLe93RVjqTI7ifZhqQ/45Wz40J24GVh/p8JaPorww5xl7h3hnyOV4GowKVQAR1rZZI3d2/GyLXZoPZNwrglp3gBEg" ..
	"M64/i2iGtXMiB7MT2fwiK5yAGLdI8Qd4+P8o+5o6jbK4ez3wHyx9tz0TwDRr6HTKjG7zIQYsM1zFqDTjxX0GLpb0hafsPSyhzuQi" ..
	"jlcrhrpVGXboh1BDGb4d/wytDEtkZpe3YqxhTjQU5pAgCg688NeIxbpurlBZI7Nh0+GldZn71o5WNJsRjG1EUnW4zYBsFdIOzR2x" ..
	"UHAZ0gqJN3iGdZNLaLRAJ2GcD0hYT5SHxWKxqCivRsWefgemq8I84rqOvqKPn83SmT63eeqDxtjKVwz4zg2bE/tp9tJw5uUraBYy" ..
	"pmfM8dtqRzqpq+Ecq8NPUTPdbW+i9Y11O/eU9JTwh4PiTercGvv8bgdrkN0HsdFLWG8ds/EtQWEkcdGtUNQQYT91ODgr36wMOZnY" ..
	""
local PAYLOAD_P10 =
	"FTFh2KQQXVrW4NRG5xS6V0zDsGJBEsKr3Aw0AXZo4UHMiC7sIa0KsfcZdilYixvkbPC+9B68hKN3HtudFl39ekqUfH8TzuZrjvpH" ..
	"7zsgIn4F6Ioh56Ur+rQoMdo0VYRpldU4phNrjI3B19Qv9P/a88NGE2B66yJ6kwHyF+R+Yrnp+Ksxqv1Yu09N4G6aBuipb0QbJtyl" ..
	"eqROTliyPHax2p8/w7vomyQHsUUB9iFhjlu7iKpnp5N7uQqanG5d2GGuygeZh8JcDwkAaLlNkgtAFNAsRYdz7nJpbRTtTKQEGojJ" ..
	"sGyrLZUnaO/LGFHwqN8VnD7awpBMFrqLysECrdogt2SFT6eY+HZDE3TWArBoaSSsWymm3LJ7dQETgL2U7ZOU6fAqM/IRKmcArdXg" ..
	"1ksuTme6o+HClzztVfo6HyqJkM2QA55hQ5ygGHSWbS7z8EvC2r4whTNSmOaI0OCLVVfwXgkARMXtd3OTXvYNZnOvoueQITVQE3ET" ..
	"29IYwAWQjP9xm+5Zx+ylbNIqtvjvqXsoqA4HTFF8dhtM9P2UpXHOoEl6GVJmoAB454GHs89OdsATSvX7ove7yhzQoO+5qXyCMn9c" ..
	"ARghVaOgvMG5g95N3qpTCKttq9eB4tjrdo87LgHFyo1Sv0XTJpANcTMcn5L2g4e3ZpvaSpOnxRUyNGJcSsDp79sgcLsi+LXNxeNB" ..
	"mnWf3/TVUFdqt+sjXrRJR1JXhGDAo/06b6rEqIDvMZxiHXWYBeNNNyRiUSCjKRcaikz3du8qccwJ4LVm+0I8cBtlHbXQz6o+xvbH" ..
	"hWS2tJQByDiBOK9etfOV6ZSTxkcKMfcEI4tUoCbK9oJo6ukwce2OVXa3trCnE23YVeH9psCAc+PaAFY9VvpCFSjyxkUeS75tl08c" ..
	"bLeR4D5SVkH24tCfmZ6RXizqWae+6/DFFJ3gwig2HhI6Hbk6yjKZaH9IdPUX82LqUSbw3UVg28j1DQ94KB+RjTlHxBuyr3buffdl" ..
	"tvorwc0Nsa/WNAmfpQYIhOlnIhUlBdxrFvenrEQgMw3Y9Ve5jXBJOICWnQSOY+jxcEasR15QxJF4jTlyrM1P2cSDxV9VTgHyoFWa" ..
	"rGJ6Ur3IGz0jJ4WMSgPPVH1sJPientyspuCxip7tAffc6Y/ILjMjvh1lkDNFT+6JsfOjxnMELPU0f/DjTNFbPVTipAk/P5Fh5WpS" ..
	"jdaEfpIriTbGYWmjcsrRYeKHeqF7BH09MtibEC5K+TbwxRWCGNH3ZPZrCxkOpjAYCy3nPNZKWi8+mudPFrq14RGGCfW9aHaAIH4T" ..
	"WEdw//58e59r1EW3uku14mcp1IMtJGSvE6WaZifVeObX6bKnOvJs2hzRFlR40qpkR49I8FrEhlhzESpyRs1sMWX3ypFgb6FRbjlJ" ..
	"XHIRO5BhPcNRPPL/p3xs2GaMj07xNhyffuKVYU7okb59yS0VLiVUmyQ0FK8m9mHAuJtUXH2/saw2nuG4IA20ULQaLDLDlX9vWZU3" ..
	"IpykcJV7cEf87OB/jm2CNXqwDT1MRlp02EWPGV7oU5iSW6NuxvrjJNdxOKOGusPpOCaMnXSa1OTEwxHfKrZW1of92WPWFDtq4wxA" ..
	"pSp9xjRxi0Exxg3u9a4uGFUfOgC1ed3eoj4G4ULfM3xRHlv5capWJG6qg9yz/R6H+6Jjk95DrMBcLUb4r7gJKoMR4d6jKfn7R1xh" ..
	"BQiWkS3W/nJVbYACIZgTGcw6asYAwctBFB8RbT2/+QuGr8bQpJIcG2Zk+bf96NRdZoz9vnuLvDkiFVs8g9+DVSB8CSilqClavjrK" ..
	"u+zPsCFR4N+ttNH+eYJno9TBe/FuGQrzzQVCdYuSZkl2F6Hx2xA4+vJ6FmH2B9UdCZhgGrxcOlHZo3/0a652HOVqasGMQu9xb61I" ..
	"91shmZGXqwrOrozW8U7DB1eXLvGWxFVvwBOiLINczFJ3AXmr4Kt3PLaW+yduhB2BSrg/0W/4ekOEvR3gjWSElPhdLaf2GtbC8PKJ" ..
	"iu0c8Q0WWn7pxlJGcR5GBJsNkhtaJD0xHEJ21c5kwPgUnZ3xjOb3VVQqeXyMbJCKY17/ZneqCY9KISI8qQjIAJtb7KEOiNZGxNMX" ..
	"mOpXaVFsPeqacR2VHYMYVChjyUdpwMniHgDgrkfjK+eop75m6SZVHB7huPx4nQwk4GHboFTDAF6k/POv1TWkjIgApik1nrIPL4YU" ..
	"Jxt/d4q9qMdD+2r0PSFjaPVGggIadmh71bQcaIFTYoP+SsB49kelKT8OAsZH/E/0Zy2dkC9NWIEUt6p1Hg3dNIzASiRojqSOu9a/" ..
	"gsedmxY60GC+IVZYnKwxCXoW2y8JMD+Iq4lIT9HWIkGgGNu9lMzBHa3+OTdOAwY6+paRodP+i6SGu3PhkXPPxiIO+JNYrriZz+92" ..
	"XJyjQtxf2bNzFDejXIWCUO4fGIZuWdyxhK9pbBizIBAboN4aNMIvJpdW8/KrL03BKKhgOE6B08t+TSXDlMqu0UMd0lFhlZgcETAg" ..
	"a9qkWf2JX2Hv8cvDAS3ROuWJLLPiZ3R1CNmUpIpoI+WKsY2faPl0wfkMyk+F+xKMciZYRJWDE6TymruLn3Sj3biaRKulCA6wmzkt" ..
	"6ySmIGVmnlw8A+TiBKoj33P0DTy/6q28hqQoloFMF/BJxRGpzeHT+mfEQuCBKA1QhPhu8QSLIhCrg3NLnQh39f2E8mba+N1X8sN7" ..
	"FuhjjiO3rVmpn8B9EoZjkAc2oaE9G7vaWQ4AKXng3728ZxrtbwyPY3UTzVWKc/jvRagLE/I14x4JbNsW2UezcycBvbc4KdQclIB/" ..
	"GhahPvb11CfDQm74g6BhK3cUwXCm+YG09iehB6lzOrUBrBc3DMjMHqnW2Jd/jJqpKqrW8FCvMKPtNOIRbk2EQzsuWzrLrSsDyudJ" ..
	"PQv/OSxydzYpbNJ5XSIT/LqDhVXy8nHrg9VpGR4sQqnNLN/nYdWNaOfbrM6EcLSnh6VwiPK/9jp4VGwPRimpYLzOsvINXvOyQZ5C" ..
	"3bpvYZI92eL/c3hNx8FjbUMdoa/E+f6MsEYRwhSRgdszyxmiFfzBNeNjcVMLoxA3UuKs3UEafc3HwajT7p+gzg6fR9kDexw4CxMA" ..
	"7NT3IZD6utFrnITqPAH0YBNof91FlJVI6/42wqj9gMZ4Bp9z74mqtTFm526c4+sTruhqSKfpi4a3B5/lbk2VhYhe29yFg3UMZtEV" ..
	"I6vaipYI0Q7KLi2zzpioOt4g5uJPKpCy0tm9Qumf42wSjaJdJiQ25H7Cmi9+kWOQON1dXY5X4yPYhT+DT8ifuUFnLZaDfsBtzjqk" ..
	"dWGpMRIY4JUnlPi8JMi6hUP5yJ4CvZ7KyiDiVqeNcXY3usCkScNNxpBQhMvMGcDbSKSepOmTstcRysoBd/vmBPWs9wxvu9XMEkxl" ..
	"5tBG0NzoD0CSAcypoeTG/FZwCCGf/i95jzkTrMi2kdHkb1aL16S/O5qfqJ4hANKCvjNJ5v9NL42ofapeRYqfwYFa7L2/vrSe4Lp5" ..
	"/gfAynSoABBWN2D8rsh4YA6o4Lt3iXG36i9vUqJo2GKTRXQx91kQqt76rXYR68/+4eL3TwBHqh4vQZH3DtSbTCHL6Ei3zNQYcmKZ" ..
	"qvvaYfDpz2D/ykND/yPGvOJjymTHuWqe+BDW+U/DR6p39z+5CnBncr8eBMI7vhrrQFoAxEPOn6wJBgrRShVr2N6vS1JxX3fT0gDC" ..
	"/U9SrnIM6DJj8qxQROusSibFixPcz2arICgcBYI8chv66IAYVrwa+BMuFPKUef82l4e3/HVBWoJplw9ejCYrIuf8T3RKYopCnNMB" ..
	"nXwywn3uBy57ytsdXX1uwUwWFIsRYG/UmvdxVIKugB4ahAp7/Yl25EqGgCmLZE8ond7s7FGxdBiEdxh5qeEh1OHLamw57OmX9OLS" ..
	"l8Gb370O1PaiFlMpw7IbPJAcarJHcw3ieyYjOlvk5OWKB628OlCEpYf/nVToOjvP/lsd5v3x1jFbIiSXbSBX3MF/kWQHyAbpsMCR" ..
	"sbRGC3rSPj2taDB/4KmWvMaRhzu0xUVcDrjLeuuM/6OWAtb/S41WY6JvLZ1HP022+oJ50YYKyI1jlgYt6Cajr4cKHmQd1FNsMVlN" ..
	"I1sOLHDW4R1HX0p2wY9rkFHPjPxTJwxy9BOGLs+JdLKUfDEeoLY92JLdw1Y+Bdd12RZLUG/rbnxxlf7Q2eKCxEVWiFcXPlzu7xpe" ..
	"DyyDtBO5/k7Ut+RCYNLBVjMNPRAS7a7FJ6LKBBNK9HJ/kv+hOkS5phQx8PYTzoynR9hx6+cUR3yj8k+nh09e23xJvmHNGQIU3VvT" ..
	"UWME7E9AOOZ83z6KAlAIMD9gdluekk5/kTH78e6x8wLbzt6vA2SHfRWSgISTEeMeGcJBK7CHe4Nu//RAdvKjjuA4Bp9LP+vURYiO" ..
	"oJCX9KRv83+v1+vfUB0cn0wxAfxwnsN0iOUpTdYHAoYYLXKo7YOgvk5fAWEtY/yDObQTvziNUE6ASM6HmMSEpTJskzRNmjMmROm7" ..
	"P3wBtUNvoYkD3eq7QHgHzEg3SpFNebO5AySgmJZgLFEXiFZ5IuWL0MglE5nNmvJvh1bL5Mlgc0s/KBBOIDAtcP13jo2O9d3qEoAC" ..
	"lfku2Sz2MfQM5cX4eZnfG5XivZSnjlA5EGfp7g0tvhwUEncYjkoJGhb3jX9/9jK2t1E3hvNVWVwzLEHglgihxjtRPkLkgp0L+Fqj" ..
	"h2M+4XoEdk/Z7EzpZPGu2DolY8n4Bvt5e9LxIoclyCPIqHOdPex5lWL8WPMNxyqZS3HoZTVTElYVQNIWzXP0rkEtpvVDiyU3KjXs" ..
	"+xGDXQKB1Nz9MI2OiXKtbtUX9Riqey9QUhNVRXAya62b0dfiWWSsCBPtxleMUMcYs421wLREtfbQ8/sl356coSnx9qjzZKoSVQKr" ..
	"EabY5ricH2ijb4PC7IL1BH//8I/3xp1vH5FLoPISAZkY2SSrKpqjLKKTXFVQhWLSdu5soycsbEE2JtCbq0wuHsOY4sEGp2ECxMGO" ..
	"HU+D6IIlfIUEE6vlgRvNVdjXWdGyOg3FWrScsFmaqXAb042L3bJVpMajkdpdpepyfIx9C65u9efBOMvvy6urPT+IucseQt7B0x4T" ..
	"ttGoUQWTXhUaSirEYlQ9CP+eeOuwv0D9+XBDyHNsrNnv8DC5DWTLMftPF2hxCh8xiAg7IghjRAg1bpmHg+oxtBwlEsVA7MUlhlGW" ..
	"NRbQHAkenTJMYpm4mJ43X5f5SkatvIjVJiYKsSROLrAdmggt4F927AsdZWap5kL1s0J91S4nYVNDFpnkvsbnV0ihb8WiVnMAGwFa" ..
	"ZlpVWl3bjmZKznwX7FxGOwatA2a+bfs7fCkQAEfCUYxSM/GLjPqu6cY4P1/IwphLdNyLCUKFVOEPhLxSkoB9gcON43Jr9XYeEKVz" ..
	"swF8fvGIjmTBvFWcSpdmvSzs0Rt8bDShov/ja8fvEYgbLiqSR2cW8IZ12/QWiZROuooXDN9vebHfUkkl4WcbouAgDMEvksHE8bH3" ..
	"cmBY775qoiH//QeUn9OjZRFS6BbNY0VG6y1WSi7yjwjNFZprOikjMPGoz7rjefa4E0+FL9h0C6dPda+PtB4VGANrvreY713OCs/8" ..
	"eSWkbD1RSgfGkl4pDCRkfJeFgCJquV/T3nruDVj5NqQ2sC8KePAJAMlEJHRcGCpXb88+owg9hyAbKAOkRCYMtzznZFVQ1adrZPDO" ..
	"QsCqHON3EDlD/n/o9ksJFscV+NE0ZqbysDBwIr4DSiiUzlF+V/D1JPGwOvt03TLuKmgAMVbENtAszU0ll5RfqKDgU+hZGqRExtFM" ..
	"VsmA32dkkjOps9Vf0Mk2s6I6biOSEARLHO9DWpB59nk6hXhyjmLESsEs6RvYTuQY7mbwY+7RXwihgPwMdqiOhoB6N4ho7sTbmejP" ..
	"2VPbUA8UA8S7hX33MwqnlJxhls/TIkaJw3v+imUIb4CSCfOpSbx2gvSY6fao0+rykoXIsiwIoASBg1B8ri8rnM2K9b2mpkHBPaaX" ..
	""
local PAYLOAD_P11 =
	"WvtAiMrG3m5m5vphxX64fH5SWy5xgIo3vpGRQnEcrPUDFi9sByVgzD94jUPRqU7MPDY+JBgeTmfwqLwL1VWBf8LPJooaMhPT/tjZ" ..
	"+RywU5rgAioEa2NRzMWIxBdHPcvXl/91EIyP7nVbTAFx2q5UMp3hedXa2ZTiK1U7vBV4lJt6e+tbJudMuQzI7WLDwBjFVJ6yBY58" ..
	"T7gSdGoET2HBRa2aMilWo3JVYIhkN5orPDKkDCYHxG8HzEyDmgkHdt/g09WhPwP0mrOqGTxJYokrTdj4rLjiE1CWqSxStOEI1eJp" ..
	"BMXM+Yrvbt97v8gJ1Fa0qhGd806omXoYRJU+EjroyfyqugXPwliKlTivuLtMdr4IJyGLxm40QEzGfKzloFH7AwO2MmeipTytAbx8" ..
	"QNSU9TsasvEVbqrSytoGybD8EsevjrNeB/8+KQenXKYkoVE1a7RNQiMWCkqf2idtX6dLRKuW84/oNDPIg8CLrPlww+3YqVcYQQwN" ..
	"48MRJ0jGV0VW1JltX0tXc0LImDoX/bTIMk+34q0wb4qp9kZ9/1VWmF5cfLKrRcJ2Qi0gRncMK0BN84yq0Z/kYn4pu9hsMnzRUOuY" ..
	"eOt5yxoDre99eCwNcssxmLzfH/7McMA3aqKeIcj5rljd6tZYVune1ASUTGHkZzob3g7udg1EkRh7dw99b8604xal8hMKBjCVU1NP" ..
	"gVOIbVUuJIHomCp2BenTfyjYtqXurZcynIKnz7uMls4WHfGNiM8ex89kHxiMDpu3VZyEfRit/Fduv2q0XLThQNigoziVKo2Ey8F9" ..
	"pCAM+yB+yeT1Y1IFDgwjxotqQxKVjg2AuYIxoZzUHMGk/MuMfTJW5TdP+BgZAcJ0Dsdi+unITWI5VIA93DDTrAde6iHMHrl6VfvZ" ..
	"Ikf3hVENVVGKv3PEjqSZSq2QM3fkvha21ErdTg4siMu5szFWekJa26b/O7Hj8iStZ/4qiZeX/1NTPwfechqECfD1zkR0G4uiMwCH" ..
	"0yMRQz5QKaSrPDhHVj9GHo+6yVN1fsKp69kjEMbyJ4+nSfat2xmLZ6fKGhcS+/t70VpdVV/vUVlEXUvXprmpudUNMJOW4b7+8Z4b" ..
	"gCdETHFeX74LlOV0iq83laTAmFXkOwuyjpB9lCY1If1CNBrNBHPEX308KxQcmAL/UoKiK97FyVKS762W+ZYx2jCTALs+yHwfmO1j" ..
	"sqstRgUgwWC99LeFZe2AGxtS2oEc1M+aZYHGyC7EOiMg3i7qQuiF+LV2Ucsd4t5Qvzqd+me9v9RAf+LUM+Ry9WKDv8C6bSdm0q6F" ..
	"yYaMsJNB1Hd5r4TYwoUeXuJMuw6tF9J2ME2qv9yJg39iZnoKld/f7IX+910Xi9wibHM/YvRNU+cQzuF7mcqRrdmoJl9eM2fLwSIg" ..
	"bve1CRiKy07WipAFxj6lFAlSLF3eURVVXgB7+XEzE9qU35GCsF8hcjBt/qoRfD/fQfeZ20hTG1wOJHdpF+YlzuWxEio6YHIrPV+Z" ..
	"glENT1CZ3K2Sw/ZPvWmW7yoR5NpesGzE0wXNgmITxqFnL3W4H2XFYl0yz8mGFYJGeAoZPDEhHcXKzzRU3HO+oANRaQrFJlOC+AE/" ..
	"EAsl9IwjhxEOrR2Qmx4ILT123hD0LKt3Ma/ohkEK3T1B1lPlfrl91uj7hAwmXNxZ9NP0oSmX/6aE8aGbN9uWx+zKc5JVqsDWbB4r" ..
	"JZNHqFsOvd6/Y8u78OBvguQ78INDOFrQPOb//eKWkL6DV9rmWj4N8igp4CQzM2UoN61CcBSWFw8QWzF47bvjaSfU91gEk9CA4tG0" ..
	"Cu0VFE4CoLo9Lbe8Gpazmne0TGJ948iiA5X6CDGiFU6KXaajpLM8g8lj1JI0SBEG3zfGozmBYN/i5DGbbPgaXHWk033Asm5F6jTp" ..
	"7LKw9FAhUxU7AxvEMfOl7n6+2+/3rmjd9p+gTW0Ssl5D5NK6+F/2FS92ParsZk6siECOkjss18gojaJ5Pw8SNQR8O7csPdDqruk4" ..
	"0uYJIQ10eYQXFqv3/2wyeDeD3WUEeV7AZZWn5Ep3daAGsfopYbH9pDrvycpUAJjf2DSVYGjTQ8QLyB8XWq5uidkNKC0OXh7k4PzE" ..
	"+PR30zfcvuCtEtsMef1wVLbJyFvryhlIS+MbSWwiTxsj05yW5P41qrvPy7Xd3n+p9Zl5yebf4Guwe5pJXmYU+Hfazy768HyeeXfD" ..
	"hpkPL3KpdvQbx3PScExHxuPPIrvcH9CiPk+CUDphwCt36YOn8t4mIVHKnZ/f6OccTYFJkUPhcyvnAIPQ6v0hsIY3ihgkbONJPBTK" ..
	"2r+5Z5EKY1wnTwNbDnE8H6pp/usOsDshnF/YBjdfWFo8vA2OqcqJc7D/xdhjWGv69+yAYVOhBi09sA86JuiN5lc5hdL/1WyUbKEz" ..
	"d7yXNOctPsXgV2jqCYQpiJNp8y73JfPTeTDTtmAey6rC6/0InZ/TQJsWEw/9bgMUOAbVCBbJpgpGUEc7AKZ9R38yRkZ3avow+iXi" ..
	"nCefj2yk8HpHuAo/uEXcIS9gMuB5bqlJy2WiKcPvAQ3MWaW7uR5EFOi4awYVhGtkG/RqqUYywEawwWLBBeByeFZV4fYyQeq8ElHP" ..
	"sCqcrzFCa92I1ZdrM3LXK3+LOyeRdVeIYHOsF82HAb7v7bOFTA2f8P6SJ63xjwfZBG7QKcf7JELGmc7bktGe6IZkv/ym2qszPPyy" ..
	"+c+ihLOmfgNGK3LwDFFG/JrabC61uG45ZUvqxnHLmIem3ABIJWrKSXCj2GcM3IcrVZhMXrhy9axzFssEE3jaizFtBfRDnnWF/3iR" ..
	"t75agTGRGo+KQZaTU+rEJXDmalPyPdB0EcS5EoaJu5tc/NcVGaGoWwsRWOqFjpc1tyakUj9ns7AWtfzd7OHkL5JLvRvqsz7/ZbZa" ..
	"6oqgL5qHaUppVJCdmhAOr4qc9dqcMoQi+OaZVF05Ww4kKJ0x9ywP010y/Ye7/X4+5jcF+BiIte1a+l22vfpjzV5O4EJl/rcUOChc" ..
	"87i1io0knap7cKnFAXPk7rBBQZhBbkyHmZ44zyVb5qX3a+L8YxJ4oQ2eMoYnRGoLOf3OfXC9bh+C1SZcmyJc7t+zZjtJ7/+ujCo8" ..
	"V7VfJAFIgN6HShum86Phz0/kbtImvbmMA0aPGQzYWtctL8fKyDVco45735utvg8UydOh6zU26AetFWjvJ/Al15dezUytA4lP7xi3" ..
	"h1z2UY3MWlP/dfVnDINJ708jw/jfqLcmfRQArrmN2Md73hxPjTI7kJ9p3KGObO0C9gWPVHyBFOxdskKWU4Dmxcd5/GUjbuXTqbhU" ..
	"9k2UynUyvF8XO9axSPmVU4oS8k2435KOFt4hNF07y09gPXMHbuvtwVbduXtYUyWoiQ0zQ0x2VMEZCyhwu6wJatU6OXck5pbP+wfy" ..
	"3TiCcDHyM1PFJ8LyfvrDDhhcGpkVIRqmUHnt7nmfkzIiePy6tdkCfkCBe80cOWP6giW5bV6J2GAMWffOzSyp1heqtasscExFXqjY" ..
	"useb7z/JHjKcOCkrX8zrlFXb+qD4rAxhQOsPaS2besU0Hy3AlqBH6b29cNlpgojk38aXSa4g/d8f5ZkJ+VnmqnNo8PAVZ+rAFeTp" ..
	"E0I70hi+9E7O7gFJQeBbOWJgs41+boLg9MwF6vSYcQZk+SUL9F6TEP/fIIgfZ2E4Ycs+xiCgWEOgq4FG5039lb6bugHg1Nqk6P1e" ..
	"I20zNoGdEuzKXIi2mnt2E+6nxiztfjbKyHlayBCbaPs5TQTZ6lWytJTto2Mn0mXnRh6AmQcQeE+wjCeixiaMsy6ihgk9BQteTN8N" ..
	"47bYHhBz7+nOZmrfoG1mgWWggY5fc3msMq830CBleRIFM4inTQRm2PVDDO/A2+r0jOZtUtTDAVIXHjF1touV2pUewBenUzGLr1UL" ..
	"CN9MNqxa/Bj4uQVdxB5ieLSzCjI9YE5hQdwnCwso9NTTA2lOsGiShgXTjO6oLMvW5Z7AoPgB16nZ8M3BbCu4xi2yJB8aEyPKDUdz" ..
	"4wxVMclJKCMvlzVIF/sbv6NsBOFjoff49OkKPmbFW2KjkqHViypvIayuLGsWlzEaqxcRRwipjXxElc+H/q9xfijsyKZAI2pU3Fph" ..
	"9i5lBUb/nQTeBPo3RGFD2ggAl4yLMKIKovp5qn5MitFKd03Z06E/BXS++mRNsN+0uwQ/OXgRX+Pj9u9DGD7OrQgbtg5xIHFxCSIJ" ..
	"KTZxvob4tyvwqbu1Mdl2uXQvfmrpYHQ6UjWIUqAKB+EqkTaypU2/E29zL4FXtJwzE5FICG7IhdBqvHMKnNwJsNjNnO1JQJI0Smp2" ..
	"I/XzEJxwRLj0jo1yq2NfLaf7RtjaKRCAqK/UxvtS5bonuH93zKqq5UmNwy9OWBPt7lMGJUOL8xj31i8HUxb0UA3w/3fgZeGiXSfb" ..
	"KPOLIx/uMSvfelf3F5XY7DEPxP21KIyEvF/bIExJNKH1hsArAZej0GoxpTPBW85iQ90fQbKXMSDPdTjwEyrWwPKawrVJGaX4wVGK" ..
	"fNudEdvxuQT6NmqX2Qbu2eeS6Qmp+uCRwsiFblD8x2kxlvtoAJNLnp9vgeAyQ8LxmPv2AsiPKrnzACSW9DQBKEUkQEMjybnsOArQ" ..
	"KKogY7BINGwMcasgu+yvV3dMs8iI7yYDY6xp8hqS6GPbOMlSoDm9fUFlXeGoL50SRFa+0HyHR4xfxkB2+We6m0fl7BJ45ZyoP3C0" ..
	"t0NROnFR7cBTVco76UVB/UYiMU5CJ5ztWRM1LqGQ+7zbDzX/+VQmnznCnbbV/2xQo5xgphBqDYSAdzkvbngsmV1liEsNesBmL9/T" ..
	"7GdrwBGRxF2rhMt4goi8xQo0keZT4pYYKG5bkod9Crd/TlVXNW7R/LzMgzPSF+pJBXJiw3+D0uT1JnfdpPOsf/bNpAx9z1chrujO" ..
	"SvcbuNagD6Uxv1ZGA1nmAhDHY893NWcIdqsnLsM70p0niD2lqxqqxAm8vpacovMAVNvS/0rc6quTbxzva68UTY7zd4XrYDpUbwDj" ..
	"FpUOKp0Q14WcUMqE108KL3iNeBKIbpiPufqUT7BJbTqW73I1Es7QT8M2SJtfR7zcYDzNXZF9+CN8YxGX7/pVmDDUA8FE0j2fVfMB" ..
	"wYbW0wmqwy1wHQWpvRQhZOb3sYRZtW7USeCLnRHlNLQJ5qMd+W2ZrWj6ciBe3Y28CuBHggRSHhDTTavUgJk9/3A79fQGCu0cT4kw" ..
	"0kYtH73qUgZnWSVfaXrGp1TwIVchlk6tDrSeDjzNE/qJeLXkNofS6wwB7mm8wu4M8eq4mta/CqLCKUSR4w7M8Djc1wPHKpPwiCke" ..
	"nZkxukt/RYJ/nM9rg6uHNMNJgMztqLMzZAMOLMkJPTy3pc7rehyTcMXLEKD+qejY4VrhMzPZ2GNxQZjwi1WO3PkFVVJINEyABMfG" ..
	"IB/CajsJ/wtyvnJi3Jc4ME5WjUd0dpiVhUCm7PaJEfmBPORTjBQFJSdYp6mPkEL4bFmYi5isV0fuSxc5BsV5lhAz8a7mJ6607Q/O" ..
	"TMRZjKgopEAn7KSwo//f/4KovKSoBg6yBZeKRHgfDT9B4F3SkpnKTJu+ZvRBtO9ZDa1NzoH5vA/A98C29uZxsOTvuNaayq5Klj2Y" ..
	"0eHTmWEN2Db1KdR1Fqm5A+xZi9SEU3c7tfxVEYUYVXUwWqVWDPlRqCfmVcbkG0cEC0E0I8g/4X2tqoEHaSc7QRaoH7Dw1oP0uaQf" ..
	"DMk15FMtpcLEDCBorC66dN3regAuZBwYJ6C4wxTQnxqj8pKK6+W1gM9Ml3yqmwXCLTM2H0QUmYu92J2e84pK8IOxHenkL2wCfJWn" ..
	"Z6v1ueIrax5qMMEYMkhHEOGTp0WSjwCIB1CTD00vp5IJD050q8IWydw9bJKaGODOg0YODf+YNuJUKDKLq5N5cnHrZhvamQTxFsJk" ..
	"KYfYB/p4zKL/+ZuosMuYbKvp2gRQvk8b6fzjBwuNRVVSJzMG5/QaplX2vOHkpiZKdCjUOO/pW36mTbKwGlfAfRLk43ZDySZkUWZg" ..
	""
local PAYLOAD_P12 =
	"KYzM3fgBq4KFO5a3KdURlC1f9et9WjTgNFIPlN6oP19UA9S7K6AOBd5ewZeBjqMsoE4Vl7tm77oNq2wrFB0q/bjwa9UxU0d0+OuK" ..
	"nSdG89ovdsEiKmsEKgACrckp81MbhQxyrGfU4fM7gcZotovWAT/+1X6itZbtq/jBx0wJHiqqIRcdAAUdv9zoF6rO3A1gOfiejati" ..
	"UFAbU+wmfk4OuFiYvNB39HAG+4Tkyfl77S1Li/lRzqSsDDUS1w7ZJKEbAp1mzeewA80nrkYYdAS6h3vBOUCiGSTpD39JbEBUuZ00" ..
	"jkAsYCUC5vewa5UN3eX0eA3HhZBjSb37ixNpAfnxJXDaAGyiLcp/lcm4lwpW0mx5m95v5HrSuYOqBMJOPzrwErAggr2wLDius7av" ..
	"W24jL7Al8s6tVEQnnL9UGA0OF8MuTceOGzKixGDeSgA35xvUwgi3xWsIt2DFqwciRPFksdtKIclffH57yJF4dwnZa+z4j3P/a7ZT" ..
	"PM1Sb1wT34c4LyaWnRoJ+y2qweiWpyau9HhahCU17VrxvCSsuO47KIgEH9ewrc0Z9mcc1110ZS9HpPyWwNZJXsXxUGgJVTkelidf" ..
	"KDoDs/34f5L3hGZWoa3jtIMKrBBhMh+wH5HwsPfPlxdZdbv/yO8l5RanM8JZ8isyuWAyTYYsfv27pLz1KkiJWzOA/dSKqGrsPiqA" ..
	"txHc9hM3G/cDKRmDXLLWmGYrVI1+KtyfJse/6ypRTXF4LIjb3OCkLnUQ/bFY1kUuZs/LQ/mb64UIujpkJKUGksyi6N8iKNQ6h4A/" ..
	"vgNAUyYC8MeFoozHtHmLlnr8T6FRAU+DKXydYPm7V2zBOYd58cSl5LM5cQ9DYzf4l0rqE5x//gRnwTqCmOuv66UvpphCevREL3TB" ..
	"jzOa/VaMhcxOo7vY+Yq+7aA2JPLXhT59XW0IEW+meKhqtkvPBLjmFBDVl1KxbyDl6y8uIm2QBB+dyi8yJEuQumSsP8kX0jIk8g4U" ..
	"147ptmPkuzAM0y49SmiwZ/VZdLVWyIixTTWCXHuKN0VY7h7WSSUud7g5gCwg+sg+UfRdlncOi02teJ8KSUb1uPYhPQa1iUhl1I6z" ..
	"u3pIuCeoVBMLSt0HEZ/VBo7p+KrCP+g18Ou5YBNNRr8jKegi7llFLIuoCfexrXfCbfiZzsyFJkyZ6J3qn8qdlZqxyqr2bQms3dQD" ..
	"X1/hRgPHrn9ZTi17CRsTYGyReDjS6okLiwQGVzerJPFDweDH4zQbzaUAw1xlHFOXOI2Q6lREfPhMuKNmfJVBxQsX+0IkORivA7rU" ..
	"3wbPU+2nmSMQkej6hLjbyIat8fz8+Kg2lpDVFk0I76Uve3cfh/opqagvi9I9sLHThuSOAOlKGDRYF1Z6AiB4xJxQ1dIcd0/XqRie" ..
	"9K9WaXoiyz/1vhyOuRa3yVgKHneCFJ98POfYk3sucBlRMXJDFSjayKcgIR5SlbnlnavZ2johzSdoZeOsuCqzEb/lUbSC7HdfP1zr" ..
	"CIEwildf6pP3h+OSU+ADwDP1Wi3FcbKDgZfH9Z2C2lEtLv/xr+5D4p2eU7PtvwTkl4+VtqpWcFHUxh5NhxhbuuidfG9pTHd68giE" ..
	"0uxk1HSpPa5zgkv6OCDqtLK0Afl514SOMsG2ne2HA5rYHMqHuAOdIUlr4AHNbQEQbZq8t8F59prn4ol4f4AsENaHn2H8L0GeCY4U" ..
	"Fmy35Z7teyJB7KM+MOhVDupTvlCRlRl/LtOiV6dOVDaZb2r1OoG7cWcvCfUTka1U3L0hi1iLioplcIekm6Lbf39v0k5LPQm93x7h" ..
	"B/iOmkSIATGWojOydUr0FPI/aSV8K/2UpoRjlosQ1T8xqpuUhO8fsMBsniPw0BBzOkD7hjLONMih1qGg7ui9lyb/R9Ww5CYUv0WN" ..
	"t+NXbzkKKh1H7FQcrwB3lA++fLRluahyQLNyssEoXcAne99SFASdkf1ioWngCCSmTOSnN1vSQHWP7BebgBbogR+g4ODyPEKmuNFB" ..
	"wuDgXbzdRm5sm3sm7K0OcKTBfFr++9t/ei5/bQslpllBLP4nW51X3xjjOZZBMUDu/W6tSXr4N88BeWFo6Nw0JGgsiwpVdxuAyQDS" ..
	"1qkgN6nqdWRXsNa7WTHKVId36M8IETL3osCIooz5nlnhGSVQ0jmPAcmFSGdeyf6nBmlPfGrFVCrH78GbOm4103tYmtmdT3UElo1n" ..
	"+y9DQEeRJs2UsRPDXm3EUzO9BIynmyglooAEsrtnuH4FCfaVXJtBn75b6w+pM30cmrS9tASLAqsQx/VEoALJVGNdksK/SziZswtw" ..
	"bPZJZiPAZ82ceHO61e0uNd0X8/SJ7HXPkkk4cPLVoxUOo6neOBGeJrEPY93ADBY5/0UzasvyJqLLkiNEPCpyyE2FGtP8iapNnC9I" ..
	"KgkngueaZiNH0IRVLediUaMbloMK6+8WergvPSoT9JMrHD/WegEnuwzCIt8QuguRJTL4+pStvDfH3Pn7yB0y/lu1/JC9n/7vpLpd" ..
	"bXI8DaRgiMhFoXwaZcDnvdKdoYB6PcIUPFvYvC25h2X9Sngg9VsbJRHHtK5ZRtH4eAptAdS0mLETwmkOFGTOX17VsdEbOP26BzPV" ..
	"CKFeDVMNLhOJ016QTwzEOs8WpjExjTcqekQepEpuS790B0LGaUJoyeHd305UKLR6yDdyaneIktqmonuxirYaLNfcnSxwmZIQRTya" ..
	"B98A+noynRBPYGgsi8Lq0a0/jlr0aSaib3JKtmTmpn3/xIqEktNo6AJlHWvzfkoo7nwd5XaOj+IKmq3smxQzuP0OG+UfYAIpAERy" ..
	"xk9z7vDB6ufxB85ywI0hPG4Rs5ct/elUQ6HXGpQpF63sTy2+RdHex9TJkb46ZzjugSN+ieTol5u0JKs3O8ALSfduXa5RKalhswOH" ..
	"uUmAlF+DuzylNrA9hsq0r3RJqFcDXEPI8uLmanLKXSGS2ZLCSB7wYEV+bi4hTJrrUj8lI4dDADSuxp3E1MjmKabNRoRJ+eznVOkQ" ..
	"+xKJkN762xo6JGK2ZSqeX853MBn3DdV2W9WBVm/kkDpUjJf8outERvawSFVPJFgphJd0Xk/5iwvyXbAZQh150GkAenNc9FbyQm+z" ..
	"H/KgxXUoIX6ul5P+OGQqeK27M/0Z4vzvA6NjTHRTUAYN4ovA8A0jU8BHUbQH3q52v+qzNus0QbP1PoijeADghRpaqn2YNKeoosgB" ..
	"bN3uoVrgzDsBhYa7EPKmJr0QeC/Mej0+xmBiFHBw6yWiPPWcIYWKs6m487SfNCJOrgHnSUyh6rx+qIKH+esF+hGRMkWN/x6ILEdJ" ..
	"QXWyj9wj2B8Qx8b8uBIDpsyQhf6gBlrZOCK4qMjrhdprb1naVMCfI4RdxguJp8rQIcPA6wORumakTzxyl1/mlxK9ix+4TpA6pZCe" ..
	"ma848nCGRH5wV3Ennw5AwYXoSxEkIoqHPg1z1XAZ1LgzewCOIMGXAUJ86LkSn9VAUc5uADOAIRz7CgEBdwXY4MDscO5M9tKSX7f+" ..
	"YPxpZ7TTvW2IrktkovbcBfkHYU5UUznep+2+c1hT0W3BGQlGF3W8+SlBvSYhgPwgU6etc5YHGJMOxfO0K+d1SjQyWU6TCaWil8hO" ..
	"+8o26HGq4s/RA7kcEzHw1DVIceNr39ril/O4KrbJmyITzS13rB7EpSN3z2Bklbub8WZNkgo4KpZXloDWQIe21SHVBPJQMAxmX/AG" ..
	"3FDFvJJoDhMzcIbAK9w9LC9aapx82Y2nJLxSXt6ViLEHFsyGZoKb4WfLgDRV80fp13lchq3e0wEBBRb+l/4USVorTKrWXdLHL8ck" ..
	"jqn7Ark0moDQHqU71W9VdQ3AEUdO3puYrlWmhgf/ng5w/h5nZAyxCu5tsyuTFpSuhGY61nULuT0iFZKQW2GuRTxlMD30cv5Rtzei" ..
	"Q3cIsqYKza0Ni3JUkqOfVLtuzZncWorVIV/Fw48fUjFipPUa3NNs1swUcRhGZJ3yXQThAvfLoUSa6Mvrk3X2HuBguO/TBun7BcEz" ..
	"VEzyyDKGxNXoUuFbOEA2DDz/Fm0s2kfn2dpEu2rNpJmoyPCFoREL8hfZ7R3QMbmBn9rb1IM4oB+G+hjHXknV30OxY2CrXzgjtgMY" ..
	"5RolYv+mxqmrFC24DW1xko9Ru/AODCxBiTQ4zyhoYbC5rAEXDWJvakZ529Hj07FGvBDaNXVv2T0nRqKqn+cG3NmO8ZFzMq8eS6ZZ" ..
	"CgYHRVebnm52ahrOyf4tuFzBIcXYf27aw6MTKdIncUkTme/J8O3kb3KasHSSVRhFDNQYZIbousY9L0bW2buCi6BnUdW0cdYpLiWq" ..
	"jMRwkvsLM3AJAK+1/QIUWBk/8O1kZW6lbH3OjgMy6IUO8xCi22EQIGPBwhfU1yWKSeUdbMqkp6zagPmGjrH/nvuO5Gkmx4cC2U18" ..
	"tupL+9gz6RwwnCeUre78n2PfhWLphO7PTSGMKNv48TCReAvWOgeB39SXnGW6piSIhYv02KmGv6zI5VBqUQ45jOCJiYeIQcIjzRmF" ..
	"CqhSMkV5abBY93MrR9qUYDyjfzR/Ha+F13usIXEWvbOsETBuU8yStHVs3N/7mBguERjHooQYNdQpuan28v8Ke40vpfYM3hEqEpcq" ..
	"kvXPCM1cdKh6onBRv536STo3//QuWWOQV/3ht6YC5g6mSHvH1KDQuSgiwwkNs3v+OIJNPMDnLiCeV1is2/ISN4smr+WUG504WtXh" ..
	"ydXJsDDrwsSis0zqYyB0fvhRC8OrQi+ey/OVkOCvoy3uno22IcpedtAWel9P4Gqr00pesZEExt8aLwTXfgH1FzZmnhxtuCQkdA8h" ..
	"amYm3+DMwh3hnAosUfp9X1hSO4d3oSSosyaK1QFrmiFVByOQRLROkUNELgZia3RprhDfpxHmL1qvwXEzca7GGZiZwHuObuXHOm4h" ..
	"UAjBRxMUGaq+PvVQi2F7MYwMxjH9rOs20zMfGi/GMiD2tV0IqYNm67ekYKsAolUro8qs4WqQqXlLGcPz9pDi6XTBiZoE8o9B/4Td" ..
	"4jb1Xy5pm3yiElUOgscCEvnVxRRBaOsgj4mQeDAdKT4rotCTwFqoS6eG1YpXRp/ZuDVaCQ1Lc8N6W6mRWH3p+WtRjfXcboo8DLfK" ..
	"NXETitsDy4W+SQ4XjO0KjtbOAPlXfSfTU5FqWr2LVt5AZzCVYTZMH21mGXUCw92KSjjtmsIVAwrSSkOxXPgm96EENl6/2SsM5urB" ..
	"Q6APBla409fzcnFxRwim7+1XzJmpZcl9hhlwmcGr+GjzjPJsM6ho+U6OJkpB3tRvoOXNtaXDbrjPUr8lydwDF+S2i9oBQgGr+0sU" ..
	"z5yRrn1lJWhwTs6MdWxS0cyysHJppgfMOEEzh4kKrVaqBl/1SlzwnwQps/+XQjyt2sE3wMzvUhthMrzoauvQNNTbZ4H9ZKfeKvR5" ..
	"mkmc+GLXNoPn5HNl6KhL7f4wzt0C9gytNm6YRnzhHygod2wDlFO4nUJLnDbeOlg/OVgNDGOAxNtz/zPDz8vPMCwJ8ncfjF1xYJdM" ..
	"S/a/Al7uigRPbn1zmE9fZQXFDeAsf/dtOmyFYAwnwIz9qncBcDc+tQrMTEVxSLJp0Lb69eiIDCNWoTQ5rgt7rnKJg7V5WoqbNPip" ..
	"i0fqzSwZtOvs+L+uIpAAzd/tWx+OiJZAk88bgKb0smDy+G02ksr1hBaseE2gYtmviFvq01CToAuDHTr1a/4KtwI9PAZE7SxcPHhW" ..
	"X1UvzV56ZmAwaTHAIMp312wDKQj1mqDvEirqfOvIEFSHGPjTJPjR5bHuQzpPoMAXSvzGEQAkfYZckZ2sKzxPZz8CG4oT8fPhz5QM" ..
	"sctL6NyQbyu2j2qnoehaZwWbjOxAW2OzqyV+BZ0nzRuJtO2yYazf/D0PALD7lktDmfBZyqscTgV058FWgF+Fdo/GUE+SMb9eV4TW" ..
	"XZgnU0bWiSh7LZNZo7sFTjUfjytZp3brY1gVpjoIBCgZ0p5Drfw+WWprTBn7kOgKyZ27GbkLS5Bsp5rxbCUgFC7NyK2QjhseDJYW" ..
	""
local PAYLOAD_P13 =
	"5cGSo9u/oWtb9Gllw+/Mx25mouBRunPenOcIa45Jx3E6+ytFihmMlwzWy8Xw+2gtOYhowdWFXS0vXmllghOYQwhJ5ZbAnAFiLpop" ..
	"q6nRFd2/kqTQza/0C5hMf05OybnA9uBNk54w3euuW1qCMM1Wx/FxIkRppRn2yopMx3kkQGYzoKdFMGTk4G9yTVXDOsnXB+DCjMwR" ..
	"0uLglJjMETkC+PvNdqgbY+FnhlVOuuYaA3ZQN0z2q4N8I8HTZJ+QPWcdgMjdJLWkETFvEEOsS/tbYzhAQ4nmdUK/AzaCok1HN4Xi" ..
	"l3OZ+rmiVUVVIU8sNQRipBtgEXk63EUso4IydOttkWqDQBrZQJENKgh7Bz/IrIYWSLRrn0+iKpw5cIqxiCSvvZU+WOAxoOifNL/a" ..
	"FdSaQxZJVjzGWzIG36TsLPk9lN4jBrBghCPCOIp2W9Lk5slM9uCGU+d+/hlDPwSVi5nWAq94u9s8RR/M66WGvWW545XAAeZ23vqA" ..
	"L2zqYqZl1nt3+UXFYEron6Fxvpq4l9G2+aVjFc6xNR0ws2GyXDzsb1zDMvNLE8RguZDF1cpNeNfw3fGjLDsCFv7kQ5x2FjV+0015" ..
	"0G28wacfuBzIlRY0V+5/IQnnUxFLmRJVf/fD6nhOB5WZAH95umoqEDY4YA0uSyHOBsUs0lMolMB3lN6aiK9lNVtp7Mw5m2lbaxF9" ..
	"Oa5tExIcYlfwJhSFEEFuT7JKnIxPFuvDb9zCwTw8s60P6J8NR94sSg179+5p6iFDfhZjrIoV5+WM9gCWjIr+h5lbeQOd4N+7DpKX" ..
	"taI2Ow1XAc6Mf5tiAh9XccJK9C16cpPDDLvrCfZiEm9FUTyKmgzWNzVKLYJ7DssY6I9dL5XNDtx6wB+Vxx/RPc2lfr4l5EXuDler" ..
	"rOrp0NlmxHKSBGuETOjd6OZmRfqgkUgp5WoQec5/yvrmXYpipI+1iZgALT9m7Uf0Rg93TBt/fXO10BuBpy7jVfRJGMZbj9NQJ86d" ..
	"YprtstNEe3cnX089G8PTl/xtm1v72Q5LCgfZk/DcBz+cWAwiDtX3JLsVHpg6MYBnHlLccGwcB3oyh5tgRdTPCAn4fsJp4rUr4hD0" ..
	"4MdPAn2MCvzhaccEzTPs/zF+6/DyFxIQkW0eNyf0rr8j1K5PCeJBKeTWUgZHpC5cm8R9vTSJQ3HhUZsR/PiQ824rNxB0MOkozwX8" ..
	"PuHM/BfOfnMYHJwexQV2ld3m+0yYpYJ8/EHwMSf/9HH07P62zbp/31RH6zcrXOCdBQiaEhT+2QuqXBpCfZlGE7QxivWL6/IluZo0" ..
	"6oEam5K4erEia2qFNGr99QqLn5SgXHcT/ONOu4AxYa4nP/ffXeEri51Ek6JbE4aSMEhttGvf1Bhe7R6uuFfH50QafZirBXUXQCba" ..
	"lCtkeZpWheYj3FpYUJIuxhi3o4BaECLXlT1mPL5BiObXKvPUf/UjS7qtj/tnmy4NSX3hRUEeYnpwG0+5zdobm81787evdpM5Crrj" ..
	"KhI+RruMfYPOCLLscNXILHC8yJ7QCTuWcXkVWKOvdjmjY/FOFe9DS+cB+CAVBy9eJXxInzrd9mK79NWRgVyvo4/Z9v9e27bNMAZw" ..
	"6OZ+odKrweAryBpV+xWf9YhgnioDbCmxDiCUDgAwC/ectfu8185fW7gATCZZ0KlDV0wO/MaQQDVbgYE1PC4BO79/bpN/USyKcDeA" ..
	"28Ufep9cc0bNE5HlUpGP3i/SZmIdculPS9o7pyady1H/jdsAbf5gwDciAq9bqjoo+dnv6UWRhHrm7H+tnMU+ZHy9ruiJgI2gQgeS" ..
	"v3GXGm62iroY2bum0oS3JE9Mmh5lt2dcbqyDDPTfSuRnEsNY5ZzKUa2Xyi5dP4cF6EVB/r1T7F7OX2eEd3/r6dy+MXnuEDtcAG2q" ..
	"TN/+neQ49NHPtAdA1nzjxmSLgTOn12lDu/JOIXuoKkhhBbR/i33vAY2WowoNu0dntVN6pT5MLJqS9LSRGKduP7LXy/Hn9VlWLxyN" ..
	"EOB9EL+t5dEE9WSbUAsWmNxGmmnr+8irDwpvjgbBrOwVdGEdv9FCnQPP/dI1flftfz3+gOSkNzeeQfjxORI5pBDtV4sJLEHGfgfo" ..
	"dSMTSbi8wnT+Eafp2yK+kK8xZqNFKEJ76HPHTNM8vTRRWGpmYkXPXR3CQm2t036ybVYv3/7HOqhYPOVl2drCsFRSYpYUXoB8J4zr" ..
	"PCKlW7Dx0DKCNF5un6+9lddQPinknzgm5WPrlwiNP7v2IJ0UVvM1FPCu8rCFiVlXdMQDovzYezAQ1oulaVEI/0Zi0fPkPSWoiMLK" ..
	"DfjXFUKZKxFRmAtdedUjK+Y01d+NdHI/1lVmaoG3iKEqxB05HH1+DXcfpM6sB8ccbcnW81NNXC5KrJRtzVWZxRBdp9Jp58/M/iNf" ..
	"jeWJovpdrMcx7aYhgH2TQy9uWbpCoODeidNAuDWhUkI6UO7oJEKtcQrxWGdVTvjHbGhnadWaKlXIzjBW47uQUR63tZ/1Wy43ahGl" ..
	"zTwRze8Vmh/ycN860ciHb5LodsPHssAQw+otQvxSLUPrRdLDFnM1hzhVU7LMB0KQnQ0vjBiVH9o4ysTt85O8VRKKUToS2pbeXY3A" ..
	"cIrfJYvAE++IcrmliFDA/UIgXheFdLLuF0RGkvR50MTTXkBrNVzfaQjBjTu3MmqGwX/TWpG22Hja7mtBIZ6bSduBZedRKtvelSof" ..
	"g9l64zE1nsTXCD82IvJMDpu2Hlqqa1pRus1dfi6vVe1WSwUmnKlSm1pAioMgX7G8nTMdVnvtD2ZNVPjEFLI/DL2IrIXVEEHFFEID" ..
	"Di1wUyu6zGdcvqxmc0BLgH/aGSnrEO2jcEgA/aD7O964HjyD5wOHkBM8lmljqrX4CqNab816Z5Y2hu9fSxOLx1IwnUr5lXUNt1dJ" ..
	"XcJMt0tRgzTI0OZDLVV2AKoQlKfTuN9DApoFJT6ml7cRcjZNVzRuVEU9nurILby08pKtC16sLRUdPU73JWxji4mTRWu0WR74otAI" ..
	"YNlBNK5kBTAE22baQl8dg2z9WAOMLbm2TBLbJA9NAkAMG+iCz48AHyxuFQz6SmIkk97PtZxsnq65PdeMAopJHyrk73xu4Aa/Kz7P" ..
	"D2eJuACaonKkS6B4OtCGnyyPPsJRSSuf2QEhby+SeNXTs59roMp5bJg2gyV0Ud/jxYuVYG/q7EjdwnE5qiihqUnje7vY/ThccOaZ" ..
	"ufCEivHy5iqRjm9tliKcyMXQtDgxQXIRBx8G6kFC6KDzKAibJgpdBm/5SycwNnt/TD94CEIkBngRnMcCDs2g1l1gFgm5bG5V9nJw" ..
	"mQovOelL+bP4gqUEsDt7QDbbqA1vOeH8gftbUSTk7YSAcTP8lxenUiRlBw5bLYYnIuhhks0yi3uXptJgPvoxlAKSDJfd/vo5O8yL" ..
	"DE8RKaC61Q4Yn6BRsN/ZV0vcWBi3W0GryUXKj4FP6xqzZYdLwA6Nngv39EngVmXf97cj2niZtkSNGLmxYI1PpJPAR01zQcCCsAH5" ..
	"22J8CWVrnhOgk0IeeyKDV9mPBJmGr+vibMplAFmDy8ZKtRYZnH7gY5UlH37l6H3K1pvtJTOdQuyn4z97TO9eFZ3hjW2G4pPlg9Q6" ..
	"RQYK+xVWglV9qCer/ofpAmErV4Sucmstb6+600V0KiaQPqlHnQwEEHCa86JOtyzUrhjbcxlKQnYH2x28BnvM7R0p92f9Eu15Zck7" ..
	"Ag3pOVxKFBwolcbWMiwGaC1uttubc59rYi0z3LZskd9OwI9QAhwOqJ+ePo+reuz+2m06bvKSjAcl+0LZL+a298mblazp9xUQP8EB" ..
	"7SvhOs5dR2WxBQNl3JiCKFz5PNRCB7A7JxgtdlTbdNpAR+PDaJ2Kb8v14N3tgqvwpBrpgcfn13dDJGKObfgYij0BH/YPU1CfxrtH" ..
	"aGTfrCggNymLXASr1MDH+iFjhcq2xq0s8B6bX2eXW20bcO6rZ7Mf3+uwoAOsC9Nqb0ecrboaLSOAVAgNV4luE4XyJA458sxSwV97" ..
	"mK7N3D0ggV66zmTRk2b1QQPTbl2EXTWMq+1MsTbIfAdabWGTxwiguMGwVpan09du2K13jZvlu67Wkrqtqjah5bRdh/4GupZL1+Vz" ..
	"9dDIFzkjhSLuWYf5fILmITU48cUqXJOM9CQe8v/DYeqc5gVswzt8559tgdU4V+GQGArqYKiyET/XAfdbjdcV/UrvcEuto7WzrlqX" ..
	"IgbSQ2gB0q+iug6S6zyiqm6xKgVx4tB8mwa4mjLUZi8TbhZ/8rDgEOkRt2mHGDPipp3OV7U9rGERpH4Um7YlWPUApfCuYoJmYHnM" ..
	"PlYLZyVMFv/25wJ2bUC9cHiDJ+eJ2japgsy60m199wlkPTt1waW2DcYw0a4fhP9WQV7rYYeojwJ0Y5a68QpnGd+j4itAFJJ/FiON" ..
	"tyXuLhenb7EXIidqWv8FQbk5NYHvi2rHdgIcjxigdHpUqzXVFV4ahMLYRUMjDrBS0hhaHnl+vDCjvGfVIQRX8mFY90nXXtMk7P2j" ..
	"Nzdn/IwILGe5D0ppZkNZKXw3nMRHrvWb+8IeB2rhW1vgGasOYMVfWO9lU813Iz+UfRx3jnNdBG8XEHbcKYVQysZ0FQGxuieX84wO" ..
	"ajRL1U+qW9yYxqI3k0oaW/zYIroM0AUC5+fmc4LZEOY9hfwW9t658XDTEzZNuJk61dk5s6GfCUcKFntW87MmXIdGDEgscrz8YK1S" ..
	"nJNG4LDytaMw6x5EP5EFG8NsgXvQZLc5PgxOUyRte+6pHPz1YNJReNRAItvyqcK6JIZ2sM9+rarT/gt/pU6XIRIBZ/1IvQHE/qne" ..
	"ahfBo2D5dA4CPVqQtw4uhN4J3X+ufl1iWGzOywHi8rW3A2tfyxaHvqBD084LUR35NeEnGyPsPUnCt+oIRKiphe9HNfS2EDqg9fov" ..
	"KWP4Eh/cXbAGO+3TFNGhYiphMRDHVsAOI9aH4fGDhFJHN1stQqNUyqvzAtEliSIlUEa6gIyFmrW3z7n7XfnUROEvh8EKzpY65zRy" ..
	"hIrCF+IJj+EkQHkcNSt/NDlZYyqx2mhJcHRzu54+Db0la+UWDKdCAjRLieyuBQBdvuJx/fyq4Wqn3RNLzFg9XF4uSCVhuo5eE3k+" ..
	"v2mhKkFQluGVunpxvl7ue967BF0Q4pmzfusOxAPxfGRxA6c0ajIiRl5GS7pn7k33E9KsFCUqXrwyGNqVt9F9oIoxYbbe1hwwAtJA" ..
	"8Wm8Ev9Kcy7Hq0wZbs5cMdTkK+YaSMN9l0kU3RASRCzSYLudGzVJFlOBqO3iy1n49kIKkzHLHFRE4VQObQmMgbm77ksrk7nOCWYH" ..
	"v5e25D/TcbO368Kyt23iJRbbQFfMrnOLP2TDl7rQb2AY5K5HwuLRq2S2txp8zGW1iBoID+G0Ln5s/uZnnm+uBO6hOqTZLWa++tDZ" ..
	"MZa/0MlSB8Epf2dnhNuUllC94r420pdPUauKel7R3lNR44gfvIrNfVfhLsCbbC2joEjkkFWA/zRhcNVf7Y7qPQvLGeqf7eGJUpL2" ..
	"xq7sHIWduY2t31Fa3tSKsTYitxC9zn9ccy9nUT+ilvgudB3pCYnampa4gxAT/9DgRADuH0c4Oh18JlW4gBHXdNEXmaSRB7B1ES3/" ..
	"J5ob0igzgX4YruZcTk3dUd6i9IG+Z1gY82yBReugLNUqGxMRwVa2e8Knm5HZEg00o6yrRf4tHgQ9f0z+YB0AAVCmPRChEnK3ze/S" ..
	"XfjsHQZ3wOF2s5eMSy1xt50cMjpKdNddZT46Z8A4C2sE/Fkd62lz0ZO8+re2MPO0Y3DupVzJ9NDFGV+bdANcz9f45JlntBzmkSpl" ..
	"Lq/2tKmbicykTFTtr3+L8lBb5UdxKNW9ffCgrwjLWb9LQNvZrYoEdWgRSvdeTnaA+d+kL4vTkzjZLBt4QKW1Q7Ezlo3z9i8Lw9MB" ..
	"QpAFnpy+DGQEvX7FUVJIl3jcYP+P/iTtiSfvYn/V6T1irmbbi4sLwRH2QgyTxa8H5VhK3NBbbJ/qIUbCEcO8PWagCiacYu/hYR8H" ..
	""
local PAYLOAD_P14 =
	"r/zKprFSk0G4evLLogGpsauNrUA+UQgMh6eRKhPNZr1ny7+L9LQsN0SnEF0yr3vEdMAKs1iLTeFKDdPwsCXJk4gC68CKU8/EnoP9" ..
	"b0MzbeKc21WzlSb2SvLTC1R6z65t1o2MVHzx+segg5BCbSOjvrGrI1x1WnK5/WeEaMBtspwSgf9hjpPSpkLBUJpV5lhPvxgAlXW4" ..
	"kZc5v1ueW6l7+ioi/h7jEO7dm1F6EiMvPC4v8ATnui7sTnK2iS5dym3gNFlm62SPXBxzOx8F3tBVZpbkWPGItsmkGHIy0GepzIJL" ..
	"3u+piKLI5vJ9R8vpKMWCx3jgLCV+6bVciD3UdoW6aHoKY4XbCSGKkRL5GKbnLLEQ0Y1OWJaKoPh6vQVQDkkzOmSpbCQqDVL+gAQz" ..
	"N5giT1RxdmBS0JXAkZYeODs95jU3TJj/LRdupDhqilggMICT+MyI+se7g1BJkcV8dxndLpDdlEIJMd4+jk7MOTA1nF8q9WMrqKnQ" ..
	"AF3CV91j9E9bC74HLVQ49APTbnw0Ke0Zyqcr6FQdCB7PuK2VqrWQGwKYMIOzjAPutZYOAc7ynmfF6dhei+xwgpBSsiU4yjxOOwc5" ..
	"7h9zSxUqeIl71P3xdT0Q1QRdrop5UACiN4L/+bS2Qlzcgev08r/gxDIIMT0nPqejPX7OkO+iDrOcGrnQ/GPEmlbA3B0YkS5Ouxhl" ..
	"4bCozHPHwapXuHOus1jGZQ5wKlPKT+JuF+ipMypLH+v7HR6zd6jpUxpiM1VX2OkK1mZw3c1hu6ZMAO+0R0/ZodYE5BR7ndWl9wmJ" ..
	"mNV5IPoG18Z6hiCbcF/ADnl5DzUZKDQhmUDij+Y4Kg1+ULVHSU9jsRCu/6IOzNc52UDOyXEV3dU5Bbcfzmj+gxQQVho7SnhZ+BMb" ..
	"7xAoA6EHnefwGUrdvTzIY7FkQ9qHfyk4NqSoXtp1zqarL6IXmUGuqOrVYiGoQldTHCZqC5YTU9GlD7K/NUVyi25GE8u5HqoiDeuM" ..
	"wnxIB+WMRYdS11+BtqnjuQ0dWEACj3X+0I6748M5IHerl9DwVKFrWnmDecghJt+/ihNA/csDCvF6NOkkh76Hyz7FQzV3hA25kode" ..
	"yJDJiy+0XppUzhTpooqtsXBLcBMhNnMcrj+lBbdr9qRuskw6Zqwu1KQBOoPslVlWF589gCCJeGrmKY++rbppNfc69FoRuueXFaL9" ..
	"G2QaCaIUJnQDiTuuQqa0Zkm3gh8ZkpfjMzK0tYQMotjzxapjOPRIPoLjWqtAp7DJL8be3pz3q3OwPHJDe4ggk9e+fbFN8B0th9pI" ..
	"HQ8Pifa1oyUDTwel9bC9P5OCIeJoi1+Vb0Unyj4ozTXjwXib6PCSfhCMV1JuX4tDI4SC7gW85bZmqESikvS9nzOOoozpVPL/DdXi" ..
	"BI03A6Fd0eRjBYD/NYhjI8zvnMSMD9gFUBMhI2qHBOjgB2E0Bip8U9w48AMw6nQdiK4UCpw6WTseGrmXWZauQ9WWEXJfa6kHuHKC" ..
	"M03TYSSdAmqm5tEkzOmtZ/WOyVil20lvLuDTxKlejbgf420GjL5p3rg8kqxCcdwN4qpchZWJUSjZo3gEsGE4T7igh3AniURZsSNv" ..
	"CqHNKb7iFU/NfRnCGUir7exfsN24ho+dch7tryln2a1SFfHvbGgz8jcY2PdoPDvmSNRJ/YUS96s/0U+6uRCeIDhlgoWZYsPINscb" ..
	"WC19gus4AIzlItK973trLKZYuBjI4WG9HwcAjWeUa1a4aE0av+22YyBDPAxpDFZ/xdcYw3gkfbmuVYbK3UQQdEElKcwWisPUxq60" ..
	"vxCWqwfodUYHyLCDg58qw22Xkcc/oUyO4kVnFDnt623dj3MrreS6/teFq9qK1jRFLUpeg3s2sHEcDgdrEWw6RDTJD43YNyn5J406" ..
	"zScldudrd2tk9VWPGjFBFkkV8puslYmOcyeBD2cuSuAz1zsDCEFTyNIENFS/bVdl/r3Ya3uIPsCpM6jTAn3qmPH57EECh1ca91KA" ..
	"iPtVnUBv/XoYD/iXvhuLMpcWRYS6Nijisotz7xaumPKq3/m0xuGfMIi1jZ7kqft8pmwSMVs6lQvU9QKD2vHQHUBk5fILPa6Nu1Re" ..
	"nl89rvMhv+s5TwHNNL1YhOUbO+0LuVaHqsWJ9L4sdZHgjbgotV8OsfY+4DpRMjX+DUFoOkNlMV8jf3vOFLu0WyZrJWkqRH8Mm3kN" ..
	"ceJp2N/sT5+qOu6dtxTVa7/CAwbfjQdxzAaBSmPEuUZMcHtHZSiU8MEDuHSPo/5ZPPb2+x9g4vv/PoEpWVi/AJy6j1mKS6WwKIo8" ..
	"c0HexEeZr+Ro2M9ySLFjhwvh/LBSVFfZVo5eg5fzkvxRln3aa3asj0JjWHx43Aafp+Z9Fx3Z2eX/Z9ftx0JndhEDrHXbQr+tLVF+" ..
	"9s3O6+UwEqDKY/+8Zz8tcGYQE64eAEWNHhNuWDsD0ClbS4sacI2LxgU90iTOthhArSa95iEo3doLnEIh+2OT2KgWqXS3gxZyYnTP" ..
	"y/gdz1oTSF9bVprIMBHsDzk3isiVoMZWt8rq8/tCJ8ATpa4YjCMHqhCUx2MOhACQIjMZ0p0ajn9EFzWD/KuUITz7FbLE9pSLRRJu" ..
	"CA/JhEdVKOaocXSXupHZlLxaqnyTNJG3pzVPbtj3bgRXDpyywmmPJSIzOiuvbsoEirGKbemrnwOIlaNMilKN9RT0eEoTUv/Yd7te" ..
	"3fDpuBlyKdrD6pdGP4/SLf8I4n0apX9beHJ2kiFH6PCyVzw4E/wN3eAP7rcDroGkHv2Cz/wSWMa1siSC3dfZvZZxFdc3gMhbHkq2" ..
	"dvIJC7Xsn7KSo6jBQTrhqgzcSRwRLlxdk4AvsJ5Gs6M/OqlwX+8ARmIYvw/QWi0larxtkTVnOwbuknd74HA6uVc1fycDi/vzKTHd" ..
	"SWpAQ2xXPhi27Z47VZHxcL8TFXBjOIuahr+QP/khH4w/6HMJeHccnNCrX2nj08pMr4ne7C+yQR0ysVZFm/m0LyAgp4XZrKUrZ/ou" ..
	"767PwDPOG4SlSxyWTHYtdkG1AOJh8VfF6d//BlO7QG4DHs+/5rHr8TA3NrSnQ28D+DUN87C6WBferRzpdRy3IQX4S7TsFM1fZv92" ..
	"926d7Swtyx7/WpDAD4yiKm5qtcj8dJkIRjuG2Fmyd2AedjurtR1yAD33CryUb3YnLRThwM8XxVqzlMUE4WqmwtprJFrR59TW5z9C" ..
	"JPsetfC9lbNF76nthyXm2corBn/2dcCMxEXUUrtdcXWoacGO7yuMx2xh2rc2rZFysJfsFaHanM4Rt/bxtGORldFCW7f/81YLIY2r" ..
	"9rgVek+fbwOIGCRik6LwZ/kE+9Yz06F3+GUUhkw9LTzvKMHGNJYwQzjoId7uUnWIgycA/jgbMu4PnHaVmatVj2iSrCCTh7hz8zL2" ..
	"/8geQZ/uALr7q6OAGvSXMZzk2h2b5GZxRnPDoQJiBK2xS/Xx7FrWzvg4JGQ/wk6cI49M5ArraRc1cdmQ9dXf2itPt+PKMxS/R68k" ..
	"pta/uD2Lqb53NtPleieeABpaZXEU8+R32k0ukW92RCgJ9W0eC4EXq8gevJTO32uC342hf+y7TKyda6+yyj+rvpcMxvZuC3FjawHP" ..
	"BWWQmMuZ5KgLTvPXjmOIXw1sKn8nBC9dIao6ZZiosstvZVQtpgjLt3bVEC0t92KOIoOH1T3TtIydfeFiMPd1/+QIhaJN+CB+OlCy" ..
	"725D91skM+lmpQwr+toX2LShRZwGjBEmbZ12DrCat6oWvFky/M5aVXj/zwRwCWob72PJK8y8fDFvkcndfYd0smsqj0WtC4qAKNZO" ..
	"3inJS1OhUH9JyTC1L6p6C/GeBfrOLBH/ETmHCNkeS60CZjwEhTVvt9IfZxVnV0OX78F7uRRRb/AYXlnyOJAi3GBDWU9xsW0s3p+N" ..
	"4NtfYGD4Q9pj15iwpYNckcV7hPIxOSKANmnV+xUXYhtKHpxN99OO19c+BrREl8oda3Bz39OSl3Pukh21IslNChVxMlLcO1axO+OK" ..
	"fMp0ohDy/TM6TnzqC7Pn36I52KW5+VS+3+u66cWRCiCf/WQ74Y/rJtME1KmceaOr4i8IXw5pPYNfL5c4ur8dRnUxGWrsyt6CMod7" ..
	"b8L6Be+rkhKlLjSwHt7m/ywSWSq4ydg9jwZVIrdXUYCQ2wViprBWWnOGlcNfOUVReW0muWAfZoTgWc8RjBCLe2Nrcy5IzjkCngmz" ..
	"aw12dZSsWSRz76bUdo7WQRFF8BdV4XFM5kiN/4A18OwroTxEK8gZEX7NY5yXLBx5RYX31tpWrg9nnAFjYWWQG+mnuipRAuF1q/a8" ..
	"ZPkcH0LQY2l+uJJ8MlehPL7BtvbQ0L2bbYxtG/WP6XGme5+6nrtF+6pbjqC4byCPOvY6K9Puej3xzHx/oyhhHtSqJjrI3RL6BZNL" ..
	"B2zxMQkLLQAmHnikp5e9lVPUALFQKKgSVGUmAtWKYgE/mc/Q2iFy96e8xSLHTUYHqTlxqlxe3sSRkA9rRyaBsC9bdjbLx3WxHQLv" ..
	"rPNLX6LlLkzDDH3IszoR4oP1W7BwHyjnkPEnynCURT8iB094hwx4V1vlJUrRJDJ2ubLikE6kUXHLDneUEO4ODO8hKTWxV0N5m5nm" ..
	"9jOmY/NWrPrL0A/MQdARfESV+nco2XYQI6ujjR34bUqrbagRoAEkQymmies+rEW/EAqQcXGFJQ86vL7idztFYdKbcxRXxN3EmPFU" ..
	"uIyPCLcoVLCw3/g5T4HT4aX+eKNJvIe1muU9VNV6SlGWoI2e+mK4LPWNDS3Qm/IjwP8DaZ08vyscYNHcDUuHOSV3BDq2H9iTBGf5" ..
	"MRAOE1YbQHvwVmMGZRw295DanXmiJZDPW6RulARnPT0T3Ue3BlrxW18H9ffApQGTxHSghqYG5K8cooDY48Q927InbkXK1g28orwC" ..
	"f/WVMBUEIm24zcVOuXcNT31blq4nS8KPlMFS53nSWD5L2KZgAGl0SQ5mPSWossez704+VLnu2rPFQh6ugcsoVfxgurZpegta5/Wg" ..
	"scSUlf89EvneNZG+juRM9/HHV+3+BHgajKvkZjgf26fOG3RXlFps+10oRc0Mz8lKhFPjZHoo4jS1aDjEH3bdcYdGActm2q0WQEjw" ..
	"lgwsyn5OJ+nYRxyiUyFBhU+l2SqaJ/pLWca3MovfXH+jk7mCndeDS+p3T6hEAOj558cR1iASfTGavYyTT1PXUVFmC9MawC+lHehn" ..
	"jLakST6LIMBT+c5sWu2kCu9Fk2OtRIUnpraQTubSpBTV33ytY+44IwbxwvB8JMVAkUMNdDFNFzAPTFvUToY6zIq4M3SkuJ5+/dXd" ..
	"UfoK3m6vpUrBxiB9RPvZmw79KbQa3Mry+ISYafR7yMPok1vc7krOiTbXY7FTRYguhxGy4uyLrKjP41bFOH5dwbeVzAQaBoGLlcmf" ..
	"vP5aOttCt/UvRvRT5Imbw9LVfuCJJt4ThEL2oub4x7OJNL7WFzfWT+7J5CKS3wLfULKT8Sbjc+SJI1oVcOG2RULrPF3x7DaBf4bi" ..
	"vGpuroB9DHS7aQtNFZwkPBnqcM6xLIoheXrhKO9Y8BgYyshHfE91Tvv1zKvwljijIq+NluVUV77/G79wjd+TYRs5hqoRKl5kYLE1" ..
	"jpyZJS31jIOqB4ie1CQ8TiQDyOOrjK4wUyQ/3gEVk5RlK+6S8dqQHYrS9QNtRC7OkGwiHfKBs55dQ1BB800GxP5mnHC+XogPCyFZ" ..
	"HNWTEf6lM/UAidxlEdZgOpDIvhW5Ssk8kNRkoyb8CwBUtNtvos89hLC8Rxx0zhbAoAjVstfrYT+cli+dhxDHzjleG4b4sCQkSdM0" ..
	"19spRGaRDg7DBmk/VcVrEJAGba06DwGqae57/7OUD/AY50XXWSTzoh9F1jVsURGtg3e7X0DFUz5cXFGvOmRI8Umvbr6fe1g6v8wG" ..
	"vIyym/LX2Zy80FjSZrl6ePg0JCiihKjmNEdE8vWk+9SVPFh71rTD3mMgaqoa+H3sEysn6NZPrz2oOUMJ0SoI0pieV+OafSX0f/1B" ..
	""
local PAYLOAD_P15 =
	"s7q6f1DvCx7PCg+TbcGeYTkpEmBhgYM/gErwnjthayfhl8GACRtAUfe5Vq7GJKVMLya9rq6/Ade3oHC2wtja7f3VuD9kyvqxmUpc" ..
	"O8lF/pRJOyye2EXq8FpyIkXfhwOC3xsgUAq18RbQw1JEqu+95rE+YroeFFmWtgZ776UVHFqjYRC+JrXu/U8xOlQNu2L2PsvmUZSm" ..
	"lD1n1oY6Xp/kEK7Uxakc1Na5VEOZ6yOhY9rsHyG8kSpL4ApfiDOCxX9yuZABx2BXEWkYCSSeElHOteGDBIEc9YjvqmsYDnS4iAs0" ..
	"28GSkhtYHOZruA+JJ2zg1LudNUhGKKVhIAATgHhlSjco6uQXwyafKwpAxhPEqwfR4nQEdNLQ6YVr37pFWEnMYFWqwn/97bnoqD7W" ..
	"5MvSDKA0Yo46yVUka7Z5S7fV/uSDfdx9KoK6xv9Zt8agYxZjs9+ae9DyZuJ9dth36qt0P/IA1UfQibROqvV3SUU4vGhe0dDVESPf" ..
	"JW+hQXxJqvOhuLDJuG9fmgH7Fn+arpR8lHvF6/47kzezAZeVC29JzPdGNqIHEfCqIMqVS040iII2y5OacyCff8dsb+gnL/z7DTul" ..
	"YNBWJw11GD24QTnBvJsSI+T+4SjU2UHA3Ns2hYfD5oRQr8bHHaOGsaLHcg1P1i7aK9dxQrk6bwbiRcf+DuOxcrlUfqIoYVn99q4j" ..
	"AfBhDHh8Is8JxTTL/OTKBOhcFxeIC1McEMq1VpuTtiauCvGvQIxbA4mFoE6JzrS9E8u5hRGXh4HJl7xOIJTK3SYQrLDXSKxVc0WW" ..
	"Q/oHOVaKCrbDh3U2i+ie60bhDyHFP8/NUZdugswq5KDT24YdXAJYEjQd858HxjD/fsv5XVv13wLkOmmJh0nlEfl4mL5nxRtwDDzD" ..
	"yfvUJb7kyCjV0s2p5UHqMHyaYOlPHcPog/bvdEuVFglmXZgomtJkMHSK15OV02s+hUuGkrOWH/syVqcyboAmLbwluQf8K+VUrr4F" ..
	"0S9WiBR1K1qZoLZ6qYkBjHVd7AGzRQXsY7CORn4DnHfZ6PDUp9HWTsnVQIpSIOPfovLT3GOFZd9mXDWYNZ8BXDqqvqAudYWJ0omy" ..
	"933Islq6yImYfBYJ1K+fJSqryHa8DLvtip2yQ9Mzp2hVqxBvwbAguWIMFSnx+O4Oa74KDCLL/NV6nVn5xs9waJwDSdls3sWvFU19" ..
	"pOGiDXxUdRSu4b6Ivo2I4qZHmCQvwexto97l/QdWp5AItBxesXr0HT3X1s8wYZgByzwrb6HQKyGYyhb+AwCEepCtHTSc627ziDMN" ..
	"m4l9BX8Rx40bFhSgySH7R1DeJw9nrhKAweaAj1FyrRbylEOvOyBiGFqLM2WVYYp+bL3LKrLz+0XD2xOlG5RNCbO7EJvyKYCvePQA" ..
	"15BmKfQqxrazf2UcPhZiaGh5LXiFACs7dpegHeC4Wy57iRb2Ixj5PGsvUrXKTsCToSv0SQQPS44ZNvKulMX+6jNMEoRW6ZmdQX3z" ..
	"lhiQYGSAR3YKCISO4TDKQChhlBgSLPqPWQyNAgxVOzn6uE8oR0P7AzGEm4GCsBcvSjdLOpiOKbzvIFiOyv8sW7c8el2TQOHRPTr4" ..
	"hJIMi4uoX3I+XX3T3xrTi8tPp7pUF85Cvctn0zr0UlOYMFnDRq26+Ya1KAWOORKupxx9eMh7xpuJE3XU5yxaYubpy6+U0+80m3QF" ..
	"5wpcwIn2xxq5KsQ9GH9sX25M1p4E/LaeqMEuj1c1pEjOr5Qc+WkZ2auyZ/ZzgA74UtpMdRWpI+GYBhzX/2XPFRQeH4D9GgefEq0u" ..
	"31JLBqWzlDxwz/UM5XaDbXpNvI7RGEw7nsMDPjAo9PpD6L6d8/l4mdS0OnUT241Yos3B+j7WhyGTpQniCoqG1LpaEKECuBjeT1qs" ..
	"/ovdv2aq2gwj3KPsbcNvTrf1oJ8JDVtwr9mpO07Zy3vawLczvMeKyO1fRSvSOduQUiAAkuXB6uHmAkCpTq69xhe6/pfg4KR8tt6K" ..
	"4snMW/xM+Xpodoa8Iq56413SGMSGYCsu4Eveu9/jB64dwE4b4PwocSPi9KfZWnoxD6an1vw4WXa2me7yX40UqVmODaRoiA6/ypsw" ..
	"SuXa6MVLbXNWzthObOe56CaIJPlt3uKHNhdK3l15rSE2qIjymWUojk+FRMO69s2tP6H6yv4z8D7kQ/4NPfO7bKG0Kw+VvktGhNRB" ..
	"J+t4f+b8ptIeJ4MWXhcuwQ0PgNjPc3vy/UV+VtNgB2J5T0eenB9HlG+AzqtHMMUvd9MmUQsbagx9Dx5sXJlQwzM0fKbpqt275ieY" ..
	"zKyxdQnLez4QOtHdBU4wbOWEpzGbOs4AF5w6I4gYNFn2wUzxeytrqbBR/07+YCAo6dxbzvCIn0n+MljGGN7O2LXgV7HRdbhhq1wg" ..
	"eiGiIGCSFOH7rakYfKOLE5VH0UDIF1Wz89tiVjJaPJUir+bfLSlZ6loJ3oqGA8ArSwnhV3LEI3olGgZHT4ePqN+U0zLhBwcEDLNm" ..
	"xRGxGOCsEUfx81hlPId+z2+NBAy5ld38uwfOUd5OwJtGB8biRGspYUDeG24lCip662V+AdI1WU3KYO0iz3k7tDYqjmvJuOx+HnZR" ..
	"bTj9A9vtURHe9AFRH/OSjQJf16YlIAojBMEpQeLv4hLGpq0EjAYVqY5q3Yqy/n3JhOmqETT6CFHUHi6ZBP3sse2xLsx9TINCYTW4" ..
	"KYI1l2DhxtRzyEN8wGxOHCRaZqsFUpVpVo+VLYGNn8WqGDRvgI49o/GAV9dqVFFHZcwk7Fi2y04OruQiNa7x0uMeQHT0LNTeO0ad" ..
	"OF3a29aXeHCLW3z5e6BvnxzzjbDM3wblYGPsdL2+dVNNxmAPNzOAPwA/mTT7IfZi/U3bYQP7ROByzu/3WBfP72//unmsL5Go8o1R" ..
	"Gm+zqJOQfH7cBmZi0dSUNOZgFOtdpGSkbNs3pSfMWopvfONp+VlIvp+oryzI39BDP9K8GNCq9RcSUVe+oqxqTFJdtkUspxnUoieB" ..
	"MHl8slGjMrECoLS7/Q2fA8vqATLEf1dRh6aiM8a4Hl51GE+27vWTEpGGQG03miP8o4jlLa4DC6rDbSlsYjDKhbzDziRpihst3anU" ..
	"QySD3dcRv6xVDNknuFCYEG+BKDaTpkdMJxYPfygb43+EHXK2s04hWmuvJXVjPTXK9mSMx5TdFSRiIhtBKmluMINERfwrf9o5boMy" ..
	"Yt9QthAprC1FSTbtLZBNvaM7sG8UlvEzUGlr4BgyqPsDHzd/Ckp7+B0OUuqUn4G5caqEzJMTN06HV9nPpit46BL/fpJDYkBm0z6U" ..
	"Wit0G0eSVpl4XEFzc+XR0D3nuzMCnA1fhiPI1faBmX7IMhdfNC+nvh14zUzNziNgzEYd90EVRF1nBXS5Owxnw4P+Hj8eQtgDp48U" ..
	"BaCdftsWar0og2AyaypOWX1MVAzzbhhpcHWLR7a1vY4H4mJtyHxB057HVmXqGrsQTeGFrEuQbiSf4+amq7++LmCoMW0lgh74E2qO" ..
	"HjypVf9h7DN4UfIdnTxy8aFkhey4leeOu36WxPy+ba4yYIn1ESWWnV4oDaTwDpwg7TlDzcbwqrSbSaZV6dkw35UTRLrfHJmRK5Rw" ..
	"9Cmtd1qrgxKsQu1vRShwBVuuTHA2bdkFrE5gXemcTNF10ZxiJng46ZUrEIKc5rUgS52Mglo3JmRJMp8ZfEZF9S0mg428VBGVF0QV" ..
	"KENZF50eWAFEBYGGZ8/u6DkQPqdw2NeyTbkosxjWRxw3AXoQC0aqzeQIzxIR82VlwGppdeG3EWzM5wZgxgP3BZ1OoL4v4O/E+g86" ..
	"93yaGf7ZPWEA/j4kGJU7eP2FirqFJiX5ilI54BR5W5JGOGwkOeEBJpKbSUH2epA3TIII40QUIYCtfuFNnqd3Adbl76zmul0g9QN8" ..
	"KOK4SFYgij+ZL9HJ+brO8NKHctWpPLxUrtJLEbP8M+bbF/UM40LkvQGTq6ktsZRcdhRamF91GpRIOi/X2xzhKR+W4JQz3XgLWm/f" ..
	"219sLiSWNZPCxzON8n26XcGVr1FYJBlEiZVGA4bt07Otkdi/UmPhXAKPAacbgFay4SRA3fGvSqwaae6uZ2vYhrdUC4nQfMkUnjN5" ..
	"gEWWJBDa6Qrj6kTDeYkKNVPJo1+fkUMSoXAJh5PtAqA8CgPt9ityqIUbphiXdYsjCzOzUoJuPrrDGtqzAQCqUD7A8JPI7TW58jQD" ..
	"e/xaRFu8hBK5g67rhrbzFkiJm34nsPJkerS057GmU/NsT+DSMHIIqhG6+yg4pjKgtbqu7nVayurVYVW5xVCbULqAUo3kTIJZJEQB" ..
	"VIYAbK63c3uQL2m9yFP4HrCqXsHpnRgfwR4I/iln1dIPJ8AoEU/C7S/X2tcgAT0BsJ7P/9WIx1ImyPipDoVHGJth/5kj7zrYaUYg" ..
	"JakZTEC/uejZuQ0pwrpRALI3JGoerv1e7WxiCaCKJhrZ71KSeDpSduOkHYbm+Fig06GJOKPwUl5dbiy/3zCRD9NXtdONE3ghnMZE" ..
	"xMwmTK4yqgLSr5mr/lXBjANHa1wB5LlepCsMTChZ+2GuhfwIX5HRjEehXE/A32SWlZEKgEvE8/TAEaRGpMsl+0Orxv4wuOKO4Keg" ..
	"dWyiEvR63B4aLn5C+g6BGQflFrOF7kHmN1X7fhx69e+op8eH7qbgT8DM6nOZLqEoNAV0ZTpoFPiOrs8vYOyboPnjpk9oXJJfbWEz" ..
	"ryUX5a22OPRtKcxmsuOfGtIb64rm80xH+m1yqe/PS3zlzw+TCPCxvgprUZbYDg0qLCG4zlamEUMxm9s30HlzSVHrDsewzfJCPcWy" ..
	"OrwFRmpHsqLfPLeXj7RgGroYGtGrAPGLkI47/OMoUXkmWmqQV7awF3iWErkJFl1HOen9JBcJNPrzAHngwrhvCFXnZItVAIXtPTxe" ..
	"O3ulBUBI9Fa85bcM1BSXGsejZUe2uN40J+oWMfnFNl9XxxnwFKWaWg/irGWi7q5vNwz01m33Zuz1kh0TbYb4YhxsWUAnwWQ+OiAS" ..
	"21JNFJd8rKY9BYcnEV+Y4rEqe7zhSyKXvIps9epFPTDWswXGas6lFPcQBcf/jq2ToQI1F79EGJ9GJjLuD9wjDo5C4d6glib7w+/k" ..
	"f1Z4H1xddMy4SJoCFCSUIKVZsbYsZwTafX43ovSS8fJ68iAF+a9oqPgkIoeIBO+8fLS2chNedCUXd4VmmbK++57bSOIu9ZzRtLCa" ..
	"lM1PmE8h0W3HwbinLyqOyiUQwZ+gMVyFO+ZWlTBNBYLQOVaD60dPq0tqTXp6XSY3T6egGV21NYdliCyKiaICPv6kSI/d8fedbqtB" ..
	"3xrkwcSomeGjK/tmvlSIuwkIhzTq7rhEOZ+7S2ZVLMyAo7pzHQHq+KiEj5rwqUGHy5iHGoMdv+AiuEPn59XNh+ESFs89+43lXgMZ" ..
	"+qrKnZzVz8vLMJtw03u6xw4FfdwueAkEdnfr5GTVpDb4lvUi4Br5wsve5FzYf4qrZ/og+MUg7oGqJI9d1GKbkl/xlstR7pCIq88P" ..
	"GYWaMFr1a3BQoiXfAVkuTbblRLxx67aZuEu5MxZvcTAFg2IFjJV/lmM9vKyoqV3bK2SI6ZkLIp3twnlFO7gopUGQHgds/LbKQEf7" ..
	"DJk59eP64wJVwehEY3Ynil5N6YUcMY8fQxhDFVlJDWyDDihct8cFsfDEPI0J9NzhztjCqB5/26lt940N9ysbb+JT0NfncFH6eDAM" ..
	"fJQZQuFi8eVLPuRo4DAQyNYUyAcp/wsbBmBGe2TsbkFdyDmFHmxr29uBgL2bzry/ldVV7phnt36FtmARtCCUzVd1podZyMXEcrgg" ..
	"gLmUAe1iM+ii7/OL4Qq1OykITt1T6OSJbdWLqanfnf7CWajGhuMzhtndJh8mWlOuAyIicxxuM1+f4T9SdIBBtp1lO9n7g/vevWxL" ..
	"cv5rRESlcvYsMsKdfWrdIf0iedbRRtMWq+K7ijV+w/DUuPWpuLSwtpJ6fd9bNIGqLxmIwG///+E505THmhxQQYbrtc7PGey3c3sP" ..
	""
local PAYLOAD_P16 =
	"vj7ziJd61XldvUH9XY1gjT+2B8tnR+fEnyphxVDsqNVn3GofecbBS/7iPP3CrBiw9MWi5qyZe0B47H/ZWR4GoVi2mCTYjLLTAG7i" ..
	"6G4ECMmUQ/tJuRpIPOEuNWIvruP7HfNDmlR2O+Dl2m2WioHQPdpi+pxQ762UVsmpYlvhkL/djYzIxYqej7twEV4F6QAffN0V72WU" ..
	"9mV1mDmRWQ8p0p+fv/3x8Iz/uZdnj0iusQ8BLh+P+UhFIEtmhGP8bkvFdVPa8o4U8UJamOPAM9Bymg9u+69UuiICmZg7/3zArE9P" ..
	"rQnHA1VDhITvgn9I3sDRErYEorZhQD3eRxHH0u4JBlUmLK0WOZQRhUYEM1B5w0vRSD/Fc+1QmWFbWdjtSuqIj09St5X0gZswcUks" ..
	"hl5LgSnFtx9MmenPEKBPLl5Xp2orryf+JldWBUVXCqS0v+PwwNfZfOepGuihkQZQCVejR2kJLGRyPqDTdfsM+W5QrGPWwUiDNNCE" ..
	"ahkMtd0HzekeUYIIap6HNG47ipuZOLXD5zE/VXoPVSPgfHxhZDsjZde1wCIjOCsw3xahMMO9YuC2It3GHhJKYKCAtXKYcFq9PkIj" ..
	"pGNp+HoQ+K9vSRSf7lsMFwJVQEGIcG3IaVpSvRhmU4qRHfdUqdbbBnUTGhkuAO6VFKeHShL4xxe0qZg3xbMXxJREZ6shH1h2uFax" ..
	"jllhNwFe0CXybC9QyfOGy8dvXAxbkgn6MLIQ91MocOjX12ifTp3niMLEK4Fe6Qq8XCbqGF+0e7YhW7uhVZRGo1/cBKQAcwnz2uug" ..
	"UJRo2rOuVIa9B/W+aY5r3Chj2lpJJ+K50CfR1TT8bK9sDTPI/DDfJSC12TDxLAbqIFE+Fc1I0GX5qp9mG/z3CT8sFlmW97QJU3Wo" ..
	"vTZYCoWccE4/znOhja2i7A22mWWKvZ6ILzIMpzQGHa5E1UlIYAQkPK7hEg8S0cjuguTHWLNeMZLEGJX3hYjzPlnhvgJ8/WdYXFxA" ..
	"DGIipGTpuqZ78HM6w+ZzfihZkE4VfGXcweCqyyU4ToqHVKx1vaSFJRBHDVxZ5EksmgnxtTb/2nuye6xBUqnyTpOzyX7wtXZt78uH" ..
	"H6SUF3yRuW47P2xI+ueBdsVQLV7orci06gIel5OdZ2lr2E8OhBba8n/k6/jyvT/DKsc/vay1rJfInpdkGh/PPdVixEi1BO3/kSac" ..
	"s71/derv1JLwaP4g6a3Ha8Vb7Y/xiOBIDhzvPABU34jO7AjtkgXXaG2kg8IkwApG6SsQSv32G7/9PxF6MzBnM8CozGYvVqlBlKzp" ..
	"oIMRyuCKInJex+lzctM0t7YZWoYJ73xe3I6CT5Z5bo/VduQLqMf+ss+NrNQLdAxeYfhmyrLml8olgqXpWYE0DdBtkE3ZBfMiPdPT" ..
	"2eSR27Iu9DSiI2CBS27Pcg2ft2xB+kjMWXjFKT1HedNejkKgBEhWAbOHp1TLdb3Nk9KVUx6rMJ8d1ajjwo79aTVZiZ2oHNxGhMaZ" ..
	"U500HfEI29lTnb67n5WDNWu86hZG+UKtaFCfZM+7zIopml50LkyZsy+ukvIPrhdVnN5xXc8IcTsAmRLfT/jAj0uPB8Ka0F6gZAyY" ..
	"/92K1doYmUSCxjBE7u5YLFCglQmL5m+yRHHG6D2+63HyN0INqa6+PGS2zws4ND2dxrUf+2a8Zf5G1SYP7bgoCMzwujYkQPRkzewI" ..
	"sSKHYxZ+ot3avH8j/d+M0Iuxw38jrUyTOkrF2UxbGwV/lwcYNem+UGlzdSVLkrHEgbSXjLmc6oOrLSQjSX4PDDEckt+J9nKXcFvN" ..
	"SCNetkNWW0+tosmm/pJkSsB9KoReR21+V8GwkqRyONQriCWDa1I4FeUU/c+8W1xh8KfMwvoB2kI2T7P92R27nRLS5XI953HJMZKB" ..
	"mogK+ovx3/wGZpEW29TSMXSd27hhHZVv0m5gMXwSSJp9f+Jr/L6VSqElXkuk8pHRxmXiaFLEr353EpNrfHlC/vqM/n+6P56FObNF" ..
	"75QFnUUlY23Hz5wjzR1uIom9ahNr9Nlj30v6YzNrOrM26O2WZtBX/F/Lco2TE2L/1xTgXAkVCm4cgiS3nX+aYcCQ0W8at0nlh3ze" ..
	"6WJJBb9ltQqWQ7d5oJJ5XTDL+t8w0WWcdY3kU0P1Y4quxPewA0UYYnISDRGr1SIC66loiCc/BKJ6ejuWU8msaAAN2BTtMdz/BDaP" ..
	"mwD/riQ3qxu/eAcA7xIplKV1yRADYKDNOZeVIGFNMwJKWqL3AXsZf6USRSC5UvSPnx1DwxI2RtjuwWQ9dYIUGMyAwx88l5+MsSrl" ..
	"yzxtfgTC/24U" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9 .. PAYLOAD_P10 .. PAYLOAD_P11 .. PAYLOAD_P12 .. PAYLOAD_P13 .. PAYLOAD_P14 .. PAYLOAD_P15 .. PAYLOAD_P16

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
