--[[ DQFarm Loader ]]
-- Licensed to: GNURT (1 thiet bi), Gnurt (nhieu)
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

local DQ_ENV = (type(getgenv) == "function" and getgenv()) or _G
DQ_ENV.DQ_LOADER = true

local KEYS = {
	{ seed = 1982982441, exp = 0, plan = 1, hwid = {} },
	{ seed = 1984530751, exp = 0, plan = 0, hwid = {} }
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
	"sea1/yLc5agmrDPD7Q4p+WZ5VatxoWr9JBqExjO7rq+/TOulyutYayMPNNTMqPUZE38W20a8QTljHpDhwdGynQ97VsBy+VuN1sJV" ..
	"G4k91x5oSGHg5KN56l+bQFCkZCMO/V+BJjRul2jr0Z4s2FpUvCJxKKVMTx20UtDQMTjUKDhcAO2jCld/su+G6xBG9MWZ/Vo/RkhI" ..
	"YYxNn9sJF0T+NO/i9QCjqEj9fOSVn4d4zT7cF9ASrg7Oe1RLFDgHXHsiAcwazZkBv8Cr6IEXe9EVNcScfH9FG7ncwR67GQCGJ4wv" ..
	"3LTQGMP77weC5fGb3BXZrTyDk4mD5L+vYAj8kCyMWGKt0yi3T1SYf83/r+DUdamFvU0q375VNdAbHjxkNEGd4w4+p8TRuhh3/FKq" ..
	"Fa0cJ9LG7X4bfVFK62Qb/+axfpcz/svXazn67h70rOyJX6BcMb+m/Iatk2Ql88OIkpaZgQqjGd1RtwqrQjkXxd9cF5+PWlGZXhIb" ..
	"QYOuwP5FaFiHGw4WH2tO1da4haXoKOsA/oVdHAE7SUAQNq8hjBRtVCEoGwASO9lewSa4LOSr4sIVi8afAMW07/e7aFy06Yb6ni4N" ..
	"qbXHwTduLBeaeyQpx9cH0jEs43wnep0JkLuJyiWJZ+KXULvf4FhTD3dV/oPncZPHSjxezVUii5NsprMQugw76wYqo1p9/qh2BRDy" ..
	"37LX3Av/YUNqfkEre9MP4dRvu8T2Nx/eEp/uFByL4arbBZ7kN5NiMLe9xphIeHrsUU42HYlnpSkfV12J4+IxYXhc3VVPS8rFS/Ok" ..
	"EWiLnYDP5qra5TqKSpOpcCdoCJLB7XWaKNEt+OY7RgQANVs5Qr3KnrmZN6zdRkGFEUh1N8rXbeOZvS/iDweCjoA38CNufp+XGVHK" ..
	"SQyM1lBwvcM/HX3HcEHUskntcrurlVOYs7Ii+n91fYjo5b87zuZRz5gssmCyQeX+JsbxRY53WjLXdvKtGexa/AUbMthblSZ9SG+D" ..
	"ylIZ3gTO9/bh+MRWSPcPZ2Br6l9jGT4gMcYv0KmMjfET/uCWL0XNitdX7tVb2BnhJghw82/VGIb1Tu+FFLSnIkJvKUJnpJp147h0" ..
	"Isoid7lXTwMOPmDs6sZIgmpwMecA4jjzqIfbftJoCAyfe3F/oVrraQm2IP00C7WGZbs395RYY/MnvS8yjdleFSnCylhaO5ZoV8UQ" ..
	"PTsmqH3OSBVEqkgFe/SdX3UvO4vFJLrqh2Jnfq1j9qEvkBVnjPWgAmPAlwXysml5COWkXjaTlQAOdLEKrncG/MjclwRa0y2zQAKk" ..
	"1dGKxj6sKd2tWtrv/HMLOk4HiETgsiK4oL95rZUql8YRLnzVKheJLOECgmE6H/wTORTefTauBwEi48yxzy0SA0m8RYVnsKaoYkQ6" ..
	"4PqKca1wKqwb+pchKTKoJu/Cea43iwOvji5p2iXnmkIFdhCPERNqk7tn1P0E2gamtKJ7pnjlEo9lxK/9WzbhpC8gjGd1qmb6MtKR" ..
	"UZErmSFjRfvqsgDy7MG0U9RX9pAO+gnYrus3FsQekNPrEGae6ziS4IYhsxNnSQlpCGOFlV9rZLT6sfY2Mpr8CAEnhRaA3v8+ilNX" ..
	"MgywjIusaoelLUqAtUSb3vNTUI+JpPhyjMPdXWCaXmuo7VU5X6C+0k5z0FwVI70ZgnI5UU8eW+m5BIcCHxgQ48plDCb70VB02PM0" ..
	"m/BRXKEITiT2G8UdzkxXsAPRjwwI7aulTkzricSiZM7EI+8HSPcd7hflsmQrQmG0Zrn4bS6Cu0PrVgUwHShofWBHRkral983ZBBv" ..
	"kjvqcUC5B4i5WtAi+3YTCsdQAN/INRnm/E4tZh8FTYOJyAstBbwp2UJOnLYvf8TVXyXWHIRd7Ofsm1Fp027WlZ//Trt0RfeyulFG" ..
	"3bhJWm1Gk6BlyacYDLtkpwq+Udr2fd2mivc0e4NyukLb85Vnzn8JN7xwGCi/eCK+EZ9R3K7lBEkKRncVX+tYUCyuA2WIJ0O4vQ5D" ..
	"7FYDu+UcBIecW2xK0Lt4Tgqy8ulxCMhsxcjHqejt7f0+FF9114rAclTyU9D97tkgcx4TJe/HvCa4fFs20pEo+Zq7SQz2CNOGBFks" ..
	"aD8w7mkECF2DBTrthH7qTp9LtvvEOEvuTr3vOyNcQxgZaBrQfYH4rIanzlfil1HTWsymOgtYnZowA4mR0yxR+q2ucO3MUzMqnPBE" ..
	"qPu/WfiiwE9zSKWsLaPjxS1NAHjo88oUi0KwdfbvOQgFfZA1DrVIY/HXAqPTKIC3vLYlc+mHDAEZrIuaTPwgIEMmofJdfbT5lvtb" ..
	"ROY+gpQj+x3wnqutlgUMga9swJ+zbi8NG3BaOb8y0OoE3PC9COV5RheOU5aFfELT6gAAkLW/3z+kFureXOb+56GFl+4P17I9V+WP" ..
	"5YAQi+Yzp6rHPY5LAFRCKoiIsmBNxUyOCGwA5u/7f6rKY8uBq5dvqUL7VuIfjJlDYnO89hkfxjMAOQunMLTnT9M8Anij54AxTdxG" ..
	"INsnuWsMUTUSEqZZdExQH6QdGbYMx7rvz0lwHThn2zwlGbWrbVHLZn6Jgcg1VpiRqniKpGR7J4kReLXMe9CDI1mHjVtd6v3ozD0k" ..
	"OmmzjrLO0CCJpMa/0qyF4EX7QaZ+pDL7fN+cCo00RFOhO8Yt067c87zpFh9FqKzGWiK2wtdaP0R6QKbvb0QWoTK9IbIZ0eQ9Lbj9" ..
	"orCY/osp1wJXVf3oeuANAlK2hUDKPKJQoY2vrrTUmuuPydUxiDIV6K6jf1gY2diH8Tue0tcdq2wPlqAXCuQ2ReMIQk9YXmFFJt5K" ..
	"hT1PfJCuNB5MYIroRAgc4v7tIgW/ERUX2xeLOTprsQ4yeinulu1A0SguYOphjmjAj/apm7gbLkH99L1kMGqBtpA43dgl9dEPitEA" ..
	"C/ZSqhDcVm9sboYwGZM983ErgKeKoyplhw8pxEobrcfnvsWpdlnHb62iCT/xb006trv18wGng89PW6W5yVcJFq9AHz6nMi5N5lNP" ..
	"PDLx2syds11GaBoZuPmqQ1RRParIPlc1jM8uDiTRIaFLA7BFoWLPn40WkSKFBOAkFVRcl0iQsbafWpIF3T5rDWrlf9/HUS1cYBVh" ..
	"Wl9f3aJvJhYsJLClxWTeS2PA9F6fwGTiF9cVJWwADimKP+KqWd+rSEFZZe4DEkppU5Hab/3TGZUW185nJZ5gPmrFT3EcveM2uz5M" ..
	"P+a0Wu1lpoNw994pLSKT5jmzwz+oolUwsUCuBFcByEg/5VphwwsGAeIC83XCDul3z8Ii5431yIr+PxpjMGpwb7W5fOmtJ9lIkAh0" ..
	"5lJaQn3kDlL3ZPYIqT5xM6Qte96nQyU88CD/O/Oq98PiW3mWkIsbOhaEUrEzswoUKyvtbTAgKrbLxmfoQy5qC9uvOqYtyS137Irj" ..
	"/horE3xBK6R/aKvA4LcPnFnj84e9MYjB+GJgJJt4UQ4m9wL7mlrg9Uu/M1yNyMbQK+ymQ6fXtzuRfyOs/7qVxAa3E6IUDp2rXnxU" ..
	"Nmq31ImuDNJfyQF7HVUyQWKUs2BWoRpl/WN2hRaaHatF9r8oCFa0IcmiYr0tPlPo7UTURd3tTveEH17XMU/58EwfpFpcOtgvrNzQ" ..
	"f7I/KrokURr1wuUcHzWsC/yzo31kGsPxWErWvTqn321U1L797ynVMj3D2Ux25kk+9fdRZC/ucKdQwg+Aq/HRli5giJBnXtQcTSRe" ..
	"dbggOKR1NY9aN74OevZtp6HiFS4YFuVxxpovtJDhN4wZQKbTV6oLIir5cqrIBM3g/JY3aqHHYfsqCzpkMW1wZVNTs+oWxcQ8oPXw" ..
	"3kGQpgIhfOt0nB+Gw5kMTlUq2U5ypGIq/XarPfrqyss3q9oZTrhCRuHf1Wd+augygFo2/mn2Bt/Q4AqgG8mOAj+TBzNHeeiYZHJZ" ..
	"9OVTDLozXpWM2Jp+wOdg3nIvWhLdS83SavhUdgQx1NtOdTrfZBaZHx4KCXnbaXKNhx97ZvTkNrCohciDe+Q4lB1YPDg5j2hShG4A" ..
	"n0ZjVwpSMaielLY74CpFxq5KgEhESyszbE5GgJaqj+86wTi8GzLhVByFwknn/NewnI6I23E8VYrckH2ZvupljaNKH9fe+rJWilql" ..
	"KmlxxAxgEGqYn2xouqP1MQVQQzFLq79nfzfxkgohW0/FKKCjpMdxsdHU3Q7BrFyNqxEf6axc83buVhliBWqiZvXuOFcswxfpP27W" ..
	"7hsk99DkI4U187GUfmZMK7VJr4b+V7e4HGHoUq0w1ErI/UFSA4PE5hMy3SmGfMjztaRUT7gyiUI8G9N0n0FZ4SmHdWAVltGlgcFZ" ..
	"wnQVzXeghB1p5So15om743tB8MLS4C1u99VnHa7SWnubyJ6sfSP4swx2opQCdnFvPyah9EWeR7dViodha5/pYvgKjSQ1wOdJVa6W" ..
	"LwFkeqcxHViZc6LMqEHJUMk0xfgrOIq/fw3ECmPYDTKX1VYKTnXSg0x0FW0QFYvv0lmrKTczWVKEOjRB2Fgyroyt9A9Vf69eO31u" ..
	"tTTcCbsqBvRXV6r09IFWdLXfOO7zyLTGrBtaOg4HjaKLrf6wEDb4K42lIlwte8nZ08fd1gROYoiEC1DCjrRj8Ff8bDZBacI8ywv8" ..
	"HdKrBUfYNaK4kTQKAGv8wgoC/vbleSl+ucZerE4xR5VvLEphQQeRO33/wMzcm+cbaQEGpYQ8GpKZitBsDCqCw+Grd8YLXvlPEe4U" ..
	"uAwf+fnNd/dPhBGt+Sw+ysNt0in7lyj4FeMdBW83nmoxMu3F/aFQM1GU02pSQTwovpVIXYdDC1OTsS9uifU2XL77CdcaFLZjPQ8t" ..
	"Mv2sYsMpKtdoTwLWNK6mnmiQAT9uYgCj/I9zeVQE7NuTijem6J5qfCVvSUg1hQy6t8teJBD28qow8WLG0kVo61eJ9cdsSOHQVWfk" ..
	"bgzCC/yFZYkWYzmqiO4IujEdsrQOq4ZK30RJzRVZxMYDMpXa/eaefAauspxDwfjm60Xk2qVrwrLUIFtFJI2/B+yCroV0Bqc3D+0v" ..
	"xcOxUncVs24RfxnBxn0JVjEkOXlDEGuLd+CsjVGwXBdN27MgPVVjiLFXiHGrsV/0tN+8jsQPo5Xs1ITbNnBbzYqxEf5ujHoIsmW6" ..
	"WqHhK5i3sNiDrz+8AJ15g/wYB83mc0oujh1DaWzbBoG0VwnWEdoJOgknopnqB/3ADE8tVXMdPztRwDwRjXVkjY0xvCVjd6QN7T05" ..
	"kaNA98CxUQ/AyB5Ly4WjXDExc15rGTmDfieN2NIT8GT+9k4+0A1WPGYkv0QuU4ZAshcBs/w124PEZdFoRX4rfDI6uB1m+0g+SbVr" ..
	"WpzxTDoOC1invfiGD2jpWLif/og5LBKZsM2t9Gj372bB0cmOVNP1+z4TMKmKYpSIyAjN66zN8PKlMJYQL9vhciqhZjAqvDlhxpHu" ..
	"4/gQ0j/E8mVYStpmM6PDeSUsFhPiTUyX3AOPVAgafbgRh2AaYyzWwLWkheP9kJJiAjoPEG+pVpCIAuInXBvQNCN2ON6RphLUUOi0" ..
	"lnAYydEusd7X95NZ7yB+TLEhdfhcKNdQzw1E+bdxc3ECnAz47fJBFAkEa7XfgZ0aNe9i0TKgturBcus9YpG3wQ8bN536Hq7UW7S8" ..
	"B0LkrDXF+/wYcT4MsIuuuCS7j/4R5nXHJcCwtayYZvmGvpIdb3w2kFbwaJ+ZHwY0en30Q6MAsk/taf1gqWLn5FnWbD7qmzG8ln5K" ..
	"ZSuif0FfZBQJ436hOMponL27QgzU9Gmbl22xDfLabkDzPbg2ZtJdA8+rUOQzV3kzsHuwb4Cyia/JrrtRl3Ynqb3kK8h+fyjuJFLl" ..
	"sTuzvdAXsx1FCnoVEg6bqcWcrGs3RhVcTpUWcxXCr6p7vP714DfyWD4a9Ym2WQn5VEvYrRG7GbpCFiW8ArNrxpRymrcl1Apiv/zD" ..
	"XKDIZmI4L4o7WRr4TDZpBYEiF8r6+LzKw1UWUP6HAA7/40nShBo+akQhmfNc9/n+pXHTYaUQ+pDKQ2vSzL/y44OAhQ+lLJMfOlN9" ..
	""
local PAYLOAD_P2 =
	"0I+CjD/6VJCGIF+sOIFiuYI1u7AHmaj2fA1U1kH2Pg+FWmvXdIxfCPyMONyV0w/QF02wo5XzwAU4IHOdeQL2B6J+Qq6uotAA3InS" ..
	"NQ5O5FbX+MjzZLgJc2ONgWqLFGvGJrCWzjWkYdZwLGKi6MdVNc4tieKO9KDXh+T+O3WwH+IDUkw7LMX2ZviVOTNVLFnqh6JDsqAm" ..
	"yDP6pDCPJtAYsXTuU994cQaoTq2G508zFHBZm5lAhv0xDrC4DL4dn49k7rxOp26zPVbyjDemjPMfJNYjvHlnUVbo9bGjOyggvrex" ..
	"0WVj43+vkQ1ZxUGTqnLmJ1ve6YW3JYxqFOFUwGoRzfpnScHGNe300vpg2DicPIP9r28GpuPFQZy6EvsaSl0m+U+wpmXrsBqxQQ6f" ..
	"t+wnVgUMZOV3ojAd2UUtnFELzXYQPMEoUWCOOQykQmdN04ADUAPm6NbQ8E3nodBigvRL+YnG6EqUsTuyUmcQ3bdZMZWPd+9+aYKm" ..
	"sspAq/xLRxVMdt8CFAYrs8IbbN9sJP9MaarPYf2K3LK0GPdJoUng1tnQaKOZgaFB6BkCQIRCMKjq71F7I15dH9z/esXzLUiiO4q9" ..
	"acvrMoiXdWlnT9Z9mfu4PX9TChJJSUWcA5+IOwMOYUGlLjlDs7s7gTUAQMqIU+838bpWQYtZDN7r/8Rwg4qFoTWAoL5gPSxHqXS/" ..
	"8QT+zXH1L7bwKxbGmDJfZIrwJ66KuB/4GGOZfM9QtaSaiq4RkS+vvbxpvU2DwOp5bGCLXGL2AH2pbVUIywhCzMKC7QU+WT+IlqEa" ..
	"2k5Md8/R7Km6P0APOZHF2XRj+Xt0LUsuKFrFMK3jfq/7i+DnrODGQMGv2OM4FjfVClvGt0cSIBSugYL5JiwcplOcIT1LbGtQdS8B" ..
	"cdUfTLurRGuYrPWNt/nM2tt+hBI4a+U5XUW6u4AlCVAkdiVSx5skSTsnX/oRIxpsSatFtXYDlCTKiktNHR7wvmYQNq7OCCu4klPI" ..
	"1nYIDW5LKmS+8kPC/dg93WxyIGpBFKsqnVLyWycIrYb2U/cWq3UnO9W7iciWfKJFp8Tr4gzm8hZ3r9wMIgP7uYBIMVHDBkDeFmwt" ..
	"hKaTtSsszBRgLT+Ors+jF0wzYDUP7i5ZpEF5OcWFFgF7G5NAjrF6Qs2C6Ze3tAO67pHymYGEm+BMbmeQnscPLsckZHk1Ahcaue87" ..
	"HClI0CYwqrzARl0SgucTe6u3DbncNiJF+m5/9aB1yT5MOv7Lu7yqIVQcAGarJGqYHHVqc5qQmM0DaLt9fVpPHw9r/glpvsTBjqQx" ..
	"d+9P+O2mjMmeEdqBZwj8NbJhqa2fHoWFdoHjMWjJdtqwKYP3jvL4j81BZo6gzDjJPoz/DPjny1j3WUxcGmDCvZZi7HYBjj/QpXrp" ..
	"cCQzM1KP8qgLkdIjcX37BCqIwpC0t3Q9P1fG3MGSS45cJwCbUNDr0REfHVNcHEy/6TwswOinS5Bza+f/NJFRmZkgpVmx1sbLGrbZ" ..
	"yhWrelmmcwVvAKXmDjUWtj4/Mlp/EazX7rlSkW4AfUkKymPsxW7ZDzpHdT9o/LyWwh9HehQ/fgEs5n/WP7d6raKwhs/bDgUpFvCn" ..
	"M68agvLdvvkAOplwsWZneY1xAnnAlyLWmLpY17IvhizHGS0idJckriu6nPDAYQUEUpWTUhkpE9P1s2l/pymNy2HCvnbK6359fTNA" ..
	"Io2OzPCyP8NIGkcigsZGAKSC0eIu80C1YIsWlKL3NGBuZThv3Be1szzbXD2SZs+eiS61BGY8fq4rBCqhMNVss6NRTXSfYeHvGAEB" ..
	"6G/k306g+WzrjlhL5wfoaqHqSFLxNXIPyttU1WE9gQ4KIdUeW6cHP+pZ3TaQsqviu+mKOAdloADI7u+qbGDKjED+qowkZke683mG" ..
	"wKjbmzcLz0TIq2ciH2kxwQQQ0hfuU7E4SrC/5+vOZBoophaauzsW4dSvctPAeKvwsIUAGLAqmOrSOy58UxANtIkE0nAYIJ1Y1iis" ..
	"8MsbCmghQrTsMe20l7RUP2OBfOtR2+r7FtPYtns25tZ6G/CA6wpe7fYzLUos9gz4rpFZOtKDjm2WR8ieyQrRFylS5he+TVDAU3Hz" ..
	"3icT3wTWYw0tbGwcc6Cvm+pXjlolsuThhnTwRUnxeCzE+Q8iLm6zSf9Uvb5rTMwm0BeG6kgad6nuXJJ2MGirkqSMmeCIFAa3CpRw" ..
	"oz9v67Sm2Y+H0PSsCHLO8CJz1yP8volJ0QPhzC1nm+Yjt732Y93TDeDtru2gaAmfskyIvl1f7bAkW6SIQ71jLpzpyDqPAX88Uof0" ..
	"GK4rhWKZnOQXbHJoZxsMsVufavITtXXqCdk/W5RSoCGplFEKdTH4VmwbPPtHlUP5zXKG27WATyK8s3U0gNJb/c3ekV4S3m8XhuiJ" ..
	"qS3gn987QpavCXuzyic/ty9ewC68VVMnCF6ipaRrT11qHUNZV6PpJXngK0FbdC2svxj6GJ22wa8DN5FqxRE96YJg81V1RQ+k9dB9" ..
	"HllRLEoNbHelTmM3SSERd4EFRAWrvQmP+ZWB1GVbK6dj8JUeINXhRKJqw1PjI89bXR3gNyvCEmr0i0L4Pyxi9G18hhDfDVIEN9fB" ..
	"YIPivnpUymvJfqNV5NmqEo+liJnn5sKYaF2xfE/Np7PgZshoxGowgLGuPpAVldZ/Qpg136pPpVX0gLcT7wA59Q50n5EKQCbg/zjA" ..
	"4xxHWZ3fk98weiue8hSXy+uPFI235WKqoqCevcUg2Z0oBr4oNMUGbfaNNkJUZmbmZXipbCCvllrhDGrzJVz+Qm1ofZ9EwSxR3mn4" ..
	"miCrh9sTa9sf9l2XMpSvOuATrUsCMd45qVS52/BKxOQrHW/p0cHrJm1Klu6RQC0/qVSEuW2tSBZtdgXeCzgtAuAx2uBK5j76TIWU" ..
	"VaVPnm4iaUkck19Y3jq3oqhS2kfrQ7m6lolvBTco3vbwGDBL5D9fTitBsO3oK7HbJVMNHb7R9/CzKNepfyIDzs3n3UVk+XeRh9VG" ..
	"iqZXqzeFFVzGh5+InR3F+1OpUCDJAff9C5eoGsiSVfgJqH/WBXQ3WKsfuAeyGyYex5FsDv6K0dKcnGRqVLXindh+hDFXuVSDQAqG" ..
	"8jrHBCzzMwBUlh5UM3Gvy6Nfj2W5CE441oD+MyVQkE1BQqRKtnaUIqIZYFbpD4zZkx0Y97R9FO8si9L5PYlk+KtSXZFpGTkksuAb" ..
	"JWp51mVBqb2xUz3NgakPW8YxhNI0J/Tx7MO9i4nIyoWi6xtmh9+lvBMBrjf3vRcMXfegF8UPurAMP2Mhr/KIb/IXNmB3VTgJi9YO" ..
	"bIWD6bcBl2kuf9wvMVkLkPjxw4Z8Vnv0SlQh4sCC4TK6LZJm93sQm43pz5Spcr8tXoD2IYXk30FPph0YMX0/g64r3tZxxVVYtRLN" ..
	"NqtAWiltVnhRmHDEozlLYjiVcoEuHYnb76tVqH02o6a5pIcF+jCXIeDGQRInOPR4gdtl8z882//Qw1peTHLNO2ID8+NSCQNBS1Ov" ..
	"5/cbJg4hVGWodYzTK/Osl2Wx7N+5Wl6QujwG4lSqo1vxTmm2a1fO/2CJSRjK2HpSHPSlq0sbXk7R6ZgieT/+Zl6Ham2TMp6X8ppX" ..
	"YIEHiDpDcnPipVoWAd/n+PSXrKtPsWG0ISE3yD20xMnsFQMF5vkXJ0DFBYHmINQ6336zs9nw24ddd8RlF1tsxeIa1PUQT9xHCESD" ..
	"qn7gomDfoH6HrgM4ogQGBSWtVyaqJHrtZiuZ+dJ9SKPUtahr8SF4uSql3AJfG+wTd4678tGVVmwToToPkcvNJBbO2pE2Cbt85Kwj" ..
	"Vped7nvuTjH+ol3JwDYYNF2zAtgIk6bPG0aifijjDwxKYD+3blZ58k48OlMPMJr+V3xLFBrmGTnTMCdwXjITg47Sv/IMG725lxFM" ..
	"aVFjedcajAzrjKDcuTYbKD/LUHrilKgxR0NEhwzyq7iYJgxAZP3JwusZ9dqb7EQZOfu7BSy08Erg7Z9uwz8FKtadrSOPZAIEGQ1k" ..
	"O01mEEnVi8XqIwzmvUwbD6YVupQUHacsbN7FGY6Zk77Ul9OIF3ERdmGOxxoTesR0HNED2uo5xQtBh6xloV3YpDW4uPpEcqhycCcB" ..
	"1XSo3wyFAPM876waEfBn6hssaWNX1b6n/2DQ7KouzWVNmgR8GMtCad4km+ebfbG7Va4nR72bdEsRpkh+5/IKko/45mro/t7RWauw" ..
	"fgrYAM8L1Stz7XnJDw5Man3oP8GaGlZoajv3hzODcXavUqabKTIVQiJqmBYtPOxTE67tAu7q3tKR9A7eV7MVOH74YlLdLwyOtPHB" ..
	"euGwu7o7rXThhps7CuLgPN/stdspqdLcPcyox+WM9gLi4i6ct1ZRNj1wGIVdYJ/s0Whx+f+1ZmbYwSxanTDkLW4Btg28UoK//V05" ..
	"9Wsffi3i3GcQui3t/cCaMHrnG+RQvXMzmKM/iBcIG4r9Yg+ZnUdkolax6dmb9T6NdphkT/3PdJ6lpYfmtKEYeCnszjKzcKAqnwE7" ..
	"oUepV8hSS9yGWsMPt5zalsi0vOwV4N0qaV8vQJe9/6ffI8CQxbCcAnOh0jzbaMRQZBUuEHHZ1qOYzuempsDl1sXkGKSA1njULjJ8" ..
	"25WqTlBF8W0G2EzGELcFLIP19x+AyzJtWQCENGq8QeiAtnqI5YQwd8pWlvTSJSd6e+1iSgaBC8xh40N9KoLUBanw8tyBLTpo97dY" ..
	"UzFeRSUGfGOOnFHc2rvMatDeeoGNIkM+GUh0hrE1NNWwuX8ZHiXIXsLlg3GvhAoqxhAC2Xn+7zh/jJOaZehCmLJTmF0QLHbkY2al" ..
	"683EYFLrNYpgKjPe5KlVjOTk8qRIf/TJ0WXTtRgrZ/6IxKQBIpBZ/vQK4ZnwENGzWa3TbOZQz65iM55bhTqojkHPtm15xNZjrnA4" ..
	"930slnUsiFArBYZe1APUdyRDE0rrDj0U9sXpGi3P22F8UZ588JwRmkks54gGYXih7ApftHt50VWHoZhdeCRa7TsL/B8v8m4I3p1j" ..
	"YXoFPYsgcUGDgEaWxSh6Thn+8yHaJnkMD5uO5x/z01EjXQKnxlP2plIWb7I+LaZNPblrO2wx1d4rICnsu3I9WIwyCS6iMukadJF0" ..
	"SjY2HiA+h0TeRhBuJHEKHK54VOBqpqBNDxr8RdVfrsDuB6BZ6dfjmhqk5/Suiz/Js7XW6w3Yl60Zz6OEq9szrEhLR5X5pzyEMlsp" ..
	"xs5zwu2hwAt/hfT05JV/NjPNaWoLpXb/dNeTb0PZYoiRpg07MrYZLP0cMYiBWpJPYV6dDyJCMfm+Pw/jxONc8dY+52K9jSnMOiWs" ..
	"4H+P9KcKHOD2NVH/dtLNg3VS+XJp+mlK/GVIEAyj/t/1VQpB2aKuVPT+P4EmS1HCeN5hXMcBMsmLq//iSrYzlmANntEa0RBRr6aq" ..
	"9xGJZObFiVFTUpJp6cegwncBV2J3NxiTHCJlVzaPnhF7OwJ2B5JOy/VB4UqzbeyAI2BpyzM2RkMphX9OClTtDOBQe9nHMZV94S5u" ..
	"jZ3Dmp1jME6m+P+owtVUBNwAEDrm0oDU9Lf1Zv7SaX0VdA0sAcezCb8eYzQi8UbhBGGQrlOcCbuF5wx/dHoLzZI4TT7IpWVQ4A8V" ..
	"hUYh2cpOlvDsDay8rE+P0PbqwoHQmrrdhYgCKH01TfCMoeGz3B1HWAY0e2YuUxMzEcYq0L+QqFBl3S9NIkzfAouvEv23SMjwmZmC" ..
	"om6VDj0ktgrjWe/ADnQqLvY+XUxpEgB/wGqZo+BSFdJOJDLjB58SzDgbMU/W+owrHC+3mHOXAkJcuopOChXQeWUkKhavjWfn2ozF" ..
	"7aL6ju5P7WpyjP27Ie4aVM+knLwTWhpIqkkNA4nb4Gso8f/NKM9Haa1lsMdLKq5TeiH2Wu4R5dLdtDL5JuZB97GFDAspR8lppqs7" ..
	"MGy51Uo/dB12gRsYTN/j3tdUhoiQ6gFHlNuCZsMJLE/xArFaJ3wRijQmsusR9vmsh6Al3jyHLJODpnjo5adXu1JjigGMWRpm6HSV" ..
	""
local PAYLOAD_P3 =
	"VAVNJH//gK4g4cfXekemtibraXgXBx+s/gNdSzUJgAGN2qMTvp19JI/RiXjDIuX+/QakxleC18YrihpQHJ6kU79JnisIDsguAHQ2" ..
	"RS+Wky/WarwExbf9OLRps5B/u2bWOuHgs6GPT9Ooq40VigqZ+jB4Jw3xNFczVImkc7KDAII69p1s4ZPURFOUnh6YIsmxExJ1zJxp" ..
	"GHetVrXTPJ1hzECE3hdFJ5OUISUEaGGPGai9CeXFbdRDI40w3ukFkzTftOBXmofdd9/zazVQP3S+eiIe3mImIs9K+grUR1IIoN28" ..
	"TktiIPhpbgg9skmWCsGlewlUzRIyNWxqKvYkFNpMUw3U9tM2aqHat/Wefx2R7eCvUFQDAw528SQgx/JhXjRXGvltvKe9g5rD4uPr" ..
	"qZYlWdortRLcUfENDH3KQJILTVZ0o7p11o0+Xj1pgkY77H3FZEV04Utqm2Dn+NGgfbJLzXff3TSTdrxSuMuUNb7FRwoUoqvSABN0" ..
	"a6LB/toL4SxogT5vnrhuB45ZbHa8XhvT2PP94wZFPuCixmAFkZw8F2voydJomOpXL209LVZcTG53bkyerQw3eZZ5woC398T0xsLT" ..
	"6kiX1HFEbpOQrhZ0y07LgVCg/JfatfUPrsBb9/igwdTo8b3ABUGBuQNqEwvO8/uRjTUlrn1zbivwiQaLS9iHh/7qw9QgDBlgA996" ..
	"3Moj7kXpO58hWCnEn1RLZVpNmjZQfBeIZPwdcSQ8MB1Pxx923HXAZEBk9XvwoW8mnOQtOd/LUX/pXV10Uzq5DxKBEe+NQP8frhQr" ..
	"5x22vXnSLJ1Rcx3M5g0l8MAbTr3R+2qIRrzbarB87i6dCfmSa+HYCWih2YjO5EwlFqhYZ85TxUnvJYlc850PbruW0eM8KpWW3oBs" ..
	"xvQOt1EOF2dxrsoZsZcNECd3Q37bYRlVzYLiHaC1xW+Mr7TSbgClrXkuNp02dbCH3fxMM7F+sBtv/C5PqAOMSDocXRx1xkWn6bVc" ..
	"V52EoV6tRmmX9E1xWrYS5ILAyWzoXnJ3VOVwvORRF+XJ2ISOndxoroCb7miPra4AKtJuecfcME9F+bps+1nM0XHmonjw5p0sS0Ti" ..
	"0zkkeLu9/QfFuYgrO635yZZgoytIFcnXASrHQUry1tgzqS1dJMF4FW3Z6Vh9n+EHInD3cHW65O/ndgv6CIeDgUjZ5Szwnja2nJUG" ..
	"wKKGBPr53eN1Ld4nmjaOR1afhJfPwBSZHSt4yRQ0sloSl2ZMR9lRrEBNQZFYQ1Cpj/7XV60smJ9uTXVVnZI3oSXoOrXgnrdD5b8B" ..
	"bmhj/I24lD9W3Z3WKee4u34i7WCB1SQKgNT5nXHIzJ+plo863PFCDI0uimWG+/TjiUnuFzdX128NCrXU32HP1kw4J9GQFz8uEBdI" ..
	"Nw5gPWICayBYMF9vfdrKdyTXiA2yImMoD9dtff6OuqRmLhf6r9dGgKREpoU1QV0pOMv7cj4uO9AZBaZu283w10GhW1N9PSDFJFDB" ..
	"txl34JLSNMWSzIHkVMjMb6ptMExGZSNV/7nmFL80LAGipKy3r1f2i79w1IDJ6EtEWgDnWkV1enRkGKjP0/6hk/8D0L1kX222/R4H" ..
	"zgHDI6cj2aNVfemKLB0lm/oQeHyAlO5TmGiTUy2XYRG0gmYwifotAsZWD+3vgDWoxFeNf9SXyUiPV4Nn2RwSKYSPXiVqTS+1I4+7" ..
	"jEPGUP3iW9TWNkY2bI5BXF1ILGcEj63Hy5Djc0ctVSRIntIoqBeQxPTKS2H0Mt7Z3siPung1gYwmdkzVx+prCuT9r23WFLD4G5G+" ..
	"FxKYxF/MO7T5kEV7RhqvZVJWWezOn8oKBrwm4gXH+at+PfyhmtDX7uBPs/NJAvN8JcKyq7JZu2awHutwYs55BqUxLSIllj8UFAUb" ..
	"ZP2yV8Hcddac3mZYrB8VJtnBU7QahtfS3ZLdQI+Na/GmD6mqAP+cYG6Zzsv8a9whMDyZN+v2cuWw7Xu9OX8OJgxLu+a1jaEwsYq6" ..
	"ytSgNnuHVJawAJ4r27VpNdjys3yOVXNM7JtK5MSN5FgCgZQegdSde0zgYUaaz+1RmxqpZAsA+WWVVLiwR3MYnOKA+FR2KYvA9p4v" ..
	"HytvPC/Felno9hh8BQ5PJ9zmqEJdd9rSFjjiP45ynmOyblOKzeQHBFpRAL2BoiBuT9Ne9RUKS8VVzGgtLxscUKH3VQ2Kg70m5NgG" ..
	"H8Eq5MENX4nfDGpQ30YyUjejmtjIkR7nGD8VMYPLor6lIDLjnDn+8fTUuv2P9vA+mu/sh/hU4Jwq5EyEdNjqb//voH9PnJUn3iFf" ..
	"R2SGx19dRWSWQ1yGeMp2DX8/q+P6EaJBLCPyXeJ9h4/UBDVfYbB7b87UhcSe3T1VXS7z+sWluy0gFbVdUImcBrOsqKndfEh071Wy" ..
	"fkPuXWAdjpjpFShXDjwl9DoSLB/iKjJ10fpn3kvB2gh1CwhbW718JBf4RK70pTYalgvT7O5jTzI1pmYOT+tpzAQBjwJLuGWnRxHt" ..
	"OFpTKHeayqVYThAp/cLnB2/Kl8nszE8jWRD+pgEjLjWisM9pa7JY5jL7BTjnH4Uv09oJjVJgiyprOKwgigzV21kDSBpRjGKp9W3y" ..
	"fFpMKRf4WDyXgTm0AF6T8rqRsA9v6psmczwnM+yuTqFs/E/C7Tx4DmGwWJiCa0UyW1lyL3SsETctlFttPXq8lL383x6rZ/qG/fWD" ..
	"zjW+noVXkuMHjJkqevLVl/V6YrFJCx/5bPyauFg0QRK9X4ibet1FHrnDu+CQ+8QGzmg1qBfbmVeXd6aTxpZma+O3zBdo8Pdj+1zM" ..
	"rb8dQWjblBHUOfdyAByAqZ7NCjnlm9qZ9hPdehpEoMaS3LFhn/3K2QTQuGN9W+UBHNaeCduH/VT+tGzdxCvpJXzIyNXCIAyTIWRm" ..
	"sosPf4nSAcUOOG17xo5yPTqJRtrY4mhGDzXYzqO3GX4ihuakLt1ZU3wHIJwO1DxlcN8Ar5wozJeu0DjlHmWdufd4oFoaTtbyoQEN" ..
	"lmlH9EXCdelOysvqvZOrNJpmhyxaGxwhSTmOtqCV26FMMihtiWb7MYHroXzQkw2JdSFsEY3VVFUIkE/iJgmkHvV+wDbHfNZpww1y" ..
	"O6vD6xteOx75Tzx2HR1AhPbQu7RoW4Dcgtz2FQk1iIpXRb4zK3Wjp0YLB51L+/RQSCJyz0vYXLkd/B4gEZM4ZkKL0wqs6GJ9Lxn8" ..
	"zZ4BwtTIeJF18PJZIRYvdfCumLWy//6aITByrT1GF6nW/KBV2cNI2Uh7y1cTjj2mj+7eKFXBTkZC3bie0HCJPaXFBccbqsdCpxww" ..
	"fJEXV01FR+8VtSDYqQOgivU/b+0BbQlFaUtymDla4N0t8Ykn8L75qhEp+NjdIgaQzeMl/UEIeKOlPb+/hwUglhgDQGGhK4068huQ" ..
	"mk0/u/WTbluWrNwssC2Ekkdqv1h2LT699zq0v1E+ArCrqg8Wn7UMhuyrBPCiWO2sGi8c666jmKUeUiD+NC7eYeST6Uuio1gfreGZ" ..
	"PEa+bOluirsX6vs/NZR4g8xo4jF83QOmBWxcJLXjlXubLTscMNMmt8bF8WXfR0flt+hbBPYQB3SSFdLffMdJlsDcNbUGVkyyrRsB" ..
	"cNRwL3x8uAWWYRqBMms/wqS2aGAwijVRRxL93b47w9hJIMsI7wGNjdCl8EThh5HVsXFdZDTYgaWhWb31teSg37ozCBTC91e4bv8U" ..
	"S2H4Tp4HXycrygHplrvQpuUibsgIHEud02idwOLL2hQG3cRiiRYuS0GG8pN//AOlmz49ogrFoZCsELpzgQgRgkXm/t1qJ7SlLxwh" ..
	"D03UYwozOK8ZmEosQrB4lBPt9+RyvRtUMLOTE9qXYkBJzSYGgN0kIIlMDeieW+joaglJlwfBk5O9oQPiwIMnPz23XbWYVLM2PnAq" ..
	"eeu7FJKvTgpFuvHoD8mOQ+l1Ka2maVhqMRoJYKv4KlhotqQcdurZrsarvDIlsx3QHtNTdAekPB1/xDCbumQ6a5OzXeY8HPYAxDZ+" ..
	"KFekNYDXG6+6vNtLlsr2wO8aoMpBiZhoNehB+YMENc8KGge2B4f6blnfhdSmSRa8WT7v5nZ5yQjG7uPemzktesCjnUIF/4AYp4AY" ..
	"g3/XQ5zzpNF8ZiM5YUmE0lZ6AMxiRzDMrNNtAlJXhOX0oqdbjm7H/7FXh0N4eDKAZz01N3QF44V4VudYywIGQaufZhhN+h8huCYn" ..
	"w/VFE+izCOIe4uqRLb/xNhOUvFiqzLUhVs01ZRyVrWXagakm2hTwk64sbupUG0zGPuYkwTlcuL61iQrQQuREq7vt6yU4Mxvpl7sc" ..
	"H9DcPVHs+/g5yVzQQXyZ+wQAw2WYzUlVNXZtHDZLTjKJeE4YUU1rVOHfTf2uu+HmZvtJwtzaxcJ14i6kpazvTVSiR78E0rFgiOYA" ..
	"n0qXll1s1MDptPFpnki9NNxXvo4RSeSb1ETAD0i0HdQTeUTkMWveqQdYU9TO8L2nB9y1zaObDbpceag+gJzQ4VoqEailft2AXJXR" ..
	"Kczty31Bhv7z2AEsHOI8RDbjn2OQ9ffArEM5MAdAlxBSN4KqQ227nxTrXaSESGW8dKuVv34qIIWjVYCReeyFlG1kmNpNqqFO0Y08" ..
	"LIWw3mbFQmDQGGxxqhNu1zvAQ9uyRzySNoCSFEqe2uVDFin5u01vVAeknuG/0Z340g99kZW9x3wygUAsHsCdeXiKS1ekPr3Ca1N5" ..
	"gr29Rw86QzdrQ50ga4DplzACR7W9ProrqZFAOWx6xgGjAwW2YAkwcbK+pgJX5gjTR1yS/WrSdQmHdwQhkLv5HQGov+R0ObIJ/4pB" ..
	"jvFZrxVxo9gaMcLrRc+qHZcnqwYXsRbl2Ol3P4PAI76x1n6xS45/zrQkhsYrmMt0lCtm4Mptn9+h0CxJXCMgi+RRaXyb6Rkkm2jw" ..
	"Sanl2qFpjCGgqoB5Jl2PFE8XdXlrqPOrX2ed8q4Pv/N9cdv01ATNpt0++CzMJmT9NenERRrmgMCxQYq75WerK/A4PWLnTWj+jzyp" ..
	"67Kv5ECh4hoEx52eXJihjMzA7eFnxXziScXbiWDRG3nY1+BAn+O0WJmTNSKtT36eSzS3F/gPBG94ayJ+99gRUBduzig3a2T1kNsH" ..
	"wbpsPuG1rR8/Zq2SiyXL/39rV4KbLPVRK06IVh4m13ldLkrzMpOKeMDavDmiw4GbTjjPcslbnDNw2iRFzUGhKhrDwCbjt4kNsv4B" ..
	"RHYmurXiGqgHKuZCWjkPUW4nto3XR5QlgsRW5SbvvWOGd5X3nUojihiOouSsaJuTFiDG0nWZOg2vlsa65Lqb0o1kNBL8FvzZe5Pf" ..
	"KIcChNU31+MEqUBie78GeoHPptrtWNV9aWX8b1qvIcUemsQNxxf901ByF8LYC+9cMTaMbHDojm7jZXF97xZRsgnxXdKxfRqdxJSQ" ..
	"+f9D99XHkyCWSb68vuCeh2KOzM5GSBVxND9O8Gb1Xl3S+hkKwWhzCu4ZcFpE1w3pDqWDc1G1GcVBK2Xuzk+sTrgLIn/M7yFq1QeK" ..
	"F66z/5vO1IxWezC6eln/HBsLN33eycgbeScrnnuyLHNV9vwOiZ46SC4SPJFjLPPFuMsoVGLYfNREoP1q0BcxMzt3dYEZAerdc0eo" ..
	"3yfICOHFsacxa5QIMLSz5kqtq3xGhx9G4GtnCCLTOS3Z55Z7C6BPIdAb5PyDNNCjoW2gf0q8Xoi5b1B6m5xC7bN2VdvUhe1W6UBZ" ..
	"/1/WvPP4zL7Y/M4pi3TRl8UQwvA7glwRZtgTGk1I01WmUVqmfBzFvnLNrTWFOzdAFqcWCmsuIGfxnsyJ8G3rBmoCjlKu13mwJdYL" ..
	"v2gBXlOOk7V59J1Y38lR/k1Yus8t1MmvkIVWpK1yc9xUWzGwOKV+J0ZhfxPx+w7rLfe9VGI+Nu/kPSvOrxGF7SSMnpEYiA9lKYG+" ..
	"XmhFWhDNiyjsTtDeFFCPYQt0SLZ7u1ms9fSW28jpJdRezq3GC2uQfU1eG3B2WXZGqhSfPrRbfue57luflcAtS7goYKstJEvO0lQU" ..
	""
local PAYLOAD_P4 =
	"igibdACt03o6t2g7/Gyoqa/Yu07wietcWryPs70Nmn65IELAEAxwmYLzouTulv+T+lPoDTFo82uTAhAJkte/5qtIfj2pUoE/o/zs" ..
	"IQgcjWvuOr1VBDvLfoZ6K/4HkRunxDXRKeL7zT/i/2LjjbXF0koe8ZYs0p8YBtQOlXmfa6NkjlS9uUsSiH3S9TanVKoJRdgG12a1" ..
	"a0e0PBD4wfztcKH7wxb2rDe4sx2ete++IVH4y7EyzoOC/TGXsIUCIwfovSrk1mz0wijUHJLk9zIHDrnHAcGmcAlDGJRHX05fIM/W" ..
	"Y7ox1JdwQYNOwGjWM03aaF+ARg7PlOYcNWFeL5NjFnTMgMdigSQUbkBancnbpzmUeVm2Oz/ohC+j1epXJCK/DmVfWc8oqh4Tl6BI" ..
	"DvqG3ZnR6kG25KVqZevMa2xRMN51mNcFm8NkPYB2F++G6K70Zgo9coO7cHk+Q6RGP1JJAloasN7W+p/Vw2wqu9QbJcRWGM1uMXWc" ..
	"+FiTWNl0CpPGqU+m56X8bQSX5y64IXT7cznKCZ+hV+MAlk8KP5dmB9Zo2rhJRP881M7ade1FOHG+9SN9hjywHQ7IwgsKAOkGx0JX" ..
	"BeJ+nUSu6W9OVOIezqCHyG7JtGhJAMBShl//jicZ/62juhJb7I434LB+rd8vh1E0azo3zVp8TLMJqbzBK7y31jd3WFVUQ37M1QGP" ..
	"xLz3n9Zwxm4/EdG7Xd8t6CxX7kOBX4IgO9hg3BENkIGv4vxUf1CGl1BIj2cEG6/WFTheoTmFCsCdCJCmN+8chBwS32wrN3r9uEt3" ..
	"2tAWUA4asRXX/MRtHc4cdFmkA2tGUl4lkHOZZqBNjrNX+JrBa6fHllNXTLq6wxkIjq0mQks/xxsGLe8l1m949mERpgh5AdV/XROK" ..
	"3+q54dhe69nCpmPLHtakO+B4j2O3q3JhNt2tzeI6mLPwEVTxyL4ATiwDZnmdQGLp8WJjUXeYJ8ZC3uyYWhXLmbbOiiBzEoeOPbnS" ..
	"rqX4M9ByTLnI2H0tVI/CyKwnWmHBHHNKNd1ciW5UYsTy4VX+6ZvfEWVg/sO5b6D1eJK5AJrOfMHX4T20LgcaUcNktWCCYl8tv/5P" ..
	"36r5iVvLrqMVc5Zrddaiwf4WVghlHr4SeGPjC/5z2gdfZoZkv1zNFm5tPIZi+vtG52U+Q67THDRedzQMcjVcYXfnhEPWivG03XTB" ..
	"elnUJieaRIvkE1StW+OWaviouFlfnI2CynDkOUNuwRZitUw7aedKr133vg/lK6BhqjGG51beh5icXRt8MVtz7dQEjeS+diiR0VCH" ..
	"Qs6CIgUgDDebZXRZ7fGvmCWXf8hfKKo3bMPbhTjsxUQrGZT4SNb+oELmyrmpDGDidTCTCgPVVbbHWG/Lr+iPBay2K+yuKOjwV6Mq" ..
	"w1jSWcQCtvGipQO1Zl7IRAuFrkS8NL2NSFGXDp6+xJ/wZbtZczUcBxyvWKAOeg4eRnHzvSYxt5bVvGuijWa4T/xC09lWU9+apECx" ..
	"IZB8IiRnVDMfnjGLKGx4PGnMfFDaxxpHxoNJXk+QgSA/RXSjhJRudW4XAq3iw+jnW+YWlVhWqknjy0PfPP/G726tNLU7p7fvMMDB" ..
	"S1Px+2q8/e1jU4N8xzpJP+VZuSHjakVjI87NOcvr+6bvq4V/6COt4mL5iEsKEoBioVNR8qJxcflUNkNQ+minonoYsbVLQsayhXJ2" ..
	"R0mb6Y/x87pFVuh7z1ZM32K7k4LIKblhwVq9u3jIhtlugPvuRCjS3cf1uDsF6gyadjzkYJAVDdgyAWIrKtHAg6VNRYQDUkcLkWcU" ..
	"p6cqJITqesv6WerKKaxHSJeg7Svm5nh+a/0ehmiFHv6wwlhWI3twQMn/KZyNnvABBdt6vUI8eX3j5+5/Q9sZAOVQPzFiajM7PC5N" ..
	"DV6W5o/cpQwHEV1zF3+vszW0m2EKcC1UjCumy8gWSjfKWkpIwQfECfR/0AkJ7vYAo4NSHMKPdQxXd5IuZwULGA90kNpoqXtDa6Nu" ..
	"oy5NKp4w9D58D87YyWII9hHYPyfhhQqt49/fFgWFiKpVkL+2RxX/67w6m4Rp4LMc3idzSawOO+imnRXtHg0nQeqlXi2mKBVyxL7N" ..
	"BaxKimVwkO8chq52H9S2n7b5DiuI7e5uq1XM+XLGKEv+DKeskrSmFmBBiuexkl1wGnvMSdkTjqJdtiPT9VQMaHMe5BLMCRaFvXYj" ..
	"AOzrfmkjnwcMIBjXyKdh0WdZZLHywk7Kq95dEaXuRvKO8G7iNEYgyWazCptROBnDdG7EjZRY6J6HJI2hwoIeVAHinrjb0TcZQvHE" ..
	"kp4Iw/E0VKMTtKv6u1rmmgqy2Ts8f4kTR5Ft0t3qqSNpCfFE7QNO9ubjPiyu8BLbtclnBLtwYhPWBseAe7Fgn0NC2Kz7nWYCim2f" ..
	"25Vxi0w0mfFdzYMdUIUm/FL1+WLd8TJvAbj5rf0j9aL6otmyPXoakOECs7804CVMhL02GU/jQ1I4JF/s22+KhIfpBsa21BZwNpQl" ..
	"Lie1w0XRGTk9my2cvRyfvIakoXBuYBMo+Zn9/OVQHYO+k0FKr1IiL2GYINflk6+UjtgxQ2D+8hJnezO1kx9F2RS1yItx/xMst1oB" ..
	"IOjsJqPdlgvJGGzWrvvW0XvcnhulnKbgN0CHEaINbcqxP3qeabuGnpO1N5FiuvRdQDBgoCZ2XK71fl2ZzSP9QeU6NABRfVn5uwi3" ..
	"WbhNP9eucksYKdw35rotIqF+tvxs+JVSWXAzR+VDYCCA5yR4m71f/lJOIXjHPONQqu5iAC+u2dOdvefN4kzYbh2lmydVr8a7XmgH" ..
	"rlEsgKLjEDTQneyoI2a0Esv27Ju/El6n0A7gVqRizC2i+PO+MkwLGSK5LI2ITl0Io3ngBNiKpKMF1WUdC+gw56NdlRmapO5fC3Nf" ..
	"KmgaCd7u+tLerbkzgYj9WoTpdSaZRFPpMNxFUXKtApn+GpyulMvfUzfq7C8jZSX6rLbY/JL5gb6ZRH/+D/JvnIg9MKt6OcC1yY38" ..
	"wja4fRQkBa19ikL5Vdl5QH7m+JuNxrcTWKZ7w+4zPnfpWN1SOoBZ5vpZIDw/pxHkY3rKo8xu9Por+UCx1TGIR6QlR1xtf/xmLmCF" ..
	"r0+HUcm7hjA7NShP6NM3e7Ok8MSmQdk9xwPf9diB4wxCuGxYYkEh/1zPsnvw5XQVPRn3LaDqrhV6PxNH1Pmq5GH11xO9ENSg/+Ha" ..
	"zNrnfglYdOAbCYQTPatcjxrijLoSgbe5xyndM20pB0vyuFV+qh9UHpsnaWhB7/Bw+umCakyUt/23qbP6TGr7T8XHLh4rchYOBmqi" ..
	"8oUiPf6yTu4zqCmyl05H+nlt/IL5edql2ThXYSoDMfJO14OiUUq8Tfsw+LkC+NDs4RRdXXivDMRqpcSEXxX+5X2BKvDi0qQ5PM9s" ..
	"s3zx9RBp4DrTrr+V8Fj7ei39r/Kwgtr24Mx9zuLDkCC4c6NkDW5ZPaMLPlnvjYJlbHZ+4Bsj8rwlGadMB+ADL4tT26Qk1r+0XPMz" ..
	"hBTaJG1Pn4fLBgap399CPkvMAKn4QhJ82EwN7YQbQLLQvHpCnDrD/j/uqmj+haFS0aK6O05nefJsdeGiaTeCYjagr5yw34ztwH4V" ..
	"rB3F84/rXTSfhNDD8UJc6f6IbqDKMA2lsQtEjAHqQnAktBevuETaVqVSbsiWFLl4GM/10pmuorV6HiH/JOgYhVN5CKhC0l6XTf5J" ..
	"vSadFvpcaAHIS+dRjQQykS83QmZCfVtUMA+sBnI7DJ8YE2eFNenvhkd2GWbU2GMT5J0r2rvWw7EmeEXROf8urrsRk5v13hxz2JHK" ..
	"pR+1ml6eNPm8z4VMOEuSt5STQa+m1XTl87LHtPA2aV9L7GysXwYqIGOysqoUUlLkYBIzLziZY1nE9qriXoqmZYcKWQUXNBWhe6d8" ..
	"M13cXxUkACl4TMoqtIiDarjZ0fjGpgVCObn5yu7p2tI6BDi2aIEu17V1tGd4LX47MLn+MorbY3SDwtMbKwJDA1yLOUqq4K73WPqi" ..
	"eXebHj5Qr981JW3ZX6FppZkUxJM5ScEBz0M2Gi2qp4YESonQ50r48n20CyUvNSGf/uF17gld25aB378DPk3hc4H2InRGI3ND4Hek" ..
	"z1LupYjITLZxVeNywAlSnVBAq8bS/Gr4ishtZybhJN1ilpf7RjvzOby+QHcseKy8gYH1doyyh8Urkc379CYt+X/uFFipU36r+onG" ..
	"ChrPUCoMsMFHt4h9NO4mbCoVDPF8rA4KQBtegWobFfR6A41VaPeFbNdeAZaszwUn9lbSqHRsW9B7ViNL8KfCwIXCau55WtrwC/cg" ..
	"bIKMxcDKw0Sf/ZkeTMnw39ULF1f21KjJ5/dTrjzJsk0X4+moVM5fsZWkszy2dK0OKTsGKDN+Geef2v1oTmy9gz/j27UlX51upfWO" ..
	"OrJXRpwFdRjbW3AJB59eBcCTdAakNgalRJpRk+uk6kEV/fH5PPo065SnaShuNPOv+NDhq05HoJlwptR2ys6b8Biz6DTunxU1lBHu" ..
	"plPDxFml1E440nkuV8QpwjXRjL5VuAR48Fkq+J1LxQQJYzoZ2oPKrNHO5JtLnYC61w7Dg/CeegQjXFtLIiw2NXAqDw0X/i8OMq+U" ..
	"cE9XRCNtoD5Jh5n7sF72u2Lf9svNIV3rHOtnmMG0RScmvfQnxHPm6/WxCwnRmJLKXts8yek7mSAwmhcQOmn1KvRCBfDFuqITyvXN" ..
	"qNPhYbwsdJwrOai0QZxbaAuOUEtpLvFwzcU4sunY/usUPn3lNUqXvx3keYo8KgNYjUKx92vpQng6rC3Sw3z9y0hd4y3ps1nN2cnh" ..
	"S8q8vHFmqWSo+XiN9c+sQu58n416KobK6XmwNieljEBjMgD1bKlRe+Po02SJG2E/3AM5qFeIr8yj66kq1DI7bOWOHqTjrW6lWZhU" ..
	"Zfno4wyBYPLykrFsk2D69NXLktLWm8zl04WA3wyfW0kqBNVDbP/QGOs/p6x8efHDhzPAPpa25ZMiX6qc8/KDS0rgAM+Qj7o4PgwJ" ..
	"HOiImsyeCvyaYR5RmYzDV08kGENhpf3P6oxsASG9ZWcRfu9p0XjcWiKui0L+6WD/QR+zMGKYQCphikZvS/DvXqk8Vh9A4NzCNOYH" ..
	"Z03PNeOZy/FvwoHbvPmpdnGWGJ1ZLoR1CZdwkmXPlcngRe4YcQADuHpswtA4ML5UnFjwLtM6zBZ32KBqu8Vg3wgXg9hBGdYGGU45" ..
	"kztgvotV4oh9LUFPtguErD88MOFK92NTSqXEsWrymQtVZ3iKbCmtqsXPvyhokrSM/ZtctvLFM8tYOPTDKKTa0Sraom2oj/ZzjdvL" ..
	"YMuhxcznLrKAfQtXM/axlhzL6zoKUhAPP8oodT8L6/o0YbOgDf406XqBgCSQFjQWDPkBJOaJplrKRse7XfFZFFbLi3obtylJ58Zb" ..
	"Wyd0TepjWmkm01FMRK1yTmv9WdfOs72BkvaamHJ8o3OEQnX1SaOJ+Gcj8Wj5Rj6bwe24w2XoGRoieciF0I5h/dzddfZQtF8qvA+c" ..
	"QLB2FUKjSTiPwaSPetxvz850BIByJJB3ErJOMVNdFi/ZP48K944ecb1mepbEnXtjei+/aZU4z5PMIOKXRKkwqoKfWmsu4gSfCjRM" ..
	"JCsPYUA858fP/Gp/VZRfGj0Ks2Nq6a7ubu9WEk4Pt991BUL8CsZ38lAkyI91PeSTI3t0vp7tQAkXHx6zl21yoPtWIemn2npNlKbZ" ..
	"uwe7G55g+qCMvot6dH7zpkHD/0EmLAorU9F2k8Jodt3YePbub2wqdQHQ0cQa8E4mCbtLjK0cgyQnTZVEep79kcp4S/kx8V3ydivf" ..
	"ZfF5n2KMUyG8Om2Q5zmTxi0MgLul9cw2QrP4WsARSLxMkAhk0g5vtmNGDEsZq5dTsbERcqywuhTMqsDwkevKCGgEpc90YkVLdQu2" ..
	"h5JTLwQ+EsT1gtIYHrP1f50H+SGzT5aFFFvPf2ffB9DFs+yaitHRpyf7BrE4ZbpeeLs2bcqg/KG4oVszzXnLzoCF0gx/fHhCOLS/" ..
	""
local PAYLOAD_P5 =
	"dPHYOF0N2pNuiHW22N8QXsyXqLXGsLXvNBYatekOf9z3LbgNNrMHv+68zG5IXzKCsmKucQhPQ2WJvkWuSPc060q8o6NvygveUwz/" ..
	"soohnmf1Dd+Dpx2y4AQfVD1p2u7VXzPZOZaJwfo8Yh2E0roYSplxiihgSxtZEH6LJdMY5vk14+h3hLP35wBsZ4B+YUkXqj99rb5N" ..
	"E/Xrbiiq9u6Lp73mZbZWRqfAXBEJzmGKZQ7JwqKt05Ij/MILaDvw3LD7zOCWqkfPhyU2Sv4srEisAsQ7pxN03wfzUrce1HGvK/uR" ..
	"qnn93DBdHuEnDHE4QuBhGsRpBNv5vHvkeh4aABYxwslAhA5hZqbwfsk6auA01lXQxh+nmnFMLNugDHlq2blmiiznwOfKt3sWW0k6" ..
	"F2NVwO+zTE4Idhkg7C7h7PQVnq9QePvnYZiZ5C1XN658w3mdBJwqpifPvOdvib3q7LIAvq/H2Ithx7JsYApXHdqwFZyWrFfiQnFn" ..
	"fy36agHR9G9unDov3JTEUwl088qp4lk1wqqOBKs8FS76SkIgQuWSM0eBU97QOW+PNxPB273OG1Pc5UmxXPcTbA+uI13TehAVtxas" ..
	"aBuC2za6ssX9t5OC2EnPpdyF7hRHWSIqF+PkZztsNbJKi7b3qbncfeo+TMq8lbuwXzoCviMN9NDPck7W3CrSUFHw8888oxYcoSvq" ..
	"AMGxwyQONJsYGOMKFufaOwPlNcHScU2AAruRk0eKFzotIzZQxnYCxW7+pBIQ0s1UuSMp1Rb5HiZLZiR0AzMP9eu6/oNpeQtkLxga" ..
	"z6yFV4BIE8U2YwV6G0mG8uDN/2PowMYUQdKl4/fQTTja5odRX7J5XOQK8rk4v+rzcjdjtFlkf27e7l1Niy8T1KhhFBg2vDzFQvjP" ..
	"+/w2w6G+wW4DWVUik1DGIvyzkg7LDuevxMYpYTTcGv2/QZxP0Ckeao5ihTqxEj8Vq2k3vubtdhj+IiVTSjMo8pmMM8G9vUye05fX" ..
	"zpUaO93aLM8buPbsBFcT2uHi4NHbUTEnMwjAuuymVkkeRBV5ijZBcbTTRn3db1tMVhppr/1VLsbi7bRQBYl7gAZ+5jzL2FXsey5R" ..
	"u1MIHLEAd+XtwKixH/W1zCeixiDXne08jcssQaW4SR17mFLKaDzq7v5MzlE/XwkcM4xxX0xM7wW5DhRZ2AhvVjVfpAzuOVR3JE2u" ..
	"UHvbcMDorlyN1QAn663PT9Gj216lZohzDYP5EFNlX7h2QABzvVjF8wOarJNi9NrQtbE3E46s9HES2UCk4HcXOKKtdKlvtXlXHlrZ" ..
	"Jm0gLthAFoByl0YB9zI0v3Iu12f3E54zIpNKGtqlss9DxHXhW6E1IA5egU5K+SLquvhIbmul6vYPV76FmeGam59GutH9NLiLyOrs" ..
	"t6p9xyPOjV0qfHCLLy5PPStzfE66/VWeADdkhX7g2wRLqGqptUAdPhxmYyXzWJ5U0VMUiyBHBSmaDNA6KFgMsEWqraWNGqspSwBO" ..
	"jxGsVuIvq+Q5PWVQglYSIiTGxeGnl2ec+k0MnRQ5Y0L6nDuCJ2ePVP8O64F9XMeSZPO2ORd3i0DSEmLroZOYVmGoXJFAbFxu7LIx" ..
	"jqKw2xg3FMKdL9Gsy+Lg3HQfEbXDnqYweSspOFpGPd88DbrF+8ZJWIG8qqiHv+a1AfWmjRwUIlWmDU7fEq+IJncfoWppqSzl45hs" ..
	"Ntf2xdbMuPv3N7h+xitPeouSydIxrUKJKOhg/SP7agmPk69jizVFliR0LA7/zqIq945tEMM6fS1adGqZs7MgnCwxTfICaauN4PD7" ..
	"tBFoQjLuTnQ8w9ziSK68R1IQkA91a0BqcY/f+H05o9d9bYd8WJOKXSeSp9W5lb4MiK0uIq31r1KsRTmqZm/xpw7UxqudUypXbD8c" ..
	"+Q73WpJJj9TTtf54iq9PWu/GhZJacyKS97WIW7eiZExAuEEuDdcFkvrB3pWEDwCsHUfn92ANkCCbHWKXlfz5Q2qnXPnGi3LftFzF" ..
	"bRBAYOJuqynk09+Pe4Ocgea7HRHX9ywyeYW913mmzrWDvg0Nk8WARYRs5+BYUAzmu/o0VH6WUYLy78Itb23t8YnxcV8dUpzCtPEl" ..
	"vmxBNV2sKcOtt0Xncr30l5gICrgzLNNp6Z/SS/a0aBzborPPnEJoe99PYWZwl6MJwt+0iiZWgPPAkxblOpuUaLtkeft6lYHgcCVW" ..
	"3rXUnT3toRTEQTSrn2vwT9jVYPUJIR7fnn3B04AxKp2ekRnI048R008WLTJ3pO/T2Tk4YSqkF+RfLdeboIczTbeSp9lhNMM67Y85" ..
	"bHxSH6kgZti3xz+nSZNAFlT8maARxiXITGRAItlt47eFAjC2Du4yXl3DOCyneNpxPWVTiKoMP67rhurw0o2Pm5JWm1RgN/OW6EVS" ..
	"RIKbe7U2WejT3oJBRGT+JDJ1y99t/EaPaaraTRzPCyb1WYxuvpgkZyTmMECLk9apG6fZ6Jrep4ULoOdxvnSSgeHy4A5fzfrWG6u4" ..
	"pp6aOd5KaQOemdPqlxh9O6Ibxq7RzwmAigDU9ALJKaKWsUsjinRSBrrc8VTRnwNOGeMOOgSW5q+eZNK6yrgdqytnc9TjdpNQOsI1" ..
	"C5e4u2Nck0qINbo5RCHtpIRI0tkHVqQ2XrHs5tvaIr+YtMMU+miyg4qr0uCDP8KLXa6qFJxpApR/vIpTfdCjPPqm5OlmTJD25p4U" ..
	"TqcNTp/apU4B/T+9lUWOheol3Q4WWmOa24L7M3E1XAi0PrzAzMnhEVodxx1PRrgSdSP/irpq4s69CEyGNg7B6T214keGxNCbH7h+" ..
	"xLPADKr/MGCdXyGCfMw8wEE1mma0BXyNbeFE1A7s3tExd5ulirCo9fENpiHjxj86g/uYmkshP6VQIwg2E5qnYSmcOYlFgeGpW0HP" ..
	"nPdsczfd5V+5qosR0Ydk83l2d83Rvaer8bapFaZ/z9p5iaQex8d/siPzmcjqYnjdiXjrOIHSnIJ3cUyayb1u2tiJbVm98WAEkLgW" ..
	"cg4i/0hl5RDIxobjYFjjEI86ou/2z/If3P9CUGzcSyqhqsHszKmn6ZsXJK3kh9giJCLXi3dkU42JW5LZmfgIDIxoyZ0jmmEGkav1" ..
	"mRV/28yjKWrc8K1dPkyEBylDDsRk0Q64Fn4LUtjHx/rOv284yUlSBJCSVuBpYrBFcj6xhtjYPUo9C/t4w2EnQKWzwXNIm4D3SSlG" ..
	"vqHMCnHEplniKORL3w3s8gfz4TPUsZusMIxOeIBwaip9o5y/W2TufqJyr1EUIv6koZY3IeTcfxaGnl6pnFiitG0gYvU4DfQuXPIp" ..
	"GVYIq6KkQFrRPxa/YQX4KNE+78Xw1yU5ISezji2Xd+vF/lRxERdjJMQPSHemO3SzCN3nEQAcvpxLM7V4D7fMVxZ/Yo5xGui6rncf" ..
	"613zTckuCs5b1DJEqeVhP8Am564GYlBT1QEUBQw1nA8tVKkNpgQLZAc8INXLT65nbA+luIJ6GgpFQZLa3AzgTAepf46X+zroS4VW" ..
	"gwmC1yKyCbFYc0A/lxUOWKlOrwncnxK+P01WDR0071QygrdPm+VBsa+ZfB/GoD7tbHSSXHB7s7pok7U7Ue2iVNzLYd5Xv72NdpOM" ..
	"u+LuimskXN616yZ6s4nVTTvopRhNwSBh4dRxOr7UXl9IRhDOwq1sNFSuPzcBZVXNXUjRFB0OTYpaquCLpTHlWLIa0xAjEPtq7R5w" ..
	"nd3jYw7403DQeSHcO4dpQhpa/y+BTbToHXZqklE2I5kRNS7whzE1lCW7FbzTPnfUPc5oJHbRfa034SnCJUJO6x2heBGJy5ZDLWCx" ..
	"BmSEQKv5UhA74z+IA1q6HPUX3SqFBd7Yp+ICHBhv+kKIABBsmEWehp1UTNFWhXNcNauHjBxpnkh7uSgg2lRilJCtj4KGbRaDoRf9" ..
	"kifeURJ1L0oLHU2+9dG24j8a4MEweeQSf28sEctNB1L4nWC3e/73Wyf8Gwvu8ttkbgJAApo+QvONsF6kTEQ1VcEZBk8nR+t4LFKs" ..
	"wLu1CzyWtS0cZdNQYxHze+GJpk6BdNEI8jFx9leimeQEJLeoLZE9c+/R5IaG8l/c4bjhjN1ev+NXfsScKG7JVnOs3TGUNWf98Csu" ..
	"5QazEZ0WkISaThXtDLbPBy8thJZDn8A5ZOuDhmWQBWIIYkNadlfVIs3FtYubdN5kVDkzwVBUlu6DZQnpzI8XtmnE3PbMAb0rqje1" ..
	"Bp2hMhtLc0SNt3VuPyADGlBAJn7Nsj9domAKkYbKH8uasEYgGXN+WDbbrIh1sBG/EgALOMwWsN1bZ9lO4to1wQLmC2QhwVtA1ycu" ..
	"Gnq5db5GC14duvH6Bwf3O+svfDLcxfMxm2cXy+5OP/uzDemS+Ojo1cNgTwwz0SjNmRFWZcFp9630TeEGrqFv3X7OZNLGCeMQ+ErG" ..
	"4yGv0kgoeMjHUtn2JUc5O/WJQGQ5hGzfTsILkv+MzlOmK89ZYOoveZfssNmE4ZPjleCa4tVHONhWHiczEUgrmW8SDgnVG0UEXgA0" ..
	"LoXvfFOoHDoNgsdRJgUSxrzLnKQhf+/g4htsfDKwGkQn4t1JG6NcADlwzZVmhssMXv+frPXbW5qZ6JEJyrM4pEQkwht6sXJy60GZ" ..
	"VvL2vlR9UNVUVoIbnJZa5CrfnvUs/dqug/lI7WamZVTZZxep8IkjAtRSJhFtCeBKginmoCq1kjcMI1HyLcJ71wpXb/uFo6fZS30F" ..
	"aA4Ja/ONZz9Uch3Yt/vZoCObwgPyaCLFVqNFLbl7BGvd/Uu+qQzs6pkfZEMuIoneURSWwM/2XVaLYNlQsNzagzv+daDfswrk8rYc" ..
	"a8yhny8lmeaqUuabk4MdkSjbCB0XbBdX5iPUvN2bPZGHHhMv5sVtcUA1VoQeiE7gyC7Q7bxhvyqC7oyqHYoq1JZSI9tjSD0qM2uD" ..
	"ikWHa5vl501BKcnquu6eU4teHmoAmX/pZ/7U9Y/me36jz9eYNXvNW9Ylu91/iI+Xe0pUK7+zc7i9ABhpIZaHqeL5BeBUgld4AzE2" ..
	"k3R65bfV++aFiD8n3TRvgx/XzLpP7rVfQ2Cq3SrCjME47mW5ybvy4DIa+DR48g4Pxw49BahTR6w6KHeEwdpSV59BdjQ2I7tdu4Mh" ..
	"jF4XlDDWC+CHmQ0o6TYf9Zm7jlqNoxcb0RHLhhmr4zLiSMde8TaTSqZMuzMfcisnUEEKaRjz7cR9qpiYRjNOzLOziatMJl7GZqcd" ..
	"UR0LS707YcQ1i/o+7a1WulhY4YOtTTYNrz5kdnCZOXWVHAGbeN4T7ID0LdAWwEnCF60DAr8s8SOkYtWMoPkFiYFhlGjheoPjyIvw" ..
	"fIvaG20I0jYnOspf3tiyHh2qH7hxk/ieFfnBUQDkvNCizhG5lj8/mtU3d64qwv/oyLUbgVpmWbzJpUEpVn4iJSkzG2ReJO6gvGi/" ..
	"foC6khcxoFVpVmS+z0b4PwRuC2cYkJ8mGrU+BCENhmjK2zAOtmQgqp+dEnvuD7Tq0gNllMl15lTOwRmMrizg3knmvMqMHhCqNG84" ..
	"x5Yjwe71DGzZFJRxcxTj0O86BbNwXFjXnEvyJmkIJP0R2TuDhRx05gpL8kuwxZjov6fofs8RP/FfQi1vd4BuoKfjEDbooxj3WnFs" ..
	"6AQ88JjAC2IiUgm49sMZd5eOjSFIjadUoT4xF0oFD5RhSaq1HUW/4kxkhvMUBJddxavVkVWY8dDyMbbNRLvOWVDxCoPitWrcyoWE" ..
	"/o+YyrHPNWUGh8IEQ6HTu2zP8bRg7J3KJzGX82NYnZx7o1S5OArkxX69uGPRiI2e4xkkEuhJ+4YaefmusmMXpb2oFWNlzv2iPEva" ..
	"3Q/I2pTZA0259FroSwAkd7Yw/caJZyWhDFQpPc1qV7rvDerGTNo+KNM6WO387bGVwWYihZx2hX7JiziKWiCVSpXuoKDNMUd1uih7" ..
	"jp8Acl5+NhNfObk7TMH8/Tx7pJSYLkcmXRNLmSo9A/oPI2IZS+q5aD6bDFWpJsvvPqIU5zmvj12lxRnzZK00/9BrST+pFZnUJO88" ..
	""
local PAYLOAD_P6 =
	"5QTLA1JC0g/3TWZ8w0yDXWfzB/ozjBEEhuIJq0hBIUUKc44qEAZsbMIbHSDF7HzyMxptaR3132CY6wZz9Sf+UFqmTlLUhdwVKycZ" ..
	"1SzQJE4eyMQEZm30sh/mK8DiWvxL5KNvDgzISrkTqklLxu136adGSsqkN++HJjLLwu6Us5iJxdXmUx4vji9Z5rpwe4a371XoxGHZ" ..
	"Gu/ocBEYndMu5G8DVvZ9rGSJdlCPIwitd8tmI6BUOBugEGMLeBVqfUv57Xrzm1SbzSw189ByQBc4arLSEtw/vNFDAZUbXTRLwNEk" ..
	"62rcb0L0B9qZGnqKd/bXTDNI6QjS4sSAXfyK69i6hGsaGL8LsYjjpoFnQxz6lIInIMJCBORwt8DnH5HlKrG1QQw6ibLToak/JFY6" ..
	"5PmCN30kenw0yvETTFBT6nI/iXzD0090SY4Yr/8gRC42A5hFVgrZA+uVVKDKva2gOFmmjpwq4CWmts92blqCKRL4x+6rQMGQj4tY" ..
	"xCeKdXY/TPEiQHvX3gMfXWecSrDD1T3Qt/SaNgkDusadbv0vwv+WjicF0hsj7eY/Z4Rf8AgWipMQom9ZFsF5KZoYm62LCKRYBDp/" ..
	"DFGSNYHAlVSjE4AfQkrFZS3zSzsMKCTJluo=" ..
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
