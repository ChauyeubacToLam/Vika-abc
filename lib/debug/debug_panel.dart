import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';

import '../theme/vf_theme.dart';
import 'debug_types.dart';

class DebugPanel extends StatefulWidget {
  const DebugPanel({
    super.key,
    required this.mode,
    required this.debugData,
    required this.phaseLabel,
    required this.repCount,
    required this.totalReps,
    required this.setSeconds,
    required this.fps,
    required this.footerLabel,
    required this.fullscreen,
    required this.onToggleFullscreen,
    required this.onMinimize,
  });

  final DebugMode mode;
  final Map<String, dynamic> debugData;
  final String phaseLabel;
  final int repCount;
  final int totalReps;
  final int setSeconds;
  final double fps;
  final String footerLabel;
  // Fullscreen is host-owned so the host can hide the camera scrims + guidance
  // mode-scrim behind the panel — that is what lets the see-through glass
  // composite over the live PT feed. Freeze + group-collapse stay local.
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onMinimize;

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  static const Duration _sampleInterval = Duration(milliseconds: 150);
  static const ThresholdBand _fpsBand = ThresholdBand(
    warningBelow: 24,
    faultBelow: 18,
  );

  Timer? _sampleTimer;
  List<MapEntry<String, dynamic>> _entries = const [];
  bool _frozen = false;
  final Set<String> _collapsedGroups = {};
  double _fps = 0;
  String _phaseLabel = '';
  int _repCount = 0;
  int _totalReps = 0;
  int _setSeconds = 0;
  String _footerLabel = '';

  @override
  void initState() {
    super.initState();
    _captureSnapshot();
    _sampleTimer = Timer.periodic(_sampleInterval, (_) {
      if (!mounted) return;
      if (_frozen) return;
      setState(_captureSnapshot);
    });
  }

  @override
  void dispose() {
    _sampleTimer?.cancel();
    super.dispose();
  }

  void _captureSnapshot() {
    final entries = widget.debugData.entries
        .map((entry) => MapEntry(entry.key, entry.value))
        .toList();
    entries.sort((a, b) => a.key.compareTo(b.key));

    _entries = List.unmodifiable(entries);
    _fps = widget.fps;
    _phaseLabel = widget.phaseLabel;
    _repCount = widget.repCount;
    _totalReps = widget.totalReps;
    _setSeconds = widget.setSeconds;
    _footerLabel = widget.footerLabel;
  }

  void _toggleFrozen() {
    setState(() {
      if (_frozen) {
        _frozen = false;
        _captureSnapshot();
      } else {
        _captureSnapshot();
        _frozen = true;
      }
    });
  }

  void _toggleGroup(String groupName) {
    setState(() {
      if (!_collapsedGroups.add(groupName)) {
        _collapsedGroups.remove(groupName);
      }
    });
  }

  List<_DebugGroup> _groupedEntries() {
    final grouped = <String, List<MapEntry<String, dynamic>>>{};
    for (final entry in _entries) {
      final group = _groupName(entry.key);
      grouped.putIfAbsent(group, () => []).add(entry);
    }

    return [
      for (final entry in grouped.entries)
        _DebugGroup(name: entry.key, entries: List.unmodifiable(entry.value)),
    ];
  }

  String _groupName(String key) {
    final dot = key.indexOf('.');
    if (dot <= 0) return 'misc';
    return key.substring(0, dot);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode != DebugMode.dev) return const SizedBox.shrink();

    final fpsStatus = _fpsBand.evaluate(_fps);
    final groups = _groupedEntries();

    // SafeArea keeps the panel clear of the landscape side notch/home
    // indicator, and LayoutBuilder binds the panel height to the real
    // viewport so a short landscape stage can't drive a RenderFlex overflow —
    // in portrait the available height dwarfs 430, so compact geometry is
    // unchanged. The bottom 16 padding is subtracted so the cap accounts for
    // the gap below the compact panel.
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final panel = _buildPanelSurface(
            fpsStatus: fpsStatus,
            groups: groups,
            availableHeight: constraints.maxHeight,
          );

