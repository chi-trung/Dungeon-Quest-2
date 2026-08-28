# DQFarm — Dungeon Quest Reborn overlay

Clean, draggable menu với:
- **Speed slider** (16 → 300)
- **Auto-kill** (teleport trên đầu enemy + swing)
- **Auto Skill Q+E** (cooldown-aware)
- **Height adjustment** (+/− buttons, 2→25 studs)

## Cách dùng

1. **Mua key** từ người bán (DM)
2. **Chạy `get_hwid.luau`** trên executor để lấy mã máy (nếu key là loại 1/2 thiết bị) → gửi mã máy cho người bán
3. Mở **DQFarm.luau** → copy toàn bộ → paste vào executor → Run
4. Nhập key khi được hỏi → nhấn RUN

## Phân loại key theo thiết bị

| Loại | Mô tả |
|------|-------|
| **1 thiết bị** | Key chỉ chạy được trên 1 mã máy duy nhất bạn đăng ký |
| **2 thiết bị** | Key chạy được trên 2 mã máy |
| **Nhiều thiết bị** | Key chạy thoải mái, không giới hạn |

- Key có hạn dùng → hết hạn sẽ không chạy được
- Thay đổi thiết bị → phải liên hệ người bán để cập nhật mã máy

## Files

| File | Mô tả |
|------|-------|
| `DQFarm.luau` | Loadstring wrapper — **paste vào executor** |
| `DQFarm_loader.luau` | Mã hoá, tự động fetch bởi wrapper |
| `get_hwid.luau` | Lấy mã máy (HWID) — dùng cho key 1/2 thiết bị |

## Lưu ý

- Source gốc được mã hoá — không thể đọc / chỉnh sửa
- Mỗi người dùng có key riêng
- Sai key / sai thiết bị / hết hạn → không chạy được