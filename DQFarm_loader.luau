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
	{ seed = 2483774294, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2490565440, exp = 0, plan = 0, hwid = {} },
	{ seed = 2491049765, exp = 1788089514, plan = 1, hwid = {} },
	{ seed = 2489848864, exp = 1788742721, plan = 0, hwid = {} }
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
	"1JwskXvZ7HWq4s0PiEEfyp/lta8rVDEH4lVYH2e/eAxTu683eaw/j8KNcKyQKgBrH4bDwN1irnIa6/cPhIqpZZ3CS95XMyLbvBuk" ..
	"msTK+aR4tNr/aRI4Fabc+44ack3yo7q9GCRvhwVRskyELQlsdL9kb+5f1uUG7rBAZgmDAdIyY7czdztm3u+wuRIIgOgbTmQmreDp" ..
	"HqwYfeVIiJEtUImjHU5dn2oMPnz8an2RHsDETikvz+6Ph8OWTx6WM6ZkgH33iCQU6vsApSaaEmqjEIBuC6JvZYKU6LCZk8YAK61L" ..
	"zEzzmBGk3kvlbLczL9og1PwFFM4NAHg07Tyd9Udw1sQ2WBRymDJEhwJUupEC1oyjGqH+AUWtYonV89QU3e6WAAkQ04qqpWT+dUWt" ..
	"CEhapvAeF583B/k6Icn7Ouj1I25MRJSZxMJwCRs5Htmu2ykEvvhrgdLLzR5ZjApELtv21SyaOBU7CgrKQEZtAbsgQ8XInR8G/cBb" ..
	"E2zvibhdILd7SxeQndnF0it0JBbd36fQVZzT27U7Jrx04ShWOIEARaKZPQ9pbwjX4RbH0PZmYW5gpGCzb6R2s7A7CrGBIlHuPJBU" ..
	"/odVvZ28aBX+JB6b9xZ1+fZ56ItDVhFX6W1B0g9w6S/1ScOStD5NkaxfQLfDhL6OsQz2wCB0HW1UAt4LI+XcU5Lm+/azDlTMgPIn" ..
	"143aSl3KO47nXfePCLiS4vkbOQTDuJr2d+Z1Ikk2CoRcVzuiEB81hUt2C2Aa68eaYAvTkiePWv3W2aoQ0/72QFk2i0tX8Dh7qhuI" ..
	"uuyVZHq7xT/inrLF3sUtCqYriu6lq8XVzuufgLYOom2BQgQHMKiERujom6mQ5QviQGOY58wJkR5hoVPUvz2ZLAtNhdPPbpFekHe2" ..
	"TUAMRyUA1PhMmML7PHM1drQ0bTtE8o3s/Q3hlX4Aqs1gwjJrIF+rhQ8YhSs6pnuU3mS2GgK1Rfj83RriAgocROI9B1EalANYF82I" ..
	"z1aR5GzNyi2AKU6pJXCRHH26NjVQioWMjHYTZQtz3etD+cnArd4B+mRnlcgMHtm4IRfG5BK9OwQyGYejtRK3PdXpz6G5akFvn6yK" ..
	"ppI2MXcjEcCA0rmEg3N5tTdgQ53T/HwVHkvkhRrZtfoLOXdS9OTTeXgF69qkwXvIQhZgB40Wg1zHxvOgpk0FnvpPZaxuuRiB7FIo" ..
	"JREIvi+0hhqsMceaCsCwS/H0ukZjwTlThYZXt3R7008pWOoItYg1zU4HMg0EsrH+DWrh13OnO3Sct+v8qarfhDhwp/ffvicIgDYo" ..
	"9VHP6TlndSI4NlJQfZTK8iYXXtO9ggdZ2Ad76V+YWyvBONuPvs6sF2QwKXn9EwdkF0cTf/GXP5M8pTnzdBPzMCIPdHBjpg3Foa8M" ..
	"eMwIHxZ/+1GjKz6rtXWIU0t7+9gK6XzwF2P9s1OO5LcB6rSqoCbPXb4Xoq6XXZzfQecDLA16y5VP6peBVUa2UitgJcCLGtobWdEj" ..
	"70PhjluvG3iNAAs2QZJpOEYotrMOQTOEi1FZWvV4S6juc25ruWh3hr8tKM7C4gjYFh2G1VvcTKaxIjoZdGPoqIWN2v++QdECf8AK" ..
	"NrPuzwPik9ajK30VSn5ybx1ZcVLDm5aZK91Lg+q85anZ6KHZHCZ2PKWOUZvnOMmydon/lDiAuY4bEy/IvPhdakssLIm2WukSmorx" ..
	"CNZCsSrbSk6joq74u2vuY2T8LhiQ4QbJsaaqN1OQOlbmStaHECKpoBWysZlo0q4MLvxG+iZBg5ZMYkb6hOhm4c4Brkh8KehL/KjC" ..
	"KmPTwRUJl6RCvSrMIpTEwEZNIS4LhiHcJ7ui2U3QOfHz88GKaJnxOXBoCmoNslzbdJCwelYGCYQRFPFSvOHVpUHDghBrVPMRPOtM" ..
	"l0XsJYIPLMd3Iq2kxx+rOsIThfBISfepfD+H528p5Ysw9asPjftd/c9FP+p+n0bdowp/C1T54xjGEkPnBYfMrfQSaur75fsaAiEK" ..
	"VMvsqR/XBb5jYICv8QQ8er8IoqcGbNd0JtAktc6G+AGiSTzlOGTfvPE3JZUqJ/m36fvN71kqHsYtS3OKNcVzZod1qANQyGKK9CGe" ..
	"Q4NlAlJMgsnCoeSuBJMtBXpV7f1uWpAwzA3plXojhsLayoYCmGv+DWPRfeLUYMOkZeLPFru59PmueXKyuG1+26jcxpOcQ7JwRR1G" ..
	"rTI04dcfbLBmEMXipB9okP+fXkxRGLOL3uG7DaBnd060up5ifDNvmlvlrgIgqJ3h95Y7zlmcslQyPnaDMHFZ4bgUNke1u/k/bsXw" ..
	"pxEB+HmlWLcY70PNUGEccm653s1VOKwkK1WicZt6hOabYTW/l6WuLhrFcsHFSEQGATFr09zM/Eej7WyJ0TdeMmVKlrd6xdsmcjrK" ..
	"IvHGXBTrcOIl7fc4G9LClohU7iuob+A0Kg7MBKIWwoinLQBLNPOXSlYRuxXXCeGDpqQljlzC551aV9SJsjpeC4phAvHRfuxP97q5" ..
	"QeOcs/oZ4fODqV45z9Pxkh9c1Ma4/MyuXS6aKnPZc8lDd/5UfpyrwUNYvEg4i2y2bgtchhTG4ldXxsAI5Qpsv1lCNxeUTLsFMSJD" ..
	"isxyj4bWZhoxKbGZa4qc6UDfuxIRv9ffkBX0XCTLMCCLouu+Q0rebTW26qGKp+E7hMBVFjHYEQ1KceE6aiVbOCis5Kglt0Y3HiHL" ..
	"ACaLE9yfc/Yyx2p5Kh+KM50OYk8Au51wUGADVgtIaZEWPE7iXFNeOF02688sYckkKHr4EWjMBSEB9mt9OGjm6ixCbWTy60VlkRBk" ..
	"J2mF6oWmPBY6bJrF5NjrXtaGXNgxS+wMr6NLe4MZCF8k4RlNw65XtHIqHll6tNSGKdvujHlQnesSNNmTV0yDUd0EDgwFRirJAlS+" ..
	"VMES7YE8Qy5yUALlfiMrmNyvwxvInUD3fkmdSqE2hqmnaXQzbAOHGR4GAQpqY99ulRWJeMKbf6lRBcNzlAri7mAOB1iuef8Ya+M8" ..
	"9c6XopcJ8Y+nYoDZrxPD2FY32z9rWNcI5USjjMiAZpbPDTT9mK4yFuSJEFeRtgMLhAWdNDfK2wZPfOh7Ze3pYjkLfWa/9pKNFJP5" ..
	"9228ykWBMohAQ7noA5eN/F0RdV3+6BkUw0S4qHpiMN/2r2JUQ1ktaLATT8EsrLHTWaMvYPLf6IZv9eiYlzWZbQiC1dT6wdWp9H1T" ..
	"gaGHxrwGSc+2dnabb4A6Saye8wF/sDGUkWBdw2wuQpFw64lqJMF+Hj1TSMiLyXIQy7u/vnxnxVzuxYa/ddhQl7uwbtMozZ2BIJfh" ..
	"izfJq/yi1e5E1Tz8yzvnX3gi6mUdNAJkrxCUl+VfgkGIalDP8JWilXz7Y7Y4BGewXD/f8B+vM9NSTWAJL7dMpMD2bJ2QN1NnWcmX" ..
	"diErNp056+/a4/88w9QEF9mRm+eVFb26Q4AdHW/r9yEx2PK6dfnrzXKXMN+gWVvrTClBjTK7y77hjJ03O3bdEuQrMpFMInY1Lytc" ..
	"xLZiyBscNo1ab/gLb2k5YjJpqppgYztwAVV/C4FqmWrdoP4q8u4qd8apW5Q8LhKa7FCW+wkDWdgvs9SJMgwYyPvVUKvWTs1InSzS" ..
	"tCjfrIBboIQFClT3fMnyEYlmkcoobL4ntfLYwcbvBUGrsKcwm92Qp+VVjWBcMEI96S3CG5Y8qkSjvdjsxg9cwl+qmVQlZlRhPa6x" ..
	"8dI3+uYHsR8jbN8rXXn2UIqysoKG4zp7ao3Bngd/DLQvuuSmQ5NTpq3RFZQ1vnZCkDVt4B1xOFjRsQ+yu/wjPGks2+97sLDbvJKX" ..
	"IkCpVxbvEQFWYNgyUV8OPaQYUvwx8Cx87NDN9uBm8jVpfF92z4H303GXG08oV4QZp2119/fehr4nOVfxbbDSwgpkX1+mtidSkeN4" ..
	"d1LYopidnjbVMicN9xOFRNpux8kzs7P7yd+MCjyHdgiIisOpRCCdUPaM4wWLmrW7VkkNJKFpAWbB8YTEmXOKYApc2bRzgHohV+ER" ..
	"wG/ehNm9F25cVC0Hg6zJmXI4wQlEwS5yfE374JXHQUmDgVpObLbj7psMxxME3fWGCTKUQ39O0n3u5nRERKIlsK1wR5Non0iU6EOk" ..
	"EhkioIahQiB4kUkLqKcO4U2/zN4RB4BrBq5Hi4A8syKYA/sxUR9zrbcg1vK3RdQeW4VlD9eUDJm4brZlZxsLQaZQvEx2OxRZuOV4" ..
	"1joh/FP+sxpO/5ze4ZwDPeWsI1q5Dzzl1EFf3UL+oJnEouu/KvgKBnhhjpS3k3+s09Iq1ppKZ9mIZG7WC+G/yM5+y3WFbisVF2Qj" ..
	"jw/PNufqARq/9tLgKGM4Z87aIlL5uBiWuutQbC/4qsKJYAdJYG2XCo23xkSRnMa8cpCA5MJQSAOZ7IJpwvO9JOGhQntzRZ/rjX+j" ..
	"OZo4PD3AXw2BJ4xXRtnsUxCQCIiWBRc+mv701Ur84jdfan3KxY3Hro+A6AIaOme2oUWFn4/EfWEeR+B3CzC4Jtth4+m/WLsoKYs8" ..
	"U84tLN2oC4w3VV0XfUsBRJjufV86gsBBRAQvWtheo4ML2ynFuDyQgIMlUm51ihGRqcfDUET4T3CWSn2m0ys3ZstVLdvS75aGHOsJ" ..
	"80wbnEFYItrAxvcSpr/xgGJ4hiqBBNmX3aLc3JKRfZdiVA0/9MkTVsKYxlMpx2FMyMuqwxOfBwwk3UADBn1xMLSN82aNuS8ezHE6" ..
	"7nm2+aEO4vakgfFxFK00W/WkyEdtDSqU+Cpe3dtacpKeOoFfL3YRLcdoBlUwfpS6y7U8lBNamvq/WGMgeUlDUKVGxScK6O/G6/Wd" ..
	"B9BCN28bVa18TIR/JBSTUt+q7q2RyXmjWlg0go3LFo9hDROuridtkDLSuLOZVKEHWe7ZSfjdoAzoTa5lv+Lqlxlvw6xKYL4MDIUT" ..
	"dvLC4HqYbyPIiN9wDw/8d7z1PIYsGV6aiWUxAhsSVH1BJ0TTJcRgUxzxTZ1T54czujv2PvxJxWY3jM9kiePHZ0sjLtk+nb86FHyW" ..
	"4SRu08ICSlBqbkK82Cwn5vg2TTY80OvSo8pjj7XzInrQGah3AO7M7nR+J5r64spdm71XbY9OzJdu69rwaN65O6pxnbI/WZ3rYare" ..
	"OS5Wh+Y4vKJwUNNaY43SM5+4y4eLU9eIQ8ioMU4kbU5U13IEetatFyLbawyrJwGFoppfyL1+yL1sMxuUJMTa+wc1b1Kw2SGnoxJN" ..
	"qfK8BBtrxBDGnYiyPNpNCVhDbYGxUYe+IwISbLCfH0LQuPsR2qnv8cQFM7Czu7KP310MlaMkjFwKlZLaRLCP9Vil+KKwCrG94ZuA" ..
	"qaJV5bGTUHMDw7tciVeDe99mJiD8OOWIbvDud/3bP6Y66EAg/c/8vOr1ByyHXMyvpy36ImeyadDpVSK5kKJLcXZOPy2uBLkRJSeP" ..
	"E+JLathutd3IHMfoniNiTIsUHlegIXz9WsXEBr8CahoP9t/tWI0/oLOpNP+L2CrQfcB1iEESWBM3zRf/6eEIg3pFkkmVXXbrRs8Z" ..
	"b2YLcWdVbO11Pj/0DyFj3b8GX/YhUKwv3/8sFGft5UAKyh12J9Xas/RjU3zkJSC1fAPi4YQJMNIkacegJ4B/4qsRVnuCvKaQqlx3" ..
	"9uk5xQiWiZVmseNfUxceM6XWYmh8sZcAs+ID6PP9sOf5NkwR8USeaGl4ptcsFR52fP3DNlRJMoDDLXzZcsAEoSRnjBa17VoFR8Pr" ..
	"a1SiYmdIBvu6AVHw/3h8DdQgYDOQ/BpTHMosZ5O/Sj8jKWyHMtJagkBZaOWur3zyTAS0bur0cBlLi+PR92iPWj2Cqf1bit/YCUJQ" ..
	"PsFR6VpM5NPa8yjal76IKGHpbTtFHicmQgtAEfQwAGMAaL8tgxA7oEpvwNOFr+ZiCfQof2GPz/HXnDK/2zqmy9oQa0M7TgwSv6T4" ..
	"hWX4iUg7MqLQZVGgJkXbGI6I3GUqmCon/i+ic/6UijPxGV3NomGjQVwhyu0nhL6cFzgv6kNmNJ9iGr+5fS3WvqTesDGxp9OpCcuK" ..
	""
local PAYLOAD_P2 =
	"gHYVIFMjDJXvRfmdjfPOCNFap6B6b+VPc5vuAUaI/t0lf+X0cHL1PH1xkzZlVM55irDEa8YQ5LqCosDJ6uIYAI2pP7Yc8MW1rPHh" ..
	"1QHJYY9I+uaftdwTvFYrMnLrtyCDmmOGrT2C5UaNQIKF5BwvSg4B00utoQHQBWG/KZ85PZDcUh5AfNYExCdQrT4GuYlUF/hx7z3l" ..
	"kh3cxACOIAYUHOigSnaOJVitqGaGj24V++sC8ntTUDkuLfUe1SCEIiiNDTW2Md5O6VKIAiWpOu1+QZxz0Own+PfSRKRcstwfkkA+" ..
	"vkQzeKitnA/FalLQo8OUbb9J5j9x7ensmIanX6ufuWnMSVcwbzS9L2mBHIX1iciFSV9Nr3MFLJWN3XCgt1bhwTp+n0n1RLmTgvLz" ..
	"nUzfuYT28NcG8FsEIgP9alOK8Dxh8jRvfv1RTpslj+iUroqKD/3leUEqQlZSHON31dIHanwgwP+RH9aEc5iUoguoqe2GM8qL9GMa" ..
	"zFZUgpJJWZNkue1MtyYeUfMMyI/eYTlwrSQEB5mKfQnzZeB0m6LVPSrvEB1FEbCwHKV1QRHySq7BfS5ka4fDsOFTD5RLLuskNS5M" ..
	"k+upMrnmBCX+72pRfAEwExVcnBHfhhoi9SbpPE2yUhf7LTSvYgQxoPq5bm3pnSCth8GuCcGX99OTSEWNcaaXHaPCr0tqCM6oGSKC" ..
	"rDGCK3zh7pUijwl1LCG59L5kP3aOoECbgRlS+RpKo/WLnfrChbvyvvI/iF5lYjaBbET1lsLmLRl75QWcTltJJ7UXy1YXZktp25wC" ..
	"hFku4nkyZc4sLwy2CnL2l4Tn/+KbXxMOlO2H7JQxsHqRZ6TdP8tAsR2+0wafRzNdORf2JfAryIM6uLcEVp1/z1XjJczfa+Bo4Lh3" ..
	"zR+zOmwTGNX51vJWfMfYVkJxw3ladZGjKtG1oyH1LmZ5TgYmTvVqBTJpVvNXxeak17yCcJit9gt5aOKqk/K+1B4OeuZFVY7lyKUs" ..
	"Ta8PMK+QobgAI3Ur8qgLKakKHrX6gkdwqrIsc21utNpAGlJqTtond+ITD3caHQKQrgsySrWP3BIHmVM1gT6q7b3mrM2GfCKxdYL6" ..
	"c8ry7mX7nuQJxraeVdhPfhGUbijlsS88+71gV7AGOpnm1ZBS9e3aZ7qmqIkKCX95QuwsCFM5XtBCAjEmE+wUF3t6k//RuEE1NKMt" ..
	"5Oq/ACcLNOuJr9IERAt59RpWs/2pwwGOCYrzbbYW4T/MKm/TXuFD/tLqiwe1HPulFOGfZu2sTNDRMg2qITAzMkAvlf2v/sY5xHuN" ..
	"LRl8vX0LSB/9V5w8mIB8gCc5Bdp4XG1jWq011UP+Y/EyHHcF8m9hGdQDLtc4iA4m1IjUaGKAnLoSwxEGEoZAHz4tOqtgQEpe9zp8" ..
	"MRi11IHr9IbnbvKb80CZV47jsJFiS0gQyKKhT1VQgvJpFO1DTYuVPaCCvwnMPo2usHjPcNjCQSUpcuMJKf2Atz6WcyyZ7zhwYBSM" ..
	"6vlXIXBhArs2bUN95k53oXIfkkMxKg2fsgwhGK1VZIpH8hPDKnxu00CFxgNv2Kp/n8ntkvYPooQU2QcHU8pUZGt6H57xZ9/3Gjqd" ..
	"GEiG/+3nqu2Tpe54VADYUiIsdkDhbnnD9dIZyqv6Q+4VpES4yWcu6vAYzdMNCnvJznFEKL4j99WzFlkByJQCDWCxC/2v2F+GrO/G" ..
	"QGWvBgFFK0lVkzwHOGdXc6ljdakjFk8YoqE1RchF2ZoHE51l8e8wdRIp2E5OwecD4Dy+LVS052NQO3fIwPOVfuGZN7hmwGK/FoJo" ..
	"2RRVI3YAgjsu4DCeeJK/ZMcBaDjKKbwX5Dh3TuXF9sngxaFrvB6R4mxbsQsTLMd3c479+K2iP5Ht6TE6khCb/OXpcl6T2VlSzta7" ..
	"E62I9WAiqEO6HKJ+96KhO/9Ih03aSULadBsrFaq/zLZgrsncApp4vp6SDrxkSOXJ3eXwXETd0mDM46xa2eg8jEEHeKddj5zOjsMD" ..
	"XFIfu7YlRswC55tRoUC76ujLBgkQ6Rc6qVOTzKU1xBJVe11R26l6gJfkhy5tIsCyLP6bVtmx9deBQyzz/IpS2sb4CAFqCrnWWPlt" ..
	"HvpdKYVZGnFwFHFjKkYrK/nRWDeLgJAZP1Igu7ojE3t6jUNDGD58U6rcrRIED+Wiqzdkngm10y5RW1KXgKS1YQLIMKCOfpeDmVLZ" ..
	"RvJnUizpV8ntR5NDtSplS9Kwex06PCFi9anikMEIYxp2H+fFi3DkjVhoRGLNssoV21E4L5mbmkvGLdRixsHfR3j42lOI9iESwJTO" ..
	"2i9tZLuvb3AxigFEEj5g8zCFAyQhy5jzN3Bhx8zcKIa/y0HkT9k2EUQ/DZtoLL0L8xSXv47CsN0OpSd/5UXA4V76vi4AFmGX61Nb" ..
	"Zb6zs3um1MvjU2Wl4qFPZ+Vj/XdyNinjTl7tZiq0440AbuU+zkVwdB/SWvFmI3Y7q/hwHWm/bQOw2KqORTYR0r9vv3VyWJ4LEU7j" ..
	"EpsKsRZxCS+GklxfP0QOe0Srqzd9xcLqIQz04o2JKUVtGryWdq9Bnimmj03KCYYFDSG/Ptt0FjMGhtqnt8zwTj9ierqf79bxc4N8" ..
	"Ti337Xeg0v4XXtf2WpUa0QAA260fCIUp83iobvuaHW4eKVhiGhUUTDVPmDf9VVeaz41pEA2Uq6n6StEN7u1vV8jOvnilJgJGVXLs" ..
	"1WPiBHLxDUEj3Mea2p4IYs1k5obWyjr42fO6jyRZq85cHOjUBDBp0FqFSmm7OpqKDsz3YC10rdCHZCr3H184b+4YeX0ABeso3nNs" ..
	"dDnN8MH0U5dgb5hJVtL43ZNhuybYeBSE+fU/5rMYRh4fBnqJmyB8160kGfFYgewxdqo/niuJo9gkQ/IPgVjdnAYnrOdvaYZsuAkn" ..
	"ORDtZW+22HTGkKV35NssLH+1DvHb0zUIPrFDh4lzf20gWlOFq0B6q9aUnlLUcN6L5p1IK6NjWR1kRSY9fB4U1orgee0OcKxzpWK4" ..
	"aGyHJSIkmHnSDXzIJFECaKbkrKWpH1IktQRTVEk5cYqVXv9nuHOBRhMlXrHrJGwcMi6uA+QwpyA+J8xeE1/NyV2mBxXtJUVBZ5pC" ..
	"8W0htoT+oLFhjszyZ1CjyG/OD3wR+ZBAC6EcygMpqfbfvRLrg57btNUA8GdoV6/MHKIy8a32przUWclJ+pQEswAJiKqUOrAfJwo5" ..
	"JDfaFLrSKDTWDEIE+KjgaVX1j4Up6qQnzm9vx901dY+ic3p3+tItPkdkj3ok3BlXBeABPLNnK7CK80w7i/3VnvYByHVqqU19r9K1" ..
	"FWF226LjV/maV0VXpC45k7fYypeFd5mm+3i1CBLHtX6qzYQod+IRqyv0pSCxMyilaSB5x/4diomLHJuxDMyq37T2mw/R8u3QhlSo" ..
	"M1YrvR7lVx4rHIeWiRkVNE2ZRDbXTAwPuuFhg9SeeVU/EPL/05GuTZwXaxm//JiK3idro+WyJdgHTR6T5qIIzUmIlJj6w6iab+Ms" ..
	"dlaXg+uOx6EjTKZQ9ZT/7j4HDLKS1Tzk2MMW1ZLn3oNiCcc1J+elnFLQq3sLn6Yuja+apqzBXAzH0ZIzKW33+ljccFPX9DqOZvON" ..
	"VHDACJKk+HFWxUsd0Je3a9hgqI4SEy1It3+yfB/Dn5bYldM5+6s7Lud0RbtIxTXZz2oufr6ez/C8gmSnYGP9DVRwM8bP5eux+o/v" ..
	"Wbpmp024sPAppwGix9UO8OSM7uu0DXB173rCoYHx+0jlsr/sBDihgZ+Zi1YpF99s1y1ygeNblzuNkD1g0+QdzEScEoHYflx2UmIq" ..
	"ts3J3vCBqna0tDHbvaIaIrKgXJWBxhy4vTuZVEZ2F7Lk9b5mdv2Ppks0CD4CYket1crxURzPO970+7Lttgya7A+0+PlprSjktdBG" ..
	"erFbEb5ulKI4qRowjY9QyUrX5hjzIxckVoCn3TbVAGVf7usYBeMYK1BUF4Qo/OHPlL4yJJBFPNKl/3uVGLlyYsVw4XBE+IhTJR8n" ..
	"OdmjBvMR4JkQnrV2WkZKcA64Xcr9jy8zgaVD0dyw7XxlVo/u/fohSj0E5L676NNXuYorO+oJMerXDfnlKsT+v8KJfGbQGSMpl9YD" ..
	"lJEr9gYtxSDZ+NjC6nqP6yeI1I54vs9flHVgfp7GUabv00NoCdDZHiJIUm+OLDgJUqI4hO9eXbJ7eQRBskvnj4CFaExrSRi669AJ" ..
	"SqdzVfruZvX5M1vHl/QElKP4IZ/dqe/NVujSOqMVgf2OEZ4xwzaCffP4dtAse2dN0yah5FRMu1Q5pfCkUCiI5p4laueW3HGQxL4W" ..
	"TgsYzX5sKZhhYIyWGIn6ZmozrEG49T6kOGuanMW0Dyp/iCKJvtXZHgAuAvoWe6eOdDfevXfSRM7POuC65NVfYVGiT4ZOutzSekiW" ..
	"Gz9oSUKRlVYrd0kXycsLNUyC6666Y035D8bf1AcWvcfrgETZ/A22DvSytopG8H/KC2byB2xwGfriEgzzolkbWaNApYkM9fLIBQjj" ..
	"Fl15r8V5maujHVcPZV3pxUxHAb+ATRv/grSB7TDkAjtk0/zLUoipgOTI6qaK1lao6ksRrP1U6Z2ewLNO2gj7ZVWKSDOYnMyieJOW" ..
	"K3mMWQpkevOJj6rDfHggMpVghSb/yx5IRUKS6fGdlZLekdTM1C4FZjIE04ieoiCUsfL4OKupn96zpYNMrdtQXg0CGUL3/9eKJUjf" ..
	"6xyS3Xa29Io9IrEgtK43sULHnncFrvJ/pO+yAmEqv17tcIuIO+TFm31Bdqn3ByczQ1L7bmijAIGUsjjAORuDPA4vjgHASqFlyaYJ" ..
	"zBif9DYyejLv8zwwtj1/gx/8e3Z57uFal9+aN1/U51tRLgrF4VyiP/FCy2Rz8emel71OQ9HmCE3kqAFJEdskIxvm2uNmdWCL/92A" ..
	"AIOUNJy+mnHBoVRLyeaED+9cYYRTrqiYuWyS9z+oP+iFqZkW/Ozum+9lWDxDA8/MrT8FbM4MdUwQxoZSirB1S4fZd5oO2+yJMF98" ..
	"WWPJ2POH3EF+iIddwvtBB/5uJzokl9Cyt4ovkIg3obcvG2NZ4doz8B/3tgi/TPs32O87QMH6BdK2snKOLksiRvPMh633K1+WgnqU" ..
	"HQkzfCgJWr/TWvErq75trKiEg54aEAr8IG7t+GoQFN4UeesB4aKxuvKgxtWX/ZvqkyJS8ezxTgT/gSO6AnPkcJCvpomiySKTSebW" ..
	"hF7nAadilTV36yxvwQ8vxG96Ue/xGXnfLYgNzDcvM6DDE1XGVFQPpAVgn127wGj0weFvxGjRb1cgU6kF/aLO8sspJUdLMAJ3L7uM" ..
	"vZQ8a83gLYkZkjSXcIhGcNC9Ipw+9idKTDAVzMSM/2ya/cbmbJF9KXjaEkpCDSiTLeLN/Ojq9iCGkSYWjJ+v1gn7VgUHcuHQut2D" ..
	"vWEWsFbLvpXhWdd1ICbhArJ0hjLNlK3b6mppftxfeofQFDnbiKgMGao0RJGzwvjnkrGNyaT5gsvKkbKEyblurWaSkD0K8y39uRY+" ..
	"rY7X/vGyNoClk2dXKCrL7+NbPvhQ82DUGDT6ds3M6lfLN6yzV77u0/ITG7CtxECI3mdPQ7naYycUxxJR0NRxxnGBx8RkuJq0EuuT" ..
	"b9iBwdJz/zYwkxEpaHZe9GSMguA4TMqHhi95qOERc6wiIGxBoMmktjT44nabEi+88gSkZP5lazaO8kmPsfwzp5a5VbW86kNl0vqW" ..
	"RmI7MnqYEtbUb4BnF7Rv6Kyv7tv1wCkGC1HEqk8V/IcnE6eFW34M8nnLwp3HKnC65wof5G7Fqju3n5dwVLq6AhFn9Z+/7IErTIpZ" ..
	"zpWKVUG7es/66jRa80BMNiE9abVtxYtsRo6rBgGSMEDao5huBV63Uf+t9SJzijnEX8r6JNNbrcLzD5c/GAD9h+wlGtZf5E1rwYJv" ..
	"VKHd0dy/z5QqMxbLV6oeEsI2wKI0AxpRMm2/8nu+PWkZvpqUOiOK/mwtxEerE7xDVKgnXPFXHiOL3vpSsDBre1cobv7WJdCOBqXv" ..
	""
