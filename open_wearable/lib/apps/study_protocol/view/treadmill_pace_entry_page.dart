import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import 'package:open_wearable/apps/study_protocol/model/study_session.dart';
import 'package:open_wearable/apps/study_protocol/model/study_treadmill_pace_storage.dart';

/// Prompts for the treadmill walking pace (km/h) and stores it as a CSV before
/// the treadmill timer starts.
///
/// Shown right after the treadmill seal check. [onContinue] is invoked once the
/// pace has been saved, and is responsible for navigating to the timer.
class TreadmillPaceEntryPage extends StatefulWidget {
  final StudySession session;
  final String directory;
  final VoidCallback onContinue;

  const TreadmillPaceEntryPage({
    super.key,
    required this.session,
    required this.directory,
    required this.onContinue,
  });

  @override
  State<TreadmillPaceEntryPage> createState() => _TreadmillPaceEntryPageState();
}

class _TreadmillPaceEntryPageState extends State<TreadmillPaceEntryPage> {
  final TextEditingController _paceController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _paceController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    // Accept both `5.5` and `5,5` as the decimal separator.
    final normalized = _paceController.text.trim().replaceAll(',', '.');
    final pace = double.tryParse(normalized);
    if (pace == null || pace <= 0) {
      setState(() => _error = 'Enter a valid walking pace in km/h.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await saveTreadmillWalkingPace(
        directory: widget.directory,
        probandId: widget.session.probandId,
        walkingPaceKmh: pace,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = 'Failed to save the walking pace: $e';
        });
      }
      return;
    }
    if (mounted) {
      widget.onContinue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PlatformScaffold(
      material: (_, __) => MaterialScaffoldData(
        resizeToAvoidBottomInset: false,
      ),
      cupertino: (_, __) => CupertinoPageScaffoldData(
        resizeToAvoidBottomInset: false,
      ),
      appBar: PlatformAppBar(title: PlatformText('Walking pace')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Spacer(),
                        Container(
                          height: 72,
                          width: 72,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.directions_walk,
                            size: 38,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Step 3 · Treadmill',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Walking pace',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Enter the treadmill walking pace before starting the '
                          'timer.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        PlatformTextField(
                          controller: _paceController,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          hintText: 'Walking pace (km/h)',
                          material: (_, __) => MaterialTextFieldData(
                            decoration: const InputDecoration(
                              labelText: 'Walking pace (km/h)',
                              suffixText: 'km/h',
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: PlatformElevatedButton(
                            onPressed: _isSaving ? null : _continue,
                            child: PlatformText(
                              _isSaving ? 'Saving…' : 'Continue to timer',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
