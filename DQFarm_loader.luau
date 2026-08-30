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
	{ seed = 4216301497, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 4214736815, exp = 0, plan = 0, hwid = {} },
	{ seed = 4215186378, exp = 1788089514, plan = 1, hwid = {} }
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
	"t/CWhbLpkDyl5eXBRKuP0w1PkLphq0ZrXaSPDUzySa5fahxUSa9jc6vf/QCz0wkEYinAoPl6id72yqAK98bFQ8DY5Jk71K+YtZmc" ..
	"7cJ0Dvv5NJLF8AwHxLMsKmr/wpCyH2OgQ2TJxLlgb+58zOlmfV12a6aIS5YN8SBro75ZqPEU5w4qf2oiTBjylkyePOeo3z7LxawP" ..
	"55N+VljXLbTsHeeiHmXwwujpU6dp9POSjcalhvvQqnz6I9k3o6ujXS3vV6o/w8PX/Ffhtvp2GpYJnh2xvkEuVYXlQFUg3eqi0ieH" ..
	"CiMHik9/U6tyUxo6/ufWlzeRoyiavKIJwF1Kw85pgUQ0JW9C3TJGq05H2Bw4c6T6t0afEWYqJkYl8/X0VZAI2DqunULSB7TGOlpP" ..
	"VOlJSQKu06qgjMtl9j5Js4tZBtjq/wAVpIo0TX763ToUYjC7KknJWq7WEZRiua18gUFVH+q0Sx4fh9yW8l1qSRvY7pFDJiPpeN0c" ..
	"c7RtS0uPwtmkT1sNlNLHk51S5K2g87m7wZnWeDQtIy7BsdCCNcrJc0KVTxxgCLW0qbX7f51zsvEKtmWeKpUbDlk/PLN8W1kj4Awm" ..
	"LaQXh4wc/sY2WZoQU55C0ackEwQRpvadSI3kqTFnNbbvz2YWDw/b42nNJKG5FgAJeX4wNmL30VEC0uMG19xNrjOKQcazDMg3gDov" ..
	"JboaRkHUgglzlAjFcBfHrud0yRWBub1VC5APc5KhuPcUMOnxj9VwMDc+FjjMW0RRcKw96txLnKfunPC3vgsb2gP4rBQf5sD2c1RQ" ..
	"1w1Nfn7MzbFnX4rsbRcJvVEQCEjXmcLk6oVbbYBHqNaVK5NOiJrqbSqd44uKOTwy3CFZKs58d8J2kcNxuqYh6S48ndm3g/ETa5YZ" ..
	"sNm7aIOFYOqYe8Z3YauF3vqSB+mJxIvpEbgPRyEGdZQadlxaqrl118xXGPzg4NeHb7BiEi5YKzpqJVMX11cYVLOQeZdom1jn+tVK" ..
	"VzoKStE3ZL1I1XouIZNDelGSxzFvIIuA7QrrrIbI7oDOH67c0LmMqRATISdzvOmwBJeFs72c/Nf5XKCz7AzEUcGNHG/UooyG4W8d" ..
	"PLipXWApTu8CIVEoLRuKZxHMQfmr2THgVFYis+g+X1T3MfdqLZFn9bd2HFiAHuKuDNaA3bX7q8oFH5ZcN70K+MHsD3LKQr6sw8xU" ..
	"oUyIjWcLIUuUT1ynkHVm74SSrv4kJlkK/5mwcJVPMr3WYkFnJ+48Y1qaOjVlQF13470Bdo9I9pQYPS4j5g2yCLPGg/4/Ojic58nd" ..
	"hvzo2dzV8V9z3D8077JxiOK+gJUIhAlWrXY6yaJB8RG3YuOfJE21C2+2pqejNAmMh/F28fpxaD/9b7+yELobDX443DPLngZGWX0b" ..
	"LmoXXJo1p9qLaBlza1R9nnOwNRggJjtYoZJdAQ3T7TNJf1U/ZsvvAfy4c7bQa0/TLuOZd+0qWfovSPfqG/rs312zjmNe6ZhuSU9X" ..
	"4COkaZDI3a8bRrOQ2sZOP/vp5l4rmlXCAmafZbVjrt++zV6JBEXsQUiZoftvUA2++cav7EhO4mpGizmhUqQXpuOP+rTlPTh9xtvp" ..
	"X1SocOYRBjFv3XKweYdiZaYr5Ce7uVxKY307JlBkHVb8lY7syoSd7AwuDMYipsVXFDMXYx/MR2A8iGc0sNsw1aVVhL7s492fJj0i" ..
	"9XMF3WCmju3HIr5cTdL/wurJ2Nfi3SusVeT8OQVb4KrZNT9ZGHMvNjmA7lCAnsa8xImfPyHer40WAQ9/D3AcMX6oUiaKUDLB7AuB" ..
	"S/NKwPNd5LdmfmTc8NozVPsKF/2dt5YGpw6cPMpfItQGfadqiM03U8ywXVMJE21Fe+3kUa26hK4RcTG0LlqhQ2U+osibitDlQMEv" ..
	"s87pzkTOqcRE3NRDGbkzeJkJOM2YvFf03xPRx8o6g+qPh+21xO/P+Hdz+HxMexIjBzutoGBNhF/MOeji/fW+ZWJKbf1ropUNKrOL" ..
	"fNRfOI48tUqe2Zlcbgc6vADyyx08dpefzKlj3b7mCUvfRhNO6FAs+qPT4wXP1mZu068sQQJHenAda1tsXEDtavwfx3XjAHyaCY5W" ..
	"tGvFOU2WwnqMXyT742hcGQ6MCyzDf5ETs6i1xI4kgdIhdTApx+VsK04Y6TRTF33ae0kzMNOP8Nn6NFWstfbNrcMP/fhiVnTt3i28" ..
	"N++TgKWHdaH1pQkGk39uan3pt1TdE7c20awnrfXfqFYV54xFhJLXIKbtVyESQ74owtuJH+ZwS7/Jdrp3AX3SlHdGPEMZGoPWrFcF" ..
	"wWA2fnTRswKL7GAhBcB79qurHLcPRQ924HLH3Riy3E9erDuOh1H89MK2FAaE+pDJwqudWaAqQqtvqVqdi+vom75ul/H7CvEdUE33" ..
	"CeqwnMnrMnSvjn8EbK+od3DvroEgMtQcc1zxGdR2qFGXdMWj3/2ocyzv3MgrtZeBcgxMJ3dNlSU6tngTKY9Hgriw6LOIweyZJP1c" ..
	"5UoQzogq1JGAvKmGWcFxQMxpalnMF3aaQFTqVe0QrHwIQKcXESQ4mkGMK8rl0WA8wP3Fo/XXEphB641UlzAshSItbWdOyjJP84T+" ..
	"zF3qaERyKPMr5v1FAskNmxKoD3rUSzI2br9DMxZ0BcAjzHc/VrIJU8SBymANGoziJ24TcbmDvAEpswxPdDew9tgEmcjd01DrU2Vw" ..
	"1eSzIaXGM0oJtew5/NtgMBzefqnu1KRwTpuPfORJFlWrSqE+nntJ4yWuGi7w4+IRIBNSIf1Iy+geEWKv+GJT1lcDtrekHQ6XOfbW" ..
	"ZEZGmYMv1EBz2p0BgrBrkn8Cxoe797D/rck7TkIOOnYL37rQlK9b6jtBPoF3wTBiCPSb8rIZxsOO4p/m3AVucmEvxuJCihdu/g2W" ..
	"d9VCr6CffZc8BFvmqeZSNCKTaHSzxaWsAcakE27DifTx7WnHSIRZH1lrcoUYfcYU5ecqyMCzVd70OOCEuigdgD3+52NKOFcmd8cI" ..
	"Ddsz5Qhf85w7G7vZjiBxJLkyOMhsjjfP+CXdE8b60nD5C76htsQbUwVS9W8C0HI0JNvW46+9G8cwiivxHgZDEAaKalIyqJ1rLMZd" ..
	"g2Z7xweCKbfrYhHr+Xrx6NQWqY7s8p+BULFWqPn9gN6ZZErjd37a9Xf9JFdg/2ciTcpHgkO2w6K/GkjU3Gf2PWpCieN3d5LW5V71" ..
	"ibe6BPFov9J8yA10OG7mBYqq+JKahv/uuCKSSfZzdYCqYREonfgbj0NSzA2ogkAtqb8r6mBRu+SJoSGse+urAubDiuI+ZeXceoZs" ..
	"hGFCNp72VYl3KzAkb9Mv94sZjstRt5/UeB7FrejSPtua9bkotLGMTXmeNaAP6KfJvDrLzBDw6fj74csGBphf8Avdsmn/yu7tIbld" ..
	"6WAFQJgJk4EuoIGNf0H4NmzEfrCYs51wQJSzh4w+xC8wCxOQSo4Zytz8QP0G9xjm/DR4YtLx2RCOyrz+Tnry9AxWCmenzeWA8F8v" ..
	"OtTPC+CJ8U8yTpsfASAw232wpQV7XiwMt+5ovwPoUrh3Mx3LjLynxgHeQExfXMTOzSM/7yUWoTZNJG42Yg+pwfr4yOveAl/detkI" ..
	"iWn5CJhv5Za2atNt9G3yedSQilungx9sGP4UkGduoAnKJ0rmjeV/3Pux+K88txjJUOizqgm7g3tYQfofBYs9e9aaHgad75a4yYPs" ..
	"jkasqjA9eom4y+RGO5kw2wHHssCcL4js84qclAuf8paCjMlOSMWT7H/OfVotx4KHwF8coSfThGDMbmnyAMojF++M0gy/n7/ASbXN" ..
	"eIzJ1msF93uDFOFCgy9LjG5R6hfmjo6k/zibgiCFaBittCgCE7rbgxWrYVAtFqBcobNve8nichuZfEKqc5Sayee2Z16Q+OrdDp0r" ..
	"H52xjI6WsfCHUoLR+USLi2OptpyT2DVjMt0hqCNMPOgrNNALfBuSeeCdismuWSiPry2SuNtD6WC715t23W7gVDKVhTIN34h4rMOr" ..
	"FJszUYyobbFq0OJ7fJ7GmgJUiZy5DJqlLLmLcP0t/ctLSwfXKSabJxrENFU6PjS2xv/hI7gnVf2dHkvRPwrl2mYlWsy65TK+pJj1" ..
	"KEXvLe8tDdEqZ26b3yjegAdY7CXqiqiV5tSWMe4iDQq2fQffiQhD/EY361KotnkCI91+bSHBshi7tpcZBM6nHIkq60bfYbScvyK2" ..
	"JlO+k4igBKYYEPWP7z6yHUtCUfuyQ+AVGmMO3VjhErLwwp8SLz6WhHZOlZkh6qISEHj2w+UNlJYx2W/C8P9rHzr4Ch7V5pM65YwW" ..
	"gnhpW9mDEhVqIJjFnA3HdVnU0sT8DP0JbrvY7LhHYH8N1oLjSz3Tj8ca2RqOVE3m359jBd0vg1SNUOZsWCe6dCCmKEWHaQarfHgC" ..
	"Z22ecMi0uEGMm9ugOZU1sfABl03O1zkEwHieVB7s0xYtbWDdfdVqlKDk2ae7OMQvLfCtgQvkBda3ZolC+/9/Kmf+SiNC/vL+k4Lj" ..
	"7FO8wTgP9WGOwyf7XDkIMMj3xSCIVx9rEQYv8I23aE9znlz2kzaj8ejQcrcz6e4/Uwzaf4jCWegO1gICF1hz0xPxsSxM1IkqCdEt" ..
	"DQ5RcO/c9RnqycPIZvDTFUb6SUQkmbT4MtMcaX1yZoKfvE/Jxnw0HgY/xMdU43LueiAMu9kvsV96jd+tft9qTDU4TMQfOdSJ72v0" ..
	"4JcuwrveiRWI0n32MYTyqTB/+EUBae/7CZcOp3iCDxljKX6sYwKPHKdUs4C/+0SQ7rV+jSTzVo60Hl4JcwZvzrKxwSooQkIg1OCP" ..
	"Y9BlhSMi5cpw4A0/XJFw/pAzR8tGBR0HEJsp9aXdH2UX639m0XNzJUTBY67su8YGNMrP0QqXF1T4mfaz+R9doXVidU2LKTS7XEYG" ..
	"ZiqOyo6YDb+UbREqYpGtHw/8V4IVLP9ydX8vohb85Sai+5TdcBSFJSz0Mgj+RDcMmojED+TMKu7ZchbWifmaH6XYP80c3LGDiUM/" ..
	"HxzutMLvBr5q9bpaeAwmC3QjuSv4nrMgF7TMHnnQ8YU4bzNrJM9pvRHMqTtgg5Clne6PsTfuRmyWF8QTpA1eLfasK6Ijz3zdNCi4" ..
	"e97XuQJA6Kn7KxkbJEqrPN5rvXFt5fgScYFc/Azylv8SM4FJBuxScRR1bS9EpX5l3OSJqdLm+R5GC9TeoiFrFaEn3tO69Unziy8Z" ..
	"7aD2iIQ+jqmZ0w+vrkj9kGRzuixd2hIbmbrDFcgV7eHA8hBrvcP2dNe4jII7+5f2M32+3KHVItlT11fwkKZFT4bVDdR3lc+dh9wq" ..
	"KEhzAWYpu1dYLaSSsTW9VtHtdljvmEO6Czxt7DLRSEm2HBLfhX4qxajKEe2WXW7w+6fa9RuJ9PZ4eflvXnsi4q32FndB1dS+n8Ly" ..
	"5sDYQxiWrSoifkRXnnnN+hJIm5drQTDuHDXBisFywt9vQ6OauNVh5Ijj7lR/S0HoQOMr9LgCBdEX+a+EFfRRbfnsTNWOLXMS7BGG" ..
	"Bod6Djh2Ns/n+ODBGexpyeHNTF13nLijzvK7HFG46sFkof4jiko0Uuiw/Konc+NhBHLUmqkczhh66vHlDS4PWYh1SSkk+nhWCTgc" ..
	"9k0EgaWLuVnIy96uytGp4BFipx138ERVK19v3gGGqb2fGKHX2MbKyFF40/Y1P2oaMpcZxzRFLD/YuvC1tYe3SQ+efuuABMA3VlVt" ..
	"o/22bwz56gVGUN/kKv5HlxiXyDCEg2/KIst/6uCxHu3GMAf7PpumvGtkPRgpxLKcHMKB1SjrAeqI6M80Zrsowh27LWTrtuVZAFPb" ..
	"q1NE8RvsxVsuVyuAXpuVxZhxJYi3uX4NxI2szW4wNPC/9aQM8TYt5B1LVV5bo1icIYoqTnFx7pYGqgnIZFKC5bZeY+mOyk+usnhp" ..
	"j0tBXanTx2uTajKjl6+kpWuUmI1EDP327QBfp8wZktOPQQsEhJ9H6NeMFA53e5OL+XeSY0ULQ8sGF/027XMaErxt7+PJB8oCpSoX" ..
	""
local PAYLOAD_P2 =
	"qumIAKxPxvPbsD4JJV/3Bx4E+IRU03tL58VU92gVWxSE3ixZYiWWgzJuBwr6W/9ecgTqy28Wna+wCKosuiYu+83Xp7vuOsuJh4cT" ..
	"ak+UJClVVzVi52GFtFqwT3j/b/xlMFD94/Vaeun4Yr5S9LC6KCd57nG8MUIxvQ/ylLVdEu/BDcSUvTHtOeOJwLNGJLfkdamtzZzs" ..
	"1H3KRw5OrJ+rwl2ofDbuUeZtX9n0j0gcUIbjYav0QALi4/+u4iuEAj9DrefvlED6djiJnVnMIilhO7FANMJqgXZ1UxAcxOTQEBVd" ..
	"RQ6yU+U8YxkNtqO057btlGbBsYskHM88tn2SNEhuyPEY8ow+yQFjFh5znstp809oZtNAIzmFv1QM7pVm/zXKentFrvhND/dQ69yD" ..
	"naPWb/WrJSConwMip60yd05rejB6aSilGdJFRVJssZpWq8soM/fqkMzttVlfL2FJDHVXCc+r2eIji7Da7Q0Bzby7KzCs21o5coDc" ..
	"9bRxNp3CSeZq/F17yHEd/N1D4rN/he1dxHjwFZT7PQBojHjsI40YfTW1UqwasdrZArNkFFDIkX3/d2QyugX0rDsmPakgWtjCXD74" ..
	"mlwMxTBFKSB1p6MxePpoA82qY2ekEVqrWf8q8NfggdVenQLDX9g38S1WDP/YKN4jv4+xrZoS1p/uBzqQbRH3QpPOxHXxN7vI1s+x" ..
	"jz/vJ0Nba1upckGXj5gJrBIUZaW2VJd/QuFrJ6xYqsxuJSyaDpIsMg3NjzzvUTb/ZM0MbjZ6MHEzGHI91gR59L5JxUacxUKGJaCK" ..
	"d7oCbXcSVD+XUU/xx3Pdu2xAv0zU3EUCOBw9X1TOAayFzUdPArVglbyDRv3Jhy2x5s/6OPyvJ9f9iRUoSf38vp/JkpWwUWJvoJJS" ..
	"7ytFgnbyJSyHU9Lw3LZNquw3DFm+4gHT0MW/fM65uUyE3i8K0Ed/80XoC4YeJyon8+EuwBTyrrKEH/wGcwrY0doiAMppKVFjTsKn" ..
	"G+CUL6rMFe+9vpk1+wo5/mc49YNoybvTngQ6UWD13v6fLF7kKfNP6owWzEyJ+Qp+y2p3Dzv+MO7hy0cfH0r5W3Ca7URVBqSKuS+z" ..
	"5iltP7kr+qX4iMA0bVb9LrkcrEaoxmcHLVXD3AistiNPe5g08rjZX3qrRkfHvgeX9AOf8HlCEM316qrZcuO+EcTj7QPPNtot9Smq" ..
	"PiNE8jNpIO8Q1xnx81qeudlQFz3EHnKGgtBxGvXPwnVi0Q0DA5+Wr4TCKQlRHQke9zgf9ck2xDmXvhgALXORcyHmlHRNJQN2Ovzr" ..
	"RWKSNstiV/ZdrpPo8ekS180zeAi20/zDoLuS6BM/sA83tozYLoeJ+J/VHK0oTf6hMW3H1J8UeH64W6yHi3ulBps87snF+A20wALk" ..
	"ef17T4m0JnvkrcEZ8tqQTEQkDpa7uqSAXbdU7auNU/jLQElKWZpiDFOk5xV46fz9TSPrK19fJgze3ZZCAVGmkryKQ7yKu3Uv9Fv5" ..
	"9iy+3fuEfsXbTq0joAmMFLKDYJNBZr0rHwhizDN0ItoMnjoEKlFiYsCc3TARm77/WyocnUhG3plXoPO/czykrW7rPYtdeNCSjTsa" ..
	"IKnGpB4ZiNcHnRQWUyr1ct/FJj7m0j/NmcD+zOld9Q9a2nDAFRt4Gs6jK0XGPQyO7FpOJqJCkk69jGo1201cx/X4LWqIHN/eRArm" ..
	"plyW0Iw5MWsaswq1JO6+0x4eWQsPznPgoi6wdm1d++XpPU3dxrSALNxb5tDPJ+22rw13F8C4OTNHKQ9PHf2tIwmh5VW0fpgQjKAd" ..
	"O83o+/fT0sbNKWLSn0qbL04oXPbowwXjLL6DpUJ5qbS7+cHTnnAN+VlOnNtY2XPilqA2Xde7u2R/lG/bzY6JkLNaxp1nVexxH59F" ..
	"7F4h8pr/OTEYKxK84W7dQfovqMakufKEHbL632tnVkwsAub2zaedMSRRb36GHsET7d5lYw+ymWpyY0fv/2NBWVyJ6OOC22qdmkfb" ..
	"BDHf3v/bvku7tuTyqhpxzX+C0f4eOpr9S/Cn9OZoRl1R1OyehaiuplCGnquQbOrYqj0quPukJ4PWtYyUYPlLia1Qje/slGDyUMtK" ..
	"xb2AD3muAfNxLF0u3m+wrhW7YWqlh5M9p63NEgIvsTdQYtRZXuzZIu11xLEN/q3Pu9rghmm6l4k0ql7BmOSEC8W7/74P7QjVqaVr" ..
	"4tz5XhxqR9MZ+8uhLdf7t4iUlcafrSgQbGuem5D0coqjlJbIlYbV/kjMim1DBucqt7WDY5BSmXOd8q3mn9TIrOO2w+dIq0NiJh24" ..
	"+BIF152z67rAcBNoyPw7TkTDJSnJAEorrql0uK5zhzInRrHxNx9ZINkMsN36igQoZuvrN0bcHyh/xIoHU8/6ffnRmp6NmgUt8VEc" ..
	"0QmMkC+57AF5Bs5l5n0wtPf6bfkJOrjUYh+LUDnLm3XijRutAc7kzKjqrcgq0aAeQYEAVly07914FTvUdFoO5EO2OUf80BKJLt7s" ..
	"oGnuGYCuwZVC6l8n5BKSPwqKu+yKmtHGsSqUB8/avYPmW4fvtU6aDvBRcnQ7qIo2YuQjZKQBuuUi9GGmtbgqN9pWHMj+oarWghg3" ..
	"VODx7GWi0tnVtQ8z7iFUT2UcMnqNsrZeTpGqANBWNLxwnYkqqpNHXdW/t4KN59FLl8/f4H3mkwENzusBlEj7sz+LP3kjuGeFx5mN" ..
	"64/bINDramv57DSoejt77KbibeCuG2VMeXYv/sHYUtIl8qS/UAOvjZi6DBJlDLTtuYef3WYssD9TuuxcbjYA3dScPot7w3eyehQv" ..
	"r/HkhyquDz+0FwOtLJKQxJe9k7kb561ueKdFnejsKVeqySWCHx1ttmjrJEhO4E0Tk5tP5xO5UqBL/z6OLnC8QYviksnsqBh9IyGs" ..
	"V9qFprxT8yA7+Ffz5YZVdlvF+S/Xk4j8zEI+7SV996J5teY4E1ienxKMgAmI9M+wT/gIQFL2nFHK5AyDw35QbT1dDhMGYyci4+Wf" ..
	"afPspt8okdZxlXP8Q5WRbVYQ/NJxiAMDyop8VH//UcD+G+14Avknv1QWyrm4F12+zWOZY0IMzxjXCYhkvovKRXUkI2nVhEVuiBYd" ..
	"l7auZeraw2lLJ54Q/MwOPl1+8/2JqcrmYehbZV2/RVl40/zCptlwXDxkI1lm6V6501A7d6P6tvXtp247EJiVvb5AQ+8CunhCP+Yt" ..
	"Vpi/RpDWgAMb/G5hWrQHW8CCaxpW+JD2WBXtz92k+ytUWBSAn3b7yuf4i83hkVPMlCbEwcI6QSBIYCh5fkWhIWOa5NmQtEfU7RRU" ..
	"sXvdL3K3MQO3ItjAnM23BgiB4jCQU0gy+FvzPmkqJciY/+vzVQJy+QCI5EZ2uI3RSjBK8Rc4Jo4jdu4w345mSu3J5/4Sb69n/DQ5" ..
	"YF0UK26iInkUDbkImj9oLjvLEK4Dysbdqhzo3on/26KRf/g5Ry5WDpjpJqZrc0E9JgCXFJz4RRZAUO1a9Y03eIPT7GF3nfDOCaIM" ..
	"VgUJH+zRllwoVQIL3S5xRAs+vW+UiiE6lbBQvXuAftIM7kfekgfyEM160EqRgdq0EsTCwcaKDd9uifgaHe4fzqPhVW2rvHbWB5cb" ..
	"v/I6q8PAviT05Ug6PaORYydQCSk8XZlx4N/poK7hCNOHrbVN67ApHoTTZE+h7NpVWNURWZBxfmbrTyPRWx5xhgxx9CV6x+MDmLlh" ..
	"+qG+TWQd6W66KHBQvJmfqjIPKLa9uRJZJNqCpKK/Ltz9sTOZ/CU5LADRTFq4g1IUXOPL1pWRsBRsu63NfGga2cfEcHZAJVRchI/a" ..
	"yjc65B13JGsLEXlSuPDB2rBljPaQGWo3sHkr3Nf9lT3KNyyRkWpWwUHipHIUgCggpkXXETkkh0actsMuT0kSaPcC9eO7w9IaD0YQ" ..
	"1alfMkotlwjtY+5aYIIgfBOClN4qFxUJ4aLUztYfs2lyl4CxfyemTztwvq31wy2W7K1lbVLmlxdHZlW8G5gdsVhbU81UGK7tJO/9" ..
	"d6oJvQF/KDBM+ISjkNjvPONBjVy18JUoOjs0WVN7mkzCnPy8tSeEagbry283HSuK3t8pMJLKQG+4Qw47pfeq/I4/iB9VabAEt61G" ..
	"F6S3AAL1IvU63uCNjNekOzOI6lZqsBJBBlAqeSOrAfCe5w3PimHso7flqzATuA4AL1KJp25Tcp1YcmelQWDZNp4DWlAoD2Quze6v" ..
	"r9yq6bZ4uQtiDN6hB4EzQ8RR2uw0JwHcGc9I0ZUDcp0Xmcr7llw+qG9lsU1xxFsqhLNdrq25+jNnXTprdLJfc3lQyvpMzrYb5NhO" ..
	"oDuK/L/aJRQt9rlsktUiRDpO1D7PGd+ZKs3Gtl/UmoDTmR70N2BXR8U2Xvv17YjbZ6H5of0GM3utl+xn9haMYre9m2C4uRb9F3uG" ..
	"fRvjE5BkWfgiu1yFvy67TvspeiNFHZN3VIPns9g7fdxG4Qj1w6968CExitjUqLbmA/9JCBewTycvVt5pWnZAxhLj9WNDalVPnmgG" ..
	"Ufg9VwznUoO8uJaR7FIA5sNT0v+tV+SZtHvLQoDR8u8A1uh97uiC+cSNqFhQGSMkposjus2CTmAgVYJzImLjceFwI39TnvsxpBEw" ..
	"6nbOQadx+zV7ZIsklBekzj75koMzab6FxKOD2GEQTSWNd6pqiRq9NAL302cdy0ycCfJRAyJEzk5rsXQOv+MFAbXRd06CxHbjpA1A" ..
	"basvsUvKNcD4FL1cot/ynhgXPn2/VfQxHfc0oxXamYwosLnUCI3mWlgyZ2mkJ59+cu3209QtqQC/BZ+3bGWyNtoEBd7+aepVb0c+" ..
	"eAskskjGolKkAKeWMDpBQNorq9h+k7lGKI40+CtmphEPZBBkoOAkgz3TVljZvWEUTvkzshKTLlkvlRiuccC7L4VFrPLjq8/zbrFR" ..
	"HMUqwBa++vr/CXIdaaGMxjjytaRt/VNshx/L/hVtvJG0SVDKPvNj7m6IJPRJwZ/ez6v21IsNgGl9yjs+7+oF90HVAi6rgtMKdeBI" ..
	"8Yv5kxngnJjasIoYNKLMNTVXhi/mkJcZgeSP4aLF3Q5NE/6jfuA0feZ8tWNRo4egHZtI1rrz5yec5n44bz2f6zTsgUyofxP3KyxK" ..
	"PpOjQclsOcszBAgEF2FaIdboO49uXcIGBMZydYMd6YG9Pi/jMdCHBmwgFJFRbcVJvvGdvW9/Fkm63MUW2G/UXn52KOuuK/ibSqmI" ..
	"i0SWqY2pBkhRxA5r8wE8/vfJQScHJPeGYd3XB6yfSZiggztQY5mQ+W8tbkwgiuuOnTaFqIBayebFUMZxzX1pIkHtjzwnidhrK0p7" ..
	"PTPK95YLwOgX58aYrmTN1a1EiWoQI8b4kFxqS8cjn01XF5V3N5hJNnxdw1P9z5uFtRMsjbtovjUs+ch6yq+S431RwSo1H5DbKhEH" ..
	"dtjhgK6B7vUD8kacw3k3JUnpE1n0WvpnUgVdSTAx8/zqf9p+NlKtKOrUB0AyjVm8K+Q5pr9fSG1+fIPfZbeQFsGrracWnLPb7i8l" ..
	"bRWRDoO46IvB8VqE77N1b8MS1DZokHJ68xFlB11BdOILPdDD0oRHzOTQ7yd6kZbdPbReqlu/pQK+60pQuyQIyw4nQj4Ya379YSEl" ..
	"KkuJ27/gfxY3/nower6FuAaA+CmH0B8hSpjxyJnNwVXJJ3VP1NYJfJA9yWXmz+RqbeCIrJRrhAZbMVk0OdqOVn3co/9oyHVL5tlE" ..
	"E/QyQs8nWjqZrBIw83Ht5w6hD6LeAGfEMQThcoLxiYp7R5TYWiA4QUDoXrD7nv0hvzczBIHvOlLPcf8kKMGcsSpobyW/gNjIQnYF" ..
	"IOjm4gMB39/ZldeHweW1vp6EPhCdnC4FAg1/VdX3Ts0i3tFEooVpjg1BGMy2P5dcfq1XNupyJt+Rs7yfoVSUA6S+1eTMUM8UNhDs" ..
	"Wt4rK5y5c0PObeCI9oI0CPTjY4pVnEg/0UWpqzRusWlrN5xwWCSdQxw62Gmu3gSBIcmw4i6BlRPj2Xvb88W1YVEu73hcNseqNaZH" ..
	""