local PAYLOAD_P3 =
	"9knowN7L+QFbALeaEn2V8mU/fgmYMYfZnOnYkmbsucCSq54+kt0Jum0j7Hfwc9v8p/T8Wo/RTVLqcprAAsPgdfmsebbdyGm24m+V" ..
	"WU82o+Sbg35cyajGFX31C4bJTMlFYhzKoXP1jImrUGSp3yGkEa8EyaV+8AIhafUNTGqdSXNptIKGHqiFiuioMTXLg8+Nxt4u2qgW" ..
	"e1yHMfxR8PcMwnNUO+A+uM3i8QZXQnRnXhQoZzyYsUbbRX9jKZVoRlROt+uvHgp4JsmDBoIYZkPvsS6iw8Om4gtV1EJCEbrNmdSn" ..
	"zMOQrmiTqxloPvpGglJkQhSjQZTL251/BTUR4lFfed8yBkuBYRWw+n9Zi1wPrplL9lNv0wj9rwhizMXjVQhdqHdGB5Bpzr1D2Ax/" ..
	"/x6LkT9PgXzJz4GRaII6O+q40qAsZiXnLa+hlmmq/BRGV+CAbffE497tyTWbjGopM7JZn6wZ90OLtXnF36hZZuncCZkKFFe71u72" ..
	"b62AXdRc014zXloJSalarubfhMSEWmYVnrsWtV56PIdQTdUIJQh/nsAGdlKkyo/0dsZGnHXGqkhwSNbc4hFqMcz/AiNECuLf63yJ" ..
	"FgSddBB6NZ9dd3u7WI4CR2mXcbLe95gTyPVkV5b8ObO0GI6mbPLqeuvQTPUHi/QqB3Y7aHBm6xGNwptp0nbnH9NffHWS72EI/Nal" ..
	"0KyIZsbeDnPQCAqzd53YCREk2J/WhTyt606aeiucTWAZQuGGrApd8THbIFzJEFdvrfP+ipM1o5qVipgfxGbr47pkZ7I2XrTh0FgW" ..
	"r4NiHz4IIBAgFBNqfVfPFZ8rg4O/kAugCubxegEL2gutNLjz3J1Lzh8AdGNJhN2Csq3pQwmevWrpzFgfBJeBSyWy139DUuzOicC6" ..
	"e83HE7otybAHPMDbfPyKviSlFaxnXKKEwI09/VMMw/jlahVOaZ5aPQTA/zgj4g1p8vdL7WUd6cG4Vprz1UzFI2kZ1fVxSRqDf8q5" ..
	"Lp/KFwKOs3B6+FvnCrKihk4EFwsY9viNpP2o7bx20kTsNu2dbjokeMwb0EGKvj/0wuoXMXNNRNTdMadvlI0cQYW/uYcQrtTKXGOn" ..
	"qajS99fYNolAwWvpSROnNdTloCBJXjqd9bNZZMgmmHGGRLNZ2Qa2v+wwtjLzG7a2g3Jf5V9n8hMAw89hOdzoMYAGg0W+pIWcdUZz" ..
	"+pfyZGbFbZGVBgzfWmoQtxjRRA3rc8ipxrPhozT3y2A0x62HFwypSQ3Rhaj9tA/VWwjca4pITPq5V/fB3sOjmc37YpDEoFegtUfO" ..
	"QMieBTQZsqMvvPDj0/ZvWlOD1bOu8Pt/y0v4qFltejXuYr0p7EnzpyTsQqIBdITgn2T1yGpe1WqENmxUzWhtHbdRuSHs6sCVxKYh" ..
	"m3j+OaaF47hNUtIvbEX8Q8tccNM3idx5Psy94mMpgmbSYZo0TpJGPurMAiTcV44Hgw53TzbcWeDiJE/WvkYJ7dWj9qKu0B9p5uHX" ..
	"6kE/cJy0wuc7mdQGleiDU+xwCMm7wO5fBqFt25qHyenUnoez8gtMWSPS8rw8VK1qtoDNEoKQ+qSBCq+8tc20RZeMatqu+UmmMOLE" ..
	"QRI1E3vw08/W4AnaJkJjZkbjuJd5MVOKcZ9h4GIfxkKnssUkCp131bGqEsCOFjlxlt1plZ+b66lnfIyMw2pOdzXSbLpxjlbB7O9Q" ..
	"+dzi4LHn4vlzggD5H2tS6llEEaM/BvY2qtEGVt+qmi3i4SIPpUkGlhI1LzVvDF3TnniUEln1J017DBlalTZsDTIXVVuOFCZP6+py" ..
	"5SLz9ex/8jHZcXSkr9wZQcJmA/Xr17NnxBQpNyIqUYvesWJsbID28BbJYQbCAARN91tXg+Nspt9VuvRJdsFf2MIqt/hnyV+vlyzf" ..
	"D+uzog6+/mJ7LEl/q0jau+vKVKXjuOK5OxyZ8bUB8PGc+QOmE9k+Ev5VOqg1Fm9K77Sxs+mIQsnTnbWc2OLuQShUQucxVfaOYwVk" ..
	"PhQeyYNdvDG2DlwpzmaMao10JviJ1aj5joVIjO2ocuGq0sOD+P45zTmAThHRfCIPpdwTDu9mnWaytAR7vZ+Uh0qdi5N58z5U1NiY" ..
	"3axA6nHC8AJh1IZc8M49QV1J6kbO77R7YUsZqcqhN/4bCuCdmf+I10H8nChFMEDoUSmYcgMgWIhZcs3+kdgRvkQlYHIqpZV9pi6O" ..
	"To/MH3Zn6CJ4yHCVvGesRVitH9ltvb363ujKmhNQkG8dBq62FisyY+0ex+iekm+Z5o2YUXRYJupD99AgxqJSS+Yt9DwRgkDFleXF" ..
	"tOeKBmt3PmQL2yxbhyJuRa5pjfwoPrUQxi+/zq006Gh7uAjCSlx8czrKOYVDKO4upw7tya1HMWWjRPKUX7UL97XhGpXWTzJ5a2Uf" ..
	"Hr+EzVT00uSaZq0ZyzwgQMxfhdbGKsz2FkKRLGDc2k94KJwzyT2LUezi+EiKLAZ2iPvx78RaiY/OUz3SFnqndghqf1WZnkUxs1EF" ..
	"zVcgFrHqA6Uh8D7fddFgzgkcFIfVsY2WGmk1bH7ItnRtDDe6dwhtOKvPhG7gOwr28JER+fM2RicHx878w3uLIWy1/LrLwQ6m0/9Q" ..
	"wDWF1RF798QBT8zaBxbsuDDrp1YK6Z17TF9yhLsGxa6vCuCcWtJsrMyMkSgfuDVpNwBzrWgGTorTGdo7g7Za7uerED22ybnpuTBp" ..
	"9MRJPaF78/lAPj7nnMPKnLU9hx7hmc66ro48Kk0dKEXtPYvhciav1YLNOj+y7bN7iNGVI6FxSL2kNYyK+7N+rsUMJ0ZY4PGJVkZW" ..
	"ha3Hwcn7yrKa1+StgFtQwn0smvj5jDVneuF6bXhUYBjYYgE71+dwqu0s/FI2/kjMQQO+UmffYx70LLrQuINdRXWgkG/r3tC8u9ql" ..
	"glOnONVRoFQ5X1N83kE4d4FHiJpRfg3i0CGkAsHvBFAksj8TwSzbWmw8sLnLyBQBijGa7JWWeXu+fmtCwnwPrejg9YmFNOjD68Mc" ..
	"m3Cey6hPcQd43sTJ1PKDax0M+zKZoj/c89KLXqacRRgsU+sE7XE7Weu6lKkMaHM8OHM+UxBChkOA/CGGXc3Oa+h5Pcktrodb3fRR" ..
	"3eD2psnO8cHlBCLO7cRRtcPCkuVu9Pq9g4rUDlAR8npoYr0kxXX3orJLou7A3VNQdlz8saLbAwMaV4d2XUG6r/dsSlU1duksSagf" ..
	"DujH3ox0Dvo4XWk2Zblaq8ia6oJvNDYrKsimF7fx2r0eXgThh9upfaEysfCQizyq2oW15Vdvu8xGoaciHcSJ5mcp3F2BbNTQ+nEC" ..
	"tGsvVKZXThJMFNL3KZqH6s8j5ulQpwf4rFEUXKkxE7owGK4BZ6ghtbX7S46AuNxGLwE9Hr9Owy9SLFtQeNaaX+SF73pQsCbJP5V4" ..
	"/ugCGLXPpStreK2+SGlBj50jfwr4gDUPy0kktUE/PPX7DjyMVGkNY8+mmkwu/mju3eO1GrgZ+PykvccVtV+ZgknddrKTMGPwfLE6" ..
	"aGau8J7jTU7whLsUSBe0KyS7yZaV8JNt4Bi2mMMTWJGJCo7PYpVRt+s3Plm1O9H33OmhVqXDRT2Ue4aen7khM+I/bY2pvb+bi9Hb" ..
	"UqbhcdwV+pABw+q9VtnoUfByjJNPcNXdrAeSAP4+o6R8Y1rPHJu2YoGbUuzV8GaJIue/dWbTmI8Op4GrJS7X9wEqaDdMKO2yi5Ek" ..
	"BtGvBMkRjlZU+8HV5ngldpSmWxuQd6YBsTCzlRdY1KxJ42JeI/88z2ikcGIZtMPubT+M1qpCohVpegHoscMJyArCrE4OaCf/45GV" ..
	"RjqHzDYPchfsClOZf8dFxrrZrgWO9t5894m3aehQmlufcaNgA4KAxUWQT8RfjX8cFU5ZGztHyD9KqqQZk3b8I59XpUjr+qF1cACo" ..
	"QP1A+xh4IxBcdgiztlLnD3Db9PEYihC3t7CdCMxLPuLwHrnUebEdpxj5yY4KtIGBtQAUcFuP3j1gFB5Xg6RroJh/sLS6owM0cSXx" ..
	"hWsTeeZV97QyKmumTmp9hEotlOD/Rnd7v7f/DhEz/2BZiqWWpxmY+pPTHKsUKkmwclaczsFZ4bInmJFntHlPI1jwW3ovrILPJViT" ..
	"CMzn9RTJCjV8Q4AHlxBGa8w5WHXGCCRnv7pm1mKEua1NxvtKXM4CMajFrGxDYPdw6Lurd47mhJK7FQgk1TUxgHZqrNCJGTndWail" ..
	"jWid6Lp2EtJhwWLVvGI2+2rYxo5R1k2ejO3j0t/iMM1uJnwoznWPYgY9X7Uhu/CcRLuOYzB0a+KZNZbxoigfvqbeAJNVw9PR2U+q" ..
	"ZErc8j4QKom/dnrUcWXG1vm+NVTxTV0/FR6z4zbo3m4zwqQOJI5FBKu1lghrHmj/3tZEVxpvp2//Y3IlTX/hNEW331XYf5q/XIBl" ..
	"CRR8jb1mAJXrToI+LzP8+qmeKCbmzmrIhroRHHLAWfecLAsCLpss00RfAzxcM025Eb1x+EE7h2NbzQCQ79oQPS9H81jbKIeVUFKP" ..
	"T26J5U9mARHXet7P8zBvb8Cg+w7YZMXPkPtfKB8wZH7PqG4ye3TZcY+fK/cguSS1fLZxvX/0h5KkDzRd6Taf7BNi5NiYndLeOVk6" ..
	"D0nU4tFWZnTosTWUBol6RS6oxrE7mkYi3yyJHmEjAPq/xr0JKc0lPP/Cjjv+yCh/QzD+EdNHyU2gdwOWoTiy+8f3Eza1UoGGlKOP" ..
	"sDHGHxZobzFEEecbK9h+ulAyX3ynHgGayb2yDaUttcrx+/6wqog/kX91LJ+ynCAmPSbR4nIPD4H2jgAum1vxz+MuFe/ueVDpqb8C" ..
	"JLw4kceb4wVKXVRg3eNflheXBozSkLdhJPE7ja4p5aoPSqBndcmlVu1wcwKWHlgmBZjp0J7El1a88kwlbFqjzErXwcJvImI3OORx" ..
	"FMNb0pV/0FIQerbKhz0odpulPizBmbFGg0PaSMWHZ0+RWkGS1DFSX7A9L8IB+An171C9lyg4kFwEYVq8BOlCWmUqS1CTcbaczqWK" ..
	"WiHvAz2feoXhtNA28rhM7kWtBkhfeAtDsZodMLVWGlXKyVmP5VqmWDwiC+gL8mNtWtEnqiWO3PiJpnS1DxMYrJp6Dns5DFBu/PHk" ..
	"0QlJkcTCFOjhZJZPbDQwOyWerFU9/DfYkU36bZk9iqQgdVNsdzxnmrRSi7HoveKVPUL/0q60IKrGRp/mKaSTy3ykRKRdfAxC8sxl" ..
	"wVRMCtj0tCM9PgS7dZ7rkZ/r02MNocA2gVahbumUoOohsTAK2pVNoTiXwRJVH6m3qe4p0aZ9PUM4c3fbgozEwGWodeTKX5IgmhZJ" ..
	"DdtE9iYb7oY+ySsiCy0ORpfixZ8cyofl53xMc3J4zWUt0E9bCSRyzdrDFmFOPWIIL2YJHIWVGurJYCk9JG5YBqBgPdaSxkbHc8/H" ..
	"OVOvNvSwzS/kgGDf9/vfywkHpUaMC6QfAo9XbrRQs3bW2W6jdggwXTA9lJ3VzHflHfpWAWGfqmw4r//w3MV6yYhxl12hnYusAgK0" ..
	"82SAszgVWyLmGkNZHtER4vmFTXy3P+D+u/YCbyMpdnUvVMBuxpDZ3qzmr8c0q9AKOCG6v60DP+6qJ9fgKxn56WjjdZTq0NesutAX" ..
	"R4Aefuyhn7BikK9pKunkn1ZeSbflVZsbxzdEQ6QeXuMWnS4IPXrNbo327/xFXUyKRZ2iLk0l/aU9XHdRGbQmmKHWjcP+ikpLnPtw" ..
	"K+BtGRNhhzbmf+SSi+MXoq/8vEpjoRz4Pp0gUQXQ6c9kVnQUU7JMoK+adXHtPDjyhBbpC/qdxktrsio3/+ZhFuO3rxJEENkt7aZ/" ..
	"iCPaFw6E734+CXDHNcz/1VQyp/kpfrw5bD2BJ2kGy6QQdxpyKVXRyMpatmVpowEmtNqRbX2atJssOIupW5qZuxgELlFrn7Wltcft" ..
	"okqJ/2Qi12iVSYXztZTKNP0xDuiox6ezEnQ1RBFb93z4mw4kJNhAMV657uabANv9HD6S1/DcCgsfgnozy9Uw07mgBfbFTdUpAMIX" ..
	""
local PAYLOAD_P4 =
	"ir2nNJBfjfbVVN3UcG0vhgNbjjJG3ryZux+6XNcr3jvOrAOc9cEHAFcw7vkvOn1kCkeLk7odcceSWglTM6FoWhb7pq7xQ1pE6bKp" ..
	"zZn+u+WKQ7kCiMttt/JmfVEtxt3YCqOwqVcsQLCYY7v9y+vTDY8sbo+8AZhwvlGU0s6SlgL5zkjrpMq4pq89XWNh9vSy3s8HnRPA" ..
	"F+EgLb+G/9Fo8p0rH2zcyT4itX4qPVVuoFWM/ff6mvp8RKVUdDVCZXKEoLf1A9zKOoErjCAkfI086aF2EBiEkd5S9WI3/3OTcdBv" ..
	"sXvDXEpOI3SRX1sGEUeETVxI8sJ8cqGONp9NkIZx9dMSP8vbG1qjVaHepT1tOnDtl9eeVkC5B5uLWEH2RCilrm/gY6+Za0qM3nYM" ..
	"3y8ZCvM2lh9LWD9wtczsyPL3SnAPh1noq8lcxUqk4B39AGzVoMCl8upKj6BRwAjNB2dC/PEZIbFE+mTOwWpjtBS/vKWi2iSZrhAy" ..
	"i5DVoqGkKUqceNagkLickXN9SsvfTqItM0TEgQxanBr1RydfzZqNQLpHYqrTUp4Nd8Howaq101owOF06JEp21SDCpkbDcEcnG/ZM" ..
	"UsqdvXWyTYJtxZRrHgbeEaUqCcMqxpsa2IrqkbSIRUgyn9/CN/uznOVpahalIQ8vprnk7jdD6IeA5U1x7ewbsd5q9JbeiM1oxaxP" ..
	"aKxy3WJDfkUtdgp/IVHCoCLEEUkAR8Ps6VjjIDKo5fFW8YkYdU9IwWCpximf/VtkvymXs+1S++iwNXiWSAmu2GC4FAljPlrsNfRq" ..
	"UqTEiw47LCa0XjUlHplKmPKPiT7TRJrBczqQRnrrCm3ugypHD2MFhPUGJODYSoFwiBT28Sb+6GxF9iDnk2EBcDslwpS7/StK8VH2" ..
	"8g/5QwzVFMGtUVKUVulXU7PLB7x8WbUtQ4eSVypI2rvqfNtLTjM5OMthp55Y/+v1JLmXEIH72RJDW+chsfDxyZYR6rWtvGiJ6l2m" ..
	"joL+RSXhHXdNP4zN12Ykw9XUtjmDZKbLtSzWuUHFkk32hs6Tou2jwVVnF7dUed3qOa8fDx0UiVJ9GFexRpD8wslVa8pnYq/lxTwD" ..
	"Houok9AjiIXjlmFL7NJ0suAsAzs2Dpay260yLvlpNO7Ao8RdEE5Kx4e77Uxo6V/QA1lJHFs5jeUL1PCpydDNz6vvfMiUONnCWHOn" ..
	"vut8367fqMtp/MXNv6m65z/PDBwefI+WoiBa+Tu2N8E+u364UHsA4ik1wXCx0knADkPmKutOKmFangBS0dGsaOJHo0xrB1Rbj5nq" ..
	"e93h7YOdexwOmxYAMqfFvLvZ0JDmyQdFOQXwgKa5R+IsgVBPyb6aBTuYZUXMPUT2oBVraxnsq81+QWCfe4Uh4znuGbAyxgNAce0z" ..
	"SWMj6qRqPGEaNA45dCwQHdDgCt3QpgpASV8hQHGZhwpvHKlM0mR8D2VNdxiM1LHEL9mrmcuzSedChS2A/pza8MxXG/IOHr9vyfpm" ..
	"9l6KhFx41NbP83gz7dCzcZAhx9bIm7SmcxmSF52m0PbmTLgcby4Sz8mudMAUMCLAvPrqjNLE03BorWO5OIh6mSyTRNTZlf4a9c9A" ..
	"eWu5u6kb0H9xLeoIZ9RC02wTpm8NiGbyzZuCBRT0Ekb5MckB4x/YyQL66TVwZiezpwEzDXj0+/iiUFWDpRZsFDrmBByf437867wS" ..
	"z4tVgs/g2whDCXp8DTO6DhHYf3+EWS9B/3oviETnnFCVYRYdaD4sDC5wUYAk+j1/1SCCJHJK+d4vWIXvx2cKohDkEckeKd5U3r9s" ..
	"epoEsC/s5a82qqK+w1d6ZEkA6m6/qiqPiHtS9KpKQ+yoQ0o26sV5BSBkPk/k5bJ7BPVLYY8S3wOOckQy0gGSLdf1PE23pvEFBUoh" ..
	"pVJXrTiuE3mEZOsIgSExwbQqz0SbYfGIq3FqT3AZlOqc81uqC5CnFnav2myGlg17dqmF2Lfd1usRANGGSPpO1SyLHYvaFcHUD3eS" ..
	"skIdGZGgpoTaAOE8TUAWcl8orW2qaSyT6tEBvdncBbm9P1KfmWXn6VfZq5eSTGgmd3Ewd0G585VbO97nydLVqAk2TVDLFHxYet8N" ..
	"PeXEWWAdWiRxxYbENWybcIJMZ2mzvpGpz7/kiYagbJxPc4NxAG6K5+kmEqC0aFHqhMeEtvQGuRJK3EFY40fuNaaB58ECfYm/ihQx" ..
	"Tr34FNeRyGy4ieMMIjQBEuAjFkB4743A1/IWYeLmP5+fphiAjpnje17Cvuu/hejgY82uee9Kaa0Y3A0QAYdkpzKScvoGaGgs+tE/" ..
	"daGonm02EcT1w8H5gDteDIF63VCgCRQgWWe1lE8OzzrsCaiNdMJBLZvHDo04QHMT3Of+v8T2Ib6dgW7jmL+T4pnA7CYbmSVR0Tjx" ..
	"n3lBfM7VKFiJ46FvpKAhfLPIS2F9tPs/AOwfKapgrnsWjTtvGaH34nKOjAh2GcdACDEUYWvOweE18QdAe8/aCdEO8b0gepifq8ek" ..
	"KOj4K3ds0bLGl8Bef2C0O+jdACABWt9mKiPk/ZLJxkEy+4WDWUGuTGzkIEcibEcatvpVcTk2wPcScFPZvHLI37o40GBAynbKW7Cj" ..
	"gUztSONwHvpD1l8rzRq4TWTaWZzAYRNAhDWM6tdJfr5lO0auJw6XLB8WIrQYm4wx4qaGmEw5kfd3r41OTONtYOU1bfZDuyPqgi5O" ..
	"ECFKkM+AcPLser5+kK5QersiV8xtInaT8JSQxvwte5PjNwdkw2QkfFKECIquW3vIXos2NSH16bsnNxnod3NpQuj4t30FrM62NS7r" ..
	"kp6xJYBYXEutGZKLiepr5WoSc83yuIkl0rnomTLl9Ki5mdrVEMQj4V8hSxOAl8vUNmTpfvzdUUZpjZV/n1pUYwJ4mPUrnlwiaFc+" ..
	"YmzZ8R0KJ7BpkUhwpuRzazWxxi3K0i6Gilr34Y5N33GDOvzJzyDwk7N5dwCFT0yyBgV1Za1nEYSmaH596inWRwL4euuVhhWWlMCK" ..
	"zvH7ykCkaxE2X4Z6ubbulSLs6Dr+m53rLaSpAzaZb96v6Ak2h/PLrLGmFqME14d0Phy1kRwxRCAdrabtPKLdth0zjAONaFy/Kkts" ..
	"RmcFIEHUWySnZHfonWVjkfFbXJCZwWbKD1JCzv1NeqIelNs1zZJ9bncgnln9CFCDCJBlRbdR6xfTLwQ6K98lcpmUSMJwMCoGtM3t" ..
	"YlrCyGKv9T0FmhQB/ul+Imvzr+5FxgCYCi9Pz1kscHALsprktKj7go99AOLL4V7B9J0xVD65vtXsserK3fzW4Mf3upwGvcNEmGOT" ..
	"2y2eykanUt+lkck2zRP8L/eeg8Fq2OFAZWx5GfenH/K+F5UeFfYn28Yx5Et64lW63c5HAp0MSSoeF0uM17llRT/hmjJmA39UHrsX" ..
	"TuskcF+OvCydzT496Is4Vt41MTeO1lS1IfPu9YwD3Z4uSRz6w1RNWr9xwMQvVhI5UjjM2tKHbhAt0C0urARdP+UWoNcgrP3+Jcpf" ..
	"7aGjGcabW8jji9Rw1I5Izp/zp4oxBLS6dDi563r5DKJ9P45MibGOBfLiBHQAPkM6ICWVd6/VQhYD58/7GfJrmoT8eltkDncm0twX" ..
	"QyVn3EDCh1z9ymKEPzt0tanPKeKFTbVLKW3z8/uEm0w4246qWH7f0qaGP82WzQdRLLus8driFUQp7x9E3G0P21c8ilvZxUlVU3hP" ..
	"+FnZLYZU73fEeBn6U1n4g9lGLeEPeGbra64IqoEK3kM/2vcAXCquzVERyLLB/NTtq0AgHVoqNWIkcXbcawFV48rWTuflcnRMh84u" ..
	"HvTOyD98Fxx9moxhX9IJxuEunIqdyqqd9fvAD5rBJYFtzd+Kxl5Ay38zoowm4Aaa/bPtRoNsgYxO6+uQOZOe6osEcb7ul5nbtAeE" ..
	"RSqIqHTewFGxR6ThAisaK3WiQ8F/+fW86/4bjHsB3QUqcP5sSUgZN89CI9rEJU5Y1goMBWHrxpi+FVo/IsQPeawiOBmBQpLIvyd4" ..
	"Jck1yFv9lulMkCeOEysnc2KmaNivN2YWO2qX+gIzwKnDh49+Igb9pBQgxr/W/tDaoKYbjtZd4C1Z+0pcAnHBjbViFKXP+9sT7rIM" ..
	"3G8y1E4+cBhHRGABH9WmaWMcZeFdBnxX/Itz4Lwmdsqxcg7+nl8w7Nke4SSFiUBH2jZLRh9peAln1qRQ/G+PQrPXORx7Iehafu71" ..
	"qMXI4tc/0dktj1l/OT0LYtH7pHwqynmjeVdIB0u9K5cEzaOZNEjv1r/CqdSgxCx0W4EBY5lEi2aFSMGrFVWuaOdNu7ETXqxKQdXh" ..
	"uBw9nLkbBY/YhrKsqbBBwX+k179ICuXZMKH0R1V5j/wD884d8n9PVhJzghJO1CJpLRXN0j7URj0Dj3FZZR/JD+TjiQurFTlmC+OE" ..
	"nFm9l6nI1g+kxyIzDwM4UmfR48vvecDGSKwTUUPvA1OLX+1KGu10Mcp6EbuKByDY4W5toNO04ZF3fER0KRiCUABx9ZcQVQi2QNKj" ..
	"Ou5IDA653w684Ca28iiiHq3nTAPLLD4Z4cKAOX5f5wYzUWo7/hqVWeFHh4P3m+Zfz9aQznLimfhCKpQU99nNrAfY3X3hOg2sWWAn" ..
	"8EsD96G5NNo74k+WneYT71KaJFbA5u06tHpW7TDlPjME58gk3ZlXGTjA+C7orkLFj2NHgDLhhjK+ZkO8PG/ezqoTT8S9LJkAlpv6" ..
	"NvUF5fzdxnY2ue0YiSXmaQgnogt9A2M5uw3q0+LhAEXMUFfwKMLvT8Q5K5UyUH+6JOL7SiJ78ujwMsz6T7+PtiHSysRoR0YH1eHi" ..
	"L/AI7Jricuhx+9GbIJ1y8KNwinZLXYcdaP1ArRZ9Ex6RiOiUnsa7UefQt3IDPm1ZJU5M0eE6amnRNUyry/lDcv2WVAd0j1O1TZjH" ..
	"2vYwM5re9Pdexc7NT5RK+tjw7Kc1lsy0KkDi5jWXP/Tw1FaQ4/3jB4E0bl/1xV3HQZMRYbzrQZpZoJejAag0VaB9o9cOhcbS9Dav" ..
	"jvEYP9orSEH8cyOOq9WBxH/8EFm2e7tL8F0mqXlsk3POVK3SUMfBFcVf0dt1JYYW7yQFTRUr+H/064A8GatlR7ODwtkrp1X1cMSB" ..
	"llFFKA7/8kL2wVwTbFrukH93+2DRrEp8bd0U7GROyCodCqkF7zZSpBiq0q0mxYWhDWI9Ey+hu9U5sPmqNarwXn/utx3pOzTRsaX6" ..
	"2iZeq7Z2UXsGfACpTUHzbuvbRmAv7pQmM0ZAp4AVbxNd3Jpfqvwnnr44r8nL7wkMUEzl9hdleMVB1ys7NZ0oyjXyztTmiq6nT7iH" ..
	"C5zECuGBjNVk0mMKi/7ktQewKzeADr6ZZfsZW5C42kFx05Fl/itsiIVcSD06GK5ieEmX7NlxxNb1qXKzquaVpwtUUOvpsZ8yAslU" ..
	"QZpI6f+6XaA4AFgcMftHz8/3GF2lk62U4Ilzd5Ii7ZoZ+kHLkR0TIfu3TXlVezfpVrY4kx5LYbk5iRI35fr6TBmBSV0VyfdZFAKS" ..
	"0Z1hIAVMA+5juYk3sj0XCaIJhsinfuMSwjheOVC+9YfwXlUr7T2ySWusy4kC6TP18lORuDejf0eWI4J95h6tsIYLDF/jfLYBIbTF" ..
	"dT00721eib8f8SufT/DWPGtINgvQ9Fy0Okr7ItdMgTy3gRyDgqON0iOqBT+fvfdro4/wQsPSnQvnMNSdcINwqWWnvfZANdg1GH/2" ..
	"1h9++k55Jn/yCOIWAqWWMUom4dmfXwxxl4bZN53T4OOyNZkaGSBvhmwMSD03s+uGMnBwpoR7pipjeIuQnq2PpZrtQGXZ7V91ZGM7" ..
	"spGwnh5PwdiaZKIYnPKqTU08JPjQXBGjIGOD9xYyaonalcYbd9wkRt29eS1r8bWNG3MA9zerB9LW5fRkrlXUNX4Dql5lsWlNcrue" ..
	"Is6Yfs5fZFyPYlMk11mCwLY7I8CymrX09L77e0s2WGismz9SwXBpaGoTGhilSpoQqVVbSTULMZGopWeJUJegaG1Rf6EjD48Qw9kt" ..
	""
