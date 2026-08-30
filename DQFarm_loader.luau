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
	{ seed = 538467818, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 543178236, exp = 0, plan = 0, hwid = {} },
	{ seed = 543775129, exp = 1788089514, plan = 1, hwid = {} }
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
	"SmSRCLCebunSZMPfMRrN3zsbr1vfmfmFZgZWcoDWWEYnf2eCWXoeumLPcLsu1a2TBWDXzhOB/VF6VNnKPGPDIw61m1jeHn83IibX" ..
	"2kcNHGcnJRzaCTBNLyAVQcZDrehoRhpV/NgYX8JJ5/saHR2G3ERVUp9z5Hv9KjNODXp7lXN7LBkBdEnhCyQ1FuuZ/mWwPyKjJcim" ..
	"7ppp2+79HiARqcjWn3vcI++WxzUq89jH0NrZgku7+eVIIhFaPvoiaU9R3k8PcqRQw9kucbEooXdLjr7yBmXFf/00td7cYCJROMV4" ..
	"7iLNrss126NPDOUamaTMHvPxhSxJaqjLu2l3dmGDBpL+xLGgWwaG6Haq1iwHSHuWCpxmh3zOAeXW80oTysJ3dUaNQVDq9jqSZjr8" ..
	"z0Xl0LI/5yqbyem+1N8xHLvvEZu2KRQNkMh7ms5K3a3x1oG2GtmNj44spzX95DQH0gyOa8aIaDQjPc0wY8BmWXGYgArkZNXvlrZQ" ..
	"yThS/y70kGY3KyJLWx+l3pj4ASM4MdG/VxUdWTP9ND6Fgxo/MR/ZOJ6jV9vt3+gik12rtXywQU0GtsVZZ8Lheam803j6tb2Um8CE" ..
	"dlNY3tzaZtgCi7ZAqydLCP0gcNwh6fa11toXBcE4NJVY9zQkkVPY+YKeCvoFn24dOmqWPGIKRrzutK/ZxctzUu6ZyE2jt9ZYT2+i" ..
	"Y3XMSxBcI4F3NZ5tK4aTEGiSr53aEVNgQG2NawNcLTZd3DEvT/HXAhZtKtXCk9bpm4vowuaYjwYHFe+OiLTK+f77upceXZogTpQV" ..
	"9GZzYHcYTuAggp319SxtdGj4hJSejX6MgllqpH1TKmrcWohatdMxx65ew3LVZCwyP9ws/DHH6r94P77PtpVuIoHEpoavv1LsXb1O" ..
	"ddsm5mgtp9hn8VtD8d4pJgSXYrfhFW3Kgul/7Bg6rbdsIZA5YDxdpQLL48JQSN0+Jyz3rZhQ60ZpYWX8eesSxQbsKEn407wXoyuC" ..
	"xqKWf7nqC5/v/+lGw9wTeSYFl4tTFKDvIcQ9fIM2iH+Hgc8Dq16VpDgU3c/awxuBF2LgDtoHukRPvXY5kU8HLca3iFpE5Lp3A1+E" ..
	"gwOU42gB4if/CK0eLejEGC8YUa0yj8W/8oSHA+cyZCzf5+HzBWPd7O0EY7BoM3AMtOpeNVvlhPpinuqHn1RMczuQsCNG/l4eaf06" ..
	"YY2+TIFTmoHGCRzFlflEBA0YjjY6u2/1pC22waxP9BB5Btp3vXZhehyfDWkARUiwkyPm/WftOokXx8+hc7IAlykE/nN/wBjFVfUL" ..
	"h9BkkGkz2z5sWXnMDv7qJBjDwakK5AmibelGkqz2FPpkXAwwgniQ2QTMZfMADY7V0f9Es6VkDY6JT9N9eJj5EfuQcxwVEfwl1vQ3" ..
	"axcAVDt/F8e2/1WRY+RjhvltOdUTLBM5Q1iQwOHq/ZER10AZtEdEgQOYgzQuiT2Yl9pa/l42EPIxFXooEG0t7nB+bPyQERLSEehn" ..
	"G+L7+bUB5p7rm2YM9VqeFRtPEHzU+aw8hEiw0PdyeJLKvZi4Esa8pRzSSpzi52AfKt5xd11zoRlBCqDdS6QbXgXoe8wCYW3jqxUX" ..
	"brIeZ2R1sQLHnisIayQkIWEozm8pzLG6v1o0pWh0OS5AQaEGtUXvdnayYm3Ut3RtTTYEz+VUMR9sTtEE8a4llgM5xnrkORzlJiXb" ..
	"6Hes426M85OYvFTe2lk5jGTkGsYZXvkJuY4TqNOUQo5dAOqH1nVuiVRlDiDxs6EjvpRrxAEYDHCxN7PJ0P7NjUCAu6nv5W9/YknN" ..
	"d5a52kuuIkWbjVo9z9yUovSvT8le5uudkgGnkB/weRRHMYrLY6z8mRTevvBRVPN75V6GC2buFsmp//z0CC08cBCkk3GcGW99UwSp" ..
	"AKptHOb7cPIKngn+2yqiIzn9DGhbOoPLHzrGKrjpb8zIbPbkaubsPN15iSt4rbmuMYVYHTMpZbG5Ykb0RmwLYwQdd3RZkjh3geaF" ..
	"WTH1gjHjje+s993ay7s7vpsDC0C7QQERZtAeCvWsYBGmV3SiZLGZcxXk3fGp9zLlC3vGgZB9DjZ+PJN0JPl+kvQHErLSMaEb/zbk" ..
	"XoZmI70yJvYgCEfK/5vO7q93kA3kQCsxafz4mKawIz/9yy6hpReT2li8tf65JDTW6S1koiixerKFOwEG5iw2HUE24CGWLL4ZGVn6" ..
	"pPcLgBLKSTVeN0hVTPjR99hWvBWQLzzFX1nFXc7yTtXl9a5Rp/ZqHr9kbXMaK9ZaF726RVENhfPODTesoSP8WiXj2pDq2eJO5C1l" ..
	"x3MYNVaurg/3pU0LtMPA4gZV5bgyUU5W/IMEAVoa50Sn72pCopGHwfSVcKC24J4OsR1/SZMETtq3pd2p/ssmZdcq6O3QXV5JT8Vi" ..
	"l87KJhj4BpIjexdwNeWl/WOfJLqppxCxkaBWOmGnSB+nYE+PHKVZrPFEZcy+vSFOtty1gXFWLq2BenGZvsT9w0ImFHqXuUwfe70H" ..
	"FCEARnHdsN0B/nGFDK6eilMdU588aEJxFqRdPu9zpHTooEn5fQH8StE2D4uHCLVpH5cXeVqs1HDiygReS4aJQMGl9jzRFqSlSx+p" ..
	"8ylkdz+VlEaQZxSVLN/sEpKfMxQioJqtOJpVvzRhHSIneNc8g/mrkeyEysnrL6D4rEWYSmYJYn0PBYaSGpNc8tMlHfE/c5lHfSYN" ..
	"WZ2yq/KKcYwI7lrlTGF732ZkS9mSVVx9UICs+wnO4EvQ2GbmQaxFCFbYLPV4vvc6i3uTa84W1sTfl3IITXZkMFNS5iS1XF6G9TWD" ..
	"jslPguDERPGjCO6lY20Q9zNc4JWaEfE+t2rAMARb+mgZg4ZmMsTT0imGWDcDmK/HkBkMUNA6Eu6pbrJ3YBW37M3MSiChTD6G0TB/" ..
	"l7erWWjXkJJpRR2075ZtKYgIzn0r3vhKUB5sTENLuhA5Krcie/fn095oST1nd+7r2Ygpoo+oZL+idYnmT/k0oN0ZS5ci2CMljWxE" ..
	"JU5yh1IPseCnPEOGy4KC3CzqotHV5OuSPRJGQvmjgrYM9mM6DCsvhrE10c3EofyQKtiR2D6qxQOgflwv3cBD4GsDCASLsSBvD41+" ..
	"4OuyY693WCRT1qPIn4wwoZHaamAxD3jR10aAUqb+l/E/Zem430q/nfEwgd+czAy+XQjZa+jes5VSW4ndHPC4hO2n9pjv2iVeL6DC" ..
	"gg9SerN7DcRMvdrPjYonTCDgpn48GcJ9Os1siSsErgtaWI+PEuSj8wVwQAwrq0idLIBUhcmYwjoHFdLJ1C4k8XkRWKcDlFqr3Vw/" ..
	"wiYHUu8RjxL7ApvFt2kB9xe2CHaVef2FwD5MLcsTKqWiLCtf9eUr64FAbWHldelcdkuWoSnaku/qhF2hnp2ZQpX87DBrqHDDBIiT" ..
	"6hNfvcoLR6fH6z6OiqsHyG2Rm7eNzlxKNBjYzOkCpIpGeh/V6QkZCZ7vvMjiACPpNdwHOtY/oJ+pgqI0lOeyHQdANRV83f/rCBMF" ..
	"TnOkTxBH9BSfEbUdQ5qRIN8+9dZNEP6P2YoVpzo9B3IblnlLGj3mPDNZduHbsopEdl2QK65kEhML9lSByLPBFFycULLfZto69f+c" ..
	"SXLBNoW7sh0PfWLBwjwcsmd0c0gmUMqDkp3aIA7UPmw+LhlWmfOiDrzLm1f5uQtUYOc88Av0WBEp9dWcVW/fk8zZE0UAKBXehnVW" ..
	"Zm78onBlUH/E16nfWCE+kUsThH4Oj1uF+RS8raLTF2RkX9s/yFEos2KspSTttxlIaBjrEvxLwpJ+oxZuWuzcx8PLVzyKKnBmJ825" ..
	"CrhQC4UoSnyx9HTGQc0WfxZDr9v881rk8K58DxpQsE+bx1s0N32CK8H+TeTJ4nDH3KDv0lPeqK6PLFpxu/0TGBjhSfCBGumsJaHN" ..
	"P2WqjWtxegevBZ1R5jWB03pZcSTY0/ijIKHyiZgHmi5nmnVQlGhGAgse7oQEvrCpzp3GWVWk4a7okr48ME+n3OD2M3eTnUXDZzFP" ..
	"1skN/bdJjNe7r3VFsTJqHtiFcAy1tR3lpmtflufnzmtd6R8JXKvxeGCDRb4aL/SEXH3RbeXGUV4bCH/dqjiTbNuh0ghwKv7J9Q3B" ..
	"5w9SGWSBmnNJmbCJsWamnCsyaDM+mbq15coIUwlBS7IdZmsGP/uwZEBXZ+D2Gq6yQ2KtjQNIT/oG8xGgTyBThuT4nPRjRRAhHgI5" ..
	"A0MHl5n84uxAbAy0LYIHCseaDFHTpfRO7ueJqt3MrpQyhBULH9z2DI15coq+i4CY4cXLLmH/KWiHwtO+WoOXNFexspiuQ2njtdkz" ..
	"GGejjsq5r5UWwFpr/QF0ty1c91WzfVxuIWJtHX4+ZfvBJRjpHicVigDzqJ4leST3ZKsk2k1QrXQrSbznE1kh5einBBuZPb0LJUZa" ..
	"48JNtTF5c6pzMb5iIgQB56M51f+tz/kYuJ7u1P8+zT4UFZtezDC1r/24DMWiPq9IAyYcEZpg89C47CL0NQUL7ymPcS/XgcPXLjoL" ..
	"CFlgyodevdxhC2H65zBZOYtGlr2e18OMLHhqWqgLNiHNtbnzI6asz/e9mWLeb6mEOxisRlPB+whnDstxa1wZVIzbfH1eD5ZfKQD3" ..
	"UXK3iHcz3Ul1AOQbshLgG3k37keqhte4p+jDKeXkQHGQyKws6vI/Uqotv0D9n0ylRxs9yy5UDtCEdzh/QvzzDaJqXdA5LhpF54XI" ..
	"rjo3JH1Bs7dte4UU04LQ31D1l6LcjJSq6niK1OSUOdLOWQ0TU/iQe0UCgfwCiL2n2K0iVMkROaHS0Ro4o/AuzH0WwDGOmQ7CK8Wn" ..
	"1hZp+59lLEhqIQdwU5eNFbb/aanCmIswM1iBf7YkP6wp8HqghKKUJpIwHJkgMVpG/ceRoh7VnzGquFPLtBbsx5QXqja/cYijJbtI" ..
	"vw8caXDPepWYC8XaFCWO4w0LJ1c0dVopcQDOPA6k9uS46T0ck1dhX3B2DCpERuUQDHv7bG5neQJpS62lloHj+dZqTPFYOGiWmxWs" ..
	"e7/zOi+1UYb8jmCo7KtwT/B7r9/wbvh90ZmaqTn3JDN7vdVZYFtpaEBZJMkJCGMGvmc2QGitCjfz3g34m52o5OOgNwzXxUMDGvQL" ..
	"gpVQivWROTLZuLlne2vfLi8nSi1FugfATG4Qm4dMV7oB59pXFqL5mpRhd0QK20HeeeOM4vnx6BEDu6dZIChcbuwG9pghHH4wsfxx" ..
	"+FnRWtA/i+9EKx9RN425auKVn2oQjT80gmPEA8Z9j99dfj845oRGiBq0w4eLJMJ5i5KTdEldH638Gpl7nl/ue2k2XlX/e2fs8rrH" ..
	"1HQoxvrIY1coWEj832TUOlwsZ9iywred1OuipDWwJcu+dHSM039HdrznKY/xhY5xgGqJGBMYA56U65LwdITtPBcyXlZzTAA71zYf" ..
	"xWT4mouFFvpB3MQxRXWrRZ/HZoYyhba4pQt38Ebe5Ys2HJPr7ThJJgFNDhjYGxn903EhiuXg96j0lKSo9qxACH4/1Jzzp+08jdTT" ..
	"4ofWafW7zlYWkTcT6vyIVH35TTVlgy+lkWoyw+7TiplRFiQZsHwb3GGCV/EG7rq2qkMR3sVET0o23KS/c4OYTcnMNV0bX8lfnAs9" ..
	"0T1thNMgryjq92Ji/iUySE8xbCP0oWk56Fu5bQpoLUnTbLBW6b8SxwPnvvN2UYqd4MnkMWXQHuLBtRtkIxBT995Zd2OcI+3WAPzP" ..
	"z38fOPM2RVF120YXHV6RYUOKpMQqq3ZxesarcOmc7dXr9pBO10iiIkMBdkU22ZjsY5v46Fgits8FhoqBaUTnc566tB2ZWmnV5zMH" ..
	"hwxulDw+F1OtDZfFFHYzzXbxeX6YJPhHeAbXT42JZ8FEAftCcEDWnSRVQdKwdoWs6Jlpfm0VgTFlK5pgzlXhLV9y1aXBUj6k6ymY" ..
	"pNVcBcNe2O2Zt3LVCo4POFJSMXj3uPKC43LuRObg8kvL7F4VLBQmwizpM9gGaRIXm+wCybYYgNE8Y3ejTUKyIaVn/NaGiMxED1xF" ..
	""
local PAYLOAD_P2 =
	"gPpK5NeTbEmc8IUtTwlXJD4J8DadoJwdcv7+vXsGWCj/AFBBM8XJtpVVrn3rgwFVoUZ8xXJ0kQPnBYLBSqbJzZzVRp7Jlbr6uOJr" ..
	"0Cxltt4wtfanBCF877O6TDXFLaTqSviRcVOKtCwhrSIYIT9H81Mmq7FB91kp8vsmvBulGgJ+h6MHiWgLO+tB/2S/VvOPWTHgFL3M" ..
	"vQdmZgzBZoZZBP+hgeeo4d3oxVWltu+viQQtH7rJXBi8JNEUntEykEthqnbHrK6pshNV7+ccOALpApy3MKjzTq43LaKRZnQsDlr5" ..
	"ogPS5ONGA7kZSubzN5lG2RSNQubMsIWOk4yEbFYaNr5Q4hGd5WaRtc8/yEpigbY7RI4lpH+5KwQugOqKUX7gJ/b8QfEUUtMfPtfc" ..
	"rT5gWsVV+9FHQcX+3zKZQtwORDMvsGX8hQceNxmFuY5hBUQg2w2TZ8xNVlTBSCSeSi+JucvFs9ApyMeHwbd5ojMDV3aZQMYHR5Ze" ..
	"Cu2Rtg09p0LY4OCpj1HAtlRV/fdRzG1Eqa7zqvzc3RCdebgLcAM2dJKda7ciEaq2rcYEytndepwX69P96D+ISnzn+d9Mw5hkP9te" ..
	"7pZmhyaj66Dx/gUiGDOIIgXkGRCJrKFvB4R+HIhR9r+x2KQqqOxdtDCWSqXF06djQBqZmoPPHpbpBRt1Oyr5pIZZBO2tu45fDsUs" ..
	"2jHGZwa3i/tS5k/EG2LW3XevSDvfQC67IcZBFw/BNTj3sM8zEQ2aQ9R9HgC5xu70hIPbmIh86GAHcXQiNme0Q3n5y8BfNwTYQfb5" ..
	"o3k8nddzwnFd4f7rkWe8iK83lVK/Mvfev+m34WJxe+vJSawb2iLoXU2+dC9S2RLSRIRCWZcQdRltZZ3lEaNHGQxdvcxdFo3nSsQt" ..
	"KaHbNnQ5vi2OdPxiR+AK1VGdqoGerN8tMhqMml89Qz6oVPfzJC8088Zs2k/qHH/G+qTMOgpKGWTvxQ3Y4TB4QQa/Sb4iJrM7vZ5t" ..
	"wh66sx1i9hSVKfVpOFvicrDXv+DJSdiLcgoFVbOQw+XxVj0RtMiN1LCY7ZP+BtVCaNwK6YemNiWfrnfwKz0j5n+VAWhFmtzohY08" ..
	"iO5RJ/Y8QBebZStrXagE5LeoWVdJWT3S6yHZL95gZU+BvQmTW45xm/bAmS/8Hf/bHggnombVeLwhlGJTniFAVm9/YbGojtgVplE/" ..
	"FxQpdUcE0F+rV+MAIfsSEoGW7oUqEgJ8QyqEIR3+y2YYWV9PEBZUiXJCz3NblPBeOSsmL8LlSyhccdiM4meqh4coRkCl9Gdbfhr9" ..
	"VU9g7ignErOZhrX83nOQwH1HvIpdN/Eeq7N4zIP6wz607hRY8Vm1kE2XUDLnFvsRmlDEhlYiJe6iTuzJ1nV0SIqAJr4PkbvXJlwE" ..
	"qM4RMRzoICPmQ2bQQORxL5QA4t8q2dzT+ZXs0WlzVmm8wzk1PzFGyQZvtxYCe8pQ++Kpf4p6EutNg2uuQaQf2HXYt5Z/0EWzaUoz" ..
	"zmqw3wmRIMZERsn/J/T2WJ+lkymHSZo0wk8cwOTtgAYWq9D1ZGHckmJ9uTvxrbZ6MSza6gR+f2p+Bk0TpDVVSECnRcYNGHDdeyOw" ..
	"rOo0LwU6wgwjYv42/aNjj9ZYBIuSJV55DA9XYPVQvfydeOZc2QBwrt/ddJlrq/3wwQS4XPiBtguDoqNsxJGkxNWLuXiWoHeQxTmL" ..
	"pC8IYIicWJ0H5CXCWmfF4Ifu4mhhKVMW1dhMjd6rVnlAHqAUFId+BX3lfJf92SRaC+0ebzhhLY+BlnNaRkil9TRjW4lSwnlPSxEN" ..
	"R2sppOamlRtRSQKqqQknwN/InrGisBUI6574T7/2lbC7M4njfGU6DLU0yZ+nUzXYk0XedFGauth6/NlsfnU20ocouHqNElhOwHFx" ..
	"JfmuWPsrtO4C/CWlcm1hTlZcKwta1W685CoH6gL6NRX91iFqTImcH7eaj8T47Tb5SGJ4IoRa0W1QAihVJ2LHR+VI5F81fmjT4+Zf" ..
	"5htxlQvQLrStHYVNYGWSdPjeBVe3VH56MRHsa7ZyBueY9Oj5ThwVCOMVyRP4RPBGkr6K0Ix4JKTCDbl4wInjhBohsuEmW0uxkU1N" ..
	"4UCLAVoJi8WmNOYIPf+0m7g5jr0wqT9Jhke6W5h/J7U9hGa2z2JebeVDOWZ+wL+j+OXH1zQyFVED2zAfLli3fyGv5ZAEcTP23/hD" ..
	"UuKMpy3nYZAqM4OnzBOdzYZtgryhKbjj0IBlK2sehsJV25Gq+ssSrwuil8yoDrLfFVTJ8nxQfTN4B0PQGQ2dsdIs9mh6P58AbdeP" ..
	"JFNgDRHgS1/bqPDyVjeIV1ulT/NbbVosEOlAFtWF1ylsI01hg+e/b1JCPwwEn632AESWH6ethp3OnZ4ElqSt7iOBABsNEUW5o29J" ..
	"h/tE2iXDqkKF0EhP3AOLhSaCDyHbW/7wLcbUjvfJ8NW4Geqa6fcv0XFTGqHvvpT6JbINd4j/8E7IOgdOT/OGGwaZUeeVNJKdR3OM" ..
	"jpZVymnfKCZb+qCE+1vRXD8E46eZKIcXPywyUP7+knE+KhAJWTE9YmyJn+NEQiBiLiyWFcnajVJHWhAS7L4Wck3ffqcg7Xzp7XK/" ..
	"aDzz+wIHNP6TMpYlCDyeS1SeC0kEDUv87WlEPK9xBkYYUyAfouJAn6C4uBZg5/MqRxo87gbY5szbxz75jc00tALe/OPsyu56DicZ" ..
	"O75UbZ5tqfVP893bnQFa0rK5i8+SdT9odvDpIrbkSMTZevakz9gD/v56oaJnwrQytXpsAx7KRl0S067qOO9XOasmjX3amF6MPdbO" ..
	"4qsxLtin+ansVntC5vguZZfZugugKAUREWeg8qjndnfI4DwjyZqSbDaGAF2ltodxSkzkvAlwH0CSymTJFZitiXKB2mYImfliB2ro" ..
	"C+jX0JIcTmpwTm7ynpb9K/QUkENE2D2TCyM4guhyybuVS8WZw9xHyA/VzrWAsZND+Pz0npY5XujLQptem8uCisF1hgv+IeEDSXdw" ..
	"0sGbAWvdU62d3MkudRbd51icTuIIVdYjYCGiIR65Q+5TKePkn9cMxg4qVh3xeYi3UJNQzhCOpeRP4M4WlQlYtZLrND1iggs4uHoi" ..
	"J0AlVzXOFcNTmmDSd7HzvSy7Y0IhhZ1FQCdeNzDtanHma0gYlFcwVATIoky4uvzYMbIh8mkQQdYNJAm4tNo0e3+BuTTjpULldHfo" ..
	"4WJSecBSkIbsUHtNoXVpab2moC8kWFn32rR6mrC+eoNjggLlscIkHP9yg4cQLX3kiAO1YV/XkVhplktZNylCxKnvyH9RQpR2qlIo" ..
	"f5zCMoFIXXX33vuielhfrTWnvRqlZ0oZYA48Sp7YCxKup4RZ939Suh32+jBgaTEumi6Ho8I5zllQ/FquZ7HiAO9sqApFUNmGG6jF" ..
	"6qhAdjy/+LSkCwvTwq84b+ugmdtQJy6Xm0+H3SVdBF7Ny3f7pRpSeJnIORxm8Dv7JRnQfl7JuFIUfNYRVekx/9KF3tv6dd5lY+QL" ..
	"Z9M9RB9g22EISYA41ySb+GMV57Zr2FMDHB3QTOqsyewRVRmUNazb7jVwHNiMLNDvY9j3tCeN3LLE/WGeTZ6TEY1SGDXjEQp42+9c" ..
	"Ga+UYuo4E5hAwioIf7MuXgckE1MQiuxt6FdTdUbJUY9sFL0kqhZrolvy3BHFIYf5MIjbsX/zJwKsBUdlsnmApdBFL2E54D4HomoO" ..
	"7TDNTIuAMlFSP72dGX9M9dUujlH56C2Ba6l3HlmVQQbcPngGFcH5hsgYHJFdu05f1STBmyJeNcFpgzAsYJv4cmJ+yFzxqMt9WxWJ" ..
	"Fq5nxVJzoxdcNCj9QWS6fmfwiU+noDCbmTN8iJEbT8EuBM7vQbNQXNfhf9gJOelzfroyFWmI6BhI+ZvePrLdkXrbSoYZGHJWzAlf" ..
	"y7q+kMVJUaZ/e3dpbGyR75UN26lVFir83rgLcnOPCxHbV9KzHLLi7c3aa9HaApqzUsDKgSw1hLcIj7WlXVIzBt3gHJ3yUHYDQMxe" ..
	"gxtl9takuSk4p47ULYChltaUVDgvrD4ChfeurllZ82iUOhSgi73tl14HusoKO+tfoLeqqt9cF7P7Hu2Wnv8VZYEhWhUu4jehdSon" ..
	"EnJ0SefIaP8azj67e2urtd0KJBo5Knquo9fUuCAsUcy7qdukPth4Uocwt6mnuOhTxJEJmZwisYM9jgT2BD3y9pdV+UcRVfLU8NbN" ..
	"gKktI94jHBsdKan/LKtGXbN2eVcsmKa19W7bbd7MbvJxw7ti/6VJopa9aqO0Z1xH5zvI/qSCv4UdY7PF8PNQko5DgdIgmQfNzexw" ..
	"khfqcIN9mS9B424JzD4eKVCUold6x+Yx2SRKmIfDvml0hFmW31jt9oDIoVOoygHWryEdYUEy9Uyshhq82G7i3Kke6ZIuxHkevhJs" ..
	"q6FslwlXt9feO2shmUqqAv9ZP/67yWYy9UgHPmJiJ8NXPfClrkHVHzaVZgOxrsjY6KMnG9LD4J2auHTuuxqWa//w897mEamAvkXm" ..
	"j7nDRNXJeb1MmCnxLIT9fFZhjneQHrp4Hxy+nrr9G8cXWca94iYEVGindvxWuQ/axKWYHbOt0Yrz2qhChi6/O66jTWRCjQ/KG1SO" ..
	"Syz3/dTCZ/5RsIGG7UKYFUfqzk5dkrvtalPRU9cfdq9RavnTX8I3npRjvELMTkBpp0vguh1Z2p4ygXi7Mca2Ji8cNgs11uUI9mBp" ..
	"zBVf6JnME8q+diaCsxp145NG0aR1q+/cuVFfZ5WBFVsB2S/2cy2KeerL1bVzonOvbGDbQf1MLcUzEq+rb+wsEagsgNcAiDNirIHl" ..
	"xX8sgAfLWDrJyzrEM7XbvhSuMA75iiWK7DVbUqgdo65eYrqejEk51kV5xelGFX703AwJZFpmU+yMn7pfIyrFFZNcf9mkyPzWzo2/" ..
	"p8ho0WEU8/5z4kTPgmuGb+vJjk5N9c1GbwC8Lt7GD+qfHPap4zt6D2XpWNa46/8fP849s5EYQ7I2EBHPUVyKFzsjRz4y+R9kWCLI" ..
	"dLdb8O8m3SAOEdaT5WSJwr84kP+gSdk2ZG6al0wyuWTpWkoqJTOL2esgWYkKufz7iVIQhfTRUjxUWFvulr1ZTdxxVW9dLC+emDq5" ..
	"xuG8Z4iVyZPkhabGrzPGNfIkbJRTtNC2GeWUqY5M1ygZ+zPK+GCCQUUpr6MWd+H057GCaqeKh07SBruL6nN85KtncJdBZvfPUh8v" ..
	"6iLPPa8YKtFDNJG/w8FSlW+lnYEPNwQ9k7Yr72laxidMaGfFvCpUBhyltmKt1GCYLA6m9a/ONbY4f4bSiwnlM3EiYcr2L9bTYyyt" ..
	"JFz9IePxyGGjrG0f4Ob8R3t5+S+/uyvqgqqmQe1OYLQ1sImzqMs5Bl8sJq0dknhGnoIXLOKquK4U1xwmqngXb7HFUFs2azUl4Evw" ..
	"NM6AwuE/zzw6Iu5PpUYGZ2BhJDdf6lytyM12RW1eEq6PJuepvQumnTcg5TrjLqNDXyuRE4CVejk+NeGDSy8+uGyatzuCV81KC6yO" ..
	"FCv8UaBj/xC/qD2ipuxwcc+eJNp+f/HghPHxQiW1lq764aTt0trHOljWNkWRBzg3QstlGXhHXJ0A79R6uM5hy+ujIyhbtQcZXpoA" ..
	"7AElDWH9H3WihvrBNnzf+Dyo4RO2iiwYIyCNIJ5VRsolOwwVd3QXLjLK6KAX1cpdVcfj21aIjoCLF0MbaCJ/bGouKMgAyhAy3Qhw" ..
	"aOh6bjazlY4qymtuT587a/ceXvGj4okX5SlgjoYdmu2jvBQOSPcjh+qFJ+ai8tubZW0FMKJfBSanUK32jn0N5oHMe7ao+sKIz+T9" ..
	"NWOTShEHq7B8ZwjbqHJmA80blJ0DrgIaACOlyF0tMreUlp7A8RVQZQT5PhBPA8xGQN02WZMRUoNJJSZyBkuxRco2FMU8yjMO5YbA" ..
	"VxcwmuK44t8MgblMEacFm30WR8qvdw2oJFkTf9y3/ho3zSCb8St9wCQyDdPbHPBBfQFjLOz+KnjZO4WpOa+UovYzI/qeP4mxs5gD" ..
	""
