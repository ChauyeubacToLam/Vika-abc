import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/vf_theme.dart';
import 'debug_types.dart';
import 'tracked_metric.dart';

class DebugPanel extends StatelessWidget {
  const DebugPanel({
    super.key,
    required this.mode,
    required this.metrics,
    required this.expandedMetricId,
    required this.onToggleExpand,
    required this.phaseLabel,
    required this.repCount,
    required this.totalReps,
    required this.setSeconds,
    required this.fps,
    required this.frameTimestampMs,
    required this.confidence,
    required this.footerLabel,
    required this.onMinimize,
  });

  final DebugMode mode;
  final List<TrackedMetric> metrics;
  final String? expandedMetricId;
  final ValueChanged<String> onToggleExpand;
  final String phaseLabel;
  final int repCount;
  final int totalReps;
  final int setSeconds;
  final double fps;
  final int frameTimestampMs;
  final double confidence;
  final String footerLabel;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    if (mode == DebugMode.off) return const SizedBox.shrink();

    final isDev = mode == DebugMode.dev;
    final visibleMetrics = metrics
        .where((tracked) => isDev || !tracked.metric.devOnly)
        .toList(growable: false);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(15, 11, 8, 0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _DebugPalette.glassBorderHi),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.06),
                blurRadius: 0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 16,
                right: 16,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        isDev
                            ? _DebugPalette.dev.withValues(alpha: 0.5)
                            : VikaIvory.yellowGlow,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DebugHeader(
                    isDev: isDev,
                    phaseLabel: phaseLabel,
                    repCount: repCount,
                    totalReps: totalReps,
                    setSeconds: setSeconds,
                    fps: fps,
                    frameTimestampMs: frameTimestampMs,
                    onMinimize: onMinimize,
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: Column(
                        children: [
                          for (final tracked in visibleMetrics)
                            Padding(
                              key: ValueKey(tracked.id),
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Column(
                                children: [
                                  DebugMetricRow(
                                    tracked: tracked,
                                    isDev: isDev,
                                    isExpanded: tracked.id == expandedMetricId,
                                    onTap: () => onToggleExpand(tracked.id),
                                  ),
                                  if (tracked.id == expandedMetricId)
                                    ExpandedMetricSection(
                                      tracked: tracked,
                                      mode: mode,
                                      frameTimestampMs: frameTimestampMs,
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (isDev)
                    _DebugFooter(
                      totalFaults: visibleMetrics.fold<int>(
                        0,
                        (sum, tracked) => sum + tracked.faultCount,
                      ),
                      confidence: confidence,
                      footerLabel: footerLabel,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DebugIndicatorBadge extends StatelessWidget {
  const DebugIndicatorBadge({
    super.key,
    required this.mode,
    required this.panelOpen,
    required this.onToggle,
  });

  final DebugMode mode;
  final bool panelOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (mode == DebugMode.off) return const SizedBox.shrink();

    final isDev = mode == DebugMode.dev;
    final accent = isDev ? _DebugPalette.dev : VikaIvory.yellow;
    final fill = isDev
        ? _DebugPalette.dev.withValues(alpha: 0.10)
        : VikaIvory.yellowSoft;
    final border = isDev
        ? _DebugPalette.dev.withValues(alpha: 0.32)
        : VikaIvory.yellowGlowWeak;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulsingDot(color: accent, size: 5),
                const SizedBox(width: 5),
                Text(
                  isDev ? 'DEV' : 'Chi tiết',
                  style: TextStyle(
                    fontFamily: isDev ? 'monospace' : VikaIvory.fontFamily,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: VikaIvory.invInk,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 5),
                AnimatedRotation(
                  turns: panelOpen ? 0 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 12,
                    color: VikaIvory.invInk.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DebugHeader extends StatelessWidget {
  const _DebugHeader({
    required this.isDev,
    required this.phaseLabel,
    required this.repCount,
    required this.totalReps,
    required this.setSeconds,
    required this.fps,
    required this.frameTimestampMs,
    required this.onMinimize,
  });

  final bool isDev;
  final String phaseLabel;
  final int repCount;
  final int totalReps;
  final int setSeconds;
  final double fps;
  final int frameTimestampMs;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    final minutes = setSeconds ~/ 60;
    final seconds = setSeconds % 60;
    final timer = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModeChip(isDev: isDev),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    phaseLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: VikaIvory.invInk,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DebugStat(
                    label: isDev ? 'rep' : 'Lần',
                    value: '${repCount.toString().padLeft(2, '0')}/$totalReps',
                  ),
                  const SizedBox(width: 10),
                  _DebugStat(label: isDev ? 't' : 'Time', value: timer),
                  if (isDev) ...[
                    const SizedBox(width: 10),
                    _DebugStat(
                      label: 'fps',
                      value: fps.toStringAsFixed(0),
                      color: fps < 18
                          ? _DebugPalette.fault
                          : fps < 24
                              ? _DebugPalette.near
                              : _DebugPalette.dev,
                    ),
                    const SizedBox(width: 10),
                    _DebugStat(
                      label: 'ts',
                      value: frameTimestampMs.toString(),
                      dim: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onMinimize,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: VikaIvory.invInkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.isDev});

  final bool isDev;

  @override
  Widget build(BuildContext context) {
    final accent = isDev ? _DebugPalette.dev : VikaIvory.yellow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: accent, size: 4),
          const SizedBox(width: 5),
          Text(
            isDev ? 'DEBUG' : 'Chi tiết',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugStat extends StatelessWidget {
  const _DebugStat({
    required this.label,
    required this.value,
    this.color,
    this.dim = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: VikaIvory.invInkFaint,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: dim ? VikaIvory.invInkSoft : (color ?? VikaIvory.invInk),
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

class DebugMetricRow extends StatefulWidget {
  const DebugMetricRow({
    super.key,
    required this.tracked,
    required this.isDev,
    required this.isExpanded,
    required this.onTap,
  });

  final TrackedMetric tracked;
  final bool isDev;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  State<DebugMetricRow> createState() => _DebugMetricRowState();
}

class _DebugMetricRowState extends State<DebugMetricRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashController;
  MetricStatus? _previousStatus;

  @override
  void initState() {
    super.initState();
    _previousStatus = widget.tracked.status;
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void didUpdateWidget(covariant DebugMetricRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final status = widget.tracked.status;
    if (_previousStatus != MetricStatus.fault && status == MetricStatus.fault) {
      _flashController.forward(from: 0);
    }
    _previousStatus = status;
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracked = widget.tracked;
    final status = tracked.status;
    final statusColor = _statusColor(status);
    final label = widget.isDev
        ? tracked.metric.name
        : (tracked.metric.nameVi ?? tracked.metric.name);

    final baseBg = switch (status) {
      MetricStatus.fault => _DebugPalette.fault.withValues(alpha: 0.14),
      MetricStatus.near => _DebugPalette.near.withValues(alpha: 0.18),
      MetricStatus.pass => widget.isExpanded
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.02),
    };
    final borderColor = status == MetricStatus.fault
        ? _DebugPalette.fault.withValues(alpha: 0.32)
        : widget.isExpanded
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.transparent;

    return AnimatedBuilder(
      animation: _flashController,
      builder: (context, child) {
        final flash = Color.lerp(
          _DebugPalette.fault.withValues(alpha: 0.45),
          baseBg,
          Curves.easeOut.transform(_flashController.value),
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _flashController.isAnimating ? flash : baseBg,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(8),
                bottom: Radius.circular(widget.isExpanded ? 0 : 8),
              ),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: widget.isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 12,
                    color: status == MetricStatus.fault
                        ? _DebugPalette.fault
                        : VikaIvory.invInkFaint,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily:
                          widget.isDev ? 'monospace' : VikaIvory.fontFamily,
                      fontSize: widget.isDev ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: status == MetricStatus.fault
                          ? _DebugPalette.fault
                          : VikaIvory.invInk,
                      letterSpacing: widget.isDev ? 0 : -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 50,
                  height: 14,
                  child: PrimarySparkline(tracked: tracked),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 64,
                  child: Text(
                    _formatNullableValue(tracked.value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: status == MetricStatus.fault
                          ? _DebugPalette.fault
                          : VikaIvory.invInk,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusDot(status: status, color: statusColor),
                if (widget.isDev) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '×${tracked.faultCount}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: tracked.faultCount > 0
                            ? _DebugPalette.fault
                            : VikaIvory.invInkDim,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class ExpandedMetricSection extends StatelessWidget {
  const ExpandedMetricSection({
    super.key,
    required this.tracked,
    required this.mode,
    required this.frameTimestampMs,
  });

  final TrackedMetric tracked;
  final DebugMode mode;
  final int frameTimestampMs;

  @override
  Widget build(BuildContext context) {
    final isDev = mode == DebugMode.dev;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PayloadHistory(tracked: tracked, userMode: !isDev),
          if (isDev) ...[
            const SizedBox(height: 12),
            _PayloadDebugData(tracked: tracked),
            const SizedBox(height: 12),
            _PayloadTransitions(tracked: tracked),
          ] else ...[
            const SizedBox(height: 12),
            _PayloadUserSummary(
              tracked: tracked,
              frameTimestampMs: frameTimestampMs,
            ),
          ],
        ],
      ),
    );
  }
}

class _PayloadHistory extends StatelessWidget {
  const _PayloadHistory({required this.tracked, this.userMode = false});

  final TrackedMetric tracked;
  final bool userMode;

  @override
  Widget build(BuildContext context) {
    final samples = tracked.history;
    if (samples.length < 2) {
      return _PayloadSection(
        label: userMode ? 'Xu hướng' : 'History',
        hint: userMode ? 'đang ghi...' : 'collecting...',
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            userMode ? 'Cần thêm dữ liệu' : 'awaiting samples',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: VikaIvory.invInkDim,
              letterSpacing: 0.6,
            ),
          ),
        ),
      );
    }

    final seconds = (samples.length * 220 / 1000).toStringAsFixed(1);
    return _PayloadSection(
      label: userMode ? 'Xu hướng' : 'History',
      hint: userMode
          ? '${seconds}s qua'
          : '${samples.length} samples · ${seconds}s',
      child: HistorySparkline(tracked: tracked),
    );
  }
}

class _PayloadDebugData extends StatelessWidget {
  const _PayloadDebugData({required this.tracked});

  final TrackedMetric tracked;

  @override
  Widget build(BuildContext context) {
    final entries = tracked.metric.debugData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (entries.isEmpty) {
      return const _PayloadSection(
        label: 'Debug data',
        hint: 'empty',
        child: _EmptyPayloadText('nothing dumped yet'),
      );
    }

    final keyHistories = tracked.keyHistories;
    return _PayloadSection(
      label: 'Debug data',
      hint: '${entries.length} keys',
      child: Column(
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _DebugEntry(
                label: entry.key,
                value: entry.value,
                history: keyHistories[entry.key],
              ),
            ),
        ],
      ),
    );
  }
}

class _PayloadTransitions extends StatelessWidget {
  const _PayloadTransitions({required this.tracked});

  final TrackedMetric tracked;

  @override
  Widget build(BuildContext context) {
    final transitions = tracked.transitions.reversed.take(5).toList();
    if (transitions.isEmpty) {
      return const _PayloadSection(
        label: 'Transitions',
        hint: 'last 5',
        child: _EmptyPayloadText('none in this set'),
      );
    }

    return _PayloadSection(
      label: 'Transitions',
      hint: 'last ${transitions.length}',
      child: Column(
        children: [
          for (final transition in transitions)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: transition.to == MetricStatus.fault
                      ? _DebugPalette.fault.withValues(alpha: 0.06)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        (transition.frameTimestampMs % 100000).toString(),
                        style: _monoSmall(VikaIvory.invInkFaint),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            transition.from.name.toUpperCase(),
                            style: _monoSmall(_statusColor(transition.from)),
                          ),
                          Text(
                            ' → ',
                            style: _monoSmall(VikaIvory.invInkDim),
                          ),
                          Text(
                            transition.to.name.toUpperCase(),
                            style: _monoSmall(_statusColor(transition.to)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatNullableValue(transition.value),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: VikaIvory.invInk,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PayloadUserSummary extends StatelessWidget {
  const _PayloadUserSummary({
    required this.tracked,
    required this.frameTimestampMs,
  });

  final TrackedMetric tracked;
  final int frameTimestampMs;

  @override
  Widget build(BuildContext context) {
    StatusTransition? lastFault;
    for (final transition in tracked.transitions.reversed) {
      if (transition.to == MetricStatus.fault) {
        lastFault = transition;
        break;
      }
    }

    final hasFault = tracked.faultCount > 0;
    final sinceLast = lastFault == null
        ? null
        : ((frameTimestampMs - lastFault.frameTimestampMs) / 1000)
            .clamp(0.0, 999.0)
            .toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: hasFault
            ? _DebugPalette.fault.withValues(alpha: 0.08)
            : _DebugPalette.dev.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasFault
              ? _DebugPalette.fault.withValues(alpha: 0.20)
              : _DebugPalette.dev.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasFault
                ? 'Đã vi phạm ${tracked.faultCount} lần ở hiệp này'
                : '✓ Đang trong vùng an toàn',
            style: TextStyle(
              fontFamily: VikaIvory.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: hasFault ? _DebugPalette.fault : _DebugPalette.dev,
              letterSpacing: -0.1,
            ),
          ),
          if (hasFault && sinceLast != null) ...[
            const SizedBox(height: 4),
            Text(
              'Lần gần nhất: cách đây ${sinceLast}s',
              style: TextStyle(
                fontFamily: VikaIvory.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: VikaIvory.invInkSoft,
                letterSpacing: -0.05,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PayloadSection extends StatelessWidget {
  const _PayloadSection({
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: VikaIvory.invInkFaint,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            if (hint != null)
              Text(
                hint!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: VikaIvory.invInkDim,
                  letterSpacing: 0.4,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _DebugEntry extends StatelessWidget {
  const _DebugEntry({
    required this.label,
    required this.value,
    required this.history,
  });

  final String label;
  final dynamic value;
  final List<num>? history;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final showInlineSpark = v is num && history != null && history!.length >= 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(3),
      ),
      child: switch (v) {
        LandmarkInput landmark => _LandmarkEntry(label: label, value: landmark),
        Vector3 vector => _VectorEntry(label: label, value: vector),
        num number when showInlineSpark => Row(
            children: [
              Expanded(
                child: _EntryLabel(label: label),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                height: 14,
                child: InlineSparkline(data: history!),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatValue(number),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: _debugValueStyle(),
                ),
              ),
            ],
          ),
        _ => Row(
            children: [
              Expanded(child: _EntryLabel(label: label)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatDebugValue(v),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: _debugValueStyle(),
                ),
              ),
            ],
          ),
      },
    );
  }
}

class _LandmarkEntry extends StatelessWidget {
  const _LandmarkEntry({required this.label, required this.value});

  final String label;
  final LandmarkInput value;

  @override
  Widget build(BuildContext context) {
    final visColor = value.visibility < 0.7
        ? _DebugPalette.fault
        : value.visibility < 0.85
            ? _DebugPalette.near
            : _DebugPalette.dev;
    return Row(
      children: [
        Expanded(child: _EntryLabel(label: label, accent: value.derived)),
        const SizedBox(width: 8),
        SizedBox(
          width: 130,
          child: Text(
            '(${_formatValue(value.x)}, ${_formatValue(value.y)}, ${_formatValue(value.z)})',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _debugValueStyle(),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value.visibility.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: _debugValueStyle(color: visColor, size: 9),
          ),
        ),
        const SizedBox(width: 8),
        _VisDots(visibility: value.visibility),
      ],
    );
  }
}

class _VectorEntry extends StatelessWidget {
  const _VectorEntry({required this.label, required this.value});

  final String label;
  final Vector3 value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _EntryLabel(label: label)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '(${_formatValue(value.x)}, ${_formatValue(value.y)}, ${_formatValue(value.z)})',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: _debugValueStyle(),
          ),
        ),
      ],
    );
  }
}

class _EntryLabel extends StatelessWidget {
  const _EntryLabel({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: accent ? _DebugPalette.near : VikaIvory.invInkSoft,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _VisDots extends StatelessWidget {
  const _VisDots({required this.visibility});

  final double visibility;

  @override
  Widget build(BuildContext context) {
    final filled = (visibility * 4).round().clamp(0, 4);
    final color = visibility < 0.7
        ? _DebugPalette.fault
        : visibility < 0.85
            ? _DebugPalette.near
            : _DebugPalette.dev;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        return Container(
          width: 4,
          height: 4,
          margin: EdgeInsets.only(left: index == 0 ? 0 : 2),
          decoration: BoxDecoration(
            color:
                index < filled ? color : Colors.white.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _EmptyPayloadText extends StatelessWidget {
  const _EmptyPayloadText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: VikaIvory.invInkDim,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class HistorySparkline extends StatelessWidget {
  const HistorySparkline({
    super.key,
    required this.tracked,
    this.height = 56,
  });

  final TrackedMetric tracked;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 48;
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(
              painter: _HistorySparklinePainter(
                tracked: tracked,
                labelInsetRight: 8,
              ),
            ),
          ),
        );
      },
    );
  }
}

class PrimarySparkline extends StatelessWidget {
  const PrimarySparkline({
    super.key,
    required this.tracked,
    this.height = 14,
  });

  final TrackedMetric tracked;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 50.0;
        return SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _PrimarySparklinePainter(tracked: tracked),
          ),
        );
      },
    );
  }
}

class InlineSparkline extends StatelessWidget {
  const InlineSparkline({
    super.key,
    required this.data,
    this.height = 14,
  });

  final List<num> data;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 50.0;
        return SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _InlineSparklinePainter(data: data),
          ),
        );
      },
    );
  }
}

class _HistorySparklinePainter extends CustomPainter {
  const _HistorySparklinePainter({
    required this.tracked,
    required this.labelInsetRight,
  });

  final TrackedMetric tracked;
  final double labelInsetRight;

  @override
  void paint(Canvas canvas, Size size) {
    final samples = tracked.history;
    if (samples.length < 2 || size.width <= 0 || size.height <= 0) return;

    final values = samples.map((sample) => sample.value).toList();
    final band = tracked.threshold;
    final range = _valueRange(values, band);
    final plotRight = math.max(1.0, size.width - 4);

    double xOf(int index) =>
        1 + (index / math.max(1, samples.length - 1)) * (plotRight - 1);
    double yOf(double value) => _yOf(value, range, size.height);

    _drawZones(canvas, size, band, yOf);
    _drawThresholdLines(canvas, size, band, yOf, labelInsetRight);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.6;

    for (var i = 1; i < samples.length; i++) {
      paint.color = _statusColor(samples[i].status).withValues(
        alpha: samples[i].status == MetricStatus.fault ? 0.95 : 0.85,
      );
      canvas.drawLine(
        Offset(xOf(i - 1), yOf(samples[i - 1].value)),
        Offset(xOf(i), yOf(samples[i].value)),
        paint,
      );
    }

    final last = samples.last;
    final lastColor = _statusColor(last.status);
    final lastX = math.min(xOf(samples.length - 1), size.width - 4);
    final lastY = yOf(last.value).clamp(3.0, size.height - 3);
    canvas.drawCircle(
      Offset(lastX, lastY),
      3,
      Paint()
        ..color = lastColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(Offset(lastX, lastY), 3, Paint()..color = lastColor);
    canvas.drawCircle(
      Offset(lastX, lastY),
      1.4,
      Paint()..color = const Color(0xFF0E0A07),
    );
  }

  @override
  bool shouldRepaint(covariant _HistorySparklinePainter oldDelegate) => true;
}

class _PrimarySparklinePainter extends CustomPainter {
  const _PrimarySparklinePainter({required this.tracked});

  final TrackedMetric tracked;

  @override
  void paint(Canvas canvas, Size size) {
    final samples = tracked.history;
    if (samples.length < 2 || size.width <= 0 || size.height <= 0) return;

    final values = samples.map((sample) => sample.value).toList();
    final band = tracked.threshold;
    final range = _valueRange(values, band);
    double yOf(double value) => _yOf(value, range, size.height - 2) + 1;
    double xOf(int index) =>
        1 + (index / math.max(1, samples.length - 1)) * (size.width - 2);

    final linePaint = Paint()
      ..color = _DebugPalette.fault.withValues(alpha: 0.5)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    if (band?.faultAbove != null) {
      _drawDashedLine(
        canvas,
        Offset(0, yOf(band!.faultAbove!)),
        Offset(size.width, yOf(band.faultAbove!)),
        linePaint,
        dash: 2,
        gap: 2,
      );
    }
    if (band?.faultBelow != null) {
      _drawDashedLine(
        canvas,
        Offset(0, yOf(band!.faultBelow!)),
        Offset(size.width, yOf(band.faultBelow!)),
        linePaint,
        dash: 2,
        gap: 2,
      );
    }

    final color = _statusColor(samples.last.status);
    final sparkPaint = Paint()
      ..color = color
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(xOf(0), yOf(samples.first.value));
    for (var i = 1; i < samples.length; i++) {
      path.lineTo(xOf(i), yOf(samples[i].value));
    }
    canvas.drawPath(path, sparkPaint);
    canvas.drawCircle(
      Offset(
        math.min(xOf(samples.length - 1), size.width - 2),
        yOf(samples.last.value).clamp(1.5, size.height - 1.5),
      ),
      1.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _PrimarySparklinePainter oldDelegate) => true;
}

class _InlineSparklinePainter extends CustomPainter {
  const _InlineSparklinePainter({required this.data});

  final List<num> data;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2 || size.width <= 0 || size.height <= 0) return;

    final values = data.map((value) => value.toDouble()).toList();
    var minValue = values.reduce(math.min);
    var maxValue = values.reduce(math.max);
    if (minValue == maxValue) {
      minValue -= 0.5;
      maxValue += 0.5;
    }
    final range = maxValue - minValue;
    const pad = 1.5;
    double xOf(int index) =>
        1 + (index / math.max(1, values.length - 1)) * (size.width - 2);
    double yOf(double value) =>
        size.height -
        pad -
        ((value - minValue) / range) * (size.height - pad * 2);

    final recent = values.skip(math.max(0, values.length - 10)).toList();
    final recentRange = recent.length > 1
        ? recent.reduce(math.max) - recent.reduce(math.min)
        : 0.0;
    final variance = range > 0 ? recentRange / range : 0.0;
    final color = variance > 0.5
        ? _DebugPalette.near.withValues(alpha: 0.85)
        : VikaIvory.invInk.withValues(alpha: 0.55);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(xOf(0), yOf(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(xOf(i), yOf(values[i]));
    }
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(
        math.min(xOf(values.length - 1), size.width - 2),
        yOf(values.last).clamp(1.5, size.height - 1.5),
      ),
      1.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _InlineSparklinePainter oldDelegate) => true;
}

class _DebugFooter extends StatelessWidget {
  const _DebugFooter({
    required this.totalFaults,
    required this.confidence,
    required this.footerLabel,
  });

  final int totalFaults;
  final double confidence;
  final String footerLabel;

  @override
  Widget build(BuildContext context) {
    final confidenceColor = confidence < 0.7
        ? _DebugPalette.fault
        : confidence < 0.85
            ? _DebugPalette.near
            : _DebugPalette.dev;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          _DebugStat(
            label: 'faults',
            value: '$totalFaults',
            color: totalFaults > 0 ? _DebugPalette.fault : _DebugPalette.dev,
          ),
          const SizedBox(width: 14),
          _DebugStat(
            label: 'conf',
            value: confidence.toStringAsFixed(2),
            color: confidenceColor,
          ),
          const Spacer(),
          Text(
            footerLabel,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: VikaIvory.invInkDim,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = lerpDouble(1, 0.6, _controller.value)!;
        final scale = lerpDouble(1, 0.92, _controller.value)!;
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.7),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status, required this.color});

  final MetricStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: switch (status) {
              MetricStatus.fault => _DebugPalette.faultGlow,
              MetricStatus.near => _DebugPalette.near.withValues(alpha: 0.5),
              MetricStatus.pass => _DebugPalette.dev.withValues(alpha: 0.4),
            },
            blurRadius: status == MetricStatus.fault ? 8 : 5,
          ),
        ],
      ),
    );
  }
}

class _DebugPalette {
  static const Color dev = Color(0xFF5BFFB0);
  static const Color fault = Color(0xFFEF4F4F);
  static const Color near = Color(0xFFE89A4B);
  static const Color faultGlow = Color.fromRGBO(239, 79, 79, 0.55);
  static const Color glassBorderHi = Color.fromRGBO(255, 255, 255, 0.16);
}

Color _statusColor(MetricStatus status) {
  return switch (status) {
    MetricStatus.fault => _DebugPalette.fault,
    MetricStatus.near => _DebugPalette.near,
    MetricStatus.pass => _DebugPalette.dev,
  };
}

TextStyle _monoSmall(Color color) {
  return TextStyle(
    fontFamily: 'monospace',
    fontSize: 9,
    fontWeight: FontWeight.w700,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
    letterSpacing: 0.2,
  );
}

TextStyle _debugValueStyle({Color? color, double size = 10}) {
  return TextStyle(
    fontFamily: 'monospace',
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: color ?? VikaIvory.invInk,
    fontFeatures: const [FontFeature.tabularFigures()],
    letterSpacing: -0.2,
  );
}

String _formatNullableValue(num? value) {
  if (value == null) return '-';
  return _formatValue(value);
}

String _formatValue(num value) {
  final asDouble = value.toDouble();
  if (asDouble.isNaN || asDouble.isInfinite) return asDouble.toString();
  if (asDouble == asDouble.roundToDouble()) return asDouble.toInt().toString();
  final abs = asDouble.abs();
  if (abs >= 100) return asDouble.toStringAsFixed(1);
  if (abs >= 10) return asDouble.toStringAsFixed(2);
  return asDouble.toStringAsFixed(3);
}

String _formatDebugValue(dynamic value) {
  return switch (value) {
    num number => _formatValue(number),
    bool flag => flag ? '✓' : '✗',
    String text => text,
    List list => '(${list.map(_formatDebugValue).join(', ')})',
    _ => value.toString(),
  };
}

({double min, double max}) _valueRange(
  List<double> values,
  ThresholdBand? band,
) {
  final all = <double>[...values];
  final bounds = [
    band?.faultAbove,
    band?.warningAbove,
    band?.faultBelow,
    band?.warningBelow,
  ];
  for (final bound in bounds) {
    if (bound != null && bound.isFinite) all.add(bound);
  }
  if (all.isEmpty) return (min: 0, max: 1);

  var minValue = all.reduce(math.min);
  var maxValue = all.reduce(math.max);
  if (minValue == maxValue) {
    minValue -= 0.5;
    maxValue += 0.5;
  }
  final pad = math.max((maxValue - minValue) * 0.15, 0.01);
  return (min: minValue - pad, max: maxValue + pad);
}

double _yOf(double value, ({double min, double max}) range, double height) {
  final normalized = (value - range.min) / (range.max - range.min);
  return height - normalized * height;
}

void _drawZones(
  Canvas canvas,
  Size size,
  ThresholdBand? band,
  double Function(double value) yOf,
) {
  if (band == null) return;

  final passTopData = band.warningAbove ?? band.faultAbove;
  final passBottomData = band.warningBelow ?? band.faultBelow;
  final passTop = passTopData != null ? yOf(passTopData) : 0.0;
  final passBottom = passBottomData != null ? yOf(passBottomData) : size.height;

  canvas.drawRect(
    Rect.fromLTRB(0, passTop, size.width, passBottom),
    Paint()..color = _DebugPalette.dev.withValues(alpha: 0.06),
  );

  if (band.faultAbove != null && band.warningAbove != null) {
    final y1 = yOf(band.faultAbove!);
    final y2 = yOf(band.warningAbove!);
    canvas.drawRect(
      Rect.fromLTRB(0, math.min(y1, y2), size.width, math.max(y1, y2)),
      Paint()..color = _DebugPalette.near.withValues(alpha: 0.10),
    );
  }
  if (band.faultBelow != null && band.warningBelow != null) {
    final y1 = yOf(band.warningBelow!);
    final y2 = yOf(band.faultBelow!);
    canvas.drawRect(
      Rect.fromLTRB(0, math.min(y1, y2), size.width, math.max(y1, y2)),
      Paint()..color = _DebugPalette.near.withValues(alpha: 0.10),
    );
  }
}

void _drawThresholdLines(
  Canvas canvas,
  Size size,
  ThresholdBand? band,
  double Function(double value) yOf,
  double labelInsetRight,
) {
  if (band == null) return;

  final warningPaint = Paint()
    ..color = _DebugPalette.near.withValues(alpha: 0.5)
    ..strokeWidth = 0.8;
  if (band.warningAbove != null && band.faultAbove != null) {
    final y = yOf(band.warningAbove!);
    _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), warningPaint);
  }
  if (band.warningBelow != null && band.faultBelow != null) {
    final y = yOf(band.warningBelow!);
    _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), warningPaint);
  }

  final faultPaint = Paint()
    ..color = _DebugPalette.fault.withValues(alpha: 0.65)
    ..strokeWidth = 1;

  void drawFault(double value, {required bool above}) {
    final y = yOf(value);
    _drawDashedLine(
      canvas,
      Offset(0, y),
      Offset(size.width, y),
      faultPaint,
      dash: 3,
      gap: 4,
    );
    final label = _formatValue(value);
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: _DebugPalette.fault.withValues(alpha: 0.9),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    )..layout(maxWidth: 60);
    final labelY =
        (above ? y - 11 : y + 2).clamp(2.0, size.height - painter.height - 2);
    painter.paint(
      canvas,
      Offset(size.width - labelInsetRight - painter.width, labelY),
    );
  }

  if (band.faultAbove != null) drawFault(band.faultAbove!, above: true);
  if (band.faultBelow != null) drawFault(band.faultBelow!, above: false);
}

void _drawDashedLine(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint, {
  double dash = 4,
  double gap = 5,
}) {
  final delta = end - start;
  final distance = delta.distance;
  if (distance <= 0) return;
  final direction = delta / distance;
  var drawn = 0.0;
  while (drawn < distance) {
    final segmentEnd = math.min(drawn + dash, distance);
    canvas.drawLine(
      start + direction * drawn,
      start + direction * segmentEnd,
      paint,
    );
    drawn += dash + gap;
  }
}
