# Kịch bản âm thanh cho toàn bộ bài tập

Tài liệu này dùng để tạo file âm thanh cho các bài tập trong ứng dụng. Chỉ các câu ở cột `Câu nói`, `Khi đang tập` và `Nhắc đầu hiệp sau` là nội dung được phát ra cho người tập. Các mã file như `voice_id`, `fault_id`, `setup_intro` chỉ là mã kỹ thuật, không đọc thành tiếng.

Nguyên tắc viết câu:

- Nói bằng tiếng Việt, không đọc tiếng Anh trong file âm thanh.
- Dùng `lần` thay cho `rep`.
- Dùng `hiệp` thay cho `set`.
- Dùng `tư thế` thay cho `form`.
- Dùng `điện thoại` thay cho `camera`.
- Câu ngắn, trực tiếp, một câu chỉ nhắc một việc.
- Khi người tập sai, ưu tiên nhắc lỗi quan trọng nhất. Không phát quá hai câu sửa lỗi liên tiếp.
- Từ hiệp 2 trở đi, phát câu vào lại tư thế, rồi nhắc tối đa hai lỗi hay gặp nhất ở hiệp trước.

## Câu dùng chung

| Mã file | Câu nói | Dùng khi |
|---|---|---|
| common.finding_person | Đứng vào giữa khung hình để Vika thấy bạn. | Chưa thấy người |
| common.keep_full_body | Giữ cả người trong khung hình. | Người bị cắt khỏi khung hình |
| common.hold_still | Giữ yên 3 giây để bắt đầu. | Đã vào đúng tư thế chuẩn bị |
| common.ready | Sẵn sàng. | Bắt đầu tập |
| common.start | Bắt đầu. | Sau câu sẵn sàng |
| common.good_1 | Đúng rồi. | Lần tập đúng |
| common.good_2 | Tốt, làm tiếp. | Lần tập đúng |
| common.good_3 | Giữ nhịp này. | Lần tập đúng |
| common.good_4 | Chuẩn rồi. | Lần tập đúng |
| common.fix_pose | Chỉnh tư thế. | Có lỗi nhưng vẫn tiếp tục được |
| common.no_count | Lần này chưa tính. | Lần tập không hợp lệ |
| common.rest | Nghỉ một chút. | Hết hiệp |
| common.set_complete | Xong hiệp này. | Hết hiệp |
| common.exercise_complete | Hoàn thành bài tập. | Hết bài |
| common.next_set | Vào hiệp tiếp theo. | Bắt đầu hiệp mới |

## Số lần

| Mã file | Câu nói | Mã file | Câu nói |
|---|---|---|---|
| common.count_1 | Một. | common.remaining_1 | Còn 1 lần nữa. |
| common.count_2 | Hai. | common.remaining_2 | Còn 2 lần nữa. |
| common.count_3 | Ba. | common.remaining_3 | Còn 3 lần nữa. |
| common.count_4 | Bốn. | common.remaining_4 | Còn 4 lần nữa. |
| common.count_5 | Năm. | common.remaining_5 | Còn 5 lần nữa. |
| common.count_6 | Sáu. | common.remaining_6 | Còn 6 lần nữa. |
| common.count_7 | Bảy. | common.remaining_7 | Còn 7 lần nữa. |
| common.count_8 | Tám. | common.remaining_8 | Còn 8 lần nữa. |
| common.count_9 | Chín. | common.remaining_9 | Còn 9 lần nữa. |
| common.count_10 | Mười. | common.remaining_10 | Còn 10 lần nữa. |
| common.count_11 | Mười một. | common.remaining_11 | Còn 11 lần nữa. |
| common.count_12 | Mười hai. | common.remaining_12 | Còn 12 lần nữa. |
| common.count_13 | Mười ba. | common.remaining_13 | Còn 13 lần nữa. |
| common.count_14 | Mười bốn. | common.remaining_14 | Còn 14 lần nữa. |
| common.count_15 | Mười lăm. | common.remaining_15 | Còn 15 lần nữa. |
| common.count_16 | Mười sáu. | common.remaining_16 | Còn 16 lần nữa. |
| common.count_17 | Mười bảy. | common.remaining_17 | Còn 17 lần nữa. |
| common.count_18 | Mười tám. | common.remaining_18 | Còn 18 lần nữa. |
| common.count_19 | Mười chín. | common.remaining_19 | Còn 19 lần nữa. |
| common.count_20 | Hai mươi. | common.remaining_20 | Còn 20 lần nữa. |
| common.count_21 | Hai mươi mốt. | common.remaining_21 | Còn 21 lần nữa. |
| common.count_22 | Hai mươi hai. | common.remaining_22 | Còn 22 lần nữa. |
| common.count_23 | Hai mươi ba. | common.remaining_23 | Còn 23 lần nữa. |
| common.count_24 | Hai mươi bốn. | common.remaining_24 | Còn 24 lần nữa. |
| common.count_25 | Hai mươi lăm. | common.remaining_25 | Còn 25 lần nữa. |
| common.count_26 | Hai mươi sáu. | common.remaining_26 | Còn 26 lần nữa. |
| common.count_27 | Hai mươi bảy. | common.remaining_27 | Còn 27 lần nữa. |
| common.count_28 | Hai mươi tám. | common.remaining_28 | Còn 28 lần nữa. |
| common.count_29 | Hai mươi chín. | common.remaining_29 | Còn 29 lần nữa. |
| common.count_30 | Ba mươi. | common.remaining_30 | Còn 30 lần nữa. |

## Squat - Ngồi xuống đứng lên

| Mã file | Câu nói |
|---|---|
| squat.setup_intro | Đặt điện thoại ngang hông. Quay ngang người để thấy vai, hông, gối và bàn chân. |
| squat.setup_position | Hai chân rộng bằng vai. Mũi chân hơi mở. Ngực hướng lên. |
| squat.active_intro | Đẩy hông ra sau. Giữ gót chân chạm sàn. Xuống chậm rồi đứng lên. |
| squat.good_clean | Đúng rồi, rất chắc. |
| squat.set_next_setup | Hiệp này quay ngang người lại. Chân rộng bằng vai, ngực mở. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| heel | Ấn gót chân xuống sàn. | Hiệp này giữ gót chân chạm sàn. |
| depth | Xuống thấp hơn một chút. | Hiệp này hạ mông thấp hơn. |
| trunk | Nâng ngực lên, đừng gập lưng. | Hiệp này giữ ngực mở khi xuống. |
| tempo | Chậm lại, đừng thả rơi người. | Hiệp này xuống chậm hơn. |
| sync | Đứng lên cùng lúc bằng hông và ngực. | Hiệp này đừng để hông lên trước. |

## Plank - Chống người bằng cẳng tay

