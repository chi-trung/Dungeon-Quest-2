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
	{ seed = 2231409560, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2239298446, exp = 0, plan = 0, hwid = {} },
	{ seed = 2238816235, exp = 1788089514, plan = 1, hwid = {} }
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
	"82ADyF86FrifrHNQ2w+GFWCGy6gPDomHdSfuzEA1nUhQDnyd8nGQU5pwhyLsXm0l2btmvguPL06YMCzt/IzowPtlkcuYjkoplEjf" ..
	"DcfwayTTOcRuHSUyzOr35BBhESucntVhPmshARI2JAwwc3QOPuGM3eBfQOx2DA0BfFcaYPXmsQjPJYzZO+8d5/4CxcqL8Ycu0MNJ" ..
	"YAPYcuTfh7so1G+h4TcB6CMUEm0BKPEiFRlQ74QbTIAH6EIHZ/MDsaCrXkUm+D/NDHmH0dpdxN5wf8eu57IHRF71nZTyBVd0lWgM" ..
	"mbLtctiOjsBG/fxgeuDx2Mt8BprbMMSO+KnSJ8EJ+G2LNmTMHfiqbrbWZwZ1vCrxFUHnm9CKZbnosShI0Z2qY57J8QgDixnnXcB7" ..
	"VMrBWf8IP/tRMausa78VO88mOTZ1EJ0s4q7lb7bllfFPgIFZzhzo5djPz0f5KqEE/4V6F0wYue5xGXR3jiiUBeWCQHyTWKIgGrMe" ..
	"sYYhs02YgNY+TZNk7oBWZg3ZqfKGAQ+jtoov2yrUkE1qUVHJg2/22sJOuK6dFB+5dfHnSRlW3cLHYNPddnTpyH603LZppeqyTILq" ..
	"kew1qCbIYzSEkdLN8Zy6NAP4jrtJZENpGfuTYaT+/OR/cTeYaQj3zXuiD/7Xp/u4hXH39HOI5eDiyz07aKhURM4jh4pJ3v660kPG" ..
	"Zly+4ib9YZi555yAy21hKLHY+s8Jl8ebyconlOOjY7oENvDS7UmR/6WTlN4njrasUp7ORsmLsLYoZwMI5Crh5OjKlZ61JIIJ0O1h" ..
	"SqXZp54UUb0XTrmFKI3grSP0pQPscjHZdZrzEZxPQneuG90LglSa2Ua5Su4VdWa+9nVZcBxrzWnM/D2VDskOClySKh3TwjEVtMHk" ..
	"pTTg3ClMZk8+RAnZ21+Pox+y4HToyuAZ3Fzh7JIqoSZ0F6OV/XRH2eXB1I6zbF6pqMqFyfP+1CXZQ6lvflrlW+NiICjQZCQFgP1h" ..
	"GPd67ubIeVVUKrnkG0CWXLH4EgrYYnreXSjM7EhXsp3h1ePoZs/T+gib+wqCwgWNBVC9NyEGKoYj8X+Chwu1VpWep4YQItEUepoe" ..
	"djNVArogHxn4FgRjXqfz0/r0GCd3n0VygskzNDPUqekzL8u6cBYmYtK5yMcB+W/9b2OODIXpFdAPUx5Y894K9B3CSNuLXN8dXWXb" ..
	"CMB5nRIJBp+1g8ou13MFlNOYtNZV3xjqEm4qvIt3b2o8e0Qosn4DDDQXqezWgedR3oDTkDXavRNUm8WuemF11FZvM8h4WLHG8ioZ" ..
	"m1JyuAIUs8BVIHdvi0140OyPQ5+e+3fAf1dvQCHlZqRUEzBH4AybyEP5lcmz1gsXC/XMv1mxWK/EarcVrz2e6vYJSPB2ysM3Qagr" ..
	"OPPcXKlhL9mfPsxoF8wWZ4jN1/vdkaPu2YIwYKHSksol4ZCW6Np6hmHlnBeA9KWLtra0Y9OZAnt4FUPMzWT5Fapq+b/6/ZFINn6P" ..
	"oxACO4ZLkp7KjPKUyU2rfBvpZGaYNYgItWS7HD7SOdJ4Vv48byrNCg4fVAx6q+7g1tNlTr6ONE79JgonaC5CPnRTtzLMxeNtLAZ8" ..
	"P/JQ6bVOyhE7XafHBwjShFbwjKE3D18Woa45DbDAZr6OAJ2f1VqQ3tKvQpJ7AI6Fk4D8cOto+iVL4gm7jEqH6Nn8kpKiTrJV3kxN" ..
	"uUr3WOYM4UGDkgNjtIfh8f5ZFYRgNtFEbO/ScenrPvgANxqKIydfctD7vlHetJElNr1wHjm9A7WZogJt4dtYs+PMl2ve3vVPC6+/" ..
	"1qrrAUxQb+LfzHyoDsMk0chVX07O+sKm8LVE8WPOmZSKbv5NmIOAZV+uJwcStBABb5FR9ovA8lLjmR6PSPC+WEsJJQeu05YEaOcP" ..
	"nLlY71lTUaU+x/nECCtmbcFWe6MHG4vL6tCjRnhZZV9JOBNs+TYxnwXwFs4DvN1Cb2eH8XjvcQBuv+DCafykJOpBJiwoyawKUime" ..
	"SuobdabF/Kbz7VqSHUndJgH0GyBiB+cNGO2kRD2NGtctfgOLo1b/FT9OcoVtmiZ9ydnPfh6epxy8b5ctq8MXzHyU7M9kPZ/47y0u" ..
	"PqqhQUKp+vM9ZMcYJM1+8nWLY6amEDMeg0u44ad7s1iOBFVXf4WEY8jxwzqClQ5+S0CWmlDUKja38mw30avOhWSFbrKY5ffbSv8O" ..
	"+TkLekeaNkmM2zvVWu55YL0PlfgBY0iO80Mx0w3xinI//N8FsafmSzi9asv4Yx1rHL/cKLCAGvTFpci+Mi3/FnwDKjhmsJK15KML" ..
	"fyV9AurfzgDgkbB755zVGkBOTgw/8CmbHLsfraRdAQErdrpoNwZ68xtCES36SjYmD0ZsczvNdXABN5A8FqlYLboEfn/et9qxBBad" ..
	"3cOgGnEcqLVOz8Cd/0CQ61/bJnTlPHANz0H/qukDDFm+gj2JUIH7+ZxGT36FDjb8n3QUZqeiQdWU8BPHR4oCAOk92QsVnPRH+77z" ..
	"K/Ku8zxWtdGMjAdd/UXfHxcgbbwuJ0tKR29y1WOIFBsfn4bIjGOEInKFzsfhtbvfORSM4JBGduqkTrLb26MoVq8vwxKfFB8jLttm" ..
	"Uvqc/MFLK2S+6RhZvuMngHDPQa/RTow+F8e2E9LkW298Re7+NS9xJ1N1HGmYAd6mXdrhbXPjXwouHZVFqKgT8O22Dmu8G2KbtFiF" ..
	"Rs00RGh7iXpOHYplMnplcLYTVQj9RQaPjq8o5BfqFACqdSTEJiPL06w/HDlxxk9Y68+3JmetFud1VHGsETnBteDIEKLEjQqm9J9y" ..
	"lwF4vyIFh2G9uqlkQfAfis5K5wprQrsiVnpapuOkHYcm5uh0xjaq5C6bS17B3lEJ0xAtJ/bQPSJNi8SyNhCLaWfIIyxg1/LZ7T0S" ..
	"PRk3Rdmbj7RWCTrJwjL85CkflnvLUgakHgPQ5cuL+mqoBZVik3OvKhBDO7aM9oNE+FPGFYg0z0n+wzA3WcRXvuVD1+oZAK/pVei4" ..
	"SrqOkvw4zHkN1JXAdu41sENIvb3GD030K+3Tg3qkPsE/brOniXXdQPj0YBnAzlzX0aDuLGFiSWkmAdnsoFfFavDLQIjP07fS84Vh" ..
	"3LY6W0Bl3vywi0G9jokiv6cQB5oG6AT4znAK3+I301sQWnXFjgPw0CCjPP4jsd0/EVIakV1J3zShFbHUGXXj8gez9GjydnkvO/O+" ..
	"MPsFROV+cxBhq8Oe9io9d6nQMxkTRya6EfndVzY+789noU4YfW1U0XUznhWozeZihwkOt1fQ2/cPoXopBZVv0JTA+2PPihgk8QJY" ..
	"IgLd5xxDGES2LL6TnH1AWVZfL4xaJ1V8/UOwefd6eyyMEXWW2l/Wz7joKGGEjKtxUugveDVTorpC+zuGC/LNCYFteSqxIpDTOu01" ..
	"s+eJBz5D0MMLcFrXsfeL8I68XpHn3aFJ+NMk/Gy6UQkkHU89FN5pfThWC7NfKpxKP1/9g5ZA0YtZoT5D+jFqtxBK02aVX42nw8hj" ..
	"ihbwNBOWzE4VYps/rarrYRtiGoKxRp3z9VQZ63s/J9uPd4rHY9J8J1G1tP4M8cFE6CWdkr05Fn3XZhMCpOBaUFPZqKq8ZzB799gD" ..
	"ePvmz3DapJ1NYVZaF5raM75t+A0JVIclLfb2F9s2r46z3vDbCLn/4Y1wlzRPB7O0hZ6qGcw5h//Qo2WKbuo9AaNwnqkFgLttACpq" ..
	"3iAwgA5G7bIuKNrHOYYyQFzxpAhULYXRfgX55WuMbZ0dMBvSuWp87AXoQreLaWCDJ1r4I8veMrlxelDeZQHF7d3decJyrnbrFEqg" ..
	"0WLOUzmUir3JHgja0xXQfONWnMyYT612ipNfmDd/vlYNOeKX0WZrB6plbwtbpkaE8L3kzk/ztq3eHWGW9ox1VaBVRlSX3ezRyJw1" ..
	"J6E/1H/7/ob6LJ7D7pBRAdILWxJtFyOEj1bmI1U2g2aCHWwILs7sv98hKV8c5Vbfo871Xslx8Puv0sO1iuv7jjU9Ow1g3SX4wJUj" ..
	"Ogw0gCc/09Pmi8WcwXSsBKdNFpZHpnPawkjlm4+jgg+sih9K+S+3ofsJD2okK0TuXaSz4azpffilK29lpa7P11n4aUQ6cRpX2OY3" ..
	"bzbIJhb+wrAAHzdeCYma8CcpU5wMtNuZXlWa0atTu2Xdy4Cr9k8rwX9aHwtm+6JiVQtddQ9XFxYVLrHnegwrLgllp9kpKSo53ETm" ..
	"u0Pz+nR3uwADfxa1rZ5rdCVFRFA1IHogvteuH8fgcgdQUHqr8jmh+FRQKtyRJIxukU6fh+9gRES2yYNDXAky/53OHrSsvSfi+ryZ" ..
	"Q38iOLbRdQ/hljLClruFOjoL37tiyStsKcSq/tPtGI3msm5BBDKXYLwVDvGD2wZ39QT9dgVlK37MUBr/CHgtsr6WhrH0Ukh9NeQA" ..
	"83tY9B1F8YeozF1D8jEA58593yA1sCkSbBIpOh8pAswB+tTHCBMrobzba/3zihfG6IdBf722gy0EirFGWhddXY6ybf9V426qz6ct" ..
	"VoEEP7NIsoHI8uf4+Bdc4STVkAZvYlG65dwNJ4DrwKC5vgRTAXRJfjlMl1XzgCVeYT9WkoZy4I0lgOMvxU5uY+mOVCMiHKiUovsu" ..
	"9gBeyx+fZSCLDD9ycfWHMVpqJfMN0h5rIeno8TDP5IxoXPsUT6sj1zwsXoEuARxarQ6hlfBHOsmC1CxATRr+cPChD1e5jmUaOXOF" ..
	"kAcAVeQrS1HzRsQ//vS5xAhoRA15HeV5z9XhVTmyBX6M4wGJeab4tiYzEHjdTZwQ3dSVkUbY09+HOOlQDh8kJcr6FC46zjQnlE+L" ..
	"tRYoAxkWyJMG77iIbSXwOzgtwBKToHkXgej7rZ7EeyqW5pjShzii8gPBFPvLkTED40ei9k3aqAQpCvzvztSgaBriGAoqB4lAt/hX" ..
	"x2vh2kVyZD7Y/Fm64RtEPIJPX4655nBQZRU+As6BASTgMN6/YOHD9emMYv0cEFbdEsPkhtJLUrobN2kLbOSzRDqqkgGN1gSwVS++" ..
	"uHlBmH+g5qIJqC63rO3bB7uSKQJEX4+UV8tymfKFhCuM+adlQRzpuk1qdNQFcJW1C7quaBoHYKiVuwxxIej6nwofCBU9zLDSpCmR" ..
	"dWUwYFBMiInTz+PaOMS17ovpF7D/T+8QaNL+7WeaUwX9sPsMnNQLsHaELfzHllRBxkwp3fJ6CmpnJgi9kXAdhiCEl4KycYTtYrqC" ..
	"OxKwdRdW4zr3U65hy3C6qXK4n/0Kl/T39L1PwS0WAXL+NuPdL1YotdOZntf+vtMMSYNtiPO2ArOT0gl8ZZ6GEIm2UhKVygaFa9gu" ..
	"+UC9G8aRsGMmsMb6NOB5vg5llKP8T84bL+cg1aVVcJu1SO1hjiWDyx+PGjclJ9gF2dx8+u2nA8jqw5XPtij/LzG15Ucdk0d9itnt" ..
	"MstBbNUt2UmoR3OOHha7pwVrlOwlev/iVlvjCZp28/eRl6Tenmhu6C5zQCABNFyRwrtxBAAxh2rpp0o2zz4D9dfaFggo8sg5c4Cp" ..
	"0aH3VjMmqf+S2tCsnDFEs8sokfXZR4mIf5T+08ldvUTNrhw5X9QzopJGhILj29QaBQh53ezN1ba7T/5GM++tR6DwukC8kyFZLqCw" ..
	"ELzYv3Ric7WqOtLP+JSMCezZN3rKVBvDqkWkYrdrSqOxx516HS/eJxUMxZLWTmA1RMxITi0eAw51hQvKxnd2VKh9ym5/WgH0QQli" ..
	"pddykR56tIsJWiqKjMcqe4HAkyGgGY/aaGTREaG+E/WyESjDXIurG3iwTmIFodOYx3mhxNuPsUDUuKOTS9ysYrCi/Ob0f0d0JEnV" ..
	"AQ9w5gQCn4P6sxGgj0oRG8Nbz5rfcUIzQ2bUoVlyyX2XoIHpHCrlO57mBqKhYJngqtFUipg12Uw6isOzZHQkLxRTHHnOmrXHri17" ..
	"tu/EF1aPvr+RKNZmz8IaptKsGQ66o8ecbYYj7x8EJ1Udf341A8lu3HjeOa6tvjhZFqa3hjEU7Nbc9SAfGRxc1QRKsKm5uTf/I1AC" ..
	""
local PAYLOAD_P2 =
	"W4CGdSzCrnYrGdTBzklJ2wqtYDreQmFHaKYgCOHS3rtCXwTXcny/CjJqd3dn1/QKPHxy20/rcVOZU+pznUafJWxSIJl1eiqvyiwP" ..
	"gdIsw0QION9OKudTj+fqZjSk4Q7s7qsBDdzfufZ3trge4w6hZNwCdp22UatstA8ApYPysnVzmlHr5T+nF6dOUH7+dD9TTOxcBfkc" ..
	"Ux3qHvUKRrwSjIx2r9wo1fNAKaDsaJKkJ6Z9G97icSA0+kS3x6fnPsz0EBy88wD5g/m0GvHzUcC6S36uewSE+OwEXdpFRC27ae+J" ..
	"y8OWzVEphnunSanfKiPT5k7q0DHWLtKeRUtiEav/WVmkDbxda9lyV4ur+UmNWa8mqOWeUw+5axKQ3cC6nXgrC3o+vGiJsFnQjRkE" ..
	"I9mtgDW/rynU2bKO4H6Gt1ebZqlAl0O+X5tLElZ9DriMgp8Fvk4saajkNOL9ljQaqzGgQpYymTWtrDwFD1GkHwSKZgsSyUDJtAk4" ..
	"dgwLEu8j7fThHvJ1bHrYflyanmCOn1hU4l+i3l+EOYko/heyg0lNvmGm/vmU0kdgYIjb/V+zG9dZL1fnA0Gi+oJi4JGv5W4vnun9" ..
	"9sSEvH1yeVDBmzLOKTxkYb8LCpbd/CM6n491/eQOvOr3majba9CeVSLAPMMrabaHH1X90Qtegs1ZgHDeOSca3MH0wNXrvZvxkdN0" ..
	"H82H/3tdF5LC8eiYuUYQk6ww7DwsWOTiSuaS2kaBJJuinBM0ho4TasiPbU1HoZPm1CB81eo6CEXsnupJykfTOwbcfIP/zpBuu1cM" ..
	"4Mv36EWL+BgbA5mg4ZNG0wm/5kgqdgy5riHRcsVx6xulAAwW/ppCEUrkSgj8PsX14hqg/pfzVbgxcGUW54n2XkxG/EeNuJ6neoG4" ..
	"BM4gIDamvoObsYBrwS5wHNIQVVAxiaPElkAfQWSiXBDiS/ti6SXSmCENKB5P0XNCLo3eVG8s2mk1xgNWrSCQxUXToOmWIlGlArQn" ..
	"4H+Qv/MnuqldFZPOfnOWTXHVJeeKQHXQMXBAklLBpiI5KQkdD4d4PP4Bof7hiw08asB98TFdK6Ouvk8aqzrPhlBn+EoqQRAOh3Pe" ..
	"A70eH7F4V7ymAoNaWVcdhvJztuZLSrIQySEYyfAKU4DjdXXPKoHHHAyU04MyKmpFyafDdFew+knLrjkeCESMmELr6tkYqDPJwm8T" ..
	"m9OTfz+T2npc451PHKQGmEYh9CSDnNqddY7UrSR43UrO3eQuolMIM9naSJfH+pqcau76mLF95TBYhap2VB95jiUp1gY28s90QwuP" ..
	"TgqwIAChB+2QlXQSm+74c+zY9ywYnaXUXYtzOj6iWnN3MZmo7mVco7ZoImRWWpJlRKbjud18yiCpg7bysgGUp3mmOC2ZjIW1l1jL" ..
	"gN7sIUAmdJC+p0k4q3hNV4CZRRWnu8wtEIumTZfA1bGu7SBFq91O0dcS5kpOCeCF9LDR+FvWCE1MG5d0rAnYKCsmLYNoG+hxDZrl" ..
	"yQeDZv8dnZo3P6IoZVujzNHpCf3tg+6pnwL56FHUs7+WTIyiAyNOgvFgUmzyTuin2w9qG7gvTIhKBMWYcW/6m1Zw6kLGP20Rk680" ..
	"A+oijkaH6wfY1O0actm+wDZffE7bcyLvK8RVeK6x7NeYTLUoP6bliQt1CdhJPxbs8WcpJiyGmQ1l0bsATJVF5l6G41XZsowNPvdJ" ..
	"ssw8F1sFUUJVTgcBHMHbaj6iLiwpW9hu+rpfHfkf0IyITg6ufCd5jZXp5D3qDMFh1As7BGg4psoqigm3Ch5XQtpxL4djdzvbLbs3" ..
	"Y/ymYgpD2zhkntEPQF/3HKoZkxz4XPOrWmPtvVADuHmfr/2q6aY21p4zX4wMr9tZvoIngbQRS34d6hQiajhFJDlNh6wOoO5DAhSV" ..
	"yaJGwzem3HwPlRWHsE6Q34SJg70/YlP4h9UIox/hDaBXgavE8LDACz7hj+dK/fyidRMoxBkzdbj1pyIHlT1Lw6dmeBHWlt37vUKF" ..
	"ID2sqYa8ZplWSQ5EMfAJBqbZ/heCMvvzlWqxfWR4QUn5WB3V+V/4HcvWgOu6QICV5qGm7zVAT26jjjUzruCX+VBVgp1BPohf1hox" ..
	"WP5GUhBezI5oZO+kqiK/yMWRj4/GiYLVNXhJ+MSezuZJ5mh7Rhf0BvRrdogaYnOPI3SUvftYbxY3IznRxVVUFdHzwjVwH5/QslLQ" ..
	"DCoOIGPN4Ml9wLqaZ1nfDmYr0ZxHlCQilo2Jb9sfQucdDbkcgTvm9/ClL9tq7/IKbJ3UQAwBxWZ4cS56JLXgaLqHz0t+wqf2/3E4" ..
	"nKZHwY6e1w45ByWnshI1Tfb5By3ik7H1NVKGrfiTc3a8xZz2BXnDb8rIG97YAHceir3L3goa1mDcHLO7zluApSOu9fZv5q0HOLPe" ..
	"K8QKjeMY/rZ1cHp78p/8fZ6C3P3LI22B9v658V+rwD8yQ4b7mccatPagjGBIqhZN/ey2pIZRDHdeG482HJYoD4AHHNS4QwhDEgpS" ..
	"hiiTPmK73yxYbQ4K7AYHkbMqnTnFbaoO1M7+3xbnP2WLh3OzBwxyO4UhyoShbIoQ5rZP5pgeP0OAVq51gpclZeuRMPWqLGdcChtx" ..
	"6dw8p3Ano7c1WwnTfU7VAWtC6hSIY8z17gN0WAHHfKic1CdfVTN7jC1S84r8N4BK4oqsPcYqwmdEHS/6gLuAY6WRsff7POeQXNR6" ..
	"pO75JrvjT0xB+vQNNxLmtzh4/YqnIVj+ixxzu3Tltf/FFwm1BCXRHzpNwMNb55U3/tAoeDbu9RpuqaOvU/xE1OEa5Gm+6reWkaN+" ..
	"pm9BrfvNSRjwMfsc0HS6jTtbJu5n5Yev25L3HdKd6CKApch+axr2cHaT8Rm7g5pr/b4bOJH+Q71Yd1io/lPPsaSvCCEqnFOFuLcV" ..
	"SbPTqhuzt6nfjAZjFhgqbMs2/HpHyQPUlp5v+C+lGXpK59c79CUHcLxLySjU0ilxzJSo4OCKl/rsCs6un/+g8qk+lUmhLN8sQHae" ..
	"IvqwmP5UWlKa+RmmQTMnN/YPtUqGQL5At/Bb2owz3uTNkHogwOlyTuEX4Kof2PT0FGWkbcHoCPclmlbhgXOL81ACi1nMMDWJOD0C" ..
	"TacNW63sNzuR7oB7cNalS4IhyaxAXUO4Ic1dt0Dd5K8dzA+rj5nUGG0Zdn5eYhLfIi7+EAOP5BfEakdyIIZ/0D+dWYCAqBugPgvr" ..
	"R5z4ZoJJJucVEfVrPRmBfH8Lm3sIgGOYRHlZO3Vnhu2updSfjRJSA1+Dgv179tr2BhjdgIFIwbAqHLrcGswuAqO2KCrV5vstTZQQ" ..
	"glAcTqdaI6KpeiG1oH2+w7iC6DaQRplpZG7gZM/dTnZ2NAPzrt0wzobY+B0uA4l50trWoQRBUqH5bYGEXH0kjvLJkGZzKFraNW4h" ..
	"CmQjUDVZegNdrQlfd5HwWDrhOMYbb9UJBmavw2EEgjo1T8n9+Uk/PsMqmYnLHK8vtOWIKw1u1hUNcU8MJJw2lNtoArtxgLlrz0kf" ..
	"4sPu2oq0ZPLrnaa7pk9sDYwU6gPzcPZPyVOj9vZy2ZontQj1nFeC8LHv2SmxGMitg490b9SOOJM3IsiSDKrBTtT4QtxcVyS+4rLk" ..
	"E31K47MFpYbPjD9PNplBiAENBC9JKOcBM1CcYYh84euvtQv9g2bavjCTndWxx/UISkkNvdTqPguD0wSv+swo/LZhbgWFcdGS7cQP" ..
	"3SFLIpb4dFKtWa/dL47B8f9788FUXHR4ekkVqRUv6q/2x06+9FMEucUtAiAt56A0GR3z//0jdwsqvde4Bakj2f/W3qyCmEXxU2LV" ..
	"MpngU1HB1nKzoIWd1M70h4k4qML2lXsecal+dOKMeZ9jbI22LRBH0PyC212IqKqqzaWrcZxMb8XviaaWHnrlSCM0YA1HobfFhRzp" ..
	"bH/Ux/IrOnPNZKhNuY40tkIiaXWs5sMV/F5nAWYJvU35WvTmnZ6pA94ga0Nz7kWsIuYcrmJD4N4yjiE5In623PdnvoO8Kg7gvwh2" ..
	"kY3TNYqnYQcZ9trTqPE6Vh+PbRjiabNasWZyNpBFiv9iFdFoivi8brNXgUCgVjx1VcOAs+eXvZpBBX/EaTjVb/NPRREG0OvRqVmc" ..
	"CblA9rEc8cdmkZqZz+1q+wxUgPOuh+wWQ4MjgM7W6bSNjuPFIcjxxOeIPBLBcFc9ZTN2wdlJ/uY+aLZW2ChyjJeIcD7EGoFFhCis" ..
	"q6oiMLt6TWN7G0LWnrSmGctScrAwlUdlBznBqSuCjJMXcShDRitdsDQTdqDYnr6J+l41ZMoDkraJP2sckXgf34XVmcYuCPpTcj9E" ..
	"+3jawCliVqRdUQ9qeOrrw5+o3V0SOzM3k3iKgysSRLyrHKtZgaooDh20aEr6s1HqnoA65yrGCDEmOVuQMCyVPQoTliJBdzVdbVkc" ..
	"UVyu2lOpA9pNw65RTmmgNEsgzAiIcTUCyibN3RbicFl9OjvI87dnVwwcLap5lnNhtW59W/Hi44ajMgJZfGDMN0QcfFkiBhnScLn9" ..
	"3y6MfIR6R9n2xLq/VaFecvpwSOv1lOGneX0kDhGF1XYF4Tc9xVDBoVfuF3twZ2hxYUU/cDnq0+IEoii6QabE/k+IAqmJ3DVEPncE" ..
	"NlBRc1AHGQhQCQQgakhIQzfbXHggYGh/NwZVknYOdd5RBuR2cFZngy0jaVSUU9sqDbaFHbCd9RJMAC+1GKMHD+Xt79foE/s4vnQg" ..
	"JkdLyIl2z8f7SGei2XeaYWLJdXCFMdWVHyw1uIGiBfzzYCDQIT6sXnM6RQ69/+5YHgqw+bSXO/Foeb5XoKwsGCbUuNTPBDTbsZW2" ..
	"ZdbSv2/xNFbuehaAIiZi7bQg3weBfWwD2bVGLX+KtlDbotkAEQGv2SP3cyXq9VbbWfmXqbn5+9zDnjtL9hXyBGP1ZNF8eCDs/dzz" ..
	"tcky2gOVhLZe7fTYLja2bnNjpjQKAgPgcpWlNJkUjnuNbnkuLx4dT45acVtn2UIpR4k3sgURHOByvTum8M83fcrQZCtHzYB/nWT3" ..
	"uEhRwoOPq/36axHqLXvdwjgcONOhlN91zNC0Mmp8D7UCrXzYfhx08KjTnYSJ6gD+XrWo14pUAmz4FKWVSpt5ySjH9r7QVMNjsPB7" ..
	"O0P8rYXl86oiM3YOOVeIKqAfVF/YljqZqXkYF5sCd3LOjBij3jR+RSaT27U/EQoWdFertpj5yayJBgZzyLPtmhnMKWpfLE1hDJqh" ..
	"VmkuDsU/AIiogGqVCLBJKXXB3h1N5LnwsL8H6HQ6UaNzAxID6wGvFc485TO/4+8G6kFDQNbIqyma1s9EwB2MasodCouk/IQE0OT+" ..
	"b8zpj2DAKxABxSy1mqpGbKNxr5Ak116Im1xnELhOakRbtVLCccIYznbHaTBSGAckBsE2ul01F+QC4GFd21bxw8XHizjxNHuJGjKC" ..
	"f1rtEq5MdlOAaU7TsdARiPKellK7kl8l34XZ2cMA3bm33rAtGvk+Tx6Q3X89sz+HnDFUoAlExWHoWQGQ2CZLctnyGPQd6j3mHBsB" ..
	"wkM+rXZ/fqsqzZ7WTYQlwdfJfnaFeazIlDHVAjfN2u/4KCXE71ULABKfo7MfoFHw3/NTb3b4jb0bTQFcsIrrasW7w19bX1hOCIBL" ..
	"R6E5SPusRmylJ7ptAuT3+nRDZJpejLQf5MYL+hC3zfdRk39Yz7G2Ryf9cTNZgFKoXaJz7k7lN/Xyb4TZjAsPL1TnrtnRs+lNNNtK" ..
	"66acdvvBcKG1aonaZ5bybT558T+z1QHbLCvonrCGXLHHkVSe4dhihgtFwcnBACOlxVCB8lFJFDgc2JdGAIddxZeo4t6uIgk8gE0a" ..
	"WCxC8twZUC35xiNrLjZGpK7vtXb0h+CqfrtRT0gyrHO5+kAr6NBUcMuRAdHoPWZm0I6BEeX9Tbie/zQdSJcxLGCa0Hcog0tKRBWW" ..
	"Ko7jaUoDgcpPfwospsPnRTT4CTNgBIPvjBYaKVt7TznZgMcc7zwHTV514ApD6Q5Aoif+e1kSMm0TwW7nqAaJMTPSu4TgZAAYEt8p" ..
	""
