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
	{ seed = 1708045941, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1706481251, exp = 0, plan = 0, hwid = {} },
	{ seed = 1707061766, exp = 1788089514, plan = 1, hwid = {} }
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
	"J0meSqfxo6qMF8eFspUJVi8JFXMn8XvU1SQPoeT5L8+pCAFofUAD99rbv0vdJnfIqvJQR9ewUuayiTm/dIO19mHg7GX0rghwKtpV" ..
	"Je4LuAnc/YtG81Mr8NVTnSxeLxp1IutKDhRDLOVrkzdJjnP94Pv+fldjb2S2nmu7Z4HHveKL1WToza+e4QJe1aA+Gw4DTOJ7Jjsk" ..
	"62Y4Ap6WeFXz7Z5pt59rFJqYYnLPwQROxr8j5V/ObcHUVqPQCufrmdhwf8kAlOpG2sSIBnF5BV1rmtP9ICC/bIz6ev6V1R/bZyWG" ..
	"tyvIKooozf4ftl7lHsz+DbHBHt6NGb0gKE/Ejoz+HaTEsdJomBim6icgLTU80yQkVa7uBjpXKXXBzoQ+o33b6t8S4eNLNRVF6pQ7" ..
	"LQYGBSmo07dn9P7Syig41rjO47ivALDEyLcIbgBGpRUZk66W0yg0BQ2FQYfe7DWjuElWG0c7dgyjomDjpZZVnPP71anhQ4ANBgYG" ..
	"aU9jBc5ehjotFxZAZHiSjj0tjKtHFAlAImFyCQUvRYLi7r+WhDc7U+5iNi9Q7AEyq7C006LxwVQ8MlY+ViF8NR+VR2MCjD5O1JZh" ..
	"E+kBfiFQNoa700s/fsVB9MziDUCHxapnwsa0lK1VGB9qFMCmOLPDUlKeZMupwzyWMUXE7vy+kekqUHROQw2C3JtCg3KuAfktiNqd" ..
	"lmQexgsPmfBxXGnE/Y6EU6WOk1KNO8oX+W0PlyRqTTa90sEXJVE15Zq66yTEaNYjo2KIlzPjd4jPQygPL9T0H5NCa+foo0z4ihC5" ..
	"2lHeb9NGGmsu4T1eq/EH8eH+cTUMC6SFdckfx+CsXGhs0GmrCr7SqPuxWQ5fk5fawDXYMGK2TqGLVmI98z9zKZ0SLGQUdluvSH92" ..
	"44xYVqzFiD326Dnht+mgGNTytAxSlkEKl1h8GziA2SNDbg+sV7yqeEz1w1GNIEMFeHurhEKI2npV0C8iMIx/zmV8RAeqZ4pEIqXP" ..
	"CJ2I8+8HsB/A9LkMylQ5JO+FdWkNWiutddtTR48fRUUeYcZi6YM2shsLBGGNkiNxqjlfH//MxdTt7bwVQcwg7TDq+jT2TNT9Sa+b" ..
	"iwlpSlAvvS31jvBMqcSvnksYOgyz8pL5EhgVpRS6Jn/VOWw+lqtyP07ESw2D9GDaz9NNLFcVDUQbBYsV/3/82Fdns10VOp959zdQ" ..
	"L92Y6PA8kK1/BHsHSfl4zlcNmEW0/LaOEuLEO57OXzR/+NDcUrM+UdoT/LfzWk8XJcmxH0BwkXnPD8jNQkHNZrmVsyMdVSI7RMUs" ..
	"NUwfb8uhd7+J57UaGvz8yrinlOcfmbEnDqn9qp8fIHQrCJtiltSLrLdCPID3xIIyGgLVKNhZ0vp+yO7MTvBJBH1RYkd9wj96au0E" ..
	"X0r5F6t5AivXd1ArFkTjgLqnjPjFtpKQR500U1F1WiIgc6K4as0x092xgfldxYgwN/0/Tao1rEHISFZo0WfAVQYfUUR+IzDaqAwP" ..
	"n9BF6Xwu6BvXiYGvqYGEeyIrS6rA0qQrsBBoNthY6ezwABLNMjn6nCJ8Ih+yyXqNMVeqf1T9ZYwdLtKNzq8+nYIdAJ8QXaF637Is" ..
	"1ArG9kKbUY/vfCxvaLslOXMKbCyiNwmogPMLhRGeYBdSUJ8TLQb/xfIScdQY126yz/LXj1TPL+Qeyx31vGTxdhlyDKkV9gS2pm6/" ..
	"xGGBnP/NxTRkXSyDs8dJu5RQHzYpDcpJlc9/7lRvTjjDq8L9Gati4AiAm4yQiAw0bms/Wfb99mbZE86rNn/MPqkxL2oCjUJX3Oju" ..
	"tjIfTbNxEwDfo8vCrUB2RvpwgRjLYzf+nhr0qGtssYlPeDiipNFEH0r+YribLwgfUf3QlNqp9dsfzdYk1Dy+LI62tbsHq+4yoQcZ" ..
	"wsgSuBuXbWNaeMJ4lK6cKvuQT27KjpUYWBfeJ7WwKIHL6RZghhI+O3dHvzkAVT5EO8OeOTLInNZzbLJ/ou5joMKyOYIieETFYygf" ..
	"/VEzF7AzCKg+MCo1DC7lQPL6wUZkQd3GcbYNvGwMmAGK343HMeD5WVGzU7DtIvU5IIIiA2jUqcRaRBFnxnQAyTpMuvkaFzfuVg/G" ..
	"YDNvvLGloWb/ydFDx3AmaJyNWKE4Lb0ntHRVbp7ffifEjiUZCOkDX5GpDV8pCZawJD0Ff7IT38nk6ikBBiL5Rq3EZere0AQErF+f" ..
	"4A+2Jm7v/fRjLdBw+WG0kLwY9dvub7QPlMH3q0ekE4f6ZpPoDABv9GgXKgO3NYIeJppJUXL48r3TF9TEzOHmsUrurdE04RroR4Q2" ..
	"ewKEHKjeiBL1/VJfAzxoow2Fz4DmxjTOBSYGm5ZNbS8N/eImh01IzcpO4Icq2t6Ng0zQhgR0NGLfgLYYS4OjAnzo8H3AWkZloEDs" ..
	"jJTSMr8qzz5qHgMc1Kz/LSgQoRixf/3zDkk8x/jTXeLyE3vlwEjCT1HGFuQvJUkcDSdX/Z75DFDQIx2yR2BSshHQC9RGPObk1JYT" ..
	"zWVwBBPQt0ueOOTJJCVGUnnp0k+QxyK6+rr1aOWij4JWJ0xkphXPtPKAwpFKjoZyRiyKHlutO3xFVWMVy3nPLZNGrLhh8Vn+z5F9" ..
	"rTFhNOT9D/Mka1QbD2JPcj1GLY2Uz4aLWAnEP8Q78nOqGOQUhMtuVzDk27OhB57TfByVCY2I++aK2QOjNIX8d5PUKkqVcyGilFL6" ..
	"lW38Zfztbchh2mw+bxlSjpazndAcKiKHtSELbA+ELJW1q8GuYdlUt5jEbkqMg8Guf+GSJEtkta4DPP4NleNK+7pm7z2omEzH8eCg" ..
	"SGqyELHgwWcswhJ5NJYVAVAz71CMViFmjTmW2rgzdM6XlDjqCF0rIn8xfeV5Lz073jltLrpjnV2PK3bPu8Czu24fbwkQGt+dPvns" ..
	"cH+IN/c4OSmNuC8ZB8tfvP1A8L5sne5PvVgVUsyCt2CcZDTVjcL+VjT6Qz7Kezd9eMen0N0Xuiaq3jeX0l9vmuIgFzx1TRmd6dgV" ..
	"S9wFZSi20/qiRilqGQSrNRK1MD41oBs0YIdYKi5K9wg86oESPdjK+UnyP9C4gvUrrlxqK7WhLdpllZUqecyU/MfRTZxr+LkSxKWv" ..
	"HxLbL0KdkbT+C9SBAj7GcYS3c0lJ7d9QC8RKaYojdRM1s4mgXfyPbGObXjAKW7RJ97oWPbFYFtrhsckiFuRetcfhkEaJxwJdFoiO" ..
	"z8AeLzHMT6q8IIQ5GRd38Hj+hZfG9FXLE8QXnUzBU7vnCVzxdZwnCl7ddD56SQf7RGi6udM6lKnnJzSAVTXAh0a/I77VRr/Q49vM" ..
	"4Yw/ixFH2EcFco9y9JjgGLFQFfk0mwuMl3jh4sIEiZ2fqSmlcIjph71DC8IPGsZ3bt4XnDbcK3N2xyqS2/NMRV1c/Zen5m25i5vF" ..
	"xu5p49Kv36Mn7hhr+IdI7V694N/+EU6QeYLQEJvS3IQOHj+CKAujrjktHnxqgjJsKGpIh3AI2Z47O/qub5Z62naj+YoLajGPgQgz" ..
	"/63SdT/l8DSsQjbp8L3bCOP8KT8eZvV5FwdLgkaNZCBN5AeZbHuSPk8Su/wcRXP5E9sXBbh84hEJMNA3DF8RLlCufhMUTi5w2ESq" ..
	"SCBgeGRcHOxPjGjHDx0jUB7GjvP/WM64lK871Dk5FreYj2CDFqXovbP/umbNaXxZCM3BueaZ8WKfWtOltd3UrXASBatkWbPXzBIR" ..
	"4gVBqPQYxi7vhblad4rlNNiPpdt/0pp1nzpFzyT/D/9uKn+OVyY7EyDFgLj1xBgXH/Jb16L/xKp9g9boBpUnrZiKoXGfhpNJ8+g/" ..
	"LRBHgluriGseOV4w7IPGlwzl9oJEpEazF30xvLdJ63/CU1RhpQt3RMojfBQrXlzYSD4EG9/btc9/F1DRK4TcYW8Wi+oOSGgCmJWV" ..
	"xIwGhOCHBdS31pz8mQD9Af9dWUZ69TC2fovQ2doZpbhU8Nbe7gQDy7Jt2UHpYMUsUXWtucxoGmrdSe1kFl5hUSNdEbuWuhy/m6fN" ..
	"Vbq36Z/aKHLU8iMgwRFCXlwWqq/t4Ff+s9SDIN0bqCiok0cw1qmzn/aAy2XZm/R6mzQz0s5OzQ+W/6hYWzXC9ybpmLmiB1uQvjH+" ..
	"tYaESl+rkp66NTvDCwDzFSpVDbHWpPbgtacxYrF+dQ5ifyzdF7k+EnqjZgvHmIeFDtKGLAW+PzYkWQS1eVjAmDXmGh+AQyyg5dmK" ..
	"85WzhtBw8IxG8Vrrx2p/z/EdI3PwdO8l7BYVS4miJ6KIc+lFt2ncorKppyNL4UM+2rydBNwecC5MSAfEdqQfoivZ81R6geVnAFnZ" ..
	"QqansqS8ubQY/Iaf6tdRKxMGaxpqhgreTrt3mNgDQIejHAmTAi8zYUox9Ir1hr/LyhyqUZV0HqUwoKr/pcz8e4fxR8+Xb6Zs5Qyp" ..
	"aFkdNNpTIupSWYAwKRGg6tGnznEC/Z9FtoEfKdssRqSc4XyRgRM/5f0kBefzkAT5q8rpGYHzuFhBu89oDopw8TQfs4Y+uHanOC1B" ..
	"q3gAvqekOX1U5NvcuFho19wlDNS+eVSc0rWQBF3lvhrE3J45OEyQCmX/2JEspgXK8IM0w0kA9LlKrQhMmm93JUR6ikwh1gzXrVqW" ..
	"VmK4klmLdi3FOJUCE8Gr0zKnIihsjI2fMXxnfjn9kj54ew/UsGrn0x5E54+2l2xgde4I0xKlzkeXzjhkGFaWkAvXwEMSgKckgxYD" ..
	"sOjX2KTE01SLZlLVpOF3Gxdp/IZqgdEypNiLmC0J1JymjVNaT7vDnvySYCncToXnRZVXwyiWXB+vKaYwWNQlIBL6fbuOoypU2sP5" ..
	"yc53G75jvMnWEBIY1j4kowuL8niBnfmAFt2SCDoFgIjwySy6NIYFjH3PhL8F7SVSzaQNVSwB1UeKMifwEBucgab/S/NiK106hgwZ" ..
	"m8zvQ85CGcYgZksNcCP29Mzo9Og62pZJpteVu/tjl77TIDHVyjNsgcbncv7e1Pzn3Gf9bKk0dLD2GUFrEegw90G7xZ3KyME8CUcy" ..
	"bqA3FZ+xpJqCGo2vrTfiyfGke8xwc7XDupZ0Hu/nmECew8ut7CBFUhBpAZyc4QunUU+wW/GQP65wsnLyvx0l/sKD+Hh0PfyJG6UM" ..
	"Z9vj5f1zkyUJ+LYP+D2dK4tKkvO1MKPXaE4IG+M1BqRYyA+jfOskqX0b1IID/7BgOxm/pn3q0E2FMyVlbnMITk+VC6vKSme4FC6H" ..
	"iNlCuOlZRkkhCKTDrRq2tywVyB/5qERCjwULKpk0fjd/ZaF4kkr7+2tnjvjsdUunPrjtuFq1ijQChYh3OkXdyhGkavyg4H3eED6i" ..
	"WOrUvTM+S3R3CEIFtBzuwFpek48PmJKO3IvrZjLTdS+8XtyTz7fpsBIdCEJAfgVpPmk8uMfOb4PSgoa4KrGdssYi+4Eo/Gsv3n3S" ..
	"5uBDjq5JscP+1lbeT7YxONiDK05N/GeenY6Ey38ogJWYW0I/L4/MfxULIaBKgOd8jKX71aNw6LPq87FWUQ84mOucr17tJyQbP1uX" ..
	"w8nx0bDw/+iTi2ramFQlnipgsxkD4FROSc/ArDAE8mxyijjjXAacu3Fz5zeRjj/dQuJrbxuXeaia47EQeqV1axX03m94W3R11t0M" ..
	"erDoCVKMAHcEzJgw1I+/gPTHs7wdxUVnYpjZYwOvYPmS1qSWJ+Gr74fyFG9IXeHQtw2FT6FTlEQ8EePi79gLsomp/bsdveFH2byK" ..
	"Qa+dhSTvjLZC5wPINE+WOVBhe8nruioEgvW1dg+/14MmkfbTdXlsv1/QSfks2em3fCYu7fCRGv+77IWD08zSoBNfUhksTBQr/usg" ..
	"EngXFuil93VClMcuTfy2RBtdYmuUumDC58mU6W2W2F6U492no6JEDyrhQBqEAxim4tytv6Yftkyb1Eiejt0eN7/wMDQidgMZbMuA" ..
	"AgwD6r9IRp1Ak/YZBFfiTTQpAQL7g3p1HA39VQZh6fNJJzssg7mB3AD4+E9qPMiGPLAXFV3wLSLeTAfZ3AOCTkwoWGQFvKG7DjLN" ..
	""
local PAYLOAD_P2 =
	"mdnYKQ4H+fUx9WPIkEig3F8e/QKNOf7UPBzCObkRenDeMuog6lwvB/xtms9mAWpek6DeJw3BT9lfP3L/Gx8TZ28P33jVPoaNRO2r" ..
	"Wph0bPGE1OFtXvIg5aANgObdR5eOSga+lmLfK9Lq3c73jfXtQgnWYMv6JFuXWP0kGwGOKjijW6x57KtWl1T7AyKOXSdJBhAOSWmb" ..
	"Kl/rEsbubXuRhMYTGBzoxbDHJ8kzPLwQToRtfqAExbmJwAiDye1BXnYwq2cz0y5c9QGBP19+CYIkEv2MgJDc+ABBNvCyrtu+0pqY" ..
	"12Kd8xxt5ccOC6G1L8qY6zaQyA3TEP2+83yZ3iEwUC+tDCzTF+TtKlECzrQxXesX9K2zFuY3ARVv9+dRX7//BSsOEQmbWDamiwbH" ..
	"vHCz5fBa89NCjtuqHYS4CKgOSLIRDY1NGVg7E58CmM/Sj+nY7Hfjtu7IO5ZtwaYIeyEQCH7ZCPuwgP32nWQaEu6orZA/BZQP9QlP" ..
	"gPlg/2J4eBonksijH7tP0yBg4I3h2AIjaZhiPSPUTEimoCvkUGYv5jhwMrqeHuMgqUaNdyWVVhsegLBPwaI+12zL636PCSsD+XTx" ..
	"GLBmE5ZdC9IrODnkfaQmbaR2DiL8Np/Qc+Yfca6FMG7YqteCm8vdaMv7ewv5fCAjF6FsXnWeFgYUadcGUprequhPNZhpQmtlWzGc" ..
	"B/ffbYXCkG8DrzVgQzdSILGdABWMWxbyczmnNl+8tLwdtcA5HB9PXVfxKB7iETNbn7/RRJMyIgUy4Z1U0d/0tgcpWOQhwi9T3A8x" ..
	"d1rkjZxr7pkDLdBLt3yrK/4dUtWkvcMK+pU9mHNehEm3vgI9skLLn3+1r1U0Y1cCd4//MRlUoCG33UWpeIXzdduaLMxK+ByiuC8U" ..
	"9kSgZz4QFzu+tqPx6w7RmbONqhWgCC+DzzxYDg9tnHOVqI3larXSdgUuLq+he9S/GODFKqTrMAUoAW1UVkaGiB+W4WwMYubrMNkS" ..
	"g2Bwle5jJlsV4OpwrQO2M2N8OrnyXqzkBMGuUJuPEIjnbngEbevZSIbGSeXYi/EJKDb1Ktuv26jtugVq/wnD/Y8aWFeGALMHAXD8" ..
	"xWZhMMjO7pkTep0Lnf0b/D93A0cuE56f3Uh8RSD3uMXCWVUrN2D3T5+dvEaEw2raiRbuJF+/gU3L6VNsXU1E72EZaUqFjRxBkHqx" ..
	"CXippRgRoG51Tmd0lLQQtiakFMFlfvK7re6msFBg+wpm7rABS0FIGA98nG3Aya3l7F+lRgmgCdENDLdpQOpmQS0VNzjIuopBSd3+" ..
	"aYi99jXQW7+A78gsq8ZKruSD6J3l+u5ykqLGAkKEpRruhkzz8e6m++c4uJZ1jK9SY28xFBd5StkG8h3O/6GTXznDZgQBtLosCDqV" ..
	"gdAY85egre4dSkqh2tci6D9x+6IH2lRkhpKc9vOupri+kgxiizwgoveQdCh6R6RDdDpYvmaN8GPYLUfmCNUALGB0qoui3YRotgke" ..
	"gFPhoHLFrITGfAJUwYDBwvAS1zutZ3Veo+sM4lu9fBqmU+NFmMG1Qpyz5wa3Ivk00vvAM8QV7DzGRpiOUej1/emHNuW1O1zc+JeM" ..
	"h9R2soT0bS8pwxVfzmmRrPXVnSexxAbZ82kosk9d6oQTIf+CzMSZUy7Uw1F4HFOSvF/AWEZ1h5G03NRZgeKHdBqAWknpLTQsYNCc" ..
	"6tZOehAW8h94si1dXogNVo94dHIux92E9r+2bDZT6uE3cD/CUa0KtyyV9w9fCelwhq4s8/EtPFynuQRz8TPWosipGJ1lVIQd621f" ..
	"GYC7ifgN0gpyPhZ4rTC2l8Trdx7V6OnPsjFgxNX98stZBGk6nAAjFMJ2abHD8eLuTAVtOt2DcVV4OEYqwzk7IPftA6cLUxRbihzO" ..
	"4uiDXsJgie+f+u2sgNfxn8kHaHpk1ChU9rsc1o+2D54WC7wDGSLxVTgoZrmky/jaZs2TWaiSjBHeYGYDQoyqPecStNc6shaV3ZDF" ..
	"qt1demKXrqwe9RsUGq5x2Dyczpx4hVJ5D5Z/9l4Cmuiv7lICNeDpvc+td+9YGST+sm76NsBLC5Y0zR8z7U6S+DxurDYwqDmTY4+v" ..
	"Ju0DnSeoywO7Q6yk16Va/+9UQJoUeCblmVjuqZ9pWag2kwJLL2Nvz2bkg7FESlAEpS93an1/HKOcrpmidAAGVjdaAOqFBJdj4YLU" ..
	"VhLLpEzAAF5TFNtrhqeonVBXGj5RKg36wjkeLDfVC4yhZ1IraRtUPoMgY6hFnr1BsfEZ9nPikvTjyM/Gxsgk4r9JSf2Xfx7pKH5p" ..
	"NGGPoRVsnVqVAPfP0JqAqnNuS4b3smHGdF+5+N4TO5Y+/+XqgH1OxTL7l4UF7GxkkDrfAV/SwiErZM+VQDSxWMTJzoUZkMDB+84O" ..
	"K5nhUErJKCYCPHOUY8KM2iU4Q5IcywN25Erl9OBQPVgwLTVQLVqSA3nrYPyif3jFX3uCuoBzuxOEecYjrOIf51fNN0A9NSdzYa20" ..
	"VgWauXL0DdjQQUyP2eMPf1fJM0Q+fRx0yKXENfMvhr6JuhMD9vtlYsoO5E1dFQenczjEevNZRShwBXhFAXNS71fgWEnHSWwSinQw" ..
	"PPpjzPCgLq+YSwqfbRBccWbCg1JjYVBlnmb6fv/6LRET0/0a4QEXd5+VlIph8xC/5RIU18IaEMI002O4m32PtxpM7/tH9cLhjFcK" ..
	"JMv5YAeYWsJUqwDJo9SeLhCwwC/+//JS0ylGFvxsgUQROwg59FMJVF+a/eBLeo5x2HeyflymBNX1z7qYuFkbkHBwafz7cQDALdjY" ..
	"743IqSOK6TR1NpOol91gmwT3JDfXQ7lfA7U0jhpoq9aV3Nn5BP53CjrSurRbJTI3YTeFH+XMdKiIvVgfRf1iGIT1+sV8PJu87vsK" ..
	"o5j2xK1TtoskGTplYAED6GQ2kUr5uCR7rXXhaIOQlixYEbCNVpZ0/5rrWL6RndCYCzjhy5RUZXHyt56F0a7u2HKywhWSH/zl/bpG" ..
	"TVlGiq8R/5npWNVpUV4LoxX3NKUiDVajAAfBS06HTc9SXx7MLMJ9MIYZLR6YaRnqkTle3Ztux5Xi9ImF4q1BdcGYQj7tcDmHC9ir" ..
	"D04vekLbICBl6ZN1j/zVzSOZSe0BfEhhqzmoEPJIMTigg3l1Jb5UP2/DVjJb5QIHCy1TZMDSxpVnilee/x2X+WcbAZnfrY5Z4K//" ..
	"7C1q9HjbZdNtQYbd4OM1gTk2WGs2rPEW65WRqubb2Oz0+9TOc2O0mjLpYDbAxJ3fr2/8Rd/74a5lzhlvPU+AaENeJxwKloVYPYuo" ..
	"wB6Zs7KbwY74Q+qkNiea7AgPkvy2E8tYhpv17EEmNLuSnALPpOD5NWTTUlp3Hzl4wuyRIxHB5GcQGzCK0d067nzpGAUVJ8+qz//a" ..
	"Y1OeDp8BncKJr/a/jGyybRKZ6HmfSev3kxPhNnOPGkdG944tdLhjEPdgo7TYoBsaItkJVzdQ3bITOqwNPBWuBMHIenBMoYfo3f8T" ..
	"uI3K0uQAXeDvDO5CaVBJhCO3YsBeLycobi7xv9wPD/EwnXoxzhjlfYkUuEgDzrun/vtdMpfAs/IorcJN546KryfGvcysWILQmhaR" ..
	"Xj7anyfzFexqTE7v514kvh9bLSwI00i8czl8zIi/ono2yRIhdvjmczE1LTRbTiSvobMrGIs5InunDLt+2ZMqH2kdjr+WV9lpQ7VP" ..
	"2mgux20yDx8QokF3cx2XscMknuRjVInawm3ep5HRwy1doUMQ5lbqEfw9siJ4NcAI3CwpUnoHjfLKzN4JT3zCgiQeNoM9Gr+ELiYs" ..
	"EPqAH+l463PtPRP4pDO9m6H10d4yb142iOP/t8xl/hEd0VYMkj+SKOjHr28+7LjJlpSoklmGXv8o/m/w6NpInUttdM/qB1nMvnmO" ..
	"h7WCVO+k4eGODBrsdkAm8G/oZqdQjjnVtnkBAksck+4zqiyNz/8wHEQH51t+94BRvp35QUpTbYyseh7vbHl49mx0QsJOA2nlUu9E" ..
	"fL4Cfw6VxJjy29ghsQagji83yQQ7XBt0VfXLHI8IQOGV+Z2QU7SDXze79FOFsf0m74nQFjx4dn+TeZ/oi4J9RAIyhFBy66f/mj3K" ..
	"4QtPMpAVFN1ths4DT/2lRIVAibECsyWOdOyPm6sIVDxtUEtOI+vXZycBIYwhOPeFoH0h/5r3rGkI6hg9XpbJymc9Js8nhrIRFts1" ..
	"MTEH0oHjOL10cqQGNL7ofw8J31mONgwHyBICgV/33tHoYNgg5x6dXMXSUZIDcWB+P8NOF2gH3HvdZRi6kHvR8HeBnSKk+vhp/b/I" ..
	"yCetI6XqW2Gcu+GqbiA0sBcOIWHBYW4ZDnYJ7q+OyHw1izZMXq2RV09Tqod6djN/nzkCKz1NHrj1Q7cRui8OfNqf40OxzxVZol1D" ..
	"b+wKh53LBqAbA0xjzdpONR8elOrdAWgBeWlwY14WYL+f6DEqau4dZS6rNo3+oh4P7PkWx8KeR8KVDa6KZIZI2Trbk/GMsu/Tmu6f" ..
	"zjrtjdkeEfpJuGgW+1Wx6h4RhMyfuKSWt4+LooWg4nesBNAIohBYP1nP6FLWdzXjwIwUMS/LNAHe8SncSRaXaVGJUSX8doI+lO8t" ..
	"iM4S/YBAfGkcfkAbYcjhjoSKQTwTwVh3alITQNNUzSAlhXkaliJsJCYGpT2pbf9KPbPm2EWNkFTCGHWy7v0dOelLd8CfKNMn+lG4" ..
	"EbjmJb+4HSLNSMRC0CZE/AwCHlkzyJM6S0RN6JzXQy+Rlbygp3xBXqGlQJ2J9NDstL+KXaIoFh1IPjrTqEMsn9QEsziKMBjp0dt9" ..
	"TigLyvZM/UHKTVw7yH+V30BPZdQDAQ+K/p5GdUpEGfbGyVVURtH08+ni6nrR1D8zN4oqpYaAP2QWoYGWILiOqoVl3f7E5IUGHMiy" ..
	"GCG3QMmp32MjAFSmF+uyQoGBIXf89WpG2ydpgq7B87uYvx0KebK1RcfP/mn1y7ALgJEboTLWASQKXm1TwVgLdYjc+gpy6+A/BGla" ..
	"wVk1uQlSnSgq4lAa927xtB7VlxtA+K2cWZE8okq53Zu+K67aAQgF6GVPexULSY74Qp5pI0iZrqHjPqeId9oC4fwMl2aMr4GKs0Iw" ..
	"4Yb5iA/X34e5A2vMwuyS3sFTxLJmPv1d/pADkn6qr8pXgTqPPax40DIiUsu9z+dRKanlr3QpyXnR/oOHh/uSpH2GfAdCaItna91l" ..
	"FGgI0WS+Rsce6iY23eKiRAVUtgMMNsGfLIAhDQflB3R7VgjppZA2kihkwVFVyPna+bGgH+OtSw3v7G5L2YSJoULVY1uK8K/0iQcZ" ..
	"jQeGVd/wzIFqVj35xOJ7DZ/dwyjBFRcP6yGc/I+hgEjmJJPnaNMDk+3AW2KeMxwN03qdie5BuzraaT0eQ6VRaqt0V6wJt900ylda" ..
	"/QC5VHAuZgZOMdYHWQ6DpIG2ZM/mz/saqW4oyhzPXJtJS6CqExoI7pMZErzqUBJaV7P11eNruYOehL7WW8DxpjKeYLCR4095u8jd" ..
	"99ae3tI3u0at9vefAn0rrozSZ4yDrl5rGA7pKc2fJpbyirgDeBxPODcCq2wVG34ELDK6prKlQvE1M1UawBIlPXtcC99pc3TlZfrT" ..
	"LVh1D583NRwu3P4QswYDcR1gVGuwZKKs3oIlIesb49ssDEKasQCb/6DSZDOk6XEVqPT0cNTQkq0xggj+OWV47FGL6ZmM6hG222fx" ..
	"PuSd4l7ZRiAOGGE1jVHderDD4E6P0iJaJfLMj30Otb3D9FPLKOLEdo0fWMwHwk6MknH0pE1wKedMX2TaK1u/AKdjI2fE65cZpWb+" ..
	"2wYXlDrc3mdm0ytdTc7+L2zFMXsThROG3GFBCEHhBX2p46lePtHxM2NHKe55FiNImI+lOOil+I1UjoS7fohK1WZDOmSltbYu4J3B" ..
	"9RzDfbIWzKOj0L11PNGJx6NYQnNTWhhP8Atloaoq4jAZRE+8Nnc6dKpW6496kElNiE6EsfYOHMaYONTWRUcatZG325Nzmluq+ty9" ..
	""
