1. Count reps after each completed rep, and say "Hoàn thành bài tập" when the set ends.
2. Provide phase guidance cues at the right time: "Lên", "Xuống", and "Giữ".
3. When `hip_extension` detects insufficient hip lift, say "Nâng hông cao hơn".
4. Handle voice conflicts with a queue: play messages sequentially, and call `clearQueue()` when a new rep starts.