| Mã file | Câu nói |
|---|---|
| plank.setup_intro | Đặt điện thoại thấp ngang thân. Quay ngang người để thấy vai, hông, gối và chân. |
| plank.setup_position | Chống bằng cẳng tay. Khuỷu tay nằm dưới vai. Duỗi người thẳng. |
| plank.active_intro | Siết bụng nhẹ. Thở đều. Giữ đầu, lưng, hông và chân thẳng hàng. |
| plank.hold_good | Tốt, giữ yên như vậy. |
| plank.set_next_setup | Hiệp này chống lại bằng cẳng tay. Khuỷu tay dưới vai, người thẳng. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| trunk_sag | Nâng hông lên một chút. | Hiệp này đừng để lưng võng. |
| trunk_pike | Hạ hông xuống một chút. | Hiệp này đừng đưa mông quá cao. |
| neck | Giữ cổ thẳng, mắt nhìn xuống sàn. | Hiệp này thả lỏng cổ. |
| knee | Duỗi thẳng đầu gối. | Hiệp này giữ chân dài hơn. |

## Lunge - Bước chân hạ gối

| Mã file | Câu nói |
|---|---|
| lunge.setup_intro | Đặt điện thoại ngang hông. Quay ngang người để thấy rõ hai chân. |
| lunge.setup_position | Bước một chân lên trước. Chân sau ở phía sau. Người đứng thẳng. |
| lunge.active_intro | Hạ người xuống chậm. Gối trước đi theo hướng mũi chân. Rồi đứng lên. |
| lunge.good_clean | Tốt, tư thế chắc. |
| lunge.set_next_setup | Hiệp này bước chân đủ dài. Giữ người thẳng trước khi hạ xuống. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| depth | Xuống thấp hơn một chút. | Hiệp này hạ gối sau gần sàn hơn. |
| too_deep | Đừng xuống quá sâu. Đứng lên một chút. | Hiệp này xuống vừa đủ, không ép gối. |
| heel | Giữ gót chân trước chạm sàn. | Hiệp này ấn lực qua gót chân trước. |
| trunk | Nâng ngực lên, giữ lưng thẳng. | Hiệp này đừng đổ người về trước. |
| lumbar | Siết bụng, đừng võng lưng. | Hiệp này giữ bụng chắc hơn. |

## Jumping Jack - Nhảy dang tay chân

| Mã file | Câu nói |
|---|---|
| jumping_jack.setup_intro | Lùi xa điện thoại. Khi dang tay chân, cả người vẫn phải nằm trong khung hình. |
| jumping_jack.setup_position | Đứng thẳng. Hai chân khép. Hai tay xuôi theo thân. |
| jumping_jack.active_intro | Nhảy mở tay chân cùng lúc. Rồi khép lại cùng lúc. Giữ nhịp đều. |
| jumping_jack.good_clean | Đúng rồi, nhịp đều. |
| jumping_jack.set_next_setup | Hiệp này đứng giữa khung hình. Chừa chỗ phía trên đầu cho tay vươn cao. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| arms | Vươn tay cao hơn. | Hiệp này đưa tay cao qua đầu rõ hơn. |
| legs | Mở chân rộng hơn. | Hiệp này mở chân rõ hơn khi nhảy ra. |
| tempo_fast | Chậm lại, giữ tư thế. | Hiệp này đừng nhảy quá nhanh. |
| tempo_slow | Nhanh hơn một chút. | Hiệp này giữ nhịp đều hơn. |

## Push Up - Chống đẩy

| Mã file | Câu nói |
|---|---|
| push_up.setup_intro | Đặt điện thoại thấp ngang thân. Quay ngang người để thấy vai, tay và hông. |
| push_up.setup_position | Chống tay cao. Tay nằm dưới vai. Người thẳng từ vai đến gót chân. |
| push_up.active_intro | Hạ ngực xuống chậm. Giữ bụng chắc. Rồi đẩy người lên. |
| push_up.good_clean | Tốt, chống đẩy gọn. |
| push_up.set_next_setup | Hiệp này chống tay cao trước. Tay dưới vai, người thẳng. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| depth | Hạ ngực thấp hơn một chút. | Hiệp này xuống sâu hơn trước khi đẩy lên. |
| tempo | Hạ người chậm lại. | Hiệp này đừng thả rơi người. |
| sag | Siết bụng, đừng để hông võng. | Hiệp này giữ bụng chắc hơn. |
| pike | Hạ hông xuống, giữ người thẳng. | Hiệp này đừng đẩy hông lên cao. |
| setup_guard | Giữ tư thế chống tay cao trước khi bắt đầu. | Hiệp này giữ đúng tư thế rồi mới xuống. |

## Glute Bridge - Nâng hông

| Mã file | Câu nói |
|---|---|
| glute_bridge.setup_intro | Đặt điện thoại thấp ngang sàn. Quay ngang người để thấy vai, hông, gối và bàn chân. |
| glute_bridge.setup_position | Nằm ngửa. Co gối. Đặt bàn chân trên sàn. Tay thả hai bên. |
| glute_bridge.active_intro | Siết mông để nâng hông. Giữ cổ thả lỏng. Hạ hông xuống chậm. |
| glute_bridge.good_clean | Tốt, hông nâng chắc. |
| glute_bridge.set_next_setup | Hiệp này nằm lại. Bàn chân chắc trên sàn, đầu và cổ thả lỏng. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| hip_extension | Nâng hông cao hơn. | Hiệp này siết mông ở điểm cao nhất. |
| lumbar | Đừng ưỡn lưng. | Hiệp này nâng bằng mông, không bẻ lưng dưới. |
| knee_angle | Đặt chân xa hông hơn một chút. | Hiệp này chỉnh bàn chân xa hông hơn. |
| neck | Giữ đầu và cổ nằm trên sàn. | Hiệp này đừng ngẩng đầu. |
| speed | Hạ hông chậm lại. | Hiệp này hạ chậm hơn. |

## McGill Curl-up - Gập bụng ngắn

| Mã file | Câu nói |
|---|---|
| curl_up.setup_intro | Đặt điện thoại thấp ngang thân. Quay ngang người để thấy tai, vai, hông và gối. |
| curl_up.setup_position | Nằm ngửa. Một gối co, một chân duỗi. Giữ cổ thẳng. |
| curl_up.active_intro | Chỉ nâng nhẹ đầu và vai khỏi sàn. Đừng kéo cổ. Rồi hạ xuống chậm. |
| curl_up.good_clean | Đúng rồi, nâng vừa đủ. |
| curl_up.set_next_setup | Hiệp này nằm lại. Một gối co, cổ giữ thẳng. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| knee_extension | Co gối lại. | Hiệp này giữ một gối co rõ hơn. |
| neck_pull | Đừng kéo cổ. | Hiệp này nâng bằng bụng, không dùng cổ. |
| trunk_high | Lên thấp hơn thôi. Chỉ nhấc vai khỏi sàn. | Hiệp này nâng ít hơn để bảo vệ lưng. |
| trunk_low | Cuộn người cao hơn một chút. | Hiệp này nhấc vai rõ hơn khỏi sàn. |

## Warrior I - Chiến binh một