local PAYLOAD_P3 =
	"7FmmGrgRlbTGE6tQr0AcCsjMWl8M8j/ZBKcSPBLaR9lQ2mDqCiLFIlqs1jms0ASWJ5e6vd7YqwWtIPr49u/Jy1eKEzrQ1NFbCnWq" ..
	"9jctcqbpiAf9ian0folU5DIqEIAkb3Mn0Y+VKtOFQ/6Zkll/sAhAgoqx2+MHy+jdCk+4tbdvfJ4mN2skyRW/4n2jvEsnO1nn7OXV" ..
	"oyIoAlG2+m7iSxvy9vb9W4ikQ5TAwmw/5nMEbEZt0+3RQ14PxaH7lrC8mptHF2OZRlx50eAJ7OA+vWuVhdYgQyP7GdBCOF8Gheij" ..
	"XgbZLQOKwhaNdMJ/o6NKa8hG46RFMy/Dk21o0AQtc92VR7/QeRyOUmvUjKezoOM/PVxZyC5slo/q6pR1xa7IDPi0ykjUOhJ/0KiX" ..
	"0iggsLQEgCuJwKGAwgI4iwOfr/+sceqRJV+f2ng48hlFNaV4Mg+0ngOua87Z5syZnrlTcVbaOanQeufG8LGvOhlvPycKiw8q5vsc" ..
	"WEs5Stj+T6fe2NRCk+nLKE8Ydtp1fFdubzIEKyjbQoCW+ScaH7/nG+NbB9yMtNbSx1wriAM6Y9KiYsl4BKWJodkSu7hfvCcFmygg" ..
	"dTlO2Y455VUTBdKdwz0iTFjHr/eTz6IC9ZcF2KrY4DPgqE8PP6p/vWp0ANgNiJwG5HRD2j/J5fNHp0JDsJSkSdqPTs6olYyw7T6o" ..
	"kKyBJURaTJyDI+zFXT13E3hNxK/we1jKJHnSjpt5dL8YqCalQfLUuXmOIKhVajx6ahPFjNgUHB0P3IPmnCOezK78b0tJm3f8grSl" ..
	"7nTe96Kv71mOVetJFqugI0bsH8ydTnuMY1KffGftj83TwnijyPS83xkT0hL1/OK8J4pZdakCwz7FRbke1xgfMSOc8i0cjbRGiAej" ..
	"W/7MoSVyiAcxTMH76nZm+MCNB92VWQ1v3ZCgKkI82bPidgaOX1edFcRjzDWSKVrjxQ5YT6yclv+r6AkO+MdOS9clbtdjzlNHJp4K" ..
	"xTjWYhOrdDWNt6/ZPSzEsIDXeKzY/7Aj2/fOnli2mMgNka18R9XlqFOnqQOOmHjwSDoE12n+amn75sG82yEmadZNogFCvEUgRj9h" ..
	"MqYI4L6WCnP2ox4RnVMt8dkoeCH42WD4nCIxUvVtHi0vue+NHCVvTpvsrUrj2R5IDPCWUOXZFrZXzY2jgWAHmID8LQR4Asob4zSL" ..
	"tHAJa/GTYd78J8yfHzitmr7u0lTbHQsI53qJXMX4DS5pdoNYOSxN0SRk2228OI5NMfbVzuxQoYtwmJD0u/e+jfRBc2cW+jEas8U0" ..
	"1HSRs+OMf3bZbUenxRtyMTH1tNn1xEJmw1puLAVBdRgCaLGI55s+J2pLMvK4Ws3UCeXLM1CfjdzUNuR6K5WYI/NvUmQD1jskEaWS" ..
	"bNThDTDDoF7JE01fmmCO+tORKTrtaPxpDKPv/V9K/v+qvkYaXtpxCJwhlLz+BqU3RP3T2f1sJyPiGCDSZg0W/dYcoNJ6mNWIMby0" ..
	"huS/SgY7/jzAuRlIvBTfLLcq+M89BUVwH7wQbinjiC9oF3L06uuGNFgVg6I+RM5zH3K84lSUYqhNLOPvTWhRZ/1iF1EscLPjKirP" ..
	"4ZzYpxozLprFzdSvYTo5D89C/M/E95KirnC7gMIhWDIi8qxSzZd9XHvnPmnkdcK8TaNvL9c6vFIkvrTudX5DDuojPJXJMTJrNSQo" ..
	"lQWyIm5U5RYM+v3KK0yVyObwvc7ueZ+a2svV+JHzmmLPsTOCsc4Crqt1nN+e7F5SQtq5fNzLREdvguoMCCztJ4MK1S5Hkdy0NruT" ..
	"yHhSjUxBccqp4E2HazNU9O32fyvntSqVYmroY/TQ2JdF5vQOaXDVqxf1nCQu5b9y/F36uJUMuZG/eV4IdZAlhkRwc0z0PzWkAOUM" ..
	"xIgMga8CuwiNGNkVi+746JsnYl8RYi/AQiHYeg1gdk9eatuvYpTXj12RDoI7BSGsKRllbLQAUcAMtcd2O1AfcRyDaE0JYUTR2B3E" ..
	"Gk7A0So6UHgFabOdumpCNGLpgTLmZIg8h9TIQr5isye7DJmA03vys7rEjAn/lY9fFe+k2mRA5QVINHNMfGJ3aNSpqzJdin/WLn1D" ..
	"JAh1V+xuO+2EsbaoETYEHhmBAmIiIUOaXW8vvwc65gEMc1iMwG4GSBFUv4tmN1vY8Fu1zp6vquD9ZZrAaYVaX99l6tl/6JcA5YhP" ..
	"lRuZUL7s57aey0Wce9IpS7e2CnpuahN2lfx7wxLySdA1Sp+NazUNBLETG4PAaBwtoA6RskzNmyTnV2nMr1pdweu8ojXUH30NNkwx" ..
	"UIVmrR4ZJAy6nOoIKtdNiPKtAs5+nzByRWuMfo8ksKm4BMgjWSjyt2H9Oib6olDKFXTV3LuVMlNu0EguPGW+iiwjEPXqxDklygEg" ..
	"bI4r0KQKEBTjOKlH4jG69zWPQNvQL6cAX9QPLRZS+p6JBMHEz8QuDMQ81X51LGYFOOgVb8ecQUc2uo81Xg7Pu3KIp3sgOyDwc3Mk" ..
	"NrkEAjigKVdbZu4WxVDjARiQToj3NS4y15E4NmwJH7pdTSCaf3CqRrRfZjOFq8tGfM1LYhjLhmNVP9RgCiretnNVDt7or00ZpE40" ..
	"CpAiv0UlACYOMP2q10l00clxYokfDUf0HxJKu2Bu34cTklBz+v9v87B3YPhA5y/S+Er6ZukYMho7aprWf5Wl5f+P176JChS5Uxyn" ..
	"3hag53yoA9p7SjSJY0K3SsNmMHiWnT4zlg5ec3lWXZZvTfx8AvuMWIm7iMp8QEHqUi69RF6oNx6PjQG1tiVtRO1UIWbVKFucXGP0" ..
	"KXTXK+MfAy574c1+EUMi0Jw2wwxyLN86Xi7Jbi48SujFqtYRjYcPOWAOFEIOzJpE/McJHyp2F5lXFnaD8cORGM15I/AklSQVFLqZ" ..
	"d+OwGFP8RchhLrX9xMixiT9WIIn8LcqV/rL0+kfl6coKwyfTjIjnT/jBR5ivgqrhbMiUhTzD2hpHprREIpgKU147YM3d3kHFt+HY" ..
	"8uv8+pHnptIelM9G8kM8pgVDzxoN9YKAIU96I7oFftt3oRmzJtatFciC5RziVL8/t6mLwfpejYzhsOY0J+deGYfGkCYtKYzpfugw" ..
	"WDyewV4gWqtd0EsIcK5bY+YA8+IMKSNH/FpBSgzcWiu3eYcMYQjIa5dVTBnUR8tzcOkaACJfxcinG0QO8MYd3geok5K8Z0fyiHVN" ..
	"HXXSYHgnIZscsDhow3ri8/2Xgm34Uyw3IZ8f2BLJa6sErWD/FImvUsiA3ZMp6FN3RCP7ANj7nmDq9ZeskKZpZxsfYLHF37mWC3iv" ..
	"z1XEp2Ovhjgq0K7+siEtZS+hy2LymEpn1Oywww3mvMWMVkHFreirroWn11xhO++GERjmKrUAwJhVJqdiHiT3X8stVCjkSPKJ9SgD" ..
	"NkKnTVCQypIzs/QLD26WWv/2OrNTRs+aAqw/0Yj02XcC8ytAyLnpBT23VyblzcEXfckxqmOh85RqzNr3AWSylC8syXC8Mil3nZ31" ..
	"kUaNITE4SV7PfPKR/+SbgfAOzWp68g/04piiN/HyQzbZnn+y82Kw6NDuLw/WCM1NwnMI1qX8rsIoUSLlhGqC8P7g2rkMD0xrw/xI" ..
	"BliH1D33k4ScFgS0fuVmuAP9OHFlSuwwboc8D8vKOFq4BBGGY+0TzPoUKtKBBHcWWTU0Oh0/yrij/Kq6tFcrrxW1PJtp+A+ix41b" ..
	"IvpcF+lTv1nyObb4MHI79/jWf2hPHxf7Z5zjScjVG4wSlElRiJ6il0+uInydWctMyBgy5C+98+Qqw/JoiksuksL3xCEWxWZpL3NO" ..
	"2mIOXlS+AtNsTuk3iACKRNuJE3UdE8tCucYCBgUZy1wiJn4EKGNqo/PNOWXvy+NVGIigl0k7Iqh01XdDLuGydKWU+W7OarH2aZUV" ..
	"kW0DChm7QkbdipRAHjNM/DbJQJDzZSkxnYZTS4wbBoEgLRwBXoU/v0loWKfq2rsPrI6Gtvjp1NSUkCERzjCxsxuQNkoO4FEGUKeV" ..
	"4VezNTD4EyKNgiTJ1oiaroASAHtR2Cx7kPSzSLDd4VTSx/YHb7zGSGi2uiQCChQ32qhMtthqCOTvhvIvtzr7e9Cdda5A903873gF" ..
	"HyNEM7f//+HeVbg8gK9RqT+cR+9YeSUiKyVc6m9b0hfLt/KIE3MZbqyrOdYL31VuvhUXx6Weo0aIcp/RwiOslx7z5NhNfKpXaqdQ" ..
	"PGi+IFWPjNnmdw8ZSXKQMbv+kyAHwCtsSSJbl4CxvjLTccGHTgKErDiIvox+1VIjP75Tegc0+h6BprhvarYlXFyFI6GhjwQTxWFj" ..
	"k7ar6vJj4fLi2Kba5IV/OFUHZPce9/oCvBB9AE6t1e3YQDwnyygs+9JCUapKSZgkGLY8Da+3ckdBtFtdgyW4Syz17Ap824t3h+WH" ..
	"3nHZBz9lrp/2PrPEDE5vnrRpwy/LWwLH0r2CW5d0ZMF9fv+tHdEkY2RPK2wBKNnJqblYs98jG52F9PM3Vwnw6lXus2VrUG9M6LIO" ..
	"Y1OBApAoxlvekD7eGF0K6StNEVISg0/fyRilb/0mkVX58OQoEyoPJ12jy/eG1qHvkEyqwox2FkxiM05HZmWDQOjK+iB3GOtev2Ec" ..
	"ErJ6vYNlnxbAc+fMW1MyzD1PqtVTkpQWBvNJ9tZ/bMv+o8dc60SxlphfLZoxW4EtMpy1wDEN77rjVy8kZXE/y8OpUPyW2Xs635cv" ..
	"1Tzf8Mq0Ypu0TKpOZDn/jvLuQbmwrvJc89D5pvYFRhNRKnR2rBmakQWGrv+1Lp4wQ0z6UpLLvZqmM9VsD/odtm14hSGp2LLX6zE4" ..
	"i3/GGoek9VVDMbbMMb9/6yDAMAMOa6CWSu+rnSfOKsAevO7NRwwj78HAqnyURjSVB1V0zrBqSGez00B4wW9PYQdjYtlQAtZSmALN" ..
	"z9FV3KMOiiEDPnNJC019TkNCKWw/jvnDJPj98Kk3tW3RKJJdIORMyCLw3bqnAIJ+B+q3CBqnDiUbHsPYaSkn5oFeU43yLRB6FUK/" ..
	"nf+kTirYVM6QTcV/DFC1HjA//gT5JqkAMLODghkhU2BRRBSoMWV8xXuY2Jr3ZeHL7RQCAvCM51mkhnGuiHd3RU/0kJg1C4bvRTZO" ..
	"A2RG1LBOTuoANaZ2D/DMufRA+PxzshAQOASuQ1kQj7PU1xv4kizwFFoYxGLgIMHu717P6ZdqoEYbKI9hOdtnuu+S0UU4KqHKVJJC" ..
	"+9IG3UmWdYVGp6TEYt0jWfybvCJSvJPf2lvmsIWLNJF2CJ+whH65gNNEgEgta0VGEGrzMcgj1Jhgqdj46Q+NYqnMkKdWimUh8m+0" ..
	"FnWo7q6IQhxqVuewtlg07YF5MXbZCHwRY92Oy2c+fEkZfmqT4N8vL+z0OywAZwLf6bSfxjLfHXbvQevwclbTAbHkttpIqwtE6Ft3" ..
	"tvQLJHB/g7PtZIrb2OlHH2ux3QgpXQ1lQ4nfNWG0JJk8fYZ2zSR1PJdLnLbAYdnTNsPvScqYveSZBlQCGLaVFTEMIyc7XMoFoX9o" ..
	"n7HwMJL2MVOfkvnHZHS6eqRMRjX6lxfSAdHWmbfnrOzrGmofpuEgiTFoVK/C9tkLVUW5o6Gm5B0SodYTU1ZTlC1fL3Yqb5mtoRh8" ..
	"q6e+vBtiWz1miwTF5DPEC20WxAW14vwAH6sdIPGmUPYlVQoHmSnyxiEfKeDMg8W++Px3ttqdh0KD/Fy/MzsggIyxmUeEqltaxf0j" ..
	"cHVIaI/SqFawyexzpSfDXtm7Y0kXMa2a54Uxv3FtqKaKWstpmm3KDIGcUvXK0SLgPpOcUw+gbI60c2bTV11g+Drso+GqSGAQ8fNm" ..
	"BqtWK+fBR8Zwl6AH9Eh3na+H2Qj7RlICPaP7+cwsgvSMCfOA6xiGClLO9jwmsyExjTJLtCzTgiyI5r3BNmGtJJjs57Npzrgpmhcm" ..
	"IwmsgxFXZQJo/uBVmCRplF5eFn10aobK83M5HQsewRh6FAqFWS9ghdkDoDjFmH9X8v7TNT6KWhTBcgE1SrO3lrubb32B4ZzB7nwr" ..
	""