local PAYLOAD_P3 =
	"kBTouEgw6MRFrGvvM8tReCwyU9aqUGKtSTy8uUW+Ifev5YY+h8bwcS+VOAUTzM3C3St/ePA2a2ZNCEp0adtlR2ZNj05d0PwhIYs8" ..
	"LZ0fLIjAymzqHn9pgoFk2AyUTMRX+MKqk+2pLEti+6r5k0cxc+cKHx/KjBChiyp2fjomR4ZP5DPh3KW3u5XICst3Y7SPYib8fIGl" ..
	"lkplghXxHXZmSfyVzRDSMzrs1EUEKtynqDTW42FUV8dW2DeFguWwMjG/bBB3bcomNWpiW9Pa9kANWxedPurocJVZ0IOrLw2mYhmc" ..
	"C/v0NNmAaqWr0dw9cZbB26zYZNWzLRGAbCW4ecpY3+sk7OkuiggrjC99Cm9btqrDHw+fEy72K/ZIkA+G1fxLOjzz39tryL4pIiRk" ..
	"yvKZ8H/h2FMC4G6pEPtHvjQgCFsCeFJ3d5WI1/VXUHdHHUBgfw6l7k+TtC5yxc/YjhSxXBH5cqCJ5+ioKPXWTlYd1tHT/2hRUvm2" ..
	"BWY3mGvucx1OJtZtyDMnfkmPaaaevYsFjIZWBeKcbv078NIebrY8HdCZsVxoZ2x0pfBlEbdMu8rpPZZxdrcTfYum9j5La3c+W79d" ..
	"4FJrb6smipts1J3g9gAt1KF1g9DBqW2XrlGsOQhEfkY+N0zht14LlFNlMtIItuey30ScgCE5jwZKWCbb7wqS+0V5O6OpMVU/JfsF" ..
	"VG67O2opwmnkDLqjwfMz/lOtZ4l3HNKC1subFiHXBEE5JcCNrdWI65Ot7oPKYwolHXgzLK3dXenIlChoBKSarVMqBYktU4E6d9I7" ..
	"UeFJ96wkaYMQ8vNIpYY+2UdryVsRrQ3iHl/CDc48+TFFXBs4TH3Xu8W+t6aR1BWGoO+1KqnvTaxHA4w4k7MJLJ3b9IWpbdJ7MaMk" ..
	"7vWSBUiPGW/m8otT2TgK01qPaKcmHe6lH9quEpTUsnv/8Uy9lTmbT2ulaOMDQTrpDKP0LcP7ly6tHhYxd8a45iEX43m+dZO6+whF" ..
	"eZgDep7Fo8SOLTbZedPAkmVkwdUxnB0bh0qHHStOLUZCU3vKWn705qA1XiTLP2hdtrLoJ7HwQPgxr29LFgOttabqU/EIpUgtVv9F" ..
	"fowGKdjvWMnzUV7KuG2f8NGsym7dm1sLFvoZF3fEQZkQrCb8WO6bIvq0NVZybmjcX42yhsm+eMnm7wug8hxipRwyLAkXBz7XK64o" ..
	"7jtrQ4hOxx13khXqkVwbqoZApvmRNkyx4Tam9g4MiFXHjoV72itgH6tSiqvmeOjelIMInC2IIhxcM+93lk+vhjE9h4RTKAsv+Xdc" ..
	"c/elm+H9995eEDHaErESusOX6eXdOyCcTG56oN4xZKgq68aGs5n59i2qo6pd68LxvXJ4CKKSJGmEi1PkshD0BVW71q92Z74VIkDN" ..
	"xWN4eo1di4HycWO37kxj8BkqI/a3vilLgYusLywymldvk4M4tkhc3ZEoFcauQIz1uMsruYCyUJR8z0JwFEFtIlbItNjqX25zkV3V" ..
	"FNHnETlfzuFJEN/XV2AmLt4Vbvh5qpXNYh7tw3se6qbi29Wl7LiWWSgZMdK2L0jMi7LwWacFlTj3EDQwLVDHCVtRRM9Qi8X7MV/A" ..
	"HPQ1bFWqT+JS42rCuGW/Oe+8/Ff6VwF/IWg/CUS+kpprBQQMA+oFgySrTVmuldgeHLlbxUKPBhHK6gg/TjIdOImS/766vAmQltBn" ..
	"h3X83pV9X5cc4k1CrnVT/GaHlf8MjgKXmmurB0NT/ULF4oqzH8u9ntKQ+zYR5Zj6Q7nbGo1q5Mf0jJdN/CZU8nSIaj2sE/nFcfvG" ..
	"PCu3fDzAUw1X47/NCaSXmUISRzsSAtBbzrr9G3Kovn6N9rW2/fkah/Yx7UCyH23eHnm5wrhiT3pjFEGpMITinpnVAWUCrgQ05b0w" ..
	"iTcCj7x7ro0cozeOUE0TaMBlgssDu5O19A8lK4E415cMoIpX7nTbCBnQJoId3B4SqqnfzuwGPAT+WVIqTuvIsDjmwFmEe8JG7CNF" ..
	"QfLL5UsP0NHVZQ5DFRX0mlXDnWxTRQZa+NJlHogD1nXWcO8e67NEMLTgYqbEMxJG7eySSVJjSzOw1KguPuAo2mgYzfoF/1UhnK3U" ..
	"BYk5FnJJBA1HrQi8KTsc5KmGirt1R54thwMoP0NWQZSXPpudfC4ptyRBdzWtvT6Km8W818+aEnkJ1EWKMntN5E+CfAfy6I2g3z/O" ..
	"RuxwaPvpaT6qO6NXzud6FgTfSQSIBs2nUnZmY4v3cHpLI6ar7AXeuTPPhXw3VlEEblsrgaJiLulmmgmejentIXkHOEadPpUTlwqK" ..
	"+e1nbcaV1okUZTuWgfqbIwAeALVraqACUNHmFBvG7JN4YOY467tytFNhPFsgo+nhB6DDsufn6+/Xr0xLFbS+tSgpGSJ6pPksS2Ye" ..
	"Fqq/gICQMwO/Uj1VzdwLjVtktSWlGbuQo+/kFa/Q2pb3iGtMkerkQtdoUgEMoJHszNrl5lIRBBrs611ptt4527aQD8x4+kCMbqjm" ..
	"FN4R5wlK/NMlh35ARFkg4eHSNykDywrwEDQIZdIN5Nsd7Zcw19lel7cTUh9B2TYTOO47ALwkVPpb+XaORRrYQDCTuIVMagle9LSB" ..
	"Qfav6ADrTqVuiCTY6ky1KRC2360/PnAe2w2FefORC2nDMQIUnk6sfLgCG1yEiHxzc2l5qWORwNpnveJQjt99ez/Hc7asmyYIy+le" ..
	"7oXFkFPNE2YU/P745LEZfdOULcOyua/87c2mmUHZRKDCIGsuT7xSAoxYks4si1sbzzhnWdJe2X+EK80s5slBWXqfUbiB6KlStyNC" ..
	"7pZEeHTDY0Pul6ePzsG78yCI44JPqGPcQ1PypgHO9ARzeK3y+Sw6mk7g5aE7T3FMAe2w++e+t6FaYPMace3QJHNTBUll4kpE3SlW" ..
	"iN0XD+tF3KfGb+tztDR428syDbbOChrX866kBhwNcd4paE/4jgpg5TjRe7P1GQ16cX91nSw45haYJViT/PFOZ1SviJFvBaPsH7XL" ..
	"/gBFg7EsglhAUjoBusqewga1wuU0sDUS0E9CBpqzRVMfGsk3b6vvCRP/cNdLFmnFQy01utKqD41gHeRBmXpS1QAjRVq4fnaoja/7" ..
	"4rORcP5QF1HugA4EXXzA+CjIrVitPPUizbCl53oGdRnnPGbJlBdYW6+qeXmmhvZtY4Anb60G/p4IuATOl0tZ1viVFYwl9c5x3LEA" ..
	"DC+HoTLy/cMAm61ZbYn7FOeHQwNWbRZbULQpYvUMBOkwm6ZU5t5CZR8DR7JP88K/5xrN89cHtf8p1IaUZbVUs0Bb7C34ikxs9V8t" ..
	"RMd8fhe/VRtSHJztpdCthiu8lqkhz44S+SxwUObAeBxw2fRRtgBByO3GzSjjecKMD7HsosM2uJhyJu21KwfhIZspueB2aEJHvddj" ..
	"iRxJBoxINBiZTeVo6/2qtsLik40ntaILnvdumCSIlsKxmSk57PgIrPpenWigY8VSYqRW3WQWEIoln73xyhNiFYxPs0FY1MdrojXO" ..
	"5IUHjtPRfNdYc8ALVUTcqr9Px2vGr9E6hKtMOGe2qJNw4kO4TuoJib2aMfLmx8CThFOOHkuup+CC8LuDEk7uy4iiGHzAQzPs0RhA" ..
	"GhzAMHkNzMiiioW6rSEX7Pf5p+zQImgY3N66uLgFrBG6tpU663lKwXA7CWCzrP3eWqrB7VQDnSgtaiTdLdf6rRlPCnPR7PdW3JmL" ..
	"GSs68knQ0aHUoPGNEldOlA6uCTLSaO/bEzcIE4o3T529oH8S+LlCkq160XfvjI6QcmyLssG6tp6bMxd935sMKpx14/mCRw39gTfI" ..
	"XxDODNREW3S3f8S98ttrNeh6gLLD6ruykThUw3j5PJoEsfWA5QNMC+me+wac07fQq59UtCrRAiUlmIMl9OrnjiUDObY5S+AgjAAk" ..
	"tRnFwZv1iGL3/+0WOQUU722zP3Ip7/rkYInY2OWc47YCYXd9YPjoRYNK/soYjTJxtHes2dsxz+GERVVrZObTTSV5ovK8lzUvsGi1" ..
	"SevNUpOfm+7t4BATiAjDMxhIhxeyqOn2zOySRUDljjFotm0svoE1too8jXdudTYL278RloS42hW8cWY4dK4eL2ENm/sl4v/MF0ic" ..
	"ogqdaPWt/qigrLi5vxTjOjRIbJ/f696r+0fPKm8pdHTJLm/Aue2U05djqQFzn4v0tjTFZvamqKXRi4/7LSmbHkt1SJEkuh3FFlsj" ..
	"1/zHnBWsOO2R3uxMO8dxMfxKguNQ52SVBjMZePq5aVmC4iWWfot0QiBYSb7KozdMUu1yQZbOYW2SNQ1iRaDDL84QNl+ED7Sp2aFG" ..
	"TdHgh+dWO6TJYJ2QW5VArw6QzkeOZRj+rjAqC6IAzfdkU0gIDTh2Aw83k2DdUB2mXrZB1vN9sKBjmAjEf/y6LBy/qsXirjmlTssc" ..
	"kck/AP1RGX2w1mJteD78oXg74jvWbqsBSpMlt8WzNBQ195KJxAtXNEHD1DAH/C8VTdzBtVZJzxQnURWob+UvmbYg8s14Me7UkSzA" ..
	"pJjzuHs0W6kHLMb/Ao+53URKqTk4NTSde53NvlRMLDGwJW+Qe96/oqoqg6FP5DHo5n4cx2Iz6uOxQNouZANvOhBSDiXtjM6M8OWh" ..
	"9hOmjfCpc1QlTgpQxLs48p6PkTYC4wFiSTEDCt//2EluA1S8S545YvGQPj6lNdYaWSk0UConbZT2bwEx+nWPbxWkN8q2Dhbhzhxn" ..
	"OO3FeQT6v3QlWhYo6lvCTD00zybsyJ8+4sqVb5MasoXUjIYWpa6LiKC75z/QCvWXR1etCQlC7oMqdNK0N/U0xh8eFJ3v22/WUvB4" ..
	"0WjRTP4zVqei7Up7KdHxKqfBM9x93vgUYwESSlxdV1QTXftWEyCdXxai1JVwAgoqFgZ2WZbjRbUAcQzPGeZmLKYqZopZE6VymYm7" ..
	"sOo8Zh7sI30+YB0zV6cPpy/EQm9JZwL8wVO25gcyFI3eA2BWFmGneQ/lgVI3SIn5wVStORtK26ZmzfJyVgaUgPxFoWATTUs0g8RP" ..
	"EkRBJufFMwqsr9Tw2lY4MTRE+rSS2mIvGJ+GYwNGFGxzyWdc1yPg3Aq06YPkO18zQo3uBIoHus//7w+gy5nlyfVC6xmKLKpUwW0q" ..
	"08ull217424Wwc1QoElXPeoZLcdCdQPnmihMZd+WoTt5JC2QTJVE1YIZ8r64rWJqcu44tfvyJ57qOJ2VeP9KbG+WqOBa+9IRb5my" ..
	"rHrmEmJVnzmZF3xA/4sgq+dH5aUFapfL3+Me6EW7qAqq5DOIqYLsODSmXdjN+bGwsRCHPvDC8Q5z0jLGs2zG2pJBvprDjN4nNgwG" ..
	"pBu1iotMvgYlxaPnbWPnxigLUbOcAvQntNbuZ12Ys46y/u5heFT4Cvl1Olir3FEt2XCUobgPSlN+iGu4ux4PHJn0T67yP0BXrmwu" ..
	"hs5EZos92wQ5xV2u6yxTM/5KRdIHAhtZSecb+2hKCoPIadMnrov1qiyScpDnQQ/XDCH2ZwSVbQjQOPCpWtTLjgQwzOsNPezg42zV" ..
	"nnZEZOI23HNx0HOhkFBZ/YTpQFw/FZCS0ufFbpHGoPrPgtEvxQaIG8Bk+Om4/fE+SXTpjYqL7Sde3/5WcGsK/7L16dZKjk/pnwBb" ..
	"WbO9uo/IEgT+9iHTNglqFTw3g0oV+4RtUaTW9X9OCLT/I/TM+p8bu8QK0osF1Qb2wOvOVgmSc8owPOVQYU3autNOoboKfB+pO/Bn" ..
	"IVCH/CjX6iwGnvvQ4lyEcmjoJ6hCCOiS6/qhRK4cd3O3olbNObIxgrmggxsQ1AJomhxnri/+ml8ahCWN4joE9VCimVJSHM13nNTf" ..
	"/Xkwba4UoOvGDnys+7IiHJBh7S2cHG6rDlLLpLlBmUAJAvJHdVIGe7gsIcCgwA1UxN1qigH9zQ96+q0rImFnhs1Oem6C0gtzxIBh" ..
	"XoqAY5s8RoWLE0cHkra25vPNr0FM56+a/5YBphDhzmuJxpTnBIOJW0fFGLQP6ZGBZdpiwGl2b5zGxr14koCLZTAqYY3kO8hBf1Ti" ..
	""
