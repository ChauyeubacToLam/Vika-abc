VIKA DETAILED GUIDE FOR APP REVIEW
Application: Vika
Bundle ID: com.vikavn.app
Platform: iOS, iPhone

Note for reviewer: This guide explains the screens, permissions, data handling, and exercise flow that reviewers will see in Vika. The interface is in Vietnamese because the first launch market is Vietnam. For each important Vietnamese label, the English meaning is placed in parentheses so the review can be followed without reading Vietnamese. A full screen recording of a complete workout is attached to the App Review submission and can be used as the main visual reference for the end to end flow.

1. Overview

Vika is an AI fitness coach that runs directly on the iPhone. During a workout, Vika uses the front or rear camera to observe the user's body and detect 33 body landmarks. These landmarks allow the app to count repetitions, evaluate exercise form, and play audio coaching cues while the user trains. The pose detection model is Google MediaPipe, an open source model licensed under Apache License 2.0.

The core privacy rule is that camera processing happens on the device. Camera frames and videos are not uploaded, not stored remotely, and not sent to any outside service for pose analysis. After a workout, the app stores only training results such as the number of repetitions, the user's form score, workout history, and related progress data. The privacy policy is shown in full during onboarding, before the camera is used, and again inside the user's profile.

Vika provides general fitness guidance and technique feedback for informational use. It is not a medical device. It does not diagnose, prevent, monitor, or treat any disease or medical condition. Users who have pain, injury, or medical concerns should consult a qualified professional before training.

2. Essential review notes

2.1 Demo account access

The app uses social sign in only. Apple and Google are available, so there is no reviewer username and password. A preloaded demo account is provided so reviewers can see the Plan, Progress, streak, and workout history immediately.

To open the demo account, reach a sign in screen. This can be done by completing onboarding until the screen titled "Lộ trình đã sẵn sàng." (Your plan is ready), or by tapping "Đã có tài khoản? Đăng nhập" (Already have an account? Log in) at the bottom of the first welcome screen. On that sign in screen, press and hold the "Apple" button for a full 5 seconds. A normal quick tap starts the standard Sign in with Apple flow, but the long hold opens reviewer access. When the dialog titled "Reviewer access" appears, enter access code "6886" and tap "Continue". A read only preview of the seeded plan opens. Tap "Enter app" to reach the Home tab of the demo account.

The preview screen is intentionally simple. It states that it is a reviewer preview, shows a read only badge, and displays the seeded plan without generating new data. It helps confirm that the access code has been accepted before the main app opens. After the reviewer taps "Enter app", the app uses the same navigation and screens as a normal account. The seeded account is not a mock page only. It is a real app state with stored workout sessions, form scores, streak data, and plan progress.

The demo account contains about six weeks of seeded workout history. It is intended for review of data rich screens only. Account deletion can be tested, but it should be tested last because deleting the seeded account also removes the seeded workout history used for Plan, Progress, streak, and workout history review.

2.2 Purchases and subscriptions

Vika has no in app purchases and no subscriptions. All content is free and unlocked.

2.3 Guideline sensitive items

Sign in with Apple is offered next to Google on the sign in screen. Account deletion is inside "Hồ sơ" (Profile), then "CÀI ĐẶT" (Settings), then the "Tài khoản" (Account) group, then "Xóa tài khoản" (Delete account). Data export is inside Profile, Settings, the "Quyền riêng tư" (Privacy) group, then "Xuất dữ liệu của bạn" (Export your data). Analytics are optional and can be turned off through the toggle "Chia sẻ dữ liệu sử dụng ẩn danh" (Share anonymous usage data). The age gate appears on the privacy and consent screen during onboarding before the user agrees to the policy, and again on the body metrics screen where users below 16 are blocked. Camera permission is requested at the start of an exercise, and the camera tracking can be tested quickly with the Squat exercise from Explore.

These checks can be reviewed independently. The reviewer does not need to complete several weeks of training before reaching them. We recommend using the demo account for Plan, Progress, and workout history. If account deletion is tested, please test it at the end because the seeded review data will be removed after deletion. Data export, analytics opt out, privacy text, age gate, and Sign in with Apple can be checked in one short pass through onboarding and Profile.

3. Onboarding flow

Onboarding can be reviewed without signing in. The arrow in the top left moves back, and the button at the bottom moves forward. The screen order below is the actual order in the app.

