1. Count reps after each completed rep, and say "Hoàn thành bài tập" when the set ends.
2. Provide phase guidance cues at the right time: "Mở" and "Đóng".
3. When `leg_spread` detects insufficient leg width, say "Mở chân rộng hơn".
4. Handle voice conflicts with a queue: play messages sequentially, and call `clearQueue()` when a new rep starts.
