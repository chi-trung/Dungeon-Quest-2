--[[ DQFarm Loader ]]
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

getgenv().DQ_LOADER = true

local MASKED_SEED = 2759207989

-- ===== base64 decode (thuan toan so hoc, khong can bit32) =====
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

-- ===== giai ma payload bang xorshift32 (khop voi generator JS) =====
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
	"pc8pcpUWTzuAf82evVY5/llJ774NJRjbwEv6Dp9kuVuiFTppEZp4xmVxDWdshWE0Amkv2kJ83p49EoDJ1HZM3B/piF8v0P88rCUL" ..
	"u3JQ0GryKVKvt6EU7/esB3FdGFSikYwIZtNMEUFLSPX8bCBa+OYYB7RZQUszHTDWlkzCiOQpYmINstebB9rfQzEP/tGkiOYoctHC" ..
	"96ACciGaD4fHMIJzOvMIUiz4BH+rBzhVc1cTHSTFSspVnX2aTr6zyfE1TVh6kEMx7+g2VmUa+Kd6kZ/2MDY464nKLH7g7oEmOmak" ..
	"w5fQDlU2ilS/v43L5W187RRpfHwTEsGayH6RDjJDroz+tV9CpPH6x6BDh0vlXCH+L+ynqqD2H93eN2aaks6QsZROys+rxsgTO1AB" ..
	"nizqS7sYY5uJ3aoTOz2VCBeFkL3HEbbmA8z6jBUKXSm+ZCWlALna14Arjf5QKci2r1boja3esi4JD0T8XBTt9kBdff7CkLZkWaB5" ..
	"L5mnCuov0kTcsT9T0H+Ac7oNSH/oWpKZlIU0sU66QAfW1ykOUsz72usZ299OgYk41NukCp6v/+pHp7I5ary/+Bk+fuZl3dAEIdUp" ..
	"SC3rAGOaa2ObeC7TAynbdsmrXX6Tl+TEswEn4wo34WYodvwuPL/+2DUyLXLSLgxm2MPDOP/Bsie6ndOxG+R4pZMjC4nGKEA7GeJO" ..
	"8UF9vWh9by5wut+hA9MpXFAGVrCGmaF6Cw/AURuRrKyKxflgbgQxLB6vMrLYTeGaXYQTcU0crfet83/31JtlvLnw+mclJ1Tu05if" ..
	"tWdQ9wBZQa+FRU4pvUxlyGeLqLiSGvJvgzKPIV9NEZ8aGiM6LqVA/uycu+eJ1TFi2fgP25T3Syul+N9pbXIXC9oVkhc8iBLKS8SX" ..
	"BGQ2jDcblTaScW8oU03hSf7PEI8d5LS5GbgMUFmgbV+cUOfF9p1jFZk1HX/VTARE658HGu4lfTTzE2DAbrRF4MMQrMBa3UPbZde+" ..
	"8fgmIcWGShaeypZmxC8PLmE4ddmCfuj+YmzDotnbQoki58rG60eKFeBIILB55yuSSduotb2lHNoBmnPIJZZ/koUDUSrEgYMOe76F" ..
	"snCY06x6pEXFm0NrKoNyDoOwebn9a2pPVfkQlEAva6ZV8WpRIM8maFwBwSTaqMSuwoDeWWs4xq49Ii82z2YDiSNaCIDDKt5r1lBF" ..
	"ibRZktyYYmsvvjoAsOT1Ro3HtnTxMfWiqQAoLIHQHOdv7s3vYwFgs29Oz4KdJsqDRIeJL6nyR71vspHxkj7BmF+NCtKMBUcpiu5L" ..
	"CAWC2xFNBIrQ577r43aXTj603drWTz9B80JZZ6i1ZRIH0H/wGKy5l+KO6K82oxdY3iPd3yYS6t1ujo6mIhbjWXnfZMWOztWAYmJe" ..
	"a99a6AcpbCu38X0NH4sVf69jdPVlUTlNTqzl7P4q8DJYw6oX/sTRLv3cXX1gp6dn+eHO02Vm8gHXxuKX9+fPSg+Te5Tzp/8voFVH" ..
	"XWahrz8wHTEgYz3BP4J5gdxyX4UZWCt88GKnDbeZEJRd4R5LxFaGztSObI4zrS6FcXuA2luworCyrh6BW7oKn0rhAXCQPIDxLLl2" ..
	"JxVrGl27LdQ6HXv9JpCewMyjJi67sKFlNusyjy+hcDnQH2pYc2/qxwvhN1QUW29E/7luva7K0R+aVVjwDnEufb5BbSIpGMR0/NUa" ..
	"m8Y9SrtUrHm0drMvYrO/SwWYrwHNwdGZnzxpbBOQz07VfR7HPdy7DUCXRfe6bWsgcBZ4JCHCagEiM8BNfNkP2xLYX1PBmWUJSLJH" ..
	"Ig907T1QVNnPZaoJrFN10RZ73Nfsj02WbYGizmUBRH2Jw4AFM8FhkcvHQFvBo962Aa9b4/WEDnn1+VC8HylWjndlXj7uR6sg4m6F" ..
	"UHho2HSUJECwwF4OiubqW4vxnPpNHw6zmgBaJuz+eM3hsIbn3eHcAUlfVMcdw4SHpNVGr8P+9Xrt8hBIxQgEXyv4MmaCGCGZkcTt" ..
	"2iPOVvbudw78GnREUf8yu9sMxV1kmk5wEdF2X3Q3YTY/VjoY3nvWbEI0FN1Ak1yHyCHY1bDUESHmzLlTS+1rzSFmpVapeP0Q0Is5" ..
	"frARMjOR6gYovKFRkHmxdQKdjQKXybSWfUmIDAoOMbWCHrtayH543fgMZcIMGzF5BNJFDJ1cNlEByBeTnGa6OY4avhwV/cgPrppS" ..
	"7puSCrdI2FAgHfDRsmR8xoXxl9MiCdntUgO0zXNrcB0i4/aEZ6ohW5fCKZf86VZdJQ38pUldrW6i54ygcHwR1uoM1RQ1z8ATmbmO" ..
	"9TO+wNf1S2RESvLf6khTYcIVqJFFAJ2WbcWHtc4CC8vp6B2BvdHEIAn0nVW9vhh9Hh4tx/R+s6Fruk+dJZ8ypZvVaB6cWAI8tWdM" ..
	"xC/IKQXKWTyl8bGDz6GHMob91VkndQsjvBiNAGuDj431sMu2RpeaHJk2U9gvXpvhgRH/mucwUzXH2+AWeGahM+h1TBYvEE84R7f4" ..
	"FEfz92uwDaFkpYVh1OsP8r8c+D+iPLYFNQ6xdE2uvGx09Q9bITdw2eNRbwNkWJhoQYib+q+d+xfGjf1+GzvlGQCWS3s4+oUwZ1M4" ..
	"+co/xDzSfunrX8iOLzJFPAZoLcXb3xq8UR3SlqgXDRVpORsCOUv3rPRVQlWb3Pb0A+D1qojlzhJg4HPo60fCiwzlSiNa2/3tr7hc" ..
	"R9sFnBQ0KCsqZ6norw1uFPmVttgTKztw06kgw6DQIV6UnlKh/W1zqfyvPQxNibxlg0Jj9bQCsHep5C3nDWePe8txk9guLH6M4jB6" ..
	"H6LTzZAJkKGgxfGHhv+U0srNIVDvUNAEojd53oe4pxh2p7ClgtVY2OG/qg2+s5BSfYPb42p3EE8ArHdr0U13y/bMG6k1J1Qapaan" ..
	"8swYEPdCDF7i/B1DPaVwovlTOLgThtBhuPrZE7nXGMWpFt8Yiru9IQVPkG7y0+25m7TY2pxFVV/DhyL/ty4U+SE8zvaOBKpJvdcx" ..
	"30ZbdIcySB+ke2MHW1P6hSlObPupZGF9MOxlfRyHQWvy+pCsghnF+StQ7FfpSLSYv6Bflgrio+S4L9T1TCeOHLExo7y3HHHJbUJp" ..
	"DRZGsHcA0lo4WF+aCOOcUO+loxgFl2OKNDYm6WiBaf21md3FD48RZoY/ePWaCWJ/eqgGAOA+QZeCmKu1fbpI8M10eTqTSEirs+eE" ..
	"Fy3UtGoLPQjLxCIxCIsUVGg08+zjer+ao7i0xGqSFgV9IE/vgNIDTZWhmjxSYnAd2/4ahZAKcEnB4V70VkhFFiYnhPbUjzVvcKcV" ..
	"j7Wk0lNyhcqx1CgeP99oeitOH0GLFuP4u75p2CkJx7EBeN8X+OBSJbqqkTjAFhdfueY1yrFYkCv3Ppg/su4Qp0K1nw3HDFSAVvXh" ..
	"QvRFAq586R51VnaEDSSca32eNf1g/J/dYyBivAhDKgPTFhoCpcd38tR+L9OoR8T7jqO8vPHtVgv4i38RNpxYH0qrsz4rpyTopxbL" ..
	"ve606Em+q7y0GR7aVO6ormIImqQAL+HM2pN1MKrQtcllIiSVimmlXMbS5zkBFnAcY7r3XMjX1UjGQuicp4UU9jHH1i9II2Mhpsoh" ..
	"Mf50W6dVbFg/HEC3WllIjIaax1RRaNDU8a8FHFxbJoS5m5+CfqJ2XwFjSKoZ5DIKYss0SLLpcD873xZ79tlvzmCj9hDFDroqJA9q" ..
	"6xS9GLvW/N1IL/An/giyoonz5gD2/ad7XxNCt+LcyiJFR1pZlgoyAxZYNdgPEzq7XDz2AUxbF2YV3xKbmzFG+kpk+sixTrHW33s3" ..
	"UdcBDXL611XTi2a6yvl//3Qw3itdQZgf6cEjSoZeCxV0OIugzILyhmCp68URAK+9MIDz2y8nTZMJR+DzWN4Nht/9qsXZVqScNbWM" ..
	"NLljROLs4FsmyfjExyWKCGC61DpLmVjrexALpk4et+RqNl1jvS39emXiQWob0NGxzqoMUGA6mdVSqmnG7NQf2JTneRSRGO4QTzZr" ..
	"ZqaJsfIZVYHaOLIzzEyUvJBGGzW2o8OjX53PaYbF4hpQXLMcFz7ZtTEZa2jYEjLDtxdHhyo9gC0DTem4a+hmKKvbXnV30YzEFmMp" ..
	"+RCc1XMVSE6uk8EngbAYgyYeEN2WIcanJ8oaX8PhcXG72FsuTNa0HC+kyqdfT2MXZ35LVdulGXK3wf7EfYdhV5J+6zYBSNOPPJq+" ..
	"L4GZWqwjKbwi4lype7R/CgNhmbalCX23NoPx/z8WC9Ar7bgfFTWcwTjOIo7PJMYOaq+EEnYSQ6AT0fbhZWsCJ/XET6rE8mRALeYZ" ..
	"3lWNlkrkosc0a0RE1Sx6mIAlRsx0iaR5wBPKgwjSUMeGI+r+Nb2MszmKRkGdWMvYJt24kksg+jCLi8Xh1wUwclTZF6OT/pHc/pi9" ..
	"D9eBHfcLbJzb+DFGEXgjgB++4LxqDJmMv5BEjm8Vws7pVTZlnNfV2hbzP728Xt/qRpp1aBVYtPzPcR4YoVlcXzb0AhdRU5VU9aEv" ..
	"uCORVfgY9ttdvontvgeUplug83D/lCGivwIBrEZ851f1Gg5JBO1jKiy2QaYQjmWBX1H2qtJIr7+SSvg3b6/BvUS3i2A/S9FkTE/Y" ..
	"SDOrFiGRnHNY7+HdXQtLLXfCUCSxe3xqcyUWi9jNp1pfJAXihIiOcE378VGplUERA/vga0fujzc841UOxHglYKUV6qz3ngbEWdyx" ..
	"KgaDDYAqfg4DqTupMnf/kogwF03OKJDVJOzXzGUHU3xoa1RhQLNQ6iLMwHsLZ9SjctKn2bUA8HXKLj7Y5C6LN4HOcS+hQ1LksuBm" ..
	"h6iKyQUOhqpTY0Hejn4Eg83svcaxvjmMYpzwES/kU70jJhfQvy0rjLWc8YEhY+mn/z4r/Ju20CF8oodc6H+PNj58i/g+14m2UKNz" ..
	"PM6m7r//rkrqJjHAYRkdmiVwmwwDcaPg17OZVrSUVtDBbP6HevZVtt31mpvH4ppmVuwJTBLLoufCUdaMBE4oQ5kPuXdxjQmg/Kiy" ..
	"ZaaxaA2MNuEIZwJX7lUtbxT5sOnX3gx3Okc3Bx8uNHPzEpXy0pCqFqznmvAw9yTUSqgqeJ72ZOCph9mtnKtW/6IuxbLo5uOHGASO" ..
	"ni0WE3sJGHyXXJ67wrZaFdjGKPeOMtYBn4RptWhEsJB8zLelFwONNqeIdW/bGI23A9u4LjMdRQ9FK3MOTNP0sVPdtNPy7b0FNfex" ..
	"Am8WZMiasE+3Bn3Gwbe+uzt+dDjj9GFXN5ThYMSGiTPzqCiBc0LFySu5X3Hy6pnGFhyRj61T3srh8BYIIIjk3TjNTiaqyOjH/ak+" ..
	"kHQRSTqRt+140mJ29qf0wThmIjPcvLkRRZ+je7bS91q3tpKbcnXywg4mZrCugnwwPPTRbrGUSuavb3Pd+5ULXB+CczSBbY8GoUYP" ..
	"yi0RgNxZOQesXYtDlnrpUa4Sk8L+s2KobPydZ+lWnj5uWicC/D8jrzf+Or6J5E3JM/al0SP9xjQk7Gb29rD+UjgCsA6MSJOHT8Eh" ..
	"cyPpri32CpeQxoTjgf+H6VSUiKsBk9P0up8J+bOXBf7MnUW7i23Zdp9lNu1qcjVCTZllyVwYUCYbOTKouLjKY3cqWl0uZRxkzV6p" ..
	"gbtdE2v88pD2RxFi8iZggjOMFkvctXNRC1pftaTZZ5lOnTBY6FYUQO16eZ41Iba4+fOyAc5CgNUbaAFyNp6m/6AivORbjJ8nN55G" ..
	"usbmR3LtbPLD53y4YSbafxbFr2uXargDBKRyNOxiUnZY+gnHvD8KUxXKUc09/ayvueNaQ6m/hANLM13xj33+qRMIUSN6Mzxc2ue0" ..
	"NgRhLcZiApJq/l1n4ZGbrXf0LZtXDXjm3IuMRxTDQPWPqqflL2EH/x4CmDNyZSeu443G5p/z+31MiFgS7z9nV6E/gE4TGy5KftqQ" ..
	"hIjhal45yUBg4YfbndkTuhFvq5OOrSCiIHI2Lrf6ad4160lwSn9lxZES+qk8kRtNNjzN1FlPJM6wE8j+MJA6jjWyQvQwsUOdzH1I" ..
	"CC+5ymNE2/3GezVcJwvc1i1ugbQ7WCOwvwr4IHM5EQbAdSBHPuGFpjSPEH6oFY6mwZYWbcOmuAL982//20TV33lk3MReAS1ZeCGJ" ..
	"EcJaPRDsYZWbl8VyCDSbQ21CTeiwFRXM3YPiZ+vXZUlu+zc96nH3ysY8VqCcgChqpmWyKV1l9me3BKWlZHEhRDLnFQDpNsLNVS+a" ..
	"bNx92aM3s7s0sJV5vkRwA+l+HQU81dTS0geHhIYlNz7eHu+Y554ORstp7gnr3QSK6DSmRupyJfLVUreT948rEgHzh2RspsINQDwQ" ..
	"KSSwQMZEmC+sB2BhEGgawXYIQzUQNI+ikQTtpldGeuU0byOZFw1gV76hoHbI8a2FlW+2nWOUlMPRSko04gdmkEWmFC8fg4BDlB4g" ..
	"QakF2E27TOlir6Owti4p/yQQoZm41U9vXS4TJjdwnFAgUxMcAUwEZjYqoutfGILezB+04t2EFE+lkod1s+TtuzX5tQJ41HMx8+uN" ..
	"T44FnYumKi6sjcxHTgfeVL2Pp7fgTNc4cxCwELRmDaQegywj83MONBUT3/N01Z87gA2dMxMGJUsr1kwiACxvkjQJF+7kjr2yB6le" ..
	"mGpv/Hho/Qr4qNxvGg+0FuNh3Hl90EyoyXAuvg26nh0+SGVXgbuEEt+CBBWNTLCDNBg4BaGcBYyXt6tT2a04MB+MXimJ0+fgnI48" ..
	"+sshSUA/rl0KbRPjavH211oTjSaHxbsdh39K8bc0BmH9PiTG+/0nORO9hEQ59fwbI3qDlSBGbjBWvL8Cz6lmgaT7jIAk+B5igsxN" ..
	"GnvHfYZuBL7awaSX6LzllGWvCnjTwYz/dEs595If0aA3bRD8a+ReCbI1x1K7fWx9o8mN7TdtGq22SOoo4OJXtOIJ/nLEkgYwNA28" ..
	"Y2ihcMrcKP66egO+k7x5c7beBGhtIw+7Bm/QKnhyMCrXYUiSrjbQJBpssmP2VeSY2fd2G+1US6KI4HoP4fb5Ci1tFHqHt90cRXXY" ..
	"MeUYjueuyBGqWnEBBO5F7ED55uLAnDaL/TzQh1+sYEHeQCrc0jJVyULKG7NKF82gSHjemz04E91mj7yLm1TwhD5z72vKZvn4URVH" ..
	"VJIzkjWCbP7UDpUg5SYIsOkZjcvh3pDGHNF5KIPOAkHDHqeP+QNOFVXEeIySl9L7CtZivtAl5XtMGENWxOpo8517Qhd1u7ibsREU" ..
	"1E03LIGIy1ZtN4SCDfMXFVtoJT3c6LNgJu9PMP6SDJdTEH2ISs15lltb4FKZZK7S+prJatAwVRy1GVfewg9HtbUnoDP5W9yKYsAC" ..
	"iZDNde4DR5WRuJMinv1jXEzK472nLgcSj4qKsbjQJx4jBPUvvM0nocjU7xP4phUDUvJWZUAE+nkwwLZmCOelbk3kMji9ZJamL1gg" ..
	"spgeDC2/MGayWSBQUDw20CA6oFZYKDyIylSq/8t0cLLo5hfmrBOjMIq5HU5bnxc/O8IG1LM1y9vq+z3Kg4VhbBElDsqgBG04MxRF" ..
	"1hnd0lJfMQZArP8fp5lQOQEfFW6Uqxd7mI6COMtiUQ5T1q52x3F4A+0LYB9pMC+LTLbQajO7mIdz65T1GPEo+hXkSLoxTAe4PxQ5" ..
	"qNUM3pL6i7+yFzMXNCF+Vh3nurp9vCpvIjrRLKgF1LkJ1QxlIrLcTmUTU4xL6NnwVIVEw7uKU4zRRNhUvaLPkoHUNO7zIO6iHItq" ..
	"wI6AwZfuCMh0zZAd/4QUlQkeuXBVUZCpfyQeNXNwgYoUcYM2Cru27VK4rDE6nMreiK1zDoylQLkFYRdHN60NwMArRtd0e/56GBg6" ..
	"2zDLmvrLBqOJAKZ0oNldPB6+SrBFg5vJyWSRlKf1J+gdrYPqCkYVMHNqzcr0bb0HjE8ITUo2kMiYNtdqTDYK8Mpmm71uHXJudPtW" ..
	"dx0+EB/Ba6W7F3vJkjVLA301rs1AWxbikwG1/1+YxgEa8jZ7aAv7RMT85mGiCvtjEJaRCLg1s47QYtVX03tol0Pvq3inBXkQqEFV" ..
	"nPvnrge1KBP/RklsIaSceh8BNZBMWvTAJ8+iiUbQaqOoofmki5oI7ApQvplgGQlCTnz1iCau9jdGPBR3cB82A1ufhHYYGO28h/Av" ..
	"noZIcKv7I3QUk8CPznzDu+Jzsh+Wr4s+XycygMC4O7KEHYkQr7KSkqo1DnbACYJZNDiX5dZPxmaeQgE/J7r2xW//8+OkXEOKQWbA" ..
	"U2oSt5yZfgDP7+v9f86vvhWXhTDp9tZO58HHB1xf2XucSBxnTV4OdhMZPICHHN6Lpev9uEQScLFRVlZz6IXwuklGiRedMbUu2m9g" ..
	"df2oW+H4DbIrW0Rju0u5O42ScKjP5d5U3rIPJe28AEqcnP1mKfH/9k+sGBOHaZUbRPRfL4QpkhgjumgMnp37TE9RcvpjiVsbbxU+" ..
	"IOvs6N+ZhV/XVgTBsqYCrLzUi+1DPyaTMuyBO7VMCOLKjcumAhhZxU6t3LlQjJWVGjNk6YByYekPIR1cHxvkZsNt9Gp4IrIHy8N0" ..
	"jaIJ5BEXrNTYuUC80s3jC4c0To4eC25GZTpF4nnOfdT6FCqwHtHNAWaTxAL77tececzAw47XDvTJ8tfEKXh8FktBn6EsQmJaKp/Q" ..
	"MbQTjp/A8DK5xvxKVWfdB6MvGY6pmRBaMl8lOE4haeFsC8YxcRPVbxP5NyAL2CRu1OTEzE2gSzm6iwP3ZAbnLEV88Mgx/L1Lh65n" ..
	"tg6zAbsSjykLe+US+j61Tlh+zh8bwwNJ9Ecc69qnMmL0uSUMqymbPzfBsqaEGrA8N5qIX5hJ266sBtm/7csMIMKIp04p2an2ODXZ" ..
	"/YAoZOYI+DJl4QBeP9Da17qKFnby044eNKBQAkT4rSBdesTKj1z0jk7ut477E9Sx1uU9X+OTxduV5xCKIryUzQRM6g0utpDMGnbK" ..
	"sWLVAjujbIT1PGYuVYrCa112vgQrhLw+XAzw3YgTsTMGMiH/Fm+Ts1Shhr3K3bjA15SAs4F/Lv5fQANLNrm68nCEPtOI5q/kbRwd" ..
	"dFHF1gum18l9E8UkA49Q/auLuZa0zumsmvMooCFVusT9nWsG259BUJhfHhnldIi1Ui30bOa17LFpxZB1uSmbc347j153nt3Z/AyC" ..
	"pcl6yQ+zuiqkzGXe3nAluztXXBj1vUenqFR1xRh2PQBgVuH6yLAxx/TKWR3sIUNXb4U+nKOhx+YhcmwZ+vfe+qO9G1W/t39xd8Kg" ..
	"r+rR2U06MD7jXOYgQNk0S/JCNNjG8E6wGGu8HyVrH1N5Mp9OzixAc8BUjyVmwOiutzrKB2Z1urtU+bQKQA/I5arLlqH3ul6mSba4" ..
	"gUvEw+81PJMPE1FzIeZyapagrXye67RoZvk0sc5f3R6JBGEvZrVVC+8IxzP7XOeWjuc+So2w0caRrclV18XRaUIA4YhtH27GrfC8" ..
	"l4dcn/Qw+Nm4GOu0l4U2d6SxaLvkze4Yk4wSBSXLOPBAZj6IDyhw/pwi4n04Y3xdi+rNZMOh1IyhqHdgtKsZIlrD6GCb1sWsq95Z" ..
	"1yIweWPMUsSqfAFt3givkAi57fSqOpx98rUJf9Y4pOabRuwI1N73u02mdPuGiHMOhf3mYAiiDXsG+uvKvANafQwS5rHSCCdqyI5S" ..
	"vegWgkab5ivjqV3rRskO+A8XI6JW/gcj62+SLHe3WA4QbjsmN/XANJ+PguD/E6Ft6uavOyDjjV4ys0LbM0d2V0e/EgvWhOWgcekc" ..
	"/cTZZbNgXJ4mNBkuluyEzOIi1k/sPBxF2Vh4eVSfY66XK5cjIsYiIz5OZk6KPkPNXh9kLzs4HAQ0x+I71bQ7AEGIveu2gWjkXSjx" ..
	"YWD70Cpq2tXaDGyr9BpWNYPkjyY7N0Lbh7ecHevt3dW7nQ8yaJBrV+LU461GkV6kH07Hzpla4SzwKqHnCXT8+kDQr5lM7L7OOvYu" ..
	"8yVq9EzoVVAAfRN4Fu66sPa38dgohIefqx5UrsMt0sa2Ggb5t0Lb9yjDorx2QE6pZqQ/ixv3H33ESJyBnv5hs6u9IP63VGNeguTt" ..
	"j+o0Eg5FPTmZ/+HQjzah2hH5S4kDpQvu+pv9OYN367TKrEMuLuLmlZSh4iXJW1Ezl7h5b0Ct50dOOuDvpE3r+7la5eX+xMT8eZZb" ..
	"LZTOymVRmJNptyT64Vlujww2QvLlhTDSIOtT+zbw/htbNlI2FfkYNT592b6t4eUXhVMN4sNV2Qq/XCVRTazMKqCk3WrCz/kesOt2" ..
	"lsn/b/mOlAD76/MlbVi21Jrc21fTZXMc1/tTTvm5B/k0CMea4vbaWGgU3nG7g/UJ3f5nNXxHvo+jmwkae+HiLsWIhVGfV/OaWHp4" ..
	"k+t9Kre1KxE/UXF4BKCAVs5WCQOT+kmYbsSkVfgn/LxnCju3oRHbEMZE8EVQIlpiYES3z/jIziuWHYVfbudywrg6rCT6/4JyXjyc" ..
	"4DK75Em99QitUgYNN8IKspo/TsTDzOq9JKVyTMJNdoF0ExvleTtaIavIikYn1bie7s/oAUvVUFqhJC08j1OQ70u8dRipIqzhaxYH" ..
	"QMKUXgb5UhniU6M6BvUkCafzvNAKj+K/iZZ0uL+UsMhEgGJc0ivEM2+vEXmXaIhnnNInNZJih585YYvodTnkgsBfzHCgjRMIc5Zd" ..
	"A1t8HRvWJy2huyO3Ll4ZsEDbuhOWJDad2+W2QmkLCbL7tJZqFcFu1r4ugbfWNkTz8sUKcC2mGrdtRVrijO2gxmgL1GjAgLLvS2K3" ..
	"Ex701HUKwvU2mOEFw8gPa4eFo3r8W8+aeKLFOkRxYmH5QGNWdatEapwW+8MNh/qpWpmk2zUklFaRP+lxrb/Y8kyw/AE2nO/q7KSa" ..
	"xDgUYisCC2kQGQfCol5eaICU9Q64Cz73za1PnQs+0+0chdZtYYgfQ3H+RmQWvMoWnPv5CxO6yIKUqYITJxnTnN2hfK3R89jAAn/x" ..
	"W7dbP8Tm+8RO/PATcpronQOvrX4NhnFm6RrjLozxZQWEHG6XUgHMK7zzM6f5ioVQ6/vH5WmgB483vJySXp4t2j4BtsoDW8oaYWFf" ..
	"bfqFM2K80k8l7xe1Xp+JMktTYhaNqZ3qOg5s5aS4wR2/NhWOQj/M3S1FVy65TpGf/Sy6iK1W3bY1nc+rDFDRpc3E3U+7okoYQG9f" ..
	"HCJs6l6QvzJZDeQQvxlvgrmwnECxRp+w+J90LOWugqOrdIVzMyGL71e/MV90eed+AWWt1B0QiYviuf58ym8JaF0cOc4+5e8uSRss" ..
	"uAr7WkdyyZb5WSUgdg3NHrOLmhr7DjWT7Dspz3Packc+HRW0omLzH2XWKP+ZssNU+ZdQBaPUxiMAYAqZpTyS3AoLcb9BPZMRiVLh" ..
	"BJYdz9vrRvb5Nry4IVWumyHSpjhPAeHBikbHLiCR6n97S5BZd9IJKpf8DehyojPNcY/5+RbsrEfKKz6FC6sgGnbG3ztuzjmalRVR" ..
	"isl+/0lG5FEOgAWVjaYuEH+19v3T+iv7TOe2HWOa1/0GykUsY0WYBdVI2yge0ZNmJ4av+arNwJ6ZM0guUL/vW6unl453OuZ9U47g" ..
	"vlj0QG71U3sZbG43rQx+1ZjrwPYOj4wGvKbuL9yt23JoJRIVfFwC2QGsij98DQ6fcUDTJg/68PG9gMCgrvlXkApTsjjhicgAqeTZ" ..
	"mF+kiRYzpVn8lPXkFhtOLSF1hRNTgs0KnX9ghfTOXdrWW807j8VftKJ1baVlcNpyqauPMcjpK52fEFlG9FfIWCefLQ2VA1Phqqxx" ..
	"7E7nuYIJq9HGSycMP/n4Fl5roEtSIagPSV2GgzDcx0pC3YOGUun/+BSG3N0nJvKBb5uJ5hPjOxTokCY4rV1j/i2w51oOVNfSTOEW" ..
	"vmOV84N2JfuzLgyUpLuK6rUZyvnKFBCJv5pIyIjty4gGGqA1sZ2q2uBpjMtjqJBQllTWoa79BO3AgXsLPGWrtUGYAu3PIw8waW77" ..
	"tPWCSjLYacRjEro0dYl1SnlG/DF4HcjKm346sCOVzCo3zO1Tcib3sVYrgR/aN060VJhVAE2b/Ju/GTHtQd+OpCt9wA/C/YXo8mw3" ..
	"fDfICos1rnVQUvZQ8ojLz26Qf23hJL3NbV3oi6otuX2BR+HumuWu3roIFmv7k/Ygcun4jTLbUHzpM+WkKU5j0rBM0EcK4Qtxo35B" ..
	"NoUoE1frQsFad/HRdjJzGc+8jaah+3KjOvErjc/brBjPPfz/fCH+cgMbCxxgVqBJzVixh5TWviNJhbHZWXodyMkRTufkZABLiKDI" ..
	"1X2dqXh3ufkwsKaP5XTIQXPdhCTGibqwKWFtFYMsy6FScYiTzsX0Hc+KCjSdzOjQnnbZKpXXgWCmL8S8j8+kMv0+XCAnMF5Y2pkr" ..
	"fBFK3XyFEywIwMImO+BGghix4kUIo+9YHmNhJLr20jfCvMBruiYlAk0SQtUxvPkNvww0XXyfC6Mda0rfAn8++43q0GJtrewQ2zjX" ..
	"tN4lGQTKZsv7EKGkZ7koYKuYlWZP2Kv7nSvv+1qxk+NNjbZwz0e7Ue/MgWsgt/W78bUJ5ERpBA3oFxC6/FPtjneu5IXNw1rUnk8n" ..
	"Ti0ROboCZJ99/ilDXVNh8ipSuMW61q7V3hPq41z3pIVl4Kiat0H2fdbTONRM+d6Uq7PKLFkgJl/kcjFi2ZPLigxswpJfv6UXvPkw" ..
	"InmVW0seRrS02rCwjZUqe1VyCRiTOZW7MtRGzDbGLZcKYRbX6LnKzFpbi7hsRMLSag05sl0coEkhXlrs70p6FGuyokYntKN9LfIg" ..
	"MRFHDu5tzXJBWbcrl6K1JGXawjov0dpAlTlnWkmsGCj7Wod219gAKCXBp5f4fF85Fb6s1zNwUIjvR0VNlPOgT46tnD43wbVHYuhs" ..
	"dC4eNF1SaGsmsYjNWJ+gMGLFI7x67ioBkFWdq/+WPDLBqS11x/9tbUZhemRXX5198s1a+duCoeU38t29ilpyICZx1O4CETPbUBjW" ..
	"yYWbXfaA8sXD5vOhCPfpZBo21UhsC/l4fj83aPtPKQaCkXG9mUXTLR/3W5GcnZxRHkwHOo8xjoUCBJE8c4SyyeLXWUc/Hvn/26z+" ..
	"qdRbvBUR/wI2ujOowRnSzbcXJlLANpdpUEug2txhAC5v7ETB7+4h9t2gg0JbCYYNcyBvKcXiH0l/RpoWXB52AR/x+wSICOjg4E/z" ..
	"ctxoOGu6UWxHDno5epHxw6e3+R4klWq7fnOQCvVYmJ3fzgE6PDsl1a9qbA3QbXnOLMEKVbkpPm4QU/34rfzkPS1hwOpdP/dAIyl9" ..
	"W+gPjdiE7MvJGgz9zLbR4pMw5pKCM9UB3WG2bA5Nen8DXwFOcHRUCBcl8rK56yAFG8kwwQGq94m+HyHVCrZb2Ok7T23A9ZXzuVEU" ..
	"uhJaTq0xkJYm5zrfl3Y6TK5MK6sqB7Yg2gLt8oWYwHgsI3s/IbOrp6CGmqHch3X8DdzVb6zJEzD2Oth3uvf+asUvze2MzsxHvzOy" ..
	"V7qff+v7Gb54TpjPsmj5xCuk276OwjBwK1mV+LjR26bFEHDa8msbgSWjiMWVScvnEUIJbGRDxD0fPguY2AXnYFJzZmyoka8SA+d4" ..
	"ytQ3fv42rRhdlZZV2K1afM70qteSefrz6F7ifHfLLEjKxENfI1ACxrxK2okRwd4gpWLQUOrr2lBmdByAsZdVbcYXF1WGP6XkEVXc" ..
	"6sWNyiKjiQR2fSA+bFtSm7XYymMBX4+Sc5fYLXp0JPOY4c3iUdiXcIQK75vo0mLAUuIFcHBbHVEVRTTi33Jkriu7SK4OFzGnBpxW" ..
	"eDawU7nU1WH4tkFgqlPsSQSSHAMq+F6B1xMVIaIebljd69d3P0zpr+l8LbJFbQuCU6SQCys8UuGLdGhY+e1Wpqh00A/OnhKjkw5u" ..
	"OU89YloH00dhmbga/GMNDZFGniciOvhH60fdJswE5MAuso64223A0Hth6ELEVCV3Qd9P4Sy6tsD5vlttfGYFm8ZzkOd/ajGsVFXN" ..
	"cqvdy7doUIvHegsYtXcI5T1KVvL7u7Zjnja77BiZjnD7sPhKOuAjV56lrZmFyMAEXpfc8ZJ/6jn2qd1GjqZfyDMA/18DgzEzxS5Z" ..
	"Ri6ehiaEgYjVthLuOnXrYLNlEKyPJwJdHmGYdFgw+BGtpjUs+fvUG8U8uuaI3gxGzSWso6UTRDzRNvfboJ2jhm6fh4/XoyGsCtuA" ..
	"J9fFDqx94NbbqHFVzKwrWbxa739ptJ+vFG9XzNRHZBNlos0ZUcCzhvead8wu3gSUzgHutNjofgVJq4O+OOpzntte316AG7Cas3Qe" ..
	"wMde71udVBW50H+uOzREV8AfeogL49TL16j4e3peYGxjlpIUHeF2VuIHZryrbfB3mAB4zybup89PkuICV2fJB3yWghHoOnz88Y6L" ..
	"u0gkCEQRGLTM1Oz43M7XaErXVrJ68FAGtbew9QT+VxkDJ+v7OwgmnHNa1/D9WCbP80cj1dsNfe3qHOSZdTKhLRaVpyPCTsyxJK3u" ..
	"SPzmNBj71Dx7JMIugJayKTzFGb3qVZiFZKe+LsJgQVNVa7X3OXQzscP++kQ4Q3sEfXs+4k4Pj4/Zb3LWyKpJ+WFQKKSmNGD9EJ+Y" ..
	"abuivlBcJtCHsDyd8boT+ZcoK+kbBxwdG8teMZwa/qSp/T5Au7fquN54GgyV6BP/ooM2gmKJG6d1CbYEUbnG6pXXgn6CPDfCqtHU" ..
	"ik8r6/MT8xhu3av1N6cNAbzhla/VUV9EcPDk/DrQ/Lv06uGaNbi3v7hNbIR/Z8kVQW9v1luE+AnQ0TrlYuh5tGlYsUDoq4fuKBBM" ..
	"ExOOriMfzT9hiQt5t5pXEXgkdULYo4znExwq/jbQyr+9chnheIQfGxLBIoD7QSj8i99Ixpapx5U7wWLjx8AgAvoHZQ2uiKMawhJs" ..
	"6L/JyoDkDJC+u5URMxQM6/7oErBcaAwxA/wVswqtKtr9EJSnG7HaHq4nj7t4xd3iNNvAI2bImpEZQ8j0MmkJlaTewAVmDVCh0tWO" ..
	"tc6VLdJ9CKwvultMAHCeAoGADMYSK5t48H7faDrFeSQhvgrAWwGByXQbcvaZFya4UE+nViEy42c7ybXzO4Z1vZ6jH2/peASMuLc2" ..
	"BmWAWdesaCOfptFbK0+jLrPqmXgfWaLknMTR/beyilt+LgIBhqyU2XbmPg+sVicVKxPsLEEMPEpP3ch5InjmK4kXXbyL5EW5f28d" ..
	"AoEzUGT4iEpSZwijptz+DP2mRSXwQrkIFNX2iORaIR1bW7BppcN09t6hFx/JwFVZP6BxjOqF1k07L+nxsC9LUaWc812f4+XFAiOl" ..
	"9mwXm9364cVZThiwhdehquCrknOBQPYyq9xUoSeoE0veN4y/ToPCvX3oj1jjnjs0RxRC82AH4N/RA6GlWzt5/G5uPn8jbipyZZng" ..
	"QQOoH+oYpSLoD+daoVP+WJdJQxAEjnc0Tm/Si2YMQGOFkElJ/mvmJ1UhpxIoqvwZ/zjT1xe5aMoxvFGoSnHCqDQgU9V5MIyNLzOw" ..
	"+6GXUb+rReBon5cPw+OtlH/1+42pnubX8dNYyli+Vlifrda/Lzwi3+/yDZewsVM44Y3/TckM9frw+71GmcwQL6JLUfxt2gVZQ9r9" ..
	"I8Evek6wBoqWSvDvwyH0gkUNoCVg20uxi/ITtbOSwN8MHEawNlmePMZDYAyVE2Q5dQOzezpclIMrHKhN97/tvWptk4vKi02jE1hz" ..
	"mz7jbMaT1+LDBw3WRXS3uhU1sOj8NyYmFi101E6Tryn5wfVFuvYFdA3xfJ8XCCnygRQS8qVsFp12G31GniGyLtDbeYzDnvUQHqMV" ..
	"gbv+K2doenRf+KqD99e4Ms0KBDvcj0j6Re2GAXJmLEfRngyjyjAXlXOqyNShyCuxv7vXf74guS/TXThWK7MS+1gPyQhgEDyp7Lue" ..
	"wA4TPiAOs4eHIAnCs/IdhgMxdE/dPvWjBAw63XilgjAaDcNMklR7ef+xsDA51gmxT8N075gEg5odCnIJsbFV6aHgwrEoYNDyCOvN" ..
	"VXM0pg7dypA6w/R5AazwEtIzijMlPsqFrqZwBDGWzWo5oI8Kvk0HC6leetM+nbNymuxOiuiJcRKNF0yvEpJ/pvuMPU6x+jWuvdIB" ..
	"CB0ad1zZko0fBy1kqmC2q5bMbIRUG0EtbCxJJWrt/8ngSskrlrSvdObBydKP+elHUO1sSQxTrOqHa6YFq2r4M8pOSC4t5u+ey20S" ..
	"GUnoUPzjdJvqwiGDi639kMWaBcLKFuFPk91AO+/ldyQzLmJ3MVXg2vngLWgZewzw+D/XDWxakXBu7Nn82cA4ky+ep9T3462Ru5Qc" ..
	"zhgQSh+ni1ruodG3X6g86ocEYfzyVcqlxeSZVfLQlEUuYLCqoPq+huZ3Xce3HFaWBcUM3btBhcUEJE6GENeKnpjXSnIFagy8fu/Y" ..
	"w8W9ZYIUdF+ObIge1EMoVcIvIgPmyGYrHv/Zzyk5BCezpfO/GJUf+hogeldyBNXqD85b4nhBRh0SXPIZmQ1DOuUNtBjpSU2EbO9c" ..
	"MRo8eQdu+t+dV5gseTRh8zrDPM35dw9ST15IFTzYvgXoght2InDcnomFbu4ZZ0TUXOQZ9x/GKH4w6uq9yciRgruho8jJfGB0vaLO" ..
	"mDdVjP65u5DsPRLBUdfBZwUNM86+4IauMIJ8lnvUytIx6py/sAEDUc0lXBkmREeZIeNBXIdCFcEVb7Aq3QREHpGV/GkRjkwn7ka7" ..
	"0b5XXTKKSvv7umb1hnzJqiUpOFASWqRYiWZcuUfU52lqCvI2bM97DPJsA9tYUrqmXhL32lbEST7reXKOhu5FtZJ084849llLtioC" ..
	"5Bd57+8e2DPi/Wie0hjqc/DEasSEXApS6VYJ2jdfxC/GyxMgnd/5iSQm1PqvkDbiv4M9QlZ351Og3Mlk30Z2MGw4DhR8I3UD0USt" ..
	"jinm1GDRP8eRS5QPhn9JxKGilDEY/+nGBgRKBh2Ylp6hHreKccOsT6oyiDuIw8jAaNZ4nkX603JNQ4ApWGUDTgNqxQSdmdtuhzjH" ..
	"ujN+dAU1Muk8r9lAirRIkyJ4wAVEYXxfu3sVOuhhis41MAZQQ/7yUuZEoKkzbh3rlqRWYtozcbT6YfL8kPsHfX8xB0fuOovk84dK" ..
	"J9VFD2hB+KC+tVLAIJbCG30EnwGzdqe3gUWbr26NMJ65zZIykYxZFb6GW1Odl1JwFu/j980xN5jDzxhAZ0pNDChoQ4TebbC7JmL3" ..
	"/U99lrW3wi6jSdEPNc/Gff081AkhE3jXD1PvKRKtAJd0loq09WX7vo8eMaSbNM+Pa45HWdL9nzKW8K+92Rmd73Qc1fuV59YXEkID" ..
	"DgJIHoomPDEbI3T4Qpe5vsQpsp9GaQwdv3OoL+2WTIIdfPRqjNXL1C0earFTrLua+ggA2xPbYGfoTNzMZTccEISt7F3BJF3HzAZQ" ..
	"s5g/MblPfStAYJNcL6rsZJqGgm61gDFvqyDmCV/vjRNLbxP8VDx01z3EtdiWIFqhmuNo4ilsZuaeICPvs6jm8UmrsCodJI3Rzlur" ..
	"LkHDPXuP6OeSrm7bkbYrJeBd5PkLu00JKJDgrEVobcr8igJxlrUC0E9v4JYlcJpjRYLvI+7pLkhZfl7joWgOenQYMRk7Sq4jVd6f" ..
	"P6dLjI1FFdgol9ipWyP7aCE4o+bI2SeiFrN/G7lfnv0a66sov3Y7S1uEGDuUXNqEd3r+erUqb7wZu2ZWRUD2KOcN86JMNfH0m9EJ" ..
	"UX7QRMlg68bWrQaM9J7WV+4m6ddqOjaqCZwOqHHUf2vsCT1BFNHK3nbwkyCtHy1Sympeh9+CFWrHf67V8kh6VU5sEqFogcHK4OxB" ..
	"n1Oo6cjXOwQFb6xKuT70N0uKIB6J8COaGznyg1rBPnpxGFRjeaAPPuPh9vWKPM/b/xe4NzFEeO3dJCmp87DaaysZV2RKlc68j0Ow" ..
	"Cb2fcDOLnmaIvwv226eR4LwVEBd5C1HkIfQsPg6Z76fORczfHiuJrzBQNZrocvTc9qcAHIPc0jHKnTeRcwlughOuZixedMao6Kb2" ..
	"reSKZA4Ld/J98NejAWxygfrCm/oXTKkcKNDB/BAL175Ael4w/+M7PLkG3Rjn56jH2uN8q6b7AxsRuVBm/r013jlTLhsJ6LP6Pcaq" ..
	"QSJmw8wXKaZtULJs6lvqiTOCiJYgVY1dP76bT9B5NKWwMcrhBr8+tlk8y0rmax93aoy/PO7NejHVdWc1tXYQvuT+VLwK1HkMLv5Y" ..
	"sRZmZJNPqQbLZN+AAVBo+LXxX68QUrf6+r7ZdNKTA13sjZtQ0rU/Oh5SoLsZUE2hh9O03R9MSn4HL0DUOjg46/NuogFaxAg2LtyK" ..
	"AjXqi4AKzj6L/cFkX6+M6BevjnHFe52t2GfIL2JEIdaE/zkWyDtIDCpopeaX8CPrUUrSEXAIk693qWpXN2Sux/Kb+gXIcG/vrmM7" ..
	"jFmmkGaU0+ZXu1wDPaYk3fwt+bZ79pBkYxLDXh8ad8z9g/LP4VFaEm59yvZ2oezHiFuWQ7k7zuhBb/Dp83+RE7SSLvBHBMAqd9HJ" ..
	"fXKDirOnrjjftUFxtQPtjQbnQSMHekDE9t4yYcYku5qN+j5OCLlkwChj4ivli2SM46Ocuy3WyMTlCEB6iabC6HKQAbNhi5WHy4M+" ..
	"nLbNWIflZJWHtptAfsQc5TxTL057lRFLoZ8Vgn4W3YdmoIjwad3+SMLdEf7xMzPU1t4qfEfhp1bwJWwBJtHv3Yb4+uSbCqUKGaen" ..
	"PPdcPgoA2SE6+pCELdogONLD63fWGpDCOPDhN9SThTOcSjIbIVK3Z9j1ScOP87HyTe72IAko/HGdm9D+fF9L5dqfZsqlZahfLsBC" ..
	"l/NCzZqFwgwINZqPir9Mexfc1c8IhYP8oK0lGJ86XAFByfhQRoMmlB13rHoNMWcD1w6y/cCYoPNgYm6Qk21YxRLwXgS4ZI5aFilI" ..
	"sYswMGvW2CUbXPDdxo32M/cAvVpFzlX3JPMoo42Y46PsVb0yh18/sQSJk6KJHgjxu/nHyFadjNpa0oGTt/LDkpQXEMp3IOJDHtfc" ..
	"yfPoM3Bd7ccBkdpRf/Aswf3gidLdgnwxYuUT7X6nZdPJsnWiU/h8IgauozLXQ1l9S54VIZ32bUsyHRK0xTlcB48ivy0yNE2Btf34" ..
	"TdWbr0378ekX98cLVd9rP9g0R42aDZJNAz7cQH7+24x1oujYTZlFGfbeiwJiY/jNgW6NRs3n8jFUV0cfXFqX/PAZGWhP2UzhvkwU" ..
	"RY4mHj6Fh1DucGvyFfJ1oEv4yHVWoRC+H9XG4A5GY5HYWZMJjOTaihPo2TxPlCCAqff5Lz72ZA+tZOeb3+u4YPNPENZD3ydcjuvn" ..
	"EMXJCbUzrG+nKNbRpTBJMn5pyzW3GrIWuHVadPLLBWbs34DU7wt6kkkiTM/oy6DtgV2m6qaG3QVHEqSwuQcHH9rZsCsMS0sKhrxZ" ..
	"ssEZSLE4oGuR+nT45i0z5+bARldLEvYmWYh8NSqZW+7UIsw+j+xw/vX1CxszGW7kzWkANRV11cR46nBqQJdMYoU2/JJOd41/2QX0" ..
	"nj3sxIG6v/5M50MmtjaO+ok2lKa77OGX2p13i+UUx9eqKLLUBkWFJjlWOWuvB1+l0zL5NPuSikI+En0kZITd9pKh/DmzVyPxT8nY" ..
	"dbukivdw0E+Aiegz/NGmGpYDaeubDqp5Y+IQ+v/mdn3phAaxHgyXuzRkkxncrqXBfF4yI9DLN4RCKnvd2jgd1WYoxJJC0PT3NR1D" ..
	"3kXPsk9aGJX3B5jkKHwJIeZ+jnln1qKsLI3J8rR4h5/lc9uCJ6HNeNkb5pSlli+edQI6HDOF7wp9Bk6suqtZGBBi6B5rtou671EA" ..
	"yB/e/1GT5y4DA+9zyncBDihURT1OcYmy4f1z3kBC1q1kWdeM6ZwzXn4dPq9Ywk/ZAQa9d5sCqMB24HRW/QWLmc5Sv9VBI3J8Zep4" ..
	"zC7FspYPkv+7cY+YPRIylFGdAllQYeFcV6GqoM70pS0jNaeYKxKxRmIEAYEeuEDxyaGDMP5fl+MvCr9MliQr+d3w4ncin5PMiPTX" ..
	"s5m7pF5WXzaZVJq5lmKpNVWjIgtMfVekw++ig38fxUDEZO/uFWhFScfHmBqxcbylAyAA16815H2sJG4UMj4IETqY6kEAjS8sqs27" ..
	"gFBOIxIZH5iR9P9v4agE0MVhd1t1Zc9PukK4Zks2UbC1DqSXB+tf67QniDrwC2rti8VTdZ2ArCbaD0JCbKeWBd64ntA7XLqxHFHb" ..
	"tBXLJPQc4E1AWBNtvRiKgAs6f49zS11dxFVz7WtVLs2JM2Z+7vDBDWKKXwY0Tf4UgIkYTOxpfC7SJYydLW3qWAN9mhZz8q52A+gM" ..
	"Xdru3PFTiAruaTUoKjkSfj0u2jjhMm2r+nmtmZ63hKvy5HPSbGR2Zn8Dc9IvUWZLcqx4C3Gj5UluKTFKrAVKO4qHVRVsJO3yj6Hg" ..
	"FKJxgIdI5y3mVX1gTATNa0vD57QEtP/zv86gR8tu2EJU6T3DWIUXM0pultK91YTPVejB7bp44vHOa9sxF+PN6E/9BUGTkAs+DZYe" ..
	"nL5UNFwJBZRkkr5lHe0tm9KkLHgYZlu9+kNbUEnaJ5/ewp+Jm/JzCNAGS4w2X3DzSr9FhOD660DyLrOy86BGZ35oH0zanhRytR3Y" ..
	"Z2UHxK2mSAq/xLdlLVatfykQF1052H/zPID2FeGw1iTIDOYd3/QqF81hhSH8V0togUPzAe+D1e6xnH8ljQHzz2IRypp3IB12hN3o" ..
	"v/6zZpvcGcFq6Sm4P9Mz4BfAKmdWSTsoke7WhAEeKAd2iJfDfLKLN0aexxC9UJecjB5y5nSRleZqq34uUWxGPWnxHT4mamkaMNsk" ..
	"ysmqub0FgLvNnGbFY8PVAjuOUFMkozeXxhqH3cmf1icmnlUzst0F41wPgAtj4YQSQ+cb4V0SmW9gft5SFeoZt9rdpDbms5AB9mVG" ..
	"0pegMORoVcKpC6RL6rREmOSreR45bKIPn79dEGiIgljCMb56KsBYWc5Ea8QpsPAvLmqWEw5lKuByDPFo4h+hiKzvAGfW+g6rsoW5" ..
	"BAU3Fh2BR2Nh9j1abrYEQuwg4FCk7effvpCXmFflDRdp8abB5+3uVQD9kVdesh3YVrN7Z1Hg6Bh8Gr2PAada6MT+NPj2sdrouoUw" ..
	"ttko1/44FQVBPTBwVEIUracAm3IXmcttgu412uCutkITaunWfNXb5MOIxxu9/0anokK1oAjtip4AxnHlz51YUBo1yrplou1rjsGR" ..
	"tZEIwpNS7bHpx8jrg9rzkTskpcvzrIaHYCFDtthlQ+mN2M99Bm6TFzYEstrytne8IOrduN9etxt8Kp4t7kcvOvqkGPyF/vxlBEf0" ..
	"PY42vPu1n7j/O5Z/Bmj+b8nBPg9C0+Lp3XYA9Jus5Kq+xU45nERp+M2H7sg21a3lbeYt8G45r6Qii7ZDt729S2l7D3XOnxQA8epI" ..
	"msmraX2j9RIehGSm4+qqNfAs5xJti7SdnAthtquKkro/71uBYrB1Fvb/7u9VjmM/1JnlyQJ/u+KIgnX1EhdTcWEjvqcZxmAONo0Z" ..
	"7gaLvNh7muQNC9FDAiyAFKGLLjPEKP1ssH1DbJ6wlljH4om+aQaGl+8eLwxJe37+ZYBAYpauaiaW9AchE8NDtxPPl7TK5FRzD9B1" ..
	"kDPfOB33OIPDOkKEIs+DPMeCnIE3rZ7I16gAi4a+jixGTahaMFePh6j1MEyJsI/anxrEtTe34xGO4S6yD7tVYrC3Zhycj9xqGXAU" ..
	"qdEddZpeKgJPp2oXB6nJdej6nPkac5cZ4v6kngN/IXU23EOalFm8EiT23kiqZMk1P8Aa0kcyX9zYczLrOmjVBRzfo5GGqaoz02fW" ..
	"DkoVtHstC2fHuJcC48wkh+lsh9WF9Y9xjybP/FkBKYxZVCMlla2RllVhV4Vk0ndvrqyH8O6kc82VB/MNpveAXWsvnFnlpFPYoco+" ..
	"8aDa4HbfBJiwVWXTlKfJ5wqVbV7FZPTzITDRw3WJLne3k71c0cETtn2MT20XAMwDhJEvj5sUi+vU8H9ruzqUIBRn4jNLMB5LLft4" ..
	"tqqYs8Lh7N0C6HlbVkgZHRVUyL96LHz9+FH0lEr4jvH/f+C597akYxBzWMWCOBi0f5VfqVe6bLX0BxMCseUFRVbhbDHr6UeGGIZM" ..
	"WBOsEQnZQdteXCPABIIdYtt1r4l/WMtMEO/RHgayBclGzeU46SEANziBtMzdbWNjkT6whRL+M8aPbn9/EpXADXlmOU+lVG7VeUx3" ..
	"wJVJbouFLE2KKD+0Y7r+m1Keg9x+K5Znofkkp4XoH+VNx9MrtppBaERB9z2Nd0tu2ekqobHtGjQlwa0RRXzzdSokC2GE5/gK0Dvz" ..
	"ySYDpbm+qeIwnX2LqmedrYT4+D+COQyX8zQatAZ4uLFM1blKK3/Yfji82slJ71yGq6zbrEykIKFf7SGy22rwCfOnt9uRfyZj68fZ" ..
	"I3g0AWHsLBTxeAG/wxEcJml6Wgr0x6IvTOL16gi5ABdXn/MM5A5t9DnMnLEhRTm/0Ow7mSoTLjLh9nXdOKZPqy9y6ezaFkegBclo" ..
	"q9lKYBNxwJSRqpLzG6shFmqcIzuoCWvYsheqUKnvIRH6dee/W6qDqgJjNtqVO5OlxjZjkFaqVqOug7hh3k3pcESrQM66JRzKgSc9" ..
	"2okch9MeDaOPGFnRVxonm/wMHNAUe055GVSkC0To+aCQ0h79PMdQn/QelgB22fhYEpmOgkS+wMCuLyVr/tJaZnafLLkrEppaiYnh" ..
	"3jP7GeasKuj7tHQM78ZMDBFo3vUkHIBSQA3E87OR0jhJIVdlgVWbNlfwpVUNIiL5gPlRPQIQhkUSm8N2+uHKNV8G6vh/4gTPe2hk" ..
	"K7w2AION8MqcZ5dMkLA0VuB/t1Gz5CZ3gbU/YuMJLioA1yWRwlcA0pj0kfAqpXrH/zdTszkn3iGu39rpcCEQl3J6XgUzbqmXxKa8" ..
	"981y9Fb/drEGkRcwcnwZzyWpXTM1Q9kDLRjuJm3xygHfzM0xsaSAQYrUZdn6m0abCbSSXKimTxzwihc2NPfwLA7jcIF7jfl0dmRD" ..
	"CmXjQ47AdktV6Hfu7cAEjSNj2gwBjYR72XtpRapr8/lRd2waKgAZiBNpbXfL2kxU9beparSwLbz5eCrjfU+1Cxn9+4Kf+1s686oj" ..
	"0EqFofqlHqrUNLGj4nDizDfsE9bMStUnbkc7y77XkWYyMvm5SnBQAuabTGoMcVmjNpMOKBngI+M5djT4Iz+wF3wB5shX5nVHUb4t" ..
	"Uq6d35csv4E2dMovARkIISRaUH2VNPe5NZIZrzda8rNTkgEomiPqK2fB4iFvuhmHYgZfDtVLrQAgbaKxqlReny3HALRr3eHbZrkA" ..
	"VnFp0+HQ+zbR8cg42RCC7hEEUI+HS4gXaiGf7YzTlNNW4gzyLS4PM7yYnGSuka61po/DT1sneI82QFCSvSba7sbhESVUM0dtb+Il" ..
	"ie+PNiswA2IRwZY07DhHupSWY46xb+hBxK4LZecMMThx7j4ukbmOzn4aaWQcA+N0VyxgbD+HjhFSqdy9yFRkKaxlMHtI+Yv5QJ3g" ..
	"KSh96zv2HcyprmNUhiBlUZT4IiYw5SEnPU+tEwtprMbjhHKv1y23NqnshrSkSFQFKtj8HZt4PYmD4LiirxC31n8HuTcyUzCltUjd" ..
	"AXSSrLNa8CfNlYm71vYOusbMpnejepwQPdbhiFbKqaoDYr6aKovLRq2W8nKofJ20BKymudqnIIny0L8UNCYLRtYil+b3HLAnWzQP" ..
	"3a7RaPJQSCyVggd4sMGP1hVV6qLyv5PjhhDXBhAofVhIiYl+aYKw06YMezjR6aeXZrsjrpUPeOMDTH6hVIlMywCfBV+ThCvRNUgY" ..
	"fefVVSIqidLnf4RUJjcVfrfYY8VzPpGIEY8Bg8HHYDLWD8uJu2xMSTpp9daOCD7gOn0VqqJHqGC97MGDyaskT0flt4pOutFuIBiT" ..
	"R9ETY2kU4WWb5R119+ACllLR0YlmTjvpV0R4JYHObAUER2CeYlknRLYXr4zB4zDr8f8SwcuHQHs1+D7V0os6BYhgp82WQSJPdn+2" ..
	"+7xPKoSOhj+QTMRikIfk302k9D/z6/qVO/xPtVV2cgAGmxrGayBdgPoDovKyY/EJVK3SXnYsh+7y+rLQPwtOLtrJt55Cxk1RXfUT" ..
	"kBiRAedYlfsZ4J4ntdNpnMUigQHkzqQZWrMpg5fPbiT7XKR4pIeDDa0MMaQiNswGWK1HoEDJBEA1xE+lH9GfpjFdbjpz/U2+SZNj" ..
	"Y9Qz/4Za4o9EA4Fsf0r/JKtbPEO1PREh6eDy1x87Asj1zWCeLMJAbB6VC7zzIwN6LJY6wfaVDoKELk4xl1+t11Z4aSx5IPL+mtTi" ..
	"IRgNVMcaBubl/q1s7DBcuaLc6f+ntbHjs9AMu4cK7IPfrVvygD9+bZFW6pNJVNQgf3qrZeWVzPbyI6bVbynJiOtSbdyExyD6Rwfp" ..
	"KpPyVjxyqmeenIZz6keGjNln9eRgl8eRFpgfsxoT8CPnVKQ7/KXhhU5+EO59SB0MgFTXoRV1o8cjXQ+oD354EBe1G8aHmtgzuIW4" ..
	"v/1d6I5n9dE43bujGRej2GwzVuxNep5Vcl+WkwRTyJsCPffedNtTejaTgQ5mDAUJGOH94Nur0+3SlvPXLdVvMzII7+IeXqJ97LYt" ..
	"zdZgqIYvTaTQA2oz4JMre9VRJzEufuvFGh/NYiUjW524WCExDvicy3AwQ7gzUffcIFlN+nlHzf7iKvl/JGjBMZMmW9BJRsE6f6Dd" ..
	"C4dIceTgpngLFeCUayEsN7NXWfIpVPA1BdT57EXESWYOxGmV1Gsm1ZeIZnAoQJ0iIJK4AQ5b0MTbbPF5ie16JzuKyMLX+p8j/p/o" ..
	"uaHxH1ZqJ4P2fwvRT7ivP2Hwbm7Z4r7JgqSIkjbFSBDoSrleQSQadmN2VF8P98P5f8UvgbZj6IhZ66e8tL2BeZNlJ4o02OE7bXsU" ..
	"iU8BlY8E6v5VKxd9gvOuzSG2dGpkBw7bdEOYSmIRPj+I05jLHsqStoK/BZer9DAvF7yxzQaH/DgYMItpAxiKRj5kvVJODZgDMwes" ..
	"KwMaTf6iQCxaWbaJs/d6dCfwaiO9a1cLgplZMF+jZPuB5PAbdgRm0lZltNmxneBk8Q1c/ZV7laX59SJMrXigNN+loiGVFdWpjQzS" ..
	"Thp9XsgiGh2gNVHZSqnypgFgsRzDELFMjOijXtd+OPb/Z+EBrxivnwOtRYLP5NsTo6fS0jUJ+nML+j58BAaW60ecmjJjKY+try0A" ..
	"5ape1UB5LvQOwo7PbitJF/1vM6jWsj8ixJ1d5X02tJ/H1uTj4OzjFDVJKFFCnFM3m94ZwcBA7aXtX/G/yDh51tD6nxEe4y3+N8or" ..
	"aYefwAMsqQEFFPA+6TkLNG8ap1zP7dsDj9zT8J8e0jIQGBKFEf09h/debfofNuMitatkuUhtBKQasNfBIJTsPde8aYW8/0+DVMhr" ..
	"xQmad32eoI1MZG7wJS8NaAnGMLu5YIspplSnbNO5OF/lOn0gz4R5/KcHNJrJGFtZj+XlAliqmi01B7jo32hgxQbaHNcyJCK7WhJs" ..
	"6cisYrycb9GNsGG4uE2NGbYGU/xFKHGa6JbFsIKwlVoffX/veWa/nLU7nXTL4IdNtZLL569pkM6b20ZRVf+jWT3ZWko+pUW6uPWZ" ..
	"Nc9BB3wocMT5X3+lXl20Y1ZgNP/geKRvn7o/CbqrhYP/z7HHCvunumM3gE/7S7GZKAfSTMGKeBbJnpbzboWOicbwx27PLf9h7or8" ..
	"rXFbsOE/M8cIqAlayfWYw+yyE13n2PSb81G2BN2sLBv9XnSVaBrpEozYdkvPILQC5hh1rYzjYLcIgPhOyCLZl+5cbEE+QfK8DPVy" ..
	"vSu3P48ert7Zl+im7VXaabHehKZTye7J3KN8n++2ci1HoPAN8vPsMovZUtoJXnpPq1WRkghCitnpW93l5t0fq0vb3OMMwoFokEyI" ..
	"vEOwpM6tibGl+YiA0Uq30tZCxHVFddML/Ta4dZmPNllELNRv41PRThSp/HtVwQCrRy4jF4xAwzbK8nPT5YunZWF17Rt9BChnia7m" ..
	"lNdxUeFEoT04sIgxClUH8ZZz1RmDqA9DiCaHYObUqSyJ2NzE4pYLh5BPB2/JoNkpzlIFnAkD8IsdFO4ZDqHmWITTUA2cI/XOFENn" ..
	"QnBjxJWu4cmhEmW+HilZF6tzxV6txrNR3Xq37XyyDZVgHCcO9Wl6gu7GzIdSnYk8NIHH9GLtasYruRdFxrU15CrlGrVFhaecxft6" ..
	"IvHHukuZQDYW7n0JhB+kbl6dMnnCYSRx04LnoZX5hmQOf6ErbARSy6LqK6n/BrIq5bCMu00TN919oynGYwpGgYvXF2gJfIbcDg5X" ..
	"2XJvlqiiZgOe/g9Zat10Y7ygpES9rXGZBPfYjY75iGtxELuzC5MmrMa+H+9/BB7skCChcuMs9WhBs8ApwdF7bNsBPbPHJyuC7sk9" ..
	"2gDcsreqBJ20uZD/jwAztVpzmbTTQlFD59/o8lBunY0iH8k+U96QlxSyg0Ng1ZsWueocBdEbsDiHgXZixm6hhuH7t7OMMW6fiDHd" ..
	"8x1zKJ2FDh7Sly0IaiS9g6UEE1j3W64QBR2znOoW0TurJQfVLfk7nEBubYpe9bBHqr4zq+kP1k2JXHYQc9x867INNYJIZjoZ0Bbp" ..
	"2QCfHsfoNZm+WD4XCYyo2cBDmV58FbhwODYGwONIagjDsW/YWrSXguYnt2QRB8tc2mwoNAOwWZ/74ruit0ckrhzC13aPQgf525L7" ..
	"1Xf+VwxhvUT4GjGuXQPYEtNju4E/0nnkZDmatsjh015iYPUFNFzJJm1MjFhU092ORpyy9iQTlPmEY46aVcXUlow5fyBFXn+J+HW+" ..
	"Mf7bqOGpruWvcd7HH3e9o7png6lx0zYrr8iFawVvF/IMGQFCy5cBaCNvKFFAOSl/ympQMAoIsYSdR8NQd9AKiWVC7bUQtPxkLm8Z" ..
	"3fLKylQbs1HVBmhxNeEhadEgrG8edJMvPKDZF7klsTq3fDCXA9n8Hp13X81z26uIS5Hc9uwXhOY4qXCX6okfK3T9tX4sOX7YiG3J" ..
	"ChG85F4dliantC3WclK7gPK2SOZ9AQATz6YN7JT0qfvq68L6RA0Hz8mltrqqIFgxW6VKk/MA/TFBzp/ni/odzt5MRZPQOIA/Qf7W" ..
	"p3AZLjiN7IzdR3HJRxULqdD3uJf5OIG8jb8KrNcBwk36sAc1Un3O/emckZ7o78Op6QTPkaKQ3WZfJWampckNgqA4+29bkGbSQw3G" ..
	"ebgFwZX3B/SVjT1gz75eLSvXIE6CC7OqjOwBvRulvSiBEe4dKztkI+5doHGiQ6iQbS2vjSAG8CwgBpzadJW+Rv74Jc8NTz2fHEnK" ..
	"KRRVgQcGnRDtL5Tg5ECCAVTye2L5wBqbgVnOyepQKfzdmUjIeE0j5tqi1/zavy/uoDIfBh6OrfZN/sRgfbfpL0jEe0E6hg2zXn3L" ..
	"609AmbsH/ehlf3uevcv2JkogIUHAOQ6qEtk/01ysgCFAEu5aetZda71D3fjkmKE/rJbe7pPJ5COlpZVnCttb6XO7nZSiUKY/bB72" ..
	"LyiYJxLXN++cxC8/6MmooB6lOogDR0qe1HRnDVpMW57KnfKeMbwK0XwxwLAIIvcTpaJXzz+2rtDYQgUryPo+dpjINg400t9tLRNh" ..
	"+36aBrsK6ruc3ycVIOFsf6R+KpJZ3c8gFWOSxvkArS+ptmOeiohgMou+qxgbf0Zv5qZWF8wG3cljH8dXoZUlqieDWTQmsugh/5uA" ..
	"Jip6KnDTcaH++l/aw3HX1XpJKev8rdhk2Vqphyr2vTtwC1w6ACmiIRymztgkAfzPXljEKfFgSKRAp7GpO06p6l0dv38ObtqJqOuV" ..
	"Ipl5sI1akEvBtPSvdGVLEi6nvztHV9WqfScIh3UkDlQnEvSDb2CxYNgoEidSs5KR7nz2jCZxSm0u21fzWuJh5egSCkKptopt2k4h" ..
	"MFPNg5/JxdyP2onCvxs+olDYr55tVWoBjuaK7qIYw9ebnKxrjS89p7zfVULmE6r01NRbevLRe6xS4dp/RZdVX9nZvmP+18PLjuN9" ..
	"01xr+EqzA2MP7sKfld3VHeFhH5dGnbaeJa5YtWtgHQW6CE8fqGsR/Xme4xDyS8iROrM419ub2KA8pKTLD1tCahmgcczR2GN/xOEL" ..
	"Cdkx/NYgX49efmjtt9o/s5iJ+ngdIGmJ6tEvNNIfpj+a9HIlSGPmbhxc9lvRn2u5Kyb1aKC1Yo4er0HVPR51DBJnoIO9GiEwYeZA" ..
	"bV6Kb9o0UgUQ8SkO+0mc3V1siAO0BqagaBoNrykfdlXCviS88CuXxz8uPeyDKIDGUqu3/eXBYuLHJm1HQDfNlPy9XmlMVqS00ZZi" ..
	"OPKBMnux7QivyABPDEaiv6TUAZ6WBdHEX9lOKJV+xf/+cn65KcW6dbXCebbXAuYJuvo4ZAPNozW1cJUwNY9pd3uqb47AY7yjBVHg" ..
	"W4hWKm6BsGU84G0DXxnOk9WtX8eWxaD8DKf+IXPXJtScAUMttXBwVAD1lwnHoYsJzu9YZDn/yamjsChUYi5cJKRX9P8qlxDjea05" ..
	"h9BnyeMgVN8NqXaBFf9mjkuMByMOX6RX5cvOs/1rEwUWTerM5Z2kP08aC452jab/RYcrCuQo0ssPvQnbXztZ5uuoXLCy+lEJdZiV" ..
	"Fi9G/MrrxCJUTucrt4+gROmESvyrG/RkJMbxyS/UDtkU3GS6RuPOlo7vvqmN2tRGLcLdHaDvLBcW1zqiJjinZYAjlPeF1x3U3CwK" ..
	"a3ngpjc8AswAbJGKKBZI5iDTUZPWdj+5TmrQbYMn6xVI0yeyjuPnXIONLEfutTRxuoHU7ZpNTcndf02FDQQ+nPBc6p5mBovikExo" ..
	"dBUKTZCVFm5hoMGKfCvkiKXFN+g90TxMfuJh/wpW8s9Bs/3jn4UeZnEvorXyUPGzwHnXCM1gjyHLsakml9wgOwDJ2Ex2Oj1/WkYB" ..
	"DY97QIqjJv0qHFBOAbDX60g6rktnNjMykd7u5HuD2XKbFCB3p4udCYuNvaIbFbF3GPuQlTCOF05+2lfK+zTFYSR/L/iH9CvNyZBq" ..
	"qi+FIRqp64SZo3dm2nvlm99InT5gJDh/XVyaLnDEYBiqA5ubvPMvW1gb5mIu3jPiNUcTzyZL/mxpX50UJHaHWjEc5ypfI1djJyAh" ..
	"p0caHBvdBUWp00L7vn+XGIRx4SyCLo3uJOImtO0tpwrajdoQRCxIrIbHzKedZ/7taQraUhhe6xbpASgmpA8wcAG3uD5LgwbpiR1B" ..
	"tlRdVWpX98BCYnJZ+fyCcxRGGnPQGP6AvOoeo8k6ltFipPTk/B7iyTuXBJu7RDd7GUzX/hSkwOIlBkujqLx1ssVKDLYqDbayxDGX" ..
	"1Z4ddSuarDnvwPSASKZyj3zEpeJyQtpGwtllVaE+wunvZN2J7Hd9pPZH3qAYDd+R1AACnEJtYzqfLQ/G4fZDnW2DiWdqc/HTn9B8" ..
	"OQZRL5o2poffR8HvF5FoqxI0nbf63uAsT91jz4n2iJ5UECATN5kB80AGfZpQ6Hp+wyGPCa9zcpJx6Wy70K6bgavEedgnkrkbmJ0b" ..
	"g3wtlZemVwG5CwZLJpvY7DIVghMHey4O8vjN4W7y8NkcTNbKo4KCs2aKBfUK3cHFmbcsIkueNILE4fTMDzODVVJfCWdm9EE1O7Lu" ..
	"/yiLbwwFWq4jitEqmC87O11oSM8YMgJilvFSoVjRM3u31EekGYQGP+AUN++8KAPFLu0LvQOP2wk7KkolQyoLFaLYdMHyfMA9pqrz" ..
	"jhwC2Tdg4LHJKv8MYO9gA7gLaG7CUMSmLTwxbtdbZp/hsehYAPLk5nIgRmuHuImFFAmlMLxAiKGDKdDtfZ3rMktdBSPryxUCARUs" ..
	"GS0TINJFV4U4BeSSuA42evsizDpriUL2UcS+Dv0V0ghokw4BZD+5blnB8dQTt9nTPrCWJf2eSeuamXMz72HurHgfgeOiD/ekkZQr" ..
	"1j+kxtQDmRq3wiGGkrtIwa+yBfuzpYUn70wRq5JPFSwtI55yFuDgtdmxxHesTqETOnDUjIPQlix7AwjhlSh3UsTpWGWK3MWr4015" ..
	"yWBJmwp0HllBrnbyrlwJKXEyhnt1AQePjscW+wmJGqCQjzwWQW30hgkx0Pq9e9UC1EuVFNUcO+/w6FwRQJEcy59rJuqdBx9xcFln" ..
	"bOormoyxraYzsWRrSHhBoOZTbXIlWEaci2ik4sEbYQq/PRkOhltcGRaSBM+6pOQSVj0SYQqbW66WQcdYMry/ZAeLm+Xkn4ouFgbL" ..
	"FTYoHzZFlx7jIk2c4sFgff9HZxXmi3X4hWu8e/0Fv5zzj2rIeY/jJT+VjrbnBMAjReAvMElacSVorKiQNDKoXrgOHBVivfKH2CJE" ..
	"OcaqNBWQu/mir768hKm/3A0UkXw8n4sgKkYUZXLml5MFnMvwW9OIaE8OqPbyWTpOtzcJsjK+U5JMspmLfxyspJJwuXM0y3eKIHKJ" ..
	"CNI7/X0aTWY9GtmZERINkGSrYql1HeLtZGleX/bOZIskYOm9+5rqkvi+VG66fY5FBPfRLIyt9nlusdhOs6RK7bdooP/eG0sGXN9y" ..
	"SLqjRyE9mQVEClr8VaDPRhAmc3rPrqSeOdL4ggGMKugdOisP/af1YdxoYDePeqiDg3QR3wxFPuUT7rcfWkX0V/rI8tKJNUj37Nsh" ..
	"BWR6pBVkmMfAFrH43UXSAm+daQiHykyajOaz3P3xN1uNNxHSu4HlhuUWfUx0yeYaUw5lpVLvtEgcgHtNNxwCp4kFT+4k8fOId2aC" ..
	"p+PHX8HB2+qeRq9xMkrFaOaZQFSurcLTr18=" ..	""

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
	bg.Size = UDim2.fromOffset(300, 130)
	bg.Position = UDim2.new(0.5, -150, 0.5, -65)
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
	err.Size = UDim2.new(1, -24, 0, 16)
	err.Position = UDim2.new(0, 12, 0, 84)
	err.BackgroundTransparency = 1
	err.Font = Enum.Font.Gotham
	err.Text = ""
	err.TextColor3 = Color3.fromRGB(248, 113, 113)
	err.TextSize = 11
	err.TextXAlignment = Enum.TextXAlignment.Center
	err.Parent = bg

	return sg, tb, ok, err
end

-- ===== chay =====
local function tryRun(key)
	if not key or key == "" then return false, "nhap key" end
	local seed = unmaskSeed(MASKED_SEED, key)
	local src2
	local ok2, err2 = pcall(function()
		src2 = decryptPayload(PAYLOAD, seed)
	end)
	if not ok2 then return false, "loi giai ma" end
	if not src2 or #src2 < 50 then return false, "sai key" end
	local fn, loadErr = (loadstring or load)(src2)
	if not fn then return false, "sai key (source loi)" end
	pcall(fn)
	return true, "ok"
end

local preset = getgenv().DQ_KEY
if preset and preset ~= "" then
	local ok3, msg = tryRun(preset)
	if ok3 then
		print("[DQFarmLoader] OK")
		return
	end
end

local sg, tb, okBtn, errLbl = buildKeyGui(function(input)
	local ok4, msg4 = tryRun(input)
	if ok4 then
		sg:Destroy()
	else
		errLbl.Text = "Sai key! Hay thu lai."
		tb.Text = ""
	end
end)

if not sg then
	print("[DQFarmLoader] Khong tao duoc GUI. Dat getgenv().DQ_KEY roi run lai.")
end