Screen 1 is Welcome. It shows the VIKA wordmark and introduces the product. Tap "Bắt đầu hành trình" (Start the journey) to begin. The same screen also has "Đã có tài khoản? Đăng nhập" (Already have an account? Log in), which opens the standalone login screen. The 5 second reviewer hold on the Apple button also works there.

Screen 2 is "Bạn thấy mình ở đâu?" (Where do you see yourself?). It shows swipeable cards about common training frustrations, such as following videos without knowing whether the movement is correct. Tap at least one card, then continue. This screen explains the problem Vika is designed to solve. The choice does not change the final plan.

Screen 3 is "Một buổi: 400.000 – 2.000.000 ₫" (One personal trainer session costs this much). It compares the cost of a personal trainer in Vietnam with Vika. Tap "Còn cách nào khác?" (Is there another way?) to continue. No input is required.

Screen 4 is "Phản hồi hiện lên ngay khi bạn tập." (Feedback appears as you train). It shows an example of form feedback during a session. Tap "Tôi đã sẵn sàng" (I am ready). After this, onboarding begins the questions that create the recommended plan.

Screens 5 and 6 are used together to decide the recommended track shown on Screen 7.

Screen 5 is the Goal screen. The headline is "Bạn muốn đạt được gì?" (What do you want to achieve?). The goal options are "Sức khoẻ" (Health), "Vóc dáng" (Shape), "Sức mạnh" (Strength), and "Linh hoạt" (Flexibility). The experience options under "KINH NGHIỆM" (Experience) are "Dưới 6 tháng" (Under 6 months), "6 tháng – 2 năm" (6 months to 2 years), and "Trên 2 năm" (Over 2 years). Select one goal and one experience level. These answers influence the suggested track and level.

Screen 6 is the Pain screen. The headline is "Bạn có đang đau ở đâu không?" (Do you have any pain anywhere?). The user can tap areas on a body map or choose "Tôi không đau ở đâu cả" (I have no pain anywhere). This answer also affects the recommendation. For example, if the user chooses "Linh hoạt" (Flexibility) and lower back pain, the Yoga track is recommended. If the user chooses "Sức mạnh" (Strength) and no pain, Home Workout is recommended. The user can still select either track freely.

Screen 7 is Recommended track. The headline is "Chọn thể loại bạn muốn tập." (Choose the style you want to train). The two tracks are "Home Workout" and "Yoga". The recommended option is marked "VIKA ĐỀ XUẤT" (Vika recommends) and "Gợi ý" (Suggested), and it is selected by default. Tap a track, then continue.

Screen 8 is Privacy and consent. The eyebrow is "An toàn & riêng tư" (Safe and private), and the headline is "Trước khi bật camera." (Before turning on the camera). This screen shows the full privacy policy inside the app. It explains on device pose processing, no selling of data, data deletion within 30 days after account deletion, the 16+ minimum age, and the services used. The named services are Supabase in Singapore for account data, Google MediaPipe running on the device for pose detection with no frames sent to Google, Apple and Google for sign in only, and PostHog in the EU for usage analytics connected to the account. The user must tick "Tôi đã đọc và đồng ý với toàn bộ chính sách quyền riêng tư trên." (I have read and agree to the full privacy policy above), then tap "Đồng ý & tiếp tục" (Agree and continue). The button is disabled until the box is ticked.

This consent screen appears before any camera based feature is used. It is meant to make camera processing and account data handling clear before the user begins training. The app does not ask for camera permission on this screen. iOS camera permission is requested later, at the start of the first exercise. Accepting the privacy policy also records consent for usage analytics, and the user can later turn analytics off from Profile without losing access to exercises or the training plan.

Screen 9 is Assessment intro. The eyebrow is "Đánh giá thể lực." (Fitness assessment). This introduces an optional camera assessment. For a fast review, tap "Bỏ qua · đánh giá theo thời gian tập luyện của tôi." (Skip, assess by my training history). A sheet titled "Bỏ qua đánh giá?" (Skip the assessment?) appears. Tap "Bỏ qua, gợi ý theo thời gian bạn đã luyện tập" (Skip, suggest by my training time). The app goes to the level screen and suggests a level based on the experience answer. Reviewers may also run the assessment, but it requires specific movements and is not the quickest camera test.

