--[[ DQFarm Loader ]]
-- Licensed to: GNURT (1 thiet bi), Gnurt (nhieu), 1 (1 thiet bi), bakuru (nhieu), 1 (1 thiet bi)
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
	{ seed = 2456814134, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2450022944, exp = 0, plan = 0, hwid = {} },
	{ seed = 2449540677, exp = 1788089514, plan = 1, hwid = {} },
	{ seed = 2450748736, exp = 1788742721, plan = 0, hwid = {} },
	{ seed = 2451405872, exp = 1788259195, plan = 1, hwid = {"1"} }
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
	"/9ssl2d/BK6vKNG3Jh3no2Feqd2PveMKEFJqAz3IfuRTXbeSiISLTF/Iyv2agM/CWDrcIgbQ561xxi96MjWSgCJueQMptGhTTcNf" ..
	"Mbz3ItI/CS7SVl0qBlWRK6UjKpCbN+9zrrXl5dYQT51xOKIqEyXmnscXlPe8QxRkoMInhxVICV4Rp+YtTOvHOvm5pS+6j0hauJQw" ..
	"hPQLWvPzsfFYXEHmjIZt712ZwBwEAFDcdFqdxlrs2MX5EdDfPYGwue2362w8OYB4d7b0o7UL4gI3192VJzi0PnQS7VaZutgextEl" ..
	"WS6WuarC329PYx/pFJOXAGhmWF4wJqDCPw5uEPWEuI5q6VOv9qmxxDDZcep4DosAnkv2lndx+8zxqGTqEfEl/xLmFlQ39NJZsCxr" ..
	"xBbaDGw1jaMcbVBdfwSGxxGgfQPB+Ac1vC5yVDiHJr1FhSrnYoAETsAs+GXtK/py7oTfPNAcPPQ/8VvSqMs8+/vMwJjaMN9ycqBu" ..
	"77TRibBE1HhqQ/lrIpuTY2+gOvwA+9h+a+V6c8ZtqSxKn6492j3r4r0FqCnkujXqcTN2xUq2NEKUpWFG9d3IxRRHAL7boUsSVPFv" ..
	"zva1WMQQdE1RiQQF7D3jR/6NkRwxaYEoqzmTR8TJFcoL/9us9FSX3+/BLbwxv9wm3piQmzx4fKz5axn39haJHFv4u0vw6fqR4YZ6" ..
	"DxB/tpvw2IRoiRcdt2SJnkmqde3bw1tAD9J7V0NPCRej63+kD2j3ZCVXaH1D95OBI4acmBGUuhAo2gXNCcneP+/YWCmZrfdrjMo4" ..
	"vKu4kLyALiVm9GhCJi+c2FkGqfpc9N+97tgo8LbaiiXZYzibz55f2KIAfZIeVG6VvjOCGyds6+YHtZSnZb3Qb0qPlgkUJgOMl8sD" ..
	"DwwIYgkCcX17TtIV390+kpTogAqqRZzhkm1jI+l0NibnS2dgyvZmhETuqQa6Jcv6bIsIxJyU1l6++1mCaCg73bAJPbVP8n73e0M6" ..
	"UpC3BYmtm9KRXhuY47L5csSwHDKsstSymVFcovHHveAd+tAOlw64V5nZrhzSmLyfu71TJ0W6cMtZrtVYnTxZyWKM2I83levPMUXT" ..
	"wZE01Zlyh0J7ch+7+k/4Vc1RwgyO6x+3srrYGuZoTjJQPWD4G2fKS+3fmmE1F2LUzOJgWgc1D5ro24izrRpfImfimHUgTLkV9xMR" ..
	"oUo8H2h/0EEiKWxp7r4QIzsFaqb0aiCGkXKwIcqjd3HWRIiQkKyXv77VOYhLBhJpVzEZIvd6feNHSwMfXk9M8YzKzAJj07/UvE28" ..
	"+z1frvKUR4y+TyFE/z/pYq+hV/7eSfvbkfouz6DC5zoN4B0TiNthlCJxZNQtzz/ok0+QZZtoamjyni4LXN5v6dJI9AP5GuiGSEJy" ..
	"y7A5ziRCBqAEdpCjn6sR3m6wvXStqqSc9isxLp7Vt7fDtzgwVlDl+XCYdEl+59GHbPIyFJKCiqXDa+OFxL+NsyIVloKcaWt9J6hb" ..
	"zEyiaC94hkyuQDFZEOlT/Si5fJxa4vlHKS82USmJhytsAU+bHyvyqgmG5pXQNSqmxZCp8beUmEr/FvjpioNAklfL8MYAMzgARhw1" ..
	"pBLrTgra7s0/ituD5uDlHeKapClVCcr8qktW7aJP+T8bj9T/P8HQpAq4OyCj/XbpOVe8dlOoL5e5vpGUB0IQlcHZ8i4zDufolbHW" ..
	"LGwHhI9A4A5WIFI2RUJej6AqQvRCrxW2GqHdFyISTcZ8a6Yvbk4J2km3/a09ebPt8kJ6pTZBOEnoOGwSpKEL5sDj/+Ickw/hls0Y" ..
	"zQeDagOdEwUpzf0SsZ6qL45GqnGNXoKRSWWJO2IRiiHg7wic8RFjd2nLlVKpLBe5cGJj1Qv5F7gyUk4eNDRj5maos4M3pa86Vv75" ..
	"dlKP/+3Can78TtrcmKMkbhVS7pP8/fEvkuTqNxTeD2FpoU6iIM4ebuCllQS5BdgmLYDCHhjC9Aq//cMyEWsSuT7CLVxm6iJmfp9K" ..
	"6+MibuLYeTRR2bxrBnFeJwosdUgaujAHM2OhNFALR94xKiTUUIkS+7XKF7/FzeGqpwRAHbqa28WOOceBGEg1z/LZCGQ4pWNf/LWF" ..
	"iVUI7eE01YO6mUVyCPAOEqV6IxMFGk5M3hBm7GBJQyJv6tijJEschi4dzgh6vg2YH+qrOQIDH+7V+wDQ2+T5xoEhnbi5pj+ESphL" ..
	"X5U60qXbCIu4NGo2qbQycOFS/oT6crsBcaWt3CcvRrjY1sL5YWWB3dyd5YavDhhngj+ckGuN9/33c8ZPCz+48jIYJC/JVGAwbRhT" ..
	"SG4tfATPAfIo/oCuph3Hu2zVfjdV8d+exiL8onLtFozRs979lYCsUdCLhisgDADdoxV1HmAJzniCVWqsteieXnLyYjFKrRuW9ff6" ..
	"7jDLkdn9/PnXqGtcMwYoSwLH+xndyVd2dgS9UAunxinyf5YXk/4MxB+7IAR6kUh7BgvcLdiiFWlQuzrdzFfrDq4yghSv4m5J+/Mw" ..
	"/sc4btzDcKALlgwnO0T5PAccpj37z0TZB4EIGi7/Ux9NleClLXAwrApvResTBv4nFb0Qc2g2F3Dy69WZU0wx23sepfugVz0h12Pk" ..
	"MN4N0m1Bc336ZvcPHb2o9BO2bPfLXEexg/ByERxBqQogRNGwAM7KGMGuoE13VID/BCc5oNpla2X3zGmrewqDpkHHUzGqeUz+5Lte" ..
	"xHjHfUya5q+MyL41rwsAAw4VcyTwFU/Fx1Kx8TWjaSPNuiqiGnslFOf6olQH3hj5JT79F+yrvXjNEzcKYkiPaugpZUzun3B866nr" ..
	"km3nkyk8RGveL7cv5d/AK8nPmgWcWTpIvSHmz6pHXmIZrdPGTioptYq0yVny9WxGDU0C8vto5g/lHhU6bElwS8Yp1Tn2CPptOl2Q" ..
	"aiLAz1Pef1Ya/s2H2FZftK/tqJI04sQ5NVzgMoTWCSNwh92yjesn4t8l0qkB08fpvTg7FdoZNOGouu2YqivxJ8NpPW40NOIP+Y3C" ..
	"lG/w9AuzFgBZwl7G96MF8mYRCdfAqm9b/dmc5onM9d1APP4NzN99wtRRLD2W0f/EZ9vNddcqJhGATnkgoC15P90Se+JWNjUyEVMJ" ..
	"LODP5mPS3wTdbdL1NNyn52H++Oy42HOATx9skDrj0il6wnsHYDc1smB8k6M+qNWfKmkr4bjkonpphwAQixrkM+VogfV9SAp9HY6R" ..
	"BOesC2r/gGYLFs0UHMOYhPcYY7DjbKIGAbyRU68dz5bU271zurnLM9VNv5PF0ZAIrr7cgiS4A4C/9/ah1KsfnZM5KDCgYShku4yl" ..
	"cDw2Edp+avTLV01vYawW94zW2mMR9yVkpJiDbA+RBgoaiF16YZK/jZGmczv8ET3DBDZJBcCSFnwrYJVsP3bRp7OTzT+E5nD+AXtU" ..
	"yZey2/dULa7xih/ADA70znk4v3PDVZrGAl0c9+SvG2EHN2xwEpwmbaL28VXRuoNxAxCygcxNf5N2/otq1wl3q/IzHYd8jds5Levm" ..
	"e+u63jI4kJLDDQa+s61Fs6NlLqTcmzcMAq6Cas4FgU75rp09K/Td4hhFj695g/RAD53sYxnItZqzpccwVJWyvwx2FUt7NhzyhUFs" ..
	"gmYVYWJMHdGtU2GYSla1/VH6kUY2JBJ7NGLHCosxUk6U3MQp9o442bEt/fYjYfLVfS4q+ZoWzrd/Ey3Mw65Dusf8/Mys7Rk2kpcm" ..
	"aLIJWvyX5kXuzsD/qZ9NTq8UGFe2yNi/3Vh/hvWLhe8kIqjWsHP1wC6dVGJTiMvh5zBYlrQGfjsczL31CBf9Fw6cHbNe4ys7cpWN" ..
	"fVi/HlIK/jhb6+f24suyIY1qB5NtaYPvLq1NK2fX0tJ/B00bACwDBJhP8b8R4TQS/RR+o1rg18HQqlnEYcIStj7unuse5lJVSTYH" ..
	"MB2ZAZumPm8XueD+kT/pLuKxHrum8F0l69DOC7jxlRdAmsAlWTxXWgkaTDdmiChv7Zli8Dpfi8kk6G/8r9GFWBEaIJGHTqQnns62" ..
	"88APAAYCmEYzqmTNWB2wvOoXRyKnD5OIaRjvVyR5zA8yz9g5L2GmzhyfDiG+StYCnSDJNmU2w08YJQq67drMpjWcwjUzXtbC73Vp" ..
	"I/WIOxFNtfVblu+kBBAu61kTkwYam3RCTVaW6ryZ6YPPZvfzohCfjBRjDOYERhIz7/nR6ET1ljw8AV3ktqCFgWhs5f+6rbBk8ZC/" ..
	"QzHqvnp9myn45e9cZtRRqQ7r4uIbvz4RJmg50ORzQQaJ/+Tw3PpnMkSJLaTJq5+whAzmIhyB27ui4FTWfrl3hlE2JgdrhJ/YWMsm" ..
	"bUV2GSzQeSQt/tGpngumpe9QjG9iB4fy9x8m8bRG1Dp63CxurhKJlMpKXs6qsjnBv6CnV9hHM9hs6oe5Tp2SRtpJR9XbsDdQlO7J" ..
	"DrQZ+jMjtjwCk5Pxbju7u19Sig3zP3y5lIsUzFr05GcQ/sJtnAi08eEwEZf2DVn+9kicym0UZwmpZQ4QVqA9YFIo6PFTyCqcYHQ7" ..
	"YvFnwNgiscRP2Q9esqk8ILSN+/KP2BIi1J6rd0NXPHjyoO5Bx+WutrUcUOAggFIXN5pQ2OHu7tIAfJ+w1tbgRgULqdsLlz7CDSik" ..
	"kPLIFKDdXBT9vmpvRSwdGRwOUuTjoGHc+IpytY5Bao3YOm2eWyFQv7XfTsd07mcpwz2qrbxZO/f9f0Z4ORiippjXTVyXuMAWCYXI" ..
	"tMkElYUbI+SKHptuYUS1apeiHEiWem3QIyTrHTxYond7seZf8mr8w/PNxDnKxKMh+AlfaLawz2131yIO0nBrpcjMBOJfMpOd5CK2" ..
	"ns8vtnEuUKJIsCzKNE49FwpqSOyq+nIB9okq3ze9LZjFwQqoQrmprJ93RHZt/joL24hqkdpueeOJ/xYKYqfcL9fOKejNB/irl2gf" ..
	"JXXQV5EQILSuCW2i5D9dqVVzo9h6rScTRRcjVmbHbvYG6MHJd2uJVTGgu6E5Zc0/RGFxGs6+B+eSs25adPZKk85KvAaVKnGNIniP" ..
	"PyHOlw5A3hokWSApQHLZ3HbXhhxI0mZopROgUeJ40jUfmtfx+7L0bgo1gyzOHtxWI8ORVJs2WR4yMAbUKXTIkeZjpd+AzwD8o5to" ..
	"nnPeRqZ7kIyYiOP4uM1LzoYgq2JNMOvDkR81v6X3UEjbbAY+3mJfwkARLza8oFH5jvFai0D7Ci07nx0bnZx7AMmzbaa9FiJVbK+p" ..
	"2qacnf/BO0LohL3nRwVfPaaon2bD81x5TmHXj0TZhJ1NX55ScQZgJ/h/BLHGFCReGFsUBsQ+3mXU3FNiZdAorYcR5Dju+zCEV1By" ..
	"IFgq2dAtgevxt03ngxfD09KchAHRyRYF/w41QBeMm0FbdQIJSUxdAnNie/ra7uG3JfoDeT8gurCMQbMUw2/lvKswRfwmLLrAQ1gL" ..
	"7+U1JNQ9i+zEUEC1ozo5D0M85IUPCqPXTi9/MXh2h+Qdv7NlwhWjAeywwMbXGAYQPO9AMiZ+lozyNjnHVVNj0KqSFgG3TMr9qAom" ..
	"LfiAMz4xMvOsmdSml1+dDOL4+hgeN7ZidA/Yt9X8uJVzJF/0yzTUTX7/2Lnn441fYCunlpmT5kPbXJmIze0ZLJof2DQGjOuuJpZa" ..
	"c7mFU/a6qbAFW+TJXX0LVEjymeyE5GWdfFEpHR0fFLQy7oqxW65EIDQrujRVMEQS2QpjfnTHhIwS57LWBg7AoOna+g7hueVbvDZx" ..
	"6bnBsRyHLgyd9C174FIhvLRC3j9MogWB9CipflJ7B1bCseLFNFkaKe5NSndUnfbPLLimn2HJ69XxeZJ/2r+lGtYA16SMDbU9EQCV" ..
	"Yx/30ITaUzrPqw9bloFgcxTFJViADs/WGTPi/FKEYkXTQHq/BZDfceawKaSYKqOOkcqM8COrnfIqeeRjLDlqzuhra0OXrm5NIv//" ..
	"snELNVfqwB/a6TXldL6SSUzcozYFnd1b+gG7gdehMcjytoUhqnjF3xm3u7s9NNvSxrIPZUaUakSRJE1bco7rPa4H3XptvRAopJqY" ..
	""
local PAYLOAD_P2 =
	"jWCZQasVBbjMk+/r03LWSUAXHJNEqdl2MnCd+xlbsCmTzi5X/vsBh+BuQSuhCcbDqG4oQ3RQghI6DhLIKx14P4q5nHhD/tJRaCVN" ..
	"vA3xCHfTTcgPqiPrLEij9XrHZ6WqJv68tEk6L3NEeuvnq98ecDtR4CIy2/3pQbDLKZdKcJp036Mr0u+GaJRcMaJlOJwzhITxZdsa" ..
	"6JiYSgQ+sH47C9OAWyz9yDx4Xz+p6J12IkOokmEuc0B+d461mP54UTS0J4DQkCXUldh7yHnr8F0wJ/vNxnGoiq7azgOzgYPesTNC" ..
	"83sc6r95RLicHNsC5cZbfKhxz3s61Fw2cgMrXT66elvW5IV0oH57chMC6nZOfjVPIcxh4C/iGrtYK9OmhFmuDRk00/yEix014bq4" ..
	"aHzCVt3Q4khVH1NA7goyGtAbNijksoO9WFAGne5YdFWlWiaXK3hT4Qjwy4NiP7q37uxjOFpFSa0DZGFlzFMzvIRKVkppyyLnWFg/" ..
	"jy7Z8BOUtN3QULDuON2lHNqc+hVIbSJ9iKmwCe7poYLgQ9RrpmB/04AjG9BPRBFIBmr9IpsnHBEPMzuq9ZJVE7aQXHJ/FQjDBiXO" ..
	"qdNrr8yozNTl14tS4deFp/m+Ebd/KreiiKQf7R3IByb112ekdd6E4hQdpRiYAgJcT0pKANLVQM1CdrQrGRImGFiD1dPAKAyYQmap" ..
	"HQsZhek93lxl9qiQII0GUtqARAvegOCRA9YPkRyEO4D42+Te3KpqQXZ2MMsRu1m9hiNi0bhhqbOJ1ZEObbm7Vg5p3aaUyAhBjhMF" ..
	"UZ/VzoBafkoD2i5t2gcfr+Pzn6frmnQYG4ylVAGaiYD/r1nr7hlkZHsXeGm+pRUBm0/DNS4dHYwbTNS8St8CRFmzCQxbUlAMU66r" ..
	"Fw62qCxnSoynjehuBhvcQFaPl5G2GTOdOQtNozJox/J6gHswTRTbeKbCigvAjYwcgSswWGgSV3fRI8VLYwYVvJf7ENPJ5wZN9blL" ..
	"8LgKmfB7ZRQv7F9/Jaq2ykUkiNvSy/v8mMm1Mcu3V9QfodEA8X6o9LFQPgoZo2eAIRxNhYyfDGzTK1pGH+7w3tU50dze9/VBfGq5" ..
	"1NIdargfzW61B0PF0lXd5gQZo3F/7iMMpknuZPpbGwsFYqB0Dhh3eHvUL/gYf4AmsxtBFfgv3lHb53yZupKc5d22tAbARRMcPFYo" ..
	"ah91RKQbO6SskphsMeyYbGC8ioRoFwd/PW9ermiZAxi3auPawkv7n9FvROMy6+KTuwCMBH5cSe1AXO8PZB9V/tpPic5NfSkIRDwV" ..
	"bUVAeVRLgU73vP//PzYPwRJj3/R2md3QsHIz0UWQl3MHiQsvCY8Bj0G0ebI6CNzfIP2HDmbnNcBog+bRkDwWCtSL4dj3a9LqTmkv" ..
	"A7t7sfoHf9cXYmUmQrlzkvdHWDSExRlA/4H7iuIR5thyuX+JjjzZD1XJnSw9K+PadIejgQoGcpwBow3xiKMj0EwjZ3tHrbEqtpyh" ..
	"lOvOOE/p6diPg/VDp/OY52FnWGkVFsTebSc4ohEGgWsVUdyIvk6MAIHQ7OrduluN65pvFYs8FPH6LKlSl832upVb1YDDwaaTdx61" ..
	"xRQtEF7NO5wqV3qY51bdI+k9AYMxrsOOED+3YMJjX7hquUhyM+osGbOsSXS8wuFGtBlSuxTnIpRI0X5qzMJ2+j8QmE3w3jyiUBIt" ..
	"S2GgDxF1lJ/VK6W98BjOowiLv2RJBswgrkFNTI+3ywPX1+3zR3RINHxp9gBAUfJrpm7nid6mmNoN9sp49Z9v9EMGiWjXxcDtYLmt" ..
	"tH1ohSXBhCZhbXFdJJ04KscoXbOwf3tpIXUigCZZCed06ydQeA7Esb0ts5lAjzIKbwqQVhKZpcbpG4YO5F4loRkqyOQ1M4Qc6uYS" ..
	"2Lk7sks6/EQSNyG7R71c3uSfVnR1Z5e2exy888L4vsZyfNoxwgrtV/zCbK7f5LrGapDJhRtm5KUoNKNsfNVdgLfUFx7IG5YeQ0T/" ..
	"vyfoGdwa3mADWDdKEdYtSZYS3c+lfBhl+Gfwpw4gut9A4aHfNj7jmAvlkBayfTKuSFKADuNZTOsbnx/zalLOAJg9lyunxXhHvrgI" ..
	"CeA3Z0xsSxOMSHDQUZaJKxfs57T6Sy16OLWsE2fcvTt5IVLLyVpLYPbzRUmRxAHYcb3id4G+tbeSi72fnmLigeGV4yH0x6Emu7N2" ..
	"rMLvc5n+D+s2XcM7MGzdw4jSKS5Edx9aLl7awJ30B6DY5fSjKPj43mDnfxlPbA8XMmW3AibizcBfwXOthStqltKyYAC8XO0G+PBG" ..
	"Bl175Dukt1w9v2kDxdR7SQJHJ6YybP+/ofN1ClFZMb3/APFpcjW3dPiWN+DJamyXIJjb0SzKkcyhAzquMUiHwn+IYl5SuKNfica5" ..
	"F61U1Ke0xCzFHsYgx8C/4T4LfUGTxBVFYFqKbJVEii6U/a1+JCIxHx1asY9heCIdlKI07tDPtP8Pw8OPDO1RcLTC8fdutwco2V0R" ..
	"hl85+hL8ybhF22AAHC7IbCAUrqLQ6kl/QGmJMhO5vLMMn8HwgeQLlOufW7TZyd/xxgx1ltDglTPwB9xdubs7J1B4bvt+VW9iQjyd" ..
	"ojwrj5zfSH1+b5dZ0+fm32QdRj196U07IKZiMd1jSwE41/Ky+NYATvMwmDOFTclJIU5H3UrhtHaMb33y3eKkMtrBxMZaylDrRP3x" ..
	"XK8tgkBTT6lwcbtnYMufwkXO/HXxmYI/TZyCoiXEegw6SVNqIZBs4a2ZFKfgk4Wyl7hoVdXBGWndyTqk9rlw8yXQY3U3U811ri/h" ..
	"mzqSLJ4bjBCpctP6/xEcEt5Kq3mCjRe0eSh8xigsTuHSqPrGmLBkjYmSZTjXsZ4Y4IRyXIm0KjH854w6bNMtAACJRNWOQHn+KTdM" ..
	"quti1EvdFus/9ieC+oLCu9rej+FkzVqxzgwc2GZAdcM50XkhQFtoGx17w/BQ+lg8wMsCUWO87NipcH2plra8JCaNX5xVJmDYdl3N" ..
	"hoEBgErvmLCFtEu05fHOSiNldasRnS6QTNRTma7Bf2RAe6rp818IV8P2+Q5UmXbTYhXCZciIv7i9jfwOlnI1MaIsJDenf/nRdMEC" ..
	"lD5hPJuHmWWugJB69eDtjhuCiwk/BG3SNEjKNv4nlBnri+S2xRWLpUeFpqd3SOiU/kemTi3RFFGy+77r68QasZf8bIIM5fxmfkIJ" ..
	"nmDh09tCBVzgnH0Ajb6lwLh1JZQiAxx1dL/gcKPcKJeQ1gfNYBY+0CHtQ0oRBdrT+R0ons+aVsisHT+hL9ceyO6JxAVe/jezewRm" ..
	"Mk5PKMSGilv178iDGsuGLnLHbaNXcyPRt9ZskuQoCGawSvMywfzPwN2KHeg4e8NEX4iSsFQX5bqHGskhP9noJJAmx1FXFgBbjblU" ..
	"FqTJ5N6zzMfql/vnT8WkVkV9uHwmhaMxJccLagUjr/izDK/F5P6tzVCaEqqZS9AVB4qQSAnypRYHxHY62+sDtI0Xy72U/zjBNHpB" ..
	"p2qpxTmbyRR+zmvjWOyo4hFUJ6+FJUYmyupfRcPms9TmxSlpBdbNRxNBlQLX3dl0pm2HABPvf1mPfRFybiz1DeiNDjKOyzZQhP5o" ..
	"PAhrkkrd3lFipcZUXQ1qL5FdqUsiP1b+FnLs+qC1ifmK7mUCvYwKQeJB3k4WPmySHl8l/mKqNHTQriHULUlDUUb9hlNpSNUAkf2T" ..
	"u7oQItP6H2ofDyF1b598pJ3H4es0wx9lgB2FNK3UBsUsCytzRm92f1MzNtq3H8J4cbxUFxLS5Y6CZlkgO4NZuaBu2C0ohRHoiK+g" ..
	"kphgDcENW30GH64Y0VeWIyXhP7bAPAnYHRhbyg8Z7qitTF0+YWgXthi++5DXhp08F9sOG4+/a8R61GwcqL+i+1i71jdHoINiyhrv" ..
	"cgATQMwwaboTInLYcIm26X2DEZOUGyMD9uGGXIVBZCGQL8Rwj6wh3DxshNcAdm1EldyJ9NBzWWQ0gF9Q5dhKS3Mn5+W34d2OdnXD" ..
	"KAxSuwc1o2AioE08bov4Mqhw76BAAdaaZHG5zDVPh/radGGlC2pYkAAdBura3d0lP5JyWOAoiRkiuq953Ic6AWjOZoHj5RmnP1kV" ..
	"VpYiGgSrZGF1dfCAwu2M9TCMBzEwpp5rQ2JzUWyUQzkk2T0UZVbWmGdlEINPurs3bDLNjIPIy5HpNs6zk6El+UPaVmTQZtRQtLYt" ..
	"Y/++rtlg5GYTWVVMEiPV6DTcGc/yh0UJ7MXbgUYbok+v/L7shm0Z6vbS6S9edTX8XCSbpvnegEJ3xkoSzrlBDqiCbQaofyGQ3I3x" ..
	"3/zwtAJGcuer2CIb8KN+q6Hj4REGXQbiYIqlEVz0Njufm64NNOD8gmpa8tYyeui76v03ZiyXFd6JBtbrN/sGXHwLVWh5YfsLcnWR" ..
	"GB6b/US3VtC20BGsNmijlv8w/zNKwUUroAllz0EzdwjuvIW0kFVotaTX3WW3Zsxy3jBX76c5ps5YaGgP5/wXvo+xuTDS/YvbOYqC" ..
	"XUsrnIEAXpAZbjxDK5wa8jany0F+s3CKiIM/77C66fuLhyL7VdPjlAawz2eCTmWMAbdaj5KV9D55WA4uo67Ip6X7kTNKBQXCcfFK" ..
	"gvCa4xcY8VwIefRQTvyahaxqNfwuOqdOB7VHnoyKHQVHlKbVgq86VoPx2Q7bvkeuYKYgdhmp42VThBBCaynOI3OO4vIn9sKR6DNS" ..
	"kP+eQ6nHDCn5C3RlPDDBjznBOvzpjIheaLkoYqxdwrBoK2VMcxoEKAQikGY5ZrxVQNktdtWeb5DpM2Rn2cuKVBFluLZ+m14BlNv+" ..
	"piLMT6Ma2ihDKephwRHWeqmTD2eRR25V2wa21mJJC/laPK1FV0ya/K/XIKLeb5t7quFTAI+vm7cmhQ/r3n5UQj/euaY0RL69DT4j" ..
	"uH7Z0w4Tr/JB+I0r795XThY4FBXnD6szmsKwmVntlTERWuhKkBhrJcYvF/oCJXXHIdC+Qb0kYwDqV8MEk5ICWbCI1JByBt2+y1Xy" ..
	"boJBlabXYnpN4EY6Ii7+UMyXwS2CYpd55ijbGtKevOuAHkTFiLf+T1Zqol3/qJYRuksmCqMIGHjiwi9vglWTmyOincXjokBu9hG0" ..
	"mWtB7lBlDKCROGbxwLlQtayYR7B/0bDU93GFd25wj1hz7MXuEPMWO1nxdFbqG62Gv1i+g3PT2jnPLts4Pl2lKt7Jz6t13M+0saYq" ..
	"khcbrv4lvi1LhMCPFulo0lZ1BgOEI9pCRNX6CbHCCDDyA58xzZSKgb6YSJff2uvq/FD1PaiFIUVzLpSuGDLlpmhIQupzlZ9DCkcW" ..
	"gsQIQAe6yM1TpOHSExOrO4so1MckiuddpGvrGrKZA7jzbM2GQdJf+Nd56BFWNvEDfSETAJrS3PeTV/4ZnMz43lufdBj7n+9+i2Ed" ..
	"Czip9gRgZME+boUBm4R8WjYPBmwoS42HOnhEdImZ14c/8eguRhYMKh5I9RHQiBYe8ffT8g5RUh6R0ROFVfaiYsLCKw1B93reWtU0" ..
	"1JYI66Snm7G9Tk8Da+SnDvt/BVhF01gvxQtIg6Zptp4WV9qsTf4YzSQTLNATONSgVnPlbBG4ky5a+Gf+cK5GLgagYDZU5UKGxTvG" ..
	"ucKJwExY3O+ISrNFHFR58nZUFTGfpFTSEfn+4AhATt6ececCJysIz5VKUJOgerFggOyZcc9FcPjIGUM11jSf7aVHjRy86FZ1s5mt" ..
	"3c+f/607wIPIlNpOVoptBYyTchmUli7Jiu9uIrSHNmkOOb3UgiIL9AyybaY203k9rIkMvXTMqXDR724nF7kMNgOF6iTPxpzPb9jA" ..
	"UJaQ2D2njzd7ITcSHSrMfRbaZzjjQjHpnR+mhvJ4aMRXBT/GX2w9Qi3BDODy4AxZZ9Pc5De/bzKSFgkbBfvqo7C7T4381djDbrWz" ..
	"IQJA11csqPhgd2QhEl3cLMkQH5S1U3uXUaflxJZdY0zyWGBnIeOKbpmFQ+J2p0wQHMOO4pif2NpXpl+viHpOGJRcIqLtndWcxsxI" ..
	""
