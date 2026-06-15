import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/models/permissions_helper.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothPermissionsPage extends StatefulWidget {
  const BluetoothPermissionsPage({
    super.key,
    this.onCompleted,
    this.onBluetoothRequestCompleted,
  });

  final Future<void> Function(BuildContext context)? onCompleted;
  final Future<void> Function()? onBluetoothRequestCompleted;

  @override
  State<BluetoothPermissionsPage> createState() =>
      _BluetoothPermissionsPageState();
}

class _BluetoothPermissionsPageState extends State<BluetoothPermissionsPage>
    with WidgetsBindingObserver {
  static const Duration _postGrantTransitionDelay = Duration(
    milliseconds: 180,
  );

  bool _requestInProgress = false;
  bool _granted = false;
  bool _advanced = false;
  bool _awaitingMacDialogCompletion = false;
  bool _sawInactiveDuringMacRequest = false;
  bool _macPermissionPolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_awaitingMacDialogCompletion ||
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _sawInactiveDuringMacRequest = true;
      return;
    }

    if (state == AppLifecycleState.resumed && _sawInactiveDuringMacRequest) {
      _awaitingMacDialogCompletion = false;
      _sawInactiveDuringMacRequest = false;
      unawaited(_waitForMacPermissionGrantAndAdvance());
    }
  }

  Future<void> _refresh() async {
    final has = await _hasBlePermissions();
    if (!mounted) return;
    setState(() => _granted = has);
    if (_granted) {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_advanceAfterBluetoothPermissionWithDelay());
      });
    }
  }

  Future<bool> _hasBlePermissions() async {
    return await PermissionsHelper.hasBlePermissions();
  }

  void _advanceAfterBluetoothPermission() {
    if (_advanced) {
      return;
    }
    _advanced = true;

    final requiresMicrophoneOnboarding =
        defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.windows;
    if (!requiresMicrophoneOnboarding) {
      unawaited(_completeOnboarding());
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MicrophonePermissionsPage(onCompleted: widget.onCompleted),
      ),
    );
  }

  Future<void> _advanceAfterBluetoothPermissionWithDelay() async {
    await Future<void>.delayed(_postGrantTransitionDelay);
    if (!mounted || _advanced) {
      return;
    }
    _advanceAfterBluetoothPermission();
  }

  Future<void> _request() async {
    if (_granted) {
      await widget.onBluetoothRequestCompleted?.call();
      await _advanceAfterBluetoothPermissionWithDelay();
      return;
    }

    if (_requestInProgress) return;
    setState(() => _requestInProgress = true);
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _awaitingMacDialogCompletion = true;
      _sawInactiveDuringMacRequest = false;
    }
    try {
      final hasPermissions = await PermissionsHelper.requestBlePermissions();
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        if (_sawInactiveDuringMacRequest) {
          return;
        }
        _awaitingMacDialogCompletion = false;
        if (hasPermissions) {
          await widget.onBluetoothRequestCompleted?.call();
          await _advanceAfterBluetoothPermissionWithDelay();
          return;
        }
        await _waitForMacPermissionGrantAndAdvance();
        return;
      }
      if (!mounted) return;
      setState(() => _granted = hasPermissions);
      if (hasPermissions) {
        await widget.onBluetoothRequestCompleted?.call();
        await _advanceAfterBluetoothPermissionWithDelay();
      }
    } catch (_) {
      _awaitingMacDialogCompletion = false;
      await _refresh();
    } finally {
      if (mounted) setState(() => _requestInProgress = false);
    }
  }

  Future<void> _checkMacPermissionAndAdvanceIfGranted() async {
    final hasPermissions = await PermissionsHelper.hasBlePermissions();
    if (!mounted) return;
    setState(() => _granted = hasPermissions);
    if (!hasPermissions) {
      return;
    }
    await widget.onBluetoothRequestCompleted?.call();
    await _advanceAfterBluetoothPermissionWithDelay();
  }

  Future<void> _waitForMacPermissionGrantAndAdvance() async {
    if (_macPermissionPolling) {
      return;
    }
    _macPermissionPolling = true;
    try {
      // macOS permission propagation can lag behind the dialog dismissal.
      for (var i = 0; i < 20; i++) {
        await _checkMacPermissionAndAdvanceIfGranted();
        if (_advanced || !mounted) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } finally {
      _macPermissionPolling = false;
    }
  }

  Future<void> _completeOnboarding() async {
    final completion = widget.onCompleted;
    if (completion != null) {
      await completion(context);
      return;
    }

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PlatformScaffold(
      appBar: PlatformAppBar(
        automaticallyImplyLeading: false,
        title: const Text('Bluetooth Permission'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Spacer(),
              Icon(Icons.bluetooth, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                defaultTargetPlatform == TargetPlatform.android
                    ? 'Enable Bluetooth & Location'
                    : 'Enable Bluetooth',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                defaultTargetPlatform == TargetPlatform.android
                    ? 'Bluetooth and Location are required to discover and connect to your wearable device. Location permission is needed by some platforms for BLE scanning.'
                    : 'Bluetooth is required to discover and connect to your wearable device.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              const SizedBox(height: 32),
              PlatformElevatedButton(
                onPressed: _requestInProgress ? null : _request,
                child: Text(
                  _requestInProgress
                      ? 'Requesting...'
                      : _granted
                          ? 'Continue'
                          : 'Enable Bluetooth',
                ),
              ),
              const SizedBox(height: 8),
              PlatformTextButton(
                onPressed: _requestInProgress ? null : _completeOnboarding,
                child: const Text('Skip for now'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Second onboarding screen: Microphone permission
class MicrophonePermissionsPage extends StatefulWidget {
  const MicrophonePermissionsPage({super.key, this.onCompleted});

  final Future<void> Function(BuildContext context)? onCompleted;

  @override
  State<MicrophonePermissionsPage> createState() =>
      _MicrophonePermissionsPageState();
}

class _MicrophonePermissionsPageState extends State<MicrophonePermissionsPage> {
  static const Duration _postGrantTransitionDelay = Duration(
    milliseconds: 180,
  );

  bool _requestInProgress = false;
  bool _granted = false;
  bool _completionStarted = false;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final mic = await Permission.microphone.status;
    if (!mounted) return;
    setState(() => _granted = mic.isGranted);
    if (_granted) {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_completeOnboardingWithDelay());
      });
    }
  }

  Future<void> _completeOnboardingWithDelay() async {
    await Future<void>.delayed(_postGrantTransitionDelay);
    if (!mounted || _completionStarted) {
      return;
    }
    await _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    if (_completionStarted) return;
    _completionStarted = true;

    try {
      final completion = widget.onCompleted;
      if (completion != null) {
        await completion(context);
        return;
      }

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } finally {
      _completionStarted = false;
    }
  }

  Future<void> _request() async {
    if (_requestInProgress) return;
    setState(() => _requestInProgress = true);
    try {
      await Permission.microphone.request();
      await _refresh();
    } catch (_) {
      await _refresh();
    } finally {
      if (mounted) setState(() => _requestInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PlatformScaffold(
      appBar: PlatformAppBar(
        automaticallyImplyLeading: false,
        title: const Text('Microphone Permission'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Spacer(),
              Icon(Icons.mic, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                'Enable Microphone',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Microphone access lets the wearable record audio alongside sensor data for synchronized captures. Audio is stored locally unless you choose to share it.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              const SizedBox(height: 32),
              PlatformElevatedButton(
                onPressed: _requestInProgress ? null : _request,
                child: Text(
                  _requestInProgress ? 'Requesting...' : 'Enable Microphone',
                ),
              ),
              const SizedBox(height: 8),
              PlatformTextButton(
                onPressed: _requestInProgress ? null : _completeOnboarding,
                child: const Text('Skip for now'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
