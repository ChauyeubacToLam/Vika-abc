# Squat Voice

Tài liệu này mô tả voice của bài Squat theo đúng code hiện tại trong repo.

Mục tiêu của tài liệu không chỉ là ghi "phát câu gì", mà là chốt rõ:

1. Event nào là nguồn sự thật cho voice.
2. Layer nào sinh dữ liệu, layer nào điều phối playback.
3. Phần nào đã chạy thật trên runtime, phần nào mới dừng ở dữ liệu nền.
4. `feedback`, `instructions` và dữ liệu chốt cuối rep khác nhau ở đâu.
5. Nếu tiếp tục mở rộng, đâu là hướng đi ít rủi ro nhất.

## 1. Bối cảnh nghiệp vụ

Voice của Squat hiện đang phục vụ 6 nhu cầu:

1. Báo thời điểm bài tập bắt đầu thật sự.
2. Gợi phase tiếp theo đủ sớm để user kịp phản ứng.
3. Đếm rep đúng một lần.
4. Nhắc lỗi live quan trọng nhưng có cooldown để tránh spam.
5. Phát feedback sau rep dựa trên dữ liệu đã chốt cuối rep.
6. Báo hoàn thành set.

Ở mức product, flow voice hiện tại của Squat gồm 6 nhóm:

1. `ready cue`: `Sẵn sàng`
2. `phase cue`: `Xuống`, `Giữ`, `Đứng lên`, `Đứng thẳng`
3. `live fault cue`: `Thấp hơn nữa`, `Ưỡn ngực lên`
4. `rep cue`: số rep
5. `post-rep feedback cue`: hiện chỉ phát 1 câu top-priority nếu rep vừa xong không sạch
6. `completion cue`: `Hoàn thành bài tập`

## 2. Responsibility giữa các layer

### 2.1. Exercise layer sinh dữ liệu nghiệp vụ

`Squat` và các metric không gọi TTS trực tiếp. Layer này chịu trách nhiệm:

1. Duy trì state machine của rep.
2. Sinh `currentPhaseKey`.
3. Ghi `resultIssues.instructions[currentPhase]['Status']`.
4. Ghi live feedback vào `resultIssues.feedback`.
5. Tăng `repCount` khi rep hoàn thành.
6. Chốt fault cuối rep trong `_completeRep()`.
7. Build dữ liệu rep-level như:
   - `lastRepFaultVoiceMessages`
   - `lastRepTopVoiceMessage`
   - `lastRepTopVoicePriority`
   - `lastRepWasClean`
   - `setFeedback`

Điểm quan trọng: `priority` được dùng ngay trong `Squat._completeRep()` để sort các fault có `voiceMessage`, rồi chọn ra câu top voice cho rep vừa kết thúc.

### 2.2. `ActiveExercisePage` đã wire Squat voice vào runtime

Khác với version mô tả cũ, screen tập hiện đã nằm trên hot path của voice:

1. Tạo `SquatVoiceCoach` trong `initState()` khi `widget.exercise is Squat`.
2. Forward frame vào coach qua `_processSquatVoiceFrame(...)`.
3. Gọi `_processSquatVoiceFrame(hasPose: true)` sau mỗi `processPose(...)` hợp lệ.
4. Gọi `_processSquatVoiceFrame(hasPose: false)` khi `processNoPoseFrame()` chạy.
5. Dispose coach khi page bị hủy.

Nói ngắn gọn: voice squat hiện không còn là helper "để đó chưa dùng"; nó đã được nối vào runtime của màn tập.

### 2.3. `SquatVoiceCoach` là runtime coordinator

`SquatVoiceCoach` hiện chịu trách nhiệm:

1. Gate voice theo `exerciseState`, `isPaused`, `hasPose`.
2. Phát `Sẵn sàng` ở active frame đầu tiên.
3. Ưu tiên rep count và completion hơn phase/live cue.
4. Phát post-rep feedback ngay sau số rep nếu đủ điều kiện.
5. Map `Status` sang phrase canonical cho TTS.
6. Chọn live fault có ưu tiên cao nhất.
7. Điều phối queue bằng `clearQueue()` và `clearPendingButKeepCurrent()`.
8. Áp cooldown để giảm spam.

Thứ tự ưu tiên thực tế trong `processFrame(...)` là:

1. Nếu set đã `completed`: ưu tiên rep cuối, rồi completion, rồi return.
2. Nếu chưa `activated`, đang `paused`, hoặc mất pose: im lặng và return.
3. Nếu chưa báo ready: phát `Sẵn sàng`.
4. Nếu `repCount` vừa tăng: phát số rep, thử enqueue post-rep feedback, rồi return.
5. Nếu phase/status đổi và không bị trunk cue chặn: phát phase cue.
6. Cuối cùng mới xét live fault cue.

### 2.4. `ViettelTTSService` chỉ lo queue và playback

`ViettelTTSService` không biết squat là gì. Service này chỉ:

1. Nhận text phrase.
2. Ưu tiên phát asset local nếu phrase có trong `_assetMap`.
3. Fallback sang Viettel API nếu asset không có.
4. Quản lý queue playback tuần tự.

## 3. File chịu trách nhiệm chính

Các file quan trọng của flow này:

1. `lib/exercise/exercise_base.dart`
2. `lib/exercise/fault_record.dart`
3. `lib/exercise/squat/squat.dart`
4. `lib/exercise/squat/metrics/squat_depth_metric.dart`
5. `lib/exercise/squat/metrics/trunk_lean_metric.dart`
6. `lib/exercise/squat/metrics/tempo_metric.dart`
7. `lib/services/squat_voice_coach.dart`
8. `lib/services/viettel_tts_service.dart`
9. `lib/screens/exercise/active_exercise_page.dart`

Nếu tiếp tục mở rộng voice squat mà không phá workflow hiện có, gần như chắc chắn sẽ chạm vào đúng 3 tầng:

1. exercise + metrics
2. screen wiring
3. voice coach + TTS queue

## 4. Data contract mà voice đang đọc

Voice của squat không tự tính lại landmark. Nó chỉ đọc dữ liệu đã được exercise layer chuẩn hóa.

### 4.1. Dữ liệu đang được dùng trực tiếp

1. `exercise.exerciseState`
2. `exercise.currentPhaseKey`
3. `exercise.repCount`
4. `exercise.isPaused`
5. `hasPose`
6. `exercise.resultIssues.instructions[currentPhaseKey]?['Status']`
7. `feedback['Depth']`
8. `feedback['Back']`
9. `exercise.lastRepWasClean`
10. `exercise.lastRepTopVoiceMessage`

### 4.2. Dữ liệu đã có nhưng chưa được coach dùng hết

1. `lastRepFaultVoiceMessages`
2. `lastRepTopVoicePriority`
3. `setFeedback`
4. `FaultRecord.priority`

Lưu ý:

1. `FaultRecord.priority` có hiệu lực upstream khi `Squat` chọn `lastRepTopVoiceMessage`.
2. `SquatVoiceCoach` không đọc trực tiếp `priority`; coach chỉ đọc câu top voice đã được exercise layer chọn sẵn.
3. `lastRepFaultVoiceMessages` hiện được build đầy đủ nhưng chưa được phát lần lượt; coach chỉ dùng 1 câu top voice.

## 5. Phân biệt `feedback`, `instructions` và dữ liệu sau rep

Đây là chỗ dễ implement sai nhất.

### 5.1. `resultIssues.feedback`

`feedback` bị clear mỗi frame ở `ExerciseBase.processPose()` và `processNoPoseFrame()`.

Điều đó có nghĩa:

1. `feedback` chỉ hợp cho tín hiệu live.
2. Frame sau hết lỗi là message biến mất ngay.
3. Đây là nơi đúng để map live cue như `Thấp hơn nữa` hoặc `Ưỡn ngực lên`.

### 5.2. `resultIssues.instructions`

`instructions` không bị clear mỗi frame. Nó sống qua nhiều frame cho tới khi exercise chủ động reset.

Ở Squat:

1. `standing` ghi `Status = Xuống`
2. `descending` ghi `Status = Going Down...`
3. `bottom` ghi `Status = Hold! x.xs` hoặc `Đứng lên`
4. `ascending` ghi `Status = Đứng thẳng`

Khi bắt đầu rep mới (`standing -> descending`), `Squat._transitionState()` gọi `resultIssues.instructions.clear()`.

### 5.3. Dữ liệu sau rep

Dữ liệu sau rep phải được chốt ở `_completeRep()`, không suy ngược từ UI.

Ở code hiện tại:

1. `Squat` gom toàn bộ fault của rep.
2. Sort các fault có `voiceMessage` theo `priority`.
3. Build `lastRepFaultVoiceMessages`.
4. Chọn `lastRepTopVoiceMessage`.
5. Ghi `lastRepWasClean`.