local PAYLOAD_P3 =
	"D1QM0X658EYRvD71WaYGyuG76mMnYjOmXq9bu/cwPO30726QEznn2IMNp2PxcF0T5irIAGdNjgL/JDf5yNZ4e/QjufM4fmkB8PAQ" ..
	"8aOZooY3mr2jxgOnR5sYwlyuSgSaUYabYa7bof9WU09Jn8w2ijOn2moxhVGQfI0Yqi26q+XRrE2SJ4ug25BV8TnsQ0CqGLMvLzwy" ..
	"z0E4KoCITz6QWAGy/DVV6KxZ+ADJ+ZHxAHblhAmN4oSDPrF92UHvxSOjvOiPIlrYPaZG0EFzq0TzeyEkm3QziDfnzlEOA58L4lBX" ..
	"zoG1/SRgNeCYVTlcoRHQyw/qrlA4JyPl+co1Javoe0L4Np+cVYcGSt1xWCGI8eheHTPex9dprGCqEXX+pNpZlr8g2HbaOwi0SLgv" ..
	"5C0h8KRxCj2ZxDuLbXaP3JLGeGI7QZ7hrR3v+GNyxiOewiBrTCCzncKISpWe9C2HF79kEK9mpfu4lXZMRvkQbXP8c/mUeJagao/H" ..
	"kPHGlRay+UOuEWI/1MTEKhZ1Denou5r8N/Q81NpoBp10urgoMrnkKMfJgl+8AI+cU4xPHiVT4dfMxNXLpNL7mb1f+Hzk+CpbeqM0" ..
	"erOekJWoDseTrmFScrdxj3iwb0Jvh+pKhZIQzvq5A1U95fdCDUu8HetCt0w4XyItcLJkAlboO2k+adKQMM3fMdzFPFYn5TiS4Apa" ..
	"qdFLwtS6OJZDjuYiG+DC/07NqkVmbbzhihb447J2nUo+ONv/zE23oK9rxSt4QTrx8xaqMxoJW9obvmEKKXyEWgari3YCaLrUXBau" ..
	"r9rXCSjSlggqcG8K3pEsQrDnkfvEL0Amoh8QZyAD5aJGzRvrUPaeBcjcpn3W6wEjL5kSggIE9HFYmK23RwKERUZ7Y7m6z7edFkDC" ..
	"PHLt5OIPMXsxmI+z3IaNvCvZY8ZThgMQQWU3DHViTeg2ALHKkN2AJUNLypPGBQvZvtwblXTy/6wJ+kXtz/tY/4o5GjPefLICpKNG" ..
	"oHUKnOqmPhl/QBzE0sXpK3vyJZIVuq7sNPEZkoELXrWLnXtzqP3RVqf4x34KQWdZfvN0HnefLsItTcLLNlZfLraJN0FDr8qSqi8l" ..
	"lN7wt5s9TVDcjfsO+h9jcGCqyPUXyzR9dB09V1Lq/wkSlK50u/cpuLdBOf0LaKMK9WbnuZOM0Dp+5r5Ii9F9/MR0STMNdDPCik0W" ..
	"IXjOCJYF76PT7Z6+pBf6nAMKf2Spt+KOa7MWGmh2UINXOPUdCTHEDMawx1n7kfOjHFP1fIephw3SYFI+q8Q2avFMiZowHgPvtSQZ" ..
	"NO2K+uChyJcsdTZ/OF4TlMDbG6w1pi1qbUYzChVJJDyFK5GW9ijkm+z3NTZFnMsKN3qdfxeqN2lKrTQWh0JGbW7ot3LAaIiFGcBY" ..
	"B9ZnDi0lur/zd+pr1cMSM3fbbynlX76ZqSq5liPe0xPthoJrp+i8Ec8FxA+wlhCFKEPlG9RHmnyJqQ2alMFdpIkVE4OP0ucZLhD/" ..
	"N288RX85FQDDxpVb09/sGLOrsmB00Gwjha5ZmoKI7PniKQoKUYHBmI2l9f1nO+2Z2tyaPwpeRnXL9TR4GHsw/6jZGRMak2B+DkCM" ..
	"6D+pVQ2hbu7ct8okIa+wvy+ljXXgz6ChGv+9pdE9qVsuvPOb38bGT6x44WtwuJX9DFyqEbJfDIz7UUHI57CGZIbhL59jtj1SJjUK" ..
	"n2dQMowsEMeFG93HiW3fNIIU73qPvirh4xQxtiSCiaiadx9Mde5StJVsvQgzdnvsaGAegcEPtz4IOtnY5jJW4DRjE1+Ww3OggnOa" ..
	"GbP/yF41XjVchssRJgTnxFmUSntIgRnJsv77hFvKPJDrZjAB6szJqZ3RUFCGDykCSF1iuV3XdcLJLQPC9DBXi/VVVW8Oug80j05k" ..
	"YoK7Z8V+E5/O84s0gPnSFKIr9sy3Itjscqa3Dw0tv6XxXj5c7WyqVgZ7lioJqSczcPm+6lLraTdH2AlEhpQQv0gCsaf7IvAYOfYY" ..
	"oiexuo+3SgQin8aWI14BWADihTLSKKs69z8rCrtfLFzSE5XtstRZneT5DZQXPO+3I68FQUI8yBUaCBWYESqk06YbWw6RAms0BYav" ..
	"XzcyDPRGO06zil4qNqoXwv5YmQHp6TlO5Xt61J6KZzr4gTq3iW+gdCL54GQYi3I2eQtnQaLAac1RARtK3a8QI5ASrI3pMSaElVHx" ..
	"B8pu6yvI6F+LHmG4Stp3xO5iSD/fBMles5q9B1Z95kinkoI8adtVIXlbZFN/WU9p7mtUe0avUnc8054Ts79WAnQ0Xbc7Vyg/QKxj" ..
	"jFJpA6+Zlhn83mBGlPLvAGx2644/QHo7NPiecWByxzoK+IhqeDNTsoKmzY4kwMO+ECqi8a9A+JQRtMYOCtdeUKW0mywzaYV1wr6u" ..
	"jpMA80kV8LyME49HLEW1P8W3kXGFLV9tC2uCbJBHjOo8W2IfMmVIDxSsBh4J4YigaX1foecU+fKFjeBXOM+v42Z+tiD2idehql5k" ..
	"bd4UsZSpHKRPHEguTZMNfVDfqdxyajMPk6fuv8EE3o5nf7vXqFM2Nwuj+vBCiarhgbU4W5SjSuJXDO+SQ07B4R34+p53TxdVblmj" ..
	"5hy80Et+UzA4XJX09sfNIVviK2l7+m9PMXO/1MtxgbSyFxrSQ6LsrJKK/bIinhiqYDugY7aVUGLJTD3GLsW3XUSLNm2+UfRuCq+A" ..
	"czhMjIbwOMi6HBN2wL4LXK6o96ePHVXGBFJkkAv7iMsq/0hawBM4OPyDVfLiANyBDbZ0IWvS3w6IAyY2xeY48xPztpXRJAMSBTs2" ..
	"f02vS9VPt8Y6Tl291dfpyKMJA5CSaXwN2syFyoQqbtFyov3QeNgBbVVZ0O89twIUyFnG7IVVzi6HW+3Poc5GpH3skI+aZlOJtML5" ..
	"VitTRoZNYsiPCz8RFuYvVgTj89T76l9erH5KNmN+vEYb9yXeyoIj0twKpjQF2RjGr1I9GXSJvrKsQLMIk5wgeFairRn2U4KIfkAz" ..
	"v0tuTtNmm7VJ2h1OSyQlzsha7io562MMnCftM1UZVtdciEeyxUZHjA9WQ5f9JkHzBvbEZJx8FQzmJpVn3KrTnBXzzLtFjhlHkLQZ" ..
	"EwoQa6Br2ryA9I2y1E8StEpLHexbdcOncRwpCeUhYeOHZSdnoFTIPqou5S1kjL7T9wlCbfqlJR8jYtzxlPbCKGnkfgS+imtKe/Td" ..
	"CvOReU6e+nEtoWEFCSS0ZidEFg/knF7gKxjqx4g9h12Ss3pCWNJKa4lGq8QbnV1ss1h9fjG/vinmDsG4TWKsXSPpw4zUv3WWK27h" ..
	"oqpz35csic2o6bxwF5tESvvGoBMen2FKuCkGGPjdZgMYEEcoSpjQKQSb7rHFJ0D/L+kJwmNKmN1MmQYFSy8++fd6zom4EM9ofZwy" ..
	"8YL78L1BVwnmcluhPs/DZgXkDLQJXIofiH5rsqdM16oh2XopuOlPgA5kfKElMhMFVSotWXZs22j2odqR5bGJdyoY/it7QY5dz0A2" ..
	"YJDGj11Zg3cMHwklRSMk6ihBPqVCQI8DQ7aJ/3Ym7+4Wz6tUGM6NbTQh770MTbukvAvRxlpJBf+KwOSX/YIvp4B6HaIeC6iCa5fh" ..
	"Xl1ia45oVa6othJAVVjbyf3S8xUk6yFI2j6yxVTpaZzvTKDkT7yAhwm3vADTaGlnjjhbuEZKb1Do9rpHP3c2HKf2jhuwwTFzz6fC" ..
	"wc/dPy79k71BhXhK7yek44MIYvxUldN7LSWXsHkbI8GbsrZXkKklZFFnVJKR4+9+0H2W16SuuHU3UAnBdeVvcj+npYQSZWX4c+I3" ..
	"wxF2etHte5ZbdPhR8luVKNVvNA0eQR/qqgfO3qLqqLZDpTjuBsqNDl/eC53k9eicN0E/eHjJnu59jEnbKtYldYQ4dXajNK+2PrLE" ..
	"b+VlR+uZIb4lIcfry/EXP5SdHAVJZsE0553msvYyx5iv5ictHnbtm2aoLDT8NhFtT6VH7zWNk3W/A0g+ZtG/oyHIbBNd0jpd0B/i" ..
	"aXj/9YiclvM12ljmGInEHX+uRwa+uLGYx0Y6DjF4TAcoEqVMAunMoyKXruDDzEiHwLtibk73ZYY3J7AnGUU2DOCKU4R9GyWMzDRQ" ..
	"JpeHFNOmkA74W3Nud0ls24d/8d6dVbUB5zEoAoDrrjWxxBNRy90Hfh0KW5GsOebbLdtKqp5025Cxguyken8swRzoUSBBRkz9h5fW" ..
	"T/bX7KplIETN+Pp07u5Gj2ZyhsEAM7z8aXo1+/SfscRfZtw14vsVH29x0mYnX/fzGvx00thqcR9+NXnp+3WrBOIhBxC8Pn2Bslnk" ..
	"u93tP1xOO1gObIAqwFRza8AykE/XjR6CluBQ/eHB/05WYckTL1O0C8akRsUWBNGMXM1sxl00c0m0/epsJRt6SCkzyf37APKDuive" ..
	"Ja8jqvghVKfZThIZNLypYOkhVnQDwtvZXVUgWEpkd7cY79s5srBE9RbIRaT9wKsq8JIQyzdFqI8RvcqD7YOV7FzQ55VoEedp44MT" ..
	"ALfxKZw31138/w7DcTpg4wqGcA1xFLAIEuJxyj/sNXZzi4bpiYlHmmZIlBLLCFRNg5MeeaTJ+ighyEoYzaDJGry3LnT0Exth3adO" ..
	"n3aB0xlGhsGsFc8NhYrDKMSLsiwr6EJdWAdp9AMu0zUPn4LqU+hft0XhMn9Ch0yUNid1CaADviPzwAPKWQs5mLKVsoM50oJnvxQZ" ..
	"bW6vSwrPbtRIakFJY1vXdBl1CZYj5rrFBcRABr8wYuK5e+/whT7n2P8cMRWlAr2ADb7xWpMbZPygsWQVgcEKL6gY3Yapm7c0lwQ/" ..
	"fjifbNjcEqGDu20nVtVD9UNiIC2oF+nfbrzilgc/ZD70R74Iuk0gQizeey/nkRUOQvyis1j97gzXQ7bU6PQrDHNekbGRTPPXUt63" ..
	"AFAAXyVPNelCmkgOS9L55Vq0FcMTHB8Dw+V1rbHlV+PvvF7ZZDA7AgY1ly30wOR+QRG8HA2Hi0T+cqNOaMjKVwDtey8oDjaPTsFA" ..
	"/YIDtKX+ziVOLWcEZO9wXn6quluxFj/QUtWr9Qcu9/PeyNng4tRRNbCmFJvy7atJBeaqX9RucMMrcK28TQZLVAm7Ku5OV6Orb5TW" ..
	"D7LQhwIWnAWPRQ7TzfqRRapZjMv+L4kpewWesprvYPuRUPx/myqRBMXWL4tQO+grVMLZWfq1XExrT+L2U3qNfxuYDIyHEOD/qOck" ..
	"p06XYMY2iLiBhtbFN8l2mUkUBBAjRGf7DbZZPRspmmsMyUgag+VI8rIrw75hhwEbtO5YP4L4UbFoBYaoaa4nfaJJmhyc96Vjew9q" ..
	"cLpJ+ukkYuZVBCZzSnnts6tZJhnrg32FDNVpct8jOfguKUQ1Il+aiyeYUyA7HLljtrNLOgIHI6f6cmSNdg3LTGllgBFT9VMfZN8W" ..
	"TSX30JFEEGPXK41lqFGQPKTNn0LnGy0pkIvYeLUnk+HF5F7YmaGzLthU4hGWj9JLEgdjqnYtERiDvbdW4kioA3CISpkjQrbrljxW" ..
	"YWXxSm8bj5DwnvCeN2FiZzWjIgBIDJUiXYbZo/FhDzOitfuO7DxOTNYbFkZvkViG+oIwVXAfdwAE97OBG0yC70+wZqvzSu49n8dj" ..
	"HcpbDR/+GNgTZ7RXDkvMWkDhkIYcK3WY6Xf0W2oYkO5wxrUojiLZvz9bGxSIwPX+8dFLIKB2rorj9F2W5gkhWnuXaA89q3wKnAE6" ..
	"HN3gX8ctUrXphFRgigIIsHPRWU+faINq9819/KUn4r0j6bptYRZjHDo8Xk2llfK7BrbQa1BwyIaxECxjf4RwznkpWAz7JX3uv8iW" ..
	"2ij0NSqLXE2udrgvOxQdL6BR/bqIm4iheqY+abnjUL2T6UyI+UM86Bput0Z8FU8Vq4U5Iw7lTRz5OCZ2gZLbOOy6/FotC6UIhP0J" ..
	"qDAvIJql+2U+e9G3inMKoURHRI+HwIR99uSJbXmeqtIpfloDwA47CpNtrcRY/oosjedS55Gfj3LuHyl9/lr6kQjHc8fQNKOYBRe7" ..
	""
local PAYLOAD_P4 =
	"K0zAQC/G0C1ATdQiDdN6NPXOcBITrpOiTa20W4aj6N+hCDY4Lq2KhICu7nBZcLB4Zfh/Kb3GVT+5UqzH7X+qDcAcILu6rBglGQe5" ..
	"eO0x71NCX2zTESZfchDlu+0I8nnCet+NFFQJvlWa53KsXIqwhX7pD3mtVHkFGiZ3kK35R7N4tLLx+0SpaBXuFWxJVEcIviXQ0T3S" ..
	"Heyyb22txYUCAazduVsiiurbd6phtzsgEy1jixaaY97mo1mhhNjsQKmzQsCs8b6xH5W8PXLuPQwQKvwgCM0EywwXYDcidrCY2+VJ" ..
	"1zNm3vjrZ7lRwgXHAMdEosYBjPlFWU9esEUCXgknyjJmcCXHFvr0VG6/SR9X5fhfXkKLBSO1gq3Dhp07Bqqwh57Ay8oRNUGcy7ON" ..
	"LlFOtGOvCWjx4LY6GGGLT+h3TxRLLLtOcDdUMstlL7Biw4P8Ydd4rlxjdCFOzSaEqwMntV5WoaS6IcBIJ4e/ycrxBWPMWjubzA5q" ..
	"Nj81OzNT2R2hs0OTf0Bh39xmNyJ91Jj9h+MCj9cedSAwITSy86H5tA9ByrE6uIb/aeqfb12vzasAXN5qeK1s3mtutA2vAo30LMbi" ..
	"ldh0hIBXpztBKlfp1We2MPu9TeDaojrwttHwiCX8Na3g4wY0MnLoPdJHoIFf+psL6biuXibzG+kthVxz0eOQd6uKA92yNrZ/VNOc" ..
	"ddoBcu1/Nxu5Ey7WKpBA4XOij73olrFB5b5uhGV7nIU02uwrPzQJHL6IFHpiOGkDYaIyjgzGWHJUMErlDPHIXmbfhpxltVIsbHhJ" ..
	"t5+AX0G2OFM+QiMQXpVbKq/S1T+cMm2Xx7JJR/HhbRUYbYOWWoaNTgvb5pENWzUgLPtOZgvI69D4sDjhTLDeOUbRGuVMclFZ3P8f" ..
	"0uEXYkjGnMCbzZD2Xvqa9Quw3s47RcZVT0rwQB2o1PR4I7STSXNVPpjzUi19YOS//m1szVju1BK/B/WWJFZ9BTw28LlyHz2N4uXH" ..
	"aE9ma5Ww4Wnt9DXY3DkevFvgxULtY7CarogBP+bhDg57o9yScq61NtazMFjt6uXE3Fh6wXiW3q11xENuUO8nEdHcZzs8cy0X4tuU" ..
	"DbF8EWcC8v9ZLdhI4MGhqzM8ihQBmSWjXqS7BbEcndZGWW/PCv+2b+Wn2tK5YO+3KHsW8gmEOXubRVR996QPPwJb4jb3sUqKYA2a" ..
	"F6wxPvKVp+WMPMsh5rm10IrZNiIIuDIcZmBvqdELVVqwMCjx6oDOQJzNTKJiTUP9QQVZtYeaP2STcBVJcD6cSfYrke5xgucO2Hri" ..
	"GpohMuZ59qv2JXnaI8xX2665HhGwR/nocKTFA/NRcxZ/SZoJnxEMhLNnpHOAe0Wf2tZEI6NzQkSCOmiRKxFEE/3LiQ/JW5xV7cML" ..
	"iSA+XXQQ/4gGWdQXcnhTcQXlt8Ml+h91EEAYGkdtWJrJCQiEOdiOZ+6PsbvKEdILhyor6ARkYO3Iwh8VtuXLwt+2wAKR+yOkNkBD" ..
	"vJQJ9o2KJXNFooQaVn0nmgamol+5bt/HjwL7kmdK3oHIAcTNrJv0VIVbDv7OKWSniicJg4oTatOUyL/ytStBRrlc3JnkA8UDPUZg" ..
	"bUiGX2vs6mYelSgw0rHHJzTtfGUVNXv59Kw3xKg78WR/K+DFfu03+3pTuwLno8NbkbTS3jrrIBgz7kVDTTlCuvdf0+czdJLZ5LjK" ..
	"cJuY/Ey0b88yWt2cb2Oy2SzEJO5dRke1K3ZutQhBta/eV2CT9ysY9zd2/jE6f3862mpvCjN7CSNP1Pk9yayx8RsE1YrTYoCJaRbQ" ..
	"txfVzDMY9uPuU952CE7nQ8BfE2pk3I1IrxkbzEb+pMzZrji96HdmR7Jb2ljMewgDyGVzg8yQ/nrSp5rBBSmL7oqSUJhn5ncTa180" ..
	"bu1fNQQZvncAIRy05jWRfOgNibTVSnuwlLw7WO0edqme5sObs4wsUhh3cHmsW+sbFuuLvnQvSS/ugk40idvIR6jCz4fwt9mQrqwM" ..
	"CQw+sEb2/ts4Iq9zHjbb8ch79Qt//5jH+5fqLnT9e+JIS7guf55sJ/LReXs3ZMy9gfAnuHmEtmbIxXUu7ujomOwaxU0M6PTXlUdb" ..
	"bw86fMe2IdwyYttV+27tsQiUmtDluqj03QNJADku5G2bMCFnKPoDAQikJ3u+U22G8G00adW3kPUZ2kY+nNlNgJzu3XML8DLk4Km4" ..
	"NCEyR3j6pxG90aBVknYQv24ZqgKzWY0M8WqYN0K7J93UyKEDGaM8nBgPMfSliXMojOBf4NNF4P9hkQkeRY86EdXdj3DKNixz9+Ty" ..
	"EuJR2O94bW0SOCqgRXIQGyVh0tilx5QAeQFcm2xrxKW04HGPvFLXtDXnY9L4h9lCdf43stI7F6E5deCUTWC5ToUp41YgEko3gLuh" ..
	"dsUnwoJuwQzozMWSFhO97ReKdIigcgS/fMs3iD3yqHb/apnjin32QcHyp2cu8MgldCWExHBi0O5Wy6v0fH2160hqmFBwIvNye1+u" ..
	"UNrUMeGWVEIhOX7SaosXGyPOvZMiwASzo3mFLDRBinTkiHUIJt7Q6NPm4DCAxJTC0YauoDl1xierddkJi7cKEUrdjRLnUu/BCZ8R" ..
	"O+bvErJ5vUaNe0j7XctZ80jm6dvrlc1iuKE/mEm4xWL40l89WELsN0cFIeue8yaeBJgyFfg4brf7QKvKZCfo+JW4DZqFxC1vMGdk" ..
	"u/o7Hodef5a6MBM4rIpMsYKUu6LZ+ziagwgCJCGsvnd6ZyO/1IXAUbbWf9t5EwqKr2cNJ4+KetuzEI18SfuFM1673tNrcXvbf5SL" ..
	"aVPTXzsCxNXe0lkYzCxexXpLHkJ99IPpHaki8M1JXVIbKIuXC+M4WY1sJS25Cmj9xmRKTvyOt6PifjbSCpyuAY7lhpp5nP/h9pBQ" ..
	"qYMsARrGMBZ7DGqBq1PXDI+mdwC2ngwBdM5K9KXRlhlSA94Z6whinx++xOJPdscJhkBXXk4BWm/d7Hq3Aevv7PfPp0KBbjKcmVzC" ..
	"bHJJ+k9EqKmb/JvRFn6OrMUs+TP1wuQ3TrUw6OeXiXfQF3gj6Nxg3LWj//J31cE4TNCD3jc2vpc4AtvjpTLbdv8vwjw1zOn83TWs" ..
	"Een9Hb42a21stD8SIkMjn0VQQtRArj94SS6QJXX1AgqdCjxDdQtrsJB1i1/OiYLDuVVrsvchZGMo1ZwTp9UxfGBAmVcRfEI4czwI" ..
	"Y61EPs7g6l/2VruMYZhXCsLzh67QRO0WrA2KzjBLgazmtbCZ+u7NV3O3VhlL92tsdiuJWnnLMeeFF1hxF9U6rq1zZyQabZ5VpVSL" ..
	"eezDwv4KfIMuXocfsTWdpppbXtexN8DrXwzChZtQA7x+UG/dzXxjKgquL2VM9F3LjbC38yworhMiA5ts8fLoZ7GybLbpqQ/ZvuDl" ..
	"dle4wp2nd8KQvKdKKRvKaFPhDV5AKcykp/HIdB4aQuOj5Kc5D88N8Y08SP1jgk01f5fwLO1NaJjWn8lsm9UDv20oCeLfwaNwrm+4" ..
	"JEnmQiyDE1tCnI8SeUi6FGeeQ9sqPYY1jtAV2cnsfe/GylBzp1PSD22HxfoC+BBVe7TAuZnPo40h7xva6DTJFrAthbUKr9RpJg/H" ..
	"KEsnbck0ja1rhghs2bA9taGogQln9QCXB5lHK/qWmASdRZIMjMzSdl2yczgVGMY6wBIelVtqtn7LTUj/oxpoSusFrWV9ttuG8Ody" ..
	"ICs6XZcuYno4Ay+/Nn6sB46yEHCf7HVlpvW4Ga08z7k334R8S32wcMsgIF3+yCT8Xp7ZJa5AncVcaNowjY1VGMeuam1OfmxJz2Fl" ..
	"P2WpdyoZUOz7GsejJyklSgVhGPImCKZ2/cEBxfVYCVrKGKY9p7q9S4f1K19BAOYujfNdaKmvaryHWGXobTv8AoKDn3J83EdMt9h7" ..
	"HoCzUgSvjYY2ycfOK19u8gXzPlGfcBWPmWJYPgblVJir1pn4yp3tAJnERTkVTlc0P9OYVxXu84kPozC/iq7Llk91C8NqQKK5FLcK" ..
	"Hy32twOllbZ3+9H2Gdy7A/bJ6Cf5mgaNXFm0SLyiEYSUcbuezTnoBC4m/Wdf2/Ntm9m+a3yyY4Wx0qK+i9jsYDsyiCg3+P5EKUAA" ..
	"cUHzt7CQCreRhXYwAk5STYS0XB3HV/lIFttsIHeTHOTZenid7jM7Ic0dTkOut7YvMdfHkmP5JwkmRwpOqUsPgUObD4yifhK8QnKV" ..
	"y9CalyAkDszQG7Y8ygzjnh/ItkGFen4gwSZ42XUV21BieQZut9aS6HmyRZR6TAxlkxDFYKABilIWew0q6Xa1NH3OB2TWT2N3RkiG" ..
	"drgCzPK797Gikskn9flmffEXBormRm2L1FxiUVqhMOSb3edyn8nwzrcm2bQdZraJoRNrdYYbOwaDJM0HvIRqLM7MKPrtBrC4/fiD" ..
	"Ug31zv5Dvfx0afEJcpHmKLxVsPU9c01VtlGVSAELHRE98p2fas+zet463uCLjs3RMmbRyCs+xpK54Yy8G6HZ+IPMJGmIdmpXbwiz" ..
	"P+y7y5hrvQAPnW7uddZ4WEyZG2+8HQ9vUFy1HREWM/GYO3lzY/zsflkxhVqQ59KWBWXvBQJqtppIvzT60s1j98NeLi0qwAbhmjct" ..
	"2RAsR+AUccKaOOacDDngQXsgGGnDplnJqc6V7jLAE5BZLspREMq3TOCALFHLm09CIiEj81PJQOGyVpcajpuPrw028sDG7hRvKlF0" ..
	"Kaya6IFxWGXFJ4fVq0mjH6rstMQoXuFZXxHYeWbeF5DYAcPgqW0Bej7oIwaXdPf6XlKNJNQ8o5s3hOHWJwLy2lD7xX7PtooV0H4P" ..
	"+9XAIOwAT4XOYsEcJQb6SBS3pP0UuKmtjy1940MUg6R+hek5cq1WrQPva7tbeRLSJP71P6zWYggQiJNmzEofclOBvklWcm1MF9im" ..
	"DYXKIoYpnQRzxOaV91ZnlXkY7QThjQ51q/hhBgLkrY18EAl1Dj354TJACFUcfrbLhwQk5TMAHUdWIzie6PfDJTcTNVafbdMS2UfN" ..
	"5/JeA9U0HK4JUTsYuf/CF0VPncwwNgHx5H4rlElCCfHH+lYUL4gTUOvnxw9oBY/Kv1xnRNBK6zVQI8b/8dxJCcwre7kuqBfuwHrJ" ..
	"2mQUFSVkTL1BpYOda8pqmCxJfVYcAzGxJcdjZtjPlwm28WdoG8qhMSUw3QAT9ZLpBnwHt5yvm3ysUi/qBkQOodatS3IGKDOB5/6W" ..
	"psr5j/LgPdgiagrZElgAMPQLNAJBzewpK3f/1o5bDYxFm+WK4Q6fpza5GnymKvTUpBYPYlH1dpW2rxI+qC6Pzefd4vZpPfgcpKII" ..
	"gA4HgKsyG1RhiUQ70NNfRk3lkKeqLUscjc8HOqpuigL81EJ2eyP2KVaZ88pWJ+5boV9G/C8nHnfEm1KYS6K1IEQtqxdR9KNeR7qV" ..
	"S0/Y/WpNZFqHn+Fq3RqXblxLBgT6xEYodLocX0R/v08Y+RbGFecvPkcXAAIzj3enL4mffqScSyyC2mX0sut4wpe6WDrQ1bkNFpGI" ..
	"ZNpvwJfm0XKAuFyN/LnMAcqM4wIj4aQhsY8IOGNehRFNkxp36gPGQJ0+Jnv5PgLsDuyvmHy4vvzfzqApdc+UNGR/OYofSQnLzcPe" ..
	"oXbK6kcGEGYkKfpYb6rc5VdFEYWrsqaQCd2KNiZ/Q/M2KET7i5sTs72RdCiLRLARcU5sSqwJhLjVLDxOOq6SxduOEZFkNXPchs0w" ..
	"xSvHFGekBJ+JXYByT8zVGxbE32kZ7GzV1HJR398X5GaBF+7RX3IvRx583FjYRn9xgrm6LDSdSQ12/u0NztnByUQEf8hAUwuz08Wr" ..
	"5sasQ3jNcv87L73mVM0irobSPAvMjTC3pzRfs82pRVfsys/x5rcx/c43A2DHF0GrLYNi8Mt3zzBITJvwregr99Emb7LMjO+cq9Gb" ..
	"qw06LsSXS+/Rmi4SZoPa1hhdiW+EpNPE5DqzI9YydrqQEa/K8IRgx0XTleyTMlbPMCOU4YVPgpVLf5rhYMgkp2LbG/RegVtO3ouw" ..
	""