local PAYLOAD_P3 =
	"3VMA9vwVTmaQQFTcYaVtbSSzl5S1WPo+If/e3biuTI2VpnU9pzoTbItvE6O6g9rXAvPwEY+tJsa+YnYxg4KCLb5Wym9n5qP6MHvL" ..
	"y66ieal716EPYDqmiJrzz3+ukV0+j44YJwGxkPiLv8S8A1qgOTbhqqx8+UNyGB3zCAUgRwffZgndX4MWHbtIdM9kDoib5H0pMKW9" ..
	"0B9TONVy3QCMZQ+APMrE1dUgdzDZtwUtr3Xh1wNOSHpkQlM/uEL30SbQ6UgJrSln2qLueVDT1J+e7mKR4hXWvOnBtian5wgcGm2+" ..
	"/jLGWv4tS1Rs37NYzpEtRY1X8/a0URYMvUcbx98LLjSewwUrFdl4h7lksHvVtGCEsw2ODU+uY7ochePCcg8oyW2oB3YZKvbpqYH9" ..
	"gJZlzs0HCaWTto8k4ZANqdkFO9hTaxg4xifN3efyTMEzd4cAnte+4ZWaF2C5SUz0xFJuRmQG936TjJUftKbbCrMzVGkPpi/oDId2" ..
	"FsQrn5+JtnJM8/CgyaUiaaEwB3qnqTkKBTFXnGu67G9ckC6AV4HrGX8m0D0VKXSbiY/G7KEcAmFOiSXlrbE0ZVfFYEInPrpMg9+D" ..
	"qC4Za6SIZUQPx86zc6YLPle3ri3W4PlxpSZo2YhJ0W7lJc2sryep42kI9sWK18SS3KitCt3kFlxs///5ASzNpZQEdRyt/V2SYNvz" ..
	"lBeN+S5DdWoZ3gUTMQpjX+pqoHCY9nds/jfQC0kiFCL5o2Ad3oGdiRlJ4egbq+bRfbc5d7pEhlMOzcEY+bnBjyEVp8VFbQsZGneF" ..
	"V8pXnbF6S9HbnXoou+iDzCWv8PI3J3TUahdktYF0J1ab9E+dqhe/iXNv1yA426AXgzLiV8gQR7umDxNdAA1Hoq+Y0bD/3+cSeP5D" ..
	"1SW5YGfYXD/vcFi5S3c56frNTEa0a1TUySTzkSdFQfJJvf88JUsZUKfGKp9idOlkLeXJ8/ekQnRpkLY2XnTt7sy43bRSdnXAqFUp" ..
	"ENVO5xktapNnbJmz3jmlHYADBxJZOc7dV/pHiJBNsWeDuRghaO8SdS1ZA4OQBrSkaLIlcOJ1EZsINIPBGP8Hdcebb2/8DBRuBbYw" ..
	"EAnDMLdZw2QJcp1MV9bkmWbx3HMzuohoSrbupiPDPlsz42I9vAJVV8vEW3x7WfnAeYxCYx7TeKko1Mdx21jg64vMfFNUYfA3uj15" ..
	"qzmiRMJ8Q5LtjTwGnoDDPZoRTPIsHKeBZGwIkm44BuAGYg5ty1Ts3bPSXKqT3PiSTDNv/BZYjzp8q8/yUOBv9JooSdWnBEUknt+R" ..
	"eggRhMDq8HZI1ENWxwjRw96sSiApcyjpxRiQFdw+Hpf+C5ArwtUmXMd9H4QwYAm7oE8+tjkpYc5mIbGuVPIDq4/fD7WsyC3Noqvp" ..
	"7CabYkgPkp40mPNaL3sKoD7F0tSVIWeBTaEdyceIEP49OtHn78Pw8VzQ60cBr5OBmWZjro+FwUySUaRWm8HRSXbPL2iDfdDOraKe" ..
	"u45xop3Atu6ckhsooJ4s2gGkzrXAIl3klCiklo+oy1IrY5ROASM5EMADeQE9Ha+hECLMGNe2cZd//WqCKRqAJN8t4mEDRUTDjLDK" ..
	"b6Rrh/z8gSVbrrsWQ9v4a9945j2l/EUWWhwC0yYG/uV9O+nuvfE4WDg1yrP9pK25sbavzWcs9RvKjgd8ziCXOdkuTX923XtZ+ISI" ..
	"XGhNwwP3j1b8xk5qw1sGGHsF4RGjelERB+TBH9CK07MrYSDIT2+U6ZwR2LgP84//cBUvt4YUcoczY5YlRmieVP6o0+crINuRV1Sw" ..
	"0G4OrykUGcD3UOLBhwLXp54Si1fjRLM8tJrGdkfiyRbMkZ5z/aBDJVQ2HsSgk3hYUvMShdIKOqlO8vEEhSIpt0+YfTGG3Kde+8AU" ..
	"nSfo2i6TyHovZH6jS7wcJzCngyPJfIiBSxjoD8EkS7z4iFwAQxVZBIl7fYWPOEtAuLu28YqQqJLIMMjHDeCQwxr9lwxSy5FW0unw" ..
	"tvKkJTDbgUQDUJ/w+7mzGOGoV6lXU/xqiccn6DGoUOiosGsxc/zGSz28ZhJT/f8vBZsj/wf2AJuYIB68e3m+Goj1KtrU8oVbQ/QP" ..
	"qqgQ3cjw8CSEJodizIqOxgwjF9KhBMEckxY9QdPxKXQtZ1KXWiKzALd6woE8GdsYdyHceeE28JEVCjd9fGjaLhcE7cJC3Ie7LqZM" ..
	"2kSM/YDH/q4H8ODBsEC4V+cAfITTLcFSYAr7j8IDd9McEHDqcZHEMrsAJaRawsbj1a1h238MXX6P4//MTeoNidCWGR/URNhIsX/0" ..
	"gBWxchjABAV6FLdceklEO+59U8wVczW/E9BCAVt6MllkkH7EbzMCGi+PZOWNYJg+YSJF5nsmOCltTcZoSQlmOesSLqCCeWbvChWZ" ..
	"7sI66cIBIUas3GlbHWu1j+U3w77t++SJwihmH3ejv4wnKdIs2kKeGbazPkWIqWO6ea8g3h9BkXg+j6K7ct2X7s7g3UPxP3Ow3h8t" ..
	"oSrH/JGAKsmTkr4Ubrxent5RZ3lz0BP2JRMRKqAxhWYjzvQR7VCP6KunKFjfwCNMiozMUuLl9IfNywYLE+uduZLNFZx3IPK/hvPS" ..
	"DqOh3MHbijwKlFpxV6UqVEZfSan+/RtpcK7mzEDaPdWoHy0M89lO6St4rwUknQZvX5OuovbRr1GcwsxGRt1/2AvRkBCv9cvt2mtk" ..
	"SHA/6FPIjf6bAsZds41mKqtpVgcGHV6iCr9Pv9DB06f25STtZxNAeL92nTcoVyO/dXvYvrvhAwtVxhJH6lBe8y72AArvqy34/rLR" ..
	"NDY8KGKutc/BYRRNWH+/NPn01tnvEkdWAQ+BptZbeX2EkfeYjac9kL3iKujQyb5pmSojC3lVCGVhcBjwWQFl2oD5oEHH7noimRvf" ..
	"wKlY5UtCkta+mG4waX2X6ToD1q8dbo4VSNi9NzBJWPXRZukUMKkmcPZz+UZgiALsw5Ps6jBSk29rD7oNhhIVf+cINPSTcByw/ngT" ..
	"LrbXz21T0aSiFRiAw9y2nUpDscJZ7VWSl2LcE+Di9ahLFHIW34Z1Lv11Ttdabuu2vPKTYWXq1YYRaOZtwH17S9+MsLRnrCTh0fxr" ..
	"i3g9sQdVfvj76cS6/jv24LS6xg5CEoIMS88OmSpLBAGjCvsqD2SFN5JFbzdYNNmmSh5mV56cDuLAdWKxj76WuHmc+lj0H7UuYNIh" ..
	"9jUlcDa5mPixojrBiGKjTZz6LDhbOV0ueTUx/c4XgJm1TkH/BMHbPMADqXPokq/NtEjFRTA0nl+ndMOJ7pJkJ1qg8twKR+2QzKLC" ..
	"mDldTFBjvsSCWZkJmHkfNY9hisV3cCyPIA9jkryJL54U027rIAhTQrfWxa18sFjEBPx0EnfiS2jYvhxoeLDzDkU3f9Sv425eAM6v" ..
	"wsMNCczmch6bR23Td3Nk0wGSS23ft8A/QAakkBP0LJ2kpjFGksn4IR1mocbzg5sjioHDxhaJsHPx5dRsjYH/J+tKM93jQlAfLPrb" ..
	"4h+1fkHYr5AQeA1c8y00VxhM7jWc7dJyAlPpBv/MoFeGih9+X2QXZ0u3/SmbYc3BuD2eaUtBcfjfzGnEsGrGvLmmPq+CEwGl7Hhx" ..
	"j/k8ho/3mlsOgDgr7TDY8t8srPYmraoFhrkNzbAhV2e+JxmH339kRfpe9chvcvh4kwFkTitQVzsf4Fll9da5TXNPrZnk9U56iott" ..
	"mB7BjeiHcfVHUN0BpWUr/lsWnUxj7CYBq5fNeAuHdG5MrQu7NFROl7KrBYhiz/hImXSFUSDsUicnUD1PqTFxgA6pKzWRhWGR0ESK" ..
	"pdDsfvb0s7nckRc/4Boycyt0jmn+kxjH5yuGy9f3piUQymYjvErkmnsCPHnH1JdK6A3w5gSkBfp7NTfcNnpdz5MudA5vkOr9jcdU" ..
	"ZU2gTlea5FPj0kiyATYMYzsj/JpLL6l2NK0pR1dOmk9cprGPMtNTKbS677bzw4xmkbh2aKfYB3HsE+7ObWGFo7qklj2T/lZruI8/" ..
	"6h/guo5CXM2JeEx7W1Us/379+Ol0LChBuOA6BqH4lGaxNFkt7fAbkC12SEE6PMVdefBYlhgHZEo/6684dUbgAEoI/MrzireoIATS" ..
	"sEBzeA6tg0RkoQhdfbC/mUFu3ee5bt1SXbuU01Zh+3vMO7AqMDmr0vXjmCmwORSaRGUE6gvO7WRRD4atDnv8gzDwIsz9sSWmLoiC" ..
	"Gkf+oCuzo2XljnEkPmQZelpbKtauq0EvsKeENvvuNHocJr7BSGX7Q3I9Lfx8KleLPOLiIL7VDFsDDyvlb1Bp20mFbHnAM3Ibq33x" ..
	"NKx7gLuevztAYLb/o8F1yHKv7u+DxCC2ixh4q6FoSdvHKfnjTPZ14ZByj0zVwy0mR1R+NcKMrMUxKOdW+GUCwTuIHi3rDT8gA2rI" ..
	"DtiYGHtua1CtXZi05XNUoOLm0We8Tak9f/FWiRAZ6y0IjL7ZDWmbX8Y459+773GLpTHh7cddQ5vQ5zuEJ825TIyo1ki+MHOVhL14" ..
	"E9PpcDJDIMu3MkhffpAmtVZy39xmcXHFStGI6iu+aSnm/H1bnX3r7U9bKz8gvTPC72AYt0EL78iB5gseLme9ediEQxwYvrw1CTQN" ..
	"E2gL3MHVJbSbeQCQ3FWR5ALxLmXncaU5Kyt73ARnU58wd3uvDFDyotDuZddbSh6t1GVJDg4fCHbzdPRTPNXFLy+atNejiv1rY7eq" ..
	"G4JDqIB7PiunOq3db6wbG9u4Tuv+dn8jUyuMSuNqO9DZ+z6fJwN2UVo7pJ8NfHn2I7mVz9RmCMnyqYTq9olVjHwJ3G5nyJK33XIG" ..
	"eePNKnUV3hwTcXTPFMaQS5mUNhTFeBUBXGVI3r4Sl6EFiotPrPXfciXQqAYv2gky4hWrVMgRWE8qWUnLX+PpXBeRnf9Rd/nPMLZK" ..
	"aH6UrHVqHUYWncYoFKP02Z1RsviQ26ZW8NjwYWpAyd4LdliHL1pLwmlfG/kRs9dD6hDcj8wYAMdHvEwisEVbNBExIprbgEBdz0HM" ..
	"FUx3GNmhQRJtamHoN9ax5h7q2deCrueZRC5qJTpacrOZdi3fPwWibGmNJzHLYzQwySsRJTJJ5+mQEniOrAdCQftB6munzpKdGudC" ..
	"PPb9NDn6FdstnNkuTGs9SCCFKhLbWLU082IkHvfYgZ3SgT/C3DR7Wwn8AZeWYpOhMt2+j3cpKIQlPMwFhT/rvL5wHIWdSxlDeiX/" ..
	"csTIo97ceLZRFAzW+BGjSIjOgdXfJxcfzV40Sw1o1/dwFZuVg9Nc7WeMezbfBN63hAE6mXbMmsDupqppu/au4ZxKaoX/KIcZgA0v" ..
	"77Z01QHRruUTml1jgZ08uRyJqUfUEv1LjW4ydRuLA/reAu8IKF/5XorrhteLkOGL5pM53ygHAS/BQ1HRIToA/sksZUQaa84DbQRr" ..
	"FHHum4ZCcyVi/2mMXILJDAikfYOUuqkwOvjTwpMOqmb8hxYStYsD0wcCytwc84KSuHIieFwCSVksFd1xj0qPuglju4TrtJ6YW5VD" ..
	"RH3Oh5DrtctTuSFDjoO6KnVRxUQh0+DS8kgFJ7aTQk6oSBcq2a2BKJQ05oGhX93+qItg02zFoOrZ2Cc4bHU9Y4cKFggv7EmEQpyT" ..
	"7wWt7jnwPBSLDKpyEleoc0huGcKrWpWJkVwILEAoAmh1IenX2Kp3kR6/1tg/3EJ3eAy7TC6FkbVh/3EiKf+xa+u4jET79C5+QYOF" ..
	"DV3gTmlkIImPXSMFS4wa9yJiv9O/Tml7ucQEbcziJ2Gol0h+3GQIaBnH346GG2TniwbjnNeo+3ErQrm4+DIzDOq2TQtZ+21uLwPp" ..
	"u/99ZgYC/Kt+45qQk1PZAHDSCIYmmSQOpCYfqR7PS1bxxVaPHzCtbVYblnV/T7FBMR5clvWcsmaE3ulqT49gE29vIS8U/iSS4CBu" ..
	"XW4N/lMSrRQVsi+uMDM0hOjPL3j8J49Vh9vg7mcpkxgz4VZru64YBMS/VaRjKlEXCvr2opNoiefUH0dl8twFW07tmpRX4ZkTfQNC" ..
	""