`SquatVoiceCoach` hiện đã consume một phần dữ liệu này: nếu rep không clean và đủ cooldown, coach sẽ enqueue đúng 1 câu `lastRepTopVoiceMessage` sau khi đọc số rep.

## 6. Trạng thái implementation hiện tại

### 6.1. Phần đã có và đang chạy thật

1. `Squat` đã có state machine ổn định.
2. `Squat._updatePhaseInstructions()` đã sinh `Status` theo phase.
3. Metrics đã sinh live feedback cho `Depth`, `Back`, `Feet`, `Tempo`, `Sync`.
4. `Squat._completeRep()` đã tăng `repCount` và chốt rep-level voice data.
5. `SquatVoiceCoach` đã xử lý `ready`, `phase`, `live fault`, `rep count`, `post-rep feedback`, `completion`.
6. `ActiveExercisePage` đã forward frame runtime vào `SquatVoiceCoach`.
7. `ViettelTTSService` đã có queue và asset map cho các phrase squat đang dùng.

### 6.2. Phần đã có dữ liệu nhưng chưa được dùng hết

1. `lastRepFaultVoiceMessages` đã có nhưng chưa được đọc tuần tự.
2. `lastRepTopVoicePriority` đã có nhưng coach chưa cần đọc trực tiếp.
3. `FaultRecord.priority` đã có và đang ảnh hưởng upstream, nhưng chưa thành business rule độc lập trong coach.

### 6.3. Phần chưa có trong flow hiện tại

1. Live voice hiện chỉ đọc `Depth` và `Back`; chưa có live voice cho `Feet`, `Tempo`, `Sync`.
2. Post-rep hiện chỉ đọc 1 câu top voice; chưa có multi-message summary.
3. Chưa có user setting riêng cho mute / volume của squat voice.

## 7. Workflow runtime thực tế hiện tại

Flow hiện tại của app là:

1. Camera stream đẩy frame vào `ActiveExercisePage`.
2. `ExerciseBase.processPose()` hoặc `processNoPoseFrame()` update presence, pause state và `feedback`.
3. Nếu bài đã `activated`, `Squat.checkingPose()` chạy state machine và metrics.
4. `Squat._updatePhaseInstructions()` ghi `Status` cho phase hiện tại.
5. Nếu rep hoàn thành, `Squat._completeRep()` tăng `repCount` và chốt dữ liệu rep-level cho voice.
6. `ActiveExercisePage._processSquatVoiceFrame(...)` forward frame hiện tại sang `SquatVoiceCoach`.
7. `SquatVoiceCoach` quyết định có phát `ready`, `phase`, `live fault`, `rep`, `post-rep`, `completion` hay không.
8. `ViettelTTSService` nhận text phrase, xếp queue và playback.

Điểm quan trọng: voice squat hiện đã là flow runtime thật, không còn dừng ở mức "data pipeline có, playback chưa nối".

## 8. Timeline nghiệp vụ của một rep squat

Đây là timeline đúng với code hiện tại:

1. User vào đúng start position và giữ yên đủ `3s`.
2. Exercise chuyển từ `notActivated` sang `activated`.
3. Ở active frame đầu tiên có pose và không paused, coach phát `Sẵn sàng`.
4. Trong phase `standing`, `Status = Xuống`, coach có thể phát `Xuống`.
5. Trong phase `descending`, UI ghi `Going Down...` nhưng coach không đọc câu này.
6. Nếu đang xuống mà `feedback['Depth']` chứa `Go Lower`, coach có thể phát `Thấp hơn nữa`.
7. Nếu `feedback['Back']` chứa `Chest up!`, coach ưu tiên phát `Ưỡn ngực lên`.
8. Khi vào `bottom`, `Status = Hold! x.xs`, coach map thành `Giữ`.
9. Khi hold đủ, `Status` đổi sang `Đứng lên`, coach phát `Đứng lên`.
10. Trong `ascending`, `Status = Đứng thẳng`, coach phát `Đứng thẳng` nếu không bị cue ưu tiên cao hơn chặn.
11. Khi quay về `standing`, `Squat._completeRep()` tăng `repCount`.
12. Coach phát số rep.
13. Nếu rep vừa rồi không clean và top voice đủ điều kiện cooldown, coach enqueue thêm 1 câu post-rep ngay sau số rep.
14. Nếu set kết thúc, coach phát `Hoàn thành bài tập`.

## 9. Phrase dictionary hiện đang được Squat voice dùng thật

### 9.1. Phrase đang được coach gọi