local PAYLOAD_P4 =
	"3mvhP8sqVmthjHt7PqaymQVeVaTyHwP/dkEObsOSXSEB5WPBP2jTQjiD650FO/83Ad/aSPUrSR23pyBE1ZUCFyJbsH8OuUGnqsuN" ..
	"ZzQq/I21gR1L3TZTonlkXogGqDZGr8IqcAkoB6BOpCZXWa42MzDAIjN5tTN0fj+HHFNNUfEImyV719xjEGq564AI82jiyX2zNXmk" ..
	"AW4FrPA4qV3NurqWy6fDIZBCgI+Krb8AvNVlzlAK/JOqobNf0X3l0e+RETXDvA9Pc8J1kGS/BiTSLDGXWTUcJ9VwOBg+aWOucKPK" ..
	"qiH7fk/moOPT7YtztdLEFPKAUi2TNmji5zwh3JkuVVxRdg4NMdLtHJlZV7NC3xNPeiiohpAsujIBvonTplWqeRVThveL5rNkYdzQ" ..
	"FBacOyD2O2rWnZ1UPMw8J38fxqq5zbu9j1UcdTLDJ/SEVJTYWQV/PxHX7kHGN/hbMLk9BddxLzQh4t8EdY0vMpdSmM0xQShdlueS" ..
	"CikCY0buhmaVpijx/UobtuRGAb24obsYWVqAR29b1GQwMpa8tE1jEq9ajkMnM7giCAJlA/p2bzdcal6vy1g27ntoj0szXVU6eQcV" ..
	"+hg3vp0pD7QOep+VvM0t06bdMFiPUha0+cILZ18Z2kZc2dsTCoIM0+Qd9ZfrI0qbVzBdL8oQqha33hEd1sJdsXBauAsudo+F3ydw" ..
	"e/RD4ih1mM4aI5bGUVaVv3kqO3bR517u/nNe4r5TDj6/YkWtVKX6u0etZUOX2mfDVcWfUhpqVBhc2Q2byGIUVVn86uiNV/7sVevA" ..
	"pyTIFKWlq5jP9tQwRZ1kxUJk9CISOr3f3rHuHk20friLg1CmYmUXUDTri9QH9Egz98K4Dzv05kJL4VOJ2kVcpfNuiQIC76eLePKv" ..
	"n4KVZwjZ1VCxmbHSQf6L73HSHm3uLNN3D5heMnUoLP1vNP+uNz6SIoq5JuyzPFCgy4/505xc4PQbIx5K3Gxy6+0f1BUUgMf81/QB" ..
	"SC8LQ2QVmf4kPcPjdZVwDuFKrNPQeZX++vMNwvzN5ESDdb125oJtwqSpxTNXtmIyIP1sIfMxh59gPD1E6SRVKllIa5LUgk2ndX0D" ..
	"tVna7lFqILG0rQ/D9eoOjmVyJONIF7jXGvHQAYMCmYc+Wl+u0UnfJ0oYyhJSTEd6H1+sy/Hg1YK18zxKW+1bIqNKq8bUQSF3ITav" ..
	"a3V+E+nyvZp1Kh/8I1nujE3iVp3jJsUKDPCZ/dH9pzNR2K3TMjshFBRpehvOyeU4AkDTo9uSbla9JlOegxZDf96SkW2T6TcjW3EZ" ..
	"ym8Bab39claqfRyswrcQ0xSq+VbmnXEHJabr5Jxdt+kGInM0BfZY8MInFQvyXppt4DqWYnWITOr0w8F0NzYpNY9n/DjiSQRL7Ges" ..
	"38VvZ+hVt3JdxwVnVRc0Aj2rGwL4J87J7Hpx0P6BjHmXnAOqsqf4GjLWUD6HcJ9386OXxs/tSCD4R+1Xu7jgiDWxtGTc7xHHgHJY" ..
	"k2cjsLnfJjcMsZ77bZlT26u/7pMqGe3AP2L4N0G22TxSagJKsTrOQ8q929xoTQ45dp3bQIwkWpKyYNpbv9gezxw96AhpGMt20f5t" ..
	"kK3e07UTzi5HZY2OJm7aW813KlrlM1QAineqt+Q3xat/CHyCoPfXj3HThhYFW/FhICiM6YYYrhwccCWwIQbUElMpo5TmwqrV5EAR" ..
	"VP/mB0IP7a7k4tmjVofhTGpOgBeiXWCMRgMpExvn2o6My6Z/cxSNSWaMHFtVF3TxXq8Jt7WZG5pQa9WhjUJPOSOCMfG5cdgj6FKE" ..
	"L1d26YDGJpxOqYdAJ+z1sMqsFxWEOc1B4jG6Xe0UL4HyFSdKiWVcrsj8vzuK+eUQJYIv928rM7UKdU0WpeYh9WMOXvbquGYFjbX1" ..
	"+/d2JDqvKEF/4hHx0uJmiWIAmAxOAz2fvw3wjJV/68Q58LxkN3E73qy3SaCuRVWE5rjQwYTVQn3iITfpe527ld3Pgf8xAhhLELem" ..
	"Rg4OQ38OJhhN3buBq2IzQUYke6N6ufSdP7zWEa81KQNt4QWJ4hL8Ahg59fEu1OiJj7Y5zsvISP/xbNlcsPko26mTNWkF66KkIObB" ..
	"4iMSD0KJPF5V08PISrxbUxaFfj8KpNiCiSHKJilXp3FQoIATJ1U32m6awzdakr6PVhqI32j6DMeV54kbvY4KWzPrD7d6Vy/+ODhx" ..
	"b6kvThTUttG2X6kGwwfmuZ+zYlMqAWzXB8BxN8g+qpkp6xiDoxr3STpbO9MIa0X/mHMSuSVtbcBOz4hVH8m2xogFNEgrhqDDNPsS" ..
	"kOoHcAfJMXbsJgDJZkiqoN7zo/MTGCB6quIHgbR3DNpylI73X3NasmXjye00anrWaDdQMyLYTYEBJyS5j+gu7oTVVW2JXhlCOBXE" ..
	"tmWzRHnGFnH28k6ol0Eb7lPX8zqc2E1O/mx0rIiEDEzAP0i8onsCZ5ivdA0TzYLbWDIrnuhgOH+BiOcdIEsY20700RSRUaBoPUse" ..
	"fJLRmYLi+ihAAyp1Td4n845tPBuTF7nynJ/HefNdTVKV3Y27Yb3nzNHNZteJIewQufy3fKfovBTwsQuFvlnLtx6nBKbEsN5xwibN" ..
	"vfhwXnS8UyelqwdZX6ZeGyzP5rROv+GAGeBQgQy2ZfIbl+GkPOv3yMO1xV7JlaWlF3u+jBc7swxfWVrr5QTd0xNgTOWW4sxKuKw5" ..
	"8kmOs3etR49a1yliFVvkpyWHAuRM2N8J15XIR8EwC9QUO9BSzt3zr+k1XUFnvXNC1d+hJjChMbJjTe+4TTpkwlm1uldTxcPQtTxZ" ..
	"SQq7d3Hya/9ysxNnuIGaaf8C3entHi+LJJ8UBi1FUDCCOEpTioEMvLaZBQz47VSd35lVphdS5HvbL6teg2AGDtfM7KWihi+fsJ1K" ..
	"J0qg+OGsrKhQhpeBIKytXZlFbrYOdgr3GfAReWEgb+kQVc/rTlWPLuN+xczyD7cvgeIbvVsnCytbAepwMIdQbWyXEu50IIton0Vh" ..
	"PxYWcNXzfPA0iMm48GnaO6hgQrdKo9onYKNxQyIc1siI709ZfZXTSWy8a2MMxThjukaKj2jQumuDnJF0+uQaySvV0nW1btZzUVsD" ..
	"KxtX37YaklqrufOztVgJTWE/sOmCXKhW+XfsnYs2c0Lgzqay4wOF7sMJQDgEESY9rY4OFX7IwMI1iMuGeFR1ly2A8vWq285yhYI2" ..
	"MqXZ7slRx4waWZQFs3GpITKJLLkVCdEXks4IA3+nNJMrPODrnRAM+jkxdsX8mWIkkcu1zDcf5CPoCv+ZxPzHXoiflrmiVNEnxoxq" ..
	"TbeLKI3kXP6FPhDIAFp44R+LHpqjVlsgkywNp2CjrfKMqQQTDzukloN77Uq3xUsZ8uxUBYEl+qbWbmQoP8J+0O++F4cOjEmz5Jlu" ..
	"+wD/XxVMmZfY14zWDkEiDvWQCnCgp78hMkyfF5veR5mSf2S0G5g7uU2oJL/jfUFXk8RZJ0ZPjgHgNLOEtMDCClqpKw9q7ExGaGHb" ..
	"llOhY9Nucxgfnjk2nlTU114bQqHaPLy7UCfz2eSmp9BHe+u9dhATDLhiTCsQ7h3l3aMdHzk5IqscAfAReZnrnn2rKVBkj30yGHlG" ..
	"93FpJCxjldse8skPIuhhPa4NhBFLjRHabJjRVGimwaZdc2/40Mar7eEJo/HRbouqdZN1C9PHM+XsZW6DRMZ6oL7qh4aXFjrHuQan" ..
	"WxKuaWIAOpMZoOfImZxmZOkDWTbMXMJTkUl9kwsYpdsJp9KpXwEBdXudlsYq8RwX2DRDMTSEOCvGlUdf/Ptwwl/X8NE1I1xsttVg" ..
	"eMWSD2jYj17m379omLULll2rEG9BqKQ02LTO7sciYco1T0UuGOkOXkQ3iPucJHapL7aS6HHMcjSMX8Xwu2UO0vlUL/lZnDfZqiZc" ..
	"qQdu9gE20Wo03ckMqCq7Xq165OJtB+d3OZ63XbCnhh+vxd5OJ43BlLaXnyJnznrT1CVczdBQNZ9hOrq2HvaqFzeY/vAYz9IB74Va" ..
	"PppiVg5wc6wc3Q7Tn4vwgXsDj6uaqY/MP0gdn24doJh588caqH4bpTA1jAq+rpiedHt80sQ9HYlNcw9RYJIxokJxLRGNHpv+pMTj" ..
	"uP8nYbNocyXOZ3l6/pVfLEh/qeTeblR7ozVSnLYfujUa4StwxgkbP/fpm0jKPMd3Mfg69bu6fI9RX42JTjlV65PINtK0k0FaICFH" ..
	"YXaOr9ga5uhsUSgyS7D5Nl/Bg5Bs5iheJfWG4HCZBlBMZxmGWEbawltxAmxkfAFdnIBG3SgN7qzDkns9UbQQhn/21/Ip64U+yNe3" ..
	"qflYVxOjIHxVMBMky5ph9ebE+hVPCXdEB87Y94vf8of6AMLAkk8FAWHCotw0aJ/85GuBMJ3SrT0wPo3YmI6b7JfwdBrd++8ZKEzd" ..
	"IY+Xj/+sFLOo/Go0AlrQONmnhDo/ksG63y+XBIun3ojjZrg/Jhwu9iEHcuWycfwIoHsynCCJ6IaDa5CIjJ/CHzrxj/HFhlpb5Ln2" ..
	"xMzP5QUYeVa2ghMHWT3OQHXbk7Yub03iVtco1qiEekB+4fTreF3F7GkFzSZe1LRbINcjy+uXi13OY+z7eOMGmC6MYBkmJnuONlgk" ..
	"zTBArVK7gEDfB/wGZVY27Sh4oiPAUcbBKHlyUVVdBj+t+iPxeBN72bukoFTv4Ppyg9ysra/06AMUI+LSljLrFCfvxGhbg6492xEN" ..
	"p5BF5WZN/dK2UamzpsrYmg17ce4dPMFDu47N9aTUqiq/bmdKD9atQRn4LIJPwCzMH167gcIjuWwr9lg3ycbMsM7dTQHfQDxzcDk6" ..
	"DjktJAkxsELxIk0cAn9RqTwTFH+4oW8Z7DNx9uBOuAIul823LC15Gv70NutJnNWgWVJvHtYZa95z28U/fjelKn+bvlT0Zqab8ZIf" ..
	"t8tmy4ngpVecnjTLIf2myvpZ4B1CntNBFdBidbQVFmDyboGEesUqAP1jgkDew4G8YVsnrX5Zs8j20JD++l9ytydP9qqbOsrDZ07S" ..
	"GGyDK90vwUm/11Rj9bE3TcsYRjCY9fSazj4MSVP6WdgBGvqdcR5gngllYZARAUuPhBXhedyQe4Sie/5SACdLQSAEUCJuu0WpRtgT" ..
	"vaMcG+Iq9wQdmdEEvPq97aUsAG+alhiq3gG+iyffIEGqByJfQuHrPabcmUl5xKLYG8+n3pwYaWrUGq1Hcw2vF/2Of77QNo3pY2Qs" ..
	"16i1sJcCAACL5YH3aDfLZTpQQPtF4ZPE7h4hNILET4PUq7ZjlnmoP0y2PLPt0nK4gyOafVwma53P1wemY4kHd/JNGPAvDNbqLqqn" ..
	"JZfsK4/VVqih+xmH7vvUFdJ18azBlRn5RgprE7bAHc114D1UEFEyxPuh8ao70anex3XawfSouHsy10+9ihpGYvg+qKucYI0iQ4gC" ..
	"r0DMbEcZoXZ3g0O5V2Q+6yvDPLvVilPvz6EZpjhmS/FNdfs4gDscUhXQuqWjibgXgdLjba7UAzTGAzAijy92nbvtjM+zzzFcoWak" ..
	"A+24ywA5WmRAuBcS5+5c3sNoL+5AO66y7Tjd2hOEQ0MHCKe3yWpNd9DG/XmyT+x6t1XLjo/22gVC7D+pjOZD/ZTSngt2i8DM/fuQ" ..
	"Jix3NZKeuYf/MTfW+D8YM7fGX99qhT6HCOSmmMq+QkvQ9LrESxKYdgIijMygbxN4+CPj3PUyVyChfJ1d4MaZs9QwkGXVe0L7cx5j" ..
	"RxuP0wWctNSW0qw+AxWaPT4z6ztC5R4mNXRa/5tgdGqNHr4N0Rq3BT1yxGU2ECwBSECoZCTFnrw2W6vq1GdpoUkuYylN//Cn89E8" ..
	"k4FBv9GlqpekBT0D5pNlmnviWJYtpPIfKFeGC51mI+dvcvC5zmzhI9L4xGoZHn1THVWWxt5CMwGK02JtZ22fd4uyYOIJd8dnmM86" ..
	"c0M0dIEzxN9yy1SLms+leAKcLXDrB2faHDcIOLWDN9jKUpna3IFN1Bm85Ygl4dmU1npNTHxa5fqwBbmDTc3OLnNc3jqVKSyk2AiR" ..
	""
local PAYLOAD_P5 =
	"mDC6lDAR69fcTYCbP0OPLPpJOXZnW59h9/86ZgWLaT5FKaPyy6XJd0WXb0EePn3BAH956TQjIQzzcf3vjSq5XwleQ+jbRI7rRXbf" ..
	"2rsUl15pH6HasrGr+Y0v8KBNFknWNXaJJs53OZOWxJ353GyTYUUSuyPZX+EDUBAieXM+7hak8OvMWKjDX62mWiDE9U/3CaJk9ajh" ..
	"RwU8W8vGrbtHWV61KXP0fJKvEmYgy3HjPrcLZ5p37L9lhYLWBsAC7dHUoS9/rLO9MQyoPvHXsuAQVGxWgInCbqr/CNMb1bCJe1um" ..
	"L5+7yK/VyiNIwkWvkczjO6h7ba9xKrfx+DS8W6Vs1FRhZGg0JyWVMaI8wSjbw8Zb9OgEa89gL80Mgfe5bpbfR1D59VNP/tiLOqpm" ..
	"aTv9GnBCIdN7dPiRwns3wTfUx1GIN7xW9ZEDAVGPHp0ca7ZNtOWGWAExnjF+lWzdMket4cvr5gpbujZt9w7CCjXv8QUem8Sdyy2R" ..
	"VAuWfPgvlOjgDBZTQUBE2n7JW5ZgjWFcGnTvi3AQwzCkP80gjw38KHdfnGSB4Sh0v35KZpQ9JirLZGQKR/y9/OO82dJJIgzEkvBA" ..
	"sSUe0Kd6Wc4Yv63Ak56M1kcT8IUckZnHJ4OIyEzMTXu7P5AgcMKl9niaf2pM1vnR610fdYkv1dRQkPC4Y2tC0Q8UgfQgEhFwYCIO" ..
	"DElrx880REJ4zBygrghMvqDaPR/PViJ4DYDUzYNCm0pLWYQtiXGhdahKlvsNcp/OJLTPaw+U2Vul8UaMm4QrDjP9YC2YHDcexVvF" ..
	"zlJvlO+L3oXIzKHl57bGn1M842DiE6PLuQwHflMvfu/PE9MPxchHKQ6ktz0txyjr9UvfhHKqE4wRcjIbP6F8ahNv5T/uh9ncGKA+" ..
	"pYTO/90A/sZ1ILGP2hlGZ0PtMeKN/rsJqQSl4KmqM7Z1jYLWEBih6hrGn6KEjclcxUBAD3TGoXvbYroV268iCFZ78yH4qPBOsYWd" ..
	"XithSbag1lg4sRncDjmPKLeZ3E+92f0pLhFq8fCyqNDZ7lUfOM9uxgpOCFJQ9O3haxc/fHpz4NNPQBvbwJg3XO4qLxq7frm5DMD/" ..
	"8OiN1FQNc7gNAm+TdtlxDrPoBqv4o34w91EnSBA0W3ekHZ3fcW6qu/n6w1IYNFLRntmZloWpB421Sf5MklIPUMAPVSEn7t13v7Gp" ..
	"lw37V10IcMDdZ8R+ZkMzFZqEuZrCLmp71KHss35QDIO9Wms7/8Pwdtwz0w7mEpjxq7eCK6fs/lJBawfUUMQYXXbfXUnTF0InRnAl" ..
	"iCTUedMZZkx1JdiCcao6lvavte/JcDG3tpMao6Low05fT6ztY3drHy1d54MKTQEM3g1hVQdl8xUgdxCV2RAp4jica0l/DKFurUGh" ..
	"9sCvtq4wTc9zSSgfgQWOFq0XayyzfETmu9NbAvWrInzwLGWbRunb1+FLqazkEYJxZJRvc5/tCZBr/h7yDc2jnEBWVlcJOMEyrTEx" ..
	"80fjyOCzRweHD7a+12ZCqMuVeJ56gv7B68lsH8+xbqyNQ56XQ59CYuXVMqGYdN689Kt5Y05ZhXRunyP/PE9fdaKQeJ8hpToRDMrg" ..
	"MC5LYVERcPPsmxk93gGaiwt3MQGNFmYQ6MUcG3+UOdy7H/dzMM283aRP6eP/SGglDty2UY3cRVLvdMGpSEd3wKLFa0iMxFfKVtLc" ..
	"IRDEvGYLNSCuSpj78iCQVHOMOStEJPw2WIvjBWOY/V3nbPSIv6MPHSD5LJQc/qPRas02Lvb9E0eg1acmNvUyqIi83kJf9BPL5zFD" ..
	"hTURgQ5lZfkVYi1C8j/LVD/5gfR7Iw7MlAbIf2SeQf1qhAC2VMh5OAf+nw98jdbyyQZLFv5jlBIsXjXIyeTi/CwdBPFYCxE14iCI" ..
	"Ltm5IqKvjqRWv+ocmVrtV9DTj/aKFb+pfWx1QGXJ+MTJolPUoYiKKHwVPhdBCuS7xmegtE+3bK/A6vvX/WpoUD0aIb+1SQvGE9v0" ..
	"DxzVY9aKyNWL7AVXunNa/ysPF3nJwaJfVD+DmCZ36KKw+xicGLtpHdkvv/rXuJ/VZABq9xxtrtiERtyiY7TCcP5lA+x/NH7N69gH" ..
	"zAh59mYq7z7DZ1YC5Wdo2VuSM6f4wC8z1g8HWhXCSE1ie27jOseuweYQxVRY5F/d66Hup90ywmeIRCxDQJDVYg1MbGA/80u0IK1l" ..
	"d+ZSCS6ugcjptc8TH7wVW4JSu2DVPgfGj60zKl/i4Eahgjrfy21WnOXF7w809qFg3Y9k9mzslmJmJEDSk+6PSzpfFomFrJCjwb+x" ..
	"DmmJFkI9VLXzqen+ZVFivQekTcoZBV1PfdhAuD1diUF1mhh5Pvp4tKwOSE8HzDWUMxf6bXPpLHZ2bxtILgbpeivIULUSqyY/9lIj" ..
	"oHYesq5t5qhjvRqImcre1Ww/Vw1J0IBH8cWxUVqo1QJ1C5REMxC80dA7R6emdbZ5Z6Tz5juiDM0nlvZGd50kyCNrzdaHRWdotXUg" ..
	"GDiVKqPS3/CF+ymJycWunhezO5xI2C4Qwz2yKbOx21OLOkKa6X4bci68vLY7hM1m1eYamG0B7K1vLfQPzXg50rMnevQheFfqZ2+B" ..
	"BrVxRCUsUJDzjOG0AeRuTVxC1QAW1JlIiAUiGQkP9Ce9JBKvGI0qgU0UhLAtcFOBArQME4DZ9Hj1q2xD0UAOqeUhtiWfC7UwbaOl" ..
	"tIOjmxyKMGyZJseGBaUTKOmO2pv8CeoTvqTCmpP7E6zTmVQUhS/fJRxHj6OLem3oOhLLUj9QUAlE6L4wZAs3M3RwhgQhmuw/SckC" ..
	"+Nz4s3C5Essi1nbnqaV3DowgCxdUgn8/zY7Nd78xwMbYBFOoW5fQQbuFLblJwESfDSKH7RJYb1Mfrm6NvcLedlSKlr4zZXxq6Ikl" ..
	"1IKf327mbhYbyc4xpBixpvYaWHvuI1n9Rhhv0iUPOjvF4xqsJhigQL9V4g0FqEBL403fz36QJdlY/hvZtWd789VW0R2o6ahzyjWx" ..
	"BPe7xEUM43smUR5+0AgU41CFC0dUVbwNlWsDXMd/qOEBTuvIiMx+osZ3bpJoGdbORam/uHwRflGhWAk42Xko7DXyXKPRlvRQsQKm" ..
	"TJVGK0TQVTsNXE9aRdf2IKaIIGbHCh4K5r379bvU6NrGOd2siqVZtVg3g9B6a1JPdwTgNExJ8aoW/97UF6j3kz/PIJOiJSdfs0In" ..
	"TIzhy3eL4LrvtxoRoeUmMEgVT81mL40igO/KuqRi1I3iu3j+4Gsg38a7LvIJNEdB4teraTCRDITA+QNfNvIjJ6WPcuUXfa6gVq6h" ..
	"m7J6I0308Q71MTFhgMZCvjJtxTZvve4riEu1Zoi9v4C93YvurL6GLSvTHrue2OzvnDjg2GqiUiU8hZNvh8UtKEvD3mBpFWHgPjP4" ..
	"njfn+p5KId1lWIAqo7Wkj4TRpineZWgkXKwxpxC+OZB2E36C47f5jJx1A9bZ5K4xIkycdK43emeteBCXbavchBnKt9UemKBmA/nw" ..
	"k6Ao23FAlrxW8R7N/nB//y9pGFpDHIoiWWnkmlmjX7J7ZQlgkM7vGwur3j/KnHv/QN5q0ZabUQ3NSqf4vdV0b+qlZGoNhVMztMEX" ..
	"Q7oYgiw7D+qheCUhcUi5UIacLPW42dMB64kcr9LxnVmFw6wz6xGLS1ihC78zTsQJxqJw7vNw4ewwL2UHel+Xp4zqdLEHQfwkf7x3" ..
	"FiAE+HJoMU6NmttjUm1hfUkpKnOAhC/gAg2eDcuZOPxh0FdcpmmXV2CJ4JRvmN006zXh+Gfq+tceTIzbbiDu6R+Gg96HCk0Ocm8b" ..
	"G6YaMkb3hqF+cYGyoLkgaZlvFjKEI0+X+BKmpPWAbcWKJpyPqArpjUzucMYoPkgogwe+mnBZXAigHoRWPnKaTu5ETDBLa+wLheox" ..
	"M3z55udUwHzoQ3MlIoWizhZLRJbS5xytr3LR31Sy0vE+OkaZOihTj0LCF+1I8RA4uDE0az5VPGtyE8gQ9Vwew59fRlnuKJLjZYaw" ..
	"4qVJ30WY0gVkLoq3EE5cIGIZPNJxG4zBtRT1u3GlDvLZNTRA38zeEdPSFLWf0XomI4VLoUrEv8JXiOCNfYzLRRXqxVbOod04ZlGh" ..
	"ULaTUUr0pPaQ5Sk/SmbE5oBtSkbOqGnONhPkBq02uhtGETwEb7ZDjswU9FKYGUvs3NB3PfDB3Jx1MBA0ei5H8ybYzyYTfYNXJX/Z" ..
	"0x4WwTu2rgWx1fl9HzHgOVpEo+RDZiKpmzvdXO0DPxcopeLXhCMIzLJ9Om2SWS+/OrsBtI1lPP9/cNMTUQhvLVa/IfvhDvJoQoys" ..
	"4Iw9IjCBaUZXqq0JTX7wgFm44/dtBYdvgUU2TOwkmVa8LrXP2+8x8CgOx374A+iZWxD+AjbHcGzn7MaTDYA8ssaZN4dvuZ07h1Ze" ..
	"rcVMO+TZCAH3C8Yhqu/vuKUJrEys7eUIxKDDlTU+PaJjLIAJeY09Oyy+MQsStid4NhVC7aPMB0fId4aQuUYF8GHIXwEexYcfxLrk" ..
	"EYhzdoyObqdWCxA5CGtB0qDhklLuQLZF+Rkgj1iMxH066jLPCS4JkGhihynZeUtb6CRYBEyy99ZHrRmjEHgam4EQa4/vqZ5nYg3o" ..
	"o4oneSau4Tp8z3cJ1S2+E5bDFGD3a4LYsmfNE07Cjlw9R4Cx1o5rMBsydJYh/35nmZAe4meCJ0dbrDXOCo48ru3oWozIaMmbIEQo" ..
	"AFxc3GZaTvdhTUXotYhwn1aFxJa/aGAsiuD0J9d83s2FwXFq3G4jSntxHYDqhpNOnK2ftjkOAIIpRA1uEnk8w7JTmVT/GyVn3Ayx" ..
	"AHqgrucUW+BLBIY3NHwUvfnDiz+Rx1K6FIVGabNQcqj7tGMUKNilt1R+qRPPLhxquVIbQg0skheknWdLeLzkkWLDPbw9CBOA0+TW" ..
	"YIwgb/iuRGoDng4E5bQ0wSvp9dNLnjErf/8JP5fcfBVe8/uhQMgvdybzUV+U7qUCgRU2eIaguAM14olEGuTh9yXHyztHG4ZbiEWv" ..
	"fJ5GQ6j5OkzmPqZDnctYFdxs9slJTWgiBeHzjUJIVLg83ZBhbSV9kV6rOJhbIvoNgqUWtmaFAU99fGjxzhwAp9j5Ufx0sWzzJd/O" ..
	"/aEfS0oyTOLxBCd6sZG57XARIGYIFjnhe5qOhrGJd87KktVGGdhDgCXYcmZggsMlMeWGagOF0OPQmGz+HgEiPRqSn7uiWNC6f8PQ" ..
	"ThaB4RkWDzcztwDIBv03e7dEs8SGMvrbqtVpQfwP2i4wm/v6t65GUSRCDe+V6ywlh40gzTOPvE0U8FiT19uLyrSAraZsq2PMWHg5" ..
	"BBhxy9S2JjKAyZPA86uwRPp8gMpNNFbUOFocssArVoxMQvjrV9n3Ibkv9lsjS277Lyr+Owcz+qXsUr8f76Ev3IcLDpCSrmIKmiIf" ..
	"dkWvEaGngkiyE4W5r/iVc4/viUgegjK182toYz4tVcznQQOI7COYj00LhQVaYpp8S2XLRQa7G1QSMrDmlcTH/Z5Hr6lrGl/Y+ygl" ..
	"Ejdn3Cs84O9MMgY8/Tb/wmME5AH2dmZzAusiyqe0EJr2dNgMZ6RrEuT3wQoivs5dcgMU5iJXBAKZ5cvhKiJNfyZN7mL4Lif9jHaN" ..
	"d3wWQqez23EjRLB2CfD2kvTp36CUuv7wtbuUfRGOkJkxI53oL5Ju39/YDc9PeoDxGJKmDPQTiHve5on7MtPfsm7kOplDWwM1aSgG" ..
	"OP3RHUUofakiMP8yGZJWW3zdOhG6btPJ0H2HoTumgdxBx/il07mDbQoOCx4A89KtefrivPeTQBumDdcvTMaEQgQ67V99HgtzVm54" ..
	"6bd9cR45kA0HVh+W5AGR+sCfcsi/g8u3cuf8uobj+ukA/w5Ekhf49tvyV7xKvdgylmHsbsIvGlm2p1vjpi8ViYuFRgWXosi0ysca" ..
	"CYxMLjhik+QXZVWYCE35QYq7dd+Es0X8kwO0DaBa7OUDRJ+7I7xyUIzbJuhkxq+wepKj3PXLdvfUOHgCBWBmyAWUNkgw+e3OcOKi" ..
	""