local PAYLOAD_P4 =
	"xjOuIFbOdXVe8eZTGlB6uzPnFZ1mlQ/YT6ceHoHEVg2r/ulcjNVCqdpNCzYC007f1giv7spw5bTjnADfYxDHm6svkNZmtIs0lR8H" ..
	"ZnUaGH4hE+99PbVfk2RVNiGKKloK4JPlq2riDSGuCmcTX/OCOFraC5+2uq6gpAPG3HoZduLJfnmpHgQCob+78BCjXBJSOCC9Cdxa" ..
	"t7ljtDgKGnEjEHqDCcyTcQ2bctF4B+tdRqDI0IQdGy0Dzyb2IG6YOJmrSt3zIjlAFzkeTI616q3kFFh0ZGGzJE0bCHEekEHq5wMS" ..
	"nsY8PaCMS4+xfGfg8fhFZOYN/LnhjCEuoKdNseDS38fdqTuaqj5nZppp5kD+LpLOL9LUkJMJB7CB4HPNaE1hWYB/6ewAEX5BMVFy" ..
	"x52sI5PvywFJ+2H+ZN2q8/tx0teWnOsMUovAJYqJ/3b7opTcNyTsDWd4/fq5ukUUDirsNggqZiX654oomzVYY9SzcR6KC9H/11s9" ..
	"+NZF23fOCJ+oZVzDn0sZX+YCU2KBSow2M41v2rmQjw5UfMUCZ6Kd6QKZDpHSLssYcfriGwneVq+WYgUt7ejSKJI03Z0E/fgWgq8U" ..
	"WHJvxpNi4Fyvijgwtyq/SLA3LCVBUogwlOlKajVAWt7PeZGJHAoLaloMH7uSCZEKu9ovbDeGUXoMD+JMBQMDxQKhqueSG4GFDw1X" ..
	"+IHDLc4h//FPH8QP/pFZQ/BxWPECjv/yvEyjjKq9V60QtmfRTOW7lUFEfmPh3UDZATGMHQfxopMqRvXQBxKFDjgjpGWmYPFZcyYp" ..
	"KSavfOwAlXHMprBcZplkqlEI1GRVGUvXWc1lQXiVVKBU7cj5PjMEVU2MWd5kZz/X7A/T5RNR0RWDRzAcTwJdRFctkbtgMWXtkyWr" ..
	"zdbnUzgLTVwuFQ2WMRu49N9njpsTJdAcrEohLBd1C+/9YfvxJ4EKuGOP33lAiL2Z+ihADrpgqc8FTvsDmnS31xA+YJJsT5bGkOVZ" ..
	"rR1r0BEJkWnFl5YHptFiRr9XmYjY9M6eu7OMDsNxL4v8JavqPjVKgawHp08QyDfneClfGt1fGH6FeRD39Gh8U8dpPjA28O2+Hw2V" ..
	"3b5kPk9pf1RsX2aNykl66kIKBuOW459lO0HIu4LtSlL/ojgAGgb2nozc/QP8tg7V2Hg5wrKRiPfsGci4mbvf+CuSQZjhHs4FANeG" ..
	"eRNGm0mabnaHMW5RryGTO90lyhgsCm7VqKU+PdXrSCMFeI6ICOVCGzLt97OgA3YZ73tSQvmCu4eJrClsDuMug4mCizY5/A3mN2pA" ..
	"c1+UplLqrfCvn3NedQND9SYe4GbXMy258MKQX2I/0T6eK1oTdBijBTWGwPc5XN42GykoTyclqDkNaIbio8ecsmF0CkdlGug6DkQX" ..
	"KP+VKDrMsicNqNPd1mnuzx8z5NjOSUJ4fbGQnSVkKaLEGkppebDq3QnuoioFawdw0YIOkDHkkqUhZfRefYMNilpzJvDsxlG8kmTZ" ..
	"Jz+MH3kz/SX3bU69nKmFHKQQ0uJvYSOVwHR1aDmDxsMo0FIY5fF9gnvieA1s1+WOQmpZoTMnr0dbAEJEAfNV0zm1cwAJOZT7iLGW" ..
	"NofvD7PVTozMmLQwLMI/7JwhVLnxiqKgLDs3QuOHiMy26U7AuphQQpRfmWhbNEctHU2TNoZnuh3f5+LnxbnHs9DNnL8hMNZLtrwJ" ..
	"eT8SI7+CZrp/ORyP2exQVm+bu/Ej4/zMRaM+szRVe8hF2RflIdOw0SPKjGUCAGFomZVdmUUAU5JCRy3Vlv/zx/7Cf+62B9OTe6wN" ..
	"O6z4A6I0DurYo47RCaJA6UEyR3EDw6nopqek0npltqgXof0cQGkDoR6dt65CAF1jFx1Ofnx2OFsZt6aEvaP/2u9xnapowQL6fIqk" ..
	"7ulf6yxOtjex0b+EecM4pfhIL8achffwuAuEKr+5X3i3joeMmctsBs0cu+WDuXx3fFdFgI64+XMmAeDdGiNGthRFpahmbqSTF2sq" ..
	"CIwQHaEEulkrPfKAE/FZe+yC+SYUDjB7T7YvRCDGlHeJb5IXylhcxoiT2SpXPJSSqFdG+7wTz6JzYZplpAE31AevsXDFLlu9YJmu" ..
	"ILtlm2Ud3sxNhCCjQJs1JVOP2igO6ejmCVwz2aeLMsAgwR2gCM1YeX7HDjXi2CcVyIr1/W6XJdTbKI1k/GIJXfFEbEiVqQzBG4QM" ..
	"jculX7ja7VQMIs9bjZniv62zgFPepSHmY3hw/aQkA6lZb8IZ43ydzjdb3d1X8WwuCIUh3k1YdTi8DS5v/TJ0Ren+eWTK6RG3Uo7u" ..
	"/ga9IrukTCTKNtgnAmb4olqy/lnznZIz4+rSkVZQXXqiEOAAOzV3quEtOLU4CvXbO8sjWpm1ULjOgvMbGN3ChDb8cgIe4VuGDdjF" ..
	"7ov3J5C0VzxdvRd6s99pOHWPN5NNZ0KMomcCfEPxK0KZ3cZbd8PPBG01aPUDFF9U8ljk8ECJ7NmoZr/c3GOjGv2RkjJXQqneNhjH" ..
	"pCRVB3AM9M/c0s5ZmqC0HGS4vgliwh0dF9Yn6Uu+BTJniCbbgm+z97Rqnl8an0wnNay9Uya0dOOGwv+OrfQiM6JcyFNf6V6Bksqk" ..
	"YvQ+NPLQvv56aUNRQEJxZR5IHF6zViI2bUbdHRl+kroDppbi4q/gAPJQVkgAXKf14M22B7icIKojxGyu9jHWrwcB99rwhOsCsqAB" ..
	"VvBoyF1Vd0YYJJ+E0QLJfN31IBw4xQIIlm4gvMSp9SD6lzIZV0QzOfWt5VVDQzDylZFSgS1+qx6y52IPxH5bhHsv9rSKrGpVVwpV" ..
	"/NrFUtw+fReAdVF40WpwvUsQLKpb7dAlmB/KSRpYKlWDAh6B/YcPUySHIi0pFPJuUKns0y2CPsT/AjpZB+sqhzBF7jFy+5fNKWBN" ..
	"5tT+DHTkVWC5fnqjC1QpK8/1REsuh8k42g5U8Cy6WpW6jLUlEEyR9STamLxZMvb2RBT7jVLBdj0DGc3PoiNrkXfy3HaZ9ykhjvo9" ..
	"Blh1c2LnzyAJBnYwIzmmQu8IiXGx5W7veEXTgcwdm1JKDD7orfc1uDRFH4mBBbyppHrc/z3cwk9AqWQRETD9mrrCxb88PSbd2uqC" ..
	"xpLVP9QWJPIR7acWue+uINxswny2XvOTsgg7tEvu8Fn/b7HVIwc4GslfNkpTg/o5XnLJuPvdEjv3BXnirIzcdDSm+/YbvVryjJVJ" ..
	"GjRVF333IxZXFcvDPe7UY98Mo2lH+NWJI703dUeoROnsl1AGxDrCc81akOy/cNX8e3jwmh4se5zRsKAsIIZD+wCG34vL3uFf+81I" ..
	"tyLNNUW/CvIKZ7Aft4esK9A2U3VXLpJebb4xfS99bEJTPI2Q5cf1ByL1LG5ZgFx2Ebcli5sNVnRhzLsVdn6QiZf10EDWzJp8bUPE" ..
	"DiF1+rxRJq2tGBhURKkIj9Stj/ALDUvDS2eTrZIvJINUoDUyeh96B/BfvXcNnPJq9R2xHGzHTOmu5A0R19fPe9TTBk+YSylwUWf5" ..
	"6nD1Z5KM8LUy8XkhkgU+YU3nc/DJ7k6+IMOIiOyH4om0DwMmpD5ZSLrBsLoMW3yfECXjiNSu+u8U6Rm3f2r57LOFpAI1UyZR8hN3" ..
	"AehtKxcNCxj+vFuzYoWP/qL/zsJGj0XpLTU7PWKYU/m1K5mow2CNp+yvPI/GkIi1kQBYHNf5UiMdPrj/SiBJavz9W8mLMd87VAAE" ..
	"TDR28AYq4B3vBrLpfiy8dkggHIK7ME8RauFPj+08nmN9mTJi+aN5zpqAWbHRtU7+rROTYrMhz/L5bCkFLc12R0fMV/c6a53Ncw/C" ..
	"mjuB7qtVqH6843Vp1+Te2sMGttqrfDrktFZUcVn/mlsw/hnOVPcNxgjs+KHsG0pbhMgcQS3K4ME2ew+Agx25ke9UeMJFVRkhitM5" ..
	"HUwf9lSUi/lVhxyfZUSThit5/x/kYQ7vI8zw8WSPBlgXatjhqNexHH/T9/NkEQKOhbIq6XAN55hMVcpsoKynMufs99L9aCoYKMUr" ..
	"uIGMjQ2zsFy+jWDEPWGTcL6iw8dQJe6kC5MHRD/72/aW2hUBpdrqlvLnf+JuEA6OHZr9WVEHJUgS+NxuWkMCkkJTmpbvXwDhPWt4" ..
	"5qZfuzCzGhwhdu1hbOCnoEZM70L4Ma8pKRe4lDMohtf9JXAWF7xzE0a/VZRVOxPqHQ9zrD6F2n+/MYeX7RLn6JYDbkc7PZ0eOsQ5" ..
	"Uk6xq5DnTzbzvLcu9LOdQCbCBY4wJu3qlEoS6w85LwgSlmDU62cwXwcSWtC51CV1JDrZ9O3F4JjNh1OkBi6dYh0YTEP51bJKcNKf" ..
	"VNbdDRnifnGENO3lTvcjtMsZjQxGbLEFnMGkC7BAw357HcynOXQ8u8dsAtSDuuOncIpCuLk1jsRuA0g0pgXMdLPKCglTf2lhTzuE" ..
	"cRLicA3a6V39l3+y9XFlf33qLPa/VwgVW/EkZBU2llrfZxI2e9Vd7813lQimxkRbr+HVqWZnAa6fCmdzth12hjaMzuEQdoiDehxD" ..
	"qhZ+MWWebQ8zIoxV3phBcRcvQUsvTA31f4aMCyqEKEmd0ute1IvFejXazHrEkChcpxTbFj12EowTFcQ0Q715VBBVzbBob5YdKF7s" ..
	"bqkFP+coNF9vd5fUSN9NKwQZJmc1GGkyEEftznDXbEA9FISUeotfqEtCSyR8jKe68VMWYIZ/6fE5AjZ6GOz7opVd3hy47Lo3Cn5n" ..
	"jujU1K/2wOs09HRg4a1w/wSQMWW9HG2lsOAqO7PlkzGozkGW0g+wjluAXP5cDz0ablshHFT8QHyz2rc76qoMpyj6PbWd97JSQ+mF" ..
	"eYPg8j5pNmFPAFt+Xf5DNefR97F4sWIgGSPlRzhLLgYosLFoY2Mmb0pqf2oMAi30j5U/12bvNn60rUXXNp5zvVKkzYIRte+wMGqb" ..
	"aL6H7uHtC8fLQH5H/KcTszKuafWg7aA0tQ0XDnhowZShqJzIM7UGWEr64GnA+llMBjcZlgDKIP1d9dXCG5Vl8NnMRat9o1iCoFiV" ..
	"pNP/sZRui6zGpyH81+iU2msxVStB09CJdOBZiau2qfrO2idLZ4Cd5GJzmlf9/4s4l8Za7PIh2ZV98OxHBvHNu2MPiYF5wSuXNOAc" ..
	"TTfEUydmRp+yjeXk2ssg845FSLj49VHWZuWXxZp3DWwPSMZKZwgw7uqrY9Ip/WnVostYT3yOzxk7D3W1n2hG86zt6DLwwSgu2/Qg" ..
	"Gd1RAgUAWP5fdooelS/+NxOXTUgYCZL6CEGwEt7CQtbQgWg31QPSU8wO5vDmx8UCXk+/lisN5jpGhK100G/dZ/7xNNHNeBKBeW3P" ..
	"JAqz/PBxCzE1o8a1E7WSJQrViY+7vNuLn5yV0vzehKe8U0b/bsbocNoGGbx/A1ZFIArPWSompGq3W7f43zR9WEreW+NaSRzpnDRj" ..
	"NS0uiMXJEGBOaSRTuN6zvqEPVpD4KEi/0s63EFBuRDcDdQf2Pny28XJsCb4naVf6vxs8JtjJGLsc/ixo9e7uAgW321mlaCnLF8bG" ..
	"HGF9VtsrjZYzkXGxAYhcTcqVOCbLtc0+Jej7Sc4hdb7GlCT2pqSJd9f8HiHMWTXfEU54kN4tpChLYsT8rw973VHtA7D8kzkfv6sJ" ..
	"b9NUtiQ3vOJ9G9y7LqUqRghohldP6ntoTuE51M3ieWXruCGf0k1IJgwr7Is1g8h4FaFQbCyPLFJEk5FjF5jkxR72hbaSI6g77+eG" ..
	"hB+aGSB+jzVCcu2qLt3eYQoapH8EISEbu8ejtPXh6pRMuaHfXvXhwR67M+RzIHJm/peJ4M1WMpF2vIEfpW/qjZcfrNnUcqzQBQQN" ..
	"I4LOgIegM3WulXQF1mDp5J9CJP1zRQHZgnP1nQURXLkWc+qZaEq3reEPpe3eXoD2xeS4+Ojt3xI7cQ8MGej7pWksx0aKcmXCf0xN" ..
	"vi4WDfxA+DrKIgiDo+g6e4Ko6lKu/lF6fNzvZaQ8TnR4X3Po0DVqK7CiqQQcTJuIOW7kVfQdy/YfXlHNJUCAG/P3aynQXSQux2L1" ..
	""
local PAYLOAD_P5 =
	"vYiRvLNexrPLGIWfMxc00icdDCcMyOkR0f21MDSx92oSCftoba0SUtikl+Fgpj8dq952DA7VaQs9QrA4nD1axv+IGq6W0DX9S74T" ..
	"IbvRls5PoQi33JBsS5bna/4Tkc6MHxtr7iwDrCfcHJxyfPizXi51NVygiaMIrFx+BdInWZxsJgbK611XrRB4PLoUEPcWLbIn+fJn" ..
	"ZNGDMc4NWWNJ5j/l9ZBhjW+Ka4Oaj68doG3I5/fg13xnb+vVASul935dAKV6rqX5Aor4u8l6T8ovq1102nHqLpqPOvHRUet9i/d3" ..
	"0Fsy60jDPCbHvTaPAdpnPeVWgnjrdu9nyV1uR3/zTyBsVdsoHrogMulOkc1/wrTJOXWI1LN9ydouBdke18QziNcY6SIoHDMRzHzc" ..
	"xcCRQlC97DhJ/14illzVEUyJiw5n76CgARVcNFFa3M3fLsmLRgxJOGprY10A4kKC1hfo7EnYRQh95yynFUc80bWYcO/tQGGhQJn8" ..
	"rlMDXEB2dff92b56N43tLKEg+2J9Z/leKubMyqHC70Ym9JaD4TOPLHip/JwsyV4HR4lvJ1eAS/i8wZBYTJBeQU6k/ynCyDW5wcEd" ..
	"5x7JOB6gfOTqgr5WNGokwtfNAQKA0IrGbJPeMZhZ+Iokmlt86W1o8MIPMJ26jI/A2bXtNFqj8UxUYa2h79y9rtKAJtyXJq08Ye5X" ..
	"amd5y3/CvFapKIukQFJ4cv6GhIbDqbfBnEohXR75yauq0Zfb7hjHhAypEID0kTvlwltSn58ZilyyNCNv4Zo/dBliPi9IMPoVe3gc" ..
	"V30uc3anF/PhrQqilvRjg2DaQtndjz7O5cNFN/co9n9Ib0xZGpC503YMIP/ubrnCFfHRgBbLlV3EUki1X9/jG8U72iAod/f6a0hc" ..
	"Z5wBQ30g1yZPBSYq/hxzlPGxhsFQhtVLGyzEYkHks0VBtgB1MlecHz0C0t2CjtT743gVYsN8gQT6wsjVcj06jnPM22Wzy9ZjGHfA" ..
	"7QimiEB65slb4eyetjSPUqAUMN+znYKfEAgnNXvbDWo6RNYvKBar2l8dgR6KzqMbVKMOHFDpxwobFebS9r1GkecWCgQ2KACx6zmd" ..
	"7z3W7TuhtrJCC4wlpqLBgCyHt7CxMwVAFq3+vwDXiIGI7MguXUTUJs0bPVJWvJ65+55Jraw0ClVBeGOw0o5AI+vDSAYVojdcFk76" ..
	"eoKHGjmfb4fTqRc/3tg+DUDu1BtKqAWYOeK77jNXXodWhRxXbQzMwntM8rdcNOxTtBRKeOXfODa4BYaPLGUeaXUpVfP++yZWgpZM" ..
	"dgFWnBJXKYODWxhHEVW2PyRM+aoRPc6g7RFQUTFxd8EetSVPPg7JHaB8SCFigxIcq4Jt+FML48FGiG3+QOhLjunZIredS3bISI/w" ..
	"7iRiI983h33fQZdihugxhl6OBdz9pLDJSGuTujSR9cTu3JzM81VUSU6ULdXJeWIdIoSDIDLuxuPNGCVSjW15ZsdVrZS6+nJS1xwJ" ..
	"fIT6HxukuWTHWSkXG/0NhG8/ERh3wUm2RDEE5CPUTYC4yCo8+CPOkShcmIkXjKgrn5svKfg57XV7b0GhWEOxFOoOjJsPCde8RQcX" ..
	"4fZNhV3w/7/2kuKxJabnvDvjGoI8KqxYdkdk7Dx//TWXeMJzHfrbI5gvBH2+o4laKa9C6QZ5m7UH98B56SX+JrQKSRmsnLOCVDoO" ..
	"YHEAa5PA4OjlEU/UHNc2l8LsqkXQY3scOoTztv4btr6TrtW1V+Ugszl6evy6AaYQaObqJwARhEnJ6CNsQDOR4Q0kKzIbTJgWE/JM" ..
	"iQraVhgZx7cier9/4HktiDPyAD85+nMloQL+MCZh+LTpUNt/8ysRNCZYO/tHNqCQTWSUW0/pgxmwQpmiDh9P68B8VGaGh4+rQqLf" ..
	"CCMSqYYybXY6iaCD6IxzokI9tIhZsDQZezPKg9i0w1fmgYDKE8Dv3QMsCkXrB19Z1Wchn6Y4h4mMkSkIW9miXHdMRWyR2miUCnVG" ..
	"QZ7v7VgJ3y/BaJEDcLyH0XxgGLewXsO5IREt5EhI39L/EBYcuuuBjNxMiCNG16gy0RokWJOKg2mDaDEN/M/EoJsElTIMwQK7rDaN" ..
	"WI+yjFY8dDTvZNXUVhtypQhQtLA8Z5C89td7cD7HxtplDxiX71TvBFilBzbkeZzpm7wqsksxkKXch/Wnh+BnKQHUfD0bDD/R2Ol5" ..
	"pucGYCLN8rYIIY1jo1Buc0CiR4jwMMMel+ZBrpBv2QoJ2B9uoqp6WXUHDZQwe/6Tb9Xi3+wrvvHNKoDIyIaj1CAzqYdO2lHWBf9y" ..
	"c3zT1LHqnehGKKjVAXUdpMlUwYNKK+aOHqW/KWpstiZ+sYaTZXwyBKVKsR4mh71lxV5Ae3VLBe5GVGnU8r2PH80ib5va4x9UFTQw" ..
	"jyJe8XeSrSQPFTOzoWeOnjxljLdvr6Ji6VGF0CWFFhc6bhDcrA5M7Xw1vmgAPkX6B1vLj4k8LOCfTDx3zFMT2EUjFRIuNRbPOLme" ..
	"3i3laxWOMLWgybJZKl6FyTyk1KRDoNDZX1DaDutNE95VkdEZUhctyr9kOnrxEFoeX/racVu4x+Xz0c8o0tR4ZL+yX8cdq0mYCWAG" ..
	"dsVOGlOsS4buquRBrEahCOqZmPnQ4pG4Ss2dQ2OmLiitzAlCwV4FfSynrgWpBXiikNwIH0lEaCUM7saYUZSEEScOaO/qSNp2wR9j" ..
	"l7gXdLz/zloKrQHhgCdBW44ZJzBzaCS1cfgOPd/Y1RmoCreLv31MrXyT9WZbX0p/G+Qc2Kd2rZUIfqGVSc/7xPLREn6BmEVBPCY7" ..
	"iJi4PDeySZMMWJx/lABxcTBV3gWE7oJUfVhIPu58f7HTFNYcMhP7ng+NnGELrip1s9zBBA22ISf5/2doGKanWx5RP0F+Hlsumc0M" ..
	"j+V7yceczf9eeYHzfxb5kUlu5s2merJxxA0VCn5Jk2iHeF5cnisk+xx0ahD/VvOb4G6r1xjJ72x3sBzapKorKheYNWVtd5KjIb4M" ..
	"iyTCZExItOcVdt6ENGYGmnEn3UaU16h+sRq3o7VrKhoossqQ9vGR1yYfMEi8rcOvS3KHntQ1pcUNv1Ljez2UWRbkgnmrwZXM7rMW" ..
	"yurO5r2th8fVqNu7mFYbucZ0ageTstk+N/cPPdz2dyh6ZOIIyK0xQZ011tz/w1icc7sxCfgcgA17oPSEUrKf09YEZHmDYDii25pF" ..
	"yfwiVrmlqAFJD3+eXaRLpXsvf/AwBTzZu7BnMIhA44hn2as8KnmeXuKhZMmpkZTS5B3BjFpLlAtBAeXl54LKlQs9Cgguldp4yAOc" ..
	"Mb3YdradDhGVsNA6PLmp8m4UqziQ+B2ZPikUaEx6TsZGV+r6JVpJP4ZObGD9mVV89UsKbk7MUfQQuzfw06PdfKc4yhMqcrpOT5M3" ..
	"9j1Z0u8UOPxpRZPfBWp31EqVTMxPzxYCAdV9aAIEVDSEji/bqYa2mUOr6mCY4b0n5hTgwMyxqRuNVXRLmiqvo022sFVqS5Hb393v" ..
	"CCckFN5LmNaRHJKyY6edrT3IJmHi4mRhZN6kWcxTDgRHturysPUILiKj61PcRmNtLQZ7VkSS0xIzBimwBi8DwXMirIplToHaKlTJ" ..
	"9WFOnLQPaGLdV27M+zILEw2AuKyTLZuaqn2Lv/fFsjilVIYCbcgmpNfN4BaLwJB0zChglGVawXW+UoDmZ25ylDxIeFux5y1SFkqp" ..
	"VOdbEO3Lg7c14unQ0oGV/dViWGYAk/86aGKdgfxbXtLI53YElutfIeK8xpOO9t6KEa+ymxxv685BgJbPDiClI9YZZzFLcBycc9Wl" ..
	"Ay4u9pm5QnfLkdsLdxkj6w0wxu1a9fZshellNX3945u3PE9SNMJBSAsJ9dVMju87ipMM+niE8u7yGh115OuY5e3Qi4bp7YF7ctpG" ..
	"ztpoMtLk3UoPCFuciUkBYpr0X6UsHQ2VQ8Voxxv6tirDdXgl7CLmMJMyVaheJA8D0YIfNEWz9e74Q7Eoiocm83nx3ZX/cSpHW/ZW" ..
	"TVhxuTEE7fZoKmV8ATmnEHJbkMLttG15cdNJz7ZGHA9e3cBmUWufv3HiDaZ9kOue8j7y7sPZGMwrH4y+8G15D2JqibrhW8T5svlu" ..
	"Fw7AL7syNSyielHPOHAcVOwrsO6cdHQho01I8FVb+ZvpNUaGR1b69z5mOdGsyyQABjq6wC6f80De9ciUPft0cuL8IxWfXpQR/buY" ..
	"+kRmmiYzMoUlp+kj2BDLXz/XtFxEq/b9vzHmw4tainoJ92DBWJtkyJsJ8Syn/+6Z5tKw15CmTKGoDI5jY9inrIKzy2W5nuwYfvKQ" ..
	"ocLAZ9iN25trzlhblMM75w0pYhCv2GtW+EMskwaQXi8U4fCsb/yG0Q6oliHZZLP5Lh2WrEjEJCzs8pSpyJ6yRrueoWNYPX3SevAm" ..
	"YcnkR1RU+lhA84G2Vb+f8/IEpu2Vwo27s8qAimBsDWlhoDrlrN7jOgfpGlyx3/hc32tWYw4wd/J3G0MnTeceK+4XLC7vgeELvfx+" ..
	"MNIJdvGQwHJ3zBQxNK9pz+suGdeIQpNNoxE22lFKNNDXd05urIyPm2F0rpSyFcMy6brD+iaTy0QhO0xqc5bz9/PxHIJpwsJ2Ntxl" ..
	"Mls4TByUdnIGk45s7AG607RRXUsUkDxTsMXhnrsHD7l4XwU8V4HBz4ghnD/EosvGNyiFZsEeF+IjHShVV57OldeYxhwJKJksAPxB" ..
	"47ZzVktC22yjs8bc70UXSv+hs0tIh5Bjq0DKEFoI2jcyfSWazj/D0D7xcTXBP4Th/ZlC5eScNJ1l4wMMNoQgwjxHB9L3tORt0Una" ..
	"7F8qM+oHz1k/ak89oI74NLSDP6ENr3Q6UpWfQjVPUgxM6ky/hiWC3jaFy9EwlLtH5rOfNvrjw1DsSFDZMcI0XuUPblDe5qX/5ryu" ..
	"35l1ZeY/xRS5sk8urcOaOQ3DdiSGgfVzZA2GzxmstAqdH4VIbiga++61qGfgFZqetBjij+HB106+bez4uh6HfWnFl5wTYqkkZz24" ..
	"UvewctJ1CwOD60uM1Kt56AiMV/f7XQaBTHJGr4orayupYLj+BgHq+LHrm4qGdgISbG/iOsisfi4QY0w+G9qx+maps0j8dQdNPX8T" ..
	"4uwt2zL5+OPU34nS1Gmo7vLslqSWFIeG6OZm9IXiwmWOo0fxqtgkjbi1oAKL8F9/dxycJOJ7KwZIGkaQVCNS1m25CYVNMf7bVJy7" ..
	"O6olX2PqqEGkyUpBaBx1jXmWh/y4mG5GtWKNGhFPyI0bQ4RwRrY5yNtgJOW0APP3R8wDwBsDsAi6t37kNOx1bVN9TW8OwKrB9VjO" ..
	"d8a+EdPdodskk6WBdHoUBjwggOfJe2QwZZiVwtVXKtXqP32I+XKm6CCuOJTd387jJXfyLRsKZ9dE36GLhrc3UDvOF6+o5fYozz1T" ..
	"+igwaM+/OJ2nSfbiQvumv43aiNrTzvdugMC8p1zZEbUpuSxu3KbLtidmOZ2uMLYQ8BJE/THhTYMpC2t4J2fnrVTq2d8Sh6tYoRUx" ..
	"36w84HiclJZrMDJ3+eZTVHMi8tdMtXQFpkxPCmdzUiDoLnuwnVxx/IYpofUXJM0jBJl/YFre5f7L2oa344LLZAe6+hFjXj3U5UgN" ..
	"Rrl0byOseCdv5ugoP9zV9235pHvXFe+qCtNZOOiiM3ouVnMwOXMOFYg9LPnKbBkOEWLlqrTmV2dykDR3D2DZb/R83NG3/uSW/Gqu" ..
	"knOz4jxbCuc3k0QfbR56JhAA8agDhBZcswU3blr2gMGkA8O+anN/x5uxqgY9kd+ea23EHxuNtP4L79qLgMewmHgE8he1x0wY9+jN" ..
	"HofSSzSwGEhyEs0U9ue987MKoYiFZ8HGnerHzbY76z/7H2gaRagcfIYZESUsrJIMlVO28Cu+GEaCF+pOk/bArY0tZJfw4bIa0kmt" ..
	"BbZ9NrMPiYhuU4VHudAtOUPzgzX3Nxt5kHfuRKbfSsY173zh1sXYiETr/34bTDCSo9w4CmYkyaEIjwlqN3r1AT5jRpqwDzhKSCYm" ..
	""
