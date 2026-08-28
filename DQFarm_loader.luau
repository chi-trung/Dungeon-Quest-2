--[[ DQFarm Loader ]]
-- Licensed to: QKB-JQV-MPR-T7Y-2JA-VVM, AnhKhoa, Tien, TestKhach
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

getgenv().DQ_LOADER = true

local KEYS = {
	{ seed = 4259586058, exp = 0 },
	{ seed = 4260574061, exp = 0 },
	{ seed = 4260584989, exp = 0 },
	{ seed = 4261290856, exp = 1790468466 }
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

local PAYLOAD =
	"MGdD5CjMelDcgEHBBHH6YYqEQCI2iZyQcXezwSA4mhDINoky2nC8xaECB1otWNuj64oKdx7WDAyTAMPP/8suAHIR0+jt83ChsGnX" ..
	"LW+vl52QKA53mIRXBjVXCu1omZsxAG3CvwDXP7plbt7LNAufFtqKMTqvywkzbe30UZpo5MzNB69AvAs3vaWkiEFhALd5WGSh5OF5" ..
	"nE89wvV9ZLIfXhyVM5Cc4etrxjWm16wd6GUF3h3WnmjabGOGSg+LWT/SaNevwWZ2vofTK19hUaylSlq1AeId3g3o0+bV0ePXpLEf" ..
	"djhuC7NKlYryFlzaC+4YOqKoFpplNMnn7RQ1NYaWAGxToAmrgPYhZqlfXaH7HshyPP7bgXA95D9KxkB8YcU9csUIV9z3Y92FGV/2" ..
	"pjeJMgteResjpTxVynlAyORLZ6hbgRXyT24qjxofOODt5zmbSWzoEe2Qpn18t7RhzErWryFW88n2tbXfeEgBijXecChJBgsl4qyd" ..
	"6us2NFxiqme0loqA0d1NOF+/VnJPt0X3hTjgmsZadUohE6pYGPS+X2+2EZfokk72QItXQwths+H/JRjRBZ9ANrxCoL7/YdWT+QWR" ..
	"NT9MhMItVPXxxBdC6CDyxIhpd+zShEmidhtc6DQcbVllfyhJEgwDKQBcteqsDt98ur2V97nTKUzGJdaetzDqLDdtBQ7vaAhDmxfz" ..
	"K3R10RCJ+h8woyQeNeza/o3+5iagkopmvFyIM5CnuEx+ZafGLJfPmqaMTXXp2NlIhesd4K0pqVbZNHe94lDbEl/djbYxJMzj4bO9" ..
	"OT+AsJ/O5gcPT+QYRTMlMtpfvhqCskt1OKrLXiKTrVJZspjt+DVf4FH/gF+wkpK4tsmmdT15R0eV625Y2Gue/40Bm3Vc9gZoOy2u" ..
	"AN1gmot3uxdfSk19Bm0ZFUKOCzkyP0tSHaESNc+qYGAxrIIDN9I9fAdM40BS0GnzUspTnem/6siSEAxnufxzx4is9W65JeXk/7I1" ..
	"NtRlDxTqqV8wgD2W+hvaD4sx5+WI7Kv0NCQ4DLHH2WaHl9mAzpSvcLJX7VWv2OVVD+/nLtuhLiwiFiNH4e4szZHeuluov1OQ+MwF" ..
	"fY9rPVibZQK/zrmwH1H6E7gn7f1KlPXzvJWJqQbALCyUkrtedbEawXvCmI+gZBgkUbCNHHvPARLiA9fU7c0x74rmLxZnC61r1IgL" ..
	"r5qxqecxnnAGxMi0wLACu442vnh6dZuRNqXd7yohy/f/ctQq2f7hctTWVhGtqh/pTigRFmYnP4jVB4IcQ6q/Xn3q8GUVG0LjCM7+" ..
	"gu90f2+fpv/akQ5UDBnRJqziRJqniY1foC4EDMwSuzpP2aNKNXg8Bs1v63ugWvLW8kxqgMUvZfKn9T8jSFPL3mdfIWeeND+aB2+Z" ..
	"Z4PoEHnT4/ZDYwA8hDIOfuI8Bxv5ZxelE5WEvlHp8ko7ak37TaXR5+3Uo6L+dB2+qfWP7uBwKY+Mb+VXC+8bl/yw7Cagu5Bh0fcb" ..
	"s7nmwtFSq+fjInBbh4fi4eunOvsDShVNdM5mLhdtrhR535vsTLcbbEx3CfjOynKJnyyp3ekrBaL56IGsAj+feApaSHoXZWgAIsd0" ..
	"g+QYZa7gJa0Zxr4dZ7bSz/TgsrXVpuVJW0mMZ83VmDPQVioX3XRhiS3IAvFeQ7tEMFMJOdTCGQJ4w4WqzriyOrPlqMbg8JkeKXaY" ..
	"Ot9EP0W6kf3EkJN+Qr4iQxZ3u4d6tu48wjsqu/sBXRuHtmaIy0wF+TLqw1aiwGZZBvccoKaKUnmDAPHrFYckPDl5aNJmRQg6BYD8" ..
	"N7Tb80ONkJTvxtMmeq5MVJaB9Hb86F/jMhtOq0mBGBxDpevzhfW4tPCaKbPAXn5QTaFtvLppEU1MqrTLFF2o2boxcpyJDno043y0" ..
	"VXW1PDzJEWglDhhQtcbXus2yfzpwvQGP8ww0v5l10jI8x/mXJBoGBZRlw/PgQBzQzjFTH9ZIMohg4rEpVbRRozvgDDvU413I+XrZ" ..
	"O6BUkk4sniICcTIQCGDRBdlBQVfHIuIyC8zyrOLp8iDZOrrIYMrxL96RY9WDQNqyzSKET/VIN0itcZkG9ebgJuo3u2JQAR8C+y6n" ..
	"szdxdhiUyJql/85t+AkwYUk/zph/NUa83ZUHqCIoH4rUCtW4fZ9PC3eZHK6Fso1CvFMXIkr/Xlvalf1lOZyp73RCMvxLO6k8YOdX" ..
	"A2LFLI2sAKcmkew6vZ3m2luBL/TMSuMMlGWoUdUvG0ZfO7NZH5GGdKTEIjdZ50eulNqtJ+H6mBFZkuxpiZLAh99bolL4y2bP7fZm" ..
	"ncWiE9kruZCtGG/soWoRFt/yPYTIIc+PAWTsZZN12oPfY9OyKwvJsz5xpkOqvOw3U0lYjm7stKZ+9S4I5wafSvjC3IDHiPMZwc2l" ..
	"S4RRqvk7tHzpYz2/ACQVsqDHJFT0zfPR5lfrxh2Vs/26HlKY6G8UfPiBC0eyqm5RE+/lQDOSimT4J4KBdeEmo5OuYzcEpf1+Jjwh" ..
	"2acGM8NbCfiwMfoDYPaulBjpGwohcLWAApFBrICvjTEC6GLXX3dsOJ4nUq5RDCSx1OCzU4oBLBen81Ufp4KPyCn0zPv6RxoxqxP5" ..
	"WMu/xUVPoetIw86mcGRA6SI0E3eFtU9a9h0BFmTkHhO/IF2C4tCE29Ec31DqvXve+Kzn6sOykrwI9ygyEzGicUXVNUP1FZkNoWDL" ..
	"VPvG5t5QOHchgk5l5g4P8MRfb/1WKwqrwkQrvfzbyoqEVGraOZjZL3l0KJBGYVkt5URpCzVPaTQEacFxMO0ZxznneoQUiUJ3Xhzc" ..
	"ClAQMM+tYfB1ZSuY9Tt0hk07irgFHwHSUn5dsd8KVDOWOoKEcRYP/s2U+7F17uNlBDjy2LBRTn6//vu7TlEgK3vY09Z8xINOo5W9" ..
	"SGaJxXWJrdfnVCYJlnIWP/rrKK0cBpYI0981+1EUfxHTXA+tAMuGGPsgg7iNBEe0nYM2njr1uO+Fpkmie7L+4yMGCIfguxRhxCH6" ..
	"cAW6DetUZOTPO6ku3GPpCswhd0N3DYFoN38lqHYIMXnWFkMjvwJCNSqWvb+s5g8v3VG8hNBBr/38WffjZnExuaERdIoAmGNLDHsK" ..
	"7Vo3wKjwbE5DWn9zVi+1f1bPiFFn8Cl8hI42Z7tnlyPiWh2hjTC7bxEqO/5E7wQtS559KE6t+NHJtg0RTA8DfElJyFHuIHIJIxtc" ..
	"y9L5UQCYFsNtP2TqugQG8GbCyBVxTAqtcO/oUyrQ6N1XKzh70bnii8sWHIZjBt9zw6nNVFrYdHgeR3uE3K1es9IApJb/g46lf2aC" ..
	"Dlyi33Y2S1cSLfIAmXV6Q4JadsVrY/vkkeCKAlmC28nwJsyDRV/H64frVwEDUlI76ZTOSSYjzyf9xf131mbGkaAclidZHFrGNTpB" ..
	"7rlTbhNshQBs+2PhmIFGTPdUy26J3ac2VJWuvSCTfBEsYLhOtY/FvY61HK8yD5E7DacUmc6YnXFEU6pK4e5JN5rubsht3Bbv7kn9" ..
	"u/nvy9tE3JhH8oTy9BCUsFQuJXDT8nPZML9nvHLIZ5yeVOkHi9Mvf9rrkmZPPc0s/lsjyXg+Xc9XOwFe+LGMHg3a5zhYUIpJ0Nlt" ..
	"iMO/VVQRmws0wFwT4tz7mVn3lFpOPGJONVYpv5KPUkH2hyRxCNlPzJBGsE0f6cBCHuYH4HgJ/NEMvGSiAf53HhXdiqELRvasEOvT" ..
	"l44FCBO47/YOLw2ZyZA4IkmINMriGw4ARNc7UdgBIRaxCEvsqPpfRc/5w3gqQRPRC4IyV/ueFqIBqcY47t+zUG9HmiDbpTAxzr3F" ..
	"uzPr6Davfi8z1DTNhI3GdFBhcH87vF+ssI8HSsjTzXZq/TgdymyF67UYuJfbZLYKG6qQ3n6KR4VX11H5gc3elRkKevTxxDG1Ljo/" ..
	"8OT6E54xdmpQYQ50vd8P8buvq1y74T1NURaYay3D26RoeuHtQy+0ZqbMeTqHWYAp2E/9yVYTuv5eoxdl6smHLKpVKyeSx09H/wgN" ..
	"28Kt/yRGM0o2q448izkJJF2TJ3HKdE7OCWekL/E0CzsbxGNya+wnaiRXelqzVHTTTUBZnNo8UsVFxLXEgDW5lqVB1PqtNf9wt0Q9" ..
	"4Gz7km10U4ifQmOh2kXhgwrSseQRvYFwdeeRRrl5WMbeKNlX7hLVT+YIZ9U4LvGk0sAZ1CcoHCB7CFkc1WrUOgfRfoJj5D9SfcZn" ..
	"eUl7VX/CmYtG9Z/oS6p4MYQQCEfdxyKlKiIkSbfCMHtB5IMwRT5dqPl5UBTkYisvxVYAys6Ck3OnICvF6f5GX6j8ivsqdeiw6jdY" ..
	"UV/3gIGTAfK+4iAhF/epfThWt0bCpabgTbKdtNILM3WHxj+toaBHXUoD2cQOBuTQBhfojDffF9T7KFV7TM9IBzdFSoqtYX8cmf4J" ..
	"MNmCBXch/3/UGqCuqSKR8UpOHuJLc6wc99zY6cMxUZNqxtKaqeW+L8GmgJGEngIlK8/S77m6k7snELq0onAgTqLGjLEw9oFLiW0Y" ..
	"e7Qb1oeAPfe3qfBHJo9joiZZv4W8R952cSxQoGdBURPJdw6FKwTNQ4wEshvUgsChZvHknA3kxrV0yrtM+YdkexZnKZ5iFbw1jADk" ..
	"xrhWwEWt07/16r+LqC8sBwom443VzPWgFmZys7BQOFP7KqNmUkl9ycr+BmelW/y1Gdp9m/GTirmEj37d5hflvGlIdmVX5jTfEKP6" ..
	"UfBY3SqVVVHEaWiXpRlMpnrzv73k870SRGNDva8CfdEV06z2UcrkH9ozQ4ZJ0UK8HiFl/V7HXjwI5cdtcWPTqQcX/D1KiZtyl4UP" ..
	"yHeCeyGmqiwmduSqtvYsoK8CL2cYbaRmFKxoSscGuL/5Tz5IZ3gJw4iGaSMjF4jyjGRfGOZHeJuz5poFL+5pja5QbgfyXAWvEhml" ..
	"e30EA8lMqTnUK/cjB7Mx3cnF0aHKzeDEsYPPnwHB3HrAEGeKConrAFJCQqPAHvi9DqWbCQOhn4n2Es48462CUM0P6w28wKHd5AoN" ..
	"t//dHnC7Toz2hxW0XORkD31EI2e3lwP4uXQJP4EHLFQZAxfSbe0QzaRRaqGzJ0upUbN6Y+kv1PcGX4MnnohPLqgnDEo1Q7lb6s9q" ..
	"wh/n3qXyhgyaear9sD8CCIKXweoJSOgr3OCN9gt2zCuGyvItyasrMiW69BOU7KMyeRjxIRWdnOGqXzlM2aeTI7WYKNIz2ArQ8IaI" ..
	"V8Mpz86UfZ/TYPfhS5aAyYV/8akE7L+9lt/oyF/+XDOrp7EoDPSukE30jpy+rC64HjQYxaQoHIbTnOuHB/OAFhZPyuEqSqNiyCeP" ..
	"EMDww31bwV6myVF1GHepdtjmI7EBqeSHaHE531J950x7w09LSCx+EF1VHRt6r4OOckANIHPapOLjHcbI3X7cOMdehAHljX+vTKUh" ..
	"dpfv1v6iNm6ttC9el1HMiwXPUiJKJtiqHJa3PF62kQcW5spJRyC/tTpX9ZO/ZtLAwNziksYhCl2ejNQdnJQwXPRge5HdjuMVJSzh" ..
	"AZ3ABwPIisVvQhZ7PcNW7Y9R5Ay0ftBUqtGigctXxXI5rElo0F6U2PKSCuHMbt77EdT9gxeAy8FkVcHFkJc/zib2w9pwLPcsj3yi" ..
	"GnmZbSLataRLRADT+2fabeJ2bg8rxqln9BDhC5EciBKGJv855y+yzUY4YorlrWsjv7zEuFfX+QeKzvF9eWHKqEZo2xgFcGQLTFER" ..
	"Q2IaARc8cj+wdRxNE3+roz+vKzkeyYQvbCCjU8+sV7cWxljdaZzmCLIa6OmmaW2f7Sp4vRfInZHviHW8O7QLxky+on+9iVpnXf4S" ..
	"ThVrlJhq9cx5d2yjaPd8nADF8WWNyDTzslCQmC4L43dT44SZLZ40dWiPmdRdw7WXyXoGoXN3ZYKT89oCP8am3nCfoXFwfaqwzPQp" ..
	"MbFGJAgFhHrE7NVzAaVUee86NuzYQsA6aMzOAH/NQdtKPPfusfN2msiQI+m2r+BFOzc71vuNY0nkxg3tmOP4y7c1QWtbomKLfR1Q" ..
	"L7b4E74/kJnDBix2FKrWJA2col9o0SNtKvIta+cKsoLJUXCTqmf7rdXxZFGW2oDljAl1GJ4ZdedOkWv/kjCfZFYIL9Uhc/w+e1rY" ..
	"eeIlrL98tazi5MFmdAoiCKW28k7jTVN2W3nHNoOIpAC1MUiZvhyte7cFrqi1gcz/ciS9C2EGof8wNOYmCxoAcMgANO1ykpSFunax" ..
	"gTrMeNKFQmFBZKFy09PCi1Fwjz1rTtdBut4F3eniq7xEQ/IoJVkvLjizBCxKgzICYbo+N/LUQJ3fiVKtanyEOgcfjgeOJRHmb4kE" ..
	"S/49x9wTalMIQmDX7I2Cc3rc/KOmpvro+ZDvz8cb8zgSD+m/kJUlIlvkNos91nM0v75Hb25BDRGcPqj++FSGPAb8XEeNV5p8IAWY" ..
	"sFaEBXwMPo07bZQAo9DY+qB3w2MSwWyuaSXfnFC7R9jUez57qPtQYcp7kVoOQKrUTwmuwHPy7izrZO+EI1E2CxB2I2bVP+bQ4uAY" ..
	"s16ztSJ5g3fSiaJJYG3ZfMhKYb5hkhkBHJqQiKmP5QM1Z/vlXR+aIpgLC4OTqq3TyRrlUzEDtJ7uuSY3+fwJ/WEgYB4SZgEq0gE8" ..
	"rSoPhOtmShS/BpfEdH6BWiZieSJ5cRXhKRevl9V/0E4z1sEc4GLSt2yXf1IE5PoYG4zHI4JeUJFcZn00gi5qqiwVOvdyhvSlARIj" ..
	"Li/Ab+jRX4I+o4lWr/XpsrnCvZMouTQ/L2AZop52/qfrwL3cLuowbDA/+YAk/qiu0Vw60unAgUOXcXKA77OXz1E0sohvrN7E93SO" ..
	"QYl969jnzg+NFnr6R03NshFMS9fioXMwd1odttwshywj4snStrD0mxcHNmsiSyfsEo2KXx23Y30BFy888t0w3rX5pVrwqL2tlFWS" ..
	"2WirUo7Lgv1mPUZAxnyW52voyoqQhjwytmH55BOv6dq5KYsI4gIznvrAJ4D9LUYueT1b1pywG35ZIG87DemZD6c5ami/9voWU/2T" ..
	"oKLgxZG6dkEjvxOPKMvM7E2f3Qq3ZJF0zgIpm5I0f/Snw4HnnRJfy/J3cm2IV0bJCiFsf57bG5FJo7St06oEhF2u0e9eG3l2w3zv" ..
	"dZuFRAqewZjCael1snHm0w11YWTIe3b1fexa7NzMmrgGoyzRgojTZ5Nc63twgC8QzC4SnDfbHUHuj7F6wGaLJvi5P8LR+uTRcT/E" ..
	"guI+XvKYWilQv+xsBGjwSFhfJia4zcQwACNZez7bzV7I2O4POnAaVInusC/50HozWwMfmIT+bmp3sqaIuGQdO+q4gTujPBwcrRr7" ..
	"+TCp9YFtXHSoe7naRzvztLmB6y0Lrj8ICch4xfZromwM/nB+weN5xzmdEpG2VbWvV9VDHN8kDA56gLGVT6RkQY0JoSgJAhxZaKSy" ..
	"5ZeGwXNeU1BSqcqdOYHt7wHEBkGnogLXfxS7L+ykYdby0X5LComIPVgdZktXzRax3t9fMoNej/vbSDlgDPRMZPKvkYUdrpMOegvO" ..
	"cbTbjN4l2j0ZDfSHll/SGQvMpxx1WIbBcDrkEq/+NxodIvsIwpM64s6476MBxoveKW0gDtLD3IS01YEYQTpLto0Hhi0fmOOucM8e" ..
	"IFL0ZNyK1YHbwz2R6J/x2zop6alFPM2ht/lsnOtMOSc/13BOYyL+lqCo9s1HalfuoDQGwDQc+hmAnFlToTgv3lewr/X3x10gAkic" ..
	"GlQ2rQLA56eA0uR0WeOrS+Dc3LV/EaJnPpht61kNLN9Xf9CTbd7VBGHEeJPcHigN7VPpu/5F35AD8TpodWItZe6Mjq6qlIfdnq2P" ..
	"bm3KM8YDjg/oI7apkG90CUkPFASPgvnNFKFnckgbva2PbcHPBYxf+ThwHhPoyyugwTNcXOdgD3c2UJVMhyY/3ft3sMPvjmviLIn0" ..
	"qU/oF5E7qKDikdx4gqAA9+xc4JqUNpGvHnCrsDusr+v3QNQzlqCFZgVo5zwoWmYhuSoD0k7AxEzI42NtOPYYcWyprK6Z2Bu3lkV0" ..
	"Y+gzP9MIeToWeMC2CVLtckeTYEYecPBGLTi7ZJ46DEoovfgU9m6OlLMfFFA6Glq2TqYcospgp2a9i/zgQMThAo4VJzmNFIVblEtJ" ..
	"1ta9x0A0ifeVi9UXI2Ue0IEO7JO1UDNas4eCfyE1u7G7Zfed9bcFztQzqHCKgMPCGJaExI0NR7Akn2R3zCqYnp5gGGuRMYARDLwK" ..
	"p5coVjl4MQfhgDemMv4MQoUUuhWhj505lXSHnefZKay/YmhnnJGrRXOnEtz+OdWmrGSrJTm21tz/Ns3xH3Xe3MrhyLUt1ycTi1nZ" ..
	"7PPu5m9ttrdvgC94mJ1HBHm5P6JRuww/pMd9R7uC7Q4KYEhEt9HsFGqDIe1YJU+way4PJRqGw/rCd7jXUmf9qiXIYcHiVsiPCfkD" ..
	"OynsRZwlBKRpmHzc4teBkD4hKAcHtgeF19Ibg0Egf1VQ1w/cZOKWaDXC93NkvhXGP4re0gB1x/0t3WxsSckQf5VnE1/tNBbVAkLG" ..
	"zAmW41reyuCYYK+/4CE6aKocMJlCEMfBwx3r2UKWUuq4rY3Fi4guaSiv2cyL8aGJbEzq31bcpwLyoP7r1tR3LdDBvYWweK4Kyg/h" ..
	"JGRgo5w+YwlwS7aF5lyMeULc4HYE1vaSfi8LphDHJDNYMJWoXxot9S4y4fzI/r9T6gI8Cn/JYO3GqekcMhggo2dG+J8ZDWuCU4b8" ..
	"VBOd/CXRqs+Z8Kd1rcK6n4EDzQZ75Oz6UC/5213ipoVGuljsJo7VqvQMfVKlGGUerh2/5be93heRb0BOYCsSyNU5Lqj4u7q4eXIL" ..
	"3bowa+tmb2es4aU3zogCufD9t71LPJD7CJqi1mOTIjsXtidzB/5vP4MdmXMbnNu8kD9Lay8skSuP6r/shgCeK88xRsZJArsles8T" ..
	"x2QOHpOZW+LIK9t0Pe5iAhIHTaOfr8gshXmbePRuyfcjdv0+0h1Kv2RQZ6QUsgfmyg/M1lh5YfjX53xLbEgy0omvvvSLlwfZQ1Wo" ..
	"DTEgSKwFkR+HYCj1HzGT/mDV1MsKGy036dGE+I1Whk50kVmDxG9N69nNdTaFpnkCnRPqmNSRzav5ojj89kUdQu1C+7TTEtzjLDk4" ..
	"ToOSdjZCIz629mQnSOKhQDW3gPWbOLLGdtwH+cCiBf5t0550FA9X/9wSG1f3fkO+zXE7zouet2SIJ4rpCiCu5U0556UY0JThPZxW" ..
	"LA9VLVSadkOdQZeO87W4qKXT6AJ8b9RsdTHRg4v72eF81rRXItJpWHDOkthiYF3WkKQPRsVwz+vHUHtXD+cokm0Ri204PlWda4eU" ..
	"0H/VmQoZHDI24eUgixaqdnWp9TxiVz2MYfa9UPGIHAGfC51WBkIH0+UcDzPNgEzbKMr93slp4abkGj2tmqHTZBMOxYUF9XQO41ha" ..
	"ypPlQm27rJXiO3/Te5DljRarheTDnxqWE3S2R7jrXDye0ULi9clXsNYntLBsvwi0J+KTrbE18LqNg/CFyjibrEJ8itX9p+o5K3tp" ..
	"NeZTWjUckuzGI47MDnMrr6MAjyCeiTWgFMU7qQzhTwXVKXdqkRvw8f+Tz9CTMCbL6Xg6lSF6QPEhYmTpaSQW7b2wzrsdmJinqx3C" ..
	"sr0HJ+khhcefGD0eTzr+fbYn1E55S1nvdi4fjovlZeYJVM5p60qKdnGhsqQ/D23qevVgIB2iUlgmJ4qGJZPZVMqXcMfqBIfzWmUU" ..
	"KMIhWC0tf/xTrcRxV+EXaj8+0JZhjLAYCV5a48nGZ5Mzp5FAJBZofk+CDv0NVrQdLxyiV9Kx/d+DFcE2eGOXJpmvKevY+IUuZGYI" ..
	"4SRLIroGsWZnrIMS/sK6r4oIp0O2BFKwcfaXxuBFUOyZ9f6dfYYiehalGwrR49rfxs1A6x6cN99MRB8LbSgvqMX6FgxAMim86I2t" ..
	"vNP07U3cJYpZprxd5pEiiIC6kNvtcrsHxxFU4zX53BOuugtcNcrmNiDUr7/r1WxD+mOUIsmL2hDrcv2o5RSX2jrO0pRuWrcJJN/n" ..
	"XX8QDQiFlUgCLuXCk02Hp8vzWMSqVc5AR9FaTdbwM583KUFqZcn8AQPU06XpALcpklFxw8ij+9GfdhuTIizFERxbvMhiQe64R/gB" ..
	"/TTm76OsFMgeaq0NZqXMF09cnRc5c5tHzI4/4Tbb/VqaJCIE3bPLc4fADF7PqPXkmFPSrsEExr90+ZYs9cUXTSwUXGqQTP1aCcCM" ..
	"gwIhw811LcSz434NDGle4aKNdnU67pP3txyMhbhFX2bxiluq4lUtLNz+f2aU5taYqDk2O2QTv86MYJKV1rP4FXspChHE2XfGWM8n" ..
	"W7mERJ6gLbJErJlE02XBoqjA8leH+SZJV2aRfhwaekLPVogOLCm9HbEfO2XQLAdkULnNm5HexHYgsHjQckkfqtrN+V/GNikos10Q" ..
	"0ZK97KsD0qED8kTtVWU+p8F3exW/TJJj10eI+BcKewWzdsv7rbF3BuG0/FbSQVQKU11yTPJsUAZLFDGXpQ9jkuB2wTF3OtER8uAI" ..
	"BBCXoExrcMEZzVh/PsfQ2RY5/gUGfwyFVCfYpw2x4og5lVl5jsUXG+syeB/xjevH2cyjAAUtF7BJ6EBPYPYLU0cXHCPISWTfCin+" ..
	"zaSvgYDT0+7lCdozrtfijPWSVYJxVNwAOfWcYafKWUcU+whgdWLXhilmJ+IEsguYAM+kUyBfdOCUE22A1GqItCE8nmhgtuv8fOOI" ..
	"7G1pWCVxFmKNpTGyMMvnboWPFdwgA4mlY/OssjAJybGcoaFOja92PQD6Ooh2pXOa82SEfjNrJ8Oa7SWHWRNnxnwidzcYyqrdkhir" ..
	"iZOAC34WKyr+JJhArfVQLlBdh1v90Wa6CzyAuFunpfh1hOjBv40ZFP8phPfJWuqHroMmpJ+LUevLgspGAEK+cmHC97zuqi2lbtxw" ..
	"HJwuLXd6+Smf/wlJcmAlD0vWrAYQCUUpxXnCVDe4uKsPJjA7IHqVYGh0TtGnYQXERmuW7tRqPCbXjh5WCXKPasIimXs3ohMl+DU7" ..
	"01gv7ed6r3/1cHGMcp6O3T1CKmnt54Zl3WFGUSZQslkDWfTnxe7FW+SSWcIBGAyeebfChMeuLPGaibDYiXcnM06xLiHlFph3g3HT" ..
	"K6dUBeyTrFnWdkUR2ZBbGpC8k3wIeYeVQequeRFwJLHhJ5GAVLmGtA3MgpDezImButsN3aCEhlDoxvXo7x7fcsZsSQ3Dwq8vo/tU" ..
	"A12uRCRsDxvbQf4CvsHsg1PKrCYI4g9hNpgLIBEpTrazTgoAgSM5vhAt5T+m+fZm13kwyI5UL5hctSxtGOkHJ1/BKeISlBlaGjO0" ..
	"p7+SZbyi7sdmdzWiFKb6j1rLMzulvGcwEmAl3++Y+0Wp8tuziBeLysGRXvo14UrRo3Tc7yqufxew9qy/BPYsr5icEqLU/MF65Z2w" ..
	"FREN7Waloom99VMS+s/cBLnQzeH+V3McoZmwD+4wJn6OsYKw1chdjQPag0LAJad3rqxyCvT4U7s5e3u916OWkD5CYdQoKerhXheQ" ..
	"ZxBAgwwQ3WPnpsAFa2wMOeBeyV/rIrIhUZPZLb5DH4M2mV/aHEMkxa00lrgSAKMZdpFdwKAskZ5y7J219WS0YwEek+aDBfsRlblE" ..
	"jeoXaCx1nFmxy7c7DIuyDEAc8Y0vVf/o2pWCEshOc75QnwG+J93MRIk9HBchI2vOZ0o/iYfboRbN7HNQrqUyheNXk/uKalz8uF9B" ..
	"bW1f/Q1gw7vYDtM6l1IGPmUlqdI4f1gS6YGSfzbWH9fSJyYR3T6qPm9jQ94VlLJSre7qSo8TzCEAlbsa0+PZ2UhWj0q8QmhPuqx1" ..
	"9N1WBgXh2UeaZjyRzzQK/XTri2mN4fEJhUz2hV+Zrf/+fD+5IWsH9Fz7/lm03I6HYs8XkGvgw6OocGfOsBKYuPxuvEekoXSICt3V" ..
	"7SWCduAvlmMuOa2Ef/N39nVnkjFhr+uN9gTFNyJyhZzg+vKjYvY9n7gvE9yN6Uxn54XkmH2bPRqV0Jgxf1gkR+dPtFoUTuzCRsdB" ..
	"zpRuPFaxmb/rginYmhP8vOFTRyGHiHxYubmLq2ZIvcbtcurRv/Ou0q88DLvHhE0CVQxt/V1+MiHVJJYvfjZgjrsnWcl25FEOF0jc" ..
	"czZHjozz+lFgthTk7nHjsno2oat17IPI007YzlDPv76g9vct+3o7iz33fWp2L9/hTUOhtMtcgWnHQON0o0UP6rW0Ber7NlCwWBge" ..
	"+dgdu3mTv/jkVZRM2YGCENi1n8EmChYZ448hT8DU1iVzLF+HVMBnHH/2Kt4yW2sI75E3VVnjci8wUvhvjtbF3OZxfDz4hAl9OJyq" ..
	"cEl4Q8ntctafNJMep8hLE/a5PGWMaCkJ7bI0/f7rpfB+R0Ng9j/52Uypz7Dem3BN0Hrew5yNkiv+jXbpwwU7B293U6H5DurGY/ba" ..
	"PT/3gGHJy68D83wTwWvxTZt9dEUyAZ4wRTtw98TsEnT9m4cqiN2p/pUhXq7AYAPBUoegdCDVx87ar4zNGddhFGczs6ONiKj0EoZB" ..
	"nizLb/orCwEvL/knQQaDAMuX9zgwSbWz7TyZ6VpBnjN5APXQPothsDgZ3oM/az0kRgoTsrXUlijNJtVybAL3lvgVM/er7RfdS+jM" ..
	"YO/QAmZ8BGJqG5udsf2aDeDLGczfulr613OvCH/hLYu/DTl+DfsjrecbNekMUFJf5n1XWW7c7kP7HWq60ZN+OWw4wbzwAqHL9gT4" ..
	"mcRZeWe3VzIwNUn8fw8ZWa/hYGwb5RnMltlQyJ8nGmu7sddQYYDFaJQHqMRCuoiRzmB51me5g8NmsjOTqt1RcSXgL+Ox2mDqD9jE" ..
	"WidwWmTeODea7bj1igOXc1Mw9QRSK2MXYoQkKZRJzoPhdAn2hSlPYzkxlT7MQcs89hc6xecaMvmmoSCJcUyKzkFjHKY4e3g0WzgM" ..
	"R1pO3Z+Q28lyVIDn5Fam8A8+TYKAu53WJoCA14MZ+jBK2hI97eCf1rpKZDhgUOm8TN0d3GuJAC5vYnbFzQoNnHLJahnTrEYG97Fd" ..
	"vn7uABNsa0QRn6vvViUQZ9p64Wmv9jPCOmY/2mYaoLqfqAqvOZVU5ynX/7Cv3kGUauXRsvKhJJ5PPpfrCERSxCcybDo3Q+urfCJX" ..
	"0GU7hhKf7WaENXzbyY9etuc00Q2wTAwkUBSqwyumpgLVXhc9D143Wg1QOC6kPOk0GyeTEJhiL+llUj6EnWK0iDVAP1UerE0IccMY" ..
	"LrNl2ej3yf8T/7hZF4v1HiQkVXCVhYF70RGhZQnZfE+Ka9sAfDfvMS5yw15mP+P0UWm4Tq6MUXqDkErxRbR/x5CU+WLvNYdmO5cA" ..
	"ssOX7CGQiraam+sLRIGpL0sxWIJDr1CxpdpHIea+L75U+Nn1qW+PZmHXnwcBJ1bCGDzS9Ihv9unXe5bWTKtyfyvg2NPHOt8JhWrL" ..
	"5827FMOIEsRWmSGS45Q9mU1lLGDhFPTb1JYqiIdOrlthy4goP9Dxs8GQ4cpC7+PBU1hSK5XJN5qyHUWZMld++VwDRbnmL6mWVc0j" ..
	"9bGTqfLSyTakzrq55uRjsH4YBB6cRPFl1LZ4VpP7pEuHgMk9WXVVp4E1Lue+jEnOjixqD/fs0L6nph6vMfVKMWv2CixQVHlQDIHB" ..
	"C5coOIkr37BPrgTUndORy0LwjRH8j3R4CgBK4undLANfZyoYTJsUsLcyraTD0SDZ9EVSSaChbUjMIdwZzLvv0O802C0S/B31FGji" ..
	"V9Q8JIX48VUyJ3il5vGkCiWuwGIx3bTP0ZPdvxgcn1vzD7KhIn1ivZ0lBnycPdR1kSd9EMwi9yg0RxouyyFhP/A2wB2g0A8iHvY2" ..
	"2hkz7IGdFdcYZSp7ai7WrvyWccmxk8SF1WW5FqIck8JkLw+ZlbaD0/d41m/6tqwV75eNBm3Q9nC71tswtMBCJ3tRavJ46UL2MupY" ..
	"liKTEWtcMXGTgQxaz3B2MZqXUgg2/6Pe5QI8RqqoOrWF1QGSu7+6jFtS4PTJq7LRM61WSOdBn1PmwitXKY0vl8ZGFMjFnYyWV+cJ" ..
	"r4bw9486lOdfPw/8Z/0NWBuTTJ6EGsU3wUAE/ypVKiCoczRnxUcRNdO2vEX1aDeNfx5Ua9ZxVwsGSiG8BSnaWs4pRxKGZW5I5FuE" ..
	"coYZ9wV5wylu5wBzCENkVGEDBfqa3Daat5+I8Za9fx6z8IR8rstGeWLlnhfiuZDk1kSF88k1S/ZPeJHv1EXCnsanyKoTCFCI4lTe" ..
	"YQS03XpIbksMD2b1WuC5RvSAAbRKOn2KjPAQ0oYBd0iLQXFXhOynJmddTfF6lhWqjR+40wMGi41jUSGT6sQWRinvHIkU5JOmbzRX" ..
	"GfLv//coWepA2GMKuUT31TSj+KPhpIZErDw7nMx45/R1KR79YORCDBgC34gjZPfZx0HAVJUS6kpzN3HkHWZ+tK6Fk75S08yTVzXm" ..
	"BIwDqJKBZSHBVrPIiasovah4LKP6dhATbETnefLD7C5x5xa9AtBfez6D/tLyVMjPqEqPxM+FDY5kmfY/5l5wi4ESquxbXiH1rapc" ..
	"TDq9TfSpHAHaINa1J38ssQyIO1yBCB0RTY9j0DXMezbBpUKLhVgZXvbMRWdxitAEVX2uEsLBvkXtHGEhDHHnv5x/i7QLVq5+ijql" ..
	"lZTYyNqo3ZDxJTuimT6947vd3ThgcYDpJKznnfklh5YZWZEokL+H/9HJZYgmbOY0QG0spkA9wzrvgdtC1YSk+K0offuiYne4qbq2" ..
	"Ob83/bxgkc7uLE6XQsHGVxMQylTOM8DXo/8nz95yEJ+iJHIj76YpgdGxyA0MQRWV/8PkPLtyuC9LnS9ePXxX7Uvj4bu3aZt2D6xH" ..
	"Kr5CrvcFS77jkyd1xn6diVOgeJqN4rRKAu4vpqaulcLw4XGlrrQWVXtCtGsaOkoZMlx3QVtTNhTC02wMh0x6XJh9TGQ71jGGYh1I" ..
	"/dxAKRA1UQY3Do/LwryRysDuDml28wYgUdCqMfeHnZc817kGPrUVRcXbxmXM7SjLuJImONopC0NH3CvoZJl+3niO+TCT/55SxhNe" ..
	"9pP92d+4VOi3fAnuX+YAICSRLp9p1HFPDFsRfIVHgs8VKmrwVYjMDucwQ9il4/zeBsqs43efhOecNa4Fp17mKY/N+GiiffZ5qPVk" ..
	"E7lzHE2c7G6bx13JHCz6+ehSbHD9dOWH91mKcd9MlK3M6Q/p31EBjBCsvMPfZFS6miIASuxiJwYY3M2TsLI/jnwe5E3QIlk+3Xvp" ..
	"lscByQD9P3fv9zpA94x9km4RjA5gs3bsZuqVs5S3Yof2S9kD31CyMrpqpj1ZJQVwFY7WWN8p2yYhl6/YKxGk6fo3+VaXWttmeTa7" ..
	"nV9MCxAa1rpAGPmkS1Kb0qc2Nm6f4F73Yzpr4dW2qClTJ9WY7Dxo0YIVTplzeq68ridsjg7kimbmpfuXOUJIURI8jhZp1E9tNzmT" ..
	"0PckKx2EqplV1L5pEWb/33cc1DSqYPQSq12z2RZQ7MqLkUzqSnVApWig2uKlWBIBgk3QIYRxGow4nzNulIGQdk0cX2A9PQc8XkY4" ..
	"RwwPM3Xzr7EHV8qmH4m6Be/weQb3/AAPzqShcfC9AhSi/I8cpP0HT10jYQCp2o+IeF3VI+BT5Es+s0A4FPrn3NLYqzujoGOvEQMl" ..
	"IdXK185VlDk4qInfK4nayAY21+gsAQWUP2iPrdJmsXUytkkFZ4LgJqcl1RuhcVPplHnHVDrAXWW33llTh4/8O2ZStVemvkPlU0jy" ..
	"TI/OvLxzjJcrP+H4OVelWGtEfEC+xXMW7asNS4MYMNs/3l9cquau/4tp9a/Mzqk5vkN5Pbt2Tiwa6YOi7MDy3YHZBWEISgKQ1Y8b" ..
	"4m6WgmbLpUegGMV1tHy9vSJr+2mtErjEJdFEAhTpUNsiw/1NxXg3RlQoQS+/cbyHTVv6K4jD0bMF7LqHn74oV8obug0hf2prdOFo" ..
	"ZaaO4ciBDpH8moXX3+GIpbNMfigDT9a3HUN1uA081becdyGLoocgmIzyyDLBTsn06QIkdrlOE+eWMtVlq4tJZ8ftNwI0NmXsTbmf" ..
	"ga+E07d0sny/1cj52G51M4P4YW6dFUGr/j9gKRcBrJjUQeDFeEqASZB1zS8KeF3qiOssm+nWltsWAneZvriddojBjU2iRAzl53uf" ..
	"Gnsg2RZM/c2Xgp4L7Sy+wPTrdU4Nn4Hvm68pOhYE1sIpRh1fKqmjPnT5Cwg6pPNfRIi00LtVP2WrK9qhYTGARu7vgLQdMPNTFT4g" ..
	"7yWjHC4QHtQRiBWW0wGghImjeYDFDn6QwKwdMyNTB/7uy+UOD/M/Pls7ugBa3LuDI34n5LvLlAdBZ028GBW5M06ZmPvApgJO9tpI" ..
	"fXSz7q/iKe8de5bC4iN0EzkU1R0V9GcUfU8041uglTRAIJ1Lcw7QjEphF4Qjv1F8KGIozFaaD+LJZyIogsdlJY7Dv7uEA07mqXkB" ..
	"CFRd7x1DgQbVs/UTF7s0Iu1GIha9Zu5jwXhbeRlpTDTfDwH6dsOrHQwInEXP+O2hc0PALiCf6IqoWHTN13IABGuhlKu3q+IE+jQj" ..
	"5PJNSJsOX0myhnkAH/Z9m7uI+j0bNl/wQ/cY9VSOcu+eTydF8nh5NipM77alNwMrac5OKrfXEHjjtKY6zG6HpirHBbTu3TDRemML" ..
	"FVk9nni9PwBeuonG400Lqz5H4EHY9U+vkFcJC7fOms7apBNGqrM3ptsrTKhz/oc/wK62MLbVtyo7C9nh/VfDv2ucm6XvLSQhgPG6" ..
	"pYwgvQwmG+2sbC9jr1HP1IjmyrWSN1CugVtVxxcAOhDZ4AmvCcdFU/jkXMPyIBjSY4S5GbYUW7nlgNGjOQ8fsUhNpBcjwAtKXoQ7" ..
	"d7yDJvFlBBiryOsBKU6V3j3r/0WLJHHy2H5NRNYHVjI4YqNMYk2/VML7wTPECnykScU5zruWSnEqgiTwY8gJpAAb23pPnaqI+FH2" ..
	"TxAQUw1rqFvHvXrqo99KyzwY7fMDN97G/vaY13gp5tG4LJtu/cc5WXErZQKrUzQI7K072PqZRhSrEPAMTqE8XMgQcqZirsM51NoB" ..
	"/64iAZ/KAZZVIvokI5qcCFhEci9wNmp8XSUDMzd/FoJCkzRc+3JAZoJxSaZahN4spl572vN8dFbJ5S+5Q7ROx5o+/gfgY2GvlIKz" ..
	"OkFMIbf+LNcsGQhWtwk3ZAsLWsxRNJNl4Vu7JxE6zNjOoGeIO9rXBFmHJEtyM3qXayZ+fdYmRmKZl56EcKRmyryG239u8uRhK0Kp" ..
	"GTCgFiO4TkL2ScWx9trVltODoui3BXEaYznR96HBnVEGNJU9Pn2Il4z87JI8T4xTvHsKOBGePU5mSPu+bfmlwB1c6kNEoAnuyqok" ..
	"9CIfSznRBNciwCVoohTCSboCGhhk6j8CN/CZYVNsCZAHyW/zd08ght48+dKQE13H5s20JBqUuziuyVqe9pMLrTcGedF5DH1+mGw6" ..
	"GDJ0FIalzUHZ+zo6Z83knsQy7AQAHwTyecjRDoYSiTv7h7TQrs2knWTtatGJd/CWPyAUfoNaPNjuCxMyIUK/phI3MiTbIkFsd/Lm" ..
	"LtF1GnCsiRmmZQFGEKaKQqCb43c+76HmJtKWQOvqmRKMuUXWahyhj/E61JCCBcUbBDgOLy/tXE60gpdEHG2kT29w5Hc7gDrAA5ok" ..
	"I1FzFwNRjpQssCL7fnuzT7TsGHwxX089rpQY94ybEZw1D/jJYVVyND6hnSrzCVNOwguj8V9uYBRH1dCEV5U9ZJoI7V1D2CwHQbJE" ..
	"eihwk7pjIzYUyVsLHqDF0BEV5OHL9XorwVItg8AzAMkfPkk2BV/PYGiG8FYERtZT9zCmlJsinDi3fOf/6loo9yVyE3aSFLuhOJTk" ..
	"IjKiSkQ1SgLD7l/MjiZMhpuseqDAFKp3MA3z/lrg2qAZO2ft/iOsKryIxk41Gxko7tZoF/njZI97vyBRunZ09Xfauv7juHVYs5ae" ..
	"+Lv2krLhcBtcCB180t64dyj9wRegHDY89w/1EQAmf4i57YQPY80Hs+nhZv468HUsFmxElcfybcoyHw/sJeXqeMzX6F0Mx1BCcIkW" ..
	"v0u+en5EMnFQwEitc8STIyJpdlW3nK1vPnFK2W4ZdcGejZsJ+Q3zMbITQDzY2VLg+ferj03BczU935SBlV19kIFLYWAo8bOKGJ9N" ..
	"a89ckr1nSgkPyPqe5WGzBPEnfatN5ctfME1Udvnd3qdEdt7jmWw9Fhd4vLrdAVRd9BkCCqPNZxxn14RTnegz7QBb8zJrfbbod4FX" ..
	"wJ77mdN+A3LW6nelqWkT0ZsWDtSfV/0VzFO80vvmejHQKIpmGmItdg+DYFfZG8KBqqHczLc0xinKpmtUQLlRUmAfOKC6A+Mr9YCp" ..
	"TYYPfqy9UqymRCmaP+4owAOd1VBtnwl0aEpT6aHHxlFWrWy9b1ff1bZdDeViqHEz0Lw74bLVFzV+fyY13ikwf94jhyLN2LiDsJqx" ..
	"mG+/dktnEfgYxK8H/AoWrzdl/gC5APZXpDSuy2hKhYalNMIEbGhp1K+G7t31Kz7iYRTbxX1h9UXxga6VUS9eBO9JnLMGFxx/xBad" ..
	"Vuqwt+EcIudpa3C5UTm0bgqo/SlocV+iQdKXwANafQ2t1Bh0QolvS2QBX/Dx3XE31vWMhDLuWMckO5rBu6ofCa75BfHlzcB2dlvZ" ..
	"bh4aaQSXXw9wpTBIG5nSxI5EPVGR711e1jmBbYPU+03cAux5v4zIJFWm/jbvgEIGoSiC/+lQh7d7nq1uN8mOKURzEOpyoRPFHsZh" ..
	"dp9DLVC3E24Bu3QOo/gWKOwv/mjXVqR51miB+R+5S1+FJnAXa6fyyJwjBjh4fd6orlTjeI4gMYnjxPUfKipbcjyIrvfRJTmS05f+" ..
	"vqZMoYN/ZoqbiOxgzFxjKeCjXXl3yUgl+5BKWtserD1TLZEbFd5Rs1Wu/zFvZPGqbbOQpB7hwbGayq4j9y98sIXOHO1KPinbwOpi" ..
	"fikatSuSE39Orr0vPRn7eRClgX2y6cZOaQb21uzyp7M2+3DeZ5Y16+SOMPppB/bJN7Q9ixf9L56zvp/cbkr5Xiu4elrtJZ1V243T" ..
	"ixzzUvZ80qtOOphSrFlfXs4sPIZb5RvvGPQRTJ7OMnRJ0YdrTY5lWnNI1XinuhQVfTZpikp3AFoYGER8qTJ1qCmeb/bqim5zpN4x" ..
	"Xt/JYaPrBh01H1xzWXlvK4/0FvrNZZxokEeSxHno9JK+v2QNfxZ42r+10cfTrN7580z7C119z9+rV/iGAOCWX5i35j9jPm+m+eN8" ..
	"sVvII8jGGn9lbPHkZ/+xuRWOWrLgYScjOvr9qd65fDAROfEAuunrk5+WJu78oox/KwCAqJFArfFId6ppbWpWnHSJ9l4WMeQXrngD" ..
	"V6MlUAFW1sKOuVHxNbRfzXMbb0FT2eYWcEiit9gkl1l1j02evv6px65z8lqUAP9BXJHtpWCl/+FQ6bkQ3QWHdW+dNIQWvU4xW7GO" ..
	"oRv9gkI52Qm8Zq0ptzWqdP+dXW3Q+lmWrW4SHKwGFE0MKI7DARVmNaWca4Z+el0B217GQjokTHyz2RguQaM/M+m0LGTahNXr46Sd" ..
	"xeLfUydwmJIneeqB1v3AA+PqkLpBJwow2R82e+FZPTsslb8Cz9u2SA7K3yrnjGmwRHZD1whA0ZG4SyjiWsGJ3W//MLeb7y4EbN2C" ..
	"w1P2zfSZmhVXKzXae9+yMf5VhjICIqARklR9RxUh7DAEkCox/aVGcna+9lSUX1tsDXnXzXZd7WtHeByTclPX24OyWmur5xY6D2O/" ..
	"9ICP2HNcNHxqtUM6wnEEn460vTjbuuPy5QY12G89sJnqxpF9ghzYnTPwyqIfh11Tp+1k8YhPqAS1DnqBfSbfNjTX6OVgzjplgX0O" ..
	"e4OCY9ySBeD45wTQmu0j5S+wzcOgCdXj2GeEVAJFSJ0V+jEG6lBE2/dW8+rR4yILXOW7h3Qsn/21jZmPBSuqc+ZBA329xEyP0xhO" ..
	"G3ZvJT3ZYo9pbIypUbLW5Js/VvVQzacNZxqxiU2n7c197YIpgnEj1OvsyvqGb+v9wHBYU1dZDSjiTMKcRDQUV9nkdPTxaeWdDbkm" ..
	"ybiYVztD50IgzXYVnGM80xCQhtkiRk2bze4ehVH0NDXw5j3ysQ3nCqu3VpGV7d361JL3JmL++rQfAMPNMnrPKDIHrTMyhadbpfG7" ..
	"Il7t01bReDRQHN+dfvekuQde+MaXNha/eU1UpsZI5vPn5LFg0GURxVU7fmEz3ih2nMp9NPAIBz0LLxqT/FBg35smL1Q4nz6xt2p1" ..
	"gLLaWuO5EEhmJcF2mxwnEfpRJMj5xlza+r7PwuruGw48QXWE0uhTiS4kO5elzYmTvuwYQjKPo/eiB9mIeDvv1neRFZUZ+oM7Zymv" ..
	"y9MXvnrZ5CTnGUuNANPWlWguwd1RHZzMwMFBgtIXQIV/qrDpjhMxSapmYH0Ubp0f4fYDoPIy1DR15qfwlDEelhDt0VwIDBg/eM0a" ..
	"NxLgCWF1XmuDHVgp92v0OKNTLyu2WzK4/W9j3FCQpyfvD6rd7Jlo0r5MQ9fYh3RK9pq4qdMFktdWWhrxG8mtfJoXieJsIzmYC6Cj" ..
	"YmHdXdirsumVdkdz3rw5qFpsBH/uMXSkfzUDIpzXDe+1u0+LwtGpxj4A76uKrXtB7K+ibHCn8wHBNexL/kb8Oo/4hKTyzrFlAp37" ..
	"X7mvk182JmAoRb1VShLp7MYYHVe4nco3V5BMIIMiu0c268kSaH1upxbDwwLZ2O6VNvJ76QTL9tCOiPaC+j3kMyH6J6hwqx7JXSio" ..
	"8WScnUBj2BwlYkRufvV0s5G4NmMbfcBHrbrft3nSL0cq7UoJPwo5uGur/TlfMw11K3YEp3FhY/Xj5RF356cf4Dd7PqaWAsBpd/PG" ..
	"CnqZpgldsFnCMbvyk7XhSpu48RnrDFiS7v1FFbApKxOcMuuQYnAX0FIFoSO7e8pOT+HjenHawh9aC2XOiKoHl/Cbel8ELZCoYkyU" ..
	"vktaBkCFPRAjucFP8awRf2IuRxbBU3PKK0pfhWbaM3f6LQBnzcxiM9lNp/gj4VmqHxRciGFEsIHmSp6zpZ9ScaZNsNzejIEZkuhb" ..
	"kkCQTtvuHc76ZCj7Ysp3NE2IyAlNSKt85SuY0vxhWL+3kIJm47Th51H1JE4uXsWzITCgxlzAr3WzA9cwqG2OqhaXRodeOccgAteP" ..
	"EjtWjBuuH5BOFAWbrCeECbF7pplVMO3IjsQIF0szMgTQjN9jXAVCxFezVPlrxcYs0++1itVkU28tHqjrZ9sBuY8oLlDf/PX0kObI" ..
	"3n2+hot15dKeriOyiQbkZ7XbjVDBFZURPxAR0SD9PEoTQ5mYFpWZOpu1C5S6yZuXk4W6HFyax9C3UUeXdiMp0svULoY2WJVATjJ2" ..
	"TMoHABSgRMQmahRmYRoZizn9uqT7sb+D//5wdRHnypktcRjS2XIONknSGDL4DjDKb2TlcPMJyS5d3eH4YsK38kBpWWUvYhty+pSo" ..
	"F51Wusd3UQBv6Nmx40cDECvzGoVW1PbjTFJm/9fjio0F/GrgPC0sSXEOiA+QgU6B3yyT2x6Ld0qLGl+YlTT06U+3mp0PF4tBAjoD" ..
	"xcd+w989byKxwPmB+WyMz/ncORh5OD3tKqBUmV740Fz7KtrbMGe95t0HewiWZSxwgAm2/3xwMVoumUaiSmI+XmMpdqS8cDwx2T4J" ..
	"vcAPkyBVYlESP2a/zwPqs0FUVB04gMw3QDpDb61bCb5EW+NMROt1NNlYYVR9mCT9ecMvC94d1fgcYjAUuc1BoHWfZtSt08ahpJvL" ..
	"5ccbzutQX6rRCdUQ7au/oIhrYxkampf4qmdEylV6iNc00OJHknRM/8XUZyU0iZyVlT+RzmqYPrMPVegcwGw++3zucEpmbCAE3z43" ..
	"/YWng6WWhCQNQ0pGd0RNlgXWevwV/NdWc/i9hX3MPcRmhcgC/5tc5S5//PNzPi8siWndta+muSYbajTOtl+yTgPP7EY4+Oodhncs" ..
	"AvL/a2Rk35a7xJ8gSvgZ5nfQQ2GgNrZOPNLpYc5JC0C+TMQjdm+sAQoAsT4QjznotaE/T0Uh0s6ofx9N7kxiyyp+/Q7I8xSEHzz9" ..
	"kprIbDI0NBz+s9FSrFuU8WVgMOblhNkPUObKN4Wp+qSv+GDfzSEwofY0/SBRqHgS1YH/nDejoxX6IN7c5ecY+O4HRy9+RjHBmT5T" ..
	"ZqD0G0uEC8BXC1/rPUWwxCGpQ/XkEErmkTv0jbjOc5uBp30YlEZPu57BHBhKekpjpVBMQBvtPN5A3zuoACrr6fAGGMlwdSifXHvQ" ..
	"OoJaKCiBJysUVyqbNhC1l1YY5XZCkVZ/ntPx5+VGF3A1YXXbXiJCMeQefD9FVNANaxhZuPIZEeu5/xpUMVS7IpQVSUxdRlsYb4IN" ..
	"JR3tOrRBRCcmVFnS4iNxeJ939b6Njjp5qoxHhchFDn8AiiGAT5pJR89OO3njAjMLwn97GjRYiabjh5sAqYcqsGXkYZdZc5R7q88+" ..
	"9aBPZAZIvkKsTW9DiyDGUqa7DcMyCB3gr51HgcB9hoj0lKkNNpIhjvyrfHtVGae2gFgPCcf4fICyObs9B80rdV9tKqC3LHTSkGvM" ..
	"uLJ4hBjJNUi8Kir1e/I0RZZmD6RrLcD1cpTgsZ0U6FYRBTLZ9MFqoqfMKPasNZXAwLD3jguXWx6oSHCzp2uehdAJceDJvbZe0cv/" ..
	"HZpL0vp6qEM/jtajwzzGsfktUOlKdp4fOn/T+7wXcxXWXGpeZpjW4+v59i4yjstw2TXGEhtx2DOewk0UdDduGOiz+nJD+MhnJ5Un" ..
	"NMScazFTLnnfYwDC1DpBUGDUKvHtBvk+MDIlyvTvDEOcU+MXEjbtxVfyAjAWetjeGSYCRYm5Qzj1PYs+AE1fzSaRPAirR2n1RH9Y" ..
	"eH6paeFGP814oZtmO/u/U0f4ZqtC01JDWw85yDmIGuQGvrnllH/jz8uxhKjGXxRm7nNd08PRsczE+c+7FDTuzuVGqQIlIIViSX8f" ..
	"iMWQv6daZWlTIVzNnjOUnY7Gug2aAT0ikTZW/yYDGqharMQm02mnzexJCU/RZ++8y5S8TaHqH8ijLinth8SA6Jmep+Gdci1v4BD7" ..
	"rKywLXL+68PbleNbiZK2Lrb41CdlYoXVT7krnu7KAlYPa3wuEbLFuv1XChIXdV3raHb6BJd+25QSu3Io+UD0E3mACC1h1aRp2uXK" ..
	"KvJtDOiItRUT1Ntt/WBqL1swqe21HSYgP7aveh42tZLni1J/q8fPJQBkxCyH5g8ZRiJ9QCZZRoFl2wTXywVg6Dgq/GbHoOEGH6qg" ..
	"8InaJj3yZREsEeul9QWjIcXEPzE042IHjeLmCZHlT+5qJZRiYBrAMy9C2MHzrMlmC5lyVR2vY5tZU70b3wnveChi3zswB8QUuD3N" ..
	"gg5YZdw1l+xKU8IZhBEkNloPgCOW/jYaVHstVqQCQ/rysVZeBJ5D+9cG1XpxLbfU1+7Gg0JDQVfq/xXT/oReaTiscpalqD0W4QIv" ..
	"H3dO0BJPIenpU1t5+zjRl0mAcruV1tWihP923LQY9JFFcvNiWJY+sz45+UiAl0XzMv5/Vy2vUQw1/aq6r6cfIuwhr5BBqS79XM6o" ..
	"GlCMyUxxANeM5GbztlpxSPMRJlskNCTYImtcp1V7WqWsQ9QVplOY6qORx4FXcHuyWEa8xZr1o+TyecvrGQv95VM3Np0x3kcFlT8Z" ..
	"iXqUSvG4tPPGk+fUEy85fXwpIbqzZohhEb7d7jX0iirb8D/PzoOFtxOER+IxELQT5zo7sGiPLSE8Gz8sTmTjHEOVKMqIEWGm6TXR" ..
	"AY/sqLHtYxf8n/0h6QkKC2e1wzc6iUMQo1gA4K3BIKALAGeQpVR9bMY+EDQytW+voWSdjt6OKzoFi1LHF88/p+Jkzz1r/PTxRxwb" ..
	"2Eg8rea19VtBPkhI4t1iHGj960DE9dSgzAKRYDmdnux4AMistlyN4IcbYRyKjRiVdQcg93+Q6JpiOUc23YObUlu4Ds8u2PO9grVO" ..
	"vb0HpwvHObLvps7BY7enRP6ZERbijF+3QC8womlToO5KKtgAWuEesN5tqLhP94+x6NjjTMFKOtDeRugw2yKmkvoJkvG7345cOp9e" ..
	"R5U/LYfbcaf/tOi4QsqzPNflKYMtd8BHOc5yCegPifl7d26xHHXRN3/kxhZEZ0tLCylGMbHJzedosygNUULHOyQNHTq5eYfkk4fM" ..
	"uW8vWKEf2eDLr0rZEEmTZUB1lZX/yuQerAfcTInmyTJ5TyJPI4TAaACevlKVczYNvIVfdQvIlAJqM7J9z/9+v3FHVrL24QDm7TiP" ..
	"pPX7NUZmOwPHTmLjRsfrGVjFCafY6TEXWal+6lYQwtRCK+zNOskuOPh+914ELucrR7udhMhqQv96UvW6lCsaCvIkM6wPLiii74UT" ..
	"mBcTe1ve7ptHXb7c/5XbAbAg5ytj1qunSSDJ37SEUNPYA8rQUFwUHOxqbD0urVHp6hlM2vEZRB/qFXci8mJ5MUUH78KApbggf+wf" ..
	"ZndnSMT4w6Y8TyVjirmE21gCSdlGgvJNJfKfEmNvjQqz3L6BUhpsFi7E6m4i0L28KS+PGy6Zhoa2vK4J5y07nGZxI49EZA2cJ8zV" ..
	"fH8cnx8iIAKbN+J643LjZNyWbR+CbQeueMdyfYyrSQyb/ofmtHQjyerL63xHZLxmfwCjtMNAIHRfO6fACSE21EE/MVgCJMrYBEoB" ..
	"x2v/ojiD3BexQMj7fjqzOl/Dyucouq9MgveY2sUV7RiCuK9P0Q8hjyUfrs/sS7naa5aMg79IGBX2g08xRD1P6OsLde1vU+MbceaE" ..
	"1c8jSg7+rPmwKSzE06BsVSDphxzC/P82q+swxZMFPq13jamje28UJoSJ347YrYmdoCsyBjVW0vi3IxceVYrfUBHUS74c0K40aPni" ..
	"btGNuBqXWMhDuPM2CDMHAVc37pVzFVzUrn27II9CC6DKFxlmYcnBNiht8gGfswqYM88foeVEOVsgEldHkGMRe+FjvXo8TeOdThZp" ..
	"Qq030tDaD7Mq/NaOIYg2aOIknCFyCnAI6iqAds0s0C/cETNzLdxOZ6t3849sGKoSHYpaCw3uPKcWGhN5521PCf5s8U7CJV0Hojc3" ..
	"dX+xOL3IYQcHt/EEawrjTCTZhfrlde7jocVPuObjSoTuuZ7XnuL5AnenbLznmfsJSAo0/YSD2b0JUTrSppeIdG/WEFkBEx2uiZBY" ..
	"8jZKpbxo1X4HN+9e+ZZl2ItAPMqt1UXo0MakPIworgFjE/9pNV/51ht3oPlm70+qehWOR7b7bGi3Bkj3aQaF98ZULwbV4nzHtfvN" ..
	"yCXXxmkLHYlFmB44CsXTGDT6q4n06UvETF5Uu5KIUM573RqronszvA0j4qx+ESjmVIFg1HAANSlJU42mmdXGy9blgiOv57EW1USb" ..
	"HflQEupuEiModG012/qQiGDeHzLhisyVncfl2WP3kfzuvafukeyErCf/PjHNWudJnXSd7qUTcZySZgaOEe2GmuU+nLWVaCA5X+HK" ..
	"4O5/Y5NQRmbErk3yXsHvAtGz5f6E8dQk09SP/V4s6TBBtXwt+WmzHjU2tkpZ2eeDpaVeMXXrFrspLCZnIB3cW+D7vazbLitzqtrt" ..
	"RnwOowR5jAWzF1nJeMEiVo1ALg7+IZsqYIkUAOPpjOgX5u/1zCKk7e/aMJRdtKEqx7qGZzaiN4+dYSdd1S7Rgn6NvqNsLxtO6R3J" ..
	"jo49pAhc5AsOqNCt3FCm0DlLyIDlKv1P08vvZ31QF/grjT+7blGcdWy5+tboBINigwSZbZZ+kMChEBEkc/21g8w643CfLYr2N00U" ..
	"YR3B7zN2EXsf2DRHfIaK4Ibx5mlNCGFTSV7vUpQxrc3vrLwRUBU4cHgPEA95rEacyfvBugfeKpz6kmcdcUTFK0stJMLFb7iJkdn2" ..
	"74jxcze33GFg7ewL65+WKkSNbK6xx7fqE/T9qp2Rs9Z1aJ7cwyBXvfjnMm2ORS04l9dazn4i9qxZQOHZE4O0p+9KkhFbe1XYynYl" ..
	"COf67HrRTf09i0US4BStfZYOmQ/MelKgOGJJzbMYKvxe8zkKN1doS0KeT+m9GEGKkFndPAIAPWh54Ut6Z4Q+naE8Mvd9Tf0UBDxy" ..
	"4OsJbx8tU3td0m5S2JEscP/biblogvOtmkZsB/4zBKAgZ3s95E1eEH2t2p4rsaeVAQWtmvgwzXWZmYxfKR/2S2ViQJsxf7SRDFWW" ..
	"+LAp6yw65YIzsrY8K8B9sM86upwqBrUW0TKt5cXnDrtvffXdUUjSK/9Ne1Gb2bT709fGpIW56j8hMJoQ2jJ9Wkpo9XG0WpmxelNW" ..
	"DjVhZbTlNU1rO7bv8LWrUNX+v1WjVYhpItxCwhbBe0xu7z+TMCwSouUD6MPf4+y1IDitNuAgfNFweDu0XX5DIbkgZZRiMMxeicQf" ..
	"+V+ZuN3BW9Aw18iiPwVHOH2wk3gyCi00XhAtfb+mrfJl7N84lwkQH47IoRnr7YXykiCJjRLkX4RE4AHgs392rU2jZ7dBb1Y2ZQPk" ..
	"ghADJm7D9zgp9jkUl/5Ycn+FJgcSUWeMr44nxuiX0VRSfS7jHARKjFSwc+AdBn4YzgPMrVDtENgAh6ymaoSSyWoEteqOW6edErf8" ..
	"43eeprpHswLTzEXZhwN2WRElDiZTqyXju3jRNhqK9PmtlJ2XQUjxcWkwCkBxtJVQyO280XWC2VsLx3BTq71vVeUC+KtIDWLqNr7D" ..
	"R/hjbX/cLsvYVyw5VJpV9ddPDP4NRzR0UWN9garOlD0HvPKvLOM8MfYu22Adt8itpz5RtNcI/rbohnym8VJwsaNEF0F4IwCJ6a1P" ..
	"0Me2TuBwj1qXJUa3CiGkhIW0chqa1lnaTlyeot3/u+jZ3AtWqI+qq0HLfr1FDnbtGFKeccLn2PpRtczgF//DLOKT8gpbsBglPhxx" ..
	"mHwgP74A0+AyjKSdw6qEA4D4xg8XC2aluAee8iSWzcpzPTEhR/l9I1MDxnaIdWGgVuI8+oCc3dk+sfMwViHlv99/IlNA884CsSKC" ..
	"5EqMblaxyq/vn+0IvMcH9PqwM/i6oUMQTYmNf5+2I9G/xFNNMXc7jQ7Qt7Y0Ox+GmUqcoWa2bULlEDbtoKpbWRoCwJJ0nhxwy6P9" ..
	"yCZfbSEYkK6KDQE7X2MVN5lO3a+RVJqyf/GB4s9L+QnDIT0b1XZH9tV9T2yhARHjg1SeZkuh7CHve+qU7GzLuEcTbPbjsSNEh5RJ" ..
	"F7rxqUeykzhH7NiREL6AoJVWkk1vhH0+fCTonkRt5o0bFD0wQDSmvaxhij4jQFz7tLZEtT+/Jb0Jd+5FTEpo1+tbY+Q5spc6DpFm" ..
	"VASrVho7bxatyBLr4/R73jFbS1/AuLxQT76g/1+xR5h2WSCEZqzyK0zNSBtNGltZlfsTtIiGaVEUcKK8o4iTOXcw0ZQcAqiRw3ZV" ..
	"Cf6cn4o9pFphWqn4YIFshLEk27blh2pUkLK3VaHoz4Z0aFnZEzn5qGG6PTmRK4S5eGEMf+P2m5drAytavV6e+0LDAfRHp+GHvr3j" ..
	"pShNU3WbQArHCvahtqzUcoIb3yfeX4PtN+/wM9U0+zBmqRC9ejWWQpqmlRTs5CXwUmUZiTtzlwbk4dtMGjK/nwDezsVRwXXHMeEP" ..
	"C4aISDBcu50vAyq7l8xSw1UJby+tzSpIRujmJ51bqj090T6znCb7FN0N+XTRNEpZwxh6LJHBC0rhGDi44lMp1pLYUb8pNQOu3KpT" ..
	"EUPmbKsHmmkd7FrCwOBfWZ9fu138jPCssDYkvpYGVhGt679Fr7OemRUcKWcslHsed2n19L2TkATZ8VlgfTXt+TLR6Ox7As4OJdDq" ..
	"W/3Fkhu7XJCQ5jYMbAKvpZf5HGTedS9e6uGzZB3rq5qK3Lc03eSU3ARXSF9UseXcDOlag4FwHd0SoROVmCBXdbXH1MhAcJbBW0gQ" ..
	"vzbDry4ODrctXr19Fqfezwwj6/LZPZLZ3YfuUtoG6OTZm4h65hncLvpsoYv4hgOMZmuRX6I91ClAR4sAW7iNkvSVqy5pO+eiTbLx" ..
	"CxF0QZVyj94+qwA3UUG+Um3mWv2GJKIHMn91dAWQHWpeu1wG9KXcuYotMRbuLVaBN17+Ssu9j6YMjsZ9YM2La42ijQYPKlyAElbU" ..
	"HznmLPGAZn9C/1uvNqjvOPqY8fXLrNBBvblstHHAS92iWy6Tage75GeQ5r5TPkaElJeZNwSwFFjGc+2I7D8T5Ig0Mn+8RUHz+xKX" ..
	"CSJbj9vMuyTkJPABCO2dUcXi/M+52c7ZgEgi/Cqf14jzLBerQJhsqPjMptP4lCxrOUNbkWFhOZgJ/bjiWXHaqpnifyjPf7KLh7k4" ..
	"duCEWzDmLXeqxtrLFcVlTMphhoRYFd0mVnxhc8p08Tu8FwvM9Gh0fKhGhSTwMbsnmLoIPhu4uizUV+Hu/qq7fUcowCSLcePwZiXK" ..
	"yAP6KVObqKuRpcR/N87h7J/yZXZme4/0oEwHgdHE/9+YMvOjo+EnKvlgQa+Ev++xGKB5SMkzqi90LhDFymWcWcDwd8eZjOaymnqT" ..
	"AuLyPQACWUzfGVnVeLfI6yE+nis03rPpSPZ8jzvCvcp98TtxSPy6wPQK5LiSR5eneCNkAoKOjV62HLdzylwNsMS5m6EJnqhj1AMP" ..
	"Im8dcu0ywh9T6iSWI85geIEx+qCspAug2u0YcdlFVyqfnYd8XhuYsNqS6SK29awEv7G3+lth5ak1LhLV4zj6+pHyrE9LRXxIlyOC" ..
	"r/tpgQtR1CvYFHLR/gyh97LZiS/CYFR7RgdujzmoHjO226JK9eYPzRVqgMkAgJP09sTvms9rBipP6PPqC+s6q1nU0lhDG0y141hP" ..
	"sMpAXbB4kefssL8bWMc+XxwVEUVAdvL/SlNh1Z1FsiGeasii+Qus65SnTc3G//2w7QV/XQs3p6zds7Zt3Ya/d/oYQEdL/eQFLCUK" ..
	"67LI44jPznFRfVgY90vN2cRUVGyYoTUMkuUFwrEuNE8HoCuEHJgSXC1et54Y0OD6nT7mKM0/WJ3dhYClRjAGC3pUkxvpffHfOQrb" ..
	"aIsApwYGfIeO+fQSvTBa4sqUZ5AG+roUlXaEavvDLR5TJUuf6UrNaTn6v6akMgCZ3cuCa2TEMjUAOBRdm2ThSPf2CmmemR5nZhCq" ..
	"XFndCbHVEa2lItfk3072+DONVwSwutWznjBBS1dvsDKB2c7GLUrWRKDwhk8kV/3S4vyJDcywZaB6GY6nv0Zhng9NQlIJkD5tD0c4" ..
	"IXWX6hDIDvR1vHvFMCc20r8zJhBlnFS4PytXu51YsFvcdoslX+Zp5PkuBWs5pWDoQhIgmhGgSH3fGFGOqtC7J0FmNgkN2mF4Xx5V" ..
	"y0f2bu5VxOP3SODNjmJn6JRlxVO21udR6lsamukGD3FDQOFPPGrpqTL60/x/I4MdxV6fb8YAZn9ihqbFaKW3C+G4OOyMpt78wkB+" ..
	"ib1nc0rZKOvqG/mWswz1ebCw4O/q0o2dKbM8O8qwTFXE2+Tov1H3IXBISdw8Z+yo2ZmkJwtSCavjbcPPgAaXqPvegMdk+4SbY6qk" ..
	"fwZF47mw8Q7MVs1sRsTQdssWaSo1M/jkh82MSksda0gi72la/43kCzGCJWlby/j4VqqZzXaLXmKk15s85oQOBmmO4sSfP0oLNf7I" ..
	"ocXeJCXj0cUgm7LM46oOCtODgBGEvfhYHl2CaLQrgeeZcZ/9q8fT+17z0RTG0RADDfuwAD8+IE/MNRmPMIa5kfbKUW+9UHMLmRUg" ..
	"rkkxJitraFn2S2EmZxe9j63RJIusSybyI9IY0AvsOFV/NSeanvqxse55iVN5ZNh8hjQVpI7vj03ZjdLHSswsWPWUI+f4G+BS8Dr6" ..
	"/W+9Ns4xhJBHLdy3MA633mDSsoN9Tjqgg9FDgyS8dO60rdcUqVR2MWwRkRNZWaCO3HR2tG2/tWSTo+Wfz310RJud34PxDRgDVuPp" ..
	"RIHmKyu4z0c+HD+kUTnlGDIjGK/WjhBp7pssbQq3HdPVCLqaGtWB/Pt3lCR+U6cDzAEkqxZN8wN7rku5k7m1ZCOH71pmqvdB3Qpu" ..
	"FCiChznC8gVothRkSCakuuGBpiDrX4iifkek+g0KZTmPzlL1nUVDJigMaQ2tBgbMlS8aJtSxL4M37ok4CRYkbGK5XdwsVIsgqoQU" ..
	"gRPbL0QAEfkaPu67+doyIMcscxC6XmyQvBY5g4Qamo0If5Nsc0bxGdP73ZNnadqxHU6IcP1IclBJXPL4DcyxjDV+UvZIJtQ6jqOD" ..
	"fmaqklbmZHArhLB99/usAHcUsudwoQP1a1TyWISouiO0VC9ZeYF1YJXElcrrg7R6P0Tnbc70Fso2HhH+FdNxeg1zrUqhvMzsj53H" ..
	"5a/c6mGTygFgIgXA3vk6Dld0hC4jfBm6agJ5d5ZAAWapF584bAVsdBk1LFHDLzaDrmC40Dk3Y0+2ddwFwz4GPSbWX8J7SsYKUu1o" ..
	"aBPqZUH4h//pfLeux9tO6Sus9IVVrIkM+F6HcafrygT+IKSDSvijWlZniR8ieh7C1nQDl7c4gw93gWvPIIu9Oq7adWVjgd5zXEXy" ..
	"h/MmFatQ7Ln8AmRKhgVZN/3wqR9BJ4B3TwZonm3IBYQm8TQ2tf7iepnfA810Qsv4Iax1jtcTe61gLvYtsyh/6Blf+ehHgNpMKDSA" ..
	"LvPGKiaqzf6yZwmKCk32DBLaDz7aPsz7xk8nq+Y9aV0WK+nZnuShpYhOlQ3BPFtp8NaVj5Om1nbCzYWeWC7IgUoyHipAsnkHHucS" ..
	"PuiPB9gkHgW7cCIT3qcL4pDEIMVukAVCEwk=" ..
	""

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
				if entry.exp ~= 0 and now > entry.exp then
					return false, "key het han"
				end
				pcall(fn)
				return true, "ok"
			end
		end
	end
	return false, "sai key"
end

local preset = getgenv().DQ_KEY
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
		else
			errLbl.Text = "Sai key! Hay thu lai."
		end
		tb.Text = ""
	end
end)

if not sg then
	print("[DQFarmLoader] Khong tao duoc GUI. Dat getgenv().DQ_KEY roi run lai.")
end