If the reviewer chooses to run the live assessment, the movements depend on the selected track. For Home Workout, the assessment uses 5 squats and 5 wall push ups. For Yoga, it uses two short holds, Warrior I and a seated forward fold. The assessment checks whether the camera can see the user and whether basic movement quality can be measured, then uses the result to suggest a level. The same on device pose tracking system is used later in normal workouts.

Screen 10 is Level. The eyebrow is "MỨC TẬP" (Training level), and the headline is "Vika gợi ý level:" (Vika suggests a level). The three levels are "Người mới bắt đầu" (Beginner), "Trung cấp" (Intermediate), and "Nâng cao" (Advanced). If the assessment was skipped, "Dưới 6 tháng" suggests Beginner, "6 tháng – 2 năm" suggests Intermediate, and "Trên 2 năm" suggests Advanced. The user can accept the suggestion or choose another level.

Screen 11 is Body metrics. The eyebrow is "Thông số cơ thể" (Body metrics), and the headline is "Một vài số liệu về cơ thể bạn." (A few numbers about your body). Sliders collect "Chiều cao" (Height), "Cân nặng" (Weight), and "Tuổi" (Age). A gender row offers "Nam" (Male), "Nữ" (Female), "Khác" (Other), and "Không muốn trả lời" (Prefer not to say). The default numbers are valid, but the continue button is disabled until a gender choice is made. If age is set below 16, a dialog titled "Chỉ dành cho người từ 16 tuổi trở lên" (Only for people aged 16 and over) appears, and the user cannot continue until age is set back to 16 or above.

Screen 12 is Schedule. The eyebrow is "Lịch tập" (Training schedule), and the headline is "Bạn thường tập lúc nào?" (When do you usually train?). A weekly grid shows days from "T2" to "CN" (Monday to Sunday) and time options "Sáng" (Morning), "Chiều" (Afternoon), and "Tối" (Evening). Three afternoon slots are selected by default. At least two slots are required, so the user can continue immediately or adjust the grid.

Screen 13 is Sign in. The headline is "Lộ trình đã sẵn sàng." (Your plan is ready). The options shown are Apple, Google, and an email login link. A normal tap starts the standard provider sign in. To open the demo account, press and hold Apple for 5 seconds, enter code "6886", and tap "Continue", as described in section 2.1.

4. Main tabs and seeded data

After reviewer access, the app opens with five bottom tabs: "Trang chủ" (Home), "Lộ trình" (Plan), "Khám phá" (Explore), "Tiến bộ" (Progress), and "Hồ sơ" (Profile). The seeded demo account has data in all tabs.

Home shows today's session card with an eyebrow such as "HÔM NAY · BUỔI 03" (Today, session 03), a list of exercises, and a yellow button such as "Bắt đầu Buổi 03" (Start session 03). Below it, the week summary shows completed sessions, the streak tile "LIÊN TIẾP" (In a row), and the form tile "FORM 7 NGÀY" (Form, 7 days).

Plan shows the multi week program assigned to the account. The plan is organized by blocks labeled "TUẦN N" (Week N) and sessions such as "Buổi 1" (Session 1). The dark header shows the completion ring, current block, next session, and a start button. The session list under "SỔ BUỔI" (Session book) can be expanded to see form score and exercise details. The final retest appears as "CHẶNG CUỐI" (Final stage).

Explore is the exercise library. No content is locked. The search field is "Tìm bài tập, bộ tập…" (Find exercises, collections). Tapping an exercise card opens that exercise as a single camera session. Tapping a collection or album card opens a planned sequence. For example, a lower body collection can start with Squat and then continue to the next exercise in that collection. This is the fastest path for testing a single Squat session.

Explore also helps reviewers confirm that content is not locked. Exercise cards can be opened directly, and collections can be opened as planned sequences. The search field is available as the list scrolls, so the Squat test can be found quickly. The library also has filters such as "Tất cả" (All), "Bộ tập" (Collections), and "Bài tập" (Exercises).

Progress shows seeded history. The header tabs are "Tuần này" (This week), "Giai đoạn" (Phase), and "Cả lộ trình" (Whole program). The main areas include "ĐIỂM FORM" (Form score), "TỔNG QUAN TUẦN NÀY" (This week overview), "ĐƯỜNG TIẾN BỘ" (Progress line), "CƠ THỂ" (Body), "BÀI TẬP NỔI BẬT" (Standout exercises), "CỘT MỐC" (Milestones), and "CHUỖI" (Streak). The body map can be used to log pain areas as a personal note, not a medical diagnosis.

