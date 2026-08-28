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
	-- LƯU Ý: BOOT string luôn fetch /main/ (không phải URL pin commit) để mỗi
	-- lần teleport đều nhận BẢN MỚI NHẤT. Nếu pin commit-hash thì chuỗi teleport
	-- chỉ tải bản cũ hơn 2 bước -> fix mới chẳng bao giờ được nạp khi teleport.
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
	{ seed = 3810783681, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 3814429143, exp = 0, plan = 0, hwid = {} }
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
	"vhnaLHRi8Is+0STWrlDoylc3Mw5GjFo3d2rapUg5QvW9bLPT4pTzX/qWuNvvt2YejS/2PSwW+0lZ6ByIWz76LFQ1sbU9NTmpW3X7" ..
	"1j3YI8hwJnL6z7BvXNU+czL+rI2yVTvxNr5CGJky7/wbaiejqGfs28naQlPRnfhkGcfFqWmwcPU25oiWqYPlntRHrljg1E48DM0y" ..
	"wPZDjpigsJ5Wn5h0kkNy/980CMfijgE4wFMp2z2Eu0FSU/aLVyPqmjbL3skkz6wbggmMeYf4xBFuVK1fb/SZENzTZOJPXMuMH6ut" ..
	"ClcP36GOZA3J78Q+QN86qsFAyIriWtzD9ba2acClnKpqLDlsOmacjpe6Texnti2cl91jEz1KNoXZb4UMiLO6vRrhR+nADbJiKdod" ..
	"B5LYvsOjGNkUvqiUNinyFe8oAS0VDc77RcL0nfpXb/PisGSq6r2fTfU9YZi1vPCQfDS+BhbHleWkvL+rCcEQyvIqZQhK/WEsNntB" ..
	"2IUBi/lVWa4Yh9GFcsi02sr4HbLbzzGbJN5tRRm5agq3ZTKPRy/2brIVdla1pu93jdcwCRlFTAHns0Vjbnt7noXaCuxIBkDRtqzO" ..
	"nol2l5pSIjtxuQh7YDWTKj62D4gF+CK78vrTnYl2lThkNkj32cIXKONpT9murfB7la51o98wxKWHoAH+MOliYga/MVdbbJbKss71" ..
	"EsXKv/AQ48hrZIPSew40LkkH3lKTD7zXLCdrOjtgmM7HVRGnUy5oerMMhscF1/sxZJ8U9JttlzRIMAvUkiVlGx1YTyf12Ur/IReu" ..
	"kc1Gm3CL+puKyGf8ph9OtFyHYevmyFgzcjYbJ2mLo6MC2pjrwn2d1OUu2I/Xym0SNJ5JP6oQbaO+t8vRyI4Ou9MGgyblmAutKrlV" ..
	"ZTxmmlZNkNSgl8ZnkGF7mylpFpS3h9bHC40H4iPtEB60y4cHzhnBHwGrug8YZWnvkJy+CedfDVRe5O+9lTvQWLMxBVNZkT/oxuMI" ..
	"uJ8jnLd3A8H/YfYLDdFTA9CSwxHKueE1xyX77Mi37XH9KmqT3D7Kvs7ujOLTcrSjtDZ6ngAuVw4Xf4siQwzVCTTkEbn7YX+q9CEL" ..
	"pERvKk2i4E3NOWv9zqegtSAEHntR+1Q6awca04/u9hvM1Oc1nfL+LtqRQrvOkRqssQ5ZlpYkF4Qtw0i2F2HbFWGYVSZKdbDCNG+j" ..
	"cETxM4qc0UWvDi9qkPq5sb/NUdzGPERsnomIcuPO4Non4rqNxOtU5ezHdoHjx26kq2bOzeOWLqH09sQJFIg7706IvMbwJcv28Ao7" ..
	"IAzsLMpP4yAOweabiExuVjb+YX2Di1OA3z+lQS7vgTfrJPjVuuDzs0dVJAuk5AkdVV8mwA52+I1VAui3HakSOaeHYPpmQEx+2318" ..
	"xrpevCHMLw9gLzGVSjPIMiix9b5HKrTl0ee0qaIMLeEK5srs/LzhRNJu78+reB0+NPGEJ1lsQPJvVQq0T79cQaCBicCtUoOhZRY5" ..
	"4uq7RHNjzpnaLRyK2y1WQeYfSvqGMbY+0HkeGQlfMYbPvE+XEtTYfs/ngko6NmYTZn3qMxMAECt3o6ulVWHFNYZJgV4rlnUsiwlM" ..
	"+8PwElhye0dyjHt1k8D046+YU6J4BnjBJBkW9VfmXSWjjeCzL39KjiuBI5w2sTpTx+k4j5xwnbU/u7HsKunm/DstKo3aBzWAbkUf" ..
	"7W0MV3zi/OsnmcUnwKJb8tG0pZ/DfLgZhr3cOc0fOOZqLrH7wPj+LYtKu3M1DpKLSRFIQKXH7UONft1pHGAKoLKAwdD7QztJYZSd" ..
	"BrKa/X5qEdjep/asb0kfqvQLOrZZvbSW+bqDl642incsHy0pnOnF3eFACswUy3HDFuwOJKnon9cMl+J0eCck/7jGicsouOolToEn" ..
	"ysMZzxmbsrKn8Wq0vddNy+JKPrsOeA9pxoG76ecXtdLO8jsHUG7JCKKvAafqC2iy2zWdZEKhhnWGlpHzkwPXE3B81kSag7oIYkFW" ..
	"W/vPwT6O9MM274bc2p2HUqIDWXndx2ByX+NFTg8jWx6aatN3dITqfSdNist6CvZnlKZJodYWYhc5qcmHU4NDUNcLepyt4sfyKJ+Y" ..
	"/wvGyTSeZGXldK0bxvwG+h8xY6VoPhdyyYHpHlg++hM1euvaJPHMcfNnkXbV270IkwMfeHtGV2FZqykg9Stai42C+zbms7EJevjU" ..
	"32B+UX8o/KwcBTvypD2eYKJNMrTn4hTpxogGIpk9Gq9SPJ81TInmfDFaJoEN8f98zKGpz8hJJrblIDS6X74VFm4ntqzKx5QFv8bI" ..
	"K9RqY/azvsQyVYSmPesZ5s8mCn+lDVcBbQVd1SiobLeJd96h5+oBVQ2w9/4goGBEbnz07S7/Fi4WppLBvHRF4+ogeAy70TkDZZQS" ..
	"f3Jgx8MNjqOB9hLp/PHzqY/LAO7lPbWNqZ/38BZQ2M+ASRAqx4uNTRHtkW5i8rvowjMP3aApVGg4p3tdFlcc1N/ctDTzjUTsaCON" ..
	"JroXA87Q/dv1EsTwZ3Up6WB64R54R7lf03dWDcB4CzC3DLa27BmJKKU8+dc9UVU+UvU201q4RKR+F3wf8CLpva3ciX7pmbwYddWp" ..
	"Z8aOMTdldLesGhAOxbbmOUPRpxPhl1G1n1mcqhgfN6epqH+vkdmSVGq13OMXufoy5OCJCWHbZaH4ruMA5baVhJiZ670q0VHv3xhM" ..
	"qV7X9mgkBcugxud+F3V2g4Rewb81FnFcQUFOCeajnCu8WDjy+tP42Y5GNR4ZXkwGgMDd300GxaXgKpQNOSWfceSbWTpvM2mgo8RF" ..
	"PL7L0nd6VrI9PXs4x7vqrfMUzKQJFeEdpZv+cwefYsNwoQy9TmOBwdyXFlp1+IvBXytAJc+volQBWI2sjbbo1g8UNoOqChiag4Oe" ..
	"agYLPES0fUlT6IpJMyNlG+eJ6F5q4plYbZrvoMVKZvIIlg3/jhVqkzjWS98V5H4E/uZS73961WL508A1okdX2JPsiao4UuJY63NP" ..
	"rCZyNf+EsZygkNGxGzHbY48Wl9PlSCzFCv7VAP85u7bABFFXUnac5hh93QeqtU5sKeNt1W9cJL5HCiezWqN1TC7y5swoDm3eFvQV" ..
	"Qi/e/zPEalgaiVx9/W09QwAZD6Q92xQAWW6OYLdzqiarA/EKB7KCzmwXyEvBp5JC/p0ffejkA+s3UvyVb5k/RXTFbN11trZdKlR2" ..
	"CAGYAD00K7+9VEvyLbDdztpCb58poTdBIzsF9kJdjbos11G7gKbbzeLs4ZKjAXM12LKrsWkCGdlGcsfZjbF4m+iHlljdmsGuv9u9" ..
	"ngVBA4NeAuW1lbneVuYphkGIrvuMRoo+sVmkGg0cbhrjIfYv8DqZ2FORH/3mkzW5RFfdv6trBHd6PFzThljwHjGwjZHT1UxM3ruW" ..
	"8NGtCfVhToJnKpImimc5nJsnXMx3K/1YaNcNDz0t06MCu81iRa0gYgCAh41i+uoAg067O4ABIspN5lAIOojk9W3aMffdb0zNpYoO" ..
	"SQenjHAw3AurfTpxQzsvFSZzzrelBOe2optLNEND1DAPdydnA1HWhDgeROUmlxxghiwTX5aK1IwCTBhp+/Au1JnyaWxwJxYrBZQP" ..
	"UfRptT8pn3IlrHtPwN/uPFPhMxpoizWbG+qY0JT5EvyHbYg2bWnbJi8C87iUV6cWxMuZPmduGex1otS3ynlEw9+472B2ywmC2ack" ..
	"nqFEj7wrmj6uM0vo+5pBFFbt8tY9IYfMSyf3Wk3Ev52mED5uIbVY3QfNaPDAE0nmVCFJiOLLBH0LYH9sGKOLRTKFwmt0Lamvv4DV" ..
	"ZY4w4gex0tiADvNIR2w62RCHJsdWRLoQh8hX60H4eCyMGrDxnfHfWs1uE3ywTr0p+tzUgtBLENm6hsViAq5II9f9jeJelhgihZH4" ..
	"YykCXwYEskQuBghbiRtKxJJSwbeh/R5/Dj7O2EoSD/EDeGd3gMvuHzfv6F/6DWuCWE59Lnp59zShlFuvUHj+KobBPCURwLhureIJ" ..
	"kyr9ieDoUGtkVXN35CXfawaHCR1W9+FxEodkUN5rp6xD1EwFE77TyMUcyFVfaxBdfwBN2OQSDNL2SogFtqWDIHhK++vzhBBv8PwS" ..
	"5Vd2jm9jfSdRcpv0IxtIrC7mpFkXwNNexnLR4fNvXLiRFB0tDUvBlxuLomBV7rIq59Czopi8C3CM85KEfrb+pRBaSW5hGdVMZeNS" ..
	"QK2w3ApjyILbClQeWQjhV3ieCygWWjNLSnDJldhvx+z7OJcMLy6nPVBEQHmCC/KRq1nxq8iTH5WVFtGp7FNQZ3cpRHy6S/JejoP9" ..
	"mqv9CBoJEK3Mi5kniJbmMlJxA6ivbY0p/4JVomfz2AGwJL64OF/DQw7//tz1+1EL7x/MD2MhSu1mFms97va9p1XUMbF/IaKfvAl5" ..
	"gTqabR77bvePhc313U++a6lhIGyy6A8jZbBeJuTfk8Kh40hi1KZ23sRF3GD4gLYR7zjb8odckmRdcPq3dcYYgtw0nzQZdmosAyAS" ..
	"navALooETMI7S+P/RYKldn0Up0bHG09gnVhZs9O2UlRi/ej89Sn6wR75mmFxn+IeYHA3c/ak8Em9kHH15CTpgqozT0HvsH1rrKaK" ..
	"Qr++jaBDZ8DlcN8PVXShvRx8dNWq1YqJNdXN7iJ14rK2CLDEsZGXO7e+Ml1hlICcYtJ0jH8WSmZ6bC9aOK0q1qwERfetyVXFDoT/" ..
	"Rcwtp5YaXL1at99RdnvNEmhEDsfgzktUBsk+kf5FNk3Ndr59kCQp6RLI5W3zsZ4ZicwXJXAT2zTCmsxp1QIuVA0ZAK5cpGtpG2CA" ..
	"Dl7lsUPDA5L++ScOUfsIJVB9TGG9P5/DQ4uePPmXGb4EucWnXAhjL+jSFTV4OEJUTo0FqqCTwwESZhlJ3+h006GT823ykBya7o9u" ..
	"U87h/HEtZrd2yJN6MYbXOGftVtv4Qv9HHRT8/A1ZsKmSZ//Jc9Scot9esQqRYQBKETwqMxjAeUGWGqTkuo2i0fKYgHDqq093wx21" ..
	"YY+GQj4dFikv4SxVAjIeuB+qd1yFRLH6cPn/mM/rYcIgPOKy/fEs7RDkkb1NgNHGjB3CIhVA1FXXWOAy9uN/PEMZKPMrGabp7pLS" ..
	"fMK9G2byw/5VyA1oD4KWa7izoQA+4vYXhJHXW+A8G85Jc9gzeBbS/R7yl+9p93HrkbcQ2PWb80m51u3ya84Aar1qeGHupCSOcinR" ..
	"wNDA7wmV9lCf0fQjLDPuUZmBN8KNXQN0Im8rycqdwWni1n0WJBz+7lCI2U6hCVt1vuv87tdvX3yr2JwqQGHZ8oK8UxLJxGDgp5Kd" ..
	"m9LOUZatYOzyLXRvya52ej4CrsvymvaH+5XcV3z7/8/0p8n7u26uqyZtVdTfTh7PMzgAsekToVr1LwtQ8E9A1tFkzKt32JYpKNwM" ..
	"mLs6Ct6HSdrlGKQCQ6pqfx1/36a8m7GfJzJj3/CrTUiEIE7SUsobJyD0hFvCAUJ79EfQ65r2k9uiGBf2G6cp1AOABLiVQBypET6b" ..
	"tqfNaxxybJtTMhw53aInU0CXisu4oHNpiTWY8TDvJzs1OIwhpWtsY0a6eFAfMNfNd0Vhp8w+ODMDBWr8i6euh+nrkxwPsJpoP2c3" ..
	"PCl7Wx6hyN8c7e75Xcl+iPGdl3tSHBgkIUKQG8EyVO/pz5G3o9b89YWvTiqKagdH8qo1aTVGzTbg6xWh/K2enQ5UsVdudK6GigwM" ..
	"G+EMLzRjWkNymfO5SfNUfRcTwaaXgg7Qp+GEtGGphxziFdVjZdeKSYcyyqC3BvdtWQhhDJUKG+0U0WJvv5UiMFZqu5KUaMMQROR0" ..
	"nkUx/nNIgtS1a21Nu8dgTMPVlkoGVkWTLp/zcrp1nvNbrTmUG5fFiJbHhA+jb3KvmqB7B4nD0UmbLoMwQvOgzfZrXF8ap7AX8LZO" ..
	"fINazwkKmA6xhz1GZHUFGfcd/+rBkQo2z3d/Pi9ug4L1f9rF43itHMER0KGM7ZnwkYQmCq2+BFNofXv/qbSgJ2WKlVhMqQsXVsV/" ..
	""