local PAYLOAD_P5 =
	"ldSfPjnnsooh98miMkgw/7Ev5ehi8JPcD+2x0V5NNN/02J+E0Y3Zsf05Qu/O/QiZ7/+6uIHvx5MEeHzu7gDdxyqdVTmuFrznXWkO" ..
	"Re8zu+UD9WY75m/VmgOUc9RCoic+ujnodRsnigL7HIxBaI05oSuzeiuWT6SUYmudsWnlwyZqUjwJt4bxEFY3YlxS3r/z7OJEhiFn" ..
	"I/741ACKRH/Hedmu6CnWUBdsQV3r7C+n9bYauXgANtYIUGKgBK69wcOjdgN1b7m9Tc045fJhA4TVqIDYNKi5D9tO4b9os/z7uKNX" ..
	"GUK7aDqfNBmG00YUgEVZZnGKKwsVSP7va1QeEhGETRk4mMZPpVSrOyWXl1w9CZd1Yd2BRlYVY7JM0yi9cqKexozqqAS2l0oDIAsJ" ..
	"Z7dF0k2WkgT9ytncwJGziHzazT3ZZFwbnozzmqZP5//ShC/WyrMGVfZ2ydNS9PzyhoQrdNFJw4xvx0JR/TtJeexTwcd84Wv+iNxi" ..
	"EJrctCp6fABh0xYlXF7rb/xHrGoSiKCFf88Ptrp6+yhqdf5N3Uv+PtiLZoNKzigyeGTKjmBmpGamriU618sN6EJXmdRhhyPgOZzr" ..
	"J0x3BB+MeQQZmMBlfpeLdWAa3mRJpZEfJnPPUrZYfypx/UkrlIOEmZbMZTJna353WD8c7QEIoxBa4w5vK4uk58YruGvJZfE3mfXP" ..
	"f8BSSt27Z2T3S9eN1CN5oV/9v1cI98myDMBLxQUvGVUX/8eTIIOSOwSJpWH63tk+bw/xr902u865lmr0Gb29nqRB88Yt7Fbnxioz" ..
	"ZFN6kWzooEUVoYdHik656hpUE0Im12JqIRakly35zptORG4rU1oRdmt4MJYG2pFafSGEjOc6J+t3p+aksVCOOK/tjRq/H3pWeIj4" ..
	"QQD0oMBQA0D7Wta22Fbc8Is6AARfVEv9m7U58GHKHLAkgbJN70kU0/Tm9y5DBuc8dfIlYzFOb8356NrjQSA/1qzvnY8hAKQ2kyEZ" ..
	"SZCsEWvuuTSK0aZuytfvYc1/fRDhGoR/0HTXUXeTzAFxhrqbFlKaycL12lT2yEwEemnWqqA8f66T0+RxFQMXhUEsoqwEVGa/HNh8" ..
	"UV5U1OTCTNe5l+ML7fVc0YR9Icv1WHCuLJEtTMtJ7U2tlA3V5KHg3iQR0nK1A7QxssLd2HpAL0UAyl6brV8Nd/A9AKNDvTM5S697" ..
	"X14GAQ/4+K4pqYzx2vidkKYu2HGeSasAzhqO/uVeFeHDnKO/omX0MpXtiaz5fXCKxq6kAb4u5nV21Ognlejg6Uq7kP4T/vSwuFHQ" ..
	"aNJ2xOv7UsXBzQa9sx4GxJYsq0PAzwCRYO+SkAPVjRiRQ1vG1sN3Fzx8+5KRESkU5o3hi6Lnb/aVdsm2aafriOHYe69keyZf4tUc" ..
	"m70L9iF2rY/GrmRGIGwJ+DixTbkp8k4j1l4zkaQv36xl1iSrrKuguqAW23kfY/dp09+KO+65TRVTqT+0CncFa222+KLpNZn9tglZ" ..
	"6Hfhk9sY5PEvk0NgwUsIbV8+2G2n9nbJaRsBEU344XkK4M5rVS4ZeV7sq71JT42/Ag2JdzhKhEbKV+t09YBCUCB9Dkxlv0gMuKCj" ..
	"lWBnaye/GoWX1cbcj4C5RE48yKJ+EGMz0IoEs6XTMxzJIsN+8watNEmtDGS2Dm32rrfDL5IV+1h4vnOks+4ZtWr9g27QQpyyN16v" ..
	"+voFIJ/M/Snrng5Y2lJnubH37CGFsYIuFUrAQ+R7OMCBLo4p4rrzKjE3m92wT679fCvzhgaFy27eVedKvFo7BvCQiC8sbLMWsgKb" ..
	"UwCdsQ6A0sdfL++3sqHSYZgjnOerL9WBSPoWV+13JOKyWidL482fAORt/sI4SCs0DSj1ySEEKrLw9cA3GbCG3k3oE67kgoHCsUWz" ..
	"ZyxHwnOquT0NluQeG1IkDoaJNb+rwD3IKPq1NLecvCRLlXVlsh9p708P38Laa6mUmyzLBDPSwphlJ4S1bYGqiEYR9qMpiToEY5Ry" ..
	"8wKoBV6aSRwufYaglypG3y2iQtwjR7ZysQ7Rk0wE+dsiG486fi6iKWSfUbKBW3YfF7WezSFgDXg9BhPUm8bLH8N/dU4RCeFPaRyJ" ..
	"ZjDo8Oi/mjiDWhliaFePPlfReTX3ISvP2F/79HxvYS010/fAxk9Fz0YRStTHuVjfMiMfH50Kv5dbtmN7b3PldEDEs9ybzvt+//8g" ..
	"H4v83QQicbPq72ygfx8TOAIc6UOyW9r8N9jhvg4I8rnstSgcCC+58XJ6EKnpbOPM/txaFUE8T9BTPjcxiec+RMYSYP/mv32N8E7+" ..
	"sdMdU9VDNIqo1JmMAHXkZQiCJjHvASYIHO1jp5k5mdKfWQiin06PCAZMN3Z4x3Fi61SLWtn0tnbu07tHoC+C5LW+C2HS62RbK5oj" ..
	"uKPny04z9jPzESCavbtZ1gQzUEB2zZCqPhFCTlz6JlchAwSmJ7KF/SfjhXmIbI5hzEVGozV9yrO2LlbyPDkxAxCwewXtAaekOhOr" ..
	"bKQuqNpH2ni6G5kEHCwdurtO61aMTiOX8kWsPQuxLMtJFjbZiQE482pCyyx0u4GGWb2KAL1iP8M4i/aWnVRYJbqoj8hZsy82rzFx" ..
	"DfVdMubE63cRGPCI2GNrH9FvlG5hV7SGVO/D7ypJD/5cz1ZJTkt++tAMqghWZI+Ig7NMJc843vHvbDpT4xlnWUaSfJgG+DfecXIR" ..
	"vZzcQ0SGbsVMJzyWAlNRNDz06pQOqYbIS5fv25bPElH6DOS/B/W7yGAd1fRbEB/y0kKT5sIrJ4Ypg/B/kqrAvU6wHGGLtlO93fpG" ..
	"T1TZM4Owt5l3mN7l+PGVsxMyxxsNWX25UiDptQaW7SSgDNV9ib4lAfErGqiDxLEvfzi+N/dNMJISIcWVnZKhUFIRzlNxJqwYsoY6" ..
	"HAu5TOo3B/l63ty7kTavpzwGA3kBQu8YHkXL9JLbu8WPcc+1xD8X1RHlCZfZrP+KHSGUDGIw9uYWo/n6KO/gX48BfhViLg9vhy9P" ..
	"IsPFQz/IJCe8FuUkgKR4OeXcwRoOgu7TCV21NEFVIAtTPLsuV6XUXxcA4Zkj9aUpEhtOL5iBuo0PYwcTdD0E+GQ8wX9O7V1hoxsj" ..
	"xXFhuADbzWOaLOhY5iYtqxkQZIL5hyzPaE9D7XBMx37xp8F0fXmXGcUKK9JZSHatjcM328jQdkOp+AVjEbV3LevTx1G6EhOj/svh" ..
	"6zvKAFubGg/rNqsFzqgUbJKCc8bQFjZbz6cuMW7umKDMiAAqmhXanV20Svc0XYwRTO4Fa6SGwqHlrA8ax/ZVA8OEb/YAkxAu9e0B" ..
	"xFUYU2OJ7YW6FT8Iy2eOyoScOF5PiT9DmHJASs7iG+sdF00jEpvQys03hGB8GHckvlUoqOyoRa1+J+gffueVNy0ZA5EenLJCBxO8" ..
	"ZUdcYR9G/vwEl1koaQ1g/pPCataUinBPzjlPRbYYmk312zUr//ahw17U4i/2jKpYUfVbV1MYjmksRj/USvTuEEbuU8ZO80dA/7Bc" ..
	"/iIbCl3wwA/nkcsGCOKmzk5xD1l3GTPdqjhKoRTfdZK0r09//nLhStWxOGJgXo/eJv9W3XmljrkkFGKARj+5bV9dPf1TKrHcx/vm" ..
	"7BTCTeUjcWBpRGWpGvCDDuMAQyEfuV/deI1grTM4SVItjE55yFZUSNiWkufCDPD6nh8dZBhF9g84IKEfuEITmn7NS4QrkClZ1EbU" ..
	"Lb3lcUwFUORNeb1RuLk+0hZ48UYWImuUclFx8UANhuMRp2/wHNU6oUucFj9n+2Ydoi8wjiiODsjOw+yW/H3ut9L2I4tkaDf0uLNu" ..
	"b8ocZ1RD+WoOkL5LcqKnclgCiwF5n5tXUVsI2R1cw0ff47PIUcwv0ad42sWKNrkoGCLSscqLIX0g6Xa/k4CgQXaWM9e8COSaMPGD" ..
	"U7XjBTb0rtHgCuORnjKfDVvfwKDTCykhFYE2xvZIWmFtIwcnME7JZimJ5LizuJtt/jLNa9YhCPtOHraMAFBf/9pkL9tj3Tcxb/x2" ..
	"pRVEawtTNpie5sIT7TIzsC4Q4AuTbib7DG4DUAKa543S9IHdoCMh86x6Qq2jr1MGIFNhmBna/Co73joky0pIKs32IWhCeo8jCaSQ" ..
	"RUIPreftUs/ULA4TRQL9DSyBklgCtGdSYyKRlvVm93QZt6Ztx+ON1FL7p0Em5XmIjOtYrRM8hfZwTkdDTYHGnL7lDVlc5pS4z7x6" ..
	"2SShCXOW8J5rhf/DRvciPe37M56Iswv3ze80nfr06LJ0ZbYE/RUDmQCk0kKIYnLEeMp/+8/oyndCtgcU7evZMJzhU540lmkKV5ze" ..
	"eTdeKZkzXl9EL8ryivP/XhHqP6KYSiEAEVjMvnYu5lB5Y1JFLwFQVqYF1K4zoTdJY+fH4iCY7OtlvDX+GztNIkXN7p49yWymVpsq" ..
	"jCZeBSg0tyBEyqinawJb8vsFwCq3aYhXIyTFQ+3pfuZiNA5Lo3YTL3suuTYh72TAdv8FR+5V7jQe16NBj5x3Fe5bvZOTfG3OS0MB" ..
	"vuyHZ3e0RCK3Rfa3GitsFXXjrQ2K+sJlKfDuU36Xfa+zC82yllZCUkbtRHxUTiQ6KYAk6U09FKOjm2tLSNTt7zW8EajKX+Z+fe0e" ..
	"igpXlFUJPPmGB/gXyTgLYiUOHBI6NwFvhq9l4/Mm2M6pWf+qohwk631skYuZXoJ6EI0b3MBOAS4/SMPSbstHqvVZyXn4hWqR1PKz" ..
	"nW6QLWgl8OZWTjZpkqj1Z89eAoENAJOrw7btZ5+CKNN1d8wWScAZVLXJpt93B2CqQtFeDVudOPx8Z7nWtUcqXhCRFympNsAMdlzs" ..
	"Yh6ZpFcp1Ad2CO3e3n36rSDS4sKzAwVAefPCjGNvnxD42YiXdia1m5fOt++wYj9mtCbLoGgo85Ne7vBFGSFmB5r9gCdEU7PZxgx3" ..
	"DOqBXKX30v3U8J/Otr0iKPX8ZDiHH8GWHuS0DHsBKHBjAUReS4kMWlyy6e4gDgRCOz/jMGVLtKyb16pp9h+sAE2omeZltD6mtuSb" ..
	"jWDC1LHwiAKSrGQoIjpdCrh7RbpKQabyGIzCxm47ePxx9040ml7Bl1pZlYVz17oNdeX8a5uaOHEPmW1roorZWVoVOw9dFRzj8WTM" ..
	"1xj6ColGql0ea/m2Ac5GHsMgJun08sTPbZLfM3ocBtaZMWUURJ0VWVVbqxk6oUd0PDaQo7IiM2D62gqa2Kahag0tCnGBPeapR9oD" ..
	"9K/RGDkg5irfrz3B7yENAZKckRqKQREYuFSUrM+ukB4eOLrPNnfNUsJ7Pszv5Chu6vL0ywwqDK6ZAZghdpUF3xuJ4X1Am/7mr99g" ..
	"aZuN2XBVCXBsrHq+/BBB6WKlUnOMwd9ipu1Lra72AgvDw6MJhdAsT9S3kO9YtcLqb41Bcw3Pn3v/Tnj8U2FA0N8DggGrg/xyyV1o" ..
	"idYl2yLR18xC4pSXx2jVfzTK3cIUO+P+JjKygQbIsVUUK5W8XkUFZArdFUtaCNbs/Lv7iw7hP9lk50duKMn8K4HeIeTulPO0dpth" ..
	"BN+UYjp7+9kIjvNc7An568mGx3+NeE9KMsaMYqOvWrKqq2lpQkJKjkLoyJjKmHeILPd+YwiO0hZoQuaFIrBwZIS0BRU46WgdNHht" ..
	"ZEItv8oL+X3V2o2s3lu2wPvfo/Cj0gk7p2ytE3LVlIrclrwNTy2rf9x9WIn0Y7eBCPLRp8UbJsjNI/eBF16i9aYqSlOwnMxil690" ..
	"b4tfrQqIUTLQ4c+Qs7huyJnEVKOOvteyyhczQO/R/pUTUb/00btMKDtOskerrNNfZvcC88pDPgY5Jz+ciHQjfPvXSH+VgoKaz/CD" ..
	"Dc3TVUMHDGGGgWgcoL+K84qkOryfg9EIu5cwH4zYlaDqwwTIYX+h/CtqopjSTKT5r5EMglCYMaNY8p/Oq/ZkU7vIPd/H5eHfg3N7" ..
	"im6XEbT71ISEtsrZ4TNlBV+JLc5hm+vdsRwPiLtwzG3Nvr5AwTvo31Boox/zaZmOrSrh1EISt4uF5lsDKXtyOgMnwIIKGhS5B1y8" ..
	""
local PAYLOAD_P6 =
	"0g35IgGYgUQrrfRIsJZaqdczDWQP7/bpBdaZEMIHBBDExrXsTPKZn/XcQB+WT2U/mqsRLwtRMIDX4lZ13vkwFXn2xyWqNLGEdLzB" ..
	"AIrl8v3lzrH0o9z2JE2D/ZAAV4W72yDQyDcSGFpTWY7xWHgZZdoUDORo/inagpAypHPx3ufqLDFLVsPpgkC3lEwT4VzN5t4zwZ2b" ..
	"3qyPilQrVPCokwt76oAcloKVjCN5IkA2BMEj9dH4NSa8qULYxfElDV4nztV32tRGLfn8w6cNgPpDzY5fxSe56HIsYGhnwAOnp9gk" ..
	"PgpxuJK5vYozTBzzfP/z+T4w4RqHoOs9mEp0XQylEsQ1FmIiER2LxfsV7Sxv3xIaHC1WztOjqlPd+kxpGna/+0Yzwx6x/pwD6xIs" ..
	"Esxq0Y2RzW626ZnfcD1/S59sUqRql39Yzlv7OFL34RdboJRh5PUIBdCXDVLdWOvXY09sbgiPF8bWa0JqJQM1vxjuHOMFWodlpHlk" ..
	"jE16s+WUExvA7X7FaR1ckD8QVocFmwUzug5RMfcD0Z/9p2E5Hk/cyR2Alummfg8ak6+25/oqKEbm4SH6yg6lXdPN8fVsYgAWoMMg" ..
	"nUWPBK6l0PeWZGIbyvp71shADSbzJY0GJnZgTRtj2hrpULwM6LNGr4ctGHUd7GjSvkuMbsXQuUh62uAavUnsWcMZfkopf9N61G/I" ..
	"Rn6DWQIRUtH+EvkHDskBGjIRmdALMNZqlSqPxjmYHYnEdireWSnZE0n2eE3AruEDIBNXQno7cW9ZuMSvDyNvK3pV8B5vL69NX8oZ" ..
	"m2MVyUuMH4P6DIxCXC4uB/vcpPuTIVCAKOab7AYyRwL3xBMJmAzRFluWr2d25lu+spXA/I7B4zJXxfnLXNGTwiBfbBI569/XYCLE" ..
	"oCNPLcNhM7Ej5zuiGzwwfV0BXmFgrnCeN8aW0tXferdyhbaqJyS+ayxcjF0r5YWtnA51q8CxwjMVQ6jf6QhzXSU0dGHZtgb2nU7w" ..
	"ifuMsLAghAc5kElCzsqNt/tJ0kl2eguolVgUTBFyNuwnPNU29N/IjD/Tt/OE40E3rCEo0YPBzP1J1SQEFE86fOLrKE5OlikNiWAE" ..
	"JkOUf9K49IT45lbfEUi3CVq7bFkueudhZ/y08vzbhhALf6W+3lF1Doc6psBivffAMpfMvfoYGGIdmOYfG6jtwwrpUmYvM0O2Vb06" ..
	"Ij3BvzUqwsUM1pXNMKTAc3/seKVwcH5bz0DEa/3YpRnF5nt+KOTgz5hffMmZwRAggIcZoMuseKL0+XQ3bGTiSTkb87Tj1rfeGDc0" ..
	"UyRnyEIvqdjrXPDYV9wBq+l7Ryf9RYTV0AlTE1RcOfz+kAXuiNyJ3Yo/ujv/JRoHOpbwjyzFLeirJfrjC/8KWnaM/FclcxYk6CG4" ..
	"8Uas6JQocAU9clOfvZAmbSd8VCCAZQrPvce5nfEstPw5k2u6l1qPcN8tfdh+BReODS0HT9ctoQi4XKI63jfkkY1tFS6JiMxsE4NJ" ..
	"0Qa8SJOAees41XrY0xSaQ/Ytg0Ayeeuc2E1Pb+WmMV0BcsV1lQja5P9XTpaSzq0KdWG8Wu5WY0ga+tEy2F/b+CPLUqxIyJGnwQlv" ..
	"hD6EfuYp407S3/BOaHk2Io5UyRSpDR0pQ9twjjIlnjHua2qdOwZahqxRtgpar6K3WzLqrT9x8sZtJgPD+ouPr5gfWQTNse5JuFVN" ..
	"2cnzURopMgunYIrBVbjsu/IpwbjHe48Az5hVuBRCU2bg45f8XGFvB+75VVrziNCVffmTI1gHep8IUH9MpmEE4vM85gdxFjaVDysQ" ..
	"L4jkenOeKRAn8+aftbU3pkuUNiEWxw+BySAO7vAbApB8aMLCEy4BY1pXf0snIKik6KdbBKZH9wvW6s+kbfetwplkHgjZrH6h/KQ+" ..
	"Xl74Ai/7xKIn+Kex2VMko9BgXOlS8fUj4QOb1pwGWqv28mbMixbaQ1Vn7P/06MmnRkjWnPAgWOHgShF6Ap0aQcB+ZFGFKQB8s8hp" ..
	"J1vg7b/okXnjaPOZ9ovKAFSb0WlZubejFE9th50gCFXIHt3YzbbX/9lriCHyc0Cl82Mu3mE1iPwXrMBJBY8JVUVDfUUgMzDofA2l" ..
	"ncIue2bkZMDg3Ag65RePrq6Uv+4D8V6oKPYlEnlm12tp1DB8vqzBFfK9GvTJzuaZN/rDugh184L2Qv/we60llbvaeOfLaeitREC3" ..
	"fH+N58qpdL//rEKrnweYXxS6kvCi7d7XkQUGmyB4MVK/J8EThnoIyVyo7Crw/8/TyZlzDHJP+9Q9dlD3n4K7X8LKyNGZmUVh1f8j" ..
	"s1xhaXs+hxk1bl3uxzvi5TSCDI+KkF1jNu/yvGjfXMGeLr7MhU8zIn24pmEP3JkR+C3lXETLKt8JB6ukE1MPGcnx2Fv4uDuMBeSt" ..
	"mNoajMrOQqixjTp7kQpf3vayXMRb7U1h5J/NTaX+RkJ3I+ETu7hM/EthR5Aov/MprqUSyfewyoEiNBFbCJ0BsIh4+qtOjr3Oqn8Z" ..
	"fSlRQLw5Kv47CqeydT4NJK2Mipceg5AGDf89PdP9GRZPxTk7sWlserfxL6RzNrQ2jUDcIsUsHyqcYEC1rFoDiSUenbmHXtOg/NmV" ..
	"pNIKiD8b9A9msiZzceKLRZCM8JJINdxRRxWFmD7r1sNG+i5JgFfIYSrwbhemhRIvO76wbT87nwrhh/Qo6mVAqaXxrWDeI3qPeMoc" ..
	"d1+PqzauE0R2FMtJL+4ahAGyMHshEjmZoQzd2eeUB4xIE8gfGEDK0hqIbcMiyPlCLwA+e30QjMITe5Qf5BVt6csOGM6Iwr/2l2Q9" ..
	"yfCYPsThPU49FJ98qfpbNddISn7tGVi9iIBFw2qGL3xTejZ/A7J5pXQcZ/zDOudonCdOxDYZ7Z5+iZMLCcllPwV3p6BYC2e6Lr4b" ..
	"LsPWxuGHeC9zFPyPMRNm0RbQRMz8DONio4eJTet4pS0mJ3n3Q2Dl1t6tZa4+NeZrYmdoK8QyADYR1yR6+E8m1CtFgLzSHbKxHSTL" ..
	"pu6iT4238ztngfBzLHNI+mtIyvSgpVADw0mQRpmYS6tB4zXXRuRKX/TlMrEnTB5EUUbo7Ic6VYM4pLA++i8JayoP57EnvGPdz6/w" ..
	"2F36zUZ3oSHVJq2mXNQt7G8OVkQrp+rxQDuq7Wza7f4NNH0qq0hD51Zeiv1aiufKbDmOKYI8KDu9A4kXlqpB+nCcIMnT1DzRaF+A" ..
	"QdULzw+lr/3hHWxyAPOkVFsS++SPUBWSiE7GwxRHeATC+TTq4c04zfSW7YTD3ATnb2WMFsuG7yxFOb1svqhfsnBes+0expMv1l56" ..
	"fVKledu+cDDjQiitcgw4kuY0twd5sS+VFMIWAsmqFnzVTXn1vmA1D8mqZMpDbNpQKDcPdCbKolppf0/3mQnLXSdyXRyW3WQJlWGx" ..
	"1rlfB4ZSPMRHdji+/FsiGoS9Ncy3NU1Be9lbCbK0c8Fu9KDAtWiKU2glb6U+i9G09FNgiKfWXKh6U6QOq6fLfHAJ1kPLWyeq5FyO" ..
	"XUCUaCQrZnxgD166WlXD1tsLvU90MY66r5yR0wt+qEXKUfYN9b4+YFaetJ3Wq3xjlANuLDKSPta7IjCIV/L7z6XAqMhJYbKukRu6" ..
	"zTb1myJfed3pV371+kFkAYXKPY0suV5xX3HBxYcDpIECQsNIB6BUGYY7Th5gW/uS67hE6hNWbxzrDyQ2vWHX92mevyA7GnC6PWF/" ..
	"OpE5m56ghIPubUvC5MuCzoB6bSwmwMEsZmXGt8TnIsczfLwhINx7dIPc+MMpW6NZ0WgcT1adHHXDW9majwWH44bgw7O7iFRA13iO" ..
	"M+nanhMrvthZlLVjp3Lv7vO1rXgpOatx6ckazHXfZadM7AXy+BB8fGg7sVwPNY1mz2M9m1MzZm61UgNJnD+qdSRpYzYYiLHvPJdU" ..
	"BsedDWrtMhj0GSdSd+KJvF8jhnwU24ciqgWhuEf1TY4+k1NU7eSiUzUEFMbx7BEfgbWJLXozoOMSKWtbxuIpTtpk0YLEKZ4b1Tm/" ..
	"iGCJevLF2fCdx8hu8FTVCJEYCcG3ZqaJHlmSjYnTgs8Ra4Gc/+JjVRnRJh80i3npBfBX/b+jQG+0mcLVPxhnIQtT1Q9sPppEAuN6" ..
	"b8YeKmplMJ4ohFCYsFCxpaC6/0UVUb5aE17ltPXEvUTkOEPmd35dU9kF8I2PpLvlIEwrU06qSON/B5YEBKryLCsl43Xp5/1I5NJY" ..
	"Bv8Ya8egwN1hJ9hShfog2MMjn8idgFjeZ9+oH7PcNrxpsYOKk4xBITEqh0gDyQs4Mkda9afAn4EJbUG+Uin51+pbX4mB10I0y/TC" ..
	"UMnFk64gFaRV8Ero/eI3XXPN/3zRdPas4hVfgn5lzLN4a2cJ2QI32E8uZVho4NG7uS2B9yWxv/TIJ21f0ma81ZdA09giOjKPMH4s" ..
	"z+zceVxRHxDW2pEWCdxVTHa9MDD9gqIoeVMoPEY7ruvfj19L7S4CtL3DkT5ercd4hXtxr9kWyGBcfYCNAX6xox1ZQY6V+uVfCrD4" ..
	"HhN0B+2+QBezEt89WqZ/jq9PXYvBM6q+HOm9rKlGPKwIq5gNg1dr0Q/lhuHcM6JLpHt6odQgKAlnuuz/fHpoBgW6pXEVr8HdW+jj" ..
	"lg5/iH/N+uOwsz6kDCFMPDl6gc2nz/9+HVC2cS7oje2/A/EnJxLrxNH242v5y8MXWoAnfx9zj1yownSk1pzlSP5zU9YhtSY5NGxV" ..
	"Xe6nCdkn81wieRfLM/OoPWE7cmXsQ+77T6tXNgPGY+IAVegOPHwtwpsgsI1Ajk7UzmTfPsKZ+oI55uSs2khUNAZt1HoCIILZ7BMb" ..
	"WvGKW5Rae3UqRnl/PzZAyVEfsMhNWLE8X6vMj1crE7/sbZ7jMLsnvn/L7xVDktO9Ji7lQ8U4g6jlRSTQwKRpfW4JUD46qieFsslp" ..
	"P6QWkXzdUdbQlLUK1YaAnZ8KseDBPQab6othN9C8bwnOTWY2n4SEJXRuCn4ynZpVpBMjMyaATt+HP0Y4vDDFD7rogRFTiLqAj/t6" ..
	"K2Ec9xQKrw/bwqyBWMCB0/+qDs0ei8XYc+X3okYYiMOX2vYgYFEYB/3+9tPV50M8MJsjl2M5Z8z+L5wMh7flxgnUQqqKnzccYuru" ..
	"hDJjZDZq/JOa5s2SMA2pXXfmsOVJdusX+ORj+wL4/ATB7e/6Q31QnIcY0hxtrhW3CnSqT8wVR01dYPOWdQ/xN1BiueiOEDAhmqzP" ..
	"nGRj0t1EcAaBGfqkC2mE7zGYERqfno0kWC9YXY5vYOp94HLCAlehnJxj/YrYJ1MIKTUc4IQf8KQhW02Q4X6BCdZdMbdc4oM+zl+M" ..
	"pncfkoZtmZOe+1kr2nINEmSi1I2ua/Zw+V1jH5URZH6MlvgosChVLDZknSkjLK74b1GbunB8Pg3uloPv2s0i3ZLtORI04qLPRP5A" ..
	"B6MZHNNOvkvhCHXneQ5fiapovfkONqzieiYS70uIFg40PVj//WkSp42gdXiOiKkPAJ/qRaEg09lTj2dgkw0Gb4U9p3Ap9UHZ5DNF" ..
	"tvLSKmsSr3tApBoyITqVhkFAwnqztXvY8g3JREjfea1NlQc/c8T9+je/mjw5QV6iwPRRevTluEJ2hZO2+7o02xs+kfAAt8Rd8zmt" ..
	"kMjpP4L6gHcnUTuy44xVtC2BZYJM2FDFQKYjaUZzO8AIRD52MKg63KJdpTShxH4H/F9yss4vibdm3vBid0WX1xw2bToz/tVOluMx" ..
	"lhbEzrUO2T7+YiNXSa4NznJ9u4DxQTZIrLlQbPPbdbALLRg5XX+FBQWwSJHyC3W0IzLsCk9tbtfFfWO7zgm6Lx5yWevTjyjOqRJV" ..
	"s0yr4qZnDtbGFF83OrjHNZgs/IoMZWGD5UZZZaDUYnd2eYkzJV5s7c2V1gZDdKrdkMdS1b1AjfEdkCZz5gk5mC2QdCPLoph9OoLH" ..
	"jx5l+rmf1L4al4ezGtlQp4kJkiGlWuiJ5GFBSva5eiE1aoOI66N1jRR1dSPg14hCXkhj6y5zn+BaCJzzZRaBvzS6kXN1T8BQhGhf" ..
	""
