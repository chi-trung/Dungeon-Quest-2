--[[ DQFarm Loader ]]
-- Licensed to: GNURT (1 thiet bi), Gnurt (nhieu)
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

local DQ_ENV = (type(getgenv) == "function" and getgenv()) or _G
DQ_ENV.DQ_LOADER = true

-- ===== luu key theo thiet bi: chi nhap lai khi het han / bi thu hoi =====
local KEYFILE = "dqfarm_license.key"
-- writefile/readfile co the nam o global, getgenv, hoac trong bang syn/fluxus
-- (nhieu executor moi chi expose trong getgenv, global khong co)
local function fileFn(name)
	if type(_G[name]) == "function" then return _G[name] end
	if DQ_ENV and type(DQ_ENV[name]) == "function" then return DQ_ENV[name] end
	if type(syn) == "table" and type(syn[name]) == "function" then return syn[name] end
	if type(fluxus) == "table" and type(fluxus[name]) == "function" then return fluxus[name] end
	return nil
end
local _writefile = fileFn("writefile")
local _readfile = fileFn("readfile")
local _isfile = fileFn("isfile")
local _delfile = fileFn("delfile")
local _makefolder = fileFn("makefolder")
local _appendfile = fileFn("appendfile")

-- diagnostic: biet executor co luu key duoc hay khong
local _exeFn = fileFn("getexecutorname")
local _exeName = "?"
if _exeFn then
	local ok, res = pcall(_exeFn)
	if ok and res then _exeName = tostring(res) end
end
if not _writefile then
	print("[DQFarmLoader] WARN: executor (" .. _exeName .. ") khong co file API — key se khong duoc luu, phai nhap moi lan.")
else
	print("[DQFarmLoader] executor=" .. _exeName .. " fileAPI=OK")
end

local function loadSavedKey()
	if _readfile and _isfile then
		local ok, data = pcall(_readfile, KEYFILE)
		if ok and data and data ~= "" then
			return tostring(data):gsub("%s+", "")
		end
	end
	return nil
end
local function saveKey(k)
	if _writefile then
		local ok, err = pcall(function()
			if _makefolder then pcall(_makefolder, "DQFarm") end
			_writefile(KEYFILE, k)
		end)
		if not ok then
			print("[DQFarmLoader] saveKey fail: " .. tostring(err))
		end
	end
end
local function clearKey()
	if _delfile and _isfile then
		pcall(_delfile, KEYFILE)
	end
end

-- ===== teleport persist: menu tu dong hien lai sau khi doi place =====
-- Join/leave dungeon = teleport giua Lobby <-> Level, CoreGui bi rebuild
-- nen menu mat. Giai phap: queue_on_teleport (neu executor co) de chay lai
-- LOADER o place moi. Loader doc key da luu tu file (dqfarm_license.key)
-- nen KHONG can nhap key lai, va loader moi TU ARM lai -> noi chuoi vo tan.
-- Dung string (khong phai function) vi la pattern chuan cua executor,
-- chay an toan trong Lua state moi sau teleport.
local _teleportFn
if type(queue_on_teleport) == "function" then
	_teleportFn = queue_on_teleport
elseif DQ_ENV and type(DQ_ENV.queue_on_teleport) == "function" then
	_teleportFn = DQ_ENV.queue_on_teleport
elseif type(syn) == "table" and type(syn.queue_on_teleport) == "function" then
	_teleportFn = syn.queue_on_teleport
elseif type(fluxus) == "table" and type(fluxus.queue_on_teleport) == "function" then
	_teleportFn = fluxus.queue_on_teleport
end

local function armTeleport()
	if not _teleportFn then
		print("[DQFarmLoader] WARN: executor khong co queue_on_teleport — menu se mat khi doi place (join/leave dungeon).")
		return
	end
	print("[DQFarmLoader] teleport-persist ON — menu tu dong chay lai khi join/leave dungeon")
	-- BOOT string chay o place moi. UU TIEN fetch LOADER tu GitHub: loader se doc
	-- key da luu (khong nhap lai) VA tu armTeleport lai cho lan sau -> noi chuoi
	-- vo han qua moi lan join/leave dungeon. Fallback: doc source da luu local
	-- (chi khi GitHub loi / offline), luc do menu van hien nhung khong tu re-arm.
	-- Chay bang loadstring de an toan trong moi executor.
	_teleportFn([[
local ok, s = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/chi-trung/Dungeon-Quest-2/main/DQFarm_loader.luau")
if (not ok or not s or s == "") then
	local e = (type(getgenv) == "function" and getgenv()) or _G
	local rf = type(e.readfile) == "function" and e.readfile
		or type(readfile) == "function" and readfile
		or type(syn) == "table" and type(syn.readfile) == "function" and syn.readfile
		or type(fluxus) == "table" and type(fluxus.readfile) == "function" and fluxus.readfile
		or nil
	if rf then
		local ok2, d = pcall(rf, "dqfarm_source.luau")
		if ok2 and d then s = d end
	end
end
if s and s ~= "" then
	loadstring(s)()
end
]])
end