          if (widget.fullscreen) {
            return SizedBox.expand(child: panel);
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [panel],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPanelSurface({
    required MetricStatus fpsStatus,
    required List<_DebugGroup> groups,
    required double availableHeight,
  }) {
    final fullscreen = widget.fullscreen;
    final radius = BorderRadius.circular(fullscreen ? 0 : 16);
    // Fullscreen glass is see-through by design: near-transparent fill + a
    // light blur that only softens text edges (heavy blur would smear the PT
    // behind the dump into mush). The per-row _RowShell scrims still carry the
    // number legibility. Compact stays opaque + heavily blurred as before.
    final blurSigma = fullscreen ? 7.0 : 18.0;
    final fillAlpha = fullscreen ? 0.08 : 0.84;
    final constraints = fullscreen
        ? const BoxConstraints.expand()
        : BoxConstraints(
            maxHeight: math.min(430.0, math.max(0.0, availableHeight - 16)),
          );

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          constraints: constraints,
          decoration: BoxDecoration(
            color: Color.fromRGBO(15, 11, 8, fillAlpha),
            borderRadius: radius,
            border: Border.all(color: _DebugPalette.glassBorderHi),
            boxShadow: [
              if (!fullscreen)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.50),
                  blurRadius: 34,
                  offset: const Offset(0, 14),
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
                        _DebugPalette.dev.withValues(alpha: 0.52),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              if (fullscreen)
                Positioned.fill(
                  child: _buildPanelContents(
                    fpsStatus: fpsStatus,
                    groups: groups,
                  ),
                )
              else
                _buildPanelContents(
                  fpsStatus: fpsStatus,
                  groups: groups,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanelContents({
    required MetricStatus fpsStatus,
    required List<_DebugGroup> groups,
  }) {
    final fullscreen = widget.fullscreen;
    return Column(
      mainAxisSize: fullscreen ? MainAxisSize.max : MainAxisSize.min,
      children: [
        _DebugHeader(
          keyCount: _entries.length,
          groupCount: groups.length,
          fullscreen: fullscreen,
          frozen: _frozen,
          onToggleFullscreen: widget.onToggleFullscreen,
          onToggleFrozen: _toggleFrozen,
          onMinimize: widget.onMinimize,
        ),
        _PinnedRows(
          fps: _fps,
          fpsStatus: fpsStatus,
          phaseLabel: _phaseLabel,
          repCount: _repCount,
          totalReps: _totalReps,
          setSeconds: _setSeconds,
          fullscreen: fullscreen,
        ),
        Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: _GroupedDebugData(
              groups: groups,
              collapsedGroups: _collapsedGroups,
              fullscreen: fullscreen,
              onToggleGroup: _toggleGroup,
            ),
          ),
        ),
        _DebugFooter(
          keyCount: _entries.length,
          groupCount: groups.length,
          frozen: _frozen,
          footerLabel: _footerLabel,
        ),
      ],
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
    if (mode != DebugMode.dev) return const SizedBox.shrink();

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
              color: _DebugPalette.dev.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: _DebugPalette.dev.withValues(alpha: 0.32),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BadgeDot(),
                const SizedBox(width: 5),
                const Text(
                  'DEV',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: VikaIvory.invInk,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 5),
                AnimatedRotation(
                  turns: panelOpen ? 0 : 0.5,
                  duration: const Duration(milliseconds: 180),
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
    required this.keyCount,
    required this.groupCount,
    required this.fullscreen,
    required this.frozen,
    required this.onToggleFullscreen,
    required this.onToggleFrozen,
    required this.onMinimize,
  });

  final int keyCount;
  final int groupCount;
  final bool fullscreen;
  final bool frozen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onToggleFrozen;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
          14, fullscreen ? media.padding.top + 8 : 10, 10, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          const _ModeChip(),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'exercise.debugData',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: VikaIvory.invInk.withValues(alpha: 0.92),
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$keyCount keys · $groupCount groups',
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: VikaIvory.invInkFaint,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            tooltip: frozen ? 'Resume sampling' : 'Freeze sampling',
            icon: frozen ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: frozen ? _DebugPalette.near : VikaIvory.invInkSoft,
            onTap: onToggleFrozen,
          ),
          const SizedBox(width: 6),
          _HeaderIconButton(
            tooltip: fullscreen ? 'Compact panel' : 'Fullscreen panel',
            icon: fullscreen
                ? Icons.close_fullscreen_rounded
                : Icons.open_in_full_rounded,
            onTap: onToggleFullscreen,
          ),
          const SizedBox(width: 6),
          _HeaderIconButton(
            tooltip: 'Minimize',
            icon: Icons.keyboard_arrow_down_rounded,
            onTap: onMinimize,
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _DebugPalette.dev.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _DebugPalette.dev.withValues(alpha: 0.28)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BadgeDot(size: 4),
          SizedBox(width: 5),
          Text(
            'DEBUG',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _DebugPalette.dev,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(
            icon,
            size: 15,
            color: color ?? VikaIvory.invInkSoft,
          ),
        ),
      ),
    );
  }
}

