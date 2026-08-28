--[[ DQFarm Loader ]]
-- Licensed to: GNURT (nhieu)
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

local DQ_ENV = (type(getgenv) == "function" and getgenv()) or _G
DQ_ENV.DQ_LOADER = true

local KEYS = {
	{ seed = 3665148181, exp = 0, plan = 0, hwid = {} }
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
	"DC2AvUCJgqssxDWO9CHcgOLwcbB/9cOSl4Ve+4uXJiptsxMUACOhTX8dJRBOaBSNGKb9Ya6maoD98JTW+7+DxjmkPi3AoLwoqd6M" ..
	"DCSKBI99yI7vmxjQtaWbs4IBgvsd1vUp3b98DANTrP2UrN4lCzU0/NxS2O7FfOK4/ezeqJU21WXlwh1nQqk9xTBN+Nmkn5WaqKUm" ..
	"ajdsK2QJjxKajgB1a45JR3S0nEiyaQgxm/xdoNJJbH42uEgzIh3UYdcltmV2QGu+yG0UCngoHRRUB2u1Q2JV4+6ghTsFA/bS4bud" ..
	"IQBIRvuJtNiVho10tc74Nmp6hIbjmFd3AFTWq8/LFpgv5cRBuKHYd9tTnXKAfcBSxWZu6a6d1DYb36iai9+Gql/WdXpgwE4yJdua" ..
	"y2q7BSyDXRtoMgBtl4NxtgHGXQXwFMLB7I7fwJt0TYVkk2eoDewnxE72JAWySgLj04sQNCbT7qbhZ0BcykXXAz+iQFMdltaLX+k9" ..
	"mTRl4f4eII8JOV7nAAm/zJasONNh9qCPH46gi/y8njbCiKrmhWN7SZUH25NOxoyPYk6t1jKrie1L/QPWbgYjAMn46VkD3UAYBAIg" ..
	"3LYI1qLsvsqHifdMCsHkoUHy2jecX4LjaqAegBQ5d8IgrYKB8y83g+WxDAkhC6318G9Pdkd8Y6WzQIGoIj55O4gvQin1QfGn4ly4" ..
	"dpompVl5lHITYncld7Wt3pPjS2/REDlTjxQdrbJEC2zRL9PH9Ht10+u//gIaxZvB+CI+d75h3zD5RGBp/tCe35QAq/b7LqJ7GHZ0" ..
	"LHoMpgFGkLDAbbQHqa3cxtxJgdyCJsQPJplP4HLbLlJuAHNjHcHIk5XTGE2DRukISfXHuGwvmHAfkoXWwXKzXl1jR9wUB7Q2TCX1" ..
	"sZvT4VwMVDxu/pFoaFNQEJfb7a7nZOf+E8ult2IYMCI9noyRTGTKt2rDlgkq2KaYMGxkbc10cT0BE1rg+E2LvtaaaohNaVoVt960" ..
	"h9m2iYtm9QSVHHBoCorus2iJIXcSCy84+ppt+u5Oo/7vfq3vBrfdthi8Yz434VNhLbyoNVAW5Gxk2nj0xjXo/dnL06s0ipN15YqD" ..
	"GXXXSNpupZmiF+2YegFGfgbAwTfxZtcLO0Clxg6BlKpw+TJIbwVyfTiX8pGogzjPfLiq0ERO3fmsnSX8pS3lqMUUm7V9Z3kCZBJD" ..
	"niC8GEdeMuQhBdMr1THJGFUA5LjsoHEQXJK03KHZJVwkDGRhmsw+D3vCDp116UX++dMv2LFmlnDW7Jo/3K1fGr3eJuNFR+/OH0so" ..
	"LSRqcimmyB8ZR57s4mcz2x+M8OAZIeC1iM/YVlJG5ifxmfActU3yP6gjqxo+GmjZfclGsR3ID5/WYwhxTtPphmmudQMExLBlD90u" ..
	"CLZ2Lhdxv3hVBhT/TyEuDYd2Fv/6sUgHSJEe9Srm0aNUrOVDpTvMY82snGdPJ7g9/Xpw1DlgtN3LM/HlEjMr8VOLRmYlZpnLK7Vw" ..
	"VF/RMRIYEMIMH1d/oHeMpGWzSs2A9ZL952elaoIdRBtdDcD5rMzzJyXU6AXCEn0i3V3VD4VHHg+a8DSq5Kg8Qx5+0BjBKkKIWRyR" ..
	"M3TZKyJ+Kt3JPyQ/SS/QjzMWbqSdTV80+xbDAEhMtLdMf11gTOQJpKVoYlXr+aHekuaUYLeJYtvzGyKYRSVktj4uN43VsulW99Yu" ..
	"9qjml/OJiJsLGbI5yh94WzTN9Mxq7Rgz56Zm6z80gCZsBS1D4zRs0ZQucpCvuzcnzGGk/RQtMKFMNWDGnRBI/jZ17Z6GlJmoSFq8" ..
	"zyAS34RK67P5/k2CwT0oX7x7on/yq7LARjWGosNtjvt/VsoHx6mGlT+Z0C79NaxO7Z58DcopBklzTH+zv5kqW9gjDGRz3TlI6BWS" ..
	"px6lgRcl7aCoeduNWpColhP21zulbqIT7V1lPJhs/rr9WRt5kKE+qYbyr8JEL+nj28pMu+0TYzNZBHZjF9nIdrMSDbG28XsES3jy" ..
	"AJbx7HjLmSTZIyPK9FlgkBYNI/gGX2Lk6EIX5znB3jCusNg/9fY2On1w+1EnZfdAhsE/hcA4nsBGi2Q+PhLmTbMU+AdJppe/txnF" ..
	"7X6Q7sZafGb5DNAg/FEfaz7xAJavbKpvco/9VCdTJaRveSTO9p0c25eQWMy33L47VHw+W/SzD+TMKVfSCjZ6V1LH472yQUvzSkBt" ..
	"MkoeDB1UVWMAZeYquK8O6LbU5j1k0PemElrs9XPOVWhyJKMeKrMlHhkONqtcSKF/bYHtGydShgyvgLRdr9t0Z+UeYFpF1urr//Fc" ..
	"1ybUFKOlm204pXXV2Cf1y0jcdYIvAJbLmA6gTaHKRBuV/G1VhxtaSf/zfVSy2TJTi8tG5RnBjgO87VxVMjxh4LTVQGbIehZpG2zx" ..
	"NLV+wpgFZSh2OuAnpQ7MeTme4Y5MUkghhvvN88HcvJw+dwycedOjvIbPl8uU1bwF7UXG+UV5QVSOkUe/9kC7FcX9RMI8dq6ntAcN" ..
	"pT2/5NmZ3AK7AXA2RIxmyXat2qluHbX+qOT8YFhQHWEKcTBnG7gyzUSZ4bcGwtlz/wgVbGW4FJYiZYuOeoevC9k1ToZJyFoh3Hrn" ..
	"xRtqg+MrpnlkyVgxhr8w3Dcxd4r6qfeAgYeMwUqC0hiVlt8vA9NOumI0FA8DA154c9hbbUsCgwVF0DIO6kbbHXn2szoou9FNZHfB" ..
	"bUWn8LZXe6dj7M8zreq95b3mRHieCCcll6rYvY4asTXLvxJmod3pVj3EmZJXR8EMaVmbUfM/ahe8YbkBwmmsOEx0GVhTIm+dyS9H" ..
	"6uMinQmg09uZKP1PzavK+aacU59s8aPhc0Ck8BY577yWO/YVb0vpjNWUcaHEMpan4JoMsifMGfZH00FRGbuKDRbOVoc3sREcc563" ..
	"pvmnm3ZnDu9KKfB83qgRYE6WWHRKMn7FwROfICvl4rMN5a6eaYkyRz/KiepZtwc9Mugb7SISilmNjdxIBGIhtqBf878usujUVN7A" ..
	"SeR2AFU1AkdUipEoQXVq7IvXrEv06T+00EnaK5Jn3M0fx67NqyFJ1Gc7Sh5cjfdHrsYo8unMIemtr2WHBUrcz58VyUXaAgGD7Cz4" ..
	"e9+/c1hWZfATP4Gz6QN6c6GLXxJ0xPSs5qIsTD/lNvAsCt8TTJCJGNywYOVH3DN7fi7ruAcpc8v1dnYOPWfxDDUWlTyoY1qeReja" ..
	"dW5DTyEO1oKSPIpfzuc6iLpGz/lrRxWtHNuRBDWyJ0QQeXLzWm5JiPSa5owUV8qdrr+YQFWp8RUdX6nMf0Trs2CSIjMccS5MY1qt" ..
	"muma4VbTwpTtoX5F0xIZod58Codf5hN2n69Ixzihj4hJBb3kDhODWU10FjUbxRjiNU91TAr5kh8XcpzE/GWEHsLciN6YXp4dR6zT" ..
	"fX500z8zSiXE6xmkZYGVsG8FheehVP8jxH3tslqD7IF4ot59mJGLnyckagbCW0awgUw/0Kqy2WcAauc5U8r88ooXOgIF8ziKuDem" ..
	"H4u6SrDlTqtyLfI0cvVWZv+U2bFRZReQW842/rM02NrxUqfK7lO4OeWtEhPdIFXK2SFm+/zUkRxo2Q9vPJZTzK4O/VD/RzY1LNP6" ..
	"opzJrj0DMy9iPjZOCrY+Oy/dHtbM9Z1PzxL/Muwkb+WK8Dxz7ssCWR3YXxrWieay02DfmESwEzrra/d9MMGLtM8n+sxPxpCPrO8+" ..
	"vCMaYAc43ton36508kS2W49dZ0NHuBX6zEvUAxqFQmSlUu2mRy95qDvJPtWHblQp19ROeQNb/gKZbSPzFX5wS+uutDBlvayL04bf" ..
	"nx2p5Rz29v14Tk3Bs3DPTP8mc7a4ShP5ykYQZTiq3iuVHHDv8sepqtE0/LkI2xlItwjUHafrViCYh6xKpDATR5Yuudz/IkBjNSH/" ..
	"QBV2igzko55VElDcfEgXbVpYsVcDBjxkYR1bZ1F1a4RDE6ps/Sm+imqVoGQQLWtSuCFGBSTdocNsbMYtthiEUufCqhXjwExSS4k9" ..
	"Os88wWndRAOrTluCx0XrsTaW/f91W3CpN9r9cOD4ERbeUfjNLpn7sWFlfJWnKsqwE1s6wtHaBahiTJmWULpMOJizCeve3QU7xOjC" ..
	"ophHuMULN2rvoNE6gY391D+vGEDZ8kln4uPAXdMuP2+mrDrfMpv0ZFuEPyWqKjFQXzUXmzAs8Lu3LpukNbQfTUHhg0c7WmBo4Ggt" ..
	"S7+zHkDXhcEcLmkEFBB+O+9+v/bIJZk6xRFncPkFB9QnhZoaKt7agi+riITMI7WDYxZuiiVaIE5A5usFg5Y5OvTLzl+FX8RdqICf" ..
	"KNjaJCEIzDAnX7++1DpRZyWTOXz20mYuZVo9bH7Int1eLLtZXjxm7B92E1G592JHz/+iOjysfnVolzqXZoGnx8dnKT0C2AgKMmw3" ..
	"LWf0iwjxXFhqBa433GRVxG5plumUvBj5U8IIqFAhHR6OZ8o0OYeDqcEbGJizKQFEgc0dmXTYYe55D3app8iKybBWSw6yD4DVXLOQ" ..
	"7OhYjbB5MaK9BQTGaaosLPWnvrEJ7RCapmrp6v/gEa/rM+Io4biRfpmWv8n4+XResq+k3LvIP07cyMTfVKjxnXVbUKNa7hSZHYW1" ..
	"Exf/RqdKo2EJo9HGcy2IhczXDt2Kk3lHHNrdSGJdUGp9QLcP4zpRMD/WPZ8oBZcna0/zOQq0yBlhaTG20LpPBneyFGlp8Vx+oMfy" ..
	"+6ktRsnupFl+FKmn5o920ZaVf39SZkiV1YwKp6Cs2Io5DEo1foqoL1O4l7OvjmU9g/gNfBSrQzBMcUlahBv8pFziVFGqX/NtUbSP" ..
	"gNin8FWXPbQcWBxZt2wN03g9dU2Bcwz4V/pTMefOFY6Se6F7PDCg1WRZdgQtCIQRsrL9r+R0z0IgwRMR+DCG9K4jOl1V2YDi+bYM" ..
	"uURp2WEr/9+1eed6FuR4rk6Gju6OBiTjkCFEMqZP3FvgcNVCXh7SO3c1vPyMG+DEF8sBdf/11hEqzYgd001Ms+LNUa9zBPmzDqNJ" ..
	"MTqGpJXIeZnKdPLK0/eAwA6IdB4FHD6zo2z3l9lSt4uroofarUVBAoWrZLy0Rw9yEgZyvIUUAW021vmh5P9GERuKkSqBjbxmDbT8" ..
	"fYjEvVzx3Y4jj/ifB3UNrN12u0TK2+l+shjkMHkT/+ta8x7+rQNffGYi4/oWRzeD5l7jZay6iHa7xWHLRuCdAS4K7kOSoBBSfzK8" ..
	"7Mkp0f+12cIISv6n3LJoPrV7e7zm92jjltguVry7a3jjj311GsSSqQo04W+552bBHSAStOY8Z8XZ+jH26Q/BB6odugEjfDNVNCXN" ..
	"9zDg99Do3rkZUoeiFo4UkHjOaneRFB9r7zmDU+3pudHJHUM2IMGxrjVJBtyN++ntiCqqX1S+7lX2B6qlklbccV5tdvGMC97Qpbnz" ..
	"PWm9qgWfG9qeeEbuJICyG+qovfQZihJ/4D3FXiCEgZbztqXe2WzcYPiBXeZZ7LrxtSHVCMP84V/zF4CPRycTgXWXgKAOC73irh5U" ..
	"VGwBYX1Yv7XN/z1ufjEhzQZoUTIK+tq2L1z4qUaLU/U7FGMrmJZgqlho9ua7jPALX80ag1ibkh3d7cYeb+JGGF6UwoJeAdGSedvv" ..
	"qe6yzxHipfgCxEuxGbgdhYrJpFQSYI8JRJ5kODLq00k7DqTrASPRjVL8Qo2+UemKNA4DYGv+euEuFkBjRK8fj8+LAvQQtdV4iTAB" ..
	"Ky7f0mIYbdZgoHGrVr8ZlK2u6HT4qDKrgGU+8QDTBdo5FMAFxUEePSmO3pDDZd0ZULlsF0zZjUX8ADYg6vu/ml6w0kzbcJt36MpC" ..
	"UBEUNt51ojYPygB+Eo7q/hAAAF45waNgE7E0Lbc8FQrh4wfQ+aUEsBfaDqrAgK8wAVICBHro/8FTe7IK6TJ59gUPKVPfd10FkhxG" ..
	"LjF+MTu3IpaeLYvBeEhKcXMUVgDqgZDp0eRlxeUv1KN3twvGbIp88R/QzGy7Bn3/yV587dvy48ashSKg+FAi7q3RHzjH82ZNowwc" ..
	""
local PAYLOAD_P2 =
	"uVOYJDXVonmw60qtl1CeIrYtsZozSO8Ddl2vBqjea2JrVxdUo1P8CiaWQE058YIm9oypMjPqIM+2U0Hho3WmznjJUVhls+9R8Itv" ..
	"bG9c6VO00gz3M027kfHDk83kF17zgV1P1egsE7e8c68RRDg8NCuAb3kCGJEqrK9L4OoD8bxR25Uf/pm6UTVXrZFFjxWFUnRflf/p" ..
	"uBaKW84ciYX39valBFazn2IbJDGuHdXNiMYbzNSzYwUbyJmkuxUYNWGLShGe6uxDh6cQWZ5PHaJ0EeEbDjWO9mKMgWq9ak3mJ2is" ..
	"ouOKP0l7ENtuDES2GemCT4pxh1mQ7dnMAIZVLFhffhCirYSpZwJ5fwM/ahNSzfvtZlJD6shb4yIgUIozJs24WrGMINCp3sL0BxqY" ..
	"hs4EFaw7DNVY+iZ9+cM9Lskvpgfj3RCnAtmBuLP8fbvCJG1oJn3lLUPbYMcAz3mN6I4vz41MEwxRUwuMXAi4a9BZ1vpFsgXpH0YM" ..
	"jNtNeL6h9/B1rwP/Qloiij9lh/LolU4udDnAGkNsyV9etnZ7SayS1vudMXK7uQw438GGMqIDOJThDfarcrTan5TfxpwQmqQrdkYk" ..
	"9977M7jcozZGkgf/z/yhoEayLSkctP6X1ZALEtk7yj3hHnHB3e/2DxZUWww4zIXPa9YBjcLlDydD8Y1vY7V0e3gqOETxVVVj8aa/" ..
	"7PoFl0d4hu8cyfi1a1YtZJhOaUiyIuBh1sQuNrrrm+8KJESgEMVaFm6PL5O5M9lc3e77y43AeZLapPZ3KEpySOfG7KojqYWr28N+" ..
	"P3kZrg9jdm972VlxYo7dQZ2Ui/gIq7y0S0qUr48kKSwe7gDyA4RCnrkmdoPKdNrii7tMapfjXIFy5/hAl9mrUPc1rS3doecoCGL1" ..
	"nCYUx+QfUjZlZry86GO/5Xzq2O427zmXz0KeNtqIL5nn/9XuiFxKFwrKTak3G/GHlxVI5JYhkPZ1b4E5aXkOjgZ6gcFZgHy2aGam" ..
	"SWIWJcQXTIEfeeut3WR4wGpuqdPAlV8PgO9MU1I4fEfw1VXM1fRPcrK+Y2qowj+j+WvzDrmzLvjRCoW2CI9+DSsdmXN5iR40kR9b" ..
	"/HXqFfnQKk34CPvpn9pzkzghCkOU3I47O2KEgy5KNDczsG543ZQZ+BX1Gd+hLB4LFbLJBr7DPULCzy+M+UKHI8j1MsrGsXI+TAD7" ..
	"ycmfhJs9oXnquVW1k7xOnmkYQYUCSRhekt3NCn/w7Byr23V6oOF5cQkLjwtA07btzRnD0d3Z4XnFXc2EdYb+5+yNmYR2/0/zwPda" ..
	"DPu5FIogBjAp84ZpP4E0ImUuYvbS1MNiSOCGrlDddYQkCc89mNn4OetzB4X+WhoZCDBgz8uuHjTMOlKqwQyvv1iABwsUgxcxmGIL" ..
	"n2s2QV4MVnqVp2b+/V+YV2bk0CSsXQlukk295/0q9q4pOA5cH6PGMXDvxPcnCWNCtfX009XGGsdS4qddWoOO8r1hsn827ix2jFSN" ..
	"v/b2fPpZhvWzRW/lC6BR7gitJYSCzvh80AUMDZbPaXypwkbMUtW4b4U5XwQiKAHNHKZUXwY1e4b+pyAnHdoNtm9c/zmfStdTjwU3" ..
	"U3IJUIFIVLbiFfOqQUxLfktTZ1863vCkppZI2RsONZCbAtdF/4r0M92ejRVrqk+3de49Pc2/+ZyebOxqc/pmVMiog8fddp+AV1LL" ..
	"6OqLyt64X/fH3lX+pnLJVmbwiX4Q/8mjGXiZYUNy/R9dz+93iXZzZTypvTAyKyXy1rTE057CFZdSYpoMhRHEkZg00XhzNdYJMOoh" ..
	"kU1Faes17PJX1HFz+lOSx0v84XRAhYiohraPYt0Rxutzh3ZAwEBJpPZXnFSp75BhQ9Dwf5xm1VP5Pr9LkwSWk10pTylakyhdMZqg" ..
	"RbTGZkoJU4JTGI1ZMRphDApfPW1W2qeTNTShfi0LeOr051ypBYiPf+1yYfa7A/9I9b6tGPpb+dscwPJ9sx5aeFDCkdZ3ESXgGHu7" ..
	"Lzsn/aMYgjHi4IlKXbylLkYiAx4KK7Hf37XChzLiJFjWRJut5lhOIwUV1k0p/CR+vCeBplhQql/JIiCTRTO5cLaVDmf54neyHVwL" ..
	"TaKfXdg9oBKENiNB4kqZOw4Nn0xpGWCMsa4NJ4wL9L/iDNEZ/025wKnJr9TpgUGLl3Vb743vbQCJrryXuJNgDL/62J+NGOCJTsBy" ..
	"j5mttO0daBdaOpupM26M5D9Wq6ESYOQM0ozdPHLh+/TpTAU6zdV4OOhcifEwz25bFrHCn1Jz3AifKK+LymBZwVoZtnGnFtteZt0c" ..
	"yW6L7f1QVZKPP0Q14K+JH2wRyJOqOI9WbIof6tIt9GqwgJ6NVqg3NUJh/d0TkPTyqg9sTHp10kn5KFSD1NtyG+feF+lVh+ZixL9D" ..
	"PxxvLBi6H/HRb8O+KgKiQgmun4neT2Dk9ahmj/HLppzfk0a2FEj/2Hfg7oSjrPRluM/l2n/jPXJSD/R/ZqqOI4yOuU3rv1uVhFFg" ..
	"3LnSqqNvpdUoT57YQHXTOhaO9xdqE3xKpTeOMGCjTL+jLqUrIQjT7mJ9IxmFoPdhZW+E6Ip0cWPRHMLrttOAGlQl1BpohANopbUd" ..
	"rTd5jkGr0VCSvEjipiZxuBeSgTD/tRH2t/cn3zpW3fhZCE/P0Bamacrf7VJFpylbtHsnLJbQ0rhC+E4njOQMvCrHfmnVY4lFMFsX" ..
	"oAOsNxAMQ9azx+OidC0jFsOxEjKjwT6ICTZEC+qS8yzY+A2glqzOc+a55O67A/27EscpKvwd2y6I+QzExWOxprCVq82AxoGPqFzE" ..
	"bxhPK03NFcehwA1JvBx5g9+VJlbr9JNEKrTY6MTj6yDFGFNvn9HCAJxQwkaqo2dZMSmD6QIMmjn117uExWNmU/XzOZaBUXbHp3Pk" ..
	"akqUEqj4YCTgU0oG/dOFI9nFm0oz7zAK3MtwufwvYgkazu/1D3Kb/mZo4sT9kYWxzX3qD0JqQy4aVyBKfxwScAhXn4qVDJe+7z1K" ..
	"rR8wxWkwAID6hasCv8eaT07Cky+hP9PyGPSzJcx3ySoj7qpeHDO5CS4vfnOOJhzWlpvm8RgqK+AJpe9e5D3RQof/ii4ERklHg2ui" ..
	"UylHwvaxoJ8b5qqOAPiQjM3W5YltsHnnE0xBj1vaKGcYjj5tjrfKoYgRhZ2GAk7BHJ2d8dbEAR8E0EJr7o6RGKYiEcIVs0orso5X" ..
	"C1QC0AAsHgapAZI+kDHW8zGksQ0ovWJOZCd+UUe902nhZJmk4N3n3yhC0Wccw7Yxh9aNkHTVX8XK9gD81/ZshcxHWDv+bAM4qxCM" ..
	"SkM0QaQsytC8SYOb+DIqnF8GNeP9MVBqiqsJTZah4AdY+GWjroVITHGIgyJWWsT4Wdu1G9HvgCCY5kBoTjuXlqbOZCOXbKMxA+/f" ..
	"Hifomoot2lRt5XamLt+l5qPEEP3tmv2buQY2kN7h6tcBM7cg7++2gNUtL9jUaqacs54pWdzKbKc27KdENxXk0hDJG8tN3FaUUnxW" ..
	"90alQtOLcA8nrzE2iL/MoGCXCoX3TahRL1avAfUnfHqLCaqQJA1TKZJvZf6cekAizIxwEsEqNTdPQSFty474ObomBWErGicbDc0x" ..
	"22j5O8xbO5vV8W35IE516NlVBvZQC5dUDiSpEnO4NYRYuiQ3x3xEHzITTGI4Drhto9kKkAv0vNnLZFAZn1JirgPEdah0nOOr8tOI" ..
	"vqaFawUnMyvecPmVUqSiRZbqYh/9elvpa44JWESlB6IrFdjfEaPPj283pXU89c/sCLIqjt5ebcBhphArigqIjgWz9FiFZINL+h89" ..
	"GeCkl4MGTIACbjFWYN/U6T3o0Aj6ZZA50+kOUf5BWOiHR0onQMQQOL1haWzz6s3JY2QbA5yIqWXfKgEqlbbaZqBwOYN4rMHi7oET" ..
	"ucupJcA+bROUJsm8eDnDc0P6An5QX/7Gr92HhHELvcKelEgkX8OK+Ab3eYoiU7MhduSuhcDDQVnht6QAOILp4qNRvSKcU0b99yNw" ..
	"7uPwPu2scJ5gEoK4ugdZ5+aWal3fHWvp4EAKTmpCPEEwWlmNdMKBhBrG6tb+dO6hzIyW51jb4u2HzWE14dX1IFNwpMUDKKfKond8" ..
	"dvy3YJJnpcunVAMAmH0p6b2NpFyk32KRjxnlDp3yyaQX97H+v2d8RQUvaJcsgRC9wpXULP5jKo3ZNenVva38Dl+mHHfjyX07HKIg" ..
	"+wf+1DK+vV1FhV/ehhD8za241J1zLyNpo9BYyvKY9BUGZtV0OGxOu1M7YWn4jwyGXBIdr/OSGRf6h+sCSIBllGypJnm5odYK/U7u" ..
	"0ClxL3fI0O/IBIdSAcWu7AWqWbOp1lMgXONo7gOg+wYUXdnIiZlT7219EvBA1onXQbDiankID7IJVuDj79TW2FmUOVV43HrVqiye" ..
	"46xyLB1Du77z+ZS03E4Day3s8x78xiNaxEFhR0FkOZrDXJD4dKno8Ff9hK3m5baoZv+neOAvY+4DZ38PQDBKgRTG/vows4wOoFsy" ..
	"ZiUIwQSu9MfqeLfaTR1RoL7FbiIxbx60xVLgJHTsJAv+Gucnk8vQS6yXHprpK2MRL0mz2cwovcv+YmaLwZJSxDwh1/81kAUOPPhF" ..
	"2KxXs37OtYhIG48TMzC/w7HAQElhuc/EIdKVnQUE7S4W+4qo4jiQ1eLfjx2Fjs+HKvtGjYFrF1F/aUW2AHJ4N5s4r+Iow5m1Pd/M" ..
	"0fH2xkCzdm+PvAP2vKnDzr2gAOYiSEerpdNPQKP460kVMtww+vCKi5rPphOE79gKRwCj4ZqAtEwtcIYPTsXE25nWGiTcBvj7rOvB" ..
	"e/+bNWyQv0ww81yitn10H6xW1sValhMtF7D9/ax5uOn13bR3G/t4a2EZ0u33AvW5xqqNFrdgjemXl3K3qaR4vGLiwcchbI10C+cD" ..
	"7mZd93+3Qw+aLT311piuOIvYGgtSPHsE5cqnwFphs1Try11r6iqEeg1k8FNVw57KtYBcSTmaWcxmJ/19St1/ASmDPsvr1dlo726V" ..
	"gSZRq3bDu/mFelOXr14LrPApL8KPgCm09DqteAeEmhF7O5dKc+cZiWgL043SzVM/M3vBaUZCV1qtOyyEqjWkncKYWINbqrXLX/Rr" ..
	"x5GWzpjCjqW6iRpUFrk6VnwPtJ7T8PrmjSMokX+aGT3Z+Jt/EXhtfJ4wC/9toFoI/bOxeW+n3OEgODEttfUO6y+SM6aFzRTYLio0" ..
	"4cSGB/yhQRPXb1T7/oj7kXhXPKjRNArG599yeaoz/Di4WEJcRho7CvLEuCq7sLkVflchTqQSFktqMXSQaA/xTlYmEcVIW90WxJiA" ..
	"aseg3QREZckIzszX1xG2Cynq4CTjcfPuIuiBVNaKiNr4WX5yjceF9wTmP1LD3LRSOl5pbO+/3tkeQDSjcg6qpgUyUWjd0zy5JzDO" ..
	"4IOHJZelGG/JpzTN9Ul6cPBIAGwivulDa2EAtpqe8BmscA9Km6fNmKehwNgepquCo1hxR3TT6E+eUPIaGyAEhB9zgj8AV6yEBzpx" ..
	"w90ruFRkee6zDatk+YU0byOSsHcqtlOIqaGz6EZulAw7wjuIgW/dig0QyFC9K8l4vmIaug5Vy1/6gkuL6NIOicNNsk9S1NSNGguL" ..
	"ueTfNXgC9yP20nPMj9ZkdznXlMk2iMuAKkXgsJr52UCV/Be/asgTQXot1vSfGmZ5giAtS3CxrrKQgeje2ra/AXTr7kcVpJYRmOx8" ..
	"HI8OqmbC35uUyhCmjlX342t9/SdC2gpOva5cBwoW039x2dUSA8U8EeGg4LqyupwBkWxQswSIil5SIAjqzQzDchJe+G7p7MEVpgNE" ..
	"hRS9hz4/ZyGjDE0wOErGagFd7Vqr/ZIHLAmIYgYS1yvZTOuL3TKYynz2vgiSIZ1Z7CYef4tjit0t8mYwIuCkmui8xW+whPZl+l9z" ..
	"XFwULnXG1KHUQ2vEXI0TKqJOph2xsMo7BKcs1w6JNwUvelQVjuihvuWVYxwTlF+s+9t0D+umLdMBcBRQvN02ICT1KOAi4561hMLc" ..
	""
local PAYLOAD_P3 =
	"GsOmDspv6YdlVLQOE/n2a3sgsWm7H0Xm507wfZJV/4Ak4fdLU9CRxGwt0YrBfrdy3kI1HVgtXm9ytyu37a4pUHYG54FAQhHU//9a" ..
	"dv3/8PVXcpj9A6tTBGOspBStHXzuB8p94607+SCcyFlBYcuXgKaN65ztLI+qPoqDrx+ni9cKl9eilf/8H6xLr+D3Hku3fYj7TDj+" ..
	"lD4d8GVNNDBq6qRWFzt2EPDWTmvbsu/7Js/nSnq6ZhaD3XSUn//D+yoYT3u6pF5ZwH2DPfOrajuuOtDnuDFg+upa4mHHO9R6ocmk" ..
	"jd5z29dZFlTfO4yukjjyQZ8A5WgC3MP28Zk//iLp/8lUckqRRSgAf+RCPYDwJri7coENVujMHr1oAXh6GaUOn+G9IQQCDu/viepB" ..
	"WVeB270gl09FJIQGHdPuY85uqnOpxE/Zdh2eaVBh1tKG97TiFFDVFqhxNfuPcz0gFNiJF1eMjjznlWpd2Bs/C9RWB6rGINfptPTU" ..
	"wD6Arc1kzdtB0Q9RFoL5enG2p2NreOoxNTSY0twJOLJfwNGlTMSIVizFy0m6s2acIIoBpX6tAvAioDvqg47D5z/bxlhNJLaYW4h/" ..
	"aLdFC0X20Gr0tSA22RqyFO5Ct32NweMBrZJCd2T3aClDfsSHzyVdnORZP4NdTvddPNrZzBOi4oKVG0EOTW3j5rS8c9/mdbknwQVB" ..
	"/BpaUI0Rtcyr+RDUw4yBhIngJx1D9VzytMZuLUZq/L3KCAJeMcfWWb3k2kHHHCeW9xkKEThu0i0Ozba8WBYGa0lJ5t7+AiqNow0E" ..
	"G+/cVj5OdUGmhPFEYYgZrS11PdJiqXyoiPtln9ddrP89kNcNtBRYXLHZHlGoDvzQOzJJudJFpUTFM7m0Sf/Grfng8aRGFWUsVvJe" ..
	"LxEWXhoL48jSCELelxwFadlCZjwF1UyJAjTDT3leKwp+sqKHBYeyRZlokG19EEFH+Rtd5ji3rfWSuOGwIfIIUMsy/vyamf7a4P2p" ..
	"V4y/y6yRITN92IKE9bAsyY+460kw8LzVb9nMsMRLAVSYw+ocZAHuCPa9n3Hr79f7sQqnR+gC1aE7/SjqgyLsa9ypJD1iqfV+hPdT" ..
	"n129WAgMOHZmtdACwTV87RBSSyNhs8iCONSh78z2tRtKKFmzggi2VJlcdKldCjsfj/B+4ZP6k/3viQ2xJRSf44b466WUn85vW3Tb" ..
	"oAQMnilh/wua3/44EVIIJZl5u3Q0qbAjO0mKUkktEBzuvlrcP2ifUp7xMl/Eq+w+LkHpufK1z/yGABiuLYw+TSk7FJ7bEOS5eRAo" ..
	"J+Ft5J2FJvo44FXBXzSuBFnbCRtwwUCEvQ9uicMM7ZBFlFJGUNw3msgvtIKHjKtTPT/z3b4fpA1eIIhcHnonBVvzgEWilJRNKA0Y" ..
	"zhOnb+edr9dUxWtXrQvuH43QM0sarYMwV6DJa/qR6Gk/C9O2asmY+a3ZwByfA+vq72lC04g5248bqocpuMpYIjXWxS+BKKJ2K0AC" ..
	"+SKQz/Zr4J7BhRRaRmXKgJvJwXZNyJPE+vtgcqjhDdZRUo4U84dP4Q+wX5JBb0YvlCOMDu9IBcsz7nXvo0sA1phmvh5X0kP7ba+2" ..
	"OHG3dE6W58PBvTZV9B8x74OFkzFEBx9cvqSOOC8OvRm4QFGOnAR75QwRKvG6ej5+9OABmd8BipvXFM/7i/KoAgTd0+fXjn/U6s/i" ..
	"jnGZiZEgucN4q2jBonnjAS3F4pmnQpSF89D5eJcqxyoZ38LM48SkGYjq0/ijRaBLZhr3iFTjfnUl1uoYJA39ri+c/qtLPYroAlj0" ..
	"i//F8slbwPA/uSNha2ujkmeKuz/2MScMUpj3fsDUkS2wejqEH/BbVaLS5w4RtfvlNkumyGMffT8nzY2KVM60YYI1pcCpTGRlMbwd" ..
	"z+Jtz4FI5BLPb8nZfb+IqpgKR5bmg3jMIpI3e6B+F0041kQ6Mg2Z7tcg2hWZOPnQepnV/AqJys4kUqNoq9VhLkYSGNqAzqPUkWuO" ..
	"IlEQZR0dqyQcaEGGyfkDsi68qOoVnwLmvXJo92HwPdICtYG5UMWF5B/f/n5yoGK+4Dwki4cCM5ixQY56E9HYB28GjRIx3CoaJNBy" ..
	"jkKel/s9ob6uz6tBug1DMNtTrtEAmuGJQEzICXn9b/VKXSiSk4uh+NXhLNHqH2xKAY2ASYQvozS9/E8aSYvPNK9AzAvDB9lKtr52" ..
	"5N8FfATJi/KMDaik8R7j3kAxu+L0/6uNiJB/EdKWfhINgOj6VlTFWtIYVraB8hzMQyZbKCeD6RY38SIjP1unt2c6I0wpwxEFSnM3" ..
	"pJiTkzJRJYg6/jxKg9m4PY1jOUI5mw2fxPLRcTYoEcQyY3dTjrdxpd7l/997JuvkzY4AQ9jt6ei3vj9bDID6ELYXqncaMzYjbMv+" ..
	"2VZocsTrWDs8LGFmFbkZB3zFP4j+lPf8Llssds/cO9cDooKDG5TUBr7MjW9dNVSZGCRzN8jSD20NigfksA6Knczin3iTpbAKARMn" ..
	"3RXEOeKGODtYp/zEY3eHKTbqg2L5PjQIwUF2kKTW5OVq2dAUc4yhz52/rrtvTZiPl/yZ/V2bSbA2z56rqznWWKPaxexZk86dY3DY" ..
	"fZYobne8byB8/o1Xit8MyRw5Wny9jacGXE6m8YRhiH8FFfe0B2V1GDczGSSRLx/sP5cr6bHcFt4fMH/ZIxY6qzrVugbTh2Dfl06J" ..
	"teTjdljlVtEGjqNtc+oNP6qOVwIOV0aMhlTMKFDSgQEZtbxkMTzK4jgrgnNNOFbwOOYSPdBAThB4oyv/bnUzRCShy1dbZJKUiDLw" ..
	"2Hf0ofmivRFqzJUmDiRwm6x3UPY/JpK7zLs3Fzm0RjKxzPithCePEGbnGffCwnwPiHIhO50eCuWagBkIf2FIkkyP7Hfj4GZyXccD" ..
	"Upl4pkGz63TGUzLa78RxkVq+HeTkre4BseHv5hjTPvXNJiNfcoB3z1WFEEmrk2FWce3KAYnmqcOgpekOwjP8Hlec7prRu6AeE/FO" ..
	"LCYwD4BBA+b1+x+daLNTe2hEVtZGJDduKNyFH1y+oOUsOP6nTGddIhRkuFM3tEN7pB2kygOBPD3U2ae/TR/F1/X8QGbuNPf7paV8" ..
	"0lnLpW013le22l5m0STn2Q8qOGrU/mI5NtXcsUpe6dyKnir3RFsYGfzWRCp1vCIvpzZn6qoyx9JGaC2RCUlFH3+db4wib7VPc6PN" ..
	"0yjCNCIJlC/GRu5RgiO8cOZMKNez5HP7zVAQhk55UGsuvrj+r/i8ZAO3zY9SK0lTTT+8TE+j2zcU37PsaXkBUUvgZZga+KP7ZiHi" ..
	"3I/HYPi9ZrPA4RX8maRdIPhN5PYdkcY9urrS+zY65outnpsJLq07gaFdpXyGkHV+MKz78Z8RNYyScKXN7Ye0HOlRXWNDPwBy0VPC" ..
	"/4Z0533LC1LiTz9j4ubeIZOc/C5/1ZSyzNMx1aax9kGTgn8hhXVLCO/vgGk+t2/qPUA6y6TiOlwaW8P2DX7Fejk/e/nC55Flk6F2" ..
	"nncBPpBK9MWQ+lnSzhctdiYEVWRDl8HR4cdKJb52O7oMiv1aOskMe+8jUwAEwLU/bAmJT/ky2+LkNcuY+UAEveZ8qeyOmtRRoQRG" ..
	"gMbeLvMcwgZ3kczw559NdcHuW418G2tIHGVEfzgjJTetaL+GZhFmYa7wt5wwNZGJ3worpB9hd97626LVM6+/ZOMwEFflnz6nlk1t" ..
	"bvU8aVKu3wo1uqZkfDQ9dziOUWmqESLfJGNNoniB0vVyl8c/Kds2hFzHjoaIl18MtL5OfCqoJPt6gmOAjcxBpv38J7C3LrqkcIin" ..
	"9ZwUjkcF+O0e3HbjNNrJGLLbb4fawg8YMTMgeR5uBegQd1X5xjTdXjXS6iEDt0etCeuO7SVINv4nyGb1N4Rwnx0Bw5Xa3dWd7E43" ..
	"WyyXjP40N/Bd7GapvpXs962QYZS/v83PBtIOE0oECzHox7YGubpEZcjbj5U7ek5uqXd9wJXun/19ok6Yunb/3fXS2oH+x+pFd55I" ..
	"pjaKV4ROFKB9O4ahB2rCA2Eg2Z0KIO8imkgaEiWb/uIN3zjxS7WwiIRFOmzsn43bJXOFQliv7ajKZ2eFLP5IJJA2LoI54eVLDnHq" ..
	"Tm8gzgnd9/19CKviWqpPrHbN9uTPA69hF4fqSUoUI/Qx4O6iN4+28D2XTnlPB4RrkO1r8n4WnbYj1D8DjeAIQtD7L5deFMLXuhL3" ..
	"q/zH4m3qrfrm5/0vM6IPu33H/aEvfWe09jhxOMtsD/e+OtoNTicrAH5F+Em1O5kSA7aD7ZvKlzPZ/9ugrGQSa4MqPIu/kfeL2dkJ" ..
	"KUjf76iFv7l4Q3KZrdW+Fpq96JnCsISXzOImJBn0yC/2wbLr58XVo0LNX/iFlRrJsiLhFA22VXv6KoyWHgFxDElWUh/yb9j9bl2s" ..
	"LK5VDgg13SP0y2KX5dv7LkkE86aAUMH/O+F+GiqRQds0qkJAE4a78wdLNsDIuBBG/3WiB8oEsjAvHZBWLWDXA8VLWxfKk2SgCI9N" ..
	"ivVEPe+RLqiUumoP6dvdRfJjtWC/PXO9KE2Lw4sS6aGVvDb7EZK2P3q6mUIDvhAmNtfVbzk6iQV9tuPyuxJM3qI9NMG5JlscQK2L" ..
	"AbknO9DYbcCV4JdReuR8BIdOjH64yO0Gul+tPU0JQL0ZIIw58uQXo8JEVK0Ad9BlEdXU1VFo/ejiQ0Va/HzJlkwZhdQFrwM8eLq1" ..
	"xq0jATRUEGwxWD6rOjinaMzpiTcvyny3AexBsFTOAsbfBOMLdzxqOW5gqH94NSM3fbKLNzPfV2yvG4hhwLh9lV+S9WRjRppfUv/k" ..
	"pW1QzeqR+Fsn9J954EmGtMLjEqzmUnQAQCyNH2HOIh9EC3bDRatYehW7FeeIlOz1StKFoT3trez0k0dhrJgw9yMT8Qs/AA1Vruvl" ..
	"rngzZJBKIGWVWC2/AUknFryy33Sv9S/lOIG1M6mfiXn1Wq78tbv76+8FwOZ6T4XcyL3GYNZvuVKm6/7R2t7B5oPh0khvUr0LkVO/" ..
	"NSVtf8vjaVIrTfGO4O7ES4ncc4bWFh5hZC1ci+QWGgAiH6DBAKHlVgAphzFUsOANKOI3j/YPyrneFOVLlx25MMsyPww8NKzicf3P" ..
	"A7wp6OdynyN/+M/SGMdMVqfPo/rBfHcZ7GAC5RlW4/k/A8t/SxgQewns54InFaHaXNnnLYlEd+KyrDbvZKN52nwm+nfxJFWbBZlq" ..
	"PzXWWOlKmPEk+Dknw0jT0ppTLG6T0WorrLl/aPyBTZMtkGK8I3aQEw6FAPq/6Ll4uKVQOMESVPuYblYzK1VjSZHQrcLAj6iSk+U8" ..
	"MLQSvkg0CwmmMzTT5XW9JJKTdHwgu0Cowch/2af2EQCjtUB7NrMqW2m4NCB8Wk2xZzSuAp2FzLr1rpIQuZEY7ChALupYsoM4X0X9" ..
	"O5rxOL/TLcsmMj2QGpvxh412qYe7mZ0x5k3bwcmK6kZCkI2xxnYBhwdVu3vaMsHz6EeiFi3M/tdv7/J+NrWzt2N97wvHjS1vJlZc" ..
	"xN46sixLTaonGsSX8LpIVvc21mlY7rCpQiN+uGT/66fq3ockDrM8bTq3aKiVZTBY6IfglRJ1nJXEK1Sj/zNjMeHXgoCNZHDoqU/0" ..
	"edqbfz8JUAOHeBYppTUB5yg9b8DzBGZz9efw5euu1AfgaGax+LTatkrOv6kn1fDbowQFhnYQ9Z1SXzN6atnBgzco1mkIJ5lsY+J7" ..
	"ceMghD2dAqiHE8vdsUhi2B7HOPO+S+ZGCt2519nwFbKXZamrP5Zrpuoh2QB3MGZsUMI6uEoUDVqN5p9pCcMeNYSYSn8i7Zi8BWr+" ..
	"miP66nOe+wdvipdJfusm88aY6PbpS1vEdkx9KEJd857tjB0NEtMCVrAqZl+5kavlJT0HF/WTzLhkz3xsTChJTAgMHkjKS99FwEqL" ..
	"cTqWseFoVCS2//9vLzzlVTt9adRVgeHeHjXCDwv4CkwfVBC6IO2Mxi0e/VerKRCsopIsEx+samNs2xR13vrFmG3b9WaJWv3gIyCX" ..
	""
local PAYLOAD_P4 =
	"ZRP74cDOrF+8UmqqrVmGuqg9YigD8MNqsIEgZ+nQIa0hFSWj6CNdJx5JI4h8z+ckZpqFiC7R/kP4l2rTwC2DZYwqujoDMln8VutH" ..
	"RO57D+Q+1PKVwZsy+fBTegxrS/EgJXNgE4oJYoI5Jq/vNw4Y/3D+L7cL5WmA17B7lgaSXWkMtrd1tMBhyZWDGwojCwuPhKkmahIX" ..
	"hK0BcLxMzEXnfvaPKjyJI5vGbhPxi2/EROzZOrus4qRi2I1RrlhKoA/D/qxu+wozxDuWPA10/M/ppx1lNisAIVUB5rV0yPga2Q98" ..
	"Eue1nZAay+Xik4645nYrbhsv3ypEBTcoUCF5K5dnCQ+babEBt5llNTT7Xtf7xafgvyYyEcAL8qwktpqAB93sqMVYP7jjI+cZ7919" ..
	"Crd481ijyvR0+r3lsDSxkRHvABvJAqLTylQZvgou2EJWKZ5Lauv6OJoLJX6UZlJyYZ9lUokOvvdpiG5tvpz3AccaKN+okP68glJY" ..
	"mwZVZ5FQ5SaxkGr4+z9YjGuyCwbwYI/Ej17NnEFjZIwY4A/oEnFLKg0i9rOaNJNwZOAYwrXQIjrJo8fmF5WH4Mfh53fr+oOrHso0" ..
	"8ZqmnizzdAE3dLMYy7FJ90BjQgy7u3KRmp9ITjzeTNFqhW0FQJexCLdQuSzu3dmjU0Nu7qcVCu6lccIUtZZ3oN6zPufK7rgo/88j" ..
	"/ld+jAlDIsDDB+uwMW/MvVwG1MF56Jc2HT1tGlsYP9J1Wm085T4KGW464VSlvzep3Hp4bQCJbUuEX7J1F8a840JE3XM/hynqH6pP" ..
	"d0wnAezLiQ5/YYotTbz34t7IFt2RVTSvYBr/QL0QavQ9OS7kaKO60fXXb8ft6pLp/utWbi7jz/BJ/YkGUGwtvj/IidmMoJbpxTPR" ..
	"8c2kUHCY3xJXlNsCoK/jZ3HzN2v0bxVim8Ehxqbp6mx/2OSxAORkvB0Zx13gQpsDHTB/TXyxFXQibcyp3gqoYyRCL4ti8SbPHm5j" ..
	"0GRDAg72uVP7FRnp04LIzncPhF4UkuEacD9Mw0LRHwIqW0yvVE5d4KfugcJoaWpX8kZAi3jbr3gBjFY9gE5ygi4uJwjwr7lhYSlf" ..
	"XyAOcTRLNd9OJ8uvULIJTOIMa3DC4K12JqL6ehgykecwU766up007v0350Rcq2jYlVZtR77f5ahT4PXcabANF86v0e39MKMKk6yf" ..
	"zXow202D3SdCfHhpT+0BzYRG7roh6NubN44zN0RgRTdCJP69rKupjuPZrP4QP/2F905fK9sjLIaa8FMfpHYhzZrRW9yLgTS6xpoG" ..
	"IPA4ASXwe92Oft6Qe+qMnrreZHhFiqLIyP8CAfIYM19a5dvvv/Cba5UugGRPzlbCRtlNV/seHuG8qSDHlUcYuj8jxrYPmea5ZPg1" ..
	"n2nzW3yRwlMolJgJqGhAXE7cx1xcvmu6QLEXDvhsCKo7/SMXlOOLhHIoO0Pb1lX4sxGqaGlA6UXjvqAIoSqWY0jFNXk61cMWf7IO" ..
	"8nEK3P7nBB8kLw72PWriqlZuZhRVcBCk6foK1+AGw/TFcky/McT67g5XNpJdzhphd5+RglmYjpZP7j9K3MdbMBLkJTCbImo/NF5I" ..
	"swPccSor6MvFkH55v93wb645H/PbNDnp/5Qs93xpkydaVWLE6HPVVKvoeMSFZyhN1xiLg+PUekREWIaKSkk6sCW9DkMICCZ4+Sg7" ..
	"KPI0jVmILYWv/P4VGThrXJZmWib/yTOEXcnOYv/ySj22VeXGB5jOMDy3vRJPz5vro5JP4iDGb6xHqvh/l4rufCH8BaFSPGcKxvj7" ..
	"EuSiPifMO0/WyjFGHWmOfAc/H/Luxc5nYgzgkqcxRzu1zCILwWAR2XxysGqhAro8ntzCmvy08tQXEEHP9dq1ANXaqZKz2sAMuX/A" ..
	"MUoggz1JM0xdlCZ9vSsKEuL3diJwR9B4svVkTW25jMRBHeMO9POcAQksZpZrd9/XCyAcpjDDkE05/amS2vIjX5hd8DSK2AoN/6O3" ..
	"bu87jWaskV6AZWiaqZF7BcuwnYmdCcJ/1AoDW4RhzlGDioEMkk5YFGBWPtUj9rhrtMELnd+rvPpRDWTs6GdAcxcF9ps7DVwyHLN5" ..
	"FClYDZNeNTvPCS69A9KRh/vPIXzRiKGPOh/NpAeABnmIgxOiigxdUSnIuVEY9YCv2wjET7lcJNwT4uCu3kDQzSdw4PIPsW4OW0X2" ..
	"IOsx+WKUR25x7SYjEbNWArcCRYjibtHEBDYvb/I0mk2gmKKJd78LS49wCn72SuO3xe4KVfH9aN7GHi7diCuFMR+bt7jikuuTFy63" ..
	"CL2k1CTrwxuSbX/GkxY+eghdJzhcAwslwRqbq1UAj+qLx6admBS59IJfEo2iWJXac9YEbnP+lJTY21E2yeREEjzczoAvOq5XHdk0" ..
	"10kf8rOn5Amp5XJ2yg3OIhZXCGi93IDQYMW4/5dgl3OB6YQLfFDeXhWD2MuhNj5qeAAch5wShcSnqKPcc+b3YK+NdhFMYwrUVYC3" ..
	"1PkGs+hw9NIF4uHg4DM1gr+BvQx7FlchWfkb+UQbf2RiKvipeiflYvIBA66aeSu/VRQkR3d6TRHA0KOH9tsHp3evp99IRL6geBhe" ..
	"RyXAK1aNwAUadwbJZL77hT6H+SM6Zg0iIQADMgVMTqD3FrAQKcUYl15f+mf1BCPs9OV6+PY/EQCGn48PXA4sAr9EhjUYCQC5jr28" ..
	"7aPlykrgIYHtbDzqNsaxcCtL5yhU7zQhj6gJ1XP9RnJzBTJX1Lh0RIQLX+UiQmY8vGuSY60RPFYjsH2tgAT8lkKyaz7lGpUYNX4p" ..
	"Ct2ycbI6kr6lHB2GLJUQ5B5/9grT5Kzn+XZ0kmJPnUPPz9NTvpWrdgtX2BNzmcdGbB86jxF0aYwtedBP9EoYBVTb9aD86ICHKpyu" ..
	"Ykn9YgL/jiZdnmtmjyg+Vki2T7i7Z/K83TGujieuUIzE2VWFSe/JKFNnoiq9B8mvs3WWIBprQNyyMSym+3x8gdvIIYx2DjBBJTAD" ..
	"jVnSjPl5RC4Xixr/oxhcYNnuAm0kNU9+B5qtfRjPWVG9xU02R4Hy9Xa1v27cOOGzVJi42mIaHttrrU9wkrN08yNvtPaw28LeJD8M" ..
	"4GN7y50QZ1sdOEwE6eoaXYYKat7QrDLEjtz93LGwhnFfePU6gkYYamf4Bkh5MdUF+Cn5qJndqPzX0Z3kNGOJl3ZC170tG/2bA/jk" ..
	"qy0DCKSnW2dSdsSaMNM68o6/jZJloy8A7HcWhS7b3Er/heR5YM/vhFqhPTgKiW5h490SKQIkrtj0q8fSrg2yF2MIovHNaDG9iptR" ..
	"nK0gH97xbfs3Zeu+hlk7/BHkYuWrNiS93Iq4VZqW7WfZXPS1Q/LhSqBa2sjZ0CqHzf8Jb+NEGIKo84kvDWIOe7FqoAmxww3lsS0k" ..
	"LsDFPdKzyu4+d/dps0t9cswvhw5ejelfhLgvt8qG28O/vDLTxQRLNLIyx32F8SMuKS2Ntp2rVLAsbbVLgUlvV71vk0WTLOZEUyGY" ..
	"FqeB+3YUKXXwHGyouCz3mMmz61XPNI1p+YgdaQIeo+LUetGeEGGRY5d578HkzVB83X7yWLCTqSaOMDI/tEj3fdVtuLVNMd0k6CDN" ..
	"ms4thVD4Bo8d6C6TTQtTIlRL1nSQheYYwqtl2HkWQyChKym4jCICjuxzvNDlO7aPTOY1ZDnXSR4g2EYDZPVVcVELNcdYDnfhYpL9" ..
	"a6OnmUZ6xuEBA/KfaI82gsl1EeUZ08unBQMf1Pv+NWRYI+sVMzTp5IqsDMDaJRQNq+XAEiRjPLbkmw0v8bGKRD/xWVxUFLC2Me9P" ..
	"A52pcBUFp4+eb3eLpWcqsnTNn+Zlt8VCCeIIb6ghtx0LiNW2gxuZr7oRS/yOBATr+/cPl9uHU0h4PobVfOMS+hLFdZ+rC7CAqH6F" ..
	"cuZKwzWWQlkd7Qa3yocDk/+KQTn7yWXnct9K1tj6ngux3hTqXYmeVCqdd3KJSbule1M6xCsC86HOyxtGcScp3nQe9VHSpg2ZTlAN" ..
	"BiFYZ2lJ514siT7yWDE1Jo6ojuRraZc/onygGAWfWSGzQ76DVK2+bFr1LLoEfnHz4JMxG8X4Fn5aQWifZc3jHqcheOzthf21zr8F" ..
	"Nc2eVIDyC6mXNNTPhANm/vVIw/pTjcpCuLvjlOASL+ZF48eXDeDlokcfWZyd6cNBHht/PEDSeX+ZVAujTejuFYvp8275f9vwnH19" ..
	"GM0w8HotRuZ14sLK0RP0MJMWlIMSBSUxNC2Gk9vVgk1rWuh9niW+tKeigeIay0EMTEyL1vxx/BOYFuftyS5llJRHJN32TevU0ywi" ..
	"XPznx10ET3IGRC1ZfuFzgOTvOT5Qnr3Mm9TXhm/NFYeBzxxrF8CkYaNJEjKfeZwLFIJjuN1qfNglmulO9KLZ0j3sonSLpEeNR98f" ..
	"dC5yNobKg0FJ3SkmXjshh+ACeX7NTJVykb+vMHz3OPshNvdIYD5w5RDnl7zZ3gQX4o0G+nfRJrCBde30F6QP3yO16DkL5EGfyk73" ..
	"i8Ini63ESopfMfdbpEcvL73jg7hLY594AW9Zt5schDNMii7UraZ03kISS+XdBItp5giNRbXdboW0fUYPskER3AdmlMa+E7z8vHsN" ..
	"NRWm9Kz/I3ZCNHmmiWAekYg6usHnvSqWmztfoh7sMpKECOqPEhHoFqxsI5S39b6jZmA1eQDL/Jzl13LKh6PxNtu2LEReFCG0WO1A" ..
	"D/rUNeN4DuQ14opCvLN0rGiOfni7dE2ul6lv5FzJqYBswxoJdCW174ej83Uct+GVWl+mQbQ69go3LF6wc46gnsp5V2uGkHScqSWv" ..
	"TWPrsPYX8cz+lhMVhJ1WGmHmo0CfQCmapdu5P0bj0IAUXjF9WIoRRK+EpuRv9WvNAJm73zghXP0xPA9OAuYl++9G1iiXPUqjUPkg" ..
	"4GmzpP2YdA5LEaSlwV0ARHxUvMwPpYQYdtIEgNUM7oU6+4ST/NEV9kRem9PgU8cwiPO+OhL7ZRdyFyyNNuO4K0gCh8E98tJ0aEy4" ..
	"ZHrOccy5m9nUtFk3VnyAjPjJ/ZCPDFqlSeDYeR8fiI4pNIK5+/F3CzMxh19lMB2EbUh23tomXfxTDM2MJBcQY9lMb6ZVq5t2ojzU" ..
	"ouCSE5lCFfEaYuMkBovJEYmZMDkS9nro7Ew990g84ZZM9JoWErsYLy55UqSfEu6Nec0fuSrDqnav2naxZua07M6DNsDN4gTDf/LD" ..
	"gBG1Rfd9PE4SuhRGAy5OFeriV6ACbf50h6nFwVMSmzxW2+lPp7E6EqDGI1U7ORSgN8eA9tT8xt4U9lbvSP51POTSAsGTbBgKjmAL" ..
	"vS3XS5GI3CuKY8kr/LxLcFTNHxTvp6CJgBVpLflhY57VCPWUocsAiNCJXIRJfp8ORWJiWpgfklEEFlO5neB6nVaPvH4pvDdjVRRX" ..
	"oWJNvN2qw4sERIi0mGh//rJYmTcxrlfm1QRzx42DUf+qfWUCZ1H6DSSghYHeVtGkeizcGN+z9FcH5DZg6vWFQE1UL2TmxztbtgHN" ..
	"OImUIfq1fsb6VJp83n2oGQoBm2pfRET3IzN2rxo8SZJfOKnNIbeAASHajsg7kORsAEnI9/ey+iavEYeIOcvBt9FdVPWwUR9yu7Li" ..
	"iky4KqrRuRi7e2HdKWS6WspvUMMW/61qMgN41pehGVDrK/x7eamhvFLrtj4pXIhjEVa8PWFORVpuEPQIsjR45NqYumsD3ij0o1zp" ..
	"Lpn4FbVh4IwMyalv/6rbT6OhbxfcY4tCnOqVXZsEeyzwEat8JwNXIQBttHCyhL/oLB8Hg+26tN4Vcye1CvM8CRxZBo9M5xVZj0Mp" ..
	"KzNXnSWI6afg+nSmEzR8orNKImNa/8Y1tPV6ojBj3q06srC8SM95mSHbHnOeFyOB/TxTpuRi0LY7jVYuKQ1XjXLjIGccPaYM99h0" ..
	"l85XejDazWnNPbS8I8PIIwDp71Grl8zRcdLanGBKSY6cGbke9DPheC8VAKRLbSU4wW6iF2ggSW1QA+LX8z+7zedQ1+dSRqQwhNnf" ..
	""
local PAYLOAD_P5 =
	"YUwB7hT8O+tdfrj/ykC9VNe1huzhaPMAaW1FlzZu6iX4+i04DQi1WUKLlNoFA2m7D5TGtsS5MtYIRXzBIKiwKsG1WguxFGgaCr26" ..
	"B5fyn//fCdTZzXy2PyB+RAyyWllUwVdoxnBdlx2gdjHdyKDC8viPEgI5oG39N/tJrf8XxYR140mnfSX9IoaRVwRMPAGHeI56qXmg" ..
	"UX8G5zJzvzELeEo6QxCAaQjLN8mbkdFTgrwqHUGladN7EKtY833Nb+Ez1rz/fv7/2tfRROzTDwygON0o34EtsNV8nVaMo4CNDBUh" ..
	"O/tLxdnrNpM61h2jqhLyrOZQiR5CcHvbmpuGMQ/nSFsAs6hWz6AGwabsYneJAPlZcJ9d2+ddkRmWNfLjOm2VENXZEQ9npvGLa94d" ..
	"g01qazVT6Y/nJ6DRovc3Jd6OZ8xFjnJv2gpw0FCBzrfhhmgS+uyXYmASGjUd2gL5aGHW1ojIkRmXNIyRoGNPEc7fXbzyHvexK39o" ..
	"PUOS1u0qjcxeog8FZaO+KlO5Rx6F6c9899Fr+tcjVHx2QIuvVsIQSRw3KHdHkoFC7Ft8Wx+P1YQCJPRYB9ZjCwKj8SJtg7eAvIcX" ..
	"NxIQ8Caet0VGdZncCjZxDyiZ296zr5hyTgj3XM8MJLQnEQNclQBhVEbPcmoFANIR7CAY+cqx0/vKdILTTj6voqpA/XBFvgfQO30v" ..
	"a8cZ5tZ2BMxWlDWHuqRTbV39KgT3abACsou9QtqiwbratpygnDkKiraXW6pae+42pqWXCNRFUoAybKRBTXe3UKez5IUjqzXlDXV2" ..
	"4k2E5siB4FO5W+TKtvKAQ0fIGpsWFdNw0a1Nq0Fd5u64RblfG72W7/2irUE0lWqUGp6GFhCq5B8z0lG8p3SIcQN6xX61F2JhLl8z" ..
	"MfOnrqHL2pPFatlBFciDEUhBynkzrjYqLqfbUzNLBP6uHpXblNgmhpob/lzLQ0dyxe4MjK5zitjO/20iD9kylY5ueTCVsau+T86+" ..
	"NxFzTYKVK1Jm57FjA3xUjOF5ndnELv2tPmPTo4M0WY8glTuak5WRd8/YQgRm/pDOnkdgS6tk+iW7jxAl1z+76n256zKX09JudmH5" ..
	"uqEV085HryAsy5HjpKe2ATbt4DX5cFy4qqdWT9T99SHYC2EN3BU8emrzAmPOVWyShR1WvOnFz7xJDQOli3Rl/m1kQHa7fHC9Gty1" ..
	"l3KYc+lqy5AhgQpVbYXhcisDNi/l+oWPxBZPDUFtfg1zBZsLG6zMmfS74qni4ESUt1MH/dIpxF8dgSl5x74UZrC962qBd6BaiXdC" ..
	"MnrQLGwXVlsDm8VcO79d+OGKfWm/JoNX00rREzpSZU1Im5TYIU5dl5d4/PR9bn6/qg89NBgQz6bo+LtLyVG9H81adi/KLKf4C1ce" ..
	"MssqoPj2+/LfggUv8mI+5TMllNQ/Fl5dRc4JixhEZ7+lxB6wuqscnF4z4+1vHD/a2XZrk148yolp62J9380Bc5fPDLYhN/xlkm0h" ..
	"N5BXjdWX6RG2VCsF/RZ0y4aHzsFZjKYk/01BSSw00gpp4kWcUgOaPYIlOnmSexch8fjyMYeZPYeuAafwcDucspbMPnd/Yx2Nj3aQ" ..
	"VeLy1r03+wagXF0hgOCA3vvcBtxhra4BCyYYx9Y44bE1b8X+25f+Fxd5ADGBCaZbbtPlZ08elpPUC5l80maFynRdWa7wSewNGjR8" ..
	"4IUliGD35b3J2yzkK9VGkw7CW4eoZO8J+N6g1+bC3mDPRSVAklrABk4RhcrR5hhxPe3T43/k+HLziuWdnjCkOiHli1aENbpVUie0" ..
	"X6wiqCQR/wmv4UMvqBrx5Gj7P5QfvnS4V6lEf8ltDYKLFIBvYmAJ5y4aBckfzmUH//JMrFc6NsuvGvceO4vttqWJR50hgY7sfZsb" ..
	"zmAoC1BxQLDjqr79wdf6qQNDqlm6j7djScbjlXnjK+OcgPFHRjb3rcco1d78nbllvKpSU4tAZbPcYLnz5Jy8rYeBst4UUIGfaPYv" ..
	"0S8YXNQKPuniVGmMUo9wNz8KEaDqKwZQiV8buo7H1DWa7iB7HAbosBCEcgbYo7uaT2lL8P2wurw9TimuWqc+XTbcnRKyt5XO56+N" ..
	"PfpKX02rnmBAWXH1ZWGW54/e+LtYncvXe1IW0N8eDrvu9/mW3WDckzG1x7dwCUOk5CVJo1rs/icuvKjDA2FgCWWYld0GBtMUWhpO" ..
	"kCdZn17W+WyIk63Vf13HLBxKSKLb1Fet1qZ8fRz4nwXJVLYbPW0f+Q1GYkgvrltxF9ifcSQOW5t0esKLdy8qXVoBmPiYXJWc5O2y" ..
	"IPOL1aLgyXrjmVS3bjHMf5DMiSK0soOLLUvUYa43okWuDO9wgarYpoV9hqf/g1OlH2Nbguj5fDn/u4DuiVno4wMeWg2grugHrThj" ..
	"3UFrkbL8kbmgkRR5RzPf+fzBuf281aABolKcLchngyMLAP9VWqVRoQiR6Kx37T69jsT2ijjw4IZjmq3oZKcVGkOyD1JoaGnJGNFJ" ..
	"TJ2Ts77fyH2uQYwDslC0/LJHkxHNBnLJc5Nz8D06Qc1oAI9Dhp1EZNEhpPxwpNfFFpcYpuPoId5Q5hBhOgb7vwaxvGuPoBIakqzY" ..
	"4fA1KOf4JnymBcorV5coJT8t735Kbr/FnKeunvbynqI5W5ajJo/9WMWVtoto2g0UfFB70lt/t9NFuJo9h95BrEI7r7320n3w5PtB" ..
	"NqwTX2q02F8IKbggVrZ8lybO/5HKuOC8c5mcbyngZX3tfRU8BPrdjkL4PVP0UgchgDeX/Ox9YZky7B6YOevMtXqJH4MWy1VZOnXJ" ..
	"gvTnRjumGf48J2kWXWlFBGu1CoeY92ZHtP8zpNyYh7W0vcxxYqmwHsbKCW6hH67cKE04H/1qmc1VOH1L3OW47Wohvfhl0N4EJgoO" ..
	"3UTNC9RhOutPFpae7mtNSia1+I81LUWX7txHx2SW6CGxLggcIz4nTJxqydusIZgAlrF/3bWBwR2Rq2XltSQsVzMJ+5qW/TG+reDV" ..
	"ruTo4u7A33lslU2oQPCHM/4t0uic+RagpXz8a7D8Zl9vf4Kb6VECKO2F/MxkK89JVsMwis9OX1xr20B6BOPzgZzFQFMBwH+xu4pv" ..
	"E/miVFe5d24fPguVV1Ezr4GQ94OGG2jfm3H6kL8AYDSOAayeHvszz6rTlm5Qr3eGZJSQIQoXaXX4hem07k+R5PAc25X7J6zEJhuh" ..
	"kG7hgZVGD30sxKE+UNcgrQ3YhMIof7BBL7bGGkQQJ94I1S7ymTmHZDlVSykAjI85FVCNnZ2Zwe7QNHxeG1RkVEYFh9tJBPl7wsRj" ..
	"0EwZ9VK0KUE+Wodgi1ZKy7sQ31EgACDcw7yQH3EuEI/cQUK7yZQqQ5uOKREFhwgZx4a9weW+ZmnGhjRoP1C/1Ie2Y4BJIrNNCEtu" ..
	"sdjOIre6Y/PMVoJpfdH7SFHVW4OcdEAPyTgsC3Rfh7qft6GnssECkagKu54Wx6aM6uXdvUg5qtbuEta+vqS1yHcNHxM6Yoha0+jJ" ..
	"lGLcrlhr9HsExGiSrp9XJdkkub57x5wiEthw1hmUR4F/1lgEEFTeFh4FKViIR5DbsD0iclHQTpSmP84b8y2y4lduminqIsfcZkCt" ..
	"DKQr3XeGK1LQCD63Ih839pvhC0c7zZQqSVQZHzvm+eOwsA5herZl1l/meTlYsz5ANj0b5TN5ikvHzfvsQ8A/QvoLeNO7Vjjl8vzm" ..
	"Ky2w2+tUW0iXIpdr6/wUZ9JbCf8pY9ADjYN6ksoZfaWNYp2tTdVQu8CyCA1NcOTRkTH8/02N/6qRvuOhzis8LKzH9fR/W1jrVQB2" ..
	"YJD0FQZV1nPH/dhRz8sPgHHgvpgmAGlzTOrugpnqN/DdqD4uaIfWUkFOm5aJoukHh+qAQyIAqjAb12ugMnYTgIhEHThlgji6jTF2" ..
	"MONsiik1U/0OmBpgkUfPPc7IW6mFlXpfEgWwt5pCcDZdg8gDaowZlVQuOaxAZcf0GVF811MFYALHC2A/fYz5v5w1qoNzjmwqJAeZ" ..
	"+iiELZyP5DWDe5o0iJbfl18tWkls/JeZ7ovtB110FfCLbNKNQcdUXSRvB0b99UAVCZlvoF4zpTkpEO1WKt7ZL5BeeC4D6nu6+jcI" ..
	"+LWXN9vjNqOUfEGu2MG6Lrh5jf2l9ewn05bnYQwbU/pn3jzO44VVg8xJHCA5qBHgTMxLGsyLImsP7IUvcMfBPFS4TT9kSJLWlya0" ..
	"VIfkg+P3rs2AACSPzMnsCvgaYb+VR3g7KU0e99bDAVEsplDPrctfpqnjiTlr21ort9A9yLCd/LDeDSiYSS4zk5NnYBhYMKLU4Cts" ..
	"Bk48JaiP4rIUc7s2Vou497Wjr7uRaNFGSCj4k23fUH86lUdjFkAgzLbY79HAeYUhwNl59BlQPeGfz3xzLthvdlHPBYPIapiK/Qdg" ..
	"TNBNp5/Owwq9lMWhl5uBjjMfcNFA5lUMOa06sKvPmKFx0BR4YuxQpUJZVlu8lLKCpDBVPuFXe9qzWQ+HKIF9KtX32jqknXvIEMY8" ..
	"iI3mkJGNwc3VTAWFwcjzZljR11um7d7Dx5kJC7YIKVBoC97/RRtFTKRO329z9LXdlLIlkVQBG7GCXZznR9mvODI0DHrc2bLcn7fQ" ..
	"YmM5+NY4cD1bu0PVbbEC0hLnuTRKku9Zeb/GkgTC/6iZCxPdYw13gMjOvWkLiY/YpOfd8AQVzzFPaQhIubYH8VQuYhaURWV+5HLh" ..
	"BxnaLVyIW6WTsqZMg5i5qDJsq8asCAAtvcAmAgrpK1pDYhyNUEf+Nw3/k9/Scip8VgN09PQQjQg4SFKkNfwZY0o1XZqkViE5ruIx" ..
	"j/LVtOi+bavky6WsrRnUGyitLZnko541Rhv5UzQBGh6msDuH5YkpU9NXPdm1FuW0sDK0hKMx+pesaE5To/UkxzCef1uYFufWk150" ..
	"6ulZBo32kpejulFZ9PSDS522MFmT7T0HPXYU2XR2LQ8yl97/ttjZfmLltID501JDljazn/QTmECXM9No4dG8wGrhOIh6n9Gze2at" ..
	"XPpAoH7MtazhZRrmhMcecMWCtWCokwq2Vf5dJthdLW66oGO+1gbhN9tCzc90qX5739gEdO4sr4XGyBwI11WeR/UYJYytlDuzq/Go" ..
	"Q5Pz2seEomBYa5Qg+yxjce6p+ZnGH7DClF0o0Fesu8rfi9tZ+gw+Ttl1IBkqVpHrhSsPkHk5PnKTY0oWck2HzVFySO+MhGxlc9CB" ..
	"Cy6Vy4QaWTXXkpy9wMYC4gn30bcWBz+p3BguKhBYYlS4TWif+hVIR6W+/N2QxZOqZp/d1Lap6M44B+XYSsPX27nOOKg3hMrXIGB7" ..
	"dx8VXNluWiLA1SphkXRpdp5AOnpPjvim5H4V5DVN8h1Tgbd72tqcnkHvCvmot6kdzeEIgnOYan6bUulrjYJn0pMBCs+gFmCN4U62" ..
	"JMNNzTsGKxpXexlonAEhYFX9S6TIW2VngqJedmQFyWe7xo7E3BtgGhhmDeUA1KbTUu6MxPawDkC79j7zNnGtCwZGIGLgG3PuGvWX" ..
	"iSZMM8DPdoZ685us9g876VApGy797Xt4JTqt8/yl8qqPlqsXyShj7S35ewHt4Ng74Oa7mwl7+0VqI0w2LWf871R8yrbw+/Ue6NUy" ..
	"tg5QBk9i1PVPAnzW/z0malZmmHSgFkswez1HFoPnaEVJokLGyyzNWiG5Il1zFoYKkv7eFaEeuLjMsLbsUN5o9jmy9HkVjaxkE6QV" ..
	"YQKvt0TRwxDCrNl3opGrfWVEr0sWne78YBC+G5b6CMqqWuveFZyj2bt8T6CXfUSE4S56WgSnvGQsJsHGSdw5Uxrxdnt+Aj8i6SD6" ..
	"mTDkKlnu0T4v1C0vWh88JM70SK2aNFOhfwBlZw4JvU1I9XYzNVff6w3T/P88qNsg48LCFVGocZdQ8FlkIjwD+iJx6K8EB0TuJ5kj" ..
	"Gvzxh4DSpsThTDWDuCbSJXhXg0mnAEFQlROKf6Ew4tRPakHPkkuNUFPvfja4kvgYd+62wovuZOoJGlWrCVPkqixJ62FfEGixMoIf" ..
	""
local PAYLOAD_P6 =
	"AUd90bKXMr6RW8uFfdk467dPR07lUtX7zpKVtO4DGLVVckzX4WzIn48S3i2z5Zs5O2oVSVPRr7AHQSINaGtRB8YWXo0G2hBBcPaQ" ..
	"3cSuOOzGCbv9wg6cwsEP5nRoPX5BW50TV+M8NYTwHgfYJUn8WHbO3qhuj6vNKGJZ8fZSus/LKJ6GSJjF3e769mspaIDgL0yqrYnr" ..
	"fLeTIwm1Et2A+92tWahqcp9P8V+DyjcxEi8UtIIz/No0g2wqz1IpRtMi/VwSTX70pczutpt1IuioyGKwVQg5A6pMrPRcZ8psjPZj" ..
	"RfxoZZdbQ0JzEcrI91rNvivxNgA3Elq3hP5zMfPsRkxoELaJLRkPNz0zehO/yeEFz4oW6CEqZzXzUyZwFHFfr+igwpO0vzLSBqM3" ..
	"gyp5YEja8vlWrT46dvVgYlbR1pBL/JjVXbI+eiXgb9j/9d87y/I+/vdSaftRiV1jgLQGVvLkPrR740IWPwWIvP2zpbNO7yrFd4p8" ..
	"ulvQeo2tWeHbKwRxZFxjN8xzwrlRzDVCxcaDFkAnGv1uvqT1W+8zS7GYme6tO2yDt4eVdF/sCVgJzc9Ym878AodKE1EFKoK4H6U7" ..
	"U6CmseHYNV9u/4rp8QOo3hKnZws86HzTRbk=" ..
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