local KEYS = {
	{ seed = 82454227, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 76695237, exp = 0, plan = 0, hwid = {} }
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
	"2aJTWjvEKQf9VBXpzPTtgC/fVQPNKKc3uK6bkmepJ1Nl4YnRATlQBCRcvKY/V5xE9C2JBA/p97IFhn72oQZw/d1SQadGohlMOmlq" ..
	"lvzMHvRZy/qIe/vtzLnMYyBjak42Cbp7HX3yNok6IaagNlwZCSqllppRkow+hWBCrOWzJQUbzfD4enfisRd7WwyVPWMyK9ULxkQq" ..
	"PYrElKE4a+JUIMeoZfpBhXpCoUMNIh8W255XR7WXvViao4tu76fl9PXtbnMAonzbv1Uiq52n9qSHw/h5CEzd9EgLEdzw1t217FfV" ..
	"36VanJMQwASv+SAhFXO/WUxrPYgqbGt0fMxKT7XeAJpZ80/Fcqf+e/HcUQcQytpM8opiz/usT1keyySO1IuviKDm10UVrcsNqSQd" ..
	"hoTSg0t1je9EFchhWIm89D45uzO5vaApUm6HARMxZFNbFrVOsRYfaYpjzZLsfMXKp9ggAbR24R3bMEwVpFYJR5x7bnkqQLfF5wjS" ..
	"I4IBFsYULF1XG9gv1dx0ykEdtJKz+udZK0Gs1riakcxEAdAjXQlpgoPWaGNVPhhGZOlx73ox9JOUcaIEqe5PM2Kc4FKcG7p2dBjC" ..
	"/3HCmyyDROVoymLchPxedVRSlEXMU9EGK3zR5VMa4+lSiC3mIG4w8tcAtPBDstJJshR+dQAmPKsifrKWY/G3icDZPekA/Ak1pnCZ" ..
	"gGhS/vUwL7vl+GvyXQ1srJ8GAwKo6cVNT8DlULovrTaOHp7dsfQnokopBf58VsNZZ7kXUAWEESKl+/saCGl4ZZh1Zi7tfm1IdVfX" ..
	"G+dTC90UeTUA6bFxNN5tVANULPP3R9e6FU0Qv4HRiuXxc4apuFT0g8NEEJ57xyQVVhyOSO2s3fp11MO1bSv8oaSuLz4XkK/4IR+s" ..
	"RRX2vOjyxHAVnaOz6se2UNZS0TzoQHnfC6e4m4w/EHIATzWChmpIyWQOyo8q/PV+Dl3REw7DvNJ7ZIflwGpe5OetVYiD93PUfaE3" ..
	"msW2lNlBvwyL1Qs3GgZiliyVXOuxyepgwNwvRR5Txw8aTOPyLfApdmRnRg5nd44XXx2/GmWPBsRpvimLv7lCyJkLxSoBHiY0V7in" ..
	"1z4qMvuiVMyujsxvpR+x8TjT81fwfl8AfwHOyENvwdLbOqXKUwumkMoUaymEnFBFPjtsHVXmvu1/VpdKz7M2tYKRZYXbxMepJ8ny" ..
	"+q9tACTY1at/SzaerzkQ9v0EypCp6Vn+LLQKCi421nnJko+u8UfyaW0oF5EYtV4HvzxFVRv/BiabcjEPAhtFB86ffpBxH8wzOKhl" ..
	"WeXB7/PH8PxljgfGFF+Tq6aMSg4EXw4k2R+wvLHSfQ7sPRtMd7uOL2zByXF75Uc0O+Lv6v8aBBzVBh5D3mtPD4wE9rX6D+XsUx59" ..
	"P0aD0JS9SKIH/EyecEl6hIY8eVrqdCwWTx1lnQw9XZiRUD7f5aTckbz+2ljHlAYl4m7v1/kY4qBcAW/vXZiITXXVeNP0srnN1VAX" ..
	"h11LlNqUrl/3g6ICf/R6/zIaH8/Lp6+B6WPmbeRVSeP5JHKJaZO8G5xC8fYBbxrWcM/Z2wWpsNV+HV9MHHVvZfIQuWA2qC0BTucC" ..
	"75Bx8R/hxZe4yWd+PP0q9CN4Q6mY60MBNv2BQbKX2/qkBRMGcNxFddIQTTc/FbqNdWwiiJuDHFXmI/43X/GVYhMYXbv/C9qtbf94" ..
	"XUVXa/jxAN9v7aqJk5OCFikXZQC0EoCvCOia4Ay0s0LhdW3pZSB+ctU/1Oo11AtvIUGPZOiRclIq/B/KxR79VQsxKHCu5wauRhia" ..
	"k29LDfc/Adb1kxwbiDQVTj7u9xM9GH9v7qPGoCO3tRYUeGrsfs6H1h6G3OB2MXdlU9fCW+jPyQeRKB2UGgQlJB00/C7W0oGnnlK/" ..
	"tuuVeEtS9o17eKCSQ6ObV68C+jOyRIFEHEzaF5QUFHHHzt7eIs7MM2O4qOcTSLxLYVIyhs1MD33leldtdQaZTGUqbS2Meu2omPcl" ..
	"sMorFYgMFlLuxBP2sL8brGNgFkz6+uMhGpijvz9LxOONxeC+5cCadtTgOqdifSRd4xHL0GEerDW+vmb/W4r8f7nIW+grChajuB7k" ..
	"6T48VGNZRt3GR1yj2SO9bMAsWRug/DDud0zAylnb/aAXOnMVauRkkyWi1Fu7osvlSkLXXm4O8DAIF3bPrLFzgSTotzVXqcSYuX3I" ..
	"kVj9NniREGb8KtNiTnPggaeNElpZp2xhwv285HbFrFyJMu65TuxAPo1YjEQTJ70jRUmLNSF/l5m/4fnPazMZNLqzMYkg7on8tuQy" ..
	"3vB9lWvSaeEMpXgLYsttBEwA0AcOD80jCgTgItS0K6+Veq8Lw9zH9zaH9N/2VLJ3nPZnRcPFr1U2hGpzVdPyYOs99gKIJ+W0kY6V" ..
	"1b0TvAZE02N34QiBH+RqWLeXb4tLUFYvYT+MyfJ2h/PE20ivGszisHK2Iuk8SOglQJmVORY/I+YGVyYA3HRdnEC0wuQOR3tJJCc6" ..
	"cKU5tvgt69qAJtZZBiNjNEreNqi7XtNJkvIPrDzWDCxkUdjiaJ6Uq2P5RHdWHS4h6JRdPnaXW28IuH3ZCoKXpj2DdnRsW1ShVHRv" ..
	"+Rh/iFahUanCKHG7Hg+FOBWGsZ6O8zxeF0/kuZjQSMTXwS2qyDUggfzM9RsJaCVMdnyTGuJIyPEfMKX5J97aSgY4Sh+JIiIcYNo/" ..
	"Q8L7+JX0/IeFWjmedRH2KnSA/ecGDN0w6S9JuvUIKX/6gXiQ+C+iqg8Fa3opH4b/PYiiQYndVVBMYRPIIhWhAiRF0JykA/PzsglE" ..
	"+27GT0J+rXPxBjwD3dCRXeolSUQngx1VHTWHw+eTzGFxcFx5a3nXNAPbgVBPTtjSDCNoaQsf5Qo4BVafOQcHkkam2SNORaFgs9ef" ..
	"mrvnd9sz1bE9cphlIpuNKPNZSeCictjzPHnZ5Ld3UhOq+hCdDlXZ2jgn4gs3qMbVaaMB1bKLcCy7WiZ6F+Oi/1zeI5POAtwf6R90" ..
	"s+PXcU7thuDP7gd6vZzYs5VyfCRFvJ3f88C1YnYLnak4E2FLeZUfZVoDpmKlcZZXbzshLEugAWRJiuXNzGh9lB9b4RjASfPymcHL" ..
	"O+9MKvAKoB/kaAj81/ncp3PTOz0i75k6UedZ9CL7L/bVI90JzyYwuOPJcAQDbqo3qfYF/b0IEDYXK0W0fTXd93QHBqk2r07OJsKo" ..
	"JLlPETPvBVzs+kqrO71M9bfP0aq4lBoJHA093qm/9K7NkKTaMnkP64fJzHo3u2Qte4pPCZ5PP5c8S/qVtdAshihrkL/JlHqqtCyN" ..
	"KxvfzH3sRrkKQBX7lK6/7ySfqbviZvyNljvpRxkPyTENZ8AMUqclvplb0pgm8xIzbe5foBxMCIp/IT8KO2jk6WzLGzMTY/JIgHRe" ..
	"Uee+4QP0B0hVGbciBemLP/+uC3al7uXc4xGYZLiQ1w0mT9K3HMb/hvdqMzVVuaQZUczGVbwSlamm25dPBm322dU2dpY3dW48roV3" ..
	"uobQNkWdfm0E1RS+aXMFAXrtEnPr7uLMtizueyDlJZyMEJqRFa2gBIStj+OQUtFehKrEUuYQkEpK1U2B4sclfqeO0dARTPn1CsxH" ..
	"xEhmGLN99t9FkJ2Ny7NNzBqMr07xPcvN+a49tC1BVxuQMu17AXZYdIMvE8BxrXQfhW8N0OgWnXbIhn/bMn36nJcE9IX4aRw+b63R" ..
	"PxAU411Q0rBTS1rLvTqSRpAUJ21nkb8uISNLrOQheaWvYG9bXqQlB0tTY0PEnFVEJO2aJZ8KNcoPnvbYcsYkeE0e4IjyW65bVL+b" ..
	"19Lx0ZRSACmtHMtB3b5jiBOpRchaTb5hFiVszZeoX/4CLM+3F/md8e30xJbvqTdjkoX9JM9OLJ3nQrTpu8WRXN4NAkui/za4fi6r" ..
	"5O/DDXwyOd4u1ChNGHQofEMb5EX/oBeVvgkHXhRAN7NPOM+tWcTmvH7CtJyD44F55t9Wp/oJGwxtnZZ0DxjJSLwUQPJyNsQGprJU" ..
	"HV81Ntzi0VTROjGDeV/DbcBCJp8KTuHBxF4RP+7hOl9M+jwRsHL3BzdpPHBLKPBSnilrawafT5VCZYHbNmhbIdF4nbQhdxOeZmag" ..
	"cys0pNcbFn3iI069d1T2S5GlOf9/b6rmAxok3ZuWcHPPm/dpcPI4KhUVjqBvqpMuwewE3YlAwwgE6E8SjeN97v0Oi+yypRy9RT+h" ..
	"f4KELPlk8tLLcTGhv26CibbsOg4ZxVjhVh0hXpflBsGjqZcHuseYMGN0amgeqEHWWg70fFTSA/7u+s5t0Us/OcU4ri7Q17RlCHuf" ..
	"eR5GYChR0z8oTikJ/fnvM2u4PVNq5eeb0Os2fYpIhAVjC28OX9RVAhwabED+V+6JHqYF6pZ57Ky7t4iV4AjA3YBE7ifJgE9qL6WQ" ..
	"Y2cmrBDrIdEZ6Nr76Uz9bkq+EH1yaXcAfpp/SUa1bX+dj5hevV0LCJfH07R1b4PELUzkUCMwCc4sl0a93zr6vyxgv/4t3crZ1BAC" ..
	"caFbXU37sr1yo1UA7qzoequUZJcRpVutRrnAy39MMTjAVAV4J1uZgR0MYUOhGMYvX8t2evJpuj+4U3a5K0W3uLLjtpMjBtJGH6U2" ..
	"ijq0vD5RflCpi4dMP6vfb9g0CqL9z1fV3O1kVv7fIQ4LhrtR9zfUPS6I9hi6x9QGxTZUzrqXbjTqN20AfemZljAU8YQ/H4RcTRnj" ..
	"OZSlFiL5NI2O89cCcUbNxHFbZgwkrkee0XFcZaMzD1QDjn09XSJRaRio3NQjKzMjrPlzH7qYNDr0QBIeyOMRzEKR/IKxgN0mtkpf" ..
	"ATEonaXEv3eQ8KzQEchSUsyvlb5qrLRz/U9FMyga+EJCDrZnYqfJ8I3CSzz2J53Dyx79k5D/nxPmD4W6WyLf5fMZXkD81ptw6LtC" ..
	"6wmnyZEKi4A1rxnyM5kmQ5jd0QGb8/60OWwxqITCQBVaU+cIxIL0jVcqDkh+OqmTBj20CQ/x+FlHq4hCUUWzvRMtLlxHkZOOSv+A" ..
	"WqtbTLvKwnoljeVbauFpj46YT31hYxns4IU6q8Hw9UlMb4+XkZ7jiCsk4ay4kJxYhPDNT7oZ5/BclaHQFHyZz7dh24rbCKLr8/B5" ..
	"CIqKiPtMvKojG2g1JRID/bCqrCFxiITR76Vyqefgn5SXumjj9VjKS6I3JNZJs7/+duJdWm39L3IvGro0O+iClFGBJJ6pnXC6wUGY" ..
	"a0dK7IUdOq2JavMhDRna+ocm6AEct6XC+AOMzOQ0q8Fohagus+QzPowa/iLVllDjYGhSMW5VtdkxXOCLXkStHfd0K5u2FNJG+KDS" ..
	"6+eb7p07AJrw1ngfE4ASRRDr2pQ5KuZTXDGF9OQtySH1rLH8reB4WXMQZ95exM1b/6r0NlQZ7oRbax5aPm9bAhp4ZcX+r8qidAWj" ..
	"PqFmlQidE3hlLZel7h5Gw/ZnlAnc2JNn59m0T1gsZcFxcOzxc6y/Y4NNu6+9oCfjjH+NurzDImNMfarN3o95FQX5xKG0hJFW32F+" ..
	"8d46ddNsaYNWFAWPMW9bE/6CzXC7kUZaGpmNYZ25hCmdEdh5AyR3VaK/99UJO/KOYXduSF7QsAJNCNVvSilYHeIFyqjaFvjRAuTb" ..
	"5P/gNG4FM78bZtpXA6xYr9MH4pE0o0/cfQXtZDRacjHeMJugS/go4poJUfnLB1itRJrYvLnA4tFAGvN0/bLX6P2ixX6rtCTFnpyP" ..
	"69UIUlXxLSd7ZP8EoaXLdVIsBKRyrK8V2UO2rOezPNge0ItWGUnyiU3VgjeCUUvpNgKFD0gbWbqqqzpyN7hVakHpVtj+qjeupx8+" ..
	"CA+fDECcJbgH8TQ9VnAovhSaWt0zcfqb35WKU9/LP7ZIQ+i394Dla9CSPVKwuGVxucv2P1+uq/76ITnCR94J4/Y6xdiPFwtQTF2f" ..
	"ONwcXesZ+GVogvgshZkzFe0+jmu7j1CrgvCD5Z0f2ZDIVxXnQPGTaf0JK8syFDjdZuzX03UChCsGEDIqhFDMc3J7nC3dOxdZcn3A" ..
	""
local PAYLOAD_P2 =
	"YWy/IUB47mpUnr9i7N/E172D8ECDuqHBhJqmibyfQq1u5bnjbJ1v9/6AV5Mus8HJPOPB2q9IaQwIUk9OfPFtkYEFD+jlu2pafkez" ..
	"Uhh9APJ7frC4CYRlbLRnxteiKQ8Er71QCVx0hfSVNYelNcLzjIThwTF4VcDFrnHroT39SHR19EKCZ09czhipoGznFeXkOV4BPuiS" ..
	"O5odYGDDo8vpb9EQmh/klFogmdyTs2yg7YEXpELxONatH+d+zond0DongOGs36ei7dpC+m84Xk7o5Vs9nAAds1KX+b0NRZBHZKC+" ..
	"nYlnVKdOqRx9SEOjkPgXw6tpCswrAjilgWv94jqxlTIoQQqXpOKmrAf8cH7TDpIq3XmjrqPzBlsD/M8w3bv1Tt9/SE3rLitF03de" ..
	"iMttuuxI9PbSYRAkqZu6wSjv05moUOWCm26YFV9GDeVvnCMnnobe222IwC+dhPM97Ma+ME+shHsJfr5EKArlv3GSSnJdPkYTLGl6" ..
	"Zc/D7pLkvHTngiV8j2cO0Ua2u5vbpr3MfemTgTAZSGoqzQT9+JXb6MI9okhnbwPSHrthCpIcUN4CLjCnAmUhXCuUfxnhi6swJt12" ..
	"AAsG5KjdwdwWfFLJHuT1/p/vXvidcf+u9YVzZYTHDOF4SpFU76YR3+ys0PYvE9T3n1YVGb+QG9eyE/Y+L6wMdulf7JiysmOahSgZ" ..
	"uloHgELR2AWkWq7g4jmYmE2dAcon/pH4AqaUdrlwgB3nnxZwV/ptl8wAN73s8QDwoP6jI3FYGdCEs5fs4U8/DhrZsLTvHMoW2Kqf" ..
	"5JvhdcECpImkHpwawgwPPSGnxTkLvNnIg4w/Js/fLc3TZjVt6jsPOSa7xt6gPauBLgtk9J6hY2VAr11sxVOVxeC0On2r8d7T1RR0" ..
	"si4QPTM2+Bu/xxvA/a2+rjg1mqdMrqehhz3nC77rh+Y/iAqniIm2B5awSWhG7eEnuruB7+vU3XQedGVfCduSb3C/k6ps9qtI5VAF" ..
	"O/BSeSn+v+QA49PFsku84sNa/NIT/pP5jzA2KCVQKHI2UCVExcK9b3HP2CaW8+4auaSp8v+atwaATYnEfEKaz/SLWXwlk8U6LQuN" ..
	"ARODbfBmRUA0GvEhecQkEnRFSB1inpwv2fL2ucxLFR6xWxwHqRrqWLsSoTlx5Qca3gX0mM0wyhhDHQDnbpXkc6d17rc8te1/LURl" ..
	"VLm3u9serHlgIjoglhhsQNcwisxQvcCGW0bC+VyWkuYaTGc+WxFV/cgqbQwPv/LgfLqag2yEdrS3xmTuOMycUsIWm86kKFxOwrIR" ..
	"PdQk/uSKyO9XTAVSod410supGJZp9Qny2182Z7ic45neCvpcDQItBnZRkw9Q4R+rU+g2gBjwnSh7K6TKOZujPf6KkonDm3L88rWi" ..
	"pqw/9oXAza2dXIt1MJG70p02+e/qbwzl9qvQ9pCuUZqAeq/+TmMPN2olu+MPss2kGKR9ZeXHF5M6pnj/zNs6TvDkEOiDGFxKj9Zu" ..
	"TJ3xTLwflb6ov+9FAByDmwNAcGCP/e+h7OeVc6hatR0DSyraqgDbZQj5dPjLLA8yoDuayJAMrMZe17oIxt8YT4P2KNwBtMaP3MZO" ..
	"o1/li4sDeDeYAwpKoEhnhwOZ7COoPCE6gZcYPTZ+bSrXsSx+Gp3vSar+IwEnYY4qu1FEnvq16tMA9CZB+qYgX7dZooX44Ji4iDKx" ..
	"nK/mGzCQ+CKjC6cP8WwVAdw/0qVBpbULiExp0f3YfHyciWq4FxbkLH81FLLv8T7qkyDn09ujTFHFyFa3CAgQZeJIWXQbi9SNFd6k" ..
	"mqGcf/Jw2TV2GYJWow5elvCPzeepSgxLkDVy5T12IRqh7uju1OsP3n8a4aSj66bsGQilUP617bnnqe4ftGg0p20YJ0er/A54QTLp" ..
	"N9ozqnjLzQs/u/psG4aDgsERLnkrVktw+tBnwyKh4M9tMMzlXmX/2ih2c1F/pOE9EnXHWfikF7lehGwxwqZ8768nwaUEP0TakH/t" ..
	"IcA7K1LN7l8BvifL5CoeninG9UOGk93Qe6l4HJKrDPftFydn50uvTDxKMRJtJFzcB0kiRZ+wQGz9cW8ETesALPG7Iq+CTsQQ1qFQ" ..
	"zBgU0n/NRyEqbTIpA5zMDtORIGycTma5iNwBHa7sKQMOPWjLcBhhoVwK2fvmAW+PsI6H0CSuK+2+zUMZDi/USfuhQPHJo2uf4NNC" ..
	"tVBHL0/yTXv477ExIn48zniX2ZCbuUA+eq3WkPtPdZZpYulhFEZJ3iKEQ3bC/WhHEjsyu/ykhcahrLm5URYZPx+VRwrZ5o8juack" ..
	"3d8PUVAAG+IAO0PUQ1ldGTroTPKJanhMPdyJzJZJQGYjRixmmMuDx6yrVVMqK2GXhuynFLhq7kMAAeSF+IMLyzUrRhwG8zzlq8CK" ..
	"xEGnJzJrbSt1m/DCYf6bG5n1W7Jn/qL0wuFwBGzXtkZERF5mOb0jMqf2HJZzkW3fN8BqKJOcPTejiVGqbSBpU81SQwa6G3fGX7U7" ..
	"B9EW/xu+r4yIM6545JjC5Vmc7xsabzUsQDjTXOJ6yTjJodgcqKT6sB2qlbqB4Cwx14eEr0w/mvTEVWPvIkD4Ekn2hdU7RaH9/8Rp" ..
	"/bD3lB6fuWYb9bacl6FWl7FElgDRS7la9na/UIpWBZ+YHk2FyQ/eIE7DG9OSy/LWyxsHPUSoXI8uq04wDOGaZF2HFPe/LTUhI887" ..
	"OsSlyY5fpqv+v9RLGKQmHMFCmHE6X0ohT1U1H3Bxe3m5xYLyfSzB6eZWOZvdCCtqGXfDBmkZr+zZ8eJuEgn71wbEp0m8Roaavz3o" ..
	"bbkozcP/EaUGdX4QnP07v9LSO8KHIGxZcOZOsTUdCIl9HTtzWSjR/8VcvRSHCQ3/mPnr8C6UQ1odaZzdOHmIGXf39SkFFxDbIubA" ..
	"sbzSE5B0pCFzTmUsETEWOopgbR1ypXLksDD396EMzXubhX3ib5UXFzAPplZIzJ139IoHnYPBijvzibZa6hidkD/CJFKeD7Y6FGlx" ..
	"wf7CwLzInGxUii3lkd8oUP6jm9QAzJNDNN5/3HrR6niQLv+CxevTSY6HHHyS5Q2GK/SWvLwF4qPEhpsKzK5Cumv4k78ZVElQTVkD" ..
	"/gqwIHQ0L0uNzLMBpt9UV1UddMT23Ssp511LI+OgnknFyc0mN78ZR1L65Q6cFAf34+8J863HxY00qK/asn15hpurKwdSHa9DjY6P" ..
	"pgthpkjjqXofO2ES7KpVw1tTas+DDhiyHRC2QxaS4HmFcR3TfoPBj5afw73SFvcmd2qBrhUUQjoBz4I1HxAI4QdLqY01u3yr5KP5" ..
	"XuTvk9JkVgAdb63fCRvXitanYmeY2Yt6jCk80wjO8LfdooxDnMOzu8G16IaKmaCHW6Ud6HKxwqxxmC+jLoJCzlu1CGN4tfJKPfY5" ..
	"53Rh4mLA/wvpUy/vTmxRotuqeaxv1FPH82N0wtYi6rQeVa6Xc8k5uZNx5JZhR9kFDjb7XYa7pIucgS3tKGDpLkt698LvO2BcG//y" ..
	"VlkCuj0CD6XTPZ4t6jpz8If65HbTkkQB/HFXYCFoyTXnk/K5XimYNSgeKkJ2V/s/+s0kiWNdXmljEpH/Qrw9dL2uNxTmguq6vMFn" ..
	"LIQuLjphBoP1vkXQjaHR7+DkeYSjFnWLjL44HtPSYvdCZ6s0jK5NC55Ny8K3/rmdOimRmsOL6IuZ8U1VNmdJay7iWe0Y+MbH23B2" ..
	"xlQe59jTTruNOpSkpcnno3i+78Aya1vwN7vMrHB7MNkF3O6ctvBH3+O8oMd9eizO6ULnDoO8aUW8/zn1ZY3DSbR7UQ5ipjVHVMTW" ..
	"RRflgi9CS7lhQe/f+8IDAJgk7aB0zGHEbL/EIYjYw9vQTzjdgbX8o6I7FRxLfyU2sguZbOOBaXu3XVpDyYuuDc/LGaJg/QCHzqfq" ..
	"ojdvQNj8wtnZ9sXcuqEVTfOK/u2lNWLTvN7kS4bWtKnTXrK+TDbm2OInphvlxnEEeDsnsitdzum8cxKiJhH/Ldxzk4UlSfG0cSjw" ..
	"U1LAB5w3sjQ4EjyVXHk0MzjdCasQBWfdxMX/YU2P07Xpt5W5kl/Jg/j7eQU3d6wq0bv+WAaJ/lpCUmq+Qp0ufuc3dFt7Nb3LdVnD" ..
	"1tTpvOVmtOd4l6JnIkohOoqA1D2aGBYpIdtD+KrMhtZ5ajValJe71uSaGasgBpzpxW5SdNunTGblyqcR0Bxhpsm294LCm+//Jqpc" ..
	"woUToSJkwZLIP3Okvj9wel0MxMPxbnUwA0HFswdzBIu84jUMgy2FE/ziGHoOiUj3NWwOQhmHZ36pTJj6ylUHSEsfzs4QelMphgjJ" ..
	"LsHxjUYcAocxgtWDz7Sr+dmnUiGkhSTG89hw6YS1GSfbMHL3uyWPrOGe61FIZmPbZ3gcoXGx1FHmjCpoC0JbL+QEZx/2U2tULI30" ..
	"30zo/FYp4vp2pck3UgyrHiDWRv8cAXVIq8zWEPF90IkMpLDiKDGGimhcbNOo4TPZxjgMUxkeM+DESE/MCLm618LDLkYE2CiEoP5P" ..
	"6ZJuL960DSo6J2iHMFUW7iybi4zq9EJ9JU8vNe3Fyy+m/YXREh55aHR6mFmg+4lQttZjyBHBmmx+jwj6R/wr5eRVSpSy15pbP1CY" ..
	"mEde68644Rijl7+UdcD5cpxtfv46WF0m9IM4XqadrOIqLbH+zD8vMm6ic5qn2UrvUB4x8aDMxHhuNI9HzJZ7VvGOLgHYtvarFoPz" ..
	"cDAQynUps0byEJ1yAL+7EfO7JgBVdJB1g0zblQc3bKss/UQT4cl/WLVjRue+cldlunVnzUQS0UQxfVnAApc4lpVYjVDg53Xa7CMm" ..
	"cZNYGBwyLdaVr7KT/1R8FsdIrQOmMhIFGD1xNmmfzoH7ej0GMujMV8sJJhy9ncuslNvrr4TUY2SmcM2zJTj8MCkpWydbIGP6Wn7C" ..
	"0z7wpVIi2u1uii9YvGuqXHiNeJp43zRKRfm47GWEWxyrvX6BkH1ejU9iJ+DYFvAdBIBA2Vn1twE24FH1swuupP+/+fObtBc7NKU6" ..
	"tvLd6c+F6yjJcVSY5TevG5qllADwIeulRDT/mTMsLpkVv0CTJMg6Ddll+csrWEZrcGSo858oMOm9IQ/xxdE3crvLyoaPAWDNmVAv" ..
	"pPFKCaRErwX7S6LoBKLDMuqNQCrF+AbuV1vFZedsfRBZ/ownw97PkkjF59rBQwdcwdPUu9Q3juGKhA8H+W+1EDArLWYYM399jkXE" ..
	"G6Uc/1dScVJQU5gDWGzU6czHQUYDdzESO+CEvtIW1VKCMDtoW5JfzS6PUlUCZN/pO0IaGjJJKJCWu7ddRx6CLipbzN3vJbkEbhbi" ..
	"6gJreBrNUTh/HKbjYZJ/x9RRZZ7JeRu7YaMp6wbLBGQllvwpuR+/DjhcHWGThb720QJVLXHH1gQNxTArmHf+8CSyaJeEicgWXe/S" ..
	"HM4nvkbP1YRLWu769RqVBZRS0i0WVl/JX4eQSafTt+7EtbVzABv81lR/9ER3b2GOMliUY7c9B8T0rqbkY0Q2uf1Hmk2VsVnze0qm" ..
	"6oc9u52zm7C7z2VWGsFENLJdz1IrmvQilMRkyit/9gT2GQukMKTyXsd7ut7PiWlmkrxMjolDq0JY6lJMvFPddeyrb8Q/8oo8DmLH" ..
	"KIyRRCuu/gTrNgWKQib5E1dTb6uglIXig0K26CM2vxzuYEPzqA270XoTndAfo3MDRMHk57lgqZwnTPYuzhgD2a+1vnf0gD1cUFRw" ..
	"CzdXi2kaZYXyFvTtTi1YhVu2PYQFjmzKWFeYAGqneW0ViPyZH7Zp871m2IynaTSi6s7jFI+AsxFeREZeJXFLleCNEzUPYjtY4idu" ..
	"wvcVghMEgjshzxfO237NkxICr0l5UpCAGqO6awk+oMiNuZ59MTcSv+WsYWIMZJgyQnZmRVNXXrnslXVbFAsQzigcrT22zMBLH5+7" ..
	"9X8SNO3+eCzDf0gARpSogb8VShRZHT5jJ5tnJNimkxnoC3w+zLM6XJtXgrfJKir8+/La2LNPIqVw94nY5LVfvysC+t5ogp3QPq5S" ..
	""
local PAYLOAD_P3 =
	"TCippgR3HW2o4oWRi3MApDD8VqVGGfUMRN/A41LG9KJ1DUGbAYeIQ4xC4foB4NZRAzYF+ysQcBKv50h0m93YD480jFH9RMJstz3l" ..
	"DaIYlDBMOwf3W/orHIAuNzlzPgmbqPJun4WtR2AGrHd+4BjwL/vVJCXQPk40Q8u+PiPKIV+3x8TkVt8n9bah1Gj9gMbuNALqdt/d" ..
	"lMN/TezDAGrsPMt2RrbHzroUVu5ztXGBJDHfwLemF27hUVC8zfaguY+207dzmINF6f9UtmBMURvpXcY+A3l1pEBXjaT+fEuUs+Rz" ..
	"Ca4EMGfjDlHX+SXBi5Px0KppLlPFexOaVsFjXXVKzG5WjfL8CqQpTuVL9XkT5ePYzBK/1Pdu20VMTcsvltMmfN4rLymJLOK8XMmU" ..
	"twjtsxvlJPnvV8P3IEqvHFhDZnaWx8SHEn3u+GXkfKNlkM/nJ/WKzthREJYxs2KiBogJQJgJQmzLNlNJTCEwM0tk3iMKLHKaU0yE" ..
	"xhV4a5nbN2Y0mH2hMjUSVL2u9rNiThemBHDiytBiiVXfyPNIOcunLZSO2386s4Ea1KE3gHUN+utx7BD6OhzmpH3pq3caWADB3RjI" ..
	"IQNYz+bBBadQgcKP+jbCpXflFK8XoOrUiQ12ILrlF/ZzSHwS4qqIgmgBA+EkY723cmm8DnhL2JAREOuTuzdCcE1htKVLHL/BfWlz" ..
	"ia0fyYuEjsorqRhbfVHeboSn+H38LbHPqEhTBbsmzDjnOJ9CnU5z+pQiPKaelTGNhNCWzD41ZYU+PiWYjBU8NPCk5BfLwznBsfh/" ..
	"A+XMhKu3CKY15t8JPa5c3vf198zuofjdI7P4yAUHhujWJwQApdaSM0u8hKTG/HSR3REN5br9/BK/E4FkG5yCPvCuZE3KqOoGoWox" ..
	"F6YvEGlLsEwEYYZqBI5+SNVwLELnET6LeJ5vg6W9PqoDKqQqO/y5l45Inv/DjA5G7ZJgw8zlphtm4mWuH15uZ93sht9IUBaHspvr" ..
	"7rXV04V5G7xYFZBpcc2a/QRyHI57JUhiSSLLWV0ESllkxyjfIJxTz2MDdOBx/bXKqgXlogEuu6XMiiCJwEBmfyDPWL+2+v8E+H/A" ..
	"M8cJZoRqewLEDridKVtFiYDwiw6MMHl6dAjPxclgyDo3Fs3z7tkwRsEz8AULT27YWE3lqH0nupEcmi5/14jzS47ysyjuwprlBiIt" ..
	"+9nNUvPNKI2+klZaiugg0xqR6u4+Rb5Z2kW5+jhKUywhX9hgC+z6K6ZR4GEp5Kj496mN68gXaAwG798pY3VBpO8AeN3bI7oqjdDX" ..
	"NSZ/6mntsv/WQb52B4nnYkalFr+YlTCzQQdZcyysYAyQikyRg6glF82JHoijtiNj6nqfi5EWteTnxNYd8Y8yghE3Oy/t8Ga8ysyU" ..
	"uqyTDFt5PdcSgVr5SwKXakmVtKKoa2UpwgPuneV9DB266JrXzUR+u4lgdhnaCOgHWxsIpVWyBopbj0nrzO91+QYq5B6MO/rOikZv" ..
	"SufAB0Yq4k8/nFC8zm2B2lYKJuLy/dw7x7uyPNFagZbaOFNqnxELZOF8BHRaVLhD7XaB++lO4BppaD/ksJaZnZ6e/KoMSHYFRuvs" ..
	"dNm05XXgNYYooNW1jFxkXFYmNbRyVrQmeWgiWSa9Y8QS1mIwsD+xJxs3DdVWY8LjOfSBW1lKac2FpoYAfr4nAJDMkif3WSCqbW60" ..
	"C8WhOMMPenGze/z600cKyxYjyGQ7eOv+cI4KwNsWXN8h5tpcMirsVV79mneTTZjxvXt47vFW0bOLfyh7Bp8x6l/bFg/gDA6cZ9d5" ..
	"0nNrAaek5VNkG5hPfoGr3PNi4OLgaYw7RGcpSfnG5NvM9QeELe/CK3Gewx0jXjpk4MI3y13rAzyMe6JJ/7Q0sSahZPYodDWoXqjw" ..
	"ksAsiJVBSQgZ5plls6UztQ/0dt2K83QwskY69rM77ZiLLhCWV+AAupRpxBZxj/s7JLVPnqaVAhrAJJVhTqvXM3+TpouqMQnXpxnV" ..
	"/rTTTHnFkMBqu7i5tAOMRGYxrh89SEOcfmS1/BIhh33aRNIoyKyAnwRL32UGX2AtdK3yjO9QR5V+r12xRKBMmHDypllH77TfzW05" ..
	"st/HAvGGWQBIjF+3nSlVlGUoc/Q+hVHzDOQUTKt2P3WIVYsxxuuuxN1cjk7HFjDVIhu5uOEOS+MqLk9m8Tcp3xh8v2W0I/9R9yAq" ..
	"hOs8go7ox7MDMZG6kocN/oaIKxtmOMR61BFALP47owQoLSDIi2sdArw27FEwHWC3mIWYigvn50+jLIZkh8P+8PiUbjKvMDNME/x9" ..
	"6xzlomVlzfJ5kRMoH3cRGOPWqsNIH+vxGbnfINDwLB9Prj825dFBLKM46YAVehfQfa0Koli8pjyzbD09Vh0tOFozSgM5uK60ugGz" ..
	"Ib4FX5JM50aeUuyqw4FY/tRHSe842GxRVToDCCNDd+EVVbhGtiog1IX9eVrJN3xifdkrqS2xhZuB4p+GVnaxYxozwO69Nu6b4yus" ..
	"BrWw7x05jk3qbczPyM1hTiqNypquzo3H3EW44TX8vYIY/N/zI75bD7mO/KqCW4uI77hi/H/6z1u0jg9oaXAP/1m4G4sa6pjao5Vh" ..
	"Uypoc+fXixHQC3owM+9xLzJ53Zo89rp6UFaC5aaP+dEVMg3NXnETXD0QE+rd4XYUYKazNYcOdow7aPm2NBiCzYYQEyvFVvS1MePJ" ..
	"o/DzQofUmxjNhLx0sGQNgDllOLJ2WZyYB2HzpprrjkmVg6gehd9GINpBTa3jT1PDeVG8gJwiKLM+Pmek2q5AmqCEFSkRkaJlmgnw" ..
	"N9o6+yHtg1ENvVj0RhTsIXZBGP+ykoSMVpuRXPe3/t8xvBlA+bZor8sDUQ1BKqingfcuK3aL3U7AyTS8Wds5X2FhowG7wZTDsTqy" ..
	"usmPrqveS0ewef0vWjG+ifdiITkyYWM36TV2TbR8FXfbjRzjitCXRpWDoRgOgAZQHU2khrEd0JjBpdq2RCPoZ/urvrTnryswl5aQ" ..
	"GAr1+dj+XPcWEjRrEhEBQ4DskypHhMCTwFV5VC6fOZfTwCmYOwiwlEAECAhcbRpW0Aar3yCULMVdQjhk7tQgP3t+iOPZEcZugqYf" ..
	"b3AzAWadWUgSDt63NBMoz6byYQxT8uTNSeQ5SySmdOzMimtEnc08PdiNpTCADJxYwglfxxuJoVtrTeSuBntYQP0RjCrolQnD9KYr" ..
	"esimtnbVtLtBYz8fvQYE3+Bsja/X94HG3jZtUKe6mKEin7NONHHOVAfxu/GijeL4RBtBztGPC7fRqSz0vxqx074wQBycsPEYv493" ..
	"lVaUJC+fcRzY8unMhACu5IrkiL7tN8Fh4sEavxUf+WFe4R2dX09HnVowkN3Z23+SN0VPXPOmZb1XK5xuNBbgRd06UbNQQnZhUgEd" ..
	"2duHXa4FUzJbtdfKGm6VlaGKTSVzOAJsoAbl9J2rb5T+WVjbpSN4v3j6xODmfAYjS2Z02rANins/2zWkvFcjhWfQdYbVzj+oYLMD" ..
	"wXd1+83bajHG5K0whVWrncAPz+IdLMRVzfBVtEUD9z58ATFs8xWRlqN6tVA3NL4jtRlHILueo4/Nq0qGkLYNGnN6Zr63OtAuS/ed" ..
	"c8KlLZi4YtseqJbONwdGhzff2itZS7NNpFN8zPgGAxIDNyXazJHgH4DUJ8gvvKkeXB5SKSiLPcf2AeRQKhVENULpMpDcc9MxXUu4" ..
	"DORWKceoya/k0bIzW9loXU8rs9uV3HiC6HOLS45ysb93v8toD3UEJiHZS8U8gi66AyzbHQr+K9dWR+kwr59jrwInUwA2kzUECJnW" ..
	"64j7MecIcmBrIYMWkuPKbPtfMPuE9teszi3fzsKyjZx4h4YueKi0UKoRq/2IYBRW1kZl6c+/A4dn0I7rYOKHvp4CIUX6kgmQdaUt" ..
	"UiXJ8pNCB6PWKWvvsUX9Xgg3bLAMKc/LI8ss+XsH9Mskh24J4HgHQjLN2laHCXKDEI+tJOnVtzfcD7GtvT5fclHqI2wdBuFx36Aq" ..
	"DScR2zFS6No5jI0K2GhLSxDgCj+C3gzsG+juIhz0WhrUTTreCGv+QbsNpHqijLhwSTH5jgqecOg9ROkopWE893keJYhPDb4uzmsb" ..
	"i4RdhQta1NpGUCQXgdS7Egctvor2WadwEBPNtDTyO6sKLTJYyMLC7c/ge08V44i+cSZ8/N2DFGcsn8hxjHC2AUrZbtR6H3sIGzlL" ..
	"pTm0mJ4ocx9TjbwbsC8PETaTMsqJImV7OdpDLYLrULfy2x+2BKe5Jy/rCrf/4qIp4H7aETrcpa0VWdwgE2E2SE3Srry2HPiEUQrq" ..
	"M+hY8IcAek6Yr3gYfJL6z00XzLrR/k+VLuBUuSgQiID0aY134KpfFpgsu7lE5zcOLVrNDVJiWnxUgnw0rEETi3V9nd2V0JCk6FRT" ..
	"NTYhXYliEGdRZooIuiaNwmMuveKowJQjr2VdBDi45EJs7h90kNuFo+7fhIUuHRrk8Maa1KBJc/dTNzRJeKs/0tUZ5tWy4lwCSdXJ" ..
	"R1dGz3Eqfr4qOQLzYzNDGUtFVWUvKPU9H0iCQexTbc0ebCQpqvPObN1YTAE/rWOsVreHplPCLZR/mBTt5TUwxDwF32/YQBuFV82f" ..
	"eHBodH1dk0EJjkRNuvuiyChw3ZC7mNZWn7v4+2jrHStmLzy4ztyT0CKf7HVzdhRtpfV7F0RQH/Lu2ZeFLJ99462Zx7WqjiplJymt" ..
	"UTq9ttUU2ZSO/RJZqloCBoa3dFgMuBuDp1XKQszKrCgAuRSsfq00cAiFzfg7vqMFj+0X+Kat0SPGazMdFCaO0hf/6NIMoqeYrJgA" ..
	"5k2dGz5XYkngXcXs5zwL+YsnvzXGXqjRqMwtiRQT3kZ/AJobaF7S1do4Jhxce4dyveiqhvqx+PVz0EyUIeE5m4fI/wNwdzdhMg10" ..
	"btn/YeNX3hA4wWYqW9SObN5RDCFAaofeN4XTLlT+so3c+lGCv5demUa52S8TcL4HgZFU83ortBrQtMt7mYcmaoA3FNkA0s+twoWB" ..
	"Wat0zWKXJlXgBRCgcFF4m5fYR1mN8q9KB7Sueg9BKF1QJtP60WuQtZ8pEZEAZ+n2fUVNJYgN/bnAbGmwSuvwzBxFQ5lpYitkO1L5" ..
	"019NKKx85JofuWZsPjy04eg6WBEiXzWgWINiuot6e827oxQSrrCIpK+p3mM8mnFVPB6JMqXdc8oeKjxpBRkaHxwAFdIOkFzdM4Dq" ..
	"wDsiJ7NCwTGfP5zj5Hhm/jQWK8LGofwNfsKYSfJA4t7O5bETTfz/a+PybNKYC2mc4Fo9AjnS00Wal0h138cAans67558pBI97/aH" ..
	"YdayJzLQLD/HbAiY7bZO9wxS4ewSuFCVsQ0OXWd3dOSnpeIC2vL4BRAcTESJQ/6QgZbJO93y/5BbDSt6NcY2mHr9tN+Biw+0uWnX" ..
	"WQwVb41k615Bz3O8s/GksjjNZgOnjUgmdxrSa0vRxbv7xiiitlJK8ACNjEFPxLtC6iHJwADdkhUmsCCKI4+5NHJRZLIaIrndna7q" ..
	"q+j7mS+XPczbeaUZpkN4q7qLfeZePzEaSjW2RqgzlFECDO68Oo2sPB9Qul2kPo4ypzTRnrhKzEdwAVdhdnu3G4NY5sRP0p0kDhQE" ..
	"8QmI0FwSotAJjr6FPWMc7m4TBwhBqiM3R09AUytqOh6ORsbbFYKAUFpM8hR+c8+Ai+V1ggVcIXsqzy8PpXxmuEovZyDaEKO/OmFu" ..
	"VpPAjA8UUbAdH+cPYwkLpn2EadsdPLfwm1tYEpzcXj+qK+6c7wiaXPf83nQQ0FeVNtCqEG0DApLVdgCRQQrtRkz5OXtSUoaEJ7gB" ..
	"WFYjDk9blTqHsLFGrmuTvdbgR2fCbZqg4mPlznx12v4/6APDNyoz/vy8QYY4+XSFX9uojCAyMUax9PzLNIWaR5XFJsfzhrkzHW9e" ..
	"ztFLAnJiyf1hmOywL1b37j7ziKZ9Z76qqLYEdNlm121R3LwosJaPjlGidb7CX8louVuBkIGt0il4az0MV07YSr1/+DyldmEUQ6ea" ..
	""
local PAYLOAD_P4 =
	"ft/PdY338uLtgLR4I61Hv90QyMJcNbJPoMZEjXpZSubFVZgrXZn0mXLm+ZhG7olwT97WVeTGoybVa5vx9c8rqAxUZ7s14X4v6658" ..
	"kyv/OT8/64GgvLOlmHRHVMKRj2MpVup2J2wNSN+vbSbarF7SvD5DVL9yFrrsIra6syOCV8Drl8CsUtYNjUTCuBC7vmtbvr9BS7nn" ..
	"J58pkB2CAYenJIhhL+nJSk8O9ddSZBcHtHyQg1L5iqz8gSey6KLLg4McmZNg3DTWXOEFjOVgmKhsK9JwSg/X8Qfj558P4LRJ/glo" ..
	"T3HlDIyWECgRzAF9OlVEqnW9DQd1rmhPDYq5Rn+VkFtbMuqpx9kOyT/fxvERL9nSO1lXu+yxFp/FcGvqC4P9aWl4Y3RZj31wa55Z" ..
	"Bi69d85VR6Q2dUosCy2oqzLJjAmp8kFEYtSij0crGmN3hj0HNAQH4qx3Z324VYmubBd9UBgpb33Y4eWTB6L8Vz6txncpdl72fA6a" ..
	"MTViXU95WWIBN3ZrSpI7uetW2VoRSNm40w5lsBq0Gjk5QZYS6NtUyAoqDcX9FfT232UcX3Dshdl8pAoDLm2WsIy+VkDCDaSSGtdT" ..
	"uGeDjQKWyNvkgB8xuLgSjF+XKlV/FiAzCkSanDiYJ0LWFKAQqX64I/q+TlDKPq63awALSQP3tE2IGYE5xrmiWHr5LaJwHz36E8R/" ..
	"PHpWkfE6MGf77PsGQMFoukjmcWGYQh/L2ZyQ14Px03oSW4+XbofdIxSonPvC4MSNQZyevieIwmypaIgoFHDvazqf5aK+uB3NKwoD" ..
	"HgZRBUqSJcR0gekT9lJia8axx6lQ2U2XhiDcSPoSP6r7c7HlR5nqNiIzTdsg02WFqa4Ji5yRMJISEB2eWyGkrIv1Y6YA6mkhzUaS" ..
	"O3KVDyVFCK56SQ5X0loUBCaBbvf0fvN46UNDqDLPXhbCfr/zmy4wa3afEFFGpORMPtT23aAazLTzxt2KIfG6dcxiNHoLAFwVCk88" ..
	"+mk7iTTAODsLzmI1C77TScHIRVOvyxj8MXCeQN872UEq75ZD1Jsw1oHU0Kl2tBGEAzVw4ZWNJnnAegQ22GsIjI/5RCN74E/MSUHC" ..
	"6XMX8+/Xjae/3L5lTOywJuNbTRBbdssckXTrGHkRBkhiBJl5pIzddXjJg5fOhCTgg4R1BLR/GkfI+iG/GX9NyalP/dHgn4GY70lr" ..
	"DXqn5hnGURvC2TicSxOuxrrWL94MnOch0IrupGeJZW53jjAm7nlQk38tap3kIeVK/vH4YgWt7Je0iWpgbNK3BoQMOXQXl917gd1s" ..
	"l5eD7nRf+o31LHYS7uUT6kRfBnrkr2Vm5MyeBtjC6/wJj9e+yztLiwLcu0TkhW6ztHva3fea0kJXMRZyP1JT8h0CqVTCe6Fve1Ts" ..
	"b+pXrzb8EFjJ/BpN7bP1Cut5aELeUE6mTzAKnBZem8e2+hesWS0ADeuQbQ0o+VFrgvwQab0jzZvYw+kNClUH6uhP+An7xx5Oc3xO" ..
	"T12x3EsnZktPG0cGgVYoSGNJ/oTOIKshfUdDLYnUx0NPzqM3btFfAdcc9WMr0z5+nHaR6vKOMokgQDY7GOTRb6YWkO1OoYPObFu/" ..
	"X50RajPCsx/BG4S58cK23VlXaLRxDAV0CIY+crzNMmueyWG8d3ZT2dPm3s3b7mSSq/oZHsXbkmNVe6T+dnxz3Y0hF1V0BFtff3hb" ..
	"9uS4+rKbD013fHPs39TF7VSE+XA1raIwZ+UU5mqIT/0yRXuFUCqbR8a/f9HWOXnv/ZOpNUQKQRzmLT/Yfj70q7AL4ss6VKT4sQDX" ..
	"lBnpV32CdsYctfGLir2zkXidprtn74UkijKIif/m05VqgyWZ86ReFZO/Epa8VlUqtULpCk7hJ1EOCQp9dAvIit0YDNuGBEA1o7Wa" ..
	"GlTIzfbcRWcI5PGMaHbY46uaE+0FKgL4tBaGQVDjZDvHK0ri/+VTr+sasY2JN8NoFZcvuTuDS0jTSqFW7FPbjNox0J7gaWTqlC9s" ..
	"7FtQNOf+6IEFnVhNhxOTTZtAYdMt5b3P8BVvizuBll5rucceIWhKDaUHTGx7BtNdnSbQFacbTue50lIgkQWTjO9D5jdk6zkKpM0/" ..
	"R370x3ZUyi6op4XYnD4jppIHKw9l2itHcerruvKbVipBAcw+r+aSFDFlVY2OktTvqsR7aeopUd5afmypmBYmV+vceg/d02Jgoyie" ..
	"s2urY3l35qHnvwUvRVo5eYFl3vil88uK7pEbQnh8JGWKin7dgBZicRIRO7USL7ozHnw+OQatufSExUbJONnKz8blEvNte9uDEsUG" ..
	"Xpgc7I41pfQ9jKtvb+D6UzvGGgK98gGIMltcnJl8sDM3rnp28oah5uemXyIk0OppMfBD7y5/b75GSjQSwu5sbpiWHolVJRnRYFes" ..
	"FePmxF1pSHR7gaOJlMi4h5lIBdy3Dk1wgo+2UXUOzWzwe4Dnnd0ouYipLSRFu7mfrxZjxwJh0Rr3NQgzXELTdt+/sxeT4ROminJ1" ..
	"JLvWe5GxHCW1bUuAFR676G6oogeSqhLdE9uXfqlLHFZLjMG854NvcbaNQ3sA3+17VIzpZFNV6w3IuBiXADqYNt56/059n6AQLc3f" ..
	"KmQDCcmmwmzO5AyilGdhUJZHI+xuuAdrd5Y7SxVztcS7NEmYMYrWAzwbmPWBPf8DDEdq42aBOLIg5q46xMHoCjU4kFAuM3QsYHpT" ..
	"7lhRcJE9fPSBpVaPzeYJqfBcYPD06lTpKKUOJU+UgBFGuDK3F2ctj2qS9I/qVFYp2mApv7MczhwzATv9pWVqKILc5ZZXfMglabWD" ..
	"sotIw7ZWRVKRHpK8JKRfDgcZBAX/vrlzL6TlQt4n3LMqYtVyV8ssWe3Du8ZKHVivXGDNhSHZIaZHWZb5Gt854Im+I3HR05/xlP3A" ..
	"wwHH1hYWvVXg7H5Ux+rUqOBQh80q2u95o7HOqnNKo9p1N1yV9h1lHUS+nRmvBvU3/Tq2/cS2kJ/g1tTI+tBPUy2XM4qQLC5pFF4z" ..
	"v8ao92prHEa9BRJDfpqjQH0QjUetGXl9qPz68bvWC5BXg9MNet/VRPAnLU9T7hEr6JtjV3K4YjFUbk1pKvIHwUq612gnvwjfKlhu" ..
	"Pp446xthED8If9pxaRh9h66Q3rxiSYVZp5sXv74bPySosaD3tqCABtKpxdpeOOp2sCsr0kgbotKGC4IH309ZEN+jZu8q5x/PeTXI" ..
	"PSkwkEzXvU2CFzqqZxGGemDnOKZmgflDmGkHoITD4vyQbEoRqMg5q7KqI5HiwV4kAunaEKgOVmVC7WbDAYc1Dlffer4u07f2O+3j" ..
	"44FL2FXzYnEOCoaSdBmz6Zf+U3rWP6GC/AyfFT44PllKr/QXM65UP3h9hECL+TDz+fIl9VBCiR6CVn4u+hsc6AbPNpzMNTXXKxW5" ..
	"yd4qIUHk5oQVNKcNzqnkJ5kzl3js8bBnkyIlJyf6JHKYuS//mCmLa8Mk8miLe/R3J3lFLlT6XpigeF1r2/w5oNo6RaFRdE0rnHjd" ..
	"GPDRAWjHTIN30xhyAVmY0gsplUI39F/tXF6UIDJX2lWipbduoGkshO1Quck1U5nIYrLXvHU6msi6DCTtXZiF2zbM+6/TEhtJlsG6" ..
	"iACkxkTsET/6x5OuA6W4bEQ/kOHg5a90Xl/fHk2MVQXRba8TNtR/4jFJpa5XItc7kmrZOckw4xC+putZ4B6cHnSckRbQuZLEM6BP" ..
	"4OTAaPqfkfUmVSrN45RGNT4q+Gj8K0tkdo5TW/RWxg0D1JAtmLS74BdCW8mXblykzDpBqtm5CoOSfN8XDpMoTLuQvJXNnX1GEvI6" ..
	"GDNKWD2l+RdDX70JAKD64EdWsNVaqIQJz9ycxtTExwLClEgA+rgTnAEfgofe6V8VWW1d1jgexmBSSP5mo5sitlfx4wGBi2OgI4yY" ..
	"xbKV2G07nXiNGErKKbZYMv9yjEwBR+zDlmUB5MSKNuH5EiyRgWlOGyhbSNvpPRP5ha8GElzf+6up6uuJ/67g1QMxHrVbPQAkBHZg" ..
	"Af39izwApN0kxkXtu0jGtSZTNrx4LpFguI8VoHlqSnyj33mMIQtapjt4EOI42GrpQRIlaRXP83fIe6hj+KSG2oDA5Hc0UlHJQR+y" ..
	"pK8OSFWEBmEKC0RLjvZ/VA+xf24I2Agf4OC9yk1Igk2JI2daeQg1YhNyHZAPOeZKJePNyb7nsgCBtSdi+Rslud/Ue3gTzxKXurqd" ..
	"/cMgR0yQA2ug1tvv5Mn5mMndmx4g2AFfiOnATpk+7T2labFvZWczzT3lIoJW3l0HaBkZPh0BP9JP+/tmS4PgkEqwiy2TH7wyUocj" ..
	"PMiuwJJrB+uT+jCrqBcXUb0wF8MxmHLNewO2R987OPrT9riFKmIOmBJZfr0mQoDHiwINZZbaZAk4/1c7aIFS+HySOlWeSLxVnlmR" ..
	"RX7j6WDwWLSbiYhetL8nbN/OG21rYt4u4L9WL2GjMWEPcICQzHWWo9YsPtpGLaEQeVxOhaCaBWgz3Hz6KlEJ3aUPJoNGgMQqHush" ..
	"hTcrwLB1+oEuysgwkOMABBGG7/gLrE6GeEdFP6/hMU6kn2Dyki1afRCVO0pBri8q0YGKbZ9X1hOb9EOKD+6Fj8HAS8BZPAZ57D7P" ..
	"55a0ag3wWVisbdvwP47rYXIdlP/Jw1lRsOz/RkY0iyVBHEoegxaUzW91wpZOsQIWrqSBmDNveo7j1Z4Kp8p2nSbIhXZ8P7XUIkw9" ..
	"mbt3Di/sQb3j338CzVw+qN0FVePqeB91WbnZdDCFgd7iAGfmd+21X0uaD848dtGjBlkFQOQoenJTNfnJVWIAYl1GGdRbqIZQ+VLD" ..
	"j2jWnkYORTrTdbVx0HvMPBnJakqkPdzS9HFrQTf1WIslrhyqZKdAIF3cMUEKtvAe4r9kOLIsL0lb4XXNmtHSpAL45E8fac+BU6rH" ..
	"v7zuxEcTTk5tDlpJQZjIhoFPs1Hi0Nk4m2LAcQ/t0lMfrOcbl/H4ADoYA0lHpvoey5p0t1dLrNn4xOHPG5JGNGFvQyCDexWfc+ZT" ..
	"D5kDmf42OQMGKA8Cc1Uk2gc4F1PZ/lBlRLgjjE0dqtG6JkONwE+CgRjSYP3qJVUZ8rk5P+VSqNY47LGl63QtRb9vO/ELW7C61I9a" ..
	"3zFC3Ut9AcXmon0se2iwxkJOf8P3rwITcV+C6rqDg/34Y72PE0olnGtnAH1sBRamoGS7Q815ombo+GaU2+U+VOxlYNzYGDes2bV6" ..
	"1XxO2LA5lajVy2G3Nm2whZNXFiJ7L545v2JyZG3FvJPOJhuRHP6cGE6b4c0fet89YpzXGYn+WoRLFtTnuNzZYg0/wthEa2l+gnDL" ..
	"+U1zzeil5o6dYzN9wrGSZ5VPcRok46bkmQ9Lmy10jilvE75VbsAvlrkyJYlHxLcG7pMAM3uoi3KHQR9u333gYJVH9wN90k3rkrdy" ..
	"h8I/cbTGMlOnjtgDmi+dDzFQLSbAIIVprxFR9oLtFgaW6mZZtp0CfmHP0KHXsR1XvPIe6qwIQWwF7ECC5ociYGLEktmazLzz0+6P" ..
	"83BcyuOA4MejDu5bOlQEwpe+hJrj3IWzjwShsb7Ujww1RFkrcsL3LDBa+Q5N55RSl7egt5CegeioJgUYCRNpJxKPbcwcIrKqqqLe" ..
	"maidYeXQfdoRCDIN05x2GV9KmiDradcqrtQ7feV8ENdkm5dTtoRinr4ghWtQ0mhlgx2B6asJDLufTE4rfQj10xcCjw0qIaWThXO0" ..
	"hd6HMewQuFVLUSIjImkUnU9uEIT8lvt6UGhBa/6C9NAUYdfdJP8/zKcQsqcQZHFOOW7kGbUYENgpB+e/0X6NlWJh+1mC8z0hmWeW" ..
	"IOrIqoOMCBqRpOlmw1HQFihaLbZWzXHVWO5SGX8MitpfDu64BKEMdhyn+IViWrs7Na0uJTnv89Q7L03FYCB1fQzzfyEwmKrDpNos" ..
	"Su2M1hToZNmAtgDUBGiJuNRryWFZSY3SjoubVruu9KROawJThRPllCDOi8LWXa6+H9rF3LdhFoZG4RxJZUkQcENznR8MJkkiEQ2B" ..
	""
local PAYLOAD_P5 =
	"Lw8SF1Ef9ZDifI7sD43ee9/GNK7yYfKT/MAzOG7XglXEVG+h+kq3dd5cgtzxp2cVRDiupyK1L3uXZm1thVR9qZvIpsFOD0x85aei" ..
	"6dYrQakoqwmw+DuG0G02PErMXq9fPRoSFK9WNDe8nhuepI/tjaXZ80qGSjx577XK4mlmDC4gFNtz88ZXxz+MglnUR5Lln0L/SDXL" ..
	"W0cC2tTb54CI3BblwOBWRDK47ee1Z5fQLaNeXk+hzBzcWHjrNnyunUO0Zgu0HIx/ebsYjy4FFc82g3umyDvC5kONcjDwb125ua1L" ..
	"AUsW9vP2/jVIttTELBXdf83HWe+hfslFijlkyf25rTgbkAFJ6Ndt/yl/bAllO4bGeJskbC5uxwU2OTWLuFvhrdMoKksvmyoTt097" ..
	"0AAQKvc6JbqQRPRcMiO9fCVBhluChgBkczNEoV+4m3mQxovtdm+y/DIqHB+zk6qXdnrGXzlbpWg0wko6M7Be5eO+VAlzwiX27n6s" ..
	"dgTFxQLt2gGmiHns4nG5XQAIb0wdFCInikDUjynlfS6MQ+AI0YPR0vTjjznfukbKlGCXNjW4BRyAUfZ+YRjSx2T3tiM0k21MeR/q" ..
	"bt07IfyNJ50+Kj8u9a57uipbcpZLndKgHZGUnQlBg+XEZFbNtx/4fEsF1/iekEIWPtaMFOugwgtOSW+QF34m5Bno5sQI/vdElHrZ" ..
	"I1Qlh18GR2SwbQeya/jetjMEkr+IkAEmroG4MHVHcf4x6Z37c+cWkkVyDYyKlm1jZqB2TiXpItcmu9XTr31BJjSilLlakjOMFmSN" ..
	"icjDzw3uVOd43p7nvBQXZOZMZJ8/VAe223chqihBamy49P6cJ9UVKnIg6BR8sIum3LgWG/6fGDFZUqvFdZAjcE1/gxG+MeqT0DR7" ..
	"f13rHJSwjjPU0BXHh9g1WffdsbgE+XQTtHjWA4Og+OpdAJZXQ+2hQY/EiLf2H2X2wzw6GbFFlzW9SgvYxwY+kQikUGoBnl1wtCz6" ..
	"32Pz097wVggp6u/caPw2V7eGoIx0nP+px9LuLD18udRMKBONPQD9tYfqMdlWI8Zjjo9XZf9ly3OV17riVxJwcAPU5SG802H75wdO" ..
	"z7lkXBagiEmIfjp8fMFcJ9fPEWTWHm8C96FS2pA79UUghWfx4GWKV4dGJo6K1hnTTDgkWg4HcwC2xwkvF86RHDtgWIA/rP2I5n0D" ..
	"S4leM+9o3NP/WNDj+/RAGGSYyOHmOlhQDievUugrmxHpTdwgixYUPXQkd6btPksFraXvQdRUxfL4/BmMge1kPVZjxfhHbGYr6WBf" ..
	"CyVNVVK9bgdou+75wob9BCvmnpfjRX67b66O9ygpMTuOFuAXMHtUKrTNsoQ3iVrBkk5gloN9ZPj6hZAlzR01KoAQ5lj16fRGqHRb" ..
	"ymk/uPgTj/3fXzctlTNw1DXwT/OjwWH4GbT8dSePDhB/bF7XyhbmSpo/IGoK2s4ZytQ22uey112FffdHqKYyV/+SNlHfsOEQNRQA" ..
	"WGYXkz/FvbadAqKxZHsynDPiUSgBSAaOQQHFe+oED1OTkiTZ+uYg3PHwf0DKc91PAecf4jupLkRLFxNhZnukqHIlEd2j/QIKr0vU" ..
	"n0KMzHnU488BuxB9ZhdMkMHKSBz2OQvHHWKxt7s/I41ebfKjwjdTzuB0a+2MHkwa3/YF5x+SaFnpS/BLh74Xv8g09fVYEWp02UU8" ..
	"+xe5fztPVJVa1vYyeo+XIJhDDFCfIrW0lqZAqcffqXsFyu/NSXSEbsjfce9FjVMPx1bEE/FOy2/cqcS1mzYswC3PKWuXXyJfGQhd" ..
	"JNwve6Fx7t5rPDRju6aL++nKBoC6gvML7Y9Iko8gEimCYSp5s0lFqRggYvIGaQugQqq1zgZE+inVjrWYclQe0NrhZEFyNpIenKOP" ..
	"NBtMkyRyk0CRI5Smnpea2fis5FGsyu0pR4iinJEuulnyw+LoQmd8cSohdxBeaoyylLXMNidwM4IWsJ/HcjCWbMFwSH2bM/IbUnxc" ..
	"houVv0qi6iHNMjBit/mRL1YZpSH8GYZnrY4NynTUO512XZ+Os4kkru6Q3COic8B/UX++sgrUfu9jDEwgwKpfF0i9pQtbClHmU8pV" ..
	"d32+vpUz6o4wRhW+mpLp8T2AYSmlV5UVOXVJo5ZZUrGZb92i/EvBiIbz+h1nkLGMwv9uCZNoboO0t5IZI1hdlZjRXCpVI9oIYYjU" ..
	"MyJKUxMpRRuWA4KKgrHJzpDbjpBr8ohd5MgpjreOTxchx7JjbFpwGlMFDaxvl/NSwkM59VAXjT9n47zlcRGCATITgod0G/BUtcbx" ..
	"D1LeVskUGuCtX68aW0inpWlcMdQvvq6I3igXBaxYjTIPZIEaNvUVptXjFHf/B0GF2wsvw0u5YCSFDo1tzcv8g2QLpzEshpB0cguY" ..
	"wHVUMotcb02q7PzenP+Cat1+BDk8cD3x6rFZUHZTcl/GJ5t0J5l7SZVKE00iVuHoXXyZ53IDE9Src47vAmNKNmm22b4tgeVjPnBv" ..
	"mi1+EEW49aSXRlDfBQQ3ouBdpp31AYktNM+50ELM3Wof7QPvcpY4K1t1EnY36E+m1K6uB8auNwD1CG7OzBEndIwIMClytNlM2dpL" ..
	"PgVovQ13LRNUkI5EiIVmHbaVUjAPcPnCyffSbdYH27Z5yMZyAJhAWs53rmWdpYF9StwWhzUPYtPCwF4jChU6apKihhJamng3ak3e" ..
	"+W089UDB0voO4vzMVCafzd5IBo8ySo/BtJu20Uo8U+QrAZKKQ9mEuWUdkAb+yaIF4/olVHbssqtlX6tBuFTzfQ/tST2aosGfYyBw" ..
	"ZKb6AWoEI+txdfruPBfG+laepln4sepdSyEIq7njDSQOKALNew4IKNzDbdRTHlzRfgJ7UtOxg8x6F9R9VyEQ/DIsqHt1aG2JEKFG" ..
	"igz5HUm5/h9rzA/vJMGtuYpGWDXpSCMhkLHBnT/j2CkAOJVsYBvSHwVfAFRjpvZre8u7l+XAIn9WKqKZd+3oTsQDmVx7OLlepatH" ..
	"QMUux+o5LPJ+nF8GAlh8l+ELETEU+SkxPUfJKhjJY7AkRG7uVpkM6CY7rYBT/vFZUXCsDPw8kyJiIKXn+MTuJviXsH1xefgXd2ia" ..
	"294T0LRGJ7RW/ggbfVCwHzZJhTKWCZ6N/aAFm4y7t0Db3s3CNhrBMLkkQk1z5IzLTevhUjDPwNr/9FPudIrZu63VWZS7lcJsJt9t" ..
	"KNwDDO8oMUtnOZnFaH1rK8JASnDfp7kQL3rYuS2AbLrsNuP0OBRNXbA60xg4plz4zKbSTDHaVGYBxzSbMg+LZYmY0jWl+1niV1jN" ..
	"QgQF/46ox5YPgdeTaQHD+9+46IEuJuHcRod2Vxh9BYzlTeWxXCvxWNNnUi0633kuLNAAlnm5/iwBS7t8fBNEq5X7c1Xm1mtWxXf0" ..
	"qZrg/n7rlM2p42UGm35zYX1W0Ck1XmC5mn1fkj/ymRtE5bOQP1Go8A2GPzguX2tX2rs1cU1IL8ZwJpnEDyKliv6/Vo9etDQKfeBt" ..
	"7mKvggNdurY1FRt5y9ds+pSK6HYysV+GRyAmT8zWRngvqLhPMsDIvVGo/v21cLniQ7q6RQ6rY27VHb14Kxv6ffJ3dD1X+zEw8H3x" ..
	"+jN3LNZNbQlJhxcgoAfDm30NciOMx91eMIttjGx8gYV9Vb3GXj4eKpjniHjetfz3fqkQELNwZNqhANWp8OLo7yxDSCDdJVBBqABx" ..
	"sh2aU6tIwwIA9WyNeAXXiG566X4ZfR2FgSY55/IVtxZEOL9HS1TZgBBNHN/0KiE4OtLRMNkC+Q8ILihpMpKw6nUcz4MF5Komx/6u" ..
	"SuwfxD0zekcdRn8fyvgyiUEylUd1w6eHlY7g+xqns4nZjcXpltkbzi95ano0HuR1+0TSeBcbgnkUv1GhAMO319Hrn8hEB1Db4Gkx" ..
	"xcHi7D1XOS/GlYTurRCj19YNw5QL/1RqVg92g+hM5fm1ozaZE98aWGUJiOF9pXhnRwNoNjv8/2H8E1xT015ZmQsx9gKdFQfNOyUq" ..
	"niuJulMso9ZECIVkhwEBqYtdYKqmFPq8f/FQG3J6CsCA7rlx+L0jdxcgV8AV/oQ5sw1mcyCQ8MZm/VOCfIZfN3ULXJZPLCvc7gbg" ..
	"lBIjbsKEoEMHtQleSDwRnISD+FIWa2JMO2UaKZwDS0GF60aUBpxAbyskIqKErFQvBBe+yEGH3DYwuPKzXEQhGBGFV+kAMOMMcZ6O" ..
	"ylb3H+Uz78ZMJXg2fVNkBA21NkfByXQhWoexGQRoH5r/okut5v/BI7j5Vlji/7XASitCfoccgTe5FMLtIt87ESgytg0VLLS5XWCB" ..
	"p205YkF8rDH0EAIAMhis9ENH/E5j++E0ViAYuHmXWQRy7idDjzQ/i6YzFn8/EI+ciBnQeP1pyV1rr5QTmlugMdse+1rUNKxSuYm9" ..
	"/HPP9xEWu+z11aspfVvCa/CaeCJ2VGDyVFQs9q9+gEIkUswbi3Py1PAOoZ3SFPY6ChucpGDGV4TQ6F4wGJEQuKgCyCV5xW6coSf0" ..
	"hxrZMeWFPn6bcIChAm7SootY6i+djX4nKmBRm9Y+cP5BQgUM0Hba0prHcSoLr8QCBY+k4rSOc4MNlEjfIQR/eTmfUQa+xWydPi6a" ..
	"xSx/KdkAJRVDpbDJbF9oG/ZNZvlGyoY28whBbxlL8OkUicpMIF5jZqHWIcRHZqzlZFFTepk45OjE/9VQOZ0rHX9SVKxxZh1s/k3m" ..
	"oC6uvy3J4WYMjYUFrWZZGUhZG9kiVhym+Hkqppp8ALkxaJLmOG6V/f6jGkrAke+Q5ZTFT3Y5lccIxbOIMIgh3XqLAIP/1tZJuVxv" ..
	"e+CpMvikIbHQ4TM/p/XNcZTGXz8F0WukQ88JcRD7MQl2WhndoWxbojLB7eT920B5MwaT00Evo39GGa+x7+c399ez0Ok/PYkS9E8b" ..
	"eEeYkYfaczsbaGcHco/QnEg2bdT4TeyFQp1XxfUsBuFVfp9oEeHmgSMBpBZjgQVFm6lc16xlJFEEFok02uSF73SWxBuGBNLWHz7/" ..
	"1/2XBfZ8CknAE9cT8W/Cin1LkZDEFgGTypHLiKkA1iNbeLGwu6t+/fgt4Pr5/WsEQwTQGqTD0iHvG27zJywZi94uX5Kg79ke+aUq" ..
	"NVSxfMSPPAZHD+QBiT34WFlyahOtqbFCX6HmwHPoqr6vfS4j0Qd4+R92bsRjj8XhpVxl6jvgytYmCnJG08WKtY87SvgUn9RauPc5" ..
	"ZJi/nQl8dkT9FTp/QJmt+RRJglhxwqQlUn0byiClHR8Utj9HJWOgOM8zO6uKQ6BdXfJUitM6940hHgsayGy4xrcr+Lv3NWIGbZ5v" ..
	"5HmGEeN6scFgA003cipTM3JnmAle+Gu4Ec2776Edfroonu7t+ewEBrSbGlM9iVDhxcR5yFJAWGWMgkPZoGg90WMo7UW1CGYCrqm2" ..
	"XSkw4mWwRJxhycN6v8FylFHUnvgs5qdrCiWu8OoqSW5Z20KsOAvy9pJAW+oia6laowI3VJBhgNwyPqlDcsMBSKrNBRAuYzpjMs9T" ..
	"i0u6Bvjd9iWKNpfS40gBQ4W5u5wC9Ilu09KoxZcct3fTiyeHyXnPpE4DBNxwBPTE1+/rNcoUd3fpW9615PnYNOIWjb5ArMExrHXB" ..
	"ns+whmlMAK36Df0UzWjddDSBclXurHzhSEf63XteAtFC0sLMYoo099YjmrzlMj44N9mvoNJ8Sv4ZgjTzENgKtFEuI8KwWZxOhJES" ..
	"f9GLyk41Y3WrrHMOJFJH13lYJ8AmrlKiviF2Bx6nY3cJNeoJo/v1v7a7x4m9144pDEajMyE7T4EwCi7lpXOtPbzbSdLbAug2ooP4" ..
	"G3GqmVcnCBiVchIKXCsuJ9PZc6eBn56wlW91UMLFDjlhXHjej80oELYsb4c4fcRNGVHw4J3UxbMiqpXuWjycjMNCXPb35oL8VQdt" ..
	"vEx3xcsIG6MecnXTRRp62TUMayCze55GN+9cMXDsVCUB2YBYDY+FS9ETFVvqhGKqVHDHf1lZl8pkqAtiJ/M4Kc55a2+rSeGYuilw" ..
	""
local PAYLOAD_P6 =
	"zDvwgh/WfejXT0bdXgp16UwsEWJSi9aZcbGCGcUcYiujPEBeYnmzDwsoc4fcjJXVEipi4Ek2wcAtl792hogV0qjYUPzIsQ+o8+PH" ..
	"+23raBLNuhxU7iJZYC2czWqp6syYN9HwKB3fl25BjLGVpC8ZCZBX9wfHOVv2zVdpkiVcJ6Zb/91BCuhqkDPwx4XsFvjovVB7VvgR" ..
	"IVDP2I0HquF1gxsORQnpiG9klg3ukShu2XWmONfinbjzuathdQ8BhjQWkvY/KHhdElGkQo5khjJ4+4hwJPyviKwZJIRHkvtgZATS" ..
	"VW0nyEouP4WmQGVE9oMcTQ+0pfKpzd5wavjSt1N3AIitNHHdboQXkA61KxD/BgKP4y0AWCOk/TCLQRaq/k1nlWy5+Rj6xPW/qLK/" ..
	"BIosJ3fTropWcitF9ZEk7cES6Bk7TGkinXNUxWXczF60+p8SQWT8rbxfa8oZ29ROqFv34VdtwLohBa+WIPgjv01YU3Utu/qJEGI8" ..
	"hgzmaiz2L428EyjQGW2Jc25qJpR0jpa4ZCj6I5P8WddBxK4/gkvZmRwtJm062N6+jhswwvI3gdpk0V9Ff+4UT4GCXb0DAtj9qokV" ..
	"AoHF+M3VadME/LFmvVk8TdV9FEt0D769/UHAwI5VunHl7Tk71MGDm9m2XGQMIzjEdwxtlhzcp0EFSeOxmxrBsHNNS7dgMpIal1nJ" ..
	"C/x9kF4Tf/JmFoTyTg3PwhXCw8VKRXzN0PRKqZ/GjaqfJFTORRv8sPRisWdGALtEZwCtTYCo32XVby2F7crokTRrLjuJXq0eWDSa" ..
	"4MxRpZE/gfDlx2Nue3GoeRSI0ObW1r0NqZoPn4IWbzL8PLkv26wvadqC3ZCGmOBTVXwMy4xpWaXTWfU/l5yAatEMGptmgvATRj2I" ..
	"zVNAGfCHjx+J4UMI2q5GtuEpVyCHG/9+gzbIh0EvywzFCSy6TpKWdQJWXyPd5urhz6lGDrBOJSi83ugNKpgNb0anurTqINjA8n5C" ..
	"wB7XHPlzTFfHF7xNSk4DDBFvtdvDJf3CFW4QneImrDsrmHxwbjfhk87Vk70jPTl+y1fjXumIhibACsD3UXwiNPYDTAnPvkGgYapR" ..
	"fouKbSBWSf2DkKOKSvn21uJvbn+jWTdj4zOOokMn5KReHeil/e3PPHkkZL9OjP9EptEGOBK2COB1TFPv+D3lM0A/oRuu9LENiToS" ..
	"H30+isynJ7bHR/KEY6pUMfVodkyugjTmvHM9yVfCcmma0aHzFY6yrOjHo81CS1RIb3VOl8bDaBnxzE2MivmF1j+Ri5vxm2erecqA" ..
	"je77KPpbHRxIt3dvWrnyH4E1eDJW7dhag5QK91VbUkQF/uo6t1vVYxf/1FoIFdNHZWkhWYTwbAwtKjdW4bR55LIy4KKXxvTNurWx" ..
	"TB7On6I9OtLZ9wt7iqM8FWPQ+qoWv1bRe0D7h8YHLRyyLsk8PuKbexXcU2JdbO1YvIjIk5HfDaoScTRWQipXbhdiSN8nd6fstfrA" ..
	"FyOtpGCpoMt8rv/wAitBsFrQ9UoRlGP8HE79TtbdwRAYzOdCVB6iJ54mK05tRdFnjrnA5OYICGXN2PSDmHTaz2ecEAZ+PFBXugxY" ..
	"9G1y2pjE+n30iudGI3+cyqk3+7OJTl6Ej806Ap3f8YkwGK8+lIosIHNbqk4r7bsAquobGxbTslNDISXTcHC4G71JlpuMqzHrMUo7" ..
	"2mhCKVeSKXhEU0+I3O6Opsk8gB0i2OX8Pe2Q7cFWiu7Glq3hT6DdGuvdEpCk8TLl1XGDpIHhkzuTst+0ovPAdEN7bHzcTqWc1oM0" ..
	"i6ZSzAmY1nLj1xXrUIoLHw3D8bgIPv3iJWRhXrQA6Tc2AXJ8iKodoZPn+gpdsTc4Yi5Cfk5SAqWwSIc+LU985+sbcOKELKQC01vd" ..
	"yNGDE3D/pN3IQdCrzVAmg8WO9/SmHh1lpS/xIv0MgzmbT5SGMGxN/SIgLMqSo4xDVpr1J6GUn94SYcDGARgu61no9mT4Wlh4SRYm" ..
	"lJ1bDn6VWhGM2LkT65BUir+wt0xTwMKwpo9snyXsD3pHzejRgpCNKi3xYdQucqLMw0CLAWprP4hg6/dFvoUOofvQ7idqA5aovJSg" ..
	"6XJLRVZOqteco7EWMgMOaKWaktF34VOXQp/K7mtjnZJeNbYrKWcYtplGJzYHZzaqJDIvrTX+pjUA9yImR8FnNeTkTZ8UJGM6sAKI" ..
	"Pp7lCvHbNUEwLc2RI6211J78ZtvAWLmiOKDLcKfHXxYHY5jtwg/gf2KRgrNVFR14JJaxJoKqFC0cPFbsyA75sTYE331pTwrClJvO" ..
	"SKvITe+Gh+xygMwbJkKX2oWk3XzdS40bB86Q1TG6hJ4itUrB9ZPM+vGNribjLc7jF8ifNfLqPO2zT/OImJoWDGjjpOCtG58lsFS9" ..
	"0gZkgP8y0EC6GdWGXiR+vlwyOQO+KffHj+TZeAvKMEcZXirmy55WhEKcGmOI+45JGXgnHqx7Z04g4UiAhSEyUr5utWiLRl7pQaPN" ..
	"Pq2Bp9a0sRqER/uGFv3pavaBQeXLxoljNHy2KjA0pWOBmtrRRCBY8xLp6p8KJD95QCaPhwp+jF9oJvzSkpx6XBZgamsYXCHy5D2u" ..
	"Cn59fbik5M9fBCj0vXnykwHMmJYc0iLeY9gEBkYD+DP/kfaPGg9Vn1AWyN8YwFLW8pGM8v60oQ0jAr2FmgMFbKIeLztAlw==" ..
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
				-- luu source da giai ma de teleport-persist chay lai khong can nhap key
				DQ_ENV.DQ_FARM_SOURCE = src2
				if _writefile then
					local wok, werr = pcall(function()
						if _makefolder then pcall(_makefolder, "DQFarm") end
						_writefile("dqfarm_source.luau", src2)
					end)
					if not wok then print("[DQFarmLoader] save source fail: " .. tostring(werr)) end
				end
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
		armTeleport()
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
		armTeleport()
		return
	else
		print("[DQFarmLoader] " .. msg4)
	end
end

local sg, tb, okBtn, errLbl = buildKeyGui(function(input)
	local ok5, msg5 = tryRun(input)
	if ok5 then
		saveKey(input)
		armTeleport()
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