local PAYLOAD_P5 =
	"kkx5ZXJMrV3vw0raUrXvagVM/ep0i956NAdeANzQUpeIKL5Zk0BcH/8qbPHBnzvwCSzfjfbyQYWGaWgb2I5aF3Sv+FzmmhdHDhN6" ..
	"V8fnJsoCEO8dayPoIHy1w92BcPG6PDkgt8AVlDq7Vafbbl26DSbwuPB6xM0fRUDglhzQRCgPlX3Xy2e5RWBbXypNYbjy4KnenEAb" ..
	"Bmk0yLaJ0P6eGfzy+VN8OL1AB3/sNKXtz35Q42SK/kYsF0yGM1LI5G6SUBpznhK44n24RJbuGdTEKWjBmXZK7sn62TS0mll9mI9K" ..
	"aRlSme9ga+xe24dY9nv2juGotS1bk0RC5q5wGumK5Ri9oPh965pE66X4XWIoI1XI1gzcBqwum8RgxproUQWu4NN+u86JN8T06zhb" ..
	"+xcYNd74/8w/xsoBo0o+EWqnutNOuH4gBQi4zmalJFzdxoOvy4GdFj2BdS5emZSisyYNYO4aq/U/patbbRlLhCus/4+f8HeE+CqF" ..
	"UfP72O6Yi7Cp4Pa7mIvWxWoQmKhgxlee0EvhNDIEitb01wKeOvOz9Q7JlMI1UFDp/snUG8fgtFSkuVXG/d/jpMbgrla6Hc8YYvHI" ..
	"Bc/40chvKuxr2Q6YFrlN7d3z6ex6E3Icyfq25ZyylO8dSy+MAizHH6WntMv1VUe3spmtml5A5TI7tvYYoLSxu+UlvkBxxw0iOnwt" ..
	"ddteA7yr6IR3txTCvNCpze4ylX0CUG0yA2gLzMtIc/xnlXJDgNkEOuLRoHZpHIhJ9oXZZ0QepjbkdfOJSgQ3h22QId+Vvv+UbINq" ..
	"STcHJGCiVi1wCoV1DcYGApOQpKO89DfDS2C7GuTTWWDjDSlA4ht2q7Mjy45V2GQvOK9Xq4af0Na7zt2MlXoAqulcGlvUZMnXbL/m" ..
	"d9zPmBMinwMfyK6YFJn+ScvVfubxoYhm8NftsxhXoeLF6D/PsRmKXQ3OaSb/VmulY8m9rbdMgcdKkUJoTzHQj4xwK9b3knNcEBdX" ..
	"Bi1qIWF4J/Q2qBb3IbVTH/6UNrEfn+lIyHBH1DH+lWIbtHGf43mmsCi8aEbmfMWCVFHi9JMVdwPap+HzBOrgJ6pwMXPQWAWbmnUA" ..
	"IpVIJGKQnzr02K6hBxlZJUwoOM/a6TfxhTGGy0f44w/6gTCwoc/UZ9WLenPW8hY92NoXam1sAla4h6O9Gzg36EQ408l0SjMSxTSU" ..
	"TXUt4YDjmNHQE2+wIUR4rJEbRpv62xFyOxpFl3xJvE6mRG7owFT8c1KjfDhkT90XNlzo6Vm3VvO31EEl7zYpm4LzyiTcg+MKScuh" ..
	"T7JpjBRx8OAOMuISySweV/S56WH9IM2cDomFpWT4DMVSpaP4LeZD7NK5Qb+IFimMvoVdgZ+c15x0UHgTV267ltIsVh/UHiBqubr3" ..
	"Jm+NdEx0Ul2fIkg8ORDBXmUmilE1RrdZdgk4+IKBOvBdKnp00dUBFSagzs46LmYtf7XXQ/ZcfFVW8n6rbZXe0I4o0xA/bhhr/qF+" ..
	"mUlSuJd2hxptKHl/LtuG9aCbWGmV84IydzWhrnoo5Mr+x9PYfScKV5BuRjqoI6TTrjMt/56yq4uQsJoBFuSlbFT0LKgUOhY4nAEG" ..
	"/Uctcb4X3axD9SPjF1HrvjuCRVd/Jc/ChvvuRm0tEC8Sm2bnypJewzDCeVIhdi7hCQZnpP8d2eQLFVJIWx4LrmJFNt1+75o3Fqkk" ..
	"L9uWCn4nkJ/G3v9noiGnTOn1y7PJyyG5fn7c88Bl8OQeJGGFmtjYXbeTh2670noVRA1fI/q668IM+XUkb50HmB1jrtz/pBYinMAg" ..
	"chAZbcn9Zdb8+/pWkqUXCClb54aYQkynwGDakK3rsDBLylgN6VgbZirMzpuwWYHpw+GZUT2bvhfRUQOhtFm1XX+zjpoFEJ4+5tFs" ..
	"EytEssczblvv3sYirJPNr6YRed1wuJAyFqHnkI4dyrbtbvmE4skuRIJMCnDStjO6vO+z5ZwQSmCJFP5UkW2j3XObQl3JjqmceRxL" ..
	"LVxRRIR5TpTf83LeF+dILoGJwTupzcO9VOyjwqJMSlTjKiTSrR4kzEpIMomL669R1lFSd2S+1hRXX5Bnp5KM1ZdAVVp5GvSX4S/v" ..
	"2a1cxTMmB8gXsX7G6VXaJ5loTSLMou/ajoAAdi9jzBfRJl5okrJKKmxgZtk42Tn1cXEnpH+xHHZZ+xXxGWX5tgnH47KhQmF6LOjT" ..
	"Er78bpakcGzPs9RHlx1u6O7uGNiFgOlSNiVj8EN+4PlKNV1jgViePzp7D0rH9Fh72SecyDvNjgwTrz7baAXBjl+ObX+ewZ4Hq9hl" ..
	"59jgfCEOQQKnO6CmNvRUD+l1/YD1XH9cWslB/O1QzgRRfuyEcoW3+9w50HLc0Ut2iG2mdKXe57/4ozETGVTEhQ/hHbxKQehRfcQb" ..
	"ad4a6r8EqyXQBM4E542GfOmRvGahdjPLPH3jBjpSednsnMK0hABD1Jk4LkAalyg52S2FNxF+FD5kURmV12kEOfeu/yq0AKNo64GN" ..
	"KthMhU7cVsqsWRHFtiMd0RqlWKgThab9N/9csPI/e03fpQ3Ot56vSKJLjV3p/Od+OyZnjRwQn+k7uftw5AsCEgQC4U+ZdGs5+wDO" ..
	"42PM6tbQB19+V28wxI9f3y0DqJexNLL0llhp1XQa2kO+mQreXqRnpTaS1A2HjNb50YTS05Uv6tTNtYGTNnjq1K7NR2s9yR4LaDxP" ..
	"iCTg8ei2dHHZN8VVgjYoap4BNhB6Q7kcgwBSDhIrNeIjjoI7f2x2b6lnjT54e/0JYz3Q6Y7XMpeTbrszLABAfcQ4LAjwh93vb17I" ..
	"uUl8Rh4aWOZAKmrfSIx8X4+n0GdAG9qo0e3tKPahsX0/7YwCAKGB14wNsNpDQ2YUgPw4+ALet43ZpVu1wbuWihSx0+PK7VMYHTwO" ..
	"zkIW0Qpi4wB32k9bZj6o6EgXrqtU8NzawBNR+be/YGpiiH941uJYBt3Ds7lSSRbs0WXq3cXecvGtqCVBKPGBUgMElAfU4DPkOwXc" ..
	"qD2TOKeSAVNqJWuysoiowd+HhZoriSKWvX4JIucN4nir6K9gdryXUTGT0Hk1WkJIRPcAP20HSaeYlU3Isd8ls2p/u74PWTGteUFD" ..
	"n0uyKnX3cG92sCbV9VEXhtbuEwPFkQYlVdTVKN2/bX9wHibJFOUb6sq7K708hxZcEiykmXDSLeIBuwc8OhpfghpMv5xKhp16gLWo" ..
	"wLAWNrOoOEoxDywiLtnsD+43VY8llN49BcgSZ1Hjm09W7gUhbb1KxytH8fZmlN8VJLz6p9cqnglQG4ZjDdcn1MrGyUDBmDQQhIAj" ..
	"o2GWhbIC/a9kuYLfc1UbGQHjU7UwdGafUbmcowX2jw2F3ekCmefxXgN0V6ZOa+Y8UWp98ooMkkstCFARHUuePYY0nhvrWgHkAbl7" ..
	"MyOTX2MboItOfXMMVySY8PPVFAPEBV1ugggvh0O7wFW9PXC0scbANR6D1J9dtu7yu1C3yD3AoNHGNe0Awnr5C0Wba5nZDCrp7GkC" ..
	"X6dJossyHTdDNyGmoOhfY/7GH89ef2XPziM4lK80OFI3uLneuGZlsFcwgNftWda2n79MW+iYvGtUVJRwKL9XVdItqgMG5Nek3eCf" ..
	"PIWy34EefmqakUhIYzOgR3MHvfcDzeJa5ASlz8YwOp/X6/5Qe643LWNstE2kTlPC+J8+spD1pCJpck007SqTRH16oe4BSE1bqePd" ..
	"evKqer3Kz+hnwx2HPYaFNk6HLZRUtQFsV1BZoWX9PR4PJzB93hGQg8291KWy2PtvBR+MBRRfn3oLn7U+ZYxhTmq5tqKab+IKNPRo" ..
	"xtfD/pNVU1fkT+LthvhC9J5XHbYPWgXubUD2Ot/V+UkZvCT4dS5yBVDhYkPDYIHhyriA6n7zdt5EUy7BPrGOMhi47NyJhSUD5PMd" ..
	"f9byHRnva4pwSsGQ5g4XKiYMxYnSLlK+Oh387eFFFRuRgxVj1hXMDFmk33j2K2gGpgw3nl2Mo47QCf1c9fblEM5oT0j6hCcs8wrz" ..
	"DEkBGBP2cQZWVxeOtpJSPXqFbheBuRXs6vTRpWgzPwc/TZdvopEPHiCyvmoPBHgd2R7RzY4v+LItK+K80DYifzZKw7ObaM7LjEUQ" ..
	"M92MvMOQTyHA4T7kYGo+k+UxNKpnqghzLSWAbWTcegVY5TL8/im4k806yNxwT/tiXmmzfT+s/9266olP5mGF53sghSYnqnCsg1VP" ..
	"LoehyTojsGgQoH5hD7QO07sI/v7xjiZ5TTSjnYxU+baUvqGGeJdGTcLtMQJtsdzWlSQ4TPJk1Hg7qxeCx21z/Y+b6iKJm1U/Nl2F" ..
	"+C9InZ1UkqdH8cLPb6kKQHhO4S5Ej7pNSRcBer90efXc/LqlFDtOwwCJkV/gmU/X5jLAGgD/FiYOJjKgaJVSUNeI0K57IGbSRdRr" ..
	"de2JzsNj4CefktZhjC8alOf6MskL5wewp0KDi29BaWUsvCNQV27v8gKddfnTLzOkFe2IDfrTcDfqUDHIbX/V0td1utf2OcuQZoxb" ..
	"z6bAuiXNu0D20gnzBi3XWfenSThyZclfxi2uUtVtiuoUqbQE9IEpFzTr2qnz+9nfLDBP2i9nR9xp6owlDnog6h1BV9Baqab+GntY" ..
	"IaCkAWclR2fAleCuVnKAQyt4omaQf/dtvruJ3+W8zlgA1oydu9a5chRSpNMSNrLeTwARxLgyT7k7isorlSlUWcyv7Zb8Nxe90R4E" ..
	"ZanxflvJbrx9JTt5Wgk8UeJwA2s6aGHS2soecmwhLHJY5aVvn0CPCWwK8p2fR+ZVyCRkz1XduO8HO+t489Jbk0U3rR8zQrzne343" ..
	"s/G2BsNv8ka0sP/I1c11mKhhMXeYG10B3A2PV09H3BDry/aW0GX9BO0cUHhI6xbsFyuz2CSkBb2X/oFCMk0EcRBwF/ilgDaByUVu" ..
	"upbIoCuWlkzspdE/kjhFksW9sAhIDxHDZOc1Re2b5TfsateRYFw2OJTtV8SCbJyyYBdX3MM2LuilCb/yryodG5ZvwfQbImd3PPV8" ..
	"gUQ3YYdAGl+0Fe7+gNtlS7b5xdBaF5FkZKcSuvHxf5AUWtdZSjQTYF+MQ3jEE3laJDyJAiInDnvZOiOAbLozoas3iywo+/9tf9In" ..
	"qVkxTFKKsBX59fFganjFgrb2h7ImpQbIIJtNZgh+TI3rag68WfqpgPNCoHBojLJfoKc4M8w1zEkr2KdPecwmCau2hFoWDThj6mQK" ..
	"IWbyDGGqbTww279MsnBRYtCyUzEE9w9cxsgfJsEAxKbX/wP+Muo4z7xolC4Fp8J3n6VUBzs+SnlKt+LL/TO1w90PgCyHOYfU8xDY" ..
	"o8XBvGFU5ufT8sO0R4sAjXjQfTYCbacuth2SJ6JxABqWovKccll0It7+0sWVddJ3N8pEO5h2G3RLd0zPT8MEKZr38e7ckZ2d3rvH" ..
	"iqdc8gr+8UbtgjOL+dfduFyUciOq/7yeIpAV5/lGvvdnv/linM9iC0RIgPh0bYkPFXgUMvOz9xMQKSaQdioeQrTkRTPGpqq+fyvW" ..
	"61qXPRUdAYMIYHCcwAO0jl3P1yNGsw95ymNzndY6ERvQ/apCubv9gVrKf7qmhb+fH22zubIUTX0fSJJUmlicW0omKzUGff0PrV7i" ..
	"0B8s+HPzXVc0PHQfVCE4KrDkIFeNdjf9UMJuQ5tLbKP6E10OWFKXtEVaawpHo/X4y52oJIInhcWYh30xSWgBze469TQLXk0c8Cdw" ..
	"wKiTJQ/V+q+40vZYwk+8/ovdzzpBQsKIGEwuVxv/Yi68NIpCVkqXNDasEP05Boev9XioG2pux3hRyCTrdDR7Iz2xFsS2vMEHpgJt" ..
	"MZ9OWwOgp42VNjUoY5/0/LGHGV2RsSfS2DXY8uMVGVEd7kw9YP+prqcQKQZlMDPe/oc/BR+gBks8VcIR2EpzMiyDNxSRfVSLSNEV" ..
	"8a4cFFHRl4Un32yZlbyjaZYbuWYIAgYiPFtMFFdbDvTWFRKoE9Mk+OJNP54Rx25HNH291TmprHzTspiX7+sZQi+xt5KDz/3zlHAi" ..
	""
local PAYLOAD_P6 =
	"oTvTtLi2A+Jfb/Ka1XL5xpwKQGZaydm7j+HIlSnJpJQ+J1wrnEYgPsuGZSOpB20ZRRbr4xxh4rR5MkscBZirD+eoQ9KdwlSFdt3W" ..
	"5S/l5WNYg9fY1wvYtaCVbikrRan/0MIMT9WEf+fx6mjP0qkHrsl4gPKmzAGXD4exn5OHuED5WIp17Oc8Ac3erDlbpQb8e3PPrpCk" ..
	"Yu1F5mYTcM82QJQtUK0BzOnaRpQ1Xwfe7ob+xWqa/5iFKxNcBbcToHak8uZKURGL4nf7PdDDMZ13lu/+1vmZjiqHsrrxN++yJpQJ" ..
	"OGZvGRoI4I+aKU7eVa4svn/H9F4B67FLL8kyqImCUWe2sJ0nrsGko/OmZjYUn8+QKAhZ8965vDWge3P6YmXLEEPPDMkHOB9ebPFT" ..
	"EBYSBTtM8gQr/ccchlxHVsmzeX0jdLocKGZzBfNwMD/ZxqMAbJF66rgm7O2/kB6o0SwLaDz58CQ2ikUcCUD3Xez6foruW2Ur6QRq" ..
	"Gd2G3JOAmG9QRZ3f/VzulbypMovOmfsLJ0XLiy2kHC3hS3UAvveT/C915yI8HGW7TjBbx3pryo/IZd4v1sdGc0SYhZ8dPLzplx/E" ..
	"qq60BmoUo7rrmNBNphD3Tn8XlkcDWvdC+omJEnWOgXjzm4XW9tic6kUYu6OY+XlHCfmu6NoZCZ3s53vhGdsYVG5BIsNE1OaOuYBp" ..
	"+1v5eLrB5dZEGFi7jUyGJY5OfgYUydsPArPxtWgC4rsgZtrUGxRB9Ma0oLcJ5Sk21HKcLQge9WZNUzOy4W740gDu3FgfAPI4Vrg7" ..
	"IPIaYok11h90hxJo0Na8rM81fRCM7dJfE8u1rS/0DTUuKRLEjeQ1nBrKaiWXlwTcLGiBPYhysHMvSXJiyK9IWgqHFzdEqpJjj9Z7" ..
	"jDBxPpHjbiaUGvNdaGxmeRfswMB05oywcSnc3tr+2JGF/l+4ie5s0zSY692GKLCnjRdlI0Rbn2H7CHjgrakGS1ZV1IUf9X9yhyY7" ..
	"+tYnsuOl4xsKluTW6NOtP4dyRSUm676QZc9bdTHXBDiDj7tjtgXgppO2IG7+9A5lN+WW12xXzOFBDuWv08mH9XOmSl4rPKI0DAh4" ..
	"LRksxMYinRIijKjBuqYA1E59sP1eBYX1cH5t7XcxbOrgyC1aoCCoufDjYvFtsnZzXNSZV051hihj9KeOrRbf3tJaT372RmPRzlCR" ..
	"RXqmm/O2xPqQxwKO82y5Ka/M4IfF+x68gyRfjf+57N0SKpapPPSQQvd0eY6DH1kbLPQeN94DmKT1nRkUv1K/hpIp2tl6hUg1VFil" ..
	"E1FNr+y/0j9/FvLwaqXQH0J7iF7PCypF35r/dFh8PinefUCfu/x7NcVdr9U+bvXim5i+ynoAoTAzt941sb5PLWLHgh2qxql8hHw7" ..
	"EwnHOC3LwmupeIRdhJ6Ryp+WSgGvfPU26WbFAQzqwe/tgmyoPWVa5WDJN/uXP8P3UfDydXk1gKmY5n7FS0UYAgca7OGjYyGmZG3w" ..
	"S4sXihZb9X01ky7X7xkaUuBqnV1dDGckBoEStbrcNdlXgxwIgysSHCrgtPCpzKa4HdCGQ47je0keD1FVMg+q2hSVoxaMjf/iluXt" ..
	"rHshbCEJG3Ux7vGduleGhH1JiSzNYnuvgTOoXZuUAY7P3IcHdH9SNma0wMKJ8/hwzX6J1q4AihnHXhfN7xgMZn3gEQLd+DYOMsXM" ..
	"ZNrBQ03ycI793mz7LbLA3Ke0qATaPjNnpjI+TzzWSeqEQJaeH+fGTFuTvmRJm65Jfdxc0D4Snyvh+JSzur7ZQPkN18z00jZ4oQBq" ..
	"gA54GOEOetmWgSg4Z/DjQ8nra9NCR/S6hT0K2G9ZhQUsPiIMkhF3eyhN4hPPU1EMyQ9xw4co0g0miI1zkLbQCY0MvRS7lhyWw1sL" ..
	"FqW1eODDtCZrpBREY0PTikXcvkZW6iOfDzTzG7zOLkvXovANAkXYn3tupzVoV5AMahnW5V4LlbAVFt6vE6mct00l2ImSJYKNHZ9l" ..
	"snGp+GI1TCYDdKiPYe6ZMtaGTeEb3i6CJ7MMA73Htra4ZVAKkBJjBpiOzHaQLalzz9CWaWtCvjyyl+cNjWkzFeafJe8Ot3Vy/LYO" ..
	"uibW/AvhyAN5SU93MB0Rzynj37KTp2gpI3M4m10Ji1rc4y4NEGnxeMIOfzNtFJtzO+7JpwqSlQ4d7O6n6ZwcSSH7gWcc3vseSSbq" ..
	"c8x0RKh6RRd/g0RclxpqeRc3fVAIzQ/emFS2oUfWEegDQSWaR64/J10nAM4edhhJkNYC8Wud4AhyMOpYGNjphbhsfjrO/0YhLr7w" ..
	"l2DE2MpYVLjRfbq1KcjFlQIZzigM8UYs9/F6wWuGYLbrhzNN4GziGpeEK9P67Z2FNDC4qg9G3pDUjXd9Poknbabg9VpW6GodfFcd" ..
	"bKRYNja+SqfFhxlVrPTOBcHBHznFdfWc4NAKafNFhd9X2yGzuuCZy8j0HjxdL/72jI/EJIroLZsG9qNRCLiXDEnLa8uJdcmPsMFV" ..
	"OXhafJ0yHkQ8eyxs5N7rznmXNAWC4KVuawkdcuqXYzbzNC6hWL8ZEtOCCPBnCzLHrVeb6xdgECNmNG6olz8qoK45dfFuxSKe1+fR" ..
	"NXLsKMEyISnosALezS39dZDAYDQU+XrRlxgMjiQGq991JPRUf0jlfaXWm1C8fW4pG+vw0BK7YSFKm7hZpF2GyndlyKjt9pkoneVw" ..
	"TGzidbHqI+Vj669JMTW9INM79BGma8uBgb7iFb0z6fwhDscJ1Rngo3nJ0yIss3AkyHqYJAFc6EuVS8SYxMhUaanK9WRZ+TxsrMES" ..
	"NE/W5PG9UH/UKIqz13YblPO6GmQ/bRaEB88v1cnhR2oN7Hh3Ug6mL9fCdole/Wut/Y31qkMfZBCxQMwRCL4qATPRoSsFQVRDbm1P" ..
	"Qio6k5vns5eN4xQh23MguHKpMPcGDEZ4D8qrCKrqTnvBvZ5O/zmKIF7UJEz2js0SHyUu142I37TahERWPEoZQby+eYUDl6ewSMnU" ..
	"2TSOC7nSx6pnQhoYu0C2r7Ee9nC6FxVx6/9DNK3OaGwYkShC7TvrW7cZunDamLnmpZ9v54fkJvCR5plPjkSKuiJe1l6ecg5qFRtx" ..
	"CP8cS8mLrQgeS8dnnm4DrqTTXyZn0B7Ev2nFo8f5TLYgEGQq9vC+QD6mkwOk4RiMGIuyT9M+O5gKKKrJHlxjYj0S7krnKOyXJxU5" ..
	"gX6y/KQcBvM2uj61lib8t/XM2fEigInmc0HN+eURRvU+71kMU10c5Oz025y6H66ifBVrwEdFISR5lcG61lcKJj/LvAWCoZnTepz7" ..
	"IBzsSQPa5zvaD0JWAXxzSwvQx3mlS+dCfzWhl91WjllhP7Xs/dYPFk5kWb6jRWYg2DixWWJ0Yj/+9A4IwlEMFz96iMFCfpZkcqUd" ..
	"dfMekIMoYFt+XesRN4xFCHKE8U5B6l4T0CHon0ilaKPaLo8ffD9H8xbEopuHgjbHY/mzGt6gsX7oy5t7H29cgN/zJUzteI2eNJRx" ..
	"sIO4JyzWEc3R3p1j13k5cmezwNcP6uYUIFVVw4etcfAe6jMprsH5i0G9bVuEHxFw88Kp9c1ArfXBnlkvAF7YqGXnOFytphyfW8Jr" ..
	"2cCkdlB171BVMWmL5whVUIsR3WsFV90x/0do8RuRVEVlkpsuoe5SMJVIGdnolw5EWMN1lZmdhA0ZGKgfayTwcbV/+YHZFSReVUVZ" ..
	"FfVtO1KjH6OuPzR9KVBZRdpeOiHEid/Zr6S4Pn3odGdNVB3k5686nV1aHXfMkWDpR9bLOhEbFBNZVPhwQQ7JWbjQpkywC8KlAmPc" ..
	"DADKm2h/dHyzOeGZslHzWewlBcWc3jiF4Aqe2nPOwBZRs1spyJrColx3+f3xHLlrvrfYEwKa0IhW7WP1bAXkld/zckCoSRkzXU1b" ..
	"U0AHyIXhtNuUWEjpW17Yrisr4qF3bkZg6s6hwG51ofiNMI/f3bhq1/JvYw93FNabx9wbhV09zIGKSyHbXuDygKLQ1crZVk/bsWuB" ..
	"s2UELdMBwc9+y9TGJWFhlaThEEDnHzP6D9Bgu25P72RVytEmUV8RRjjC/cSpDHFivpMqrM43gfsG6qJInGKmVEpydgz00+Dgf/Bd" ..
	"stFD0WNdNwX3P9L4PmCgkk0Wc9zJ/DIKZ8mUrKNEq2wBIeyyLQoWwjazCXkFq5PDc9/nnFBQz+souhCqMJTfoAX4sA1Cl2+q/coI" ..
	"sXFAOsV4ODi7FbjpJfdqJsJ7AuTjMGN8N7yxJWJoBSQL3um55yBn4/7BKVheRwxYHkwuqtzfVCGtZAn6xrW7lh+s7LJDmlTgAi36" ..
	"7RuYmutEHl1ifm1Za/H64lZPvSYWblVhJRdPcegmWx8NLoZm6pPIb2zy4pOs17yO6SVyjFJMA2R8YTg8zwxMkc5LNld5ENPfNsWA" ..
	"N/eKFjZn1o0f9XfumZkYuGQTUNi5KoIPsAROxS5LKwb++Kju62DMIcSM7tAAKwpS+9bpSXfMDl4QDuhpyk9vCUbpG5NvR79udBaU" ..
	"RBAP/6ytck7f9UoEJLYTYob1z9cl3DT84/Ez5HUvb1buSWOtNsCgIOzDxaNQapcWYTeVwPeZvDfJ+b20x/snWMO314SniA2V4jP3" ..
	"oR6Pd9kquYLlgX1krKauzcF6gkvHkm5wT/6PsdnGp8yP/bai/9PX+gVZcH1F7NH32UDN/P4KrSl/DAqU/h/UkGzVamZ+W3JJgRJX" ..
	"zw0NdDILa2yMdzdsj7CsO9M5rSuppKJUieavE6QTleZamXiRPkI2+wEhANKOFTqu6KwopAeozz5pjHBX+tmeFCoTVwcZJNWVea77" ..
	"L3aUX+XSwFAUkuz+2uiq/PlnHg1s0axqmwz35oMmCdqlgIq1TGKQfvtidPv9N7ibdQUd2K/UrOaoKxeXuB/dovJHCPKTvxCSLy40" ..
	"LX+I2f5/FbGqWFgv/U1p1dh1uFVoznQma3IpbO3hcY2cy2GHvlMX2y4w/jDN0lZuPheiTzJ1DR64zSOxFsE5rMQgG7rZUdcyojIR" ..
	"UOPrCtl77q5OY7el/g7dd/ufyEKrQyyZkvbLnTlkRP2AKl44HKFxKweoaLtqrspcTWS+XSoHAtwx8mxRB9swkk6SZf8Y3UZzIxrn" ..
	"IkrPN7LuBlXL9FCSP88ovw4AGQBoTQXEa5RWFz4MpBVkUtV18mh94Hv61PjcRj+rGZvo6MzvX+nEYh9I8n4ZStSXf1otv7VUbM++" ..
	"rry5GBy2l7K/UrNJ1ZqtQR/rwDSJxfsGFVRrynX8FpnYZlVeyaPB/qTJiw7KzBKbPux3NVBp3FZNHIMwyHSx6N2+pC93RnaxoDLb" ..
	"alxZtOS/n5P/RBg1yipjyNjSgKHGNoe2GHIxaNEoDmAloyLthVIpgGgGim1jUFqGI8U2xoFAhaVJtWt2lwEPR6LNapMOgoDwQ8tE" ..
	"SvZ0fDIyhk60w/8cKvC3klwu0NipIlylkxK5BzS+UNTWd3OmSO1SdzdXFQXFbkTfBAjYrTWgcVG4F7W0AWIhf0IB8wuOgfcq56DN" ..
	"rEoRe+vXQY6w4nAYJuchgQ5mAefT4kVhoxV5BQuHbYMVMoZddCRpdky2aD/TruWAv2t/F6O44rREwoBUbh6YBujUe9G4SyDYWK8i" ..
	"eegMvpG0+AzcbhcePJ/8Ogj3aHjivTNnFptvFjZCjNMKvUPENROhpEhAzQRgkvtYBHY7lEOwB7x268/k8w3BE+Uh0TWWGSqYzi+t" ..
	"Vik7dxOUkZSUF5A1CH6PfPD1ttRzLZnqonpVq7GKnOVk9hR0vvwIM9RkfbmxSS+NrLRSBzHYta78UzPVRTDqnb4qtt7B3yYugxog" ..
	"C0vnRxUFzQMrDSUOlHlNFV3N0ZOslouHUyTZR22JLbZIqzKOxTohn94M0xq2fPP3K1pKjXbninrfVMnarxXuekHp3GmrTzyDxKNp" ..
	"vJNj1KT4Yc3kBIXFNOAKV5KGXTTgXq0zhbVgZmSpNQOwJ8FtlCDGWuH+fc0k/xa5xVZPXT/rgazRTt0kZKredkFHSOzPf7HzFNlm" ..
	""