| Mã file | Câu nói |
|---|---|
| warrior_one.setup_intro | Đặt điện thoại ngang hông. Quay ngang người để thấy hai chân, hông, vai và tay. |
| warrior_one.setup_position | Bước một chân lên trước. Chân sau duỗi. Hai tay vươn lên cao. |
| warrior_one.active_intro | Giữ người cao. Chân sau duỗi dài. Cổ thoải mái. Thở đều. |
| warrior_one.hold_good | Tốt, giữ rất vững. |
| warrior_one.set_next_setup | Hiệp này bước chân đủ dài. Tay vươn cao, người thẳng. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| trunk | Đứng thẳng hơn, đừng gập người. | Hiệp này giữ người cao hơn. |
| cervical | Nhìn thẳng. Đừng ngửa cổ. | Hiệp này thả lỏng cổ. |
| arms | Vươn tay cao hơn. | Hiệp này giữ tay dài qua đầu. |
| back_knee | Duỗi thẳng chân sau hơn. | Hiệp này siết đùi để chân sau vững. |
| back_straight | Mở ngực, kéo dài lưng. | Hiệp này đừng gù lưng. |

## Bird Dog - Tay chân đối diện

| Mã file | Câu nói |
|---|---|
| bird_dog.setup_intro | Đặt điện thoại hơi chéo để thấy toàn thân trên thảm. |
| bird_dog.setup_position | Chống hai tay và hai gối. Tay dưới vai, gối dưới hông, lưng phẳng. |
| bird_dog.active_intro | Giơ tay và chân đối diện. Vươn dài. Giữ 2 giây rồi đổi bên. |
| bird_dog.good_clean | Tốt, hông giữ cân bằng. |
| bird_dog.set_next_setup | Hiệp này chống lại bốn điểm. Lưng phẳng, tay dưới vai. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| opposite_side | Giơ tay và chân đối diện. | Hiệp này đừng giơ cùng bên. |
| alternate | Đổi sang bên còn lại. | Hiệp này đổi bên sau mỗi lần. |
| alignment | Vươn dài tay và chân. | Hiệp này giữ tay chân thẳng hơn. |
| head | Nâng đầu nhẹ, mắt nhìn xuống thảm. | Hiệp này đừng cúi đầu quá thấp. |
| lumbar | Hạ chân xuống ngang thân. | Hiệp này đừng đá chân quá cao. |
| hold | Giữ 2 giây ở điểm cao nhất. | Hiệp này giữ đủ lâu rồi mới hạ. |
| trunk | Siết bụng, giữ hông cân bằng. | Hiệp này đừng để hông lệch. |

## V-Up - Gập người chữ V

| Mã file | Câu nói |
|---|---|
| v_up.setup_intro | Đặt điện thoại ngang sàn. Quay ngang người để thấy tay, thân, chân và bàn chân. |
| v_up.setup_position | Nằm ngửa. Tay duỗi qua đầu. Chân duỗi thẳng. |
| v_up.active_intro | Nâng tay và chân cùng lúc. Chạm gần mũi chân. Rồi hạ xuống chậm. |
| v_up.good_clean | Đúng rồi, tay và chân lên cùng lúc. |
| v_up.set_next_setup | Hiệp này nằm thẳng lại. Tay qua đầu, chân duỗi dài. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| sync | Nâng tay và chân cùng lúc. | Hiệp này đừng để thân lên trước. |
| rom | Rướn tay gần mũi chân hơn. | Hiệp này gập người sâu hơn. |
| jerking | Đừng giật lấy đà. | Hiệp này dùng bụng để nâng người. |
| knee | Giữ thẳng đầu gối. | Hiệp này duỗi chân dài hơn. |
| tempo | Hạ xuống chậm lại. | Hiệp này đừng thả rơi người. |

## Dead Bug - Hạ tay chân đối diện

| Mã file | Câu nói |
|---|---|
| dead_bug.setup_intro | Đặt điện thoại để thấy rõ tay, gối, hông và bàn chân. |
| dead_bug.setup_position | Nằm ngửa. Tay đưa lên. Gối gập vuông góc. Ép nhẹ lưng xuống sàn. |
| dead_bug.active_intro | Hạ tay và chân đối diện. Giữ lưng sát sàn. Kéo về rồi đổi bên. |
| dead_bug.good_clean | Tốt, lưng giữ ổn định. |
| dead_bug.set_next_setup | Hiệp này đưa tay lên. Gối gập vuông góc. Lưng áp sát sàn. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| opposite_side | Hạ tay và chân đối diện. | Hiệp này đừng hạ cùng bên. |
| alternate | Đổi bên sau mỗi lần. | Hiệp này đổi trái phải rõ hơn. |
| anti_extension | Ép lưng xuống sàn. | Hiệp này đừng để lưng cong lên. |
| stable_limbs | Giữ bên còn lại đứng yên. | Hiệp này đừng để tay chân còn lại bị kéo theo. |
| floor_contact | Đừng để tay hoặc chân chạm sàn. | Hiệp này hạ gần sàn thôi. |
| tempo | Hạ tay chân chậm lại. | Hiệp này đừng thả rơi tay chân. |

## Plank Up-Down - Chuyển chống tay và cẳng tay

| Mã file | Câu nói |
|---|---|
| plank_up_down.setup_intro | Đặt điện thoại thấp. Quay hơi chéo người để thấy vai, hông, tay và chân. |
| plank_up_down.setup_position | Chống tay cao. Tay dưới vai. Người thẳng. |
| plank_up_down.active_intro | Hạ từng tay xuống cẳng tay. Rồi đẩy từng tay lên lại. Nhớ đổi tay dẫn. |
| plank_up_down.good_clean | Tốt, đổi tay chắc. |
| plank_up_down.set_next_setup | Hiệp này chống tay cao trước. Siết bụng, người thẳng. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| alternating | Đổi tay dẫn ở lần tiếp theo. | Hiệp này nhớ luân phiên tay dẫn. |
| arm_extension | Đẩy thẳng tay khi lên. | Hiệp này duỗi tay rõ ở điểm cao. |
| hip_rotation | Siết bụng, đừng lắc hông. | Hiệp này giữ hông yên hơn. |
| trunk | Nâng hông lên, đừng sụt lưng. | Hiệp này giữ người thẳng hơn. |
| knee | Duỗi thẳng đầu gối. | Hiệp này giữ chân dài hơn. |

## Bear Plank - Chống bốn điểm nhấc gối