local PAYLOAD_P3 =
	"6yFY8i5hxR1x3JzcYUvKkNQgKlryvAbQN1lrOABvMUbmKm2hehVlKKiV8NNETMMw0+UZLER0CrU0YWZpOXN7KU60X8r8n7nStnVn" ..
	"JxEcTUwTCYf2mSCdxIgCqKjoJfeziSJJD+VhkokuPTfPoli3Vvdoebohw97XpejWuVneWkH7OGgMtM9he2iNY1XWVvzSk/CZBvkf" ..
	"/PjtoYouUHN586aiuyfrgLNi4yglU/Ez1Lt8cDtO55rUuZr9yRD5baSfHsgFDntVKZAzPts/hkj2Wu8eloXYinwYP0YQ+nzs4Tgu" ..
	"eINe4HnmJFjXKQ5R4TE9Pn4WoEX3j/1rL+uH43GyAdC6IDpuqk3ae84zqtrjU/icyi7yUax3aRwhtNefX9cw30gpU4Mz2P1RJyqf" ..
	"VQpxwJ6+maWbYTzfIGo2XcVrF5rHUldkJiUEupEqS3GTWOF0BnGiJelTHjdn23xVGLOG10aKP4Nx7vVMfaFGoUbhDmctXeUlGXQg" ..
	"ix8eRoDFrZlUj3htC7/toIIvqUq+7otdJ9LS4YOuWVB89UKxfEK1s82Cn/l1nUn15N8AST0Zww7PfvuuxuP4Jgk/yoIZQ8sb91eS" ..
	"KgBnHk3uu0Jdby1CXEuFytanp8PDcz9VRCtCXIaR32LrtC+xRTq+Iyr/jx+906lgcRnVTyRn2SK4t4H+dWIjHJNP40A3X6Pw+UlY" ..
	"eOCUqjUB/Xh7aIShdyOVbWHlOKbm8q4S9D+4FnwMxNfEcn5+FVJBDBkvObl4Q+NZY6qn0FWumk2Qg5pcdXjgnd+D9NES1mNQp+yg" ..
	"Sk2C2KhrkXZHAE3nksQYwTJm4rXsexqXKrjqQ1DbO+nHR26cRjwv8o13sQE/TMJfR4wX+NxVQk5O+0/Gv2Sx0gfoilaXHQAdZrP+" ..
	"oU7Gc+zQqQII8lk93MftjkB+RHDJXYc8qBgdRaYv77EY89fNLsDhUqXsKFlrpIJuo7vdU6OrKgk0ypipiFfH16r3XAperhjnzk9p" ..
	"PkbpflFLjEETsZvw3jTYM+Uj8C5af6IomPHqlTHB//4wVGau1CYnNgPyRFOxTCmJwgvWaySLL9t5+e9mVBM7sUJf41KT62Qlltbo" ..
	"9J4Fm0A7HKna7LWlwgp3S5iMRUHMR1pxra/cvgcy6JVN4PQtx+U3LcuY9eZf7BexMS2VDG8F7uXO3hH2evmJtu6D2pofWoLlEFzb" ..
	"DP8xyk2SfHvQxgE6ZdPlXExBL4jR1k5qCEKU22Ngas33TH0/1vAjcmmgozjkt2n1h+Zy1A3Ozo0uXU0YNS6NAxY9PmT/WCgs2z19" ..
	"eaAdwhYB/ObqqBi3pVup//YWIHcmzwwTamWcQgA0PqW3mipAh9ftaOe0G3ZZ9Dec2jPT3MuK+clzr3EPalIHMTFd3C1hZRWeKmeo" ..
	"agxViZ55fW4k9dWNIgaiAt5DMHYWV0pI104r9NAFBP1VFG7g/vlJSYEHfLM76kiTo2TRIc95OeDciUFfBZSwsoo/2NHCNwSIhVUF" ..
	"o4gk7Dhyk40foC22fa6pxh8t5QhP+CNZnLej4uPaV97a/Hq82KiJITI9D5xDRpYCRuj5DICGydxxM7o8jtiwG9ubJYzTvdsSsh6+" ..
	"N7jLKZUDW+IMxNwfIxd3xEKxaw3ASEje3OTXbVujEPJp8lmOn+FZI/N9wF9wSWg+Z9jTnCJi8oeMPcfEgTRmM+LzgUGjWiai4EK9" ..
	"a5LU/9oJVL/RT+ov5A6Xpj0OGY7wKKzoQjiDY9WsmZpHwGTh/gijGohrKAoqPTt/NX4dQAS1wzeMfqoh6rM5TnC62CRy1QDljFTE" ..
	"1HFiJKlBtQlrNg2Px9vcJZ62YLzlWLFVW9xBkUaRQaAZBxEctivCtDUUTAgHpgJglHtFzQgVTliXetF4dZbya3uIdsQh/OqDNiPi" ..
	"kRk0ppHqYEzkF6l07L1j1KYS4ZIL8oHLbamA+169hOOouSxF3CeN+O+/LXQuUIyR6weV2x09BnWUu1f3o3OzGpFEudHjcOIJtaC5" ..
	"bABdgKcNnqWt8g3w2OHNbC4VcX01nXWtClGBRPY2yh1CCRqwH3b6w9fNEW1gy1nMcwmjQ0TmREKj2W/6rWWio50kEqzlZhu/B5FW" ..
	"hhgEJ8HsC4UXvpkl7eBU0aQ57h9VTim9kOzl4gRHSlwhnyDQhLSs43GC6wfkodacbCD7QW+k5nh7es6M3Q0LOh+FK1UpQlT/2mHs" ..
	"HEf4t7sbxipX8+azc2Ofpgpc4kWf5a3NO53h0Vjxwm+nPHaIqJ0mhtphxu+eRz+WVXHahvgl4SXYLvTiBHaivci0uBEVjkaQfQcE" ..
	"DEVm0ihY3NKPiaxSRGlir+wP6diH+lfcKrbJLx2rweK0AhoFcoaB2O2e+bjFSbur1SqKDwSRvn/2DQEAIxMNZ8rG5UzSoruwulTF" ..
	"Zd0FULhwg2De7kBuZ0jNUZSyTRzvX1qelWwkBle2rj/f27+Ijw9mJeL6NpIOTF9Ee3zkZiTXZQHUpNe6eCf6S1KTLbPVMZ2oIxhI" ..
	"W1awC0CZOVjODKwypCa/xfhW/UOF/KU2iGctAr32cBjC6mwhuq68lEJpqd3d0EKx8mEpEUQZBv14gHFy6xq275oQf3VohBPfbp/l" ..
	"FjSh7HDDG6zZaMo79IpVPMExsAOcHhVlssakTCg1J0y5nHar0pPVWP34/mfLohVnuTXzKrYNGhGIw4kgW4yF9VSjx0ekhqoV41b2" ..
	"K8Jq3CSs+KMYP13DbRxVltMIyUjrE7P7eGR6YmSVQZdznr+qjpopga1mskcsSPZyYE8hFIemitDYRrpSH79p78FQHUUDnbjsHjU3" ..
	"yraaEH+kcparJcznkW7O5fokeSFhvDdMm5WstS+2OjMATY38bjvflmSDQCqpYG1WOkJdkU3zZjTeKHZHRu6XWiaEIRFzdc9t/IGH" ..
	"CwJ2cQdO1Igyvlgk80xQFFDaG8py4D5YfTJE+4zIAB/rg9eTSq4xNTHStHP7LVKI0EAODzx11bA55MWvYAxZwOWvVeN4uCu5n6rq" ..
	"dwnKvlOpWz3BJFD9I7b+luui0Br3WzsUCyWPRJNuZtTQYX4UA6SvL6QOvp4mbOwD1SFWXYCzJhar2cGeaWrsUIV+jK8u9JQr/R0O" ..
	"C7dfyT97XmrxwgbFUm6LOStmhdfb+Hq8TahNW+Aea1ZwhaO6JcenaWaBEyaucY8FCARizBcBmKZvABoXZnkRnxT9RaSvqLvqxHVp" ..
	"vY9Q4sNNck+ena3HdbdKK9Ezb80AP5EpNKHBspMyUHy3pf7iW76Fj2tJZ84QWrMfwVyfbz15rTQriu8tJi7nSgaqfIWLVqHzOGVW" ..
	"7E52b8k6qXKT0tlmMDzSopPw1zMkkupI8sBqCvU2q7dLB9BEhXiDswTStB269iDwLnoy3jUt1z1mg8il40ElnD6z7EO/d0P8jux6" ..
	"R+ceNFwPUlsQ0+GSnSRdA8wsj/Dv1Kc5R22ikSrklTaKZiF87quN/nhobh5NwIeZ7tvVml4y6KC5p4ddDShSwYz9jgG41V61kowb" ..
	"xPXYL5htkTIpm8OLnLZfCC0PgeIXcGYlRQJ5Z7aILrGSN++t401wHgQAldKwGSPwV8JoXNPI4JmarqFJDHo/8aPJ7jCd3Qm8vhJ3" ..
	"+mDYW8nftJBwYwfmrvPCZth8W6bYo2DudxdQ+JR6C6oxIMNEz97R9m5iXnFUXn2V4Q8t7CUyc/VCU3hKdzQBKiePlh0Bg+Vs9jFm" ..
	"hgtVBGErb+t9XS+qQhgxO/nOm9+8H/nV3Vll2sPosqVlcrM1Ua6i9yBCRD17eXoYHQuHopWPJn2aR++/EBcdW0TyZ6HjOmC8rJRP" ..
	"Z8AaIFIU6jzzsC280Mhc8g+D6uuuRrHsBYTbC+X5kXT43783wMFiDY4yeNDv1QcNySCKZoja/9YfG8OfEwb9affTmY+fjVRAnKxD" ..
	"3vTuLcsyAT2LdVVe2VWfRx6SElhvK9mMIqeUFK5EEfS4Aa4gRtk5f3fsoygdrGw+6Z5Ma19dQczklD8TjQDMqoQVSFCWaruvZKbu" ..
	"Iq3AGwSuFcOSrDRAT1kLOEAIEQwxKA6OJdtj960fGb2Of9NWbpjjEsgyNgu6regKFxxIK2XRcAfcy4k6/AfQHC7nYnatpz03GiPL" ..
	"pGjOqwhu8VSx4wVxP7r/HLsuisJYYBrCaG49HT0o8FxTu3Jl2wuKek9pGfm/QTTAIXK1Ad8kZt83qOCeKZD8wWZZkGzUqmuZNufO" ..
	"YkEOl9UoHX2vVqDW38apirsv0NNmL7lA4FFuuYb3JblPQJmZ+oERTCgvFCvA9BNxpZ4QikLO4IjDF6f2NYkLZLMBpKTFPm+9TfuV" ..
	"My0WsuP52kt9CPa+oisSJaQ3ML6vPG0Ta82yP5j9s5TyDh3mLRGBaXk+DfQGwHJB9r3nGNz1ph53VvsT/9nvbSuecGU+Ik5dsf8a" ..
	"iQe6A34WZQCD7VhN533ylENjitoy7muZYdmAmOxNVnWBIy469yGJOHdKx+/JfEZLRWmz5g/bxS+lYeKJVJnnEXHxM/Zyc5Zmkuol" ..
	"mCh3c7cJUceJy13ThLaSg88ITlpdRBkUqgVZM/YI1Hh1oAf8LFwgg8KRA1GtOt0MsTWP/3vYBHSZusTs8YB5rq4XER3D7nADlPIJ" ..
	"RBGOle/D+S1V5aJz04n4uuzhuugJ/F0aNCqmWkjBqPleT4pjODy8M31tTInE9xejRI5aykfVX1nIzdCm9BBNMfWqxUKtqDHG5eaf" ..
	"dGWpKw8NioSXgkUDRLMealDq7J4VHw9ERXZGrE6hwwT0tqgnrCYMOmcIFeqe/d6b9c5DcBX50ptBinI6kqKJbNa6p+lG0el9l5Pp" ..
	"4gqgchpV6fzzgJ6j7ucqQSHPZfO1WMPurhis2vLODwp7/y7fdo/WlH2KLTbLLHtuSAe3ZD/PxSc5TyxwPPmUVi2FWCKxZ/WRY317" ..
	"VkWoXttOIvAb6pm5UZ8NW0MLExSOyPW3jiy77JbMLYgShiZOa+kRDEz08ub11JQVlHXZ8jjbsC7WyHJDaa+Ud4TpCVQtkdVvss5C" ..
	"XXWhiYQRX/JWL0Xv0Ow/cJQ1uW/SMkma8af+/WJdrS4jKoUWemSW4kpap8bdSZWfbxDoLbPKysTJ1qGBpnjjqguGD56vKAp0sTDy" ..
	"5EsijdLYBoDQOKrS/yVUO6udSBOWedfT8eU3il80JubmSOQ21hvZf8WlX28coFQnQo97V8UjmcNM4oU0cKj9ONoxCKe1wax4dogg" ..
	"AUAQ4qb3MS2R4+LV3dSgoi/dzIXbZc3MiaXIEzepgyMrT8a7p56FvzyfEaEI+0F7uwiAEb8RORhtfG/w9mMg/15IFmO0+eu8fng4" ..
	"W6QLmZwkaRD0OR2h9oRt3eJkEZ9XTDjUHO24+rDTfnNnFp3l96gTLPBoDI0p5oOsZEREqwMHjP5AZOXxgOsEgPv1L4gFHCzwGq40" ..
	"knolbBdJuNdzjsSrnpSllQkNejn087CRKQ6KRjjGKJzT0Ylknh3J6wl/3LUph/OhvjoPqXdI/pJvpXc1YLVwtcZOqcy390uynsr3" ..
	"mR0H8HdBq6hh5UuCZBhsHknJdeh3h8BVJQx3jbYwpVzv93qxi4kPQbJuNJH2tzUudLQHTja588H23on/xFOm+LRLD/OMk7TcYS93" ..
	"ZsKGankEv5G/BVa2sA2UJ+C/70KWagjlEMZI0f9HRsEWiszuY07ehC2tHon02DpVAd5+mOkFgLGBJDh7XGt5U3aw0q+RZKw4JNA7" ..
	"2rFrQMiDWQVuFy5M53KO/3ljeDHMhscmQMVdL/g1yf2O4f4YgCJlG529v5WIYVVD6Bgqr8g7aQTZZfsYGaxEbkfe1l4xZqLDQCvs" ..
	"zDU/BE2IO58o4rEGefRKqdO1ISaPtyAy7t7d2qKQgoRXpZebZvzer3FGvqTsDNcekSK/6RKzlghf9rQfGDfbShAYJ8mWY8ppRN3i" ..
	"fJ6pCQ5AcQfA4UV1ezUxmKV2yQOyqkrcfwJhTQGpKjxK8f0eT/TbvNz1mVq9vpHEnKRXsJYPHBTiNKTcWQm4zGNYUG3yj8VHkKjI" ..
	""
