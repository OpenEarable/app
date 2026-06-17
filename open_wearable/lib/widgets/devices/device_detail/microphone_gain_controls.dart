import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

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
  int _leftRegister = MicrophoneGain.defaultRegister;
  int _rightRegister = MicrophoneGain.defaultRegister;
  int _lastLeftRegister = MicrophoneGain.defaultRegister;
  int _lastRightRegister = MicrophoneGain.defaultRegister;
  bool _linked = true;
  bool _muted = false;
  bool _loading = true;
  bool _writing = false;
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
    final manager = _manager;
    if (manager == null) {
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
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Microphone Gain',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading || _writing ? null : _readGain,
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
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
                  'Link channels',
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
              label: 'Left',
              register: _leftRegister,
              fallbackRegister: _lastLeftRegister,
              enabled: !disabled,
              onChanged: (db) => _updateGain(left: true, db: db),
              onChangeEnd: (_) => _writeGain(),
            ),
            _GainSlider(
              label: 'Right',
              register: _rightRegister,
              fallbackRegister: _lastRightRegister,
              enabled: !disabled && !_linked,
              onChanged: (db) => _updateGain(left: false, db: db),
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
    if (manager == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final gain = await manager.getMicrophoneGain();
      if (!mounted) return;
      setState(() {
        _leftRegister = gain.leftRegister;
        _rightRegister = gain.rightRegister;
        _muted = gain.isMuted;
        _linked = gain.leftRegister == gain.rightRegister;
        if (!gain.isMuted) {
          _lastLeftRegister = gain.leftRegister;
          _lastRightRegister = gain.rightRegister;
        }
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

  void _setLinked(bool linked) {
    setState(() {
      _linked = linked;
      if (linked) {
        _rightRegister = _leftRegister;
        _lastRightRegister = _lastLeftRegister;
      }
    });
    if (linked && !_muted) {
      _writeGain();
    }
  }

  void _updateGain({required bool left, required double db}) {
    final register = MicrophoneGain.dbToRegister(db);
    setState(() {
      if (_linked) {
        _leftRegister = register;
        _rightRegister = register;
        _lastLeftRegister = register;
        _lastRightRegister = register;
      } else if (left) {
        _leftRegister = register;
        _lastLeftRegister = register;
      } else {
        _rightRegister = register;
        _lastRightRegister = register;
      }
    });
  }

  Future<void> _toggleMute() async {
    setState(() {
      if (_muted) {
        _leftRegister = _lastLeftRegister;
        _rightRegister = _linked ? _lastLeftRegister : _lastRightRegister;
        _muted = false;
      } else {
        _lastLeftRegister = _leftRegister == MicrophoneGain.muteRegister
            ? MicrophoneGain.defaultRegister
            : _leftRegister;
        _lastRightRegister = _rightRegister == MicrophoneGain.muteRegister
            ? MicrophoneGain.defaultRegister
            : _rightRegister;
        _leftRegister = MicrophoneGain.muteRegister;
        _rightRegister = MicrophoneGain.muteRegister;
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
        leftRegister: _leftRegister,
        rightRegister: _rightRegister,
      );
      await manager.setMicrophoneGain(gain);
      if (_hasPairedTarget) {
        await _pairedManager!.setMicrophoneGain(gain);
      }
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
                  : '${_formatDb(db)} (${_formatRegister(register)})',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        Slider.adaptive(
          min: MicrophoneGain.minGainDb,
          max: MicrophoneGain.maxGainDb,
          divisions: MicrophoneGain.minGainRegister,
          value: db,
          label: _formatDb(db),
          onChanged: enabled ? onChanged : null,
          onChangeEnd: enabled ? onChangeEnd : null,
        ),
      ],
    );
  }

  String _formatDb(double db) {
    final value = db.abs() < 0.001 ? 0.0 : db;
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)} dB';
  }

  String _formatRegister(int register) {
    return '0x${register.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }
}