| Mã file | Câu nói |
|---|---|
| bear_plank.setup_intro | Đặt điện thoại hơi chéo trước mặt để thấy vai, tay, hông, gối và bàn chân. |
| bear_plank.setup_position | Chống hai tay và hai gối. Tay dưới vai, gối dưới hông. Mũi chân chạm sàn. |
| bear_plank.active_intro | Nhấc gối lên khỏi sàn một chút. Giữ lưng phẳng. Thở đều. |
| bear_plank.hold_good | Tốt, giữ gối lơ lửng như vậy. |
| bear_plank.set_next_setup | Hiệp này vào lại bốn điểm. Lưng phẳng, gối dưới hông. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| knee_hover | Nâng gối lên khỏi sàn. | Hiệp này đừng để gối chạm sàn. |
| hip_high | Hạ mông xuống một chút. | Hiệp này đừng đưa mông quá cao. |
| back_sag | Giữ lưng phẳng, siết bụng. | Hiệp này đừng võng lưng. |
| back_arch | Hạ lưng phẳng hơn, đừng gù. | Hiệp này giữ lưng như mặt bàn. |
| weight | Đẩy người lùi nhẹ. | Hiệp này đừng dồn vai quá xa về trước. |

## Sit Up - Gập bụng

| Mã file | Câu nói |
|---|---|
| sit_up.setup_intro | Đặt điện thoại ngang sàn. Quay ngang người để thấy thân người, gối và bàn chân. |
| sit_up.setup_position | Nằm ngửa. Co gối. Giữ bàn chân ổn định trên sàn. |
| sit_up.active_intro | Cuộn người lên chậm. Đừng giật. Rồi hạ xuống chậm. |
| sit_up.good_clean | Tốt, lên xuống mượt. |
| sit_up.set_next_setup | Hiệp này nằm lại. Co gối và giữ chân ổn định. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| jerking | Đừng giật người. | Hiệp này cuộn lên chậm hơn. |
| rom | Lên cao hơn một chút. | Hiệp này cuộn thân rõ hơn. |
| stability | Giữ chân chạm sàn. | Hiệp này cố định bàn chân. |
| tempo | Hạ người chậm lại. | Hiệp này đừng thả người xuống. |

## High Plank - Chống tay cao

| Mã file | Câu nói |
|---|---|
| high_plank.setup_intro | Đặt điện thoại thấp ngang thân. Quay ngang người để thấy vai, hông, gối và chân. |
| high_plank.setup_position | Chống tay trên sàn. Tay dưới vai. Duỗi người thẳng. |
| high_plank.active_intro | Giữ tay thẳng. Siết bụng nhẹ. Hông ngang thân. Thở đều. |
| high_plank.hold_good | Tốt, giữ rất ổn. |
| high_plank.set_next_setup | Hiệp này chống tay trên sàn. Tay dưới vai, người thẳng. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| sagging | Siết bụng, đừng võng lưng. | Hiệp này giữ hông ngang thân. |
| piked | Hạ hông xuống, đừng chổng mông. | Hiệp này giữ người thẳng hơn. |
| elbow | Duỗi thẳng khuỷu tay. | Hiệp này chống tay chắc hơn. |
| wall_guard | Chống tay trên sàn. Đừng chống vào tường. | Hiệp này vào đúng tư thế dưới sàn. |

## Mountain Climber - Kéo gối

| Mã file | Câu nói |
|---|---|
| mountain_climber.setup_intro | Đặt điện thoại hơi chéo để thấy tay, hông và hai gối. |
| mountain_climber.setup_position | Chống tay cao. Tay dưới vai. Người thẳng. |
| mountain_climber.active_intro | Kéo từng gối về phía ngực. Đổi bên liên tục. Giữ hông ổn định. |
| mountain_climber.good_clean | Tốt, gối kéo rõ. |
| mountain_climber.set_next_setup | Hiệp này chống tay cao. Siết bụng trước khi kéo gối. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| double_knee | Kéo từng gối một. | Hiệp này đừng kéo hai gối cùng lúc. |
| rom | Kéo gối sâu hơn về phía ngực. | Hiệp này kéo gối rõ hơn. |
| trunk_sag | Siết bụng, đừng võng lưng. | Hiệp này giữ lưng chắc. |
| trunk_bounce | Giữ hông ổn định. | Hiệp này đừng để hông nhấp nhô. |

## Superman - Nằm sấp nâng tay chân

| Mã file | Câu nói |
|---|---|
| superman.setup_intro | Đặt điện thoại ngang sàn. Quay ngang người để thấy tay, chân, hông và ngực. |
| superman.setup_position | Nằm sấp. Tay duỗi trước. Chân duỗi sau. Hông chạm sàn. |
| superman.active_intro | Nâng tay và chân vừa đủ. Giữ 2 giây. Rồi hạ xuống chậm. |
| superman.good_clean | Tốt, nâng vừa đủ. |
| superman.set_next_setup | Hiệp này nằm sấp lại. Hông chạm sàn, tay chân duỗi dài. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| elevation_arm | Nâng tay cao hơn một chút. | Hiệp này tay nâng rõ hơn. |
| elevation_leg | Nâng chân cao hơn một chút. | Hiệp này chân nâng rõ hơn. |
| hip | Giữ hông chạm sàn. | Hiệp này đừng nhấc hông. |
| hold | Giữ 2 giây ở điểm cao nhất. | Hiệp này đừng nâng lên rồi hạ ngay. |
| lumbar | Hạ tay chân thấp hơn một chút. | Hiệp này đừng bẻ lưng quá nhiều. |

## Plank Shoulder Tap - Chạm vai khi chống tay

| Mã file | Câu nói |
|---|---|
| plank_shoulder_tap.setup_intro | Đặt điện thoại hơi chéo để thấy vai, tay, hông và chân. |
| plank_shoulder_tap.setup_position | Chống tay cao. Tay dưới vai. Chân mở vừa đủ để giữ thăng bằng. |
| plank_shoulder_tap.active_intro | Nhấc một tay chạm vai bên kia. Đặt xuống rồi đổi bên. Giữ hông yên. |
| plank_shoulder_tap.good_clean | Tốt, chạm vai rõ. |
| plank_shoulder_tap.set_next_setup | Hiệp này chống tay cao. Chân mở vừa đủ, bụng siết nhẹ. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| tap | Chạm vai rõ hơn. | Hiệp này đưa tay tới vai dứt khoát hơn. |
| hip_rotation | Siết bụng, đừng lắc hông. | Hiệp này giữ hông yên hơn khi nhấc tay. |
| tempo | Chậm lại, đừng giật tay. | Hiệp này chạm vai chậm và chắc. |
| trunk | Giữ lưng thẳng. | Hiệp này đừng võng lưng hoặc chổng hông. |

## Leg Raises - Nâng chân nằm ngửa

| Mã file | Câu nói |
|---|---|
| leg_raises.setup_intro | Đặt điện thoại ngang sàn. Quay ngang người để thấy hông, chân, gối và tay. |
| leg_raises.setup_position | Nằm ngửa. Hai tay duỗi sát hông. Hai chân duỗi thẳng. |
| leg_raises.active_intro | Nâng hai chân lên. Rồi hạ xuống chậm. Giữ lưng dưới ổn định. |
| leg_raises.good_clean | Tốt, chân hạ chậm. |
| leg_raises.set_next_setup | Hiệp này nằm lại. Tay sát hông, chân duỗi thẳng. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| pelvic | Ép lưng dưới xuống sàn. | Hiệp này đừng để lưng dưới bật lên. |
| rom | Nâng và hạ chân rõ hơn. | Hiệp này đi hết tầm chân của bạn. |
| knee | Duỗi thẳng đầu gối. | Hiệp này giữ chân dài hơn. |
| tempo | Hạ chân chậm lại. | Hiệp này đừng thả rơi chân. |
| arms | Duỗi tay sát hông. | Hiệp này giữ tay thẳng và sát thân. |