local PAYLOAD_P4 =
	"2yn39x4cy5D7c8TSfcNCORUtgzgvt489Wj07olr7XC5dwZ8ck2CCtgrMrjyK5tXwUYAX3+HvwKqtBr+qKSibjUlYhi0mpZTIDdVC" ..
	"rDPD2J/ShM2TulJ+5NEqciYquAWQGH6+AZe2kXlLHrq0308eoL303tSb6KvMiNOW97hE5dTQGNZRmdwBG/N057lYfxSLWAAuwvID" ..
	"q9V+Zs/koEIT9whTpMKr7LQbrSHkKkvyKGHoteM0c1eS4wNbZNUozTqQkrmQ5HoifYAgHp/Zukmi6TYFF00MQbIa8Kite4XntGXj" ..
	"I6iyGsA6tObv2nJIVN7el0d+brZzCyW0+75FPgSbLlBOsz7XgkBoEcvCGlPhLjJxdopcA9aSxsNn1S8cnTgtjMSKoiWiQZfldps8" ..
	"yCfuCww+4pt5Tku0mQItZze4GakmlmCm15HJaAx6pFbQ632dlxDgx3NlFhIIMDSJ//2BFRYAAqfMSDd7v2v2oLjqk69cGUFi+XCU" ..
	"udRzx/FkEucjoTnrJzag7MALZ2yx7XG59jF9Q1h5J0dEM5ASbbeNanhgMRD8kDlS+WT6kz0S6wF8mXGSFWqBg41DDIvsPXCWlpAd" ..
	"WSvpvAeNIgzNbdZmt05FeSHZ2R94snuJf5uTYtf6K2vM0JE71CuhXYHVJiehWmtbE6+c6wHXdckSEPdN3KCbetYOGBvvnu21D5A+" ..
	"fvJBG4jO9AsYK1/QxshLxb63cImYkGxYfRPIlcYKIkk7TVRVJ6HSXx1VL54eO3J3ZHjTA02cqtBahymVi4ChUbDALXXA3fCFF1CD" ..
	"d813kWZ19HCmDbV9wD2JxDuG40QaZLA4CQgUQY7ENKGb5JvQlhnGRU0xcf4KblyqNqlyhFWB40jKombS63oUuTDXPfw79HgMmRgn" ..
	"vAU+NsVrQNlszjc62IBJN7ANOTrsaabddrn2rZ4vRM8cOogLafKWDGhtNfgL8/CQu22mWzPgrjhx9CUxcAHFwqsccrWv6p++vp6B" ..
	"AQDXUTg4AKE7EeRNe3wMqhONpYeG/Wxpe6tR8waKftbZQ3kgqL3Yq3l3Vx52FLvG3akTwLr99fvkjWxZJmhgPurtjZAB2fxdTufZ" ..
	"TJQTZ6DJ9grUlfOCCwF41DN11Mcgpq7mk3b11GIBKA7Jb4LNdbn3bzBhBICamjFCYvHgRs4T8QnFZmXeljBz2Oq19Kw45KbdbURp" ..
	"Lm8V088lu7ATUh6n608vIx9DA2ulV/dIt7VRymsajIsH98mxNd1O6py3ufOPQ9rTIGVoe5mVBAN6/5iYebJ+rJc8n5PSWJLlUcX0" ..
	"pOgGyL1HGruw96W1ZldHlN2TyOUfWjhogQbd8aKaIob7JzcI+0YaM4KsaoB3qMXCKMeUhR/gzBFKk8mCrRrCN6+dztew6/Mq2eA7" ..
	"KUzo0Dok05aNnVmIrKiXSsQuuXw4Bf3BfWQHJoBeWuo0BBg7WAHWv+QvpKqFCTA0x/rQIrsoCrWEZvtlQM7zIAH4ww9C3APMSAN9" ..
	"MMg1IX97rfLlXfd7LkdISmCKmiB5V07JFsQMCqr6+s+KDciwF1Oq+Ru5GviAh9LIkaCoh0+vtb7BYT5pZGf64rHqc8P3J0cMSXGX" ..
	"tpSBW337zYB8orWvOXszxllrrZ6iQcr43OV5/aQBmwKHpV16FhvzD4X3E2jUoxChf+Ox22GUHkLxTlFUC6Tw2TigNUayZrSwz1G7" ..
	"Yey68YofExIABoaA2hOciMp3+FJsGzQuOLPZUfcrm2ujuqXZVnBREgGl8n1Ooh5/OlFVRCZe7+HAftAKCaNAqQrtxprpS8ogOOs8" ..
	"/QjxDEwb6dNre0aMj0IHlndaQH51A7f2de99vZM2MGib+A+1nW8U8fVOhAQhsoLyzi9tL8McCk4BTBJ6Viy7m39GlX/FDVSra0w8" ..
	"SYbtXX/nd6GN56vDRYtRLYjL9Aj4mxoGw7Ids57glhNFwSiPqGs+b4kfKCHi1YsXUDA5v8i+zlbagg6uhLzD+7TmfFGvrc7lRWlE" ..
	"9wHN7W77t3zP/YJQ9IP/vxjWbuz2nAa8cxUFAbt8NvgrzQDtaGe2LfgwXSJGGZQag1j4APohG7yeKFTtIKU/q5IU9ED3kicSscTz" ..
	"84IhCSXepb2f7fDOIsVBFVXjTxjBtnqt4tY3XLSsgWcFmmxseFhXGEEoAI0PefuMzDYRvx56X7Na6OxY9Ms1if0NYt3cXQQ/LcI/" ..
	"5ncqi7ukJr4XVZim0z9ctIeSg2NtNoy0Yvqe0SfNWjNHW6E8HGw8S+oU7bO0qoKCXBNk/lDTNCYZYd46BLsCPHcbs3JZAlvsApeK" ..
	"lRCK82nQUo3W03MbHYIDqecKsOl12VqscoJ0YWUFxLgPG0rxeGR8xsHx8aRYJuJjirWmKE6nTeKas8IbzEDENvywRtEoeoPDvMMS" ..
	"gVsuEGixX5dMZeSxPMYaFfP/rGbNwHe7JUfTSpzvDRHVci+w6Z0mIYLaForb1QTzAKDwdMXEDxYoVMHkZMIxbeIUyqtDLkAwkCl1" ..
	"cftuymk+ji4/XDLtErBWQaTo5HGbkvcl2mCB7lGsNOmmBDCDxJdsx7jdlbLH1IJvRs0LHUJkkRGiWtOwDFG+GxjsGHvUXkBQKuQU" ..
	"KdntGVUuvHEJdweyAShyfitsOoUGN2Nybofs+HRIfrZgEPEKBDI0/JZ5LHyLBUKFwz/AEKOLl0kYDPadRRgYxTCdDukPkpAip6v2" ..
	"I5tQJEqbXO+4BwSaUbWd5li/FeTJfopYKNQ0YH1+ocP2ReiT7DTDzcjVcPHR/Ft9TwYinYZLT8d79tQb0kFwvV8b3gJ2L31YeCFr" ..
	"ieTEK4SOIG8kh1SBhaWQKmXyQ1DUCkTCN70hA7Iqjh/A/VfxnIsnBEYrsShcA0DtbiwMrPP1dfqvkQDnR+ohCPYD6wXEHOCFpFzW" ..
	"ltgUsMc0dpj+eO2CaB4yAH/bwjZt1a5tE3hXLiHNW19jOMzC8jfpzBhyUe6EVeKbLYjlauWpYhhB/YtAwt1VJ7XR6R5X8v+3L9yG" ..
	"dOE7nG8QfUfiO9XciVRJ/tKFCIa6dgq+sdFOTQMJc2hXTKA8yy5mzgu47l/Aa/coFgP8ZMrmYcBapAP5/UwjRFFXFecl4m6Q1YPq" ..
	"sYv9D2Dr6pfJVYwpQxJUw6q/HpykSw/xvq35Wic6F28hWaSnSjTTet2J6pSz4qG7RJSMhRp6CrDjMIoSanuMC4cIxn1d2n7E8zCx" ..
	"kT4ROM6zHTsD9FPQUZvg1udrbZTJuBQUsl32V+wg7mJoJNZyEzCUFZjeMVB3ZahMgHcX+Ro0taVbdfL7qjaqwam+ZxDVS51wFivl" ..
	"vn+8P+kf/BpUT7mg/lM9LrLHlwKTSLtL8b6w8QA+LiffeIgOaZfat78hE7jBEqApsYgh3ljaGXtT5V+0yJ0VdpPtdG8VZSVM4RkG" ..
	"jDuCC4Z1OKr/O6WHph/62tyouN5ekgijFRICnF43l7YU+6juzHhbBYBOgf4eMjY/DqnXLQzN4rPcsfRMk5Ri9KJ1Ew9Rcd4jJ508" ..
	"+uEkxhBHb5rzMhM9olbhQZavOay0SO8MpHGwADU1tXIfWe35DA4qQRDOikvFZNoQ3WPfAO5FQl6sPM6RYKcBegYkri/DCZUTNS7E" ..
	"ossZCWDDfK2f+1GthYf7XFBx5CKzp9vKQbeWG2HbO1lmSHtlDl5wergwhVsSpCGG3FdXUr2yEXSv3//B6IO9/FeI94cdvXt/5pbf" ..
	"q8RdfdWbglhtBl7VKXyMEtlWusBIYRJC0Cwog8LdL0Mvxv4NOZX2en4Sg+EVtu9xMugCOAKI/R5QysrRBfVtIy+rYkhXEX+G/UZJ" ..
	"+84TOT27b5pLJiO/SXEA1Z28R+n91ReuMYnvmR0RokFUqH1iw4CNEwDNLLUYJ4KJ+QPX5yev/0hzECyi/jsQ5keGI1fsaAeLcX+B" ..
	"wp8BD0tA8mdrb3F+/JADdYPPln9PR5zn2uQA5s4NdijFJjEelOBMmZ8bU/8OVMvzGIUAzjAHeclL34X2sQg3z2ZC6HPsqoGyEkOh" ..
	"ZGqeJIQUFXC4OAXiRSw4U4ZXaT+flvvZgrSa60AAUn1SV0j5MfKTuDJLBmQWoHXz2DvZGjau6PS/A9Xlx5HCOkk1klpwPxQGDdaY" ..
	"awJI+wxFBZBn2r3HCgrpq7FY0PV31f++6ahtZax6d3MoVElarT7qRkHGFeoS34Zd5hobl7POWEzVrpDd35tVhVAbgvsc5aNVjEua" ..
	"/cruHEIabgnLWYafzZhWF4tG/K8bonOX6lQyFI9hOr9Nc/A0Gpdyyfo0PvFT7YFdDT7eJiuyUcVQ0S2wbv/ik4uDiZ1eUvtjohJv" ..
	"mJRXD3v/7QrsuxvK0nXx+1v5pGvN3OYeuTxGX2aQvp44oKqLQTXrtO069WDkmWWghZ8zZdJJv3GQh1NsPkklNmmBUIKYrLMIB7Fi" ..
	"7iwzakjo3wWD32TVSfEPtloQ41iC+4U2XWrmdEAqEPPHg87SPNXmIMQahqQJPmU5e5JhsKTffTlxwMMjvCpOWErzvRQ+AsoK2ztq" ..
	"RJgqcZTZLk2LrLETtdNNHUdUXnwm517zyWVirOEV/qY0iv/MN7qIgh0zXpNL+z03HxSYXNElygaJl+H8pAJ63sHMQsqFl18K+tW1" ..
	"kS6Rd+f+eRNlCSmFUBg/Nj2Qcnzl8YVvxR7SvT3vrldCp0iTBxjx0bLff15JcmVca1ZBTlFILiB9eG2OPIB83moupgUvQEQ0xvvX" ..
	"MfmGjANAAuxaIi8jhGbItBU9KviO+RXeGPxvX97wkUTgc5DFI7oYdeqD0Rylmi7BzKu5UY9D11fVBvMLNdy1oFNxSjOJtMD1v7pC" ..
	"Anx7xdNcGBLpThfflZhLwECPOo/o3WlYd+2EtoFFh5GvZH6VwZPVFwWIEJz5wY1iHjRkQGiQZyZBAEp1kI8/QNSrMWiQy6SMsvEX" ..
	"StIAkNiAdFjCFVpawMZcbNiMWjLIPfUVCxWxdIWXQFBWZL27mCmuzxic0ZOVPPgBrCR9wkBRikRTOFsrEKqjqX3QlWBXZAiSwr1l" ..
	"CvsR4AYPYxv7yTSNd9VRPjI7giOCcI/p9tn9zcoF8TPpJJuZRd4irpoblsSq/keRcQjKRrgFv6HEBg/V2OpxyRoqBuUKfm4MM5YL" ..
	"sYTuHgWY1l61FZeiy5p9/a/wXLvoWE69YnsxKwEWwrthISs/D/3cC4f1oYWGI+t5Wst6Hc2RCGVET9ARzNvtF36q2/9o/pb9TMVk" ..
	"7g4TkG61H+tO0yOD4xJP6ltH8wnXvHwyA+aMNhOS9Yh91747r6R1T4Y0epY9FtnPtcl+CzkVqiHvVs7b0xzYcvwrTP3XG3FJ+Bqn" ..
	"VB+WRkDh6bm2gmm+3wjN9saXEP3XxR6VewVVvaNQCVVga/VJvwmr92jTXXHHVbFa5fsefuZQVF1oJIdnypLxA8HuXESO0XMMqdtP" ..
	"5Cx5ONah3TL/KHwFeXYVB+4+oyve0QajUhXbUx8FZ+nXL5NdYlXPmfb7M1n+zsb4lEt3K6y1fA/j10Ifo6a3NrDe5/Yoql4vaEhg" ..
	"Pl8Xg0ZvL1niv4Y1zBbFIx2KW0WtlnuNWLGAnnmWg/GXzzr3daIL8cFz6EycEnX9UxOkdZDuP6kBincEnHHQnsvrNXBglMxmfCQQ" ..
	"93pgOIWT5/nKWCSOAa6Fnj28Sw/qbT50e4jc0Vfmu1Z9iqvcx+4L3z6bFx0b4migT1n9iVOez7gKsuiRpRDI5/EjdxE4EodsSZAZ" ..
	"8Mm6wuMuVQPK8N5OsA5OII0TTkYE2WvopJAMT+OQLHLvIeUDD92p35GjP3B5yaa5XuaylrnFx/TMBz1x214xClT2U2KTlgUfSE+d" ..
	"q422pt1JKICXH5cX4RKpzbKKjSz0+3MQNCbKzGPXqN3IFRh3BJ93kVdEFLSpUa2hUbzfLPlWeKt63Vs7vfQpayoZGdihKt5f/0fX" ..
	"/Bt+kQSFLyRrNAP0gohGFTuAE/SH939pDMHRhGmkEYc34gpx1HftO3JNVqJ2IM97AQ+Im5GsijyAXgNJcEeI6dyEzZ4kIQ2cAILP" ..
	""
local PAYLOAD_P5 =
	"Q4RxGf8jkBZbOdOIhr45nFOIikddQHc6/bch/EawIvOh+Z/Vj8wrpy3/lY+Cp8OeUUEDkFauxLOI2SmYP3AKL45J5kAJJuWxJE1o" ..
	"9nYdR4fKRJCJ71/fFnE/m8Bv2dqy4AE/s8ufcWeJd/qqWizNnbvjUkA/CqOBh08Se1+njZBfRSQfAs6N2QxqFnBmQvdkoOcbmiDJ" ..
	"nZShyO44RyMJMvqoSJ9La2P1DawgW11rjaqSgdolZyK1oCqrevgWP4NUeXxXaDoCUKpzMjmkkaFje04m4xOz+9Cq682B12284c1h" ..
	"OBrbs58JfyWmIQAWMlWlqStA0u0Toc5Y2rkaCkH4xsV+P7jRoIU7ZLTbeSKf7eQnX8PGLUIYS+vy+RyF9mJUrQH7OLVvn8GVolq1" ..
	"d5TuLs6/CXfKrydiVcbgkPYh3X2bJZxCXNJLaK6mvHC1YcsmsaH7nTYh3AdjSFdMieEyjSnEGdcdfb6uTAsLffmMBKbFVNTKDqIM" ..
	"57JzRMpUmuLB09ALKAiJyijPvJMMrqKjh5/w6PP8zazqYgmbjboOSmZj6SJYkYskvhTPxhFmEecSsNkcLaYMsBVntNrEQfNLhjx1" ..
	"S0s6J0ARlStCMB3mL/FO9Ic2ERiYYrIBINboYxj939KYfygXvDJJ9A9RI9oUhkC3SMNq+XLPi9paddI0+2S9Anicqe67fSU4bK7s" ..
	"nXpsHltXFQx2AaUhPZ1yL+JIzZjyEEvYQImaa+sbPCZzeEhTaMN+Kkl9W7tdW2djsDgMAltdp1+XzKZOpiodsQBGq2/IDf7uuZD9" ..
	"vJzH7KzWYOquFN86OR88EuBjejW9IYqADujmIAx3mvpq5SbmCdNXQ0dEnZwmjOvEAnhbWUWJiiqOCHfdUUrRUr2ksWqU6Cv5lxJO" ..
	"7eb4Bytva55QWxYg5bJTgpct1AVIb5IfK+CawZnfAY+VPrOeauL1Q3EcCxTbgQ3qp/B17grTbLmZ527/sbokJB1wJ1YAoVnNSSKd" ..
	"ZxYii1P5yEP7uThwJ9lj7iMWF1ETDsUv/vx0wUKHKnGPHhxaGj2tvcT5Ed3lA2t/UnfEDbyC/MAguLK/kvKP0HfpMuXaSEX0Klcd" ..
	"aOsc/E3aqQqM20rLvmTQaxwwNp0AfShsM9VfaizccXB6XrHFKID34BZo1Z5/HGzoPS0AYTZvKdkPsYwIq4ZAvE2Is1ywn9Z44YTh" ..
	"YQV6cspK4GBRp/7sizDjUvFFKLTbITalXDja73ZdmfzlXYQrWHcSpDWGVlQlaGKvKve/l4ASg+jcrV7gr8M4uL1FGJoxOF1wxCee" ..
	"i85VnuhpkdQLNggK3xnp0fB1fRmq744Klz2YEreJyyd98TQzXJ7kwuEcn5UWZpRakKDDc9wusA+g4WJP+635peLdNsfuxl5LgqFo" ..
	"xwVkJoWXFdgqAvkAZakbW7rmU6Pq9O8s5m+iHtavyym/qAOF9W5pQtTo0f9Y7xNdDKbC8hO09WzLc8/Um75RqXVOV+gTim63t9PH" ..
	"EzULPSh38l2gg8B33FdYdskgpY1Bm6kqHldFS+eYkpH5NZHSrg7lKlfbvcPiih7uwUX+y66ppeDMFKCgrzJiBUpfGvTWyIZ+uygH" ..
	"CqmmY8nXYJAHU2e7nAv5J3a3LVTf6msaow83//SwAxQiDsnIjOLDjlubhKwzkSZY+plRqEZq72uOnSTf1v6c0kwsZY9ndsUW+sQE" ..
	"DQaRRAlavmyQXx48lGc1Cjk5THWEqf/OYqijnpuho6F2gXCu9UWvxb0KeBCA21kHF/LWsfza3D8NJ9u3JTBWbnDnsyjsAxYfDXZ+" ..
	"a715sg2am4TTJcD/ZoMKCTdyuHLzcGISbQaNs497LpJfNN3pwdikRx0VMiN6GDFLKGmub4ySZ1wgpKWjG9fvo2yp4+muLoc2R6gn" ..
	"6fL95X6R6f5iJ81Khy3X7Ncl7iyuk1iWVi/X5pQawr1DVDCXI2YFrCrTIDgD2BUKAdyb8ydch5gqxjZVmQH11p2fsKPrnVOqKMZ+" ..
	"7XKw0z8klfkhux6QqLBVeed1mRfRZmZSVED0gg1ibkq33vgwaBM1XkPPdkGEuKrvDU4wgD13RWlU+osEOLPB1j0ynJJszly8o1+i" ..
	"FaNKE6mn0jr7a0CklXO98iH28UlcmAW+/84q23UBxH1OpkuXVENAgY39OGCqqtjIufF+g9OAL2M56D1MfiDwY0D1gNRgsYxn4vig" ..
	"LL1kjVuu4L4a5eQkTTtjlEtrroiQkUY59bNBpdz0s8nsoQOUc9CAczY18uASfaC01aolbrWMjs61gvkNxdFUQwUdOMfPWMNgzozq" ..
	"BwO4gXWxeQTefdlxaJvJazmYfjHdJl/6PuBHJVxaYpE7GHeBBcxvxOme79dQrfl1dMkyvm+0a4ikY0B8JePhhylxiEeQIztVC16Q" ..
	"7nHCJASVVPDmDVrUS3a2AAFAOWYN7N3pp+f9TGJtXOaho7XzbjWNdGOlj7dsDtQfAJryK4PvjjNIOXl5/F4Zv1lRHcpXPqzrUoyQ" ..
	"3uDI1gLTZAKIuVr5/p2heWgMD+Fu4XQbyp4VaRcSTgiEzcmJrRAINfVr8rZv1ZOLuGO+c7rLNwyM7P6On3y8YDmfHub7KsJhQ+Pr" ..
	"ckCf5otyPNHxxCkm7P1XUGay+jqN9HjeIqah96ITqm/RbHcVHBnCzYHbE+7tgzXwC7brqkuPz6SRdTfB2yswnFsQqhu2ktXTSYat" ..
	"Aa61DOPhg/OwxtomJeFdWx0xBaUyXF1M89YKQJSd9qGKBLtxC2q3hGL6CXRNwqOZDBlBVY4ILA0IQ8ZzpSJ2DSbULAbD13sAg2XL" ..
	"rEvPSanG09yZGqMmXyA+5F1dpunimvdb2zwEyklVlhXCO2jkn403srf+lKP6nZSk2zdogDCzD5x9yZ/hrTk/BgI1dcre4sAWnEoA" ..
	"Di0sPUDrb63z1G9QIoIKpJjhex9xRS5oGgKyg6VTs9nF28oag36GafEtoRIuKNNcMdvbHAwQ4F8vjzSEuhN//4U7Y5Hm8KF7n+Ti" ..
	"2Uak3bRVtop0uOXUovzldsZh2KN1oniMxL4/XyN9YT60Kky4j1EvNsNr6PI2vim1RzCvZhjKM8kml3yB+fRxu8rbR3rd2s8mh4OQ" ..
	"4iPUAIUe8sJIbuavIEtOpqdNxGu7HV5ZdpF/Vecka5lQbCKKsp7LGMKSRCpM/WRP/DtfQTIXbyuolwoUcnu7vncb1vya3BgqWzeM" ..
	"fi9sz8eF3y9OU7StDz5dAYbra9gs5sKl1cKU/cTaCcbl5bhv+PcvL6LAmiYwMCUttN8MSl/KTX1x5qKyVUrP6wshnUmVV6Y2W9rL" ..
	"hYUrAOadMqOJr+2pdW8w73HdRuraxC59EdiYkcmBdNSOXHCMCtpyKl6nD7CljhUyokBThO0h4IbBN9mmwe9jWHmR8up0PKIeXE82" ..
	"UAqrBDMKBRRMHS8pneduuVmSLcpFm9AFZC7Ybi+HiZVsPasvecYbEnUcacAjSd/09s/CmxhZbd46YXm6765Bl4k4Q87ltrXxaBgl" ..
	"a8Lx9JDiL1wx8/TBMBapcrJNx0sdCGBX2b+h1q3U92i6ReMarg5bC3kuOrs72cETjA7yL8vHiKRE5MOJM5et+Ivr5+7Vwjnxjmkb" ..
	"fdV2/mAhBVr4PagxZyLDLZWFVYvEU3Jatz5ic6PXhA0P/LAE3F1Nz8NKupPq1ypP4tEXkMmJQrlu9htHmq05Q2Hy7NHLh6IiKeQ9" ..
	"fxTM1xS+8/V6pdBDlx1cJjaglOXtuL9z6tQrSBnZVLCAg1Hiq7zYAm94KgtIcJHpe8V3AZBWU7ismNbS1zKBfFJ0ViCo4aLRRd9m" ..
	"KNQGVv2tcNLQNIH4pymzTJp2uK5tlpoCGwz//XK84CoD3Yx/R+Y1W/mqr/0rnan2qwbAJ5VgUXQluIO45o4HTDR6rLCKrgZgo6pR" ..
	"IkNSL51GlfkEfKfwSMf2wz2tpHZzoy3R/QivrC/NmxESlTeqnbnNG2o8jL/IGfFikM56d7KZY5LrL/nACADA8eq3JcfBzQCU6LhX" ..
	"+WrbxIWQBzGxyES+EspIo2hexscVFoU6yZQ6SQKJEfmoB86O3E3lBWKDsclkA8OUKyY5pv/xTGOUSSfzhnmJbWnUl/LDy21lmVQh" ..
	"SC9oHAJuSQPh4VNEdcVRT6Ofv8xeD+NH6r1Z5btW/VBZKrrzHGDO8Hpg2WTijdkGCEBHODBjLcbpzHKFl28sX2F+bw2ZRS0Apiio" ..
	"SGnFynQzPPEB7nU77Kfo5e5QEOyh4JXjG8Z9XskPGWJ1pO+UZkde+r8GOt7jJsL9c+Lfp5IjuA8vpQAuZIoScQLm71ZxUSHndp/D" ..
	"rycWz0EqOf7q3pDwF6RflwpNO5kdb2FkFRDSfPjsnyVXDPk6z44XXWFYyM/K3dLFa11Pjlq7mYK8LBlQJPFjWAG3Qbsu5aYoGgkx" ..
	"NyQXtXlZUsg7Cf4OXYmmd2oWwuSzJIOGYHJtYavhHJIWXST9aOhYYY8srzmuwpkbE2K/WqKUFlLVNLMStqXEmAoqrXnH58C82SYH" ..
	"aJ7VdgfxbmDaPGMd+Tp+Fmu2aoF+Y/PbEzKagjmOuFMltgpN6bhkypbALkh12NdyrpyDej5Af7LlCKSurOeO9C8rOfaZjSqpAlI9" ..
	"pwf3XwHceI5AfI09aP1b6w6hB1fj2BU2yIFbduTkrF4tkaaYybjdnrx0lz13vCPG5Y4mej1JHbzXO2kEIRqapt/Ux36atHR/mQ+r" ..
	"OGV9y6n+/IXkzWaZtECDakykjsi6q1g1uKilYSBEIWpc5BEbcSTjv6hNh96IfqeHHIjIEY3LddW+mQfj+dymtP+2LoIZBss5Fn4W" ..
	"4p8j8wP7Xp9OYve9Rk/d1c97VRBz4cdHmn+ncn2Mq7RWlbvF6w8KSbdsZZxHB/irRxVTGAKTAaHgkiEQEqXbKtsKa5hUVzGXZfI3" ..
	"qMy9r0erXFh22mGRFg97O/mlYv9ER38AhTZuNckDh2f4p2zrHL8b4bcRa95bBPXk3zpJD36UJQKlLlgYYfFYPUisMLkOfeNG6Mf3" ..
	"B/3uZh2CYHjBlkGkdswXiTDT3wfFa0SOIIzD/BaN2NfUGXLRJ09+RZln9LHrjUWIIw5vOdHuPNzqyGTlRcgUcWsyrXZKuWvjsqv0" ..
	"WTa0SpTSuhX96STjMKN1YmnyWijx7Of0jcaOqilKMwKYpGW0mRRQ4dKXxyWOrMRXw1jnoAcEARC00UqQBoPecrtx9eTZLR5azm4B" ..
	"ZDEZnNAuSzalRP4M4GRZqiy1QQyJ4ePW0GYoWfnXHMAvxgQUVUNiLyLsg62JeFueq/ZpCszJRV5SXHE7BR8weawsptx5F246rVd+" ..
	"WdU6bcj1IlpMQ73Fqcnv4IiIYaYJ9xgmGIGrXxOiyQGhEeWvTGq/8tYpR9B3vsDdzlccFogFwdSEulRuXZ2EjamM1PTlm1w/Z+BK" ..
	"nt3hoZdj8iiVDBESuoeDdfvHuf8nQv70ACyOB9jcFK9+l4BOK4Vkx13tz5gM+Y7TBBJKOn+RLCB51mVzLkmGDSqd+2s/Fo19GbOC" ..
	"kbhK48gfVyI9jpewlMp61jL3qtN9PhsU1qPUOKxMNN1gl5Ihy9mW/XV4X3D9MRSbUOXK96eHlfu3vptw9YiHC+tzqmAgSa7M13hj" ..
	"AYdkCftTFNqMo7JMD5ilggqH1GpP7SmrvNzEYBOcSNh/F30aF8UTQoPEsqKsMAdbo/W02ttZbG/AepcZiD7kDcbtInIOLlp4SkgW" ..
	"vzSdH0Cq4C/SHNwyH9FJCfjsq654PnnOhAafj08P9OHFJGROU6Ly2IcEq74ccprCbIDfjeMtA8lOC09zOghWaksQU10+PQ/wG8gL" ..
	"7L3rscMFch9O41LVa9m4MrlaW0zyBEmwvxJaQx07GTQd8M6aAoro9R6wQEK4pz4T1epCnJIY2uz/XTOUxoBxe7cNxHXVZ0iZLBtk" ..
	"zGSkHt4t2a3Tfc3cF2s+UGxD8IRxLRtBb0TzQ0+EUNYzcW7QaaYmPqDKRjJDM6Uxq3Le40DnRn++goSW6IKN1stPZ4DGY9Ds6mvE" ..
	""
