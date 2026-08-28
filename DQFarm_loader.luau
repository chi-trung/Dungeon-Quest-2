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

local function armTeleport()
	if not _teleportFn then
		print("[DQFarmLoader] WARN: executor khong co queue_on_teleport — menu se mat khi doi place (join/leave dungeon).")
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
	{ seed = 3584584880, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 3587181734, exp = 0, plan = 0, hwid = {} }
}

-- ===== base64 decode =====
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64VAL = {}
for i = 1, 64 do B64VAL[B64:sub(i, i)] = i - 1 end

local function b64dec(s)
	local res = {}
	local buffer, bits = 0, 0
	for i = 1, #s do
		local ch = s:sub(i, i)
		if ch == "=" then break end
		local v = B64VAL[ch]
		if v then
			buffer = buffer * 64 + v
			bits = bits + 6
			while bits >= 8 do
				bits = bits - 8
				res[#res + 1] = string.char(math.floor(buffer / (2 ^ bits)) % 256)
				buffer = buffer % (2 ^ bits)
			end
		end
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
	"PWkv+D5AyyxJhTjWgoBkKdqzD09ynxkYRaDg7v1zh83g0DK+nuGGya1L2cTLBjsiLUvVg5iSXqHH7HfrcNElNwnqf4VftB62sNJ9" ..
	"Kx+ygcB3vcVK9CgxteeKJii9CvSrHYgRiZ5zlqdJ/9RqFYGLURdaoQen1UokRVjU0L0xnLtfGxH0/3eAtN2Z0Pg76wYsUVb8JATl" ..
	"ys3pXqAH+SHnS2H5ntwU4LmYmP5P8VusqW10YaiXGrdrdo/KRj9G3NytRM54LqeVxzp1uiYwp1IvYjtQEFsQF8rRDFuA73FUkniX" ..
	"d5bMJIq/hAm6KfqYa+GIYglh3ZuDmg+M8cj/Zt84UNLPoep3M5xNTFHi6a7eFaso8M2uGzdyyxgrxIY0vpehZOPTPW4KC6P1m6Zn" ..
	"3sjzUn5TltgxIMywVtrhX/nFHv17mKYPJr2STad+QuarjwJOGiKeow+OQyOOUuwsl/sA14w/5ATF9PO7XrcBmWvyRYZYexFsuiYD" ..
	"yNErcUYnuwoG7henXSGVe0akoBoRyRELrh0Su1zNjuMphyAkPboOBBIuH/ylH4l1W71TCv3oHV6oTfNMDl34pf+X6m2QsZRgNboS" ..
	"dme9YVHQOoTI63wOT9ZjAtTZYhD5RR5vsw7wtM5xY0DFWfuWkN8i55NXG4ccdwwL0FxxinyaGAn5vhY6MmmQaPaGS0sLXndd8/UT" ..
	"nrtoa9lStbdICLnjGkDuAlpsx9q4hKRRFJGmEIdkHx/deG8KBPk8HlYzbTl0gAGe8XM1cJewyZHmYSa26VqEhaHq/Y1iqwQRMwey" ..
	"NAERRLMhD5dzXrr3i3AyrzqR3IGsfcT9//dSbtQ/ghKdDooEz9cjCex1lVadbpsfEcVQIntTQd6EjWxneGRmUJ/Q4WMXJww/rpJP" ..
	"Ps6OzO9B20bfqcwh7wDTNHMFLZVNmqJPIpqr2UlHrUgs/Xp1+W6cHAZKxdc5mAR1u4hVp1tGR6Q4SrwZ52RlKJRgqWfCYLMjdop2" ..
	"+lfzDs3enYftJrEH1VnsKPCON/WdWY6a1uBHNhGD7/hJIAsQjT8NtPFBZw54JstCDXHlr2FypduU4B0/ycTCpKI2dn/cDo3+gniR" ..
	"CZH26273xCDEQc8sFWVtX/C7ZGXQuFcofOaH5ehFGVgDVwRWGF5mKzb0iIfMHAcfBYOZNhmGY7vXD+2801jRUD3qmfM3DxJ1neTz" ..
	"ydPLERizY5wCSULkasHPFixLCjYfCe7iu1nkOmj11QcOG+udFqaPwp3Zpi7TfcmukRSPleGeK2asRKgCPxCswQI3ZbroGZ2ajgYv" ..
	"TlGEZyLb9CXMMZtjNdNDc8r1AZ9oYn6IH70/Yuk6YQ66g1sj6Ri7NvN6vhZhuiC6Nckq8XBrPLZzUEfT5q3kf7ZMHF+BAynsc35a" ..
	"7E4Ubqk5YXJLbDwtWstDgvqvvBk+NDWXzxj8b44GF3FFifYB8bkiihU0+P6WWiGd5zlnRwKOZZt7qzk9jTGgSCh6rL+zIvHV52Or" ..
	"eOCbRV9R6zvT/gjdlxnUX3vJYJDQB6zcJ9bViOUvhFx4JnlKDnX61IMT2u9rwH2DtkPFLr5pP8VQXI6HFZ0580h478IMX0qUn2yf" ..
	"ysYibAZ4+iHV4JfUWinPw7QZiTGyBAt9Ad9AR0fG3iyzahi50VhAAE7p1lVBQrdbpeVLagT/uwzi6GK/Ce1pu8JQDnpUMBYJHkb5" ..
	"wJp0OBYiipqA+etD+RKnjOjylxKyfuVRFA4K3cnXFJkyGqw+pvnH7IwNW7zP2wEofHcKn56wPzTH4Q4D6BygaAExCk1pJRsL4snF" ..
	"zIFeEPFIcP0F5sGTohbwoikrUgzGxw9Knk1K60ijxZoddbvPKXdoVc0nX74NdUnjN835TN7CnL2zFxBERgRq3O+ZHQCV1dLAOBhp" ..
	"75MW/n7NiUWVU1EjRGmOe9rnPVADn3o4EeSCUsyTdozY4xy2cV02hJCp760/aN6fn+FqhDVjyTP6ympEqtbQfBmWBtPqIc1MmWlu" ..
	"Nuzrq8bpEvusRNRUXSSAHLaTACVkYFVmYhb9OA2kIsgsJXoFFbKvoIUbIAm5mvCWgOe5T1T9Sb5QWgXJWGazCQSSjKFMrzGr+8zo" ..
	"aBOd3hgE6DSdeFrlsCQ4ljVznI1lYIVFl59dZj+D0BQtSLT08pmpxWbLiVQzWsTg8auJ9YSGXLlnj298gkRCsc4UgqrFXjLa0Okb" ..
	"LE69DXAsiryQOE5kXMlVyOVb63QPv4tQvszhlYCISEQPFuZJNVyfdPLEBm/fhZaGOoFz0VmFXYLFEfpoH3esuafZbTDOmogBn2UG" ..
	"o5Ex8sO6V2wVX6e+1XeblFDAJObN0qpDe5G1vmHDn/iJmyIzNWOo/4Whys+xngUx6vfPXUOL4wOVCvmG/seRZb8KR6aS/34o8mFm" ..
	"di+RcwhVHh1nx88sgNUAm2uO+P7WJ0EohkC18cY+BfgeBQjMqvVBfmYYu1ljQQrdoiQp0CCFSNA7ltZbKybBRtoW5+VSVS1yrbVq" ..
	"sThwmPlBdh5ruCK/FZfvHvUmGcrgEsdz2Awp6fBAjaETUIkqF4MpWv6oZM60J4Je4RWAnKjkAuXqjfspZ6CXkOqZhiqEBu6KS3C3" ..
	"i9jghtt2bnysLkW7y/D06MUaNsQQtDOOdT9hHtYgUFurgYp+hi8Kc3PDveZHUSEvGhiv22RUxfwbq94GVhLYPi/52DLtZ//LTedH" ..
	"CQHx4iRZmOfxgeF10gfTItciCuFRcWBgP6bmLeL9xS1nJin38nQT/y3n3bAs028k4cWCuKNaakJXjIaLSREaTZhT66QhkTYqZxjN" ..
	"KzD9TvidA6gfh/AV511W4s1wXRyfxS7N85NyB/+y+TIVecsdAs+IfxaPbGQj/UuoKzKEiVaA+6n7ZSDoQw3oGngdzkINpv1K8vcq" ..
	"YFSDO6SPFspf/U56NyBB+8hH9HI4fc4h8jE6TBItZ7kybQjhU/hJiQsydfgNEYtKFIz/O2cS3kBfn/uRBdz3pceBkECGAL6FvdOB" ..
	"NGjVCgGkz5ycwTbDLcL/+PGp5wESwxO4JCMVKUClReZs0urBlu438f63ROKyNg0PN7RVadv4xl0m164bECZbYjx217XnCmnWd95W" ..
	"BaXHM/4J40IRPLAhDNa2lRSPLxyxdW+8zKUgPInGaLFtYbVcLosA7gNzhljAL+AXR/9GdnjjjFTASQv2wH+G6K3HQgENL1ABuf8N" ..
	"kP07bbjatMnn9ESlU0G/szT52OcY+L5CS2ebOBjs8gjrtERSjfwB4egj0Pv69cGC2CqYpybz8yvGkSws4kpUhR9AW9AuGLPuMkbX" ..
	"eVEM6zyCp83z/cWnDl6tMdmeAtCehA4VZVT35Lh5cg/DOsf5tGr6GSsXyTVU90GGKJ/Sg9M75LXTw/jWXqZWxOUABuGH6Ghq2NOP" ..
	"qXhSQhhcO7W3y0prPH6WPB+xGJF1+RFDcKXbbhflKIQ5hkWc2kClCRnlHICFnonf81oe0uDyIugzbCR2phBRVvZPGAuK+UpN2zDC" ..
	"Gb0brGT6forbzy+NcExjNaDFO+jh8WeNTIXe8myxAsLNIT1Ib6I8aKHZbUMpFYb+JQvVBj4cQi+iDWJY7kwHvKVFpugA+T41npWA" ..
	"1OAPOY4E7fFewiu/qsIHtyS3EBdnIoKp+s27KQg77KG7M3BbB1HrJbhCO4So4adiNwK24KTkORUliuWSqJHDxs1S5wbHftcvqkTP" ..
	"1vk84VDTbq/4Z7F9lcERDkph7AkfLeDNqMfNhNQ4AshbuakEhwsBNupqElkg1KIVULH8N9vr+CGSNAeau+hL7cG8cwggJicK3NHN" ..
	"VJzryvm5ssfRbvZaHgwU2Y3Hse1LeomIi7Hei2zdUI+4dK9uIojYoD6dDSlBA5vALVjGPKMWmnVx8MMlTr727cmz6jn9ZpIfjE9d" ..
	"mpgz7+7cPpA7dnuBP5GkpCLyKRfzz/bTefdUHVwk9ucFOlc/HNa4iZ/s7EDpNQOtjOuNpira2qNSZ0fPgXxb848opokZQB18NwIO" ..
	"E07TLdjkCwzADqDTSp3vXivCkQJNTb/zUkRIA7tnd27X7RNWPb2etgiddzX3mtQyttY6tijMnWQcIYhxatsIceY6mORGnAEI+dau" ..
	"KvjDscmaU6gw6/n65jQVt+Plh7WW7YvMSCJry6BMgMjJJfey1i40Y//ChpOILIqhuL7focIuZJqU5gZnJSUsIAYNL1770wOki4DT" ..
	"Oi26gLh5YPcBqdQ1psBsly72gr4eOEFOTag9Fk081ofr4anyVnGq/UAfhe110cl5MjpgfGGqZXDHHeRh/nmQhUNDgKk+Pjg7i3zu" ..
	"/G7Ph4hMbg/DfL7FvrW0+QWiV0ymFK7XzGlWUoGpjX6xCZXRQ3e3dvAOoK1iCRe0NGNARDbW6o7ZPqFhmfMRoHZcdoyMrWn+b0qe" ..
	"ol+xrRLESuoapaJhkpJ596WtTsD3I3zMf57QQEfpgutoV2x8zRBNmqRDpvTvFHgchPlqyNWKDB6Z/3Q8EciseS0emZda8MryZeyu" ..
	"fyi1ciNWv7pIDv1L2JnH64m8gdhWunAZyPyk/XmsoqeX6Oqf7ohxJDm1xoIZctVI/XJAFDLGaXdKBAq6U4btIz9JN7jd5xPX+BOb" ..
	"jWoS9srIy/9HiQ0+7gGUrR6cIInLwTYS6o6Ww6TvUh6/2zTfzIj7tLyJdu7vuocUnbT3mtUql2Q4k7ov1edJ9WPAvNcPXpq8RJEL" ..
	"CGWKNgaPCN7WZAqGqMfeOx1nrqWsXBvUZNjhfBl/A+4LZA0WxTmobe+M3owe6D+i6ceLqsG+fh3YR1taWEr8eVznwhCCTrlCMZe5" ..
	"WhSY+IqiAtOidE/5t8U5CQcl/pmRM6Xyhnj0LAZAudnNl7K4wmHWnw6cZiHDArSs7CF4SrQc87fbmYuKYxgIZEE5wP/7yIiFFyku" ..
	"wqSrnOLF/IUvufrsyxXCtuxV3VOxsuwJaJwjynPI2n49vC2wC1quam1l73YyhWFCVPAPNGbw1Y9GgPCBsKmYPYLy67gn0BgMlIpY" ..
	"LS74OzBO9xtst/Kw+7TWi4O6ymtsfNpKYxcuZ2DmES9oVXrC7NDMB5IbhOmweV52Bh1a4mFJuemQDwMn48p49Fo40pjY398gziDi" ..
	"fkZFgEl8eN7y1Ba0/JK+hRD2RSmf4A7UUdNEQOqFFWC8/2tcnIxU2qAOpSt+XgmMQXU2hpNuqUnINBBFnMCXN6X5Py8OxpmXTkUk" ..
	"iXdtae0byD0lAQzYJVfcTnMCVRDVx1uuHTSZ5EVDCfwzRKhR1erQrIsJ5iuJiDp7rP529UBWk2OH7X1QMxO97sTnbz2zjBtjHgPy" ..
	"nuG3wv598bCv8bEt+abuat67e0NtSfgQkpp1emM7fU3+j51kZXIVN/QrEOu7lTQV28mwaGT0lyH9DfssxsnI0QWy+gLaW2X7dQY8" ..
	"pyDeo56a2NmOMiwMaxtJvioimIngtUSSemsiCVcVoKjMW2WP7GaIISp+/0zQGMZAUxrhju0Hia5cFBJfLZ6M2g2va2kOryK3UHT8" ..
	"AmzuNMGlmyMCZJSdeoQDAO0eEDKekbN8MqTFT/uP+6yI0WGyYiK7z91IgKK9xpRP8+qQYbUHD6Ud0ls2mZ+GY+IcJX/bOEWGHJFs" ..
	"ICa+NykI104jbHM90FLzdXC+p5uy/0E+4YoqwCYqDUvn7DZLKBk5EQhW56WHomrlauN5TfiYTuCdK7jhXfh5t+LftHk4E/IhNDWu" ..
	"6lAJluysrsmZ/m/8DYC3g1zbbovAfSy/6TRHJ3lWNEtRJS9W0/WJlXg1NsFzGumrXqvtimOGVBtGyfWo01Q8tOeCFre0EGkJV7XU" ..
	"puwZBGLDUn6D1Q8v6MSGDosqcjhkL5KIWjosJAbuGhzVngAy6iJ6/aiqOidEKuppXMxLCG849JvuzhF+cLn01k3mJaKBhPVu2raG" ..
	"/WlkVRNm4QEFMrl4DbzCDng74IpgdPFG5spBKvghev6zJTmY4/T7mzerYjPXfKRGEHY9uKvvm9nButoyBYY8noNpRpngsGbIJ5rm" ..
	""
local PAYLOAD_P2 =
	"Ww+hYu4xP3gs1zfphhZcSEzdJRdvwe+LzholU+CzRLBnFAOO71mV8UjY9u68MWDSLeRTWxts4/4CFTK+xnWmYAgoy+zT8Qh1EtRD" ..
	"AvzZMVNYhmmcksRfPU+gMovk/v3zXhFGNyagIUxy8/yPCvN8yWBvaHV7BBKwswthPMhMFdM8yQdtNAFuDAu+jP7+v5SbWlbUyzrx" ..
	"Jbmwy0Xnb6MfiS5gu7upi4eHfIbzwZNJb6gd9ACUgViLTMzxpTAnnWGrFEpb538szfGd+WuRBIR0BQfBUsxP0lrBOxZKLvrXXOKE" ..
	"sl+0WMKMTcUJQFDqdKGHb7nFTrINMdynBFE+yD5Ulv40JInw1kAPzP2P7yC58I17iDYu2NRE2pdnJRU62xSW9lEuiz5j/YHD0FNE" ..
	"TPrkOxdmlcCeI3s28+sbkTvxSfyPO5unw+bM3oHoTo+2fM0pPsSXO6POlCAiYcOz3DOMqlWJhCheEFYr+gUb8B+DdnKvK81eGTjh" ..
	"bG64Cj7wyUmO5wy3Yxz6l9/v8t9CDhi7/TuuhrnQwCzcbqruEelk0ltyycVvDr779YPIm0WagiKywynByXCUW7lgiWfEtbYiKW1G" ..
	"A9bdfrnpOZONsfwAEaowMkZctyg5ikKUhEMZGHiINz6JrSXmmZW+WeGdv2rSvdTMDnligSr0hcmg4XQ74VaWmboM86PNjLg+EHHR" ..
	"zIRQ6BBoKUOsSWbWu2+S4wclijUhOsuGBEF/poVxqS9XbB7ulTYeomkU/5Anbn4vNriigjRSIZxSz1evdXEPwPCF0N0tZP/0SfW/" ..
	"tEtrkoIh69cM6umKLq1NgPWjUFah956bsv9Xm78kgZzt6dA8Kl10+R2xGl9f+L3t56X3/lXX9NgKDKLf4o5J/BNM/Ttst6UIDhZD" ..
	"9gCmNDTznUi1jNTTyO8l/+mCkjbP+L/gDnAP8UDYfcFQitFAZ6bhv3ZAwc2jXinNSQt0xVf3PbgmeuW/l7c5iBwwga46uazT/2Jd" ..
	"8wyjKad+y4CsUSkkEw11Ecu7ogGjgiKz9aC0iDSI7ods+815BcpkiZS1hO0422J7hXkBSBqXyvMeCZt4aK5Cu2kigX/pzZdWs2hp" ..
	"ZCZ+SlBeg9LycDqwv936Zb2vHmojA7N1wJYO1bj7n5692fEbWLb5bw+gdkbJv9UUTyVPffUMgRnnOPBZl17H7sagscmOBKXtB/pR" ..
	"ESlBTpnR1oRGiTEfwy7syeiZE4yepnimRGRj0SQFXCZxeylLIZroN3tC4gDnO+MGLR2onYdEetvp8GF12x2lu/xo4KM/gkKbeZOM" ..
	"f+V6H6ZGZWIlIPY2B08TogOHn0l8IVl/alZkaEOYw7nxVfV523bYD0QuZau1UxFoLGd9+vzmlZxJPoUTVgBD6M1m7ZudaSvn8ysF" ..
	"p+KkUODK3xGWB5RW5nWsF8xrSxhnioN8hHNXEV2a8yIlre8sx0IhMRj8qyHJel/GMQDtyp7FHVNLoccwyHs9lUemGdVWIzI658O0" ..
	"k0Jd6XgR05mY+fx0DGkVRS2owpjc4xh8BXc3KWPfnT02NcFnXwLAdKJTbUpdloVYBqh/c8hC6MyTEJ9ubU3d7XolRKYZQYg8G0yl" ..
	"w8RegZk2T/+NfXMXkDSeRxBJn4M+yCXMDuO0m6lgoeKm/SyGBLsMMtVBcDvT+9vwH1oRcBu4Q9RcfkBrslxj303R7Uam4Wr0M7sK" ..
	"SxPLVriYhGIFLBE2iTFcmR7Q2jCM/gNj6qv0wdyOO3wycEpQ47raUT3i7l0fZuOT6v5A1Hg0ybcmnWi5pyitqzeRrwFlHrrGmiNP" ..
	"hFMYXgTsjTgTHK4wfb52A+SHXAs9o1EC5UgHWVkh4EoqxdrlTj27MZh1QHb2VsAsK+Jj858Vo/u6NHTwAR+T0KJ0a2NbfeWXNpUT" ..
	"wgebLOwje0WWQ984T+852KQxU6zMRzb2sEk5PUJpTthi5gDWKggJc434mnBvGd9wXKBsyE8/csPGVa4Kl+GnZUz6TgxDyuFYIase" ..
	"vbM2L4AAln3Z7jNDwxLyJpw/rKNpaP0CGJVniWahbJYA6Q9amUM+TnoWGPd2klmTRVAJS4hnNwbdYIHw5/H61z+ydxTya9WOZ7to" ..
	"ohh1sD4pOWTyKm8xF8o5FNbHL2rICuhKXaYIjzPiKLuUovtbwOK0mUl0537QhRj4YMvjwWaKZ1RArJYZr7dWbOrSYJJDjDmf4912" ..
	"yyXwNu8qZsHJFFRy/pLTTDVq5zDTo98gOYprZQluOpglKLObNtzHfzudQS00TMKSDiTmeM9MTiGq0P5/81OgARaAfpHJxdGlfItA" ..
	"/RzG0zFp9kro93xvYBrUFdE2wEMvbjI1cDdoAWuxs3T4WbjTia378v1C7ZtWsrYTAHDULa6MMaB9rm1SHRzuHAzkK9WWZsB3OM7Q" ..
	"NTKspfymKOo4AJacYx8YiCmvJP+OL73eDqhvChZ7jtsZELCn+WBGaA69Y/PRPR5sC5mtUDFphV3NLp2X45n9oMVrBpEoXFmbe04l" ..
	"GmM/9Npw3ykqWE53Cvzj2qN4qEr/LUr65j8S8cEw75COA8D19BIdkQb1XtqcoWb/Pk/Re89DGKiaF414mvWhb9wuW8zooXntK/JH" ..
	"tm5XXIlq4GbwmSyjjESWU7wXnGYZrq/HALq0tcz/Tfq2wvLVvRyo7Z+FapnM3sYQLsFGyv9nDu1LWUgJcSUyy6c3UNJ2bu5aTRxl" ..
	"D1ZFfklbMY8fwQfNnIeJVEZXhe+7Rq3yW9zKkqAcxIP9nNt4E2tygNyOSHZVaGdNIJm65Rb1XxRJ+VbIt2FJN+X7y15UtAq83ZIf" ..
	"0Fb0AHDQatlVts5PTvKVVZb8CfMNpg4S944KUVteSgcGgsMRSNyBPfBvuh40c7BAg14KtgVS5ndV+ihs7oMr5Ovuy89RtCo9IxiS" ..
	"oSKiLatN7Sd7dEc9rHPeFPBXnrYP0OoYu6n0N5c4xvqcAPi3ujthGod4zUD7Mr86PpozB1MRNWBj3LY4b9vsIJJ9CMk7I3wUt3TS" ..
	"wiZ4AWHpThGktIhVa5UwtnP3dMRhKqJdAzGJOfXgHA2tWRj9fFVVaFuXXf7A7DVJf0shL2trCJs4/6a6smRXqHU3Nn1Qm4CROjnS" ..
	"A20Fsq/KANIO+13+mWNPN05vIpU9QbXwzvKOc4vPJXllOTowFxhJh2Jc6du9H1+CPGkO/Xo5wJ6PblNGr08eYUh6dGSTlfkYXwC5" ..
	"HYQ6vFFRiSqU3tYh+a1Y0IK9N+skcxwGgLw8D4HncWAft6dIEZ7/1Vn/B14N8Ig/pawhLW1FX2MgcNvMpssqOa3fmLQUXHmPdY3d" ..
	"cBjAZUNjns9XQVVpm2em5Ie9f+OpGeZuFCEq7y8j3urMsk9nKAOiL3Hq/q98ivxH6FMW6rCiwLuVrNXplQ4CNK/Po0Es8lbewhDS" ..
	"R8lrvcMt61wpXNk7O52MAhD5BToRn5I0Gw0ZkuOlrE05Rtd80X/R1ng1/1l5WSTBdUhA0FjGgA3KYdJjsk9VLtRdmoyVxw/p80OU" ..
	"EaKU3sp23SntHdtaiVed0xSKwEDFQ3ODc0ytNhp9BLDArc9HZDcK88hGOdZ/CP1usm1YPpBlRGuDKdTEA49Zr9I+whiH5H2vpk2B" ..
	"AcEybcrBIR/Qg9xIRS4MoDLfV0M0lYYqjGxE/pn/kzkinjSDmJI78ALvDAbblz1QaG+3lenhHCvPnF45h0a6iuIahb3Gwzuf4Hvm" ..
	"JSvqXaS7zPKTZluTO+N6yseeXjfJ3sz8AzKG6vWMu0iIa5bx/XW/IHnUzmUA9scgKBb0IdI3pSigX0F+quoLFlx6g1tCWrRYS8xG" ..
	"xDYF95J3YtmVzgh5LAm+Puy8bqlP/HUblv/Rk70CLrg/RsGOy9KnMqKi8dI0nK2g81xTat5oeTJNRXN55msrtORC5t+UdOiF968m" ..
	"vXriyuPmUb46k0+gtciBMVy+sXv87HKclqire4bS4Hq+Y2mhmFaW0cUaj6O3tHuEHJlC3k48UiTY8TqUYpnQrZK3QQqjzPQnFQLs" ..
	"YFepLZo6GwMCoCkhu3NrmyyTeROKwq66Vk7+edbkug5uYxKjue/NeQnzIYIt8Hh7wp0bwuW9Zg3LLvxt6Q0pZlUnV3ZnKoPKqx7T" ..
	"GB6i8Nzk97Hf2iy8bjoIx/wWvUtPNlWm4DSK4SDm90MGs4juUe5Xk2LTu053YsqxJwKarkTaRvQ+fxJn7jZPp78SkPycE2cKWZkh" ..
	"rHrxti4xUk9pZJQkfNR9mQmiqRYpDnKiXGE59W9cxYob1e/KUCiblEEwp3XmQJt/DrYVCN/phq9/YnvIxiGUsl4rO7/KkZX3wLhn" ..
	"K9/OVbMVDgS6TAxiSVYT/KbNqTZSzf86C/zPh8oRc1RYiKOYqMmuOmccXHGkw1N5SZG0+9OuQtgcTSDx6qxQI2vfkWLgWi0l2k3D" ..
	"tXm2F3jdX6xauLKZmUqSH1f0xjcq0aOMyHLqj+zLKZp2TnT5mD68jXtsWwLGTtgBwrrKEJykaQh9cAzMJTc5FUXnPmjqeJtm2XlV" ..
	"SNB37aqJkMQGgtNUmc2FBqMk1UFThHwFiwfrqrPWUZavSj9LAg9iC/nIqON8CDvOIK4ZPEHlDl7vWNmIAwEn/uNAAXMeKwb4i1lb" ..
	"8YF20OzZaGRIqjI3BB5Z1ewmrjTCciRGXy1p9Sq9EnznlEBVY2WMB3ew4OzE0Q1/ISCCMAcildfWWLo5jJCCDBdD4lFvqeistj+a" ..
	"woaDAVAT+aEQnJC0DGPHsI2IQC5cilm6aFE5jBGCKGK1QEI6v8mKNNr6KA4lX371y1juDrkiGuZ0ghGf3MAlkV9yTlVddD5IbchF" ..
	"nFuv3wLAHiVEo3EiLKyLZIeHK3SBpWuB3tHtQhh/HQpNtBu7k4BhcrMQrFKfcZigGgOXn4GxNONmqTpWctvVSWmbtC/3LAgSpuf8" ..
	"BXpPeteW04WqDVFAo8WKdEvMqdA/cENW5Lhad+9okrTA8+ntbWrPJhk7NI1Md+5Sw7CyKagzIaxQqDWQ7JHvY7aCm7MDxP2vdcRB" ..
	"FfQpsMqbK3T5eI89mO4ZdWT9wyun6QRwek8cFn3sqfMLPJlq2AuGAfOi6AsKf0YH+f/e/ZYZrZHuzlg8f82nksAhXF55l+GpXbjT" ..
	"JQTJvuc3z/JLGwr9bOl2iGUOUgPVDxx6wbPNCaR91a+ykc21U7ASXvrm/hPchOKOuiWGctDQJ33uKMppLxgebpmQmLf3vSLj7ozG" ..
	"hFBKckYefSl3Yo7AKjiPCB4TOTxIjM/zWadZMQqDlg/Kn0aF3vrh0+qcOtKHLzKtsnzmwbBQy/C60cM/Zi5xS+oz7CTqwlQKglQS" ..
	"4XtHOcNnHeBU9nDNzjs53xorpcxFL2MuUxsFSmrWNzGLOWTDtgd93Ycsf5d+L/aXe8OiSTZabkB+QFSbPeKPftDtu9skWgByst2q" ..
	"/zDRQds1N5L97j41J2TU8nTA5NGKLhLjbYyJbnzL16xMmkStrUSm1bz9tqRXU9wRDKYYgihs3KKnp3T1E0Cj6ZD0Yyrjz4jAi9TN" ..
	"FLqAkMKGyXY+qBw7LKd6/w/ELBJUhWIvmjXsflmKkVmi57m2dsGmKpNurLt/zMuEydg5q45mNqqTElYk5BQgNeFUa4+wmr9d8BHT" ..
	"+sA6Rslfm3xLpYQjFtM+bjECTwZJLVnfTWsUfi1WKG32FdZcE8FkoOFIo63nv5IXKzLwejXL24q8VFMyX3IdwUXubXT9MhajKcX7" ..
	"LbRhVCwv5bXiI755MQE/cqkKmkZ9iiGfotaT0+/JOg/7MxkJSRK2EN7AiqE552FFK1alG/4C62xItD5Rc2ozUct4YzriZsnEvFZn" ..
	"GkKJNifD+NTneEM066k8vOjkCdIgymnBJjRzyuoxw3b5moAmI+IFOYLbq1tGVpMY2OtiBh8NyyM6QEhowNCE53INiZVu+w62Uh4n" ..
	"u7/wBVC2i5Brx7v/7wcqacLRkxsj3LoqdaikiNVGX8KEDxdxRYoo7VRAcV8ggnJU7qekazTet+Ia3VFJoq9qk36lyR0m+vjXv9ey" ..
	""
local PAYLOAD_P3 =
	"sA3evVH0IyyLOP5YTbpXTdLi+P1NGj11EVhiQ4fkGNtsNBSSXdeJQjzSCKdBId37DZh6ok4SN3vYDUwq+DGz+ldzg90Z/clqL81R" ..
	"36HYEwj7PRhvReDd/qYU3/juCt7XFy7SOskgfPpYasG7qk8EsR8Mg0M+behc0OrHxCumf7LlTiVvZrHCW97cAFBJ92xh5WcgEn7p" ..
	"FOtH/6WuK+al7IvEGOq+uY5VezrEta2/SnGgZoSNHrFa8NzUwXtUFCU51pGg6CdD/mGegVxhaI4R/OL0ggU0Q0PyrhJR0/0MgTTz" ..
	"EpkGKNQuBZqxZspczin3/Z43Tae/woPfA/N4cIyc3hn8B9RZKorJl0TM2KJedh9mjCAYLe+UJeKo+q6hVFHGZiFlbsPZziXhMxoE" ..
	"hht/vyiTSSEg0cGHXARw50L+vu5602pgKFFdS/hFSfyUUe0FByzpD+Qc014kXDCkqLir4d3wnRoCWN7XWfisi0tsSrDvNmT6EAvM" ..
	"G8T3fsiKBNfIkYmEqtea51lstlcMw9YWoz0ywHbiSdU81OajSibL1TiLbg9c6OlZCam5bhsSNg1x/lCoZioy8izBc7i+8ZA0E82n" ..
	"u+FV0cXqrf6piahcfXOriXGrG/8bKYB81vFk2IDBf38T4nJ8d7zjhS3q0YNzeTgGchVRHBEtlQGQ5DCPUaD/B2gEkQwysbWankIi" ..
	"dVH9cT1WegMuNeNPKvbci4+QEfiJIXyZHWpWHTenpnaJ6SOLX2zXbkMqw/pC849AbpwFiyxwZnMIM5FivBQ+Q52NjXqgUEHrfWbP" ..
	"5u877iTZ1wMZ6ODodNUZi0T0wN1f58S1HvBemOhWwjJR7wmIWR19XX7xC/Cf+Ems0do2QnuXMhRbWk7TVgU22BhIU+sRnXpbRb/4" ..
	"iV7UEoklYP2T+dCSPyFz7Z/TbCl0B5aXW2lXqTppH3AUiKgnGvfBX/9+3nB1MPfT4ZQMrwx3JP2qN498lcFeI/LudNsse8F40hR8" ..
	"/C4Y9Vj3KOjy7tDBdFHQONcc2sMV3J3cwfJBocwtHU8wrOGwGGWVRZFg0PN3EmqRbXxEuANEyoS7k20h5g5sc86VVEBZWMhMyFDE" ..
	"AiOFLmyO6WtWZdZDy8ch5SHjwYI8Jl3aG+ei/VpAVjCiHVlBUP68O+HvMT+mCBl8XxyKyq1qg8OO6+mc1d+jkDBDn611Qkx7Kot6" ..
	"xqHyw6YT/BdPZ1j9vnOiAX3tzvZOJjuuDSbkTR+1NUQdqKitU7EDvcQ7PxXW4xd3TV3bA9PHvIcw59faqQwWg7BqfMcwTfdx5MQc" ..
	"OMtROaxALqIWVCPZJPwMhX8pyqOh9stpCuvwgKwaA6xCb7jYWicubaWJItFsLE3VWQ8jfpD1sX8ZQNi3I0L1MqXQzk1uwmunKnJG" ..
	"zQKvhSuh4R1nUhmO00lu00Ljsw5OMyt/Vds3K7fzPqMrIcl94xd0yDOBMT+x/L0CKFTZAl+vt3GMSEMB9bebYcYCU5VOjnrbcD13" ..
	"KDTAaywGufRt4FOiJWk/COixqzAjemiSO5FIdqUQ15qcyNop0bUaurBNZ1c0kFHfa+3B8wJEgcIBf49eT8rAhtUfcXcldr2NZKYN" ..
	"XziAeOzpitxGvAP2RmvLNHVdlTBVtszJ804w4hNiZYyeN4UBrJmhXVtlENFp+Uhpn1oMyBGYMdalK53CobSTh5D29MdjE5Rvqpln" ..
	"4mrgEEBLqiAizeKeyuiStSuL7v25Z0MkV0Cbg90njyHK5eeCR+U7QYP267ToOeRQmyR+Ebg8VuZTZkG2vreFszIkSKwWxX2sHW+V" ..
	"d85R8P/6FCqYqaSemlDJTQhUL2Faq2AODQmGNbUUM12Fi55j3THytW3hCkvcdczR9YKnb/fmQQu/I2ONOPPQyY3PuLtuyszjE4IT" ..
	"fqopG9zNvf2ZR/sFJugaySLwVG1nE/n54GoIRFfzEUXhmy5QPE5/W7NNx5aDCFSYY4HBEQdyENuUXsoLAwJjgGFyOqERDrB+W6G9" ..
	"fxnJ1r92BXRCj7yYJoNbmGu1EMNxdLzvOu8cAjP4gZl2Lf7JD2xbCpoTKuaquImc9YAtz34k+YeJA/er6khkn0ODEqXpbzckHR4j" ..
	"3aTaMXjFJuKMS8Vn0hfs8Jml6sADFS4Vtp3KBlMyP0epCXKfyCmdI1up1B04cvGjGRRFfFH7iQBolxyKzENi2i1ney6xyqnNh3Sd" ..
	"pPpKqeatEcT5IsnDTKUQ89uxg+e9KHV+goKQn2//RIFeZlmbz4tW731WNoT+YgfDXgPrkV5hqg0po5E14BRNdqm89WT7c3flEza5" ..
	"mLt4e/meU76zyqFDP7MWu2tJlsUCcI9C/XCmI4x9f2SR+sZUjZLeLCVPMfZ+yH43wgKC0G5Oqxq5/itpclvI5D2opZWVPceXUeAg" ..
	"QQrPeBv58a3bsgfPLNq5xpY5pS3AfqtcyYVOJHkBFtcgDlbf+ZT1aBcAEwl20iVj3/IWB33KKSDSjAaoLAZRm/k430zgs/Z16Q+4" ..
	"PlH4lPQ9sEZFD0KLsmuI2xm1QVwT1MzUqjtjh6VLCei+x22T4MqMkVOTDf9ZKOWbEV61VM2NHQ0tBTxbjkxGrw0HwfHzT33VBHp4" ..
	"TNezOJE3FFtUB2wpnfKGFUpQhp0FpCFmR5yN3nHD3zt9b5+mFUWUmoiP9BnDumL7cH6+bGTIXxmtwfUcSg0z1s2YwX1sl90DjuEj" ..
	"eLypa0XYKXEhKTw6Nx8hVM5x6K+fwHLJEsHjudyiafVeM0ZB/R4pUW4KrSVJTcW5GF37cJAABZ+tLejPMB/ITUknUHbg1SzIev5w" ..
	"unsP1zjwFWb37ur6Wr6nGbRG95fPrR118RBa2Pbj9D3SRB45dTBlVpOFTWzF7nu0OfHqQZyG63OR6lf6EDQk2lX6zOdtpG9I6BRa" ..
	"v5F2GlQScn0M5P0wyvADSOG0//Cs8wd4ePubVy3HFwLftKY/Az7X2mgziyyP6fHfa7/tLjxyGOlHiiktfu1GHwGhjnKw1/qIhV2G" ..
	"jzL3u+bXRy4PSMZJo3hG/6UDY7zOJn0+HMOEGhXn36hHv0u9JpjI+OEy/2hgHY2iza7Z7RdInu76Yen0SmbVKSB/cgwMnSQuwsdF" ..
	"jE0GfOaD346nVh4KTCthraBFsw/TqC56ivRhHuD8fYUkGaxCaf/ftZUCaEJrtI9LCRMzs1timp2As6KS6Frvo9qtocteV0xPZZ4m" ..
	"U+IB6C5LzLRs5wLea2nBsROUxGCRSWgfVxveBR3U6SXa2IXxoFJFZitFWohzGIMP+ka2pJzkW/bm+4VjL321jRViw3aoIz6FBNF4" ..
	"QIdh6vlHsmD8zpFknMMM3+pLIuigu4Na8KQ5Dbyyn4FKKmDvM++vw7AK5gz4Mo5Mp2PswMjk7i1h1z00uOskTg0JKxoYFNFeRNt+" ..
	"dH3CWwuy0GgVFevlrbwBRfZFKovLKr7ZYcHQsixj26WZj4kAMk+SRJsP3c2oj3F4nXUsVYeFooC3ZjF23kZSp3F1bW19/HIiY6a3" ..
	"fZ9malgktGVRg/4QrxW6BOILHhYlbecafjAVCLt+xdzUQmTANX9gmPXkmyYQhrLL3L/tyigb/DHECex/3xcBXeqN/1F0mIL5Sljz" ..
	"aBL60NWKDJCl7aLlFHPdplIQomjaDSxaOMKqOuH2TEzvkWRRMgYLb1tUb8yFulJobzztuN0OMHUIAcGogg5/ZXAGuPyxGAEE/gqk" ..
	"OBSGLbzlOWPQ0pM1Lj4MyCUn0ervf056pbGSD1q9cmOx0jsqEhu7+gJd3Oq7xX6xPsFe7MeftAUudUDLhQMMRd5fJsTUIQg3NYRR" ..
	"zmMxVefxH1eWhKD9zGbYhq8OO3DGOxX+fmjywR660pK9RO1SqVxh0wybGePwm5wEkGNFkDTL5wB8iqCNjJmR9e3ffApyeJbC8BY3" ..
	"aaviecgkQaXn9jO2zBgBasD+8ukrV+Kgwfx6dYUGjOo3FB2boicJaktol001mgF2xZ81X7pZ5kMVdgNT45Wt3jtXYFdFJ6BNQ+FT" ..
	"S4aSYjR2r9c+be1fApa5ueOu5bQn4Ut4dJmBqvYrTW/CAeT7VzdyfGDbWbrpSbjBB/s6cEdBwD2wtDr3az63P+8JaCvk44QBiIA0" ..
	"1XZwXNuo/j+WXxkdB+6wzKzP30afetfFgz8nT1HAiRnY6RgBYRzNNwUSHuDSzykkOi2hIPsHblv6yQGrYd8ClSbgD2A6MAQvz1/R" ..
	"5B8mVe3n206X/+hxPib/y/iD6Dgyl6/7n0HgE1+BioQQf0b57jYI36NtGP8oi+P7E1v5kbIVLhzFRu5UXCau4KWpS0i8QGRr77lL" ..
	"SHttwRxreu9KeBU752a47HiRA8MLEgtn81IdrIlrBuQg81BqIf5KQV9W3bEnoX7M8oZPTJ83jL6LascHKDlQJvQ8fI7Vw5mWJSrX" ..
	"xyH7K/PZF4E5Ma0QZBYPcMVjMC80jRLy8uQjc5/am/heWRm7WCtRNiuhVrMo6+zW3ogeEZkHXRm5wwb5r5DPd9TKJOrRzbFtEbbK" ..
	"aqQ6sCnSMiJEY9iRhdY8gTCfOWaehachvxEfPV+LhrN6ZbLsnbz7aMYdoRCT/KEM0Yqu1PuzJU5b0cIbkABSXdlsqG6lTzEkVsCz" ..
	"VM+pj3Fosoz/TVA+AQRgQigJbFCIHbuqfONq7vcBAPFzS+ArpHqFsU32eCEHpuh3g95Ib7L+IsxSMOwJcEzNbQsXVckiFrynDwLf" ..
	"khBCEqepQljHl7doP0VacTw49h6E5CL0LXNkC1F22dq2lNeEu0T84HLz/6flyhe8fVd7OwUpdLNnEeRwA6ttAYmMkp0ND0jGaD1Z" ..
	"vUeeotZbpC26xTdfZ0HC8Bsua8ycUO69jMRJdV1NzAjlZj13fIwetpXEZ3gcAQJAnyWEtvFH2cNOobiaQoFd+uZ7Iv8bup+4XaTl" ..
	"1sXyPPrgGRn6cl/X64uEIvcJ+QSW4QiWKa7kkdzIK0i1+eG4BvHujwtxx8kNa657CeZuukdBwJ/GTogloWWyGtuZXeqbUk2zJ/v4" ..
	"MG1yTgn5RiX2VhdUYkJbE/KOWI1fl98SHsPVyGJ6Mxn+VynIbrYlGU0sF1JgflvEt5ND/aOfdRlG6TuPWytspFzxoWuIFO1u/1ip" ..
	"D1vJWJVJvwHpfhQF9XFdokOHrYrLKgXTLLXge7RJMhYIBzLkybzX1QLTw5m5Wi2rRqQNw7pDm7F2+CacDltdHCFMMpNPgOZmmg4u" ..
	"fxObhzMDvELzrib2MDtNNblTArXji7vzRI287PWSdzybq7NfgNu480dkSIlytIYriaqMqPzHXgOVW7pCZYLOFx7C/rQP8tw7V5ji" ..
	"QTH9LeMTUHCaJ1W41KiphsGdbQGuCZVd+tXp+Ixnmp8cVq68mJ/iMHoO1Hf3qHMuwg1mYjIlQmpPVSAOC2yNLulaD3y7tVBKTO2R" ..
	"LbSBg5EEu/sMU1ZClOEnE4NOn8b5nhqzXwNv9Zu7UEQnh7ngkb1tWmIF+oWj8mmf6XQEKLYZR4T9od9WOBK2cSWwlr0ejLSb0p78" ..
	"rCoak1LsWxfVkug2kAfRXI5yk0cgQcce2+O7fsgYMG0NLpQgyHkgUWnEnpP66PPb8tqeBMvPUiB32Jkolan2OptYJSIczGNjDYZW" ..
	"0rJFrNlVRqr+uap5Whk50T6pb+j/F8VmnBPMDtOCc2hH4889NIbVUIZQpcSfKa2w+F7LXSF+N7AGmIjEaDxjtADm1odOXJonPoyj" ..
	"WAZqQ1tGbpwEobjLcxcl5js6kZbDuG4AYAWrd6fI9VJG0SsHIwY7RYDLz0k2SELwV9YZE96CfXMsEVNuE4/7qvHxGEt3tK7ahFUm" ..
	"VjlIuEIV07/rMcEykR8W0yuNy46YtriFNwnGcQuPCo6vZrh/JZ3bSH2wDnD991roRHtrd+vgN6coWh80NmSmbDL6P7TB8CoOxEXj" ..
	"EgCDZSfkYW12TzIhNlvDk8tueBw0K5kJCt+JnKq8x5YoxbbrvNETaoj2Ql3F3mp5l6MdofeVyQXcRKdiTLzZ7ZA1Psf+d9JQ9NlQ" ..
	""
local PAYLOAD_P4 =
	"3bBY3+sn/bYY2qMk9T2D5vkRpTRjoH1YSa9N00gW7eW6ozfI11Nei9ykEQdKl7CKmnbouBgD9L6/df9aHrsb4Fr6kiuQSlBtV672" ..
	"79QCch4M9BJ3YoZzS3OlXZMkddY0wu4QFC8WRImTh2qTOlIUKZh6XGbXRSBu7x4zDgEFto/SEEC7oKAG28nrLdu30gOMK/1dOS8K" ..
	"1l2CWFjl0o6b01DPPRh6Ik1sG4AzRHOZVMNsMvM0UshZRpQfxZWT+nfbCTGQLFJP5AUEEdo6I6Ztg2xaCvxYJvrcUDvlQJ6k7L+W" ..
	"en9vugF5KaA1U0CBpaOxCYNSF93KzdCA3P+8+K46dnQZbI+PiPg2N/yIOu1yLGfdnEGWpvVzm6zQRC2qa6XhDYRQUpUyoqkctFok" ..
	"8eK+txPflvkHO5xMHRWTp/s7wm6oSZW34m2/T06JGsMHI9sLgq5m4cwYgHtxq0ijTwHa0bxDz81uGwE764M9o0rxLlv26pJoya+u" ..
	"Rg8AQgTU5Y+cTeg5wDX9HvmXloDhH3J0yL1GjdO3sqpkGZ6Or3cIYeJlEL00ZsB40p7hP/D85Oj0FBV/QcLB55vygDtvWF52Esfh" ..
	"uadiI7NU0kgPeiLRj6v00cXO0kRaVSupQL1Btz8yP0ROTHcHoX4xZstwufzaIyYiw4vomZ4HE67Zz5TFd7ARJUSH1HGsoKDo30uL" ..
	"Vnx4ieMR8nbYVwiUeeA0bVVkrtOq00S8882K7PLuBjL3diI1d81wyvfbRKEA9JsvMhgwC5vlFvWXC7Bl25Rqvems39NLz61mSEtZ" ..
	"mlpuIajHK1/fo4RqRUn64ftCQaCnZQ06pJUr5MDlSUVguiSB6ECc6EokXEnqVkog3N6p3+TVs8+VyAiG09jigHYCs7hRYHBMwY6L" ..
	"lI3p8Fn5nl7VNIH4hreypuQzmC2H56HwByVevlmLE0fHCQfeTVPm2Ru5UBkISkaH8T0EZVQEhOG562UeA7fy9UEtjPN3EfrOuL7I" ..
	"d4BPGsGbviuIZmSVTP0C34REz/jGaUvHfViRocCO9wpEZJ25RXer1TRk9AmsUyEPd5c0SVKxR0qlQ5F16Wlt1KeTtIKaPeTe7fwT" ..
	"zCTrYauhPan3j6Xb5ZgUEGYjLcjjf7fCAAh+SzvKcLtA0qawN2fQkyryVmYZUPU8yZ9v0sF7QgUlNaM1CG0gYEC9rinPG+fVxXhw" ..
	"8wS5BJYTjCX/XicxoISwj16/dWEnAUs30UE8Ikk8yiuf5puFrAo7J5D5Iuk6yvssxbD8FTLeBE8Io+9JbB8wTgZsXLqUHJ76pK19" ..
	"YePQf9kztLeWAKpVBcnWgdSgNCCMm7py4JssO3RWnSZ/Hsnb4c1559uo+ilYVWiNJoqlQZclin7Z0AokzW0yh6ISoJAPzSHVyfWw" ..
	"cO2xKK01NGlr7tYwUhwM8rNvnym6hINps5rmVKM/uXj3fK9T4PANoALqRXCLtzOu6vlIayerPE9cgXwNgiRIbfRwQlpuazgj+vjX" ..
	"LtnJVPAZOerRTVMx7lLAGK8G8sgG0ie7L3OwgZGtgXRWNwF5jWS4W+6NfXDtZnRJzjJml82qUhVFeAuzLm+cIZxp4mKscfnqYsdE" ..
	"h6P2ueMeYMSmioU/o7MUr+zqan+QmGwCtK32sbb7BtQ3rjb3CzFkq8/NG/+DjCVwuwKgzpJ3fb+SxJE4HlJ4tlE1bMIyrzkgS5v1" ..
	"sGG7DiyS+w3B1POm4OPbkgNMJybVmkhGJlDNFKzGRyvUCLgVsYlKS46X0zWBMj84n8nBsqPGUL2warbFV9ph8ZMJC3TZdd/mML2q" ..
	"OUVU6LuYhvk0EtzMM9NPxIvm1VGrNOIRDVZuP3zbGJjCkJOdn0mVLtTSQiWjXaXHgMIUqea0y08u7ZqLsjsEo5/2XL38ST/VEO1l" ..
	"/8HC93yDDH5kqGiefTeQUG2JvaGMMtkVhQf8gXTPBRnErWfBI3RLTEQoWl0qqzDDpC1sDnh2gFXp27jaqwGqI1hQT+UpNOJCBbzR" ..
	"dvmeJ2Dq6Uk+IqT4tKo//QdEsbUW7vEf7JR+WkZN1jSsnZXOdzlyhTNRuiBy5GlIWJIYqsnZ7HNBysbOOV+LFN7Ic4sTrJ6orNzA" ..
	"LU7RdfoibNCUOdxMff/BxDkGemfR4ZPapbyLY2aqmvE8ZhCHGubd1ZxrViqLZ2skdX7smidK72ai72fBpOj4mPUhvMSKmK0XayN5" ..
	"Dp4iFb07rTPbkdHMiFoRBhezcSvuoPCsnLm7BrYd3oHa/6IxwPE2F45uBoyfzO2gXGLf0+wY+SdOSHt33auRQyghZFKudru30Npv" ..
	"+V6+LWLIXSpMb0+F7AA4EUgWAJykPcjAjCjzahSGx7XD+UDzaEOPmBrCleCPV54QkVhwEb5qYBCXXctvbrkBPuSBusl3j7ozklE/" ..
	"nM7awCD3fXyJGbqPi28hMZQYlhw77PpQubJ+gP1fwDKPVGMiWo61o8nPvelEvwgl0PvlEfczBsFfKouZlqZltz6kV8YAnZsl2Ptf" ..
	"tUOVn6yrgnGIQcJ7+Me8xEf6xco686jsZE5lE49Ne33g06LJ52YQM+J8sHgvhbCN1xzcD1mzoYriRz8jZQy7YzESHoO6FQ+lC4GC" ..
	"oG10aYtwonVyZTkKm2gMqchN+4muuKqQoIB1hxzPlvJ9M2+X0UkSQFl/zJ1b1qOo0Sxc4UqAaCOXejMes/9BzpxQBjDBXiuWc6CW" ..
	"Fc9xD7DThPn3+vZD1k7jIhIhA4p+LiKIFllZVrl0QMkYz2dUHVOe971Mz93RjagHTE5jR/Z5GxaoIRZjRjxlsD2G8VZvnFvIHN/t" ..
	"Hv7qkJCLTjY+GPcMQWOLAfOOglk6u9uQprx2C+LSlH5NIsFczXbjy8wPxK4Vb6c2AdMa6I+n92W5T4vsvlgm48/qrxJlGNMcMaao" ..
	"T8aBSk7cQ5bn84bkx9jz8eb+iErQiPWBtiQvyf5rR51PMx8XKATZwe8gyYyDwyDhtg5foacL/wmd5+VgNd1NezfBATFLp/3xvmFg" ..
	"5FEouUSJts6jy/3f0+2Aaqvq/LQDkkrblNjB71zdn1ENZJgDBkVsTDhsODPgzxvzOj/mn4jpS5sGCjlUy3FEbKbCpvWChOXFeANH" ..
	"x6Ni4Zb74WpJZ4TETZLoEgxqcGIGFHIPLso/EzdSANf4TeqxYQ5GN1Mhh3xdH77YeEFLCQJFOHGnviaTfPb0QK8rmDfG9yjDT68G" ..
	"EVlpF6nIQQmW7oFAHme9rpxMtRMlanGGuXniASg2uJwwNO0XieZusg30jc0i90DzAmfhdsf2v4TJC/uaDJ0axN60acQo77K+xhru" ..
	"NXVNibKcxNSzert59Ln5fU0NTDggRCptEZk9SbKbSLEgL/FeAs+xc/F5mAblCIAdMGwTct/uqTbzkI2/zWf4/QM0s/2AlXnpkO+O" ..
	"F015EGtBWST7boazQ/1QJAtd+B8+zfKNqldqSSTtyHgxHcSq8wrQElfCeq0lR3ijzNK7r4dnEOXrQ30cjwiU3/a+1MOy14iTnqwi" ..
	"s/mdNismmuK1EcF4dcDvhr5ZHRyW79h7+agetr+p5oghR04eGejuh/RSxmXjA+jIA/z5YV6XtG8mlQaXRtNPaFRWSN7IEmm46TRQ" ..
	"thvqrssAidx5aCCyTOgkGZ4HpeSRNygdCCQ9HC4csoxE+3IM1r/Pqef+QQv9p3FPAqXKbR0bLpoPntkbZaX7/bSEZKXF9dd+osft" ..
	"fBWjsItnyu/VhsPRcGOPSmSYAu2I8ObYitn6GVUEVARWxu1veel23oDW3ioWKt0TFzyAE7e1XDtb8gITHwIcPv1KFO8K5dchgsKM" ..
	"0Q6nYHVJgE+k8S8XmAe4kwl3tvzI3IGWbqsAqZ4bYC+Zp+Aidgy67p4b8VoozYrqOq4+CmRb4C7UOCvqqInWFt+5+aVjuEI0kjxq" ..
	"xnx0/OGigBqc1rhath12sL0RHg4lpEft0cefVVgeRPbraF5bM/8+oULbx0CCaO8CEqIYyn0YqSWJeq44GYEnpcBBr4gGepgLy1+/" ..
	"wserGcN5oENHKRDP6XTZJw1M4xJgaJNcsOcv4+cIytAci8pJvbn8neypDulBh63eLN1Rrm3vi6cgDULEF7b6ke5kc6FUZuyvwXSb" ..
	"Wyf7eAtuNoYssDKMLtjLZ4wlJR7yR5+D/zAj4xBjrtHzODGVEGEhTCaz9pwWHGcSul4/KZb639btx3Uztq4L9zK1Bo8JKKQghLGh" ..
	"K2Qwl4NzblLNUmcBTdnRhsMq/kAC2wl6iDrab08RYHFEfd4jzZBZ4b03bNqhHDmsAnr9t6xbvG4OjM3oHA8UinwhKhb/vk+gwnsu" ..
	"5J1GIArhMJt422e/MasMRnnpVdteDtz57R7o95XfZVU/MPa/tPAvq+Lx+8KUDYywgrBSrAPD3Ehi6ztr3wmsOmeBHUgqdjF0RGNf" ..
	"jDDvyiL87ZcrJgf2105183QE1Na2iAeRDTWhdxdgvTPAQDYgHj+LhQHgJ7VW64pv229n7OyqpdpZWA0qGCKo3rIQ94fgEQSt4d33" ..
	"Zk/k55w6snN8v9RiNwqN14nEuMuwiK4ayvYbKueWZBby24SIHUgy55ftM70YOhdal6odjNTqHQ+KZVyVRieobqlvB7k4rpnAVUJu" ..
	"Ktl4Boua+Vsev1uopPdL6TLVeGGc65ROotJKwtxTsIqYLiBRngJaktIEIDwX+SJtqTnn4LxgTUMulppvlybT7RjfUHnBQIlAZBU1" ..
	"QYNbWI90JGVWsP+PUFTBplkj4mUzIKzQIHdcsHdGnV0AjoIYkkHsbQk49mAXsCKLnGLjfwP08PDR2RWeniAa6GbU/cCeHYIkrDeL" ..
	"l8qaS8pLA+XuSq6GY7tQLehvbxbm7N4lNXVAVeCyAPrxxuC/nco6ZRdjjQH/pxKCA1e8xo1UMJEc2rclXKhIEupcbrCXJxOOMtgu" ..
	"14uAuqH4uMtSYWh6GZFtvdRI7hvEViCnLX4+12f69paeJ148RMrED7kh2pVy0vMzBuPBlZnQ3H2TYZddeHOymB160WrbVb+0kCHf" ..
	"JvoqFebEG90LWbFtACBAbrpqztZBbW140RAs7V/81OMcOzMHkqVxRjb8etPVXHEykdO4zb4V3o6InZ73DAPYjpucrna/yaN5Z5O9" ..
	"H3tedD6EimWBfxBqZARe/1zc0YK79DwjEbvKJ5RKlJTfzuYkTpdiUZPw71mxywEZYyZg9i6qVxlTmGW3wtBgh1xaULWeqgPB6UiT" ..
	"OKSVIEPwDvSX7rjswjCoQkGX0NICWXLs059k/rYf9dHvhwJORsK6lKzYMd7f1l9Ht2JcEYdE5EX/tEEGtT/uP33D49dwDMGIEwSW" ..
	"/uMB4d/UkMJo7JuJa3St9TkU/4afj9G5lJNzv342hSiO1DYxs5ceaJaETMApPK7RMUazNgkPeCrgKUlEODI4EZz8KIewEQDYDl3f" ..
	"a59lPAfT9s69SUac9JacndrYg91sZp+0820ofgIZUehlyMoLI5SJ4/s9CLFsE7EoBH5r0qytOdCvV9Y3PYYFGor6tUFiOHkdg12q" ..
	"zs4VjmRHeOnXMjKG/PJncRRfu0IGqAbejyMLnrCHKNwE07a/J8vPG2LMW163a+QcyXS2smb5AU6sU0xQsJIhZUT+J3tGBUZzjbW7" ..
	"FKLXcF1NALhPjHIi0U//q1rU+OMLwlbg2ho4J7K+4aqeC2HLrtM8mG2W4wvnsQXDb4y3hfehzc+l73cfSw+TmG9iPVFH9tACPBFy" ..
	"6f/h9y6k7SJsqbNs9TQBQScpP+eu265queG8itG7OrEfLtb+baEpj0wKPC42KxGzW5fyMbMTgnYaR9InrIwR9m2RWOB2BJs1uZ+y" ..
	"ZrZPRHkfnyQQnpzw9BhpzhLm81whxDAexoanS1/O+lICnQuoCr8QjxyP0/k5ksen4Wd/H1RE4qluPaez6wfVQJVZbGdVB3HoecLW" ..
	"jQE9aJ3z4Z5gpvd7hbPo694XwgkWxZNJ6Knp8qJ4TXW1johKaJ5D/sSmbesrHsXZk1XwlZIkfaR9zJFU73irZULPAona/0t8DsU4" ..
	""
local PAYLOAD_P5 =
	"WYHxea/6xXl6OfqChP0yfty90zca3g7NNcVPdYkF0ecJr6uipk8jXCBWlhjw8lNCO/DIYEL6Z/tkP/gzKxpX3Gan47nSIfmvF4QD" ..
	"vNKqZX/cK/oFIOM7gYsQh18KP8nGz4/x5WYmCEIXW0WmCFEQo0IPyFeQ1nyyO7uncb0toJ+l183qWMd7JRUGEC7wfx3Lnu+Ynbf+" ..
	"2SedH9c6G0eDh75lgECxdB761d+CWNc/LeB0T9/RS6eKw2hacdeA8clTQZF+dayH3edmPmuexxhlaZtrpPRDKDsnPb4Oz3t/ySuX" ..
	"8ax0DR1GYnb1h210G4ob2yRnVBYLW5ZVOekFND1JXamKUKZ/g0ccClI7X99fIGkput/NABbhI1+dFzl1yOubpP7OKl74e7JP92Gb" ..
	"MVN2EcKz9I1ugU7hb6FPerMZlRewCTKQUTw2zWbVgvNC6jz6gvvNTMLOQeD9mdAA2PcHH6DtmyvN+uhpYt4jH4sCRmdISYmK8t8k" ..
	"45nULDxtYaXJJwzup66Fir57MHl+Q3obsgXrgtcqnkQfCfJg+RhxuNTjb/GmIu3HhIasMmBwZEspvn0ZamAD6YmwV/R1zBhDgx2h" ..
	"T3p2qw0fAFUn+SO4MgFfIZvvZiJKRKrZq7u5eSLPDP/OMEzVOWKPu3B1wZFdpfFF4LWE/WC3Q5At6es1+bPB5d9yND8un4ls2L61" ..
	"qgFfqE1UEwORfN8PzUEVX9mb/pt9l4koH+z0c9X4rdA3H5at0Qbec2F3UV+OB02v9Jsx5iUO6aw/iq6JvJi6fGwl9XoKj+UTT9zl" ..
	"HIEQGlFLavA/d7y9gr8QylpNNrZ9LAJg7AmwOS2FPfN5tDUKKzNJdgxNyEbgf5sfH15tNhX/ZK8qHe1ZHb3nJDvhe/Pb8Ak2Rkuz" ..
	"rDEQ3x6F3QXcBO89sRKxR4VfaerIZetMLkuD5oeA8MdyBfR7gmET3UshRJZq77T9kJDLa42PRwI56XhXwOMLM6du7GcrXnENXbhi" ..
	"zEQyECeH/uHcmDzY45R2QnWNfWn31t/oPxPiW1KdSqXDvvYc700aUlKjxF164KvQjPFEzJ5f9552n0CfVcdPSfGkbWgORd87Fl/z" ..
	"MjIO1VMgyAWqQvhYtgBQsmEZMPhjk6EOFXn+7NoUEC+wVNk3Lvkz6bJJQeWkQ5Jj/koJVaxKerm4Qg4DBnb+q9XZX0xiRCPd1sV3" ..
	"kscLITAd/HyAHh2GB9aIy9Fnj803FHGB0XAmxx3FWBFtt9Wjn4LtF/Jf10l500/2VTVY7kpXbknYAEhcxzlLLv5XqDXYx8TpWuoe" ..
	"dZSBhIOLvTDHzmGEoFDiEPhUTByFVlf9b3D911pcOKEtrlmmTlI7ntQdiGylwREIAjc1guPRI3eoYaGXMhRchK47JazYRwoZwurV" ..
	"EWbgdvDN37fkio3jNn816OSIzPUneEKspdho+8aeYbgLWJ6Ysn9SReRy3nZbsikPMWKBXyqf8WqTUJ53RMG5HCtyYqri/5yvFdgS" ..
	"pZTWbDvaz/Bl3d83IyptOdTfIBxdV/zGvB/gsRn+YutX7vCKEJTwBxgeRh+7uUDE/0wRUB306aD3Jpt7wlJ8OcuI4lLv/vnZduGt" ..
	"/5Jzt/Y8+d/1I2cBQic45aMKvvugAy8BMxbEp6zPjWA4hjWY/YriZVf2WCHljetWCcZmkjO8yRrIkozXjEmuKArbJDaIYft5ZWs3" ..
	"WsSPaEo2r3s8DaiJTvRynpO3Zo951aFU+52qmY1dVVqYPseX97krLOanS2Y+eWxhYwy+FC0LJV4QmfeUvFM08ZX8Yen74uEMkdB0" ..
	"uHzGonYNhF+ATnPId7xjBAdxgQXdHIDV5awCe9LX72ls2WILOTmgkDpkjzcWgK4Nehm4nzdADHzt4nNsOgvfGWSJuWEJKrhLdMm+" ..
	"Tsr5q20Xc02rtQtnKAlRVEJXjV9G2gmgg9S/l8oyCefM/WVrg18gWDDrlu/55c6rGKIuH0rFDke531zjgNKdET45heJVEwxzXLTV" ..
	"MLD6nL4a9IWmHk/NHnofH4z5/Yi5FbYoUMeVwkZixP6zzibA2we4IG8zXmb02szdRuXMiVnStomx46ftN75aB1A161r4p8SHS+aC" ..
	"Jj6rSEKxoqjcuLITTD/k0kpRmOPNrctNmIn2vDIiz+pKBUQU0F1zqkSk3thS8YLelrbeKQWrq/TasiEUlVJ5CjW7UcL4RMlcAkiH" ..
	"OZoLimV4ywPpc6l8dp993OZmpwTWqlDEr9dqW0TOWnKSmOQ98C6L6UXv7XTwaw8+jfe2J3IlOuWSkdIKCFUp0NeGPRANTjCAfZ7F" ..
	"pmjFdN4b1PvW1Zak07wBUbjRE1RkNPb9VkMHIpnDy+sUG8/hmPiw/HvmCl9OHRmObWX4FrYl8NFagpTZQNHlV6W+PEzrfL2IOnRN" ..
	"fseQi4scA7aRwOO0xLliwoJl18Gq4+8nwXslr8GeeMruxj15nwbwQAYIC1rNTC3lJXwAxSMVXiyMMkfuRqIWM3eGg7l0HrQBjC1P" ..
	"D2pkDmFras6Fnb+mCQTvjoimVRVb+S+wEn7RIFsaYHDZrjVp/Gdnc/0ABk4RK3ju2sP/hEGfTbPK/zQO9Xttq1NZCqfEct3HhfBH" ..
	"BIvGfsKVOkXWyeg4w1V9VBUn5bEUUWwzdMaZDTf5uRSAALPAtF6wITauprUQQi01o0H6yHVaEiLlXotEFWmbualJLmTNVI7Itf/P" ..
	"LsJuCUEGnBmun2dTCeWIS4VJMlMJsKPBF6sLUkA8hTUZStTxO05bKiO1WY//uIK/fPmmIWNp0Lb4f13NM3gv4q7zSxvfIIisCu6w" ..
	"7Q7MAQQtEhQEV76oRYfkZ8rU+JEMytD6KvuOtCBK5fBJfqYQ4Z7MWbLASGwVdLuPmQLcx+WGisC/B7McFrj2ow1ogVYMFV9eWtgw" ..
	"hHKLw48Yex2rzGBizPN6nOZmAWEo1bV9wh7P0T/LmNBc0zwJyPPDEa6TY1IAzol4/PmhMe5z0+759ZdrXnCSr1GhLMTJ6X2LG7sE" ..
	"fr+zLt7wABoAAbk3OMCRIoplT+NK2uNUldv+W/Nttt/YCp+3Wel6Q5g+QlSwXwBUVw9sWN9NizCkzoeH2XJZK1oOV/vkLAkOcgxT" ..
	"Jb6ciIha7hnLwa7drNg+Izr3rxCJVMsEA/tdKMYdu/CF/AORDUBBDp9r9ktyvQ0wDQxzHqhFs7NTg2WB14F2Jg8nOXayeH+onHn7" ..
	"OzgVTmuHW6X0NeksDDIr8DeV9+gV/HIeRYIyZPpe7AapdGu/ydSEZlA/+sgSfqYLng5XX9cKir1OOCRXecTXZ1VGsEBCMMx+dNpC" ..
	"BCbTptxQ3JkIvtZZBheIMQbVMdT9BmBK1wHUjTg6nhMkKD7+VobIadURLyT48aOb67yuoFB87iJbgt0TkhEwobQf63Pw5AxqMOEN" ..
	"yaHedcduDMKyIxeoJa/U9qdge1KeHOwT5pr+RWE3Y5qkZirbv1RExDSuN23kAFxZ4417WQLiAIm7IHvkpWOnUlFMlfbx8o7IlNEd" ..
	"0f+9GXEdPl4E6udqFEvvJ0B8adPNvydEMOdoJHVOSxdyf3fuQmAwvStjfN9cG2sd2/cW46ZEzyBPv+YdOjQooFnGQ0jmvIB2FxSo" ..
	"tORv7Sb3ZIDqH+ojgskaGD//SPQx1Viv7P4+hwvRrBcOioFKvpRPCWy+7UwfBUTiJ/TpWRwpEtTyi0h06kaozVUSi5F9IQj6PoUt" ..
	"ppZPhJ2+qkN5MjbbXTSiaIXE7Eh9XQuZ9A4sHVLrzYbcqwn+NYmTfROokz9XSZAkAv+zo8anB64Vwh+0juA/l9EC6/czb6wKRa0F" ..
	"vGBL03tvlAh14zCcwfOgxD4y2ecuKAxU+E9XICjwehfB6RfbHXBoHDmbypL1LpAVBwO9XPk2dYYGK0LpqgZUUaHrLsdtGoXcxXF4" ..
	"XcsIiW3+Ud6sZN7vwpHKnkPfziG5Q8WBqbeNe7WuF5L8uAxLssehmJyiDufCSWYUanJZW2zBpaTxLCVV6UKg4gRr43mno5W+aJh7" ..
	"U3+MctsZS6oNzGv5Xwskzznx3EGPhJj7Ex8QbqJwA50jGfanjGQQcGiWJa3WMnq+/2LkqX9+OA+YOKuG12YmGRhZLrMOa8fUwqel" ..
	"iHzmcMk7tVXvTM9rm96x7/ZE/YFKHcVuN/Ajf+r9OZswG5O6/Vd9unFAmF9gQRK3ijMOGCU1fnEF0FMN1XNrS6p2buTKyCxWXDty" ..
	"66gU9jG5KQtKFDAaNnVYyz386pTBY8NVabJHNqxCGrlmKDf6Yfnx6BH8KOxiUUkW4dKHC0wQwdCvLK/6A6zgeAogS6xWE/wTCmDD" ..
	"gtGEKw/kD/RtpLFrkp6vG2tYCdkURuoql76im6n6nyfyK7gkrS5u2yw2iuaD7VEZpRaqTYsYpOick/QiHta7C8B4YyY7nzym7jBS" ..
	"0AhRCxWSAsU2C8vEJX89Gp3FBQxYjtL52p2NNhlRyZ67qEbCOYX6rNUQRvhe9Y5SUEaEKURQXCS8ps6nUJUnGGyyWvAjTuZrZO4r" ..
	"AbPNNlLl+zau2VzMdwvhsTmPZceF8MOLJwSdt3zGQwg3ftQiLDOBfDlwgpcjBPYLKN5Fh+UbvaPpcfXhwKZye75xit7weE/HAgJm" ..
	"gGEBaChDzkWLVA3mWNyAEDFy3qOfzs+mT4rkUbVmGI44oB4XL5HdnLBhaasc+Cptcw/7yV/n27hnEIhvT5EUtSLfJm+yTxgFt8cN" ..
	"98cYjrEyeOSWacG83JhS7R83M+tl8WyK3H4YMJSwdGM4SkRViPJ8gsalbMMUmfKppW77h1CwLF9Yd1eHeHUJxL4JKuq3nWE4MB+5" ..
	"jRIsIsiHjMLugejcBsiYlPPS+7zJmnneN+gfmyc9Ztga/FaYV56E4GjLKOGbqJPKUTXkfldcvWfP/eqDxa2y2MT9VDSu3sQ53cTS" ..
	"a68kZqeTDHexe4QpWYy0a1u30C6vASRtRWgNRddI/H4bZcOTJIiHAkz/+FczC7jGEqNvMXr/RxY9qEVIjJPcgTiSgy3U8hWJqJhA" ..
	"e73gLvi73w06Zh6k+wPqhYSRwiVJofpSusuSXgHh/rsJIW9TMdaEdVR/LbSSuZ7GE79ojRvlGKEzchwdadNnIVTckgwg2IALS7Ef" ..
	"0GV4zJuxi62e7+2tOn6OZZjYDJ+QgBBcC8bXNWdcLrMfGM+fvq/3mIEc4G/qsZVprgOeSRPCTPrnkW5AGwEKs22H/Ucw/Q04YJGy" ..
	"TLQcmWoXaQw7nIIEqNEllpsNfvw0UWNNdQ5XhQENSXjMz0zruZbUgYGcCMs9s7r59Ohe6V+CC04unCIFrv79wA9mV21iBKdmBr3H" ..
	"2jTOJ3SGOxEGYB1qTJPB1VaSoywPTvrKad8OKLnx7Qb+DvagYm7QvJcfXt/xF2Zdc14nM7Tj2Nn/b0CoONC2CNmgSzZXRuFA4WBr" ..
	"n0VdF8s3fHUUl7nGQ/UkEca1sJQ43fWrecsJX+mHFvlYKcxpyZ67agac9nl7cbYRmIlS0qv59RCsg3af8LBz0JJB5GLW6Er6wofN" ..
	"y6Wv1FSyX1QPx6BydNkWwlMLqI3/ka0iqp0CkDRF2QrBLfOfS1MEE8gFBQWY/ET90cayW1KGG8JHrlHX+BSvu3u08BSvCS4RPAAY" ..
	"nku6a9iDghD4ezz3tSt4OO1pXbuipADicKha9mcbspUbmxlWAM1bsrPcfz8lg+ygHqmJwauyg14ZoO9LyofyuQ/dR4LDeR7zDmVb" ..
	"Lr97aWrA0z99V7OIOnpFmPCbjdO4GlB57c0MDS2w1aNMK2dkuXq1TwRjJzxLvlQRppXCvQTHxCdJSIdHYdxnL8LHScv+bPiO5AYD" ..
	"fBylS2ghpRcwXXFNYibhtYR6Vg+GgQBFQK5KB5DNAqWBOTEWbMeVUlG5+gMGugxMPD7aZZZz4WJ3Do+CRttG6t0PYnUCXVRRbKNe" ..
	"zQ/8fCsSiYY4ecXWaLi041ZSPJsO6QT/fUw4uYxe144r9dliqe0LbVoWQAZj7ePjy2Cfk0NGVAybvvtsUn4K5b4eow+8CZA7flir" ..
	""
local PAYLOAD_P6 =
	"khSVQEkq9PfGjtY9UM5lEs2oQ8sv5fpnwIJ5zcv1hVlVKfnK/jysjdRP48YVzVfa6eIbNR2675HBpLEwfvufZBMPQCJhAtZavDRq" ..
	"CByLcIJ7fU/KUnIyPGSaYS4i2mSe1gFBMdImsW+8PT8PkA3HZM1t1anG/+vgavAXGQhgjcWXOOFEp2lBDydBYr02PJEuEpb5jTBj" ..
	"8lRBa9HWEc/FVDgb+GHcNJoCHv4ThM+ta4ON+ysqkoRoowJZVNRUgLdWWCfQFH23/CR9cmHV6BFjjkLg4NTdYkVbSreY6C1WoNsn" ..
	"LptS/UeZJ3BxMXxD8cgyTjEdI42O1Q1kuIFTaepbLGTBYoq39dbL1358pIgcCwHb423PXwnoPD7mcp2iDWR5j6EU3vb8T1TrzTIb" ..
	"xq2XsWu/DoxAyXyhbbpyCme0Rk+3QvJwNEsL1WZFhLfIROq2IZS+MOoTWNuY5eZpY8TKMMgbbw2hPhPQN6rwk+bxlF5o7txRgQFW" ..
	"piQqzvf5I2+83HYlCaB0yOhaUttSpTldqOUCunfhIuxHsLfql+J0mZ+VuaeUQJeTqaIh1M8MmCSHe2qN1KvjKnGuNuZqlVhT49i0" ..
	"RUhN6CF13avubcx27/x5otAs5CAnFAp3ZMFrdMQLOYI70NTXUDBgbCbOYLQ2DEJE0YETqjMksImQp0icU9FcPDF7/Ut90TNsgzW1" ..
	"9lQOahyi3c1+u0X/ilJi7y/J0LIE8iJxw7HVZDKmxDxe0VW5cvyVFZYotqyJ4+K/QIdHi7wZN61kuAfWbIVN+5I4jj8L4UOz/kw3" ..
	"ip034f+350pdZxVal/dTfwg9HTLWrzm6Vby6sbwWHljamN30iO/tr6MnS1gcmCOHpAWrrPf4mZBdsOII4hM+fsOEU+6MOKDuttOI" ..
	"CoBR3Gt2HetPwaNZXPr4Of13NPW9hUgdlAzWHIhnZSGGKr9E+hVaru/jmlOIgYQa1l1ApWI5QeuETlmgGaBs/TqJuJnja6fBpyM/" ..
	"fSQwn9jzFrqomBucH8k8v98QQC65TwLBMKS8buisa2UTTXarAlKJ9MJeqhHSb8e8REsuSzB56OmXgGP1NYZJkXcyF35tSwPY/HhB" ..
	"k+spJgbFrsSRe4HcbyF8yQs/RYG/cV0Gnt4GEY3Pe74zSWZqcC9dgA3XEFKMKaBcM6hLtqxxDWKSzIv+hT+bd5W9u9qzHqf9WdWS" ..
	"uQixxgiUWBm278zf7s/pK0hOOV7jBXiqenTTtyw2Cd0vmfBGM9kfliKVAYIdq/C4xiVIBWP7O+981JivdgiU9VS03QgkmFnQLviH" ..
	"1gQbHIJSaq8mQmDxjuZf8bv7/E7zQd8spE3pJIj84lVg+LwtptgkaYr46qYD0KuVEws6cTV/yDLnWVh+6ztAc66YvpgJR1BsduLR" ..
	"SY/6YF2iAl9Gtc3e1DIrPR1ffu9oGWuAFXLEae5lVB2pqaoffMRRBsuIDG+zs/Z/U1qPZUvoSLDboxSM/p4L71RKdt6BBK2SBlhw" ..
	"ZznOd6xkK11GU9OicwEmmArEyQiX4mWYJ2iDxoUnIK21HoCNuXaHiOydHzFS9WczCM+cM8kAt0Q0MlQYZ1XVPBAzFFe+yOzEU1yf" ..
	"b+mPx4aXvLcXP15r87wJto+kcXn9xeLRvI1rnAQjo7RywBLS3VwYwde4vNBXc7cxbgDik10b8TIzKTsK3CtWjCWlEdWLQSfHIuA4" ..
	"31iq1ZfxyDMJy9pqdrbHFNPB74gtrNyTvSM7CAeX9EMlJH6xp0zfHeLMbkTk5UiLD0YgZLB4EpRS7NR/2eKCubmcmq4Hju4FlgsT" ..
	"Ah0jMPHa5uTchsnBTGXOUmSWaPNUASu0OiJ9UK4oO138XDFXhEsfdZyp/4I9o1Hi2D01KrJUtqS3aYhvWguoVPO46GC/uV6H1Yoo" ..
	"Tl/WVTc0QWc+SWgZEG8rtYVMv8qbxPXJRozIEMsNjWiKJwIkzBpUo6C0WULzt90ItoftR/7O+OxrV/b5bkwLfrWiSiRooyeM6hyh" ..
	"Md155b+8arsWHDWByMo9v/RLrBh0aQTTfxkQ0XqtrTpCVEfKx0lGXBaTL6i8kK8+zS3TByswruxwTD3QmQW8b9kmjWcHMhC1/DQH" ..
	"Nkp8KrnIHQ1zBI6y7Z899k5aspx66SsQJ9ZoFbNVIfWxHUZ+DpftH1r8aWBwkq15/uioIMiiPQIiRP43UyghBTsiBeKf5+TeZLvJ" ..
	"Fzjx0L6rxGsBeYioPeXh/8bXTbT0DN/Ysm10SMxsnU4dVNAAZTXCjquf0XvHx5Ow0x7dBQ+vzG4s2UGU7JRYfSK+q+VEszRng0Fa" ..
	"sQUjFyiUldQJyGXgDVga964fc+Q/gquV3iL5wwyjIdZHHXPM4u2CxeDOPVK+L2cPW6P4Qr/xevTDP60pVlCTrUKrKDqcqcxbuEat" ..
	"BjIMpBEgskL3EvMYgZRytNmrZzgQmZwSjCJKr6E+H2NCZKGQ2JsXLWecqMV2ZVHbSJSZBXRfaqN7YDrXDHD0dbvbIXuuHUEOPVr/" ..
	"d6N4SoKASt/062/bssKJFvee9Muxyaddi7AFooRI3NiFaasqdk+FB09ySwQnYC/wTncmQoxCNuSdmZTWSsBL9YBXk0ARWB/WFdWK" ..
	"zhSgp3WXDI8cA/N96CEg2e8rEIAu4z9/VPYHEGJks032vtEHcM0/ahl0dwCEjgxu2FvhxRK5nVP1x2gwX4HgDg3FUlfv8pWs3h+g" ..
	"skP/YEadbePhcYVMugv89uJ0mk7SnYtzHPjRajAvEExMSkDv+XMoRL0+Ew0RtfNzPDjsZ4Roh1d93KPsI0Q2EGx83BT/4Qht9+/G" ..
	"89dTtiiuYAbD+qBJwh6+NwSgDVPXJQu8IFaH9WoVADOgUdlTuQ2GqWngvb/VtDjXnkqLifL0f/immsXii56tA4HtkL+NfjAS6ONB" ..
	"RD8lnBaI1NlnDuNTfO2SWyW3DbGhDek8vB2dyZBNdmWbwENX7tDku3O2vkQi7+tL2MGTFaCKf40psSIGxfj74WGTaaAj6E/isvKQ" ..
	"JaOR69qqTVGhLL01yOeiQ8TaXYrmjHnBre532nt8BrK+7LB7Sa+ud9kTeUvb/umjF8dIeef3A+hFV34t9QpzS9oOX5MwGFs+nl7t" ..
	"ifnVG2w3VOnPJk5C1tUyLk4QbZNVUcFVQLIt3Jt6H9hYj+UAr8dskeXoT718wtmyqfYUkKu6iSOKC0hLxMiei4ImFolM+nEs3v+Z" ..
	"V4qcJutAsSLHrmgJ6Ip2GH7pzBtvM42GxR9gp/3ziZpZhcOmYS1RZP8tFIm7xI1l+BQclNz92cQiBFG8hjPqn0uILE7TMdRlSO2c" ..
	"e5pitUXWQlhOsHz0wUiKyzEzlu9uQ+A4a1Aefj8St92oyLT6wP1YiHZsn1xz0mOFKVXMEATVuAI1aNXZ1/DRhvN4xP5BUXQRQUaq" ..
	"L1F0mxzzz6SMWQ8uYilB2eqcD+cl1wXftgdbBEPeFnFwY/bLJxNP5OGdAEVnnML+pDyFQA+CdqLBuGXR0QEhG93Q3HUEgIGLIAhg" ..
	"W5l9yqxZA5Z72G0wsB+kmX4boRxsk8oxVf23mYJUhv8jeHAFbyi//ZTEtKLNIqMI0XKnls8AdwKp///yc8dYF5vBGlpReCvhbDG/" ..
	"V+KJ611eMcoegexrmsybsWpnboSeEluPB9e+Qb6HuLjkFJ3LeHCU6OD6qD9kWNZdLeZsEllNG2E4Y9IAydjDBKdNC3JuVHT0SOgp" ..
	"BgfSBZuJnhtcSNK8qFM7llWHJne+8uT9mi2QW6yC8PPfrPi1Pr09qHzrAZdSxLzbjykSlySVlRmGOSozcQUoLCr3RP/aE84ZV+Kc" ..
	"mRVI11COgYM1p3mRGWzaQlOQpieNRTa9Bt3jtg8xZH7InHQyxt59HRPtJi/x66ySQWsJfwDj0dtUId1wKKpK6odhmcq8kIZt0N5W" ..
	"aDDa8s8N1tGjUXlU94G1TMFHhhpkZ8r3Lo5KJTrx0/TpIeyTADNJu3JT2d0uAsT19+dBnE0BosoYi7YLxuF0hJUD9gyAsHgXNsed" ..
	"YRk2uY2ICJVt/L78fwqO7BbcrGZB0eull2lW5Ec7KI9CBv5/uFX2st0KccNKESGUKiYQuyVGNnpessqflYlRi7LqGxqhCcK5XLFa" ..
	"yXdtu4Yb92XwgOdq54aEAW/zHqvz8SoDTBWJluecVhlNQtZzvDMP0bLolPLRxIxPIVbvFfHzoA8wNsXQE7rsrcIgPWpHs6JSPSL3" ..
	"j70Cpwkc+8d7gOa5utvGlAvavktS66YfWbuXZlQwJ7gVq1fuMfYlObla0/5aXzhxL/VyLDA0fT37xx0fHM78a9Y18/6dcG5CcYWh" ..
	"ea/fF9CH+030QP2PyVP1MbxxXVptfjaa1noXLEajSfAS0KG9O4YpSBX+3LdN/97sEKNF5IePsldaIQs5MCJflZLy6A73Ncra6UqE" ..
	"oQGtBGTmIaDC4UvylkqHf5bILB+vmhcMJlwKt6NELqdWffKUwEA3lvfmaPIeBEYkxO8gsnabju2iuVgRxmSYnWmP75uzBXakDNCw" ..
	"2I4JFuuvBZe6MsI8BfEvXegxsbKFh4vffpNKxTRfpA58eoTuhE1gpVB7vdIkqKRtQ4/t5IZFOL6Brivy/Ws2FJfOG01K8OlGIphp" ..
	"MFI6G5fgtvEVIP6aoxvE3JHb7Bw2sB+YHf3UtqprJMdSC66HbCdUw4RQe18aYDx/sn5M/8TEfkTe1JcRwVXbwP/AA1YTgea7Xg3E" ..
	"1xsl14gyxCCu2519jLwq21nZsbklZaobtaVp0Ok+pkToxGPzRURoBGCqv+w3cG1mpdsbPhTHgAx17R6Qohj4a36Ttb1ByulYkQwC" ..
	"x0M0YZlDxrezpnCTeicUb+ADNJlJfAf60uO5IUA9dMV76aSm+1STwnAt0G/QN6Dx1ohjmZPkCmV3wNfGVKaQIItjbOaauVMWEM7d" ..
	"3P4FpPt0H9V6KY6WwvzoG+LOrdeYEfE2NDLGu1jSgwtpNioYakVafR+da1Ydoo9lxzBPgh79RHTbSk22spZmdB7+w5lck6FvOuhg" ..
	"ejc2cz/JIGt1IfKNDFvJFH4SKY9UtR8oeoHX01MWEpmA+a+ZYCorKms6lqZIMhj7ibsxVNlXyZn0yrXfd9SFYj8i6WnnxsQm6Jj7" ..
	"vfLmZGGDzPcSE1R1pnX1WgmH4Jaj+R8YgTZtzgHKaj6bFAcS62SlTdUBNAL8nkk3rVZbJ8z0L0sac354f/Ta2bq/oIs34BZ3ZUTS" ..
	"DnCB6rwgP+PXWfUi7+Oi2qVp790ROAg91mHC3RhBZvw2PmY9CCvdHkblIxDvVh0rdIVEBIyzF99XbfWt9u8G34MUfiIG6Ld9T1gF" ..
	"0bhoFMEJ7kzMksRGwaqlx7KgAz7O52wBa9ZfTz1wD0MyE8rs8LxpXzt+95ImMmyvH8Ogakp3NewmSfuwQLlY6oyEe3gdN3Eb23Yj" ..
	"OMAXglIvhDM4nUYDmVs1gWsvJE/vNQYhcMcAIo6wU9Ql46djtmuCN813Ho8QQ3P8uSDx78Xr9lDI/q8MsRTTSmAhboux3M3G6Qxf" ..
	"OUNW7EDwg6Q6r9lXxS55W6GPKF3CPIsTCx4Vy9Rsei5z8SVpEs89+xDeNvy6EP7BG3pWKkvVYGeWCf8l3zXeUQh7b0gRrILZl2v7" ..
	"JWclf1JluVuB2Fu6Iv7xI7YwRjyAVqWkB5py5uPrJE8Ms1IQDBOXHQGJzuWn12BsNB61PxBb86iCwkk/Cp+YZPQouzCbv9xqLBnA" ..
	"haWnMUoZcwHvSxqTbrQfeRq9Mt2xjv9I2TuGtGlssWv6hlWRjUmEUf4gVHxh0Sychzac8ZmRnK7Sa01Inea7MeAAh8kDrnoq9L1N" ..
	"mLzA8hYKyvvO3uxmLy4FGle/yxp8I2bSwkzj/qbCTK/SWRwadJOIittxMGZ3BrGwfMCI2QMRxn2Hfe/SoXOukPaFIHdJLNZXhvgj" ..
	"LpRZ95wO7T//WM7r7RFKlgBH9JXUAPoMLWLxEqyLCxPbs8bK4umr8NDzVQZXd9nKLehvh2B4tjExPNqne0jUns/C3nKlmjQxRc1A" ..
	""
local PAYLOAD_P7 =
	"8HZ0kS2iya//BjNcESJe/zppqkrhM03m8byEsjxJHTGhMuOvYD9x/oJGrk9199myiZQifELPj0Av+4Zdv5+ouMp0bluMXlBEId+w" ..
	"O2Zw2G0hrk6l8PIcIvJwaEtf8nm9xQY/nNd2xS76tZf8IIF6Ts8i0Ew12niPXdAwhhRCeq3QR7f6rJH5kF1tyQjcn4+q7zo7K8ST" ..
	"iQiRA3MdslgOUAb8+AIg8ynu/OEZIZjqzPiVAgILBSk+fAJHBeKtQtn+4XbNZZZ6kdZEj9cz5pnK8avsg8lglin/nPpzzlvjX/7K" ..
	"6zb9vfZVjnTlcfxLIK5uusLZdKFiD227q/JHsICA70OqfU1GoW4zT6+Ssn8sdU4vNkkF0u1D1RIowtILdIfmg3sMY/y0tp2Csx0/" ..
	"OFZRKiCWCfakaW42Ld4MuGZ6pEsZ00qk4W1pt16WOjShR61a7e3zwltAnTyvZRnzryB8t/0+FdeNDpEWzL9FS59LkiTUf9iYc3Fs" ..
	"h04uLWOmJLcaHp1ukxTJpjIwtmANMm+bzNVym8F0KJJrG91qp9d+qKozJrR3UII/7MRZvzcWuzTlhowZx1CQjs8E3sfpb8Pe227N" ..
	"ZlmWdhATYDpWeafHAG+dlpMVKyPHgn4LmC+PsJ7jHgwV8/iOk6gfPPoDdZ22IrtNCeEKI6KusaRhoij0eETfoTs0Wdju8jIameRp" ..
	"H7s08S+kHFI5oP9d+dmLiQvncShuft2Z85b05DtbnnUPGYTmer/7TcvNoChJ70y1D6HkvMWK5kRIvXPkZK006WDiz6v2hXWkNZc2" ..
	"3hTcQK4gM63qtiSuPIgbgTue2A1Kw6udGSvuTHVCp3MO3dMsZVcN6+hb+2PKooDPd2O/YRqtLGEz7g9CkzUgcXAX4v6mGx7nENyw" ..
	"Q/CyTOkj0A+CRjafz8VKgEg9I/e3GMeHxuSSpYkNdtVJpsfQ1Xykv4tXSAzfaOUf762tsschAXm/yspqycSBf3pkSgqeNiIRk1Li" ..
	"/o3yQnQrscqueD+462UnvBT44/+u+E0k/OCG3i/hDGtU//ZVwB62bkEnkkHaN0aJZfAeasiLAVW0FrZyN4diPp6TDXfsfN6+1lc4" ..
	"e21hv71urp+4WBXUvDyi59oLVJ0uh7VCU3pkfF5W9etiKyfEsG4rDNx1qDIrjgOvbrYFIhZsiEoD706P9i1i/zpByfV7AGhPMsUU" ..
	"1A3e1iCYf6aHA2cfsBOlosj4GWP8xg14kpymgeYSjSqBr+42l7RmZ3oqIgIc+Jw198eHrGMAFm4xDdidA0D07KRqYntRMl1tYFuE" ..
	"1jY0xi+DCI6wgeCUzrUfNUJwEGoqQ76HJZ74Clr1qi0inimrgh5f10WPR6GSNzyTWGIuFaeD7o9TGyvbOfWezC0Ks65OHRFjGwJ+" ..
	"z3CsbTXRST7xMTXLouk27pt6ZCNpx+FBP40pRldlcErvADPaDXBI7IrDQsmjmTMpUVy1zQSJhoqKaJmpXgv8Y82TCCrlJHuA0PYT" ..
	"ZW2SjkgWq016QtyrPTw3PXkDBDTEEDkoa0LD6mTneG2HyQ81qrfv3CHqua6lqBlK1+DprYs5CCU0thgeF44mvvzttKYiuwVxuKtT" ..
	"iAlnJzFg4nJQnU097M4Kxh3BPcChnTNOFAr+kbBXz5dlmYVGpyFwyZMfXXbaLMrBm6fUnUMGC3toj380+8RVstPavstiikF4VJPF" ..
	"rK38lRP6Y0/XaIlM3FhU3PdJTkJJuelZj9gmu7I5VW2zC8KSzxpR0O0sW5tRpGmqFUI3Xi9aapFZT1ZHk9N2DGl5FQChFy2RcH4h" ..
	"pcEw5vOVfEv+FUAwUJMDOvSUH0uq0DKEMeNqT5XXai5wN3GaiStugW/SJsoiYat2ekT2bNngnBm8STCkofuT4s7nXsnetYfeUdR3" ..
	"y1wD7jPNPKJ+Ue8Xe2xWQDdBjGiWDoPJMgvWiP6qXymomIIwm7+Hj2+TFuJnWzVwiRunUqlkb6U7GKuelnBn7g+GDJYiZ14IX5LU" ..
	"WxYIxOZkH03EYVdKoIlp4hRg3HEwbvtYHDYNoa7UM51cOiO+UlbOepLGQzBaer5tF0/bgvIGhvT23izmhxtzDhsd2+IjLbvF4CLc" ..
	"jzWQUPl4VyfxbkRhzmn+lD1efHDbs3uxOeWbtD022C3j8skjcthPfyjV1cKx9HYljJFUW/bkI9S0dXr77iHD0o2B+e6ZvAwFZAqs" ..
	"66RoFFEHXPzaagE8bn3ieuq0PuB9gSCHhbtXmufUXCnskVp35q729wLf4aXIhx9n71VUHP/EpO+gPvoYa6b3V6/ZXrPiks+XTH2S" ..
	"eLDrEju5hyyarbCE8lwz0S2KdxlPBWrps916QbCvxDNm3Nn5XO0OglGDeQNJTBKlevLqaRpbblfLhNrX1uD+vk1xCL20Gbg0Da7s" ..
	"7mhWLj6ZLVxBiqRPjH0uK8MY6KOhMxGS/0Sg1LTP+1LgmQNngVNLiLL7CyAXCwI+LzzHHW5/5cSCak5DvQ4lLcdow+nZhVpyFv0g" ..
	"O2I5uKOHEExRZdfuInUOo9trbbCSxTZlLcFiZ6xL7whMIY/7oNhqGyWRPZ44CWYnlEKdQazHwuzrr7TQ9E0HGRr/pxSFZ9wUB9vJ" ..
	"xN3D/pxnhzBsw1EDUWiRhqlFdr9cOlJ0WkfQ7lPu/zBtfd0GCKYw6wJvgKN+WMFLeNXSYpRfPmA55rDFDso942l+CIndEQZ3NFHQ" ..
	"+uhbn4FPwHgsLhJIJ959BRXt9RH4401WEaCr5X9xJdxzFt+MoNMZ5Uur+8PTMU0hKaIJxrrrjrHtsuyejSrfr9MLDbME5gJPwuBW" ..
	"wpe+DuZQl5O6XS+Hqzx8s94QUa/vMjY3ocs6sUhu3V+TQRHwWeC9kJ1XG+1Cba+y11i2cjB5bff0tVcRhZ6Jl953WFlFQsrkKLWq" ..
	"1JJNLKRsYo8nIbJnJlBgtjxtJr0VAYVFFbQjiv/XvCm9Fybp7avauaqumbk2JnJPHOnvR8aojSJnvuIbwSOO7dJKKNlJEalFONXs" ..
	"/Vrs+WitFQGw5ENLzFJYuaFJ3jo8NxbNMTV+jz+Gtq0u41rOGgRIPn2ruN/TOt+2nvZX8+GmXykqkA0LaGdTXMi3dWVv+N/ti252" ..
	"njScVA5Papu7gxoJ5JSTUyeFqRVE+vOQJFyynua1r4gWbyuIoD/54ZpurloLKCO4ja1w6xi0j51ReS+IrWSO65nO/e1T0foWSeHn" ..
	"zXzh8ukmGRg1iZn13Mdnrt5G67j/wzgM3SoQHBRzdSfsyCiDrwikBicoCaW6DTSMJVXqZNkjXX6XR8piPBN8O7B1cKasfB5+6zPq" ..
	"b2+K7PAmFuxQHUj5yqoNl4ZyXU8+HX/fwe2QwaZFJ+W6q2Z1oPXedLlKGx4xW8OAbbDVtGIQzZjsd57/yJK16dnm+dd8tiKHpr+y" ..
	"lGuLyUWWIRTzXujidiBfGbga2NeuldS1BNSXLRnhfOmXpepIDthZ6jgIH4vueJiSJyeoFikFlxT3u7HfPSjX+n11/85DvQ+X6LwG" ..
	"Uoeu/kaMPQgZYv8C08MGSzqzV9VqOn3jovqi4PArbk9m3hpA7FdwUFG9fFQgwozyvFRFqULW52Eg+r8I/KTQbcRkANchmlbPEC1j" ..
	"UOMry3Z7GXfL6RFQQuxEnUi2LExFa4FIHwxENQ6J1IveuIs9WtrrVTAZ4fJhLBhLZQlXXRC+jIHkoPjHM7nneglO36WGCH3OpVVS" ..
	"xT/QhPhKgbOHcriBaqu7t6s4liIgPkiNQXW5Mn15L8OC3MzMyxDgrOEfke1b51fP1pn4usyNijpMIh2NAmJDyNbyZeP27jb//bH6" ..
	"YbOoXUj7HGZpFKCfgmTp03kgpREHIrefJ58nt/0WPaptsMoy175Laj0orxLVfZncVngHPrDNS8Ykz3d0JeRuGtaAFNxW/I/B6VtP" ..
	"gBcGyd4bx8gOQ0XlsZpYL2YNcni4/eX07yB+rjgUChQjFMjxadHmQpvgbWG8am48a7LgZLcvJlIgpkqzrP/pu+oaTARk1t7BVycM" ..
	"TPSyt5QTpA7ToBJes6szqo9dCYz9h0JRxVDoVPSsdIwfYH4XyzTdeX4nQNLde13sml2tTh+mBRRt7RAwD77V/hhK9bYHc7apSg7l" ..
	"/XTwHBQTe3Qysk8SEmSokgcfDY6GALnPfZ9IUgt3TVF3OI8JR148BzLrH1ZO+Ah5p0JK6PPHNEQDsFurh5yoHSVNrc5WxD9rXPCe" ..
	"zQAc2c8bjtWTHgCFxEza2b4axKivVIBfUkUZxTESRZv18QzTVbHBESayLhVZcHcpU535BoRwdD3uzPWNeGkVzWGiaCju7kkoUthn" ..
	"7MHem5fiwxN0YtjwKUUSy8yGSSsbop2y1G6q0MxVy6yRIZFnKFX1nkDLoOxO668y4M7dRPra4EwJtgl7BDwg51Gw7yge4E0rfBoe" ..
	"8y7ApeuOFtlSk44sJdhBedCFgVrt9jiVV0m00zxqAXUAOTnpAyjxBtUsiJcFECagy9RqpMK2Y8MoBEtBYo1SRoLvPBWixhSy/ExJ" ..
	"WyolAWTs3Y0SGxInWjGPBAcU6vRe3aG0aPfFYb9AsS+0/QB4Q4TBZkvRWb9uPow0i+CzChZrqHWX89oRNAhinFInQ7cTkWTA41xr" ..
	"/vtO1W1vi6NYgfgHQmPuXSlxCiCx6h7gZMPmCeh1lTI8vZ77Ddgw47nKYp9Ba+SbT7A/9zFwA8HVRqUiiqeIjeMXd+XvmiZ0/HxG" ..
	"McfOjKCZWJym+BHSM1OSaDE/viPcFwTI7GNNA0f+2IJXafFWC2PIIlt6Pe8EpFEus0g0kaAwfF1V6QI6Q7fykR8KN/B0BhyCod3D" ..
	"vK8wezYOl58difV/g4x1Y5QexKbzt3ZjVQjNlKKRUyhbmT1M1Abnz+I9f2yrHAvPmuZQvXYuTQh6a/5+sKaKGbZDxlU5VUZ+7A4R" ..
	"cnfyXKqd0gijP5B1spAYbVvBH4EpaPnnDLrq2MNueL2YL3dTsESsLLF5/i84aJ9QldizpeZN9GC8vkNOPmB4lR5rCZcf2PYPuyxe" ..
	"Kh/pFFAaysa6iL1+nLwe2v2bYmwqPFx40zE8pBMwDl5IBT1dteOml7QxcuVXWDDmrSluqW+swkdI2I92UhOWMwFiF1/CEt4wM8cb" ..
	"AfjXCEqIm0oRyK6j/d/NFvO0cCQ+9wsXIPq9DgZGptv6XKIWBM26iivr8rBPo09AZcI84Ug6LRfqi6aiSpqznOPjVrnbEb0xzwlF" ..
	"H5fMw+NQqqgntWi6/AcDacB1ZNnRhorM6o0QJ+AvntHyt2lepKynyW++sP0W6XMODwyQec7L5fqkfVKfoKLOoHKenMgpPCGZtn+V" ..
	"DqomUrxsOl6GLP0akQ8ILsEdCaei2FiSaz5Ui4jfFPa7Bz5BipupbpESypUguEB/H0KIAzDkqxk693izVmfgMzpjctv9diNmC80X" ..
	"jz5gPqU6hElZPbkJFU1zxZNrN5GDmPPHhkYP4KJr7e3Bqo6KqjLxbgTsJFtF8NLzB/sTjldBDa9YIzVX4mQK2a2XTgRFoe1aaRLg" ..
	"K8IDfIyoDTmqTURwaBbF+tqqQC08Isket7VdJ588SzisRgHtGcyjtlC+ZBWigRki94Jf6Z94qZ0cFrkDlfwZJBrQYdI8dMoycqkU" ..
	"wyDsH+hqr5VkLqsl745+SDrbnVugMy5sk4+DulUUixC/ROfSUVOGGXTeriR0tj+nRyEI0VIjXm9RCwjnJY0OTonmbmSnNQb6GCNy" ..
	"clDOpZ3S/5lX8sYu2G9gAMyDvf9rqSAitLu/Elt4JO/zhGFbK8UlOHBEJr8t043AGR28Dm+q75U80qwKYfBvocCucrh46nIkjip1" ..
	"oPKh+vn5zaM5zN79qRTE2SkLVAOgJE+g8Lkx5cyxKJj6XAozplu/dnh36PQtcM65ZTWghOweEkeKqVEkufx5GjN7h2bJVN1pb4Bv" ..
	"1VK6sBIWo+oIrEgbW5NcuGQuLXfbRRgMtzKBB5qcVwLYtX9YXfP+5Lgao8MMTZ3nFBN/edt9fdhu3DEiTMRNd82qBUHwcZha9oaL" ..
	""
local PAYLOAD_P8 =
	"j95TB9fAFU/u1e3o7l3fLYowQ+mKQJgHP5QJDZDu10ANYQX4w+Ff6OIkjg0AA48Bem0YrwGo0kEjpVUVy1unEcvCm4di6/gRw887" ..
	"kmzzTkvsktZ+niW/i4f+dCbw3/yIoVmu9ooQ7HTLWClw7qJ2qxM9SnMil8iydKlJkcJ2GJgUK+4lMVDCuHVFNrGsWCoHqNwIOn57" ..
	"0CAJRYsImY21/WImNSZtVR3eG8RvCi/ZXUIkRP66w264FnOfsBR1nD5WHRJ0quvX6v8fW+t7tq/O7r6XRhv6vffZmjYBo+wHzkwM" ..
	"k1se9VYBe01jD3nLJdUz/5AfvskE0Qt3bnA/GkkjqjGJu1OvHWtdrk750o2qlbVgOA/RqIosNLozKst6easBnzhZVEXMA1qaO7YA" ..
	"kZ3pkm8hNab0tYrPheNAXvqh/2NrVnwCCXCaf+ImnPsCnIn6+S4spnOuylYsb+eavG2ghcATRgL+8fWZfcfIQPCtqpl4Mz1+7A99" ..
	"zyNnLbN6cg3yiXcdDKmopEf2xrdB1P8JR2HP+b7/SIONxdw29e4QSiz2yOHcG2EikKrdiFQcTR8t2UhoEKfVqnApPthXLAl/sCjT" ..
	"B4HwteHwxV7yhk6lJ0zv26PpDearNf1nflqF8MbqzVQ+XLnH4CVjYlinJVIT9I16Tu9eJNdjerCjUAJhYL3o2x2RVIt8rTIhav9C" ..
	"7PuAzeAhg0hSNO7zNIeN+Mm1n5+pnwdqkLjmqXUrIYCrF8N5f6F33rz8g7g1ENH0tRQXWscbkg75UpAQ2liaSfuXrkiexhZ78zfj" ..
	"MrULeOrlURei1h4QlNFSyd7A7t2MN42vAd6aAd/X/NfXLKplqRHTQ9dckzhQC7wDJURHnO91L/280QjWIcZM9Cq733XMPMXKOIcG" ..
	"zOG4czaZDu9oxjKPNZ9cz24WvKKlAQReEGn8hZVNfQbSMuqYnTcwOe6Dnkky/e0m0YyjSYIk1urcf0bbsYpmqDVqHhlFOlCsibjb" ..
	"s2hCpFW3iQT4h44sGPNyOp1c+wGLCWOH727VacfUJ577ahIrgbLplP/JPzTKMBJfeMnjNFCgjjjidsCq38O3iQFnJeKYeyDioitM" ..
	"PjCjfXrpkF8piJpuShgAVU4+PQYl0xnbHNH5UDkrftS3ROPHPlrx2uu393tnx5cDOoE+5vaerAf+U48Fly9W7wUQvsBpVKeRBUPD" ..
	"6aElZmQaY3vhQ9keMwcMSGRoCaEZukx8t6x24WpCsufdEfFZ4rkwYObdtTH4A/9VbYahF23CP0ao+/QoyhreVTyNKEM20IrIWCCa" ..
	"hj/3lGMbOzZsWoyzZkdMPhU6jf61qpafQl8MQzu5IzzIBJtQBIetUoz1625EBvwp5MkYoM/GkDK/PSBTVMjbokhrD02VOBxN1U+0" ..
	"9TFeVbfo8S2Ohq04SVkcnyW3ixtOkBmJ0x9BPxmFFvgM8IBFZNH1XUcSfzGZOFvPZVaFZPVZRVGFGbkrV4KbWnR6mQPCw+z5soCx" ..
	"lP8chKTrnkQjUhUw8wfXFS/wmOzlR0raiKRfZ/wS6IydQGXpJ4MFz8+4UIWGqmOVf3c4FXTfh9D+FyfdKtHrLHlNXKSCcdysDCGj" ..
	"oc9MeXLCLxSpMViSFdVi0/eCGEkoWZl2Z5X/o9QsXV6BM/gTx5xKhdZnOEfeUq9uL2aNiak+MjxeT+pRH/ypeoRTZuHmwN0PHAW7" ..
	"nyqx4Zc/WhBDCr8VBchq1O1gfR7bv7M+hcaxEd+GORYoCMSvu6t4e+zmcaW3WMGXrtUA0rIZmVBXUks9ewrY861OshPzTI+DSP+O" ..
	"5YCAWWvoorBJWKPNPXvWyK1wh9pAJyt4VHRAdfCihYzqfAe/4/2JQdWxvW7WqWkNBnNbHBj8kytDsSXqGUUsCl26teALxvGWRxOm" ..
	"4kPr5Sl/T0dL1EncfBaKR8AuPkRVlLULqjQLOcIvzf0jhdSluFRjnuwzoCQPJBbyRx3xJFKLsR7PvulYZYPr+YDCJOX+MYtEhUtO" ..
	"UX/H3+S4MvOElxIQWrXduGYQ9513l20hAAkZUILWCERc9EULy/AlWFbFoBRIYmTVs2w5+4ARri/PsCIJ9t1ROySDFDIyVEP9U+ik" ..
	"DWddOAtVKZjCRqS+vOyLs+EmPJsMIppQTRBRPLrqFNSgtTHGTzR9yayXlwE17aIL7OlcqytFQkdgfUb8REeBoA9lUEeW0BOkfMGi" ..
	"hcT/6M6PK6E3ESDVNLNv+eMF3gd6v3JdlWxrNlPSAOw4yqqlEuYcsMcrVEE4ZO5M/Oo3dsnTvkaH5KO6rtaRlnk9thIt3WDzjids" ..
	"UUAHA5SQ/EdQ+YM0lZbIjK8oXO8mT4Hvqh59Ffwjccyx1kD70E2v5yLIRrgS7pxMKXY3/5jx46DmvgqoefozagHiFbZbIyruYGcn" ..
	"nd55wIBnGTmAmBftYdLyuYrFQg+YMRQKjmULh44E9VwJSLX84i6NI3oB6tYC+qokxG69vbvwf9wMrewblt3ynoncfel15/7h6Us8" ..
	"9gKckXev0v9veAJF0UCGjDOSDBpl5EnnPGACMiD0acQuwQDrL/WiEmr6dazwVTeuJktSyYsGKLyD57QI6m3MZvx5EiACYmEWUsrJ" ..
	"0HoHcQh03FWl2q57n4b5Q0zRp2yaThOV/TAE7WNg8A8e8aEcO9U36dr2esxEM0VaL1VqJsgf+K5MH/b0R1yUdD7EgCkLsfm5QhBN" ..
	"u4F+gVRC/XWPE8XZQokH+x2S7kGaDs0+4FKAuA9hRKsGKrZW6ahqvL3qDJ0Tz8gSwBQ4y4DsNiGX0F9qRPetZJOiqHlX2AwGPAFa" ..
	"Vs0fSvRQ1AyUFQ/qJlrC968UY4eIJXxgj8nHwg+wY5jF2/1MR4be0D2SiuciIt02dzeE9DWycYKAkPOjgsOOrdhXl5G6VPKA9JC5" ..
	"FTcK5IRpOreXHET5vNln8VAXkF/gxM5C3KhWlQIs4fX7vFTRloBCkyGPGKgQk5QbVtcqjBwDLrVb0MfIw9d9tACQHCBszQv5yIrQ" ..
	"IYJ7d8E9jaeV3gpqqxS7XiWgmtsioSziQWeEtnmZLAziKbu2Ugjpgzh/qR1t+Eu7gGsoRcVir0+wU0P+FOV5Hnsyq0V5VVm/DaVd" ..
	"zaq0f0xqERz+EVnO9XnrQWd8sGAmerbO0wKQRdLJU1TP5I4Q/MNYRtUMxoJ1v4V6lnwZSZ3Rov3SUQs8RkPvNhYIJ7q0kDOnfrMn" ..
	"uBavB/gSLcLjxVVOBRyfkxUUFL3OieWnf4gYE0oF7HK2asWpY2mqEu1Nmnu9wwBIh+jqyopw9TKJb7tXsH3v0EADu+Ft9YAvopqr" ..
	"NM39uEmos8Q4DRDCOImmixJQ9TR8qxvaolsDiCaStp3ovRvczIQBuiSv4M0bP8GPR+tj5pkG1Z326xP24zCFrWKCOLq4fXU6dRib" ..
	"COAgkzboSlRWTreMoKb1vdVRPGTlGIhNR6R26Y8KVhTLBTRJWCjbf/+d7qL77UZQiDfdegW0U+EeXH9J4eZTRchStpWdJ2MjYcgl" ..
	"HthzfGxori6nX3zf0BlNaMKWPjZHN3TpFlmv3JeSZd5ab9Hs1cqrf/CZ1iHvRzIWG837cG2xtgZSj76bt2JZxK1cjYMbYx8x0KX3" ..
	"CpxMxinoHkw5yX1urumi22ewIH2JYsr/cghfEcEeljuZdyrL0PJLnJfvSJD13FeW4WGKjzAJXaIDvA9tXiD9bfzendhFzilekvFU" ..
	"Dftu7i3a4YIkhVrkHBDBCu3mU6T1TqwW2Km2LaTV4gJvBWg7F46N3uRxq13NcRLOiiB4l4DYP0ls0l412/dBlcG4ho1BZRPEN5HH" ..
	"WEERTZJJcGJfT/bJIVLdGCEGunuQCUreaXBZtmGnwyjEjbD9dXSR1G27BqI51wRMepiWIPxXlGnERb4wIhHLO0qT/+Eypz/s/oFG" ..
	"vhP8R/QHmm+3H51xS9vTlQANRzewyuBK/58F8gxyW184nrURstjHPIStC2qCyhNneDUfgHlsurZXiW8WvkoKRJDbu1IM8HdK4OyK" ..
	"y8Ka2LC7CN/sI7qfMi9vKDqITBbjiRPFrxCA4JczTehnu51Q6QF0AxjG7RTR3m+cEUUEbRWK3noUutptjzUZG66pmytG0NUTLHmO" ..
	"UfRDCKfi3Epobul86TFlOei5gGTnmq/rbeJYdEWz2XGFoC71qflHfOIf4GHUYU3HLmw3leMHlMAjX/eFuDvMHGdQ5dT1GwpiL0rZ" ..
	"QBwXwd+lnZtyCbs8c3LbFQriLTU8nasopgLx8lb2a4trZ4VCWOlB/84aWJX7JHgV5nECEJRu9HziyK4ZQpQlGCZ7g2KjZ82JiB1u" ..
	"D72pE/2LVLD4d2BMewLcDylbKc6luAj5tqnTuZTRwdidSSKrOu5fTdT2+KEdJI660bCXVfKmgki3dOCISINXxkYQ+zT+UPJZz6mr" ..
	"58cO+SGVMSAawmP6LyacPfu4/fr0x58zDTm2awW4nF4PR8bdTY44o7Nhr1KqWeEjzNAAMNxcPD75jqhfImpH9aZjLC3UPVPDh57z" ..
	"Ia/qUaC4DrtKYRs0kCsl5IEpLo1Ntj1XP5HkZdZdggAuQwkTxpmfHf5hObU4XV1hJhBoF7N/uGx9T6Kb1rDv5M52yXDtE+0sCR/8" ..
	"75MufFa9sHWQxjp3XAc70LyQoRTV0sqHexB+YQ4I1HRQB0QemFsiNZ6/2dXIdH6nEKKs4Qlob0K7XKzOON/uM8JtYcn1Gaus9W10" ..
	"R7868MTDbw+kePWbsP8A3DWZmNQ5PCZceVQI4quhhCNr0WZ4mcSK9ckfFJgVbczIChS4PsB7euquLw7ligioreuQXVxvSyEpsJP4" ..
	"Fwgm5bu+xq2J6KGcnf9Tgoxz0D41uqcZLP2JwEZuKWPbyOBl1tTNDIylOSq0VNRd9Cvx4BQpm11k5DegFNq5Bnn/kyzBhWRBKaFS" ..
	"5F8ZZsVYtqw0fVuoVgiZ5viIkOmGciIzVwDDGZOvFjIkRLz946MhGJLaQQ2P3kHWlFItZX5W6fWII6MQa9fEEQ/4xFuk8qKj0awD" ..
	"0ZzTU9OTOESdZVTlPbB246A9HDywWV1Ra7QwTcstjbT0ROf1i1juXbLGq9DnAwU62G1WAm/ahO0ykDjJmLYq8DNMyB0eWVtRxNP1" ..
	"t9K3k/3NlrEfBsCCkuV6Q1rtdgjRSnkzFAkdR+pWmmCpDoxoqfBBBCgIxomMcBniujsW7mqagiHcO0F0wjp8b690lflXCcA/2Xwt" ..
	"WxofkcUmbtZh9wMbO7GdKwfoNKJYo+D9eqaYkh03lQZJRUk+LWMNXRORWJZW0L6jDMHkVBVfttwKKG39i/WaH5XOKY59ZJgFu0Fw" ..
	"G132qQgG73gcKYSW1zjW+icQ6+U9jampyITQuY5/RLQnGE2OdweQ9sjl9cxa3oQzarR3CBFNE2HHRf6JZ8zV4Act73PWXEXIf0gp" ..
	"TdSiX4ZzmV2Id1/sT5iKadkCYkFL7HFocj1XvkRvhTndu63w1A+/J4MrmuXCM8LFXsFH01kpUmJYedHaOKYJZUE+r4WrM7sWJQNf" ..
	"K3qMeC42WEMrvw2AERJoccIYzCGK9wseqdUfXpIYL0a//2P2x6oR+7lTmbV5l+Xq+WqrIkQa1Np6yroKNEjtNkVzulodigxPpJkP" ..
	"bQqX1jX371w0L3WKm7nhpgJ/mxvELuEb3fLbNiRXmuW9aAUfx1WZxTy9A9t/uHCw+JtLMfnYb3jUkmnXpYXNhtfb57i2ItIbjppq" ..
	"ydFXXiRantuvpVx00c40c5lH5EBm5E6ac9iNJx7sYDGTsBf0jJMCU87a/U2szJFSYHcwsnxVgTKAfzmJRWtQ6Dk0kfpStJJxaoOo" ..
	"3ptGBeP5gPxytMMcVmzvgHvJNYINt2BNwky/xpVkKeogWJ8Tz64IFaxQS3VS9X64FhM+DC4C8SlcFXScPBjpX/hIkJHa7nx6MTPO" ..
	"QM0TnNekFBWyzl7qYH7zsg/uBlbmLCYb5sY/L8xhyeUg6uc1mNwmttLFFmlTjIvjSRIfiX+Gd+G+n3sgN4qJj2s0Ihp58qeVeDaS" ..
	""
local PAYLOAD_P9 =
	"j5ZULSIfwM7e8B7eofAJL1n/P/GOXT5R8Q8Joi3/B+p4b4v6AqaRzVe4GJM6KV2T3D3a5LgdB+lafcK2qfG4DtK42+LgOTnWEaaa" ..
	"/OQSlSHspCjWChE1veUWpRgUeqsDGh4f5vdGIJDW3zy0gW2BPqNsUWHSN9hFho/z9HpcHjyxU+7J67VnomY6dD9FjgN7RJD1PKrE" ..
	"bHtsdTa63pwPelUp49vn2T05B/KCsev08hHHMGqjaV8ZR9sWaCNeWIzd67g9KZrODYOm33IUg11TgTFWdik80HmfOAa85hs4wa5P" ..
	"Ua8Rtd0mfz1wgIwVWfqT6AetyeHkhiOV/AcUlsca2X5Vu7hYcPs4h5wUJ2uV+y4SXV18somTa3Q+18dWfa+Q3pmvpJwUvqXaGKKL" ..
	"h3ffzsKa4RK3jNZEkgFVW/C4OdJA53N9TPIaWH6XPEUiVUXQnMll/WxVlZyQ5yE/zXVQugjnudWgT3u4ltYpb1VmEDtFC44WjOa6" ..
	"wQmQmd1XT+EFGjga00muawEieJ8r4PiqqtA2GXQ1sYp4Tt5byhDiw1zr948W7ASwE/F4AzHKy8satgOlLXc31cKGR7nFMSM0vnEt" ..
	"r6BZxDNkAocZOpqj+qkrZuFkt4wdCnPpry2yvHUSIwWWGmazAaiBdYWC38elW9nWg32XclEqiYdskoaUQmJzwzLUrmy/zK2DnV6g" ..
	"c3mJ931Pi5kjQmXr3OMJdS4LPM3cUa6sv82y5yu8ZlOjTSJrBygEo0uip0LSsxyCWf0is/UhVzFUxzxAEiN7LAXX6az6TDSNr9PP" ..
	"8zc7k9dIvPATfC1g62s46Eb09mk8fb1lfixV1vN/F5uQQwV3hAjMxgZ84StVgrAtTvdAbcG113cjFGSTLuXkX/UeQtUPujOWLntt" ..
	"PiPyX31K+yyE7+W78awf+KWJoM2rb8gGAZTU5cyIBevOPPmUMMJuqoOdsSfQizrDNRaASgV8vXFB6Nrq3Y5xnxNGJl0RGk+qgIcg" ..
	"Y3LPFJM/P4c14zEG4932qQ3FhhKJZgqq6c3EFX8/XKNSLEKfETuH0vZD0MB3OIDMrzz1T0m8kIzKxWQNidoAxriuVW66EnLn/FyH" ..
	"Om23yJpeVTtw6LTHwb/2Ub9Jlzr6gvLokBf++QszayuQH/oMDIUlL1/Y2d0mlP7Jrw3GB4YxjSiW85TaIMBqVFpLto0wFkTsY/B3" ..
	"nUIjg5HJ86HtuWYI9WPMCuwMc3UEvG/UCXVg9wuJwmbq/Dje3/zZBrKcGceVDTepJDqmyCtc7bo+lq4F94tlIDP4rnw=" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9

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