## Reverse Crunch - Cuộn hông

| Mã file | Câu nói |
|---|---|
| reverse_crunch.setup_intro | Đặt điện thoại ngang sàn. Quay ngang người để thấy hông, gối, tay và thân người. |
| reverse_crunch.setup_position | Nằm ngửa. Tay duỗi sát hông. Co gối và nhấc chân khỏi sàn. |
| reverse_crunch.active_intro | Cuộn hông lên bằng bụng dưới. Rồi hạ hông xuống thật chậm. |
| reverse_crunch.good_clean | Tốt, cuộn hông gọn. |
| reverse_crunch.set_next_setup | Hiệp này tay sát hông. Gối giữ ổn định. Chuẩn bị cuộn hông. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| curl | Cuộn mông cao hơn. | Hiệp này nhấc hông rõ khỏi sàn. |
| momentum | Đừng vung chân. | Hiệp này dùng bụng để cuộn hông. |
| tempo | Hạ hông từ từ. | Hiệp này hạ chậm hơn. |
| arms | Duỗi tay sát hông. | Hiệp này giữ tay cố định. |

## Bow Pose - Tư thế cánh cung

| Mã file | Câu nói |
|---|---|
| bow_pose.setup_intro | Đặt điện thoại ngang sàn. Quay ngang người để thấy tay, chân, hông và ngực. |
| bow_pose.setup_position | Nằm sấp. Co gối. Đưa tay nắm cổ chân hoặc bàn chân. |
| bow_pose.active_intro | Kéo chân ra sau để mở ngực. Nâng đùi nhẹ. Thở đều. |
| bow_pose.hold_good | Tốt, giữ tay và chân chắc. |
| bow_pose.set_next_setup | Hiệp này nằm sấp lại. Nắm chân chắc trước khi nâng. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| connection | Nắm chân chắc hơn. | Hiệp này đừng để tuột tay. |
| hold | Giữ lâu hơn một chút. | Hiệp này giữ đủ thời gian. |
| stability | Giữ người yên hơn. | Hiệp này nâng thấp hơn nếu bị lắc. |
| chest | Mở ngực thêm một chút. | Hiệp này kéo vai nhẹ ra sau. |
| thigh | Nâng đùi cao hơn nếu lưng vẫn thoải mái. | Hiệp này đừng ép lưng quá mạnh. |

## Butterfly Stretch - Ngồi mở gối

| Mã file | Câu nói |
|---|---|
| butterfly_stretch.setup_intro | Đặt điện thoại trước mặt hoặc hơi chéo để thấy hông, gối, bàn chân và lưng. |
| butterfly_stretch.setup_position | Ngồi thẳng. Áp hai lòng bàn chân vào nhau. Kéo gót chân về gần hông. |
| butterfly_stretch.active_intro | Giữ lưng thẳng. Thả gối mở sang hai bên. Thở chậm. |
| butterfly_stretch.hold_good | Tốt, lưng thẳng và gối cân bằng. |
| butterfly_stretch.set_next_setup | Hiệp này ngồi thẳng lại. Hai bàn chân áp vào nhau. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| foot | Kéo gót chân gần hông hơn. | Hiệp này giữ hai bàn chân sát nhau hơn. |
| knee | Giữ hai gối cân bằng hơn. | Hiệp này mở hai gối đều hai bên. |
| posture | Thẳng lưng lên. | Hiệp này đừng gập người xuống. |
| shoulder | Giữ hai vai cân bằng. | Hiệp này ngồi đều hai bên hông. |

## Cobra Pose - Tư thế rắn hổ mang

| Mã file | Câu nói |
|---|---|
| cobra.setup_intro | Đặt điện thoại ngang sàn. Quay ngang người để thấy tay, hông, ngực và cổ. |
| cobra.setup_position | Nằm sấp. Đặt tay gần vai. Hông chạm sàn. Khuỷu tay hơi gập. |
| cobra.active_intro | Đẩy ngực lên nhẹ. Giữ hông chạm sàn. Cổ dài. Hạ xuống chậm. |
| cobra.hold_good | Tốt, nâng nhẹ và an toàn. |
| cobra.set_next_setup | Hiệp này đặt tay gần vai. Hông chạm sàn, nâng ngực vừa phải. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| neck | Hạ đầu xuống một chút. | Hiệp này đừng ngửa cổ. |
| descent | Hạ chậm hơn. | Hiệp này kiểm soát khi trở về sàn. |
| elbow | Gập khuỷu tay thêm chút. | Hiệp này đừng khóa cứng tay. |
| hip | Ép hông xuống sàn hơn. | Hiệp này giữ hông chạm sàn. |
| hand | Kéo tay về gần vai hơn. | Hiệp này đặt tay đúng gần vai. |
| stability | Giữ người yên hơn. | Hiệp này nâng thấp hơn nếu bị lắc. |

## Cossack Squat - Ngồi lệch một bên

| Mã file | Câu nói |
|---|---|
| cossack_squat.setup_intro | Đặt điện thoại phía trước hoặc hơi chéo để thấy hai chân, hông và bàn chân. |
| cossack_squat.setup_position | Đứng hai chân rộng. Mũi chân hơi mở. Giữ người cao. |
| cossack_squat.active_intro | Dồn người sang một bên. Chân còn lại duỗi dài. Rồi đứng lên và đổi bên. |
| cossack_squat.good_clean | Tốt, chuyển bên chắc. |
| cossack_squat.set_next_setup | Hiệp này đứng chân rộng hơn vai. Giữ ngực cao trước khi hạ xuống. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| heel | Giữ gót chân trụ chạm sàn. | Hiệp này xuống nông hơn nếu gót bị nhấc. |
| knee_valgus | Đẩy gối ra ngoài theo mũi chân. | Hiệp này đừng để gối chụm vào trong. |
| straight_leg | Giữ chân còn lại duỗi thẳng. | Hiệp này đừng thu chân duỗi vào gần người. |
| torso | Giữ lưng thẳng hơn. | Hiệp này đừng rạp ngực xuống. |
| depth_deep | Đừng xuống quá sâu nếu gối bị ép. | Hiệp này giữ độ sâu an toàn. |
| depth_shallow | Hạ hông thấp hơn một chút. | Hiệp này xuống sâu hơn nhưng vẫn giữ gót. |

## Jump Squat - Ngồi xuống bật nhảy