local PAYLOAD_P7 =
	"MCIXdHwTnzwKXD63WlhRBCucGze54RIZNzqTkrazBDg3SCCSheeZMoYQi3V7OwBlxyfGw/Hq5sVXXKVLZu0hDITiyiaqPNsJi2Fa" ..
	"a1GsHnmFF+FVaUb3/oeXVDKTGVJCgmCpFKkoVyOuOhDqYZVBHY9eYYIcFp5Hk+Fb9dVJOGtrypCZAv73rrE9l+o6RmqqZwhRCer3" ..
	"J1yRUO0u0kHRMRwMkPIK86j7mW9CLtb2IIXkZ7s3iQVL//ztXbdy/FtkNTbaNauc6Lcp0B5M9KkYobCuaJMloUgGSII66zcaEqoc" ..
	"ur9N3Y4CTdCf7YhOo/+v2H3HOzNJcIOBMmOABDMM9bMXt7fGO3VxRP+jSmVEpSJrcMV3oQFALHf/jc96xB+3MCCrTZLo/RopCGm+" ..
	"H8Pofy7HMQjbkzFPKa2XchHcp0PJNIaeB1+oDbvrmXPDFHgUSSLuMgX3s6bciwurWIz1efx/xEqYF8e3TakpT+7de5/z0Kr01K49" ..
	"YKHIna+1lABgtLdSjsKWnuYwOZ/zbHJMbgfsdySAih1wQxQeCsutiYb7jFBois7Mr9u8mWRfnxEgglhk0pd4P/bbmhUmi7d/kYda" ..
	"yU29b7k8k7IHVqNXmIqaOBqQEEzM4gJbX1TVQqXjLHJifUZME9HE5PaO04lPNh81kBWqxS9tr7X0KSCeu58Rsyd6ONQtD29sfNYP" ..
	"BVn508IQ5B5FhfpG8o67m/3I1IbEGcg0x4lZSIddiKxnvCIEWFcnTuNKBXbS3IZjERW7nQ1fCWrcHCgU276ba+OdGYBeslWlCuzG" ..
	"FxNfX1cdqKqjy7rbqVt8io8aZOLMmGd+eU03hJCkBYNDr0xy2JNNtC6gkp1Hk4v72fKIMpnXuec5fLnOjKzfdf42G+DVdDTMa5Es" ..
	"8/yyMsMD0syvCc/kvCogXrflIqiJWdrHCLo1FJmzqV/2wqTJTJOkvnc3QwTB0Cc9X82Zqqn6I9GvRTqGmy66vsEPPcBHkj4+P5nI" ..
	"NYN08JCHildZ4rAewdZIL76GbdtZ2r66RVP4yJ/c43ftK3H75J186vDU7VC5tIRvJtQSTdS6cm12e1vRc7MYd21bcDZQoSZ9zseg" ..
	"m3UQizvsaxxZzpbycdpFIKuZS8SNSsJotmhUb2vaiPfp+msn6illXKUai9PkuNhbKQN5EKtieR/T50MYRHQ5nczIxInGihL9vfs6" ..
	"9y/znzf3eqyqvILf6XsErF1sxVvT8k+ZzdZyU3VAx1BIXDllPnmoWqQgFkYC5jAHDlOu+9ZvmJIJ6myo2w11vjVejFxf5I6DXHLt" ..
	"MJDbgdCcyd2gzxJuwpZTZaCy6Dvz/J8zenoEnUN2jVlT36MfwpChQ2lxrNN6JIXMu+Ast1Rlsi6gDvHHLkAi+L47V9iYj8Pek1oU" ..
	"qh7sao1QJjImBXiv5aSvmxMbBD8r4bcPTQG7Qib5QUkw9STzd3wJMRDH8cSPsxGW7iVSsxstJMZMJcfUti3uy5KeHxYiN/mycNH4" ..
	"W4QSrVkC9L+MKjTJU5iB9xIIsgzEug/qZSx/zu5qrQcdXrTuURgGkLQIsSFUw1rAj7UGRfWACd8/yUqkt2pHoxwD0O3MiifYd1sV" ..
	"1smzJ8r+9qYj2IcQDAKqv0U8k2uDxzYrAaTve3R3ZQBenIks8d9kOadjPqsQFVHSj3EfXNrmCa4+FBFIt8WjcJn1v/HYPm+gHNEk" ..
	"NMPaB/kc69yDdwMe9Tp7bXyXZIw6cI49No9j6bb7OsXYPDUby9kUyEIask6g7kUyttJQLxSirg6LSOx8FS4Faa5j0Wy+LDSQoNIM" ..
	"AJaTkZsUuDKqSxFFEufFoPWs4fi81oKrtXNWZ6JWDl1eCKR1ZDdHCnraKOd85Pcvir1orsEPTOYiYkRnqD5ySY3O22/67hKHKJi3" ..
	"8lJI+GDPT5qK7hW+JsWZYhSuN+VbNn5OpusHlWosjpj0QyM7JAr6wL4dSxYoeJ/jwAT0yduUwJ9Q5ANhzME45h1pkvx9QBNJna4L" ..
	"zzboQY5Dbn/kH2FDu9R0aYuZB4R9yGPJKlRNIUskiYjNDuJF23B6XQ8zJqXmcgb9nr5cnAcrge4YSCWLetUd96Colwp5KGGfbY+1" ..
	"KmZ0uebRXlCYPOUDYWdWNugG8lTwQzqU3jOK2fUA1O1Y10y8qxot+s3lk84hP9T147m6Ni9VSk9Tjp65TtCZ0UpCPLDsigWO4yu7" ..
	"NARH0UUT6Ihw5aWULHgiT9DX7mxNcF2QYfaJyMjcUgq+8ht/N2zqrCKB0ySd/ES1M2ZW2eyUWFTrMr41t6iFu1L0Svk5iWA/fMvs" ..
	"HJVcev3KOrerF2I+ZpR+cSUjUylhgaHowo1fmLCYLgpNtS4oCgKWCn40Q2F2I/TFw8YQUBZGJNlZxsoUdxLdmW6nFY9nAn1+Fqyy" ..
	"fXwVrkKXxrZZWzqUflHIga6c28K7DMZ7asQb56jm7i46dyYJOqZ5qrD+8R9Ckw56B5b3vqnOfCKn+83afQU6plt/qjWDXSTEx+MD" ..
	"1Z/Gsjha/a5eHxZlRwXB91bqzQxdIzA0XWkZ1bOVuqoseRTC0aLWqud0vc/sftvlp2n6UghPa6Npo1HWxaCDARXBCEuEjhmH9Z+9" ..
	"s14grIk39E783IZf+jUu8aitxlkqmZu97uKIQcYQt8fpY1+tfvQ5/L13/Z3E6Lw9ueJb9cp3JsOnmyjsfUmKj8OX4mEHRU4oDiI2" ..
	"yEVFx/4at2tkMj0BmyOXMwnRTY2gNjErQ3hMsBnvK08IRP0VWYlHuiR0gaPr3QpWWZS1XNPQcI/fX+EZfdqKW/gZbKdditStFVcl" ..
	"aG4/CR8u/KJkwZwMOnA30A/XOeu+MCgm+LizsB4rCswYIMRBY98B93I403NNq3G0DtuBMmqge2ctUetqHYOY8gPPuJh7AIQA/aZO" ..
	"iuSdrqCvBTwqyGdQW6ndlM1sfI5h0FaLrKNxX2WyBd4X19XlpmCL1XHDHOgF28VG1zFErlZTofXT3t4UkjuKjyj8bZvWePN9TWbw" ..
	"SWLKLMtoMsErkeDC/hgWAZASb4g2rNpZceKqKn6Su9iIaQYCZNpTfBE85d3klNpfPTZe7MKNywKfujoxrDdcZI/E5v2gbZ88Alq3" ..
	"0Euvkq0PgzvVWcO+CxgXPwoqPJNz8Socb34stb/SG8MC/MJkVXqPjT6Ee1GeRuc33e0tDe3MMQKa6aJL6104gVvFq0WnwJOGjUbm" ..
	"Ze5NUauj0nak0Va/iHL5a0Gz85iXrRFi71AGDtz/yjAyjTbrll+kg5Fw8CsVUziMN2KJolIx+VRc+Z0KmpkMrgC0v7JicQ+BRNYE" ..
	"hvIOKpM1RnoKG8l+D5xkalh6paDB0CebvFkyLY+lpD6JHUjbFH1HWvBKJt2/sycgYugP1yYT6RWeY0Y6RcveX9Y16oMpMRbGB88b" ..
	"i0pJR1olIgunsVEOUP2NeKZczsN2NtluEu6IPG2hkDbEYGf00LIxizfHlt7N1xnth4hzgz4Uo+7bchSXwfSU/KIZPN31DpTfFWuy" ..
	"vAYVZMwCqtGUHaeJDzAZeHbN2Jl5guKVx1Oroiw6vLt/R+NbdH15M1VoAOo5CoxVMN2aGz22zni/XPUoADiZdSGDo68Lzao4ISoo" ..
	"NbN0HFVkBwdXxGQxsIxd10tmpnhPNSO73Vz2IjjaT2ydzNy+cOPOzNL7XewFN02yXPEQQZOL9xlNP6KbwQC2Gv5lwDwK91lxCwez" ..
	"0PBvPdp1lNu2XmGx9GkwtieZvAE4iaNCq654EIxdJiY3LtlWAQVKCcMPgV7+0x4Vk3F+Sj2PFcd9GvgMsT3MXGtZ6p5ZbluKGyzI" ..
	"48LI+2w+dkZGMaGyzYUzyLMqPDaZip6YVBxwANfecS9ZvqNz1iTx23RYdHhBvG8U30heCsoleessu6pYYeFI+nIsMg4UZsasULwP" ..
	"0JsvOKeiE2CbH55dT/P66nPyPsHg9udhXXLty6TVdb/6+yR3IjGLWWKsSsjZHPaZl9kqALdTvzSLDLuQLwwMu/P3g1xcSPDYuqAK" ..
	"XVMJUbXXJ12JyMb3G6g2yKbV/Q+14ymn6TXOhgI/pfpNF+KHvRK+D61TY0Qhn6K/RyY1c3KP6vwSt1aQTEE3EGnhtmV2EX2lHogD" ..
	"p5fSLScDcIdV/BMIPS17QO/W10+FsVbBLGFHrhHo/3RWdnVrn0tMPQIKDAnKQvc23pK/hx032rZyWV66iT7w8VcA866EOfdkFM0B" ..
	"A7udTSSSt8DOSw7EWYECFArWRBwS5lz1qFTCgcX9W3WXz1wFQYVatMwXDSV5ucW4eqV5k+QdMucABT7/AgjOvDy4+Lb/0WyzmhlL" ..
	"ESvGl3bPNNV8slKb+nc/BG6Kw2RNwdmnXZ6N1SqTOix2Np/Wo08tLMBi1G1u442IeXC4wRMH6vCGW5CB8LvK8itlkVzRlAfeQnke" ..
	"OoRRpxnXs/oFcFcSdE26MOm40lR8xO5fWeTnPPzvDWE6hAENDrpR6uPCLwtTZy+QsiOU3YFge+swgpTzPbLf3CLqLLOLyceqfdhV" ..
	"a5nnPZn5wnomFSKpd6AJ8oOUlPoomaWEx9GQCBtSwMuHNogHZnEs7halGMxVzRQ8KKTjtCXriYOQA0eUxtER7ziocPYX6CQV6a9/" ..
	"dz1WAwXFX5v3ClWhflw6vd16xK9vscJYEkmQwzAV6sURtgfYNPVBKl8w5mf4JNYzLVPpPxNOcgiV+faxE65186MhzKmUEhGt4qQq" ..
	"4djet9bUO4Tm3VkScx6eWUwtRHxK33FN/ZuzQySarqsu6LUYR+lo+IG8h6ssfZ0XYB5yHrMq1CKzG/RJ/Ihsq++usXWZvNPGIufN" ..
	"6LpLZyQ1ytmhTpn5DUgejfJDawrxycg6aSvV485JIBWabkXZn3lhgJl1f6URMUCKRVzeNuJ3N+h4sxDim1Ee6RE2Kjxld49Hoq8n" ..
	"7Zrxd8Rr6O86AgeLS719Y7LKTviXk9o5Xx6e9v31sdYQ5AhgoM63BmyxtUDtZ/TY0XefOWLLiilyHufaetNDzGKu1v/2M3mCiBL6" ..
	"wWisa9uo1wLYD9eULdeTBdfuQKpyZA4bula3+esShHSs/RQWsi1vOlCs3zjkkDigF2KxYjjmBA65z1ULOvpyTZftvbubVuofWMMm" ..
	"lDszkL2osO2E8/Het6QIRW8g5xAUXiWE383LKivnbyICo8VW2mds4swrBD68pgGpIS/6b+GyzyeDQ6bbiExFczi+009cdaET5zzg" ..
	"u1EMAeDhldXsqbOWFoFxJLHpJ5h+sLrda3flahO5a88BBiKwtFUMDQ00toQWJzgs1EhQL4dn8DgpluqH3TUm8s9lOcEcy2VcyJhx" ..
	"uXvkmg4wqwoyO2GX879taVsjYz4RTfT+NzNuRubF0KQulHVQroDXqgpuI9zdR6Aue46JET8Xulp+gfhe8sFOznhP8mcnTiCq9QAo" ..
	"wpxM43wTQQKImTxWY5wxwC8tIaiLvKGVqWZUDrrjw3o/I2n3P9Kv1dHi2Q/wpu0RaTOLRhIp+AYoHDGW4GfmzCQGL/cS+I+127qU" ..
	"0dcHJh/ZEHC3OGXi+ZILs6G17NDh2eFoOLeTH8Guafn/JjkgSv1lgpq3NqOhWolfrLR5bN5iVIFBsPdlLkALjK+Dbc9e+7MvTPaK" ..
	"hKjQ6rhIQv4LAwHsCOqDqesHvzbIVopEISK1xgwKx0yMrZVFDJl5JQDgmK14h4HzQQqTkJgHiJwPzOveqRueRZ6FWJbQy3dc4Qwr" ..
	"6U9/5RaqEMDmta9i6fpLMI6vm62/TzWVb1X2prw48whTMjC7gd3LbhOqGbXnkkmpootjlwgv5VUSoazkmLNGlIAs0vCReDqI21WP" ..
	"ExMVc3TC28ywdAn8dABia2+a1yICMFp7OdwfChP2uZLgabVoeoRZAmXpHaeWCCND+9CIiSYOcxSOG1yaxDB1Y6Kx63G3eIl8I6NP" ..
	"VNxAQ0qAiC638Onc/s+1cd91ysblFzNmw9Kn/Gr85qNwHteX9UIDyc8a7XhUBa8c/i8UdBpNS0VHoIVGq3Ebt93dQcSDVGtFMNe3" ..
	""
