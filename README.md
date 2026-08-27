# DQFarm — Dungeon Quest Reborn overlay

Clean, draggable menu với:
- **Speed slider** (16 → 300)
- **Auto-kill** (teleport trên đầu enemy + swing)
- **Auto Skill Q+E** (cooldown-aware)
- **Height adjustment** (+/− buttons, 2→25 studs)

## Cách dùng

1. **Mua key** từ người bán (DM)
2. Mở **DQFarm.luau** → copy toàn bộ → paste vào executor → Run
3. Nhập key khi được hỏi → nhấn RUN

## Files

| File | Mô tả |
|------|-------|
| `DQFarm.luau` | Loadstring wrapper — **paste vào executor** |
| `DQFarm_loader.luau` | Mã hoá, tự động fetch bởi wrapper |

## Lưu ý

- Source gốc được mã hoá — không thể đọc / chỉnh sửa
- Mỗi người dùng có key riêng
- Sai key → không chạy được