| Mã file | Câu nói |
|---|---|
| jump_squat.setup_intro | Lùi xa điện thoại để thấy cả người từ đầu đến chân. Chừa chỗ khi nhảy. |
| jump_squat.setup_position | Đứng hai chân rộng bằng vai. Gối hơi mềm. Ngực hướng lên. |
| jump_squat.active_intro | Hạ xuống như ngồi xuống. Bật nhảy lên. Tiếp đất mềm bằng cách trùng gối. |
| jump_squat.good_clean | Tốt, tiếp đất êm. |
| jump_squat.set_next_setup | Hiệp này đứng giữa khung hình. Gối mềm và ngực cao. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| too_fast | Chậm lại để Vika nhìn rõ hơn. | Hiệp này giữ nhịp rõ, đừng vội. |
| landing_stiff | Trùng gối khi tiếp đất. | Hiệp này tiếp đất mềm hơn. |
| landing_depth | Trùng gối sâu hơn khi chạm đất. | Hiệp này dùng hông và gối để đỡ lực. |
| trunk | Giữ ngực cao khi tiếp đất. | Hiệp này đừng rạp lưng xuống. |
| takeoff_depth | Hạ hông thấp hơn trước khi bật nhảy. | Hiệp này lấy đà rõ hơn. |

## Russian Twist - Ngồi vặn người

| Mã file | Câu nói |
|---|---|
| russian_twist.setup_intro | Đặt điện thoại trước mặt hoặc hơi chéo để thấy vai, tay, hông và gối. |
| russian_twist.setup_position | Ngồi ngả lưng nhẹ. Co gối. Đưa hai tay về giữa thân. |
| russian_twist.active_intro | Xoay vai và ngực sang hai bên. Đừng chỉ vung tay. Giữ gối yên. |
| russian_twist.good_clean | Tốt, xoay người rõ. |
| russian_twist.set_next_setup | Hiệp này ngả lưng nhẹ. Tay ở giữa thân, gối giữ yên. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| knee | Giữ đầu gối ổn định. | Hiệp này đừng dùng chân lấy đà. |
| too_upright | Ngả lưng ra sau thêm một chút. | Hiệp này đừng ngồi quá thẳng. |
| too_low | Nâng thân lên một chút. | Hiệp này đừng nằm quá thấp. |
| spine | Mở ngực lên, giữ lưng thẳng. | Hiệp này đừng gù lưng. |
| thoracic | Xoay cả vai và ngực. | Hiệp này đừng chỉ quăng tay. |
| rom | Vặn sâu hơn sang hai bên. | Hiệp này đưa tay qua hai bên rõ hơn. |

## Seated Forward Fold - Ngồi gập người

| Mã file | Câu nói |
|---|---|
| seated_forward_fold.setup_intro | Đặt điện thoại nghiêng để thấy lưng, hông, gối và bàn chân. |
| seated_forward_fold.setup_position | Ngồi duỗi hai chân. Kéo mũi chân về phía người. Giữ lưng thẳng. |
| seated_forward_fold.active_intro | Gập người từ hông. Giữ lưng dài. Gối thẳng vừa sức. Thở chậm. |
| seated_forward_fold.hold_good | Tốt, kéo giãn nhẹ. |
| seated_forward_fold.set_next_setup | Hiệp này ngồi thẳng. Chân duỗi, mũi chân kéo về người. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| ankle | Kéo mũi chân về phía người. | Hiệp này giữ cổ chân gập nhẹ. |
| knee | Duỗi gối vừa sức. | Hiệp này giữ chân dài hơn. |
| spine | Thẳng lưng lên. | Hiệp này gập từ hông, không gù lưng. |
| tempo | Giữ lâu hơn một chút. | Hiệp này giữ đủ thời gian kéo giãn. |

## Side Plank with Hip Dip - Nghiêng người hạ hông

| Mã file | Câu nói |
|---|---|
| side_plank_dip.setup_intro | Đặt điện thoại trước mặt hoặc hơi chéo để thấy vai, khuỷu tay, hông và chân. |
| side_plank_dip.setup_position | Chống khuỷu tay dưới vai. Duỗi người nghiêng. Nâng hông khỏi sàn. |
| side_plank_dip.active_intro | Hạ hông xuống gần sàn rồi nâng lên lại. Đừng đổ người ra trước hoặc sau. |
| side_plank_dip.good_clean | Tốt, hông lên xuống chắc. |
| side_plank_dip.set_next_setup | Hiệp này đặt khuỷu tay dưới vai. Giữ người nghiêng thẳng. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| shoulder | Kéo khuỷu tay về dưới vai. | Hiệp này chỉnh khuỷu tay trước khi hạ hông. |
| rotation | Giữ hông thẳng, đừng đổ người. | Hiệp này thân người không lăn ra trước hoặc sau. |
| amplitude | Hạ hông thấp hơn một chút. | Hiệp này hạ đủ sâu mỗi lần. |

## Sphinx Pose - Tư thế nhân sư

| Mã file | Câu nói |
|---|---|
| sphinx.setup_intro | Đặt điện thoại ngang sàn. Quay ngang người để thấy khuỷu tay, ngực, hông và cổ. |
| sphinx.setup_position | Nằm sấp. Chống cẳng tay xuống sàn. Khuỷu tay dưới vai. Hông chạm sàn. |
| sphinx.active_intro | Đẩy ngực lên nhẹ. Thả vai xa tai. Giữ cổ dài và hông chạm sàn. |
| sphinx.hold_good | Tốt, giữ nhẹ và ổn định. |
| sphinx.set_next_setup | Hiệp này chống cẳng tay. Khuỷu tay dưới vai, hông sát sàn. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| hip | Ấn hông xuống sàn. | Hiệp này đừng nhấc hông. |
| straight_arm | Gập khuỷu tay lại. | Hiệp này chống cẳng tay, không chống thẳng tay. |
| forearm | Hạ cẳng tay xuống sàn. | Hiệp này để cẳng tay nằm chắc trên sàn. |
| upper_arm | Đặt khuỷu tay dưới vai hơn. | Hiệp này chống tay vuông hơn. |
| shrug | Thả vai xuống, xa tai. | Hiệp này đừng rụt cổ. |
| neck | Hạ cằm nhẹ, nhìn xuống thảm. | Hiệp này đừng ngửa cổ ra sau. |

## Standing Knee-to-Elbow - Đứng chạm gối khuỷu tay

| Mã file | Câu nói |
|---|---|
| standing_kte.setup_intro | Đặt điện thoại trước mặt để thấy toàn thân, vai, hông, gối và khuỷu tay. |
| standing_kte.setup_position | Đứng thẳng. Hai tay sau đầu hoặc khuỷu tay mở ngang vai. |
| standing_kte.active_intro | Nâng gối lên. Xoay khuỷu tay bên kia về gần gối. Rồi đổi bên. |
| standing_kte.good_clean | Tốt, gối và khuỷu tay gần nhau. |
| standing_kte.set_next_setup | Hiệp này đứng thẳng. Vai cân bằng, khuỷu tay mở ngang. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| core_drive | Nhấc đùi cao hơn. Đừng cúi cổ. | Hiệp này kéo gối bằng bụng. |
| cross_rom | Xoay người mạnh hơn. | Hiệp này đưa khuỷu tay gần gối hơn. |
| knee_valgus | Mở đầu gối chân trụ ra. | Hiệp này đừng để gối sụp vào trong. |
| pelvic_drop | Giữ hông cân bằng. | Hiệp này siết mông chân trụ. |
| setup | Đứng thẳng và nâng khuỷu tay ngang vai. | Hiệp này vào đúng tư thế trước khi bắt đầu. |