local PAYLOAD_P6 =
	"7fIHLm1NUkNZ0ZLZvNrT7BudmLT6OLPr0RCvjCpEehgxgSxi8DWiiGD4IFT4mxMfvvGepv2iI1bsxn+K3sRnZ/KX6PSrFapyqSiw" ..
	"RqPm5V0dKjE2N8w7LnjOPozpn+SuCfP+napx7sAicZqa/+S6kuyzZbX4cVKOe/c92O2/mY0gtNvEBHSbNeJj8zFdT9BNzGx1ri0N" ..
	"e7Vdcdvr77i71Y1+2z+ceTWiONJndxifheryGNv1HQB5VwntC3ozjI/7tyctkeqTN+lEPFzI6JfmS6KMZecCbuDPs/Ijyy2xSd5e" ..
	"WAZxjjiz+6p+te8h6HT+3fP4Egt/kWdbkTJAc8OUcUc7tsUBhpqOmgKLnNJD0dWFkMQ+yQAplCh+DMB1CbfZNxOwRe6oANaRwoPH" ..
	"4xWUCiE77c0D2FrOcEPNH+1zYlC40WTMaL727LDj6z9oW295RzwwOynuSJufE5K1faRE2/yHo6hqsZc73GmqWJnh18zTC+OP8AQz" ..
	"S36zYB7cH07MvKagNM6GuRsPwn+g3vzQjoMQcgnChCZPN+qxV09R4gCP1OEaahqwytUIhTtA2NtFoWINLElCk3dq3bfQtSqOrYm3" ..
	"JHvs8y1O4KC2psBvsP8NiE3xtTOkOMWP/OPI5fHrCcF04tsttt1BA1qu7P42ep581UCb3u87iHK9yEiXzso8Qm5vS/1rSQEjcYf/" ..
	"JDKlQ4rBGGq/pKFoQvTR4cRp9e6WitqfGzWl3wMtqP6rJPREwSQcOF52szsfP5jwPHJYEoVELWd6OgGhQl55PgQNHN0AZlzVC88U" ..
	"+c9q0qvEnChTp9xnyDX/O9ITRITprTtFG2gHqYutP++7rQP8RI8MTEMD9/ujIG+J9h6wRm8q/xlsDO9zS7oNdsc1qSu6VP3PjXvc" ..
	"UKuw9etj/9KhB6O4dpTVwjprsB0tTtEcFrR46PsZdX84FmvZo8G1A7cBE4Jba4VgrhibuM7KvQAqxTm1JAT8nKPhFo8k+vGJOn6H" ..
	"ZVryeh6l9LK++ofsfaB6tv70kIxd+4Qz8KAoFuNckDnqcitcASfWG+9xzX5PVVioNOoMhmmONWU5kN0NA7tghSZEVW1MnJOe9qeX" ..
	"hgocM8/jgeRosGXOxLFvqFFlpN3ZFMy/kMmHGU7BN0zf7BoiDcsMMTGGXFh8MGjDiABj2lgTa47FSHiz17xzK2sJrTmQSFaz94pE" ..
	"VkkMEt+jw3U3lIXvJJCEvKayHtIexQe1IuW73vPkg3XMikVr0Pz+83RaWiTSnDnbGae7EdFSWW9tZf9S9kR5qGHZTi7NjMVTtC9v" ..
	"p8klTsQ8Tv13/rI15VlDxGZQ4Uiw5Oah+AqNsClylngef14etIVoJCkBfJsp6V63fXyrdJInZ5kMZDNaE4KjTri9xd1oVKn+TIxB" ..
	"oqL0qb8rw0VNpPOF0gUdbQcYV3kgMFKRV2DjOi1bzlekBZ9D9cht8TNeFllFqZwdVQJgdmPQhpGXXQjqUZgAx6GUQlVX2ShEjXRX" ..
	"n3cuFL4HZZbW+ZD6TdHNWeXXGfBpO+0qqVfOcUr0Jx7shCk/KjpHckN13tUgsDl04Ky6UlKhyBbli1ZZ9adFZAonyprTbZGJkl0h" ..
	"hMsNDhsk+U79PiN1+9kvWGQge9Ciojc2x0IgdV/TijS9fXkrdYj/qzjFNgHBLcbsHo2/Emjw8Sd1hLk0ButGCjDE9z45zzGSIY4F" ..
	"DVexW+anSR/bebY4v0RNCoPxnaAEV0ys8QylVEszn2XjbjaudcIi9A6WuSfA9+hxHHdxpquFV1+A54X8QPqNqASP8URg7M78xWNz" ..
	"ckbqFghW2DF5NygHeD0U/PU4uC6MQzv62MULylvcnsMdRxJpORe8BjCm7rCjiCFAK58XeRO8A9w9XxeNLK427FMwJN8cSLWMXAIS" ..
	"NdjPUI5tsW1bapoWTAR2QQPfK7XjBodMbFBCBy4qhO4a8KWCQuIZljyscni+Rs5p8LEG5lB63ufQwUbgp/ZVLDqpTrSYlqOLYTGN" ..
	"BzaAKOOXJVgp7xFOgh462rJjmp9OiEuW/3JxSr96Rv2H9PIQORyIKi5DkMp8HzQIdNX5xnDLHpbnRh5Csk2TSH3qAZQ2ZyiDk8Lu" ..
	"Jj1kAfaCp8CdL5eKIX6uG7Sht4eOKZ0cBmuQaqbu8+Qlzqg54b65jsm/9i1emejdVZBgjpXetyO+hDKgK4y3IyMwxUYEku+B5mOP" ..
	"iOCIuWn4ZWgQ579v3echFLHf5Ltd7rP36hg6cp5+hz3HVO+63P+GG/BYlCKY5EvTpySJNOmqxBnACKXvlCSkifg/c6mljEY774b6" ..
	"FXqz7M2HT5JzQ3QrsIPAdjTLqmuOoXzZh+KnX9gXluiCZbZC+qzn4U5B2xKeCodJG6KJxiBvBTsSvH4QOdW1J0VAjszoK7k5BJft" ..
	"AVDTLcO+6kvG8jH2Nt06LF9RYdnwFFgvSy58bBdlNV94FvhQnX142faCoTAEwRJOSRlb98fH8P1rqYdm5QtoJHwlpZJgQJW/UUoE" ..
	"dyXT7MI43990IBLwJpacyaoSIeB1qhbG/OX/D+keITSp/XMnuvuRVa+a7LJfk5EbzWgTZoJu9h+/brnc0Vf5TKv5yXbT26L9T0gf" ..
	"E61OPnPdXw39TJWyRmyKxcw2rGq1QB30zYz2TLDxk15gJ9Mp4ABC66k75/4/mkA0qEF1OGL9JoRazgtrGeeqyow7ewo0576VANZp" ..
	"bfAiFCb80Vlg49lS+7hv6ceAgrnSHWH+vr/UTa0JF8mOreqMw8lrcsbQ5NoSpTbPLbSVLcnXfY4O5hh+QerOva47q4GQ+Z7VhzO4" ..
	"ZTbXygagjtPQZGRZstto+Nu6nzafBPBTkq1GwoMpvmyXa3ufnpzxKgY4UFT0MUA2/BUXinysWUZXZZNRqU6NlFvF87nw1m8nL72w" ..
	"OQRYqnMUaG5av2lbtnJ9BMbZUTVQ/pXnDPwdrSdaPtSRgY3VcMif9dPSNUI8TUrvVxagtJm4eV5Mr91spixSAxXSnZEijAWdN4Df" ..
	"GR4AmbjAM7CBsO+onW/XpgquvuoAqULd671dfbzAZ+bLG3s5FYdl8rXLuf8hDwW9lon3AcaDEUWhUOxY9WTuxumDVVommr82Krw/" ..
	"ZZW03G7pVVIH5CUgw9IYfEKvBDp86/nl+tax3EenW5Cz0sdpCCqx9pczuAR42WQI5+YbTlp8zwhkikKSz2la79Lqk1gkVbzfJmQ1" ..
	"vbH+ZpJsk45atdvNxnAIPVMRLECZPrzPbiSe9dB7/rBzB1hnOakMrrFk+w3d/mm/DnCcWc2vmNOfQvvjzdhhM1zT45KAAABD6Qrj" ..
	"DKwlmzWHuATPcyT6pHmb+pcQEPDhweXHqiprw4tLYt0eqm2ugVkRe0vabA2Db95TSD2ALKWKmZAGn29mQQLXN42tTC9hnYHpLSNr" ..
	"cSwnvATVOzztNQDqbw3qJOOI420eEJ2Sx+iT73w3w1X1gn4I72O1ASpD/DgygUXYZEOuOHLzpC0BjGMJ++uuf8d+It+OARfkO7eO" ..
	"5rvsAuHrnb1rQansA78XtNiXPZ4oDNmABfRkf5G1PSLhpa2SwjwAIjEeET+U3OKjhwQhDt0e1FOX1xnibV78ZEqRPOPwzWAJIwCR" ..
	"rl3wWHxz/zd6rN3c2GIaoLXsn2kvnf4gBVVIxSzZuHfKZhQ2BGuaSBdZrsjQb02Fx+8w1lSw20S7t1OMvrlh0Ec7E/0tgZHLaIek" ..
	"S9ajNcROkV1ESbH/Uaxx5F5uEzSwE2PdyZcVOk+TNzDDbBV2338V2F2fs/HXSD5F7ahp8mwD0oXm32hoAlQ2XvtsHc93qHdtk+yn" ..
	"TUrqR5UvZsTs9kNkd6fmE5Yffo2UDBaqtB/M5umk5meacAZ4D9LyvQpzDyMRkcI5WZYqsmI7PsspcIyx1wMrRk+E3XBCShwmo1dW" ..
	"l22/xd+Cp4ZXomNGUYKYF0Dpqsz6edOGfxSnonnlD+mVAbTOVTdrQKkYKq6pC4Pdd3o5JHFz0Ck5WgxCfFepRSRO05w9UyhWf7np" ..
	"Nhi3/K9stqqcdOrbNcZlUq6epptugeF+MlnmURX09lOrv0OVkFtrng9SOvOtcVf6VqtASSL883vYp25ye7hA3u5EhU8v0HYwMTu6" ..
	"xlSNz/xcISw5KBmzkVb7tmb1Ri4pn2zXpOoofVzyvry24bpDZ1OfLQlyzymcc05FoXjzEtwP/5jao2V7kPA2UzV74Uc3gVTr1Owk" ..
	"ML+1o/b3l6XbBOgxc/DlYi1pCHzFY+N+vp4FPQ0BkFdjbPFjc5z9+YvJQ8gYVuslQg6Rm27RIZKf/K6VtBASbeztUK4cJtczMK5U" ..
	"VLmkO538RmphvC7e4uY/uuuYfkwqH+H3bedkgCmaPLNONXnsAMaVqiqnbXhQiz3s3x5HVCkSV5jDaxSSAONgEEHxMlbFDde1yXm6" ..
	"Nkx2x6C6FPlUnMAC3kRPE1OKdZJDsyjXI77sj7tmsH3LNmVqEBktus5WQrBMIWqXGIsjb31wFmmCCASP4N5LdPE094eTimFWOav8" ..
	"ot3FYPyIyLOdhlnZ226p4U5qydxz0bIe3g8yHr1oZoXMmoCFu9ZIhBG8dQ50sKtmsQlB7sPN3bHE95wabMu5tRb4vPUqw1kcYUWZ" ..
	"Mgi0WYiPYge9RC4VWNbJDtVaMIDtfbX2Dq54E6QdIyepaqewLpX+j3gZKH28AZ3NV2Du3Ha1Sb+r2qD3qx3lQN2tIU1I/eCHPg5K" ..
	"xypirg8g3gTgIqpumidIB7fYMBAYYFz76rWdIWvU6oagRDatUilzSUqY7cti98zu1DfogjoKazonUj10IMZKJ3v8ibZk2fh3eS4v" ..
	"TdoytOeXYqiK4x2bQ4XKOOytB5ENMKaWOt2U7CnBE4gwj6yAKxcpiJsS7NGIp4AGEK3TU5jmoO/2XPCMYp5jCbuaAGDiMQjkPxhp" ..
	"C2+P7KcLgDsTSdlcsp90W3IuSPxPp37u7/cVyJyMe5bbKgsaCyDGvz3HOsgt5BKpRdyih1I30A9dd68Is/yomfuP3vPfe4Ou27Pr" ..
	"apmcnnn5ZNtqImNm/T52V155ovlrooBuufZZ/7sezgKKfUATH/ykoXrECHsGBlx/ebH4F2dunCH6Mhdn9M9L7Jq9G+fS5lVcNKcr" ..
	"r/SNRQ5kIroqVP3ZS04zBoEnvEgpfErseqrxnVf6bA1mlDo9dHgj47Go1gTSWOIg+mcoaKrifBCYYFtHmzy4cW/CgtrkW2r+jHAt" ..
	"fLbzLcRE/tMc25sBS6VcKsIWn2Oo77Ayk6FfScNPkhbvRa5UcwrRRYbQd5M7ZRvEjNxP/aD2+8POBKmAWqWDpnZLcLexvzxUh33m" ..
	"tiOT7+yuxfkfBZXlUZBX/7pPFJxqww9oYf8Mh9pPUOjvZYkzPHCyxqvE3Lw+i34EIChcwe6RgHQYUPEZzzKXxlFMyjj5pzALACHP" ..
	"NXuNcVctnVO3LzoBd4hqH4hYrry9CjuTf+nmIaOSFYEQa1SUjumg4mKQUDVWZhDbFcJYm2DgOaar0xPTCPKzUy1rUCNwh8mLn9Yc" ..
	"RVKEB6zAPuZzctxEUV1RDb8xxUPsu/yOwO/dVIqQ0yiGxw0lB4pyWhuivIGDyQV/ISSPTNFdIVwZ7T36yDAeF2IZLiUNUzVTiEAj" ..
	"aMPDNkilJjqHXFRYaD1r9lbSdwVRuSaYnkkzFh6dO/qT3KAs6q5FWjhL1U21bhJPoMOnSOeNZiZRCxunpP/RebxiuYVrZ1AbDu07" ..
	"EILwFRcTc21fiKggZgbS0j3rz9V6AHAPFLaHp6V03n5FyXbrB35X+gJsNovTt+ubewFtgl1ANUOmy2IkCMj2CNpc87eUaCjyFO2r" ..
	"/D+mOX5FkQoD29tu1XdZuI2UfBM9T6MfWVTiAWi+bZenuDcSgBmBUtYGRSDtgl8hE8PEeuPbjmZOWpZamU+IpMQKCEObjQNnNLjM" ..
	"zJTF2OTzVVq7bF4mPk/uU7JmG/zcFgFsSsp0s4oViCRJ5KrQviw4wgznlcyYzeaFe6XMg1rKdoJC55Pa+tjQnwLuSvEIJ5IlSuHX" ..
	""
local PAYLOAD_P7 =
	"EsZ7qLIV6JlaENpVf+CMGrvIAvIwxpyK6coJIOaztWsZV19M1K6Xa1Fg+Izg+2S5bfNgad6ueNGd/Vjp01tnFcJ4x0XeSIICoteq" ..
	"OD+/kySpBK8xmZL7G6deiuBoMxBiwGB7Z+uOOqm25SO5zRXSBEYpjGs4P9x2mOCjqYMFBjIsiIKin9zjtas8LDXK8J3Y7yH75td0" ..
	"ZTAWyP0fkKptKnSJuiOjQkUWE9eRy971Fs2upONF8+vNwA53ewZA3J39IkI2SLsLplhzJa01Xlwu6ab86mLypiAo3RCnay8jA/Nf" ..
	"f1fIm5gqcmhNIFEv55HAuTK4cweB4IYppIzmnIe8NRnKV7mcQTJZeTgk6Y1lebyTBrI06bVyIy6b9EYY0g3Cbipz3lBnekmIVQw4" ..
	"Xo5HXnKVAjjk6VIx9TFn3QPJRImlNiqq6idOYlWcYNzJSfEj1KH4tBLGJYtzBgBfAl1tZNF7VcPbJvUtgJtt8xYKbkuQXKw7UVpS" ..
	"f6FGzJMr/uHgaR3DCLqRLG04gAW5HGfW4Sql35G7FI0RSFPLmGFbGPTCwkqNe7op5fOv61h3HSlIsjeg1phAsrd0bqfWl/BDpPx3" ..
	"cTreVVsE1///IRt7K8VHiQUmj4b72KX4sduOdTIOm1e8LQucDpmsXW+s0vGQVwNx128fmMXqpofKjwU/UVHhxrm9WFPwUixf80rC" ..
	"aimb49RYSMVC4G0RNoGRE5Kxkh8FMWnhkckjD7alEi1lSNB/ZYWmpCUBdUpDL/SxOvwD9+nbQIxe/J8jX6Jh/JL8BysHo9AmEEYN" ..
	"xj1T/sw96DqAgF+Pfupzvd7/Cvxsv6+TGOM4NY0nWvOszQwEzczuaWBCmkMn9vad8Kzlyy83R7YyxXH9Ez6rftIHMNXGmphC+vkS" ..
	"ayjfZv0XiPcH8LdcR1OLWNNtv0NRUyZEbMy0eGnDi6hlGx52Z+enWVW9Eaa0IN4P72Gh7qyRL2buksBeVargtd2MjGn8GdH7Y2a/" ..
	"J4pi7XOPcJ+cUQlqrsyySWsTYv3L9CB9EKuZ+3a+eYNhlxU/BGMoPEj9rJeH0dWbpRttkhwDb8EekZaUTQ6O6gX2TtOJfkD27QnF" ..
	"4yk5pZzF/bUoGKBTY9ThLvpVwOA3tem17wBz1VB/D9VkgJgCvlqRtwweBuv8sOSQTN/ZWYf7yEa5tJCkeJu5WaP4HPur0adZsKz6" ..
	"ZNcufpvPp9FzDPQMZcFBghTkYbvzkDl6s6v1UuMtznwhiw8HsWyr/hXsSQw5/t0WV3vNx/NBbXfMa1z3hOlxxxyMEzWuKCDSXDFC" ..
	"TOcsUkXHBSCWjKEkGzKpxeAFvLwe5Bx53RMjOlo0cypIpAh37GXEi3hXPmbLMyGu5khmgHthBlefVTy9RUwdedbIGSiQc4dI09EE" ..
	"q0dcQ52yv1KyzehzvZlm2HBLkbjiXygIE4Nk9nur5x2L9MBvQxRWyw1iAKGu9LpdcGzt7iDDEh1687jePalnXM7lIq6Tjbh0mxUv" ..
	"+EDBig7eL2WJYgdVGBqDpBaIR0NMVu9L4UdqlpbDeAx4axssKz/fJcasEPwo4s/llDPH7mtvxMGyPxg9BMi0AWy2apZ8eS1d2Ku4" ..
	"sGeeqTXdTTWsVdD0ee2IMXTFnQDPUyZ/mO48+ownPU253dSrjzpDeIPQlltmTYhOkMI4aVOeACRo6op3GGtr/0D8PMBrjM6IZsET" ..
	"ZBgxL6kFSqbIfexTnHieJs5YOmkDXhXmz75tHQj2m5uXl+bKwUMPbq0siI0YTZ6eAkekl0bgvxsovJkmMla0wnAOeVYCmNPRNsKw" ..
	"uNyIigmTJAqctBXsT35MMytfiQWO5ib/ek5Tg1+fWtqDbk8/uCU7aUvEu9YkpLFSA2lr9d/QkUVR2eJ5APrr/EKC3Qy012Dtlx83" ..
	"5EilWRVn+Vl585PqTYi9XfzK2dgKzcWHwWRm2x3jpXIBP1/cGAWaRizCfbhwgBSWGxHaZwK+1Qugtts3gn7OFP6aWpWjPZeYIsjS" ..
	"8fYNN1YH8Rcs/BrYQNymKNd0u8N/oMR5zc3gCuqVhBboWMK7re2JVmfZgd5/oUB/BJ7Ks+mWg4CIoEhLhytjbwl+N3CbtF4gIX+i" ..
	"0TcqRtKul+8LWrBC0WtUlmFuGH4BtforezyfJ7kQj7fSJAOHWvaQ64NKlcr2NcoCXvezGY8yXPjnPwj3DwpDDHrC5n6BBfdagamN" ..
	"u2fD3Gmjwo6mrOQTjn4lohtqmKiS2hUHTJ9cMrznC2Bj+SlDMwKU/3BL4kPpyIwmdFk+Pq8/p3lDe40e3eIuP8lFgG/7giqI8XsU" ..
	"nnBJZvyl+l9sboT+nflDndEr/foz2StN90ybPYuG9/YfRCVVEuNsALJtqmxSsNOAwznWvulqqFT95R+QnclDku7HkPnJGiLteJJE" ..
	"Uv/k2nWSHRv3J9erk7/ThFKdYxUgLpYZFPZBrQSEoxy1cEd+slSfzAg8hRf20rT8b0effT3Kkphn5C4hc2yGDWW+FlmtKsMRaROZ" ..
	"pFBBbhz9OOtGXFoYhug3FveWaecm/hV2HVYtm0PO1iwvZnwWK0XEbkY9nWV99gpZnqvAeXtqyFJEBYHZdua4ZkYHYGlXeqGLetqm" ..
	"nn3RKOkkoys8V+Bv+sVqy8bkndxb5mZSnp1vsgnAZXXtaZiPG7bkgLSr3MNL4lqlOxQapPtmSFZF+IauMlObVNcgTiX/W1uYxF0z" ..
	"HwHnZwGs0FDcDoLLWNh8JxedcdvAbKomBx7sE5Bt6zNlAXMp6HGdOn5biigsWqJmgZ4Q1u6JWqnYavw1cmMzNpYR0GTCXmcpI/t3" ..
	"XW4eikbMZ+JSH7Oa/qwAzdTDW20aeePg288WW97pNG0kELiuv/G912/fbdcHMFjp9eq41z5lctD4WOrm5t6DWH0EazYkp4a7catm" ..
	"ayZu//1AVhn1b2zwP7aJzt1bXxmJGyFFWlgR2poCH+LFDi9pn9QhXmbwvbquZsHJMRIt5mY3hb12p9T0StHifk5t0o6Fd4FdSY1h" ..
	"8G8/4qwbzxWX/2ePbwO197Bw7Mt0gylle7MRK7wPs6cwXCvR+4AuHbvT5pjYHawYebBSx0OrJyCeHYtBumIT6c8XFota9pVV/uIN" ..
	"lQyZGHovF9yIybXbMEVYlmFmfDRYENgj6v51ulAeClPj/qSObyj9jv2wrNIhvmpiK+3KViFg5fLcqt3vP1vuXx04v10vqOoIuKu5" ..
	"UN0GYP8vYN7/fGES98/VL6nnBnek3SKPTISiFlbEKQgQ+l4M/NoR91BM05GKaMpHzJQsy8glqieOZ0NDSklIWEXvY+jR3etz1vU9" ..
	"okeWBjEr1WcdMvR+jGHnqFF6UJFBOlOixpqshUDiPHzPs/D+uHgKbH0MfBIJtaoSmHY34WqysJr6O+haakIJQw+kDvycVmG+uvyA" ..
	"7700BoDrRQzVcyQc2TO2oFVMzNP5n3WWzpgovP34eU9aDJX2FGXMDio0pDKYW70IYUy8x41VfEBY9ffsHo4Vo//LWod0q0XXtSnJ" ..
	"7ikiTj5en8KrObKrrbevp6iooFMbLTXUe7orp9Js5hnvIIzasY0V6ruhlJeX8/EyvdnDgVQfhvXtSgp2TQhdWVFJ4HW4qOoeUplX" ..
	"dyzgGelFbD4g122d182dvCpGgdKLRE1gVVMw9oZONBoUO5EeJ03USVLm552cpzJQyXPxYmlDeuHoeuS6e8E17pjiTg/RwHr6girP" ..
	"o0l+gSE7q0VUKS2ElWj+Ik3BEdqc4StlQ0lHFGj9p3w05Byy6j0tRIYiIPsIJk4s+2L99viRn+m6PKDOsA7izDEAau8fDi2H/0Tt" ..
	"FMQ5H4wwu2K2fZNMnB3+n6DbLIISRFcn0OQFzEQXhAjo890ZoULmDsH330Xc+J6O2T2ObVllAq4D/E8vzpxib3PqW2rVqWX+pPFD" ..
	"+yfsrxe7sYKVsB65EYFr/DXyPdi8Kce/OzpfmtEqMWqu432Gnbmj1UAnZjrCzMDZoP9vLYzSAPpgSYxgCjYoEU6vaaoUjBxss4M4" ..
	"F417/+ghmixRv2PStU7EIqnhjbKnaXF85G681R2OBqFDv6ZI5aqx9gMMyh7c84wDNC7Yy43jxhsnmESs6LtguQUNto10RwTKRXW8" ..
	"uh7tulGWpSbn4fxCwTkwRvpwIOz+oitJ5/rvVZpr1Uor9AInhSCgWSiU5vr1XfjJiq8bEhca+cce72c+0fBXk5OshtOvtvhy7/wx" ..
	"xPIM35TFjwZLlbF6opHlR+siw+yUY9FIP4u1+JTgopC54XFE0PNy9NvPpDf+yu6ra9e9Z6ip8KzpXxG7qnwaDncTHIp6SvzirtMD" ..
	"qVRlmn5kdxMGA6JumaMfmruCScRrEjYm5e+uOBVC/l0+XuoL2Ximi8AUel3SZsz6koVl3JSipN2BY7Sf3R9AOLWhn6oUqrVQK2vu" ..
	"1wKWScBETb1FEsHhTTIBDsTp/7DKuQQVdvfQNqx0bkNhvYVcK/s3MmOevHc/MyOD+G/PL4KQWqKl8rHLcJXLB/r9xwcNWFBal9nV" ..
	"JAiLKHOuNdYfMwyFK06Znh4W62AB9oUhub2NH6fSUAldkCd2k+P8lBsoA/jq1nY8rn3f99NRPefch37r0WKLCAx93PO21cjPASS8" ..
	"/BUz1ZzoAiVfZOlumXJfQB8HcLDSXIacnlAAest7wwHhYzRcIwAejOt/8h2EyijIZxWwJq114r8Ti9F0N516U1QTEek9/lzsMdeS" ..
	"VXBuT/9xPC35ujGvmpmuTreD4KTGIA59FXv4UBE1Ouk5eWDme9/c2lKBz9AS4iLkeGXqTMTuZJJ6pBhUptEbmCkqaSIItSzJEXG7" ..
	"KBLXhqGrvokGFfCbRsVEouQ0HFOF1pV5r2aavRyX4KwQ8By1GzT6A0h0rnqRLOrlVC2yUMVRlkEdRMQR1/NFMcUPD7SnL4j3tbj+" ..
	"pJyMJ6z2hmaGJ48rVtBDneH9aUHZnxtjT29y5D6PMbkZWFufQCjBHlvHxE4mwX9MzXedmORSg1QhtpzzufAtFIRnLs9rv8vWaDC8" ..
	"NLwjwYbEm8QYx4jFZWapExnvxTMrOwyx0biabA0nOYTQbIpQIN2odJrgeXZv5KqKGknO12jzemoGW/ZX/xNGj3cTZN4PXnpyD3RS" ..
	"bndeDQbkEHcaraM7ZJDq4cChUxe3bW/7mT9BR1vz7usfUe5iMyZk0S5weoFDwpR4osoFgvbDqMq/79MAPig+7JuJB7d9uRJvNw3X" ..
	"wfvdpLDK0pPafN+CLJgrwSk0ZArhByERfqbXncuznDZMcu3N7nZM843f+S11B06HQ50JGy8LTUo88cf3myy1EdPu3IadDwigRHfX" ..
	"NLF806UBGwUKNEANmO96eL3zTovi/XZoXkjVqE9GV3gXu9XaINbe6Kw41Iv05RUepRwP1HzQ5hX/jAl+MpaSiM6/x8vIKsHaUuwh" ..
	"SNJNYZntPt3sc7nk7P+PozKH+js64gsoLCNLLHE7e2WQYkJI7vHJ4dUP4/ksS1ZNVZd+5GtEV18/EYYPHfYda1Pocc7PSgImdF7x" ..
	"PptZmXj0CeLBw+44goDOCD+ZG6WU/8yJu0orTccqnkwa5pGY5qfgVhiu5T16w6Tsgoow70zgQs/ZD6RWlEbzFpJqIw2JPhoNiPB1" ..
	"gVSsMDvllOpSvOLb28mEBQT4LGIvCb8sSzoey9USrgPomGAG0hCE4ohGCpG/v3kJMl0/XYozG+6J5Nf3yIezu/qvZkXdXjGInary" ..
	"vjyq9DWtpwo8F7BHvyhh5Cfw71EFitxmfuVUrAa3/UULyE4jhN8gCbrgw3uMakoHCuPH806RHlDnHY0U5FNluJ6hPFEsRHRDJc2n" ..
	"2J+6FAZsdH+iaN7Lms/KcrxzDbKlcN3PbAh9fD4YwIdGFHJb0T/z22VroVOswxFf0yHQfZ70tjUylVT96xTL/VOGZer9rVVcIRnk" ..
	"wIa9yfOVNmablnGDLHnWUMRWIJPsb6KhVwX3kP8x3sTe8QD1LSsMsskkKvDCkfxgB8yPj9ahdTIxP+cn0yfeaDFwJcTmPd9MThrg" ..
	""