local PAYLOAD_P4 =
	"tfCMzuxkaJ/jmGU0GWUUTcVI6jSD7BJRLK5YAoiBFyKuBryyKUDl/teMy9kcPvzuZSmDrwdPA6z0gIWxWdYLT5bGcvnPy1dJNpHq" ..
	"gyIj2k8zZ2kOOc4q5IKlOcSdmADWI+zEQonV2Unq+1a1n5lJdpYZkf77HvAvJ3p3femQk4rTSTTw8bH3mgeLbRO7SRHXx+Il7sRm" ..
	"nCbbpuaBlLthQcN3wdLN5lbQTeW8gIcjhX0tlTG3yJKrar4pgUF6tG2Y2WApgmoIW/9yu6K4/WdjOVfo/SkcVleGe9IsTUa1qc7S" ..
	"tjkL+ppirbujQwJe+ml1v34/GGL8kPK5Qznulj2O3DDbQJpko+sX6jZQJdCod8m+Ek0MUNHhzi7IOALeypPbhbHi5KV/BVysKO9k" ..
	"pHkz2MlIHI5ui+zINzNL3yW1Tc7XAFsJsGgYpY8SlILLMEy00dqalT9Qd8ks6z2ygjxq0Bf1K9aepM2UECryxhjutW0BFgMQRBPP" ..
	"1iTkaQZpS7ZMPSCmrSo0oQE7M9G393RkyPA6Q7f3DP/j36BmBKUJ+4VDEr1ECdS7wg/WPRTaSthTi5BYnGNXJpcYRLVHVs5DNoSE" ..
	"vzUk1T+WsmzAGrUFKGI+TmMzX5ZE6lDodcG4eAZcQj8YvFTayOfI2B46wSr/cvhHw1Y7zcdafon7hC9PGfewA7koYL2+bCUnbCVw" ..
	"2Uv2EyKx+/LHI3XKFgBA8pez0cTKPYFVZ/DERoIaIEBthlbG8TfGfW/ft+PZUlR8HjnjT4DrOqqaHfdb7bWb6vgmFP6JHFzD1eiX" ..
	"xNA/cRfVYqVaAEEDv8mBfijb5pWxLEBU3NOUAeH00SPfKHmTl6SWoeX3MT0t62oQh+XWKUgEtF9BQCKngERVy37hgWpIZXqEVvcf" ..
	"mCmiRCzNrS4Eo8ZHaLqJ28ldqG+xVZ0gs3TUJwmpxjO2RiGt/1jPzAihv6ngDMW37YDgyJ3VWKszpwjsQ2X+dzRQxh/CUUG0vys4" ..
	"+4YVcqmhQ2I1BQx3UT4RJspCYXQQq+Un+IqPs+xLVQZnaNDn5+GWCvd5i8nkZeqUgkAzrH358Ha3+8zMGqC8t9dSjsm0CzKOi1SK" ..
	"0ACGBtVsckgfAjir+CNV6dKwAOfPcyWnxJUXXW9rW4zdPabqnkEf4JrQl1DYfjJcfYvhfFsffBW9+tNjjnnEIVXB9E+AnBft0nSY" ..
	"iqJIndkIyBkdseCMvahjTGgZwTX00J5I8yeBR2FjWAohSl520rVisnAUWeUoZeCuuISaqGWtwzWl8Q55aW7eKy3cbK722k0NSFHL" ..
	"PyQEo9hqHg3HFLJuQU+A3YF0vyTRVNpkQJCwlXOUcyt6OmcQiLHf6t7YszclW6OusiU+EiuXyjVJ7M7EyeFifYAiMsSXuikcVA9E" ..
	"iJ03pRgj0fYRXnqAiFxiYSfwzwkeSyN7cDaJQyR3SAUFkQ1I1BbydWdDCK86jMUMAWU32mkX8NblbQIFw0sCTP9ZVUeTpp2mI64w" ..
	"JfSH88OzBS49v6rcMzzf+gCQ9HIAcwqWUrYK24Uu7GdJ3oP0sZJc3wOz7fNduVkGsyLdwOz666HOYyXP7oEiHs4C9MjT1LYEVOOE" ..
	"xr74qHNLVeq4avPCdy74BGQSGOT2QG/ERsusk1bDcJzuuAV9w4X8TtLG86G/INF8zftrGP/BNf1asNhA0NMybglmcLBI17uP4ko4" ..
	"7DWdV+o7HiFrY8rbRyqERgTCicmrt3Qe2TQtPFOcMs70wS3nJourVbKpwmNKZ4FkfyX46csCvPKDSe4Bu55Dlcs8r891CMlzg84w" ..
	"f8dAkLBGrujXBGCo02v4XTWgQ6p5KWAD+NSYpuy0TjJ7vGJSfCqVyqqLouJHlHy0hMfSS5jm71YjQyIpoFPaP2R2LeVyiCZseh7q" ..
	"s9kumvikNptVRX8ssYINhHkbRY6rBbivGSpbQfxviOnS29u/X85S7VoNS4hozSwlAanERYv7Gkr77ht6PC+9SYzqyA7XjA2vFuXf" ..
	"IIbkCbk/+bRT1jGjXP8hgYrOr4TwT+wMYQewJMPxCugTakQEEVLMOpn66hQH6oqkjV8HmChOOy+gpGdoIto8IacHwXOdazZRQDQx" ..
	"8nFSMmlnnLEHX8xsqhaoOqfvFotHJn39XZTnNwSOoQT5RHuLM5ul342dYTiFDHX5wPZzhxKfhQEwUSsMoaDdKTsv912hUSGJwooe" ..
	"8SeLw+/mqguhCkWRE6pQFnlEfVxMkrOiXbavLd533KzNYBh2FiGkXzF9Yve4DRObQIEi9w6ZTOQkVNNNIt+ivGThvhbDXh9BPtIB" ..
	"YtrBqKfFIwlCb0OUE5ClVkregl0BsTSZSaNNLjKhlIwrx/nvML6M874MGyFFtM5r27VLmoBhe/Tw1D1GFUtmxYyjh7uR7rry0WPw" ..
	"nYAtEUdnxQ+95heZRqpgj2aNqp0VvCeaKIGa+r83vVJ2EuBwBYnduEIT/SO56xvwOceq1eCpuEkbvyqcnlzPUHqkf6tjBhhsqUDW" ..
	"jNE9YtIrd6WzsL8EeS+/mn/Ugl8OhnbeeNKezb3OeCmaG0zwX+8tMJnW2sapvUl4XWDZW2fTRvryhoIaQx7jukhMBmyz064UxiuQ" ..
	"zBiyv2zhJzOz9p57s008Wmob4Y84SRzRL68VvF3Q+aMYCiubEpZ473L4ECp2t3uaJxU7K9tdSLRG8l8bmceNvIu/XxX0SlJDGjL+" ..
	"hu1mq3fgBrJpZ9fjd/cvVHyrbrkBZREyok8mn6ukDY6hO+WqDwZ3sw06tmh02WiiwJu2T0FcGIcplAHOiSha5x2zGE3GXUtQnOAJ" ..
	"fSDnS8fkEDyWUDufu9QGcZUwYsjCz4XBUV4LD5l9W2fbzdTfL1t7lmJjuSBvxbyOshBe33wEUM4A6sIm6yayTWw5GSj8tGAvvvl+" ..
	"O3hg28nAUQkBBS26XwH+/Y2M7QVyhtaeBZufUyRBEMXxy0YbYvuJ5TZ0o0ktIJh6E+lLkUVi4v1P2qyENrT+zdOiZsCd3+jAe+n+" ..
	"0f2D+GVu7GX/+2h1ibBeB308nu3c+fL2o3qr1pgnnROAPd2Kq1M0pXNA2oKMA0f43iqkj5j6BLIV0CIbRX0DUBFP7mPakH13ZaBD" ..
	"vtAqxCrgHZ2qDMEjwYK2Msu9yeStpAMpYqLFGh4IZo/oYE0saGS4J8oZuFZ0bFRZvtCNIjBu91AnUNQlzQCbijpIHtT3LQccnz3x" ..
	"2S1L8qo6jvr3o+v//uH9K1psXCDawop6F4JkKHJvHYxB6YxlauKMpQCIrikz97KnKwlsGj7sT+TpOd9IGOaSe1creElr5nTxT7Wj" ..
	"qeMhCBgjX6hb8dFZF2m+wUsqJXJgSfydZZJv9tAIs5c3d1svk85fxoEZo7rhEDtWamQNWuMkbNNAqZC23eDYsorhLYRTZd4KTZ18" ..
	"olXTiaC6ha053PMadn/8WOeVp397InRxJjuvUFzspudfc1xYBFQKOYibK3ORtgg+nnfyJJLawjKnbZb4HqeYiLYejknIvWaoCAgE" ..
	"Y5tyLHN1u1stUJVMjPgcsrX0qPzWqREJ6QA8SR1v7kjUF6ozbJAxJ5dQ50XC84I9KHcCbmsLicOmSrME+FySKCBFTTDpaEm+W7sW" ..
	"ldUHsKfp46rirhVWcVhmJTQMxt8WpXH8q/Ip+zKq3BcGykhK/49m8LHaBs8QY4Rsl7nLl7rrR10pSMSysP5gk1iKpCYNhLHf+9oi" ..
	"M5FpinBNVsW+OjU/C45iwrKiezaTY7uPU5OMPcgj+JI2fZ4Jdx/7WqJNXSi3z8llDreiX1NaWZBJxxd7hd2QQRGLuTudr0miQjZ1" ..
	"I4uME2a3uXh+No9RbldBH7QpYL8QMChaTzJBy4hPFsl6Zfu/HOKAI2YtkY4e5H7KRxqrc4OS4aBUylmlva+TG05w2ur5oV8rLgty" ..
	"/FyO+6hz28pzoHf8iE1n2IvLgGh/D4bjgB+dSJGedHoUrMNJGgwak+M/SlSSvpypv/cX2tKZJcFQxvbnegk9xDdNl2QRHeceNNRY" ..
	"GzTG/n9Z0CE/FKn3rdidYy4TVt/ez7dQ+JKp99RiQqaQAZYkFoXSJLM5P52UQUOAOux8hxmsuuIOh9WtM0vu+wNX+nWcLlhpHETu" ..
	"fDUqh0lWkfVVONOmFpeZIp6RxtRNQCkRr72jM+RvjNm1VaPgzizlk0531ATpR7tqGn/ciQIp0SOd+sQc/mkETJH7u/2dbvE63E7U" ..
	"M98nSUYZLccQo4Orw/aNlz+BJexYQqIn0+Wwz8AARRetOAQQamFKHZXcBTNsEphcnlIuq/NLmMmV2Uw5B0qWEjij1t/iNrkCM1kc" ..
	"aoOuqGpq3rmmttbX9YTqOhlChQNdbHuz56p3FARBG+oRoOOh0dwml2d6WOsNLll8HmbOF3bkgaso6g5NTWWVgDX0hI9B2c2UeyRz" ..
	"FC1hoCQySVFmfnJPtnW9VVZElFN3y6y45JcqyeujlLz3uosLaVI3aHSzeyj6MvbX8YcgQMs80d3GQzhVtNghEfu1S5br2Ts8ggcp" ..
	"XxtyEiBIRyOI2fJfN7IUFeLEWkCpbTicLkRxkUnwXD4faQKDQK51wYRTpWsEJNO0Ya8/eyOdueLksvowYJM6U0wLTkaj3bWZRezR" ..
	"WPiZm1x5OHz1xXGApBLVceXgDaaxdacp2B8fIBYKrpyelAzS8BGAjjvys3PWGVstzDY1Yi7OUBLcenJtEFcT3tJi5L5bpxUox0h2" ..
	"vpoEHJJE2g2m0OgxB+arqXE84mZIKO+VEqEAi1JdBDSUR94io6i4LjBvHvXjKcLfpXsAhuT0yLvXsx6s8AyDdEcxI/TY5522Zdmo" ..
	"5ynMVgQ83K1Dxyx3Dpj8DTOU0v/c5IXNVAAoOK5EgwGjefNAgx8EvuxJCUREyjaZP4s+aPMz/ol+SE7HiexGFmeoe3pHNCzX6MBS" ..
	"6HQtXymoiAr5yZXPPH3vkEJJY49ihc+Hw8f7MGAwXS8n4JEoCBRQbbBYdLEoGSnlr8IhgkeBDfem4QVlu+6Yae37V/AF45z8KN6s" ..
	"OD+4BZRgc71TqUyGvkcbpI7Fq9NTLfuiDNzMSnsl14DYWvJDUE+h6qNNp45ibH4HIN0/ZP7WaWGy2nvNebS0JcJOKFECQ0b93AFb" ..
	"ppvA5p1BQS3TOojGonuY2dkmugsMgMgWI3nV/78NijzQzVm5jV7FARx1/pBKa4yvWJKvDL3HkWjMiWp/a6OROXSop+a5IgIX897U" ..
	"dboVG7XSd8bTT56N+U7f/713Pakx+HyxhjaC81ttyDlM9mR9Jv/oDNFREdJKBsKKahK0/TfL39WAiOIBdupBsEU7EungkpXBmnmL" ..
	"r8yO50hmxbjw/OBQU7Hx34Y/Kdrp3V0hjRlAXbw4w+wXMBf69g/AYsGgs0TdxPc+mnULhKovWt3kLi2FoYwjtt1f5WZv8lHSOVFD" ..
	"v8aQXVMQwaCysBf3HYxmCs0VvRms4slgepQUC9dXRvNU07TWgkB2mBSJTbxlRj6GYCCQLr3uymkLn1oSNmwstezw9j/UUVJ/Iedy" ..
	"4PCovyUdIG060s/IULu+LHgoxdVmoC2yPn5NzqYeVyRlhq3SWSG3LiDtUAF1CUII0FuntDCWMqW352QFoS2mwtu1jBJpPpLgkhzg" ..
	"gH6wUxg3i3MQclEFLR4ZKs07tHFA1JoXvQGzOtk3J+MhSnd9EpR0Ipsae99QtmlfCJXgy8NdS9LuQ3LVrNtuRBy9NvTGJhh0Mk/v" ..
	"92mlPtaCC1t79z0HfYy5Jr0Lgk7QKrHgvdgmoPn/A++aK4EsrpqdzLX/s2DDgkau9MYbYR6SuI+cb10gOnKgEF9to76yfykVF7t4" ..
	"JoFwv8Zbw40R4Jryq2vek7ARaBwprvZbnF1FDJOJNznsj0dAyRCDWC2x8g6lVbizYOm3CODU7VZay9meuJrUbqrDIKAPmmd6WzhL" ..
	"GZ8AwsZO4w9TmwSxeIj4K9zYB0Uv0TqySdAIB/4iPW7st/3dv39mraaVz+zxlb0jUXbmjo390ry6i3qTGdFnTKdxGfApQ7+V4yEN" ..
	""
local PAYLOAD_P5 =
	"6Bu+IfPLEaDaNncVWseoGz9M9EC58JJH9u1vWJXKRGSYrdTs3EBTlSx0B464AGYxZVymcsde613+7HSq8NE0XsLXMlD45bVA3eGe" ..
	"FnCXpPi5XlnqJCLB/yeHctCMhMdWKw3C5ZU/9wYl1Egs3+guYaeHCVCqVkHc3lYA6XrslGYmQK3lhXyUJ4FKp2EeUzUrBwBfsgod" ..
	"1pkmnMNW5l47ufewj3U3kkr7ik3XJTfy1+TFIurSaJ+lFmCNyhfBTq4GRMdSvN2DyI5wkPW5V+q2KQGluDVy+fIyoYcyET+Ye/P7" ..
	"OzULRjQlQ/x2zhS0DZDW0zKpJI3iIBRfR7fKsyu3/FWV6lA6P0V2SRRoBxbpze76thn7tRNV4u+Tk7zT2CM9yJW3ho/y+VHoQURb" ..
	"BIWHblkP1dEylHxZCORhyLm8OWBZFXePJEhW+hxA5rhNdi6oDvxrE9eAT/3iaIKfrez3VT2hgxo68YxZIGci2AqPJa9zH/PES3nB" ..
	"z2K1ZW4ViagIW4r76FZPf99O5wQecUOwAhz5XZiPbry0IxnowNJoeFX/sgJN1wt6xOZfc11LvbgfC+G80RfqBF7Nh6VFDeVhMKuC" ..
	"o4191xpfelx3rstvNgRwj0Y7GLqgYWfYGvRYtNOcpycEnz1Ocbjbw025qk3xkdAHKoH2hDbJIiOJmVSRkjqY8WV4a15f3eNoM5R+" ..
	"URaTDagamLdlZxuVDC0jLgSu6sSoQiUhvmaK6ke4omFoW9aQWs+Y3Gg5Waduk+xIYz6ZCuYTnx106vDSmGZQzEpuIDUEzLbZXB6j" ..
	"prKhAFpL6HJ4+a/wVlOPsyf4GQHEKZVFyiGKdzj+He+r4P0ZQfGd6pIyYBlxRkUgjZgZbx+gJRyuE840ebQbwG44p8IAgQb4MKIf" ..
	"VH4bZfC/Rku+7CduhKLWTtI1dT6Cd/aKtzshDeyUkW2inaod3ARUsl84vIyuuTH4FQjOngTrwMZOQYwiE8Z2vlEBlkHTpeTAZkNl" ..
	"IeBn1WxAa+orFvVjUOzEp4bXuBVfasl1daCToaJPU+o9+8J8+wJnBa/xI5/b07wk7qc5fyNdwnbXB64g8dWjKYHAI/hZmuMCpCiD" ..
	"/k47XnYQQhuCX+sBpTLPsz4SfyqsXzzqn+U626tsflsks+hYEYiELB+Vx5iYNh1iSVqye4t9j9zUicjDv1EhvUP82sh9FHhDVfg7" ..
	"LHMm1R8pv+l75/dYRO8cWi1rfDnUKGktpf6lyWkjuzWzlbJjWiMOBu+c3ZykEV/oAbU3YNioXxHcRvp6qT0o/wb/LXjic09bT/Uw" ..
	"BrCkd5jBeeyNjZVGGp60/T6zG/pQjy7BFozO5Bk50HtMNF4zAXb7vvxx5cIg8MgZ6wvkdhLhJqGUHEfs1x9XifjE6F/pNwTrSV6g" ..
	"A4Od99htJcizh72h2DtQ0Q4qur4SJXBc2/l3SzCwIrcjHtWkuNj4d9p1jWVQliQZUyicdm/ciUCjDLlb6sDkylC3VqW4Co9TJjQt" ..
	"I+u5z089SOyvlbBoRRHQSCPU6s2iD7KbDhcq/tGhmWFPidevjvfxDwmIV7n2q2lg9+++gdQqDYLbdYPqiFR+6WWAtB4qqKdtooIl" ..
	"dUuLP+CFliT883mxptMXrxLSN/1WFjg1QbCPDhITxteoSOThK8D9/gApC4aBW1jgVhbYdhpgWruXdHoOR3avqALxiefxIcwJ54G2" ..
	"8cl55YxIAz26gfYU6lzu2aHaQIuN01/EX1SassLj/MEQ0YGnv7+7ogcBGbkzmJIvBNGzSGXIZNBROvrpp6cyTIZorvn4hOQ+9k7V" ..
	"Ig/Dm2EZm9Y03q2/rcbgFuyIARfdv7HrTZXt161GtVk1ay1QNog4yF8IM5n610wH5Fq1FiZnxX+KlUNh31EcPvJ/o3Gyn4nK0a4H" ..
	"EbL7ix9T+p0Kb8+8YX7yBK4bxR5Ls37QT2ktwkn+XcwbOsASN6cHTCp6wuKclYbvP3yqdvDqblozvdV3iARLAfXhSguKHizoOHbn" ..
	"AFg/qfG0npztySAyeb8GIWJi39w6vmccBpFgytrllXOXJZ4pcuwwNL9Vav5puR/sd/NXFCpiP6u7nf7m5EocPLHuydFuFFMr5j04" ..
	"KlAraX51EqHCXvYRzSDUaVxNeSTiHji1d4ut0j26N8EdxufN5vczceNanYlFc1uYiNjUfuvve1PfVewhqeHuj8OXhwSZ6Ob6meXp" ..
	"+Hdb+MCqMXAfnUbTcGiAkcFoHcw/Mb85ozbafidU9ITEaDUcK4CQS9W6ieEz+5B24usmeYnhxOKiLM3grIkBTYLIPcgMHOMf57Er" ..
	"1GYjHxMRWzQhjFzkz89zrBLWVDAFJfsA3T35+3Crg354RlJ1TKzuoSvLQleX3IL9VHh7yHa2e7gKBnWqIj+IngAAJO4uY2e/xXQA" ..
	"Yw81OWh6Syi12BcJ4exrnfoVRn/2z+61jRvH8quz4XZfu0Y/xYDTWfAImSjNcKhzr7H5z0iSPVOol84MWnBEL4OXmZuDUDJ4xrzl" ..
	"INMTKdCaM/mL2FtyDhwMv/gyQjI91Vd8HYBDZTPE97EnVCPyqfB8WfxpdYFT64QYtJoFmhR9ajQFsSi3YC0M5KQWJEZud/6O7H0F" ..
	"qqjzcER2Tq/1LbYcKoIoeuUbhysY5Rpq/EFVQ6AxwDXlVbDDHzVa5KjZD33tli+nf1kn5rRcD4KdnYlhrEht3GsctM7FBpFwGQ2g" ..
	"xJkqn5jq1FTOA8WNPyFLZ64sGt2SgA5oaf6AjEOuCiZyVr/f7at9DElXyXGNikJVtaTEs5cj/dXJWqS+0WjXyHchy56ODyyRF65U" ..
	"WS4HWbaL7GAsuvckO0djpjOgTIs+TQQbrF/D+ZI75X1CUnJdesoU+iZjyRMJZykRCz48gH4tRRlH/34Zp2/LaenVlinAg9+wPT/g" ..
	"N4UQMfdw6SVysWTUymjq/KlOIlBM9f441M1rQhc0mlCf/G1DLu5eWHeWGIU0hh/ApfjXOO5VCGEEnZZwAuxpEm3fVkxt0lHEbyXU" ..
	"VW8HwdnY8cEULfWI0kOhn68BsQU+qKX14bGPdtefhs7ggMbPoL5Pr5vaFqLxdcyu1KNCBm1snP1RqZS+dMvbs5ycuqdalKDNxL+A" ..
	"LPYoIoMTQPeAGvgOn92omRYnM6M33JXN7upiAOMCjeYPlvyXg34TxBOBwlGXetoMBtyUmFKy3RadrlQGxf7Vn0jE80kVwDgyBn9r" ..
	"ZoveaW3GBSds5BRInfavQxa941zn9uRVVCHin78VJQZmy6m5SfHwexTBTRIdCkYngTEGq9SxNsunsM1LRuMOMoi0aFGa26LQcsjy" ..
	"29WRxCqxY+Pj3msVsf2arUAQlMqk6qGcQDeTiX2Xx19wTKANPaCqYIAGNnzvHpmod8xspuWu6CudMLEEzn/JC5+6jRcu8L7+atpz" ..
	"ZgfrdsvgZ27N3/+zforchOAnuiWazmVE/SvQPpbXdPhSMnSyNg//UeXlKB/ClyiP6UYs/f29K/D9JOP8eFSHWU27csfQ+LNqGuv3" ..
	"pgaNLMZMXfr1ChLDE3yXUMTk3hY82lCJctmJSbf4blG1BNs1mooOcTrrSrrx7VqTxMddt46pjOl84JZ4JxmxV5t+4ou4T8YS4eA7" ..
	"/etrxpmjCXtYo56Pg9sfzzmc96991PYkT7LeOQvpcK6K4absIUGhzsCa9JBvpXqCMKoCoGfW0qK8eRaldWfT3+bXSpHVxRBC9GMG" ..
	"oEwqyHDEscTgogZu2UU3z7L3BTGXI5WA8BPfZQSOg/8p59qYTDjsVeOo+1Fg3HwRBQrVl5V6BqRgpRC99PXtdKYI4kTblT+COzFZ" ..
	"q+1BO9j4H5PZxcF6Ztqw6oLZoxgVHCzaAM+qDZDk7aCcBnFLlvEhVpaTpZVDKhPL7bvUkYS1M/cuvFRPPP7B65RNJnBnDDhNiUpW" ..
	"khAv1+4ActuA7chVLIm/b4j9it0ILXBTh+1gYWQJRv4cFuDRNQczjRbTkgiCiIReT61sH0QKlD5IIXUW9VTJbJvyVIOcLakkPhre" ..
	"wx/anKLVUML6Riw9v0UzgWo54wO9JMnLxTs+9bYdDRqZrLG34LxC3Srn7gDv21b0hQ1d5HHLLvgPPb7uaAOtoeLlZOS/I+E7shGP" ..
	"90TL//lt8EHBeV76B2ZZRa1CfzZzWojs5coRi9amJfVKUTZLt4ydJZeI2q6oBjr1PYy4Ka1y7/pJLeBQDPj6K17HAJ23EDNWCNWB" ..
	"YBSt/grXpWUT9JcMdfnZ+fG3qauMye9xGgyQQE+1rp/hWJjbB2ywi5wAKY/lqoLSVuqf10EQk0cGQ/s5H9I7to7YKfEQ2lVIWGnP" ..
	"ad1uMeywDbitbWg13NPQvIpPV6O4O2if2VQe0vUD3iUaFLpJ6UJgHPgwdYjIB5Tgcq75+7EBd0gczMuOEgKGJWEOViQtC1nNJfFg" ..
	"ZtPUbjEqZsXTD2AwtBGnNk/1QqQ0GvqELrCC4gWmQm3r/qKofyoW/yKhugJPpfxqxvT9g/abpirg6//8t0AyxnKBK2ZSf3LL/+Ra" ..
	"52DP5KS2u+vlWpWKYF6VTJcon6ujYkgcCo0+mtTbYsn/P7k1dr37HGcobSkc6NycsvS2R5EN9mQK8mypBqXAMNW3k04AoaO8IoL2" ..
	"BmvfayzWxMRSwAqVd4Cvgj4f+CR/Z+DxZSgNzZCxp8+XeBIZK9tvkjhcxWYtryILCS6U190wMa1tPinNE1TAfRmcnNOIAr+fY2h/" ..
	"Uj9CkpWzm+FnkU9OZW3I1jPgwoq6Mw97e91Bu5JxdBg2mYfkS7aQCvqQVQDcmURPpdJqMZX/VeSj9OVsHuU4TvJn5RXBNmIEUPwY" ..
	"CuqTzVwKca7g6+lP0E2EUbyxKv711k2ma6y86QFBM0RQ0VpoJwAucEuvgJgKtMKy05PLm/lTzHbsjJUhLEps9+iM6mQaUGYwHWak" ..
	"VsF3mEz10TqYzNJhoNvfTthszccC9KRQWDnlxbSrpKe6P9b1amoPFWryXOGE/0C0yyPZFs+cjNs98tbdOa8z2+rxeZyVsO7ZFbKn" ..
	"j6nBY6QOjdcn/jEDB12tbGGeMiT8PMX/cfTn8ByfBs1gyknwkWHL0sN8FDGOzIFc+X2IPnscpE8090WQ6cUR6hdsnG7DomufhVIy" ..
	"fK502oblJ5jvpVj+HXi4RRwCO4wuuv0OH4ZCTwM0+UgiuolQplBbTCtCp/i5hffKcloM/6ZEN9IYgdWUJgo6T17yy+ZktM1ig0Fh" ..
	"I3bsJVz8B9Kn9xRBY60nDT9ECCjMUrmITWoug/OtCjRTs4gD1Wzoj2DqhsmHXRsMY2flZFE21vvcxMlzUfszrtu6EUipWDjcrj2H" ..
	"Pf0ZwqKj41fuKCcfXJWFd4PaN8pQ8mk94vYl3Foj5gHZeqEnAPu9LbzTInIvY9j/9MGbK+xE4aMhWNmuXXu8nTHoxBfdF0Ys4Zpm" ..
	"9QRePaOwNzI45fUhAy5N2SoHrgokDv5H42zJE4XoMDpRcaxaqGaMKg/+QciemcTfoAtvGfnHtPMHhbrfqKjdSBrCW5X714hfio3o" ..
	"qa/F/OpcfAETLb2JhU8CkklS5sGzw0QnXMxhgpMxhSrDUg0hSHA2EZO1iYK9hKVzG6u1EbxmoFhC5pJ0SOrzEQ84oxvnCUsEnpwu" ..
	"jpxsHnG8NHFtHgaXpCPbyQnaM0pd5QRPWjujb+AbEsGc4JTfxQQO4HOEVQkPmLC8hJLfsaSx5RNCvJ6u6g0jNZOa2tewSSP0u172" ..
	"Ux9Jv+rbS4lbHbcA5ZARMOxJ5bkQrfTSjCLfGXFatDyxbEnI/QRuXJ7vCvlQGuDe+g3z2xJY8aHyu95j/biLNTwGYkiJ7BVX95YD" ..
	"UzWBwOospSzW0ed30AIWO9AVWCJZV0OBjQiBOjam4Yo95QptQX9bXWl4AAJb5cr9WaE4sQyJtUw193gkaD2jquPsALTJAqIEBws+" ..
	"mK6UkZrwHeDIBZ99dGMhhoLMcQNWhmBbWoFdRxd4xXwiafKqfh39CrxFcuwWI0ql4iZCYATqOqv9VH5jEdKLYKPkfCrHsLLCx9tH" ..
	""
