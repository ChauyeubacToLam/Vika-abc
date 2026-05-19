import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/recommendation/weekly_check_in_service.dart';
import '../theme/app_colors.dart';
import '../theme/responsive.dart';

class WeeklyCheckInLaunchArgs {
  const WeeklyCheckInLaunchArgs({
    required this.recommendationId,
    required this.weekNumber,
  });

  final String recommendationId;
  final int weekNumber;
}

class WeeklyCheckInScreen extends StatefulWidget {
  const WeeklyCheckInScreen({
    super.key,
    required this.args,
  });

  final WeeklyCheckInLaunchArgs args;

  @override
  State<WeeklyCheckInScreen> createState() => _WeeklyCheckInScreenState();
}

class _WeeklyCheckInScreenState extends State<WeeklyCheckInScreen> {
  final _service = WeeklyCheckInService();
  final _answers = <String, dynamic>{};
  int _index = 0;
  bool _isSubmitting = false;
  bool _isDone = false;

  String get _prefsKey =>
      'weekly_checkin_${widget.args.recommendationId}_${widget.args.weekNumber}';

  @override
  void initState() {
    super.initState();
    unawaited(_restorePartial());
  }

  Future<void> _restorePartial() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || !mounted) return;
    final restored = (jsonDecode(raw) as Map).cast<String, dynamic>();
    setState(() {
      _answers
        ..clear()
        ..addAll(restored);
      _index = (_answers.length).clamp(0, _questions.length - 1).toInt();
    });
  }

  Future<void> _savePartial() async {
    final prefs = await SharedPreferences.getInstance();
    if (_answers.isEmpty) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, jsonEncode(_answers));
    }
  }

  Future<void> _clearPartial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  void _answer(dynamic value) {
    final question = _questions[_index];
    setState(() => _answers[question.key] = value);
    unawaited(_savePartial());
  }

  void _next() {
    if (_index < _questions.length - 1) {
      setState(() => _index += 1);
    } else {
      unawaited(_submit());
    }
  }

  void _back() {
    if (_index == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _index -= 1);
  }

  Future<void> _submit() async {
    if (!_hasAllAnswers || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    final ok = await _service.submit(
      recommendationId: widget.args.recommendationId,
      weekNumber: widget.args.weekNumber,
      answers: WeeklyCheckInAnswers(
        energy: _answers['energy'] as int,
        soreness: _answers['soreness'] as int,
        sleep: _answers['sleep'] as int,
        motivation: _answers['motivation'] as int,
        painChange: _answers['pain_change'] as String,
        progressFeel: _answers['progress_feel'] as String,
      ),
    );
    if (!mounted) return;
    if (ok) {
      await _clearPartial();
      setState(() {
        _isDone = true;
        _isSubmitting = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa lưu được. Bạn thử lại nhé.')),
      );
    }
  }

  bool get _hasAllAnswers {
    return _questions.every((question) => _answers.containsKey(question.key));
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);
    final question = _questions[_index];
    final progress = (_index + 1) / _questions.length;

    return PopScope(
      onPopInvokedWithResult: (_, __) => unawaited(_savePartial()),
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _isDone
                ? _ThankYouView(key: const ValueKey('done'))
                : Padding(
                    key: const ValueKey('form'),
                    padding:
                        EdgeInsets.fromLTRB(24, 18, 24, 24 + r.bottomInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _RoundIconButton(
                              icon: Icons.arrow_back_rounded,
                              onTap: _back,
                            ),
                            const Spacer(),
                            Text(
                              '${_index + 1}/${_questions.length}',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: c.inkSoft,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            value: progress,
                            color: c.yellow,
                            backgroundColor: c.border,
                          ),
                        ),
                        const SizedBox(height: 44),
                        Text(
                          question.title,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: r.sp(31),
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          question.subtitle,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: r.sp(14),
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                            color: c.inkSoft,
                          ),
                        ),
                        const Spacer(),
                        if (question.kind == _QuestionKind.scale)
                          _ScalePicker(
                            selected: _answers[question.key] as int?,
                            onChanged: _answer,
                          )
                        else
                          _ChoicePicker(
                            choices: question.choices,
                            selected: _answers[question.key] as String?,
                            onChanged: _answer,
                          ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: c.yellow,
                              foregroundColor: c.yellowInk,
                              disabledBackgroundColor: c.border,
                              disabledForegroundColor: c.inkSoft,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _answers.containsKey(question.key) &&
                                    !_isSubmitting
                                ? _next
                                : null,
                            child: Text(
                              _index == _questions.length - 1
                                  ? (_isSubmitting ? 'Đang lưu' : 'Hoàn tất')
                                  : 'Tiếp tục',
                              style: const TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ScalePicker extends StatelessWidget {
  const _ScalePicker({
    required this.selected,
    required this.onChanged,
  });

  final int? selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      children: [
        for (var value = 1; value <= 5; value++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: value == 5 ? 0 : 8),
              child: SizedBox(
                height: 58,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: selected == value ? c.yellow : c.bgRaised,
                    foregroundColor: selected == value ? c.yellowInk : c.ink,
                    side: BorderSide(
                      color: selected == value ? c.yellow : c.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => onChanged(value),
                  child: Text(
                    '$value',
                    style: const TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChoicePicker extends StatelessWidget {
  const _ChoicePicker({
    required this.choices,
    required this.selected,
    required this.onChanged,
  });

  final List<_Choice> choices;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      children: choices.map((choice) {
        final active = selected == choice.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                backgroundColor: active ? c.yellow : c.bgRaised,
                foregroundColor: active ? c.yellowInk : c.ink,
                side: BorderSide(color: active ? c.yellow : c.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => onChanged(choice.value),
              child: Text(
                choice.label,
                style: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ThankYouView extends StatelessWidget {
  const _ThankYouView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: c.yellow,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: c.yellowInk),
            ),
            const SizedBox(height: 22),
            Text(
              'Cảm ơn bạn',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Vika đã lưu lại cảm nhận tuần này.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: c.bgRaised,
        shape: CircleBorder(side: BorderSide(color: c.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(icon, color: c.ink, size: 20),
        ),
      ),
    );
  }
}

enum _QuestionKind { scale, choice }

class _Question {
  const _Question({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.kind,
    this.choices = const [],
  });

  final String key;
  final String title;
  final String subtitle;
  final _QuestionKind kind;
  final List<_Choice> choices;
}

class _Choice {
  const _Choice(this.value, this.label);

  final String value;
  final String label;
}

const _questions = [
  _Question(
    key: 'energy',
    title: 'Năng lượng tuần này thế nào?',
    subtitle: 'Chọn nhanh theo cảm giác chung của bạn.',
    kind: _QuestionKind.scale,
  ),
  _Question(
    key: 'soreness',
    title: 'Đau cơ sau tập?',
    subtitle: '1 là rất nhẹ, 5 là khá nhiều.',
    kind: _QuestionKind.scale,
  ),
  _Question(
    key: 'sleep',
    title: 'Giấc ngủ tuần này?',
    subtitle: 'Vika chỉ ghi nhận để hiểu nhịp hồi phục của bạn.',
    kind: _QuestionKind.scale,
  ),
  _Question(
    key: 'motivation',
    title: 'Động lực tập?',
    subtitle: 'Không cần trả lời hoàn hảo. Cứ chọn đúng hôm nay.',
    kind: _QuestionKind.scale,
  ),
  _Question(
    key: 'pain_change',
    title: 'Đau nhức có thay đổi?',
    subtitle: 'So với tuần trước, cơ thể bạn đang nói gì?',
    kind: _QuestionKind.choice,
    choices: [
      _Choice('better', 'Tốt hơn'),
      _Choice('same', 'Như cũ'),
      _Choice('worse', 'Tệ hơn'),
    ],
  ),
  _Question(
    key: 'progress_feel',
    title: 'Cảm thấy có tiến bộ?',
    subtitle: 'Cảm giác chủ quan cũng là dữ liệu quan trọng.',
    kind: _QuestionKind.choice,
    choices: [
      _Choice('yes', 'Có'),
      _Choice('unsure', 'Không chắc'),
      _Choice('no', 'Không'),
    ],
  ),
];