local PAYLOAD_P6 =
	"ozhDfcYbd2amNpLJNjwbBQYUpK7m3hqpmLmw+e3QvfjD6xPTHpylAbwdnYyCiR3BTfUdnr70RrkC+Qce7Kdn2rslvkZJf/cHf3UW" ..
	"MZIZ66bYNwS4B1Rqjl2magTlRB0c4aAld4dkwL1/7171rSyLf08+tJKBEJseVfWDy8W7/wWsOkGSv/ENI4nzdyniJXWmE8Qce9B7" ..
	"L1bS6/33Os2wH+ApnwDR8vEADrexviZMUev0rXWemV3b91o0givjUTDSoC1zgOK97EDR0rvi6Y1FRl/zkRLCOZGsCAd59X5VirIH" ..
	"Il5vOtXInO/BP+6VhNf8SuaOE3o2gcS7j98rVpmQsi9C+ON2be4Nfg7C1TexG2wks2bh0E4RhUBPPDzi1Evrb7gBNQdu+hsd35lF" ..
	"4ussHHAOHxVTvyt4ImH4w4DAF1Db7oCcnrGbrcp+z2SeOxkvESdX5sBqrT+6UqbL9ikw2lPaahWGnp3wmmuih+8uvMPe92QGxMyi" ..
	"zNP769CK4k3YRMKjp0MYe+FIbaF3IjsWIqLYC72eDSp4gV4eR/t6CavcROs+l4hfLzl1T/tU1PpWiitK3NXMkoTNjk9ejbg+/4jV" ..
	"a+S1LCiFAgGaruHNpiDcFNrGFYeZdRNlQVLIOmyaPn3Ck0SUxgrbEMXURF/h6Qfuej6BgeaQ+SrNhxxJUGpn00Hxk1tPnbqvzjhd" ..
	"sKpzesQSdFFtNFEX9gXaTNEJCIiVaegEBGlgGI5OJ2AA73joz1QY9cLKh1oXVPbinigMd/wnhKFPQYLCiFhaaDGliKgNv9IC5Sku" ..
	"mrPehnlYS8Ag/V/iBOM/qc9jAp56FWWNTGzWAIyt8+8g/KSY1mnF4HOrVhDxotv2vMSjp64SuonSe+8u6593MBl51PfR6pbwxVWL" ..
	"nl28gSdTZIgVmxcFrAGPIFu4HCZ6GFT7aAZQNy7Kh/UKneGNxnkk+xt7rjSWV8opQUJKSWyzYRblEcSxsWlmNFsOJCZjvdlkEVI5" ..
	"QhwNFR2blCbXisMKZ0MIrxUnqKKa3GTQjnwbG9Sfrf+iJIEqVIFLgUUNpV5COvy8eMbbq8RCv/dV1oLYgJQptJOJfcc1NhgfndGl" ..
	"F/SJn6nRDJe0BPYdvM7i549tjnzNk8uhxgkYBbD7OCL61d8gUh8q8XJTmVh/FVjjZqNFlYm3HCJP3BXarEstLZFP3OYOrCqtTD5o" ..
	"VBl9QP1AtTTzdFz8G8iV8Aaj3QCneAkOXFMZOhge8XR8oSL46bKOkpnywWDRkCW6mtK1NvdRJyhexg4NGJnhuFvRR3KGna0IN/gO" ..
	"NCA0e6Kv+q296EVdOVE4PO0zfZvw3106PdLFWVhM8YqN99f9cdH3iNHA6DNyGgkNTuMzFORucH92Ixo+toix86pNHVXzuWjenJfo" ..
	"yR8MQBJpHdIp0qVgpfH15lCilm+F36ThKbbrWzMmokhuqapXkhKpcXNll48Lo8QuCxBVgHKXeUwSCyH+9PI5yCx3IbKAxbgHfeM3" ..
	"HBWTkApCj8v60BXUBJWkcrurB+N+tUBdtJLjpL6A/1xgRlthaENHgoivuxKg9EJO/rwEWquQJ33gnxwnzeoVZr/1W+BqlFAOgP9r" ..
	"F5WSxlmBGFYj5pdRifSJG0j1rqpMTNsNyNSESAZfM6cKOe8ICauGcO8CDvMfQBFjGaKKukuB2+BcSso+F5q4XN5xJgzku9j2MetS" ..
	"nN7J4FKTlweT+0quenDZqDQRvQ5occux5vcz14Ve+cwJP8CTg1AawHmzzzCjDUfdgHGtVxMWe8Vsx7NDjfnEA/rDVKqPo0tJ8Uhx" ..
	"PqsCbM7RWRxy+CI4GOGLCJ1J1YIP3VCLCOxKHE1R0GDSoSogo8PmJbVRRtj14RSgOLFSyYDce7Jelhnz2PtWmlbEuYx8rZcSr3Ma" ..
	"6lThVzSQmID3Vzum80pT1iU3aabqciCJP5tuozu0sa1YRc+ao9Nwsz4helGIt4HDrG7YU1zRdzdEsK67Cu87XBeRlxCkLmr31Ms3" ..
	"gNVeQAKnv/d5IhPEjfca2FUKSQkAsJP+yZPhN+qTgD00kkOeIbsTGzbsoSBZkdqbPiUhEp6MvMk5CAt0IdoZZpRu3YZg02S/VMN/" ..
	"iZstJIVsLEQQN4pGKzFB57fr0NYN+4/adRiQ7Z/IBhBoRFqr4XvJVtufZiLzPxvQLBL5mz7F4wKLaBftFU7KhQmiJYMzlDwG2QTB" ..
	"P4ti9TgUlXRw/RX5ErjUZcwXf49/sDl5Fw8s3DU6vuzKKEKYhrWMADvJum/UaQC1RzsAfgdFmUvJtJQh3lB0aVTmxLPQ+yPZX9c/" ..
	"o7kTOAbTsUe4V0KfMB/m8Jw6xjsgpJAFmWwOexkTN4lqfbxBXKhRB+mkg3fDztMDs6Sj3jYCbeHHustkicMauttaREjIiKMwWqp6" ..
	"3AO/TjbYHQ1jk/s9x5kQuG+xXITbzdXryLcnc2m/MO/JZJlrVsX3iMDzRG3eax1i59b+wR6gcmucCxOaLRo36dPJfCkFyeTqqg/v" ..
	"1LSCxlAo7SUzVEsKiyohQEti1wgzNpkiqJEYyWXJITe9mXD3YsWGYn4dNfQxSHCL6jY0NluTitoINBJWZi19Jlbt8yCfS3aEEVLp" ..
	"mgTMyuCKnLV5BxXGmYAKWsI/Z76LKddI6q7HbxyjAFNO1QrZVkkilxSD54MSFR0WtX4vAjBVxEJgRjUryhYZhoyMjJ9hZjV5BU8t" ..
	"dt0hJ1shRrTLFp/SN1TZmXlv3J+EM8JQwvl9ZgRkd/+JUMtdb7BGYiCw4sOZ655zjCkZf1JGTlYJT29/8FiNragajSp+3J+ieJeP" ..
	"qBZwrqTP4Amq9LXie1IP76TDDmmJwDc2wyWDD/5ktgKosiNmS/U+3E80q6OHQUN7Mw+XXSdikd/zAX6TDehnRQP0xNX3kEs6bo8q" ..
	"O5YygURg7MkYyw8mvG/5Xx8XP3arnrprw232LZcX4knh3djkyZl4C36z1cwCJudZ6gNFvx4GqvsWTgcTsgQ/PAXyHgyHFYOGM9BD" ..
	"PfYdd29Oskg5xwCUKLlJEUgD10oJCGjsUaehWO/WkCqEWxqGVzsyGvXBK6SYP+Q7owjIvbMma5VY0y1nZeL4NC5xN0NlJj1n+Mn1" ..
	"jkRGPxP+oPmtRgpVWDsYwYgw9ODFMUPv8KmHes/WX5JqWyesAZ+pTd8No2APuL/AF5X409sVCChSapNfA7qEXTFEvkUjKVfcllQd" ..
	"fUh9B885wXg1lZNUxbBnDTkjhnrNs8+loPuzh8wsIu6l6C0D4XOwPTrBSQwPoWe+gyDl2AWa3WuKk9a+JEFTzprWYOgw3MYICWNs" ..
	"dYLcUGyTY2/8OCjNY4FXrPiadC/flQ7mUFqaw4cjeDt15gY91LkcDjTf0vtAEhsee6x+ODnBJp5NAvaU9lRgTMq9LSI1VUFtx6zK" ..
	"2ccuMPeXOLK1yIHal8F3y82p2KvOjvk9N8zIeO+dZKsSUUiLFeUEC+lj9ApW9IgtQfXb7hduU2oAauGIWaASOxOlz6MQcmOIXRon" ..
	"4MGVykb7UpVUyoQxy+VBGyr6o97ZR3s/j+y2kgwdLDhdfX6pLzQXTnzXmCwF7lI4A9MNUDw2P3U82D1r5h0hC33S24fK8YOaklHa" ..
	"36kGPB44DEOoESDCXTqbJ0ScXkubet7ct5edpAB92/tp5AueCQQXxSar8LSjwhoabsC9wOcDPZziimxDOuSZXcki1BjgFLgrO05d" ..
	"07ym9xwaD9aCRfxKcn86mzUmNywWNoUTycN3A9o0AaQ3zOv+PKC26VHH1Odg+v+/oOZ6iF7jbZk6GXieELEqu+/M0fzY1/au1+gb" ..
	"vTCsFBHiogB+Vx6eG14WAgYYFM5qeghDYrKL3w6WWXyFv4dbHYcIxHOePNeNknAmO1m/UAWfBk09OX32W35Zx2c832CiR/tspe4+" ..
	"dupGXIS5GzJBdWU+JaoRU2bjK2i51UGDnjroVsFSSWTLjku17f34pjYGUOlpKwRYPgdQTQ3/npOMGEIIiLY/4rEcVtStkjDrUmky" ..
	"i2VESie9IXYSMxTugO3FgUcZYPHz0PwSQKrgUhxSKZt3togc80hv4i8/xonnIvSseQHsSWJwD+iBdK0u//Hm8O36tFWY1ZQn5B1T" ..
	"+AA0SH4cfvzCQjsSyq5aBVhgDVOhGqOMrNSBkII1kLpV0IFwEhbEXLRAPkkQhWrWkTo9VIkpqZjRZIclJH6nn+KS6ICYgFPWOdhW" ..
	"8PT6kxCjWPTAzdHTPV7cVNMkaRRi4BznpauWp7YoxDIAqyz4w8RIcv3am5ijZfEf7ZJgIcs81IbXXMZNj3m7c0q63AnTMuKl+12L" ..
	"PBOoMck+I+2YMX8vHvnJOsaKvddTIBzwF774xUqt20lxQnX3IM1ZbRQXEsy2PV6N/usBoXzEGr7JrZ9Z65t7QQUATTDohbAzb1Qq" ..
	"SQZCpcxSMm8JF6y/e3Z4o8J1V1EEA+hzb8Jj5ylMgLCoS7NRFtHNfb2hGM93Ks4wp9JE4/j1KyJaC8pfIMN7IAJQayUuazeug+i7" ..
	"1b+s9zWoLZ/ANrnZZlO3uRzePjYZ5s1T9YlUNCl4aIjpYTDVtF9e04BaBI7nnioWw7XTD6ToVGzK31FAWCXvq+OCTa43DtU8rtKL" ..
	"y/eIsh8C8kdxtv/Oy90UM2rifEYgp/LF8mxiAtgVMI7adGQ+JFibrlx+EYZY6kyaNYF134YZAIf4TiAcjFfLk7l+xhivCAVQhh4j" ..
	"AopuZ1Pon5fsvd5ZYfaUwNeKBVqnmWJnAvMDK42wCbz73bsHlEp45a/luJM7HehlQ0B9ZMCMTLfJJZHijCkmlFJ5Et78hf8rNajx" ..
	"NEAhhpAffk04X9YnPXUEFNX+JRVZDg8AwLfzoposo/J/OK0YLwP/liBgQjSPNJGokpq1TmMqOzpUQmLXlhdF7rTbX22NtMz15TUd" ..
	"BdEicagNUImmqbLLfDIkG53ONW7rK5CofOzIyMyyoNrgQe74nNndQOjh56wY6Nt5Y0WDmX+AuASItYyq5kxHfVSFfmTaHjL5BqQk" ..
	"8BJdxzlETzgCgeUlwe0EYum5q98lBPPWEDEzA3dp/WV7JCR/+T27QR+4/QesbtpzVy7Cj3jIMyZBAI1+VItXYB5tjW6UGN2GV4Fu" ..
	"KwQXAtUcJh1FVrTvFjGA6L4GhateZTbE/kaeHwnMQWx/k338Iy0awcS5A4EGbvTG3aCs73KO3UzKikJvHwBbrU7UJ0UBYbnordc0" ..
	"EAOWsFNPMk+IkQazwEyRzcGKtYJJGTlDfdzKfb08eEjhgfrO9qAPr4N45tIGx9eU0PUPYTBaCbUf0IVp+eJcmux7Rv2x5iQWTqgC" ..
	"oelxG8M0oFjkl+nsDbmFplD/f/f02GwJGmkRNxDHBxYbsoTMuVYP7MBgNZn3d+P3mpO9KWRSu0hgcWZ7eQvoyg6rBNHj58yw1yXq" ..
	"ZnsFuVYoRA3STjoJQonqk7QqH27P0FsWEm42OTLLHQ+cRhE/lEcDWTbjMGNZCXiMD1roOwwZJaqBg5DWraDUYv36t9shv+NxZyYm" ..
	"J/Ys/EZ5vUkJFkwLdfdOzFmiR7ytHcgmO7YZDuQ2D3HWxWgATU9IUFcLvbYIRVnh/DsRWI2sTJTKlb9MzohCID8R6n2VPYgM4TtE" ..
	"bJ9tqmQd44BPZzyqhOKuAaZHMHp/UEzhcGX/QnPXZaoZtcOSCCs1Bi6W82+uKqtHroUzEsH61KpclcsLwyjc//0zin/bKAY2qcgw" ..
	"DVwLh9SJpCqMm9kqTVjgCpV8EHWratm9JjgI8C2eweIeWaulIZsQ6xfUW0897NF307xO0oCE4GkmiETRI5Vce3c9+kegEQKsMdZV" ..
	"rXraWmnzECgwpyH8Wu1niYq5riVAkVmsJ/nV7YCHC8FhHV/NOxz82jHbVXWJfkXyv36EDy3ZUMgnvKF9Ay2v0Vu0FT293dG6NcF5" ..
	"cIXmIlV3R79blVsu8onZ4ZRI/IMHW1d1novBFhX9esy+EY0eypqTCX4MIb0Zt+18PJsHSap0I5R9Wc75fqiCBp6mjqriF9CcbfnS" ..
	""
local PAYLOAD_P7 =
	"wgoQYY3tCMuMJRL0wa4JKLyCtcHpUQhfB9aQvS6n1Yj+oiNSwUabHADFvMiMuYLGCQUrlYcJwOxIgRy15FJd7r8xm4bj0MOofowk" ..
	"DkpHVbnTLJgMkxegyMZ6LVkng7CeWEg5ArnFfGObzM+Mg3ianyN6N6Djv+9Gd7DWnqo8mToifo1uRVT+Bqt1OX7tKR4+eckaQvGb" ..
	"z7PpLskYkLnRl1irrNlZiuvR5SXtls5ebMC1Cky7qLsBHlLkFtb62lVMlxXFYWyF9krpbpFo/LHp7CoeScdh5AX9NdQ7Vaysfoly" ..
	"XYeiUeZbUhw8OGsG7bmdy9cqskw0zZPug3l7PDmXo1VDa7MMwS2ykyhsIzCaWXansH//LgOC11Heukpt2XyIcCpUPb8ho2qV7eHo" ..
	"h1GQXY1yQ4nW8tIuzo1Rbz9gHm1aFsB2iLcCkB0fvKckgIgAc4lFJ2BzOoS+vsEQwKBcTi0/LYEp+Tc2j9++KAxTzPC2rtl6MH6C" ..
	"C4duNN/R22gzpN1BSUIzmLeKvRB6zOO3iMePm9Wa141DusSNG31dSnJbzec92MIjDg65RFbv1z8MmqDTQcvmb+TXKWoh/RZ/TbrM" ..
	"M1RvaLaT39T5GJU09i99JAqo6j7j6++QguKxy7MPGG7RLmFNKoqrdFcwuBlPEBTjoDdGcAAKQuJUpOU9lpwYId36E0LLO61VWbVb" ..
	"g2aG53bFzahYKh1EqZf42+wBAtdPwOM9JjvSq1TAcTwPO8YR7JuzM1uratdQtkP7jnI4mNgtDT102j/X4NrSFZc2Nil5LYBzmuT/" ..
	"0sv3yTIFrhM4xLeg6TbVlWFTv5PPUqpIBGSw7BrJRxFOvrbpupd0wsIsNIhfrDGaWmHwMFwxz2OD8nciN2Zr4Z+gjzTEvzU4dwnj" ..
	"8YwE17HzXErgL7g7y1rrOt7URqu137Irg2EXO4RqwyeoledbZrnoLq1In6bv+I8pe++Hm9CZcPCqzSdXlwJJZTj4w70rRByoev80" ..
	"ER+tnfUACOh0ljC1EKrW3uqBLWUx1mW+f5lKIHUvrFKMPW2UkTRM3QNFpojXnHl9pvdg83I1I4kOSebQ67IYFINL7TOmLng2VJ97" ..
	"RupwonS3batPU4m47nSq3zl6r3jkoAPNEnnioMEBy1nQziIbY3PdgsvFV2JauHDhRzNW6Ue9BrpT9EHx0zGLmkSFOf3YuxpUpU1m" ..
	"EbySzi2rh5KzgHacZFZF6b8vQVAugAw3DKNFI+Zk7OYzxquxMqccoLRGjr5aofJmb0BU0PdNwlgz4bU78JhW/YwuX/r9O44imsAs" ..
	"PHBItWK0Indt0rhSighHFwvnzmzWI86o4Pb2Lr6bFVsWBW+iPOokr/qk93N9duC3YIDJ6h37mBQjtBAOb0CcO+WGgUhr9tg2hVof" ..
	"ANZYOV0diIb7TymixHBc2XW3XLOfjRYTuziWLPtJrH9MBmLF7+yK71OKEjpLyPFOYm5JaNT5p8BJiJIMccY3cscgNlJg4EZ2f2xT" ..
	"vyT23c7CXhdxJ/PphWAsBCEd0plCc2b/7lz62EhCZdnU5zKMJkTB3IOR9BOVnNts8WoojTCcPHcLinCLkm7e2dieo6wY5vxqSMDn" ..
	"NbuSUDAjLFK3AQYXdm4NLWyNwoT+g0W3QstoIdO2VFeM9dxCjZro2ougwt9+5KWxN11BBp2PoWkuNGH85vTs9Jaypuz1+W8s6E0i" ..
	"OKmOeq4cLjrYlSSSZpUgm9qtFTsJbOCxu5dVPHXcpASKVff9DMoQ+AAYpzCmntz0wzflIMEzJHcssS1/0o6YaMs4zn4LHmrcC9AJ" ..
	"F4T0Lv9lDtg83/iDAtTw22sILQqcERQG72nC0LP66+EOn9LdG9DGK78huv9frTzhbV4OeAFMORDBXRzC0ZeTLTC2nVH60CQXb2hm" ..
	"Tj4XSIy2i73VhPfwHJGuwLcG29oTFHapSovVgIsgl+UIGr+f5utp6K4MRkngiRrhZrZYfnM5e2tmwQG2C0CCiTELhcevPCR6UO82" ..
	"fAPq7O0k9NP5pqqmm9zMvGzTiYP8Mgrx+JFP+4whiqArMudTW5FXfqZ7fY/eilp30f4VLXutpc/Z+lFsmn7BEkqGUzMIesP2IlLN" ..
	"rwK1+hudkgr6NPuhWgwApvKplzK+jbo+mNrrXiy7J4zT2C3xX+Hudh6QTzKqQ0DnrcnhQJ1eAWDD0lDPL0+6DMK46LfaYIYr1DLH" ..
	"1B3573XSaQRG29pYt+rQboINylSL8prft5wjzjRnOfkiajbxUJbc+PuZIfCwdaSlYqqlp5Pouu5x28aEyTsOMuypfNlZu7HXxvsG" ..
	"9uswhYi7qA9CTLewCi8H+PrnZ6z/2ns3aj7BBLarOe2i6CYyCKWgOgRjMWQInBizTHACxs8V/jS+IB+sD5qK6LLPscYo8uUY3ocm" ..
	"zRTIoQGEFP8tNhs6o6FXqVlvkwfJsquu+3ohChCRPifYe49Ve5Ji+rvqRqqXbIJw1hGcA6kVJWCBZFt3jj4iK6sbqbg3g8BwrFfu" ..
	"bKzaWVhi2XTVMXxtZdSnzadlfTfPNG0yfNyPZff4vmYhNFanVgu6/TWclgXl06BwI6GEUfxiEvDBfla04YAHnz859CDSblvUtmWI" ..
	"0+qLsBm8390Aw11crGvgiYeFu/LGqi0RSoxqbNEtS/xoBRGVKp5L63NPl+1H24Dk5EcOkEdtO/IMg+KXWc3hYp7caSbU88RkIzud" ..
	"VGJwdNzCWU8+G53JdD2W3rHX92R6MxNJAKLb/F3cS81eZfegmk4pDjHKbTHiuPX2d0tby6Z66eHkNND5fvv5lJhNo98ustrFUnQV" ..
	"P5wgDeZ3D9q4PrJYXtNrpezFYSM7Sp/r8C4cgjihY05QAa4qQJglE3P2oitkE6UQEQjibwXXK4qlgGkNZ7q/2zLG7IZDrC7gIGpY" ..
	"2aff16+5mVSZ30XV4yuJ+kc8aGeJrt/HnyoHopNupBQsE35xpMce1nzlc3A1DSmeZOiYJC8gO7Nq2k5pAaw/9gqNYgUuu+tuS/Od" ..
	"JW0vdMl82TRpGet5ZCr7al1eP07iwQsgqivuwRQ8zB4v5T3xjkbponurQbKaHJj873ly6JV52BOxFWeaHcUwtuELPil9DxGUZtx2" ..
	"WMIVBJkn450VgQ/UBj0IjuFq6zi86d8CLYExibwpa2FqaP39qGknh8SOVdIRl87HMI12qJMBYGrIiut9YwvtM2tCRhWkBu1+I6/s" ..
	"FDStS8GKZGoMdm2GmyXVMEOieSbNUXZRZOfFrqBJaXk2zy9kfKElfj36NycyqtDAmtJaFDl3I8Pz7Htl1ldki3TyogtKby/hv5wo" ..
	"znF0Xiy/h2pY8xVYApC6oW2N49vey1Umd7+imtBy03ufxYb30yBXolWrtbxc+yYy6AT9Qyuyhr+CzMsaoPOd5JzGG3+d9Cc2iOJe" ..
	"Ry6GQfE7b1NJ6CAqzrAEkjXAMTawiPV29YB41+fXMv+Rwl2w4YO+PPRdkjy0aemneUAC7eL2Hs8f1MpRIyAFmZ9ZoZ/iVHWIDxqb" ..
	"8E+0XZ5CDPsSmexMUY6rRUJtZ+lg4YZfI2sQqoqljjfjcf8it3K+VqrwgbZqI5lwSSpUPKVg3Jz1h+3N8YXnEZ/QcdtLXOdkdbXe" ..
	"AJd0Cj+ySmdjGJI1y/lv71jPvFJazeEL8J0LIeQo2DKpee8kyUCySkbxuNvuZKmfoICDgo1bKwW9NVrJUh1CNb8sZo86IQPpvRgo" ..
	"1VCTnq5tnNvl/AQy+t+P75KXzUZUCxSWx9vw8p7NCWavIykFEHwfStt7EDLTLGEBq6kkZlTBjGZhcvhJVAovTcbSW0qwok1FNNGY" ..
	"+fzkB+sg7js6sM6TjIBUsyHZRAQ2qnz3CdtgNrFtZGLJfyqKGziggiNrrSs6eSeG6BpAaIOtMGWFBKYYmKFpqfhXeFLwLmKxjY0Q" ..
	"udacZWD2dTs/HTqMV/MS/h5+Igy8QxVrxeHAwMi1GsG791fe/K87x4hMxUbQo9Zn1QuxgIwGlTxdqD7oELQ/C6J7GzoOQpIIeSkO" ..
	"284tCcsMxb3sKClo1Iann21KDHRjlfmqYQq2WAtJnDd/WvjcEmPnOpo7Pie2eOqpHfYH/gxAwyfvzjmqph1woFCcTAkE8lM0scrs" ..
	"5CvxToWtXusn3EnHV5fbtWW9tuEdc3ldPa8FUGTcd52o6MlJ7ILv3x1DPQ1TfsAB6vl8IVw9HSxcCvBFG/UNJeCJj4g2wTWw3or2" ..
	"dVbPMtb8SdXMFJStFa79vBgniBoPZMp/UR05r37nEgfnnWJculV8PeEm5K/iyDzUtwWwmCNp0hK6gjIZvWHQzmiS+ygP/RoACtA9" ..
	"4NkhKZIYhVwsrH5ITma6TyBZP3YHSclHJolDYKT32cQeBapExa0v5mF0JzAyHDka44GKUarqZQpa+zzM981we/djh1uQG4/yNuFS" ..
	"xbIV6tQbElBoRxtFGihZYCcRT5I0TyrNuEt19LKz8KCy9E8lhf1lhTiDTZfnb4ve0fILKEamFxu/W/NMByEAuuUlgcFu4Gj5PxVk" ..
	"CB6HIaetzOGZ4azyuF8bSPoFUX+r4WxeIgEQmkHQ7Nt41BulUth9DEDKtW8j6QMgUrtB4c0ffvjtZPR/CYL+zukwa5/JMRxhxZlI" ..
	"v8GFS3xEjUqCNda5kmQV2M4e7wLtw6W/1fCfc9OJKJrdbgETi2MEHdd+aMieeYDDcAoOUmm/J2xo2gYpP7m56fW7nNWvD0deuot4" ..
	"nvFQOWLtQPD0dYWuAp0xH6uNvbuS3yAXpUuv5hGSdqlbEzLc/OFyW3A7cHBXu5fc38CJzhRWm6abxe9dKtQTvdvdytyjXeDm6FDi" ..
	"TFCahLRydYiRcTrSCsVZxOXKyKGdoOcpbMRz4E1chb3sNdw3t6yiwL4Hc/M5RWBxTMz7RH7di6tndIQOOmeV0Ptt8JVBEuktiTOj" ..
	"/IejuQSqGFPjBlnGGDG4VjBZ9TPOdPrPYmLT88hMG3K2vaOnrWQGPxEVwoS1N8O5PUPOcTYdYJDMmXAIvmxv67u3lPqpQC82iRX9" ..
	"LNW9dROjYPHUmUXR2Rdf/BHSXy7FNMPwB77SVoPKbfA0m+xN95RZ2hQyUCLU/uD2sMdW2C9BGUpS8fu2YU8Ll1jtf0dSqvdz+r68" ..
	"AI6Zn0DixARx1bilKD6lCHoTsDJUXStrO6DCrOk+NkdBmAub7aYOHtyDDnFxnUqUwQIFRtrvqZGN8U2Kg60S7k89L+mKDb1i44mf" ..
	"kEXhZClWnISdPgN2lhoFq5/LM4MN0tef/TBTBSpq1ItcVFIbjQZ7iwEdsaojbwjpxmHlv5izHPS5RQAYBwWJ2pQ8eqjitPx/8qpF" ..
	"ssJV9eIH7puKOoVgQz2TeYrLfqLy2CiIeKLmWUciGBysspnyM0tQ7ClmWJlVdJT/imRZlvS8VJOtnhkEg44SICWT75bQt2pvn+oC" ..
	"36ENSg6Jye0vl6gVidXGnrQSiLce7J5+iy/9DjvCf2gNs3gt6htf4xZBpi9tQaB5ZVCQINocHB9fnAIyC560j9SSqlYw03wDjIz9" ..
	"Bxmbs7UzFT+uLxrXI4bfKTM3s2lH4oEXyhFq5lvPPtnlt8j5Lh60g/J0fUnH07zMheM87xQ9AodSnv3KIQvT1mHVe2EuyIVTyvMe" ..
	"4S5vNpkOE3pP3/CdMpdDy3e6l0EOo+ePwJw/E9nCW5cq+ZOvjKDGUFKDVS3QaPx+FhaNu1+CUGW1yyGPJGgBmmIE/2ckqihhhEGV" ..
	"H5NsjcYppjynwxVtEfP3WexVfUSt6F3UcFVDK5SO7QTDFo7NCO5+dZ+eI/YYs0olpc/rLbCl2/NiJV+F0Qz7l3GVyVrMzBE1CiWd" ..
	"aXNRCpIqfqyUvM5sjNPe0vvGUNqkkKz71D67flHveU6TCVsKBYX4p88UwYS4MbDYnAGS9NizJfh9BafWQ0M8ylJS6+epwwbJksXf" ..
	"TSE+VccEgi0KDD+Kt+zV6dDGwXgLrnXibU8JYvrHThQcVPLx55mFM/nU5CNfxGlC6avLP/2lN4UiEi3LiTbJyWG4w85x77CoqHcC" ..
	""
