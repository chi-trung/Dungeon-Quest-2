--[[ ============================================================
     DQFarm — Get HWID (ma thiet bi)
     ============================================================
     Chay file nay tren executor cua ban de lay ma may (HWID).
     Gui ma may cho nguoi ban de dang ky key cho may cua ban.
     ]]--

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
	local ex = (getexecutorname and getexecutorname()) or "unknown"
	return ex
end

local hwid = getHwid()
print("[DQFarm] HWID cua may ban la:")
print("[DQFarm] " .. hwid)
game:GetService("StarterGui"):SetCore("SendNotification", {
	Title = "DQFarm HWID",
	Text = "HWID cua may: " .. hwid .. "  (xem console)",
	Duration = 8,
})