local PAYLOAD_P8 =
	"Z1OCklnh8H0DaHvWI1Ptbe1o/I4inIK92u2bxPMpoxDLie5voPLDEYeI9Ry2CUzmMalt53IUilqywgWgDzZHBQDP55hdyWw8izqU" ..
	"I5iQ/vswF/cuDF4QF/GTZI4y+xjlhntRe9JkoT3u10xndys7i+RaU1t/jzHZvLVE50N4l5mWsn0D3v/XnXVXBQoUnAqh5UYrYZBD" ..
	"RmcTZKw2Gr0k4Fn/IsQSxzc8LryxKgClwVyRSeUKV4gkFjITmD/zt9cqlEOUegWsQvIePow/DQk+F0R5OwRKf3m7YTqiMpCpVa9h" ..
	"keyrP6pK/h1nQEtKH81//GIYlzwFR+QUCNbvrgaxw0pedBwY+7rtlpMdLE/EeOx/0jgcJz4KmIwHoxXiwPeFR1L/NrQ5pY1vBJVB" ..
	"Jaj9dSuOGIzFl9B0cEfFEw1aGlhOUXhUPt00lG7TDfwQywLIBbwTjMf7lIpft6fnhMD11hMz0QhwO7VMbijk6DlsR/r2MGGLt72V" ..
	"/GSB0XpYnEIzocx4LFnG3ef2OPVN6jm9x7as1pLI7qcDmWt/Dgs6vhyGb5SAdQch41wawmCNta6k2wyM5Qv90vsjYmNaOTh77Tp8" ..
	"UEGjTWT9yYvDaLUMv+Y/vaoxv4aFCZnGhiQApLthuEMfty+8Lfp7dP9dJZuk/aLLg0Rb8mOHCjVd1QrBtc3rZZy04cuPAzrsDEbJ" ..
	"1Q5/3paMl4jNXY7KUNQ26+8rd2vX68KvYtViq8rRuV/84cfM3C3IdKp4/OgvSmCXDyhViQhzE/mD48qT+68QVRRQi6lyIZT6352a" ..
	"7MlZweKtvry2F8xHPe8mYcMlZ/0oHOGA9s9FTf5wIEvAYLMdMGJG/Ku5OMrfPEOfWMPPEhPsbCucPzC5qYLLpjsJtRaOGeaE1j5Z" ..
	"EbiqVMBsgC1Mx+WnISoOVZfForzK+JQ41xV9RzcXh9TgVi6Fl8xHGTAkMVvY2ghCtkI7z7Y4DJMJgn9uhr0EWczFcVu7+hsFN7ig" ..
	"wkTxZnzRQVgWINF1qOQQVS4fstvqizd8Qnk/iARKoxyk93MVgNhA3uDTPuyCTpmJZ8GLMbenYWQWmqOn9z3LPlpCvWI2QbtfmOo1" ..
	"qR5dB1ONRfH7Dy5kbEpnD6FkAmYEUpbaHyAqchtIrM7OkAZ1LJ6y8aVIiYd6223HEOrKt2TayoftXbBlWrPBoskc9WUh8isede9q" ..
	"q6PRu+6xs0fA6e67niVrajNAzeE4fnGynPeZ206W8CXmFaZp7472HBAd7H6yuXcw8d3CLZDDnacTqRwrPnXjZw5NpbUq40TbZJEJ" ..
	"TyB/dXuCrF9kXIVlr8eBYTsDkxeByNnIRWZCDtJBIuWMlWcOWLDiNjjA7VE+M8Xrca2/bmhzFgJz6y7VM/Sx3PtdsKvv6iFst18F" ..
	"NBmOePO8yWfrgsE1cwu+uu5sxttQO/ySZJGPXCZegnc5BiY0vsWZGE0UuZb8gxuMPJNVn9MmpWZ8p45Du1bm+sexxkYoTWFeBdr1" ..
	"yhmIblnkWampBBWdbZzZhA6s9X4qmR/EZWqzWNKuugWYm0+Tya4r6Oe6y4peN895+uLTTZUtYCpbzMoQuYgv1iIdx6k+daCCqZ9p" ..
	"NlzH8fWwM1swmcb+KBP7oKR5Ty8Kbi4P9jOijHxTMqL7u7ue4KgGKqTsy3ae01CZlJqshXMnCAMCbSjgy39yC0tskKbterswKNf2" ..
	"GM602m5Fh7WZPjxDfJ+yqcgvdSexdIDDV/rWUe2V/U4uM2s5EwZb7QJFjHnmJtuFTxOey1jGZhUtzTAVas9r6ZNOduDS+mqo7Jfl" ..
	"BFq80RKizy1/LZW9ImX2cWwkin1musX7hlxwGyl0ihN5WCAgkFZHYS4TJN6LPLkL0us5WhiV6vQjZfgTne0iwJ7DVf3xf/VBGCHs" ..
	"qlMOYFS8pBuIfsCpHdkOV3pbr/hYPI3eodKVs/lWNEEfmujQzMdJ+zrjJ8XFkdN/xdur0hlIHUBMXSxPn7MDCtNpKiTr1rQNKQgm" ..
	"uTcoefqhx8zCYOiXoDTVt+EP7EdH5qMIGruR5XxpJoSJcgowPFx+FWeYJLYh6WTK86Qg/EWCJcpZKRlpQULjiq3u3C2LcdmmQkXW" ..
	"870p+RNs47R57awxdyUoQE5tRe8nQX74Q7UG3mjMGyEPsR9VVyXb/HUa2ulz8J10QT8vFhD8dbbbqfZiuGOYMh0QZgYhbqLwq9pQ" ..
	"FQEXvXnc9uuhqy43380cSGiOjMt7aay5WSiyBtKtghXG6JpMozgB5YROCgeE0GSwQ0qkd3EVoBFCrui8Q3N1o8cETp32msGwFvTl" ..
	"I/XmxPJEVYujRxnZHID3A5Ap51/oGBO7JsD4Ilm9yeyX7M7OAU8drWaxo26pJJ9LwUzkRv6negxi6Cw6SwunjRTLXOuNKGBPZeS+" ..
	"Nnu/IPoXIbKtwXkV/oJ1wb4iKux7uHap3UMYEqJz9rovkMsSppuMnV5JNlyNanLIA5YOK9hzxNky9LZuub0R4VYSirPX7VA4BdVm" ..
	"JomtT8ri8U0B4n+ZDBuJQqsg1ywYbUViaB/QdL/pitYTC31/j8HlicS+4H36XLiKT3eNei0vZfcbnKMMiqeyxUGvYmrXK2g5Ws3f" ..
	"OF7/q49jK1Mfdt27fSG9KW3C0Hf754aTWNmmj2OIMAzVnbg4d9s7wx7hI0FeS5gnVAPXU7dCPLcQ0JqB9faqkvSj63w7a7FkuMO2" ..
	"zRpvbfS2XYUzB9x/yLg81+OXkMnAzPjd+urfSbyXk/mHajkYS6diEzxva/Ra6zfVbiEy271l1MYe1Xdknd9E2wJGgaylsAEx3CC/" ..
	"SCxZl4rVcdjHfl749f8AS+a8INafPTNkmc5hCfEMh1yzXxrS9GVSIim7WcLX3T7S1XZcZ9twUlkYbpZ+/al6rQr0oid45XoHvtUZ" ..
	"QufOVQGLCnPEim2egjvX2ufppymEqPCrnc2KYK81R7/l0s/wZaFC9ALByRKKIuzdIACXKcaDtwE41NNdQ/sRxalaPt3SPSrKoIEV" ..
	"OrXIenn8ysUqjQZayAc90q33G7/18EC2xHHQuDkXpoqvrtwV4IblYn+6H00WktEW0KdlR3o3uamHDUSVprk1pN9BYkfJ+inUfTt3" ..
	"mWsRLXOfCMRhLuQSwYchim/oAh5jKr2mb8u+CXbgy+H8cOdZsrLk+Wyj1PseDK57odTiCfINQ0xuqr+cuJkl5pro4UM1Ed8s90S7" ..
	"/cUQB06tTt5xB3Pcn7LBpMT4eKMLvp0UpcDtfeG/0clr2T+o6iDaZsTEJwfcTn0EweFvktkyMqXcdmCKgjMY0l93jAIPKDEIVSRl" ..
	"ZtLZjAPPbiD2L9ARJXp1TrOd2xb4kNkxoqWaDerRnWY9oiceq8KsP78RbLtSPzWxHnMp19OZwDYaqrIF+/Pn6/CjQ/tZ5uZsswa/" ..
	"2aCV8ofRBvmFgzbOL849mMFVuYzGgGhxDHZKkDBY+keHF6fI7RFVw1GnfEKoTw2Z/VlKfJipjo82hpEE+yAkILYiMZr1sI609Omr" ..
	"nBqjjYIT8H34ZVaXClWMlUFZaWRYndiIMETyIKgU29fi/j8tZtGBFUK47ktOUEXbsAUyKzrWLhy/c1vq/cPEqrngXcnzGr7+sr0M" ..
	"s5c9CdkcxVdVHq/pnF+H7CQa8RCIXroxl7qI89yU3eEPRYH7dIAhYappMQrnC9sqruG90Zxlj2OeLZhlUPcLwJbditxA7g0NJCrQ" ..
	"fN1vYTeIzHNabhR0gSkoFj/9mJg3Tc11FXINSX1lH7pCaKY99M1OpCqSRVWbFC4E5KV5tHClVtWDPnQ3CL5yswEHRlqoLUVAkWXe" ..
	"jmZtzEqiRG2rLCfg5JybhHVcKqKBWFdCg4Q7a6d/I5m9/VFXLserfCHkoxoYWkYXT0ChUkL77//a/BP10Vf4o7zY63CLijAQQRNT" ..
	"p/9EabQ6MeXXFqHjLO4F3nNmHIoaoHOjUHwMZbwc80DFFPBzDDfMkwlTN6o9Vd/ZUa2FRwrlUqRzHy5dbUL3rbUEt3e1yTVgnDF6" ..
	"mdVi23i36kRQ0TGVCJ1T4XwTvrDIYsyv8PC0ZT1MX/DsEsbr7e7ishUbCglsBg4LjuRXrJM6ryGdAtAyAhW9INDVOtIOHWPr/KBO" ..
	"ml+8dObXNMJYNYku7Fhyf8uRJIQQ//cKjkq8OfECiuINkqNfJhWK0TFGTs1sUtxk8JZh5zMiVwnKQcIHpBSUtEBZzgBfoRMmwA8t" ..
	"L+ezJ471pVPVNAw06EyB4AqQJ9nZ4KRSl2SIvsxJ5hGTC80I5N8TZ+sOwwYPia7y4UHBQ5kKNh5w+ASxHTgcheOnRAbwVG19Tr6r" ..
	"EZ6t+Ufd9t2JRT0eB5Vd3Z6AzbfnV4LC0Fd6DxtCJJkS/Z0lUl66uCBsPu4WCG/wZMaE+GLKWJoiu7qDKuUwI33idAEp8bhytB9l" ..
	"ipo8l9mgPaV3VjGt4PEwzGGFXph0/wZdOX5zjYLSEZ42KxwPZPlX9FAJt/bInoe8aK3HLYEibcPUh/KqiFscxZeGdzZS0ShsDV2S" ..
	"Ph6ETZ+jPcC2DLmUDwMpjX1xZygfbGOIj5hLML/TMgQK8dYCo/9Mfaw9QX4y4G+2x6avzEZlINhWZ4OTuaDZwkiQW5LUcx6ktGqn" ..
	"cZ2hbzMWb21Vx/Jo2GIsjHfh3YcnNdgp5penkeb3zFiKPjsGGqMLNNqPNKCqTZiQMT28s9V7BP2F7UWRxRb1YMQnyx/wY4kMy8KK" ..
	"Wb5NdxlxxQ1EznYtev5guCfMkmVVBseL3UAR/Iv70QuSZ2VtYj0T74dgTpTqocxX0rykwOAL+BRVXUaQYZ0gPCgRmIMzx9KCBJB0" ..
	"bEv7tPzFpzi1B+84Km0mqdpFMU8qutaFDK0ScWWkkl+OEfbT5C6fxUX5c/tjYCuHwbwGyCJd0CdfgFucVma8vThlx5ZxPQHrIy9j" ..
	"oOFswET/Xs1Utmo3DQ2dcH8qTqDLzWZrH2xYgdghdi9Y08UzYzPeP/K5s3fAjezfFAf/It1Ef8wfcFcELb1OkHm9afA41dyMEMn/" ..
	"hP+oyGMVm2cOk/s1OCuAchdkr1RXbocbU1qxp3IwGZ+TfwFT4pDY52VghISIVOw4FzGdFGq4k3fMEevNWbgfBZH3mcdvbSpLjukr" ..
	"fw/ye588DQztC9zHBED2i+W7pcrDnPP4JfUnubyCxbrDfiVaZs9vJ6PI59H+i9G1NqoPkbsiHcZRHlnBQyh/O/t0AaMMGe4n/E/F" ..
	"RfhJrobWy2yje+ZAeowHMjjm3sL0mo+97H6J8TDQr3IZnrJQhIC+DuS2C/DV74TvUvyH8jOfXmI0ezQgNc7JwzeKVIaoIm/qRl/1" ..
	"cYCAuYQDI5U2qw/sMLMO1MPj49q5wACgP+8muAx8t8YQw9EOwJWL9k09iBJdULYXANxtl7RItE0ocf0LgKsoCODjol3f6OPH5vQl" ..
	"PD3RVZ2bPbXPvJVUUB8hpGp8f38XJucp1ouw4WeIvRZOrCEtlUjb2NfVhdHW4TPiKmI2ySx5Wgqd4qpth07OQqt4QxdhKM1luWmQ" ..
	"DztHkjtY05mcBMPyvNy2cNQy21mViAyAjrRDNnxau/dOMGueCETMzc/b0q7jUc8iOEgCwIp032InXNP+3e3BPRMchkXybcJ/bXiH" ..
	"uJRLj0DwD4YELmyFlWk/jDaMou39N163sjYOD2uYOC0RQkeJFl52IIf9dm1qB/mSfqOOEYyGRr/f74yp1CSo8rVX/hmjKTQ0auxd" ..
	"AMMX44Lq/aIPL6F4aj61cbdtT/KDmlpAknZYoll42/CU2lFMgKPOoTKVjGtFWLF1W8gxFtk1Jtm6LqxMFagT1TFp7KVlQtqXhtRe" ..
	"gsVJ6BWc1AYw1N/MkUG88FLmJgx0F433PWTt3/Vsb7E2RBx1nkgGPeU8FIdadFQ84coT3XveXeTvj/XXPYR37aCYjwkxX1h+v/jT" ..
	"g/tjZkjXcACH3tq2aQCQCBBBdd6M7vMmu7TdcUaUSxN0RjejfsyWp0RnhsGnDhtWETCzx/DawEYe4UYZ6BAqF4+V5XgjAdzP+3QZ" ..
	""
