1. Count reps after each completed rep, and say "Hoàn thành bài tập" when the set ends.
2. Provide phase guidance cues at the right time: "Xuống", "Đứng lên", and "Giữ".
3. When `lunge_depth` detects insufficient depth, say "Xuống thấp hơn".
4. When `heel_lift` detects heel lifting, say "Giữ gót chân".
5. Handle voice conflicts with a queue: play messages sequentially, and call `clearQueue()` when a new rep starts.