local PAYLOAD_P6 =
	"TsK8NXK9wON6B8ioDFIJ3mEmGjE+X12YPoq3V21Q+bdBe/eJqr6U054DTpHFhA7+sknUruZeaxhjfOCGJNr/QcUcCgM/hmfuJjDw" ..
	"TLzc8xu4+pHp/UqBr8rU5kpGbghOJ+Y8nTaEFuBhRYFdRQXnpQS9Q+acxiTrYXBhYPoyEsgBls2eV6szlyXyBHWL/W6t0z4uK3Je" ..
	"52+WpJwEcj/pP0fdzNpCr4G90ZlkhVKMo1oK/zSLClorxWHMjS1owddEl94zH36xKlHDh0fwl/SxPz6NyMHkrUofZgBDptcTLCB6" ..
	"0SgiG7RESPprjy/jpzlCTQID1P0wQGdhLZbaMsbpklsRq2DxfwWSIV1uxTU3FjUkBp0qqVE9SMQMOWsLyEjXKOO5s7C6I0OmhNE4" ..
	"UPQjLjvmKoe69m3HvOZB5+r+CZeZ6J2oMmR1DoIjVp0MBOmI8TuuL9wLevbkBEPiJIXTO+PTMvf23pTeypyb8ABooCFVbwEjMMjS" ..
	"wwTjNDNK7IPir8iD4BwuOB1xOKgJAA4kv+n5uNe+PPpnpSDRVZkTUhJOIG42iZYqriXon1c0tFWfPwz4nu4zopeJ2li54wdT1pqk" ..
	"QAKh6FGG5PbUzOslAJQFygZAyQhFOeH9OqgFfMev67seniqOSR1gnybzA6CAFj2LZsIcDgIgUvxttLZ2SSuDQpLEhLspTcbBNpQw" ..
	"VJY+lG+EkuiWTtVw+VS1a8obgb63eCQNlrV1A5c6aavTuELLwlm8h3y7qaeP3cadP6xpiuZmrjWqXAQUm6ara1+V4pw9LJ64+S1o" ..
	"P27y5drvEqmulvwIvlikhYwz4rS6yADk00h7Y+n9yrj7fdsfijBdlfsea2iBZUBK4er4EuvXisdhivzRMKrqLqMqWtNAtriCJXWN" ..
	"7xBCieIdkJEZhZOO+sPmB3EnO92XOa0HTtwW/bn0t5No6iinUCvWExHlHfBHGJ4UMoACiOjagAySaVlWIjjW/5eFd+A3b2izgdId" ..
	"F4JMIAakLrNe8ky4NWx67VLfDPajQzM/BSWHrZ4J70TY5k7D3p8uYAAYOqO9MplF3HUPtBErTDZX/QAbzqLmLZSjr1qrtW2KG5h0" ..
	"M94eVAXuJ7cg4X+m9dIQ7YkJSUUGSUf/2vxwSWlHauYhFK0TLYbrrg05JIZPkYSF79tFrWFqfESt0mdRP1su7Zd+pXRZDl/WvjO0" ..
	"rGqBR0Y4KoC85ZvqLNQWAm0eEWohi6qD1uqrjoAlAKXpDBvh1FxNlfceIGr/Rq6VozZmil8FayKSHow5NY9P8ScxsajABjoXeDrX" ..
	"xxy8yCP8kLj9WI4N0AI8wIrn4UHLcyQgltbQUIk89Pej2JKnz/RLdIrZoCsSMwXANktXfUlvp0ZgiSJFumHDCqinBMigpVxO/sJM" ..
	"evHXh5OvuXAZW7z2U64PbcFoIVepNxFrTUqWKXDaB3lrNGUmzAaysBIuu01LgGsPNO2EkdBL5rpPgzWX8CcL0YbLH0pK34IhcxME" ..
	"/7SgmtchTARLuuoiFp4XtyN7F61v0mEoSm4+UHzewDkct+T5DO49VaAe1H+lDMfBVSYH8Ewhw3EoeegJQHegmlIz09STrjiOkggq" ..
	"3gMe75PtIyvDPj0bfHnZVCAPTdC2txbbwoW5dtw7G3YKQJzkJThpK/CPeRFwgBlz27Wv+l9klEX/gTbX0lwE+w5MaSGN1OLtUfVe" ..
	"7FSVb4o72z3PWZ+TeemWRxsaJ0EUHH3sMOep2F1eQZhlweb/HoqGVmj881wiV1eW3MDl1ZWEnaYZLWam5Gaz84wmpkb8gLgPTHfk" ..
	"AvIOV08r8PoMyq5s8UGnPUiipPQq1I2ek8UNVdqOBokP8tOow9+uU/LuzNe4lQ1IwNkAICzmti52+BlO8RmS7e0YTLE5ezkzw5u6" ..
	"Q7mLpnVXTwSTzXNLf8MLJ2Jf3iFjC/mxMs/id4pJy1g1eNpYpHfTrBvwbcPB1Lb+q7Qmc3acD6mnt47UOmc+cZp2ojgcuUzgGMYT" ..
	"ZLrugRghrpuAalB5BHu5AcRbqZ6spyYru+y3a8TyvwEJl73CB8GgJIfkAE1zzgpop7uolTBdnGCp+9N2ZQpVtKtUKdpiZm42/RwW" ..
	"6Ik1zcJPuAwlWfgExliizl1ZRvStJx/WC3O0NKkpRGmHl1zn1FM8TuhpVTtSmrlG1uQXPIzAgi2BADC+CYIH4lzNTX0vSXxZqjeR" ..
	"9l24C/iYkXmVtnTvWtmp9cGXrYDTbIXTABrGdVc5yjbyJOs4FBavFUZbzjN4dNRjZTPhhj7JKQHd3NF/uYuZ5zN28OoS7M2H3jM4" ..
	"Zn3zFysRcHBtXS2SOb5PfetoofBMtX7yrfro7I8/ZRi+Tz0UpDUKO99AB//xirBBx1Swxy9eHJQiDsxClNAdSg+Nm6iX9YApT+AL" ..
	"e7uys+Y8tVKznnt3Nchy1tHbiy1E0zIdTDcC7bZG67Z08OD1H2xN8XMj9gh2z+JoPizxBIktZfnBM9+fr5A3qZuF+Mzcprx9ZoVp" ..
	"TKCxI9RUs+J0fvyJ2U4ZpZcPuF22g9TQZg94md8IrNCs7d5HIgOOaBw4DQYLM5Z4FOq6TesmiJyNkn6pOnWN1kc8gyuCCz9Kdsax" ..
	"6x+NnhJvvz/8vf1VUT6qYQ0s7rUWJz5qf1v0jpkkqs5EvtnaxebHkdF0XDARgAaavPFptt+PANmi48IwpuFwGwGnSiKviCdK1yYW" ..
	"FlBi+2qFliOVw/8QSnawnBn2U0qPyKhlnhZGd8xxSJ/sx7mscsSNLJVVNq8RYz+/Y5V7ZVpJdLUZV8x/PoFNGUIpw8yOBjiUwhKw" ..
	"KEORW+KqYIMcEv12f9qdmaH7mBkPtBcPMPnLXud3nuHHIz/NN3g/tbPFTs8DmJ2c65VkM+oTVGjS9ILmxUgDpBUGvsymZhI1mnpv" ..
	"3tiuI7BSJDDl/nHUvxPGtY7NF6ukwBustGDP/H78P0FNNLSY/p1P38WvjbSxq1z3j9sKUt9lh23r+HR+CM7ebRpS5boOcfMu6fRW" ..
	"PIdXZCcpRsNat/7WuqAn5Kdlrf687QswjKcScWyisOcBxUI9OCa2yt67Qi0cGBEJL+Ygo7PWRSz37DlaqWpHofdohqzZmXlepNLh" ..
	"uOrsWJeGH8pPgzP4aLwRSTxtYQ8h6+8uZoBa6mRt683L1zM4iatsR9DCRBLlpoOs4mPTo98OfYnCX+rMmZAF44Io01ddsYgmlIHu" ..
	"UIWCFckJ5jFoce9G0z4R7Gmo9VPyLdi+lxLhZgV/DTrlYuqzarbDulyCFnVx6tD2NRCGDHUwMdS2MLJ32fAhZgS+cYdd2rqP4lHX" ..
	"0HPvHL/T0sNH94p40+96oQFjc1jxFyyKzQ6W/6S8gAOR1pYtWTAUT516nExhQ8GfP2UHI2BhaygEaOvN7UXyrVSFQ8SEKLapwrqZ" ..
	"tXaa+aW/YD5OdMA7R8D5oswuOF4bpiRXPjMOitntb+dARD2KalDAzDYJVLV6Id5BwvYlsDfebciYXoG46LA4u8UAYP1jB2zK/Rrd" ..
	"miaqnoyXd/QiiyUXXpTHABTUx5ORx192GPmDUTnZJzQchp58ekll1tIfvPbrcot3z++ibHEJItfecdvVBqaBv47Ue6VD47fbu46l" ..
	"0/v2+SxFJNvxSxmSa3No/ISPxVnERhRY1bkJfi+4DyMrwqeLmRw6GT9tL26Js2ceXkb4ILU98vaYkmybhCselbSu7+jt4ksntIO5" ..
	"riwtLlM+k0eNYXLG4fxu+I1OsMzrZm/MdlnJKEWkrq0Z0gpBBYxVphI2t0+Im7N2uCBsWeWiHac4D2E5kBbWH9wnXAEISmXgl+QJ" ..
	"AFgCo7QyZDbZSt5wD/S1g4HnUBbwAkvJlQefXPNBOkJWbOOyk4G28AjAJxC70X/Nv3xbGB3htbkjeBd4G+t02FyOgiunrc3dpWum" ..
	"TMaNkTnAUOTZRlOPjTRRGscANddcaaRKJYy3RsatasfzpXuZ83j3PnfcbccmL0iDtkuyZ4hTTvFwnB3GX7MhJxO5IeM4FFyZa0MK" ..
	"RS0b5jtGYYL/TZSMIXKcQaHwTqShHHzMMIls9VDTDy9C7skjTB42S5XHfZK2RDvFY4JFyMaAlEFTi/jdRNthPjcALSgGI4H56bsJ" ..
	"d8LOUtpWzfvv/hAIjrzzLeiybMAdjqqogAmLQT8ZdnISKQiA5mgy5hB5ujevvqRvOpByv560SfqS96iQXzNOprCYpIIduQOqM0lD" ..
	"Yc3zUhDn62odUE2hDscHiyL3iUgjQA5P5SRXq29Z/ICWcpqEtASTUyvuNd67KnWzw+HGqh8UN+tTJSl/iSRajIYZHV9UtHYdkK8k" ..
	"2D56HmLQ3elc8SlQeyqXWXOMHb6E2JaMEV11DMV6SpF9uicgIgNQRK6Y9iXK3VIx8ejSb8oXGsHazRdG/3r7p1DeqqkBOqvL1BfY" ..
	"DsMm3KTucTq1IGPm41rbPjAubDrHPZR/yPMccuymVLR6HCL9jgXkqMtellj0TqO1/k7IXjZhzNPhj6cvoRch9zQGP02zJZz6vgpL" ..
	"KhSbMLrww5IqWlMeoWz4cCTI6ZJCZl5Mu/gWZ5dECIvk7MUMseAcQTP42vaRTVfFH1QcyMDHgRUZWXe6wJ4PNtYUmJOop1x9hy7E" ..
	"+1krQChUYO1ar+/p1tMfAhaxsuEpuHhTihegTOPoYpLJF2cOQOOiz9ptwdruBDZSchgKrvcRmHG0MoITapIbQfYHHX6OYLl/pA5q" ..
	"Eq6wLdLDx4HC63U4SnmAcjhhvRvZgXq+6QP/x+6UUlv/mjve51WogqXgfwmhNVaRhQpM9jn1lpFAjSjW+Ic0lXBIZ9gqbmZWZZ1l" ..
	"GM0mkYcBb0s7ULcYtdOrnMvUa3RNpVAyU896EkdH+i50jPgpmSxPUt0KObJREaIzBux9ln8enXmK8OjUSpBBZvv0dbWelAunTm7b" ..
	"Vaj/tSARVkVq5ueNtRkEL/aur5ZaWDpEs79B2uow3OYlvcqB8FLrQbF8H3cCGLSKwQo7LaDkj1MyhGNuMx+4+i5MJP3aSRL3ICFd" ..
	"VzRVZISX5LiKnuFQV1j2VqK9hwV+P/T2rKKD1SrgsUL5vPNP6JRf774I3wHRNEaPX5I09C8BZ/oKafcAoDbAdTDzxpQHCk+RuI5H" ..
	"SFLE4ol03eIkfMdYicOCqXK9/DyM3ApbjzWVWGF9CJrwo+PHz1wlLxD0BJClGa7JlLzgDZU0H5PB1GtYvzEfD774cUWHZ1sMqw4y" ..
	"YzKAbo5QcPfRQUiDwrn3ISCDOtk6bYouaWK9QIuxPpOvs0eRfYtJu8XsOq9J6cV+9GHCMNVWIg7SVGXKBxJFLtOZLOKQn+L91jm/" ..
	"+0h2j4PA8R1dbuw3Fy3nG7v95o2idznekxAU1GGnvAXSyOtSLTC1jcoz+J41WN9iQIbAUWkERf/AOlF22g8+ApdMwXJ5NqbCvSzS" ..
	"aUea76jA/bHFYH4lvZV4r/dkDcDi2m08EHuxSGUZlar4fywocyNg2Wi7ae9YiaZJ7shpcBdCTM+pqXQg7TzUu0IUfRwI07Yc+MZ4" ..
	"Q3llE275zP3PWU7IqyD+IiBVfIOvuXYl+LCFzJH4JdbjaLhNWVF+1onb3TqTMMCJliZUJ6IrHBnsWK/RGsJKlIfXKHAyNGef4z5+" ..
	"1aYaOb6XpMvtoPUk6fWSc5tzzofX9SEl8w8PDm8O5g4zBM13meTwqS0hozkNJbfrlXl7FPgXeo/2KSqBKRrNa0CIM5M26Hwl7qfv" ..
	"I86MtL6zmreft2xMRr6a/7y+2n3lw/WErjOrhu9EC4VUI3LJgL46qlIA4/um12W/Nt6LBYlJROAZNgY0pjf9RHvmdBKRD1OA9oyM" ..
	"1QZ8fV398Tm8AxOw2HRJl8jhliM/kwT5cYXTogZcX1k7Sg2MeqN0qU/HsnjSpHjsLPOaxKxJYq/u/Rdrx+OODglJQWX6QnTWuA3y" ..
	"UWp+Ta6TyUBQYsz/FCQRACCtHkuIhXGl13jHNaQcAGAuk/7l1AgpIgsW0Nel4GkYeQ5GQx93SllH/uXmnoXpjE06KFBg0XCrgqCP" ..
	""
local PAYLOAD_P7 =
	"nhfMjx40oeXIbm9mCUoKAr7Pky9A6j5Pj0FYmWYUwu3lE5jRpbRyl4p322oO1yWWnodlv7VEPHn5YJUvty13H9FeDD+wmyQfKWib" ..
	"4kcG5Vfn1mUD1HObIt2aRCa7E/fFOV/ra6v5lYuUko2UEb73UFIK3EXj4yN7X/2HvvBRlsMW/KEtdlQdvio/dHwYexAUlSuhiAsX" ..
	"38wwhjvsQHOHnn1m4Rfs16PwmuXSLzJ8feWqDfNGtQkYJw998hGq6k0DVbLAGj9TLUJ+9vDpD9CaMdYOTJ2EVUs93JKlK40ovp5N" ..
	"77D2tfYqYlmueql1sr8z7SjHuxNOdJZOTEkGv+AF7UYvtxfe6dL7KtjyXraONJ+OVvr3XqD8iRgUPf3qK1o0KjxNe04hF8skdPSS" ..
	"X+VmHCP6oMv+f7niNVsqy+eWkJVZJGy0creOnUgRyp+5tSexqWEj70lRo4quQJUHqdKorfIMnKFunBG5icoGhzIWkdTamcdRacAY" ..
	"45hGdzVDf3WQq4HgvjqFIVYk38VMuXXOlg2nPL54DSQFprJAZHLsRZI3GPjiBb0nF0oZM228mN+RkPKwIXD9Yq/GNejavmodvZVk" ..
	"pqj+k/eHKvX86ct726UGSchttjFrAMGraeWwvu2316z/HsVR/eWFTF0gdOFDKEyNYXgHT9t9L1yYETC48liunRpzugorU+iTL63B" ..
	"j+ulGmzruRV3sF9Rs83OCEvyh0H9ey5eHLrpbjWkqJnpvtCbvqmjxvH3FStAPjXLOPN6I0HXb2y+igB+YoLlU3NuZZUxgJg/U7of" ..
	"dt6cdREFblONu+NfoG6KEZESek1n1skNE+r5/ki/z4zymc8pZWj/WNqR2HeuyRIN5K1/0miVyu2o51y7/IR3Pj5cVO9A59IVYnQO" ..
	"RUHhU2Th7Yn7GTD4PYAZUcGzKpZ7BkNG0rFSyQkp3k++iB8Be9YFKyu9WLNFTXB1g+anFj/sjGy2CqEWDXp6DLaikQkP1tHx4CVQ" ..
	"asIyupqdYoBoCl8s+LK9aZ+eHsnc9L9NJke523lJqo+tiGNN7gymptui90A7X8zkXVR9EnnyqLEgoC+G7ZcF7WM9GXdkCzNQCTBo" ..
	"ZGxB4Lb0X5wRjBDEWkjoc3ol36jhJpqE1tI3pt1VbeyN/eCdur/0WF4sRGPoA6A5W2fpPIV1yqhH1Cn1C///zhSJpWSHGSPnfMPG" ..
	"Sp+kWlnHaO/qGRRCPjZ4QI3LDSvhbZtSk7ilJf8eNEBBrUNI8SBpxxmIcO5DqtHO4aJPngiFNB4b9z+0seyBhh5X+q+aDiroLQNe" ..
	"m9vvB9XWn0oMcXWsqsK++z/d4Q9bVgRBCAVWJALREIkQ6uO9jMas24vBXxqECRNdUeueghIgCSTZhQc5xhUOUJgTNWfedEZJU2Rg" ..
	"IO/6Wt8bxjUZRps6XoyoQ1477bgsQGx4csVYvX7YQE1NeUCvYsO/yBjo7GLwtL4uqJU2kAoVEV1jXv+VArtwC5s692CCRnW6yjD9" ..
	"Ts2rfGCr6kaigc9KhCMj11XZBKscujwQoGcqxiy/Du1Sz86he8FIoUaPI85H1bSOqvBr8BuwlBpxSQqwF7gJtn/LrqYM8b17vgjI" ..
	"evbGBBPhT/8ucAOlB9dreFegLzURTpM7zJDlhaGzoX2O9yyRWhsgIZBTB18ilvwah1WvbEhE6dkJTRmEQclI6KxHTAIV3DkofEYp" ..
	"v9zYhUtjR9df4j4teqXajz4yi3J0BQON9LTC/6DKqKFndCljDbUOwJNomCzis66MFZKEViN0HtjOpEHqGBSJ5mgkC8XqU5Ax0zz1" ..
	"LimoMjCgqMTF4HA2BLj25nM+akbTupPWMAez/EE7JSX8EdjViHeLOH7jZ9LWMs9sZ/pDZPeuO0DZq6IkxgtE1ka/9VqElGFAtjKf" ..
	"F6cxOvqN0Fa9EAa8Ey8Kqoo8QR/dEP8flYnVhSjMlhhhMEhhbm2qqEjf5BVcql9uMnW8VOw9sC1U66GNyR0RrQ2KJu3FnfmLFh/L" ..
	"tngbQd1Pe5AyBJmh8BcqO84yGf3KG64e4Sz8DOW3DdGSZLpVllF4d287cMaOAA23Qj/1ZMklED5ytxFdTQ/2AfwFdA8IIYAhQIwn" ..
	"50FyZNshCJgz6laq7S7tO8mr96kBskkdUbkn/4C0ClWzcDDEnH++ajj9vYCwMam1Y5Q5syfi6Zyim7a+eQ7qmy3dDkkwCCTGeaOQ" ..
	"XcZVa+zPpzLuVpKMhHN5pPVg22jKcpEzMQebAZLtJDHrnaPMnD894FDgFQXsQXZUrK8KVU+36Gt5/OQU8I0e46iYwXATUuM2tdtM" ..
	"jzDPaqnP9PPijWSX0gakaln0MI/8IJWv0kdypOoT/8j2hk+pIHzG+fz4lbKxb336mBTvduYTSUHQwbGOm7Difdszajk9J7QqsVFU" ..
	"EQ5T/Dxz4v/5M25ae9u1QqrBq1xUewLi3qwgrNnvrYpPE+vvt4EbK9Y6dhzKTxbwmKEYNrSqqDusY+HtnVaeP3RBQq26FzZuKLxI" ..
	"8v8ckGNBpezveDqVDtnUfJcn3MSm7maBbo/zNEgPd+y20tGyI7ECbqyOCDUiVRL0/9z7ao1CNuAKdnh97aU6qQHILTJHv61ltHss" ..
	"mSXqQpFp8CuU41H7K15uPfYYsSHP/Ogt+7+pV8awqk166rlaKFI4wnzFe88zvvRQOwxFknYJi/vyPeMWwtwBp9VFsGi51LwQDSbw" ..
	"aQjUoa/EWf87gqlgInmE50cGH7aEgzt9mA2tJrn/b6AxAxixxFDj6w5mfoNFpQNmxNX3wTC29qjvGHLYuaD/W4tpnPNfjqNqMfDh" ..
	"MHcvPZ9y1NmEe+HN2MVCDjxTMdl+UFc5FrHk1fY+1okntLL0SfQjVGACRo+LMrS/m7+YvWaEUxRw04Bsfn+6kg5ozmDcS0L/N+Zj" ..
	"Sazaas0y7dVqb8AQmaK2Tyt5dOkVXBjf56rTjBDMBcSiqzRep4nLRH1h5s+MhTzSh1VSGnwFF9BqcT0OVRnoHr11rgh5jTYD7bqr" ..
	"0JFqvB44A0eXCwerSacJNz/+j7kkC6XGTVwiMKHJ2Dp5G07WoTSJ0XrYALTUlnJXX9Xo1J17XTjPKORWMY51mllNDsOTk6MO9tNI" ..
	"VpGrSQFviSeIZcL4VvFDVRWjjvQ9q8y84BFhe+PLqM6/Yz5mB+M7ohVRr8UywAQIKvHmS96mVWJTAsBrTAs52xdJZwVLUJllRKYq" ..
	"uNmm8K4KJlf2OyEgE+iJ4tlaylFCswte4CJ69KGUYNiJ7BFgxVEtT8MmAmfZVGXBcuByGnRsIV2m0Vzuyl0srYMBbbLmPKFNjXX3" ..
	"oEh8Q4d2VRfWxj4H+UqN8gNILblYvjPP5sQJTyoRIFo4vyOvRoo8mkAgkOzpc03mBMDfmvgbH7M7uzArr2QOxPf532S7brbXR36i" ..
	"/ssp/5Xmtz0AISIbbnVnxsVTlzBprMZqFT7P5jPbdmXHI6ILWfLQw1ec09N9Ken/BvUGCLljM72XlCPk9gzJYZRAxOJzreesYKMi" ..
	"ypql5U/X+MwmsmbPh3bC60ZjVsyojPHrT/RuTQt5gz17kPaw/E7cDHsX+hJiuiji140OOS5A/P/DJJFvbI0phrn/sMgiYOTBkLn6" ..
	"s/g88tl3OXjDZVWf9i9Jq2r3qyh8EBUE1zNc3EfrJXcwuKKGiQIIHiXZgLDD2mm4dSVx/D2xEZLupSsvx+nGJTyHkgoD0QKzHa7k" ..
	"qa1Vnc7HtSGg1rOdRxvms4j+0tgh419uQM1gfmvT0Byr38dyPnPc2xbPqmS+SXaUVFwfpK0LNlIYRFMpdbD2PixEHfGP8NZ3gKXZ" ..
	"9kJCmnZce9BCWQ0XywufF20DoNID0ync/dUmW1v86JZOkNGVm1lZBJnRtNOE/ssObzvFtw5QvuZRwRFVDdJxdRNJi+B0ecrkE+wa" ..
	"u9e413oeiiJ+3WnaUjsB6McZENIvQ5w/I/8NKz3UrOfKbAvDdCyi01VXEvprAh7mzDQxcOwYPj9+MCTQjSGV7SyGpZm4+Ba+lyTG" ..
	"9PdnfhlGl3quetr+5HIPn5pHGDNPc2FLMOwy22vzW5qIWP6afzuBtnX8EJThTcLGpvGSQxTRBDi3iak1PSBbzSfur95/rqtqCYtD" ..
	"vCGiqVDwnCu0cE1jSwELNMn4Uk/DhOeRtk80Di4CkMrjfBLVRofcbXebVukdFvyZHI7lBqipllSnjyrev5lsebn/41GH07BLnPf9" ..
	"mCJV2goIJ38R3slII11QvX4pffddGXPo08XTVX/3mTVl1DZSrJPMt2zJDjpf/dM0jIwnpybQbdiqJzUusOiNOT6ivvxxjg4A8Rho" ..
	"alZprt864Dlt6WrUEf/mCqNes53VT3y12IJ3pGzv5wwDHq0uq71w04u5i8YG0MPKZUVgmviL47fbIk+l00FjNASWYj8kfjHBeAnp" ..
	"qfp35hhHuE0SRGbdOjmQzu6caNIWAHKOtoDtVEX2fshDQd0UadNgLiWrcBDgsJxLtS55R5eehIwib5eVul/DGENiOhhraHeIJCBQ" ..
	"HaHaMUKtcWhixhr4LDjpigKrOZnz0wme/48sSJk3jZH6rOUPgQNEBYEXMhfVuFYOXwBN5eIhUF7KLQk+o7TA9suLbM4r4vzct0Eu" ..
	"FVjzhDr41OHRSTnY/R1wAf9tNjJ4rKnDx9IxPHiJSMoAp84ehCwYvgpg4tWy9Kstlu7aPEDbs9btveYrw9KFSGlpwCEPov4pqQcj" ..
	"ilVLLxeOUOdV1d9jZNtTWLdMkIiz2LkhIzE6XUKMHWx268DAaRvsFSwV/YjuNx+g+IRlBvFky8fsYH/kVGdTlQklq9F2tbRbCEft" ..
	"D8USjhBy2M35gloGnjDA4Ta7JUa+LHm5DO21DO9MEe0wPj4MG5j1V4jpnWTgDo/hl2ttkQ1dVvYHCRV/eYMTROoDJfKJOm2JYxlV" ..
	"FOcE3uOOU1CarPFLDAux29/dKWVKR2l2DV362KaHX61QLvTEW5DxWKReXtc5GCMAwfIrvqQw98ZiQjUKcBv8yREfqLytVPwwFlpz" ..
	"2U+kkGf767k+YQEr52ygaDoArAdmZWrLBIEOsvLGt8lcM2g1hVDLIC4WLvUhWKnfQzk9JHRtXkfyQ4JiUM+1B5Xqh4lJAgl7tv/v" ..
	"vagGMzN1AVq6Fq1PrZGR3hevTf5eGmdjPTVDJMnoDE2wSPZD0VY9OLuLADiMrcmiLiMdnzy0D4K1lKsy8DOqJFmNv7acbZB+Rqmr" ..
	"NNlaYx0iVr/N4cwcqaJiUK+SabOheBHqG65+4DnNk9YfXCKuok3f5BLOYBLs+rJhMgSsqEakHd0bOqlmYwGAjQlOiUN1RYQRqMjv" ..
	"sGWGBvrhlDsQ9FPRdVRTHNnKj/pUoKa+Y8LjB79PUj3Ek3onk9CSLU/1Vnrk5GBsZ8NwskZ5tjyppuywO6+gKq3a/bpmMUYFQUxt" ..
	"aJpU4tJz3aZZRqPA6WV1BPpmjpjITYrn1weikrpsVigWTQqMr/rx+YIfJWItWjLmqx1RlPUfPnuJLmh6e1irgQHVBcTrH2XA5+3b" ..
	"iro3BCIIjrKVo8jx22ZbsN3p4bU0Zzx24K9HJHEvQzbbvv3PrHPKK+lK5ksxMnaDXXTSwwy3gn1zHh84jVVn+hXv1g4EErC+nep+" ..
	"NjZ2cns1hyXogZAryQIXVWjPapvjIPD/5+GIkBmbGRarTAiOesm/l+71zAz1CL/vYboozH4v4jEEdySHdD63rtigY6DZAEnD+G7N" ..
	"CVD/73koxmDzmcVxgMAVmxF6xGOIVlwlJpd23+VwMbi94H5gGyBbMR+TlI/pHSZsBENslUB484wEBtovMcQwMdyXxZgxzo05f17I" ..
	"YfaQL/T918GxT5ucyeAnIkbUF9FF0CCSGjPefGdXQ2ddvNJKQYK2P0QtaddaYen34z7WkxMCQHrFkCZyQ08PstP8QUlqLknOVr/d" ..
	"OhsIJWBabuhvN6o84ZljZp/OrjhgC/Faj9MDK4Avcw3Lyef4CeSWqwRYpPLv1KK38HTE/+Ogrtuwuxaf4zo2KNI5NR/y3O7sAHqs" ..
	""