class _PinnedRows extends StatelessWidget {
  const _PinnedRows({
    required this.fps,
    required this.fpsStatus,
    required this.phaseLabel,
    required this.repCount,
    required this.totalReps,
    required this.setSeconds,
    required this.fullscreen,
  });

  final double fps;
  final MetricStatus fpsStatus;
  final String phaseLabel;
  final int repCount;
  final int totalReps;
  final int setSeconds;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) {
    final minutes = setSeconds ~/ 60;
    final seconds = setSeconds % 60;
    final timer = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          _PinnedRow(
            label: 'fps',
            value: _formatValue(fps),
            valueColor: _statusColor(fpsStatus),
            status: fpsStatus,
            fullscreen: fullscreen,
          ),
          const SizedBox(height: 3),
          _PinnedRow(
            label: 'phase',
            value: phaseLabel,
            fullscreen: fullscreen,
          ),
          const SizedBox(height: 3),
          _PinnedRow(
            label: 'rep / time',
            value: '$repCount/$totalReps  $timer',
            fullscreen: fullscreen,
          ),
        ],
      ),
    );
  }
}

class _PinnedRow extends StatelessWidget {
  const _PinnedRow({
    required this.label,
    required this.value,
    required this.fullscreen,
    this.valueColor,
    this.status,
  });

  final String label;
  final String value;
  final bool fullscreen;
  final Color? valueColor;
  final MetricStatus? status;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      fullscreen: fullscreen,
      child: Row(
        children: [
          Expanded(child: _EntryLabel(label: label)),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: _debugValueStyle(color: valueColor),
            ),
          ),
          if (status != null) ...[
            const SizedBox(width: 8),
            _StatusDot(status: status!, color: _statusColor(status!)),
          ],
        ],
      ),
    );
  }
}

class _DebugGroup {
  const _DebugGroup({
    required this.name,
    required this.entries,
  });

  final String name;
  final List<MapEntry<String, dynamic>> entries;
}

class _GroupedDebugData extends StatelessWidget {
  const _GroupedDebugData({
    required this.groups,
    required this.collapsedGroups,
    required this.fullscreen,
    required this.onToggleGroup,
  });

  final List<_DebugGroup> groups;
  final Set<String> collapsedGroups;
  final bool fullscreen;
  final ValueChanged<String> onToggleGroup;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return _EmptyDebugData(fullscreen: fullscreen);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700 && groups.length > 1;
        if (!wide) {
          return Column(
            children: [
              for (final group in groups)
                _DebugGroupSection(
                  key: ValueKey('debug-group-${group.name}'),
                  group: group,
                  collapsed: collapsedGroups.contains(group.name),
                  fullscreen: fullscreen,
                  onToggle: onToggleGroup,
                ),
            ],
          );
        }

