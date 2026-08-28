--[[ DQFarm Loader ]]
-- Licensed to: Tien (nhieu), Free for test (nhieu), GNURT (nhieu), KhongMinh (1 thiet bi)
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

(getgenv or _G).DQ_LOADER = true

local KEYS = {
	{ seed = 3186186579, exp = 0, plan = 0, hwid = {} },
	{ seed = 3187233856, exp = 1788740761, plan = 0, hwid = {} },
	{ seed = 3179829844, exp = 0, plan = 0, hwid = {} },
	{ seed = 3186907171, exp = 1790469007, plan = 1, hwid = {"HWID-ABC-123"} }
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
	"5wh9N8GUKwCZNw0s9Hs6c+k4XiIKtEz/CfkSpqo/hHSI+37CH9FRq+L7Tq/IbyuiAlKR7RvXPossrr7aaJp4dAokiEnyEYPMbsoN" ..
	"SkaG4I318rAHSkHWUGmv06kKst6ETMIvbJQtjYTt+EhwwwtNuMnERfjZTDyOG/OctuM7uUTQz5fHb6R3vILbv1a5UWaRvukrq6U+" ..
	"XfNJMvifqTFfNExiYb1Sd0/9kQE6wFgyPWsoW+E87KOaLfYKTlFVP0xPWeZHeN6mWwW7qBVuQK835l0FgOQA/0p0tzCR5Mr7Yyh9" ..
	"2OH3Nchxn7kXgVWkHu2oWQ9Z3zNhxG3LtKxZSPNImFvWvYIKCKt1Koc1yH8vpH7EwFbCkO3IlJrBM/z5Z6nl+7aW1EQGzWFLWj9O" ..
	"TObuqXCs9qSyDBRKwkJNAHL0+h31IjSeN5ckeKESlqJCCwy7ZlWCsjWZgXERztmogRN4hricZMMzElk4LXBtN9BxYpCK/fXTUgfn" ..
	"NErK+u3zISlSmdmOHYE0brY+fHU2B7zpMGFTfhsAol4xDf9lMNTDix9p4N9+kaVmtL6+WtUASWjZXo83rQhfdQ+o2fyanLSvEV1V" ..
	"qsKeJppNTQKFMYEcz4KxWMhP1Sf7Dd27x+UZVWktjE4mYlAhXBSvy/ZKwNnBw5kIPXkVFEL75Vg1APkGcGpThYhoE6FcPBupOIEh" ..
	"H/Z0T+ysXv+fDC9i0qnyISN/tXcAhfn2OY5fAbQuYvSCu18TP3TGY9koEx5mEdtK670OHrZloTh/UX+QGcp6M+J6lpqx5pfkjSt8" ..
	"LsroquGfZLehm+GtQhxAsSF0thJm5X8LB2AFarXrgBJmDcrBRCmbfyTZNZyHnTxEvzfyQwUavrQLOUmf3f7B2sWh7y0d6A3CtuFF" ..
	"UjqEjsX8hFQZEqSpItsTaJFS1XGdYQ9K5U9lEPla18zIbB48pF32MrF0f1p2xyRmT1jPfuZIbrEVzsJDWg1P9081rMGNe62DTbk0" ..
	"eNLZvqCkr9TZjt46U+j84flrf6595I0YAPxA+3i/oht9bXRXl7Cc/guym7tn02yneJKrWpE8i1mU+3xPQ2mD11QTOSGiFvT0+omz" ..
	"Q/slRVKGEOKoiMGlnbEiwtFzB5MUfSGaK0dJTIiGiU/3Ia7BcmmCe2IJSe9UVgY1HoCnbAHfPon9bZAZXULbPrVvgn0cNdrInKNd" ..
	"l9yRyJceaMRVOQ4B6TuShJSTL2JfLdFhXg6sgm7jjdcw33AETsNT3jnB3tGX+BQdXnF9s6OBpXJ/Qr9TMtTeshu3lvq4Pzrd7w3h" ..
	"QqX3aufwuh1YqMkfAxzEUvRjWzo0S8NV9+xuey8fCi2kOoW108GIXq4ifinMrVa85WMRFJNlMZZfxWjL8qbiwWertjlHFoLxH3bW" ..
	"UlbY65lQbxoLq5QmJEehvQxtCS50rEa+cmNLPaHhdR0KxqlaYTm4IVOY0ESSv1OsaYpANC4czlMXLlVQPolpA3wrrBWsypR/wLca" ..
	"IFqfMURHpvvgcxy96KeD3NM2eZMrx9UgYQHQSjq9l+j1B87uRKSEAPI2s2r8z1TO+cUljO9HtPqgZYLTqrDgXmdzbLQsqxjSbGgs" ..
	"Y9gTsrnVs9p5KzxcBjuZmaxyS7f2Ol1PJVJI+rjU3OqAbclYeXVFRhyby2f0ib/WZKd58hYsWuf+J1yQ+qh0xGHKDfjWd81XbaWK" ..
	"ad1ooDl0C169DRHZYnBgf/e7hOLnX0o7QmCy/+ir9NhPwgsOMH/3LFg/iXj0I5OjJX4yEUkh4FD9bgwmeqrZaosihdGLhRt5lFkQ" ..
	"tzg201ZB+Z4Fz1Lnt/JmhEDSXxR6pNvU3+xnFEiB02oJI7N7Yba9cbBuBY8Nc44SpKK30fJlJB8o9oV1a6O9ZEMz8rOIylHEZT2z" ..
	"n0zSvqiJdKJx/oqYPLzRGD4Qj68hoRQRUlyD/5tQqDhNygBZW52dS29S0QlbDbOkypXd+rzUvcFKRaIX93BTlgTTgUlI5hbeI53I" ..
	"1dtZviViRwJCVg1FTUinucFJ2TXcV95UPF2gUC+UZZCfUuQVb3DRszVK64HxUHwEAf4tpXSAsxG8YUZwEOljo5G/NOaQIUND5GKS" ..
	"4nfmn8Op295fy8wf3vEuptaaUAYf96bLmPkkwaLk78R8FlsIIK0L6cswrQxzWQzpXFFot3pL+85y6EaCNUdYfXeNYXL30ShBmd0V" ..
	"4ncJXL2zt38NyQFK7rfUVzGzP3byQwpS5nIW7CvF99x5sH7yoRzglDjWnaYh81ArqIfBI2gAZrCa+z6O/sOSj1nTK02KarDrHi7Q" ..
	"mRsBmowXiuhk/CID55Zo0zFv1BbiXks3r9MEebmzWGcDCd4q7tR55YA1GBKYvSyBDYPRpDzyp0xGX2xaE+A8a4NUNaBrl+NrJMU/" ..
	"gbhJxaSy5oPWzEsF+Tf7msVkEkvs1/pp1nFXJyE4NNvDxKW3RK5mkdHzwJWVh+yul9B8s+diW95rhZZcjbvEx+a2aDeOXTEbEIhV" ..
	"B5HMfwtLPJnnc+Bx39Qq0f8jpSBconiEY+IQfZl/8WCb8ewVMkyaCHTOojR/Io1Ko1tv/sTkptDmRpSG0ZDoPJzxtT5k1PntlwBJ" ..
	"AbUDef0gD6hUYS652EAP6Co4hrbiR/NuYuwUu/qiK4xpiTok1bH/uZffTGQOZZ5DKSTdg8tGOcRBpLjE1WFp9nTFPxbnnWOD+g7W" ..
	"yIqLHAng0Why3JwvSDtDvOKjFlT+imQEIwUZ0PjUsa+KNYV8GXyLF05+7aZRJBpTXtH78FrsFPU+Dz9GmrYRH2JmMXKekuFQXTET" ..
	"JO4Pk5Zwx1aeo67u/WFGjhW+M9OJmJQZUPr4hnQs0yG+u+OCehV991Sy5N/Li8eMNvSilh+wrbpMF7cboLB3rVYnnE7PHdoK/4m6" ..
	"E2dDBo4ipuk1BUGwA796LlWd9HELhxkotKdr5MPUNgBPo5JeYJDhhvehndD/sVKnNzTABPLb6iadZFzW9xHsvGIYC6Mom4arfcgY" ..
	"k38uEc/yTLUPSufcbin3HxWtHIZXiWkAzApKcSbwu3LhXVHEu8w585OekeVC53O6bKIZ81BV18bqr6XmNq+TqLmqZxxMdnu2VhU4" ..
	"RZxvvingwIon7PW7Na+cXonjMUFOUZjSxYD/MDcGJL9VvJ1JXmGiuRIrpIG+6+LUCA0mkjuB7/kNiQdPOo6DFNLzOCiv6bZ69neA" ..
	"40NB3fmgkWU+j3xVWfxW1RcLIT3L0Dy42dO3SEt2nAETgfkoIxVBvp0hvAJRHUc/dt3j1NDd0ffFkCsY+nbn84NCU+Q7T5N4Ce+D" ..
	"prg7adTHYZdoWlpA/8jTDoi4gduo/ROVIJwqs7W1p5W3sV1E0W422plQbADaJUgAM75LunB9nKBI1fYQBusMX9hNx0TY6Q9O7vbI" ..
	"qXdPLR7mhrQtJjGJXaLFkBM1ig6XC2IRgysS+f0+l0liXELItaehkflmJDf0Kw2uSXtSS3mz3Tudygl2+yj1M75fp46EfCgNCSVL" ..
	"MiabaDUWMX0cWGGzqeDylV7k2oPs1ZrJbkWzGGEBREbNWVXZBuNmaYRcrYzUe7grzEpE3r5E6pvHkvRvpai9DA+whHN8AUpGIHsY" ..
	"jNMdpPUpplSUDqGyD7nukSseGKma/YYDtJvXGrj1auyfwVP7amnYnKPz4E4k2WP4ucAf4ySsyEbZM+5zFyFWZYNQFRROeo/tGA0/" ..
	"7s0b41MgEwXP5pKDav856jR5IaTHIYik2xqCBbD3hx+hcFErKfvMz2IDeON6J7HYt7naygPljFW15Pn193LTO3DXQsQdU4WSnMPU" ..
	"MSsCKUhTQPPGTusBLctiWBZZvx6thV+7tsB+/d0iAsr1jU+m5CgBnK6VKcsnCugqt/0jYI2qqJvPPipMgZUMQ3ghLWCNNBtwsuYk" ..
	"p1Npp3n7lkmELRUI++XiHyOu9ym3ZTlCOuMQoXb34cowJrXmvRCn4E1B4FU/hzSDJ3JbpXX4XJnbJb2eLkgB102nHE6IRLN7jvnH" ..
	"WY+Z+raR5Lf1PuGIcMg67EwIlgRZGn98sl+zFnUYGfqCyqH2zU0hAXImsCvR2t6HyWETpd/b1pupP/t4CZkIVwUrldIW8JYenP+0" ..
	"9UcGJDeCfQmtngRxA4Qj+pmK12fCBXhXEfZq1drVd3VUeDsL5PYKoyYApb29wd/sNfLTigJDVf2bitj0RtF+CNSTZZFNSrUM9pom" ..
	"ZrbqABq8FJ+PT8lXrBpj5j06HbiaTuqkB6SXlwCD5Bir2w8tx43phdVidFjRYqcPGlOGM/cUzLS+mY3ff5+Ns5S6cmVdWD0BJdQw" ..
	"0vp49e/3XK0nH64oFyXO581TxvA0XI+OP9YEA9CZnpSUPC5r/CLZzywaaQyfSlSdAIGgAuxkl7FuXY7khHnsc27wbgp0EJyTc4zg" ..
	"7HWPSZe7FZVYjWQYsCwJurU3jUdkyIYOW3pQLvIUxWXDeGqyPGHF0WmYpYCqJMLaBYmB5zzZM1a6zp/Gdj2HWIpvRqoMBTQi+uYC" ..
	"UoBVoQDWJsK2Ql9IFwJF74x0yfOByqrQDErPn9f6Hk/m+t1symYHo5nr/cq04LKR+eUy3pyOWSuSOIlgzbEHziUaDSZFIEnjEA6a" ..
	"tdRN2Fl6lmSFZ8rOAIBnLKiDyk1+Fv2c6PPzC1IyMysd8Q9s+CWkfUwBMS3rhEPi7uWOdmd5bv7Ur1lSRnHgDhw27J0y8Bc1+4RZ" ..
	"sdWHrqh+/zQczzN3bmWPK4rzErNdmUPM2wihzQgI1BTHO0Yp6YNjo7Vio0WLNoHQO0kImHb2kiu6t19TU79yA9U3UAT3LvqVgomE" ..
	"pmqFtGm525o2t9rviLC6OQkghwbBfaNLOa6NUI715n8K4mo8i+zrG0Ftga1p8O5pRAeoQIV7Es53zATFce4x9joE7uJTVIzgy1eO" ..
	"qEEs0/Z/q4Ca6m3lFB9KjVEdNfqf37a/v04ZQs6QBFHbabbQQDFezsoPaIXu7fHb/iwd6UwiyEK+qxj3rIt68WL5TSOnQ7dnrag9" ..
	"p++7iska0srNdOfkUPrr+DN4a7GdQUtcvHv8pUpYeKlANK7YlnxK6zQTrXnWiP6gH/nfeeWvKzaLwlnMdSe+fyx6Ube3XeMpU+nm" ..
	"e7iJygQfZF/7CXT8E+yw8Y3ePr7Ie5oUzq8VMPtpfGb2PVHx7ehdDwzg+C/A9rWZWaWtm1cUSpOQgrHcwwakMcQu1rQtgsVtqPf3" ..
	"LhnJHwHwSv6IkoXpiRK4I/Jrd6G/sdIgw2AucSm8wpm59n8Z/M9f0T530FDtOxLK6gZ7kx+NRbAsH7g8CQXqFyH1Wt+QLM8mSQYn" ..
	"Ia2rqFDWvj4il4GCsf66zRdoDyifgI8BXMigOodz5B1PA+UbwLvTULeKemEC6AyjGPymp89yPDQEWOkqG1D/mqdetVwlFypbu8uC" ..
	"b+5DdV2i0gaUx0AvmjXVzD9QmPZM1BDI3maboodLoV2zxwFdmy4H4EmvlkwrfIr9hEfbyaaw8XJqofZKnA2H5HxmvZqGE4DYgFCF" ..
	"NMxqcm1YRLIUviS7JP6yQO20Q+pF/oMwH3pVHD357xOiFH9JWSOPoSatLOFe06Jam6Dm9FywT6kXcZUIlan5HiepP92F/gIdOYbO" ..
	"eS+rfGhlBbvrxC3XntgvL5M03JOMMUgtgwIIUz9copFe7j2xKH3rcLcA2A+N4kQei4i4GmyC40Db5jGhJXNWDWkE/OqQ9SS7gfDv" ..
	"eVcwL6Oqzp8AUAymMVSJbVYPlBHoBEqZwaGpKzage85VhosF6ENlTv7+TTzeoIuYi9pSqV7AE5TOjslyABP+4gaNoArKKLdmZAhh" ..
	"nzJniJ3Hnj9i0A2IhoPxM5AsFOaoxdjH+e3Tues+yXHLy7J7eF6W0uCl4ImQlrtQTZlLXJMY/jJJ403Y08D2/HWOfKQ3hbpZNcmh" ..
	"dXP4rnfewLC2UBd4kEqRN4Tr0zZUHdlTx3fITeS0fNlAJvNx59IIVszV1NWAfqtiOxN280Fv0rC31GjVdHTTgP6ybK2oB7A1apXg" ..
	""
local PAYLOAD_P2 =
	"qEvqDkLGRY2f86sgEWnO2I4Qgk4PzMOBuuTPa0tN1hVN6wA0tM4lzA7J74TG+YZA0CZUqn4OxVKq8UxkSnqypNx1YgKS/a1nwrTd" ..
	"0WgQwFDHtOdUIl5QrkpRsZwMbp7MXrSTV0ebMvRlAtvaeJD94XF8oDZrCeEOBq7XKMxTusvOAp5l42HRWKbb5YfZh6/aCCdJO64p" ..
	"NLOWzM//5rTSuBGdld00l5cKXNRPTfhOExOc8gJfaZcER4YB+yorJiokbzZ6VosMWMmnO1Uv/ty/LG/P36KkZNk4F6C6Waxo2bzo" ..
	"1qqTakQeLu1n9Ba2ymf+5hAvM8MfkFr7qJA+MWe8j69H7IzT728wVCAeCcg3mord8dQbtLA7lOjxAtRBw6v/4uVLOkRNX6NCk6C/" ..
	"h7Wb8PVaeJtKTN2Mkj3IxzxBqObLi574RLM4yojq2Lji6cTZPpXVbJfQWgil9SAqev3ITlTwPjJvNVLp9g37aUX0cjnMhghfB932" ..
	"rWXJNAtOo7EvQREpM0vh5DNC0KFA3MQJzbI2Ic0ah0WqVkotLcTgOFav2Q4vuNyEAM2BhYvmz7RZMrjogrZU2zzRVMSY3phzECZY" ..
	"T8v3MDEJF5xsG+Hq6h2oM9m3pwYdkXLPWNYcHEpQ4Wh6RgeczABaM0PbTlF92JBNzSv4YjH2FRu78R3S+QLsK1yTNOk6oDerag5D" ..
	"7pqaDPYqXvfT0M1e/oy4mYTsy8DMxZ7j+79Ykm05vCuwRaz/KcN1AsaWmvVRvB3LzmFQymz9XdsnP4YAggK+vsHQ5my8liHxK3sQ" ..
	"IkJuKr+P2Ob5RV7I3tCr/CF5eEQXm+sN6e28jjSS6QV3bWArfsd3Je0rscoJOH2VKjW/zTuGy4URQC+rMgUuUmUWAn5Nh1PRBEzl" ..
	"66W//hFgYVS7dAuG9oo2QoGK9S9uAVpQCCbZdSA0t2GlytRDJkkWsb+IAOxF/4JYLwR6e4FXEws5DKFsbjTTUiuMWSzUWkvknZr9" ..
	"L7a+xNLaJK4NgELETdsYxKWs8SMbgX9aFCPYcnOMN2LGC8HwRKLE1Zuxd4/zvyEJBZ8hm7Z+vX4kMEqt21zAdFwwix/RqzuEqXE1" ..
	"p6vW34qbSFichPqJB5C3EbZbkCzVx9lyr54rnHAKbbgVjomWfYyq44NLRjmGNlKuaYU+lIEPiXCjHlJEWcvTZat0CWm85YeeancJ" ..
	"0xkA0E4Bvx3uuirQg42Xpi0Dk9O8K1t21Eh1AumF6FsOdzUFZYnYtGLbmeNvY2tzIkPgyibEXiL+3SAQcz92uP/i9kRv8CAPjrT/" ..
	"U4H7WsnxcIV/YmWSI0+6e4VaTqQVAQ14Kbmhb6ojoctTPiABsSMdnSjaMFvYB5Fk06QCt9dnkR00vQe9IwilVs7CscVdxGiKwavy" ..
	"iJfoXPkIyCfvgZix/C5zRdbn8+QDphrgTS5qIhbX90zLYV9QDpo/ABisxrdJjLt/uiOaG9cFcJH3GvuQIvcGYbE0J76kuN3Qs6LP" ..
	"lJKzYsIapPiX82amRjFgmvJ9ZGndV+cJjB4nfILshCDpWQ9I6lANhlwT8T6kDWccOHEG17YNn0GVyBLBMGLqbILDhVRpvqqa6qZ/" ..
	"Fr2+a89QKcAevmu5Xj1mQjpaI165XBJY4t35GO4Mwd5UyOncjo4or9eG5vR/jQZoDyVVSQzZ0fkFMV28Ngc+FiWjeYARVevrEIQc" ..
	"oJZlhs70yYPtQ29b9n5BWvSbgYeNg370SJh0lGRvF7/hxI/Fc8+mytf+2KLuJpi7wz1UVF5KgprpnXIK6d1omIRhATGg0nlnxDCR" ..
	"REcOYPIVlyrHoZaQLi4D0NDChy5+XQM3ZOqd+ILl+qDKb0OgDc6+oKIxQpyZlcTNBvDvH94qKewGRLy7hp2fdNx/rhLGZoS1V3lM" ..
	"dYQdqVTBtlOgLrKPpiprOs2lHuoPC96ykfkjqQ4kXMf9nchqUPFe7iKppcDe14hxjmkhPHR/1fc+3mceuR42ysiB3niCKuQWlYur" ..
	"hwXYqj/jKHCqa6Mj6A8TUoKBIXR1S7LRmlVgTZ3BXK5h/VoSY2PxFFEXPw8VAumJbBarmT2PhICuMmamnp+ySxhUTNEnzGKFUDQI" ..
	"5OuD/XUmjGFsZK7HwlLVsQw2Ofpzr+GMGIvo9VA12Sh0DgHSbNgo+UfmkH3+Xu0RlCZ3Mquoz+zW6ZI5DgMUFGJV7WMeC+mn8Dhv" ..
	"res+V6NxfOP1GRVyg+tLw2i/v+TXA3e0B22NJi2JREICUJTvpWqbz97jBWIrtubGtZ34HMkZEOI/2qwCRxawopzEWWGd3X2AURca" ..
	"q0jHaOuUnQP/YOehaIeVrPMPQg9O1NFwAZCHELXvPZ/q+FtWPgv/05VCSfJDPEaf4B1tIqN3XKNP5rWXZfOTai/po1tU86/SdSG2" ..
	"Nf1dvPBkhZN+26TlLCkUVzUu+Wv1rGGOZQRGrqVUspaUE31BgMXpJuMDn2Zr/8UbYof/HjW4YXtVwSnWmTlZVPq25oBELl6n6hej" ..
	"lTn+H7YTkevdVwWiGsr6Md3xs2fg+u4suJGzL8q+T2nMDlVtgq8q7AbHxQDXIqra3bk03xSnuFqBiCelvgKgp4LhvT/PHwgtXD+6" ..
	"H/OlTnFny7sf/O2BqltAhzOHxWrMiysF2ssfnuth7U65sNK7gEFZJgnVRpOjaTnRRuLUym1pZHFfMVhvwn3/xWsCUbvnRRv9RYZp" ..
	"wGYVwh8nRhhz6v05AjNGfdKF1LjIDb+CaEXnt3AXhcBBXWyxgKJ2aI8kSub790bUpv+kX5jlfZwW3LssOtJlcoSc2qJjctyRYsq2" ..
	"0/4z/+G63HqoFygfFt6tbazbhEM0/D36jSLeLGdtYG9zNZ9KSsnV+ma2nU65LsK6txXc8lUVpOg2ruJflGdBf8IqB0eOpDZ4hcsZ" ..
	"QHxtSbz+mlkTJulN0bEwrBfC3HRtzaqC111Nt8V/wjiH+DfSDliYAPms2hjtguqyfLTyOQJeu+1ZwU9RV6gbnq23BaRLYpGnk4NA" ..
	"30Hmqo/sLATbGaov4TyCGgLJ3totvw9Za8K4ogJ8Gk0TRLm9CprwYRTpdaW0gOvUYWG44RDdqIulA3Q2E9ahrIbxfy7kr1UEFamu" ..
	"yTOJXi4PpVxhiaKcrPUmSKuarlTD8JIG2dp6gyd4KAaubosb07PDtX0z2cmDy53lHE90Iuw1ZT3VZAGfx87YQO87ifQ1uVmYagUx" ..
	"cf941NNwKyY0b139RlYA4EvHmwFmkv40tM1OlWW3Ng4hki8GTjrCvdCGPDmF0Dm+oiAp4ohBIqGz4brm18tFmKVXmJ6bGfJLuVZL" ..
	"0zq/aqsyElmJ9PWSPxoG8XmE11vgZJvXbILhicKJXAx17PBKSUos4uUNq5OsinoQahpHKWQ/GkEqZrC9rYOSL1i4iqpREsbC7dj2" ..
	"slZ8/ZQRd+5kTl9xP99oiHhOyxS+05XrJexEcYkqZTaqJEcyzW/rcmZfURfdf2sf00EsVDrNkhNCNjCuRaOTieymjqfvxgdL2obp" ..
	"WDnxKCrNO13GdybkIJzewvywneNmvra6SfBgfhWojohzQIfL3oYrucriWGTeInKVpvqNl9D1qmhKf53k656pB/I2fXXo6jXX6gQO" ..
	"sxpdfRewlUssIHL+zpzhBdXWAskmTKQ4KuUdLsyski2/36CDF0PZt2HnHKeFW4Yy6Y76uUCO7GuRMFz3J5vOj1P0gHvu2vNi7V+n" ..
	"k1fnusMuQdnE1O3YT6a08PztKiYBi1evp+H8GXPPCWoIrf5zqChJyKgDm+Ebz+eox9MrRY75srxZOHzfQjpFLKQbsOtQodN3KYfC" ..
	"eK+UN46oiYvcdxEagpcCb6/J4OB5iPjtpjZ7EpuKgRH96WHKBviXlW8uVNzF2wmRdFx0Vuzemp0yFlV/6E2i4aou50BEjyahsBOR" ..
	"WpWjIdWFkejlr6eERvGKhJpHzfXgoJpyjgrLXse+4JsAHntbcVgkXxEbbr0fO/yWazFNfawPAxWHgGg1Xj8Mr+k4MHJFtyZvYXaV" ..
	"oj53OY/lopJ0B8MUMrlegaVJhEj2mb5BKD9f0Zg2MA5TbD8+XIPFq5h7EAC0FyFb7HrLr5D53w6m/BHPmHTuC/WLPD9LTsBapObs" ..
	"kY/XSKbMZjMbKYIx7r5xulFpgJT26I+H1LgCgLZ/lg4oJgLYE9l68JD46jq2anuHwZRMOBx8jGY2mNhQDPx/Y5CuMdq6eTuYVwR8" ..
	"6NaXfDQ568kvP+ZMdsCmdhLNR3WxBTrGChPQJm/36l3+FDiH2l0a4PUnrVtm7hW50Glu/EwiGZAtBDn7R0bVW67Qc1+1VtR83xzm" ..
	"A10kwJ1JeaCWL1i0qAf2XXakfosbDTxJw6myd844tJvUYh58aSV0/j9vTX3j/U6Z1VjiFTB47ymYmIJ9VQStDYuZYGvHWrHy9Jcv" ..
	"dSLKPh4EOIUn6jjnRO87sWvDIONjpv+vouYsI0w4HvnZ1O0t3ELLdWIrI6tup+ydfNnUCmiTVV/RX72FazSCkYdATUWtUTXQMQdq" ..
	"UOPRhBeX6F43cpnVVcux/Ft7dsSlM1trgAXb+1rMxbDqoQPBUtxpIAhIqpOEvtD57dF8uf9wFiWpU34kNUf8LEkAioUBVW3kUYH9" ..
	"QSYdZ6Un+OKPkbaKb/KJluxsVSs8gQl4O7E0t7yyaJeV/hIWjuP/lSKy6QdzWQ4Peo7D8LTK90v6NwbGPRCla0pP29yN6e7mgZHy" ..
	"mVWixxpuZSyFHnwvaGrdcxl0EeCYfJc/MvrpBM+ZcaAC+uffxQq2e9i3/0JaRQfbsDVYGj8V5oQgmskQjc/2mMHzoQT4HoTl7dfU" ..
	"/xnz698szaZjj+q+Qib4MsRsq4f94l3sDNmCeGTyMg4IgN8h87BJyNvcl6m2viaPJ5upSH8NkhvwRIX+yVzYp2BOki9+iJaSSyMn" ..
	"Vj3PiFGNdQWOzFPUYp+5gXNcpefzF7Gts9ZNxI6QdsB3poPF/Kg4Hj5ysEnKTLGtQxeioYx1XNYcQ0L6PmzIRowSBbrKgfvN4stn" ..
	"8uU/190Kdk0o8AFYPQzrZiMOGuoUeYPdTSP00xSOw0c90uYkX4jVrjMcZ+7UdL566eyPIFkYR0Ew/GWELFNG/iIvW/Z2BXdQGyV3" ..
	"I3olhZIN/o+ZrCrVYFmp4v2Qvi4wLpI7mhwel/AhbvlX06xtMl0nFj8SowJSMIcakOQ74qIyRY+TGIWkGKumABjUVmh+TutAHCvA" ..
	"lbVnux+jPAPPNHV3R6NTVHRdZmf6rT/NUK4JnTzEyu2qw3JpW1vaXvl0+h3DSQmuF1J9L0k9prOBvi7jZFjlJOQ2mgDQZ4gMz7r4" ..
	"926gpUyWpYGROsdzxt/9C8OWeZDxapEyYOIFYaLIzsVCH9b/wC54b5nUeMMGiMGbJqM3FD2aklVMypTZmGum+eDjW9SYzLToLRKT" ..
	"TeUaXIcRFxKD6DLn0DaMnkcINRNP6cRZ2FOm9F43tuNpaXeSWc1M9tdTHF90FcHZphL2mLEr5GHtFqRAW8R7b7fvgt4aizbRm54o" ..
	"Q4Dxo9AEtZxjsCOxYSAV0Ho+s0rz5GWQ0tvvZDoAj3NNAInHa2x0zcar39YaFw04GT4SPYW8sbMHd8c79wwXOZKvxUFriyDp1w1s" ..
	"qFrcLRh+wS01drgmxA2suwonI9csx/5ssSyvUrzLh3sesWwY1/ZEpIhiUSgQ9m2qmsuz7/rQBufdjFGnJZLAUgV2+g4lZ6O2YZKJ" ..
	"k9u8R0NgYfXTVu4L0YqSRLhJxDnd3aTnQUbJsBRSAYqVeOtSNKh98mBdDVjXIFvHphDfvYeuBW1yVlkSXws2fxOr+Xzkkkqfam1T" ..
	"03rBj+acnuIDF806dVahHhkHAttCyHO6xLBbnpTWq4GWXn4Iz0pHNX0mihRlLRkRFFRxGeqCP0KI3YPnP7oFI5/pC9nSJjGffUbb" ..
	"sXf18LpRbdVh5CM0e3dnpr+kAM5an0s8j1x6I88XRmh/zJbOX2OikE4YIlN7MQpFdR3nTlFMXNIuN9Hwa9sGvQK4J4Q3VEDxP5/m" ..
	""
local PAYLOAD_P3 =
	"8XeNrMX+R6x1jfnk2CIw00cn65x+Fq0jgQBD3lXcuneiPAkhaet9FoCuIiUpywecvjukkVkwZqkwf7fgQTAzcLlNLchIA2AbFWSQ" ..
	"MnJxks98BSaJDb+e09pG0iOOygwR3YgxznYZ4qImfNNBxbPekv/9DvWWlGFpzvSL4dJ1yV8bN48UKy2Z7yUgAFnhQXKcXE1eHtKa" ..
	"V2uuQcqjzM0XphUZ0Ts/wTBEWFHfv0sq0cKUFrb0t9LbVOGgL9UhdlnJNRPC+/QtDgguXIwYYfyKB/we43GomiqVtgD4NP1JMiQi" ..
	"jYoXiLnDBGD6drJlX1q+v2pXOGsdleTpGEPddmjwZb1miA9P68AxoQF587T8wYCbs4EONk4Yu3gk+G9hOrGNPdACBrDn7vz89sOW" ..
	"AjsTCGq1UyQdpBjuuPhfBh7BEE03ILGCUsWcV7BVUzcc2Qj6TWcwvHs8MdaoLmh9Zn6kcb1HBos5aytdGynxdyIb6ZNZvb+N5d6n" ..
	"q4UXRIpKqqTmdahjSM19ZlZujKyQ3jBkpZc/67z2PGMO+zEHHXMI8PqWxEe37yo0NASLZItprbWoXlFEl6QYY60gfvFeEVe5oRce" ..
	"eixDNTkgseKAge8YfQF77V9bIT6BCdvjg426tPfWOEk8w22WkUhN1wwXcqJPJXgXrF0Zl+4Gm5tW9OwBz2wZlhVmZi/t8T9Gj8Dt" ..
	"TT56Vs4tuyN0pXonylQ7A0O5XciBWsE5UIPB3NQC/26Pu3PxN/0P+zbN1awLuJUfZIl7HQBM0KSCO+8e/2A+WTAob2j9+6QeXcuX" ..
	"U+/okXOHNVcKcEpZc2kR9c9OLjBjp3HyD7j1UnexsslUdDHbzyiecyu0yKizLmg1LC3ljr39jqIoldIARTTBdRloUUBu8fg/NMJP" ..
	"k72FcGJOXPNHu0gBcFIWgcCYUxMBZjMZMV8e9B+YwEtCDM95J08bvYeIReyUljYxmSEnstPyTb1+Ve+saypUqQXXBKEpvz04dmli" ..
	"HR6v+MiOm3uzR4EjX1OGyVBNz4HmnrYJtHCGJe79Nhf8mx9+xuM3n1t1hJoqzAPGNkCdApw+9MAbHuHaSRuDVj3RFw44D8OgHhzY" ..
	"IJH4zryfzOLPDsizYbz+k1o51a9Sx+3od39YnTlcGqF4LKGMakXeyOlZdmoVdvRGOIqF7vgHdNYPtu09g8IQhVcJOOwYSbk3cYur" ..
	"5TmovQLWToBxNE/9QbB/XMFFrvukcwq9p8BDjf5/essT8lWfNorQt2DtxtMTF1rNE+gM9B8sgS2Z7y/PYr0cXbc6W67EMIzjwN5x" ..
	"5YAe4ARqz8MvEbxZ5H1wp9GIYd9Xu5qagEl5Bpu1pfZAJSiXAD5meakHKvWV7NQJr05MrYVGsa6bHCJBkV/Y6N5Pq3HV0ALR0EQ4" ..
	"WF4w6aqkBYTBkQiINqKaMhpJZJ1bZ9kARFzoNooBL/adnDfDI2is59+P6NwYgjWkaJHZSkZzVFPKcQPFCyj9ghu3ou5wHWV6zlKG" ..
	"KrR1G3y+a7ncgp+uko3P4omaR7NvUGd6VxfnbCXb7lfDFfabysiuBcyNiTuf6su6OjqQJTO27iwmdfuJTNtwj8LWHkx2QkqoOg5b" ..
	"TfYY/OmS3v8yseyEqYFv7Tt/hE4D+npKC55S4FxtbK6MLCjGFpc6nwZuFjlUEv9lMTpJkstFyWfpI44fSzNIzR15k324/Mto12XT" ..
	"yWVPCdnde2NICHPNtRXuGW5gCY99ZywTeqm9BYhW/XaNkQnu2m7J3R3FFSeDku2ztrIq0uZPcU+wyj9pWdHKGn1udk30hDbYXs9i" ..
	"9/Xg7JKBtQWokkGw8eU0LurjVD56UwieJcZ+aP2ICmnQ+e+JsPzCZdYqiDP512wf7f/MgssYZjLBCT8bgruPT9VcpVwYjkwnNITm" ..
	"eRoy0sffUbTiCeV7MLPSpHl1FxaC6xrVxJmiU2KmznCq9f2yeoUqPQiZrF7c0HmZxIfSUJygH7hxwWU+5FbMsR2iJf6xFIO0vE6E" ..
	"EfB8pMWVE0RnMMQ5DSBK5Ipo9CijpvEoulDe1WnsBeML4SnZa2Ffimb8ByMPnuNcnyVLzRlt9r6qi3ayiD1bhT1FM1O5tlnlq4fd" ..
	"QvPetWQS2DylhL07MZ91g0PUZJSR/OyFIuHqDY2IH9vOJrWpr9DyBmRq82k/CTGd3RwiyChysElWVBmYzZ4HeTrQCyll75MjSFsh" ..
	"HrTAzP4QCHPl11Tvc2jlOnvixgOywqOSvwkzwWzlhLd4pmrnPpJ2L7HYnFqgjecPofTnQWJOpN6i2i8zlP84k9aSekbXCKNlvBxs" ..
	"/NOIhCagc0UzwZpH9pU8GV3mX2Rw/ysn3J73TK50r/NL/KhGvmyMQftZq2Akf0FCYAdCBnr7HX7GvFmGCr4Tq7h0WO0nbdgfiR6G" ..
	"TeeWauqKcZO4An6sbuYwKEoDhmVSo0gzjhS8IhD2xzSfzcT6iVjWu9vWGGaqGcSpz6FV5+3zjM7cb39up3UW6p8zE7p7aRQ/Km+M" ..
	"PQXD+OFnjLO5xYwqjFoaomZmcQvxuAzoba0isQ6xHbHTxzvcqLMqG+Gp5rDsW/DvZ2Uy4E+rlpDiikd84V8K/IKD8Io0dzuVdqdv" ..
	"FOZUlw8tpeJj2zX7kHbucYParjfOhUQgF3Ct5/ojLb3+H7GQaTkoEfOzTY2+lsUNQG0xDKVpy9ZE9uutvQ/1/IOfhUJShSebB86x" ..
	"Bvbc6IirYdPefUMlFxFPloCu2VY6mW8OoX304NeoNfKFzxy1S4W2rw3jYBhC8DuTnd222qJ36comggFxIfLJMT8TdLh9Zsaw2y/m" ..
	"re4kIFHIOHfpfzeWqnVHHrfwIOXzLJRLEG4GP8qpGphirKQgSdsN04EmiiNdRFGyNi/rpTfUxluk9A3onoEJlSVE7B+d/abQOUVd" ..
	"P/ZJUx0zuatj/JXkv/1c+KQ789NZD0kZ5ldzzpSvnYVax2XJlVtOCxUFlNHafc9UQN56KuIH1n9LjB8mjxd4R/dgENwn4cDKk6eO" ..
	"J32QojoT95cgwkCTLPIUWmJ3xDPzk/tEi/34kTXgV1/K372RTDWVe7ZUfhu3NGKTzsrvorG8NKlIVRmDT0gdEFmiL/M6597tNjHe" ..
	"K5eXOHdnnOPKkFzm1lwStcgExyAAqsCfuD87JdganFX52q38pWUAYRD3EQQlZkHyw+gBSMKVb4NJimWEhwKA617uBHc7ig64oTpS" ..
	"NMyBnQIJUUpyX+O7MJCSYLE7CW+XbmeYFIzDhbCgJEBrVuSqUAHDULKmUQSwZ4nna+fznnuCnxuyiICJ4yfH6UT+UnMQBhTtcgW0" ..
	"emSqGZTAiZCnC7GohimI8hUUDxBn/ddI2ni//f6rdFxLx+UlzGazvt47sl4eoMysaS972y6eAXl1f/qbJDnxN50LcaqKgui3JE4B" ..
	"0uapjT4MBN3UgqUC7n3fktsWQOgXnMOCWdB0JGmAuzkfALdvBcjIp3yPOOt5cDjxLXOzCVy+gWG2OfkBJaFULMb1YaRix9TRumkV" ..
	"QAWIf+dJ6w6QkO1/mJ+ZHN4I37pp2RAFfzUyQztaW2xF9JJeAjbtqBc01FclStyt03s9+s4cclM6RxbHgH16dMjKEMcgsABn7uLL" ..
	"4O34RnZv+ebvtYAf1G2+hH5ql9OKwW+6Z4n2ETMWPw/qG1EQdAUKUrmY/wTqACyop6MJziIj2lPgR1Xxak3Tc6L7lb0mqA46QbVV" ..
	"iI/HLYPM8S9aSD8f3oNi9qKZCQ0WAqX6QoH1A3ru+yUSXswP39ssh0/yWPhHO7batlOnxkUcCoobiY+jUAGU8+iSkJvptbbr7JgQ" ..
	"a/ee2+WVnZCxWjlqxJtuzoCLDyf2QjlHiFIQh9/IDwggkP6Wm4d7McynnDhGyQegS4g2f609Q4SbYOqGk2N1iAcSyV/LuleBLfGn" ..
	"xqfIowAcm6zzSM52JMdyTd5e0cCsG6X6E9/id50qPaHESpuWuD3akxcSIwUUjYNgr3lj3wBb6taWEoMIxzzhs2JZ0XIVX1j57/Nx" ..
	"AMmdmY/9PFfKsmdiTgCK1FsYIuzvrbLZrISruugJE5BPZObEkPR20W+GAo0+BOQB24YpuYMGPSdmTJKyhLjoibQ9J35nJZPjIWuE" ..
	"mB4karSx6F1surKI+aQuDmB+V7hZV8ORU737IJGOc0YFzzYf1tGcrWH7qYoCqg6Mx8mJLB+HXvX3++n1d6+s+yfRhWkjISoDct08" ..
	"u20Rz9B6pm3RRU3vWJeepJ+kuW0JhA3TRkf83BNiohC9TGSsxUNKrXZ50aE7FRIGOEpkZb2BdScjlheoGXOFy7wXtuJykSJ4Xwmd" ..
	"FIyZtaER/yz2Leavf1j5NmPqqHRZeJTi91yvB94F+PMrMzkXcj9ucpshozJHSQEW4ytvJTyn46Kt+AFJ3q0j4pEu7FIDI1ARJgK6" ..
	"iRGzLM2KcBGAFyf6l3cVOleWRyEmyotMI75US22LnF2HLXM3KA/D2I9n+lmakUJe3Mf9R2RlUXg8KnJJdTr33wojzoTlUgiCA2An" ..
	"62VH9nEaoW/twUhL5rnZuGI2d/qgTOUt/Loy/BnoUt2aBD9vw0CQ2k3vAqKzBKXHJWMc1YuzDT1NIh0kwDD/LnbFcHqoT6OqLxrR" ..
	"QywlftvnRE4ljh1QcOlP1rNa7N5P7hYmZpf6bYGgR0H4vbW6VyYEFiQBkK9lA2uArWUG8iX+gVGQcZ5AK6LTDALHVED22Ur9qtE5" ..
	"LoMAMdc4n98jK3ID3wSU5q7uz7MzZFbfoh9CDdpwyYABY2u/mkK6MHdVUl9BKJepgzmUciVR2QWyfONpIDvHJAcqCyogCQVM9IW/" ..
	"JM57hM2Ju3+FpaW/J/IAcu52czRQL5BKYZ8Df//7oTUwin2sW2/nsvzga0nU+oZWp9yS2lW5jaIZqDWtabJ7EyQad8Wx2VfHJ71X" ..
	"aFIoZSMFtAyJ7hvQYD0hN98ujQ8ZLWBljZlcIZoH54rtZePw19uXZ+7LZ3xI2YtiHYz6oR8tSp71V0I2O+ZCPM4blVJTwq4groGE" ..
	"muRmnQkrXeOhGB+4YnBNCGOpQd3YDkjPeVe+HB8sEpYsAT1AXP66NEACd7U9XJIpcQMgqDXzj1UyxLTP2O2mbAmJb0MlvYQqsZAF" ..
	"GiEGMEPJ+hqcQXmihGMh8FMHKyaeN3ROSNWT/NC45ZW5ANcmp+mVCgEhPIrxTU9XL+DncyxPq2l3o1iR4mb1SBhdCzBWO3RK0Uh1" ..
	"8zwE4O2BnVrlqspQCFMKMVpIk+9WN6zQmzQaz0oK5WSKOUIQkLUdjUIQzX411BZYOQG+JG/jrXjXtlxuobWn26jfWVFsMpPzS4ua" ..
	"afaIlQ+7wBuAQSkLMuK2358dHZpkK8PfUOKMNfLbndtm1mGjq/HKMXNVugGRwYko0eaRlsHDLDI1E4H8gk5Do965tm0o2wdgnQYw" ..
	"PDVKk0TTX5VSiasOsrh0JyLvoUOsjZNxmWfhPRK83bT/OWOqS5+rByBlx+5Pw+1VntBoDRfEwzQZ3wJymZN7XLompXKGlN9IISKt" ..
	"T/KllOojYmw4emeYIjcWrV+IvSzqZIYpGXhAMSb0A3gj5NWw9PU1x9aK0Xnexv9eWuIhUmc7mGpT9Bb9fODkjI1zPZGWf6TOhxZE" ..
	"IyNrsclQIyDbrL6oTsn5xEgS69DErXnY/gW67iVHt1rjTD7KOqT82fEYnIJQouoW1UNG5vVvofiJfpDDdZTQiYtwgqEJjXzW3V1E" ..
	"6QBuWHHq51GfFrQrLzDPqzTN2MtEQ22s6I6E9VUBcjUR+IJ3dJXVrAW6unMUhc3EYB8h+khtq318kSqA5rXy9ttwqJaYxGvZr702" ..
	"HZDXgs8gQ18QgpsHK44GQJYMOsbFf3FtYWYhI8S5ZdgnWG7yr/2Hyedejqd33rgobkqh8vqpGWnOmpGGKsTOX+yKKkdSckWvLyTG" ..
	"s3WnvBYr6H7sAoOKFHhulCutwleuVhA9zbxDicRZn8QCGePnWHFYfN5Fvf8H6Jvb0CtVETDLwpjXbkQ+YJg4qonyj6wxxVSNww/x" ..
	""
local PAYLOAD_P4 =
	"SdodLTHQVjLla6RBqrhfNTcTMg6NliZ68ZdkLl9dPP0oFPtzhEGNW2XVPO6Iic12RmmnCE4LEQ9e6byeXrsfUVrNM+w1UZoOuuLN" ..
	"b3aRW5jKlrgTCS6UicYJOL3Kr92X4nO1wR+j10P5xVRPG13GndtzvJSfJl+YfnNswkqUrjtLlH6mvvD8YOLavcveWD4HeYPwVKcW" ..
	"du3dCsMhJ42uh755um2LBzNt//DMC5FDIUUN0RbRdJ7ApcrZj37csdAUpm/exUgoIgVevv/3EAQi6v9s3nKh/uofsTFbXBI5SvAA" ..
	"wnGM+mZVPrhtONc74zc6NdG62LYB62x9IBbzl0zyhmL6AeKPZV5B/H7eBvRfnFE5W4yG6AJQ1179TGHNC7BfJvRt/D7SBUCKA9oK" ..
	"LR5Gm63CI3VCEgd9jZ/WG0N9VlcMApqS1khNPmKdbbHQhD6S7dH0xDPYnOL1nMs3OKcSgWBUA4nytcSzLs8iLm9EfxD3WstGwzQq" ..
	"0GHU66IgtnfdOjGL+Fn1dImbQ73tu6VXpC9F3ppbxQzjiJ741xImRQQILjRKecE2s+Meh9vE5sjBNYml7EHA7FVSJdxEgWPmxD/H" ..
	"Net6OwIzCL/NENaqjY+5Tf/94dLzjmb+vARMfe/ht8JiPgCfu0GpTxhEN9tt/7Vx6m+DcxHjdjlQyAdbrZmm13jm6DX8qqCgn4o7" ..
	"+B9pFse6o1T+jspiYIrnJN+p5+7/x7boGcHVqbVNPXbTKcCw2yjH+GRxOlDF16+GXnWhgDETUUNBDtomz1X/I0UDgVi8Gacwl+n0" ..
	"uwSKHPiKxWPB3YxyNfjnTRwMzeiVs3GZuCluaS+MKwh2PsBrrpWmWGkG7wJ9em9OYbLa6qh8laPWcQ56UyZKzau1bE3XMR9BytB4" ..
	"KQKN2jkDh+sg8vTXZ39D8d/cjh2Rzam/CdkHDyEodnKITT44MNQSxzUqt8/yLOr5Uyh7zouZsjIZDeo/4m0oXF2XpDpZysrMNbX3" ..
	"dp47MK0vUQi+vSaMZGi2ZYppGej2LDUt/I/jlB4heswIMIZKaKgGXv36mRkWwsUBXvqVFac9ANNkZYexcZlNcHTE37ZaJYmxvjSe" ..
	"bppsiFXgDS3FEGnBRNc0yhkWQGYj2x6Xf1KgNfInNGNIkEaA4TMZXBlakN3CrFeu+BG7/moOGF7pci2sXwDrcJIlyQFLrhVIuOVj" ..
	"1qx6BZJW5d06PA8qLv0gQTW334RIxxMzg2jP0lBTm3E0w9cQBoXZbfPYXPZMCGnAF6sULlVCOIAWjdccrFPT0wg1l/Mq38KFYkcg" ..
	"6b5Du25tenZEXFbEur7Y01692Ze/CBYAtX8fMD2xAwHgv1IReeR3WN4zx4a6OJ+4B8KvYl9rKcTP6X3BfeAprdoHSun7Sxn/uw5a" ..
	"UxCCWXBQWcVdW44rEeqrWMbst2JD/bNIXVxHAe+WrfFuQvVI20CsO6lrd7XgaIbRKs8Javb1DIUAVuseenuJVNZXhM+9q0pTs5Bm" ..
	"2nQL5kM3j8bP8cntbq57jEznIBlcYvIQv/RgzUBZ7Cve527c2PaDkSKrq3kLA9FVfu+rZ8B+Ed20aHIgUYPryKOR9+OyqB8qH0Kv" ..
	"SmbSnBukALRk3AgMsur6OVtHpZyUPJFtt7lMfwtS88K3oDePDIoos9tAsOl0oEbi1HSlYdKRh97470KHHZhj54iOmLwGyal2FDGc" ..
	"DuCwbn5azDWrBcxc1mEKSpiUiEmdqGqj7Nyf/A7CBVezOsL/TeS5dc5dMG6Dp2Bsgybl12uiN5Bb6ylbTAaGS8EURvc/UeBI/NUS" ..
	"6chMz0xXJ0Ytdhm1js3ir6ErgWlYb+htcBS76OIVW3tci919rzRwMIvH6KzxKWwmruJeoSLy3qqGmrb2bCHmaSUVmPgGxdjY0lzp" ..
	"wvCImonb9EuGhnhN5wG2e4bKST9HdmR5jb/N1kvVfn6rY1fR564orNTcrae9IVrCgnSbl8CojCIZNjnG9NiRLd/orNZB+KYJi/y/" ..
	"IwlUrSfS9v6KMkdbr40CviCwio8QaVe264EKG0qrKz/A2nnkeeJbhYnzh9dJl+xIzXhNSvMKqIhcjPQOH9+mECAvGaXSdhcHwtfK" ..
	"b/aY52deMl2ZYyvoY95K3gy9N5pg1vPOiFKgsqmXsI9x3E9oNVRJ6kpqvee6T9Q0XTxSYtK9Ae7vIx6vAXbojKKZa/t+mTlQmAr1" ..
	"4+LDsnW99zCzYQDTquOwmOyJfHZ4KZ31FPGmQF3S+p6yfuz3PMcHy3Xxizk0IfBzQxM5Lru2VhAyQomnEKVwYeNJtU4YcFtmZFyq" ..
	"TN/h3wSUpyPTXO6FR4zDnkYJwaeAq/R91qBS4NFuLBHaVLcFaFXu5B/oBtZO5rb3i9YSJq2v0GwSOHwZGhLe0FILmqzvLWTs29rr" ..
	"j/fk0WjY+MkyOxENizonbTAgpS+QeQplnf06G3D5DQCodT4nRq9S5A91bO5LKWFnysXC0BmxmSX4wkrJeuvrzcQTCL4/FW+8uv9z" ..
	"7Nt0BV9PThQ2uc5ZOjARVpKKIpygXdUpw6IbeSLSVXnfBayK7oWIZBCGSLl4f4so+JtNLr5pvXkLPpwOKdXut0LdD/Y/c4eipExV" ..
	"2rsfLU90xTs/ipOquVai7UptOQACV4bExyIQlJBCHYOjXvCeNqc2a6l3sVgOW87DohDHPHIsBqBR6MCtobjNWDQ7SdduoYD4BzeX" ..
	"4OK2y1nhmUCFVhHg5/CuWCAPFe9Xeod3JdAlywmcq2Asm/jSS3MVBAPTlkf5kKu2BmLlABnax3theDhXtnvqxIEF/S3icMIDntRE" ..
	"VkqSzy6o3TeTMA5fJxaUuZRbcEmQNzqAf0VuKvU2nKVY1pCP4ARSMxMMBhqfyn557Z6jWcC9kBU8Y/KNs+zNHjFJCbrCh8CMcT3B" ..
	"SYrBeLl2PZv5808nhy8yhD+BfT/8oSeurCOpWWW533fsxw3IBkiAB5yD4wfE3R0+lDD38LL7rCEfe65E131yZ9drAPx1XNNEbTd1" ..
	"TPecOKezd2jcCsp1tK5/Gipbqq/X2F0o0fSyNGoqsWxWEpyFBDAKlcBP7XrUXZPiSdpq3mwg28jLoB5W368KWUnhfmVTLJ6uX61J" ..
	"C9hO4mrStkBeEN4F2yR1p4gsPwGJ5V9HuRfLEdboXO9kSYuz+EiV9YzVD4u61zyEphGzGYOt21DbiFFVAXuPZCzY4xG50tyi7+g+" ..
	"XYSi0Yt5TrmIDQWbT2+MPNvHpNF/lRj7SinrdkH5d8Mh2RCzWjZqK5+IjknmiUEwXIzP38bPPWGI4yHwnrD0jDox/wuaBW8VGvTt" ..
	"37O3nHPsYi6BOXwU9rV4ojSwzwn017uGcHfU1wWRCLB/G/hVwCz6CC7x/fTfjU/4TiePIJn67uUUPPsnR2OcLGhPX/Pd4cVy7Qc6" ..
	"WryloKmiCstjcHJHhkM621KFrqkkavudXANDt1VvgR5bVv9q6X5H4nPv6UFylw1dUT5HX6privDAfGjK6yJlBhJ8SIp3JHhZfb4B" ..
	"N4oHWgQTP87rs6e1jtbtzcb2pM6Bm7b4nNO/QLfm8ldzc8uCvIIhueSvDiALW8VOFuNmaI7aovF2gbGRn3dpl/1+/cruvnSux9hQ" ..
	"oqEPBtD4sgbBK+KNtk2DV2GaVu9ZESbIu11IvAQqhcHcx/tmlgxzm98iUxbJW0JqvB+3KcXMf7cjqjGCtBbzI8wWLmT3OgYedG2Y" ..
	"93eCYWkEfNfrgMBfPk4UmDhFTdUvwLA/53dJsZWZ8+28KtNw5Y0HQd/vSoY1PqghIaq3eJp7fAM15u5+UNY/4BJGji+DOZBla1LD" ..
	"0EM0m8tKSZgbyLdfMeZaTU3AJflUKZ0fRsdxi4c/uAoZFZg8SMgZHs5CCnMq03ZX5YQyD4/kcwd6S3LWd0Jgc/y4bvYoBdAwms5n" ..
	"5CJeaFmkcsLywk7elk5p43Ux5bKoE27nXwBffI3pIto/nr6CvIxGRTkOTZyk9hlgLlySEfA03ZgDiXNE3dIV+Elb1xdlEQwzllV5" ..
	"aG/yRDVLx6wDasU7ltXcHZZ8s4K3yl65hjmn889gdD48ymhwwRwfT5tGJLFz9ssrzvaQyoUDfJ4XafdgapRkOPbUz2OcZK2rRGmf" ..
	"Ctzvot1ink93eSH7NWF4F5lrIyzX2vyY3Ct2eAQmAY2Tt8QFvoWsQk9im0kRpyshgsR4vk14lIWGeTDBXZL3fhysXHrMtkj+qqjp" ..
	"hm9sh5ABcDt3othH1+ymlo+xD3Ao+jT/kjNkA4L97LN9OWnMYZrp95LavfnHey0P3Ai24dpbI7wVJ/Y3gqAHxIARFEFpSbZ+gSQo" ..
	"5gNuWWQpm6oT+BtGB2GCKAn3tRLJ6wcUkCTh2mST+Ahebcgh1BkEgfLQdYI08xVO9wDVEuPIp0xO/9+DAhYOlRU0j4Bap/R+jiQg" ..
	"0b7/OZHUdMfeyfnF3mOc//s8yHkuFr7qgJt7xpf0YdiTtyZHlchJrVkgClLaL+Rm0IoeWZS8c6h/w4d9/cDmP8zCy9BBMzdt8oK9" ..
	"NaLxrNo8EY3VsWNr9i3175EsUgYbpHaCBHIPzHASTGcEhJu+hwflbxt8VzBgxtMe+LKlRNTi/EqPh4BszX/HBlJJC9XABRInRIzh" ..
	"H1ICb79OVXKTTQjrGwU8X3vhH1CHkgAa+DEGuE1H9yXtVoILwagr+JPvydICT+RHH/Ud/1YXpg0QKo38Qcag8/0PFv9sXWkY9P1c" ..
	"mRxz0DZxpLQ4vvz6v5FYlaGFW91751eRk76ISGVjZhTBOhnv0AwRvEfPnpNHs4RLVHnjiq6+uMNKjlyqfA2/PiIwiL0ZscXHm+3x" ..
	"7Hy+gnq0Us1oNZUUrCFliWwDRsp/fvlMtvgLAZjEFQNBOUkPifW9eL8kFptD/yx4e8YNmRjXPNlZZoF5yCxKrj0lMcWM5AY5/8CS" ..
	"3P0OCdNIgq+i5g4a5HHX9cI2e0ulYptkikWC+qEffMMuWTq728rx/ndWqhJINcc8YnexoXc9t/Bkfa5jEzg9vA+aqEJWHcbREqGG" ..
	"B2HI6VZJlkf47QS8B2tVIdmIqBMFCw6cZkQM95VnPJJ8byDyHGTjq+qaJ2Di8HLN1KKBFcZRoIPU2Ctts4qC7yhNWrJIjoHmpU6g" ..
	"vJPJSOPUGDYT/mV1RiUqcO2VsyF1l/Zdlmr19oYVUqTQ0tZb300SlPlVk4rmkLEbKiKafhEbTufJpYjXCi/i5/NfbkK1CxJ4L1ER" ..
	"Ptj6JQN/15Qu24pwzyYDC0lh2kjxg5ISU4sOIXbNiSPK/3NPsuSlGatFF5HVXwt+KS9VeODdo6eZNgTeA3aCnQMiJhX/W/VYDktG" ..
	"RZ1FnBc+H2U/Xs+znjWcMVqWjPcP1CfUCv8cvltfD0v927UXEf6okaOnYTVRoIRsCgKkJSlxL07kUt6qTsyN7IeOE/CrZh/R2veU" ..
	"oDZodpniwCIPWTvvcrShvrXcKiwONXyYhcKH/nvaAmmjU3mpvI/SYoRR7zBqi+duySfI4zJOX7Eu4xURnHqW+ZVSPOH7yOcGylnj" ..
	"wH15FC2CiUKKKRalulfeQNpy58MECA2cH3QBEG7PI4qzxtLnkPOFvX7wShA0in4u9nND+/G4/3WdRVatYF+6eXvhMiNivJrmf3Ln" ..
	"OQESQEvwb2qKcCFW0xEtLAndZ0yORcOHgu6TGaYPevZMFbN0cbZN5JMkcmSIJYoD/VjBfVkhY3y+yVmstH8sAFj6m/7tRXR282jR" ..
	"STg09M9hnlsrgs9nTZTGAHFrGbYbsfyanP8y+89N7hj4KUtium0N/1ZOrnN971r6CMGOmqUz4tCiYrP4r7Y2qRWUyQRHVCLNknGv" ..
	"eA46/s1wz4BJGDAjElBtE69+xx7odqThdy7yPxzSRw2agCmjP0oNDEhrGif8730xJ1R2/VS70GnIB5js7ZjKG4c926KWMcPToBEQ" ..
	"8OkpmT3nCq+WwD0qT1oek7GzSKphDuY1TOPxhffpub7yVYcx7pZzjAHQIiJqd+pWSZn1zxPKwB3ttn9tnw8AKJa7jlnkZbd2pSgd" ..
	""
local PAYLOAD_P5 =
	"MAMB7m2P1F8P6Rxvx9UPsUbVVOvruNNJCeGt3wRJj8/p/qrDxTltZ5LSmM8X1g4NPPPNQyMUncJo8/Q17SX43lMdSEaeoOCn61mu" ..
	"wlTQ2gsl2JKi9CvSH0EHgyWwyIC9DG8kcF+wkL+WxjUjoz/oWy+iOCdhuf5/rJf6h0DyOa7v3kIGOTSVkwmE8EYZ+oz8RLVrao9u" ..
	"zNHmbwfLyOo/pIohSjDi7D1BlO1XJz4+1ZY+Wqtw5SfdBweD6L8PPPkTej6sXTAf6xpAS/1rYleDkVCAhN8bAEUfxx6CAqztqCoS" ..
	"Uo/WFSVGnNG5cJkrB6QWzkccx5XalnHPwAmui445mKQUczi19IxTo8w1zvU7Z5YVwjXkWVIhDZHJVOqTdbemNzZHLhb6Yk3FTOtO" ..
	"BeF60HXp1NZmUqj1AKv1FDaDF48Ah4oMmRxUGNLA+9KuJayXGlyvRYwct7fXD+27jCgLxaQJNPtjl7DvrAqDXXDW4zd10F3aohP+" ..
	"HokKXDo9Pi9UBMKSrthg6kER/PZ3/e7xxoWZmrbQlUlD4pYgub00YJiXfE8hX4J/36oTICgnUbo6MTUnWUMk6vd9zOgw3fq2EEE0" ..
	"hRWzDNiwFPRBrqwpux/rj7kZQpMfKC5x1KFMFZYpcGSIypDXop0a9MlOGfaNoSemj67c8qgpH+VbmuSU4JTQdAZ9swFC6PkW1lq5" ..
	"kqDgExTNGFfqoYcByJkKTINNmmYjl4IwSubfd0H0bSc6zXnAaByfZxTPCVvN9x8BOfm4CRZmA3qFf5CzPJjDGN9B2qQLdnl64lRO" ..
	"cElTbE145LTfnW2sKkhmrlPVG3KLxVIdOcRjEKfFj2lb8i/a+PPXBQ6Pc5PONsIUAVsDpBNlkS7WTmTKwHPYqprslgHump7US9Cg" ..
	"/oMFrCTeX2qzWSRdDaPLsq8RH4+MB0v/c5ha6+ckswZZZqKUx5uAqOHjPBI5ONFZPytkPc8A6o0pya1F2gm8P5SA0hgx3uWhxuug" ..
	"EF8QN7C7zfxih0Q9ZpubkLyybJGTzm/KfPaKCNiuUeuXXZ7fyE77b5xLcxBphVUmAGuwAba6KjSJBDZ4M95EjWun8ye60E+7+Ghl" ..
	"uarFffwne+Tn0IZTz3Hz5+p1bWDNueqFrJaGJSe4zS0Keq22go0otcqMQ86Jok5MKhOyK6P+vO7+7YQ9as1whySb5/htR5bLEC43" ..
	"ZJaP914BAh6Yjw6sfzil+UGJ70ulYJYrR3QtuCQ3zLll/iUuZGrUGr6ahbXVrxnnc4cCswd5LE5uflmc0MkKwqszIYe4bnHkuakc" ..
	"YdUuw973iv+e9mV6wrHxz9/cDxZLR21NKzfOQOEPCF3/T6ceIMEJnrMVMF6YVDy21dSS/cBQQkcgcKKHHZHMxi1OUik3b/M4kwVU" ..
	"Vog0wOOsKYHIvBc1g3oAknJVoTKREdNdrFxdyvRIodJuJ/4XiT8Pvu2VJ2+2oU3VLwfvLV/IEEMQNdRhRlAASiomAQcS7Qu2Qlwq" ..
	"LGJq4RDhwti23Y60OU0u7WoQwb4mkHDmbVA3qvzeXQIoc7rAnnPoQ+n13bdtErFT3/+wNgApY4FB5/sVknEphdS0JcGZ9mMI6tuY" ..
	"yaRm+R6Fc0otxtYAf9LDfMkGpIB86Lubb7kkU+SP2vwmzZ5/Dk66aj4LeZRBSMHq1GOyc7i7Cnc/7J55I/pv7yZ9uruPwmFNFCoA" ..
	"EpRGMBLbTlo/F62GiNttiaL7FsSJmJPrLMqlRKD3eVmBK0d0wwa708X+VQLe3sz2UmRu1q5TX7+AYFIFc4VZh88vdcnx1VScc8Yn" ..
	"ZFdnwB9NRVY6VA/so47ONIxQ0XzXhXMeku9kPKIYjvIOOmZrnuLdf7UMaGePIxNqG2K5CGuVghUjARN2dYo/XautvQ9eWvEzsla/" ..
	"SzQaefDrvB0HYkC0w4fV4neLjsLiYuQsPqycajEV8R2L4eDNG3clT4xTvJ8T8SwoM+4u/YA2ZnnwcnH2q/MOsgoFeGAfX7VXxAXR" ..
	"Bcz9SmjNrvMLIEBm17bp69OyJM919YtuplpYmY+m79RMmA/MrZgUZ24za+HNDzpkMNBhuKSLGHWE6uNdAeyAjG1HrCSZ4g0sRysy" ..
	"cCM6SChfT/L5jfuXfljc8tg0TA7BDIuwTR1rgIpX9h8aPXUJxbM4v3FYxiBILmKS8rk5CVI2k8mGH4yzJRHVYBs6v4KwbVrHhUAC" ..
	"4JHFzsDYmcB3DshAcvRsOYUsJftrfcTZYGzbp0WijcGxGRiZaYgLB2wNtMsiA+p+0VhyYmCvZU7JASgNZXiF/ViIj+LFGxkuDaq7" ..
	"vg0MlpLyTxnKugKq4j32t5R5rPWDsbGygyMrII3svTUU/wWd101vpwZ9E4IWxKEca9sygy6/nusVJ2sO1/oTIBW+a4JM9CCyPt3Q" ..
	"IqHOQRtmBSiq8JI/aBNOPqBqpCY3fw/Wg22dTgNlpwsbJGMFX9+n/tRTUSG3teoq2cQbF7FGpiWF6qRdMbdDtmu50tE5JX4WfIOm" ..
	"pnP02RMNs7dwPBpMrv3ozHyOt1CFKIZV6GqPXEhTl/UiuzEwUaPbUEfVgY9AxEcUpPfLugT0ccT/rdXTaoBSJTIcmHFg7R5zVOfg" ..
	"SlR1ruJTp/YpOuhkBGWDj3BuU5+NB7ookVKRweaeAHGdRL3918lei6PerB8UXu0XU9e3Q6E/tsyElv3puyDzNI0n6/p1HVippGI2" ..
	"sehS0PfNGiKjI4i5/8ntMe1hdAx090MlIxSCg80FHvrdXVSvaFFXYJOel4VitvWorDeAGwMjQ6k1ZMvR+BcSbZwrMVMHBFLRIsVV" ..
	"OwkiNGKk5WJX99r2zzDE5aygLKj55f9MAVnHCCvoAyIuqp4mS/EMK9I4eaaxZ93PoGIlyCoxeobY2WLbJnw2h7dNZ9YR6EVgy1Ja" ..
	"SVFkqDfb1cdrwZewIt9Ke+TRbBMKQrBxzg3b8BjRmMkXSNI38HDZqok+8+YvNaSr4nOSwLcynW97Fwh9b8QTiCtxPTxQuIeuG5qS" ..
	"QKy5SwUvkAU6VRQHFDGdmVFuGnkCkyGqof/ibXXDAVFQjZ7gE6DSPb6siY8RNx+FuhmCLlkO8U5Jg1axLNn+V1wZtFQCQHU1yS8q" ..
	"W15kKyLUxSOcrpUYSOWsinPStwyaDCDRSRjCpT1nDNfYLhbzZNIIrzN+kdCEJ1K5k+orQdgm/gF6jCbPXTzWmmwzr8aMgNTxevc4" ..
	"IX2oKM7Op0Js1+wZn+6RBHsLk5kBDOYOm0Pj7F4PGcffK7200SjOuSHrvtFpybjCleJ6kXjru/OvmHY1NdzRGnS+OoCMjRr3U2b/" ..
	"tjugvTMIuVMEDnVz+N50GstM6QbXRMtGgVBeKFLyppkfTms+KLRmclhVOhdN4tIlcnoLAOlpRcWjRWkHyhL2rGWdU+1XZ2g5JB9G" ..
	"vXkbA7jzKR/4iv+0En1ZtGSJwwB+BNU7SMLsd6cFfXGOUkRD3Yy6FQzIz26y8mW7Rwy2rSZqYxqbMBA2xC09TUcNwl5u9ku/x/oh" ..
	"yQQiGbxwMXZjweoyWXtGDi/RBU+GXSPf19Dlz+YgylMHd7boyugckhDlbAHnY8OXa6xXFZsFzEa+hSxTM6E+Z44WQflkKeM4pjn7" ..
	"yuUR9dKafEPr1V444qE0lOCdIx7bBP91qw6KBs5YXrm5qsP/NYDUZ7SqLFyj8NMfsUU8VjwtEUhcPzc0c6XqDwt5tP3TaQgSp8T7" ..
	"O8/kQ8Ll1RGd8z9N8YTmDoNPV0Z/j9z6k+/JuPDmnH0QGFblOGsF+ukO7NdduMBFqzfmV+vyMGFaa6KO+5UrpwUShBrxTuutasAm" ..
	"MNXQv+I4z3F6JKUCD5aSBtevcAkblmuTVoGwFBfJvDvtRMVP9kV7CMLL219mE4l9IovUCMvFZMzD4u9gYzWj6diQPcAPEHkHXlg+" ..
	"W8e02ItGEskCujNKELFQzO4SGJoPb5NZhCwGQu3+g2jhgmBizRWi71NVL5OXczX1opV/6z6UsaTxs3qIiI1XthTw8jSDaHhrgxli" ..
	"FSuPS8fG8A6L6ELj+5yq0UQZT2u0L1UzjruEUUcMTPXYL2gpFIe7E2hh3klDpS6a9NxMqSoktz3EyzEzFSZo/s+jRcTCSk3sLrPR" ..
	"Obx5SlP8pUFsa0AtrHuNxLFU+iIScoaangGE2mpYFXJKJbUg8ijXW5OIQQs+6zBlVsMU/1WXKnhW7nAYtiogEq5u3oCNJp0cFn+e" ..
	"AA/LLcZVNy0n3o+Eh+JvGg3AsIN3y/DUIKULJqZYL/b1i8n/76w5yfcbuUxfAcUUCmTcqr0DCsuO3kkd8eprz9Bxp//jvUBrU+b9" ..
	"Q3TZmQsTp18UVRYHVQ5LyZ2mOq+4OIEXzOPQAFLSx4EsUdKWAkWERwOe+WILOnD3r5jizqwvYJcMiVykamq2tKwZY1OpeL9pkDHM" ..
	"fYqsODKyCZnviDYsB9NUYDzXSevo3L4gZjOmYx8vYtL0cYKQS8DUmk8AX+wtUZ5gjUGSqohjh0C/1oc/y3os8zxZAZvDuviDgVUj" ..
	"WesEs7vLK9BBwcuERyrN+G5HAa2gPYOkQh8AdXQB98cevRP+iqJyvpgLLoUERboCPCZ615vy9TIynWfqt8hwflc9PGOk6hRcgonK" ..
	"9aoYWblMe8dkgRzoaKrtxxgJAi4iCvr+IKofGbboGiB6PIwNj/4lSpuLwAjsgiS0pB43Ma0sPxPpqb4LTkyWAiWJtZOoFp0SD1wX" ..
	"XpY3d3xAcQIFB1PRZH9NbuLFxZY2jjkGyUr694ctAzw8st04NhwVQj716l/RpJsZ4uYiIv5G1+sMvvwhiDZD0Tm+TUTANfp22gry" ..
	"VAC3Hy0MFvkFAF01OQiYoSW+Psc5dvechMUq8jNTCV1tc6l5jWKzyFRqLk2fXK9UdqawV8No8sFl1kx76IHBDYwVGIwOu4WGP+g9" ..
	"mtjUCH2pzZvMmeWYt1LnCkp9QlWb0DXGjbOK+hxCod6byxFkqwS4lk/pjHHUXdOLGC50yHaX6GQYxkVaAtuoa2nNuDDrXqmSI5dS" ..
	"Aaoo0iU8p0hdcp6kS0JRuKUhXR0t6dpzIWOXa2ZEt8SsgqHBnzWgTCN+Z32ztPX+J07ecsjjtibO9x2U/b3bJDO6lh/NMth7lCOz" ..
	"XXa2MQw4NjSI5KyWPp81VkXexrOxbzNsh0mVBvYNbubOHySJ9ZqNPHrhse4WuJh+Ynf4n13yiiQgyLj3FZQrVLDUWoI1z8QNYcKK" ..
	"t5Ymr538/IiAaQXaQhGAVn7zSnFTDOqGU9oVVUGwG9B71OomTBmz3LFOooWJCifc47KPVJNxK8YXKAy3NhBZY7GN6J7R4y3nYDTW" ..
	"cKQnf04VphuWiK1pxzZej+sgjtR0yHdkPsSPWlrj6tw84FBt+bw0clIakP1RNZgSgWvBbUl1mjJs5a3xh14kD+RUuAqsKDsmSo0d" ..
	"XKBO1OiDHZuLCNdtxmBTLNHS6h0HqIOL09muoXbqnPqz4HAda0+ddDLKNrYmN545YXEslkCBBCoLP90GexFQ22eTvllVOsBJBQ9B" ..
	"uH5IO5L2U2x4swsKVcK3gtZ+NjurgioDa2HYlauJXLlqCdzbrjLKI+0Mzav06NBViCYSsPWTdHSKF/j0zfqu8N2E/rUpSqyVYW/h" ..
	"GYHW53lbAbZPsOwK8mqvFjvCB+T9H1k9f215FpAoR+qLpgrsd/haQaEsR4hf3oiDM5lN7iJSwHKuxsNm5ocj5r4/qQGGKXB/LtgA" ..
	"YAbUIE26QunkBCzQn+VKVhIQ2svuJyqWq8gmY1LXMCmrfV7ab+zvalcaFNhVuaomzZ1rTf0NT3VEPOS4fMH1ZpsWbqCnv3g80zNH" ..
	"xJAIlJSSArnvG/pvRLo9EGO0b89dHrn3oOL6dmr/w4fU3sS1ZNEuc87k7v9UQZC7Og+kFdC1nFIX6XmiTXfcJJ+FOS6jHadhkcxV" ..
	"9wrFa2vn4zrVY+6V/CpI8j4rOC2Yd7o4piOZNpmx2O9uRNJnlioiCcEuddnl7YMAiwJDEtnoFwbf9DK/K+GMAZ3TDlGrp3F3pR9H" ..
	""
local PAYLOAD_P6 =
	"O8Ca0ao5wA75a/iS073LRd7+leg9Vqs9eBzAz6SI5cjpZ874Xo02BHw8IHVHw87oxIS3dKGFWNFmeTelVKoFZ/mGa2VlI+h41r+U" ..
	"QiF4EYwVc8yc7gfgzUR8Lss1AZwS1cyBzchz4xETPij0m5wTliYU8eBxxeiXFSEgIQs0rvh6LE0G01277lB617Gr3mBWVUBOIWws" ..
	"Xca8JsdDlNmgGoIcZp+zUJTCTEnLLoVK42rJQRty1EADNSdVWzL5LdsOlO0uymOLnVrmxoRR8JUzQbvDdK/8otYuFArHoKfXBaLB" ..
	"s5vdZfYk28hy+pT0FWLpfZvInzrqkD39CGWpYrbk+kv/e//uAXk9C1MMHOuwtMqCMeO5Aj81/XJ1E3sdoE/UPPM2vFjCvjiqDUR8" ..
	"mA5GM62ywf6u+q80h7CmtbKY/E9NtochHaJzNmziUd5h0sNK/n3CFTE4rApClPBjo/dFgOLmpyRlUx5nAeaTppyHI76TAcQ2FsZP" ..
	"SZMfTmoq+7t+0b/hU/suDXjcVbYfwI8w9e6CxRuMwsvHecCO5CVmJTR3TAH4Rao40vu6YD+rlbLji8/6TrpHgYloQXi3Z/rNE2YI" ..
	"cV9hiN350s9nH753dZdWKcx4zCy/8taufSI=" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6

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
	local fns = {
		getgenv and getgenv().gethwid,
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
				pcall(fn)
				return true, "ok"
			end
		end
	end
	return false, "sai key"
end

local preset = (getgenv or _G).DQ_KEY
if preset and preset ~= "" then
	local ok3, msg = tryRun(preset)
	if ok3 then
		print("[DQFarmLoader] OK")
		return
	else
		print("[DQFarmLoader] " .. msg)
	end
end

local sg, tb, okBtn, errLbl = buildKeyGui(function(input)
	local ok4, msg4 = tryRun(input)
	if ok4 then
		sg:Destroy()
	else
		if msg4 == "key het han" then
			errLbl.Text = "Key da het han! Lien he nguoi ban."
		elseif msg4 == "thiet bi khong duoc phep" then
			errLbl.Text = "Thiet bi nay khong duoc phep! Lien he nguoi ban."
		else
			errLbl.Text = "Sai key! Hay thu lai."
		end
		tb.Text = ""
	end
end)

if not sg then
	print("[DQFarmLoader] Khong tao duoc GUI. Dat (getgenv or _G).DQ_KEY roi run lai.")
end