local PAYLOAD_P6 =
	"YS8jggXQyVfV5LvJtjtSFLzLEEeVpSnfDvNT4BV9Jk/uZNXDepjGTs3DQ7si25Rn77mJ9Jhhe8NeXuPVuP/01AguYDtI2v/8cgT4" ..
	"EF04dHMBYIL/fNvKpnK54XWY3XAQZ2UnG/JzimI0zrp3ebzh0P1CgIQD7+HXDii82kwSFK+m3eumQtsgFPhh4KixCPtYgJMP8eWI" ..
	"S5kEqu1OrXVJHSgEjV25cADNu/qPDPmk96FK81jfPREq7LcOtsLmA9fUvDy5tj+xAUr3Y6MvVk6oaKZrqev+vvL9noKtRDpVK25p" ..
	"rx3NZtR5WA9s9top9+tBCH/1PBqZYnqjuI4M1FJlL89wYjgAIQgCbkMHmG209sf1C/Rm9MNnEo9uI08fgX62Avh+Fl4JeEQbYSVy" ..
	"55HCp5+wpIJgupgvDnEEc4iGs4Z42o2VoOvo5MiDNpXjTMBY35Ga/SxWr+D6pHY/xYc8VWZ3NC/LT9pwLUcKkdiAH+tHXnu0SURv" ..
	"uO82RXsy/L06gDT7grV6zwAs0383WfK6ckd4xFXO7CLt2ePeFZ+0ZkiX4le/qFuxZyXSfUUxGmOEVDiGp0zcwcsXxvoeDtBrH5QN" ..
	"Vj7pyRU1wxiPFLSpqMh5zkzNOhaxo6Jctj4+oBl3rxXzh//twTOK6w42Ve9dlcipfj1L042FWt3Yqi8hx64mT9p6efzsxcxZxbP0" ..
	"IpUUyf4ua2+hqZkFr8Wk6TqiJWfrZ7WWyckzssI/cjff0pB5+k//RS4Gq5kdq5R2inJ7fKgnzeULNQ2csCyiWmmiHazr5FivkEbg" ..
	"K48wOFC/XndIhfnO0ZUUrztskpUMeMgPqTMBXz7alMpgZraRfoKitm8yBQDgOUkGdYQjokIELhCvFDKUjbCmFod1lRcYvHI1PeUg" ..
	"schKZrCXGkAHPYMiT6KfjfF7mQl3BdM0PMek8wYgd64FNTjjjFgLOu0AQgbHRRAASI+X6j8qd/vKSa+1buVihlG9pHO5ty32TPzs" ..
	"CbcE+RMG5xMsVXPc4n08dv0IgEOqRmoi9sLp7TYIs4v7qWq2FDweGU1Qe/0r2567dxAhU8maNE6mhtusFgCNMtFliU5IEeR7boZS" ..
	"V5TPIBj3LCffBS5lZl9t8teh3ssSPKgSsQgxYK3XV1z6nsmjopcwC75RIslAVEU22C/m1IDRTvHAvwS95YI0DIlZXnjapg0WJ3ee" ..
	"JokNo7R+ZzeooQ9oebM7QCjjai9DgClny1C7dThblmSlarn5MUL/e48tMiBMR/05309K8vDd17Wx9JFH9haj8QaIRWIDAIzz/Zin" ..
	"KKJBWEcrWiiNV8SCZ0hlcHxkeknlR3JyTmk+orMAjrDRmrn2w2QJK+rNtFqlmfNME+3ihqfSWrsSs48VSd7GY1cm3gxgSHtd0EKo" ..
	"NjEanQOxHsw+7QtiNEK20sdteYnWqn8OCrFcEwKEAAANPGY5yYVrTsTOUatwrsRCbUE4u8IZhp2gztFqXs+oLkW3NbTbA5jqrQOX" ..
	"CgnsPH0/90LG0+GunNj+RgO1R06E3Z68rZBDT4ge2kBMBBtu0I6aUeqw81W7dUIhgNYjLJazr8AiD52HigXMypa9z5P7p5ECjzVY" ..
	"nyocXsflR/T92bHmXz0wNvdbCQfwomNUpemVuRnAnD1I7YN/oXhbp/Ir2gYhLjTpI5a1QzfJLI3ndBFIcAcXniMB+5j+N5kRLl3c" ..
	"Bb/1Umf6KHgcG0raI5gWT3MeA1GJjtPkbOV6kDi3ihlNW1MLinfpuI4dQK5bSY55BbVjrKD7pcVsh8S0ucXPpGKoXLoeT6C7XyaY" ..
	"9uXtesRDS7svXtkTDT6KbwP3/QytaSFoXYJw07/7X7DyjP6rFPfOWARPHZRtfqCaYteLCgOvGN2Y2PRa3X606/zlU6TJ7aKaJ7aq" ..
	"Dz2aA9EA1fq7eJ/GYO073/fsXBk8QeTTF1bwdQK8192sq/GrhBJq+Ua+k4B8+I9gIC6TCCUGrVubpKYnxqqAcyi8wa+xb4q2DNww" ..
	"dsZBFqGVifaijA/EB/4a42WlBKK7lk59INbIKk0CyArXb2H4VpVBnX6QchY7J/Vjbz/OAkkh665waXs5EjwKnLRQaYcGHHS0jGYw" ..
	"2JcFEidROkRfRWvK3/9TeHohtI4AhPVP09xk+xGz7qITS3n24IsgsZcIYR+N0hBigp1EXB4bMJ5+24MdgL0frTMpZ16/C0ELoVcU" ..
	"R70GU1wCbCz5Al6ouY09iPvbloAS2BpLHoe8en3YZSGwMxHJrAJKifsz/EmkxPKUqxYRYo5gv7DQb+aCQqOF2rePfWlMBUvu0BaU" ..
	"ZhN3ZCGUCa/F/vio9sEnnjE73f4z4+O6B+sb7kS1CCb2iGh/WkBGABsx22KBCieM/y4X18yJLo/FyI1zijtUsr+2kelAmZnaFtD6" ..
	"E8acpbdLYO5eYBdaSzoEsFg/ORbKCgLGrHLu7onds6xrfsw42vm9S6meG0U2Ok2eEuyXOxi0kCVF9kI026evuCYDiIbVuWZtQjnC" ..
	"bM7OjZxLbkr3MNwCVxGbsVf9q2jbaQ+E90OP7+PDVUbz6JYr4dJMTFRnrSgj3w/wKcbcorKGELw5wVheqkFffPC5Na35McJiY5q/" ..
	"dwXmEx3KDzYBRKD01XuNwqD1cSlKB2MqS78yuddSiud6tEov9/w0Zr8a8k66o0sM12YYJQH+bFzxFtihqny79ZNwl+qL6czDS47g" ..
	"wpLtwvLcXX9M565pvMU9vOjLzJtf51AK7jT3rWcK+uLUtf7p1CkeBo7MrZS2c8XfyoGom7pzGACz6ObH5ktCVCGWirEFuqMhlYaP" ..
	"KsX1N51YRvBDDgqMHuFf1fVOpWxFKPraO+1kc7vS7gp5ZvfIfRWkNqUL0cTaku2sJiyOquiU8rhZQKzY+kJxHMSod63Nk0gKlWJf" ..
	"qqGr0T6iS6tqsIAuTEKNZI1YROrF0bbMzs68968F+9QGaaqGn6mKq7eC6RTe75BQvDvp+b9iwcoow6YB4k05jTvJ4OIxLTrDy/ch" ..
	"uMf2OKLDrGa861K98XoaWTObfcO/l+zAh1TqZ/Srv9GfjcVBCkG/95yxarEmEHmYr/jsxUNz/9zjrWE/Z77OAaeUTSoEc+rEFsgO" ..
	"CrzjKWrmYxOCY2ynVWcjENkycR7aNO6e1qk9x4YiBQiSSMk0RPS/L1EWuOg5s4LImrCUx1aZ2g/6a5tYYas4uRG2nfvx/4oo0rVi" ..
	"uWwgRHh4XcG6OlWdAZBi1LbM4vuRMnbm85cZCe09RaUCMLOjDXjdTqPDSlp78WwPnwJwKDQqXShehDaWOZdzOTa181FH/sN1O8Q+" ..
	"avI2z/mF5HXtuoockBU+LNEJhsVhHh+WT4vxmOe7TIxl/yKyNPUg46ftX7/Tl1OvX+JQpfaurZxg4wZmAh8iiACmfF9281XQ3tCX" ..
	"u2OHXIWvSqR0hKNgB0CH0AgbB+WL+BDjJtH1uVqlp+r4Yf9yZ/rR1XLMr9u3IZoQ/MXtX2bxRdD/dG1zqHVJI5L4DtDngPrxBf8D" ..
	"DMjhdWXpt6JPtBTSQeua0nuCTo8XDyslFyVPXSf3OrhfeBhJMHsIGvbMw0Z405UkuBkIZ8HiewyP2XDOAptQfxhsOFiMOPVs+xVd" ..
	"mecNohuOREI3DOf24BGOFbizeOqgirBNS+6lKgDjLV9O85QMhDOC8HO/SoLKFeQAktE9kL1NXmnGNB5s5Gs7hjRwf2b96qvwc3Le" ..
	"3bD2sCfRzAIAMSQC5cSHI7FhNbrfVxWyxgR/aIIKoKvCHcaKYXTmJegpQ/UCnknkwxNvv9MwV4vp0kfwNKKpdKB7xyP5J9CylWH8" ..
	"ei4xyaycwEnGMO8tU6kuPlMVGLq5mA1N5uKwJ1Sh7BYVGF0dzgdaylU3APQqiCPE2zuxLT0wijytCwp8WLv7mwq1zru7xQ7AH/bw" ..
	"K7VSplbkl9P/LXrZ97MXDMl381LsmtwBBO45QttBNI1K61QujJ2muCRATJzxvlD41mgpxT0tpGA9Hys3efr+h+NeJjd9ApdkINPD" ..
	"6Yl/9DdD8GUDokrlvQiI51wwRbFpSdPmKWevd4BIT5NlLzeSuF+a2/3K5BCeT9DZVUtZMnjiPUj5aPQcZ7pikMspf4Je9wAOZJl/" ..
	"DSMw1gv5ty7xm+jLIUFJ/MAv3O74mbw5PKAMSd4bhUmcGdFfaiKt8lWsYmV5WUr++KIrKYr8KIl0zs3Koym2yc6NG72gXgDcfNli" ..
	"GYA/7rHgizzJ9LTjc6XIukjwMXI/PEVALHXqrDsC+uapmeK0ySsknrSaDi0N1mz9JvY4pn7p1defjrZzTo2f/AJjnKlDeEGIpIUG" ..
	"M4B46LtXTLLjvjn6vMexxnG+TAlMPV82FQIpgACZsXRMxKkvLy3S0+DWvETpkUzRwpdHoCPKPGAJAeIuHWJP6g/RFmQRfYKhwMoA" ..
	"6LFTeqH7TPCDsJWF5AfjFbHUb1xlx5ldtDtKMYokXN3xOnIjy67QO/abqM1tISUf7nym624Plf29WC0I6TxMRrLycrORYLV3HJe1" ..
	"h47Ay8vYs7PajbYC6AOPXeUVp3zWcyndIQY2A80FKK1HMaxveih+0XYMV5PH4QK0hdst5ayfFPM/NU5k6/fHTN1LAtcEOYjRTvbG" ..
	"ncG8JkPs8W1QLPbmFCXnLe0YyyGvruHwROj/xPqF/mF73a70PCmqzB5eVzeQZ15t9ZNta2dJJYxBWesKLK3Bb+xkvNZ+7i+bRMgT" ..
	"R7XrlOXc/TXCvjTSRLGbPwnBixCd4VccgrXugu0ajuCQciCLRM/Qu+PeC+ipFjr/1P9aSggE6vn5LjXVG6lI6+ogU5mih12pIQ+O" ..
	"tb0lqlcTpOfaHduK1ddf6eOemn9sQ1R6NzBhD+dK3SOrQBc/o8SFdfxTSrERX1ktMaKZkKAzsbrbEqn8f3afFmw+nDlrKXdgDg0H" ..
	"pxvMocG3S+8T42FldwsFzYw6/rKLRGI4bkRxTg57ZoU8SBkJmIdpPn6X5Hhab28HMZS23OOyma9uAOPNzGkoNUsmWfL3O7iHUHx4" ..
	"H1tUEf28KDLquQVAMUK35lfPMYXAf4eyO981saX8EWEWWEiqzIb+GsI7rf05PkwgmwfkqgNqz6SnIsg/lSgqlPuUOq6znR7qr+I7" ..
	"65tEa52Oj2f8buTDpD2sWnhuKNoDXc54g0En5LmPH2JjdXKhskZ7JBEgBs3bQGtO9UF+sn3XNqXrf4+KB2+HO2na4cDG4FcClb+f" ..
	"TsVpTPcBmMhdsUfX5s4oaPfVkSLjOg4mJyZkDt4WtHx2FJKqJPTeFAYDlwj+zP8XDxIOjc/xewcQu6WK1SrMhpJVe1FnNGigOlTF" ..
	"ox8u4KBywk8lCS13v9Yo3A0madOu+QwY256w8jCeRnAEkU6xrCD+tQcgYxeo/+xdwRHLkOslBqg4NVXRzRTy769ILmoO6e6puGGD" ..
	"9GZl27JTiXmxIPQ4Qd/3ipy1RHItgfi34t/2TQN64cltIt57xK5GsIf8GNn8sLZSEiPBWjKoXuT5R6JAAw+BrLQ+Q3ozgSwxJTXn" ..
	"6oR9hPhr5LxhZ7E9IN3vKSI5NUWXL3DAxnQT9YIdGfsezKqNV0guBczIEitktMX81ZMsceF2QqNRpHG0hqjpBlQL1cdRxG36Kwo7" ..
	"NjVNAQPEZVI6fpl2ojT4cT84gQfUM9husKyUzEq7bFjyFVC7ovZZ4wKPvudf6td8aGM2NLkp3yFqc11IMMkYT7joGd90mTkUK5qw" ..
	"VqzZ1Bi7OXcLH8597nr1+XUm5qwvlqcOYDimlFgiSYC5vFL3Q2mgmJjbL/pVFmgH8VYWGUZ6gLjS9vECq/czV3iFJWSxKjsxPUOn" ..
	"jEDfBhL2/xytBqmyX0IULuZR514HBG5fvHLhFM6ZP9uHrJsUmxbC0t1d5i8QiMise4o2kThtZgfiInwELg0rXm3WIU5f1bPjM26f" ..
	"xPILcwTZwr5xn3+a1aP7u9BL35+KU+3iGPZuN5u/4FykBZiRePZ8kl3xjh6IFOCOO7oAioHoYeDTofokZ2Rj+/k5fVtXVLgWT/UF" ..
	""
local PAYLOAD_P7 =
	"10tXZDdqcobjP5Ts3E/yQLXYmBymcinIkUDWrvtlRmn2vEJqekBoRK5B7HZWSBW3HBj2ipfhtFqhejkJiQOjW01u+ZZQQBhmjee9" ..
	"x9nkImdSYNgQjhEF8ek+TW61Yko6rKTKuf1TLuCjvLwZZp3+Hhad8i4CQm7uHigcF1AGppO3Izz66wSiRXVKh2R6UKw2EdqpYHbH" ..
	"vTe9gtOY//UoIg8izX27pynEESoo5KYDDfPm32dthnE3ek/tRdrVXSYQyxCi1XAfiJN4sm9fmXDoQRS7sJsS5OUUe4rFMXVf4UBs" ..
	"iJOHpI28Z3rzygYBwve3z9S4seQFKnYQP3Mv+Q8hTWZc+R07APTq5n9V+BbPpFLZNaDhHpSdXY8AFrUFc6lS2Zyn49NvQb3JZ3aC" ..
	"sGvvLTKSVhYzoSuSqAKhtG7hWpsI18dIF6WqBJ/gXkI3uAT+Wc2spvmgBH6QftnE7ITQBVsjIl2K+csueeNqGzTi83aU83z/MTFy" ..
	"W6ElKUlCqiUC/grd1U04KL+i/CmsIhi+tP4gNH1PMBLXbcnYKYkGsMdt+pmgBe9h8yUz/SggiKKnURoTXod/vfKn9Kz/+Lwhqt5T" ..
	"Q51ORadSTIezoNJoXZoLMqveG7dMUhtTD/sClSnuH2qU0Mkj83tWDQpwmHNXPFa75DjI3jIGyCp9LGMJA0RUZUiMbxTjBYY56nW+" ..
	"PmiNzMVJUAuUPCt5vhdQa3ReyzhyHgnvwNezhakUy4eTp8P1qURZh3jGRmdMy6PV/Ndue4xJi85UGMMtmeSuGH0vcCV/ohImnZss" ..
	"LeJ0juxUSNKcIOCQSKySa21W/efgeYtlQhpgtWPEfg1//KRrbctJAM2DRLZELsqFEEw84hCqv+elN7b6mDtHderulbGnOhkk1KBT" ..
	"O97E6wOtIzop9Uuo1PTHMgrNDnLjGBhS2S44kDMbNrwNBAUbFo9y2+Lcm3LKi4/JF+999uKKH8U27xzPWC4TdrAxJDlWTZDvIR0p" ..
	"P25FW7ezcF5czBGC5l8qTvYOydsyTrpX43bj3Dwe4WrlJV2cu3QvmKEU1UYrxXCW82KaGDjNhKj5Z1pLPm7mSwzVn0VV0Rxc7YN9" ..
	"kx7xhwRhmCEfDHWjiETa4j1Dh5LP8F56SFvr9Boi3lQeo4LRwdK06PiK8zXW98WpexQ2AdcMHzEil1aaLfMjMjSHpmdgem9Ip0aW" ..
	"6Qgw2r7iDGU/Da4+lK2b8z7A1ffoMX2KnAsrqq+/9db5LsamXNTMEG9uaDrRynsNckkke0CjtzoAM1N4uNgxkLOoB7z/fkkD0drT" ..
	"e9xtr9AAdxCf/MXh/4dnRa6xvvhZg4BCX2O3n1xL4R/cu/QsGbigJunDQx2xHpPgNya5Liwp8mciACAsxWNVwjc3f//IZSLRKZkY" ..
	"+45t3SqIrpNAsdEO14j+jNsghEv2E2Yd6M+RdZEDzX2N7TcgCHX6T2adu1WfbEqO9025Q3LErPL+/bZIEJjMpWGxl36bxCt9H/Xv" ..
	"6WJpsl0nkkvunIrmaU0mYdNSB1FEFD7cnd4U6oMKGLWqTisBUk7X5NXn5emzdnM0mx/MpX4xnkeayPvRRPjh6clt9qo9cwS7H/Gt" ..
	"gFGjuhaN30p0LREt+cs+gg6uH/OCMIe8r2CTyj/tegUPPGq6sdJIpURGDWgjTRu5aXYgRGkkHvFS/8HyGv2r3uQE5VKOZs9Ulmrk" ..
	"clKku3ep1kT57RxJVECqigtMzBtPY0o1AP+fXws7fMztKmTaEkUKCxRRQH0NEC3UkDem4W6p/+V9EkEJGFpXCtoLsoeDsNHtP8cY" ..
	"05YxZWtCo6VOUlVOv6Vos9VKMLaOrChT6XCmFgBmoQtN90B8bwOOQo4XYMKSdRiCj1zEW1pEOV9qj7Jfgln9jt9DimIPjO8uRKiV" ..
	"mzriNmV4F2qagF1VRjU7yNEZJrPhuMxKb+WnLa8rOMQgatRLLIKSEe140Lj8jTCDE4B7s1cNoxieS2pxTMWmBiBYTxyRkRP1YyGP" ..
	"bMNMmLwm4AYDhgKfE75+6pusxQs5XcjcgRoYE37Fec+03tDxCCRxBXFsbdnQXOPnEAz1FqbegOxkpjhjeSEbeW033j9JIsV/rh56" ..
	"H9RToClZHeMRMgBrSkPq9Pb8kHkKljQFLlUZS4AGfZHgBvKBv5wNX5LQMjDYqDi07i4Rd/WIzEAQT+uiZaQhhINbaKNuxwlg4hSq" ..
	"7OB1sTzI1PYAZFBpq/RtdjEO24E9wCBtEWOEyUWV+tSn/2UucIeh/diZ5shgmBv4cvKZPexqzSErQeohE0ww+fK21LJW3CtjHioW" ..
	"H6NhIb159o36gsa5qAu7/qRd5odR2qPPRHeAWM+h+o2/g8sKoSdCPoQy7I6gNlU8khM4GxGV3er4XI7A9lMd3wrGp55o9SyvdPJh" ..
	"Sg0sO9zPRSvoSJ4/m16wbNLdxyBnESjlfz9W71zaJlKb/l5CA++kHCFeMYI+rpH9prcHsL8dBnQH9K1aq9HX8IWh+Dz7uordI6S1" ..
	"JT5vFIV+LRXHAmaQECa8KKTM6MuwxXTlTNhWEPuKIXRLzhmtNG9FbZ8mvGdc3ak8Dsebi1p783DGgllSuIYfHkOiUfXktAKxnz5b" ..
	"JaHEudBtcYsGiiBoKZZTYC/aEWZzAL1ezgIeChreGV9lp+DWXhinDu2/WWcKQ3/yNyN0f141nBJ3OhW+Ww+N76aizpToiOQNikHh" ..
	"o4flm4sp3oBli6LJnu0UVSJNIsdJAO59/l3S1l3mwtFjznuoMMCMS3U0pJ6+hjrGZqQYDf2rrTxevBxRT6StzvsP9jeCzh8UfoKk" ..
	"XQZcoIHVIZMorc1J29SqajMPmLAvkG/lENgRE14/inawlIlEHbQTWZB/epwVbvinhANAF7P2gaeRz60pNwL3mqB1H/uK/44/APWF" ..
	"vvR8SfAwdH58Iq2DWLn8z/op7XIj5SuGLX4lPS3xHLOxAju9WIvd3IFsIHK11F38cBAMXliAOJUyvCbK6IxqAFnFjQlR6YFxKdMh" ..
	"u8e7q9hpEXo67HtPzU42Hu6wWdB7jtkYDj+tL5NtS6Xb+BQLE9eXthjvIfoTaizTzV/Se/FysKT55vYRiNMKr3b+9E3bdZehSTgB" ..
	"58ymqfZvygLbe4lCgsRJ6FgZCiTfeqZXYw8LJxnygGrDjH1HpubcdduM0V6zrHkMuRSY+h1NEHeMIKDDLeb9UdzjiC5iY9m6c4CH" ..
	"awO9VREBQfWyaJJkQn0OVcnC09yKy2VOJkqWoYnUw6b0Nmbuy22KMAZO+oLwck4+x5ARQcb0ll7qMLTD2uOLEdKXfYDspuSxAWex" ..
	"cgM9VlGY75Vq31UIlnpSzYuaHRX0qF8wwwk9gsuQ9M1Ij2kcCtPRSzCN9x2A5elCtFifEMwExAF91G8rPh20hNUl/PnqhG5a9ODA" ..
	"mL9+Xeuddwc1gQ0T9JGLgmUFcPkk9NBgMZ7LWzEVxSHJVkOqQ3+9Dc6dywfohKCYQGL/VdGcZRBxF+haIES3uXa4xBVi2Cb18cWx" ..
	"B+W//9WTCw6j6ipx9K1A6iKRZ9Zxx+820ZqpWS7ooAYXM5mq3Kr5az5Rl0mea0HPIaDiGdez7hSfpPCetxFhsieHP0ng+wV5+c0L" ..
	"GtXBYKIc6aYrHy90wQA8N2RV1k9h4wtNv0noU3hzGMxWgDW323xpJfO2JCBoV9tNVB8lX4BnGXjfIVjTX/Qct4ZGJOXTFPASdGXe" ..
	"GdXithWmUE0qV+4F0N42/IChK1RaY8z7Sv/GDmORVXnXuwPMnoJTFnUqmZFzp6Io7Fm1Fk1SoEkPamMkIJ67yIdoFZqVVFfy+dad" ..
	"q0HonLZEoADycIRccIF/C5iWUMMzFpBFuksPH1CyLivRV5HMRF7CsAin8bl2P5DIVO3osIsV0KsrgPJgo6QSqzZsHwrTlj5MdPvE" ..
	"XsTH31QleaGfmf36awgh3F1yuCiBIrro5O9iQK9AnY+teW5HjQCJ0k5hVi3LxH9S/xmrwhdNY6qfi5/mxqJhVOaVOvnigyh0efSW" ..
	"e21qfd66jBWKHG1r9JvaZv4tTba29sQ5ZVbvshT1K4Fa7Vs2q+ARMs13Ke0lg5EDIaWKbo4Ycgrvp93S/Z85H0akRiJzKwYcdQfV" ..
	"2qR6qVjxBns0qDW/HHvkV2k23BeyzPkVzaIVInv0YADGOSWn2gj2siRW6px8cbJxRByfDNFdifTZs1zHv0r4+Z/ONS6bnRIpTk0J" ..
	"Bt/hj4N/FiiEPlkkB5Bn3CqaNkV/DPs3e5HT7JQH0hH3VyvbAdMQHZkVvV+2X74BWrh+uQ5tiSYj9veGTcKj7pouraJJypMGYrK7" ..
	"VlEhf4yCIZ3yqR9IjQhAF6FQ7G3BjyMsVXvA+tHntWgFR54BQKV30d4e3oF48tVMJaS8UCYjo28WhOdBXDzVZGxvXzcZtcqpfj+E" ..
	"s0z7a6c2d7h4KI6bMxuVUY9wQKxjOSognW/DMVZrLbl37H5XQhRkQDPzLpgx3Et6ielmgpOQLMKVYEVMR5xmK2lhZw1zbel93/O2" ..
	"xwTQkcsCoo7QYPL0LMo2XxAe6OxcFsi/pi4N7N/AjjH+UeJKTdOJidoZYWjan3KFVQiVOH8h/+x297/ET3tLI/RCV9D8EnzbCyP7" ..
	"0+IoOxrRSP2fSevFrb93ysecEINw4veOteuH7CNtQTcdwLKu9RkjojJn1UWOul6/+wxthG2rFTpe9JixKxLWG3ViNjki3eYV4iMd" ..
	"V817EC7XA6GkGt9ScKrhnMpjAvHnVnkLV5Cj3UUeqpdm7m6bR1XcQvxg17zdM+hDIhxy0ZJDWvFB9Gq7h+C1iGQonV5cFzbz5JVF" ..
	"suZzvKAMwGcxYKFpZtNdGqhdd9k/h4jqrzP9nFJUlf5QbsOk4U01wFiaspai9H2SvZQ7zCbvis/mlIG5qky4viGKtUcQ/QyHHhzP" ..
	"YRkqV5ffzTH3c4VDvy+5Zq3KCRNKTIIMVJqBfb3O6p9H2A+zSZEDXtluZn0fUk8Ekk2jZiILKYU9Z+EIpZhnwFtTnFCaVnp/BkRw" ..
	"8R0X/iNWLP0U4XKT1eww5xpobY+/h2LujjUes5BDw1wPMJHKWi1rB7a5cPQ476e/dw9CzAnBgkXh50WTFlLYLHZ+z5oG0FLWj6l+" ..
	"4ZFdYpHCh5QNPt83yzQ2RKsK+s++CQBaWbm3uHipruAS2CC2ryu/X0+qk1TeBD7iHnTbmQI250T1XJ69YXA5T2XrImEASwjudh6w" ..
	"zXhFm3oc+xvgojmnHQ3vhPW2x8AwDXjNqpAaZAUrBaE+8NE7g/4Az4QMpZkkvW0kPNhsOb2Z3Za/tJSELWKyopd1GXAF8Ex76dax" ..
	"8lwK8ifw707xu5Fxlx6fiktGpEX6p67c/XTALrvWEjwx1vUy8j7vaehdLlgZapHyWt/sfnBVake4gHxjuj4jVLvvj6ZqxVqI0SLt" ..
	"0gKZGg2eChYuwWfglC/ppqnDu02MygRVFToeNR21IjO4qFbwz5lf2DzNYczRHBZ3fCqVW1t29J+8O9AUIDEnv4HHFG2cY+fqAog7" ..
	"qOj+rtOEQj1MFkPUiWeurQuVC0qZP8J+bLRFP7cC+BP6L7eRjBZZqeTui/Txznh2WrMeRRupR1WNP6nwQXIvtDznyXnLo/1PKyxs" ..
	"ai2y6qfawTGCQTOqYghtfojk72WWobLwQQQv54ZOEXOsm9/w1v/bzDUk/trESZxN8Fam5H2AwcU6X83Xo/NT7W0jphvco0vB0Six" ..
	"/P4HNC9NZfODFRDbtkPBXGTiU7WkfsxDc/lp9kSfdD7uiG1quRkqU4gCaSjMyJxeL+w5g7SgkXG57tNKw265SD/zeneQ/UfX0nj3" ..
	"YrxibOxXJu1ZxEqKah30G7UxuwoQ8veoVchHuBmtbVlEQKa5B+dqJgPwafcylKhDaEEOpeM+RrzOrORS30p+pQop2/vpqMWerKOS" ..
	"EXi8/GIHXBuUxp0ME3AEdLRggR6UJu6XTtMyZ1k5m66ji2EL5n6OjUEI4uGUmPoyhf0XvJjjekMFZuX/ZnNE+JOrVU2e7D0uBBvj" ..
	""
