1. Count reps after each completed rep, and say "Hoàn thành bài tập" when the set ends.
2. Provide phase guidance cues at the right time: "Xuống", "Đẩy lên", and "Giữ".
3. When `trunk_alignment` detects lower-back sag, say "Siết cơ bụng".
4. When `trunk_alignment` detects high hips, say "Hạ hông xuống".
5. Handle voice conflicts with a queue: play messages sequentially, and call `clearQueue()` when a new rep starts.