local PAYLOAD_P9 =
	"69PcUu5xo8xKzGb+xdj6msCLDkbAFKOmzge7wanyQaX6RAxtg4q73rV7J3s0utu+d9d6yTt0hwRcSNxqGNsnj3RObGNVpaoma7OY" ..
	"J98U6RrWn3HQ7KD8b1UXT/O9YBbajik0Oiia+qyozDTJx0CLTUPmjDE8FU/Oh1xWOZVBUlVgDQo4j9svmO3vJf9CgeYLBHz/okoQ" ..
	"wpDalv12hLj+HytO3sYwywL5eR1uOiYcU4ZDteBEFok/i9zKjojmyOSHfkEQStj4qu+djO6t+AooM92R1K/W+s+DQdPDWBf2NDqG" ..
	"OO9wFQqaKbHp/6hPbvFtGH+lj4Ha7gR+fw7hHuQC1kh4/ZqIlQuwk2GTQubUJb1lnGZRwtr13EOB33AfmCkXGGmi95Mdgkr2asra" ..
	"SvWCdf/8jvOfeMwLFZhAooh0BV90X0Ce5zZpDpGPNLdAqigrn80cw3neBpmJFtXG+l6UpD+J23F8vKaSD9bFJnFdo5dn6gCBUNgF" ..
	"+rC5UXDfDpLouDTv4G1bWoSIffQgLw38pqcaGihCH7hecY3+ZmojBy/o0TILpwfmwIsCwYyE4FzwaST+L8cBhXPIe6Nidu46hPI4" ..
	"gbyIOnEmjM0E+P2y9kjMTjYY2wzc+IqaVKGuCyqyn/8R648muXTeDrGQmuLeMGfx8T55WvLetyLuzT+M4mj6VYnz21gosFO+4G/M" ..
	"CBXZrb6pwGyk1U8UCgTVjLHMRskwQbVCf1lRwLKx+/hRfjV5n2qPHNAO0to6YhQf6HGW0+9RlPULIFBXD/KOaCdK1VVWvLNPbiqy" ..
	"LrFSE/n8MKpQrPb9XnH9JljbFIpb2tvH3N9scujfGorddGozIRtNRoHN58BZpkY3yQVoUIsUnJXHeOF/n8Bg4qs3Eb/FYFZ4SA8L" ..
	"21D7ut2xanlJRBGfVt5FgdZMICIQz+/vkGDaI0NXSJaDIX7oEijsbPJQ52ocZzz8bT5oaBTzdeG0+ewODfnCcB+dznv2AMw0rjr1" ..
	"V9bPaEL/gFlMvkOzAKB7anLe7Byci4EKupPkeoeDkT0rhgnZUdlr2Frl9mYwo6BpQiF0g9QeCWfgnM7P38J+4TC4DgLKsO+kFjMr" ..
	"YY0HWQmrmqFKRwzuDJcRB5ZrLH2Tvr7jvWjrfJHwiXDwNQu71tgFFKx/0Jre/AynYGz0X1l88mYfgiTtDlNVD/I3xhpoWUU0Xd+t" ..
	"izK+eKnJcPw4T9YcZ2LykSZYTzqa9oEsmt/GcdFvUn/1NA8WfeNb/fB+YLaWj2F79Mc+4vf8Bp/VNEivJDApyv7FBRrFVBBDIJ6l" ..
	"12ls6aJS86bBE/Wq9tslsJKIt4rNT58zsy7CXUE0ZEvXH6W8ky0yORU3aqQuiQISkEXh7G0viWzQnJPyQHGkWvZGoHW7aS7RAasy" ..
	"wbe7cepYS2agNYXqJbZptAsI0ok8uProl0/50WPvNFzoqoqF0BpifDqTglvcpQHf5m74SedEaV1Fef7zhy51YaJ1tqZXFOy9/E0A" ..
	"A8TRhQ7jxhC/lP36Klthk75nJXidwRwuCjXYOfJsZzSjeFR/IkbTf+xZrcT5JLOJqalLozcXQR9sz5Tvp9ilsGFPn0LsxUy1bUXB" ..
	"N01S7ISoXQiSoZEImvETzFzxTmkl7L5hRGH6QWFSzbVvTQxrqIsaXHN11wbWRu57jpxlA3IQvN/KZI7KhzqYoQavBNaULJVPznKC" ..
	"62tEVZWQvHu5QfCi3E0IwmYfWkLpkO0MvCvg/k//5EnmgfCV/RJR47FBsiJjU2FfN+jL2NYSsXHNVBNQ1xxqpMeMYkhuYDELC++i" ..
	"rFs9+cDTjAakJQFFeKEi4QP8zjbmBZlcqI6HvEuNO4AIA0FAKEHTU6lZrkPOPtnYlxMi0L4SC6hyUOIvWgd5btj0tJ+24l8BMevv" ..
	"hnA6gwI9zoymP0GIakgvG4Yq1BjsNIn8qauW8TudUpJ3zBN5qvLTr+8eOTgbKMVQ9jAGxf7gVctJlZG65V4hqoUZQIXVgrHU0Xon" ..
	"Hc+IyzhbUshho69mBXCPm8NHwszhPm/8n5GcmGVm6fU0Ao9wavT9Uq0qJofqt4Z1GTPeagYDcUx0MzMoxIN4ToDzlDo410kPELdC" ..
	"Qvi0fgGjljNWT4rxtk+CN9dUWDhGDw0KLNFt1jfxh6s7vYHDb0g9hXSk6ZZMmkWjgt9mPfAO1gzl4deqizEj6Hb1XgGYQVu9Y3mM" ..
	"kyQNZhlBCqv4pWu8GqXGYCagJE1urpZjevcC8P2dtPT3sMF8e3Sm6AKRUh7dk75/fM+FMvQn3MG1or9rxTFucb67z1Je1PqQ1jfJ" ..
	"TN0m/FeEu+UukF5AvSff65HgXNaFXipbgEwgkGsuaIKPclRyQ8JscqolrCVBPy+LuAw5n+SfBDE6jNIee2zeMOpC/mZv+fhApJCF" ..
	"3DV+vqj+3LQ1u1PE4MZ0ucpn1p+kXlU3xMMw94pdj7nnImZEWSzRh/uYNt8ThAEUfK8iL+1/WsryV+OjOcds9s4AgPyayhDDIBZU" ..
	"iojftwyTvqwCkXDFTuifxxvaIu8jiaEO/VIvnz5NsoZTCUM8giyIc3rs70NaUz73NUV9p2vTkOGqOGaqIAsiXsrgfvCsfl4evoxl" ..
	"4zyKcLgkWVQTugWpjtqw9X22r9/lQSfgbiHBZijDZgxNcXUMinLuTt4mIPV1Xh2X2Ja4MIDoko0jQT+QUe6x/14zTmiSfnBxdxii" ..
	"EDwOE4SwO42kDfs16hsVnvOlNCkzKUdc9leum/5RWvhtTcnsiL3Td82mKANjPQ+4PB1cAdYuIUrEjfM9OpAaIwJr91KBshvyIv/A" ..
	"TQu596gMYX+AnCzhdtA6klNJksqX3m9aUTOrR9wOIixUrnyuxjZGa/jkBxJ8ZA7nxrtI0cWUMHcn0PqqCUSJ8ygrAtVdMAKp9eMm" ..
	"E9xRiESIEuZ7eY1Aglx/Jrh1mtb+Qm8JA7IIKBXVF+ehqKAXDjq26C4UJMUA9mYZzUiHKMlXlBbMK/ydR8RQoxZBw1lov63kO4fn" ..
	"lLa8Sseo1WxnAobHkjqJKZIawRCzzjSWCWt1P112uVJy/eo9xlM5EDKG5YEZ28tURdR6EKxcB5lLI2DHTL8VsadsTV8qGSJZ0VrE" ..
	"2Iis0vvVGEZa4U1Lfh0fKenRP6fC6WcKJ+9Zkkf2A1f9pOnFTuwlZV/kDEeDkFm0WdZIwVNjcJt+/QrE1wxktc5+Z8E+EdmqVbyz" ..
	"CrLBhLmrBeNul7iYBjhExvsJTq+bDmSNlTqLHKhKJbr0+vQql5iiQxSGLoUSRe/pOwPFUkS3o/TTgpfAKoYIA5JspEY20WPItEk2" ..
	"PX8hC1AjEvp4QJuH436fsHL8CGPQe3yUsOd9FVViwplumNt0D8ExhzuaIfeR1ndcPnFtIYA2uoWqeJUD7kZFmIn6+LV9zCCj+EOC" ..
	"UbgKrzYp6raVa60ARZZ9JWqOMf3txV68PbkPt3vCp0GuRZ4HeSqRyiZYt66M6fg7oyu81pY0W2qVvKD3gyRGNYGmY7dLLUJSZYEG" ..
	"K79PgV/6RNzV/absCmhKa8SF/ARIyK0kolxE2EDuacvFDkp95BLEUsgMVr70oHZcOaxfDTcnlcqn1tP/xqzRTSPx88A44e1jh/z6" ..
	"6tdAsJTMaei5KbHVm6gtfm3Ay6qFyB+F4GLuG/VCjrmy6lpTcc35JYlH0s9xm40FwUNZKwcOcFqyiOnrJGdYuSx55o7aVOQZLF4j" ..
	"IOYCw3v9H37wqAbQ5nq4rdQuQz1Ubht+T5xO7Wg07TqTwhhH6gSooctK16Z98ChCT17fPwr8dfxsv4aexprh02QdjxQvt2m5x4/k" ..
	"obiZRiibhZKnc/s0EY9yUiwCNKzCkvbuvLajVFk6dlUVnGUPts7jqIwy2fdYyak396vSTly+dNc9+LSdDPsnL2H71KXmIibPCY/o" ..
	"4j4eIRNNHT6dXvzx05KKQ5fb87+mmzkgbC1/ntN/tNPOVeHN4w5qmMlYz/XHFKgAMQZ2aesT9NOCbF6d0El8T4RXOkCxJKWxFwg+" ..
	"Hs4BnJwoQS9auXAsCCXTLrmDehUIvNGvTCeBA34wsN1HKL4kM3nBHcxmhV5iN12C4ADJiGnyGSPDS9CMUH+X78Eq5Jyiw0njsEXu" ..
	"cqxke2SexmwOIGYAgZsesIWwRTjxVoizrx943QYWqHQTuK4tO5LDn3adHp4lWmrCROdZ0g/E6bCAjbg9wFLRqnUN1AImJYrCDMBz" ..
	"nDxnVtnWdMI6y7tJKwvtIe/D9/hLeHPdYp+SB3cdihYChVVNDSa9I47R9C0U5/JmIFrI7lvY3pJlprmG1pgulR8QjvJ2ClWj6Ouc" ..
	"pnOz1Viw/CEH99oSGuK+0zgrRXzKwNukHYJ/vpjoyf/03ZkPTjzOKoCNxajqhuysc/gIA3ml2rQIpAsQZrbRspDfmUZEgklcyMLZ" ..
	"xt2KteCgELS3wZKs667GM0hzg/6Yd4CtfZf8sV5DgUUmuvGnXo40UbF5v6kxo18q0qTmO0jFuM2qD4K39eulHI5sE/2hUOZ9WVD8" ..
	"0/Ees5TT6qKiKM7K4lgxyPHrFhiIJLOj5btG8ir9Yk7Tx+z9LON/Cq/zPlLcgqzhvTVqquN1S/eDKF9ofUyUuXTmYl8vBZnclsGh" ..
	"rAGa9B1p2WHmvwVVIc3P8aOcMJ39MJCQFK7hD5vEQmIGxh14l81jQ44qhHfzmhIWCuDcnLfHWkst0H7K53oWoMU71JS6TvD+xdNA" ..
	"KRGSBOXO3JY/oxFqEXcnAWd4F6D5pMDz/drU3s9FJvi91i0FkFw/S3cZFQga+Gr/rL69gkX5EUbK7ngSlBGXNl1CPgaRsiUMpZYG" ..
	"SJxEl9yX5XAGi7GWOicspmgF3BhEBYV1Iu659AwkUj4WwS9jh7LjSGCA8853x+L/yi5+7HH9G6cg3zKK+5DXukQerqXsOHx4a8WV" ..
	"Dpq2rqO9noL3ceW7t8bSWa4RC8TviYWp9mAI2J4GzFTjAoHzexG7chuw4eX4Jtxy1sGfCdbwjJOzmUlK5HeL3HReBXjms5gZZUKo" ..
	"6Z4osxeMWp2PrfvYBWZalYJSDgX4BfhMhUe+c5hA+al69Y2e20kKY3BLU043Q0v5BYEiUg7nO+0HuZOkGcUnMfzjfuo4SKBtIjAd" ..
	"MS1bOx2EaF8+jkbO+0Pp72WtphwOEpSqz1pPnt3DZPEn8n3ffOOTrGePOtOepelI0OleEoa+9kdfHECg1wvP6/REbPs8aPy4TnY1" ..
	"HXPEbZRQZ6e0BAG8Whg4xOGu36eICWLa/aK2jFDS+cU7krq8KRJAPlCiCgH7w6KGrq01sVRdIkMkf9QkY6ekXvNSQVB08/fYFsAe" ..
	"w/wH7hSqkwdcJwFjyWIcVlmR5YRHmUF4Xe9kg/ewlwQrYZGJZJ73T7jJFNclrAqi8NiM/aSByRqH5lDNb3XILgHu51Gi6PLKgg87" ..
	"z/yol94y7XqxCotnvllFNNjpfCFcG8rlRNOcXqZ5N5P0CRW9r075x6W09VUAKpzPDF38YmrYdjptW66wXolxcI/DSVsbDYASJv28" ..
	"vZuO9nOg1pNSsF6CqG5XOKlpEo1fsVNBQww+adfQUzZytlk5J0xskqp2zM0WpGQWDyIOBcWLJEdVZdxXF5twV5kIUnDfmh0rV2jJ" ..
	"So2ylmOtxLzwYFIvskSSNAVttbeFMUtWAiiVn3sQisPz/XISEW78kT9vC6qhAW0YOvNPLCfp8SFvmNKd0yjz6PRyIXOQgA9jXtD+" ..
	"m9nrkRKl5/jrCUgnpVFYb+4aUnIoi6xDNN2P+vb8+qhMmE3dZZNH+DMzi0xymjOwHb8JuNjRYdzK3EJskooGViAlhsy+DirGjiL2" ..
	"qHP1XtS3q2TIIjc3uLm2gw69xDG8w2mzkCnPsv/GY6aJsm4NTfVuH/9UX80I6CfWseDtUjynjQI9peJnBigwHnVxQV5aLZrb+w7G" ..
	"gc3UZYw0hRIMQWVkUWS9m5JwM45YT2gaAqHYYu2P2/Udd7oLmi0jYMqltEVp/4TABQ6uauLCHQF5xTGKl9KREggb+EQkl8liXQbB" ..
	""
local PAYLOAD_P10 =
	"6H4FTQAwlpo04KXKDnD+ZwkqPT8PA3tFpTcifOEx9Hl31EnueklTQ41tD+1ltWIG/X1X5vFS/g6iM/UfcYoR1sQf4sWqIlWGLDZT" ..
	"Cej6JMNV/YJ8sEvYOjKPZ+EQWSWnraL0smWXrh66oXN8fZiU9JBmpDxmLeg7oQisk3v9G3ffbeooHGyKS3eL2p3ZQ0zF12Pq+a+P" ..
	"GHnR0/0tbSY9nai1UTR9USotsvfRbXC6HMv0uOgPhWM+bXAhxUdvODLt5YZ/3PasxVmRoYe6S5e67zC7pF+Mw6FN7w0q4HikN6qQ" ..
	"z++RmW4rd0dQqr3ib96t+mnZqA1ZsUb8TKV0tTZO0AKUXBzU8HTs/+LEMOKNKlVUWAhEYWNfp3n9ycU4qn0FB1qvdrEhqco5oyWZ" ..
	"FI6dtJmwdt0Uwiid/iMo/cDSyO2F1MugDdI24Qp5U63urNyRvJiUDZeH3UWH+pv02544HcxypSl5ITxqf9sBfokuTGxgUnyKxOaw" ..
	"a8yNAKw4dRcxwTiEF8evb4GksTDOZZKQysgKJNpEYd/ss5Phiap8YgGF0KUI8NBqxk6JaeRxOm4/iFaxfpdcnJGeWk3e19NqNilZ" ..
	"RRrJMBNV6sTWI9u1DZLyMyi9FvoiYaZn+EDMDH4cCNtCYxiDu0ippJlQOwgRD6mEU13t1ZCDtli8D7HHDuHREbbK7FQmQeVzPee+" ..
	"t37pKHoUNwAFMRQXUFo0tcM6knWAnUEB9SMHnLjrYgbHnUdl5yD/q8Nw6x8bD6Ozw9xZH8W6rdfxfHeWL1GdxbYHqih9vuJMS4AH" ..
	"j5pxUEBtocL8muvbzzhGNsRIg4hAF9cQLOlcKdKjYXXaxOFlxSzjvvk6AoDKO5C3c3pd/qNTJWb+tH/VjAPRci/y2MJIM4XQp8ol" ..
	"jR8FeDTokxxNnqmGSp7ETimWq0YlugYhrAzqk8RxHd/kvYjzqvHBcZsX326O6vL6AquXnCu6bDxk20Z6frubc3wswpzRKMDQ9GrB" ..
	"ZfpgCYi9s7mUagxVib4Gb+WTHvru5VRRH3K5b5SU0UHsAC4dXE/oW55d+rEkvSsVT0wXau3fEnOTaN9dI5kvlgWie8YrJ60f1qV1" ..
	"1cLeoeKqIhOIkNo/WuZCisG6MvaGrQgWdgclcufZ+5y99dy1s7f9PUWg7rARK0/sPQ4u/Ivqr5BsS8OacKlVa43D0ilJrMoq8GBW" ..
	"ihlFPBY8W+t+4w9AuK/8CnPkbZBJGumPYCRrzaYF4EKUzSn4HHLOvlKZQTb5RW4+bqtKlXg5MvZEBiZOMyL7fM/qg99yWdDfO+UU" ..
	"hnnn4bd2DYKHkaX7rKqhgIHpbyHh+hr9egaw9/apYnjxYnOVlaCxniXfwLFTJMEiBUq4iDYxohaDXH+/6lRTdULE3rZUF8WXH8Dc" ..
	"b5BBi0hDjdl/ly/IRNqmNFixdgcBbHk9dNm0ipqUbxxyEkaZDCp0e6/zEwqDym1Xf7Io8qVVo3KCBlkL03ZGjQjih7ZeQL5+CcVH" ..
	"Er7mMkTK8FG5/7Jbh3haRLyI2fMxOszo60uGR7WXQxKlLs2eS2Sa0N/fcdSK6lSbVNp3AD3VdTKKcOsjSYSlmmimy3bktQqXcxdl" ..
	"Qfu6VE0IdduAiDEWpgeV8QONgspq9vIoE0cCzZrhfqGsxFlkJ6Eb2pt7jOdb4ybuJFwKMxmoQGjzPYLSBIXzMJGWlGlObLNfCXHq" ..
	"9YtSQBWmF7jnTbsDLt5TGbxxDqjzzQLxHebjvmu6dtJGuXGdf0pi5CAqgcpTt2Rmy00yBp2DTCr2Nkj8fknGMToUMjgBqgUW0d76" ..
	"u9+chaHcm5l7A1+oArFshlpojfGDoqzmb4pzKudwhCvQFtUbPMN5JFz1UT5yscSuuUzoqCqVVU+bEKCWuy4rHPG8bH3Hpbb6BryS" ..
	"i11JTBNGm/mC0JzsWYbgPqLxINryaAyJVZ7FBuNxrUuw1ejNoQgTdC3wIIfQdI11VdXwE81v5zu2TMvXAOyw0E2/uQoHo1p6f++8" ..
	"oMBtCVV+N7X9z929vby14uJHlAsJeQV/0hx3hCLCLEIJ+4pp+pC1O5evXyApLjKa8zCrcBT+BM/D8Zku0Z8G2HxRw5CZIyTd7HVx" ..
	"ddu9z+O8ufcmPBUZxxiz+L4G4uDcySA2QhFVsu6eLdzfVa7ue2FPswKEBZ2ZRAlvTWDMT26F4qFywK+u7KKBJzIq//qFyiTDijiX" ..
	"RJmI23WwZUTIskz5J98sYczeq6ym3GBX1hlWcKhGnt8MQlafkeXTi+n9GXlpgmT6Ml+Q5pMetmFZBN4RRX/IzycIR/mixhUpmpGR" ..
	"WRvp7Xss9RkEHxefdkjPUsKW4y1Mp1r8Z+xcYd1PUrrftSj2CD95X767fAC1INRu7sUMDodcHum+yFqAFeb4dMX1qoXwrGUXgBdY" ..
	"J2jLKnVX+KQ+YefG8WgffD4sJsOTTDZ8bwyfAs9O+HPJBzoEAShX/FeSIgsvKvYa0zYLkyHU1A2xODnK1BRywP6MUHZ8E+idG3s0" ..
	"nOSrqXlN/ET0Jg/WRpwEusSm/NyqhystfjUN6Z79csg/8njmLuuPlva5EWBVeD+Ey/KawCGEAd5pvlCOkvtMyt/JcQKwKUwxgcvv" ..
	"U8lxdzmP46xIgBwS/kKsD9pC2aIC5d7fRdHXl9QlNHMz4sh/bLnCM+4PjMZaOtuuaauqQYa8Lm5/V7WBalPJEZ52Sj+9mUH84qDo" ..
	"P1adrJb20wF1MF1svLCNvhHgX/ximm9rJ0QU4NHi4SVY4HpsEryoSY+2lldjD02jsadCAZ2lp03UNpwnQ544p0DZKRQVxEfatJ/Y" ..
	"sdyBMdG2Q1sJ66k6viSizJg8nLFJDehEoPcyUqts9AVOygjymlZ02DlZ5dNflAMB4EhQWRD4MUGgk7+ek6evHO3KvqACWtakz0Im" ..
	"rJbyNksmoca3qJdtIVr8s0btxosvwzf5FZuUVWZ34fiSqAKuUOtkBzt0p3eI810WX72tGsFaosr/rowWL2DEZ2jzPzedwE7b8NF+" ..
	"i8dflW162ltSIIiSZ6MoSM5PNK91Cx6VRACRQJfDb8PBWAstJm/nclo2Sj03i4R5AtIz/+f5P14hxRxxQzTHVILeD/szbUeIjvvh" ..
	"21bUzbQolCLajO/cjPDyM2k02mMPfFkXVQozXXLez63NWb0NMU5iuPRWAMFw57dDkY/7j1WjfxBmvMSPJCSafzKy+8HEq06Nd2Ga" ..
	"nxRcCD59OoLwxIL1iJzj+m5krr51AwXvi4C4GhjvG2kd2kum4LxHlk6m+C38/8E2m7zXZR/CNNODH9z0BrriDbHYl7dibY4mRtxE" ..
	"ttHzDiIlyFCzg0keQlIBIUNN8WyU8wTu4hjc7l29H5JN6L59Zy1iA9yFk3Nx+Trtc0TBxphKpw3SZshf7s72615WRao2ohvp1h7H" ..
	"FZQ70a2URo6eh5Gal91zWv1f5PlHStznG5/hpDIH+cCbpmlmE7/4rUE1qCJ+ESzJrXrhcCn3jZ/LRtbuZEahb8kuAfwcqqq+AIHw" ..
	"6TMB33WMAVC4CBRDuuEjaP2f93I9k2gWPU5STovXaJta2Xq9gNJXdkPPIXAjVOaTL5ztH1Uwn4RmalbzgGhrtvBop2AAYJ6RIxnj" ..
	"cAsTHtqVaM4wylejOrkZJQG1ckFl1M86PTSueN1vbgaVx2B2DjReeAyX368YxJ6eTLtiGCThvDOeF+1G2lnfxwqGVP+3tTcswTzv" ..
	"ELR0ks3pVNmpbTnTQK+/abMnYN62HNZ2zbBw1Ji2zFP0HihlVR1oAduLKb9nruI+Zc/DIREki6Td2UUmw+o29sk4uBNFBMrAVhqk" ..
	"rjIB7Bt7ZajeL5YkatOSukH+vJ4ubIEOmV9exCKPCJUKDWfOOgbcmAzsMuF18HF1nmghi9LPrEtka3U16tUE5NBdbKRNWvYp5u2g" ..
	"OWgUYDN9SIpxew4pLbzQV2psaY+sYVveNRRHx0YdJqj+gNhzy1fAncRY+r4v76A7Rnga55YTd1gweIk1uel+QPzI68pA6f5918Ao" ..
	"J1wEdYY2DLCQ4AB/euEDNcRskNru7Mh029tkzXKcjxGy9RoNDfCTcNtg9Z6vynhTcP3LOfZqE4SqC7rB8w6JlGLg8/EHjZE7mzww" ..
	"h3Ccj19ipjrN7+0cZKUow+Lhy4Zfdy8G7IX7ugvVCpikJL7z3n0gIFGip4RccMhCK9uEDf6O+XeyLh+jJScyRS4ClCkjnF5yfpQK" ..
	"WoqUkJ6EiwcDVfaCpXEM2LzRtNDBoGNCQxzfVoJbbEjEM+QW444yQO01Z1KpBnacCgFHHIrUZVyBjuDsZU7mzjz2fhYGhgOAYunJ" ..
	"o5N42vi97p0EwBcMhjePUjrIhZ7sCvudBFYtzCJrm5shQoAxuFX9g4yWP0XPPd/0+MABIWGTEoGEDJukKyjm/wu/pjeEAoaohl5c" ..
	"QtKH2Pd/JGxytBHZLv4N572o+N9dngZCAiOdUOOTOLhbymWoRJBhqFmVmTOa2FlYM5R8sqt06OgvpNIDQ2qdxCEoWpjqnr8qj3q0" ..
	"U4GcXQ5xMzlBiqWnBqTphF1a6EQGYf7RXYQ+b0g46Hqp3gKHEHBamZsvM7Q8YyGXTaDEdovXz5pqTi96YN5BQfFIZGcgINPMts5B" ..
	"6Vz9EM8WZ2dTlNeHqxGMc/rqWYwXGz5S5xIFVyv0UoUY30e+KOpYfZysVAPnzQvgQ51seqv3V/JVjIuFRcsDZ/9Kv59xz0fe1V7j" ..
	"f1JwByp41vzVJlZzGirUK2oqB024cE5prwvvsi/S23GvKitPuWTWb4yaHPWN71ieejff+xVDX4S8Vyhr5Q2/JkzsGYoEUPDz7pIX" ..
	"rgTOQePD6XJAykzRrnlmU5lhfAakr0mlTt5X4oTMEOzNqXz/RaDixKX/Kujhoif/SH+zjnL+99f9zm10ga0MZ+aMClM9ormKbfSu" ..
	"uC5jtCp4BOvFioa6FqSILHyf66SzPlLIN8Qy+DH/TDDW5VgxAW0wZuycyEjeuFOAJeNNRxkHiJqF1wyNKRkZnCZXYxsIbzGUHt/O" ..
	"r/k5QjOgvN1ZFSg6pA1xHiXv/sVD/VgN6vfNRTz2eHGw6LpkmLKaFuobnsBVvAxgXjEzflhqH3KA9RkfpLOjBJsHysDqC+3pj2Bp" ..
	"RrWD7Yvqg76MHlYBPpTxATqFiFePcxAmq++KEZ3ho02Vuc8qxXQDZGfmv8LYSAwWV3rodEtT0wZxWyyLe9KQ4lcxHL5LUZC9fjFW" ..
	"2UPp4edvMfaBfrQD+3k8sNqUVs9ByYqVCa21W7Y8eiq+RIyCqs/eBJkYvsfIzw1tTBJ/CHkf0XX2WhoRFWuf80YHTxqHfpHTIAF4" ..
	"laE2v4cxyRy3QGXmngaCVAsHBt9l6z2GGZNY3tH0kLHj/Y5puq4bZ5fth6UxREm+pBmDALDDHHymFseHlqOtUnbSWtek6BM2zLf3" ..
	"bNV0wEIwNtCHsEh5WA9eSpQy29BnoMGLiSUd/Nl8z6gPodU1vDZcstfw+cw62J+1D6ch+BU3VPhescjIxsVLKMXV7zDVNIhF1sxq" ..
	"05HKp1YCi98wJIvhJEi1ONoX5reJ2n1mNn9WwXFUebG2ORw6UmjRftmXdZDNq+GypGllhwmmhoywOG4ev0KIim+bRl7DzHp90Npi" ..
	"RqkdCNn/KmN7uKCJw9GOTSBB2ILJKkN4uxcFktu/AEXqws/UXzl2T1pmOZVfvQgZ170cfB1vK+A9oD1RZoXN3TItr8+NizKZBoHL" ..
	"Y98Dh4kj3HbMDUZhD8qalkQACbLirDeju9dcmRsDoWIJs5PpjX9uhujp4usnGxRPGgxfqRX1Mc3QQluv1z5LNaCEDpJgE1miHqrp" ..
	"i37M3dwauG4qjir8g4CmnpTqoTIVA1y7pDUxySPPBnb9+eWv9AxOWKrREXEE+e5h4zGEXrnggJd8anDbLNISfysQ+6hpOmHmO8az" ..
	"NUk3c2lYiGdOGkRYWr+1G5uH33DqODZEbI81h4DhZxCkuDE/FGLMoHy2on2whzeI/blD/+sTFPgPpxPQd8tlxwoUTtFHP5O20BPF" ..
	""
