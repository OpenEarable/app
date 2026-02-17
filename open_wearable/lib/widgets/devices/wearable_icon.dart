import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

/// Reusable wearable icon renderer with optional stereo-side resolution.
class WearableIcon extends StatefulWidget {
  final Wearable wearable;
  final WearableIconVariant initialVariant;
  final bool resolveStereoPositionWhenSingleVariant;
  final bool hideWhileResolvingStereoPosition;
  final bool hideWhenResolvedVariantIsSingle;
  final BoxFit fit;
  final Widget? fallback;

  const WearableIcon({
    super.key,
    required this.wearable,
    required this.initialVariant,
    this.resolveStereoPositionWhenSingleVariant = true,
    this.hideWhileResolvingStereoPosition = false,
    this.hideWhenResolvedVariantIsSingle = false,
    this.fit = BoxFit.contain,
    this.fallback,
  });

  @override
  State<WearableIcon> createState() => _WearableIconState();
}

class _WearableIconState extends State<WearableIcon> {
  static final Expando<Future<DevicePosition?>> _positionFutureCache =
      Expando<Future<DevicePosition?>>();

  Future<DevicePosition?>? _positionFuture;

  @override
  void initState() {
    super.initState();
    _configurePositionFuture();
  }

  @override
  void didUpdateWidget(covariant WearableIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.wearable, widget.wearable) ||
        oldWidget.initialVariant != widget.initialVariant ||
        oldWidget.resolveStereoPositionWhenSingleVariant !=
            widget.resolveStereoPositionWhenSingleVariant) {
      _configurePositionFuture();
    }
  }

  void _configurePositionFuture() {
    if (!widget.resolveStereoPositionWhenSingleVariant ||
        widget.initialVariant != WearableIconVariant.single ||
        !widget.wearable.hasCapability<StereoDevice>()) {
      _positionFuture = null;
      return;
    }

    final stereoDevice = widget.wearable.requireCapability<StereoDevice>();
    _positionFuture =
        _positionFutureCache[stereoDevice] ??= stereoDevice.position;
  }

  WearableIconVariant _variantForPosition(DevicePosition? position) {
    return switch (position) {
      DevicePosition.left => WearableIconVariant.left,
      DevicePosition.right => WearableIconVariant.right,
      _ => widget.initialVariant,
    };
  }

  String? _resolveIconPath(WearableIconVariant variant) {
    final variantPath = widget.wearable.getWearableIconPath(variant: variant);
    if (variantPath != null && variantPath.isNotEmpty) {
      return variantPath;
    }

    if (variant != WearableIconVariant.single) {
      final fallbackPath = widget.wearable.getWearableIconPath();
      if (fallbackPath != null && fallbackPath.isNotEmpty) {
        return fallbackPath;
      }
    }

    return null;
  }

  Widget _buildFallback() {
    return widget.fallback ?? const SizedBox.shrink();
  }

  Widget _buildIcon(WearableIconVariant variant) {
    final path = _resolveIconPath(variant);
    if (path == null) {
      return _buildFallback();
    }

    if (path.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        path,
        fit: widget.fit,
        placeholderBuilder: (_) => _buildFallback(),
      );
    }

    return Image.asset(
      path,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => _buildFallback(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_positionFuture == null) {
      return _buildIcon(widget.initialVariant);
    }

    return FutureBuilder<DevicePosition?>(
      future: _positionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            widget.hideWhileResolvingStereoPosition) {
          return _buildFallback();
        }

        final variant = _variantForPosition(snapshot.data);
        if (variant == WearableIconVariant.single &&
            widget.hideWhenResolvedVariantIsSingle) {
          return _buildFallback();
        }
        return _buildIcon(variant);
      },
    );
  }
}
