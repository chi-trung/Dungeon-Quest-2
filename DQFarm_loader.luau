--[[ DQFarm Loader ]]
-- Licensed to: Tien (nhieu), Free for test (nhieu), GNURT (nhieu), KhongMinh (1 thiet bi)
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

getgenv().DQ_LOADER = true

local KEYS = {
	{ seed = 3326959232, exp = 0, plan = 0, hwid = {} },
	{ seed = 3328005011, exp = 1788740761, plan = 0, hwid = {} },
	{ seed = 3324796295, exp = 0, plan = 0, hwid = {} },
	{ seed = 3327156208, exp = 1790469007, plan = 1, hwid = {"HWID-ABC-123"} }
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
	"G0XZ5xkFHlDM/9/+NPBquQ4bjZ8zF9v+HCpuFADVZSvEeijzA2r9AQ9RTHov8/ZjXnO4silJwUxZQkpmBZeeBae1UNw5mrN7g/Te" ..
	"zvgYqPaxAT66E1xGtqWPW/V5KpuYWO+m+qac4i/SY2BQwn5r29Wis8pepEeXnIgja+qyzLy4zkTRsoeSegbclTapjgoQFWclYFI/" ..
	"JhQbyfg6Df2fz5bt0gSLUSadXTEvq0CBjTNCjwKuDkejCQdw+a7/5QlwkWBkNKIKkwhMi4Y8+fUvaTfCeuFdEy6KQZZQT06OaQFA" ..
	"D+TBWX36lDbYVBXdxlf374J7/JxjCkmbNCKh7/7hfOZUKLpSfyndJDS6/i+iSR1xvt7a8cbGoRwf4ATNexUiXRGZDsZjcJMwDu6f" ..
	"8sRskfvacy3MitOM2MM69UkiY+uCJhy+Vrs4QMHRqXi3nVZKhUrSpEmKuJX3FUjvmtGQNo2drs5OpSGvAfdccB4yOjDfZxjHSb71" ..
	"+9ZzykCXxTBPasKLzTZbrUCp4QkOCNnFwo0Wd7ZKi1UEFT3wiIx9RvSYoyw1Vkj5RnfzxYQoDTykjH0gpNX5X2W8zkPjWbl4LcCb" ..
	"0yZ55oSle4KYWWsGFr7BetTEp3EkACNryk29i7iT+1Uu2o1YNjC/loPNGJB/WYadSW9+KLgrodeI7DmPu8mXhfaNTcBp0p1dQi/F" ..
	"REbV6eK1G/Ps4qSpM0fGyJDu4k5eJMrprvrIPak1ZLKvdI44VK0j9fpbi5Jjp/b72GL6smQFqWyGjR3/3hI3cvDbRvu1+whwzu8i" ..
	"EDE9XVp96RU20xRJQohje/Ho1ABJ5SEHu3yXpTbxP523uk9BHFECuYbyxD302kmsj9d6IQmV0zivWgv8+eoGi7L9uVuwTuZTElTk" ..
	"78ZgEXMjTDfjpZ4mcS/ZtvlAQKqMvZG51OaQ53yO+lOPYo5Ruw0XkAQ0ei5Bb3YHHse0rs2Pg9PqwzAdO5BEOUIGgKMuecrN5yUl" ..
	"c5Ok57wM69pYmYO7qbyIOGvqCgtL1hHJkLoEGtW4mPbdfPbO+6FdRnt9u1IeFhInkGyD8yjG5PDsERWWmWbGzjhfGCUEvQQMQx8Q" ..
	"i5N44rnTg0rg/oG4IABIXfuffnC1fkPSzcRX2qfhk9f7TgtWvlg068Xt+eSdmwSv99eBlb/efhwTWcENtsZiIERzpjJ8FIpJpRP7" ..
	"Kbl0FjkSbiriQHPljIlirBb6+0dIF/H6G8rIkB5kmIWcf56o3rdZnekOJ/emiIMGebXzETcvwE2XoC+tGAON+Czir2pzDHtMR0CN" ..
	"lXbWKj5NvF/e1MgtIyZlPGP7OWeHVoRB6CbXD+tBmGLPhb+xlT5iN9+cU28JDm+wGh/yiUq9icNdVmR5jcDIvm5kSTdVotr08v32" ..
	"a+P/DyZJM3pcZtNCOP01IBh5y0wuzNN1NlBzXgoHuqcl0ruZyvm4nf9czXLfZkt9AEKKs29x3p9PAoJh3XUYufdX8vVLnXp/tXR4" ..
	"O5ZhSIOrpBGhqAyL6ZQMQbgL5rWqvbZDqUppL3lfOfVa5szc4GzdtzeXGq/bYPt3tJXpBkdDWmqMCJko6xw3vZx8K2LzD0KNSNoh" ..
	"CrvlTunKwJ3NkoPGrokmaR6C5rq5AyCpkAW7cpTtcexKH7OwxIdn8EXvH5KZhpCp+HFiDkoI+EM3j2fZasJiuOQEE3MUozJ360aG" ..
	"kLbfL8vFx8zm+5Ux+XSqd02jmoyzzLh9GukIDMZjMnbhSLDBxAmx10Oodc8vkVPK8CpTzVxxLFzh8CzVSM4s8vEnSv6eL/cawKav" ..
	"vneIW2jx0HDb8KVAsSlXFBSif/G8qtNoNXR2aStwUHbKtMkMfmRoa/3KQdlz6hJSqLUhbS2ffxNINqRX7ImtDDXiRo1tZzDOmp0Q" ..
	"Q6hiGYB188wzOQ5OZP20KQy1WHuccQFyTahLbg0V8ihOvHwX+O7Pt+XfUGEnyYyhxzjBsmQK7FcLxcrQ2bsfqB3TNsciPMMkNtid" ..
	"rmqxNHJFb5CZsZYwyVi86d8ew6HuHkHUYaId3ubK5sfCzhuIyZ9HoeYdlc1e5raYHCN1eiiBX/IGFry/25GWr1z4Ge6686Ak3ttm" ..
	"Jb85+uxM4A0Q5SYbweBkgIHWi8QtSeRVx85TNHc3gPEbQUbE5zXxv+3JEw0ynzi0/dIWCNapMKd4i6rvV9efS3aKKh2gSAHTutCy" ..
	"QUwISyqmRXqpMUOjt/VS4glhE5/WD0jQABSmw51G6QWcrpn0/1sLTMRnU3g4WIbtlUjzNaeV17xc81wBsbqoiUfv7T9z7fHtlUB+" ..
	"OS8VKTVZuPp9uYVolVGwst8Nbj19vqpEmzqrtdsvVAPhCPKvCX3qA8V9/bbEucgJZc/OV+gtpGtboDmB+cUpH31SAFCYyuS7U3TW" ..
	"RxYgVBAqPisN4aEPGLebI8nFZT1U1lda5ZAZSRTu7YUwiOEo1pCe3ncKiL7M+97cay5tpMp5QmvF46XEnyuTZppaLtNRFwKnmXfS" ..
	"op8UxOblndC97HGmpUXRKQKeWTPe+CYYrCe+tsf+FlSJS/DfojmSGNVbEKk8DP2vn8kIjOZWfPq7KLOE3FG8G5FvKeoM+Puco907" ..
	"1yf2MdFJtOBEW54xz7oUKhtiKzrQmHHH5ZUwiGfl9x5xXnb3mAQ8E1m1GFW68gZfHd1JL31xJzGIuWXACm6YUwFjh9VZeXFxqihO" ..
	"h8xKGgME45vosS1C1jO3ZS/s6Nv6QJ7AZjWVJFQS0kJHYE6NWk35sHPEexVT3AtBysx6503H2Nn9TULlm0lhH9PiNrhvHcwi7qeq" ..
	"nSLMv+otpGnbDq4K1JDhS+6aDxezdskPDZBU9zCcPMujBwXwnSXa35prbA/5lGd3AHk5sAVF7uthQsUglUyHGrHnBBGdeTu52zzv" ..
	"Gu7PcxN0SHhr8eQ5iBy7kafU94+GrOMoWCYG5OCvXvQw8tCuugedtG9Yncr4xS6KjBjy0GOdw7WW7Oc9qQ9Dr9T15dUfrUe0lwnj" ..
	"TaUb/+ogtZU7JaqodrVTtejbcfQTO9WLqv7pGv6JxYc46BzhR/5VPt/MgAfTrEg7QRpfdiuFqM+dcGbKBoXRfjR4Sa4nfuLFxUmL" ..
	"e5Un+M/Uj/OrzwRwQTLRsibrpTKg0bTL5Hujc5mxoson2x2+XP3HNRPI+pOQolbIDctFJd5kpFzsleEe5p/n85zAMbiYdA6CDbGO" ..
	"KLOO50dxNrFi5HiPjjZnoOC7BekqJKvJpF9vf7o67y8FUdC0QNU+23g2vStu4AbsAZVu2Dh7hYb8MPKtmu89EujJ7sc/Zsrw9aEX" ..
	"/4It16FH4amSJkNPSd4Ekw9c9BCMa9+rA7+HrYKSQkOwdlbCcYaiqyKfBGXo5Q4HaknovyrP8YmcWHgk8MXFDnzuFRPZ7oxsT8vR" ..
	"hl9oExvnIwAkYwzN+LlPapSYXPclSn95UuTCZsFpWn6sQX06k5iRiElfdyz3YR9mL3Pb4x6HCgeNt+RNcZjJ+9kDTW8o7gfq2aFO" ..
	"fzE648lHXfPTZ4bj9CLvJoS1OsIPm0CZ6Tl27yb+tMsgmIYhQenQ5XudGP+7ECQeaj53PkIDw/JIncRh7U22fiCaEhaxCMqf68Kx" ..
	"s28ThN3NYRvZ9slYfdMTHIx6/w3dtmgHPpT2UdAVobzE0Xu+JzcHPHDGVuGgIiP0CitbpwhAUgOkEatm/yBbd1WzQi0iZlKUJPzC" ..
	"wZq+avXJ//Edlaf1cRmyf5aHYsuJeLYckT0MLmLCPIrK1PKswqvJAiatDy4KK1XQGRXDYKAV08ZAXix2jo+LQBDQX0JNdSEyNJDM" ..
	"W11Y/kzR+A9vh/EDXmg/BfTaafFz/+JVUBJXyn8jfIHwgsePfYr3buUcq/zY2cammps4DL5tQq1MIVRFhnGFE0WW1um17re95lBI" ..
	"o7Caxxzd6VhrrwwQC/fXJkxPnIffXREs6Ww1kf+9s2uxJoe7NOJmXGmoZN+x6osuCC0JHV9CWEIj8/KUZqqywtNjB85Jr3EYrJD8" ..
	"rbLtygi/10alI3IcRwkVxfiYnV5gvcjRSK61naizlR0BcOsJxqy5zo05UH8+uHhTtfkSYajYKtwUzMo+P3k4PFpbmzaslD8/tF5p" ..
	"XklWyvLuOm6st/PQx3h6J3DwuBo/hkRLPZB+PHpJEBwDgntv0ZyBeYMNV4xX1rvZCU6+IMAUTkpI4Mq9ycV5WLoBoikYGiHcjWx+" ..
	"84LmWW5O3W2vbawG0RuZL/r1YJ9/M7L9LMUXjCACc97r7MQru92EZZorUHKQyjxAY08bRwUwtlgWJlqm0zKsJwc6jQLhad17a4XD" ..
	"WadSbpdriYJmu3/6Lui6xCLJvz/tU6si/V6x//ApjBnDF3MS43lvylpBIfjKDhCWlw4VktE1ztPQn5L2DUXD010abq5UDQi2jCH7" ..
	"faDPOj1Len0aynSoWVTdvmcva2dniUWzdk5bAaVSs282xA6AHrqFe5juHIyzlqy/TzcNnpIFzOjfv3hSZm+2C3uXYZNZ2aMk2qIo" ..
	"CYOp2f0fY5dJbpVuV/WQhWgbMbWgZCB/Fe3N/MtNGmU1U59cgaKXApQtzVEgsmC8SrNEe0T2q0C85AGdtMU0Q3o9oHOsMyzXpJ0A" ..
	"GImnuQx8lkcQ3iwWe/j6pxerb/HWYhZH1HzNk01g0OHyc2+S3c9GDDh5m0/xCNlGz75AkEiYKk48S7A20803MepIPEYAOrRY+r2d" ..
	"nbHoPt+aZBMSgrrcSTCbF1djIRFNZEEI/PxlPvzYL7f5bkh8O7su4x4rCRy2+fb/rLg2Lf7BfFh2c+H5kxMr7nLqXQRpLnWIjk92" ..
	"gyi4zqH+sbRXeCqyIARdAl6YcgnKOzPph+bh/cPa9OZZNfStf73KeqbBm92TqtDoPTC+AZj2s7sq8Y6bMhyOuas2rB2JKYd5qZ7T" ..
	"lVWaZS5CrPyCdkC9q1b1M4LjMiINMCjW+SfEEMyP078gfT9wFKTs+59AF9r/7YCWHykH1D1edMPChfYZSgpTHHedJ464NYfH+AOB" ..
	"+qztN4Vn3meatTyFXwT+6Si1RPXy0oNs0ipoblcvbwaOVFgjwA30hSeQD2NbzNLZb2X3A1WvMNWw6u78qhOf1PQmcIW+jG4jTK4M" ..
	"a6BsYs1BmZVLJ2vj+m2oeIcstXEXvuXu0qMErqI3ZZgIUrNkriW/Mle7TB7AlJcrUafxhqLrpGOZMQh7yNhYp1rXXTmiqcuEtYz0" ..
	"w3dyGomUpaUBrKFf+rncWmeT9D/G8FOGm6sp01Z9u7FFrxdtEy0SPdwvIbjMzoZELNd/xkVm0QZgw6uJHT2MQuON6dhzHBykmsJ/" ..
	"UHQEp8p06fwlJEM4+WaBnuQZ6fMKIxthyIpYkAIGRGnI5WwuvAxNz+56yCadLJuzeA/gR3SIUUyJGJHkhQTC3d1vBWqri3kSr9kD" ..
	"kh7bYRAw23Y3Vmy6iag/Mn7EFmHW0c2S1f/TKiGLMszQj/XCbpN0YCwqEgGaWBfr6GPZA3FT+t2QefEMXRxiQ7qnc31+4qxaseBR" ..
	"AYmDzkBEpUteiIA9pHNB79cufLoP9YLZDNCGoRlQ5mqotgNcaNI+FqQbGzn1Mse9cWsMsMYuv9O6K32FkZ5Uhcnc8tcv+RNZkxEo" ..
	"qQ8XDdAMUhgbKb1aAMUWm4yHVJn36e06uQYwto9qN58r0kujy2XB/yAymx56obQlDdrqJ2WYeyY5lKUT9dabjeGtCDJowgEVa7EN" ..
	"ZQcsSP3BoCBsU4tabaoeawjCA04b6DHWAzpF6Wh2JOqvGuCOhm5278EYo4AckIrRcdrZCjHRe4A7ZYsKyBoHWBfTE9khVGGYNs8y" ..
	"dlWTpgRUQhriVUvUaBe4636dS+qJyBtxli3aVzK9HMEkRZDmtyau0pAWOlxM3FGtQ/jmGgRdL7hvsqGRbToD917BWzXq0ynlJZK3" ..
	"eoJvxOncSSPDVdB5rd1Vt4LVOTeMp4Vrj2Vkm+Dt0+Aw0C+5Rl5GlhJCUzfeqnnVKofvszOFchFQADi6cW58w+dE0N9b6yJzB+WZ" ..
	"wkALcp9oOcriILCRyIpL3wjELYtrGDo1y6CS2ds3OYUEHke1V9BZiS6dpUAygNPuWoXB7ajifrmvUR8ipoojCw34xXqJRera7a2b" ..
	"YGL6mO6Z6kwD/Ix3UKckyksEVwtkmfUo8Z95BzR9FdcuJdWHjyba3jHyEWtzPYo6JsXLybdhxEkc+5bX7cObNrT/+RujeYVOOY1o" ..
	"VOtTn3dYT1/7afAyn/hr0H2xGQNkT9rgLhK+XUUOssoEIebvpxP51PEksLoL7vJKmpq9MkHP2TGF2gKxhIbcjIA3hnJ044+jeCOh" ..
	"MNB3aF+lWKtghnMMKGwoX0XA6Lf0TJuo61Ipt/I/CHm9AL6T+iNp1MkeDR6HQkCOMSHTIMGH9Fy6PbcLjjO/m7tBj9vEKT0WUng9" ..
	"O61oLX4jNqznSSxUN/umfWtjw7aD5QYjLfXo0xgPK0D+XwLhu/6fSs/55E6IFQRQXmrDYqFqj5UzIgLjPheIB7t9TLz3W8xPZYXO" ..
	"//MiMikFyiw7dpqYr3bF/vnu1A3gxoig3myyuCJmFVUmWJFkI7rMO38gcXTMyGJnNh6bu7aReyg38uuu0pR6rvN7ZSSbstke2+s5" ..
	"rkwUnHAETmjRwFb/t/LCIR5gD35GQ6gZlGSE+uzm+afv1KGApbsTQZPWGbBCoxU7T8mIA6MebUg5/4egHNyskvfD84YhsXoxK0fL" ..
	"ggmqmTzViD5SYDQG+8fBX399dwlR4rC1DsIoxQcPYW1bOiTF88kjt9FZSYDRqpPI4E/TxzRYRPJskJHbV6MXq2OOzDJc8Qg9u0cX" ..
	"88kIPDIGpTUI8XkgS45KHIA+SHfneyONHqt7WWHDRdA6iJLEkLpO1aCAHyTcPIjEFxqy7RKdRi5c+Dc6GgIjUC5TdZTsIwvaq/YS" ..
	"yOnZNy66dDfAPXbuYJhoEb/6dUpWZ0LVusFE3dN6LegcVknUPa19Exg3daF4YHo/lMJkmlUrDOthmHoPoQq3qUhT5e6V1ka6JskT" ..
	"MkzswEgZ/2vx+O9nkGNxfRB0pEvYFQYPcuXfyrd+t/EahrLB7otmK7UfOg/gW2iJUDkV/jfYo9CHtZ66VqDBbpWzVzWz7WYb79UT" ..
	"8kRebiwfyF4OvQQq+cOI4TaktIFfMzGxgQnjrV20wpg+9rdAmenZRweOAYcz3izKCGDWF2aG8T3sbd9NoK3qOsyXUdYcoL4DKB5g" ..
	"D81Zp3Dsmclfm2ro+e1zwE6JLcpFd6PpZzurS7MBWV3fyNdsJyGPyuD2Q709ytRoo2lg5iAXRW44duiNQQYcg6MBzbwbYZ+bO7wi" ..
	"RAIf45xUINdpUYaG0I4kNnT1763Vwtc1rutOxsS0J8zwwQVl72guG3X2L0ZFKmE/gGoVpaFqwvLhVFjOOmmIdGmBnNu52Rklo4iU" ..
	"S7YouAVniEsmeMhrfCz42NGcRBUJB9V5jEoutPSWYTUxxPw9tOgnkmLAH4r81+h+WhgKUvg2jJ7pFb/wJ1JVNZMCvlCUZFcG2Zlp" ..
	"cxayhkujs1yhmxMhDOk+TFi+oeyOMZlVZiU7Viec//VPe0R1GwkICg1GK9MhwMROhVqb1SuhhiGFbMWzGrj/SwDvrldxLDjouwwe" ..
	"fuqHZHDsIPiuj8GnwzmFWdX8as1nTCNXMdvydxgg/RlO3FSzvmLXGqS7q6QG+vVMNqtXZs+M6/maa+Rnm/A3kx/T0xScsHh1RjGP" ..
	"susdHScHhH7c+4zdUqTjy3BMLwOSNwjsB4taAa4DIPBjRVKxD5+KhvMELI38935cXrgbPUQeFAeSipkzvYJ1sDzc41nstM1PRkD6" ..
	"jvOfrbsh4PyGjccrYZ09cpbla+8WONEWU+NK6qs4BxfASnYMI8zz5jGJBgIiXkaFQWSCWgdG/h/wMsKjkPDJOeAdkSOHPpo0nary" ..
	"8nAwZ6xJ1zmUNNi7lkQKOPwfmuqeg+lplhQVx/IpTlRF8JtCpo19KmVSCszjG2+7eMdcOYKh3OQIxa2VcCENn3viqUGGs2eaLW7J" ..
	"KVuTlYPZ6ctD7cA2olL4d0VZl8daaxsYhaDL15q/lpyUOi7/ThpCYFZW2cdMZgShBRXU/6ZYUDkpDKPgcf5HZozB2v6SfG8q5+RI" ..
	"jSGzKZRU+1bIl9U1txRPDkfW3pjYv+FqJP1WBvzPfediQvPmiRnPeBIoRif65j+lbEJzI74VHtOalBVZX4pVueJu2/fiHv+Nv0s1" ..
	"yG8Ww8u50DFftbufMQHPWX5CH6sszAs7rQTEjrv0S+tfg5hVmQaG5p1V1LlCdWxPJakKVB3n1aprVoUb3yuXp82jhjGiAAqxOHRV" ..
	"4zTDZ1Rlhn7Wvksnl8nrDqfMS1+UHCZGbVUB716pQSwzH+QNmmZNsNHF1ZWzjxDdg5uKWCJNYR1W5kIE5d1R7HfLmDfiOdebqKxT" ..
	"EKS/0OZ3x6UNf5F7nxcqIIhWou9a7aDTK+hIcQRd/6ZXc0ElPW2vwd+sO9vEGGpholRGA18kSSdpBDOClH/LZYRV1zAPdNBpHoyf" ..
	"2IV64O/uVUZ/lbd3CBWzWeX9CCfwjPGILo4C4NAYSkM3fw++CR2hIocj2g91iMJ5C0rzTAh8FU3a2Bd+GHg6Eb0KorjPxLKvm17A" ..
	"UCSrC/7Ib0yqdxT23cRV9aQfLG3vMV9eVY4IFrHGj2ZRj6BK2FpvGDkR2lIiuNVfVQBX5JrwtmBMwVH57k15UDIToNDmgyEay0iy" ..
	"uwkok35JFyf15ViSCVYYH00MkW3w0iU1oyV75IVWn3amuHUp6M56eegRRf9KzBYSD4X6nd/D9RiWqQ990rQFrEt9wXd8n1JEPWhG" ..
	"ySRw3HiNNaf7B6ORlVXHB0UIwLl4Wcy/CWfPm3KLYNIUnJy0vcgeYygcPSLofNzT9Yg/GKQYup8sU5aKtcKT5tt6hrMBNgiF+XHs" ..
	"H8W88AYs0hZW5GhnY5Ivx+sSg5YgUvkk39lx0Ott5rqZJGC7TVWqpWW3NJOyalzHXSCwv0JWTcX3zXwJ2AFq4kEO4Ge+2yBzshXY" ..
	"eM4UXQLp6A+Kjvc6g+tXERpsneHAWvcXFC/pqN05cavsBjeYtPzSrq+thKxe//fD0JMjqjYhedY3g5da66SqQezwHQhmzJBNSaC3" ..
	"cc4XcYOtDhkAwF0ERirR6xfXtHfE7cYs/l5ffU9tlzvOQVqDp6JpyvrXGyVt6QGk8dbQJDXxM3qxikLgyuY3WjrsTTNc37ABDtE9" ..
	"dZJL6J0LnCPZeGuSpvinKQXtTypCdi8feMOlEEkJtSL+pevFu1Ub7bgUFV/CrsB4Nn2MY+LPjK+msNeIlx1xs5MlXiF3iwfWER3U" ..
	"Adhdd8Uzw2oTRWYa+iffVy+c6wnGxYdOyoCYA6utNOpJqx6jZzbXOYfP0aHWAcuvvpa3qeRB6NX43XHNw1tpRVFJdM2PI0p8aO/m" ..
	"2KIM5RuaN/5m/4Me+/ya7Ji5Kl1gyd71NOaqet088R88v5XJQU4vWplXy9yhYxZa0LlgtA++h7KJXNd7bLLRfZw2gaUvdo6gdKVq" ..
	"LQ+94Knq9f9G5mzMlEhOns8+RLhSGDtAoU/4BlI0j+MLbGB8x87SJ6fe5BhXxpgH4P0RpM4OVd95+PJ6Hhw+t3pZVHIBisBfI6O9" ..
	"5kf3MHhhIG4Wjs7NM5ziC91gGdwNDHAPm3syAwP7PO0vrCAJRn/u7AnuSd77dSiM0SAVZyjOTKPkDzHc0B8jVFq2GfKXyOg052Iw" ..
	"MjmPRwOG+IwlLXZobDxYsNXjiocL9tqc+q0P8t85fu49n4huuiveextB23b/vIA3lEESxjyCkxpnoa4qBjXgxV1E7ouQkdB6HTIH" ..
	"estAfqaeskFJmdAtw58rdlKcTEK17TZEty419hKOIDzoC9MK4p5XK95LJjCYG2A4webmeNQChpR49KtiJKXeOThY2CvPObQt4rVN" ..
	"Os3/NUV1bYHdicx1AbH9l3BqBUfvYjGwNbqFwJ7ZFgpEoT/UEL9Yd0SHkY15fdk8D3QGWjspyA9SUrvdgxh0NVqId7wB8AFpln3e" ..
	"6shOe0dAqgt+d2li1UIu3hmJSkvpzRFVOiotnXaHmM8KY/UH4PITWe1VeKF5F2FCsqzdDrHb8godIW281YHjkG/AIbRFbazdBMJA" ..
	"0ss/SZcEHnEaW5gL5c9PjLudV36GWQeRLdVYaVZWrndhknolz9/P19LGBXL9tOtMZPbDmXI8uzPdM8xrd40Ll2uLaRgbXhqnC5Fm" ..
	"YlKZbbS5+hLnXkcUcuvJA7lXABfCGbGNpAyoXSebaizO9VovmPLs1jA22mh2XQzL2FCoolpM4F7UBfaFb8tZVcsTx78Km78HGBZm" ..
	"k/32WDTeZ8UzP8a/VckLCSqPlVEMaH/+RN9TXXW6U0uLMUnIwW08rjzlgIziVxUN2+Hk/X6Qwveu9pSBH/TUcCioz4ilo6Y72E4e" ..
	"FkEq7GGrV30c3M4I40dhX60Asc7MCgo8TNo9lcrBGLgr25S3WX8ISULBYs8QJKpVYLM9jMTkDKj72Rl9958RvQwL9Zfwwpwxfult" ..
	"04suKE0Ee/GRweQ29YyyQq5BFC+8XRs0ItPLAXzvwZkw7vXsviZSq7Exb2dZwPcOIaFYBISUNW4b3d5+PBPuQXcfxx1/Tm7V/mcN" ..
	"jMu9tMiWg8Afq3ftz+ka54Pa7C7U1iUx1qOl+RrwbkNOwUNnSECDPtvZxVCW5MiCg9b+ZEkLjkixF+vcRToTawBvV0ujTllVGREm" ..
	"CE3A3N7KvDDwhGBJXgx+b1iiLGFQ6DlkSIKiR46GToNZ8SlQpJ5IMQNEIBCejFt5hMHC/epQMJCpQt/S7JPwCXDAkwkkMx0lbW7h" ..
	"WZ+PZ4p8TFAUYu8DIxMmJBb1vWKMQkpqSP8+lIY20j6xBIeqNljavipl3SkYwvdybtxpjOAIjreURD0XD0yutgbAW3pYBlU7G57c" ..
	"YZgC2fkFpjdZbsY/cXBtQW1+IWC893RAP3XTy9sWUi+rE06Iyk7EE9aThDYI1BJ8FdmgYUUJvPsAlRPdeQ4GD4aOf3zp5DBpL1WK" ..
	"pVyM1smLtg1776C9hgPW4FYLj+8KXovPw4BhcQKC27Si2LW8ZWgZt8y5yEiY7zglx980OXoHOvMCQQU8355Kk6ABps6F33E6xQ6H" ..
	"lUqhqLtAGm+GpCPGwvzvy74rhnCun6+oqD8zonsoPLiQFAPa3xf9HspiAmx79BcepgLG/B1IVyG0mkolOTHLJiG81cN2jZwYVLOd" ..
	"JtWW3sDFMEY1yuLPoEl+QR3zZsHoG4UTlrqVYMlFsZh/tWC9Xzbt0uXp9z7fCIxQB4bjwtfq1tAfqzfKPiQCzQ5lxNukXsyXkkuC" ..
	"UMDmLih2hFjxDngXke4nL6EeZGz9yfGPlXS4nmEFy9PIv/AF1oMZxKzY2J9ZBkTBZrGBf8N88vn3WjJyLwUaDQ/3+bZ8bEKaB40J" ..
	"tTqSnY15Zu2Tj+4lowvmZO2FxZLpgcwqQ3BUGFhbPqYlcj4UaBuvXgwqGIx3mMmd2dwMGXl9lXGOGy9GZRpqoAb3DIqAS/9xh1aE" ..
	"nwtNL4dB181oir1vOKwuWjN+CnyXE0PRWaX0+Bd0mMQkvSuuxBdl13GhrtmK7OIdCvTeL4jBANYyS898lUD8XE5QsCUw2tfzzDTy" ..
	"KNV507uKMzMPsAe8JMxL3s2Btta8JxW9TYtFlPDQsmhqMkNFH2XljBU3xMxjqQqwnblk5juCeKEWmO+88z2IHcdme7BM5sRGGROo" ..
	"0vINfKPN1uGOVndtrPcDfZSPD8OyRZ6aC5ihAzg0lgPLNcHjStxLdmKeMStJJZMrrLP3aHqSmnpHsdPY6qJ45AMbl2c4pUqQMFph" ..
	"Smzq/+0VtWrk6eKpPDMALXWybr3cAVFZMyuxgKsq01Sgzwh34E46+OPcs4WLUX0Z31S3ObuQ3TDm6CuxAVooCOcISsmHxT6OAmPc" ..
	"TMz9ip5NDAo9C0zEZqdlLI7pRc6O8XezAtUYR3Ev5hA2v0fKWIxjQOcaQsaRNEJcZ3CMi18/wLZ5PH4uNRxWEWc/9bwspkaqqGS2" ..
	"oy2ds3wDLSCTwkZW3kze8796p4IK2E0B1LpBleutyz+uhY5LsA8POisNKfwZpWCmTKBKfQEqu4rcZgGSFGq4TeKG4RTnUEgIbpy7" ..
	"ZQ7jPP3bqd2SQrw7CSf6RTM9IwycyufyD71O1FdBt8Ie2gpIBj0u/nWd83HRvOqd6RHIpKc85iGUm+qCp9FI3Bqpbgmlja2G7FS7" ..
	"QN6jNoGKpUvHpG4uDquv2VC1bz1O4IDhdxIH1o/eYVFLOjik/UOviHgfstGnR43B16Wxe2iHGEKut4KmjQirQxkNYx1l920IYcm6" ..
	"NiGHBmoHhVqS8eEpzsGGjACE/kvagXjwaqmJIUsFB7I2unTmH95DWjjXnrlG5g8dyApFzPoX7eXc1szcwpq6SNQHM0X6glwy4z+A" ..
	"KLOrydtAhsELs+Rfm6wn1+S0efuGxYHHzsd1AQyJDQ+j2A+uhV4nv8jLT/G8yVFya5UIKQMYXYqzdY+D9/mKt7Urf1JtFr1ihjxB" ..
	"c9RLzj9BeUj7Ly3bSTAA/7E6HZ09ayHqc1QhLZOz8a1XFM1CT7UYQCDjLeu6kt8bwGrNRA0mkxa8Bfr9+hOUQ4rcGqRjUVLB7vij" ..
	"n/rn9aGtmYdBt52WJd25W9ITbRz9VJnb7LdWxjdas3G0NDoIuxRZ99XVd7nYsDwIotrrdEg8cn2vAE8+XcYdxBrBCvt+FkgtylBZ" ..
	"QanaKD8DnwMXnEF84w0uGvo9arvfWHwFrkIpCjlprvwOMngPXOZ6aDzxiMCJ1AtWbjoEXOPR9pmhuxt4MX+3TNxKn6K8/GivohUJ" ..
	"uhCpoeepBhJTGXEF38vD9f743WKXgJTykoGbSjkblYLxU5bABQEA+1gGpMz5JN/21dr/rc+PzJlZRJPm/VUQnCrqtUZQwtPL0Uxe" ..
	"MNDd7X9xzxtcjJAytabBiI8xFX+T/1kVQtbj4Kv7TwMTXFjnOQtQujM+QNHClego8XiPhtw7vOBFA3C/wakjbm1fdX+lfUMnGtrc" ..
	"Tnbx1RSYMOrBh37cD57jq5urCtFivXYY1gftgV5Xj1kXxsf0WhTCgdkNvB24HEOO2bUiEm0/+kXz3txaq3YHuflcu7dBQAz5UEhT" ..
	"fk/axtF7RmUyeQoQ3LZLDozEwo71uFds6Lb3Hc6akzbgqDHd7vZR2LUoukIrAhkt8SpoEfbaQMfdd0IFKM5XEdYGvJvdVyVctMgO" ..
	"+PFdAZUe8VKGBYt4qRs5iAtlEurBacH5BTRuoDoQrJ7gK9k0oAE+RyEvihGbqs6DhtO9wgkhOxVTXPRZ5hj+1BWiVZbS7bM8c587" ..
	"ig1i/tD4/gcggLMtY7jiQGvvjLkryfCJKQkIc7yfB1wY0ePLd7HHEGONYPYHGLXxrHe9aTIKznoJ0OuL7Ev1KsPSBz+QcrtcT8an" ..
	"SwkLIpJjQjDJkh6zNtYBOU3+BBBrXDuGdsNGRtI5U3QLMT2BZtUegr6RZ1lgfonUoRit6b1khHluUMtNnuXC8F+iuYX5dty9WeF7" ..
	"ZT7gfeVMHUfOPXoq/2McjsEjGCzFIRGc0Cuw6ESk5OxYzdAFwiSMU9WnK/OC3AqmDWyBkKI6qaRsG6SUB2DWYmMv7zopN5oZp//5" ..
	"aZxo5q6Tbtx8O10UHpi3apWqGIc6wRDhcCm8eYDF/pVPwPcQms2oPTC+SAIdtNwy2B8o0zGns6WGTTMaaXSgCfWVbLm3ASSG7Bto" ..
	"X3gijJwpK1ueikglv1y26wlksvlf2Ztop1YGhawo4XI2/B/RcCuf/8XV31QHZk0VKlm+R9GOWhextM0eEtT+lpoNrB2sThbJC0tf" ..
	"xZhw75OLp5BH8hYBEvSpd+o98d34TbCxb8CNJZshKSdQbRczdJMr05qBnwnPN4sKQzM01Ya5IU4zXw8wLiXQpWrWyWq6iakqFzoA" ..
	"nHCps42gntvHwjdMezC/v4exIaeHuCqPYExGz6EtO5ooJsM5ruuwhgtEi0xP/Q07HACdgtId7GeEhyzv5ouI4+cKWNnQVi+dYVcC" ..
	"9pCaxN8/f/xfs2013kJQr1tuIf4tVeBkp99MGE2xkNUqZdoHhdhXirYDLEH+J/xXjZhqSOv6xKhQDwqPrb9ohYMAGaSsI+fxn2u2" ..
	"vb8qz4CdUvzwst/0MHmttwC1R2oYxbOuQ2xdB2dv+yJtjcMDsxCHvsFV2sdrzWs6+s7ZOLpthdqdBv552q+OF3rZWCG/YZTasclm" ..
	"xJ3Kzf2xiElZ0yP4x/E1BRycEi4DYFSv/4ULOjEc3fVdhyZljlZc7IJ0KaxHO5cIPXiTfm6/J+rNyv/606wftzhrllIWYcbf2bLb" ..
	"s+/0E+UF5ONcy/OGfO0UowTGzkBCs9KUOy+CjPYg4CDg3hMziV8FyN7auUyH7HA4BdoMczLOerPB9gPchCQrB8nz8Pt4w3XxtE8T" ..
	"FccJLheeBNKptdpXyj6bJx4BRp8woeXCSZmLzQCXNdn5pCGUJqULWxvD2U9lnOTbFOqzo0cEU+oKSKRQAGWhB9fybdPPohkaD/nw" ..
	"rP3pkj+3+Aqw48i7kHv7HHGjxTWAedlgafbOjag+N/2whIgUWrJLqTPapw6c/taYUwJ2IVV1troFQptzrfEULIQRc0tczE/4FgXX" ..
	"6SuKZU88B9GdkTB+l/Dc9Nw0twHdx1W+Y4AeOFiOZtPMUU1yzAIv4s2nUK5673mfFXV3jlM7bztWZhJW/IVOLfQ8RtHOZ79zjYOj" ..
	"dBBE0XMtfTVp/fsgPDiIgiFuctdpjCcOXEK+LQcwOCcU5ti/lNOWCQXjZ/qoqURT/XSQXjX+ZrIvKzYhqRilYCQI/jeA3m1mXtGq" ..
	"qxsZhm/of79gjrpi9ApCkMPCKnLTgMJ6sv44/cqgZvx6od5Y4dbpJD1JBWJdTz/4Ni1a3+9Zu4/Omu5ACsKiNA6Y7y1aM8YHsljZ" ..
	"3z+HgVnOXqMJWkuAlil95eJET1N/MgE0Dt7m3BvlKUCf7GLB3tRNjY8xS4EgZATIVtGbW7Art4rhfA0dUFP3nrMXX7TYCl2iG4ya" ..
	"QUJXmACGLF0vXA1ZQfQiWYP3qGKhrIPQlM5KZdoWuO8MrQ4q/y2zlI+eHQLSWIem6p8FtY3J3t+6JeXivBQeuEITD38Qyog5YZFp" ..
	"yK21lrZoDTkd+C8nBXKLvV19s5elrwtLwltJasBp/QdofH0h/lMd9Qp6ScbNt6r2DIlOC0N+GntTqtj6c5WxjLdcBhy5XZShPI/3" ..
	"V9njOeFLXYce4aD/AI5GJJ233b4tv9DPiZX7hqAFcB7IfFTOXuQ4ZvGY10uYPwZN9j1yud1YD8gbPBjeVZmQgQcZscziZBAwVPr1" ..
	"Ef3ce65t+73ptWdYpNPrk/P4UgFdZMDNHEMODiwaYxvt2gedYK0bbJfMrmfgdNV504MNiEEvre07bDRu9PNUY//gQGkf/keg0kS3" ..
	"fFbuWpUIcAs5I+AwVSBwJGPYItizjMsbsrHwM3hRuBRVw0zA71qFhFPYhvJVT5pZPaYdSH1XMU8QlODfCsYPKm6EfvuaAjdnXmQ6" ..
	"pEosBV0VOTax9rVPMmsl1Nzc2WlhqgkR2NU0Q0soQX0bplTr+HFzPbcxEwqJxRBcv6KTOyhTHSFiMB3f7PMH/S/+60CAeCRhwB6A" ..
	"Dxpx2mzPBxaekjaNonjVKh3AirMIli7ahUYvjCGvUN0bjmZ862vwuQgO7E/yVePFyMODgMNQPohq7ZJjgRYjzqsmtJJXNb3iL4Ao" ..
	"2/n5DxefaMFAlj3sehym4XmiebakisG9TUnGvZIvs9MfnVkKcWExY+Xv1OMnyAYzOH5ATGELoOZ/2NKlCb4ivM+qaLixpBP48Yi0" ..
	"TWUMTuqz3tYR7foDmVWRJu7UO1aGm2QBohxIITolWR9WsFcaehH4LG8Ay1fy1qKSBXm9ZkG0usRtGB9jRvlr0cQK1pBO0en2RBjE" ..
	"8geEt0eyxQcOOdxNn6z9vz1HpiF4t05W6FWzA815ds1VRzXiinVN85fcEp253V2pp1f+Sv0GwC1GMAteuRXiSjtGpXcwktzk5cjU" ..
	"Fe+S2POB3H4T+kK7K/fqMMHBMe67C1EmW/VshUrKWQFMMEZ7EzpkDPvivNZZo5f2DrWYij1oaLYBEwYRaDmvTCQviTPtJl+UNKKo" ..
	"+hAE/2eULdV3lrSYKoSNkfP3FYxg+NVaXe7nR/Ns4YLbtXj7etZuayWm5G1XERVgPH59xlj1MBE8/yi29qYEyT1ycbJQ8/1VHhX+" ..
	"YRY7W8FcRVOlEpt5bVe7DvRxYy/jLFACEQav8fgxPKlTmZ7MaLfNTvmAimtN6qySfg6iECseJ6m6XtW6upX5b/hAq8PavUHNq1wr" ..
	"314m3S76zAEE+F8XEnmxcQyFB/Agba9T1yf8eRDfL2chIa7Bilvch4Zjg+k8q1jIQFeLV/ENT8ovUxQCog/3MGHJswTogj+o8cTx" ..
	"dcn2wriMf+HWAiOtHfyZYp10muCTsA2r0yMmh7NBssCExnAnuNjlmOFk8xKYF+4DAVzFYqZ/vIqqbUBcDACLSIMpTGczea3hZnq6" ..
	"rTCPXNIQ3Y8g+Cpy2MNhTbKKh1Z5efdr6rMxLbiNiqzYVHsgWvZA289Nv9tETy4sM12IuXgVBSnYbpbpVJg4iLVxwhZc2rFTMvtf" ..
	"rhH3ITHfLRMAArBtKokguTO8UzhJW2NWxIJzMwQ1e+T8AEl+Lpf7jl90O2NX90apmdSXEd9W7aUAUtfy8eIWtxkYs7kh8kDzl9yg" ..
	"PIlO6U4A26nE2S5H4EjPar0AL58XQsRZ975Wjdxg5cRSgEHnGZmpyxK2O0nkrv4rAmv55cIHU1R/GKRKFoYb/1aZfKyS6ByX+ibG" ..
	"eWxnGBTwzgkbxy7ZSasb6ZSnkQJi9UYdXWEOOd7dfqQX3m1aHSFRQ5sDYVHSCfsBAbnAXyeDhJzt26ppHnGlQ4bSIWpTKhr786AH" ..
	"E0BWI9Z3J8sicp4xcfS9yNH7UBtHitc/WRn/J7+T/RofQwzzuYS4o3X1kfxMIQo2VTD4mItDbgVC/BzRAfmVSoX26SfFzBWBgI58" ..
	"CC0l73UxM+A08WGimgjxX5aysim0kIGbqrRdG/4KXKA8K4R3EpQJ2C+lgHcoBFOhVpBx2e89pAYFkn7fejQbiOMI0l8zrFZFA5b3" ..
	"xZo5LYrtiqEtMes+BXpH91SbY/HVRfGExPTkQEnICsI9sf/k6j72pwaVPkJ8hsmj9QE81iCerhdTXSaJzGANy3vL1HPc1HGwej+Z" ..
	"ZlUI1vG0YJHojv3CNY3Tab/BBhCBJEJIkgePKx+9+GZgUfCYUDqSnsnmwwPVhdjIA5cfP86uRlMDoUQPGcte9aW9hgAHrxEv8PUG" ..
	"MEWX2AuwvJmaDsFcxuQT4vsD5pOe0IaLMHptqWHrIod54FDAofOveYWJG5TifwZw5zH5QL3U+EPULrkNnsB0Ga0JHTHtKEZq8BZD" ..
	"azD+DaLwiA+ucaYZ0BA00y+3dn7IkxtotZO2GdzbMCv7Sr/mtawiy3u83bn17QEAs4kEdid81IHuyuUYFn0GOpFzULWj8OvIlBET" ..
	"0pqStgoxY9E5J6YCzxP7IEdTOeS6q6UN9hf0oF8ypsOKleoK9TtKdhMqcLtdGD/MK464BqVxARU4lRljBnTuMIAtIviDxqbiFtwM" ..
	"dJNmu9TrVvTGTyEz57AuCQ4F/kSzv8uce5/xsYnFeb3LauOeuxLHNXoWlodP9EAGChEz1CZhCQ57VdQT3CHgtuRN7bIati7xU4q5" ..
	"fhjp2iXQURquX4spQZhqFJOHsvJ0xep9e8MM5q1KfUDM7gKB6gGQVOhDH9r3SfIJHZ1BuvCTSxCRIOnnx2qmbqwNGL5gLNNXmWen" ..
	"uVCLnPA1sLEdjM0Zpw+QKZfbOELKA5xuBWOcz+PbWhmjUO5CMtnRIVR3a+bEDxol+LkQaBrqfXPM4Q5oFsml1MP4evCUVxwTiIJp" ..
	"+/W35EA0Z8+yVn/gNlf6RPmNxv/EQBWsrSVfNXjTXaUlA3VlCiORxq9g6+iDYopOMx1BEq0Cta52lTTQgo9LLLNGvBl6ZCrGRCTz" ..
	"RHGn7OuSiI0gL5VQZt4CYUdRcFD0M10ya8k6h5FhohQ0rhZPR8Fs0dfOy125kc0LTLtkC8ZTadr95oz8BL6EAgMVeTWA2MwSdadq" ..
	"d8LJGCcIUpRuboTwXnrcCoJOX+upDJUtw3SD9OuuN2aB1D/tC5dw2VGu8DvEOoXJ7BrTj+WNESpkee4EPc9+ckrSDWR3ktYCt9Ap" ..
	"3x0rSxm+shuTvQIFDkcWYv1/g6sni0Qlm5QTgEN2T6RgTSIavHax571tRnY3xPO7EYhCDKEiKgQYeE+MBQGUVd7+kHhgOHaRQfEf" ..
	"KDlUodqGz3HOb3x5E3G/b1HMKHRZOoFyEFr5Emk42lKkp4SuSURvGeAglQNfp+OHwc7n4Gxt+PVdwLQC2Tf+xA6M9LWqQR44Kh7+" ..
	"Q4cXw0jm5jsE6FKbrwUhSXR04fiZvb0RemF4mRfBzvkfdtCOQcr/3b3wsYnHZITqXdEqRcHGV1u5brdykWTMCqihFqb2ZeyZjygp" ..
	"3QhDGh8ERJd7C5D7aQ3xmSVxZ159L6N+UOxNPdx+LcztJFG41CFZVShNX7AvKPJY4SaQ8dxv2n+aN0vmOP4OOa3LhIvmZNRufVL4" ..
	"O+8tkdhsk2eUktG9zrM22am/2PpAQ96kLK+lo0wLNv5D8LmDXy3NJ7teX6pVxex98cqDA91UETiCb0yRE6lrRdxTUGGeCn5zDo1W" ..
	"eW/GY8ylisbE7rpCgRluKRYEdth4VTGdw2INI/UwH2CASsBFjXxJTkRvT3sMOzoPE0mfLLT5VGuHw4iGBOJyXlufFfwtrtf6cK1H" ..
	"JC5Cl0R1hoEYI9Si1h+rTGyLcueCcJqFoThzEAeVc2b6UNr/IQyjQchOvsVL5hs3K0t5A1khSP+R5IIWTEKue3ibZ5fR3JcjaSYd" ..
	"BeHy4vBHeUXEaCc2FjtHYCFYkjhEbO+8C4zBuuEuAGGctypA5FFf0PT//lvA4W/tHB5NWjlQqBA6Lq4ZSyatKq+rS8VaBJpB3EZS" ..
	"4kclb0BLCBqKGdIikyrB19RBLdJZ4HC/KYmojkIQCdvhy/o79c9pB3vQyZ0Ps+pqK23BuIK+1fCZRFDuNdni5lSivpq2nEWq29yo" ..
	"s+NgOEgmDDPtDLbubUKymQwHMKc4hlRkjXgGIpdUhQa703dpO0G+2ZJylkVglSIiahT9A49BQmfmcsj8sC8+aQOwSOc2oLUmVZFZ" ..
	"1lUSFrrTAJtsLTM4XaOD4OzeUouoYVAlWfeoeBEWP7dvv1dMeCk2gGxEP6jZNAV5As9CTOaq/WAe3pYiZJyxgP7Bu+Kpr56A+8Zn" ..
	"shYx7ybliK9WbXZo4z768J8hF1CjFxZiwnU3hJLpvTbvBmVpmA5/kXEvVvnJbPoNuGCm6+QELj2rKRnoeACwyOe/ExtqtxNZRQJp" ..
	"tdFU0Aiq8jfPbV+gJc1EAeXv2pJ8GxCSRO5e044O3ODkPUoU/NoJiS7plbqZhXKvWW+spCM7OOP78jCZZ5A/LCEx5989B5abPEjZ" ..
	"EI66zTcjnqYKiFp6vHeWOUqrDXhEkFtZij1VIOKWmG/OUqwCRMhy89r3EwuECv25I8QU0zfY8GXD3Rkbepd25a/0dQWpe/biY3CI" ..
	"uW3F4LnUnCE8jL1xub7gx7nM4U0MgZxHptLeg7Vxq+dXKr90Ohtaiq06UH7c9U/kcyRx/V7i9AeA5aIIYCFwSoi4zzxm7k7dMIDA" ..
	"1bEnulicf6sO+UYBNYDgUF4OxT/C8lsTiHNBLm7ec1tzrAMDKyiBAEUkFUFLXn4voLFTVbhcTTjQUnpqO2YRtJPR6u+vToZE4Jjq" ..
	"RbVYYT4huyDxBgrBFQ6L/rOZHik+j3DL7YQekLDTdJrPATkwAe/WfWskhvDZKwD9LFvuM70g/D2u1g84vUTCW5KokaflS0Qn3Yyf" ..
	"WLQwJFanQUY8oTYtxxOf8lFglFqrh02/xRAI/ZGRAtwMtt+lJd/mb90t3Qy3quuGl1mdbdU9jpFekggaSkztHOOhdQRDHxtzzAB4" ..
	"ftGk3yWLB+afEhloF3az342CNASG5rg9+iZXPEAVRcKCS8butqstbRI2Sd9E2m/OGWYEwboHRlVvH/Ltp54hsEyiA3TC4zZoeKjG" ..
	"F903gyMTVD/fuARFvSYifOhavK3wcmn8dgn1AJce0jcR7qMHsyMX1iBmOz6t8sBw4kg7F26i6TLamwFm3fIJ6wu9HTB5TBAekK0j" ..
	"ItqLyUmfyFZN5uWkJ7RDvGLz3xfzjLIx1kvKjJ/kz42KrH1YRnSj5AeW54Pla3+dW7mTRHnNjd+25Scqv4oXxqqMmX7Ix7YUI/Ba" ..
	"np9Y6h2OFMTnwBuKPUI0pU0jw/i9hgVFjFPdTtk1jbeMipJ9Wjq8mr789LDuimSmW+llqe+sjeVXHUEizL65U0c8jfgMsmnAGj+D" ..
	"B09mUDac1+vyMZSRVTEgWPOo9mrNGZJdX90dW/H+KeCUL3P2og0W8iEmj95k0Z/N9RCwGXVMnkFBjU47gaoRmkQEiv8TTVts3x91" ..
	"ufbzSnI1r2srajGACJmIiw+G6OQoxNTav0mRI1XtgoNTSuV926AjhxmC+mwYJaawQ53NnV1IqL3+/DqsB4vDeyMEhwUWvuGJ4Tjr" ..
	"fnm+WJq/9Q7dWyW5ABdGj9rm+rVvBHd5C3pSbKi2frGjVHx16dlwO0Zj0yoySWkbBtZmN11f5wbIKLEDdBMfqSloKvEGQV7frxbw" ..
	"ihU7YXHZd89ydkcOukeuCTONAI5H+mQyxniHFFQWc4q/8KpHm5sUJ9Jjw0cMv/w5+IC7Zk0OvA8sQv8q7wqwHyGqi4PcQoDKXUQq" ..
	"FHB8nPrtYX8L4Nsct02iMpD6o83+qzXAAkAw8UICIufPVDkuRre6/VABjyUYNroigAFRNBeiSdKbCQ9/ObZWLhQ0lY1CWzldwr0M" ..
	"90aev+iJgydS71iJliax44ew8GFxyVphaATpcsksl7MTNNcto1jqO0JkbzhOKhK+g1WfMapTuv4fYQC3CEeFVlaw8QB52Ju+sqjl" ..
	"GEb9cxkwHm8X/fR7Kbvf+KdL2eZGF9opIt3R/YjoWjeqFjTsOPoz0J66lNPVTeEQ6QE4JIA2LX6f0nsaZDyoy3AvGp/eKBcPm7kY" ..
	"o+AGGQ8fi6aiaPjbW6nml+Eox3D6plNDOf9oXEmCEgaXXcX0nAmqoRy0RshF+yrZtLtom+sdK7fSzGzKRP2e7+Hvi38LS5Ei8ZFs" ..
	"MVQu/LZfGIas6x9Xvpb65YCh4vhfzc103Paa1tZ1j24jbEIdoMF7NOTaQSG2C2XiHFulITdzTlh69pnm6LDq+YNs0O+opME4FRNw" ..
	"mBR4XOykDrBxcejo7NJn30gmgLUips8Pe3Op/igT9yK8lzdP3GKE/lUNTTAPy6gEJO1tVyTkcj767ZE1YsjWos65HOfEVKhI22zw" ..
	"vtfoJlpMz2qY5PmVkCWk6bNrDGQHP3cHkXD1YFDfmnq1UTmPZSyVx0lz7b/UMjEaylnaNq/OwE6Dd/XtouebnvqYi7i3+acW1c1y" ..
	"PwFGNKOnOITCiRHcNN2FWnLhPwKp/vteT0QwxYUzvga0cAOVO/OuGCNN+1NJd45qT+2g1VkYeFrOSrnfhvVl7FjgD2kLlxZOIhqQ" ..
	"gm+tu4/EPuBpq0HeeKv10ORITyuPF8VZJjpeMMrc21neoJNh35mXVWTMOczXE9mdr4crBnZDPVilNZeNmLyzzb/8EoAUYGja0e7w" ..
	"ZE6Pj9/vP6wXMeN/2IQZcFIJTB9DUJ41H1TKYb2VlNRD0DakHpE0hBJVuKNGVuoFNExeetUAwQbQn2mPqxdBdTvY/lRWrC8Kj/ea" ..
	"WknFgKelZTkBziUxbr5+32hItdIkbvd94t62UklWU7wLfaT9p0QOgtDSCNPyxtbMGISMUSW4snEplb4ReP2zVUT/DtNWi4JQ9jbJ" ..
	"AaZ2OGVBsfD0dlV5YKRKA/j5NP2yNQLQ40+ua/AQ858EkFpSYeGNMqKzYHwbENfunmMBESFupZ/10ba5zTOlrmNRM2trl+y2En2g" ..
	"xgajQ/AntoXMSLDTjpt/dgj3/79sKvgCCjET6Hnz6RbI5hAgN/C2beNj/dGWm/UkVTVS9GvMmAa1ZGN/9dAOnaGulA0+QXPv4IFH" ..
	"nRlhjCsXz25DgVnlg6VB8oi3WCyapxLIA+eWqgg/HxLmeiOTX9fvCMuypwuzjUxJP8OaaoffOiClkqLpBekuPKk3dT5pjnsANzTk" ..
	"ffzQrTgJdOhvGK5n0wW2oq08NrIkYdtMD0fGLPzYhg/9mku6g3udgen/YIM8ORLnR4tp0riQgj144ehUFRZcCUCOlVG4KS/6/N0i" ..
	"0u4Cp9j8M5i+WroyXpOwlcHsXsPLPZci0kAU/SIicFEaGA3kVyxefZH96hzTBIzs2Sm/IniALUhrEFDlfhcWMr2t3bTn9R/GqGzP" ..
	"9x10sq0wu1cs1ZRkzj1yO2WenzmodhqhnkyvOcRmJDwf5osiy1cdiDVV7zg46PdAxIKgvWvQEkLbrdkZ/XydRZXJgChK0S5m5ty7" ..
	"fEfPjRl3zaLwpb2X4iEAKt+B+fgBRMQEmoRgX/NrlVq3Bq/Jf5IAR6LB3E9vdw+PurPlYMeFRYlwf6MCpKrGTuUSkKB8WpQBUyyQ" ..
	"60cXldxSwHmyDq+ERCVZZKbMwwuIwdIeUhF7UCR9DFRnAPg8rcud+crYU5ErSzm5rq7QIOlP1fJjcG48JRMdJnsLKFhxhhrpb1qY" ..
	"2LyrMo3anKs8yxm2ooOcC5GTbscpX7Ejx8aY1SA6/fJE7Quscw9TOyz9gRcsuFlboR1rZntjGEVeyPo25G6FRhJWJnFjABoz6C6A" ..
	"sA9Hu7QqKLcBbbL2+SbsQr1DcM2qs8SIBQcc3RqmW34UGUwfLnACITKTpIIC30kmTPX1j/RRFMAfmqpKfn4vmOwr6fVaR3fNFRc/" ..
	"qwTBfJtriD0ygC3UsuJCfnv6YFktZS5FQk7AHaxiQy9hENf6ej3un/SjpT0P080xBZ7qupMFghrQHh1XS6Gg4th+f7Rui/U0iIcU" ..
	"IKtLYPnQEyEJ/qPNxaq1R3OdRT7FSfkcWc8iOkSWyfYcHUSYlGyXldGLz7AeEIpGb+cshb9BTgATipp3W2mVGk9jvx4dDlarvIoF" ..
	"PTHrtB6DtuykW2PnTSFk1zvmKsf2gsZUFgBu7WISw/IpBD3MmevlN0O1cMQOvpOqKweUJdq4eF7RIjwLl1eQG5Zy6QnY9ZoLF1CA" ..
	"o0u56OozsTWVLPLyu0elwf3EwC2CuO/YVWcXkezPcZ84gYJHW9688nlnOB7jNUXvHCRcF0likNg1HBtCeTTtHG5/gf1AsycfRPb/" ..
	"5gLswni5UkZybw+Ghq/v+KDrEJ1ONcbB6Dp4r2CKxOGzI9034KPTu0pkiFxDJBm3qXWgNbcJc16xHUfr1q8QtbJjlY0Njpmi+RCq" ..
	"/P/j5BTOYSw7H0vpNaPTqhdRuxx003evGb/jnodTrN7OZH8azCRuLX/m4NmUfvW4XfFksAQVISGCZMXVWMFncnOLuk4Q6LH29zLB" ..
	"fZ5iQruuxnuVje5mK3moCnE3YQI+JgXobnIxR27tu1DPXlJesqphN21AmIbuHGN+y3KrInTdO986lZceGvWb6s5ZXDBJ6rsZbPR3" ..
	"7TGBQQnTAiuf/jUo8JAK6vxFV0Jet8WyTX22Zo6RyHUeWTmuBVjUC3X4OTGCXjPuKlJpBMC3n9xKjL6OFNyV3M8KVfcDrdGLedrB" ..
	"3GiECxRb/BVdEFWheaZ8EBGk4UcYR/afk2k+EdNVeWkEK+/5oEPEfC5LNP2hbFJHG0iIQZSUW2M8mcFsgYedc1LTRstRCyxtY7Bi" ..
	"7tWf8YUeHaSZ6yLsNmi4djGFpX2NfnJvZrB0cUei95IKLKDGg2k6TJNTMPoZ7SfhAez6TZwqCeKaXrjr/RoTTk+xcXf2lD/DJ8C+" ..
	"8nw3fC77ws7nytOZuEfth0Q8N18jIZwfyWd24zjlFCG9M+lh+qv/f/qRWuE7OTpKAfBG1BzXMZU5v03bGxPAaQtJiXzXybWyi0ZE" ..
	"Kop+LRrxZJ0bwL4D6i7cIzq8REWlEIRqiOkeQ6ARuzEa9oRuAFYB35M8y/rE88pn9ELoGFEUCxN/xptJnKgq2jHGRWA2HackAgMa" ..
	"JlNX1xN9yJJThchEPxGMagn7mlivFTa5b7vgZMOD8AwOWq99XM+yJ/vSx85+vhLgAiDiJHy4Gzc3bw9bucJLWL9TS98aMtzJoamn" ..
	"XH2tVciCrL41NIbgCtdAEutm1T3QwpruxmRC4YyIYQ8xjLAKLStBGehjWU68Lmv3I3R9WV7Uj2u0o4g+tah9r3lsaF5TAFlzT8Lf" ..
	"tor8mCXXTNIr9cYzpAPWI01PK0NioZPReC3jgj+g+dZummRqYYaEsXka4y4ekLoK6PavQOhGzfg38aIvSUk2IMvrmMFyhrs+LKHy" ..
	"8jS0yiWAJzj9/CfozH4g+mC41MgGKxHc6c1XPp8NEXMqnC+G0lWA1sZwZQrqmGDJMZnPE234WDBV9ejuYE70ctOn0qvoXcM/wJLC" ..
	"khZRC14as/llaeC7XWa4FcET5hSbV4QgNAbQWj8NbpO0Ikj+2ebaOZYa+MAg6N6pbMheVD+4gn10AGXBsjZucTpnqkeuDUWFLbyh" ..
	"nAPOm2Ctj6tsyXe78ZdZIOoc3lMQ3Wv8uJwVNE8XDf7TR/aqea86MDkZIVHZA6fFPGyrwKpdDHMdho4qwuETODj8Mn/teIAIfok8" ..
	"ZWZOXBy/7UEWz8ZUMzM4xRhiDxm1dHIU6f/anjLSJnxdIRSi7IsfdoHIuokRvhWlq1cMijhxKifjKusvD3QnJzEeAiwSqDFpyqRH" ..
	"5letFGiFYl8JKRkaukHoQDCnch82tYQw3cJ+OQ0t02Qk4ftPzeIZXq9f0Z2m7r7ClcDvsu+GQv4kC/Y5fu95ui9y6LUMNfebCPpX" ..
	"ZoOxL910zXOWgXskNLm0HpnnncqbovyAu3+aOpmn8QvbeLUw/kJ0z44MXJ1muxlPW0q09OLYxu7yx0Za3QF2/l4rU9yw1e/zukuj" ..
	"+J6FW8KS6p8mg4s4MGYoC0lR8IfxeycN+BTDDD9oTDXKSxJCXgUqNYl634AVweabRpgsy64exJa4TD0R0J/zAcG4dVkDVFpRaZzM" ..
	"skMnF9Ym1ylMZAjCOUoJHTI5hW6jQlDCyCog3J70m/MmO4c2JQTd5Dz1RzaaonFTuT2gNy+ibdW/0sr/EZBvJlQMWFUIQ3YNiJWY" ..
	"p0MdDY4mG4I3A+1PF0cL5y+jYW1xJCC6mqZ3+9y93neRqi7+7ICsiwuzzHqYjDULSJ3p3kcIRWTdidr2jWMku2O2bgOqzh6FkC6N" ..
	"6FtrjeD5nrgGVPdSffPlnIFZZHvX7O+HEH0BS68chU0zqpvnWvS5FyFqK+aENN99sbJvqaQxFoXqMVlHs7iuPcxugXHj1+Oe75oq" ..
	"qUKxs1aDmzUmbHOciRUORQHPGh9P5fZp349C3mrd8q0MAMPX5OrV8lU9jgsEGGWW5DSYwaX5/eDvvn2V1+1ZUDLRceP/8WHsVbRL" ..
	"1Npr3e+d9m4RdLUfl+SexQv+j0/6fhcBZevV6/Wd40225XvhkeifrcKCP1J6XdeHccaTBMMxYxvQLvUcrJB8Fguezkrw08l+Fd2u" ..
	"1130HwsiFB9GimNGfKVeWYx/5UrzyOKG4lBUZadxetT2yTyIUidrFefoJFjHJ9rhzT7w9xFv2dEjSsZJAX6MKDIhxSI8xjSzlhfI" ..
	"QgR/66ueOvmClFzeWN/leAZQblWGnjEwMWPhQ/lcnQwU/nVCrYTL2jpnYcVpdHN5cQjvOtfFgYqiCTkavOZq4W032BpacfmkBa1x" ..
	"7w9tPRvlbxkpdxNsxvZQEx46K1RpUUoFtVuixJ3nvm3nBWcvSbVppToAysd89eQ1UdLg9BNVwIlOrtYPmt0nHP+g81aEB7NmD7Hx" ..
	"/LWq3dmIksDVj2EpYcfxe6/+6Q/48+YEQf0vy1tqnpsW/t7qbM2vz3N/++5B4DKjmkX1EiynIDSsjwwr9U5o5AawEyMxHpfnO01/" ..
	"LEAkkUodCq6bAIzH9DFv6w8VjfkG71JZMYHYByHwmKw2di0K4wifXgyLaEKO7gj2NXP/OR2bikyCAKTfWo8J1ZEgaiB92+4BCNQz" ..
	"cAOcwvuKy2Q0lX9GkwbGIi0/dhHQ9tAFevmlgOsk9IiJvyt1LlDCX3v2/NVcj2omhR1LV4Hdvfr/qvUw+Bgim9Cbts7WVj3fpbuG" ..
	"vYklJlGBOEzrd10PxX7awGZ7T/MSDoLdfC+NNE+ieRNELN/W6xJwR9/EKmavf7HWtJE7QRyp6pokPREZInosmzUx+KVDmxVFI3os" ..
	"RPvjohhkWlsT1Hb6sAPeB8l2ljrmKjlTkyZ2408R3jkJUWknBSgM3DWqc61aDFsOG3t91aRwvwvMOzYao8qGC6gUGRHkwTRnh/a9" ..
	"Ib3KSORD5nKpkNn1xGkYMjsDZrZimn+WqfSHhaQ6U5lKLEzBpTp2FWhK95uNU3EKMRGABzCbrtywwlNUIGDsN0vre+A5a/PUb3oE" ..
	"X3rnl0lvklKw7lfp28I2NxBnnhuw85PanYKuHox2h8ZoFP0Yx+LrEkC99rdHKfDjisq9HI2pJnKK7Wsz0qdIQFkM6z01ZtcruRYq" ..
	"swVGmBHktG22ExFHwisHVP5Po7kCVotBjiyXI16zs68oGz1sLU9ijc5ohqc9Wj8dzaOHV3Of0udEsElZoTNVy0jyfU2MKvwJC66Q" ..
	"qA9TPOBygA+tJ7GKqusYkLm6eQT8JRV1ceFanSBstDiKUrPKEtFSMwLcp3N37kTqRIxQ3r3vhkJdTLqeTI3Yr6NPez6ip+fxr0xh" ..
	"iPeYQA3srTA+t/7g6il+Lojbaveg6uEGT/3RIfwCBovQnFlGsbtjV4j2dE9sYo8/s2oP7OUCplBEW+2UJD6Is7DH2u3KafM5wzL7" ..
	"pxBunERK3T1FQ5N+4PwgQqZ0KFpGjrwXj+hQAocZQzgIDXwJqwURs8kT182k4IidmKP+p+EqqooJiaCmQYZDQl43qfbXbcaG9DVq" ..
	"WMv0H6Es/wLrSxsOlVkEDMUwN7JPUN7tOm1Yj7t0XesDdDz1RL4xZaOrrXHdqVLpok6bDRG0qxxDiT21dN3mAFV6YzRn5fk8/y4i" ..
	"wX8tqlrHDnsqKYwhuupitPoCnV4nymCRwMF5auhTzyctuqAP5DIQBtdyHsGIxFuUDvYLCBlGJAJoJqbBBnQWrX0jXGwIEXnxZbox" ..
	"MgGIn8WI/22Q6ZryzYoRngOqPkfcgsLi4hbTKgIoducx6BaB0dI7puyVsPmrBOFUdMBg84+uk47H5MZh38eD1Tb5Mr4zYoSz2cZe" ..
	"qcEJY00BI8S/e+b+wzQyEJxlEz3AyFmjUkKuHnBCi47QJV1C1By0Y72fmiHoHQ3/6lJbJLAyHjnzkWwLqnpyS+koh3P4fbaiRHa5" ..
	"zOx55VnNskSZoq7B3EnaKypp9jnQ4O34HJe7DMIkaWr2YhRzS37UoMih2GTnzvwfX3FrvxomRPktsvzZeohtU8e7n/CgpXDMufey" ..
	"OR5fnxxbiL8NL9FL/WoIDkzLolCVBvX4B+7CA6cs2ggE2gPwvMBr4EPtD229Zqx19WoBZXjReD+OS/VjMHfpsKhzGem1e3WlYydt" ..
	"Z0H4CQ/Qts4m8+qm60CnYcrnVtVok0oNorFy3w1/44d+xwvD7zwpVycFcexnlA9q7SmkfOmU3oSqRLH91Dbq8YVBKse1TiYJh8de" ..
	"i77dXh8uSE6ZpqC3biGGJ/Hr2KP64CcJE3Gb8UYzsusFiUB7zB4yVcfYaA7Q1i+AnI+jKnR0YDiVpZMOuF3Pw0Irh/1Z1mR+7t5i" ..
	"fRyt43D8Z45Y+IoFlHuNOiKhCQEvCLp4s4yVk2CED9Uinv5Wm1J/nV53AeK9pKqe1DYo7BNwhCppGy1sY3Q0k6eF4z73MlMbLK8F" ..
	"a11StBOrXutKUJOY1C94sqZWUMaOVSZwu2MEZEyo8tnKtms0qTGSYXc9+tWMV7GP+U2ZvGDsBSDxxM7ZzHu7y9adWTmYdBmA69K+" ..
	"94PI080DZ5bMZ2QfA43BlsxTxx9gNEqqU7wTdgsJhTt32muQkr6vMHZVt1rA6m+xk+hV9vKa5vCQyy/7bz721D4hvUlScNjwbQbK" ..
	"/5G1UIIj0xlThdGxITMmvDCfK863Bokfg0I5W7ku47jg2ycFZ+BiAJw4+zQ06DeCsw+bUxXPAGyRKiv0cL/8URZi373nXH2hzExO" ..
	"WNtO5hXhg00TotTnkUKcPJloDF7yf+Yx3LOqEVvdYi1IkDh0C2gVvpNHmOZiYSmKSZj9acHg3nD1y2PEH7MrGe5IFENGq3Z7GcHK" ..
	"SbC727mCqPJ5CAkYPZa4UA/c5BARaiEinNA7Cqv+HwH+Fvt78jM2aXUNLynvqhs5854EuQkdaQQlyffRPq/Bofo7Vw1PpJRTHgje" ..
	"27dB/623DyI/UwpnzuMiWitpgmc2SumK1Lnur2/MUmNyvmQ3zCd/CzcVHpEWKLYiKKCT1ww/samjtNZi0fwyMCsz3On9AWnMHXjY" ..
	"JKcMe82nHcQ06QyWbnNo+idRpcuXkNtj/rOWrysEV3OUaUA8gjFuTHtIQkgnvs5zS0lRU3PNLtcuyglpb8s0apDSNHDet864JRsW" ..
	"yguX3OU0qlE2SVrquXytgM+YsOtjx0HIzERgZ3Y7MzAxndFfdrDbaGlXwipDGvU0BtvEv/Ptz6yaHLI3E3vJozo4ASf+/pqQSTpX" ..
	"1VxUIt5WAJ8bL/YKPWMePFf8DfLDeCsJLtRl5J+Ibe55Go0UE+iWf/jw9Q3OxMwlYvawkcSmbeKkPI8x4hjHjXrJwzHCp8DSTaN4" ..
	"AszGrD5wMpw+rnRv2wUpkQKdWE0K+0KP50/82WEI4fdBAy+4lNX8+SX+Izwuj4Y7tWDTUhZouXVqB8dHZ7RvLUgNtOiOLhwKgmgg" ..
	"UtoEzhK7lHOeh6YNFHlKrxosSrtqGrNtmrdIg6ZXbBOQzP9Hvs3fW9w/tCYXP4f/3KZLlLsIIpZ3JTya/k1HKEp06LTsyOxlZKt4" ..
	"bNCG3pGBxOWT206LmWaOHByU1t8JcoKdjVWlrS5thQczNiktIYCKmZIdAMh21g2H2j4MtwuUuyQNYx2HNPzGILeW6Y9OlLzGraw5" ..
	"2vUIw1mjavKGQCN1Awuc6f0d0ffNGOaR4FqwmPs+TJA8X2tywwpqtqDQQhwlh/7wGh2U25WB4rZ02WlBA+wNw4XgKmgrKZXvVfhp" ..
	"zRVV8e8aRKb4yUy+PreX8AHrLCGTeZBvweIACGvKUI0zEJRuqzBv7HUGdRpOFa7x9GfASkMKHOs+3nY9eo+jBuZZoFsRrbLwN8MR" ..
	"fSSDs5qLirf/VkyEGaDn9ueuwH7JOS6hll/SKq9rMhglqYgZ4JMoB1sW9Z3ZQRyHgCYsbs5Isd3JYxVUqeZbOOXmOIGQOFEgQ0ci" ..
	"F6biIabyfA5bOxfCW3BGh28fwOkWZS5IscR//R+iBt3bCZZx96EntOXvA/2lkVR4w6PdxiTH2ZIeZR8zOU0jHEoyo+KXiZrsHK1W" ..
	"Wtkx3kcRnAQbGCHInHNFYTwGvgfSIkMkSaQPv0q6/jbo4T0ZXd7LIqBEAwecYWgfN54l86JBCgApy9XvPwwmy63ZNfRO/je1yDcA" ..
	"bFLe5PzxaT11SCArmbBG01SXQgZbx06s8ufFHTPz+JPOVjkZGuPDo+Q4tJe2GSRpR/TDrhR/JKvBz+kLGRcAS4hxv6Nnhgk5thUt" ..
	"0G3FbXsZxM7j+UumlfKMDJKEMwbQ4lZs//953CiZm3+3L5o0Lba7mmeFK7lura4um4B116lEBhmjLKTClTYE0cQFEjbR3KOq6+Rh" ..
	"uzsqp+Q3/7iD01xNJfWrw+IiGxJd8O7V1ME48uJsJg8KkPkimP28nKllsQKHSI1ClseK2pyVsBRMktfY/2GMOvOPM1CCtsFhQqfZ" ..
	"3T3F1JymKcHslumBJLfao7ZdE9X9pK5HFoj5bGvNhlyrJyTFi2CJ82iEILPIicT/MbWAieyH0zDfeK0vi6XWElScBajOj+fbaQ6C" ..
	"pMVVFjVyLVWxuOODVBNoOmkWgZukdpPV0+DPSatvXqKiDB1VtBasjzIdF5RrjcD0Aj9jYkuWRgGZQyAC5AwezZuuS2Istx6zf8S2" ..
	"Gify9OWUy+1B6StaFTi91tV0nCUo2Yj9Gyan0l1+Kqp5IJkth4sba69p8Cn2TAhnP2VvbS+LI7E+ivpFuely+JVXM//QMYsCNBOS" ..
	"NhKST9RA8WYMKM96w4Q3zVL7vReVzZGvqn7wU6y/dMANTi5m/kaKeX4NVJUqYuk766n8GuHXSK6Rs/csEfvy90Sa+RWZAEv1Og5+" ..
	"G4kLAbL7eJZviFAkMssJY7Z9gPffNKqnvGsKM0aSlgCOFO2dKbokWqyJcsaRzffBRwaNEE+rUu0UzKuwVoZvyk00I+HLUfHwh7EX" ..
	"48C3svA7Knb3thBI6CFuheBBxnZRIT6UjRUJy29YN6gUeCIcMjTo0/wDC6JyVTYsd/ry4trN0fQQQGHMNF9NZ7pnqZkHw+A//SYA" ..
	"DYsHRuOfYUjAZjs84naXvTwc7h4yR7bbkbztMuavQwHeYu/nFPoS8jWDcICHNYV9xHF13pGpK//4d8FdeENGiS2ok5tsHBu43ika" ..
	"RNA/1vf1xw/4GiaH1WBgcoTzID5CW2XPseM=" ..
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
		elseif msg4 == "thiet bi khong duoc phep" then
			errLbl.Text = "Thiet bi nay khong duoc phep! Lien he nguoi ban."
		else
			errLbl.Text = "Sai key! Hay thu lai."
		end
		tb.Text = ""
	end
end)

if not sg then
	print("[DQFarmLoader] Khong tao duoc GUI. Dat getgenv().DQ_KEY roi run lai.")
end
