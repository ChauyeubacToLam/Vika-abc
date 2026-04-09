# Squat Voice

Tài liệu này mô tả cách voice của bài Squat đang được implement trong runtime hiện tại, đồng thời đóng vai trò khuôn mẫu để dev khác có thể dựa vào đó triển khai voice cho các bài tập khác.

Mục tiêu của tài liệu không phải chỉ ghi "phát câu gì", mà là làm rõ 4 thứ:

1. Event nào trong exercise pipeline được xem là nguồn sự thật cho voice.
2. Layer nào chịu trách nhiệm sinh dữ liệu, layer nào chịu trách nhiệm phát tiếng.
3. Vì sao một số câu được phát ngay theo frame, còn một số câu phải chờ theo rep hoặc theo phase.
4. Checklist nào cần giữ nguyên khi port pattern này sang bài tập khác.

## 1. Bối cảnh nghiệp vụ

Voice của Squat phải giải quyết đồng thời 5 nhu cầu:

1. Báo cho user biết khi nào đã bắt đầu buổi tập thật sự.
2. Hướng dẫn phase tiếp theo đủ sớm để user kịp phản ứng.
3. Đếm rep đúng một lần, không bị lặp.
4. Nhắc lỗi form quan trọng khi lỗi đang xảy ra, nhưng không spam.
5. Kết thúc set gọn gàng, không để queue cũ chen vào sau câu hoàn thành.

Khi nhìn dưới góc độ product, voice ở bài Squat được chia thành 4 nhóm:

1. `ready cue`: "Sẵn sàng"
2. `phase cue`: "Xuống", "Giữ", "Đứng lên", "Đứng thẳng"
3. `live fault cue`: "Thấp hơn nữa", "Ưỡn ngực lên"
4. `rep / completion cue`: số rep và "Hoàn thành bài tập"

## 2. Phạm vi responsibility giữa các layer

Phần quan trọng nhất của design này là không để một class ôm toàn bộ logic.

### 2.1. Exercise layer sinh dữ liệu nghiệp vụ

`Squat` và các metric con không trực tiếp gọi TTS. Nhiệm vụ của layer này là:

1. Duy trì state machine của rep.
2. Sinh `currentPhaseKey`.
3. Cập nhật `resultIssues.instructions` cho cue theo phase.
4. Cập nhật `resultIssues.feedback` cho lỗi live theo frame.
5. Tăng `repCount` đúng thời điểm.
6. Chuyển `exerciseState` sang `completed` khi đủ rep.

### 2.2. Screen layer điều phối voice

`ActiveExercisePage` là nơi quyết định:

1. Frame hiện tại có được phép nói không.
2. Nên ưu tiên phase cue, fault cue hay rep count.
3. Khi nào cần dọn queue.
4. Khi nào cần throttle để tránh spam.

Đây là ý đồ đúng. Voice coordinator nên ở layer gần UI/runtime nhất vì nó phải nhìn được toàn bộ bối cảnh: pose có đang mất hay không, exercise có pause hay không, rep có vừa tăng không, set có vừa complete không.

### 2.3. TTS service chỉ lo queue và playback

`ViettelTTSService` không hiểu squat, không hiểu metric, không hiểu rep. Service này chỉ làm 3 việc:

1. Nhận text.
2. Đưa text vào queue.
3. Phát asset local trước, fallback sang API nếu asset chưa có.

## 3. File chịu trách nhiệm chính

Các file quan trọng của flow này:

1. `lib/exercise/exercise_base.dart`
2. `lib/exercise/squat/squat.dart`
3. `lib/exercise/squat/metrics/squat_depth_metric.dart`
4. `lib/exercise/squat/metrics/trunk_lean_metric.dart`
5. `lib/exercise/squat/metrics/tempo_metric.dart`
6. `lib/screens/exercise/active_exercise_page.dart`
7. `lib/services/viettel_tts_service.dart`

Nếu dev muốn copy pattern sang bài khác, gần như chắc chắn sẽ phải chạm vào đúng 3 tầng này:

1. exercise + metrics
2. screen coordinator
3. TTS phrase/assets

## 4. Data contract mà voice đang đọc

Voice của squat không tự tính toán từ landmark. Nó chỉ đọc dữ liệu đã được exercise layer chuẩn hóa sẵn.