local PAYLOAD_P2 =
	"lLcxPn7/xP8P1wRq8t7S/uBEdEYehm8/3ERsav2ZmB3YZM1UzWBtV3hEnD42myS7f5o7m5eBlIYR6enxMg+G97eaK+IkQSOlz5Ra" ..
	"/JdbMEZsE5S1AMoJamwn0FuVIoZjp5tep/T4xX/npZL+sbM0DIhE+d9GSfN3FKUkxCZtzRH+SM7d0qkdizEsHEvi9YrhEv7MOA6/" ..
	"ar8LAiRWJDN7435PagOeqBGh0NyqR0oc1sLvoS0BBiOErMWMWB0NMfpzLMqQ5k8xJ5gj1biLZDGSe45LIhJx/6A3mldRga90pRbk" ..
	"EZXDWkHn01K2HnRwcrgG7SozZOCYEYjBhxYnZSyGkW43zAsChmrx0DD8aeDx+2VtfpSNiYTwshHCS3uhhBV/w8uBCDX3nGGdEN7h" ..
	"Ovp+sJGbyH9ReAtt8Vn0iJb8xQjZ2vXHDVnhDWwTibKvlxpipWaXf5j0+QwDpTd4A7xMxQH4eFlWX4WhkaymbKzwsimLKM8xlUeq" ..
	"ro3L/iSQeCDI3tFkZNGIQ1NjoeUW4rI10XvIPw1PwB9ovGSkAPzNy5oCzddX8t56cFCex/C55Howk38RKWa36SUVG1qeJ9JsjNVy" ..
	"XHNfocs1vcBmFA4xmqXVtOF2rpcZUZ0LNmTyfFtDA1XctdR50soALGrlINqEbrw3e71oATB8hPEW4Q/6QfwXHI09XIz/wG4OImSk" ..
	"3LVmXDQZrCT5onmRxEMfcYLsfUbCv/50yIiwHMHB/lwH8kQsodGte/PQMzVWOadjIt88MCQhMiFPnj2cZtjxVkGGkw/ObJpi6iOj" ..
	"iiJJNNTDmKzBdNRvCJ6xF69dS6VMF3xxkJ3+FFykGZv+2QxisgwcFqCC5oDMpe766CElyXo/DbSJL+KwE0c+Y6vo4QtRcW2Xi1j3" ..
	"p5ZN38/eYvTqP1o2OFmb5+8EF2zv56WvHGCLnsHSLTj0pWe2ehEU3WxWBuMkuntdUmHmyt80K3tI9Yv0/AlocFPKh6xkoXklK0x2" ..
	"0/7yGsObeyLWGVThIEpYuY/WUp/gXD38c3d2IqKYTKYGzhmto4eCwi64hHm3K2YohawUtvFgz4AAEV4GeNFnZtzQlIIyB337cEGa" ..
	"Rzp4JBOiApTOKEP8KKBd8zmIH1/ujJZVHrdrHGC6c2Zu1AgFZad1zO8SRZWRi40KUTDWw+jky8yl2usZYuOfvfSc8N5BYeLAstS9" ..
	"S64s1Hg6Jy2Qer2f2nmfOS4CNbeqKrjWS9b6vst5ZfNh58lSdSEHTCEEkapq+eBygCN+y/RhjtVjvDYno+2QAvBdpZhciYCnMi+8" ..
	"lOjvBannNM7i999RZeHtOtgYJ0EA+TgLeN1LZKBPBmEGhlAe58ZKSn4hBxBrw/e+4EC6jORahKsjlpNQQ11H7Mewo0rhf9nA1mRE" ..
	"kOyahcH9oRQ8fSQQCs5tx9C4zrhBuJkBmq+shBqO+k9CLfemZWhFwtdWQnwGnwNgk+s8KCiQhWxXJeROsVsMSTiorJNKyRn+ENt3" ..
	"6wfkWwIwhHxzJfwRe0qg3pdUf4KvQA10kDY3R/gDvrXzhBgIbFp5VMeqWn6iXW8TZT7datqS7GgCbvEwYdCFFrn5bEmIRKWB9jmr" ..
	"kR4g7WHr1c/4MasHayWHytuLZWZNN+KoYpsqEJJX1UqTQPm91batreo3MZZzutbyqQ8Me0p1qs2BqMpPlRqu+6JbudXi0hr1b5x/" ..
	"AejcVaYE1LnAokTU00um4XTp+H8T2Qxsiwl6aMplxzhw8kp1Mr+MxWERr36J+ic5N9K45RsHdoHB1JeXQMiKQ/bZpVxfRztbOCD9" ..
	"bZc3IqpIQV3Bs5LkCbUHJvPh2kZ+YHPR2rsF5n2K4AqlSOCnmgwmR1PXJv81BbwmtPGxBLDVxf4kUuWJwfrGwa/XOy/3RN48AHFv" ..
	"lunBBsCNWVFtadm7WErMbClAyshNliBFKkD2qOXNNTURCTfICvbbyMsuDv281WaQytGWL2e1sWZVztccJdcZeRxEVRcrnRexj7+N" ..
	"PzNPACEuEZm4AxdxOs4mOzAB+thKUyinkbpqswtPMDkpv7Jv8djNm0AhifjWrxHtk0LlTKYn0q3UCxAyMI/gTts5ojxyLMcfe6bg" ..
	"OOsPSbYpBYR2ayLylbHz1Q+FwEbmyj/glWZzpCssUocAcz4zfwvYrjTbutLZNqr+sIV787ERdFfYAdBg+vaojf9ttmxEeoOzZj2Q" ..
	"AGMVboSc4JgPLF4zO8A7tYcd3vKE8pSnfxvbau+5sWx0551B9zDzssIddtCFg6XhpSRVMk/uSZOXRYdCrBLj9rRU5QXMvwQRSBU2" ..
	"HaVB5IRKMaPWAhBh90GUy7NS84eEj5CxxhtnVeM3IPTXTZPDtEkMP46kkqYDfDbsYjejzJg9P2M8+z9Uwh9/5my1shnIWNAA9D6S" ..
	"i9rNmHG4KwRMV3Ms1GGqsr7D1hDRddi2JubUMiBk+85zSCmPQ5ZvUBPXVivis/bywiqPPfiLDjxMluVT6HoLhQSY7W8bshwtWMJP" ..
	"/HvAKkUzUPmOywL3oXmNf/qldfw1S8JvpmmyPPnHNqfGUoW8uW2VCeKnN7yXRNFNZnPLdtCOvtSZAWVUU8aBpqEX36wdTkn8mUcd" ..
	"J+/sD/rL0K6UYoE6kdVzFDet8Me3IfwC/CuCJLwV6tSYfEdz9yaXkUFXUlQZPHpLNpDNXW6xdMUBGYaibPovl0oMwTzclcAl8Oud" ..
	"svpaLfMR5lB89/A5Kpj6/vg9gq4WWGq7dfwF2GiyeDMZHgJNqH7zO/HSDqjGGFWOaP915Ry+ZZrRCxInDTxvOZULwm6+DDHzngM2" ..
	"PZrb8YknoAcStex28Z4yeAj39maBlbIwMyJF7FXg4jIny1/Bs4Caa9+2GkrcayRSN3k1PxFMuIS1EOhfelOyCg9kpB9XlPDGRJ8S" ..
	"aezhTYgWpjF+K1oTk6Vrl2yvWAGtfHvbkY9dPIE9Bcxcn1H9+xjTAXoCNe7IcXLS1ECz74q0LAf9dQuUYrpTizS98mWgL8MeBYsc" ..
	"D9rn9eerQFy9jOaJO2v3p7updwQ38qo2+yYuSXBtscaqP4IxhsmYfSU+0/N4jXSZlJX4HeafeqgVnkLiOiz3jqtcuZjImI6vD411" ..
	"3CBzEK1492Ua/jUDX538oRGKq4YPVNwqxJ9lB8T/uYh4dq7fo6EHu3+JpChLoGmQKTQtvgxrIzR6WDu1M/dgMvJSW3RgIVfOSCkw" ..
	"V58LH/kvlPBCXlX6jRwQgsMq+Y5lFTu67tK17w0kp6sABFh5SANSNyrYg41kIk6RCpjwEw9VOxCeGG8uAV8LxAeJVz7IbiSV4lH2" ..
	"vs5XUyqFlfJBC1BYVz0xsdBC0CmHOts9+Y03nFnKdaen2Kd6NYVMAXaAEKYZBWc9yTsmH5Yum7UJTKQoZti/KowoGEAnCeqic6v5" ..
	"KhW1HpyMKfpLX7UBXHnemogXjT7UCD8iuq9Lqm3cJRwWdfet7vFKs5gjw6vceJrlBS8Vlmjs6a3PdxWu+evgYT1fwxXZsX5fz62G" ..
	"Xbci7KDvLDon/ber9oTwzBvo0YnS5UqlkIV6RbhTcmh1nDahlFLI5oxFjP8lE0tGRIHsc+SaV9RKuMPyCZ4rPbkGSRtxv+6SnelO" ..
	"xSMBaN5/IXyTEWaGYioSSY6TKY7OwzE9aiEWlSkurbuqRaiM04qu+v8D9F7PTrYI1VCGm/nmdFe+hewrvBy7I63OP2OKrPmUltul" ..
	"Xb212y10pyKRhD/dqdCHi849Tfafln9zkkHnTa11La/HaNA8QFHxBR3u2knkaimm6uy7aaJENuqyTcHAFR/O9LHtzP18VmlPS2Yj" ..
	"cjsq68pA3iZ9EOjhf/ecq254StH7wQVcnD3xwIXcQh1FiioRBHfnXNt0bIiRnJCY9lU03et0k8JuxMPsL+rSPKE8yETARS9RBiwd" ..
	"g3rLbXZPudlnYobHJuFEJJNdZcbLEJT4pkznkqaLAw5DLKs6TvBqdAx74qDKSIPrVkvpLoAg7lQ5z+K0+j3JL1PQLiZrpUjUaGWn" ..
	"PiffBsqDSZ+USgj/I4AuhkoEt9OHv2XQunP+s0yTUOuEFpKtypjad6j3jTziNpUSiJ9kCPJyE4PWUduhNIBl1xL2CNxJM/hHhmh/" ..
	"4CSimjFMP4CWJTqcjbiNL1O+fOlsGEbEwtyrMdl+vawOCFGxh/nPMLb9Mp9cp9B4NhHztj0h6H1OIoA9wrDaheDUDXXwVlxNQE3Z" ..
	"qbVWQKKJGSFsfKxC889ptVTd499wlLtXQYAhFvg7plBs11fTBA1t4DBKogatSsW96SAD7ga5XHbH8SAG0LER7Wzi/miJN4lLZBkB" ..
	"bJ3BQJ5SFTemzJOy3+L2pdpJHctd3UoEFn64YfXwKN3COAjqzA5ky7GQQAx+nxg/YbN0tFBhEC2OLymCuNyLzQ1q3h4AFz+olnK1" ..
	"7XTmM2Tqk7enEZgIbQaBzw6a2fmUGVLdmBQ5u59W2kRrTiHm1CAOFzK+H0iFTfaUkTyvr/j4yIs0P5mzdXOS8tHWdTINHMrrgdSn" ..
	"uue5JtPN3wCcC8AKIFFWvQUGImQewiOHtw3V1Ft03pLmQEoBcFYrx9MyKuDSFIysw4I0V/8c1EPzabSntEIWVJeHQ7AyFzmiqZ59" ..
	"BkogZvJ3En8kQf3mBioAPmiFyVksTaGGkeriOFGhLzNsTfWFmXvSE91c65+TBW1n2+JaWPFdR26kT6fnXztmebv9MbKeZRJ+PcQy" ..
	"iZvnB7VkrlcDM3qLbX2pPfUCi9tlAJmApzv0RWfu5Aucvh16b+EWV/p+tfBvk9ax2HHmFh+78PRClcJV+iute6nYMUq2l8S7iTnO" ..
	"HWVbkXDRKbsY8vXfX72HGNqHffuhiqV+vcEITn3URaENI7vsdJans09L/51Ikpwdyav/N/fGv/n4RXEkYvwxbSLFPVX7E0sDzHXJ" ..
	"67KNhpnN5nC882N9zxWyNhR4T2slR7VLvo4S48WeDdit4ujHMZKQ/oveerc01gN5pA5fenFjFdOXrx3hTZGxorzX0XcV/59omF6J" ..
	"K3fINy3BK0UHzOw/t0Yuz5PsrogVQ/VuhgFEPXFEJiGhfMgDnFmQ1QVDXlvWc1GWKowh2bzsl8C0UIH00In8bMYc7XdXRem11e3t" ..
	"jF78HxtB/RLN2LFYsC4sQH9o3S02spgoiaoAf71a/aSXDRNQG63r3m7mBNxunvk4uAoq1XHc+bWsO7lVRTGfVmjOcPJPLNqyddAu" ..
	"8FGXBdKbMdMy5w9PTD2NN6MlRg1YwhnUdZPCxI5Qbakziw/PSu646CT0/NRUlVsXwOaLoymjBHCwOVgIWU4SslhXMdboqDN+Wyfz" ..
	"ycjzJE+l//zn8DFQWQ9zX6TKgg//xP1bs4FH/f6wG3AqucKl8RanBqosBuGIv0f5irWkvE1fmY4dW2Ww8ZNHXoU8CSIyarOH0zyP" ..
	"gs8IPcdZLZzGLPsqCcO89Cw+aJn6dG9j37R849DtjOYzJ+ikX3wavlFUN17t1elvmTcjeA8IbfNjyjuSkr7as39z4/u+1zMGAurv" ..
	"xuVG6rs/aAWA1iue6paPTLGgDIbN8ag59LzKu8Vo/3y5aR0+2AmxhTls0zpxpR+HvNIX3KADiOchOGNaQxi7GATF2R1ji5hU3N4w" ..
	"zeQRkRoxvHGziB14A0+Ivwb0mj2SUACEogmRY1m3mmfcTcdGSU6qBGktvn/tHvGf3vEpCf3txAAEwx3MOKULkLsfAzf4FqPZ0X5r" ..
	"Pm2QYRFGIQC9Kd82PFZmTkjtdgqvFn4J7maewqDtOKGnAsF62j1CmVGBPgFeWDBxEgxdFY1kFMLZrOWDuHAd6YqFMgZsUVPJu7Ex" ..
	"fVvs75ujCkp2zgnS8Vs2rGnaVPHoFsvn4tFb2IGALRiYgtHXkOFHXC8P57vwwpyIIdHCrr5XB9pJ6+ML8UGWnMlkASCPeXTnsahQ" ..
	"xmEPPzdOwVntfGEnrTDN47I5xHgPb8AnkZyJXNyaFTqjbJdVUFvCL9jQ+oQjlrUXvuQgjvOYMYEumaRomTRWheabOeJyW5fEtjC5" ..
	""
