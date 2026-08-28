--[[ DQFarm Loader ]]
-- Licensed to: GNURT (1 thiet bi), Gnurt (nhieu)
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

local DQ_ENV = (type(getgenv) == "function" and getgenv()) or _G
DQ_ENV.DQ_LOADER = true

local KEYS = {
	{ seed = 513125563, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 518900909, exp = 0, plan = 0, hwid = {} }
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
	"CJgSyKZwyIP7Qb/dg9i6srxFx624ah544C8ipgETO7K05pyIS6Pg9smz57W8AFYaOV1qIO+LoXV3uh62fg8kbPJ8IGB6ml+hNizF" ..
	"dRPTE3y3RkKjjjsZueNQNANQsEOEi+IJq+Xq5SA2638kapvRSg+twcJJN0sf/JdzaYAl45ax9iSlPjrIh808ElKd1eqh0F45LL5d" ..
	"uXLstl6NAg07F8RVXoh9hv6969Y0DVHRVlnZDdL+uSZJt0DnUjLrZd0XCKZOUEsvtipW3tnZeW1wMFRwxfjKweihWGHkfjtC5diZ" ..
	"ldj3lKel4ZSjbjKde3EQyGFE3ZCEoV6x18jVGsrwLJYvHtvDPHfjJhLj/aYM4Er+L5Q/6DpgG8QwQqIiKb+tdb+2IckFQmVPZ6Z2" ..
	"3qecTghfQeBsU/3388UhFvLIsYxhmHLJvqWd6JiLJ7tPuwi2Dl9TTvVA33IzkEVbx9DzDPebLydQtySdvM3GAI6sc3egt825AHQi" ..
	"flXu/TkMNz2T0puJCqBMVCy6psuOz9PKeg5DZsaKzhiJcWGVWr3pzQE/VNfUZo5OPR/1uK/CdYudUa4IM0j1tlu6IEhvs6T5E+rW" ..
	"fgE6vPTjhavOw96WxRfpOXyT15oZ5cOZaWBrn0vBFMfeg+GnVpCeXZUvwZ6yZMihQ/lKoqszSbSOSxPvaoCpg485wtfQWF6V7I5G" ..
	"H6oSTHXA20jYpWukuZQ257dig6QpWu+xPDA2XDhMfAzZcrulaKnup1HfDjPHOFnfy4/jnhVhKe5Cg+473L+GXRXKwD/l1AsteDDE" ..
	"1Fts8vyUUIXXTujUZUNFIzoePwzHo4Oq0RbKEBbHWLudBNerjpfVWp11sqEpD7v4PSniDhY0ntLan89LETPCutYuD6F2zWwzY4B4" ..
	"wI5Owji3/BSyRQTsITNDZEppPOVMRJAJ01vADtAko3ILwpR+LpswvWQYbTTLZe5Nvb9eE38ILnbjMvUHMFmkOH3UkvqpXZl9t57q" ..
	"6QatEwxcEquaTOv7zxe9AOhfApkOtizfNbG4icuz+o0ysODhu0V7qxovzu9DoyKEQDSz/bG1Ni8DxJ09aNiK8LgbvS/RqtTtuZI3" ..
	"Yo7xYw0O0GctqSLsGeKj3JS5RAs/RT5+xIzHZ4Ql92CHMA+NT4WpZ4hx5d6KTHczj7i0g2VOkVTC9tom5vM3eLjU2EH88q2tv0+H" ..
	"zANHDCcHV2Z3SRUdwe2V5FadIa92VtZ0lZaiaA6D0LPFUkZg8Ei3mgG5AItdWhpqvA3PtZq3bupkLz+qHesu3K0efqOsJ60anMLJ" ..
	"nGtOA74WDFBPfEUBOwAcXujBg3Z5XGcaWR206mU+wUbfQCtQQPY4/LtnpX+ao5lHwQ69wR+gS/SSY0Bl6Cusys0j3+qhgikaetuU" ..
	"FzfYpfLM+kS0LwgvhN6yObjkxc7gX3Cctf9y+SG5CCh8VeLknevn7/HTBG9eU1jvUp1sau264ycpVTN/GuYyD2GDEGmuxg3NEom0" ..
	"iu01sskjmFs6ucOYUmCF5ZglYroQT/aDcJCI1zI4uRcZI9MLXrAy+FYbIErj+bfTRDGbniORwus9JqCm0Wr3qIp/s/RNMgmqZ9u3" ..
	"sEC/0hTZFJEpke259A6Dm1rApIotN4PYt7WU6FajuwyhIhkbytn2dG+Uu+Pw9mxknfDfmpZMa98Y8w2KPsYQj6+TZ02jM2cer4bZ" ..
	"uZ5oejX1ocrVZeNbMrVEyKd3SkkPeWwefF8om89sw47i+BBnVO7LgfEhRULzoG1KyVQWNHijnoZwwEObRrTsxZ6U7mrfJU33MQEs" ..
	"4xQmepxMvc+vl8+mOQH2iW0RzduK6wTg3UNA37e1w7axkDRo1T2snyPaeJZumQ0qJ41HVvG9JFxgWiihQlnoJ0MEFx2+OU52QqYf" ..
	"Ufn78MkcCwzGDOcZQn6/tq7Kljab2Ygj0eIFY3hXflJ5LpCQw9HK3vaFGqQcWARskEfi7ySRg6ialxPmUuqa+edCFYZgkX+PEJBr" ..
	"WbdW1jeW44Vn5xWAR97wu6MdkwqAf8p6TBTUYK+wNDAPqxSK0yRZTvZv9+cJB3qI2cA2G+UtDHuezdCaTDAbF6ydtG0StBLf9k7M" ..
	"Dj1/L+uH+19ifR9WUBaPANx2lDR/rM1qrgBrwiP6044eGP5lykoB2SSyYp4GkQF5NoaxyFYgf4gfhKhHW3XtiSy/8Xwfy/wZd8M9" ..
	"SPYnF58VrxpCrNblkvILBU1VUWd5EeptAWyrzvfQHJU25R6GPdZS97LPy+8DV4CjkGjkkoUrnUPbDrCZ9ZbPLSSNJjujU7XEjtAu" ..
	"PA4Q8S6I+5Tx/YlyDhqFPWdOe/yDC5Bn+KNrSzZwnpX7lkjcvqZ6dBeKQI4eQj0GGak76FkRZ121yCW3/bwdKStlmD599MNUoIZj" ..
	"4wdc5Z/PEDzZJTeXDiu80Z6FQaSLtxZcQKPNn1SQJMOex78qG6dHouBzI3nAOskaIm7SiIhIS931su99jhI/+4yRqaG4Pm2kVrCy" ..
	"WFc6pjYDsouOXttjT6pUlrqUIYaUvmMHNVBXVm2m5ZZE60oIAB8AJc+3GoDz+gHXcleUlHBALIpD1GHghpcWxW9AD3e8B6V8VpZk" ..
	"kuD6VZP3XSCQzQryadXsm+WIDiuP47bm8TyXfEq2HI2KCduRESNySYo9MqmJ5FCqqP30EzDxLER3ThpaIEhEee8mFOGL0MLWQGSm" ..
	"tkw6H/9THfhPR2yG0U7LK4lNumcvKrjDEkuhzEfZjzfKdEImcOUbhzoNJ7eIcAOVFFHNO3bwGSw3payPkdfjRVQZeqy4NGgNpsjX" ..
	"b57oyVQ3qnJQmRu8ncgNrbj8m8KaJtTXRWgXYBnMbfyEgTIg/fbM22OPSS4sEnSEKbXxXgF/O1cZAeUnhderB1QZxIokMJbaCfuN" ..
	"iG7fbMPhtic4wSahvOX3SpwH5EtKhV+lsEovhMprRQ03lL0aSeImeQxhL0mDsKRZD/uYawMoOvp3DLicNzhosPtL9mXeAj3prh9j" ..
	"CXmf0b20rJAHaSlThmd6ADlCwOLpknv3hVIYPuDlizz21t7hIaoCCdVKod2bV0MCg7oADTmGkQ50pM02qXx/XdCIjPZ2jntHNAtT" ..
	"BMb/wIGyH0bROE3EwN+Z9waUmrzjP+/Nph8yYOCqvlNmdEAlo0beJsGV/T0bpLq5jGhz0pkeWX9sIbqjGdQADB7KJmAjY9Qd7eTq" ..
	"m0kxXLdSFrgbQaxnT8q7vOajrwZx1v3hZuk+gWdvFwBRxPS0JgiAgEJ2RTt2w/SNa+szz1XcBD5bnjmlq9zidDe0OZ8l2qReJq5+" ..
	"57Yhl07aVfpruX1VPBxg9FvqNAqX7Typ7PvYN5+AHKtIl1COQkukBj7n+MSsrKg0Qz46VQv4/e4G7eZKqxQlpEpGSXl2dhV8ZQM6" ..
	"mX5EOqKKjlZl54hwbredySOiGP0eRFqcdorXcws9lJz86/+dH3Ls6v+hjhLe9r9EbyfLv+rEius+3U41astxxB1Yll80W1S5ZCqq" ..
	"Z++gYftK5X9SIfIdXQv/kTiaRN3Jl0ikzTVt4GB9N62AVh3FFIzWxUReh3hiGxHe4477M6k5CrMJk8U63SjRdXJEKthA9lSg6C3Y" ..
	"AJBLWf/ryBydCsbFn3mjpiohn7TnTYO9IjUSZgPpmq91zGnsHv3z5sDy751Sz8asZuAVC0aqdnckrqFqveLnMVv+IW8oiJ9erFTA" ..
	"2eErSuU0bvsRo7iesRLxvViuRGdHib4XTySmGKont+JuWz+hDGBfy/6rX2afZnADZEMDmMEHM4ViaotCxytYBbWjaZGf0artaHgA" ..
	"KlNSFZorak4MgYZDFSNp+pQDd5a+wE2Bw6bMPHyXl4/fhMYRbdfDHvlRmkk6RkYej2bdQjV4zgr9iDca69ozy50c4f28xTuBeMbX" ..
	"UiSPzolSZuM2B0FRC0wn4/odCagS8FVUxFMk1WMXHNJefusBDjfB7T57SGnPsTw4Z0Bjl5dxSuOiOebIFqqgA0B+VGUjdbMTuVFH" ..
	"u5QD/LVPgGNNy9fOblqwckTQcXFHaLhBVUtgB7QSJelm8JHb+G6IWWY+DKwe3BYZxpoKSZULGhD9z8aSg4AQ84keo8a/YusDSzly" ..
	"/srSqfiE0khEUfG0Y6RV/Bf7e1fEKGRVHtKcUPXhVEKoGU+CFcTwbtc0S1fMl6ZD1icH9PeKlCe+tqlN5mR9q36+PztTfNx4CrBI" ..
	"r6AxsdLUre2hEb7cVkCUCk8/Piw4Wpg0GdaQ0zRH1eeSGZYgGD9+nC/nw1iGPyPxkTSE2y2q9niNAsxJMUTsAShC91kLSddFXkDh" ..
	"Gdtik6ptsO7kpFoy0rQMNgeLfFrlxsLqK76iKA5inL27xBJJctiuH25Jj9DvLchmdvB9NVZZm5s6dpBY65D1HijCMC36PQis6qQs" ..
	"cbs01zofLs6ehMJmop45neTAvjqvNSTXyUdzjNabCkLNMgJgBohJV4SGae+c0YdnIAyYHeK+daqrE914tUzxQ+aUOoQ2W7TwXSTV" ..
	"lVs33UBvJw3jHEnQuhKQE+0uNBWRv5ryTmYnXDHpFYLtpFL1CctT+5RijMkpKDf8DfDnSS3Zy7plvMa7vn9nzu+5IxQEdymKWhyD" ..
	"77pl21gl5P8Ldjto+/O8zI+r6U0XBw6NrsQwAV9sqnh4lugi6w8L9UmFEah7EiJ4C3uxvtJ2MbdaIX/jPmm64kjY03YfEbklaa1r" ..
	"RMM+2OobJxcLA3hYC9Ane2qtbpwxCkruoK53Onhaz6cXbIg6Qw2c1uXoiAwtlPn6d73nIv8hruqoLO3Qdo4u69lVOPEuQOphARbY" ..
	"GwnD3rzdt3LnyxS9jg0gPRIo0PDK/ywNUzO6P8kV3+4JWkX5aoSd5Yg52NsXvgEDaO3xiDE9/jWNrJIFi+EajMy9IHSkrMtM3b+h" ..
	"anpieXcLJ7n8t3Nn4y//D91VRq2N4HUtbqLNqW1hR7FMzwgvXQI8UqSX/I5dhVPk6HvWDFfxgmSJUNz2eavWuIRARhCGVr+Hn+e+" ..
	"HH71zpaKcfcAZG+2pRmiXySVg93oFwiA5uc0mgVGYWPXR250z8aFrZpi+P5LwFs3z0wjdGXYh8ALh3mILV+YZtP6W5fN7LOI4cu/" ..
	"JaI3cVQpWym6HWaWTejOmz510ff0ZcG2vCBHgPGghubscSLPHMHmyMRNsNk2dGJAjlwZJ9HCemNYvBDyh7mIwBv0+/2AKLJtpywt" ..
	"kx9hpoIdw42rOuGRblcytPsiLHpRpkXJqNHC5CooRXp43qVwL61U98/BxtAHto+apmOAOF1ObnCZVd4VVfiLdgVJCechp56jA+Dg" ..
	"HmJc5sslM0CSmBAZ8l/Bp1QCj0EOJ9zxEmjuBvXD9HkfvcgLTi1esIxe4UQO8Fm/DL7w3ds39zTA6Vd1JAnkT7JGfa/e8TbeOiWF" ..
	"0r/p60Q168qAT6tNiP+GacocRjAVb/K4yJT6bhuVOu6DgtDNYk4nlLttS44YNyQm7SPx5xeg4uFiDOdK/pErwzyBC5yd4rZBf/LQ" ..
	"mHWdBI39j1UyewoVigM+I6czhYvXBwAOAizgCPhaI0zQBXrVpA8dqjfB2kMQ3xuEnz+7WefQ1fBLvzoGrAMiAG0v4tZWI/2AXIFq" ..
	"/10VtE2LHjPqFuWwVzaoZbKjhpyZ8P0fA1bROqOBEJSRrz81q6HprDMm+rwGWM7yFGLv0ZJ4/bsfRY3aR+MkraQBrn8oc15JSCbq" ..
	"WFoWu1zaiahfV2eWS6FO/Vmd8uTGcVVjEXFNE+cRaotZ7jwMkQyVkAWWs4nZm2mc7m2UD3i5oNQpEK8XYDPQSpkopWKReUphonzz" ..
	"ZiDR3CWXweLSkboFL6SYla5aV5xbhw6W7F1cBtZX058rDxfncP64LFIQtu/HkIzo4JEBbban926Yek4jogFFuCVjeJ7yBGd5RqPq" ..
	"5IEe3YacNPZBmqPUZqPbbZR6zbKQFrz4WtJMyges3xc8By9OChw/TCxure19sTEsNN9AJ2Po4ScsOCK+VYG8cBnRUbdWYHNTXK4F" ..
	""
local PAYLOAD_P2 =
	"Qrmxp805Sqau1vYUq6+9OI/CCzTm/kkuMJ09J1O89EPYLhpCp+0rvMXI0X/lmG/3y3NIoXyEaZAMTCyp9m4Q99Yn5FQ7xMYVaMxK" ..
	"2ePFsBpdelHKcDeI/7YsQ4MMTfnL2lPCltSJ+00Zy8Qbiy86WatPwOSlpQ/1IzUHTnHkXGbLLGStUxeeDB58bOTSB+kaJidHd0Kd" ..
	"kzXqu5MTU1C7/lklv7olc1a3fvNd4NYoI7IrMobZzqKAp2wARL+tmHlALsGoIdjsG5mS1mpNCitDKfttEVbUf5apydkI8yg8zXUj" ..
	"jXHz8gP8eNnH5uyPYFOywVQazK94BqQoqmU5BGReUdNhQKG3kRlY/OdnFGVBJHra0VCgt35xv+MfJ6Kxuz0jlIdKegzOSXtFJGGF" ..
	"ZdNTE+ku61aU8su0NzLHM5gBxNZ5U1bThElGGDTPfR3lhOpVaJfFUkzxu5lXZD31BJIutqnnX3xy6VphDLyiFXA4X31d49gLjyDZ" ..
	"bO8sSCrA+UWVncysHFteCdZg+5F7nlXV5iB7xiiU81/1R2yzRNCpQDS53wt1XTlQdNvF5pz/iPzowODdiZNunn9eU/hHeyjeSS8D" ..
	"txHOHm9d3awtmUa/qASeXmETtj3AzyXMQYr7qWmvkNbPfogGTChlxzaKpj/L/PrCTdIViFdpbTdQar73SILS+xMUpunt5y1N0i9k" ..
	"zgoJ6Ekl/H3uc9r4xIeZQiNR/ysFZfhopU3lEz/SC/4vuEnCpxDEE2mBqVWe/HbN9Kb1RY742UkqumQh7n2+GoYizlPi/HM9APXx" ..
	"ZeEEsrKF00PmTOFvvmUomId43AovokF7s7hriBxcKF86ILxjloLWlyl5Qx6aM/HYt9PwUulZWW73CtQRLytcsXSeJc61qQYkqgiO" ..
	"SvcJ75hNcCF1+Uy0IgjoIlUJGO/plr3CJD+1BSZsZ2DAkFBt+7dusg7j7VN5V59TbMqjx5O5deJh432UfcXoXmCjzguwE4AbYn9d" ..
	"twrNQgeFj55MVPo+YrQZH7SDOhEuZ4Id+0UTSUnHKtEdwzEiVcilPH5ufxjT3gDFcMR1ce3Ulz5+zCgwIpQaTjTZEvhJHgmX6DJi" ..
	"JNR//fhzHwA0oFGk50Fmjd48o2ByM07KPbE3zCa6pXb7sEFPL/T6sVvCx96VdHe/qxf2i985qu0h5rSclY+dkOCrTjdZdQS27/P8" ..
	"wIB2l6oxN/5KKxhMVr8Gd7OOOolM5PppaZXPLRV4rIRPCe93N1irq045oLJdPn/RDMsYmibi8uPlAjHS/0bgIwC6zJg8EUUzi09f" ..
	"q+L0WKL1i8k6JH7K1NwbFCIFCBp+O1Ct7LkCOPdd+6DENMyYhEb0sF6tP+mJ3kYdU2GC7dRaMVgm3BUYMZf1hGsIbrPue2y9Sj+Z" ..
	"BPR6e36iygVFXt4owEXIW1H9oBuAUAkJvbcjXJyRhg60N1mucujRssGda9WitlX0bJyaXUdrFzJ8GEcWW1L54HzBsd4kMMcFQoW3" ..
	"x6u4xUFyJe/ymqGYTo9VNQ1BopEbWun8o+oN5aUy4AoUnGfOc56lytFlRJORoRkCi+HzOYw/LHIedanLN+iBh0O7wLMLFbO047Lx" ..
	"/GtkfshoHEeo1WA+T9FnKflphWR6zB+obpMrw+qsu6oa1BFoO2pbImmHzryNb9AeoW/hpESf3VZBADqa/yza4ILSx77mXMGYCY/V" ..
	"smS1l/gvJgvSsK9jzLVJMe5cnBLwas1TxfS6/ioBN0ndi5wSRVXAvb0eb/pkxqnXCJnZXXtQYhYZ8+nia2zk13YyLgzgFZ6DfOtj" ..
	"MJoISvAf1PwvPQd7lN4gUr8no+bC5tdRfTQ5F6JhTfvMV4GAddYtPHBEY3KM+i49OoR/FmQNUPwBWg8v3IC9c0R6/Ss8KDgOUUym" ..
	"ZMogJI8kv2YGUX0aYMmqdcv2RjyJRQIuxpN+wWs5EwQ49vCudy/hzWYAKZpQM7lzy2BA/YMHJwn+qL9sOa+19OvElc5EeAfMTGRN" ..
	"WAsmHPBBdewoQvvYs5i4y+KlyuE2aC8kAcXG8fTflDHXaBQZo/x+VDxQMhMngFSTMBAdwPC2cTCaWgtaipRdEhZo4v760kjxSg1n" ..
	"7xEyN4FvMtJPIh+bBbZeRNPz3Vk2lm6Xg5TAcVelMTRAqVx3ne6k9euvW4ucKJRMV8/R41XFZXjnPfbZ+5UpHKuoRG/GETYqyAHV" ..
	"gVwaWpz22WTO5goxeA/TGoFXIOK6ECnp09Wdsvxy4CKHSJG5f8VgApi9RXLSQzQV1HyZQzhE76et9oexKzuPAeXv/iafEwKC+m+H" ..
	"CImGwdG09YI8FjPIqo5yhJawc51Ens5gZrXnM2TvyILrq66T/vXT1Dsd8TpsvwIJWdeQW5lscDuvDb8dlExQVvAwKQXQJy9yk9s/" ..
	"YnWPmsjhPiDukBawvPPByp8c749lDZ1W2qg3rfZeOvGjnjw/udf1w3tj2MtNarmomvOvAMDFG7wMcmr6UOxG00xoIo2/klZEute8" ..
	"3phvJZ2RT84RjlvyCVXsW7ugkDc+tc8fO8So6iJ1H5ybxC5OLQpw7uCy1z7alhfr0laFDkVMKbQquawqcD05yVETzh75qb3eK55U" ..
	"iTeU9INVjspfJhdbvq7sJqbfa11uAp0RpDEmTSIDzVwCjTn1eaD7quFyxQiTbcwSY0I6wdJatKnDgWASgjEnrhd/vXx9ID7TSegv" ..
	"bH7hEgNL+iTSDTK+DQ+2OS1p7j5Bm7hQmAe57kAVdYcWr7FCDpubyJAg2P4C2iVp3oSdLWcY59Ouv1KBx8O7odo/zIXIT+F+BZL2" ..
	"IFpvkLV+JsnW34YOAqbkqAPxGsis6ndtVPAZ6rg0zIiqe46bRi7qBD3u+47BbkPt2g58ElsD6Sh+PtriPR0MeU4x63X0C9EI1t+q" ..
	"7jIrevVcxqp+0ASyFqAWkEEk+td1Y7rGQwDOPVl9g/NtiqGE9K16zu4zIiRTi90DrKoxao2gkHBQM3G1fo0lQv1zA3OEsKqAgXeV" ..
	"TSMAIXWfBQTpQzamJ9hP3Iucw7KvovsDX1yvk9gWo62G8b6DfptZXUFtuHWz+kuA2nOLk5/lHieyg9E5ao6PhX82i1OGANYiqS0K" ..
	"WdfNApVvrWVXfpSCCL4igAdW8iBnXYrix4qyD52GRyyeuQVwbgdTfluKoEuP0q22xdQQ2atzfF02ypIx/Gg8LcsbZUUci7S1jHiR" ..
	"ZvkdaVmHkyveGW6pPQq0BdK0Qc3SYKbgvid8TmMyk0jt6xuKAlsnhuiqDNWGggHGkU73b4T50gkRqkdDcymJ2m8oIam/TOMF6Gx+" ..
	"iYMHp+eINkkJcE/OAjdXQ4NpqrhL/Msu5SOHNbGdW08QYsPfNyrtWGeqwwJNWh6MJF16J3uHYyUNBw2Za1nTORfXVcNLXnY0rjis" ..
	"s1KCZZ2Q8IE/dhOe0qIAq1YUNCDmuiV3Xw+uY/KHpzKRXyf21H1b8+iPg5ZgXLmA+zoUZMMC12qi/Hs0ATHoNfMJ0cTqPXjbLAjN" ..
	"uFBb0IyhJ6cRLPm41q9ihPU6R1eij9UpJcl7fdLvL4IXxI7fDLjMuSfKNyiTcsV0bK+29A2ZY4vpaxoU26a9f7OqyGilqPUM7u/P" ..
	"j78SkmTX2McsBNenYSBPDIYHJS9YixLXKLc/JTC+3IKnkXDKRQ8AQYq9eGhJfgNBbVD59QCPuKCqy1Rnedi8ZZar58fiuQkT1xXY" ..
	"UHxTfZV4J+PEgAyeMWc6M08fB//z9NvaVrg4CoJkpGMKy7GUCgwNsoIvAKngFGe1eJDrw9aPgR3CQ+DF0ln0ikszQj7rfY7lQv5P" ..
	"4NRL6up5s2eun6+ca5+ZCk+sUs7CDEcVnXrB63PRlWizcpXR7TfZOG1sW6frQBfkEQT7t3feH+iEDMTtM/hnJw1ilTqAUaDHc56j" ..
	"ojF256MWCI3C0uL0DgTgd2bYlKPwz+h72gugz4KT7vn+3LOiH4/xNpyIEqu2ag+oAstNyFoKLufaFYgKYsJPKq23UFvTtHhObXOO" ..
	"MC4FeVb0kT10U6Oulal9pdKoULAGflNWKT+lnPFn7XhzYgKr8K6YB2QpkKYtj9ukATWEnNBQRcEQt4vbNZ6+RWVfmad2lIqwk9MS" ..
	"QVtJPWSmXgtm12BLyIchuBANoLZ2+z2Hl/znlbnolDohxsVE/peGZiLtzj3891VU7vzDI/MbJuZYgtvDOu6O0mmp9yrUtwlmfV5K" ..
	"UqOXnI0TJIYaGFuxYS+xVq/Wru1ZueuTlfTcMY4mHWXWzU758NH/Ra2qE+8VivrrDGyWZ0W43FtXK3MBuXt5RwWzxd0mOY6pN5Ng" ..
	"pB9LTY4NWSTjGJx7XMN2WXirkg2eyfQdILZOnJsLl4CpqofR1olpDl0csSc3yvjgT3xRXyulSAX19p7lJVMi7Cuyzi9BW1enq47l" ..
	"eQHCjsbyQStDv6Jz8D86KOq3vCcC1oNHb0Gq2yFSdJUm7/6++IM+n1oL8BZuzknlCcj8srp4oQayZFFgVBw34keox2CSOhs6UXjA" ..
	"DsqXig8B/s+v54e4u7I5gEmisF3NGvriaNSq0GWaqC2Wpsx5NRs+ngjG+uvX+VTYJLP7MLcyW5bR7tRulkjLw7A7tNUNY3TCkfwW" ..
	"SQCW9obkUXIgx8TFp8Z3z2h8AfyhA6b1q5y0aPln2kYvPVwRwbTCvnCRF6oKXoQvmrD1ijZ9brYHGicEbDK1PW9toVU0vRFa7gbl" ..
	"tBi75GwLRmckpIoAlhUJKrMJFVu98+gZqA37ML9xEYAt97uNDS6FWcYM2SWwhTWnTY5nw1iD/it2GQunaPrI6etxSMzIF+oK6H4B" ..
	"z8moUPXrH81fRbOJSNzerhFBa92qld20U8fDt6l66oREDOVoJ/r7R/19wpHwVHwtQi/Kpw1L35iP6mvyiSRqs74gY8Ob5XuZXbbX" ..
	"8tAIwHpPJzMgWUjIwja6TD+VJNzbl/agit0izB3jcvU41NJ9cT2LjMtOH1Yxb9D11YjQylOHf1w7GJbMkfpZ7L3kF/jqxJA+0zRH" ..
	"Bh0J89sXSQC8TV+zzzacYedC752Z5js77KQpkIPVzVWk7jt5fGIbLBshRapkQSJSTOnrbBeOOO07fnoqzgmeAHefRkmIDB4P+CJg" ..
	"Czb1qGO5pIJf/xXFGdu2gYDtKG+QQb7JwSs/62FMkEIttvD2NYlZdIRYci+CaFBv8v3eOKZe11ovl5VKS6HTcejOeUvJnS8adR58" ..
	"yfxfV7fpre8kaFluxB7l7py3i6EqUhIoEW6tfK+3bS33ZLeKl1FqY6atWPCJby5CWj5allg2/kauScynvEetZ7ZS0LOuWpuE8e0Q" ..
	"l+muMi1HqXNVN5AVZsuv6fZbZyMmYBDYjO6FCj0U8KzO1wAQaNxNyYU5ZYklQvMNeHvrf7/KceB2+CH5nZRnKf/ZSEEhDm3evKqe" ..
	"1yXrrbNYJQX5EygN0X0i9pUSlNyzmTrtrWW09QrxZgpCiRWdKaIl9dE0pofPRlzQCq027sfj2iztat3nlWMrqF8SljI3zSa5b/Eh" ..
	"VVy0s7O9CdEuRi0mQLg88Rp/kelh52wWsSE+hOC2iALQviUW8eoDLFTDg1tPBK5MP14QGrCfiakhtuFe9Y0RojZd4Pwztb3Hvp8n" ..
	"vzadea7l8vj84f0haVJCAMeQMD/MRS8sf9deeyLA/anG5i/B0+3spjjgZev2IWQHfZHCCtNSeZKHuYcvxZ0GpH9TemOKtrbfMNjw" ..
	"H8YYkYh2kWVtnZPDtmMAmRkgOYaRqTOokbIG7T/e8sowWvPnr1STdiH+DVsdrE45MiLJ/FvO3iD+F/YwXBHhc41mDmT+fA3aRPOc" ..
	"2s2bl47e8diUlEo4lDsSBWKYxzqleZ4lFjaIF3znLGlA3KvFtDh51LMlow7znJCwiYm9nuqc/kLiusxN9GH0V4FEBT+Ohtzm6HLE" ..
	"uDIxR11VSKksbohEeyjPODhAixeAQg/+S5qKk9KgXH8oMyGJWsiH9KEIjaNzIcPFGIwhdk6nk14oywRe/4D6HxuQrZDzDhzaazpq" ..
	""
local PAYLOAD_P3 =
	"3oAAWuDP4jrnHM0dlC8NUn+8wcCAVV7VptugZtAJHmTJgSVaiIK0IiX2MbPxDWFLJRHQInuDBD8mYEardviEeorRmz4g8f6h/3Dm" ..
	"e28IuoVmKYV7IfwkLtmSfOqz4CpjJkPcz+ZeX0AsUivpIKzN0h+n4EzSBuscq5i19diPl/qvSoJcIf9GqTlhrmGRT9B7BXcL9gwC" ..
	"HZ+BgikorqM0H7OKgfaaS11T+n8SF02lMeqA48P1P72mVJBXvNZpeIV5SeT3JrJqqL/CQcKfOdYNmH217ICJEyJ3RDj9InfBTWBz" ..
	"0By98Dk9olEKvvlsuj+s3WuQL+Rhac/xNtFTjgJdOI2qYdFnntowgyArjS1GMLBEesq8R6cAcRcADwkah/U6FbYk8PLmlsxAFLqK" ..
	"rovV270DpD+Z5ccVMA12EOr1V14RzZRHfauoV05jbjiJuTj26+cdvuQr43Vg9/eP+CcNAvgfIwgaTL2QYleiEzlS8ECVNmXSPzom" ..
	"t+Fj+Ep09fGhDXe6EnDxWXtw57hCSXPtB6TVKLGV0AbBU3K+YkU5UeYapJa4Y399kmvVOUt3Ye4T1VibTFUp4GvAb1Jjn3C0Qs+7" ..
	"1KnkhZTyuIZHiCkCCpgxPsF47uNCQJh8NEjegpRo1VbiLxZw8j/y7gVp6j/k3jqBTgIYuoIyxyZ7NIRgaejxnNoq9ozAXpB7jWKp" ..
	"XyPXSJJm/VWenSHggCSgBxShpGc0VeS15s63hGqMBfuiXxW1POvBv6aKtcfJaSdGg3143lrRGhqFg+XDNUJTt4P6/L2qYpaKXTnj" ..
	"gN4l9fPs8tVSWe+yhnz9Gnvsao71kQnvTL6dg2BSGi9KyDxogWWFNnJIYgkjyauXL0eDD8VNvBTakPmQPi4yRMvoImELVddntsGk" ..
	"a7CDPybMq1l//9s0PdSmWNBQd2nyAKG1bYzahAgLylVO5Moe4Yh+eUDQ0F9tAaNaCuks1s+c/mMvOuYr2y4J2FI3e4/JfOtm3uEN" ..
	"+c4S9OEJJYryUjCz9SLhA9VfyqGlDDjsYEd/Men6/i7pQRn7GfbarYWY+YZLk+oaC1iMfheCKBPjNSJkfYpREjiZxPCvGPJSSmkO" ..
	"0ootSz4SuTcfHZq3dQ6/MOLB8EWMq3W2KQ12muprw5WxBlOFx+nJrr5BJQ7+3xc9ZNM5oBKC+tmdyukmE0A5k9wmHe0v4eHccZla" ..
	"25n+ehqBOjLqKZsJmsIQgG1o2Iv65UTYZtk6GiTHTUMLp3qU6phr9VJfY+f9iclzrksFU+5ldajreKcokQuAu3kwdINBpOV0cvPg" ..
	"eRR+XL+GNX3NGdbb68ZkeWTpSgEa2VqrEg6yltTtpZcQBNN6kzn6sbUzEv2bZpnqdrQKSV+3QF+Ah2v2TrN+PO6YoCIuIM++ZXlB" ..
	"5Wxf7fGPDjvbX3wrWpG/CrOAIyHnhuli3sLHznF9R//9PEwYSOVBfIKv93yn40qviPh8sPLicg2aFOTMB3wIOeoYalSC8ZkhAeiX" ..
	"QtArO+mBI2ch6FZ+IpVEjL0QFlegpwwWV9MTtGApvMpq/86QZ5n97HxG2WvnUKwkM+9GLRDMJBRJhKbx6sBhAzowoTesVHxjozbO" ..
	"5MD/HSSPBQLaIbuqzBbj3w4/DKZ0Hb47Q1Jdqj/qvcBo9JYGlvaRGbkZIGRp5LIhybfXtoTYrgFyvpN4ZBj4aYWgE8zO9Ik/Lv9h" ..
	"YiYn3h5g1tE+UlBLakVHu06IvzATRSzIZACyQ2aNvX9kk15GXX0KGQMUfyDGdOtVPL5qxhmYb6byOPP3cD9WmwTsXMpBr35CnHA/" ..
	"+zh7pg5nZ5NjMB0MOa50vb2hKsT6Imlp7XfR/TySRL+8znVH8k6PdmaQEwZ2ScpRAUMPaJRo3g1gI2Kql4S+7OqEWbFbhcmSg+2g" ..
	"SGGyS9k8r48mbQQFpPqcUlxta3VsUOTeTiMR2Hpq8IBnW8SvKZF3RmmE0GMQUea2J/CzKiCPmnSwXXbDPN9RyhW/RNnDCyB6gX79" ..
	"nmkvua7KES/ail8obAj03aClajAzNwOqGQUelasKcSz1FVVeI4r29h6EmbIf4FlxIvria13DQeguLw1MJXFWZk5mAPSK2s2hH/P5" ..
	"VBrZOoWhMhkz7M/R8+rYGF/1X5Aa7Ij1hy19i2oMFSy/O/alK+yTse0CBOZ5YbSoGoKFVAxM1AcR+1vEc4gilnVf43Pk4WJ7oxcr" ..
	"zWwuGHNmlG+OXLYOf8LIfAFUh86zmRQlgqDqw7Al0GuQglwxpRb0+2d1uhXJruBQTiEr3B+DUWJ7J7+3IqkaqeOIIw6igrGLIq6q" ..
	"Zk19qP9wdaIBVfoWEP8s+5VxqWApzgjOAfJiVuwDh2P7Uvkeg2EhHMTtpE1KhEIcnWzl0Lc1tPVMthDixwIRFqsEy+Fg+Q0eMbZH" ..
	"ep2EOc19wZCE3/Fek99jet0Gg3oFH9I77kGiomJ90ieRdhL0M4z4zh96rvcF/2IC9+pSlb0moaDCQJV+WtkjPpV6v0wZTIobtz3m" ..
	"csr/njGKTaAoUbXtmMINdcPnTz2q7sx+QuQFJKJihTqJk+EDv/V9hEgWp7Xyt9wHPpPVx0Wer7fsRfQObP9GMjaczrT1f+0jTsUw" ..
	"czL2BNjqqlbPUODME/Vw+RXmIwpWO2MzamQZ7LQv+xG6ASmmwPFxFToTM+1ODSGR6CyjVqQThsUxGHEPX+sTz53XMBaxyOHhMGep" ..
	"UKhMbT05gkigNjcLX2GTUGjiRFbuMNjMOjvKQF7sS++Za9zi0OTk2lUHu9dyLkm1XyBjkg+bwbRa8/+h7dpPra4VIhi9+bq+8zib" ..
	"x38ckZaKhQ04Ftxa3bnqd38U04V1RB8knomzJa8XnrP8uxu8WO9aPQbNtc8ZdX2fb+MmsRVfZf8qXFRyF0I+cZpWEnqRbBR3AMFY" ..
	"nKp4Oo7QKzpPxmPg0LstweLKfU8cYVCdRTc14Gvq/CR+pltyp4lU81YZSSK2Q4+elireTNQXkSQlkYaqB03Z9DzuxnVXOgYUvJiK" ..
	"x+lsxQXTlaBfpMtvyBgAMIhobtSIDSpKl1IWyOvrrqGcfZnmwD/i+vRdtVU94OuGBBfp38gQfqlSq1UaWxf78f0q+hKm9ub2GTew" ..
	"jE5YPLhs7RbU8K9VdeVR6/IhSEHj32oVYqBIr6igKbNM7kXdl1FsEIHGy+SnoEsuUKIL0sCV9iU+0EGa5OjtM7FZ9MjmuqJm7rH8" ..
	"fD9XHbj6z2VtKMOVmk5AuHeLPqVUKLzZSKdZ1OZnT1VUPtBuEDR1OwtO/kg3nLBHvdv0St4ixkguwnD+5xQhVyCTolvXIYAgEsCa" ..
	"Zppp++YrKeQbFf+LOdmcaD3K2WdqKVi4bNZbZZmWIYD1U4J3RwU6PllBm6hwmK/e661w4RTXJdCQkcdIPPmxMSjzukLTsq8nxrAY" ..
	"U7nTq/3BmnuGB5fGBaFAm8RNSB28pF/gNQIEq7I/z/MWA8lS3ko5kjnBTrt9N8GHhFeDTChbHKZDjm4dRswXAyAgEPZMO4rFDP3J" ..
	"1TtEEJfHiAiz3/YoZc5cPRCNtppdweQEXHdVy/aCPOmA5JrboqOHvnOsAJWP/Kqbqkr8G8GDW5XcjRXUbaiASJ4VHkihlpDZ7WXb" ..
	"cQHJZd3S1AvTH10aYZ8A/Zck3TveGiNvKJAe0hLM28kfYVUOfb3nMVuZYt6vJYu2yKM38uxhPU6pwIkTbggs65IMvcu+IZohMGfg" ..
	"sDBODzcXNbSV9Ex5OS+gEBG9TNxejHkW5N8B51gg3ucqjgNEbipsjfwoUDHis7R6akYUlnXMlDsAt0S7NRyIwuLYYaHHNAZ70iaK" ..
	"D8Fh4Q3NG96gBY7Zd1UKjq73mxV3zIHz1y1nYV6ZqxtxFNDKOpNL8chQnlIGiFTjZvL8RTUSj7P6hnTtcOrmXJr1/pUwW443g4f0" ..
	"7k+7D6aJYnbVgklfl9hWsXg8mqTN9oLJyPHzT0l5ADLkeZ8M83JQe+Yi/QaytBscGadPhUNuHtR8E/wnJULfBaJ089aF3tUBVpnE" ..
	"GFXGAeTY3LizSFUWcYKOCBu2NiEpmbgVzvNWCpmK+SJqsJ8ZX4VpyM4jkftDZaMmKqZwoJ+O27BBwtah6lI+KqWW39RJzTrDkHfz" ..
	"rKjPL6Iw5B1TwwuY91UscRwV9Oy5C0vzXTHCPPnmFmQ2SK+pUfnGXmwU18BSymiHrgdc7JirIAYeMLU2Q3gPwLwyZKhJz91q03cO" ..
	"9WZ6BXllVX48XCQOrETy+jlw/CDKfwKEEX3tZU6Lkf+X2E9RLCLflyEaiklnMoWouY7L0KkpydqceCLCie7Bzg+wRHktL3AVyXSz" ..
	"Omj3iKLhwDBXpmGDPMT0UrTinpTSOwqXYaaf+YhWRvf2P54vIS0WN8Y7GGTwvP05V0aP4kUypVtuqmFOCrkaFFS2RLGJNQGK9nzK" ..
	"P1QMSGb+G6gTaN+4xalgSEp8Y3KPPOmUW+fdp8yFwCbWMWho/s9R78gBX0FeNr4DkOGiYgCCU/cOTHIOlek7N85d0mc221E/UhKd" ..
	"E3PzJEyDhbHh0CPA0mrrCYLzTszOqlrR1r1bI1MOwjvVovD9wjetgMQ6/ETRnfJC7p37ci8GAXxgHzidFf5YR+myLDdFgJwcjolR" ..
	"4yMEd6OlSEBM71832FYjpM0y/BVC+hrUqtL/RPW7FNOcB6kPDufIUvQzRmupaSRc26njbnfQadTn62NOwj9ICLLOV0OtIVK2ig0Y" ..
	"e7+9KqV/DSQ2fCh8I9yH+oa8F/BJHOWgPy2URKG1S7MeqCa/4LuRuNXu7dkEAJb/u04iOjP8Cmt6ZKe2qPRW5M8UQYbWbcldVi0l" ..
	"e0NVDwtwLeu+F72Bq+avjizWDPPnzitTCm4eNn2NU3FRQXocYy4Grioiz0fFGICZAKPzH9PNROnGN79bATOVFlthEN+mxrNGTSXI" ..
	"Mp+5YgI8yx6Lyizs+CqENhsUcBrvDzHhdMlUp/ookSlhMP3p7Wsxij0Sh7flDXrgC7yvhfRDyNz3Mxk+ctJgKANzLcDkAVa1j83x" ..
	"Qz9pF74YLPUvEJVd49xX0tqUymRoN1BipmGtOWxYkJqcsW403jU/pgzyx6aCkscnzcVs3eCoJZCozo0dYNskjLnz5JECBtSgW9L5" ..
	"S5Qb7NMoOXp3NlwZ4tzoqypbHokZzVkOkRSd3SJkUgIXAmZr8TtXsNYCvdBxuINqomlPaIRyl+yJBPpwzLMdo0jqNHEI2V3MgJQr" ..
	"RG6G5srta3GytoawtcCVI01sHJVMW3HmdIFsfqH6zsLxBdkjGn+mxnLUlvb+7Jx5GPjjZfCtZG1i8mr765E7TzPx9Fqhfk4dV5vp" ..
	"FUbLBfYHvQf4c85641NH95UW8euw2rCiTl7K42OEv1ZtS10ex7xxgkjmQTeWPfvR4xfyeA8ch/JBiuzTcSbeJyiq4pnNA2cmV5Aa" ..
	"gE+g22Qhl/EARKN1/cSHRz6qqp1f5pGe8/3kQ991ot7xBA0wq7SpT5czrLil45W+T0sm5A8gTgv/B2UP4OVsZI7wizjvxjjWZUGp" ..
	"Ly8eJvg5cHyEaOPxJ1OlfV/uBBkfG8whbWdz8eK+KkoiVWAL+e2c0PmpDXlG79EeggS0SUBUjOhwZ25wuaX5NDQxX1+LXSera1VU" ..
	"u4lYCtB5OpGeBrK8OwvwucuRpvM7HXtKGjDBa4pT/l8x25NNDFANWeny2PYIn3BmcKBGwVdWpmw5mpI8ZXVnZNtiQ7zRlQMum32L" ..
	"4RwvTO73HFziVnc06hFyIn+sdgoMpnKAFHNFRl+E/lXnkxBXhjGuvXLgIUJIiV88u+uVflkM0IBEcuWY7NmfIdTWeImFyF2yw1zy" ..
	"Vqm4e2fK40kQH7+uxlr8fvgh1/Xwx1sSHowdgLm8FLcOlm1mrTNJ58ZvbGaA30hh7wjBuEeR4ItIDLID2BSMZsP4KuvRN3S39N06" ..
	"FJqv4DVsmWBsqfZfqBT6OVIgcH6md1HhzM4k5BjWJAYcov2G+W2c8cL2zLgi4FcoBD0QqTNKaVFS4GSL69TKVddmUZZLA4j+jaed" ..
	""
local PAYLOAD_P4 =
	"GgRbCiacqPN2ESacOK4KfV4hc/sG4etRXCcfYhHqTGf3QHYvDB0gPTjiSej5dHz/75C3qh94yO7BW6lbVZlGHkWEWv3gY61Mr+s2" ..
	"YNf9JzKNGG3/H6hbawyeUzYOgv0QAgoTLqtwNle4sNjoL62UISnOgimtEJTCnACDhofqnXjrBz7nnpyoFOCdFBBBapMoxzdbwzHS" ..
	"FKAfCgL9MfhZhgaHoy8/ST7WsluRV/WBTi85rLvzRJ5WmMaKyZAsfnsqAyppBzC5l45Yv++w7aK4YDeEC8O+fN3eSY9neliF9UI1" ..
	"mnt0X1L9FiEDoS0w4YT0Go4SSZWBFFuPQ96r8cYqYhb08WhWfKgweUTl1tSoTUghagch4FSsv5KWKo7iHjs7KxeGlVxKyrd46b5B" ..
	"NvlvKsVRAKn+7WVOBVnD8i9669kysru4Di4RDD8t5X9ukCcYsin8rAfiZ7MnGuH6CJr6oPwBomyuBLSvJh+J8VrXtj07AvZnwKNm" ..
	"m1CTR04SZIMnfFNxr7TG0Or85IgVq6Vzoa6P6LooRT2WKTxs1BeCL3MHNlWJTAvfc615DzY/HaIUr6HM49Imltltl5bbu8hUv1eW" ..
	"wDqKukcBBSvDqy/aFVAOxcG0reKE+y5DppnAPJjagOR3VHWy70FOfC0MFvkjfuK9P8cmfwMVcQqXJPS2ikUig5CTR/QMUT959a0E" ..
	"QbyMWKKc0oeFYBYZYa4WFvSIZt6HOYhCXVt5fsEinO8dd43VOEJavkVctvVkh/XEfSNEHBNcIgHy5pZtkjFQrii0P25P8RhNXC2W" ..
	"veocdPdWi9ZOSevzYoW7GwxNp2ALWChLKB+pm1QGa3wfYuuOHtXXSIvtYDHN5swxnJjaNsPfy/RQ9pAwDOunErPxItkuqPo6Kgoj" ..
	"xw6kowPbyHU4aCXFcvMFPBcx4D2hEIkpZ5+aehZIfRBk/14IaihdS8NX2E2dwyHekfICzaYnutwa45cr0iZmBQ+gitdKdAkAw3SA" ..
	"nIIwFhEl6Hp13Ym7lhQI/f7Kb0Wz3uI+wE6IDu3OYkqcoR77eruUIr8m5pBtIlb4zz4irqnQBPijmzJgBCfwsUfnkfl/zZlQ6Uvw" ..
	"szvmS8kgWYnxR0DTFs6u2AEhrvgnZg+jB8C4rK72KwCnQ55KGkegH1GwzF3nVV1QbNplw5Q32OMNazUvLXDd+A0FJ1FSDibH1vhz" ..
	"GP8wwYKjvYuMKGOBDHr74NZBeXbBSiiD3yLDoRS/lMc6u4Na3/aX81PmbTN8nu3ckv3AY3xt5c+y/bQNxZ4n6XcEkVLM6RdiXj5N" ..
	"Om/YaPHfx3WlfMWjnHlzKsR6CnIqFdCdIwFZ25GAWtX5IKlFa9qGaWE1ggICXMtMwHgpt0EjEFjEmYKPnZhx9KaYbzBjUtVsvaht" ..
	"sKC4RcMqdzJQI0wtG+EvyWEk0tW6KC0XNlri8AJfTXwLyivkZfkLKb2yVXcWbie731lvC0O4IEaEIRS7PbjtuvRgeoG4kSsFFuRz" ..
	"rs5aeA/WnFkAtbN9cbjq/pwxHNHN7p7p8lYizDESzmYvEEVql6biWlAqdg3zx7OUizXLFO+7ojK49gbE+3XAamgaCgn2YHoy5h0s" ..
	"eKux+qT7s39TTq44BQOWhu4Q5oe7U48itzP+WH/U5SxSZNrVYKiXfFM4Oy1IFogDLJu5YtChFsqOLbSeIlGV8i6uhdl9M9V2kRp1" ..
	"38ns1SvSqgpANC/0pIf82Eo1p/U58tok893NBBWBWc+tHPq6AQ+G1xQsCEiYQDDOyQWVOeKaVyC8wlKBZNnurrWs1MCErB4IQrfb" ..
	"YJrFlqY+AYdySlPcvq8kOQwECBKjAsZ63BZZg1WygAZAJJX8pcEMLmHeJgqakG/vTU+NHkHo9L837bpvVvgfZxsNZJ6F0aredqrh" ..
	"ENUjoEaSZGRZCa/K8Rd6XEUcHxlWHw0ziuqAPqfUfpO+iXpCicaICdTemO08OcxzMLDTNXTVJpPdj7atyPMt/LbINf/o6L2gVHqm" ..
	"4KibZy8Q5gD1W3IcuQCc1oBs33uPQZJoyYFbSHhhcIA9Kp79QpsfNgCs9mszDcUKYhqlSRal8MKAFQcVGUzms/Jwzun3oiJG5lYO" ..
	"PE7+l6fzmkHd0hNzNX9y4/TqxhoQ3+5lF0YMLTKzQmUAPxA+8cFQsHSx9bR/mT3CuCVQm06zyuomuP4AVn5Fc3WrCykb/K/SFX9X" ..
	"g5wmY7a1CRNsPNY44ogQMWlAiz0Ay75HXcBtZBkqOt+IryNPzt3RLVGSgsta8dwQEO03o9Sq4QcWEtpOFwZGwV8CLMhJghB0N0Xm" ..
	"9OBeEn5q6go/JsPaV+EIM67i5AO2Qw7hO2BvQxaX6LyEHpxt9S0Go7y0rzXv91NOYXSwQ0Pa0d63/AbByMacv3Tsgqi55H11Qj7o" ..
	"+WDQGapmFo6haDMLx//+7Jh3kbEKgyeFQf5VXeBxJgT4youV57SqWDt6Q4D7Ip3F1CNITTCpAgWyU+pwlxzSdFrkDHI5pFsn+l/Q" ..
	"Es+gTAeOOGJRb+6F51ueMjB9gnqBSmYx+kZMRaeUWqD2FbNzr763AYdIhxDkLaeHUUVUdhstN54AYp6MW4zMWjlL2zWjZW4lPRV/" ..
	"1LvPaOjxe3YgjMBjTn8HylDYqj/KxSni+KGJwb24STWNEa3BgS0TFofLc80bHZhdIqV+suJ470akt9pY4srRmA7c4nDNLBjSTAj7" ..
	"x+Dh4TrYgiza8wW6DVb9yvwhelDaf6P/c3q6ysVgK3Z11YbaOY1v0agflGjFy556SqrZG4LyMKnL4QQ4296A/4QbHByoWGdX1QKE" ..
	"VvDD2zB9iQEZuOaNBv36sfmBT80GuTKLH58r/QILw2TVULrhC/FZ3pmCAs10fu9tSFy4ElTwi0gAaWSKAU3Sf+hyivOKaGMyamo7" ..
	"6/7/Twu1Kc0PLPfCujgD8dcd+h3J/kNJS1Nxxlb/rir8HahTtpriYSqqj7iodG+fsNMCfBi313Bsaeevurla9X3IVco2bycWcVZL" ..
	"H+iujdWAQqda6fqiEdYlQM+Fkag3r6AgitBIf8FLeBee1Ung1yXkdI2QxH2XtN1646K05ostcorbubPLeJdRASGj/gXGBf3DqojT" ..
	"qCSVzUvwavmRQtpymt0IKSX9VsqgHfRHmMDp8tPWhMiij27xaTqDysul2pIgwtpwIXeD30QHXILVD2Nv9ivGMTmjSKNs/75nd1+6" ..
	"zNbgrnFGC1PstQk7DGDN3bpD7jebbzyWkguHOgnowQpD6MY36IX7hLZKDB35hTXUeC+DkUXqHTPO/qi3cLIF8cE5MUnU6lKKiUAS" ..
	"tlzdu1c0q/hMwqJn+VKEUnzx0upPfCkDhXRpHsO2kzulIstiYeHw9SwHdeC1lZCLi8oaUYXaWgPfECDU3HXdKIi4Vbr64O7DT/XR" ..
	"SlsRS0tWQpAAQodhuLhEz5WO7Gwrz8oQGjJwR0OVf8t1rEmMyteripm2QdF0YShP6Q3YFaLGOCGBf1hd4DxeItNslSAIEgrzGA6+" ..
	"M9TYKjZ6AESZ+KaB/JTyhO5Vz1GHO2UXNxGrEhY1zY+XTM0L9jsvu6rkZElku4PH0btWG1j/8tZFUMcbaR3SEGfd+/WDQCQNOLob" ..
	"4SilqOqmTKLUE8E3+Ypp8b48D6aIIB8dCZNUYnNjFEQ8L56r+0oGJVj+Xl6Y5P4DqpNxaWHpO2Wu36l9m/6fLhUxMHOCPvnKYjRV" ..
	"ALrXt/o3HBP3T8umygnxhrsRy8zy/YBwDeciXejbf1wAs2xCyWqv7hFXCsroOfH7oQCx2jkylz29uGEPpgr6SoyYDDdUsgmVCPoj" ..
	"0ZpvoSmjMoPFFrGAKTykplC+ifyArgwr+9pPqhNnjlBBdYJJQqLmiHKc8rJaAk+i7nEbjQjUr9vQFB6qYnth99hvldFwYrjQuoAb" ..
	"UnyNT58yiUr+SrDwjzcqzyFjGuen+LPDKK8K9Lqf/eaMSzHIjHNW2boPOH/EpMOPIZypAraGJp0I9pIQzY8nqfKht6wOoLUNF3lO" ..
	"UFd9BP5/nWQTqo6KumCaCS6z0FgyQNIPDRatAChoXI2LsKm7QC3NV0G2V84YnBVdwbnOjKXSUC37dxYz+xeahpfEztj2ZirjN4BP" ..
	"XG5RlDI1qK/yp+AJnSLfC1cnfTldshpaw+VuEfCjPTnBJb4QnSiJhvR5PxR3Ro0cT33eedVPVhxM7IydkPsOlphWg4EU1Lrcwp9m" ..
	"NhmLgzi4BMFqa2WtQkbyr09PSKA91n1IwIUQlBduIrj/fAIR591Rq+3WWhXVK8g9V1u/RYnYMReP22Xg6E9G1wQw3gckEtEy6H6p" ..
	"rvGbjX80H8LRexTpo+FBns6BuJ3pKAfJO6GaArucUGBF23Sk6/QMFx2ZI0o2IKYqEaYaR6SXYWk1OVG7DM+l50rAxPIYsdLxzqMc" ..
	"hzK7wmlWRFFv+FA7PZjNeZLem8RlMfI/cLo4s1gfbxgqZ5C4/H80pMbhF1E+rd6mPmunUoBgzzXxdz9LLkaZntP9YX+wY9sO1MHL" ..
	"Rog62UTNSkFcKzliItvP1IyqAkx4Pts/8gwkYTAZhmqsILNJsm4RMaCLq6Jm2/wm0HrGhYf/X5xXMyMZWTBEmOQTROaW2aPPwpZK" ..
	"SFcFMBmk2ZV5mJROeP7AGajR5b6X/sGzxsNgJq97oVQSJ8QtjCQvRVddo+e8R6iyXz6StUppqEeueR+qA88qlxXREUdNki/KapMQ" ..
	"kW2DfzdOUGBrSedLA3VB1lypWlHYSaxxcEygYKEFatDTfWCiR8mg6TA1yJASMngYNZMGVmCYCExQ6BsPGkvzNKwp4s08aVkSvDX+" ..
	"248nfHZ4azii5thyaRFsojye5OfARbYVFuk441dgukPDlYWdX6ij9ScWO2Ek40siDJzwnQE4nlNcaDMDIL6JCQu1rLMP7sw0Lzzh" ..
	"7YP0LRx0Lj+zkcrNtx8w4hcP1BEdzxkXeTSVX/bWx0YEE5KmNTX62XvKDlrYBT5yKPDaYdKre1HPzyDQrPfiTM2bayk+tssFRAdL" ..
	"xxP4o3R7CO3MZBbx53pAUTrnr3DisRwQxuQwLIbIWVvpHWCjGgmtlbkUF9/dOevjHQccoG3jXwPRUunWEo9I3BdRf0SArJO3rZuk" ..
	"Wzi64Jb76lwmg3fLXW9fLivfCxodbwL2A04Bnt7/sIeCJmIrIKbmdc8J1PXEnIzPhqD84DSyQ/8ug5WVPfTfI4Znt6LKQXt+0TFY" ..
	"V+aRG1ZpdRM000MtmZz4TQko72+xBIBCq9ArsItl+21YObYm1YLpRNUUjPG2/XgKUG9bioXx8oMQIsH8sH11RZmodYj/UnooTgyi" ..
	"9gab3Dg8J9b9MbL/Yfk8bSMBoa90rXtI02bkfne2ALoutuoqSC7B3sgh/0Me6C2wq0WaQybKD0VqY2y10szx0Qb4UE9vRVsPIE6w" ..
	"NrBhOdVE1Y0Lw0WuxFPFSrAjnfocLQNvOZF1AccDX4/CnYuaQwqmNPD3iaT9G7hNe5u/9rfZS/VKXqz7WbkLjqRHHGrlUpSRr2zw" ..
	"xHcMO3NMgB/OWoQd4ziUAdnIGnFlmntfyHFC6+oa2/T6t1cXqkehitlDmOGeaNYi9pXEcacR1i4ugcG/ELLSgFypEYKiAhdvcsCx" ..
	"HXD6Es1Iha+8sB7C3ZV4i94NrdNaB47sLnM9PMx6iC/kLLj9URRNumhlKzYtDTzbsYagol8MvjjRSJhMg+7qYLN2yYiCFW/0ryaQ" ..
	"bFipuJLmnXXoOy48JH4M0jEkALrmbmczLw9YjZyWRG3ScfLbk/gzOCBk8a5ttQpOGYHhuMccnqTCTWoIys78aKeHjJMg36svywp7" ..
	"uaNFa+N4gJne43WCNzBfdoVZdmQ2/ETffPbvjTQkkVcANa7ECiN5WJHTFy1qmfoX93V1sO4IMKSBm2zjJolrFEKMdo+2Qda/VsJc" ..
	"oN4KKZXTBp4nTAs0Gd9jqY+uGxgQAf8jiYmLFiaaoSTZjsKbi6ATm6ed+U/jDIq3+Z6qxjO3pu+LvWtnkzPs60GVLsWE6hXG8uB2" ..
	""
local PAYLOAD_P5 =
	"l1s2GMTQdoCcRiqhzwKa59jRAcz8sww4IqxnTgF3Bvau8zykdzoIoFtHMs6QH42fNGIFWoJ3kmYGLu9DhDWgTII7SbsyTVASFq4u" ..
	"0MHBFMqd/fndAybgFXe6oB8TQTs6y6uYsCPC5Ug/iNNUwf4h4eILirPYu3nKcTV9hdbeDvQo5mhtKwxSHP4ViorMqbV6pUevgdGB" ..
	"zwDAR9I5CcFT7JFnxxwKfYRDwt8omNGXTFlDj0CbozvcugdAf2Q77nJeOJJMUUO1LXyf6E4utTspPt3zWVmJbUJvq3j6QaUVjM/M" ..
	"oCOGohMMPCCs1f0x3ldoKkr/7QCpCgOhQgPQUuzSD57G1ujYvJgXcV0hdeOQi+w/e8oMxQ5BkwVeb/+Ajz6KYWvhjAUNZ72ZZiEa" ..
	"5rcoJrN7BhZwEFNnjyh8Gnw9OXZ5adLRYf8qQ9OobVbsJFH3U7q83vyS1SuV1/2KOe6qB5JXquUfijwp/lcc/D9Yul0UFjepipYS" ..
	"p5aEQQwFChuh1sui/ZAXgttfZWqdTvQomS7594Dh/x05FR6BdckTmT5PvGfk7BD+ubzjuGKWhg46ertngYrfc7hc+G48WkKb13Re" ..
	"bJXxPyRxc/LDkBILHinFoDXg9GHWZ1hp/kIFfJmXGdEAwlrcVpKkmqBfCLEIxrj0LuDIQ8ETQsoPG7eTHQ7RdQbrxMHTIZKFmw3y" ..
	"WBkGgGaSic+SLN44mzvujQ+GjQZXDsheNFBjO0+jyFvONHDpfvMbNH1Mb3uuwlKrviKqzOQQjqlusIG+FKifzstseoOkNSPE41w4" ..
	"xH+iAkqxJZZklRYo6209ATeC9nBzp1+uISTLGjJxGqvp7RQNprA1pMZk0V2X5Dd1H+BA3R+iS1D/Hcq2XD1ITRiNVwVJe6J0AOwS" ..
	"MIRd75LhxE7FwTf/lbc+tP8xbL6npRwQ2UmdWPcJkR4gBSRcjWuaS+gcwLl0UluxpqudtUxmLLRQ/CIVQl2O97TE0eKmvV9XJGaO" ..
	"ME6KNx0F8b8tnRJGs0J3iHj7lNWWLuuvy7H1TXYsv/XBsDJ97pZ62xYY1EOHbkyhramGpjJddVdjWaHwWLqKjafckwaidBsf2Cde" ..
	"RuTQ3d1hscvK3USWhxwE36/ojIIoRXND8XB5TcIJ43AL+lJe9Vck2AzfGW77CAQ5I6lDtMAmKyb3v9vLPWiOWPky5sxZ4uoOp5X2" ..
	"Lb3Ud579ymRzB+cirqtrOZ/bThq0Awlo14uZw1mbQgyZXyFg8bqAc7h0KRKWpck8Q2ZlvkVBx2RFhWCm9G8jlhZpv3myoGaQODyn" ..
	"fRitHGxrwuyLrVPm9Ddmlozh6wCVPHV84M9JqehWD7MK0ouuZsA8nW2BDHyA5QMxlUg5DPElaHNLMKUFeWyy9RXhjDfWNBKzltLZ" ..
	"dKzMJDhWZ9z5M0ZbKqP+6i3xGJiaic7ZO6R1Tx4vQ9UInCyGDiCQq047jzTa51lxlq5170q7DUcuNJHHOY4LnDBwD1wjce0GUoVq" ..
	"Lw9EFChNCDoMHTBjqGKqJxRrShDOQQbUfhBE1fwhUi5Nqn+G0YM2ezC1PzjmkWXxEUy3qrX8NmxqyE4JKwWc+ePAdxO1DDW2ATTW" ..
	"Tg5hpbIGdVDvQfIUCRUNXh2iIN7Urk4cuVYgR+NK77kPeeC1spiItr/dCbyc0fYHY89tMhAOJToLF7akVsv9JFKISGt9cVOgLSN3" ..
	"SFgi0e/3TYzNbU59HntN1JhXO64objVok0zknQTQ6FK4gnnnMcNloX0sLvwHb2QKSpIWGnEoolI741gtma837/JBHReAgqUbk0Z7" ..
	"pu0EYZGRb1QqKQ0Gf7/Z8jfleHNnFFkx1HncVZ0c+iZFvDCyb7MVenmYSYsPZU/fTkli8UX8Ss/gppbOA+fjOhZTJf/Cu4DXzXhu" ..
	"sZ+gjdv+a7eK3gzbpNeqGoUq85sbT8fQtCrSJ4qF7NzMIaCXtEZviskxhpv5MzihhZxbLyRIPMkl8d3C68uMffsNBytjXh9WVs3b" ..
	"bGhDLCWbGTdEqg3blrtOPpQvETx8xloOm1mGHMlhrhZxUerdwgi83IAj0efU2QzMfgv9aEVFW216cglLGV/+tD4UuV2BVk2XXM+c" ..
	"uba11mdS/KC81o5cMNFGyD4f0zCCqhNr5eIr0edn36rE4UV6HI3ZuHys+HLb3Yck+UtfNpbXICiNstocUAffdXpa3r3PPITA2kHE" ..
	"QF+iGHwmtaZvsXgvg2csZZcXYnGOBnuai/FuB7sBufLDhWibyTkCmv/yC1yskPc0jqIrFNxrGJuh4MWB9PLc8Y4f4uXIeJQBomMY" ..
	"p8qWgtiLzVxFuUin9Bxvo6B305H7WABQREgZp71ddt2ucKCZ9D79nx+auO+aA1mtpWGRajb5hyIASSXNVdM2w0/biDWfUrHbjZbp" ..
	"08/TpaKsE2I5xsIf01Kldyp6LVuT0nIC1WucG4FyLct0JNJjRi9h4ZNrWlYXnV0YhB4JjXGWa1lJZjK6UCHyYtjGaMQA+gw1yILr" ..
	"y3Zk0uEAIT4AfZa8M5wd11GLfiCz7IEA2TIXZOnDilW139owUC4wwxix9frn7lRpI6JQKKPbFEiQbenkSguw0L/H9jtNO30c1+fR" ..
	"kTfFki0H/iOwgheM3NjXslwNtCySHtdQfr736sR1hGTufrJ3FDPNYbatWoRwtodpNXs2tiHUgLngJIhH7ISMiIUS19jDC84O8fzF" ..
	"Vy1spJhhIoqOCa+Dvb6n8O3VvyN0bX1CY/SnBHYA/agzhgc0cmr8GG6jZq2dz/EDuqByz+vRYUqqgJqTe+pb2v9PUWlLlKIV1M9o" ..
	"nnnQrW770wdzvL0Rmczqc0ROPQ0rdUa4qmF4BMC4B1NS+KUMZ3G68pBK10FHGNgXXFg1UH0NC1lOJ8dJ63VAp9bvg4hHm6MvtZXN" ..
	"ZS7RDW674KYxoDS8FFwv0D5Q02Js0PT2fn1hkhDlYKL76unGQyHmUEEL5EH4euu/3lwup1TI928Pou/yjM9dbVnH10GI/qbQ37OZ" ..
	"CWV44xiCy3A+R2VEcoMjd7S+lmHpBHsWtteHl4QRycgOxYSDVKMAg+1TyOl67x71Jzng65Z2+nLDGQ3Ep19s1WBTVtg5dncbLYIt" ..
	"S6wyTMnoEX0AzNxMOPVwEerZH63ELCuWdXcSac5FcVcO8LnHB844gbKlH/fl2NTTEFXR/do+eP0nm++NAe3zXUM7WZcM4eCptXnS" ..
	"CSVJtxZwhzMWW+QaKkCvSecmqL1oQL/j8LLyEyx+zZ4R23aY5dODzqOch0CPlLbYxtMQDbJbKLDcFkHAgrU7U2JXzpWzlugw3aQH" ..
	"B+saxhzq3hFxRwapqjs1glRVpUKCRy8vdKfQUJHoBf5cUkZ6T7gSuTrwTey2AVRRy7TScBgabZgBhHKl8S3a7N7yFceRTHOdyjQk" ..
	"7JV5W8+dLusl2gAtp4FVWXNrF5KqYT3Hcl8T/fdN+ERZLZdCZB1bYZmobve4DmUqMViwN1oIer5jHlbqguD0Yj7YSA9TauRK64NT" ..
	"BTE8IJ8WEEFBEbbGxTLGhVQCulijeSobQktdd2Atl/gjeAGU0fumNZPs8As/WW0RwN3gJBXQWtcW7IZtW7rAZZRTlBdWXOx2KEK5" ..
	"HlveA/0JfbycM1HsjngrdIJPK5L44rVQpwS8YOTzydmudiy3wAOGgoyM1EHqYAWpCHZSYVu+Be3Yyub2jZuXM9V8wXZLV/HBs7r3" ..
	"JJeg9u6ZrcFyqTqnWT99UTYjOVe8Xa4gRXrND2lLgoCkbkhFUo2RrU3EWxZxfeB2cPsBtBVWuhh3lBA1w+RDkRrn6aWYjEI3AbKl" ..
	"zZtamcMjF23u9QAsQvDKaNDzC22Vj9o1lvqgJDRu/5QAmHHsQ0nV5kxzsFXJromUwvjCB5wvI8gyviCaHU033DnkZhyyFNAAD+GU" ..
	"eCTcFsza2m+z1RKd+anDHmCAP1iwjtpTjXjZkeM6DmIYU1tGAJ1FjsleglBz79WrFGSJnr2o+w2F0fm+hHVVPB84cOjbkWwD5dba" ..
	"lo/8PAFNYsRXxxjytmj9TdPl8I+nMBs/5pgTqrvZQiu25pLSBLDwUl3lJqAXP/qY7FFxqtUIvGuqzA7Art39q/OYDqbXgksnBP9u" ..
	"qjUwLzgB1PES5k8e/jxJA10slugukuqyxqrSs5tihSQp7IhxwT2P7msroSKrGUZI5lLhUIQ0CEQeKGomYb4epLVMpj8vVB1VlJna" ..
	"TKmw1F2euzbTCOUGfThchguKfYJHdbGq9YWM9XImR5YpBbTz4LtjnR9E7D6pEyhbcYd6+OJzFsp/4tAmqnAN6m/574bCz0PJRZ5a" ..
	"B9cVGhcwwEzWhv2N6TkJVSFOvC7Lyqt2+NiHVJ1tsJn6G6DdLlmJApgVHzOqVg45FnrGxxf5IAkxz8H/XiwhcoysQnsNixxeI833" ..
	"4vxwH9+ri9Avyh1pA8hmT9RAQbfYZmt4R9E+o5IbA1X6/dBHJ1VrX7zW2WGE3bHXY2T1MDBVBrL1kLcQIHdIEeVY8rR08Xdn2XXV" ..
	"4hKQquYzAsdus75fKFeLW1z0iOkPN7zuRJW5GzTL0+1ZrLMEnifFHY9uN0wUJBTGrvRN97x8CRDVf7EUKYFLAcbFIZOdc6eLImIq" ..
	"iX/gsvhWLMSdAQatX2wlrI1n9XcPJy6U+Lb1VOqjk6jEQv9pton8GUpdiw1S8i7z6yMwAp0P0U/J7BOTyXDiz3Gpb6VB1W+XX4Zp" ..
	"iDOE6u0T+CrE98CIuNoWMXHApQn04LGgUC9uiX5Meb7G+zuziQl7KoF12IyUB2CCgAtDz/dzSHRHtD/YOUUygA0syo4HZpOnTZuT" ..
	"0OrAuhzvsxeuG4g2s/+P+ut0kZj29xcAM//1m4HigyVgV2V/yXzdd94lheJOUtUGgF6N0qaKBh7K8LplNTQ1UaXq6FggmlXBGHuv" ..
	"e9U3oyDZ1jiNlVkbvocMzZtS8gnKkAss0hirJMtLqNF4TTvoHibKSZy4mOUvKAnmXBghmxnmA7Z2DCu4UjaH+bse/nx775p686m6" ..
	"KKUmKONWGBiu1rCQLdf80+JtvyL+5mFycA3AxDBePJMM/bgL5BeriwPqfEUcwOSHjNJ0zExCUEiw170DK9TYH2mIP8CGrfNt4EYM" ..
	"rkk9VPq4OWjeXoJig+TDpnofBb0YAJ8uDzXC+cVR2JoZPrBGheBDr1P6a2jwI2s5V8A00nvL6acsVY4xIS+gLBhVe94NzYJhcRz/" ..
	"8N22vla07axflY8ciUB+Z562Q7ssCX2VZ6feOvmaymiy60uySkmjtqYcm6zc/zzXIOHSJLjY61fWAttrYWbYsuQJBImoXvQKUel1" ..
	"0v2qTu217ldWiAHQnY0rWlaIjLr9UUktTsDsOeOJvCrFbLv7ogaSe9cSg8RhAwgMgLO+4fZ+p1BQ97XtV+UzH0geN/pBW9XeomcO" ..
	"Yhyh0GlRUObeo/zogPn12ccesDd/D2AMt3ghI05SP9oj+y3GKrSCEUsQI1pClBRkiGxN+v0mbhsQK1v77YuTdsc3tDBCmqE+3zhn" ..
	"yj691B0pcHwHfH0SCUL5h5JPPGgzmiqlWRKAMh+NDOmaQAmIY9Ig/wabs/Nerpf+aiRE77IKt4+GhN+w60UDnrWs3BsWejjs9y4+" ..
	"00rQo3OuIDaxa4ZSeJKW4nBOQqr0lGDecqf+eBBCLVcqbubBzW2UBnhoiumI1yR68EqSO799QZw/zLH54yT5XyhNUhT8q5dhsItb" ..
	"a2LtGjn7oo/Wgwtxo894DJhVjl7TKLYg4csVksShqNdk1ptrUgehQ32McVl3V761qRcP2Sf+yk8gzdIr9IMab42hwOqWU8XVGdnx" ..
	"Px5SeeuiYSR9TTMopNFUzrZ33iDP5zdVJQSTUgbWgA1P/tolr9hsv7EEUnNeqIuiLc/2foQdLUf0d7hiW3pQTWL+51u8DbNU4Ygl" ..
	"fVfdZe2l6uuUZQrp6s+CjX7xmopxPFjHC0FrY5Nq6YUVez9O+r970b/RetMfwRa+IPRqaUT6GuPrv9hoIJM7jUGprJNUUjY9Ky0S" ..
	""
local PAYLOAD_P6 =
	"MehhMpf7UcWIMGKjlPNsUB2+bqFv6V6OLck/GECEXa2bH2UHLIo1caZoVSS7cQui9fpITNJtoUHwBzeXc8BJJTQmk94jI5l0sl8g" ..
	"iM25X6RHYBv2Y0vz1dTgNCxJSzupq44zmkQqWURJ+mZsNUWg3qMNS9lDB7/11JWKvehq3TLk4U6awMA9/MRa3tje0lKkST9nCe+X" ..
	"YbksxRT4RDgBNlVu0ORZwfj/V4nLq5LfH21w7u6F8Pu68JX6l9pXOUt3m+slD7TfqmBKBp85wGlmksPZKlkl9Qdx2rop4K3otMuq" ..
	"wa8NlNTTd5NetMMFjlauFaW8EPzai4mzscgtUQdtz8zfYeeaFDwHfbN/ggO9da0YrnHHUGiDDOpXrsQcQrI4vXxSr//cefZLf0zn" ..
	"a3YsZItduxJBN0EXCFXTKOYcgZmwoujX53frVkrMi5SwPsDFI8Sm6RDVVSiOIM0k9xm37Uo7Enni5ikcfi89NJPA6/RFHV6g8ebE" ..
	"slmw7DkgEd9jbGG3+oj8Mdx8lODU6vsev2Q2MDuCvoAQM5L3dWyOf/zegb+AzGqgIxXN1U3p/wgvU5dqUb6YbVSM+Jntur/U8PPL" ..
	"onLlRYuoSGzIMQQfXGYx2dJ6UeBKornFZjNYK7jD2chz48H6l1ujUanYXEWbtMY/KgR19Vz6EzwjPjJXNv31r+iPaXM/TMhz8cxK" ..
	"c6sf35nL/eE2bI6WU8J9T3hGPyRqDxjSoQCMoDsaOlMZPt7zzYzf0pActv9dbS/kMc2Sdx2zb+oiOzTd0jjMeTB+otzE0acKqXtm" ..
	"Zk1yCU/v7Xgq8eJsMTZCSIu/ZnyWSe8ePmB5JlNmKjU+Tj8sIrd0TUWaLixLpptKq2jAv6+1q0ENUvIic4hc1n5NyLecep2YaCdO" ..
	"Uan5ZcllVuqFsw==" ..
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