### 4.1. Dữ liệu bắt buộc

1. `widget.exercise.exerciseState`
2. `widget.exercise.currentPhaseKey`
3. `widget.exercise.repCount`
4. `widget.exercise.isPaused`
5. `hasPose`
6. `widget.exercise.resultIssues.instructions[currentPhaseKey]?['Status']`
7. `_feedback['Depth']`
8. `_feedback['Back']`

### 4.2. Ý nghĩa của từng nguồn

1. `exerciseState` quyết định có đang ở `notActivated`, `activated` hay `completed`.
2. `currentPhaseKey` cho biết rep đang ở `standing`, `descending`, `bottom` hay `ascending`.
3. `repCount` là nguồn sự thật duy nhất cho việc đọc số rep.
4. `isPaused` và `hasPose` là gate để không phát voice khi người dùng ra khỏi khung hình.
5. `instructions[currentPhase]['Status']` là nguồn sinh phase cue.
6. `feedback['Depth']` và `feedback['Back']` là nguồn sinh live fault cue.

## 5. Điểm quan trọng nhất: phân biệt `feedback` và `instructions`

Đây là chỗ dev rất dễ implement sai khi làm bài mới.

### 5.1. `resultIssues.feedback`

`feedback` bị clear mỗi frame ở `ExerciseBase.processPose()`.

Điều đó có nghĩa:

1. `feedback` chỉ nên dùng cho tín hiệu live, có giá trị ngay ở frame hiện tại.
2. Nếu frame sau không còn lỗi thì message biến mất ngay.
3. Đây là nơi phù hợp để map ra các câu cảnh báo ngắn như "Thấp hơn nữa" hoặc "Ưỡn ngực lên".

### 5.2. `resultIssues.instructions`

`instructions` không bị clear mỗi frame. Nó tồn tại qua nhiều frame cho đến khi exercise chủ động clear.

Ở Squat, `instructions` được dùng cho:

1. Status theo phase hiện tại.
2. Coaching để rep sau sửa lỗi.

Khi bắt đầu rep mới (`standing -> descending`), `Squat._transitionState()` gọi `resultIssues.instructions.clear()`. Đây là cơ chế reset rất quan trọng để voice không đọc lại chỉ dẫn cũ của rep trước.

Kết luận:

1. `feedback` dành cho live fault đang xảy ra.
2. `instructions` dành cho cue mang tính điều hướng hoặc coaching kéo dài hơn một frame.

## 6. Workflow runtime từ camera frame đến câu nói

Flow thực tế của Squat hiện tại như sau:

1. Camera stream đẩy frame vào `ActiveExercisePage._detectPose()`.
2. `ExerciseBase.processPose()` xử lý pose, clear `feedback`, sync presence, check activation, check safety.
3. Nếu bài đã `activated`, `Squat.checkingPose()` chạy state machine và metric update.
4. `Squat._updatePhaseInstructions()` ghi `Status` cho phase hiện tại.
5. Metric layer ghi live feedback như `Depth=Go Lower`, `Back=Chest up!`.
6. Nếu rep hoàn thành, `Squat._completeRep()` tăng `repCount`.
7. Sau khi exercise xử lý xong frame, `ActiveExercisePage._processSquatVoiceFrame()` đọc lại state hiện tại và quyết định phát gì.
8. `ViettelTTSService` xếp câu nói vào queue và phát lần lượt.

## 7. Timeline nghiệp vụ của một rep squat chuẩn

Đây là timeline chuẩn mà dev nên hình dung khi đọc code:

1. User vào đúng tư thế start position và giữ yên đủ 3 giây.
2. Frame activated đầu tiên phát "Sẵn sàng".
3. Khi đang đứng thẳng chờ rep mới, status là "Xuống", voice phát "Xuống".
4. User đi xuống. Trong phase `descending`, UI status là `Going Down...`, nhưng voice không đọc câu này.
5. Khi chạm đáy, status bắt đầu là `Hold! ...s`, voice map thành "Giữ".
6. Khi hold đủ lâu, vẫn ở phase `bottom` nhưng status đổi thành "Đứng lên", voice phát "Đứng lên".
7. Khi user đi lên, phase chuyển sang `ascending`, status là "Đứng thẳng", voice phát "Đứng thẳng".
8. Khi trở lại standing, `repCount` tăng. Voice đọc số rep.
9. Nếu đó là rep cuối cùng, sau số rep sẽ phát "Hoàn thành bài tập".