local PAYLOAD_P3 =
	"6Wfbg6nevI4UoYtYHy5ZVhtAGQlIeGI31SmaVjiVDQqIPoT+6urdsh8Uh6D3D19/aOjCx9+i8udi+uP/n9VDsbjsZwYdYBGkIE/1" ..
	"qZiA+DFT8snYFnI3R1Mvey1TZkR3ptWIxHvVkCww6mXqA9HzHSheP+KssJSCzEtzcKBFSNqfwrPzVwGMsGp5dYpDe+tK/TIeGaFY" ..
	"4EL07neSvdMXfXPc9H2AToTDJlB1mtmhErh960Wvj1jRdMVHDlgjV5JTqBpDtaCavGU4nfmF28yeINpqVWLmb1O3UsjC0g9Epq3g" ..
	"6nfuiISr9qmWCLvSBfvnfnwPn19O5jef1qOjbQMw5CWLPOCpANBrYOT1OomQDsxszSXrUXbLepnNDQ4VkgtrtNDTbP0q0DA6NOEx" ..
	"aE0js8mKkx2NmagUD50poosMu27TWi3bR/ZuI+b7Cg/I5mz7TiX+KrgIptZdWKqUfhLgtZUreolX4yAXq5OP6sdJ1hHpS9pyTxLM" ..
	"PKBWEQiQG0pjFjYWEEf3D15cUilIKnRfou/W73PiEKLqlGnCIpAwTultoph7JUfX4utNS91E9Thvz3L2TXiqGlVVQQrFp0x/8ofz" ..
	"9Vidkbx1kP0MT0CwuO58HOHHhWF/rBjlOvQ1V7IICtbjYBhtJbuXFHWrfRPtVCl1XnstD73AHmaN0dcRaHyXo+t5CKnVsY4BASQb" ..
	"dSvVDFhBzD8VtOS1+xLsF3Dr6SCR/fubDEvK+YExiCvgzeZxmgSEh8eqRfNP+pQr5ZWUyIkFowDWLZ+Dvx4ZRWX4CjJymoMUvTik" ..
	"pEhIWBo3WH8m53pBr/r4l8w6ODf9UpFFh1rK9Hj7M4fDXqjy3L8cWpNS2aVEU+7MlIxgAIDh1xGzQvoPeIFipUV+FGzKwqKZQ3z6" ..
	"ZkoAT8zaWJpLNKYdOCbPAWps5/0nYhYHR+oMIhJiHoTYKLrFrlPIWy3ebPj+Rqk8rGSA6w8eW5gKOiXrYtmT+kOG0tBleD47DUMM" ..
	"Gew9n6p3Azzn8/7I1qlfQNjvrwpJpg8vw7x7suF6a4gf8pSpudzht8vj0dInTssrILLJ0obwrmGJZJo6l2uOLhNHCxLIcbkVTlLU" ..
	"ChcHi1nwP3kkkJQaPQwQZhZv6M64XDT8QeY+nAsWIsNXVt6AlpRsHP5Vz/eTPvT5AFeyU8K9MVCoeEULQig06lRs/D3Q67vP3Ek/" ..
	"/7X697l7AFpnhTNuqQ8nSWTtq7wONvO7dRsYcVWAt0yRWFc4jKzYniQURm/7saT8qSTgIvdOkNP/tHyTb5/U8S8f7T8PT8CUkSFG" ..
	"IT3bMTt2epUNj5dlrq9mwxmwYefv2rloz6Oh2ZzDJSlR2wObvWhxwuiYsk8FWP3EmUBF6ogz5Ta+r3YpvZz+qNFruf8SFBNreAK9" ..
	"xxy4WY7hXcw9WunGJ/Ms+3SiJtMJb3XCtlU0OtumUtMQdLDqZ8rPWXTsM4V7iTbNWNgHqkfH2nDNAPqg4gE07GYufwWAZQPU12qn" ..
	"hVs9Gm7kPUepgyIvjyed+HwBHlu/UZUlBaQnLnhsU5Op46ovdL42dmRHQXxww3USeTfPcqBI4l1hdHhNhLUJvbc0momn/fXX297I" ..
	"jFR8vI9dmKT4kOtkSqarqqthBFQhR6KM6LhEO1UGF5XLuDep08yzAZdd++3y+yFeMImvAkm5rQyL9WPwgzS7d6a4rdd5/yvNbeIJ" ..
	"NqYv0dS/9T9bxGO3XHu9GabNSxPcAQyfB1KtvGdPA8P6us/dAF6o5aZyw2eqoV4bxgEa2uxQRV5x3Q9aUXbIDzcbobdMiWIMTqOl" ..
	"wDVrufcm6jYLqAscQT341j6Pk+UauIxaKAtIMukhF/DF9jQ02NKRo0AIvACoYIH38iDW6tqwwJ/m/0yAThz3hS4OXKf+UdS/x0kb" ..
	"YlqU0C2YgbwVkXSouLB6Bcdvbo0Ag587kGC8u1wZn2YWyxAr6ApBfNPmru5XMp3qhANff5SqTx8XMgdsjxwVA6JgqPbzp5v5lcjp" ..
	"Gm/E0bFaP0PCtuHbPy4cGiSBtYiJdMSeZ8hf3C9tsmNWSy5KoduhmCy8aJ3Xy06CwQ6uESv67Lo52CzxyUoUF974K3xTOLKsZp2H" ..
	"14nQK2BRVW15oqJ+22TaRm93y5dq29Uy4ZU6Q0iPVVMxbz5DhaYoYkNer1gyMSg0RhctCXiaQ/Q0dUhCUNypw/IFY2AgKGynIM95" ..
	"dDMQ6J/dsUqSVpbBnoUWM64GnR7J1BzSire3qf2S9JDwp4H6e2LxYJ+jYKdmDKsEoY/mIkGw8dI9ZLv1KUgrN/uGL59i7e6u5opU" ..
	"eEEAwjZdL8JlP7ftbuJRNcNyyhXrujSAJYbsc7uft31yIOITUyZDPM/ys7yANa8IYyOaHep9IC3vcftKxeFppYLo1aIlQ4VqIOda" ..
	"qgRep4FR/YtXrdgrMyFgvWsLRYv/pqGcTVhVxz25qTHgpOJXB1pXLCY9wyJS8n7kOtzSk+lUEyYbjIOGqXVHvS8aLYnMT8bKubTp" ..
	"ruTASdklBi/FtqQ112WNSae9oOvxM5XkngYohi1ctewDVVcm0A7wPz9W6gWzm2qd0evE7wWQZGwrQ+fK8wvYaEwRHPOA5mRLmKLg" ..
	"HnqtyvU9CDgXgW4KWSVZZzwK4xkBJjiq3aac5I8SE1jbCEYIHYxDyLh8UMCh97uNNI6rFuBANHSIsQm9KMlEA7sOKl6g6tSiz4yJ" ..
	"DSEyaIAjKD52pLvEZ15oBefazdnaX5s08rUEqo/YIrWfOODbI7awxQcpyecDcKjbqaxk/I3g3FvE+qTV3Gjc4QFCPjp2uDyelj3T" ..
	"Pc00ZnNWKgM9mF+nTrcegqSF071FuwHncdql9CcmDwMqNV73L9pyBKlTRXJNrl2RXKcZdXtxNsPS943AVY6nK22W2+OGXFCQGQRs" ..
	"AjvcRDP3pOZkhuvx3f9nb8jEPcXPWkB+YGgcDWYnQaZmrJyFG557p9aV8uBy76a5GeBqY56ln8gBXMozJK904QiNAPPeoaX5o4uS" ..
	"IshGxGQaJU9ouTlkRBdCa2iDieTvS1hxLUfXmzsmO/j3TY2+dcfpHKhjo/fSwo3NFSpSlMnP2aCGdokwoToaorIbIce4lGhebeO5" ..
	"P+FYinGxnQzQDRAsSSJ0JhpZKJO3zUq3Mfcgi4Tex2bCX4zEqCVhlv9Rm8qyEqiry5CF+mRYeLW1WtynULyQBBNBk2pBVwKK/xjK" ..
	"iRBQRNTEThcdi9FJgezkeRmfYzW02XbFKomUGHB9Lz9Yrm5CYDQOHuLnfkkzPXFgRI31uwnFLrtAJasx6zr7A+VO74FXkLH6sG6e" ..
	"ivCsu85wPn/F3v8cUrVdn6w6GR0zxz4cqauuCgkbP2sh4kYfFf7Rd+8sdmqxaedwN8wKtEaMc1Ugm9evzSxbOj7GUNgawUK52bGG" ..
	"ztKrTsDU7AVYhwhc/TeQZBliaro1c7NmKwvn/xvwzTBfBSY62IepFdGRxTNffjbqx5Kmu1nItOzuAq9jhSCC7MAJhYxscSh1i1ua" ..
	"P2S7d/FmMiiouVXYfHTDtL3csa4ihTYWqYL9O91eCbrh1aSDHjGMXT+Z7GsVbAt1HaAMbkLipEXhZQDs7r+BKbdke8cZszkIFNiW" ..
	"R/+gJKjVjOhp766CmRvd/boiMlbNAdQNpWC5l9ie6Q8/hvbosJkI+rjPASMzbjT760clZSsL+3ts0+x+wqSCzAMMtkeKJ7npxaQq" ..
	"QE3+fKzEq6601i6bKP02mI8r9mZHjOeURa0+68rY4mh66zwqd+8r1k26fp4Yy6vhaaazN/fFMxw++lfn8qcKOX4e9ulM4QCB9bw6" ..
	"vQaoaSsX4SLdK5DsM+z6CSZuV3VWDuodTIRtlAARTv5oa+7DIPlMFcnkZ3wv4bgFIY2gtuXnrMgEtXBDmFA45OD+RADi6ErrPImj" ..
	"D63YxBYvHnxeFXGp9i+ISQxdD3DbAuickYgSXeBtFXRCJn1LRRQo1gk84Z2PZqIBxev7nPPmBHtOxRUoIwePRAhRTrLFYYtSoiW2" ..
	"+HEP6Abua3XzEZkINGqWR2ZGkR1eZme9HfABy9VU5fTFIDDwJzCQoVHWIZ6kpjj5N4BsOE8x7lWrWoK5yz4N0/7RjXCNCkXQqTgM" ..
	"OxZW8mX2WVlZHBUuRI2lLPocK7UEJdWq88+m5OMpxv84zWZVNybobaU8Bf7zZ93BXExzK9dGussUEFKaevn8Ep6a+mNgP7hCcseu" ..
	"BjBm7m81O6R39gQ6vYKIIC7YvZ/xChpGe8XvRJwIwsOf0qly5SmL/7LODYsUCvDAUfmj9Ncmt7sNarmnt1KAwUr6xF99bt8uw847" ..
	"HInbhuY24zObPXL+t5tUNi6rQouFq/weFChackkFKZOueJjNhloe6jis2d40H/iFgHpal4vwa+wQSwhG8KK3U1B/JlVXoBJNl/Kp" ..
	"9veusTnrDOJywMwaVm4ZVjjpfdHX7uOc0UNJklqabYQ9zatGCQ3Li8GSe1DcDEW4M/KEDuYZ7HIEwCb4+BXUvRdWkWe9pWz0MG2d" ..
	"C+RhDGTo6oVOTon86j8awrpEaaDO4gI7Bj1N9i2e4fmjd/G+nmt3AhoN0EzNNXY9T5t912hppkalWKML5C3jlIjSaoCyb+l9F2FF" ..
	"ejTQnj1F6hLN0S0tB+PT8SoiELdYUanWAeoq0i5UpxLIo5Izw6/YRAD5XuFlF68Tjhph+B/imjumO0F+3C9XMVnWSAnJA6mLka43" ..
	"fxtb/nw/bbKUXmQPuqTlu0wT2XlF7CS3Z3gh4D5CJTRwC4KuCGuYWx9uulUK/zILcA0JOsb0xpT0tBW54QXQAMBDkFmbsp20qZcB" ..
	"zB7c/GtSM9pkp1VH9Pe2StJJPrJ3A4Kguh2iXJ+WcyQgNfgi3WtlhmEbnLmxg5Y1FV6FrxX0DrME+cGGXdMNBzLx1HQvbzxZdsWb" ..
	"HvWWtT6ura1udy4ekPcTrihvB5nzF+GE/TAraiaUngQYsM/fUY8B25SiuHktZJP0Aq71CKLRmVpSFCYcvDyovHBdgksDYsPdkfVQ" ..
	"NZ0G4W1MNaawOS1OIY5FFbLCLJDg2Oz5IYTkR0mchiMxYr+kLGGHiFBrtm1D+t9TPrJ4cBltjKFW8NkUFVkktAEdDycoS5mnLM/X" ..
	"gRSMMv7ot3m8z78rXK8A6eIp4a0FEDvS97PamTVivECmEV/q1yP3VyLfbRSfwoQO0DKiX2odVZwnFd7c/g9hRLNmcZUInueGnUT9" ..
	"2agShj+GWNjWV18Ne+BtwO9ipvAhqrgXFTkbp7eTI97hcPdNnoa9/I+LTjkTZYUQelP8NPCrcE6mxEt3E0rJQrJRSbXs8KF/x2LC" ..
	"Zxg1AiXME3IKxAbCMKyezQ+E+FGIKtEPXO0dZ23Y2buF7pMg/S+L+IUQgXFM8fE384gt5PUXv0WyekL89Ar9nYILy8Besp7wtqtD" ..
	"ze1ZjwmrkE0zSfscG8ztin09xcIVGZU1R+x4UXRk298ValSsGojmoZPh8rX8+5uPSWK1Kz64DF2Z7Qxy8ArmFh642o4Mqjxj8dKG" ..
	"+skdPji/XOY4eRONDKeRT5gdrYI0W/sk3dijI7zvW65WBi+WbwzKECvDzj9n5uGxuQ0QU/88x0bX3BJgOgSfuePKub/asOP7vD4u" ..
	"sWb++UZ4oNqLcEKR0B/Bswg22RV23hXtTsu8MVdFDhW4JB7aBVa8Pu9/Qo6x3zbuDf5kGYdnJG4ykRSfYE83HqF0eX1+hEjYADsz" ..
	"tKCVODNYkxqH40mnPBbPRY4bjIfgMlioK0UqK+b97k+30Oxk5Yr6K/5KtSS7EwFXUhsjOXn1hVS0V/pqSszgdY9cbwKEN+d0Al4x" ..
	"MGecUm2LPBJM2QcErmOF5dMLuEi21n/KUHYaSp6rNYIp3OpuqU753Q5GR28qCBw3guOrf5kzWcul3yKoFZ6D3xmozemUKGb//h/E" ..
	"EpE4Vd15GU3NZvzPkaI8kA9ZGFOXBSu4MzXpP73t3TyZ+VNuq898OIXeis/2DWoKz9jW8BdxIP3uDUmoph5lY7liXNBb+MzSvdjP" ..
	""
local PAYLOAD_P4 =
	"NmVAWaYbQ1d+z4PkDqSZYYd6kxa5szQfUXBKcb9svZ/5BGuhr0zTqKdUlVDG7Kbfr9rH8nLAaC5fX0ZLy4xEJsJs5wz8KacgOAWR" ..
	"YQDO1vZ38PknVpS6fyBMBUyhy+89eYucKYgKmRT0aZc+5k397YVkATQ5M6/3yNF7iEsJnYP40/sKKpLS4ljUkVIXgScRKGjpE7oL" ..
	"VycXUNPGRgpSo7Hgb9Dc6Aw5dhvuRDXWi3KhR++XKhU8mcw+oMKgEr+AAMT8JYYyFSX/zzIsbi9LxF/ukx8pv4f+AudGzSSlimyi" ..
	"00IKAZDVQf3cNojgoXxJpuZwh5UEupKSjE9TpyYLqSvjB58EXRwdBU9bb9gsYY0SWMAjQ8CTR7yEluI/S/NNs4pwUIc2pRBhIVVa" ..
	"U/UMsZg0jlsMwhYoo208Sb97E76EkQDjwMli0c4kIf7op4W0Z7o0GzPPj/8RmiB+jCVAOYrMeBMeRNBo1ZsV/V3G5XTqLpGIpAC8" ..
	"UOa8QsDinDT6gyR+mgzr36rmH2+om5zbXWSgdpKEk5fHDGySAGiK4An7mWDSvQQ0+NEc+LPjJsiP1T2u6kfidJ4lIQ7E8T0jgisU" ..
	"V58Kb93K0oYh7eZl4qjsDfCx+55VV5de5Vy9ekbrO4kCmgNLoyxpTt66OzVc4BJ6k0xLYhzj26sLzCLheDWgHQF0r1x6uxI/kTFG" ..
	"Acu5eY16szgDt2mMY53ECwPNs8TYpfL9qzXWlKYf6BdMdF9sRnG+1fIEkQ6cGQLDRSSY8o3g9fBqMC1GtTYsTx1JJUdGcgxxLFiZ" ..
	"Zq+p+bN0U83CQY5/mLmnYmJpxJuj2k+q4mro/i3t0jW0uHzjNnnUm8HH4CwsVNCD51swIoTrn9Ig4dhJNccLk0LLOuflkOqPuVRu" ..
	"c6B9zVHVRESKQjJNSponOsTpDRbWn/qit6i+r9KaV3Gh/u0O5oGOuIkXI4Zh6w9zaipOnGI146k4hb27CVAfR1DtBmUeCDD8jigB" ..
	"AqgiB+WazvGigUscnhDrQVZI79ysi0aqDv15Su32AVZYNFWj1wZwoTPgG5vi0Pj0xwcaBXlYocNHYmE/akfy5/WpEwk8A2z0jiSG" ..
	"zf+VQpo6NGn2tDBEjV8QkdW5YqcDxsNWk0lqRWbUf2Gr/IMH1KF9G8SX+eNVa/fdSoDnl8dU2TZJj7HObHR2/6DtbKYovByhQZz6" ..
	"DMmEa+vvfaAi8qVNo7aj2aDkW5aMLQIrUu2giH1UxlAjHoSH7lnPtLUwbb8JukDM9D9QQhbzLlg0nbq7Ud23Cyotp5qIvq6qvtJa" ..
	"yJABJ/atK8YOu+Zw5xxlx1ysba2iDlnDoDeJvvIv129lajki/1r10tBd03mfNUm2zTBiOLBdzOQy+w7USwQXTYtA4CPD+VVIIUpe" ..
	"cGtU73aY6cVHOZdVDdm+V4hLOvrhWF3beSQ0HPJ/g6m5Uh5xTvkFHTpJUiaXI2c/tPWm3VAVndKkgMNkwItMXh9u5zM7KHEznyQN" ..
	"hUtSeqcrAcMMK7BgVE0fJscAqZeeUuuM9Ttf1EjymqiR94mYqMl1UFpB1GJfy5KGmZOsIlM3lMH0X478YpY32h5snghNBmWMbKFe" ..
	"X1LYsd/mP8zBQlGeyD2P8E93q743+uDGdW/zfxwl7KWenimG3nBO9bCoS/NWrnykeepF7Wk9Zwf1Nbl+2mLFl2POIDaMm3MYeYLM" ..
	"TbQIcE5aiu+FVnkYsNmtbs62GnTQ8XLvdOETxRpOPH78cgwdrIZGp1dU8MRznmtF9cfeCfOyvORfhq71Xlkze9mtum1kjV9Djprt" ..
	"LTrnbhE2U9au2jEulcDM/Ztx9DQRiRwAE5ioy6Vh8dbFw8JbcFgE5hepNjhsWxGo60PxEhee688vamQTepPtfB5r4Qyh6K5WgkSN" ..
	"AdNumlvhQNClnPFM/ycd5J6VXUpiOzK5p60pOPUEChsbtUrhF3wsH40sjqjTOgIHj96obugHAN3rHtDk4X0OHAQdEqQToVb+BmoA" ..
	"YyBc+DnfwldLm5eF1G5E4S+yIM324xC7kxGu2NLFzEZOXrw9ro7SjX8lcvI9FZRf4r1YBx8oQJZy4Xq4OpRjyZ1YNAPZ55JzcoMu" ..
	"uqWtwUHtXaiii0wyCqOR2OP3tWe/7/fPzAfz2qkBVP2vLk6JZvLj32tswEt5XruF73kldg1WIsZqA5O/KrH5A0ouHQAJdO1UvmHx" ..
	"81Jpg+VB2C4yVo3eTxIA3GnCb4qY/gK+vZk2XFUmMRGpqnV/10m+wL62EaLHhGRHjZRa0cgI9Lw0PXx8cev+V1gKdx39iTMg2xlx" ..
	"gYpVs+DUZwUSHb7IKNJoj7yqY+QZ1i6VWQRmE4YTV+X6KlkcAle4G/e2p4mg9V/zVusvRe/bZysCaOOdYocps/Ishq72xbp5+rZX" ..
	"rb6xOffzz3PhvYoVc4FNzsPnKZZqM6wiiswubovY82UDPQVkuYEqTHJJHfZfuW6tW+TK+Bwhsbp0kIiTNNHDjCUDpxKN7PPx6Zt5" ..
	"iU3ORIKXH2pIX4oH1EDtAi1HiEKteiwNq6stlYBcYSdD0j8x3o2JeQw3hfcT/gKCb4/oOpcH4QoHSLUOofzssu5zOE7WpkBr5XGR" ..
	"1GlEyoObXTMMmnoKcd6gC9mQ/AM4IG8SICwnmox44dyiVXNkwB2YYjqy88vIGifHItzgp2AsK04dc/c1ghG5Kcgbvwlh/DAOxH0h" ..
	"GMPO1yu+0KPRIWrTCsbuTSfO4doy+REyjV1c8RiOytF3jFXMichJwNeUW9WUf+uzHbdTfQFGlSn/GqeZyMsdwxZdd1TXC4dSBZbU" ..
	"QotiWyf9mgyoddFQ8deC+nN+nsoqk1+JWvbrlbLXUs9ROGhMuExmb36q7NiPqMVFgyq8dM/3anKLkUZdFxjzTJXVASD7/5m1cDnX" ..
	"/kZVbzx5b3UsS3C7g6ATGI2yAt/BFR2H8calNdku4W5V83e3yuQrFcnFS4so/++shyehpSu4AaZr4kzKlhuw8RsJLKKWIL1Nfcaa" ..
	"i+whop9Fg8ydsTtAdjQEa4sSRdRnFNReX2NKzdPcjH0fqyX+qQ4Zk/aDFvtyVTLZMU3yM/L15mj7rMP5ubj/xbH53NAnR70Y98bv" ..
	"y/h8aOqEQLRMUCv/a1O3H905PJ05i2+Nlxmr8mEK/654teHUqaGXIVibLW9ILHy/OUKjJxGYLUubVS2M9AEqhJB0CfcPWtI1BV9/" ..
	"oZE1Dt9YEFo+TXLRGkzzjO6B1iHGvGcm80JWC8c8y5zHWOm4eERDepb0pq/60+D5qJoG8OcLTTj0Pf+Y8OeOOYuFpy1pPgMzgCUj" ..
	"GNc4hcMpIEiExtYgGXAyM4E9R0E3NJ+7rQyUijGUKTXcMFzs21FwkUU0xb414DGxJed3rs5XqVEBu4D5jxZX9w/Jt5Z46ve7VAiT" ..
	"nZqj1HPQ7hE066EBCfQ16Q3fLBBeRaQb74LfIrr2Ui46mbhvy5F1IFighd9qam8AEq1aGrvMKlNp1GxgNh1DlZfrmLI0l4X+rH4u" ..
	"IYVt1yBisevsHRWBJfNKeQUdUC/LOzREZv1+eF63txduHZ1xi6ydgAMzrX+gYnCdFWcPYLRup5SI2WFnI0aBDKLVePJxfPEWwA0V" ..
	"45DJsSTCOFnm+kkpO3EbyURX0b0bljDaakl7gqyvmmXl8bTMjwn2ko1lJQ8gIFousCYhWg0JI2niZZJllnuLomjapw8EYfPgphLe" ..
	"fXDjGzaKKi0n4ZSc3eBQo1mxfGiSnOv5kXHgRFiVDOHHjZ9WVsuJ+IgiNrvCFM+Q0Fc7Kh847IbL56/1bNxR2xs4TNmw2w+cMEPn" ..
	"+M41NCJC84QWhtl87ld9FndYWeXlE/7uzbt3Wi51956bCwdWGXIdYI0/IcErnS+/aed/k24/SksIm8I0FZjI8l5GK6/JHNu8rgan" ..
	"l0QNha34ISgiDeYmvd/rX8iPgOoMIZ2uGFr+8MTozA6lyKBPhURKWWXfszFrsdFqHgHS3HKm3J23C/7jx7COWFs8nXLWLoyQnpv+" ..
	"bxbk+HpAh3ui8+3PE848vltefilxtnzKYIVsm1Kh14ov2otZ9PssLcU1B+ByIs3/8qRRdxOi/NH5IRV1vXGuSUSUM4jjDXzQBedD" ..
	"I6l9u9VWcZJylQXftwzXw3RxVUfrpPdkBe96DFRNNATuWWASTnjmuj0m7lYYbUozwdXy5iwPzevNLg+mt2hfyZWA4qkh5SieoWYW" ..
	"+MrGyf8lBYPIzqzJYLoh83zjNak5+v4ytOjqSK0VfSTN0YrRQ+4Is8WTDMEZ9JSQRGJGpGGP06CoFLiQNJ/3jQ/XWAFQQg5/xMQa" ..
	"xSXNDD7EjgkIumb1uu0UDzDFIZTSNSqPA5+k5/lmQ38Qen6+CIaLok+/DQyAeACRrEXiVNX+OpM9ipfHb2iUOCo7CKIf7r1BKMNo" ..
	"CzZtynDugN2/J3dpfrQPQVo8EuFdZZrL3ckcaxddMBoGjgRbAiwU335ro8m1cFpe3+mAZ9wlTHRBplpAYoP5B8IlVyqgx6SAuPv1" ..
	"m9ExtGLaxANXrf/X8+zSGy9spSs2uz96fs5EvUnLQ65ePnD2mGKTdhZg7lZqjEkaTCn2itVB0YauV2sSZllBqkvfB1svzWmGQ4xk" ..
	"dZW4QENDjO1BIXWvRhMhv1jo492w3Almy+78YMWkdynU6RjKyQGtfIFHiWMbPgJYA0Cq8XJtcsgi6HLsSnfYjkBujcsaqGFpGBYk" ..
	"zUPNMMU9528L+9ysw9jnbPoUNmvxQxyulAGmoTm1Vneg8Oq6wzzryZA/npo5+g3k7qVEY3Oxx/SrCZnOkKIGEIK2KBOc89iXU8Vv" ..
	"TjVF4prhqn9KDmZoQK17wqcNSpAcdBQ+4wJoiohWH17J3EYged8fw1w1oxbVcNJmx3kL0Fynay3EZ7NK0LMyUR5A3v9kiRpoS0U2" ..
	"wli4h+B1X7YPvAKdlvk3U4HFctzpWCzdO6DmgoLmjqaULtx8k0xknKmJV2CYAcKdCdBA7d9YBUU5u9Fcz6Pif7UuyBmRzdQBiF2K" ..
	"WaK1FWaYxzl1mOzgicAk56CVims77MRsnIhKeDUrBwZaqwOojMwtLZ8YF48MlCNH42onxcEXt8l0ORxwdLsXJ3f0vVDhHV2tTjKL" ..
	"lj+nvznlk+6wB7yCJfZ41kCIUqCjHKiJ4Vob+d9oPXEZLw8he6tG8cMVGB6fHbQc1Yn46eAHj7fwI/5l30olHy9AXzpTNNnLJqsj" ..
	"Yk7Yoq5DiK1l4FCvNdbftMlVdEsrutRLnhXC0BqlueWmBHhVp8lIYkuMcYj8U5VE3cToROMNCd8RI192FB2TKO32KP9RSTuF+gdW" ..
	"p3vKLSUfzex4ROH0mFV94gg0pyp0P/3XeEG6Dm2y4EbNKW4O4pQLYZIIYyoK/sg8hNL14i+v5yyC0G30l3skltzOK/jNKQT2xW8z" ..
	"V8YglrrFgT4+IL03K36Cwv8xJLhMzKbxqyitZwHFh+xO7XYirslgb6X+bVbcYDhTM1sy1QShjZdChj0eW6YVVpCDfvmlYGbYO9LY" ..
	"n/CIvjDEehUGPGoq7Q0zHzFahRKFcF3OojZlbBscwvKLqkGDqJxif5MhPwqd/K39uZ7AEtvSF0rmH1WC5Lj5dG/Q49v6XANHxw2S" ..
	"2vYnk+VGeAzU5+eakcq9q7I0R1eXItMWYi1LF4bbgLFIP1SXsPw8GR3kqr/J15YJi5mFZynSr1aJp2qnUmsgarCFt3VrE7bi7AKr" ..
	"R3EiBuyQeMM9KBAcJT1CQLBjfBSrCQ67xo8QEzQunCSbeM95tf4WJPFhREK2NLzqjwGbL69LfUNnUx715f8tHk1fJswu3WjthH8a" ..
	"m8xyDO/hZP0XD/yXRK+fMX2ePyse8BgB4TXVbtFb1+JzAXZfhbD9SW3UVALdbUkds07FHax6FmP3f0pZB/ZLo1ilisJckBUzERkQ" ..
	"CgfKChElrWHeoR2JA+sentt+tZ5q3DPRW7slQ7m14uU3rvRQBHXf+vS9kSoT+212bSdMGx7QLnW9z6IuBF6yp50oyJXwj5BMykOn" ..
	""