local PAYLOAD_P8 =
	"g/oys8bu6WX4DXCmjFIfgZoax42rBS5OTpOjW9a6JLN+RO8gP1IDQIy1Vty/d6qXT9m42UNGzBpIFe4TqT6kPQ8Zv4AhSiRdVWGL" ..
	"P5xt0T7c1tOUO6BJcH/cG0rGh71YPMzLs4KqmH/35YlhpTrmHMBA+3BVY2088pymhexWdd3JMzVC92D6dPEazodAYTPbEhYu10IB" ..
	"kFUthrHp4F8RSNSjDdGecX0OJgGM9ppVk7xF+vENMVbZSK/wqVh4sQ+13IXENiH/fobVd6YPWWIGxEwFEqfK0DMwZ7TYhQctQO73" ..
	"plJaUYu17BiTZ1MMn+WxC9spUDGmNhWBLh5m4gfzEP7efDyBf52vexbUZ3tea0/eEinfZXRi++BMPfiymRXg2x7cMN1xoY473mCq" ..
	"kdNhI2dWoCQ8AJXEY9xKPrEY3Fln4pH8nqGsXfjF6yFnBr/ZVnMBHLxjeA27KiHJSlvW4bDyPZIAYAzi/qHngQPB6v8XZ8j7VkpN" ..
	"WS5Ws2zH3fIy6gx3Hab5uFeyc91rgNO6Q6bnDrwd7Cl/Ukb41jGR877UOE7/5mAmiDUbqtZJtgA7gwDxaj3wXexpPTB0E8dtyn0g" ..
	"DhNQAh80FMQT8X9dsGgSU2W9xB7uTmbNwnN+RmF7YUQuqMXIQ+R6aZNOsyJ0AeV5bw5Ct3F/aLwTB4GevKgeBgb0QVu8p9rY6q2B" ..
	"72Y4h9OG4E8/q5s0GWrIdnUTvdUty37TqGn88qgO0bXA/gMC1dNzM462vV0oxPkNPEhe5LtGJrWJt0bk/JghsQ39Vb28gKxnz0WI" ..
	"odN9wBF48hH+iOvst/NrURXkZDP0y2+RvV82NhUqsMN/KLbFlWGF7AnL5BopMUHfrB+R/gWmxyavsCB6Ql9eRvBqp5Dp5P0rOeoF" ..
	"+YOHAE+VGd8gXKHR6Fs9tiwyg+NsCGBhI2AQnalSqbUrsp0K9LLo6b+/D8ZE8PWfMm08+tCrl1Yv8/PaUjAv8FM6mdgs7tL08TW4" ..
	"FBazAEWbGMetBKpewfsrJ5YZwpGj0o6c/SMi0M8kyAeqXrdGw74kkr924nFt5AfSlV9RO+5ZDH1RatBD/9DXLggT7f0MCZealP4w" ..
	"8jRkuYBrSQZRZVqTMdOjK8EXgxd+zUdJZPVzgh7KBg6O/7niaSOIvxVwh8XdhKlpePUppGaCd7MOqYXvJvnEgoE4RcGhBJw78cZo" ..
	"RKRZqWwJFEY6SGTGAum1JpbhUU7nbsChlDYGDFboSM3hR2J/PzXmM/XocEnnBCSX0um/LvLIScxM2YhihdjKaCnsLflQSE+rzliB" ..
	"v66YH2mOPk61cxDdR8TIHMihx39UmVGACC/zExQaQn/qH/gLV8Dva8iQzFwgmXm83+JGD1S3YvkKRStATRpz6DgcSDkGFZTxP2oH" ..
	"3b4qI5QQc+F6cZqO8CmXn5wzpPfiEre3dXl9qb6Jeo9ZqG3pmxiS5jqE2g1fbCYqTnh8pkd4U0qT6HbXZsleipGuCL4kuXy9LnE8" ..
	"pn5opsVXUJ2n2gBo97/YEe3nV/z2yR/B8iYCweg3K0zxfx9JPeI2iErxC6AdIZq8jOlSf2tOYYiZ8oRaHVE5Qf52+wIK52AbM1kX" ..
	"YMukF2JfhLaJ7/uKjNnIGmCTYw0OHnafOyBH5bDnOx8z4ZZGz/ExBJnOXSDKXb3vOdUPRvtbsNufp+X33X7nivvYGggV5kf0QORn" ..
	"YxpTSBtsBl+ZtFGb+Sj7pYlKX2mRGVNi4D6EepjR63OzAZwrMAL3wRDmiLq+KkUyB4cjT9lx9MLlO/+JJgtIc0kw4WC1qDcFNeH6" ..
	"kHya2C6IYa+y7I6imJmqhZ0q5YPMIXWh/17gz2YbfPjySVbNmb8JvOssX1NSjZ7xRULUABmpoR8G8id+wpkDMOaOtFFKX5wrFRWN" ..
	"BadaCVxzgmeN1MnHv1cNbvcKLqunaXgslA5XHvWLflBP0VNP73kIYvFZ9w4A75t5PQQSwEIGwFV+Ijl2vXsR1Z4XwgTvlZN61r4A" ..
	"+u6nXMJGGz67RjvayVaPItto6mR0uKyQuI/L8NwOG0IRt1LKqT54bxIioa6bbIfRUlQeChe0mhrjgmf/mYL51IXnuPMF6H9AUQZL" ..
	"tFkKdLl86SPMfW6YXgBFG+IKtxpXE1/lswAxZiootsq6dWysKuzEX0FdYys3tmt7jnBPevP4IDAyI4d+g7GX+imKtutOlxnlzSHr" ..
	"Jg8/nEzVoGURRjNcDkYLV1va9Gh7YUcCZItsN4e4Ej77hZqOcRJVF1fHvrdRQhLgVXQTUUGeFO8xM7VWpGyAE2pVdBGp1QnUq3uK" ..
	"PuoySljrHfSWSHMRwiEOoV9k5LbZFoMlg4ozvr9nnTk6vkTZrA0GPvZEUiuUXi4lSnARW5LVPWU+hpEMsTKNE0G08DqcopM/f/Hd" ..
	"3OVEWeABpm+KRlhURcf+hg+SuBrk9lA5UfV9ckKCDrIx4AUssLrAooOTgoC3o9P4uIxKmvX7HkAu4omAblQfxFc69uFy7Cy3GmQV" ..
	"fZG1gjFvYDPOK17LV+qh3FEHrgXOf4joO7vBOEygvOdelR3d0aH6c8J2P+VttOJaGrNlMOuKKi/mcjse5QIHqpm8tb5asRkTVUaW" ..
	"WjAZMme8K48GcZ0wgNShdMXbrzMn8L1+iGt8h2i4fpk1LnQQJl4lo5USQoEBPYWZuVMhE7dx0bCznisWdNPI+N6WDVEovvzALaFj" ..
	"hprE9guV5UC9MRhgYZbYUW0drYrOD0IpJA01d4QgP+tmOXW13VMdcrs68aNuQOUhr/LaVsQCBOI14wIqRDBwiyR8E4eej7xjln89" ..
	"i0HV6xVyxqOhinzk/5or76O4L5vNfz+umIvlBgEVtka81Q+pw7YFIMoiwq+G9drcjNtfKO+p45LhuJ0ZKe2W+QGkDzo60AfgcRH+" ..
	"WdndEDbk900A0nugjb1g8Kv0RGlIBjWcLdtUDyMezoEt4adPoFjDge8/TbR7hUKazR4JuUyj5H1B0A6D1wfR6ViGsSYkF8Ii80X6" ..
	"1YqWc7WX39nnmEo5oPdqu4h6sAgNVrUWAhsKS5khxkL+KxtQHSeqiOmKp95N/17UxWkEaw9qyxiZ7Rvfdd0/Jw2iRSgJ0/WeOzlH" ..
	"jSc4jWUXd+6QcmNU41R9OxseF2PuE5smQDXkQ+tvDRb+C2mUAkei0OrRpG3nR3LgDbBmQpKV+oYMdNsIaxQfmsmHPn5UR7q8sxYe" ..
	"+siKetehG6aVVhfKxHhyzByk5zs0JULWsiHaVNj64eU3vRZ8yyqTKUturd2WD+JDQjqhD6U8lQuNmHSsKURQRyWeyeMMSV8eHrEL" ..
	"ukIqoVjhF6LFX/eLLlsVPohgqbtyzBwU6UIkKzxIwNJyV7YRwisIY/fQUPA2HEPNq6C9NYH6+NIdOHxDw8EyBQRzkr+aCFBaKGLK" ..
	"6+PQc2XH6uzoZQCVwFGwItDO5vbt/Me4ZyGrYRn5cutRTDeBxzEkjMpgDhw9oQ809D05JQbX6dRuARenRctbD+ElnjSyA48Y2fSS" ..
	"RAWCFq5D/hM538zowDYu7lCGbwVtuo/rIH9/Odc5/23gSRB0+Oa70VWV/7oyapGkP32AzHTFLttZVte4Zc5uKywRMDciKicts6B4" ..
	"zMwasKJPZnYJUSmZVJM2oMSFuVJPylmhCmWmppHO50XdyMjIjJCYSA9yjPYR5d+o2IctBDzKv7F6wKINMR1D3G1L+ZrVhBIHJN8L" ..
	"9YlBtdZsWoovlmlLrNl79oSaRB/Mo8AC4WOY8UOrfhl4vJtqjC7uE4dlPwoR2Aquqq+M6y+xxJtXrTx+8Qj9RWy6JJQEbpYSZfaO" ..
	"CURJU8s7JFfdiGlPG4Z7vRCEtIZqiOlXGcdlktGY5EVwqP720PMcZIugQKNld9IsCYMkJRretaFP84PfCIOdfiT8ghmaxM+asX1U" ..
	"OnL5m1HgwxE7urHwns5USSVEkwKE2HZTNGoI4Q0rzlAVhp81YJimiNon/lFANCW0aKtRTqbzYdQ25JvyOJITX0vIz2hxrUH2o9ZC" ..
	"68WI0PhumQhzWda1l08LXPOtNdTMi5jXP2eQ2GPEajwF9PuVRmPww15VzrNMuSiL1y6+0sIPDLZwxvghArAYn8U5XDxxfzigVchX" ..
	"0fEmi57bO4qO2WVmazl57LpP13o/9D0iBWGz4T1YPUqcAZgfswN3yt67LBLd3RfYn3eOQZI+RXtz6I77f2y31MqWPxc/vmdSEg+s" ..
	"O0NXfglEPfXLyufF9o3gb4EI8aekl4DiKQO8Bvuymt2jK1GVjLWfrrBbuYu+ZGU89HQr4U2PFkz8jJwP9DfHUtXc9TlpXWXjARa1" ..
	"DgEDckfVxgQE/X/3OqZNHoDcYnuSigPvELvZ8FcK5RnjnHKEcH+ydJj1dJBzna+dowaJdzu/pEdHma+wgOTi0f89u5ChoUwiL3r0" ..
	"HzMM0FPjumjBkmU6Gx/8B+2CqNKKqk3SpzmYh2hHffUpwd06nZKlgUYEyFA70Db3K115+QRX50Aa0OMckgqVbbJtm8MSrUdtfwyt" ..
	"i73PE78Gv7DBZfbgoLJG+T0MAriLEnDNL0+aToNpZsPecAGkxOBRFg97cSsetyMQVocafgUxJvWJLzpNaU+4HTp6DCs8mG3rpXxc" ..
	"X8Nj6ise6TewFW1HOCRh2Yy2v2skD81LvhmXSy1V0ERpmRTrBBEZXx95XmoEx53SiRX07+1Y+D7cjylpRFU/pivcVPQH0aG6w+Gs" ..
	"wvjzvkOBE9W9m30y5/+2jNRT1gqtBPU52oiSUNXPr0dW4uivjfEPduBdVAVoULxQzeVK7KJcsIfnIVhGMMywnmLeNzW0rr/xGCRA" ..
	"vAfGTvbfPThNpREJuNUoidulswLbidsu7HxQs8zOmhTpQF90LQBFlcIGET6wBgZVu1HRnEPYBlIW2MyIJBARS27oKeICpvUPP5dp" ..
	"bEO7EvHiXFfX7JIh9TE4o3FwZCStEV2gtnPcPVo9HrGgljTKbtcNOazMsErYpkuCfDnTmwxLsuZd22oqE2bTHPl5FVSz8znOcZJO" ..
	"j3TVVgupc7Hupj9D0ddwKnwnuLxrxP/q928QhyoPA+WOrV2634uxMUqZCjCjlNsAZsXq8V0M/HQfOif9W0kr4ZYF0gX1curEAOmX" ..
	"novVHfcNZyGaMlWpBt6cPfOSfmern6QGaZ/2KMRDvue/ihJamls587HR6PZ8rGygztEKHNmhpIaNkuHYl061ET0+N/NetW4vHzSf" ..
	"j3vJXJYX8wO+eOmkKL4pwE6TMq4zL5zR30AXBmMt2+uTGqYuiu8B8Fcbi460yVoLTdjAs/YozWqwzQ0FE2lW2LtGaiQel3rz8Vz5" ..
	"aCOB+j0gZpiSPKRfLE76SbYCRxmoj/LJHz9LopZABffjNPbgO0poeU7ez2lMNx8PkeC7fmLorgd7obZr/gCXOcWljH6DtZov/pC9" ..
	"HCwMK2kV/0Ipe/KFJ6ZmWxacKqz39wbwyKSvoXAgBI+KaDXZ88RLdYJAQ/Hk+JtjZvQlheT79lcsAyZsJSNJf1V3zt8P/EikIZVx" ..
	"7rvBWluRcRzjzhPoaBFORxHO0CcuSeWfD7H1d9XP/kmgJHHzPTu1RX72el7BN9BFAEsL74xs1FVk4WCfXPnA71H7o7Pb8sL+ni1U" ..
	"iybRh1u1Q8bGCNex6VZFj3wO7KtqqtRaxrzJeBcGxUW5zXdJqMFXa360/OmhrD7CA1ZD49iydiwh86G57btSAQgoMntiaN5V02RP" ..
	"bcs+sbCcTXPjkV9VDzRShIAtFSzJolYAXPxbOvIq5GY/gFZNjIYGAoBIPBe8/tDgAgOrdcw2Nf12mZgR3kooIjcsxxS1EGdoQP5p" ..
	"S8yR96/PcM7VXlfIrOCsZsgBPML53R7/zhkk4Z2YJ0FKdP86LS28TnfjfXtHViI8l7FaJM8Ua05MB1I/oy627tLEf+XkbfzrD9jB" ..
	"a5Foetf8+qzOTxKajVO5lWwxdZPrH0koKQndJzo7LKQa4m/mEtQe1cPagKDyCTyEgU4kabsSAOrBn/9Vi717hr5piEgH/6EM/is5" ..
	""
local PAYLOAD_P9 =
	"K9ppor6MklXc9ZmXK5okWzUsjMjewcg1aWHUshVu7imLGL9kTRNV4F2WBKuEhsudL5Qu2wFkqieq7E5BLYccNjyz6BSKTQj7zb3W" ..
	"RRktUfIjqI5ZD9AKwAcQWN/CA7aiIh8a0kU1NnuGlwHNg0tKV+t3Lu8d4+AD9l0Qk+ieM4DEpOFcG9pdQdFhGBofD+L9FmrMECTz" ..
	"VDZaT5LO57jJE8fOynhbhJjKRsVBPiaidGx6luX/8TZXAhkpkWnqnpMzu2CxNmxC7DjbXS5pFCGIDFRARSAEkqsZUkcmD32U+K5c" ..
	"RfAPZqj+h5L8APTYGILw2ATsUIYo6Cm/PnmaP0YxmCJjdlvSND2WS6Yc5i27vsNwO4FpxBwKAFQtHlwHRObFnxlUBM8blsfYfnWf" ..
	"xHkgi3irN83um4SwOGE90iA8TPCSf+yfV/XGpBbP502BhdS4P6sFxl46VhRUT0nuivQXpeXiiHQ1IsaYN4ADQ/CNGr6tdz+/iaGW" ..
	"fLHqsz4WSUC6wz2KFxy9hzrYo3jBPL96P63kdZYue2l3NKkgCqJeFkdKW1F9JpFobfO3adyejYUKMm3eCwTPnGKsxQb+mueHGYHB" ..
	"HoNH3Sn/ia5N/zEXz3Y3h7kxCA6yYDQ0kzOWRSfyi7D8eSsjQ2+gkEArqnmzNJwb7Aar+Nzf0b+H7DH6l7qV7/WOydoG+XlBMDpo" ..
	"YQ6SytdNjFDqbO/jLlogQWlHUUFQrmmTXa9VnFGDM/QBN/hwhqfMeFLz5kJHf7gPkBIOycYOvn65sWJ0gGSsGKKZgBpF+XHTQQrW" ..
	"z8uEE9eTtL6dB9Uk60zw/GiNTptjZwiXlPJUX87PRxRA/5hVFjluVeGlOxXpeEPuprUQKClt9cczHW3egcEpqZt+SpJFaQc30zyz" ..
	"kvT9TA9XjqQa6H9D+AhiG1GIDztMAMPtS1SipRcyqRRq0R3fVrmsPr70SIjwWY/f7VrUOHoRgOAHPzWj1x7kyMbhk27fw7A9F7Gj" ..
	"tvFd3lgbuMNvGxEaNbhZ/5fRGYXgGfIqR5a19nbLhhVgxgk3HNjEvxKZ0wMoQ0Y96dVQvKjjUAh12QkY1CPNs3yqpE5KcovSK5Nd" ..
	"RSeVM7aGaMmVJUCyAyLugfahNtWOhtAphoET4BzpqO8r9M7qEw9x77WbRsgI7P9uNHW1Utv5bTLHFkvyKawFdt+N3QxhOEehasbJ" ..
	"PEXXdlB1Wym//ObJULqDbeSF1I7tjaS3KJYHURI0bsTKVizKsjP64Mc95BXm5ONXBrVu5E/ApvG6LWP/qC8aKmHxOcNmkhPnux73" ..
	"Iofsel8NEA5IKBFVYC5SzZieBNr/JzgF1pFOXrVwx+QD3boXO/kRC1tdFqBhIQ1IVfU8oLoRdhX9Pit0LZVowpHDo8QszkjMaSFY" ..
	"EDG04FarIALrSzjpkmPcdGX3XQFAzueb2YVdLTqFBljnYICFpJOiBqSTqoUSnTH9N2skBpSawYotRL+YM8+VSCmr7WknafPrWp9S" ..
	"lCMbgkRVTHAq0QN4+UQzUkvdX2UTTOkZrfIl5niRkdy222lu4NVkPcWoRFClaTENkbp+mU2QFxfUJxcj0ANOE74GoPxL08gD858l" ..
	"3rUCTqEVJO8TM//97vxEgda/c/agfSoheoBsMiZ3ru+mptnx1mQ+bR0TYs/nnGPtAkgNt/6vv5C8Rjr5QSFXI84Xt8WCG8Cw13aq" ..
	"wF8vt/BrWoseaGgJF6QwGs6jSw2evHWQ6xSzJ0V56pV+DMh511z3Ev9gWZkGFBq+l9LYIcvcXwIBeW71nAoJfWr62EjrUMUUSBvs" ..
	"OyYpZPJ2Kcfnm+bMNZ1oprldqB2FcCf9n/CatIJyLBsBK83zuGC5F3ImMc/jEeHtyVYM89xvrld+ih97uXcfdLuYHgF6W53cb9bo" ..
	"FbMefhuQEpQ5XmDQJGkOAk/gEKyFSRF1fFmVxPAKMCN/Yo1mlCaT6vBAOTAVANsUC58MvHf8ZTFtWJ+oW890GJW+41TJpCpCXe2+" ..
	"TneroBNBBKergqck/yU8ic6unnNqi2qdgIUdn+1cy5urfkkuWJOzhEZAc3Gzhlin3gzLt5jsVrpK8Dal5PZqypKFkcksvDbXzU1k" ..
	"ovQ+95Q40CtesX3qlUj/y221wLEbaWwgBzmMJqnpowVqjhs4eGIShtOh+nbBiFakxYDgxuGw/evOh6Y/sk27/PwcaLuZszCvtihR" ..
	"X8XcE6cORsf+ZUG0rfc/vkNMcy45MfEWLK8b0f9q3XTUcjVUMIkSVZAccehzHRj1bXWtawrfvxFZmU9+OI6y0FsGM9wBeYq6Wx4+" ..
	"4fikh8G35G76K94VfFmZOcpVkX5HhH5PIlVIW0vcm8gZmtgNsHcbZcNA8qH9kEyqLfMRR7h3mJ+DxIPbrcYA8FxO7c7INg+rArCN" ..
	"H3ryAno49Qx1HaNnmKKW0bFkVp5+atwVRuFwfozYWtk/xSgx7EAVnLGuhABhDOmjsZHYzzmfChY9xyZJ04BAzxazAqC2hmtdjk0y" ..
	"mIF9pVfpD0jJ7DfYr0FFPKZu/JJ4rizan121SPDn9s+HzIB+28FMx+k+0Cluy64zjofcVUV1yWxVk4YkUMqxBkAJ3b8s23kvsjn8" ..
	"gxZHKnTdkpo7WlmtwN37By1nEGDsOSm5fVIT1Cn8pNsOb8SYIaTzpyFua6mer+lG+WzyAr6dFmAJm6q6uYOz+OSHzfkwPKWvEKoA" ..
	"BITrSUBlBabo/D+Hw3eUfom6t07UNNfkV/wAdMno/TmJ5N5+xUNP5S1U8HZGYnpFmLDBSm0A/B4nK74gz3dP9psYBuxiWOreLNRo" ..
	"/TVCauCMj9rggBAURFju3+RPI4Z1zO8FbPT65xn/9ljHE04N4MK7pPe+QsHLX0v98TR0r9bBUPcCt6B3SyCupqggzezihGrfB6XZ" ..
	"mQnwLrZ1VsEgoJraRW6u1ZVZVxmmZtDNAcQDc5MT+gWnRHgt/3RYyf7T0UZ/fdBHjqrJmh1CjOdIwgPRzyuhcW03Iu+6wYprei6e" ..
	"DfWsJaOSaQJ0v0fm/9oOfoY+9Ag6lIs2NWOlz/s4xuz6g96LuQ14uHc+0D3khxK4OkLA3HL6SetVO3WOlE8/JYDkTI/cd4CFmdRl" ..
	"I1FW5Uu7yB2bpQOF2BW8tVRds9tknmykfKnKv6YPp9eVQPJctORro4k6BO8mjjVYD6NYecZCr7YE4dipBk7pXP+8oxTFwrBnrjLn" ..
	"4pTF+cy5MQGbHyQQDIZaLpFcLLtMw6CsbZe3pWKoSH7lsYZB8lj//cAqnW0V1Jp0qtm7R0zDzyPcqcUid7m9rFSGR6OxspJ34bBB" ..
	"5Gr+pb0FD4RQDEI5a3yk5qKuJ5fmdQPO41MYbfIXM+omNknNL+LmwkSPoQgm5BxGKxYIhl18FBDzppRb516Ke5crXuacepsF5bHZ" ..
	"xVeiebYNC2Da6CM23+EvZRRahLRQofY+n7SwY+SwvzG42rbO/HbpABKvjqyaf3KbVd7re/gk1llCdh5XmBeHjfHDIIQhpmpuSQJI" ..
	"VOb9Kw47bJGlg4SWFufqBDGarIaphRkKbch3QKT1E9vYEurs5dwGZcoZ/q7JA6q9O+pgZZJbxnqFceZN3sTUpsRWJmX5x6vRauEB" ..
	"9ctQm2IrkFjDW+FjC1MKeW0XLSWJm3QRQIThgG8fJB31sBd2E/QRfnUo84Z1HdCvnuRNoqLn20Wac7QdldNsWOUByaDfEqB4ANE0" ..
	"0Q6Xxjv1/brK/4PHooh6696GFjbXulKa7UsjgU3XzRuUHBQ/y81Hc4HeFzsMSyzhdsDKu5cjcEX1wgMkyQEoUJdQArPJzh2waLZt" ..
	"iDTSedQn789OpR5UQ8pDKhcCr37mehj0fGUsnYMKno7so4teIXl7S/NqX5sxEY9ebFh7ZKDuQEz5/VadKBfOXU3EtqSYoYt3Te5e" ..
	"a3Q+vLe7o+ExPuyDxLmWSaJ5tWKMxz1mI8Q41S3I5lbLemO1MJkXejYuXA2CG+KQntqRXG9zwQo2iM+9/2FG4f6kAFHql/RAy+j1" ..
	"V21LD9M/+O22kPw5LRRv2Yt8m+P8qUs57pLZhQnZyUPh8ZGNP2yECTvCWnRbv5sRcvqrofg4hxlIFSSzC1CccQfg3UNcA8XGMxqM" ..
	"hS6aas9R9NOPWaoW17HIlY4W945LWOQ8hiNcQN8HUNJ4z44JuTMgJDx5fHUa3oeZRb9D07CdeEe+FbnXAtuzByzN4xqvgTXL7UPP" ..
	"gyZetAzz9QTdlO8v8QUIExrRvmqe4oXTAYQj+k49ojSU/DKxD9mwAiigIPmd49qDVAqIFexYOrrGylfyicyS3bIw6u/Y4nn5FJ7R" ..
	"Lp+D/BTu4Hcfr/PH0+8odA4QfvLhO0ie88AM7CAVJK1GVfYrXKvfBM9kQ37J7F0SPs5PQ86gwrxtbsjKXcCOIhmTsxgXq5Du0oDI" ..
	"6/8Rjp7JR41VgBGQ1FbXk2nyNFUJbFPUEPVr132BJzbZgcf/yrzcg1mi5oH8DrbkVG0dpvu4Bs3lwfcrXdjPQWmLJZOLp+2f8fN2" ..
	"WBeFUHd0HPl86iDKJpdPvBsJKMrYMdHkOtbUadrAw9UstzkJjbHgX3DAKuN0EDHVv+XXZwVYESeM7BXU9bapPPPPH0zm6YOZZ5+J" ..
	"Kv+jMWauh5leYo0eXRfucBqBvUY/NoI3bJ8u5J7nZZDwdFVXCgvjlrkybwj71INGoWmA1mhOy7ANwIK7TgB+79iynhAxJ1Xv8jWM" ..
	"N9EhJYhl0ZRETzDn7RnixoEdRMAqVjzrnsYKAeiSOQMEzybz8BBx27GNbmWyoERr/rLPy5Ojxr1q3+RtKgYKjnVoFuA6PHDcZTZP" ..
	"gLZxJjyX5Oi9L89FgNvkZ0HaT033WbQntmTcm2UkAUaHkzOKZG9wGhHj9XSMhqYcjArrs2NoyxEXDc5SQebOjYZJnvnMAC0ZHP49" ..
	"38qPO3nYZXyasDfbxpvhstpX9RGhZRSf/u8ls9gUWvEI72w7tYu/XVnzTvuAwn8FcperET4adR+ttGdh/KLdoUdDdcvucUBQKhFi" ..
	"kNx5cZq/ZF6Jed4c6g4ib3t5JnHqzB/8RxmkLXKaZa+yEyRSAiHjXFLGh5YhZJvq079kgZwtBdE9dXetYJ1vQC7cXFWIgbJGz4P5" ..
	"EYW6oGA316VYUxv4XUWygDSuTMN6hE23xzHeaLPctBwjyQ+dOmRQknXk3WiWbwH78UEnQ+xRMY7K6bFMJqXsO59Q9loIp/v9LIh0" ..
	"NevysU79ForKe3nWjrgGWJrBP+0/B/HrWGQIo8jKhWY/wl3yEPzeQMHOXvLtha1vL8CWWSg0NTqPup8jakLQeLM8kzgpdutv0vS4" ..
	"a41mwjKShS558YTMMTNbBseAtDPMytjVZ/34l5LVZwI03vlaRcyfyn2pYd1QsEwcARdGsWqnbQAf/E4Dyo6y5hw8TkdBDN/Ep1Us" ..
	"CXqKke6uGx4hUN8NszRLN1iElNXcZhtKMslWU7uPvfdlBhWhgCHYS1Y9nI2kduo9yc56lEvLoJyODRnyDx8017XM/aysewG9qYpe" ..
	"cBfB5Jvpm8F2s/loN/U08V9gfKpBGYYfiKMcvDF1Lf0IgIBJ5pLlA6YzWkm4o8PHxY97eCRjym/ino8+iwox6Uwx2AmGVVv84yyU" ..
	"2cCrbVUl99gxImZvAy78sE9UfDznQIgi5NXw5ht+V7G6qoq8nSGRcLBLb/nUD9bDi6i3STrshqvvviL7FfItVZMyXUqILXN4Ti/F" ..
	"vE+meCkRFdd50DZfjXxmmDTf7pT00OzYzf4ZwKEEJZI7wJeC2ncAlEL5BaYEnL2DojrUhulc9e12znA+7HaTpkU71huYpw8B5FdY" ..
	"Qf+2eQsL07r/OPhJLuFo+MTTuMjLbO2dnUkU3FRI87MJvmALl/RFS41813+q43aR7PUMh4CpfJhvuFoqMkAOYfL34O6z/QsufB1K" ..
	"KjXcLr3yuOg2bewqgSmcE5EyllCjsoaDvXnUm/ibptHmlwHz48QOMul+GNI7uPMuLLxH1xhRwAARIGaQQ+SY0F+cgE0/VnVTGLzM" ..
	""
