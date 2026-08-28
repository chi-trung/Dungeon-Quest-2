--[[ DQFarm Loader ]]
-- Licensed to: QKB-JQV-MPR-T7Y-2JA-VVM, AnhKhoa, Tien
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

getgenv().DQ_LOADER = true

local KEYS = {
	{ seed = 4259948088, exp = 0 },
	{ seed = 4261328223, exp = 0 },
	{ seed = 4261337135, exp = 0 }
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
	"h0dodsT+24Ba3A1rL7pUMhao8WpRcckAfM20+AzA4N01diwdwhzjSjCxcpiDNKyokaC5eZLd1pGyzkis7bDnSg86u6Lyi5f8dJaw" ..
	"mz/bpmUTgT7/P5YFuEbm1kwsel63CFgj6Yj1xKu+izXypt8cq9Ep+Ah2XM7BdeYJMI3SEG7zDE1oQaPQu1Ea0zHo1u8HXSy4Y7Ze" ..
	"3J7xV11zr0ziqvsWfvOd0aXttZ8UXi7pvbhArThLkH3wuv5HyCBMGmBEM3FUpiwrk7mSRAvAOchbKBD5CGEu/4TlMjJ084mEbR5O" ..
	"gzA8axHE8ZNpw/mI50a+Jqq858sgLEqFhSFgc/Cy8N9EfmPDK3HEfBXcq8RDtGOqMbJ2SAFmOBjxplFW8S6Tr8V9vQQfo7XPmds9" ..
	"h69gLtnzkHAP+j5I2CRamw5EqMijnGm/ylm/HPo6o19KabBb9UhgCBHD7nOSAQHIFtzv6jpJuK26+qL7laz+xbtBKZ1E/JTZZ4LU" ..
	"BlW/RU2ICgaEoHdsCi6OBDP3gUGq0uJBbl662mA1/8yIonkhGiFYUnBvu4bg1CMRLZt28Ykyk9fonIH4r6CCPfK8dfdp2SVyEdw/" ..
	"hLO37yZc7Cys5P4iRaufIjcMU4d0mUC+hJ6Oqwyf3A5WZ/GypA2xDu/L4XDniO344lXyLYDIaa6c11WTGUqOFeAFQ3wnq5NppOUJ" ..
	"T1VuXohpOVgd6Gq7UF1pXOVkQ0vzl4Cw7ZOmufhS2RCHEyGDxDNxWYgfsqHP2GKO7B2YxYJVjiZ8etf3YctOb/PsT5RG+bCQadFf" ..
	"huT8TIRdJ3c5gxWvz6UpCYVX2iPyXa/khFMzqw4fifUWquFtBpxpNkLIhP3krdYowdjrXK35K1wPgGCwD1hrC3I0ezf7iOjaY7EI" ..
	"XFoOLQhIISXCowtn+OQo4+DC7LnaHMzFLntZYtD1Rb05IN7gxhwGK3Fpgd9XNoGlWTTkLVuhaVZfnD1cZB237HVgtJiJ8/RVONdF" ..
	"dk3JWgKcbp/dgWgmtB4aoVkVCh/WmA/ElouCMaIZbvd2fppPchUYLsp6S5Af0INsqCeWblA2XYPB8NDka3ymHkAPq5PFfItaXCej" ..
	"fkIxbblWXEdLY1kUzyLSkwHFoeMcAjx8ZHrvop/GSbfbmHKDsq9m0h5jgjh6ILwf9948ZOycaQWoX1EOHeEkeeQdP54NBqkb2Gtc" ..
	"CsTJypskYl8m93qw31cTqF2nPMsjkaR7rbD7YSZr40mKwhGFfmlgmFrDVEtl1ervy2W3HF6fq0BHF/tTAcEPLw6J/7IFtvEpbY5W" ..
	"X7VG6kBZjodPknrUyHyY0WwR4LS5AX+ga1XoYu6nQ0roVgIftBZ8sYHmsDnfrmFypyAOjSqMQZL3pRp4RqR6VHfMspQ+CPZ7JyAD" ..
	"AQpLnCumZV2ERcdy7PHcRd7vowz5JBuDD5C/MypHiC83dPY72FPOKGdOEcdk7DDyhVXbGzjjUL9rCQQ2n9hYzl4gw/flASNl2sIp" ..
	"MnsAMRTqk54Y4e6ZZKaZ3vJF4xo/v9PvTjjSWI/qGcBU6/OTU3eaiGGgqfc+MFJYKWjgma5A4U5X7mnLZPP3I+WIkKWUwS9mQIdw" ..
	"F3uVJad1tslTBYE3ZkGR+kioxgtuRjH8jM3fdtO5SNm7XrdEBOw5nbnINdy8FcOOYauGEd6G4hyVZlEKgoTf9iNHpkYWZoXCeanv" ..
	"1S2wUz1YDS1ZJVSunx079bqlvI1uUpIR/3MWIlR6kc7ByArFGmH/wQxDg79jbl5JJID0X6yyrkGhCf9RgfY8JFaUj7yZrbZB6IIV" ..
	"LuI9D9Qphtq4+BslQ/6QdqrVjWZuqf/ZzIy+iX1TiRlicWiSUQ/n+Bae9EKgSv5Nyohhg+MCLI+4yf5eUh9VkHXSuoWkweCz63lj" ..
	"gncgl9F0n8/jUegKoKOGLSgTuUXN63aNQYnyNntTh+oPxVU98eqbmdkFXoywVtkydQERwFEMCW1Ao91Qs2T/hLzf2+7sIiAU/fKH" ..
	"5gLfnjSgAQzOpD/Aq1IeNaLcDb+Gg0NI3EBFxM9YzcBoFRiPoMfj4VTpjRDinSnBQxm/EHT5gZVZn9OltKjPP94n55MH3wEq2v4Y" ..
	"ZWnpRpFAc5yHzi26WYsNtmnbN8xLO73+OesyWt4j3SERKqtiFden+3vSfbmTY9uf1ML/nvNNE1A+JcvRJj5Ek1dUX6tnE1xDYqQu" ..
	"taqHBmqAOPPCZc7hrA5VKISP3IOiTIU5qwoUQT6WzuyGIlNvyHP8Gz8QxasXwUHIx7enluRl0aZ4VmTfY+Em9ISXrtzRlMIygJk8" ..
	"clEuWKhYkzuwYAYA5vrchOgR1zDZBu3/37IWig+zoHG22qp1gFxtO8bqecqr6IYl411EmOWiub7Xsb0si+svDA1MtqxbysMAIG9i" ..
	"CACxqfAiME0l+PqYMdhmloRwtGwJhTUC708DmSWx+6Ybt1K/PgtFhVaXkXTT1Fuhxl0WRVG2dXcYsL0iXLA/irIONmx/BIM1kCf3" ..
	"+23sqUuiNX2nCgo0T1X2bGb91dwDQ5dAQVdvCXajnaKa+uczyFxYiZDIU6YNhBxZAvjMFaSRjuhReeoDYGtyFyVNJN5sqgT03xIE" ..
	"U6V3pTGcgk7GNV8hdFx8s4ws5dBG3aJX5oMigUR2T5PlmcalaJFldwMMPYhk0eTqOtbUhcPcQK91SyXvrBPndQ003GHDca4dphFE" ..
	"0zJ0kcrFvho3U3Iwe/JNfr2nC5lNVjbian6AbhPMrKIGYW3GdymJgxpI/oNUBzXlBUDe6JugW4GObmgDikCRKWKnzElbqWpsGSSH" ..
	"NxGk3mhK8DXG2KuT5uEKRwj6RDZrxwH+TZTdcf3fwjIPTB5OzT1j67A05YadvJAli2Ao51ITG0UKAUsJRMPXjQB6I60P4pTT/kwi" ..
	"OA5xA4aBanf9N7hTdr7G3nLalKLpBtBH9UmbH7zGMn9BY/2/q6QArepP0pDH9DEK/Q0AwXH5C0ROvUP+pIYuuTCeLZxHXAyik8t5" ..
	"/hYBn2TwZE4l8XArDHQujtczzjSaoiQcrnx/oCvrek5PwPoK1O/oDCsrWEfo/AeB3H/n1tYlflGVp6H34X/+UMwOVlkTbTiOY/KQ" ..
	"VzlLgVrwcLFCeOIpkr5UZ/Fsh0fpoYC37vbtGak5Q1v6i5V9S7jY+6GDm9JAQAnfWjTKBHcCdCbfMHM0OTX8h8POpsb4CU2+3f0/" ..
	"TabB0mzGvWoSAmOdYq12rqo3G0j4t/CkSwWu3TVtU3hgZe2BRFCtQEJFaaqBK34oHJ3QFrBSADyRqDMdmmebpAg/LSu3V+2V4SDN" ..
	"3wXYmr43dcseLhXPZahdy8oXxDylW8nGmyOE0k1MLvFDS28qHVZO6zYLDyR2MK82q6wJwPNPrKFsu3qP/ZVFb0XyDikTHARSfSNg" ..
	"n53me0R8JSsOV4qIc29W01Dw5AzKkd6CxZfn+PNPzbE4haXEutA1ppQ++GCKkb994n0vc6o7ZqDszm0rmFlo4lGwlNV1NJ03349y" ..
	"YanjOWpwkkF/TUkvyFs0kxElbucF6rEZ9AIJFQQiD7AvphU+A87Ouq0LhdwKB01fItLOXUHyr9cftkYqXjeJ90srCJdnskYE2uFP" ..
	"wkmFyugys57DKeBkxAFw3EkmDEhqsiMZTKhCNd/0to5CEPGtQMqfcAJvHvO9fesNX/KkpoEEc4NlezBjPweupjnISQHiWFZC9Z6z" ..
	"3bY8ratRXd072O8zciUBPJQ+0uiPRmUGgQaLkFdIeOTbpfnNpwYb2n7bZm9+LSEcCj4erUiYTUpDrn4as97kaUMkz6M7e28cg0XO" ..
	"AvctfZAXMOOkEejmA8HoXosG2eyqCG3ZdOtDepj4OCck9Q+ilXDiskcVY/v8PJgf8U9JydUBJoGVmDPmIZiGNg3wjtqArLDkte2F" ..
	"5ayK8Io3AGf007u9ui+pP4vLhtETjFkqoilGHroS2LbQdePHEHLOUhHnnzEcBiJni2SLFlZFED3thOT6BDq4+HvADWx64o2V/iWa" ..
	"CEl/foJGT8JP33DbbgCTzHuz1gaQaqS3oWSXwqVPvKxQ34nMqrceKIatnLNs03GEdwHiDuTC9GaXCMjfxG3QFtfcWYzBSFXr4jCD" ..
	"QM6cgl+6fkPgz1t2Gf0lnAPePdoUHxM1KrbZYAJXBgcc6F2mlWWm3iypStoIvlY6PsjxYM/cIPR7Yt948szmIWajm/aPY6LY+ZS0" ..
	"sxv/1u/Z3hzQ6rfG32CueyGHBwiAC5pJyRaPRsCZAxYJjweGOOfKIMaXOFUx3hxOT6LNrUYf5e+tPdHvfvVcA4RVlrpJMoW1rbU6" ..
	"fcI4u93k95ftLGA2kLiRNnr9ooMTT+xb0e38b+2eMqyg1lI3+r+E0zSldMK2oAXiKugeI28WAsooZ5oBDEs6KpG1uU76NpCtzFJa" ..
	"LGZeKp/Pgux8zgbRJK3nHSJt1VXrZY4dwZIn08feX+isILCnWbGo1n9CJYSrjTqHR0JDY7dFeRR+tFcTSGRFBm20nLYsWPOF153U" ..
	"uDujU0RYoixH9QjSoLWym3q7SKoJXK/7wG/VMsi3Ws+1uRAs54kr3r7v1+06oKkG56sRh1PEUn3P0sbRYcZgOGNzEQTYwOZk8Pe7" ..
	"ugTgZkU+nfNaf/lSz1Htzq69lVaEzJWH1pGPMxI7wUwzbZEJt8Wh1zt+p5nL508Zv6QAOlRyDi01hGa13uWdcASmZgI4kTBMjRXw" ..
	"dLe2rceJbZ66midonpljjgfUOug6hMmY3X2vbqPL8EKiTJsirRhUmrYJqx5ArqQJRTlNZfdNOIWKVqNxh2cXR+L+GJT1nkSA41fR" ..
	"C4Yr0KIOXroHbvU1bOP9nTHHjd5k52sEpUOSUxh9zRASuJCsglIz+bjgZoWP2hpJmsJiNy35zSouWNc5ieW7DvHtuF5ezL6xcNtw" ..
	"4JusqEkOJ4dzvIJ/wSYNyNQkHNr6tfP4EQ15x5wELJl02NSbpVcCAD/XbOn3+q00hqNb7y3wH1ilQ2A/wX8vN4YxOQX9NPfth6R2" ..
	"W5kTjGp5IrI/UHOuitN+4zY/PVCVhvK/YfCQ+DCOsjLZcYh59Ekw3FgTK//3deyE7JlufMSbf5hIYQ0pRJn+VDis5Mq0FvaQKm/3" ..
	"u7rt+SAmVJOSEtltZSTJgmK6+KoxyHspUof67mqzhjbru8QHpVOaovZvJRgZIOtVwwndRlz/q1Nwg2qZ5NfjOOIipOnonUje6Mtx" ..
	"+nBXcJA9qrip4TBhax77IgA+XrwhmZ5mzUr8nB3VVbFrUU4p5ra3IkuRoduSRIh9BLeMC8oM7MoVyr04gsUTM1ob1Y5VMywKW1Be" ..
	"8y2tuehzyCWCzZud42TGW52kTm6Tas0wIXi7CTumDsp2Pclnq5JTqiXgBng876ShcWbqVfaoMOPhj8WgmUvyLRncK3+4gTYPKO/+" ..
	"s32qnGqeEHn/HSBe5unfsmqzrJXO4G47nMEsIQkI8sMB/xy8G1dTAxgkpv5n6tQT+J0LuTho3UknMRDcdMOFAp3VxKoSRKZghMcw" ..
	"l4ARUlVF6IaPG3RniCoAaEy26dUQQJ5BPcmB+IKSEiXu1lhtMxOcXTbAiF74HFufxDeVhxdvGxz6tL6HHWv2vSppeU6SUt/+jeQH" ..
	"HyJjil2pEXFi99eJ4czELKoq6gOh3o8AXXNTxafS1k6NSr3V/6cORYtaDya08/WS4uAIphxdw66Jpoe1NOBp6fMktQaOEYWoyjWy" ..
	"fVGQeQ8HfneHeGtNQpGVexWtR1sPkO7SpAvnkIqtIv+LFHCAy9qylsYgjnE2U4k6+IEjEfQ6MMIkmcytKxAEyLNvm1xiYQvrlbGz" ..
	"fA9HTkQ+OaoeIYe/19VhfJUl90qaX+DRUnTdR4f4N5FPfP/atIxTGOjhuyKjppoFstt+5hT3Iv4Tx/bKKQZqYqE57SeeNWpC/3Lt" ..
	"bpS2FxVnZP/ssqrk77Usw7TvM9utlzTosNU3vqsdp/QuZIfjwyI2JzHegpfqk1X3whw3o0GUGoqOzjMI24WoVCuZCCAMkRVpVuoQ" ..
	"gL3YVyyyVJDCnJVmUZpBQ9T1ykJQ9AmeFob7+nHcCRTJFijxcA/824AXrd9l6HdR6VxWbjalb6qfeWA7Mq6Yx+B6qUaH2RPvwkFl" ..
	"xb/58ogkRf+j+qoBqgtZ0KMmYzJ18SLQ4ATLvO6CpzMTPKVAo6+Xz1atpElRHEyr3ytPRrE6Njox0JAeOHKawXSOiDrMHJwydzP2" ..
	"4S8lXq6loMCreCZP/ues2N0ndKfD1xjzwUgij//mw3ngMMGkgq+o72fBlUQO7/kQhHCgJVumGG5abenc2jcT+xLExxzgukOfT6ff" ..
	"p08L8BdkzTYm839PBPEwX0eX6vTzcUJNHfmmfuwl/Bb+rtf3PhMUNxXMS/W+jTGPjbQNp/7x6DcBhXwG8mXr6aL7QZrShJ9VSR1C" ..
	"HCkGfIqT/nyRVrSYvpgZ+C+X2He5dykdNFVGEjhZb3WyDx5pVMAb9loChgncCHQr8bZ9E58ukxSRngPpfJgRduqOZ7xvn4lOu8dD" ..
	"k5N7yLNmhICq8YCXbGDeB222876/HqHUWcbOOTTJFSAq2fP4iS2bIh7OLGpaSe23FqPYRZJi2WXF7N7fMfkuJ86GI/SgWPq8s7d0" ..
	"bF4AK/X/W+hRdZP/yv3nO3doHd61VrSWnZRjGjUdG5vuuIGZJ7v2iXgq8KF3ugbyw8qogk9BMQK794jBUYrPjSSFglIxTX7Gu4yj" ..
	"z5LaGD1+T6MuJG1tKZaPKisEVuoaRVStJdTzql5XL2n5jp2xXvU+vMWBvv01L1BR5BJT9dcqIZOYDBa9h4jsySAd4sYvSRH5s/K6" ..
	"ClwL7oTgNxXVvNwRn7hGmgo/0pIgd632Q/EhaeP19k8jri13NOtTJAGaelLRfyABuljQ8bM3eZM/Jyl5pAHf5GrDZ/qEMYkPXYnM" ..
	"Le7KIh0p4eLkMWXGv5AIewRMjdv7g78eDBl7ErIEbSD8m7WVwC1Bk+t7egKQ8ztUj1RIsYfwtvl9kan5JMkQmGrVTgyVI9JmwAgf" ..
	"/YcE220dk1Yg6eSkLTcjm7TSfrKcxkRQ+56gU639QEsOzzkJizONeYls0+ohrBw6V2Qu/ILXjclA32ZjGYLnBQBY0GNkEdBb65qr" ..
	"2IGnHysAxo6cQnCSAd6V8XGcLljo7ktQVel5/Vhnkyb5kzOxxghKkdeDtjTY/NjZlAJg4ZTbgYiJiDMv/+tWL/+D1BqOq8EX2U3v" ..
	"povLdl2IK2GBSPHbj+rA8DrGtamaGGgxrqgUkUb2DsOQeVOlS48sfyWshLYZ+U+BeLwIx90ewXSAzyCpHaArZA/JwmRc1PL6geQQ" ..
	"kLlKMaGPJGEuTt8up5V0vW+QFUGLB7VVpfe6x2RYex8M6rTSVhjPSKAWVAJM90Gijpr+wRYAQxAkZ/+h+jYGOYvCmOXWLG2woeBA" ..
	"YsvZhBL7Ru6Pc03/SNxYRxXY2aQrnkqDEnkDG1LkTAoxyt+nqzYsjC/WK6AgP8wRVsfmwqzSEFp9ZwYfEjONrtYVUU9xdysBR4bf" ..
	"S+RyX6oTtQudDnbtfmrEHFa3sNjJsjnYCH/3nNff1dOmpK7UoylXMQDuNZG+PRxfcVFFj0kEqh/sKg33tzBefJ+fe6g2W7NdmDR2" ..
	"93NJNwaO5BWX1XRudTFSEeZf6M2xumgn3vvU7npmujHHj+HZ9RrNY2loMNyIQo1SvglDX6NjXVcEzxd2I2htpTXsW5AUTAcFL0DC" ..
	"NZ1yqBu2YA9cG34zafKGmcv5ECCvnYqYgMRAx3PoMZDpUB+zH5/w+/CBD3OLuNQZE6zvwEbTHUR22aTMCdokZHRQciip33w1zKxI" ..
	"KWa/Wr/xaUPuzI9lDiOM8Wg01L47idGz+4X13oRPw/4+Jzcq5UvqwinubuIBVTqev4doCkDNqnkLHHWCgOt72JL7m030YlJpm46Y" ..
	"BXjDIO0z9UmqUADTujy1u4Fp9trjy5kMBuuj79lV25fXtyXnKaFRvbFw2XWKHZJII6fg6E/g7JrW/AK+kI1KxGiYUm9ZwUCi2ywM" ..
	"6JIxcGeVT3eOL3KYT4Ml+mp9bXObu5vA2JRQ7troeFAagBn/ZvqG+bs9lZho2xgz+QvryqfgmK2cIXiHJEX77467bcA99BTzK+3p" ..
	"4sg7NlKs9HgBkOHUi2P5+x3UpuWVzeiuQrSJM+ytf6Z+LYQsmbs31XOafjJ0h/36VfEGmdc0p0O0J6jSwSMftB3MiYjxsaXVNCbo" ..
	"hjApshv+d30Nrg4kKFtyDXLMj+SusrASXRsMU6Tw8Bvp5e2mej9D3H/mQD8/98ef/Bmxz0LVIvPnUls5DkuTs4vYpkhjKCKwJjCI" ..
	"t3HTC/uUe+8dXUkufot0d8FDNTd/s23qOjx95/i3FgJCzxRuFSeCDUhBLl05aGyoMwnV+hbF//QuV534DVnzapdHciS6O1hlVn7H" ..
	"uBbSDojjKSpFtsU/PQHK5x3N5efnVKImVMpquSwb/uQvAdXATWBi6b3qSux9OZUsKuPBHTtxFvcYm7Xdz5XhVNpMidWCLD+OTONj" ..
	"0YEc1zfKWpBtSza4F6dW3RT39zKrKVs7RFursRPHE5SQ570wC1I/PFLiw9imFAe14sVLfcLQIl6x5xLCG2QTICxoBzodF6uxuRzu" ..
	"bq3A7cZ1aVRENzSccFPWgUV0YR+vtXQVMhwK8tnzFvpOexOkeassonZmIMR7pypz8e81zYB9177iXJn0L+CRiPmSgBvobKjAH0Cn" ..
	"Gq3pvZuqftVHEW+5GxuMBJ82yBvCucWi6Gim7UvCAx5Zhp3nQnoGg0Bpdx0fDfJsgiZ2jmA9V3nFlt8p5R2S81cE3Grr/s1xNF2E" ..
	"koPTQmfaDQjRNkA9veqFNNqXVn2pAfHj+I46FzJHExNzPZUjjeiJqKKjL4XPiwaeIwHJG5tjXXiJjEarVrAsNTvPuiIg/d2bn+iN" ..
	"HNVoSIFczYGnK2jZhcl5YS3gYVz0d9N0g37M1nDSaJ+RMI7tHe8Ue3IhSpYgFSvd+/7ILndiF05RiZuFBqwMxjq0JeUBYxVNgbLO" ..
	"f1W0RXjpcBLBkZ0mTRfNxXuE/IkGaiCSdK56FA7+19Y1d4Uc0vTt1H5/dZpaEtneFa6Zqdxe0Lo5ZrbNY5uljfpX44P0OhIcqrmI" ..
	"NvTDZolRN7djnrVez9A1GZwjiVeIP9i1Xs/7lxcnyauP2fEzxp5T/sN9X28YI3CT5bKdlC2fEQbC7Tfw92I54UKOfS5qT7Prx9zV" ..
	"JYqhyDwGukXnAfUG0UkC3tqIUdhgGMinhcYCBhfTGJlmKvB+ELkAeylZ2iSvWHd3ddgfBaCUN6eWitdYIrxmZazohRbyNrV63ycx" ..
	"TT/7Vowp4foEHUcL2QFDzlsQpIADxr9z/2gWElDgdUP2KAzMNLv2eUQhn36/uvEe0j0w3l4soGPDdISZwSVvriZ24xvYH+H/sGHk" ..
	"rFvsTdrvwsuJzUF3CjfT6i1veA1PLZfJ9lGL2Ydf1kvfgn5ab0UtEZBTcHOqDoe2iJpyulWctxVu9T83qfB+6kMbVgAwJl7j0pM6" ..
	"2hh6HPIDPM2kN0SVDv/JHEmbJjApZsc+U8zhzd8gtjqrdjB5ZODbiC0RAdxNSbVoO5feySAiu0x1ThgusObilVQzKbSB4+nMz2Wq" ..
	"fkDG6W4kRCjLMqtwluMUQg6KO4lEJDI7ALKjVMUWd+wsRgqNMdinPpowzvrcBc7gV1rdJcJYJV5vvpMUPoKAa8h80l6lCTtR1NRu" ..
	"6HP9xUEaN7ZPbXhHx2J1i2liUQp1EMRNyxpwOAAzFSAxtlg7UXD7t8UK2BJWNLnxOLwbXZUEEujwZacYEyWIVYD0EgPEjC/ojoWv" ..
	"p1OckEQCOyz4CTGj1ztdm0/YGoPAUOG5u3ufNMl0i9CsZ0qcHJcjf2tz5lKaRnTsjdEXoFrT6odW3KMZK5cG/LEiFU8tYS+vbQNE" ..
	"aEBBHjwJhRG57BGJhfqTeDHTQdVtMHWQmZsXGM3QR5Kljcf7kjrsb6KEWYusl83tHmJ/IznecwjdCP6LS+JWNSr6WOw/MIXItV3t" ..
	"h1r3JXVhiyIwU5ET0+3yknYl3oiu7yjR1AX8Mzpr0jNsCKt1jFcnWZ5WVbXhRQMp8x6LFQZq+0QWTg+58wvag87usfOJUyBTREvQ" ..
	"6fxpNWECmxFGJsUpZ5LbEajhcy0D7vkl7Nf0wcwN6+mSrRZHcJwU7ev3ae6kDdPEndY9JaQ+fxam6DW34j04v3TB8IJwa2QLELsN" ..
	"CyzG/ftTEghRFNOs/jKn2RHuhCPvF1M4q+jBhW7tOyCbBlo/mAKeQmxHg/5MOH+BOP5bgkNJwZJ+xgcAC/cUZ8VpkuJkwnBLm9k0" ..
	"qXIt6LLmOISsdaWXliTsv3wFnlV8+HooaGQCm/G7EBeQls5vEvsgRbS5ejWP3REK7tKs3MsoJktpVfBERtcgZiesC/frRKSvRwnJ" ..
	"ebfUPTAttXynPO/+ABF6dLzYk2ezWRcD435MZV6j0yIJjUk+jpq7X8sEp85EWr3cqUgqgPD+s11HXDpxTSmRPwhE+rvuWT+Z91hW" ..
	"sQITGCIc1b/l60j9YqhG+IriYU6HBsfIKNFqG3sYy7ZPs9H9PtL+1vtjQT2rZwyP4uKr9uGppNzkOXwpwvhMaJab+phyFrVwK0jA" ..
	"yQcDeRLCLlCw434pSput+46ZrkqNB/3K/28KJA+jiIGo8xfk2DNTWlvP/2lRRlpAuAFIaGrqk/eIXbuBas7wH9+fOiEhOI8F4sBJ" ..
	"TJzUVXkyCtWN3hSqup/hD9rJdOS4Hvysy5xVwyAL/rmmVdzEXxBCtsmN48/7UceQ506qqxmwjNTe5lKtYcu/F5s7Iko0/e3sz30/" ..
	"vJm6ZRGBI4Rk8DqxZvJM/xgCamptX5HO9AlSpUmR1yHMLgJgbs1km3vTBxggxrfq/734FWwVYdb9y9RNFy+KXVNqyLijdu40osUG" ..
	"OsyRSgdLkJfoHxDE2j75LAOCgeCGr/YP3YpMDwGRbVjw8irQBJpf1Tu7cCV1EF9biWSD6xdQbXgXQYqle0wnEhuVF6F2vltfFW2v" ..
	"9UK7JG9FioL21pj3ghfVFgTfHBh7+6L90G6CFNjYzlZmTPvoyGxKU2XXuhnRc1DNghzLl9wpgqW/0LVs9iL8WcPPXlp7mJF0zV+L" ..
	"Cl97rvVLo1O50nqgM5pQzQ8OAkYwkCzyIwPsqZChqOF/c2o5fdwb8TxlzxIZ61Uh4RHJhWysohAMAxZm9YdyTKKXSLBxy71My9Gl" ..
	"1Y5siu25KV0EcTi/rh7lO4zJLegB8Kiplj02f6zoDwGVicy4ZtIDlxET4ryRfGqUU0wSG9gsBvBh4+9zTOOIb/moYBbUFhbBJoQI" ..
	"7Q3mozoOaC17yE01km78Wcq8unSDVKTukT6ALbxLmYF1X17iUCbHijmZ8D2BVlWgmBHhmGMNG5aSJN7IDUawV6tRjjrpTNaN7FoI" ..
	"sBTRgX0IYeok5CguiV88GEItKOGKkOv+7n5iiEXGhRWuhTQg1c1djBI0uXfua9WE9Qnf0XlP/1RhTDJg8Qwv1pgFr62xWBkz8bTu" ..
	"1AFSCsk3khrCJqAy34aJX1Y8E19cazDdJba94dNENinv5wsr7ypCv/ZrNCu+ua+dpUHvf6A4ASo2PttHpvKLQKBmg/LAuDf0lW43" ..
	"Igf16896CkcwXLTLGKXm6E0lGv5BEgY/IkV/w5nQK/vGztKTMJBQkngxStnxDjV9q7IHGI7Opa0fthZBDXV4m0VIebttffiFDfz0" ..
	"7NlSbxfjo5TdxEQofyZ7Gygp7GwYQXeNIpCPoSk3indIiW2NizufP4c16L2l+s1Dwet1kAuNeDOE780dI+D4LYXEQJKsK3sZdkG3" ..
	"8ZTkoHRq/OBnjeroxpdLlnmx0XDXRxMRlTLTHkGBQ+f6f0HrVCp0d4Z/OY8WjrjyHt9Xis9933jA5i+v/TAzzT9fRvW6z+U+4TJa" ..
	"I30sn00OCj2Y8vojp35tt8ioojxIvry6X2xYfE+KwnXoBWpXmHIgzZAPRVsD2a9AJg4E7p6ZGxOEPwyyYS6O7uoDcbTNflmyue22" ..
	"PNsUng00XE42iNIA8jtiIGN+nyBf+2xMbzymO08Vl3GNS5SdypPOLYlTXrcgvrdSwYhsu3EKQfhjyKUtlxcaxOUbqcyo22za8Jr8" ..
	"ruYBlAzgqYsAnj/JUtH3PndxtTdpLUywb0LBKaU2ZYeMzEAmvs6zSUerf8rtjDDcF7VInVOANecXD7ECKpM7pe0Zk5emiw/RNYGi" ..
	"VgrETOnv1uGD1VxYDnf3UGuvfTl8rKi02EEjvbKaFOj8hEsLoJvNL2ZMnfo3V6cSvPuBgraA34fYOaFAw8aLJChUMrIz0G1nwq/e" ..
	"xqJ/Rua05CMesReIAShds+/Oi4LmOPd0CTyxtZDdlP5w0EP7dCeJkhQG8FnCwiXeMIRmqgpO3Du72PtH4k3aHAItnoFBlmOr0YxB" ..
	"mv4G+79fmi//+d/e0AfadzWmESQ4vmKmFq1jCqipALl6oIx4jXrbuKJk/EbDaLWgiRoTfsQ2RnSQeQzuCnul7CNpF+/fuDov/zkO" ..
	"nlL+Nv5LCKLYJLfp0iBizGZUZg1Fb8B2/pRacTF5NZNocEGz20xLQP06c9kSICkduKHzvRfW6xVtKpNEsJyscynNopGpY2jnT+b2" ..
	"VHkl0MTu5LIxV+VroPhj0bnx7pciM/2nyVAXGemBVrbgz9esNr+zDfkb1axxG2GV/BOvyh0YhjP/88tnjvx9SujePC49g9dfDw3m" ..
	"SoSEB8GeSk1edABdblU6iCI+6yjXwkL5zUZLZO0mzRo95Fb0lhK1vTNhlaE81abrNFayzGLv8nQ1yOt5ZEDSbFUuL2R8K+tYbQkX" ..
	"E0twsfHEPHmdUZTw7wM9tLD1b1bcop/V4jXBIF51iId3bUYicqrxrMTOhAanrstr7DZ3QtudkOxaxG5J3WjWlpE6JnpSG0OQU25V" ..
	"FdxfS878/njCRbVKjfoH7s9cZZ5uwYyv8l9SpXNTAcBRt1yxCMOLO2QhRb7MQCHsIO9WLbB+KI+k4yQ9IX/2dirqdkWJesNE6GPb" ..
	"0ttF+pBXUVDm/9UoC8ck50Nl6OVfR1bfWcAk9d1k2dXG36Ikr4ceFtrIra840T9a9icOMAFeQcpT9oXcpUIZywiAyQW7tlEPRKEX" ..
	"5Cg1/Pm7EFcrGKkOecDt6dv7UoFsUCZmvwRVCPXgoxXdcbTR+iRsOwql44XMViNG4NFKbAC6oC4dKMb6NTz9cjg2SXtt4Q+DCBt9" ..
	"IcqUY31a04IzvAf6Pj+pzOi09Da5hiOa+3aK6KT5uNgKpN+nCCor081m6FN3V4RzDioZpebvkyLPXSU+Q7aFvwLpVd/qlYc1D+9X" ..
	"At/eGYqLoDCpEE3qm9OQmMP6olQcqeCIkYf4MD9cL5p1PgeBPHpqkuGJAK6txlt9tbsPr/rJJ6cR3vQHEZhN/NbcFYLwPGNLaDzC" ..
	"U+fslXp81lEmZUPo9Tk4HXkR8Tt2hM/997zVNxKWLS+ZHNTTS3zPyPq+4MRZjOZRKTha4n67VA/ZLU89tNjBTBl/kBvuDeWWap1t" ..
	"DMKeIA3Q1wwr1hQbfJlMw7q5v4EBdp9rgoykX9Tp5AYONdy1byi6hlp95k5bakwcUIKfMzm8DI7gWS2vHp51bmstU2eFMIRhGNF3" ..
	"KjTjEQTOc+9IxssrLxObGoNTYD5I1UCwa7gf/r9VrYnuXEbWc2BtRsrZnMWGrSot71/N6Ym/cbgal8YH3sBUvSAz0sXNc3YQThip" ..
	"2XHk2Ywqevy/phucDN2PGoOJF+pQsDn000zpwTuOR/c4CG1/PQuzyo55LeasLnWSftELYJXqFSOBvIu1vD8KApEQh+LugtewK41o" ..
	"25IItN+/WWHmXflMDghHWL74HLaWuMbevjFml6BIiu4GafugYdNrS/P65ZvDi9Lz1If2eJ9rkui+e7EVbkD79bdJjqtotEOKHMSS" ..
	"uqsQ5HMtPJd4BNXhKGumBcUAWL4VrY6v6xh1zXEEVnmf6IG7xzGyXARPmGWffAWLnYf995xDLO8UxO46qwWkAWP5F6/7zxFQPmzu" ..
	"Hl7AZWaLYZmGhuxFVVUdn7kZFg/R2kegB97h5mB1iKFWj13oITO37Y33ZO+gyOrOaEmyC7XYO6gm4GtYXuc0KVKh/x1wapOdbulN" ..
	"mHU7r7rzIcGUqIMA423waTxhRyMj1DqEiTGfvaPBxgAVLmo9rVMWGMBeq067CiP+ZPMmiQSX49Ya0GIB5Cc1qyObRa+YS+wyK5ug" ..
	"bDidtdhEJkFYmC1fS9HUgc+qb985rAO0bt7VnXKG41U5Xnm6Q3akfOPSL6G6JROFyNo/9R9RIuad87r2pBNizRHh7x5qF/0YL5UJ" ..
	"9wLCzv5+WApqLqMEAdyPC20fR16ulsXkk21D4hxC9t5JApEgzIOQ5Kj3erEGT+XIBXgFzdLkqaUrG5mCanKTkGKe6goCcY6qoaOg" ..
	"4R6ET57BzjAemXfQD17HVuvwqBsA6+XYBls4muqsCOAnpnws1bF85ewtCnMDQENjJyAPid5sL+YIVfFddpG8UCINqRaipApuItrg" ..
	"tqOcfmI6sHrrtWH90v7h98ocp6ndkQD2l+dD77sk7wOxwYI1nY+JxXVTixjDJ58Pkkq54uiM4WL9eLevPdnzARBdqAjWseuArFuV" ..
	"+ohCnNx5yYry9UGuPBsR+Z56clPdLARGzZjSeytxJgaHuiYjpttt4JMe3ba6aY+Y6VpdmiTCW155uYzrDLnKlSoncwzJDALlazZ7" ..
	"W+VjbDCZ9tLd00ECPDMyT3XR0j+E6GDPEMCDmg3+TACXUWVwAo/c3P4XjyFPanfcMGFlmpV4L/PcOQv+1v7QWaeeUdZj2isO4uOg" ..
	"vNIBr74NQ1uFHz5xyMr3f50ycFQqpwV4itDDTvyIoKjI3KNV/GKE1iDH0JMhy4REt3Z/yg3C8gWAFTe2iP8l/kr/C1i/4XZOk5xd" ..
	"d4Ghld0FzqZ9A6k2cA4USBUxb04HyJidWBQWH4p2v/Lwyavb9PkSBSy9OknSMpV/J6uugq09FMlCau3f56c3n7RJxNd6D5iYxMO2" ..
	"nd0NtDWCaWsVx5uxzkxSTQYs14fafBNZhi+l0UKCE4qAoo8WRCrn77EJbgpwdVLK3p7wCrF0pm1ARC0EeDvpX37/eTNTCpTv5eUX" ..
	"k4bLK+wACAVQ48j8hl3kHMTeCubClCtmY5aAAOdAEInUAI/u/jGEjOa1LQzl1fL0ODqxcFiqBZ2oMptj1Spurv9fGLV1FLdambzC" ..
	"QglyW5w0MKW+tiysHSO/W+z6AvrXzBVGtOlXlH2EdP0+24uM5y7IDDc9hjKgtf+MkF54C6Rupn8gs5DKAtyJ2Qh8NxCkx8lWF4+D" ..
	"KQujNki2lnR5cTkFrZkV5D6mCLj8whbYY+sbWr1tfUNPM1uiw8yMVWv2p3ouxQk1bhFkLeg+m8dMsogRQikAgYaK04psW6puDf2q" ..
	"m1wz6CEnpG8nfBLWAt5RUl+CgtOapNhJsORZD5/IwwOerETCwi/hPMmROkJOsgdkFu2hiBSk7Zp5i6U5oe4mx4XDb6YGye9YJBm6" ..
	"wP35qodlJ0RZlSheY3CqU3uHzq/Q6y4mhs/s7bJAdG1w2KKEYGROXmZ5seygrhSNakTdlGIb4MlnfCk/P66I3uFbofQkApZH8PHT" ..
	"0Xv2RBOCQig7fhkqIkcTYgrAubQH+TM3H1zKxePJKrO26GO3r9rcM4mcqgU7IQglkR8w7oVw7+Vpzf4zASmSEdRfS7RD/qwrhh37" ..
	"6ch1cJEmAgamffGhac7llvdRnxPz7NaVwSD1R3Ri56cZO6gaFs0KQ4cHp92wxaSRZPWwg5RWCUIlA9nDJVbhtAafeFNGKf29xaa8" ..
	"G+0KdpTiVNzpPKf1s6zLi/Wgn/7xILsAxjVQiuJDHgkYxop/hLjGhkP3LDJ7n6a/IJ1IexbQD6oZOnucyTW8cVVXdgYfuuOjqSKG" ..
	"x/MOk8omHEbLE50YmT5K6fUaksgTiaeegn8GpnR6CtinTCedVlUJ1hngREA20XKcX0UeOr7HZcYOkcUnRW+r66tEss1AGhXziPr0" ..
	"CPajRzPCRqFgqdjOEA0N4ewoZV13wPds8vHEhshKR+On1u1z3n1f7cdg6D8nl7i4sqUznllLxpb/WzF4QnuKuf/Yhkvk2Nuyxwgz" ..
	"ewY6UsFpAOhf9cp7vJJ1/ovT2s2tIy+397KKAVZu7T0/lZHjADCcYRaiB6aLweA/HB7m4CIqWc1iHePLTijWAf21Fsdytf+rbwX2" ..
	"dasb43RcTgGQ5CmHe3FAleTSZ2Ue2wmSGuwo/5/MnUk9Uk/72Kq5i6TAVhM4gwNaHAstjPuxKA+SChVK3KmNraxbcrW2Lh2Jy8tp" ..
	"Xv5qfKU+NYjvB8Mzh55UI1wxrpRcINhv0wi6+NCss11ZHddpmmADryy3lAEbheG5KP6X79t7QL9e8tXF+NFOQ4sk1725EUkzEkJv" ..
	"2pFbCSJyktrQ8dWGtXZYnqQHBdIrLpIQbkIQEFvvrLLwgorklYi8hPcLb/ti6RFIqrm7SdMm1BQWAOFKP6PwE+kc9sxX55HM1l7R" ..
	"wobSzY5A4USBhT81C+sO8MxlANW7+M0/8E3jxKHA6iaMgv9ANJfaOxFL5HePwm8vXptrJALqbHu5UACMO0JG3gLgvEEBQ5gGKBZT" ..
	"POH0pFqxCj2BD9nFPPuRtwgOHDDxKs2yL2sCBblKd7LHomF1IGmszvu+zfqEQ4X6zhpwhM2XGX6Q6pb0SGWLNUBdVu7Zl/Cz0A2b" ..
	"+L/C8QBuy/7avIY8b2RKm25iwnlxuCVmFU04jETzxfpiHb067SganqJWo44zU5sJJIEkGn/bCxJT3N0R6j18C9vWuyILNrerelHg" ..
	"DXIMvgiYxz8ET59X92jR3++giOHFB/lZTxSaU51b7t22GqZo50FYWvxZaRNz+PKn/tx8aCZm9UD7cS1veKYx1dFAKyUvoREjz47O" ..
	"/ClMUDxxYclZLNKr8ExJQDL5notoTEnUpNQSG4jSNXIhJhryevsUdOeUdIOucWiDi2Vq1OjerckgQCd0yUYby9QpJPEha5wOfwEI" ..
	"72DbQX8YkKik3OcHOJL/Y81TnidCs1D4YxehL5dbDZdx6Zw13cogaLGTU4n17RJtEHZlUYEUj1bpaGL8vBTxhQHTvtQe2lC3Yvfe" ..
	"trskZ7r6dWfgBnAtnFRjt5iSyCtM4mL5Pv2R5Lac3haknfOIpDWxantgT4/ZA6Olqi/faPEYqnqyyq/YEIlQexgMmV2igQFXUBP2" ..
	"8e2+Qp0aQfQBmNmYsbsWykw8jLV5fCsytiWomsAe7WTUHu1+TGTeQMN4bYZa4OG9WnTN7xEA0RywsIYiPeyumB9K19wG+tSdBSww" ..
	"fq4933XcGWcPtwIwO8dHHJtBM03lu5rWTalFlxFwcm3Yr644sMX8e2mWp8p4ep2qnD8PFucmSsqF4btr9fanOAfj4XaycI7HRBeF" ..
	"qU5cwppS8qucLO/6msQoYLLx+PV7/2G1OhZeL3uJXtgtV+QB1Ix3QxrL1nyHVAJ6rHeDZHkO6we9CF2DJTVEGFsOyei/yq4qK1QE" ..
	"HKHgRzQs7PUAKgbLrA2+vXQ15aAckXdJZyKp2ygI1MB8UnO05SdhYsGqRBCERcC0YgQyvzK1cr64GPYxcmeUOLDoMxTYmmSRPiWC" ..
	"hS1BH9IRmAPM5ZTm4SGjIXTy7UAvOjimtOq/nP5vVNkCOUJteBXd8QjhXl/FuhroerOxSFBHfFU33Y2RNdQsCZi31i6NakSuuA20" ..
	"sO3rLy44tDIHp7yxf2QTBhe7UYZ/AXeuzc6LkJgnJq0QV3xajAUPIu7d+82hsib5wZxXvMFScdTsRG9hee19UrTQoskvvcda6UTY" ..
	"unTssKee0CkRqlxdcnEcqEzl05AlFKhG1VLqYmF1QAAU0hJ8WQwPhzAukKyucpNL29VL1X+hRq8D2HZd2VSiRLCZk8zF8I/vyOUK" ..
	"T9ra0abA/Nmo7EB+72OmcZ0KxZIyBu4GombDCgLznzuAcfNZ0g8TqIVyqHsXiCNlj1uBgKXK2FOZjWZUEK7CV9Bxu5r23QvobCOs" ..
	"8bwFqBMv6csaSSAKSQKhmk5VrUw+BKvof3vf4saR37XmqBReqjzY8vMa0zcEn7902ESKVZD/2FQQQ46UtrQgiwk4xXQQQOwmlPcN" ..
	"jFdEWf19d4VL8Pdr0N5cipYCgE1vEQYGL3irSDO5J5IvhpGgOunfWlfjRosTecyRfQyOZOaRL/M5cVs05pYhxqjrgV2r+uB6BkTp" ..
	"TGfqgLTKqTNV5D/uPk7MZ9XbHceYPH2dyZKxywIBHMQwzKdZtZeSnF3JJXdS9W9hmgvnc/C4hxpSqqkRPZnpGt2K++5Qp9y8BNgf" ..
	"XsU8F49mAMopyUs7RX51cTbScabHW+JnrbgoahvkqPwFuWub55j0TEAcQiEnn8cgTShNT6sYCcvLB4xuvFz/otp9IWMFVdM9Gtxe" ..
	"Al3vUO9ywetuUanEPqow1qZOXd8AjX3gYKeCCRNRqfNGOEox9Lk4MvUYCulaWFEvSZda0uw4yzEwMNrv2UMgSrzCRPb8Ve1TY+WY" ..
	"Mhco0hklaCXWtB7gYSd5xDatkBLvO6mtRByk8PmIX7WlflCn5Jm1JQ8af2wPtJ29z4unABsn+Ootx28uzTkgrjBhNPYUjUyYAQUD" ..
	"TxVh8yNVyxBz1060LoAwbYMo+2zYmvip0zmQq2WIgn77rlplJmLZy+ddgykjVrZCMnqZBR7VRCPWynsiTCH/s/jKFQCK0Q8xACO4" ..
	"ilFwWbeGXhsW/hSOH0ibwYLYSBE/iiHshnnD70TpjyMZBBCvHhledK9nldusGj9K3SvO4XUX4xHCZLdKt3u/Rky+DSoYcmHUT5pP" ..
	"V7id4zN4P8i2xkAKrStbg8zvkFxkytlpsL475gitZ3KLMo9xLXQ3Q1LmZ2f9lQq7g9UDfsiGL0l2FP0PzaXMTwdQpuMRQsjKXUsv" ..
	"aOkgh3gO0ekepZJV9yt/FxIHm7Y3alPl9MWdkHZ/JHB2rDMwG7GNslV+mRjNozJxghu/Bl4g68mgmoUhGTPyN2tN+tnqXiqjX+Hk" ..
	"na7DWUPB0cxcwanLdTpIRRuxsoDGfAHbyISxVWrI7cW6bVirNQiN5f5WEl731rm28XQITyyTbNc/RFDGScuY30Y/cx/jqq+RzPL9" ..
	"+AkecuWw2MyTJqRtW3aqD3JFtkn92qZEXgxqRVNcOQYzP21j8X7fqtfApKFX3GcxJxZGCeTR049txx1Y1z2oikaYNNjhzax4n3q2" ..
	"fjJnaM8eeaDXyfCvl28W32clLcc3A0FOHv13c7Uj4KvFS7VYZN21soxWL3ZydUE9u6tiAdJHsnT1mDGQhLZeCRURdWKS6Yew+X8w" ..
	"mhKzve/QFzn1TrjHqYNisgCFL2QCgCqHQ6AJDyga2UQ/gQugNCra1R6Kszcrx+2ScDdjXyDX93nvvvsBH2EEZ45xfclklkDLbUTX" ..
	"6fPO9cBqBcTtGByAtS7XP6FlbSz2mj0bk5avxqWQK4Ef+g2RF2eZEZjttcvvJsi7jQM+IQOscreUvAcrUpjV0Cxk8xDq3CM4tKMQ" ..
	"cj4LQW1nAmQn4jGe+/A9GstFYYqLZ3DwZZmLt1sm+d2aZPN0UukZUNS1DToQlMAO1s7rpBojJ5XUIRiFeRVogQy0bLaAwexxn52a" ..
	"CnnmrB4Jgx0LqtZxbAXUqLDHeLCuZ2F87PC/W1HLulSt0taRYWJRKqZtg5LVu4FZUZkU1SVXv2SnAFjhCRmyomNkEJ6y9o1Xx8tJ" ..
	"cF5InxNXKhDb0NIdIRfGFFgTnZhWectgQgLYEyZw6w01XuVoTyv3ZntyjlL8FzZBkcpUlu2eIoFA9W3lOxqVBfu96cj+dqhYeO5y" ..
	"6RIAKIvM1EA5+PGw0/mY5wGwfoDqgRwEURW/IPUrrUXC6ZPN8TJPQwelQPp7pdg19y0Q6vDGOMDlWIUwcDO7pG3juyhgpqbkkMyq" ..
	"rsl+GKk2b4nDdbK+DvuGA4ObtibdV21kdPFe1rN31Xfre/WxkzOgZWMuNPpBaySFUUENnTCr1bWSoR2dYnoMsIYCNa2rSpL2ZRWM" ..
	"ZQ6qTGyfOuOP2OzcMN/tqr+tECy90qlapLBBiwGT9u9pMSC8Je5D/vVBgE1bVaJSKvIhbo1StaC5MJ7/Z3qzZ5M2/E038sumtY0Z" ..
	"2ybH8jIPjnvuCxlwn/hPuRYxSa16FA9MaB+6E36n+5xuCPhdLHwiD9tuER7i8PRayfwsglMOLZioLOtWud0c8vB+aANL7mT9o8QF" ..
	"au/NRsvefA+JN4ZajvPa8tOQa0oL/Kbr9m59daQK5jNyKcgesovpX0n11s7C+CE+MUM/gwgy/dBgqAfTTMOdjpnfiQ3uWbtomKzc" ..
	"ftnEO3GTbJ2vs9IEHNyLpWF80+qaivg2TznH/zFUKhOupAzXSB6/atCqkZ4WM5qFz1hkImigiXmyJ1mUlFkx0l017roDFdc8iKsm" ..
	"kenHua6/TgIJiwotvrdL/idt/yYj9/MIquCYi/eeU8psqPxDdSIKXU7apz9yDEb4aAkdQkti3vMEDtPVW1GfuE8KtrPdlnOCU1A+" ..
	"50KUaeKs/fdEnLMV2xOSrNyxeTHXzmSifgxf7AEeH/ESFXQhQR6NKXBAfbNTMT17PGg02kf6R984AZKT6j3Kf70/SD+lB6lQWqkG" ..
	"0/C3tHkb5wpeqH4GWCM+izqNp4ROca/aRFp1Fvu+h/HAhtxkaJn7J4varlkfFYhVBeH4nEGni1L9pz0zDtpFxDErdzTpKgB0DEsr" ..
	"TUfb1U1Rr7vg1y+4um0DW5vla6ihnnq29RPPkFw7k6dZlZB6DkIMN51FEVKsVb/gxrydd3EVdY85r8BEsQlzBE8zllnsbu8rxcfE" ..
	"OJBMFe1tI50nnvy0IB2rwPQ7ZxSaYgvhLSF/aJL02SBVaUPWozWJlDpM2IY5KTL7XyVBTLc+vdyvlMmUULNVpdGRY99Iv0RxIkFa" ..
	"qiuRulFYFmXSgW9Ku3DxLWY3UBkcP7VZnVqNlnH6m3H/r8n1KQcURGJLLmfaEBqSlU3VXmLQlNhjBIqw/xzVOjlvsg4/7CQjzspT" ..
	"h0G5qHqxKbBaoeIWgGLFaZeoemmF8nn89uompypHmrI80FwGyCKBTMu1zIAtPbf9ZMupwzV/TFHvFMqf8Q1QYaCmZhvB7uFRSv3v" ..
	"3s6XeqzPcm5DXp0dlHEv5e719tWDh7wBZNIN10SYHu6PgPEq6rJq45ArgQlP+giYZ1bbNC1Fu5NO3HUJnNzO96o3SdzHW/b0NTcp" ..
	"KJUSL3whQTd4ty0zeDRQiy71UMdiDF1Unr4M2ogVL8PeD0e8DF/GFpI81zxqwntZksLLtcmKJgEcwm5r3dGHeOQbC9M7x23Rz1yb" ..
	"/rjSx6D6ZKwnTWU1yC8qUQpvRJZpZI5CZy+aW1DNU9ZoSbvYibtWcGe+sqI/X6BqYr9d4J3HUa66tDDTxLPwC1IAuvj0EnDsw+1T" ..
	"8WKk76aJjszdnXMeuRKS0fc8XbRrnmtmO2WSVlah9abX5MgKxk2HRyzusdRGbA04NxIVhKUmix0HbTQj9ZDy5d36isgFMCVQ6iwD" ..
	"25suPnVxNYvel/fNrRDx2ASEzHOQgFQz+yumJ6KVwawVnYG/I4c99XZxdxIWumEHBS9xxJtSfyz1BZwiXS9Yz14E+fHdvuUevTPR" ..
	"sFVaTi6t6NE9xNFL933rdrMjLCat0/cMeX3/EVOdz50OcBWi7YpDEj0gwi7uFOmC6bxHaMSemM5mOWMO2A+MuS4BYF75ddtcOJ/X" ..
	"3iXV3H/iZP+e0DuVpG2DK1hMtVavSGZklSPgfjmVJxeD3VQBczclmCvPNYlTSoAYwGycUNxfrTHdqNFt8/2rapl/fJx8sDf1eIpW" ..
	"M4FXNo0kEwhHrjH88puVKPHSdB0UQAb12FY74EbudkTiHxaxV1oIUp6bIDJQhL83Vxw6vxFERNziiQJtFb8ibXi3uQLk96/94Spt" ..
	"VhFXzdqtuRrNLQhBrU/z0vYjLm1Zr/0JY1FkCKKpEwlJS2kmwIUGPYLYw3GmdvAMXnhbRFXOsQXUFx22HoEGncvL+fPJOjU7g3OP" ..
	"kPUwuEBigwAWEWJDb8C+D3CSF8x9/3FffkkCg56Ql6twlbeKmE/0Bs8CBKNbGYeIcUb92d6U9nZA987lisKCI/jG5NFIs5w6GrAU" ..
	"EQU2dV+8Qf3eJB8PrSteWwNq0hcMziRRRojVU+McJ5dk6T6jvuIQuiai93FLrS0KOsUUL9lG0/3kqS7d7SgWtuzlStzkeefNI9wh" ..
	"Nk+app0Z100rjDwpIGCdaazFycTKuh1gbsWZ18o+Qk8krlpuisBYLGOiyYrAWUOVxSrvZS6/WtvgeNtbSZLAzQseFBxZ5wYjxXIw" ..
	"jYBcjfMUAsA7H95fJSXbWNs0D3jNPJ6utp9pwZYjhN2ieUCfezyozwnMZXgZZLtyBshsPsl80BOuUiD2i3G5IQjPpSg2Sk/b8tE4" ..
	"a5YA3CEEDTrkg8SArlHmBKbTLw412W3XAZc/DGT1QlswblkrFmxR02iVCFrXJaAbHxDlB5+VBwjaNb6ruSeynOYmcDbBMGFzc6z/" ..
	"HUzB0Iu8E+Ys3Qug5epMbjwlB1MKT0I3UNzqYCb8qZeJixPO6S+JVIwxPIj9hfw/a0Tr6JO4Gkwm3yrEwI0P5fm9mJkv6iqOTzQ4" ..
	"m19JnThjoL+XQGqkcKJfFrcrcA4ln8eR1Qc/TyQst4TvKDn06DsNKIjuNhszyTUUQ/ZnbJ1o70d1na/LbStL8ARFBJt7fRTPXcWg" ..
	"3Yt9h6swCdZc1+tVAub2rB0LOBgrRD2KjIFEoJfkxtANYqkceUTUKhwJKcxpMQeXI0+ig3B25kV8z55GApJZP9riuimqnzsVIy+l" ..
	"JqcGNR7SHFm3aHKeojA3J6G8zSnZ1tTFzsyz1GYEjBG9uZ8NM171ak5n8800KtVNYSseXFGG//kwnU1EFq/NoiVwiZ/w0VfLrsfR" ..
	"13xAZwkfbRUUwnWupOnSXb5vz+N9JBUjMCqBppUHUh2YwayxpEOl1kjOUCFjqx2T/TxN6XpdY4Hw60Xlzjs+/ZLtZhA+dGX+PD+z" ..
	"DhD3phM8pZzhwdJW3+tw+Nq9tdjbqoHie6VYPYbQXVAK75/ydZKyrMlKCKX6B9heunh0+Re4f5qrz+kJeclc2R3mpdSnRrRKCG9g" ..
	"8wQqkpOPkZ5l6mreQGzU/Kl8q7QHUHRSmG1cRqCBSKyhkOhUJ4m7QrllVMWTR4oqtrBDtaRJ8O36E8gejfpZLnbqySMstB6CH9Dt" ..
	"BTjzzFLMrzYmxekqsELWdDNDaEkonE4ltbqeKpkJdOdqclycdKxgxT4KwSNMOQ7WeHljBxo0uF7CO90EIxN8U4gdp9qdTL40YYBH" ..
	"cTm46w5NXPvuwi3O4C/GC1O2PTjQw1OSEI98O3X/SiDg8vjzwYKu3iHCChrW/T/zBXG/t01XXusg7HEpEGXnDmWpi8xMebCTIcbk" ..
	"FETeeKHRSpIsp3iWUOHSQ3b46TVk2zUzc05/nLpUDHiX+w0MPqVIwksXPhfy2kbEAZY0NmaJsfc9+xDE1vqJ+X29N/+0Q0GHvxkk" ..
	"Ipaff5Gd5IJ/dJ9UQvt6vu3es+RtXRdadqdUDAMgXS7Y+GxYScTnN0cdLZHkWwfwAw6O3SiyeoBWoSSPnN4rwX2kOXmzoa9E+w4K" ..
	"2K3fwoeVgwwleZEN0YizNGQxZUOp2Esv+zgNhdm5o32VJZ7wiy8EsXP0CP4aTpkqZlM0WUrR+Sn7BvMIXlPL2Bv/VK9ijbTXw1vD" ..
	"FPQZZ89M6H72I9Jl/8+ylCEs2D2HoCGyNjVDEt0e2BQSA122MsUA917XmoAu9dU6vdY92OUBX+EGs5itM8Jag7DJOuTbUPRyyfTi" ..
	"LWhbKfQ5ECtCp73JgDZJH1MUZVmiIwPLLIn2pDTl23kXbepYLLUahKcXvDS5kQrTCir8h+araXKPicTQ9Fm3Z9jazdPWVWMR0pzN" ..
	"ey4ePKtY89G+cR25YM5JVgbMHyM4cWOZSUCYe8B2tHgkw0Uo4tvbLbRoB+jub73sHwFIey5ytnuxIW+z8/FBo6m/3JC/98c+BLCX" ..
	"v0PKW3ekrGNGMiJD/uKTxdpLHA7QKJjfmw5damOS5Bi1GZWmSyxddBKjFwVvpbWknnHEzq7sWjpqkh+spCIIfS9b2unMc50CML7p" ..
	"7MHC/vqIV8xRn+SO8iTj+/c0D37EucKHDAq565laEbsEVei3q5OMtHclu5fWmJT5xi1SK5DtZE5LHKVyrfgvBegXoDRU8R8Kfjsh" ..
	"faMHJvu6Ni6gxvByKso5XNC1SjQdn4P6QKMsevtMXfOa3mH88h6FKFuotLNWJ1qbmYPvz6ZnrmORCYAKL8tpXDhaTqt5OetKfAu7" ..
	"uY5a9yb3e0s2/Z/AkI8FpCZ85nbJFf1X9ICw4arNNdveO7a8MoKIkQlWnzLes6RSc/IxNW20EDc1ThKwkGVGleWUqWbIbwXCMUxy" ..
	"fg/cGawGvNysKBUKkYN2ttia9YyAxKxpQww81iBGgvbdNEsUfa0+cl0yyvP45t0e6ggsMwY9o+KmbcAxSwFetU6eOW/SwFi3Vfwr" ..
	"tVMiJ+t+keIFP6+2K4PFF1EsULJg5mI9ZXGRVNeLgKL9He6bujOygRl7GMcxpK/1+M7CHSsxugr/HJH2PYgddBm4jZHl396PdGB7" ..
	"BfDmsLXc36kfoOlcZ2WHGBvSmj+kkaHPZ5cKDU7ZTamL+xgqiQ39REFJF1hccuyam3qMbZi1oSEWuIh+ZGZHhqUHlDXyy3Iu6d+q" ..
	"JnXnYubaPm2RNvh/PXr+6HPfPilcNuG1suDthbmBG7nIX24lVJuNSqQeoGsArZBRn+sXCQVtaNh57Kx5/CN4bJR9KM3Gx9WSGBJQ" ..
	"EdUiscsyHAuA21UkOqMu28yxztUMWUJ/wIU5gemR98+0erxwiclAf59bnsixn40H66vVIDGOq9aG/u/7fq4mKwGrWn1Auw7Yzk7u" ..
	"ywXyt225aW4kOxu75EKu0+PNminlOEgXlqhKqdeSuuaVgK8Fcp4HisC1EcJNwOVeY4joREuvIWOhUvjMK02juccnpgI9oRt9pyYe" ..
	"Vv07wF2U486SjVt66DXJ9VGAAfkeTfi0Z4fuVh5a3CH7xlIPkXYenJypqOR3MOcQqn3I/ntM7tz0ttdYo7XFji7wnw8fnl/7+Op9" ..
	"+QAHRFiBnUC6T5Z1JzhnXPGArXFdY7f15hPbIb2oarxyAozglqcxyI0mLpEELlaz7nIwYaohdpeWyaOwB4Ati3ccVGdwsbRgMz9k" ..
	"ciRVS+M6h1DujWswCT8nX0aBSvOe26zoOtLMoLtJ6wtFYdtPPw/gaAUa6AkQeRClQ6pkkCTXna2vlibFhasNCpG4OfbIuqM1jTnq" ..
	"huIALT4X1mYA0sWW/WfKr+zINfI87q7zuQb3QBgckbYv0Zv0H4Lw650NfJEiXFfAUi9urbJDL48Ql/dacXkLgTe4Z5KBjTCPY6TB" ..
	"vNHpsE0NC+cAOqO+71VZhyARufPCCR/sUSnvkXVPUcS6tYEaiJnPkV/Ns4CUhlLnZZdSD2jmUvRG1ZIHtR2sAl2zN+dSq+P99Fhc" ..
	"77iIvM+opPI3YK0Hxwid91hpGnoY2sjYibdy+SsnWSCLWxdq9wA1LvtvUEpAr4L/obxX/85CoZ5DI81h9GoGlWfn6wKeYQHtrgdS" ..
	"uoPTmwUMRe+IoPfgO9wxOp3zKXux7fKbKbh/4OejY/z6i7WAR7bpdROelVxqTJ99UidSN9oacptUoXDc2HJeZNbGpWKZ1syfwkZk" ..
	"ZszOlW2tGpvCBPb0V+nVit5r/4DgU5Fsg3CqrMDDBBSWm8/sIwjkB5zhr09nPTSP6IeaTC9CuwKbhwI5Ga4EMARo4zLSgHYeooKW" ..
	"nCpcE9hCDiT7oyP9KGSHa3zbhPYMH7ZlwuBK+K7z5VFJ7YO1OyvN8Qq8im+S8xVxaR/E/hao7+PGWHMwfdUtp+fZzUJYUcvdxfCc" ..
	"icC/XH0B628KE0T408YKadWp9yZXR3xwbJVF+03hb+8U3zTUxCkGPEGA4N8uOAwNLkv9qsXIgAxpG4HlNS7RQ/r15lBM4FNl1rNJ" ..
	"ocy4RtXDK6LvKfmpThu6L7dO4LdXZKjPv3DOtSKgYV4A/LBAmHdXaZwdfq+R69CO1Hej+VuFT+n3AJ9HALanKpkTl/aCOWqF5Njb" ..
	"3q7JdZD6FCWR+HYZalylrckaLBzl9UtyC8mGDWtxaC89y5KC76rFVz+vPtP8DLdd8A3uV2Qp6+jX8gtjv33v+TjJfQgzWD8Zv0Sf" ..
	"jaU6+wzhqsFYKyydtugwdre9Db82GrOxLB6qAsgfHJgelNedd3kLXwceRY4qIQPBhwIiR+s3vQFMobPzGoa+B477w/ZXwbJ9BkOi" ..
	"hzJ6PZp+VjO0zNouCYh63x3w94/CZXLmBgRVISmFYYebpPH+crnp33+HOLveIwR29QX1A2Ym83Iu36NeCc9QEmG5OtTMqxfCQxjs" ..
	"U5gZmFHDIzm/4g3kFE2iYFYwuba8xfk3aogm4QVDZJ8KcWA6+PZrFbH9fBNNNKAdjD+S/l7JczgXOM7QUPBOhJ6dafJVkKW1c9Dj" ..
	"1MHwPFYFYnIb9zvbtux7SLGrdBZQYNpESsWESb/bpOlg4LeSqXcJuRm4Y15znU4E5kwTMKoqAyo6f6/bRaKh5k9ODsckNBRnieXo" ..
	"Zi56JnNugfnE9PaI50wUoTUnliH6f4ZmgFxQxq6SDxfdDHy4H+otPW4pfG/hGu0XaisH0UPtY/HxVcLBMOrU/af3GFyHX3JP6Bx8" ..
	"prYVKOA5yO9q3bUXe70CUdGIfxPQc7WLJ2PJYCUY63O0bcazjT80pC4JkLr5l7uSWL0FqJzCifdGvS5N/14Oj7eUBtUt7GM/IeuT" ..
	"tqy8MpBxXwesbyOT6WFTwlc2BEgBYNVDoMllM57hT1ES0EvZSHhtVrhoEiDT3h7mBNe4XvxytuE1DY43YGnsoXv+5+AaGqTw+7V5" ..
	"93suZr1nr5rkDFo/7zCrIOyw5ayzZNt0vzwMIQBNjjFsY7+RZl3pA1vBckZpFB4gBQNv4BfWCNoXNNnekXOc/kcS8aYwsbZzO36I" ..
	"HsBKggfbkCfN5BQurmLrcK/dKff3hT454BVlCwdYNWjNlR+MztC7g+Ip0PR86Lch5DMFhyOsTVTmCzwuKq7lFf1WsaxU28XAvaMU" ..
	"GyOFw6KY/AoNEp5eVDXo9f/IgWVPzyHpbextJFUDU7x1yvCcSmaCjhPqFpda7Vz0KTivp+TiM2QOLu96RovVl9TR8JE3EPoYXGgi" ..
	"+XzsjG7UYeZEcxZ7MaSNAkmB+H2uFf3J6Eof8ZlOVyHMYoXi8V1KOy2/217nbJi1bxkglS/s5KtIIGT2pkI+CBXM0x1tTuFv55MI" ..
	"rkkJ6lPM1uJFQPe5uwZ4QbEvVnBZT4Ss2MDbu3kGkmFeLQbBvKeh0Yqx/Xe2OC3IbR1A8sU7bCSrSDdsiGT4XbWGsJ/4phZWqrvJ" ..
	"3uzkroLTUfFM5aHpuVOM/E01bpz/igIedBR9pjINZLTl/6b6MLChmiifXmNoK9EglDvMXL4OVU5PQQGeAeGxCg+3gm3jzKWxw/Bd" ..
	"gYworttRZuaPI4YF78U7cLX24q+qhGhGEHkS0Zgc+7csXh0rHQRoTXZand9tasdHvA04VopkDyzZcmN9jrMOT0eJvn8/OybX9cqX" ..
	"Yly6IlLO7NayeBqsWWap2YQxZQBrGYYqY28r29E9GaKlZ/iX/F2V/53aQC7XJELuGxYbJEbnp8EJ4Amb2VEBc/BI0D+I1O45Y5qj" ..
	"s27Ib4TAEO8gDyeqx8W//IJK2rUlxL264VKqgMM4hYVgoufJ/NTBySIQ/c0D+sHay7tLZgxDDHR1cdAl/Tg2/3eDRgdXUkHbbbkW" ..
	"tUVWg8nPwcBlfYtnKDP84fSqIK7s99wAjZg9WlFB6w7SWQoxJoKxroY3Uc97Ieu8dvY2HZtNs1r3tIdNj+yygSDMg207KwZTYkT2" ..
	"bPHmlr2qYh9XeN2dCmRt+o8yIKahU/HEkcrAtKFDwxrZL6CU9EsyXMOQWhGjJRuNiWWDxPXSm+R6f5FFdpGPsYG8M1MhuAhWr4+k" ..
	"I5kodGtMnTUIVeU1ar1rwjvVj8o1ALDR58DXOGaUPInvRyH2ZXwwtRl3aXjMkoCfbX2rpUdBwm6wws9opCChL4zQVp7m6s+dbbt6" ..
	"3zrmxdW/dJSMr9rLGBqvnk0fCoZTCGdSI68iVxUoIpvlxC3Lm9Yjz7mAzJHLNUDrPrCGLg0aa6Vpw/8lg10XgeandQH3urpnfk5j" ..
	"vQUDomvwJgdezQvnzcxkWArcaj2jYhDZMTGBGysPwFkGky5uTeliPI0OppAtjf9psGkZwUaVdqLuiquTYexJC+T7QtnLTUiKpZr5" ..
	"m2fhHvH2wt0TGkVAs6RZPXo6ppCP+S/mdTjasE1mozDxe0eoXsosIB+E3vycGeKrukOiisi2awAjklcw9QHLiS/InzXEeB2eKZmu" ..
	"eyIlWGvRpW6DUmtqB+jlgaWvSSAL3JoBob9bRZOtlPyEB+1z8c/L97b+6+aqnkcCK51RRuIrYL2CoBfKl4tyAsfYMxs0IfNa2Vxh" ..
	"+qaOaTwMRZ/SYJ7L3TUFe/stLugW3752matRG1GjpSVt/0Q6T8DT0UrlnbdPv9Ev5st8rd1segTpenhzrQFfsGR/p1NPd4ei3dtO" ..
	"laafhQaADNl+RwvST0xNXtquwp8MOV43DQog0pSdpQ5Zqo8KY+hBvOjsJMGdv6ukm9jLjF3iorZ5T6vVD3jXsyPATi5cUL5JVR1c" ..
	"0ZXxYLpJZ4g9tWOKSt/2QJb1p9ZVHcT4/d/u/AmwyFhgfo8mc2CzQhcG+DazURZf6NduUVggWM2GVUUUVqQYOjVcflXzCXNTzcQx" ..
	"CAg4ebEd+1Ym5sHjekHn/aB5yeGG3F7UtwkWOerMMbYa/ENNoWEUeVPVsPHCSaw8O99KP6wZbQIixBRcsMniPX2DV9xDUeDzYw33" ..
	"iE1y/31UM4Hcuu7ctr6/nKAKVnRmioe5yGLR68IVjRh/EzX9ejvXYq+dqrJQH8cp8GPkjwqRKQ1l1kSIc763KsDhjytKSU3E5R0u" ..
	"AdWjL47tFO2ir22FUrzS5X+zKZIuv/MJMdlHltAWOlsgqzUIbeP/g+2kYN1AhIwwLEOfNkZ97ktUWkgQL9plZ5XTCwyRoCF90lsA" ..
	"aN5jHAISX4YwhTUv6a7Q40swBG328IDvOFrJGa4TBaiJUCZpTLUyKu+lKJXsjFvN0oRN7e2hnKd6+1fNhdIWY6sl8bZJie72YWde" ..
	"lPmXy1U3wGjg3bn4zdqZYgGT5ao0gJ08H4CLxqfYjXECRPvc0BB+jryChqSe185IaJ3mtb7kGHrBu0b8yclz86t3pxhjbiP+kGIK" ..
	"DM2JmPGIDaF2wwAVVBZ7HGB9HkH3xap4vxlL6uFASijA0G5RXjclILoDg/YQ8ABnQNn/F5ZSn0O7TDp0yjq3LfMo4Lm0CPtzbtHW" ..
	"i1S+aQLwb4K4AmsOtIlU44ddkQZNmge17ZPtzId63mxDtNDQSIROzzZ5a1zTDdPC/LPtRqDwtJmAyYcWhajwWwN37cgPQghddhNb" ..
	"32gPoJIJtNmauajgj+FC70sSkcu5sCsnGHQ/HgR4x9xjj5ctCJSUvpQyTmRXJBqHxAb3jW7mKfg6IR/Ze14HY7rpbZQ6/61azSuQ" ..
	"8+xCA8g/q43ISXhoF/Z8GZXGpKuME+xLkHt7rbOYuQB74SDiFCtRkg409/y/qbbR+WxrPnmprA9rAQdg3NNhq5K5BlA87NR8MOLP" ..
	"9AgpT9nTSi8mdzTIitG1V7x8vTL8Cep2UppuR834JMh0YF497ErogKjekT59ONNt26I8Ux8kZrRXKdLOvIwKpAiSY/OuolDHWgsK" ..
	"/+EvyBdL+Qjjoy9s2Bnp5b3IX4hXaQKUoQEpAZn91rf7Uawlq3vkxgS740Gsd7S4i4vIdbMYEqLRdNef6xdHPERMwIfTpWAeTQSq" ..
	"A1HuQMqXpWYSim8NjLXHNAdQecWgnEmYmWXu/DCiL2R9tIxQQcBlhuAvUOYOyy+r3yXWb+4TTtr5srTofrfeZ8wLCVGJ99fMHlpL" ..
	"sn8gfXTrWQycOMtKOsnAkp/6aNTZCBd3PJIaaHFTsmwJuPwfZLLWsx1v/gRnuyt5S2QjzctNusJZpYXJQKhUKLFDzOkO+zU7V1z7" ..
	"lxIXcnTncCcjO4ZxenQPKLDhNeR4O75OOxMUKDU6rMCeBTM97dNsaD+c1mbx4WeLGIKIqHtYKoX/QL0tpCY5LjEw+Wb2qYBoJq56" ..
	"rJ8S1Biz8a1+8aaxX8p92IfimJtBgYmLYbOE8crXbBw5iPPryiJvy3bLCtRXlyNP6e3IKYRf2fuCmIPQ3AvRXEO9MWl1Ma/U5lhg" ..
	"lpgN+faFPAmRo8Y2TcvAwBxabREXpUYqjMycgHyVQRlzu1Tzl1HammKefwQsa9ooRaK02M1kHiShPGrVNTVjqIVNMMUgHj6VwXJO" ..
	"QENf4LEBcASOEQ+7JhkP9s8fv7VMH0D+fD9+tW8xiT2fLcXGH/qUJOTrH4ZuvD+JrAVoyVGr7hKsO8q0TLrs2qrMSVoeNTrP/0Ta" ..
	"HPq9mll7aKtkPM5yB4ifGQeIGo3taM9lUSrRAA4kD3ozdLQTfLlMMjHWHZbwbKDNtSvJz9rGAGf8dRjjFAG6BI1wdzhHWl8ZXVnw" ..
	"Z1hjvIYun1qw3X+7H8het0cw43NlD+MoJ1o=" ..
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