Điểm đáng chú ý:

1. Voice phase không bám cứng vào enum state.
2. Voice phase bám vào `Status` vì `Status` cho phép cue mang tính anticipatory.
3. Một phase có thể đổi câu voice ngay bên trong cùng phase, ví dụ phase `bottom` đổi từ "Giữ" sang "Đứng lên".

## 8. Phrase dictionary hiện tại của Squat

Các phrase dưới đây phải khớp với key trong `_assetMap` của `ViettelTTSService`.

| Nhóm | Phrase |
| --- | --- |
| Ready | `Sẵn sàng` |
| Phase | `Xuống` |
| Phase | `Giữ` |
| Phase | `Đứng lên` |
| Phase | `Đứng thẳng` |
| Rep | `1` ... `30` |
| Completion | `Hoàn thành bài tập` |
| Live fault | `Thấp hơn nữa` |
| Live fault | `Ưỡn ngực lên` |

## 9. Trigger matrix bám đúng runtime hiện tại

| Event | Điều kiện | Câu nói | Chính sách queue / cooldown |
| --- | --- | --- | --- |
| Ready | Frame đầu tiên thỏa `activated && hasPose && !isPaused` và chưa từng announce ready | `Sẵn sàng` | `clearQueue()` trước khi nói, chỉ 1 lần mỗi session |
| Phase cue | Có `Status` map được sang phrase và `phaseKey` hoặc phrase thay đổi | `Xuống` / `Giữ` / `Đứng lên` / `Đứng thẳng` | Cooldown tối thiểu 250ms |
| Live depth fault | `_feedback['Depth']` chứa `Go Lower` | `Thấp hơn nữa` | Cooldown 3000ms theo từng phrase |
| Live trunk fault | `_feedback['Back']` chứa `Chest up` | `Ưỡn ngực lên` | Cooldown 3000ms theo từng phrase |
| Rep complete | `repCount > _lastVoiceRepCount` | số rep | `clearPendingButKeepCurrent()` rồi enqueue số rep |
| Set complete | `exerciseState == completed` và chưa announce complete | `Hoàn thành bài tập` | `clearPendingButKeepCurrent()` trước completion flow, chỉ 1 lần |

Lưu ý rất quan trọng:

1. Runtime hiện tại dùng `clearPendingButKeepCurrent()`, không dùng `clearQueue()`, cho rep count và completion.
2. Điều này tránh cắt ngang câu đang phát dở, nhưng vẫn loại bỏ phần queue cũ không còn giá trị.

## 10. Giải thích các method quan trọng

### 10.1. `ExerciseBase.processPose()`

Method này là cổng vào chung của mọi exercise.

Vai trò với voice:

1. Clear `resultIssues.feedback` mỗi frame.
2. Đồng bộ person presence để biết khi nào cần pause.
3. Chuyển bài từ `notActivated` sang `activated`.
4. Chạy `checkingPose()` của Squat khi bài đang active.

Nếu dev triển khai voice cho bài khác mà quên đặc tính "feedback bị clear mỗi frame", rất dễ chọn sai nguồn dữ liệu cho voice.

### 10.2. `Squat.checkingPose()`

Đây là main loop của bài Squat khi đã active.

Method này:

1. Tính geometry từ landmark.
2. Build `RepContext`.
3. Đẩy snapshot vào `frameBuffer`.
4. Cập nhật state machine qua `_updateStateBuffer()`.
5. Nếu vừa về standing thì gọi `_completeRep()`.
6. Nếu chưa kết thúc rep thì chạy toàn bộ metric.
7. Ghi `Status` cho phase hiện tại bằng `_updatePhaseInstructions()`.

Nói ngắn gọn: nếu `checkingPose()` chưa sinh đủ dữ liệu chuẩn hóa, voice coordinator sẽ không có gì đáng tin để nói.

### 10.3. `Squat._updatePhaseInstructions(int now)`

Đây là method định nghĩa "business wording" cho từng phase.

Logic hiện tại:

1. `standing` ghi `Status = Xuống`
2. `descending` ghi `Status = Going Down...`
3. `bottom` ghi `Status = Hold! x.xs` nếu còn thời gian giữ, ngược lại ghi `Status = Đứng lên`
4. `ascending` ghi `Status = Đứng thẳng`