local PAYLOAD_P5 =
	"i7yTQpzpKEs8I4kAgspyaFbZb2P+JzQ99WVIP6zAZd222Z1cAMmti+PZig+zadjBQhE6qGCluyrFsUoWJeJrprCSubhlPgn3rV8u" ..
	"aA1guT4NLrUQkmEUoZVoXCIOEFeKHVtckMFJ5x/nsStkRZq99JKqiveK6XQ7U2EuXbbF+J/zBWsmnf4VBP9lUJdsMiAy9P5ihWgF" ..
	"TLALtPQWyWzEfpYOKn8wNdBGKXytoPd10QSEm2k/CcvAOuDyjRIKQQ2o+HvrqPsgIybSJ/Nd8k+QX8u4WjQrutQUkPZwirC2cYRV" ..
	"Zh8DITjt1iIUWryqW3SZY85FXto7nWnggoKTQiATiBo5Mbn4QGx59FY9CEmltVf231GzPkhNlgOfjN4SV/6XqBrsgN/dVKSCLCkN" ..
	"mJoChQf7VrsUA+nXcpDTv7d2CWw8JkP5enEm4GGpQ2+pkoVJplirPiElbPRB0llcLYKMcPnPctwuxec3COFeYVozS6keyBgI9QQx" ..
	"GHu+aovIsMmmJ45QKdz7+LbXb3T/u5OukUaiXQY2PMc/hihC2rWiDrbiJ077/43fV52vSowBoKiqKvFtQ6dToCzpXNFGyEEHGlQ1" ..
	"PrZUfV4qRyRPj7Ir29ZuJ4DoWPckOD9rPmsiu5l/MiSDwKLO60NPD98jhtRdBzetJYNHSOg02dOAZMT74nSgwZ1zbX89h7Kf80tv" ..
	"qwV7oLaO9julMe+zr+KRWedLrQoxMwMEEm3QXnCh9mk1fr0eY3EHO3vTfBDP2tF1NcZhSdz5RrorOf/2zDNIqgRu1KWgGXoPMeGy" ..
	"6er7fwDnnx3q3EuTqUY8mH5KjA2l5w4Lb2pR6+iLfVAuv5Nb+A9e/Hwbg2wR6lhbLmwTGypob6meYisLtWhFBANcLVgraQWpeSDb" ..
	"ZGsAFjqEvlxH33XWe9o2cSUbbZfcZrJaWMyqLWYxf+k5ngDASfNNUMFA4tDpjGQ0fXGm2rXWM8zDuDAhX00x1jklE9d9kFUs0aH3" ..
	"UjOmHKZEaGIG4JbhmSnYj01rPzyvEo7cb0sLJ4P2UJcLUuSUTJMJDY7KB7e5HCtIvJtpLu//5qiF5cT4fXCobyFZn76FWDDZnQKA" ..
	"SvhFBm3mCbKZCxOBVLALIIyzLdgoQTK+tQCBsDdooawWHy/2PmMeEL/JeI9/paqVP+7zfnTrAnaZuiq31hzZKi+AYnOUcoc/M5Sv" ..
	"7+/HqXknrwa2RsjC771xhg7VV4QpfMl9EbUwP6ESWorvumv6mVGG0Rs+35EjLik/533c/1WaWG2LWKyk3OR+6O5bMgt3VsAkOiW4" ..
	"A3+mkx6wb6CmolfxIfbuDexE42J+RZ+9RWe7jct9mHFADUrbWPWWJwow2JqL7kgRDExo42yzo3AOUK1/zHJAxZ5kQFHqqGP+6H4U" ..
	"/7VJjPMfxEUCbHNp3IcD4R94z4iQEQJoco4psp41AiEMjwxX17EyMeMAH5h+j52maiidlNTKj/eezZB+dgWa/VK9hVfKW5ALYyCp" ..
	"fkTHBZqCDb5OBZMlkgLbyTyJEhRrImkhuOD1JTF0wUn35zOdCLeVOgdGK/7ZxVth+mcOfE65KInJDw9jH91zlNfNV980ZNYkRrBO" ..
	"FHpMHHYMgNk6QhAA/SGs/TP/xWXWmnsA0eiPF49MZxX4jOYaZ8QiU/DFukFVNSdYAsz/NARstcFOSDnBu0tXFkgJ3aBo7VfVVoyE" ..
	"AhhHGENg7csnlbZAM620PbugjJdV84cUlrF0unDx7bqOiJkADt65NzcHl1wZwgDmdgaDPRLKVcVxj/nj8AdTWLfP6OA6XYVys0VX" ..
	"PgBACnIrYx0uh4hSeB+BdmABYgI2LsFyyz9fBG5FTZsTQ/PG1Mr4WAJMrNvf+kRtJUeBQ2ItedVUfm0Rq+8KO31E9Xm4vokTqyG3" ..
	"oviAR73WiRoJ4g1kG6wu+Vzk1XBydntlMmv0MO26pq1t/Uevk1DWr1OWJlwG0t02hwlb3VcZtd5LIPBZdext/j+jFy6H48+f4j0T" ..
	"hXvir5ohR4u6agL/JLRlE+jgMUq+uWpTyBY8VyTxhbERdJadVLfRrqCByQh3fZRrI3yox8rO570uDxwElhINrDm7lbc8QYJ5r6hf" ..
	"l64Mgczsn7Ft1x9TwK/HSC0/3ic+TnSvLC4v27TCkJKKnpPDZrViSaGJ48RoTNIVSDdXpXF8i2u+ZS+7Ax0jz31+lnwqHEDQM5H5" ..
	"bn7/wznlEqjcz0uYU79H3neGpdOe3NiIsy1Y2Z7SgCTZrLrW1LRC8tKINY+SgwpqgqLLFE8of2h7ZIuY9ecOJ20qnNC4o9ABIEJC" ..
	"yqooC3rRrAv8WkNa/a4i2blTovjTEEIAv7rffH5vRrS+IZ0/SEes1+MFuCCZYunL6FIRSpACB9A6xwoOsjUfpWdQ3/Rlb7pTfeTc" ..
	"OEj8jLS3i5GF96dIz1mmAhv5H1ffz3DQQypsYuT1iU5y7pG0BS7yknHVDPKCAV1NZek5u8AJEwWnPkCkXQrZoNhfzToQKuycJgaD" ..
	"e9BvaCLJ/fFOFP/WB0a/EzBKqihKpG/cxcxjfoU4XEprmNdpc0CJ4SJ3AKvFrK9X/pzma5akuWX18nKB9Z8+TSm09qVORb+KqrIJ" ..
	"DQNQjFMvX9f+TdWLLo/Aay/izdBQXmClRSrOCwAxAl9GWfUVqMcixt+UHvJgoepE8nw5ajg3SOcgTyiFWvZfwSxPjiurLzNDlgIB" ..
	"4Mw9gbMeK2e0geZLvy04zY82uH7Eth/kTSEdobIK8SdXiMrNuSoqDxHDs7VWzDvSEwH0Azz2+CcuKa7hVVXWMEk6H6NTswOzwR2Q" ..
	"v9ZponAfg46T5oYTiZV2UxDnPQDpInPybFC74320KLf0aiMKv/AOWy6/awEoJ4Tb1IUocIjVGoCZE/BU4LwDDYgL+30OHGGWGe5l" ..
	"A3POsAIu78Kkbe2oJ3NLtvPbDNGb/NSC++s16vRqZ89PDiGb7ZcPF96iPVuHx4ityiXkMP4327MCXdwdZx8sVf76iJHJXdEb8aL+" ..
	"8ae72ksK/CzX5mA2bPCsg5ZtD5MW7XghKzq8zN0OnCyAh6Lo0MyYQ+BRgVhVGhhY7cqnI11ircpslVeEY8+fySHKCY9zEmdCnZPA" ..
	"00CRyT/PaXbrEVkceQifc/HW1WJs2g55PAltePRaBZro16tVeySf425XsFyykQxwCu+/jr5sKFANHIZL9FQDWmAHcCQcmmIUzaf1" ..
	"Nq7ZRxCl0F1H1vDD8kRO3pcp60c7StW/jsWQWTCem0J+NdQjLNPg3Yhcfpaqj/GRJ8fLQrEewMqMUMZXkH2w6RvYjKrLNoNwn8ZD" ..
	"+GGNScz9G3Vz3wjFy6XarVgt6qXdAszGcVGYu1xsgT+amFUyH1VXK+TektmxwuJFrJROqDG4qJHjTW8NMdt1EyMdR8zMEC3acCaU" ..
	"/bjrN8gZBgaxqrqAjRrW+eIapybGZONsLB6zdcENuEtriwL4FuBgQoMUKZH+et5dbvlAComhowQYZxm419/lrE5DHFF9ohkwxgXT" ..
	"jSPpod5AzSvnLYjyiQoc8JUT+OGH+6LmfwW9oodnGXyWGdmh71oWByQsld44DhhHsyivXRm442VbwTNJ+Xnydez1xFIW8yDz/aXl" ..
	"lv81K7mmv4uq7BAljpaPXAlIAx286hom+kjvNzIwrWJlfOmLKZUpxJgdGcVk3y3cFB5Tabe8Os/Z0xc/jKstGN0LOJjNKz5Ryv90" ..
	"X8bmFZibYgIRhIlOMHtE8Awg9oAG6kNouv9/+Sz3pODCRqJa/FHCKpeOT7yjR2EIusIGOMOG84NPDqnhJTzNyH5O7IsMleHtCIB7" ..
	"GDLc6WvGCfc1QPC8SdypjbSpuPVEsI57M2AIDWOSQ+BiPpiWb7cu83DQnXRcgKWySvt4A3ncFll0V+bfpLMOo6A/6n2Ctmk5NTa6" ..
	"FDU7IWMi/hTIyq+IWNy0rjF5FXd0tAed2lvNvl4+WPKGarLEkGMAJcsXkMmZ0vz5T+IkrJ2f5+upMBcseT841/+bIjvxNzYNy22x" ..
	"rQI+9tQeb49I9surMpl7r890FYv/VPWozHFHJLbaDpXUjw4E/W1YXllntBUri8xnk2B/bBR9txd1lgGn0smxeExaZ/55xpKV7yuT" ..
	"OoocZYSGQ2j4oT8GVLkOgmDPWhq5PDJjXOGKLoHPaiFz5a6gv2ZHCk7r/kCpYA5N58mn4XUdNS9jPxZBs0VLKmnlFvx73oQrHLc6" ..
	"WdXOiEl9ZOLFP8O6V+H17sJ5sB3uAdzB9uWAkc07O1VEctxI8yD+rVePLZnrmIxAxvUiFGefOOOVwFOD5HtMYJr1WCcSvb1dIL22" ..
	"r5el6i0j6Teeq7PlG3pJZOum1HkGPQEpFoRZ1o4ccbb3GoRnxBKuMtswW1RNjw/n+TjdWZEnS414qCbbuVn6PPETyfC/4XqryiDK" ..
	"zSYkZyDlb+25HpHDUU0bfykSRFCHE6TZUml5q14S0ihsaYzZ1aeA4hDg+s5KLHl4Pwl76cV81lJRRYsMcO13zSXu3G42JMSYxcwi" ..
	"oH7BnLNnedFcP18JvSqb2JSHCinjrkUakCeBI2+MhCU+5qswtTlhpRLxb/RJ3Ns8oUIcDlm6X8SvzroX00HUhetGrGl2Lt4nlwsg" ..
	"jd1VVYDybYv6EXFUU6VyYqTeN36/oHHrluDAsTzCNs3UzmPFFmHQRdUmQ3dyINBJy/rxTBNy2WB1/QNms6QL+l0mRAWP6moJv5np" ..
	"yqCDd091HPb5B2TUkY+vgfzBK6oXy2mqdeIhRbDIb84rPmcC5svPbNwjYl1aa5s73Bj7hyMgpeHAQHP6V8Q9wigV9BRVSwMkZPtz" ..
	"AHf4i/IT9/pl/WOKqPUvFo3pwRIgBR3i9o/E2oa1ElJt0VoxtNO/f6RFOC9Y4j/6E4iKgfETl5pkZs42TC/ihVsJpCLCc+L+qvrc" ..
	"2R0YOAvum2972domH1xIbVjINLWYis3xIK8Jiwac+I/Y6mYpAB03HTTl4umy6RLcyEGIk/+B8tXGVTRv3neWe9uz6l9RbhQ0xrMn" ..
	"kxI+I4rXsHurW3PH4qSTk1M+eYtsg9ssqteZ/Nk1OetqLINQknRxCYu/Hp3Zjz7Z20S1Ghyy4E25lYvyKaM6wAz8bXHbx+NzXcYn" ..
	"/ivK723lhtXm+ccvoVaGnMEI0T3VTT7scdspjX7jAw6e6GV+P4snttJCrFplQHITIcqVS5GaFpomy5cwi+d+y3tc/WFa6NC4D/7j" ..
	"mWtqUZAFgWFlb4C42PUsBpKOl8bNl/IPVMy6aBg6TK393vF/MRV5Dyh/0drR0sZ8LaSkW6gubnyIGATqZIFFH/9EYZVUGRjrQgAO" ..
	"8aj71gGR7yT1ec9aLtfAE5LN0UqRgn2+nJGvtyoUdEeYO9e2p5Iq9Z2or5DjXCcfQHRTZC0CpWNOsvThX9O5OUaEFHE6ki7vWM7N" ..
	"typQJN7ae0wW3aoGh21QLFilf2+4JPqgfIR9fTpffh493gYt9rMDcw8fKKQXTZwS2nyyX2ipY+AvtEgsWzLwBa8ZUfyz/MW4iYuS" ..
	"aH9VGbJeU7UVNZQbyvVJmlGtVJeUA/aSTTZ6FPZqFI8wDcPEOn0Mezz8XlYyDQ/5JOP7/HEQV0qcK9VCODgrCKPSi4io+IRLX/oN" ..
	"vHJJQ7XxVA5OalFsktICC4L9398sRtVYMbkg7zMpIBUEWFxYAkvD0C07ZEzGYVtM1QFhcQDRNjGkk/q+rZXYuEmJZJvFwsglhwp1" ..
	"FXaRudUkDMjHFIeCApmaASTzWR+iShNlznMYsUrrYbzvka0DUlStd76YwAaAbKOKgtiGfUaTcPMgDyQdb1+AAisURVozBvgGXKi5" ..
	"GCGTYIExqxr9e71VQIxP9SZ/5tPyAnHoYJWg+wiKbE/Fze3tis/bDn54wIBePL/jYxksprmOWrF20gkZVz2wMI4VZXJVwmJt7ZZc" ..
	"/oi6XVa0oDNuf3de6K7eYmrGQ/S2krjfj1ufPtju2WygjJytAD3FEJ99jLzFFbleiLPnIJ9a+X/5fKnJxN33KmpZhs5iZDEURpC2" ..
	""