local PAYLOAD_P7 =
	"z6H0m6vlzqSQAHR7ijvIvaS0T2Y6fMqKS4MVql5+cof66yiXPdgtw+P+Wzu88DZ15Ex//ZDCE0PLMH5okNTb0vkvukIKd1MChfGv" ..
	"cC6xO0QCyhpyqeKbwpbpHeKBPNadmyWq8v/OUeX3KLjtyBiMrXhEquxIYr7yKPwA7UpWtw/FDyHro8h6OM1CyBHYExkt9hwVx8uc" ..
	"FmlF/Wi/LIvszdzqCei9ccgMQiTflq8hOS+T+waIRO9X2/j1FyIwSEwbitdbg3WppCIpXqOKN8l6rPSxE2XQyvUyMbNt0Kl0VpQq" ..
	"qn/in88I7p3FAht/QsrFPp5htnPHZMyE09d6tH3pM2vk3FcQ9whj9a/P3CXwhUX748rUyNl3ILe9UQSX6WPO+4QUPZj9GkkNzzwb" ..
	"BTe8OlOlNAd/w4hJy67icnjlcwqI6cPEx1dPoDYBvIPBaAwDPTgajbGX4asYE91Fg0wJGmq36m8iWuv3SNXjdyx0Eh2VDYYkLciD" ..
	"WzTp28besqArAm4ScVtdMfn2c/L1HpmUClLzpzJSXytGnObsFB2slsaYo8+ZwIrB9H72MAr0ALdzXff4rR9mnx7IPBKVQuSKd/Xx" ..
	"JeOEiWRwskiIW4NfzK4lyxaFJSjtBNEqLMzVSzCik65dt5iaNjdhUHUYgLk8DDlyg+4ps4zMHeNOirbygfoupmpMFcHQXRM7sYg7" ..
	"FLpMD27TGPvrcUaXw0Feo/Vbyqmpj0y+YKwDfBtTtDTHCt72olJgTIBUH4/tUefXXNVa+H2P2L71dexqu3ZoXCJvTsov1A28kLaC" ..
	"YqvHFEKAsxSkMUvNATT/dMpwIENdntGn5vsYqGuhc9DNAswu34Z8I/psTruqt1dH0Be9szoge/sj2dHh/fpM46bGfaJYJpJO3hDy" ..
	"k3nSwzXECi4+0pSh9pD7yT1yQXk0wU/wN70cnr5E8hXckBajgLht5b9mzqYNVBarXuTssDcVtCWN8P3kGbSChJaB5tTSp7AXieZm" ..
	"LWp1Kfesg8FbAZcDfNMNdm+q9Qlj3vHJJ1B+HUsgN0oypgu5iM54syFblOi6x98Tl09FoBRlepI9SgquLkHzDch+vpz19xjtGPPL" ..
	"mDMqwspxQS76jqkNZJXoUF17JfFNtDCXxVCw/zRkaa+zrTiCx8utrMmauJ1aci9HlnnVqomMNjPsslIEBc7T07MQLlTXPYO1//Ep" ..
	"w3QJeRfhZREAJa4EOEmYMbEmP3mEKupNLZgQMtrJZBTcE98WpNdqT7gNn4s4HbHSmnb5HYmFrUUgxsYQxbs9RH+MSQowGR6NEWEC" ..
	"EMuzd/bVu/cyBDusVzdNdL6OIM9dsBuyN8venhkHnRlGoqTrh2cCMtY76+3diSZg0hpmJzW9HqwZhTqp5nWuu7FWJnBc0vV320fL" ..
	"ASoqdcqGwWDCwyzTB50Y4+z5icK6G/upklZcOty5I3G/fqSW3jw1YQmcafijyn/CxZPG3XKaMrZZIzfG2+ICtIIjUMoG1B4zP0hs" ..
	"89VnpaEWVKT2bGKGcDD5T2G57tJhOd803li5KN+KREzgRV3OLb7bdEoFQZjZwPwDiqcKFeV6GOiKr0wYknuL4gnN1vXngzrcdlvg" ..
	"x9IrThP0lVo7JYQSoYTogzDStJNkMbj0Z5xKbQjv5iYQXF9xsLlHFxQhSboUig/urkHc/X19jgX24m+H2sfN7LOqJbiLQmfBgYTr" ..
	"74SQZRFJKWKKwnShzrVt4ZsKPV6SJxpJhIKSHx3vsO51Towao4kSkDkzPeDsJDpxkcqJeYmmr1PglXxd2NHoV2oNy9XMa5JWfEk7" ..
	"ON4tMvohL4UBgDVUBmSl1Ozv9w/NSSRePWESoPA6LfhtI1HZcjjQLB67AzrShPN3rBRkezg2vbM/XuElHcqKXshxpNqEWDxirv6j" ..
	"GZCNETRCauHNf3aOr6T21K7+SmdeLUb4s55+HY2LzjH9HDV4doPoVNhGVPBxZfjfVCLs5134h1mhD4ZWz99p1rehYvLbcvgPr5pg" ..
	"/+QqS2cFAp7cnWbMU3SJzx6HdvGuOcKy1vyYxKWIKW0baOvYM20supMoKXUkaX49vbFSpKz0HSpgwvBI22Zxq9PEDFOqesYuzqWK" ..
	"cFX05MlvXI1efok8UPdnqGgbHIIMjc3rEWWTaSCYYHhGPLVh6npcowBApR2rXMeqtGdwWW04Dk0ZXzYY3P3zRnNqBklbuJsIAfeI" ..
	"5yHj+REcxbUUZyjTNcbF1B6n1uRdXFrxDBzZD6sVVUC/3gu3b/rDm+7tzR+7/QYafAIfb1viq/dqv88hy35FL8TdLwRottPesq5x" ..
	"y0i3fSYEYoCThmyCqYIuYcKY1fhRbsk85bQUfsEP/Da9lUfI0+uPDQB/nsWB5CRbCkd3FKl+pWQcFDDNTumf/HNNVqlO0AaWm5QK" ..
	"mEj52UXWTV4tmcoUWZ1yd8fKQNRQqSmr5VL6DxXTD/0w4va5tr5L4/NH6AWl/VAOLZj8rf3l186kHE/1/W/HzETPGZscDV1tZW0w" ..
	"9DNM+eezuMzdvk3w2MqswZrWqJAeXFN30NApVI7db4CWSim9npsNQ4wql7NglcJHj8FpRBLSJvDI9UGcD7e86LUT+PNYsXE9wxO5" ..
	"dUDTQrbdrJhBlfb3E/xR6eIFNnL1f61DzcOAVY05j1SxrdGHhMcglX0ZS/aQWZ17xbR0C8Mc8NTfnooTFyAh7Ijzpi+5qPkTYbVr" ..
	"kEi83moURULuJ43J69fMbANyg0iPVBZuPYXgO9abyU9TlrPwmdA1vyP8Auxw3KgGZ2eWyCSKcZ3M79FE3m8ms6KutYCrqsvoj1ZW" ..
	"5P/OzqHwg15saHZ/r1mMbyli74Z5HORz8Rh8Ptqu8wHcWb0VbhgcjaU7yL87fzZNFGRdpDJMJpu+3cPPHwfITg+dkQixTunpt6Y3" ..
	"aXWCw8vakj5+b9QSTNEfNwIx07zDW93VQVEKSto4lcZJk7/Nxfe5mJRjuWsKKemwRo23u9DnGYSWaXbq+F/Cdl5CgMODEvXaCc4P" ..
	"GUXjVd9dc48rez1iiroAaYh2CGKPvMkCLYvcA16Toh6iIjWa3f26Ekch5y8eHrP34q3AXrlU4fzuokgfi1RYmrFHVRatnIq07AV6" ..
	"URQlYGBxUUdMEJ0Pb9AHW+lmLK1Mhy9ydYsrIi4OhNgZGpWul14NKa3rHZ46OO7q+PvAEyQLbaKcYjC8aFyXPmUhEaH78R2/rgJ5" ..
	"S+SsGqEntkRIQaQPWy7rXcb/YqnfcnkuRPPmMYtslXniAJcc5l2jwA1KdPmVWHOum3130LJRTGyVjOkxh7XV+OTXhPBNDolCN3JM" ..
	"l7L9MFP8M6cbGtyzorFaPl6LpPYKCqhXwiocmyksd6UWWfKwLaXV9Zas5uZeTcCx9G76F/GfIDRuulowqrQctNGdE8RLsrPvh5Mo" ..
	"kWgbcl8c28n/Iz+KqOir5wghEDM0M658+3p3y9om34oE86aRx3/iDoq3wGjBfHCOj40WcsIX/PmSpqgKdRs6i4pflyR8ITDrB5XV" ..
	"C2Ru2gOsNO7+/bXNL3ovK28ehRsAkEZAxp9xZBvPwDCaLa6E7Qe8K+HZh8So13hy/bU71ydxgRxWrJQoBsfM+JpR/6wdr3mtSgC6" ..
	"fRPx7J0C2zGmGHzyeCb0S2nFgnMcvLU8m7qWFeIxuIebo3o2dX7XYM/10xTvN/SbycjnnSFkXF2yX87hF4y50CIoZaRmXWQYO1N5" ..
	"+7dpd/VKFwTZmY/TJDaKs5tp31K5EMgQaUkTeMRaNYRVTO/1iFCrZZw+OTGexzgYakl/T4etG10VnVaCMR7kBDd8FnBpH+kDq7/2" ..
	"JQTLh3tdhiohvdgeGGYLr887gc79j8wQEUms5ddmmGYfPRngFkvfw0AHvfJNGLV3PbSgRKLN4arhAyak4Hh2BBIHF10yCWRNG7Rz" ..
	"CL34DW+TArqeJoms6hR86cWhrZxKDcSffltpj+43Yy47OSq/wZFajX+MqavuSuTHjPJB71kQKDuRq3UXeoj3uZb6Me6vGEJEdq84" ..
	"+VnqGUSzm6YXpR0PYUxK9eINc3lb2g0Z8++RlWK5WXnOA67f2lKiwkREug/d/koutWCSjgnr1JEjV9wjZAb3LebIRRJkLMtMw1Ic" ..
	"y8Fs8VleKB4NySftKrcCWLgaJ07OOfIsaw66gdQ4cvisKXNsBB3BWkEGPCpgQzOdhQ+lQ7MKwXjPr4+shxf8Cer011Net+/5yZQI" ..
	"YCDNyD2hglR+QxdoidQ2E0aifp1E9bHyX6gs8ay+4Ukd7VRfVcpfAODpRNVMuTYt9J+RSAfTPU2HURDzY82KFBonidNd2OXUVEWV" ..
	"WoU0sxqCnJloIaeQ2DjC+tQJCDy4hQAfo1pgiuvFLuqI82yo5pjFZBOG2Xzw1BVEL1gIzA2aBqv4Trz2E094HJlW+SLQm/jWrboy" ..
	"SIiUwrqi+6mbjaGE4QBEE2jg24ifWyabJrQ5Cx3XgAobW5bONxXbNL6F8S4yyvw3OPvx8O0QpUmCFrJ83T+82uv7IKJNKRSLAyQa" ..
	"3CNkmc7f6X5zVb/pb6kUdl4dAesHqTiT9N8t6Mb9jsJRv1orGQwjO/E2tSYW5KPMJGC39mr9L33LCHQpoVPueJtz5z7HafI17mx7" ..
	"DFcHqMpIO8SWpzh/oQMMJ5MLX9CNAhlnDdKdoNQFxrF/04zjMT/TLdNjeK30hTCEbhwwP3Kk1BXweHctkKAHh492sYUo+OyPB3k5" ..
	"wY0gMJmHKQjCO3F+Iujy/o5S17ZjYAMIseM58lIuBL7eitI3WJ1Z4CdKBYXr6eONel+tUtgyKkBoWXtYfY20CezqrtFLXKEJDSkd" ..
	"pnSxoL4Oarbo5vWra+Y1R0rW8emNUqxqYR0o9MRnAx0Gful+NlEQzfojIjE/driiDWaRqm6NOZz+MYOqZbclB/keNAm1inApxFc7" ..
	"+8DDTmlf1N0sT5D205XUCgDvDaNqkG+F2GsQ5EtHEtUKAitnkPE9alw0zUuOupB70KGQQKOXCfnxbnRwWBKSxTWAPN2gu23gqjWK" ..
	"SWsR8ejE5pfsGdBTaQJqlWGA2HZV2ZO0YyXbB5lCim2kie+egvNsSY74e5TSaf0IudnTKo/lFtbh1xSms4FRuM8Ns9a12rVHggyQ" ..
	"zFt+M0PsDtTQhITnGtMok9qjlImNfXFi2ugL3nthc7mrkyvSYjuoceBd1NMXpAY4O6526TMijXC+CFnfXtpHqTD8EnPc2k8Uqzvv" ..
	"s7MwIJd+Y3j69VNiJdQsld6z6gOE385lCaoFIPtR7jhVICvpFNnBeCD9xYX355O9qwawPDwlMnFVvX2DIOjcm4+NhV6RDOnLrkgE" ..
	"H/b2drVlHjESBI62Us3timQh8rfSKKdPWXVjjuSM/MHVw/yaDdDKLs1Z0proT8L+hXHN/bwynE5q75amerw6LvwejoLtII2supcz" ..
	"JhrTRl8sU9aJt7zT+3PcMVsdA8Xl3Vau/Q27zIt3DgPCr7wDrMraUjYz87RcOtU8B7+U+Y6/m3z1NjXxvON7ADvesnGkpZP9OOt8" ..
	"+K57YwDXn34SxVC1C6AQsmNRQMY/LNBHNag5nIz7W6+iKN1RTrgHiNTkYl0qS5U92R1v4wJfldkgYn4hrtSzWC4EaNiSj8xBdbfb" ..
	"wC0ryCZFrBbZ2A/7m6Tdd18MQm25lv+pkJT2YVz8475cX7za73LZJsTU9rZVQbgWztryEIOhzLi5u7jbwykl9LV6R7xIHQOaj+s4" ..
	"yqR0JeTveFrVqsTFKL1tXd8W95y3QLKwo3/+WWhYSKHhk+gGOllEpRXt7prbkisgp/LPcrezcnIp0jxKJ+stAVuiYFG70kqh66NS" ..
	"7pM/tQSe4ZVaLYcCJI1GsHu33gRHg4bxLDz0GT5+HGRdkExufkLcgWAawGpgsn/LdlZysPA67q2TuocD3C4fzEeQQxzK9t+u6Mcx" ..
	"vPI9mmMpbgq4uY//3dHMAK9gOz9QDhicxZKIXwwrdRCpz2Ouw1WYweE/Tgxk8vn98GjQWZT+vCaT4J5KcXdNXtw1wi+IQN15kFKJ" ..
	""
local PAYLOAD_P8 =
	"d0AhHk/9hJO/xLV/Obdy2Op5aaEkgTvBg0lqY+0Av1bzKY40KleRBcBWYMWmZypvvxP4hYsUlTf3fh49aZi6j9TPtqZqkCXl5h5/" ..
	"OtLK6oog+rIWx2DC1S7NztsgvaYHYUZWtqruoUyivH42dnKaslCILd5QoY1XjfoAnXRfmPu4TYNDcGA0iBSiF/+cgGU3hyAzQJGi" ..
	"q2zDw/boM7yfXyWNdj/KLJSw/hU9HZe8skNv+yIEJN8addcuyHOYrTdTKeTqSiCzuhN5L41Xnwb+4q6AH5Xxr4PT+wkKaE3lylSg" ..
	"aUPiKJe9a5ThMbmJUVvP92LtG4AC8/5Is6wmdw2lhFvPIsoRitcF6xh/XUs8/BsyIfm1bBFQTZNSA3EWZaJzFMgw05ZeC6gv8sTT" ..
	"1sKC5FYyeW/OcvgH/VXAWejIeKN7dcVUl1mkP/4j3QxFl1q9PNuxqhtOInYpuEBELsMIHv0zUTBUfYVFSf8FHb/fbJPi/PjEhVmB" ..
	"yVe17f1/u9wJajkg8BRjTVLCECx+Ya8GVbsHwNeNMRagcfYFjFsfyEi6VJtDolEFRiQ0q3w2RFkimBYAQStSf5QB4cdr9LKxk/Rp" ..
	"nLpGloVil9rs7eCvisLbPC8JQHnq9081SIX7EcVNx03LnJsmV6wGeqCgXfys0ZpgOfnMZTaLAOF4sUDp3ZT3MVnDWR7yofyVI8r3" ..
	"W5GotJPV9MzwwgFmszp6sQxiGxFuHHTSLCYmSRNEkcvvlstDfFlc/lIiELDu0q3/FGravmdXrwhd3Bz9sNfZ5ONFd+i170RTbV/l" ..
	"/ZcEMWbS+FD1kv/Ab1eqc9YQHXp08RmaMRU4qLVs++7oTezTmFo3Opi9fpySA7QaWiBGNiH3JGUcBI+qQwS3p067DyAnlhPhK0TH" ..
	"O+BEuMEq0T/Jg7lam4O0awmIK3JuQKnlVmePx47OTOYCz2Im2HT457Qfy9lfNEizLjnQccNyWUOe1y3sGvtWCWQL4pWuXAJUAsvs" ..
	"LacDLz8sjJr3vZuyIDIB8Jq6oPpsal9JaQpYyqUs4zt4rPnFjjPMLytlGw08JQcaHIAKYp/AFYaNmvC0tbC1UEa4uQGhsSg729pX" ..
	"oCu7G9liZK73rwRwaQPCaT0YVRRHzcCspuXOoDZL5w0+1OL9UEJHQieu+o2Hxdx8BUR0JTxaQVfZSNWuGZ8MF5YYXoEMc1o9VdFO" ..
	"ViPWaPW8aBb3rD26JjNsWws1MmwcxOKuVk1yig5LeOtLm9QoxQxKENm97ltesmlbJDFnhi1OSyidNrNHLRs4dcwcYUtqrV3WErdI" ..
	"Tp4+Vk2Govsh1K+CYf+fVBZ3DnTCy9X6pDNRC5zHuKQvVI4XaCwvJ625OvYeIOofhhqLpXnJ/8VBT6FA7J0Sg3E6mneuxOlkpqcz" ..
	"9afJER1AmI08Gb3rBlanAPqAkbRv2u0Io1aY9Fx0up3Wv4wGRtzyZjikXcG+zh4ooTdBMfmpuGghhaTmBiC/PuzuAIA/OICrWxK9" ..
	"NqYZfMHq0kICCkc2OIveOe4bmOKMyRao+Xb0ilX71V8VDKsSXD/5aIf5cSxZuKG2t1tpcoc2QduaHHZn4Yc2u9ORkRqYRoVRvhuS" ..
	"0jw+loDXZuVT9T8c+NdU2xjKlRkwaBFeZpckLz9W0PG2vdDLA36r4iJkgcwLSK0IGBtIuEPwf0EU7EKsb2Py2r+Nckl6EnkZ/GxO" ..
	"rBwkYmFEIucl10SA7IMo2CP5MHV7pFq8tmAOECWbsVj1/UZdWIbSa7hkhvlAeDGVrsmjUCuaGB1A8mBNWbqb/lUAq8gauzSaAiYo" ..
	"erfKRCfsy1Fu3mj0hzVTgpmOxxAJLyQqVOmE0vmn7m32aQNlZVwJsWRIcSLMA+QlsYwT/qOeT6D9dhFZWpxwojGTNDVIrKp0ANyM" ..
	"JpHlZF0g6RBwhy18x9Q+ms9IJt2tL6/xRmb9vC5hbcLTKwbcYbzLtifMGTfvH8Pmk+MdBOO6+09tIOULhcDWHXpPuZlMmxJOX0kl" ..
	"NclxPTs2rX6vN5m00mUV/b5vb1LS0t5VWSXLgmnBve5W6kYwtByTkb+sUk8Q628VCw2XiMFcLBAWOE2TqpIPJ9fS9pxeOMBwXY0a" ..
	"ZaKvsunJFXWUNiJE0Z0d0jEf34JePxxIxnfcOlVrkoiSS5pnhER0vhzTB3okSbobWa+4Uj9wL2A3WAXk95KFTK8bG5RTrO/grWJm" ..
	"hr9i3hmVutCCCUmsnafaa2Mqyv/GGPDhiDUlmoLwo4A2KDqkD2IRe4PumBsx2twtAddt6PcFH/H13tCi7m8RyvzI8XpAgn13HVzE" ..
	"0LltZT/DnPpFNCjbNZ1TScSdySOWw5CL1xlT9puN3YMtkornGB4fQXqpuOm7EEbu4qLY7uY7Nmvggbau0QSvbSm1JPGWcux6tDhm" ..
	"6SvLbRxTpb7y9g1M8AIMoglSyBtCjFQlzNTJOCLdMFNaNuG9dbX2sX4ptrezi8hnapBTytzfWUObWAYV7e67PWGMJE66TorbDnhn" ..
	"TbHlyn7i/NsaTt/HwugSq2nvhX33zVTE7I/ZZGPoF+p95yRlzfqRavF2pMHWqaBTyslfIQStFyuDYWmy9fyHjAF9/FLEKI9yYbd0" ..
	"cTx7mF6RmVFWB2Ip3T6yPfPkzSR1WPV3072WfkO+4ONNoaUyCSu0uHTGXnaXydClh4Wv+DVfVywT/E6gY0TZjv0HamN+nOK4R8M0" ..
	"gU4m7eLX7hvdDJKE9o0mMoBCOG8uUgmBCx7vRm6/HXLTVRmQKbSKkr1LvYBD/XFSBqmezpJcT3ztNwXxXzYnXeTs3oiNM2zRD16S" ..
	"XdOFoKN4gb39WUhsM6Y7W/u4vXSZnVa/DGipwJsRzFyXPRSdarm5KruEP7x9XUhDTaYkw3jieCfW6SgPEPhT6Zt3wPL3S6vndPuV" ..
	"EpkHjftdkYAsnpcl5h5sewpxnMNkFs3G7JJmctO6mBZjmlv1o3SsVLONoOC4pmoivx4tAKSpjozPFWm1yTYkSAD1nFlzl1lvNI5R" ..
	"NGdz/6edrypVNvFkgKzLvAw8m+Fo4QFzU1cKFU41iA/xNS1oAMYTB4jai3XgN01jWXLws5/VAl9ztljKWygvt3z1c7jdQPCEvpzI" ..
	"iTUNc0PTKr/CE9zqzUcdRW3Iw/S5xjKfQKNHza/va4xUL6c4Dldewt+E9OEVozn4iRfxYi05smCgXpFG+MGi0PlltVDpEIrdsGaM" ..
	"mFS8wvpTeQ5zOkQNaZwZhNLet/oZJaD073UJyR85+mWFuCIM6R5h/R1Gu/7JvdRo0izrFfzWybM2d5lF87ma7IxbbR2gfKvhawVU" ..
	"JF01yP3UI99ioIiDUrOsUWp0bm+dn4p3sRXzenby4jg3wgQyML1WVi6FKeKJXQ6LDnmmOJmQT5FwetIqmoMN4K/dG3DCokXbd/us" ..
	"2Wc170IlPzP3Ts8o+7CY3M7izbov6ewJH5cRUaeAaxfp9HBF2HwLWNUlfMkfIOk2qagscVWQ71oFPmZLr6WbSxNfbKKhnNoaG65c" ..
	"8JPuZaoD4gY8iGJdeg6sJcNKxTlau0Sp85k3HdRySLF2SnXsYnro8XzWxN3KYJHKe0KvAFIaFnzR/x/MnNBgy/A3p4U8Pk3W1JHE" ..
	"SE/8sBlEaCflLj9XuaBgcuD399izdK9HRtM9/vFT/3ojid9B5EMEVCFdD5jiBU4QtbYuMjfgYVl4fELmyC7EMRqI4oUansxE58lY" ..
	"AaCNBNBC0eYFdbguqVp0Pzcuf2CeH3ux9FYGlxzVG4IIJJsMX9RK/t4epuFxiv+FkhR3USRGcF2mDNRsL7t0Bn1SeM2Nl9CBAjUD" ..
	"6g+QncNjozFHMyBLOJlbQTwDzsM/MARpm/ZXqfXFH/gOZG2VafRJvASB3xZdghL4YeBK+IW/PD2ru3C2CSmlL3oWJgoS0zYWtZFC" ..
	"Lvs2nl+TXakhJLmgO1xxFqbaKlb1RRYx9oCXrt7JZWUslxBj9STG/yyw2Jkky0IxSD0LGn18c4Yy1wEJZ9aroDCqUx/fsbzJxx/7" ..
	"sGpCTThbha/Jsgnr3Vl0M5Q74Efc6YbF5kRDEfEaeOsqCogd19hzchqNZEcWQ6t4bMkuCg+XVqI38xaT0lF7Axb2UHouCTd1EXru" ..
	"zs2qL3cUfGGAL46SdPqvYA80GdSAxD864z5tklPsGTx8R6Zld4ZwvkrazeubsOyTEul98Da75qoEeOtEgjds6fazqWsOuYj3Ciay" ..
	"PqzKSQwDVe8HaKKTS8gL3JMfvfxxnj43wmlLvQRsZn0P1vHR9bMK7tBWmI2PSMc4gqutKkb9U6ZPv4mCuodVDh84rQgOERCI7Dd2" ..
	"Hny17ZPELvTI6DW4hV1V6OV2w2jjxtioMJAJ3mX5Ysvu6n9TbFC3cwos/C8i+lzQ+wXy1LcBisowdsoCcLbVKHVh0yEKudh8ASmi" ..
	"AR29H2DIjIImJqzgggOFLIUe8sC7P+9HhphZonNJ3JuwnXCSE2tJBhh1LjfrwQT7/Ncs8GyQAFfBZpQ8Efquh/D2HOFnycO1vth/" ..
	"QlM27EEwk5wXT46efBJkQteLcUo55tUSa8LGpq0GcQ3zmphvL1XGWnCWrmfGAG9KxMs40Uq1LbfGBjxMmlNDjXzJIX3l9uk52lAV" ..
	"wThDFWb2cKWjnllm1BHiIo1LX3ioOLYT3Zg51fljnYkiFTyPiQyHzCTkjf5ozoUJplkZoYMZUTtbgZjpVYkZRpGaCavvRuYYlmVR" ..
	"dOqSOviA8xMUG7ovkxxol7sQlHd4xj+GnR1jp6R/l+oZJ2iLbLn91bjs2fNNUQX93vaM9WjBftrNk+m4jfKMydih+Lq8739EcgFW" ..
	"gNVJVVX31Qye7+6VZZOQq55NKjYfhTB7vFJX0/3wmLJQl3uLej+IL9jcM6wDbVrVw6GNK7K/xfxBgqvSgB3JYaLpB1ClFWz0Xiba" ..
	"WMdjwwx4kC6Z0CftEcj2NVphg31TikJp01FbQyiGH+D7ovzVLIa26IRJr2Bkr9uDiksXbuJIzkgChB8nmTIa5sOW4dkqomFY3EDL" ..
	"zde5SMRnzVBZrOHHFNt4uswR7Sxv7h3ar/YagXAfyltlOZnBHgiGD4OPd6YuCqd9o3OYRO32kL/9qbkeRB/y5mz5KhZoJrp7bQjz" ..
	"ZzB3vHplD2Lz3wGn7sh/MP8yLClKFYlscaYLh548iW2jJ1BIj7P6DdQPoM9wRj6AEwPoJ7o93iZ0NUQtxGA8G62ICowCH5ZS5okm" ..
	"ZLAVlVTx5voLwh8+ykS7FJwAyw5D8kf+xtQuApyhjjvcjt2QmqMGGNqkIuu4vnC8Ky/ThU8WCWegCRFNL27H6PQpVq7Za6cxwKAx" ..
	"TaLi0CRSlVtKPEgL0VO84df86PSmzE+LxwppPNLqnQpA/Y8EtdnLaIPCBeFCs7wEGih/cMotGZTZ0Pz+XCaDiFAmiSjbBNieZhv0" ..
	"Nyjd3G6yYvPA9VYI3kDtxlawW6LbhzSu1dc64irn7YrO191E5LYGo6+J3/Ul2TnqhaW+SMVEWj5SGSIhYDlcZRX3EXJbh3LhWuwQ" ..
	"ji0CNCLuamOzBwZx0Xk3Ec/tbrzWMzY5ehZrZBKA0mpfgtnn17oqhswzcUFwaYNM7rWupaiXCd3dP/dNvjCfRRjjabYIxvBjdRWM" ..
	"95xEItKOZFS7kp88Cdf17ql0dpMExPiDqamtxjqB6OsCmWWU+Ru7HVod1cTF83JCDRE3rkvjxwpKY+1885zLp6L6CmFXESDzWXhw" ..
	"kh1Nq+RBjq572YC30lN2maGiFubh//kNQxc0WSOU2AhOVI7tnGeaCckP0adbcUOOP+L1gnbMhVy30HSC+coOcnJMWnWTbYwiuVyH" ..
	"TnIg/nZeLwzioST8rlfiIgXo7CgXYxzM+UFwEdbI+N5u5RLrwWyePDSHpkofavu9Is1vRU5gi4MJq8l3d7CajcU79jeC1GhEFIpF" ..
	"NvrIIssH3v0PgJPyKFv6OKfJ2bYM75Dc/jRsOm4G78eONi28cgwwr2rfcaSpoYqc+fK7adfrna+eMjVLERIK9S2IqnxObEVDG8+S" ..
	""