| Nhóm | Phrase |
| --- | --- |
| Ready | `Sẵn sàng` |
| Phase | `Xuống` |
| Phase | `Giữ` |
| Phase | `Đứng lên` |
| Phase | `Đứng thẳng` |
| Live fault | `Thấp hơn nữa` |
| Live fault | `Ưỡn ngực lên` |
| Rep | `1` ... `30` |
| Post-rep | `Ưỡn ngực lên` |
| Post-rep | `Xuống thấp hơn` |
| Post-rep | `Chậm lại` |
| Completion | `Hoàn thành bài tập` |

### 9.2. Asset có trong TTS nhưng Squat coach hiện không gọi

Ví dụ: `Sẵn sàng, xuống`, `Lên`, `Tốt lắm`, `Sai tư thế, chú ý`, `Sẵn sàng, lên`.

Những phrase này có trong `_assetMap`, nhưng không nằm trên flow hiện tại của `SquatVoiceCoach`.

## 10. Trigger matrix bám đúng code hiện tại

| Event | Dữ liệu nguồn | Câu nói | Trạng thái hiện tại |
| --- | --- | --- | --- |
| Ready | `exerciseState == activated`, `!isPaused`, `hasPose`, `_didAnnounceReady == false` | `Sẵn sàng` | Đã chạy thật |
| Phase cue | `instructions[currentPhase]['Status']` qua `_phasePhraseFromStatus(...)` | `Xuống` / `Giữ` / `Đứng lên` / `Đứng thẳng` | Đã chạy thật |
| Live depth fault | `feedback['Depth']` chứa `Go Lower` | `Thấp hơn nữa` | Đã chạy thật |
| Live trunk fault | `feedback['Back']` chứa `Chest up` | `Ưỡn ngực lên` | Đã chạy thật, có ưu tiên cao nhất |
| Rep complete | `repCount > _lastRepCount` | số rep | Đã chạy thật |
| Post-rep feedback | `exercise is Squat`, `!lastRepWasClean`, `lastRepTopVoiceMessage != null`, qua cooldown riêng | top voice của rep | Đã chạy thật |
| Set complete | `exerciseState == completed` | `Hoàn thành bài tập` | Đã chạy thật |

## 11. Giải thích các method quan trọng

### 11.1. `ExerciseBase.processPose()`

Vai trò với voice:

1. Clear `resultIssues.feedback` mỗi frame.
2. Sync presence / pause state.
3. Giữ logic activation `hold still 3s`.
4. Gọi `checkingPose()` khi bài đang active.

Nếu quên tính chất "feedback bị clear mỗi frame", rất dễ chọn sai nguồn dữ liệu cho live voice.

### 11.2. `ExerciseBase.processNoPoseFrame()`

Method này cũng clear `feedback`, sync presence và sinh system message khi:

1. chưa detect được người
2. user ra khỏi khung hình
3. exercise đang bị pause

`ActiveExercisePage` vẫn forward frame kiểu này sang coach với `hasPose: false`, nên coach sẽ im lặng đúng cách khi user mất pose.

### 11.3. `Squat._updatePhaseInstructions(int now)`

Đây là nơi định nghĩa wording cho phase cue:

1. `standing` -> `Xuống`
2. `descending` -> `Going Down...`
3. `bottom` -> `Hold! x.xs` hoặc `Đứng lên`
4. `ascending` -> `Đứng thẳng`

Vì vậy coach nên đọc `Status`, không nên đọc thẳng enum phase.

### 11.4. `Squat._completeRep(RepContext ctx)`

Đây là nơi chốt rep-level data thật sự:

1. `repCount += 1`
2. evaluate depth + tempo cuối rep
3. gom fault từ toàn bộ metrics
4. sort fault có `voiceMessage` theo `priority`
5. build `lastRepFaultVoiceMessages`
6. set `lastRepTopVoiceMessage`
7. set `lastRepTopVoicePriority`
8. set `lastRepWasClean`
9. reset metric cho rep tiếp theo

### 11.5. `ActiveExercisePage._processSquatVoiceFrame({required bool hasPose})`

Đây là call site runtime của squat voice.

Screen hiện tại:

1. chỉ tạo coach cho `Squat`
2. đưa `exercise`, `repCount`, `hasPose`, `_feedback` vào `processFrame(...)`
3. gọi cả ở nhánh có pose lẫn no-pose

### 11.6. `SquatVoiceCoach.processFrame(...)`

Đây là coordinator thật sự của voice squat.

Điểm cần ghi đúng với code:

1. `ready` chỉ được báo một lần cho mỗi instance của coach.
2. Khi rep tăng, coach `return` sớm sau khi phát rep count và enqueue post-rep feedback.
3. Khi set complete, coach ưu tiên nhánh completion và không xét phase/live cue nữa.
4. Nếu trunk cue đủ điều kiện, phase cue cùng frame có thể bị chặn.

### 11.7. `String? SquatVoiceCoach._phasePhraseFromStatus(String? statusText)`

Mapping hiện tại:

1. `Hold...` hoặc chứa `Giữ` -> `Giữ`
2. chứa `Xuống` -> `Xuống`
3. chứa `Đứng lên` hoặc `Lên` -> `Đứng lên`
4. chứa `Đứng thẳng` -> `Đứng thẳng`

Điểm cần nhớ:

1. `Going Down...` hiện không map ra voice.
2. Đây là chủ đích, không phải bug.
3. Cue xuống đã được phát anticipatory từ phase `standing`.

### 11.8. `String? SquatVoiceCoach._highestPriorityLiveFaultVoice(...)`

Business rule hiện tại:

1. `Back=Chest up!` -> `Ưỡn ngực lên`
2. nếu không có trunk fault, `Depth=Go Lower` -> `Thấp hơn nữa`

Điều đó có nghĩa:

1. trunk cue đang có ưu tiên cao nhất trong live faults
2. live voice hiện chưa xét `Feet`, `Tempo`, `Sync`

### 11.9. `void SquatVoiceCoach._enqueuePostRepFeedbackIfAllowed(...)`

Đây là phần quan trọng mà version tài liệu cũ mô tả thiếu.

Coach hiện đã có post-rep feedback với 3 lớp gate:

1. chỉ chạy khi `exercise is Squat` và `lastRepWasClean == false`
2. chỉ chạy khi có `lastRepTopVoiceMessage`
3. cùng một câu phải cách nhau ít nhất `3 reps`
4. nếu câu đó vừa được nói live trong `1.5s` gần nhất thì suppress

Kết quả: post-rep feedback hiện có thật, nhưng mới ở mức một câu top voice cho mỗi rep.

### 11.10. `ViettelTTSService.clearQueue()` và `clearPendingButKeepCurrent()`

Policy queue hiện tại:

1. `clearQueue()` dùng khi bắt đầu session với `Sẵn sàng`, và khi dispose coach.
2. `clearPendingButKeepCurrent()` dùng trước rep count, completion, và trunk cue để ưu tiên cue quan trọng mà không cắt ngang audio đang nói.

## 12. Những chỗ còn "nửa bước"

Đây là các điểm vẫn còn dở dang nếu muốn nâng cấp thêm:

1. `lastRepFaultVoiceMessages` đã có nhưng chưa đọc hết danh sách.
2. `Feet`, `Tempo`, `Sync` đã có feedback/instruction nhưng chưa có live voice mapping trong coach.
3. `lastRepTopVoicePriority` chưa được coach dùng cho rule riêng ngoài việc chọn top voice ở exercise layer.
4. Chưa có cấu hình user-facing cho mute / volume / voice style riêng của squat.

## 13. Acceptance criteria đúng với pha tiếp theo

Nếu tiếp tục implement mà vẫn giữ cấu trúc hiện tại, bước kế tiếp được xem là đúng khi:

1. Không chuyển TTS xuống metric.
2. Không nhét business logic voice vào screen ngoài việc wiring.
3. Nếu muốn post-rep phong phú hơn, consume `lastRepFaultVoiceMessages` thay vì suy từ UI.
4. Nếu thêm live cue mới, update cả `SquatVoiceCoach` lẫn `_assetMap`.
5. Vẫn giữ rep count và completion là cue ưu tiên cao hơn phase/live cue.

## 14. Kết luận

Trạng thái đúng của Squat voice ở repo hiện tại là:

1. Exercise layer đã sinh đúng dữ liệu.
2. `SquatVoiceCoach` đã điều phối được `ready`, `phase`, `live`, `rep`, `post-rep`, `completion`.
3. `ActiveExercisePage` đã wire coach vào runtime.
4. `ViettelTTSService` đã có queue và asset cho các phrase chính.

Nói ngắn gọn: bài toán hiện tại không còn là "nối cho có voice". Voice squat đã chạy trên đường runtime. Việc tiếp theo, nếu cần, là mở rộng độ phong phú của cue và tận dụng nốt dữ liệu rep-level đã có sẵn.