local PAYLOAD_P8 =
	"bPIL0A2RJr8M/hIHcPQJXb5VHT5FM4h4VlsbZ5s/x2qBaTCPVmgNwkz7yq10hcvqEiK5WbPlJHB63ZnDLMz9EbEr577Co2Vou8jj" ..
	"zKTpWSR4FjrWEnEuCE/4UknXTcZxmV0m/rsuVs/E25yryo7gZje2RDca/clymxBkPmqdRQLtLpytGCHJobjlm0NtL9MD+YysPYbA" ..
	"1lfPt4gfzvouQynTxT9JMDIDUX9fQuhNc7+Ip7IpE8FsY+SErCm+MvKiQMhWyFTMc1NCSD8O7QoqILyI4CbDkaRZDNv82iaVnWkH" ..
	"UJSPeMFcQgmu7hywWF+7+rZcrr5+A+lkU65AD2dFpd6pSmHA8f84kyQzrqECoX6oaKthrtSAw0/7U+lMLEXkXH7UXVWQ2uhxs0JE" ..
	"503nbQWFq+xElMLRIz2iIC7GuFPVmyKpkQKQEmw5wu8i0wqKxoQGAkkxAVtqs18IVaJf0llNjghABPDV5XC4hj3t3IwtBUKjjVqg" ..
	"p5LO5gpprxZUnkDna7Sb+jqAhed/wNt9RN+/4OwSoRihF2JxE3+PYlHi14aRB3Zwp7zWJJ7A/MRR3r98tFw5cTjy4yK3umOpruGu" ..
	"3oe2zjeJbJZWJKgRQA8c+PeFCRJlRdKgjJX8J/bGLZUN39zJrWsY1Nx6N0kGqKuFjbXL22KmmDHn3Bv0VipVRMsitlGXdg6dUaBq" ..
	"Ps7G2IwQ34Bz91KWI3KHSI6OpJvb0pMgKtVE9ETmo28LISGTOiKwaVPjJg6TcSARuKpcsMsaDgJ7A7E/C2DAT/DFeLuT7xMRFNTn" ..
	"jpstAqVNJdJUk665Czz2pFxhns39A69Frn9uSVEvTKDIT2eXLjypjlkkTyLsI7AjmHpe8GWGgfVwKjjYQsxod+aOlf10cN2xhI1G" ..
	"RFE7+QTS4C9jhOsWXjk28ON5X8uz2JBpmr6jvsTqTVs0mLZwN+8IXzqZbrL6V7QwOOludWnL9PGfxqXCX/c71z34Bdb4A+ckDwLg" ..
	"f+NsUy48wQpqWy0SqcozgLFdh6cHETlY2EX/YseJadU+13T/DKLh1IcxCDt67OfHxLiJt+cA02flpj3t9AvsJaR/Z0Q9i2VZtSyN" ..
	"Fl3/JQKPm8r5h1jDT31IlgA4sQgn8jxyMsvwIEj25QmdelDUkSOtUhQejEM4HdrWdIv+p3d/OzimyYYsEuU0Yo87aixOvMSrk6GR" ..
	"9ShCpF1e+EpZ0ZlWIzsqGavUmGLUi1u1Z3ZrUCR+ae7Sp8//U0sTHTTn31m4V6eOwQMIT1hQups9kEPF5cqR7w+xH8lGG76Rq6xz" ..
	"5xMT3LfsNv1Rc5aEOCQHDFa5MJytXZ/JvJam0I8MoEQQ0lAAuLAA5q0/5PwbBGR0MoEBd68MQLA73+Uz8S8zBigumIwidTgTMZy5" ..
	"DIdo4AGIwuWTQB5cdbfw5Pobf78Y3Yni3e7Fq81QA7QRdro4TOURRSi7Jvkv3ZM3RMaN2UjzCWI3T4MDmDpE7Fmn/h8kh18/ayD5" ..
	"kYop/uEZv+yrziP1VAUQgetVPLKcYpt5uxb+7Lb33qld+zy8NQRY7hF1PKkZtFh5ONXrfYMp7wFKCgnsXc3m6r3SA4P5lwpCF2gh" ..
	"+Km6L1DXaYCldF3fjMcZyDREIJtIsOjLH6/rRuaZviBcUZZxPac53Jpl9XrNOG+78UBBvnDjEh4GYA1mF0ZmBsMquDjRI6HZm7f4" ..
	"jeKUSLWoYtiiQdcG9OD0ptpb8kdjT1G5VpF7HHsuok/Mv6IzbE5N9Mr9H8bs+sqoqMIe0UgcXxiUTXmvu3dtKkb4STm/Im4x0e31" ..
	"+KPti1WrUxfEL7QCnMphd8E4UNmyAZ0L8/elu7tw9ejmBi62Y6A/ClTFhJ5jGbwJ2eO6ctfGtLXo6yij0WJrz7RyuoDiKHfOsnzq" ..
	"3fEbPn7Rne4exfN/ZYx31csMWkNEvkLsi+IgRmp2ACfiAelHa3NDLgsiYgdZoYO4+7JoXOiIRk5Xf1YSIBJ1lwQ+rZQTYf+hfvJJ" ..
	"qQTwxRhY+6qfOe8M2e5/nYnKX94a1HNEyjRjebJgAc0CFmyc9EHPPPSWfPbpIp7Q4gu6/WMCLMzWn4S26bTBiWxYoxCehwu/mbsE" ..
	"AXy5nvbctsh9yg6x9RwdfOowk9gREloMAes30bMY3GBz3c7qnH6H63xvWR20bMhLoBW7R05k422wyrAHAhNkybjukOeZhqRVdo8+" ..
	"SAn/GwqyakQBFCWRNc50zqhwlM4jkLnSCHMod1R1Y6dIY+RRUruUeWu+wQPap5ylh/jEZn9H1AaPav/0PaZF0n68RRPTmRdObrdo" ..
	"dI6qGZc43iaaQ9r8YeLu05hVNkePk+FodulbrObLzqOp2vSlRIh51+K8ZE6f07JD7d5okWL2tScyBdaYtiCQTkpRoThNzClqxZbg" ..
	"OrrR7NLefCrduhgyucJZp2V3bhzk/5Roqt6kTnRh6+JfqKD6VRveZxTCYpJzNIWJm9kiUg2lNJl91hW1UsgVMXp2GLXFAWA9XNwq" ..
	"f++XdpBwZ5ICo9cDOcOeyCtD76uk8FNO8Cp3g5WwsM3RWFz15iPuK1Y/FU76i4gsSMryTCBttnL/Vp2caKgz68M4GDT/TMP2VMVB" ..
	"xrGVWV7tecT2u94CUZPwYTn8V89MhkqeKauUcpdai0cn7m1XUCVESqKD0pAxkTbvv974tvD5xLBb5wRdr72MwebKptZeeP4EruV+" ..
	"1YXRlVsY8rXYnXY/BddtaY0uTzt5Q3ULsXKNiLU+L6/Ipa/QEgk8zRG2gR6rsRePz6tTDa2cuHbFXqlx45tnmXh2eHS+IT5GgD9B" ..
	"FMguQa9EJkeTbJn65AalSrBSxgKitDSSZmoHB2YuDLIETX3nxzI3C9R/juRAxeyVPU3yX8Gm4zj4PVvJ05JwW5sC12WYv/5tGByg" ..
	"iZxrYsd/sOL9p+xJ5/4kIKbOvHjHYRO6cj74AWX8kK4gPR8gQjQVnuNkvSD9X9eWw3zivYvf85i2u8gctZKsogosJ2RNPae5rfK8" ..
	"R3GKLIqHU15oSAjXTMQyzPXiEvAhkoHQu3rgvTfr9zNXq2HyuM0WjTXjHPZwQQMSlQfK/XHAeYUKJT3e9LATMFxyp/XlfanMDlTn" ..
	"+A47wvNX4Egk1p/qsxvkEYzt8kjWGFuHDGE1tShnw0uDFIDseh/nNxuAS5WCCiZGUVvFBumzPRne1L7bX5rlRj6MDqhVhQGfGoPo" ..
	"Pwy2ZCmhwvw2zvhHQP1FEz2UmxoIvdseqb2x4Dr6q/vyomog4sllGnGa2vWMuCXy5Wm1Mm9F2ZpOSIxBsxq/6hUdSeAa0cvCRZs/" ..
	"6i2Ff0WJLTWqaOI/oCPBEB3SbMSISLfKWC/y2UL+HGTj/woK70elbWrAt+8XQ4mZNEmS+J0oeub8S54mHZ3LqkLcwcuwGMg6G6Mi" ..
	"/L0NBGH1FDgfDbkxlOiEfBuFwLXMb3BbU0Aic04xsX6sESwnCHc5tWJU+GdHOYoAvcUUhnLjVg71kGSgqqIz6QzaWtq6nj6t2doA" ..
	"gIeRk4vRJmMv9XOxN0NJzK2Y1mSuogbFanE8japfp1mh9VH7PFeKp1uF4Emd4hFxCNl0p6amtV+FqoLSt8oSZidGPb32lSTXxc3p" ..
	"jZZTrcfArA4kkFanuzmOe4P0qOdCW7KhFiXS33ci12I4+jQE9ufLqNCKoTyNU4OsHDSpmrJ8jc4uSSOYgAOhq6Yg6Erg7Ad5VANg" ..
	"Jh+R/eEd9bnM6yvqModCRntyCbiwfM8782EifKvn94BRFkytbj5W/AN7eEI7P1+DfSpOsEt9CclTio4WzF8Q1j0bzG71Goo3BHTD" ..
	"rqtUPMsjOWFvnO2e9QYDR161bddUUvhkisxNWbjkGfGeiP3LH7LeOZFwsDz5fBjtoZ8cR6h7Ql0UvwxBAJchFTkyciTEPx9TBh+/" ..
	"5uNXXkYUat3wZOtnWQnGKKCpuWDZtbMovH9qaJxMhNZj+5jNTLTiC32fw0eUTBDSwEzgG4/jbOUZjoY6eAXXai/tIhuwv/vypNXI" ..
	"cLajCIHiHA2Kt8mbz/e8LGJQ4xFCdjAkzcgdpaQcFR39438OYUf6HIETa9b9RwBwb56zhABLlCEkRUz7jhob8xOGpy9f8pdzkdlU" ..
	"9QX4OCqF9qIIQZi8FzOt1jTd4B6SQU4PPsDIxWewVLSIF3WVaRHf1p6bBeBSmU825e+KJKqc+dQUrAmS1VJrFJEn+oPXC9GamiCY" ..
	"Bz+BGlyb5SuiOnFTYEAcJw+TQmmLLLoAXz/FoDvJ7e+6QIT540ll32JMOdApLwxJdYvPnl+nq/+oDWwCqJVSKLam9PX2w9HXuKM3" ..
	"qsROzEVlIvzBFcwP6v1OrqPks7DViM98gFKqtnj98obMVrJL8ozuKk/rZJC1SfFIowmnvacGHf8s6QxJvcpwofMdJZzCsM7n79Fb" ..
	"h7tIBVtOmtNEaCJPzL1kD/Ag2MGTwSYQ8FQposWV6slP4zLUp5Ygm5UXFYFzvWa6yhRq3lGRxglh+MtXAaS2PfiQWfhVWF3HgmaT" ..
	"0NyNNJ0djl/i3ipUQsim8N6xGR/rDWl97BHYPGMuNWFhJbptGo2ZOUhyEJCndoknigDma8PfhZb6gyuZ5vEpUJ/lzNs1OEiEoWUx" ..
	"RvVKraU/BrUQOK4G0Qs8FNkPXW7Utp4U9L1s97tKZgUBnnUAL1YcWzOiF58Ydq6XSEO1sin8OAREoQWkAzXhx2VVbTBYQ23X+JSd" ..
	"Cj8Z5DfveplZ0VHapKu0YP5ueyFmznAPIGc3zo2DkSZ1lZhOQn4WCwfr7wZXKJzFAbJKzt5fbSMPkKFMGjhiEM/23w/VGDxWIeQC" ..
	"OGy72hYlx0vmPihx7yD9ofnUR9WXGBq9KF95m3qn4VIO0KZKk+vV1CbK2V6LyGEkLn12x8rAtMcApvykWadqQKaFOBg5hhPZEanY" ..
	"6I8nol5tHKSQVMoUaQ8dG20vmF9GaV+QUWsJTWkHzJkpJXTo/Lnh2k2E9F7IKO3wkU4iJoLCC1I47ejU9X10lXQLmOtTojC1jfcx" ..
	"0KQRKWsKi1dtXwrIsluSc7TVPYNFKD9RJJXOE9rk2y6nyCQsAPkeFjQkQVxWkqYuhFGW0v+5eq/I6XoHrlWBnDs1+vyVm80aWJOk" ..
	"7QY+vDVXxHLjHMiiETQDBwvTz2S0Aj5owNHhJpXU08CByxa4Gq+iFnZBxxnR+M8wDImH4BxEOFqLR16dQM5x5gxlDuqKCEOdfVcc" ..
	"gY1pVVjUEyvG9VVhnGRXgxBT6plHTSvgRfjWMM+zT3b+acBrMOTmm1n3MbjWNugHlSLQm5ra7AL5bzRsL670KknL9/Sbh4eGgtCq" ..
	"J2u9GWNI43M/jIC1LQ3xGsLqENSXiGlcEHldqvYmES/bkMVqgqT11n7P6JFIIwmNDhADvK7JTuKmkEOhJ68C2iPsMFAV708D5TDo" ..
	"7+X76zSm0xgX7ldJvx/7oWMflvaL2wkdZWioqhTyQmyPNxlb7IrNsg5V4wPSmEG5XOad5gFuO2PoNd49rARSnDCHcz5ra9O7xKSo" ..
	"JInu2K1gXOUWgdw030eqvOyh2JUIwscEA3m3heBezzqOnxfmOxeqokeQOoRMxItBmZP3NHkCxFaXoTjwD4HoBibutg15xksrb8OU" ..
	"aqHU1o+zwmRwWtPNKAoTox8lNYCZVPbOW+7SMv0ZJgcYMEDd8PpxE4BbC4KzoD37yoT0baH4atrPjtmFnPb9hJGNuVDoqrMGKrBo" ..
	"bkFwTeV/5ybg0hfHCqSBZY7DIKrA7Zyj2rpoOeilQ+mf1v+NAG5W61e76RjNdT2k/iLzdm/bIiE9a/ZPrh62tNGEq++puG71U8c0" ..
	"WEIRcAAriPcJmiykS7fmddQGEJSfQ1OHb/ex764hbpnTk6emri1S7Xs6ptYHWjn1uCQurKgP//8hYaak/pkJzYguY4qG5zf4gZCj" ..
	"qocVooFdkUMfcKMTvpn4r8PNwvL4eHqfe801CYWk+m4q63odAg+6hxPmX49ZDm/PzlOTr9JhOCARngGHONk2qiAnECHr/kTaIuOH" ..
	""