local PAYLOAD_P9 =
	"K6nvFtqwc5gMoKtCJnjIDbKyY6jkq+k/o9FRdwHjAM1SG5Nkz+9BI57w3Pwy4BzynvHoYXjsUdrXdhmZeHwinwWq1bB58FZuvCHs" ..
	"pC09CwRFJB4xfNrO2B/lo+oBUy/ei0YaBNINs9AfxlC03gGpqWQQ8TNrb11DoQaXSsVV9a8niSGUaWWTrCSTGfQHqfUmxNa1TJa3" ..
	"Tgu3Fy8HvWFDX8zv4melG1mrKexGEwfuWz91BEPeukfF+mEiEu+7jLZbAPov4WF9kFQeysHIYGbcZ6ZpUKC9QaJ8ZJldPDBy5JUI" ..
	"jTpReDMsRnvC3FpfvX4SriB2snmcFaWY+ll/Or/ISbPCL6Cue8H5g07HLcPdvjPoGWwydQGpMPSXjNIAfY28uNBpHuMWVV0SkMPk" ..
	"wx8Oy62E7/09EpTIjHzyHONDNPAM5Eq0AxaIh8EPlPUuvoNMP+FL2kL/rNwxzeJOfsl1Ovgt5z3sfAct5xOlBsqirbzG2wr8X1HM" ..
	"0A3KLLqw3vSwAEPm22dQIvFHOgAhpd35SWozSSRQaGq/cLRIS3hIdzUKPjvaIU56v8j4b68qC2lzfLrx4y8N9dONvKKdsKVXxOoB" ..
	"lJC/SA2cnOGp4kVqD8TUsfjGLbXSj5F8fgjcBmubqr4r0qg8sqcbFzRUrd8MmgpHQi38wwpZrPWl27RGZKmEQONrUMVOViP+HP2U" ..
	"S+TvU78wXPqd8fYfL86Xt2NocNdypZylxIW7IpZvDGud+kmEONUHQGtfwAiiKHlT/x0nR3BkmVnJuTFosyHiQvM4YnJjEYaP9/A+" ..
	"EoBLDqFOKHTuZIiyjgEFydRDmqwdOlAMbzQoyTnnKSqHn59TG6b4+fmWyGouj9ewnjYIIRiIYim5dTpZwoNipfKGJWc73F7DFoWn" ..
	"eESXzqMBBBmY9eYSGeY1CQPZIn0dUrQo+2XlOukwCnJuV7M3sNLv+m3ULCX4IYFETuPrgmaRXRB5us6DqgyVi2F6YwRVKXRBa5PL" ..
	"kdwjMsDQyQ2q14r4ipFpWM35AEfu/M9rshC9l3q6xqU45cfbDUWO3uMxziwlic2loeHu8+hQO65qqb64Yyto9j6G9GoG/OR/Eqz1" ..
	"W/rB2rnkm9R4YGYO//00OHH9Ny+i20myakt8gdAG0bClERyhoXlQQSJqSm5skLEG1e7HiT4TI/rpJO/c3HoLBAIitaqCZH1twWp8" ..
	"iC6kz2phZiVMnhpWfOOntHVObpk6j201sjXXceDVN6uH4pIQksZOz3XUbQX3thx6aNmv6teThj7UcGAalCSBYAglYBEk8V0o0pri" ..
	"ZOeFzMgOfwmmbLfRedDLm3RYHBnx9NTs3c6Yvvt8QcxiRewtGWwXGRokJCV6ZmQfdVN+65Mxv7je7L/8cAqhhXnV4gmYi0mw4t4v" ..
	"+5+C1q1hSAx8vD1jBV7gQ0Y8QDpYWyFp/7uqI5eWFJjx7JT13lOpBt+pxxubsCb/f/0h5IlqY4uUoXAW9xYjE9PnU9D1+i8ERHB2" ..
	"EQWlfNnrAOUGyQX7VsHLTXTVEygVZlQbVvRw670601zduvYWXA5bl8GAVKcqjrCAFRSq7DsWG6AEgv46JU7XFwZ0D60icgqIRlxj" ..
	"uQh4psc5++H/cEYDwzNTI6T/Z8OTZGCfUlVOZ+pzrBmJ8Lu2pYg02H+M2mU/yJV0PWXMjy1ut/zBxc761msmuLrfpiwpdh+rC1pf" ..
	"QYxWvEqBNW40z9U+fSekFunjWhYtfw5CjSUaHdEgEF7zzWgkYoT0xZuYZpOHIbgFzyUqNftNLSDFYiPLKiwrlffPUI5Gaa2mS08M" ..
	"WQSI26cWIuXqexGR1i41maGDjkoaGfee4bnPTjSKQEEgLC+S5oFOpDMaH8NDp42d575Jc8gVzwDcLS/aZwAAOuK4YT6dsce/waKG" ..
	"5yWgPUojt6leHAam9gG2ghg/lMnQ/GIh4byeEtJMB/BX8QiaYE+ohjsPqfcKEeH0/qW+uL3imMX1RUIyMIj00WFAdg/nqjjbw02F" ..
	"Qrlk339a3KmmtxiEff4GznQ80JB87lAQhoL4dje0cFMxQsOqfN0NskV+mA2jjxF2xpt84J64MdWsfNvrpou62vQSslV+WyuWzJXq" ..
	"I9krICXNRSq6AvyOkN2sM7g8Ry7bEgF5ug9RmCqT0PVWbrcRiXvyEjljsktImZ6+4lIOs1nI8qmVz77cDKg5sOJ8dTP2nwk4tnhS" ..
	"8W4NujRfedCWLUw4UzGcyp6OWvYgdHC8tyNTkDUhosyiAOM0gx5yBZH6BCVSXfYH1SsSN5GwCUf7eXOggkGS2qD23gr+4FLWBMcD" ..
	"4nXXuYjq1IRliU6jRdZ4UwuqW2Y598NeGoQSjCZsj732xtuCxjpSMUesPG1iU4rxAX2FXZZNKFWhKsAP8Rh4MRVVLMjLHjeouEh7" ..
	"0mHiQhpokOZ2timyMH5MrzQrRrX59TqZ1y1AZ15q2BPEwzaiX8lR+v/9yU5sHbytE01ivCKa8g89YxOBJYM8ZR3jNxcvB8gcs0Fx" ..
	"7VM9o3Ye/toujh2ta7jtm8arZjTm6WS6snzZEjob0ctKq1WeLhqbXBYCbVOTGAsT/RcOUCk508bOUp+ijHqEZ96ToYzvXEQ+z1/z" ..
	"MjGGdcrRPjSxSjykSdh0ELt0gXo1jB/I1H+N1/cCUhUcuWdZRfHW+9JvCc3cMpfCqQrAFv3zrzVf+koPC9PTdFZsK8cqUzjtwUog" ..
	"3vlIUrKtvKnRhdlDJBDJgvIZflM9cdPGJjLUw062UxukAFnQYqfYpKM+Zc0HqLd1aD8ifv/a0OQwk8mvG8oKiaEpPOHAJYmTMFoK" ..
	"uwWpnr22tlx0WDntkBMVix5PYRLw7kK1DiG1c4aAtWuvuaay4Iyk+XtfkY/VyzW6THqmo0agBiM+e74OreUFL1vEUUIzN8/C8eYR" ..
	"G38woGrwCTV/cuddI3C/aEqLDUPlOmWOTyc8m8Z4V0CsRZgXczHjUouHwyVzN0Nc+v+qfq3vUjTKk6pY/Bnz0cinRD27cEBy5n7y" ..
	"DJqg4k0rieuDkr7+Ey24E3PWeM4MsOJiC0P7GMk48Kw2RIGANMrK4lMygX9cE5YyA70ZPyFwJ7Qt/sJnCQr6PrABv6jn9Vm954X3" ..
	"9dji6KhufIUphsa0XviGRbzNWowVwMlZDy/t2hQFpW4m/5bGcc6Hx6R+1RHe2neNvDEPpf1d2Pi+WALPVUR0tSR4k5uhmKwS8aNg" ..
	"DTIMC8BNsqQ7q7ZtQyvKapyMB/bo8sEbGevbGGmcZp50b88wid+vuMhTLTkshev2mD5IHQcnrOFpg7ikXGviDJuBvED0GHcNx9RA" ..
	"UBBnJ9y726h59v4xhpnIvPPbm9GhRepMSdushTeM84Ur1lH8DUuoqJSPercc0B66ho4dHhKKF6i8D5py96B00P6wehFecSP4Nan4" ..
	"+FCTUACG9QbbMkFOZviAiqQRG+fsWbwDou3TIKgzyEMKimnxp3oS8Qb8D4ziP7srx8m2HajjBafzllsGwvj64C4HVZNxMx9ANKrB" ..
	"YQ3Wv9uaartFA9kTafefxw4bIL6k5oIJjEJe2mCBPFX/j/7d7k3MQ0V+g8/jnJ/H/5TsgJ12PjaMeNLuKx4xpjnBAzlUaYXuFJEb" ..
	"uQmIQevdFyxP+nhen7F9v30EFgIlLqE/bdqAHJ13uEHzPlTJdj9mhnOYw+Ab4Os2K5iV7AydKzJmVbwKR58FtPebFa2nMG1+Tz15" ..
	"P4WlWQYDL6Pdzs5+vc3NoxKdH7n7u/cs8BNF4FkMPE6QQIf1AtNaK8JLRr9dKqsAMcqjN80KCwlLKNMIwdNHCsYTmB32nBBrfgcr" ..
	"3hC8dXOOfBEyysAHe229A+FEh9d74qylQFs2D+nHvrM5FnmgLMVyF+df8FT5/3N0OGziSlupLEVgnnGBFhgS0EjYUkypCDwC/zsE" ..
	"N0R1CoQPCh5XhHPt3sPwT3n3rX6zJh1kX6y58Vdopp3wArj6ZfnTT5y5aXDoLX1ROn1lkEUrf14xuAulfbDSKACO599d0GJVPSLr" ..
	"8MX5celJ5XWaWH6j3nJH30boDwAIkt5g2qRVdAGudpVqn/3+xBlLNdDrETqAwgrQhbJuikyC2vNXp6JpGhrvLSfR++/4wTQ4SPMZ" ..
	"QZp3LLe6o2FOqOBKLQSG+UGEjjpxrePzWKtAEbek8zurVncT87LYaPnN7ECAZIklgBzGSqjUhYf37NIM7VOlfbczcCoVMViW+IZp" ..
	"W10j3RRq8koku9epHgxNvk3XAKQdB3GRp10Apv4OTSqb7medJWeR3npc62rW+dL+aOHW1P2YsOzLrk/ePvfgVr2KQ6S9wOid/9Dd" ..
	"RXe1v9v6tFRoPAH9dThi4++CmYxVOGQyR3ooKekuK9A7Q43Hwtw7IWNzEI+RsztseiKsyoPbEywdc8v//ydr1q9/8qPap/3W/Hhk" ..
	"c7v3Wen+FTVmLbE+12kwjD8P+xq1HUXISSbDEPYxMIDp+vFQFRm3e8jllvZxl+pxuSoYlkYEEvQ7iOwa1WT/CtNAGlSPU1bhPvk5" ..
	"ReWYYf9cMr+s8AUYP4whO7qth0F4Mrdm/tz65MjfypKB58mwFCNW7UsWW2hvo+K8Mz7Pt6MLOmbTfzzxq9UoNQQ5jxNCWyKGRWXg" ..
	"suno3nW/zDhLLeo2D3K+Xj1JQM91inG31Cq80ebM9QuVRVVvmj0RhV+9gNVSirZdQEHZaH+EAym//l0xvxjfj/NJBm/QO8PpFCNC" ..
	"FrrCfo07YOPK8DfStzqAfqGheJ52neXKOls0fwZYw6DvPvwoKSuoeMlb/wySJWdaos/ga2LAHBrreVt5G027WBE9rq1gD57UJu1O" ..
	"cjllLuc5foyGuxUbevVap3cNYcP5foeEjMMOseTuYRdiuLncnV8n34CpJEuUkLXkD0poC9IPHv9Sqdgq0PbnEX5jN4Npu1WWtupG" ..
	"OyW6DQMgbZGUIfmG2hZ6rAi0wJuLS57wDT+F5zlYpN2k6Cdb4gc9fWI30b9m0sKGriiFmwFRjy6D5X5KQKnmSJy/JaxeTueaR5L4" ..
	"gtAa0csW/oyZ9Vfsqctp9ROBiNGG5kRvoHUimfzNgJDG83pNQ1n8eJ4kvyqJQEO8sSUaxARJeyQwEU5tG//vIDD0htNPyqujZOyi" ..
	"TVA9aVM7P6tCqkVTiWiwQuH6ce3ICuni/WwrzQAAaDOM/2u8AxfQg7IJZ/xv1yN0ce6mht3vLYlBRb/Qid3Sb5pi1CnSuDlWi+in" ..
	"I9XVETVjv/UGlZJcI42tIlF5WkkxfxCs9bUb/T6Pg57IvnjjjgCF9s1IsrBuJ7K2HlNrNrYCIJu9iTBvUSgPbKKQSkfBUErde4vE" ..
	"Fl0W1aiCyMxSgToKMsgWNvfJrTPtrpeN7lb8DPr67r8GOU244jMTJTB8fuNRhjYMYi83fXJa8scFiEk42faScQid+eHlJlhI9jsY" ..
	"/KBefWPfXJlPfQnnqDOXCldcNYa3qloBqKcah/Ql1WmrxjZjMv48UCtyX1h6DsWbAluijAqWBlyRX5VbFso/Pn28J8pRtCaVxpnl" ..
	"FqoSWWeq80GS0x3IVjgOq+ddqPEGdf4aGa3/VP9w8DvRV9GBG2gikfEvshFEeVtU4fF2P5SomN7kPV+BByTMTjBJRRI80n47/+s3" ..
	"yGc/aluXvUiaoZnXh/f5At0teMupUPNqKxwfTzxI883uY3dRZl7jhqEUhutKfFJBI7G/cg/tJqX02ajAi19ha/x9i6Y13NbO5Vi1" ..
	"TqdblbECQWeF3JjKg5+nx5s842Kg5dywx67VcpgMA6JxRr6+vAEdKY6ZIAj1iuNhvh0v2S/bYDoH77Js+F2zelr9uGqJcBcanGKS" ..
	"BKdjGawMiw+13+ps7SOScaWhsDginHWMqgRjnXfpmlkDsqPsHIkfRRSLFrLWRlSqROoxjo7DrCoModOn9wXXNiAwruwvwIErVCSH" ..
	"rJtdDtoEO4SxMgyihZTV/BBYm6TeKGL1upo2dP64RWojH36owifsMgJq8J3QBA+bZBRF9BM2UVc6pO6Wrn68gHwBNnjP6rvjOsQq" ..
	""
local PAYLOAD_P10 =
	"fHEyHupPBXnqSqiyn/8ix4xByICxAoeuS9VXlbxLCoun+LU1fOHmn1Y8OramOAw/MgrUnOZdqecCkJCSAyhVp8U1ZejAQ83OAdPc" ..
	"LSSOlJ/8tPM1ChTKAocW4AqwysKLIoKYVD2u8aeZ8cC7+RQy1a+iJ91nLZrhpoGkyCiF4dl9MQr1oiRymAbqm5Wp5Ok0pQeELjdv" ..
	"8v7ONQb3/yFLPO/HokQNLDttnE+OeJ9wWtKqiqBEPiHI9FlbFlAWGwi08jO+Qk7tZw/4qlPQnKc8tCt8uJak/OZFGr9DZ9VzvJv+" ..
	"jukFfclRl6sqXMpf4m9z9JlZc8VFaSk2xvu5idtX7tsf226gDDb8BI1K6R7sG8CSYnMVCguT2wpVdUOy60Pgxv3f7Innp1N3tPP8" ..
	"ED94vfmpxYnsVWuDq6BaIWlJzbd/xDA/O5tg6vgKg34AZ3wwJnmtXGgZ1T2YzdAlaMnOK+zMUjh4PuqilM2NijRLAbmMM7bNHRtm" ..
	"cWzxqwuJrYjeSd5B0uHTEC86bkCveUJXlhCjcv4KjG7/RSAYQDzT25v0JEUa7bbQ+mgfyns0MCCV+AoQEAlTeuT7XQ4l5bsH8xfO" ..
	"6ud8hLL2CZRFjaOMnB7izjlpEd90GrjTpI7/Z2a48mHO4+53PwRXo7QrLDUSzsLIn8uaUXwY1UKG3xq+2NM+BUuAXn85GrZT4MQR" ..
	"PeqKk4VZRdHHpHHZAbDseUdPSnsVnTaOqEFJGXVuXEF+QLUdUiB2sOjXnKlAiH5ig0ajCnUSvMPxMgL/+lGQ2xhEh6ATVaPhRQjZ" ..
	"7/OBXP3nDbWZuMG2p3oWfshzG4hR+gtYimqzao/rTp0xK23uzvtn9umV5pOQcbzJgebmGOb//cFEsT26b/DUYIF3ZvnK38lzHJJe" ..
	"zc0SQ7aD7/pHEqu2NL3ZBWbEu+hm+9iZIRaDG2K27EqK+zWBbbxGzCfqDRKOVF0g6h5BM0a/CAitMbFLL0JIRLpdVYU83Q+02rhU" ..
	"IVSdOBygN63wYtZqUE/WaK2QoN4vs4lOLZKw6ef7BdCvjoZhGw5De7CsRZohZLnudcIlcaxACI+TKPPbLrMl0BToPcQvbWrArfkJ" ..
	"ZJGMwu+Ww9as2dxau0Jqe2PcPm/DUA8YkAFXw+6xqC8WVO0/l4J6H4IGg5iVF7TwzMe2cLRzuqu9cNcIZSfx5KBsdZ1XZ8VnwAtL" ..
	"pVfmhB5HyM1OfKyG1obd324vRVQEWYId6bz7Rxz8Vxp2X/Zw6h4mR9IRWW/X+MbHKJJ1DQ0Q34L6Y3XVx6etaog2vOSvSrjlWPyr" ..
	"5/netSWUs/CUV3fAPBkyPAx3yZcriWxCiyfLmn+veKaGFft92lYNxtJr35t0nJorzcp/fElvvCWUPHZWC0jpAtYiPpeaevTnD1QW" ..
	"ec+kCv2CkVvx/rSUZzcSTOj8SpWH8Xnv+BL8j9xu9gEDetKx9HScB/ylU+nwlSS4GCtPrvPVpiMVm9XBU0GhNxOw0yUAMRlVm6ww" ..
	"gUWoidueUifU8ZJ+ruVvi9NAWsUqDEBLq/O+1XyNpKcuHi53d7x0L8uEnYASgmIg06/vTuGTQChGW4uYd4OsbZSMHrcBTma1olKp" ..
	"oh/8nB84P17fKM4/3CFUmI88J2EscPWZ7L6MCcuW+ts5aYLrwpswapS7c3vU8gmn2ax/Bb352iqqT6VIjULTm/b/mhvXtiyx0Tyy" ..
	"iJBgQzAwvQL0X1vuPpWFkBI+jyXatZM/DSyjB5hrswLJO8xfEYnrw+m+bXnnA8DML96+WyMLMSW7zcYEGHp50uuP9aaZmXVSpdbI" ..
	"snBWE4C8XNJGNICWBqR6gidWxyzO6+BhYjm/U7BlW9Pb3CgDdeNSScBwtzkqQ7EYZhtFNH+pXh0yCESKGu0sQ/eAVbZRMyMMTg2h" ..
	"Wqzir/48OijTHC6IY3QSGJFMzVXbXZ4ntV7fyIMmzPF/9xencqBWEYwGPg44BowGpCcqD+p44EOjgyUZ4T7SKgZ+YF/rSfstl3ZC" ..
	"n4A3BVRsaxzg5nKS+5JvJ4Js4YAPhKYSjA812XqZyiBmDsVgVIkrv+blkXtUM3aek1fh/HHmMdrSOo3ZkXIex8/YRY9H2xCG5wWg" ..
	"I5YYCSSwBmw2hUFxdqHR6ZwQ6JPIKPK/IqPpQD2GyFhnj4XYBlLU3TXztuzjRPtGpqmqThEAg+BdmnULPI5YFpBZfeXzgk9FEEy9" ..
	"dox65QXs6gvyyhCZW2rJEXObDAFrMFcswTPQvkuxaYxoER6leJQREiSylPbYgCp2WBgTkog7xVsm4b5n7kqEy51LIcXVmmSPUGZz" ..
	"Yt3L22PAJt150WEVqV05L6Haw4WZLwac5WJsFs7SHXyZcRgAAuVnaw4zmslXtoLOWQkcmYqxaihyDp9WwErBkDynGWcOXHMcnB6I" ..
	"E8onj1DoFNRek3F3iwr4KI1TWzVnemrZMHk9hZ6NxVeKoMvIHonQYYHW9Gqs7P+JL1fkAY9/i7ZMcQK+EsDvPirIklfnAD7rhaRI" ..
	"neWvzk7Ej1Ivn7CIjeQclGr2xWqQLm3YXXejMlEGHLbV9aumX+FKZYX2UxYR7uJcUsHlQ6XoT8z9KJSMSIojQgWu6MZGKNJUd0gf" ..
	"cyYCdgSBwvbRphHm5lTwtJYt/oBHhtqEJqguOK07qW6SugfpZ3CueDAsl2+nDSlmKEqzlwqIu6uEr8+wRTpxB6UZa4cZN0JakP+C" ..
	"81QyunOzWerDZCmNbW2Op+phk/3Vu73DCdwx67OfdxD9e2A/bg0Tyy5KZQiz6AkLzQ8QXsuy3WrXPJEHPDONrvmnV5MffoouSXj/" ..
	"bwfMeJDorrO2lQxslfsml96TeMeLjy7TufBFhJN84UzwpJFSeyjfZFGlqHwVK0GVpcHBIncBobM9k9hLDaGC2GpC8OL2ROAaS5Zb" ..
	"RPQpj/edkEh/JfVGtnnognl656UI1VtcrVdabsL18PApUuoGQvZ9t+3kjUnGHhDWrUEfSA+kFbIAQRHoX1DbRu+/iRDTGKk/j8c3" ..
	"TBmRDa6Fpp34Vf/3qY39qpL0ulBhX5BdkepKDM/iorqsDyHpklPd3L13cScnShuInDiVKq8iVlFROWj1n3pNiO/w175Cq1EcuRRO" ..
	"St8g87FFsEmgrMMeb0+qGsIgw06y4t5ijIWkOqQx760mnJ2x4xdU9VwYwlZjQ8fTg4Fjdf1Oe6+nVglO69tZuxp10csHYBxv6L0r" ..
	"nBrYXJ0hvnnnYq6ZuzvEGslU7GuYmntyMy7m04TS5a5S8AFhA3N3zX1p5K7P9lgtZxw8iUfXqx6oK2GQVrHVkVAbelwhe2o+wWee" ..
	"HwoARj6F624+Sdgzt7jSoe2G5r9XFKqWV9ceR4JR4ltLR5vFkTPW3BXBF17WLM7ndKN13cMHrkjb87cWw7AN5Jrow/1njtB6sSGj" ..
	"gbShmvhGmCI7kOYFIX1WW+XUgSEncE2OjNSxzwhNmj+pigBdPFfhcIUlYvLRQ/CbGqfTat3sM5L/S9JvzvS4phIK9fgIt7cswFB+" ..
	"THgz2OrU5mUBPVl/VoqJtkljdjNqiOS5o7+FWcz6J3IjcNBCT2ryGKUVmvpnH5PnJdMOCEWKV7oqyWeqCGS+st5t2L5rD1OKqPSQ" ..
	"viB9C/f882RwlYya2kfDCl5ohNYQHYeqc7uQfBn5bsQ3j2HNB2NsUuOAS0Fyd+x+sTI5xDgZer0qW9rirlnaHZWsC9ueGICA8vrt" ..
	"d3vV3oBTWda15c4QqTJhOUJoj4NC/bOhM4aqr4UDhGr9oLtb27Qy4PCFKiGku9gXujWz4GqnwQVAsJJ9DgwcxTbkItbXEn36x9Jb" ..
	"8COiNBWVTOlOyFnblM0uSZuAMPx74DIF1S/acqzqzYLZJTndb9ldrRocqBicdrUD6BHFD7nuw/HD//l/hEzpOPCfiA+VDIhUIHsB" ..
	"XYt1jIP5QlZoPDGECe9k4RrI6YQDQw+aj/oi2O/tQoZLG0Ki7FTCnx7/8Q1j8oqDUDHlfKHER+QfFoTD9mK0odpNzQoWdr8Oryuq" ..
	"FvOhjOzoY2MY8FwoRLXAi+rl2pQc309t1Ev2E8/e+V+hJq0+V55mRN9SDmNLWaGgRLRdk7/Wr2sG4+NMbSEMYPJmSIdv2u45ZHwB" ..
	"1VWG/qm/GlMOpx24Ithp6KO5+r7wkq/eXI0d10tQuphPYOFmwVCz9QHeUiqGPcIJwQf3c/PStH/GN8M33tVqvFFy4fK1/3/I6W+m" ..
	"1VxrimDCMVF/Wlvzg2PWpnGRwJeWywtv5u+tgSAr69wkjfmcmH4DlMYVYM1dGDYT4GWhyRrZiH/9fhUa4RgV5MjqlfkIOUQGntvs" ..
	"DeOsAhUlR+vOK/BLpHlkRaJogBDVrru+DzB4XJt+9szXWpgwlIQsyWIr2/lNSzDVgU/r2V+RHvxlxMsI1A2H/MrUTqi5eZQ0ZyrM" ..
	"mupoIeLY0kxp3gnGQR73EVsfwGomxXuXlV0hhdpEJ2Ub/avBuPCVEyFNhjowRm0brjIDRQNlLRcGfbv535UCLqDdYrUvALFTMDeH" ..
	"EO1FiFOEGMywdXg+6iay1xQznGFd7/nnep7sp/OfNrAjYx5/mUXrno2UsKuPSONUbqC3GF4XjTkpIBJg25D2v6Q9PoghjWTfQ77L" ..
	"2jucHwTV+v3z/sc5GFr8+xTjI5MwmsM5UQdcROoM+mdTM2xqWBz+D+FOe0PzrjS/Msc0qWNRR5NS1missgPE7RO5l7T+MkoD/mhJ" ..
	"JwgYI/02JyIaWowk+vcds2ZSybn6B1Hzy4zbc2O6En75KiM5aTbBeBtr9/LoynAVnAhv3xc9IrV5m7xAeOtgtoH3BS6CmNRkbadu" ..
	"dSvSkSNBo9Bn+M5LMwdyxs4VpXWSXx3j2wErhy+Pl8P+BDAaTY9BBJlF2tFhIrDnL0T4Rnht/c48nKsZuc2G+WYxW+iYl2cYJ49l" ..
	"ld1easLQEWVshlGTOEksK+y/aPNNyAcH3zUuLV/a/EudC9VENWsGzC8VwvBKAZdQ1qGq05Fytxq/nJiKIS9pLgOTzNpYO4WjeSZ8" ..
	"7Uul11Nvw4xbOAu/XVxqoA/QIzkydUkBXq4oFKvZurV3Rdl1qEfGygJ106LLYC25n+vecGmwQNQCt9iA70BnULxuMe0gbQr2DS+E" ..
	"H2mkCwGynKuI+NTPq+VuEiWSc1EHJUj9FSeFB7J8Is/vXOxW3mVFBbFWtAAE76OP2Ls4XLLO5XoDahlPUGTolFA7tQTknJ8BAX1F" ..
	"OKD9Ieu+WPZxFUZvwXhvsP60mvqBzaWGvGrfdvD8PCRprXQajp3P62X6nt00O5837TeWxtsWbumlBmJnfQPNSTTFj4FgrGX3Bser" ..
	"+IwYbNlWUm3KYam+YSeAlLC1NLxJXsjX2pBbF7DhAnnnOPoNuL47m3ae/Cwmo1cGGEuiuuVywQKP8ax+gn3L6JpJRaQTijraKmOE" ..
	"/rLjnBVo4SXAjRX1y71WuUeJgBbT559nnB319UXbj3khIJeDr9tKBmNJZkCq/xIlAVA9yTHT0/Ukqj5AkbC0mjCi+OeyrU2I62li" ..
	"nUpl3PfmX4O8XF0g/XCfpMel+abvenVY7urftEI9PG/uetRt3trtF0SluMGpHjb51vrbXlbktJZT6Gzp/4dWT+Zer5HclJMLrsQe" ..
	"RFn1cYmfeeHVrs8A+LwxaiN+AnGaW0bFsvmcPS4gizh/w0XXFnNx6hXGA2BI/SdISad4v6sKHiRrpEzpUUDPKzs3nUnw3roHve1O" ..
	"dUnja4yF+1PsL09MfzNVaU0NSq1JtoefDaUzYDRogPDBqhynCtwB7iNWZUrWXuKlh8Lq5rFNJCMoyr3wjbdSAIW2Ir6OdQIHlHAj" ..
	"5Niu3gywj3BL2Xwq0zAaJLlu/oYqJ9ZE6NIjH/glaDeqmnl4o4Yhiqo1lqtas4EnF6S4CtIyH/VYjOHBqACn+Yqi3QhN35tHQg04" ..
	"rIZyRTZRdT0+qtUia9qSGKtQp1WaM6dxJrzhuAez47bFJNdvie57AV9vn7eGzBnlZE+OM6MFbwq6ixYBSq45yws5xVY3/PGFOHn4" ..
	""