local PAYLOAD_P11 =
	"wFZGx1/vQLtfN35ejd1V4fqiV2x+DnoiSmHgF/jRWt7841ux6BTvjCFdMR8ejkV39N5PwqwzXZFtw1EaTvJSeu7TlSfRFn1ebB96" ..
	"u4PyQvrcoZmlt6cxjHTex3VJ2Uk/6uZySoNd0risgm653CPpGnxZdKnqFu5pSAv3txeDSxdAkJUIpmCneDpDkhaD6PJ/DH9cxP8C" ..
	"+WDAlGGqYwdRdHmFJQS1NlveGxHzT7PqsLoqwO+7FXgtD2EUM3iczDTJ/SlUkKoNeLQ/bZCz5OYz+OCVnFPuOjH7qnr2wl51bzXv" ..
	"A7mP561y3tpj6nJ81z6/wiBWQmq8sN+8HDzjLBKqNAsSkorJcL9NMmfE/hGqpD4rIGhCZn2vqFCcUj+L0WXyk9hE/b3jnNuLxWtX" ..
	"pP0iIYV/PUHMwuVO9pwdiih/vfjHMMAT00BusgifVnO73eTcmdn1tGec9ov5We7UE9hJfdy8/DND/+XNpDmXhUURLiB0YBf380yD" ..
	"2wehJgRGNBfQELnDl9sOfZEs+h4jkF0vCcnDOGT5Qo2NELvJj6Mdo1HVr060C6IKvuU0wPwVSDESrlRFIHA2gmC068BvnML3lpGu" ..
	"E6NKCbfEc448B0dECH/Ovw7VQLLpDX/3Fvic4JEyQSvJ0CiSHfhY082Ia3on9MV9R18x9+bmxN5NyL/YZH7oBRFFCAEtJFeW8bk1" ..
	"cgqvr2//VQNU4g9+w1j3qsLSBC738NA8796ZytOHt5YHqzFZYJIIUjdUfBM4TDpv8nh6QFaUMCb8Iej2vGM6vZ+RJz4T0gg/7QSj" ..
	"C0KmDzp2dK0jzw2qZ2ghYE4kpDwvlrvLjFuBt2HHSx+HOpYRiYKDRvfI3gQRTDQhFdn/7cvKIFMtsH4sMXxTTn6RNchhcWQY+E/W" ..
	"i+5C/fChf5kgwAq7Ki96OQKXoUbYYtSX7MB4vL79C/HshqhuBLn7HoWTQLvANjmSfe3Xk+ZDxguR8UdqjFZjTUlN/6xeVaRIVXk/" ..
	"cTV/t8IFDlRv/MX5WkcYgyxtlFFnZ3GaHekJWIMlr4jaJRGHs8PjwRaJPVLCHkGJxbLxxB7chPZor0cD8ZXOb2+CN+lDNH9aE+sA" ..
	"mnOMnmhc2qEt5AsOVLBMhCrlElC19qn0ebTa4Egg4Jeq31G99P0GymVub63UrSiSJUzr+dFEcNERbA/oeB3fwQnTN+Gl5xOSiNxs" ..
	"aTJFjcICUetJAm3YYR87OHkt71h6VGsqV4z0h6ltqwA7W9RhrUQvUcJ7VAvEHEk8WgJhmmILVcfOvM92gvz+pVKAOIR90XmrJRjm" ..
	"2xfPPHhIkYy57oJRemhutr3R/IDF2JpE26tSPl8WpTy0S1EYrJzYii5pjf6MDUi43Tnin1mbWPzRjvfy4E93aX38kJX5wcpeei+t" ..
	"Bu+bVrOwBQb4RP4rOgqggaQsymuoJjGuraTZxmYs14fWcQH7NFkuVts0SPKoC4UjNTsUdqCdStz6blY2Azo3Ev9GzjRofBpZY0Rt" ..
	"x+k7vq50yg1sCqlDT1GKMAudbS1/oiwXAobjXYdFFnjr+huRD8U5F9Yh+Lsa9r1tAMor0yQ6k8lmUNswgFufQmJiWUCAqWw6+0xb" ..
	"3Rj/4U4nxCuSnJsfbdImspod2pXEjJ9RPv24/OwYt2sbAOo38oOVB2nsgrXjjvjElpaZ7wedkGDZ2+WJYnKhtBeW0qqEGVg6dqkB" ..
	"KxI29RTMb3Pwa0x5mgd9B17W6yQjtpUrsZuxp1MfGCHQ8l/Zl/oQOFAI8E3WDr1OQAxbQqHUUiEpG8FH0utr/V4HdxSVYU77G6oZ" ..
	"qZ5C86d1sE3I/wVEAVWCJ6eWOi/WZUgyZ+KRqV+aG/Ajm04NfnzMXf1Nzweo17gMfGaQRps5z46s98oj64zDXBGrXy+GgtgOXPou" ..
	"F3b5eqAhnGdCNCukmWwJFL+XA/StOK2OFU7bSxSUdXxfOX7UQlbRv6WYw6XWcR05moWOAg8VLSgpiTt/GX7+X3xvV8eiE5LkrYkm" ..
	"XrSpvNvvZaXG2dRoCmN3rrtFqvGgR6yPKrcrk0e8m0T/7sVt/napqEKNzecH7ySLqffYtCjXNIEEIJko+afWmQc4pIzFc+Ai2Wuy" ..
	"q1dTcfEoORU/WJ9oMEnxxsWFnqgI76VjYhejFvFfAVu7xttiWxT459JfenfjW/TbKeblw/RucBhQtkAznElaRh51rTT+ZseKmtzZ" ..
	"LVyiRvarAlsPIzZ5a7N+aTpgtuy/iGbYbFHi/gUX4WtvCasraJ6ET8eI0MrZgPax0qYRuNi9pUWn3C5D+P/IGUCEurWCacv1o1dl" ..
	"stKy0tU1yiSv8sFZ8H1a8xTLa2d4tn9lbPIHkK0eIhRSPxnwIMQgerQNULvRdWbq45fCUZdjfmhpHf8yHf/QQE523PzVZXJdKfjQ" ..
	"ZJpRfDaLzst9TKbIC17LGsdjei2lIrC5xmdnSvc9ntyxMIcYdbpMmH4cElKzSuoeG+ZLD0EQzC11vcMbx5BxTvY5k6Roy5eF7d/r" ..
	"XiZeayCx1IuEuy/mvRWx7IQ4U9ehkLV0/E71WgngVpy30dhock2hT9LI1FGIDPbk1sAzycXy9ZQ2bJ/BAsfBvp8d7OD/LT/9Mefk" ..
	"7zX7XFWBFfochRf6QwYibU3TpxGWFHSs3OHKsrySddDkxfAeZMB/Y5APAeW/VjKf0pEeLzY81P1+Zmq4gk5b471ThhFzUgkeRwpK" ..
	"lXV+muh95EQu268UtOMjWrNtIncxdux5xIzOb+VFXTq0zx/dU1STmQU26ylN6n8WmhZdn215D4JgfzMfBroorKKZxRFPEynKIwG2" ..
	"1QQVXwc9SogcohglznfINjecyBb30p4x6jd8565me46Mlk4MY2nmDryeaIajLGBWyxNVJyD+RFwmOdCzniAG5AmvBNjlVPanLHYb" ..
	"b2YgVTL+qRjGSARD+It6RBTVB4MG4hRSaGzB7kPFbKFCJ12Ozvq3HbeuZ3FAKOQ+ZIOOhIr2qMYJxrpn+QMASW3x8S7MYgS2A+i3" ..
	"gBe/YkLL3QCrgvrWbVIvJQiotQqNxSBz/klfTjsSgG6nSx1FOS9rLQAFkPtLDRYryHm0OJ34X8JNXHpA/I3OtFH7vHtrv9C26rs5" ..
	"cV2Tx8ZuqfGNIDwqZUY1+r3dHdxIndcQjO5YVIp4mj2lVIOUDQT1tfxcccq/Tyz9XqjA0J4PgcpyAmUR46m3uptyZetGyrjxDDy1" ..
	"RBRp6vmp6jHiDI5FOQ9rIBms6UA0mSMfksHa125VzLtSioiIRC8Ty8aRVp7m8U8Ne9pX9CvHr0gwH7LlSxkJ2FGjsEJNDjlX9aSQ" ..
	"URn7sppRXFk6Kd+wtwpOON79L0cMQO7hWPSjeZo/uu/EsWuctIxgonoyUk09M06myAY+WQoRKfGdjmMdXc6JkwwjVassfTBV3eUc" ..
	"FpgAeJLLkkBNLyCH+XR2yWmVbu0MrvXFZA3Gaz16CtW8m1uj1m5llh/UWPsfh5wE4szBYWCqSnf31Oc4mTode3SkPAtK0yJ81Ixa" ..
	"tTnGpboQw3epYcrNJIbAjf6QBCMaU/Ir7GoTWjtNeJ+cElwAixPNAkwKJHczYOVpLcYAQbk/uGZ5LFR2SIMHerY4oPJc33GPH6yS" ..
	"cxilDHsylGLkiRCj7zk5AvizrXbK57wvW+i/nug5tTt/rGXNL5q71pk0vpuOx3QA6IDL7KEFwTdm9C1g+fgWRrAQo0Iga2c0T8UE" ..
	"i1Nb5Jp99EEDBdV3dRBRutw4gH8tZgM0z8T7JufUhEN7JPjpwa7gtFDPwvcm81jxsD3GwUmK7jZrHkpRHrlZmlw9EuSvA76PRTup" ..
	"pwJ34pXLYOF8bFUzIBLsCOiBKLQIPrl1dBbdYaBe8kVSZHmKhLXl3rTXLgc1MeyqH1m7rPC89UYs5ltCWNQzSl3MghcEPK4SoSjS" ..
	"mml4t8dABddp93wL5nNdb3DzHFgMqvOat/NDZs9SBmQ+ngkzGTidZ9J5mIOTrsuH+cDr1QRrs1aV7xuOXkzTsjWWcpG5E3swPvV/" ..
	"tyzrJ3ExDnBtSYnAT2NeX9UKPuYiVs2ERhFtTR9qr3UQD3h5IkXJKzpxVi//jqKYtEvtWo1R3PJJkCaLM1cSgpqRKPSYt67tnF4q" ..
	"VFlU7tdc3J+uO15B+u6V+JMbXXvnpvQX8XaQ7qfCHvyxRYVtkMBZk5YfCTaygvSHUQVwCO6glqNIhvt+VFCzO7XYC6U71OVYfWty" ..
	"kQa/BwY9MLNwmiD6hpql3US2cNIzIRlOD3JoUHrKWCcJ2DvSIL5nQovlJ5OCnT9y0IeXfqXRZ1XSega+jbz575yATVsTEfoK9KnA" ..
	"EoGfTEA9LFgtnY7XjmaGxmv96JZSqJqcYnbxiBq3Kpjd+OPOXTlTPZTAhVyx6WPR4aOSZUJNw/yCHyZWLNMTV/s2KU8ls3pRhyUg" ..
	"6iyC4iWROyNCn7sGIth13PmUKTJdTJemmdAsp+yUY39ZNZcFV8bE/bHn6wUonV19xtiXrd00vJIga9/u+ec4QFHvDHVcXa+bTIkB" ..
	"3LlhoyCYOq+OBxmAFyk43Rw8s+ofnBZfcoH7gnM+lWmHAGzjCZal4neKL4gOOkr3GbTptFGcTJagn3LXGQdYHA3Vys0KPJ/ZRzkd" ..
	"x1BSHzFXg/U2Cf0Is5RSbF3w3uE8OUKAAGfnSBN8XU7MZM42pNkUpM6vCoZuCOXGzLvSeyo4X3Ch6dyh32ZvGzhboQBVXIvTy7vb" ..
	"/8rC97SYa/VhDwNlMVSdKDdB5G2rrfwHiQe/bFx2Is+vJ1NLsx0u1pXQHGfTyFsRxyqzgPK6QlSh9FvmfqqGyElN7mnEWXjPBWZv" ..
	"2OIxL1tD5om0JsJjttwiGpm1m4dIAHNoSiMJk5KH0k3sLB7xANLNu/WwuKBIJ3RTe43FVe1UmR4RWO7V8HQE1X2S3XPgw0CcEbBT" ..
	"Y9kN+qRbdgY0TETooyuggrLHvzXW4FTXf3ZFE3JRnecyKV7JLCn8TJRyibf0MJMxLubSYnN6QCrwE8PjJrwXml4+kLqxe5WPJaXV" ..
	"0mWpis5M/98yt74Aj4eq2YrUTSZqCgwSBQS7l02RYaYLcfsE3mi7s92Q9hPlf28BZBs8xpnoEmSaf0PycoI4RqzC8qyZwnN24kCc" ..
	"31isSVyW3Jc6ckzYFoep7wnrR4ty+8lKkvto2/AZiHmbkTUjFqFnGlmeAz2odmgW+f2DrxBSFiCeDcW4AmZb+pA2mpacHS442u7h" ..
	"FX6IU/TA81lL2U+pHwrj3o0GUpRl/8JzrLc9ggIJhOxy4ixqIbU3KEiH+ga2Lqzcm3UgI3776lpnvQJ92TlrAxwFlUcbaVDWdaN/" ..
	"FTGb2aMA7b84icNohbLFNg1ZO9OKppmAlAyJObwrYTZbYXkNXM/UgOjSGsuMe0l5flEjEcf309sGA9sV+cp4u1tYfzatPRq/NaPh" ..
	"AOOu8pvtGHbN3bXKkYRgVg8bu7FEfyFIgxJgGRZVAAuZeA3SPEsiAZeFvl2M33e97AJ7HNIzosq1XvFLZXYSFx/C4dD1/AeuPt/G" ..
	"Vpg7pB7FN1yIhZ5qwXXZ3NeGGrKwsIUoTQaxrpJoB1nUZrXVUBVXbfe9g6uVIQjTA4//G0pyIB5F/2ryPSFSldnjSNKzWgJVeFAJ" ..
	"kmwKMfTGohbw0IejK1GKItAvmpPULfe9m4SesMG3Ptn+cfxwLxHyzPoH11dEwk59mQpG5cnVamTYnSsTx6AjJsEJFvRMUtyWNve0" ..
	"vdhQmPuBt+3+BWeMu89DlxX0Nqr8PJUUR0qUSR8IFZYeP0+pdm/jB0QpdN7bGrstyPw2eBpr0OSPEJWrf9qJOKEcuUvJL2+FySXs" ..
	"SSb4slWbNZ0/8Wf6qMQe/xnrRGtjAX1/toJeSsMV23eGRZ684hk5o+2TJUif1E617c+4bLYjo2ZbPepoQDjIcV8hIe1XlFe5C7gM" ..
	"ZXzQRoyiRyxMBCITNSk1wU1pmdrWRvaxN+BfaDYX2XQdptE/UAVuLe5bsM3Ntl5T5nJViuWXSqslqGmfuN6r7tA6Fh1b32JmX/2H" ..
	""
local PAYLOAD_P12 =
	"ALiUTHeDWa4+WonUnsj5JCDyHPK8b48j0B/5xdxTWMA9WxD3mhmKgl9HYFcneJn3Sjxcutvi5JnJoXxP60YQNgs65nTK3dUx4gZ8" ..
	"7qMO3sGy+RlMgiw3WFk6+/A48P1Hxq9Kq86zI4UMulqa1A94hjcxphD+C4RPNKzTPqUQEb/gJ+1MDnjlhg+BzK7It8jiaadetTt4" ..
	"iUv8skAzWXQO24/Dn9UCV7HnT77byiGWZFhKUlQe4thi6DvTwEhb/gbNzpH9zLPNWZwSOyqYFst05Zo6cCOmZYO3NGB2xk7VyryV" ..
	"OHkOGM41kx/VoHLgaM50/m1fIcvYBIe9pSFxWwo344mvGCWSbVvtsrPFGdSTcd+gZJOqHnQzB6+wYWZBBx9UxIu+G8PSaNV7A9ha" ..
	"cOuiWV8EueHshQS0/xjNxeRgk2s+nOPSArxvkLHvdFEo1J1t+LK6uC+Kml4Ah14x5drYUzejrnRXwBDAsc0L95a+9t7rslhIdZ3E" ..
	"BKE/g7ev+PJfwTCzQ0VvM4BoUCy98+aY4joZWeliEhcidyKoslT5deJOi8DWIHgoKhgbO2pbDDO2YDeTq2w0oeKzBpqGJATcqPv0" ..
	"LsWVnaIeNs2cUrS1u/LxMqfo6+lB6lTVQml7klxu1yvJ0Wkgl24g4PRjwBOJPRD3HjlY9liKTue1BAA4PUIHERRuESV295XEJ7eL" ..
	"Cz7q0P7TtmUXRN9/4Qoyf3jkjduUf+wvQ2+oGKe6Y3ro/rAKu+ROj+lJWkMGV3eU3lNHQc22VHES6B1Otu9xOxF8tyOA9hyZC/Z6" ..
	"MBhbPb/ejtFKADD+txq4TgZbyTkLY8rD1Ip89wG20uvR4afrEo8LpnYnTW8vkHOiKWJoufBMJxKTn3MDAYLr/iOzqvsGmFUKNRlM" ..
	"ywY+CqyeRC+o7GuFuTo9tP/nn0XXmWmnKOLl9Ot0UCeGjKbep28ufdGQToTjj+DraMdqBFEVnz+Ygzw94wPTVMvl/Fig3xGvMKYq" ..
	"BU/jztLvoRPvWnt6u13coMtndncEO57jwoVghxga/z2mxtnEn0/nsi3A0ZHoBHMzdmEHLqVzW66pLL0oqXFmhlsacSE40AMY+45i" ..
	"tJRdFrU7dwLS6kNqfEsnLKYI45CPMetvjdVrOIi9jYyKWoPuWLj85JQhYMWy5bR5JWnnPEum1tfqssawbKycOKkSCrSqDTIfWaKg" ..
	"YxLn5ZXa5VIbbd886uozvHJwN04TNBN8fjQc751Y3dk6ZJUzncRM71wk549YLYxD800C/biC/sMWIwrLgv26R3vYPnATqSRMQpD3" ..
	"145tUkfHXL1PDZ4h5gGy1jz3v0zpi/VKluS38+uPNW/iBHCIRognMiLuLJjdAhQjJNcE9xV/hT8C2QGoCozxyEURa5bR/uuYg2sh" ..
	"B+fJtE2wD0zhW6oV/JT3ylE6LNTvZHeGpv60+aLFBzIhu8S7axc8BizhufDbe0YRRRNmsVpXfjYl2LzvOx8qhxqzw++kSxq3h5zD" ..
	"T97GRUMMuJicT+1RLTxBYZgoTPkS1Rr0JzWa2X3tQBWbfmNuA8TO86B2oMMIbCHVVKmhWNST0Z8tIPna9V6EBAVNBKF2alGS/s8a" ..
	"KVQUIMJPjERtDPMNuIiFRdL/2lN4kbRzyf17jhU2/j5mi8S3Xk4/EJEtuEZ+ySdcWtx1NLaWk90F3rnuSV8ynEVV7Gr4RVcS0uIc" ..
	"5jSvG8j0KmY5mJkbReVEflzvmHP3HxkJYDi7cqzTq4PsguEuK+VGwgQMrVvsxOHAvlyN1Gmxk85ih3C1D3xw5l65aI0fEF6AxURl" ..
	"fkNFmCgduea59ftJczCZkshKHymLNXzn9xO2ipo3/kXZ61//p+rtdARxGdrcvpaoaKNVSVAlQ2riVWTxrdJDqrOvhB/cNbDJxQ8m" ..
	"ArJ/BkNOHLqgRY0Zsp2n43juBSXn8NVlQkd1WhHDPdr6DviaGVK1DR5lmn43j8ph00npT0UtF7J2ejkeLXKZseNhQMcynwfDHudJ" ..
	"0DJ2Spf1U89Wig3wu32OPwJuE9hlSXflJh/ij+HzEJ0g1xzIL+q13ybgpJS1kig9X5x6UK2BXq7eahCpoY86rLq/1O1jDpgZqzxA" ..
	"pMPs0ct/kjiHVulS9QyJa1epA4MczEyJjr22YjFDDnNRe1VH4nLTbSGtTYWE13afKtLoeu56nuJgQjaZVxgsDQhAova/KX2Vyl2e" ..
	"69tUtpobz9gmK/o0uoda3AtM2GpFrNFVRYMiPeRvU0g/O9cdH8NQQ8OJ+U8YY90yd9lADOsjP/0tLBNwcE0r9zlWQNGYSEk5FBEc" ..
	"kMbHrRerkAr1Wl2j5oLqraCwf3gk3bxVUI0BVkYa4hs+jMXGI4utjroSxh43h1dUaYnxiCGN5C5KP8D0xTR7d6v8N5s2YDTsHnk8" ..
	"Z2myFRLCI2Mk9nuT5blMOkvSJsn3Fr1L6DdlrgTTV8g9v2MYcxwzOyFs6KmFd1/iWYIHKWZN/pwIHt9SThRWqhz/K+Gy7UzB9jsF" ..
	"v/cZlfAFz9Db0zxdVr4GrP/trLg5K2ulRweaI7GzBW+pL/mOpv4d9hqZQNVN3BZFkhkpC8kyEkk4m4WMWT5mFYnAIpgFrtq4J/G/" ..
	"ywTQE+EVLQByJN7AdYMhf9SOJMlDjEXmsr4n+r9BnB+RhHlcReDPimPxpzNZWv8h5Cubp0cTSg7EdTCtVJh5A/+yk/tAZap9ybcr" ..
	"LsLhEDRWNp1qxAgCIWVnV+YGigdFUAQV2CDde+eoc9HQrfxV/Bdo33b8K6w2xhpF7MUA5p7KJgQX5PyTFlQHEEFJshbB2fq+b605" ..
	"8dFvC9KjYa+woWLEjc6x9HrgILqCSa3B+avse5PUCbbjIIarxjrT3eTuP5KLjNS/ZNE8RpkIUTj+zXlLiDsRRtWshGkbvk+89HLQ" ..
	"FeblKvVpXffDy+/C9+I8aL0Dz2tjZeTnVD7rEeGecbkp6xjdsdQp9/76A0qqOoSK2EMMPoA2BfaZTqfQpEkKMCwB6bFmhnISCtqS" ..
	"T3fxMhIGh2fBXD4cH0m1ZXNIT9Il9jWunybHgVkXN30TcJ+CT+kGctIz/IvG3X8Q9tk5HpnRRGW7T3HXmJ4CW6dT4Ux/PO57l2Yv" ..
	"fPvSqtdbY0E/hVIOmVntN6/789Yb3xVDvN5C0UmdNINIoteGQhrT+v+K1X3UkAdxBLnjgdhEvDk0EJpdfiIquSKPTbSVRFpXbaHa" ..
	"Fc6YCpes3Uf1GjGH6c0GdQWhvMamXwWq0+dDBfTrtxvMWPkttNBeAWVsdDS+Tj0Q5FuNCBI/r7bf5jajTQnKywCyDPUI4/mVGutv" ..
	"okqDOjyIXqi4km/zIR3wOqjH/sBj1DkERT4GQLFNAKpBWgAs/wjV35pOcAHoko42NLCcjuJZRe1/pISQvkSYlo+hHAeYTBwZPcfA" ..
	"65HUAXKzVAJxV+9LIqocQ0fc1qX3sw7wbeESzOQzirJ3SQiuo4iwhZXwxmTEPKUuUdSsEOwta5kD1eFr6HNJ2iUwS6Kva1pi0dd2" ..
	"Di15KD5oaM4vkQTlw6HSJwjsPkZ72vJ0kXzUfzK9k7sltUlOb6ooWpPMNnfPyGDDyzPFpOgdipU7WE40UtCactl48JTy0M9cIlll" ..
	"dQf1T5sMXG/ZdpRSTM97BPwRTN8Ib1C0towPozGR3OuB64d2uSjzsyt/NTK4xKYIpKeyKIyDs9gBkyAICj23F6vjlyn5y9NOXiRs" ..
	"qKavsTZ12Pz3/oJLDNcbq3OH+qTT55KC5kkf0gP2OW9ufH3Y1Q+jVtjzVy2uW8sHdKcHyhDn/xxcWkZRpZXspZQCcwqXGEx3resH" ..
	"0Vx4ydCWDDZ+qpnEGxAdgW9zS8iBSt636BjsVVwQCKuqrshLDk+Gr+ySAsE+cWG6UVTdB/Q5NDAVgkfp2Q/eeD6qfKgSxec+Y1EX" ..
	"oGEbTED98w2COjC4jywQa8bNyQgilH0aMN780QctTKTBoogL7UEtj6W3cm9DvBeIUzxFcOosgtgPEDYusZI8EAzUxQs00Jp4hsIo" ..
	"tCLYXFQ1QLYUpNFU+/gQLIvGRn+4+xoMccudLNYvQyHK0IXQHx4VJ1DrCSji+jv3FtUlilO5BuF/1trzd4kyR+uV833Ikmx+cTtS" ..
	"u4YOtqWxgtdpR8WYMP3wDsGrGX+tUh9vWyJaBIN0o2LUpFyimwwXLcZEUU+Js2LDigVFfbt+wYwjqk10YCl4AciIioPJHvVkGHNI" ..
	"/4XkEjW2NsSwctui+du40pphVA4JwQ3jn87DXDveoLh7RSdgE8flsW4/ynZXhRW97oQ8Eur3Qc93geoxMKhtcKwfpVeApapX/RIe" ..
	"VVmykge6HTICqE7EPmGcg2ajGZQMULziU2dMN34chWSHlk/lwgdI7FkPT2G5t80Vp9n1YV4VmtiPL7ZyaGoUmWW/N7cggHIY5k+f" ..
	"0/hEl6QAIdzkR74gUeA8mpr4C1wPqjZnlo5obNaUfscVQRRtER9dg60d/LSbsvZLxQVFd+JSFtd4wNmEWMZ+MXIplsI2XEAo6ibI" ..
	"oHHcHoIfeQ2NDUC4juMpZXm/KZj+SCoYPSDTzw0CwWwrciHMyz5w2ViO3NsqXk+58EZJqe6hz5HQraQaVlVggIxz2MsMKr/oGuhi" ..
	"bk/kWCMsybCamasRbcSHzQ7UZtsWVqnj9z6wV9cFPPYu+D3rJjHmbJUipQvMPAZJA18SqQs5l6iOG1mYBr4JoDQtCun0Jpz/5SRH" ..
	"fBYOLjAggDDM9EKYSOTrH0aZIi7EQACMrcHXWa/RPabnyLzAZ50VukMOiLrmcm9OVQ1gP7vwOtI9qLmZ2A41Y1o01Iebl30Bxirc" ..
	"KxROVbmXt/I4XVui11oaRwqsICVgBSyQvlpY9WLeoNIJV/fFjqCDdBB0WmGfPh7yy2xyInU6HE5UvmOM0K4Ecm2CvsmZIcGx7xRB" ..
	"1KyVNutU1ezWR+YV+5y+03AsSm/ue8gNo4WMgk4K2AzCoog5FGiLWYnjlLUo8StOh5O3RFgf2151xmh+p0vPnLy7q/ve8CHfJgo7" ..
	"otS64FGtN4uTMWhK1V5J4qLu8Pp4gNXtFLazoQEyWrxlYcn5QebXlig4zXKYWusMG/VgQxGvvbROoxfVa1ZxfBnBMR/YjS9RLwmH" ..
	"jMaYh62Yi6B8OI3hPaL9e3eit6G/d6LIe5vB5k1GkWdsGVMeFwc6nXgR3bFJNNIY5kDc1C+0oubSK+UiQMMy7bn5jut/Pf0nDmiQ" ..
	"R4nbyTRXKmBZnHRMLHqn2zkZ/0kfM71IiPVjxe1cVpMhPz6JdEotqowc3vrVfiCELk6ILNGF9ju9m4s+QrJCRW+VhL0WXJZv4/V0" ..
	"nQy2+qPAU8bjMO1ip20keDxyIukmxFCg3OR0NNGaxrqaIM+pk4yNvOmYVRgMTNow4gX3zlEo26KeIp0WiEId8UT+M0pc1Hl/KBy+" ..
	"mQS4wEGaXjwyHM8IOcaUAc6tuG+dHlvpY934LO7VOnCzHYj+rHFI38zSh5ESSyHnp+X3Z2BCwoQmAICoq9ZKWp5xjAnlSQdnRjq+" ..
	"X4bzgtBoVgexiawLts/2H/AVXKFWT7Lll2wXae1R4yDphlwQzeLnu4WFTKEP4fCRdvyCf9Y0caVizdEHvCnX0lq9kpGJ1TW1zM0s" ..
	"S5M2RBNdRFp3QzPy7tk7kjK1ZlK07rMyehjMT7ThtP9Gzd7Z+A6qs+2TAHjB+ag/mLvDkLigRdft6Pq1MBeSmaxik3waYxHyxGel" ..
	"+2kWzMmqbH+UARpDU3XZu14kF15qG9YSDsjqHf0R+9mG77zvcCAR6KO57KCC7UXhV9mtvZQ1jxa6PHsqI3dkwJmJ9skXqnOktL95" ..
	"beg3ydkAFX1bq9HPdMMMzpk7IsmRdRP5ht9ju0j8d01aRILTnX5n+j5mrh1Cf+hXmTuVg56Dg7vDzAS3I9z3qeQwmPXd/Fz7JjT3" ..
	"ObSXPFaUnkNWfdYzcBe7G0gEyfLX+SYlerQg65O9dFEjRRXt9JLQU6sYFBo065IjCkVfsGBhWmYiJGwPVFbTm6qhCoqQzI+jLd3W" ..
	""
