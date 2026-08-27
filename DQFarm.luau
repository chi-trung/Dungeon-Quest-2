--[[ ============================================================
     DQFarm  —  Dungeon Quest Reborn farm overlay
     Source được mã hoá + bảo vệ key. Không thể xem nội dung gốc.
     ============================================================
     CÁCH DÙNG:
       Paste nguyên file này vào executor (Xeno, Solara, ...) rồi Run.
       Nhập KEY khi được hỏi.
     ]]--

-- Fetch loader đã mã hoá từ GitHub (raw)
local loaderUrl = "https://raw.githubusercontent.com/chi-trung/Dungeon-Quest-2/main/DQFarm_loader.luau"

local okGet, res = pcall(function()
	return game:HttpGet(loaderUrl)
end)

if not okGet or not res or #res < 100 then
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = "DQFarm",
		Text = "Loi tai loader (check internet / repo).",
		Duration = 5,
	})
	return
end

local fn, err = loadstring(res)
if not fn then
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = "DQFarm",
		Text = "Loi loadstring: " .. tostring(err),
		Duration = 5,
	})
	return
end

pcall(fn)
