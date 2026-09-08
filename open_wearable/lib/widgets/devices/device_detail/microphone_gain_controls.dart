import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

const double _gainSliderMinDb = -69.0;
const double _gainSliderMaxDb = 24.0;
const int _gainSliderDivisions = 31;
const Color _appliedConfigurationGreen = Color(0xFF2E7D32);

class MicrophoneGainControls extends StatefulWidget {
  final Wearable? device;
  final Wearable? pairedDevice;

  const MicrophoneGainControls({
    super.key,
    required this.device,
    this.pairedDevice,
  });

  @override
  State<MicrophoneGainControls> createState() => _MicrophoneGainControlsState();
}

class _MicrophoneGainControlsState extends State<MicrophoneGainControls> {
  int _outerRegister = MicrophoneGain.defaultRegister;
  int _innerRegister = MicrophoneGain.defaultRegister;
  int _lastOuterRegister = MicrophoneGain.defaultRegister;
  int _lastInnerRegister = MicrophoneGain.defaultRegister;
  bool _linked = true;
  bool _muted = false;
  bool _loading = true;
  bool _writing = false;
  bool _pairedOutOfSync = false;
  String? _error;

  MicrophoneGainManager? get _manager =>
      widget.device?.getCapability<MicrophoneGainManager>();

  MicrophoneGainManager? get _pairedManager =>
      widget.pairedDevice?.getCapability<MicrophoneGainManager>();

  bool get _hasPairedTarget =>
      widget.pairedDevice != null &&
      widget.pairedDevice?.deviceId != widget.device?.deviceId &&
      _pairedManager != null;

  @override
  void initState() {
    super.initState();
    _readGain();
  }