local PAYLOAD_P6 =
	"/DSEdv7MFBRnRtHtWhEVGGTIuQMvhq/IFFAlH8eWUBx0Yh6fURQisa4I/wWHLhWfIs737w26uPXVD3f1XUpAZIi9MTX3WmL54cgq" ..
	"AUvAnjftRf+A5A70I/Z4+7ewsQSHcd6LsTUIFF+/+v6/a3MstDN5udSZpK2Rx4ZL4trO574uDhUlB+GbJPzr4PpBX4SWmWLdOXGl" ..
	"E24MC6pzGx6gbTH4w0+1V23fDEwKOJtW20gOqk9hRHrYkRyoAuNF3dqfGncZ/D2VNGXEvs+ehhp983c3cClo6n4J3UrRHubU1NOF" ..
	"r8T0uEGgZwuzYec5UssPVbYQ3k9kuatKawEApS5iIU2Hbogm2z4RxpRjs+4r70YjX5nbBMdbeQ9TBnQG7ZS3zkESz4ZWD+X0KQih" ..
	"vj3zK28znDluaeSeeTIjhzoK5ByF4BeSamzZ5t02OeRfltAESTfnfSsTXPtepihR9YFbOB3YvohdV/M+HVL6cocgmlMsGXKjAY0F" ..
	"+nKxwiMhww5NfG1Sf/POb4/nowfQL/+bgbUOiwQ0uC1YcTzpHEx4ZA3583L0Yyrt0KcCx5qbzXWVuQMuFsI9BBSAZF06rBD3LQdt" ..
	"PCTl2O22JG/FKjymTlRXlJu3dOaxsCOPwOzivrbvzHSV6NNkKVg1qzYIVr6s+cFxm5zYd7B8/p21uwEKjM6zM6IG0JkZ/sTRjlxC" ..
	"UJNYNk6R7NCqBYXywKfuRBqC3b4QVH5hLbkRY8y4RIWr1VuylZrNOQquStcheMu2auyW6YdlZmU2PWuhfBaPlM61MaG1+yWRvpQp" ..
	"YyRgBjALT3F6FPVTJ03Mamiusqzf5M5PgP8pLn4qYNpbf/YSzDAFMjkm8Af3M3gUqArZbGmJGnbggrAfuugr4gopq3wm37c7KLjE" ..
	"/WaCPmep/Tr8fFtNBWBjLF07wi8cfpWGYo7f/1ALfF6fBmaIPoHjUmxxQ5EKxqtrRCQikk7XtvKRSGaZbDgHU5S9sptG06iJErWt" ..
	"JQLTdgmHUm1JWN+tWJRqb2XgiOzwMRQIlpuw5M2pgMdnF4AeNo68BzSI2r0twbFZs3i0HYeJRTGDooBxLg48vD2Z05pvw30svW/t" ..
	"/rQDZOKRgpTzOHnAkNa8duHM8j6qS7hI8sqsR1Bg6ooBKVh0JhhA2ypDtfnKN4ZZwMWAAP7socpaiUFxs0MlNr+A65kBes1YSaJU" ..
	"O6ybPY5+mQYc7CGHuIxbNLpltp4DpEm4YR659iA/aqQfT++uXQ/AKmjmI6U0mRWBGy9St4qv7WFSeVJaMCnNSA69JNVwMR3woJpW" ..
	"o/z+gJwZqJpfmz+VY6F+Vg/Q8vlPMg/0aAm0ftMp41I4Ur2tswLReXka+vyN8zMcbZQXpRaea49QqL06drxm/WP5CKy/tCkDmrDA" ..
	"NkkhgrZZ0DxRK1hpH4y9Sg307IeaZ9EBMiQvofkBB6xkCBTKsjWpM9mXQDGtJNB2Fea0vroxKkjnXtjG7BjWheXWJ/VS3hgLe7sB" ..
	"qgW1yLa8bYUq4S7iHGtnMcnvZdPTcgpXtfefmbB7foCVL1vEaNHKwcXWjHJkzNz15Y25t06k2kd/iDKDZ8vXu7IRdSzswqvhkWFL" ..
	"BaCTVCTaPaiult1qRvtxD+TptVlMJXXhmClSW4V2lmH86Nv7+YY6xHEb0B5wWVWfwp8cYgyTj0v6q5LRpmB0owXL1NNrzzOqDPXM" ..
	"jegjk210XTpsew8Rr45OKCQlAmX5b6fyKTNTAipKq/tuqb6tT4T+LaLCqM13kfvD26Ug0wjQvuPuyOu9lz5qLSCyLPSmbOTFeBxV" ..
	"rsCpgiFACvRcSYNolH3dW6cx+iq24HoQaOYX9MCYISyUChoip1yrXcicnJxcS969thcYfbQaJ+UZiGQINJBi3mpP/wnDGCV30LNf" ..
	"kd7aMb+N3xNyZw0K7JWTF53DRn6m2ryUy7OKYqMEFzb7UWmq0JK05+R7tsquIzHaxJx1Xyig0l2EMWQIq+VaG+w0PckuuYyyt8gV" ..
	"+fNApDUX2WK+e1NVDy8TZ+nJOF5yS5M5oUZZf0pZNTyD6Mj1o01Yn+/nCJ+UhR+PhtAq5obXKMeJIHRJSAIwcaJdSiFaMpZn2L1e" ..
	"uHaMHuJX8FNkqK5xrFEsbaA5Ielu/PUF/6WfjRjevPa8dhxAn6cM9t+gIc+40H0ENqey1BzZbhu30bM1s1dixhU8sxquUt/wzKbQ" ..
	"fZzCuG0/VZtcbLHx7b3fGS7MR7DLlsnjpPnXH/g3JVzC2GA5OaK9E+caj5WAdR8IXw6k7d15Ug8rsIG+G3mo6petB41FPCGcJgNw" ..
	"3ncv7n/VRjYeT1PBCGzAr1COY/vVbm6SQhWbHCbexd86qKsTFO9XuuzAPaL1npGLgBDmGW0kVIvbMAuwlZ7yqlnr0OcOg91SIK3n" ..
	"jaGkFeLTL9rhaRNTb/N1SSF4NtFX9wFBxNJ2T54us/SmIDQ4BHzAWbqRAqBwOp0csbCZqriR1a7Al7DOnRCZActYvg6JgQhvuRbC" ..
	"DF3gE3WU+D6Q2EN32BW0E4eUOmqgYn2O1Gi5Bo8/q7vdBExPJwlpDwA9i8LjQ3LF2LRtynF3Q5eNcbAFWv0IEUYywidtjLW/ad/6" ..
	"C8Fbs1C8b2C0+kRIxASOR47ImiTRnKm/cDUOG8kq3V4uG7rgXs1QBUnv6xRfHFMjRvOX05n9k0jEKicy7o5I6jsCHkJT4pJSJcIg" ..
	"xCxXbfiJAWEc5vtWiWZlkL3gwGtp9HTAXgGFq+Kv7wxW0xMZj7Yx/yn1cpxxaj0Gob9crNArJr+URYy66RtK0mHSVawsj89PnU4A" ..
	"KkC+Hqaq6RtbZvmIImTF+6VrmVd0keO2a0eNN3OrcSaXxqV+95LYuaUEy/iCjQsDEThwhqXKunZVragYOTWK2uNDn5xKLNcHqZm1" ..
	"XTWTEa8B1GdeDbOLPCG/4RkCBVvheAkqvTEzbM67MmPhiFq3E7QvjvfKlbLik8Ssd+ugWDM4tFYiK0MQgXMoJ+76u1BmdCBFG1Mb" ..
	"H4MhGFFolFYM86tGDrDbxIFBkhSdPxMITG/USrsX/Lfv2Hhhratc7d0UPFzRLXcAceMOh54YTEVrMr+Q9ORhdLZHi2e6PormZUg8" ..
	"remJ1lcmB7RMLZZcxxrXKKqAdXht+7tR01tF6I5sCYAfWLQGe7Biy7WJIr50ugXjnkg67bq7S0PYet3f4O2RsuwM+QcaeWok82ND" ..
	"SYk2EfsAQ+wtgCTpd4tilbDRJEhZaFp20qA7MIi/OP2KS6yQJtWfCwKNM//DkmkuK46xogSUpepvTxKEOeusd5tohHBA+c4K/Atv" ..
	"97H1PtR+QqyNqtkvBOKDKnHAAhBnrZdItT5A6be0QDeQlc7ec/iixP68/2bh2dnH+C1Ip3Q/sBxkjgHWLtVJPHW/uSO7wrNqeiwo" ..
	"bn0MfbzaIvLibLuD8XRhhaIhko5Qnr4YYzy8CaCM0axNMRZLEY4KC5IBl0+YruJNnYU1IzlcN/VsLcOggKKBwAomIKGnI2KKNiTV" ..
	"DVLUKnHmSkfCWCf/py8Uh45A7yNdlP4hn21ssWGbHO2n7zatNgmhjwb4rgZyibXD7lMooZHdnu+07RMwrESRfi63JPJYx4VOhCa+" ..
	"EtAwUwPFUOOLtB3YSzw1hElkgcUEPrPZynrSBqoZeYwjDNWmnNgYpumFPX+NuKTTELZf6+rxdYq/2xI6zIapCKrmo1yApadp3Kld" ..
	"vxnzV40KziIOZF09Rydh/YhLbzapL9gkAfBazhaqT2i9PkNm9KFri674zydA2usrEls5BtymgXUf0UofUXLS+BfswbgdbldMv+gc" ..
	"EfyprlOTdn/nYUZKMvQZfcgBWdWqBM0DuolXjB4FdifioipPuqq0GsaneFJOpM8AXQyvnZDL/IbQc6F/iYdXmBgkLaZ3ETdbm6q0" ..
	"+Zm61HChAPH7EuLy7X3zQCFT45W5uRTAlHMIOO9Y1NNOw97UU5bEBWqzae17RTNzCGZuWUjCk9o7ge1RBd+jJ9mQq+IXHMssn5jA" ..
	"SCmXI5cwLyrRv8QB7g7Npapwd2NrliM1j0nOUJ3e/AptVkQXcZbS7cm4ATebZu6KgIVg1JJmtV9Ycg/kApHPwKZCdJMKv7BfYcRn" ..
	"FRAXFqt7LNeCO7Ngmv/ifKt59xsP+DmYTF/h+mpb292qx0NGKuCmOI76/FHeDuFd6V0ldPq66gUvzFaBcHv3GBMmjvxLtybmudub" ..
	"oGt1e36rlRH9sy/Jg5BBfUYFMLJaRU/ytKKtgwUhI4psv0YTv8qBuLaZ4ziEk+Lnw22RCX7nr98NF7dCAHax0mkz+my0i30bh0tc" ..
	"+wiaTd7LMuwpaAInPr3p1WcCcR4yZO8rN7XrW+btMe29hzrwH+y7eRYONiKXW4ftKBfSpexLV+nVPxstIIQGWZud02wUSFqxtaSS" ..
	"mOpjmxF/1dyWQ0zjdeyZO9vcZcX+Lz8uW0tKDUmtekd97H6NeBVU7SOu2Ulvnr+6wV+UlKAqlaC2QvWVpBsWUiWtgvey7zN0MxB4" ..
	"plmWmCDIcNYPhc2FlCI4jwOW4G15HFWQXnihczpk+qWvWFJczmA3NMNc4GNc4uNYqyriUUsrVi7sqpO5ZqHrYZ6YKmM0LDYaGDfm" ..
	"ha+TMNdEXtQUQpF97dW6ExVXzIhkUNWSt6gaF0mSAMI/fwHWzQsw3JBoYuoJBeEJomDs/lQpTRaoEAzY70riXOpvSv1sAT/0TLYR" ..
	"RGiFQDb0eUa64OuXWpwfbRCQG7x4/QPVAbThdgk0X6ct1P1oQbwztS0DBd8W4aC51rIYjKGyt/dRyG8ywK18QF8njtkWBOjdsEO8" ..
	"OyCios272KmYhEiQ4WmtkYQxR4AUo1owEYGZmY0kc1ugUusjSxTI8R34iHqJZt+XowEsWGAaVBNc05R1hPcUPF/7pUE2xY3ssJ7L" ..
	"KF+llHzgYQdkZaleBybahzmqA8WIHeIQdicXZLOmI0iP9bMNnpsCY6nmYNmhQ+hGqJV0/13M0vZ90T4FjlDcW1y1xmgphma4nzTT" ..
	"50Rx3HHwEfs4K/v6orbpy2qeGSj5o9rSqp8EmE1YHOZvQRka3jESg9cbUVa8GAF9OdsPPg1xJDw8MGXf1/+kCeLXRl/fHina6wte" ..
	"hRTNY7DPzsvdw5P4S7Qx/DgpMJa5osJPZ6MCq8hx4b6rt7Y1/ENlma+RnjrFyQaDe75BBI50uOQVzoHfS+ad9OZ14eJhyMiGN0uv" ..
	"OLeKO3XC6MNgDzxnYPlPyDCUKnIsIrvv7YrwSD/QzvEizUXPLUmgN5O+ZsC9PJOjsS+bXu2UDB0uAnCL4kQc65dt6KG4LLJ7ATJE" ..
	"pf41NWn1KJqnkNkkC61Qezd7+KgogVULE8E5t3+StC+KLBpIB70JbFDyTnSpZxQBUgMcpSGvwpGIkBBskMGEwc/LtlD5tQW+TOEH" ..
	"HWmvtQ+je1gpYFXzWBgloxrGcSfADnPG8KTOnwjA/IKeVPki+es4ggAKuZ6k8baRyC5lucCpxDoRrljm/SRrRDDXMVAOgEDMm6EQ" ..
	"xv4ncLxEz/RWs9Q8D6fh7WVP2OEmupHV9cTqBBaGWdG+OapdRO7CvKhqj6wdtuxPniu8R8cr3I2ccRGObSrBC8oS1ce+f6On3s0P" ..
	"/ekQD+6Sq/lbTXnnF9bDOp3+kvcbm/8lsQYjDi4au1tDNsOZ4bMGqxQECGYX6Xy2ABOoA76hv9z86qusFchKrUlPh/mRZ3kv+I8U" ..
	"+oFPmJpTchR+oaUxT+PbH8uNSPm8wj1ESG38SIM6O3/IPWA5oGOYbwERbpBm6dYToISw4pUFs85RnSCpUkgi+BOkYeLWzz95gB1H" ..
	"SZdjwHhCfQd7if6zVVcZlrwsnvCgyOS8uFJhTzwJQpBE3cV6y0njbGknKdhygrYGkhrauuPl5A55wLcnqLhqRen6hFrrx5vRQkuN" ..
	"rXTG7kO8S4alm/rwc3Dn0zw0HRmH0aSZXzdglu8hdsI6WIE3KSzb6mOIDFzQukLsiELaKPSJ0gXoimoftOsHiCXM6JITaKRyQC40" ..
	""
