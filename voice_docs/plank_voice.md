1. Count completed holds, and say "Hoàn thành bài tập" when the set ends.
2. Guide the user with "Giữ", speak countdown checkpoints (10, 5), and say "Nghỉ" between holds.
3. When `trunk_alignment` detects sagging lower back, say "Siết cơ bụng".
4. When `trunk_alignment` detects high hips/pike, say "Hạ hông xuống".
5. Handle voice conflicts with a queue: play messages sequentially, and call `clearQueue()` when a new hold starts.