  @override
  void didUpdateWidget(covariant MicrophoneGainControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device?.deviceId != widget.device?.deviceId ||
        oldWidget.pairedDevice?.deviceId != widget.pairedDevice?.deviceId) {
      _readGain();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_manager == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final disabled = _loading || _writing || _muted;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Microphone Gain', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Adjust inner and outer mic levels.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_pairedOutOfSync) ...[
          const _OutOfSyncBanner(),
          const SizedBox(height: 8),
        ],
        if (_loading) ...[
          const LinearProgressIndicator(minHeight: 2),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _GainLinkControl(
                linked: _linked,
                onChanged: _loading || _writing ? null : _setLinked,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  children: [
                    _GainSlider(
                      label: 'Outer',
                      register: _outerRegister,
                      fallbackRegister: _lastOuterRegister,
                      enabled: !disabled,
                      onChanged: (db) => _updateGain(outer: true, db: db),
                      onChangeEnd: (_) => _writeGain(),
                    ),
                    const SizedBox(
                      key: Key('microphone-gain-row-spacing'),
                      height: 4,
                    ),
                    _GainSlider(
                      label: 'Inner',
                      register: _innerRegister,
                      fallbackRegister: _lastInnerRegister,
                      enabled: !disabled,
                      onChanged: (db) => _updateGain(outer: false, db: db),
                      onChangeEnd: (_) => _writeGain(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading || _writing ? null : _resetToDefault,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _loading || _writing ? null : _toggleMute,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: _muted
                        ? colorScheme.errorContainer
                        : Colors.transparent,
                    foregroundColor: _muted
                        ? colorScheme.onErrorContainer
                        : colorScheme.onSurfaceVariant,
                    side: BorderSide(
                      color: _muted
                          ? Colors.transparent
                          : colorScheme.outlineVariant,
                    ),
                  ),
                  icon: Icon(
                    _muted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    size: 18,
                  ),
                  label: Text(_muted ? 'Unmute' : 'Mute'),
                ),
              ),
            ],
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.error,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 8),
          if (_hasPairedTarget)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                key: const Key('microphone-gain-controls-padding'),
                padding: const EdgeInsets.all(12),
                child: controls,
              ),
            )
          else
            controls,
        ],
      ),
    );
  }

  Future<void> _readGain() async {
    final manager = _manager;
    final pairedManager = _pairedManager;
    if (manager == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _pairedOutOfSync = false;
      });
      return;
    }

    final hasPairedTarget = widget.pairedDevice != null &&
        widget.pairedDevice?.deviceId != widget.device?.deviceId &&
        pairedManager != null;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final gain = await manager.getMicrophoneGain();
      final pairedGain =
          hasPairedTarget ? await pairedManager.getMicrophoneGain() : null;
      if (!mounted) return;

      final outerRegister = _outerRegisterFrom(gain);
      final innerRegister = _innerRegisterFrom(gain);
      setState(() {
        _outerRegister = outerRegister;
        _innerRegister = innerRegister;
        _muted = gain.isMuted;
        _linked = outerRegister == innerRegister;
        if (!gain.isMuted) {
          _lastOuterRegister = outerRegister;
          _lastInnerRegister = innerRegister;
        }
        _pairedOutOfSync =
            pairedGain != null && !_sameMicrophoneGain(gain, pairedGain);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not read microphone gain.';
      });
    }
  }

  bool _sameMicrophoneGain(MicrophoneGain first, MicrophoneGain second) {
    return _outerRegisterFrom(first) == _outerRegisterFrom(second) &&
        _innerRegisterFrom(first) == _innerRegisterFrom(second);
  }

  void _setLinked(bool linked) {
    setState(() {
      _linked = linked;
      if (linked) {
        _innerRegister = _outerRegister;
        _lastInnerRegister = _lastOuterRegister;
      }
    });
    if (linked && !_muted) {
      _writeGain();
    }
  }

  void _updateGain({required bool outer, required double db}) {
    final register = MicrophoneGain.dbToRegister(db.roundToDouble());
    setState(() {
      if (_linked) {
        _outerRegister = register;
        _innerRegister = register;
        _lastOuterRegister = register;
        _lastInnerRegister = register;
      } else if (outer) {
        _outerRegister = register;
        _lastOuterRegister = register;
      } else {
        _innerRegister = register;
        _lastInnerRegister = register;
      }
    });
  }

  Future<void> _toggleMute() async {
    setState(() {
      if (_muted) {
        _outerRegister = _lastOuterRegister;
        _innerRegister = _linked ? _lastOuterRegister : _lastInnerRegister;
        _muted = false;
      } else {
        _lastOuterRegister = _outerRegister == MicrophoneGain.muteRegister
            ? MicrophoneGain.defaultRegister
            : _outerRegister;
        _lastInnerRegister = _innerRegister == MicrophoneGain.muteRegister
            ? MicrophoneGain.defaultRegister
            : _innerRegister;
        _outerRegister = MicrophoneGain.muteRegister;
        _innerRegister = MicrophoneGain.muteRegister;
        _muted = true;
      }
    });
    await _writeGain();
  }

  Future<void> _resetToDefault() async {
    setState(() {
      _outerRegister = MicrophoneGain.defaultRegister;
      _innerRegister = MicrophoneGain.defaultRegister;
      _lastOuterRegister = MicrophoneGain.defaultRegister;
      _lastInnerRegister = MicrophoneGain.defaultRegister;
      _linked = true;
      _muted = false;
    });
    await _writeGain();
  }

  Future<void> _writeGain() async {
    final manager = _manager;
    if (manager == null) {
      return;
    }

    setState(() {
      _writing = true;
      _error = null;
    });

    try {
      final gain = _microphoneGainFromRegisters(
        outerRegister: _outerRegister,
        innerRegister: _innerRegister,
      );
      await manager.setMicrophoneGain(gain);
      if (_hasPairedTarget) {
        await _pairedManager!.setMicrophoneGain(gain);
      }
      if (!mounted) return;
      setState(() {
        _pairedOutOfSync = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _hasPairedTarget
            ? 'Could not write microphone gain to both devices.'
            : 'Could not write microphone gain.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _writing = false;
        });
      }
    }
  }
}

int _outerRegisterFrom(MicrophoneGain gain) => gain.outerRegister;