## Step-Back Burpee - Bước chân ra sau

| Mã file | Câu nói |
|---|---|
| step_back_burpee.setup_intro | Lùi xa điện thoại để thấy cả người khi đứng, cúi xuống và bước chân ra sau. |
| step_back_burpee.setup_position | Đứng thẳng. Chân rộng bằng hông. Chuẩn bị gập gối và chống tay xuống sàn. |
| step_back_burpee.active_intro | Trùng gối. Đặt tay xuống. Bước chân ra sau. Rồi bước lên và đứng dậy. |
| step_back_burpee.good_clean | Tốt, chuyển tư thế chắc. |
| step_back_burpee.set_next_setup | Hiệp này đứng giữa khung hình. Trùng gối trước khi chống tay. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| squat_hinge | Trùng gối xuống, đừng cúi lưng với chân thẳng. | Hiệp này hạ bằng gối và hông. |
| squat_depth | Hạ hông thấp hơn khi đặt tay. | Hiệp này xuống thấp hơn trước khi chống tay. |
| plank_sag | Siết bụng, đừng võng lưng. | Hiệp này giữ người thẳng sau khi bước chân ra. |
| plank_extension | Bước chân lùi xa hơn. | Hiệp này duỗi chân rõ hơn khi ra sau. |

## Tricep Dip - Ngồi chống tay hạ hông

| Mã file | Câu nói |
|---|---|
| tricep_dip.setup_intro | Đặt điện thoại nghiêng để thấy vai, khuỷu tay, hông và gối. |
| tricep_dip.setup_position | Ngồi trên sàn. Đặt tay sau hông. Nhấc hông lên khỏi sàn. |
| tricep_dip.active_intro | Gập khuỷu tay để hạ hông. Rồi đẩy thẳng tay lên. Thả vai xuống. |
| tricep_dip.good_clean | Tốt, tay làm việc rõ. |
| tricep_dip.set_next_setup | Hiệp này đặt tay sau hông. Nhấc hông lên, vai thả lỏng. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| extension | Đẩy thẳng tay lên. | Hiệp này duỗi tay rõ ở điểm cao. |
| hip_thrust | Đừng chỉ đẩy hông. Hãy gập khuỷu tay. | Hiệp này dùng tay để hạ và đẩy người. |
| shrug | Hạ vai xuống, xa tai. | Hiệp này giữ ngực mở và vai thấp. |
| rom | Gập tay sâu hơn. | Hiệp này hạ hông gần sàn hơn. |
| setup | Nhấc hông lên trước khi bắt đầu. | Hiệp này vào đúng tư thế rồi mới hạ hông. |

## Walking Lunge - Bước tới hạ gối

| Mã file | Câu nói |
|---|---|
| walking_lunge.setup_intro | Đặt điện thoại trước mặt hoặc hơi chéo. Cần đủ chỗ để bước tới. |
| walking_lunge.setup_position | Đứng thẳng. Mắt nhìn trước. Chuẩn bị bước một chân dài lên. |
| walking_lunge.active_intro | Bước tới. Hạ gối sau gần sàn. Giữ người thẳng. Rồi bước tiếp chân kia. |
| walking_lunge.good_clean | Tốt, bước chắc. |
| walking_lunge.set_next_setup | Hiệp này đứng thẳng. Bước dài vừa đủ và giữ ngực cao. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| front_knee | Bước chân dài hơn. | Hiệp này đừng để gối trước lao quá xa. |
| rear_depth | Hạ gối sau gần sàn hơn. | Hiệp này xuống đủ sâu ở mỗi bước. |
| step_length | Giữ bước chân đều hơn. | Hiệp này bước hai bên cân bằng. |
| torso | Giữ người thẳng đứng. | Hiệp này đừng gập lưng nhiều. |
| hold | Giữ ở điểm thấp 2 giây rồi đứng lên. | Hiệp này dừng ngắn ở điểm thấp. |
| framing | Lùi lại để thấy đủ hai chân. | Hiệp này giữ cả người trong khung hình. |

## Chào Mặt Trời

| Mã file | Câu nói |
|---|---|
| surya_namaskar.setup_intro | Đặt điện thoại quay nghiêng để thấy cả người trong suốt chuỗi động tác. |
| surya_namaskar.setup_position | Đứng ở đầu thảm. Hai chân vững. Tay thả lỏng trước khi bắt đầu. |
| surya_namaskar.active_intro | Đi chậm từng tư thế theo hơi thở. Ưu tiên an toàn. |
| surya_namaskar.good_round | Hoàn thành một vòng Chào Mặt Trời. |
| surya_namaskar.set_next_setup | Vòng tiếp theo đứng lại đầu thảm. Thở đều và đi chậm. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| pose_wait | Vào đúng tư thế rồi giữ yên. | Vòng này giữ từng tư thế rõ hơn. |
| safety | Chậm lại và giữ tư thế an toàn hơn. | Vòng này ưu tiên kiểm soát hơn tốc độ. |
| sequence | Đi theo đúng thứ tự các tư thế. | Vòng này đừng bỏ qua bước. |
| breath | Thở đều theo từng động tác. | Vòng này phối hợp hơi thở chậm hơn. |

## Wall Push Up - Chống đẩy tường

| Mã file | Câu nói |
|---|---|
| wall_push_up.setup_intro | Đặt điện thoại quay nghiêng để thấy vai, hông, gối, bàn chân và tường. |
| wall_push_up.setup_position | Đứng cách tường một bước. Đặt tay ngang vai. Người nghiêng vào tường. |
| wall_push_up.active_intro | Gập khuỷu tay đưa ngực về tường. Giữ người thẳng. Rồi đẩy người ra. |
| wall_push_up.good_clean | Tốt, người giữ thẳng. |
| wall_push_up.set_next_setup | Hiệp này đứng nghiêng vào tường. Tay ngang vai, chân đứng yên. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| body_line | Giữ hông thẳng, siết bụng nhẹ. | Hiệp này giữ vai, hông và chân thẳng hàng. |
| cervical | Giữ cổ thẳng, nhìn về trước. | Hiệp này đừng ngửa đầu lên. |
| elbow | Ép khuỷu tay sát người hơn. | Hiệp này đừng mở khuỷu tay quá rộng. |
| foot | Giữ chân đứng yên. | Hiệp này đừng bước chân. |
| heel | Kiễng gót nhẹ. | Hiệp này dồn lực vào mũi chân. |
| head | Kéo cằm về, giữ đầu thẳng. | Hiệp này đừng đưa đầu về trước. |
| shoulder | Hạ vai xuống. | Hiệp này đừng nhún vai. |
| hand | Giữ tay cố định trên tường. | Hiệp này đừng để tay trượt. |
| tempo | Hạ chậm lại. | Hiệp này đừng lao người vào tường. |
| setup | Đặt tay ngang vai. | Hiệp này đừng đặt tay quá cao hoặc quá thấp. |

