--[[ DQFarm Loader ]]
-- Licensed to: Tien (nhieu), Free for test (nhieu), GNURT (nhieu), KhongMinh (1 thiet bi)
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

local DQ_ENV = (type(getgenv) == "function" and getgenv()) or _G
DQ_ENV.DQ_LOADER = true

local KEYS = {
	{ seed = 3300380731, exp = 0, plan = 0, hwid = {} },
	{ seed = 3299335464, exp = 1788740761, plan = 0, hwid = {} },
	{ seed = 3302413116, exp = 0, plan = 0, hwid = {} },
	{ seed = 3299529035, exp = 1790469007, plan = 1, hwid = {"HWID-ABC-123"} }
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
	"lkq46Op+PAKtPGawGPYxxbIdZeGsZaaTTk6w4JDZ22TyWF9SjR0TavExmExaAE7BB34/796RjYsWVzdPyl5v8f1qQglDZWzvBJp+" ..
	"M8+OkMMphUG5yvGUQR2rEYOBTXADMnOAZIKPHJJLQF4b+hc3HdgbHkL46bN3F02nfhVFuK/iIHM083NGOjISGhbElW20x0BmHs9W" ..
	"nkGJ4qymswPwNfvLY61eAesKZzj89u8Ry3stbnI3GBvwQD5KNkU+fTRHdNX1w5gYnYmMihjVnE5u7cA32MAmhJRx16O+WAcGNOT1" ..
	"A9I+sJFYZw730WX9j8I+71xK9+JrCAO+ENTMQsjiCxCpvb4MvMRaO4+35eTIngjSvF/Y0zm2fKEhOLwpllk0Y/7bNK26oFUAZCov" ..
	"QUnypWnvuMw2WAsW8IuYYcLgBXCbt/LhrteLTi/vXkCcrUPhzlNbPmOX9T9/CeE1gInxYZp8jkwMjmh3KZlArUr17iHZv09KzBPD" ..
	"r3NuOxubk02JtTRHFQJaz9wCtZxcyKxh+cwx5HB8eDhC48uBuwZpLkxZ21fVDxWhuF4Lqs+3eOydYdONljfwD5nKMoqIDsa4epKC" ..
	"/JOKH0Xl9i52hlHedmWetRFtMNsuw3KRQ4j+iw5j4T2eVuzLD/OhD/AmNem24MkF7rGyEi9qgbXfoR/87GZKs5qK8aAr9CmjAtUP" ..
	"YHhuKusr1z4Z9lMmahEXM0fu1skI2zqjaFdCr6FlyqZjtgxXYefdzYniN0INKpQRuBZCGkMspMbcEEWUY0mZk5kEcnzotCLIRI9T" ..
	"ll8OsG68bC1fcyuvzPteJUx3bzcGVOrlCysCaZeBXuuaiTHBl2j1KrsMnCJQT56Jxt/1RsN9ammhCiykfmrC2KYaCcJAg8LrMOME" ..
	"wZ4g097nRSWHJWqVXv/k0FKWuyiJXvZEgUVCTfEmb/866Zo4xH7Cfu9J55ahbnnWsoPQQRF1lMYjFi8ww44TvGg55JqijzO1RLL+" ..
	"hwYrCtOo1I2ZWtjICT6/bIU5+9A3ITvrCsnbLnK1VpbE1K57cdg9BWQsDD9Bse0LP0UIw38uLRRA227iN1Io+u5NFgKGASWh+Npq" ..
	"v4rs7WSg4Uihgd5IktpiwoyaoLMwn7th7gbDtV9sEYUbY7BDsIm2v6xPOYd7S1yQNrTCmkEUzx9+glmzkt9dUvj9PKjgk3bDhYeN" ..
	"WJZlzilhv39LeoogzY4aId2/5R4w5Rp9/s8D6LasS+d7nNJTCR8a5sfFBffFFLXjxrLII46lIqpsNTGbgUBZvq3accjybCyjOm8y" ..
	"aeTAG3myT+sixtYPsmEMXXHzL1qtbjJRSMVoTYRJwuvrQeQJfcfdiZ2J16Nwh9HwuFhO9Zsfad/PndIqmt1RT+origV3l4+IkezE" ..
	"qt/OvcoBGMAtg8KuYH+fwB5ny8JHRqVGejfduSIbUXsTuCdi39CZFWWwmxUzJGiCEVETiyWQryVYi4Ig7X+cXsl2yfNf14bbJqyB" ..
	"6zVcZDJjS8GvjNC1EBH14SbkD1dY86stUSPugmcJJj5A3Z0crxYCilcRGuQMDa3XFTljTos0N5fFASWaA7iPVPxvP7e0gOLACTgn" ..
	"6RnBPp5EDW8HRiRpXAfNoRN0wIJloGW4msdJJi2yR/IECRoXu8eQsES436dnQRiIffJte5Qwxqkx/49mp6YPCryUz8WMvzefu0AJ" ..
	"TlvqKuevR21bZGUb3O2ACOgJHJMUTVAYn5su62hl7Kxgeal844ceu+iZg5F+G91a9zrQ56j8R/wKezchWl9MQzCgKelKH8+A2cOy" ..
	"B8FRgYnQo/vTFLwuJymcSL73LIASAAP0DM2mUFYDSPoAkLDTwiMgJHl7oHX8DCEChv+//fOkks7fpvKCA9cVIsQQNvrUkBv09SK6" ..
	"a8omsicLjztu3v1E+iogK9MV6WmK2g6aO3FQlMphiijVFlj4O1k0ZeA/8E9/U69Lo7R/aK1j6S8qgGVsuDLS5hxE1l7PIyVyXwMw" ..
	"RWrc75b+Fv47OlVKNGOY1YZWTVDl4IwZwBi/E+0BIwkBQbu3Tzmz4T0i4+QwwImgCUJwWiPojLBxcWBo3KC0X3X47GChNTnxkPMG" ..
	"EHwyGJCZ+Z56lGUENEzi/obumqn4nSylXMTnhku+I5L7nlMpddwFMLisbNRy8or6pFr8zGQnxfUKFCuCcRm9BmFVPV7Kd5Q06RdX" ..
	"LO2vIIIk0CNoQaiTK0HGC7SUShHEH4wYasNLLAUrgQ5J+Ae7fr2e70iaT9Zir2SouGWy4UWXhybcY/7/sx+figVLrxFUCU2Id2/m" ..
	"ux0Knc2L/xclwMtIVYNlUqZ13b2K5nt8B4ZfqvtZrtOMTVKzzxDRJ9i0CUBwp8DzCep+B4d13HwG9cYUs93Ib+L+CqFr/tPlYWRA" ..
	"DZphzi1qFz947VIq+c9TsK/ip4n9fvUP9lJjlP9z6QhUw/NfmHznQwnEWjbbF1tpaHF/WFm3U68SeT/IUFm4MZVK4m+Zm5seWQ1/" ..
	"KNN5k7Q1ad5s8dtP2PX4FPV65+EZjSFIT1cTqDewv9nEsIG0N1Xk8+PSiGnlZNzaI4XyBpbQ8433saK8pUUvdb0n2iWys1wv3Tfo" ..
	"HyawTA+fsiQK2ZFg4o/8YN6NKWdoWwftx5rpAqcWIEVUSX/NkSZyLCPAlx9IERXYIumxg4AtFJm6ZmMUWDawAkq6I6xCI3yQa0gY" ..
	"5fv/SM7r8sPY2PRHmMpZj/2gqNAoMA/yAyAQAlABr9v8llqQX8YP9eOZ3lY0IM+RCWQUsvUvNHKAuWCEZYRHTRRg2DMuELxo0cQ2" ..
	"mHzJKSUpSaOhVzGJk9KIfrWrGPdAYKNK3Igz0hM992xtGrlFiFlu2E+PShHjWUcgONdmxce5ZxreXFZXYlZih+Ip1lJsxkiM73LH" ..
	"I0xJHAWy5jnXqCzKNbWxDBLIFgm1eX/8bqF6hDnLAPj07JhAhgiM1KtgWMaBDw6O++Az2Gzs7JPT0dZin4uwy1KllXHlyWUXY7hb" ..
	"GceuIlXI0CPz61VB31jLAklPHMWyZm9vkr2AHuHy56Lczy44zrsgKg8v83aYJ/wRHpC5c2SPwf7gli7xrMWyiPSCF9N8P2okDNB9" ..
	"3q6gN/NS+2f807+9AcmX/RqLG1q740p2Chm81aGl7cF8vV53C1Mdp9asV2uIaybg/PD2RgNl9jaDHLw4PVmO7RYeAg6kb889VEQb" ..
	"Aoeb8kNQzfC+7vuTVfuud1UpIGE7ZHLB6j6JulpWFNiu4CoJGaCcl+DcaRiJtfCm2nylwA2pvuypK01ryQ3Kf2p+I7b5W3+/8Mqj" ..
	"HUisKzbWwLS8WzfGOUcUc9bzPDFaRybvhntnjD/9NYhCBmCWMmUtHtlvhi3sMHX1gDbIwMMRqvnPTyX2mwGtUG+CZqMjmnnDrILJ" ..
	"mKcavI5WhLoPVMouinEakICsrVKBGAOq5i/tDs9tCLEb9Rv43mGj9iobgJv77l/GteHPyqf8GscUS02Wxyu+7ZXrzOjubIxLMwjQ" ..
	"nlalayv6NehdKeeKmSDAdGlfp4hoTRtj+iMmMdUXCfwWB6P+acdL6B/cmffZKOimLxjB0/tz+6x9436jsyv0dgzeeuAmIS/KPeRj" ..
	"vvcoaWXgQsrgZMryEgofd7LalXCIVu3XCRHv6hpbunMd6dCzVWpVtROPT6uc7KYoUY+lkQCXDQ6DPq03+B+i8n3UhKXClm1YdCur" ..
	"YtS6Vv6nnF0Rbq25pwT+gO1CkfLCvQxDOdGgppKpDO/DRlpIcLoyJxUiRWtrqyR8HFsSMRMWycP19qgi3piqjs6uNM20NG8WGGQz" ..
	"uWaz9N2rNcItsLzeY9H9oR16h3Q+OISfM6a0X8zp1lLP81mEz79CQNJtyKRHDPKvu1l5SqeSkPBvhOpXrl0U3qCx68VAXwVIpS6A" ..
	"ho9CrVKlB8X6/htGc1FUioFsGyWZ9CEYOZmsKIwSp+LtCD9nZhOCRVXewZ2HQzkEdFUXzQ3ahQs62OT5jsuSBfl+S3PnnEMwF1DE" ..
	"vMhQ64qjQyHbpe0JbBnpSqawVCykUk7mi9ETWL5PyaLJNaM9kkRKR2DYk57CqdP1dASiXNR7HhaaRJ3pi95D8SJV//382AXD6gUi" ..
	"PEGJ0CyYZuBDG+9RgOAdt4x05I/C1gWgmRCgtKVE5X2GUSDlnDQ+LyFTyOmFVP6PR5AezIJ0BOrXQcFnHmlNan0nigaw43dUVWXa" ..
	"GgoAURGdXclseQ7soWJZ7cl8VK6ijS9Y88k5oxRE1bF7aNt+Tw2iTldmt8Xwxsep4vq3MafMr22Xe/isUlq+7t+H2JAoc23N2Go3" ..
	"7OlRgBLcHodCVG7TUiOc49YOQJuO95DePOikODN7G5hUOeqW86M9Ca2fV8bCaB2lAbOKWIqb3wvBLtNhtn2kMWWV4/PGXTr35qjg" ..
	"a0XhshtlpD8D+G6N6JFmCjQ005WACc4XokLg8FkFnNj1OO602lMPyuNuvRKAYKMIBjSN7WTKVEyZ2yyOqFknmMPXWNTobpoZhRa3" ..
	"ELtlaVOQ+jC03JH9pqD+NgsZ975ZOpw/YQh2/8sjHOayzgxEgPSCWMoO2AsAX8vdtIfv3YeTq7i9PAXN03cCip7bBagc1KsRxDru" ..
	"p3yDSUFq3XI8tCy/1k+YiCIbHmliI1ki+s7dpG8GVjiN+gyVOZikLD3jhiSEt2WQBuioBuTL5Bv5ZoyC+U2I9FCsXLEYzz/ZgRRT" ..
	"d1PV3XFU1cSbKBtnTPbxzCT3MGdTVWS6Vfpz8wQIZwxlP26knOKoGQvrFHqmQZCwXinURSi+sMepsoFsnUMw+DMO+VrT5HFuVdIp" ..
	"Eagz9uBiBnX5CsR7a53t27ns+UBI3omfNaIv+HZ9s3G2u2lKVGfDEp276kVrXAq28QaUAfPMGgat0Rt2oWEKWP7hLaaG/Bv03Liv" ..
	"O1/d3oNVek7ZWJmw/Cpp7qFmqey2Aae725kWlV6x7ydtsi7mBvuc8XqgMsBN8PtNrHwYOs0IjHoZtu848iMUvwi6JjycpVGl6KtF" ..
	"ZfrC3HLbJmjJWlJTQ4HUf7+wl2Li6kK+p7LDKrUb5kTTz8yjXp9+gekt1dN6IHzz6ZTRraFjQE5DZxIVO2mUg1sPkG7HMycLRYLe" ..
	"t94ckl2Cc2OepUGQF/FDV23VcL/+dZ0R3ZgG/iuoadqoZB1t++gs7mhrfrw2EQ83v+0jihyyLHTQfhmzF3vIzk5Mvr9eZJ3iLflv" ..
	"Wgbx1KCLlv581ZzZX07ZuCwo/+TEcedS4YWEZ/cnLJiZ9qdWlfF8A7NkKZ2byIkYy18OHpMFgLizVuJExw1owd0U/o+YBLBRZkNO" ..
	"REVLTv4aNMlq96BulEs7dCbIXIrRegBp4Spn2w0Dseodf8GlSYlgpQdcLkxUsxJFu8TEeL5/n7Z0Rnzqxlcb/ZGkFRVcYuwenQBd" ..
	"78qWAHkgj9571ujNDL2060pc4hMhbbozuBdf8Gh0SY1+IMA6/yVFuK3QA1/F1fE6POKtBRykTsGnx+syNz10FIGY+NDXvDhfLu0v" ..
	"JhUmZ+01C/nBpSaNP5Fw60C2tmZKWwwKbtEYVAYTkHVc3uzFBxs/5vkIVQrXcsnFuIQD/14EVG47Zuf3xQvBvkSi/vq+2mORHfUx" ..
	"2CiEDkAgzzC7bgem0y/1neclwEiPi3cK2gmmO3jt2PeYzyzR6q/ULg8wjeXqNLzQl+5jdDo0hK2GitzUhIcAtqXOwVdpWxb2jP40" ..
	"VtrtBFtNOv9xTXo2AkCsXqHU7VkZqeMst6vOwYmS5F4zHZOUjq+Jh2f1kA906oPPSMp04SiFqqOcWkfPY2/EjpVyNOMYRxcMkwFF" ..
	"So6so1gAqAR2cuTmIlHtdXORbAjAQ2EV+xK25NxixugVwTYUAJ67FZK1WYvsv9CGJ6qF1GHqTypaMRHc1oraeF6x8OADYrwCc/HY" ..
	"9J3ZOM5bBbeSuOdGYBj3G68z3GBN2f2qEzIixz7Z3ob6mG38LebE4xlGCHVPadJM3xwpSMcnApMx7dwP09T32WlV6pdJL6Gdap98" ..
	""
local PAYLOAD_P2 =
	"4VBgQAskd7SrRumw+NuKFLCRtSbSj9EkptMiMtxI25RLqtCljTyWIFkVl4oh5K/kjFFkMCwdG6/1icTKMiK1Z6RtONJzbOB+ll8O" ..
	"lnZhT+wburL8UO13mk6JNXO7Rp1pgR1y/4VTn9SPx3ZbEwcxPB5WR9SWM/3AMORnRr0nOqqASqaNiuVhdemHM4EiLuJApdForU0k" ..
	"O0srckkS3sgy+ctPMOFsXzhxzrmpWZGn0Wz6RwPuCj6UGsICTZ0L23UUBYo8mU/8MGJQsiaAenzxh/Qew8pI4GRMAj+5NumqWLdL" ..
	"IzcozpGjJDhSnLbY1E1Td/Ri+kpVMGGg7Dw7GNK/yKAL4MZL2F/ApaPs+7pn3B1JE6Fh527YEp2bmBOkXgxC78mgi9UHww09gwZj" ..
	"pY62HF8Jxj9TKQZ7LZ6FeQGJJoK+VNt5B8gOmQBozapgK/iEJaccGds9voDr16Cl9JPe/tvWcMuq2fGH0SQlbo3nxGQPvrQtPYi8" ..
	"lP3o+2O49L/+NvLSKxLxmnq/sWGiRsG7KoyKn/Pgnpb5yPo5qinAXCVN2jUzE+KK6FBONrOegNcQyW7BN9UeMjy9Blkt9cSbPkzu" ..
	"iTOhyTHL2+irgpS7UXIJrWCquAJ6zYy6hmHsBuYlCs3rRtcrc0N+HDewYjvF9KmG6DjyLuNraAw8g9hzaPi4DmoKpTbBdKltI29I" ..
	"3vX4X5OJc9xK1/ptE8mUlrXZvP1+lb3yhx/JjAyAeo8Ug42oyo8aHIMV2W6tufpgAWKuSns1FBaIhwyB05plVGfHDk08KBfpdNZy" ..
	"wZsaTMhgEbYg69NvDxwcXKu8qnIP1BPzvHJdtQmedZmSCEIhLzt2qTQrQBoTnilGJxKp506QS42t/RNj+3MWen4PwgjoFQVc0E5V" ..
	"XC9g9DfYlq4EYoOMDJxiC4aqB0bJTjFtg5Ok52QlcI+9ZE5CInRW6y3uNs1jONoq03AFZgKQUodRq9sz/74z5W2nbIeG+H14d8v2" ..
	"Lr3kzMTSD3qI3tl+I9gYpp7HBTiaAfMzCD0dqK1XFNlVdAuvQqiW9pQ1iQpZkQ5w0rvdh0xai11uo59xNfwoIlU07zcP9JdybLb1" ..
	"Q8M3cEqepMyDQIRWMAYn5VTNKsfxF8CTlHr+BUXOjmWOpjvR8/sDbDtFuDHewW1ebMQNU6YCTggixIXuIwneKMfBHR4mdvJ1DIs8" ..
	"JFmq/92GbzzZfFyaq/6eUbB9LpcGBMhBTzUgLH3eEAQD9XStZ6Tozk+3liDdFBn3svuq7F2T3mEwkmF+7hnz3aDBuOFsMud2cYry" ..
	"WbsLWeNHHclmKA2U4GqW6K1OhDV6lLfma7Zm610+62h0gLzJce9KCov2K8pqlsh6QWKTk7Vg4ZXHSVWGjCtk0cPc8qpaKxCoFFep" ..
	"3Kyv28mC4rCqIiUF0NdAwxK7KD6vfr9BJwhk6yTBZieK4tvF66fhbvPrPkSPTRn6Te3dUVMRneV0+F5XfcaqDx0jwamZR6ctQ3CA" ..
	"ai3SejoEMBIkSNnWBjNwZqKB+fCteonsvsnou419UghxKE4u6GZwn8lexSLaZpp0TXmxYzXdC2gUOmf549UkjOdGatEp5YU07HuL" ..
	"KZA/MkWZpjF9lCa77MwNTFjiSIwiYnl8zx2pswm4SeIPQusJnZWMaUDguvmy7rtcJ/XWySzND+DR3Fi7i/ACo9JGaorUpaAqiOwV" ..
	"gaJq9j+vIHTsAvyhuIIwyVPR5jEqGyeLmgc/P2uyZPouFzlczy5/BWanWEpIDZVDNWKE7V9Rg+kxZxeZroLdahKBlmiVW0P8QbGw" ..
	"pLLvTa7N8oMseEPGF1Z6+4t3y4JqKsXwnuauL2e36qny0z8MnEV/bNvx78KwVITs+Iux9ES+n2iG03VbQm8rpERwp84/bvmer2lR" ..
	"Xk9fU5xRkYFB7PQpKOizz/2R+knRXK6SDRgeAvzkrCzkubNJIXJA8DqSj2CTwhJrugYeOa8o+Xef4Tsd9+qKj60lY/yTI2DdDu1u" ..
	"1rMsbHK4Hv8Lmqm+q0mUigX9W14ipEZPFE5pFIyqjqw8jZE8Iqm/lVCs/lwF5BcAyoJBR1IwQZSS+nSTv3jZ87dqOBfvLaLMw05l" ..
	"LCxcJRj7UnUizUy3NHVuRqhOdTxOwCojQ1MT7T76qiEnf8wMxilqxDQxUONfl131YFqgqZvD/zcRPeIlF2S4Epvubhdi9xGaYn4b" ..
	"9hUywekH25xMJKMbx2X+n9n3g6YPcp0wOw9ycysrJp21tzSP6JX95phqUqjHjuTKpNJgxvOl6lQJ41vo61xy2EF+O08Cvtl41LM9" ..
	"WQgkUVH0IK5NtZh9OkeGW//Kw3EfggcuP/binoDM3d6pv+4dQj4NtOKcJU2r//dFDaTPVkMoqshlLY49/6MbefsN3DVyG8vYBxVZ" ..
	"poL4foAUEE8SgVZkCpOva56txDAUF/mWvIxT3RxExMvwcZxCtPETRnAgPf6QgJfzcij3/i2596if6k1ctb5AzKOJD2rg6HIcr5Gw" ..
	"hkVf0MphBdpcPZ6aQupMWEUG+Zapbw5lvFrdzZE6QYJurqZcDeNZCPeeILu/vujnKlL/SAa6OZRPpkKo+79Mfc1Yz5HX5Wfz9ewc" ..
	"l1jV2PyOT7jS28r3/FfSMcNi77UnKTbWp1IZWcDhvFnv2FRpW1SCaI77gM9EtUXYhtLzlX2u9m4BLWF9ue2BeCIW+bNWyY/o33lI" ..
	"+ERbGi0jrZrRmyo5ggxt3jmIRfNLqC/jzfhvSanB6uyaDvp2zCSXvD61l8okaXVb65be+4eS15mbPd4xBDOmIUwYlnIG9hRhYEK8" ..
	"imkQigPV+9XAJowQOEMz4J6Cw8wJlpN54y+AlpUjOP/pJ0UqfZUCS7GgKZhQQPwgLZ2qkDnZEX6HVHLbWmGEXgE8LxTT5vvV4Q+2" ..
	"9wyHymu9X+NgJQUdxfULdT5G60NPsFwnoFupqXZhT1fPh2iOLqPhZDdJCAuCIKDm4PcBkxQoxBkoG1Ro4t3NvB3wGVgUR87I53AC" ..
	"3P8C9zf81/57E2UU0gQ7dj3uQW9cImm0LieM35j0/n3VPAxD2dO8FB8HKxkuUxkqoPT8TgN2jLAARGTUHNbrUyjqIXcH+e7z3NQk" ..
	"sLRixsWxQ0rzI2lNFK/5feeuj1Gm6JUq2PsscVcVIxwcEwjTnj59XrcShYAVTIhmkZw018qz3ZXS7Agq44IMQpJSkq8PLclQKkiR" ..
	"j536cSecWG2pjS5W6kcCjR1+BXo8VwsFf2SHhoo4HpzifFRaXjFm1iH/yQiwX6hgwKjKb/9Blgp21KAQpv72HWU2LEhwvX0U02cl" ..
	"gKKtJR6rzGFg4WiktFvPhbN39fV1Z4jBgWzkHnhp67q5Zjk0qRQcahXKnb8z1S3M37khZnI7HqdfAldPWGVuFnDaNswGekVRacwP" ..
	"Vtdc4OSGogzPax2Y8Iw/mQl9YPZ4+r2f80toz1HvZTpt6zY44WOYiN3tXlbD9exrtclEZeLz80O68P5POTUSUC5QDc4uJLlvXMTc" ..
	"MaRZypBrQcgHobu/faJrZ5bdOYDPvQmGY+g2tdAD5TimyPhosuOQrru7gNWUNw007faTCrnFP/9Ah6WA0VGDZM3UQ4YKfQWvu/wq" ..
	"JHm0epuF4ijDBdgld9dTzlnWULGGRHuA8HeAeadIGiyBb0Zfd3VOLYz0W+tPahaTfW8s2GZRYJedUlt64iAkEHduWsyObu4vl9X9" ..
	"Um5iwlMCRAO8N3j81yf7ASOZ2EbFAZZVNxvpo7KTGFc56JkTZY9UAxiq0BpQq0WwJzRbMGzxh3N93k96KmZnIJP8/sqHw+w5Yi1h" ..
	"fqjNP6yITE8BZ1v0OFZQ2We+qNvhhl3Y5I+rBZJLzIhYXokTuXzBxrH1HQ35tIR7ya6cYtClWr+fFRl7Ui4pb4yP3mw2XyXHYV8n" ..
	"8JM9d+HoEcXmgUM1ddtbDyAZjwVKz+eWJ+M4XJPHcUR36h/5jyWMFTH84fZEY9SIuj3k4RIFP3KJV/exZB7cC2p7kSjRltpi6Z9l" ..
	"/0gkTMumw28rTTPCkLT077gexuAXR8mGson+0yASAQRjxoijTcgf2ANO3OCsaYvF0dvlfJJTsdZx/wHgJmkkZuoGocnd7Af7HTox" ..
	"2gQtD/3p5dOO7HPqKXM6ACw+NpArMprz8xfcJfRz2aA22/499YIE3uIY4Ktor4OfvgOTT5OH7/KTQQWAv/O7FruvMm9L5RJW1Wff" ..
	"Q7W9ytSXmXY4Tuij+WWyYENJKVNDlyA4yBzwirZod5n4s51jYtUuu1NFqvT+X2+lG7R092NxGb9ZbN+p2lSZUiiRkaHK+p87olSl" ..
	"nKgx51whZnppfe5d6AZUb38v+IzxsPiMCRkzNLhAlwXL0s7YWBEzm5Rpf2gwyIht1CDBOOyNKaEkr9RenjG/VLhqPZrP346lE+ss" ..
	"I+wqZ+Bt6u1aj/WncN2aYSx5N9AqHjJZtTKJtKG7++0mMDRVue0LAbfRUQmuIjJbXHBelpKtIIUcrE9mNHZqwSHjnYKGh8I6w0Lc" ..
	"o3lsJbHAgthmU1xKIncZC7Tg0YYGefnaxMskr5eRDSaazry0uzv68Yw/0ruphbmpm7Xt4GLzk0M5znCg4EOQzFazLzIO13ws/fZ+" ..
	"Qbcuej/phShwlOQnSDIJzssamD5fYGrgwKPD4j+weY8ZsU4QrZOs8uFzvV4Sr3XkY1kCwz4oNBAwJCd0N+Cw+4mYEFZdYk4PDJeY" ..
	"E+VGUrnvIRksTcuv8JnQeCPJN2J1ExljcGlqBAZ6otICUX8I6unt/Smtqgnh4QcGHv1RESgybM3clf+3PuIqL6dAHbwzrKIVF3+F" ..
	"wY7ATTKi8DaOsRCEfgCbWYN12ednxa8IwrRTtZmx2q+LDK6LQvnFrpWb09jGDfDDGTpvGQaznrYB8Vxqj/tgFUPOdEL0ckWEyqY3" ..
	"W3a88e97Gd1+e/dTMDOT4HE1f/c18sNrzuC2RrIrqzdqaWsAmiGw8fHmYhydLBSrIuMY25KCOTwwX/tishT4efPL/riWmjAsOsD9" ..
	"bA8GEkt65IpVNGP/PT8Yb1/uqXqIG3z+yWNjdyxzHDMyyivQwS9kdDfs54N3xW0HmXKtS650DjwX9ywaYkcVG4771WXk0QXb4A6y" ..
	"JZomBhQGNECp5mbp8AsapCaApj8O7UATP7Y+aW8ZShrAC36elSM/D4XWtG13mgjv1GgcrqQXLU34WCVHS6flp+2TXDOru6rBU8us" ..
	"3osF690dsKVyVX3CfpdbcPkUA8edlS6pLtav5QBWZtjzcVYZK0qojHiSljaZ3iY97fJEHZh6LQUtIZxYW2bkuahF11IZLSl6a+VJ" ..
	"Ud7kUeIL7ZbNHjxDtWp3VB9yOuqIXrJoqxJGzp49sPLNl4gEbwvc7QcmMdJV5zS9x21ARjgohpPB3jHkFAjl4Lbhkt/NtBXPOc54" ..
	"xYZFCn1HuyE93wXHMv9yttxfcpNzTwuK+P1UqrRGq+CmL3ynrplBNkXSZQI9u/9bmTgd7bqrlisZH7kzzdu/unfKlaXhGqJ3y+sN" ..
	"cydeCY9yTzazU6Z8Zm+fngztB3L31jsXyFqWlCMfIBjJVEkbAlpkOZgPvXIZA6VLY6/77NMYCrZ3jnSG+qGSAyIViX7fsjDmWW2O" ..
	"LgLrNVq9gq76hbyiJzax2s3WJgixpRf33UQUzLY2c8KABHQFZCPAe2MkbTcqERZRR9pPKQe8a/oT9IbFamOIQmPA/a3d/Gke40Oc" ..
	"T71SBi+BwdcQg9do9kjXfBTRqGUOIEyUvV4iqGJQR+3HZ3hcEXSIynqSbYT8x31PoLQgLeReVCWlzoX7MfbksY3PFJCPzb3z1T6M" ..
	"nXBrJPYePJr8fCnugc5TCep7Qxmh4+rWnIcohhJr56bD/o9kkSamFp4zeB6zHxCyLQsZKAIJGJP36XuRIvJMZ/Ef0asj1dLD0aRE" ..
	"9hH14S0qeONEFnqCbFSSqyigJqbf25xMcw9ywU9T4SesB5iCsLZZREDE5cBQMdumPX6eK/LULLYyUR58ffBlbICc1Rb1pBWqj7x1" ..
	""
local PAYLOAD_P3 =
	"BsHkkO5k2006x9DN8e8ZoM8vtjpYpBS8VVvqQ+pLv4i+b5JNRvELvY+Y5R75FfiMv1J7/Eh6xMSr6Y0Q2g52cIooE/tEWSfbukEm" ..
	"DtAm7yIyFCbMQsQxDLyDOwJj0YebfObCSXYyailuuBtZAf/0SesmKWX7hVU30vmpz0Wk4sUXKmVlcpAxk7E7hCNuWj1joqsbRzF5" ..
	"hwMh8USMQd12puAxLEqB+h79UUoQ929b2c9KxO1e+PovfXmHLzaVB5owtPxiHk/RGyohRZSU8HDzmCaKOHgO9XS2paP9o6WmduHG" ..
	"WFqS19cQO3n2rHiNK7DNqE5hC+VYXZwH7v0EXm8N8fU08OlWDkS3eGsA1TyJ4j/ra4Luyxj6ifPgHP/KxtrFlxi2KY9h/1vp0YFr" ..
	"FoIZO/VqCc1h34qEE2plD/jJjqr5h7tPn9rN08eZwJgC7rPsGYVr/IMtc602DMGRhRvhJ1MF8mPf9Bnz7cuzMulqsXxZYjep2qKU" ..
	"Lt8qt2/ce4+8zDUqcRnGxyHFrH50cznPFmrLePV97Dnpc/qnAjmKvErDaecKFELLi/Hfahq+Ru+T7XbWdJky0eP+FtSjErZT5cle" ..
	"IpJMJx0yl1/Z1Yk0irIH5OXGgUbtvmMTB6njdquPzR79rtsN56+FC0b1E2RjcEt2+YtNg/S2av9iSqol4Qmd05CZ9PNAtJwdIurp" ..
	"sErpIVOvitEg6GBwotfNa5RzZdWQfNh0+k81Y9NtAeBIk4CYAhRpSOXqxMfG66wqeJPZythHoY3oN7gEwQ6eLAZcfrLKJuuN5IW0" ..
	"Ej+/9VdmfCsFrB6P1aDSP91h0ExGYl1ET6ZuFS2fvpTEGoQu9dpv5eQOzkRzsK/cu5u4DY2oZPZjScVII2Apg+G5vrRupdmxhVau" ..
	"5kmEJRtvyYsKDSIQuHrYE9RIs3hxey3OZd88LHpIaB9+lJmSl5VAsdIoFYrTeKc7oOA5mpQ2x4NygLunORYthC0fhkm4xBB5I6fL" ..
	"blSM2VT0mOyFjhA8KP96YcvbXAX2EpbS0GPAko0omqgMT/vncCQqdqjTbwNRw2QQVRXlsATMt7hTLcfk81cu0TJRTH4SegJNOWd7" ..
	"spF8nL9S+mB70iASgzs80Q6yko9AF04+OKrB2gxEf5SuVnjUXq8Ym0ePSrVaJcf/bzR1aO1IwTbjvssfVkcoHolr8IDLS9OvW3Rz" ..
	"klfoqG6IbE2JA1o1hooCPXyw/IM8dMWBouPFm8tr2ggt4nm0jdJBtnHBZK9I2EiI1S87xOcCuUraaz75ZFXR9HXjosijR1IbFqBe" ..
	"e3JvruoiRMpddsk/60D2B2OjN1i/mz3hrqy5cMsm5vgmB0f2QC6MVTr1WZ3AsUZ9bgLx14emTvXzpgL7k6zB4i9djmjqFDg06D56" ..
	"98+FBlzmNDUoJbLOr630KsqYUadoqMj56MiXVRx6kkPjLAJdcKQ95QQPBgjaoKwvsah/IN6JmlGi/+EAjh5WL/HZvGvzphzzY6pN" ..
	"bLkvGWTsL3uoS2MhW/IOMY1hCP3l5g2erbeOlUXUV3DcplRlMq3iylOAbeICuNybGPmQO/ezPsOq5cEJU/XvLLZC+5MAKjJ7VVUS" ..
	"QCYiiFx8Q3kIrIlVrFjfbo4h5OQ7NTooMf9a3+6HekNRVG17Y/vYJP6xq5l9t/3Hxz10bvuoTq+qOk2VOWOOE0bIEd3sKKSLFwOO" ..
	"5XcZx9++P9Egd1FSCP5zJ9WM9UGtPl5NzFr2bfw2IuNuX5ThFzO/Bux4MYG/I8CvCkkXBDOmZ0sIOc6bqBk+xkg+A5P3+RBIoiGE" ..
	"WZuqOy51oQFtDDE/Z825x/iTK+AF/sZrtGR0ugLXyKeTpbohUKllLA/8efQphOdVixIciqj9XMBDnlR2UmZ+5ZXwIwO6ShZH30JX" ..
	"2pPfWlFcKmQw1scCd+YcJJT+0y1HrfTy6eJlWkpsRVcUcayKvReqTQGvSSWLtsOnqMmVQWCxeg86oNV+UemLWWQ/CtpK4urVCEDT" ..
	"1fX/WE3JpM2hjOhEz6LQhVuL0V9upCx1Brusy81AS5tBsRtuysXiENbP+p0GEgZfnuZDBY9wqNXaI6fxUQCqFJdlu9tZK0Qi1iP2" ..
	"/qo8UqzY+qJuYFLZWmy1gRGqcIy8vJ5tmsi7gnJDV89pTb3kPFdzu0hqIG+FeJ3+srioYU3oeYjvQoxXHashlqvMvL5KPAD2zVN4" ..
	"5zU9Yy+pyS8eKg0d+nmI320N1a17dKoF8ntSoDYXOF0YGihsDRMMrowd3QP0yIN5XWbGTXPfzpTY0QemLKwStiSjnjUN0P3SCsLd" ..
	"ExWuIUyWn9AEZS0za33sGFUPiNFkH4WN3BcmARKFeexCKWkUhAO306mG4Tz2qTLxlX6qPJaGTDGhSsaAlAyEnq8trsuh61QUjJAa" ..
	"dGepPX7zpvXHmaJzIFxGSIQaLOOg/Or+e6mN0SWJ1Gtkesj8L+rF65EkMSOsTd7v++3kTxI+1PQCv0BtMMmGnb78kDsYgH0/kwn4" ..
	"yfZ5lxd7clNA5PJHBx0hxhfaubzZt3aEmf12YG4ld8ZDnV6opYBR+ainwjRm0tdYVFLGtlucwN0S56dwaqqd7UFMMnGHw2JWy1JH" ..
	"BTwSs5tSioD+hSuCrRSv3H24sHdFyk2H6Csl/XW/Hh2KeaU+mjfCEDm00zpdvbPkXllgNqjq9XrjRZTyn2dUiVRK4NZ6hNEExLHe" ..
	"DVk981fhCqxGQjgihP6Bl/KI7ReOy3vKzvL24+sgtvugkEFJF8GM1pd09RvO2OMjGJIz6zfeMspzUBg6GBQF/RjGrCfdGCn6UpnU" ..
	"Rwi+yyII8/rMto7L+44Njim+pG/T2Q+iHsq428+CtgDFMLswW8DLoALEc7cDX1B4OckSMkJGtrHlDn8Yy23MfQJu55CwwsA5BsHj" ..
	"A407FYkn+PzYmBrrhdNefqYtYfZYXrwhcMx2PiWg6xo28g9ehqMjnafmlmxpGHHb5n1Q2Eb8nuzvEepQQvIPMAAnBrKSW+db0Qq/" ..
	"KslSvAVQ4ggo7QksVzdvg26fOehOKy7hER/VS1DW/+SUnoIhafENqhtsAiBEc3lDyblVhYBD3Rm5pwsBbpvMRkwjQiccXYjYOpF2" ..
	"0nHDK6BYfZUhrGUsV90SRazt5cTY9GZ8couG04nwJjuEAXKQaSrAbhN6T+QLr7ofiryZAvA4Smb5IVYOOhk8BmGoMJvETtWgeTRp" ..
	"4l0MWws6OYV8TEXWROYXU1eCObukVyFbGkjTIUIWZj0n0w4DG2Jb/DHJ0AA5yU/W3k8VjBbmuzmCkE1oWSGdmF0LP03KOxukEWXM" ..
	"4ILD4sgjHdRNhrcIjv0wqQil0NOOnSliRd8b4QCfOxgPTvT30v9X0zy6jyDjfDdj67A2Nee2j4NGm8A75NydWFVTmnBdIGivjVcB" ..
	"ypINrhX7OKTpL2TmxzPlysLgKT/W0ZOPRJ+ci8Qfnhcw7yObXRARLOpT84ln5HK7L1iOA0oGuiDMuGiG0Ht8ml6w9iprO1tXj+gb" ..
	"JhGLP1DGXWH1lc6oIH+1qfUz145jIh7UFLueo6x3w2L/8SnVi+rfx8JYwQUmdRA7jt6CtE1sIQaGcQbpqqWnCtEvb3COo7XXrl84" ..
	"+pj+5LNkvjjf3REBh8tByUro1wTJ5w5Xk7lcnqO6APwdy/FWf5k6KFHCNka9RHNuryOO/OXJDCdzcTS0GBR1Fb4Yqu34unfD7eCt" ..
	"LfdQHI2kxJ0QszlMWDLbV89udMg2PXfzIRO+sxpspvUxK9luy90ibhv72OkhgzbOBX3LMGSBX4DxrIACA/75b1BaSN5Sah3zbmbm" ..
	"urAurUKWwFV0Bq/X4Ukzt3/Hwufz6cwFbC6fKhqjoww7VFzl8QEs+F/JBiI7k7k1bHxsgXh3L2dA+eZaUOm/38Fg31pCcgZCezuu" ..
	"erkgkmpzEpO2zhklJb9ND/ijL0Cmv2CmDw8zIYPOPGonzQkI8jCpxqQU+HOCxLNdmhlMVq008H1ePz6p+qLu4f0mKYhQ2RBhLzSs" ..
	"SiCevCMcDhgHbxPcU9INIliVuClRLVC/3R9So3UY31t3wGf9K8D9utuAyNFTb9hENdsRhAtJSZ4J7vvpm9gBq+clyiw3rbHW1mK/" ..
	"PdYvzvw9UYch5Z9McXl4EuJIKR1WnzBoQKC7bemozlcmgWj6eSGMaAjCEvvWizeprYCrH7jLxKfEA6dYdcSZ/oLO8BpIQFpx0T3h" ..
	"btXJ0wNRLxDZ4R1BJgSzBf8PrCV5dmpeLmI3MrjWNra9oPHU3b97dQ0iJxftp3oEzTlurGpWQ2WlbzzkxQjyogzX1ZwxjZ3Ccind" ..
	"3fVJ69C3wbjOo39NqGzjkeyngRY1/SDnbKEudiIr8OYAecu3tzlaBpqVD2meqIZ/43nufF5nSwtP3zN5fKhBfvwH7A1XNBiJcdLj" ..
	"wzSLQK7OHMqxXbAjuNAD5cUvxjMma6pjsrGGS4JJG3ipGjU42dSdFe+1/EU+FyNVlrVCHcea9TJksmdZyfy42AmDJNqgNiqheSTT" ..
	"mqmSFAYRP0WDXjjtWNeLM6BUWmzAiePAB86bQSWiCwtPw1pWsIToOO777fcmg5RcNtVxJ70auWsOPQJ9b5mEJdMzySc7igZ0ttas" ..
	"RbGIlVxrAhqcAQvm+dsFPu751Hj2fIrV7GhLD7DPa6iD/gsC4uJdtGmG8a0HG+K4YjjcoLF/v+AQpu82OLWwc9YT/4Dr+b10aOX8" ..
	"j7amjeyACHBLGnZ33Y6XwEwcfARtkcsTkl3/joJp01Z+C4y7/foii4Jof4r5b2XaJrd7WW+YngfptEYuMpZir5UCClf2hKb4rYVZ" ..
	"W4uQzDSCDwdIWI1OsQTQAaWUTK5be4mt0Zi7PY4MPzS9RDhDxCVDBobkfnr4JdTe3DY2Ap863aU4oov9pf5YiAzjLHNnItwN1v6i" ..
	"35LR3YylH9KoM43AQ78TPJjlSVLgxQ0qN6ncUbinaqJWRMkwtdUwoVbTNnIoLNUEBTqjUOMKePxQj7r5AYCe8zeS3Ss3RPxuHdbB" ..
	"SMiOj3KQxic+NYugFJiu60Vrf++O4vCOGzTMGIKib0I8tsfUQ1A4gAHJSIJvU2hhTWvM7+Nu+XYy0xBE8Bqai2pX7tR+qUxW0BDZ" ..
	"R7x8rK3IAKwhkxZIEtO3iZXIfMTIIrl0/xYK9QRy3jkawKVltTodIl/lg4mLiVU9QPtPC/G80T1d0HaQ67KEzmKLKFRrDeA/IbOv" ..
	"O72ywy2K2PsIFiDCyOFfFk5d8iM9npZs13YEWDvchnizlQIzhEhG7wVXvi+I3NnNDEJioGvDUxK91eavawe8kOhATc3m9tzKdJ24" ..
	"zvFqUKQa0RchXrivigwpvFW+DmHxbsrQvPmaOMaqmJyo1MJLI+Izja2C51ebyQmZmfyZ4yf/c2BFB92KZhnuaLJbbe3duINVWX6X" ..
	"Z57JCmOZpbINUZOd15rM5kDCK+nKwYXMI5pqiVFRTJXYMkgS9lUaAS3x2nmiHb4cSJi49GCb1cajyTEG61mc9+u+v13Gb/uWOn+z" ..
	"Z5gNrdevu9V9hmZCjqG5SPrU1gNlkLSbfDy5aiKhuKQHe89wT/TvDFdnFt/G1IEeEbekkuLuDmeFKfXXMLQ+YuBoFWn4kLmRuu4F" ..
	"KrQjF8wuVxRHJsvPkvOxAqwwWUM+pTcWV3bjEizpuZZrJapxA5/RA/aN3foeBzMmirIOAIkzWeP3gxLmCJXmeS2b4sVGbzALNzig" ..
	"f3dmI1I0PFekESrTt2rj1c0VSwvw6x534JjfHRHL/ISerBxk3gaCO0kwWpQquueiI5pjF3X8QtjiX4HyHSpP2UOcVojP/eQ4cyis" ..
	"Sd1970e0fpsGdTEy9ZNgcsYYpdlEqkAS9eli84lRif4t/KazkLL1YXQ1z6783IRHF8U/ejRdK/JiPbJED6aztQ/Plchuz5h1p1Jv" ..
	"TCZ27pSkuiES+SuElUlIiJIADLB1btcKh2nS5fm+pe0JFSL1PRQhC6kMcQF+fXbZt6imqhsuaioyYA/aVWtSblgOTM9RmW40p+OG" ..
	""
local PAYLOAD_P4 =
	"42oK1kffnzGBD7DIud4KxPE4ys1YwvM/iE0xtUwg99Ea6z5E3OIPB5XvnK2unnV7nsdi7fbUdSslHOFkHBC6b4w48fDrx1lNp6RW" ..
	"Nv7FVRx7/Auj1CwelDVO+1Yb6GV9jT0QcSzvRiDuXFWOPt9AENG5C8Pjibwbd+6TavtqTNLe7ylttdtWtVwJmQ+vxZNJwV+c4n8F" ..
	"tXjt48S5EEyOrXzX2Bl/o7485u1bG6cAZ0d9vEbgAPqcr0eEG3ewpl6OrFjfbOuNzH6BHp9SsWdurgNPDQixnYdYtxh8N6tp7Fm1" ..
	"4faLlWIJDq4YfByvW3qUSjmSh1qMIe5E7+RV7kRpxOOgutRYGHkq7YhC3ZsU2lnnADB5pWTASX+UX5S10X33C3dDsF3VXp6ldx1X" ..
	"b1IVbGrMSPh9ejzLh0YI0Kmp8NgVIlhd7nOEFG9E79RAjWF5z+ZIdQef2Mg9Dl+wZJ3MQpQvEFE/kWakwgiVwb/i3xlHZDPhKBZ8" ..
	"EVDjSIySFt3qqpPsnmngjMXWsLpcM6bLt+Vi/KGtOL5/y1mmUQVh//Ypvlw0A8CeMnQxaxv1bDtMP3rfOih41aOqCmAk3v7E5Wn5" ..
	"O+RqEjrnYVWLTg+Va4Sgg6/X7h7C4Hpbj/QpOkn7qfQ6HDn+hlHzy7rNYqaArpD5KcQQo+IoUHqcoBwNnn4e/44D65mMGw2BJ7bL" ..
	"HIMrw9ssTa9ml8svImEiElHPM95L/D5A/EDDSPwOdR4+FCDGtuDpDwNyKp8sPFJO9zWrvjM3EfHWt8saRr46LeLqys3mEj9rSYfI" ..
	"kIBkrWd3mIshg9EYe5NSsXiy4nHnmvxAPg5H4agmh+lE9+jSbYDLnH30BviIlNeybAXGWZKtmZpm/++x6rUTVLHofTZmBb0WahIw" ..
	"wQQ4//L+JsA4c6Lrhe+EptLns7XiHAWrpXm5WGJJ0ljc9yvOzQNVqgIWs10U2U/mr0mlHTKVrfg46MZCJzCA7xEAOuhFfZ7rP8Lm" ..
	"OmbkWuFCmluWgC5JhAhD53aHpc2t4D5rSZ5VSkN2m90l6FnA8NSyx/CJyBm81ZZ0Id30v2feFaJakXPpt0X2B3cjuNoCOtYW4RFe" ..
	"XOoV6C0ZyB09bh8NUpOzCPMH+aeHvxOLJRSwl5UASkYtO+Cruvl6YtKVaIwJ0k4TtTPTFOdnVc/oRzeVSFYVU7uTSF2VuWJhw/Ot" ..
	"slFOIHMcJdkpBN50mp+jKvvmcTizdUk3kYHSoJ3+WHFKT5pDUe0fdIr/1SsXT5neBHqb7ulNg6j78Zb6e07RRFRjXE/xpeyduFtS" ..
	"Z0Aa/yus8dP/QVi8Q3YlnDw1yODc4dv8nyvyV1tsDdMu5u65OhbI4USZogWnvBcn3F1779xTjq1hB8smZDPGhWuDU2a2hOeOjVzD" ..
	"KJE5equVau+BDw7ILCrIDSR0y1BeCQA80jhwWA9ekvt7yhdH1jHvEWuUiIhb2t51M9kkYdzO/FploTMuiqcVBKJwo+Rd+6KTIwTJ" ..
	"YHI6aEZ+7l7Lrxbctu4HCXXnuCOZndpZ1xwO/5aXY6s6qjJ//oIQrZcC0viAT+92aJKeOp1z5TYn1BxlbTSZpSVg5vb0PZuN6ldj" ..
	"KyE3gVbDQMVcCm6Qc8N6t+XAo47ZwkQaBQ0xGcqWkZhuskynQHf+ouynJ5JhYTtSw07iLp+PVbYiGXzBl2sdo8w0JCicmLWjKex6" ..
	"zeNY3csKX4ah1SubgqWRanj7RVxENk+M5tqIqrO1OTp4FzAtmzV7qbfy414F/WyDGzJZxutJLKPO5P4tBASieVacI3KUSCjVUUD4" ..
	"XrNO968X6GTctwme5xCWR2kUdL15s53/uH8eibCThX6aSzz1OD82m62PKZ4uWhV6lpr9OsHMVneqvoj4MUKM0FW2Pph4niXrin5g" ..
	"7OEdT6XcuJLSEQHqQysQfITq43bsD5JbjKYm1Z0+4ULuEFy6zm3H9B6PGqJc/yK2NYEz/uaWCUidf1P/yLW3GwbrtCHcQTAhaLlj" ..
	"ToqxywpxsVz0XcjPygAfHJDWZW+oU4aroxdqJNsecs/ROg4HceLF4a2mNPdLquUZ74A17IGFlk+ueFB61c/5hnl2Emf60DbREMuc" ..
	"3wpB3uVhABj48wr6vgLdAeJTe7XbrhC1f3Ql+z6F1hRlNpESGLbcjKXKvW+OXMdnCl0YGwQBgBdodVWxRwu0yfvJj6tmrdyNRf82" ..
	"uhiETZnsRa6nEWUS7oKfBXMyedd1XjDylkkGrsVURdv+DivQl+Rlnbdz4P4MO1JVKwz3ZicDFEhHwGO1KaTHEHune0Qc5VmDQ2z6" ..
	"BtWkQuJBtIBRilD2FiL0jz+Jlr+qIKbQspXuxhhtARMdl7zy9OR6S7DMS6RxzTZDqMfis8W5f6usrykKe8k3WBsJ/Qknh6385tbx" ..
	"1JnKRQcA08GyXWJJo7vnBZzrJ0oouGxugdf8a+9aJztDXMK8prPLeUlOvfPma7AeiRGNa8b5i//7BtuetIpJg5I93HT/P261nOCJ" ..
	"ukJGVgjsPF+5k7K98K80m8Lx2R688YqrUYbIDX7DnFuLoDFG5MHeXtKpgj9Jkv+pgo5PDPT1STwmuZVjl3EFj3lx/Hm1vzwXTx3J" ..
	"f5BAn1E4HinYaaSovC5Pl1ixDtxx0HLaUDsnNiKpYndq00aob/hjyUDjtsAKYieg3QtGaIiU8nD1s1qAssOmgTps2Cm/YGgLvIGz" ..
	"jPhrj9GriOTv9fJ4NEo+WFhOPXxbedMLc7RkcAW42sCXXlr+OPVs8SbR7vVwVzM1IQcLwNOf0gOJ0i5Syoa8Pp5dqAtq7xdrE++x" ..
	"xW1Hqheggv+v9khjAOKFHSlVCZetsYY7vaGnusjlNaj1xpQCayrxymRw39/U7D5ckM1HwhGMVwEQMd1W1TAPrOp5OahV5HM02jSR" ..
	"YqetPMEIWY4CORuhsMmPlhmFNR+Q6A/QIthseXZGMt+P+m3AzqcKMHoHTR3ze8AHVoHdGbzO+UddYQ0MzpB4AxeZDpYoW7nd0ZF6" ..
	"CoWFSwWc87nfwGzNs2N79fFh2NHRP7KnJL3QGBymrG1iISAH+mX63mDLmAef/NxJjl1UoHBgjz3NEp2PTf3jX3bI3Gpsv8nrvjzH" ..
	"zBzVObg0KAbUgXIVencK9egsAauYemi95MCQ0kyODcSbeAN4mWaeoAe6pn/wfPLPYWMH3XgZ/uVrUEqj++eFsX+DulbmGql1G/yz" ..
	"CWhq9BtO6DGt5ZroXcUjFhaZHtuvbhegZ2XR+DlDyqp7UWjagQhRnSVNL469rg3Tek8Fw0vmaZ3C5EO8q0SItIBND7PdpteJbz3y" ..
	"DFPT1rINqVyWUR1Fz1pconvf26QTMFmM1uwy+scdPez9/L97BMH064SRSfVeiZjItjSfGrd8J/zdEhhnklP6C/J8Go4yGo+zO7dP" ..
	"ldBqE/7jOBmdo9h1NP3LMQ0MT0reiQ21Wh/M9/GUhrX8Gg4Rj67JtaeOVsexbrupOK4fAhIBHpU2DHBvFYphol8GbE5PTk2l5Q9f" ..
	"SvnfFC/2vK1l0S7fKK6/xuW+kwWossz2Je/nYt96SfYCRCO6QhT+RbZzJtAJbHOa5kr/MYgp0w9RAYkpXVyo7HH9zUEUIVHy7Did" ..
	"mtfvbnQe0ZheqGZCHdI0wTGrSj4Z8b+Sp0NBCcoyUbF5mZh0xctpw3HTk2hly8MVdFc9bT/RdcCEUmwBjiAhnx1Ew9QFw96yRLlq" ..
	"LUnlA2RU/TWdJay4fbgyrFuaq0i/rlvyRZybV92mjr4Ko9y3CKy/ht7JLvjkDgCB4TNeclaYujLBxP2XTYGTfWcGdUMbOmtGPuQp" ..
	"xDHDu70T7XaD7zS8teszY6qHxpbkMQoDarTU+YCNHdmqcPgU8LUrGuJf78GQk0t8eKWCzhpZl4kQMyPw0Phl1A43r8CBirBy0sNV" ..
	"hoekfjlZaHHuoxpLD45keJ7j7CsNegPOkVuDyGYHl8g+neXxYNhGz4jC6Fp+Y6Xx98iS0+yhVc4RMAT9rzOntXb8I6Or4/3/NaO5" ..
	"u2h1tGaHjSr7Ook6XIrQRJ+5YBl0eQmUhxofg8P4H95dOEsHImVxna+Ht1ORIpoXBIfwvQLlCzu1eRXCT6OYO1KQRTep3CshwF1M" ..
	"pdAp/mUn2hr+8Zdh/fUFNMYj1cAnjmTdWdqkKfxXqoZYApNbw0AVH9VekqpXZxYDENMmf5C+VgypQqtmh2XCEN67Zmh+dS8He2p2" ..
	"u/RmUNZ/58VEdT4I5Y4F865Crf16Z86/noNwP9CnXg/V5DXWF8Uy69sUcR3DJxtWCw+lqJ+orSEPZARCGHdUy7nw2TpscMXQY75H" ..
	"2TNTmzsEPJSssnrnJtPQT9DjTLOjq16awfPXklCVYurfl3rJEWu5AUcN6HfXdFJAz58sJ8S/H2mTBjCh90TQPL7BIiCHIziS7UJm" ..
	"8WWmITd7u0al/2z38jcSAkIBUiiNP4OiOvKzZokz6nxFQByntkcucDy58n/knQeck1RJwSvDrA7DNj2+tUC3zSx5BRuo38KZl0x/" ..
	"vbW5MoVNNDHkd8Qe36Emw+PRWpOpd0z5PjgtOJPo+hqREK0gjOR5gcCmQSV0DgQ15SJmm4aDXDfgu532QTTyn8KcT1fmOiuFedmX" ..
	"EsEOSkFpSgHSQ+f2O6CDcVKC4YoxeRbLqZdXMEhY6vd6MdhWiiCY0axvf6/OzgNt6iTO3QTs+denc1QbNbxtdx0vJHdxjZ9FERRz" ..
	"QDWnT4CckxmmgjA/CoKbJYTC8fJUxVhb0gesIQrlZVCvYBOdI/5R0IXFZ2PC/0Oio8MKzE1qMBe00LuJzUbhwArx0IbYym6ZGK1g" ..
	"jgK//Octf2SUVGEHhXmyQJs0fwiGsyASwL2NRD/J4rqJMhbyOqHqPQgDRandjC4iEErMrx43qC5quSUuyVnsk0CMv3qHm5sO/ZnI" ..
	"jYtIVmcfxb+xjgCh34XqQrhw4EaHEmJcXxZ2/HCoU5xYwXYsNIckTBlERQpDMOxsI3hFUZvoWxGKM6rbBB9bSPefGO0v1owVl/Ji" ..
	"7L+h6eeQl4tdrmUcv4OmSXXr+n8kEagFW7uhl5z928Eoe+sB/fOfmUH+A6OxhIFmz8AFw/57METwFVLcVKoRFB4vE/E/APHHCnq+" ..
	"CLrYJtxripjD0Y0QcQcnOrVy77Csn/dnQ/lpXV6w2lFlsrapkjNn4CFBX2u/mZCrXPetTtCOxH6cU78+2rAX+TCY4w0fwz7Bd2p1" ..
	"bY0Sy3X5/aPdTnS772XjpTEfIw2EShxLrN/7EJ8LhF4WO4sHcPCL1K7HEXOvnz1HWRQHjGbAwceQR7WoZljubHo7H1w6ItyA+Ssc" ..
	"dbzE5q0VmCxFKHjcJRK6d4E09gNiUbDp/rCw6s/isduYaO7OIbhE4WlLERSohx88YNybwis9zY/ieNyeztyRImFznbZXcs/Y+gkz" ..
	"0VO5o6BPBUMgkkWq7BZV6yxFXW4dLwVuMPULwzbn+DzYoAb0e0MQJb/AKuAyOnk+awFs4lHjzeh64OLJjL50Nj4oKKbcQ8IFeijz" ..
	"8zt7KQcZv3bMRhalhqvv+vZmurR/y8izwsLmUbumJOPUdYtPLjNvR1uX6Zvjs+t/+8SQTmfaaMNFT50CQ4WaE3BSH1KxeQJIzkQy" ..
	"6itagm3TFicZ3wqxQj7ZT4DmXtExJ7PzBvi1qaVv7OGcunnXAxRrGihCjQVKYNcUhWkYI25Oar2kA33tB+No72ztDJvVjqvVbBUd" ..
	"cD3LTpxnTxCcqqp1ItP9vbuwduvmrnL7bGxZWzI8Pce1K1DWagUl/TqxH3Kbfk46xr3YTjwz1wiRiBCpZoywXjwFrcQB80ZHkHQO" ..
	"fr9/s9jEN8NG8injC8yC9JWCubVYIcDoDnO2u+wMZcdI4ERsZMcBzoqk9KaI/99P2IWQLJLz+Pv5VPU1cGRy8yJhPuSUPQ/VLYha" ..
	"zNLIvCbCCNp55sQdHXBC0SRJVWpXh7oTTzp8RaBKxsxsC9RB0gNvU1JKbeqPyMOdgLLxtbf1gSRLNqVrNumRMqLTPTw3S93yn+AF" ..
	""
local PAYLOAD_P5 =
	"3TBOhRFPc9GulQbjXCV6ToArnWX1116aP8K1u9vTXlKd21FhMMNli/yVsuXReGYda3FOatF+mOJhNCmrMNc3nKCOttDE9QuN4QcI" ..
	"0ycCBRfJmr44ge+OEJ2VHATOZJrAzNsXmx5GWr2sDT99OVROBLFoCZMw37EfeHDpBGknH1KvXu2L5tBux/vfRhGLdfnfMVLUWdhP" ..
	"ceGc9GzEAPey/SFSGq3FSbQ+U1xImkekXkyF0lCALKHYAIVjzENoaC3IdA0ItH/xMxqNYQth2DVe8N7KrIs+wUbVdLXItGdoMvCA" ..
	"41FTovaPnVuL/IFi8nrVJjM7uof5zdOFElXprbCs5M8zFhdjs9+Sq2QCpDhJa0dh138kFl+N3rEl5NUEZrBPpybcJrFX//9MgPHY" ..
	"faKUjCbiLEreuAskY1eHkLL5XmtOpeoABHIHHjhbZmSJ+DHsBpJ2rxoT2xLA1waGxHG5kqARYBuEQ5oaw/TucPdVo/Cnrr5vqLea" ..
	"TlFPbDodz7aL1csH6Ir/06jQ1vYdYpfuTCeuIiZsh3eL3CJ1GYT3k35xDCw7Mm1Khw4B1yGn/yIuh1FiHCQ+mQhvSVx8ZoSYPhVH" ..
	"LV+G/5RNeElbBNLJlaP8sriinu6jXUPjCRdEAMIaYfwfeq4sbMpIzkwhi9aK3AM9MI7llz99RYno2Y94MjAXM6yEJ82t5O9F034b" ..
	"cTrb9u+pfwjQyR0eSpXJPCRg3yG94Z0UYz2laP2SmwKisHlduM5R0Z/Wl8dJNuEWa2bJpTHAoagBBU14teARbLqvXT9xHp865UhM" ..
	"wVl0dT+0jS5a1owJ0841e4Lp62Vf7VD6LewxFqV12ylphMuw+4HhiM+gyDBbFZrQZ2kFAIyY22zaeAlhp2eGS9+EioMYdyUwa5iE" ..
	"Iq2KCB6W2CBW+0v+9tc5k4Gh2zhJylCgu9t3+zH2yCG4Ag6ZlxI8DnhxCRP9U76gCeszjczfQC/tyl/JFph2HjYpdMTIt6Na2Fju" ..
	"Nxxn9IGMchkh5KbVX29kUGzVnHI887rOrqg9nxVln9G1XVVAnMiHJ+4mSwmgAEsuKV1eLpwGrNSh4mCdHsEMLC8nkxyGqvk1o+Kr" ..
	"k7BspZQatUbGe7ekl3SONslMLjHnppFzW6iCqUivCaX3XSGolwHte+yAcdmEdFf7LGPcNKWxeLkT2CvOLq0Ea/YN6c7pOHOegU2L" ..
	"8VrnC6c7kle0Q4q1F2nHdORS43wwjB6eb4cUU34m7vDaHXXNeVZkkHzxg7epl7ZvtwRpR6Y3sQiWM/RDuv6rmxv9NlckaVvs7hHl" ..
	"tE9bNlOJfaR6wC2Ed3+br/oOJ3fCK56Ajj+0V2fEw62f3IXsnSrD9/no8J8Hc4yBJW38HNd7Tik6gANMupya0fcMDSpBKkOGgkNP" ..
	"WewUcAzMTZhPR5ZH6Gz3qauHNp0j4i38hfYY4yjEZE6ZvpFF5l40Voazc2xuSzZBUVKZtOYgUgH18adv7dwgMMQV5TzlhjOXmUXL" ..
	"51KdPtAzSSbJ9L5ykla8mlKvDZc1U89AZeSNFneS37YuSJMv9tBz09eKDSSIih6y7HjazMrJurK68UlVsq/rdUV+L2LO7Po1DCng" ..
	"7o7eU11laYouY4gy4bqTtAXCnsD+2Z3+8SdJ+hXf568rkq9+cyDkLBH/zdF8E+b/soznFpoV8Wi4yTWAnGOjGuDkZSbFZHQsRr7z" ..
	"zf985CxtnStMUaBQ+pT42+KkTStHr49ATDgR9QGFZtAef2a+GUONsO+zkdnqDkZkSnAv/zos78ZIAvNXbbHty6RlosVLvg+/tYT4" ..
	"RUNsO/o//wmdGQOG22PIVsDRDpu76oESk4ykatr7dIoGmncHUSuGkAUG4lIYzkNln39HR55xnPIDwR1uQcS4PBBdF9W6WzKNGoGa" ..
	"f0yNGy0yxNLWpCLKBYRUlgCMRJKmsE9247yS71tQbxz/kJ/Y03dloZ6WAXiZA/IvsyrKrZzmDVWLHI+Ti/c5YZ6zbequhhbeWvwM" ..
	"/iui7vvtq+NqzWletwFsGDo1F7+jvFfGDFvLwsfqnIFyXPwQde/Wl7SjCQaPKEVGZkUY8Y30SZfb+AeG8fxv9q9SDXy1d2kBCW2s" ..
	"agrNSNeKQHBYfRtUGqgsvxam9DieL/eJsDxfxbfoxngie7NzHpH2zCVaktZQA9OXNfJ5s/N+y3clntt7S4wLOgPS4kVkgGOdIKi2" ..
	"RfeFo9MJ44ZoPB8Tp91PAaR2FmyUDO9TX05nyEPFK5E39tdq7UFW2zuVMLKer9gYkc5Hav+quz9L6BMRtsPm2X5ghSGV8Tla974v" ..
	"FZQ6AfxZwlEOPMWcjOS4ek2cUdk6GocSyFW9W/MWGA0RCFU1djYj3ODsfhRWPUDFultICzjuw0/oBzCP6SGvKMC/LEL+GRHUXzXp" ..
	"3at6rOinTjIT0msiW5SzpiIY9SrhXgbJglw1DuZIJ0swdG46iKp39OUGXiKKJB+hYyo32xv+ysx7+K2oG02NyKdD4i1BoPPZ7YSm" ..
	"VlqsO2iys+Vg+MkgNvOJe1ufkd5sok5IhUDg8zESBkIagBtiR4sNlyCZDXjQVSb5OotRPqmy3p4foYGCldYCfJVFWucqN+1Ee5pr" ..
	"M7xUYk/6HOG+jW5qzg77acUplUTpReTMoGPvzNaob1wKC7Bgcm14HfWGDa6FGnY2FQe5PAc4fIS4GVneWq+8dd4iy29y3wcxSdNK" ..
	"bjQNacm1G+Z4QoJx1env1GlgCAf7uFgct+W5PPKsSHozgnRWAxuBioqPiKexwb/qM3QCJbk8Ga2cFWHnMzZDWeefM/shjvAZa56K" ..
	"z1Bke6XH497qnosO2Xl57Xhj+6sK0Dn9jqwwMoRzt+fRFjg8eN3U4Wr9+tYh6iyeKaYTPkpPjblmIsAckB66R+9JZAMf/F2xxEy8" ..
	"BJ6KmMzawNILe0dAXrQW4jrqi/vU3ZaiRxVKuk2wDE1FbRUgRB7xrIzb6gz2L+LCPf4idukHpQO4OTppB2TLMXuoztZtGdPDQT+y" ..
	"nJ5K3k/be6Qf59wcTFJmLM6bi+EP+O7czIbz0YsRolYBXH5JPZ19g9QDZt3ohX2gvCjpaDfGEqgeXSS4cL25o/DSvgUYm7S6aHuO" ..
	"3c/4MZ0NY6+37UfKOguX3io7ArQJAEKZKDrMccawHnqvHM5Qj67GmDQRprC4Hg2Q672jowQCVVj/5oeRNQtxswlp12Y6Qb5wTeL1" ..
	"tZQnY4cMgRIFTSN+rVdosrfqpftdXnBYCFSte+FUUcQD673drEBpurpBYyHq+9muLx+MsaU6m3Im6fBut4ar9Y+Mm+9AVvoqgSFW" ..
	"J0S2sOydbvu8sidZMTQYt64K6onE4xNTTgTVAXz4tyda4zq1MiZNPdUKu3nPThDTyyBhaIVQ95kqP4rks+mL7m1U0blGo81iJ/a7" ..
	"ya2LJn53IKHw+PTQa5pTMmjBuY4HZVMvFfN1p6iFRCSp0/iInPZljSPwGVfTtAkoXShQcxvu5JXJ+5MKZcZvXN1NOe2SKHb/ls2f" ..
	"MsrCDi5PxchiGepEqRoKkrK+pWlD2yEa6GY5qkyWqE+qwXGjd5wyzuY8WXhbSxhMzwBGE5Eajh0mQdThRq7tH3r2C/6JTvLWygpT" ..
	"DK1PJOY0KR7vosIiTb7p9Znr907y0Gs0nqef9fpiXtvu1vRJm8yJUo/0mp6ZkqChiGw5YfqpFV4PkvFR91S178t1DQDzT9glr+0S" ..
	"d1We/a2EnvLfpnOYPg/WqVpwRQqrlG1s/RAMjr9iYmB7c/lqYwQdzETQupAP+0SWoCE52Gz+s19ROfFNbAY3dTKZZe0HXQ4CLq+k" ..
	"GiVY/uVUR4KxB5QNEP+JqtZIeu+oz4MxLhbu1FoP99U6NSkHuZN5Hj3KDDRxFuQwtZYF23gt4v46XYntB75mfWgl80SKNOUk3s/Y" ..
	"Sd2XAFPnCPPvItxdWN0DorrwAnQwbi176TSTJlNy/oBkA0Ndil0GaEhIzPYoJ7lZVxp7NmkyUVwzHf3q1R4OIa+E4Ql4sE/fBuSn" ..
	"OkHL0N/KFvjnpifMPMnuKjBIDDufitrPosfIZj7FAFwsS+f4qfQ4vNXArY2lm2oeYnO3SJnVIkEiqJiB4J1Jcy7EwEu1Lgzkp4MA" ..
	"KNrbjqFO670qVPuisKanWbLozgxtpMkqP2C1/pP00nqSZhm4lWDUzJ2IqVUtcics7DYdE1EvlFzbmYWelUh+fIdGp1ymWtUEJfot" ..
	"dY3tkQnM7vX6ck1ILq76DvA1WsAl7oJ9vWBn1MoI7StfVhlooZJFXfYdTAefWnpUtWgh1EXVlKPHGTBU2muYAV4BKM4u8ETGShWZ" ..
	"W+1MkiuGwERJ5aHHdO4C2kx/zaS4TAzQ7WY48DrjKXDoo+c9E1TeQECDhpSp2P7XBZ8E8fmDpJu4y52RThtaWqb9QCNuhJBocR+y" ..
	"Bwtr6e0QYHWFI2vT6S2oJpAqtRXrwNfeJYVl4sxwejYW3/fOSz1DNct6VAqOr5BZesZ7qwd1mNm4ZIr8xAdnifLzeGr7H45YBJbr" ..
	"hVEET3Ef71ib+L/6Vgxw3GymMzd9q0Vsgj22ki2bLgyk+It8wKizqKBnFjiX9P+c11OFRPkpJlNyIPlEDYW74zslJ9+fOM1vQql4" ..
	"sULEptLJlx0wT53Q3TEYjSKtoVWnJnSeOxNFp980qe52AJ7SRl65vJg11DajZLKSTHrdtBTYHkcqLK0bZXR2Rf2aq8g7AjRRHkmM" ..
	"R5A81qh6psZfKure7T/tm771TAyAQhm1wAiy2Dp8Re7TKZxkHDVb567TiUvLbWl9zUBN5Tir/1qxDOCQ/AscZg0DdOKTcfIm0ZBm" ..
	"G2kMcj5kHvrE9fbT7pybXbDJlvhAOo8vIXYi93S5Sfv1ARayp3wNojk9d81HfvNf/Kp53Nw31ptSBAAPJF70faTzeQTZOi8uhQ6i" ..
	"6foLVQTJmgMwI2VOo0N6EM9xZci7mXVd5443NkIZikJd/UJkPKM167DAPX/DF8/2ArDFbGI5TjZUSNqJuEDYfFtZdCMK8iiDSXEK" ..
	"4LQEx8lvwg4iDSXGthfhoCWhIky13Scm5w6tXCwWZeP9hsVrhER/+rwyfOz69CwUYqys+D0io854qqSU/KQY3uxlGF+i2ypPMcut" ..
	"wRXf2eqbGvDqHRQFp5PtpaTS1+5Wb/d945G+b+mxY6sLfT5KgorDMCBjg0OHpiZRAzmlAn6KMMT7v/5EP3oSP/3nBJsgwtbP1wHN" ..
	"nRX0ROpufxJTDRnjhe9h1jC4EeGGvrEAa+4P3XyvQtIw6P38cd0IvJGmnT4GsQ8XkaPr5FnZmqjJ0SNMZ74Va+1QCjXsGS31dKRM" ..
	"IVgQzOQ4LKVw5igbEvv4UAUrJimHJGTOTEUMaPRdGaWxT00S6IJD/ICJXWJnP05PlYeiCWND7MdG5LWAIVHWk/Gc6+rjoYwS4M09" ..
	"zhZhhnUzV9s8ZoSL+Zh676EG452mBV5J0zX1Xd7GKIC+rjnQirmuL6g7z9W7Au3pM+sosOeytmBaYEUEqFLMxif5jFufM/Sz26fR" ..
	"cKahMi9RgR5ZTkZh12qDY27m4D1a27gqSLlYM2RGADK4XUrTP/0nmCW2tPRBeq/UOWPHoz70E4NM31Y85eVMaIkvJNhsTUZNmgOx" ..
	"t3qPQ6lhzo9G33wuMef+bs0RcizOuXtW5rpRuR4mbP5XcE8HpmMZwLOQt9Dz6LGUPWZndm7WtbmG2J449yCWezaOuXEv0r4T77qQ" ..
	"3rFB7BR0wgzjKAuadAW0Wd+K9GyQ/1MaIR40f05zNM79nCW8CfTzTaGjQr+2qFMXzldHCUTv6pJqndT1IrbSn1kiEE3BOfjioS1j" ..
	"dJ+9hjoM11PSwu+r5+mL1d7E19iyMJiWm1V9paMrzmgFGdOvwY7laYte8boV3UEMw5vTwhDL3kYKrzT0AQrJkdNVfNlWgXAuq4D4" ..
	"MBivxAyx25xWU5IUnDQ2BUoYsNY1OVHAIsmoW8e76G6LdPZX05mkDP4lYB1xkLyDnfiyA18sNVXrhnP6HqyaxBHmH/KVDrOIIGv9" ..
	""
local PAYLOAD_P6 =
	"l0Lfjbe8hj6kNoTPTzKa8F2iJUs+J1J7NNMzxw5d1ruHBzoI7msVYtjZyBp6Dtw8AwGukWJjjhKulkKBImN69Mt0wynY2bIk8Q0O" ..
	"kFdQC1lWGPTcHEIV/qPf81qWpdnMZFTFgHislj1ru/jsysUxkFbt7TKI3RZ/M67IkQ9QPkTJ78Wrg8Rh+FKD8DGey9qfV4AcNJL5" ..
	"mNN7tBnvgpwa6c2MQFDGQ6viV2IYiZaFJA3KRks3ZMUhUVZG7vzF2J5cSOiGaL6cnjTaOGPldqlobFtYR/O+m69gXwO2g0aPcOoZ" ..
	"n9CoQBSp2OEJRN27TA50BdtbLFG3IXb7pUXZTUokP8IsF6cAb6An2ih0rJmHgLCEO0elhnWWZFID8ziN+fCdJevfl2c8zZ9jxAzy" ..
	"CUssOZPhOSl7xHU3D3BO2rtzR4kZa6FDr8O8yOCMSDWuLpbZ7Q/UnhHIhMcyUtLyRCTu3u45OcYMVpVMDpz0NvMWXhNUVc4eazUb" ..
	"OERJSblz97AKBL7whhEw7q4IpEYIJVJwgWXSCzkwNlK1v263WqaPaZxwqYnCGcefU5fkYdocQK4MtV+DVx0yVb75uDpAbfgfGkna" ..
	"9sV3axrllc4NipQzGLqkxZquSAc4Xwx+d6Y=" ..
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
