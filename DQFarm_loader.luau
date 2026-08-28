--[[ DQFarm Loader ]]
-- Licensed to: GNURT (nhieu)
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

local DQ_ENV = (type(getgenv) == "function" and getgenv()) or _G
DQ_ENV.DQ_LOADER = true

local KEYS = {
	{ seed = 733339364, exp = 0, plan = 0, hwid = {} }
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
	"orV5N8KPwCwlgSb+b85POnZ6Td1Wd7kffpYuDOb8Ls6dEbxDoP+ZWQozKLo5G2s1L3mKWs9WDfkfFXH0Hj4nQhoqEua7D2PKJKPs" ..
	"fx/DyTFVwLYSG3MDxkwVPGFuNO9aApJtwoRYxVyAbEYw/pFtRjDe67kRXllnsqlTJFm1FfyzHgyLaYhhZGqaSBJN+o6VQOWkTLDI" ..
	"0iP+f0YhosTshBNi/8wzHmD4ceFtzHyG7rnwHmvBHjX4bvOUQ3DaqjMJns8QQgeoEqBEH/6iFqqKF9N8wbKtm/wbyyz6+IV9Imqv" ..
	"qDR4yJ4uO/n8BCKH3OGD/0wFby//KSWFxIDGdm+TFzeJLbNZPrt14dfxJtbmQwMw0KxNIBpAElrIzfX8Ga2Ybx4Bf18/9hj8Q0Jh" ..
	"JPY5gsoIMs9r10Ow35KJ4Hl7fkG25eGWVUBNxbgnS/vCRXlmLNFWaFVpIdHkDEUpJJbwjxWSdUsL+HdeOqw32M5SxEdmhOT825ch" ..
	"GCVPK3zfBr4B6TEuo27gFs/S+VjCozc0wcepjQPdIBXybzfkq67x40iG9PRdkz5n42eij9c5n0djwR8qLmZJz6DE9Aw7zRhWAky6" ..
	"u0hD2d++vy+7FloGqq8Fafgo6mkUuOQo3VhoN4ChqjwrDUAuJpR0Knq6kbuHNDs7V73/PYloExgukrSa8sMBCGCDhMPv7PVqDFvS" ..
	"sW0JNukAir2gxZOIxUdPPPie47Oh+Wk06twdhoSGs84/x4ZfVXtDjOc3xWoc7/O/lS6OLCz0MpxSP8DvkxUAKzKe5rGk1rGAxCft" ..
	"ZehknnfkfB3NDd1yQpUr90UpZoSMyTADTK/LkliVAONTVNskzpe5BFO/ZSIu1E+Js4p1pV05XT2oZ6bQN9hNUK3rcY9bXeSLVweH" ..
	"GpXXdHrOm+wtrcUdm459u30ijxD0DqW3L0MMinAorv3QsmFx6kVNSsgEfDn1u+Ch90rb13QOO29U1mh+AdQvmuTTlWeVh5a5ZPDN" ..
	"DQ1GCxPBT7IgbeNrC6vaFalldAUWmm7WIkz+6xtNL45iG45GO2M3SXjwVhdnIGlegVmJvqOCBlKBd178VWHr0t/YwIRXhylkwuk6" ..
	"QNPOfongmar1SGgdo2OItvBjG3xSXooFOpL3GLl5IAHlgC9I8vqVV0Cil1EUcE4eHOHsTS9kPNZyN4ceOJaaiOboFXI9wKnZMVg0" ..
	"PotCunB4m2pAjYCDdq9jIdCH116KEaxVE9j+YFYuBemzGfhcmb9s8hOcEtZCjFrOuvqPvSHw5SJYAHrps6xM8ePpsZcvNrrL1BIw" ..
	"G4OmoPNNS7HfZgm50IH61l2Hjy13JnCgGMbvmtlJ6ahxA8fVt7JQS1+F4pAaSzWlv06dj80JgO4Vuvlc+6Y5fb/MqzjeF+y/GaJH" ..
	"wL5PuEdAJU0ii08l0jkYR8I7nKcPjLZKImtKmxVF3o2gIVoTejyuXS5vmeKkLxLFJ6FTHK/KHenfTBV0Trw05Vhh91NAAv5m/TRF" ..
	"1C0um8Rw5nuhn4vQg+W/WFaSPst52rn5LC0XuISyh9PhWtCXx9vp3DYZ8JSViUeo0aagjDdbKxWs9WfhsIconWYht9Xf6BqywnXP" ..
	"dJBhkSqhEIEGCXqNkRwyMj8RfLZYd/qn7JgDZJ571Oagckj/vNMHs3JQD1dYCs6CxExVO85DEJmHUQ9x4jyZhFQI0wXl6QMB5cLo" ..
	"W04Vb+UJ+NW72KmPwWcnxGJTlFvVw6tPvNwczsZ7H3dIqtmKoeEbq7lB1Fu/ivrpmFFiBTnb6SsJPFyxfpta3Nyg6xOEsWZ84cPV" ..
	"ns+fS9aH9vmd0SNhF1e2wYUYuXWUk8n+9FJyJOo5ZuIwDou7KBEUQYtYUpjIJuTjy1np9XqdjzLkSXgkTPH+KY9GoB+0tE5lL9/2" ..
	"DmabDgc1fYhcT6PGuK2dwEEsVQ+iGVdCRsUfg350uwuNRvIFkxHNfJqUN8wV+D/NKS9cjvElS/T4ywqyBu7BRES7EWtoTdk4z8QP" ..
	"rh6CbbnoBDz/qJL0DtIQ7GlirKn1b9K09qJqNE0OeA5oP9ES/lruclH1aovScMwdPSAu3TDzafrPqAdAjSqtPt0h89UjR1FhOb7Q" ..
	"uxePZUJqTZoSrrIotCyqsuT64Y2Tij/WXhLZPHx7PbXtOOSf7I4iVUy4WLJWFr5QVt+wZQUt2rZ0ZW2L/KqnpNFr8Vg/qlWf8LO4" ..
	"r0WD7kTcYdKUFXrxDj1NSUkJpVNQ+CE6nZqBaB9MxEulv2t9fZE574cAtb8NpWDac5sLjAi8nK3iLjFHM+Uvju7my627RB79kja/" ..
	"xp/Yv5F1g1Ytt3iYy6uOJYzWilBqiAWA/5XI4/zuGGzxKjB4tSYDRmc/ZpOtI4vaxde2u1+9v/vySztTSyaQy/11vcnoZ5JvS5yt" ..
	"mG5aNlPJb2lFbJovHGwRNB8qH9kYBONItqWuJj0/a+9B/BY9+QbuYOkNnNqAKH/V/1RMNsM7W5pCJbxAMtBPIrb4/PLhb1F0OTnL" ..
	"iMCh8sCvDxXc4o2QKqsdA3PXqDyzHUKybvgEmBFsNu/mZGNUXoIOnPAWfm56OVG0voeBTHDUdw35CIa/ZgSqF4vGHwf+1bVTWUAY" ..
	"MpgWd9P0ZBAlves9CsLkcWPMXrC3x4W4KAEjholIVydgdBQ35Wlx4icxEtxH1A1/BMioRS1xnFavqiT+afzIgzzr+DNrBZ0si/NM" ..
	"VQiqK9hqBs/bnN5zYFKyGdLdU/dn/HStFpKLWpFudr+j3up7aOgtXI1OEDX9Z7ITWIbM4glCTsx7RuSanBw3lLr/01K1yGSn4Icr" ..
	"+JrQ9RniF5oGYLBQ8hAFOCWQ8xuJw+gss/92nvS9+Df5tN43ZpMKrWp90K8tnnbkX1XTYNKZMvveW2Co2xXOJbK766pctjxb+Y+T" ..
	"n1HJhjmesKqWNYsQ3aAH/vGIN0teuExYrqGTsc3lnUnOrt+z/V9Sq43RXZIvuVB53SDhwJU+D8KVaYRN0+/qNo9Ox1B5axsGhDQ+" ..
	"zOFDRNG0AN4Q8S7nFjc3O63gZ+8pBNFOVTCtJF05l0oBpIH4uNSFYc2B2Xa62/yZTNW+mZu5P2eIISRWmdFTNMuIKRu/90dO123r" ..
	"mmyMD9Djfh43LXMfIIwX1xuZOll4UgyZtVhR5MTYdRqr99DHZbosKqNVDThGb+rsSmRP67fJgeBo/+My0GMF4FFCnPaF9q9puTwJ" ..
	"266h++V2JMe+Yby2cFO2Z9JSJdIGgjJs/ffvnyyqKisPA0z1M2Crwm4LpjJ/VNl3itmkT8t2eKEkd+ogEOo2t+HXCdD2LAam9yMj" ..
	"Ln2qEc+1gS8qaDgtfpYOFMEjuD7C71bVp5e8+cwTA+IVHKnXsTwlC5AhaK/WwH+FH2DTjaXM53o38N2V17YoKb8slVa8Ed+5qDnW" ..
	"uvW0qQ57tHkgk+e6kwSFuTKDcr/6dvcqG6f3+NE1GpJwAR9fW8qv7+PvBtVJwGKPM50Ys776EZS6XQANHn2x8r/1i0uLeVlArMkV" ..
	"W5HYXCb7IzODWvZi7zqXqwyEc0zWOEhLdDlgzXfVA7s+OCL95ao55vbSbCMsIJtTEtPuZbURZEJod1tRpOYb76D427RcxslNhCnC" ..
	"XqmxhsDu+SAXxS/M9/zks/OsQagweSHy9n1D3i+x1KU1ahE7uhd2NavN89Tj3Su1UHao25NgCfH9fXrOa7vPcf7QrwXW0SSbGQxB" ..
	"ubLtDzvT3CkQglBGbL7iSBBzvf3I6AvOc2LSBdLdzDMt5+W09ymLLuXIOKgvFluUv0nAh2WM6x7D53/9l9ogUH6arHrV1GTfaNb8" ..
	"N/BEXpv15olcnGqgsgmZsDmcS8a2zhBQtQAvJms0zTotWfRadCEi8ERW2GKouviIIlcpnfkOJWo8RFL54P1qTH/1uy/6gHA1IC3h" ..
	"tW1RPv8+zHRfU+jjCpCefeeCKoQ44qCJC2H7r1uX7w9Mn6JqpWr7Cb7cT44f/Np/c2InLUufvFJarloeNynpgF+9neD2e8xOPFn5" ..
	"FQUl6XxljGfNzlgyYhW3Bi0kdS+ox0tGsgoJqfywAyz5ctvqLbX3XZTbRDVfW8pHw8gC5DM6CCOZjfhHHg2SFXVynl7WSAVfrH7t" ..
	"NGDKC0aaMRiBuTbqelf1wEpwoY+lXeMiQkvqkPDXsc1Jr1B0sqxkcJhmUc2Z0VWRcS63Rswg39uys1Elpp1EMO/VlTyI3UHKfyQ1" ..
	"If4C1r4An7PFiz/ytTf/W6xEbtQXkpBpWAevOSJWqzGyUW2SMJow+wjUvB3RQusSgwxvrJFlxZ2YM0yaEhfG6o1q5svp0s/bALPA" ..
	"K7WpuSELXVYI6lG600CNNpuHIKyDjQtIehhAHz9RhB4DqLhFCmm+bmc+vFdvAXBHHahJTY0XixVydAIzuXBSZdl/OYZECwlYy/IZ" ..
	"cd26aUZE0HYWMaNtLtjLOsncgNnvdraYQzFZ7WB6Z5Qonv7dBsAkP9Wzv5N95eb812ah+hLRi0zdiYIuJgbBf10q2RVaP83q9m4V" ..
	"B0LlT9CTix035bLlJu+gB+GlKj/f6xypsJwUgvZ7Plk1aYEqsYfZ5lPEUKB2YZxk0Q134R18Jd+tgdCnDF4VZz3J9eSUbD9Ynfj0" ..
	"26AB9bxYs4A0kCaHNn2sSid1oLrSLTtV8PCVHgt2jajwqK2cvqznJ6L7i5YyL5X9XQx7GD/o8pi7nDYQDYLuDjrtHA7J60xAdgaW" ..
	"d0XUYNE04UxiUmgzC7mwTJvq5NuZD5W6B/D0SffSH14P5L3em8+uXEH7hR0TQniFaA5KKyLTI0VLnkDWqWVozSIGDqgEPKdhhDjr" ..
	"2MfAre+Emo532E7Zj4sRw9ohiFwBFiqaLReNYxgWhLv0kSOkaSOzDQ0W0c7x37nTjkn2IMES9gnDcWzcFAEQN1e2YjOzyWSD+2EO" ..
	"E09Izj2eLovaZACGF9SlWPGE79YrlwYfkCh93u6BIC/CzgjAyvngx0PsN7tyXFXGmUQv5jbKZgsKZbUJnBLfk1hzMdeLVHrnO8bg" ..
	"vBRu7qDjeIAqEOSdpaqhWwJuPwFVtb/yhmci4AIW8HuyOBQzwGyZNVQBELLyj6nyh3uqAIPp2cd/CgHC+dTZ/bQBAEouqf06BJcS" ..
	"xgzQuKbiiq7buO8et9M5ZSskFd6xRkDwtSHbMkuOSZf8BIxGVmIaCXTfwZeu6157DZILKeEtIP9rR0d00gvKBRNvk7GnkY0AjTf4" ..
	"tXc80B7JlSRzTDojeyyEMix7LmueoV2fCrRnFiALRyq8H757zI/eTp2CibsVNfJPYwRsYWs8e2AmIbg007vdsxfIgYR5OxpXtODO" ..
	"Q934p4WPVSF1devdyxTQIGTOWouVdDkNIhwnpnFIllMNJoxFh+ns05QGB3KiT7OaMsCB4A8fZU103U+Ojw4BCyECMMhgHa8CdmZm" ..
	"gO3641c5/ShFWP4O3Cf30XbRPe/hF59MsWjsLYYKFRqAXfw8KB8AQYZvJbjo0bM/O1hyUzmAUzlka7214O8exfCtBwYFjBL1YA0O" ..
	"az85QQjGXpIKM+QcljRpD+S48aJMgsH3hdt+sOEGP/99jCiRDhVmHG/0JQkhT7BDO3TIcnxyEB/Kj6lzKqHl/90pMA/nYr3aUW/z" ..
	"F3SiCb863B1NaPw9cAnkJHFmDinPmy19NJuQADQ+1tRWz65tJnmLxIZEdKWqP9Z2wHqlbz/QBUpVQqJ+IX7bsCSR1dkTumZP3Y2x" ..
	"MZZkktbQwUJPX3X2gIovtJuSAexHVc4J1VoTdjQVIEpp5Yfw+NxkXzUy3kt51Idc86K7lo/2bFcJHNFgyaNlTXaedJk0066khgW/" ..
	"9qcLZFk3uS39ITUOqlSan53uPyY16iGzcwJ5CdSeYcUodfcWf1yIjDEAQ3VD82cj2eEvIxrS/OHZR/ha0hs1XKJwFaHCAZc82Bbm" ..
	"B6hAF/ZsmdMvJVHIOiabS3xZOZb4kE/+ub1rQS11+3+xoZIrBPoQaLvFW8p010MFyRAvLN0eKR4ytcoCszvE0+CB83QriOmMP3q9" ..
	""
local PAYLOAD_P2 =
	"OcSBZGGTFJ7zEUeMwe/NO6MtDd8eDb/AtTsvC/ogsut858c8z7mGKOIxSUwSIwXtCxXKOQlNZDUS/GnWOfgPCpLVCMGocwYxM3vW" ..
	"2YmuS0QekxfLFiPz/IHo72lH/JWN6gHZHlngrokCyYIBZq2KxitYokemyX6t+NBwzSf92xwnD1YQlhEYNNcOAXa7wH0gsEhhy6aI" ..
	"Tz1EUqzmGOJ6/NJQptYi5teLKfXyod20nUS/6ELiiLImTV8c7lHcUlk1N6i4Nu66DsueQCiJAFMsgf6kHBcmJ1WZpmw8Ab91nTB/" ..
	"MFSDmCbYTR32TkKycMqVZ/9RhJLc/16MeNygQiobcB2mlhbnEiXCsZzNq+XJEDhzePsAGNbL3X+bdrUl4bjT6Tc5c0sf4RskLCNU" ..
	"MjF8b0oRahMGQjEEJGmFsRhUzL8qdjtyXuK/VniI9KBE37ymnUDBbHT5uqJX7RvB2T6neVxfhc/yfFawSYNNVDIu9U3ya9bGf8q1" ..
	"TKIaqIpuLVdf9XCXDlzZZPNVhx0rspifQEdOPgDLYS4w5PM67X9f6U1KMko4geiWg69uBMzdziuKav8AHLQQ1arbMJ3KgeWYqAUE" ..
	"cXOK736jeBZmdixkgpKxS+lY2DR+hoSktpjNgAR/CvPxPvrRpoDXREDzrFacPzghF7lbxk2CZfb35uSORCQ/Tyu3tIXgaCym56X0" ..
	"ssssdTL6Ln/wZwclDYa+W7BZAuyeGbnEaoFnaPi5BFUx7GGhu4D3sLj0zjoc8b5VzvNltn3XdfZuRojK4EZj2X1bSs1h75Ka+ule" ..
	"OR3+zjxGqLoU8co8iB/dHwDV6GsQgGq95NCb7LH97OMyGmYxA4Jr/Xn7cMMvaZ5ZB5WUQ63cRezFjUKnz8odaQp+seaho3gkqqao" ..
	"IVOjx2+NWS5m1c0wBVx8++7pXeMpEG+tOiMSCH2Jra9UUf1PwudOitC7G3W6ZxPOUFnSGwTtGm0/zjJZizYNOxwglE9qIUEM0mhY" ..
	"WNN+Da8es+pDHjQDZchn2AAKKyqIjwK1JwdSdV3IC2Iz1o3PBEuP4F3u63DSqRNLwjgPGJZPiFmDzSt0NYwxktZIHnPPBcdok7VH" ..
	"4BgxOWqycDZ7rA0jUAtofcRLXQMWHQpOW9I+4UUPBwMakpjQnn5ciFA4yPdpyr0kD7ijkMrUTk2c/BYrDfxqZXCvMEZIGk/RO+CN" ..
	"zBWEPEw99XNjKjlaNNOtqSQWps5/a59EpBUykvBTwf1Ab8LrmUdh6nMCY6t1Q4YADllYuIz6M58J++PPafxIWgsyWHi8gRTZWxdQ" ..
	"vzpXLeuqBk3av25GYkPwqEwIYuoV+rIk/NwzCVpMjyVGejBZXmkaYHg0NWBE7e8uqSnLN2wi6GrXvR+jnpUbMzyATbi8BdWDSsoL" ..
	"lHfPmuYzoUpzoUY2d8aMOtYutMlONwS3ryWpffvxW+th5RLEfNpckqf6QxaLjcV8y/sZZf4cSWZ9T/AlMxLeO0YhXZGnatlie5tZ" ..
	"G/FL29sUre5t9O9f/ntUDMuC92kwVloGYymX5Zgig4RKyGyTyKQ4tBULd4b4i0sF123bkD+7F9EXi9x1w71XP4A9hK++B863noPm" ..
	"dj2jJ1HwygtFfXl65vQGC/Rk2clmb+T/995vJb+PFFeCYbaH0hTMSvnoCBsFNT52A1NkkxmqnU7A1A0cR8MfL6TS2tBYXGokK9MJ" ..
	"tXLRk8mL0nlEGrO8BKKP4BOC6UBJC5wkBvgwzg2tePs4WjI6T8JZOE4x0OVMPahTYKGsHAhnlxhiqWD3g+UXuuKQ+aA6jGUv7yQ/" ..
	"hi3tCp+WbjJjgfcSiY4BRvH8/6FGMIWcrmf+EGKL4lvZ7265UXNE/p+DT4i+aYdxmsF6KEnUncyA/WqIQeTtKILzzUGcUXbcbm12" ..
	"ZqgJXSOv3ATJp4igTMxYZNOMKd4O17rgV5ldzLQrDhqXJnLOtFiy/qkhTImVWk9D82Rx6UzCKG0D464LuI6Rsj5x4Z1dTrJrwyyx" ..
	"tzaP+rkQz3tKbla6zqdc+0RkyGzCZtIz4IFw8EWzgyXbVFcPSNXi50oS+URv/dHybq72T7DOSuZPuEKednZ6Fgg4GdM8ta2b9EXd" ..
	"sJEIWb+swSj2DteUxcc5mfJR0xii4pUzx0mUMa2bANQwcm8e2XTMurQcWhRVF1rzPmXMsAjlSvCw/7EZZ0DrOvm6BRe1ksXVUTcm" ..
	"cVN0s5XYN3LCL+HLcavLXcNIYUIdRuF91xw4QfNQ5Lu92Xrm5N2Jy2X5ZMMm/kokOFNOKYgFMoRPKqRQRcMyMnW7wm6u32GnsUDU" ..
	"UeTXpgMD/QQ25lWEA+7vlXlhBPRdyue1gVyat0wO51Zr1EYjEYnzENWGavGVZf7paiq2/+0mkPqdapofCRbndYYMF4idvbzKjZn2" ..
	"p8RirnbAgQFmPRhXzw0VQl9h0WS97pzjjvAX4T3yzgWSq1hAdEt93PECx6ELitYTCKvY5l0Zm0Cf8qXoHdevzEgioCnbUBvW7eaq" ..
	"H8s9ZJtEa2KSDpGhwRWovSD2uwiLW3AQq8PzX0PMDwORoyfgwQ4AgCe+I/E9XTGadsKGMQ0ABGfCllBBh3WWPM5zHpQyiMV53yFD" ..
	"SpuF8r8zgiiXfjOQr9/p5TFpFXVbaNitERMw4af0bvK5vbdacELoLMyMD+piZUP0KvEUpOAJMpMFeOED9OC/lYwQwBI7uIdRarzm" ..
	"i6oP4cxPPKPfo25V5iN88ovjoog/C5SbtCq69ssV1S9d83owEYcgo4ekRDN8HeFniVtVIpf5LjyfmF+KHDu29WGnBxi4jYJ5U38a" ..
	"c7UgBp+uQ1Lyv76p2OjHLTjMRnzGptIhDobuPzcpRV2MrkAfIO+zkebWl3X7J0nGIoT+vJKh31sc/R/+9rg6xkJdkhKO94sHZfZv" ..
	"fB4yhc1lUsP/T7tWJh9r5ZGdwRm49Wij9kk771KhrbDKwiXtHZs5xIGZoAhfzt4aDCVrMrkvVajpU3R9Sq6GHSFd9MUEh5Doe+NK" ..
	"xXL3DsQu9+JILIgiYedTk+43gUJPBEZKJUZLIyBz0KtfgT/AVB1Q2CnCaQ4ICvJBi1ccYf0d5OFX+7FLXefXdvKrOK/kHimtHpp8" ..
	"I+A5jSbQmbwlCtdcnZZpEgqSg6cEfvYAALSyNIv8jNNxIM6tSMoTGSXrp+YKgYwxmUKO3hEH55HQ7QnYAT3SnDm9LgAMVXRO8yoe" ..
	"GoTsfvMoIxQRm42Uh6C8co5ASWxC96OYVGrCG1yaU8/h/2icJMQx+I4NPajV76j7HTyAR01dE/iZtZPhj5CKPQBgp/HJuMSre6BA" ..
	"KlKMA9wW6wXPUPWLoUEqmodA280fWLNrQAKpeAotj00LPGeq+0JK0opYYPkj/eF3s740M2TUql1frTJtrbZI8c8fOHXPYVPrvU2h" ..
	"kxL3zEGQEYahntFokEc+jflxuiljNfLiVfVPzkgHjcQmEsYXo03InuUyQ4Tc4uk56MmOBmYECdRTrNc1LK8A2meNNxzgy6bNjDMn" ..
	"TEOOpeYc6kuGC1n4j3gspq2Jsma25IGxrsIJ5kTADNNFcf/SkGyUAodzXhxDG1+O37Zj1VI8KldRb+1/bFj49He/sy1IUZgCw79A" ..
	"AyPaxXP/wBL00y2o8dzI6L+bJ6wQe+ZoeVJoo3vH4cxhZPjf7aMTGlyIa9jMqZU4QQ1Ff7mjFbexDiQp4N0J+R9jhuz+Kso+fJlO" ..
	"rAZfMR8WFFF+QIWtgEqDhQyIHsfu9CqW0JuCwInZjXWUoSlRE2ulDjVXQfElQJCZqpPRsFx7F52j3ZKlAl0e5dmt5jeo18q/UStQ" ..
	"OUN+HEKlr7lL1QF3PSg2VElcEc9Tlq9e8VowcAqgRRVIR/0fej2gNEP0r+dNqEkjN0dRtUtUdv14FLqkOblsBvAsdhI4Xhr7WKtV" ..
	"ZgM1/3pt6p1lN+QBW1FqftpaatSIWupnH0rCZ8KLHsTMYGPc9SHepEmkNVlJ/SNlpjuL2/iMd3QH1JVjqOhJO/EbN5J+O7DhJ9LX" ..
	"Wbsuugqqfva96DBgWIa3R5hBqt+j2F6jbImDHKIFasURyG9MHb+gtRyY7pnkj3l07f/+wij+rZQrvLxEwl/Q3CR0z5QW7hQZAmGg" ..
	"kSe14j1Mo++sWTwdP2Tct8g61MuxO+0ToJRImzV1kYTxhQzCmiRqVNvu1blM7GjHWDrX7hv21teEDKD+InoTt3LVcM2AcF0toNiU" ..
	"3Ex9alPIuSBuYZOdocZf5TlPJYoy/diLyw+OBqDjzk3IrsDt2dSZUtmFHhD5Wvc+k0WwBSG7ahwyX7B+v7uknSMPce600H9jkAyc" ..
	"5JGA4fB+hDRt6BSjd+ftdFRnoETzbi+RZGbU2Spuu85i9Di/efyMnGJVwrZl10f4yxKFTykbxZXu+vk6HH90j5rwMqOu+0CMELbe" ..
	"jMTvwEMyhSTOgt996UwmT6p89HDUvi86qn18ymLhCudBc7yfTFE1ermuEZda5ObyO7secwnJaQJnLLe5CiOH+etG/QIBwgUv0ImE" ..
	"YWE9Mbc8IcP7yl+Q4o4A+H19T29tEi0pVjq69rEPMrdiVzBPH1w95zzq3RYKfQew9F8waa0a4hLww9mNVRCO0oNGtEcEqDbAVgOY" ..
	"XtcNbI+UjZdXyF/DbflqY5JC59gR28O7eiYK5tZ0WE2o5E7lgsVw1mrdTJ/9wf2TLLBTFgNA/k4Z9TBkjytOHY076LJt7v7v1+Jw" ..
	"r0DYlzGgc978wo+dAqeO6wSfJvUaEZs65NzzdMNbMF0TqlPVZlEirpLy9sY/pB8nLf87Ms6ntHrqeyMisaKlYCdES6LNbcdjseOL" ..
	"V+J2SE0UREkUa1h3Y3D7F2g7H6LBBZ6K66Hx+a8FQx32JkQ9yRIUX+uX7KD75Y/J63ZtgVP2j88l3p/m3KR41FBJxtcU844sg6Qw" ..
	"EFH93JCvsHTkPHweb8MpkX93lPBZLPLiUKalcz6YAfgYfLwIzBryO3SfVwJghgNtmXbStM7cOyecJfZlrDvUYln56NxrWYxpZRXL" ..
	"YOxhgmvwJtDiiMozjx9bHsqAE+/hUqMvSJZbKAhzhOYT7nc1dJSHOhUQDM0ZwNsv+FWK9o4yG4G1n7VX2Z7pGPXa0H4B9GUHJaif" ..
	"ez3dCFwa8bVaYp1IHUFMeiIMlzFDqhyUbCiyskRqnz7uEYDGAhHeHuaz+pgNSXqG+gecx3Qpd4PjDp6mnjjeCzTMZvqv1W+L/7nU" ..
	"fZv6FERug3W0bX3ESCG2L7OX1ZKdgIES2ChX6Q2ryAT8nfRKjmOg6z7EDzj0oE5lFZQ7UDrdP4ckbAUJmnJvEpjSe78awB9j44mF" ..
	"ijB+gW60kjp+Vqg/1V8fB+3j8Fyb1Hwk4o1J2ieU5WNuyxP14F6Itlus98v8pxfLTGkMmGuC6HQyWR9YJiLmVfHYbcYBhWZPxuON" ..
	"y7kMqC+x7EthfhF67GXvnD1AOG/Vct2vgst6E/EsmFbbXr49RoSHUubHM8ngvCzTwYxVJQksCTTRDoyJegQ+uYJyr3cGCEy1eY9C" ..
	"hKr2uFSD1Eo0CpoOTEvr4nxi4rmFxsi4DZVoPyXNQNI3Kh5Iqbw7q/ZE5Uxrz5Z/slMjKYeLqb3yy4WDzcFx2uk9CdoGUdFatgRq" ..
	"qnYqEOWGadZtXIuPF5kOaaBpwbtmls+oq22m9pszd8s1iQ2E/ITE0PokxHl2jsD+nPfNYw43fZRnbW0ibvztC8xnFVGl/pOJ94YZ" ..
	"T1++eeEwGyWLVGOK5t2YqmKM+y0X0W4JSrrtd9ny3bH9stlKuFrisKE59OzV1KtWM4c1Amms7cxta4sMiBMUys+PpsVZzOVvu+3k" ..
	"dSubVPNqufRAhU7j8IqWm5qF8i7vlm5NDIGbDP3k8MFDd1NnzdnP/VmsVIbJKNHXWi+ZRYpIsAcdQGLjmoJ6+CPPmfa38NERxTUi" ..
	"wRoufCaBO8TUk4S6o5k2yQSBbVLtgqzTkfEUUS3ujpNuf9YZ3ZKpYy1TS7Wn5dav4LwYhscHhVR/6ok6YTleSS7dnEmnSjjF2TTQ" ..
	""
local PAYLOAD_P3 =
	"zYrWQyBeYI6QyEo+TAUzt+lU0mPD9WSYgOMgMm4/GoZwy2N4rSMiwdP7R+p/Ez2Lo9OI/BHpEk6fnTWxcritBHSmQft3R5YJjbTI" ..
	"oUZysf7S4361+FFHdMjpUKUHIpVAvRBH0FtlFBrPjIslmxwPk07AO/dKWay3rjEr6p4mjoK2FPjOvSzxC0KpwJGrBUCRZixPvTP1" ..
	"no6pmQpf3tvIYzvcU/cDS5eJoMG736SZg/eY5qf+RgjSJ14APhMXDvmJi39/R7sa41c3HZnY2DOHE6zmL+/sKv/OlbUcuupkGjZ3" ..
	"nKI+52XQSudjtcqZFCUWFsu1VHjNHVE7Ld2+usZgjVk+xSwsC+sTb7rhbO11QKVC88fK58lnpAcOP7mzIY6JeWV1iPL+tOBhqTfD" ..
	"WrCZu8qV3lp0dpXWJtgvxjE3YtYnq/42RW+gHnuJN1svc/H2ZP4ECqf547L3MKvcSy4vNrqNR41QCnaOB2JbNdMZGD310TgZVS17" ..
	"6kUqP2kyChtMB5X2AYyQAxkPkO33OS6F9YKkzyL7jdWpUCMVgnQf3BqxAmm8UmjJRIFeVIGsAMqgP5/MAxZB1ypreoohNSmLVVay" ..
	"OOJaIy4e7BfpVaqn+C9D/uZ6jRXB4JXwWrJIu4VMPPvTd+VxONMnewunEgAFdn03O/crPkO7/jOShD9oJ7mH5SRHArMoY4kQHRe+" ..
	"qmn98PHMMYclwZ8pBHxaluJmRLQpbUFTCws7MK3v23dX49wVrmTu3Tmye9at63B94612r9rXsoE86FEXE30upiuBosSXAT8jQRZ2" ..
	"vygeVoAGBMXJ9YhJOikq1L3qOVQv6XCiRHRh22PZg/jDwPV7VegPEotMbuP1cUWVGUQZSAE/JK8atPZYNk3UjEdgPSBBvZNAIDq3" ..
	"sHpLRSt7vyTU4ogKjUMuIf90uISQ6RZoJB3xwwoMRQLNBJewT6NFdI8iAPUKBDBkEN6zOXEehwWLkaLCIR9AW4MUjP4ma0yUbQfj" ..
	"z01z+zggmGjgNm4AhB5Qhs+KGKSYKfvQ7e6N+XAIyCQ5kpPDgrugKq9ebPayJtfVkxmAaIhH5iVKXJSYVhZmaMA7D4+UAHMK901n" ..
	"ApvjSU1hTMNaVias5CXSZym/6GaELwD8uQLk1zM4chcWSctkumFAScriazoCNEvBFpQ0l9dvhbBwEnInwC4DHrUnuKh7B8he6iYH" ..
	"etr/dwbiSOnvzIuV8MB/ttlQnpdKTnJwV8J9FM8mwAICufOvoC3Gl5OHBnZ4VBRT7mc4sgj77I6JUvQk1pqm2jctkToXlZHuIrTi" ..
	"kLVJx9pFCmk5mXYSAz7MDrPxNlE5jlfViXvqYSJAdA+W9G4hAiw2fHJeNLo+WwtNK3SBobi4+vjT3Zuxv0Ap8qIMFVTVTui8SgMN" ..
	"zkR00hIHWfJcVb16E2XORKXcMvPq87F2dzewcIh1IM05+WPSA6y2UZ5J0N9gpm+qJA5idXGM6++ev2J8ARBhIuTtk/qucD+sbb/g" ..
	"3/HK2CNzumHQZisDRhdPtZRg2UpR0TYkURNg+DK9HVT2/0a6UGUMjNNpzmUOxBcrzit+lgB8911QLj/I2bcGR0kqKABXbMgVp5hw" ..
	"YmO3XvITzi0oSmN9Cep2SRhxZtzXcM9owFefzUJpAeXV+BLRhuiwxq+tO3vT/OHZXoHrrD2cmm+Nc+4857txHqfq3CfBGCrht4p2" ..
	"gpHPIixAqADDANGUH8Z699qZdmEvnODrAQvg+AN1zwymCmUH2TJ2HGXlKeHWgTT6ZdqruzWLcKuAougVIJ1mDs5shPpJF5WWhMFN" ..
	"Cwtl14bqgQ05NUm7IzC9gTfddsj4YCny/cU2ck5jh1XCMRn/CL/fTbQzgzTo4TXfEK1OVmc3bJ9b+NEgiJmMaN1VaUwoyRBV9haY" ..
	"m3QCWH5fmN+TjNKVDl0wjXoi5ONMf2BjBhaMcgibJW/Ey2VzCZ1afdcBokUTxqJKynsIYnc1aagCQWkb9y4EVfnvoSUyjFvG4DYn" ..
	"MqQZ/TVIbwvi5sl1MbVsSP+Kv7sCJh1cQBEAJGqziEUTOziAeBly3o290dxhfmDBld2CLtreAzWY5iyHx6JayPUlKSgk6Uxil5UU" ..
	"5fOsKrIPwnFyAKnJ51B32HaMMbZLavFgZ6BsK3h0ztXNNxmYv79oa/k4BAu7S4SnmFK/9kL9HngloUkWqDb/sHbMFxT1SjtVVwdZ" ..
	"TTWEV4k3HpW/XOXGQpPZIlOMEiIYBk6LdndIY3jZKGxnNqAvcRNQScISbvKcPhZIMdaRrfUIzZwIhKvfJstdR/pjz3za8PEhh4TN" ..
	"IO85oIM9R3GvJHYn5NWo+OX9/2EWDcY7eWHJEdxbE+cZnSbuS/P62djGCBuz7fOHT0IFxuZEAAUSDSguPvnvUpV9Yd7YFRgQIPpx" ..
	"dDddmy6Ip/csWCx3lDnDHSuSXpI+sVzzzXj6fLa3TMosOu0LBlRG9mqWP0vyxR4UDzB7635B9cPwfEQMxDgVTwmprpXUfSugwOmy" ..
	"JH98qb3YDusTai36QCvXnf4EJ24k5PgjB3DkcZnK1DrNrdcGw++oJOztY3xhNgZ9/xzqzrk+dm17XURgZ2DyXNIsbN+HmWn9mJPv" ..
	"MqFWRdPhFHKm1sJ0hVWywLD5FKWbozOsUwYrPPpz6ibxkfMPpq6tr8m3/ofnFNfaJdBpfWm1RskUrdf7TlO+Z0wa3LfAEkIBnoQ0" ..
	"qofE+7DkZ8i4xkyl4nqGrQPAsXArncuM2Nftl+EmWk5T7RqkqFhUd5ZJBekceYY0yIkx2+X3hNTBL9KQyrxqP65SrN1NW3zK4Gh0" ..
	"qLZuAiEBNI7BmY6CX3LaAHu0gnphkB7+JpW3T5L0jVZZ/9TQ9NV9g3CsgcwbP8i5stkE2JySpi8lUEzcx/qlDf/cdEK1I1JQQCWo" ..
	"pGGsKKns/2wYG6ZEoEBmAdf5vDQ6oAfqG9gQ33JpzCkFBHxLZzbRBfZZjb7w5u6dyOTJk/yvigQuvSiSqmAVeQUVH1WGIabRrCNH" ..
	"mWyki4Q3zOfUHBZiqSRLodlWC+RqIzvd9o6DnHFIN9QlWbEAjd0YKoygQLIRMq5YH1RdB5wdGu3MMdx1Ngne9s3kvH7/rSVOW7Sf" ..
	"GafxjxIOm6sd3XHgXaVfN5QNBkesapEH21bVCjwRN0GNyo2DsaExMg2HcgS+mfhch0klPR/WQwSEJ56L6QoSCRLHnJ5qb4fFMIp5" ..
	"RNnL7v1QbmCkMHuo8KbevNfTxOvNo6Z1X3HpEX19rAPtVNqjH2mS479Y0i9cPJIU6Eyp3piHHyNwsqLxS//FXtLAfAXYnyYJZ4Cx" ..
	"UkjS7kJ7Iin3lTM/yv1U/dVvH0W0owfcBHXronBB95c2B318wNOayw8cBWkITYQ6hHPrYZ1ULobotm5QhX39FT8OrTq4UcyNQru1" ..
	"PjjupW6BOtNG8zO+FcNdqgpsRwqx0lJVzGDDRxyhI0ZxMzmLtev7nWCbaFGEn9cs8LJhFSQOUfZtSVZY1uxbxnp6xu7/lsUX93kt" ..
	"e/dw9VB/dDxxPG7iEgqsFLxipik7OoGk148geI1ZO5NBFwzIiFnbkr8cpXRntr/oC4JPWWZFpzzZga2Mbsqhiy0KzBgwsHrOCQPS" ..
	"d8IKYtNTpwVcx0rqNPRiyH3HPfsEiJtq/7iYs8wKgX4p44DaxFWKDEHVOWLNPRwHrXlWx/6hC74X+mQfxkqw/eHnYQ3PPCA5pgVy" ..
	"YR8mEs9iLdYdCDQLxCnBiIJ7EXW5hZ5wGBzJ95zjku8QEV1To185oUZOcErpv5Hh6e/L2RSI7B9Y99yZQsom1lXn8PCQ9zIiw6cx" ..
	"6lz0B8qAy1COh0v5+gwO6I/BcXdpsV33dLeRyBy9OwBkhpXZQeI+6pAibdQg44BkdGHHCcCWTIcPt1pB/PKZKGibeLWpUEGwTbMp" ..
	"FNcoqVnty63KsE1xK58jSwwk7S8NYH8SsWkW4Z7bDTSav+pntAbHzBE6SJLBCtdZ9n5EcnN8HLA1415Cxnc9b73QBjmaZl5tBgG8" ..
	"WpaLhOAAr6AEe1bnUEjO5+5qylp2prR+BU924NuthWKGsfkOEPkYAO0c+8+Y8jLrSoPWjRzVBYtCBHojQAvKFDcEgI4IB0RvokDt" ..
	"q1spiLrMekvf+NfaJ/mjqjxroHWC1LxxvyoBbWdmFJm4HJmovXsAfOsozWAhhw/VweGK+nCCz4KxxvznUdDdvBrGPs9MUa03VEqO" ..
	"bCzo/5zzExo6L1LgD06giJ2VRhMbib9jAF95vb9HHocIZyk0n06RqOXnLwfqNdvpEjUz0wS++1UbosMl/kbMJnLrV1/Y2GZ0OacI" ..
	"LM+c5vFm/upD4B+h3dgTJLF4rIgFGZ8GeCohbG8hSCpwQeng1JQaIb9RGq0BdBHWfQ97sjWGrNLqvUMKZa3kqZEMvfO+5vk39ux8" ..
	"C81RZ8M4DHW92OlhLc6NHmqU/tqJ7DacMbCOs3R3QufDNBdEREFGhIzul35Y0rBKGoF7LudE8dlynFWBKTXjda80xJGQ/U+Rvzw4" ..
	"0Oxfcsmm7EZBbn4QSElRWZo+fNVen72RxPZN3Kr69IAr2sYY2hEo6Dd27dccfXKBKjrVmq4OuB1SGXX9/zkyAzAkkrmtD99M8nlV" ..
	"iQjlMXgDJvpvj9Kk94llR4Ujas8JCRai6d7cMuxRnb+lc7AmaS/qwRUjWe688utmll1RMw7dadywBWVxVou7BVO8jgV0MYDIrBla" ..
	"l4YF/0RwtmPZlJ3UGdoUI9hCVdiHVWFgIB0SKtuF2JCzxf+x8Npd1Kga8oW7DXbfD1dABqUBA5JuhQ2pB6azdZSYkWpX2CKnhMOd" ..
	"CweJYlLNNbwdp65lulR5FIlWH+kneLiTC/B/RI2QEJU9M4Yie6op//207NL7vik2v6rzP1OblnDbCKBg3O1GcKqqcAhf9RpgJHc2" ..
	"jFmNY9tALbnl56g0RXlsnPKyKij6ICxOkhGUj5mqmxmNzNF3pcu0CHROpoYqT08EZfSMIm+Vvw05gN4pFaNE8u/K6l5G/kpa0aUZ" ..
	"obbwnM4yew29O/8D4rNN2xoNknosPiov8KOsR3ySJpDVJTBaA+LfZRrogK5GgJdc3JuRnOKaxqw+fjmI37j+kqyhLOO719RR5Itu" ..
	"KDaP2a4OChL0oj+Kt+gmno/KkL+L6IuLKRhQ/ngs/vvU/Gb47NhasKlV2FAXXzS9XfJ/ZZlRsK86EkujF7bvjWhZyM1aOge9eNvB" ..
	"pga0Qtixr71QXQda/Xwq3Wq70OGOaoyd8FOyr9qAHAztHWiDNrA6XPxF2XxO3Sut4SVzODQb+nympVOvNQuDSiM234TPcTFkSFN2" ..
	"HB/OfXvI5ASiVUBsSYX4E2BYnDtlInE7iYqdFgGxZNTM4CdnH/02fc9jcJ5QSaoNDjW6aA+QSfi5/aQx7GP3oCPeExiVs8KpO2eA" ..
	"fGRyvtBSXcmRPDItYxPn3bW+S2Ld3Ais956ildyC+QLbsDpQpmwDH4VMtRHP0pppzZi9wHdAJylfHzZsMQUEueCybefrCZ52ltJ9" ..
	"ksu31gP3UDX5QJK1XDMWTMwnD7wxQbswtu0PZ98Pxnxk4l3e9RZcyxKLiH5VyJytojXCY60bLVWAnacZAcyn9d2mCPICgo8zEKzh" ..
	"2q3y3OGkR602q5D8JKuQwFS3oDXUBDXpNdYIM3l4s+qmIoYrPE8J5HKiWZAXzwM/ONH0/CvMPwSnD0cOf+c73AZp0ayRsyMZVSYj" ..
	"WxU5dR+3Ia8Kb6Clf5BFvDjweKtUaWd4oK0q3Qawj1FG7HtC8adXYL5x+nEjF4r3s5JuRYdc3/q/+EWwhON+rzJyBFNX9WGGL6lh" ..
	"U+5OYpmuC2Yh7Ypk23xbiPcD2qX1ALYVoEIUifcZOUIYrFhTvHG6khPwh4AqKvjt1pi5SXinxxboemv4lnV/QjigM9R2PVGWgTbV" ..
	"q1m/ZavKgxXQn3cQzsX73eu6Ra/TtegN9FhNHtyJ3ffGOiSGJQFKLR0Mgphmi/nm9Uy0fIwXn23f1F/56cGnWcIWC6NaYOH8G/RP" ..
	""
local PAYLOAD_P4 =
	"o8BHAVHfl7YJXB2uMOADrzk3Jw3k+GsV+bg3ZZnkR/HH+67ueMEbU5sW7Ne/MCx8BrCORCZHNsP47/zwb1zo75PWuxzCJlcraWdA" ..
	"93YP3DUBgRNAd8/akmrDO0h5sO/OOY8zbtHWo79/mRVr9FLfkJEY9XHzcgMWTYARplXnzmZTWnRB1F4FF0Jqpi+tdM8vRo6VcxhO" ..
	"NMPeKDPzpPnUxp4raqmBmVuTOI/wY8DCkVS7ixYQ67LGlIxnOnCJHbKPGCwIt91Ky/C4h0LvfssHkxgt8sAiJ1qj9/AYGmOuqL63" ..
	"IxvU0cDPeRT6W3LIieHmUbPIrZOKU8Itp7d8ijE4WhmWqSbggBLfOz2Cz6zDBvX+O6oyzm0sn2ic5c8N0N60156lLg885Ab+zpIi" ..
	"/vLDY119rM78CBAaijWP2RvT84qD6S69sIpyB5uPj2q/9rblDAJXic7jQeSMM+CLkMNevMYH98/csmIWo2G7RO/CumTdAjQM5C4+" ..
	"5V+q3snN5AXJ9Zy8FaZkMH01/ral1siTkxA2JanzfCujJx5HlMi8j6pniuwm2bCqgqH2yDwicXVvCD1pxw50XekPxE/7V14MUp8j" ..
	"HFrgVgHraPkASWHfYlkjjAhgCCifxP6hui9diWI402qB5VPXahtWv4+5zB7plcOzKZhstJE+5CnL2Ug6/dnTMq/QxVhBQ/BCJJqv" ..
	"Q7Y7pGpIfSs+sV53cyQBJadzxAEEhaiEb9+FdJ36LQ3BecFq2Hc7wOZ0eMykVaOOmoEpEupEIRGL4b7M0YUV+sgDkv41/EfcYF7S" ..
	"81qztuY7aoAmrp5rT2p62YwZBASkF2jOK8UF2V5YveZOPLVcgCeB0doEk10n66f5oLQPbcmElEWVHDDt74qSjwT+y8x3BS1ahHRx" ..
	"Zw5oBSPNNDJp0KgKJYzvaezpsmBcbBfNWJmR41Gbfyl7/JR/uJAO2tA/yV70Os4MXGwysDud6UEbn2hPH8EtWLFn0/0yz4AIqctI" ..
	"v5bvLjDGmAhU+igQhMW7uBbnWsksHfXwHLedAxqXeXqYPuEowJD1q+pGYgDwUVCLFJfL4CUEXkykbNPnYydg4clKHgcAuvkjN4BV" ..
	"aChefqx6QkDKSNS7da/NJvF/PE2PZVetPOS+X+O0Z8Zg+soosjUixrVOBZZi9XlKApvwzHD+TCQB0nO3+RplG0aZJPA73fd+x7s0" ..
	"fmWY6P4eCSv3+ElYHHl2GQm3ZJR7eyGiuUI6k07kJtWeyIqmDIzlF/z013LCFNpUyRWGFqNQ5ZttBSyQsrHS4mUWO5I64Z9opYf+" ..
	"91v6q+MWxqI899Eybwtr/EUSctEeWYbFIwb2zv56jCLHsDJIwG782InfqG3NgnK8XMQlnt901aR3oJ513lt9r5ytNByTNbh4na+Z" ..
	"nKTrKTPfpGqJ145sbPqerrNrzU6FgiHPSfo3AOhM3y57p32MBoAn2NAm7QBuFUyFcq8nhkomoxN6K6bFwV2Yw1bFQqqoN3PDL1GP" ..
	"GCMHvS2DMB4N7b0B2k9w1eIfKamR4l1x+thQDBV0eHzhsCkYvU9l5Hje0jhBhbL+mJfFq5bPAqwg7NM9Er808/rRfB9JeiJyewtq" ..
	"wo6j8uMvqfqM+vF2wRlIl/XVwgWkVzwWKOFQv/m/4Neb9/xTem1nj16bYEBH49lcWHHYqc5+R9iCRgiwUanIbFKBC7+skzBIZP6x" ..
	"2vjmWCDwLYQ9sCPTpmB0lGSdfQqF0HDszEVaVPg6yWJMkg7l380NeYADhqRFw/PNwLbW0hkoNe8nhEPypo4yebgoXS+tUmTRAg+8" ..
	"WT+0hzORP7H4H1NdSu+ayCzWDFqyZrM8R87ts6p1RrgiLbI26AqZki4aXFfaGbi5hxEeXtc24i7IawZcm+L/RVmhBTG5aZXJN6Of" ..
	"A3tGu2X5aaH8vkkFG7PRLQQH3A7acai4SHj0CAPTdPMNFUI+JDmhEGeAOi5luoizVE1LmNUanHSU6c9Q93Xm6E56gjj3zEVrhGMp" ..
	"Is/alMapmtvpmctq0yS9NnB/B9SjUfuI1r4dSmGZZF2jnHhsw3gyomhOZ+X8ugmuzF9vzWTsxC/Ruf1kdYyJ1Wfx0BeVUSA3RfGt" ..
	"RcTkLDMpFdS2VLyXHoAMeBjHvy5zPiB3fCXClKr4nOkWVih+lTYw1mw6CaUrk67xnlZ07uxuyVUTjst2O5XTNX4S0wLthh8PpRDd" ..
	"CrzVO8LffWhTaS2tr0V+0AsVeS4k4FfPg9pqaH5vwiYL+CIY2JE3qmZbk8cbb2Aa0NuwxgmUizhnesxUoT3/ygBgQFVxz05PfXta" ..
	"W5vDc0DXZzedYDBkI+W4hO9ce5Pm6losdAip0lK5PuqsbipkodDln7UIwJxqnOWyRx8pCKSa9/Dapth6ZOl1NDkLS7RX3z/cjPkw" ..
	"nsV/1JphXgtbSYh0onKNgfTEFOOJe5M/A4WZiKyKzq2py4FqP5amOwzCSXFDFceTjTLn0YRt4MYJXOguRHHayUb4QbRS3u+pDVsJ" ..
	"Nqn8V2rUG3exEl8aS3BoKCu3UDCDF2JMYUMBCzWhsl92QnNUDyD1P+wNWBMFsRkk1G69cgHI6a6tGgFAd2V5XsQXnuAMkRPhpeBp" ..
	"lcZqG5vK139FB4gFja3x6DkIM6lUsV7AoE5K1Re2XjBTwYN1kJexDj29uYGm+/ihBOEbcp4xljAbWlrtF47i8E/+n8gXvo6CvOzI" ..
	"cF7R3nuIECV11E7dOOuiut0PrE/eIlmlla7aURfz9dyRFNJOrj8JtJkiU1wdi7XsKU3d+j09F3p8hS0HTxeGTbtbvrzNwwfsyeeU" ..
	"5NnIXhdf3gGRQvWKk4shsMA2A9WE7f04DmbODYFkVmprMwkGp5ZPcDSmYyWEFUjCeM9SQnfyrY8I2hMbALZSFHuLCEmwe+W+sXJN" ..
	"/h8B+rRMDipyaZyr9XCePjqy5IshTpPt7/nGk42PoH/IJI2OKzo2Y94+e13jkPhN8izr2q9//q4HQvr/rjYRpt2cjHzDDulq78yr" ..
	"4LO4TScDqVq/OxNeXd/AhNAxGouZgfitWTz5YeLA+uXd/3NNgVVvBuJqX92EO03INt6/jDBpHm4VQnRBIUW3j+AvS6GTC3MXT9uC" ..
	"qo9vktY5+kxIKMC6r7ex3X3gbbK8azefYqX1nRDa32OZsYLBf7lvZNYDSUeY1hPjc73caNd4GGhv8suIhXE5XoYZDpqHSlP8fsXN" ..
	"IbZCKwKYnyjNWpAtwQ1J5mcaNrjlKbx0BtqizyGX7jPE8Aae94oJU+Qzr4B9TJi33ctDaycpSAlimqnW4dafuCENMz2D+kL4LBoK" ..
	"HPJePDEe21nTKwfdjKoOVoaY7hI8GLh84uQmxUY04vaALvX467jRvE6ydglosMFf6oppk458thh5Qibk9syYZr/aQbglyZ89dZEm" ..
	"OdYTh6F+xU/Jc4cKap9DBFn3ofNxSXyWK45d5MtuWKgDPXdSyPFxPAFLFBCij4CsSp8hweEYL7EtiiUlAAw40cW7GzDHEK8AVhvC" ..
	"r1npNlF7KArdRq8k0+zn/1SJLp+zH0hgiEhyIR4lpf4jX+53bTZUJZz/v261oQoFhvCc9hc8clIbBn+8pTmbuQRv/1lv2yFdAJKA" ..
	"fpqa0FSHO4V07TLfKI1oXsX6HoWQDJ1ISZi6WHkQed87T8jdMZcYhk56O5ijbV4KuCt3m2gCqV8xaPhd/ZTL8kFI3VZcCyqm7Ipr" ..
	"RL2PMNb4QjXpfWgMMc4CC9OvZqTU4wAuraA8XCOdDtYh4IYhN/dp6H0mfI8/4I6jDUBSOsJRFMGtmUUoSmmOwrMALPJ5kNx8iE8c" ..
	"KLBaOJeIKY89+SmcIntG/sXFSvlT2N5d4HJ2btCCMVWDjmmGm8ecCE3K1qYvmdAeQRPqS+5U8O+TJSsrQRSFgl7KBN2t6QPu6fdV" ..
	"Jnm2R+6j/JHhRj2XVEddkFiIkMFM+r7avtoMFVwW1bcCYAsmSORI24SzhohmCGU14FgEk1FIbBwlN7iKEyQ/vSMTa5BhVFED5Z7/" ..
	"kfnOefvXhFtaXY23x+IwI5wkK4mDV6+rfWdwNyyoH1MBHJJaOE4+vPNtIcgRC3wSwGGPQb12ZFdLbxy6t0SuEAECqkj3Kzhw5wdw" ..
	"KfYgrtMsC7Zd+GjoKihuKdZGZLVZWlZIUqnQMAcdTGtxJr0HmAkkdnBf06zEN7VJDsKeZxcv6vK9GSJ06okwyonpqE8Igvu0b5vF" ..
	"BxQOPZ2UsL8ECy/biSsH/Z/rDo++Mbr18B1+2xMBED2mZ4hhoYnF/h8iLlmakjrE36TTZaUaLrWPcidxSDYDGyDPySC4DGNDLS4y" ..
	"Nt76efVfbXDbd/ybGUDntt7KcbBWqb5WgAkKOLH/lPuKxidfYcfZtwSLHskp8QnZepRievLi6CUWLexWVqqvh7xzsd7fyJ2aCsGq" ..
	"DDk4KWK64iqqtBr0FaIFJE6y72scQTxlYoupuLBSRSw5guXC2QN7mArFk+Ykq2wf0/Q/We5QC7c5XfOO9zbkeYnuY6ZidVQe1R+0" ..
	"ks1xTGkK33OXe4hdBIlwCXNNLEzSHw718WqFhSxBm0XjxNvxFmkUZma3SiGVV20LP+qIMOtKtlm2X8oqFm8/4bJLAiaUfWqsmWo8" ..
	"z8PEyZ/Q/e7tYqwMX4mgPB8w6dReq2R+7IuJqRuLwRYGDgwVLDEQtx4XrXxtXE89HMhDzMSfIzxQ8oFqNl9hrU73GPs/QG4/9+V3" ..
	"jnLtKc4MCh0/lWQY9xzB0yORwx0K+dlGctCv8h9MYu6vGAIurUob4jLA2piJGYIyC+LCfWXI5uL9B75ABbaXgsYbHHJrZdILT86f" ..
	"bg3hhLd+uMx5BN7+e68Y0L1iPI+b5ff4CS7sfHovdS4dxN2O9j3hok3Omd3o3ZFFYHukQrO+QTRX3Ozxu3jvWVpmPk1h7rLs5TqU" ..
	"SVEIgTbl+6pgeKiiWzvrxXJslopBoATNXbiIdm34Zf4AQ31iINAkPLXf1MKpNgq28TccOKZqH1tie23Pu9uSocg/Mp2wkjq7fCmn" ..
	"vSa0LwBPtAJhpjjfwdm2DTJmZKXwoXi9cev1PaJOgPerxR2E+7fe16uW81785ggY6mTumHfEawt6iqerwfBi32GpCralFm0oC3wl" ..
	"ujoAyoNmbs/zywRYP3wZqaVDUT/Q2euB343bBVKNYt6+eHjCWhuAiEtv/3X4zT4bnGTCuGXgKQx+Z+onl3pmse1FuFWdBB1pQLGS" ..
	"V3RrbnNCuaEtxyiPpiajgNM2D91kryC6exOBlHAiQyZUnuV4pqOypA6emQOgbSSexSEs2Cf3njkwUUYv1wp9m6R1ixzJ6XmFVdrq" ..
	"zX1rEJUGwGhYKuPr6x6wXw+++SK7jdFf/if9QfAw/Nb5mpyjPGM41L+etGZS/hbGc2ROkuOYuQOVLpzJrhqjtApkJXtv02QAgouh" ..
	"rNCz100hy+17gWt8UdOfmjrglI1q8sV+D+r+7r+PqXrmhKsHeqBQNH0sCsYm2DfRLcXtb3nvGTF9eYUcjPWiW+FoR8aMmahEX1uj" ..
	"6H9eIL5smHtz6gTKIkgzvrRfS0uNljZ6KbON5dd0lcFEd2L1mD6LYSZ8RZjnYVGZT+FvQyZ2fJxNbcN7ezzoC4mDsnNGvruF4zWf" ..
	"46A/G7dW1uQbGv6AUNp9MStzOCl+ZZwvKJE49026rGRMbxe6oYqCh2/DyyK6S143Ry4u7lYpLkRQaN2wenyRV53iqOCkyVWdLGo1" ..
	"sUFSfRotD4osvMJcphS9OdXh9GjFf6y32sTkyNTbp49EYoxyH7frF47uxB7vJ+gR+tWAQUAu1gYV1t8e2ZiwkI9dnJFp4hrJaAHu" ..
	"Qcc0jZksor2SfwE2xVuHIyOLn/ZQXoUJlLuhRsYPe1um+CF3dlWjOf1+LeiCqA76h1TpUppHRvcg/s2nhwnojbq4nFB6v3sOcuE9" ..
	"L3c92rDOBd69ttwvBfgCsCMeS8L2d/+q1Hxs/FE7KuxDdoIQs0WH6BKC8hs/LW4+FYu6te0kbzvha+lX/om24VqSDLewQTVJP4qY" ..
	""
local PAYLOAD_P5 =
	"+kfNFQrr7eA1ysRQPp4A41ZQTgFQjwLB8SNxevcFcI6dMslQlYO41X/wJKXwlYQ7V9gsV+quv+OUtHLhrr/CfcEmiFbGGV8PaMBC" ..
	"WRDCu/q46xQ8RdY0GRNIwLzRmltQT85g9uFiFyUBTltwwD3AEiJTYJTTUkB8TQgw6hVU+YmBw2nHKJW73zFrJ3lcclhRyLDfz6+a" ..
	"w+9yeT6qh51a/pxMr5v6qctnOrRNA1CTSGTq8bcnp1l1TO/CE5BjUKfkcJY0QeBHi4Ku1Uu/3dXGMWAKkQua/XSn4FwTlb/cWFY0" ..
	"yLamIcSeCh/Zfh177XNsB/rutPzqr5OcePMn+eheavJEhebkll0FA5ViC+EF8/GDCXHvmCqWE5OvwyN3J4jvJ9eSINRZXaId/Uyg" ..
	"phzkSB93FQKjDhy2qu+j2uKeIvqK5CeLUZH8KuilS3a8psvazO+7KmCBnh9RefZmoPcGEXBQ/doPMKgmgCCNNaZ/grpf66RJEspN" ..
	"tLn8T09NYg4INkvt8X8hyrHCU6MS99th49iT9LDiGYygCv/NzxT0M/5DO0/P20g3vV5dhXky3okREmvOSOjSgtmLCFbPoFQ32nBx" ..
	"V/pn1K7unbOD2XawXYZb/eaL+gTploVqMcaqbUh6n4CTWb2pNF9Iou3xdxcjDMh+g2tfFuUZmJz1JSkADdmK1xif9QWvr5HzYMrj" ..
	"zqwUdRYKVDFpwmGn4WybfYm8YqDuOdyeB02Y4nlEsVVFeQY7/7YyAvYAdnS1LVhnZfhdgOd3MhlV69JqJ7AYf25oDm5SmJZ9KNj2" ..
	"R1IDa8a9VFWxWPuYA8pPIczSIs2g92Jh+dovriuiU+QnIVeaQWGIWwWFHx+Hj038IdGBA7mgNCwCbw7PMoF0rRQqrBYwPpcbrKUQ" ..
	"PPOQ6ThAatpgtmVYTjktrVVoAwM/VLhwlntg+oeTvyexgXJhuZmrlc6V5haLXtcfRlwcQJlQnkFNxUOMnuBqDhXI5Px2y7+spleV" ..
	"HCXqLKGV8gFMmhaGEjNfQVcNq17pAAcvtFzJVAGjUJSvZlMkCgZN0yWnkRV7v5AK0D+bcqOtYLpSEyfC38/jNe4us0DnJyw7VSew" ..
	"nC3DTdyxY4xCFGJ11FlwQhlGLPie9Ut7Rqc2JzunRSogQDCBf0EGngCBma+tr96fZ/YIx/vqYJ88peUIet8qvZEIdJoiiKymHPWR" ..
	"RhxCoYtaM8D3Gn7khXywfkplOnqJ0lzEiHIIH9ZOJlXn5qJaP7iiSgKeLBEvXsG80MP++sielLF3IR7+73Tp9AEPf8PoABLlJqgs" ..
	"q+9uE/l+rfYWS9uQeZQIv+QwNdaO3aYyDaVyEQZS5Fhv53nT/OKcZl8Aw3Diw+s8Ghe4QEABSB0KyiQ7HLv4V+XkfsmJzrdokOV3" ..
	"QV5C2RwP+LRACkQ3367ZjvwPT3i0Egwk8QqDgeUib4IDWByN+1tfgvjVFRJ01Ikrp/nl0uutvtEoxFhQpwlK7ber7z5CAlAppQ3C" ..
	"rtaN2zc+K4mm9mOgsx7tv65WtjgIdOETAq0HKOIQguiER/Or5BXGzofch0+lLilbSCpm/3A/cnMZlNdZ786g7kOg9JVErVIf+63b" ..
	"fBIDTLWFtv+euo4H6GKcjLS5E3gywXUsj2M/rhSk6CAS/WvXaPgU2fNoVqJv3Dn17rt5ZJ4PPF4AOtz5GAETPK6MzP/MP27CMvUE" ..
	"qSronwnTJS1aPp8v2Jm34eeNAw7YFlrktWIJENF4XBW8NMVBDr3xXGQfGiIpc297wUsSSlWefSsyvuLKa0y1eI4a1osp4NXJmLIG" ..
	"fcBnt4UIfVgkSRE2O+oqe8R2y33x9yRtINqxrNchqFvwor1ntMjXz3Gq62DqxvZh8WhRdIQsXwI30z/1njF8gd/4paozIb1qfqwg" ..
	"7KqQdF9vwuXA/00fvEZ3OJvpRctW01gm/FF6rfdDdFoSxzL6gijvT3Ej/jIcK72RWVdkynlu/0QRTOQrLkvQS2T3Gz9AHMI0/vHW" ..
	"N5oJe/H1f04kUcYHpQyyuWKXLG06BLgnaRDmpuD6m1TmMUfYrDYWeL1Yg3Nsy4t+Vtk8v15ptgX/Cgfh8gygy06JCxNJMx/tWWfo" ..
	"Qg81WsZPNWBIszn3mJnavSPAk7sjKB+aSbgbOXE+yyR9zWmUef1vNHK+xnBkARMDvW9/I1+OC20mN1AMivG4sCLeymxDTUpIGTSi" ..
	"VKBdz3E2huab82gH8otOdw4b2clYGIADF1eLcvTLrX8kt22RfoCfjG2ScjByvgE6dzgfAJ5nGQdgQMLcQCJZKzDMp4KzqDX8t2T1" ..
	"bb9VByOqk3shhRXbXUrGOWSnHdqmZlB6sFUJod/0VhooyxwLIxBewLWEke64e5722utQ6f/+aGGpcwFBxLEZOZxaqkFYv4Ky1+1l" ..
	"UzwOCzbfuuq2Mo+BSUr4jBmWwZAcvXXVib/xRsHCJEnVLWKvhj7dGijNN5z07T/BkzK34+fmOS7FdlYSEhDp1ieiuN5utDCdkoKj" ..
	"17tch3A2fU+n4ShGwtxRvh1C2P9rGIELsHO3sS9CXwdZs8GjyUofLAZ4nbH+ftpf+wI4Gx2iIK1UMAWS8MnJuR4saytUwa7Qmumh" ..
	"LYwMuQdGWqKJ7Jhuqv+M3TxuActXyMA4LOvYz9hdk4CfzwkCf3AZwWWMUaJIheYNb2A8dZpejGu5KvbBiaspZ9vgXs07CAbPZXtY" ..
	"Ue4yvr3gg3nL7+yJniCWIVSNu1W2wECU2cBuY2WTTUKMrSfyktzZ1TinCCcrdPTFgLjlWrE2PTrY0vxWnhNvBRpN4zMnWCdsjiUM" ..
	"1HEZTPz9m1lqHKi9dRtUMigEULTo8W6v/yVHUIGoQPXSPJheCA6jyucUNyYFy5amCeMfVS0cHOpHPcWnHe8p9eZfQTJLkNFUqbLi" ..
	"mJR807tvyDv9av1iTrljEBabOfBpJm+k9wauVqTEZ3HJ7NigmvLwJAfC8lOJQs36UqP6+34m5ronohqxwEy72EZOJGZMQWYQzofi" ..
	"+YpeWDEw/U9SK8XZG7ARKypaqdakxai7GFvJ+sx7Da4cnEfUuEpCSu/K9PJRyWp3opjQo7vxP6bS7HamRrQkPCLkbjXYP2E8FXCX" ..
	"wttMAOE/k6dXWz/c+pIF6g9EYplWl5URfhr52M1GG/KqO2zJ4XZojSdJeeZK0iThHtGKPovhYGXfdFVlwIZttxbtUFSqnFbr371k" ..
	"P4RGqho6CXhQS6W68anTL4rV6IE5lS40cVAgJ7V28yKGcajY+tVPfvqHsYCYZ/VYRVffdY/qhY3eK+60dP826RXvkqbEZaPr+Kbx" ..
	"mXCYVus+7xVF6rwJlC6SwesHJHk3EzZw9+AMrlVpZs/xiQDRId4UW4dv5sBLxYUgqXjIg5D8TXaZQ3sBa42r3z/VPZL34m74OR3o" ..
	"T55C0HN0kW8FMpjJQ3WvyAfhZ/sVqJGL4a2jMit6tWQGYV4vuG2Upg2AnZb48GPdE9owhD7Eajv+BiJD+cYgiQb9FJshkcrUmZon" ..
	"taL2lgoJy1b7oHTF1nHQsbFJ6ol6ecG3g4/Tk2yzKfugXZ/4ZH0HCyB4rw6cdMQyK3yUjEHMz46cVcFb7LzpapTJhua0I+r0fdgD" ..
	"8HOTMpsOlW+h0oAHQHko5vA8W5NeLkkgmkUbDfKXlpr4QEQ5PDf3w4JiBsRG4yWSop4qzmhY7q5E8MqgbVeyWq7T9fvWTzqc77T4" ..
	"WtBZ9sUFsx3oTQIOEWKOGTvd188NRqVBVj3K0O4L1TT2Ugeg8Y3oeu6IbLDeJWOLyWRgTGn61z+OfJdydO5XH6EErGjKupW4DsXQ" ..
	"MBycZCTtALsHTJifWjXMHLhBA7VhefIl07+l7V3HF6y6zO4LGhSPZbb6D1Ku7nj0jCBkM0jYbNIhZOz7CoO7Woyb2QwudLC5p/P0" ..
	"23iYrwWr56Hy5a975kVo77l8HYClDuUoMeQSN+llyf9qH2KuLy8kK8RctHM0UwbpHRL6rzOjrT8gdvsD+I1da0N2Rjy/2v51mLM6" ..
	"yza+LmbDUx5FQ7H1KVnMiGq6cLZHtaG226TWNf+YdlkZ2cnkwLUDQhdcSjk3leUt2/e39OrGRrUpnGXLkkCGhlh96SY1yYog0gQC" ..
	"QcTpV5MHQHsQFDJ7CVlg48oEQIe/5mEusL16nir0zHAUiOtJKF8VI+t/DIuL+e6Tmt1JOt9VGHwrujnS+r9AEyMuEetNFvqslmCB" ..
	"PJ/LzNOK20bSVBsH4MSXcvyXKbsAptabn0rL+s6eYG3T4FLxvb7DGpltEpyPj+itWC4M4no7Lz9vhKO9aYTCzMPL/AJeXSkQbfkL" ..
	"4WtafR7VcdUOY6LqPzkgI3izFsm0aJrfX9Rr2HMESkHscr8L+aOBshcsCGAGSvtt5RYWCY3rJ/L993LBlgolq5J/3D2JcmkdCj1K" ..
	"rkiu/cfQwEdhCPgV4ew0qwdSxeLb35pif4n/hdb/bO/1wtZ1DF1esl40zKuquagrwwLOXpk+VLI2sUrWhynMKFljlzbFscoFmNYp" ..
	"p36cxvUG7aeSUBAlQbf0r8nK4SG6+vngOPeWhASoxyvlv7zohVuJy5eduDPOJag+mNqGGelsKVXo1Lc2p3rGDs1G66TZ8w0gP3od" ..
	"qptWfUm0txrjs66K0NwR8LXxPXjAuJoiGPav6UTGAdzRociwuETOSGTSJgxmVQnEO0Ivi91WmtVYIrpx6Tz0UJUSGmEvEgRkwNFz" ..
	"rmuWHySESmQE942i1J0i9sUzepkOaBaFGf9BZ/3rG0loCaL7zYEVHCj+OGlXcdXBU9PJCNmBNhidsD5cM3ow1uQgTre3kpfx42va" ..
	"4m5bxliYhXQETIr5OePpjUJ4EjhSj/xB2nvVzsA8JWPeRpIc2BZg69XWM1ByIxIR/GPMu99hC7f84C9mnGOTx+ithgKA3EwFlzj6" ..
	"YZgNT1o1g5JPQVbx7R5M+ROn5+yAYvoCwM4tKJeuJWXB4box5mR3Odl4ZQFP2vUsNWom3d/lC7yPMQcntPxbADRUaQ6mzQbvteGX" ..
	"fVUfVNU10Qbb8OZgc2oAuwhSL1HHX/S3gOl83j0gjP1nqfDrdiUAMYayXbeXoxfHhcJWFHKW50Ct7Fxf9cC+J+I9GELd2D5tjMHt" ..
	"OWjr/K4YgBXmUW7gJnUZKaksoui8WzB/Qn/aZo4poxwOdA2TlxqqiJ8nPLXJp5TjNhX5XDguqF4AZgTQqq+ZSRkW2SMN1HemA28S" ..
	"e/AHbARIXn9KZZpJ/+ep/D/tcqXy7QvKJwicA1l5ivsofPTruuBz/T13M8q62DFlXw1NngypvHG9S6/lacZMbURIm+ldXK+AfgY4" ..
	"uIH98v60Q7AeEO7xQUJtiE82kgJzrUrIoUU79G8RTiMDGw2YXlyaYDLTjeLZ81Ry1uQmMlVAkz6VNIdiv/N7Bg4PMQNwX8kwkUVw" ..
	"AgkbpVsqjuF7k2HIgX5xlveKyXetjruCg9/5g3f0SW/g5NkmeJFVCuUu57wY5lDoYiZq+mos867sViv1TMWoDP2wBro8bW8DtwFO" ..
	"Buzoja4C8b+47nFk+JZ8tyJrjauXpd7F1ZJzQOpIu+vwN4qkzxse8cy+fhtrC74zkSNXlTa+mRsmAuESB+6cmKLHbGdueUbxnS61" ..
	"mPsl74OXu61iPuc9PSSM5XsLT8ZvMJj0BCUG6OCPdkPwaf3qttQaeHDMrOf9Jss2sWimif3WuRxspTOztMX6KbW7uNHq15YXDCZ8" ..
	"vzU9QwfjXFYZBDax7HOnjQeJk4NyW5DIiQArIN1piJskfus82u5Du40zwc1lItnPRyLj5A2Cnbfi4FcKsDd/AOr+56GYW8sWMq6v" ..
	"ViVqmAZBO/+UJ37g5ddkdOl5PsK7Y9gKDfS5Ie0uOQ504R8SGVsb5ukFJIvwp+66AOtgHTQT6b3CnbKbYoGfbv4lv+GjgcmH6brl" ..
	"jQAGBSSgswjM6cs7uOEDC84hGzIt+273+TQRf/N2Y/JzgWGT1Pmwu/k5tUF2A52LDQvrj7jv4Lbs/AzIjfmL3MrNLpKJTF+JMli0" ..
	""
local PAYLOAD_P6 =
	"zj5814KuyXF6JJ3/wR5P/IDDpGFRmbw3gur1z94AJr9BaJLr1jIEHWoP2GQFy0FPuBPUKI7koPjrh+/37/BuxZ46GOHhC6HOnOxF" ..
	"gqNc915BwnxTemgTMgX+XuUxtSseqealL2aZY9Ju6ISUwWeyVxBYnd3lO/P3MfnEBuyuP4ZHviJ9AryV3d1qOZp67I0s+cHYfvOg" ..
	"hEewmqcBsMCurE2GlnUTPxGMVimhjZiF1Gj3CHjB9hF6Jg/XIJkGxEywYbW6RidaHUisrV2qYtQotYKksuA2bWrh+xAjoM8sNMDb" ..
	"3dmQeSAZu+BNYOZXqvaQGldPMXyVc6TbGkLojy1OiWKGJQDPsGymA5eFV8Q5CwuFPbLZqr5NU6kCvfAhkQK6rj6/0bObS2GYSaP2" ..
	"D90nhB3h7L3+BnUZHQOZmdU0fSUp2k0gjuIdd/DSYJ97+r3muESsRPpJNQdoZqcXu6zI67YMsFztrYpD3N68QblEYsar0PRrFcTa" ..
	"KXgH6IwAboAzreeMyPaIFqmDaiAhUHcyFSjiJn9Gt4urxLQbstB6a5GVDVxhMe6K97Qzyao6/z2KJ1dvXyg/foYD79hFD47weq+R" ..
	"yaIfwOVimq0MD+DVB88V9fhTDvq9P1/3Bas=" ..
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
				pcall(fn)
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
	print("[DQFarmLoader] Khong tao duoc GUI. Dat DQ_ENV.DQ_KEY roi run lai.")
end