        final columns = _splitGroups(groups, collapsedGroups);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final group in columns.$1)
                    _DebugGroupSection(
                      key: ValueKey('debug-group-left-${group.name}'),
                      group: group,
                      collapsed: collapsedGroups.contains(group.name),
                      fullscreen: fullscreen,
                      onToggle: onToggleGroup,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  for (final group in columns.$2)
                    _DebugGroupSection(
                      key: ValueKey('debug-group-right-${group.name}'),
                      group: group,
                      collapsed: collapsedGroups.contains(group.name),
                      fullscreen: fullscreen,
                      onToggle: onToggleGroup,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  (List<_DebugGroup>, List<_DebugGroup>) _splitGroups(
    List<_DebugGroup> source,
    Set<String> collapsed,
  ) {
    final left = <_DebugGroup>[];
    final right = <_DebugGroup>[];
    var leftRows = 0;
    var rightRows = 0;

    for (final group in source) {
      final rowCount =
          collapsed.contains(group.name) ? 1 : group.entries.length + 1;
      if (leftRows <= rightRows) {
        left.add(group);
        leftRows += rowCount;
      } else {
        right.add(group);
        rightRows += rowCount;
      }
    }

    return (left, right);
  }
}

class _DebugGroupSection extends StatelessWidget {
  const _DebugGroupSection({
    super.key,
    required this.group,
    required this.collapsed,
    required this.fullscreen,
    required this.onToggle,
  });

  final _DebugGroup group;
  final bool collapsed;
  final bool fullscreen;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DebugGroupHeader(
            groupName: group.name,
            count: group.entries.length,
            collapsed: collapsed,
            fullscreen: fullscreen,
            onTap: () => onToggle(group.name),
          ),
          if (!collapsed) ...[
            const SizedBox(height: 3),
            for (final entry in group.entries)
              Padding(
                key: ValueKey(entry.key),
                padding: const EdgeInsets.only(bottom: 3),
                child: _DebugDataRow(
                  label: _entryLabel(entry.key, group.name),
                  value: entry.value,
                  fullscreen: fullscreen,
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _entryLabel(String key, String groupName) {
    if (groupName == 'misc') return key;
    final prefix = '$groupName.';
    if (!key.startsWith(prefix)) return key;
    final label = key.substring(prefix.length);
    return label.isEmpty ? key : label;
  }
}

class _DebugGroupHeader extends StatelessWidget {
  const _DebugGroupHeader({
    required this.groupName,
    required this.count,
    required this.collapsed,
    required this.fullscreen,
    required this.onTap,
  });

  final String groupName;
  final int count;
  final bool collapsed;
  final bool fullscreen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: fullscreen
              ? Colors.black.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color:
                _DebugPalette.dev.withValues(alpha: fullscreen ? 0.18 : 0.12),
          ),
        ),
        child: Row(
          children: [
            AnimatedRotation(
              turns: collapsed ? 0 : 0.25,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: VikaIvory.invInkFaint,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                groupName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: _DebugPalette.dev,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              count.toString(),
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: VikaIvory.invInkFaint,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugDataRow extends StatelessWidget {
  const _DebugDataRow({
    required this.label,
    required this.value,
    required this.fullscreen,
  });

  final String label;
  final dynamic value;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      fullscreen: fullscreen,
      child: switch (value) {
        LandmarkInput landmark => _LandmarkEntry(label: label, value: landmark),
        Vector3 vector => _VectorEntry(label: label, value: vector),
        _ => Row(
            children: [
              Expanded(child: _EntryLabel(label: label)),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  _formatDebugValue(value),
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

class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.child,
    required this.fullscreen,
  });

  final Widget child;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        // Fullscreen fill is near-transparent now, so the row scrim does all
        // the legibility work over the live feed — nudged darker to compensate.
        color: fullscreen
            ? Colors.black.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.026),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: Colors.white.withValues(alpha: fullscreen ? 0.06 : 0.035),
        ),
      ),
      child: child,
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
        Expanded(
          flex: 2,
          child: Text(
            '(${_formatValue(value.x)}, ${_formatValue(value.y)}, ${_formatValue(value.z)})',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: _debugValueStyle(),
          ),
        ),
        const SizedBox(width: 8),
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
          flex: 2,
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
        letterSpacing: 0,
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

class _DebugFooter extends StatelessWidget {
  const _DebugFooter({
    required this.keyCount,
    required this.groupCount,
    required this.frozen,
    required this.footerLabel,
  });

  final int keyCount;
  final int groupCount;
  final bool frozen;
  final String footerLabel;

  @override
  Widget build(BuildContext context) {
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
          Text(
            '$keyCount keys · $groupCount groups · '
            '${frozen ? 'frozen' : 'sampled @ 150ms'}',
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: VikaIvory.invInkFaint,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              footerLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: VikaIvory.invInkDim,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDebugData extends StatelessWidget {
  const _EmptyDebugData({required this.fullscreen});

  final bool fullscreen;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      fullscreen: fullscreen,
      child: Text(
        'debugData is empty',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: VikaIvory.invInkDim,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _BadgeDot extends StatelessWidget {
  const _BadgeDot({this.size = 5});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _DebugPalette.dev,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _DebugPalette.dev.withValues(alpha: 0.65),
            blurRadius: 5,
          ),
        ],
      ),
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
      width: 8,
      height: 8,
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

TextStyle _debugValueStyle({Color? color, double size = 10}) {
  return TextStyle(
    fontFamily: 'monospace',
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: color ?? VikaIvory.invInk,
    fontFeatures: const [FontFeature.tabularFigures()],
    letterSpacing: 0,
  );
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
    bool flag => flag ? 'true' : 'false',
    String text => text,
    List list => '(${list.map(_formatDebugValue).join(', ')})',
    Map map => '{${map.entries.map(
          (entry) => '${entry.key}: ${_formatDebugValue(entry.value)}',
        ).join(', ')}}',
    null => 'null',
    _ => value.toString(),
  };
}