Đây là lý do voice coordinator không đọc thẳng `currentPhaseLabel`.

`Status` mới là contract đúng cho voice vì:

1. Nó cho phép anticipatory cue.
2. Nó cho phép thay câu trong cùng một phase.
3. Nó gom business wording vào exercise layer thay vì hard-code ở UI.

### 10.4. `Squat._updateStateBuffer(double kneeAngle, int timestampMs)`

Method này đảm bảo state machine đủ ổn định để voice không bị giật.

Nó kết hợp:

1. Hướng thay đổi của góc gối từ `frameBuffer`
2. `StickyDebouncer` để xác nhận đang đi lên hay đi xuống
3. `Debouncer` cho threshold vào bottom và trở lại standing

Nếu state machine nhiễu, phase cue sẽ nhiễu theo. Vì vậy với bài mới, chất lượng voice phụ thuộc trực tiếp vào độ ổn định của state machine.

### 10.5. `Squat._transitionState(SquatState newState, int timestampMs)`

Đây là hook quan trọng khi đổi phase.

Nó làm 4 việc:

1. Cập nhật `previousSquatState`
2. Chuyển `squatState`
3. Clear `instructions` khi bắt đầu rep mới (`descending`)
4. Báo cho toàn bộ metric biết state đã đổi qua `metric.onStateTransition(...)`

Việc clear `instructions` ở đây là quyết định đúng, vì rep mới không nên kế thừa coaching text cũ một cách mù quáng.

### 10.6. `Squat._completeRep(RepContext ctx)`

Method này là nguồn sinh event rep-complete thực sự.

Nó:

1. Tăng `repCount`
2. Chốt fault cuối rep
3. Ghi `Result`
4. Log dữ liệu rep
5. Reset metric cho rep tiếp theo

Voice không tự phát hiện rep bằng landmark. Voice chỉ nhìn `repCount` sau khi method này chạy xong. Đây là pattern nên giữ cho bài khác.

### 10.7. `ActiveExercisePage._processSquatVoiceFrame({required bool hasPose})`

Đây là voice coordinator của Squat.

Thứ tự ưu tiên trong method này:

1. Nếu không phải squat thì return ngay.
2. Nếu bài đã `completed`, ưu tiên rep cuối và completion.
3. Nếu chưa `activated`, đang `paused`, hoặc mất pose thì im lặng.
4. Nếu đây là frame active đầu tiên thì phát `Sẵn sàng`.
5. Nếu `repCount` vừa tăng thì phát số rep và return sớm.
6. Nếu phase/status đổi thì cân nhắc phát phase cue.
7. Sau cùng mới xét live fault cue.

Quyết định "rep count return sớm" là có chủ đích:

1. Rep count có giá trị cao hơn phase cue và fault cue.
2. Khi rep vừa hoàn thành, queue cũ thường đã lỗi thời.

### 10.8. `String? _phasePhraseFromStatus(String? statusText)`

Method này map text business sang canonical phrase để TTS hiểu.

Mapping hiện tại:

1. Status bắt đầu bằng `Hold` hoặc chứa `Giữ` thì đọc `Giữ`
2. Status chứa `Xuống` thì đọc `Xuống`
3. Status chứa `Đứng lên` hoặc `Lên` thì đọc `Đứng lên`
4. Status chứa `Đứng thẳng` thì đọc `Đứng thẳng`

Điểm cần nhớ:

1. `Going Down...` hiện tại không map ra voice.
2. Điều này là chủ động, không phải bug.
3. Vì cue đi xuống đã được phát từ phase `standing` với status `Xuống`.

### 10.9. `List<String> _liveFaultVoicesFromFeedback(Map<String, String> feedback)`

Method này convert feedback runtime sang voice fault có thể phát ngay.

Mapping hiện tại:

1. `Depth=Go Lower` -> `Thấp hơn nữa`
2. `Back=Chest up!` -> `Ưỡn ngực lên`

Không phải mọi feedback đều được phát ra voice. Chỉ những lỗi:

1. Đang xảy ra ở frame hiện tại
2. Có hành động sửa rõ ràng
3. Đủ ngắn để không cản nhịp tập