local PAYLOAD_P8 =
	"3Sqw5M7MyeWKz4JzpDqDHUC6SEYfR0W5Ekv1AkEMW6FgxWu9gsjR3rWY3w5aMBDRZBH8Z0DSoYzho3fCyo3ViV8hX2XI9HO0x4UK" ..
	"jQ4kxYWctudIMVVoBINILA9IhR3L1CHMz3rOb6B2nI+4JunME4FZOp35Z1pwPX2WIWz1KDFPUPGwXXgyfhsxxuxKEBpWE1b28Snk" ..
	"zl8fKXw+W88feo2TkkWll51QNkDQzMCKPHu52VZ8Ciy44AvJOlqTY9ca/DsidBruFOWawc4b9JKYba0oudwcr/bYQs8mUHwc05UN" ..
	"ylxoaR9KT8dLHptXO0HYLFJpO5LaS53uIc8tJTQf0rMJjUyn9iSoh3ViyUfuuTdB6/22KkBr6ifiK4Uzal9isYQT8xZpgWVh261j" ..
	"EpL/0fKRJFC1w3z5+y5ONxJqPZtNFe310FoQP9hgKMkH6i8h/hyjrjw2OozP0lmkZmHEdR38GhebkESZD+V4gRSSXhYK5uMzxp/x" ..
	"Mfx06bkkpyWSxA6F+lN45eTzFWeT+0JtQGH04BpgNt1s+gMIZtO0djkGsLQwzt70XPMPkz1odUPJ37J18s5wA994wwa34qy6BOFb" ..
	"2bHj9RJbwA0DkQMlzaDL1+a2K7HeSE/YIJx7NNH0wR1ku1BCI5MAfX4dGxRJ7EwHos5C++bRPrnaQ5PY0IrUEXGJfdyJZ2eIFv/M" ..
	"OVwDUZCr/hzjMCvYMyZxJKXe2cOBGdpPc2JUe+iHaCLn2OA4B68cl4GWDEgbBlk6yHjVmufaJobU+sSRQPBWaDrGzUp+9rOOPttX" ..
	"VW8j3fyg+oaiRsjamtQoMyBd218IEBaF3wYmmKnUET9Lz6L2FXuj6J4l/saimD6Mrzi+FEpV44A4kkOwtWoTfb7yY5diDHnUK+2t" ..
	"cMPpbfXIpwdAlrSrlsCznvO03FcHTph0rg6PCLrL4KUzYRjBvlXlKnor6bgD14w5JVOxl0yAeGILhdJPrQHAuog8/+XLy3WIXG18" ..
	"2TSZZCGg5HX/ld17uws24t2wOoeVtp9a9Y08yrPO3FFO+ljiV1ll1KHW30wIS8Wvajf6UnEyCkYm4et+PpV9n1XP4rD3qtjBt5oQ" ..
	"G9faHGHM1IZHwn1lG0mFRTbL6sFt7bKeCVytE725odaheilRuiJWsO/Ro9v5AQ+qBjUujffds3QXSIOkIHNRHBiHIuumvmP2XQDq" ..
	"dmTG5MWwEkfqk0YNPZrudUdgSlehTNdaW9eC/BhWDhcv/KZtL1RI9xvAV5zpvXcPUCydZdDIX4p1Y8OL2OQX4nO/qCN7H18ynI0p" ..
	"DWgdziyifuJ5FXccCmUZDYxnIx3Zm5fjUL/Ajky0wKdC6q2ydAU91WjMBwLqY7dJGIomRdEwKhCBFKay34l1MGqqzxD7SICKd3Rx" ..
	"uLsWDcj07wpVdQs3ZgllDT0M3SEtnjlvf9+/9FRKUysXpPRYde+eDOizZynu7XesIkfdJBTc4bWbhHg+Hw9NIcDU8v6YgfT+VvpK" ..
	"P4Oc42udwLWLNG2+NpBuSMlE2S3O9kS1uWWjZwj+twtlR+pR2Dk1CiWf20XQuFpOLHy3fjSIDWufUyK0rCTHcy1kjR2tM+wRtnx8" ..
	"9pmYQLKaFXu38kOWsIKgjrRJiippVg8/x9WpMisBGPzL17dAkkjuP/z7f/0opOBLYARkCPIY+usk0KDdUY0aoM31Lm2o11zIIrBH" ..
	"x052lE9uSHzscX+meyCU18q/4YN4eEPHZUKaxECdIV5ieXlKnrBslatZIigiTrnZ28Stofl1UzbHw2+1zVbgdCRWmSP9WJUUb0ue" ..
	"yb+RVe7sBbhtya8IM8JBHf3ac8Fv+VzCo3Wq1WkTQ2/QSQq/s5Dh9Q7XkNQXCKf2EF5OixwpXfJ/c8hrnMtfjxZj05V9DwTr9V2N" ..
	"tbU0wWebmGaDDQQuRjlUVXnqxKcmiAZLxWO6r4TK/H9tCimnUB/HlUG0C8k+fLyuC1d4JBaXEA0H6Tk6P36UibupO7ghySTaZIzc" ..
	"59x7qxxkb6JhOFFGA9mBELg/tW1rBy2OkGaDPhFX1vnjcR0GYB/bh8P9C2/sc1aOkaCeqs+UBGchNQ8Up0cQpteaSU29ZaEiy3pO" ..
	"pze2w/ww8P0E/F2PdVTyHslaZZDpmZOQbaG+1yUTWW6DWlRgbU3UhwJ2XbACXUIi4iFPQxx783+AqMlFHMtw1Rzk0AqPvU9kO5r0" ..
	"7xRUGJgd00y4rrTNkc61bqg2b2CTNfd8ll4psJbk332xfOTE0YjwEQB16AzZs9Xzixqaj1YRliEw62EJYSN/YyskJ0bnmj8SgC5+" ..
	"gkDvsgyeF5SaVySp/BT4RHGRcNXizBJFmtDdT8pxewZ0aL9DOTcCbWahJ1e+/SL9UPjfE1lROQFOWq1d/nCroWsqYi8ks8H0/Tmc" ..
	"h85oYFTvoFz675zyZDsUQaD5GsK1+ZZ0x0XhXSdqKll27jIEkx4RKujePb8Yg5PbbVALVoDuYf/HC1a7ta3Vk2nbbekMP1/XKAts" ..
	"P1qF4u4u9aPid+yKStkqHYyoWJIsb6l4Lj08CaOqKKvxg6Hmi/yY9YxiI0pCUOpYVlCcwLjE1NWcsR+RbdBhpt3uiO4XPfYQpLgj" ..
	"257+k7UTMPwx83XnBrRtxPPbeWo2vKPM+ms0/RAA4NSdXr3UcSzsgDwzhqzAj7KrILF6/Va30Rh7Ed9j1Ja1t8FIa/zB87RuJYoj" ..
	"bMHTcPk0K6q8DAVHJu/Zqb06dMPjTbWSrULK78+/kVQnqbRRYclmUjMHkceMfdhbAypE7h10hGpRtyGwHjDXPk1iSetv1/X4hZzp" ..
	"SWsIecao3XuTiV1skukIuovCMmG2FklKDAOPYp2XfvEZ0LHbS7ob9zZAdgEk9Tl9MyzbMQwS6c8LX16LVzBy975cEVLzWdtUtg3u" ..
	"A4JMpHwT+iEdvIZC9CN4nlDcoNfVxvR8VOTA0qKOtup2QqFgMb0qTpUetfT30sGFe6SkZydC/4UXUKZUtcfclCbu+VWQDimIuv92" ..
	"BNkdEpFzrl7jaJXky4EVg4mYj9pC64UBVDkQCdBu7UC+MtoY+3kl/TtjuhZYmRzxudH01uM3awM59z9uXxRNTHObXdHWiSr+KQ0R" ..
	"tIcx9g8uXHBTlyiwUXlrxBglmY51FKmt8tAQ/FAD7QA/PPWEeaUfGR2h3d2eB9eTDqpIWoVycUiaVgQZkPyqarnw8Dzv8tVcBzJ4" ..
	"rb3CFG90rHplMAMZBWirSKFQ76cxsJ0v3vSdabPWfM4mASk2J6D1D9vz5jiMB8WQtsmN3KMbYasWKPXii0A0ICV1WIWZp/dGsfb3" ..
	"BRG8qLUFgy0goKtYHzNwudfes2cinmYkzajFlKmjPgsZpy02qLc+Co8W/NoBftlwNIaP8ds3GrpBYMoETWehPuT3W4UmTdSjH7ST" ..
	"cGVgm/O6/bgZNvJC+vmY56Cc0JQEmre+3yYXnIaO6VGm0aySclKC1AuiTjTtOcH+AK6FyW3wXBFsQ2LKJybXgm97tvfI5B1/83yN" ..
	"/F3zt99n5QfeB2vua1eIqaVkwp5QJtOU/n6shflNcY6q/zpzmbGVQHajpAFl95fA4mEXe0j1Vz2YyYHHzLZq0rviVr6zfqdPafc+" ..
	"JCimQBG13bBybiM+YsE0bvC5Hv4oBLDwqiJohvlNTEpQ5GKWe+85yapiH+15nevQf7fw5s7dh6FxxwUAXfCzwiEmjgDMLyDofF/K" ..
	"LvgRS3Ky78j6xxK9GiZ0MN5YzGAuEeQD+oSJxSoio7Ga5l4+SVaQ3KxPNyeCBY14e1Xl3l67Am8UQ6UVxRPWkAaFktr/92ddH0cB" ..
	"E5kyI2bfPaRRNlgWT+ianjgqXY0j2LcPdUErRkF/eHtkA901OTEYdTucumWKXAuqG8ZKXVbPi5G9mocqGq3uuQgZxJoz8fXLerom" ..
	"OGgvgt71I4H+Imza+Zy59nav80Q4RjHHABVcVbS0AkoY0Wf+AGK05hS0KkYw2RsGIEfEH7J82D+naJe+Jh+MiC+dIgWNolEgjiw1" ..
	"WhF1qJVocG3JMGXF+aVvLGPM/bwjVWHMCBxY/6f87bTMEfmg15eRjYMpnpFoQ83J4i3LGvJ4xPkqnHADPkUO0jDjv9Rk8+Qw7ctS" ..
	"ZbUWwQNmAsUE4XSWTxJA102z3jwNnBIjLhGcOdMp3QisstmuFRz6EaAkDGx26sDOR2fX5vT3VtQoP1aHY6r5EBhucMSOjWpDWyus" ..
	"w5pRMB8E9CV2LL2DD3po8KJy7FAmiH99fZ80VSeUTzepVuANRCYF8Q6NeE43FXkMA2Tvp0yOW9YbcyESFUJneJQYLsn2joMcbODn" ..
	"O7lNiVM/u6ZaG5Z/Xp1LpB3xh+ucXbKC2puuj8ssW7ODAcfOMrBvad+Y0cT9RMWsWx9AU6HSWRTsBO11ocY08VovzxjqT3lf/ibW" ..
	"U/D0C3+jXQY20RvUdXMuAsDhtEG8uV2m4FcL/MiMtzjf4/ykRKnnmJJEav2pCRQYDIz5iz/AnAbcldnKjddJwXJ39p8crcYTe2qQ" ..
	"2+BExJZmxCZUMr1TBpHcfpwdBsNw2KYvl1uo50p4Cd/wVFhI0eW6yzPQUPeqCvZ2xiH0l7YWyiFJqFwmAwt62dNXyJal1zhm9lJP" ..
	"7CbQTFt+P6ZU770rUkpfgGZ1nPAeVYS6Omd4g+2RZ2mVPFFSybjQZay4rOU8uRFjl7gCAdsXfOKWbP0q1Ld8L7SXKNetY+jgXFaL" ..
	"9lIDzQ8H7rjlG5m+Jjgwnhe+zq9L0Z20mxbzhZY/0bnervaN4izymPcTvqsE04XFs6DrSgf5Y3UGEQUUwhJ1vemLPQ+8VqrlE65Q" ..
	"tPjgnqgmtzTT5t1pvJJKlNtcNcM2zhAx03Kyzk7/E8aKcfT0F5v0GAWAvaAjwKlPAyL3f1ZUwpAphLvg+PwB4DwEAo4pwncQxgcn" ..
	"B20ENoOB95ElfSJe29rycLqkGRl9iO0JxBkQjeY1KIpBaTu2kyapbsDc5oA9yFcykJ/DTjwkTslg78BBeVKPClHT4oNhfUken5dt" ..
	"vz9hSEFPpJQHrgTVCTNA9hrvE5paOjRfXxJFAYLEiGNE8uZs8XgqcaW9J6QuBO4sPJHon8of2ob5d3T52Vbbe8GJ1lOztvffy5SM" ..
	"/Oh0fv+fHcXSHH74MvCgk0lKzJzWZA8Z8L/nXLVUfXoOcEWHDjm5eebGGuFqm2+xBK198EZMW3XjW77k7chlJ+lhBS/EGO3uEYi4" ..
	"QnXGlLiimmb8yA7MhFBoHWLOPLg5WtwgzBrhePLcva4DNXcdZFElLyA5Udmhw9T1jeWTVAGyCOCH22WJmXiHTYI1YdHEj7/kff1V" ..
	"bCV97XyTMJB9tTJ7xpRpwl6V6rQaFE4VECfkk8EpprCGZcNh+nAUEW6PDCuBf+I2r3VOcSLygQtX7oL0ua+neehstA9rA/Dt/nVB" ..
	"WvAb65G+FWR0MVYz2QBBapIMgTamMItcXpccbPh8z+rrnE1WkM5pFRRMVpeRLdtNikaLMNAM6RSKvea1NOY2k4x6KiHbF3hjV4Xg" ..
	"cfdfn6tzGmqKIBbp0sdtCrrbRmLp1xKuwBjRh32KWQ+gcqutucOvSWnfTEsjckHk8sPAfkdr1XGa7aTzjY+LXD18GRXO0WOW982s" ..
	"PfdTeOgVIBhEYv13AwrWo3Vj6Kg5olFUlFfPoGQSZqUxdSfGeH+/dvV4hbF6TAOKyPB10EWPi6b5MDqA5Ek9n4NQMo9NVaHdDQxF" ..
	"M0sNfF+l7AMj67k4ltsyJx/XSupemRm/R/WHgK/2OlTBwDWUftHAPYx6bWG8BB+uFwX4Uynd0IrW0mZ4DldWS0vA8UTOQcZb2K7O" ..
	"I9fBtNICRkTieg98WuZc6JhMlSQHg1saOEYHfFe1eJK5lU71WV94twmpmrIgXKZxZ/LNOEmU49vb6blyG22rDGJaqUnMlP0jaFNH" ..
	"vi28npYc9oLxb2p6XLOF0FPUQMMcSI5V4UnKo4a0dYouJox1n/SjpWNtXZlKxPen0pcRrxo3tROQE9lHkpLN8rvGK9+ngnqKEBbw" ..
	""