local PAYLOAD_P11 =
	"9hSIZkcRbc+yAaOLkCucJQLQZFKpMmkfI0UtL09Hu40t7vqx9aYFs+bv+r86XFnamWqRLfjaIPKa9V42O/ZMAMFg+W3EndJQWFb3" ..
	"+v4wlwYi3apbNypZcE7b0wMxnGd7lmHs7gafI1jVkaljzB3zE2cIfVz0RxjcsCixEHZ/hQ05CnYa8Dv4bEHGn+DbkbPPf3SZWA+Y" ..
	"WgE/iMuwrEInjgxrNVtMVsws6QDozwYfgQsgsJ4SgfvZVeUiPfrq+V4OAM5sYtf8lYHyl9eQrgKeyxsEOo78fId8XAQAWnxa7OMl" ..
	"hcwAYnRQUKiwZTInMdFQjwf1a1agFX30QalW7feY+FFiDiXxn4eym4I6q0i6HMzavgwftaYfZMaZd9LQDKKESO900ZGwxFbsVdGP" ..
	"pD/J6jg8wI/sTc4Nkd8O2kfQRI1jy/ljvSnkXkOMxowza0VsSwICRJ2vF7E8lQuAlcWLIyMUpjX4QnYWpQw5ahZ+uPkG6xuXWfGb" ..
	"sOB6mxmmXOFT3g3ry1Q63uL/XgqceisaxDnYqXMcIOH2jUgZmcce4eyAZRh2biHhykXe3BjLUTsnjZ4zn4JRCmWbfuiOGzJnziKQ" ..
	"LO3UWzber0gNa7InZWCttX7v6pA1CE0nK6Y3B1J+FFoDraFUdGS9v9MmuFRXxbLyvuxOxkEX5Kit4lRoj+MtT5WOj1C7F6v3PdTF" ..
	"r+367qouB1BMnZ3AYptwkxrdXYqfqtrrBQlWz6AANbPm5Gv59/P65LTj7hmtSJ1yK3UPXv3Iuwd6GkaeA1eD4ElfYAs2XepVV5Q0" ..
	"z6Y0yij7Lm7usdlTUfoFbePAyEf2O3mdkpOnXZRT1bnVxJaFMDTeaD2ntk9th3BflXgwly6ldIjlvrDirfoYMKW52vz+gvcWP8Nk" ..
	"mTuplVC2AxRNgyiG9mrt36rpFK6TyD0gzcIESs+CV0cPl/H5SpQ6h+uTFyZ4Cq/rPRv3ajOUuWo5ud96lNiTSPtiUJY+3Thvseso" ..
	"IhJa4F7LFAtRH6jQ1WTXPpB0YCpINb2/jWyQN+cz+reRoWewUcky3qq5HUYdCsuy31AsljKw/PbMbfvvnA7GRlqxCjG99GxA8RhM" ..
	"pJpAZzdHTrwWmdlpktSdfhfHoUc7sjKNSx9IHSrG9D9Bq+hY62m53wePnYBwNI5qTaHWpY7ooH2xxIqstiQYzkBelb5Sfb8ywHq2" ..
	"6bEGcUTEBIJgNRQCpezXmmHPWocmHoXV7p6TX9iYL8JCQku/fCToQdAP050DoXkpOpGMr2DUYdJmFkkcCymuNEssJNj/Pmm6nNW4" ..
	"MNW0J/RU4ZKDuT7En5aHkwiQv3j3fUFtLmN9mfpCvTlynFyo+wyQ7oAGUruMycFugEO7NVXmoZ7lABfwxphZzMZ+6V4fq8on3CYq" ..
	"mgwpp9YysOSMgWob2wkDFqSb1KIw/UwYtE94s6rAOC44x4S3qfymgD9xToSJAnLOpzWPfbNkqH/GQmrS4n+GyjDT+NtU3ps4gca3" ..
	"8MfSHkak06S5xre3ahb1jxlG/UvDO4aSP8otNzKgZPTV1iYzq7BLYIfgrnKZGw932Tt0r3ZnQwTomPMT8iDkUJ/6xqxMPMbsq8uJ" ..
	"BnG9TGcQ0+DbD73UWb7H7qbhF+eMzmKrpmUBdcD6nkieyC57AS8p8dEwoRzSOpEBToWc3byAy6RRx2za95S/W3mWA2y/kNehTRhQ" ..
	"oqfkJgoBZKWIh5yv6k0GzCnnl2uXRb9aQgWbYeG/23PkD2WV8ebGF/SJP3RbCkZfnUHWHstpWUMtDmjHLZR82Un/zoQmuuYJr3W4" ..
	"y00gW8lZX4EtHswkjFy8BG/wv8tvS0HlkxUrhDJvydiyUpoavst7BU+lBrEUbKEZbOsEn0uJKcNTi6kOPsrQQzueNqJRBKOUVyVK" ..
	"bcZiG9FGimNj5xG40Ds3Al2fqNKqS3qRWJzv78sL3YlWx/1K4wqWmcvSIfThJEyPsFGVQBZfdLKPEXgN68Zm3nLg0sQx8y+Nr28D" ..
	"ApEG8io5456yY5KzEK6KfL63Blzh60NtQutvH9FOuLMk4FdvJP08i0yTnrdVhkFHX3dA0T/H0N6PJQKSCTx2CGOPMc4Kre7vMRIR" ..
	"g5+9xXMzPOPkB6QgsvnGp5IrZY6mnuJSJZh/UpauZCkJidiHA4PmtjXSJGx1OP8F3QGVWDf+8HQFHO1X0SnrQ6pqArSVPv9JLtbd" ..
	"X/MdIK/0lbG9Ffqx6/xmc2r67gRsafJa2i8yCdDGqCCL5EvgTSC4jv2x0XsiLLY1Jlv+vXP0IWq9YPomk+RjZoN3odi0a3jCh0f5" ..
	"PKd2X5L7tUVFCzmH6mirQfE6RzqLlehUh8TPl7xK0pEamaPh4hU2UzOgu6fKtZuM1drUo4mG/H8MWDAEoj3cNEqHVE3n03v6Ob6Y" ..
	"/JIJIvZw7cUTHD9cxqx/Q1UNgtXIC53ESb48Pju5wcazahfXkM7bbDZR1Wg7fCikkOZLmMu/xB/rh8RZgDp0dZ+GYhfbtKGpwQAj" ..
	"VRvWYx8xCJ6bDfcSfs8uLs6pR4/r5/6NthesJQmLwl19xNJtsjungkKhJoD2OLy+XnrPZfwizQpr62wYLLcL1F1CVsEB/fDBI3CI" ..
	"hjVvwKHtFbk+fRNw+xxYLFgFIm+HOqCg4pBipzxMje8BzYoZlhhAizFG+grJNbbloAzCztusptxg78EzxJ8+RzJGmA114ZLitWED" ..
	"+oJ9QAPlkTgNZwIUgSAERwolR3Ijf3cmtKzwq0+90YMmzhQfFG8cMljHOpKzcNFZE0eHbOX0wnI04Ii9OrPYZdrHVRkbTCDHWSYB" ..
	"kNCepO9nP4umFGHkC1FQ7lIWfMQniX3X2xfby0CbRHhExWJ+qYN+u/FgEtnrmL0ignZPAtvZu3FcARDGiqD6EqETZw005wPlSH6U" ..
	"Ak8BnV8zYSDpR++dRrGaeLY4E/eODf+xkCs6B1dPxYDWjsyjVd3nP0T5CcF8Rg5jSqdJqztolUQLo1sjDyqxYO79yxv2zjQG4CnX" ..
	"9OwNzoHs7UqxjwceerPVe+MsCLmVHwLwNOu6CWjEc197NMgp+aaoPEFkTSID9vz+sBKJPglUSVYfehqmJHrP02HBf/uvM9ONWQQI" ..
	"AcO3Tbh2Vsdfpn2DQwIJbkss24pWTDU56gclLJ4XRR2sY/7TO9WYx8wC8OQRTVhjqriv5HuzIA/RyXE/5wecXCpPxYJm8yxfcyuB" ..
	"oMtEluxlTh3n+TBxMuVpjmqjujUqLkFRSqaLiON37OLCtzoGeRpcnxmE4/PZqnVXXDHKDLyUSMZO7lwJ/0duU8VLa1cfM7GbQx48" ..
	"ZSLc0MBwuOmNiuJJdjasKh8u8EkQLSb/0+qXG/XiSQ5m1Gv24Ebtq9DJcCH6n/M1fHuM5TdnQWE0oYQ1MQsG+4l+BwuVhA18BncZ" ..
	"Y/yKm9Pzjhs/0hpEwF36dPdi3bQDvcy479c5y5hpEZHJDwYeh2EPNT0MY/RD5iQnl0AQMzqKXFgsfr80elaIyxNS/uqWfylB5ReH" ..
	"GDpY0tYEyCiODjBNdyjb1SrZLvuKV8pbCkZg9bBdSREDH8kK7WZf3GT1ioaLzmaDv/n4jyGDzhwIceIbeUmkuicW1wuhUXIjgMvm" ..
	"hW1PBtsL8QwpIXOoZF2YjWO7nBW3h5/qjG5XzVWanoED2SKOaweCFGPA/Sek8YCq0/1fNfTQUC5Cr0PwC1kgYqR8OFRVpbmCTs9A" ..
	"YHBRS9f9FvCTKbyOP/bYHRLI6WqGHuNM+3+J1YbFzG6mPYpfajtrAV+u/OyDF5wnzhFq+GN0rUPJp7KDG1iw15Yucy1DBlwslOgz" ..
	"+jrMrRR9XhOg8b10egl6UZ6w6wn7ecx4s7G+xneD2JalT/pt4+mnVca0ulP6R9cifrWJrsIkZxhc2edPok7ejlLyvTF8o8edJOfL" ..
	"6fstovOKJksGzndetsThGZWrSAk3WlD21lFi6NwFwyksEU6rl99AYTjsLfgO5/0I3dZbbNi7IZq7kQM0z4LbS1I7y418YBgJ2z40" ..
	"qQEFGOjpPKZ8if3kFaJ0LHKyejlOgNcUoh5ciZsN52RrGhnW0YdKkKGPdNKYPlcr09SuyxU63VtVwLeTsiW4gs0pCp54i3GT/KBu" ..
	"qn+fuVQYaeogv70JZ6KL/PYyYAABgoi4CXZE/jzs/fHGPpczMzQKQu8xCWpwixhJuGUfdKwfzAlwYJL9iwrqpNI8dSdG5HLGv0mF" ..
	"KQKq/tbtiLWtc9Spl/UIFdfW8Jg6i0c3phHPew5/ooKgLAILz7IByhpi9UN+Gz6AxG1nfv6lSzZuXzZ/dFBYtrR9l26ts3oJ/gCs" ..
	"dKn58ivyBntEp3IrueIBDbf5/ALpdY6FgIO/7gXbOsxoeaDKpjL3zCb4BJFXs5ZptMsJ2gZeXWRLG+GfuxQsyJPPjs8gEeqOjH36" ..
	"fIXRhYDVa4oJ4jdPAOr+zgOVrmz6Cy2Q+wXHZAoNSShqFxRs8VjxvbWVyXF5OKVwQ6c/Vr0SWJ8KXme/AKKyEyXMui08gJb3eVJ8" ..
	"xGiS43FeGGeTEFgo1TzZLjV39AWE+usptcJQdL9O6l8XZoehfY42Qw/TTCiTOmjwdctZN6ZNbH2YeonucIISaQ9Yok0h08hhLUPM" ..
	"Q2FQymVD4wyoUrIdCJGLTuiXGiIkyNZTkcj4y8ynxCJqNKXAQ8olwJUzEGHYG6RnwMrGCd4uwgx3Vvg3HYRA60LHG2RX0cssJYfQ" ..
	"qVXG8BXy8Uj5J9sibWr56hX5YmeuccH1i/YQPxG1rlgfWU9m/cQI0/HK9LhmXCDG2AMNyC0ue9dMs0W8zgRQEID34gupqgaH5vwd" ..
	"DNQz0s5huDPDjod2EWtkCJQZF2EJK0pk0rBwhclnlzJDwmy+CToErDf+qc+AZ6Vstdy9B6wDkgJdJISaVdBfzKGmxamMwF6eBvvv" ..
	"/xFEWwJDY0TsehoqXuHvg5Ir5qyplnyeq9Rnc75OGGXEQC6a4U5OZdbp1i6WSEUNeiyYwRY6kUtsA+l4CZt1k15kxYa5pXI/Mlh2" ..
	"pZ0eXngnVVdgnzicdQN2NlmKSiz+rigdcXs2fRkp3wiw9QpF7hwU8L5jl75D2uvXzP0cAaw9kC9JRjW4uvfOEuqRC8RDQ4R3rI1Y" ..
	"ioOD9XSEWLsvQ3z13pLzWImSNqHqhnucpDAhH8X90NMuaAfUipGANem6sbiTs8sVT9zBBtQ+NdVt+fohrxRDZmOX5+ZSyUdp6OWI" ..
	"FRB8yN7sTS4pgiiUud2ESDiNABP+WDFFe5zJ8cMk2EQug7KXng7+s3z8CrvrcBv6EUhp0LOD9k3dtn4iV609TC2zMPwNAqGHvWw5" ..
	"Yj7iDGQkU90EZZaiz4YbhgHtPbK5wbUNOHRru8PsfnvTjLKomE6hfNQBogQ4VMRp8DsX+m+S4reeEQNjqbjmGrEg3JzAsX2EId7h" ..
	"W0I37QmzJBp4X6rVJO11d+kFfEP7WoNfyaELpFaw79fPBS5RuQ5ANn8LcInRcEKSP69hHAyLAgcpTAl+rvO+RQl/18941bVXlkjQ" ..
	"hGrzB19a9pmaISb7Yd7sFUT0E6laRlp84cA6tejYVTaDfb5pDfU+BJJSazLkQLkQrxtcPGlg5Ncrx2RI3RcRYQUWg5nd054/T1qL" ..
	"V87KmOClOH4cAjPX81pth8YULNhP6A51YpftL8D3pQe71tvjAtPUhCerPpLxHQIx0mlFflF+1Z/OiH0nwEkSHvlPl2lpQoFGOx4g" ..
	"aSAlG8MvfZxCSp930iojdZKhqGnMpdqzt42L7I1bLmAS6jkLagk7qtRdRb0yTz6qHeO6o3Y34vlucUrEWWikcA9TKHYDE4bJ6er/" ..
	"kPMjzlU0iRBtar0c5ehTh8h0rEq0m/LQBiuC8dq6S4oUX8L7ACVLqhSjRNaRGd7QyP9KiNH6XrkvNIlZ6A16Z7tAbvivQFWfwpH8" ..
	"XCraDp+9XF7BeJ4+8DZoz2qt60FVzGKLNw+BNRrxYM8iP5Ov7OXzVayz8AUcZ9V2347I3krEAPaL7KfFEanvb9X97q5NxudsGhxQ" ..
	""
local PAYLOAD_P12 =
	"dTgg7xCgUAheV/+hv0nqcSZW8HmSUx7+Sl/bE2SzXQj54bfT7wJeoTwiUYcpjhtHNkpcQ1jc9FZTRIiLro7kvioEEtQEzJSo06Tt" ..
	"V0ABMCPmqrSgModZJalublOwRU+Sbi3bI/6MyxVHjg+Y+OZIYpRB2/AOv7bJ5qo7VplDqUwA4QqNrPDsFCOgOwUe/QXyJXC1pSKz" ..
	"BXRBVF/I7z9K4wJfZAgomL+FT/Kwdn0CbsPuaVw7Z4KqDcA0C29E9qJDLoAQ3agrRkEhlnsudvHRcwp9NOEPyIr/6WrJQ5y4GwqW" ..
	"2a6V0SSHERS8X4BQ+jBqN3CNdZqeJfLNfUPmTVJ5ICC+DlGkpSsiM9gWaS2Zpxv48BbbpR7DpExhmvvzseC2gpkBzMrQBkBFgb8R" ..
	"3ISpBiZJfqp4aK+HGtC9HPUIlKloQI+x+Zxr61r/S9BJlEwcD/Nn43WSZ1PWeM62UdYvtWPO9PaAhysoAay7nTR78cgzqQWleCI4" ..
	"3pzmHofwYDrkzB3ZrXDWnUQUVrlS1Hvi2vx8KlhuMm45SCOvPJUL5w4F1UVgyLAaooQ0CuNDnrRRys8cNR0pc93QwI74iQkYB2ed" ..
	"0fPbt8oOauKKj4m0JqaJc4+AIU84lTBXn5xkt/KMjzK16xPGK0Z3AZtMfv1rbH+J79mPXeDTy2g+x+c8wtDDtATboQwugckW/39x" ..
	"jaJTJkxAHmaK7CUZAN0aMTAPUpCJgN/83Fz8XfaSJUOFiEZ3YGn+ZwVhGJidAAv7AQlSJXcItwODdYixn98DEaWmf9RfAiaVzBMN" ..
	"jDq+phi/0WxF1w6DGPqGoMZTO3g6f40unkKVyniQ9niL2U1D+2yNZoi9quxzBRjd0GQbbJn0Dv/R2UKGRpMSx2cEJ/pVuW6Q3A6/" ..
	"0gVQrJaua540QUVwfUGijNMewFRW7MHUNOPFIOgEp8HEaxDja3W39F90+S0j1VySVyDeV2ZlqEvfnNLhJjGpqkXjlG0wcxajNlEl" ..
	"dwq3nKZNgb4oybuITut/EbziWAp0Yo33O78cweOIs/bBUFfIHEpX+7hULyCznzo3c6lsA2nB3dssI+qRtQmMNqi0gxpb/Nj/veiu" ..
	"wIoLltHck37qvBpL6ku2LgqQtt30NYlNghCmJ1eCeHJeu6lhqMzE70HfixWFMfHIwwbfjkKOA3u62McGL4vSxeBgJKaiCaFmCvN+" ..
	"M2UekTJgbQMjzzKlEjeD89vHNX/6oj8bUrLI6aoCAS5SYNuOarU/Vk33M1vok9JSrpX0Q0gH85Cs7Wsn6XXyIgeTsFUOEX9IPCvO" ..
	"bBkl4CZl8/sL/1DlVyIVi63IxddQBdJYPalTnHzVNs8+WLmuCm5y6NXKdPV3j3YCGC8bsHelIVNb3Ky5zay5Ubrvi74NQWjfN2ZT" ..
	"hud/KrCwHJc2nY6dcuS8A/z3hyrY73QhgsrU2yP9AruOo5glpYwnqcYOyg/xtl26JR8VY0QOHDn+njOAwKu2tpjv4C8CCKiyP2kb" ..
	"hDMRV7IrgQUgYQlcK5Exvo+iEG3CorfMq5jIiNdvCqfp+fIbZ0Hicr8snGimhNtiUIsnHaZkuvYeO1282gb/80W5s1MkWQc2arZP" ..
	"vO850Ic74vZvL4yzyRO6h2Rx3PhAsiE01UKQAKPRKEriQJNjfe25zf/96sj07cHCrJt6KzNp6VxTCDOKF/LfsPWJ3mJ+m7xCH9+m" ..
	"FscRxITwDJsRRuf2sG4K5VyLcWk9UbG0OXm38RBT0yS2Ugj1DlUKLWDj5uaxcl2yQrVA+myTDINUvDLhBV4VHw8j4NsJiNSR8TGV" ..
	"7b3hzmDuKIvjPfOOQpOI9d7o9wujYAcMR3zNKu2wIGkDhp42Oe3nI1DUnBYdvwJpgyVQWwWSzcr/2QgEA7VUsyQFdiLgKBxFEURj" ..
	"CZxR4vsoorTq4cgehA427/odYUkL0prsXvUwTkjb3zZgaHTwO0A49ZzPn+vQN0SryO0EdsR5cv7fIZwuhRNM/eKE6aix68ZG+pNK" ..
	"teIUzTCPn0l6eKVlstEO04cFcJ0qCYX+0Bx4+Oh74pKG5IaRC9/e4gjvPAWtWqKeKXWBWdOQ5HqOJo2tkbMZbl5WCEOJp4M5Jnh3" ..
	"A2ycEyZpFSpaNtAJ37knV2jZQNHDzykURBFw/5lh3SsxwJR5dAcOaobGafWrhVVwy/8O84FNZHQYeJvTeF9ASS5ML0M2ULFOfM2Y" ..
	"EJ6h2UabJPq/JUxrsFoCTLozll4zB/0/RsJ+hAccT4Jn24VJgKpKCdvAsyvFQRE0H43hLGztbny197FgqEI68iZKMZzFqFsPIE2Z" ..
	"NYdH9K4/KXB3Ki8Sk9BDhqRPtf52hZ8c1WCkPaPNcCoXyWCuphXfsud3ytv/m+s74BYzova5LYufdalkK4mFdn96U7dOmJAfv8FY" ..
	"4PCJgfxRrjUhXXsRULCNxbQ7VavV38SYy7oJ0b1NdZX/pOI5AKYaHAGl89rloyR7y7qiaFZAwuKKuKKkS5jGCH/mWfaomwuCwwOC" ..
	"PcTFcT4XexgoPNA8B8tmg3Or4+DOzGQaCLfwI2d/list3tAOaweQLbQ2Tc3i7eqIHEuvH4NVPgta1NOs9XPQ1pRoTtWpjPacPHPK" ..
	"etYRKLwO2mIyMPxo9t7Jtcyj91GDuSzQHlC0nJyg9vKRg/9eYl00cp1JvgJFQ+CZgRd1fpTEeJzfgsV3Zjj0pNF+bmzbIvTi24c9" ..
	"FLGO9nDWDsjcCvHRZ4yF+XzQ8juNn3raHRIPc6/zZtYv3J5Eks5aXAvPVkCjtE1NuS5FsbPT2eN2BYh/lLexBhEZs2Z7UclRjjba" ..
	"vMhI7yEKe87iEYKW3csxnPPkBgRgibDiaI+XqyqjKIhL1swJJpqJUiatSQW5Iaqvlosy6ipKHWo5ncDBZrLWX1slPoBuwgh5C3kN" ..
	"/ufLqgu+C6/fPNk/QjrOTLT9yHhde3sGftCrP2q3DAN0oHXlpS92YkiZFUkr7Wg9jlZ87Xa/KireexPKNrEHt/Z3iTfsFejhUBVe" ..
	"g9F6Hi9B3S+RSNNht/n4/Zmxsrmzn/kL71JOL8G6uCaw5q6746gcYm1bgGjfLxtqWj+MYav4tsL9bQotHn9dCbQEvQHTY0DSRm1S" ..
	"+lMiIJ2vRTgUua58bFjioFjf2aIFrTtVCayajVNraBYwNNH1mwIfToP0NbI1BUsEd9cJy4dpWp8IS/G+0d2HOXQiu7XpjyqlaxVq" ..
	"9ny7A4z26PXKu+eX/Ugd94nxUyH8TpUbvIsFuHZqWFKIXhXUIUHpM4lHTTcw7geYE/A9L1FAlUOBGV0zg5Nle+WZJ/V69yKugL01" ..
	"V++3kqLjGifpnISdWZBEgT35pG0FTQ8UCWp7m3LBV9WxULly8jIxReNO4brgstd+M8MyrkmuioxJHocxHfiD6gSNRX3CwiKagWgk" ..
	"q2phlT6HloLQ7wTia0hVVXoLzfP4FLvQ9d9E7eOiwFSH406HcGaOxod5ccI2O+S9nbwXmZ1EffwFK3ztOfp4C1zNceVmMtalZKj7" ..
	"/f1d9bHsxW24W/D4XAgk9Jnw3bRkRfIiGBklVCPC64BPme06ewPmNoPWzaGBLlkp2Yx0R+rEWjbwAYKwlqOnQKKeXVHSuQM6HIqf" ..
	"KaOxRrM4zQZwFtRK0SBqtV8ULxGz/ilPuP6+HdzE+gkJrT6E4xAPvEHoAo7V+4JN7soRhRgRHobIHUyzJu1wL1zsIF/uEDbIogmC" ..
	"hi/XvC3a1FYj/QuCk2KIvNAjIKX5V4Sm1L3UeAKh6OwuvzBz7gQy7/pFyfEAxkpSs10cA6GWxPj910yMfrCsvkeMh7ZvAC4oKIA4" ..
	"Hmf5x5ROOB/y38313JjW2mQBTi2AJkJQn5RRi0WDp21t2xXi+olBYppYQaXZdPqlH4Nn5uL3D5b2mn83kupRX2L6+d0tG55S0tyg" ..
	"JHlvUMBL03Gb1wBpAJNLAx/eqKYGcWpWV5D/YELbuJTfvIAHU37luAL1xEEtenGUy9YsWd5GpjKBItjiuhQ80V9mkKlM33R1HH7e" ..
	"3aAEKyH2tqAyCy6w+kURI2RHThLC/JM4cTVQ2KvcUtVV0mt2NWSz2RHRS8xX+7zc1SkucOjXSh9j0MjbLVFkrHAOXJHIxN39IVAq" ..
	"zB2/ViBndhuCHTCrgGjsG5mdsVQ8Xf0SoX8RbGghKrQ8hz6o1HMC4nRA8p0Xnm5DHAJnkVh3YkRvj5UosREL7+w2UfOMTUvC0naR" ..
	"VKfqakmNYk4MSqnrljHHsuqQVQlfeibEKs8SJ6tkWhAaZaKB/K1biLwtuqt3o/g3WTwi1ien1SQqWCFBoSAW3r1YYWlul2KlAaiS" ..
	"NdxnKaoIElCQrSdk8IWQYDjPKupiFvpBOmb5QSjsqi7fZpzAFjwg3+hz8tH7Brds5fInlmAzE8ouUgi1nCHscTbXi6Cpm8FVl+Jx" ..
	"XVLy+mMpeH6wXSteMwlR24WQmnoEpKmXHuoh1k4tFK5GgZtZyqWUhXHwM4fIsNNOICD6TwzgdLyGAdClkuBDxoV33+5PNVVBafBg" ..
	"+rjps1yxZouiz1Pgd7KVYj2z61/hSBVZ+JH7/fFBwn1Ml23hC8/2x04S6aEB9/aS/kAFD5le5yxIuG2X7eCvyUla1ndtc1WXEQ5L" ..
	"v5d08s48HG/5WBCJwdnrX/fwXBvFD696+pEH+DGb0XQoa+XrDgzvkpC6TLpWcgB4/0bvT36ETgkNkeitfcwaj5eM3muuHm9U+/Km" ..
	"QsbLNQNQCW1qYc2NxnXu9hWLvq7zxHPs12EBHqMSiWGymorHOI2AagBZ43hAcEYZupDMQoyK9vuENwT6foQlv03+qXwAiFvU9qJ0" ..
	"FEb0U85nmm31w4Ed4NfdRYP93oH7Qh3QDy4UjdGWeF21qIgqOW/Yb/opJ9E/iy8QwuTlCojN6CU4YSkuVXVsKnA2OqIp2ugPjril" ..
	"nARWUmQZLFKgFDRxWDOoDz/jq8a4xV6LVtMLWH58ErWRDnrH07ccTMB4nO1S7zQt7aKG3yukIBTxX+pmAuA0YNuBFrL3r/nsG03j" ..
	"lgZBR6vu/stgFjGeTDfN/LZiZwpOlb8xQoDoi3OhRjHm+mcuEWpB5iUJSIEEDiGaeStLlbWSvLLG9kHeYP7wWM+YL/gjiNWAIaJX" ..
	"ehsIJVpnoP0LCDUO49Q55xxarZEKYYSlB2KNUmG9Hl5vyiXtSdhev1yMDbxPukASHiuSIKRknNLSydCnnR3IqLKcdr2K6CWoPHA7" ..
	"abn+dql+bninGj5A33YMgZcyrHF0DNtsBO40DomuLZ6RTybcavIgx78wd3yE08ymuG7ccT5p1zE8/0nGJ4H2gs6WznkV8bY2ogT3" ..
	"S8DDbr1omE1GFxoFokZCMrQvtGN+V4MB6UcsVypi6VNXR+lcDk9KJvTLg5LvxZulaIRzJ7FG0d32y9gN7pnK2+xdzbUvaJAT82aU" ..
	"aWT/3c4scRusrJ/LJ5uW+gxazFVZ0iQflILZkAprQNKBFh+OnZ0zZ6Myy/RHF1xE8iCIWyoXUJvGpMdTcFXN5HztTFgTVCBbN6IO" ..
	"sOWi37Kd+rxyMSype8l5SEaKo6BurbV2SnKtwUJNC4ATAgg4QKXs8bQdMqmM3eV3RB7OuMW+F/z4m2kaf9r3JBzoAE29HpXI9YC/" ..
	"7R5Rlkcwnmmlk/n0iXVoC8wD40XCfUzy21f6c81etMjOMbNi9Z57dvqWO5+lGllgB0UHziNJP7eugYVsvWpKTYLD2jmgqOpdldVX" ..
	"uxG4nfHKvx6wbisyrgU5G9+SDEa0tFDMzUGtPEoRqOyqs83dfNu1Kyk7KGGSg5GuibglQiAoXLYhvvl04IURAZPLBGv8jAHHssY3" ..
	"I6FLJofAK6/sCi4Z50daDD0a24CnmR00JDy8vWytQOAuLQA6R2T4TgcyMxmQx/AfosT0ezvk+7bne1+5d/3pFpV4/vU7XQpCXCDW" ..
	"Ed1sTqanjovW//1B17UfYOumA2Si5O8JQqIBmjeqE792SIsvDY/KDmJIe+2/GV/fxHTDVnYQJJROOf1By1EL2v5jNap1jsV1qxFZ" ..
	""
