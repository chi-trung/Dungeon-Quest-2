--[[ DQFarm Loader ]]
-- Licensed to: GNURT (1 thiet bi), Gnurt (nhieu)
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

local DQ_ENV = (type(getgenv) == "function" and getgenv()) or _G
DQ_ENV.DQ_LOADER = true

local KEYS = {
	{ seed = 1824018105, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1824534191, exp = 0, plan = 0, hwid = {} }
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
	"vF3Rf2mSmTcukMTIgOsLFxFXxoML4lXtcmgfg4YwmyaSu+uJYE50VZrdf81CzPwAQXF9Z9w7SrGP04LIq+prdAhziKcF2m95TLWZ" ..
	"L9RMwk8p6zMj4CVEAQHOg5QckXdNTVGEkDS1yqMODkXDCgWtmXo8pSi6mMVApq2R9vyzCgDemnch/AUPusr2EkMtZaUsPNTHi//a" ..
	"FitZXbPFuosXRyaabg6c3RafY0WCbsaCiDCVbTk63B0X6BEEBLwg4ogEpv9f3tnKwmKDhjVaq33MoiBEhzWdAfePcOQm4o5CUGl+" ..
	"tz0wvcV98uU5l1KgILugztLQlaXg90o0sc5z5h8l/y26OccGBCkf5pdm3cd4vV7CCr3vcQXChTUxfSU7/2fnIwA4pSbAB7JyPFeA" ..
	"WoHuS41SySfazlD4vSOobfjRqVCLYrF9zHmUq9YQQrEk6WwxkwwEHgO/dhJf4KkzA9CLYP1pAVEGkf0kcwpPBJsRtzAH8YoTP1Dr" ..
	"iPrKFD0SJ0aP/rZN9x4SKXPQYy+45lj2oK1guEP5FjdJ8QTzE5CxSmk59oc/jDPXchUxMS2lUunwM1fVU8lt1GBWzbEtg5SLqKzk" ..
	"11D5nythoDaC2vNQyat0avLYazA7/M1+ymO6LUtu4fylNiK1sJvSf0oy0toYzbs1n0E3lwZ4Z6N2qkLGNb23V0/heXMefixnpFOf" ..
	"ElrsZJYhvDt1aRFEHSseqawH3BCbYaQ6g327HWZoMiFlxnXXy/NhcKnmgTqFUlUKr+VYuOxlk56EpkxzQazBalAanEj8nLNGpvs/" ..
	"ovm+tcBziUhYSxg/acDYzsv6WQXwX47OaDpHj5nnmgpqiJwzAw1ZQyKuwyDZs+KSvi9xatKTH/JI80BA9rK1dJhsipfPNwCN6gNw" ..
	"Ar75R3xT/y5qfCcU+B1U4aB/JAW3PPcOdLlRLk7w+hecow7HW7mAwPWNC53NebsruQxuT2RPHSytbPThZIcVHQehx17btrv9rvM7" ..
	"sb2+SPzIi9+bSCYX13J6whKwM4nvCQLEmMagsNf+2e88okfA3tO1QDhhJyWpN5So6GeQmhL0CcP0e+mg6G+0cl1zUVZ4PVdFi3Rv" ..
	"iEFU2mgIC6vZMj7yobXsAEXN3ZMS6bKCY1aeikzkDVBnoMrtL32lKU7IgGvfLTbJE1jyTHYpzXu59K46xmj8hSODO1KsIDmybPZq" ..
	"oCXem4g6gZ/u5WioDc5ma1dq3Qvs8riebQwZ9GQ3w2wnqYStIXLQ/QaffrndEfXX9m58EVzBKZ/hmTXiwJWhZPmw/hlZ9BX/HByl" ..
	"Y5hXkkIAeBJoM+44Ex5w2saYqrMUi1NmfHDebKrlmo6DnTEEXw+xBDYwrpIDI6gcCOFsLtsmfqG4WGDH2extJPvIBz6T5ZaRe4Os" ..
	"IXwgp8X3LidiARh4kBb7Dl0Dwimq8uhbSwwWJMt/RI9ZXZVfbwOJlJoXEpwCY6UozKHW6PJhRbzZM/4KaAHvUCOGFrk8wt0xgqIj" ..
	"7X+FnQmCAji9wuhGF5scwIO8v0bKWqdo53/uPsFsGsJLRDuAjc1FCZ5+w4mZdAQ6elfqbv8YCaclvNHsUDK7tgThSoDgbGrL74yV" ..
	"IIFW3GEKzwrvM0p8yx6cE+XDUBiMLWAfpp9rST/EHgxAtW3KclqdiZkEFRGJks8/M4nr3UsAX18hXL4ZpYs5ep10wCeQ14dtZ3yO" ..
	"hufzp1vkg5FZgMfZ7b8VRg+EVSPRrUg7InGfQkv7LvMC9rRD2jPsZoaDqAIQBoPjX0X9wI8Bv8cE9agzRex9f/LgIOfxugb/+mgl" ..
	"vs4Y1n9aVu6ng34yqCNEzQb9Jds/wP+qikrKVdH34IwzNjdWzdQEUOAKKDts7xgFx1yNtgtzPTrDscPbDbIpg2n1u2dOwhA3ubGc" ..
	"A2cuFXBSNpkYJ3neo1/YyEySbcpXDzMbSNvvsDB3HE5O87M7Csb8fYiyqR10A9fpOL5vg1uaEJEn/7RSJi3+w+bUNUTAb2iiE83d" ..
	"Nxu+6G/AW3PQqFmGAg02+dcXBlwi0tI4r8jpw10kumHdIGj7YTgJtoUTuZCQAx5h9sq3/m3P1dR3L25WckHigPb5dKA3VociK4+n" ..
	"t+YP74tEVLuUpHfLtK3FmGQcgb2+dL/Sfp7lWRVaeZ/ShADu5yUzl1qJwjNdIozcPTAUjf/mRyFq5TgYz/9RB+KI1X2JYT0/EXWf" ..
	"7jfDpdlgyLtcyo9gb2wUiDYwJKi5kX65R+duEqjgO8XJSpO2LGMBGwC3c2pVjWwAOoQXWJ/wjl8qOToHNatBWNez2Hm/GBmk8hCL" ..
	"Tka340BLEnzI5uahNiozNopuTmSCjOs65WMf98JT5BmzoLFWNy8FEGWlOJOvkvVz/BdBlbNrAXW5jnzWPGiCttc64wk0K8fi+XS5" ..
	"SsvdlRylar0y2VEa1q6P31eL4j3Ap/7pqSEZ0vu1C5SVmhllIm3InpZ/wyZ0h0pWtI3Y7s8FG3IJmZuCuJwMBSfJoLDnYciInZ+Q" ..
	"CfNGfIFbIIeW8kpRY18Cb5QmCxNEXK8Frz5QjWknCIzgXtr8vHlDj7rzDVO6unPiHbUlU4N2amCKYtlwdBZavYmefk6c69tEiSlb" ..
	"o9wrE6ZW1j6O1d64CKJNJXZvkaxXuQP5auMxDppNNiE4ofROD25waC8sd8OBvwGNsxM/89qOB+UY907VHl3bV3Qm9UqT+LjCtgv4" ..
	"CAT/kNlgzPZ0JyKMwrjuOWmcvPxwyMa1mApPuk8WwBF1+ZdwEyVsXo+YFKgxnm67NuJCAo7DdXddffXb7I8BM4NLXQlBr7G1Um+P" ..
	"54ZRCR/v1PFxStDcrL1taQIHsoJ+qDsugUXp9qIqt7PlQsAWR9In3b8O5HAYeHvAc7U+FagabmZD60GGOmxz8Fg8fmVY50b9Jx8N" ..
	"UXlZFvS+pt/3jlyVzqP3n5cGAwOdi+NwQw1CpfNmUDI+AHyrbZZqncFP+tyVPGj9QgY9DKonseldiaJC7mGT43XioO1/vBGxOfLy" ..
	"uMMbgvl+BUIbrfAUdZNrwVystS0MzAI2I4MNNuoedTc74RivXJj7c+w77Mq2sqFNYR7kZkzwji5j9CKrdFq1hEyZUuYtsvPI0ID/" ..
	"XsMACkm8KNx4bIKYAbx+OnyDxJXGe/NxuNHJJC4tcLZDu6XLtXIVX0agpVQQPrvY3xKAzIkNgWZWrYHElNCdVHRg2KJqknCgzHFS" ..
	"Mf8KRvgkYw4B1NiNA8de/PeZ2uhjdVGENs55bEoP5K/4da5olVHp3+aRVXYPJQXjIbW3/p451r0k1wmI7DizF1Jm+XAtkE2XuMLJ" ..
	"qO9HWMqzfSvUNB9LpCra/z2kJytpx9gv90JS+6+On8KCPUWnfCn4444tYwvAYA7wYd01ENPrp+n6d9CwhRXqHWqPHygfrsHY9+NW" ..
	"jSm0etF/gBx9+oDTOWY6fZlvA7ScaTFoncVC8+QDS82OdZqphKCU9bYbIxKBUFyTgNoM38IzUcR2LqG1YEvtzCacobv/9PUosqTC" ..
	"xjkaEgtTvW6CUT/KoErohLKAJCGWAy3w1yXz945BjgojsTuiEQoRxIrwogyaKhHbcmm1X0CsgPG6SkUk1x/PTCa4blMIqqCrQ4wx" ..
	"Ztpn98oKyErmBJ6P5P7xSP61uS8QkjK8vmHqTPFkkB++k3CnnqJFGSd9+2WB6m7XOebqBKTORoBLszsiMY7Q00VNcoi4fyqHcoa5" ..
	"ST+6t3OL+0iizOXEV8BOBA+KmK6iKMgHg67vj46z9glx8pf19G0z+kFpRSZhFSbFzu68rEKqK6Fv0LWt9wtQUuaQd909QXz+dRLT" ..
	"n0+n5ucKt3ioqewAKPkorAe8qfT5qYHtsNwMtzOrPN6U2muOPGQLCqShyDm1kOmhgdtvCcBBo9wTlF/oFIjK8gg0YrLa4E6YIBG3" ..
	"brj9bbEQCPQkmVJzhIUjGTcZhY/CxeF0QExw6NkjDbGi/MRjHclfAohzZV2w0Qp7hA+0DnSwsT3rzSqm6pEUQ6Oh1dRmB6Z6G+82" ..
	"ILjVU69OO5uR9paSiRpBPm8yEtR+b6JhdHkUM+gsjnN5jMiEcIP4i5rfRuHMdxleISKbKfxny26Y0KDvF+xuHhimjsl+8fN8UFIr" ..
	"smgXh4hTyMLk9MOJbBJ1oyo/B2x4VrHQWgKiyNhB09VESjEkcwGNv3XI6vQ2poUNyHqj5zZe35j/K6phFpE0bYxQq6fYrzZvzn+W" ..
	"J0PVHX4OvSO2aSXXbskU1artgjS47+O5bzHkjVXWqPZmQ9Jjx/y7FKS4xqTmUccqyXnC+Xl3e8BR9WunR+UG990jP2lxV/mBbaPt" ..
	"xBEk+ArLT8VCOLi0hJcSMsl5JqdjYTLpWAHm1C8HCbBIGELPXdYE6+bLmdYxHc2KZJYAUxkOsSJBZqKEY7eS0Ek7GmNIjqx33E2l" ..
	"EKJtzbhrtomzo7rrZC+m1Oi59X86EedmT0OWXRjRHXo6+PWgc2mrWQmeqE0Rxp/fjetU0mR7znmPWxj4m5XOwjsAg6+cBShrHp+6" ..
	"kFBkSv3aiwJwPW/8CqZSdHegHdj97Diyj3/eLyCGqCILjTDMPMkDaHOmS0/HFopEHdJ50QcmV5TkIp8mg+pLJCxY0TDCbVvuGx1e" ..
	"KqKDukNu+ZeeMTrghxfMYijKjLq7Rxi7n/PVpuD372Eyipzx0BVNY4svjWf3T23hcDc082FOaun8oJRaC02tIwV4GVBR3iXiaNXA" ..
	"5YpKosmwhJxbCVGGEKVPW1a9quOQvlYnID2pt635+LPSFeuE1dmrPJF2JsBZca+mBPiWzn/0TFSViJdYkDRY/DZXLsVy+TG+LITu" ..
	"EjqqZyo/59Ce1pQJrpnzK+mRguaCOWzSFWJGE4d7S6zraethuBsVcoQMlaYcKZ+1SjCm+ZuYEf84PN1EXCc4L5Rp7hJ0KvB0Ni8n" ..
	"OVvwg1KW1sLfBxVi51qkLJDK2bE3br7jtrxwLYyBPOb8n7jhYJTJDkWX0h0JluElBnOlt0YvRcgIAZrmVbKBTBofrTy2ozvSk+Kq" ..
	"vM/DBj5rwpwwl9SRL/bPUVpvtosj7wffWT8euU/e0L3FCsU4eVRAYAw3T7mlh0CzsFjmKQHFBNkDqtO5vWJ6SWxZ0l6WFfeQrjYR" ..
	"I7NWzVwlwdWSjx9wI4pVI2NtnxJpBBeV6xEAFUxBpbDatUilXTTu4y7H/6adkdC5IurPvgAura8o7C/lKQ5IP1zbw7mNUyvbUL9B" ..
	"1zwliJJ8tlQYcpnSwCWSrCGSnktJscVaTNMB3WA7a/H122MjFjBWfu7garvpqFVJQrRZ0XkD3+XQJh6Bv6JomA30Aj239yLOkBET" ..
	"sZmT1TSX92uWWgpfBzuw7vvQR+RzoQ2BaS1od/jAQi+D7eMXnRcXpR92FFFd4bz0Es14cZvi/fa8bDT9RUbDckl7AWMI62Yk57r3" ..
	"ofx/s2X27KEHMUJglEPN82BVEtBWB9yi2BsaMNZZ/m3yufKFdU3DSEyPKI0tgIWg3brDqi5vI7CEOKInKCrmFlr0CijpZsQiVNIb" ..
	"azRu55lUoIsP3VxYueLoFPCOhdwuoleac+3+3WHNomCJ99v74OWu3LbVExLx4vwgcYvU/czgknCj0AaEs4VuPqG+9NFIjuUabFk2" ..
	"OPcJF9YpX3GxNjWFkRCfUgFxi4w0enoJZziioE4oLCCEgro0jRaTb2jKWtA6i2gnjpxi0xFkiCbzhcUdiEyHMogqNWJtayzr0pwq" ..
	"xYoCO8lFvK2IXlAqhCGd4u5dm88VZRDBphXOJW/SO8sRFRcOyqFTacRNxOaMCFRBXJc5flvXKKZxyE7cQCO+ayIrimKSavqC2p0G" ..
	"UU6sWQRa3hwy4CEGUfiB4lDzBZpZXhhVJRRtwD7n6VMMbvxnN3nKJn/wIqez07ZAKelBuBIpc8BnmrfDz1fhVYi6vFUINiGauyea" ..
	"4WpkCj95ymOZBufA9ttCXI/2MUH/KRhz8X/FZWsGFgAnt+dSsBCrftxuwDfir9ZFeZxBiIBZpRsPEYE/nWbTZ++2F3zhqHRYadVG" ..
	""
local PAYLOAD_P2 =
	"Jcu9ug+Z9mP7JqO6OsCxEb5Ec5YURNOQM7lGu8fbMwj+3ofALOt7Il4a6dQlPQGWrtSDTB/qwivhfifEK/9tU/WzdFOnWTW+OaTr" ..
	"EzEl5O4JxLWn5D2WAdGhfdE6z2CsES89OrEira9FIv/Ueg9QGQBTFp1+ok9Bq/H/tVOxz1bnYrRBC/4CMHLq4XgwlP8ceXFuAr78" ..
	"mYylyZzClSEiBMFQ3TSkeclTkXCi2EmeinobJaYhnnVQLTLk/BX2JJGPrTpvRnEPyMUY0OB17Q8Em7lwSyeYlbWpTNyt1D5Sm4c+" ..
	"soY7zNLLleUVaaOrCNQLiaUpRtSmjCttNK9obxJg5fBeEa2HRe6+6dhYf4aZlDe/nIQE1foW35wXI0BqwrADfqIgqQk0aoqDPVBT" ..
	"W8FKBzDEqIz51Em5vMHrTBB7FCiYXx7zoQNCCOV6x5ERzEf36yTBf0PLcKYri/SxvLHITDngxjrYSCuTlkLBasUyjvRlYbW16vS+" ..
	"sMjU3pyN3+7+X/6HkptrxEmzws6RtiWViXqc9kldwWJINgoZY8bLM/ej2qIvFgkzatzaS0zpyKYW4wm4XACgDdc+cSRqlqEVOOZ7" ..
	"9O4dT7cH3tmq4cxJgYHs7E9ILWuA56dnUlNjqyh+REiamxqbmJQj+kL3aUO0jKoWiWCFWe57k0H9E0ZfHZpbZtctgPWu26bvjgW0" ..
	"3CJhH0AJBFI6JT/wz5uWbholLWc2YOOJJD9PazRjY8MjoKiQ1mJtHrL1w1jWlFUhSoPTewKkMKX+KNpQZkKT2Wx2yHuEjN9TWVMM" ..
	"CxJBg7KGN44/Ek/JlrzGsgnxgsmBQx5XYhGxRE+WGZZ07kSFeWw67yVRpDtDWjpxzREBg7Dt5iLYgkfmIIfsP8Z0+NknttnkUnUg" ..
	"g/N19OGjyOwPqTd4X1Q7T52kTLgfr+j8ufdq0zIdoG1mSjDaylIdsMnFUcyfDFumQXvzwD1dA80Aw13aN8rdhnJYIY2CY6iHubxE" ..
	"2wwmQO3TuWtHXDwaA/HXr55O6R4JFrQeadAZTXZEGJOVMSNrnFXNKLM7rdOzDJSntAVSe3U2dDtHxVV5zlkvJxXj0cOhk0+yDDRQ" ..
	"rTjxs4m3KNC6QeL3XhNvqhZHD9B3w3sXNGZRvHfEHfEA8dcfJobS0M23sZ6DwXDSUyTj4rOH5VsiDA3daE51v9T0rhkQpULggFRw" ..
	"HYlhrZyCMQAht0q7OfRXrx+hQlsCLFmLQSYl0F7FB6DIQ65v9MPYKSv8iY8niOfVdluoO8DmREnVVFeN5B9lNFHOQI9N6SnK9nNd" ..
	"uXRan4jDGcWFxPGa1Ext7JFULKTbBLUwN513QDkwfMORjVLcyhxUJ6Z78PYG1paD1lxK+JAqDm50sqPRXKmrhPF7tHHeXubORY5Z" ..
	"DH+lVAhQLKI7g0BQY7zpEwogxJRlpI8pY7SKcjshoVmB6HQjGKe7dTwVzl8lLdso0GW5gK4A/kxjoq1+Q0o9QXO3WMbZxlcQPnkz" ..
	"qIetHLnaBdHtBFM8k0d/EgunT62r8ehRScE4l/Fu6rXxEZGn1vWXFG6xAtohHRMGShMtyhGW+r5eSnWGAaGDi6TtZrjIhQXMBLqR" ..
	"iO3FVYnwKODwgnZEAg890PNhlMKdX3AE0fLq7orwnuoJkPYk7QFliDXSt4Tgomvos35cvXNlv86eDHCVxqIPaOnhfeCynu/f8ZWQ" ..
	"MtzMYrQaMo4r20QJw0rKxDKYHmbSRzqEZSbRwYq5VUDjUTmSC0R+ONuwlzCMkI1WxdyqE3CRSZB+iH6ZTpXHM0UlvfYA+MyPmC9l" ..
	"KlY96+p8XkVBhPzs+qiGRpRpnrp3yvB4aqXMDly2NNPjSdNEHm8CUdM+f0WFfoI3o2UaIjN8rkKxPcyk6ipGbxw+CaB6H2oWEQ0h" ..
	"BKDb+AnJGLWgFz434sLkldBn7NPFoO/Nmh93GkBshBtT+n9SqsoPIyaAUW6hsC5Sae3HJKc4DQx9fruXoO5/pnWpD4CSzjBrjCoG" ..
	"c86OHQ2sU2y2SHDmROEZn2gTb8sSjQJcGOC4/76M1VrIPo7oUemaBFk1L+gBsdeyq3GGbDr7lsFv0YKyAjj9zzHSArZr+MbJegTs" ..
	"vZV1vNkMFsGUz7xeRLfuPUnGh3kdhDFfSF7aq6xngiYjo+bmpwnHF2BlZDF8AuIN5UgS7gIoBZqUdebKLC0OsLTVN4om+p5VHWep" ..
	"qs2XShSS78RsH1x23qflGHwE08ITNWJ7eXaZ/04FpD3megEo1GobWLEhsoI8t0/UOcVc9H2tBSgfO3vUiOEqNpUJoHC8AfI0yCro" ..
	"rnMRPw0630JSX0L1Z+x5nvSZCQsh6jCVvwB1Zaw8L1jE7bQHTa6dkZsAqwyD36gaPn9xrZqCp+yrw8KyHuY5HXej92o18phLWsdS" ..
	"KVwPSs32wqNQgw3aiG5ZpJO0eTybRil4SfW5D69TokHgZW9HDYAI3AaxcR0529yiEIol4L7KBMpVEF50qvWqzq2nxpxQDhgrNK4k" ..
	"D/XfIyyl2TfQ1gSs4KsPu7mm91Q37YfPUJNTP/Po5VIALz2beIYraL62l16kJEzaL1bFcI4YQb1vevksN4RCNExmugCCZ/PZWQxe" ..
	"qCfKOHhltmF0R5bGNwRJ7WFNPk1O/oG+4EuQi+q14VNKfMgGr4y/D389I6TQm1mbplGv4Y+j1XlRWptfzbQ9EHfh48oZCXIkB65D" ..
	"w3YYZ1iY79EtV7p6qbBARb2kK4aHdnkr0CG7Cuw+vE68p1c/CsbsUakiPwysJi8HfZmaM/DowffRYmJ1sGtVgQ6pTlC85jVgkQ6k" ..
	"Kt8JjHe4tcTxwly8zjD1/DUOzlywkZqMeYsQtRIwMg2WzTRn8ulghrUXsyZhErme9lSa4F+zxF+iuEXzTwtD99V9fvuDfe3tEZV3" ..
	"+OnnNUwFnkHsf7ojlqljQbmWkRkfOo70h2J5TECzHLEt5GwuX4hlWOorwO/yF2yqpFp6ns4KM7aOhlq2ia1HEroWYDqt/srSVW1Z" ..
	"RBNmoeYLzcCzpCJQl4bEhQKIdwRnB6oz6mwL4sVoPFvJ5YwpfoO8GTqPr/V/uJLuN7VmtTlFC3OI2CH5i55K7doGCNrNGs3dXF81" ..
	"zG1nTwNjRuJidaaCEl1kgzcD3OBPWD3pKHWlk0KdU1dGkK02InoPzAVcEfDxF3AFZ6BRcTpAWU4kD5b/+T2HpZMGxRMGY7pcDkhc" ..
	"hiIiXsKZGPrpoqCE7bL1LvDu2+T72doOKvb0RdtRAOxJTG7VEya3IMZlZpHLuPUM36XrotolgTUa6r4pKCld/BSW3g+H4rCSDDYg" ..
	"c/dOvpVqoGBzIu6KkmZgdu78sq0QoZjs33NqUsOEEVOOtvdGPJuo5ZSgVpxPbS5+6F3AJJe3yhRWGyGlkJKI3wbVxaq4c2lN0gpb" ..
	"ffv1r5B+Mpac3lzkyWAOF4bKE+Lx8Dd2KBj1qko6Sc6Pc3wEvj2lmg6Nfy4MEYue1FbhFpdub9voyc9055+F96LNjdmQPa9GNNf7" ..
	"Y9IWFa8yepp+hUDatJqnPToiZs/kG21UM7b9/oy5c6MfGIyRQATpeH/oNqP6I6GiPtP9nbE7CIkQMo+fBtHSY04ZU+75UdRwYEIj" ..
	"YirAzrfoaf7hmJHohsMpkx141NU5m8wh1BbuhTzZ7LHYjSX/akl/j5Vb6gA2eZ03hBnZbPytvmahzdTbz+dtZM47uUwAHxjlB2vU" ..
	"KyalM7hO68Rf5Vkw6VqHdRdIZuhzkpxeVY2meo78SJPROR4npNH9SgROgUcXvZlB5ggsAQ9XV7vH3wW7BSmktKRWKXFCp87ObBWN" ..
	"NzDJTfmovhEZ6o5axVGg24Z2BHdwYCmJX5XHW+bhLhMjreycXNd5C0Iy3VAn1ZPraKfp/ocU61ul+tCtO2qNzAn+kg+qPBtpBDXz" ..
	"eiFxhl2x/aTLiDRO7m7BFk+1NyiijUAzOhPS0NGnp3UIoEM7yV1mgpx+cGnxHLuVj9p5hsRaY84zW6iv00EkAZswI3SKplr8icoU" ..
	"6Wkz/5v/OcUbbteEQadc6x4bmILzJ3+BieZQLU7999y9BR23U7K3e5Es+ffPmAUBpjwYtDfvtJO2wlorvmmcKX/ZsFgkgz6Vk1P1" ..
	"EwvufMmY6ThiTaAqSiwL+pYsiT3uyR/lbfBzGAf9E+inBbkSTi9StrZRn5qenHPYRFnHE5FD/KXl7kpmzICIzhYGbgXtBRQjaYbS" ..
	"jObnhfXj2OnEiBa3WtDUHVVFbs1CqetR9BSz3bMrgA1BxzajeZnHVz1Jmjrd6BXT5WoHhyJjZDaFydHLXYxYS/acbZjKsOxjCvqH" ..
	"P1WZBetdBDwDSGkrJEfSI+B8OcVHGqwHDkVWZ4IVTQQy/TyVj4MrqvHeko/5AjS9TYejw7wi6h1B4V9ZVi/3I0N1CIldYmvEBiVm" ..
	"5KH5VPxQGrGzjoHDarbCr66F65Fs0YOR6bWrEL0nKeVuvKXxSmsziwKCw2Cjjp1K/l7dI42FZzeleBHBWqPLXJOCK67Nq/crlGsU" ..
	"RByiSEdRp/mqK4fZ2odJYnnakXliJ/tsmHuUVq9r2j+mcqvx3xpnLKXYIkayEDJZgSbIELHc61cqjH95hFDcTNGZBb7IkWXKQy5X" ..
	"jQLFymEJNZlnIqReoduy0F+iaKQ8KBiZr4OE14vnFiaPTF34PEuEjU/DrCjLkQ7kLHo1kycbFPiqlOpfBvjdc5IpBbtV0bHvTcBb" ..
	"9YlIKz8nCHy8w5FeCNBiLnBrzBfiVxV9fvH8w9eMjlpYVlWRMZJg3FXEBBr4FH31aZurcK7IEDht2cl5bmhpIxHX3Y2mG0llkDqb" ..
	"a4sYQgbu1xqalISAmNKKZr5uWvv6SKPJOWpu+Td3NQ6ZMIH5yvS+FoHOKY35YgdYXM1BNLIfTgRABSlEHa7FMP+l/7iR5t4W1Ix5" ..
	"N5JORKpxq0kzNzxBlqvEbdkgH5fw43dUd1AMt/6BXonjl0TMH/OA/miZNPCXznXAj8DjZ69Re5SQ2+yO39vN+7VBkn39nfhP1ktn" ..
	"XmKMo6fpsfPNs5GScU8DFGpR1mt6golG4kHJIlPPod8IkulnHMcjrVh9/4OtigQFMg7SWbcXYpFbqQsW3BKB9WKwBm2zr3RuxVec" ..
	"RP+rotNcQz0LkFR6vaLq8ZAfvZQWpgWRMiiDCYmmgRR5ZNQcZkDPy5Uu9H8b4suFqzeaDCkabozbM+TBxxtj6A6KdN2DLRLPQcwG" ..
	"rqSNJ7fig5ocVr89Luf62B0e4zeMzGkv+jE+FNMTQt3o8NgxSGn+uW1ZNQjuDr8m70EQ4GWjipzOzvsEW3MyJpJhJNhL/JnUq+MZ" ..
	"z12WQTXWT3RV4T9e6Vy17YhUUuOeMfmfb65yUH2sgNVLiAL4R+bHu6PTL5S76q3JHIGfqQw/k2IpH2ZzH9M7Kcwf5SQcx6+v3Ucr" ..
	"cCjKRyqP1oYNL5VZjqMDg02G67gthjB78PglvM01/cI2DGOziX2pvX9MKoECQLEVqfOdHM6Z1mKR0K8Eg5NFDW0kdpx/7lJtlae4" ..
	"x3o35XneNkQQr7OmN2CZIzAT0sqXK8IKhl5a/0XzpGRN5lpG0JCc9w5hfwjlnVCHvtZOL9mJf02Nkrin/kZ2kJ0iBJLempOA35EB" ..
	"3C+UqBYBC0jxUjUIJQnhTpaRU01hriDGRhbc8tehoGlEVS45avcKmytrg9ratAns7H3G7BerqHI5tqtZjTgdn2wBh2bgAbgaFwIc" ..
	"gb92nyNTsfgqyd+u/8ozXdTsPVSaDUbBZXNwu+Qv1i7WtIoQtNmIslPI2S7jiR6scOqAz0WnBsFSr4Jxtt7WtgKr535LzeYiNCSM" ..
	"u021XDN1iwzAnjP0eTpL7O+WMm51dbkYmiNDKZfDqSfkuDdDFbjmV4cq/zdu80Bb0yCcghVbun9+47EUryDlMHdALWR8iMMh5w0w" ..
	"BKHCqNHshI0NG4wDMXCvd4SyidSNcDIgNAfJU1D8HPR41ZBaZdrX3nX1jvinZG3HoluXDBhmOuOOauBZbaKAe28hVoNGsVwSyHC0" ..
	""
local PAYLOAD_P3 =
	"a6SWiMEpVE0Y+D/lB43q4oSCxQyohGj7itma/p9hKeTqBdF257c3LdgKMmh/cslqBVMkCLVVsmX28hevAODGtt9WO9JAWmt2ADcE" ..
	"ErDTWsbr93/z5MYDyxN/yY4yFLNeY9oYMmdV7ORhxWV0U9LzYuZ7NiOVEmm4b/MzM6uAVyUiH8GE+mtp6vFZZQej7rQ+z1j2Zlws" ..
	"WBTjs6GOyw5E/zyHoyiNTZ46X8ENBC8XrW8xljR8Oy40eRFM2rt4oR35CbwTXIFJsyPub/tw0KcMpeaQTHVxjHrX/ZXDEOVCX4te" ..
	"8r6FoBkh8SOsNI64mV6q84KZJoa4ZCWUwbT99og7chWfATUC4xHpUE1R8LhxfMgs9TWEw+t1cdhdV1zCjulp1SX12b3/pDCj/5ez" ..
	"lpdXkb3tJboTPMyZcwxRot11T29nqRgQS76v+nmN3+TcVYIgF16eAADXhYPgrHpbl+Wo7e1ZG6/ytzl2XMqN3NaLzMGVMzsobxEx" ..
	"fLbuPjkI6R29SY1xRo/xQznyLCNjEItDtiGMfI2jTA2Bt1zBEVn7odsrScp7jxCNiZMu6CE5osE0DZUxKIkj9atomGly2iGrJkYn" ..
	"ZGpv5Ua96ftKxc46KJZQun6oyTj1ac6ByI2tAW7optNLJB5k6oWIfWxeKcSaammhTMS0JbnZhXnlYQznRKUczkevrLKYlNMpSoI7" ..
	"3ZD4JGGVgU6N7XxUVYCOysQG6ULXmw9/AL2zz2ST+8gHV9YQU8u9dTOqIHHX6JeWS4hnO5m0nunFK0w/ARrBE7wMeAqqWrpyTsos" ..
	"GDIFVErkgWNmhILbSEYmLYgwoXLIGD6Dm4g7KCYzhjoXXGOe+UO8nmehz1Yi2dk6sTQ4CbDuc2rli2UzGVmZNI6BmaMHDsVdTu2a" ..
	"b2zIIbp9bIQQsmVpLet9/q8dMCfzXuoSw0SKewErZmeL03twPxY6EUF0cpKme44inQPq4lVyOPUSkotfsb0xcgNqRd5gBE9uCtCq" ..
	"kWQKnQn39juoVohytOEP5iQ8U6pk2T8VNYdwfy0MyrapCI7dr/6dzkQokQPcT3O/tMMwj4+59PeqHkbMASlqNKFJLzrmREU/DjGU" ..
	"40Efiv6XPlQ26zIhV/DXU1KWDMeYVC67DX6JDSPJb6UCUyveV27qSsk3+cnJ5RJvMiNB6H1pX8vEHnmE6+bdGzhaSXfAZcBP4XLt" ..
	"JinZx2lB+GTwrzhAvvlO5qu0b9hSsq+RYAdMNPOweWxS0R7IycKOrxuRJ4ZT4ao8Nyl3/zxfkmpGVdOkyvEqeTQG1KQeOIYTF/VH" ..
	"Yb4RjsOeT5F6CXKqHvqrMi3HGEam4XG4FTYW7NcBoJ8WTsnaF8ZvwqM8FWosD9xkgzln2ngVurcTqMfAuZxBYloYT9Y//jCNjL4Z" ..
	"YPgi9Dz0NXhv7+cGbd3wVZJLu6LgU3gKSPiUBA39lu2LCJQO8ifDGCPD8/w6VWKDI3d5k3zrgzr597ErUQlsRGOntSSHfy3lnHV4" ..
	"tuwwFwKr6CTONhn4x7AmZCN2WTB9C5YW8IXinS4yH7M/X+b3YV4ab8KNFQ8x7JC57VLhiPdmAX/kLKQiiOaICXKZjv1sqnuH7xgK" ..
	"5LEikfkRbkXkA0jP0nky2QFPI7EC2ullP7K7QL6RNVwHkedchrGa53paeriAlgMTQfa4wzxqIchod2VgH2fD9jxG0yTdeP82HOeE" ..
	"XQG3kbxmJaAm/uB/MZeTNkTTG47Xm77UiZRLK/20eisVd7ZV2ty7u5ryAJJ3w02MuTGG40oQD9YEUdW2wwSgPtLbUrq6nP9B/Fa4" ..
	"skbL234VgimtoaMb1ECkoVqJHX1BuNWkGQkWAPIojPw+vMSA7ldGlq7wvjxmGE62zu/xlWSpvG36uMZ8Q4NEUsq4Rp0rRquGLQIm" ..
	"sYJYPf1821ImVBOwaJ0w8wsBQ4ydQ0QyYYvcDKqufcwNfwrT8PppLxDXlfpzeKRJHFGU0RsxGaho1SXEkjL5Ub3c4ffnTw6ABQLU" ..
	"110QD4k0mIIzSdnzwdALGMO2dEqnXTqPjQKOFZ3ZdoZB9L092nRJxMJLQ6xULoq0mOF70FZ/nuY0i35IxFw6KeOtP1xtsZVGTZAH" ..
	"cOJaf+GIIu1KOKvaFY0nQwjQG8xw2Be9fcYDEAg5wr3OYi7ZlhKdWPkTHCz6REfcpdDhum3lQ+b6GZ6pdfBxO7SMAMhlE1LDHrX2" ..
	"dBto/KSo98O+9Cv/q5vdbfqV0GRNQY0tN+G5bJk7ezDbM/Uo6+GC8tB+m1BavlXB/ZCi3wRsSasL4LGW9+srAqA99IHErvrT5bJq" ..
	"0zrbU+f6vkjW2sSFKVKyQhpWn9b+CMD1AzpY8mjICwjcutm6IasEfNYb4CXvZk7qpPsjIXfkz2LQUcJZ8gYR3+qugs+GZIJ1cJk8" ..
	"61B5MCCNJgnrk8tSHtv+0xwbDadrBpwfxuEND598oRcH+W7+YmCblcqs6SUL0zu6tK+jYHEL0P0GCv3rWzvJTcf5EkzypARAdXNx" ..
	"mQlA2K0kb1UYg4AMYjAPiuFAWwbGbmCRZqYTlW1TgWAPJGenZt2C3PmXiK17OeOyrim87atXetNBRlFXaqExyFEqlo5JKFAwGtn7" ..
	"0rVkeq0icHZmNuhv2cZlSLWfq16yeETeIgPuMFhuunsa53XTj8cgjs5F4Eqbs35bMyAGOvKAifMV9O6huQ9yD4aNaiDgV52npKd2" ..
	"qWcJTMkTrSpWPHpubBZGMJu7V1+Nbz1ZQat8OlJ8tzXbt0kUdnrVD0m8s+WkxZaaCduE6JpOrlhdcueBI/uef/7D7DvBe0RQDOj6" ..
	"qxQGaPKY/Z913PjWn+7cn5MxQnRfnhMSASKeGLMbr/I0vu6MfHbZKqHvnpguRjwAarnizD69daoo8pPHuJ8ZvifmvDh/sBmwL9Pa" ..
	"gtFTAnGbDva+EN4vPY0BfnICkI8RiSTOBIcBYoJBnsKvOq4684sI4eAcd4DBAYINHDi2aZ4Y6GA3V6XE4mT8XUNDxDnILkezcYq3" ..
	"uZfDLr4GjGkeuDvrPuQIUfyTObLPP7DXUaMK9HIPCX1Kghv+KVfnvsnwL0MtzU8uqlGvDlccCg3ocnS8U1cuDq4mIQWmyrziEw7R" ..
	"nf6PwfH6DGUupuLHH9E+e0zoZxiuBZSL4yEMAsqU2dx+DGGsIlHXUuYpIZng4w9JONGLx7FzpT1Wt4VScu5N34whD3G8J5g4RpYC" ..
	"DFuNI/YUYS4q3ZI5P8S69h9r2dvIM9xHV+tVyMbUT+xpMR48+ItIoUhMlr8/X4bR95WGBEpqQVCmdqc0dth1Mlrt0d8/y8RrbrEh" ..
	"RncZ/x7LT1lu/r5dI3dbP3J0y+wA11lFKqOEzH0ait5PQ18JrUN8SMT8cgYSeNODceKvJpQSeWJNI4i0nQ6fC3Pp9DlR0hD1AOyz" ..
	"4Ya5mz0dF7C+B64x4yC7Tan8NWnZp3nIm6I2qGzJlGvqEOKp38PIH5iFzQglUrAduHTCN1eZ/TiR8J83vBZW7TnOlmzMP6+iQ/x+" ..
	"Eu+3sev4/zyV6ZcrtfDOZCX/Ni6zKu6D+8MTS6TKuyD2fzUPn+FYxxoYGOk/61qBu92htn/8Kd3qd1tA2FXham98As7V2nYInAGx" ..
	"Zv0Xmybb17ObmHKftGlBAuVOFMYorlaN3SEDfrcyEsVp0yNeN5CwwooquZt0HVvGaFymglPusyp92em05BoT15Bym74DR3uoVMJr" ..
	"NALlmbne7825terkNepIhDHUeeIui3qKFj8toBm35dB29NnaClL7O5t2aaVSkhXpmWwMqI4in7DEzMfJ6jm5T0AMKM5qGjB47uyD" ..
	"dMoDbHqkg9Q9wGa8gLolmqkwhcKwI9IWuLCtNcX2bPdXaNNjHF3eMMPK14PLcNcoine9Qaxyg/w9SmDAUdanQeTSpm5wioH1JCi1" ..
	"rK9cycA5v/yqav/qTOwNmTuEGomIY2BJS3rdd0rGXgIHCZbVEyJvpTyjuMVcsD1+UwAEtr8qGGnylLPjQez/k7xnWDHId/MyRXMe" ..
	"BkIBe71KoIkrRVhLtNpYkswxstXQ43MtZ3HsQ+60DolHxnEdq/JTS7CA67e34Lu9rVt6G2jBTsYVk2nFbFHfQ3yI4mtZym6XvKqe" ..
	"hObLWfEi0TpMqdEmiQw1CbWJCXrD21fxJz9iAcKn8XhS/1VwSjTqshnlzMPqnsAv/a2aBNMxi9q2fdaIiR63C1CWIUZepccK0QtV" ..
	"MAgk5ujNykDcmTdTKgp9fJFnw5HlM5/hboxjEDXGHRqj5ypBaGdVoOFzQU9zQrHhWwU5nWIarD9mQVPAFLbr0F2d0J91yHCw1m7R" ..
	"pfXyckTGAY51RTnlIus6gUpFIype5nS22+W7zX7b0s+bBW7AkQ3839mHPKWf6dUC4ou9r5ipDwx0YbnW0srSh4chrbiLxm2Uh6iO" ..
	"0tgqTqKjTqOlkaLzPX3Rc6XSzWL67O5ljOQPDOVkfQiePoWunpYksEc+rwPROiRD9hqsW+SBMAxY+vkWumePLCJyMJalQclB81u2" ..
	"huANkBzkJj/goYGxh/5ia7zQM4fY5nsI8tLz7Ep2oDp1YK7Nbublw9Ldxljt7NHJRCQInvjxpncDRgqmLpV4Zo3WOXn/g0KC2G8T" ..
	"gTMvkg5E3S8bgods1JoMVU04FIOz6GxQimUBOYke6+tSAYp+2rKHP9xZUx4+JFObg+snnfmAu62Q8UXPXhNS5zJyiUzp6gM4Ml4a" ..
	"CI26UsmOWVjp5KlcxIKt+VjHmX9YcKtWuPTVDeimGE7EwFxm0ifoekHiuQAg4+5/HJRS8B13ivxrdbNEogMeRX9oUSNQ2qoIchy2" ..
	"zYgWjhxG+TZagfMXWwkxVV6mXTg8HM2L4VXxFGq5QsgEZMhD4H2zmNohaZiq37BYg1G1I1jNDxmjmEkXPFIrs5fTJcU0F/0DwHf9" ..
	"g9NB2P6zXnRMoOlEARPUtnfz6crrdTnrM77g+Mgnkq4AFRYYYclFNuQym5Kc2dRmU8GruQ4LcSjyY2ntxM9KBGDJJTbI/e4eKbIg" ..
	"f9KdIz74K6xNKnsr72x6/PFP/Iwp2YIcdWHFy1V3pE9ieqMpC3HWNO+tQ0x3go1+JJmue/Ajw/dpXM0mFwkWAx7AQHs4lhGhVhRp" ..
	"vsDPRZ//d2ixWMRYIbsA4LHfRxB87jFPySnrXjCfwpkB+LqlpJEwmXD+Zpp3ouiyMsUm8J9RDkjjWI57yEq0zFLelbNX+W3pZ333" ..
	"0XmfgzpaRtZlBUYY8vTj5TSxegn9EWXLCVCeaWD1msCajT/7YSKq2ZODl5qi0gx7ZZSpER/9JMfRuy2wKYIkvnzftWLAUuVGPgYl" ..
	"mcK6kSeWTzym83Gh+2C/a9jqAo0zTI27eXLQBCVUWAvZGGIHpfC4+STxdzWmm+1AO5z26ap+qCidP2DvaO/N+A+6cacOZZC93yhh" ..
	"m4zSSe/SVoO/NxDk0i5WRjprLE8EY6I5wvYuEE71xAjvolPDEY6FNHTKP9bJB1RZCkMnZZczUafwnoCqUt5leF0s4HGZx213w3Zl" ..
	"/AwaNx9emz22G7lbySly2WRDj/1ZqlCgkUPK6Ti2YZlNkiTKACtGVJ3AUcJCc48r2HfroKigMsR3ZR7D0VSS3SYniRZF7kd1kzAB" ..
	"zrR5JN7reJL7FxadgJyaOC5CkS5em8u9nHb5/Fa14ZoJwYoZpKgc75akuLCAnzeEnAq8Arh5yXShDqGx2gJPkX4ZODo6ShJewMhZ" ..
	"1fKj2FqAReR4dJQhMoMW1GqQo2EzVMpN5WJ4Vkb3emqnqC2Fraoq6XaCnkd9lYM9yfK8f6YvuC7CnCPRln26CUS2bRfcEBDv0qTT" ..
	"vlhbKxMyOyhLFMkfaujRoZq4CyJmZ1raxd07lc7zfAuGHdqKCf7gXhT+FyLXUcCoFC9L8GX6lr5VaVNH47m+4zOQYb9p43Kz3WX2" ..
	"Whvv8h7i1XL2mAqswxw1SxOdScwPgcRhra7kxB4urqGep/rBgKLfbXLBUZhnO+gw8Kpq1BPMELgS9j12EU/DaNF278OEMjCnYNZy" ..
	""
local PAYLOAD_P4 =
	"qoFl6lJKPT+CKn1S19ZoZQm4DrF+ThM64l32oMHy3j+FaINSp41lsAxkIkFT9DILbSEaYs54Fdt28/HvWfVagEAyp1kziP3N218M" ..
	"mGARrHdqFXcVCmOwS+2jf2cNJs5gPmI6ELtf2RJzccKjskTauQZWmeyRIAYQdqx82l1ieRRlt867yJwgYrbRWPRfKsraTlQR5w/Q" ..
	"igndwVpvjSyRDIWXRLot8SWmh8CXnSAF5ZoupDbmrpYDD8wqyNy4m+sIEOsUe3C6MhSmTY6lU6+CVJGQfc/6ksLAMZa7WCqDglqe" ..
	"9/6dutCTVSpyWRsgpw5v64h8ib+x7NxAkAsRlNsLbD5nCFv3Wa12Yu3Y7CN3E+4qHm3uLqcsVUObnC9ZbJmphWKzJcFwmuQrFb5a" ..
	"rcy6H7dFG2AaHmMFZE6xfqhRQmSg13XDmkjA67B3u8QUGNFAQql8F/4OIsiUgnk96YSZUq4BwOiSaKkrq/VXJq1ub4Tq1ZoBql1x" ..
	"p4RCLaOuFPyBvk08dkaHjC7QThssC4ToSwAPL3cECG6pPkZy8CpHcdntfzvOdrOKTlkxGgjZBdkw7nHJOdjcMJNfyW9Kqlu1IG08" ..
	"OltVj01BAzsVCyB0Ij06HS+2SmZFY5HETDQPSTMo55Chz5AZTyKL2JdcRl8KRtl1j29653pLbU2HZaTQw+NH30clLk4QaARkghG3" ..
	"225pOIrQdDj/pfXcb1qtdBSyosv9Ct0JRthLK4CXuLmiVM/+GMM7RlSHiqTCt2uVuToRoVlg1JtxvvkLRQFKwiyLhW6QdQL7ETGl" ..
	"GC9YhLb2Ljf+rBy7nkhs40+Pl/FZEBKT8SSAJVa0z37FYyu/Db3LsNnH7gfJEsSkJ8mxj1H176a6ym7T+QHgKvCpZZ8y40fAKhfk" ..
	"7rD6e8I5kT5PuysqWiVIZ3H39XtNabiEYSOS3I3c9q7DuWqHT484K7RD5eVBydb8cd9ZPajSi+SEACYRMFtspCJ6+pB05Jo1m/KS" ..
	"br6Yg0efnAsl/qXxMUwHVywxyvQ4iDvLM8IxmlN3pujgr6MpJL5+Zu1qz2YxHVKvwD6JuX3yrGvpR+D1mvNZKiwMYjZbcVnMaZXe" ..
	"3fl/C2serBD6dexxrAlbfUYWdR1SDHmWx27A6Q44BjMPLD7D/5p4lExp6IbyrzuFropMyjnd6bpVhwC72CsZ7hjm0wRiJngDbDbn" ..
	"14wTunAVcEr237CqLEm98cjFoTIyPDk4HePNRxjzfG5V5Wt86CH2qAX4OIZD/uUrDxvql8URCAxu9+CD0f7imzX1w/n8J+waFs/R" ..
	"YJ0OEEf2WgeFvcv01xjoStlgsqN3/fbywvO3jYyLhPG+7K/YKMKCQvK8UyUcwdd2i11ScVvkcbNkfpswTIuJH4KlnGS1ZFNdtYPU" ..
	"ClDOK76ZzZwbzXZnJP1dAaFeuq46OwfF0K9SQRFw2HxWVywtutRNtSyR+gx4tYCgrvgbeESf+3AJjVfr5O6UEm2bGj42TPQcnKoK" ..
	"amTq8koLsTN4BrkoNZAhM3gisHiQuyi9iDomWU1G8GRjxw9kOTDKS3M1osEasPOi04QJYRYjCjKhMjE46nX7NVgMwHer3MAHv3X6" ..
	"Da5j8p720HYWDeCUttziV2V1PHaBnbLoXa5urvkzoPNy9phn3t6tB1I6UVcrIrjzK1HLqVWr+d3eJzKE/C7mjGMG0ty4cUGH17Ae" ..
	"+KOhYbdZ3mJUjXdprfT4kTk1g6GiZfVP48tby99wzJJGYXAn71j+fpa/gozdsyNoiazyGgKvQ3RygZXCEEfyDuIy99M/hxser6WR" ..
	"MdyhyckXK7tpL9AgScndlddp4cLfYWKdB2P9onBPVb/UL41DWM70pXuJtEfoYmqEKL0N94KCk+bh/+WN1R2mlknEjSuQdFEusiUm" ..
	"ttwNca36TzLwWN81TeNWnEu8WwdM6Ic/gBt8rJiZZH50528XPplvNmHyqe1dyM2chn1Q4rkLHbI+VYAPS7AsG81dyOAt4iHHZeob" ..
	"jbVnx7E+UXUjY98Jlnj8Bh3/feCzWkvSDKD0yFAgvpyZ5ERRly5iGHRH/0hDtAg7b8TaZoyxHG/OeY7duVO/n6Du44BT3Lp8Qmg0" ..
	"gCJ7oLceRRKgdukLddtQcT4Z5981BWV32ZDLWHYhL0H+nQyg2CqqGsifSesHcMCYM/C/OsuuasH8cHO8Pq1Tm/DKEgf619CIT6Ms" ..
	"Hqk357lbmtuBSlXYuhtM/phD/bAuaEl6EcsgVhWDAzgJHRWbP6Qr3pnHA++i6ye3EBRGtS8cnSigC5tzEcy3cYwxdKU/Jz6XTBJa" ..
	"gvOv4UywygJ1PJmGPyfgtEPR2lIxZHLZ1DrqKUGhwWlYFyi+ZxfiW9TcGtYIrELYLY1GMEGgr24p1dXFJ14fzMm8u89QY0NRK2nh" ..
	"SyL2yC81G1755wySb1eqIin+ez63VqIPO4BqPdhToOOIE2RqiC/VhVwtyMmKIRE5dzw/077f3YthDrzh6frEmNsgQtRyL5taGkDs" ..
	"SBCcp4lkBnvW7hJuuwA+OZitugGeMVHZ92JW4LHbpSRUywVTPdisagJcWaY4HZgAKw1AMQuVsfTdKU2LXA2eNsGgOTAxGZoNXGGQ" ..
	"/4mnJOWkhIsny/CsH3g2oK0ur8jYjGckQ4BYhWG5FRRDqzohc5gCppbSX1jN/J0HY7ftJDKZQuf+PL51HdC5L7JrNNqdk9zDaZLU" ..
	"/KWBms5SG2AQ7hkB85ZbzLhjoDAmRG+ZS4yFfKz0wXkiNdnR0u6TjI964vfKIZdr0fcgLzT8/joqYmO+eXNmxDWF/txbEQPerJY7" ..
	"4JionmV6DVEcsRYVES4Sk1kdUunCurtvdYoOhI383mIIQfW2LyOl34FeL4xAIqsIyIMo3ZjY1RAiLT62QrbdPk84qfu24wbbecK5" ..
	"/Sm9lWPogPqa3irPnC1d3PAQwigtJp9J1KocTzbELLiQsbpMOoydlVqoq/0PtJwS65bfTT4LvYpWT/sLWPTtgn9sKZnKQJnJHnmx" ..
	"KaJlnnh7x+jj8A68ofvSD0q4vbY/PEyyKCmZUrW/eMIgZY5GD+lFY+AaPxWMzXht9hxL6/69V7cViTbY+70UipwVk26X+icTGHmT" ..
	"H2TMxqkFbA0uH1GM7TBMDzaVkKtS3ey7ZqtoWrrXjmZrdPHLsdFFfjSXtHil7shfo3NJF/4nZHicboWft7Lx7/+324s63agp0ftv" ..
	"2nUnmreR0pvMEqHlDHeFCFQW1P0GF9rMEpBrnQY+F1RucNNTEGjHE6Q39J7qAdT2waiL3ZQHKggasYp3i09bzsxKj04SXBceeltI" ..
	"doCoIo9GrBUN70hNRw/tso65iiYrLzTd7AEXtloaohoPT12vHkehU+ppA2reKFsIs91cpmZPRkgqCjAX8Oa1NdoEbsi1v3soPc+F" ..
	"jGxRPuWGvwYcac5cXX59oeSDJvnj3jEhX5TzXchRPC+xWoq+qsNSiVX/4nmbWOQXZaWU2rdcfNwJHm3FTtNlbrnk+dbgpGkMz4wj" ..
	"eSf7YAi5pedh87IgKMy2lhv01MLOSZxpkF6oxPFoofgEr90GK4hY+1pR+yFF5B64Q8kXfbtCChA1l8jc3GjzxsPX2gLTK5gUv/Fq" ..
	"enF4fD02xNiJBWWWbAceYVXRlJboNAjXACo5ywWJ/d+TTXx/1QCo+6OA5nryFJYB7GGRo1FsZq/eIW+wOZc1wKPzKHQ1ubtPSMGa" ..
	"4ohISkZRIgkVIji/jvIeDeefWrEbnubvkkPbymUNQbAJ9oodZDdurM5VuBA35CJloLwV8wndnuysHI+HpCnDa7C+dO/LiJ6Yghfd" ..
	"hg9djZufNcp/Ed0ilKC+1+mxs1q+f/v8jN7dEzxZZg1ssKdCATfiwkqJKFEURdAxtcTJgXmJjIKPPNBzSpaArNfEiNI1XOgAG+Zq" ..
	"WDGvHhu5X1ZhePOvhlSzjV/3EuilMQH5hfoqht/9+dXkDUXrh0mLUfT7yOBmFkPYuoRDYSoBxEJm3zAyBqOWct4ijQlf64ii02r+" ..
	"N+prlL9km0tNU8mA86SatHJvTOYofLMvA1HlUjaQ9xxItsXHjeE+kXlTTHDlUr2c2e26QkcMe5gcX7NoA0JeuwPWCaGNHBfWDyVb" ..
	"k7st32CSZv2BlctY7yG4n5/rCS54o+sNQGuByox1/s4o74MsphLcyaVEfK7R0MR11k/C9YitgBPXBHKqFmFWMyBtEEfOSy/ZSpcC" ..
	"eAs5Qpyft8TYxYxHuob8DJWbU8CG88gF+Nat4qDeYSuCwbK+PwAjCIdPObrmVxSoX9HlURgjGaxgmOJxzs44vT7V4+jkL8i4kW93" ..
	"zwkJzTYYSkogm4JJ+Afq8ogd6WplXh8DJSVOrN2zDbigYJY8U4+T/w0iC0dt0l92ddlchvH+b2vbGFF7wIAEcxxy7zg0KwWbyP16" ..
	"Bxt7Y2/pICL5HDo9rdqpDBDXTIyiE6jJ0S19nY916+kRwjQ5t5WNq+e+Sd24aE1zRiCkZkyV2Z9krkujoSzBYnavhzUgiCYBHRo1" ..
	"GQBAeSkJxWeyUbWlTC5oElNV6aD63kzJpJvdoVjoL2SDmXS5/sxQ2m0/c2ikCUerzjn8FQv5o49lopUe7m5jiUXVeDMUzH+kx/0G" ..
	"LQJBQoQ9cy1b1gyhC44OfqGt+0l1ofKACDFBc770M1kBaGVcI5cbuIHTzXWQmuBS3Knqc4HEy9iyA65Gkl5wQC+x67PEih0x/VYO" ..
	"RaTc82/l1VkmSwyNFzKlOw3C7dR5F96YKWlkLOvpiMTAWU+oeBh4TDjz+KH3cNUQVs6LtRWXNJv/Jv4kmPzDTg7VX1qjKbyGR0og" ..
	"7ZW2rHNpKKrvNoHEiqPoXNDwJuIpJn+HYZYUz13NqtbUCjID8uCZUngsR6xJb/Q+b5y+9fsZRxz4b/u2RVPpk7K2CxAx/ZuySr2w" ..
	"wsJzy2hoAwnkKDgKnvVbOGcBE2YE7TKALBNgAQY4+PliXM1XpaXkEQhiIVIcaeZXiS/KG9Zl/dFOlKX1QnA5OEgJ+1XOq2qUEg6Q" ..
	"gpekRQt44YT9uxF0+ZmLO6d0XI0hTO98G2/ABeQ481Dpw//h3GKbW/dgVSH6FXFIy1ee8dTlEBt2zrwfoZQU0xEUWYXMNwurmWtJ" ..
	"BBHRpSiXZFRvNrHTAGFU9HFtUQ7QWSdloA/zTTgk8UR4id2WPeARYb1k0HawlAgikyZyJ2sisXQtzrDMlK8xJR8/Fs97GwLE7Cgp" ..
	"DGE40AMIbfAr6hYBOdUpVERnED5Khbx5GRzsWB9yebwBw0AD/38mhB197VpTTzDnZ97fgXI5j5meuhBu/txhWiWHSv9W1g6BH0lD" ..
	"INwGnojzfDdpSA8raDYTALOaclOpJ0aMKTZl7wzku0BQvhVIN4zDLkJ1BElOtyWTOkk/uyec0ywB3kxp4J4psmDktirgPC3Obs/z" ..
	"Ziui6yFcnvT0E+bA/fyWqUQjWH5uGf1jjQv/6IRRqnrCTg1CJtgM8B4/iZ+ZSs8HhKWy9dFzUOdKls+2xmzOjjUiI4zff0cc538L" ..
	"Yl28ENULEW/YcsRPLChf53fiftYdvOK6S1I8g2SAL+9F3eMXRpt7zzkA7bLqI8zQn+oynQgpARDQwkP2I698Nik5g6ttH8388h7k" ..
	"AYKJIeMkWe4tWgXIuUCB6+8HXO7+/s08/Hcq3U9NY66LS/G03Gk8Ebj4212FbwXsY57vbvzwPIYIzA5XIq6gqd2fUWBZ23ZQ2l7f" ..
	"pnJQfhqbpUgjUHb1yxbqzeiyfInjFHwgqzlkcX8FzajBGq1QYHO3T3O+oQI2l6LKZ9eg7VYHvV8y0rHwUNNccSaGYjJ3tYHUqXq4" ..
	"RaOlhNocUEqYev2JPhHuRqrg85CFq91H2gT2N53ziCkYCbf/m7B2LN0AmJn0rniXjym1X4F+sCdmUuhiA53adboJJ7OAok1UI/p4" ..
	"a2tBZhdY/NhIf2hTPSs7Ax41IAvXNpKnJVaoUGacfLVU+ajsKwErqEfBWgt1fPwa5YHYocepXorFFm1aAgqLzM/Bqinz5DE4+dHv" ..
	""
local PAYLOAD_P5 =
	"yT44sITKsGAAkjv+mDIsZeFJysXfIUR0kyAhOauzRwx5Ih8mNKkjiHaz1XWYM64FK/JGToXemra7cvAHy3TcGq+RpwuqpFU1HXkO" ..
	"MW1UyYlKttKKUN8Qy9M0P2w6e1TRosah3mTTTi70eru616jyz9PLHe8TWtq2RFBs/7fiSES4WB241zoymDvQYb4fGxDcR5j9NV6P" ..
	"Ef+PNr1GdBmLOUY6bc2XcaUvxYRBanW1aQG5GO259K/EO8V4/U83BEsuOEIn+MOi1g3UWuNWi/4/JabJD9IbLaaWkw+AzJ+lMxKW" ..
	"LVha1TkLoHxmxqK4MnJokfPXQJtbYQn6UkTniCchW230XrIT6XjT313EKHPrIMUIoe6MkMbXgPhPE9oNc0GXAvHARCI0C2SPqO+p" ..
	"iLPPpQ86dBYjtG8swHG7Ujkln1FoZnQBeU+tJZvB5qAUGIhwihd6cQ1ICJdTTbg0ZH8Eo4g0VB1PK/1gMvelCL4fKONa/ybVuorA" ..
	"anTg7UisPSR+XWb9Gau5nMqafSakzUbLKIkEc9WMluT7V5jqDXS5/jWlGcCsc+n1Uqc857tqodgIjYpVWhROnyry68F0B490bHWs" ..
	"AS2z6whxicnE/vOnkG94B2KQo3OfqdPdi9zuHH0iKYhTPnksrvAAfDGWAyD8XamT5ndMkkyn4HOiXab4tEL12+cip+CBTEs+e8Hw" ..
	"FQObiS3be/ACLIeyJA1/xMzKSnPTXeJBEeY1GBYalYzWka8cgIkNOCP0jXOzG0NcbkeARrxKHdCyCP0TgL7dldQjh74k62mdo947" ..
	"VDJVCTJC/i1gmoNMwVIuWhzEy6C4m8hYqQmq74rCuqSgsEiwrcuRS+ZQcHzbkK/9w9YKPuTyEye5vdMLM2BwVwK5yKEN7afyrbcT" ..
	"AvVPEV4HWitPHbSteTqVuy7VRcUyarHLT+yeMbm2Xry0cPamT1pJbu/Dbl5abe5rXq5XV6GTS53pjO8ps5Wm87xUBlNAHjujXdsz" ..
	"uwR1LEUSDrnSH38ZFH9CYa8WVKx9cwQBy9RIdnIcBAC9pxb2bz4KiHeXKxL+BSvsaIB57NjbXRwWemEUjN8ryhgcrKg+th7HIuqj" ..
	"8k+zpDrnuFY6K1yXkov007EUss4Oi2ctd3MEuQA344OrlYJ4PHr7Hgd35kZmIYsh3iybezXlQbgmaxOeWHL4cc7qMMpiWXapsy44" ..
	"TSUC97Z19Hbq6y1jtIPb6jGzGuCfKYTFoAHeKc+0O1ukWnsmbaOX+QvsA0Az+QoUQ1aMqbGypD7PMQUwiJ0h2odQQWQopzRkhaTN" ..
	"864CzmSK3Eww9n8ZT4RjH8HeO/axxfzymhSvOiLsrMrXbuxPX4pMX7tgL7xh2E9+RdyFLxDE8kRtveuXjEk2YAfYTlG5zRmJjguM" ..
	"15OnV4bDRXimcw9la9+dYblBeY7XATbfnpY7YeV/Ns4EMgFoup6Z+Ey9tgaY7NFoRwXsQzBgXfTD/AV/94E773fWD5HYiatU4TpH" ..
	"k8qWVcNVyMERybW2efc/vsI88SoY9/uA8WdRThN3eMkadEcUSV7nYm2ZPWyKmmm88fbN0DOqxGrpzxDbDlLGOJA/ur7yKpqSQRMT" ..
	"Qib/1FKqLTUUAevIN67OPvFQZ/7yHjYWfUoT3WA1hE3oP54iqYJD9igLvF/sHiFuuT+CkFnRXQ4RMXiVZueXMXEwEKzfHLprH2Mq" ..
	"dkibacBk7Nbb0QHubrv/gwXPZey1dtUzBNUSQkvxKi6kteEuwUl5XVq+jiaNBGcqpx7TrAP4ZrofYp8PrCmbtKQ1p+I/rkAqtwtm" ..
	"sfl5C98k9zOGsWOnPYKw3gx8jLRp3izmXWwVSXAVp5NE2KknG1JOCKSb4pH+ML6eW8lrfPiz1gJK+S8CBb8//QRB/EMQuJzME5QB" ..
	"Cy+P+37q/+PJ5l/+RyJgnF59cQHghidV5jhWyr5Q/53rVbHCAXQls49Z4Vv5cCKxMAyXJqXB31yWNOVQGFiXG6WDmvzwQCPG29/6" ..
	"U+jwouoJ48ipmRIc40bWnGpvL5OQQ/lL59kUdyN1DIB/beY6+XkMHSesOJdECzdZkLEiSZR1rjOGQnfDdZyOOvTMdNqMd4luNI64" ..
	"TsfhtbZ08Yey+uRDRjddtYCUH11rP/9/0npE36LmUEkSQbj1W1gnGi4kHNdVWAy1cfztNCXdR1hDMaEJ//Irwgk8+JIu1g4ONMtS" ..
	"UY81ngmJ9tf2/B7bONCA6lq8nd059OrUTAs4jjQ1tAp3oWONLVGqvPmg7cSIgGXz/3gig9Idua6sCAUpb6NYewEcvdgIbBo52lrv" ..
	"1AE42cZ0zFH3stlO4fPCl+gifu6mJfYxdD1xDerxUuvCA6HS5lJjd4MRIMEio1ZdRpitzo2RBx1iwud5xJSz6wkLyNwowEvlA8hw" ..
	"4nN4Af1ELSxWbOUxKVzt2lOURcVtgJTa3TMOQLzUtcxxrvvr6+0eAC8Z4/fxnkDuQEFlPXu76OpHTdcPGc36u3oP57xZHPmF/bR2" ..
	"HP7n1rR+EN6aPHMx5eee+VqrAXB/aDA+sHmGrPW+n79xv/HYxZ5l/JnER3b80MU34JbRldIrxd4/U1gpheD53DKd0ihcT2VCwUZU" ..
	"qul2BLsDXtqdzskJeo4qwj9kOu8vmpfMLDEltYKDUJ24/aT11yxRyae+3e1jwRq6o78rOHfWU2qW2kB3/eHb+C3Nm3+I8GmzlAtv" ..
	"z6ZVowp/0cZD44Si1DUqSSFtIgqsgnZ+rrQxafaUUYLmh60jAxFNu4UaC/90h/cJRtQ2WZ/bsWCpS6P8B2CWEemfsNtFAqTSDEqP" ..
	"fFrJX96SFZ1vL8/8m8N1+Xu/32j0xBjJOuQNAXyVj0LsIAFY559YJHLUMs0t1gc9aOdLzggbC3Zf4zaedNfjRQCo8T05eyuzZ2jJ" ..
	"snZmtBFsKdTc2VbH6qIKAW2d/NEeGo4qzFP4QEpNz+Rgbj4MWTxPtlSfIXcLkc5vZbm1dnE7Gh7g4KSYmYRp4FEDX82NSWrMmLdc" ..
	"WLVH0y8Hxwa9PEEoIjEoXYXuiYrsdGqOFW8VHJ4gw1/u8AnmoLP4D31OatM5jTTSNeGpNxg1U7iVfYpuTUI9HOaH/LmX1o3riqHQ" ..
	"VFI/h963uOeqcNt1xW7CxLeNsMPBjwqNZJVU38ipoZUbGOzXwGZ+NBji2rW1Jmm150ZX7OvjcTqjLIKDJmdxR/kFLAS7ncO/GpbF" ..
	"EJ/mBPeyoLm8H5KZT/4Nfm8CW4JbYDuR0E5dpDcnzo4rGtF+PbN6LpwlHpqYCYrvLxLqWtnOPvY1cuBa1fVwN8p1JYuOY3rTdht0" ..
	"K1ZHrkpi0eCc9gC9x4siHBHEgFsUQ9QHaJKqMRc2G0Y61k94N1l01e67GWLqUod0Hz8ul3hdmzN1ecAqjFkvxup0htmfx7GBH/Xm" ..
	"uNWJ0davhpobCNPigYsQ8PzCBmzYY4irjQjEMoOdJw2IvtDHZe/xgjsVx6u6DCDdSQWaZ3UQDRPSzEApAL85bDK3Jy1uDrTyPjA0" ..
	"/G2sKCYdpPp9v2wfyjM8EnT1mBENSXFWENPp3bJHbTDHXW4OVhTKxaXezruqlz/Q0SbyurZzCJnvgjDWJC+WUsOhSVefQHRLecab" ..
	"hQtzCzP97hBCYfQw4Vf/l0JMjFx/SDGkNpF6H1f0exDM18aiNC+UkFsHxIKCi6EVRd9bnMYcwvrvClHCG5qq1hdQjsg62wz2M4KT" ..
	"BLuOzeYTDog23z4VJ7GHGNkVDC5Xv+xOQO2BD5OFoQfeozvffvmcQQDK/j5OXmWKvD9glyIpoLbnh0WaD1yIdaAcY5HIaMn6S0rq" ..
	"+nu7LN9f0RQAV2lRs7ptxb4gxloji1fM/vA53yXmPgI5FXTEadb7oIXnmTEiJoqG2okrm7+EsHjhqrV6aMYK0AOlmanAWe3WiPcP" ..
	"4vAN+aXMw0pW32oKl+OlZZuRTwHYuklmjoUvD+7ix839p0eYtwmngEbEiOUy0XZF2wegwfOBkXK3d7Mh23qvKNDZWd9oG4RbsUt/" ..
	"N1j9hG3MA2zShLf5vauoEQ5DACF4cUntJ5iGFAXDcldqylMgb1lPwUIB9UdXM3RCbyky9as0U89XdMw47ZzpqS2r7yYM2szltiGO" ..
	"d7Yy1F/0fXmb9ysqBiuQrmqOHTYb8eObDp8l/Gq60WSU0fXL3+zNhzyp/Q5tVFCWEimrQTjEW/9EYBBBCe2lcg0D7JabXjsDCkOA" ..
	"UmVEVcosFdY80Yc3vDRhLOXZK10wQ71n4Jor3OvEi6EhC/DA8dBPoTFloEiWbeseh39qBZpL8layt78SOvaZyEWJb+zppas1glm+" ..
	"Uz52ayfLZwNfgCJCxYQm/H+HHs/xESN5CBSzzBtboHh0InxMAgBzLVD47t0F7FyexNPnRpbIwAlXTKqc0x+nNjvlaheiSjwQXe3B" ..
	"SCUi2K6nyBPgpVHeTFpXPGpLQ2SHZoL5YGoMUnTleW++VYS2vNTK5lmFiFNP/3no/4RmokIECYrFHc5erHmzhBbz+PgjiPI0ds/S" ..
	"zVm7XUj2crMuOfB3JipOEQNIV/PTDJ1kYpcnm4GNH/4Eh5BsDZNAC530yBe2bPsoi3hheR5LqltXsVDnL11HwjwfZZafa5h6tUv3" ..
	"StfOoDM3Nhgi1DN4+Jvl/FBYtor98kEls/XJwpn1Hs+ITnYAXxz+QYQizbRLyYJaVEGkkMq9er4oDDmCZOjWB3Zi/IMRIz42JCRt" ..
	"YGSPcX4rJHqp+wwETeSjiR5VXOmFIEeXujPJQARV3s3J+f1jXVaMgAU3XMGhuJgoJBPgjZWm6YU0qFhaVKE0e7auj3ny/DadxY7u" ..
	"/1gdmHYrxAZx0h5BPrHQqe1dfb7EpQKJEwvjmrBCjg9xtp/SfI2tG5bFqnu0uIs7FkqtgTQqxNyvNO3oI+KDAvjAHgYVxW10ZjpR" ..
	"ZRFiTI1s54vGzxrl+isP6qewPoTis4UaxjZSU04Ryhhq51e3sYZGLPmvhLjUiBEpTCM4zidD31cCGTNquRkHzIJdX39zN8ByvoaM" ..
	"p8XTf29Bk2KtU9lqyhPyM1w59IeaFTE/dv4SQBFvTwBXYfPGYeD9yqBswp/Gvni+CYPkwBvalZFzTKWJbk8PieVViku/w07zvFGJ" ..
	"bBf/Ze3T0l5UgATR+lbomvtYdu0Fdln1yMHiftOPgJ2r585atkKdvy5pdDP++hBv8bM5IrJnYr7QPEvZlu+VrRYG28xulRR42mv0" ..
	"X78u6MwoEAkGLNy4IjYygO0bwa5+sk90Sb5i0Ws23Gtxgmb5ILEFVQEmHeuJVVKMDE/iVFNnW69FuWJLgcsLVQaZZyT8JCVeLvax" ..
	"Y1ELb2i0Cpo+MtgzAPw8nMW8u8lpyYZBBst/HEh6C53gGelZqjb0dOJHjC4Ie6C7XCuEghGDxWMPRA0HK/AZbXCYsPw9kmAieWda" ..
	"X7XlI3Dm1JHqnExOxL2i5WPgNlTjT7ZQ6lnRLWGi52RxvL1GkH0NnlJ+2cTfu5nugHQzCplw0mkziTgytjL/Iv+BpNCkxkp7e5jR" ..
	"ZUexqOithclckthzRuWwa3SFM+GXS7GLgOHM1gFqT8x/vB2JTp2nx7ivYbtZYGy9PpCLp31r0S90tzwqaVb6TRp847Y7suvycl6N" ..
	"dS1dHFwN4flgtOEZ8w4Hof1gCBEJ+aPdMStUbStGUFlWKyT5NSugVVuqewp7rznMyshNwO8hde75qXM6Ofb+9yAJ7ifFixcuMEXt" ..
	"XaietgDjV7vCfuNI1Mae3y0nvJXdTO3+vLPeWDGqY0/zXwvMXq+nRJt+xrTiQWT1aH1ZpIU1x5LRqcTRF1O7X4mtGA0wgLrdezo+" ..
	"GSg7d9OVv/gWtyT5Y99i3H4fqDmNFIZ05tLp9bdaxW3L/L6RaeDHRKdourpaGG32hEpd3eJ8a0lhrBaP2OYwytoKS1WE3pxrrzNv" ..
	"rC+hlgCLr/zblXBXTtF47sW85y4MjGAZbrejtXzRb1iHt4HKGL5r7jt5Sdqw4NCSKX3Ujn478LTNrXsRJ7hO96tTxCXSD5WrzZ3B" ..
	""
local PAYLOAD_P6 =
	"p+0GPBP+Dw77GB5yn/xc3a9KsY0DCngwFOGKWa6Az+dRtaxqEmMP/KBm0hfIpd20Hovy6YQO4iIQhxV5vjsjJxQUGPkv5ymRJNpo" ..
	"JhZlf0AeoGag7OOYf3l2BtWXTrFbnYSsa+xWjNFHREOi/zDiTvm5cOs7eqkfbd9/fGtajy/c9ifWSo6RR2OES/8X5UxZ6ZGP/jB0" ..
	"V9wXhskn6jBKFRhQ16LQd3Khz98pqxA8S6y+Pz/MVLoter2H7/dnTIdojl81L90iJEuOteeTOaGbMlFq/SNNSrx55yhztYbwPm4/" ..
	"3IE1jVBZxxnDyte8j4UW+yLxm00dVjMrdy72MREESWW+gPAHWoDi0/zvLOIj9iHp76dnZyPadcVODZiykMd/0AJQJqylJTLQ2MGC" ..
	"Org83q9JVFtAWAnqYiMcgr8OuhL//Q1zRr7Oemoksi4NNW5KBi+YXwYwgu4Fr7y/y08lAPv7zmaUlfiWSflSbW49IvefmGMzeEAS" ..
	"g+M3xYiApO2SqsDkzZoNQ38v1Iu0m54TvYtaYR61CXH7NAoY4PhrCx8jzZD5Y6q+GP3Ka6jQoyptrPKpILKwy/tntAETjcPrvy1p" ..
	"wvNyWgRSsjciIyU43dj7/wEIo0k4g7mKdNc=" ..
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