local PAYLOAD_P9 =
	"gTbMhJLRYXiQyf40J496TzfwnkAJ1KyTBxhtLi60uwr0flDt6twLh6X4jDOrey8e4gwyf3BcnFfCAq6t0xCw6j0Fmtw8cgTX1Waw" ..
	"COJoE2IoE3dI4W1NgtdeLY33Tpm53MoD6Zb1wCsDuy+jVmjbJ/972ZipJDwUOo+Olu6zMUsiUPH8zI3+c5LNgRKJ6h4lXh1Udpgw" ..
	"VWAahkS+DbfgZH3yWO4rrrS4GFS6Je0iRHb/zRKnFhb8uyBTEeMOZzpF+V7uv0QcdSRKbT0y4eaCHbDaslMOJ7+vP/KpASnirTT/" ..
	"bDot6ASleUYNFzSy4gvpZTRRDsagp22gR2SJXV36sgqihqH19o7Kcnh+4nyfijMuQhVwBNEXiZtzcbqMZlhsi5MKH72l7glxCrjH" ..
	"AfWnzbnu38xS0epQAgzWJ/ezpvIHWEA401MXTjdv5oQxaD2Lq3tKniQsOcOA2JxrgGSm1wpHPihObc7KVmt+A98n04luUt7B1fzX" ..
	"nNrsFoPyzSbQrOe3qo3JuseekcQRYi0wkwEnFzqsxNEcOEH+N/Vz/A0GstfXIXbdiU2xtHUL+ogi4B070u7TkqWosfVbByqX8gU2" ..
	"i6RMaMg/iI2ykiFhZLaVSYfMvowlInE3OUnsRYto8d3NrCjWb6pqmbiA1lBChEE4PiYpYG1TovIT3X8iDv/zKntW9mHwEUMwszQU" ..
	"nSBmuyfKiI9DhvRkPwDrgrbGV+wJiC/3LuxXNEP9wYpsK9SaDJ8TvEC2mLJywGIv1UCSedCwZkAQDadBNSBr9FTnaDf7HyKqKk1K" ..
	"nMuuJEJK+dz09g1DSP7owMr/p7EOw4xiM1h1kYF7fa0wkhnuUzpyymqYDkCL7RSG3+b3y+wPxLjnYF0PXwfm+Ilhgr/fAW3htfMp" ..
	"BucrMzdZsucvD+0OLAZLjCRxA5+OZOJ5ETJvymZ1/bWO6FPH9lk4AjzXJ/LuicAPPJdr10pBWl+PvFfqTaakL1rz1c1YgAdXefcZ" ..
	"vG01ocHevxjZ7JaqVBNBBsErhCP7+MSJ+bE1jdlj6IXqTdYE5QSNO8nGNaoaSz8pN9q7PtpGd7fbH2vlc4Rpw92Tjhx61NxPuHW5" ..
	"XE+ZIoFHykacmPPBMQXuG88gfAt5ZkjrNWTSbIq0eQS1GqdE+E7rsCvANfaQiHkavVVk40MxipUSrBSc8NoL7ARNRiQ7m+XfXbKe" ..
	"yH02LfWhTTk+vPMVjc6dgMp1/a17pyTvqfqtg/LDD7S0HStP4IsmDcjFxFIIAXg5yQNFD94unc+/OkT0IAIH4eNcp8mLtgs3HmK/" ..
	"6oOrN9u94i3QCE4nWbgXAZcxU99ofFmnOsV1OQ8zQCSPsYHv9ie29PGfyF5q3cbAaS08ewnuvT4TlMXn2hNajTceDANnUgAar7r5" ..
	"SAS883q+OquKiogn5IAHgw/7vVcJDVpuKb8mgXtBuUBDHZ21EhAlU2ei4lv3GwQQGtXbUYogPi7MwJYZtH3svRKgg6/9+FYdKXmc" ..
	"dF63zKmRli1Wl7nxGGjKRwwAY13BwDnmMEuCZsZ4uQG7nKm8Xny3/WmcnzCo7V4CEXCluZ72F19uvhjUDhEkFpmvW1sJ5W/4OIN3" ..
	"g3fh67LTYk3tLwIEJKLiLYgfGImcj+mzIxFMBGSEieDd4WfzH1eMVqq6/5EKvWsCcvl/dknZRUebrUAWb5PLVdOobL2p+2YcaS2H" ..
	"XaMhenASvA1omry6g/vK60vzXGKCR9mybq6j8XxfA4g3vJgL7ZsqzuvPJi+GCHMb4NTqqaLDq691ZVxTH1TlSSpQg0IWj2JhFReS" ..
	"ug8R7J2nS2222JhiI+RR7EqcbAm/znkrlGz9urPEaFhGeUJGvDsHQR2404Zv5crak9GDP0Hr2jWdTAUoPdcl4Cp7tga7KarDedDB" ..
	"ClcAcxzalsURjRULb5oohjFR5pqW4YJysyjBcx7oNUWkgltyYgYiD6dU8SpLpxk7eUwt/VW+jjlMyBSEb7wIpayAKkIdiOOD004+" ..
	"Z2yrIlPHLj2Nk6qYuDP0jFmptwlnbCPFHntx8rqHC0/NqM/TyfdTpxXVjwtiUPbbu3X6abvuWT/b4/seN+u45iT4VABhgatVubBa" ..
	"xR886ouYoaL5WwF85hSvH6YIcGNUj8AiGlhDk/tv/FUgcjNula8eRsyRSx9qOTrqsQjSEvRzY4R8/bzoDaCEsGocC3IK3yJ6IhFQ" ..
	"ZD6vW+eeBvU9SWUlkgT/kQoMBtSdIvVzEVFEQ1DU5lwAkVffw7PjEon987c+J68jV1/8f5GTv/x0X7mqYXLnlWR7a5IimVZrG2wv" ..
	"pXkq643q7m++STc3vDadxxoyFdxvU/qivZrvYMDQCmDqwgnJfSC0+2Rg8aPc0Ks3IpEiYJgE2utSqsbgEpVbP72/1gDCxad2C0Aq" ..
	"5wQPisdnKGNQZP9xRpoU45iK1Sgfj42kXuyTX96UKleMA+cINBa6tNN0tiHqr5eGewwEFDzo7aDcbMn8Mukaw6++8bodhgrz6luw" ..
	"KTaeOFgq6YPl42QiGYVsg1f6L6N7z1iXoMH1gKRZ6/FtRArJY5g8BIM46imFXj2/3z9D01UQnMoM/4j4tzTwmizopTmNRi0d+zgw" ..
	"kXIb1NsflM7EmxVNu9dI+pBJ7zu9DfqNlMTqa9D4lv9BR9Yq+z8eWb/C8IJUPX0n0YfZojWgLEfXPXkQH+VbasbC+5AFvketnCS9" ..
	"BotH1InLofVZPJJrJ5sTWlWKMF5Jf/D5d0exZOEUNzpIT8Yw7yv2kq2Cc7aAX5x39SuGeh3Q5RuKUFCM9SyIbtLgB2L/T9vCtF7o" ..
	"dMQmRg/7wTIQzzMvw8Eu3hBzc35sK9T/01FGYDpas+Ds9DWUBCDTxVPYj+imRM4dpol8uHsGFszBS08l1cVsm1uUhi8jsxx0r4br" ..
	"rRGr0QK8x7UJjtuCmSOcnyu0bVzoeoabnLp6t8FwvMDrhH5kwGBJL5P51yQyvq80EJymlb5iiLQITJmjlrFhVNJyK3bZKjyE2pXp" ..
	"OetocokH37fSbRipyWkuR0ZW7t5NKAeGRFD/xD6kAWelDRffIi+Kyvf7yCNhsz/oyaB7eILqDIXIRMtrwhnAsa4oNIi9Wc3KuYdX" ..
	"gZbwZNaZJAXnxV7s6QtB8V6jBnZmfnvVaLYeIiHpg41fYM0rtkAexKKeLRcX4mDilpkzn5a77xcIZQWX7QgkhAurM9PNnnrV1xDX" ..
	"CGieyfjKwy/ksNlgywURw0cNxYL0F3vtk2JCr8Rm3B9hzcL3D9z58EA/eq+sT1hNruBd4S+QP4buD5gCeG0QK1yuni4obi6ghY27" ..
	"617Q11jCD+DRtby6tLD7bmxuWcWoYJXQzfFF+P/qn9L47YLN55Ut3HTa/0nqPHBov+0wRa/tWNDoGw6HE5MPk6R4MmbnS1qAO55C" ..
	"xUW377HbxqNmIazwrYD9PZY47Y10/EsZ5ywONjylLx9g1DA38/lVjwPw2SM9tE4M+AccyzQtnHiSPYeLpJqmS0nLUgRimrMMge0q" ..
	"F9OTzxjMr4sNaorMAKk6Bd8h+ALHUZqHl5ITok18sd/I5V0R2qoktx3o518UvvjPUoJjt05z5ZSiGvNXKpjoSiVmM6yXwmPnCtDW" ..
	"JIwAPRHtAJ4LfzdXRxL7I4z/nHHdbCPzJWEv5+tjhfcU41FZQ36REs7hppTby045cExmezU2T6ZUKfNUEMWOtj4ppbCi8mZKC7Rb" ..
	"1MQAmvZWpNrDBxPpGWHL8Oc1ZbRYOmDhfa/EkEtDWFjWsZUdDw141z0GUxNH/YdbXQIGl6BVg0bu6Fxd8da6ZgrULfSzNMtT+D4+" ..
	"uIxVf2llieqv5oXF6BcRf5yo3B+7QCJXIHChVxbSybdoFOXHOtgnkh2Q0dNG1twdenQvrjXeJrcltRBnWU4VuXdbv1I7fb4Rwnwl" ..
	"6jhwNEbGDdu5h9WqIQThfLrxLOJFtEYFE87xvh7PczlG3SzrCnpQZqB1TNTq6GplMozXGXwzeidq5kE7oXdcLEwkzmXiUGaxa1kE" ..
	"NQvTD2KgkP2wD0n+WnB9v/bM/MTg+8rS6bXRN5IPMuzien/HmLEtKplBATCSzFsWgDNlfZM6UorbqBpmdMo3Vy9EYv/3sr8WBYkJ" ..
	"4nLdVijns8EeRjoRHtePMhPso9yiUiWmzocXh84SKrjHQ5a3TO9OWAaRQmlOxVk6+M8UlZTxBUT3QygHGJtA4jFkQXVxBc5aOMiS" ..
	"fZP9uYYNn0kOHSSctWTQ1ya/fmoz8qTqo8O/A+LwtbTlGierBK4oCVGUKaniyPulZfh6uu55eMB6e5Lv6N9mz8a2vQ6su2dBlrDi" ..
	"cfUeggmuXsqwh4mEKnxGR0Fm4cA9pk3RPQ7e5YFcROEtHofXtocjvrlXlg65t+Bom4o8xj21q4YJc1aVFoeZNxJOSCHHzwlYkx0r" ..
	"8a2HgQTKCeE/h5+DUD2i/EfPF3WpOIVyxFvnzs0xyB1YHYJdqcrOfn+Wrzjqhkb6w0yTlG1WBOeQMvJc+YREyv+kXp/9qieuEneJ" ..
	"o7VX3bVzqiwP5Sn3xCgKwAmT9cDDwTbqYh25s1v/HvTAbShV7asevc2PR4UmerDrp5QQtb5HkqOP/osQFhtKUugRDQA5YzNnhe0/" ..
	"aGehI+6kUUt0gdm6Fd/W6vRcNlXplrC9xKRNyQwRf7JH6OX8GfyHEfx6GFBVvSCRwlQJVbDCIWqTDLkIcKCZdR0g2qa630NxQc25" ..
	"L5FPqUF6xZUqZzrDzuH6pCf8CDkiQcE2q2695MQwPm/BENWs6PdkHHE2jF6Doa2XrIMzUzPjenJRH2jn7VNp8KbksY1fP0p+F3y+" ..
	"iuJz4xUs7L9+8l4YZwni+zeDctv8fvmQli6tNvYkdNfthrqa5FtDYZUzc1D07eMCVRFSk7F44QcIse+Xm9c0pr2Y981IQsSCMt2m" ..
	"tO68c4Vw/zM/Gg2rEV9xmEMi2yHwqom3RQMK3WSGU28A0jp3ywL3fqyl76DIQ8gQq3a0Fhgdz/Y0zouKhmkMa916QH+tHwXJRgx9" ..
	"Oct5gxYCD8AUYs7gJyVTbtuyohLAalhN2IhGE7NzKKYiLmm8o4qRCI0Q/ZWlOado76VD+nz3dEBt4B+nYLddUR/wnBBsRPPDKKlT" ..
	"cr6+PFP8hVtiC3Y6mklQPSLo59DTjoS7Vzk2Jeqz07gcmzxUvzn99r101HF+eNydmYy6aMMEkMsjlhSDmxf3KedOV5gxq+qsV3WE" ..
	"F+A7aT6L1jyH4BHCpBuVlqyo6UlL7jwo1i39iCzfQ0aNgXq6/HW9JID5u+idHB+pACKfLT48WbHOPH3fLLyZZjvpZQQUJsdfs1s3" ..
	"TVhDqvc+3elQr+CyHhpj25RfdmQnzafkRyqXuMue+y7vQVC8fxHnO6NODSYWhK7OpH6NUd1S2d62u9Isao7XEZFrBxYKtbnE15er" ..
	"d3yX9R7WT8tUr49kFNPUbwIIYSbe/XatRhJcWy6fkej7DCUCub5EoLydt123mcBvqktuHjKN3gRJ9xLVuGUoGFfjLx0vUWFFRczS" ..
	"cAOvyAROdlmmo2hwOjEK9G0+1itVBgYGQpp3ZUzhgc71SV6Iba9r4IqTLKuivGGghTTASyavWbt7gmG7hZuCYa6P/hueFAeWAWZY" ..
	"SWjgLxofJV8fj+W03iI4YxrnykUaoYmHX8jttfMX9AxKHgOgJ+hIfvarvlopIp6V0PgPVsT0XYaXdkUgwq4lUGWHOKlhkphBWW+Y" ..
	"M/YM9R5v2O4G6DekK+Th5Bqi6pbgtvv61senDJKKaMKTZuGnWfIAQWxiP+RBhKWXdnjKsGt6oLXHMd7D9yoDeccJirUpWfJHP8Y8" ..
	"Gmf2GtrIIxomrkuAOA4FX4jvYdfP2G05KjIeF+u6t4umOMMz/14W3IMHdC3TEF1OoeCDbfzl+F/knZbcK4D1Gs4V8Zkn7aAPijdo" ..
	"/z7x56uWku+hPWQ8EqxgVoEo6PoXnDp7CmKeBg/UPRaJ9pK3muS/nI+m+phCwdPWTdJUaIhX1znGpIzrJprFYdoUBBBrNf+TP78w" ..
	""
local PAYLOAD_P10 =
	"WOXwHM/tU6uQPaiRmYQpcFeVQXsmufPZsudxZpbnO2l41OcCY1bK8f4r9qlXnOOlWjQewPTYAAvGI5zvq9ULkDXxHJ7Qcbm0J2fx" ..
	"fkt6g8Zf+7ZbJuvBxd5zD1fy2oIKI9MxptoqtJYGj6hk8Qcif9u8scb3MggxJsWYcmPLTsJ9wVFY3Rn2cXQxB2kH3HTwv79Wyw8G" ..
	"GA+bg9noLZc21D1O6SOcF3Vvxbu4xUSR1pzRh8zhto4zm6k/nmQO1KjRAOGbuna/RbV7Dt3o4UB+ONKBCpmQ/u1QjC1cIAprQWh8" ..
	"Jz7d/n9QvCi9EOR9G0d5cpAC9gSlmAotVNA8HtcdTBUS1tJwBy02VNwUMfGN0CaFWogZ0+oH7oUKcJ5nI2/j0DqIT7JNCsT1sWz0" ..
	"S5Zek1qBDV/YVFCpkAR104XN7oTWr0zNbWSDqksCEX00lgbjTx/tMZiUvk5HkQFe9eOXZQaxkPW3oe5LYKAc8M1TShIogVy00Hwg" ..
	"f0hOAjikJoF7iPmAjjUV+r4/55pfNnsr60C5qGsFZxkeE6FoMJSC1VFRvxVb6pHm2FI7mdxjp/OwjRwm0QyTCojsMAqLZkDXoL+6" ..
	"x9zuJm9Ho5DCAhok87WmKRasSVbOp9bmNmTBVYiclj4Dsr1xPzf152aGzCATH7SIXhT8anMQnyKv3mdHcvQEdTvr0E9YxVk7Gj4G" ..
	"kgKYwClv9ejV4W5h8JJpqPBvjsWpOPWPZ/jivjO4wOPxMg+kP+oUjdB3kus/4bzilS6jOOksG90KowlJ/nin5OEE/jYeH1l+AeRF" ..
	"dsXhOO0mV66kQAe0HPYHRYJTnM2frd1o1+Sj8U/SlMXYzErJT8Jo2WR0MkqbPBHSWIIs8SXhCB3fRe8C67sXCffghZnaAPayL8wU" ..
	"4AjwMuQo9e3IyASDqNBSxuQmuvzcDv/3X6Cj6VMO6EHNwyd384oc5RKkhgb5vgvHwtrJaaVAHVec0hfOWrvfL1bBjXg5F2gcCMT/" ..
	"jmqNXDCeIEmZElSDMaPwyAvJiUT0PsCl3Wlc+filwUpPI6Qv+4SwjBJuqw1lfkUynxH6VVQSx1GnkkRNOuX59j+aG0o0cgZdIM/G" ..
	"d+9Rohs7TUvwjVwPoR5x/WBvonCKg8xY/97dIkGcISLR8TbRD5hWDP6svnLUcH9smUIAK3/5EPJyxPJzg1mxDfXyfWzeJiYcAOmw" ..
	"TgQDofnFcXEdO1Ke2HWQwfXspLsWW52Ep/FH08GA/BOCtmIByDh699Uxn9ADY7i1bjW+IP7x4I0XjrnF3NMOqKyJmv3aJv8gVnYD" ..
	"VGOfuJd5oh8XeMf4sH9OEOmMztZC7dxWye/NHlu2cs8+Z9kILHQxJfXQVoA4MWzuk8YFDu9hoN4t7/1QrudajkADMbaLU57zD+Be" ..
	"5yyULcEJC7cZs86N+yIqq3iKHxWCV7P8TzcU+iWFT4d/tbhVZE7PS1E08bQDTqd3TLk0XP9vEmGIH3rWqiBdD9zeJmfXpnj50zep" ..
	"SoHFB5twRIEZO+9uf88Yseb+6R9XUEcAXiuLRYTaw9/7Vah3C4dg4gStyGZJGoJYAAR2JRD+T1LwvsMPE/kM991/Is/WQTMpmHao" ..
	"RjZgZugUkv8pEqvhYktQLyg7gO5DHmYkvMb5UUt/b0lsDLm8L7kc160wd+VWWqlHz7QEQZy5Rm1PLUfffgXwn1dQN8l4g4x3IMwe" ..
	"i4HkUOZgItY5nqG//LbEY9jSdtdtWaEJF4IIDvj8DPpcQ9q1yR6udpjQsnmC0F5VJWf9t3pSdhMw920LhXzmKcZqda9hZrSEiBUA" ..
	"zQlowD1ot7zRcyA8pRPloE7arIAxfUzvn+QBlDzaNh3W2E1zMS7LCaHVzplJy+N9wzjS+fzrscf4d5lN7zBBLXIVF1pvgoaqzSKS" ..
	"PMuZQsKhb0FTjc0gBojRYSTkrqvajVz4bKtS76Alm0lGxvu2Nq5CqcJeYIezYwRLq6kza0pB3uX6X0l3JZ+hSIx15T2fnfNg8Fh9" ..
	"zwUdYSNW/pWc/Dy/omaUkLksj7McfA8Z2y1bGBglKpTLpDRcsXRw8lN9IsbsLiHNBPxAL9Atd9vOGF42pRnVnHdIa6fkP9Lx/MJu" ..
	"Bdv5ibwYFKjiKYUD8Z9fpC4bHVUmktcznMuuu4prIGFxAA7o0lO1pk+VmNIcVljYWVw09/k58A8zOaDHSXNhEL9HPi4e+uNbw3W3" ..
	"AvNARSQ1MVURljYfCeTRI+RRasTbhmI/qeV/Nrm3lHWmy0pp1+EjOCCCvEb9EFbKH5OTFT/q0Dsg1g9mm9Z92RQizwlzn3c3svnH" ..
	"tJNOWjeWACzapFAV5DGGZ0IhZ8BY7ge4T3wkbSKE6pvPp2dN6kzI2yt6X1701xI+V/qguK2s/e1EUp1rN7ASLLqVNqGA9BC8kBci" ..
	"1tLQfG6bz4Qx64svh9TkyeOAj+milyWRH42YHdFtVkAYpO+xpe5RqlwsoLX64esF6Kh9NgHfVrItLQ2XnWJ2u+2oGsynAjZK2c+w" ..
	"tSMT7OqbVZ0TrfLjDgfMvU0tIlRD7XIpAHA45b/4ZIqLQQGBybvWF3a97smhCVZ+WXYvRemiilC+BNbjeLxCvopqAb6hZLTnUN7f" ..
	"ZughgCAZF/2chX9eKQa5HVRAZOad65AnkqcmXUQim7zMIfIU4XBdlyru+cg+UrMzUiIBl00OhSJezjU0d1Bh4R1mc3O9/fPpm9dP" ..
	"6ZuWcfL+VT7fg7A4NmmzIgr039q9UGMyWZS6OBEMkcST9OMJvDbBb+BfxKMSIxuvVrXrxIPTi7u4LPVNuLUWUSIPwq50p+6+5qT7" ..
	"NlMnCxcs4lG1bM/ms8pPa02mfPdj76OI81KWM6TWkOgIYIhKrxwROsJPhORixv0Qzl8MjR/TnOyX6e/p/12XYLWAN16PfSKrewNd" ..
	"UAQi+n0LTxloM9UgOHDJ/08Qrbr10aSSirXfwkAbqz9/mMCfAQETHAClJDAhezHnQDzddc7mUUk0clhyC5SuGd+Dsb8D1+bHz8Ng" ..
	"ZSk1GXWb/+RvjYJVH/vqXM0OKLAF0XFlyRQqAWoNrrKTh56tyEPcguTEWdGfxicx8WLdsGZ/UVuTnu9uBxtkEfmVk8Ad2eoO+3Rx" ..
	"IuXIQucvLbzuYO4ihafalWUwvIKiVOSRVu8aJqfcn2mqPzD7TBiDlvQCQB2RWqfKFFHISj3bU3oclmjQi/ev4AJrMk6aYheIAE03" ..
	"wd16ZM1UG3AQYOCY9SnUp3b1SP7FCh8wOJyQO3m9jChYn0KXbV+KetI7yYGlnZ7dSlmolCGni1O/iy9OvR4kxHqinnIjV2Fz5kMK" ..
	"F4XAytCERsE3fwANFFycxDJg6tkfsXeaF7vdVUmc6AbFIC8WKFKheJZrf8lLv0fhIiuhKgMiegllXHEx5r8AoCdOIrJTqwA703K2" ..
	"dZmlD4z2r8qCYvHd2PvqrZOt87wcoZL3A4GXXb/Zhrz/9fMrpxa6EqvAVt7Gtn1HBSbKGQFzqguNwozoRa62KzqBWfUs6x4rdJ7K" ..
	"k/7pwMzUEaXYqowjlH9ePIcdMDN72vQssp+QrrGRYwkQUN5C90Yod7c5WYyBuo417beYWOJru05yka0VqGw/dhwLHg9x13suObqu" ..
	"nMcLJriNKUIa3iK5HhCYSqd7p894fU7a/b4Yr2/upHW5LkcDP+TJntyBJb213dv+WyUjgqbwbshwEHMkHG6QhEniFGq+uUlomvt5" ..
	"yxPzH4gSvmWfkXyBDnBKkOi00CPSlP54ZUMxZrT8a6BjdnB4BMYaDND9LmtHxF2OJpEilo6xYRYxtmjTjqJ00lNK6VMmcN3oBfhn" ..
	"RiRB0w2qDIdeeaoHqfaGCy0w5YkHj1p9qrlByMdebqgKu2akrIe8zWUvxZslSYGcCsWCCk2yqSA+QCtO/OrBunnVSYzAQodV/6yk" ..
	"CG7GW6VOnNCM92zJsAIEnCWcE4Tqrcdx9r3+0Wwu96LTXFX9PuGo/3c/Ujb6ZiYjFJu1tjV4PFuAUTorWIBg5JmoO7fdjMU5H4Qt" ..
	"DSxviS/Zj2fD0G8vsAJABYYeP1rMr37ChqvhDRRmykcHpIW6fhpu61i+b2CR2KJHTSclYAWWFaryM0Wv9KF7NOm/kQFI8JBGhiNl" ..
	"7Ag59QK1pyAq52EEsE53JwngPxxRkbeOrJaI0BzTEA/5JEM/jT53B7gUWsAbsqn4wNtDrvRvSuCMwe06cntjvEcE2CUVWWnSEg7y" ..
	"KmE03r0JzWE7Ez/gc4dIg9f2urisxC/mg/0xaBPY/YGIKL+lbh6s/z9H+QMVc50maP8v+lUw1u3aS/d8PYV3ZYxI85/fdnwKOCkg" ..
	"NqpjRVF7hEXYeDkYdSZ5b0sOYx5qz5z7hUyI0ze7LttLhEFscVta1QPVbbwbAGkLo/5DbHUu4xnG18cnsULUlAd2VQTGi96KibpI" ..
	"4YgfZO3vfIzjewvjJZAjOdO9elcYzxiutqHT2mZFfqeTKCA4AB4xFgt91mbMcZfUqLf3w56UXEznwOUmsGxxlxCJkBEYV8otndCe" ..
	"USSrPovysleNeKzaC0g9zhnrePYnA4/gY7KeH0Oa7utOCNWudKr8nPL8e45ijsWv9hAf+bJRpsE3GAK+s8Npf0ooQ+xU2MI+xRzu" ..
	"eFaKC5YrHSuHR8TLVa3kdRWqfPhSaMADf7KBjXdUXnHMtQgsSEz/5+YzBOlqZ9VV7iKjQAVpIV94k+1JjpaxfFou+a1ZGvj4Q9Pj" ..
	"B0bo/y+wL0H1708DSikp+Kxowrzq/9NCv/xVZqhQw6QAhdPCR2DFOyU+jIKUvnuELEn1ehOc9R4p4e2RDlbW6jAaOudlUs0eA+Xf" ..
	"/e/xFQGEZxQaSf+W/oFiEmB9vxrEgnb//1hR3uKxTNM58uAXwSVyueaRI7GGR4z198Hjm/PJ5v4x8i2uRmnDAKmvvQ+vRsoaNJm/" ..
	"nUdoxzKVLiQnFEBiaQ2M3cjYPPD5VpvABeHu8NzVKqaCgIJWxrdE1Y8JMASepX6jxj8V7q97+GEPmXztDl21+gSkPbqDwvUUZPpu" ..
	"U8P1E5q82jpDuiLeBFUf9mbnTbNH3+AUZZoc+KRPrcBDni8Sm7213MyXX22Lxsj+lI8ftLdqToHd/wyV/V2ozYMoQHh7+zyt+f9i" ..
	"qqeRLhL+7vEb4Yaz6YqzKe9m0o44OgJ+oP+JmAOMyBcjcRV4RYY+0c61EMVBHx7fLm3M23PJjOrwR47u8EPUIIgmaUgX0GbHOpKw" ..
	"tUcx97PWdQY5UhqoP0A7XUi8XzC/Ld6kElZPh2j7q3vYapO6lNG6GoE58hUUugEKJCkY9NC8laozJmx7Cd5Zw/DPqMb4sxDdc0p0" ..
	"dYbnDOvHtnkgDw7x0TK3wlU4ZYPf7JPMs+G+p2+aRmZAO7xQySpuMKMW2OCRe7oWVlydjtum2CdWs7fiIvEEuJ9dgdSY3yq3jHUL" ..
	"wR0ykkq3mLXJPQ20rWSeKGkC8nFc/b1ulR3zfGeZhyuDDQEYC0TT7YXty9qU5N/IX5bE+w6RKg/PkrZ5HzJpKodSmSvVT9sZ0vp+" ..
	"3MRpgRmGaqRG/vcpNOdQ+pxLYwzvoysiClKdxJYnjHLHnsU8j9XpodQtyqMbkf+KHD3NastD1Db+mObHNI8lPx/w2QCJLvKQ5xGp" ..
	"2pProXjkdK6woShUWSLIHH5po+Sc3JICqAT6BExA1oCsgnOCMASnpH3PLPnSgp7f6nsPz16Adh25FBqM0F3jYCnzM+PR3vnhCtV1" ..
	"iXwfAZO9AdW8Hh03DmA3nzXA+r9G2nKwdREHh2ZC6eDu2MwwwTSFkV6YnWMCcW9YcsLQMF5xii6EgST0kYbNlc3Fjphx+g4McYRY" ..
	"6p1M5a8DDrDO5FJaLxkhvwhM0IkR1vEk7D40DeWTTs1U0B46YKrW9yU1psDO3x6ML8FZPgxD+jxJfQCQqWmnTKTqoIHs6w67aBAO" ..
	"/a9Jk4inTKAMR741LeKAaM7Modkay0cYir3zW/fWlAT2726MURtmcQsb/P3oESRMdGAuSUXRKF6JUcDq0ABajBbCJINTvOIqMis/" ..
	""