local PAYLOAD_P8 =
	"48mJ5iXQK4+NsJRaAMzMZAt51YTiA3kFf1IX1AwYIMpNSjKCi+8KiLTKZJyIc0zeO6E4fDSRBvn1lg053jEe27HuH4sfsfk/VCVm" ..
	"jCoTk5XEXi7Cj1MEu7kMch8ZiOQifl/2N86hwzct+amib6h+QRNswoCHWZC9+cK0Ua41tfy00w7ajOnSi4mB+3WhjptUdv+C1bml" ..
	"YWXIH0aDN0YQlInY+D+JzBXBS1P1OaHZHGXNZDB7BajvKj8+gprwF5B8XBZItpzUfVV6XcTNsLZDJ1ACYIysPRNeqA70gJzmkBFb" ..
	"tfxBvVKCtnod/VQ03aN/UHUF/jEjf9/7nZ8p8auVxqJ/rSi1XrApXl11h/CNrxzNrysVd8AKBGzQfbmVwh21qEKQqHW0vidj1EPJ" ..
	"fhKfpXnrmdci6YVOtbhKHdZyMzPP/Sy1Be+AxuS7RvMbgvBKyY8YNTw48gCEC+7LnFBwSaRT/uOpOHNgjp96ytsb4broXOwtz/Zt" ..
	"vwWf2LkwzMeMk4m21YB2N6iqeA4tDRTjgXHXx1S89l5g3UhGmHhkKXDXcIsyXcH/UhkIPq4ntB/ZEPoQ9jr6Ngch+XXdS08xGA+T" ..
	"8QguNrYV5zeQhYfHeniDzfV64dKsj1W0RQQ0BbxxyMbQxcqzWcq6jwI+chYL1+iMgsuo+Fu7MUb70PCWcfUZUjKJs95hEcRgCgNI" ..
	"WT2xkczhlSqd+3lJGy0Nyj0PvoZcZcqFrxBmJ6RaWgT2OswSNIVXvg8+iGVY0U1M82jr4sllqWwCT3LjAUWZAwD1u5jlYw3Odu/J" ..
	"LByjPd+ukiu4oJD4Ci4EHnk8XWaUbPiSfxSH0+tKFVyuoSYvRzKaBAbP8OQT7qRneXA4gi5kokt7FXxE140llMVw0wh7TLCZYsyc" ..
	"yvGwZJntdOGy4xr+mIihQB++rosT/Qy0lyeXgtvqH3bE1qTXoPY/w2xTnG4Sml4clBCC/3MfzIfKRwRBBWs1krHC/eYxqUKyD46d" ..
	"NxrzEOKfC7r7zEl350X1tyJPYzykGBCW9202uNCz8OEilG3giqRwDjBsQc0JsBOuB4YlG2F80l7r6Tn7Vd2qGQvmoz3msGeX+f+V" ..
	"3AtZ6djZMmyZA68rF/7K+0fFt2vk5N515DiVhtRkWm/FG7GE/lBU+5UAaZGUcFzkJUHI8Qt6FEpm4IZvKvcNh2tvfYYgKgKuTUJA" ..
	"9MBXqPjd7MfMfUOfhbo2bmT1j4d3oVBE0N1jYqdf+VcChpBlr6/jK3ZI3tnjcbo5GoVtOIXUm7C56AnTpf+k8UjVbG0C8tmEZ1Ti" ..
	"wweeHd9cDXAKoziW4fudyz1jsWMapJzfnZ3oCFzLo/LULdzvDIFBWZfa9yG0xgWQ4bly+2uwYI8YR4ba2/K7aUcpviiZm6oyx9X5" ..
	"Zl1jt1zkA1H/qD3QEwDNpaHL+NpmxOYM1bHekxMzUSWjH7P2AV5xxLFC1Lb0vBxdlsgH2PoYr6cnYKS9Ydl2XjRjzCP3QaFgli2D" ..
	"6ECnNalFatTJXL63RG+snunjuqcv92Eu8mOCO/rAgu3/rK5QeeUVfC+rYWsdzNkfB0rVzOSdZHusNaUV5O5S5Juze9LgfDv6Px2A" ..
	"LOkfTqEroZ/mn/XwCNhctcZHIYDG7fSZbu/MkzcgV1tSvTKwRd9wdjbntGJBnQFPFAEDFMX3UH9J5ir04KGBkOM0RT0j7iTnX/6b" ..
	"piV3hBld4hwb3w7IRbYjUzVHZd2lxzgH6doDZvD+9wBkpkTqhJrS7c6+LEV6nqDNUVn8sRdzF8SlzGdqjRqzB3G8uKz3KfyYurTd" ..
	"jaoyYutjkY3WAjDyrPnGGhg94EMGJdOzLwosTBUnc/BtB3BJ2nH44lAu6B2KnYf15BoiqmoP2HPCVSfanML2lCM+/50vCYjm2Xbg" ..
	"Kv0OBXcHTZ1UC8UBplRVtuD8lBKylANpqTAybplPDZTUWzM/KXz0wgQW+pzB+BJSJxS2zZgimMybUynEXSfNs4Rz0kGqbDPvwKEC" ..
	"yRsxhdmsrE7cu2alwZ8bBXsj8Y+S4gnGeuODMUlBPmH3P32K/qPAAUBSNKXgvFN5dZlMzZsJ6EF4BxSgSNbf5pnvnbFDknymPNiS" ..
	"7Ne3uSGZHB775jfvxH1r0RHvZ0ubibK2Qd0jezSgd6gayFNzWhpd4DRqynufjOobLKoxrMi5Qn/UttTVPGHXOqI8Q7NlG6CD1B4X" ..
	"HQ2fBdz7vjbvL/sJj8BMO2E0mrGiFOkg+ZbviKothD1j2LbXOtyYiAZVnvIRU47/wK8aOax5UCCtQ6Zn54vPl4kV3AonMrf//mLp" ..
	"wdGyrVYeQhyB0JkJxSKdxB4Bw6M4EM6xUDOO57AGeIBEAYpdvJbVS8PMo5mPBNDp2+m4slABnySTzrIM0F7QItpcuDbgeVkB1cig" ..
	"msUxCQJ85EBCOdbzdS5xTTGw0FA1NtNXnlA5Vevw5JNEc59kSYZTzFbJBChZyCxBv1xqaOX0Rcv0ZE+ikDttmIJgrcVQP9nMnKvM" ..
	"JVsp6MMbYkv81HwSAfVoRueKItH2ifUgT8gM0XNvL7/i+JkOIDUcWNYsqaXDe6dfbAmV97N09OZqPLC9Ng+RYLp4x/n9u/LdTqpB" ..
	"ullMLeQBCnoHdclAOI7bOgZHGlnH06C8SgdFgzadv4IqOi1bH1wDcrZ5my3FiY6h/VHb46i1b6ZZTdzP/nagRlevNYdA7M5rQIhw" ..
	"ab0JDOG3zRrEFwPXmZbGnHCFLThcmOu507beoU5US/+0Wn4CvHe1i2mvDgJntQOYM9F7bz5CnWX8ANXcouzD0PqAVRY774eydx1m" ..
	"y4E4xha6AbSL+n9CE7mpjcWDpAmYTDkDBDdGp/4RMSL8ZHT0aInloce7+B3mTNvGrZ+32Z7UNczqiL6X70TjcRoD/rCaO1xycfho" ..
	"QWP9AOYbfLOoyhyLNXSxyMAZk2k3/D/RZha+0+fNPUGfTEScxuvCI7cdpKpgOvK6lEgTi3KlxqVbAahQ/vIt7kVJuw13++CBt/1I" ..
	"h17udl2/JsaGcO9ko6ztWxwphIrk24Kd9g5TKeq1GNIrlVqxTQlOi8B4tUc0KMR9jqDg8MGiSi4xl+kAw3aBFgJ2DKrA9nYIEgEu" ..
	"WWXJLVh/tlfJIA+y7kRm2SJ4aOwlEnoQZqywZJEt0gfNKjaDfnO5ogg1ejFPQqwbwRhD6ysyblHiwRA47iAB5FjyXm+1QefHsUU5" ..
	"83ofZaiBoaNr+Cn0c0WinQ75Imw1tk4O68INpxQQHVzP1R/YgFKWMXxfgojNdDyXNfz1KDQY6fAwapRPdcyfQcjrEiWgLPERo3vL" ..
	"AMQ5ASRQNPlPA8BNt5O1YH6mfDMoP7BxA/u3ybxKTAonl1Ypr42loomij4mzZOqkAAEaiT04gn172Mvjwk4QvI0oMpqTyg9lKqmK" ..
	"giaYWtd+6U9FSrbRX/zRptUPl0jGvLalLG+EXUEXP02m96Gd9uZWjv3OnP/8sP0iOAsC7N0Lb1KNzRkub1HXOw7xfPDKa1rSltep" ..
	"fHcgKD/xTTligbeB8XTUPhvliVZsc0w1o0wXDcWqcaO5D/8+2xtGsjDusuz0PC5r6ZTJ061qnov2MGewUGTRNW+jzynaALNXw02/" ..
	"bPINknJOYLMFNGm3o82u013ZMDjsqtUlKxw9wmZywlj1D9TBOBW5vEo+rE6isPht3pJgJXqdHcr+snDGYpdfR3NoE8brnwX0YycK" ..
	"gEMXeYjrqNKs8r0Ptioi4DGIK8iJ32QAPjGugs5jqVZN1WmL4qezcSAKctSYfftB3pFwhpix4LtJTc0Ki4opU16N+5DKy5RT6sj4" ..
	"g1J0gM1aB/ayq28+aexorQjR+4IBMJTxjKXvTcTX3L61Byg6NXWkS4Nkxjojve+oM18e+RgvwQqHHtqNGTkhwdBkvw+TNmfr39yb" ..
	"gz7B3YQUjFO3jTvix3QaGzVwj+MlRbb+21JKfV+tvi/8+zacILUPSmArREJu9pVwjBcXmJR8bTpjYl0VMk9MV7/QSA1pcFmRCWBl" ..
	"mL5iA+4SLNRcZUUJz5Xq7P+F//4gR4GpeB+VqghahvzpoCyldNs1OhKPpl53rcPXECegE4/xTkkr9a5LXHMb0Nmeg1nX/dF8iEzG" ..
	"0uYue1zToL99rTx71gQmglY9qcEYypAlDLx9uLcUuN3OljFhOGFKDfai+Y3LwrHe8X85dQliWjs88IlRZ+bHSTxeOHIYQDUoWK3F" ..
	"ADFGCIf90YbS3EZJkSJIq/PqsqXcudcIvOECYk84vsefbjZMZDz/5G0coGfDCuJs0j7SJ5Cy48LYGiykEfCQCKdf5y9znmUlXWff" ..
	"GTE686nSuNxDBWWfMAdDZU5jpep5R3ylHH3vk/+ip7Y7Df9L9aQQmKooKZAvAqwrqfoTHB+XUbutwXbYKXKQ4RfEuhg8XirP1yvq" ..
	"4rbkZUMNdARpOuMgs6DZ/lncOe1SAtQa7PVzQsLqIV8jgyfcbtU9oXTRfOPwVZUerEBTb4kGh1pQX5urFszMU+9GBcqMlqslyPVD" ..
	"Y3ljxYEuGScnbbT7WIR02dXF7NLrOtn0/l/8Hy62ZUjfia2JbbjK5PpJ0nf2SeCfV34duYqJ4xVJc6/WsWVE088TD/JAGOt3PzKL" ..
	"zDdiZGrmpGyAWMLvdbCpJ6+40OQ3prRckUUoWNFQqsCsbtPn4r7/mnHhQ+uvD9rzV7FlxSbDwHsIcQmvkS1n2kgHgrjNFg0UFTsY" ..
	"N2sdZb+szIniVZwFFDrbCoRmaXskEy7aIvhrRxpbHyzUH50DSVwnUxRlbNRCdiOQrfv+3RpaDEW0ZUGUjScW2JfWqwidBYqzZSNa" ..
	"CTT7wzeObwDlEtwO+czwY9wOi92BE/UdzfEl/Cyb+wf+vizmmzImvJBVqFVItkyWU7Eeb0DCCSnjy8S8oqwEj4XilF+CF9pjlDmC" ..
	"vpq2BWuzuCL6piHLDDvza/vjdGfnlv9g2SXHbILQZLZWwNKUFq0RknHZt11XFs1A9BucrEdbHN3xqnrpEjCAHvNOgIg26SOSt04p" ..
	"Ss6cTEQiaF916M/D7IMNFxe9CzqyiBDTbIuMI8Uf/gYbw4+5QULQb9q76134wNhqyMyyUHw9LTG85ooZLZAcSmyNDHQhXKdDU8q6" ..
	"9BJaaTpqWBoAZwim0fmrZyPsAlx7ZI8HFyoDg9yzcRD/2YSHHcJzJg75kfrmwdLGoPiNDZQdFYtmW0vpZ+kypd+Fkg5ig/5qY+fP" ..
	"Mn8PL5frUzUMj1evpZ61Le0ffsLxdI/FjSjZL/KezUwRLfgjchRqmmHhKs92x0/kTLMhrjl9q+3RuMTxh6iHji6j9EavM+NkoKpH" ..
	"eoAXPgoD78ULMJ6nfzDjNPPioNQkszmFH+wStvrfL6ZDv18nSOe+MLOKX00Foy3+j5vy9Mjn9AZdeCcAGw1ekQRInAeyQzI1lNT/" ..
	"soes+UrDaz8YI6+2lKUwcpYtZiHmwxrpMtiQr1PeZv/fpHWc6UmlPIp0Ffdk97R7CZM6kRMVMDVBGZj5cTJVXPh+BS62Gsydiwxd" ..
	"VckbPxbQq+rGK+/YPOawe2xKqNfcVWkbOOsMmUPaEoDnHnQIqiIjIJP6HlD66uO3zOIIYDp2XPWQWrtCn3ZpHN9vP+EyPoG4EAih" ..
	"GduC+hgUJs33NXalt2KUBSJ4hK86h+/zzqDDNkGMP7BMKfeowCIoKNa5v/t9ZygrYTAcmTJz91IdSbSLjvMB3GKPiNwnEBABK4Rv" ..
	"nY3CBnbLUasW6rSSZcGRagaIVzbzMDhtA2KOwcKiVrKNajmZF5+ewRDY+XDQlsW+6bw3Hy4HE4BlRQ9bASQXBgBG1tjY91ieiPlI" ..
	"6ughYDH4dRr/ccBUGgWM0npYEdletTgxPxq2YdPYmgbw87/Rwxavuue5zYRfAaO7ylVBe2ao5siwFyaEmJaOu1XutBx34iSC9nwU" ..
	"o26B7+SWTItwyqmOnhnR3RhdKz4n0GE49zxBYOtpZCrKOZ7qJCQJMWAT99K80ZZbe87FOgmkqgHaW1E03ysmKtxN8LoaCKTlfZa9" ..
	""
local PAYLOAD_P9 =
	"WDLqqaTY/xAOuz/idVGLf2gtJv6sgG/Rkw1JY9wV3Jk3xHQhiL7+zb3ZjNBDphGzqvFmdnpPzem0fp3eEufZSAwsFqB3GkOd60Uh" ..
	"7kNt0K1AUipnq8ZAIzQcT/atleDzTjhrsKT8Knnbl4Uwy3oGQuUtFkA6E8wKNlcfawEAfyi76twC9A3YQV2kWJuQGpR8oQdWC+qf" ..
	"ZMWtRvB8IKaHmHgQD3Arb74QGAeoAh9otCnjKy25KjZ6MUPnRY+wWed8oqd+CtCUrjBGvr4aTQM4MSkjb6u7IIKEmGIz/OOy//Lj" ..
	"u0+bND+DYvivZS8QAmMjnbFC7GNF6m/fJVsExwzTc4wW41YpdFd4qYjUGtQhcQv1sL0ul9HVFVEhSOwHmgVHbu0+ze4uAAH9BCxC" ..
	"1H3YdUXzT1Wn2bqqv+a0loGx2j7j1c3wKooGr7z6ODbPzq1ZpZ4goILnayMPU92IhbBr/ZIfGgPe6l4LQHQ/EV/IyOEv0qSV7xJh" ..
	"ayZuWnIdmhVO8yW+lR15GbqcsA0eoQommTQ/H0StIpD4hFBm3jE17iQmMO2YiVFya38u/m/4DgF1qwBXQsqS0JpN8XCn3c0eS3iB" ..
	"QHFfekw7WHQXa5AHtPpU93HFAxYa3lSUpN8DzG75Dsu+2vCqAcyqvMOuXcStdcQSeEUJqSmZc5uFf4DPQgnDlksuBSki35fb9WDP" ..
	"dVdhxPXXipa9/ID+44LgUoI0a7PhTuV12iVyA+jWPHf9fHYiSf4KeNVGdsmop4eF7GXIckeU1TomxIDou5bQV6PwqHCtYE4aS842" ..
	"uf0oTBjRL8vQRLOHxbFf0D4hlDjZ5X3s/5x1hbEkfuTSg/EW028+k/8lYCmszo+mpfTegTm3nwmWNhUR+j6kEKtGiCDDUAqGup3e" ..
	"FIrcDMeEZvwPRtLClPF6Ztc0PkdZl+V6oCTwMqENSWj8LP1CAqhFcbe8fX5gnvJVUVKoJsukiFmOfmbpvxtdPT1mkyG8sTgCqJq1" ..
	"VtG5QhV25evQjCvvouXFJCYqgSagiY3URf6SkBA3xlVpDePuCtBoi4Zui5gT7b5aVbGYw4HoLrT3YHlL/px/PRN2VvDC4RqWK9ym" ..
	"xIGHObKo8XDMQwuZjoKXMZcQol/6HG1AslKQaO8PLgf+AdM1RUHzuF0nvo9hdviXUEfcRJDwMQTZ/cLpNM+C7N4uXFalXxMn4NIw" ..
	"r4AM/YUmNvXwofDDhGnJOFerBvxqbZh9VXEi92JOV4VQOcuSH3AyyNlFE+yWvhpKMDjkbxRw1PNN/M/Gt1FxDZPa7YTJ85fduJ/T" ..
	"hFiIbJLPSZ7TM1C3IIiGZz4QPYNJWRlPswBULjDklFGQbiCIK577i6CRISWkcXyWxh8t0cJidqYqlDIZ9BZI0jub5Jjr/2BOSUj6" ..
	"D+GKp/1ZazPJVM2LDEeVlozKdqmbbww1Vv9mPOM9/vvCcpzxF6/zl+/jtlLNJ8+MsoqTbFPn6NUNWPUvBm+nqyOW1QKB40+j3tj6" ..
	"EcKwj25X84mMTQyAt4pIN+DOQXS7HMCiDsJFZFtWotS6pFFmc67Ir/spZJD3evWBojvuQsgiGpFw31m74/xErjxdlUH+Isv+6189" ..
	"Vv8Pkkf9qMKuENerjcr34f+JwpLYZVIloFzwLv9+J7jdPxlq24JMAqajWunP4NpvZnW79Zqf33bPLiHqn0yIZcvtecWY+cRuvAHB" ..
	"/o9cf486gNmmiTuyw6omXEI+pKVB0KK2OOz8bVqOR5guahg/JX59Hi38DYIACvFT+4XUUNUgIWk6ZjHUehGaBZ+IFxnUpQZb/GHF" ..
	"8so9cDuDQlBc/a7GLtV3ZAJY+x8IpDlApdvZSg+UPiQTQi5uQ9m6W0HcXC18tr6ACjYpGB1dawIH2zgoFsWJV4EomDWMXP+6IwOM" ..
	"DtYivc47DExYoBiDwjZyEx7ArmNp6tPAg5ecmArgqQcEJ/juSa3SC7I/+ErbcSwDauVa7O/YbeCaiWi+ao1OnOMh5Mw5ZAgVWQvm" ..
	"HW6HuA5/UxTbDgN2RMELAlME4EZm9kpVVTOHg0c8bygQY5r65PWsStab+LVHrBNuIz1dp+trOWy41za+hvHpj0jIuk06TbiO3kWW" ..
	"3+gsWfql1r07TXAjFygkH2nZUK/1LVKVjVCF3f7JFK6TFU0vfXFBrg4Wb7a5sB2hhvld+FVgBcn44jbHLjmxrw5/m0nwvVpeK4Su" ..
	"qj5yz6Ogfijb2dshqJ4nCYyBMeBJLR+Lx3W7K5pq1p4y6LsjNpsTpa4UlPDlppEgaE0o6acP+UVXkAeuks6XoYE/ZubcsGcR8xMU" ..
	"M1UtwZiXkaha4YMjeusl4I1+uFhr7emTCQ+fYJo9Lgvd4m9ntWO0hz5f1/2WjXGnTtgY+N+4PAaD2E0JHdjFWMKSwZupt8Hq6FcB" ..
	"xwMxCy+epC2bGr2eMxzNJrfTd2mBqltASJarQsgJKjd/VwH0khjnyzFeYS458F/yZ+4c4/D/g7+SsDfKciICam4qd8dxdhaazApY" ..
	"+H5+9Bf4nk0gDKNktKnpW8Ew/NAVyLdG80D/j2Suwx4YBkMIhQgtwYBn3pykiAe/LFDVAzTDQtydTgtwA9OjpvXsVorl28NRkQ6e" ..
	"wg28ep9nzhjJhMNvWceANqE0I12DhhdTg8hEu/UD/jApXJxsPCYMysrKgmWH4GAzCqiChantzHikwlHzra2hN33U3jIg0WBdv5E7" ..
	"JZ0w5k8B0t+7ZsCTzeVC+wqiycFiCLuM8XsaCwCLcYONi80YTH2bOmBgvDq7lc7GI956ls4D2M6kw5hzmv04icbR+CXzW3QCExFt" ..
	"0ixv9KkC2g9yYpiST6zl5wZOqd/94UbRF/MA4rlZqv85QaGFORir/IETul2pnMTq2s2Q8goHxu5N2EzVZz6EFQjFl3T6mQJAyKAg" ..
	"lIOUKbIz1fHQR7MGdRhYTeJNoSg3HNYFoqXTAfEyoaDzTh6tNBNkx+KB6HCG8QR4SErABNoI5JnyraUH5f63unWJM2HmAmy7rTHN" ..
	"7IEKctZZYZQhld0rU9GW1dlHmR8ODJEwq2rhcwi9Q7X5kWNWZyirBV9k0WxBseWHLax4A/sZ6yyOY5bTB5e73uipLDwCR9zAwucK" ..
	"mGuMDcDzTTZI4SMPpSXLWlW+rZr4msQ/KnvkdaJ4AbaokAEPD5OxU//nmYYoFBUi27DfmIwuWhN/ThSt2Isx+rWtqvLbJm0fyEAV" ..
	"ojB8X732wH7tdNMB67g+X7MHpphGczu6ZbprklWjPDZEIGbH61zh6H3wIgp/vPjGZnynuVz+I1Qvb625oVHOlX+vOk1wMfTsnL1g" ..
	"z0a8skQbxf08uaGKJ6C8lIf0wiA6WH6FWzyjlq9R1dYo3lrHAkfbCtSOb/TXO4OSrMtLgrteap2aBmcmBhI2QNl+23gVXz1cWYMJ" ..
	"N1u7ggJo1tm9Gc1hDah19cyhpZeuI04mwX1gAEeVtwH5heViiZo/SLLooKvgCmrFAjnz6ip1O02Cn8CYnNd6tM8Od6IqSQxfAwlW" ..
	"IM4be/G6um+QiqnR95Ku62/KZ7MM2iPVVRJxmBgOEM/Y7pm6iShzqjcIUIZHpxVfXzzFfsU+aUCcuEYHK5pnPHncY2bWE/gzD8HL" ..
	"EdF5uHiFfegML1y8kzJuzfXrNgLwFConc/kqzcUuR72kTwH0F7i9kESBKspjuWAMcIbZwkLRo1t69kAGAuWRG1pmSHpWTTPZAbwU" ..
	"daYLO3OKyZ5DuOL4GpLhKVElBEDpmFQk2xKcJxCNFN8dZ8BSiqV1rgrP0QIBhnYU+/RqALhtJEQaBoSasAeFzzN/lSo4oVWTVskU" ..
	"3sggpKPJ3QrvFXsf/0FmcfKgZy3AiiZB/XXc1rI2jFpg25egpo6Tn12ZqRlLX1jjn4oaNCQemNCfvtTUtiMkpX3GUA9qFIAZ0SAi" ..
	"DzRNk9ErBjzt15u7fVWcVzcyKDV1cmBtoioCgwOMFxOGLQfZlqZ/yIBupGCvt7h7Mbkl0gOj8WpZp42/MShs9jTD/VfDhHvHE2vN" ..
	"blY9MT6qvAn7FrVAzSq0+tSCUqOV6Ap4x02MrfJKuwaaaQ+pQUFPdgpmmHgl0/E3tkF4BILkRjFS9p/3poWRWStki/AlIZiaP7P+" ..
	"AJOqH6/meQLcOkxWhfFUO7ccTqOcVrxs1NT5eJ55S885oVllD4LYqb/sc9ZReAczGyS2Ud4VDpkzlxsjkP9Ozzp4HWro4mrq8/tH" ..
	"e89n/lJ+SxJvWD6xL+4NVheBj/tTTGkMFe9SBkuS4n2qnJnVd7HQV/a3X3XTEeIXcDl1staEmdLD+Ad5nIDy1+YOd+NRbI+e+E2B" ..
	"oNIMMFZkp60K1N1FIXmkGubZLfFNqi6gYWwGpbHJBtSsZM8EARhoZH8Z1pssymP86rBQM/V/N+L91FvZNLEV4FVSNhGmpk61+u+J" ..
	"Ys34bT/HmYi+AD2RvCe4F4jp0lB5KQMsbGTbe7RCespNNpax5ROlMbiV/oBN9safiaU6mWthmzkAY1zLp+UplwnzX2cVw7tWot26" ..
	"TzGZRyBxT9yRsLoaOxVIhucACjXlvo9IQoAzEJPiOlJLlTdGVOggJpxw9sJ8TSIWufkgsHCIpaZqvU93KUCm6B/b0vBDtrswe3Bm" ..
	"r1TSS1XFxdFV0aLcI1RDaR3phbFgnmxfQuuAICj6BBjt38BXmMNCOzpIIFINYgUs4AqXXwwACJm+S0Pfotyekj7txPwFrf5KNdnW" ..
	"X1JujA+PL5fMODOASUZgsX0TCBBMiGkFYUvoM6/V6P0W3L4B7emGYwW1NT1A3a6mZ3Rhdye7y3+PV94YJFY7S8lQmXXBr4i/8TSB" ..
	"Mp9pgHwAXmoeanw+WPU6+lFvo+npngpwHq9JP5sbB7WBJsFvvY9qe0abAcFOZ5X5w+USHWGcDSR+pLGDJuIZqXjI7aOexoyiTf2/" ..
	"emw9PoMpRvupQW1i3djpTwUBlp4LrB3X8ZiWxruah2FwPUbDRA62Pj8igYSfmeyb6h7dDkxIjEbKLO/64eZiAiWppd3S+DDKXPN/" ..
	"IkI8HI+o5kcj+cJ7kmVWBjw62al18Hg/b4fRJY/2jt+HKB9IKVutUxgZlpxRoztS8V3bdKoKYp+C1F2/m6keizhJA01R03FK2gQG" ..
	"KTYKyQYd8TcxSSMEO/dAcWJt4MDlaj8aP+LOXk/glmQx6QPcSBSYhmmdhKQtorqtRyi3+upSlOkfvFshjG6MlIsAo6L8Xki+l/b7" ..
	"+Z4Xd+G+6kU0pRLOhBIl0XiyCer+yTo2+EffyKVoWcNq17BnJC11lwxlnAo5FfHg3k0Z5kRhEIFHouA+ftgBaYtVQaxytQVdtxLF" ..
	"LJkBlWJBorM2y/vTsyPcXO07QsRVfc9gT0QJSVO1M3l7E3AbrAQylea8nZVleh/qCgFtNcVD+eLWG5U4lBzp4noH12oPBfL7M8H/" ..
	"w0ocIV4JG88vqvhMPIpZcfNYgN+xwK0s+5B6CD0Sd28pbvE+ds9Zu1fArXZuHC3CjF8r76s9kJ1YVTJn7BYGQEHoRjUu3ahf8TMo" ..
	"cLkyUid3iYYBJy85vY9qeW25c8NulT3C7s6veCVV0btbBATCPdK1CGNU7LfLTaktgIU8GlG/ARUJIYoyT84WFI13YjovY3eHBToB" ..
	"tUZ4AbWTrW5pkSaRXvzKKjHGizgifqJdVPhC8kn7TTmFXjsPYc/qpARkwhGLisoSv9a569yUlV9B33nK2DdDlkkGdguSDVBzO4DP" ..
	"vuYVWWTFjY58fNeXH19/Pszqiq80WJ7O6KXeYXQZG5lqVNsylexT/QGAbNXR5IH1Py3zhakM5Ulq7+HIihw75f90yL8qQxEQgSaA" ..
	"1Nju4LxitUf+ser7rUSQ8F5jLOm66jigp5lpvoS+fZxZIv2v88XUnrnCFhff0h6GDb/32cBMlIJWtF07R8ldJ59Y9EDtfARnAeOU" ..
	"9gzNoZkI5bkkM/jQPARCCVbWWaFokdObmizd2K64sYnig/pW2D/vx0cJlJ2mSCb7eyR3ASpJ9HHJD6Qij6ziwjiDS3TESR4Y2zM0" ..
	""
