import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

const double _gainSliderMinDb = -69.0;
const double _gainSliderMaxDb = 24.0;
const int _gainSliderDivisions = 31;

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
  int _externalRegister = MicrophoneGain.defaultRegister;
  int _internalRegister = MicrophoneGain.defaultRegister;
  int _lastExternalRegister = MicrophoneGain.defaultRegister;
  int _lastInternalRegister = MicrophoneGain.defaultRegister;
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

    final colorScheme = Theme.of(context).colorScheme;
    final disabled = _loading || _writing || _muted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _pairedOutOfSync
              ? colorScheme.error.withValues(alpha: 0.7)
              : colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Microphone Gain',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (_pairedOutOfSync) ...[
                const SizedBox(width: 8),
                _OutOfSyncIndicator(color: colorScheme.error),
              ],
              const Spacer(),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Checkbox.adaptive(
                value: _linked,
                onChanged: _loading || _writing
                    ? null
                    : (value) => _setLinked(value ?? false),
              ),
              Expanded(
                child: Text(
                  'Link microphones',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _loading || _writing ? null : _toggleMute,
                icon: Icon(
                  _muted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  size: 18,
                ),
                label: Text(_muted ? 'Unmute' : 'Mute'),
              ),
            ],
          ),
          if (_loading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ] else ...[
            const SizedBox(height: 8),
            _GainSlider(
              label: 'External',
              register: _externalRegister,
              fallbackRegister: _lastExternalRegister,
              enabled: !disabled,
              onChanged: (db) => _updateGain(external: true, db: db),
              onChangeEnd: (_) => _writeGain(),
            ),
            _GainSlider(
              label: 'Internal',
              register: _internalRegister,
              fallbackRegister: _lastInternalRegister,
              enabled: !disabled && !_linked,
              onChanged: (db) => _updateGain(external: false, db: db),
              onChangeEnd: (_) => _writeGain(),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colorScheme.error),
            ),
          ],
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

      setState(() {
        _externalRegister = gain.externalRegister;
        _internalRegister = gain.internalRegister;
        _muted = gain.isMuted;
        _linked = gain.externalRegister == gain.internalRegister;
        if (!gain.isMuted) {
          _lastExternalRegister = gain.externalRegister;
          _lastInternalRegister = gain.internalRegister;
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
    return first.externalRegister == second.externalRegister &&
        first.internalRegister == second.internalRegister;
  }

  void _setLinked(bool linked) {
    setState(() {
      _linked = linked;
      if (linked) {
        _internalRegister = _externalRegister;
        _lastInternalRegister = _lastExternalRegister;
      }
    });
    if (linked && !_muted) {
      _writeGain();
    }
  }

  void _updateGain({required bool external, required double db}) {
    final register = MicrophoneGain.dbToRegister(db.roundToDouble());
    setState(() {
      if (_linked) {
        _externalRegister = register;
        _internalRegister = register;
        _lastExternalRegister = register;
        _lastInternalRegister = register;
      } else if (external) {
        _externalRegister = register;
        _lastExternalRegister = register;
      } else {
        _internalRegister = register;
        _lastInternalRegister = register;
      }
    });
  }

  Future<void> _toggleMute() async {
    setState(() {
      if (_muted) {
        _externalRegister = _lastExternalRegister;
        _internalRegister =
            _linked ? _lastExternalRegister : _lastInternalRegister;
        _muted = false;
      } else {
        _lastExternalRegister = _externalRegister == MicrophoneGain.muteRegister
            ? MicrophoneGain.defaultRegister
            : _externalRegister;
        _lastInternalRegister = _internalRegister == MicrophoneGain.muteRegister
            ? MicrophoneGain.defaultRegister
            : _internalRegister;
        _externalRegister = MicrophoneGain.muteRegister;
        _internalRegister = MicrophoneGain.muteRegister;
        _muted = true;
      }
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
      final gain = MicrophoneGain(
        externalRegister: _externalRegister,
        internalRegister: _internalRegister,
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

class _OutOfSyncIndicator extends StatelessWidget {
  final Color color;

  const _OutOfSyncIndicator({required this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Paired devices report different microphone gains',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: color.withValues(alpha: 0.12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync_problem_rounded, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              'Out of sync',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              register == MicrophoneGain.muteRegister
                  ? 'Muted'
                  : '${_formatDb(sliderValue)} (${_formatRegister(register)})',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        Slider.adaptive(
          min: _gainSliderMinDb,
          max: _gainSliderMaxDb,
          divisions: _gainSliderDivisions,
          value: sliderValue,
          label: _formatDb(sliderValue),
          onChanged: enabled ? onChanged : null,
          onChangeEnd: enabled ? onChangeEnd : null,
        ),
      ],
    );
  }

  String _formatDb(double db) {
    final value = db.abs() < 0.001 ? 0.0 : db;
    final sign = value > 0 ? '+' : '';
    return '$sign${value.round()} dB';
  }

  String _formatRegister(int register) {
    return '0x${register.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }
}