local PAYLOAD_P13 =
	"KN5KRgkX9KiJR9FPAD8NagWs1LxaS7OEp8QUZxoMZNVnSZY3aZMfQq29hpoJeq1vosibq06LyVdCvzB67r51UWYibNMaRgyRgj04" ..
	"x7yuK68JTJuHQSibBj1ATMZXTmVpw6FSSQ6bozKp4GBdoAVv7e6NAsMkHX1VU2q4SwmY45t+ATbD86l3Qz7uiPC9ztT7enGjxO77" ..
	"Oz09HXS9dPeil/hTSR9I8v7i0hD/rhI2MkVWrPP/OWZs/4CX4wtNm9ETgYaN/OHFdKBxmq+wpyCWdyFXf9jcskFIA6m6vV1HBLtS" ..
	"OncFWDGNat0EGHQMp6+lM9D4xLIPL05DuroDSOunXLA4aM0m8NOyBp18/N0/qLBnVXaWZ+oVrgO7IDtAmN6m/QQ+1lsFE84btIpE" ..
	"QwtVQTF7/71VJHusHGCsYZCpRdlrLDFvZvBpsyQVqQpJ4Cm5H2PdaxBvhF25OajW4/g5YDzIxuCaD124+N+erKIFvsbCc8Ykt50I" ..
	"Nve7a+bxRmzGUjwHsAaH3ZPAb/rjutXuXZBovwAs6fpJ9YouePjw0agpSvRfsFSGUGf7VQhqasZO9sfReWO1kKsiI2+Gp/47IS6z" ..
	"lt5oCcfqokGtBCLsnycmqd583MPUS4u+Z5UAUKRswdEODLfboJjVxwYc7Zv5fkeDJtj4iomPpUtQAmN2VlNwi9CSILS7rRoxf2Zc" ..
	"QXwUfHDLD+1uReswQRRpvAD5zCY4QeM/SGtb3BJrEBvk7LJARpsrcpk+8TYW+e26Rr7QWfhYBJfECG+soiYnm9Q604mlfvDLRqmX" ..
	"LDNkZbBQTFDTXKuPW9EjE70ywkkUVwcKli6i59GqqrbF/qls/IOKJuaeaasQInKPwuhytMww9o9ESHdh2GM3jZwKyJ5/TDjJ308p" ..
	"PxtT2CWhYOH+5O/ezof3FAVbAkqnbrhuyO7OtS2VhbjVWycQpU9rwctlmzKceIyUxBrBNJdmKIT2v3vfOxWzD5ldM/wgk+fN/gAO" ..
	"ObnPl5GUjFGEOzSLbmpliiZssAylRKq6ee+9dItPyzlB+iHZsaZCK3litgJcb97d+rKRj29JmuLo3Sp97FiHCvbaowxCnT7TSBO1" ..
	"4g6NLmmA8kKf4bl08btf51g4m0B3ltdV4QzW4RMyRN14rXkVO0HTCWIFSD34xmIEu7jwU3ahFVOfk/Wst7fS5xVP8be97rsQGMp7" ..
	"vi5vvqM+Bfh3stAnj5OgJe9s+EilyCKYrDeucnG/16sakaPdq6BxUF7GG5A4TIawL0iP4REE2prwGqUJCjwuJscujm6f90T2Z6bF" ..
	"DR3zfTUCcy9IcErrsX0CkwnpAK4EIvYnlzhHBaGMVAdWhi5eE1go2C/nhKlhrUy342PJAduzdG3S9ZbrTOqnaJx8WYpwsZlIWhnc" ..
	"6vgLONHtsfv+TUrullBdadRB1dyLZBo0cZ7P3bfOWvapIO/YJDM3ElT+7VrSf51QWzY6m5Cc+XHAIjeVjjWbeQfI5L7szOoRTawm" ..
	"VF78Bp8K8xwh6hPtOyQeUhNHlqfXdfVWy4GPe64C4Er+3gnNNla4Aso2J6dt0nZlyenEE2DD1ypaT8PnW+G8661AfOZaTzhiBDvf" ..
	"EzHA7ZQc7ehQFvuEvF8MSSXfAVUvl9y9OujhoeFQO5MyWKxTJBh1fYWu+aLXHgRo4/ePBA7CkSdhvWTtKon5aUusLgUZvhB4KG+8" ..
	"Go/7HxQj+tOTbuH2d0U92BlqbRY5Q9UFPI8FJMIui/+sROuaWBoKwarFKKE+FS+e+vmq8rP3fGVqUIVltyhbku/cQm7Gv7mqRREN" ..
	"54mlTm0ZBIFQQgkvlilFHxI3KKUEhexi+h3KlxqSmY3C1EtoUkuhOhmNOfnfhjtqKzbPgBnzYTxKcyqsONHwAlw1/0MEfBbiPO91" ..
	"vEPmEg9TnNe+RrbA1tJMn/s2NWcNwLfwnJgG//2TcOQda/v8qK8LosJsAYjnbD6SOxwQxQsvHych9YVlubS3Xk+sMCzkhD4qrtmN" ..
	"L+tpkvOGic6s6qsdZeTSI2/PkWwDYUli4/03aKZTb5jTWl7hFF6+wNUK/NniM9/xxIxukDj/Ahdrbozj8FIAGs0KPSP6V212RE2E" ..
	"m6R38ng3IoWrrAxhRL4Vl5wfKjUXugj6AacmrYK3BSR64VN/Kz7Ltwg+4vVdIH4GwzU8hZr7ONeZBfAxeE7q3UGoZBf+E17tYTVj" ..
	"6oJXcMf7XzISq00380YfM6bPWkrRIuMcog6M4ijUOz4kEEIZqvj68rrhVGMYMTiaJ7tk9wJvZKhVfGwv0GPgArzoIL/roOk2F/SR" ..
	"do+CqWXPz0UzaD2DhpQ6EWu9Fifv+2IdzS3tIJK1dss5oNcEqawyux8BS54/3mV760+QOBKdLtra/ZgOZmbEoQ7viSXwBbyCktL+" ..
	"+CmaPF/ReW+2CCfgTcU/ql+snTy2mR5f7k7ahuu5wvh3XT2NRs5OVmMtBzaz16tsAP31MegkwrNbVuFv9AGiykikctkgZAZHFvb4" ..
	"L0g9t/DYtpY/W2fgnCLS6icQObbHtSFhXZrBUHg9CdYb7EZhGNa3I61qjaawk3emPBKaKIRagA8QnS/zpbxDYgETR0C9uFLDc7/L" ..
	"+RRs8cNZc4iY4YwVx1r+W3tW2rGEvI3vldqXwptPQx6s2U3kih8DOCi4e9yyIq0K6d6D1mKvt+K8FarQw4sqgd1ctZylnzPuemXP" ..
	"hHKIAuLHqFo5SSF1KuEffiXiXBHe4SpXin7aN5lX3/amKXMgNAapqPcOdfrV/CZOZIF9b4TegqzDUyA8cXWYzLo19++FgRLeXv+I" ..
	"J7F8GN/jCCgiQc7BchP/xCr5Pw3kLmZD2I13rP44X+5KBuHBGBOcee82cGshOjYHLb4w9P0ulhwsDnKM6uUf80WbADI82+GLP9Wl" ..
	"hxpFtARqUMpdOLwWeAe9v9/51m1A/+ZD7RLJkj9UCOsxoURagVqf7svQm5EheN2O++eglNAvVqzaDEpDNMD4YwQo7ggXDM6xxuIX" ..
	"lue7ybrRRnSgr9pY3j6S5HUe1LQwwF8Lk/jCGkQXO92sL3MtvktGcWOcuTdKpMDDl2ME3gZhX/F4m1y2k4XPxvEH2y8JPgmwbNeQ" ..
	"JMg1x5qbGJDRQtSdFfqd79NiVYn3wQy+CZ1cuV/IrlvDLMJMhu90YwCCqwieOxKUP9BRnJ9lEMh3UgAK1kAwVEZtzfRNAy+0xAzG" ..
	"qZb6prcUOy2ZwWaC79VgxcyEpL6vTU3gOTAT7YwtC0/Qfxan2y2UAp43dbVQ1PNn9nIOw1HBVti2EXL307Rq3O+0UQEa5uMLW/uE" ..
	"u2afhYpe8gOnb9cGQtL+St9sa3RSK5saUR1rMZccQo/p00pIbVv7XyjDXNa/Ap5EKsyKjkIB29H1Y/0dQ2oavIUW14rKk8L4i77w" ..
	"/LGpFPscX2fQP4+m71Ru8CpuwHXqVFvzF4sxOM67/khspq5tl3GpG70MjEfLIC0M4Shh47bRJ3z0/T7Baw70PWpXSTAsPcne4u7o" ..
	"tXubu/3shz3Kvhqgl0zMU8zaHp2TsqEDmQz1IeY5SlAYl8JzqRF6XDw3VpZi5ZvmngXG+MMoXo1tPIQe+P1TfqB+K9XcfU1JiB9W" ..
	"Whd1/b//lXxOwsayU3tHIQ24Fh/mcL8t8PugjUnpNe987AZV7cRY/CvHN4WREREbQ+1/nhUZ4qki+VO/wh6oceFH8aONF2ujR42i" ..
	"FWepusQEIeFAT+Vpdb9hXpIHcUnXD7dK0j4qa+pA0VvrsGVpqedWfD26kA7EQxTFacbKV6kvUcp0cVUZr241YVfriyJqyz6ii+4j" ..
	"gq2ZtO/zOkJ+b9B1QD+7ip0So4L7Hp7XyOjlIuU+J10hEVpCMOAGKyw6b0Zt4htFJKKWc/ZPklJaDRzxUUm3w7b46R/N6GTb7KGe" ..
	"zRcpoZ21RKJARs7qexzLTg7G6nUpODhGakfTmSVw4v97/Tnd1j8xwwQTcYc9aFEZtoA7s9nzUOQYnp1fl2tcx21WqIKCeNg1/qCp" ..
	"y/55QBg9DbH747uv0YHGfiMI0E3fNz5ywqmyq0mShlPghsWoxjVXRxiwBeNwEf49UczkBBfXp1KVGgboOgMRwEZ4sP2VSZVzcnae" ..
	"myg/Le7aJDiTljC9+nBX1qOt/TlkbRbvb/x9Ao12T33A2K2ENUNgj6zbkdN+LQ+Cmob9afmiBAS0eWOHsTOb9JNzhcQKytRJOa+U" ..
	"kyljKftB9JhEcZ5WGg8N3FiNFmwh+ihBgvv4MY3V3Bm3Q2u7rsM7cvFbBeq91klCogObooX18wip16EclQTPu9xe4vkbD05Lspb5" ..
	"I+pQIiGlrl2MRX0kl40fCQ7EQ//gLMp/enfp4fh0veQcTNQGlPfnqDQXi3mwSgaiPcPNyFt68VGImKDAdpMm0cBaQ7T2AY4IBGro" ..
	"ZMTEVnuzwaBASrJiiuT3oGs4olrmwEpvwBlN6Rfr9SNd04L/1Rb1ooYqjpz6mRKojkoHG8CMxgaN02p4BIfSfWwC127s14OFfTNx" ..
	"wD96qMekIopeGPDQdb3NrAo+xy0miyWfAEaBM+m1lgTgk+5nU/hTn7nieEL9DuDDZf/FPNLqtPHkw/HKKHBiVjD7+P89Tc/SAdTj" ..
	"XwhJN32YS9q+9qlWXxcLpYDrPE9HTVi6oE7PrGDKt7zJVjBR7wDt7D9crFc9ZnwfP81R0wwSKPyP7i73PfT491TxyrM2V68+wfJH" ..
	"xqRhaEcBJp5YYzdMoKwkrRk2Ya/t4y86CNNkzjm3TvWrRc7HQrkM/vPumKoSH1orh/jGeDupvuVhrLZxSA5kCc8eaYJ1AhItLzaX" ..
	"1XpYtqks7cfNTs+VHDd1Qtmqei9dihvJ9N5tkjSPaiQsRSbQXm47KmpsB0Cwi8gYptPiyGnaGdSMaWO/UZMHVIt9i5MkCpPUr5zN" ..
	"vQ/oaAahNuCV4TSFQ7pOX9PDGegzNZ75HCmCKYVoIaVVDxNRMwc4THEDH/RnyLhlg34MZsZbBiM0cgSdjeJ+50lHo5yd8B9ZOJ3A" ..
	"uamigGBKzmx/d4/AfeWiYa5rKGHnEduD8JZZyxfF3fdJ3wjjZslxHzPQWRiFZbnCSjnNqb88MPmZVKU3iw+JIlrQuq4wzTKqZwJf" ..
	"MsW9rkeX8QAZUdio+kWz8uKrhjfT4M5Aa9NFLLSB8g+dJ839tho07GeqWA1d0Ocg1ryazj8h+qZ9uK/GDhMRE3LnWxGZByW+vLtU" ..
	"u3vdwzaJC6x3KuwmPci57cMqDnB+k6n1+mY8ZUWshaaa/UdFvFZbs36m05f/vsC7khyEQDnQw02MwC4GM3QDxg5OeWTrnWR7VYPB" ..
	"lJqE8mcCFzaDg6Zb7oA+JKg6lcyTtChUSgQsxA4b8zwK50Tg1rzcIUr/D29MPUbEyY+ASmmK97FEoz0AJEUFawQCuu8UUJoQBQAj" ..
	"YQsCyWCLhOa1zZTwEvPkAzoHfx4s3X3mmzBcwu0dRkNHlxiZ7srOccixCVvXf/WBQ4zyfsOc2zv7w2Lw/NuOcAID5ZkfIzhtFVs3" ..
	"b02fGt7JmW/hWQdun+7VlkAzyQFQ1NfTd/X7lbvXsqHQQrCTsi9ihMBhJOyuJFoswddZJhuNmG4o9x4qm0QgDLgUzbY5rb9ljcgy" ..
	"YkxjbSMNNGo9Zid+gzE1R+uIBNFF3and6fpR5MPIztMnK1Ye1WGhuLaFto2e2uprTOYlXUJgRqS9ROOs3qXW5P33pDfIlmq+LBHU" ..
	"u/beR9HKhpo+LBiUkxlY2gMbUK/119igawJlgDi6tlSTEdmFE1Dr3vmgUxtt+b/ReDzRpf4YgTEHpO78h7cJ7O30EpD6lQHFQ4v+" ..
	"a7hoFmpx0utAePV6Riznrp7v4JTbwoliBkurt3DRVhNziVyv46qm0h2m7zcDJ6EWJRYubyZ0db2H6ClcxygudtSUmGXl50VTEyQi" ..
	"0RcLeteoqYtLTa5ZV8ziugnmiPtyjLnmf8K1iiH6qCl6tO30lY2g0X68ONTFqDB4HygyPmRVNN8vIg0/Z/SnFi8t/Hrf4Oc2DTsv" ..
	""
