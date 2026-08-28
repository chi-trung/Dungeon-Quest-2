--[[ DQFarm Loader ]]
-- Licensed to: GNURT (1 thiet bi), Gnurt (nhieu)
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

local DQ_ENV = (type(getgenv) == "function" and getgenv()) or _G
DQ_ENV.DQ_LOADER = true

local KEYS = {
	{ seed = 255008992, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 256590070, exp = 0, plan = 0, hwid = {} }
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
	"5UXKoupW/x6s72ixbdfqqjWzyhEEIHjrvLl4vZHBi7U5wb8GG9zP2lh0ISebYGshUkUCAlMiWsJ33oPQ8/LmPr92Qx4ZSCX0Gh3b" ..
	"Qh9rY8YZ5u7Cr3eUH93724sAFA8LHNN7lQQ6bwnRlod3YQKrelaA3fIVEmv6DUjnpJREVYpslpiJe2HXHeUAcI8MqFo4JuDMjFS2" ..
	"aT5q6M2V/y+yPa7p5tA4tIERl+AVQC6O/3NyzKAW2iH8LxUTgz5DIlNtBlVxZ1BoFaU8R+nym8Et1p8HEG2H5vBnLNV3+MCKDmks" ..
	"+LLi/r/dvus8A0kgW276Mr4bqeahT+bk7Ht8tuqyAczGGfGF48pKB/d8LHYMV/+88dCxtESP4vbC4V/9PPTyRhZ9uaMhwfG4RKTG" ..
	"F+qcl+DZkzTPO+5Ulegx6gzRqc3cYn9fnMJyrNaAwgUSWHXbEZmO9qlO6Sa11RUC4/jEMYMgdNCADfrMJC6drlpaauOWKpiw9ZY8" ..
	"uy9LCiBstMWyy+3EZ8Y+VHkKDdX6s11132IOH5RIP1HUDYoSeqsi5URlY4PCe9B/PHdp4qku+/Oh7nEhMMyHk59bKSYZERmC3hVf" ..
	"+vZYQgMuHoxS1zUrybE5NID+QVNy3c9Q7M13nkxtk9sv41sLiKGCfwlLb3ZkcSq9BLw74BbJbDkPWfQeo/OoKdJLznD2s1eIX+Ql" ..
	"Mu2DWuwYZBMwIO67g4ZMcZ678CZHdzwlCkwilnY8qFAyBFVq0CuA8+IB5vUZlPmQQ0b/p3ZtLiMiUDAhvin0j77d+r6mjgXbQFsD" ..
	"mpjoGKcbjqdqx4oPOCxIKQ2GjxUkqRRUJFiELbnRlLg2y0CHBOwfhem8oe9cKO+H8SyECiNBQ1RoTHufiZ2oUj07p7sT2ygV3t4W" ..
	"dR4amIai+3oELfhBSEjBq9jjXCrr+bSQSyBFkCC5lcEzN1lmwpR1XVutBbShRdDpdNTRJliLZklWW7BI19wv4CL8jcmwGly8nw/b" ..
	"BaN/yq7JV7wxcQY9AD+DQp993ADh61eY+yxgbCi6KDhTLSoI5cYbPuJeyxTtLhZi+KsWwB0RHHOGjU8ePyqX/hGXHpKuSbGJxmzO" ..
	"Wzwj2qaZ3gXMXor10EogbCWuMJFDIwCs6BxpSYlEe/u6Dany0t4tUHOn7IawqkfD2T6XnQx75b8eKrfzEm/0JJhPMS3JOJGBd57X" ..
	"V3RpJB9rgHoOBLSCrfIo/H0pNnHymC5/REInyMtDKvRPD+nRvQ0WOAv6A3w1gNjdITbQrA2IfuMgBux1/HL8/UQtWu4EI0VORapk" ..
	"S9jHo1SfKFR91gj39HEyeY5GLFjb96hCL8xGSCUErNz/s2pQ4ZFhPg5jKh51mmCkYlJRcX2nIUON4Ihxi+cTvIKQ9G7DHp4nOvuZ" ..
	"LiRJaG7Mdv0om+PzqMgbrMANG9hHNtkdtebSh1ASsqPZKwFFbuhXEDIpHnYB/UxSQjsOkh8r3VG439Jscx7NE08RfG+/aferjt5V" ..
	"uSF0dKEayFJZywVmBA4rnI2mL6bjgaY78YnY5RWfGicvTFpPRA9s+zk0OfxW50lTyyXEsknSoiV5BayP3FSEb9scs5+0TeANE5SI" ..
	"hhZgUlchXR/H8SJuk86r9RgbhqZ23d7NgRjDbLpMBkLdmJyRqHREVzWb4MgU9Yle0n8n4iGNH+19huedhDlaGYOmeQ3SHqyCHY00" ..
	"zZg7lidV0CzDFDDFFCH3ERtDwOOpM1pNcAjsz871qOBPIWudS/hUjVECM/gdkmz6OTr6KkVFvbsta4vrzpv1NWxZ0RQPrhRnWi1j" ..
	"7OkjHC8zWKzQZE5y7fybsnVBeSuFfwNrWsmsrtulMQ09Ojw2D2A6OY/LO55XlAw9iuu5hqOuTQ6uXKwdo8LV4HL3gSL59EVCq671" ..
	"YerBRqXhCfvg9CiRFJoxch7eilVp/xxfffWtTI9bGhhpPM83s0DhTb1mEaj+8Rmdu9e3GTFRNSNXRUv1zKfV2Diij+HnwAp1lGRB" ..
	"SsicMpENT0xsnJvCNSy3+wzWJ9KHgu2Y/8O4NFumczyYskz4R46A588fkr+xBbP+qNytyRQxMu+LyAV5nieBlridESUogFOBL2wu" ..
	"yl4gVsYit2MTdkavDqEswV/p2mLkpgLxqnLAptj/qgLXBstTZ8h6OAHP9hLYfBiEgAnV6kXqYIuB8Y49J4MMfg1DvCu7INncebEb" ..
	"sZB5125N07J5b7AxIxQvrF9i6JSeNq9zn6b4Pu4UmuYVN8HwCSsbEB5BnHUfA56eRRa0Ln+vRL392mm9lnSsiXNrh/JtZFe10paj" ..
	"d4aDFh6DcLSo22YR6vR/igPKZOLxPDlnjXuw4Rx/y/nuoLLo1L5Q+jFf7CPuQWUXv2Y7T356vxZNrUgoAeLAj9zh7fJrsxUXzzgR" ..
	"lgoMAC/pngb1mq2cscypCzOb+TKUo0IsrCI93g2efsdYVNvz4IE0Q+izpfUqSyRI/WRQab/Z9hh94WeDyQhFueClw4rXsENhg4ol" ..
	"EM6toyimF2iKCwjemgP33DQeWcXDDAx69D7OatkrUeoaLecZWLa0/XJTBoSCT/W6ofQJHWx/8l3PFPQEPOif3z9srFh7b/3Muq/0" ..
	"JoUFE+720rwgsiN+GaVtp6GZ7bFDVU7ab6SLwCNSrvMTBhghHLcKFKzZIN2ttW19yranFEFvqEK+cmLOkb1ZgeyJzRVoKNcYKU0y" ..
	"IuVyKaeEjyUPq1iyekz1iuX2FEJeo4OUdA0h1AITJHUBmCbyEZWrfa5uEQfalnBKmJGpUXuU9cZv+hmHMFKzQEDJf68lYHo+GQNe" ..
	"pjyo5EUqrnh5oh1kCkBFcjRXePhLpWCKxI66psh3npndQlKt4erxLs/LjzkcN85QYWHZlxKIj9qmxwOidBV3cc+K5Ly5zT/BFqGp" ..
	"PbMhce3aa4+ErLgLQnXQvFaf+/uwjcu5cRTyViNLhgULn4P7iuSCTEol43bCrWTz9jZSeh9yaKcAe/jKF+AmmAkv+/VkyXNNQfW4" ..
	"9YJwhCLPaaF4FDCl6AIWOgkXodPznVuzNjnSaERcubjaMMNFHkj03EJc2RTe3MQ/5j1TGqbH6Z1Bk/Ci50+P++dWKLxZDBbT1tS+" ..
	"lMS0izFbsUp3c0Ubifm4y3ZssuzMQDtlKIZVlrWcHHzp4Ow5YCQ5B+/U6N8d/cnAjwEgNeor2AX58rc1PLCwqeMjdkqEW1iLblOv" ..
	"LNeak1iABuhk7VrtPn9W5R2SHVrLwJjXCaHQCf93iB/La+/NBeR6PnR3q1EFhkI9bpX1DLBIcySNDVUEIe8GlUK885Fuim8gYfdY" ..
	"OiwFEczcmqv0GR2g7s4t4i3/JcUm5ylI7cIxZ5n7OOfoA5AzXJQlFah5WLz0MqIwYMzHMy8m0DvskYJWeST8YBQq/L0f0E9/Vi7/" ..
	"uxf75UAplAf0KMQPmck14ZeSdjXsSoU9sSmO1g1AmGy3lUBSCDmTGIPJ1YJ2d4XkcBWtq4hq1APnDqZWGqMSn22jxMvd7vPhhX/c" ..
	"geLo5uC4gU422BUitn+EJVTmzrQkgRrb0/JhauTn4181X6xt1x9dNDyzQZeNHd1RKTKe18J9JqmajQYMNtudYNLC8TVxuPYtFQqV" ..
	"D2jYnymmlDpA6o4UZ2D9pt3QnUpnSZasuE/VadWecVMPxcn99Sj6vbZq0z9XR5OQaeyq7+JVO8z/qfKUGb0zY5qLXQH5qUTBW+l6" ..
	"GzR6VDUYRCUEbk4nk0wd4W+D8SCLLn/3HnSRO4BXkYdJxZ3ldJf/SQBt8HoC9t2tfXPmjytgeXSw7um/vuu7QcLySZY+bGJjDCJU" ..
	"IKzuKKEU0U907trKmI6DS/9nh/7t1/G6BWqKDh1BWlTTGVC6Rac7rmJQnmPoWcTzJZnTi9dYUrP+RCwDnkRvVoMyMam4EbWWGfdW" ..
	"Dpj5H9lJWb72ordv2H3ke9imsZpzXmM64Mlna364fiS5d627OxHlUMMrBhw6hbrNTpL9htu9nCr/4XSh27vtmKIp8Ya5VfTGKfAR" ..
	"Ga6dZPPUnHn5ygxXkM5rEqh1o/sxw55hxPsSgYtl0AnnSF0PXp4PD78OujhLimgTlV2503j5iAVPMtho01K+RyFi5KwKX3ViNAXY" ..
	"wGYOyGTel2qwvEMhFIgHcoDW/wPbdmUyE9jEjwD9J2B/1022l1mouROzXrTsgy9R4u7+kscxNbOM+TGzcxUXDj1VZXGKYshuLdav" ..
	"W5LiQ2feMt0857OqnWl0vs7hZZA5rQarhsEqn5vu9f+ckOp2BzS4gm82OTIpKc9LGnx/3juA6zjzv0fa15CXg+mUdvrbyKDyPY5z" ..
	"R9Ypgil/aKgOMVPmXMPr1D3lerQUnG7EV9UE7H+rJyuj0tFQ2eW71kxSP/uqaSS13LHgAq7pFOfVoBNMJST71pSp8J16HAmpsp/K" ..
	"vfSp3mf5L1+vd5gO8Ll/CfFG13YC0lDfawyRmCOE1CHx+dL/lZSQ5t5NyBCrb0AtnGKdwQvthBsa8exGWz/96J9UdJ3o5bUFPZMq" ..
	"orz07dQ31kXu9X4renUR+Wp7v82CCoEE6vRH3i5SlV+XMKxZZ6IKNkMd1ygua4/Q9vecN4uCg5GCTOb4o5a+O52ny6gGrq3ZT7qv" ..
	"9HWMuZSvfdpByyrnceowE1aCS2QSj0iqWLtvQkiphwkvJ4OW9SzvTEF1oJi+339E32eWJHB4iysiY1WAj4o5oVVuHwy0M4inWFgH" ..
	"XNvkvi5v+sAL/ALvlx3glu5YcmIl4TkRchdw7ySiOF3U4hM2/gy6IKthkPBc0QRtlL/0Kvc8DVXJGiIopSyQL9fW7xyP4KQlwEek" ..
	"HTNQwyAaT82b06u7ufcW2xTg7iRqqoPnQiYqLrnLNIf4dUk8F+ZW/FRXYWxOkPIR+c5tsOsJgjBPF5z0Pl7mQsvo77mFCMY96Jdt" ..
	"4LYtUzLW2xct3uORAhYHpmI4Ie0YCudj5fIDyzhFtnrFn6rGvkDoZJSAF1EOsA0Eysm3k7KWGwglPpEsM5L/qxl4o12IgGIAMtKA" ..
	"Vn/AdOBKfPoTHrbQVwprXO3Uoa5kOYj0Tm5j/8U477SpKLg1P21M45Lw5R65GNPewtMT5kJdoAXPj0z55syta18IA5nWmruvX4Sv" ..
	"xST/YiirjbXuVBlGLWeECFWAsi42n8oILVhOSKhnAVVpUchdh79CZrY0ohUGssu4DAeuq4ZxIJ4ikFCk0uy9wOro28rIVr0y2cUD" ..
	"qcqzLHqx4bcXi4o9D7CRt88IJOyH9pHqWAuFE9e3MkAz6KvoCtRqxDU04UkAYlQ+AKp5R9EGuVimvT8ovcgpn1C+X/VvyfX49Pgm" ..
	"POYOLEFXi0ztfq7ZLhSANLKk1zyO7qvdbBUXj0nJUDYy3i5Ko/zMBt1sVxusvZ5TuKxnscvHVAJeZx3TySNSeHemZ2FnZYSf3nFr" ..
	"tC32URk9Ayt6bIJu/a4bx6aLY2IOC/VLsgorQvaBqP/+bjYCUD701FP5qRW9fxDBJQAL2G2mAinEH3Iz7zT/OWm2S0keJrI15tCM" ..
	"ITgXD9BJrtH64UhcWjJEuA1eIqXizUIKV9TiCP/031xcjCG5RGEIm+1FrRzFAIExAgCvODNVOWGWKPJplY1x+1EBlgLMwOkgtK/q" ..
	"Som5kSoXc7JT0uG9xCXEbXcN+yyGN8hsuyYibE0pYCYJP1L7GMzBnSraHn1l8fdGy7QSli1FOaOiliMzucGwLbmcM8KkalINdAqW" ..
	"LG46n4pSydWpBhX+Q3b6d7mDOHNSajjFIGdN1BtuBaCucYuqU6W+xLgl8ninXDClxVJPnUtIk99SL6PojMnmkUcIBlhljDMX3Zo+" ..
	"8VsweOm5fkwf+3uXBeqytSnedvrapTWUa4SP6z3nBUA1GXyNSAvH3/pmaC8XlfMVAqcKwIwtazLwgO/lz6Jqet2xXG8rUEbhTsp5" ..
	"//B+fSBgrKS8jbAs2kAThX6AzZA4xl8+mhq3lTzR53gv10BBpdTRoLMVQHxpQyn3JrootiKBHWOGSZ00ukUSK6DwaeMGSfO0VFb0" ..
	""
local PAYLOAD_P2 =
	"aEEBPwEK13PSbq7Cg+9GkwuGpu9+2VKBP32Vq1xUYWk2pAPIaW+MJMGd1/wZZMYjWsfAO8ivcDzAchOxak1/s4qk4KZ8LqLPaUMP" ..
	"uWKD+U1rMXUE8oShkU9elUJZD3oymZdv2DR57+19ag8lXyt2Qvjk167bdWjU356AJy729bEvbJMM1jIv1dE0tKSyd5joYVUbcDDz" ..
	"JAEbrzXixoKOvcs5ensvs8/9XsmAju0QLDANOYiO5s7qYwYF9pzU9PPoqnvDJU3J+4YJZNBczNCIWYVOdz3mf09YeM//KPyqnj58" ..
	"NpVk/6v3bsoLIk9wYN5TYvnJuMNkKmgVR9x87bvv1lW0uMOlrqtMSoaO6kJlWlnZLVeVfnOERBMaa+pitSx0sZbSm0F9XJHGy83C" ..
	"QH6H99fpu7d6EgFB6HLlj+dmbUDq3zyzcvcIGGSdWZrs9eOyI+qKXnmGY4FqFoC11vyfmtRtCudjlCXqg83IN+J6t21ZvxYnyWjB" ..
	"DJA9ktup2l5gw1cPvr5czTlBCZAHu3Ad1eEPOK7kvTSvVW/GKhxi8+lWINWP2hbZtAQiixK4GcUoa6cUthPtLHa1Bg14EJoZIOoQ" ..
	"F7C3wQqtuhNP+Q9XLz7U+nCMppDi0rarU1tUqJNiswLI08FnyGJZEh3bfowrHeyy27ze6ZfglnsrrY/BrmfbTuRgKDZf8wDW06NR" ..
	"FAEWaTC3JLp5TwlYQMDDNpfULj41guMSiuiBlnA99/DmM2slkVeqzDBMGGMkHZGYIBIHBPwoPH5gAGJ3O/UAvuLqk/vXHtOWBCRN" ..
	"X3Z8Jqe6OnmnSQbEsd+jkwLM/960dl+UUDQcIN5GtRxlNU+sjCIsS8qD5cDZfYo2xlbAFhsCJGX62l5+0nPzMLPU/93wa+pIENwL" ..
	"tvetd4GLkdNARdMUhj3ExufYE2E5gpMPomQIMP8f7xFhkJfXjHTlDlAWgfBZoLVl8N+ihftLsYWdxARQA67CwBPoWdfaLYT9FLR5" ..
	"s7IzxXUKM+YUOHNGYmNCtqZC7p3VMau1BguuK/lkX0/sDMHAeq0K3Wi8v37c1gh6uSCfhOEBMHrtmDWoV3MJENk8NGR4o548NGw0" ..
	"4jQ/L03GrWQ10gcxX64jFBZCCGhGFnBP+v0mnS/SjRH1Qlpq1oVXXNuDpksmDUW/C5XCSzNaySNZ/jz1AUj8UqwQqR+zg7rwwtA8" ..
	"STeWf+YAIIXfCfFYgd+ek9s97rr474SpnEdAS+Uexp0ukjuQ01YUpIByrHQe4faX+095HB/m281ZJPbFIi5z/5vO/0o3KNDvLW5M" ..
	"uFOtWau9EbgXKhtAYteRsOSY6YdMLO3ZTg9aQSeVEZFDFXk8DIcnHbBmIp6hd3wBWDFJ5p3YzA4QI7GhYthA46onQXzTEbhCytBd" ..
	"H7HoBHTn6y88WS7DMHctOmmi6vv/Kj1DC9u9PHfbH9i1aO/y0VoGXgW7bDHeKSaUr8x2TE/FxQg+Czi0NhH3yZth1SL7m2Zg9AZw" ..
	"Ng4QtXm1Om1S6+ed6dEp/TtbU5IcWVvnzrH20aWABb7GwNvmTdnrPjxBVueLXRixMGu2+VXtQODCiwQCpMAqW0yiqQctIK0QMTzo" ..
	"bO08hyP3308mxMQ59uO8IKRCIYg5m8dBIbj9Jo7ZfgCRAgiwakvWjgt2TZyTgawCJmk3k+ZPVci/H5T+GAMTQKbgWq1disHMEHvD" ..
	"W7rDRSPSH2rJR9rIQvZQnRsVYptYUeFul2vKy9oJibBo++EGpzVTeqM8pOfLhQpGbWcpS/fBvUqv5pxHwgt/F0++eLmQdTjbsq1J" ..
	"yW0eHNbekKoycDGeka9XeZ7mKxIkFlpLmqQiTFpirjPJXcrwQRN5nhhnC4a7YpKm4ggA3K3BK5O3RE5ij3s3Yj8DvXU/eXfi+gkb" ..
	"pE7J4Tl3V27qW5h4oQNEezuAOL9ih6ZvFigtFHJLs6dhHWOQMlogYbauW6A8KimURoXjQ+Cl+uOh/6crxtVXxHaBr6MB7oxtFwCy" ..
	"GxCfJaKnJSksgHbNvL7sIqLS0rSI6Ab1vnZe2ZN0xoaq7QhonaIPaNn0kJBnZq9cblX0A0vgDsxH/5gXhc7t+sIWDRBaJAUK06IO" ..
	"A8FqYk3aZELdKGgJVPpZwoo/kyoV0zje1DGKTRpD7NShjVlpwU/Bt6Q+OySNyiCJ4gbZtzF4HdnGgk4Y7qDAIpJucUDrVxJvzJnM" ..
	"qJGJNA1xng76sessA+12VIWheW79MmN0fnVinq11CECuAMTKO/ODWhXEd2FF9Ma+OGisT310iQCts1HYHc7cW3zBSJzZ/ZSo+KWA" ..
	"ipCubJXxD6KH58V3AwWbve47W+76+9d+P+1dEdFCefGWysc+fHIaOLCrNpwMxO+OUcVYZC+KXXJGqNbO3BbCnz3s+tCIc8lI2QPY" ..
	"yBboJLi14Mqf8RpzGmeVUKYM2mYnY7PnYWoAkgqxYUqxaqVmCEvZAESDrEh9dsrKwrqPxAQ12kDvpyVJt8BdIZoGzPoNOmH/3fcP" ..
	"GxksOGSivC7YZzyyRpNbeUF4DQ4vVBBj9uvHm32NN4SJTj6PzPjJ/6Q8mAz4FG77gNB+G+udHvC0SV0Yg4gHCBh+QdamObnH7ueI" ..
	"G+yA1wuQrIHi8U5MxNkfObwARVkRlUUvJq+UZtbnnM3BGXs9qp3st8SJcNqF+VeuQVPVv/vRPQTKhFLewgE+/QB3vWCrWzeBCUI5" ..
	"/9kTIpUlkvpk+yqRClAhox+igVl2A/W6+9lad0fJwmEhihxrefCOJaLGcZla6fLqjWXRgccOzJq5vjkFTr4NQ/GGlHiFkm+hBxHd" ..
	"vTBnwIKTp7nU7+hmL8RFViZe7On+QcjpmDZicFW4zqR9Cfrda0opMoKyolw3Nx+z1VbOVVMHDxw7X3YEgaIMhQKAWU2Nfp5UTn8j" ..
	"1SW1ch9WpiAyBCUs20WXAdooAviLA8qyBBCvMu0rikuWbnxex3DiP5NNC4x4wNSXF7LVw3MHkJFiTeMcbVrnEs9fWDl1J1mvM/JC" ..
	"xkOll7IDZ/k5ovILSPgQwEQXO9c60+eVmSGB1c4SbHP/BPYEGtUgCZHJ6pRQsWTCjeEqrvSbjrWCiMAOtWPds/zlHdx19ctXk/d2" ..
	"qTcg+f9iD0v1sw77/Ty3FyaktdJwg8NxpXt4hc+jWeLzDwJocuQJ9fYAA3vMG9l4mXsm8hkLXs730GFzIWt5Ku+qW7x8A2N0IkZM" ..
	"Xq/BtBRJtUaYoo8MmWpzojaiU0CBASK7HD/5iD/O4t/0brVWdJnKeUK7s/z+gDOzWyJ4qqudzbejZc5aUvmr46Yd4M3WBznMIaB/" ..
	"5urV+5kHuaF1hnM4cq+0lywxXW0Ooj9z7PNTLbdyokRsQTJzw/zHCvfRI4BCvAvwNsRbWUNVAuFlVbZ/EljYTRjwTtmnU3Y1e/2g" ..
	"YfG7sokGnfRytprCZBU271KZEtOKj/RUOz5sxNbsUiLzBql4j1y7u/GLul4AT+xWnsmHra0q4WxLiCIqXkscjlXz/rJ4/O1RlSz+" ..
	"YLLAOvRYQt+tUEr2n4DF1+Tfm4AVUBXcfG6DP7Be3AeMc4NFlYcK3n8mK2bMD+byrYGxQQqJDjXSYrCtlGgVxSyVN60XIHvQuQ+b" ..
	"Cdl9ys54a39eaFiii5VbQRt+d8fSY/ykgmkOZMRCYVhFcNlTWWQcRvbm+KL+7DteGiO1L2XAJg19RutXqN6l4qOpZBhSd6FRbUHQ" ..
	"49RsybWsZGTi1j9LeQyEN1sFsoCHXGJPHteOohqc9tQve615FQFqtUYLBwRIx524Od6AHeH5Ju69KBFUucQxSFPK6lG4f5yBhRWS" ..
	"YHlM197FsVzHMmun6LvQ1wzDF02L2fylc8mSa/AdmcgBdPTCbSosSXPNTk6uebi1VE2YpbcPPsunlXl1StjOkB9ARtC9Hj4YbIZu" ..
	"sraZMV+ofxntBW58xFyir8Ohs3Bmdnc1A/nU+UkkTgbiMXGMZm2yKSIshQzpI4zVz5nBUaMf9yHoZSoPkhDC/44mR/BbaNx/NIA7" ..
	"CeTRTcDkhZtmBlwLF2PUaYGTtobCa8pY1sfOmemkldVcog/TMxcvdHXYtgqlwaL70jCtNZW5xwfONcL5YMsUcWMDUXBYr5OJ+rq+" ..
	"n3y+xkT7mSh5AYLU0b5qSjOMYWdNs+fiIigYXLIHaTwNxnVe0ylvHisXcJ+FVsSpt80PuGt3Z+P7lw4xMnxjAjg25UW4Hr+XYttw" ..
	"0dcGlTlggmcJU2BN5nhqMBcwnkEuGZZzT2eO4+V47dDbvNhpMBQ5YxG9YbggZvhHgllXmZvqw/Icduylsum191ICNPJ0jfoK/aOW" ..
	"yiwdqlBdcDeBdnd/OZKgYg/3x0TZOAzDhxcih6fZNrX2XFM9HXE0c8EU+g/P8+bQnHFfbZP1dRgxeUWBb4YYKbHsPMWhK/hmQrY0" ..
	"uFliJZ83VUbRxWWhz3+e8cRu9J13RLaf16Pqsy8Gjq5CywYRkXfNJ6tOldb4WzT6qOdxQ55OZQi7RNiVtCsG7jn//TeNDbqc16wb" ..
	"Hp3Rgb+SFE3s7n0HfLOLhdgj48vISBbSM8FLS8UlvHFTEzztBEA9Ntcdy1c5J5GWNFVFN6wR9pZHYD+XRuVkz94WHHP3XkVvCGQP" ..
	"HWlGFWjdT6/GVRGel27V/fmFhV4ptCJgjmHbOHLZW1rhi47HvojmhPiWn/+auXvACSaq+/Ui5aeij/meC6rIeto44g6/pNPv6+G0" ..
	"r7uXjowo9jtvkikGWsfM5nB5gdN2yXKnlbSP6oRCTd9at2A0KVsg0gUlJCtISvYurab9uSHe3rf0BiMSJz3vA9nPYVNOw7OndVsh" ..
	"r9mpR9vXz7iMok8vABF24fx15vzwksGpZ/7YE/gmFUx4xwV5tu2f1CQfewx+EV9EHONZONU2oczcT7tWxWrJ+N4rVK0ALrSv9p17" ..
	"3gvUdks5u+8gkG2GWJ+swV9h+bwwOW+Al+hS6zRtVEbvHDAGGDVmuAJuL7/JadmOmFGVypg2KBcL9b2+MBhs+VAWaOKfFgm2MnDM" ..
	"op7hQsL7aOIJL+a02tfvCfi6JbsZzuPNjL7j8ZTlmu+n4QEJifaAP5HFbrG9g4fkb1q7diOZG89O7NgsA9UKbLxZDr4BMNs5SFYf" ..
	"9AM8hrswhEoHIP2AiXSYNDgU2ilOP6TUrTab1rR1wXIZkY5qVzw7gTOP3nh2I5VdDvKtaFPIubVvIsDe1vEfgoNOzWeTeVxrQ7O6" ..
	"Q6IX4cUUtVupIo9dQLOVc8tdo6UswmFG0HYeQk7+WP68Dl8Ljo7RetSZM/HGH12PLY9xpceOWCrqc0ccD3yVIgdIQWpupjNSGCHh" ..
	"No0mg3NZGHRVIJ9VlXn/Gs3SMBkYfg1+q3s9rDTh8RBO71x7Vx+RixhkbbDC/P4mnwurwsZGWHcjgFRdNJe8d/JBK7A1kUAajcCM" ..
	"Mf0OwGb60Uc3EtIcvFqZV5uuOHeCnYHhBBpy44LxCgSDRHarQd14qL1sh/n4DqMlMNGsTXlxpDVfRVlZe7QwmRYwSfmiSrE9ox7l" ..
	"DFtOadV2mib7C6qIQwuD95C730tNssXAORwJXV50nFUnAOGOKzQV17U8jbr29wjOmBns508Ei/IhoHX5KHsmmYz8x4WPkulO8hxv" ..
	"aysfIFnrWS0A/IrNuUQk2gahqm7MWLue6ljxwr4HOEPvlYp+2p+s2HAWIDcrZVQk4CSy6nlig3A7XRR+d9e5QwUbSAxZzvPtB+oW" ..
	"C4+TsQQueHoy2Qhat3dXTxPOdmJsWlJDWg1kZIa85PYNzGcHBDey4d80eqSmD36e68OoyzkA/MNYsTEzmGdoCJOHmfi57pf6cRJx" ..
	"z3JiLhwPZC+b6TttxFwb+ndz3NCSFnvC5JlOMi7qcwd/NH0Su4MuQE1dZOqM7JEBy+8beZT/mP1FhGCvYnSKBU552VZy6CJMB4Js" ..
	"2wTcEOd6XVqTWn82FiYEKHi3YlPZi1Sa1B6h6iiJyZwNUij5RExLblxT9ih75aTrt6HvZ3+obKhDBrk1GJZJf4W7J6H/10ZP17nz" ..
	""
local PAYLOAD_P3 =
	"dXL/C4ndxF4GVhnPt3vUz8V/vb/4Y/vj0Deu5gogp6ZYZb8IbL8N8JjFUp8jWet8BtvW6uDZsPiKb9Sz8APke+1VzX9ijWHDJBOE" ..
	"qHDcBKk1ejvnosRGoCDj0Te0DKV01wxd6xmtaE8bu5uXMqjKshGF6m2czbR7y+5Tpxd7xFw/IpIM6skEP/xsot4EtoIWRmW44Dcr" ..
	"AX+Fi1Staoq5UP70SHmhdPNJoJHP83AaGnhXmtQPE/mfxdBsFsH5mwP7NsgBx9BRgpGQphDXY8xUE6MgDXUKKlIPiKWNHlKceBNb" ..
	"mK3NI34VUVwxB0+ioGCBxLL01ye5N390SqK17I6sz6AV8+50X9s64fmxvoNfDvOAqMf++2QzfjMyOEyupozENXKNN8+fLT8gOLn0" ..
	"+P7a0COQ4ftYtnv0hdn4K4b4d+g88x0DiE6mZ/Oa7dvvo298KxeQvYAH0GI/yU0mBrSRTbN6h+SYkR7FKQKgf8QBijq47nlzUaCZ" ..
	"sjkhJ+BqandVDth5LsxoTNaUV4LRItGOqwacKHoDORQh50zgmwQshm+uB7oiGHkzwaDqSo4O6dCJKVwll56WSUMSVxyzmdzUw9Wv" ..
	"LJHuDjnRk3EjuZA5NU/MPkhY7cMMwJKgwKOHsKZ4mftiauUfPwWnmPlXYqxx5roZhMSqh6xNNhobe4xL+1+4zR6xkZqWrIXYr32w" ..
	"gcerlbFuTfzdEvBRYU/cGJJughjBV9Tec6m3QMXvQGxrihS6IDIABGHTirQd5NKW8tKt34HY/5LMluP3XhJzgFGIROST3hE3lInR" ..
	"FnlvDRdLtbxRGsnk2AYgM8nR6bPbEPK9rGy2ySrboCPYgom+D6ucNynO7eZYvdT47UQAzUx9rnJA+kc6AqDsziIEz9HJUNVmAHmQ" ..
	"wclX3QEz1PCYHs2A9Z+3C0CEZSzccbrvDcTYDZcMTBLJvlVXyu44fSL06LN36nTolARsvHPEsh6ORw7S5ffeB7zwiETY8myzNpIn" ..
	"+njks4a4b6OsnnPS+6C5AFgsOBeZkDqBbSPx3nc/zcCxijByaAtRoZrv7mtJGDgwuUcGv577jurGXQebHf8H66d2qi0FuuQX54/W" ..
	"YutHc6yhEeOe3yI5+8jHjErYQsfD8jx3PhTQM8yVZxKqOLavQtW5uF+xmlPK/75LxPa/AsVPoPFTduJGalQ4uJIHSmSkG7avyQza" ..
	"/agnnigx+acJkLndr62ELg4zSMx0jQ3bKAOs3vVLGXsY90Om9ZNDQLTUO56wqbl7O8q/cqtsTQCA5xr+NyHf9qCmTZDBcMZO8dij" ..
	"tat7WxIfbk/ttDc21hYuPzsVB3ZsjBWIplZFKhgUQCWMN6/3qnBaZhi/48evYWtX8t1Ze6CRZ2udCt+vgpBs3tVvVvIsHm4Phw/a" ..
	"YtMUCfLStlQdmLNW3LhfcOPoXjbw/osP/j+As6bUlwOYMI2OVum+B03n6bKNlgaDQrY+LC7mXh8Q8iJPfqf6pyuBNP8b8Ya83DrA" ..
	"QVNAUnYJ17tccOTi3tSdYlbF/EizHyuXp/3Q813V2zG4S0ZKVsoSSNSydnf3JfxmseHf1WM3+/ZnP0HTQWgAtGQWRAEg5aLTFRd7" ..
	"KS4StREr9uJS/dlfg2zPjRThE9VTMH8i1xYoeeY0ivdEAETLyd0dgr2HBkrCdVj29PTdb/tallS+DdWM7A5s96cXgkFz4USBFZmV" ..
	"D0dl9CniKWsxNjKODxq1OdgBC21t/2+US5NRX9VsWwVVR2CJ05izV3EY46n0iTWvi5gli5nyoBjIwPtSK9PeDnig95kPMj/nw7XJ" ..
	"lwZw5jixDC0gGYZZwaOrf8bUGQ590M12OmHw4N/ns8KCpJz08JbI/Te4PM5zoPtFyHncQKjCojeOLCC96ao4nT/905g4m/lL42Jm" ..
	"rtzWcndYxy6CK6I5zqA9QY3P/ZQfS70L5iAn5j9VLFAsDbP4tNfvsWM03+0X/CFbjJ1OPq4v00mKjiRWgQbpTjysDy/UOZ7n+47i" ..
	"SqQgIbc5ybNGDB3OU0t0dnzqEeFzRNAF9fxeZFdgv9WGwCAoinKEz9jsjRnLu/DgQ2BhbB4udoChoVDLD3kKPV6EfOigk/5jS/lY" ..
	"fw4gssqEMWDaj04YceBydCWpdqtC3e6MS0htqCccbSpDOMoaSsK1KN+KgfrqK3x+tu9CsASSimPMvTFm/+4q4pn0YHpLPKEJIDE5" ..
	"xHY24av/NkaEUhhraX9ldl71U85J4hasD9i2SX5rpSdBQtY3oiCXw4y6/HLgqB9R91JkCR65RlOVI/dUs/1pFixQj0KTJyu509JK" ..
	"JLZe5GZh7ZXCTMjvHuYr1QZMwyDwA8RU0X30JcYTjyhVx3KYiae9Rq2/leh/olAuD9GLtNcfvNMwLlmv3OgrTujmEiIESHd0L5d1" ..
	"IfHyWZ4ak0rysn/j6RoewQ10JvIyUsvyYCjPpcoedqi3iNEUVr0sV3B3g0Yg+XNPnuszQRSCLuug+9sjnA/DTb9cPyABjy6Lx2p2" ..
	"jTZAjCY30CMM1Bmevu3S55LhB06S6a8iuOcYBwF6z/Il4tT02XXqJnAOvjP8HgJSvheW8RdUHpwUvAyiva9iGTw9lBZWhqhK7LLA" ..
	"X0XjgLkSMy2H8u7NVsL2UJpuY/1nbfa1gJWqixvn/xS8NY7fEBzOq0l5w7ApZFwDX3YQj0qkpH7tpCNRV2JUdu0tJh79lpizb8+t" ..
	"kXQymzoUyBoirCt3KjHrfC/KHSfiSOfYDOC225f48zyeIltEHfEpR1qY3yuoXZGBfK7J8dQc++gJNGUyS1NWLGhspUQRzkOkDm06" ..
	"aHuG6QgpsTBnUoqEo1WDSkvBAxLFyaH9lopnAXThW8XgrpcThR882nS4A16F7rATiqA0/shN8s9O0L/O4tay0Eh812NTiVsCgatY" ..
	"VgISxqn7MHFy1RRWvF7jqMs/eOMkJ9H9v18YKBQLHF1NYBds+TgC8tUCwSboQ36U5VfCLkETyQpJfMaL4Gxpsg0mr+o/eBFIyKrU" ..
	"gtT6ELiiafe3oM3pqti/OJP1XHWbJiHT1/uU8f61Vg/iq5Vc0M83JE3Bm7CZ6Vi1pNKC/g3Bv2UzHaHj804x6Nx2iHcuR8CBqmZq" ..
	"PL0IdlEpO+4FtbCyC6OiXgULo/cG1IqyQJQJZIFHBROP+NLoS3TnN4l+XxsxjrWbhu+QlEg+jFXjiUb/8r9C440nMI5ctZ37YHYF" ..
	"BcS6NpF7CS5rhwXVsZXx1wFPtk9SaVGLT9zgBiW54/E0/60Y9MHospv8DnygyBZi0YtMHAVmRKef18cirZeMfpryqdX+ljLEmpIp" ..
	"ux5w7yZDLbd7W16OqWNd/TSS2WxCfxv5+QJHHRiwfy8kv5czvK5LKY/EPN0eeiQnc8Cq2dj6wGBW06SxUmZeEiUfE1gRtuijWknx" ..
	"wC2u+b2IGaz2mKT3Dsh0hAyiIl/S5JJV54sEAXFh9DkYd6r33wiYbhUSTK48bt6offcpOQz3+kMlMULahEULJK6TvXak+1Frledm" ..
	"NR5FgRGfrbkRa9EELQr8XXZjH2UJMj+OXyLyAtxEPmMOI8M6bwuFi0G+W0PlPCbBu10YG6Or6Ht6qSwWNwVCKvYC+/TTyWO0ZnJB" ..
	"7vK5TC75z62ey0WALVNZhlokCWHBxkPFbbocz83cPvoWhkZgpP+x3kpIhFTMfnOhushTjME9L3G21V6mbHWjR8WzRCXSxcPo7Dzf" ..
	"sbLDrDcqi08VjpgN37oYSowzhH97bOR9AGAfoossQykJlPXWT8OahP5vQrxOPw71QE7/qnaGehM1WV/l0ftvb8hiqpeR2WQqbPoZ" ..
	"Qar98tlP6i+didl/prlIufzWZhhqfndfHgTfFD5P/iIrQ10O7aEM+7sMooPJAWOQMWyCETKNZKjj1bdaVBx4j+/qWffsV/eMcctj" ..
	"wuqMgNOrvBiFmyj5EzTW3TcIf1aBEJtOXriHHSa9pkJMPsRxr4LZ7hD4pkOR+Ff8bat4LUF/YyuxZ5wgN4/+jUWcTC0Iv4RkjQns" ..
	"jjMtxdFd2GItpQqlRxPAi10XYeFgmJ/A3ff/6JoA/czQWfpj7Wgz9OEv86IZXnmvVwSCoU/BG5Hti9IV1aBOVOYYTW1WKH1BOc1Q" ..
	"ULuQPLmIt53YoTkl/D3OVMahLq1A8bCKAYw9WODhyE5tZVECfgL3OhPdZ6VAFz+WPcGZSZZzJqwBROUgfHtBmg2DDL40d8zbyK2j" ..
	"/gxc6PqLWoQ26GkSDRJUrne64SgoS8UmWRwBZn6ZJBSUEEO97X6zcJd+zdKqJYCrk7G7zmrek7420ZBTIVCYKw/rPdoEmsWXsbPU" ..
	"9g9PJpHDNWWe9Eb17IbsTrLZ/cWGwi3rZwZ+h4ydbkJQoyXSVhmyh/9LzZYn6ZAijDoIOkrsqzYUW9IiWUrZT+gQgMA3RLclO0v9" ..
	"VTmCHOGYrJsdILZ3mXfDsTYFfUBCcbGM0R+QH79/fLyKEsB59lgS+LblEn1EkGjhaGNF0uERwB8s8j4fDOiGweOPlO6LAelxZijJ" ..
	"BPM65Gx6cq1T+NE+woQdSbfrDAwrDI1uvU0C+S4N0xhUx7lUBFapEvpo+2JtBiJSnrsXQPXHzOmE07N1dM/mSwp4IDY+DIJBktwh" ..
	"AToIxXY5Qky8WNi1jWnfP1Lf9w32nt67Ka2hMifiMfqj55AcJet8fgxdGwhT43eiaLosF43C1yoBPDSo8puCldmlsATt7T6woNCA" ..
	"kvesrwbmZUiRzWt2V06HsMVgqdJwkG0Locqe21dmuo2MQ5ji2R57SNSLuaGIFKlRihBJz+VreFZhajHF3MWdJ8Y5ZQySWK+Ugsaw" ..
	"HPjJvTnm5bQwViErnNMNFzF75G43e1AcWhS9ZmCrnEViw6LWNQe3hn99YvNTZGzcBXTKIHYoNPqyxhEz0D8sxJoDlE1RS9hAo/4y" ..
	"9a82sxOjkDW2avmCwrmUFDBYIgck8hnDzQp/0clFu3bmYuiPglRySSaFCxzzL4RPCx3t7jgcMxJTArtPlhgwgl2Up7vDTDIwDJfN" ..
	"MGJRD5E0W9MBRhKrcenAtXnxgYxGlKRSgTEvLNXTUD98HbeC1p3ANZWRZnHbqtWGsW8s7Y9fb1/a2vDKz4wY1SVV2oLs0h2R1d48" ..
	"CvUByVbNNWZjvQb6wT2BBW6YrEh9uzYNDkhvEJ/yMRHiuewWEc8ucjFiDrx1KyikrDFlaJ76pmZjHJvOY3N9j0pWaPEL9Jyw4sT3" ..
	"eUmcq4zRksICIVrAyegWuuqNxS5FLzjVpXU9JHyI/U1WJdQS4ATaJeR1TBIbgIQ0c6kwaA95TldFItrqCi8jc/AIt/IdK9ngx3Oi" ..
	"if8WfbN5C8oOSg8XddRvmkkHOk8LAUPLP//307FbPy5ciaH6J52McLqr/6DVkPZm8DrNoLQBSxOwZ2pXLMiDRQVyWnrpFSzfnchJ" ..
	"QyuXxXecv2x+3vpzwN4BKb0DWEswh04MMJhU6BnXRtrX8aNLOWjI2s2tFkb8as6+0gzSUHdrSHT/1Ay8IdWKiUyotnzQt2eAr+/4" ..
	"HaKKht9MN5bjSbGZQFrxKu0hnXCJXAm6hXGx1CFQ9WzzTCz26QK61o1O7KD4u4LMHhoRbAEM/8sPr4uDt01Fm3pNGWxTUsmqF/GB" ..
	"hByNBKHwJ5tvC6f7tEhdjG5j4asrs/P08SUYmRcekVaVlX1rQUNdpbcyuJbmUsFnixV3KwEkgh25YsVxbR5UxjfJIaDywNK8VBsK" ..
	"sQ6YFHbrJ9bChzFgmAYZWXs59mHKDASVS/z19fhAvEZ3vhbFmMUwrF/KQa8jHcY2AYfOdTNsECDGPN+HhJ3eJ06rbbeEzp7uT1D+" ..
	"W1ErqAiDc+cZGpHKSFC9t0uXHOFCRYGQb3zMKqGMPPIr64AmR7WPeaCbsDLBznohsf6xZi6DkawmvwuX0GxW6M+PNmZMjvfAGNHC" ..
	"bLDZlhxiV6Kqr7zgr6aKrpbME8OnIBSBNpPt0aCvzNqI/0hcu97F5P1HT5GZxE4rZKPmv0y+KomAeXonSsYz+lYuchGPjurrJaw0" ..
	""
local PAYLOAD_P4 =
	"GCM1F+7BWcz6vOusxyTxbjpeSn2KgkMGenYNWEPVhfLnpmD09zlrmk+gIWvYBOrerimsltZKf1bKdFKb3611FtmCvn9lXPncTegl" ..
	"RyBzknjstbUzLyr0BInwu9uES0x/YIhv1xqvsz/DIokhWU9h5mvZ8FbXm4chBuxVIcSbqLED9KoFw1mKBWuGboYRVgeEgMcFKsDT" ..
	"amyJDvWzLXSOMRjwPd6tbcPK2icOht746PugttqNZxYQHEByFnM+qVnKCkTEfHbLuYA29jVDSX8sx2nZG9Bkjh0wqplIWhQJEBFQ" ..
	"QWFDFVuNKWb02i+KtXHzsQ87/w9/KS5MdBACLBrE5BtEDhqVsrF+Ytz+WsUD37vzYfIdhK3EsK8tHMOYQmlgi6XkJvs9Cxn80YzJ" ..
	"Wy3ixPVVJa4Xf6ERyNBLC8kUUxLuRBGBPgOchosXLTKnYWlFOtTIOU4rDgMEfX6MJv8b+EcAWnDacs4VLpr6ycFZaAAgYhxz0p3p" ..
	"U7w4tPplMhdKS1Z4UN7Hiei8cKTWaVTl3fQRRYkv/vqG+LO2V37ArPz1jZI7Dvut1eBVUeD5uMciGOw5V8bKJQI5+JpeVjCD5jRA" ..
	"XD+WASvZ/CTtqumZkq4bOx1YMEZbRFisgy35cjwkQax4kC8xBYer5rw6hrVBi7ljqM7a7eRnb2D09N36wixIK3rqYmk9cWZdx5Xv" ..
	"HQ70Dlm+amycflA63s0Eek5Fk/Fdbw1coq7oF+qe3FogWfGE+dERrOwYTbm05A98EuslavTvS7hQkSzzCeVvvs7H5y97dQOFCM9J" ..
	"isJPsHFT/TJUc7RgjMfZ51OKqoSo/Nv6evjxdV/ARxmVWGmm8fSUu5TVwPtQnMRsqAawNQNDWvVt/EdYdO/2UptDIncvtoE/rLrU" ..
	"u1DjmADAyPwos+2c50AlyhTUCgD7MMFbIcXr9nqX8Wik9YPOrIpVwtX6c0XvsNMl2nbBCd5rwRn3dY63BzyhuIYx+fr/O76Tk2OK" ..
	"1eT9P26wsguisVO1en0ZpjFHN2eL1RYCut/TGYxG3GltM7RWhxr3/zR0C3OK3p8OGxQxA+rk+ngyTCFtTff8jXpMf00K5HcVkkqL" ..
	"HdIqed8GEatTRUeCoUyCaS72fxsOaclL+6C8dq0pgTd8XGdzr8pb9n+YfLjBxQYl4UvMLUysUIpMSmTUbK68+X5Y4zOjP0uks3cV" ..
	"BXj2SNCsk9R4VhQA66i4hq3F4Foo8BPPTDNeMUMEa01gsajU6YbjH4PYxLBqkc4VWu5GE0qoXpodBl4jmdbs3OTvDbWQFM6QetjE" ..
	"00RGQMHhk1zdn1K8+vtOyyZ1yPHdsQTYizOAEZKVrYZD9RKJvdATwpDHevojDPMaCBzIkQ2KWmBDg1ERFdvgO+DCJQKttEH2USoG" ..
	"qhEaFjHVw0RuiiRxJFrMPKJoWKldv2NCMQZq+HOifhA4jdxBbqqfz/z9edNIX34UGNDH7cZOjEDAP9X7AaoxdWkk+HcG1Yf7SVxe" ..
	"zy592s+Hv2/Ul+tSZFxGRDrqptVR/Ur50iHIUXJVItnfTLb5hY2DxQC7MFjQYcBdvBUMBthnhx+Dqh7bT6anJxZ/ZxYMNGA08xoK" ..
	"jLY0uewXfLVu4G1Jw6spIJoA2tHbXiAPk7afEajtMUgqD8pIvVqtCuwACQMV3H4qEeFTJenIpHfkNNDEwnvDbh/Nbpa2WWyNdM1z" ..
	"nNJOWz+WfxZ8nNEs9s3V6BfGbq0lu7qInPAB8qtVRILUTPzMQbj18MZSl97vOfVLHEvzUUXFIWpE8EocfjbQns5tAQQ9Mm2ti1sJ" ..
	"hlTc7IPlD5ufFRo0oxrUVTacmuDGifXOMveK7KsyJ9fARWhF1BLorsvEw7vFOgbJZJYo/Ekm6SFaovBy/7MjQiP5pFaM2f+sy5CY" ..
	"NQb1cKFyR6czKUlBKX1P+F0wZ7dofZYlJ2Ak8cIdg3VJJfeRrmAYcIJBNjs8J/q6geLxq6bQM7WeuR/XPzLz7dJfeqKpcezMbCuQ" ..
	"YT2Bd+RH9zbvcSxlJgfXbLhvCMlT7UIebaUYfU6vr7kDzZvERJOG4V9GWBCKghgxNMmDi1/+xFwNGIu/KxibNLF9oWqiXcQECiLR" ..
	"ULC5NLIBL8NXiCv3BapE/gw6M3HagJOG2RZfcU8qLru6sLe75//ogBlWH8Z6gbvfy2lSn1rIgn/q/lkxaoeOM88LhKZw0tHjVUxr" ..
	"sxwevinH8G0OFog59K/HHF5smz5WvJhUpExYn5+4qkPdZE9lTQ/sUZUyc26BcDTOVG/1je7yhLkmYimEJvSSKIc2BlDQDJqnyTUV" ..
	"TqfzdAmjM1W5mJlROqosb5AhNKiZouOuMoesPmcBzxAMuiyDx6vabIQjmFZr4xG5Vhqyni6YosXDdPmbEDEop/608zbgXe8s+SWO" ..
	"3/pp07vavLBbDEI2ni/lyCqAFH9aAJJ8F/L8fXSevw6nOEMG1buFNX4M/wTPgbeM1Ao7ZSZNJ02V+kTAbFJEYCHmmRebATLE6pyz" ..
	"sqMy6ve1HcBFcmx36+ltK8U4Pz86fmfy4jOZMoSRKFKEx3lS8xunCtSSKiJEKdZNFjY6wunfgOlDxiPG+TNtOuLtJMsFYB6ljQR8" ..
	"Rh1I2iZ5gIA3Of9xzWkbCam9Joc0wVJgipsQxjQW2uYtjE+s1KdqGpHvAxQ9yvt+ccQZAgnOzLLYpe8ESJAxSjvEn43P75NzKqm0" ..
	"Ggp+a6eIcCFF2DPlQdiFNEXi97HHCA1dl4fqiZAPdy8HiXfeJhPPTlcWoBh83MLW90Ba1zcPZUyaALaXQMNRPVf+FwgoJZmZNcMw" ..
	"GmAWjwFoWqpzxCNwkuJd+k+gamipzEsT85Lg6kFNXdTbAKa5eU9S3DztFRoMns0iQGPb4ne7wjIvHnkGxtMA5nKSadG/kcyIGmEj" ..
	"n/RMec5Ljf/9+cn6ta4NainHEpsNlh2L4bC4m75OHTlfiAgZB3RXBat1So2k2tGREvfPnyXZygPQEJ5UaDxHDQsJTyQ6AYuYunRq" ..
	"lSWdhe+o4XkVdEwQi43sYWpjJNW3MvOIhTLr6sGaRJ7t0693FWCcH5h6P1Wh0be7NQXGJE/YQGWkcYIZwlkCizwh71Rjwjv9N/vY" ..
	"14wVLTbufxoNjVf7wi1DSFMkg491U9wXrOOHkY6Newt/W+SUyqnbHlPkG8aO8XCGHhv/nav1YH0oyfZbNIB+toubkxs8X857xIM4" ..
	"/ngrdl4EqVRSpWZWDTSq6x6mUqoOug73nsc7P+2qD848jES+hcs5LE5NK9BfWt/hKwqmXNiX3SqscRJmyDzziqlROjWYLwEq1cdA" ..
	"f4LYwGtRlmPB3KY2HseENLpwqWEId3JMtl+IN7IjP3ccrMnlEdriGR//oqVz4d9kT0f10v3MGloE6XTt4KjfQ4Na6IYZEvK06W+G" ..
	"/SOMpz0wCg/wlUbWPTtSGGcBsVnRqcBj1Gj6fP4C9VTtVF2kfJKpbtoC52/NV0G5fCBA/+fM+n7d+s7CHvjvho7BNisz+GjK43o+" ..
	"ntOrtoIZMTh4a+hoWc1DMDeW8KzNO3+vjvx/cY9v7sv6uIo3N61VZg/7n+fCZd2vK1O7HA6YZpX230ZLj/w/SDT2GFNkVm1d7Obu" ..
	"QfMI+pA/paolw3pRfuSxlRGsTm3OEfCxVib+AkR5OPRqtDN/J5PParB3zD7YQ61ZfnKlZNOQ8Rpnk2NeuVJAH5hWa5nE45E0q2Gz" ..
	"DiHRxFy34iswg3ZjwMThube6+xb208bJyT/+5r6nTTJdVr4MKu6DIwqWxKh75Ub2WBsFgaGCUi6v7YyWtmECHT64pIj0jsm42eG/" ..
	"Vf8M/kVs+2tLInjOBfZPX856RuVoP1V3DwpDFmuNakl3s8O/LVn8L8i3qC1KMmo9TOrm9kawgrsgmo7Qlrr/N1px2Pvx/X0X8kSa" ..
	"PFAO7SLI2oLoSecMvg+gDey1eE3TjPCWkpy+AcuoILbcUphfRXleBtOTzkB7vRqVmwprAisgcG0PTgmLduOlGoSNhv93ZxSwzc7L" ..
	"gaosmYrb8uAlcI+z5e6TaXyskKHZ0T8MwcxqIMxdRXk62O7dStdXa2nQjYBRiHf9snyOb9I8sykziPsra7YrwS7zpcjdTEaCM8H6" ..
	"Pe6fDnF2vrmblvoYaS+czFRenKlEMI2z59xrgJtNkJVtlf+Ds2hGKsN/UmGWR/zqdeVL4LugoaIHVvl4hP5UD2s1PJjWDEYcHsWd" ..
	"gV7zcfjYxGmFlc4o5gmzTj+rNSzlbmaRVuHbiNhqG0crFaKyJBjmRW79SK2epgwbuD2EfSRV2KiG+AXXvhIul9/T/4Bssh6ziG0s" ..
	"+0YmivlNG0DK6n2Y6CiOFAcwI7ZMsADuHwRjO8KEufj3Voj1HgP8FOy66HxCOixPXgKVknn36c8qbCEEtEKaJFvTWGMyh9/wYcpj" ..
	"KUPbxu5XpZMdT9WRUU6xG4R2g1TX0mGzxMNu1R0etCTMLDdaoUSTZkbcQavWiFHvMzExg45jt3bHJ0Zu1FMCnlwZItK2mYQ7cHF+" ..
	"cQ6iFwekxZ/QeYDqbtZpKOOV9QPmocXCe5dFSZn08+mMiNA0jHbev+TPleX1CjnoS5EEQbl33ZAvIl84chgCM1cfmmghVoNYBefA" ..
	"iNFH5URyXJt2edECZOeFXmkQpw0Z67S8vOtEm7LUAlxCcN4wZvvLcesOBccD7uIBCnvAf/NlwWJPKQWvTok8Myuiu6Dm/fiokvcB" ..
	"l2S0IIUks1OZ/ZPhPQzxWj1GM3AD1qcKYjhB36srIR+4jY74HMP0eJzsx6lUKhmAxcRSc2K06bm6QGd2CxvTHxQPd7Htyokua8pN" ..
	"+E5YOn0BD7SgFQWHyaqbyiR0BmnSdJMfF54JvzkdnDlrSQOpx6uJ0M7L/02HRchOAmVvf4eHl29OF+4x+XJ2uDteG3ZVInPOiKzh" ..
	"lJsjkr+EY/BCnqARFbRfhS+msnTxHMhyf77O10Jn+CIfWfoANphISvWSuiDxd/2gwE4z0fW9kd0la1bUHVn8GTmBODK1O2xp0KXT" ..
	"O9WNaI+vcZJkjvbP4QQD7qV2V9eYq2tfsccZpWn16ofaBlSYLHmCH68rwqiQz8SY7mW5QZDhOIbEaC7kPpIFvekhbrt9she8n0MR" ..
	"pLBWkAJcsKOWNZWe4h98Md0knIPxVYj/0LM1CBjsnZnpRcGo2o8o1PDfe6AbY6jxvuTx4g0rHIvvvcWrwTg6K7Ds1XFZIEfuHSAC" ..
	"POl7I+1WhFsL+zYRuXk/fVAb5ghJczoWd/lWO9q9+qjpOjWUx/qhSpqz3mNIF7TZSRdHGj+c/vBr0lit7LH2DRErDIob6SPKcc9F" ..
	"XRRkibaSqwlT3XfMUZ7JT/gFUKjzx+o5Prlm7C2wrHFA0gqMJ4HPc5UrG+jCUb790IOnGVgmWieJ4lZzUhoWP/xDfYWqjuikEpfU" ..
	"dInv2aOAFxvSt0eJS5MN6HErE8kNm6pYD3LyDhC2kvNtnAltg6+xVX7BUJh7d/c9SesG7OXRT9Do5xtJO+hGYuYyPBYOAk6Y0QlS" ..
	"BaBfqTCN4OENCtMo64msQaWtCKy+6Rn1DNoVBtfAJ/ZKpgl5AD96bwjulRyA7/GHZOH+Yd+MOfSvXf2CbU35Qd5SDVRzoEKu9UR4" ..
	"xLhCAJYFyAGmqrAWP61bG9hBEmP2KOh++aOrM1yt5HFw6Qd8eOfmG6H/Mt0rEsNuIaFD0sIExjVDGeOfANmjJnkWAD8vkwWFpuJB" ..
	"J0x1qEKOgelkl9TSUvjRYhQ07PKBb1tytP8TS0kb+Ggvr6n0b44HOUxFyEDUs6/If+3PgQ37Ze9eae4L4CCjRXtauA95mtUHwD1Y" ..
	"RorjPmelW7ElmwzYkWsYRvK1Iscg1ilW+2JR48K+92Qe1ELZ0QUcZVdQ0vA1snTZhKzAYi0QUdpvzjT8y+rxWqP7PS4jojz6PpnL" ..
	"5XkG48mwewf4fucf0Ebyg76wr4dEHOeuj6D3YaCUSXh8HlThMAYJeIawt4NAge5odAutJalgClv8NtJiibdrjXeXkbZJtMFx9UHy" ..
	""
local PAYLOAD_P5 =
	"QIvbLYz5BRYOJTfTCEw7Yn+9bjmLJJ02macvvRTHJmAz49UTYHAXYu2ZO9H6ZSVkEjXIOLSXMuKb+WV4OVlt+34GT4iUySi/yymH" ..
	"IQ7zZiD6m2SozUVhEVsEowi45Sg1kpbbwQNqVpHh+N8MO2OXlkCYRWEivJHIJ/z+t2mW1pcxNn5vuJFPB+HJUQ1zfHy9eEG5C7Fj" ..
	"NfochzVcVrFE/Ef52jowWCKNWpKCCgavE2Mf2K5BiZchMNVMcWwSs1+IqGADfJ1b9ysMRHD93JpVhj6u2BmnrYL9z175fleeBeqp" ..
	"ng86ykl545cnmsFFhh7Ncmp1PKjVigV5aWTfY98wbWKUj/jOqSaXXNDKmReTs986enuvvrfV3w59U1SLsNv0WSKdJvuZK5m3EkMA" ..
	"M9OIKB6j3pJA5ZVLu1fp1RVOsSfcqFrY2UkHnT/jd2Pp1FHyp89kTwzBQJ6Coow3UtUQj+j4fshEC7iUphuiOrptIsObpFyFHm8J" ..
	"tS5Bc8U2ygTr9l3TPt9J5cGTJxp8mbTT5yrQ0jeAlCQCE9ZVatGAiO8fv6Pz7plutGPIht7aeAMfQlp1v7CxB27hmV+Dxhzcf18y" ..
	"ojcbcilx8JTfnk2Kih2d+RnadDqcNmiw5zUgbPMvQBbkpPFeU9MyrOyeD/zBdP2Tq5OKaEG2SoRlcZM/ef0hYuYLkAij7qcfNR0P" ..
	"2H5gl1NTAvxbu4qzODacFU9Qgh8KGEe9fqY0cNEcLHsPiUcNTxYCzj9/r9UHIEHpebnCFpA7FJBPMVC7rW9so31yNDmDuGkczrl7" ..
	"iOADlliz2VPn6ivh/W5GdhlzhO1Ljxmz8OEGXBOsFZEG9f//yJKFYpFZ8jgl5b+q3dAaQ6ye7uFNsQDt3d0l1Oz+WHrbytlczk5n" ..
	"UOHbOsF3wb+ADQxcHvQmxEhKd64nQT63xfhyAEd1q97ZNmFe+z7IEOxbke/dMnBCudN0o7as7eCJ0xXLIhbL+g1R3sej65N/mkyk" ..
	"YGUbvoEA3/QHTSP1oPuIg7dVUPjZLq4EjemI2GeYRtSs135FiwzJvMPqotgtY3kbpQGH0XTaO7SEChmDMIrqG66uqaCsUlLZkGbl" ..
	"cwoKExgQ4ho/iTE8vM9RD4MvTwPtf2ZeTJeFEoNpIvNLVoni1AOMC6YkK25qJzuG8ojh+xx0WXVirbElqfz5xekjr0z8TYpDkOkD" ..
	"bogHctpXcViqrEQVMiZS9rF2Dxf2p31I2in2a0x5p0p3vUJtrNaeHWv01LBZIk5niErzOPJsyOyxYL2iRwUBFTYF9ExaxgO2D0QM" ..
	"t6Tt33Q9GNS87AlLSdlXrQiOeMJgESAARWjVfjE1LVLhKI9BPVhOiFu4HHl/+xTyBfaDDnjdJN61j9dMr6U2zVPvk2OjJqGXV10C" ..
	"nhmMbp22WAe5AxEAeFHzwVeFgXei+cSPfPfHy7KjXY0ylWWHVTkLCndslwtrZIMFkCNXmtEkEtYNH76eE7K1ss9kSaYUVOaFix8S" ..
	"s7M+y1qkA8Ldq4T10MczN7UNZI6gPm+49SM15a1jADbLuaK0Ng3ZPXawLyMsidvjH/54hNFoK37+rAswIdUOuGRjYMQW5NmkGiLU" ..
	"6SLLmX95jJj2XAyRy0TMLvhAk9Wcpp2vyMCJEc7P9ITY55EGna8PXS6/bZnHOIBrg8YD7H5P4NoXaDwExUgTaopOguFfYlKbsfaS" ..
	"ICukZ71OqMHXx4MuuWaSSEdLSzIpP/SVw59s9SglOqrMxRr6cfpQqElUkeey+BMnQpj0V8IhOGuM+7eKp4qdTH7zh2OrdiPTXJaQ" ..
	"KvFY+hLXYUkGXzGERotqAFiYZM9IPKvWNECcJZnbOd4B2aAOZykqFHxgElMGzECoT+XWZ6g16Fx6htXjlQo/+C7/RB05Lap5Lcdg" ..
	"M/k5XgRZbgwCcpEwlWuNySGgIKeAiyoeHs7jDxJU2XgxQU9qRa835WShc596CQjak7VCLtYpJ+1RoDbN2k/yem5im38XuqLa02+S" ..
	"aBoaTM6nkhiPV0S4uzLVJw6DICLBfmaM1PWRJss0l21I4/uhYjetetYvwuJc3x6u6TZ4Ob0nr2Eby8CJKuglQimTW15hGFzyTk0u" ..
	"oUW1Q/CBGBtUq3bERSZ40GRqK0cjDgkFDJQqmOOVJ3J3gTMBWSjBLOMm4iw70pokIRo3T2z+wkEbqKinXvGl6IdrlTXfPdxs7ygD" ..
	"YdK8121tc3rPzites3mQR6KUJqcotinI4uyMEABnBpirMI7K7F5H9U5y5NySfjEASn/iyH6585CB35Si2BGniHtbY/b1/80VW545" ..
	"c6EGMODe//IlpON1hruJk0bdwKN8icjZ+yJIykx2wDgrB9IwtUyHf5aV5yq5eKNxEeKqvF5Ih2RRs1FCT89sznoLlPkpH7Ise8Cz" ..
	"eEtdj52rmd5Duh9VRt/7FvRdWXFlsZ1nbnkPJjAa1ZYnQvR/Ucl9tWxcx1Xl49vCAYsu3JAQhunZ0nvZqzuNq5Y/JjOpZcfT/E9s" ..
	"orVePe+bDkiMHB3kN1EXg5BU954Ncc+6aYYG5OO6vPRnWm+8H3gvjb7EcV3BSsoqfPtd568DTPE3CMFfu+GHH+fy5kluh1SXz28l" ..
	"rEMuTPk9JVPUspyyQ1YHzgPXlXoaka6c+/pXF9LGJb0j+FSgaLi4qYObMBClZVF5WE6Y76Bnv4IUk0TtJtEDJ/J75fOqIRwEcPI1" ..
	"KqDREsmrhqRq/yK8uu17JsDcmJ+fM4Z+jwQtXU9bhaUZ+fXeX24y5y451ZXHt5OIkBeFXTNm/KoPC3OR38GjmOLJ/4OqVzJsEcrq" ..
	"WAnVuhlMyfiGF00H567fczfug4K692GH1rWniPBWpf/3X23+pooSu8aqGdxL1jMuYnuUpFY0ni5LLgUl6MoSmjJaPg+C9s4Kc1fj" ..
	"edQ2xx51ZfwYhe9HQO+dkKeNb6WgylYqtZDx+jXHbfu2CfQ9My23GhhQNu05PFA8T11rW57dDDfmd8bAP4BPXicYLaJPMGsJx02r" ..
	"V0uP3y67QrS88N4aqcpn5O5NvC7F+BZ+bbhWBRpnXMju2JlV797pvSXBXglN1LQxrxT6/AuD3lqvFkpa1Ud/oNn6jcP2uJDI9yOR" ..
	"rzyFrPVes6iQZa7dssF37SJiDKPgfqL/FE/2eU5cMZ2Y/Y6BTp6uERImE+UQWX9GvLix8SdBo6PnZzscEQ4a1PZh+mt+ApA9smiD" ..
	"+ehXcCzI0AgU7KYmAN9JkMnBN+l18Do9x8kHqdSGtLFPDx8n19zct4UocSkddKqYsS2EH6Gn9F/05q59uhDTtPxcmwHbLX9li9Jg" ..
	"H0NJauAWTr/WoiYsYeqP0wsvhELWHvs6Hn1+3OP+UhEf5a6b/Ke6+N+4q5grNKqwfWMaPT2gFRvQW85gtOBlhS7KAWgZgfwt/OBr" ..
	"bwXW/JrWDxFn/ajW2f0jf3RbioDdc1RpQvEeYufHPLhuNBa5CNbQhsBxEms1IpRbJBrf2Zt+w3IEobi20sHf7duWNUN564oEHHHm" ..
	"ZQ59w0IZii9DqkiW4Sh1rgmcLmfoynhRDolbBLpp0tJq8lZ6Sb1B1PIKcb2ZHAZNrLPIKjtiDFC8cYHDtNAUez98OAYpOB9MWlLB" ..
	"hMRibhGiefjhcCGvRx+Cnl4N+yuHc5Fj/JPq3mVXsGKQVxYWeD5dVUwfA2SYLttdsl1Iy0NUkhT/v3t2C9VX2/aauo4im5ouFGFT" ..
	"SekBrEtXKSZxxx/vsDyiI9yNzJ4jR5N1hMAkZGOrku6Lwf2JujKgUqKrvcmoyLAoguCBoiHdxES4zLziMpFYTjuwbQDud4qribXj" ..
	"zc2QJI7gvEER99wMvuCkEH+2/PvJI4dZKobTVKE2tDx8FSA94vP8B4aUBT5y/PopFQGL5foTz9apaStinhQHnQ/ZzKkHmbqA1CHG" ..
	"CSeg5OwvFZzbIgGKrPtl/DjTZRKC6nxFN195dUzqSawg4VILgEUi2zG0OhF9RP1JNrsS9lY1Xbo+GwoAuXWxNSFWY7fv+42Dda2S" ..
	"SlF6eeFYDLVzbypvocw5oDBXJJR5DkzYmLJikZJSxIYR6RKcB01MBFkOvn+osf+D470lOf0yif4tT9kwj106Pml1lhlgo9DmBj/f" ..
	"OGltkj4sO/n9DtmRRfBjWTyyz9g0z2RJdi3N7rc8hiobxuku5vLWbvrJt/1W3PjkoXE0NgAYsE2YQ/LHkbfmkQDn28v+C/H5zEQ1" ..
	"UiN4nEQged6U2IBfzb7pQjaU1ZhsaRIME71oF8gQK0DpWf+l9dcxbYbJQjTEsfxwsmLlntxW9nA64qcpGvgPNQoeNISDUrTT0vP3" ..
	"jKukdOHbiwdVCJlG/5DE+BkS0ZTmJ4os1lW/VbfUOx3O80WP69NursYmvJdlBJPF/6ZMorKtDDvPuLAaPp8wip9Uk/ArE3o8MUWB" ..
	"VuUio8KeVpH5sbM6NY0zAu+MnoU32ISnGp97M8N552/cXbC89uilsEGhPYVTj4BbPSb+EXTU5UMBJnJ8IJnWLjlzL7HhB1YI7FIq" ..
	"vSKH8bADLZpSzY5Sxv5yJx5WKebhwC+FEgr5o9DzlYrWz9IWQwACNbHWismt/FFZZbqQizhuHmyX+79YeoZODtEw7f4z01BLpIPH" ..
	"R7UKJ9AIJ/j1sCUoiB7DsSs3/S6Ide20WvV7ATLdGfWXWkJ5qa3H70CTyf2XmBA26w9N2kSBbvzXJHQ9qlqNJ1FfqpF7tKVWc7gr" ..
	"haP7JeZE0fZg10qFJxSuC8M8ORR3AQLhkOyzZ2o5W7OxJdVySU0waPqHn1NeYhcpsqFipla23A0vgGK1Kznjosz8uBiIrZ/2soaG" ..
	"vXA7XXDRmbWpLJa19ITfCCga6Ij5wi7Ak4aHlBMNGiOmJRcVd7brux26zssIHQTBDNqts2ZnlJM0bdxvyf/BK85EvPXhQGwGf3iQ" ..
	"771FC4/C/UdZRj2MOFoeZvTG/SYlxGWTSN1fn1OqH9TAGY8qoyWUAdge8h08RtaWqdLA5TolBnplCBhyEspO5Juz0E9nBVnjLdbd" ..
	"eqbuddAdBS4mepVJ90M7hGcW1ntVdeuuKzsXkh2OolAgwfVA7VdDUFQfYXJc0BpL67h96gnseWSIJ8WqGNNJGoE0o664lV5vVtF4" ..
	"t7/2bYPXl1JZQnlzyUhJBo+tVX3piQt2KgcPHAtB4qqEzf4lfE1lnPtDcc4VYRwsP7X1EcFnPHtehrNEfNnJ70XePs4BIlfBqAOn" ..
	"KcRWAfWUP8MZEaSN4AA3wC7ynzt9n07rVUjpwu8tdbliMDCCnaut7S8wvBVooSMR7N1StA6SZPbGFhlhgMpojDCvMdU8/miSNy2w" ..
	"79hexJKJN0U/DiE9LjqHTMeMlSJTD4d8a2NFfInzblFZXdoQ8d5Qpb6Y2YIJq2+M8QlcOA/agmXIYZ8oByfQWuRYamsg9HOJjfZu" ..
	"NAB60Yww+Qr4yI65NlWOCYtjriWyJ044kI70mL3iZkViRzBVN8cPO4XBkkQ3VqTsbnKkay7fTkoi0E4FAmxUeaFgyuyPMM76lHGQ" ..
	"J6bdZ+GmAzE1RKRPpCxFjX7VvXnNcezCSrIlU0TMzIsAL8YJdpPZNrDuvGGSHaVhOQCwgvmeHgfW1l0qfKkTlMuIpzJYdhvXDxxi" ..
	"xvWK4Xp5pq6UeEXNfh4rim3+ODYPkYzSR3myf9afsniApuPzimLDqtRu1epxOZD9EFByzcxFwJQCbseuDXqeOg762H/tzvuiqr4c" ..
	"ZtKACZRQ6kr9+VJcutJxQmfylbuEX0mgvTgsAGnBozQi/d5fZnWQQAlWIi3J7bjXpFBgA05bXDVeTA013X650p3AD+HvvvnZGN1D" ..
	"Q7xiejmof6Yo/1R6kwrgUIqD1Xr7xKKvYWAeBNrySwdjvUoafcJIziOVqAmB6jiEOZ4LdnjGiIPc1mADFy2yE1PMRTRcMPdE7dtO" ..
	"xsuzb5FcdTjMfmOc5M91W5TlaYmRdTbQ37PiS9vowRY2dBCKWv4qOelm71EID9UZthEnQltkYXtUMCv0naYV5kFFs1IQrJbP6Dxr" ..
	""
local PAYLOAD_P6 =
	"o270IDwRTSq3usJvrWoGsXlOVQDxb/ZDwlHNTfoeqhHs9OZZB/3e6Qx2zwhKtze8xrJPyvyV2gmQHyD0ZVyJfL+Q/eITlgrCoBpz" ..
	"LJxy1n3QrMRYYFtQCvjO1M+3TT1cbiNtieXmzsH8melMYkfL4YwtcIjhA+6qvMhBqRu76moFmSUGzjCjGM/AbUALluVbA8moO8MB" ..
	"ZtkzZHJliKblHV76NOkzg9IzcS/F7TJK5E0Pt/6OHd9lJyBi+sdN0etYaJrdizKPazJOctDqkeO8QK54eMzsg58JIGAhZXVc8ABF" ..
	"iZETl/JLnv1JghL0NcqwE24vxMy1AxVR89aUPPAa7Cn2oizX0xMKDNTUE8zvBrGqDOFpNCOmikbJabZjc1dCT3utUSlprs2RVDHl" ..
	"M4QqC8XJiw7df7dTt1PtAISTWhUMEk1GjBvUSsRZsHxpLQ8xZ7Wt8f8S3lZKeChJqnE0BzuhQK11VIZtIwIFJpxjUybzrQRR8AR8" ..
	"V9bbVJuFubiR1+udpF3+NNDgpFNaqLkVwyIb3cYbf0wJ0Muie56kjzLSvayK/46VWPtOGG7v9hzytdM/o7OKTTwDht1S5pVQvepF" ..
	"2cemgMN+TgldEVMcv9nlvvaL70BjHqxtky79XzIlcKbFwFx5uHIdx1R54CV/uVvyuLp3qjvdmGvjV1w2mvXUhL199yTCgrbALMcY" ..
	"dfc+8nPkqXztDCb3asZYzf0JIL0qdymwWSW1W6P/vsTV4/QDJ2es9GvnUINv9iC2yV10HDIUvAmx2xX6Mo7YqSLPPNQ+D9D+Sl2x" ..
	"ibk4cS2182sIbhni91t5kMo4v4fLMenh4aspkt5a/DFL/C8ENFolTYTv463DKh4v7pEH4J/DMVXZp0Yc8maC1Jhso0/ex7nncyIU" ..
	"CroL90fE4mkRq/bEIfMQ+TVhwDgeNut4E3MoAVrixZ44lmQiMPkZZCvOI3nrhtxSgELaT/kDQ0fKVkkSc9ek41UrAbvoBoOeGuWD" ..
	"e5revJvIGkasR6H6kHdeRkrI7nyPUOCmQeQH0wKurxK/5YW7bUuImKmJyYL2FJ9FSwK2V2MANb4ND5NTaMYI6/0JHIWrXX1Q3NrL" ..
	"30xLNx+JBCg/v7NcrJs+X1alaGwHKylkQaZTIBONPyS/mu6d80Q6QKVR4E5yYqQ0woojtAlHpwJ6+F3Bp9Yf30rpC4LCeV2dYsRm" ..
	"5j1vNiXbS54Leu+DrhBZy4SM0SWDgg/QBPdOCcA+ytwTjTxjz89R8natK7J+INib3pOLdVHhqH6P8FwM9BfYZSbYghcTBieIqmzx" ..
	"nyKdSwRHYQ4L0+paxqzq9tzHsp/qYIQ+X1FMjF7WjwFF6BID2wIOK65mZ3VpbE3ShSVKOpsqqgpP2z3bIs0vlTvhS3uWy2NlvuKq" ..
	"SR91VS2Gole3k8uYge4SZ3017ByTqYwt09IAMUC0NkST1uqq8wFa4DZSIKVZpjFvei2zzYFjDJXThmiR50KVTz7Mk7ChAaEaGVN1" ..
	"vE2FPCgC99znfL/BvFE9m0L8rVVs5PPMTvXVPJs32JIYa/9VPo2sD74qiqkGsRB+HKLMILWBuy+olTorngBr5tH5yH2dCfIjkLNf" ..
	"AAq8IaiZ9i2J/SNUyWdKP3ScqXaQhX0bQJ8SRDpa0GHaSf5zN/CuBrReBt/O9XdaBX2S2nrK9/PcBHKuugx1F8Kn3oIAHZPNoyfi" ..
	"LO6SWo63FvQyJ0aRiK05q3S2lhiCKO/zfLYtdmeePzFUBxF9PFHOKpROdrbqW8ktS+xXnz8K4yPJpVMItla8NgNN3jUiDSkXSPn8" ..
	"z2/NyK54HugPA9C69VE+yy8w1mC8n/GK3gnO5zllpzLNn0QwPgEi/MEnjDXwpD4le3Hhn0ZlZr2v45XzC30Zar7v52+tjCQplKaf" ..
	"gD11Oda2Fu3pkrcWtsiRFNNlVc4tjWo8ZD/buvkzsv3p1lak9lJZzNyQ8aQDG2UOZKUbKLCHCoEj3TKFOLp5Zg==" ..
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
