import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/models/audio_input_availability.dart';
import 'package:open_wearable/models/audio_input_source.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider_facade.dart';
import 'package:provider/provider.dart';

/// Displays app-local microphone recording as a virtual sensor configuration.
///
/// The card intentionally mirrors wearable sensor configuration rows while
/// writing only to [SensorRecorderProvider]. It does not apply settings to a
/// physical wearable.
class MicrophoneConfigurationCard extends StatefulWidget {
  const MicrophoneConfigurationCard({super.key});

  /// Whether app-local microphone configuration should be visible.
  static bool get isSupported => AudioInputAvailability.isSupported;

  @override
  State<MicrophoneConfigurationCard> createState() =>
      _MicrophoneConfigurationCardState();
}

class _MicrophoneConfigurationCardState
    extends State<MicrophoneConfigurationCard> with WidgetsBindingObserver {
  bool _refreshStarted = false;
  SensorRecorderProvider? _recorderProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<SensorRecorderProvider>();
    if (!identical(_recorderProvider, provider)) {
      _recorderProvider?.stopAudioInputSourceRefresh();
      _recorderProvider = provider;
      _refreshStarted = false;
    }
    if (_refreshStarted) {
      return;
    }
    _refreshStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recorderProvider?.startAudioInputSourceRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recorderProvider?.refreshAudioInputSources();
    }
  }

  @override
  void dispose() {
    _recorderProvider?.stopAudioInputSourceRefresh();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorRecorderProvider>(
      builder: (context, recorderProvider, _) {
        final selectedSource = recorderProvider.selectedAudioInputSource;
        final isPending = recorderProvider.isAudioInputSelectionPending;
        final isApplied = !isPending && selectedSource != null;
        final isOn = selectedSource != null || isPending;
        final colorScheme = Theme.of(context).colorScheme;
        const sensorOnGreen = Color(0xFF2E7D32);
        final accentColor = isPending
            ? colorScheme.primary
            : (isApplied ? sensorOnGreen : colorScheme.outline);

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    PlatformText(
                      'System Audio',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () =>
                        _openMicrophoneSheet(context, recorderProvider),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: isOn ? 3 : 2,
                            height: 26,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(
                                alpha: isOn ? 0.7 : 0.6,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _iconForSource(selectedSource),
                            size: 14,
                            color: isOn ? accentColor : colorScheme.outline,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'System Microphone',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: isOn ? accentColor : null,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _SourcePill(
                            label: selectedSource?.label ?? 'Off',
                            foreground: isOn
                                ? accentColor
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  void _openMicrophoneSheet(
    BuildContext context,
    SensorRecorderProvider recorderProvider,
  ) {
    showPlatformModalSheet<void>(
      context: context,
      builder: (modalContext) {
        return ChangeNotifierProvider.value(
          value: recorderProvider,
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.of(modalContext).size.height * 0.52,
              child: Material(
                color: Theme.of(modalContext).colorScheme.surface,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Microphone',
                                  style: Theme.of(modalContext)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Select the audio source recorded with local sessions.',
                                  style: Theme.of(modalContext)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(modalContext)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(modalContext).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                    const Expanded(child: _MicrophoneConfigurationDetail()),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _iconForSource(AudioInputSource? source) {
    if (source == null) {
      return Icons.mic_off_rounded;
    }
    return switch (source.kind) {
      AudioInputSourceKind.systemDefault => Icons.settings_voice_rounded,
      AudioInputSourceKind.builtIn => Icons.phone_android_rounded,
      AudioInputSourceKind.bluetooth => Icons.bluetooth_audio_rounded,
      AudioInputSourceKind.wearable => Icons.hearing_rounded,
      AudioInputSourceKind.external => Icons.cable_rounded,
      AudioInputSourceKind.unknown => Icons.mic_rounded,
    };
  }
}

class _MicrophoneConfigurationDetail extends StatelessWidget {
  const _MicrophoneConfigurationDetail();

  static const String _offSelectionKey = '__audio_input_off__';

  @override
  Widget build(BuildContext context) {
    final recorderProvider = context.watch<SensorRecorderProvider>();
    final sources = recorderProvider.audioInputSources;
    final selected = _resolveSelectedSource(
      sources,
      recorderProvider.selectedAudioInputSource,
    );
    final colorScheme = Theme.of(context).colorScheme;
    final dropdownValues = <AudioInputSource>[
      ...sources,
      if (selected != null && !sources.contains(selected)) selected,
    ];
    final selectedKey = selected?.id ?? _offSelectionKey;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      children: [
        Text(
          'Audio Source',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          recorderProvider.isRecording
              ? 'Audio source changes are locked while recording.'
              : 'Choose a source, then apply profiles to start monitoring.',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: selectedKey,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: _offSelectionKey,
              child: Text('Off'),
            ),
            ...dropdownValues.map(
              (source) => DropdownMenuItem<String>(
                value: source.id,
                child: Text(source.label),
              ),
            ),
          ],
          onChanged: recorderProvider.isRecording
              ? null
              : (key) async {
                  if (key == null || key == _offSelectionKey) {
                    await recorderProvider.selectAudioInputSource(null);
                    return;
                  }
                  await recorderProvider.selectAudioInputSource(
                    dropdownValues.firstWhere((source) => source.id == key),
                  );
                },
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: recorderProvider.refreshAudioInputSources,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh inputs'),
          ),
        ),
      ],
    );
  }

  AudioInputSource? _resolveSelectedSource(
    List<AudioInputSource> sources,
    AudioInputSource? selected,
  ) {
    if (selected == null) {
      return null;
    }
    for (final source in sources) {
      if (source.id == selected.id) {
        return source;
      }
    }
    return selected;
  }
}

class _SourcePill extends StatelessWidget {
  final String label;
  final Color foreground;

  const _SourcePill({
    required this.label,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 22,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: foreground.withValues(alpha: 0.42),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150, minWidth: 38),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}