local PAYLOAD_P10 =
	"w91BgEK976ljiOwANv3robbB6xmk0dAFU+oyuoAEQL2GtrW3fPJZdi6/YCMIMvCbg2VWpYlmm9wD3ZP98sGY+eHO/+hOhoanqflg" ..
	"Fl9CBB4jFtVdPNohIRpGCQGoT770TsnzK1jsJaV5T8rVtc9CL86gdbGcDEVU5/eU2hMd+JiBaUpf/4t1uzohBVEvLcoZTT1WojM6" ..
	"Riz7dcDSa7wUd7pMzoSoz+NoG14Q1g8LwBB82++WPX704sWk/9rY+1W/UuQWfIr5HnSi5oPzOyA+Khx8HqzPlrCuwpld+g4QHtkU" ..
	"bI9ETEQwopp+IkPBnziDQdHIyn8iNbA2yVNEFEr4fS8Ugi+z4SWlcTG7oo1gdVe24z9V+0+qlJQ1dlFGZm9wKKKaHOV1Sgu+Danz" ..
	"Od0ibow1tj/Q6JI5ybrCxpyANfL02LvfGRN92YYsYhEOBVvPstjeIoGVpZWz04kl427DX1pPNApnJLg3y4brQlaO+AZuHekp90aQ" ..
	"iHr4zjV+ruDkxk5glxlhTpEHBqenHvqdQr1ObNAfo8Ll0pOuD5uTj4umvuKXOQkScZ82VphSmXaf/rAI/4+BelZ5Fs3vEURNM151" ..
	"iAv4DaRNzaQwPsCLcjVG669Bal18IObPZIBJxOZACuVUY88uGZOzCNqmMLtWVVM6nkwXCyc7aC9EiDkyQ8TX6pkpG3fWV5Vae2Su" ..
	"ygMpEInoj674rveOyRMvFMTgPTvRkcgS3k7e4NEgmQW1j4HNmE39l+sT1yIlmrooCKJSwW4Th//BCJoBTkXFsunEtq7lupwf6Sq7" ..
	"ItZJNt+/z2/g4pJXjspUdE+WklNJ+WVNhkhkFwVGNhmbbc+3HxHlUs25I+WsTL0UBO2sVo7dPtpBuLZ8ErGu9NOZqXLSRPrqBAu4" ..
	"GnlD3o5ZLHQNXqrDSf5MZMsgPVwHv1Sl49jj2bT1lsvFqxAjvY9xXHTRgn1V2j3p4TkGqHI0Rm4IGO9pV6Is8XqKQ60ozyGCF0qH" ..
	"kisYNEThJXIj95DkGlgC4r5XYV06AJHwabe8dHasOaL7IhDTNjV1eIbSmnBfrd9P5P0WGtBazFnELM/7i+6ImL8d8XxmzlDAGO4K" ..
	"WiMo+/YRKYIV4UhSZDdgnmW1QxnNAGwH/MFOjfb+kXYerjnc073v2I+hKUJfcaWdW+Z9XFBNBYhpRt9rjV78Ge/q9iglZC7ABhZb" ..
	"/SPUEriWq4Jlgmu2gZxo2Cror6XOxc2JaZJSj5I/Ji9rY80mV+Vo4hISW3x62Y4eZnNkIYqWMBU2vfBBUvB3DRNn7VguRZK4FBg3" ..
	"uqEppBvsdIyTMfpmhb/8LvNh1vUmjdF7uAcLlBilEYaoJ6pp26NTiuJkjoSQ5pFFb6zfRrM5YLsc5j0fs0lzJ501TYR5fXVofqGd" ..
	"frGcFBpFOrtg2JToyypM6kfP76SImaEqaAx7wfT7kYTs14L4l2CosMyP3CyatE3S2NZgRHV0FJA4lKGmlvo02Zmggrmb0uegPZPf" ..
	"t7KmE8AzXiQUC71ewzc1L0vGDIqTppF24ffRl211qS6nGyp/oRGvFJIMdmNyqAf2er6PjXEKm5UMk54N2iGK52sAykvNquS03Te4" ..
	"dg6fEyz2KbK5cHdhouKWwkUxtaqvwOGLtDcv3m+IKEA3iv7BlIXZKCwIUWIFDK5zHiBWIHnp5G+CBBNIs0a9AZXMixR9Fs5s3MOv" ..
	"v31M9j9O2APjDCdabKXuj35NT+xYNa679URFKJXseoio5X1c5vBsKhOKvEs82JYroM2UuZ3xyjrdU07WkPYkykopdM1FThO3VlMG" ..
	"wLRGABV22ZDaIfZUNzV/5bctqpMyjkEzh6frinGldGKRpys3mFyxdjUCT46lJRNleBwnY6Vr5z7B/FaKBnnMmWFQZd4TauuN458b" ..
	"U/+ZmafqtI1AZITJNYC7uo6qcGnSjgCoZX3OWTsX60AOvp6tqTRz1EoO3q0oNQjzOCsFDoQNX/XXelopVd1fommXBBpAZT9ieBl1" ..
	"B94HvxQDTQ3PQlXZrfDyeO7C/k7/Yb+lBa4t59GPqvwbqYeArmzoXrg+kwqHUfxOsfdouGfAOWz1mBOVaIoqVevqHaENdhfVXL3G" ..
	"WwxTqxUtk3IobhP8JrBIee27Nn4ldW8a3NqPeoSWA3EJorG8m28YD4pY/22vWuRLTKsyEIYYcXszJc7oi+eDH5PnHlIm3Barh5yL" ..
	"+t3LKXynfMPi7lnGZTwh049u+KSskntOzrgRDwrtSrK1A/310UTj5qLjYDb9PytVJjGpvEzlkzDrba/+ntGFK2Hp7K0qfWL6BjcZ" ..
	"PGnXlM6GkU3KpZ3G9ox9qET3KYFzfVgijTrkaWIOC+/wn/7dnI6ux456VJO8G/jqfrp6WMGhHhhP1GTuP97bEvqkV7z67OcWCh90" ..
	"8OxeZDx3SP3L8A2JeJ3NOWMWLoEX4o9PCmHH1oBeuD/EhsbCYuKgpRj1aPhVzz5DPFaSl4zhAKfUSlpllxzVl90jDo08UfWiBxvj" ..
	"JZ4qGNOju3EXfSAxj1V5DnjYSUXIHVDEeSzdN7imwlLTaItgd2LzSci3lpbOZhB7NjUlLreChok7iHChVRwiAIpb9ESOn/A5udSA" ..
	"bAI9HErrcvUqbqFQ6I46pJtOl8NNlFyEsSB1M8j0ClouqFr4plylLt4VIDiaWq/vZEM/YHiBltBt8a6FziWFCQkSHtadk1NWcFd+" ..
	"AOx0PtESqQASksoW0W0jO09iXI2dZr4yJK7V6t4NlBNM2rVMg9B6gLCGFubR+G8onXPywJV6B4PUhTLbf1BdkxcJpWWpyG0lTMVb" ..
	"SDuSF54Nx/Wga4lS7+Yv84mw6V0LN0WOPtmMIHVB9ORkl8wjGaJU1JrFgYJNpWQVok0+ZC3tgS30D4ePLCsWnDBlGx3RnwsgL3H3" ..
	"kzcWt5T8NU00QwMQu4UwOn0ISLw3YLegRkyjqy5jZlolJdkSlek6Y1WpVabI1XMdG8iGOBGGncoVYou/0T2bL3WfbK0Etp8qD+7b" ..
	"y+dnVCaqQ1hj9pgsn/TTwHyQgYyaa/r38+T0AHj82SpYi+VWQovh+ZxKaBlLcBwxCghFMwtiMuOjB0W8TG5Ye4pi6G1h+nOcwMd/" ..
	"1ljn/acGL49lwDuLQJxL7LxHbgkGXbyujViy92yAbyOTHdqRk9/Mno2xIXMi8vWHWQEuKfzsJuzOoX1q/osi96Uup0l1e9YZQFaH" ..
	"IgSsLHr40ahcOPDH+yjmLNM6hyjUuZvSVhSk6xBnQg7DjkpsVGpUY5YMpZ2UFyVWQ02wla5ofZGRsbEWd+KrNnHk1tALtVua3nMR" ..
	"EhtAU19tqFruVTfuUDUS4s3twycNTw322zFme6DwMSIckc1k6rZrj+cJaX3I57cziNdDq9vG27eqdFxP2s7vE/OJh6nD1rnJro5q" ..
	"Cl5onN9uPwf87VOF+TRMIqDBp9XqkG9a2RYVrRnjmktKrqgru36pKjhxEeTirH2QrSM8rnmMERynZkmpn2i8vQnursny8wcefbf8" ..
	"SxZJk3wdimdQFOxC/v0rvkUwwdkWdPxjBqGIRMnlDhBTwnsScxzum8yTz16z2rOx320G/zGgB1q6pLYYTkY+gi7bJRAkm5KvJ2Mi" ..
	"mvFZ/A79OapfSp0hQiY7T04wS1XjP+e5/CW+rajhsEcF5JqrHxWFah2Nc8aIcdBEtb/cV5HhOkfIVHNQBKrKx7HcJyeTVrLL9+mT" ..
	"+RYqOcHokt6JAxLN6SHpvzeZmAcVgFO71IY24mllqkeUI7huKAZM5S8FKoBaOmNmxSfYgEFmG6UYKGMHh7Hh7/J3/FuPneXRvL87" ..
	"HLMueaBf73MokgHqZZ+0vHLm1TKDQSW9VyMexmOkF+j4KHCeMXzZe+g1sDeuIMgfFU/OO4DMrND9/uAhf1olpAvN/AzshFecaHgX" ..
	"PCQ7NJjUby8Sk+CdTohObiR5fUhjm9fgLEMYb6XdPFRjlFssFSlVUyYZ4JmMfRbgXuTKarglbvYtsslI0X93ui/+Sr46y3mVvI0P" ..
	"ktOqA5XTAIFI0CzWCkOjNxUzNwmXV7a7NhHDLMWM7IkqJ798nsCXdhkBQ/kN3OhEFrzrvS7LHoYcz0CE+Q4g23uSWjG7MNm5QxKf" ..
	"qs0l1uZkyz6JKQV8vGqBEO56B0tKzIkg0N21ELy3iTNZHwXyuPAqhuXsKvrmsFBRtBS2DLL5KnmKXPLOxB/mNEvNhaytr01hLKmR" ..
	"hNMxhM2/jrOdMLZdv7yYgtKwTSJm3//mESJ7bP7SD608vwwdGV/mBvB4yQr7sldQVAFWT6xelGjrgfs1p+4gbzN9h0OPokleNTzy" ..
	"iKRSUSuEZe3eu08f4j2xo1dGyfLh0eQZZFHClMtfmIgsFdkNaGdXX26ow7aq4ZQ1W/4UuSSXbkdUpDIOtSfssYzY8D2MYsFWFGbt" ..
	"R1U5bg+15bSP2FhRrHxz+LWsCtX/YrCuW15/XTJFAVkGJ7+hNjFezFehvwXP0b8e/ayuAtNSMJyDutjLEYzpUUSlXJaEVPjJF4ZE" ..
	"Cxwya41DkneXTc6qCV7T6bgvqKtxeJMYkpUZHy3fPwvnmVx1muJhDu9eLtbMcn7V+wdUfvsutrOstqb3Fwh4sshMgVPiXZF2yj81" ..
	"J5+99QAudhGH3nCkVqHwj7Ku+5xX7HV0Qk9aTPGRqZK8QkykdQl0OA3nf2JhS3ClXmB4aICEfQBFF+F6d0lzsm3uJGkpfjKDiD7c" ..
	"ug/ckqv53ZC5l2agxzkox+oLcX3lnqHtjMf9l6pYGe2mDHnajfViApuVgD74Qy5WoxXRUHbvqiboTsRQN8kBgvMuLeGzUnmYZP/G" ..
	"JXIXQnfUAJtVmONCJ184sjreIqokV8fvlkCJJf69xf7lG/vRLMLLHx7yKqxrwFSCxcRgzxm5uFWhEHyuBxxtjIvbibHOiGsZjwRj" ..
	"ifn91saYj2MDAbhojDShHoHMG8234EE/azqBoC6At5HcLP60ucwdd9SUi31aF0y+WuF2LCvu4CjzTnGhbqcHOhxVGpCazajDLek1" ..
	"SKb1hf0FTawfNRLEjn+Wu61cErTdUwkK1OlbHBy+IBGjTXuMy/D2IlSJu8Nh0oM07NqD1ozibmK9/rWQERrFS2n1O3IlPtcdyvKw" ..
	"/3PB/j8vCCanpmpZV2fX3PnLISU4OJNMj2HfkS2V7ejds46wCJXEaFdXS1f25cMrMbUlfkdnJUP0y2aEh8Roqzj8y9WFi7QO34qI" ..
	"HLRI8eP9AhmcU9qRlK9fb2Qo29RZT0KshXT99o7CLPOXtQx8J4AgbjLXjR42+2gOpdAvOk3g3jWq3WcYRs6D0DmQWL5FMdoJEzmO" ..
	"jqz3Ug/CZyzMzK1t0wtJbKBwMPWfVQg5uK1uD04+hiAirMBqLLE53zTkOqOgDusrPjRrFejdOTC3PGdnHdD+z0VuUrZRzH7xbShV" ..
	"xb9NxPU5wkJLmmgGLvaJ7MODpbG1PdqYyGbq6BvOs6TdnERxio+9MJDdmuUPEPHSgWwCAoyMNKzVt59XLwZEWIpLPugQAWKw9Pky" ..
	"69a6gY3rfVvaNb8WBg3FHD+aCjSsea+RQCYORzha/48gFkSkF+19k/RU2hwU2+ECmuGezO79ADJDIjJyf7/1Ix3kL5HeUnhCDuWS" ..
	"FeFpnn35nUGieDPvY4SnPo4yDkN+GtIgagLQBsKlgA5wsg58HbkZvW9DDoMdrza50H2aYAsp24yOnicTK4ETTzEkL3gzAj1SAJ4L" ..
	"50gQftHd1gW3AJOiZ9Fa9Pg9xjCH46wVnTjIo33HPXRL8hHA0nnotKUfsH1DPw2ptlsQls4csxfnwnE4majFRWl+92s/x4Jd04xS" ..
	"9R38Fq51kOP/1X4/L0C3+vOaKVTirwUzaH1vG4VfOcg1+kI1BS8VHBzD5Q7+/9PUu0fkGSDkZoau5YlUN/bfyuhLsgCa3IQc5m2p" ..
	"HEOFWU7gPkNAcRWpov4DCQ3djVLxSKakyVE+vJbXEBiRw3KWrRnpqRNSAQRaV+5jZ0ajkY/YM2hlKIpPLe1lTswWkiMWZjfng51f" ..
	""
local PAYLOAD_P11 =
	"YMKEzSWBi7dW9DXF3wFRwLqzJmuzENrt2Qae96YlCnL4HbQq+vdLkzeZM0Bposvu7+178WBQcHwxa06OU2e9IFUiIx2D6jVoowkf" ..
	"TAJ+wsAQ89VLLGWwFNEgmhUwQ4C5ML2KT3Pek8iioLcbjMRn4mcYB2H3adNYytVlYd+fqLRWahWU3bJmBKVWrmAq77gfpQsD4feC" ..
	"2jZNKWy7byLXCXJNMiU6hOXbO2i7beHVCDVgfVgEOgs1aRBsECLtZwVaqUdnsxDfVp3cuktSL8mKVUKVam7gc9AEglwBzaPTz37F" ..
	"gHls77ONTsp36TyRv3gnnY2MKpx6Et6Kaj6kbnSShbG+nUhmEC5NDpMv8Lu9W7+U1K0kht3ZoZ6eEvBjZOs+6uclsNhiIvaJmbwM" ..
	"6i7BLsGqfunqpBZVuhdpN1WLmz7R9B/blwcrxPPWD7pIUGAFqH5WXw0iUP9dSki0P9f/fQP6yX6OTaNOO/0oQVPGwaQnmf6931ct" ..
	"U1uFwj+xHYRJ3OSMrFJIq8TZRuTcNqJx6YRwnSmiUOOgsf3cULkGezYIabiJ+2sXWl8+RRz0SLGUQQ5cX6mA+kHhyXWe1MOGpTy+" ..
	"E37rXTLHyRbrtyYr1G8UQJaIJddlmKAtyaYrR9/8BWnKVuFB3fD+amQ1K/Jqt2BURFS+6EDNsqskW8JS/TtIAuNwGhT1Gwy/SA0k" ..
	"EH2Rrp4dMlVRPexkdzXvqiFxPHpvWu+VjF3WH4zFKYwglsc9wOVtcVQL1D9U3e4zSlBTqzlYfyQmzenHMH+rlxHZOETQ6/NEesUr" ..
	"E54RmKNivJUcN+o+EuxG480DTFTG7hgyMW0w0XMvfpMl+K/aMa+L7PQOWRnSCKKHI42RpNkKEWnvg9fLekzRkOEYxyV06mdHo9Th" ..
	"eeCc7k7H78SIlWomztvImrKJY2h7ufwpjCSzjCqpmSw+x2Jg1GyuKMfcYVp0pA1bGobcFjktaNEw8rP/+vsGAl3dknEf4uWjk81e" ..
	"REVc66cVKXwZhoDHFVLG0STUiKfs/V/ePkZYIwEv1pC+A64R4ZUcyL9rLY3MPCGzl26kQWxjyoPgTrmXmV4+fPifYeYHy6IQlssV" ..
	"I5lyeCDamfxDssdqaRBkdbm+oVlLNhXsiLk58Szwn+nkBKuMbY33O8ziD/I2Mtt7iM3wgVJ4hijyZj8yZi6nsV2feEAQ43xh2I/u" ..
	"czn4eDjWwtkSMO9UvDGS73kYjEa2g0q9LhlNf/LreRWjKYIjnCAWhPI7Q9TOETvFerwNQ1A+AlOuaB4v560l5z2qGznRt1q+SXsH" ..
	"jGJs9R06OvqCv3U09WxTY8FIBSJGDdoM2nRK9yqZz6uxQcXja49o32asfdV3wj0kCka6fjvJinxorlotI679cwn0298dmh+iKciB" ..
	"RVrAYWZZGirN/i8vywediF1ZZGZODCwwvFgUBkVpMSGO2yX3Pr8jG5v2ee3xyJyPRWWtXxlNBhHHDwimg3EFFMW88Pv6fIDFqjfE" ..
	"P0sYnk9i7hDoySW+BTYfaVZePWSLULFs4cH68dF//PbHL2YD2BrNbyddYGQJTNRyQAJNrvOXr/16I7PFVnL5Nq75orXayLQKnPrw" ..
	"vHpjrqCXynchWHOT+HAkqmu691rwgvoxizCA3wUwCAHHKrSl76jI2PuVqpzv8WbVGKf1aOdwGSgFLt8jIJJrLZPI9ooBgOffsYHy" ..
	"BExlxzqNJFzqPXtqpCWcSa6rmISMs1ZCG4bwk0ybpZIdiBOntITz/6DjzOn0w39UKoMHTfwPQjbJA9Hwg3cRUUBcTBZZn0clgPc7" ..
	"/4KKf9a+o6SS/ZfujPdjplHeDNFUwurGwdJIi6UeOI2IkBi2iIIhT9E9g3g7WTOOvJ6v9Ygpo8/vOlw5GZJ5Yj4d9qLoGC/KtPzm" ..
	"3UDGjkGBzayi6g6jJj68WV6Q4PVva+1HBrxAEASLuY20QX7eGihWvEJE0vTMwcplvVoC0qFk++Ebe3e6zW5TdkEBXeLuehFFwpS5" ..
	"5GaEmitGno0vSBuB61XFaCgD5nCnCbO4GrHpX5H5F0KbO754DOBVocKs3a6WYc6qROgQHCBsf9+uZSCYBwoJL6bstMPX6KrU/qrt" ..
	"uVAbd7bmEcKmzFKnAriIRIIeRRx0t9biJdXkXwsdnwAoOCAgfb8JjglAmyK3txUr380jrJ1yaR3cs+laqM+6LaTDU0eKaZCpn+AO" ..
	"ChgG9gOo9Egqylv/zSo7zfN1853redc2oKjYs5pBYP5PAZzUrhM3+9CWpifbc9yB6vIc4Jm1aSjifeRfzGCS+PrY9fKPllMH32PX" ..
	"lI7jboRWdkqXMQvHZYG1bSu1IUiOnbjGGc9Xf6NP5gP9ZWmNJSwe9/Lbk/KHkwZeVy3mafX1u9eZhpc2HxKiJ45sR45m4ozB2CsM" ..
	"XEcISIqwCIfFgWdC/yHTm06c+nwaFVWDNUc1LoYMdeSV6fO/mtLJfoKCXhn0sxscC5b/5j/PU6r8mR7kmuEhl9ZrGkgt7aVw6bL/" ..
	"ELxP22rcWRIDqwo3mLcT/ASsmHw0r/Qpvo4nFD5Ed7jH8P4vAlLm+Lkupj4gOAlnjM8LSVv6hGysbGerSt3yJ3MwJBY5fUpP72Y8" ..
	"5DCs2Uz5zFu6QCWN5153Z2btk79UjsqAwT7NjVyYOK0Kch4GSbSyo9p3m8TYMZ67iwlYoScxi29inVoWJp7dKFQM8X5aGUdJu/Ru" ..
	"McFlwFDalg4TU7yFOe6Gejlmq2IeFpAAM28QUY105XaZTkboUjONovuBiz/S/we+qr/3WMOxGhrX2f0TIZchBSPO2x9NSH+1qxeN" ..
	"nyiRXTI/t1WUD2AcdX7WJIf9qChzVDmRmDiwRbZkhnSOeZNkry9/RFl9QPdEAqqTPy0m33Z+3tDYkKm8wt8AWgrorYRGU0soWNIA" ..
	"hB1eq2iZUhO3/MISNlhjhLumrWNb9ctDKGToC8GovclQJ9wtD/COlT+zKQw22Ta2J2Eb2aG9cTH7S0yNto2DjBLaGgN9GXdJrdTQ" ..
	"mHD+sn+0/7h/IUxXq/8EpMngUd3rf2jvo9yQT13yefFAhFYPhr9IdcHTFUfIFezTckIuKTWW+wppxwV67wHRcyZp81Q9aj9lnCS1" ..
	"uaNkymN7uDpmEijdEwKhZahIBb3xS1T/upwCpY59B6DLCYhYZsdbrbVf+C7pFKS/pvyj1KooRXoVGutIGEK8ye2SR2+n1y3VFgfs" ..
	"ZMmB1qBkDhifYAyrUjoTTtOx0O6fVnBcS4osyfCs498awLNpZw6AeH2cB0kAmz5LVglIJpB847LvYjxpxVN1xKmrLthVeYPjDGyl" ..
	"bTncmmAK6sswkbyj1w6tqLs2AhanjBes5+a0UqMkWn6y6T52ggPjq8/ZcjCO6DdVo9lcYWqe7F9kBYqnV2aoEcMLoijZ52BS3fsT" ..
	"IpO8J1T1CWrX2IhiFJSvBuA8OM89x3IX/FvRDo8LURu4oOsBfEviWu+iQgrXCckcgk6SCm/kwZS/msoRFXvK7tdN5ZiyNHDC5yMZ" ..
	"M3RMr9ZW1XXluiTB59cnd7RNbVlLNYWgIrwR5zYhYZlRN+u+12n3h7/iO5XbrRWm/UrXKHO8/jp1YM7mqJHmoaorAx2Y/RlTOx5c" ..
	"sJfrK24Xy8iIhD4pji40wW/Y7PyG5O7r4Zs8N6nLfenvVSDhym4sZdmoPaQGr4Tv2kCTzZ+yyE16dwhhZuE0Hw/ngU5Oq4U5UzCX" ..
	"n2K4u9nM1FrYnqZcgoT+XWyPwIfOsN5L6ogCwDkIScnSRpz8hfarYzwNB4kV5Dp64h0xY86XjHpjzD8o5CWj4VkGJXq6+g4ypXe6" ..
	"D+DT/7CbvG3K3/fZdVW1n5wwvyqBX/ud9uSrqrN/YPc+5uvY6aZqz2kkqnT6PB4mvZEuuy2Hhi/jEKYeMh137bWKGh5o0348qUvh" ..
	"AlCE0BeB5St3o/nIb1/omsJU4+1a8wlIMa9O3dgEeCzRNuRo84rg6kuwfXQ3ySKCxI+CQrltvUtVIzMRgcz7RN02lvsCgbbaWSUc" ..
	"EVxeC3cxCXf20E5saZgrETiYsfXbJe6Nl0wA3a1kPTDYUknqF/NXpiZkfgelQ6mNz7SkfUXJEUWxv8GLA69j/CKJzgp15uOEfjRY" ..
	"nCtr1S9RVeM7YlYteIF0w4BhnT5z46tAOGa2Dhpr0NAsc8FLOW6WGBo3yofhkUo7mEMUJ9VfZQskfkoQ5B9xfWmsKWgcUZ/C4L3+" ..
	"gF75stoewuPV2cYWnJU1eDvCcSTew0P6zdMId+KpEu4yCDF9nWSVOieoQBR1gZJHmeWvfCxQUkFrBtWFiljQdohANtKJKMC4hioq" ..
	"oK34V2ViIo/Bla2R6gLeqXCTsvz/IFX330etkZerAABItIDeroWXwiTJOg8r63/X2UnYNrZ2iMhzy5vxNitU/rSG/D9ges/wrVVN" ..
	"kgDoYkZeCUcGU2repK2ei9WEGTevaO7DusJIFCGL2IbRXZkO/bM11GGsNyXsL+KAHtnho1Nze0HDaLPH1yI0c68BzsZxk/+TwIUb" ..
	"MN7Jh8CqjkXTdhmlfl8U489Cq+71t6pcjLWvvBbIPQoTNgpZiRxclXsmPNiIgSv5IUyELmR5coOw45uP58IsC3j/KBBjvoS+Tz22" ..
	"vgxNfSSWnz4ylR0KjcAbzo0AcFNu/vcyiP5UaIgLrvJCr5AuEDm9YMycjOWKtzr4N9qaFHBAhrQCcQ5EETaTS7y2lhOfvktNgjPa" ..
	"LjowxycjoPWHHY5Ya+50vwM30fXLK0KyNycKJIK5eZd1pcAcjApIAvNNkzQHafMhme99jCTFKMtNllPzhwM5nomK/l3LQazkPQOE" ..
	"UcQp1433nrG0nQFmVOg0tkqhH0OcJ7S9qH6gPFfKE/D0UrRoetKLxkGjrncReu3iHXrWhQh0Pdwm4/OkUV/+aPO+oDLD0L6gaj81" ..
	"60khj/Lng68knMsb4lFwTCJTe1FWLEYkrcC/3VdwxpXIRouxxKFRLIoyfqk9tUSEvNZ6kpHJa598rzKToMDZ9osg3o+TxYuClrQO" ..
	"54wysxEbOfCQY89xaFNIemCJRvsuVHeOk6mJtt+QMiJG2oUlAUX2OANUHNOW4DLjwnXIcuygJv9j1wmoDvKUNbVeCr8/67fIaUHy" ..
	"ijeol8i8tc8dZYXy+sxCQrtSapHGpPayvzjpVXuG17HJY1nyRfto7IpK6dxw7492t6QHKLnZfzcsQWmFF57vF8CvGAKifcOvGh0t" ..
	"rYHO9maq/n2LFhsHxt6xvjI6eIACeBb5p8kgL8BT1KpWpGjMTOChHd2tBVEmVOM6fuGGW1Tlw4EPUYn8MSsW6u94dkeNZlIdG/RB" ..
	"6HpzbYzjUHiXpZy6fBB+/X/D6cKQFGkP03lzd4wifWCTCaDBnT7nH6nuN8l8fpAAUe6HfhDlc2kN2EDE0vxKjRXBjp+1HJ8yZvkX" ..
	"V6To1iOj6LWxXikbtyjP0fJ/X+7bq5JmgVya8hUrfypjIT/diH/NT28HzAgOt3h8e5+gKnzQh17nI8OPeAyXI9bZbTiw79IOzHMF" ..
	"CaKHWFuYDPSqaTGy+Lk46FAmIVIyxVwYLt2B44mMP1n9tcqO3iwshQrBaVOrGwAwhZdjLkYsGWx7dcJNMIaBbef/sUKD2VeRjRmw" ..
	"0zBSITlJb8tSXbppDdqHYrZ4pm/7uaVEtXEqK+0DCQz09EDZQXPIgtbXFKQ4nwyuWczsxBQvbNTDaeZ6gjo0wN3Epnj5m6rgxLwN" ..
	"JfX8MyfL20+EiITU36JZbg4kN/w4luLKZJUvLR9tCzAala6p3VTSSi4ijxmV6TeHGuoQU/vs3WbQ8wBr84G8prAozJ/YHr8nrf+k" ..
	"IU2N5LOy3Y9TyBXdZWG+4/wkAe4AZE8YEUjHcRu4L6XMXjF8Scmv9rpBC6Ndyjfv2Mk0uC+j1FpT6Bu4KR0bw3Byw+zNsrrmmx/M" ..
	"WpZ8/qNvjAI/HCfQwzkPqQI4H7OxCkLvvj3MtMxZR5w1VwXLZCpTS3RNhtE9Bp31bj++C5mJb/TAQ89ykMkQSfnjJwiLcx0lhPMt" ..
	""
