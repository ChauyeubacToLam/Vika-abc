1. Count reps after each completed rep, and say "Hoàn thành bài tập" when the set ends.
2. Provide phase guidance cues at the right time: "Cuộn lên" and "Hạ xuống".
3. When `trunk_elevation` detects insufficient curl-up, say "Cuộn lên thêm".
4. When `neck_pulling` detects neck pulling, say "Không kéo cổ".
5. When `knee_extension` detects knee extension, say "Giữ gối gập".
6. Handle voice conflicts with a queue: play messages sequentially, and call `clearQueue()` when a new rep starts.
