import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class LoopingAssetVideo extends StatefulWidget {
  const LoopingAssetVideo({
    super.key,
    required this.asset,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.fallback,
  });

  final String asset;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? fallback;

  @override
  State<LoopingAssetVideo> createState() => _LoopingAssetVideoState();
}

class _LoopingAssetVideoState extends State<LoopingAssetVideo> {
  static final Set<String> _failedAssets = <String>{};

  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LoopingAssetVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _disposeController();
      _load();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _load() {
    _hasError = false;
    if (_failedAssets.contains(widget.asset)) {
      _hasError = true;
      _initializeFuture = null;
      return;
    }
    final controller = VideoPlayerController.asset(widget.asset);
    _controller = controller;
    controller.addListener(_handleControllerUpdate);
    _initializeFuture = _initializeController(controller);
  }

  Future<void> _initializeController(VideoPlayerController controller) async {
    try {
      await controller.initialize();
      if (!mounted || _controller != controller) return;
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (mounted && _controller == controller) setState(() {});
    } catch (_) {
      if (mounted && _controller == controller) {
        _failedAssets.add(widget.asset);
        setState(() => _hasError = true);
      }
    }
  }

  void _handleControllerUpdate() {
    final controller = _controller;
    if (controller == null || _hasError || !controller.value.hasError) return;
    _failedAssets.add(widget.asset);
    if (mounted) setState(() => _hasError = true);
  }

  void _disposeController() {
    final controller = _controller;
    if (controller == null) return;
    controller.removeListener(_handleControllerUpdate);
    controller.dispose();
    _controller = null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || _hasError || controller.value.hasError) {
      return widget.fallback ?? const SizedBox.shrink();
    }

    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          return widget.fallback ?? const SizedBox.shrink();
        }
        return FittedBox(
          fit: widget.fit,
          alignment: widget.alignment,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }
}