local PAYLOAD_P12 =
	"ZGX/papMEqdp1Wcc32vd7TQnO2/XUGCMbYPjv6KQ7ywT/pfUhOyR64tjnQwlyyuT9YvBpf0QeQkvWu/TFaC0Im4hMDK4CfuDlBUc" ..
	"poUZUHC7esm6AxNlpJYHDFk0Tpwg5GOzU697RKEpRCWXfn7w2SVZ4CEixLuEX0h2pGRqjQv56bQyqhlVKD64R7hlXOWs/ESXnWP8" ..
	"RyxQ/4jkzbkyQM5S/d3GuPMbSMwLf0PNmWE9ybmoW+VnlrkcijMfThE7j5Jp4q8Bpp3Gw2yzSar+WSUgeNd/L2DO6vCR+uNu+8Hq" ..
	"YUjtsASAzuf0xoSBTNovsIaZyA+0alcKFC3EXmFs2RweSHeT3Ewy/RpCysCYZDBxW1OYWVP75ei8YFEGgsS/heMGWs9f3iSUefaY" ..
	"dSFqvz7enDKpKchOY0HSPKiQAY5FlUhz9/y697M4+yFF3w2cdsTmvGxMLfTUzJxELdiMAHGoJOeDk5lk9NKTGr1+pQHNSqVgiZ4G" ..
	"axW16edi+36Z+g1FezYURYh3hNGWMjX6kFudYCysCzh4ddRgE+or4GyVxhHcTdYWR7KnKxm94UYY4lOGLuYPm/bXwL2yOGyifeUG" ..
	"6Fh47+xp6LTKUXF1pwTxYOu9k7aqJkewX7SxI77tXhdHYocqIxUQvqwvWyvEPotYEKa0NIWoQO2P09mTEwthMBp2BagfVNQrkvW9" ..
	"f3j+xdy6pG5E+fzt5o0NGmrYjwM31YDjNvjZX5ozs/bIthEaqYwhLkJ69d8QZ7sBvN6Fadn/KkmpCUjfwOb46lrLsLaBbi2kCAUo" ..
	"m1ylNGvugN5ns4IQH0f85ZnCcfkOrbHKwTpBu3uGeO2HB8wOmzBwfKhKiU9HnW+r+enRAmqQ1tVUCyJ6zKik3G03ahX3qV8Iu9v2" ..
	"mkhNfqZOzlubACTg+CIBNVEzaLDaN0V0GsacavANAxN+eQ8K5d/EoHkAjYQfC2ff3CtZyrgZWAheZYkJSBmFXhVjdLWaxAWf5aV/" ..
	"M3xDCCieCiy2vmrLkeIXfe16YLbBg68pG81Mae5bvnwgtPuD5i1rEEeK6KJilJQtQvPrcDYqCb1pWoEZy7yzJbFJ15vCD2lHqzEB" ..
	"V9hsfaQD970Bk5leCu2+H2mjMsGejOQoNHaKMfzobblilOc62KOezyHq8CBYCZhJxw9ar/ai55pgw+3faDd5w+cXkpXVkDb1KzEj" ..
	"v6Zvr7saeBJ/HYcx68bl6bHshlGpE89Z6vGVSMD51yk7xW7X1UtF8PHq7qs4wESD2x52JePIO6YYFbuuY4MWdkn2HOeUbiYqhWBG" ..
	"e7mw9g1deE2Qzb4kBdxEVmINSzHYfzYg4aVMHrgpprpJleRbb+HhaoYWG+77dgiG001oisZGWsozwV/noxucUtLnA+jaL+6jihLb" ..
	"fZYFPD9TkunwJMxpzAX7F4non1MXX/SMcwPcHhLZhWqLS2m7V54pX/gCVKVTiHafGsCPXf5sf6MFysS9jv3SvtB6A3WIW0GJiAig" ..
	"gS/4FdtvP3XK+A7qQZAArLNLeSMZg6NHDdiscNKchV+FDeSBNwwSHP1p/YAG5R4/lhO9TQI5X0kxVrOAZaa0yvH9ZkyJei5ovzgY" ..
	"CRNBf5z1ErkKmgif25zIQUdl5zxJ1dbLs3bzwVRBhEAp7LySxhmI5yEOVEZm+a+SSW2jpZUoskbqarzaQiCazb/mGQoJ1/GRAf+R" ..
	"QlfO9sL32d9MEF6pjwINP9+vegjJ6PMoNuZIkdZBS+bgfy1nJABuqyoRwhkFZpIEAcQm4o5lsr1B9enJ0PSkVG5VYwsnUrCc+yKS" ..
	"/LtOfTG30aS2cPQuHOKY5HGNE92WH8xa8rXcrUzk7cNBr50DjcPpkWxUPmd9nWuRhWl87hyXMwd4Vn4MMGCmog5hVUB0/wrn8FkP" ..
	"K9Fdhn3Q8h5GyERx76Gi8rUxdqGy2rmgrZmaxXrLmBr/8k8r95V3Zstx/C5sh2xt4ogTDr5OxgXBKykTvMTDTbDg9R+pV2iLryFk" ..
	"Yw7JCLxDRYE26Qa/5ZwPEzYNonMGNWyHv1dMYQASmyt6H//GtejFg4WfFxbmzISw22fMCZHiw1qoEIy8D9hfy9mqPyt+TAFHQZLj" ..
	"9IgCfDZXpYjgIQnFei4ttq6eikZIsahQkgRBj3M5dqAp5mGQR72ecgoeTveCdO/2Jez91aZiTlXZCbml2R2Tr9aEE3zIoPpJloNO" ..
	"ZiHPQgGZ0CHfQhA3oB38giSM/1DXqY7l9qzaX+TnqzG96542Jg5G8xEq02YZbztRsQbLahEfhtPoHZfGKUSgsCHPcKY6EY746e8o" ..
	"lpN795qGFIQka0OTinF5MpggY51M2RWgPY9S6kLD1YzvqL+/RbApkj0f1zGvfWii147opQxvsGY8rIJSCwozrQtFUUWRKOA9rOdu" ..
	"0QaK869pUYuB8YdkngbjAv8kWT58vXjItRlIp0pr7hJIFNUfeGbIMb1pXSvrvjEohcyedyBc7C1IsRZdfkGUoKuWre4utO24w+Yy" ..
	"6xD8nsQcer7ntR/xL9RlOqdmZT0SEetdOI/h9M0+oNBG7pTOFhWaJQPHEnzqOJVEbNx64P/nAZOiy/frU/tSkMcUPGKkqvWf3XNn" ..
	"+LUmfZV0ArSiuy47CcgcMg3vcwdvTZxnYQfpuK5NX7aJobjUqQ9TD2JArZKDSizteZP7CNheQ25KGvzYKnLIa+XGFNNhjjasBLa8" ..
	"Le2pD7apXQsIssQgn5foMcTyf2olsr95i1/WEFA+dRtrjdAnO/9pCyKtqXlDKI9EonWZIuV7ZfRmvN6+n2I9dcJ/7B3z3Q4r7Bav" ..
	"0W6DjcS8Zi0f8UDohfAAqRp3f09t1bW4YZasS+P4dLJU74V2VG9hEEZAYH5TMmDR3jCjQq/b2VSL83vOYkzbWBr4pa+PNxgI1uPd" ..
	"l9OOSCRTqybRtTp19yKPWuqFbEXIIzHKKEDK8iZmUyN0nFHK7FkXhAAARIhwOeKUCbGJz0QAwmi9wMeXRmtPO7l9ceM83dNbOsc0" ..
	"3nwn1CpaVpNptjQosFCzMaPPjP8iZSC9tPk33eJDwNN5MgfNlpXxVRfleZShpqwb1cCRZTpIYIBHQkyYHu7i4oDnCLJmRO1Qy1RK" ..
	"ttxEvxRPh0sIBsKha5zfxITGs2nR4YdQyCRBzkKUPQqSeXzQ46W5WQlAWrMs52D47wSzI6PtFZuoyny5/krjlDMntkzi2EKwGBHA" ..
	"GbeMb3ik5CEwARFTIV+qTCejgNCxk+jiB2ZBHd1/15iVIYkUykZks6VFMS/EsMmr7RYRZxzhU3Ue5Qd6KxOduilwQQFaJRLz2DRo" ..
	"9D7gMIY/l77hCTMMdRkKNBUPOrdgPxpgLZpo7nt+nRPnXM8rhmez3tVGJrjgo05YMlTwnzhoLbNd2dR7hnA1mzjFSSKeEQGb/5hT" ..
	"+cHVcWchOlLJBNCYFZ+q0FKrmDI/VBcV3HZo3Uw0J+GYFVn/3S41OtYtFMabuf0ffR/TkrSdBAZeS/hLJh6h9ANvkqvprXWnmKOA" ..
	"/TaDmJsRe+M9LVtQmjczHXXPqlkSW3tXV/sOSPChAa7Oal8L8o8rxCXAbTvc7UvtBIadjhXfBbZkkfK8sL0Xct2GRRrs6Y/inlSo" ..
	"SC9C3h8S62m+SvwDsEPuBrH1YFToJdHk8yuRsLSDnUNZVjf4Cy+ePpaH0gTJb2ggKqpel72MgIt/1oI2+otzRXKxjEZoMIr3H9qK" ..
	"d+r6HkQf0c7UpIvGGecdCqyQyT/Et0FYFCzrrrfoIfc8lKpQOShJVT26ryl0iItHBG01IzI6eB6eo71oPyKKOlrR80IjBV0oE0c9" ..
	"UuJoSzrr3ZAwkDmXp26a9rRptWrCLcQo21+Q0kvvKK3qa2mxwgkYNOwpVDVqlUL97mUrgIZyP2yEGLFLwoX3+uQs02NF4m5QLOn3" ..
	"iwtV8PfEQPiCqoV8ZLFXJ3kdNtIZUHB6W1+DaeSBiyslqSZo1uYpSty/UV4K2D4vFdLcdKSrfgEfR1IFPubwC60ODMpUR2kP+W19" ..
	"5I2bcok2/eOYbWNM4RkUpqUCn8aGr7OltWpcmLBHicSO+jaioP8m17yk79oFVNE6PCDPhT+7NYOdPWtx0VzLZxVd5Dj3JLkHFBzx" ..
	"wYwoLfzhCFzea+kM4jY+1phRvh9AQK8Io7Mfhm5JraqaI+5fKjiVwGDakUB2HOupZ1gHYkhAsHIaJGaaebe3fcJZOHkhWp+qdOIl" ..
	"qX0LuEZ0Wi0CXdZ2kcPhFNV8QxmirneJHxWZLeIAWD5JBkOWM27UpXGVvM2FSIdOZROmjlJf2k5TzTRVIwBWn4SnuIrFjMCxlCtF" ..
	"EasyRKQ+6TOtS4Q4628m931N7iO6WpRY2n4nYpzbWcl/OYHx2rOevgrFwDh9cyF1YC32bW1TM+++F2b2MX/zwKmNKpTv6SyPXwbI" ..
	"f6BmpRouUdFO7lC2UJ8+Sao2oG0GJjRhJ09s1AzJuzGmKzV8veiOHaBK5pNIRZwARTrAylWdqQBs5yiiEuc54Wxk0RDldQT0zh3F" ..
	"aG/89yNz0XyrsO3/agXeYmf/9OmlqBTXvCcRwSKmoNt8/kxbWG9Hpnmmq0u7kW+Tp4iv61Uda/UZkHV20w6jL8egE60v2xSuFChl" ..
	"zZNTp/hl5yk6hfpVva771ood2hrhlSbvhVQBOSUaPehj+Q5tj0tyc038i+Ws4p9NHnT44I0JEOy3Yd611TRL9mGCNwu5Qc0cVhxh" ..
	"NpcaBVP8YfOjNpMDTYKMbQvwNxOyqtmed8nKQlkUzw74AVT0pdH0G2qyChLYyKJCE6e0w08sTuqOLVSOJMMdq5W5xUEP7F4to9IK" ..
	"YQ2Zhz3iyTc4qg06/1njf092C+YWzOF6Xym5/uAjOdbyHklIofsMoijm4HaxPg3m3Tufk654JRFz+BGhkkVsO6HFO6PW/QEsdEyo" ..
	"xyq+EVWTm3AUQ8coduQXhuztE1VnImV7PSyHv4uENSQVn+aT0f4ekiC2rto0OBuJ/XffgNdFkNx3mLSGwT8vpMO3mm76CUztOKHN" ..
	"2EIStOu7ehuy8uFOiYLkZW69JMnd3Fyvk+PLOhQnKjHnfXsGGCbZixcOUKVX8V+xxM1yAC3SdAGpRMn94eKOhY4yRpu62Qg8wKyN" ..
	"S9UDhiJtkxhNcF+ptumGmWWDlmvwVCIvni3oi5CDN11OaqlVufiFzHOue0XjcLjos06ZRXuRvKz2DduaccgTRkRFurkxGxK3FDk+" ..
	"QDWEkx0LStpL2DVAU8RAM8vNQfZn0usndMj33pHHgB0MrnepwmcLnNR0wCU0vVtQnE2ygYZUX7SF431qEDXpXYSjuKhTth76vGAA" ..
	"GGQ8NhSCu5G7CGfGaCsy5lgWM1tTMyULEoA24ANxIg5YNg8JhdFFjPcpTXq0yR19pGwig9RQIKyv5NCDn1w0ZxVMykkl1qxXepQI" ..
	"C9y8HHpHtQ04WoOJyZwYHzqh3uDWT3nD3I0WwdPuduSc2CEygCPcplpaN1z+oeXtB0RPogBLE9NgT5/gA6IjDdcpCkMsbDkh7LaJ" ..
	"+ohnHbwbxTlbOgBdHFN44Zt0qIwwBAKfkP0YREudKmve4cr0DETKtdf2nNo4Gxf1jN6qwrRokWDEPWufP0wgb3+0G9TbvfDRBdXB" ..
	"/JYy+Zsur+5CHa+UFXDreiFCNC1P5/VYgyv8qkVV920io4srzKGZaVgIRceq6Ic+eZpDk2mQcAWX3LE7YKJ0yN6qkHYg50DZ0Z2t" ..
	"vY5fY1bQU+2Z2Lq+bMx2doSM3eD8fYUIwXMY1LKO9v8hT64aYVDf/R2oz4acZeNBwy+U2hQWjTYP2wpPJ4Yb7vMR2gmP94FIYsl+" ..
	"/KDn2ln7Ba9e56t8xO74HiQjtO6CpTMXxuyEw9JzcTmspSTb/u2XH7kaBMfnCVQfuBG1DQwdoBe0OkncaCwFBN5tfe8DfFlCnaqU" ..
	"EWfoHYqHXPby78YdSDOwMmVIUeRu4ICysFXBYh48ZY5yzC3l0+wT88FgSGE/GsW1HSE8NM3yaZj4MPschdnSthq5PfZzXFrXTK6T" ..
	""
local PAYLOAD_P13 =
	"RUc/ZI9YAFG+ADXKIjTMU0Cm+W8sj3txiwP/C1oqAux2JXQXUyi02lOXclh+yxZh6SVMGjInrkz3o8GWYWv2n3yeOaYCcuMAMrQB" ..
	"fblMoHasOa/JYNvW5yxulCQwVqfAWTHMgemqqiFCkwaSWb/mhD45uo8GcTbb5bG1wBUBe1gv7nrHklns4O+OaPJ1KmzUHYRPjxex" ..
	"k4VfSgDSgavwgHVw+CKZe4GGiPkFaPDc9B2ef3eZFAG8UmLVwMXtiudqP0CKmPf2sitjc+Lcm8Sb2z5S+8oiW193G8ym+HZV/KPj" ..
	"AcX1TXAaE0CvLzml3fefvY9Sh39pbq5BQQy1BzDKVWC3icXNgm2VJ5EbRGZU7AWuHwhftF5ColPQ63Vo+XQgxg0yIqMTTAy7JpWN" ..
	"1rfp0bgserJi9jn/W8lzsgMMYYu43TWTuJpp/O6URQM+AiYvv1Sf8I3hI5/adkHNXLS+1EfjLpcQqPr0cs+nFdj8BxQ7n1TLnCGZ" ..
	"4JvVFSdXlwEHxxPuMNawTtjVVIm4iqLTgbccjYsWA8JAEL/B30XPWuyMlQ66l5WbuMyR0kpg2HMoY56gYw0/Dqt0fVA4N+bzS+dA" ..
	"9MDLXBRVFr7vQR4vokAvUHEgCJ6Ah5aZdizg+EaAcZ0kTdf/EbRX/HRbEEhY5Goh/Fhbc+k7Mq4hSJHKQZb+2+ObK5lVKlDZZ8S9" ..
	"ZpNn75Gvl+JEMA9XT1C830q4dpjgYWIO0q/4VZHIcB5l/pYzDMtz4FPA+AXAfmXpIEMHodGam/swjy3Kyvlx6u5Mc0FjBuQAEi6U" ..
	"PlttCTaWdOEf9ntigUrZz6n5emtmbCuWmlZtPtvol6F/ucv+BBc6E4mRaKHrmmO7eJSad5UaxViLXYDND4llDqmcOC1LklvhNdTZ" ..
	"ce3kF+O4M5SvST6qIvMgY1fCzsfE0V7pggpUg2PAoRnHCUFsyja9gNleu2hVywF1AIuNmLB5IxYsZa4Y3Q/zaRnQe9SYl7QgWCkr" ..
	"qiKRHAqPHnkQz0dr56I5cUj2fx9uHfoZRgDKTBB9jpTUmcYmbNgi5dWXeadw91xJD0dl/x1j4NxPHg3rF/IopPphYbkvshlx7T4j" ..
	"DR0K8qQppXnOC4t3uFSv+7tYnpMcYIWjd2tjd0UFR5OaUtWueGBpAS/KQDd5vz495vjeSL0XieUoygPIKAxzDZJ/WOaWF3Xbt2qe" ..
	"F84xdd6GrRAcdl/c9ICfwXkvxzCm15W+fUisNSC/i3JsCNAyMZ2kR9d/YdJfYYnmJZGheosOLx7sXpkPRLwEFhCm7klWcst6t4Nh" ..
	"owU/u8IBJmwnndHiguBDcmQTy9icLq6/IXEHW7HwbDD92IeG5JyY1kyaIKutjlkaYahTZR/MxGr42CWsVV3s0KhIscUR+xqiPCjA" ..
	"HCvpNGa0SUYRPg2n5pNowibQGShP8BAtOK3Yvq07alyvAB2w/V0RRJ8RiDSBabSigtMGD+ZiJQBo5KeYE0/KkYhEQ3TYZEsuaERg" ..
	"9mJuCSm2wLJqKpuyBjHBh4X1ONgBM3mXWYYeCoAf5bICj9ABa0h1T9VhtEnzEyNqPDH0cXulT31eE1K15gq7/HdYk468d73wzAqp" ..
	"xEm1O5ODk1Vl1bjAYSva8EALVagzwfRFwBT8WI2ynXXh871yObn31/STJDxNsDsq4NsKOCECKEvoQYgxOiDEvQKTDIVW5pLyx3AF" ..
	"fCADql00HRG9JZUBncNbPys2ub2KPxwJVlOFFNlHCPv7K5sCSrvb1b24IZPEIacovmHQ4mMWoPjrsagiUgDVqSuJ9gh+iyQ5e2Q8" ..
	"pAtrhSwwxV+6le0+/lTqgzHBhYMGrT7tMipt6FSf2uaC4b7Wzf1XBV2PWpbFsgSBjXvapKsdtYxL7vgQZ9hrolP/6a+1TnKrh0Dn" ..
	"ZndwqQM/YPuHpJEeVfWXZl+FVggNlZPvpJPYGLcJ85cTQfD6z3rNH1A1cWYEQGtsy05kqC7mYnHPywIXuulQ6YKwH5/F80n3lv6u" ..
	"ko6mFM6e2qlhE8uvVVJcYHY0MVGXbBxKrWWD2MeI3YDjOYp5w+i1zWUDuXYuaHFxm87haMFUTvvHHAM3drR5QP+E58fldnn6mVpH" ..
	"UyuWv/e0NtzOBSnTJia/RHLEa+AOxbGNjxUcHxW+HeQTD31gbMjaXlyKUCT+gSjx7bG2lT6Ndy+f6i7ngcrUh7/lfWg9fP/VzAX8" ..
	"9tAFsI+wMpzBHN4MmHknNJ9YNtIrzgkmNbsEfh8gu8yEOCiTsebrCU3DAwGXSdbJuRfg/lgobJ5CdDNHRvvCEslL25QDaRDcwT4/" ..
	"y4BQeVVwVDIxjCjrIGrryaowaaghb9DCVA3w5tHc1sW8vObPwjpTw/t/xNXCvOc/J/V2xVCLIbZ/UDqfmKRM8vVrCumjtlmQnL75" ..
	"v/2LMU8ofy15z+9EHcdqG0D1h/YXK7U7CSaeSETxnPXS4kzGlWMnX5qWpvi/B/0Ii1mFhxGdxiep6PN1THP+eDM6EEXzB/oALkhz" ..
	"FsAhmIRsllP0wipXrITbo//4XagPN7Q8fFqHss7B2UAX7s+OPCjISSjYAqEmRXIfUIx69h3GUA7TF2XLG+HIXuzUvOeBuXeptcXY" ..
	"+G0nw8pPZwCU8Ivl/YdgptE+pP+HqVVr0oDTk1W5XMbE0QrZGGNa37qpE//VU2/JoRHt0oRcoBlydB07/8RPEEBgA0vNFZBHENp6" ..
	"DavbrriTVPRWF4l5DSfm+6KcvEQuUQMPGOWOu+Jqz7UiCtGvcFV7IynCO7bo/IxFGM+IotDnbqcnj/nKc7lf6ix7zQAN22xS2Q88" ..
	"7se5znGeOdw9JA/ftUXOEpuF69Q9+C9ziXcdpu3lIcu5toRTKdezec/ae6ns2d7aLxqgQ9r7fmcnfFsaIc++CVYvIfpQ0kSrmtbJ" ..
	"+Lc33P3Gger7impENIR+r8ypxdomLLzti3qt7qrBPadMYwjiRz16JRlpUuTKOsemvwuAmTJAdPfNWsIS5zJLzF8YKHhAN+OGlPLa" ..
	"szG2TAGfiDqNqPa0QqMf9XtqfrqmBZZNfGYsx9sqCBIBqhbqSMZ/WGsDddNkUCySelotKP5aIFlZms2pAtKWBmH1UT7tvo6mJ7Zx" ..
	"AOCCm4PnEkRegDAt9dTlIITvQ634m761uNgYIKL+/pAra0f3QSIgyNhSEp3kb5q7QDmIufTBHfuUxkfgHL4hEVIDYYswiyixDif9" ..
	"Bd4Os7Wtshpk2oemrDv2cCBv6eaT+JFKxs8wbuAdcFuZ0/QtPikiqXROw8yGXzqMR0aiU8qN928FTCw9jlcbSthe5r4fqCAQX5gw" ..
	"JVczxJo5N3LiluU745Qlruaxq0QZnDaRPn/h6YtrTY+p1dC9SSwKU1XpgIoylMIB2+2ukkvFkvDMMpmxCwKRuf2DITw2seSHP8f3" ..
	"fjFKiqUo1UPW08VOLfFpjHWKJcsA/bI073EKB59HI71P3vFb1o447l8Pjpng1TIpKI+t3sYVIg6dip7AkT/Akz91utv5mBLUtQQc" ..
	"J1vd9d35sYJsiUN2ITTQZGooahn+ksb/JgFu1VdoKZm0UNV4OpHfGiiIVZdegF+QLisc68gR2DF0U4s1kdm9oUcytY+/WhYxQCjU" ..
	"0UK8bTN3lTtZs3FBuBWeXPEMUQwAHyf4aPheVMxSQuwmkP2TeLwkxWzBS7eDPNf2vYYxaO/kXMzuhUIuRIqZVg0l/2Ai6r7x9nP6" ..
	"FCEA5GnOh1Vas156bK8JZ9NP/RR+PALV31tPU0K42NydTj7FI8uikDpHsTbpEJHCyV7+oL2ecp4OpOCty2/f3jgqoVxHuN2BbcBx" ..
	"OvJHYyU2OpD+lCKg1On/lvj64Yq52ISXhCs8eaLdl3Q6u/nsqIFSlJkzY2snwkiELDvxKcZbUAKPfBlr81RYiMyevUI3prwURgvF" ..
	"SUIsZIJQ+1jyc1MtJ0LCUo5LhLRl5kqplOLUEX54ClW2BZtx91Nl2choePdujRb9fuC6bih1DhppdA6hwDMQAljsTy7ruBUxBlQ+" ..
	"16c/EuymlqoAhjUQh7RszBJFZ0eIPtOzZWZVWK/Mv9Xkzs/lWyq5PBcmM39RRbDpNTF9F+uasDGZ+0fyd8xC40yWHtIu4u+I1yP1" ..
	"R/VKD3kALe8alc9gSBwxqUkk4fv3flHDu/ibj9CmYTqLu/LtMRvXdHvDlUIUbBi5BRSVdsSDpniI1K6HXIsJQqbiba4LzyhChI2I" ..
	"tbIAs9+NT6xC9SZAFVoJrRFOAgA6MjpD+RHGN0ThMwjUwVHgWuvnrjrIOJ9UfVNG6P2IBvVpdTV6ctWSXq1n9Ta0aMaVYDAGF944" ..
	"DSeKxRPLwt0U63KcKsKN7dAGAsCThp932kt2lM0lQR3e0ZsWoMh3Aj2I7ng7VyTGEAtPY1HoC3ICEb8ssdgilUcDY1W5KsPjt/NI" ..
	"VSdq9CA5Vo7SPwpVJPFwXM0BKTH+no4fij/JovTuX1NQvouXAkeO3XOdwh+2YhJ421490nX3scy1RjpjM+gzIRahaqZZa4zc6myg" ..
	"qGPTK9MruMD1+VztPIr8hD/JiHJjaCVrXsiHeZXxETCfq3XwAB4WrKkb94KoABrvqSTp4/dkpDvDU/6+ptMNh5CFSkiAKkLeH/Uo" ..
	"kVrwVR2FE+3MnQ26RBhPoml6L1EmpsiDPcXyY8t28XMwACEuHAm5d3Iyx5uDpEHnurf+7jNgTtZf86uk+ut1qtXz3R1auLYL6MM2" ..
	"fUcCy5YBa3omuxuLgcr1HO7hEJqONQexyWS7l8/8pWngtHXfz5sHKtU39mDY2xz0Do7CXCxC2KNfMNfhZQqK7yeeJA4IP4YtPEZa" ..
	"N8kwludfvlkRPO0Oiz2cdZH6tDeIu/aoGa2P7CLkq742xm0epk4Fcgd3j6PP/irMlaNh7MCe/sIecp5YRR8JdfJhVBmFKHflcYWw" ..
	"gX0VoRaQr8HiSdVojFJViqnq/SPB6CxwrDKsNSmOn+z3kI/zWhC681UBU7OAioWjcLj+E83Z4acXrS+0MKyUI3fHpEQLCydX8298" ..
	"W5csF1Hn6ZRRGXptNNthd16RwY1hCqkfRTToK4FtiO9Qx6LCYDZ50VkXYNyXCZJoKpsi0HOs5X7OHfDW3YLBZ13aTi5wEOL37GkI" ..
	"NZBoZN/rt+N46mlcKC2rZeNSs+qQxR0uaWtpZVKghz/P+UlELzKbr0tnMHFWGdfF+jeMYhxl28tQVJMuxmPLwOcwrYjkEnng0Ake" ..
	"st0G9mK4iarz+Ze6jRaKlVw1/Bx13cAxWJ9DU0J0IFyrryEFhve4DS7/b83VgvyNjTA6pPYtvA8HsspmB0FSU4pjvii0UFHrFen/" ..
	"1ca5REW1TrP++QEOmi/IVz2dWNTzyTpe4a2bH82q6ITX/Q8VIqkERYJKm5huXvUmoL1gLtYERD6gZ85U/rWMhUk0ipxsMbN6NqSn" ..
	"NitbzNTQVYGS5rdhT/Biq5wz4J9HIvGfYr7SnJ4mH4QS15ieKGG0XdGspHm5dVlS3XzYtSFyamOgaLwpXulxpRWLbZhaiVCW1KFU" ..
	"6063fj2wJVPAxjkBiG2qIjwTKE6GnJAcOT9E9gWIE3Lil6mHLmoB1OeyE4tL0P0SUZPwIpxXr/epbcqYjwJ5Sz7wiwPVxM2ARMKx" ..
	"i30DOzPu9XfTomsgYN0azxa4S+WD3lh1En5tYfXn0qFpc8gok6pHljG+uVZhWrgUkKS1dmNTnXk34AOwk+x4M0/URDG5ETZd0YZp" ..
	"FksYUv3YbTGmqCL+8gwEjGPArwwndlRwDVDhNGUzKWsqbLJnEYGw8NQ3CfvAw+9aQYVwiCv7JZ7exi7UbsujK/SRxdlm1pASzt1B" ..
	"P+bXm2499uCEov7BZ5cPmAzpyBkc3jWHvGiQAkGiJG1XLxf7Emhfh/7uu2ojua739FV7LXMSTd+N9/5lprUYcZl//RrdreDgjZB8" ..
	"wao0ZzzziTJgcuKP5TxbLGE2Yr9vi00IGSAbJAMTzTAWYcu+DHuqriKtYoVTirQWhLiJTpK4JyKsdV/pOnKbDpW/USlVHWD0Cv3N" ..
	""
