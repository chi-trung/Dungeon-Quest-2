--[[ DQFarm Loader ]]
-- Licensed to: , AnhKhoa
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

getgenv().DQ_LOADER = true

local MASKED_SEEDS = {81021488, 79911255}

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
	"EaqPmk5ja9uoBiaJxKrRw812l57+t+Eo1SaZ3ry2fheYEkO4ZdJBzb8ugPIonKF6Gh1wHldm4i3AHstzJSAQOS2WlsMwKXDhFy8P" ..
	"JCAQOxl4mS/4JzktNvhfRqUyT7suLMi3iCZbB/EV2F8Xg5Dk+TKk8p7xO0xhkb4B/a1LyzAc463er5dd8YnygV15BYEsgrkwRzXS" ..
	"vm5yMVfduZQSwALU2T+lPSwSCD2i5WbCVNx8Z8hlL4TXVPUpvbJM/3gqPh2iPgLdHA2pjcuLbZlnYsnye2NQM9i3MflegPe+Aw27" ..
	"l9r+rwAkske7Wuqck8hi/CLqDDnLB75nRBtgCLkIwWYDLJ1AeK2LuOnuOWurbZQqX0W1nbQAhI/mGLKkkDILIrrupIb1Jm6/nN4n" ..
	"IBajfDHtzvxOBeu6dlGQ4kQ9hdVNPnNzJZHrnoXCY0j63HR53jiYjazamWpPmJoMUd+uqjcO3rZuaMLVshBVVf2oetr8GCyMeK9s" ..
	"BejOeA6hVORlXi09gw/f5kKkl/wHhnrkWN41UtYWsOiZ/uPcVhyAK7wr7ckpUuGbZRm+oPtvAP1+gyI9o2pujQMoYc0B2VTomyqm" ..
	"7HoXSGIWkWtnRtZyYcAL1KGR4A9Qd49KLuBVZgZhoP3vn7jmmRviXYrstf645PKphMgYLsjov59809LzTz3svH+alkjo45STZgxW" ..
	"4pv/USLvRXy+Lzo20fmLDB+TH5T0LwvImQ8yINMMRaXotABZuo3+3ik86ucYWgydtGjzQoCeQBVTcRq8GWqs6h00F78c/qMSeisJ" ..
	"IeUNCi9R+qmS4ShbvtopUvFMB+YSQNqo8hy9bPP7JOyr9yFM6s9fBtTrWyOszHu8OM3/mSYvgdCENQnT1PyarXrNoYy2l+fhq5Ge" ..
	"4NjEzkkzQ/XkR/MbiBGThxCHqdiJETREYCb9GEGfhPrjnL3+yVxiV6iH/Os7Mk89BJ+60dRUClG7r2BlO6uhIwCjLgsb1KoKXodH" ..
	"TTfBhQY3x43G/IYwfDXRvmEf+7n5C7JX8soGjWvAse+siZkofGVU1VfpdWu+fLXFRq484I8of0VhMo5wQIZr7ba9AmDlSGBcQwfk" ..
	"Vh1dfqea7ZfRpFis1Wwc4ZIAlBJLDylhoxjttSQGE+NifMkohxxIzIsNJr7ezlpFb1GZMBEt0oHn18psyYijGJOHp+nKH4+T1/LK" ..
	"we/tixTC8z1TNjAjmmD2r0oyP+OQmkZ48Zzf7+IBS4T1oCDTPdfSLZb1FEKQK6ZEj03XuYcauxyisOkidlhYUqN40pq2LTzloxAA" ..
	"eylQ6a9c2C4BD0UISFiWVPQLMk2tAGeEZAh0yf+7E8CoZ9TvBN57yYBtwL0MrI9SzxH+2aWzvIhIFifeKH/uiVBUuxWMpz9Sg2QZ" ..
	"bqDXuEHE1XfFC+OdU6VRKRZSQ+ZgcVbolGKxkvZTdCk8/7HC0mHMnKXn7cmvX7+MBQT2X+o50qkSyRRKV/+kbj/+QfU+GV+nEShn" ..
	"ve+gCvbpOna+A7ySJFy87sEFOs3RxpXecoWefitHDmdcGbpPmNkO2QvSARJT2mkzU56lJkdqxdjzd9ujXAfgDpSPFABC2g922ui+" ..
	"QRt81yBj9G6pVay2Q7vIw7pfB92Ab9jD4Ev0gQ+T86S4RueIVg2pGJeiEdpadke2DYmtXR0I+vuCRc6sXMsnSW6Ybqoh3mwNhXCv" ..
	"Fc3ia6o852CqqRwybuBWMxT4uphDENcx2V0ScdxnuETtfNv3BKUyD0biHWOn8lq6z6v0GlfQVDSi5n3T9TvrxhZOW9XB7kz4VMjH" ..
	"gyaT+SOepPCMB3piT+yv7e5zBEZf+slo5LGQIK+/0B/b3JJ1vW0TobgKLFlWhHD95Gm5lvjl4PKmiqnS5CQzA0KdYmqYg1URjtYp" ..
	"ONNYLrYmDHuYjqEFuADc0GKobQhp0rKxoO8EgECJ1bzh64Coo42LxXzdxAcb4CxNwq2+98+9pdVFRjH4DCVCTgvkNzVPitdPSkBc" ..
	"aEnywhsuT/5koZEZofxeK2Ds5Cu/v3OPlN6zxEJrl2e7ltK/76pb3q+G4DhVfSQniQzbgAyeVwEyt8YdD9x/sM/n7DxXa43bMT4k" ..
	"/OqpkprLtcw9kdfDnUsJsyqouLL3MAZom65SvZbZhpUluPzpFEnhsOtd50Pn14npV8KKKoX4/9t3qhXX1FWh+4wM8UOdmE6KCU5X" ..
	"p6M/nVGC+wg8ManF7RH/R6DqzBuZOkaH0YMD7ZVUHC5m+tje+8WqjSj/ONZhIceK3rCtLb4qENQxh/XBTx8qBLoaTBYqgtDoKVTL" ..
	"AlwrT37lbjoVxzHJvrj0PM7KDCfH79sgatMmf7zXKdvscjc2OwRJIwrfqjmxgT67JICxe+zZtOAZ2Mu+iMjk5tkfzAfDsQyAd66h" ..
	"5fV72v3BBmR+1/GnYREqpX09aSr+QaIH7U1Llbram4B1la+APPBiFCyBm2e/qLnT9Qn5dGbzRrLxaVuhV6QXPYVpcP9WKFjDCdLM" ..
	"AxWTlAVTyRPUdyTnie9IzuBeGXIumx9fMRg7UXAb0XXL+dHIAL8ZvpRKF5SiuWbwPTHcnrvaO+N+euEo3cGXEmLRsxSfDBCO4t8E" ..
	"D+BOX8ZhFXD+7n2vyYlw6Imi0VusJj85Eodw5F/9TFGCrauVL96sI+mGVQI4kzB/Bl2HNx+j2nVddpV4wxIqDqFNN5Rl6+WPJyv4" ..
	"9wdunamz4TMh2NozyzpISEV9yjqmp2sDvpfn45990hhnPkWYZvd8bVGoRKd14vVga4vyxr7nJI/aKj51a5P2ofhYE3Yxr2fgfkLG" ..
	"qCLSCqWD8IznHmm6RlG9dlm6YG63s4K8ox3IQQJWnC1EM0Af3F1a+X1GTtO0M+tzkGTtf+l2WvTENSUexqk4MqozTIYI6z5wGaxf" ..
	"midugl68RKQVy3paVdYO++S0bS/ylK6Cll8KSotIO+BPa0Qn8ZHV6nS9BEpVJCYk0z2sv5/dlRMCDYmI5IaaaAiBs7fYy7ihr+hQ" ..
	"nfLbMps3KWupX6N68XM3R4AyK/4axqwK/Nh/Dzb4ycvVDxs43EI60ST/d5FLiYVQKNMyLu+cNDBPGIEVNyfqzALxZRSbO95QmsEy" ..
	"Q9UyBmMmicYA4zhVRafHMQiBarOlieTuAWuGmbYpq6bZfGsAzx0EptkZpMBoaSplGktBowXnQdIYhC6635NlzPsv/GwRp8AcH2+I" ..
	"EZ5DVQuDIrP2qhpbqP5lNxZ2HaCVAwyDg9FCccvKbFD3E1rplG7DnOK7uqHof2i72Pdn6ZvynpS5bM1GSjjgnSNM3ZzShBN+5Stf" ..
	"SZuMpvtpVEPRKs/uAVhNg/OyVH4fRGCPe7jb3GNEeuZ6KE7mJAWFGEBdvoLdM8pTB32zUbhWkt1qSf44yFBAJkldA2UcZOjbzBYT" ..
	"ZYwqchPJk91ZhfA5TseF6jeowaf/pdG0YQsn4rU9RN+bxiPDhFhSAAMFv5AJQFRwhU4kJ0mPSjCdheHjBIEtQXNcnsiwGs1dZxZW" ..
	"BiE8nyOGkPFz2JffNjS23gMav1uUG6txYL3Rg+QD81IiCLWbPuYSGV6NlzcGpbMxNX5xKQ7pjed3spaSRhxbrb/wOYVEGpg3NmdR" ..
	"UQVHLiP4J6rLkTlb9ggnsvqZca2I+LZtUeEQvD4tDnpLyaRVPIgET6n2OPcmpZtUNp7/VpFL4nVFFs/zH1XhrYNdftSuW4QQVYHn" ..
	"u29pjwG49gNLu40Z6f4+cXuHLHPfvTB1jNLH7Q4KLa5w+bbQ1YJWL1AK0Jt7u8lng7A0yIfVtaH/nY+nYYOWcKT8qeP3JPZSKCNC" ..
	"dtB7PuBTdvNxEXA9hu+L885yL9qVOMVxy7NADFYByblj1V9WRGG5DZ/qQS87bAYnb3bB5WZycMuBlkETCVS1HxXZhW/yHAMFu6wE" ..
	"IfBd1de+/xpCzVXDcfyBmJ/EpxrV2oFuHmZW39LG98QPqyCpo9+rLD7Ffef58OrOOES9zULUi2a+xOxXMhKeXMprOsVyRcwkAg0y" ..
	"jx79x2s2Webd9kc35vxOCgCO1HWtXMt1w4I2N5wn3M20M+Yv5jBfO7qFgqzlmefWL9wFhF2WDnLBm2LjH5eWQcNNGaHL9GXMXx6G" ..
	"JgyVJ1HQtcfvc9NhXe02moWZ8F54ymxn0+NDbx3OeICvKZ0cHvj9QBwYHOXTDnJ0xkTRTANbp3lL+PMjd27QK57cTfvJiXdWoZDc" ..
	"mQlXwpgIoyrlnnnyO77SDScbvJRfhSgeLS8eeoNTt1rK0Rx1zpRTwesN/DjiL1ivCYM93pYXIpbKUC3kz9nYkJsVv9C1g3JgXM5A" ..
	"5XqmRBtRJlG1dqMjTIZZsmb1qDQBM2J3AZeTzaPahnYkru5QCBUo7LP+cDgHZQTvV9I2KGiiXbN2SEhzJOxeekRJoRoJ7ps4VkCQ" ..
	"eFGQ7y1t+iC7Pt9e3YAtHKt4L83ThJCJdibJ4hIiGGYVL2FgFZG5SK/bPyUVbFuH2HGtd22FPLhzlBFD+3LZdO4Fd3Vl9NFoL2Rz" ..
	"XnfHiVAwZURINeceG8qtnAILHGaZRaz2Pnqaw6WhTK/tHzQQB8SBk8Bcmw7sINbg7H7CheWA3m0sNgxdDedkLU2WGtb69N9HV40p" ..
	"Zvjf9RFmX1qVCJABsr6N/VHCizgl3OaSNrDeglAuF5e3LwvGopeobhuwdbqGt4SfT9uxOOhTBaDTWuHvNytAwlvcaX2DrAdzu6D6" ..
	"2jMZl3tPNEdCqcSmK+q8qUgdVpibd8PDy3Y9wNX3W+EZ3vcuIsC30XThhthLMiGapvVDq8KXOqiZ4utlC06TPadXUWpZPgYbCmE5" ..
	"1j64yaK3MXQtKwO8nSwPXnXLfHSq99ZOcMMfUWAS24tdh2sAUtsgs4OGsxaCfsfBX8CYmttQm8wC+4te88OGOJRebqI+MyWr4F9y" ..
	"SgXl88Mz4gLscHpcIv7gtd2/xSKf9eKHmzGs3vMRUtrYWgBstjR5EDKCjTZHem72TlXTBPvhJFDjOFj6mD790lfXHtvzQPEGEsJj" ..
	"GQz4oqyjVcc1bK4cUQO+8yTMQw26NtpgFtvXhWRkvgpP2g8iB3+qwTlhEuE7d7une98+UThf12+ENzBqIZVdPjF6h5IAQKj1ROEN" ..
	"3YY5QvSJPBKOaTAx31xS7x8Kgb4tGRrtXWx+g4KqUiB4PuHTHfYhc5cHHycvWah0nytz5+qi9Dlm4rLq7BpBFwaK3icDybn80pz6" ..
	"RBIQ/YZxC53lHKzct5ZKvR4cI2DT6XA5OsDtHI/NZ2ymxise+QVkcbQPZ4V/PMtY+ObH7jHBSzRUGppn7QreYXX/Nv5fbBYx5wpw" ..
	"4KUQVRFFwZ839Xeyy1/E9k7dwG574gcl2DwF+XZzjZJsufsq4b1ZBKZCN2XM1HqAaeZ/qKDgKeH+tSQhucaPmqKR52/mGbS2GVTp" ..
	"f4EkJpg452lV0nz+Ze8FhMiLimTA9FBBmh9u9RQHVUfsKK0M7Ko/zk6klChWQtdTRZPeEPANj0MNP9X9mdIOgQCDGq8atNyikWHn" ..
	"JTeT/NjZbtYYJ2q35ZN6Isir6/G7Qfkq2TPy+oC5SC5HCobPLMuTO2g5UmDoHMpX6yQIqY6fl3H8xhYDmDuCt+W4XQWBr1QWO66H" ..
	"FUOEQSVWCLZ1m5D6ckoBw+xOg0SWgTmirjNYBe031V768idjkDLZmQ2GhobjSPm7L0vavi3AevjT/37zoAKwwGfyNFtoFGoOlA4t" ..
	"9aZr06IzFwzxp2F+Da0trfgLSTOjZnMHsnZHAMNnRydBCP8W4yKWRSgyxGEQp9xEna3MF9jGmUsmUyXN2dOWK3FhVc8J929PUJNy" ..
	"zc39/W/nkEUYy5fJ+KFcckqtt91Q+Ry+sI27hzZaBIy91wp5Aq1lCoROBUYZSgNnLEJVuIru7nVuvcs1hji7q1r8iZ5WVE2d/eDi" ..
	"OMbaINfmKoCV+4vxfNF2sZFK0ijcDBmAcuHNm2Gpn94K6lsnficyTGc3ytDQovBfwoGIfbPztPl4kNe5ZqMZt4bGzqu7y5i6de5W" ..
	"dozztIrvPaL2wvE/2HKDD80+bhluwF1n8cRoLF1dmQK4hUDqmTdDtLrH0/jc+VinUYc7m2thDC6KziXwvMIrS/3UNOkYQdIsMETi" ..
	"VsEq627sOlWr0VRHm71uEUEiboNn39cx9WXNoyh88r2mQEd3/9OoQTnKgSi2xyK6+zknMEupaXijKj4EtiMYO4NEUBGWOKLd6BRU" ..
	"bJPeY/kb4JmLw5diK6NRskEVzAd4YCgV3sIGyrR9p/EntuO4zL1JVmWE9LWDun4cqkwb5mwc2X3yOfMI/Q8+7DOMmLh2Ho8zoRJe" ..
	"F2ajyRhky249grRKJVnnnM7iSygL4NTPTZV5OmaZ1YpM3DxnlhK8ZHmJLv/9P40L68i6Os2C1Bcqg2sXbT18FdMLF7DFu7spPjZM" ..
	"lRonFXMASCo0bXZIRDJC4+1y17aoJRvmn4fH1ymzSUSeziYK6TnJhOXkF74vR7kOGvl2s74pyI4B33eYicBurdi0tPmw+eXlrtIw" ..
	"RJ00Vmcmj1k8y6dUPIJS2NQcgyT4RkaWubBvytbqmVXAXdqMGW2GOe7mdUHEeePczuV3wJQmyIff/9laA1JYblqKe3TNQzmj8M5a" ..
	"IaXsUTC4SGpI+gGlbUy39yt9KsdyUtdtXy4JLC0omKpbTSVwC6KSvXeV9tN4CXtvedanAmPTvs8oViBxdQZcYYfbgXfFL9HohtzK" ..
	"8BZzG5F7ZkBchIipuWKq1I89i58eS/Tj+xEEc0+Pn5cPVI5csGIIhWfFz0fit9orNis+SXzWA6jjsRkIWpCEgeuD8NnaKZr1efYz" ..
	"vs0CIaSLqu5dJNfM/hMNTEW9mT4ZocDLK6Cg2KDKH9aFM69f7Guiyg1vFk5pLhv21loWG/jD8XdQLeZdZidckpVcouew8eLsAUp2" ..
	"UzxPnFiBBm68nLK2oDsjG/Z+SQYcZkr71f4BmfshatSqbhekK7Dx0MDUqPMqQLrxjA7JO0bmbF8g4+w/v9pBe4ERTgVRk6BuNSKX" ..
	"cacncCO9LWR8YoWhSqjjiZYlcxJJqm/jY8PPrdp1hM2GsxcNpxEYkkl5tsqIqR1iGfDFlBNnIvTi6YUGoXpJrWexH7UdDrpO3Mtf" ..
	"CYX/zdlHVuNy10kdkWxNaBp+JWAjLVbzKvPyxZ7OXGC1Fw1GlLuu63tLZ6nb6kDJ3Q5sbP1hr7Ky/WcMIw5wVUmJ1Np69+ZDzvDy" ..
	"rExhgoekytJj1b4S50kCMSgYKgT0eJdwljXIo34FLuEHUgNtNKxgkd0TKtAt7G+Q5cIXssKQGYVH/5JTWUgjPt8NIjmit0Qx2o+l" ..
	"O/rqoE5MBeqwmPiQ1nUChC916Yf5sXkHpHfLsl9qQ4wETg2m7cm1p75jo3BG7ez8KhpRQMU9TDfMBAgO4QouCz9LLu8wJFkbpvyL" ..
	"XhBoSery9kA/W1Rw7ItDdlS3HvTlqPIdjIU0pYR2fUO/AfEO+EaEh/z0w/dT+0i6RMptDmIrUT2QqCh50T+gkoC1Oc20/GHNc6Rz" ..
	"tkYRne2adbdpE7+WZz71SRZpW3v3VdBylPP4ju2awo+tHuUhhSuloLYOKbYJupUKPxUjmrQc/dFVFGEnrlLiHohywu3+bbNog+vD" ..
	"iUDYkuKYdW4hHcmGxFpVdoxVP4BIGqfm2lIVnPbHvUtJe1SLXjUM5OtMJXFb53gBWFUINhK6eZpfl9FcNHP7C+5Rk/gezwzEVZxF" ..
	"BHUxRYuAYHg2OJL2FInzre0bjW1ePsAwp03UGhDfLKDa+croJ32kvHuEgvIBGIivJnGAWeXDG1bVA5f984TEfGTze0o3hM5wrod9" ..
	"c4QJ00LtgV2tjDknfyTSg0bFfIXMNwrwZBlm8WskQ3bLMLWFH4+0wPkQbdBbGhMT2pZfZdT4NXuFVRFph/63motj3NJ1eDCkOhch" ..
	"GrXYltrV+DHB4CLBn6BTKeLk3kP/JDfQgbQUS9/KeZrOPbFnVCsPthYJSzHYvKd1d+haM27tvU5whk2p7HMqK1z+TD4i1g34IxrX" ..
	"zgyywAkgLgSoPiBfpuJc+/t8TsA4XXafP4bRcaok2qPgl6+FCif+6ue2YnkqAfMQrNj9PORmleKgXB8avXD7ibkWkQ0Z8jzGJnar" ..
	"dCkesHFRZadwPdpzS2SwB0yPF9E0RXMlTUuWbCXerAiWsnAba8KINgXXSKC0Rz5nyo9wUcekrMpCcJ9aXkMfWRmxss74VVBzar+y" ..
	"DF2S/o09O/Sr5JcBrhxBOYKyZ6vksL2kHZIhuAhsqjPzvucD5bBMTlAqBtI6jP5eHn6bVudkYQ4iqEH4isJN6mqQ2AZC1OQpxSfB" ..
	"E5Nnp6HtaKStDGrtKivEMu6Apczh75zsnL+qxfX1Jos7d/EHKU2UuUXvKBhucM8UtSedK/rZiAIAruwgY4mJ4g5p141Lrd00uZHV" ..
	"Yik6OuZcfznUteVQZl+L8dUDXO+iCtDZIUi91GpKyDWTC1s4yBHQSwFXwBF76WgzfVjKDe6S01ZdBO5r33DORx3O6DEbfTSqVZkL" ..
	"iB6neB00iS7vuBXAAw88PvT1Lb8GJdUJPKAwCup/F1qUno7FzjorEp4HPuBLecbgr9tN4/G99K0uh32E1iniHpXKdjtnnnwfRp42" ..
	"gpvLOcxgOBvR20mtVm11JHfk9ZNKncUgIZjtpL+u1mBcjNvkE7EgOFrXQ5Cy45V3o9GnVkaB2rFbOdOJPylNfOD0/w6OVLdGO+Nd" ..
	"caN+87zqwy5TGKWe+yqGXgvzAYvo5LN/I7oADcca/6k9LyRbKLn0JfALX9pziSQm/BUYHXQEKHhqjcBKqZ+wwdy4n3kjfv3vtiVI" ..
	"I2HwGrR0sWiOO3ttYLEXsp3fXTbC/DtlTenD9Qq8l8P5WSeHHcO3EtRMv3W+g5JHVP/gkNJBhxKuyMyBW70JRho8VzN7KYlo1z/+" ..
	"4oZ/ogBjpk4b9UQTAoE7lRtxdDMfVFV4RVnd7RRSF1NPdmVeyqYDwH5lspkQK2YkX7E5kfh9o82/ihqNVhlNFpKGPtWbA7zz1768" ..
	"7rzJgK+IPUK/LF7vSuZfkUIPxq3naPGs/Xt09COgUpXkTNVXmLacAL4Doob5p1VhxuXGcy32xOwK5acBibQKmYLLNisDIB2VdPdU" ..
	"BA0UBUOiyDAsIOuuXNiD/d2a6KaWePBMsnh4w7bN3QPevRjBB833cnnbSaoZZ+zNaqU5/iaJ4X1GJ0m5IeQtJReCj9rkn1fl0Ayh" ..
	"nQGb77M3hTXMCZ2/zZK9Z50sIicj1YIae/QWAP3vJr9JDz0dVh13JBgiDr0xBWIdO+c3MaPyC0OupuBgv7WF8LYnGAKL0qzqq7pR" ..
	"C0o1+XfajwezLZf9aZyxtzTVpx2AyNRQqwzMrGcxjr+zHnG0avCrcGpl0tTDUc8/k/WTNKYykTM6+CuPWjK12gL6/k5jaZsksOFD" ..
	"EzJKw4q0WhaJkvsnlG60GmE8VjYkjQSDfXyTY5oh5ui9fb7xFh5e85HiUbxolvesX2DoPElkBPe+nKF8Hoak1ouhRt38Lp/edV6f" ..
	"64+v0B9bhlvJkA+q8qgMrye2v60dLngYgJE8KXmeX0ukJoxsziHDwU2hU/UgBf1LveUAGZ4LWsSk5Wwew1AQBXOlBv8BSp7K1gJD" ..
	"xPsEF6RRR7U7jG1wx2rL056sb1X9MeEYqbWWLMMPMFFnUA4bd3wImTbUd/k/XuYaj0N5rCFb+jV5IVrTavWIos5EZTASGIF6TzYq" ..
	"o7EraIEEhqQuEMH+wiySYeCLq5bsJUOcEOBki8Cfgi2Y8VDcQlZels0xEGrjbnbcy0sxDcqez4kbI7vy8cqRwh3mRyW0H+2ev9EA" ..
	"M04XB2Jm6fktlHDA1pak6n9LSprC5NeUwFgABfQZG3KTZmCCaK7sfhL3hUGw7lrR4tuudpT8gqkE02JEq91WXFL1QbnJp/lvL3mk" ..
	"qO4aLBSmdVEV4+87pJYNu4X/QM+ciKrXBbciHRwHWPG5Z9GHo09wwT67xptZdhxv4fEb0qQ/2LQiKV9NqGu567weNDnNgBdoUCU/" ..
	"1IdGqrY6JKgeQAN7k75GnneSrMpYVWt4e21ulNf6egPw/w5lKdvTZ3jcAB4+C3pyKlZphWyZ4NXJfWX5NFvAZ60AS9DQ+54Tl5EJ" ..
	"MzuikFHLOc3q8DiqHpLPcQxCgQk/ha/Aff/XCoOiFaxqWDVpCvNMtmMxPVq1brt1EU6gLjstwyxrj5FGrxGmC0mg+rmUxNWivQzO" ..
	"DbzSiK81Vp3ln7HUhO5OwtLUIiOwgdrkUa8OjnjerwT1X+dBqo3XuPgiAZB2SuCXoqpLre7MIPI7TYbc9vDn6U0ynWtT8M5TacuW" ..
	"OykRm/KztvTwrFXIfiooGX0h/1lTZNRexmyPkmYlOhHNmrOtI+UHvVXYDZz97231+eEJLwlMkOvB3Qiy+XUOYXyBWaibcCYxZAe4" ..
	"PvfnQoRJSfZnrDwxtO0gWrRXMrKtsMNVQAjjZIQqdrxa5VKd31gHvde2FXKfZ+FGe2R8W0ID8tQt5Ve7RbaI33234+ZbZHBU2uya" ..
	"XDUQyt7wC5hCyVmp/Ash04jwDVU2y8J9VTTI3+PD1SMLleZc4i2i/ln13QHAWE35GN/qdAAfM6q3QVCE/TiAO4aGoF2yEX8pEn7C" ..
	"DUhzkd8NmHNf6jKFp0Wt0x8RlVjE8Zz/DMJwo+aPewTlncRDUnsJ6/3YWi31AzFvS+KqDBO6vUUa2nsG6Elgtde4yhMUC5eslejW" ..
	"4l87t1ux5Yj7/yVtAT4d6Jf6RaE9MrDzbeK7ZtdZXgEzwQOifk2UA/PNGgZdbUSW0fLgCd0+DCvFWeMtFwN10QPxExJt5ru+hdDE" ..
	"KVw9nuJl8hn43OcYyGzLtvOKXC6eFbx/4O7AIT9tfFkp77KWiU2/hw8SWwPvhOIv7XEsZUVPyxhPE+Z9GrDolSdBrv2q3ertY5ta" ..
	"YuWn3qIrmaS+UUpL4l0Yxl0oReTEyGNsFePsncdBIMarduZHaCVRfJ0ZhhUAdpNr9E4h2mJGGJbGbD0ZxUlIjsqG00BoaWrHU70d" ..
	"mbxuswtsaQ6l3C+56DYcsyZA7qsrufoTyLOeB7Xt5NpDBZnOSk5QYVwBtIL7b9uHLibwDgQ/0zOZwCk3BfYutb1hmK6uhkKzcnrE" ..
	"mKUvQr7PK+7L4AWlf4KN2sgHj6A0tUJjIfFX3+G6nTzev7/zENZFlDDMlXCuLNgg5mjLqUOp/0UtVf25Vi1uogU7gxzVuWlRUC6H" ..
	"AFmU9rZawhk+p3n3FGG0Ym3zlk8iWSJ7p6CEnA9+tDDZ/+jKQuquMOEbFTFO+qIwE4wlNkOOJzC81yNI4yPX2Z9oTEExGSeSk8XG" ..
	"Iz+bNEbj1IUcvWFADEBsOhL38jCOg4s9Pd7ykGgWQOkcq8AXRaUMe98nic0+yAzfN8x8yMtFPlc/1J/7h6NsimH1ICcnZtOFh6uO" ..
	"IIZC3s2AeXOG5k08VmGUagrZMeFzBbczhaAOu3lYa3N/+FbZlk6jfF7oOCFYQLoMkU4FrvSijloBD8ouFGvhMA5RlNxMtCJgna6z" ..
	"z7sNChBGMyRhjAIyfa2LEbseqE6CMVdI6v2GmaQTaTS/K18DOdvZyq9S9JU3YTt4sUCeWhH1QEWSq2botjSCSQqHUuyIVfDyJsWO" ..
	"eK1s+kAx1wx3benLYFPfDr97tp819/zCScv+7pUITZStwFfE3pQ2h6nCkUrYq4nyEspGOCRTqcJYbqWin5VGMqbkCxz9k69AgfUv" ..
	"wEQAV5YesXUJEf/WRVAxM67U+pO2DBzOPv+kLGlaFYU2gVpmOFPqnSiVlGoU+R/RIYBj3I8ufGthg1nlX6iHnHgZs4tMz7dmCP/s" ..
	"Nlo24b0fNWXcqB8GkV2ldbig9MfIZ1Y1Ew1RVJU2jQtgC/80yK1jOTdbCAn3Wm3diXPN789n1SIDIzRAsnPx0iUD21BwM46eRACh" ..
	"HDAxfY7Zh5XuMgW8LU5Zyt4kjoO1sNG7unCjQ6aqVd8/eSQlnCKV9CPgIXHZNZPyaNjz/QT9SsiRCZyIItjckSWVWbNoiCjWQ8QO" ..
	"q7qfX7nafI5SawKmChOZo4r8kofvrk3OhVOP7QNOWOFsPldkXziIbrBx28zvglfBSJILizyxJAcZY3S1kcCnk6h257MjDOdsmuyy" ..
	"jqFyUa5NYTC1EjplXmoGss/xSErStf1NwBWsvJpJiZi2EwDeDiEl5yBQYe4VB4UZgvH1FwmT83gBMqWLqkKZsPCe25PVQ8SCC+Xn" ..
	"vj1vrv9GLX5mDJQUnokph/YPhRkneqFQ2JL2vK2tpX/K8jSYsDAfFD8TNHMMh9Up/E75bKcj+AZi2fwzRMaikUvIkiaT3vi7swjr" ..
	"Lg9RXYapVB49WHDk3pdA39fCJIdDMgP+mO/7So5e/Gy5gsI1UJ1YP6N3cKvvjcwyVhMQ5CkDIwkN++U+Dox8z69xRueHHN2DvA9d" ..
	"FMoxskY+E9tNSYkG8s9vcZvlHjhst+rbbtetaM6vnKFzWIg/Bwf4Y6WInNA4QeN1HWy/inV/gb68saC3q7nV+rAMYbzkBRR3i6y2" ..
	"Pev6vRRwEC7S9JC9mVzLPqtjDexgT7EWgXgtWvhLc5rgoxSUQrtAKjONdDhobx50aBe/Puo6wdaC2rguSm3sbys+xZat4fxwU1KA" ..
	"cL6ZX4qt1gi1Of1MuzrFyR+wZT6yqo1HveCUsyXOEjZMTx9xTZOGGxCc64L2Ro0pnGp/yjW6hdAh0vNlomv7X4XzQO5IYnU8M9xt" ..
	"aQ9bcplKGpRrgjTV+sykqo9Rxtwrj631maQGy95wqZADilCnosC6lXEjaqDCcyLTp3CmAiXWlM2o7i5G0qilfBj+sIWWVKTt0JAI" ..
	"5HCSZvtLn9xe5C/cNGt6CrhYsefELyQWNieOEiXJeSk4v7LR9xbanz1H6hUss6Te/uMAZOOj+c3XwrKVk/4koSQsl+oI2vo+hqNF" ..
	"me5IUHToV+FS2HDrQfBeBxL14bNoWXpfkvDeZ3QZHdzHLLsuhUHona5eMEgVvqpTSKQo1PovWq1d9PGYKY/9uUObPPvnXWHBLYVI" ..
	"snELwv5SVLqQR22BT5LZFDvrchMgpW+r/BIj9K8Tw3hqZOOBmGI0CUPRXzzV2ZJHX8dl4rpyi6b/Z81G41Yj9OmGKEJ415/+J7Ru" ..
	"Q6b6qshOwDc3cZFGaeX58DtuxKD48Alz/1zA8BOzCeLY8nWz44/hgi1kEuwPedF6uKoGEIgQ6/b1XpnS44s0T9bAKHU9d26TVUWL" ..
	"6cP/6lqUNK+SV5axfJsbdMxHR1/j6GeVv7mwFbKtvwDZJ5/8btRBDixP3wr0+rKffg43GEgO+hvRQPK8pqk8irCpWyU3k6IOHjVa" ..
	"36ewceRs5092UWioTzYyAfwPHnN5YZnH5m2dUv65HdxW9YLZavEY3ZbEkoBzx4TvpnP2ek7KzY+Mc2ym9cjc29Q6spDoTcsS6rMF" ..
	"NPhiFP6k//rhIUFc5Jx+ayL5PGN0p3VqscXxnY1XaTD/ic5ozDqGKhcEcaRBTCYSHzNZVIIn6452t9rD+C7zjNGG0vsaP0izOar/" ..
	"FBtkdN6sCcHtNS4la+vfpjTQLTtEr5L2HelSPBCaAkUASY99b5p4yLGvY9M2jBpDRiZ10mUYW1IoTDtzfkawISt3VuUftEdb7RU2" ..
	"PpWarS3TSG6Rn+cT6fQ6pkotftSUEUAgWta3NbhtH9UXyQssbrWYFm5t1rFDo38oTDbSexIanCLovJKC68MiFxJEXoMSdO+YbU9k" ..
	"+EUwnvv2zl4iwnwmlWRivzhXJAt+9CaveaWjy/Jj97bnQDSsBQIJ++mujAWJlZWhMYFmbaRlcC5TJ9O7ENxhOH4PnvoCzdcsFqnS" ..
	"a0HB7CTiKwfYHNiTgAYW5zlNbjt5mr5qetkPNoSgwUrsj201iOu1PglJYFbegL/vGK0CySi4z6SRHUQmMFCF4UrzDRTBhztnXgo0" ..
	"oGo0Uy+smIiFQOKxM4IWKgK4hfpgOGOUMfRv8Vcj4Gk7fQXaqZvpI+yJgQ1aNT7ASdB2YJFAEzzy7YsKaM1bs2+45RX56oPXIf4N" ..
	"Ko4gPPgqwwFl0+Pxf21SAu3+TqPNkshdOUJr9EQ21CwALtNp5IMxwNcHlVZnTVYHJf5utN5qp1O0vhJVBo6ShQp+aey72YG2Q4a0" ..
	"uUzT/re27bUIfCKhK9nKV3v5dNgd/EMXPkXN0UrwhYduHGeQfDNU2oYGBQjqOQIVyQUbpwfccYqOARZ9KkKkUyVKu9IHnk00Bu92" ..
	"vszgzNPbbtOGIkHqqVvc/juTx84c37k9Qh9l/n/fbRG4itZDug6QankTtmaWWqSIjvzXaoQvQ9IF7wdPhV5KL2sCUuytd7mJBV3S" ..
	"8KI1jmGEw9rOXZWuuBm8U5F2df3XFZLn0SEONydsUdDP3PAd6C2FdMOFdDBJALP4QxTKwqaeR2xoGpHxEjla3EeIbcO4HhrmniVg" ..
	"4mIQptJgBTjL7mXpVbe8RZ74BjehChPaGYv99URplZg6kuHlOiHZra+mb2W14/VEjgSjo54ZgwS+u7oqGSi/pReFvaduo43+uWcJ" ..
	"dAL+UejBFMeblMWdkIEiujDTDC1K16gz+1crj7IGD1BJmP3NFB3izvf+dZhUcFAFBnQ8AG+KUkJbHHXdn5WWkDM6j8XGms4tdsS3" ..
	"XNADJeF4U+H/8GJ55DWQq7oOXFK960eiMQ4cHJ8qNJiRF+zhs+79chwrtVhOK0geETSzc1R3vJo9kTVmVJP+1XQrQS0Lf7mfAJnl" ..
	"YnLubNp04vZhVTVVsJzEhBrx+yK2NrLDv3+63+kBvt/5OGPuFxsDvJJF6rqdh+ThbwMB4ex+5zfEAfY+IP53W+g4laXLlb35gFhS" ..
	"5RPhK8zxk/u2284vKYOS6THed0AaRNETMZqjqEO1pNpaYxbIia/sbGtCe13E9U/D3In/AJmcQippHM9IzERstQaNMGY08H/tg2i0" ..
	"kjtYaq84dwGTjlJY4s1uDfyjEtMLcr6zf3h+L//lEeba84pNp2r3cvARksvmhJhuc9MQk5yWvkZnPVVIjH+tzYZ2OYVk3BA6g2zF" ..
	"8M7ERFS+rN9aKMC7FY17WxvWdxjIcuVdvRJkp11ZvaghgJVdeo1G0ZGyj/1moVlwbkvTqUsyR44HgBn3zBzaOp3VzNofvYLiiQRQ" ..
	"nYowWppOPVKQdzr+yEdeUUmm+/mOQ4AgNe+9JLfX0reBtyrsm2tZVq6RfRAdtP5NtBfqJCjHBUZ9m61BQ8mdMdlF2g7k64X+4+YN" ..
	"o2BhU1lwbHaPI8NhqYfJhiO55nm5i7A1FAKTBC8QHhCwd5Rd1GW4G5y6vzLST1OXjA9ANlRDxkoXCxhYPVkcOk9Be+Kmv61ADBxK" ..
	"M//pwp/9fmmhsNCO6YqW1h+0aDZlVA4J9xn58llHnM0+2TnzOdXgPJ1FjroImiqc8HMULdMjz7L1gDxeHd4uK5YVfOInhGqg+ib1" ..
	"uBCMz/aXLpQXPjB9k4z3kvOkg60zfrFiNmj+PWlFwnQ5MKWmiKr941lQ/+dRn5GA/8FHbQU0JCwyGnVwyfCiySMDZWOS/nwxD0wc" ..
	"Q/8/Sh/yOlr9NgZgkDF8ob7D67p32SfqFvUXOn7bVnmIcTqV+j2NtdQIU2mUFzImSVIUH55evWzPX31rVCeKNcvV8ZaRqF3OSw9N" ..
	"6Ae7pP2VgobAwESD20nPPS1iq9dsnkx6LLAhLMwWyIytHaSt6bYmXiABqFRZAQ5m+jKxaMjhoP9WCnaa9acbwRt5PUscK2j+zbVm" ..
	"e6UH60S5ZZyTmI95oveRDtzN+Y3mUh5/tx8/lYj7JYcqmpeqqdQuEDo/cM1Sy3c40leBLLbSqp9UNZPAWPYARck+iQMDDecC1d/7" ..
	"9S35uQOwhWWJvV/EP9sHshWJORvTpbYo9OOLUH5qAW+ed4aCm8rIWYFYI0+yBHXeTzVwF/nBVYfbaCvHtxbDk8LI50Y2Ug0mYxKB" ..
	"qK6C5NRTQgXlJ1cIyf7qQ+K7LJJaZFIRzFpmeK7bD/9JkKcBWvJTVazBL0o6KmYT0S/sBMBHsAL3pyWBXYNxZ/2WuPJO3X/B1vPk" ..
	"NPDVIEzXRCZnJgoPvvHqa/KobiNrMnEmib8u6YXmhQ1gDJ/n8T9tAUH5zcxo8v0BGRUWfmZLq0EnWrIjaw/GUiVO/8EtE/bVissl" ..
	"pSsy9u5uCcB9wUz3SPSF0/MNVyFcLdS7HgfuqykAUa5BJnU1C5ktT4ew3ZS+Y5DTJmQOPV4pqZd2b5Ug6hJBcYyeGWX7RUmxL8k/" ..
	"TW9prFz8ezsqqZS9lf4fVdn4feq78jPuFOecltewYG3Rz+/jPbKKgM8x2BjskFwQEVf805TdlwN3+Bb7/rTMBkY2DFCI9RrIb4TG" ..
	"qFUZyBiHXsx0m4YTud+j4zZHk8Le5nnNe9hMElTfzZM2kxLb9VcURw5JONvgyZnjIkUcI797sXDGWm0DJz6sPrdszfh/mhr9K5Zc" ..
	"XJvCvADkXu7QZjEOIyvzMJmoiecxiVyCPRZ56zyqINCDAd3BSyDyS0tDs0QWmvCHZLa90EqkMbXnl7yfWK/7MDnspXIZbjBQtGeq" ..
	"svo0kbYOagLTT46fcnTaFlWU+H/SMGlB8aOgF0sEl1mNIVjcjRJuguwjdsUybWSZK5pOQsqjbfkxG1ZltU2ogqFoRKbPx1jfKTfL" ..
	"yhk6DDbhteYAPB/L4HVWgbx3yibIvJn03PTHs4RkiIZa/kbTLGQPzylHq6tPKVo0pmonOhoNWPIN/KJVC4rnTUIl1EDsD4k2Tym5" ..
	"lq1Z9ym8gRAFQy+ZCvB/cPBb36zF5cPEKzhiKWmEU69/+oMRY14hWOXwNg2ne1gB4N52DJmZXPTtKqRd4U/JvS8Z2Z3HcC/iqgzZ" ..
	"Nol4VBFmikDJZTLxPa0NJ0a5IkZQvTJFSv9nLAR+n+b1i1YsGDN4zfZ3rZqW30YtlUUA7D4+7+QI94YDxTtqF4PB0EJYEgi1N71F" ..
	"MviV9ePGJtUvaWISbpRwqdUa9HxClptNcO3WiHVR82qz6kRqLHP3GBDwCjzUPBzvjarQ09f9egLjJupOvxDI3rfr/MFjZOz5nr8O" ..
	"jkW1vX0O+rCCR4ExpFWSdmx5VkrySYKtKmWbB3y9yZVcO8mondz1/DoSIYuWOqKem1e5vnjmDBKyJhfJWu4/HSIk68Hozw+9rdSi" ..
	"Ps6bera+IqJ8nF8hJn4GS2x9QpV8F0tnxkcSisynd+Jm0gtameBUeMzvGrsagnpcHcyDCUlfrrf3I1LL01oEZLGM4Q9U+K6xAxuR" ..
	"eGqQ4hQuLkMnTwic4izKnvJMaRvfowS8dcZBzzh2znkvCFnUlujdSidcdws0PGuXSM6mQ20KELdOu2GFvq2qqGgEEg9I2fukMpow" ..
	"WK1gX48F/MTsz6GxDqtP3HcZTuYYUdSybolL556XZqwyD7POkOTiDsYWjZfcjgTRgdL3an0QZmDeeWme1+q59FR+qMC75K2HmOIU" ..
	"dgN6qLbWuXusWVaC4q/mjB7vusrpW9HMCFRzPKOmZwW7yPj3Soep1rirjGLliu5r9tfBPoE72Pb6qI2wdws5RPvzxratZDtrKCPH" ..
	"xxVFngrU6agxY1JnIGDfyhJhODBJQBNv8kImSIUOKexgUy9yye/UxVCw+jTSctLXrgLE2CXHxbgi1xz3XS27JIAcoyB6Gv5ejFBS" ..
	"824oBf7kQi7q5NvupcwLYqgbCCBXTEf5rrw+udlqelcmc34KabW5K5+rRrd9uAzIj6BttzQ37Hr3KPbErI6WBYBNJx9fXpjhjQOz" ..
	"zNnvn67CHd3fvm9djjKaE5n7InW7r65KATllhxI3u93q9yaqoUUOKlZ0DjHTvpXe65oxFAlGL/HK7YxnVFx+T2bMnwPVxQB5T9Wk" ..
	"kvDQVsM0bQ3cbNLxbNEadtFwcmgEDijVyZud9oZLoM1oXZdClmTs1Y7CzoIIgnvKseq5oSeDO3ELewBub/HbzGlwfqQIDAEg94Mw" ..
	"6I2KkanYADiCBq8HrEZKAIbLPM6sSlKC/BaaOXH0fxsaiZw86A/PsNQ0qVouwOmzUBHs57zYIpgMYJtQ7ew4IodibAjU/HnzJzxZ" ..
	"9Io1e9k9g4uItrTEVv6b7Jz/HemX9PkhqM0kem02ssLc8GdiF9dJl7M/35vnrLN/tRmJJFDmoFxTqG16IcUM6na8sjohgeFO9Vbw" ..
	"YWTG2AKDGwtB/wut+VCIuqBdDmC0p6d5g/uGDx7ZqtDUrijJUy/9E6wrSx4UtLA88eWVST64rF/BlVlgVYC4g0biwC8uEX8hUAR0" ..
	"mSkUvBaph7ubImPwDlrlFJ2nJplvYbFos33bFPw+cG/kbnA9y6yAB2TQI7U/NOvdYnOnvHPjJKQedwVhkod/ehUFXU+xtjQEbDSI" ..
	"mcBZPw1u3fB1OvXLBaemPZGAoTjTyxMaJsmP6TNzkprr6MEBqugCn/skX0x3yysYatOo0Gldq+pCSmEjYnfB0yiiGgJ5U4/ALfrI" ..
	"vkRMrAUKCV1quaR1vtWRqSyC/jL1jL0w67646G5YWzpyFROloXFihDoqXDmI7bygXEZvkT6s7+dbzGgCoBVrvGOBMbnN5rJE7utw" ..
	"4kw6ROOuE49hwHFlMnN7kOGkayE6pOcPFiVGk0FNRPSnrzsQ9RbLj5rW28v1pNvkpr1D1zdPId5ERDN5wsxf494gTGXtQwAUe6ds" ..
	"CwDCXkzJpgGcbxNnZShApEkqorCYLmGMXu9p6IGCObegHJmlat8GkEQyTFCuRG6lhRtSTFuSIMKQHwwom+J/v81YFEnIoLfVIy6I" ..
	"2MW40r/lUx2CRJCqGXMxadk4V59kKIR6emZekSnIMwR2LJdRSmySePITjn4JQg1L1xwLDncvtkJd+/njwKOwNo/PnFQbNYd3xqHI" ..
	"BRL9Ahwd6/bZDdPYiavxlMqEafZwxx1Tm0Sgwr/OwP9aqnIhYGOd65MeU4SSdjPn/h60ZaUazf3DldSmd9REuXfKc0rZsqCM8ppV" ..
	"QMhozKqwLRfITGSp10hEQQxZB2Ee8VLgD2XjJIIKxxiBNXA90xchzgkLQ7Cw8Ow5Dy2xvW0KP2LYszheBBHNFUnPK/oalZJxQMME" ..
	"pKrxUObngBfOA6ctTVi5Z2iGNjD3vFHbN6x1erFCuUMxeEu1j/sLWGgjpFqm/z1ceUiu7nXixKMFnPAbM/Dqe0PEE3GOv1Gx2svK" ..
	"c+HRzpATGbu7Dr/QgbmnjnqSohk8fE2nzHhshCUXDSIp+tcTXBTgAKPC7U98akRDaCj8Aiv11pKj6iU5QGa0KlTcnTjdbYYnVupJ" ..
	"Fm9q6jNUL+qroKaQ2tvhCnVDoT4yiiVr1mLMDiaW6yUvULsRkA5DsV9gG0c9yIhVrKEx4F0hD4QZaa5Ezi2X08+kwUNrYxnezz35" ..
	"WMQE+lzLCp8bXlaIpcuI9Z2/S6bK2WmSuGBefglbjBNQsb+Zs6QVgPBEKhAgtz822Dx4hUc3AJbgMfA1HzQ+99sw5rWzw/fup4V3" ..
	"jNeCmcA0/Zy4CmCOUqR9dzjoICdgTspbpxU1LZycxc772PAJc5oKhpokk7eLGG02H5Bv0FRobIShvSSJJv++DRrFPmzrZEwYPklm" ..
	"ewjgaDr1Db+z1xivZwgNuWQzEphB9iAGWAZ0/age4Bd2xosxIFmT+UH8aSN+cr4hOOIFdGVNhELNu1IFSujxdXGW72rXBKhnskZg" ..
	"TpJxQHVcMik+XHTZGewsCsr45Zra5mzO5aV/d3nk8lmJOPkflBrAmVW8Q4L01dqO8EBDG2cJW+dg88OhPLvFstfqEdJ9gZpLbuVi" ..
	"11Il9TD9rQVGHZ9z0+EWf97Vvtv3Mp3DVPTjktNwvLYvO2fR6fP6sbxafpVPke7Ce32CUqHZS4aU8LP7IwpK/DHmlzrEWIjEc1dN" ..
	"6lfkV3OvMZdm1o4+yzFvlr0hLK6NaShsYqpEBnzVy0/uDnan+kp15Hc/HPFdmhlIt88YbhIk5qMeUHzZEqY7lDOQvlIoxUeBkdxv" ..
	"TR0IzcI3zGv1cltLx+OOMJnTcTRd3xvFQRsllsySKZICJt/PXC604IkUyTy0r5I9FU02xCaShQ+nV9jzk7sZ7A7G59svhDYDsq24" ..
	"e5Yv0mAe16ILnlbbdOUebxMROvAMAB8W23CCo1F4XkDDGHNQyHBUSVQjYVJjqoSoEh/gKlaDBSG8Bdyz8oUspfK0u+mRiascv6vP" ..
	"00HsJtpTXbPCAzkCDo4JaqLeZuFVEOthK1M5Elmo8R2PTHhxMzI4T3FUZCH7phDd5zrDwNiNpMzAaiZBx6bE6zGKApiqjEhFb63h" ..
	"ls+npSF4pSa2qGUysxgqf7niJALDwkDYFrpjLtWDCII2M4ahiMo0L0go3zVD2Myfpr787ZZE/h1XTCgGxrf+6ynMH8E7zEp5p47S" ..
	"Zcbl56rsTXO1RPixZnJFyRiYKQL15szSzbK7GHCcCvg0TyTJsDj92Kmfho8TdfpQwf+6lB9GMeR7gQq6hxsM9lvhBZBumluZmdCA" ..
	"6yCSVVVBqgjv4F1TG4U6Ghier0K9JY+TCV1wNLtVUlGH4zLK9Dgx8aDsF4/zIcnBmx50sOT5mjDghyvPvCJZpad8g6Qr/IhHXaG3" ..
	"OeWCv1uBYUs3MV1aHW7IVM2W/bK9UwlPqOq1QrfDmVqIlJyeQZVByzcD2WEjZGzf1mnJgux+LDDXA1thAtJh+dZXLQscXKfc9yQl" ..
	"IQOAchlukL0sja+cZBUtraAZYHktedbCqmDo2nP4xaeQh/oMaNNgQLo12hm+gGeOzWmSc98f68ZDVAatP5BKyArpXZyMPLtPg+7T" ..
	"kCG+PMs69VNZBpmimx2taPj2PxwJuLoaAOlTA1iFqmvvU3Az635mLromo2zLo7q73P88llmwddI+XxbwFGtlESDSByEC3PxLrLcK" ..
	"4H5W0OnQN1alM8k3MAzx9XnZ+5zGaq/hDr8S6vJDKb35JU8DhvG+XQKjbV5od0e+8ZRWXQUodt9Dfe205FcaRIYj7ZJbnMEgqwiL" ..
	"FdBE6XA7QPLPB40b+Ly8MEDS6KTobnq/GbZXVHpPMG2FdaI2M6ov3LQH9GLKG+9W4tZcd8XSJjK94Fx5OxBvSJvzMqA0i6GWHZIk" ..
	"Lj9Sus+GmeLALvqeDbnso+Oe+AJ6xXKJ1VrSv6kQEs5ecDo3jTm0cbiUYMeYTSks9l61eH9aYjPjQPL33PgUccQyqxjO8bWgorPW" ..
	"wkNeOtQ5Q1CFC6JsIieefOAZBGyHYo2UUMpk2lj+xq2ZAJHm3dhIBalyyRbhWCtjqsDTyURiWafkQG27/G6eoTJ2MUsoYWdEiysB" ..
	"ANPa4zHvnp0KIjsgKTyuGcePsMLoHE8Y78sTH8zlaV3V47yb8LbSxSHOgNLemFLb4aON9x8T0AelzLct0beUD4g/QpMQ4y5gPzMC" ..
	"EgYTYh03hOAHZDbs9zb0sB+PCpzGyj2G30I+bbQau3vX6goLNtLqjsINazT8xfVj+yXGQB5W2k2u3X0PcpoxHg224TS3wxtRpvRZ" ..
	"Ti4ZLv+Vnv5ultDQE/ropbichq4wEsiUpEUHgy5Ln+TLt3sId9+Teuafl/J2RPCQEg3D5jAStxThrm8r68MqMfsWGTAqxXcAKgoO" ..
	"iI8bZwr6aVkGcC0J2pnD72hmUVcnn+KyuORZtFD1tMkLfZ3VEi3oeXh1eC8BMhrADfBq7TyscYPT5wNAyKotv5nN0JLCJi9OufpM" ..
	"WtQgGZpIt/6a/I7Nczjfcq5THWFmRMuzAiEyZV3/Q+PpjrusBjjhXtSwCvv8FQLWYXzZcyVLpZIf9UcTIW8tWjUr9KBf89sE9+H/" ..
	"Albxq7u5brK5cMuPMxp7YyCVK6HNroNIixEAsZIlsGZxK1ZVWh5bceIoVPXBqw70KdIUlChESKm8KdQDujR4e41Cyngfw8solsjW" ..
	"18ntPhkUi3MfOh1EuOEe+120Rp01deHz5QO4vG3CQASSPvP7m/KssUc7ZRrJLKrE1aBRf6bmWwdzCj1sbn9sw+jgguYa/IPeU5Mi" ..
	"AphGuXIu2TjRtbRNmPKDgm9d5hNuDPs2VYdvENk5qXKZsVzSpeFbFoeTShOQDvNt7AQUKmTvONA6BzJtCw8yIiL4R+v/7fBt2nbv" ..
	"eYaOBx620crbPy0CaftbSDO+c4riA9k8lXC+1lrKMd4qjgQWdUPcH05WhMPkfBunpXwqm2COIrtJNmgvKXle52Zap/8eyOlbkXAA" ..
	"DLr1KT25f/yTziCytsPbWZA+lJU6fI6Bs7GByW5VdpM+E7YXy4lhV/NyHgjWBxK+txirPDyOlixRvFTAYiSggMDmlEuC7ITCcTHo" ..
	"N2GFfu79Yn2yELRefhgcjI4s1KGYu4UY+oTlnRaanOOqTLanRaye4H26k/8OuHUZKKUgJOF69MRanQYGA5VS5+ohC0KIdUgd+9Mx" ..
	"lKU8k9s3yFv4NrVror5Iz5hUYNmt1LtNV6c6mwgy8Ll6GxuPmjXJD0Ht8GCrTrGZiWZbAWEWwwfMwrNtIEy2pRVFdZX/oFuWF8tp" ..
	"dlD6gsNH56QlpLlhEYWkVfbh663Lmb6TxB/pTqlPG+UYQGv3oN12TiUcGZEj3XlyNOjBDSzLI6KN7i9+th5Yseshfn/suVSAOA1n" ..
	"K3IORlhLJmHSJLq1vWjF07lLSv7+ly59syg/mxTLMPLlG3szAPkGa2wjsLMpZ8KXsJkwFITYZJXvRgejiWz/XBPDAb0YCG3FkFdF" ..
	"1UZDVTYA9aNadEM7kaqa0jHQSXiwDrEBqQzVbMRV2T1xe4i1iJpXA8b19dvQqeh3DTs97e5yfH7epjJwww3WMBry+t1DlChbPEZS" ..
	"ztwQSetV6woZBBHugpcTLIk39U0NOcLWQ+rJovaSmIC1Oz9HUIYa29DCrSpP8POIUqLMC5qZV5jFLh0G46hdxILye8z7mo9wY+3k" ..
	"2U4pulRsyOYrSX84efY+Z56noNyv5r0c/G+JhJJiWnc7Kq3KO9feeiuu1zsbQ2dXw2x5gJBM6zMhOYIur9YBbB7LxFqvpZhnIQGW" ..
	"NaD92CoXtgTkY+6mp+6tOkS43KzZir0RE4btSi3BtA+Z9Bvb/K4ti9gSlxFbaHHoqkavwN2VMpIFT9LEIs+7fA6bWN5yzzWl8rdm" ..
	"UK5R/XLrEXL6A6QLPP02B2mgiKWGIdM+xfcu+YZlvqoQQfRO3WpOYFLMNCoFPDMJOVRb6IsR5byZx9OKcXDZneb97akZ63CG6AgH" ..
	"dVx44whi/Ibc4u6xc0RmoYJIB/MEovCVVwUsEuB9HvKDvIb77WkN7DVa+xMg0NHlvhLnJqHYJNs1b+CEk+AdSEh3sr8pNnfpQo/W" ..
	"OJddgtyzQn3plwRu4g7IAOteDPo1gg3KmgfCcWkqljFLQKArrEXSIje+aUBn9b/SIuizWjK8fbXw35uhv9MEdqbWKQ/cvF2hPf6a" ..
	"JtHjXvdKYksVk2U+tp/MPCfwsayUUIxq0lfvf7sNhtVssf65dgET5YI1+SpMfMOfdOCCYXWQIl7Ee8tnaYfblbZXHpUf2DYd3mKx" ..
	"T7jd6IIsJIt6+cEhWppbP9WYStSwX9GdJPIuBYl9HiF7jtdGuKONc9Cv5kTsBv/f1Gl+mAvFpumIHvd75tO7+3S9iTvH0rZczyhB" ..
	"wcby3WgShsEEUeGPjdqRUJyc72+xyGeunETqk4juMk2l5NQpIB8xYpafdr1gQEoBirWGekZEIWomuMoWlpmLDWSiwOQb5GA6TnWu" ..
	"7pQh8cS9rzOH4LBfisEyEROfNChYDItCz7eSSTY2cIkDj6pCWMf2o++gBTIDoKrabiLIi+1eAlc0wnjY+A+JdZ9PNr996qmh/VHa" ..
	"0EIRnDguUqq5GYZyfPBpyZ2O+xz5cIlHMYRDpiVODKbe0MGBl989Ipipn/jD6isludbSbip2EocfTrADygdOnj99OSWFUocdnasq" ..
	"9WzZpvOuIclTUjBIwlqIpBlQAqhEsopIso2SslrfbOTUn3qgXYHO3huyeMpedj7COC4RCZVBLyxFaFkz8Khvh7EpJss++NNjLAKw" ..
	"KuOfWTKwuxC0kuNgOhMqO0V/R9/nVOHpyFy4SN+AzNI9wxOWtuWgRHrN00PnfcMOkqh9ZIhblrybfK+vUe3zPf7ovFy+9bTIxf8o" ..
	"Q7oVyJWAFyrW7dxnN4LxuxP5HclYcZxBv6fuX7PwaiSU8wn/v6UVElUDXyBjBkGxGgMVEnIiI6BmjFiluL5V/2po/0LhnRi0wt+9" ..
	"JKldtjnK9zWbWAwTvX89deuJjV2bLxNNUWADsi3h0L0uB3DHwHg6LUNUytpq+0Y9nBJzh6fjZ404dISBRibvspiEcR115OKF6DgM" ..
	"Q6iWmWajHQMdBA8QIhIYNx4ISP9ntflb6MI/eIAf70MjQRwVufTk4PmBr/cQbopq5NGAVsBmojHETyK923N/gisHWnzaVw5JHfRk" ..
	"uo1XDANb/3QeVOxqo1rCjzPVpdR4i5Ji8h4H51RZQH5761JEDCUnSFAKf7awEkFXEvMQdTcMBTQXX1aqaO0f0dGPRFpL0k3jpWL3" ..
	"rRwVb5+KLYEwAQdQJCiBDOL1zEKnuAyW8aOY7L/7xLo45NsePoOHfhUvIycUKTN98tt6HWx92VY0qqTa3iekZwP4NGcUbyoZFTTR" ..
	"rQPJWG75E1vn6Z4mE8AV5+7tAkBB1X7Awvem8KmSIVHiJAjNHtClJ3kA1CyWQaEbQckVXt2T9p5vIr1j2hU4M00wkdcoNldrOMBu" ..
	"QbjcZ5qDhKgU1eTNr7a+BKtXOWDQPUv1YcGhFZDzDb9l3dpoqPpzXTe4H4mcjjEvsU76aQo6Ejj1bY3m3JHazgdzXFBGPybO21i4" ..
	"uSVHSJraRSeCDrCkuT4uphhbUE5CQ+mXWjwCuF+iwtRsQs/wRhiTUgICnMxj8RmnbJBX2Zy7Q6Lrb2/YCLh6cOm1ztCyoBhfk1+O" ..
	"GHKd5tpXmsORQFEounmJ6XkJRl21Iqf6sLxJH7RXBqxPsTneFG+UvL0LeX5IzPWPy7oBjNYrq8ZwQ1T+w0jiSaXWhBvveAyFzYU2" ..
	"1KoUYForw8Ubbfla1xeo1ByU282MP9S0ps6uHw/Yj6rlyYTOOetQzDnD4wpg6C6DiCPyqofH5EC1GPME6TL34nt5UHWIRqYK7IrN" ..
	"tvMpYQFy6QWPfpPXiGKc0wpjgBWT+vju0iJPnWQ9I1Ml4cSKwuJI7L+anG1Y2OAVKkuqvoEb/H/22XGlOnFPyi6LSdw5RBsJMpOK" ..
	"5jC6fR4wVz8hDbHvtWH+d5xEqntQaiV7/XQdYryFbgiat4vJyrQx4JlwzRfdR6eMEsN8zBuTETGXBR4tnRR+vVQk4//5eBp/RMDt" ..
	"zck4oRVf+fIcyrYaLK1e8uU5HwudAXHra9asTwY/7EvbVIp8eikWm6i0WO6vISt+SlhxfnMleX3XVghKW06A9RumptrgW11Gh+bD" ..
	"6Rh6cggsK3g/REB6NBiKdHH7JnV84znGGsNO0Qm3Md5auPSYjq8p0iT3ZnWiCK8wg+tjHW07+a1KByzelROPprcfo0SlNonsU47Z" ..
	"pZX7KWATpYDSPfFMeou36+mdgk7n4OJRzLc6FKPT1cZO1se3BZW6cCsj36gOHBAWQJpevu1MxRwCnB94bHwgsB6M5CtMBsW4syFQ" ..
	"TlUD+kD+t6Vt5nee+C46xYpkBgxDTa8ISd7xv5zFZk+BGo0/Z9hbpkV4xGDI6BBT6259nKyyyY99amPOXp2T+iPv9eVqoL4sPHCQ" ..
	"JJEy/URZcLTHOHcATNmTmPp8Fh3mfwEpT8sDAR8ib2Xa6PFbHLj2XaenDKd6V+QhiQoQK1vGcmY6ga1Swk/eDtmQ5DFxqyKsiQY3" ..
	"Dp+vlJ1tG3vw3BoSaMWuq/4nlAoX5JcQ4xr7vEIM65iQYqZ3NQmMk4WM3QGW+ghC2+EOTD19eGd2szMtrB1TjCnzA6Glr5bLUEr3" ..
	"Y7tEJ5HdZgGeYNUeKa/r1UathXQ1etnNWR3z17wg+ptmm0g0CJgezRi7mbw+r/DdqITGU0amMa7sXxs2mDqU0D/C/RY7/0gKWeMM" ..
	"4uxOfmdl0E9r1Yna3C8FjKm/z/IZRjav09ArNYnxw1TdbuJ0ePsdXJ0jcoTH/PNY4515UVUhDZz3lCVdSQK9OfGlMxI8VRAZ/e8C" ..
	"2jVWXwsYqeOzW/Xcsf3zHjMSkFpyVty7iZEjSlRKz10lA1XZ1GK9v7pMArujj/EVsls82lsE3oDD6EGsemaoqawXUPLPwCjSQEDz" ..
	"w9r05t4aDPHm5VubIJIV969zIlXTTI97Gal3TWV9/JBudl5xA0mIm4/aJ+V5CFQJlA0hPzcGt3+20J9MZmBNYj8WjBLCSbDneoEb" ..
	"pIfssGsWsROxepAwKhlRDtg/nFZitv11NZu4PgPe7FNmATNjn/t6iCav7iuyssQi/eRJfMLc0IkiPz39kiZV3mZ0I+UpqII91d+s" ..
	"D1+MPl2uUytCboiMNHNQMv+QmD3N/hgRbXBAqAHlVi5ar2oP2MvchP7YegC/bpc2Lmj1SrSqvCWdBRxPGdQFu2NoIoPdpM0bWxOz" ..
	"x+9ksO3xhgLwxMwNILPhk3+C9H6StFpBG25vRG5tzzDFX2IEzYNbO5VgL0diiIyDtp6K7flJxHv0wbq73ppj3cPxQPfqs0WhLL14" ..
	"xkZhVE7ZoL4NhxqIPUhOIkVZzFo4iSWhhsKY42kXqrMYnrIc+CQzmHmR1bqBoTtVSdZcr5hcSPsojwKEupKlEQ6G+4shjggHUSjv" ..
	"Cl29uEdHy/1yMfxq7PwfZlryJBEicqvUqnP+Sg6zttRwoy/vhPbrQRUbW1cusMjyUcl71P/NgIw/skLyc8iqyjnb1qR/0OW4/6hX" ..
	"EU8cHssiqDMpuTA/ZJmmTl95xl3AzSML3BRIyo0TBBgUky311O3d9dHX1AIbWLSGa0nG4OD729gbOubfgb+cOQHEHf3q0pYHGsdf" ..
	"xM1ckoEpc/FZ7eNhkiDlwdr2GMIH04tblZ+D9pU7ZhqYdJia2CvUytkDwJ2yGpK+FMLfeSoDkkcJeGcekSNxAwWf78Jmq6yVj514" ..
	"76YZtjafxnX60/GlXEZGYLgcZSmMjbLCxZ5GN7h8uo8QVHhy2yWXcqzzxdgfJiIkxg7hssU+P70+OCt4e082AaT1qcFJbJa3I6Cu" ..
	"welYGRYKrwWeOOpT/f7Frg894lUHftUX/Usxrq+x4KeDlw9gqdKel1S2kYZRdnnycJSCI4j1qs0CZj8KE3gzhWJwfrphntv3uQth" ..
	"Pd51IJlPebtJdeao3f5UIBdSvyBNUbVysdkTIBs77yalsBZ6wSTPy0eRfjK91z/G9YnEkMXmHR13BaHMZw15Uqs/zzqzyZQa+bmL" ..
	"GHKf0IpD+kk8z5bSNBeSyL/JTxVfHYlWi0N13I5c0FuxLeOJcA5Vl6JHeqjHUKk/iWPhJDzBoxfjbD4NyBTuXADrJHswPpBbDX5e" ..
	"jsQXuyc+xk+E/N6suRf9+c9p0KDqCqsw8BOc9ok5Y00JbWGDq6mQeC2z3kaIxlb2TvZ3ABiJmGZ6d3TxcJ1EjdUPojUd1jqsy0Al" ..
	"qPXuyi7zCorABt1aJxMHQlCMtgw/xspe7nooVvw3xBNjTqMc2NFHpyExWOfNOF3u8zr9g+9mZbWFAeMMHu80g1VzQYjZiBBFrXTm" ..
	"sJwIqL7WQMtZVzZJwTEXpTIGcusBlXILOCmscU0um40o9XnS1p0kq4KXi58bJOIAT7OOVDoCIZszJQPPkZvFOnwqbpBaMVW0sYX2" ..
	"qSaD5bgJ6DCwrvVFX1JSw3eJaENf6j5iuXnDIdTyd/hszBXYTCvcTuI/14Kkr5UMvbAlc+OKlmLIm5xjwkwdsKcR4+UIloo177Ze" ..
	"fO8knKyBW5ZbQcEfG1oYPYUvn2hx4WN6+nZxx6okgNRATRX8MfSFGUjtmLekId75p9rR+Hu6X8OOMLP0syN4XjlPXQKHw7BQOxhQ" ..
	"D0WpNPHNNcxOcPMaoZJu9KwUAK0ewMir8WlVEeLhhmVOkjya4cQZZf+Foe43CJIiGsg/OtJoL3VIZ7CmAZ5UsD0QR2/xs49aHDfh" ..
	"6CnDQ+AWdVOZp6d7HXyHLt916gpwDBPLL8nPfJztCy0ET3XZotkdohp8xdwKEa6t+7vaL2vtLuuew/6yU1lMzMdJriOzqsCBbkde" ..
	"aAsAnlcRvSNMheA3G7PAtahNm+WmN4xZUwFRuxov5myPgXuVn3NKOdng3q65s41vNthOaH6gKAtMyGIFzsd/xqmcfvQ6Hrs8zTN6" ..
	"rTKR2/YVyx4Yl8NxbSR2ZNCEK3K0bIbHLCvE3NHiYXb+j3Ha0RXjQfzZHI6i8xWk56qlDxpvd1gZCKVKCMqxrwRYEuqGBU2ad3kL" ..
	"SA3uvvDL4glqEHHOpqB2ou2HaqzSnm5sprn40GvIshxFkLVOeaSi1oZMzpG4aRCCV/p2WBzPvqt4yozXCkD920RI/4XIHUov99Pe" ..
	"N3+xRz/8v9sJxitVbBgZjjWHBm/jVmGwxwg8CXR7XzouJc6GKHp10Kso6eN5apC0QqPJcPmCEKiIqbw524+xPhxZiaQQxmH2pXpv" ..
	"O5uJge7YE+oZRNNkh8vWrovntNdMKpDeWz5BOrFHlpWLMiAXvf+ivq6wLdD/gd4WBcorrro4si2b98GtU4HAduxTSFks1P/YZThA" ..
	"YUcVGxs+0xqGfnWkFj/RqFe3ZOipe8iLFkmuTsUkDX+yKEJSge98c4ABA969/mhQdPZgLHguWAq0UQKiz69lYHEh55rbjJEM81JC" ..
	"Bq4vSaRJcBxRW+y7J2OdGluDNto2sLGqKdENx9rOVTwRqFGOvEf4OLYsMt5rN+MhxKyNk09gUkclnXgnV1/10GKzdGNJ+bqfus9I" ..
	"1tJ1krTN3HFgYpIFGQJmmn9qs2FKT/KyQJ5zukDibBIw2ilXIE6hhbiMGEA1vqHslj2s64GiZIyb2MfcfjcenDANCTu46pRJPpRW" ..
	"XOMyBg6SJy65ipFz0nT/wutvh1ydqQnM940HR/qQqllSgYfPdlqC5ioolIkjfWdVAFtoMwp1bpr5z0QdKiccWJzwcG6NaG1XoGOa" ..
	"hxS8HHrtFMcIiqi8A1qHTpVY7Xzorwe7a9I7wF7x9Z7HNQn42CfsHpqkb2o+mCrkqlu1feTOYAsSjA5IF8H0wHCyMJk0VMWwgRsc" ..
	"HQrONccw3MV5+tEZnb1LMppwwcZ5APS6AXzOBF1z3jp4gTHPu5D69I5aB8xROsmOouC30KItPEn/EoY9y4PS6hRx0mAzeD1ckXNG" ..
	"vhTgGZ1R7yAFzSE0xtxyrpiv/u9OoE0Nul4WbZGIMMRH64IrNAPHosMAYkF1cvgXAlnF1LU0U91XyUdbvE/SLO3l4cgLk3aqliFb" ..
	"jmstScRn0D9pCTLr0kbq2j1WElfkmldbPcsPdid0xWEShLjigk05dH0MYQl8h5vTP47fc5R/slygNXKcx+AB6+GCNzyBcDGHZgi+" ..
	"JSWe9SIsBJU0qQwt9JP9sixk51/MUM0mX7kM5OfO/vDyzN9hDzbbID/1d91Z9xx4ahxYKWll2rtqjWpSSFN1417hW/AVAgXI0+nn" ..
	"Qfq1wWfCxhHk/KFprHAQcJrI7ko9bo/1us925g6Z2UUr8mhvGvES9/SglTUSK81tfcA9oKVFDzZbkO/YM5MRPKrkTrOQXQFevwuF" ..
	"U+0THPQnn9fg89OKopFiSyKJADiTvALI3TGTdSKG3rzV33rZTcO47clh5UFBsbi34y+3kCnzh7KXSMtpYJfoKsf3XVcpgR+7ILYB" ..
	"DMc6p+X5BE5avVAGEFn5Jjhl6/BG6oonk7tEerHsRz/h8shjmmGy5e6/iinaTjzwjXeo7CT0h4KwIbSB93K7cMHPwJo5mFdsH9+F" ..
	"LCQfbSmmGduCwVbyroAdf+S1oWGo4f0PtTY9YYa1niDzTuZtrdxM99wLwbVuA/m9e7UcAVljCFzRD65wdMC7PGD2RlOX27yo9bcb" ..
	"uj5e2Usro39yuX86GY9Z5HAOxUG/6t4tBF8/D82uT8GxgdYYf1RPAsegqtNKoflcR8nKS8Eb0GOih2WSwIOo/Ri2KQYkKEYVcaQN" ..
	"LRWDDhysPWqMiu5Bf/7FWIrAFxjCVa1gHb0HkpjqL+MtYEQgZ6PqEk821F6WtOzYwAH4L1vL3sRwBiShtYWtcJ0wTsBROSRfTNp5" ..
	"c/RER3NPhm/7heCi0PTDA/FpV3vOWlQrsw9YqrO2fdl+Eh8Lugr5ws/HmZ0iLtvrupWgnhCbHVprE/Xz0EummQ/mBWKfaZYBNISw" ..
	"bPNNWtughKbDgevFZFu7EVb0UXsiO4Axrq4HSJo1WuUSSEpOkivB6lG0+czly7hqbnID16aEWPttKb0OnXqfxwPAsM1TcX/5ROCu" ..
	"Wi7rBMj+xO2ZCGfx10T9027p704dqH45PpupM4mG/3BUeqpZ7DmG6YrNr0Zfg0eiBEf5NmUn00JaFIwdMGTeL1V1dLxTyhUHqq1R" ..
	"JdbKe7MXspKbmW6WuUNsSCeW0KohthhAuVWewKnvb1O/CGTqf9iJxEgNcMJVuJlsJpt26pdTkCv0i2+cHiW/ISqbaHSwHJxH0JbV" ..
	"lr8m1FujvPBdMJJvchpWlUbq0g3zf9jg0i3VWWpz7pthwCbo5ENVXA8TZdngR/gkDFOBeNlF2XCZaOJzUbN+NG8narvhNlWheMZ4" ..
	"S8droacWDoIpUM3UCFnNabdYEPRp6NYWV+zFj+0f5+zrzf75CWN5WxEePsjK5IpcEugys78pP7fww4HlTaWOTN2HPnGkIb7zr3E1" ..
	"YZZlMSATdNb8Lxz+di93CGZjVjbLB7SytTs=" ..	""

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

-- ===== chay: thu tung key trong MASKED_SEEDS =====
local function tryRun(key)
	if not key or key == "" then return false, "nhap key" end
	for idx, masked in ipairs(MASKED_SEEDS) do
		local seed = unmaskSeed(masked, key)
		local src2
		local ok2, err2 = pcall(function()
			src2 = decryptPayload(PAYLOAD, seed)
		end)
		if ok2 and src2 and #src2 >= 50 then
			local fn, loadErr = (loadstring or load)(src2)
			if fn then
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