int _innerRegisterFrom(MicrophoneGain gain) => gain.innerRegister;

MicrophoneGain _microphoneGainFromRegisters({
  required int outerRegister,
  required int innerRegister,
}) {
  return MicrophoneGain(
    outerRegister: outerRegister,
    innerRegister: innerRegister,
  );
}

class _OutOfSyncBanner extends StatelessWidget {
  const _OutOfSyncBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    return Container(
      key: const Key('microphone-gain-mismatch-warning'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: errorColor.withValues(alpha: 0.38)),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_problem_rounded, color: errorColor, size: 17),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Left and right gains differ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GainLinkControl extends StatelessWidget {
  final bool linked;
  final ValueChanged<bool>? onChanged;

  const _GainLinkControl({
    required this.linked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final connectorColor = linked
        ? _appliedConfigurationGreen
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.65);
    final linkedBackground = Color.alphaBlend(
      _appliedConfigurationGreen.withValues(alpha: 0.12),
      colorScheme.surface,
    );
    final tooltip = linked
        ? 'Unlink inner and outer microphones'
        : 'Link inner and outer microphones';

    return Semantics(
      button: true,
      toggled: linked,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          key: const Key('microphone-gain-link-control'),
          width: 40,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GainConnectorPainter(
                    color: connectorColor,
                    linked: linked,
                  ),
                ),
              ),
              Material(
                key: const Key('microphone-gain-link-button-surface'),
                color: linked
                    ? linkedBackground
                    : colorScheme.surfaceContainerHighest,
                shape: CircleBorder(
                  side: BorderSide(
                    color: connectorColor.withValues(alpha: 0.7),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onChanged == null ? null : () => onChanged!(!linked),
                  child: SizedBox.square(
                    dimension: 32,
                    child: Icon(
                      linked ? Icons.link_rounded : Icons.link_off_rounded,
                      size: 18,
                      color: connectorColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GainConnectorPainter extends CustomPainter {
  final Color color;
  final bool linked;

  const _GainConnectorPainter({
    required this.color,
    required this.linked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final connectorX = size.width * 0.45;
    const topY = 24.0;
    final bottomY = size.height - 24;

    canvas.drawLine(
      Offset(connectorX, topY),
      Offset(size.width, topY),
      paint,
    );
    canvas.drawLine(
      Offset(connectorX, bottomY),
      Offset(size.width, bottomY),
      paint,
    );

    if (linked) {
      canvas.drawLine(
        Offset(connectorX, topY),
        Offset(connectorX, bottomY),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(connectorX, topY),
        Offset(connectorX, size.height * 0.38),
        paint,
      );
      canvas.drawLine(
        Offset(connectorX, size.height * 0.62),
        Offset(connectorX, bottomY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GainConnectorPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.linked != linked;
  }
}

class _GainSlider extends StatelessWidget {
  final String label;
  final int register;
  final int fallbackRegister;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _GainSlider({
    required this.label,
    required this.register,
    required this.fallbackRegister,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final displayRegister =
        register == MicrophoneGain.muteRegister ? fallbackRegister : register;
    final db = MicrophoneGain.registerToDb(displayRegister) ??
        MicrophoneGain.registerToDb(MicrophoneGain.defaultRegister)!;
    final sliderValue = db.clamp(_gainSliderMinDb, _gainSliderMaxDb).toDouble();

    final displayValue = register == MicrophoneGain.muteRegister
        ? 'Muted'
        : _formatDb(sliderValue);

    return Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(
            label,
            maxLines: 1,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 12,
              ),
            ),
            child: Slider.adaptive(
              min: _gainSliderMinDb,
              max: _gainSliderMaxDb,
              divisions: _gainSliderDivisions,
              value: sliderValue,
              label: _formatDb(sliderValue),
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ),
        ),
        SizedBox(
          width: 58,
          child: Text(
            displayValue,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

String _formatDb(double db) {
  final value = db.abs() < 0.001 ? 0.0 : db;
  final sign = value > 0 ? '+' : '';
  return '$sign${value.round()} dB';
}