local PAYLOAD_P13 =
	"m216wptLFuNp3O/gQ9qfVHjRN6bgNk0Kj8HSEw8aOGt2FlaQeaUT9x22BTkJT+QoqBAwOVWsXAn19mdZIdOw49y5hDRDITweZfla" ..
	"FeeXR204GbzV59bRpHszupRjxd+gLXP6+EAmCrkLlN9vVbV+XLi0RAUP5zPVTcoMGyq8SHzpRuD/qCxsGsTSCXrY8Ylgu0fyEbbe" ..
	"22XFULY4CxjtA2X+Ez55huEZOPP241ph7lnJ4+OR4d7S19bVC9wtN/boNCtNJz6wzmMoHg8m0uoyrS2Z4GeRLsF5kW/VQXCmaVmC" ..
	"O8ojXockBmvZTKrRTH7Kq7RnEVLfPlI14zF7DHs9hqGhpBYdizv3Yi/GiYhtD/54oCD7tJaLxJ33RnoTXr3kEBBetOsI9/hlDlF1" ..
	"JURiXFVXlJQKNxYkQ/C7lCLJybGG6cex2AY5Ux2jD3N9LDULe9vxwon15UAaZNZRSogx01DBaksslouXhANbDzrN1Kq2+yHqlt58" ..
	"YqW46OAq8IJGvjujrQEh+j+v/Z4caOtnKU3CeBf62rqT0/gi5T+USYowZmVneyTM4guVU44oRTlT+OPDP8qd1YwpBiFrXI0KiH8J" ..
	"BlRygG+o2EzURJDm4XqjCjIxFAvgSa8nE/+xZJ24CzyNr3c8LqNBL4FVr+lg8rQG5VPVkd1dYGaP5lnEW2pIy7d8ikC+1IQjHaj3" ..
	"7cX/kyo9NYL0P+xSlzbeiokDxP6dbFrG3W+wt0tdYTHjgZkqYJB87JjCt9sYUz5DgW7e/4R49F769F6OegKPQmHxZTi6jToGcP3o" ..
	"Iytp3Kubda1VTYb4pyQat2oC798uk6pEhmhv6DrgqFRsyiIj5OvzwO5cx+81UE7z01Ji2isijTE7pLbWW67zP3GTtx6ZAejkreNp" ..
	"3YptzVD5mUHgBl/s1/D8RXUgQu0c8pdzyHylSeIe49nEPx8YJhEdb8hID4C6ugtgkw3MvC8mHB4sAHNpafV7kQWIWdtSINcgjykW" ..
	"a5oSik0VR6gBuv61EibXJXnLCFsvIqFG3hP1CCPknJCt4b5f8NZLo2OR4J0HFR+jw94MwAevelSu86BCrdiA/HCTWElUPaCywNqC" ..
	"Kni8DTKiDmriKfVO+UhIFJkI7KfETELb3PoAN6oV08+0invrGXPuQlbNfE4YGdzcfqQM5x94zEWP6NE3DINuDbkq8ZcsbYMDftgm" ..
	"4JAmtFU+WSFnauHVWZjGgKCNA4y4o3VNbGsUsLhCNVCE8AtRRTVf0zvzjZNbS6s6EEN1PIjX5gLLVA7OORamfslgdLYhggONixVC" ..
	"SxQOY89joD3rjGJ2gqk4dgzV4/W8w3XY85v+K6iBLAnGFFAybBUyaKDy1JUOF74szxLTYcUTmvlomlJhg49F4szoJKmwKup0poJH" ..
	"s+zBjpnsdWlmNKaGPhiIvBMkN9XQf/mJnbOuDST5QjWVNXmCsUNUcAvrxQH50UNGa5RA8+dJCDjqYFOS+miOC4Wq1kTLuzEFuOBI" ..
	"8sgqjnbN2SuOg8EsBE7aP5f+uVaayJgux2MI8cjeGKMKyE17zLzFMfMRgs8fhVvPKbO5HZ5dZVxW5Q0mcas7+NF2juSZEECNI1WY" ..
	"dfQaHXIMoXWszuq6sLD232QRDeEzvrpRQj3toLG5hlK6KeM8hH1iQVNkZhKtg+ks5GNR48rumXxdyzJqUawCrZwu4SCYLxB/5t9r" ..
	"fkpMHOJ7U1+sZG6AEOm4Msqnkb8W3Pms28Cc1F8SL0LAIHD8Q3Oq7VQbbRklXl2lx+5FnNcQUybva+wiQSSa4kLnLXzXJbCM/4TS" ..
	"/Qpdqv6HwcAoQ/mqhRN8B4Rb9vpB/EiRIER474SGmbPYBKCXcACMmQN7QzRNzKgE21JQ8Nt0hnIrwTF6iLW7AqG0vZ9U7+gov+Uf" ..
	"BF8iV2cj0ZkMPvX2O0z8PAZxq6sQFWG8A1CD0OeqecJbSdtXRsVRPUJWW4XL9xEGs4G6WSv1EcTG1U0hm1OFdsrDAw5p5f8jf/+s" ..
	"bQ+GO+Oioj21/PIDIsvHUEmLPRExAtH/1z+WNehF3yVyRI25RVV4Jo7MjY5D7bp1l8ZjanZl1wfICdruqA6T5/HxC+Yh6qzLgjOn" ..
	"sycJSqyw8mkrDLUrGPSjJefRCZrI/GblX0dLL+vyvEndtD9FZJc7edkcPRiBeufWaWmAwDSkzGO8/8ZebYvw2zBjY80I2mvmHVtP" ..
	"yPcHJ3cNAs04tDvKfaTbUL41gHpoOz6+E21T0NAlQAQOEqHggqcbw0uhn3ZEZOXB2qdrl8Q7ayiZGot6mPRtQ1oZ+ZA4/HFjUt0E" ..
	"+ie6qdkwPWqBaMuyJ0tmVN5iv+J4uwaBOBzT3Aka3RFauNUWWBYHQHHUvId5wNp+GZa5pNDTvyZ756tJIGeSNpnngTegH+gej016" ..
	"3SPE6yS5MH5hStkzYbe9BKpczomSkUu8xEaWfQJ048ATGXvNrrWrYXTVtX7OT7ErDIaWIOREG/pGt7bWnYVVUjn2zfCNeqVGIYux" ..
	"GE8dPfCJ6QVr+DxD0k+fWS3fem3BVzYojxTSW6t7I9VIrD6Y68Va7PQ1+0stLA4YlsMMVShORCRbHMARJj/ELzzJk3doLsMOFnBf" ..
	"ITZFx5dCiPhIAqHbZBmMDXSs2xDWY9U3636UrUyY6kgklY8WHGZIjPqLCq+37ok7O/R8jvLn94jxsNc7InFMfWivQ9i+VEIHODto" ..
	"Sho8ToGe+W+463uopvnyTbgR6lZLFTtqYht9lrlnDLn7XIGQ9qfDafIZtb2HsC99+lf13mII3K9bKDXCXKmE/UqUFa6KxT4bEMN3" ..
	"h6r+jWSNC6B+uC17qm+WHjz58B6x+dECrb1HlwdtANQtRlp+HLDIw6maCVi0W+1wJ9KjswwX4CbRkRLAKWTcCl7xoKIESDHxgryO" ..
	"ogoBa4uMw+ICNKMPD4+wJJ318a9GL9VelDyl4ElZoU3TySct1jIRgMDMInS0YGCMTQzA3P5henBeq2ym4X0jRWGIufz2KgShAT29" ..
	"2fILEPPYCbqa/JW+zQA2BTBWszwX29i6RQDmqG7wlCDvsm0NRefyhpYIdD+b3HoxCjNnEJWj82D2EvwZx2bEGmD1d/Vf93bxd2em" ..
	"7GJJLvWI7dVYpajk8slkiFy9RXg/BhpzkYg3gkXrVDrTeMJZGwQ2pezsubXryhQuEwLCFATVP7sW4nXiIg0ZQQC/KV12vN2Nvu+T" ..
	"9AScGoG0WXjfKhHdmJKyV1L6aveQFPSPQthU+QK3lHnL0OW9YDtRZhIS+xMnkesHj2ZmeqoAkqEdw8rp2i5Gv65u5opLLgGRWXge" ..
	"S0qXh4ciiBfn9CVghVnycxVRaP7zuJffDoG3eMmYM4JgYLsVYnEYVytPLgAaXYTSX7LamnEO7wK5PvOQgsopk1asuWGbPLwQFBHS" ..
	"OHfXAq9B9EFi/LKbuawmSsTCekTdzDVtPFx1hEfBorNorgbCcskEXAmljk+sMDbRYiNKoF0+z508mMOyjx8zN4T6zwTlnVwDDFRB" ..
	"xWR437s9sVss9onzERYPSjIkciolNFCOdE9GtJWUWjkMft7igofdco4ul7DVwg6dVnD6RNkAc+Jds4n7stg4KGdg9rpOwm+NFgGo" ..
	"DsXiYaWghP1gMiDv9M2K6A2ga4tVshLkVcciZtO/QXfU7a/IxP4LQ4SEQZX1aRQ2BK5K9cJare9FI36e8p3rUA5sM2ezfRwaplmD" ..
	"NxJMWwbefoB/xasvLAc8cKgA1Hh8y/LnCY/PkZqa5gX6MZGnXY+iR5vNT0XoEGrCxPAueZ/bAGqsUpCTYwghWKK+hMT7R+oqg+yH" ..
	"7w6mJV45foqw6di+Szsc/Tj0txQ/G+BI7hj3ijSWfjSjlCTJebPpU4bmOjZaGd6Z56ShhKTIpFyMpjx5A/fBP/CGlXYswyN7OL0j" ..
	"GZ+V8GEA674mxYmR6pQcGCt3padZqO1OT0STNPBepubzFrBqeI/mfyfyoahqaW9702YoRDgGhnWjUAG3ALs2jcD3dZ/lA7tYp28o" ..
	"BKepxypHiY9iKY8ple6ZcDG50ak/Xvt8iaVBeO+2f7nPSTYd0sw2ORZWnyWFWckPl+ii8kBtLoCb0N7VfUMGqpBMNvbj2CP8E7SW" ..
	"qF0T8HYGJnnatAy3Eq1YQ/1YlPqR9sRgssfL+WF0mOkBT8afyphRY4Ub0GYr5n1403Ake2qeF/9SOyCG+0E/7cvg0NC5I4v8bevc" ..
	"rPm8oXJgqZom4wao8B9ssnX260IbPv/WZzIJgb/pFrr3hVUsN6jSS0F4EHI8yJ7mlvk/P8jo0G2buBIkrVVY1PRJ/tCfeVqY4sK1" ..
	"R69V69/5OK5wa9BKovMK7oJJLWX4FgGe4x4Kp1fpnsR3TZ+CsDIa4Il67EnToGSvfOznfhGLkex7uu9a2lpoxlkfTOQCNT65tvsr" ..
	"i+MoTM4Z6oVL9tOGzghJpMhuO4WUJDaBxBDDqckHts5Vn/Twwk19Hw4VegVH/8igtn27r2FUr9dBS73ZKeb2VglNjSh6xF3Ne4mL" ..
	"6KYgEnzkPkRnDfxd5HT7BMXRSXtufjbHZBJBuWlMGOT9lr2LQYbKe2pDePuO+M9zSGZ0VEfO0WSIFCv1mc8dTGvwAZZo6ox64yN8" ..
	"78LptdgdlzXL6KPOUAfRq0arI8aV2HDLGPwNxGqjYr3IQFQBODC1oYOxaOPzJUcxL7FLty5nmVDjWd6eSfAtV4u776qvodCaDsUm" ..
	"3VtCo5dXfovBP0lZAHlQ+iufy8E5/s+U+ZLI7chIsGUlH2KFVH+ZPUp8M+DxltDNEYGJR/vZnxE9h4/PNU9r86vYx8jqfgJFTgeS" ..
	"xB77tbqIll5XdaeBthau4lVxZMbT8BiorYgLoXJeUMCFgw4koVWrRmTywwpFuH5JFec6g3lku2K2e+AlxuotF1LaCdXKtPrQgms7" ..
	"mfG8Pu/2MuVp2KztRMnTtlZKWp0N/0NE7L+OJCFckmUwbX/p8bPPFKu+lAD29ndlyKm4TGZCjFLwy2hKpSexMCwzOPuea1M6s9AZ" ..
	"X7sGeygN2VtHhtPZqCWRPrKjWeuOBMpcNvpgRhvRZA6PQ2jITftuhiXmOO12VKaCnNS60DjOlZqfBllWKgcXXh3ohVJvxk+hbLDk" ..
	"Abg9eo2efoWvRUvR61cfygOLOWlAZUTB2t/dbKBTeDN95j92C1V9kUzwkPSqIf2yVsGLOYuh9ILmK2JVNgyUXqQlQ91CIl1qQ1ag" ..
	"47+T23b5WRBWNki6kgjUApCkozeKV9UmV7qtUmXbddffjWZ2mbUDXAX/IWeGcGoP0mKKBJ9204Tg7HG/X3ZUuyruI7dkBG3jW9X0" ..
	"vcZU/5Vi9kePLYosg57NDfXDWKETDymzrwpsmSInseLgBcKNOFyiDtYHmkOG/R/FwaS5fBJP8SYFNUAYZsnTZ+Xwy6hZu/CgTCo4" ..
	"JTp1mPKXPq+ZInDqXhaKXzGegTzEFtoH1zGD8v/6IEgiDKQYBIMYUWlFd20mNf24+H1tyZ65vWeCZdYND0W99as9Yy9Ox5KOjWvP" ..
	"o9z5NJ2Dub/dJR+x3y7xu+qIsZoqZ/zL297Cj2iGNFmW4yt44aVt/5rdSRHw9eABS2QEoWi4Af5HQ4ipv8/dv5U9OTCH0vgTkcNn" ..
	"dxjXKv1/7rIFIo1ioDrCMKGmoC499oNP1EjGALu/3CTLRKFFZhOQzFdPBCmQz91sJv7pJf0X811b2u2y0TcHmF07Q6YGujn521R+" ..
	"S8W14OjOjZWUWBcy6dGmkGWOjxPSjc2uUguPHsxRgpneiP1YZwPqDuRWwo5RQ0o/hoBdoI/GZhifyGOlGSxRbxI5HEqY4hOiWgsd" ..
	"DmIChdQPvIiftS6mlA3vJxVmDFItVRSyklTDBLHQrE+s/rLhkc74WC3GFChLgCFOeT77Fa2KH289JptuA1IUVGt3z7sb2WOntf5n" ..
	"HuhEtKW0XTQVNOpzG9mp0+n2wVIGETBY8aj21Guk2kRerxQxW/Tfa1ae9a5pNeSg/kw+ENLvbn6PH5e6e2vwADNgQiakW8jbpkqo" ..
	""
local PAYLOAD_P14 =
	"C30MEPH+s601nEVRt73X2sMWzOWay2rIt3P8cGruHkUht76VqoxNRQacXNk7DswzIjsLm/B9QrMcq9tmOnUdCnvDx0Q8BBAEItZE" ..
	"EGj/uDna0/sAPujLc6oKS/u/C22M2fiqCp+l4InOnY4kYQYULeb57zhFKqIXapaAQwVIgl29I+YF0V3CyJBDENQRJ0UYS0KwUufy" ..
	"8zNftmqRDY4aqOKfWRDMP9neoMYzFNbruLaBA5ZZDIBaFEekotJr05IHuCLWd+D8zbwMrNyPGawx/3peoHipCwXV3ChaCSz7IyYK" ..
	"1iL8FtXop3xM3OvheMKjqDffWRV3FZ288fstD6mlUjZz+4S4rPTr6ttW9M9CsLi7jO+/nqgQFaLyYH7yArNqkYIRWXjd01rVVwuz" ..
	"e9ClbpAoOfpWaAWWUYKUCxgEbyIbsMb1IalKIox/na9RQ+rnWIbICa7kFsfFPRUE5ividUZBjafHC/7s7VlSkuOPWd4vARwTZLOV" ..
	"ufkgfgjY5TNVsRltfC5/YQLbp9Y0IjR/5dkcFBHCBKoBxmIHJkXqY7EzumEgzvODn7Nmo7PM/m7ka3dtUm7uD/hE8fp80eWwJOCT" ..
	"MOxumZdxY33k+9LYeI+WM9HXkrM+Q9v0xAffNqYBx2WrFPCpb7y3RZuYUiRS2QLZIUlcPabE+SPdoIannPOyIk1hjDbRRjkO1WU9" ..
	"d8U5K+++l/bV+JJlv/NGJsjcf2IqAH1M0SU0+ZmXfLD0AJYqWA0rObn2ze7hVt89+yHD5FxWQ4KelHNsDXIVPogvP6sxDD/CVimM" ..
	"nsYWX6mqtOD4fOrdlOttPI+20ZxTemuKCQ78/1ivPVPhJJ8+MD9Ua+I1MLsc/9NcvbD07AMUPvl/2ThufC7mz4/Wx73320W4xp76" ..
	"L6rF2FvmG/kyB8u65sz54UwikeHet/1UXsWSIGLGkZJeuWYijmgTPMWxZOtSL5Q9foaquMGvYRJiu9MD7Irgjs2qPA==" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9 .. PAYLOAD_P10 .. PAYLOAD_P11 .. PAYLOAD_P12 .. PAYLOAD_P13 .. PAYLOAD_P14

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