local PAYLOAD_P11 =
	"sM3k7ckKk0obniU+tSGFLGyha0q8kpTvxtn6NEVYBKJIP7NttbZxj06GErAxGsp5+tWgzTGy0gpYMsccBSLniC4VUUVUUipqQHus" ..
	"mL67w+qomKu1C8zG576MDH1h/d0SEW1mMDyXoLZGkNSE/AhpZ0IY0H6YkQLxahBCC2jlVlvi05KtDhYQUfC/C0ajE4JayI/wyxdf" ..
	"NVsQP77mQQ5GrMvytjb9rB9zzf96adNXy2ezhpLec87A8+v5L4lNXYgEnHpxWlyva1ehJ3FVaMyqXp5PqktvccJdsmgbJhHsci3k" ..
	"5/DQAGvnZXKZogk5nBhXmHMd6JhXi4sfmC/IRmLAWrY1PPEEoP3RdCQxVYVzT9sx3zvaq6iOmRX9NN2cijAV6VR4880vMlzQgOgA" ..
	"tvkpWV66eNbepVKtLdMkLHR/x/M5cTOy6SeAmG/W+NxbC3kGun4HzaMwSKMKmsU12lnOKwO6umDZDbqtJLpkBN3E23sItGdJZ9cf" ..
	"XoA0qAnbdFaXqv687mW4gXN9MZ39HA26Qt8WT7Kic4TY55/nKYuzYyeNJePoTFRFeaui1siroEXn49SY2KxpA3sis+gqEW39Fm73" ..
	"+Rmi7aErV4E+cgwYjm9TM9FheD1ATbbFA3kNRdFrqNpt5kbAWvLKqUDRZvafKDPQsM3R7NERbA3VMKS+DSppog7cxs7K3XrmaCfO" ..
	"yGfgSspTzfzLs06DnZIJCPZlge8dgYVojbMPyDRjevEqyn1YEPD5hblXIm73ENyNpmGp/fh7aL0NpQqJXHpd42hInFZeCgbJnrRc" ..
	"No+BAw7AjOf73J/000bLn0XaXoWK6t7lHsf5eN+m3aPveuT3Wqhg6FzqkTejqKXUsBocPQ5lhbVbEV6vYQYK4yCLQ8pqaSOYXS1P" ..
	"zDiN+uGitlkzdL5pAQHBti9vEPq2XvgE9dkJdhNhp3hJrU8lUK6qxf3b1/x/S4o8oCCOsytsrT99TiGZr8/1Hrze9/wH/2SLSzCY" ..
	"/j5Z4A+sB45z8tB8rvuJU2gsqSrO09oyF17eb9neo64TDMHGG4Bd8RrfLYIFLNTDjiXaek7sigtu+XkWlrrIzsVqq8kc36FOtjRz" ..
	"+Egy35Bvcb5MR2ebv+cYW0gYk5hMh3xFb44iyJ0M0zwBafIJkBVtU9/KikfsxccbvnZnw6jP7aeYn+6ckSglGcVFCOmfDhChSyOg" ..
	"nrZtF9eR3yz3KWd+sIGTEFQXS5roKNifqn++nyDQMoujSvOfFW+Bs8aBi59ehmyOFo5P15Ge5HLL2HWYZ0LmXiPGE8PaO5vkwtlE" ..
	"2QZ6z+IaMfS7Et4vQKffSkOqUHELqRIkoVPrvtte7CB7saZc1OVX/BHPlmDGOwo1iYg6f8DAQUWBbtOqHuwuYGFpkw0/OmkpCZS0" ..
	"JNwwglZpghauv1gyJB9ULs9JPf0ioqxnZhGY5sv1onpnveVL/bcbR0IBPwEejVUV9AF0FHAlC2TIHSP1xS4n2QpIb7b1Q1rbHab7" ..
	"RAhCufJI543PlW0wt5N2eIBoZ7XG3Hbd4UHL0bYC1yrWwU4geE/bMhdVZycP+RwaAwkjUIk5+xP+5arWG134zCESPputfIq5l4tb" ..
	"f88Nax1ZwSX9UqOSEXSinVTFZQIe/mHxdZh4zUgx2aTlV4OKDVka+2MHkGPtj3UJkTAK1ZIVmz/R/UO4QNUCq7NDmKgjmIXOT5sO" ..
	"5duBddPTSp18YbpYzaWK5RMecCfDZfb7uns2EfT8OURLKSXXOxrbzayGWIgNvgYmLIJBPc7TB0ArSuhCae2YRcnr/6RE5i0XLj52" ..
	"+Ai5JO2kYg/1FpI1LS/6bH0JrdJgaNvncStDkh0xz8QdQLmgT/9XYag1l0cNfPqlOeC13r/Cm2we+FMDpc5axTrscfHVoYSeylpG" ..
	"ziQbjlJbs6oew9IXgskLv/emhVh9SkpKlnSBz8ZqGImPWYTR40Ejm4ubjWTj2lI+8zm1uMUbmy9bK2jXXzkfXKuwtNBrWmHAB568" ..
	"FWSelgp7OuWVccXa2Vt7rfynkZFWwLJxSYUx83EHPuCXo/91bnS8h70ne+XAM1UsGVjyTje1nfJAHHqJCo66ckMHZEIGu8OmqbLa" ..
	"jGuc8l663oUoC33LFLws6Gqhih6o9/Hk5ohYoNrqTEnOMO5Gkc1zRv7et4nCOzrRliZ9e35fcIzUUFzL7N5BuLas1RosMcEO4/Ki" ..
	"pQ0BlmsvgcvsoqFZBwNR19omPprLgHyDpmPIkJ/68qSrjktZtIUPxhab581/wMZvXEucH0P+HvtZLzb5FWPYztnHoSI2c8IOss9T" ..
	"WPO8e7pjlqoWRliAHGujXhhB6SWqexJR2hRcSMbATd0vLrikuiqUsM8pRaHf5Y+UAIdMRrLvRbl0Z9Hv+T4/XUIOsUk0qlYgv8AO" ..
	"5yooopIMinBvAy/awGUuHAPmVWg7PT1pOXmSXDFrGuWDEh+lgQDtyQT39tAWZYX3ktTt+eVtSsSm44BEGVbBhI/iPNamaMPc34K4" ..
	"WXuY3pjMayexu28YEkPVMQiPnKGt68RO2UHI+M3ki0zj7ew+YzVj4XS0nRe6i+WOIRPffcpDd05d4KgL7yxSblDjvZPPtOd7eO2M" ..
	"jbp528uDA7vFRdNGFT5DOhWXChewbwt1L6OxLDIihoPtu3NgGeNwLYuMCoGYLQLmixoXrumG6lfA7+qJfjfxClSOiwbIXUXcxWdK" ..
	"uGY16tG30tTysjG/NcIeykIyI2jwKz5L5t6vD/XEO0HD3oZnAyVrDkOYR0OvbpPuy5zqf2yEuyQKSlh4G4q5+K1//Lh0Uqur8tfC" ..
	"cAxJZSJWV4Zggu96mnYzRlF9QQ+aqHRdYvuNIT2B0/AZR9wUJEU6zJKmQzHNB/YTD9tXVxJAFz9Nc9/ehaUGFZRvuzUSokExEKsd" ..
	"03Iq/LWMp68NvBWOF5HupdGfiROESYe86VKxGvz6vGQ10RqqTaxZm3m3sIDup+5oUM/fDZ3JPnr2dGBSPaVi/GvJweXlGnVsnrTG" ..
	"zmS+8aEytgr6Cmk5SGsr3Q8NIwrvRptHXNmDBJzEeAL1r8kOYR1rcLyx63Mg3rWtFsOqIs65O7qfeO4L7FmPOQSAI//b64wQ7MAj" ..
	"GzUTDtuPaE4y8ozFqK3Y7J1DfFQ2hEwbkDvUqPxLP2IRfOByg/p6+zxg2oJ1RbKfUkeM4TTKNJsqwwrf8iL7f5sZkqORIvvwyQxT" ..
	"+IElGtCQKZ09sQrpT70Sefrn1o4TiEtKO0F/GX+jkSxhFtJ+gIemESJqHhgiNFOekbwuzmU7ZrkF7JTbz7UyJAylrUsq/Hf3pQU+" ..
	"ulnq5H+rgTplGf6B/SLtqIs7xEZ/gvUxK6LGrx/3NTg7IuH+62nPVRPN2D0u5XAjU/bPO1r8EyV0AR3JUddI+rr3s6GqPoOQzFYJ" ..
	"Y/BGaIXH2ydMR+Vl+SPwhwADtm5wvcRuplnx99YMMvfcCz3RfI3fVpkKqzuuku2MGguMetgzBgXrJD5zMlFq/EEZd/QFMqM4crGE" ..
	"X8sWA4hEmV3SUxP6IZLoJkPYi3C4z1iLedJ3lEOC2bsUADPqXfZtE7H6taEJCDFp8vQj2C3AeKpVpUtZ+a88dldVgPXzs+ksaQQO" ..
	"/nmkrdgN9Aagzxgh4oqr/FkRjvsQFpN3nSi791NKa4vOd3toJvZ34MxsOJJvXOPs0iZBVR2IQx6csiol/xjuxVswKWWu6EkARyAI" ..
	"i6aD0tY2558Cuc+k+bV/tZLIReq9P8RZGolHX6SrUfO6KrVdZeP7OeFvwhVvjmhnFEHL9QaPV2+vIKx4zurMWIAzeuBcHRmRBl0c" ..
	"0QX4KjF8re/oZ3+ns9H2wIxAqBtqOny3TNvx6JaDdLDLHvP8C4KUnFHEJ8uRclqIIjWRdRn1VD7UYok20OVU0AEo2jCzcx6itdg8" ..
	"6huPRAKWMnXSYrWcPukBvzz62r73mYjuQSu26gGYG5CCn4l1294Fg9Fdrv0ubL2tf0LY971qCP0JzRIgG/rDw3mgLZcOzWMiprgO" ..
	"dPZngvhaJ0jvQHQ/ZUH7B+2TpSn2T6A1pDFAHKJW8C921eE2LH5sVLsnHCyl5YdNiS3aMvdGyz64rEy1ihuAVPfM0e2Yts7NAqYh" ..
	"iU0wprmeBGABo96htfvDIuWSFrFS/Kz8kxsgUUBC/nhNwtANJatSmwARxJNDQBvbeyF30MsOhA8tCjnCuCIXoMGwqmDl2NAHqcLa" ..
	"pB5mZbk4fQ4GRjmW0qr+jis92Ej2Th/MEGbmZCE9JeWqxZZ4IfGtYIpExrx5wpI+JabazFrK+ojavnMJ5PI0AppFWwPjKrB6I8UT" ..
	"DFmgk/jN2bj0ly8PpxvT1AYk2r+5sp/wlQM3Dz4yjghwtNrNsaiQSBsj4DHH41dc2gC8dKcvPILBcegwn85f+LfcKB0M0F+PAmst" ..
	"csCA4Ts9iTRZ2pYYjcL6pVTdEShOk35dRsWtl9hGQOEjJ7K/V9OuUw20+s21tesCqYdL3yQEATQwcsXrlaaUv6WxjTW623D8ai9C" ..
	"THeJ7AjqqH6stHar4naNP2WRV49woguUEyLx4ilX29UDX6ogpH1BqQ2SIZcFzw1YVWj7VTMb8s660mFh1TjftCWhGe2h3P1+VDnS" ..
	"4RVts5NJQa1V9vjElmOAIfVWFDqHeeuPRNHqyzPIHDY56ZYT0c4lXq6Up//iaCUUvYsLQ/ikwj6PZIPvevJE0w1lF56ja1NsOdR9" ..
	"WVDyNoqGpjnb66MHDr4e+gEE230EK5uuNfcfnYuFuWlUKUl3q1z0gcgqY0cqzv9xcemqEzsbyldWoq5JZ5EuoCGVk5nsbYq2373s" ..
	"4oPHVYDk6zvaWd5k3S/0ODabYTc7KIFmL9xbBTb7IetawCegfSKkYDPudgUzwMSnh2DoxzrzlsdkRutbEJj5cbPXw11sj9XK67lY" ..
	"OK7UV6NGfz+0NSK1OeHX4/RcBFx5pf52QZwY75fiySi99B50tyEKtdKBBlgB2a7hIg/6T2iuO0mc2kL9UV9YWkuUFEoRq80vO52F" ..
	"piv0VwePWTolwaI+k+0323K/jV0FB5Kp2qAbfGpKb/vQcjikz4y5Pn+8PE5HEDnlQi6+RB0NwYyGXnfJHTm6tqjyQky2IuuV+cMA" ..
	"9GU8Tm33mAqeevOUILcdXuDxHy2Ufk3hjLcRPfPhNBAX0XdYkyXApGI1ZlYIoOM0Q3OEBiyRsKPvbmZBjRQyhhXQ/PyjFjVCKWnf" ..
	"TBsnxmY4oogef1+wDZl5aSS1WZR5qWmj8vmnspNOXX1M54nlQAO6bQKpu+ZxZPPYTl/zHJ0LM65j0CsMGjkJ3STrSeAmwt6p9QSL" ..
	"P6gxNOHU3E8SaI36HJFnX+a/OcugIpn7IHnYH+We5dxeEJRpLq4HxVrf6Q8vlXC/SAscpuBdjKXOynh+Tx3d10AK3K6S/uGtt+4O" ..
	"HS4J3C1orioMU7Ow8dcFJd5DJmbI6qc38f62zaYafu3RhJkxcEoU25tIyuH+UC+UXzbGUZfulYY7QQ+R8y5Ff+41pWP9NwiWn4DY" ..
	"Z9eqsIzhDNzY/K3kDe2V6aan6iKUR5C+oLHKLGd/fvI5TQITYfVt+Ydn4D/XtAJgj4xdCpWaPf+QwxpKxLubwdbsFEdv+yv1Kt8m" ..
	"FrNj1wVizqqy5G+OG0i5W2oRjz2ks0tJQD0E5ICevwhR00miWfp5WtZLK495RwPBIir4NcuwO3/qDGKHGNzQaB7SP8a4cYzshBsF" ..
	"GQvjUyZIjAnRQzWCgnGHhElPL3Zao0GjBR7CV5AJQ1oLdeutLQBmuqJA6rXAKIcMGFFcBcbSieAGjwS5jFtNxtWjw1HFF18C8ZT2" ..
	"aCbiBrxkoW9GCxbu7D9pjswePmE2GRCFfornUz5UuBBLCmtjl2sfoupwn33S5am+AaZbW52QHhqsoUNv3gHRgo70IaQhLR0X6QFX" ..
	"hVFrrZDRLjhv9kUnk3j+H0Czp5fiSFCp6FyXQLN++yLko2wMl/vfkbvbXjsuoSH3L+tqOOkzRXie3RWQzrU9+Q9Ig3FmIHclACIi" ..
	""
local PAYLOAD_P12 =
	"BtGI1iaFrELrsdQUUuwJ37xGwZ7CwDRGshnWfQL70OmXVWAaNKAP/fSt6T7l0yUSSF6mK6E3Ks/LAh8hz7/AGE8B0zCfYjAtQpnD" ..
	"Xg1x48fB9dGdKxhhL2bBv3/lS7P6Q/Z0m/c1iHjbZddM3LeBi+Rgg8MiPOF2A6HeHkb3AsbRuVVmzufdnQ1WVdvUGvXeuwa7586r" ..
	"EyXmHwZT/w+N6nNv87bMXBKtLZMx1trDRfY4avHfmQB106tgdc743Bz9l6n2qxHuEqleY3Zcygz3x4UwbXdg5CT1YNSuRk0WAlJN" ..
	"9zwQ5edqm27dDxQF6I1ri0NBuSAYGqMJVGdtQA2g2bR+t2oGD5yIHcl9vPF3vcVZ3t8NSmRvB0NINGO22wI1m77oU7F04iN5rFnY" ..
	"yAdJA+7G+Mg2tG9eppZ2wL6VR3vT6AhpXQU0b5g8uH6t7hn34E/sgw5ZrfKG59iLtJN3q2qK9qx1Npo1KEXd27sq0xXtcChKpw3s" ..
	"UlTp3R5Mngp+tfLKXth93wHxXRsVsGkf23K/TlId+N7LvhWQP46UYiCQcD1xh1b68f0nk6WkxGt3TmOMwogc+CjCEEEtGqA9qpQ7" ..
	"8Mbdi2tn1orMt6tPBCtmYhTekpM0Ku19ZQoxa5S8ihIuJvXGNFeD78jF1m+foTwUAH0uXpydHWSoLMpRPzAS1UYZWyoL73yIdtX5" ..
	"j3Y7UT4j5PxtvWV1QNMb10IC6sirA2SXjrTz3ui6SIOxoJHtS3gvol7nkPn7HpuJhhayfp24CfClDw5F92uv/pFlKhrDn0O/xcRL" ..
	"KSdCBxywhmCI1VrroyHZn9wlQ0uPh9rTxfnI9XCqF549v9qXm7Yep3XiIgDD/i1S7d2nRBVub/d9T9Syy0eARawyMClOzEFY47oJ" ..
	"3iqXnXeoyj6hVzaBMTYH69TyQOL1zuswpv4xaXjb2WOkEcJe9eV30Jghd/Ftpx5Fq+PfnTLhQ+mPfmzwL9h7j8v1aqjNxSU5+e8p" ..
	"5LZhYoMjzVHTzzNkV4NvxiF/UMt7V3PDBptv0jCx0LGn191g+NX8y9Y2dIcHEUO7ksqxhzQObezTZRSID80M6g1xjzvS2PlHyXk8" ..
	"KWpBFrq6mxxuqj5h1UPDawLB7mwyM6gL0aIhwv8IQRfPe2NYxZjRzRGLPAV+H/agZONnW0voV3pZ2jummyNJ/o3sX5Cb+N3GkUAg" ..
	"2PeDVQ5hqHdF98iuSCiYSrmSh/Il8fJnW/P2XJHzDsgPoPPvcilaYt+wp4lFVZv4y5niLCb13Z4d6OVwMndbNT+3LbhaBIeB3ZeH" ..
	"LXtjDAf1ncSpYoq9vLpKS1eWzrC9TnGMOecNLlhAzHiYn23gGAeU7Cm0UXq4xpkSc+gMoPvedMzpqByGxKkw/lDGgEZYZ1f3vAaB" ..
	"QlLeGL9dKEKx65v9UeC7lsm4bxXTEgVyU7ww5KsnzrT3cSCvEU1Ftyv8jSVnYBZLqUR1nlhRusxnTbUTlmtjvZ+2UDEZCGjiTWz2" ..
	"KjNAhwxxQ6I2CzXZye49lbGCMUjP8rUXbY25cTwiKNRnTTJlH8YywFd2/2to7i4ArDpfzgXO9n2z8SHhEfJGwydyJ8HNwys7RJ1Q" ..
	"2iDL6KahLZEyF5IOJBWDYvEYwYd77krfar9MDsMSbrmmC6c7+viP9G6LNUtLuCZKVulqWtXwHopV+p64/BF/ohqEo7is2K2OMIkR" ..
	"XM4huIa/u494O49ypcoudxTwEu9a+1PPLddud9VNhGoC/CHWlWb82jP65wgEiTui/NSszBwtkyi8AWrIZxyysn9+ThiwmjEtoGb5" ..
	"xHY7qyZlap8IUJqdHVPJp08NoPzwkAZN6wocxk1vfKqlyEOa4b6JThUf/hEK7wPvxhfcjHMPbnu5mzukjf43dOYyH/H+XL4+EGdm" ..
	"cHvvDmtGPurEpT1Z08omms95UEVLtPSxpXfUQxCdhuvt2iRInm0moqjrnug6HtI6FP7wfOWQUsacDGvifvCaS/YXAb9ZzfxYbaq1" ..
	"IHL9Mm/3U5QGB4ru8Q5sDIwBxRYjsPMSRU2fGtMD4xE6QZoRfBKdeYl7GFfWVkn6I+9mA2M9zIL7sUlkV1NFEt8G37AsBUCSsKgL" ..
	"n1/MAsAhuyRx7z7EgedEmeT3OBs75k+2hEsDeL67z+1+gRFp1742t0zpUBAijMeTANX7kXeJI3hHTmc3TrxDg4FKkBK//XiHvkGn" ..
	"U9TZpiceZLNl55ZpOmNruZCSUvSbhstMEKZm/F37/Ko30/dL6jHsOJHCITU0w6y6RcsO6nXPrVukFdzK/+5AUMCzM+8i6zzuGNL4" ..
	"lW/IZv5D5rGRWzztNOV330LlZVzVcc5RV3Fc7SAnPcjsMmWk+pRJQitkdYqDrgsAzS7hBKedvRHMC+raban6NUmzzrN4FkeTNH+J" ..
	"qlIC5MANqliCSyxF6Cb78ONgJr6FXp/wzkNehXF16kgq6EUdp3qxCJyMpTkKum/oo/Hz8Aa3+qbA8x9HwfkVW+lw+M4upTTYurHE" ..
	"zHJsGfMeZGqixTYHFtx2J/RZefIls7beAOWKcoFin4x/GXw3oeZP5lnwQPJvCtWTpMu6HWL8NkQ86Lml9ynEYjnyOCVF//DaZufF" ..
	"a2ZCmy7uXF893JmvTRYmpCXw0vgvtapxI+7aEjm32qt6Q/Y0G11CW+MjP6Vo+KrA8n/cFCzTE+24lAATFifFe2EgBxc7vO7sFoYi" ..
	"pq1mPl4tgIhiJJ1eEMFV0FXG36r00+XfToIG9Lgj3cg1lQ8rA9HdsFt6gSwIEuM6MsBHpwNyCmni+KUSlIEgrQgLJmJjO3OHXGav" ..
	"LIeKHQcplGJQuBFV8dt9iaMmgQ5ML+r39SJyOZD77Gp04WNX58fwiAlr9bHOj1oRJQa2RmGwh62N1M/ypZEIiZhWY3my91SDk+KI" ..
	"x3AFoPrhX5QCaNQbEZDA4fCEV85yCV1/WmN1Cx8YBLHJnuRlRtbkxkSvC7zoLMwa2TukVbiTkEBENO2vlEgWf7vYWUvyZEDih7Ck" ..
	"6fDW7CBrgB2qpZ42ZZjQMGMQIwVWtEkrKapskZF5AkapyqXkBzMVuorNAI5hewHdXtmWTZ5f9GNDlVVW0b1QBz1fNkKSP7RaavbX" ..
	"NgtKzuGfsecvUhbcGoGo704rr+8vTqSrmXOg2Ndjs12VvAKJmF4KslAa3YwJbTvuwppw++dsNgtog8s7LceLe4f2m/JqoGoVBFlj" ..
	"Osf/YuykCib6Dg2ae0MiaqPN2QRM0b06vLGBgdZHa4Tyy4TRHFOofabHNMKflwdopY2oSVAVKH2Ei3wTVuHLEL609x0J1no7UICP" ..
	"VU/zDQU9QZNyCObi7lhttCpnPZ7zAMN+4y4RnRyaq46UXvUSKvG5HIbYi35MlKBh+Pjtkp1/PtQrSsEhpQgkSVGO9eezCEkdT6R9" ..
	"EKmQwXPtLxbnhpX23hp+GNu9KO7QljO19D+0vUTGojS/POEq7Kab/Rz98ZuU1devkG3Afk5vOer4vmawRUNQo2PCdIP2Eo9TPix8" ..
	"z8sm+qxR1u4eYTP+H7efnRRRDqhqw2bLL7AHRU2w1f0Q41zBfej3E38TvYOao2UDX4EGvBuNS+y/YXU4oQCHq1xh6SxG6JsPp24k" ..
	"uDADf0JFb51SaQiE0X5iFz1KhyFyVDXkx65iTI4Q5OcTTTBQJwdFDeut2OBz0aYF2HkrrEVMBr0b9ruuc49wK4intlyOe1LytsZv" ..
	"zosVKoX9nfubYuqzpOozkJqU0ELO2z/DKdA74yNfr7uMG9U+38BDJs2RF5zVY9tfsdCo+ZEmPu5w0QYWUVaml9h/HgruhnNCp220" ..
	"xfcPmcg6GXaT0w91zSrfFOrsK9c24ib78o/rLoRp0EVBFQjWWkpFe5d9DplA9D56HQZ3LIxf/88WIYD252ZprOEMsjTS4RTyYxeu" ..
	"G2exVY7UiuionFeKdb3FMW0JNSIrJSAt/jgkLxuOruLez/omzhoA5pojBMqsXBGxuU2apBBur6UgZv6cXEk5xzX69U3Lm+Sf4aEF" ..
	"sl94JGL54ccn1yYcOduyTNWrt92bntoQzh6kQ7vdvj/b8IFEiI0ceX3eNoPwjmbcLo+ohBbr9FGDQ7/ihU2IIldMitSTgRDNfcfX" ..
	"sX75tBUUDDDR2OIXntrZgTRILrGY42RWFKdJCv9sjYO+FNXkZXV9pDNN9RaJJX6eThX7R5qMYPEbEGfeFmGdwPYlYiw3BVHGR+de" ..
	"ZetfbhcB8U6uw6PSPT2O28jIUvxZb9+ZK0+EIrM2+N17X7EBOQkzB+ZwCQWvXvH4mqUPAcokKcta2ckECt7UFCP9QBgCuAeWwKNQ" ..
	"OvY13SG4aJqfwn1bCfm9tpTl3U/fnSJv3XKaB6OZuX2K700AgdnGkEQCm/e9r8x9Oe9pDSg9nJYD6j3GdeOTHQsiVZtDivfM1RaN" ..
	"SjPK1+C3FVQGmQXHVBAr1rcYUtqWpnGcwdtlOXP1Vk+Qo4SrTFXcl0P2uDQsCu+nAhR0WGF9VEEMq8TKAixHzzgvrLU7tPEQaZ2k" ..
	"uG+h/FLcVmdLjRAS5jvZdNFFqrfx4lK3zk55QCUuCtdpsRkLW/RdA3xol+wwjoqtNeCSbPsPGzLA/gPR8IAp4vud3XmHF6KRUASO" ..
	"ZwPdP9T+fh3X+eGlUVkkrcNhTQn9e4cJlFhyUcHQr8n9kFhyEZL6Rg4809aoH0dxdUSCGD31RkJQItjYdDEd1WgcelVZmf5dyk6P" ..
	"+Ql4u7IqCbIgkfQ+zOMgQZFidM+cs8i9rPBmRvr2gool9eG1xwnlamuZTmM87gsE59pZSgJSowJ9YLC5h8D8Ja7baFyfXro/SXHa" ..
	"WSXdU6f7sfxS/vl8SOVxQvN9QOKm2bwp5QIkJ5tY90vLhzbK/rc33W47VEQEiPPq9yqLGFrv3DHMxNkqQpr/h4SHjJDsPfN94WUX" ..
	"QkTU0UHFxMAbLlZCMNUhLvrCuxbZlJl5BAwLy/RDkt0p5Ucad125ARcXI+q+DZ7NYfHkgMoP4CEBG7tSeHrgEOV3/LqKrT70JmIo" ..
	"D4abpQlg812OJBEzyFiJVT66Ua/0ZnhecOHSjBuS7fLt78NeUPsj0lmYpEtZiPPEJAjBrc5KFRJYy0CShyM6CS4BZHte2zDJuUtb" ..
	"imIwwNhs+h0uDdSveOAEhmmzebUlTRhhPg5MrqnfToJNpt4gtNSX91bR1SH8SC8Id5pJHhdgvyE5+Wl93npNwq5PRYG22N8xNEFe" ..
	"vaOiEm7gT5rz3dv4+WVnUdFHg/LXGhUyZlcmc4os9hzClnpTgEdR4n1z27qKkmgnLB/I5yMH5AKSkl6/ed/DjPAix0FToV8vYoN3" ..
	"cup+C5JJAe1+CLJ+un9vVzCvdzfvmYKNv+NFAEtFvzaRYtuXsMkFjwjHYdZCVKregI8TmxElKJ/H03Lo1hXWvU1+WPzh6cnohz94" ..
	"dp7yppaokyo2Q3LhwnX5DkK8v+Mqr7MMUlxOa+jaEt5hwj4RVeBBaALBbJUYeYv99D8H+zqPUiCrYqt8cdXj1aLqKcCvXS1thkZo" ..
	"Z9eVYPB71qFbS5aaMOQP7Y2wN6ez0ZMS/iDqdKl+jqpxunGMqVhLKzSDwYzgmMv1zKticldZzTkcXRvvWsPh92DAI8Yih5I+tMlM" ..
	"oxZv3rLzwqh4Ol9ZIoxdZEgHwYe3SCB6pgpSvkY6ZdSONBgIqn8uU5aaSvsdjN3XF6PYzIdg1R01wtYax8Ele07DS+gfgiboYzl6" ..
	"sHv8aQiBG9tnAjm3iSB2M/TkqBpukrpGZ3AKVx6hk0FszwSHs7wTE5G9kUo6rr5Hwz2EPeDhQd6hbqDA76HrXxupur6y/eynraHo" ..
	"Q/PlmzphUTicDQW1m5yNVrGauVuIFAdy3DukGcl4I/Ww/akrd1ZdujmbyzfRQDqJv2kRv5Vy80XUBmuScEWdC6KJK0FaRJjfb6tE" ..
	"/tZnk+cWf3VzGLpn9jkXXHW92wf9XUGhEB7OktIJj+MBWIYPSOaQl8F+ul1Mhpo/apPWPvYBacj03gZU/0jjNooX34lYAMqMc6aF" ..
	""