local PAYLOAD_P10 =
	"vEgPrvQzQYddYT31A1cp+yD/kpbWeICGpPFnEuDW9NFHFlytyLqSqWizqFpmkj9h+/Xi3KTUJxjT/NfUaExIPt2skMB2batFfuUK" ..
	"yWMlyD37N6uOadRZCfsjZdNGNvVQlc/jmWNdG3AXhKPIKzPDhpnGdJLZX5w0Xxdu5+Bp+fnbkuvjxOinEJbevs6c2V3AvzTnOell" ..
	"/0Uq4F/oEc2bswuOSAhrw3z/pDabV/szWUbIRJeXjoUkvKQ5D964OG6eGiogPQ2YPEc95f2KpxogK9D0DP+DKXNrlmatzVV5CwwW" ..
	"L4z9oyL8D8Zk5R6/pKBjbzHkwFFOrDuJIh0vaKXNrXghUrf1QqS7EQpyyM/iYrKud0tXMu/HZ6aMg7xOuuqojKsSkwjeevn9AcPU" ..
	"tOOXaTTMofBCl5PRUsJTByi09X1y4sifCoFix51ypZkXW2gF6M3ym1UhIxmsBtD/NwMTX5odelJ4qp29IF6GL3qjyE1z2dI/S1/P" ..
	"Q6hGM2PJdVGap3o5YPJLcep2sCMi56Q++L8C0uQnkgLQkQztRyBtOt03eQpv8hYdW2FmZyCqkRcQsQ7DW74cThTcrc5uF9Cj+0m8" ..
	"LA+nc5Pm/dkmM/xAObJKFQEam23nv/jAqrLCdcncEf4GHYNbr5ehOwo2ATWn71+9T43ffAy59o03yXd7ExUsjaAC41T8bDQvQbB2" ..
	"ce38JJS5EKKYSKMsGrrFt2R4HKGlfaQLp6cnYQRQXREpntDeiLZP1WNUIyCNkPV+pjQGgeCgQUXQDwY6z1EcRzgH98id+Es3Rnwy" ..
	"VH1al7fMYlzmaKvD0Olym2xKCkIFWacCoRvKh5xbMd3F99pYw42qZJSDsP1dHLREPo6g2z09iuR/GUltvbtzx9GY4pwSdmxNluDp" ..
	"W5T91tnxVyb3rUt0/9zgTTGTR5CaaGdTA08SRKXKYWyo84fp1hEXc4PswLRuKHAlc/gTAQ7yHgcoNOoQwx0dZUGcz1CBcXHPI4lc" ..
	"Jae87GCYPuSWVyMTHJWkyrrGWc6BZZ70L2GxsWbCzG/unXO2bvCoEwk11Ulx2oA4BadQfEzh9RPS0/y6hYPFOoo3rvhoAUwjHjCw" ..
	"8nLwbeK17DC1UdpOY7v0YJZzARwA8q1HDANd3Anxkbm60oR0qoxWdEjx8J37dUGwVzbgSqDW7XrQpV/kIcoFEL6Zuo50vDd5K0yo" ..
	"QYGKEpL9tjL3dRHD5jHEQNdUfL0LfNgieKdKh6qh8vE3KeRSVqtkRfsW3waKs/hZeM5vR6xYWnlKETvhuGGIsQU4yx//jSy2pPap" ..
	"ho2+nN5vC/s8N+mDcB8WKTg83VVAGk8OEKdw4u0TuPbNE3UZdPodow0OdxI/fjNC2J6/cZTNLqa0tuW0mLBW1NXapISAciIiriJm" ..
	"D+xG5TUVF+iaZprSQmscuRGLsYOLLQGImsDp2SKrnSqG/zqnKPtQXSZNPjOXloNxEv5zBxjLIsVEErSobWiHqli//pdXvQwfQkKp" ..
	"qHv+w9B1/upRtZBXuEPd6v56cFqgSLLjMTUQz5tpq1VSGSj2ZQxvP3Fg9EXfeKxAoxyJ08JNKCe5nKYOz4VBq+47VQvJvkB7Rb6m" ..
	"PUnFNPyeLcQD3n/Bf7ud7MLdVDwXHmmH8jtcZ5S+7DmlMffSWBlz3F7c4RGUnhShXlyzLCayaR9fO8TpaNoFZDi4JQliKs3+mmUx" ..
	"eQLEXr2u5wv+HvnRBUyIGfYvHsiApGJcKgiaiGlVR1rsp4fLnJ73iCxLbOvzsUejidccJzrxlJ10CybSRY0IxM7HmZNY79Fr4qdl" ..
	"46ZBW5DkG3IMkcByU3B3spwQYbMrBwO3rnQh4ltRkQclCsbdnU0CetVIS20Crf3/esrA/xsivvqMmeQi7SAWh89OchUyuyikwrhx" ..
	"bTVJ3dMMdUCFuYTjT3xmZJF+Vl5t4w+YuRuj3wTXacXsIaaa8YSbPleehb1pUOM8AjZpY5/hIZ+Apdw+Vi3RT4QqSVuQjzSkxZho" ..
	"f20BIKIPzZeJSBDB9CTo87TuuLP1DpvezD5ml0yth6LXkwCscb3ZmeWXsMsNymuN6YTXVzYAHfr5O6WJgQ6rvSUojwWKzQyuSoq+" ..
	"VfV9Q6wmhFWWmHuomkXdMQJ+wNWH+z81GRcmqrGDikDm5v/NQifAyeBN1yow0ju4akDFqYkdFPYm4PLSv9sQ7U38oBo35Pcgypaj" ..
	"IRnNqiS+P/dbe70g4vW5goXoqPiflNeP1K4l1GlP2oDGoTTzvAQpcxoFOlN9KeYvHyGtKFWykT2rnpk69+Dh4xMAY68s+yx2YAZl" ..
	"exYbleZKEiHac+ZHYD7XBmlNb8FMfsEqFelArl5pefMB/vwb/hI/javFhxaSE2vPK8I36xQevifg21+gJt5+YiB6uokzd/TUBZpI" ..
	"97dpl90gH87xXs4YsFoqTeZSBv3f5p3xYn02YMidEggBL4ZAT1k1raqg7Jujfpzd9zqHyQv4soH6pQV55rJ0l3gwbfhlvSW51vgK" ..
	"25QBRcIdIuYjdNh4xrV2UPwkSSUWEzMexCMgEGeCdTKIKqtRJ+9QWN1YTXrGw/gWybqbw2m1E/i674RWGk0lAEEVzVuDmQsmHBw/" ..
	"6EOh8C+7ZnuisHCI3qH4YFQR/y9LynuoDZrLIdeZtdTDc5NNllL+sYbRwTUfXq09k/zYpdMtqdr9+fH/SVD2GBH0dfAQP6bAMe/i" ..
	"0omommxE1LeHIvX+JwOLhPPUot+q5K+gs/8WW1wcgDuNCFJrYR+ZCkL/MHwtPGXnIhJ6od9leF4RpfcxwFqyVEfFcglVQ4mcr5sV" ..
	"3NRTuZn4M622GvmzneJBinK11OPrrWvl2CDp/ryMi+K1OrcGJsJkk4TBcbjSB6eOO50OE1gGsXtAmmSHz1CW4rrX7AhEjC/5sMmv" ..
	"mVFISezL3pu5i2fSKhyMzHInhYsO1JQOz7fDJoJFQkArZ9m/4AsjlRJTQ07vBDBUpWnTPQZGMbXvYtWX6jTNNNS2uuFyjvZxQKys" ..
	"HvAjF3wuyT2YIldE+uqQmb3sJTCl5tIqNvJmmfMTB9Ybe0v7DgTc3Myd6vEos7GjpmkE0EMpDpNfeMnA6xy1K4OJnOg/59d2GLQq" ..
	"ta475w8Q4F0FY8IK3G1hnMNqSezPFSKyQW6ESLvf7vHETDtssmw/8k0qg4R07Q6CYrTWWBdYXd7hi/ZNlTUGBgpszGKw2/EYd1Cd" ..
	"GRaGL7nxgEfmOoAA6OjAlFWzLmbwRYXH0Xz8HF0dCDGkAvh1s0m9CnxZzQMrmysI51RtsJHpK0mKBIAxz2RdHd3kkdMc36pDK2dZ" ..
	"EV6uOuMcBBxar3/Ugh4opEiz7uhsPxy7gX46Wrbi5qQd8tsyaOis5xY/1MNCoNJQ+UTO9Mxzu7fN962bLVEBacQilcgIdMknUOcl" ..
	"6iohIUeDeC4qbDK5pn+CjrWSWufrgF6hbIjc718sT0O0hfDLUEsnsEoac1dXpL123AGYu40Y8kCX06DLdVn/ObLQ6akd8edCwadh" ..
	"sUNEfRJoFDriOiP4OFFKdtalowTFCvOr9CFBONL0I4cvYto5R4mqKQyRmTzrJlaDqFt6dxTBY4WffYy7cPuH3j5pQsorHCbBRh6b" ..
	"eLkp2CJKTkkE/H/kWeZmwFhCq3V0zH5Elu2GPxDrZ1Sn+WVvqdC6IaZ3VkvqQkAZKYGD6FVvuRrS1NUkRCV0zjl5xa+48gZG/YJe" ..
	"vzn26aRMJwMrLuJod8rwkG4DpAYNcBqwY4GG2p6BHv0BW/o2eHHhhJX0oOCKtQiOiSd1q0mpW2Ki9HGAnnjgFO61fYru2qtOAh6R" ..
	"6sqKnDYfgpLnhxh65MqSOdQaiCwrMvSThmKlGNusT3OxwkwaHEHTaHBlzWDyBf5DqDdLa9wufYPB3ufWEqEDofrlXhYH8oewg6+9" ..
	"GxlSarSEGgw1OdQtYB2j4SFhOJhTVLtMpqXuSN1l5N+sWRIJp3GJ5D6yR41c/AB7+AZFd+WjdpPxHeFDWd9Bmx/Dji8rdXgozySS" ..
	"f20t02TXf+PoLRbY/KqgUdK7b5mHafO4Smib3aPNRZRjhx6D++fmyaK4ArMTlUs4vz2gbZ2/y8dzqBp1/w/k2l9DdsGfHxhMibzS" ..
	"VfnXSsHtyFeA8rnkUz8YbH7v/9tOWZx2QxN63+rCCYqnufAVnBDtUM7Sywn6yjT1n14i794ZBxdSwp7icoOmj+tm8/+1hE57A4N2" ..
	"VbGJpFp+NCOlBsaAim2Le7O+coiaJMfv4qFU4qTrHUpHkFKk2u5vAX34QtgLx0gdrwC0ZuB+Cl2VItvZNQA3VIJSqv3Gsz5Oc66n" ..
	"FyepGHnoqEEUpvuU8pkxLjNJxFqy5GxiYkm//SgseRGO2GR8YhFBjabiReTs1aEvAiY0+GG/lbn6HTnjdLNjIAi4uD+eLArOIBF3" ..
	"u/ONAlgZfSCOgHz7Cn/aZvwsIppUS/6Kpkbr8LOQyEWlIoxG6syujpWixxcEvspraIGJdQMfKKBuvZl0azUn7UL9d07RU82DJ0Gu" ..
	"FBDfBhZvDszb6TFp5tnyDiodM/qgW1PLJk7AqUNOKhM+57dHtaOCeLIcY0hnqYTgByi6vmAkjAqaG5hBgyWEVqSuafxJMFCN7FVD" ..
	"Ud3hj2szoH2KcldhrgaouTopFBvgEfkMGCu+CQhZPv8VCDRVhgTIMnItkd6rTIdyhxosQ+yAwGIGqR6zKsTfbmK30AH95GHcv44m" ..
	"xFGZwR8Mltm7tdvO8nz/tUZZnM4zxZvAwGzM0RJnIRwIv5oN4uYiQQ7AUWVA2SYD/bUJ4X9jOYJdW/9EhVaNmpaj/6FHLz5Ecr/K" ..
	"DpA1i5JI5opwAxodheymtlhFeNNgawGmtbHRG/zFpB8OWF53XgWMC1q2f6hvCQEcH9cXJUuXsr6yXcDJ1QREgzx340F+6kU/UlgN" ..
	"8hGDceNkXr7sjTm3xfVsKKFy631MMsVApkn29B9TBRLcRP/YuxhuzGer7/3g983Co6207p8VJpPO7eu3Vy6elQv0pVwKBhKHR3Zg" ..
	"3fvoXbx+oO3McpSqjsG+y+Dy+iSG/te5lGbLVJdSZcBTpcEcJ5VNGKQow3FvAJ/HEHdHiMiQOHOjunp8RX8XO9Y/xrq+ZOCx7kNz" ..
	"lWbOmt9gs0S/ehtsZomIlmcDLTiedvjq24l57LmHl0q8rLzJA174V2/DfQLFU+I2Yd41iQ6FgEkDbq+NTU4phZt74m6zU4Ii7Irq" ..
	"a3QqQgdA43W9yuUgy7w6YiaffZmc4kOwfi4SsZEVt3UfRXJ0raklIffgp1IX6cH0uwXJ+CqFVuIhP/Qw31PhhDBdrWL2xXnPz6hr" ..
	"Ko4NiJVLbifNKnzjxBx5Gfr8pmnvMUbDflLuM0b1XeOVFXEThApRYbJ0n817evC9qHTsKFWhlCIO9z/+lVccrLEzuekcU10wExxU" ..
	"o8oxA6NNLQzkerZI5A330bFyX7EKQY3/U2eAtgZU3WR+PdnIoPncJVnjuA94sTqz147f43yKm8Ogv4jxijdqIr2jtBx83w7zow36" ..
	"iXt3kWdIIbZzgqnJQrPvtSYQwBKLvc9eiAMvn2UcFZn/lUKiEfr4eIy4ID5JWmAr6JBfHiUP46xZYyl3m3oR6nyHqvdRnEGjicbX" ..
	"7X64TNmyF1EWa6P0DjuxWg5NaADRm4BZW6YAmQuGGhkGJvnyvQ1SMcAEKG2my5iIm4DjXr+0/9N8ZyWMQ1mvsyI+SRcpCRr3FfdG" ..
	"XSP8I7Ys7aD+pMxDEFiziXrMv+YywSB6288R+FmS+9tGQ9P/hnoBsHKGUdgw47McfftOobWdxYVrwfu11NBdYA2fK5iaVWIl4Fzp" ..
	"wuJOkfOclVY04RBgKR0PtTrFJMziUOv/KANIDsvoO4/wu88eFeAnA52VWEAws0KPhAy6GVBNSE76GcnAF3l2Lj9Lu/eA1iKdhlzr" ..
	"19CpHcX5u+L8By1HxRvslLwQiZKOOkKb9vJEOBzsoU6i9QHEafufa9lYVc9de+u8LfSeTkhj8Ki7CwbdjldEmx9a9AxeQ/Ro7HBy" ..
	""
local PAYLOAD_P11 =
	"OaaDp/mG/w4wj5hXJF4foQPybtSwfxBkfAWRLX0yoWZhmsLk1wkJ3cx+cpyhwCFGRAGAvREOWC8IAmbKeE9SXi7lnqDCccDHCA7i" ..
	"bkqk1BEDmIwPlV9CZ4s+f/Fzop11peBrq2cOvYrb6zdTfUj9X3D9RVUd6BxJllkqcsHcxUNdg430Fw3DIA1tDQHfLz4FlbIeMdKX" ..
	"SiAYYAgtAh/Bssyo95ahEM+y0XK5AdwilaE9mK3Mn3BPPvNEwG3z0DaECKCBYYH/PQxyPR0ndfiUL4MOyhKww3p+wGTikRgmM8hW" ..
	"qH133cjfVadxKpVcfwRbivGNmI7y7gsJ7YUCGbX+Ugq+U+51u72lbU+KrD14Q8XN/VwqjXrzth0uaXUzypVtAfp1lLueFNgNM2CE" ..
	"5fyYX/uy1ly8ZfP6P6j6b2M3NcJkdwWtdQb9HwPazhZthv2eqXDmGcl6bDcsuwdM1DcFZEGfPixU7D8cyV5N1Wj4Rk0/jsuwlcli" ..
	"rL5D+32R5SKoipyYfnyumoAMeNQoyrloTkIV3PO9fNyNkWQqd5Es1lDOtvdB5nCpwIbF2DmpenMK8Y6bdGOEpfls62AtzuzVMzTl" ..
	"8Nmqk7ljkDMU5yXuKt+m8R1BFgY6Hd7ij5pNhAXjl9azthKLUh9Xj1r7SnZYxK2kHg5ttl7mBTk63iBL1w6BUjW7XrkjtKjy2iNj" ..
	"h+GECP7jn9M8sijUw4EUcfaJPDL80vG2Xe8u6dpESbsUIHbCKkjMFx4EsSRU6L0E+8/euLGRa5LE17ayOVGPR4tcU9sV6yqDPzPU" ..
	"LymakMHsNqob0QqjTIvkG2Zv9i8Fi+OzmjgQXzBHHJEtRejmo2/A/egGAkuGNd/G8QJX4v9LgRYwCtrFMhl6FddvTzj8pS+q0o/A" ..
	"9n5SyJQgdp2GIhRHbEDBknmGNqi0T7TUEqkhizXQG2gk9ieB7iyHPDkJKj2INg3IpNXotVh7OwzLIOBapwnlec2nyJBY6LUtlkTR" ..
	"yB4wra4No4KWaszFRR2rrzg0lNQzZZeZi2vA9murkpE0FKLxlJ5cwJc/2ZMKWlexx/Spa4KaYUuRJNDJ3PzTypjq6nClzCSselpf" ..
	"ntv8pu+kkDhwJI5mhqHjiGOC6mMv3rtiwwP1+UnWCYXddByZ//vwVW1Cj58ekcnGn3Qx6bMECijUhOT1ptGzugvzUOQZDt6BePgY" ..
	"amW89gYkSSkjnk9NwvWq+5/8FIx8c+Bq30EwoMQYqbjISacRFCYQdrRvqaXYpJPs/l7mfyQ0XZZnTp2bGSJpNwE5h8BRBvEIoLDH" ..
	"AGLGeu6xtDKnS1TMimh6AiVk747Mhdehi7bg/8be3GeQkDe2E4nP80Fl2z7LgvWiHSevspip06cjWIV2hviCiYPr59nTiyLfq23s" ..
	"EzWO1q4JZ1CVTQ0E8P9V92VNLArO6I+UOeXiv2VMDQ38874dQZ7vRmZiC90KEpAG0M8ogo5go0KMk62mnIN+HWhW2MmPPpkSU4DS" ..
	"r9eDWIACTo045mI9cfUI7/wtjObcigmicM9k1DmGKhX/N2iIuFRtCkdosUDQT404d2Hxu9+SPvRfBUqDO6s2UWzTFX4NaIRWcCpY" ..
	"Ow3mwLvbZBSW1MUrxq1cgDEGrEH9CmrBK6Nj4+1Y0O4YOl8XUBVkTaTse9CB/Ao7iX1dz9QvxrbpcozFUcDdBpJxtmib/xNuUfAG" ..
	"bljJrn4dB7VLJkMLuHeZsdcJs2Z4FKFmqeDSOnRaGovD38PKB4GZJBwWU0k3hTA9XuTB4dYol61oFx5HdBYvp1SSNWqWxtEg1QRZ" ..
	"96bjGnuAM6spXfwpKL2EIuQM9e0ikW9DFyl3OkUZxXLc3XlW0b/oXO97R37h//fi8QNNV/K644n8SRzp5u0pbmBEU01gSmPIlwzr" ..
	"+2xoujgfxdnHeNJW81r9we6I/D/e58F/CQ1fsEKgcLNGHRL0SOhBkn0t+kwOhd1DlBq+JIXm9KnRhem+x/8DgFDXuJ42Cc80KfwT" ..
	"Z+OQ6X3bVxHypogamWEBH6u/dRlbPdp2ZQgQVN5wfwheAoDnIGfJnj8jySHSwLpxAwHBRm0JDZ3xPF1d3YdG+Ju3R+Wb1gNzRPTH" ..
	"UG+uJT3Aa48wX2peZ7qNdGaiER67mT+LcTKnfI4qVA1yt7V8/Y0h3p2bhlKYRFpFIixv/JRpmyyexFcv9UV1AMoRktq9zMGO9CUw" ..
	"SqwaJKAB8cPoUIWwYPjr6mxPpLt7MxNNL+gI/eBlyec8WvDZ8w6k0rp2itQJk8pXh6MjGl0mnOwV1cI+u4IDKPnIrOmLhZkHhAKo" ..
	"kRMEp9v3khkDgsa2IxIvgSefdR0X5po8iG99i/pKqfsqNVdXsBimtyxtRtVcoGGqJxigEh50OnRwT9U5CyYKv530y8CuFYnzqZWB" ..
	"SYXF4BaIq5M8iIR4SvMLU2pSqIVbDfUIAmXP3vlpsvU+QYpsjTSvYRgPBT3cQY/I3YFynMQtrbqDAnFBdBugQUUShmm6QdQvJ+UH" ..
	"RO3DhVO1u4NnQglWewEm+rH3TEdpk+8DzBGokca/j/a2SPwlh136aTR08ia10R9ed3i7hrn2gH4aSYolQ21z2tKJlbY0dp2ZQtnW" ..
	"ACSRPbSHgHv1T6L+WlYmoKh+vIeDkd8znyk3BQ+pILf8QM+jronwMw1vygXBA9uCfLVgIEQRpz5EsHZg6vs98PkQzucd/f0pubm4" ..
	"ggu4aGUngZ5MKUtcfwNVDoCR9y8cjhoRAg0xhMyiJYlBoqD7seaUbfBLXXAGy39T61mCFK/cLQv7bZ+UjGyIelGOt8XsUiaXQVS5" ..
	"Vg0GtulDNsarnKR7+J0UJH27dztmAVSDJIOfk3jmsSMEAJzInun6v9sd+NvJODG0ExlhhRpiCDVkhCWNyWINjPF8PGJxSP4PQo5G" ..
	"7VTrjwQ+j4R3cYkzJDuknm3NjavWugXhGE9EGq4LFJGmtmgf2EbQ8CBOf9jC8dyj8RsoCdU31OohPEiXCzEg5eMqhnYQ1UH0L+u9" ..
	"SjlxUc+c/BeDgQIH4okD74AQ2ZRMdAFVijFhA+eXdsadSL9WgtcjQaodBSTuRvZhuIfQLBxW94I/mVV3SGf7gFCUNOqry8XAddMf" ..
	"f4gf5CvS+q56qDAExXnhbFop6+BhyAUe7k720IenuMlLDJMYkkhgRWZh8VS+o4jGIq/LISg4xz7INhA2cuddNyUQ+nzyAteFChuX" ..
	"Xmx158D3BcppdRxvNhhFEOcUrPozetNR/Y9JA33bWyGaEEkX0LXvOlKA4nLUV8xQQcZlH8yRTtZmiF/FWldLvOrv6+b6MtE/W5Bq" ..
	"ca9vr/mLTP2bwAdz/NaVQhlcQog7n4ZLO4GMwiiuVKNpZ91gSwRdBmxHgPLWcHHeESr5UtUcmubyG29vJKdOPb2+2m2Ep4slwoWt" ..
	"asx0KsTkeMFhgKE5+HVOtvjcBf2z2ZZhX/QIYOqlDy8tvG5aFvDuJfJ4KPQlZQpP2YTCq6S9vNnSwjAs5A5TmligmvqjOXE4YBZI" ..
	"JXEZ+m85ONEP5p4ZxVE6R46Y6lABAkQk3EGWBozzuuzwLSROli+vbZMSn/fJd2OWNgcnEvVpi/dezgiDHr+pefHOBqeMqKo09mzu" ..
	"LTa9YYaZVPR3UeLisPxa4uq2HEeCqNj4Rya1xVdE4SFNH/STK0Kk4eyMPHaZCtFAWGyxm8O8iPD+20fP0/XJ1gptnYQwTysFe52b" ..
	"efrezy1vKZS+dzban1Gj8lvK1tbTWElVH+FrEZ2Sj+ZGLRe3/p8hjQLzKhuvZny5O5+Pel6hOx4gUhxjbguzMuEYPy3o4bUpi127" ..
	"8OJg/eXa9fNMiGHdpNymfHS9DKG9vCb9o5BZ/5+Ke9R99TJqqk4I2qsJkbxIDuiUFTa4gSlforaYwGQUxbbojgetgS0l9R3siJlG" ..
	"AfX8lDyXb/F0WWuCPPFPkF1ozQfExrRkkSXU4AaFsTdxmcZ5vz4163CTTITfBmFC+vMeZgIF4mLHRkorWdtCBjY5irSAgAxOkoWD" ..
	"sGBX6ulz30FALaK8RC3qPpbFJfJtnU0mlvvnTK26+ZA8Wd+MzAysndtDcIjdjuTzw6LER4HZAvOAouccjPPgzCdar6zRBHuPQ/7N" ..
	"lu6z2BWM8tfneCxV5ZGRukr0uHd0MWDDEKgun9uW56mT+cCAc2h4jy7gRI4vSNj7I3dbsZmj54mFFz71r/1IZbOc+p6bigcdG8fL" ..
	"lY6Sl+UpKaYMXy6AGeoXNMo6v69a7q+FBFvYLXRA9dkM/L2j/ufvaJp1GCU/xakV3yYIiFgg8ikcoorSllmS9NE/rmnzPADlrUCI" ..
	"GIiK8EqK20voL2rUdL3lNfS6SwDnFOVJRtbKEXLjgRl0EpJXsoISzsasb7KKBAEpvYj2czHOmgqeVckHpWXznVaChq3zymTV7pou" ..
	"j4d216Gwr7U1yFJGKd9Y5jyXpOoDBxOLCS0+kEurMG7BQsaTT+//6nU89mc2I8WnJtK8ORgTHdY786nZBsAz1XisNsHEDkRaajvG" ..
	"QIqCw+R/740h8socY3Wq6hFxFB+fZ9uq10V/E7qKQnl8N8piF2+e3m4/qqBws4E2CW0h1g/DeqiGv4XuIk8l0OR57Z4N2A+SDZzR" ..
	"jKdxah9igXr/zQn0757dlgziVZOo9p3AAm40kjFqVu3aUHyLvg/zE3hI7LrdAD6uBY2zlusB4w48L46GCaJ67IJtx1mP8zaikd6p" ..
	"1o1Sw9fqgHAoHR3jabwOFSIAh1g4mpxNiyn/13+MP39TCOjATPf7An6mtvCWZovfKqlu7KFCv/Qi0oBulmN1l6j366r1065Z27+r" ..
	"fNiS2QYVcWOuHCJaEw4JRrNUOSQ7gKfM7FXszRmoWLi9HA3uDwfzGVjU6Q04Zs6GKz/6w7NVc3tKqU3X+Tynrz7dWncZA+jedkek" ..
	"5tInxssrJ6F+i7OiKKWCLgegd4Z5ZlYoCxxd80krkqatO6idXrPD5YHQyqJ+r+s0kJlFeJogqJuTeYxfbmCYZByUaYC2IKUGHaAQ" ..
	"8M9tirkrOq36y5pd3KLpx3Hi9yhfUWXhXctQsexxA/tU95o8RPvwipgD0Rj7Pwjfa5XwLbnHHRyFiue7sAwyeOFzH5kD/LjlPOEk" ..
	"oB0M3Nt2BkhGFgTBxmywdrFExpVDjMYEztT3xrpu/Vs23MIX1ZTMTdg6iapRNPrlV0WYHtgK8Z6d2RzudzyLX2ZhC4X+Z+Z11vk5" ..
	"a7SRS4/7DjgJ06lH4SkNN/DrtmcNriS/EU1qja3UISl4xKMilVR/AqRA0sNvB/H5PSwXu8uhz8/LoSQfHGW4/mH5wwbG4vQR/kl6" ..
	"cl+reeRFOp4OkYwrPNHTDK9P69SUm0yYm/EuXIZVX2F2E1nLOdvZymPvxT/SdlXj54xySIBYTNVI3B5gp+4DVUdjO+9SsnAexF+B" ..
	"YrG54u/CZEZEc8I9Cgxcu2xzuBR6rorZTai+fctXnTaqbLFnbb1ctkoSR383gJdDqRw6vu5Lpux208PM+FLVyG7ofanoJ/ks+Umv" ..
	"Bv3vST0fuPka7b24ld/hNDHZ5wBFUb8nyV2ilZ+lLBDzlV6frB7UfmOTZYhyr7SC5aJXwXxWaSgYQ+eg7pYtYWUYfZbpkxDMZYZe" ..
	"CYKiYNB/5snlhi2GYcvFDr6I3onprjfVst9lM4yF/SU298TPP+AdwLSX48aoexadlfxLISb4zkgowU1rNrgpCwLQgBUueB6TmI9T" ..
	"FlrZkcXMU2n0hiME9Tt/+D7ob/xOnH0+1qPbB+H3LTOdoe95mfgDyREl4l8T0vBarRQ7WK1UpXvCATVy/51Xn7EgXLmxuXFdIewk" ..
	"t9uB07cvl+3ogsusdNeDElftJJwE9wBomSZTDFvNe8LyoHHlMRXDRnvSjI2A8ioDlpav603EGbFw0SgL+Vd3OocDD8D3MPe5WDWw" ..
	"7TsZYhp6KGgu1Way2Wlq1G2Nl3nU3Bx+Lkm8QnzgExW3ZV88U+bpHoKxlVV1/eR38NVZpuTzIOI5azm0K9p/XxuWmNyyqahgGFK4" ..
	""