local PAYLOAD_P9 =
	"DBxflzJeu7oy74fnTcgCNmvUwZxiO9Muo03H37S6y5n7m013XrJZ8RB6Gk9Vssa33YeLvhapzdjLXfNnj29kd6ARUAiorulzfhgu" ..
	"HxDGZsV1zgz/i5YtLKf6NaT2xaP93Gk6YADk8AOZSRYAI8fmAh3cqi3ctG3gdtI+05i4X0jWkPHzv4Iw1nijanJ0d66rVJ1lvJVk" ..
	"3Pr+d4lSdsmp7OtBaaGeO7EcmDNBw+CezsfHZbTzUhYWXFRx508/r0W1CDfUAuVsB6KJiCkFVOmheMffUzRhwYF5FKNH7sKyKTEh" ..
	"slAQMo7XBBvCMgaanANjoNHsvF2JRflXjmCNAijp0yLlyXGIqn2Xrnt3KahNSlJVsHtqiL5fcJZJyjFTCBJCNyLjTxCv0vSUtBPg" ..
	"JmNdQRlG5WkgCZD4HZXE5YDchCzyKhKT5Yr03Mpmee7mq9hy++Uy4c2wfPIpfdXR/OFr39vNBcxlS1/WU0RYGBtBnLcm7tZdDtli" ..
	"anC1dwRm1QOb0U4ktRYQj3/Cwv5dUuwUr32oadUmql/klowYcVAQVMsv7jM1q6XMjFn1sPThtNX2ftSA4UeDrbu6ONV7+ZKDpFlg" ..
	"q0ts20cNQp7PopuMaMkxzMVVoXng8IUWY6cgBUt50eJcNF15RD1cPqMQpKRDPCCd39ifFVA/kPXbg9qG0/eL6LfSYKYNX0/KyJ2h" ..
	"oQOX6+6VfP/oCuQ45BNfj1i4+dLC1Tpn6DGgAFINfrG/+W3sQ+YQScoGOsj4T5tHKDA6FpfFN7BE/MO0sCLl/G/7ioHcw5Dv07Wz" ..
	"4P5lYxp1K7elty7aUE9ePkG1hQ1d3PxPEZ3xnesqLF/PobnHV1ZlxJ/brQ1uLtSgq6UWDV3PWn9oDqP7j64URF9Z2kMJTBAF8xqL" ..
	"EDqGRW0m0M2yJGLkjRQUtcKetEiHqGh5WFpR5L1jYhtiXo9Gy7lfuTMzw2JTyDkIkOsh+Ra9pMHRcKW9n4DGRsFiykvNL9lYVGYC" ..
	"ZENnLKvUaQtNngMRDO3FXq/tECgLF43LaqTET7+5b8TVKBEfln/eFxLvhowyjB/8oY2KeUhuncftjgM30NQj9FX22D13soEFRrqA" ..
	"BhFSK+nyeNcOoppvd6BDMf0qrObKZ7NkylzuISt/rPUqnWmLoH2DIk7wTwfWbBvy66pyKt6bCtMNdOlEwmxiIxGqgNrA87o+OvJ9" ..
	"AV2kb14zfeRv0sIRK3kTUmkeu5BGuQL2/2UOzDKXBUommHrtb5QIH+RewdXJihPT2uY9A22jBZtjjF/akO7syInGdsvfPy841HJC" ..
	"XW7mi3HWF6eD/VlhFMXyjQsW60VsqMp7ER4QSoHoBZmN3i72AqBRxLzBphQke6Mu2HtR4DFIERp9m8Ws9Vi7BSeIzF6b0IBiKOXy" ..
	"aw1JUmGso79/61y6eNSTF2UCJvWi6CDZfHjUKjbZbQEJdqQLAtTgYyFeQSrksfDxHpgpCS1c6a/LetxjRSY8SWYeJckjGBpX3irK" ..
	"Cl4syMVjThmf25S51eZeaYTzlp2mABIC+nAzK6SwEDUVZ0V0xTIr9Ee0hlalAULnUP6DRHmiP1GZdHH7CsD35YkSKpcaDCd/fiSR" ..
	"2gj65gAFQ+d8aqG4D9yUol1fwcwuAnj9g9sEIhOujazLhHxUliVvXBtSuzQXMBeJ+xOPF4fAn2hLqUO7onfwKNhuIT5lg49zT59h" ..
	"pd6ClRqasvJJBffpBxO0eAfBrT4Diy6ALafybRFSci4tgtiF6ly9OID5FSt7dtbyvqWYFSkgs0PzJGBK+tDEgxCqpSQ8/oMtP/Ff" ..
	"2LYBEmOag6348+oeeNcYvhY3p2WY81H02wEZajv8jp7piRwhPDxYP5aSs46IvUP1j54DBgOMuCkoMb6UBTZDjOwie/JM6ZcxjAAr" ..
	"qybOo16iqeaWj6/M0PSohUtIsKZjTmLjZwE9x/x7J0ikpu3su4WqUNVVFuzX/9UHtOwoDaLWpKqpEojJepGkwBXL3l4kCmGYBBBo" ..
	"zCv7nUluuj2s3V9R3G8gCwvVVvF3e2o0v9jCNJw62pOM/liOqAH5Huf2JuUdZYU1QaEIqKUdFd0H+ZceHZIAV6qfW48Ag41vnWHS" ..
	"gmO5vhQgz7gnlWN5TN4Yjhd7mPSEZzdv3CRqfuOnv7Cc+a7XF+BEBkO2fHlKJ1BNdZRtpnDIT0ZLL8VFKP+1RZybIiddqGw7+1GK" ..
	"4kpk9fy8PswbWy5jR00fGIpAGXKmALzLt3SVJSOH1XgvSDiQGBZc5kuAZnClEHpYCMqangM5qRmdXx5Br9BdgBkK5I8421NgGtPC" ..
	"CHKUhmShlVNB4q0RF0jBVsURgZj52ESo5wFOWoO7B4yGQSbKWl6keT9A5oGgMHOxnq/6uGl0ON3ZNpATCYMfkSbGzWy/vRa7DQQQ" ..
	"9iotry9h6C9nww7MDhTU+ruAGfvenUnR+d3SQ1zOCruWy9/+6iBn+UFEGwUkoOLViG5wTiFTzcQPGEQdx46bBKfidroI8S6f75t7" ..
	"QF8uyhZpWrfWXoN0dzX974LiD3iSXJWPCTDNRnlW1p5hBx23z9sRRWM8Y9C/6+NL9/KObAz+oFg99wnddbT6ynRK1BximwxgKmpe" ..
	"Zf4cDgfaO/648/C6pGsBu+2wdoQFEwiWPqZlZXjbQvERASlIdOEnjZIMWYrkN4MGPngQ7D5xvlKHrEYjkT/k5leGK6Bu1tOd6o4h" ..
	"0UwSjWfQKRJ2TEdrlZcTki6Om4bjx8RxMGVQO64W4n2rW9y5mywwTM4thZqLk9GJ1vd8pQFFEMi9nU3ftO0XUJkExfaHd2AAGk5J" ..
	"fi1lusqeJYihzKVEktnwCMb3EdiYzmpaWd4F6Ga98F5sF31LJ7DYUR06je7eYJruMv+MXimikEu0ny/HdQuxIl+WbxcpRJv8hbuA" ..
	"CmVaYPwRRk3/TRLAb8wy048qGXcfKkPF2VCIeFE68CXTAXUhHZQ/pEoQqjPwn9wJqaTWnyxXO+wdw0ZG5KRWxcaGQTUYoe2oRzWf" ..
	"ZAZXuIeJVCXnTZWsOlPixJRGw0PtX2FxDsgvF5lYNtRXsXGuK6PpthjIiOXu7CmOSS0PE2ONsTJf+AQmR6JTmBIbyrORapPWlP5e" ..
	"XSx+PQQ5lERQmLwWMpiP+w4PWKFU2vvMRB4cIa1WP7dnnRMIL2YrIjZQM3PrUZKApyHRp0/ZoC8luaj8GpuH8Z+eak3B1gBZIE2y" ..
	"AyHdga1CuWvQkMv7CwSE2IBbThj/gouCO7LEPiIS0+IaC00ZFO+H/Wnoi2t8iByvV+TfO3QODep/mWo8mlEzyLhdC1Ow8UtTI6Zl" ..
	"6otyLPQ9KEp4d3NWZK12uzkM7LUD67Wajk5kcgBmT6fkCEL8cTQJWm4V0XF7pmiOtSxA2NfL3/OJ/WoPSP4WnN/QFSscJi0BKRf+" ..
	"39obc0Ps5MawUWURZr2BvQ53eon6Z5ZWfNTJPX+PQYgyKE5RT6y92ALZX+rvJFRidx390eXMby+Wzxl1YqdY0mvqVwqRNhd4OU3/" ..
	"8xSKLoM1ehhVaNJuos3JoJpGirxzfhmSndbbuUTa0Cm9iChhMybgAEVdL7oOCqYKKnQGK4W5+uTVy235MDCpKqoqn4mz+/PS9TxF" ..
	"pWaBDo6Fy1m+rSoBP0h1RuHnCCTWEsu3grdHLctdxeHCoux+tDi8rl71ZMgwlacZYeFqj5P40+IGhZ3uDQwADRJLB0PeH+28ryWK" ..
	"0bQWp3rog2ITsIYrV6DZiSHBMIe3yaRy9scip6h9M8rQhpPe9oa/tVv31z/v5Ed5HmCxp9sMGUFZuum29XRSJHcWzKUbv3R/Odjy" ..
	"PVvuSSF/GleOUjBf3/oxNViUoGyNNV7hb/0wWPbg2Re6JqCoa8hgh26te6SVsv7W9RGN370JusJLnhgzPRAuutPpx7sUbs/5XV8Q" ..
	"gdSiZPXWNCwKm9pup1ywJ9+fU9QSrhIw4zobPsN978s+p52TsTOeaJZmjSP7GRrslA+65EOI+j4w9xgbnhKpwpgwMPiG09fxESKx" ..
	"ln0IKX9wV7fxTLJUo9vdlUFNNeN7o58b2nigWYPn4brvCXkdTYPa2lRokUPItdRVO//ilaz4KEnXZNUAZEfQQy4SY1x7XSqj3VYP" ..
	"DFFdrPuiHt0U7+hgLVHCFeKTGVaBk6KM9VViy7T0j5pbXoo0MSx0WT8HFFnAsKGXnOe0rFlkXJMT07cEIJi4lH6O59zpVgupLVcE" ..
	"ogiM/gs72ho1TjYTCLrljz0fWqJhR8qZz4CEkK4wgewK66xr0Ht0lQHF3f6u4cbGrZY+Obl4AbyEwgW+LSUEbTFhuBP6iwdPtnbl" ..
	"54ZtXSSUlu2+09e6dnHDA2EGcTeFzQq3EEC6LG3HTNvYXr9UzOCuslR5icoumCCWEiZwpOxqNf0Xz2Msn//KpVWwTu8KGZW8Od8t" ..
	"rJk87JJsT2nxrFDSrs91OAitQFbDEbj8Ay8KcJ56xYfsJBJTbCt4Izp4AcEh/ErMQ1by+zxQ8ZSacofYp2a0IqlQI+qib7WU0Frk" ..
	"zJ37TfG4LgNyAvWUufhoQvbzy7hNDPNGgGd9k2y7N7C5bsJNdHDGUZf7avPSDByDF0Kgh+fkkAwTbL2srIfhg7ZpZkA34ke+R8MG" ..
	"TflmQ+jIQyeSFHwpn1KCg3A/ffDzzsfK0Pd2IJr5S/nPDYJD/v2jDamWdAsPK6OINDS+gy0ABtxAerdM1ZJH72OydiJie5d+ERau" ..
	"mNEYV52Q8xZNb2YnAX95DcXiMAbAdqVH/8v05SqZRv7NyVqKcLeO4PZ+H3J992N3eZNJOnMCqQj/K2BI4P5ibMZ7np8wr5GmlP0q" ..
	"FKuGG8QTWA9Sv0QA8vf/HRpwEqzUWXW2kLCqD2g8/tDtfTKiTaQMFJgyUY1K+jpTmEQufXtRCsEpEufMUraz/EqCWCg8+wgpfMhC" ..
	"VIJ7jIvDb2VwkQQaInjZ+lKLzeV6QGk36Dbq6ZZehHZce7kujdyjw12ve1VVlOm3CTbEoS1XsbM/P4wsFFfOwmOWeDZZExhxFy/5" ..
	"iewVGLoN4TtlvnMFLvIAT2BbRwmX6BTID3+FfLnlAs2Qk4xle/eaVE+wunwzZDK/Y8QK28dwodA60l03DCnV7YocFtHdR79keDes" ..
	"GZzJ5OY09gUSi9B4yqtlVBrzPBa29Sh07SIDkVtxchLCCl6isWYnS3mx37Zyre3pPQjZvJNBUjK1Ue6glpW90M3Cyc95AJ6SkfJY" ..
	"Bnv17wHpHjrt1OzAmtFUrnGJ/YrcxOk+wy3HKimLuovkqBby9Z0iqp7+e0rKhxHxkJMJHi3VjCDA/m2WtxlBTJYRw587H2yiGuHN" ..
	"OFdmOBr1F780J26/oz4k4HBs77kAhrRrplb/IV5cKjF/A3rC30SuqVYwLQVfJtP4lS01ZjCal/C7HRYpuqUsU3nraPKTZowv97Bc" ..
	"efaBO9G+ar21vnfxWzabYLMSw6l5CLX5H2h/IIXLbiFYR9pW13yTYDaWX/EdG8rLDDqOrHithp7e2Qw1k3Z64bHuMARzsx2IvRyJ" ..
	"l9INNYj1LE741l9MgxvEtKN+esFbIKQIoinYn7zAwBK0yWNzNiDdZtQGhan4iNEvP8zW4S6xtvsgS8V3fdUgZZMP4hfjV5ZF4HHN" ..
	"zFTLheGr5R/P+r2F62kk+DVm1xuFSIEXj5PtBPzfYIlikYCCKdTnhhacOq1Bt9tq/ziG6bs9wK7l8gnHsdDSGm2dhKSgywxK0RZl" ..
	"X74VTfqjjtNOU6/SkggIYBU+pcGIBy+b0Jf/EJ/JmWJ7LAXX3mnUj67axILlxLTtdbxA3VUFqTSrP5n3nX9llAvo438baB6Rly5D" ..
	"9KJkhDBcNyMTSslY3IbwrEN0sAD8farCGWgcCeppC1TYOaxu7Vd/0QoHDPmTlhs0pg5vDpY5pwxCpllts42Jyi1ywPMTKZIVRNVa" ..
	"kzhpLVDlaGsCcX6ZMVwynVtEwCxna2Mis6+5cZDV9nDmFaB+opJKPEPR1vq4XAierd750s0YStBHuQ8lBMdlOdhz7UcFSoRJbYOj" ..
	""
local PAYLOAD_P10 =
	"PxSirwnkgcQ6jKcEO3eAes9+A28bOtPrk57W/fZAh2S4M0eeuJQDBqjKtc052tqLg1sq8vqGGskqL/wVVMwXlv06o4JetehqtPnG" ..
	"cveMfkTbOjbZ/0SJ2c0F7Iy3+Xn18Maq3xeQkcOuAYeH3NWNZfA6JgTWkCwBwbcWTLMEDRYjCjSqOsuW95C2wnQf53MQndchxz51" ..
	"gzlCpbk9tKb6a237GlsbZw4puhPRU7gWA7Qt8NCqb8kYXhQoY1YWUU9sv4HzQUhT9wqkclIJOsM87g0KVS6CwVlDk9i9cjerox/i" ..
	"4DJRWDqqZO0QzxxGxZizAXlrWPQIeelCWIxlWgDNCpgShTKXdcoTWW4EIfZaw6LDN4XyN+W7BsSylthbIOwmtgChnckRc+feJy9J" ..
	"iA4nDPKwghCrxSGFHMOpWaXJjqWy04/BqyBYDY5eC9qXF6huaBDuSjvMtywL0pQASD81Zk15uYjDhQts7jmbsWwX6SYl4EHWgOA+" ..
	"Ji52gO1gLcsZtGPQLRFVa6ic+nkg8bcYL2Bp5Qo+coM15vAFEjF66ca5vcLg9NdRK4AlFgXjQP+eoWsHn28MAMbpoDEN+PpmU0/V" ..
	"HrdWlb2kDRUIXpKMvB9g3/kpwrTQP8KRJRA2owrkcrirNdAqi2gUQOGXEJ9UhwIGrlOspSFlBqQ0pXCw0t3Z6pY4U9vneIkbRpQC" ..
	"SyGD/GGECzCgVVdBSkQb/3NdxjOJZe2Plpz7RnyruTJ2t5TIpBzx+xmbZf5iY98kOxEWf9Qm6hklUT6O7bxlSJ/ZjDUXLKTQFdxk" ..
	"PzYg0tF5KhaT3ub1jGo9oGFyfbJZlcoJZMtMXqg9z2MUtU0ikVBCy+k8ZXUt5vaaWUb5oNDmzEJctDLreJnpGlteQPJKWuNkys1s" ..
	"o1q/bN0b7ITTUDVQSX1b4CT02619Q0QitzCWb8PAsnLp/ZgNRG6IlJ28vPqV2ljhF2mOmAQBtYVNS18GjYxiZkJT/mraPOzHbaxL" ..
	"uvGLTEp23NdVmi57RQjpcDXZG1JO2a1dzwHxXy+J2TQAOb9Veh4V7Bgi9QQWiQylGTAB/fmURnjulAbeW6sn587UWfivy2ajdATh" ..
	"N8NUMrNK2CbkF6OZJrR7i1F3yUsC+PwSh9b6YldRXE6t77YNXJ8o3978ZpHpY/EwWNkBjZ9M1HfRjvCqSILNPHDACy8KfhckaMiA" ..
	"blG49JFXyxShaoCg9fYMnGE/FxfKUGv9KSMmNnsmBqWnVrcTdt4KqVutMD7CIMER2xmdGnSLmMgyBOGUgTwyp7bBkr/PlUzSmJVT" ..
	"ZsvOwQbjPBn4LVafBWXktGabrBVMaGGmm97Hn51I7fUq0T2k1tPGgMGfH2N6fUK/JzTp9GUmm+m+TrfEWla+QaGuZARDAo78bCJ7" ..
	"Q1zMoraP8+6kCrvx22QX+56/Kn9HNicY98Ilkfaq9I+C/KICcSLBhJeRphCbj2rqVfQ4+2vcPZyTVzDoWNbb6vJXLR1A6Ovi+vuN" ..
	"25leIwnkGmeAUAP5AmQUjKoq2dm4IdHjqo61JrOR4tHcod36LsFIQ/A3c+WbaOYJobMF2PitIMnXgb0c5cTNQh+DmPnRvbBlBA2t" ..
	"UxKyMmQmQ28clmRHt3lkti/g1evie+T132FaIcVQ9qgh8Ttby9Wvo3qK7JGMQaW0Nx6euJErg56yD5b2BBKQTYgx6s/TgUaNtw2Z" ..
	"219eTeoD2Cgyn/X4U7eHNUY4FqFv0X/rCDMZ/IdLvGEqyXmyYW4ueH+Jo/EFAvN6qDO/qSQyWUDpxTMc0/cDOgnXqlyr3T8Fd864" ..
	"bsZgtrIElbPDJc2ThsX6cIizfFK+yq9icerCrhz1kNSIz8wWeliSexYb2ObSNPkngCgrQdnNN1UJtrRAmUjoUujimvX/y1TaFK2t" ..
	"yz+S5asnJi22leKFwKe8GdVfJhy5jVf0pvOkirDYrk3hbMD8sM40bHsUQhPXFVkjysxBohqH9eTy+FUi79oaJW5Kl6fOec4weCZZ" ..
	"BoB+3iMCDVFde1nAM+oGpOiPuHyMIqoUSuFr/85Dgd96MbDCTStIXaPqJfAw85c+8mGwZKX+T4kZ5F6QHKRx+OBs5gHaucaIQ9Hy" ..
	"GBm38bp4gdwG0IE3t4Oj7pfXInyzui6vlEyu+DDPImDNBhNiQt/zgxLszskPz7vLUGt+wfIipUKmx54eUfVC/LV1NXVXhlk7oJoV" ..
	"oX2v70dOYIdWCgQHdBtx+v0mcTE6f4c9JQA1fpEjVtY8Wa8F347zFWpcnj+/TZfFc++gx62sb3H3k/jM/kxv6yBsoX+v0L9zXHyP" ..
	"T07I9ObMlQGGm//5vht6L7PpxmM0up9O7YNQd3Xg/0TWqNklo9ba2dGHfwX+vQtRDQJrWKKLCJBlOLipqeSgcphm87kOf5ZlFOg+" ..
	"WYNJt06gPBS4mU1eeljIHNhlIHIAdfxZV2pv/OXkGVZHsYGgy6P8FQJtBXiM/F/4xJ4HMOs3RUoBhB2F+vtI7DQueGfCrkrD+h58" ..
	"bApLX7bwMSN6phVNw+sbBGNmq0K5CEN33rdfM9jvenS2Y82trQg0Yub7MaRuXWAGN0X70ylA0eKxPoRdyAyIggXCGQ4DVY1ttKan" ..
	"qdcNYdNnQ2eaMIztl0KuZIwJLVSuoVkQsjyRxm7KZrgV1rlNffc/5LdiU6OhKhmBow/14Y1H+6+ifcfHok0xn2AfPgijW9OhcOBh" ..
	"jva0d5kz90Dk/92MhaXXNxT/35iNsmj5cWmQZ9pz5dbXZ16sgANaX2xHpTutb66MZ5Nom/XLb2mBEzOzy8ASmay2WSCVNylf98bc" ..
	"BfZI4qLVYv6BYFVECdnCCcfdTg5nDkOyLDMWibLCBIlErwP6rdlMzrAD2jtJ2LdZIT8pfKpLiJVtDyUvmIeBNHfgOgepvjZGAGtz" ..
	"fuqNJjrAtrB0ol0RFGAIFvuklJ4dwiDxGPxC231o0YVxOQW9/UKlvRu3PXmAP5QDHiw1r0c5HyW0twqVjjyh7wE30jINGd/IVVIy" ..
	"5E8vEHCI5iw4wYMHoSWXLlnPr/6N0y8LKHZE2rthoXUcwn7qsi8Vpc6QpD26crWHSI49gey1/Xn4qnSpIQgRvu27Rm9TVyjJn/HL" ..
	"vLrUrRrckh40YmwqZ7QDEPrFkU8ld6dIV+a90Uon58/VMADFfRKv0Wh2+s+iiHkXEQ7T1iCtjVIhuXN7T2zGHCEzlhhZlQQ+MZT6" ..
	"BisUfT9frgBfzEtup+fTlTE5qnimsz99swJagsCI28eCV0c7H+2IuwRyGjdnCG9dyznWO8L4fDdMDqN/1EBSj8CEodsksFj9D8PN" ..
	"hnnj2bkVJDqZnrGdhRn7PWwZQ2wWnFaObIIFxPow7JJfU73pknzFb3e1EbTG+Q61LA1mrWOpmoBkbm9r0L81ob9LE3lsVPIlXJhb" ..
	"zdt7hQ4CDkm38IfM/GpMjdXpvFdc7iFQVkfgyOmUHAkoMPJbiCaxl1W7kuUKm/i92YOk6xe7aY0obVBoxTBIeW/x5NbvCST/HtNZ" ..
	"te/HPmnl6ZMXF6OWcSKu7jgLcrMNEn9L4jV8JpJILOzS5Knr9+njvhbirHjoDZynD9olP3MmyRbFX0GgrTeeBBmwxAIEPdPa3lCs" ..
	"t0UUdIVaibdSHRU4RNiy120E5aTHS/la0lxn13qnP0q3VNIlLbXolHvpXv5PDKaDpgD8rJ5qxTTjT4a+ArHuWl23KP5gYh5v/Qx5" ..
	"9hHdtTfBK7j8ohOOobhlRdUvcd+4XTbQV0rODfn9pk0qS+603j1f9s4j9wAe/geXzrT9APEFzHgb2oOx9Wt6QFTwDpdfRfEcp+3c" ..
	"pCnEaMinap/wbVV6rnmI88g9NM7apG3LZhnwN6nogqdqYYt+VXABwlRNMQpV4rSbJ2OCXf6jsnP+sBr7nBGSl5k9b4oHlSwD4HV7" ..
	"bn+SWXtUe3hPePi19IFMbwG68hEkPnQqyIVZmIPcOOd7V49/96AMmPCUyVe/xGYdzq5TjyhaBD80AxGwyCe6wOYGxcxhcEm6f0K1" ..
	"8bh75Set1y0WgYvGKrOh7vjUM/2WwVfSvYbGlKnZk3eg6q/siJOKAH74zL2SC4dhRfILAn8aEftrNPOJ3uBllacuVfaL46PB/V2J" ..
	"3WsFs2hr0eZVofU4SEkSC3cHuWjl0PH3iQFL6ydqFZI9YDM/ciwumYKmKwML0vEyF088Sxqg8pIjzBkZarltbuvLRybrdLm/dr8n" ..
	"8XIz3NAWUaiFDLeHZrcCz4beWt6sXtkHrSRqC4GILg7CvIXaaL7iRbcOJSDtiaXwRiACss/NAW3A5K+2e2wtD43jx42Mj94mlgJW" ..
	"TFMnd34ZmQtdn1LsRaXUDPW5y3orVvnNgiWzptA5kt2VKAwHn3/w/0e+41XmFyBDGO2jL50Ugsqoon5Dqij5eWoxuwk1QOMmUTub" ..
	"+YgZ40xdeo3wmccqiOUns5Mu5vu3Eer4W6KuqLo5EKjE4jUMxoED9w4nySiQVBwG1l77qwclsclN+coEOrgGjv6nNhjYD3OMgCI7" ..
	"wY6ZgFsj/PIXMrAcB4RGpPR1IyUC1w4JhO5FqGH7CEIeV6Gcg3AH8pEnPkHt1eWqtKbxx/0HhP474SDVbjXOUVq2YNWzPSB/ofeg" ..
	"IYVtkqnbL7KWKYaG8NHQPNQ4YdWrfzgQdo9B7ywVzT2jHJ/4yTNqxxx0AJE1Hq3afjjYwziBrm6dwPlfd5gVhRUGx/a46v1omt6U" ..
	"lpcLvIino3TUAuYBSCZFVaMA33LozYmDmCZuxI+hfXWsug+OoKsGfA5YYBQovJuzOYghWGluHBD/XMRmevNaJldNltaqJMjCJnRu" ..
	"mTlQOXvOW8hVBELYmRjg1WzdKhRZblnaM+aiHFqyWKRSBKf0G17noFJ5tiRhEytgVKDWUUEh5AXl5UrZi9DVi4Ym7p2rhzASQ0sk" ..
	"uXeqAuxN64GhdWQsakaiiijUVJsznIVAyrK2sCJh7yrOui1FL2Lum+/qvb98Zb1hRG9UQINyaF4YfCa8kI0pleV/gWyQuZfxlm/b" ..
	"PRqlg3cDEH2qtmLDDl7JY6Qu5CPA3vzQH0xFLZgXHkqn3VGiRObpB5c9dk9aSPUWj45WhdUnRKdLYjzL0sDv8mdBEFILpzW+0ruk" ..
	"UlrbPgMuKu75E2eZAa2/ik4nZo4n05OnbZdBkC2BM0FjksOsbBxM0HFot2m/ce2rULwLbDPuVBKigNJG89+RozcWVqY7wjM1Tsvj" ..
	"XGh34H+2SZIG+PRBEG9ofE9+PJZKswbb2VDHQDu5b1jvCthzrgHHklAsZocgyRYCmddYme4JgvnCCCO+v8QessChcJdKTZDHIs/I" ..
	"i7htEsuaf8LHFRahAkK2QPWZNHRwUi4a07NmuilOk32Tt3IytfH2jcDV+LpQNrmlLqFf3ZVX2a03BAjDVY86FkWpnv7r0vro+rZ8" ..
	"bKrfpQoyotZf4v1SuWotHoiy2nDds/NCqx0CZtWbZiJwAF1qlL3dC8sUpM4Wt2qe3u/S5Mre6EJfZR/K9BTdXGWFFn4WSmSyE/ZS" ..
	"4pojrFGbrnyi1P97k887E9mYyOeNjrFLtKg7idr3lRceTgR3ZVY+K41l3JJmbQhKJcuMjM3AGcMrSWnS7u5joRDFw3jzbKc/oUkZ" ..
	"EWXyikt+TWCknmIythamTRCSabvArcFfbseuJ34rINZNks0hW7/igdKsEJOfRPuxkrsBSeu4EZdZXjD78vOQJG0PNhExzjj4Uqzu" ..
	"qREeReiGeyHsbYYPp/yz49tcbTb7r4E5l3aLsfxhfyd32v+pWyO4IGivybrAbS8T2hD3KwUs8pCoWtgt8Hq9covGmbLZvsaKUa+H" ..
	"4gEqbeh1WNH7n/tQoRdyeOwcnGodQXMFPVrCJIzxDj2vBiPMyNQtOV6mezGeUDRfZuzTrdKNUo0slIiyvaKQgaMJ31UsPt2R7FH9" ..
	"o7LMhoQ1z4mBh7Q0Y/UAMW4JRlh62uj6KDjvAwSNyu0qp4jhKuVI+P2jEDR7VAYBzHch/jxoNdliESWwz8diuhk69JR1hU053Mlk" ..
	""