## Chó Cúi Mặt

| Mã file | Câu nói |
|---|---|
| downward_dog.setup_intro | Đặt điện thoại quay nghiêng để thấy tay, vai, lưng, hông và chân. |
| downward_dog.setup_position | Từ tư thế chống tay, đẩy hông lên cao và ra sau. |
| downward_dog.active_intro | Kéo dài lưng. Đẩy tay xuống sàn. Có thể gập gối để lưng thẳng hơn. |
| downward_dog.hold_good | Tốt, lưng dài và thở đều. |
| downward_dog.set_next_setup | Hiệp này đẩy hông lên cao. Ưu tiên lưng dài trước. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| spine | Gập gối một chút để kéo dài lưng. | Hiệp này ưu tiên lưng thẳng. |
| shoulder | Đẩy vai xa tai. Thả lỏng cổ. | Hiệp này đừng rụt cổ. |
| leg | Duỗi chân vừa sức. | Hiệp này duỗi chân thêm nếu lưng vẫn thẳng. |
| hip | Đẩy hông lên cao và ra sau hơn. | Hiệp này tạo dáng chữ V ngược rõ hơn. |

## Ashtanga Namaskara - Tám điểm chạm sàn

| Mã file | Câu nói |
|---|---|
| ashtanga_namaskara.setup_intro | Đặt điện thoại quay nghiêng để thấy cả người khi hạ xuống sàn. |
| ashtanga_namaskara.setup_position | Chống tay cao. Tay dưới vai. Chuẩn bị hạ gối, ngực và cằm xuống. |
| ashtanga_namaskara.active_intro | Hạ gối trước. Rồi hạ ngực sát sàn. Giữ hông cao hơn vai. |
| ashtanga_namaskara.good_clean | Tốt, tư thế rõ. |
| ashtanga_namaskara.set_next_setup | Hiệp này chống tay cao. Hạ gối trước rồi hạ ngực chậm. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| knees | Hạ gối xuống sàn trước. | Hiệp này để gối chạm sàn trước khi hạ ngực. |
| chest | Hạ ngực xuống sát sàn hơn. | Hiệp này ngực thấp rõ hơn. |
| hip | Đẩy hông lên cao hơn. | Hiệp này đừng để hông ngang vai. |
| neck | Đặt cằm xuống nhẹ. | Hiệp này đừng đẩy đầu lên cao. |
| count_guard | Lần này chưa tính. Vào đúng tư thế rồi giữ lại. | Hiệp này giữ tư thế rõ trước khi thoát. |

## Kỵ Sĩ

| Mã file | Câu nói |
|---|---|
| low_lunge.setup_intro | Đặt điện thoại quay nghiêng để thấy chân trước, chân sau, hông và cổ. |
| low_lunge.setup_position | Bước một chân lên trước. Hạ gối sau xuống sàn. Giữ người cao. |
| low_lunge.active_intro | Hạ hông nhẹ về trước. Mở ngực. Cổ thoải mái. Thở đều. |
| low_lunge.hold_good | Tốt, giữ rất ổn. |
| low_lunge.set_next_setup | Hiệp này hạ gối sau xuống sàn. Chân trước đặt vững. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| back_knee | Hạ gối sau xuống sàn. | Hiệp này gối sau chạm sàn trước khi giữ. |
| depth | Hạ hông thấp hơn nếu thấy thoải mái. | Hiệp này kéo giãn hông nhẹ hơn. |
| chest | Nâng ngực lên một chút. | Hiệp này đừng gù lưng. |
| cervical | Nhìn về trước. | Hiệp này đừng ngửa cổ. |
| knee_travel | Lùi hông ra sau một chút. | Hiệp này giữ gối trước trên cổ chân. |

## Cầu Nguyện

| Mã file | Câu nói |
|---|---|
| prayer_pose.setup_intro | Đặt điện thoại quay nghiêng hoặc trước mặt để thấy đầu, vai, hông và chân. |
| prayer_pose.setup_position | Đứng thẳng. Hai chân vững. Chắp tay trước ngực. |
| prayer_pose.active_intro | Kéo dài lưng. Mở ngực nhẹ. Thả vai xuống. Thở chậm. |
| prayer_pose.hold_good | Tốt, đứng thẳng và thở đều. |
| prayer_pose.set_next_setup | Hiệp này đứng vững lại. Chắp tay và thả vai. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| posture | Đưa đầu nhẹ về sau và mở ngực. | Hiệp này giữ đầu, vai và hông thẳng hàng. |
| shoulder | Thả vai xuống. | Hiệp này đừng nhún vai. |
| drift | Giữ người yên hơn. | Hiệp này đứng vững, đừng lắc người. |

## Vươn Tay

| Mã file | Câu nói |
|---|---|
| raised_arms.setup_intro | Đặt điện thoại quay nghiêng để thấy tay, cổ, lưng, hông và chân. |
| raised_arms.setup_position | Đứng thẳng. Hai chân vững. Chuẩn bị vươn hai tay lên cao. |
| raised_arms.active_intro | Vươn tay lên. Kéo dài thân người. Ngả nhẹ nếu thấy thoải mái. |
| raised_arms.hold_good | Tốt, tay vươn cao và lưng ổn. |
| raised_arms.set_next_setup | Hiệp này đứng thẳng. Chân vững, tay chuẩn bị vươn cao. |

| Mã lỗi | Khi đang tập | Nhắc đầu hiệp sau |
|---|---|---|
| arms | Vươn tay cao hơn. | Hiệp này duỗi khuỷu tay rõ hơn. |
| cervical | Nhìn lên nhẹ thôi. | Hiệp này đừng ngửa cổ. |
| lumbar | Đừng ngả quá sâu. | Hiệp này bảo vệ lưng dưới. |
| stability | Giữ người yên hơn. | Hiệp này đứng vững trước khi giữ. |

## Bài kiểm tra đầu vào

| Bài kiểm tra | Dùng kịch bản | Điều chỉnh |
|---|---|---|
| Kiểm tra ngồi xuống đứng lên | Ngồi xuống đứng lên | Mục tiêu 5 lần. Câu mở đầu: Đây là 5 lần kiểm tra tư thế. Tập chậm và đúng. |
| Kiểm tra chống đẩy tường | Chống đẩy tường | Mục tiêu 5 lần. Câu mở đầu: Đây là 5 lần kiểm tra tư thế. Giữ người thẳng và đi chậm. |