local PAYLOAD_P14 =
	"jxh/Af9WrBhb1UMgp+O0+xvLJFzt6Q30odfXDeiO8rgiQbqjlQHlqZmcPSWiirrScT8mxbT6n/RwTHrcI3TIYOwD+M5YibGt7a+f" ..
	"9cOoeiS+HTsmGMDZ9zKG8HZO5ccPFev9MXxVaOcoua72C8RxiCG+fl+Hks+r6BT4xU8h88DWg5biWB+Z68aZpMeKcok8MHujtR+3" ..
	"6kvOdQUOURuu37X/SeMowmcYkCXQTKcis1wHQBMWwrHJteTG3VjIvSGyoy8Ctj4j5i1C4AzjjHL4SBgNM7XeR2xh71whCzcQfXto" ..
	"k9sMX8B8qf7bXbH2xmRJTa654jqvbuPv4eZ05/DqKX/irVI86ljZJEM1rjtKMexMFoC0E4MGAirQbijqi+lPLyN3dzQ6PX3YJ7rl" ..
	"/sF3TRxmJcF78ywjPUp+okcDkwJ0BDBGqtLYcoGlgw/8QkIPqRHc1cBz/0EvQhDSrD284mM/3bDrfOKDjN33FOiH+CCwnXjKprAn" ..
	"nr8AeQqvNBB57C0hKtOjTEbtXdpb4mrCW6zcKveYa65G8g87i3wJ853Skl6K6WMeDPS8o9U/vHpzloRwcAmyZiie+2eRApS6pE8a" ..
	"AQt+3JbHFMVwWIc7flDc5HOhzKoXn7jGp99cF/yTNeJLgcd/8F0ZFls2aE6rUn2v9xyRIma3XtfcpoNVBdy9loeVSctZCJz3e7hn" ..
	"J7t1MlIebvgebCKTToFUibc6tSEGNXCFHqu2m/xPRtcT5awyTzKZyf5k+56HL+WhnIvaneftJX9wl1PBD034LHjlbtmI7byy21ZH" ..
	"iHE9bH6Zi2pxFkaaNq5oyEpitt8QD0CHQeTZ4p/fQn7PwcFU/FZbbI8NoWM9aMWjWN1w08G/w6O8kURRoimwTFiW7NX1Aq6QmbJz" ..
	"nJ/7dMbBOR+joFqYK4H1h8lYPji81Z+wHEzteT/cvhZWVC+5h6rsjSUms/gd+tYcqb4DJ6Szah5Yk75s+mWvvqbb7Fs+Av1ISBij" ..
	"EeaO3uewoHiNcj7KX2XobbxuJuj+0YVQUyQthKbCtnGs+kKc/qH7wZIfKyzCf5OgjRKniHPmyOF8r1mV/StMc80qKhWSCrT3t/h3" ..
	"EEqZQjtYMxOyTgBJQK7EAyRvqJmvN4OxuSg0Fw+da4fe+DeELxOC85JqGBiGfHfsOZPEgwJcETDmWcLHS91hzwrj4a+P1Ehl1g+O" ..
	"TNWM38py8uQSf9OMjteVp2O57zjwngdhVPLfpv36pkOJ1JB0AIUFvZ/eHrOhxPLs14AGiSF5TYWHRudY9tYTplKHuOQyvPIwpYIG" ..
	"Qr1xLIqr1PKVKCyrjrENroj/gbvfVTzL67sONMG3iayDP137aj1VNTLAFLPIYWX0YdkKyTVxUhU+g6Ai79rA/YD5etMtJWDQvlxc" ..
	"qIh7X2aGtiguqnyvhZQROP4NaaLR7r3fws3i/eS3ScMvDPqT28j28vq4V6c21rUzSmnVzVoI56VLJtTbV3L13sQ6KLozm3H2OhVt" ..
	"qm2ek5KEPTzBEQKIOxu1i48DiyUOMMdyXgbyXNZ2DbNsLtHW4NNqBZJcoCmQVuVgoQ9X4rAAzAFXatSjVXkdwoDQFQgaMVAe71Cw" ..
	"cQ4O2XssjdL6kK8z9xsxGXaSq+uV6gZBqfk1rzwQgwKwO6wREhaX70jsa/lbp8/J8DcNqMdyhkGkUwY2ae1v+7YyBXZXH1O/zybM" ..
	"8oDF+US7PIKlG640LTUAB6SoFAHT60z/3LSXviltoxMFSPoglTDgryaiA/hJpoWVmSn7lmOHB2PwZV2DKVsIprhR6kFhfcsVa39j" ..
	"d88IJQpBTIKtC37qXWfS9PdVU8HYPma8sPKKfXh/acyUjvPjXis8/+qJRYT7ucfSWE0hkguqQ3tYaPfwFUOuUGaURIlQwmcMcqCg" ..
	"GowYkJhSj3LcZW2VAIG3e4f1soNl0OGuXaMh04bSrV0sOHZxS274jOVR8lrcYCWLOeNpBGa60wzA4NM8UoPxRgGVc/G6SMBkdbn5" ..
	"yhTagEs204d4457gpH7BMRzTqeXk8jIFUREFq+fJaljiFF+ETSLaMrXXm0EoBGohh3OfF1+6RSfPEZC1Bb13EGNukN4gnibXQagp" ..
	"cZNANRCJXwvc7rXWB6ZFw2OcOaZHFDOoBF1S8snhuhphjkg5ptxVaPGyp8342Hv4ZIdoLuLgZ/x9nSNOZ+EDLtttsKA6LKss2XWM" ..
	"76Rujjya9rgU5QA+F19CT4CttsfrxSQ/mP1DCb2uV6AZeqIWADfCuEQ8rxfGYJ3gAl/UhkTK9cFuezHPt94u2bshA3PMIA7NM+QV" ..
	"d7ZwZsFY38OHAwWva7qKbVo1coBCY+GVEmYJbzyz+wDNDbJ4qZxupcu+iQL9E+a5o5keMVl/nUe/IRu89T64z47rq7JtZ1U8diD3" ..
	"1HIz+K/YyuPuZ2+jg9fzzTcrrRVuaI6PLqZSpvmGGnqXcD7CVzJBMTFkDJGTwQ0rmOUoPRdGkYnUJ5YB7D9trzVS/yIKj31r0TV0" ..
	"8aSIC2jrHDoGdt9Fwmhfp/xLoP3O2DM4379AzMKiGUy9Zc+3NKvbYyfJb3DHcUfY3IM3MJlZM6utFTSELvKq0Imw1u4tcqP0FaVh" ..
	"UbVOenE/7ItY3kitb/UAVDQ1YLlmW5dofMjFMsVPHVHJautBTqqFSyHk1oAzWod/Tu79CayWekJqtrze168qrm9c985VTkOcpgZ/" ..
	"CHkg5DRejFGn05hBWpVcaTUKPLIX9VUPlO9liNHhZPQJiJ4CVP7/dbzdPArr3+uDsFz3aUCI1B5yt1ko3/Pr6m8+lYWheJsmFTI4" ..
	"zngVDJIi502NGJWPnYh27DqXf5aA4gWvCT8UIb75C7SzvPTTPRxQp/5WxuVxne+NKjlmDineUh29fcrC14DLFxa3b+UZLPyeaolT" ..
	"rFrAtoG4vS5KbMRkbDIDkIuaLQ4cFZERbR+ml4uZq9ctBHru2I9h0VRNwEXyh3L7rgbTDpl0oiffqMjJPSNtWpukgliNZ4UYcLu4" ..
	"J0oJHVcj2oLru4goUryt5Z25nFQbGBiZcb38gjwBo9tcqQAvpnddepWOV4lvrlArAvI+AM6GgmzugIqY3QcbhhRcQCkcExZ0r9LY" ..
	"mh/m/1qm6TvhO/HVQu7+WlaoZhjWlc3Clf1KnqwQsNtpNHXMqQHnmxfhudYVODjKSi9n5JSxYPDq4lifOmvIjkQki3vGYQqkkxKA" ..
	"8ULLARrBOk0pW8wqXm0x0qnOGf055UGhxwdko+0cNKaggUVa8X2KgGPzhXHXE9kbFnbDPbCpLVEBcILgzN+bsLESSR3Ro4kFFvzN" ..
	"Y6nrO+Tgllhgl/e3e+rSv62hhwH1N2Uu4pWsjDT/LhI+XGlrvtPI2LQoG0gck1jguKy84/N8yN3GCttyUrkeLdkvl4/Ycu33wTWj" ..
	"b4jokAeAh8mtFzX2uHnqavQ7vfRNN9/5E2pfSExSrxD7wdWvU3eCYWuNE8QfVy+fes9wFk6SX6GYQaNL8aTdmQcd9Sa1Hbyr8ZoR" ..
	"qr83z36KyHacAeBTRT1bB9Zzv1T6AUAi55+jslaQQKdZGwkSSGqab/khVaC3DktrxMol3gp4GH5HvMVwymITx1FTvSKK3WI/9nJU" ..
	"g+iKU1CgM4cO7+EsLBRp2BIs0HW5dz7pMejLzxO3CJUelxE5/7rTCkONLpcKFQfd1r2g7hciabbOYx+umVHgmVxlVX9ojXGe3ShD" ..
	"0y/BjGxHOwYReURzDPkHGaK2CIzorLgFpxdFBptUddzI0ucPhwuherUf0MVFHxpTGm+h8jizn+jQ04yMXu/2b79kiPCsyMBI7/D9" ..
	"Y604k2/PX2HZX4Il4Scx8d2saKjucRQ1quKnSdRJAZlGauCrAQI32bdkhGHRYbh7op7QV2A8p7IpfPU3Vkj0CrKWN3sXEf5RIx6q" ..
	"eVAQYON870BUbbNvf1f90cLUka/FsEt1HrRwYtA2Heti9/FoUwjuFAO8f9IxzVoG1hzpSg+raIuslLNruBumAwZ+ouEKjXueCezr" ..
	"smcsB+MagsLdbmNA/xzMlsq6sD04kI6etK9gnoDJfliNH1jMjtFxZanVKMMvaUH6BmGfpql6s4ic3CYgdoASjQDoE+3hNquX2Tav" ..
	"j310bxsanoT1W2ngHD9IoPLpK83xaAvcUdEZpf40hCA+7feVk8V/2zzZD03fbc31dF0MNlFgtA6paCUSGi5g+0kv2tHCKnVueIR5" ..
	"JiRYLgQmnxOJHfAzDvgKApVvJLtM/TTgYiiTPyCkzspQly6SN5UjmteGY/2TEMsocniLT9vrFOkhLHcqF0UkJyL/C7s10LL1Jo0h" ..
	"hW3ZMH5BM1BIQcQppQmKN67/zWN8m83HQGEf3zHz8nyO7yIIvahTS2fM4y90/tt8CLpIvacV+mvWvla61p3sQjP9Fe217GgegG4m" ..
	"CQq/V3GFUmL+7N/6wyiFqbpjrc4Qmzvh87OZKZqIw3EWZ4RComakAMu1Gnx1WZqp8/lL6kYKVYxGBu7DMDofuDu3CdjfSrzsNa8W" ..
	"3Vch/XW+wWOvi32AYIUWpEBkPtxQcSlPE1DIRKg4MkPPL9E38Oqj0M9gClE+jc7z3EypN8TMwuKK2DF4ikRYLAltFxvSbOgl24/H" ..
	"smWkYvPmg/ZRvk+FCDGUx4ecLr9uILcCpIiuaPRL9GH7I7AIdN4H9kzxp1tZICPFZcosO2Prl3yjZjqreFlhY/y+CtJk8kPomHvO" ..
	"A1dT82sQc7ZXQU2dcmBTJUf3yTtIjJon77DBdam68OqxIwgy74pwvx8iNevc50QffggvjiEBg+Rjd+qISLdAYnauEJfrTibwmHHT" ..
	"iZSQGUhWbeH3xG9HJAx3FxrB5HLkzVs/H72iOfnA7cdPz5X03fJDlgoXyhnome+iKt9cpOYyYHlQSn6VWUty4MQ9CkhnDAuUgTRA" ..
	"HG38Bx6x2cS1jLyXY0INwyMecSUmMZ+lj6favqHY0JzZfMYKPH0zHmq+sYQMLqxYa1ATnlzSaOVLDUvFpUEbBHzmYk055MWoRxyj" ..
	"mgk/laTzHAGb5Z086EYKJAH7a/JM16ikyubfwg15b1YLzk049btmtsEKcaj9SlRDwQEPfvJLCfD7iPGS/ACi17o27nGyOYkiHPZr" ..
	"bHSsu3z0vBiSQCSVNVKnS7grTnthu11arbckyOgTaPrRSV5HlkEDqhsUnr93ZmBvI2QWErZQ66e9+QiUPno54sYPJnICqCPVEZfh" ..
	"nzvcbBoNkCxOJk7BFsHSJiWeJppBYt4+1k9ptWO7iyHFSGmeX5puH1zuWdfXANt5gMO87yeS/PuPNOIZK9UMatKj3fEXGjNV4hpk" ..
	"Cwsf6rTsmCssrDChWlihNii2Wk5l97w0Vgx/r0t2N7TRTCZom7lzxgg7ozQil9qCdXpW751VGQ/jRG4CaSnEeWZkZrfj5aHS44a6" ..
	"xAMMVmqGZXAjWII3CS85GVqyfwAErCzsr/Jwgq6NyEnINZn+Ao/bxXNcbsC7ppwg1BNbcaYA75hCMEnVHEqr9W/MT8csCqYYhZTw" ..
	"mcSjLlx9gv/JJ+t9wcmDY3KCQJHqfsu1/ghIcwP7d4Xf/6QsFV7QZCLZkI+0gUWwMS1AeoezmWA0AUBi9NTYkAA1q6IFnKwn3tiU" ..
	"V8BQIQ4W8J+bFvDwkqCSZ/vpQfQiccz14ksx9DnlsOEHBveAK0K/eaK9N9Oj6GeWJjIkIEcv7LiMSLyOBUZk07Ughkc21ILC0CT2" ..
	"Q/4BJ08Oij3XGo0YrZlWZ/Zb3Tzf6AUe+tQBSkrzTlloFiOocMI0jI7pu/wWp65DcWuYBp94LXBX0RJQta2KOBhA3gwmil8Gjt2K" ..
	"BvsR84lcJC7jc3qYC0AC+/MUCFxsYgwO24j8WL+kM9S1nc1A8VQ5ydveJfbOjF/NecXAoUgf1F2XY3cuLCQqCTxLRxkFA/U95xkT" ..
	"QkjZFySGb4jtSTAmIrQEACNOlFTn1tXkCxRLNP4z2orii1eByXCao3kjm7w1jbQEQV+IvSmDw7iQG9SwqalgvxTN4hu480JflYD4" ..
	""
local PAYLOAD_P15 =
	"8pIUhQRIZDD+TRWHCijfNLB2H6bjoBvUgPEe64LLjCO6sYvd1cFBYdRyPqo9nYCjaVWwWED5UZ+xFx+r6U7T7W8xFBO4b7GtuXxS" ..
	"+lSVuF5ZBvmUTWp2fx9im9RbWw9mnoggc/U5zHNJbR3YJw+j8y6UT8eg095EvOzJUM9Y90LL+VPzZsEAItARs5FJHaQ15uWHI4mY" ..
	"Rph/sGVLy8925az4mOQ+Cd889vK65C1ihj2OmDGA+syBLXAJrRBMnSNmyHtJwKM4j31Tde6YzrV/nUI8A1Lrl638JSWHxT1uDUeX" ..
	"6OYjAMAQjgx+ZhF4XaW7Hce0W82OqscTwl1ey1YBpJytUB+BS6CjAWGtYMT11rnnMxA1xq4zq0aa/ztbqjuNHf4lcXXZYhSNevS4" ..
	"KJtGDNYpDly/17ZdYXwjH4e2bFomfnK4TBV2mXwmIW5opXrIq9ASMWe9trtCao3f34j0q4aE081cwrhGhqcJthqlcB8HvVpKDLXs" ..
	"fCbftW8q/qz5gP8ipCiqAsBYMUJze6R9QthY+1q3UApgAKvGSPxuwWk4hCNlF64l3xsUM57MzQcwjkRXjHsxWKs8qRY5wLYEWbFq" ..
	"Px8aq5Sra8aUsZRNYmakIyQdmTFvzBW3NgLzkp/seDB6bY3lgx9+vfaHLOvwshDThvLH55aeAjrXI0eysD/vlsjnc0smJzfzQojP" ..
	"ux0Cwj4i9TQizVFoZ+LNaPKY0ahnnQ+1duuTLLwxeLABaJRoLoDqbBf49YJR7ugVot/UkgqJcyq/+vG0zXJ7WlBvo8KAxFOySCxW" ..
	"ddUQpSA6croJKBE1e4jyWTEsNi7ADlbCHGt0sNMVAfpe5WrGKeWuXT2+k7qU76JQY8eOEIGJRP7/VzmojsTqZ1ij36V6KIjVAeJC" ..
	"+BL/ea1+3V+Nki/DeZnLDNDu7bzvJ7iYAsduG3dM6Uu0R4ienehfZv5yIbHx1N92svZxS+2HKtUnqOT7j2pd5aHyLziGytCYDDLW" ..
	"MvYk3QYmMdSyZNMbd9rT38YreOA8BQcTan1Q7ES4jJaywp67L1P8Ggs9QTMdNV1BwYDrSzDJWBpoku+c9gMFD1SDNeAZuAjimGqP" ..
	"4nIQXjt2rZ2oI6hYPFqkHJ8Xb3hIP7lFMF0hTWK8f//s/h8DxtPx7fDYDTHcW/AcQk4AG2BAZpbPxRA7yC5Ztp3SZJm/3qH0xQQY" ..
	"N+YnRyVaTx/bXxr15oj6Sqln9xHEtC/QV9B/DZUjGXAkbz0SJMcu6MFzZyUo9VnvxZtR8skBnD1hXbtNcPFjqAv+PFBdj7b9AB/Q" ..
	"Bm5q26gb0DWiULKJOnDafnEtl0sZbwv11hXz7OE5zad6Kwdq5sFFVH39wkjaOl8Gruw7xyU3rJsuzFOZA29Bd5uL05lidwE2vyGE" ..
	"DgPE3mpevpNwcI8Mp8jalvwE9rKYR2NACCdRRlwV87896B0IXHDFYtkHztnQZn82TBaxGQI3shVL7Eeq/ZMCAvRLKgZoVfXxPGxY" ..
	"EtLqyGVtppxnUYQOqXeT8s+b6tUiKrcbkAPJUZx6j7FCqV9fX5ifTAgVQliDq4SdtQey9fu+zgt0U5xLLWmHeeMu58Ipwavy9TOw" ..
	"IEVq7LEY4+HrI/GT3IdYiBzchP/84I/Drrpw5GzlB5ybvlTbezlJYSEXUBoMfrUZ5BW47p+hHoaeiRy+6OndUE6eNRmK8SIN9vPI" ..
	"8bovh5RKhutfL3P1MphEGP3c3+KPVrDQOvuhgDOYEGk3rbtuDrutctBXWGT9rP519V69JxzctL+oAk4LBe9j+x4Ibm4jyrcpxCbF" ..
	"PBiYvq+PGL7fS2vgUod7448C8stD8+PqMGBF8PBHCSzW84QppCnAlL270U0hck5/5jrwDFJNmD6k2nuFPHGOA4el8rj8hytlljWx" ..
	"4fL7gMCChgCglL4xGnQCDNDoTnVK+5kaoSw9oJnKdULFf/j02fnU2FPZC0zIGesCVBxivBbeYGRcYIHnzKbUlI23xoRM5UeG2ByC" ..
	"wkt0juUmPCg9XE+0gbT4T0WLI2E4a/cwTj9Xt9UqzQC6K3XKpCdA3TzD0pVv8wN4q5ZGQmfhnZC4b45ZSQL56GA0/8eKl/7t1zaQ" ..
	"zZNHcYopcaYwhOzA/3jOGAAOQmf5DSde2gcLK+/IDavq4L5YdjrpjNQKwcEqNcMmeGFvR/M6PsmwaGf8B5+QVNtapOf2l13qNrAf" ..
	"B1Ri3Sj6T+KaANASsCmFeDG/S3O/Ue2ukQyYW4A9N9LPCEBlKdC2rT1ibShusnjdlVbMKdM5ecqBk64xm+ORsRskpCE8CHYJsdoy" ..
	"7MW1tIXlu/cDaAQdU4uVc/bw9/djVNsillJySkTFr2mA7taKhJ1DRK6QepVfqXncX9Q7mg1N8h5ikWiUeZo5+xVrk0frB1rzUrw2" ..
	"3GhUhTPcpCI4lsouib1jlchw4/1/bdJaP2SPbBZ/bTkDh7nZOZ4uVXZI5+PzNDEhI0tOek4gF2kBMhz/NJGNhDxdDSzQS2efR4a/" ..
	"RtGeBvSIebUJ50HaJGu2RWI6k0XxPJLiiA3OKbPqBM48ndka/ztRnVijQHWEtHvcran73WixHXpNzZmvGSfZWkq89PxS0WT2HRbQ" ..
	"TKJKumK30nlx/WCUz/wMZgoVy6zmh3Bj1XpyTgLEIB5EunvC04n+1rUk7pnw/jYGRyYtl/OdMsUubcmlTejmj0sPGok4Se6X3Pwl" ..
	"E8S+mG2+2QxDOjskaT3Ra+8wvA0OSGbfd8Ml7Ti+7EOV3k/AnsbhbFgGACpoauv5VDIf7WqWeYCQMAO6/bA3qFFnsGnnzCE29zl9" ..
	"pWrxVz8n6ldNJQBm8NDuz41lu67G0V/AnrFm8snePVwDCjYvrn+Boz/YjynJaMDqgcgmNI+r9Bgx6hARdYU2Or/KllnaUQfHj5o3" ..
	"hrkmSss5FTBKXtl0B8dReq66fAj8HG5xFsJogp/OkTz3H9ATPwKl0J4h6al9KMRRWS8kWXV66TeLsXWohmQ0eZztVUp8uhBHZ6Pk" ..
	"IZnrT40KM4dKd+HyxFBk3OiZ0CPm22DbH3dqf0FKdLmrfOIAqZ6LuUDn6Ivp2eXG4QEWyg0mgzarD9g8Mhjnfmd3g1oV08oZi6fo" ..
	"wdiUcgn7LMKJF+EcwzokB49s6085+Z3mhCMZ3RsH5ojr/3ZjbxWUCj+AaMsEdADb8CpVTnKGNsAnDk6M3lnoIZ19fYxfDa8KjXY7" ..
	"Yx1QOv/udQHa/2hjLAjsIuqWcSwLiGVeOG2tiy15jsE8LwvNEcOcRcVXPH+y+POvjBcWzdwOwWFexsE+1Bx5WsXHpXxcjhNvHvkr" ..
	"lxSKJiVqP940/u6xPD0Yue7CV0ZQiZmagiiJBQ0e1e8ysboSrIDCMzMNO8E1HOarTALHDUUBWpoVoeud+NR4naxY+BoAXSFIqZ6a" ..
	"jiKtuDCIha9u2wQu4X9mgmdrIxt4DVvv0GadwJCaHU4cW3DqQgi7/eFgBcpAenp1uiLLSxyFdO9uui8ekjOXtosEuH4Z6zHcOjjB" ..
	"GKm15YGAfSmhvnylv8sxA1TjuQHyx7phSWSfGZscRDVE0fM4DUe0jLMFhorXsxTJlmNQa3HjatvYzm555o6A14todGxcHPfH62FI" ..
	"hVyekHZdV3LuIIqDVFyskHhfZFXwpxOsJMkFVC3kwsKPSFxnFtvcep4y4PfSwCG+RfvZErGc8fkq/S5zPrU37fdq+suffO5rUh1s" ..
	"mUe9j5dFPZ1Bmk9k5cE3WyPtnWKrHKUuiIm8q/YzfjDMOXAKCpJ9RSYuBQ+f664N/D+Gu4vRsqyqMo+S7UTgm38Rf5bnBdx8H6ip" ..
	"76HdR+orBik53wmHbhDg1uvlnbDDQirUobby1Q48j51tBc46RlP3oFsBkr+ql4Udg2+mnKv0TZcficcXCxrEgBiMl5XO0b0XKBQH" ..
	"YNcpnlPxMx6Bap6bPjmSbtteoNLLGvXNJ4rZkbeK58IS3+eHJ5yuOPnsgCvaT62M3K1RbI69hiszleMnSjKa6dXqxPMfYbrhP3Tv" ..
	"svBgrpgFrYn6biaTm8EyrpsyWrqYh/9o9ECDs7B00xhJC+FVaxxiurhJDeW8+ffdUFCL9LjF7rIsjpXKWMDDBX3vXgOpV0LyIuLr" ..
	"X0lb3iKGnYqGpZT/WJAGupAqj95zvqgs8IAPjKopuo1Ybx9eAlcOz/CV0rPgpTJAkJANwM+HJb8SB99jcmbNhdFiM0rWoJXsQ2eK" ..
	"3mujbw/gD+7e2VwAWlHDcRztAtSY0zgiBHzE7YJa567kdj4hJtl56Bvw75N6BqPnubRaJqxR9L206wASTPj+Qy4lA0nxMLPSOzBX" ..
	"dHdNPcbKdXICJ0fhjVAY+Zw9F83qRT7wAcS4rZF1p2byEuHge4qywYRLUPGyLWuvbv5kDDRF74Lka7GfTS+3yxiOfQ60RtO2CXER" ..
	"jx/76uHodyITmK2RmtyHpvavrD+0xqY33uwAuBsz5IRFy57iPdfz0sUpq02s5k3Or0YUpJMCO71lIPPATsS21xy2dT137+Lo5Av+" ..
	"lbNm7TmNzoYWgEVsfZn0m2FqBnAtrx2ikQTzbKjgw3x/VijJK7xEI81BC3IhlKRqq2mVzatarn6Ft6Lw74/fTmjxvY8OFuBgZ41M" ..
	"VQoAyCXZTUU9tuqYhdGMOcEdnWbMncVJ7q1E8Xd+t3XAFvM8iMlkqVCzb/4ob0UB7SKJ8KF0MxPtIM13NfY8mfLXqUdsI7h4eLPb" ..
	"OwrCQJEUrY0GY6O1wkVJ4IvtqiMriDCZe2bqGhCMWSP8Qwuo6IsbLQaLzvBNnXwRX8LYLq/uxORajzBN2pNY0hrsF1weIFuaGrKT" ..
	"h666LssmmYUcbHu+cLmBxV1ySAFUagbSBkmg5lsQ3b4H58TC2gbtTEv2hWrub2FoW/udP7frWLM4dyBK7vCFIk/1siexLpUscSZS" ..
	"tXIgS15sgkTTbGP+bwpFqwU7BGtc2r3cRfxpUR2/ntNYg4TmLzX32MZ6Zo/c5CW+x7I5SmJm3xyiKnn2am6Y/ZqrcPCg7N8haQmK" ..
	"inWqDLQ0kWk5yWZ1sqYj+WFWtcnHsnpavLtuF+ZJKPRbjSpj0T/JjG+1qVXh1Gv1bIg2rgoqHEFeDAWY1TGhIuemUNJsg2QCvbD5" ..
	"C7yHL8pqD6nWZlHTR3Qlx+Hdegn61AbdksVnTby/C69DQ2Dego9wfQq0Ve/LYkFjA0xvAcAGRCYWN27UnGE3iW6QRiqep+8JC7mD" ..
	"DjdNQD0hT92jAqg7R1Mp8enNI5A/rMZWmvqWSyydcZACtVM8KvfTpXAWrLSCCuGbI4HANM83XVmeyNObCj6ZJjUd+ZIYzXzMu81n" ..
	"iPmWSuTIqDmx4xUQGgHpVBrbsjD9DBtFEHhDIs7tu51ly3EqPfM95OqAazzSBTCtPvQjgC1gENvkTTh5Fy0+hUoQQrDkShJXiUD0" ..
	"NjAdm1bo/5qDaAhW7VhYlH9yrc6BATn2cOw9EWcFsT/ujA3TC/0NXrw9rh31B6fH4ljx" ..
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
