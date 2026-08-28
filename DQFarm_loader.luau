--[[ DQFarm Loader ]]
-- Licensed to: GNURT (1 thiet bi), Gnurt (nhieu)
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

local DQ_ENV = (type(getgenv) == "function" and getgenv()) or _G
DQ_ENV.DQ_LOADER = true

local KEYS = {
	{ seed = 4240943211, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 4240427133, exp = 0, plan = 0, hwid = {} }
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
	"PL7HHXAubFpBEIvE10AJzVG27wh0eEoU8BmO4vKNcPIZuLd1sIwTIbgHn8JcDU1s4XLotAkJj9wAuNDDERA5Yyh/jfCSlzmuPWST" ..
	"v5wY3PGKZQdzo9Vi7nPjP7iUBfsvSCVE5eQbhhuP1T75XN65st0qTf73C4+BmsdMWuQfDwMKl7xW269DjcMwn0WOBNiBlcY4Inim" ..
	"bvjShewu74UI7kAzbKNgHO3+VQjz7gmNT+FKXVAT9owKpIXbacW0jqBsOqa6X6F/hiW16dyiGvczUv8wzeQV6pDCb/qVIu5MGekt" ..
	"zqw8acqC2AKgOp7cWjQxOb6NuGnm+eGke/uNRUYL+YqmZy3bSca92RA/CRDV/2m+5vEkRttUkwnJwaY1cLltHtKl8cMlEtPqqZl8" ..
	"8pHu0ceP9wJ22NxPUqGPvCdzxdxsyDs0PveWGQhrEPaYAQ+llqlmvJbVUvi7nF8Xs0gh6cI61leMp0XwbGGIIJQLifJqJRh7CO2N" ..
	"IN1qPOJ/dimsQX96Y+Zwc39fsEP7nh6GEMAl8A8juNxBCrKSyb/azThdiwai6Eh54aoJBKtQcbRdgYQeMxb2LFAnY39UH1MR0N2o" ..
	"KHRWZxUMoKg3gMCrXVAhrknImYIollyEhYdNFHUmsSn+wv+eQgxNWO6V4Lp3JV25qytlGfd1TyBrNsBLJfQvrBckigF8SzHZc7ia" ..
	"ESlhHovGt+kHWSNKRd2PgRIRpNhDkb57fefeNefRSx4RcGnYCgtkuMsdB1Qk13WeoOEO9covXIwDX+3zmtQC6IGWBycjAIadjR+E" ..
	"VUIt7Iz2Ph5nFZPro1EpwVOpoPFwngl8wQYP54N0Flz4FOzGlHXxqq7PJaEQ71Tz2YWuQj4NcDO0MbZChhD843RJHd/tEjo3dghd" ..
	"4jMioEs7TZKxSwUW7wgDvl50Al5nElkpr0LH4md7fQTpBycXOLZGsslzCkRWS8bX9Yb8n0TLw/wywM5945UVrN+QnrBf4PiLwHkq" ..
	"yrSEoa9nwNLUfJifNjuc6rYP9c4lJdb+c3qQ+tELVrBwXtkYIjn1BcwweWIAT/padbnhv1/HU7atPuMNXzXIFWzuRZvZ+digqODu" ..
	"ochDnsXhkCSk6WU02SYLo9wXTVXyV21tnBZoef6pxM+1nsuQw6Tp4Jp4AghsJR1wSAMQL6/bF1R3RjGVdOO3WQZP0cDgYUpYkE6e" ..
	"rRioomXLeP3ZXwsEVtz1Z64NuaZq8Av4DYgaY2Ww1HzFQZQ0fYeP7ftP8Sus1ej4m5qO/wd1fw59fGEBZXSHfcB7ppUpjPLRt6Fb" ..
	"uXORKKLecicCuXjTPlKNxmojvsblhp8YYMYVlW3D6+NhOwfhfOijTY89TW0RqJ6PK3C6yRgOGS/wyd1KeDnY1aXXabGeWvlcJLOQ" ..
	"ykJ3kt5Lb7jrMj28t8GdvXZlAYRNinVsDW0WERLF2aj1UAmNH4zrh6TUabFR7usnOOqcu4vmOacnI/LZzbhP6fTg3OGjmGM8Qauu" ..
	"dRpTOs8KpLF6tDVFSrmHqF54oxOndd2IHKO/+6oPCPsgjbfLWhCZwO74OLLmuHl5aS562Vgiuluad+3WenwAPO5g4os7675VFxOd" ..
	"iiRTq2ggMERNtgoGlFl5wtXHKWzOfAJl3SFmnJj3Vxb/4NRR5FCGBUJA0+zu21ORE6w8oiVrdhHdh+TZ5kJsmYxhJfBWiq0loNXT" ..
	"0cESXAE5lm5DUATBSRsxvFGlwyMPBi1lwzUyyrQ/ZsLHu22uWlJppvPre57p/dXUuCrpRHScV6XDo8Bjapw5XjdU65g4ONCNA5Bx" ..
	"Tro07AoUwf16ntEL5p2Z45rjn3pwwnDup5NR3KhNKZm+21Nbyz0APDSAu9+hKk4PsKYKEvTRGgEYwxvj2S9TX5fD3K83w6yoW5aC" ..
	"ZsDwFNYiCpXa2sHqH+4uNPgF402DUKu7PPHL31z6EGPawLyCqGWRg+dEhShwNt5RpvZAqQP69H4hHtVS8yyenSC6iHzmR693V7IF" ..
	"zPnepsbxBpVTPJEERq5y9wWHt+HwVc1ZhaMzSToxOXxlCYUpaWM4gJPhPObAPwnr4xbL1sK1wH3iRPU1AbosyWAgFavMcR91OF6E" ..
	"sAmdchnQbXoFLjaQxHdgNmYlFNDFfMk1tsOT5YIdWk/hpoEFRBIEVv4A53vz4NI5dIBzCVbXSm/sm1UyG/LmLwXIEUmvpzhD+qPI" ..
	"CsqEyWyu8XeEHFzqFatz+WNF/KS9fuTTsAJ4i9NCkKjLJ5J4c6Er4eKNMXPMoESc5ucqU3i60SdXDS1duRzqD/XFGsHZeuIUITHp" ..
	"XNNAF4ZrvKVwMXc6e7crZpcKOkJJ506+6j7shg9DLrJ4KPq13tgp1qZnL0wVY0umRoEeoC9L6uMyIiqFJfj/+qkleSQ6UfnXN5Tp" ..
	"tflALTqf+y/OelYpTpuGGuwPSHpeoS4QPmMBs/3alH4T3pu3ZH72qvBvkvesVBkRo/qfDQ4k+mG6HmjCRRUsasEoZD1S0zaOV/4V" ..
	"7FOvtEXyzChv2vT5V/Ify74XHHonEKY4T3S1g1/lIMdDIzilzzZw6n6Vow5XVfYH8hY9LLgJB6iVZhgFkWzYTMwVs+pQM/oRmofP" ..
	"VnI5+tIFyztCfV1AWIVbek4x8NmPWAqAVkIvi+d6yf8wlvk+451/ldyo1Bj8ADoUOJ5NRGXBSwYYRoBmhXyNJfFBNVvnb+JNBSXY" ..
	"uc66TW0WjLneJ74l0QZB3AaTzM0/Ziz84rok9AymL8IXCfy7QhyiLiwKiBKFPuSwPkyVJUclSudEDlz7LInPtkqcInG4EIqnHkHc" ..
	"n4A+2rseIgdR3jnlBOA/a9ZNPLaiNn7CfzmKPTSjBfEFMYBWD7GN1I1sYJT5ctFoGDCNQQu0leFwjcQ/U2GwuxleUIPKoUXrChWw" ..
	"mi75PlnwZLQwXzvpMZV6fkHWQivW98+tYAFkl1w+oYIpC8GKCYJo8BDKr/o9I5xTMXoLzn2Nnq2uB2ZakKDrH16gFwM/zYGh1Ad/" ..
	"JhPvmfhLu+6kj8TIpBNsRxltXKIYXzO6PjRpgXu7ajy24OBcNMASLidrauvvptlspgUbAuqSNH12y9UUBLjJ8zlv8qniN5L/CcuM" ..
	"sVVDEjCuaVDEA3Vgylg0XRgh0dH16mbp4FfsPE96czTJEeUQ/VVj1tQdMda98WeZQY/djdItH5aTR4ZDpbhrdRex3xoQWDv5B5MP" ..
	"TaK4e55dMAL1dC6mUggl1L9A9ow/jIOIteDHa8hNLX9Gn2HRC6hn41Fs7HhQLAPlJmpzNx06p+BU2a6RZwpDnNW1G9sl3Jb9wFVN" ..
	"DOnlgT1bxbFKXPWyeJr9zdlqH5vTNL94n1ZmoDbOnN/VFA4u0FfyTTP8OXqXstMb6B7Yg1bOD/QqDbzM/hTJRrFmepQdWjYDsoaX" ..
	"QJhLtBWETTPZHPErQBMX3hhneE9puBEnDbinr5DRcvYcLyBj4qHD2RXQEKKEm+EmaoPkZ3QYmE8TxAAxI65abI7xntiT7NsbvdJ2" ..
	"htD7NDTxgPmfoPFAFCgx9VNONc0VRX8R26S/tkrkVuiUu/VnTb8mx7c/ue1IVvNsx7wJ9id5A1vMcJGUjOgf8GzzWBvaasYPooRV" ..
	"WtCl0URu+NRe4+yF0yijC5UhWuSFo6BmbrCGw+7A2n1CRp88lK+NGItREM8CfPLbmcoMXIVsCYvPwMjMfOjcJZPJyhJgR3XeELFQ" ..
	"SXvs96/T9sBkaXVqaSe8ArkEYLKhaInx8OwQ278Py8QCqDHpCB1D5T2XdasarP9r7NDH5U/yeNv0QINAcCeL9E89Yc+evMg+OUL4" ..
	"u6dVMn1E/Pn26t/zROmFn5eGrDeMS7+Za4skbutC/wp8yf+ph/D/sVWkGYdXIChgv0X031bSWAZQMkiySgLMCbnYZykgThElF5QC" ..
	"eRiwxvnyv2IEqZLUpfvnAVZxuNZnw3uLxxmuWVvRS5jF+WpgXuuCHeP1b00iYh7XWYcff3JvOkNxihL3l8/rMXPgFiS95gJKzVt0" ..
	"VGFg44lbrfraucf77fQL0OMlfWCrgj3iJTjnjlqlSu8hFzOcqKssRb0JEAML6vjsad41dj1YoWgaoToQf6EOcPnjmQfcx9tlNOa1" ..
	"H/w0v5Oj7M7BjK1Wb997XZk8nu2qdhQCmnSMylF7pgqNxSr0Xe6sP444HwsoPi3ymeccw3KOZgBQ+5QjGcLJlFzGs8S4eIM2imF7" ..
	"Nn+R11lLqS2uOAe0incXsF00yJ04QL4RP9j3iIPHQK5JbOBxa7Y35q4fQWJ4d3KY33s5mC6Ub/mOl+yusJxQpfayXdr8ReRO0sxe" ..
	"RY8KumoVxdmmQsyd3ZDmwnnDz54ePpQPxhPltCCJeUxWmdUvfG5daY4brho/ShmWo+xUNSGmhbTk9rKn0DXPmPhSrZsLqv8xNadb" ..
	"gDnoLe410zz7fn5kQFvChFRSIqb9E3Nwkui3Hgb/MzQ/dINTiVU+0zXeZE8N503Xge7rKWWYFuQuvkwKmxfQJkXPUebmy8ZD0sMm" ..
	"/pvdPwhW55JqYdT73nlfwLnaGNpxFS2ikM/yATCbusZ6/9ilbnzBuJM6OIUWymn3/crV+YmMDbLj5E9OBxFyaq5bp5LyX9RTBE06" ..
	"y+Ir+6zEm2GYNGwmw3zoa6UnVAZ6Wc8dLDLHK+rz0VXbjvSpSgDhTVJDBdkPeaBqYc1oVcDIxjJVvYNH2gc7zn99TPGsCdf6ennu" ..
	"4dmp4Z+hLmqr9ST0XDNQlPKG1OcgtaGFL+ElJbITOs+RpPWStxRlwxiU9h+onIT2JoAqlVQ788dqA/9coNCtr109sVNRpHXP9dFu" ..
	"aLDZLg3hWhUW4WixTbQOqybcjvcZTx26JVLICPAVu0jLUYDZZq2j5TgCTNp08fgXBUYcsunTayooXkk2r1tbzKwvFFOXmRSOMfCZ" ..
	"zrtSeAGHogxBln1tMmY7EjKiqpsFxcoRSsmKQJ//jH8Vj4/PX3UFyABW5Odpxf/RhEvYFtDK+vFB5cMFj3qMhiQLG6Jj9j8VNNEd" ..
	"i80AbTquf8yz7YZ4e5acEYF6Wrig6NwIG5R14dSzKVhTEiKglKyQ8slfc3beuvPUQmkCgk80ur5wyypiQLSn4wA5FxEoXeYSDzGu" ..
	"UgLnVMsyzpSXL/b/PUwMNMhnt0b3BFZ7V3trB3QIFpf2h9sP6wUYT76GnABPAOd/qTB1d2Nn6Ruf7zkDTxItO8kJRrTJBCkLNxUu" ..
	"Aa0jqkPI3SkohkcKUm28AGyu1y0IOG+DV0vovf3XHHWVDBTTRUxZi++F4r27pxiunPm7mzcoRlU8Xr2giUBlbAxx97kjtUoemnfW" ..
	"ciiU0flAmH3A/CAOvgrldphrbQGl+BRpXeFq3scvo6X2+YT08oIeq8gLFiDprVLn7h6fIk6ZWyO7jVn8KqckaRZTLNZS8X3uLcy/" ..
	"C+dmfbJIP2ix1wZom/cQKsPmMFefe+W8fTv3eX+mPW62B1JkPWk5UBc7VZx3iXA0DSieQo9sW0MEQAm4IKpVm5ILNkFVYRVGIpqQ" ..
	"1pwsE3zvNrgAxI5dTwsMe5Ohx+c82YIPtPlYG1SqSnV7cM1oybjFQwRNericv3KUCY7UVneKFa3r4EUiZdB0Y/D/4kKjhIpoNJin" ..
	"txQvsA6hwswG94+UKWDmHnnD+QIPAN30Y28OGt2KrFs2ZFV8V6Qbxol+uikcmwgdpHaUcoybyCbEwzuVzSpEurGvuZWZ252otHaf" ..
	"1iRd7NXkky2O7QuRSAhMffninRhTsV0hMWl4eeyWUGNMl53N/Bl8uChIjwITuNQg7WmlrBiLX3YLp95gTepv8X7FCa+LILYaLuJ9" ..
	"WDhWh54XlIXi9Iz2rOK7ncGAy+QOs9pO8Dooi7enDcBRcPNtHIBdYZiTceph9ofhvls5+JYAyYoMKERla5NKJ9vVDwop18TW0nmt" ..
	"Zr7zfVFjOcQeUAeQKk/tZHi6YlNQ6I1SnrjznKUhK4j2CrFmEDqkVLJeuPKoS6wNb04tvCy+bQaHbV0SyW54Q7rIq5lQPAmBljwG" ..
	""
local PAYLOAD_P2 =
	"jibbelLb4aoncRMo6Nne6fhW5IKfmwcv//jl7/fBq/179cOccqK1hFgJr4jYOmwEMCA6dRL5SnY2/k1Et7PAWjwk/buk6WdvwpCf" ..
	"yxSxFSMNDJs0VP++ZJwb3DRwS2QG/3j6Babm1qSoGj/8Dj4yzjdO0yp4+QD2Ii+iHVUvGfHQTdT0XTbO8ql3sEaNuNTD2pqkYCtO" ..
	"PAr0bG4AgimCoQ6iZt02FyKASJx+JZiC0ZuH+OuU4xZeV+KgKucwqe9+yrAe+daxeUeIj9pBp1wFaM28CBRqnJnhIxXI1nXvrD8s" ..
	"7G7n4kmklbRuhCmreEI9L0FZ4zLIymVFOR3q1jzmP+djAyPyNlO4Kre12qEYenqcTlERQJyZoU9IYjFFp9Sl3ryavZ334VfNEKv8" ..
	"lnrsX/sxTwssztqREMFjT2Gicrs+vJf/Uxf8V1kl0VKGVrqFyP3COjIinLtkGwtmGcbEsZZ+ti8uwTVczZa9nH2JAbMfBKyWuCPQ" ..
	"Ev01XCcOVPDvTS92qj9j/c4MyPtTrJWEGmudnYL4Q74QbEDpg3sH277INUqM0eLJh7CcuS2fpIgVUjQ1WTDwJruV+my3RxD19saX" ..
	"+2eJ+ZQMo6QyG+WSR7+H7bP6uIrhjuBFZH0iEfDU7w3l3l1iyZwdCOHlTJhf70mvKWLudd7r4UK48m/S5CffuE0Z2Ceca1bTmrsF" ..
	"AKuBDnRbw84Ei5eLb5iK4wOyqcUM3NZWoBUmZwe8f3V/QNVnhGeV2togqq5UpB54yF8T0O5OM0/wjfRfhSixs6fWcGJefI6kKQRQ" ..
	"GbP7cdeFer0UWrbn5qELt+oAmk2gzS1aIzao/niQ5XBsFMbtXXFiDF5nHDASNG1UIkir0SjRxQJRXxfTqj4UlpJ6Mgl1amFO7tIJ" ..
	"sdUsu3VJMdWfbl0B2a6MG1T9fLz0rXANwN4RKse/AhRVs6gFqo+KeC7ep/wi/kl0iqmVKGKIdhTHpZVbZCyf4Kfb5sP/selyk6MI" ..
	"2u4Agjma71uwy4wLgNCAbw1kvxEXWwIU9PclxWJzIHgBXed+9EBctOItvVenapeRZfP1ZPr/Zsiaz80Uj98acM8UG/vASTzv95C7" ..
	"jomnb52zH+bHtP2uUHFR9XdT+KSPBSBAEjp9GFlYIj8xTE1KPzpO05zUJR7LsdyUAlhthEqsvZgMnzviqb+qWdPWzuFZ8xWjKsdg" ..
	"7aHZASaluSy6JHt91tdPVRiqE5HIKGk2Q3e/1eXZsmfV+pLNSVzQVSSP7IeFPPF6ZX/Pi+kZU4Wyx3fL9eQU9jRq0YtkY9I7Lrdp" ..
	"2y6N6EEtTRI5sdeNFjv4vkMSBC7mESbBiF4NsWg4+p8zvRuoogCBKyjrDfrO+g0iky+jB1kCDcMgN+mdwDhQLIv1ypkHtLvDUni6" ..
	"cAxIQ2/t1B97N7Ad/GjspQh6HIfpNOGgDwUJ9+0e28LH2W4GJSgooNCPBIpEDoFbGNZ2tjyB9Ivq6M8oEJwp00P81nl1X49JVBh5" ..
	"iNL7px815DTUhxJ7UtZy50161EMWHv8z8vkn1GqAsAmk5NghvHN1zEd0OOGN5hpwly42kvUXWxf1HAMWQWyMf7OfoPMpYcw1RxJi" ..
	"DEgVnybNHYhULJN3EXxjmumyieGs1BLZ0y1GL9SPOF05Iin2ZcOK+RQSLmHEAeqF0fwK7zEq4MMM91ldQX0jobepn6ExXYl1yQAk" ..
	"f3B66u3H7khAW/fpE7cQSaAASO7YWr9SLpoEtgPGcYt+8M5T5PLFqi/tIh0yJT6fsAsjSe2wIUwxAFkcC1EtBvY4WMcjMjyZEgLi" ..
	"VTfGqnBcBs3mg2YUOONnSKDN/3yjuM1oMJhPlK4KrdiLTJqV8/Jbcwm6Qa8jTCdr558/zow/8GyWFzd2PyOFBI1ltkluOkbgZroN" ..
	"+UyGnUotpYzDSOR3hwmt5tezZ2HhzVYT7jdK09PLW+nrRHMs+qj4NUCagHYOFywXOwBTQPYuLSxoFgEJhQaoQthLgh7E966MwOla" ..
	"LApsAWTpaoZlgAX1SdBeIXiWO3OG8v3ai7g81WjSdRcIFgNyo5yMEbpTQbMDQZZYoDBfi5nDavwNIYwMyn9uAQR144wPTrj2+JX+" ..
	"YxeblPm4srIPFcyCZdqbcc8e0jhBc58ifnLh+4lDF3uaOOpKjo3mn7JfNUR5FCRyX5qHnIxNFz0N2QEQvqPlSGABIMgfZYv76rfg" ..
	"8ZU58EI3chU+sTT/EfXx++R62vmN512L5doKRE6HImDEHwkaXHy5hVhBDbq2nmkOvN3QLo0tysuVAPsQat6m4pzZX1jjHAeuAMXL" ..
	"SXDXkrtfdznRk+VN9I/mf+FTvhnq9pl2+xonsVspyi6uawAvEZZUafScM484Vey7JhLNWDRhvCeC9Z9uHevoG9RwNKlBlHSUIkH8" ..
	"mBTccwGMZnTvLrhuuArcoRtEZdtO1cf+smx9QQ2kqZO8nTnXfxKTma7IFgeqYrUtnLxqhzHA/cmOvwPWobYoX+4sl0YkVNkInEvZ" ..
	"46RqEqg5nhbjjVCaE8Mk5yIELNEw9XVAtTIFBX8yOZSwoMFdAtospDUeALhYYC9kTnzt9OJBW6F5KgWqtFiliS+z8//PlLqskIfY" ..
	"u56RnZ+D9jCqe4rIP7+wWSp7UpQ4oFUstEPIAJeJBTCWfLrMLF910/cQqfphx3cXEFNf9ib+nOO5DkNgo7Wu/sLHvemP4fl67Kf8" ..
	"fiyzGt9YZuwLjl1WaaSsdk5B664yc6DRjzdKspqzcIJoYAuV1dS+agGpQ4wzdGh9o3mmoPyh5yALOKRgdjZ6NDg0SVj4DgUyA/BO" ..
	"t7Yk1QjyZFs8koZc5Iv0zdDWCdmLAd6kA8LBf80T2bqu1DS6OgsGd61BvEc5Le1K2CDhB53SnEKW/GP8P36ucbHlOVDgFpIR3awF" ..
	"gMNHzWJpcZz1BNVk9kv3WMvm9E1bgxRLvYehtZQvThrRKq/Ydy44hJrnqfHQJ6eH2c8BaOf5rq9uZlrlIkmowk3cbMHBVRM4vZjH" ..
	"zGThNFheYFa/LMVcl18ROdPkBOnNgTD1I86RCFVMXW8TvPT2SyqV/uwm1kf8VXNMEePtlp4EB5blE88gQNnz9YorSMufzgj37iwF" ..
	"8KtqNG6wReGt7tMjl//YCt2KSPnW+2Hr5oeG9eHtCGmXydP7mBFSsrGUL6ragplNPsWuEDerGO6QLfvtW6Yq8TB/CB8M4hg9r/wS" ..
	"3OSjb7wfnXcg/zbZ/eTVkKXl9zEuQthyz88bCdnNebKO+sMOTMCJHEcDVLFvqZ91+FRgRhXWmeH4NUosw7gL/TxqdRTGTVUdvCH7" ..
	"I5VxvgBDmiKbIntEv7KhjUpMfkKamS0gECB/3ftLrvPDUOdxNFBuUEFgD4Ev7XyZgJEOVhP5oRbkSkVAmCiACSVBKnMdwZJViQkp" ..
	"Qh0UhQBIp51y5BdV9JcJIocXQd5UsB5nlM6ngXXd1PUVWIiM2APqXHN/Kcm/UV67xHXdg/ww7yrUoba2A0WPnIYUWBQOvQQqA2Ku" ..
	"yukmpjUVeMv7u7HqhpFi0Dh5HDVVJVwh9sHqKRRqHcHeLXt5CgDc3YE9bawjkUmbVQImKCCKOljvFgELmsaJuCGA4wa0AyjGu6PG" ..
	"raNK+ybsyjU1spc6GAxHv7O3OAQkrAKpyJwDi1ZXdUJHxDcU32+konOPpSitOmrDPEV8xdy6QaH+KZbzTsW/PEK2fBovkMP+NAo2" ..
	"XfB1NSrXFHGHN4sfiVwVVAg0dYT00LV5i8bqT/+TFxfKNqy5Ss1VX2tdECWU5R8ipJclhisOjWOPMaLpKtmo8r6Dqp8N/2YBwqyJ" ..
	"D2CuHYdiwETRtQFrRRiQ6nEAEZi0cozYUBq5IMw0R7VdQzIOaSG/tjjeril+WYWjUKLEh/0YNlcHqL3MbbKcUAdE5AKQKZjfbN+5" ..
	"T+/YRmVRDEwIJLItxrxjmHryCK5RcjnGt95tSRj+kFMqPEWWySeAVvofThaZBDukkiJVldERwQUPDpCYaCH2o5vNxG6qmBxqox2a" ..
	"AxepqVourQ4NTis0VCPzZKqr4WGgfYpuAGOQJA+bLXboRaN4CbbBGqIasKddmAlEhmRuCmSQRHvvC1d8oJe3Tv8rcLz8WbVRNkFZ" ..
	"wZ/+ai1fctV4YD2OK/HUPwQL3PtX1LxMkrJ2PpgMoBdxrLJ8g6J6JDSk9oyxk9chQSbl/Dw3d8tU4BJ/NpZVebsoEnkyehiFLL/U" ..
	"i8oLxnjj78lHX3l4pNjHLaG9/xrGiKzxVK1+6HXTzIvt819R+umlneTAuCMExC3ylsPC5K0pIMCp8zwmuQ7eS8Ev+RXOf3CGpGsN" ..
	"oiWSPG7eTkb0wnoK9KfbBR822t+ExCGC3mn+3kZkHZqDd02kSJXRua95o7YgmzB8Unuq59UBe3jzsWWcssICJpZh0cZ0rICfG1OG" ..
	"/N5tkeSWVAV6qGJs1W6pIuLNKz5OiZLIA5cbw7euJ9nfUJGfvquLIwHy9tSPLzc9RqwfB3am3pYGzP6XLTk783QBUpdIi1G0U5aW" ..
	"EewgHbYkxK1aWvHvRVHWp+8wQqV6xRzijqtZvUeSmS42kZuls0Wypa3NPq03uTllTa6mPzc2UyCvFMNk2098sIz5QeZjtA4IVz+0" ..
	"zZlZrKcGp59g8zejPc4te2CV0CHbYcMt6m/TGYwvHoN6dyw5eqV+hea2zqJjhMPIvTgOUBzWStcK1JdOfHsrRimB/omAJfo6n2z0" ..
	"mt3V42dgZgpF/Bwnah9hkhbIqvZZ2vAmieVyWNX3JWu1E7CbTyQ76Mx01e0ekOCGdmG8TtnTKKaPAPlp8kkXwSljUksuRVtVj0JL" ..
	"nkSPxbrT/Sxk/2xGmovpYxWv016/Xd0BSTRk2r7f4Wm/kDexT1dNCSFuSl68qdiYAb2Gb4vrJqwf5k4Tm+EWpcHXUODzGX56ZZcU" ..
	"wpPmj7bgTNd4LAKoHLRZMiISFzKlp6GGR7EtpRB1Hpmfnk/fSF7vWhcM9ZDxQE5n3OzgpsTvdz7j0ieUAP2WKPeiBMFazcDEKt4f" ..
	"n2yf7KcCs5Y09sh/GgG7rWoSc3JuvUgaIFpQZaB6TdkYcyX26J3LtUin93p4D2MCJ/vCrMSVoVsVqXbKSHSBbL+qha7Eq+miF03o" ..
	"gQfJwvEVkM5mBAhy+eXpXadR0uP0TrR/j41QI9BIzrdKOoJYqR7D2lYx+vB0m6oDiUfYsG3y0Ji8YsSb7OmZTLmd7fevnmzWuGko" ..
	"Ch20XKoJ5v8epNV3k/EuN6dGs9d0AFctgXsjEsqU8l0S/I8PMADDsFUs25HlEkiCDTPoT088G4ExoYYU0wumiKaexsTD3cpzeZce" ..
	"mbAd9e++DAoVlGKfgKXs14ZPev90k/xpV7RXFI+WIsHPxz282GxtTmn9K0PNI457gNEpLRMoaQYB6T63HiO/amVI425UcEyODfb9" ..
	"IJs2YsUsAaDIcfn3gpkCnK7kKPCLxEd7H4amabs5aY26mmwVHbAUwclcXEtYxDa840bkwbMexXgNEhA0/5+iRmch1F6oPLfoTZKn" ..
	"emqRpA0nfPnuXX5qbvs2vKBs5wRyUUBcvI1KRbwMb7b7FguftXvuLxQQUlF+5YuHjHOb+iZu03dV7ZD8XJNfYOwJGaZ2p+9oTYwT" ..
	"xbI2TNh7ztsatNZGGbMqB6HWGqVDGtRxJX0pPVpIvXOckMmR1kjrHz0ebqj8z25SsGyWyfUQigYHNfmZNzDsu40PKu3UqtrCvk7l" ..
	"LeSJGXbxmxRhwyG9ECZMdGzT7JKrTPHxoXbOhpr4oiAa/8bF7WgD4u2BePM78ZCtN3mQrxOy15HmLByCZEbc9meE3ol5XNEgueL5" ..
	"jXF2b6Yp2E+KtnwPBqjg0reB01SdOpYuykIouueT4gohyrUkq1fAcNM/ae+Vm1XVFA8jGvHvi72r+LZlie+E4xfD5xG0qaj6ovQD" ..
	"XbCl/BtlxBTFxtQfq0wCODcHxPk+996ZS9mYoYycfJ/JJBz/xdnUe3Xq4xNzHehOlymOKW5tFU7Dx5t75Qyn11T+/Zl1FWPth3YV" ..
	""
local PAYLOAD_P3 =
	"NGc+Z2X19KaphWfW8b8zoNrSPo7bZu18g2RJ1BWYNuDXbWldNTE1D5HJoP3MBcQSiWHvoIcmgUK+wbqDu4MxyUIV0k3d6tIopRv4" ..
	"nG2hreTwUzYB78B4HaxfMMXmCATEnoAj9I6aChhnXXq31FSC6zqA6HjxcPpRMlIacDXfgnh15FcjpZ2/3xsJEq6CzBCyjl991d1m" ..
	"yumnaD9BrnV8uTmbLZ59rw4t0hmbb5BieUcOEyeHbZ0Vq09CgdeMTwsmB3Y5ACsl8AjlLn8gJvdR3ijwFUDRGQCzO0x7izrbvFs+" ..
	"Ei6cK2aOIIXoqXnw6g8zQT6kR2vZmo01du7pD8Qz8gBmIK0qnB61AUMVxpsSPMpxo7MUrmTmnMRX/85j5/b8a5PJC0id6sdlZ4b0" ..
	"a1xPJQ7U3+KsvkAwkZVdwpDSy3wb3VfLSmxkXrgpNP4W+5grVmW2kSym5cmDkIB3GvAUgEr7P2QCQ8EE0Ze4kxXytQNRVBDMs6Mq" ..
	"2MHuKNofS2Y7Gehb0+633ZifXJ298V2v4Yv6GGciB07w64YicNkRLeg8+qjE8kw0sV53faSEa6plilvNb9rEh+HAqyfMwUncoiTb" ..
	"wF6K7a5OXlv7XoGqpFTAFsTTG1Fws6HS0huFtpWCetAyPyaOOiMn66MBthQgdTQ/AsUF2M0uEQaCZMsro+C2vuxrB1jDWuE0gvGe" ..
	"cviqm9eqEmDgFnMQtsoMK0VMf+dQajYkURoQu+Se9b+GTMJCgRgFrQokQsESMLGqHWxz9IxIraLan21twkDMG8inZDpNOffjttuL" ..
	"WJYFXaoU9goJQE4yvNMnFoRFzNYAkEjhF/s399+JT8z6RnIMeJGNhupB3FgzchmiyzblQLZnYuOvpmvsfawMDfwXDw6ehvmS3Qg4" ..
	"HT8EC+9M6wxhdKwbRZC8s+a9JX2w2ubwvjc868w71dYxDSkv7eeR5m0W6pUuVI3fBAV2iX2qGbFam9Luf1rxN8KWc0l4z7HyhIaw" ..
	"r0KweuU7xluXLgJfcGIirkxScjOWMpB7GIVKn4nmmspklQZz/vqqcjSdKNIW4dug0JJ3cI3TAQUr+VZSYwZ8dr811S10qv4EIw7j" ..
	"MtEj54BsW/ckVW/YjiLNtxDxWGm+8Yug7/G2Hk1HzBfSD2dErIZXzRw2tjp40dfx4buBsX5CNIX4ru4lp9g+OjddfVYjk8CLpYzd" ..
	"4cXGRKvez8/sxNiPxmHZxz9uZFNPFdKOS2JQW6hknHKA58sJedkrruTnskdOMxrvj3VKMurPqBuMBTO0dnk9IfsabcNJE4U2p2xF" ..
	"OreVxtjssrxNfdgqcCU5kz+9KXVb9UBJy9MGzLOUFj8puadk3oJpc+mmaExHPT+c0CjXtZrDowvf8tdCnB2oUA0++W2KlDHmte45" ..
	"4UDbmSOlDbEZyxgFHlvXV87IERDqEQGe837A+AeCbfaKr65lJTed6HAX0nFPlSiLMck7P0herP1I8Xb40U4h/kC3WPXR8u5fKXqN" ..
	"E7w3pn2BqTtx0axuo2Gkh4QjEDFypIzVePU7X/1g8izhNmw91L8lqY3H4mMDfCL6VxhjYmeiTEwGJ0gmL/Y2HjwmD0vQ/gp4csZc" ..
	"njoSkAR4LWghuoseS3pLqpyJqO+nIniCgwfiCS/wUIDLdMrW0tKX7WDRWlv9ZpW3CQ5xLbmk+OO2rtbKAxFhCJzSvm5TSw3nVCGw" ..
	"AwWDTVlBGbYJaxH1lN+d027Tj5IHNaefMfmZLZcSpgXsoxKUU9WJJ7tHcYR7zUC0B9AQs9kZtjHMdIOPaY3CeTahI9NK8Q3FQCao" ..
	"Is15CmTBfmgMdIs4MlLrhNWsXGpbrIoupLe0+oJx8J5kE2wdiQQnIcAeBSuUyInFcE+mFG2112JpMTRWall5sj4FiGnCD+2tlHXl" ..
	"uUxavEZULlb6CHK4ekev26AWzqI5x0OstolAeI7wMV8DuwrSHyOyuR0ZDx8NnHQKH+EJR2w+J9i9jFUx3SHLPjxsKm5MmBiQeBAo" ..
	"FcTbA2bmr+kNFC6/2PcRV7LzG93+emI/JvJGEauOCA176jyiiJB35SFqh0PmV6U7JWuG+4B5nStK4f+TLsTxlhuW2fZzx9zoD6Ds" ..
	"aVfd6IQsGd3jq/gw+rPVWdhjOH3EZy3vtVrlPXg3CXXrOdUQv9zU/GlQxpia5M0jOu4r1wtSuYy/nB7A9cxr4Z4gCuQrOFfuMI97" ..
	"7ZCEsmBl995fVkZqMES7gZHh1ZiEn0Af9NtBNDWt/wrXM28Qoat/2jTiNSe+0xaapQM8tsqZAK8ZPbIwHCxkzBRVgcvXrXe7EgT7" ..
	"4wkR1Y4r/hOsLJQ4TJ5w/z6mg8732bvBFIcqfO65LN9OmLHbsqw2w/HRKk2b8DnIXJN+ihoYHXnnjStKK7HaDyRid6PyNhAfUuXn" ..
	"KuHAMmI5oeLx5+OeTV5ccKqtsZbkNxPRJILRW9mwC+sQwTGo22vsm+p/tC+lEaVfUPF3Lssxf2euh8e0Lyd2nXtZzp8+mfaIU638" ..
	"wQWBr/SxoiCKZ0hZ9L9GmPnBwl63HsU9z5bFFPq3XmBg/FHpUTqy7cIowG3Bf8Kr6jEOXMr05/AJZBJ7+Pt7QptoKyVVT0i3VRB0" ..
	"MTP9H08KNXRKhkisoTFcKcNZgUYTLInZ+r7J/VJVuhpO2rAGiM6/tavRjF+XZCOj0dYW7HA+CNcq3pRJiNL0GVlglpxMjVEbToHR" ..
	"9DFkzkVauauWhWaCmOtvrfOhGvK2dUhyMSrIJGTDpM4QUQQQ+Dg6u5A+cASaa/53b3dYcc8HO6K3vXHNnMs5GGYJ2AoQo0X89vfv" ..
	"KNSwGdPO1ztNjOaATdC4zJcphgt0wA29D/SrbLDrbsJRA03JdtOCvljzLoNhFBMl4GqCpNSZPxxYe3VKBlF3Gzov+6jea6bbPCIV" ..
	"H0Bs/HcLa4mWyMU0zjTvD1hLcBNgLfzrgGrpzsKgYDBf4M8HKProVlrq1MC+wDYGDpXP30poWX4kqLkRszPZnq87eyeRii0VU/c/" ..
	"MVkqsfKcBEOajoTNlzzBzcCJkepdixJt1BYuzr92O8aefmP2A9icpr1ztoZLmZ2eDzxER/CQuklUzqqb9aLzGmcsvkbtrLMvKSc6" ..
	"tKFp7lwi/GloZJ+OyB3MKgJ7PX2JQCl4naASvOu2xSdLgF4tvIQvTsiE9n++fZLc4Arocs4Fb3t+85PsIR8ZaulS3DFa9Q1epJ5b" ..
	"d/jWfad0Z34mb8GShaPqnIldEfrYMquAWjAKZJ906qQOy7JlQVxPIWxlVrUWaZJKMsbEEn+zYzLmGDgdiWfsJQGrf1Dv6mWj+R+2" ..
	"NmSXovt5lXhswA0KiSGkKjua3AlPBs1RiNSIcBGASFGHc8SMjuy3TmDv1NnQqvsOf3Twh8qTEDDCtW3X3gGII1jh0PNmz2shrOp9" ..
	"6lnscPZuvO8+3+Yh2EOodmMCUeYgOej7/YCmsL1m0h34GBe/38nGlefMl+TCVdC8T+8rW9Tempwjr7T0qZYm82hV7hwxOsD1YI4Q" ..
	"CTyzq3Z3SviL04DnGxZhLEFHT006mlTL485CxldoXI9mh5Xd4T/FkSsJtvIgY54rQUyGUl7W8AtJ/8y1eN3SAOTmdVJ/hMY2GIsz" ..
	"JN84gKy0TGPl7bVpzG48sQBubaY3kPeox/Iniq2HzKVUftHRLEfWMv892pE90Q6dffEiFOSgZSdJ+aNk5SwwtIpUK315PTb1uZpJ" ..
	"Qgxte6IjNGMlwjLVz0o97GcQvwunCn5sMilDLpbP8TR4zTJ6Hx7JrV04u/Lo3UZ5GL0Xai48cv5jnI1cwNrnNVuTz5ZXNKLCb+Lr" ..
	"nLrDIs+oDxFXrFSfmeCU+4qMmQG8S7gu6h+fm73tBUGVSCCi7eJY/5lV4ulXtTEB3z9SxtJLNF6GjwS3G1JGwLGo+17xwyJr3AZy" ..
	"wjHAlwB0vuqa1Uhi14fy6H8ElMjQl+b6yJkYiDLToL2Yvu6eN7OehfdMxh+PupeyHJyaaHJKKF5U946i3lne70rG8HgYVCwmvzhV" ..
	"fsTfyzbsXv3QocG+VRn4giWEZlAK6Km9/TURsMQH1wfaJtuknja3HbuI3qgbEHRT1btLlOmN19JbI57Yacyx8KVmcL0rZRTajEm9" ..
	"dcJyHYuLKyG7GK6rUnnPZ/DUzUYjZeftV4j9v4RwHJKoighRDZxfEvqpE6cqGRE2D3CknW/S+hy8c8OQknZQx7612/bTZSgXx2va" ..
	"opwXLbxTb+FLGDTElL5c9Qa7ii6W/6mlUACipx1clu5wkjOvTdueBM1Jx1NIO+z4FoYnYHvTw7RgD86Fn8G5g7+lla9BxCjmxeMh" ..
	"3UVUi22Tbzhia7xIvZIY5r8J7NL1CiUfpuss11J2oWviddSPTYcFsXn/rQiqGGxkIyG5319dLqZyvkNxkvWsqkIT8MHuGYi1FE3d" ..
	"0r22I6I3DYOskVxIB4hhzqRMiUCcxXcHpyil84ubfXJRtJb5h5BlNPEz1xJWvV83CpS6U6EW805PchLQGStVCPOZtMyXoBSMKGoA" ..
	"6CN1mJQFeUiWkWTenr9JtOicLkp/unhv0evJBHYcXHKk/qF5s2VbNTYDwdGwRdntjeZyGBHvugfOLDzN33/vmJwlf6CGYcFDwOuL" ..
	"Un1Oq5hXXWJ1X/Gj8scuLHBreu3oR1AGBxZQ4dhlxm49w920OIDZ5TzZ/VpmvLVU3R5E8ICo/WiAmEbNizqBIXAqUg2IlgXF1bAA" ..
	"Mspr+DZDRrmaka/afv3UGr/2nBknZTj53/mQafjDdTZ9tvNvfkE03TbpN3wyciAoT3tt0vQmkdVG63QXc4tmHeC3wxkL7u/lStac" ..
	"MqjpDDm5xur/m3TJHItbJR5TeqHQ4z9duFnXO7QYeX2b0SplY2ikQa99lPME225hyOoS/UByCagxNb8eZX4o5RwXMkd7UvWEDQRu" ..
	"fnepDxRwwinW3202AqGqR70CTnmPY52j5Axdw5v9fLYphFsxu2LFCaqu9Fl7ZN+BI+Np72MH8NafFHZs+y4Vqec5Dio9rPbwv4lc" ..
	"SLjwvMQsbtwj4fmOqZK0AwkLfrrkHNcErvG4HAvSdAhEO/xBvg+PcdAxgKDJcQRuSG7vDVZohDuDfw7xqf7rExahLhPFjE5M1xch" ..
	"cXvL9Om6FXrw2x3klwSpa8F8alGcGEFv6QyO+aVtoLO2Y/HpMkKonu8JRugYF8zqxHxOi5Qo3Du9Z8lpdSvVM29b5Gfs3Kv+Fz5i" ..
	"dyA/j8Bt/PhYN09GJ273u/a35AJr/+xDGpdo+aGVTAUZWTCv/J/mmOOQpiwt1wXxUo7S2PKdWQOKnvwBHifR6QaCto8nI+EiOSVf" ..
	"e0Q3xK1vQ/zI20v49ip5W57UpkDtfB384Qzcze1OVJcCOnlQNIZWS1nT2W+08jfS77dTbBSQgdKCBIX8jT34zBihhrM7oN1RI2PS" ..
	"nus8VZZ4BDXlingXGvrl6cpt6RtURNgvd3yLWxUl5gvVwPLGJvIZEkOME9f1TutG5NHJ4PKcNdOEdqeOWZQn1xNUGM2OA/C6DIoC" ..
	"Od+mWcMG1KUWg6xX8V17b0jbqPz8iuIQBLEUVQA+ohS5I0bU+2vDMeiNH5fVcfXqsIDd47CtskGM7Et5/9cewkqGBLjfjuQ83kaF" ..
	"1AyewJVjQvBzPDU6Ex3DADXKlj9zdWJXd/NSn/nlF00ROnO35kIQGwl6CS2TARq0rLhz+wXVBhGEbNX7DC066RBgaslujzCvkz7R" ..
	"6/C1IC1WsrhzpAdP2iTjQ2Scyqbt60X8eObUNgBixUHNGgD+7xSZSsS8+VAClOTSUcqzu3k4N0ibhA1kz0GrCBZk+dX4Ty9/mUR2" ..
	"PxC0Fx65XCUs6Bvbt/wBg4Q8BCEPxtwHwdL2yh2DVb7LGPHxwxuxU+wHeFK+W40SwZJRpEF4WujmBnH3btzmEtlSNrg3St7fG7gs" ..
	"D4x9tbqSsxDM3mpTXxSDPHkmMtW0acNtpiJHnJ2uiOHFARdvhaRZPglqmEDb/9OID5lsVq0cGHLry1otdXa/mZzPQuFpKfWWu6yM" ..
	""
local PAYLOAD_P4 =
	"A7a6RRqxhxitdc/qIo60e2Qe6pkuPeFVl94opLf0UsgtyaeJ4rkgf9yBBZSrb90kI9TeIwi9dG/FoioqX5QONPCa/ay8x3ilnwLW" ..
	"5R/GYGx2Gk/IMVxqVx3igh25hEEQX0YYuK2+BJv3/7+8YKr8qjobK+v5eiUlt+dmd+TfhW+onEJOY4dfrOFmxt07JwQ/JXDwys5i" ..
	"akIrgI0WQqojqWMQbAxtU9OmMPWJNgVL1NhJhcsMIWcZH2/LGi8NNzh+cg633uYx4lfk/1AB89quSSPwE+iemZJwA18IhQaIpT/M" ..
	"XMfx42LeXQ0FOvBc8jSVzynhXpwr0xIEvJTI1YwFP/vW9HXWjzGpdHq34T+UWTr3jL20MU6uhpgDJUQ/4Ld+Bbzs+yN1YlvPRhAf" ..
	"CmN0xKIGlQa5UrvklfWZ2Qhwtth7ziubiK50FkDC5f9qjnuOMha9Ysxhk6uchBGU1GaH5w1CGMXzZKg79keWAHZz/+6GUcx3dNjG" ..
	"uGObhNYqvqhN5bBYZLvBv+QE1zryfAO9XPNKocHKUVfXpGuTPlkuI8bwZ116gLLiedXJ8PITGcVBqSv14t7ri5gpe3v/xcVXEGyF" ..
	"ZD+8tOLGmktoDLe4aj3fS+9Vcw1ETI51xWo3zW23HBkT70vZP+v3K02s1yPg2CpMt+hK54ibLz7jlUqZyBH+Agpok6Ru69HGLot0" ..
	"4WRpXaYB3giTk4XOOmd+A7UB6+58nwuGVYu7gj5EwztWhEtu4vZnhYIDYht/CypZBB1WmRtyfdiiqgefrDM0gsyisk3u8iOz708k" ..
	"KBaxNo9uAtD2a3cUb3YvYsr8WX1VVtW9vQ4TTy3wZOPO9Shia+hmG+3FaFx+TYk21v1l22834DHqtm42KEzs6cpNgmRWFnxtudVD" ..
	"l8A+LxotSRkpo7jc49Qy211DbB6gD9/y32VdUWY6ERFtikQLttrB3Q4WKnwQwao5WD9G4n/UatC8ngQw41tHBDsOscH5XoocLdk4" ..
	"D/dmsvt7uAlrMYG2ZwcR8d7XUmELU9hwJoCdIcc9nCSXlQPFQyRQ7fxOpKFKmBK3Olx6qWvpS2oCAJ4L+fzi9y0PSDU/qaGmK/Rj" ..
	"DbeNqACMIL+JMKyltS633I/YeumjDUTlGfammo/FnojZ/n+sVCrXRsjAji8e59gtO96xDZDymdI+Cps8qSYA/lMTAWwR0sqUsJHg" ..
	"8m8v9pKdFirRozX446JOYPzrl023PIiqgrxvOCSIrnm6A4qZqK+MsDR/86e1wUz/XhNnVqQ0Ui4wzSWEUCss/woqq91VHSxjKHMs" ..
	"ebttIMh/0VIAwGjit+oTIWZxfI3L6tX67PotbTh2moPnRdJUTGc/2qsBOfF5vDV3n2HcXgHTdR5DG6r12Tjf0UVYEZbVRY3mh4tw" ..
	"PIQ8h8yg58yI766K/ci1XLTLDdQE5VByv0PIuN+cIdqWYoDeOlMMtG3Ib/u8+no+aKERch8+UmahrVkVVImwu+nyM0AzebNsBoaE" ..
	"Xp2YB8m6ZnDFdvgYK1e+xfoT0UMwLjmkicv89Rxe1mXJuSbPZkYIsRK3bGhbPrw4sly+rnjKcdfAg9PpID2gNRotdC1hKWKV6s85" ..
	"nc3TVKHoW19jNlU4w7UzkRg+YT3+O487HO12lI61kKmrKN7zEQWrtPvDVYkBZvMlRpriP1Tu7wrgmnD09qorkIE8SYu7vPqxTA1s" ..
	"0SCrBAxvmptcvBvopIOXfZ+JLMMXkiEKWo/fRqONjeKaKHnm5eHYEbIzJfLVBBBCrRQ4aMLY1ebs4I3gtVQUBuCHSQSBQOkzUQfe" ..
	"TSdTg20zs4RQ4iF+jVENDA57RKhBh0wPEZV0C7q6i5KFxNwUIINB2iv+UiZ3yiaQXxI3VbYkBNdnq31FyVcToRI67K+dA906K6YK" ..
	"5PgLB5m4XfJwP0UD+fl2e/CF0p8KT2o1xkcaH4scnaKwanWuyenOhfv0t+7lC0Et8kDXVHkLlsq29fDQO67gKEESf0X2m9xrAGDx" ..
	"YvmIGZdG1kIeKgu2klsOlabAaFavmjHwmENFTyUWs5Pi56tTMU6uph8Q6rTYdV+NBXB/m5P5Sx0StJrlD9rXCIa7WY/jr6dmISZu" ..
	"Tu2rIhMnEJyfso75hiZJXuh+4Jwgt+2faD4CMtNaJOlyhiI0t+JgtAGwCHxbqLtS0daGK8JThP2TqTd2LhsYbtlWm6PqmUtD/2X8" ..
	"HUVmNfGw/zzT5kjToV4NOC9aCr09qgQD97fPnSYBiWVpb0kTghLz8C/S4y6hmQER593kw1gxOiVn3FGieoWCh5T3lFNiVCXDGskv" ..
	"TwsI1OQhFZ7jdCqz5mCrE3Mt5YA1Yc7ETo+Q0izL6tP9lqq32CwYRw6dGHLTNEJXtqmoz+9K55aUAnFL9D8vg0dnhcNHRxI/hPYZ" ..
	"P+cvwWBMpZTdrtUTN0YgYR6svPtN8KmvvQFQwzYXwLmQZ5fhwffizjIHH302lY7M2EcNLZUGwTJ9WhooekG6z1ZqEqZMDoTlYeYd" ..
	"uExOjmYA5iQcOCJIMtyjXKdeSPIrzVWAiHVYdWQmDkjKuU4HgzUrRTB56ILGMwHP+KVHl0unt++i0AQZqtI/3Y6FgChnECwyL/8G" ..
	"slyC+N4n9dLhhiHU4epJaIarcL7AfFCnpBagubs/V3QYVj2O9nfcjSBuiNaME1T50FNki5UyhfEpWMFNrDc5tnHZE4yZSwK3XnzJ" ..
	"o2iqB29SrWToETHW/ajJIATy08ARXu6loE8z8zJ7tO8CrdV6T3y8UgP0/T0ffLJswOPiHsnaaxsVSxhQ/PtsEeUT/auLH6m9LjJ+" ..
	"1gPv3QU+HRLDNMsgO3bt3N+ylxzs6ZktVoLdvuNFEm23zpJDmJxgm22fuEceIWRj6hm2/3QsqiViaoFxqBTqH3GBZr/uAdCh8a78" ..
	"0zPg03QzA1HhBngUoFg1lw+eeqEsDhwtsYiEkG6V8lE+C0Yo8EpHUGBVZpH4hLDC3t6Dkwa4GezX4xXzbRSBKBWEF2prKZ0w5V0y" ..
	"SReUsdEZ18L1D/Xr+4dUTpR33g8e+ERJNYigSIVM5hCgZ2ghWIi61OjjPbuo4cTm7XTid+iMfj+QTpuqh/0J/mTTTjiGqIKfkkta" ..
	"c13h0PeyhEM+m25mAgGW9dA0a4bD08P2dhLm1rvSlMAZOvqcuGgi3yCVuz5yqwW+5mgg1OhPizvslueTNXeX6lHwwqObMwZYTDRe" ..
	"s/pRkYWnk7LjUCg7ErE4SNpeClBLrYv0p1xOUYuTGwqt16X4GlhY44gIAIMTBfaYnlfMqu4Qjr5gqEdcT4+GEBxxGPjC83chQqew" ..
	"/83/sOqqP1c1mJdJ/gYpsReLsAbT+Nyda9EiDsT2SYSAwjCxl+cWA1BqvsHvlCqD7cFwmD176rnHcET7Es6aICUBRDS2Gsq+1iHY" ..
	"S2HCBcE/P7i5VJGZtTJ26dagPvxOuo3BUG4BA5lhh+B32KDpa3AfoO0sK7C67lEBnJSPchnRRz4JjLc/Kzr+S82ALptwhXt2X/rb" ..
	"dupmoctJgKvNepKlsPA6zkzpUnmBW46Xk/mqHvYQ4ow9eTjGqewOuMFyc31Otqy72b6bOkrmr9tLDRyA21kbfssyJhkwZ0buwuG8" ..
	"uTbEcs1DmkDHqFKfGfjEEeIkr6X5RwcihhMuklR0H1zpUTIs0Yp8NOMETpOaTrW9wrgDJbzie7ywf1AGER/EDHYwqgQANwzkaXe2" ..
	"E7kBPuahxUFR/WVT1vBgcDX0MEmEjNvuvYvSpyiedISDFsUJlILT9+VC3+XEeBEbOfu923T1Y8ZEP/o4/xRWDBr6mc4mMxrthEaL" ..
	"b9E+bq9f9dT5aJXGpdDHj8zGrZZ7KLMbGVuRmOajAOZHdNU4KNhG7IZueCdjlEHuQ8FN5Xe9PtM7WsnLbMshC1bYWeltf2BqL8OS" ..
	"HfnEuXG/uPVaD+A56QCH43mXm4WOypN31QxW2kfO3bo6jVQaHkeuyq5Q8vI+a8RIUYMUxLGQHvTVHpl6RpFgDlZbouSQsFxQVlsY" ..
	"98cGXDYW2UIiIuLfkoyeUUYKw8VVCCR54Es2pT/WU1OkDVWr/kQu0od2o9SoFgnRVcSmbQIK1RjWgwSfZOF4poBjKU8ONNjdA4kQ" ..
	"xlQZk2dv7QdqN7dfKzhWHojNqxXrvnKztx7PpG5Kv064AhpCfZinihZWI79NPPNSd1m3I4I18btnoxCU+7pBz+quBY2/RJvViutJ" ..
	"c3h0foI3oB8x78VcUHIq7RjLsseUs8Z0UNSqoUIvGEjVnKjfd0kb06fn4NaWCc/PoKnSEGIfUd/e/RdNKJc6CkZjKfEMUWZQHvLS" ..
	"26+mfIcdFQqO1wjpL6tFPazs6IRVdbv9q4bPoDPlz9n0hGmxbha83oL7ho/xMITB/n2dMlpG353JeYb19muMKeaUp4f9HrB3ZUto" ..
	"5YGolCmo4EeSa6Uo6qPt4Lmho9/IKHSQdfmLOgNX064ulL91J9i5GifsBH1HC0wZt6lmI0yWtVZlgHePArzbbTJlmnLi9SbQ0V3g" ..
	"XXhMTvzSfkN3j4d0aJzKW4Op5b5fljScpIogRu6COwk0mcVB0i8/ESFphBEk8QROjlRWTm3n8+4dDZ+M5gySKKeWl5Ya5HrN38j0" ..
	"GygRBiCZAQYS9BXwQOQy4o2TJalU+FfLrfKqWs+gPCesEF6NS/9l9V6JY8hIPZoWIm+KsV4Osw0gSyFXDYfaWp07pyKml3Nw5kqT" ..
	"BDL8KZjwUQSLTjOEzOheHJ07w0SJ6/ZSuInJWdrBPwF4vPx1+/4pDw4wx6Cc0Fq07ng3erRmkTQ1yed4qeAR1dnYp+Ur7W/WGMEu" ..
	"Z2l24vYXWNZtLv7Sp7rMRk+Tp5x7ENNb2h0YD7p+58Ubn3tCLDTu6qWZ6VMnoJic8SIjNGb9jeS6CgYbIv5/Xxr6Dm1ySIDoaRYZ" ..
	"ogVLGGiwvtmapUZW5nSHQ1MUPJCOHi6zZFvjMWRe0irJBpDJ/1gWDgAZOP6Bh339kr5q7SwB+FJzaO8peYl2wdWxGlpNGos7iF0b" ..
	"ETMDC0QLgvgEbWnbXgEc9qPwY2VyCpmsziowqmgMFFOiHvB6s3Xu8mEjy5hcJ7jWFTA+L8f0+vqA7CrgzGzzBWlhIY7ikTqwO2B5" ..
	"3bYU3gVxImzAY1sHFZuyP254XOOLPCdU+DgO4/dSCfUcrr/0nGfvVGS5+6CK4LfKrDCx7fBaAIk0o5llil02QmPhOl2CJKXTJq4M" ..
	"CbOC/LhxmnYMvkpaL0nFIquQ92Fxf0cMZKLkIs4L7z3Dp8xHvuXKT+XtabcRDa7eiqleQ3kCTbFwYy4IpatSSN+qLpYS0y1qeolo" ..
	"i/TJC2IZCWR0lA9w4TudO3+the3cuSLP8/nZcLVX74FZwm4SfpOO8R2uGuqrrgRVpmdAkmnuHQWBL9KhwH81hj/cb2cgrWJC65oI" ..
	"C2xT480Q7k6HFQWJmZPW69v8sOp22WCpzfIoLk145d/cyI32IH/cpPWmEQ3Rqodv05eSpVqRERBGbf4DmcUnF1sRW0wZ3TVfA+Fd" ..
	"G/TX4XF87lXPOSHwe4br9BvvcSCochyHyaHrY1ZzErualE7hD76vfxtapKwICIqXlVE0E5z3QTSg63foE0Y9xklNEhFGbPju2fFh" ..
	"OL1gv46BSwAfwxN0Be1yvRjli0aWnnXVSMAhec/oXrZOrhvEWjONRpBHO3/mmXnvRA6kTkbCjJb7hqppxQ81ez3UAbVTgdogeN87" ..
	"pUegL3Q5GUsV3xKOl8Xx041/qwhcQiqaLMTNUbDjkuZTE5Oa69m7zURG0ybb3vV4ZR0TrqcaNApddeWmTpdIVltQldVQ0+1jDJVt" ..
	"0TgAzaXomkELVBuEy/nNTauZbvMQ980VFhfVfUv6/xgOJi/1p2QC29/iO5itfMf92SXJd1yqBqPk/1ZrSnrmPeqplOA78SS8DWcr" ..
	"Om8xF0ueqOG4BTZqpSHNWlpFIkydJPfqSycINa3pRw/Xljspc+pfpUqrP2FLJO6Tpq8We+ZyscabHmHLRaoHkVUI6VrbBbzBbgmx" ..
	""
local PAYLOAD_P5 =
	"AbwRetjfWNtkp5HrxsmtOSxYaRcPygZI2EjjFWvuPX6ZNDt9ipdWgZsUhDzAS6zFKBbrJO2miREMth24XXwMBgiTJr0rmhze+AGj" ..
	"jB6xDESwoGhTeCPHzSjaPp9IEIfGDt1MLLLiPUXIf0P0wZRQCsGkaAFiFa7n8kDworaeAmY/L2jjo9eNlGiXvyGltZpz91Sp4K1J" ..
	"bBjLuugdxrOTm0B/iuvd5M3T8CyfwmZS0MCD4nvibXZKcmUPxXQqSmDewDLeKEx7JitG22S0bH7/M/VA2mO0SlYAgW2gaZqzA9m2" ..
	"g2e4igyIexYWyrFBDxVrpzT7I8IIlfPwrQU/RTTpfCo1/F6iIv18pArkC3+xkCcUKiz/YMcmcsMXjCN7AmcDNOV5DhsPGXe8Cu3p" ..
	"usV0ipPXUliH9c9JPDvgZgWnryHrwOE36eeF1t1/I+2ZDj7+JYn/jFi2/g33EYCYM6VG3czxVQOOn+erMK1KL+qrHBllT+de6nY/" ..
	"JzbZCA98LMvz53yaOgXMQ9n82brRiKF3/NZdLsU984CNnazCOqoa/HiM/WhqYmm97jTV4Ap8nCNflHSETX9y8OsuYjSkQtKYhR15" ..
	"2VPeDtDDexlIoMkeSEk7w6wbYar5+q+kOqm0ImKPYxsxsPye5ZR0iv7izkkSHACaAFevMv7U4x01m3ZjxhVXPQqlJQMalRV9porM" ..
	"bddczUkqBRMJFfjZSeYxG959U97cTbpIvFglVGdmXMQqbb1Ny8kQLsO2mryPl7KZXXPV2N0SHDcrJNOP/aIjKgmN8+lRmtMzQPL+" ..
	"/w81ZMLnZatpI+ffsajRTosBUA9SwuUjeXjy4jkHa/fWgW7nuMJjSpuzg+AbVoDp6BuoDALd3vyNVmOCZFsavYmkWqBLzyUDUclr" ..
	"IZzZCix29ZZWoD17gZSqqZZ/k8ot/pX2UbRY3VQJ71loYBN43Qym2GCoZdAufkQo91lyOoCm8wmEhEw7H7RZRBCyxqD/udVB8tcI" ..
	"SqvHy/EikDDYHCuJeHY/jrQB9HQNA3aJx3rrvweUmInta9FwUBJvB8VRJWHK34A1VZkqEFWNKq5SZ2gBUkN8/RaF5H+jN9ZQZ+zL" ..
	"WxkGoX5KXc5glZRNJldFSLKVmD0hdC5SxntzQ5Mp+DqflzgROBi0CVn8GzpPh16oFBZISPF8n36LogkD3RgtNwaB+HM0a9kJqRR/" ..
	"ClsljslWSeLPucmRKY9esYwxBbKnmp4Qts9PxeCgM+KNEoMUVAgA+3wD6YnxKBcrn5ERiF9ZOdfbkO5ITeLMdsxaIGzUV9+Ho6iI" ..
	"n9iinshkL6MQav5MmMdTpNSXrvs/q6gjY+Gya+iMaXh1ygovdzTWQhXma5Nw49AMH6Km3lPPKh2oD5Jps0sI661jBoiG1RrgfddD" ..
	"RaHBysdNzo3/oOA7QeXVCkE2S3Nyzy54TqEaJKT6ats4F766p06Hmse8sy3NPlmT6vwwn/8O7T7d454haquEBwD4++pYCfthGxqt" ..
	"L9Ow3/aViS6iBauWrvhjJnFtZNiKERiMTn2oySmdiHnANfUUhZaxOMPF3T+AhV/nW+qubV8jFz+kgkhtUQ9VI+QcOIf1diweaoTY" ..
	"AqQOwj17hjaYHmuLl5+CjMzddgPWgpU5/uG2PXZKQZpzXdf4lIls8jrzPyA2UuYKY4375Or/UlCOvR+JcQPZ3t69jNgRX+OueqJs" ..
	"Srv3oMNnLDQlP5avNTui6sc1zZLCH/+vmDQ+ovpmcI2aWbUqzOrnnYZi255C2ZSiPqsjdAh8mcEDJ0htsIPjG6VoTcywtATFLrcA" ..
	"rlfMZkDp7kVKrRVSFqeVZ7up6DehPeMiuLJ204aWzxnndMzxQkHF5tuZjR3CUyLbmk8N8eZGv+FkripLqJg+UZRHbP467TKT//Qy" ..
	"BtG9lfzY5PTAuFFZVdPPrQq31GuO0NZpwNcoNHAMpF6bKSs3jZakSpQcaIoTm53qdlACA0Z9o5kH1RaxsCPt6/3kktZpwUNK5TJj" ..
	"i1Uw9Kq0KZQgRdlfu5sPfrFmv1iUPzSZDX/ClcVWkazip6rIuE/eKR5CRXklDUpisxK7246S2vXzAvNw70LclHHSqpuXHGMQX3BE" ..
	"oXqWvdUBAN/uGz+CF5K7a8UL3xiJRcZNLOdEBqLx6Q9p8hRcosQtWzRb0SoGxb4ax30SzoLPsqUCflIMXIaSfRGoJAmFItpeBKmd" ..
	"uFXiwpXuwLcbA0/cENN/4SjpL/jlfXc1p3DxXw30hElCE+tSOi63SJ+AuuFafqS4WX5fAfo+A8PuRUV6rbPfu713NIkjPQ8hx8ib" ..
	"ReQYNkbWAbwrusiD/587tQ6t4m29wkEP0lzxKTBaoxMW7Fv62OkU8Rgagu44tIG+lLuJMb91n5Sy7hm7B940yKVoN7oAUBfnu3aV" ..
	"zJaO7fC9jxva4pBj+XKhU+W+IelXgeZSL30QyrD66v2RbZtXgG4h0emVSTafKk4oEc9KRrbK559i3Dl+ud+AFaZL9Pq8C4z27tZG" ..
	"pdmOzepC9+K0KTfMF48Ztji+jsQvZI87/2Mf6zG1DsVoHBz1L0F1j772qB8H+cFXoZyHvupDdTelXtAipkU4lVFJhR/Q2c8YoORg" ..
	"maaGzdW7u6vpgGXSXVjkfar0CGNuVhd+Dl+LJCWVie2qy6vktz88na1MfItPl4Wr4av193v81kbVml07pWu8B9IxUnltIj0QRelY" ..
	"dhJFo5AXQoTr/NrrcIAnOJD8kG1HdyIBVuC6tZmvvsWTHDQUq+KorOqmXN2eFzVSSYGu0YfcdyEifEAvJAjPiHCAQU05ZjkxGeeI" ..
	"tApy1Ma/bkoRQEgP46pDK3qYUOL5pArEra5ttc2BBEbWwpeLohP9JnrSG05B83548eGgyTQwiO3XpBpDhgVNiBSqaK0FqGBAy4Ns" ..
	"OfEtqcr1m/Q8N+FsyG/4DltNxZKzMemPpAM6j8RtBMux0ha55sdUzICdP2YfykiIRSz5vnJ3fc2zYGRWR8ZBU9avjJUjQ+PjrgvI" ..
	"G1Pq6AV/1sW1rlu2Dh/CIUZhokOmSmJJiRjaQN10b1SuEMk7zwuVCeEX5G3ZR74jytJHiFEHjcK7NR2XdVpRT7ZbmlCNWBV7c0GG" ..
	"6ksz2DLpXt1gqu2EhuW4pV5buTspKasQW/mWX7NeMP7ljXj72MOWBD0oiT+0QQP/CHWBCF+t1i4eX5L4RFdA6B9x6NayvDE8USON" ..
	"1Msnze0askatI/NVpbpUQB4Ui/QuSUIYaBSbHl8dPnVHzZVaZAHcWnWorPx1vIAVVQ/5R97S39S16eBFSKhfzccobqy/GJVqFUBK" ..
	"OOfF6QtweTiLtXJgugSWobgE41DJEdDfwCd8ADyI1zxzDXCft4OiqXcMW1t0776g8BGtAPf1gYxt7bPOMcQpOPqrlKp4DXCIEnhW" ..
	"kDyn9SUCbkT829HZkM2L4Emf01JDGUbCO4c3VAEkEWdsmdkcgEN6e5w1D9LspyFoBl3QiTUo3Vc0f01nzuX4JRkOm/CJld3IXjIJ" ..
	"IjgqavlyyHLyS6iSjrhDGwb/z1K9rIwHVUHR7+vVuYj32QZGfSVTVfAccoA8Gib+AVAZ/k9i6jK4zuGL3bm8140hFlEPAqEHr9pr" ..
	"JEHTNKFbFmfc3Jfx2qcFYwCXgnbV3ItRcWS2NoWtY4f6iaq7Sx8d8H3vaRMixVEt7WLoUc5B74ksAqNsa3MkmlkT22dBJN2UpVlp" ..
	"hIY8LYZwl85OXOGPkBkSzE9kQ+p0gf77NSMpV0ah2q2svohwPnPK7d1+6NzGgQ2m/NcUbshPNDBnFGJ4wZ+zaM8EPNspZmsJQ33h" ..
	"90AEyvTuyBe2jbnqGpXD02qD8+P5lJ6aUhB3M4LyC6ANkwBsGJrVeL0UvH2HSp5+eJsNSN17JJ5xh+hAtIxmXka7CEtvtmvbcn5R" ..
	"c1sFGft35QusCFRd1NYsNCa0a0fb59eRG6XmcjEGtZRNkuTZErdlwVjnQq1em5Dllwv8emZ1+9u9FRcA+Lez1WyLS4zomt/HEvpP" ..
	"Tss/r5rLVqtzSXwyTBUnPrwc1yuKzn7qZKGW5ebvvDeOSg786bVlkALPJvnrXjdnR1aT+LnIA6mHFCVsroxeKmD8nDsUQb81yAk2" ..
	"V94qDeVM4EoG5Jw/tmCd+O4SkYDgrVhqyNNJmmTuCYACCFkGs7tXsBR5ASNrwiDUt8dm8W8rTV6lUxjy5C+Ia7QtwzcT7fh4/dxW" ..
	"B8CNlthTwK8EsMgvSA/PsgeiESvi9hTuQk7q77c5/PT2XdtYHXbb8SiI8pEleJOMsaw7REKZQwIfOvyFBH6bYr/XlbYHI7DGEfGQ" ..
	"Xy8j/4CQ40/4UvMKs8ATvH4lcPsYwrxrNZofl9uRxxUB5xsL3V/EOw0lmSHS0KTP7RlirARaP/XqjaRahW+HgLwTZIHIVpIKpnjK" ..
	"hHtfIDYupY0JKQp8ba7btDdDmFhEOGK3cKAiEdWOY0vE4Mxjef9bapTy9QB18eTaOA59YMyotP4iFmwJtsxDwgNQTeGf8Uo1S+c7" ..
	"UrgIxpuX7YL98TwZkyOgmD1rQoF7+4Td5byOY7nfUHJobKzJ4XN5mSyAznoMTFb9/JYrCjcFLUgcD3nRbcTuBPo82fBtGzTRl9WC" ..
	"FBB8ZjgIR3agFcBW9xRVN9oKKI5hCkbhaFswpZKVeUfPmA45plAKUCxaHuuzp/B1LKLFoDqjtYRFUGH/IchJ2ux8NbxT7Jet+BQy" ..
	"J/S4iGfUWb0RBfkqu+vFV3I2y4bsFvmVXuYMvoJeHnIYOa2N7hGAQ+i9ag8Li3ZsEcnhfibXOq2obL0Kqscw3yRlu/Uw94pseWSE" ..
	"AfNuZOOaUJWU1fF/JFNqprZII7/D9dO1Y52bUDuk3bYcDcJy/Bi8fCAgpPE2NvgtzDpZS+RX+orGhN6YFnc2mQwkL2RlDP7urU0p" ..
	"FXmFsfAPE/S9qpCnkWozzp1wT4fyn5LEDFlawIuSpnvWCIswgKV8LRywqMhzRsgUpXh/VgXKv7XOalxTFFYrEq491OLW+i6231bN" ..
	"w7My0eyu4PNpqzu0kdKBji0cbJ+DXKAOcfC3vV7/TTWJGGGImE+XYTqYeheJuN6GVIiIYCjT0IJgKk/cZ3VwRA4xLndv13Qv1YDf" ..
	"u0/DbQpSgu4e+9xGfE9lbjud0Zo1tEnzqwSQCp50qxj3hdl8eSKHzCK8u+xNe+gGxSthEbd3tAUh0OuIfDXbqtgoju35AZxF+mY5" ..
	"/rQ5Q8VVw6uNYkLqiQ5Xk3A4gM3cdSvbXenFrAQ8XBYNHPoH7UIJWubi+wBe8fbbxCuk4+X7bWrfOz1gPVMWq4CrQYryEBIRJA2u" ..
	"lIOHR6+qRzuzLz1HeCSJNqvd1WY794T5Xo/va8djM7r8i5nqJWVTJQQNJGhbXHfXg649Xfp3tDrSzj6OjibDfUzi0auMefln+fgv" ..
	"lPVV/7ZA/i+gNet4vMU+1pU64kBwuULMhuppXwSb2WjdTxNsYsb3vXMEYTNloIU/DV8Ya1xiUIbbDOdg5/D9geGilHnip0P26WmQ" ..
	"ZV/DZrdmvnvha7mfKhdesHxHN+oMBUBx21IwF6KUbAMmnz/GigBJ473PIWBNNDOxJi2CYsArHbksXzanHK+gaybBo+IVUmKy0uH1" ..
	"pysUzNYKQFYdFfYh5/fBKYMc06s3sDXfOniNtk98G/ZImRGejXrctdJ09WzEFLE2deTrxScXOqfP6hn24q6AIyPjsNmmCsum0nvt" ..
	"P50QdQrN5MU12mYVZZe+IPwEuH2mLE2djs/PyFRqau2Q0be+79SXvrst3NpcLxJICfALLDnc5Z9Iyq9JpUKcO07U7I0ECohbqTJj" ..
	"cC/2iNggQNsVj8uTxjqRGk7A6z2mO1dxI1rdN4eFkU/2dBs4pE73JnuBTj8go4JJZMbmiSD2OnpIF8rFRpPkWZZoDM/GqxKcZ5Fp" ..
	"4qCpEx0kCJAjOL2TMSIX+YCg2w/HElzGS61xGpy7F1G01G8nFmIEWZ+hg7hEnjRb+qOAMGL8wZbczrnRNPVilrcWo+oBQlY8d+mg" ..
	""
local PAYLOAD_P6 =
	"xd1ARUgRifpXuoHYj/JvOic=" ..
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

local preset = DQ_ENV.DQ_KEY
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
		-- dung FindFirstChild de destroy, khong phu thuoc vao upvalue sg
		local _pg = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
		local _g = _pg and _pg:FindFirstChild("DQFarmKey")
		if _g then _g:Destroy() end
		if sg then sg:Destroy() end
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
	print("[DQFarmLoader] Khong tao duoc GUI. Dat DQ_ENV.DQ_KEY roi run lai.")
end