local PAYLOAD_P14 =
	"w6mUyQQl6YcmDbrUT+bsGjJC5iTo88CkPNICgOW16XF8sUZVzRY75PIbDGtVY0T+1UiwPi4519j9lhe211Mj0EZFUSdpSNabNEgf" ..
	"jvhTm3Z3n84rMPmNEL1q380SSxsAlQoRCBbDV2SBRlpYR9Au5F57oHiZv8OlQii/8sxD1eiQxeaawphLEF+aCntD2lduXCXz2gwk" ..
	"VF5AqLrqMhGPsCDUY/aLQJd/69j5JDVbkUcbkQ0unRPcRoze41ypW83hsTkDKKhuxoni+UE2MfrwcrBy2RJPVIoSQ3cKwFE9Nmn2" ..
	"Q6vbG2JMniq3IZro8U7ETtfXUlYfeUq55pz6wWta1bCNizw7WwvguoXJlICx04Fenndfm6zIJWEz4Bp57Yl335fIdmST3+NjieqM" ..
	"4lh40uQXnIQadjc4FchFEUqHh19Ij12FazxKuCSwA3PGnMiyrupcfgQeL+BlwFX2//2tdGhm6KD+z4w+x/smiDCmTEmHlOuj0acA" ..
	"p5Xkxbyrk4FAxPPHW01dfTYmuEacbBiXnq7o/YrdY+XYuzxfEK/gHDNxtE3EhOooFEmQmIuSe7FSYIBuzeBmj8xyLbFEXnhVpMP6" ..
	"ZpWJATU/3++6XpS8uTz+jGB5zr5QBcQ7T2fV6pLSQJnC1cjle/6T1PojAykOVAZAEbs1c3vMNI6fBWoqXwgOeHWh1M6k2mXa7j6e" ..
	"qyQgd3mrTBEcqBV0kKTk0jX57LYEu9ZcM5bY4T0wcbYp9WxsbDoBAU20XEqXS5H0WO+Wrw2573ahD9h30rvAgbl5N8O2i93lT3Zj" ..
	"wQBiHwdIIVgXGF2VhJyGE937TNlmFE7fVo0DhD6Nlbd6ScDbH70pPndnqxHCJzN/m2SpWipop6ecy1YBWddrasd+LEs4pXh7Tm6/" ..
	"i0cYmYAk1xlWMaMcEJo8c+REshmEuZvy8rwZU/QfMJGeb/6gp4I2nwAUQdJYVod1fPHCWuIIyRSFRUtcAeoJa7VYgCJnFz6kdLsX" ..
	"+tSNok0UrAVMvUsUuGBOAx2p5Et1ljGmhnkeyeOYNGpqnkMdMmUuUpv7dYVl+Hcv9R9KttV0Atff1BXIJP/Fqt4HAACeZ4aZ6FYO" ..
	"qvlZzNO+/m8G+EGQvR65E377YJA1U4q65wJDS72IKhV+zOSThpE48XH3XBHOlMhoEgQD2R1BFeEfu+139lmUOKHDz2i0D1OIrcgt" ..
	"wafZPbD+olxS8PlCZpCJTqrjnl2Aenf2QfwsjwhyIci66KW0IcW6WdEa3vS7fV8jrESEEjXT6Rj6zKWXzCmB6glAF1IrUKF7dQYj" ..
	"XtCqYr3tyQ7CfXy/JMFDYurg+prnXDY/PTjF0T3zNH/C+P7jMbVQNtIYcnA6CiSGpmVmg9TRQGTsOuAGDgn8lPoKBnDL69crBRi4" ..
	"wqox0AjkZPNEXrjdN0bs6ruEOMeCsrMHaQRfFo83ydjxzqeSBArWq3/mD5T1fyqX9XCyJzMLKMKXxh6x0KlrvK/LeyhQev8K+ALS" ..
	"WLzCN/QEf1vsm207zQgk3V40MzCuxqVfhx8ECkzzxdt55poPBI/G/rOBFi9YgNjzMxqdOBIuE+bjC+S+/qnQedowiDkfh1VGih33" ..
	"sB8UYHHnwo0K7Q72+38SBLy/sm1sGORXyC32nR721K/nVDBnh7fPNbSRPcNV74Xhc9OwRXwEgYBE5AAiF4Arl+jiwo4AKliwjbyX" ..
	"BO1DeyFfBfiIJNRrh4S96X1BAQM2/nCrn6TUQ7gFnGeulvdLFZ/Q23IMn9QCfBTqp35QtJmZhDHWtRwS3QWPQmOtiA0Eh1Xg7VCq" ..
	"n44SPVHNM3gv6PCMhojwlTAipEdoG+QFRlxF6ZBNZLn6lHZyPX+rU3ywJHkY34/S1uPgsUuacdcSzNHrfXVa/KJNmZFFy509GHqd" ..
	"2CJvDq4k30TExIdFBKHT6bE9qsy8tc5CvdyoD5PwdWXFUCdRkob6ALus7BLlzokwlLlR/bUnwk9xSdCm9ShacffTNaaCKbAQ4m6I" ..
	"+6qyWxXgFlYmuDkDKEXV1Nb96SsI9ypz1TUFS20qWlCmtlGThIXtsANRQAhMKDHS+xXrxW2o3Jh88us196d+BG5T/s/vWx3Xelbv" ..
	"SzsvnEQWnENhrMnPyXXmm/esa9iSW9MQZjMlOcdXgmD9HwlGrfx4hiBd/FWNxiYLnDMij4UjdmHzYLCp/SSt4sWOgqnVlf3VkIhL" ..
	"S6fgnaQpWdHVvw77ZSLzsUJFAmwXYfGaB0OrdsCvUnPRBcIh3LbdVJlIa7n7GTGqIalEKSmpDEjcFHyuB2lWkv8nkWynmlS5guy6" ..
	"d4Aapn5xaT3j7MLrBv+DumpDYD1VVmYie8cSD3ao+2LM+ioerI9DD3IzHJU1ElwaiLIkaGh25E7GIxetT2sSnUTAatT0KRQr4Bto" ..
	"0NdE1HQYG97YWVeX3XeQ24AA/T6R7XqQ0wD76DRnpPdU6R7WbkUXMMWoo9gxfHYx4HzzIfGdy99XJJeu5hLV5Af1puzZ7NoDC/dJ" ..
	"aeGt/0D/C6oAjcFBn1vCJlFbZCP1B4PA7yX8Nk2ThvSA1DeSQZH3TYFTn36d/XoKaORqcdqHwmmz9nslIIAiP6Wjvr8pxV+s3XQw" ..
	"7NjnIaA6kzpv1FWkdUHU70McPtHHZpQL1LMFh7PW1/uimu1j88dsvHjmWT8Dwls2G9fRdy3f8HIOuPWEsfYYseOnBPdtRHZp6GSb" ..
	"qTzKIvOK+4Yvc8B+v3YtmmeRzLht2Ax817PyWpRPpbq9LVH9+8/neQ47+JHmgwSxOhvuEghFQTCvY86GeQ12BSOD4x8m96I5PdT/" ..
	"pUjmM/C9WiFzm3HnWCTIe0VlIjb0RCTw6ZSzcqvEnDme5AGbTVkflTuLq17eg11nw/dC3T0LFKCo3N++h6bA7ATvnJ5ScQ8RUAn/" ..
	"8LqdqqobeDkubFC1ck/t6IUO40GzOGPNiA3Q1bcLQYjPisHMagt06YqN8hZ6CtRZ7gbo2P8dVrOpFmte1WsU1mekDBuX7YoqSJBU" ..
	"l4BRc5jYrE5ZK8l/MD/3Bz40BoEs339EJ5Ce+PpWlLuADxOTsvOtvKpgxXkSWYqdFqKYPAXzpLoYSAbMZHRoRd192xMwbO1efFFg" ..
	"/bb2Zzx35BdOR9tEOjCN2NkLbqTLeSur6ksChRFs2lgXlvQ0Jf4G8OwuGJAMq9ouDjRKnZ17shdt/Ao42ebLBzP8TNWByAenr/24" ..
	"KA1K7mMmUNYiHpkV2TUVnPhg3172Q+/+qMw67xI7zxGjXDnvKsyghvswtH1WuxzXcLj0AfyOfxgYKyAddz2bpKXbOeW6bM9HGhPO" ..
	"1iZvDXtodk4MEpQFF9KetWKoMCKGicY917t93KHL5IkctVm1eZwY96V/MoMsjM/Y7Gp4emVpugUtrj4Cvin3SlDMHl3uiAlkspxL" ..
	"MlzPhGu/H7gTtRAQ/hd0ah6gsMC+quAwJk8d4CuZcf1d7essKsWfjwEOImz0Y8IoAjvBPJFLT53cU6PyX1kzmlpzgoQ5dkCBNhH4" ..
	"IkX8XEzabE6D6RA2GELqYsGaPGGIINF6bUbi8TvDTI5H33UewrOAR/YFJ931ebWMXRDLvH0MazMnnQx+D8qjS5d16wVwq0ndBwxY" ..
	"2J1yKowu6Ab7EB3rr3OWXGTC0W/1Jl0nOGJLF2tGSOtI3lVUD/e9Eej04zR+Qw3vvnl0XJg1sLA5zoGlC8ca3Fkml38QEquZFrjD" ..
	"gGBLdSYV+Oys3Ru9/qPEilFxQgckxtO6HFmpgCLeoQFvIZVc0jfXMqyu9ml1oDxIWdqGXkF45jDWL0CXLQ3hcwHlUuJxJN0yL693" ..
	"VB+5VWEhFNfRifIyTSCG0QIXg4H9stKU+M2t5Ah8HU5zgFfbKRmOMRai2oGbEZSBTE5XSemlyOkIJEuMLGUCS9ZZCdXaFXAOC7wh" ..
	"jn1vQ4ruPp5SamaN1OFhaMzL2DlnM0E+fcZaN83xK7dbWlOEJe4+7mTnyYV2Nt6L5hVSPTQqwhGVrQBlPR7BURYRHSdoSPbf9B2h" ..
	"8c82mZM/gqZxtY3F/PXX90GUzVuwt8T4L7dJj+qB3lePa2PVCiNz3iUKbgGQOvt9VmbEkjmyoBfeCAviHMK/u9n3lWeLXwSNZrlA" ..
	"KtcsMzBPK8XQU3mfFW1gx5yxwAPmQ6ycYHKStPacROJozLL28wNj+1nasadFLxhLbMLPXUARQLyJYj3jYhDLXDnz5ONgPkg0jVlP" ..
	"mlWMYRnZssbBkwebg4fDrbE8AKjNZRlyRDEcI/6zScWezRe4SNxfXjo9sgeUMnDhqCkiEytEV62+1x+VwaHRsEEqcj02Agf4s/2v" ..
	"0d5vFQlQLq0BNCzRiNDkLi/wWTTgEEFpfVvmWOjfz+JphKK2yGOtB/1rH2cwMHhsdbUgLKLzS9mdx/gX5X7IZUrUOQLi2pL3a4df" ..
	"IWubUInYYWbDalXAQ+qPZzCs184hVSLm8VDKZo5FSK49ajJZMajIO1+KEYW6c0+mFVgLWUtjsw6d+uqiUA86Gstjd26/ILnyUoD0" ..
	"OQH5mlG9KGsnK0eLLnbXlbFQzhK/W35FFoFwSMp1FX0+RxDOc+mehdbashHntTUzB6K8T71hQmU9UIZRoYC1bM974AOonGh/sw95" ..
	"xWXnucwJHyS/G5fIv8ep5GbCO7296yjzBgvzd9vXFbo7NTxXEdWaLezJ5yz2x4jMq4e1YefWRfKKFEhWu04xs1Cbm7UA77rf0woi" ..
	"pyEgDrrI0LJnZCf5fal8kiJYFCVYnHYsVRRltkvQHE0XDstNnHRRSjyncQzbm0efRglBXpENZNPYhxsk58pjRtBq86bobFJiEzIf" ..
	"wqh0xadhwidhMFPD/9i+AAcEwjRGMU+8OYgrt/ISN8NHVDEi52O1Qf03BUIreV2y5klwymRzJrzhkGk7oYxZf/muOn3wf+Jogvd6" ..
	"b/swvQRgGvHROx0u4tR1mU3pSzd92ynL++vPX1uNdgwHEXQlVKEvf3DG0DddsvytwAsFUc2nqqOK8ZY5CRnbyigwNso7/nURcZk6" ..
	"S2aae+DL3AFJoMfeWp0Tijng7uNRUdwiBsaZIQlp2I0nSwqKPTQUrz61G7LohHYumO4YkMHBEb5TV4TRLr9Gt7DKHeScJ/1ONuwv" ..
	"/ny+8jV7OXrLnaucnynnCvMIvBEMZFzuuBoAZc0gJPEA2fpTSl5zEnQiWiqu2DH/UWkNF4cPSAcQF+1CSz7Qq0GCNDzjNi8uhMVg" ..
	"SIlrthhk7Bj6SytUrxEVzc9+yJLoSjpVKZMBXwGDCOzDZE58n8rVW/u4r/b0q0NJ/6P5flKfyJsnzDdAWpBs9xjhu51KxbiuaE6H" ..
	"xRz+A5lY/0V+O5UOFm2uLiOhCiQAe5IAxgGbPcTYGOhLAZX4PyHQHklk7Mm7e3R7Tnrd15KX+fyothlYbxOwukPu8XsP3vQVwXbv" ..
	"k8PqYK3psrYsgILNDf7KYuQKypO8wfg/j/BudOUpXFZfmNEb8z6SeEc6FAazQ6Xkb+HTx9i55y1cS4aWrQxi3z7CfX21kufkeKlb" ..
	"g/hUoH2CJpnZJUdv3gHV8MWSCjRw+NAGV/vJISVxcbWRJoSK1qLkKC5Fz9/UbYVzI6vI4tv+WXNT3XA/AtfluH/KTUlxIog5DoRO" ..
	"hecrilogobIiDjPY+wrNR3KtlFdB9ZQ1FzmtGejM+JdnxHIB5BIB8hrBatRu0+G/tBcgHWmwmtEsrS3+cKEvARMt1DdpkdOVCvtB" ..
	"1oETCXT2HgG2WemBltiGumRyyBPGPprxCGcU2Jj1mFTEfdThoiLxM8vgoB5twXnu1msBkuFCQJGKLjO1ZcA6u3DVSPxsG3QaDza5" ..
	"1xH0H6VrpQ12s7umfbRME7qFl8l2EUiNM6lvlh3kRx9tUEUOyi9mY4SfRzzIr3da9omlMq802/+1CmoX4/EHAXEvTUcXUH3sbFd7" ..
	"AtbsDS06ScJ+2+mN1TCrOQ5M4wOI/chBHXV7tOlE+Jbn4apXeDU3mHil5mVgfO7B2v6RRFBRJdrVyDO827M2nXJlNNvZG7Ao6BFz" ..
	""
local PAYLOAD_P15 =
	"plSkG7CpByX7auH5uAu72djRKJSAG9uRdpRb6HWfLL5IGOHoR3IBOFspnW9ooogBdsVGxi/t9p4TDa9Lk0H2skZbSrgRzunYAkfp" ..
	"6jNEzK+zvTfmgm35hLQtdPNoz+w05IqJRlbwdFnYhMTdON799Wk0TsklPF2DB+0mbUFo3WZPqovo4XdpFrFqu8Lj2kPt9xbh6kkU" ..
	"FKBzNucSu2I1Jar06/bcT+uQ+g1KBAzYet6rGC7tztm10d9Q9mrKyAtTJgUcR7JfZ8YKvnLXtNRKq9BEDg7ZU9AuzF0sed/Kz4fR" ..
	"JgRSeWknQYKyZbFhv6T9IQPlwCO5TchVvbcm/wM5KwDB0X1qT35hLDU4j2ZefPdb3R2RY0atYENcfx60JcA1V0KI9o3Iz7pMQPDr" ..
	"RZ7YntYfm6q+FVvu/fDHNjIeYNdIyILYVooqonWVZYT/aaoXGmfTfWB0GDk9ypHpetiN1mzZx1Pk2cnKCVKbmyYBICWek4kKMPMC" ..
	"ZzU53w/PC6k7GCaZR4V8VdhLLdpq/vyn287IjZY0RziS1xqDg4syZPRe/JfbmfxF3g7Z1AtKp9Ab8DA53D45v0oON9kr4MvNMehs" ..
	"Fqmzy4Mx/eN38VgkrIN0W4lf6xbu9zOYQADv717b7XrsLsWCndSzaym4WfkY+m74KjHtb2iAPMTA1v7Z1THvmxGOMm2ERx+XzsYM" ..
	"fohGThPZMU1kJsdKXAnjAy0FVuKgSHz9gpfCtV4oVQWJMfaBwyo+W+1a8Q3YBDyFU2mjqPyumsfo0xHwzj6ERkqkzAb/dkQ7dcbg" ..
	"WzzAy7QynM0GhlfN8FnUEDjGYFrCI1/7Xen+aF1PghrFXuBs8TNrs8paZJRfzoE+PF6c2qQFfDgSugz5cv8rF5MGzUCovOdemYsc" ..
	"rEn0q3Euj0X93J35rEokVcwVolPNIQKvHg/i8hCGYzSoAH0JqFEZr6FPb/RhQEL5bXW+tJoAWaQYrLvHJ1yWHbuXuJ2kPHIQ8z1D" ..
	"VXUtXHXHIg5+yOxS6xLkw4m1ueUGa88wvigdV6QCGQpU7znHyz9ShPR6dVqa5Znbq3kfRaypN1owFQkCFCH8Vd+7tfEDkxJpufn5" ..
	"mE12uuTcEJCk4QZndLj94en1/u2IyB8jDsvtBblLMwjabGAsqZJptVW2L01+MH91EK76JOgEx9tLaI5G6ScPPccUGU4Qzd9nzJOC" ..
	"jrffQZl0AAx/FXC8jibbVvF/Zb3pcc50RNv9RUvHoKtu5z+5PKMoZcTubZ91rwMIRBSrxpdqeaTWrQaMpQp6jAxMwhIJiLzPvHhv" ..
	"mus282dNzXJhMWJ0FZ8BVORU/bqPm+kf3OUWSbG/Ia8PkZRWy+OrjUoWhKP2rUUiDa6k0T3jA39IIvbhs0KxCZFSxTZNwgAEUMiZ" ..
	"McynnhVzhA9yb3nYrH2YO00cmI9D/vigcdNfWYlvl3p5rxVkArohdzyMvU3Dkzi2v7ak8b5CjlAHApi2yKfCvxUvaYPREhyZEBvf" ..
	"ZjAjrvJlmJ9ui/fRxtEMD7iwJx2kE+CDT7W/FlsWXPIx8BypcwdAYN+0fkFjceUIP8FQjM+UR907e8uzOOo1cDQucHa0xJGhytO5" ..
	"e2pzM/lKAZltNxAXhBWvHMSEcwWlJgY3pevmnl6BTo7Ytbcwib1peyIwUMqNgv5uxq9EwrAvfI3TxT3bj3IidcAipopvSg4ha018" ..
	"Av9vxj910Ch9qH3argF5TuRbShqvaA7ccAU5UEuARTOK1Vi44sYA+zKnIAkUaXa8mGLCiWxMXrfDgCpDnzXdsDYcjIwpd4gZdP+R" ..
	"9DvTe3YRYuEtH8wr6gPLNSglCjie1kgtNpz42s1xsPK36kPaR9OmvF/LHM2YQnyDwU7v/0xip4913DWy7Z1RrKsucxGHgQ2B3dN8" ..
	"vCt/rBwk2LfLPiQ5wNVD4aqdrjVW3be6hLgmtI/aRnm4KV6LT6aFz8Sy/QimynhjZ6EDK8osDw9QGSWLi6q+/T632UupVOqaKx7I" ..
	"wQy/HMW0qUDtgmiA4qmWxYlAhPBDTNp8snVOyuuFy1GDk7x+e3qo/PbThp3Q0fYC/p2gjDfMX3+NtGbEqU/oXpCEsM66uCrkANr2" ..
	"06u4ccGl+E03XGwk4GelYBAop4AtA4yzuPB7ONbYPtj728kfvcaugNLIcBLKmWRysp1Nf3k+UAa13IchGehxWWWHMBezeEu44Thv" ..
	"r2cZl2ZhyelDcA+W3Oan4O6rJjMT4bhy+byJucPJCCLGdlqoAPWgGQR6rhSJwkQPhUXHALNYTBc8L9PTU7SGHe1fRlRIBidP18Cv" ..
	"RCID1gyZBGUN3ke6XNgRSYibVOBGFGL/cuHoho1ONxsvt4fGOaoL4Zneeo+1DmECXSobGFp+HXEoh02nVDwcY9SNBsTBxMrc4F8C" ..
	"4S+BzmKQ4gHN4iyA+5JYAGtpWTIpASMleWQxapKOUqrjUt7ConUAX9W0+9VJ/zaIJrPBT7Pp5HskJ4KajyWkYMEk3uxYVbpvD51W" ..
	"x2XP+SJQffaXbi81Bd03jXDtsXplamWFOyq8xz5oAEI+sGUQ+zote8Gv4XpCnUeAcBQQ37TFMkZM35bL2ckOe/tReuACCkNOaB9i" ..
	"O6+Yo9Al+8u2FN7QmVpnoJDGkUHbp73FkGqTKFsB8olD5OWhuXdnLfQH/SSE03YWaunBJuNVxHAcBsLrHQ07YoeO/gSLqQ8xkqUO" ..
	"I08JHUTrNXS1Yl3FAG4SZOyh4rNDqyqyX6zD0nbtnggFR4cikyeR++k7F1IidsSz5jClmij4ynG5iX3iIX2t4Q/mZwCSpAy1zcLQ" ..
	"yysHsnUYmLu6ezCWkZG9fmWOGXyA0w1wFUVohKHn/1MovPXucMiZgBcxDGIxO9MFkZUudaIBirtM4zJfBSlfyD3QAIH5SUNutvLT" ..
	"Qyv2DPT29L9OT6TD9uTY421S8TNNyHdy2yJa2LPlxxQfNU16tvzEceKCs/VlWf0wQ24QnohyW4726aL64FzFE8zMTZJgtr84wgM9" ..
	"nB7QkC7Z9HJjzq7tjmL2wSYfaZcULhPqKGHTo2zCjfpjgRfF7yNXZWX0DVlezvGMnz0qtL1bHvnjQxD4QES9SRYkSxs3QX3+3ZtL" ..
	"gfWeInVlT4WCpBv1JvZC3Qp05tikYXx+osZ7SqMRH7gsZO04zsNU04qPttNVhWwO2yyheXyO744FID39xt3aZIMcrY2ISLOfDvFT" ..
	"+AGsYIJJWKmeQAN0Wn86BPHfDKX/Xma8wEsN/RlaLZIbWc4kVikkVn2K1aU2em4VoRR+NKLWdQMuS1MfPX2I1dpYxfkAWEcOZm9e" ..
	"xBh5x93fdAi40M02Hk8g+6eNlHLTN8tIvgmk/JfnsS1cf4W0jun5RP+13Rylm+CMicvJGK51WScuSArt/NQtPpJZ8YnZCtl9FDZW" ..
	"vY9HJaTF2IRGrlgUTkeI47BJ0ENvE0uUoO1x+gbcs0VzwjggsoB/25tpBdCJrU1ZP/PFBDKnhSjLI1ClM+zXrI+lukIXKWlQq4Kw" ..
	"ecdE2ZvjY6/wTQPUA3RoTjeNa3RNe6rlZn/4JJFmHTTn//8cro0aQzmYkZSYyOJuyp528jfBouVJYY0AgLlLSSFlQ1KivCZ6k9C/" ..
	"wXRIG7wF8QOSHwCohKW0iRIpVDCfRZvbBZQ5pGiiqfh5LhO5P4qLBLFvDZfMoTdIFrRZeAziovH/Gpn/UR5wwrk0IZqKFPJgND6g" ..
	"jy+NJ/48YXVIt1zQupgfeP1RZekRqIVnsmb8HyPIoNA/xqk8IJ9Ca13hGmllGPmYaAs+znJAHhSFlSNKGinaaBwo0GNtn6YxQqlb" ..
	"Hirkv7K6NO46EpLEPS0fNJUghJvEXu0NHE/Kbq0ADZWRtyFzgWJahrW8OO2oWIRADorRQ+3REYGfGyH/P9ABDgOrnjzXLmeRPmul" ..
	"+keKV5xE50MnbIDr+c8sRogmeLVc08a7py7sLf3CvxaieU996LSkW37tBfEGfTBpjgJYuqlZMlZqoK/QnB2cACWvgbYE0QGlJnoG" ..
	"UYvckRTJc3n1QRdkkO4yzbDK1yVMxK7UfKLOpK+tXy9YJT/l3FDcx7ROPDbf6FOJtDdqSXJctZiwDb0IJksuiV0Zov5DmnTEBR91" ..
	"xNOFgU4LbuQ1+NUotRTrdqQx2F8nLQ1APA7Sdcul+BvIZjqQnGzmTBE9gLMk7PdFiPAf6GgpZQs5TaH0aU/EYRprS6kLEfmif+aO" ..
	"iQdme2x56l5JqDzttzQ/ETJGxC9Y6T51R5EgXDts9cH38zWhhQJQNnUsNWBZ7mObbWIiHLQgk5cPpdDITn540JgRxhjpqawXeHBM" ..
	"oBtdFkfpNvL8qVyYPtY54yk8o7aPJU401ETjwcIZigrGYA//SD3i5nJxY2gwt2q/1spB7Jy3f3EGJAa+M/b96IIfHu+AhsSc584z" ..
	"iL/iP3vkejB6P+Vqsj9Gnx0XbALkX+L6xhXOZm3IiDayzR7kFuJANvmYAqxlL8EUNlBedCGzSYn11egjXVF+ohA6nJksrQDCIrLc" ..
	"gA59AxMkIoHZBIt1mdWpJMK5UcMFYOsY04LgFDVcZJLSyEasm4w678ua4ib1MIq8SWbbgZpmlWjb/VDQyeMWsn8IOuDaC2ziRPSd" ..
	"IYXIwOtOA3jaZ6WrON4oIsziU9dnKUV4Q8cu35LjG1D7A5NXYP3v7cWcny2SQ68qzfu7kLMzKI0AM/gSrDsAlu+/wODFRirbXY3S" ..
	"jIDDuRhhYuZIczKNH8kJ81zZ20aSkW94nMZ702S83heRKJ+mJjo4fEevXBtKx3U5cgKdt/X//aNx56cjXppjlobErBRvZLR4XoIS" ..
	"Qu5WRsVuRPKwgB6aGinhkD5mZmqxpeUP4LA31WuoVqQZkzXkcGAJDGsCMQ/M9kplXp4J/1nXjXnLEx/nk1dslrpV/79RlYINuBnO" ..
	"DdoqDZ6ULoL/X4oNYtdkyecFKsGUaQ9patwQuxPM8A29l6sv2958cMx9sU0hhkT37XZh1cb3+CWjmcPHwVqel7rqX8YBBKzDTzG8" ..
	"siF1uWVFOcG6uGpdf0HJBVdJZ/TATvbi8GzrzKwz/58y74gOMTn8CIsjiCeVK8ovrWjFu9eut55ARyJ2Rvzvum9OFv+s+8WtnLon" ..
	"HBtt99dcDrpMFHXNvfqvopEnEwryGOlLQ0p4zrto+KtHwiUnVAEgwJdoxkt48F0L1RxKzPIs725QhjuXpeaCh9szEizForLIx6AG" ..
	"M0XkrXdis8/+XeqB3IYeFTad1PBAcDkIGhoAxsh461yQM1opI171srO2ECaXJiR3iKJV/ubxmxRI0jyJnkM7E3IuBwsvsOihE6Cq" ..
	"Gaaf/Qp92Sghvk0m+QgnJnIgKRT3rNaD+/R+Vz+ce0NYOYYv9cOYEyY5n9HRWAnOvd1ak5oars+CxquD2Ldng/gXdReHovTyTN6/" ..
	"kQ0pHac/cZv64DesAk6vtbvBzZHn3a0KfmjnSylSCC7PPwEZpwwy6vcPdtcSn9tJ6kYgNFBmktymoXBLANZteWLu2qlGLJ1DV9I+" ..
	"gWt7Lqt4VTlxt+DKvMGDdOmr/LOVr4JbvrxtH3wmbtp7pP8V1JiuC3upIpj0fct6vaFKwKBqeM4pc8Q12/5jmTtqhE2Igil22AcO" ..
	"Yxpjw15AWwdsVhKmLCNh4m0AGswD9oiJ4isc3hhRQ9LCTNfk29PSVa18TLkNabCRREurOMNPHgCWjX8vgQDUVFeuTlNCbufbQYFs" ..
	"ko6nbkn/oLWhIWd8Y/XRTcCaPTbOvrB/5rF59+gWuOlVS6nXmyN8rLV5kS4Q5Gl7HL+/VcFMgS+LsLBLvZ9nUOjIhj3ynDyG/v6J" ..
	"kaosb3NtZqpDZrjmfKS9bt7fWAuwLC+9CdHLhqnzgRxizbLBZmOynV8Y0XDgFmuiLD+2U9dQuvs+qkqqPBGmaxH2Ai3tDYY+LIdC" ..
	"mqsixWW0x9Uxue9i+TR/As9x+2DK0f4y9CBuTOHChkdoZwws3RSEGc4VFVn0i9zCZj0rRGnLBiP2D+jQHsPtpGU+dspGtJffgV+t" ..
	""
local PAYLOAD_P16 =
	"WtwPXh540QdStzW5B0WOZbG/hneKrzh4j8Arsb/Suwu6tYBnAOwKb3DR6DyID47SKjM37t+RShwy8vGZHFF2KJlECxp6PexsWQgH" ..
	"DvLCrOrQz5vQyYUlofcxQGjC1Ma5+Uchu0rg3rSTuaby2wFfxfSOzm5eDwkPfSXO4tjr0hgM/B35TpSHkhNDLe4o6DTvu5eKqyev" ..
	"6Rj6Y33LkWZ34khF5JOxPiaiSdg5kNVeEwQtq0/wJU+P5NTVHVoQEejDn5Nt0Wp/Xm4DR81wqXjjjyTuCK2Uy7kVldLrjlXFutiR" ..
	"isPjK8ciD4dWH2aMBSqVGo0HfY+2avgrqSkkYe0I5/RDETiHcp7HPeLmD7we6NLqtn2hUv7mkd15TIvmM10U2B7G5pTYHGf1OWD2" ..
	"KQpkuxSYAR4E+2eJa5Tlnz9U+/t8Py86COpmSXeLTg3dtjqpRc9JbeUauB07FpiiJO24l3rf1eFpNJVerWFvHPzCfBAGKVlmno2D" ..
	"X+qhuWhWOts4pR3UKLGXxU1bmZTZ14L5JWFsxq1xTHPkdMXIDSWgBrUrkjlml6T+va/R/LxWc824tm8xEvIadGksym/9XTQ6a7ga" ..
	"Pjm+2oM1R/8cbV9V/5QtEow+Aj6MBSUlQIyga+L2A9eT09eXxss3C3Gq7v19NT5MVvGmYNYP+mctrZ0gOoeFvqTt5xKjDfK2qrWE" ..
	"6otaQjLNulDiKcgYd2BnfRHXB5q2AHqxYDh0sj6x7WLBNrTltFpKz+w/8Idxi2JnHhv+rRGanT+MFp5jUCsuWlAfNYFDi75e3s6F" ..
	"aYTy7qe6K7UXBAmPMiHlYdRiprATg/7htvV7ortrTCRz558FeXGJG1asQ45mf40z9sXHPo1ueX7EfKC9HjDhvR1wz553jt43c1GU" ..
	"d4pSxxxNuiSuStLtJeqKGkCgq2PEkRrwVjQasf5yvJxey11qhGzVQUW/vDxHS2hOev+8c/iUlGCCXPLc19EXTSYAbNtjVF40WM6I" ..
	"r5qUUH87vBSS5LuZgkcvK9SW+wMSxs2qWQ3j2N191ZZrTE2L+CFzD77/KEWl2S4rYyAHpm2ZVgEwdVnKf0f1TaAOl1JUic62SsCI" ..
	"e9JEbS65fci2/Mxsanob2PVgJxXcibedk0FvYZ0MerFdGDsi4uKkEVXWpoZpq1F06fVvKlH4XyN9aM7cmUFbiDP8de0G1xlWalqC" ..
	"t93eVrDi2C/7j02xP+ifSod5Qy2+ce0fUE+MDntwmq7AVh3BnBiRARuO0zwHob4iBnl2JaJ5w0i1GGD74qjXQPmhfMDWABC/tTJd" ..
	"ttLUyrTpvKO3yURFh805ME7g4jQDoKWthENyycA2EqNvsiKGtWhHploEEd8eOfjV4NTsa1LPOGUPPlIkT7wUxOtHDRmgdR7G3e/X" ..
	"rK1sWoa/Xxz+ZVixm75nQjtnqB9sBB08tSzzaTsky+0ZOxjKVzTwrF1Ty32R4VGvgiyaVxvDoLSiweCsUjz5XBaoKeFw/Kiq8soX" ..
	"7faoxiS5wChUvFUQkIyEH8dk0FjfiyIG7j2s8w7K2DXHknTFL5Woa0Wy/LPQqFCS3b08xsm4NmGZYhAr9njnMAuQFKzq7w/lA7Eb" ..
	"w07JasFQPg5rzgBq7In9ksmChJzU0lDomrzL7qpc4/G3KeZbI9yMDNzjGyAlH8EAMT0hzLlhl0wQgam8ZihHPAyZh4rHwMgSMrbt" ..
	"loKe9TT/PTqwkiscZOS1rIH2GY1a193e4yho8PrZPxXASCuiTS+15HP7S1QgLW4zu59mQpI6CoglmZPd3J/qpbzWbLQ4HRAG/Ij7" ..
	"j7xRRvtxRUtTDTQfIXILW19y76oDhY44vqfFW1ddApJY9+kazY8Cj9iaV+SH8Ouxx7pnLGa2X7alokMJXGeS1MGRoSFnKwUCwdLn" ..
	"YSEPFPEMqdpepJsvuuPWMnoX7SPIrnNjn0hLAciXKOoIpmknJObnxJHZuwhiCxp6hvg1f/pm6QQaYxEcuW39IXZZ+hg8shh6dr8t" ..
	"V/8i8DaPu+yIJUUY3POF4jFqoVZqyYS0cbroogk0GtvyTCIERCk5/eHF5WrQ+W/MqUICsz4xHzaOv6CAHYwmuxLk3siOGgDd0hVV" ..
	"EWchwO+w7wSiS+14d84nkCjoDkcChE4BMk5RHWm1RYe/YNjrXuLdA99OXCf473UnGvUlgWYABclJDhjGc+ATqpx23HaNsU5/xp9F" ..
	"D+EjmXoz9UKtrGa29z2N4t1gDz2tDoPMIO4jJX4xWn24hXgk1ho78I3XYWX9iMdoy698vl5UsNzWdhHPWAP4L9PdMyRIuTw8dszi" ..
	"2rqKFynAJqvQ" ..
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