### 10.10. `ViettelTTSService.speak()`, `clearQueue()`, `clearPendingButKeepCurrent()`

Đây là 3 API chính mà coordinator đang dùng.

1. `speak(text)` thêm text vào queue tuần tự.
2. `clearQueue()` xóa toàn bộ pending queue và stop luôn audio hiện tại.
3. `clearPendingButKeepCurrent()` chỉ xóa phần pending, còn audio đang nói dở thì để phát xong.

Pattern dùng hiện tại:

1. Dùng `clearQueue()` cho moment bắt đầu session với câu `Sẵn sàng`.
2. Dùng `clearPendingButKeepCurrent()` cho rep count và completion.

Đây là trade-off hợp lý:

1. Lúc bắt đầu bài, cần reset sạch queue cũ.
2. Khi đang tập, không nên cắt ngang âm thanh giữa chừng nếu không thật sự cần thiết.

## 11. Vì sao phase cue của Squat dùng kiểu "anticipatory"

Nếu chỉ đọc tên phase hiện tại, voice sẽ thường chậm hơn chuyển động của user.

Ví dụ:

1. Đợi user thật sự bắt đầu xuống rồi mới đọc "Xuống" thì cue bị muộn.
2. Đợi user thật sự đứng hẳn rồi mới đọc "Đứng thẳng" thì không còn tác dụng dẫn động tác.

Thiết kế hiện tại giải quyết bằng cách:

1. Khi user đang đứng ở đầu rep thì nói `Xuống`
2. Khi user đang giữ đáy xong thì nói `Đứng lên`
3. Khi user đang đi lên thì nói `Đứng thẳng`

Với bài mới, dev nên nghĩ theo câu hỏi:

1. User cần nghe câu nào để làm hành động kế tiếp?
2. Chứ không phải: phase hiện tại tên là gì?

## 12. Workflow implement để port sang bài tập khác

Đây là workflow mình khuyến nghị giữ nguyên.

### Bước 1. Chốt phrase nghiệp vụ trước khi code

Trả lời rõ 4 câu hỏi:

1. Bài này có những phase cue nào?
2. Live fault nào đủ quan trọng để phát voice?
3. Rep complete đọc gì?
4. Set complete đọc gì?

Nguyên tắc:

1. Mỗi phrase phải ngắn.
2. Mỗi phrase phải mang hành động sửa rõ ràng.
3. Phrase text phải khớp key TTS asset nếu muốn chạy offline nhanh.

### Bước 2. Chuẩn hóa state machine của exercise

Exercise mới phải expose được:

1. `currentPhaseKey`
2. `currentPhaseLabel`
3. thời điểm rep complete
4. điều kiện set complete

Nếu state machine còn rung, đừng implement voice quá sớm. Sửa state machine trước.

### Bước 3. Tách nguồn dữ liệu phase cue và live fault cue

Nên follow đúng pattern của Squat:

1. `instructions[currentPhase]['Status']` cho phase cue
2. `feedback[key]` cho live fault cue

Không nên dùng chung một map cho cả hai nhóm vì vòng đời dữ liệu khác nhau.

### Bước 4. Đặt business wording ở exercise layer

Exercise phải tự quyết định status text cho từng phase, ví dụ:

1. phase nào thì nói "Mở"
2. phase nào thì nói "Đóng"
3. phase nào thì nói "Đẩy lên"

Screen chỉ nên map status text sang canonical phrase, không nên tự nghĩ business wording.

### Bước 5. Viết voice coordinator ở screen layer

Coordinator cho bài mới nên giữ skeleton gần giống Squat:

```dart
void _processExerciseVoiceFrame({required bool hasPose}) {
  final state = widget.exercise.exerciseState;
  final phaseKey = widget.exercise.currentPhaseKey;
  final repCount = widget.exercise.repCount;
  final repIncreased = repCount > _lastVoiceRepCount;

  if (state == ExerciseState.completed) {
    // rep cuối + completion
    return;
  }

  if (state != ExerciseState.activated || widget.exercise.isPaused || !hasPose) {
    // gate toàn bộ voice
    return;
  }

  // ready cue
  // rep cue
  // phase cue
  // live fault cue
}
```

Điều quan trọng không phải tên method, mà là thứ tự ưu tiên ở bên trong.

### Bước 6. Thêm asset và mapping vào TTS service

Nếu bài mới có phrase mới:

1. thêm file mp3 vào `assets/audio`
2. thêm key vào `_assetMap`
3. bảo đảm text phrase trong coordinator khớp tuyệt đối với key map

Sai 1 dấu cách hoặc khác text là app sẽ fallback sang API, gây tăng độ trễ.

### Bước 7. Kiểm thử theo event timeline, không chỉ nhìn UI

Với bài mới, luôn test theo dạng timeline:

1. event nào phát sinh
2. câu nào được enqueue
3. câu nào bị drop vì cooldown
4. câu nào bị xóa khỏi pending queue

Nếu chỉ nhìn "nghe có vẻ ổn", dev rất dễ bỏ sót lỗi race condition hoặc stale queue.

## 13. Checklist để dùng Squat làm template cho bài khác

### 13.1. Phần có thể copy gần như nguyên mẫu

1. Cấu trúc coordinator trong screen
2. Biến state phục vụ voice như `_lastVoicePhaseKey`, `_lastVoiceRepCount`, `_lastFaultVoiceAtMs`
3. Cơ chế throttle theo phrase
4. TTS queue policy
5. Quy ước rep count lấy từ `repCount` thay vì tự detect lại trong screen

### 13.2. Phần phải customize cho từng bài

1. State machine
2. Status text theo phase
3. Mapping từ feedback sang live fault voice
4. Phrase dictionary
5. Điều kiện rep complete
6. Điều kiện set complete

### 13.3. Những lỗi phổ biến cần tránh

1. Gọi TTS trực tiếp trong metric.
2. Dùng text UI dài dòng làm voice phrase.
3. Không clear instruction khi rep mới bắt đầu.
4. Dùng `feedback` cho dữ liệu cần sống qua nhiều frame.
5. Không throttle live fault cue.
6. Cắt ngang audio quá mạnh bằng `clearQueue()` ở mọi event.
7. Tự suy rep complete ở screen thay vì tin vào `repCount`.

## 14. Acceptance criteria cho Squat hiện tại

Implementation được xem là đúng khi thỏa tất cả điều sau:

1. Sau khi activate thành công, app chỉ nói `Sẵn sàng` đúng một lần.
2. Trong rep chuẩn, user nghe được chuỗi cue hợp lý theo nhịp: `Xuống` -> `Giữ` -> `Đứng lên` -> `Đứng thẳng` -> số rep.
3. `Thấp hơn nữa` không lặp liên tục từng frame khi user đang shallow squat.
4. `Ưỡn ngực lên` không spam liên tục khi user đang gập thân trước.
5. Khi mất pose hoặc bài bị pause, voice im lặng.
6. Khi rep vừa hoàn thành, số rep có ưu tiên cao hơn phase cue/fault cue còn tồn trong queue.
7. Khi hoàn thành set, `Hoàn thành bài tập` chỉ phát một lần.

## 15. Gợi ý refactor cho tương lai

Design hiện tại chạy tốt cho Squat, nhưng nếu số bài có voice tăng lên, nên cân nhắc tách một abstraction chung như:

1. `ExerciseVoiceCoordinator`
2. `ExerciseVoiceConfig`
3. `VoiceEvent`
4. `VoicePhraseResolver`

Khi đó mỗi bài chỉ cần cung cấp:

1. phase status resolver
2. live fault resolver
3. rep/completion phrase config

Tuy nhiên ở thời điểm hiện tại, việc giữ logic ngay trong `ActiveExercisePage` vẫn chấp nhận được vì:

1. Squat là bài đầu tiên có flow voice hoàn chỉnh nhất.
2. Logic đang còn mang tính khám phá nghiệp vụ.
3. Chúng ta vẫn cần thêm 1-2 bài nữa để rút ra abstraction đủ đúng.

## 16. Kết luận

Voice của Squat đang đi theo một pattern tốt và đáng tái sử dụng:

1. Exercise layer sinh dữ liệu nghiệp vụ.
2. Screen layer điều phối thứ tự ưu tiên và queue policy.
3. TTS service chỉ lo playback.

Nếu dev khác muốn implement voice cho bài mới, hãy giữ nguyên triết lý đó. Đừng bắt đầu từ việc "thêm vài câu speak()". Hãy bắt đầu từ việc xác định event contract giữa exercise, UI coordinator và TTS.