Because the demo account is seeded, Progress already contains enough data to show trends rather than empty states. This helps reviewers see how workout completion, form score, milestones, and streaks are presented after multiple sessions. A new account usually needs about three completed sessions before Progress has enough data to show richer trends. The demo account data is sample training history for review purposes and does not require the reviewer to perform weeks of workouts.

Profile shows the avatar, name, join date, goal ring, editable goal card, and editable body metrics card. Settings are under "CÀI ĐẶT" (Settings). The Privacy group includes "Camera xử lý ngay trên điện thoại bạn" (Camera is processed on your phone), the analytics toggle, and data export. The Support group includes help by email and "Về Vika" (About Vika), which contains the app version and the privacy policy link. The Account group includes edit profile, email, sign out, and delete account.

5. Running a workout

There are two common ways to start training. From Home or Plan, tap a yellow button such as "Bắt đầu Buổi 03" (Start session 03) to run a full session with several exercises in order. From Explore, tap any exercise card to run only that exercise. The single exercise path uses the same camera flow and is the easiest way to review the core experience quickly.

A full session and a single exercise both use the same safety and privacy rules. The camera is opened only after the user starts an exercise. The app gives form feedback during the movement, then saves the result only after the exercise or session is completed. Sharing controls are not part of this review build and are hidden because sharing is not a core requirement for the workout flow.

Each exercise begins with an intro screen. It shows a movement demo, a short description, the form points the app will check, and the planned sets and repetitions. A round play button plays a short clip, and the yellow button "Bắt đầu tập" (Start training) opens the camera screen. For exercises after the first one in a sequence, the app first asks how the previous exercise felt, with "Nhẹ" (Light), "Vừa" (Moderate), and "Nặng" (Hard), then shows a countdown with "Bắt đầu ngay" (Start now) and "+30s".

On first use, iOS asks for camera permission. Tap allow. If permission is missing later, Vika shows a prompt with "Cấp quyền" (Grant access). The live camera screen then shows the camera image, the pose skeleton, the rep counter, form feedback, and controls. Each exercise begins with the starting position. For Squat, the prompt is "Vào vị trí bắt đầu" (Get into the starting position). When the user stands still in the starting position, a dial counts 3, 2, 1 and then shows "Sẵn sàng" (Ready). Only after this does the app count repetitions.

The camera works best when the whole body is visible, including the head, shoulders, hips, knees, and feet. Good lighting helps the skeleton appear quickly. The tracker can use the front camera for the person holding the phone or the rear camera for another full body subject in frame. This is why a reviewer can also point the rear camera at the attached squat video to verify the pose skeleton and repetition counter without doing the exercise personally.

During the set, the top left back arrow can leave the session, the top center shows a set indicator such as "Hiệp 1 / 3" (Set 1 of 3), the top right can flip the camera, and the pause button pauses training. When the required repetitions are counted, the app leaves the camera screen automatically.

If another set remains, the rest screen appears. It shows "GIÂY NGHỈ" (Rest seconds), a set label such as "HIỆP 01 / 03" (Set 01 of 03), a tip under "GỢI Ý CHO SET SAU" (Tip for the next set), and the question "SET NÀY CẢM THẤY THẾ NÀO?" (How did this set feel?). The choices are "Nhẹ" (Light), "Vừa" (Moderate), and "Nặng" (Hard). This answer can adjust the next set's repetitions. The screen advances when the rest timer ends, or the user can tap "Bắt đầu set tiếp" (Start the next set).

After the final set, the app skips rest and shows a short transition. It displays the form score for the exercise that was just completed. If more exercises remain, it shows "Bài tiếp theo · {name}" (Next exercise, name). If the session is finished, it shows "Tổng kết buổi tập" (Session summary) and moves to the summary screen.

The summary screen has the eyebrow "TỔNG KẾT BUỔI TẬP" (Session summary). It shows the session form score on a 0 to 105 scale, where up to 5 points may come from a streak bonus. It also shows a per set form chart, highlights, coach notes, and scores for each exercise under "CÁC BÀI ĐÃ TẬP" (Exercises completed). Coach notes can include "CẦN CHÚ Ý" (Watch out for) and "BUỔI SAU" (Next session). Tap "Hoàn thành buổi tập" (Finish the session) to save the result and return to Home.

The saved result is a workout record, not a saved video. It contains items such as completed repetitions, set results, exercise scores, session score, and coach notes. These results are used by Home, Plan, and Progress to update streaks, charts, and the next session state. Camera images are not retained as part of this record.