local PAYLOAD_P7 =
	"/RpnipDBBcuEnZ5mgV2XUHBhU045/qyxsp8Von4EU5JxyLkjzBNvj34WvgZi3GZSRs6tMZXD+PjQvCLUCyk000kp5SFEuj2u89lL" ..
	"Q8t4eZTaCr7H0eyD+YguRsrThogz6DpYq8XKOLE8+r1DjQJn6tM7Neq2mYzzi7rupUBssD5VZLWjV0vAQvSrlnmkxQJGIfVOycZf" ..
	"MAqWLEGKL1K/+r2GwSFugeXwVcQnt0daiuPDWp6WFEsOUGQXr2SVQDHmjWg7J+aEIARLjm1kKrpNAMpvv9ivSAa9ZlQ9vfB+KGoi" ..
	"+DQi0LjZHpHRQbv6QTcfdc91TC53Vxs4YnWOYkHttwE8snZsCBa2q0NgH/yDycqnn7/15n105zgoaS3bmVa3zOBF859TnDvwx0iy" ..
	"nhtM6uGjGVENhEuZJUtSIafuWNRVC1jz6vitiwkrx/pxAmM6lgGpPF+kQvPL3dGC7AbYItSZktxDQQwi8w4KoL00ma5f+PoGiryW" ..
	"nZMDVY4i7MP0hCJ98NcB522B/MXDUOecILTs0cxwwrNh9FTCtXsR9yhjVKCvMmDhi0UpQC/sR9Hou7lyRt0cGke7XqPVzvFAFepu" ..
	"TNLRfMVuTh3xK562SWvCOnHO1qinzLensHJYh4JygDop7ZHQXM/f2L1SCbSsqsh7P2pWYfqUD1dNzjzSR6tt1mA/iG+upBfawg1w" ..
	"vJtXv0G+KSRCacI2tuELacujhm7Vf+YAeB2A40FcqEpweCJUdW8FwDdbUnHsEtr0/hHPh4r7C6jhk3O6253ImQf2gDRsZzK5DgK9" ..
	"SwjGX9lvy4F4FudxxnF9OLBsXzwReld3a/rcSU6+VVyu4SamnHREWP9IUj3SZy/K5Gs5CAnwABwkuCa+fJBTV+BYgK6GqvcwZr0o" ..
	"3+GfOOFiRVGAbHcklorI033+LbPmqXg3sz3ZkN2YcA2q2EGAytq7f0wgr7FCFkhN3flXQq+va7P6wInpMdZt5P6ZzoqNUqrTAMrB" ..
	"nwl6UD+Fl25DDxcYJg7pJGGgNGS2bFfrtxNpMec87azSV47w3x1Lo+/7eAgpbdizkZ3r4gVzPAYo5kLyeVhB776FpWVKn5s4rhGz" ..
	"QIw4j3UqMSu0ChU+O3TuNqgbwD7vSt+s2PEHESW4dV+1iaZZ1AUTOqyISBx0d/g4aCOkG7mfK/F+lhLITt1iiqgpN64LDobPtuaI" ..
	"9UUVyNkKqysXFeqRNer96a68lkPQsvS2vmE0HxQXtCJmSemLnx8iWQfVOkEwdmY4lq8Iut0mSL+9kj6UiQwGKtSiXoCkaq5wW/pK" ..
	"lMVQ6SrtZys/RNmYEaCxcilh137fAaGfoEfjZgFuiAMpzd6+v7jHiH2vqsHiXR0T0+4hJFec35H6x9RiBzNOp3EXtRnJ8/+h33K9" ..
	"xhHwyC7LdtWtcgEEWyLr5L/XvCRYRMv28EVucZDdyaaz6GpAWN7Shoerb35DK41hVx3yQF6/pZIDVGTtxRKkzgfXA854YV+QEXp0" ..
	"qHYjXQiGhOzcD865R03Lcs9GuHSBMO1h47gT0yD7oxacS/Nw25bxC2LY9nus/7VX99Xy2Q90zuDvGtVQ9qFCtauye5JDn5Y3orjS" ..
	"Ho3fNuVcXvAGtYrvqMCaJTWmBlhF+anqthwpUHCtO0B9iwG6j9tyqPtut68L0Il3zuE79r9K9VY+feYV8DlxDVGp7TP+6DJ7WRZ9" ..
	"wQkKx5tm1aInevOhLTePHW7JhVUrvrTiPpD5uREoepJGmNhGlUEGE7MHSoRHjakPBg4d0qkdgdiGravCP2nWat01wCeO8gAmnLHD" ..
	"GQ7uq/lqQ7tjZzxBdfMhhtdP7HV8TMYK+YUOFBtbmxLZT+SmySy+bXad8HARXdTiPbFibBqe0RNvsi2d+JbZdJ9jRaQygCO510EF" ..
	"15MnDGuXjzyGlehsn+uIQ+4bTf/WyYp/DWjYdYnp750COC8DSUKJNnAcX98CinQWz1lIlEIukcDb3GxU1naplNd2ettkoJXtyej6" ..
	"xWf93vga1QZ9WyJSL81XFJedfOR+w9WbF0OFP57VUZKedLTPayhmNh5Sp3aondeXocNUqhyKGfynQL9WNrwSTynkHUtknEKt2au/" ..
	"qNm/PuGwfQjPQMQnBwUZ49x2+QGzPvKWlQkR4yougx5R+HXfaJmpAHM2gzpECwGlBiiQgwLx83a67jkY01gy94nt6ICwh/zC4VQ2" ..
	"W43dP3p+o/l4GH+K0iDn2gHBrUhMQn6BTW70s2ct2cP4AnBRWQRtj7BdkFPWbXD8BP0CLqv0HqU5g+J5h4KJB9/tiJg4GYytkHbc" ..
	"PdyYPk/Q7ruaD5Z+lqHUQJwWlFwfddDJ2HhMxfxF3uTRSMXZd8L05wAduzcSc92Vh/UE5qpBYc6XpibbG2Jy5qhRPOTqrr28ymOi" ..
	"nqkyTLpoQFv+JZHzAxOMJsZWzeIHuw+RckvHCZuWWWO6DQy4cojdf2T5woKpsXEvxkzHARCz8KBmHYHudKoiJ5uFtLQrpxoE+Wh8" ..
	"RGcoGUscTzJnM2annqBmezRABuyps1JQOV2J3gmImUYm3DzZKD3gyfRUBc4uDVG4LQqx+QAYICM5hTP8n4e3kGw4ZDL9rFVXVM49" ..
	"bsrH/gm8mnKwoj/lPQXTM6ntPy2HeVG+qt3I2IN4os70t4bsyGab9+MoVGWOLcx5QY67UKdUsTUJEpBtsYFok2QrW8LvPazpRGdb" ..
	"3iwBxorZ7iSE6yVqjcwb73UBQjRfadolzEGUUi1bCeh8bVSGZkfiJ9R3MxfRm0TW926/Vgjd878uMWAx7gawhh+05GvgNrCvKvtm" ..
	"lWO91nL7vexdcCXtdvR6IXzdP6ZEotCPmb19OSp061WVMpUoy+LKeRPRVuX9A7A8e5bScCPLvcY4obc/vnaTbqOvW4NusF33qjef" ..
	"+8vVZtxIaFwLygWYsrGgHagyCMAMnVuRUDKS6WjMv/3sLE9ilJLe465pCyUaaO6j9KdAeR236FKMfNqwkqrLr0HMzRh78yVtm6qE" ..
	"J8vuIsIzoNfDiTFykkT0CUkxKysBEvCSDnyKqSD3/NInYj5dkR7+r4iiLU+7KIx2X62BPcknYbohnVh6ftH55aSU6W1I7UBzLyct" ..
	"mYQS3GnA8j9C8X43VCUiX4hkaSY/0k8eOdaeCbmShx/HZpmFKrRJn2Wl92vpdtoMQeUgx58o8STYSEpbVYOzuyWA0b9BDta7W05B" ..
	"6uQFqhcSnPiWITYEYpFGCe9xCnzSq0AwjJJqRezz9wsEgHUTYfu5nBpcMa8/Gnr8rQ+kSrQWeAp9kX7A4xTLGHx70RI2KMWuvvDg" ..
	"n+h31YU6EmYuGLpYWc0QChYTpSofxDsBT5/a4Z/hca3lIvftAnBDI76AH0DjPSfNXMUcd07AArgw+9VaQNKV3N40xla75xSKdzJ9" ..
	"96Q6ptEQQ1ys+2Tzeg/qOzCT6T68/vzZ/DiGKRmG0rj2iNGbdZTdVc3UfX1NL+Jl39+9wc9ktfK4XQsniZyc4VlqE1uW9S5tysqs" ..
	"EiHhSG5IlUaqm+MnDMYi1XHFKq792QLBmGyUBrJc5D6b+6hEBfTWx763pjXN2RegPrdXdTaMPXDJT8s91y5yaFGOOaEzsjh6WI2g" ..
	"wwG3toqKJmPkaTz4T1Qd/6cD9CLHIExM41RW2ZGriyhhdqI9nloOdx7uFb5NEGtDV1Bj/Xw/cJ5SY3uP50GmonXdUFHc9hcG0uVt" ..
	"6uNPS8b9Hl93pm0iK5SV3UMfDyNkD6PSIK8wO23iWlpfGBp2cF8otKcIvZHiBEfaKwLdswBmS0gIbx2xrpeekvWr4AqseYRF18Bk" ..
	"3kd3eDYd+HQ4Aw+dRLxjiaTtLX+CA+J5vV2IgAQ/sKpIbVo1g4DReSUfrcpZMJ0kNkIExnebsP1lCcNbAaOoLjMe/u5trn7n2HlM" ..
	"OC8ByrH+z5a3la8eUk0AwfRi89RehqydiKXJ3uJEYtdZOwqa5tZU+q4GGQ+kzDWE9Cvi7vJ7gBk8U1V3vZgDCFvLrsqGCkRkzruo" ..
	"smMaAGN2RSV5uoq1q3X+p5sfQeCtcTO9kFscd8+KxaiY6pqtDNQ3x6azUvTqKGdibNPeKQJhjGhDlqvmMjVwSGafCo0dTraOd7yt" ..
	"x4c2Q5cABVpYXkFLmU0iKhUK601K4yZmFU8o+kvSsACY2smPnhwiKQoP8NRFQgZDwmIM3upl3TJZjrSqPSFU66B1fsHsVFWzQX9I" ..
	"W0XtCc4Mhe8VSjhwyAAmuj6UTys1BYkqKDRVlQNM/qeI/Jb1TsVfqOyRoEwQt/Bur0F1ixmT8vNdn2SJRZ7N0J3X+LzUADiQhPcB" ..
	"ytW+KUqtCAjqGUHxvIZPvZIojNnsgb2Bx4e8xMg/k60ZBoF9DTNCz3GdIrxLtnOzrIVhMIVhgbZs8v7+C4YNpqb2ODG2FEvdaGcQ" ..
	"k8eFjAPAyIgG0dOVMOp4cowYkg6cooI8iClGf/fINfZgPn2STtU2mJrRYoRyGIFuu87oIf35JsxAlNWIDLwYY02i7Og18lpLdxV8" ..
	"MF/5xfdkM50UVq+N2nAq05ulwYYCV7Rcm8Sr5XrddxVhmWY9pzdunUMt/ogpCk6d3pNjjc5Y/J+oQpl9760cYTJ0/Isp3rcTU09s" ..
	"TzkTO7CiuU3alSbvKDbB7246EXCD+eIKSMRT0j4XZl9vANlWGRombunFSJtn7sj48um3uyhGabTyUn93jRUS+0Uj/pD1tfhpxGyV" ..
	"YwH3dqxgEGL/zKgv4liyKTYIyl5yjZVbMZ/UYKU+vj8JBU2CKUZpjROYDGTX8e3GYTGX8WLSPjrUu5zIUvHMLU+8G2xGnpjE2TIH" ..
	"DwyHtTgykrrEO3OQEEz9RUAct27Fuo9Vu6u4RDtOGBe3+nlLtIgCAtmXALaCngeK0H93zotVH2JYlW+I1gNpWIbJkK9K3O77BRHt" ..
	"rAe3UbNmyA/F1LmO329vh7ZeEer6pNhNTiqDMS7aY+xrV9hCAi7quGrOsBVdSKn34B7g8aDljbDz5qJ1taMAOfIh9ILUXv+pv7X8" ..
	"tA4rALET0bVGDq5ZIj9tpXwTTTPjxKmxtWErScXJEVWHPBi3UBMqmnODfSb6uyxQctssZrRkRqvy2J39mgI/iydRmZEzibeXIVT9" ..
	"YQy2GteNf0Fwza6XNpJCHvHhCiSEdNS3ncxmQyDfZU/RIJBlyoQsy+pt3i09B+C5Vh7pPwBsVAeDZSZBkF9HPHBgYyNnz0vLx2yQ" ..
	"0ZbfUCzH5zJC6+RGi0BVTlHQL64YtsuM+mQ6R/4n7B005WrxXvvuWFjTmasa6m6k//iOmHpaY2Qyh8BSFKjCPWZHJQeJ0g1yC/3Y" ..
	"i5x1yhLSr3pipnhAMEem4l07fohby8s4B0SDsSKMi6izvioUZ0Pfw+4tztAt+4y5T45x2gx6HA2VAKjyk6tH6kMEuMK5SALmA/8x" ..
	"KZWUmCWYKmBlDRikiTT2b8qkmDAPuizHy3YMin9hdCNqEXpPfz4zPxb4KPgKjwrycaRZNIe1QYhxylfEcBpEZDaUbWpi13ds71AT" ..
	"mKG9yq7P9rdmCj8P6VcbC7rIwVjXIQSRQNxQHU3OALHWg5BdAlbL7kyddjEFQ48vlUWkq2z+q9lnlc06qKhevbDPWoViceSDiAFo" ..
	"E7QoGuU0SlGoZrW1emOGVYki+j3S1Sc2RAznUPiUyugJFNH6WQSpHI76a+IfGOSO1YLbD0818sFx9bcGvqqjLCM6mkoKM46tu2Hd" ..
	"4nEbsj/mlfUFapYwQfPvIPDint737eUCHuEWzoafOJQTJQxohx3edIx8dAeRQ7q25SYZFmqmqSYA+z0LXD5xTgwKYrohveRpBdIk" ..
	"hGjPetGuzMjVOH4IX3iN8RFg4RtGRXlLbwmdXCBCxAj/mmbUS4nFdodzlorrxNJ4tcs2eUgoFJfAi2evPwOu63H8ToF3HfOm+vkm" ..
	"IBHznyXMlAjVNXhqf7Mu1kZRzKxSI/wJU99uTRysJuS/NHh9S94hMQkUolauVw9Pnuy8peXeD9JcxZ5ultZRyDJS71M9GQ2kM6a1" ..
	""