local PAYLOAD_P11 =
	"nuTMbbrR5dnQThN3ryc0uBpEEuYF/2KEcl3mFeZtOO63tJq0ZUZDO0ZAx1MCF+cecz/Mb+WN0NwaAlS2DuaECYnOP4SkE0m33+MI" ..
	"dXKFSGDh+lkGOdKWgH1xAjokWZnLSyu0h0ZnNTLWECwvHvllBJM4VwXjasBJTdRwFspvwOii1PbrEK8W72OzdSfOM6qjyNstkdB7" ..
	"4ZJW0sIVIFQiIUmBplQz96m+u93QrlGKW/vZpAUWNSZWSPjxs61aTaQFvdLSQvtqj2Bzf/NZ8Wo3w70zPp7oFsBFoK/oF4vZL0Sd" ..
	"hr1r3+5JW9FRANvkerJ/vuvgHqcwjxzBrKrAyoa//LdFSjn9L1bwzJILOFUCZuMXg3Piaz7RCFoY9AePlDRR4A1NpfiZW2ZCw6uP" ..
	"ny9DgDkPQVLWSIjZIeux/vaoshonORR3xqaX9ZEzM8mTFycDsNusjPMO5OGIoCIZg9hAuZ1+SaKDUCJ30+6jIoiu6esae76krJTK" ..
	"j/7tAZmMXA2VrkP07y/IasLGmpIAfcOqm2pLmOYY5EioYukAnV1uip9ZsQyS4Z3pyqMGJek+QqAp6VFCdK9xPqmqH3OMdN0bENll" ..
	"lVj5wA7kjXFCNYrMahFpJaVHh0LO5M45giP6i8cGCC/mXc1quUfnEHxohhVVjwfWyK4mIJcm18Ao6QIGhDyeVO6OABhwIu/5/waH" ..
	"Xdsh2g/8fTFHZ+OfP3oVTtEtZT6keHgZ8sI+OeV12QXYNaOk0a+nPiXpTnFEE7hehm8KWGzFUy8B1BEi2geVusBVnaD4kaMPxpf6" ..
	"1V/8Mylc15vROilMqBnSbBjotRvlFeFltI/alZM+/EobTIBDeSvI5iMRtW2CkHGvBU2r95aafa3wSxvziU/4P2/jmDedFUNH4+1h" ..
	"z0iK1+BevogxMDHAH0HEfceu9D+RwiieHakJs/hDR8WDkIZ4y9MWZmR7oqt+Mw3m7M43ctMSKN/uorJpO0N7gEK2X02j3jR+PDDd" ..
	"YMIjBymm3GkQdO2hrsdYMAwP5VgSG5yXFBcSVP8XZdYR0FEmAf7zCX44vG4nhyLs7zUISF0UdN+6AsTCfGUztOe5+Yy5jLsygYOd" ..
	"3Yv/0GiYuAgRjp2r0kNY0rhm2epLmwOaeEmf6nM+ZLeVqQRDndHnAoZw8AExyGWjoPCjH1hbowkLTKWNCewW7bkaeIG65GmnEuyL" ..
	"sSWCaYtkkpbKTUtuCeqGgAlXJPFEW+a9lKoULKf7HISSQOj9v1mqAfyNM439x3aHVMOqlh2CugV51XfFQwD7bRqduvjoYkLjqdxd" ..
	"Bz+Mop/sAGrcmmTrVtFkOjKhPL1/jP0RvprbpU4phaUJ8swXpuHux1P5R7qHjcwnVPeZMx8NsDMzsH9Q8/UAnEpFSIJ4TX+jTuiK" ..
	"Bv48Hk9xe7RAASMpEtW9QaBQ0v1m0MWRLoPr36ERChYsev6jUKFdJLGmJoNhyHah1J6e9Bx3IDwYnvQYygOqJf2NOfN5JaOkuKxZ" ..
	"V1LrKSf1ePyj2Pl96Dz2H+/gc7mQZxJ3nhzylIXcLosLjsnC7SU3GhJzoa2NZzRQFvRfzKR6DB1x1LecU8pddhQvo0YZyrA2comX" ..
	"WDvwp3OJjeC/4HjX0myKJ2LmOIgE7FGVDoO1H4lasgt54YksEuYliKTrUXCpn88Ul6L+IG2HrfYHyk92pIqPgM8qxfgWilD7GHYW" ..
	"r+qRHCd8qbnsxTgyQ6DvvBl6VuG27RLsXKDl5OzZYqAsHFIvrQYOxwarKnCAkj9f2GOz3fC3mnog3jIf4iuUCrufgUvvAgex4nSa" ..
	"wFYC6Q7T0Nh+YCe9DIq7VJrMsGOLHnsGEXCHl6xqwRIJJBAwSbJ0YZOoHDd6N+fa2ef9lqQzL5IfGpHgFLlPUviTDJmgAeL79LVM" ..
	"/VUFuk0T5TsnZsK83+1wgcGfWr+edxpKrcsGAc1w5pp84KXZ3Lswu90FY4EQi3DP/A8i22XlwaJut6LN/WC1at3fdULMu3yVlhcF" ..
	"I2dBeAmp3Q56GCQoSKiZhA52s0PXQPT+HfMP6vOWHjMtGRK4eKXOjrFQd5Yg4yF460+fVM8B2Xp/2fYQOevULFXsgQ6H5kyt5u0u" ..
	"s4QfTKxLea0lUhHYe0a7lzWm+7T8Rbu2DnsovjGLG3oeHdnsgzRIoAbQPpt2HW3yYavdYjuA6mLxsCBEXBHWSb/QiY9/aDGN+cec" ..
	"rK+ZKWpKHQGFmf9oeMY6rawskdc9tl8nEoDLX0tXMBp8ZRS0jkKDdQoiG2HL8JmfBngDKp8rizZeKHyTDCEL3npeT6gATCP3Ly8B" ..
	"AsV/gTt+hGz03ruFLcK7S1IY6dT+hizJHERCQpwYWZBMHNLXGHu8Sg1oZuzDZGaYh8YRLxDCdkbvd/erldbnfFRgo3NuddIrmhVH" ..
	"U508l/NLvojUuycAN/HpsatWhpcD7dAaQD/9DduIEwLxxsW3cSohtQ9qL+wjwZkWVjSpf5MSRYmehexkO/d5bCxShk3pvzfH/Vv6" ..
	"B0IW8z+Z8nUTEY66LRGWdcXi9ovaNDG+QgFNBhOtANMrEYvcAAunTjauxWowduNkZMrD2Xx1T3ufJEL9A76MFrhJEfqnYqd6CGO7" ..
	"gotoUx77q+SL7SqzF0KrK5c+K42NTExWNQGf3Hd/yoh74NIklHADXCF9u4C/C7J+QWWhLZVjTpLScko+eUIRb/plYIK4j36NQ5Zu" ..
	"ir3e1yTo/oS82mboLlT/vhNI7Q41iXln1nVsWXEXP2iTxFOQ+ikR5w41nk1AJhOB4M2jyQPhhgQ5b4b/Kuq7Ehe88PN+xGk5uRsI" ..
	"auApPdeumN7aPajYZL7F/fS3ttN8h8fWkyxY/RhoD2qQgUc0z/UH003Us5LkWnoO2bxx5/ZA3/qkDlS1oXp1lMf1tc8fxrVh3v/4" ..
	"QbViYpuzJsD4xl/MQQexVtklJe3p4wQTfZvZIkwm5filagCyX6YgvRj7poXEfPNuPoJaG2k3DjdQke86kccVbx00TGQSvfc0e3lX" ..
	"aObQge0efhkTHsxEXNI0ojO5t52GXleuj7YxR6kvZt3Wd7xqbv+ZShOXQXmYKkUcI5ePaZJQOyszL50CRFX331Ry6riczxOjQ20w" ..
	"+J6yWxJi4v4UUCyGzKoZo5urgraObanr7x8nq/HmMGqWRQKZaRrBkVa6HXOSSgrk082TU0uLWCzwKuKgAD9U5LXvu9v2YLl04zxA" ..
	"YVas7UdPJQv5kiO2whLRMZ6JyJwoo3dbBTwTiKA3wl41LuxKiffNJq3W0ESKqt50turog/JVMipCOKg/WhNl4t3CB5GQ4WyUQvpb" ..
	"tl6SEyw/uOuPPgNwYoxuLi8QfQkY5XP+z4tzqoS4xXmZXmP8jbEyyQopEaz+0YvOqd2G1h5e5RNlPojVZLMd6hwd4N64Yhp3dISV" ..
	"hhAayM1VKSbg1cBSWd68dVP/zYEuf73u0C5A9xVCW4xUAKyvLPi0eE3llXu6Y/jw4+wIM+P++jW3/Yn56/QoTPpBAFyr3NcTZuGn" ..
	"9HBar0PNIyfLOU6L4aMxuGgBu8hIrUODXTNVHS35Gg3ELJK7hFA0GcsYJZvUb6Wi7oEaLAtC6So8qtmvBEnMJg7oczjCvOz9sztd" ..
	"h5hQHG3E/G7+in0VrFzbT8prpOsbAuXyZwVxODxBJX9U1ZuPdNixVjXbegS2Q8zsHcTT+veZzto+if7dsaabFtTy2Mxce69BvpJB" ..
	"Y+9Q0z0rjSDiOrpmrJm96slmP0FB07Yr6otpA5Cd3TBiaAarWEg6oB7Y3V1XdxRJjpPvgjVKyve+4geTa6U6HGs399WPgW86aBnL" ..
	"8+VYfYrmDgi+MCfJMDS4DCECTrOlcs7w4Yeh/qhoPAsBQzNcIzhdKlO834oMHWvoThByl6+43AhT1jFhSRdcNJs23QvRzxPlbhfO" ..
	"fH1hjsTdeSYDShXkuHD2zeUw9FSKpuQVI/BNz0vt4l+1P/99tx0dn8rK7AS5l47nEdihpDVGKHQwC+csFHSoeeq1LBfAvJqkeriS" ..
	"fEDYu79TNfBjxQjmm+JJZeaFEgGA/PaaDr0VCW6siqksz1ByGLOMJohp7JYdh6s01qHf4OKIKKsb7zbd/+Q6e7ulfvaO6jxdQofK" ..
	"9w8WOWs2etkwmEkg9CXnDOQIb2neJF3w7KzQPmrCZyx6lI6W8XFokMDtUSQYOZVpeY2vMFm4TiYQtOJGheF1ZowwaedS+7jMhYbR" ..
	"Dt8Q5DTpQSRAQdBcF98X1ebvAKRovkbnkI1MK/nmdBIta5iHv+CsCa3DgR8wB/CMDPuDKfKWTak2r9GZ1ctCRibPBpJaLFvz6irF" ..
	"SiOg67D1U5qRGjl3Njl3H+1kSi1/IMDlKxp6UWDe6wxHpI3g+JvHggrByxD4cZwMYXlUUM/TYJHPm04VAMUB2rqrSMFJIZBDf2v8" ..
	"+g32ElwYoKruFg3zKEi3Gb1eUHCy1cl8GA0mwjR0SquC+4XCKTwvjkKI6FOsVqipdgi6zpMpvnbHSFyrfPWZ475jbbjLwqIwX/Pi" ..
	"/Zg+HPZDPzQnAbTPXIFlIQACIlQs8hPFaah7noGasSRUjPgDRbhXtvfaX7+ccZr52MJy/AMZWbV+xz66cdGgHaKRrn6JSckzwlBH" ..
	"PxZ+QbQlRvn0PtN6wf+M6294ZIWaR9noSs24iyYLWrNKaOdsqKTBBdVi3QVoU7HdQ9gguiSnetQxd0DHNmtIdEtVF5OGYpJP05zD" ..
	"vR1X+FsDpA0lfzDDOQsQ/4I89XHgHEM1RI5x2+eURDXYTdapMdDoa1aLmgoQKUbA3P494Y/fIFa5yW735SVJzBceKUS0vukBKYIJ" ..
	"4cJVvxyX3boDZK160ompZBRL3aAYXKr/51ZBQ2CUVvjaAZEkql8sWhB/3sHdVkDTfOFN/WpvsEAupENBk8nvimcOpdrUa/Tg1kC7" ..
	"t1YvxlmxYww9EPU2094yBB1eKng6+FpiPb03XX/FHf9bBIKaDByMgUfxW5YP7EgyNhmzGBfhKkyjYF9E0KvW/jah1e00Z8upNkCH" ..
	"njIaaZedGGqJrzuDNIvIjTMLNuQBT1M8c+vgeSKmQyTSHuv9czKI37hJku/vA+aX0rJZUoaRKbuXZ37q/J3YpJsuVd0A2yJGpeRJ" ..
	"XsChIvuyd7SZKQWTj8c/kQKBULuxttTMrx8YlGiUV3f017/GubH/byi+Wv8LsqWQdWxzb6RUwowbCtHKDFSUEkM7re092WxF2ho0" ..
	"Tq3LqXXuvunNPlDUGbPic9QUCJIACTdYKBtMBUcVXySvXKfwLG/ajyV4KhL8VFm4kVs4Ug7vj6PRlEPxwoNO+FfdgGb2IWZNPyWy" ..
	"FHgpS9fHB0TnUwami64K9ATDxxnHMWnbh0HAa/KFJ94ckaQVuxF8aWTGUppjy61hAQVoD/phgVTn7fqYseBBDLPtHwjYuqu720+b" ..
	"pYoDTJPl2HQUs21+RJ9IQLm+m0Op+G7JdtFDfrXusNaoq+4yNx/Bt48UAGKHpVEEey7S2z3iHgErmmaO8zsxxpTEDLGQF89ucvO/" ..
	"Itzsgbnm5JAXxL3gqVVq6FqyGsPDoH4rqM7h9GxClOmR7nLTLaPvXndB8mpPP63Xd4KKl9VjiDOjMd7Ot1nI9AKlCnLSv3ilSNye" ..
	"AX+l6oFL/edE33Vu2YmGi27lcPuPJ13SKJGTNzd5dgi/Z7Fr52eNbPkVHrvvOtRememtBt22t2XRF2NUiJbVYMbuNtDZ6su/Ismx" ..
	"9+X64TzODeJRkmohFwtclB7uEbJAJT756T2NXa6lwgfjfG/bnpNNKr0IgxcAIfzTZ8ijp7uG5CXxnlUXNHd56nW0GoBpwNECqYyB" ..
	"S3J7tMpjtTEHRiV/2qCilJWXvlrhqd6YtwBM+9TsK4WiZhHA6q0bpLSbdxjuEAvYG/QV0Kr5FuVvJAaoQ4JWY471YNYVRwHxlPze" ..
	"DigNGlF3Qd8mN/cuHA2xRAbzuE4ZFKI4EUu3aGxfIAqdWzCunaXA6G5AscqoEcbHQfuGH+ryVHWKrMemPmZftkQdZst0zo9Fr9f2" ..
	""
local PAYLOAD_P12 =
	"AwFqDwpOFThEusyW/nVHE4hfa01hCRTFXQAz1c8XlzeLXL6NbHGZ7Ne04CV+oNNAepWJjxk94WQIeSqvKs5cEd/M8cDdkk4uTHBX" ..
	"2971ElZbft7fRokd30UUjbAH0LkPBzfoth6ZxiYXQTYgtoxz7F9V2GN3qIfmZo6hYDYmgZVqNWxANIje8Fe7iCVUeXirjtcyX886" ..
	"Z+3VHIdA5lyInP+2G4b/rEWTZ9dRwLDYnZitNJHBL8irJFoJqVCY4trEyRe3OR0tFJKJ7yzVEzNneqAw/O4cgOiNEt7RV1MvxsK/" ..
	"aUidXn4XAeeG/1smlC43ZZ/4ojVAj8144Ubs/of6eflzjRiBH7XoBbPza+8t5OeUR2mX9tsUl1JL7EsBbLUJfq5S26vv43G4v3rV" ..
	"gMH8ASBhnT7v7IyMyfRgP0Esy0w1/BaQQSrxgrLy4nydR5iSy7Zu/iRVmgE+CHTFtZ6WvHr8y/Gc3Xae5S1yxCAXtLvqYywbM0cy" ..
	"Y3111EWkPOqnNGxUl7gMT204NzK2m+16TttfT3MT1ww0Hh2OWW8y1teiMe7omXXUP4RpqdwBqW4/Tv8TJJrfutWKBEuO0QgM+soX" ..
	"DMy1vDAwdm+7Qmt8KKG3jQSIydsLJG1QhOwmSuR4IHHTeRx94yeMAI8lPBwIK7V5KgjmVAui2agOirt2VJIfye+TYmEH8ZEdgneo" ..
	"t7wVSDCuWpTJ7ztmhKdfkmYTFhjtoFAf8q/oQu75e+CLyqWiLtPD5PwSlpnoWCckQOindrB5iEW2VyS3MLI6NK43L8xmjr8NxFBD" ..
	"s8CSYyffz/HKURx65qI2fUXAWFaYvo45QMj6OhdeEq3RznH9JMwWcfqdUmIt4t4YExccODAWuUWivKIdgHiN7JJeQVkoa7d7P7fz" ..
	"PlUMHacNdMjk/RT/XMPDFdW/0kN6nHKO1BT8UNG+kbnyRn0of4w6sN4zPk3U6X/YBTDzb5N75n+zpVuJBFdLD3XT+JiX3EMMBCmY" ..
	"Uni4aBulE+mYXyVMVBozY2C1yru5Aq/weLlPXYYpfb5f9bvAh1foFyekF5P6FIkc7YWbusAVNPSFJbs7K1s1n+Wa1xjP1xXpL4Jt" ..
	"YWmljNEMDMYxD56gFbDdZ2vPob+xVnW0ldqZdoOWyQ+fz35HTAL9RdnLzPEXbb+d/N/JBh/x01Pu56MjiiKs8HrhVAI/FDr+2J3U" ..
	"gi66QcJjjgOWLzdeMHnlS98H2xaUEr8GKCqJykPicyTUJcD99WRYcVN61VXkJFCphNugdIVU+18Gm8Yym/BmBJVN9UvWI/+2JNr/" ..
	"oqphxfrwTtk86u++zwipn6L/e2AUZ1LRmpa0gQSm0o+K+0QK2IGwMJ0dFDxdjROK8wzoA6zyYFa9GeB9Z5V33Q8AIx+5JxW6/cRs" ..
	"Hqskyp7KzH3SRfeoBT3xUB0jcKcaeFpL6OFoCa+NvxH4mLgazgOQi9xKnCJQMT/HvE4DvptGqY1rxtO+xCN/ZKFLv7EMAPe08Mwa" ..
	"y+l7HEmhK/XsAH0Vp6UHkyd3VL8FhkQyanam/UH4fnQZ4sw/x5iOlhFEhwF0jOJhHOBBm01dLxKZsac4DkC0siUizFRuPRnHPuIM" ..
	"mLD1odp0MiEQdJ9o15Bq3emMFI/PX/Qkzx3wxZnpd+ndhwMUGqRe7DI2I7TPZkeA9JB3jYlkVdiaZe/rEAlxafQpEprIrdryY9Zb" ..
	"jjmmUtI9Z1yA8Q2QAhnr86kHBI45bokmeJjoKSFfgX+edjxLP1+9T8Q8BtC/RSSuUuxsauSV891HAhAwmthawWRNv1ySX0zLTlSB" ..
	"IR5IAMkFnn9IQnc62nNp8MXJ7ipqV//mavVgSmxnUlIIVTCfvO6AkCP7Qi5j9R2xAkEpquHj1GQ6sSJZobm4BxcIT8Rajp0uIP/I" ..
	"8djHX5L9rs3Pbk82paKSDlxOrF8fH5iYnfItOCcpBkpjFWmR9A+L3tCHMLw5Cu/cKE8q4N4KPu2UtQIR6YVhGCNYsOmN2BAJaCHK" ..
	"grjPmj7OtTpc+rWsdMmz21jkhbBBEN+W/P5QQC/Dk6UYTRqGRWenQzaks2sIspDc5rJsxQe4Q+0ki7Q+DKZQfZSrh/R0/GDHEsrg" ..
	"8OH0680Mwqspj+LOE7YfwJhOZTVcDR1+7SeNidK5bq85l4XYCeXZhSydlYibB21hOXH4RXBCtb8BENSZnjnuoNuNHyVV+5bAve/5" ..
	"Uw3mzZObNN0nJ/xSr4Q36ymLqDju4sM1ryTffII+CnGXyodmm/oLsVid1IoXS/DE10iZIxGkZ51F2zXCDeTAdSTJzhxw4YLh97Vy" ..
	"XSd47k4zfluw/Jh9O8zPxDHO8/2xGK/9GQamW1hmXqbmBFm8BhRelzWPieN4kwnlmR8VV49vaJfOyPrny3xFNTGdTpDvfp8Vl9ZA" ..
	"z74OmqjD6m9dICLwGw+cfQA9MohK4h+OjrdTZbWRwYj1uQZ4SbWYRuyRo9kCcrJTsv3wivNhip2kJemN6aW62HyRXo4U93Rribqv" ..
	"B7CcSeOlAWblx0rrtaezjws1mATXeodV//U5lgRXYPm3k7lQDf9LtpbDEqkf9SXQfhPzPVgTx4Qjsn+zxLoG0TaOsTjckxo/qoLT" ..
	"t4C7XcWQptu1j8XRfB5mFcHkl1mJhf/ap8fhmjQ4MPr+O89RWH1vDZ5zVOIC+u9Lo2Y6h0/qHRy5jSJx987mJ1zeeiyKy6sPyV2o" ..
	"83/Rfk8CjupwIh4xCP+jmmQshPOu2Zagtxv4ZgnNpg5G92xm/9KRL7vjEERG6L+5kP4JSNEH8kopzRvDRkExsyT+tlRyxai4b79G" ..
	"OeJRic+jwcsZbhjhTItYYYBm7F8ZMQoRNbd0hun7Bw0xJkYNR9evB2tYtHzo4hKBwSZ1XevIpc9AQOMxccFhD3AHxPuKq5PrAwv9" ..
	"mh7wuG9ux57qVQwvKuYHlBzxhAQjiHVdWkYg0NyOy5VIUHxYmVt8m8VHlPsYp9Tgw+kiVu/f9geTxanhSg/zvYLr0/6f9Mr45ovW" ..
	"ZK55+7wxh6Ej5RM3rngKZg0gt8C9IwHGhX416pz3U03IkrbGixlmewDOtH0OBiqMTIS1mojNH+0udjFx/5SNCzz+br8VumIbS4TW" ..
	"0N1QFUFUAXhz05mk8k3cJhtxfDkR+bTzpdRJrpW8JjdfRlhHAWlMde9HGH93hzfuTpIt5Sef9LIYpsXjaKpmH1gpdQlBrzZBLZpZ" ..
	"CQEyZ9KzeT6zI5rraqy5ihSEvMPsK7tFeKR88Oi72lIXQVIA6O4p8GUShvYlaWsj6aHfWw2rgCUsUo1FUt1/SKko9QzSD36hc4nW" ..
	"2IedzrAU5EuRqZUgeDqyf8P2SKScTC1RkkflADK45oynuXGIfdse35bEsoMB/ItrC2k5l3lj5P825nrEjGY1NSbOsD45u+Ij1lX/" ..
	"sCGc+QylTQMQNxRSJsiAMlEYUGy5ZbEsi1apzTTulO6NUeJGsFpgq4Wf4FoHoCBdypS4GK2aw+Y1LMg40k/X5CnlC/iVfCmGBHa0" ..
	"SBkNeNDeNusTPHk3T2OJs7VARklnkbiBFlogqCRCCqS52km4CGv4HJI0AYYP4IsmgeXu0QbSbi/gcGcE6q0tesV/3/a3a4LiWx2R" ..
	"XvcHmPekAy2cg+2o3NreLBFyBqYjPQKyGyJjZ2KWYP4SgH2wyOzMZKUSTYzsziE6ryeTYvck44iBhbnvEaKVuJOtcJ6mQWrQ4Pmc" ..
	"R/bxm9U/P1z4kQ24hR8dhf9Ck/U0e429JHRDNsGc4/9nXdV97EaJ3c/tRaqvWabuVcAvpShpQMFIpGjkA7jztlylOAkJvTvwkmxe" ..
	"CnrSuwyrLB5QWnF9Swk7t7lGr19k6K1uS5qbnAMm6/KD0RcsdA6XkFRtPeQdSJtGZba1Fn4irkmTxg7rO5P/FeExsmKMwNxzYqUF" ..
	"/wJ70SUq9OXVaZ/nN3SCdKzDPyEVHBhDf3BpM1BR88nGNW8yVEn9JwEl1cHKa6fhr3Rf6PnpF+vbDP3yNXHZioZ24kyXH6kssyn3" ..
	"NZ+u+k7GEIHqUTcCjL4N+ewsh40u56AyQ0P/ALDcXgjNbSpjeotI2Mm6Wd+sDrY0uJIo6AQlgPoXiOxcdCeGVO8yj5cAVlG8pmJr" ..
	"YT+bi3INDb6e4S6AsosNNG/51vsLgqYKB30H6PVrMdb6jujH4ZaWFtB4aKGA5FFqFN8rcuVfF/KjCmXDv11Ld9fetCFug2hWvWfB" ..
	"B5uoL8TYoDZisGz+sGNkwbUEJNTrVblsoqXHyXAP51mv4rg8qFGFfW4ksf6C0mjf6+4xPmSIQ7RgQQ4d9UzMk4rGcD2YMpIzmlCj" ..
	"WzZ/2RbJCDTAYBjW0yozpYVI2TO9XOnTFvreYyeAWhfLv3A1NdRUbRStkwpNieVQin1SlYtyRXZACowhgeHlVZG00F6s5iY2ZqkM" ..
	"WoSgi0dB7nRjXbZhqKlXL3NMeJxOrlwqzjqLTeuRuNoGNqOw9Q09Ycw5gxgy3YQCC0CgOV2lc197f+QE1zi9LligpqTWGwxEWhH/" ..
	"lanDh377EjUDkYJmxQoIOqzFueQfvc1X6sBa4/GxhGA9Tr/S2PPFtVqXk9WJNalN0WsXaIgmTe+RDHBPZiPyQR/JPs0tfY+MNQUj" ..
	"na4NrHiENBAy9I9SNqdrAv6XyVFA0zvDtqN+NQ+QiaDl0ZgUW5X1fozrdGDIHgT1wsZKAHqzGytEl4QzcpD9qWN0vXIvmo1UJyhk" ..
	"bSHkvwoqR9jFOgTXeaL1q9vSjxQZCPemtW+4m5GENXo73YZ5mRv2G8cj/YfdSREKgSt8E8HzbsMS+39j4siknovY62zUaFZlphzg" ..
	"a5grTtGqgdw2Xv/oQn8/EQcPJd7607w+l6va3pqlkT4j0qFLn1GJSU5mK5MNmOG8eRKJlqicMeR9pvklSiwd8U74gnHb18QjawfU" ..
	"QpJp6gYI7ZnfVH0JHNyAUHA4LxigVponTEHPJS9IETx4iMyWGRwZBQkR0oLU5G2QRYue9qtBqemu80iIJBt5r77ys24VwNzUsqZ+" ..
	"BQ4FL6U84hBeyrtvUq+vQlE2uYq1jp3FwI1aGxFE7422G4O/RLULzl6vfrOd/NcP2FQDlVadLz+wOtLxRKcCT/kq2KMtFqzlcNfo" ..
	"WEqzyzLDoVYJhsL71lbSSBNVWRjY2WiHihCLoi2BYBah2d32Qr9Gc/ZKFo3lPA63MHsLcalVp8M+PIVcHJh39oBRb9FMB9w32QNS" ..
	"ebyyBivaK+JZKqeMLJBWBs8ZagzdHwwLXfwOxyzRqTj1kgyAz32y1PnhSRSrt5BXNTXrJeQyXEIkkTXkSEavQ3VJaYqdzRqof5Ab" ..
	"I6+JyOFU9VXqEcUrw56kqkw2nTrmfndaBzcIY0Hz5NHvYUW+pqtnUk/8+WG+X4Aa1QxE/AcBSgw0AHm79uywmByIZqyS3yCVVsUQ" ..
	"LEdwTO+YRBJhqWBUzSkZg0pQAq9Dv9fABFoID6QGsjtoG0PM4SRl3fCo6ybIWPvpHIOPzxFUgOXp5RF8iA1M7Cl87h4cEcyemHcR" ..
	"Meqt/7x97hDlB7XoBOxOnV88jXwQGYMW3aWSODVJTIO7z14IseXb923xjgWr6AcWJgZtFDsm5mWIu8shgKTrJdx2s3s67aMCZsIi" ..
	"AqyIKKC8Zfq+P8J5IHnHEWG09SYbJTuubwWWYCD5ns8TBHt36OrUyEivQTboE4LSlxpcFLtzGzv0WwGd9eB1wFQ3IbiemhP1sT7S" ..
	"vBxn2GnwNzhCtBwaS4Y7DjAIeRidf+1QY8HG1LEUKUz3o5CpGA7KnkGndNj7P874clOx4oW7pquIHkAf3taymxJ4CkCwBHeBj338" ..
	"8MiYDTcJqBnnfGJpLan1HU2PLf2Me5hhgGlr3opXlqcIC0Y5KbEPg30yW5a04T8uJeUQcJWcK+Muo9mR/PqmyKDQgv8pJvvZ5Fdu" ..
	"E+BGie8ebBXdJfkQJ73To8s5fbxAIsMaNBm1KTzI176WOWMGkmAeRJhLE9Chcmzyr18m28fqu/j9Wmxssrcen4tJcW5bUEnUh/1o" ..
	""