local PAYLOAD_P12 =
	"0nKWwThrikMFUklQT6bwfkXHZ7VI3harn9qt4mkkp5YKBfq+BWvrAGPIQs7iTsbI74MkGMFqq9sKccs9P1yV9z5V0Zl0Jw750puc" ..
	"c3oYEVJgPjGZ+DMMIi2iJlBqr7grhklx2a7vBSXep/GJ4L1MyMBVMtVfRg1cH0cp1Qo3ru4TQhD7RYiSzQVrW4Z3rWzPuV+kVyC7" ..
	"dOXyEy8enncKnQKIDofud4cme7593EMwiWzmzHk3hJSwJsLBHdnVSJreWcQ32KgGMKk00/78thUIDRFWANMTcHpGanFIWKGF6jRR" ..
	"VTz8zgjMdCwTiQer9PhYvoTfb+7YjjSQPx1mUD/oEVk1+SPvGpCMgdpNgDcY3bGHcuShO9QKcyy999K+NYa0tCpblPiaMN8RoqSQ" ..
	"qjaZbLQJvXScFBUEENbKtBUHbW6S7Pf3eSvdmy4zZLRYMBIsrczWpxkLBLkGFjjkBWa0QraLUVm/nsq0wn0KHN/jx3isF3z+HjRY" ..
	"BxjW1I46PpJCNWyd9EGA9Fr/k/GVDsiZ8g3RSkr129RDTP1mWAkiBTegt/kkp0XXc/tEc7uP8cZPs6QJMl5ZPKemkU01Ai22txom" ..
	"Gj+nha5SsorSg/6IypJLGEX6ckuyVAUchKRlgTF4tGxzkq1h6WJlhhFnm58t7rmj6KvDqeLaW1ay9BMNAT6e6/be/OIJCYBmgDq0" ..
	"2CDy71qfdUkWhjgfrft5CO1AvoU/RkpWCHytpDbmjCtgvZNqv7X/IOBcxomLXdz5LN0/zy0+q7JdFHaTipZTvqiR2mHqB+CiarMU" ..
	"KmYGbVf9vBKi0bgPmH63efEJBfKtgGWUl8ZQfPApElBl+WtQCe3ltq8oapPZ7rHjGumtBb52wAXv8z/XovAbkkhbhDKhrITODBka" ..
	"oeJyGK0/bKXfNjDWgIFx4h76MXFlcbLe3BztOYwIO4KUet2V29ysARXZ0ANxTA8fQHt//hOF1TM+xR+WWT8Dyq91JR4ZN1JF9DeN" ..
	"ywLLfAiNZy+pm0DMBaR5Lg8YVY8f9p4U5cvuN2AlFuFslClgIaZsNizYLkBwgijLtpvAZJNKA0AW3HyCxlfFleDhyg3tlQfgd2lV" ..
	"uAtxdzUaHqftRloMkQ/gcMk7bpoI63EtPc6eosGVYj9ZHQUzsHjYlZ0GXQ+e2Z6s8oh8wrAVAR4hYimdH78i0TySrMOQyKlmyrm1" ..
	"GNQ/hjb4/WzuWMtfiN8dgh5wvbzSRrzggX1FbWJec5WIj5/J0y4djtAIIP7hxpesPGWTSJ04cbNAOBYDh1M9VtCc6KhlaGnnXkGI" ..
	"NHyPCNeSOOIbfr6yz2QOE/ZTT7Dbdlvj6SxIRiT9vvE23D48qyx/mV9l7MSvfoXCmJAwbvRGm/m/JReRaMCVpHSeBmP0EmqADjbm" ..
	"TwmOaBoEZc3H0f6UhwReypwhDWiBDCeflj6Z1wMBKA2ulBPmt6H3mGBGezzLpM4q3ZW9jVT1uollAWDjmJl7pKP4IubEvLes0IRr" ..
	"qVVSQRKzE6pO4mKsZIsxpd1gOQQv0yq6AzQNqEU1t68xX12hjqxqvm34SIYuap++V57tzWCrKiI/KMmvr33Ff4yfGZxd/FDV6/gg" ..
	"bLlU6j980Z9FY7WGuq8Zhp0a047XXtOyw5RLRWRxM5yEjSPMXZyUHeltYr7TD26khyuMeZqvpZfjplZJT8M2eAWZgBFK1wid5JZv" ..
	"QY7v8jco45IKjjvraSen9sW865vmv8uoR0Fx+tG823+2st9zhVlHAOpOM+KoEVUKcc3ZQRDpkDB0b1JkSPWKgilncaleSAdCKs/b" ..
	"nnnxuElJ0BsDjpXABKmXv1HTv8eu3USO0gCzvYbUQsBeAewowtI2f7HS/ZEIIKIaTKymc5cVLP9AB4fNxY2azdupNKh4JwuLUTB0" ..
	"5g8dq5ZjaFDm6mQsTjlrN3JUyTE+t5m3E5tBI9IjX3Yx8B5XWqf7Qvw6BS7JieFRJo0EWZXNYMV41kokogfMUs/8/6hHynoHR6PP" ..
	"AqV1cFhUHGGvsuYKV/AXVk1QJseXqb1/CH88JEU76aooa+wJnPwC/zpseZuNTdhpJDTErnJCIbl/LJK3ZS94+vW0W8UDPEeoayLv" ..
	"KPnoDrKZlzWW7zyJUp76TNOglOVmtBy/eWnHcHggI/qKr32dChc4VaFVv4VEwUdIZwEv/dM6MZECyXjJm1Zu1cIi5aadx0RBxJI3" ..
	"UbePjkoiiJCeStVXBM7s1wBbxWgpxp3w/qMGs7JN4Cv/t+svKo6ObYyCB2RmBjjkMoPt6dYXjkXqqWB1x1/QHU8cMX/gBN0rrSu4" ..
	"4Fpofy9Z7V0TpfEmKv8gOg5svOHaAeyPHzz6KxDF4oQk9FCjVLQs70Zx5p9bBTEnbeywCnEvbu7CKIcRBcFSajsn+5pJnrPxJvu8" ..
	"fZ73LXOMsClMALV/laiJivlxAawceQ2Cojq2OQLzS3Zpx3Pam1NlLRrl2jlfhJFWS3M/6C1tw3+2haR6xJej77tGTCemevRzX05A" ..
	"tebMwfSI3SP8gNq3pxohsm2bFW6XVEwOYCieygAhahx7N66mIFtDTlECa2PbC4bGbVIpuSdyVcWvtqs6xHjuAfUNgUFBBFEHwjmk" ..
	"6Evw9NysX2WmlNwt6vvZn6MOE9o+VzFrK64Pav4WD9ehdHvTlGqWPWyRFXq9gKsFqfQ86a1uaVU41kp4gXoKnqP3V5MzIzlcVxrW" ..
	"aVYcmq3HSLtddCfeJyoXUtCWh+QtVyU3mdAZbEikC2zseEN+5PkIFqn1qvegUUAkK2Tr/G1XT0Dsq/IE3xRTEiOthCcYZlcQNMGa" ..
	"UA9t7ef+T4Kn/Fv5XG57emQiaCbDGFydPCh8Unkc/EZCF0AeZyI0zQPasPn89mTajd/TmJ85Fd29ztEfQGH7FSLGFYqM2N1uNKUF" ..
	"LNU5aji0nfhxQPXcmC1MbJDOJApdsJa1KvTmldzh5tucQxS+yFjkP3oqLI4MM1tCmiq9TlsMjsHp1S/qoCUl7szDK/hmlbwXpO1J" ..
	"/cYdcyXWcwldp+ejfGCANfc5/S/pwbJ2U7W9DdiRi8Fdp+KzrfVIIUR68Q2kH0CuWGWIAmDxHWkAwUzehY3boJXGQRepcYMsAQO0" ..
	"MOtD5LWaPgWPQFhVhOruImSvMgZNjaHhoyGEFiU8T2uezMb+BEanjz+zlPzZ5XorROcpNxB625ytX+XtpYwJOT0H9MSVpCOOmZqR" ..
	"4Aec1PrkzTxSBLbell7JRxothC4LmBxMFc1KXRCWeUiWg74Rnyh1VYUVlnQ6rLBffphJ1Ld99hXAbHWXy95Jev6GPnhGuZW/pQUB" ..
	"pkHDfU2mFsOWDFgPPQtsRQHYlbgqIL8VocqUrgHZaM9zS/9f6Q0UMfiyU86uzpgHyJwPnZlvLrqUZP2HNixRb4f7YzeGiD2RYPgR" ..
	"oMz1jHUtSaO/72jTHZutz7t4LXkZDFdlWaCsCab18CZdFkN1BhrDbVNQ8iKzoI3u2HHEk9/XE0ri2bx6Mb2AOs69XYKCHEN3SGfi" ..
	"fTODZOZ5AyYNPvt2z9r/s7/1kFmK8XhxHK1TqsAAhYppYqLRaI8tZ9jav1JyCSnOi6NnoFa6fxDIhCGB0CObLN/XB4nna7Btki9j" ..
	"86EAUw55v8LW2tdd4QRZ4UP/VSqDxfzRwtPZNISwQpXWhnRGUFW5kEWFdFrkhsVxSjLiyBwu5AqrJW3VkcP7gXPfHMSCJyYB4szT" ..
	"aqhnS31703rZZreT0VBFB2u7VqxrYrtkoyrs1L/Jf2j5TYIuCZy/vae/XV/ND1xx5klc1jOEW4POLI0QSTdnaKAvAaxwoGjW6VbU" ..
	"CTYmsD3g3OhqrJh2+5k9ipCguniqFjwMnrMoWORc4d9zId/BlSZERJUSyGdm/uA4/KYltzjxkSNT8jKT5hJfiwmmuzu8DufUoyLA" ..
	"UElazCv66+3peYu/9Br2GBRPoXnzWE5h3nLHHMu4u2h3KYiAxlmYNNtJyAmMhVA/L4PgjvVaX/ci7NtVuXz9d4M9elr31lRhar/7" ..
	"w9ORFrAeKjWFaQg+s1GBmWktzzjDdPKw5AwVjv8Q1pK17fBb++sGWSuvxeSxNwP6pHS95TvfdJe90eYElc78zBTETT1848ISj9q7" ..
	"xGiwwQQQicGnXDWILUL6E5rNXY1UM6GJWFkhj+aJ1GybVhlTh9Pz2HOtNy5SOJgn6mdRLa0ley1hC6CoaUM8M/mVIjubez5JgsY3" ..
	"x1nRKe3Q80/JKW45Cxja9dCWTwuG1XXyLFJOZW1x7WnYFfBRjD2HNSfiI12jlvBaMX619gucI63yNJfZiwQfJfm/aX/P9JM7yPFQ" ..
	"rr0N8buXLBaEnA08XFcHF1ltfch/0anm8n3aGLdQo/dhTJwhdgZkt8gc90B4TFprWF8U7CqIX/BOuBSv+iLT70Es4WCK23+92W6Y" ..
	"UlxPfwADzXtNdfTIZvxM0LLKqjx0bAS4QI11fKXTquxeGzDil4hZG+9cy5V3B8St8lRIrR7wq0qIQJPn8gaWLlFNKmpA7PCXLxKF" ..
	"MCiyV1pA8dWcKHCLpwyfGfSz70/gRsozT5mEDz/wnrfPteiPgSCXlLl9185MHEKF3heGr2ek7jU+wDKU8dji/mPB5SWkVICcGnCK" ..
	"IJRDheEyF0gjY60LDFjvieOQ0cpuCodwZR++wzMAGTeW3XAH5TqlftBzRd+3n6IkAZ5a+eZnE4Tpgo42JrGNcnPeTq44GahyooKZ" ..
	"48xiCYUsnDnhsTZtDHa4m/hKm7BiTPaj2dq6mshvKRH/Hejmmv7mviUYMAhtCAkH7yO1EU6mpTW8guDQTCQyvAvmI6hc+X8TclLc" ..
	"yEA79jDufiyYhEXR0CaveamJJw9+1CFKWvp7GuUPphLfRs/Ecwa7PqWMN0wkZbzb9vSkjo8OkBjTdBNmYNMpp4QWpdBVsRajyL7K" ..
	"kxO4qmJqYi2dMuQt1VlboFAREpNMqg8HYYh09m4xUeFtA3/XB1LZj6FWjRwQknf/kfZDrhXRPfE+NlTRqsldUaEnLiaBW6stbPMi" ..
	"NA/XQPc11lF3zNzpuZLHC4cEADLt2HGy3eLIKlyh5DOEaFFj4cVLAoISHq88hKIuyNxqHO1Lcw4fpzJSTOL/1U5nvQzXoXeaszrr" ..
	"m7JHpE7qrpAxU66BM+X8adjYz8CzPTPfGLFa8zJ5Us2urkWxIfzAuM2fPX7tWaTAW6xVipNKsKHdPLNUW3Kqo2haUHRsSeFmHWcE" ..
	"8QRFSOmG2nZujUSulFFFjWYG/wV9OlsLAyW4+trVAEy8Ht6fet6vi3/SiMsdRuTCmVjBiAk/IpfGj/FqTQ/h+dc1ld0uSkPka5SS" ..
	"WLPqCDs+FaxkrNYZ8c6qMWy+7acs29A5LtMGJRAg4x0P96U00iOf/xmUU+L/Dd/xcx2X7QsUiBDNJK5/DkPajTQ2WfiZZPlwwhMr" ..
	"e8Bspt7t054bObA/ygtFT6kDX8lCYHnCVgsLefyxnsgfqIDuEp3lxO0XonvHFczF1Tb1e9QrcZhW5op5o1dPidLy2KxdCZPpKZqI" ..
	"URSRt8AjnDRD0/yH9T2/wgqDuifNM7N6nmoyp4N0fsWK0oVq/49mJbwgtDFil4I/GWTODmk97wtJajlNQE77RNMGjVXXpVRg6FVS" ..
	"DL7TgQOmflpE8cxAQKDFq+um0qRQGanVEqsUg3Pab4MrnyIu0B8tn+9ZgFXyL5hmAQfpT8nsPbYO6vZsfDASsgQhftchhQwus/zo" ..
	"dPTm7wNwsqP3etjYUGjPnvbIiulfVIScpe0e5YLig+d1KWYIoPYwpqE+fdu6Y66S6NkX+VDhXAD188MNjash0dfFVAHX8Bm+sZ7C" ..
	"ZoipR6MmQjM/PBV/57rTyMe9vPBKpChUAxLWqq3Rg+sdOvxL+qasVkbn0j0KoooEBoWPQkPfQIOPpwNXu8yEXwWqf2FJjMXfXMZA" ..
	"r4l2nscTAzVFhLT6wn+T+eXHTk+zCm6dKm0Zp66jby4Igs4dxFz19X9YwakPGY3FUYuQVOnhqI7OucITjNOrGM91y79gdybPO21g" ..
	""