The user can leave with the back arrow. If a set is active, the app shows "Thoát buổi tập?" (Leave the session?). Choose "Tiếp tục" (Continue) to resume, or "Thoát" (Leave) to exit. Before a set begins, the back arrow exits immediately.

6. Verifying live camera tracking

Each exercise intro screen includes a normal movement demo clip, so reviewers can see the intended movement before opening the camera. The quickest AI tracking test is still Squat. Open "Khám phá" (Explore), tap "Tìm bài tập, bộ tập…" (Find exercises, collections), type "Squat", and open the Squat card. From the Squat intro screen, reviewers can use one of the following checks.

The first check is the built in tracking demo. On the Squat intro screen, press and hold "Bắt đầu tập" (Start training) for 5 seconds. A quick tap starts a real workout, but the long hold opens the demo. A full screen video labeled "BẢN DEMO · THEO DÕI AI" (Demo, AI tracking) plays. It shows pose tracking on a person doing squats, plus rest and summary screens. No physical movement is needed. Tap X to close the demo.

The built in demo is useful when the review environment does not allow a person to stand far enough from the device. It does not replace the real camera path, but it shows the same skeleton, counter, rest, and summary experience in a controlled way.

The second check uses the attached squat video and the rear camera. Start Squat normally by tapping "Bắt đầu tập" (Start training). When the camera opens, tap the camera flip button. Point the rear camera at another screen playing the attached squat video. It helps to pause on a frame where the person is standing upright, wait for the 3, 2, 1 dial to show "Sẵn sàng" (Ready), then play the video. The skeleton follows the full body in frame and the rep counter increases.

The third check is the attached full session recording. From Home or Plan, start a normal session with a button such as "Bắt đầu Buổi 03" (Start session 03). The complete workout video attached to the App Review submission shows the full exercise sequence, camera tracking, rest screens, and workout summary. This lets reviewers compare the end to end in-app flow without needing to physically complete every exercise.

The fourth check is to do the squats directly. Place the phone upright so the front camera sees the whole body from head to feet, ideally from about 1.5 to 2 meters away. Stand facing the camera with feet about shoulder width. Hold still until the starting position locks. Then squat by bending the knees, pushing the hips back, lowering until the thighs are close to parallel with the floor, and standing back up. Pause briefly at the top. Repeat about five times. Shallow squats may not count, so lower enough for the movement to be recognized.

7. Privacy, account controls, age, and health

Privacy is built around on device analysis. MediaPipe runs locally on the iPhone. Camera frames and video are not uploaded, not stored remotely, and not sent to Google or any other service for processing. The app stores training results such as rep count, form score, and workout history. Usage analytics are optional and can be turned off in Profile under the Privacy group.

The app supports Apple and Google sign in. Apple is shown next to Google on the sign in screen. The app also includes data export and account deletion. To delete an account, open "Hồ sơ" (Profile), then "CÀI ĐẶT" (Settings), then "Tài khoản" (Account), then "Xóa tài khoản" (Delete account). A confirmation dialog titled "Xóa tài khoản?" (Delete account?) explains that all data will be permanently deleted and cannot be recovered. Confirming with "Xóa vĩnh viễn" (Delete permanently) deletes the account on the server and returns the app to onboarding.

Data export is in Profile, Settings, the Privacy group, then "Xuất dữ liệu của bạn" (Export your data). It creates a JSON file and opens the iOS share sheet. The email row in the Account group is display only. Sign out is also available in the same Account group.

The minimum age is 16. During onboarding, the privacy and consent screen states the 16+ requirement before the user agrees to the policy. Later in onboarding, the body metrics screen blocks the user if age is below 16. The same body metrics rule applies in the profile body editor, where saving is disabled if the age is set below 16.

Vika is a general fitness and technique feedback app. It is designed to help users understand movement quality, count exercise repetitions, and follow a training plan. It does not diagnose injury, provide medical treatment, or replace professional medical advice.

Pain selections and body notes are used to personalize training suggestions and to help users remember how they felt. They are not presented as clinical findings. If a user reports discomfort, Vika can adjust recommendations, but it still remains a general training application rather than a medical service.

8. Contact

For any question about a Vietnamese screen, reviewer access, the attached workout video, or the expected camera behavior, please use the email and phone number provided in App Review Information. We can provide clarification or walk through any screen in the app.