local PAYLOAD_P8 =
	"Il88+WuGcH/WpZMr6bMQwWD+xsmn3WQk/9ltyjrt70WSW7lDlM340PzJiW3NNVF/xSB5OiKzWwKABXhKT0bru18dG0lYa3Yq7dzC" ..
	"MT8hxuHGn9jgCdAVsWBgHZ+kZdTy3s7nzrzJPXn6OBRZS5OH23VDApvEjFgwTCOU82dOmqiFyNHB7nd1ytZtSZrjIMyjktw6AAyg" ..
	"snKpoCu4Ybq0CjPMq0f4LZnihJCCeT5E7hvL8sr8yzGZy30OQkIHjP+UTZ1xWMM9l/e8t2oIzzgbVGSvF7tBql+AGkpXEjPIyNAn" ..
	"TcbaT1MvMlALKQm3G9aCBOiyc7TbyeZ7Qjb8MMasqVeSfXp+ABeYGh0d6wKDY/Jex0BQyjMBre861w8PXfA6gXEPLY684VOVvl5T" ..
	"m86G44ul/hMwlFm9IUwSnSHzF7MUYtM0ldwwRAVjGLlxf4HCqgU/09nZRzGlRIGrSIYRPcSZf9cVogKNacPS/3A5ZNwcJosuq1n0" ..
	"SQGcT9QAnqacmPqi31GfMHUeUmilnpycwRLUJXWH3iHYhuLQJ9Oq7Td2UQ+J2lAsYNqmogTEnkK6W8i4DxCD5ycSlJxYtmqTHb+f" ..
	"OILCseMbfDV4Trh/drPH65wsUZYQGFQb6InzpOZmTJv80NZZOuiH8IzNSJTMYwy4e3fo7Lnq+tiT+Mb4/vHjbDlRQCCWmH8zemae" ..
	"0LSIQHHXN/CvULt2MTfyAUsPysvaltQp6ohMsTAKuIIcZGSohuj7Ke5gkWyv00Lk0/f5aNwpVJ1PUKvOL5RZUMvWyT/xS71iHWly" ..
	"9KnkZ3I4nhtGyLUIR7Q06IQzqyjwi46DvHRQ0fxuKFr1In2n30nm4jGy7ZJz2rNAQOA5B6Im1F+fgxxTU64QGlJuP2UAXFfIh/FV" ..
	"xsVCy2YEtHCG/fj3tPJIt5afrhaLBJxmRPNh5bm5zwydwT625wA1C66MbZxFaVXJ2G07wNrwTx4K0p+YGiEX1Ae4fUsfWPgk9nav" ..
	"siVHqYmfUgA1NV/8b2L6P/tHyvQbxo8TFRtlZ5gkNFkOylvZKH4tj9QE8Zs3EMzNEoGIGK9DVRm8j5w41m1wx5Qqf2DL08PF+qBP" ..
	"9gI6VjBRSB1VIWqGwA9BoyibSPEn31W1aUmvchznfKaRcCAhUiBY78GahG9eVYDK2jpfA29QKAmnuZgctOXqlYyGEK7fyzHpexlS" ..
	"igWiYy4voQnSefKy8czWhcPHdE72THMI23BSVcFDbYOtrsnAPMhfdQPHDt8vCvGk4PxQfk7woVQ2gTxncyn2dIPSMgBYmL5BzRVn" ..
	"wVduhqg4OT3D3wFxx01n3/RAVdSoVEO5dCyaDjzSuTLNaPXZuFXpIl8UP5XPbhKVorVqbBEKc2McunRnuEwNTDstAbEDdTD7mxvB" ..
	"erKCcSiZGGlDtHQr1BMhc21BlgIQ/noEYvV2o5b7I+WIqEw850F5OzXCkIY/9qbUMsn1HBKPW97UfCg38XuZ/+r2VHKPa2MRLPKW" ..
	"aCUUP+N43+jS/9W1ZZARp+tx2l6AJlmnhv3ANPro9RygSoG+nTytjFH+uzjgo5WZsevZSwOf4cJikf8zGpkEs4+BSe2P8hB17B4I" ..
	"DAsqlOymYT6tu/LYkAmY2/uRDUkwWPfsaM3NcvTbD3xqLDlY1ps4beOLtIHADLRh7SMxd2ajtOaH0HnWUMq1SZnC/uYFoBMaBlkw" ..
	"PVj5D14TpmMfpt9RAeDHCbDfFiKM3Eml5zCo2WM0tvmU2SrC3lKFjqtdo8TPOHlqxiW9T45UoIYs+mNPYF5ipiS5Xmb6QOYMv2F7" ..
	"BDdSUGVFqW6D1SczizB8slG3XTgd4EoaEyPYNSGebU31XMKMPXE+/Li1aHjTT1tgN5aoe0mMco2SiDo68Z1gHqRWhiSQl/HyD1f1" ..
	"/dLePzVo+2o8fTIuHROGkBe4/yBkcck3+L6EdfDjXofZJ7LS0GLIpob1CvuGyD5Hb7p4lAC9Jg/RjYvz9JC3H38sniuF2JLyEMC4" ..
	"8xS7x18JwTLjrRV6DLX1cavWrZn+PdHq48O6jz2RhGjyNkAXYWLfeK2NIyiGFnR4qfw9ER+iJzeZg3MU79q2nRxhXMYsmetyXu95" ..
	"e+VbaQWxPVY/k78QWEAZa3crFbrErL/H3iiCysBDezKiDiwwBSIIoXWjOHNIacFNvasR93BomCAUNlB1DJhDdsFmP882/F6BdTbg" ..
	"/E2GB+5UJX/UKqyFrhEGhsvMPjbZVSGhMCR6qa7N+R3Ep7FspuKSkyFsyOtVYr6IY5OXSGV4mKCN/QtZLs9c3njT+WQVBAiMqvX4" ..
	"o/KegrqDOknIkTqw21BPjGfWVi2i1Fg1rtfvnU8t89xZCVGKQz0KpasBjOsnktyod25I+4D7vNgjU6OjllK8Gbiq+7k4633MhnSu" ..
	"azGpPuxHS2e/oZw83dqGH6kBTNWtw+ga2KhVjhhHv+uHfrUoLgJNt9M2R/c8FfP2RZlN+hOKjp5UsbqQ/FLisGOcORKlwwvIpF87" ..
	"6Se7/eenWbxARjs3ecPFJJuOgL2Qtd+GMMXpENgAqgH54iTvXDfxQdyTzYA5ts3uD1jjLhq5b6nbGZ15SE4cNZf8IfHgQc0iMAxe" ..
	"sfKIGfiksjl1cIAoBzAeCHhTucGaRwhdTeTIZRyq+CTlPpqDIQj3dZfl7TZOQCx6Pgnkr+TULolVAGjJ8i75CqO1BsQuZqTqQgL6" ..
	"Twp8BKS1Dv6rX8bBKOxBi94j4wXWO6d4/ms4E/4uNvGTsuJzEaPgXtUg7cZZ62DyMLJINfH/qxxTMtsCY0L8f2UTkk5TuK5gTNMt" ..
	"4owMd35CrEaFdysjmtLWI3B3PirqFdHH72Yd00jR6zde+uAr6qJHOVGxTYaQ0lnmq9t1zzr6DyZFRf+5UDmNdtzrJEyoOGfboqhH" ..
	"mTDKUxp5QB3fgmIFMDriNUKWgjad/ozcFS4pPCFnJVAjeK7FfBffVe68wJWIY5zvrp7xuDG+p18Jkvk9JA83ehRTZuRwzqlf5GrI" ..
	"Har3NDaQRVfKa++J7LQGbcSMBSBcBnNtQtf7fbh8v9GFpNgxrHP4yZDgaRJP5PXT0ZT1IzgAN0lS1sTHrXpdnufdZYRt6BtPkn3U" ..
	"YsHN0GhNKb5RUDPiB6ewYolUme7aFC15Ub/fcOZMYJzlXypvny4S7dj9vyxmKLjPrPGY0VielFsa58dYcOmk9XY5DfnMolgBi0XL" ..
	"cQYRLV8+QV28pRwVDRkbqCwTX//AEZ/HUuUla440YRZpY9wzfKAU96k40M0QGlhXRcFwo4i91tjFCFzxCDXUrBgWu2B2UA1O7gE9" ..
	"ymNoWQjzYs9MHdG0OHzhbGwrITagS7DE/mOkMXLT4HujobP2UvTuvqXJ8MJ4BjKlAuzIYw/C2b8hxrsPLamuMKq9prcrNXcXUYJ2" ..
	"zqpkm6I1LpPf0BKkpaxu58UxQj/BuyN4lf7FALDwcmd1JhiQvfZr8Ro3YXwOc2EF2w/ddPfOcpRzYiYLXGrKHftyg9vrP4mP+GT9" ..
	"lYEQ1nHzOOvDYGnkIft3xL/wk0aVvQz2N6h3XYU8s5W9P6UZUsVLY7dJDVdrAxiBW4v1JI9O2HuOFbXVVhGk1Nrs77Uo247mxUme" ..
	"PDvT8IhK8nIvsyhp/XWCmLUUHI+4dMbtdw1MlsDLpusEgVEjTtY1SxCrgNR+2tQcEKyqXx9VgRgv8wdyk/UvHA41zVDBtcB7bCJG" ..
	"6nQ1AJqxoX0Qfg7gfiO3aO7AVwuR/YTHeYx3Q+uc//kHCO/es+XmlZUROmMJsxE1i1/IF365vPBHB4Hp1MJUb9mlPPtceckB2HBX" ..
	"BJZHIj6CCnlQisGDH5JESwLaCJXY0xk+RNqgKx0Ta2CR0k1JvrIywedMTxbR40jw7X0YhX9P+1nEwGyv0ujE0QlhDMO1c9kaYtvs" ..
	"fncxXUyRHkt6rP7d0xYB++Kec+UtMy0+NsIzO+/fCyrimcskOnCDsv6IqQA37m5Qp9j3e06o3CQyu0hZTbB0MjIJ3n0oUueFcv5e" ..
	"VD/77aqHQ0FZAhinD/t37f2nXy1JmByMiPif0oqdxRp8Hl2vgsiXjvJQSFE2/Ban8QS4BMn2KS+I8HprXbmSOPdDWbml+OwRmbLD" ..
	"yLLTAnsM6JrBglJ16jEJvcPCocmNvjE1thBldzeJIvWcLOb+Se8K7AQhuaMPEnSOxzaRe3dJ+MF4Y+znzPixDv7ZK1PexJvjlft+" ..
	"YJU+0e1/wHMGZ4Pfi1rmZ7WJFXjLndzPHSKpSLv33I4rIj2nUotmw+2lOy2vnjPuOjeCMWJLsnmek/RKa89oyetrQlTxhdVs/21r" ..
	"zScxhpTGLDfV1ZN4OsunV2uJaBKj1tkF95XDCvon3m42CLXqx8iikbmntBW42rN/p8heFr6CGnxxFcqFShzehwyTVWIBRnlykXuy" ..
	"vNjxfMQvikxmnY4DAmcqSCShQ+i8e4amdNJsZvPApy1S4TDFDdIQrTelRTeswDskeBsme2ILjoUPEH00upY0ctyKHq7/wQ5aVjle" ..
	"zE6zOb6j2o1+nhmMj9cKofDUgCoSryQ22EKqeP3PXp2NuMdNrVZxg2r7+74iWjg60iwg/fLZ4OU51SfF4PE9VeQHIcaQbafoB7Hp" ..
	"aXXZeLmmkz4PY3URSZIDmI9QVBLyygA+XiopuW32naI3XhdtiAPMHBpZ9iuBG73ZR/+ORqo+2EUmIbAvUocv90Ol0ulJf4ov5yp8" ..
	"L5gmtMKNaiki93KZ8gdOWBaJInaCqcl99EPc4oEnGtRntDA9PkdDpKo51HJlCse6AMYlqRotl5WtN0GWqoJr6HkE+xrb+BqoL6MM" ..
	"TIoNWY/wfYU7OjrWniHpDltJEYbOYFZj++B1ZUcZzNsj94TYppzBtqXLDLqrfL8o0YDHDWqnKtlqWB0m/HOIffe3aOQU6EHJ0mt0" ..
	"VmbX2NJunZJIWNY2FXYk8dP1Di91ToLZJYikLBJ6zFPs9Pd8ji39u6RaB8AmwyhwpaOCpL3ZtNcRPL1b1OB/rvkyXSP2D9Xhh+Pq" ..
	"Xw5XBTQO9eM/jZB99VsCIuKISjSRyMf1aLQWvSGGlVnWIX/38HCadVWmWwEXXeBXMnqQjPnvjrqKXzQ/jNY3binc7jnpG6ooiARI" ..
	"4HOpwP7U3s/98k/48tqoWRSw7S1+3drGgUMgXXkfmOthZ4P7Do/6wGl4QTcqBBU+FWVssRMvpPElFAgqO8OXrLKTTvizn+liToQV" ..
	"mIFfnTuaZH+XS++V5doo2u1Dj5TZ+Vlvve6oyiR7A+3kP59nmRfHCG4Vq+TKjyT7E6Bd6vgsnOm80pzlTjn3jKKwFaLoLQI7fIAj" ..
	"s5NiQnhmxMLtmj0wkdHqQbTaOGsZ+X5DrvWfhNOYDDQXFT32Yh6INDWxHOHYWu39RSBoW+TFkAajA8sZQ8OYpp79SNIvZs7eSoeN" ..
	"bxlvJSCxbaSD+nQqFg+3mwou0T8YDFgECkkjZa6hfkWcReVsEJJBZ7jbEIlQ6/yrzi6NQgo9rHKzEdefe/dIQLWvyavdy6WzO+UY" ..
	"AQ5tkvU7pBF5N1fD5aGUFDvOBSv7LnZtCvg/ovgooSNkrboOkQjgQN/8ZFR4ANwMvUwts5wAQOkwcNNXCIxl34NTNPKHgllQtntC" ..
	"mC6F+Hy5qQoXa+a/aX/ZuEN9SnCGPvc6L5goyWdfs9brJwW48AusuETB9WJf++ncDK8kF7VDNiM1QHyyjfg3os0WcBrGe10B/NWN" ..
	"YF3DI1gBe739ELwgkc45fN29HzLG3RcR88Url9FQLnHajzyWzmQanG6GMDd8d8WmKmOGyYusu0SgZ/cTytjo5KZKpAi6qhzyuzb2" ..
	"xAplwkB7VZnSC8ZOvIBy7YnpFjM/HC8AO0L8i014O9iXOVWHbrX2dwPv4GMis66RYkccoOzTM7/PEqy4Zyrk0p4h/KiG8bf04MUg" ..
	"ntFkcIlNvvBblzdFJ41ZgNuhnB7TeV/alMi4uot6GqiUUR81YZxAHDYQNLaHyIWJCUSE4bafItR2MLOeNtXQz8HHpb7SsNR+/aHu" ..
	""
local PAYLOAD_P9 =
	"6gEnvKj94Hu4hLrQ0F5ZfzMoMUN11lcVmWK187zqkvVXXcaSa194hrjGqQaEgfEBEg4QKtFbHajSe5JYjDwe4Lj1eDdHrdvasspK" ..
	"5Y334vz9Twxg+gfrNWCHyIq9McHLOQS8bvzWvWL0SyOk2dTkGQdSFvVMAXjAyG0uLphmmQLTJkuBrNa2QdkkOWu99evPjsK41uTp" ..
	"mUZgHjBI3d9MPkwIQ4t9pzFNalR53AeqS2upDIFICbRie+Cf8UnwihVmy4t/+g11RIPCO4WMYOR5Kdo2k+2jALXlnQ1Oe3LLr8X8" ..
	"g60KgCnLv7KmxxEpcZpC7YsnJEaQvM8VYWttLCKKPjnWcibJkal3boYXVgDoIzmbsAP4SnXVoYjL3d6lV563BQbuRg5xjcmwqBSj" ..
	"h5ex99306G9TxwnST+JyM5N4PgFUpcuj4RVoAR0bKu51aN/7Km1amwluyrqVR3zO6hMmHZZ8xTC4Ax0Z9m7fZJxa5APzkusYHAnM" ..
	"qwJD+yrO6TIuK+tpa4moeHLkuN+2xRrou/y3sgZzwk+QcD+QVU+M+7KmCd2ICItEi8Q2qTgaQ2Nj3Dig/F6pAAl8TM/DUljRJzBp" ..
	"fWuKgvCJ6Ej+RuirFtskC2tshQyEuFOn22hU0lkPnJkJVwkDz4slX93GhxC4D7VWQEC5olKrUgT4/CZxrvS2Jc0F6+HbqBAJjEPn" ..
	"jj6PcickrnGn/TQeNc5/2+32EKkyOJ1ETLAQXafEpV4CaX1zgiOy/HY1kN8HqFrwuxQNRHDeHKHgSDLmwdmHBcDvyGk3E0PsqV7B" ..
	"cgYKDiNfFlWJGy8v0ytgMDyPdL5qi63DA8NXaSDjcXAkRp4OE2uNV1P2PP88NYvSYQ0/x7dJG4cGRDURAqFskmDWjKLqR0UyWTn6" ..
	"hEGsfiRbLmTN54kr7h30ajjofu4ukVasjNIUMJ5bGRhFDlKQyAGYz83gJFBBDlULo8XZ/NnSoXdg4Zues7BFWqr7z+83s0FjNngA" ..
	"lfme13XrfFtLIL8Q3yJmqVLobJpticLdO5bcfYNse5OFfU43dmoK0GRuuy2WuTfEorQXPyv3p0pmYZqCVCVoLBdUNWw8DdLBTZbQ" ..
	"GXOYQQBW+tVpZlYQ6pmXlhKp+yHtBqJDsSwflVtxo04clUZgPiwwywL0/e7KuZxPuPDWNILtn02fGOxyLk6kTWwvWVVqO4vVSOsi" ..
	"mPWZBNTfs3tO05Msfno7WpW2E/c1JoGjmQYbMEuH5j+m5Gr1Uv7O9HzdZ1B+5M5FZyrkm1P1aHjzvaxIhrOljdbPQZcxVs2C56yV" ..
	"v0yM/sSNxPHXliqApqNIxLBB+Vfh/ed9IN96lOYzMOjg79vUcsv1ecug2TvDQcVzQFHXieexu6Pqqi14zdvY/xW626xIRvGX5sRE" ..
	"eNS4y7XDwF86do0gAHkE+LnFBosiK/fJrm5tJvFSWGUuIFT6fNINEBRz5BlDs5LzxY/4rPWoVNGa5j8j1bWniQ4vfkJX332R7c4R" ..
	"nDytx6ei7wl9ilnO3uh04Fk4CgZ1v0VCbl44chtL+2kbdrcVHjS1xSfTRjNaxA6pspl/IEX7gAdzZHrGeH0c3K3FxA+p/2JC49jO" ..
	"ma/bW02ME4XXQzk3ywDfLUMPKxH2J7hTcKe+nPnhip/Ja3XtUwLNfhGbYhiiCp4L4Z1m7Ri1QJNGCUaoQvXotsq//F3K4NXFv7QE" ..
	"3BK97uOFL+IgpGamC+eX/2LksKMbp/U+mjEhNCrpEW9pdgnV5ler80PQpbKw3ftz+wtAO7ucKy8uIGqGlNfQKLj2W5sJqu5OP8kC" ..
	"DfU90wOfHwJPHC3udbEDrVYOD52qNYF3zHi8LGn7fAPrgiAicrFZK/xwrO8Jp3zHo/5cK9hd9SvUawa2pMgWHHYHaxho9QRsN4Ed" ..
	"3U9V/bKua/AsFD+XTbkQRNtdALs8Lj69EavSqU3tMUJc42JFiTMWB/dH5Ro0d/ffQdTj6YghnQYQSHJddJmVV1G6onGeLg3YvHE3" ..
	"XifPznvpkEpk90oeFyvP8cK8WjAxsk75E5kXIcytnw49tLfg/WeBJQ9a29hPDrZAn140SlwPI5Wfmr+sAW2vRCjLVbaEJmHp7O9Q" ..
	"IWGLaMJjDFnc/YxMxBs+SF1iAS5e6TH+wpz2V4hN0eVmDgzhNGc37Y0LELKf60sNFHSxKi2qx1Fh4D0+sUX5IWU9fY+0qOAWE7zN" ..
	"AiJJcVFJObv/LbJrdFFoc5KsgzTco4CLydgD5NDTk4q/Wt9jWxhk9b9qmkcI0IOXCQAzcMM2rWtVcXdGVMmL5Sig90ZHkL6EG8jp" ..
	"XPt5Wns0LiWSj0uZO9qj4yzxQXEjEn6PH8vRHJgWqDbt7eK20vsWRZvvDz0xdOSRmBCKshjFlseUc5NfA/9jUvL7iOfr8ISOaZAg" ..
	"qj+w45H3JaOXKS8b67TFXrSNEolO9RaBzJ76K7SDS5KBe/VinL0sbFie3fh0cP9jQjVkDpkovdpOG8YndMzmEh/O0jAcr8Fvqq/5" ..
	"ngV7QUWPu4KdXswbLxxnOieGmZMTX1q4IBvmQCQWkg6ex/baj0FD9qeBIWOpj7tA93JnAh6z2+M9iJqn6rWfquATexINsr3+pX3Z" ..
	"uO6iFvMVy/AFir1pc5rmMVmjdb4IPtb/ZkLEUat5rXp6oQpn8sGALSvUfkMgWm4iLDd5Qe6SX0h/zFTf54w5y6MgidevvmwKs0n4" ..
	"h5L3RCzntfzkxrNTne6OTcgbqYXw1O5PJexqvOEZ79LxeUj5lSuEbE5h51LbxUcGEIRlL3SR4Cg7PGWWEhLaY0Z55th/FouMJQA+" ..
	"yhV83GyrLhmPcTnbnUf3EnqBqRPZsxZzeK/AoIxC+gMOmfVY9DRupevPKI3xy4Prnk/43R26DATPOVb46g/gbj6uLpR3Rde9Wv59" ..
	"klMnInohe6inWN5E/9EX3cNhTApGovp2TLfKTZD2HOuUH3SH/+z4ViFrSyB+36dZhZX7n8cZylU0E+tjYJlGjKiq1MCzMfNDqopn" ..
	"dCSvODT3F00nHIfYzGwBY5KcYOIEdAsKhah9VBK0lyFT3OPPJdby3Nfc3IlLX2VOrItoLnvOeOw4Zlp2ABx/FAOFm/f4gP+U2SoR" ..
	"KFYdXdgjs3X4L24Gd8WP9o5/W+B6fxA6j2i7II+8kaN0vs/OTk15uNQ3yPCN0KOebw8CaHmmCJYunoLXRwKFYvzHmw7yXKaAu4mC" ..
	"d6BjQs24oqkTF1PbKEsmgNwyuTcitQwCCurH4qFHkOHHKv9SbysrXPEdIJ7tRA+qnVN2b7lpcMoAGZZwpwRmOjRV7I0JumNVsxWM" ..
	"KMG+bvphCjr/2KSiRdEwy67IzIdNQTZ/j4jGh5++ApFNDqW5grZ/W0mND0em88J67gYl0yUt9VWn7xMF+3Int0qj+/dqENG6oycn" ..
	"6gdY00Gu6WZLtWBdNsVKCGHXtrF7BSpDXgOJuyj1QpoHI1dp7tbbgn7ZflT6IAh0hGEb0hGJmI8emLuOAmX7dQupq4wJMPjczJ2y" ..
	"nARuJKyV0cW1/th4Xa9zLFhv3c0/Vbo4udBe0QvRGA+ElPkpONRsOKamEeKQwGrr/7BcT7+zookaMdjSpiWicAlis8IkIOS24fN6" ..
	"U9b3RQ/EcGepC3jowYyGrmGHb3d+hP4EVvjVrcTZKt91MNio1hVZiOiRptAwKDpycVEPJr8U/YkJ3pdBPtEQ6kcQZqyQUCKZ3bFz" ..
	"d+Byhr22Z/yLQiuFtFeAfo0Qisdarr4ZFASvQa2/m/Xtt4mKHIGxDnp/EYWW2Yo9G7gndjYrgi8cEosjtZIdpn4oRwwL+v9oBcDD" ..
	"dXIKUoO683Dst6c27PYn9kkJwGoqj08VVJwnuQ8aGd2QNAVsantuOYIvQuVSfi7xNmfYU5CB/sPDfgBBPrM2QP2eMy6MqdjLNY8r" ..
	"KKCbyqM1lnadIarm1/N0MtaITKSgO23w5eAZmr1oiChNpyExyDiKbgeMIFhiFVYl2m+MZqjwvcSzt8myIs8Q9+xQ/8HdWxf2SrpR" ..
	"EOG4w4Lz+aB7t1e+ndzqNxoSDhOCyTFUoeANXH/Y13GzfU8vtyBlpJYEAx+9sB4cy3BHLFbvxxSn7lclFNsG3CN1SCsdmBrANrV7" ..
	"4Sly4iFC8tusjKcTa1ng4jEQxAm2BZMiGg8aojkVghxl4DbALuRLxmAHmTgeCi6UH43LaQPVjq3H1+yLuJ8mJJuQds+dTRexmStv" ..
	"JauhakLMQHVhoBnG19bJSUipbOsBZYimGiG5svWEHutR7A3yIIA8rlp+6h1UgMXjn0zmkrlHOBMz54+aiAVeE6BMm4TQc/WI5fA9" ..
	"4TRzCfvEeOcGVex3sWTd4YHSDcP2BuBfxotLztxOVDh08+jtUeBc5n1ZoU3pdh6/0XF4wr9Vi7e6k6B5Ciz2fuV6ZihFMu1Cd44A" ..
	"01853id7c7O7eNzl75Wo1loYXtj2/kPcEoZZKdX7IfUbVDzgnaea1EkOWwkGfh6fJNJSlYxxUdLRFlkEMhg3erk35yQBEPyneYPY" ..
	"7DnBKRazbQOX8lOsPeFBfd9oPtjrPatLXYtSCaD2qy3fH6ZdPRfSF4b5JDlDyWhzCBUCWd6ldHrjDKZTO0fJhrFFtuFITBoP81o5" ..
	"YLlOaQDNqEBuLENoEW6aElVFB6DIEKJviReethWRp813wdJucHGiE+DLlXE/uRtoueYAL7HHveW7BDUhqFBHKCSla44zNeZx1SM9" ..
	"3g1MjXtNW2h3JXMIQ2mTNWnfWi0rKYgZm8C+EjdirBDZ/n9dldrVOIWz9YhSKqq1SgI0AY5jg9qNiOsu7lb2HHvAkdk7o7uo+ebL" ..
	"UqW30jisIiMB28mhk6kz6IeS5pR5vsWUGS6VaNxZX/B+RWJk4nKpMq4E64Wh34bJDAr5n5GcxAmurst5LD0SvN2UCV/CF2ZWmkvU" ..
	"eZReqVamIYeMvE7WJnsZmg21EPCKssDXRYOBiUbyEVAbk0/dxh/MA2ZtFz3XfIoyjB+EyrfnCX+k+XgDP4To8gsyTzRl2SVur23T" ..
	"zQTJOkXZYLlDPzTAiIEentiYIVZWsW+5HAYBXcBGRP53BG5gtr8kq/HQ0D/dm7SQTbjZ8UALO2qojAaHmrYFBUroyqnplKV/7JC6" ..
	"etN/LJNcchDCnfK4SNKCi4/i6Ah4QPTNTmv7MXVnTTzMRGPuiQBFOudJbdeE37+dVTIwoXVlxVv5QprdMk5SFtvopCwfdXPOqXWm" ..
	"wTWE2febpBIagLbkgTZ7z2gK7H2dkYk7WFHaRA2BHzWURrpmQ0kqpJGndewakmWrMrmti/RP6/oGlpqxwfpsQrFQORUWpQyq4g7a" ..
	"K+YL3Kzi9eoYdC1Hn5EmUGLityhBgdJ48n1GNHdyC7Ug3r/JTLNw7Q8pPl/fsXOwaIciJR6uLzyYiVBu+TqhUP4evvc0kLM20iVR" ..
	"4l6uVcuFJRuDUKkSsvKwSdGllA6DcZ/xYmhLNbu53EcPZSGeG+/GdlLyQ+FtAjnkLb/GRkYdVLmQDelX+lVRqXA8lXEXDsI0BJkm" ..
	"VKvtKStGYPQUG+BkkjwmCQ3VnMJfwfzu+tOMm/T/TcIr/5fue8DXKpvtbExx7mHbmLzdjMR1WhPZVYnfgklrtn2GRtONFuFJLY0Q" ..
	"M6iPJ8guUvTONz67WSeYi21hrgUUtoSVCboH8GFNrYUFNgR/B9PCmQLbFzrBG9KPz0/hTS5K+dvj0BhVThpmtY/Nsxj1MBWWSNxD" ..
	"5enFDk6hiR/2oOl7o+WpgHDxZ659GRV7vrPX37wRVS2qNf+nv2e5ID/vIcnngSMNUrgsXYXjPzuHB+s3wpG8aOKSWnrwpgXRWUhi" ..
	"xI9yHPyJp/U4/2QqhM54Qf8dEXeIl5sHpX+EARLJwGPhJiRm5YcsgqOWNPwUDbIZvGf4DPVS6mHrITJWWtOKT5ag2Lk7E0IFR/dq" ..
	"0qX2qbMVkeY63cLk9f2KNX0/bjm0XxbRcKvl4Irp7evbZ0+P4lnbdtX7m8rHGQ2ula3c+rw//rgTMiXLC7hx9FzLQmdt61e5MiYQ" ..
	""