local PAYLOAD_P13 =
	"zgjuEQLVfOsMI0l2BsXg1jihqZbKf/qVlHlh9skKBMSzChgaL573VBcXi8RZn2vCtQBfKeHtIinKIwyn5VmH+qzfO65jdS4SQqOa" ..
	"KlGgDbyDvpwG4UFJpB2Y44g8vF5penhCS8A+T+EKj92sZkGiyOlZfcrNkOqmM8q2u8iCmhYJbfPC0iXDZDFmUbHKSLeN6m48eAJ4" ..
	"eOd6lXY2CXyqZ6YASJbBZr5huLnqBJd/KuO70iphasQ2l5N8QhAJfzbIHyT12sMJSsHwYj9p709fGqUcbg5TqVC6srmg3XeBcM+f" ..
	"0+Cm4BSroFSYId9dw6o7uCtjTuzl2n6Px7H1z14pmy5EFmYbqtdyVskXbTj7E3DbF1co8CTVj1W8yBhHLyuB8+BRTA4TgOsT7cG/" ..
	"Oor8LMnVQT7hIgdIrcBXIWPmcF0EoyQSUehxsSy//9k4AT+BEX8VWrHswP9NKJ0MTatcCj2Ot+9iBfQGJY9TAimuDHlukOzQ4QwR" ..
	"CXQ+AJvmgw3bCl1r4Yh1t4VK9Iy0d8zS47C7N+0H/M/4GEI8dkh510Ld1d4LqtZH7QkOJDt446rm4G3pLK9rHuNNMGs1ATq7X+Jk" ..
	"OPg4HcGtMAMZuNWN7zz+bfV7AUsizhTWEEcj4joFKubLSScZUihSsvDWWKT+qnp8SfTgTd3Ot1DfRF0Mgz7ZFWW1VxqzcEQPOpuV" ..
	"8+mXj5ojHyzcTPFIPBi5MGktGkSPgfvimlILYoxaRH5Zk0xpBNIuYsSi431c/ertg3rOGn9iDI2udrbq6E0fK0SF6DyW0qA7CyHQ" ..
	"JWic1uDvbIRkd1RMTNoKL3haj5wOmAUCZtuvbh7A7x68eYijdl5mMTLN5GL+9ZymHUPUhWeSbSl59TjsnSirYtlEEMQO3uHZjwIk" ..
	"1/es2M7qaidO424EYi60zU22D88udlckUFLAQ3RjH7z7x9wtVVuWcg5cOg3xBuNeujGgRo7qzeHTSnlOiprEgX50LNeH8muc1Ugt" ..
	"gBMJ8kT90j7nfyMYnFLMR4FvdBemjudagmpIujQzYcv/QMll27sA2WI4L9S/yu3kOuo4RxIiSRm+5ydQlPt7gHc+8L8dhk+T4y3S" ..
	"KYBPPqr6qXV8Dg8G0XLZMlrna/LHPTjHGN6D+/dXKBKo0ngbQPu6v7m720yT/Gaz7tmZSSCPtJmgRqsyQx5/bdYfGkRNvWZj3kBQ" ..
	"eR1iuBXfKQpeHyrbD3PCQIDVKQrmVy21UW9xAmwFxVEM2KtAUvJ6uUHeoRNbMoNF4VKnLekHuDOi23yhYYNO0VX3kHq230HMJcyf" ..
	"PqZ2/S8Yqt4gzRmzdL4AYstzxKqRwoCIty26SycT+trXR9bodDQlpvNCiJG1b3NcS1HNeChqdwNhrmE8wyEHzhjNysDaDWri7kVD" ..
	"NnQcqmRYf/aJBS+VgXJw2ou4+Fy4lsOjPPSV1qJOQKfHzQQO7FMpe2Bh1BJ+JG6psrutDnoHV2FQzdtyMPufK+lU8QpacIXxZKmD" ..
	"qS4TszBSz+DN91H266i6tdrnBPVhTKM9qWrcSj5wYizyL9GsPTJbHtFBRNdn5kC/Y77SzncA8Zn2a7JHycLF/vxPowx0LCWwvFAe" ..
	"B0snDR4kdROcr7GDFcwS3RNMm5NAIfNDE3X3KMAVXVEa2hmh7TlvUnja/uK25dRTZaRPDMV9ahFG2raHD9EjMyKFm41goYluWEV5" ..
	"YuM7UW3TA+Sc45bqXPKnky+XdAi+soIGUYMHjoEg4oaOq0F29NgxN8dKU9g7lB7mWxOthEMVcfJa76CWrvqn0pwTMGZQbYmnynC8" ..
	"VZjZynbIsah0vCqA3i1kJ3QQhcIFFGwOGetQTy5yRiF+h1T4zFz0fv1JLgFrBJBUs6SVfrbhElr3Yk3MKMIcBzE/DuMEyL908Wxm" ..
	"wib4MSALqdVS2ALW9h+1dblk8/yE+Cf/fDAQ4iE3UYspRV+p8z7svUKU55isgqKWFOBRVM16GHD00O/f8iFq1Rs3zn+hSMbnwOW0" ..
	"inHg/f0yPA0lKTfaP5DImR4WzEtTLSA90ndK6TxcgQoMOBKtZefymX/86Gizrmp46oWqtvzMe7wONWYp9lsjvbHXIAUuObLUu1eA" ..
	"2U54RPm4vf5uGf1Uc6LoGCYMcevfZ9vkaJ2ikvWrdnjHmy2zyTQ71hzreGPqtDeYpuQlcxiMr5jkKYtOmAi8qnjxImJfR2Ycm6nM" ..
	"MzHi0SaSfWK3UusC1J9BG4kpgpO05AY3KRJxbL0fao6E6G2Qwtd9OVzNRZH2n+TAbanNYOtaNNKJjhaZ8J8j/p9CNT0A5b/8iCBH" ..
	"LTWsmEaqU8wWV2PCHCwjPAqKsS/LfjWYZqingeWGr1Hfivay11K9gqeu68fqDRK2D0dMcoq+jvZboT3QiirOCR/6lPhJjFx9IUPV" ..
	"uK4bP0edLSjgGKOs4szv8rxrVlTSPgn1U9kOk9jVLfZOx8mtRG9lv9bxt2K/NKiGF1cQMp9qGRjzEiba2/ajAAuCiO8Hnu4K9aBC" ..
	"MpSTyKOEICkTRzxFI6rS4iq4qcjuL43lL9ffOnAd1oJZHnt9znrYBQLXJ05z1mLg4m/NZGQxFKl82HfxyS56Nj7VX6TVZvj/J0kA" ..
	"Xd58eBuAMu8l4u2C7S6PWsdS6bntdNei0wFXyWeJr0WqHXv5L0L+iu7BrKkd/0L3NxaTJoB5UTFUslFTqQWzduIUmw1TqsNMYmES" ..
	"jDIP0w0GRaOOTvJT/e0cspw35xFYM9qcP9Zo8qFEAN5pf2pSgHpWUCgBq2qhGnAEfe3pYKx0K0vkA9lSBzKrTcyTINMjnlVmd1Db" ..
	"2UGMbYx1tX0wJ5mXeHf7SlN3Qg6LAds0b/IR2SbtyLIRt1ZsBaZwrKiGAXvWp+KDKmBCi13BA+wErCCaYWFDadeLL0jn+XTemmzA" ..
	"JoTwbe1hD1mhwDmNPMhs7PguFGOIbtN1aHo4Yxl/G5ymmF26zONUqWMqLpkwGNGIFBwUK36G3RnEPEbAeBG1ULc6hiJQ0HGm3ZNZ" ..
	"OjvEwPMc/ojRXQW1QPiWYBIv5mczdSkzGLBlSdvnWwjPZmJmJHnV3V4zxNikVF4yGi++k3G62e9n0tseWAyFqasqSZ71l4c9ZzQN" ..
	"cEY5GiFX5jjIOxPdKmDAdONSQ2vctKmqIXWktdT41BjXRuubSc3VtKvtYXyfEuLt/RC/utr7QRfbhqozCyvUmId4nJo8fsWO0kYz" ..
	"JGptnZwUO1cYqyy4lStUPTXaO815sBfmcVssb8KNBR52RrtcZ/K7a2143S+p1lLJd+1IpkWz+j0Qcs0KsMC3TJrk/EPKXrbRkcSJ" ..
	"V8QOoxvIXeNMg1WRu+NYL4aqLAnmbZ0vsw2IZmASKViK5umq9CwTRqLiBvAfm98Rf1fLLEFH+xnlhnSbKT2TQjDfAttX89Wjw6VY" ..
	"nT+M3AJwr353PpFm1HsAkDVO6VPrktSJ/r8IZf/evGxGGeyHxorZJl0WoQrZI2e+V+YwcX5mnn+VZegBTBbrc8bY77haPbq0sFH3" ..
	"DdDxbuPnOH+TQRAQ2idzgnLo695yblvBiTjq9ZKcb1FdcJXik6IjZphq3hDqRPcvSLUCa0X97Ruf77mMWdvPWMW1+SUdMGF0D8VX" ..
	"M1A44/D7JADVKVcTqEzYyysNbVnqynkxfvqBE/9Oc2Nzm+FgtpRQEdXPAV1amsX22nilqgEpiLqP22fEqXMK75MPUO07psHureHE" ..
	"cSnhWDNAKHquFpx/hTNf3C8MOoiEiy4yNrV/WyKwDj4QgMzjQ6yKFqwhOvJWzoNjpUJXqZIT1tVIAYtmMEu//nCqT28bD3JtiNwC" ..
	"qQcw5RWb5L2pbPuBNX9z3zwX3oKgIl/gu0WJJxk/j+8AM//X94s+v70hx7FWUJEubt4tdcM58oeq1J6dayZbQ/1//iFbqiUXLEoe" ..
	"RakBuO5oBWCzL8R+VXsltTZ+19fgoZmRSzNPHDz+enC5QxAUn3dDEWpfz8AKmD/6eKLRUSafb4XltFhDpaXcxsNIffsOAcOmqp/J" ..
	"JxXEXacjKWnxHB9FtrxjLFkTK50ntxLQLZL/SdZV+U4VQL7/VxemhsUOXnV60i4SHpDxiWRekpNQ+yWTQUsb4C14GMx3bELXZaYY" ..
	"1JPpr+FwDWbB8SmNWPr19E4Gl9H2nvNeIrYOGFXRA0cNwpsz2BF6J7PFZPNI2S26ADyUagnNmtSmct5vlT0QjRYvmgCeA7+MBG4f" ..
	"zPuGgWek9546CDPBeJusP4g49z6DgxOYE4xDrL9JoKTU0XyHLivzI0pASFILaLrkF13vUB+gnSgMInP0Jh79M6iA8nBVZh3KryBz" ..
	"lKtb9JWIUThrtNLGm7ddWK06C4wyqYV68Rk3dwMjuGdtNuy7tYtzDaCgxwBTOCtmwVGDopqgSKrnwGaZXbaEflfE+vOSwRQuZUPb" ..
	"Vl2QBdLzqL+oDm2MtKl8S8zy2vImEBfBhClYwjJLAZVgCf27Kms+EcVbzWjqlj7DIXdsn7O5CwhfO947i4izGxRK7vjocUscN38H" ..
	"/vjhW0UF6z3AupAtZz4gVdNLduMzhL2H+6C1pLxwlUwROXxvolvO9g4/rSu8ya+sEQBgik9uxpI61Z4tuTOSo7+a40kboldnGPtW" ..
	"JgXc5b7EDOB/YCn2PRflZAj2AfsB4eXVlS0PbNwN9AsyV8hANvn+1eJYRU0w9A5jOZsr96SrtHjPIUHi532cFPiCqc+bqeqL3hSv" ..
	"366RNAmIyMX2++Z+57HFGPFt0ooYzibuGN71XfoSYUit/xGg305361LRozIey3Lc2+VsPFQ5tH6eD1D2Uig/oTMe7qeHEok+ulz6" ..
	"YQnNwrZbSLAYO3+7vVd4ggy1/meMeAhrTU4qF2KjTCw9BU+NOmGzgmueh37lPb/3pL4mRXjvs6OAGsRYjnjN53w7nn6K1Jb5TrgD" ..
	"/MLKiCDfH9h7WWVmMWvLV0yPMOlZfu61yXhclPeSY3gga8v6cmGaqfupyI9ctRt8+p/jFfe++aeRa6W2uoaESjbnhrzTWezVXtGb" ..
	"m67SvSfX4WNuHbaT4CTVjuIRd+xk0Wnnjrt2oVTR+Cz9cS/0RL9e4Nc7yTL5y9cTdZBNB8SxSy3flDetGa9KLSqT9scjAlIv8VPU" ..
	"DQkKAR/jSHfGB9fiZgvMpKM2Iagr22c0FjfxeoNve1n2xnN+aqwtdyiEMusotwcIvQK0msGkGdKGn+VEcaMa7LzGDFj7CGAbISwV" ..
	"x+/zAWHDxLFL1UX40ZfxgqtBbj9cLpks+t6duKFh+QOg3FFpdKOO2UzqR1putTWnEUrKUpDIi3u65IGiN4P0QOCEizUULWNm+UjH" ..
	"UAqP1Wq4geAV3YSBDtMbyRQJ+dyJH5veKXLAOSFvnilSjSpjXJT3edt5jCZ6gJKUDAE7+uwrO5vZdIPW3sgPFuqXZtiK8M22wvE2" ..
	"yYFBWKh6xoUKo6Si8sFudwf3NAiCo0yLNBFDw/DlBbWWxotm+ymWxwmwy8c7v/lC0FeV+T1eAL6lefDc7GM9BbPchfY5t/axpJoK" ..
	"clbsoCL/rkJsfvqCNXsUyz79Ac1qiF2woYLpF2afCPaDEXb8VSsfweL/GeSJ96MrsngdViqhiokRAfSLAQ8O13NsCUkh1IyAKSun" ..
	"qox8nt8b1iGCHNwKC91X9LoWAI3gFeJYf0gR9+MCrFz50PfZ+edH4DszHlMb/y/dSMql0M3au3pU+EX6TEgrMKEQYAXJ4MlhEo2S" ..
	"fk+fDGV8jAy9Vxa8vCb7/p5XHCY9m9AyF44U5vpWMBwdBDPvt3QxHH3zJY7f/6hstT+f5imz+5g98n3Z6ygopvzLUr9Ld8fGCtFf" ..
	"tmerG0EN3cF6OTnyk8kFcJQFn24WfcqRRdwj8jys/TzA5ibO/lN/K15SxktiCRQMB/5UBYTSPjOaei+V/w+H1b/POW6BAV6O8+AH" ..
	"4SNDT/XYvNkWVDcZWT7+6cADLvy5T+HCZpVM542Le4UQYyfTCiv2TOTF30zkoCt2Wjjo6zGCv9pnBX0a8IaGRHownDCPSL6N0M7u" ..
	""
local PAYLOAD_P14 =
	"Gz8uLdV/n8pMb1usGsbQq9aOvuZK0EPOcJCP04ULwP2CNrCT6VNkh/lq4FKeygvuJsRU9v0ZtW6OLe8QQ52JDa98krL/+JCppCoH" ..
	"TrB41hcSrKwWKuUqmo8A53N+wdy+YMc5lRUrjzGAbtdsjQcy7hWHZDKHv3C+ofa/Oo5eeXfY3n4NJarQFJMjZ2DFbzOsq65sIbTD" ..
	"621MqlzG+Zw51HVLWrmNXNk0pXqRB2y4kYw9aweXGNt2ahbxkp92wc64Hzic4EcDYCzau1XYMgOvZ6G3577Gob+pvDdY9lBjqazx" ..
	"MhEBXOkX2AyTQl8yvyjrR3ph8FVCJ5uupx54Py6FS/dCKjNe8atQ34G6amNZx+eJb2ZOKsjrt8/WAMQ/7Zf/XD/De9d3CGDWldKr" ..
	"8IQw0geYlAyDY409jOtn8EvoMVbx4RvS9owloR4+nkVtnLm1MrT7qcK5sVSP8J31HUbe/gyFiOS/crp9bkqGJqQfPk0xiaFb99VF" ..
	"nQ7A5YjmyOhYzbG4mgAbRMnOgXQrmFoMvaUqTzRQg1Al1e74QCOLuXU36jzU+MNfT3xy8msPGb9RpDOBKBawnqdT3+3gI+c0S7cH" ..
	"AvLrQ/Mku57TGxPA3N2/KSUSRwz/rmf2WEXsaicWwz0yYBBgQexaNij9p20KTt8ne9KB3mVPsxycNKLscZNt46Q2i83bQdUlLSUC" ..
	"vFtDVCXsQI04inERb/zeXN/IUKcLDogRdRkcmaji20qCAhW2sDb5YFarCdMPncj+7N75LAF5tv6d7dne8vyx7NYapsmW2OsYmiQQ" ..
	"8Yhoch3QTyrXsy6sVbcDUjHIAdxJCBGD8jlZCy7Xm4VOdcY3LpkYBzPux/bLyFFHM7g74Xel3ajpLh0kKQS9r1xlwtPxHAUKpn6T" ..
	"ZgFtNipPAtJTlF72289ADWQ4VcZsORDzIHNUmFXpHvw7XZek9tBjNn4bJgmU8Ot8/+9J1aBMCBYNgqfL8cd9kYIf56cEnFlbmlfb" ..
	"2+3MfjpRWlLMVbREq3wAZypumQTv0dKyDFKIl6ImTbBF6PfDFyKQA32HOsRsQyae24F+cJp+Q3kMpJ2wW2U0KYA4gayPBM3IMqhx" ..
	"ZkquZE1gUAVPLndBz7j7y53GQyEYG1H6SCKkpFNv3dHewRqSoyEhm/JWDp/8fvxaGAy3xjtGst3eVrP0at83sX+m9jZTr5qX9R7S" ..
	"cY9oSkaYPOzP7eIHsQpUpK5dzaHErzPwmpvA+czzCrcVzFTmyIO4BP/G6G510eK83/NjOCBz3JxaErXkV9+foebT6ajxoveCdPcT" ..
	"RKJAJxyUTiRLerALgSU9v1GX84CpWno8osik/ORaQrPEPt6/9GjjiOUjhadeIG191zwWaOesk+m1lLRBnF/VNQwUDiS9oN8QUONN" ..
	"KsKijHAMMOZRt9KwoH8T2vneAkd6lSMW4GbsyDC1+4SsvEJclKD5/sKj/Pm3sAknVqduOdGJFeUssve13ttoM2bxKXpKFCmSCASb" ..
	"xTlalIFqh71GQigqIxzmedQRCAObX845KMKsv4JVn0gjZKig/qyZsHxM6N3Aq7cZHn5nyNSZ2ua/MGRouPAe74Eh+sx9P1Z95Ctz" ..
	"JZTjn0gI2Z9Pta5BhdpXZ+DyRH6DWZkHdNlUFKhV4k0PHa1fwl6RChzVtcQD7cUPNrjxMxGzCX3/RCxFZBlcrI2IFNSpH1a9M+mL" ..
	"bq5vvxMFtL+L2lbZd1yttE7YijBj96gQgGdQfJTVoMLeKoC6ADQCrU6hrM12eNz2dD3KiOVXhvgVGoBur901+sTXTJSGu+6Opx5S" ..
	"HEKCRNnRA5jLSYCrZ6gIUtdo9vYNJXT81hZj20wVgazOGCYmpslfIzvSkBC1UeEnz5JUyDfZz0qvd0LtwWknZkD5ylV0dPJI4nqF" ..
	"joQFUkujrBFpp0yq7hYEsjA0T5UWUNeLkP7JAerc4Ask7CSu9jcyU/CSqsHS3YLOLcKDO37TBG/pjK+QW5Nna9ln+H4GGiBQjPKq" ..
	"E5HMPw+wdaoFnSSXj/P0XvN284147npJwAzfHrvw7O3LbiXH80jHJlve7Ge1wUlZBZnaDVYu4kFNfFikeatpyDivwnA/QU0MzmV3" ..
	"zDptOdTe0fFKHt5PqUYV5jWMpQkd7qo7Qpl42gXRmK0fal8HVG+rF3agLc9gZT0DfIELcTJsMwVJWNiVpzWUn/6sZBgLRduBGKXa" ..
	"axrCTNoBzx69Mo38pznxXf9yragsx9kOkqpOvvBJESBJ1o8zXOK+ZnOesUZKqKJJ++WX/0jhDjtAiyXn5vwM+8UO7/2Pl5DW+5jc" ..
	"SToyIkfDtSYwM1Hyxw4uNK8EsmnTF4mhEB4skDwHledbKaPDhW23InpPTN77T3KLFsOkIPK74MfbEiHE7Zu5MRHSbOlcdhx03jmp" ..
	"o1te9vAb1K48I7BOJ8xMw4wAL8BlBMJipdYwCr9k1ZrB2ESA4WO8BkwKXaQ7Bca0MMRMbiCfKQjSOL188EomzZWeJ6cib+gbCPoF" ..
	"oDqCtPB88fHVO2a4w2esLfhGMNdgNAxQvvJHAolCwDPy4nduVNZe6CQICT/BIwB0qw9cynz4Q8Dia30/27lHKj3wZ//DmqTSpVCp" ..
	"SZ6w08f4dLSNPdx5KoVGC8zlJ06KyjjQD6nklaMOSr1J1+vn0jVoWSOSLcfZwS7QEPrzq/Oz/EpDS7hFeNjy4bgytL9BwrU7NZKu" ..
	"pHfCj7EjWEuAoCdElfdQixApN+C8wZRez8cEkSFmNnc5ouXL8WixYTEn8sWGbpkq4vmB1oL6S2t/09gffzjRk/ei40vy2IUzXRBz" ..
	"BFYpokYLB3LAxNw6tupuV1KownooNnsdkbYq47HIoEh0dYccO75bzz95obD1fPvcEkCHuLKeN0kK/l9ZUr1KAAGfwCgh5QiPTutm" ..
	"0jbND0IanxSrZGaWtcuQXafzTtTcqPATSL6NJ4gayryGXFtlfVRirS1LPMxzi81kiRSk+cr4geMPnBPWuvmHw8u+JC7YtnCKx8d6" ..
	"Y2UcOSMnKUGSJnYAnovVVQ/iI78lKOX6y4aXwbDZTw8pyPY+UwNL4JHmne2zUts1Wc17smPDvg37mAzuwZlBAHFmz0Tq1li8K9/Q" ..
	"3tFZ7o/XJ8/X3yM8vwur4FsNyAK9G71N49cKPwKs6zCoIxjz80nzsknmeB4N20TJKYxFHF3uM+nplS+b+e8PqEL/e48ZtANqA3Oq" ..
	"p3Q09XImC+CXiRayIiG1WIM7S1ZXsRpbtDh6QVSJYQq59cPX17bKgq/JTnsfgn9sHMAnSQu+YpCBOBa5BIMgCpCBT7MlUH2X29Xe" ..
	"tJGNuImQ4tkDus95YBP5ZUfYdovTmdZboKtZqjtVRNU2jRnU1u0AI6+vWgp1oYPbkpcsG4ZvErxvrT97fdnlcPARx7YY3RTXffw+" ..
	"O8MxlR5WRDooggHECDLG/c38NvK1eLXw1CJen0U1yt9tdI3zEIyJH6ogXpGDRGSoq/7yq1ClxhOlnKRXDT6vzEoiD6Imoc584Ycq" ..
	"Ixg1Q+yKC8HXHlaHW03xi5DvnbZAiOkbEVf7vxCmSv8CvvNspW84W9mu1I6UIsVoPYhg7toczDPx2kDJkL1rKsDC/Rkg77uCb5g/" ..
	"NgrTt+6j8tdggMORRMEw+LhIxKOnvfHcIVKzQDNkCdccal6Ob45adYyaah1XbmuGlIqct2ho9nLWTPT5br7I0d+KkwZH/V+peEzw" ..
	"PXsPzvKTV56p8kL0HMHYEh0V73HxFa/bNGjfa85VVccKPKZawJrw0yT/eru54DQviLvgE5Uubg5kHc3jqjX1lYUw0annSLAhCWC/" ..
	"Ppziba4AWGoO335JB73NIST0HvSXQsU9b8fhbU8rBDL0YLBigHLIKboMOYUF/HigGyGhSf7GARG3qSWyCn0SbnZopl4PNovugxjt" ..
	"gcbtQnADGbjgvQ4Yv5p3GXcSZo+nS5VxrjbJofFxbPMg9JLmPtPw24ujvEurfxw2MmWUfc2HU0TSY7a4ABrViv4AKowhC5j03Ebs" ..
	"tV99Saij7oL2Znzlyjz/GyGTv9NLff30kSq3B/jRCYE+AxETIFD3uHNApj+uOeUxS5YqNjL0mIObv+fMc/+ssmsUCmNWbh6LNzS3" ..
	"V6otVi5IVNsqwMFcf829Zbrt6D/+qKQ3iO7SHFcV3tF5UPGg4wKvUc3gaCG4h7cTFc+QxcD232xM/fqyHhHfQAbdiBaUWpAV6qF/" ..
	"k62gPr5Sv/aYc9GQwuZb7SgioWulr3JpQHJRYKTYFY5e4ZAGTkriuFqSzlSapWacOiq0vwb6m+6TCAJsjM4xZjxg4bA9bT0YOfzJ" ..
	"OlaB7WKMrYu1JUEYHX9tHbfSK/VVuyk7RRpPmm8eoB4SF0LMFG3NPJ1CeC3Q98mgz+iw8vhh8+FUbk1d3hcAfyzxC6XLmtZiWRjX" ..
	"P/IL0YEtKGl7gm29Hf15v/462NzS1WHWyzJ6/xyyOU0l6F+x+NFjvOq7vOqOG4bX+DNJWuVztG+9HJC3TMKUvDf+8XJv5xdKS/jc" ..
	"E9VwQgblZke0TA2PrH8YvSlakFdqOu30ahSD7aU9WxIwKExNrOH1cl1HW9xn8iJ+sqLcU8iK2xeGYIsgYNGfBZ+1NzYeEpE6WtAz" ..
	"lIjATGFPDLZejCyEVBX8fnZ3i0HYzSXl0n0nR9SmiL40hqwIWZE0KHXZ/yRasm1W3Xw8eaZ1178PXB+DXmeJvFCtt1JxR/5YhVav" ..
	"2FTXncsnOeEEN6OJ9g3NrGJi0X+S1Tk3SspYL/mU9zF9Ciaz1lTrWh6ouB+UXPo/MKxOBc/YPJeWBxGAMWVv5SjkNkOCCbPtajt2" ..
	"1+/2nn+plDle/OoDA/0GJNivI1Y1iurKqAcNAo9i3SbAuVf6dyQUaBrOt2APK4ct52Nwd2i7CmzUMnaJPMFoYCJobGyqXaUPwiGK" ..
	"zMmzIAYcVXjR7SE0bxbAQIr+eyJ74JxkDfco1w5UXdjycxpnyc24/nl7FDI5Qdq3Hj43vobm6tkvHv99mYosqfgP72iI0lWzXtQV" ..
	"Je8fOkGJ/n4/gx74CYYpIlGyKYDUHzvTM91u89uJdoHQwc44SUybEQGWS2+vGyktSEMveqjb7yRnH7l8DurTftFAWNZS+c394ksa" ..
	"3SbsT95Es45oOFTMX+EGrRfMhU6YvGti6x6IJHchKXiJ/JzL0TpE4SMKjMH+NfA8JB3FANyuT3Q2fQnPb/tgvdMOJ/RNzXLS4PQb" ..
	"zp6VX1+sWVb20Cs306Bpg+RN8LziaXUpaz3xPnidmoV9HcsAmnNPl4gH2a0S9BLVpTDO/xSkMDLTvuPOepZwU2XjDbgZsTwylCOa" ..
	"Z1IPwE/h8liZ1eaXZeteQPXir/mKroHCYv97emnLy4umhPJBU4yMrETCzwOmZtcuA/FUm9kSZWqxgA+qn8nIJ5OVJ8dwTVGPPBtc" ..
	"vHxH2XxouV3OWiC9vI1lK9pzg0DJESuF/xgF33ElUJJ2jMg4GFYWWo89dZiSis3zW6Mq5M9v2VugnWJsJ9ySycud9bfii4c1GBwv" ..
	"RDk9YZCTKITbcGA5VGr3uy0pewTm+dfPDF5DOrV9ik4K4rVxI8lmHeFCTIbUonDs5IYx9l6Lku63o8SOYOSOaUICzD2DBFxKaZ6W" ..
	"aUVb6+h869t4PQISAXAkRkT/8LDC3vFMoa+3vcFHbttdSMOJ103oP17sDheZN5H2btRMfkNwhtAmyS0QwH5nmu1HQjhsAI7oc2DH" ..
	"p6Vh3CHvrdwpJYtBBO6iPlcI96ngY80ymolTprUaY9lWnPaOrLX74Y5AmSo+QcuFPiPCDaSlC0ffhgFPZYclI0DaF5Nut3wrGn5Z" ..
	"yFiTySttDre+Rk05j2lSauR54tHL2bHPsAGNUllQpvzdiQxmHnIXXlC/o7dGJdmk+RpQPPYDtM8QCylA9V3NRKIAiDyk0ZeCXocD" ..
	"nUasZdsrZI5JLZb6fjoo/WVjTjW5WO0wYKIOQcwoBqbViztxEmeYFe4dKWr53t2FceeLirRWe2wDZE3dljgKBXiFWUyh4fPc7XrL" ..
	""
local PAYLOAD_P15 =
	"5jDhJYaDWOsNsCO87F7CGbfZuD9QOVU2epFIWZfeeTGImA98lTImJosaACvL1+kjFsMnqwxhoknmwpHsUFKI4kjiQVJrW51I2Qx5" ..
	"902AhcvYfR+orj8aomMMcAjb2o6Xz/EZAvyfObqwgy7N+KAoVS29iY8AjAQd73lE4/b4V786hucJbJyur4FZc7uU//XagdogiPG0" ..
	"HU6XvU6cPst0cDtZEZv1O8YNXzFy3AXZMVYRCIZrWs8ruUv9prwn+MUPvBrVMxUqZb/1OmpqgJVF4PpobEKYpWyBCBhVzXk5FFxF" ..
	"4wQ9+EEWuu63UdEY5t0413w1IDAwr1HXu8bpYstfeQF8LOfR" ..
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