local PAYLOAD_P13 =
	"P6KAFYW/uoEA5lgTXiZBoOGCOLf9SutSdWjRdp+9mtpFJVNcdFHRFBSPTdRqMp5eBBzxu8KZ61UCxipk7aWHy7uW/Z/YeTpMq+Bw" ..
	"QOA3/gYkz7bhEkleqDYSBb5XZDUXHpG3BwCfgPKtanOgdkwUJ7HnL9TMJmCdE0FtoJNcZgJ9sVWvXaJiBbHlaU1nMNoiUnQZiMME" ..
	"SlctaTdB3UGlhyLE36fVHdir9NxUA+pQstRSvPQezIwEEGFrVXrU9KNEJxDxh/MT3ergLrfDkvsKwSjvzUniaA91gMMCyuAFS6Ko" ..
	"uJ5paVqtA+q7aMMJrWbwdb9zSJInj94cfXOSc3np1zYT6pagB+/OmYPvtJAD7sMWx+3rnuZxtaMx+5ZcMwb7p/llu9K4z546ns86" ..
	"Zcvp19bUUUHJOi0fl8iA2Zd3KuvpHO2o+QTKXl0Hu7dnFN1mVE4py6zg+R49W6s5sWoLZg3NAFuBbEJ3Z1nsOrxUGOKDL18DJeQI" ..
	"R5cjgiYT63L/IbAC61Bcqg1YF9PqTCMQZG0gdB9SSYZLztK6KX1pIfqV5VnbE8E5e/pHINN3GytSa6GgfE1u52nvJpLA9iQtjZrh" ..
	"A6KAhtTrHI4/WE1miPVOLnJmLFPrFo6hXy8bfp7whWyIfmO7Bk/SPltitPJb/xlqoXCxRXwZHRfSqUGt1jEo+4D+EbzpoF4Kggin" ..
	"5p479umfngRAoq/0UK/xjnAow6nUWN/5sXkqyQezqrkJsd/9WmwWyg+hhank/KeFMW+msAX/xPiOg0wsHZjaeIJYA9K5f5uyAk7A" ..
	"wspkVebPBcHB8b5q7A2pW/ivkJk9j9CT2M36RfcJCOPUXE9WLvXDhAT5Or6HqKBxYJ/TPDvUZVqfb23rbZYgZSaeOSl3atzrRkhT" ..
	"uLVyKDMvPGaAXJZYNAtchC2uWYTog6GgIquyt3kDxwZ9P7v50NXhg/PJN1senBgHMG8ON8tH5No+fdFbnxqZxcy7VTlice4BGM/8" ..
	"U/08jNZ6WUmpFMbjILFkPuPIeDU0fLficU4FV8330qDsVQr7U1p/E2q3iNosOyndic1jYQwOMTZCHUEH18h8R2MULlBr38bZTVBA" ..
	"Sw0iO8YdII3epIyK4ZfPQSEkKM9QvasfbmKN2m8wbBzpb9wSUhvLiwy3Iutlll7Uv/D5xvB48eCZpiCzQzN1CwxhyVTpkr/P73j6" ..
	"VWb4uzJjH7hAbF5y7/+BnLGfsAjJqubTkcQ7LK9E/fA32p+DpCO/DDZxYRVOvGd8zfAQVFPeR3uQEg0xrzHrbIPTLV4gw7jjF5hg" ..
	"Sy6j5NN5IADbMYN6T7TeuLrkiucdqbw3tJNh6n9lRLUB+51rmvii/wwr3ICLsXMzDxMxViVKgf55BOs0prwd+ukVSf/AvE+w7xxO" ..
	"Oq2fZW+ugeHAXinKU6XlJmK1VXBrcOSddrmYhY3FvdHFo3XEZfHPoiMqTbOTKU+biAvncDKtc4cuyhnI5hwhbOszcdMucK59Cc9J" ..
	"IdvAawSdMLfr4vpJu2japJSRspiE2Jn/vBf7I7RVUzkgWdSCoWy16LuY3DoUXCRRraoXi1k7kMWtDWpJ/kv6eXK23mYiGO+1+awA" ..
	"9HwnLnT+RS3xnaB77ut81NUE5iJu6yAp62lV3Wprz8Ll9tKz+iDDpNSe5SxhakpH9O/8fmqR4aOJya8rtaKdPO58Re4LvMaZMTJV" ..
	"hjUxPNV3b32MxCdv9h40eny3VvDhiYTzRkIBkJlw9n7Zn3/XeXL6Jjk5HCla8D4cJTzli/YiziEe9F2mECHN2In8imy+UnM3k/WD" ..
	"lSLO/IeRNJRdV375gVFQrp+LgFNxk30WG2XfFS5WOKyxy421u5NiNwqYCK7TfpXJu35mJZERyulOoBONbnxq8sfFBgco0Cha0SNp" ..
	"kvnof94qPkI7q0S7NhxhBaBnmfzjwxUQ8RwxdagdBFJiZTP1k2/IY44dD91LGv5niMuDy0+Kdaev1kCO8K3+WUkiwhufVixgFIxT" ..
	"dpOU0xaraFXmqML9bp2Jc+2zA6snmsFEXqMaEwiJcJyWMAl32Q+h/VFL3Em+q+ytGDkgZyq6yi2LQM0CeehqQrAYxpFLXWw7IgZt" ..
	"ls/biKAdMrwaZBwjzk3qBsxaxvZM8zGDg7OqR42sFF6MXvPycO4U+kRiArxYOMEvoXAGFHWQFZn2xbJnb4Ayzf71xAIrvppqkGH8" ..
	"Mnc64FMhwKxDEjQDyQAPRLrQ+VYh46FuhNS8zR2LggB7q3nLphrNP0Q+aYIBH/ypjOm9QmsHxJ+tiMIZ6tlAPtyWvHRg+SYDN5mg" ..
	"rPmqtxVLG671ilt4Dt+x6FCq+AUKYq4VljdV1/7qagBdnzMfFLD9PYC6c6x9zBYH3tJdpOQDZ2YIym3Lf6c7zMBpEYK+vHRrg9uO" ..
	"QsHGn19zG639yjzLbeBz8ahd+CXFpjVZ+QcowViABbM4Ei5bmeVI1baTaUEy/jxiWgquH7ZwXkgyvm72K5W1g21EmPIlJ/juGi6O" ..
	"yBB6bdtskcCE1Bsy0ejublOpoZL7r5k3kdcFJ2v6ghBCB+XGyiQ9ZjFSybB6VmOHOQ0qhLL/wZDOjufXveST+2uXtL+jxDtFpbMK" ..
	"GNZ2En40ZwURENuvq8VEmOJWCOMNgEIma1eZSrjIP5hUyjJr8Qc0C5hFT3+6zfE7Ap0mlXJjFb2i2eM6+Afhc3L0mVoiL/5afZKi" ..
	"0lt0hIdfCAGVifAwNQIZw/zGEJ/UbkR9S3jgj07xq/bIumc8C1HBmynXNEQ5KbGOaISOMXEQfPP74iVRBgi1dFO7EtmEhJqiD163" ..
	"6r7bty4LGxceSnWNSqegoQjhVbcTiCdbKeq2vCSpPPPfvOJNxZEpmKI1jVTLzkAwn7DccQtVaiWchjRPwCVVZ+eYLvLCb92/cZ+3" ..
	"mHkZhtXaBA5haIi6OR8bEKg7m6fROOsjWsdGdqXOOnic4LaKVvMVg566YrPjfIuTejR392ZOV3XqRbLq+yT1AGXYIt8qWKNYdazL" ..
	"xapb9KWDGjET+VbbjGUBcOwk/CSmsGC/TerPLsXF08emgdCaqXMm7uP6QLSWVL5fS4pH7z3UgZxkCCbYlDNsuwH3G7b3ihvbuERs" ..
	"LLM+LSRybxW0Uj2rHr1kiRkvBXQ1hibVb02QxX34chJJsnk53a7jF5e6E6CG/qKTy+mV5gMx9nsgtnSB/vk4HfIyW+ASZdMHISQu" ..
	"DPld4U5lbNxN4JhVYlubY99JLUjIF5AUiKnCXYr0EZOYAtXwcmktuXbWjNJs1yqGX65YMswMrb0k1bA3rooSe+f5Bkncc/N3vBg0" ..
	"FWWAIdkedRZy05VtyN364VH5xa/GuUBObhyuNgZurScXdf1JSTuw0r3XhW6FZP9lWDujzpzHC6VyQ7ULh1P/0P9zUD2PkVd52h+/" ..
	"T6uhIlQXXzb5YLBZBGGwvEBV+YH945GwdQhGcUJRjwdsbYzTSZ0sIjJZ0TzfALDc0G3v43YnkmbxaiHZdUwUrklRZJjJk0hV6idh" ..
	"2xNa13pJdSBgwxQn3Cw9BMn5n4zRYZIkiQ3Z5B560sR9/fBGjEk1+wmXwePSkgw/2wmdJzZWoUNubFfRwbB77Q+NCJYYNFlFPHSv" ..
	"QmJ89l7ChoD6DZQmPJW3FWAoOWRBMlWzTH+RWi05OD7Ano5lLtXhgzPeDQhLxL9AdkUpfunrtuXmY9Ib83Y/Kytsqgo6QSRObuTB" ..
	"vkb3JS5dSHIX8oNI9L7HxfgPVTD7O/A3JMKPQtzy9ATErfH9in+QqwIOJqOjzHWDw5k2u4+0iv3mV99y2GqelsIlrRHtv1Y9nFFi" ..
	"EEQzAKWyNl4v0l4Gbk3YDu3eYSGE+8g1/y7mK3Jx6+7NAu1REydnh0tuZhPjraaNgZ+cYSmh6SuIbkCuYxB3By5XoBXw17PmRTiP" ..
	"gg0NZsnxooGoFz04D5I/VrDPMr6Nn22m9fQoY7jpaRkitP3E0QlpjEAmD5e1zPWYBcTf7bF2GStuoBxzySE3ABEOlrXDzzVWUM3x" ..
	"wlEtpOlAUUphzTgEafX0P5t2ibaVUePB9U8rET2Ho3ajvt+BOpouSypdrzG9xyy+mb4eN8OFhyBuOsEi6xQOxKPqF3ssVZ1DRJZ+" ..
	"aQkU7QVTloiYb6F87uVQWZPAGbvwHQlSJOA820m+2mV9+6wEIbiBteGjvNqpPGFZa0bCQC2qehIC3R7wYO9owQ6IUFUAx8x5AR+Z" ..
	"e8Sby5wF0okx3yPilfFmFPVQv92bYRNEqnNE3g5Y2SCkcjOzWSei3YGrkGngI9P1fx/CBy4d6D/uKRKkXZIah2iW1a7k1rxQgkWz" ..
	"IXr6f7OEQhZXBDdUxMHkXpsTq3+0LAJTgwkvJOjP1ry1hsxUXAuQE+i+I2+Ra4Cq2g3ywn0Ndlbq0dLLPvJwJr4nODz1Il8CnxUX" ..
	"nYwVGNQsCrcykNkUrJxxoboCOHzj6TogSdsGPv6TmWC2Kd0scfloY4u9cDuLw/EjvpFvhj15GBReWyPgjosD3LQEh1639wkptNn1" ..
	"zJzdmy/uIi3d79dasLPqzuhRuHE43rRUPqKpNO1c2Ssyn8tXiW0aPfmBsSwsD1XxcPVIw8rBrJxssKgFTKl3oYdAgZoHfA0ptqfl" ..
	"EIeIfyZmHG7LsTiLTHQNrdNrZRkrCzsgwnWCnHoZupD8whY7AFI9K5DwImhcM1AVxZq1mORFTa90SQ68aydVvfPT4Dk0UUFCeitA" ..
	"bKkvlLtcVqB6ae7Ey1tlEhOYu3fUJYJiVc6+3njlyZJk2WycGDY8pnvNuBps+9cvwHB+b0xC9hm9tFPq/cMfimS1FQv6Rrtu51Bj" ..
	"5AtceiKXOqnG0qa9lrn1v2JZ/z4IeJImSLzP5E0oXka7YfnfYv7jkkktB9Yb4ZZlU1WzkedUZCqza8HBdeF2N2qDsbzSfHXKk6QN" ..
	"yH6wUslD04fv5wa/BzjOk0rVFe+ql33hoSw0Vps2tvHOw0awreelMoeDsFJ71t+6ecAlhPX1AoK8Hjr/N6xjUBxtJTvEljJVeI8y" ..
	"KDDcBvUKiw5NuoKtG/H4tyDJ68p12EGBWJL4lwKcdV/23yeMs8oF15OHvlXJkDbYueFgHkPpQGl3TmaLahJ/6CCRyeFdxydmd2r9" ..
	"mz8M8BICzxXsKf5cO+uc4JQIJC54z/ARehtzniqGJ69NDz68DlkFffU+fa0ceRFgt7tdU2B5UESCEcbGBiijdMlx7UU6jvE6DGmV" ..
	"qA35WI5kg5/hU4PMhQnUrgnU4/uwQp/QYpiLQcuyV09che76kSsqc5/HowAt0slr3D4qgYifqfsQ3BIQdsF/lJ1YfRFhFix2lTUs" ..
	"/a20HaaHTwDs70TsMSyxyy3XKIfc4a83rN3zRhg9LU/vJSjwIL9s3eXCUgN2YddmrncKFrOKwKY3okyVLjJZ6sX54L2WCtDjR+AG" ..
	"DWlsRmlWmauysNyfR6uq7pyuv4uvyV4bFrkbNYqXoh8wL19NWaGVtHkOrgch2R/2OOeY124dYmOg6sVPFFbykemCtwDaqTHXxwzQ" ..
	"SOYiJQWgIZLoZw0n3ozEfmSiEeCRhctXGaP2BBV1/4pPlPZm+LsK/D8PHic7fv7t4shGjqiHv25x4ewG5zAHtNy98mEUWaxkcLPH" ..
	"ZNDnhBuf1PSbsMpFfYflhTsxIJtGtaApvfbcYqWYJOIhH7kx37+R+k0dsGeoVcbvKhHkYV1tkU3Db/ObBysSCFDFibAby1LAX68N" ..
	"YHITZrrIKr95LN95Qz8TLY7/mnnWQQNIKWuavXGdzaB7y4bhkBZ6lwJu/kEe16eucy8+8FzhxWpOkdL4mpQrJd4XI7NAOIfMIfTJ" ..
	"bEpoS1b3p4yURk7Rh+Bwp+tDHXw6NosuRsdQMi2OloTvyKMaOuxvz/IriX88yIu9OZUBNl6JnOwAm5wCkX6TbWLltsPZQvnxHo4O" ..
	"LRGPvTgwAbimgK/D74pD/BFZAe99xvMqRh76jOq7GMMiMk7Uunub9ltteeYRQ063aYv58+RSSqqj3GmEcZAhgji+tVguc5ZVy3RG" ..
	""
local PAYLOAD_P14 =
	"aoruQ8IBmpIisqhD6oQsD9Rbdeleb9kA24bMNFlJCICMZTN0q/SFvo6bWXIP+j6KEWEDo2mDrrC8l0lggkui+WqG1KFeJgDc8mI4" ..
	"HgRAXrvGEjrDYO6zUUTO854yyINcnOQN32gUzPsloCyN4XNJqhpVGOYk6xsdl3be33cg8bQVnO+69FeYz3oG3miQMCQHfCOkrC/r" ..
	"SsfGipXyV0CPoe2Y8AQv1B/lBVovcHsWGuJvSqL32o+6vUR2lO6oWbLBTx0DnfM/KUrQ9P/7O3SL8fi9ORS+NQSnRt6dh9tWzmvU" ..
	"ay+DWmZ/v3bsc2g3fRkdU/8autDijt/KcnF6LWsD9G/oYAatmwYQm9r2gIdeU0vR2QimfcoFiw3xI1LucedKT5u9xxz2XF3+LRyu" ..
	"DoD/1NSX0/A+FEJiT0wBqp7asyrC8w68oHdcEhQFJkIM31vhrxN4AH9HHWj8xw47AkajFxqSvS1oYcoLq+YWfw5QbeqMT+vIayoC" ..
	"kPewtzqjZL9BwaDcO+X/FI+EWXjagkGzvY53nq7dM3BGP/ClP8VOWLANoXuAb62jmok8rWaMFR+7fvY9M937RPaNceln6NgZltBt" ..
	"pPYR7y+cRTrlm0sRW8F3FqQL4Hc8TTWbzDIW4pc2X5nXkomjLqO7zWUwkcKF/cPDQr3iOcj0fMReZO69tktZvGewUqvTblhZfxEa" ..
	"LJOw37ZcBLqLwEziIpNmees3zxott1PfKWb80ANi0gaI6kK34N4/BmZ54waaywpWTSyEqeVE7pW/tJogvatp6FlmWcaQADwaPzvy" ..
	"aN+9SEP31jQII9nWdyz9TtM7N0wZfkEJqk9cLtM0NqPqp/TdRfNzoqbFI5Z5a+eTRDHUkG4Lx9XpFr1aC4cDTx4ia0OVK3FsOKi0" ..
	"3NdfgT41/LYGmY7rLqxHkcdtcBQpEoOmJAlRc+HFofpPVyoTO53nnQByR4a2yFe7rVeLQT3eRnhjn0pURIDYol2vmcrwVjCTEzSC" ..
	"/4TblrQCiEUBeHiCYkCNDRJgdDLOdIMENgqvOnUVsttksXPJStjKWuJ2E+YiILzFe8hdSRwBqydqSh2xwWrDpWnxb5ntbumafWgv" ..
	"2TwRlbYdzEG9/XNfU+lbWpayLCvNDbMQX5DdyH9MaOTNgae/KxelIwPAQB67tG9G/7XFG1ko/kPA7Hc7C2DHyMp1SZSWrD34mxey" ..
	"s/u50IADJMTMEhkFfM++JUcMX2OfrIOAG/5HUyL0ys5CrBOgKoMc1yiMdLGKqqz+gjlNHFy/PFil/M2dEedc5k/YgIt/GPNJ7VwH" ..
	"ypLSDIU488D5VKL3hXSazaf2azJdcSx97J5VP6A3V1+uubCQGU64qeHF6pC2KEc857ZV+R5efrJllT7BcU2bIuqG0ck2H/s8k3oz" ..
	"8pFStdhdao4IdtgrSPMb1bdLuxusbmQohaxJ6njVLk1112AbYK/VEtn8C6kC185ZNUEEnmg/XgUjj5jleBVF8VVN1rDLSwod76UF" ..
	"JJeQdpSK6omHwYAPy5l0ydijOGU21GoM56mFdvIobff3bZSbFnjCF/XJfWzAuplN76dor3WxCbPlqGmLRgGz1+bftLcj9eQrBZ6x" ..
	"jthcjpJdDuRXi8f5PSrgxO1TyST2RKqj2IudX65MC5RVBKnS3zUh8Wb+WlavddXdpDrEght6f+gTRC8zsjCNhviuSe5ht6C4siSv" ..
	"VRxz/f4lJv3UrkAvJbTO/QKmqNO+sO2qKuf4adEg/joWn4c6HOVq903zGmutuHLQJuw86UoKuFtN8/PIM9HjbmfzU2NOjqABJFCz" ..
	"5FIvNW/VdQ/vORxkv9LIeQsebIKHACRgCtEcU7Av+uQCUoICitSdix1I4cvsDbyCGahUBIqz4P5CK2DKPB4V2kBNtkTUS8wB4KXE" ..
	"VT4EukoJJb970rRfs9DJ4MCu5iS+FHq8K8oZI1shWbBrPnbDtxXBOGcoIFSYDMHM2nBaobDrT7gHBAzIlSfw3nbqzcMIV44qOuFs" ..
	"TFqDHl8dlxuwlB66trCiowkY+AC/u0B123GxSf1+ktSMVbMVItjCiGerabKDAyEQDCg+7MqkRQ3Y2b1BXIF7Zylg1ekSuNvsxXQw" ..
	"wCJTPdVLooSQlc8hi3/DqOeXocx37mloYoPbdVsraWaqybrGFTdS4u1eVSI+KLQHv+mFQodYJEgegaP8OvUtQ9vp10FgDR+ApwgN" ..
	"InobYixEZpHyQNMP9VRe10eaBb+zc+Xehhzt9igP0UF4I3AR4C6D7E1W4CI/Axdo+aWnWjNfBtqgLZ0ouT0K05pumFX2nzPRRrqD" ..
	"qRZf9QLVVy/RvSg8M8UN0/307lF87OKm+FDKQ07mF6ZymxU4YPjVHCSnTTwnC1GI4XKqkaW4MrVTu+Vyv7g4Ir/atpTEa7WszpXX" ..
	"fn/EIiZx8vKHrB486EtoJ4myrwZHkSFfYD6oUWx9c7uWH4ybVtkrasGsCCt/4i8uqv4GuQhLGjIBYBbfo5BO829cg8UoN5EPkU0B" ..
	"epkvv4AkmdD7mFyNaAuz3EPAV5Ox9ohobGAKQUCHzZQb7/4CJORu191VfCOQPBlXKQvfblp/r04pl3Z/T/JXfqQutvSBnXqpbmsA" ..
	"iRzqBMIG41ui5bHHRKrf6NVfgzSUflPjVpNCjXYnyynn1kckD/xIYccOhay1xJo/gJLBde9ZCesumVrHxzoMZ42IO7fidaPj3wu4" ..
	"bMqn6XXHEj3355nyTnHTAAnGxlA4ay5ZpLPz1bxzMk0K0HSYQg0Yn4B0uddbh1OhvNhRhXmpuc0sMHEbgekdqRGnzWINC4xHZSAf" ..
	"17qop1Ztk1PCn5ByzFfk0drGnnUcMY8nbY7iVGsi/v7jEu8VcgH7JQbi8S9jtiwfHQvG9EN6OTWjohCh3iFpA5PCYaJc7XGDveMI" ..
	"uhBdEnIkxT2bmIwMwLQIrIt3+s3BKdOL10zTcao+8g2Tnz3L5gOaSqRDYg==" ..
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