local PAYLOAD_P10 =
	"8w7E1DgY9tUVcbJWxjzGfQAmDp0m52z/SkKLUYG0hv0Fu4fdc0L8Y9K9ljd5MEQl7B+aCP/kvmiQbxl9R4+ozLmgEKS/kCdhis5c" ..
	"zqfBHg9d/dlLcGvjuxAeVqRSQxl8cJGWbaGsAEexFNlQ+ImiOQ1vHA1ADvLekoi0i8wOtgDxu0Rtt9IvG5ennVTD46rfJu3zFeo7" ..
	"NxlPy1VrkIe4W1CM64sY1exS58J4lU+Fi1xzg+2jc+WKe2wkKxPKBlVczuWBY8P9ZgcNja3a36Gu0pRpu2hM7QWWycWM9c2ZoW1v" ..
	"Yu5/B90JP+waHWyF9vx4nB40wfgx6psJRtzRUhnI9NB71A5i+a/3Eyb9/2cVCokHsobZT+8dQa2PJdgI9yLFsVOyOBHHe7Ron41p" ..
	"UfFvaSvONLrY7P7yrB69CtM3UWd9Y6vU956A87jXJzlf+JnAqlR6V5nFpv1lLl5s3eXKAUlg4ODwX1KSB1NqYVOWu3fv2Hr2OHu7" ..
	"ySfSQR9Rxp2qFRLK/vnlc75Xag24N8rrdCovWj/HpL79PZAqzdg6RMKdNT3xQuzI2H7aPQJCbt7x7gxxsE5AGJSHJ4Dk7LV7xjwU" ..
	"iQywbzIDYVPOCiCift0broVQmYBA9rM7m+U7T9rt2+LoHppglOVMm60rCcR9Cs1/BdEVYJ/3JPdL2kUXLUlrQdfr6lJOfC2wyY6A" ..
	"vorWdVvlMJfqg9rBlvgpFQbFOhtZcoyJID5k2/0b98StBHP8Nw/J1BHgvCGNoNHHax3vgVziSiPKZPWryiqqjhpkMVhIFIGsHkbW" ..
	"aIQE9X5Zgpt1gSRz6FWwsmVp87LdqT+Y30aZTpQ0hsOxQ/Yy4WTiFQMWpD4dKAQdKGIhcaimGwLu5jfxElgTJwCcRC9pu1ktICFi" ..
	"6zzgyLB0el70ku3k1Nh3kGNIT1If/6g3+vREwWi+vHdXbn+4K2FYRbMWZiX0Yx9EHPnfKtXBRaXX3/4P4IwWOgTSs23e1s/P7Dcm" ..
	"aX//S1rt36KiFc6Vw7f7jV5FrZ/Q8sZTYbSQJkueWouJWrr38FLnOUYf896FdfGOMJ3Oxyqo1RBYu/jNf7YZqG9Hbn3nB4fuyewr" ..
	"L/Je5XdKtq0eBfwpywZ298KVuXr0eU6oOBCyCQzb/2wFAA44pSvRYlk6Dv//8camSw/ucDYoQu7R+OT5RrAhngrhWYP6uaB34zYW" ..
	"oTRXm9JL4HbFNfEJ4Zhou5mg1O10SJpEMHEIjzPDxSU8aiQqqMEjEiP4DlofJOgiDJ3NH+uAjQQBy1r7eQMBE/RkK6yqQrPlnWRE" ..
	"qBKxq0I8JOC3E0c875rVmph1QYcLZTiUhEAjr2Rsds33XYYGITawDf9ac4mq2UcyhorcvhmbinStJ68AqyA06j7YWQlW8r3n3lec" ..
	"zmMrlOLnghf/sN4a83h+qoQLb7hbqxsIEx/vw+Qy3NQRygQmW+hC13QCrS/5bJdOtYRwmNuKuIf6vtVtV2NF3P4f3fnNzMaNWtkv" ..
	"G9DYxnsRZ7uFcGxOWQ6ttOpA4yAnGd5kULSj/a2EzyWORBrMz1ZZgki6YxsCgohsUUZKI5IcxqZvCWCAustn0bF/Tf4OM5z1Hqtd" ..
	"ei+vv1u7pbqVqZDHIJGsUlt/9lAIAwGBA+BUvK7LXdMZ2Dcqn71/v8YVB9rD4RT8kDZmzEwD1Cq4s+DVL5aqJhwh36oPh1BhYXC2" ..
	"oOcRlU78cmhT83h4p9ccvvoAM84wVd2IiumbSx1+2Z9j5m0TP5pYRXw3RxjNLth89jmQRFviybBfNcIK+BlSzezXT4Ie4XWwwyzO" ..
	"ZrrPjBkGalfg8q2uPMLRmtXI7Uj4yaqNaL5o5vZitUWoLLYnrm47ilGfMoTYsjVsVu/np0BeKKJUSeWm8U1kGb/B7ey3OUjuv3vM" ..
	"+3yZANpppIDgiRBzz65w20rhr+FbS7vGRNVZsYt6YwrCoF5Hi2MJD9EhCDeP2hxAPQW5faqTJGSwfkiLKA9zdz9q94iCUv1saZEV" ..
	"2jLb866idw7tjUT4/PoseewcSYijYICwAiPQQ4hiGCcHLUVDx+wG5o4/kC9PCvGTLiSzfbBumWlxMFMz1tEL6F1m4M9EQ1mT9yEK" ..
	"ato2rxAoqpp+WJyqty0eXDMILWjJRgVuzjG61fO4BMtmBHgjeGVmsg24Cyewv2dSnkLoBsmGWOTpcwrljW/lkB2zIpOAs1il9+om" ..
	"O+ZcdTaJ4WgbMDS0onwDWxARSmLyQwKIMaqHNcw4SwlJcLvDE1sa3lO/E6V4EMxVjnxmBRfdQcWkoLD59zNaCfmUo9sMQBISPiyJ" ..
	"mLWRjmqkwKl4ojPil23gu8Ed8pYUuQGgt6NC31Al1/WVtxvM7j8c8LRklQLLTyQLxTHUevXRgGrPwP2ctVjrHID0uS+M1xeJ9hdp" ..
	"eaDPeTmB0jiH/J1GeHCODbH9lnUkxJ9Mp3ptFAOKHWgB5vRtYW8M6yq9avDjalsonHrA1ZrZI24/YsypbZUdtDDGgL7HIg0Pn7z/" ..
	"GdlAKhBQ2MMLrMtj08jC5CfA8tjzyhL69dW8yzN0KNToJWhNJd8mYu7VxYfC84hACI+udSIBDpOTxYxXd65TKXpuBvOStqiwhFz5" ..
	"yHNzsXcdRRGb5Jfx/bMxI54TpJyQa+w/u+gB0SxthIvit2ylmtcMcm27c9tiC1uCxENzYv4D1XXpA3tINhuf8lpIP0qdUz8EmCnh" ..
	"NPIEg2sKN5FBpXI45ClhXuMratTPw54N99wtDydRtqHVgDEUDW+2woloOX4DP3WY5saRi45SePGnArvp7+jWypjjSqs22ZBpo/dI" ..
	"QyybeOkeVCQheznur2mXqK4/C9JCLtnrSz3KMuV0FNLPbFvpTQl0aKk/NJ5a3D7VX/k4l4Qxg21BcbMNviAfdfYbIzbitJcki7ZM" ..
	"GFych9aMIT5be3okre6o9mwuBzb713/c/9VWE7ykmggLwRwrZhqt3edp8ar5cW8NkGY8Edhjp8UIeYU8e65a0ToFcyGmhMV8xYIS" ..
	"oi8AM1P+EJpp233d0tuQIrOau7lAACt/GzHnE3qufMoRQW1Rk+shECw6af+BobJWdJPnrPXkdj3f3fEYr2B/Z1pDgWuNNiMMgFBH" ..
	"WRxiPVDROY8CTaOR7I/eZnT+LaW3C3Npx48EaxnH0xUtfGcm/Mx2IGKNOUjineEwIYHOZXCmoGKGKgSmCpwg8t315bInYlT9nLtg" ..
	"FUSw5pSZi7wWSy2gLr90LE4J00WpbGjLNykR0BhbgKQXM0rAcB8OZ/dP7wDHY8dsJFIbHBQz5EVWeSkr+4UCoSKwO1XxGQLNP9PC" ..
	"LuScXWDrSYHmA4bTm+NNgUZAxV8JBMyek5CTG4SHC9Yex4QL6U8rQBdWElCiNyP0jCVlxrvqGdCeSKyyHTzMDAxgWeXijX+Z+wHo" ..
	"k9G58AG+lHriNWcne53mqpmERhKd2wW0cXKEqC+eTELckPepnMqdzsDDmOwTijEjRIQSpy/O/deZeKplKLj0rzF9KONWtrFBPnty" ..
	"RKmyCL+KvFe27QPQ6s3V71el8v/iwv9fnxw3PcPEixvtjHEIpope0zPTiP2F7HoBynq5c7J3PcfH2eWEeJKSvB0EVg2Zt/aDrgtj" ..
	"kcJXe0W62bI8wUUOz3xTeKkmqcvuucVNT/cVtSaiWc1y9h29omLFUimGOPD8z7Tzee9eLkW87/pta64AMRHDvl96bsPnCXMkoms+" ..
	"zZ3egq5opYFEkXYussd3POLj5KCsLmpbos2gZX/AMljfWsLtf4ZATV34hnzge4uAg3/SHK7m+nw9qM1gQsYx1LegxMruJAD22rGu" ..
	"RHrIcwFlbTIOVLD20t7FdsCPF9jDkaD/TWwk/gd8Ao6UNM5+FxLCxrxiucaj9EyJd0sA7fApfc17ShnK3yuo8b6RPtw6aV4WNsIy" ..
	"WnUF6NVSWWvNxWzPvsQWxPiu3ZwTcvI+G2nAWNea/HHY/QpGrVqhtE7Bncj3p2Ixk9QYYYUB4fLdtGjUwN4HKechMt2QDEhPH5NX" ..
	"Sme8JqIRJiV6FyTiw9P5ZZchOlnewvdMCedcYVRFQDhekwGrX4rw0vZaOg4lckVGoC5ugrftdHK7UkuhRNZQOb7iZbCcjE6N60+U" ..
	"NRDl6O4sJPOYPAstkeD8A/KlcTa3DN6wRwluJVsBmlAtOJg3Zf4xZQZUsigEZqPZb+CyrvPxVWxLRloB7EiLIsr5fZ8Ef9Jsy/UC" ..
	"JafXq+m60SYuXrtXtmckWt1TX4WTjdwlfXxyH045XkLyLHX2qWX4TqEklwGoJicfRhXNwfJZE7nAKZrL018ZXNfkf5nEMV3Wq6Mn" ..
	"nV22sb6jvIQ4lt376oGKUNZlfaNkd5GyIHILUvR3DMekzhvkLgO2N5NvrAfLZHnjoZvFJbImRJsbCIGr3ozP8dV2l3HW8ph18zDw" ..
	"GFoCyNoRLMU/33ivg6JxxIwwML4xnibvCzsV5WDoqyFVBCS7Pr30jewp8AxImBcWgPbZ1Ce5uZvNjJdjvLiNgyX4qA3C/1dQ9xlw" ..
	"OsMtVR5Qfdg4gzmEYGCdcyLkKLvcgQ3DE77Kvf/sQBgxs7r4M05oBefY8yZ6+6m6ndk+y665WZVtyzwGOdW4AFrwZquwrjg9zPRb" ..
	"6MSSIebYp1MjRljfzGiMwMImmvT+3zYMJaM0YXMR7k0gtE0grE0six2CNwGhztqfwIF9ioXOjCIQz6NNw7TVSINfPyQOZSt5oTAO" ..
	"T0UnxewQ0ZErBoLd1qqc+BMEkApJA2inPi4BcYk9aYwiGhEy/bUbhNMQobWF/FsM+0R5ydEvDQegrX37COFY4S7vwLRTMYE/E48y" ..
	"pMtpYLQMM7OQQ2qFyk25hY6D8BeA6f2bbqg99srHJ37aOG7SeE3Jztoxj6cbRsPcXZxG2wPwA5cNJRMvB5JrE7v3JxFBDUcI1Yup" ..
	"JGTJu+OrgiCNs1uHaBUuY6lEhp6auKt8eV417EtejKgySylK+J00UukO7S62g17ndt07Uqg/SWhWnywKwOUyFJOUiYtF6XibgIhd" ..
	"cG2G1jXtysb+KAbl1H0VD63YKmY8L3K6L7bsAjacymQIHTIuZtv0Hj8VUSwks04JOcZnrVYlwSveYUbb6+wLX9Ufxq8eVcSnsB+j" ..
	"G4/UwtK78ycSDVvPEEeAnO4jH2CL6VASkHVYg0inssiVDZGhXVfaG9n41YPDdaHxT33OBpb8fS3Q6mG3aX0Qmjc0uFElF2E4GoIZ" ..
	"CLRq1nWBO00TTStv5y3oVvp7CKQVHn0KpCqcr2Mz3bd5FfuXnCCHVd47VN2E4ZjzA3GtGsIlm78MBJ9nAt9k3VDYDv5tTuam1A0N" ..
	"L6JNHO26RlRBJ+TXcf/MNCe/ezZBfcPl7OqBU4YjEAphC8L/1z1KUdEac6uRDoI5w2mm1j/Y9CypYgNhumzmsl/e4wJTjoyiRDxV" ..
	"FSH61OfyEyOpciihFgOAo/+KV1FzC2JB2TtijCwVPr3yX+CwHh7alQ+9bTyLr2BtTgtVvZ/dwSenrx/ohr99ZW0uoJL3fgTLDR5W" ..
	"cGDhIOCVnMIk1cFD16swk99sGLTSoEcx/FIMp9tK5IN2+8reS2238nAPeyQ+MCjeSGQ5P6tezqCc4yHhsaLuSce9IJIb3vlCKfcl" ..
	"WNke/pEXrP+bG9Ue4CzTMVvHCh/4tcE=" ..
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