local PAYLOAD_P13 =
	"O4ek1IoAWQHWKE0PCRCfhBNC4S3kZEgnlSMz9VFNVLdUJJpWt8Mpe6QMy0O5uWJ7sM9/AHyHWBBsOr/7k7bgtLWi3dDv0rESaNrz" ..
	"s65zJ8+Uhs1GX1OtTEIKqnUdls2XlUVD05KwsE3H9fV61eW/KtYs4nngVQ+b8dw71a0/ODG6Pc99LVBwx/UqBxS0aa902foAoTtV" ..
	"daOaZqIbMu+ID/snLDapRLw6UDs/uPYxGm80hFJpxQITeRorYct8yvOusnwzIEaLyT/0C/tW99vwFUnYGMqSVBvyynm30lhugNi1" ..
	"e0Ub4o+c3IweHFcuP/5AQXqENU8N1qpNQAXhSYBP1zemos8eFr2udQi0CKTxpGaUjD9MwKUOjxKEUqxCnKAfzyRxQ+YLvAJwBmlm" ..
	"Cz+ywjycbruLoMYSakOSEIHL0Hos3MZtdvH+VzGbHD+mRGBV4uipWrZ5IvuVB9oPz1OhmqhbjuuHlFZUFr3tlQa96QiP6DcZduCL" ..
	"TAsN9GbqjMZIjFdt+OC+DCFTgP8PXEW0VDpWSITTNN+pGdk+D1eUl+uHI6Yx3gw42qZvTYe6xfzuMKmoHb8yK0+gvKiPUOtDoXtV" ..
	"kOfyftZLkQDC5xsGW1qv3yaN/B79xDw7dDinGCJ/POeTno2LofSpcCZiuswwOqyQEbqdjzq88aYH9xDGzO20WFrjyWh5+ynARou7" ..
	"XW2pL1BuSNePoSIy+WPQULHqZ+WsCUJuVxy4YJQ1OuWJaUZfi12oQYiDeTdpDfBhlkbTiOxGx0V+xqgD4wVA65nktzPmf1uAZ1GR" ..
	"f8SWlhmAyb/pV68ettosnKf9pS/gYtgbSjXPXB/dojy0Ilh5VWO5z6S1eHBncPNSnFlS4pfOfNYznZOUSiEnmpG9PmYhFMNjcRDC" ..
	"yg3uSt1bkSkMkA+jr6XQt+qFSutVl/DE91WtHazurBNAuGii0+mNzO5ZRDQeIjJptZ/hJ/eqW6GQGeLLXwZoS4QDLfDaj4ISh6nM" ..
	"OpVyfMlUTUwz1zinecTy2w7HRdTWilfJAMZGhJeaB1ee9XL/NWRrwuxXsajGNXJZy0LAMbEhwqPsNpfIWAUcSZbBd+uqKkMd9v1M" ..
	"Yjc788vhiO7LnfZyT/QixPwYTyL51JYK6LiiGp6tFKnutaNd7XmumRFExrVXoMpO+GI6w1j/2pu1IMZ1ofHNiqutszpL8ZFJdhBI" ..
	"7ZzHc+SMqeBV8ouqvZq+GvYsNb3I8Id2ILuKwoG3HyiTIIu2/gHqy7DhkYJM5CqM5BZQliZoY+ZCQJ7yPPqdKGpWN9H1NVgP2fyL" ..
	"N77iIHGHkPEyRSPDaGprY0dfvPBdspZYhCdWjtGY27haJozZQzy9Vl+zm2vIOgRwWIQ3xo/KCT9MgMC+7Ue9QZXWUAzt7JkutTEj" ..
	"3JdjTa4t+wT2SueR56w2Y3JFjjghvBoFIw13M+J2YMPgf2Tb4eqWkYNNgfBzLXF/f7tMNvjtKI1X+FMTCNT3EQwzBc3aEiG93lO0" ..
	"NCh95RsHVLtrfWUbCCwv9oCTBWtYbvBv550oiP8/OzTTFrQnR4Yhyf0iLND/Qdl2aviLGT7vwLRrqEV8K940wyjbtNR+OLhic0w7" ..
	"Dnoaf3UAIGyU46qH7/XDS0Yi0JsAd3bakS6tfKJ0vKzc0QtYq8MylFKxJVEZMq93i5Wa0fbxE8JLR9rZAJNrOrm8FhOzit6U5Mz1" ..
	"srJqOZ8Dz1eaIQqzE/Tku/WbJElsayXhr03Cgbz8aD+Y+u7DUIAoTSW+kQH/XwKRv9MBNFBoB8uygUCm9VEnrCE7MUQYERi6oHuD" ..
	"MJbi6HDSg5g1NDW9adEuQXkAoAqmzqdT9ZyxALH8+qFdZr9PXL57ML5sLWs4SMuPE1OT62G30J9buiYUoB1WGaqkZRQuUnFFJG+t" ..
	"hV+F0ET1Wvl5P3p3KxGYHM02PK1bkWVMpyPGNEHjnopwKRbUlIq1jtUfRFyfmHN+bjdgN6jcnfBuksaWZH+z3Z4Z4hsQA1PtMmsF" ..
	"edOP4BXGnI3/LG2KmUGCu4zGgk+8nY1wvQkmkDimHbqMSVBEHCXyIHf8pmK8U56+jlDkoDHFQGHkUN7pNrCt/mwYqLufYcuTMA9P" ..
	"ZRrYq3hOfp6LBKusYcj6OjuNgAaupO5/6iniUZjtUlDMYav9mP4B6+W/GJ7/9+kcGlwPa0GqyKrKivi+5lgSVhwfBzWFoHxJoJXs" ..
	"eEDzedonyEyDX/cyucTb4oKG0BFvPq9Na9XM+KactiSIImuEErNzdFt66yv6YJqx7NQgimdKoalfVtVkbjz1iPA11PCpnqbyvEfr" ..
	"prcGRlxNPD+JvKlSMSyGXPlAe/+kwL5LHNHOBz6HaxwE41EHulMurWX+rSUXrGRX23GgnqmQs8KJWfdb77sKv9beX+HLT9IH6tyO" ..
	"Hp+eP7010+c38fezVJuSI67hzCA6dLyLlUQjZ4vp0TK2dXcrlf3iJ36yc2M44Karync1EQhMjQfBDchIKLrsbMfNV/pqmDSJBil2" ..
	"fITc2YVIagmZne+9Yk4w2K10zhnUT+1TtzGLjTfcZwBW5SlflnLfg8GuaKfTJObrEGzCKbD0/+QosTV7gaAQVF+UZtJH/RuJL9Ig" ..
	"8d+GwODSHeig4wo/8FAANOOoYHquWvUmww31dSodTnDDKpCHgvw85STX48soyGSheKVoHpTlra871Omsxj7DVjUtjrvA/bccsZeI" ..
	"wxJx2Xn8MNiQPdY/mKAHeE3GI8MofJetWf0HOXBSWxDkCpXUJOLGWfzn/LRtgEj7/+FXDknefGWGaMPwRQkx8Q5kCrByGw1nQvXR" ..
	"A3ypcWS1EI94t+HOX3HlffelpNfSNR1tQWO1ZN3rXDRIKRkNvAo2CdzB4nmPTCADNeBRJbo+rJGCvlQwscqZ6ofk1cVnosAMmEbN" ..
	"agaX0op1/Nw3ts8Mzmj0YQgdTHr070d3W2gPk3FAuKMtrJJtWXddALujB3ZfXXc1he5wYVNVXWsuGG/0kCSXWveC63GSmAFA2MUW" ..
	"Qp8swJSHhuX92U4pO5tzjaGdY6cJkN7cHGmtXW2eSb2fx8lzRoCy+HQGqncaoy5Kh3HG//OFnCaO0FWjwNetfrz2WHLC6PnhAxJP" ..
	"vhI0TdUG4cVJlXvif9Lis3TURI9iiWJ4N3/W/N4n1eCtYgOXEDG441Vv5j6ywAa/nw5r2wcR9Rw9tRPBfaCpZWpOIzDQ4/Pd+sOU" ..
	"uCPcIKNvi/n3JWnqyR7tLKPzAPqTxnpOC0A4xfSuPWl9sc9IYrgnCGRGqhRCXBSp4RJrYk7SuZJvKvSi0n2KBU7TUhkFTZH3cCH6" ..
	"UxGkyzRj8AwJJfZ42FIXvrau+iHoIW7gipnUIfa3tL0txcZOh5AXSoQYm/q6PeEdUPhX0H09KWga/LvU1rX5SjoRGYfIubF7K6BZ" ..
	"O2NSgH/8U3tKNY5rF0JvJovaVE5d3iVX6N6Bby+JpOycLv9ZjslgM4J1eoTtM9osttr7QeotmMpmg9YceArJekzqTvPjhcmGJHUa" ..
	"TdO5IegwqWFX7B9VXOKkimcWFb8KFfqjvRTbkOS0TMiSAGp9Fj1vFs1cbe+qgBVIfiT/+9or+EZ1p3nHjSEeVl0bqhi3/wSL+5IE" ..
	"MZl+/knjoqQGW8qERJEUGi8p2EFhosVpleUT8LHiBqmtRaXwnPbWB5+JhTRrvFfupv9+/L9wCJLgP3uEIUA1RYCa/ixp0hYfZ66T" ..
	"2vN26Z4bicphNo0s0F6yPsLKaxtn/Kjte9KPVTEIWwv+eKlGAZQMU0RY5WNmwzGn/ihG4JYsnHhVMAwWZDlo1zJo7lE0Uy3p3t9r" ..
	"Q4f5j3ZlEsdoqu3q6kHG+SW7gB0Uv6hHymMGJYgQJPFOxNwD60w75VTVRFSw7fQo2k7k7L1ZDSMIQ0HdxSveqsFMHj8D2suMoLhH" ..
	"7ACF0QcYGWkCDH/CQzRJIiud2uy2bX/fTQVmiifPSm+InkTztAHPxDwOxMThUkmx+jkyuNcQS+ItNoHgH+ly1L7vzk41krFeSLo2" ..
	"ZuVUi6nm5NWi8dbe/VJwcqR5dnQEJUAnfI0U52HZxftqWNX8w8IAVix38VgkjGGgznFDTxOWvpUzG1+2dw+Zq+0dRTfTMvy6SF9J" ..
	"EuEd84s3NOvNNkrjaZvV/f8gwMi6GoyskyUt0ohZH0zSrWlEYvM6dfWS8eretkgS818fXPlNYfjPH/YOO5qlmKEtjyIPSpc0lFc9" ..
	"L+/lzFpW3IeL+EmVfW6GRTJIktJaeLgbdwsL3gt7ZK0PPB3dd0jr0TobFdcLA0rq4/mYU/1Xo4lDj4KdesbI/pFsXAB0b/Qt9pg6" ..
	"t+2/vmiiayzvG4PEJBikeExaSYhYCyNHJor+YPUeFH6TgDW9xjtimdhNJZK7DZF9RhHr/RIekw9bc+E2geaQeUnnPUxcqhwKI48G" ..
	"lFG/I8shFqAyOG6fO5dk3gfjCEWr3ictZjjy35i0GJ3TMbbxjrPED5bEbwk9D9nco7NmUc2Wfj0iE5cRm7k94GELPZoJC99HQJ0g" ..
	"BF0cMhzklm0eG1M5f93TmHa6tFjcj39z1vBTPfWo24LoMFU4O0/5MJlQD/i5SnYYuG58ZVlmCjmH1lJgisHRpBLlvzd42xl3YgDo" ..
	"RsaTjpPovd6Xq0B/YADie/m20nmaUNKUIdm+wfBg22wuDdSjxvQbueSB/X1G5nFhPeJd3mw6cvK0ZtLCICYOuKHcsstGj3jisKaM" ..
	"aNzIT5bNFO8+kCNahvOZbBhHtXWc9O3kiDm8ZbpsWhP8CLJMlYdcp6ne3/3lt0HXRXN1SmkLAIAYyiQj7hTVqjpYiFBNuiNvEUEl" ..
	"cPXTSrrsIb8WXqmFv4G/g0QhMUu697+MGdMqvOVO8WBCs1aKn8WRvAO+86XBGHdc6aHao9l/gpdz7yKpdvYJk13hCoXzmCKT8+iU" ..
	"kI863rHxWkY+eFPz5eQyvtB4Y/nN2bUZdFP7LC8ObU7tODRoOPZn7NlpGMTRhnWfrpvyLsvLrZo68pQwTxPuommkapUw7Ni4HLnc" ..
	"Z4vO9l+dJ1HbnFpHECvkn6mz3eGtXlptWAuDEVgZXZVyZRTctioLJyc6m4No5+JFhvGKMNCqy9HDPAhki53TjAimd+LugJ7Alqx1" ..
	"QW1ZeZAjxP7HBeQTxdKlmCPZQWs3SCRUeD/1UhcrZTENReE0hQ8cQmVKn+PyTFfQ2rUiO8OWWA/zkrf5JhfJ+FHv7txMDlGCNHhQ" ..
	"cwYlrd61n7Fz9n4JZaA9uunEAmZ/qVfCrNCn6vfvTfZ7WKnTMeo8JRooCZlZZl1aIgA2MvWIPrgHmUiRB9GSdKqd7qYMyCnxI0BC" ..
	"MxWgxwKCt8eFL1txsqPhqsThkUFbejaVTkm/wbpWz8Qn+7fd3vyoOmaNNFs+tikKwlgg4zuo1tbDoDzxqJncECdqNrwqagUe/y+H" ..
	"yIDEVWH8TgHYvBFFZqw7H0z34IWtIHGAbRJGZKw9abViXUZoXPcOPBsDTELv5HpH8E+JQpiCIIWLHiMzyXZ1GGyFGJPSQ5k2dhIg" ..
	"b5NTzd2slKrw7WQfgIgL4usQIL5h/kQBS6nhPVLgXN0orv74ZLXI+lAC4fu9T7JDwiWnt+j7nyxOMB8gzir/uFG64mOhuGUTTU0/" ..
	"rB3jzympu6WVXkqNBSGUu1Xu1XwRR6+PuVTp2opo6frXpjGLDBUnlKhY+6WQylc1ZsNmWnBspqb6vH8IjkRCEJ4qZp+tBHQv03Gj" ..
	"E1Z2Iz11EHR3jmkYYMKBu0OK3bFIihkVxV32DoR/gsA0ebMcjL+L4mgYKIadzM99L4KbINIhDsiWvvU49/fEskOdRWr4CAAwP4MB" ..
	"g8SiEzY5wwWWAO+BCD5i+pFX10Xh6PTLbwVVi3PIWHfYp4CbR0Nb/Ovwi2JVsK50H+4W8iMlOJUkm8Jg1g73URRD77Ars8vimRAr" ..
	"fECtQKzds0rArLE1eCmJS1HRyZI/6QMIjbRYvII7T32kQCoRqiLWKzU9pEhGIxEuVGLThVX+HfrS6khp4xPxKH+XLWPLH5g1vSTC" ..
	""
local PAYLOAD_P14 =
	"Zk+O6ejiMLtkwQDmVrXwzViingTLjafa9EYojY1RrPWZaPkXp6PcWq3cPtNAx0LtRja/KZiIK23X1xyZnTRdhvl4Q0JMb/nK+AOI" ..
	"vyyTuWMJpLSSfy/EJc5RL0+XPzZsTTld72kxEPv3nGuYV7A67qPBJdMHlUH6MLWzQwY5p9yVdty28IPntKYpgBBqSZmG/FdTPRSF" ..
	"+i0V9wHNw0Qc1NRIkMSDNqBsaZA7NnNYwcXfDYX0qjqhlSPtkPmSnrNadCTFrJ6JJu0DUcfMfsjTXJcDoWC4iFLIrrRJbyn4oX4R" ..
	"wJJK7Dbh7sluRz12AaGLJWT23G2lKsMSkY/1trTN/ey5JgkxiV9Hl50J1T9/ozV2Gb9Nq+geclRmQAbVhds6gdQ07VRaMmi7bxKM" ..
	"6Dq1QYRiARxfoSl22b4+HZ4W9fZuTT/13FOKVUDNQP5PhLNa21QKY8MT0qUkktD/7cJGyBvwko2A9RDdDlRRk7/OkPT+8G/qh2Cw" ..
	"1/kd6ASfajkJ2O8b0zf8QeceoHRLYyXVwsxiS+t3y8kjWDNnvoUieBhi1W9S4i6hUzM+bt698dsEEiVZkq8ZAp6eCx4RfX0aB0bq" ..
	"TTH+JeByXzQpLC7RA95H0hZxGFm/RmyOGU740lF69alTcWhIgg2kn4HAub9HOeLcvcdob3ol1CQ8KDXTLXcdzqfGwcmhrZQOr/hO" ..
	"GQ11ctGMuo0uKyBGosi5ewFczjlVbS24l4MsTBkK0YNwUrMRyBcvcckUZIM/BTIaxTzfDAPELvCAmy9nuukpSUfFPhEnDF7DmOLS" ..
	"TSYmCwe9kHWGOoj1/Z1ZKlM/z2RqaPXSNQEl45+OSekFsAkAsR4kVjW0i04KH8DXDrwp+zNRD2jZ4vCKtB9DLrVaPvKXnJb/TBAG" ..
	"lLIHQ4wSyzfimLL4m+JfSkegbjAEugX1LADs4NJheMKu5f/tuttmwy23JG3lsdQmQZuAHjolQ+nyTp+jYN51b6eC8de+oKHHLpfl" ..
	"WPnYlMbGkH4/BcXPbHMaVwV5HoKon8+UIuGld6qnog9BAtnY0Hhjhk2DdJkn4FwRC6frfLEJEmTQ/If+1OdCKGSSZy6xzLv4atGn" ..
	"jc4RPTAR1Tzh0Qfjhz+1CEnorttZrz5iNU6WugY1x3ceKK/km1qmq8WToxZNHMCzKytPL7ERugnJ7WBOEhFQ17WhON79n8pOOexx" ..
	"DO5KIjOzAYq8i3PLqd31Jtxw5sc3TUixGorf0uT0y40pmLFHksXC8FZ9MY4CZOmAB6PwmzCjYofvWX+1wOLuCr9OXOJ9HSbhMFpb" ..
	"dXT3Q6ZkeEOoq+YNzzViIujY8O6dKlKxSHL0nsFMIDxsuCTmewDfPz/MsCEBpTWoDDClT8BQGf++DqE5ERv716jXXRykWQy/eu4c" ..
	"zgOrz1w9iAWkHQLWBfbHNql7pQqtiHMVDWML0wQPCAsJKx42lboFEZctIlbWXF5arEgM2vdp9LHbYTgkRDdcgVogMeOZs+U5tnkY" ..
	"fT/EZPGHUUtqMW6eUuNFQGD0nplOrlSY1UFpaXI33+Jm/nnC1/WS7nVOEFbylUYIJ5p4PT9UHA7kaJIGy0hedyMUtnK3xh21uLcl" ..
	"0gSrQpjpn2hrLCOhKMbPGd4kUn6Q7yA2Q+36M5ebC9z3qrsiIErZJbiejxhMXWiriIqpDLjPgWBAmOLRbREmfgUh/GuNe6wPQeER" ..
	"FADdIEn0zV8ezKj6ca+Ar+xJ4CUq/WZYIDLs5yAui+ZLnzSGPEvjnbkcgEL+qXHFqnwEWpxfNkDZWkyeFrQAh9IC01qaXzyZxVos" ..
	"Jri5qBw2IcAW6C1KBl/P7YW9DfFKBOCH40It1BgzzGjgeH9OEaJZ9Mw0r7LPqppPW3CkUsnDI4j+2HbJ/1TVAYrw7AqMyaG3RXFv" ..
	"I+PkpNdsWOJL2SZpnvcc8M5Jp9CpBYaWt+keENj7XsrvOFl+UQgFkuqzqFSxW1IuVtVVxZps/c6RVWjT6ZYI08PzGIiW68ef6ib/" ..
	"dHHAakwPOPQphpZerx2dcsg0TDkf2yoYnIkJRZ8ztqeia7NHUf4Xb/Up3NLyg5CzOw7irq02Z3JYncKdOtgbDBKK8YbV3hlVZo3W" ..
	"oBrsKl8AuA0m2KatwIywrmsyRcdQdpucK1JqZRqRuCQIPfs17M1+PXaYKc3wom/x2xtPbnfMxiy+I947UZkPs9M4n9yLsudWguBl" ..
	"xWDUiRinegHeKS2j965rdOR4KR7J0+Ls7i6vKeP8A9GjOGbNkI53sxjd5ede2/BBNrp4T4MXiKxhSdL+tZtseMIBsC+7+StZUXkT" ..
	"wnAKolkfvlND1WLRzaHUaIkSViFgUgYUg4QwwUVlw5NJjy4voCTgwZ8PWFOzq4JAL/w3AMMfPu6bgzJx0B5MSl7EWr/I6gvUDZjM" ..
	"PQCxO1SOzC1Fi8QyOGo42yc8sef6Allki3X6h/iSNsQGxMY7esgeOmcYl8RkIweTTluk4JwephFoQ9kULkDGrTn9kMo5RaIYXlpl" ..
	"xcZClO0pmjRSws3w3bCZVC74qg8Cb4j9GKjpJaOB4D0xIz3DvG6z8X6Fpd28LP5zvgTk3BKLqubwT3pjk0T+Sj3YHGJJb4RjYi8G" ..
	"mMP0aHRLAgh5g/D5PJmn5oadoNpw4RVEmrVHB20SEBZ18AfM0ZV8jPVBgrDCq75hNCTNsGVlD/qua0hH7YQeWLvmBPj2UtZ95KuU" ..
	"IczOqVbZ2ZZIg3jfSJrn2ABjDBSq5x3zE58Jb0h4HdxWp5myDRdmDLqcDze3fuDmmx9aDsUw73SWbnthE9na2GPrtxVEFXWuf7Gp" ..
	"a/6kTUhtOdHw4QS8Ync/nY6Z5geEQoVi5txCbjmVYh2MrrBdMMJjtYfFRVtbbpp9A2VrIM2Y5ZNt5jSOjm3KE7npZKAIKfICodsH" ..
	"z59cyLKTK9yL9abA02eVNOr8SxwouTZVD3DwFxHFGKDm/5PCqSOlb+PPeFGZFarVDhLt9vg7disNngliq+raeUfgFps1OP1YxRLd" ..
	"o/oydNNCPwEnkqdwYAuogRoaD9VRWZsTBPYko5/Knrjrwl4Hl22KEw8eSVJEEAlHR1+RZmt6MajnMuzQ5oz/Rrca2sIF74cP502M" ..
	"siHLYRs60YWU8w6lLjjOLdbvNeyONLL8ljBNaMZhG7iu3cgoefxirF1Anj2e51YHAX6hT0U6dPotJ8NR1Fc/PVAVZ9FRzsxethRY" ..
	"HeJX7r4M4CcF/rnJ1X+iYpnyW8+WHnl39UpmKfNti/IroeVyG6tI2tJQ7UZgTQI8DnEVoJNrPtOfyO0mExuKP6sA1qazocExZAEu" ..
	"nDG3SHIwXxHPPxMWCnLSS549sT0sKQqGghQHq53yc1vKNAvAhoOYAEswr6NVmSS1ekllED2Lq76Elp7jDJyQYQlRT+sDkGPJbc4x" ..
	"tNUZ0jGZG+CkNA/oMCzRD+Yt9l7XbIRMjWhwotqTF1ANL8LMklWGOko=" ..
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
