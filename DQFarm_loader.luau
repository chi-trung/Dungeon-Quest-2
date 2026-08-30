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

-- teleport-persist: MENU tu arm queue_on_teleport (armSelfTeleport trong
-- dq_menu.luau). Loader KHONG arm nua de tranh double queue khi re-paste;
-- loader chi can luu source da giai ma ra file dqfarm_source.luau (xem tryRun)
-- de BOOT doc lai sau khi doi place (Lobby <-> Level) va chay lai menu.
local KEYS = {
	{ seed = 1772280020, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1775941826, exp = 0, plan = 0, hwid = {} },
	{ seed = 1775492263, exp = 1788089514, plan = 1, hwid = {} }
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
	"+lVw67FsrbTzzkvHnLmrOnNa4iffszqPp0jKTxiI6VYn7ilILlCbU4TQGVcrEgIQKfsMbOpmftOvo3SlGdtjoETv1QK6ogCUWcnD" ..
	"+jfc0q7K6zPBBXqzTKms7idVa/AoJ1+jiqpfwoGIgkAH/FQT3kZerLKrkqcASyVwOKzKzGsDMJjoBxuwAyAF5lNvAaYy45L8Kci7" ..
	"qSdl2oXzgRWH5G5lJVAZmgIQhDB4RvKWzavGDz90ovGG08roPN32j7nYhXxuJJuBh1NnujDtP6IYQEjDkPfQHsy1oRtCIY0yPYRw" ..
	"r165wfTag+5f8d/CcK8/QSPo6hlgJ9DKqyVjwxWKGyeRBuygZ+/wwmW3NSZhl5hMDLSIj66moJwI3bUgKyjXHA+nQVFM+w91j9MQ" ..
	"ZSnrmFD/9jLm0IudHJQUyQkwak7QGSpyxg6gm3D3WzeEYX7KnqbilFftLNjH2tBKS4+T2FYg7NeT2kd8theCmxZ5vfzji4c7bFTO" ..
	"GQZf5QLqrpn+XNOy3bP0CFWqdR2ZXgG46cTS/0gwLP5N/J9V3UF4ZI0I8mm7qjFEpTNVhysHa0m9gD7IQjmYm5ZsUwoevS/Uk4F8" ..
	"Sql1dc2lpq9FvRyMhrXvpvNh30j805CER6aAW2JQdsoFyvlbAyBpyQlJX8phsmByXW2JbFxJNCd6w17lkSeax4GJGplPb6RpJlvb" ..
	"R296tDhg9OrY1lfbg231WKIbjAJ71keP2dAZpkFNrg8wKN814WgUpBoatublsfmudS1O5rEnpTxRUClxEO7JxYPc/3MwbsFtZZZS" ..
	"NV4YJ1U9slqb5GyEF5+l9chHnl0oprNFrUNryhscrLI/i2aKHACgtDqFd4VKWWbbg0UNeolknAvYXzULFVT78K5NUdOJZpXnlQLh" ..
	"QqmaFPQUZl2nw85fKEcLN+aoZ+DjDxuYpXL+82jv1dfujEYBIHc8ZVvb3cbqfqs+eKZ3mYODNaCcFemFO/oHjXVCstRu8D2F7Bsh" ..
	"1i9rNdde43UwMZJ5pHLhIBTIle1nmlpEQEYI++bVN0QJ0qClSPIDkj/AlDI5Jd+cDJSQWy7OADwHL5lUUca9oz0/Wvr8J89XradJ" ..
	"hxWlbX6Hio8iKGUuGNHkQX5HwSXVlJ0ZqGF2usaYYVJRJbn/oCp0uZfXhFIDLfwGWQN9ia9Zll+gjiFzNnNdw3fCN2BcP5ZSYMCF" ..
	"Jt5rdQNQNpZApBOVzb9hjg3ONUs9Jiy/3qjDy1YZ2F4a2OE/2/lPjzbMRLWIKQwPc1PqAh2TPTNm3Sv2r7GHTUvJ5VRnYGfBgDXj" ..
	"T2iSgtbatl+VNm5EhxCcu7hbot8yGRagqfmsvBfv348PYh0j5QI8v3g0QlYh5UKR4SJc6lhhoQ/BpiGkp8cSFyiO2o512MZn1Nls" ..
	"S3+SlBBrxMC9CpxboY0kKy0XrQay4NFKHRLMEAsjE7Ot4LKCEVV+R2E4ZmC2fkvH7vUbYS8hGDc0g9EQI/cYxOj8yp+wOky2S5l5" ..
	"AiAzZ6i1haqeJDBeqa4p/tNqDIzwBgecEORwhK52YitBorq4jbC/DJV9ttb6UAGokmF6hWUtOsvMZf6blivRCNSpQG3aA4+nkNnL" ..
	"jWRs4pfEx+/a3g0uedNHyc1Qa1mmpZrROlolxkdyoQITRqwvqNwZWmuSpWOe/Iaa2R1knyfSRfBEZI0Kcun1yty26IVaC6w3xROc" ..
	"7hK8JZ8YBZTNMb2/3k6iYfx/I87/8NH08jU9FW9uTlC0r1i8Y/6nWLpTrtSfo3anf5X/HvHpJT5dIk4UgmvRj0t9b9XLBNoszzaL" ..
	"SMDpKCHdQUmhaEB5tjckWyRp/uhxFZczgXnL7YUfjek9aJ3PIvAXwZZeP0++OHoIbzjQqjThdJaZgypjnT06/zcVlHq5Jxc2uwzU" ..
	"ClLYCANAWLY06xdBmqzbj0jxu0E/pfQWm7IAR3LcTkwjAceqsLaoCuA78AeoxP8uhkg274Yazlyt+gndbX0Z8vi5H9/2aq3Gtf2l" ..
	"nxB0rKHUjjxmLPrkTmC3UatVmlG/a0gyuwwc3zWab3kjujKMyUgrPpKRnld5KAdpGG+yCzxA4Soh29hy3+/rO3T7mmRrfTdG7c1R" ..
	"vQTpwEtCcU/uyRFgksb/4cqjLNfuD/PxJfUfhirif4VBN/OXLJaf/EU5P+AqkgD2pDfe4087to5369seVzBscmzRNU6AqTDTZb3e" ..
	"eHWzXWpgUBfndQF+qNUStMThK/kJRFx+hCDYd3I5qkXcqur40qUIL5A2XyjsSlt48qxmLY5oymlRzaQRWQmpxZw5GaCX8gVYvi0g" ..
	"oJFxIBxx0gVDsGMb64usEVLya1qoqcfLZClkqeCE3EufCcDaPAxS5tkvYm8jkTJKJZR2Kz0eHHaDNUlJKr5y3z6klaQGoZLH/CuN" ..
	"3cBLwNbQNgkt49YQw40DeVXeO3ouuLXsNBRM5doeQTdhZHecUv8KvJNxvyHXD55ni1hWRzAMfI+z/0mTzXXEA86QtwsJyeN+J5ug" ..
	"NrE/cM5E8W1YIOQUo9FZMU9Wb3g2BydYKliDRXhxai3caSfcEHGAYYSE2E+2HSuWkmz+TQdZvaYL1q0s09ZxQdT+XHYctkY8y29x" ..
	"ADjbBRdCayZHCL9KNxu1E/3rO6E+8dOLSHWUSDbjXd2YdewU2DCM6SBC7NAQ1B3gVjBAJbbvCUaUGGaMBA4fptx+dbQ+lyjVSb6y" ..
	"g3hmUzGC/QalBZV6nA1QCQf4KFhyx325aQryaHuiROmcfmt0B3kHMPAMO5YUcjG87d3L9l54it2ePgM+3x2dflRcyAou/b4bYSD/" ..
	"SgF2c0nUGb7233q7pvpoQ0DVE2Wpv+DAWQ5WH5t9FnSM2IxjUIKvagbqo706an5aFiYVxZ1MLpLi4Pr3xRXiwoxEsma1RKyos9cM" ..
	"NpufRf6yxG9lz6ZmM5Gv0PcA0VwN9MxzTMxtyh48XaBHwApihkfqXGprmRG9wMAgTcu3IKe7NKOjLqW4ZpnMbiyETKWh+jDLeOT5" ..
	"m1E9Q8mveiNkz3oAFsCc//aeteTf0FLnQ10KZ5aGYrLfTwA/B50JZ7g6vUv4yN87gL/IZEz4p8DwIpusoWCfS7uRFN2fBjpJJ6cg" ..
	"kw3TAelgPKr2jwPXSC4dvVQWRRcHfQ5xu6GBkNMPTfWQHt5J7HK8TcMLgCku5SW2YQClKAqtkRwbKJPrrd4ZY/21SOcpF5JtVz1p" ..
	"PvRngwuIHDWWBk1xSbBm74ijVZXQdLpprygn5cQU1O10LzPBbrgXPYy46/6D+EN7IDITfOtBRUiPRFzXgorxuDEr1vrMSGB7K3jI" ..
	"WcoCE0etOhW+PdQgnUV1JZM7W7bGQSOVdJl1B4si7zpg+OLESL8d4jb9dC3KqHQPsDEO9E8HIhBq8Ue8t4g4Zx5rw6+4sIxnVRtJ" ..
	"5vPkDA9g8bK0sFNJ+1uxJzlLvUQLuIwWC1FKrxAT0tMBrBHx6A4aYF1xpAid+UWSLfmkDslWOmucDlWFZe37qgT/KXu1d4We12A8" ..
	"ycjtQHMZDY3GiBnFx2lfD5JFhdU3eh1chT656wjvk04F+qQu53h/qFuEeHat2PssqOJSwu/4/4r6q6RU6cYCFVbHU1kpRZDDC1JK" ..
	"EZnLc3lxGCdaksP9eyRu8PYo95ZVj5XYfJbzM085Iau5JMHbuBLbo17e95WZ/+Is4mVRQCvEtYGbz3ToVCjPBfnINo0TJqk229Q0" ..
	"aGMV4gdXDHFvWuzAle/K7B/l480kofcsG4RPfS4Mx/kUTJZNuZU4eC7Qu+q7Wfzb1MPBweqT4faQ6dfMcPIDUUU2pfLJIsjpDwqz" ..
	"eVMGeeU+69NZ0Y4LcDUpxX4ZVeW7IQExxzc5x60aPc3ioT/eY4XLCSuEdWMHdDOaPfrY7ZY0ZxilP91uHM9eKzHJkr/ZGwvasW3m" ..
	"caPQjkTXJIaOLNUYU/tCtMTvM4x2Z4zm6bEgglHcBsO8yOzZi3iV+rXJAa+9D/5yKEZiebC86zzfMuE5rVC2PAj9R71BfVYurPWH" ..
	"p5to+8JzDaTepVhbw6vwWXaYLs26SVO+2kCPHZH3jNwLLpWuvEnh9IHISIzlKldNijXQw9OPxdvwFVZxeqe/eSS81deZD1HoOQaY" ..
	"FnnNaW/uL0q+rV9ax3h1MdxWmCENGX3cq6yquxfwxvwmCkzzIZFmjy1xwfeflEN2HMgQiO2WvTbkwe8r/61FDyQ4P7XdLjIicC08" ..
	"/i55DqYLJo0+GNUQMVMAfFrxhvrguOwmjIqUVnxKsypqrbIna3Lwa0Qg6tqAwb+E0mo5tR0yyxBVmy26zwwEEQRyoHe9ivU2z7cg" ..
	"wzU156tjS115pLLqgqjQ9pJ6fDwnG0j+BUivslvATr9JreZkMG3OYPV0g3lLtmh8Fd/8ap956NN354hVQ2KJIhzCRJYCmqsXSSz0" ..
	"yB4rfJsYQLZCijkTpMquXpNcr7/KBoW3qfEO5p9mj6lQM9XZceUUNFDWWpCqZ8wlct/yyaBMS9/LXchLEk7tvnXgNgsKH4lAJnRS" ..
	"QgkC8ZXexneR9i+1Lnh7vAob0JFdNVe3u2fhRu/4cxew2xr+mAieg+tJKZ23B0zElzcUiH7q4O8ff4P0IJgfhc3Oi/iV5ahoMNfx" ..
	"jAKw30tkoPVS/sOZYQtimLj8wUeXelgO1VQziDWie4TqAPw4zJ/6CoZHblqWVNAFvNOxxVcKOhSZ7WbsoJkHJibh0Uuum73vv6Sg" ..
	"HfvrsYB13A5r76zDhwpMIdcaNm8ji8Gu8Vriy9oeemefsAy6DLXn74BWhmJD9svDjQdnWUPJaQ1yxqi629NKxK0XxmxzQiUKsrP6" ..
	"KmQLcrNnFmZTtsjwwHb9jFQEAevbxf4Z1MCaK0CFk3EEA+JB0jP55fwsfnPHcjeZzi0c4ol5P3WMiQph69C6SGb/8LJaGkanc6uk" ..
	"8j/TBZQMbk4WOpTHFjkKsOJUUnmW8FVOeUXvYDGHf5QknLAuwYVU8mnmaNf4hZ5gGoQZwbIiBJFz2iJITuQ8gM0bFp/C93Lnpp4O" ..
	"u29DlH75q6kwnpyE0P0iXAytyI8g7mRcmxrgCVmCtdihqhLNWOfegvkIcq/KIqCd57s7Q+1Tq6nqOAaYR74S7S4d7Yajkd2N8ZrU" ..
	"0S59hETxWoxchCm0cxGbnX5ol3LUzH5Tw6b2d5Qla7PQjO19FNAYXkhjDflFwNNkqo33s3P+Jv9vVKULP5bfXTfb6SPEO9Ixr89J" ..
	"hjqxnHPGK3hWHicbP2TmPRyogHFVhENP+JffdQ6T+TjLL5TQEKRtVtL1UXtA6ea3qACMQuako4l9+GW2JQHgqpIFiPV9HWlwIlXU" ..
	"yiHY4yDLnxoE6O5gUQ3w5oXakSkurDlSEhLg9d6KTg4XtFni0ZX4rDjdthQJw8d862liH4VkK9UcV8hXNstpinr/ihNv6CITNl1A" ..
	"fysyhJSs1Gny6h0SirXCg3AwwmfordZsVj5xIgAclmCX53bq9BS2hv0d0ZhP6a/22zCVkMBdXKi6f/bHIMcDtbolLdLa3o4+RraX" ..
	"OG/1k2XwIGIoi022gL1BXu3dwqkGqGd5YRMCwG07yuTDOWgUPom7Ywcp/Z6TNya9I/652RjXNSSUWHJO9jc1oJvvGYPoZ9bdXXS/" ..
	"rzGg9IANMyp0oSF7H9Z5MFwD+0AmpaRoxXh/CtM4vMdEpfJTaCU/mnObcu60sVyVlwQJOIAWH9xLUqJwdz5qHsy4925BdddPZD+u" ..
	"HDYU2AOQyPTidhisL5zy4T2KuRKuHEOAbTVcbWecvhUDd+jM57NROeTgZIu+6VM8+HcnPoTVh8yt3jzm5MCJtrFqHXS32ssP1cBt" ..
	"Gq2uc0jZaAMzGv3+CX2ek2NpUaeJBYMcPKZ6tVRThBkba9pLcZAy41ucwQon06Syjm2Iod+JuqKROALTtmH9wPa1mJUIwSIKnQNI" ..
	"pb8Et0cBWP05qYYCbNo1YE6Uu9pkyx2cDKj3EIAn1Gs4ARhtl0oeGLcev80LHASpgh1S4BXY42XsaUwTn82ildoCQZFwacHSeOdq" ..
	""
local PAYLOAD_P2 =
	"cN0U7PDPOahOqyy60yobTYMgJSKI0m0Fx4djZUNDpqar7EVJCPuf+4rZt2sYeBbeEH5qaBSCAg3QpVJ+uFvw2p3vc/1Xu/KS1ZNn" ..
	"yLjNvKNA66CqC5za5/4fsWjJeF9msuTurskP58PqsMjfOIHbDvQVdR6pKXS4c58r8YuJK+/drmE6saW+C6ui1dKcIzJ9SG81lGBn" ..
	"F31TVu8gbB7eF0T43ALkMLKwasn87V4wNGFOOhZylyH7Q70MvXW3WsK0+opBU16Zb7+S8KXRoTa3VLk3toIxvoLpeP6tE1G7Kdl9" ..
	"ccA4xW/4B/WBbZsxZZRaf0uBWkTsHTbHAPab5s55ZcQhbSc5HYjZUalB+WKkbi4H8BPEgesUiT6DnJ0BanNX23VxlJ1y4y/ZE547" ..
	"GQAoEZL3xpnd+ee9L/MpYNrJmEi57zecA/ySncbimtBrSZRF2HKOYXZQG/7IPnfRHYQ9p8CEWvZeykoGwF85QW4V8Orw5IjwLYTk" ..
	"mB3fssXCoaNq0O7IVk2JYo8EcfWsag3WqoN6Yd6X80sg3ASRXn6Y2sxhRX+1V4CynrGR0x+m2vhUzOijweA7UPtk9/ZdGH1MTLE/" ..
	"U/hNwETQVgIf9B6WsX4+c9EEkD/fYZODdG4MM8mfe3yBhYuRsNGr9W6E3c6Y4R4u7tAIoDtveqJ8Nl6vNp7A+N/mCJ/tZX1yZrWP" ..
	"MPXyLyt0JvHNyVsTemYB1NcGUkmd/IhJyfXhLcU3bzd+82LEd9ESfPSnUE+N1CrzR5Yj0Fcy9Xa8HPqPi3jw31UzDRVGpM0tV7s9" ..
	"k/mTW5JLrxppSDYHwfh1OMxSm5psSqOC4+YVWcQBp2ZMgLawLd3bCR65e9oDw/LgXZ0g1+ts+IP1qynrYF+tUpqFmMVu+6vcDkzB" ..
	"eUd3lOXogF3FUGNA6imBG3joY2yCGTKM5gD/eHS6+G5f2mZV8Fc+Txi86t2/H/vP2jX2PRVcMz6cDGh7vtp4owOKWzwk/8q7vCc0" ..
	"IJmohT05iWoEsdyiqXNCSRjYhxiEu9okDFPosIyGwdQfaDh1LSpnylvxTFpY6D7JjL6SKMSZtTZg/XO2k7S6RzXdjSrJ4JoWV/Fb" ..
	"dB61wO1AoDjpCXTMdM0+Urr5l3LuW0IjMv3BfPUlYGlit2pcGH4UxJjc9RTd857whg/M/ogpw3pJxZokSuqVpx3r+6hmKtUZEmbi" ..
	"JaTbt00vjj+jLzWUK0n/uufcbseeCjQtYbTJo1GhaJ1tyZTcfyQmLPgeSPTk6q3iOoT65A+m5HoHbAIJZHAFkQsTlGvce9PwKE5Z" ..
	"0yml5QMbFMSf7Te+anY+uvVhuTR85Qg/2QUwMW4oFT/lPq72KELe3SeMNTC1qP6DjPKFh7WeqXhg6lMuYFC8lIFvBD2NrOeKnsNw" ..
	"fOyhS9ozPp4+gKZTPK2GxQDAKjza1eJ80TfP1hzREi+/Cwi9TLUzQCm+WPL1ZYF5d9AGlsQjlBYmWVIrSJuZ1tMEdqIorwlzFIcz" ..
	"rRp+kHPI7226uMxF01nMq44czz83OrE2N19l/MBj1GS9NQ5KQ6t1Wclg/tbi+KKmPwJKrDxuKCHSMvVMgyuBxEfOj1F6aQpSHJ8Z" ..
	"vbb0zus9tWVB/gIgm988/hbDrK7O94XHCbUKPF4MO5nR2MeaMrCeZ1BTmvcl8NlsnwcfGtRssDScq7bowIc1cWLomj3rCjI03r7Z" ..
	"eFxAQq47hwYhesoUSllyeFDZvPhUS10bqaJ3Ol0a9DhcwTz5Str5EhzQtM/M8Woj5kQ2t2+pMQCsgJtSz6GaDWuEbsB8Rn0byGhk" ..
	"58wObka3Lh29TVkKhJyojvXe+5T09muKhtgnQE4RwBQjgxfywyCLh7xnXplHJHsXtfYgAZXfK/qdSsWYpj4R2cX2+0D+UNwhSoqv" ..
	"A7HijWyQvH/Uzr4wXp9TO9fA0FfGTFYmFm5eADy12UCY+siTmBhXZ+tgXeG6tn/JdZPda5ov7pTFeQ4yeGiO8757XHLZ2ux3rrjY" ..
	"gldJJ4m6ts5uLauFVGMpF7eENusb2uk4CJRPmm0Xa0J7+oXojN9UF32PL55jCy/JdH/SkAMFvBbjoeVb5oU3XFnNc5GP/qw2whKF" ..
	"ty57D+aGZSx+kxF3ftnbgurGFzUXb7FYimVUfxWy7fhbwWpIxA3+0Zo52azB4TqtUvjTvrQWrLRSSpxQ95aQzNJyegsLiECmAf9s" ..
	"SPrOyZre9PpC1o4+avOvSYnQuYdSCOernAAM4DA7LC/mom6IWiNRYaeKkHgeaL8ObkBY/f+cJcchmYeaM2mpARO/kuuCTUkkKua7" ..
	"VoSDPEgnpXSomomuRHjiieR9sQdP3ggi+oyFU2x+evUDOOlHhuA742jb9GAlK7XUYuCfuKO1O6ExHHLAY0VWz32SDko+0rTlGdkz" ..
	"tpVC3dv7/zGs5NbNRCznyqdj9hSBHn+BHRQqUOWBnwv5Bv32PaIBGI2F5x5MEXIWo5dOEIeDnYb3vEfwWw+TrcfiF3FXDA8/Tf7c" ..
	"VxEF34dARQ1cGcsdIuZEOVa+aDVly0K/kMEv0f9kEaclIu3KtP6FZMMHAhm1k4GSLkp/rdwX/bsU038UXoqZlt5FSYZe+EeCej+r" ..
	"edYL27Zy5VER9RPcXXAP2xzDQfz0wvmFtyLES23lM2KDOfcUNeD0bc8S4VUzLrQ0xPxy078TCoCyJWvAdYT23DlvjQJ4Ns76X+dX" ..
	"sG3cHCcD3UgxC+cb+OWf1N1TNCKPE1bAzt/rh4js3HHeBxIfyhf3ydAuPKgvhmJWVekGQSAHtGRP+d6gP0HCmvZcREZfOwFqJO5T" ..
	"3cFQIEcHVle2f9JXOWI2973pRcJUCArh+VubPTn61EopiOrXWBp0vP8AQnladIGul75miABjVPxbWcUCgDg1qXSeF78RCqlQAQNf" ..
	"be1Ye7sgScJ+zFQK/IhHVNM4y87KfFQpLaCr2HvX/8ljEcN6ykShazgm03uZbBBtX+9IvNKH83EgtX53gRneZ/jRIYg/X4MDKTyk" ..
	"Gehxw+auERDsvN3/BvAe1HTUXMxO8DG5ToFw2jB9xgPdjn3fiv/QeuqZt7yZXBzXbLTY7vqtF7+d8uaIh4TqfMGe9IARVDtoPTNl" ..
	"xuWDf7OEM1mG0kok2yiw+119f3VeCuhgDFAaB3uS0JBx5+3ibs9m2DNJqsjM/3QmqAgYX4ZxSpuRmVWpXpWAoOn/6ezGSDFZYrwu" ..
	"jcudTX0sRQUp25Z0desNJWu2IDSZCoc4IyTaLxnK1OQddRIZzp81jgdla0k3OrTD4Lqt/euZ+D9LxJYt3X5DOfg6V8Rlk8GPaipx" ..
	"I2tZyAjzZk0QAQJ91RPFYSVuZGyoqisrSn8e5aX/nL3mQxt6ptAumBoitRTlqjf0BC70Q1R8X+qus34rhlmXWZNwmwTdHIrc30Xl" ..
	"ah7pWAUm8A/cACj9xWMSmLaxJxhfES0IsHEuYh+5ZkfGCKL4sWsPXrCUixWoH1idTsIvmLWJFQ4jeC/YKt6PcLTAJwMoWN9Wf4y3" ..
	"vLfEVVcIk1b4Jke6gUgt1EVZ+Nu1qVSRp4SKT5HS0NTmEa9uYq6v5W9AldgBdujGp/4zuYbXJbEz3Zo1otQDmTuyGmbZUaUmsKPd" ..
	"Tugy0on2d46AFXVD2b42AkeA2lkONmtcqjtH2cnyuCwJ4GrefBPw2/EmtQNOjhvj26qm4PrTI32aDQIfdIgd+tfdBnNgv+/ZzQVs" ..
	"53X/5hYAnuQaZVywMzM276PfXXCFjH8Vuo2x3FLPD5Nb+1fxgL4YxbzVF94H+4Lr+Ub8Q37ErbECuBI2Cclll/DQZCboShpRUdR/" ..
	"r338ESsHGBvYGpa6lQc9I2xhdJGMLBbMJgZzBYhQqLHNkQTEsQaag9Gw1jmEHafWwI7w7hBeIgogAKgyVdeq8kt/YZjC+mMqQOPU" ..
	"hhiGeLd4Cz9BiH9O2wxk2FagNl23QEEoQHqznuVgnZX9VmLKqhxQdPsCj45YAkpt+sA4lTv3KWHLP2/myP+Yk6x01yGMoHEizCcw" ..
	"1kYa2ONCr6pyAUmK0ajViiWVIuIIlMBp8Wgr78qjOI+rgd1du3dAtcayu9IuhO2+a+Pl49uAcWpHkeNf0F4v9Msrorn2+ar3p0Ya" ..
	"1Uhw+DHcOiG6Xy3TsYS8fdp4tn59WE2FGgEatliHW3rSZiw94y6a9ptwyen8nz3kFH5+Gj90pUcFNjgaOdyBMNAyy0Bnep2ostXl" ..
	"JnfrnvbhidVGH2v6HwEfSyrchNwI0hutHGRRT7cRQdGJO1CvxVjEio2iw+hJV4gc3LRRfK06QdO2aQHqZnpUFU4OFVkpy/cCrUpy" ..
	"u9GF8d04AVCCZYSfWserSayCwgPGxjueQFrZ2tjl6MMJHxInMtCnOUSGw3qy9mivCAkR4DUWtqFeFtA1rBPLGTVov1/4/8x4T1Um" ..
	"/as/2lXPIrlUPdvyuzY2MQsTFItFcXkDtcKJbsGA32VvKVmFPHcy6VGd0kdOkNk+7gKlKIGrN8cejP+0GVY79vQbWxgapFcy72VT" ..
	"U+GZoUzQRsL+6gT6OkGR6em3W+TPGk+LZlvTazgutAC0kYIb6cG2hOh5hc7ZKtDMZzWCyWuRwkyMTHkvD7Q88hLEbVfnZlPZOBPX" ..
	"kzL2LvWUlB//8LdtQU+aGk1/S68kDTMMLp+Y4NFMpIMgrEw3X00SG6dx8RqaY0XaD9Du/iGPRpW+CRD0sNFQ2+Q14s9ah+fg9R8O" ..
	"lVJJQxxs8fXZ4gP2MqP73l0GTQvpOPEzZfDwUx6faO3hVfW2RmfS0R2+hq3faFt9v4sM6nLCEKO2haZPN0s8MwkafK0Xlo3HRhD1" ..
	"S2WVjW85bnOfEl3KDKHtX2SSL7yZ9pMP+eC7rKB5OLllwIpstUKW540nvlV11o3hESY6/X/HqPBXUK/EFa7+mbu5Jufd1ncfyzUa" ..
	"4xlHj2K//1uP0Fh8KosRNvmMdcZnyCgwRNpDzUXoJGEKvs18MIsL9qum2a9zstNfneAHxj1jVQw5C6jPAL6a+EqVTQuxwCH3LbzG" ..
	"EF4CalJF0fDvpkOTpyTRJ+4hbKwpoD/D2kS0McWaSp5da5ptjHupgtuf1IHxPxGpWoquPNL4d04WJsPzMIl7jpo6VxC67WCDo2wM" ..
	"49Dz/zDsanSDjKJA7fIpgodkYdDu5fneTZbbzIvolmwrZ0Gt+6BdYjRsfHItYoUbh6lI+OyAOaLOWeEiubz8C4kjW1PHgeHOPWAX" ..
	"vOwuBBY80Xqr5c+jgzDfwMjq7Iz9yzTLlNTvzy7q28nV41+ciQfD8YGvA/jVpoPd2OrDi5Ih+xPmZyOrMkZ+yv5diQddMBEgoMy5" ..
	"wa+FgD1fDB6oVgUEfHIeknirwKenTj5QZoAoBcmwnAtXy/o5r+PnLvGI1iMj0r1nTLHE1admRTQlcmQC7rRQXd3L9XSUPy8iriVm" ..
	"gGgWivyyJlwsMGc3dV8nrfhRnuqpo8azjACAxdrgzaLDeVHWEw8L5wa4+inIMbWRf33+EY0zLvKNJ26l76bInkHAY0nZ6PFRc4PJ" ..
	"EU5EW5LNmCw+ylWeOmRmFstaTvc7qeCrxb77QkXbQ5qbdoU/xWiHKRpiljPC5R9uOA2cGb2Ej1iDpCJbvSwdSjmImrHqu5GYkIQp" ..
	"7FmNlY5WsOYYvqJR+niiEpzotG3SQTLt+ERWnqfSzSTheFTzcKceL+EztLRFjE+Vw+Bu7CHp8Nwq0cKUN306Ipi8BbqcDKDVRgJu" ..
	"kmz8sYcBZjKtPPbJOVLbbbznLgZlZxYnIXcIdvZfFRiHDxvwnm7Z3SfcLCQePWyhmFnPdxK6V/Icbrc6KssDy2djJjvR+Gyg/eg0" ..
	"gPoWPy2xnzScEaoRW4InrPHSYgR+J7xPtVjWxsWKsH7fn0KlXJoqMb72jVkQl6imYFFQQJf0hN9n8MgLi6synmJQ5V9d6ic8EgT9" ..
	"MCr4tW6Pkd1KkzOQI2e/A90/lmNWRd+9xpcjMiyIaSSJIV6ClvEr40q7ifmzn2LzXgGejzV+4UH5LxSKQ2NjnbAlMnTmcOOFrbRu" ..
	""
local PAYLOAD_P3 =
	"k6A7wmKfXS8tePdAFf2iKsC8eBSBjlIoAflWATnzWPD6OVjZ40e1FMZVm1BnGq9STiYQDnMyP+jOS0V82ToNFvR1i308ozesX2lS" ..
	"Fxe2PZXdt9uyvgiuBH410LIfDk+gcNv5CIS2EWd+bQtamUBiv8u+4LvSSHeM3qU5MYfBtuIqbpu8V2fn7zEPYSj+95J8lujv4vl2" ..
	"okW5BD/1ONDwoqcLSXABVi++PsKzabf7rTZk7hPQvYDjpAi0ALN7wBTOsPenS5VaoQeig7EaHkmiPbEDB46XVkZ9cPwsLkfYwZbO" ..
	"f3sZSmgGv7bICCPKMke6UpjKjmHNOTDCPJoIrzMv/pHaJwqI876fI5H1Kzq2jSFk4WbbqjBaSpT7vxQLjYDL7+yRc3KBuNTn2MEy" ..
	"LJjtQALARETrTh+CLSRxgT48Gvd7db9hllN3na6BooF/WOg6v62mfeJMv8EO3g0Yf5LZvI8gNmV5VNQZoIByTNw+e7iShM/ejSd2" ..
	"tw43xjGIpPOwVMI6E+oKN7dwHm7Oi98/t9iveIcJ88c4AY7XIz9ErpIdtxMZfvWPi1z58wRPQgFDodh0BaNWHDcEGxUVbdJc4hbs" ..
	"5IrpYSF1FwhSIrTYdc4ty7XkJyIcUtoHO8MTUI7WfRJAfZgsIgevO5q+2kX3ZJPdCFE9a53J06IMLbI9WG1pcvxqSQjq78GnRRl3" ..
	"MWpO8aDgYbB45tH+01TdFNrOWpqHBT/lJreS8RqP8R/dH3xkoF+lNWUya36lovB6JDwktnKmpxDbEUWCEg/0yYa6CnLt1VjKBloq" ..
	"U1gZCRQIv6yjdDb9Cn2YgKUD/kZlmwVev/17hxkZLLktviEzFJbApnVIs1ljV0XWydI23NiQbXOPYr9haMk+Rkr3kw3QU47tyGiv" ..
	"SWmVYOh77PzJy1MVXVitSLCr0/YNG/2F+CTezcZ5AJprnfRoGD3GjifOQhf9332Z034nQ/9Bn2Xk7bC0hTa9fHhDKq4rnkDci58m" ..
	"nwqrw0U2iZ/m5QLDUkYckRwitjQ9do4RJkW6dm5sfnrOHTBGSsDbpttDH7T7DMF8P3mCesykq3FYpEMk8bqx0W2Xv+okFZ6HBFbq" ..
	"hsARejauMvcFFxo+pej10UqCl/frPc5H2NGlPyK02B2LjCN8UB1JMQ9dzueXC/g3SIod4sI0v/Vgp/seGZssEKO0dNbmJfi4w4Y+" ..
	"u5p04vrNhU6lIk0UU2IxlZn3hK3WlcbeAGV6qbiJrMYnQnWuLYFH+vaizBVqG1eTAN+F3ftMEGh/I0UzzptQrBBffa6PwX1dc4Sk" ..
	"zqWZmwgDjHR9tTisA/0aSDWIKwENHOUA58EhyD9guus4eVaZdGYgljFI7bWk7Q7xhP5vJjrG/J6xo9IAVDTcT6tLKrDTJdFEptap" ..
	"V4wbhMwpnuR0/1u6pD7zaCg+zkOJH43VCFuVPTnN8x6O3xfTMv4KMZ1WMTnEDt3ta/p2Bezi9g+tAtRy16j3Cb0j49nk0Px56HYW" ..
	"kUWp89trCSccMipdOJXhb13wEUscYc6vO0zMEXRBn8KMlAhEDGlbgZiEcIGrD7GOWdHV/noECXoKT0WNFB+mQr+8cG8Kp4oZBqfc" ..
	"NA326lPZD0ZE3rjUnmP6GpqM24T8Bl+N00RtO/+PBB94+4NMh8t0qd82XL4sIcr/vs0pBXOTQtQI+FOBDEiO0iySouNiydn1DlDI" ..
	"sfrcBGcEoDQrpfHXOkhHSul/1b72HEJ2Gz0P/PQfyqNLVduAy+Wss0HqxOVBPbo4qDOUm/UcZo5aInk7kCl38mU9HIjXR8HOozy2" ..
	"NWK+f3V4xbM8k1EeWmXb9dsDGfV9NVjrBbKn7cWAAiamfh9ckedLD4yCU6x4W8YkRYMJMuhrK6h4EgMgiWkDn9yd12Rk9FHXjJ9O" ..
	"e4yQWe9HMwUZZ6tBc+psTLOANBYgYDavNLgHszr5ie2tqAQy0C+me61CyAZ0HJTbVWWs6px7QSEF9EUy8eXIU+9051LpfjFv6PZ+" ..
	"cDG/ZDl6hNN06Q4vA7NFTYYu0ubvnH06nENVnLQ2Xd9Ke9CBpLHe7XKAG8ZqYO/GB2N6qtiX1QHE3MTKP/h5i/1pVGNhxGWePhBg" ..
	"mTv+8sFVCKFQ74jhIm0rISbmkR1/PE8ObFPCnJsdCVAHkrFZ7GkuLlyZ7yl5EsCwt0onCPEdTFuknXEQCtmliyqX2sYjUwuyuP6G" ..
	"+D8Sw4C40EjO4D1vqM0RH07XlQihNqIyeV9raEtFD+I63hGREMiIOuII8MogDnEE7/OZAY1SXPthDeuFv0MLdzLX2XZUfH1GbQMr" ..
	"+WaGHWq9Y4PywZvhXNXLJOHhvWaWxeAqahKmeRHYyDTS/TAmpErbAULJUaiBs/MKndPj+oLnMFegFpC5zSUQtu4TH9w0ddCH/yta" ..
	"8v9ka1+hM+DOCxOe2Y3zC6KiD57mEt8tQxxkA6gbIhinPqQY9GIhuNXt5MZRf6yIY3vCB+/KKsYjAljyR2VNJcZfIqX2FcH7ENZx" ..
	"5TdWlf42//qo7eUo+mCfQ4ZdhGewXHJXoT86wj9ALMBv7ad3HIWWRpxHlAH2J5LqoujZK/tjFMy/EVCcU9sjkqdhKQQ0KNmRpJbl" ..
	"duQ4WWMfKYMVBVuXdTT/aVG9CsG1Mh4jE2Ig3lhEFehHZhszxStHedLE/zxD3vbhIOto9cKh99rG0fzSyZTN/4IUoYfxBwkLCZ6S" ..
	"xJWArLimKKX/Ga27cVEyWzyEHEgU5qc3+1DXr+nChr7gw6mjt3i8xVPVVjms5SCx5hD3mpQEVhLGHKhht7GtAMCvNTKteV1czGl+" ..
	"TLIG6PB2jZ5498y8ViCcJYQRYOiYmwjB4WtWkExyPqf8xgpVymAW2iyxIm6bCwsntbZAHqSMgUikWkzT/isuOpV1Tw6uzeXpVTwE" ..
	"Sjdf9CgA95uXB53F48RsbalrIP/Y3M6hPMcK5oX8u59nwBp5kliDXcHb+onkL2zU7UwZqY8JIVuVEvMo/XYl4od27wMd8FoJkJQJ" ..
	"Bye3mhgj6pK9VkjSFb2tOchbgSM+BuXN5hEmKA9zAovgKEfsTC4sjMLE7nJE/M0l4WpE6ntxu4doP1+MVVM7zGjLuz1A6gKai9Ku" ..
	"jWsCxk1Sq/KYjbxrotmUBMhxt89OMJJ7Uw7XvhN+NyvHfUmO83qWjwwaQUiWoeOHfdLWfBy2x5diOoUbPt37X7WRbadTWzTGZDkM" ..
	"+wSVIZ8E5/RwDiSaaYOAAp4yOz2+Z6W7xqRzOCk2WTdmcXJVXeWNO1dF6rR9BOG3c5jCgYtGAIpuIdnfLzlOjXfywDngWJg7/Ymi" ..
	"vMHLBFKfce2oXzz8Bxcq/fImPfIbJh54V4TFz4QlrKX5mtVCBvABI87Dp59JGe+S/aIJ8KTY+X2P1t2pvNvFQSYWhGd/9pwc8Cv+" ..
	"YeExknAQq3GKxjeKSIp9TUp+hzoCmEQUxhkBLUHMfipdieiYD2bYhDs4TGI8rHgypbiLuwMad+h4XZjtK4BH4xRn2bB340+0Xj0P" ..
	"umlDJTJr1+5HB4teZ04szCg4LqO7SpJB1KcVoTEMFCn4OZ1fadGqGqKXnMr0ON8HZRuAXk+KNFla9gKYvYsbA06xUVc1VPNXNKKX" ..
	"ZherFftHq3Re3NnTDNP94zH3CZ2gZlcuEz7ywJ7mPtpWhuPZaMQjnx56s8BIQ8nD2rTfotcNYWqjd0TJk+q7+DFAbbBiNv9P8avk" ..
	"/KjaWq57YvsveNci+DAQixf7m58D+UgFAP+YEUqvFQkQ6DZGRP/7RVtrVSgnLXBji10ZhhhiytVYhkSV9LBOh1Ayb1tVU/TyW/6I" ..
	"AVh/CLkz5c8wahMbkTCEjfMmBq6x6Ct7GymirShDRRp4XstCmMIJFfclKJmTHpZwKR2xp1bCivTfzfRdOF1gvC5hkFwu9E2AAmd6" ..
	"JudzDbC+w2iPQ1pavo7G/sO0W1GGwkrlHHEIhqdtf5Ul7xKqenbxuBp8F2zKzqcGS/fzFRDf+MyLtF6Van2AjuuJW7hTUov5Z4PI" ..
	"vQeqmWPhm65IGzsjsav3gwzbOsfmE8AH1d+r+/hAxvyCn/MNpgGfzw1f5RmpWqPAjxzTngqDVp1Z/XJZBftXwNYdTyLhF7BtCEwq" ..
	"+yNzBLvJ6uTJt/pGoS6bsVlHw1Gm9NYB6tPQsL24VXbwHFzBXAgYdnCc6YWuxl+Y4YN021KC3mk70OuGEDJ71TvCvpGZ6WHK9nR/" ..
	"NoJCRl3kwSR3Zln6Xcf2oJhJd7As+Q6dKYhHNsy3Dmd2NtVXl283PGLuXn3XoXyhgRKsUyH38oYCwHcWDHuJk01wNrYVzj6MaxGR" ..
	"rbbujcjyc0oDl4rArxSEmzDZaiMLq/uuoiHhfI9I0UQeG8zqIlpHw+678/2wIQoyLCk0RcQQXKUhihy3RcVpY/fLiKWfmC7yEuEo" ..
	"hZd2d80iDc4k0suZ08mkdmsuQYCpb8RVtp6mnsPtJGHEfGCspFkDL91fz9iTegCzb0uX8tnHCxg7kv27WXTzCGFX9NoM5JtxFIjt" ..
	"50tUvZiTiIOEnrtrybPIHxY5J0y5qpUUao0e/wl/4y51vW0vHed0JNC+D6ipkoHupRk/2xuzNA7MXK95t9mMxH88++iKeZZXHoQ0" ..
	"tZBGO1bTF0/eXV5gLkOW1wWBrwyOyuM5MD68NNZlxwL+YgngyC7yRk4Iavts6duKGwbxB33ABKjchpA6LHXfWpudr8OqDE/wxpgI" ..
	"2qNbuViiFNRTpx1JWcLyZBh0bXrEmvLUfQbpIWrsqV+RwHRIBhA55t2wPO8SyDOQycCdxnfp4ldFeIXlxU8OWIhWo7P2WH5gNx5u" ..
	"jZf9dS63V+AImjYOqvpQUb7Lktojz4OGBooay+ZX1ngt0Jek8IjWHgVDJm5qBekYqLGdD2UdV8Hho1Pfe3uryQeKXLuN3o8unYyb" ..
	"kksyyBDpLgIGntW+RCTKaLQhIpUk8bm2nUsaJno6EDVd8C1cCEO0XpzurdzOhkJPa7gwOnjBkeXeNDkx2r2vVwy1xSxd/1QgyKtJ" ..
	"yTb2IteCfMvO+W5AVR5fxozq1knVovhOGDUPL9bDxsTvvTjU5EN5OO0U33Aip/sV1MDsBFNBDgEx4PsvcgdbtHtChc/Gl3VetQpG" ..
	"NKeOEYXg9B3/is5ZhTcyHqtwlNh3v7VqL5ovUkaU36S+40i6wkFzfz1kpbxkF6vBIEShamaezFZ5qovEHxYZ6d9Yit3jYruFeouz" ..
	"dd+fOXeqexY1RiiJF1qt4PSxqMuNyIdZDi7rU3/NSIp1RIFM+AKXA8RVo9siB/nlwj3K4hOBDo7UELWXO675XmEOzXzPZOiGbWyI" ..
	"Px4QWfw7zB3c1qvQGp7XQwcIHjHRf6gEtpybZ8ecXs4ZuWksX+SvKLezZN5z7WHE5j8Ta8/RiCsKpj3/NeekZMxqczEZxXYvn9nK" ..
	"LZf/i46YXuW831m9x40B6SpunR6a4Y9+LAgiH79OW58HWKC4KkSBpQPOGrd8LKcs18sj8Ays7/Io+fq782XJfekaz825L5IvnLGE" ..
	"P2jlaRvCX6bzH4d/N6X5ZwXzClzXWbr8rn2gVGPGV5aYWmLikq1yqcIhfwQxB4Hxnk9TI+YCYp0xHyczKZwUUkh1SqI71TsPWaRc" ..
	"mCt9lIt/2AoVeuT5vW6udGaFzNOPS6BQ8oLIQ6yYBqyLsiHwmQzFQqxW6eDmJ6N15n6uAAmc5LM4iMoWWCGyM7hJIyBjBt50RAGG" ..
	"CyAxEAfztacOW4+7PfZiZvWoki00z9M2gUdyFhw9tjPHTbhyenqLtlybVif4CM5uOA3Ru1OknFYUH1KXbhyTle/7ButejBBLqiA4" ..
	"ryStrdYkAQk5gNHOLTTzrNGtFuEL6fiATCOSCefayCGmAikfVRpRnNLuTr7z0dzW9TFnXPmxE5LRyvFGf5vHLzSjRPPQuGPwd29q" ..
	"XdiNXeUPdbpisGg/4FUd4LmIaOUsJYMRtgsaRnOY2iXrjyGxXRVRNLJVRoHX1G9FbV9gsPtBayYtgSD9TFfERTmyDLi1GC5X5x4x" ..
	""
local PAYLOAD_P4 =
	"OXjF4FReFIRqK9xRmtLMLeP/Nf7+QwXyqdTQJf1ZeXQluiQnbrNb6f3K05qXkTtvE29BeRGmo60zsV4nxVm0mg7JO7yV8KbpU7NL" ..
	"m71EVxHcKhhmWqb8WccBS0DcJFhv5Jdao+6ISImLXQmODkadRdQxF5zi5YcXnKZ29139n5PqrVWeIVHyE1tFMzF5FPbH4OmdgUDl" ..
	"EYMp02jgWz5AIR0ust7lCUuKBVBHA9KHkWhSrhGAbTSRtk/AU5Cwk4kZgdwHYVLOwjP0HFBOi3pLqRGuUYIzmDEpT5lB2MV8RRKs" ..
	"YuTPUt3UlmP9zL/he+Qhxhg+yLyjyRBqazJI+kNVg0mfDTEMkYPo9Wi97FueUAfKb2JD+QtLnzKsPRs/+sV4TeS3XC/DbhS7QXz0" ..
	"nm/uTAi6Bkb+4gfxTQy1R0KcgHyNG1lbk6g+/HJT4trzxtXlE5LtfSuoYc9euSnhvTRXMdk3EkxqfQ9PDnQ2oTBjR9gXL/dEb3YS" ..
	"xuhf7A3wyDux/20ew+g4WZkM6UFUvKUTQaVJP62NXo6TgG8l+/IQf99gtMTCL/71hgCgHcFBessW6xSByOWNnq5HrgLzJToihZwK" ..
	"cYFxaHwlxQWA3Z6UXI7CPmvRs9b+c0TylVm6i7FK3q6HqVcXD7cL5oZXhUqeCtBHBjjpRv/qNDk/PduzIr8+wB8ZyXYrtMoQihvF" ..
	"OtL79vDUdNElHVyMaF9l84J/OYXKJBXe13eF5RC7v3hnJWHxzRlx3i19yjEb0Fh/DqiAy7pM+p5Pl/bnxWm+bAPy3+eh+GFfPafK" ..
	"mjsq/ErmmPTm1xWZOv5CSmfT44NQ4c/AYeEXAxLBQLBsDSzL4y5rN/zudYhAdRIfodQ3AvNZwqY4QXsLo40HS0NlLYaGHHcvl826" ..
	"+q8p7as9e1717L+yq0Ot6WPvHHVDECL4vIcBm6KbtQ7w93xRiN8SKws84aswozmvpcgmrwoupE96D2CGJYbbq1M5iR3nST82P2e+" ..
	"/X2V56NdMkr7fCnC4HBGBT5hOexTqnH1AneNH2/Q8P+8X2A/BmdMJ0BALXyJCEkXe0SZ6jAXyUgCZdbwDJZH7YTiI/qwppb7BDIF" ..
	"entR0bkUyMM7aJHOHeOYx9wtgsCwj3KKWEIq5cn75xv/NX3I88UOZvCo+QJXCt+AwLIx7XFDW769p2TfimJxLiFQ+Ik7et6LqQqe" ..
	"8O5hzmNzyKTBsWTiY0RqunEwzJgGHyXWYgMxKJw5dSwQ9kBW/9aDGfW1H1k3lbfv+QXA/04FmINbgc7YNdoWqkVYsnurjShXD+IV" ..
	"ULl+5wnMZASU3O79wSegSUAjCVswy/CaJzSYtXBqO/bzOp4wLAX6N38W2n9moOyAoRyOeuYavSDJxrEtFuo3PiJEQkI8Gwgwid3X" ..
	"AaxHl/zhvmpAsvdYkGvjKxfvPB7vD6gCcEgSAjwgTImKEYslpnynnbH+WjSff+vHPz1C3gONvU/+ljjUjuwW3KRa2CCfGcQSrToH" ..
	"eC7w5oTlNfDR6l47Go7RRNTGAGDCFO8tSE6IQYONoPDU4pTejcMfGaz82RkmDYCKzVTKQAYMCnN/uoDKmZBIb/dUASlVIgSgePhe" ..
	"iOHeJT4kyqF/9/ZSNUNNuabkMOQXm+EuEDJ0Tn8748tOSh753j3mfB81U7JluiT3dOiTYQ9737pF/Demp1Bu+OYVgQ6qEafj1TPT" ..
	"bnGipCr2q1bISEO/1QEVfGSfUgyHzZ/V5xNkdJ1WXP5WgltjGSozLt/95eANLdCSopxN4O0Y0bKOxpExj/pKjDvlS0guhFERu4Ix" ..
	"Iz23pC0E7eNNWBB0wFC02Sz+PZrbWmT7WSCGjCPFMTcxO4mFPt0JOqCBQKarIiBfGSXk//LbwrTgAwheqz9bujht21uX39Zye1O2" ..
	"KkzIo+qxz7wa1BGq2M6uwaxVixGyofdy/XM338jyWtNnNN81tTuow2inDZi2TQxRVLJrpVR5pKBUvcpSNbmAyjTgSeKeD+9kforZ" ..
	"7xaW392UpyHpjitYpwounHM5ume++3InDvUvldkYf7MzA9Wz8BcWIEFGG8b9Pydw3T9W19c9He+j/48aU25nTmq1T9qLt0wot8oE" ..
	"MMwoUmwh4Y5gDRYZ9jHM314fbx4op2W7cyUjfkG8HtlnGj/yZzPb8Gt+FCw8TG+XbXh5t0rksuDVMpT5fmWXodvGp+rRcIYUVRNd" ..
	"16t9HA6CA8Ro2jFWtlAhku+KPqtAeWSBpegDfzUaXCn6wVy6dPawc5VJALS1uVCdxlsceTTE3eJpmKvw1gM/azvIP7qMUyUjteU1" ..
	"SJGec+QSWgfNNQ2kSAwHx8nRkZWhl3rnDR2gf4VP7ylDzevblrSBe/dwMgLF5grv9mMyI79mPLTkAAhRWf1esfsegvdMdynrgVYs" ..
	"d2xZpwAl+z26ZZ3ociqUZ9OSevegnhcSfXoC1l3MsRoPBg3Exh86VUDUd78ZO7dvGxKFAjaZSUH9xGVLBSMNKduFM3tWiissLGe8" ..
	"2bLwkQ88KyGml8Rz7u9W02YYyUG9jA2gSGMG8p46mFs0QJS44tdOGW0tXQxLu63HUuDvb1UxgiVhDYYPHwtBWXcfkNNsxJZHnu8p" ..
	"DAe2WY9SefNuHOV+k+JNnCNThKlsXXxbzlAumN7GFbyQQnrRhuwLPwm8WBkdm4Ucv/1cXl+LzobYKpVIbt+GluS3pYcyNHNfbUaA" ..
	"avChKWPfomgzGU2N4WuGwJiA470CCVqOp+dLgNVyb+Vnu0X7os7dl1Bc34zohArx2vLdC3VtsWNqoNQZDVR/TmW0fu97jLpaScbq" ..
	"KWuRE7lAwIlB0Aw5dOLwwoKQtQ/XQ8JbE4qb1xRsW4Wzbue5h6YKmj6LbmGLPCXUd0GWpYmAA2f/rXfRkBp3vcxOUq8O6Y1JkhUr" ..
	"/kyVsvgwwr1zo/D7vnpw8y+/xQFsUa/23YfheLEOUERXps0u23XFInuLLPojGU648S7SC2Pk8T7Fm2PKkpcTYLYX3KAMXEGnsO9L" ..
	"r97z6/7jjlSYawocAzIvpfJ9f4dzfU5gJgoAYZaC3lU+fAanAHcqRsl0sc4gz+sfoMnXyZgUNQAcj/NMia4nQPb1dSLYFqTl1QY6" ..
	"U934Ulgg7WMhDztal7OdhQD+SLiJpBWCYbEydThkydbQ+iC3odSum1X5FigDZ7ezkzeK8ByH9NH3G/QPLizIJwoUza++x1keCPcg" ..
	"BgAZGov2AO9qwJlAqdnEdARhOawZuM7H0VvxPC4maXRItmNXdJSQKh1KnIRpepPsjnRERcakCGkdDL71fexEE1Cn2jj+0VkhQgjG" ..
	"Azr7A/63/Wwoyz4eK0tbIk0UH4VY85JzmlzvL/rTJB9yQXjbfgYmsM/Uux6zF9X1F3K8OBNdzH81854EgdeaHXqdaLgoWOAQeg5g" ..
	"wiXcCvSTbwkx0aHNtoDh9lzWMhgwsVfgAFgvIlF7XnkC6XmMa+xw02eKbu6T9v0Tv7pnOulTaY/432aQIqDt6Oz1z21bAwlI2JXV" ..
	"fr42kL37Js5lxaX3GYauf3TeKJt7lkhViAnRPVakAjLhtwbTWV3L0VJAe765I+JlO+0Wdrg8XZ9bCjbp1KjLvLX4IqSeRf2RHK/E" ..
	"YvRQwDy/tNPCEm85gp2WmB76V2srswxYu4oLYl1WWEKvDMrwWVwjsR5SUdqdpXxe4j13rpGIUdL++EZgMeIO27/Ghaci1LvuzCc3" ..
	"5wJ/CKArpRKojqClvfl771pCu0fIMh/D4qlHSM21V3vKdp/6xnjg17JretEJrbglEfriS2AUopzu+/FHOceZ+YWnnXAf7Zwa2c7p" ..
	"/fKslIldSP3U2q/3I1teqpnitQ4O82Ct2vtRgjzQ8pph0OJwm+2mvRxVpKOa7IittwbzWXE7QmTEz69+clUbr69zbjFqqb0wxIja" ..
	"JCBxN5rutoKsqf292N+s2As5ob50CMzYgY4f7ghcykdqI3tzIaWkqZrseFlwRXKb+FFMXJyb9iYRWVKWC8aVTs/9RKvW0SkzxQuY" ..
	"of/R2frXniUtLHet4BsGGsdyjxK3OkvrWwXkFE1ed1dX9Fe2HFAVAICHc7OR/j/NBQZ5f+k1Olrok+X3h+gq9/KsWgTLW5746FUS" ..
	"Qqdhc5A9O0LXTbwK+hOrvRqVJSL+zo5invGC5T9LkVzVi1myzhT4XGopBXWdQyVlo0HeAoxHBZ8zbD3DVROnz3QwkJ//FdVHUVsh" ..
	"iZUt0FVZRLiLXaXkInPVASOcNc6NScH/C8lo3NQM/QK/LpwmrFZtuA/PT+f44GrBKTC01mBauZyKTeQdajeEC3Y0Xn+Vnke4RYko" ..
	"Jr8TZBADH/rQkvA5J3MWoWfUi7pSTKjh4HChktqHE5rRVzmqsZte/WjegjAofnaIEEpIvUZCG08SpM2CplEY+WRp6n0rOW4PlHKd" ..
	"JChzrc+X367HRGExFvhUTYI47r5JaANsVvbOpX4q3DPsOuXOgP8LDM5RNVHeNlbGQ4zGEZ7ZK0ERqrLf2RvbdoNB2HlCeyCisg0D" ..
	"UO64QmP3KXWEpLQlQ/7tEYa1A3owGJ/Yf6pCpjpBCf0AxJ6sQ154pcv1YW/NCfdyNzgHOPviEBWmKBKbsdaQRFHj4hLL+Hwaqnxa" ..
	"VTjAHi38xgtRWI3Y3tcCzz3o4KeFiVn707oFN5HoBSy1Y5y6KrYDwqEmUf2V5JvTJmvCDjxfikxCO2sLuO1CUNXtvHLPclYwaGlm" ..
	"7S2OEACw31xB9dNZCKL5BWq/DVNYfs5eIVOVXUUVQ3MGkNr36f0RwgKqQ6Qb+cfHdBTA7R9DsVXQ/V+byfJHbywASm/d6UmTVVgp" ..
	"XqvsMjvNQWbNPzeLpIArTTjlpK9suoR6N2NUnEhAWNxRqdNKce/yByuyCXA+xdHBqMDqx5KZd7zjDgjn5+1c0tw3rIQM+LsGcAwg" ..
	"/O1nShsf9nhvGNCIQ1pTJ0v+GsNRTEEv77Zlwtw3tV/vsSSt38KF+638+HaNBmwmoR/YuPF2KsQlapQLZXdYLo3YhIZptqqCioiy" ..
	"LjYdI/D6ge0fW62D4p1aL5MaF73mkkyrFzReUwy+qHYDGwYHL5X/ekCCuiU+5rOZv/80qMrL8Gr27nQi8icW4xf0XlDS6mjnjk72" ..
	"iakG0qOjVK5zZY3uxSoWzqLLZX1IUkhfjXQfU/LhZnf+qqh29oi6ctwu//5EMpLI/XVVzaB3PbCGq5oeDF48R3ZFovINtJgalyzx" ..
	"eK4e2jL0bVlu2WapeBYZ2y3asjv/gnCXYk3sPyAn//crlMfz07z4a8UKcC8qKDuQjdVZe4toZD7PxnoqnI37CTltsXbDJrkvkPUv" ..
	"DR/Wa1aKM9F4c45BaNFAmQUUbcNOZaJzebJgcqZ50K9SnNXr8S9W5YHMPBztDJFbRUhaNKIPp/b9itbGp5IuMJV1k6CFxJSc8JbO" ..
	"VsjPVCRbS1hiXl1y98uJt2DXAH+E0BXsiwmGQTjyqtGIYv0fLYGJP7ZkboTe9PDzHRMEVvQoRk0AsBhHDR0WY8kiNCtMmftVpKOD" ..
	"TGRZoW97qZcQ9FlPSacMA4UOcE0L1e+yu5AkbFBhf6zoW2g/aEew1PC+Q+7oLuTJA2kiVnvYXNQvjtwFqcm4sDWfbwSr7vSP9Kiz" ..
	"qdxYYAZCbacnm13E6j/r9tAswebGJSD8TUKu0OPTi0+r3tLU0DxR/3LEeoUe0ZYaHhGqb9dPvPhysLIzj8XNWbu5zUQs6VNXlZBW" ..
	"KlqyN6JE+jUaqZnURUBhDUwlrUzdYLsmo8jWoJxI6xpfaHLXF2oARNy3JXpCS/y5ADILk5jQTnqw5k0VtIXEazADFoNS7ZMa5hUe" ..
	"3p6t/UVbhn8JcdhNMAp5dcB/iXmQaPRNMUzgMoLlbqIUTy1Bg9n1SR8jmJUU7AUS6ckYEfWTpotiTKpP97FgAG7/l/FOI5MFIzNh" ..
	"OW3go9jzLZMCceQljKDY84F/y31VnKMV8R77bIJbvtR05hN4mI/6Ah1qazyVFX1Rr6dx5LEJxcKMVXZ9Ei8oEwqFeB+ieImm6Sve" ..
	""
local PAYLOAD_P5 =
	"T0mO3q4mSOxPSJChXFOYMlpPfOUL2sKB663YFsMjr5K3/QjzPkLfoBrdkfFux9dzflhEIsycuHOwzPGQugz2TERVXCwo5JujK2JQ" ..
	"AjCZo+9AiKvW3MJXSvNdMlJCko6jEAxmkYaE72bhgKvT3yKj5NcKM8mHEahruCKifIimv9gdF2IgF+/xhODUB/7nuEIaI3P4k28q" ..
	"EZBJAatIjWTT3dbiVPBj+TiIm+xDpe2u1CYEZvSj26qFY4dccbwWg88e2rg/LHhxd4SoFC9Z425tLJ28eWpRACaLYyDVTJK0m6bd" ..
	"nQ0G0m6XDheW25yb/7AF1E9LNf7eGfaES9Z5mnQJMBM6TkKKwqPnjOYLrvGWmdTu31I786OoGPKlzmMFZehS4GYzTzQFZ5nIB8hR" ..
	"WDX9otAZVLwe/lzjV8HrRgOo0k2jbfdIxeTahUXvErWue4SKNovA/otYxWVle6iNCDFHf9kAY1w653FI5a5nwaBt+lxZWTThsOCT" ..
	"f8VznB+42zy5YXQOawk74IlB7oRlvh7Y5CS/6TASgXK1R8PJvajW81X15Ogj1wldTkpy70PqvFCffCyMZr8tO2zWW7dgzk994ubi" ..
	"lOtq5LFofKpu8ePUg4U/I7t6BkArsr+wK6G1jqI0d3R0EiYRkDNHgLHTga6IHE9petT0hX4sr6NsmObTwj12iemAywAXOFHarr5j" ..
	"UZ3C/+376pVdNu6FcTPglE3TjMbTLXh+xj3+YfPjZlM/2Y873tG686dHVtCdl/HZMEflZOKvOEi2qMUGsephCh4Dz55XlXryA2+X" ..
	"3SKwUiYp4WdNkPP4v5UMg0V8Sf5l8uQEjo8ynKceUyFSz4IRCSTP1xJcXyT2UzbIdWrKg8UgSagaUl0YyvZv0qcMATTwkp895s16" ..
	"zcwsNkeLYrRbQXnAxhwao2UMeEeWYaaJ5kPDCMt7XUXc8nCVk6cQ60vELMcKI0l9v3z/6BmWGSS4G/gCLxiORzl24Hk7vfvJqVFG" ..
	"ppwmGP2hucwTPGj/BgiDuIgP8436KNE9TsClAGCQXhP2Ad7SiTifnbJ7OwoJDXFhbDFflhCAKyBwS3ud2uGWTEf1Gwjro7daZjLp" ..
	"3tjot8ER4+NEqELnaIyis25fX5lhSAsjcYEDvqCd1mY7WpEsQTEtx8VrDdOseEhp0ogwRlwvKXo8NtGUrJe12b04w0sTF9SDLM5y" ..
	"H9Vk4DJoE2xPVeER5pPMvhKvcJZT7RTorHuFn0brR3qP5yN9T8eZrWNn1VuMqqQgeQ75x5ePoMPAnehgd62bfd9g1pngu036MzNF" ..
	"Wp4PgRbji+pei5Qd9meRzNV0tOQ4ykCpou8jq6phJ9arNWTYUmDkR+GLOO5gA5wSwogePQl4/CmIGoETv9CpiBUq0rv0h3nASaGi" ..
	"wqquS6f6Cs25Uneoqkcj+bFDeqROtkZx22Q5lY0VjXc/TP3CvrtipMRC1uFlrP6uUU+GBJVlgu7wvkLd8TorYMD4FQlKAOaNDgDl" ..
	"Z0CeOuW7Ph8fIH1k2UGIBLGCZrv+0PAcABxApO/GSvXz+bjhXKVmqBDOP3zlT8p2ukpUdJnnMPpawsMzn4vOy4fG3w7VF2IrHiBA" ..
	"Fw80nPWtNeH7eMqmxHlMLNCU41OpfI1BNmB6cJFSAW2TYTUaUWZyI0J4son4qci6Uyliv5zKckAw/RKPB39XW02UGenkwnAm8DQu" ..
	"q2EaBovqx+A9Kpc2wEnWJ/DKVrmdJZo6gqQ3w/1KNyQxbenDCJ5Cxing/18/76a+aDX7RA7jRr38QuUmixwMQvqNhX4rlahheM/u" ..
	"96L7BRWUXTP9sATDFlmJV13pTSPjyV4ZWvFgOPXjaEYxpRF0FPmv03jMvGi0ENmvmYMwFDbFuBkxjEjg6uT6FnS4RpFEKgSpsnaa" ..
	"82udhE8FKy7IJNQ4ERLp0O2/TXRhz+RVBI2rBsEXq5288iQIPhhMU492Xet7aZOLJS46GwnVu72TziSRCPth7w0502zDOQG/84uB" ..
	"Yxxg7UiEcRntq9eD5HTE/Fgk6hAblKZLwLb6/Az/WojSx126U6+OMOrhRCjOz2veT0p+hcN2rOB3jhIm++IsA0T6vCi8Zj0KLr4Y" ..
	"HqAbWrP6hHMZCR18aNCDyEiWt/oj27eKPcSaiuzogAzRIcTnUN/wtqdMGLOHKZ7HVl6TJDiKXDbwlVdnVCeqJ20/LOAloHkU2iOW" ..
	"lUaGUaJsSzm9wPIsDOK5r8vOwgPidd/IY0enoLgzbU2med4lA8/SK1P1P6MzVxW7DZ3oYTiuyCbfRIT1Hsj+mvsJpU16qR+EnRSx" ..
	"0mo0boGtLAtkJSiWNclDOMvqcRpjNsA/6nb9xQE7CadCDcwIyGL7XvaKNbjTOEFBTCD7cN/pWbZv05qqQNMdooeLqvHC4y38G5ZA" ..
	"5zICcuZK/rsEVluii7IUncDKlWbBcJNWNg5XuMwbBY4CXIExHOoTf3/8wWAfBkeRfAI6XnmRIVa2T5eumyIrqDRDQ/b6u8gYvHXg" ..
	"p+PaMr+UM4B/l63r/pHzhbjzM1E1ESpxrVWugTL5/Kc1MtnqfgsbOabuANpLDsIh6RZnwA82v2GLJ8vPBeCdAs28hHHCqz4uWdjI" ..
	"pXuQYhxS3N/zIzJIxoCNIi1f7Z4ozQnyb67bWeSnqB4INisdwRwUyW3AAUCMOhCv2TEAUU+3RoiB6y+NPMxtLQ47/Wjr7oxF4HPc" ..
	"Okn+GWCMsInmcplT9MpJAVU3qs2mRPg0Cy3TKymUV4m2PDdw3X1d3KU3ymagnl5LMjqmAkf9YDQhozyc/p6HT7JBYhrJRnsVn4hc" ..
	"qoHpovf8PTTXHe3ODdD52ZRmfRHDgCb10ppwHmzwwsN/0opCp269YOlcHiV4jXG2zBF83Hv21WzoC03oGQJj/1AqGINZnZJrhYTr" ..
	"uLiPPhqxQca8RUu3gptMEA/wcrFcBmjWsLxdU38C0bjqgz3hMEBt0dFmiYdnggkgenJQQ0494sfaqYIfoD6r6ZNZCBrUAS4nJgMt" ..
	"6jtAKlYE0S+eY9WbiTYkhIu315klQXMNWEpvKOU/nOIR+8qEBf/Z4dueNlKHltk3M+U+WOzTKiFQLCOkFWGlamldrbFPthLGXtvr" ..
	"sNfcTVCXxTz44gw1pJw/xjrN9neHeeepvvG60hi5A8DIjVpHDLfCD1ETv9wJZlW2wIqDD/Sj36iiQXHeGOU3F5ggluAGc+nA9Rjj" ..
	"ratpSOsPLck4tLqafV9ZcC8EwxWyW6NxGXTho6O4ufA4d8pnd3jw1Lf5bP9qZtmkdg1zzy9J1LWKND8cx6hBPNwCdTs1eCdzBXU1" ..
	"WGITj0Ksd050pGVZz8PjPn/Dg+f+/wSt4ZzzMjucutnRJOP81AH86xSDLWVxJDtrL8XMTAuyXcrXRUw9YsSq1T3UXrjbeF3ppyd2" ..
	"GCu5osOq7FcHRyJVisGvmFLkO+Atkwt4LY2W3vfILsc9lAYglcCaE7OODxn/KLjR3EaNNiZWKTc+6C8swd2/VLhLW5Sgt1Hh+W/0" ..
	"i9SL4g43CUgnrz+InmAjoro6goa/8zjdw4/OkN39n7yXy+J2XYGi8xkFxOxjcixd4d8lLN1BOLrmYJ5ZvcoY9gO6VBKYWe3fq7hx" ..
	"sUeCKwxnQa0x5vnvHtGhpRe9VAjykhmuaaBmZD2DnXnzmkLRypqMcvjuFeugUJE/S9NEJeXKhtRJl7HqR7svtrQ+1mHMF1T5lJU2" ..
	"QMPBh8rewUeYjBlXfhgMLUAvHiBXjKQheM3u9MandCvzsLTq1wbh033qCI1UMogA1fgGEzj+8QJ02La+YF+5wlpiEA22NFQRFMxI" ..
	"0/XNYeddu7w3VA1L/wiSoj6fANmqK/NlAGpGgZWumy0XPPEUJxCmP/YPiSsupZ1XZaCrlLGoM+xg496AxEH4Ol903ccYbSmSOluG" ..
	"s/9zX2ZUobCDrFfuj1psqSe1sZBxg5d4Y/E0A7Ywk5FTIrU3HW+3z4OoJNR61UneZs3K7qNDSPM/0lJkKYlNl/++T+jU8OeKsC04" ..
	"VtdI2VUF7leIrw83WgRsbfUeD0WiGM3yHjK1xjlgAk1GLLvwDASFS16pX8UYaZhz1s5E3wa6fqV1dF4RSgyogxrif7E9AiFjvdGQ" ..
	"3RMMpUzqeUy52Uqr4eOBkvBJdLc5BWqnJRulLFefNd7S6LMr/kV5zu/EJ8AqWbQZtEoaM311axgtAUmAICaOR6Xmd4LNdL31+a6d" ..
	"jFYlbue5R4Wd+OoPYKQWZcQBWcODR+5+BHUSPvkAF+UfNvmFtULOoeM30PCUZJvPFYgJyHRQJuyVVFWti/oQ16NyHeXGjCcw00CM" ..
	"I6XzzFAR9DCuAL4mhQ5wZw00uqzaxcfAwTZ9py6sgsW6v6hiyNS0KNAS7OuMca89ofMOi1qvkO75s57Nqeop1E4j9SIR0HsiEFCO" ..
	"u2wyHXtQdrr2fq8yNHBJY0iwwPv/ewC8BBz71iMJ/QfeLhavYxWKkAZuwzL+91QuAqNTxn8L/jgz0GB5fiQhvF1tDma8KeLB4qQL" ..
	"RjtD5twJOfKknOt+CY/DrROpz5a/hSzcfoK3GgQ5cpW6lOdi9Ne4cWHAL/2LzN95W4dtkEUt48UmspgWLLf/ZVbSEqIQM+Ak05UL" ..
	"ENKh+3OKmN+jMJboIhbu4Up8PuG9pRgisjKEkWhXQJ5vqhl1WdPOsREh0XnTN3BD5gJn+MmVZmgdSwPLorRHzGbkbrCYwfWhruHP" ..
	"MmrWZ+lynqdsLZhgdw7pjO1pNRdRJUy8sw2EZ0+r0faKDYVwY1fmeBM1SamPRB4iaCL4E154Z3jAMlTBQr+paabzWpQUd0M2YdJT" ..
	"C5xmHzW7VDTFuEH1Ad/CE7yDEkn9V4YID2+la8HiUvoXGlm6uCmDzkTVBjkJSKIVqCXuTdWcI+mT+/VIFxtK4Rlcz7C7WhIToDu0" ..
	"0WHU512sUQC2nYBcNszuAbn7lrzj1SUQdOCqnZ2RytHluOqsC940Mv6xsmiFnwh+3Rm+e0GWEMChnCI7MbaWDftxGkUPp2H2GX1E" ..
	"Wyw/UvUuJ6/uU7sX/ccoXIrBviVoMXrOY7mwsuhriXVNzchAgcNJ1wbUXu4JwgIDU9D78DXcGPid3GjYfvPnTFJeSwNjeO8yivon" ..
	"8u4nah16t0MkHnCY+xx4Udx01eAa65aPpnzmFSoXs63CUSITCzxgnbKFn8eZmo4RTh5isiVn2b4VPC7WCvqz4Sd60Ufcmch4fb4h" ..
	"H4TyiyISKCmd97vfIdH0LyAseJEBQAvYOpH6ddL40nzPjMG9zQGGOK4REaXjhz2KGLOlE2vXAcsrJHirejnkG0pjHjbacyGpFZBY" ..
	"9Lm1i219ojoLQWF7SVOmmDN2ayvut8hkwax5zmltdB8erXLCNuCT1kfSrzS/i1m6/4T7pELwiucg/admD8J/Ba2ZXnJeH/GrCWWz" ..
	"r/nkN7grj6j4XF4UuJpHRffAyugsOyAQjkFEFIXUQZ7gma8o1myz+BBCe8pOmSEAtjnTu3X881dKz780h6k1qonllxx+9UIhK5Ou" ..
	"7amWDN6ItjWNycRn4DAe5x0YCAchvWKYWmcQwPW4wuFO2oOHGEchrrXo7oB7OJ3NiTFz9Rpf7Rthtk26wF61w2m0dMgK5JoLabIq" ..
	"8X6WwyQvU70jPYotSVnIlY+VqNXnvtJSbBjj+EwcowZCq+YE54XmM/WGnyYRAVQlwHszhs5AScHV+YomGTQLlHP5fmdH5ksaXRJW" ..
	"DbOeH2TQAZclzS0c0QN81UL3h1x+J2qTeY4TmM6Eve4g8jKe8b9EwGwpuX7LYzO9uc29O3oxKaU21TQU/Hu+QZ7g0tT+F/V2+9dN" ..
	"2dIDoc3eHUROy+X+wDRRC+gV7rmZQn7k0KnLa5UT7AqapbdgzvaUV0Lcl5wsUOnlhtCrPUCfIYyPonCv1qVA4yAnJDzWRfQ02hgS" ..
	"KeWK9e57jPyjmvIl5kxY/yyY24MNBJVaECrez1LKqm06goha9fq1T1nR0QKYQ/Y7YVdIG38rjh0JK0bzNGLZV/+LPPe2tMUXr/b3" ..
	""
local PAYLOAD_P6 =
	"QcmwSOQXy7TLijBU1Kx5wTS+GRHeKgT+NvNI1EbLwpyJevGYIummJU0LkftVdL1qHlGfEz3KdbZIazCwiEAMNLGrQw12Mmq4KUGE" ..
	"5soZ8pSWKqy4ug1NgOLKpZR8ZkqRHXKcsjAbZkftbM2o7ypCKOeCR2XyCi+vXaPKB53KortQqabY2YKhf/zJ/KRwnE5VntSETNPt" ..
	"fAnXzVEeYOw3NlIDgLL+qZu8QB+SuKhJYw4iJsc1mwPMX0lEvKZbMWPy1ukpvDiJ1irH2c28+b7A14sztBToebEC9sg7gNhwyz/P" ..
	"wJrdXq796i35j0BEBMPGMNjW9uPBfILlrPQ9gCc5V3l/EhfNchURWPmV6Ys/A0tgU7I3uWnOx6h/IhioicxImiYNnBb7I5ManOZy" ..
	"vBo4i112dbBe80zPJraVAmchwnqUodbuw5AuBK/7a142vegegcTYvm4OP7IIqf4+SdCebVVeP4AhNrAQ7Bj5+12ZeNAe6N4BsNaW" ..
	"PoPgZJ2/hrvidHRqtobaqbzTsS4qV3TGx7BIIapU5QqXl6OzPNwhCDpxvaCXY+ft+itk4PTKcT9DDgsxcFv8rnyEaAjogEdBigKu" ..
	"Zo9BA5s48Ln3yo7KcgFu2PM4A+W9MGBCT3n/c2CvqYD9iakZx1ILzqv3C9lJSW3JeJk0d+jGJ7WUtkx2WxjeSgr+/1uAhWJRVczQ" ..
	"iK/zd8x4tC6IMcjpSW4cuqnRT49HwBJGhk6IzlmqWZxTaaXGlz8jg+nemdu/UgaqniGOhZwg6htW1bDhzNSGXot2mQRmKCDzpgNL" ..
	"YOPAtYfE5kISSQY3DHLk4VWHXePhB7BUdUiQTR19K7hjkMQbhiU4ZQJcAl6S+fFEhvoyNvuYw+jM/TZixWzvZgLP4MikZhPZJj6w" ..
	"uzBGmcx5st4nUBA0yHhmccutDlr6Q/lMNkCsy8a+4CASOxefdd6EZB+uoCCzSRL0orcf+ecBlwzKRP07YOpdrhdBg9YrfkY3V+4T" ..
	"vDU+5KbfjU4BGBV6oI0EHw8Tm/oTB3XV43Z2gnRlAksVc2SdAAyfokouzBbzzBhm2uhpytTUXy5/cbmrGYUHwsMWrp41vz4mM8MQ" ..
	"QssHMI6doQTy+WPTtxOLJr3DNIU6GtKzlw8DZ6lpAgaGFpth8vMkDRdNOkR98IAo2UhKtjPOcrsdxZcEDTt15FO28msfUgS4IgZ1" ..
	"jGib8cbfclaurzXjOg7ijotVSPp1b4M+USyE4bvER4+RTAO62HiDiJJmYVqgPDir7BhPIWwRCt/tUCDh8HThpsqYjRfMHQrKPTNc" ..
	"IkyQPuhY8Tf3BXUWYoxl1pC/V8kF2Ix8H33nNL/877c2A/RIMrXGK3tPIgI7vL8VmhXDSg2eVmZgHeh2EspY2gE/GzZHi9X3VFS6" ..
	"9pVgWrCd1eHGvQZJ9KIzbfKcJHJhAXqX9DD4H74nb317/TmbG2DgFoOLvZXP02z6450vQcyPuvEPmD/u3JfstkB/soI77Bqfdus7" ..
	"gG51JpeiY0jUke105xyOwigMTrUDWD5Hyp2z6tcmD1BboErnQRhbqnZd/P6+gIckSPAI/R+pJhaUGhqt+AxmhZo3ta6taJW8pilz" ..
	"macVlxFP/u0ktECYbAgMEzGHQWn8AgwyM4Jd6MM+dKhKWd9/rt55sd5Zb1hOeCoQygvpyLhUH4a9BS6cMBwEGsWDT3ciCy5Sz3al" ..
	"6Oq+TwALWCPvJ4g2fv6+5EfMQMNM5r4IGiwyjl2ninuGDcW4TbDLFm53XBWLc5LPYSnyEXHY/+3Zzozn96o4rrfoy4yh9n5z2MZZ" ..
	"fVSQ7cKDlMKeRo3wvDXcczENfo1bzj44GOwwYrgsAAXKA5JTFxKsBUIXMA4jgWNp+wXkX6gDyNcNPkqihkzEnrrdGo1BkxukHe5U" ..
	"B37kHEnOxfw105g3iOkZ3h/Ge0GgrDe2mjAGEFmGf1M2R0YypVngbZ82CF77+724vizHxfZWTf9dfIRjTHfDrqThQnPvGJNpCy0X" ..
	"Wo2f53LxrdHrVMKL9yrN8mL4sccaL/nzmf3Mxl8fYWlRjTDJUzegsI21M1jfVsqSR69A7a8F+yqYQ7sZ9XPhg9vD3Qvxbjv7WH4x" ..
	"vI/dxM3aIo+wpUEmai0lfA6nY+Yzr4mCGfxGkm8sW7hf/Wij90Iz+t7Mm9F+QySVevj5hqxwMiEppJwt6RpNlLjWg8ZPqSNLQgaS" ..
	"iEsVPgvyFSWbo1H/J5q83AyhzUycxmQ2WphkMDOqFB9eB46IW4RA1/12d9bDJu/iFyBRobwFUNfP5U/j/3JU+i19bJxpH6m/ZpsM" ..
	"xIR8JcSaLvnO7cWG4H6lkrtQkBjolnuXCB+QiuJ67DuRM2IEuVTeNx1R80eYCozlkpql4pNguNgewJGECJZjYQHuak3qzj6fGA80" ..
	"oxwg93xno3tPpurLTNwR62lrU691ONm+phHuTKYItTrsASrgNTPn5SH6vOuEcnfYwsfVEq95UakFZrzgDGaNA/4SlO+SKftmMq9i" ..
	"dCp8gkvAbTGmLykjFaUQv/3FPyGx7neq4ddzEbpxrCNTIwQCk8JKTZOW9qIV8qPu13bXhgAMlgULfDa0JqapjYoAoO9q3BZ4ozKH" ..
	"4041WyHHldgrx84eZpjJFrE2GiP6kq/0QIeNtdckqGopWpvVWInLp6Aida0KOTk8sHbXrXWlLMEBt1g62sjzow3/wE7urWnUu5W7" ..
	"Cgl/KRwQ67isFtNsK5gDRWHFym4uuweq9CnYckUXtpRuSDy4PbCbugfvDHif95o0W8Iv1E4IMbfPsA82fqlxW6VMzyu9EMdR4H1t" ..
	"aYYIq7DlYjJeZ7cAT8DjqL1LcmPbr80WrRVIcDHoNb1RtUizDKA2yfSgg5oHWjItSpbVQ6RSIRc8+Ua0Wvz7JzyKDIr7V6v0y8uS" ..
	"dtDIRO7kF8p8neSlaHs2AaBeuhnDfqerum5BMBoLg86ks1cZR0qDR1ux6Pid29wNq2ewSqAij+rhaXj140zfHn1k47JTFUpau8gE" ..
	"UnByWRHn61Wuj5dZoII2Xj6d+TPYml9ZkiD1Uv1rViAjMJ6+D5ycCOVgvAXeOxpKY414DxQmPsr+tR57xNclu6R2CMb64TVD7Ukm" ..
	"2Q7vcXgxD5cEoY3GxELgxeoyQ+qzM8dqzlISyEdZUiU3Lw9sL/pC8fZm18G4/TcX+JVEOhI2HeVRO1KULyTzvPbPlvH+kM4oeuL6" ..
	"uxmxLUg4yJKlt60x9sfn9iUQ01feAQj6bOdfxd3rXCeQuweZxAqFm+/Hsag3sXQ7HKkL15lcm0GAZAwciOfpoXR5BhNoy9X8tKzC" ..
	"i64wFJYLXwhH90b2Z3v/KIuxpmM4XvVTXd12DlLUgKD3uCSGzLKvrpbgbrGbK3gjfP5dp3Hej6KnZD17kb2uQf2Tm60rbKCLbVeB" ..
	"hf6PvQDorngEyD3sLEW9uh2LOSJklmA+wh2tkz5dnlXJyN8jBcszJXMl26hsxif1Ce6DwPg8mh1MFsqWnWkPAz2ZdgvuMjyW+tt4" ..
	"iCZp6OytuYtTycq4vld4RKUUNywW1WkSv8CWpZVToB9jD4r4p4KBLHBqvcfYLrww0mh7cfv5mL1DR8wD831XQin40Q6M1V21oKvc" ..
	"bFskd04rlhTPgE5P+QFG+B3CvxOuHZNnJ2jsmftUh9iL4YEQLt8xFDGnJEsk6eFeCEj9FmrsyQrUwmJOX0TwyyCbRZoyvpjQyj0f" ..
	"lPDPGKndLa92v3dQ6VPXGLuM4YDTJUzB2lzUziIwrNS+cGjLjK4ngrHyDxSDxliLMh0F6a+PK0YTyC1CqOK8dVjmcYurVbzrCe/Q" ..
	"75Hyp5CT2K6KR1UAMqKrovIWdB80heAQZMgRybmzaEqoIYqTjEGpDqoRnwglejfeKKS3LL+1rv5oV0Mv51l2ZME0gJAfx4nLqQZ+" ..
	"OMg5UKMMlQgK4rrdCO4NnArevG1hMaZwlN/IkwAyiJu0sbrC65gmEb7tI/qqct9A4nhRUik3iiVagT6xpcdXiMCMkyqmzrCG0QAy" ..
	"UDm3uLcYCqSnEJSSpD7y/jIE3yyK+oF6aUT+V1ng7maQ2UofrN64BNuwwkwKGOGtwNgXn8u+Hrzr1jGReCFbjsKw1Cus5nWhTsqn" ..
	"06IJseGNh9j0hSXl8f5WH8U2zz05GpcEZbIuJ98Y5yh6k0yEr0i0fiJpTSY856BnyYDzokJR+85+0JTXi1yzEPehgsfOPKOrdDUm" ..
	"EBuFrk3Gl4xco3sJzoa+/rYevmDUZOXufOUInFdwreiBssmVt6YYp8hP+MnHGnaVZ+FH1UO0QbkTXUwqK/zMkJwWuYroWAEBZmev" ..
	"ZBSPETLeuoaf2P3dU7ha8ViSqMKUFIyQ5B2SCLmkU2Thpw+qgnUhbrkditPLFOfkBWEQgP5ZbYG3mipag3clK4aUvMx65C+Czya6" ..
	"2qzPDxX0jRhebnQR0W+nqrBBnc7VUDk3hFF4HoShj5bhhVYafh1vcRPN4RmuqVm9akRG79XCZ7OlC/oVGIXHSjB5dihEgsJGlZGT" ..
	"L7aMiIETb84JrzQwYaDPzwCZd4EZZV47p81wkqf2v8u0O5Z98WpafCXhI6SddCuFxqos/ZM6ouSZtmTooG6S3rAW4cVtyycw/3oJ" ..
	"ezherfawD6J8RpnHpvfgqtlEedxGWxi+LPBD2y7ql+UXMhzjFatBECfi3vm5JZ5wFiLHO+l5zvI7Gf/8XfM2Etrc0JCkJOza8Yvn" ..
	"RybOyaUyZKuWrrbJFVsPLbq4URRotQZdiWRHxF9PENcjPK5vPkTRTY4GkTfy9zOEmE12SaV9zVPVM+9e9ek7x5UNj7lgcuv8ZyC0" ..
	"X/CQso0+yNzpaNrJeYs5hb28tcdx7pqdkh0mlBWXJJdV9PKb9vUs8Rod4X080HkgeYJ5Zr4YbjeBlVyRxO4J/ztb7GbJDwBe5WKG" ..
	"BfbRrXoAFo3SaWD2IXZWTTkS3Htr5XkoMr4V2fwcNvMkUBpvzk1qFqSI/BAwD0b+QQQ/CP+03Ns3Uf2KcQXF8Pyc+Q5qLPjc5XcA" ..
	"10c6P17NNbjkXGT7paaAZ+r/fcDHKFCVSxpx0qlBNS/+Bv8S+QUqw0zWRNfOd0mWiY8Xl3A34KVFcO91bYi3476f98g26DFvhxPY" ..
	"wYjph54PXxaiKCMdFGt5zaYTTO9Qg+zLIqumJSUoPm5+31Et7eAwJ3Qgelf8P1a0QBgbLWY71iEpXrH/nwuqpfe1txIw9DsPBdR4" ..
	"78MV8rkgilc5R+hVs7KC0lKEy0lgIfGpRTv6zuPc7nEpz+NKRVwcgTZftIvpgw/tegcwOiIG7KruKIggbTber9PdcE/OnMCQ1qFL" ..
	"izdabCgO0cJLdR0+1c4fqPLGO/rThqsr5H7q68xLGpvD2zoesYlJ7pbiaCXMJ+MeZn2hwTw+BO3htQJn1u2xQ44phpE8Y05jVvBr" ..
	"mffc4z83QyZGC7vmJ3QIrDmn4ZdhaAldoNg77+yLh8PnvkR+3y8pAMjK4TqGuKaEw0EqNP92PTSZwJEcBZAyBPrO1kn9kEv0r4nh" ..
	"3p4lZ4QH6SaPSJSsAdXrliJUnHVhWP3aC/PkCy5ypcrTinLLr0ODOXmBLSpaRFNNisAiA2G1dTBoHCheRDEC5q6UwWwMRSt5x5Zu" ..
	"nSxLAHplQSW4tbgcefs1IwVWq6Qhw3kSOIceox13VxvfPcbvQmHdNKr7Egh69YkTi2Pblp0iWy/4vELaR/JD0fUo2cOB94ak7LCw" ..
	"l9YB3AOfr9R9mVpuuIzKk9SPm3UR4qHnUV92WYzjcpJqoowc9WW6FEwgUzlMKuUyDH0Q8/feOOdl9tav++IhYc8mq9uUCa24s96m" ..
	"H/OfS1VX/z1IufR4RHbOz2z81YhiFhHwHo/uGTxQlqS3hQRpg/SMQod5hkl158/NLhEW7B7zhl3LdnYck57UbhsyZ8zS0EjOh6wm" ..
	"28OnFfmKw8Bba7RNTouNsRfWSZ5V9cC3ynXvaXiv/Ibe2gnRFawTQ1IRc2O8/8kwB8Xjnjv0jMaia21mJA1WwRz+pA/POTssRtW/" ..
	""
local PAYLOAD_P7 =
	"Sc8ZrY67vmQ9DG7BYofVXSABo8FQP+IagaBTQQDB0SsaTe1GlND1FmZS+2Dyl4mmAR7mQjITd/oPZRUiMAcgQifrfIXzmEKkHfyA" ..
	"IoFDNHEDC3kQTeGKpdi0nMIfMcuUE53Y2pYEiKGuOEUnwg+FqGSsj+BYSsYsIMoPGUr2QUtDE47PlwQJgnPzgnpcXWzcvefroL+G" ..
	"4AwBnUGBA3qhd8/bhxD7zuMSyiHmB3PFuNu7D0ERPMHpzCd6gjTbl66gPqPBW708wjqtx8QaJqCoyc0dsgVa2dhMPjB9EOcdaHMV" ..
	"9rEQO2SUp1dg0tGC4zZuHmIgmu5UqUGgNuVNqogcxtEJtWbrZIU9DRYYn7D8A7AFR1GT4T6jv8nOM2ari74awyMf4dDt4OriSUrr" ..
	"ZRgpmGJ5qTvGCcag9FXZHwsYswCFqcAR0oQjDTRECqiytL3XOC1lDiIBeNFU/PcMDQ+t/fph/BE+LJ65DwvXbavSpyUkC8pMFWer" ..
	"tyIcmndjSPAEc0qhT89iBhcDMVMhED7wnmJFXwAmUELlw3z02/8Rzr0s20U1gHDiZILptAmh+LLgEpf4lE7PRmczIa23O092vjN1" ..
	"BapelFNMmuII6X4e9evLpmWDhpv2DhJun6dCZxIZlEUpJpjVlOE9BaT1UGqSIFYpe5LuWBr9TQ9HO1C8vTe+VEpFAibUtKb0ee3g" ..
	"zOeUieXaO1zsMga+DgJoZvEYJRzEtABS8eWSfrOLm+2BUUxGAV7RRJmp57UUSL3iUgnHBFxtI6xvEeV7pETqUVHDk//seFo7vo7i" ..
	"Xik2MVSh6jyi/gb6RWfAEdWEheO7ZznRuMYEzJO1vub7bNJOhwdnqDczqIonjWUIZRZna3G1NI4NlsJy1FVHZ1zLfgFedR9VAZPL" ..
	"B+q1zypZFefEENW4GpDcqDZizVgD2Vq5fThj8Qq02K9uMZ1r9qxUSPhr4kpBvM1rpIcRf05npLf0WoAHoXLg4Qb2Hy18MJlp2Mx0" ..
	"kVAiquLe0+BaHy1GqVpjHM0P6eJaCTOcHC3rXip0iHVvBOVjIAke2ShFn3Ec1jdh3qVZ9e7zdEhjNmSd4QIMtSQpe7x5D8Nxigxi" ..
	"YamETgrIQ7BRBrHE8PRHHHC3r22T5GKB6XSE2EDmldZJLXWDCEzMMZuYIb5YIvPN10/CUq/YdGicC9qCai9YexFRG1/jqZjRViGR" ..
	"HzIyv5CxKdcvYCQAR8RsB5IrhuYO6GsTHg2DdAWMUhSzjLuQsI1y0jOIoZgw16THZFTxDfpbHnd2DR2jywnq8XwV0U5QN6wpl3Ga" ..
	"0CRR68HkiPt4OLf+Q31BYJ1Zu9pUYXn6TUmVUiIzo+1SlXaUko/2oXlzgBu9N396gYCUVKlag4sbBaLfKkaeAQ+p2oLg/23A//pj" ..
	"PVqR65oF9cRNGt8dDJjCkZUf8IxUGJ0yB3muS6LJOMSqmBjHdFivWsjxVIgB4JSYg87JonVOMQDjrJwn99oidVuljp3hPPh6oaok" ..
	"aVugRYZ8IX1Ovo83FtonHc0ZXOq10V5FyFNFeWIHqRpUybgwPYPAMEue/yHe2Kr50ZBoq8XN9Y0X2fwEIR7ZgBIWL+++MVsCeZ4A" ..
	"VqOkjcPqSTqlOOd6nWaoubcFzorA7hk+3RW1g3wY041kBx5hOinLgFd92j+cY7ULisSrljF+6a4I08n/EGfDSvdqi8JxfH0u3tQx" ..
	"9AZl7lE3D5mkMDp/pebaqcSHE0950k8fYgqD7TM3PrJaC0u61DSMRICriu8bpbWgBLtdFn7jD3FK2S9GoF4gllmysyB4OJ+3B77I" ..
	"kGg9pYQ2rAfKcHdFJl/RQwXyR8XQerRf8GdaoG84pFb1DWW8vNJXtsyrtjFIWf2+/bVNeceXluxZzCdGnPueHW4D2SzGrlTxUh33" ..
	"+px7OzdSQqQVepQHHZYq6jM+V53+3pGSYw2t0EfDXpJvhSboQ2FJyugdSF9RUmegUCOb5rCF/MePYnVPGNoMtvNgZkNlLZMS9xg3" ..
	"RSlcOPD6YvdwABlHQdbg6EqjJ2szZP5xdc4PcyVTXpXa+2MbZB0QQAPS2CLWoXGK1X9YGya4hEgpWj0hY0qhUpSbHdboHW/hJLTC" ..
	"as7x/5Q5qs7vk09r3s9hr9ZVvq1bkY5puDOjZRurwe83yIGBlSDLwDWVs5ql7v3+WnPzK/dogj1RN1kfBiWPpETQfj+lK+UFu2fP" ..
	"VMjpR2fWKQyuY2SC28pTTluWTotYiiHNFjvADi3Rdxhzs87qg33dcWn3Q2l6umfszLsLY+wjFhESaofPfFFVu3pXCBp74iWfc8cp" ..
	"MFlsFK9gzoK5N7LMuYqiZkGVCnYKLCKNVq9UlD3oxZ+b0gO2Sl45CofSv5xVUr6//a8Dl+EXkJnBpMW6Q9UOWVBJTqw8DwWwKwrP" ..
	"bB6nOaSAc1BjVlfr4y4XLW84FwDBv8qsvrBerMhFH2ZDRoMlPSxgq0jVT0r5UMNSB3aLGHAvJCh8cyUgBoRdG7DgWvFxSEc1eyJj" ..
	"CYNt3m/U5OUeVup0RAJjWV/MO7qzwMlBFvEkAKyu4mD5l7m4+qcy9LbpAJDw9NECF3413E3BdOqxcXQUBPhbubV4DVE4QSlHUSVq" ..
	"JPdqqFvHtnee0p2jIGXdkpSc8DshX6sZm0dPeJ8RQHQ+MK0VAuryL/+VU4z/85mYIiQv0cjWbyw/AbqMhYl9I84nRGbCJPbnFWMD" ..
	"KGaWsKTuW4O72vbUgMyogW6Hb7U3dDNpZ+s8eppw9wjWPp0MpMahA7g60gnIC26dwBIfVXO0p0FG5WyYVGqI7B6Di+Cv2jWcEfEu" ..
	"rztBEflQ8HAZ/bnlkeKXQOKPSN5L1gK1XR/FnIKXREKQAQaTlASyLjZT7/KnlR8LrN1A8RQmPRj52p8Wd+NxQECn+vvbrnI1M2XH" ..
	"8JuA1iz5ffzBqZYXPyZbi0Xg4rrffoaXxE9Sn0ANmpHQ+liQY6DNP5ICA9YkChYMRmuJvoy1atxCyEYcOHGxWF/nXvH4WPJuss2y" ..
	"PTzcUJHtd9IntRwYr3U36v02zRyIzSplrfWcZjzwsev4JRJOo76uIfWff+lg/k2FcTtk9+d4DNAWsucbHUCPDG2Ho9PQ237LJ626" ..
	"vLjv0z2aRcK4kGBqTwsZ/GOpNDX11Oj/qLgegtLyQpZZOrU44S7UxjXYGB9cke/JxGisQGrnk3b4hWHoWiCZVpCeTeO1TDYhXKTH" ..
	"/sj4l2xxgYqAJEdquDl2lA32W7GaSVQYJm2X1szNeMcB6NBzq9p1GUu9yEAEP3H6gh9zflwGQTqy0YeeS5TrjD8VLUg1AIW0CoNj" ..
	"mdLsYw1B+hLS1vINtQEVh0G6rk37CCA3C0vYD6SB7ErDqgexAyC0TsWQCtCjB1QFxq2yaOOJOtt70MkXKCy+vbWw2wR7l5hrmtIZ" ..
	"YjH3TPO3A+wl9cQTd/GgAcfgFq+cy3HM4dt9+dsgmLMEEPwwJLQyEEwMjSIc5C1WA/ut5pxXdsIc9tK/AnPCiBJDvi0/N+BxyO9M" ..
	"bNZxKVF3c/GDCNGw/DPaW5qSz2NijRUYenRoX6qOedpII6Y8hUgFTeL60qj/yuROYidbKiOYhmy1eGtKBiLzFufV84FeN794wIj0" ..
	"2aYXi6ylTooW48qIw2tHNI1vebW9YQY2C7q8siWrTcVdHzhLbQGMlGI4pgKLlpnbxYT/GaBhjXCCqejiZhbdiCDlOh4oNWxGKWfS" ..
	"HIJsIxxAmTBCSdpJnckFSg5uG4EcHXr2pUw0j0O+rcV0gflL4CpJrFuAaPa+JSo+DBMfHBe8QOZPeOsX5wJL1iWenFBZdL2Khrjb" ..
	"aUdL8xazwA/NwMEyqCHJhqpdwCyUG6MMGa7pSd1QlRirmxDZjqbdsMgHFbcj6B0UxvIr9T+4IOFRsun6yjfKaNQPHbp4VQl6wgcI" ..
	"7+OrRZdWScX0drZc0BFFu8vFH9cDCWxd2Cr/9kyYbK9RozWkkMG12BLrgoUTk2xh8uw+ci274Rwsq7IoQgY/xl7b2SHGeBgOm00y" ..
	"hMTOxnfalwiVlcJqzh7ZmgwT8nbDDuHnxreqMiMkKKexJ5IQbmoHRWQYPfbGIRB3fcTKWuoTu3ukrQfflAbHd2joiH8O8dK5/6yW" ..
	"QO82IVZ2XM0W9avEJkMfxKZJ6k1i08GjaRkYe8WC9YFhVaKevYTQ1HLkA5br6FeFUvQzX8TwOoubEySxhNDo0FIBVyyc4HtdjBpx" ..
	"iW65lBk8lhE5Ju5QsBDHYwgvJFYftMyGzszGkOGlpZcYgj1BFAJ0+TH3eXRkRTzLu9xjaRqW3paF1IiNGRnNvQl2sUOvvdwSHOkp" ..
	"xdPhwjVvHsfVvztjY8vbMlXv70/aAc12wHPcwBtm4R1Fz9yQcud+BU8q/wqWYLqJUJ8MpfRY8fbtcIkCIcSyto5EDILvfnPMW1Rf" ..
	"/j/wq9Lu6fGWxjjoW+iug5osVKBtvaZuJblcSUQzJWH4e4BnYCBmEB98xchUoekJQEfrhcd/nduvCTKbmpmnuL/KJ8P4siXUAcNl" ..
	"kI7y2PmmG9opU14W1kxrEuHaBjkC1pvF5Dd5M5l0bo2b7R6y3kp3TkH8Amn3mC5rTSK15Vc9jgLH3dLUXfbNMCY4W2Puiu8Xw9gj" ..
	"Dh2o2SzcJm1SMnrYk6YkiHMYQTu1uFdRV7s/f/TRPvrWlWIMl3KkS9fBbfBQuG1PDW4/A57DPRuMzfh1yuRPEeqZLi+T1Twns6tX" ..
	"qbVO3Qd/fNxcFEppm4a3taoCxfkaOk280orSSzLZe8TnaKeYWnwiWJdKMM5v9d9hhipDIqwkxua+0Kmxj5hCINbRo4H4Pk525Wxj" ..
	"gZPrvdmRBW9DBXfzGfjDyEvP6o8OzC67Vao83e+9EwrVryvg7zit3NpEun8zapiAOHI0aqBx/zRYzPNhAOTRtaA7i5hapooOB2GS" ..
	"yZLuqze0xj1M4yfa4ygEyIQAb+DUnCrXQlajG4R+dYOUDqpLrDv6UZvdTC6/9mmDJ8vCHHel0icd9r3S2q5wlIYt8B9Du4SOFLuS" ..
	"/GW7rOObmApg3A9bvEsIrc0HvaLipf0TP9l1AaVWqGs2tWT4a9dBlsH2t2eCrSK30Qy8pjSRn7SgOX3/b5oeR+ePKUMypzfQza42" ..
	"M+dCPCYnwNjls4yXWCPTYS/j5EYgKHXcMUIFQpb3mPolh1UEefAVZmBaD7dKHc/p+AS+leFpvZNfKJ8SSckO6vXjaFOXUZ1x/2ug" ..
	"ltk45ZZC3SlUuMlmgzzOrsDseQsq4sJzJTQzjWB9cwn4wRha8GW2Cn5WMV4mri4ptN39/oBOAmvy7yGZxV4PNAj8ABQVEsduGWQy" ..
	"Hvuymw2UKPTkWE6qRspr31oV+YzXB/SzG+S/f/83+Bppv4PrcEOzWHEHTE1qgDOyYrgiRKyhcSN+7UuKlSgB3sIgS1LBNRGjV+xA" ..
	"aTPOaR68Gl8wlvmWCKUQm7KS2X9aJJYkvPVa1PPSQ9lLlamBf+pFyCTcNBLKyE9peuqqdDEDA2Z9dxLJ2aa13I6yRcMxiGJ2OWz2" ..
	"cGiZYf32+Cnx6Uc8NFD9PXHt3WTPrQ56yQI3sxMNu5+u3v48FVKPkmbFG6faX1osYvChPvFqU8UN7R0a3qGKR3QsyCnHIP+KqVk8" ..
	"umH6iAIkqWH6PN/AhMywKtsM9Szv8DFOnyDxfrlFKU5TgSwd08NEARwfUHHDvWIhdo7nPNYL4SZ3MO4BGdWV+oBUpM9kfLD6fxCy" ..
	"4MtfKIncn5PC86GSQQMJdxcHsxl4RZwAo9N3wkzxr35FvIxaUNI2+f5HXB+zh6baUANJdMEafUIUpJ8/tlmB14cSgFoA7v+X+gYs" ..
	"t4d1PR3PPCiV0kUZIoegvSHtUpArITZDmrqyOXlZBnk/5syPZSElJKUZ8pFHPBTAVx7y0hfDzNdbpKHSI2mP3mD9uNCZBh/KcGAX" ..
	"0er9m9FMSDBdYjTv3GYHucK+ni/XOXZOckWUhneqKSKwrvOJKoGUtknb1xj8NTNDweMvhKgtGbQfbMNHhynRtxFNIDmkwrNweagu" ..
	""
local PAYLOAD_P8 =
	"PAsPVjfQor7iqF6jOafgaNBiMCCUWsubMk4wyLFHAWQmF1VFoU0dPRgmzMTxVgifiTgMK8L3uj6QicRRq24CDfQC5r96cdruGQC0" ..
	"EChCq1SOmYmaEtwn6gXFFYg6H6PY+Fx1vlVfmIOoQZv9PrOCCo1pbq0JcvcJb2x3jemV9GhynNQaDxl5JFk23E8fFqNcweFuPxC7" ..
	"kw3LqPKjECemyffJ9kOCnNv8AA75Se2429jPOkDGpcgewHcaepCamh7B50EJdVSdqU3vqpydKjaZH/GZIKoJVsy/NJrT56EIoug4" ..
	"Y+5hwgaUQv97M4hn2qeCzZPmyneiZClj4StwRdIcKsWExv19Dn5Em7lF0vTqO9qoKl/ojFODEsl+GXeYa7WO7VTVAD2AEIPl9mxn" ..
	"ZA6Gkz5WDX4RNuRWY+vixqkuvVUPzO9iHN5FSKoTVgM1RWdTX9ikTSW3GlM5unkwfkeUe+74LbSXQCl9kz8/HuesoVqOTtdEb+R6" ..
	"sjWQTxDU1x+iZkID1nfjUuxzY6JS3asxnM8qHFcvU/mZO2lZ1wbP5irxwcwLPNUPs2Tg2Ydunt8QfmaHT4O9ffaDW8NIWB0Upj90" ..
	"9gUjlpCl1MP3f2jC+YyYOeqZVWQNbDnPV02R0ioRNi4ILYsMn4nmjQPJQ5uU4+d9dv7UnBv34mxYVwFHQyT8XcO4NUd+wqNXwbxB" ..
	"TjMl035tC9/eDoxusGsGZ41+4cSF8Tg5PXAsWnGcP8xV56PPSHu/xhV7z50JMnj4pXT2y6hz0mSb+c4SopSnKowtjH1r+ketWKlf" ..
	"hi3uQM/4P5YQF1+q5E/GEjr61mZVHdSoOezdhHudDVY7683OyeH/4y3KnsLmqbu4r1M2n1enxbto4d+DTHzRnM5yroS3tImfvieq" ..
	"Ki7dg6So1aw5kPeJc/MVxY9RnTOnaBGD/M0sok/gO2X4OI5Q5j/dGgbaHLFxJ/gxJ78JCp9k9x1lDkV3VLNNoh5s4Tg6U1PsDGQ1" ..
	"rRbg5lS2gPQwb+xgSqkZv+ZyP8xjGXmaXRQ9JNEUrAQApR13N9yjHWXFfqsJ7MqLSsmKuGS+hV2ry/jrqs43e8GvP+lGl7UXAIfk" ..
	"OOKKYo/MNTNwEw2R4JUJ2mhJNFOaW7Cxcev9BtHGwxZ7baU13+JQ2UgMIZd43ufyPoPbRNNKnzcgqgRDb3iI6OdTI7hxIN5F/Xtg" ..
	"WDdAaoLiO0hhIOJlsB1akuCVm83tbKAJikYD58ezJLIkVSQHs1ps78aEj1TT28m9svVllBrKWxOzvb7+hBsh2DpPpSmZiBpRXYxa" ..
	"yJLg4yqf1JeJOj9UngNEWbp6Rzg4QY61Yq5s+aNnF3t6fSMBkKqYIWzoDgSxA5J8eDSdQ2I2dpbEzFtiuwA8g6hl7YWGRYXac15w" ..
	"aEmC1Z/hBGNLIO3FmAdcmZAriItiSOXkcYCJ26aYTWXws9fmAw9PSpUZ9a+3p8RSftCnBTpgXHGPgaLhxBltmHk0uquylPPoaHc/" ..
	"t66BcVj/+LqI8T6Kk9kNkB6it9ErS5Swt2lIZuZU71Ose8G+eOIfJN3byGuK8shOHTY9fjgYAC/ffeyty0SF/yW+h9GsiMXeVkmj" ..
	"nZqeVZGlMksu7n9vEoik/yg5as4Ndj8m0HW2xtnLuFNAK8f8G+f/nwdaUXLcRdoUJ0JC7QqcoAyD02qHkwS9WY/FfprsjOlmrB4b" ..
	"ST/rgZ3yhjcaDoa1VVKDps2OFkogAI/azz3QYq14IAst0zOR0gyrtShCPyQohkFHCsj0e9DrPX6d/QJx/wvgTJKa/TZTqfBvpgdo" ..
	"XM98nHq4oATRvEWD7Puzbg556ioB7/gGIiOGkzDyCDewAKJrpdwKtdHeCPCsZE1Gnwr6JCj25Mxpjy2FXVgAC7XBh1iDnMeMm9OI" ..
	"MeHogTE/ls4A1owHmfrn1QlUQCQyrYlzXGqPU0Iv4XsqEYA+CmwJAC4DHM71MtcUNHzRhnfd8etHH8brgfUVuba/5dzQeCMNRTxX" ..
	"5lhpx8RbHHSahisi9JvH1sHfP7lrdhF4dY9EBdNSHEpg8RQwWTyreVHDf29qVyOivvk+a7ztc+/5L146fqFYn5nLYFPHHFsGAsDX" ..
	"E6xVc7JGpyAgRYj0VWZ/hjCh6Y/8ulzF7eo0zEFjKClPVMwCmRwvS02hTOF3XWURQym77zPhchaAuu5E+tpU7iNF3R4YIFF+A7MA" ..
	"MdsYNOgSQyFa7U+OO66Dr1SjZ90K1eQPmGN02IiVEEE3aS/LKYLj8ajz8obbCqFW0omekyuLq5tIeVZJBnnpmIhPNhYwKkHDj9+4" ..
	"ODYNeCabbYMSMsxVT3dzTk92PziDLpWiGFTP5PqmFZ7WK/KYlcoaxGCAvCXKJ3W5FGc9oQBga6UArFUD3n6w0Dc7n3alETPdjIww" ..
	"bfqNFEjhITTDRsR3RMKtYrEZc/WFymabAWrGiOuGJdRHS6PPph/qSbLAu47wQ0S7pe4QWCkG8FlutNiLylnOOk8eXjADgeLCaPNU" ..
	"EOZcx/6HVCCIZ5JOCwtE6r5H1xfF2HEPW9TCwNsghPNOXWIS/xK/JhUzgzGNNie6MhLin2tta+JDdIBqVCHpNwupCaQKe5t0ohp7" ..
	"PYt6uyHduJoR0Iz4mZ42vMsnS4O1C+HwBLut0e+K1SHvUlRcMBB5vgd2mTwJFk35GfyPrGqrLR49QU2BdEuoGQOm+XDBJhoZyc2I" ..
	"OaTVmVo9n9q3PomsCXDHUuCNBAQ8AGyy4bNMOwCRHtK8GB8xRdldRWZLk61CcO3eZ+TiK5OYsC/rKPUSexlXfXueaUMjRBlhR8fA" ..
	"+YQyu1xhW9UMVRd0Q1QrlAk+ActuYtTkcHv86NvR5J/SWxe5QdwNtm6qK3J2YoquvD0lFANb/pHbI8fnxj5k8MmRfR8X0uaoonj3" ..
	"LVzPYI/oHSKRm+jCCUMnfz0e2EAUaLr8hIeVIIvWqZRhGCA9OoiN6yMA9Cfq9fVWVtiumP/RFIh4Zoq7bVDcK/M92V9mWby6rstw" ..
	"opJnng1nefnCqpdZuH1snCmU0ZI7yFDEPx28rOIK6o6ipuH7SOdkU2mETcipuQNGDI+/YzfKmeudceVNzn25lAJPJBSWheYdyCoR" ..
	"9GBykgTRRu53AH4zVDdtjkl+gk3BCPEMA8Ff7D8cnmf6+4XVrXdeTn7H/XD4bvaru0NxFntsFkfL5Dfg37DvawceR1gUxM3cyfsT" ..
	"b3fRgCMdGdM2IXeCt1rpHywVflHDOJiAL56G0hbzwWBr5tacrOYWqOaeTTgBkfRCIhg/qdDdOOKrTlsqNqeTVu29eBo1WDgQItAL" ..
	"XsvKGgw8dM1rytOvnDczSXvoglLE3c9T8srxVH4voYH0/g9RO15EBVeOtDZguQfix3oSY6MzX8Nhea40Vj4tAzvVgobr/C38NhZl" ..
	"Mi3jvK1yfO2VQ9yVBuIUiouTIFzvqZcA78lzohHEb+pJ/Xxi7fFmXzAD8G717VUs4iLTfPRAplv8snHfFX6/Hx9ixfPFl/l0k1Bu" ..
	"gFnL0s4fqPR1HAuFBp4LO+D6wyxg6t+4o+rPepzUZ2ftkb+aOgoZupM5yuUvJZ/maARycEjib37ejNwyGLYfbEnyH7c2nr/GjC5T" ..
	"DXCEawgBIRoUnJSbW95mTiUSoTBy4+5elHYHAaawJwXqG2ObW49KlMKsfDF4ET7b2dorNGPBTdOuNtyin5F9aqJP/QfUfn3qgzHD" ..
	"rqddu/O2MJXj/At6xoDJ+uLPlLB0e7ednq5bO4tOqcCO+UcqPerVmpz8/l0TESCrw0f5LbQvJuaMkEL55m6rUBDiU4vWm+0nhwGq" ..
	"IG5QvUah92/o+pvl0ItMuHByxK7gQ6N3g8AVX6KMwJBPCsueg4dh/5iSNJmCi1iIW51rCUFf7VvWbbjM5gyf7NbPlzJO2KTyTLGR" ..
	"xLWAuhczgqxUB2tHpjA7+uc9DyJUS3ITvz6ggD2Ar2KUVi/XwWxsqZgqhVs2kJ2kHE5O47KDEQLB/+Z3eAUr+1x3HnnQA3cTBs6I" ..
	"Veev5CyP4Tnio2lLkKczstDgAiCPgRHPe1kgBns9T+cgzJCo2utG3q76P/1ZCVtizuvGepZw8spc6zBL4L2nrhl+CMrISsSOtn5u" ..
	"ZjE4NACuKaESVQUDY+t8K34qisBaDPMGvML3TeRmNVBQbkjGL2jH6Ah5Qro9Xyo3rdHxrXiUOhFZ+mIsxErxBW86QDc6cGzInGyI" ..
	"F5Y4n8OQ9e7a4U8ZrJrC9AWSZZZ9QWofWGaX0G0gdDDpnGswL84wWOpv/7o+kW2cK02S8nNoUedVB6GflOT6yQymEnMk4npcHLdL" ..
	"mnjBx7GYvGMG08adhXH8lGZTumJi47StsXSszufPcxJ3T3QLqJgcH+Oymh8ArBaYsQrsbd5rmWAiut7NSl3ODh8yG3cio4QZ8zeb" ..
	"MQdh8F+7i3huxc5QZMQkjluBWYBrjw2BX9m8vNLye/E+H3e/U+TcQ6Wa81/1jeANAY8eacelCluY1qY6VTWdrxbVDvq1X82w/gfu" ..
	"HWopjkVTJDZQfFCs6ypaMRNFqP3YR2qBxW+RUy3u8FrXqFBMI3jOEcIAJDuXEcf2V237H4rDsTmr8zkDYg9jHYZjCl+E2/t6CpYn" ..
	"p256zvMeEX4qY1bPmFLBuigfcT0Xo3b2kBXc2NXBD89OHe6xQpSn+VSy2eM/V9RWBu0zg3rLw4I0A4tK3wbvqDGTsyaGyjKkC/S4" ..
	"Z8eHUu6tnl3VymJL3akV0lMhcra2krxnQ2QQDYDNX1ADB37ri2jBNEgO2uGeDVGilJThFDi6+PoCgF7rJf9zisU3UO2wFJGiZN1z" ..
	"J4RZ00Ez68dvzdGCKiX61b1nzaHmeNdGNpWw7jGuZ7LMjbnPnOdsDSw4ntuNpDPQgZ7aP1BZXUDLq6cLGBDmWTbiZ5sotI/NrLeH" ..
	"r835E+o1o9kourdn1SCNUDdWg6Ee16J1JUztslHWJAGVo32QCl2Zx4iRAvFnu4zv1lyupI6ty3ty6NiZp15/xpm362o9o+ODhBdD" ..
	"jsfj2+zFOpyYmoHnJTCEU91XrNafJJQOmxOS1p+UUnJ/fcgvdx4U/SO3DxPyyozft7wwJIgSiG9vJBaR4YnvKKux/90r8iZrWkuw" ..
	"R15IQMq4pcAk9FELPvFq3a3ULrn8n0Vdm55mtaoYw5KlVPCyaKumdBktS6HwcB7Ht5BBeoShT9XIgrcdzau1wF5lydJ6l5xOA9GH" ..
	"q3AEntmiTw7nEU9MxhY7TdsLzUD+lWHfh8K5ETQg1EEBc6DJYgbp8E/UDAT4bWvgvtPTeeUHdXwfd8p0LYjkfFrFVD3/QoLkgnPg" ..
	"2xFBspEnEfiZIETpzBfYmq4sfBpgtduUk4LF8xA1zmJhlxB9ZPaMQkP1NhFZGM5YT0E17oE5eIesPeGI3bYSM964+VuV7zdBI4DG" ..
	"25lvLGZMPmxcTxZcUGBMhHOCkXr8YR1DO3mwbTDNXk39RUD9jFixppxdy6oUsxv9d0FKcsQpsh7+p78vV7Bhn16BTBIiCmAKlmCZ" ..
	"Lw4+JXIDZGLIJBUe5YJuQz7CtbTmk4jwfFynczB1q42lnduSOrGyLZx+rUApK8UxmI8KdZth31VO27N3J6DqlpvDP3a9NHpXp41q" ..
	"Tw2iNb6F+rQJqHiKb2ppABgatLXxQy7S71t/aN5NnVWqDuyq2l0JtVEgWLW6x39UfYsvshssYFgB7fPvjTnt8JAeB7iTuuBTgmx8" ..
	"ZyD+Ia8cs9BT3RLKazAyKcEcJP0bus6MVxRJuqZoAlJAIHQRuwnnl6JVGu5qbZ3mzT4nP8bW8J8+Jcb9FmNtEZMyAoAqffYBUD0z" ..
	"fzHayFOchHDEZRrpmFBo4T1JpxOXsbT2fDTcgHE3nXibq6u0Kmsxev4iPtcsLSCL+c/Ak8Km9kaikhJM4CNJcPVq8upSCosXmWDL" ..
	"XvrbzD6bmJcYw75/+PyKVcDutMqsqfj1J7SfcrQlzMQ1h0LEe2ObRrl4wfXV/4Zgk0l2JaoaBCPIcp8fGwAgd+MjcR/Gy7di7Ezg" ..
	""
local PAYLOAD_P9 =
	"Y4pm4djl+a5kgSd5KSlMM2lllnmZpOUxe4zMXO0qiWPxO6YXouThYjOtlXmC31XbMyGQbXRTSl4Ohk92OkwFr+auqr3bFyITmKHQ" ..
	"gI734j03gNDiS7tCWwmCdd4dGy3Fo/VjWtVLQmjOy8a4mhItNnYslpwrGzkFtCjNcA6GPmt1WNMYwUizboqSY55aViRVBhk5iiJL" ..
	"BoVenU0XM5EoC5nB8n15O8zKCojIM7MIrm2aXmcz/FivhHQ1SEwm6bOakyvC2IQadbIFZZac6NUqRrtxaozx8V0ZFJSkuZbjkNt6" ..
	"KSFEPLdEbpvF4AfGIWirxtBN4QsFfAsu1rJ8foJZFh0ZGaCCUhuj1V30KbyqJ31LUfa85dAOcQkh0xxlElWoZX1emxSFRWxFBNC5" ..
	"j+bTLYQNix4TyB4vdyY/kDcbVDycJ+9lJsvzLEU0kG3nW+CGrzaA0vdVLZ/HdntWaGT6Ns4o9rvEPwREQp6S3l5YSd7p/MWXc6hg" ..
	"xPL3kbprL5hUn2ueiVQioSeTI/FWNbVL2ZiXaaj7qVzzprkpuQW4YWvSSirkIlc3Xjy27dkXms6sArOQV3fchrF5dgplJwvoGhJk" ..
	"jTrXJm0c2d00wCTGNfdE57twAbpm6HIPpUacWE3ZRLdxxpPbbw70WnTW/WbLr8aF4qE/HS/U29y+e+9FwwyE3VojYyYb8MzlQuws" ..
	"zujBY3rRBw4IkLOgDDPt5kj9VfzWa7qDhjQBcUVbB6f+Pth2ll03TBoCE6t59FjWTwDq7D3yMd/tLDjqCdHAbK8Ah03YStsT3439" ..
	"HGJsaRfw6TnOtn0Umbfb6o8CZb+ORD3wv2J9nYAsVxRbVNbzUWzUypAf8WJEiQw10CnjcDAnLHvAsNZtn18/d0UWur6X7EGOEgny" ..
	"uG+3tdWLujYFjmYQ36CanUVyWaAz189OcaUGi+SFjQbtFf8UjPY6A3obh8IKo4oTTH4PR9JB3CKmxwJ1tgoke9IvkTegn41/QPmn" ..
	"rNhAYsnaKFSm6poBmvcKfi30SIPdba6KKKaip8m/CuEzrMboWJHe7A6jAhAijh4rDw7rjgIBsPC7lyIJDxZi6X3HOgrg+75FkFtB" ..
	"LvuD/qCklqIyTJ/ogpbR6JS+J2lrTkjvUQ5mFu1pMjErGYOJOQkCAkxF/OcoF/PIhMZB6D+UdN1UdRqBQTPSbQnC4Xp/U4IrKYQG" ..
	"5uI2MiKupYI3OSvwBSUhhJUF/pwpS9pKoybSIcgQG1uY927tuteSjdIlmG7NdS6pSfKe6Yl+1olRdSAbLp9uQkeAA/tDr+trQGvO" ..
	"id0VuIa/UMWa88Ve01Sz+QcAOomas4IKTinsVDJMbwpGpq4nN5e1OPdfNsFdIVf2U1EtvGOfDxlWWdVPBj48r8QLMHdPZbYoL7Yx" ..
	"RbkOgE5r0mOq0lSZJszXGe5tVD4oE8VQZAQdfRmogmLP6CDLYKDZqyzY1jYRl6/DLjMxC4jlPx3PEFR/z6RUkfunxTAzOrq5Fef3" ..
	"J0KJ0B1TIvTHrX5kn0Dd8ca/L+rMMQEFwIUKD5UNZlYqdrghmQtf4HIRSp+Ogb904YYYIPzWwLt4FkW6Cn76Fn6rr7MB+myaNzzH" ..
	"FgjCrvXZgNjT9CmVco3n+QoN97ECxB6gWA2qtqNVijXKMcPxXoCeBjZ53jI18pvwazPN6bh3PZdipuhi9lRY6YtdA6QGRKVJuzzh" ..
	"5Nujop+QhW5bGYCvyHAevfFiGOL11vmPUIijr6sSGrrWskn4HAX5mDZHchkE1u811kXjAqFML8OP/SoCrvewx93Klf67alYfQaXS" ..
	"RsEm5JbaucYgg5U80e/BlejLv25GbjZdMikbEP1xhbqtclHKlfXxLrfpYl6vjauhP+o9v4V8QWK+jjF4am/0J13BCWL9Inz3b2AL" ..
	"S8QgzrB1RjKXVN5lrMBYyP07vjl4QtKuEqK8zKyqFQgpYUDUpB8ohTf+PyrSJH80w1X/AIqOv1W6wnjPQ/ix83ExU3ZkMhnpCRCa" ..
	"8sFV3Xrrk0QHxdndDwDPpMmhe+K3DB40qDJRK3H6e8ZhJr+MiVtycYs4dfs5iRdQ0PXmef6nM5vZghfm3Duq8GhqMKDhqGGKYjeM" ..
	"oIT0n6fDBqeqaKfVpLBSGiUKwqwATdt45f6w8AFIYoXGIr9nd6WnJ+PmWxx1PwoFdAyEnuY667BJoGpHBVo8XWk/Jxac3k6acvbb" ..
	"xg74E+ZyAZIIQxCy9PKPRI7K6I38x/OmvTsZ5phH9w7Et4YbOeVdS10aNBOv5okLXpcplYTj61j2BCKuPOCQKELlDBq2LfKFimPk" ..
	"EF1VISE2myZ4kbkYtF+R4HU97Fi30sQ8u4nGJAlJWD6dhn1QL9e/yGRbicRRpUGPxaq5dhZu1Z7TKXvqgUM1l8GxqIQzs7zX65rO" ..
	"a81YoV3cG6jVAvm0z8wnJadFTwJyNunayfESoj+byIOwJkz+VoCaEc8YaMjL3jVaDHOYUs9Av4XWycJ/sy0qd3j+2Pcqd8wzMM/U" ..
	"yU6mSg+cr6vCTEH8ptisjLmJdrDjsUL0sD/oXw34ILwqXM1W5Rxhaimvp1H/Y2pBCQkspbFSOqU+NbptAxK76+anLRUPbXmuOxx0" ..
	"3iD1t666PcvzkzSM6q/Gbtjh3sSJa0l4hpgpHF7+b4KF4pP9aJJzn8saEcoqHHt2/1ydhdu7i+VjNXVWMNt275cU7WioTfE+BuVK" ..
	"6eSoeNzXZ15w7EXtj4ujdlGuap1Xg0UsMwte4HB2O+Y4w+l8Si3I0dADupLEDwGJl2wWQnNGq40PyGAgpJlI9jEWdNEnJeftMX4S" ..
	"xYWXyILLM5JDaMumh8LmX6Iig0T9zxCA1I4IeEwwRlOFzyCJXdsTIqKsCV2grCO24Uh7QO9I5G2JfpUBQQs0gG26Nm2Mt7aNxD62" ..
	"3hZ/iRE2/UJuPJZVlUZ3fBHNL5q0G2Gg0Vozj9HT/xu/lWk3RRcP5oYQrxJWGSeLKezQpSurELvMdyDJUyV7Z0zknvTG7zal1bD9" ..
	"NpysBGmFfzOe03d1+jsZuPIGtGMR7KdhRTjLwHN6uSdRLX6LIVpJBqJ9r11K9MduPXSxq7dm0XedHMYr1KxTUTWESJNCe5mVAqPM" ..
	"Jhf1DFaFtGz1/YW/FoGJGLXY1+/5NmBM+vDVX5NMa3CEmeLLOWiJD264SvBvW6qz/jJ0TzbVu3WDXYKfQQEGVEe1m4Kqm3qVmWCW" ..
	"ZBjn4AOC6HipUqm07Gt8+QuY/ttjCyaPmqcCfZIKNrkp42g5yzwtQK9t5cTduPdXbzZwD67sP0TB+78fsq6s/8gmQxoPFA4Kf/jC" ..
	"4NPIC/jmuEJRUDX3fa0L9m65XBRWMmMstgFJIBcAk3cTWuJOsuOpKqa+Cp7B0aqZc40j8o+aqQuoPNBj8lzJn2PXIasiWu9NLQqj" ..
	"u0jXeA+DtHYnf4bIuadUR3l8Va6tuvg5VkwnY6o9pyc6ST5F+fWLbjf97otI4gEObLc+9kKj7dHRcMUIUkhCUQoU4nktHfWCb8UQ" ..
	"C0ZmOB39RVXdahETERfqn6eugrY78cGzhyTvaz7ZWZUeXthRH/PyyqgTrAJgrw/n8M61fr+Io2BosJHRzoOW6rXM31zrFXVPDLAc" ..
	"LryMA+QFyp0Rl0DX/cg9z31+tGnlX5O6LU5XkG/50VAtKW3+gTQXWMIAzkvsbVXQcNNFHXo7W+q9/xnPucK9S38uwpmX20wwt5Xk" ..
	"7DoaqtRxeMQuGYzVqdRrbTGfJVgiiYMbt885Lk/vWo+lXCsGhDoyJVBC2jqQD/fVJWj3NInWYGzZMeR15Y5hWVDzQY5OOb3s04Cz" ..
	"5vD0bmyTP4JqcDLm0eZdrg3i2T8vKe570aEXG+xNPiPZdQya2rs7DEMNkfOUQYav19lWWQ+RQIpFmF1TKJq9fNcR39rj9pPXq1un" ..
	"AHFJxgG9fFiF03/OahqelsSPOj+QeRJUR0APJlqbjkM0qRa0JF+1nhTyDVo33yaeeL7HbIa8Ba1KdwcX8mpqdYJfZ7UZeNM7va6V" ..
	"N7n6+QmzxznZhUhUjZCrvG0OK6Ka+BlugWynnedh3c6zprJmWUkaG6foPAtWj8/ZZVJHufjVSrX9hPdDvFZ0Oae9BOhP3Isre2YM" ..
	"3zjToBcySTNz8/XYnO0hG7rjEccoozbeW7CbBVeZtWXjMI4xR/iJurPjH9Ym33Cszq0t3CRMoXZYFqUiuAPfYULXqcGRnedFsuoI" ..
	"nL/fXEsDz5tI3BirNq2+1PZQSgJPzVleJ17G7HUni6sbjxM+Dq2YSfvEaQlgmKgc3jgKJbkzAyq4dr92d+Dnwliv5rA+uClrOZj/" ..
	"9+bKkHyVvxyMn1bSS0fyzapgqQBLrVfaY5NqqnPKXUby7SiiFvdTeC1Iblc0A571pTQ8/LKf91BISqVOq76V2Vsd/yacfjhNb2hR" ..
	"OJ2hklx9njSqZyKg7UfsomJfkvEr8RoypwE6zVvBqENS/Pt8/E+kx3WzuMdU+wjdOOsBaxLcaJtBR0znTLbw5JX/XrvhP7rCGM2f" ..
	"oNljoIoyuzdqZ9bqJdnsG1Hp88oNqPF9NtKd/+Y/nkUG5W2IokDkGXwOVQkyC57cyVv/9XAAZTmx5yzwejObj9SAe/evvE5AVX5q" ..
	"DLYOCehZ+9Iwrpy0mc/GdfNrxwjNvh6uLS3kzvN3+6YLTayw8hjAJlv8B6w4bepfwWkUH9aGnDuEl65PGKjVfpPCXU8xEYEKoTo7" ..
	"FiDg2BHGPCVIaunSJOnk9XKYG1EJdX+1rojBMVPmLt5P0y1Y/96xZpE+Awsx6KbrxOrKf/uiKf8Hj/YHHYRikegBGtQxHPPYrZY/" ..
	"gzL23J8gwqYNEgeNt8iaoB67N4MI9jmb/m7CNJ48YBzkUSVXHkCIUKn9wZFaYmoYeIfEWiHugrDF7dZJdDNlnRV9fN2jETbxQaE/" ..
	"zzkW7QXvcN3HH/tJiHnb4HXfupCQ7/zDmDJYBXM+xv1xXOr6x/03c8mLsCj1pxPZubCQyy2hr1ItLy3r1BX7RVmJ7qrdni9P/VdG" ..
	"t11qLeRzyGPnH20Q1oeDXVUELtgLpZksd9cPWA54Mjzu5FK8FVZxYzo0BxsytgImYADNwfJ/hso6Lssw42Bs7eyXe6exhZwRTdjy" ..
	"HiFk00wNdA9OL8fSMJ14Qo161UUpqUCTFQtHcwopqnwErdThUrO9u77YE5KCXg6rNb9db92rvaftmSkfpg3gMC8VT8CU9GR/YjI1" ..
	"V+LtG1pZxypBmF9VjQvd1oQXl8JyBoLxy2zgVgEY2R90V/dCmwdkWFjZFhVbQoCVgHWThMTs4lnBTXOQCRI3u7b8Vk1V4qnGt4rR" ..
	"uXpYkZz5OSFQP5wr6LUXdqIUjpWJXCi0G22TY+uRpOsg+UDadPQDCmds+m7FJpZDfO06BILhIq9cWyExp9H/kzkUCGbzZ2VnuAm9" ..
	"N5bVM3y6Y63VrsL5xjTu8Pt9GqyyQOfzfOk496ZowMfnV2Wp7yFTFsQ6J5WBsojNtvcU/O7ladVJ3g2rjpFjCL2iJUhaCYkve5hb" ..
	"qQogl47jR0qrVzTVfzbz+kTWf5+PTtsXMNhrNbCi0hRWTDkfLIGEv5ZvnKtpVwyEC9+69WL/nyH0gLcuZxRBjBfob/TA7C5vigmS" ..
	"yJVRwHvBFGQ9X/+G8v/qFzqcq+jyf+90ROyo6Xmp7WJ+Re0yNSLl83cUqKs9P/ME5zZsdgixFQ691bjUSrF928mkn0cOVLLYHv+K" ..
	"Xgd8IAwlPnb399cioQokKD2NfeUe0v+6gYhiXI2Qq5f3ZTHAxufm89VgIodsehj3vmrzaTXeWcK+k7OK07BShbL7g/JfTDVKjjae" ..
	"xXB6QWZUCnu7lu6VCzcoyYN7/f1BZ3vINyHPP1bTH4T9/tu3e1W9ZTIS3KIK3sInyYiBdriTtyfFfVulz3Ax2ZOvuLEfq7279lg9" ..
	"dQF1em3L1b/2sX18LXQar6SWn89SFXYHc0piE4UpIg84/0rFHHktuLkghxFtgIzgjyElwpZHFAl0uoEgSiv/MHWmIWUFrw6aEJT6" ..
	""
local PAYLOAD_P10 =
	"K88y6InwRuSSl3RtVRD/8+yf4bZ9dmDbKSctKRI+WV9QB96/N3pfYTUeNNLODEnZty9kKFevhosMtBShCt7j10YKOYNoIk3h/5cd" ..
	"xhVabKAI+vSO9bRdu3+G0ePDLCpxtQeqiZkHpzquxUvyzMgiZCkHUv+DxKa4lWNx+kNTV1FdUXsu5Er/8U5us0y1Amn7f6mkQeco" ..
	"BHLcxUC23vMLx7aceeKWwcOx33ujnpSHzqYHmjEeotxwOx6mKTtPdGSrn3ucmZfYM0lvv41YVQE6bAjjPCC8v4xCbSfM3gRyFifS" ..
	"QaFcCHl2BTf/HmEOL5KtJGpeljL5c2HMUt1v0zUDYyqRmqHePkg29Z7/E7xShtYAOG5Pr0iWPrGrl/+DdoeMCv1nKrAJ1nnT1LA+" ..
	"cRWG4EdjkHCMrcgoHrLRmQgSP/DVrFOfOri56QOIBuegwyT6dU802q5ZKibeL3MnTsbD2DOe8YjDpoSAtcLv6uMWYgD4cIsNoBY+" ..
	"XKuz4U3FtHEDCDnHe65xHEH7Nn5sfyYkb0CRkJaMI+g3y55owczwZ4wXMESzQ8gXmLnBjFwzz5fJplROZJ4pD4aiiH6+4vRMyTrA" ..
	"P4uEEU/M5s0+qFKjFWlOVDIWJwzq+kd/4vDluffqlvs6AnsjwlLVx8z2mFFzEBzyVnSITYOewblvmw2g5ieBamTAq3TrUoYJFMmP" ..
	"X6JhkkpjQdgTEJz3vnOYi8czE2At3YIYcun1y6sz3uucsFxzN5B+E1Tv0tkh6+PF1wF2VcaZzdAUMZkYPCZhGzTJHpz3tfa+RlAB" ..
	"2eaUuLZMO3CfXuzWrzju1mTEaTg8l0KrmqBi07xwVrHxZCYqC/XavJ3dUBjxMqgYligcaJBNYJeEAbL9GB+pD5a6K7o6Xpa3wyth" ..
	"axYQcJJ999kENgdcPfdmjbNbqqT9018Hcl5U9E+7xPp/tB/o1hrBpU3TOn7CJ/adbwD5/AMxKmwiQ8z1AaHTNFnFpTXyqp+5CtMs" ..
	"tPXZViPX2svOwg3vcVX7ibB/27CyWPHyKQSdUJENR6scVAi8Q1P4iCoRI6n5DkVjO5JLFNxOCrxNfB/dvqzUxxQs+QQY4MzV2zCZ" ..
	"rW4u8EXVyV5xh98KE6X1qRk0Ixixxe/PCAvjAy/1N9DEhhUMgxQFc+Wf6p9J1LYNIu/gz86Dg9jqWMMP/eL9DFuvdlPKLtsqChUz" ..
	"4AlTbGoXp+KCd3d3H6/rQRuDi9bbAZ/9+d8Zj/FJ4bT1ymZKy8xShRx9/KEh74iZ1yxq9emyCrmJp4I9M2Opz2FgJjhyzrHlPdC5" ..
	"HRUBFUa4pl2SHgrl30dMBulG9o/XLM2CKSprqmvXprMPo4O3Ow3msOGNcN3s+Jiln/1FCHSeaMt9aHtlnaHqRnL31k2Yl9zEA2FZ" ..
	"3oiCXpZMEJfSwOfzTIHpIbgGNDSbOB5FazObMtbPIs8isugfxwh785FvgScHmckoigGmVAcJHOhDzjN9Xx6zfj7YdxRD7RkFU+J5" ..
	"Arz5jX3pR67wfmMSDbACZkgqZFErB05/ECAideaJmeRJMweahcwm5Nj8HnO5RUQtqG0ktkJY/KBsFVVhsy5HzB0t5ugRbiVvSNNO" ..
	"MWqL2Au+RpDnpWdUZGE/H1/eIC7P20x1QOnR76M8pgBOjv/vCzndAS7WBSra+9iln5AtwkoyFKkozNUyjd6auV8dto1NgUbh2LTy" ..
	"lM5Mva+lrcenXgMMPHOUVXLMjU0WLXAzoCbc53sFzSv4vX8BhysjW9u4xlYdGPPV8R1r748dMGProW1MXoWe+HsAI73DuwnMQdxy" ..
	"qqWmgFL1aM7Ce4VZ2oiqA03xl376nbPa5grr2+PHJJpz95vInLCEJo74ejgy/8TByPVR1Jb8wAvqz/RYXpobgnnXQvyXWeTsh6Uq" ..
	"Wve6dI/xO3uVW7cG9P8VnKDzCOKSlRyydjUDOAbERrfCzlPVfQL88F+isstVqLhsaE3MfHhZ6962JVnxKnb/Q7HBn3hr50yWaFdb" ..
	"nuDdgvKRIo16iahoqrUhMPDFKLkeBbUKCuxw5NsUl5MXZfOrKhOYkcgpG5w6PhO+hvpk/5wHEa9mNyaVB2ULDuycRVVSF4+eJ4rz" ..
	"DKY4PY8yH6MiV7jJY2bNOw5oQQa2T4QYyJse3XUH2alL3NOTnQV0nxXWV/cgXTlfEixQzoAvPxUjs8R9Mlh89fZ0V+ulvrGFRnX1" ..
	"XJneaqfanG0nM5bfiM9rbFISSK7J+1/7mpAwC/4VzK1/9HkF/H3iOC4xj3qDGzT2s//QTqsgWvBNo3rrqO2tiZOMtRxpnoEXyNwD" ..
	"ZLhQ1c0LUUn15Q+B2OXBQ4gZiY1WHnyydbRx4ttcwfMJeTa4v+lTOwsgr/By6LSIzjauzePoSDxwEL9UHqzgwfVG9+pkcHs7mXyN" ..
	"3Iu5D2OVo97WBG/j/NadnpZFe5M26B0Z6aeO5lQnTrYjIYXEchsnD/Hd2MDWIiyg6NTZRQmxhqM/fP+SxMj5001oc47Ma4i8Cm3g" ..
	"wlMUuiXtvRf6I5m/J0aNPxYTNrX79XvgPVBP2wVW20OZImbL0fOnvhj3N8GA1zY8U5/uRHDejjW/T5Nhvzt8UU+XzoEGHZCDmE+k" ..
	"qJS+PXevVW87yM6iLJjjYCQj5N3W3/cOD0vUCqogwRQf50HyqEKfzK6EPIgl9KQxrbwVL0kX0VpaV+qmHeeZb6cjSuBzkeSmDs/0" ..
	"fDD4kDdSd/RDGCZMO9HWLjsoVGsXlmBVQEEewRiHAe2mGLCKLUdaH65T8ELpr7MNd+CvWURADQyAITGD8KowbMIIfbN8ZNSVMySg" ..
	"O2h8XNMknb0iibzWf0grLVpUN/2qXTUMOJi7+pdEvMzP7BJ7j8GYkaTUhRX+Tekos+BTQIZcqXH/AELWjtCzqfamIrRf/gBxvVyT" ..
	"N5fQPi5FofRfOmaJOP9KLIw6hFjducGBFstA09ygytVL2rfK7WlVbYM8dOI1lvRfaDoe7WF0/yq0gidzJ2FfoyzonlTAwcaJN40G" ..
	"5zIWe9A/+TU7Q8N5NnzHqa3gQXqbQpk6GPrS3+gvUXUIv7HA8hqY9OlLq1Y4yZpn7iZDXnjQEWMTRk/cCZ/P6pwJrMPjXc6vF6Yj" ..
	"ZTh/Tdd0FXV0FDxlADLcJl5/biTtI1r7CVvxxzC3LlVxgggbBwdzMsZDU9NLFeYi2RpIdkULBCdqgBtykGDHladI9DHb7LyADiyn" ..
	"Q8zWzQrGeo+UXZlg/Fc6Tm67hS7Wc1ChBpt4cadValP4nokkXAZkgdD0rckbEjuEukA1TLB0eizDFtzrV6qD/1VukNRsQNOoJaXH" ..
	"S9AHn2CTr8LKb7BYnOZj4BKiVLxD3BV1QFG8YCmdvETaBCVcJqv2M2caZIsXYnGvJNGm2BXAYrLzlmaHXVXTRto81stadO98NU7T" ..
	"yJTkM5dfERdqsAUSEoIbe8WAmHYxE+mOIZ+EBl6xk6M2GvisPHyo7iEThVfitLN25/swPn3yOoc7ZYXNFIJx/HFihOAx/zsHGC2B" ..
	"Z2IMMAS71YQRlXLGRtigQrSw0OcGgan4RKn7AUsLLnyfE8JHgUqOlUgjgYIE1ChJt+KTZReuz7vMRRIwJsl7KMIbvS9jGU9TYBUL" ..
	"Ezs8E6f7VPeDUODCgpeVHT6dF06FjzRro6uv/m01wSp2VeCVNui8yG9XjBKvLCeQilcjr+mQ2Rx1rCbvxPkfWLBeN/jZo936myOn" ..
	"4Jrd8F80344C6VYfZQF57lalUDG7LmVX4RTTdUrfz+ByXde9pOyP2JFLFEwsk9itXUA4bIQJ1jDhXzdO+M+bCX1QFXxdhGnv2OxC" ..
	"Z0MCEDnNuPIOYWllclIpI1weKZCA1qnfw7TjI1RH97s1wJXWNxSyZUtwiuXGRXA0hQlQr6qeF8zCOzQoaMVKGyRWqVic1wX+Z//c" ..
	"+7x+XId9AFf8I8NogD2ccvOaPbYoYfHYZjDLX+0mWjsn0gpS1+y1YMycW6iUUnMVlFRw7qs8nIiArLPhCXYoiW/irXZT2wwxNdVi" ..
	"wP8d99ve9mO0tULQvZV9VZWpaaK0Xn1Xmng3F7lw08dZDR03bpVRffQEaRfUpagzKsNNBc5wFuJvl2O+5cZKztGURBiB/7weeSTQ" ..
	"3wBYAVaDuAJ6TgY01xgDfsBuyedmyLIOB6Hd92tkALrKiHwO/s86G22Z7ndAfowEtcJ6wbz8Eh7kGAS2r/5imLsK35CEqmfn4bYO" ..
	"IfNbGacclsm1CfS5R3uBe6iWIuNv12Ay4kpaiVNsH823GW//qh1y9ygDYlJnBnvIJsM270qjpdYW1HxEO5b6j5mk6JohzxSzS1bp" ..
	"tN1/rsTvophQMTvZrbjOOWgALbTOWfjtFK4+ESucvfDtWVX3CGS+4aAzABYWZT9b2Gh5d2UHuc2F9tKG6zeCun3PwWpk3qS5mA4G" ..
	"old8mhsk58zyI5uTxt6sOgyO5s0Q3JbY7hkSaT+POAeUzD6Ct1exX8sEm8ZPgD0BDCGpMIzbo8pLO6MvkITef4EDPkeHy+mONlcu" ..
	"4VzsiL1yRkTedJ47APEYGV9y/C0iPXebG5aIQSsRuqN+BcLwXfD/qDVRHGdWd2+3Bf3A93wvnY6EWOuDJIhuiJet7xXbRkvoaYSh" ..
	"svemTJ2il8/And/a5zT/2ee3+uifTHW3YYO6Fs1CnbHLakszG03eoYPI3t4H8wvFACAfN2NVr4PL8PoxkPs18yl6D3M9QQ6ewuTS" ..
	"hp8jOd0gOW5oyGb3ARzZktvgvOe7ku9dW+xuxtEXTsVBAiU/3SrWkvwr7s+qtV7UBLDPpT8GElv0TVWkDLA7jcFLk91z+cFDmPji" ..
	"8N3ud4l622tlrc57LEafn5V79gHT+nGZBB6j0PZwTh22s77slzjRQv6vITwJ+dP3DTwAqMGWLws1aVlgCAith8RhKVs0/TC1eEiR" ..
	"/kgLbdeGtToDZu1nLW2upWGvzZV1Av3I+T7khhmw8PMpZOGgX2nk79T2JRFqKkSfVI1McvXJ53a+afqS9mS+yEW8vlT7n+WdXQrE" ..
	"1YafpkH25UmCb+5QpdAa0WeIrcIFTxugQecO9WByYo8MczsFAe1kdVMkbPL8XZFbjqXNGDiJQTJ5j8LbSrCqPp41mEPjwgBi1hz7" ..
	"F6uQJ8tMll75MgthsKCrHC2M9XcLYxtqlnOCrUlJ0TvY62NVGrbGN4uO83LZs8Fi6dj0YtwMK+sczedjO9T/t4Sf5KZBK0BGkcxX" ..
	"pchudbkiPCBmVdEemhPvK58l0Kqeob5cf4z/8UGSJEU4ao9jLcQR/DaBvhFrNhGr2JMeSVziROLAH40clZM87VOKNEyX3SsIKZZX" ..
	"bmjYEdeCoyyuVoAK2IXaBnoPtylKQJntn2ksNZh9UmjoK+jIwAJre0wxvq8f9rY6d/G2jN/GRcrCGgYeAJnzWK4Q58TwHWqtHZBG" ..
	"CgKvG6i2u2D/3ppq5ueyooeD1uNj2rWbJXF+XAP6Nj33wmSs7yE6d9WX8Zvye3R56lG5uiGCKTRe6kxympXk7/GKhhO6nXkVhuaK" ..
	"E1mro3RTydaw3AKW0rNrCh1DAyaSnLjhAh6nTclAGg0C3+dp6R+yAI6plocy66FOLP2sbO+CNaBOrcURZpcoWfpJXZsZdm9mvIeF" ..
	"3dREXDM8+dlzXJliVUShgaCEXcfansRhDQOdotlpDD8nhmo1TOBS+GdBtSw5zByxZohZ9G8Ck3ZopK3EdwnGM9terT+b3xw8p2at" ..
	"nDD2C9YPHw9wVPgT7iAqFLYdYmym7dfXQdXMYMzpu+mWk2TCbuV/Gn204EEsQXQ+FQArfzmBLQVp/gbJwDP3ZNfHp/ToN41KhV3P" ..
	"e/ASyYkZixbgRngQ7JgVFNA3CV03eyLAjK08cCeMMTW7WusL2sWHekvaKPaM4zjc4wa43J2ib1dpoD9fe9ucfDUYPvFl41lkeqnp" ..
	"9bjS5svuJML+9MkBdXY6iPXBe8Kp94ugJrB9OREhsfXv+5m06lLKjZZfRgf4uMUm3yFFUwqSntEMenR4RNRc3HvJeZKd01Kgql66" ..
	""
local PAYLOAD_P11 =
	"d8gQMMK+7szGnD7xY3CKKj3x/HdQvs8/RECsKdpVWF0U3YiWbq2/4UtB8m4RJq0or25nMVq01ts2cptZCEBb4p5XnCIV6nigEA7m" ..
	"qilg/cmzGP7+SIlhhdoogFqn764wDsE1IRLM/jPWJ7q9SGyXFRlu1nG4q921Ujo10YaYQvvYDhe5wwDED9+C4npxmDbGS3RpWE9y" ..
	"g+1hJ256DSOl3kil00KINI5bgXLIRKo7WoUBhbzs4I6IhJ7JkMkJguoZ7gtncZbpSSZ1O+uId6EMybAPLQQxx+cR/1maHjcin66X" ..
	"ii6USZIQPn1y1t53R2iMh9/fdvBjnEuerN0Ff0mlU5zpsQyll8z/Bau9maO8C4Vy2zH15Wu15nLa6ay5h0znw7SnMthtUKRv+eHC" ..
	"zLFuIVfvl60lsxLDtRZB6H6K8aN0J064NlDZ2DnjguvA8WDB1rApkIpDsdD8I0L0AhEwAhqEhUZSLINmPrqnioBYH3RUY2grEw0X" ..
	"ZdYMuIGXzOpSan54jHWa9lV4hTjVnLDqLM4UkMYs/Hcx9FbuTn1xIQdXEwN480jr8TNC8240DoiuYL+aG9q2hHwd/IguMZSEdcSR" ..
	"M8t7gEKUZuFkk9thEo4RhSoi1fSlIztsnmA0HqjSHn7b22vEy3OKfXpDlUNF7Be7h3HB0CET5T/UK3M283JcE7vIw3fv5pL/Ywmc" ..
	"NqTVGXkIy1V5B1Y776D3pINZnsikrZDDBjn+kXxhHuGZZNAMOXtLCOTzaWTI6i8gEICVsbp+Pdyn3WkRgtTCyjGhVqxX/JILMPPt" ..
	"uXxI0acjMgF5Kopp0Pi3rfkqCSSj+gSj5tO1FsukW86MoXwR5xlPpUpcpIHVmkaM97Xj6Sd8RDiexQnspprMM9b4enHrL7qqg7Di" ..
	"ncvtELLidm8zgC+lDT6Nl9E1WfVZk6GxEpi5wMaJoNEKZvo3aVQIix5HA7o09ljLKhE5lmQM/dMMGBGM2auJ5htA5CVUQpzNnEcx" ..
	"+Uk9+C9Dfa8z2Lkp3jdq9Bd8yNng8HJYZ6Pl3I/dj8amqYM1nEzgCto8WXAWZuA4OQI+PXFWfU3miCppypFimOvgTLCLn9a2xvuA" ..
	"uDAI2DkGBTxx9sK+IdrQWpujzUHBNhCLZddjt7TqhjCqRO116zEQaDClATTBynJSY8j8FekfmtGg3DlSaXG2vpJwmID3j+uo/f4j" ..
	"Jal1+zYyZB9MLrAdLtkcZwY5Qz+B3IBHaAt5Nnu7Yb/2gRDKWEmH7MV4L7tDrdzQW9TOaRCn/fuWGz7CoUQQMq+p/1495Oc1S5cv" ..
	"Kpd0OweAKRVzbnxlhmLfhHR1apTKTXQ8kprvW7snz5/r+U2MnbQ3Zn2YAuReKY7o7RN5F58xPhe7M+0HfoJh4Ilz8n1MZRLxiJMn" ..
	"QGGSO9rdYpHp/OVPLXD3SycNbhWqvPVcJ9r2GMd0+TcZkcVywEcJfwknevIG2OyyaO9jmeDnHqhis7zlz1AY1j3frlFIxdBu4o+A" ..
	"nYrblCq58B13qn72B/XbiQzxHVpTseq4XpwWWte4QYeWcQ90qTbCtbngH5JqtjOjHjVMOPpmXrWadTlFa1tvJtbFPk4jTsrINH7T" ..
	"9nDXBFOslsSv46blqNRljzqur1oGspQhukeTUgcCB3qqI1CXY+Vjdy3eERXRyVGq8uyH1Vqe9AIvMJ/A1hTuE4Mz1MvyN/etw5uI" ..
	"talqRPQFhInp0VU20eFVcwA77zTSR3L2A3DUWRYDOeGlD8eHT4OV98sOkmz4OWnDHXE0qGfN3ZJ3Al/LbjlnLJ9FIauTX1ZoPbLp" ..
	"hH5ngNH7LVVDRHi+kbjwNJ/wnPNVSxR2oTw3sj76R3KSyQTo9ZX4YWAB4zUKrrk4iT++pDK+hrvfrQTR/DvrRAaRnR8A1QICW2Jj" ..
	"gdhN68Xh1vRLeI9xbsS1bzQkhj2ZrrXGs2G85FYXOLhrghLZNbSbhayfYbYyw0FR2UNp/CHgwE2NlmKePhRFOnBBFrc6JOMMYMH/" ..
	"CmRz1qR8bjHrt3K5onXSTLPJQGfWPK59mPBZXgNRqTx3n2naRDplQPTkBeqj1EViOhKFxkpKN0rCwGh4LyS9efKmwbnWeqeHQm0H" ..
	"NphCaKAO6QX2DpdP4lcJaQCx9ZpgKJG48mNpkodZmF4n9YVft27gKixlDt+nlWDKytkYFQBiRS/7cwDsvTjJ0fSOSJPbX+nky68Q" ..
	"JlyYwPJNEUNqrktqO8bPkbA7FtikLAJYLBeu8gjuBoOkQGO3s24zXwWy6NqN2S6KDZtjQ+79/iKHiBrMrRzjbgzryRC/lrjGpAVl" ..
	"KJTKPuOW9L+ID6peV4o3SPLJNEzKZ5g32SGNc99Y1lC5IVhL5+U5551X8DWVqIpdhe/O2OirzJkCChV2heejq9hwZsAkQzB7ztea" ..
	"t+CiCuTFmdOU0Cf/fwJ7MmKnTnk41oyG6vVR5QJEERL7f/Z7D3slBXpyhWauCLl5kj+DJPfqU2UkZrHk59ndPcbfIY58KxM2fu9S" ..
	"3Mu9sseb3SsxJqZyqHS4+Fg09QuZzM1z/Hi4M4s4M4HrlFVWEiCEocuPQOJjwopLr17E6pTnCXhu24hq/5tsJvom145AdpjEKrz7" ..
	"hpiCg7IstO5tZG2nl/wd+WRgiEo+wd2aNDBnJ9tLnYeEPZdSWPfh1++Qzdln6tPs/AjGXnGmi1P3ca8EmA4264vwS7h/boxSsRH/" ..
	"zQ5jCD3bm3gHHrVagfRksqfisBs0P34uhkxtdE+JWkfET35gMmhF2BEUW+kgOiwf7g0luxq7Fu2sXC6xHLeoYsQOyNhBcXn9kukI" ..
	"Ra7CtdpocsNCPIqgRxR3TjEqYnI5BIp6MQNhtA3m6Sp3PchGw3H676+bUon4HTZ/UrN5+g2oAE5Uw1Z+ktUtjMKBTGdMvRZC87yt" ..
	"iwbunxcTE+tSChDBnYD3J6ogKxBuCksSo62iLN0W5UR1FOLPh/QugCRYko2BcHSu4N/jS8XQSklTcb3LH5YK/qrJM2ZZTnPbD/ux" ..
	"5cdys7eaUZ87kLu/OX9t+HyI6obTlZ6sEGiU13Wum3wstagHsLIitWUMi2WcPcPpIEYiZnttgajnvD6LnxuMAz7lpiE8YT89dywW" ..
	"7ktPwIm7PK0t+lyRVntaj+dqk1w0EH7LqwfqNFbk9OgoY4eOPdYRaIMCkq+axNp1J2UB1FBuovY/P7FNKaRjDSzjVnq+9N2tJc2/" ..
	"mGw1OqhP5P0HfsvkmkHML76xP8WzWKadEtbGWig2pAV0Daf6QlMP2hrdlX/ZMZjUYMcWFEb5Mh5U7NKf5sfJVqLseSaaBM2L1VGn" ..
	"OWHnMt5gPxIMA9KizbdHKiWnQ5JskQFDIhOnUE7V7Dj8GONt/58T0fatLVS8WaNUJ6whVV9mqEgzAfY5DHVIDIW85tO3cUjD6SZL" ..
	"Uf2b0d6CZ4Op2AIMhnpFUpWQH3L7S6gk4IBqxuHb4djQvjWWYNSrltc7Hm/736xJQBwJqvQiN0DgrC7DNbXaz4YyyxZOYBPk1HeG" ..
	"DXH1N9Ey5juN7qstQaT/Pxart3E3NgM8Az9AmAqGWDO0WuOMMYEEUoIm2LZAXOUG5bnZOmB3WR1d+awOxYQWQWC4mglWv9gLBL8N" ..
	"rsvB5q7u8EmBahYklMF+iht0CvOI+eaebhDEDGzia9rEHt7cezI3F0Qn5wxNC3kP1tz/Gi/bJooe/OhVHGogXVX21JJ484pQC0TQ" ..
	"3DQM6kkrKh3zlAlaUubnDC6eSCFnUZ/WYZC5bJQyMk1g3PTLVSCUbvUgob+0KQFXLx9+DpEFn60fz4bJxx1mTc5W80CRkaXMFjo0" ..
	"r4euwGzUQYjOH4TEILu4pNWMbpgna/NWIgoAW9Gz7ArjfUKL0T/aLHIsZHrqHk5xNhG8yNFm4XecxkyJbomr8f5hq19PpUN5PpyC" ..
	"KYHmr7MdPOk3kC/UVk2pUu0r98YKDpKjpqKVwh69MbYiLEd5xBWaurvOzengA2Xdqcd5cTejPx2QoEPt3eofRbL4kLPDhamgTTmP" ..
	"QBXGNpqEpbFJQpa8+nS4fbpLrd69eDgZaQFGHtkJMPWKOp2EAIL0i29LvI40se3q5DdmeglUGYGPnzLysA1Nq28oMNrjBwa8+//Q" ..
	"fShe6XnsMfDXIf+aCUVBXT8/ccYI5Kbc9Cz6+k3+r3JeqFqLJuycNj4ILi1mrxQp3/8xXvzTFQy62vc9HtsQgVAAeYJwtm4/EaOQ" ..
	"PloqCi2LtuQ4TncFG9Le45K/WhyCwrE1mUodANGZoBVNh1HlXwP1knhBGuy1n5cevSsWoxfyRdjdRBkTQa0LTPVeALCN5p+Hih70" ..
	"uxfv1BUweqVB0qt5HU+Rh3s2ewEzQ8jdudRHCn2K3acE7+ZmU14/CSd4mt4wLeEI0zzvYUPE1T2mBPyneras7zp5PXEGcQ1iT49N" ..
	"LEao8ocsAI/wkOuuFzK8UDPp+W7WBIT1oYPhaom6PnpDwcDTb46iMRwF78UnUJO38pHfjCa7vw7LmYMwSJj4eJc2h0DSA3wmCxuO" ..
	"zWSQMVVT/X9Q1wYrO8SJSNDcxRSJwB8899ZAGpLWAZJxeeBJiwvddfLzAB1PMUScn4hvaUmhwCrdNdZ20uJHPvR4DvRX68ktCSgp" ..
	"5x/KQ1gmK5bLwfUNlQ5GoPA9kZ2VESLjquU5WkgUO9YE9RZrlCKhUtKxK5QZvHvTisht1gcniKjyhtziWTPhmkOE1L40DUzv/YrX" ..
	"FcFAgmEZZP55P9IoiqFJSmH6aSETb+oW8+PxHndSOVJ3GXm27EUvN7IxTxzC4ssy+sF8UvWRrHNdIguZZ2yPNz2p7Wqiuawv0yyM" ..
	"LKBTAQoOG7Ux2sHTquEFSIvlySNyJn1Ko/H2lr4rCtz/2pqimEfFEJAZ34TZs0IvyU4ok8I5S3fBCfSyPfbaMWyhK2yC1z6ORZDS" ..
	"xDjjko3gxDuKTlcw7xaWaNNvVg1DynbMmXUdFuTjV+1+QJnsGkeGEt8p7qhjs4rid6KELdD0xE2miiRvGAVuhORa1KqCM3CDtsxN" ..
	"fxv6LfozD33ERRMc01YjR12nGNx6XPp1iVZyPJrk8Kd6Bro0Nek994YRUttPUGEtwDnWGtu8i2UAjl6SzlQXR6Rn+S0g+VHj0Zs4" ..
	"2W+ZE6+l6O0VB6aBnAtbdpQD8ilCYF1EBuFdGUc3bJgDhN9dmy9HQkOlTw9xzYX2IbfuaSgQzSvDLKsIXcLpKWtGJEZWTwI2i/ep" ..
	"oAC6fWgkr5N3kaeh1+7adQK54+QQCk1CfVIhrF4CCozqLTBTDPGltdWjdnu4iYvIZsMvqLPSrjr2EPk9wMIpEKZZOOaf6/bBzwp2" ..
	"XNiyfI5hx4a2EB9odIhRrEyBmXdpDi/7xPQUtK2TflATU2QHbL0HZ4rkpwHQ9fKXFZMkcTsirajnWS362aBn9lvlbA3HxIC6Csc4" ..
	"VPwdQq21DqNY+IGtAAXzp6JxcFPRUEYRMcmeYvVWvDcxc5Yl8RkEmkGLkSJ+3W0b86lE4J733TKVzafFfAXU9v+64gsPUoA1XJhB" ..
	"lI/guyAbcG9gGpmELKVxK7ZFZuJuCUFVscKzgnu6o+kB0Ez2n8JNdauEchke5VxauYnVsMHJF6cxNfMa46FdQueFDvYVNz/nv/pm" ..
	"1UgINsMSqC892+xCkzUYZtOPqXzHrbFuVucvD46Ydqnj81jvw06YLruaJVywtCv3DpUPoTDY3Eq3gp2eFJMZg4lH2ne4cvJZnXsb" ..
	"bUZJarGPcrGh/Ahp0VpDcNy4nsQxUKHMSCWe9ZHfpVsm/ld6grhXNVN6Ro2+fUdDEOLjtJfuiKoVBd09MOVy2IF/4bh2hemA8BOm" ..
	"8IDD59mp41N+xj78hWfQlWC93wUtNCBVKtAb9LS015Tm9+ni/kKh9kSWUw0w33lgrYMy1Cyq6zgZ1j1JhfX4mjwGJqxA6uSp1ku3" ..
	"HDVybUvEuw++buugtUaQb06TpsskcDud0gXkfl6AUvf1mOib64u6JjekzwOgy0ilXg8uJ7GK90OO0Iai+Jw5Gi9RNP6qG5sQJJNj" ..
	""
local PAYLOAD_P12 =
	"5/8QEGRAf+NEXUmAubHV3HkSc8TC53Kpjk4+JgVmdg4JbfaJ8UUxKQ64Y218xJRF6RzDlgx8AWrOnlaBQkv4ox3mgHNHMtnJ56+h" ..
	"ke7NRhINqyScpLRqSnqslAmTD3cZa1TK5aWodm3P0nxc5Gt0Soloy7b0vIEOnYZbfB5c7nP0BYY5BYZl3RieUvQ5vqyQeGUoYK2x" ..
	"MzO7C3DQmbAjMIPIiatIugZTegC0Ysb/NZcxtnL2yh7Nt4Db2Nfo6Z49OKnmnX9Dg9LDWVcIw9chao3ijoxmIzeRph/RY25aQCoH" ..
	"0RAIwBX6hwdDv1gloF357LETxahnmKQpsrc1jz6dlopSBjTJElehGsaTLh2+tEtpQ/rEcubhYZs/7oBv5s3SypgpY/H+Ws3RKopU" ..
	"kiGsg3fGJg4u3rB7/YlHj517NR4nt8e8gO5Xhs4dRKCZa1zZpPSj8g78C/+O+hMz3WZxv3edustLj6WOjSP17UpV6hOvzFiQy+XQ" ..
	"Nj6lfyNa/SNnX5LcMZ991MTGpESsO1yQxqYELr2YAbxxTHtMAD5hunmlvC8wyRyTolMiI0Bejq2wMpH5HZU5gyKIzBeHWlPXha3R" ..
	"Y99xRGvTn+tAFsAgtlaZWqJ3Fbb9JtN8VbFyYBuUhHHz7rX6iJFA6Yvw61pH+Q7uPlbF9OvoSv2dFKAgRYfIC6kRvd1IafwQmCAu" ..
	"9M6RBy/c2Dg+niRzitX8Shh5BPEEsTGzQAUC8W9hsGo0ji0kDx2s2r0dweDP/oLOHRs6qNjgFnUslQeq+Mt43FqO6M/q+9sJZHmQ" ..
	"V3PtTdWzIA9kbmaZGUSp7L6jz3B6YIe/ct0IrqNu+w8BF08es05CwfAM092dFqr0uat78zI/z7nY9pfS5msOngMwy8H4GZc7xwBe" ..
	"RyBVdN38Xrnw2ISUykt+JRMdjK8xXYVhcmYzge8NvnLD4xFE+zE/YCHS91d2vMg/QSS+Kt+QwZfN+hqOBm0JejkhNKPoS31huJIQ" ..
	"BvviexAsmIPiNhMxU1M8vfduLm2TcEbfgSAC++59ddHrtu+GDOcU/wXJoC4wBgFyETLP8gecd7vXOOh4NzTra5VOV2t8iBwHfzcQ" ..
	"mcf5BWh+cRorAzlyjaD3piP+dP5EoTYnrHIxn+kBjSRdHn8+Hov6txfQ4NIn80UxA9CqwC/Nbs1cTaAPCzBxsSC9tZwzgRM/gkr5" ..
	"YebI6BL721jxnQdLqErjIHubieylDY6ys+4SfDSQWl28+9fGX2pKr7T5c7vr2nFTuZwPWso899iph5ji00GBhFihaQH6o7vSN/75" ..
	"NGDv3VRwgPD3Xp5KgF9uLbMLQ/WmhFlQ64odBnYEx5hxZSbn2VEz2AsgwWgMh8iJTIQKb69oWo73HQKI8RR9kmgohrGBRt248cCo" ..
	"NwqLkLYD0wpcyyDC5GqlLZL1241MCs1/IF6HdyLT2WVjJnIlLPjnmavtTKOE3Hs2aCtsrsqBZsC6xBLRhhzirL0adERy1Fbv0WiT" ..
	"wm688C1kKNQ9VWy6CjAI1z9T1lhDvwiAbVSElUyD0kJoIwNhwMDWZi/vviVDEkHSsJLKquDSA2F98apQxwK+PQOPnMs9pCCDHGJ2" ..
	"aqq+k3ffveeLb1HhDOZuv+S4PED4MVruDpRJaV5TshhDkYB9x/31H3Gwg643VnH5414NEPaY+AIZIJ0yXXZcv/+Sdnsu4flsGsD/" ..
	"vKNiB3SEkCOuyhRV+wIR5Ziu11BfD9ow1+1CKSwYZHM1mxMZRT+wSjVA+kmKJoj8Yiwj0KY4C4q3KeD7xw+VzNa9sClzLDEQv43/" ..
	"TbkuSnFsqSHso4vifVfgwM5KF2WSJiznX/GgePVIwInWxI2UpCpWADYiEFrJW4vREuVO41uC1YWHzGieg4oqUADmX7qbT8M6UyFv" ..
	"PYX3CvjbkWRT6r30SaqdKtm7s0I17GyGtlVXEFAs5WBRpERYuOpoBKGCEsEV3PDQxBX5EYWCkrdlXH+IOvtek1Tw+AZsW+eHMXNI" ..
	"XTMDkPLhNr1S3wK59tdrF40YfUqmq57W8CafRqkevwi+6GMVRb9WPzN4ZGUYEsPy4VsSnqN9w9zX6QlXhotIm8F22G3QVbG1dKT5" ..
	"fK5WOkwIJcfOUbGqvEts2VfVa4r8Xnujdf1y4ssGF/tiKwRMFKMaaH9aYQDvc1L05X5gHgmqoe7NsQNNDd+ItjVIS7u4zjjqQPAM" ..
	"Uuz5KJFV+5lyhSZ8jz39outJA0tpkju46MLIkaCbNirN8kvemcaiOdUaWP7ALtc5YZ1pmzVDqx+rsI6Tj7hMwoW345bVSFJCuu3F" ..
	"UpFifuGZlEO3ByOXDedfiR4kWE3jxDQ9B/4LDk8xSpQadgRra2Kf+ynYT19RSHM7XwIqhRAFg3O06LKQF5koKfSWGdlagpQbn93t" ..
	"U6LuT5b+jY5mlRv0LNHzGX9nUU728ITrJl6Xbtx+Nr66nh+Rj5vwCKJyHk/oFQ3FIx0vGh3OBxCPs3xZlQKYnFGiGF0CpFsVlGDw" ..
	"IdYln/ysU6DOEliJB/9iaSok2WHXJKVhKbyJupwCLEBTrTVClTs053t2+aBysIYCbWLuo4sMWznqLhxn3p+PxW9zpqtG1AUVobSD" ..
	"dzNPwuyND1/Ny7ho4zC2vPzp4SChUDDlysm5zQRF7QgwqPhgT75uhL4nB7JLYdiHAOxENSdZTQWJE5kuSD4IY6GLKSnansu2AcLy" ..
	"Q/g/5ti8Zdqjg9bEXa9OOGyDKKsoyhvGnd0NdC+hZB0sl3gqdWQfso1mixnjr7BiDyyVjacy5NM5yAqOzFObUQb9uZ6qZK9AjItL" ..
	"a897puaSxF5FYJfthoW1aAAxoRcyZam0fRm39ueWmxCOIuugBh7jtunJ2jL8vuP/HDE62GI6YSOxyNjAS3U1FTZFwTO/iu13l+mT" ..
	"Pat4FWwdyrqJLUO7E+fqROZwN9+irDXmZaugzw6BpvT/KdCozuzKzJryplyHlkWSbs/Nc2FlsIu1HiW2ZqE/FSSGygrcahGcaa4w" ..
	"Cs3+fRxeGj46MjpwLkB7/B9DXD7ShXyhPWXsCdj7RvqiGzf3S9PFrCfeylmA2o/kjpOmdl4AEXFaFVied8eL9M+CM7yBNXETZCs9" ..
	"i0EpBeN6pT8uMEON4NZhNDqu10lclspG2D58h4v1z5Kvgn0DCZy2YtZxOOSpUuYDiaSGzFbZddczmuHzJy9UXeaqhbm1iM25wGVG" ..
	"+OPYIzrhwcT5wNP8gXOirjQawnkE6xFdISYwyeTQLXOpRyND2/HKN4ltFTQ07162WhE8qE3rdb06d20vI9YxRoqkPBGDoH1Wzbxp" ..
	"ShJmNG3oHgmiJB13TGKQiRRFS8d4+deBrIFhW8WR72gsYZILLouy4+FQPwCfpJUdn3xjS3aWonR38HURRZmT7sgF7JkgchVNlBTI" ..
	"qmNyc3+UH0/qZ9PCrfFhUXxqC5dMzdhWgkm6xiHG/9axfr4iBVGnAuPj0V5kM3MZdKlRelX5iSa1cSKPp8NaoOLPtcQQXQjBOYJX" ..
	"3WuE+dmBjC8vxNNRM3RF7M4hj4d94GRzmiIF9Wb5SyvSciCKDaCOaBM3fgG2+thyzx7Liltok+A2x+PWH4u/QexuRuI02ngSl1VW" ..
	"zqoo8lsam/Z9nXZe5Kydi/JBkz0K0nnHuBkEvwhRJSfGbcvd/P2ldqZPkdKJa53eq9MFlYeH5mO+VNepP1RfuwPj0eE6VHgXaTYc" ..
	"nA0eOnVw8GHsW6ntyr/BzFOyxFDu2z7CMQGQvG/GxSF162F7mNpWdLCNGX1TdskEbqSURD1HY9S9fxfBgB9qog5+q7gHMqemRmYV" ..
	"6dxlDZqDbHEKIAJiIZGmLWmkISUsWMP2imX57OJw1Vitc9gG3kNwHeN3fKA0w8L0YxZ6Xq59tiMI+PbPL7RAGSfL9XdXYrC+pg6j" ..
	"hwGLgV0D+lEAgIWgrjUgtcdZ68+Wn3UQ8MFKOHYkgJAjyQSgQJuZTNWToOx+FB1S0jYBADD+BwS3/ysRfCdSCfIJHglJXw9+BCYp" ..
	"zzfB+Mse5jvpSfmpZMRSkOLGMCUZBV25aZQ/6YRB5XpvmEjK0u+J4lG/TYSg3RbzmRvFoMTTNmU6v2BaN43dAdMkqgx42mLiStSG" ..
	"NBKYVHue+G20Df5Tquit7RsqjGKMndda8aY+nsbgt7Y0YelChkJBw7aDDAK69F/9FbS8dwTgrnU56YZxzI5qt73j5h8ursf0iVAh" ..
	"/wzYOiktmA1y23aNA9jdxUxwa5AQNxVtOGWPj3qtxL5oT76Qc0wsm1gJ/uKVecWxckaHs7XFdQzA7EvJtNRh6yXpmX4OcehK2XMT" ..
	"QdsPqRN5+KfL/SaVSiAQpkM+Zxe1UqpbwN6FUwrecF1ztRHorgsD2OLA0YXDIUgd+8bN2alxtW76XCxdQv6WN5FvnQ1wl9FzGudx" ..
	"KO/eLOiG4ZJlQef2DmirkoV3vb7x9rKPPYNezt5A1TWdADSaJhGLw2hd3wrrKWTqriA1nUiPf/23BzDIW7BpbpsjTo2epKXj66Rg" ..
	"SPyZMrghC0Yp+i3ENhcsl3TQr7BhwQuk/4JB2KeQJM5N0yEFwdYtgRJR9XIv+PhTr7amqJODXADMIiWlxLy5iiAth4mZ3VCPtgiO" ..
	"XSb56KLxG//+khmBebeThth4NW6b6nZBmDZeWy0frP7c7UmAAZNp/CBCBKna61OIXUxq1EBaBWvBhHQNEws7PrsGGrpQ2jpE3mLn" ..
	"lkvtL1LEzU9n3eBAmQyKwIc2E+wSSxPGwddlIH4zMZxxHX9unUQ7vZV/SkohU/rTFfO5nybCNFg8xJ3j0HwKGWmeZcrENZkN64Qn" ..
	"L/tiRsswoxWq87tFHVfYO1OanOwuxKKNGhbcA5HMnqDWWCEXm6tPJBGlap72ZVPkl6NqXV9Crdse8TCGdxUmHUb9wdgTgc8t7hXs" ..
	"1PkJTB32foMRiOaB3NpoD+zQGuOnCagFamkJsEmjePrs4C+/SdWJrEuoHkIFmCEbAxaPt6LH06SnkzEMUXszUpmrlylntAgqzyju" ..
	"4TdA2MWRcI1DWr/NGDwzgJ7uk4es1KFRuEatPFGFl9mPqZX19ZmLWgUdhAgR4P8jldVsXvNxgtpZ85AB0hr+3vndTKQjzJBzmlVr" ..
	"NJyTKFJ5AvR6dg2FANTzSej9MhKOweoj+tBvhzjoGqcMeuOf1yeDSGbYBlcFmkUJznPQOVxSS4tqf4SV375kcYQiwDdNWVPiuIMv" ..
	"KunbqpBhYHZkQRZ8PGNscwOFKCXOWkcSa+fIDsOal3NsGcHVcdiYzqsoXPKB5ONlv1hJloag2mQDTpZF8px+oeUEc4lTze+jCffz" ..
	"/QZ7wXuwU86DPRkekarkAURYtH1GJN9yoE2yQT0yh1X+n3yQT8O47QsAEJtZ/HXe+LI1UeNOAEuJ/09fI0hQmtnsV36h98L8agM4" ..
	"X45gOp4eP+ZCfOMuBL1u9XwuaZaD5f36fBPccSH8jK0jVa4en87ok33529fEf5BpUuxjGnyiM1Crw92YYFGDWa3cUa2VWeUEu4/d" ..
	"O4AoLrrwBqax8LEoLvYqvXzgX5DSdD2k2WwytqithdvZFsHvTcTYzHplLI+VTBaw4myIa5iLuIAq1eAXURx5rmbLxpHu+Bl6dgX/" ..
	"8wQlCC/Syfiu3XBPS42okypCv7vCLG9CiV+5HhZK8hJv3qQ5ViPJWO9Zi5EDh3CKzJYpx7duykm/vYyqpd0uLojwOkly3ZxFU0Zw" ..
	"UcXo+d74uXl2hjnVqJsyEoTYzIkZFoL7ej0I2kOV52aGtpPrJZNoQdxCkZuGCkQEpG5AmauRoHKS1JTNgcg0nje6XDNxCv1Rs9/f" ..
	"q4dYyCyho2ltP3WGzPmIaqgE/7mVECkGBfRZDJx+YWIz3TUscDpfccBcIELcVX6yp2ogyFX/fBFB54QK9NkKgL31YkDS47nG334f" ..
	"Mpffkx5pWEjbL7M5W8SMCf0fTphm9FXK3n+wJB5vluTInh0oOa0MyydLIAlaApLu2MDTUcOG++MJvhtkifsHocIAXWeSD79UpLHS" ..
	""
local PAYLOAD_P13 =
	"y8MNoNixOUT76XAIxIuBvK811dM7j8Ad1nFtrO6gA363hNqW2+yy/X7XWoGERtSemQJSFefPgtmznrocrRb5aMGokXBT179vF97E" ..
	"xC1fvdelHK0NMrkknuWeZGlyOD1xrxeV72twBlawtSfAtjmdSS0edbMUUqJxNyHFt+ktWf5KLOYkDYCmN2R2aTRbPjiJMbvkkxNz" ..
	"RkLhD1BYzQMM/reg382l95wHDC4xQEwgQu5COhbvPddr0eIfoad9mai41AQmKKaktH5ip1vw8ZItywGjelL8Eedf3gqWRvdHJe8F" ..
	"iw0vdWMOpy/47GRElny2//Oyx2HMCxFzEnt8a2GDdDt5ChOJyExslWwBAJ7IH25Kj4IiXQb0meOX+JbVoSzoK25eDr97L/+X/QVo" ..
	"N+hZxiqwqYivg4kqOe2L9n0qgZyZzSsC2/lrlR9cwZsBdF0roTTvZR5s5De117rzMYvfNW1Py7AuKy3R5lDG4u8+4Y4Si7hyHinf" ..
	"qykF4Z04Fz9SeKo6BRW3/lCPkUHS7eigK7uEqHnjB/jFcuii9UXE9y49rK2m3HWmWqyt4PKSd5kqGLowfXdOM3+LrMzR374uxQQJ" ..
	"R4RW4y79fUDy3cO13fhi+9QCkGMIrTNVj2cXbDLlh/hBIBYVgdpLKVlbJClywmsUn7cXNl7+rxOuNMzKFfKawza5ZEmQXEWC7eEs" ..
	"lp4f4UhAIqB2oNbdrKk/LgZ/ia6FrChLKC0I5CrhHX458zBzucZsNG0yP9k2IOsrs2u4d9+ojpEHEU3vHZDC12gtC5OEbHVq1/bK" ..
	"u0xaYNMgOUgPtGODEmZs5YzFa4mG2AwLW5YTaHuMdan/yiYCXCZcqK2Gt4axPaebD+vu34reX6gEUflAjMUNisxH1u/wKX8IsuHl" ..
	"RM6NwYQ5SiTi81oSml2NmZ4JuskmXCyt4nFc/w+J6iGu4fUU6n7V98tHWLOBewRQt5MgtJcuef61gDi7FSPqqsvHV+60MvTKtxyS" ..
	"/0BbBnC75SSPrzBVW64vWJVenD9kwTcXYgRgcBlPzQu234fHo/8i9YvKV2e72Hiv0OK3HjP2sOdajr/NGkH/BAnW9BLhorcrvMR2" ..
	"XNNB4zhwwiKhWLyzMoDZvUlCOaLFAnsHfVmrFM51f/LU/SM1sZYMs2qwOUwCcwtjMoqpZoTcW/7GOKXFzFc97nXLRLq3zA8lwMJd" ..
	"7C94JL2pqPmtTw3y5Ve+RANaLnPD+mmRYj85lIe5fBrHkM9SiME+MwAek5QU3WAMeqfz2HAuiwx+HILKyS3SoS7Bg5YZtUGqmLwT" ..
	"XmXFokavBhnpklDKzt9CazpysZALEWrLYuTNpqfh+omZDKv77EPzjZUw6WBEbapjMBC2TqFKegAZs/B0NvoszfBrlsZwYXWT0rNF" ..
	"NIvVsmJPw0dpdkkyr0BDC1N4uVugW4ci6yhveE2PtmaVd8FKgcg0Hys2032uCloUin2d4FfDKs4nhlFGRRIESFyCjVO8BnT1GSky" ..
	"7larrmPhxSg8BouFGnYt8Zpze5RY+8kH4RQQy5vYp8m6BRAipMLUB2EGuixBr3/oRbNY6usrLKnchYfUPE1gbxk7dWaSqCjQzMG0" ..
	"BDq0bZiBkoczOl813On76vFDe6caf68ioNTPNdhJFjIQlTGZKqpSJdhl1Ky942kPbsJvUH3JEZhyeixzQHisAGK++Md0g80Gq1F+" ..
	"gVANAYW5NmCJj+nwiAvPVt66pnDHosShvNbmyk+Knp+/TUnqEs96r4pBW9PXruMNgdDdAs95d8lqbE2yZhrz9scnfA6XzE0+mwgW" ..
	"Hk34oa+XJP+C6zQEaF0O1znTNOaIGqYJUlShwi9417i3917az4MiFOuIH1xBmOAumuIl7DdiLDYtUKW8mSt2TICbL52hdy+sQDlI" ..
	"IQVExBh6sm+ni3PL/A9nX0laAslwyoOMEtpHaqRQLEZn1DfNSipMiQsttTFQVROyVL2z8rzDgAsL+V89MVhqly/Sjhpr0m0uJarM" ..
	"uV1DVZ2/OnhYPc9em1v5GUR1KiOnIbF1rUGQdXqGmDMSlUTt69PApwTCoiOOx4cJS//z2W7qB0HEpGXf/45aIpIsj9I5y2OKf2al" ..
	"9m4PeXV91stCwOjP9wexwXky+dkxhEzyziza/qpXpiVPeiUhEWlZdP+2EAl6RfRNwA7t45/qyPePT1VTxdohJT1Xy9g0ayfNSk22" ..
	"lYYizox6xFJsvWOqn64Zv2+fhWnRQ7QDTYMVZKrvGt3ApwntOR8Jqu+cPSTldnIwxfNFfOYAT9oqVPLcx/caqy7rns5pveN2Cdl0" ..
	"+D/U8XI8y9O3ZPB9cg2pcjRH+H6MVSHdgRHeehfqGhj46DmpK01offntTGstMLLXbQSxvxXS6Japna54Kt2uzlhKM5AdADGFlAX5" ..
	"WcsFSDWdr40aAcBaPPC9R9BDZOIxln4hH9beUZq6EW2YjECcgKE9rFY3x87ru25jDKEtwJuUBi1Ncwv6IZJ9vshBwNC8HhRHoSDq" ..
	"NWs/YVxjHjZHqE5DENE94PAhO9HaQDCfg7z6ANOpKOYdDDl+8WYYSOK2sBnclHtTLmRyPCQdVH2/uimk9t4qZp7j//7iUVu+MXuz" ..
	"UGcrSB18vm2NiGr8ric6Q3S++J8lT6JXRwwDZmSJzFVW7Kl/ztBpKpvW9i628dOibWglJoyoUxtqTnpEYWi3ztSJJHR1/3ArHeH2" ..
	"EHH/vsU3698wkwsXSPwyrlNxKqvThIh1qBSBdIOuJXNQd4V1Q99S7m4oNDKtlgn6+uGAsCpXHIVeBk8t9Cs2SluzoCxO7t88xTK0" ..
	"RYGTGKImxVXCS/1JUq+ACuDUfsn9RHs2RDJgCrMcxTU507C33MTd8fgEFGC2r5udHPLIDhwO/WlFUQ64F30rfpD3bL45rTM2p6ff" ..
	"RIKtEz8fBG2hcPXLbNdjVxKtWvMJDoNNfVlQiajl+2aoDDUCZMDNRAb1RcnuFuKQh3/9FDGJfRk1KNpzFFQDpCwDlx9cFJisADEw" ..
	"/bTKOxEX/hOqEZnF3wNaniXdtWbILMjl97UkDlobdpHF11hYlaAqIbUXXEnqSqvKIHYzwbhkmMcJeWXa9OIMTbXyxqly6mUIkPEe" ..
	"AHTDtP8naW3tJym4OGfFSEMcLZfA7iomnAnTXOUfvH5mqFEJUWomX2kcIc1KExxzY70p3EYUB6k01WaF9CfoFBhHB3DxM+zfmnTJ" ..
	"j0Z6ciSZaVzEy+pW07TxSRUKz48YUEiGE8AtOpgIbL+YtJJOV8P2xvp15HL1jPmY+EY3kYRmffcr8XSveTmTjS61YNfEZuW1VS5H" ..
	"0DdeDfOVECE90uzoFzfeRxZUAxwsFb6+NWaD1irFQx/dXLYdRVwMIsQqcYB8Fs8pqNsxITp/7KvCIYbCsLZXYb85mX7IO2g7vwrS" ..
	"SEyPVYsvZ3ssUzyj2Pca+NWJVP9+S8RFm2UCzz1U4oytIS4n8TJkp/ZVItjB30GtgAH9c2SwGggvNS8JJ6QsyTmzeM5q3NFHYvii" ..
	"iVGmGfrrIZv+2YbcRxsj8VEVyf3jkvkBEAQN8qfFDxHldvuUMuxaxZFNxczjFBskO2YkW9pw6op7dezX4R0b6DI+OouhJtbBFxFc" ..
	"8G4RsD41eqt9qpAHuvRLTJ2G1MdLp1p7XbSSDKiM9KUYBHpiReMj4qpnQZTQkKKtnXPyDsdoVNewHJe/reOvYjj71qUviN+loMhY" ..
	"Bqh/FfJ+SQn5ffTOgOFjcp0Ggebqi3w+iaWDr5zQnisptH3JYSDaPnfgwshoI7ZB2L4crWXEZUxD1LgET3buYirB89MgNIlz3ChE" ..
	"ek9YBA84lSbDXMT4SIlkf05S4LT0EFyjNu0L9RHwgsG6iG1Xm6kGbUJVfx2XFxbD+zr8en9xtaKnEw2/qvlkU/f3/LTCFv7ivJeA" ..
	"+2gd0yIfSrO0gGwMItJeKCrmWCn+jX6dsMP6sKuzddbCkYnzrPquGi3uZxfl46JV7lNRgTBCq+c0PrpIT2OTBaVVxsOyS0kxYQiN" ..
	"g1RSubEpBY3VySRzZ719ZBvzuJUYQs42WLmp40DwZRjrRi/3c3voUFcPm83kKFew2KaVEc5cw5fAZWftPydjQSkfSCu3zDTThepc" ..
	"0nBmDerTi31O4fGv+4vY1UJgtCclCZ91fG6yVuGEJcJcJ4GDTmCCD/drurmwZEulz0/7iO2JO14rwLHm7D6kkmeBFFYB9QbV/+OR" ..
	"mJ/s0QA40RxtAObBg0zddLcM5FtvuavabxSk8BeXFUhOtMSYJQSGNsQSOwAyhKQkD08yMizIY6SbV7EEjBpKRIHmve355vH0yeLF" ..
	"b2XXwYWMdkdEYzjG8O0tFxZis6P20kj/4irnacz7OTNBBlicw/dHtE4IC/ykl//hr/Juuktk0/WQnshROBRdKFOBXjaApF/yMB5f" ..
	"bYlt9BkIv6sjoxVkl3xNo162cfeJL0yB/Ob8SZ2PhIQ0uxi+DktI33Ur4yx84folxJcP/uYkLfITfxLgMplCvD1nmSRyUrZvnbtO" ..
	"Y+bcUXGq0WF7BxbrxoUwU+NysTf4whDxWLMJaPEk17jUlwE+L3fTLRZl3ckO8dVApkQjABRKXI8QOi6nF3PDRYSIndXY85SblZEN" ..
	"g1cxXSKIlw/wwCAPljF27tDHwk0rPaJnkJkdnOiSIKQJSgx9CGViB8Pl0aLNMMnlL03pr78gqxvk4WdU3Sg1XBci61sot4Y7hamt" ..
	"YVtof+1y7kz1ZHtsvgVlmuReuoEDgcTSs+h19AB+ucCHAAR2SIUfIM8StVHvFNmcNHTxSHOu7iYlcYjUSk5I5o/hh2Yid6QYxjr+" ..
	"uGJo8etm2OsBC8Lot193cbVDPJ6Z8jTS1PY/4v4R2DjcC0QKsks1vWr8aFHC+xW1DoPgmt4bNgxLO9FeGGbFz63nv95LoQmjR/Kl" ..
	"YajYbVwy5C356NKGx+wFI9T22RUNZ9yl0MVsB/EWdRc/g4us0KuhPDfD5B7uyePKV4GxisOZETLqQy52bYS9yMPnpUGeikzCjzg+" ..
	"UGPUhMRwX9mMLPSHI5Ie/raaVMfTcrDhb6ZjuQgRwCgWm4iHyC7yYhF/acvr+Pt9MF6FZCnU5gVWScpDbBGKrSBFW4bYfUZFvNRT" ..
	"Tz0XpgDBMqZ+YHOxM3rG2hlJMHm9vdLdN304Vjarmr9On9ToyC4G/zhYlZXEoDkw3dUzYI00Va7g+Q0Df1iezGuHEQh12N2TqLcD" ..
	"OnANb+Fprd1GV8qj3WwR+PS6O5yQY17lLSV6B0yEUkqEantufxZR3z3uIVYVhCa1p3SaSqSA7X5ZmTZ9xRdh+RLN1dcMbt5AedxQ" ..
	"hrLw6J9OSxNgq93uwDskjJrbgbQK33WZzmgg3vcZuRvUQLqFKKqhu8r4d049dCpOty0MIGDNd28gSqGBmnDPdU1cM8ucd1dC3mBj" ..
	"LcZ/M/p55fxgKDr5PffYA0rjlwCCN9vr4+Ykcz0Wiow+zMycCuHDloPPsTxsKoJNCPimu+oaru0Z4S9ygm48Hb5xcdGaE4H3l1BQ" ..
	"gsSOSaKboVqBdclsnZg5FzpG6KdqzoNYtzgDJX1/gdedbVhu76sdffV4gNQXU8j14SJH1gD4gOi/UNNU6RR/PjHZJZTQUA62VcT7" ..
	"dmlNOw0qDkF8jxUDMPyNBbEzRH81aIDtpCaPlp+/jdaIVqgKsWyCB9+KiN/F8t/5mgpIjPEJ8Mr3QJGJIETpuRqU61SPDCgAAbCu" ..
	"6nVsUGajv2heTsJcewAv1yXTlifR6irFh6UwCk5EXaLwqDg2G/quvqo5AsaPwPL8dnL0KcVX9J+ya7XnpiLqhA9sozDHWE282xLx" ..
	"PjmIYMOGlf+k7D6E4ZIjLHj8BPo/uioJIw+MUiC7OCf+5GQGNj0RM2y3XbxidfB87JNIWLRVKFrFKLUQaIceEs7Bf0bp0cLKdTeA" ..
	"DmdmkbYxfuDJE2JN2oTOELBMrIQjaBl3k4NxDAKO063KGudrK3Wq7FNx398sTJac2U+okyxGZqdQ1E1PAuZqzBJXwi+2zyKmQ1k4" ..
	""
local PAYLOAD_P14 =
	"L+Wo6DZ+/VF8JGEabYub+D6xKYbDKPkd0CG8O1CTH4Nwv93uBlnNQJJKbYFOY+BpoRMn4sG4RmBYm5maAgFHI5iQjoi3XEm8ql4O" ..
	"xfGbMw9D6QObYRc3cZ64tfZ2Zh4Kh6+WceD6mqQj0Sak/HaXmpDbot6CbPqECIO6kZkjK24cSnT1mamu89oGQMeavP376CqtflVq" ..
	"uVE+awJIDCJl9I05zsDc2laELU5zCP8N0QgVyyOEZlpnHBZpMrlRHFSC93PUqeP88idNnRwn38uU5YR6ujlu03OBcozsYi/zESbf" ..
	"YRF5DpXY7/A5kjM5YQMM1YCCphOIXIL1Bt5/S5+yFw1YTc06oJ+P7mEhTs5LsMsbEECW6GLrD+QgJIrtAqisqdtytL42PLz0vR/d" ..
	"E1PRmB4SiEbz6FNabs6iSgTf9pygQhvSBe3FdvlqCmKj3ilC026NLLTF4HpGsCyA3WmqxrPbn1/iHirPzhwRbhbpdTh9RkzqCGZv" ..
	"UQ5u5G7UXKdOfdLHDcUQuQyAWUqx5W+MBgtSv7fPBnJgrSImX52vkNJfSEAusAzmoBBz/3DklLjtso6n6uEGrtNZsVXnxEUzIAUE" ..
	"ILNKBX+EtEooZoBbs0wCWYCKs8nc5hsq4TbPM162nz8mhzPDYe4wLa30EuC+iTAjr23UMoe1cxyvPfb+Pj6VC3fw8J4V4xx/5yJv" ..
	"MMvDB2d2KDBvQegX2IY5wyvVfJXXjVZgqH4k7J4rimSzLOzh7tNA4qj5QN2o4opfom7c39I9+TbVnCz6nUwuEUR15MH8bYk5McYX" ..
	"D5V51w8DOVYfh9Qi52szWcTtQR0lx18mRar9IcFuQgWYU9DFzx995z64HuRV1yWM8E5Btv7nweQFt8nMCgoaZky5BTLZ3tUp0irK" ..
	"p0fP0GpYqb4S6vbnzk0ZjwsXU8h26HPBmEHZHMYjuO/w/PL3vUhHhgt+KajtYiK9jlkWjXS/5jLyLp30AjsLeaQIWrY41NWQQh5J" ..
	"N1eq2XT/m3/uoMQf5tc6YHb8auBxH5jw7cYxpz1qBkVBPfp0oS0a4ZkBiZqbVljRYCqTu+IwYHo/+hV/udnbM6ACZBZKKujd6Q9E" ..
	"rO5jqJfYQAsku1HAUXw9G9ZHxkWAXXM/eYg4wEC/07z0ENyJLkFdzYnApWhWLPn7S1zdpWvyyrtcuOJ1D9nIByIcCXjJLBMwtt6k" ..
	"ULCyS/uEbezPn3djj1WUYTRaik2ntKpiMP7utimTP5KHkPz1KtU43hUCtd25Cnczihmb4App3xHIU2oykTXjJRKu/gIBuXy+VDEU" ..
	"y4/P/EkVV/BstSWZyu9IWSblflg7ppfPic2X2ZUcX+nxGuS4Bfz+e9E2E4Ayz8dVNykQTAz0KAvKZQ5kqfdrlSHpnH0MbEdHebv2" ..
	"Z10FH6BlHTWhdhq0BOnwbE/5jtpFxum/TXFkhPeIQwEnDi/HRu90HFGd3b473LZu2DShrzxL8Rfl0saLuPM42ZT7vaHuD/PU/tUg" ..
	"2B1xVd+8C5s1DRFISACZVgmMjs4E2skn8pYst0YGBOp9+TD/wS4WOcyc0eiWoFveaFE0oovDtOTDtqlrchXphvGLigy2Kzxg7lF9" ..
	"jtFFESi7XwUpNXrfgYQO1yy9gwqazJAFWxTaYJ5fpb8CQLZcWvCjnBygyMI4BFgQukNKlqgBe49uo47WHJtS+RTeXIUx7EflhrOH" ..
	"DqNEdqFph8ozAjZgs7d6DgQwEIKMYbD/vlDqSEX6GimZjyfTVwM2hG9ZkzTxtS+D0Uay/ILYjtEZBkIvUD2KqBg0E+HqW4K8Z3Sr" ..
	"xOXRBYhVhZVcRLh//sprudL7knYHoa9G0Op7XptDdZoYWrI+Za9gKW85NBJ13ak5AGe9HmuxIKwemVFl/3MUmZ4B2fLWTboNQM69" ..
	"TVOzibv6+r3Bczf7z2owUJU2++rDO3ocWO4lWmp5mI4wqS01GcIHgzFf1d7Bb8wtf28rv7vcoDdsqrhKL8x07RnjhmbjDouusSWe" ..
	"aSr0UfBUsl1Bjl5Cf9SgJtCZM9mLHPhk/omEMlbryaQRDQtxyz6zZY9B9b1AufFevFIGR+LbbibVN3udJ1rGILMMDEuDIPO/KBGn" ..
	"MBxwBsp5DayyzP2xOPsWodVe5isl1MG2xhhgroFLjE/CUz/Bm2+HFnaVAa8cNt401ixJfJ+/mLywIctsNObV1aooRS4j5pgI14+V" ..
	"rcOS5J8s6Cw4qrBOZtVb5/obOU9vHMQ0rJazky3GYJ8/Gm7DklWX171Q8Ks7ZUxGoJ5i9xCW6caVGzggcySYpAZxXBqe8F/FZLU3" ..
	"Jp5HbjlWhnhvz8R8OovpWeFpbsFBf9fWSV5tLeiDSAR1uw3YlF9+eqcMtVQdhncu36C/zfESkX3a7oWQ9d1a2kulS1N2DJxyQR+P" ..
	"qVrgyaO5EtjJCsbNA3Zk6p3DlOM6PXW6oHrj7P0xztOcTvqRYlO8bm0cbbMWwhharSdTEAldxiWMdff3tDOu1wYOa73RMGzjGuFy" ..
	"zEtSOvP3MrGTLE6VAcpEwziiY+UkCWO3h/oFK6pEVxt9rb9A6+dZ9KpVGUrB7XWhlPaDgE+4owePbEEy4fWA0NgA21z3cFGasSTQ" ..
	"Gcpy5QktppZnfwSusMjWJA+4zUCWRyOdH8SlQ7IGuUOBDgBvRX92+BGd4g3DAJgCCWqMpH4gRNCltLtVq+GsqttoI4YqF9zSWWlm" ..
	"qqfQqdxWLB3w3lYDfpmYeBLzxBSpFjOqH3JrNMYAQDFSdCqdC+NiKc09wuN0e1k0ngGRy3ko5d2PHSWTcd/mi1dWuGQKEoIcw14t" ..
	"NbETWQXzc1UgCEza6WUyM55gUcOs82292HZHN4lFzF60rkLkM0+NWw1slIJ4DLh3V2rAGN2ChTMHE+11ZLpK0qB1A3PjD6Ux1qVZ" ..
	"650KjLcntHmLdDxopQQ/0sed3p+PvaCfIn+ZsA3ImHeMJEr0sHRvgJTmkgECq7z322UYQq70CTGK+B9IgJgV8z0Y7Wk4L8pmZWqC" ..
	"yOT1FMw7rvQIPfTju475yUHREM3o4bUHCy5ZOw+IHwoqUrpKsj9Y1t4GkXH5bfEVwkmCcGIYyw9npABKuTkDk69j2jGGhnO9nD0V" ..
	"dn1H1w0jr0Cun+ByhSoNSsAW0LSrVf6qAPJ+NoZWaXCHdx0Q/vKPEyfseGB2kpDs3nQYQCwEt67mrgVblt1k6JVjN6OPjvYZajtY" ..
	"maVi80BjY/HWDfQ1gES1WaebTxIve4aVNwXcoVjsL7cJwSVeWvhe1ynuvicMGov8hDCwgLIDyh6KuyVBA8VYpwu9HscDxV4xr/AZ" ..
	"bC/GMhNf1W2pnyldtZHtflj/28tmGvLNuH5CAFOgqVe9zNZhwICz/orH/oN/MCYPUNYcvoqqVB9rTmD5mV6BzQD4caWLtjftBXv+" ..
	"sbMxf8jxuOTbfKnCLF2GWtjZqlTXLNeeNODtDY3O6loq2Q38xpfGL1VNofh67R34wBsn398qeyPN8OypwipqZB4So+6oSIXJxjET" ..
	"aDmJTss7kej3ESUoMk3XaMbeNKzz941YOje9vA4EG9MsHg+qzFWtVysAUHBVUgWMuR/NOf+67rSGp6lBRA102HSegvO+EMOkzB/e" ..
	"qU2hue1hsPhucLEY+8ine1Dr2+mKg4I1o4CS9g927kSH8GVTj4DFH9ZXjlJgxT6X0j/YdfCGQZ/+GSARMb5xO7ZnYxXPNjhQjxYj" ..
	"pesO9mDCvigSBNb3Xw4A8nlypADQka+SrdU7NiL6peI8dQDQ6gt/LNIV+KiJPb0DJmEq3VzUJ1xDqhIhWbDRW1n2U5zvfX6Bl3rs" ..
	"z6rkW/ws3UxFTH6Ibj4oJLcRWVxsO4hb++20qKQ5AdEGlZIHY9rfYivdBEnRwpdIVAYIbfG1Da3gDIjmasFT1IJ9x+FCI/SnkAVV" ..
	"b7SCQwXS6/utWHjTw3o9ncaGlq5uP4WTU4ONd9ja8tfcBI2M0e7pDwjGO8VSgGrqxsuABVHPnrU5WgHt2QbycoR1MjJP/9wrflQI" ..
	"SSxUPmOq/nZR/k/quUV9Grfj1wtU5Xa9KGJmlCR206t5FhIxiAV8l+LpO1KI0BdqtHpjmj2dAaeh+pmIc4e5Ky56wmxKyHIiBP02" ..
	"HE+ZeSsPXwl4GfWQi3VrbRWBJSEXWxpfN/V6zPw4aOAy8mM0MK0pXmsrJmlccCeAJYqJa2OBFpsL27SZLy6PL2yVJJ0yPwt83eYx" ..
	"vSL+xPMPPSSwzC/TYtj2NPeDSX+yySyzq+CJCn7OifhNygqOpz6kJBu7PeZcskBn379PXrGrCRl+Z/ixwkLdCx8xrEtd6XjIe3OB" ..
	"zEdqW5ihLKhzZYfbfffWNyK0+4CqO3l//pEicqiXXq7QHWLUSeSMXgFL6SAR3T8i/yNeLh5zPFPuZQb9pkN6kafzTujfAL+NHu6t" ..
	"64qRPlA76lgwBNbp8woto/j1Twv729C47nfHjVI1vA5linzbwA/VJ5lZqdhzbRewLAZGHt9klPJ93Y7LwSPnbYDuo3i/bMjX53y0" ..
	"0qLhcDRHWwgpUt7V7WBALiaSjZUc2JhVOAXqN+v9T1GBCkfT3y/faZAlBRJ8ESTTrCa1z8vbLHPm7439sUfJh7tjpPAUnk6hmpNo" ..
	"wIWcQcaIeJK9CfHEe+dZinL7KF6ccbnsnXVr4R0sDuUxeaD3Xkb+7o9ea1M3svUvQTqLHmmodKAoZV3XtVLY10qHZzoHKXMFQFJy" ..
	"4HU/79DJOG5i3GQKN5y/knCXLxuQAJkw+1Zz2iHqvqF9p/csPM9PNsAj1IfY3XkPLBBcYLNVJ0Xivh64gY+OyKzqWMwjwrzdsdZc" ..
	"HsP6vnp9nGSLXYAHgASo0lnjVlOU+Q2ueI88U2q1YDAK2wMeWw7wVUPF+RZiu4BUG4Nfhm4ocYSuTbX8ElSGeqav9EzZvdAv9kjz" ..
	"GtzfsEfUGJyR/mcruqh/bjp54LwDHwZ5wOMr6swX52GrIN20oRIZOT5vNWDbr3pa73YHq3NXZ1FZJm6+fNAWrCkchnztzgO7dHyD" ..
	"OCPNybDKPRjZYDDi4o9+hYjgTFZ/ggiGytWR0kkjNAnt7Zl8V0tH7BOTAu04+nRhYtv5N3spjDcGps5ME/k83HcEL15aBUmz8Tyu" ..
	"TH3QFZvashrcaq6mlMV3MBmQHygQXYL3xe02MtSbXZVNc0eYkwv31OgTcgW+fNcO4wibCIqSJt1oAn4RnpyfTperkhFcgPtyzq5f" ..
	"lcrdQwO2rdtj08/F7KavcvyDnECnnhPlx+/QDR0594BR7cZD+HNa/8lrSPTH4gBepErjV/myihuRDJP0Z3jfdPPsqzpA4BNISpU7" ..
	"sDXEZwoeNSGnnjFrUMQDOnEe2PRTAaAGJaw0qrn4Tx0ZOwKsB1XAcrZUrp6rCxbwn3ANo1X7s1kn1tnf+pAWriE8YnPLl73D4YRk" ..
	"DTbq3zRwvPsFsLV+zCVc9cSah/BD012fRoyST1JyRgCMk1uVAEC2oEqNOn0MggmAfBI8ntDDXXu+jz16WRDBOuFC1YjOEAKsTW32" ..
	"mkfhOVHr776X7qOYP+axbVJcJ7D2GiAXktQ/WPOGkogGSIme6rY2zYOxbouRDp1tvMmBZDIDMlAbdWSFyB3f/hD2zOx45BZ7xpjH" ..
	"s0R2L2O/yJah016p6K7reqCtz5YeqeiXO/VD81FSXLx8Emez09cRnMtG1ASi1HPb2RlyJgz/9fo2/aTJoWJEqBA+hZPI2+b4gLp7" ..
	"WYpM4rN0MB5tCFtiADiV6mW6tU0TblU8rkdE1QcvhNhG+bJyyBbuT/DyQ4zQjC561tYVxk1A5u8ga9Ohz/bAKysPaNL63uZtGK0C" ..
	"Iq5fJCZRrOjEBRfwXi6McTWTaiZu1OOtJYcetrBOivtMRhNYXfzsfGZ+yXsm/xpVxMaVF3L71BAyHMp8f1zEQlikD1/2k9e7vJK/" ..
	"0Od4i2Ub0BQXGSoF1n4HKQOs/Ip7aphvQ84xm2Nx4ircY8DDbIsetxjwXUrbTZAWaO1qo8r5PAhPiOBhTnHv5YZMxBKAQc5oU+t7" ..
	""
local PAYLOAD_P15 =
	"wnWtqIy+mYXmpvUQD+oykwzGzC0ZCyywNF4IOgDgyLBHBmSJ4mrDc3MFMj0F/AD4UlpAJMMJNqXNFvyafFEIibUMbW49e4hYx+va" ..
	"IiJpR9q+u2YPmpZvLSms2eICdu6On76vXcC2ldnJlk7+/i/82ngI13QAfJCE+HUttu5ZBpQC4INYgFRl7B26be2RS1yAnDNQq7sj" ..
	"mmNDv135rBwPGTLmKgVVyuABY0GcYOStqXagR2Q+4rYDbKno3s1ldpjaH6D2RpRQMoIPS4WcnR+CL4cEtOwhacuZki9RpZzn2NS3" ..
	"9DOSpl4VOUe17nUhAVfSvKG7NZssbpK5UTqZgR18uFdHA8qChJlaG8o7RKf3ik312fEC3obXnsgjzagVzEAqitA3TO+jeP3rxQi8" ..
	"MbkPRZ8bR4/yX+XQWFARSyDIiGt0VOAC+WcaYz8dfhEBrB4Y0d2hs8koaCRCe5iAVxHPaXJp6aJU1tIHpCR7Sw6d6sj+Q87FuqZH" ..
	"19A4J519ZDN12QymLEMCuNgfiEdtZuPPpCZwQTeJmwh1+m+e80LsyI/tT/I3oHSsMA+zg2HfSFA0MXXI3A+1awY8dlLyXUW/l3wF" ..
	"zRmM/0kO90/bMRK5aw3KAGOI82z17K7yKL3ihZOMdvuielPpgtyPY2s8kq+Ql2SqXfnZkgILp0a7fItC+gLscRfzdlHXRezAK02l" ..
	"ppAvLN8mXGtI/+4QcVtnV9ETQff5AErMtNhmdrqqiyI49kwrDLBbFSxBcvyDWKcW/zDcktCmoffkAckb0QH/eYSYg/kXp1w2g3Hc" ..
	"LJTaJOWpX3ZqQqLdVDvguwfONu4v2CvKRMkH1eblMI/hwROjaR/vTKeR8dA3K0ZFIlCdTsO/J0G199EDrKytIHP2HAqS61jgtJYk" ..
	"pWWmXi3vwHD5sA3T1v68s7ETZ/P7UntHY+fRXQzYU4XVaGT1m409ees4sZ6tUGz5UTEQxCwaO/KIV5d9cO8FdeHiBBySaocDOpd+" ..
	"Mp/wa3hyockMBroGNSVblY18nI/sSIR00mKPnzZNe1umntMdzLsPE6WxuKzMA3swG7TidETXlOZ+qSdlp008T6Hs0se5qiF4NiHS" ..
	"ieX/YWmUgQVKhxdJS5kZt2d2md/hpT6i3ROpCjqYCj5BQ4ppczaQL+Xsh+VSlQi4si7fSv/eJaUA2RSwXDEKkGx7r6kWDcm2M8KC" ..
	"EiwxzHW8ns9lfqIfKwJWn7SKOEf3D942+o5rdSvYn8YkfFHKGPq+vGlDsmv51mS+vOvAUwSThSY0iVyjblkMVc+MwlCDeeyvG8x/" ..
	"FAhvBfGvVRPwdyAnNuIQqzuQkdVV7JyobeLVLLCggRHQiy6fb0HyG2fSs8iWohO36DzFwKJZnAdjkFuUPAbbnLN3kSJs+Wvs/6Tp" ..
	"N3ZjNVC2VI15am//oWhiyU1DODL9sOKMbEIEWA18H8CP" ..
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
