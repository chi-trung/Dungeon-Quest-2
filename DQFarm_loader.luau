--[[ DQFarm Loader ]]
-- Licensed to: GNURT (1 thiet bi), Gnurt (nhieu)
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

local DQ_ENV = (type(getgenv) == "function" and getgenv()) or _G
DQ_ENV.DQ_LOADER = true

-- ===== luu key theo thiet bi: chi nhap lai khi het han / bi thu hoi =====
local KEYFILE = "dqfarm_license.key"
local function hasFileAPI()
	return type(writefile) == "function" and type(readfile) == "function"
end
local function loadSavedKey()
	if hasFileAPI() and isfile and isfile(KEYFILE) then
		local ok, data = pcall(readfile, KEYFILE)
		if ok and data and data ~= "" then
			return tostring(data):gsub("%s+", "")
		end
	end
	return nil
end
local function saveKey(k)
	if hasFileAPI() then
		pcall(function() writefile(KEYFILE, k) end)
	end
end
local function clearKey()
	if hasFileAPI() and isfile and isfile(KEYFILE) then
		pcall(delfile, KEYFILE)
	end
end

local KEYS = {
	{ seed = 1125433984, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1131192982, exp = 0, plan = 0, hwid = {} }
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
	"ELGkjvJ/8zARmPcoHAdjWqLLTIkSUsnV5AVxJO5+TP/MKGlhSwlse3eEgd2gOO1+mCKT70VBdHDWisbx+Yt29McfojWZH8AjMOzS" ..
	"3LsvHcfrZyVH8Z5Px0QaAq5aUGHsLPxPhQ6gu40MfTCoiMeNC9KcaVadyBy/f0VPluiCqIrl1nA5o3os+bMnIhlvqq1R6kpCT4bY" ..
	"J2lznb7k44nYA2nKSjUDQINBhM0SnpUK2DEvN+mKfzmnO5N7vIicZ0i6iQWlW7WFKWZSfcUI1RCuP/8vOazebK5d0TH2jZhwQDC7" ..
	"lUXabTPkC4tTexTctqzH5YYLPsT69/p5ZZqRjnx7bW76S/+4PkI5d6numJEW8jEgusi9LtzCc0NKB2SxolbkAUT0LapGDdKyZnSz" ..
	"dKWwlDv7BxdtI/ktIG179hRI2HLJK8fwaQbIPUeqW3BldfBmTYDw2n9VKxXI0ncN+soHmXROip49Ia7E1rTEK1v7noAGRgRg6NXm" ..
	"c47pVZIxZM/vENljfDyQZwNvqCExLOvM1ntGdQQe8XyXhoKczwFqWn8VFDR/qNoPMPOZspeRomQB2HtuN4ZrNRgM5o9scu+LHXk1" ..
	"gQBlgt3YG/TMhPb3rUslQ61hhvqLxaVvxzPNwN2irQ0/u7yZdz9SW2aufA2bAOUUAVFJ1Yjvp9aJNF4CNtpR4ZgoEZ50pEsDz4LH" ..
	"vjoR2IFa/jW2W2K14EZqiQvtFqVR9XKO3MrH3/wCuyhdmoAZxE58Kkw6SjMXhQcw1zCRO1U5LgJegQOdL2+WVCfQE5TKkAf4BcC7" ..
	"zAvEeuidynyFW6l9meMipku69jL6lHjcGJZOwx0DvkexHujpfxNUq5nt82yUoe8bPyZAn34oBuSY4tAMOVzqahy6v/PWp5al8Bpt" ..
	"fRyQ494UEhlnsPVxEd+e3J5nU8T6G4OmL4Uy6QQFIgJhdKxSWoMnJ+AIqFPSnWdKm5k70w+1WbL2cN2+ENaIcNAD9/cc118VUy/s" ..
	"1McA26errIT/gobdyrHB73wsv6yAWAbP/3F6ImDL7CJ3ioa8jaE8ujDFyRnCuvhTVNHJUcwc6hEwReT2VUvTCLoqbIPWmi+5053+" ..
	"+W8t4sOdOeIvubGhq3bbh07eSg8tEYZaApm370tIeXHtsv/blwrgpEYCztSApMSPFEiXPHSO/ycyf8za+8YLlVq69IHfGGM9ZN70" ..
	"o2jueOHhJpJSaZGMfF48hZPWz2IRXZ/WEQwBrDHZsdM3658v3GqtHLVTMplyBa5Oilf3m3KKjoke2o31Wh3LU6YiFWfK22gN7JTo" ..
	"qwfxmjBW8/a8d7WUwOI29h4QIVW9gpjvieYQW69BqH7UQOaKomtFm+KK/k8tcRMJCqjKIiRrgf3S1xDqYqqSrFA0xsiiGn/ErKzP" ..
	"kLDtwTqWCEeiTyExpSZ77ksCN+pE4TIcGKCmnVQ/eWldUjag3AI7LBaJr1oTHrErs6uC58Ad3VspzCdge5SxfTQehCoWnDzI6R4X" ..
	"nqkYdPw85fdrJ/iJ/QMcBROBD0cpaq7QSSRrDBr9JIa/T3sbAIb6XFAq2tY/okpbkwrKOekdvqhJFayhw/+Ffyves26wfNwsJ/pf" ..
	"YXqPbORs6smuJKlteugsWDmQyO1b/PMu3RhXYXzKodGxYhXzGYSDtTUBMettP2kSzkfSVoje7qjfx9b7mT0fotZ1b65ha1usdyEw" ..
	"8HCLE1SioxmoGTajkh/7uu6eR6GvlhheXKFuDyPn671b9UVtqhoYyqXfB45HFI1BSbeDUIx0UEOdKTsruYPoZNAHDJn+GguihE1T" ..
	"imXtDnPSRSQU6OuSYohk/eMTQchXx/M3vdam5kQFPjnVTT4H8fh3cSGLPFsx/4Wn4AqQIrw8esT0nmeP1F2IL0AI7LIMWSJBvjJs" ..
	"JPKTbNyjukhiDXVStCy6oowu7EsUaVLVaNPXFcSWyiNxJ7/PBaR8EHfIkdeBjAWzVovCcwlF3f0aB77ITNgGMkMMrJeKkbRUaMT/" ..
	"KdJ0CrrFMQoAwSDy4mvO6aysMQSCPJzpQMk3IyVhMgu7khdOJcDflf3bN8qMkP/+jN3dPBQ7cDi7gjDW4FvQpO/LJpM8mwXGfqHn" ..
	"nO+sFVmizznlLRzzD/fyIYCUqYsiGSndd1J8WGlZS/o8XLXtdZoSH1lsluZ1Oq4V2C2bp9oiIyFFqdX5K+q42GDc7vk60GMA+tFq" ..
	"4NpFlvFJ9sY5WtHfILvMJw1WZowJMJlQD9owvAKc+oRajopmFoGm1KWp46nyZdFcgUzjeafbShNE9f2ZBOXE5G7qaKVtdOQ7X0XY" ..
	"wNlOZPUpKfiv/D7FiFHB28u/vdU3nbeuVn6iY4LuJZVKOkebfT2xaAS8uEgRMntrSDKul5uaq/+sEq07chNLdXR+0HD6d0Zm/oHQ" ..
	"W/Oa/VybJYVNq/Ls/PY/QIe2avoW4gbFbm6yQq95uCwBaqM5it0BIDDc/uBG0o4p3GkErk24HbOrs+AKMurk3Uw9Lhl7EeINwy0m" ..
	"dOZ/exgobmphUkZauHRZwod5lhRl3FF+HcwjmlnCPxG6y0OE1eiZT/87Xb6O9gj5O/BEZqxlIL/mnbMN8LzgkN/91Bjw7nDf2uBn" ..
	"AtLmBBX0PAlkOZiyoIboBXb2oSW5/dVYLv7/6ABbjVTiZ2UGKfQzdkBTW4yu9I2eemMQHqf25CY8uNKT+jB0QqZJPjQzut6CNmDN" ..
	"RNz7d672avfHz67Cj96ulzVkje58+JVn6/MC8C3RjPwIO1t319B17zKtB/rhTv1rYMJ3ql1lqrUeay74Y5lKlF6yxKByR6TpbnxG" ..
	"GLoW+yjmPqqx61PrQUOOts7QlZ8yjfPDrz8qd4TlOPTxL01ENLUfeNfdaQvQkDerTY9HVnONQ5BRDhhTkRQlq8g5Q7v7ah/PKm8H" ..
	"fgJU687DPDm2SmE6UJD5NkYbOd0gWAhqI09xkWtbqrdSrFyH7vmZPtciY14cWQUyKtZHHwAZTpilQi2AHL/ZIhzbgyDMxzMZhMxx" ..
	"g1JgaFb/6prwivfYBfX8wqvh+H7BfOLt05IkChZ1/ztcgrWw2XFHHCoFxp7b5FKgds6GFLwGW2TKJLkzSk+pRy2pZkHbcfzyL8P/" ..
	"o9KDddTvGnAbuUnI0A+RNT6tpOvxEaqQt16SEWfof8rjuIgzLbLplXdxKuOZSTbegCOMD5UZkP923oEr6riR38HpXvweg9skBr9c" ..
	"xFJ1CBUw3F6RmCMz0bnfglY7rKqkW/+TeRhlZqKhXBsozcILxOaSvQIDhKo0Kt6/9K8kC2h7jCCn7rMxzLjnNzwtzbSB5tDP8wS5" ..
	"u+pXk68l/kF9E5kUvYJWsq8ZBQgclU8YMc8uK8t8gZJWlUWPuZeJi1mJEy3Kpj1FZbNQwOu5QiHk5GeEcW6HDSCUPaRJueVdjBbs" ..
	"VLW3mIaaJ1RNt7yKosIAcG0UdM4Dqv8P+VBo265ZACD26NAzqPcSf8Z608XCFllTxkZ+v6Hb+RngqG0LNrhR9EO/Sum+rbHjHG30" ..
	"rZ4k8icEyOb7JhGPS4u2FYbQalc03X9gGfulqTgod3D0Q5izrE+B3F8vk784TiP7pL5qkd2EYyFr6brkJTBeJ/2tlHTUip4+MdbS" ..
	"NOT2S3Jx+EePAW5sRCWXurStz5ZXtqqH5+1Xx90KTJXn2Qdv4COMinhFltZO4hUvPQkW338+yryFJtDULkt0z8LgANafDP8ZJG/2" ..
	"deaIsMGDkc19yq0SgBytiY83P5aXTOj3zKaqp0hKUUk6VWDBy53i5180ELvZ2l1YIXHVUh3clvZv1NwtqNef1JxuJhAJ+PWiFXiZ" ..
	"XC48/5DfqjBHfBY6Ksht/T5f9JBDzomRQcthBF7wQ8i9CE1DrDOis4O+p+UHg5rQbz+xn2Zt46NtS3m3Wdi1UM30Ghr2RvYzk2eE" ..
	"hCT7Z6h8C1vUsrThcZ2FetXthJqQM/m5DCivxvubdtxl1yDShcLIdzgZcBAZSGFNNIyZzwhcsbY2KJ/3vx68+OS4O7zNMT2fyjo0" ..
	"p+IlWevLrSHfcYc24EJQ2WRJ6HjLxZnmev6Qttj0RtGOj8rCz5vdGHWWjz3PprpX1lFVeBd2RWHLXqQZEAxVzCQzQdXr8uHXdnSZ" ..
	"HabGpxE4pyOf8kAvvRmOLGAoJHqW8hos2Ftq0rES/iy/jB00EPlBFEnOHlZWq+m122/bvtYxspyEWoTiWSsr59/V+kRZAnRFkMXJ" ..
	"TUBkqMas+PBt7HLMuXGZTLUtmRDdntOmRNah0WpqQng7ZTM7KjZf9WXj7VzJXd7N0RfBWWX6Sm1w4emDKf+VrplmTCNV4XkLzOCs" ..
	"dJYUa/O3JGWGyQKTlE/EHRo5V/Y0kBtQir5v5KIcUIJ+tUBGmxnK8cYgKjvs1m8IRd4iHOMHmLNzTIzCtebDypo71bA9aDd8dAWw" ..
	"X+BtIvfkh+kspiYg8uY5hbyvUhP527KyiFobi1GMg0tiAfpu041GnEgCt1qqckfxZuG0vbRXVWjuxipG+ghCkUpx7eGJWD8BSewp" ..
	"fw2aq8lWBLA57q3qhF4+H4DreucA/YkJde16o8zog/retn7EjgB42RjaqlB3ZEulVaI4OgtfuEbGHAMgeFO5QTTRTMJPRQTSYxet" ..
	"By35EpdXNnEsdQyHjFWZ023MaU3Ms98YsrgDSSjpK17zexJPpXtQNp2YuWoHYWx0o+HM1A3R69zKvexYrmmQozJPrsSHcqX0/KhN" ..
	"Tcst0UE9Vigkvh/G0gH+AGLqCwhmcPPqHTuy/Vl4k2nrKmFYQP9M+H2vDb/jT48K/aMvOhcFzjWVfUmJs7n+Tja+BYJU8IYOEFR9" ..
	"w5CwgoJ8cGBlHkU24t1cBhRqrxfCjw1+nRWpjX0E6hAmfLbFh5RPjUQkXG4Gn5uJtv6Ao4/04Ev2uNYbERaHPAIQW0pwTb6j2/bh" ..
	"rDDH2NcvdV8my0ZAs94B3HkB5w7oNKEEKOJGVz2fyJduRk9dFEkGwrKiMXbx6PcDz4S+z7ArpFqip16V5rrVnoPk0WLaI/ADUiSD" ..
	"JRaQXYgxkOS3RQOO1ZQ3H3peOutfGWELRXttmMZICOcGEXw8bNUCrZtt4Y6zq2bDNW3Db0XGfp/lS53J/+QVpqeHYJ996d6rWiAA" ..
	"LP5SoOxQnpy5Sq0ND9w/Cs+fOmJjEVDFAitDctFG4hRgP1C1BoMjPgX5COyvsIlJbSptD6i+b5ybOx0EqU+dLitSL4RoRqJEte/P" ..
	"MO75xgQaopz1k+V7SPX8DervcGi7IKH1UKiBzHsAvtWLVPNCnmwQjCGgRfmV4Fwi4N0If8mrWqUg/VUN/Abx0LhPtzmfNNYyDWPg" ..
	"CJcRXs5ozfiW3qMF0W740T/TsqaJW1YqB6PQfQ98zt8O9WqF4JROxfqnojNTSqr+yRYG5aKD+A7oBVvClCsAtVOwcwsCcLKg57TE" ..
	"+TBkjj4MHbdmhcMN3cYwWqMUTVrFSwHed+2wPSQh8y+MJJHqXyL6jp0dNqluG6EBlyMOnKLoqPcFTAwNQqlGqkUu64RGclo46G5M" ..
	"WPJJ4SWVPZqz66nvcaDzfOLgViuMjA3Q7T10d8NMOunQWuC32RIQK6wzjCWt7HxqvZYpYT6R/swiUsTaETGGj4ByuSY2s6FhXlPa" ..
	"s7iULWZCEBnLVZGUsVFzzC7d7joTEwsZcgYh8K0ux9Y7cGb3b5rcfYyfa1IeEpSbAFOQCwXzENcWF5xWCCRdbDm3xMbDeqwpWoBS" ..
	"/n9RqxpOWrAm6tXdCS+p7jb59BTQU8yFaNZF2twwsFzDRvmznnva9vygnpJgdPtoGOf+pqzzMvFdyGakKjB+BcsGfu/OKCVaHxg2" ..
	"yF26kze8jeT7BXcVqh1gv62gWRoAuYHcR5qvsuJZxDOY8ppGCbpfPgYrp1jO2JFV/Ds39OJpBvrwIJbEp9fcHHX4xgbkqDcIdppF" ..
	"kW+UmikR6ocJYhqctW8jjWmGgu33YevCrM4tYFXI1j+La4YaMP/ZX+wB4ePD3qw86yXwH0VE65i2eF3iyP/wAlIlFN0EHvcyzsj1" ..
	""
local PAYLOAD_P2 =
	"OcfpohtlzsyhsZPD2qORHEq8/wb/ZxbxBOH3uTtOCqRwpxPvj2O5raqkFlJnPn3fv8e/Tfe/52JufNNXrwEAFaUBT/p8w+9p2sh9" ..
	"s2SqXwMGPtRlit9qUwbBo2oiJBbTDqZdlhqtpnXt7gOm14Ni7oijspnZ9qJqQ0FAQhJjwuZEPx03jLbHebdSF4/h70knTNgNjBfJ" ..
	"Qf7OgWuqGA5NT3MNcrSLSJTS/+dCm6GTeDiQ8W8F9zSpZ41Ray1mRk/fWhF9wShkRoWbHox6bOT6XQy69iUhO59gPxYh/E0Eflz9" ..
	"CLgKAlPUa8prdQaVt8lkfyw90a+eNi/Lq79D3NDpimHg9g+GL9Jue6nP7/XwqbAvzQGmS1ZhTfc9tR0t/ti/ezRZZY+65bZnBhNh" ..
	"wWHFlh92xPqmD3cGtmZEH/ol0Scf3EB9YonMyGuIDoAVcxoqg318cuNMlCW4QXvnJ8jt6Oz7K1ht1G+C0oAmD05Bkt9PrxVvZcc2" ..
	"hewKv7l8amiBVkwts9TuBatUJMPLD3tF9FPrMa0eQlNgGltGG/AuowH6VMoMnqCxCUzZBsYbj5HBN2VfAF0ukYOyTkH8iD0wr9VB" ..
	"PQajTMKfqAEXOMdM0jKTjUuZrN9k4U6ZUroqnhKDrau3pdq4nZ6jjTQo7GysvmOjLJTdQXhElJi3mIeeU/UW4LI1H69bBwWul5RJ" ..
	"LfDv+ZgYF2COOLKEvyesXaot9NysItnl0LdRS2y+sbsokvOjJq1LccVPqHX76etBlMlO9hYz87u9vZUckB8cWeX2z1H8bujpURtz" ..
	"2gycrghyiyRrJtuiK2282zg5G+gE8Pm+jag64XH/Hst9iHw8Oufy1uqsD9NM6KG+/Kd8yrmYB09rEH2VtG3HcwXNohiiyYla2OGX" ..
	"5Xz3ohpulsdMHSCXfYc1ovw3z/B0/1yQ61JEL4/U5fMyZXv6KgiIKsCFv73tmLQlfwIRHJK6TCMmrKm7tUK86+yrP6lml7ReTLtO" ..
	"KTaThOcIXkHkSn4KQ/VQ1VuXLH+cAWgnYTCuN1aF+N53x2JHUWZd8rBAa6iwmss/RVYQcO69TV2prdxXtmscbiUcSiMfMkQqX8ne" ..
	"zCW5SkTnn1Bgu9QV4j2hK8VRnBazhYmnahOiUZamUk+60L8+yms+ugkpJdfihSdYjsvmlvHlx6Oo55CZEAYRHxpy3k7VD0X0Pomk" ..
	"67PH7lu9qs2+k0hHu+sDWke6OW7OH2DordAxI41ApFPAh+TKR9t/sIWyE0ReVLk0M0lR0tjuyoTPoQFvXjWzUoKNouFO8ubspylf" ..
	"wM0LBpHCiDboW6FNDDOxQzbkQx4Hn7adMNw0+V8wi8NdDJwcA3jbEEZgXuqWWHbdgj7HYkZ3siUL+YFybXa/ocoWZZOfCahOpS4W" ..
	"CEwdqPCMFKx9KcRfjkZQPmaRFeOaW0B9FAcGRO5ZjgDce/4Yh8plOwdoA5WF6yIzLrXmoI1VZ0wLawWiAljaALns/GJRWut2AkRA" ..
	"ABnjrIoz10RFXeiMurEIA91F9zmLsExcZeUMTxDjlNEOCJx8FGMtF/oc3cyBVwwdGd45oH9ANOg0meEMEyFIZEIhdblrxGsH7gWl" ..
	"DTn0KMawxSsBGP78WRNSu2VFCHaKteDOcU+I+5hgB6dik1hL1V6xvLm1Kqq2zZUhWKn5aBPdCXGI+NXH5VlbUl88XWUajZ5SjCg0" ..
	"o8LSDTZLdNe1WkAquRB9fhb4ZCeM91U1DXePn8evjNeHHaOcJIUwyyBBAeFnlCfEWFr9BbnS+RABkB3ZQI7l9eFYgfyl2IxxVJqv" ..
	"wMz4SX0plZ66wn/2C6aNQAhbnvuJrcVRZAW4tm9QzeFhjK2pqS3pDcvRXrOYIV1jzSh3abp0UZkQlwc0l/dtc+nVTPWwcLvvswQ4" ..
	"Uxm2vf/b6w61D8tm1GGgP3YposQSrRJyNxBF6KMYa5H1cwwo08AE4DTehdN+yzrvvFQx5tN0ZfTXjcOoo6cn3n8gtkge2TpxGTtv" ..
	"kl8yXyNTHf1l6KqO+LCXtSerHCEzwWRJO75tR/rwyZM6NprT0Z6+GDFkT61tWWeJMAOiNOKEMI1LL7ozSMDvf1435OsNMjmpoAxq" ..
	"lZI7VG3ffemB5NumKl9sPKvZXyj3mfIgmZ+Amb7r+PzudGCqmpt8nBL4yR6qYy0z9z/MqxG8ah11kUU1gfaJ69Q2W/tgo57F+CUz" ..
	"joQpRgejQCGyGLi1PsJWNa4Rpo7riIH3JKcbG01APXcg7CBV2hntjk9yk7kcaHZBKfnWVkUuU7YVgWoOr0zoad5JhAOVoY4XkdQ1" ..
	"ZtXXto/MtNPM1dW5mYRP7dBh3q6Ifpyx2W5js4aeJUowj3V41V1V+egOMGS9t7ZHJHU+VVOL+eAnybYet1RT7GvP0ddrtoYh8UlA" ..
	"gCIF8AeXxmOy+u205q9c4DtqUec3fn0z5Z2tGJ8rDDPl6PA2+xccp0/CuOpEajg6LlCttWAGYh4X0BEUcFdtZCaR4S6L/ski23qN" ..
	"SHGheYCjT6jc185JC0jh1VA1fe3Wy5Kh0pi9OnbhEePjR0etp/+keQ/Up3iQa4KTP0515Zk/CDLqn7dSa3oL9tp3GPHX4veV9zvt" ..
	"7Dj0jsWKqeaDrC7VXy99FgQhCytePl+Gt3Brnh1wGIyP3XgwqmxaqJQr4IAbLT8hjAE+ERvcBaTKsMnZsU6gxXr+jtUdozwgLytm" ..
	"O2kLdFEwYLXGXyz8P9HPbz/LPuF1UCGbDIjMND+wcI30Gs8PEQzlDPfbH+d5wRe727UrnAG/BY91a41IQFXkJ6p6NmsaSrJ/DNKL" ..
	"3Vx/LiES8jMH+u3yIeNsYTCLolU+Ei+bBh1wcR84IXvSAaN3MEEFwgSqr9NA4zTa4FfTm1YXTt/TgEsTf0IvbrtMAU4qGBX7UgeG" ..
	"FIttpIAqwxDiumD0r5XVPcXXewZSDHVMYv+rXZRFksN9E5bXdFZycwg/eeiRkpukv4HlDzdpGZ4MmkuyKO38A+HzV1mstpLpz2jk" ..
	"MaX0pjTkz0KW21IjUewsSYUWepHFUBmkWwiEKpktcvvWLsoAEnGNsi5D5cIvi7EdS9Y+3IK3KeKqiFVbfS9jDqLV4dePkHyqMEop" ..
	"1bKCzdYxwquv5Dppv2mTiTPm5yP4rDY8X00wW6rKVsKXRdKjjiC7oKr2tkdMBDmaSvQeAWJZl10GgOYx4MlT5/tSMD9RwF7hobCy" ..
	"lRdtFbps/q7ZOmTz1iQqLNcP8cJVK2FyvLC099sG0LEvEh6u8fQy+PU+FhhS4eU4+vzUmZNnKF02JoC4FtUCDdiG/Fx76ZblJHhs" ..
	"2G9ufyIuS65dnM+cunLj1yqYSj/AlXlnsbSccXGGO+qE42oPAUWL1J7L9Czo13oEzIn8lZRp4M4CvCAQKSmhBIk7zOPB18fioleB" ..
	"03ZRwbdZSrdp8IWZ5YHbQkslWsC8vqaHu0US95LVi4AefER1HLMXmnesfi91uQRzdNAGUsCRESj7mHCkRjknzAOw08Q0cKZs0Mpd" ..
	"Dijk0eeSws+5NCz8n8pWWs4Xi0ta4Vrft3GzgOHK2ubdLTgTOoTBQnRylYTaTtTpaG8Gk0O6rw9Sw2rRGF9+BDr1B7uiK2NFAwla" ..
	"fkciwpbIEFcGiGdxF5ILth2pdfXMnixlk0lXJEnwmf9JXV4o420bhmbJwvNHZMUWyqTLvlhkOHwFvrbgtQrxOLigSdnw8ZtxW0Hd" ..
	"0ClS6Z7b5mi1OAzqw/sXcuhM+gXfAClVoWPb2zJerNoT3h62P5I2qpPjm7iu81txdBKWcc7Qng3kmKU+SC79Plf6mQ/A0yuPauc8" ..
	"uRnTuD2qBmktD5VZzdBC2j8SyO9Bu3GTRfpQbCciGSn1kiDNqyHmkgrVhWLuFSBtA2xBtWKtAzJXyfpXTpYcosWvWjtWTD2q3/Es" ..
	"xOzOQoLrUWHtdzucBXKHxDsGEUAbl8zqtYI1JjpyZ7u7Kyqb/LOorxNJ6D2Eahu1sTDa5NeclKeUG4JEUjFgsSKXVVJdG1F8fp6S" ..
	"LLHzW2JKMDZqYSpSTneHtALNAnTNLIXBusQKm37cCAh9Z78cfp89ycMlww976Dil2QYq5/RKTHDPwEwDom8VPfj8PI4TZ0DyUswn" ..
	"Z7pb5y1qLqsk7Ca0ACcyU4ji+t6Rzwxxep7+grNhpJC6YmEhH2lxcLTB+TN4EoDAxeTHS+DgPQy046iBxAnjbPQMiQ4M5lAcnqE7" ..
	"EuUodT7nDJp/qz00kh+oY0kPqM0VXCtUr6KYQX9novl3baAbvfonA93sPN9SF0m/lbnBJoO6eOFvT09RpIsZMtrBvF6PaAtg2rVj" ..
	"+Cm/TY4xJ4GJPgASvx6nbCh36UIIvmzNhT28H9oBp/dAjRq/skCv18MLk5gqFm5kMoQeTOnfhjATGg6+5osznR29p1kMC0RpnECD" ..
	"zWNro3zASlbuXuv3Ic0D6TWYBC2Y2VDEzMRwvEOm3X+IU0FSMjCo6h8x+AMQDlReVUbkg3ILlOZ+OrsHk5XfEP8ppfyN1QxNz+YE" ..
	"BfiyxLKjKUnqPVzwbzGIoayEi8FJzV24F5wQa9ZpH9zSXhX1aigjiy7V0rHnamOjqeRQNCEvgCIrWyYruH2bYMX3K5h7feXZoY1V" ..
	"CE5kMGKCvXA+kX+j0eWtm12LTQ/YqSdy6RXYUMRtMYDBRjLbZUXHI6+Sg1N83GDnAHBRyji6bebXBJI2V6rlA0ZjacQ4N3ppfJ2a" ..
	"zFvyvQkzwEnLBZy921UUYGm84CRV5jwtTk35Si4BY3jnv62D52UTY7gr3SYdm3dseBCPQGSLhouVBa1Tn3bShNje5zF8IyMxpwq0" ..
	"67EKVjmwwiEK/GB6eEc5yXRSL2Ge30sKobHh7iaf/PkRWX0UvbNO+ROsFEU7wOJ/zgqBGWdK65y56hh8JDkJVfhpjaaxR/NsdWK+" ..
	"aTtR4s84Xl9J9QPEUsMNXj1GUWxrgQ/hS1cwPwANHGRjkpEaWhA9T+Z5UvYvnM2iP1aetnliONqQs6Vlgktjvw4rn4Np8LzPbzX+" ..
	"spbmPEXzqiHpQghCaN0HpmtZQVwe5hvnOnTdbf92AFJTkF0Gy6TMOTRWsQGE76oK7JUrhYIYAJP6bGuj74USqKbq1JlPEUfQQssO" ..
	"EhQwKE36DyKEfSpVeBzrkja38KHL40GHWmiaXfJWuI/mvhTEPl78oDB2N/+2eUlpH+V306j1cYx7NLlDhYuwbkj9MlP4zRkj0r9Z" ..
	"uCpgrfZ89P4Tap0TegnLX9R+TojvZ3RLJF0IZYyr6TuX5J8A390V58OKT9oVV81hM17mXbPykkna349L920c1nY/OWb7/Tb/LFHK" ..
	"QiXSdOF3lws+meRkK7Y+MU6p0N1kzJi69Kp8vHE5E4CXWNaMnp8Zbw0vcwIIfJOls8yfH0wjic8IhtMmUxcHC5VzTJbVEKR/KjHz" ..
	"8bnabYjE90WTOVUUGtxrxCgJRhum9Z/4y6AEYB6obd+Qbv/apB/k8vTuBKQtBRWvc0iTJhJA91Jb27OOvnKFy15gC57BPXIhOaqr" ..
	"bxBzStLQ/b4P7Fhge35/FlhPYBTnFNf99VmZOfG3ublZjy/esDKTuCTrUmdfEFEXXtv1WNbkICegjcOrj13pf5wAOtf2NZjj1YMV" ..
	"XG3lH+TaPfFXciHoxZmlOLTFgx0l2DUPNG8Sy2YtSn0W3Hx4SLHv2/VyYXDs/DQo2IFgyQzPiQn1Pt61BiNrZ3JJILuq+m9C7/0u" ..
	"SydMri7+ushd1WGymjhcl+YRpHvczRINty0NEzpJC0gtfXibmXdacwA4UzbrGifgzQkTz3WSvMd/v+ZIEBaPP5/F2a85+j+lKR02" ..
	"cUEMnYk3HI1W+Wjm3M4j8sUaQmNhjwArKyulPZedIxHBB/5y/j4wd9mQk8GYFzoLrzZkc6i3PLNL9jaksBDkjQ8O28O2ZiuzzsvM" ..
	"TcfoV9uHpXIBWKv39RE1YHq3gwmqGhzJ3FgyVTJZ9MI3U5sf+a7S1AABbaRA49PzF+ohgbKZd8AdiU1qqcGI1S3Yl9e2MBqx7rae" ..
	""
local PAYLOAD_P3 =
	"0XdP9qiQrxTlzyeHQIK+MD2s4VL/VRECI7PeDPWAD0xUENWjQBIecMycGVit9/v5ueZK1RGaDNrUlLrISUwdJxYCa/ClmrUidqiP" ..
	"1hAqCAXBnSnLz6S2KejqQabQjmetBWWIrLCVYtcyod72MlFnfF1TYLzU2Nm1rVzRZoGAnHYaeNLviEqDAYe5aUgl6mvE+01bNjyS" ..
	"xsD0yBHUmdfE4hV9ZhLqH5cnjBVmrtVrCRYyCDW0tmM2Dq2m8ZNzaDU3gC1ajRc8zyde9DjFb8WkhGxcxd7bGgQar2JRpWh1FoMY" ..
	"fMHOOMa8khzXLpb664gcPdPnjt6+2/q5oFrdQpUHOzZ3BQw+8HbLjkOoxL4dD9yK5qCTj5IVne46XrZM0L7hFhx91jly+fnCwDVu" ..
	"4mPCeka1AgiwSggnadqifAkeO5m+X6rLnHWoxPcHbEwJjnRIvFKTBNClD/bxfuzkqirMO/qXXR8DSNI76/+Z0bYGjtejO1UVlc7P" ..
	"B3fTJycjLwJZhY50jnqEVGxcAr9GEIff8hTna+/O+OLInlPSxBspeEXhgjK6rlSAdQ/vXlTIJBiMTOqQd7ti3sagvhV5MXbJ6L2w" ..
	"LcFS963+L21WUCOhVQnO0lCo60kFbTBaqo1MSzmMuYdSth0qB8WaLWKevRi4tkTbyDGdKSN5P3oItVvzvFFmxB7/1fYBRvaOotIp" ..
	"05pvt1cDNxHKF1kq9TtyTv1u5b8pVcyDSS05dFLVqCW+1s6XVY8uLw0jUrw8cw1Rr9OjVnBd14mrB/5jizwubb8HBWAVGr/C0+fN" ..
	"u9/7mR8w+DrMe8PRQqc61OpOY5Dur75C2Rd7zoQuMmDA0A3jldiaaQmOT+ny1iWazGei575ZJkz67g6UxJaYLZ1QDnFsfo4dbkhZ" ..
	"jjIRa7jAMs0wrplCMkRjh6l4Kh6xHbIUgTGtLgNxcoYlcatheZdEjUFaffkQoMbOugz/q8Wcxgt9coU2oL1uIDlDzzm5/j6k0ecd" ..
	"hw2k/r7SfVqWNoJflmk56iEcgWk/25SXiYt8Q9XlgrwXn8KNGbpq0TPi7U8U5+8jTl6KdXA5Czvoibv0ALwNIueh/3/F0W5EChFU" ..
	"p9wsKeSLauu/GuB7oOtEW3SS2N5n+o82Bj1jwWL+kHXa+KChBUfPc6+quJqvXThuziNjKCGBKq310HIya0592jRTLSX1Alx/+Nr4" ..
	"noDoSNdY+GbrQKxfYi6DRB7WTzraxXnOfgTTHV8drI0qcWwtFBKoc8fF2rReW1sSH/3yIJIX6kqAZwgXuliK1c4co1orRuyzSZTM" ..
	"+w5802F5mNoM55y87pQHL+BY9VTqLgmAODVnCZEpZZuon2hVIdtzei4uSsC3vBtgCQIeywweIqw9SmyELBXkHRBrnUjASux8J5+Z" ..
	"dpj+cOfEY+If1SSjo1xtcHfy3+9jlBrPfH75hVpcpLf3oBESq8D/DXswUSvZEzKFpXT82LK+wvloMjcwprOULOsQCBkTkGA7Lwa7" ..
	"yhK8qolkur6Z2bn0Jg9B/1sMc2jQZoJGvGaAP3topvTL+8HJaa+0W/SCRHSfZR7boIh5+WDkzm1JQp66xnBva48r0kGcBiYpRKpj" ..
	"XaQo+dYqw9wZ5VZDsyjQQ1+E5u0gisgJVHNS8HgWmxmlek2Y8+smbXlG/8V+nYOEg68WtSdLq15BCAv5JHyUFt6dkpqDnn8yFvnE" ..
	"Omtt+e9HK06TdVWYGCDnmeqY/QKc1azd/fFrGoO6JN4bLWZ10bBFWigUN9Eo3miWJblXAJkYOwW9RrjJLQhikIgskZWS2/t/pUny" ..
	"YVqeuQyev9Otkm7D5UQHJQfLQzRLiDIqWfternAt2CRfZLKSeuWvPwqHtQZEnngn8IxXE77k5XbfJ4G6PF5t4rD4UY/21TipVEGL" ..
	"vFVtxyiYlldmqUL5brjKzCh+hi93CTuc/4YBWm18s5BAMUW9u0ecv8cQfFf0nCbZx7pk0VATXXwfT9vnLDK5WWgILaryfZDRDGlV" ..
	"1BMyvxZu/ZYsV2T4MHG5d8CjO5qaFtLQQU0do6oxddYchYH1uAg7gk+Liqu6hgEA0z2vPdYUUv6d/eF2AcIi18xFpZXMTCkVR1BE" ..
	"7yQlvHRjzJ3NwWfOZTmw4mlTI2N0X3F93srNxIbbY2exTiS3UrsVN4/Knm5Oj/HblDGoRzidmghI7zq07VICdGteUf0KMRbAN6KX" ..
	"L7Ec479zwwvB0QXGsnHpllqxifE4MxbX38+cdpFj1huWK7ntMOqmD9cR+738iDkO9zRxnhPgonaxuvs2/o2E0jb3uI6btWE+GbPb" ..
	"xu9jWzooW/K2Vg0OR8FB5uyOz5oh3SW0xaizdTg6Ybx+mXioyaZIjfPSuXjUbBY627HprFfyriM8HssgfKqXjoBuRLx8DOyG4Yl3" ..
	"JyajQ/3GeKJO/ZWU6/QfswvFCy49p+8FYzO0vkP0vMB95feR1Ae7ULlmim84k6gBmKXg83YtrgieL7DZLIiSbbQkRc79iS5F+XCa" ..
	"wABMRGZgAM9mqkt1JnG2tvH5BZ5mwrGy9T7wXySD++PiTVouvHqCXiGIHntXjvrgyONinVbyW6SrgyMk11fxah9WlrqR4EBpvgZy" ..
	"GhWk3Nqmb32WIe1yjLWK/POwHh9hbV9/c/SB3lyRU1OHlijzCLogOdNbyrvu/0r7CFe0unZnsb7fmCVgOioHBJ51E8Pf9vKsmkwm" ..
	"A+8ylyG1q6SMZtPS0akD3zx7+CEAsIV8bY+hscasX3CQB243pd1rlmvVPfz0+cLOLlBGprv32jyYby7NdblYzbNr+0Up/HtYf6/m" ..
	"9HrdWkRgBQ6VrUObvyjkEySsajLpHIkCxKwA1SRDomfsQZaBHZ0CjRR3fpuPMZiOEtU9Euw4HBapKhAXBxXHbozkP8vh1GgkQYR8" ..
	"gnT8r52ikTWzI1YzXHmO5Iq/Zuc1UQRUlx8EIXFbYGhm8cG2p1ydIpIe/NfPozpljrGQEi3QFKL6FopBP/5llhGVjfiOX0r4vqOf" ..
	"o8VHdqAW/R2Q2IOone2F0DufUiC2b0mji20VT7K9QXzqANx929gt/ndsIyzdIL5vhkzpweN1PPXpEexC6ukFMcK80uiPrtLGnliS" ..
	"yEOS6t0dO9ON+nGpB/zDT11Y4D/Rlk5aqiZw1fjhKQA2epJ6jx9UUo0UUjVqQ5jMXHt0GREks3ysybQ0YrEaQh1pnDgWjlxpaUbe" ..
	"vCRg7CNAxX/TeIh+ddP35zBecg4UUtTnxoPDbCMpYWwu2edbPF9DpAw6124IAlQ/A5rIOfkk9lwaOs1TjB/V76taPWntiRgeHFQz" ..
	"xIrjG4bnVQWXvT1VHHMCTognG7BrVXMmfK98Zbfd0BG+sB3t+qTo9ygwV4pPt/c+luiXa8aqiuwG+Lt+bYCRgP/l+J7xIYSKMi5T" ..
	"nX+s29LS/RajMaV6BiXPruYciBhvsmNyhNq7crBqF+BisTJcU8QwfoXIdwqWp3gmzbMFgDqm40SHpMzhnPeT/g31dU4sMnSYZc7/" ..
	"r08lYPVDtjyceWTSBJLzLd++WfXWImlIWqGnWjmSCHAGjBQffHVfC2s3AQfS0SAwuULL9towLQyTiOUrfmbFYgB1q32f+8rBTyMj" ..
	"KYi35EFuiFZOcQFaUqb28N7MDROKKzEcqwjoF7dKAtL7InttN0e7sjETYEmtDYj2d5AKj0BY145aOOaBbdaaKwUOIGKG0CcTmDUS" ..
	"E/Ye3EwzvpJiWUcAkXKLJgPUwvOXoOqvXjhLu1fpyKOflkYAuYduH1T482TIu8F+PVR/TntyKvUgyoFfGLMLBuUfhIabhyjns1fa" ..
	"PDekEOX0wss2st6OCaIKYuPTFO6BMGj8gukFnkvzX/iakargiuUJUrrIfvKFhA+2Ame6xeaUXyBonhy62nLsCKNBMfPlJGm1aQpB" ..
	"LXgGVoTMhdG5dZZIG+AY08I0CTh22pJS39UCt127Y96LZmu+rQBvTLwUlkG153mMbRPVvJs6rehRWF0R+uVyS61P4FX9IDzY8fYp" ..
	"TXsyFduaSzgnAHQbrASQSV82/glX0boMJO8828ctF9vp7jMXggUA04G9FRPIIKUuxrl/WK0NhVJVe8jFTAPUaYar0sYwZlTdTn/0" ..
	"szNUTP5ixMz4rMwh9/ZgqF7bwTUQgwr3nz9eSeruibzw0hf4hDs/kfw8bhYVNP/jgEjyuwB6pWcRQJr5KXXPI6ehAdVoN7DUiLw6" ..
	"9Bg9f7/PAO/WRdHAlQyXp5S2TAQqvC61TnsauD3r3rmTqV0cRFSPDEr2aE4bsk4EB90UXLvzN7fDCIctcb2TchjPACwSEjAJOGrm" ..
	"+47QUsxTozzH3Ypc9aEe7pe1lgdpqTMkQAV3eHIixVucKrKawGJxxyUC4dfudNvG49zUy/lCBFDrIDBA5h79Gp3+WQH+jhBrnZwN" ..
	"GvHbsHehbHVeTz2/xgMbVZjC+djhz5tjbycZ2uD1BBDWuyu8FZ0fquBD4jyFLiubpjqdd34rbR0+ArsVkHrNT+lCP/1Rac1q6p9+" ..
	"c8mFhAD2HBvpzYW1rrgyCNpcq8Y58KayKEk/3CtMHkEE8zS62uIW73AjYbTt3PxiB2vBzNHEnR7OkMQVYYc1dvr8z/UYyDCkylJj" ..
	"Kut5pdp5msLhdl4nmFoewX3OzXBoUNzR74+cZeWKBZNuiwPPX+HgSmXM2xEuckOzEJRvlj0YOTKLyTIP/Onha9RFLBI+ISiGLUqb" ..
	"QZ0trcU+QeBcMeOLdJSmEw863It0xCMH7QEupPN14fA+dts59E+FVZ2WsVjNrXnndDm6TTJpPejkBZnkzDkuD3jgmuAC9IiHlnVW" ..
	"XvaF3od+Ckz1wsBg8QQG5EMCpalEXlEc8Hh38n/RuudRkefDyiEsLcybjo/4Lp8XSAlk9f6xWTSX0gTMXYtM8t+EOnkNFj4e8xjR" ..
	"foHFYIajHSYH7ly8jJh8hJ1URivCiz6M3a2+7l/cpYV782GvhwWLxv2wDdc1sDzWY6kUGOeIDtN6KrCDf9xymZoQ4MYJM12s22UH" ..
	"rNyrzg57qE+RswIERKKev5wz8fDk0GaHYWKQbiHRyMSTpoYK2PRRFqLT0ycEojNzvpT4T549bcD8spkLIxMMI+XCYGqDevnnvZY+" ..
	"3TPKADVbcK0eX4L0I5jVUABQ1nP8spkyyLY1b1ckSlDEFY7TxyhjIvgKhXXTZ5RNwjaTF0qRfH2RV/f+D6tnVkZ1QK+o9Zjil8yd" ..
	"dHbqu+8DsBPGT/0GCnzRjfBQGBNp/59/ZGf/UBcNfzA2+obmX9I/EhNDDOnQhHXCYxCB1z03ga0lJgYNg6ilfsfihpnqgNzEDQch" ..
	"nXtQ1yr1qg4zKfEsOahnSjXCzroRnm3FIOwV6ahBcMdqCyGWk3GKi6QjCS4+7jGrX3sN61bS6LG90Ec36b7xazb5k6gq9nOQJA9c" ..
	"IC+sSnHKB9qw1Xhgs/M+Z7SjA3p5tgjmoMX0Am3vl6b4n1caxqhjmDdMVcYG3MC9s5BJhA144817JD0I3VxU4OpCec/fBzby2PNU" ..
	"rzdOZEWxL2rcaptCmfAejqrl4lluVxUWrdnMgMBDhVYnZ7YL5XM0l1D3o9jl1A7OxWK5tSNsVkoLtRUPydGVSAQNf5EaiKiv0WOD" ..
	"knN2jiiw7JWpVhZYD7duMZmnJwr++Yb1Uj2k3ueYKI3n/5Axd71sUk/8hf20Cm2pG8BIJWxJhwCYiQUV/MPGrx5ba9Ro2VVwj0+H" ..
	"tS9xXo1IarN0bhOSoifvdkvvzvJbJUYFYMDwn6ocXbvj65TfAtk+uTlnt9L+6uNQXYKMj583XZ0ri4VPTzliEmsuNEIhXdYHwNW/" ..
	"wuMWrCbYRmsD/zhkg7omBtcNqjpKH5SFmcj1T7yeksqBMez4ejfA/D8c28W2p9IC2+wDqDTmAZRVltX7HV/pdX2Ty/EVd6urBnku" ..
	"m25ZpfhBCM8c2EM95PmgqRIdHm+msKtbvxum7VIH0fo83vJZMg2BqVBVFQLI/1xvZYJpKKTIhN/YkSuXIHw4/le9XzqkEwvUifx5" ..
	""
local PAYLOAD_P4 =
	"DOzzKSW+I73KJRtpSE1hN4snzdRd6dHU6Ub1ZGiPwYy7vIepI1R/NsdvJv1g2vkI6hC+XdMbBcWRHKsst1dU33hyev9icnrCrag0" ..
	"vofEQUGWK0CzNDQ1uBdnjRMFB7D/W6CBMLA/vxveXWZ84VsUeXUX7VhQEadkWjzl/dCQfK41isPDvUIKcEb2HD7iazmFCqDFNNxN" ..
	"1Jac8dgjP0rDXZrd/81tXapTnJT4Q2a8IJws/AuOm2wcD4jg64ayFaPPqZDH5/CuiRU+sxQBTqPQQhypQWqedIACBNM8IngEE3oh" ..
	"3wS4Ht6EwH2y7v3cnGtX1Q+ymBK3OHlxM70bwmxWoMeoIpnielAgfxyt5eRL8+7A0c9gPBX2DVT3z+zeNEWr7RoOzMT2q6JjRGuv" ..
	"B/Ij3Ql/rntCZi9xaGNgME5AS4vmRbTSnd+ISDMREufwfqdGDIMLblvoZ8vjqvqH3GiCHJrGwRMXZNF3iA7psMhUNSPzsQKvCwiR" ..
	"frc5N3iBTdLZHFE8gSZIt70msIaDxDybGOkvrfLphfqqly7tyPDoHoOpWAE906RiK8Zy8rAjpeo3Qo+K2jKYNTS9hSTizN+ZJysR" ..
	"kzEdPD8vv14kCvlLC/PJYdnBr0p+3JYR9x9r6Qb9L/Nej2aaUv1oGtNgc+IL3+qTQGk7uCBqywhpwXjck7X6V/0mQzFzNbzg/9lN" ..
	"NjTzVUPfEhIE/kys0Zp0IDHf1WFGXyr4xA8dRXmVsG2cylQ0CBmTNO0YwcZ7ZmWiDjOgq80k86hH4UWTmPNuQDfFd0sIeThp7ixx" ..
	"kziZtuTwkvm01GFXFuTQ6QKl3RNvbEkdTr+C72O6Xkad0cI2KnHX87EpoZQqwYSM7rQQWUCiFkVrKO+BXsyboXdxNw2t+8QNfbRR" ..
	"UnwMmuW0cnzAwRAQMf4ZKgNgya0KXH3Zy4WlHERsiLPnGe3s8zhKXkdHmeT1HoFSBYXrT8dSX5jqhWtu2Raupq+QwJBmRYXo1f9U" ..
	"SQR1llF5uIiPtTef5TE7racy+c6eNwjAjARv/mEL4b8zUX+SR6PMMo7nQ1yaUl0hnfBTLg4DO0L7gXo+ptdt3OiT4LByunV4xhk5" ..
	"SaOPgRiRCdJdrmQ/viunG+YlOHZOBizD4xbRpFq4hqo7spD9A+yhor7+BkL8hZk5g+vLcdWL3pRZka/CClG0gaPiOfQuyAYBNkqx" ..
	"r/nZvsVGlyymG/SCM26lQ+LVPE95TUO3zxkBhgMukuQ+sjoIFHlkwbRyWEJdeXzSdeRopEFV+wR6mnv3JjeBePiXVxz4yZ8P/NZw" ..
	"NWkSQKB50EzgIEnOp3da1F9Pnd1KOCWEJUPIrQalh9oqdusPBc6jKcOXaFoW/KuCGk4eZOwO9SCIEshJDOvwKA7x9ZzUEJlEMSgw" ..
	"pc1/Od5piHN3qwgcn0PYVSw/paZBePT2ErUaAESvebm2BUxPOf9lix+eU0vONAd1DNuDTTifNu4D9CRNxTqQIZH2dtXZajNzwQTY" ..
	"d4xHwVR0opfShtih2nedrMkv+T9t67SKFDnFge6+zeVudB+6psbA3RTxkVUboVgUpJSExNTMIjZ2WVIqIjFqasni2gJL6aMJ5E6M" ..
	"13aTMUxG1ZQJhDgwN97rWtdFEdZ50Fy4BLHFn1V7TMNCFZ//nrAJxJMg8Nh6xskZ+oexrw+tuL0H4CFqKhSNhOnY+E7MheJHNNo2" ..
	"VQQBXAOSP1jnBMm+sU/OczumI0Uo1d+N73ThNZaYQ1aKuDKHDaOaNZAbsjsqR88nZuTcFdJQcM+r3weZFTFt/NGuu/VYBwuZ2Y+4" ..
	"prl4QRlVVGE3Ea84Rr7irgz/lWBtcgKI64ChFbGAi0ZzH4hR/1u1RgH5AhuQG7vkHwQFSflAThdyTtSXTYtq/O1WRJrz+9oWxmhY" ..
	"T1nFHlkUjByZaIvwnoooJqbCfHG473lC3cUKoZkRZXuLoSgDqVl32Fx12H/+pRxe/xu1L1SNG0GwH1q97Cesd4WqlOAi8QZi1Kgk" ..
	"TCfu0Ud3Hf+yz8fj3fEGzCvpMUTup9mExEFhi713RdetQ2L9M5fFzxUyaKsr6VOsyNUirQPyeLPOpiqow4oHnPjb3dLMIBiZbLtM" ..
	"YL9t342Wh/M+BNgRuA+cxBM2BH4TMbnJHUf5AjCzcKHJa0sv2Ep3/4fObcBvx23NQ2Lxyp0E1lP/aDpf1W4cXmhU+6kfudiCjJ/U" ..
	"jYePdQg4RTCeUD5viw/9BTk7Mywy8KOpdIPOVaedH/mkpu9MFPPfuR4LehOzHyiUL+Tfq1/o8k03sy+FwyN4wbTm2ev+L04Ksiqt" ..
	"3olwD+zxJR7szGHywnOcBkH6MLLUVnHJomxC55P/oUkgdi965TYqOdwjM7MqSf2uhrs/fZr4oiVPg9zEJz9dYaC8siYX5SxQfc0m" ..
	"EbViZzzTsi2LlYMpflBKx2TE0JJDfVmPl5W+dy+e8CqwcJ5IO99dm+gGY0jZKl4ZAJ9ZNUURrlGCEsaBsVXsXZ69J1mVbGemXQak" ..
	"wloKdRWdSd1C9CmZBXNZyx7/b4oBQSe+WU4NeP76LArm+A+6ISIOfFzW47zTTXrIYG3Fi9zPZ/D9mCrcARMkuP3Y7wqePwcC9g9P" ..
	"0tlhZ66fqgs4rjcszVcy12+CjJ3gWnqlIkEs5YcKP6U7uTJoLToVMQ0waW/qvfBFbbCL7a76QyyTdJL3YluV4UTWWAzBmECnSPGG" ..
	"0W1aQcixoOjnxLG0S6ZxO9xmiRuNnk7qpsl3hTJHfKtCGmwkSCm92kfvOGVGvbFSsMy60knul+f7+uCdLqNGzY17f5p3+u30SMjp" ..
	"fK11R9w3bEz009MjWSS+PJWb239Fm2qy0GJYu6A18yDli4sIXIAx+R+fdWwJBzpn0O7O+ie5eVakRy9pua0op2Q9iMxi23rVubsv" ..
	"GBUkieD65aVKhpgJbNHS5QSG4p1os3h12xMpM+WuB31Ded4R2WFBiy1GivLyM3kuIsc7x90s0gTGoVmQrQHezuK5fJYRG6ZD40Yq" ..
	"fXgHJdU3nz5zfZYMpneqTPGnXb2lnLRbUtRwPXbmLpFs7qCTQ7/+RAJR12cREXShsjl8OeiaLu+v7g/0qL+GICKuevteNqucAudc" ..
	"rI4gz0CAjShKMqJnV4GbvQk6N1NAy0XzGQf0t5TOJ9A/S1RaK+uhVYGx8AP4bJKCBrz6XAIXW31Xukt5GdwqBE+saFqP1RaA1XfU" ..
	"+g6z0kkV7Lg+GlIa+rWHCZpdveEr9z1nYf8GG+H1dnEQ2FZ0tK1ATGGCvo3WcQAt9nUlK/4lDg34MqEZ7lbMxx9/0X7KuCgnDctF" ..
	"WT43CCtHz/IdyayKAIc0FWJXJCixpinf8fMLuo5IiVlkDR//B77nlkV6O7rOKXRHNRYChpFrL9NEHL9b+HJknb3XB34ib7zFhJ3B" ..
	"UcigMQczwgEKIPt8vOAxDaQetxsN8wJ6a5gADr7w2TKd34GSy4J/md9RLo+PPj1PFMCtW3QDIyyQMZCiy2ZFX/itPo6OFVPfmN3V" ..
	"zH4hB8rxg2+smOKmsz4s5+dmxVnf8omyrkNUaAb+d06WnMxxrWT6SDc1MAkMNBB0srg2P3rpYAOyzIjL/HGwCTGYENF9qT/3iJ4x" ..
	"h61a8JQtWSQRQeAcuakjYgyggRngSmRjJNiF+SOMJz5rZBnZv8WQX/AkebrMGo6mFCUAjtOkal+korTVI+kD0QQEgNbYcZmWAIw4" ..
	"XTd4LvjzA2gbS8YTvjx2EdSJ8jpeLmkABJalhbUgUD9+6X3lDqB7j/NS1Cm67/03+x1iEcf69l7IjX+PTGdketCkpEgJ/sjl1XGF" ..
	"j+4fMEH5ORo45wT0LC3JbjuQQRYEaoCZzY0F6Xl5T84MYKqCN5q6IdhVzxdDc0WJuoaNdZWHyLz+DF1gc1ry0HZWJ0tC5cDGTJfy" ..
	"7CspF/YJNu6plXS0eW67JecBIb2lX4tDGZ1zuzXYp2yPrGXMBQflx2oUNAvrPybTd5Bc1sjTSwL+/V59YjJ5/OY5EEprLJ0VZE9J" ..
	"nEO9ikp0A7n2HRliskmZUGqTCbbM9hqnY9Gil5MMKONrRMY1AhvTE2d0kRWN3gR78TtajVkzhEVHCKjGw7w+cJb4Tgo7pnpQmVhP" ..
	"+AHkG+SfBHNISdp/ckM6N6IRHI9xfC0h+tzwjmvMSZX9ZxxeRVlurR0J9c//pvWGa5xMAcBjXKKGGKiMDttUAOOSIwOqxcOAeUKt" ..
	"wElF5R3nZj8tCrYHxEkSP7DttSdMI/VBwpfkLIEtGtImGP7IAFv0EuJw3tS7FndeQFbhrFmicSV9QHZhuke9yxJAx2+s2xoydBaG" ..
	"kaBEgfhfwmuON+RCOKXRPZ7x6ad/gVUW1js0HwOjIXL8JvcB4FzNLYFQN27+DYjqkkgC5YNGZfSzb5kFAeMXMrcYX0kIF9YbCkwB" ..
	"Tytap3WuRbdJeP5FNFizlW9av1HvsakuQ/GwOlAHlyfOx4WHjSKy1Qpi99EJtHoGsi2ZJlWH0RugQYnW2aBv2AiGhN/CWpqoxm+I" ..
	"r7vWNNWsRh/JiX82bDt27zfWkIYQVc4ngx9W8awn7XNOxZ3Z2V3zVq7CvrF4szeAHJP/2OxDsdYUxWyM/gCyNZqzfMFJWguW8fIi" ..
	"0qNRIZjIDS5ztn0KBiyK8hJDp+bofo9tMdoFizh8io+ke8Ek0npp6VSAi+TVpu66EjCD0zEk86y69N57CPFH+TlWt3fJfFxeOeBt" ..
	"sd6Lz4ytuaJ0chj2qfmVu9O+d/tfnj5i9NDYzzEUNJFYVCnsRo8CMqfRO0w5TV3NwsfSOcUIi1ZFbq3MhsbuQ0sHgHWQoMwoIaa+" ..
	"WrsqkwlxKYHMymOKvvNPbQ6+k7axNiz2qIr8QTb2IeDE4CYbiDqjr8HVU6dN4Pmt6l9w4eo0UlFRwcIZxZmjXSpMX/gpBIDh9vwR" ..
	"xgztgNkEU24FfutrWNXStWxUZHHLXv8qHFyWfJKzEX7EsUcZjGJoB+Zt9TXfVwbTFXtTRSlEX6X08MVFo3G8NJMdGsu4WGsEfOCX" ..
	"83q/LhQG7zne//T82xkEICqvlbtBHeitssuJhlz8jcUiKe3JtP79+Dwke8DlLdkcFvAJxtsRHRgX67pQ5IIDL7Hl7x/x0/EpI/kf" ..
	"CpXArrPCp7JXz8kaW/XmgTRJMqeMgjOZiysHE2kDJ8uqoq4q+253E2pjOPgWC63UTHSJhmJL0uGMIAd03Bam7weVizgOieC+3YBO" ..
	"3u8LaJx8UZuFfYx/nFMY2kawjEP2anFN3BbpezaqzS/SOOOlccPB1l97XPSHM72EbunTXAfKu6GvBF6n8Vbio371EzbS6iskZMFD" ..
	"sqB9V8EMAXaV3Y3KgvnSOia5Q35fmSw7hYN4/KMBrkiNpgaZHjSSYUqOGgBtO+YmQwMMfaITBpPHaHMuds6GIbcwb98HC0Td2c+f" ..
	"M/R7IPxojS9/DhJV5nlHZ2eCt+I3JoTv/zzCmXyRND9OQ1cGQrcVGAsWELHK2BpHf34mIsGgwcQ/klichfYfw3Xqr52IDA5/ZE6t" ..
	"YVm8OHuN0ViYENTKt8TmClUqb/HFonDdQL2gEBlijouyb5kEDizoIMi62rNcYz9dXXtt5SB5zITod513jnpHmA6FEnSaHQIt4NTv" ..
	"BdzZE/J8EPCNmGr7i2CNXM118kMKzb7GbEOadGgFLIBOCuhnguN0wMo9Nsr5Y4HKYaGEFVPHwMZRuR9yVGUoIafcwFqLbmKaAxJ6" ..
	"BmzTj+05MpJnYNPQHw+OZ6tD1TZ+astytSc7iv1qsxjZGevVYmEZK3aKsOL+es3rku+VC8/X6IdB2saMbjoy8GDhT+8Sm2tdjiOU" ..
	"aaRbURjrN/N6louf96a4Bdi+ZuIU4Y9fM6lPpZAPIPDI6kGHSRVaEya8k1sFICxULidLV2247JeDgqomDvsVjOsw6H5VgcHIysaE" ..
	"zb0I9/HZy8AMLDIhaK+dGRgSokXa4LudwRbph2Ct4VYkJlnIjpmu5SnAD29pTp5B2zgzAE03kZCrMX74hb8y3bn37+gOrnNfGkMl" ..
	""
local PAYLOAD_P5 =
	"fLy/1zzhMCC6vasS8hSJ3jczKmYqAyJfT3BooyOUY+3XKqgm0SAYFjriFVzpCEPtJDCWONYu/pkPv5+RdMJ6ElyBkLMHRoNcTGOy" ..
	"+MfDnUWhnH5EANxxPv6Buy3cn1L+iwa0X2Th9gc0vtbCDWV7w9NqjGyf1mYtkjxNcDaIkxen/oQuVFlNREzttkQR4iJaYQcGnAeJ" ..
	"GRF9WIuK2kJv0mRD1zfbhuHRxYSOIRe0mEh5OMCkxEscxvTKPcV3lMs+KcH7iB38bpEYwdpxgSacHV4xqXrxFjEj1xg+bBa5HiMz" ..
	"iRIw/gziAXkCsSJjlHR/KTmuzKzHFPO4G4pteoAuYNQOHLUa9XVPv9BNOMeryss8pd6upCSppy5LhtOKlQsSDqZADu6ADe7UJ0PG" ..
	"LE41RWigatV5Ha65qYrlpWPLS2wzewZuFEeRfxajrainp1t9C2vk6QARLPGpvumJ/vg18ymCp/Ozb6ExbDFfU6vZxjgwieS2+wGR" ..
	"JPobr3vl3TfZOq3Q31ZS4fgf2PUiDtIz4PcvVHcB9Xs6iLXnXXW0FMV3Hp1cntM1zarCenN6s85USfNdIaLwcyR6+tlj7IRGxd2K" ..
	"0S95qjpW63hWQnd4cqf1fJUhFEAdL5VGbpqhB/76umKYZBUngBK3Syt4xTZQ2V9iz3CSK5kNOj1yj22l4A7nLj8qVzudTfs0bUv5" ..
	"8HzE/3p4dCbNwxdmJiuOSNWRTtVlFoseLDs+3zmfznr8F4Qhw+s+8M4IVWl7EgbE0YcIIoWzJNDbAP3rh+0MJ4iVGnnKTisJPXV/" ..
	"MQdQUavIqEQ+HpJl2mZ8/toMWFdpfX44rcUO7Wt+L3VjucI/Qed/bWH1uJfapEg72XdKVMmzAYauS3fwB6fCWKv/b3yO4AbHvw4r" ..
	"ve2lxMvLJ6D/oCf91c5H8B4+mpU5ZDDabMn9WC4ZipqfmZijcjy9XGsCeSPP9VsVA/ma/BuoXKRz773Mp+B87hNQMzeXoZhvmASB" ..
	"Nx8SNS6mT3aK4j0J5VvYRDJciKe5nakFCvlX3oKnJ+QxMalYV0vQ/FcKL2g8Q8d6P5d12olcEsliMGjm6yHiPrSa8QXSlkLlSx3G" ..
	"qGev3LGT0kjqvdpGdiBe0E4uX8LGZkQySJ18fLV4QAYr4zHpmZZlhSk6kI1Tilz/rXUngJMZR4RNJ97ZzAzyQQPnh5a9Fj7I0jQF" ..
	"1nfGRjUcrd/tPD2spNvZ8U25MpSXten6LzeMRYKKAyNBafphgun1MGGJyQhUvRutb/uedfmwbgUhpQvNt9uYxOWVWMB0qyi4seKR" ..
	"4IL+5/BIKQUaqgpH8c7L07gZ6bBa9a8sHL0Hn5VNY9Lf5xjdJdo3IU8fAmjAQzZ1iKiM2ZqD7Ro753JfvWIeyWkXIJ6wLZN5HU+4" ..
	"zWYSauEFglTawOVdrZN6xMun5EhKYOQDSUBQdtZoijxOin6t57K1dDjoGpxj/piKio84oEyqOgo3nk7BEpyQcI7pnAWc1bq79M9X" ..
	"JXHLpgDzb+efvmHuHx8QkpaMvMcpo7hpHP8gYbv01lpP9VpVmNC2H1BMYF7t/sh3gWjnMTuWZX6TgkvS0yGojbjO3hqfdqOB4cZ2" ..
	"CtBZyWgxD49wh0daoIcjD9euJcalbkdXP0ohKAvnqaco8yTKSn8E5HfvhqjG5K8VypiSmbXL9qtZ5iWJhpHGduODJ6RPp3u1bDCX" ..
	"ng8ufiNal6C7GO+5qVoXheoQPwgW0+A2aGERFcqtS7usj1w6P8Av037E/HRaDeUscjyQQe9snsDbl588eCe6MErJCsOdsJ7o2k50" ..
	"Lk6EqfjXJCDVgJoesT6zEnCK7NykwK/9/colGAQ2U6vmgf3iX7KFXQ0OdkGlHhdy+QHadpzGqaZYepC00t/h+NJTR7JdnoUsar1W" ..
	"3fdypboj2gCBrzhcT7hMaLMfFfYASsY3FDJeSDWmgShUGmiuXl7lhJCBOzsLEhiACyeeORRMfgEpbGstjPgRHwSPq5zZTXIejs0r" ..
	"OLOQpH4FnlfS6nsBSyGpl/ZK3e8hwL+QuzpMrLM0Y9aN9oFhVNez5Nkgx3K6gkvBrpc4SeJvrD2yKjNwCYEN4XHeWTej0G147qC4" ..
	"UsvQ8ohvHhImixK3OFcFMkjXdw4IasK1aRN546ZTvUIxP5SuwYxAt4aKnHJCtyM3IlLwBzRgM46avDHwuj3TVhW/pteZTTou8bFA" ..
	"jkYx0zcfJmV7KhytN/m3lI8HsnlJHCxwDzBXTOX2ykl6gA1bQhfU+8eOECkjVUpNzbVaya3qRGK8Pzru2giOrRJaFvjXqu9HDuXq" ..
	"0giwD7okQ2uE4ROvrc4ciUUQAcv9rcHPJN5wSCiqDuxIqzptynccTuZZbrTh3rPwnN9CzION88gbnS76c/KoMjajzlD64647UY8w" ..
	"TWDlxGjVLNKk8fwK4pdFCYs3GngEHbHwYfMHo7KRPLx9VcqjsZG0BfmxxCUANd+4+ADyfnnYHGAkzz4hwAiFiawo8EkNyEL/9w6A" ..
	"WmzdvL768Z84QOgMeDkFkqbppd8MYQGcrkzcaMOq4k/gPq/IaOKO2bwVt0aSoQ/WwB/s41sUtBGqXe3q0utWZ+nCwOcz1GddLreW" ..
	"I9lDHqZbnu7TaSePdJfPSA0EOIRAEHUCjmOoGpn98+XEnIjhF4zzwZOfbddDWi/1H/rGQb52kYiS1MSSI6u35Cz62lEcyUgPVKPP" ..
	"uOxn69qMBI+czsIykOjyTnD9cpIgiz3qN88xpkXD6cMwgvF6FpcIGBY7ZUEUd3wDBgttkbu8761cDfHKjnNMB8oGLiCqf0xOMBAN" ..
	"/J/dbND7zj04Td3aDeJXqZtH35mo86TZHTWcIaKMnM3B0OxyB5SvHS9ZaXD88MO/qn7/U6rDXPd/M7OfIQm2XgZPd2OqKJUKzpnM" ..
	"rDD6TzHgQl2Ot7kcMtnXCdvauoueWwrqR4jTGKPfXSfVucD0MaUq+SoFEsH7PZfHNvIoirFCcz8Bd+QJ4czqtFubxWPlSgWe+bSK" ..
	"Hiki81Pgr8v34jPGXZ5XJ0V2qdw5HFCkQxPMJybM53J+pEBKZrmrj0F0uGfRN9GV6UzNtutXmAJ0QSZi6fykeGquGDwP21luEYcP" ..
	"PLfhkz+1h5IEXAFPFbTAexwQFzhEFI8/1Fk2p0/zyf9JxHJwSpOdoTE6x9fHT91sJDfnLnDLIZtdMQRKmZ2frFCf1NPx6B3iDNuP" ..
	"xrKsFbmzSgklB/McxQbJXjpOAL01jiWHkiAnmNItWVNtCn5Gc/bvawEewrz/wfJJ/rJYYHNuDlssnhoDMRxUtZU4lVmQSZq4nQk/" ..
	"7MY+W6LxBzhVK1+QoUaPzn90vP7hrVQ+sjmIL8c7qvL5PyqdqJVrftMTgtLRlVbpik0pmOJbujdaVBV0gcC14woRPT6M2/xUWyTl" ..
	"T0QMeBQDEJj7Kx0lG8YfbU/r1VsJrdr7GP+mLUV1ONyvGfWwMw8RXxnWTu3N/fBF86DJC3zbCKVL03+5SbbLV06dKsPNSMWwRQCs" ..
	"wv1Eu2c2rN2VMlIZIrQfLVc2aZsO++KnmJkbtjkJniYBkN2tpYlJsPYht1E3jSmXBeO3UY9SI01LWTdhXHS7f1J5AiQaZVpLFZYC" ..
	"ingW3RSb0pskKAIGdu8IkckK+jhJCV+wJlEvtmW0LDgsRELPow4faI6kptmeOvZBssIBXHxWy+gRzwikypddM+jrAniBwk7az9gd" ..
	"eIi/C0wn4lbejt7C8NuXkVA1/iRaVUmRBVhwz+zUnFT2GSUfeKD3zQ5s2J4ayoFHXjE4OCaei6QnmkohDimrn1ITUekofinqJFgo" ..
	"RthrMbeWoBQ8LjyIaJRW3PydjkenYVeasBe61fs1D1nS+KCGxy+vW9yfGSG3DdjOih9tC4k8Ui2vM1xUvwd1DDRWYqMIts80apjd" ..
	"eDNHi67txaBw2PbnpFOTv9KB2l6I4N8XuHUE9l1djB1PzNtNiBo2XnSHqbBNehx/SCNRJfRMTxy350rWZWqIFHauBaHL35Z0YNhx" ..
	"n0OQuBKSXiOOVr2PgJDia3CFClvgDOqDMXgS76WvvcseSXuKIuVoTnoQ8cTNSCBMLJ6xFldxvX9C2upNyRQyZXBu+di/WKUE8uoZ" ..
	"XYKT/+8acyBXNDtEQKH3HST+5YdFeOz/szFhYbh/HPJEAjrTrNDLm81qjvU8YqWzMxGlzGqjEVh489I4EM/GASduE1bh/0tq6mNi" ..
	"uvdZDFxvhN8AtUZb68732SRVZelPiZ1fzRWuWVlo6drxymXSSoyycBo2iFnuAbBtoqdhkgopWXw+yeDRK6gFdFnWjqOmJkrctKDV" ..
	"SkG6RtP3Dkw4+EVIyoaeVUq7Ak0ntfBsJAQhqStflbgrSwuZDqS2H1bp0sSktKTDnM5jBG3nJDSQNot1CFd3CnhacCAbuRb/3kmi" ..
	"n96XzMpJg4j1CBWX+gu3rY71QO7xmig35OpNB9/npbRG+XxhyQ+tI1PbGAFUvmTsPEhjVh76YrJRsoGQxNB3XiGQIbSFgus4fLsY" ..
	"Y5Y6gmDDXjgxBDpqB2uFw5ZUS9yvwDbDuA87+UA/c4GkKtzbYDpSG6MThNAs6bA0ba5GmwebAPg5sn8gAl3qcOb1tgldj5Wd0U4E" ..
	"8E0A3qGAAoVbovtcP5wCmXpdRvQh24F4LIQKJunv/5L6Q/cKi37SZCLujwLVPuqnd4HgSBQ/IF/Qfb4tXId1T8PLLMF37qB1UF74" ..
	"V3dcojGwMMmEwuAaxBEzSnlEfsItr/vjs9PMKkwkzme4w+mR97t/I86ss1c9JupCVPF9rj2EChjHt06ZniPLtHxC0Is28hz6rliD" ..
	"NA7sYwVjJIWLvxHL48X5M6JeNHBIF9azvj31SP6bRkAx6jZ84xCiVMLDh7698nGIwZqDb/vxHMGIkjf9JD8SKxY2ICWFhptGzKiu" ..
	"pX9DP8RtSw5zqQqMeaUS8bptWddNfDEGYD9nLVZZG0oEu53Slwu9Zz5yD/rafri6hml88MClVb05AJgH3JjxTkot4t1Yc5oM7HyB" ..
	"MO9jozcmlR++jz/fRlKVsoOnRzC30TV2swAvC5U49CyW/zVteWu4QA7GNUURC89Sy89HzeI5XLrCirdJWV0998hxz/ABjnBAw1KQ" ..
	"HZBmqFU+cgHQCeRlOJ3ZaJFUonWqeK8AJKvmwFmqyZCMWF5FiY4xKPaq3sWaAZ5c4OPmopUhR3yFqLzoA7Qh4rrbCM7/dp+q2Fr2" ..
	"C5yhRte7fK07M+/BkdIA3FReiS9Cu8FNcWc2pOKyQfTRhOt4Z0U1WrXLyZj5ez0gpRsN7M50v9lOxz3gvVWsqgczNAxvuNTzJPY/" ..
	"KUBgLMJjMz8Ay+lDY1vucZm/cp2oiD8IzC/TKb3GxocslrSwjfVxufFnOMocAVYxY6F3WRZg2ljMymkZ0CpmW8mx0nVsqAmQ4Efi" ..
	"p27PLiX4O6qYOf2N0BiuAnq4p5lIOnxEAlNh1tk81/aKBYOgwDADlMMfZ1F4mHrMnmBBWitF6mPBmKi3z+M8VDMravuxYKK5j2B8" ..
	"aNlAgc6FPkMpUlKpQl+XfUJpgonO7X60sLr0FiLqvVc/HLkGrsdVAoeynb8dWTZG8+8Qplelj7X1Kck2rcnBSMlt8lts5Ijg6TpG" ..
	"qEcREvD9VzK6UpkbmIWvR4xsWnrAIGU1wPO6941p+nvpbAVPMubg6K8fnSge3vR2vUUW+jjNGYD895rlV7irdkndV0BU4J1Y2OZ3" ..
	"AOFa8ICMaqG1nxMswuOnG+2zZuJq/OnCqWJ4Vg9kz2LMZ+1qA8bYPJQFWeuNKu+jrv3lv+aX/ngsfQRpxTajflxGzT/Iv+eU6D5q" ..
	"PdidpSQE4rJQrsRAcJcEEo3H+N6tzKQLKugZSPDlIzqAvKHTDH6DaQi6yDE9DRVpNzSCJkp+cxCDON00ubFGXdP+eixetQXpYaW8" ..
	"vmzgAFYYhCkt8YNVBdREmBtcp9Y9wKA9k3vDCpuU9SCDUiHq7mDGAmIkTsUIBzA8ZvQYSH2xXQ4u5QnO7+Wm5hrFxrqfQWlF7lM3" ..
	""
local PAYLOAD_P6 =
	"gQYDZs+hmTUAYknO2IfHeJ1hXrFcVgHTgOjEs+4Q5MlBcSOBOkCU5xMBLkLVYOTXpICnpW/Av5a2qs/i7CVXUNCJHVXW7oLoAdRs" ..
	"iakbm3pcgrgAtADWxKTWRgOZG/i/7tioZzMDbsQDc/sMcpZBqhDQsKeNw7yWZmziFV/X4lDY4YVXk5vb5+F4OlG6yUxNU1+CIlNE" ..
	"zuhsp4tXmCtUJ5tsdzs02b9XbxwYRmschojs1W0X4vGWSfwjH4YS/rK4yc7v4PeeNJDKihpK4oZLO573aFR+EalatgAqx426pmCw" ..
	"O9J2Rc2grXk6W62u4TT40a9Pi85psyS/yrqeAZFADhZT2bLyOCgbFvkhLQWQNCxW3XJkbg+iA9+5NiL5wtxxc6XHhNbuGY/J+ID/" ..
	"x3/Z2VH7VXb3Cn95ZRheQk25Udx2liQpzIe4k28iKAHqB2a2wrgO+xF5ZiEq95BLJz6+xI/fdtQMIrYPqXumRNkCc6dnpRdEiPtf" ..
	"IKsVafIoJsdN2C5nJ9GWWLhW0yj4QJiKgz9UWPlOXOMh8T47HchyPDoK4u4ESkaKkMuSX6ajkp1oXk+oRKPBleHufZpNaInAI8uw" ..
	"D5KgthlMVDI+gsTEWHMGNbEy82rmv8KcRjiAtfNy0yx78Jvn7KTSObXq1LUiKkZyB5Py9xaqfb1uIMvcSZm5w2btkk07zvfIYt0O" ..
	"DB8uysyXjHBd+mFviIp3PlknbdByHfbYyQSIzoim65w35iceA0MCYxV/n0D48xWuKYuw/eyePbXhquG8caLlX+JKZIFnavAHQUjY" ..
	"ziDZ/4aMAQHK7kZjalHwmGps+uK3Du8YIGoy0QoMdcywq7evf4/bBEcBg4vQtKTLbUDenuNWtDxX3r2q0rzOpcKE55UWTOtJwcQu" ..
	"mahH9aWpRGrdUg==" ..
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
