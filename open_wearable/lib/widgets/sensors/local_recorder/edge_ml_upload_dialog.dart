import 'package:edge_ml_dart/edge_ml_dart.dart';
import 'package:flutter/material.dart';
import 'package:open_wearable/services/edge_ml/recording_importer.dart';

import 'local_recorder_models.dart';

/// Preview a completed recording and upload only after an explicit user action.
Future<void> showEdgeMlUploadDialog(
  BuildContext context,
  LocalRecorderRecordingFolder folder, {
  Future<EdgeMlRecordingImport> Function(LocalRecorderRecordingFolder)? prepare,
  Future<String> Function(DatasetRecording, String)? upload,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _EdgeMlUploadDialog(folder: folder, prepare: prepare, upload: upload),
);

Future<String> _uploadRecording(
  DatasetRecording recording,
  String apiKey,
) async {
  final client = EdgeML(apiKey: apiKey);
  try {
    return await client.datasets.upload(recording);
  } finally {
    client.close();
  }
}

class _EdgeMlUploadDialog extends StatefulWidget {
  const _EdgeMlUploadDialog({required this.folder, this.prepare, this.upload});

  final LocalRecorderRecordingFolder folder;
  final Future<EdgeMlRecordingImport> Function(LocalRecorderRecordingFolder)?
  prepare;
  final Future<String> Function(DatasetRecording, String)? upload;

  @override
  State<_EdgeMlUploadDialog> createState() => _EdgeMlUploadDialogState();
}

class _EdgeMlUploadDialogState extends State<_EdgeMlUploadDialog> {
  final _key = TextEditingController();
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  EdgeMlRecordingImport? _preview;
  String? _error;
  String? _datasetId;
  bool _preparing = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.folder.name);
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final prepare = widget.prepare ?? const EdgeMlRecordingImporter().read;
      final preview = await prepare(widget.folder);
      if (mounted) setState(() => _preview = preview);
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not read this recording. Close this window and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _upload() async {
    if (_uploading || _preview == null || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    final apiKey = _key.text.trim();
    try {
      final source = _preview!.recording;
      final recording = DatasetRecording(
        _name.text.trim(),
        metadata: source.metadata,
        units: source.units,
        quantities: source.quantities,
      );
      for (final series in source.timeSeries.entries) {
        for (final (time, value) in series.value) {
          recording.add(series.key, value, timestamp: time);
        }
      }
      for (final label in source.labels) {
        recording.addLabel(label);
      }
      final upload = widget.upload ?? _uploadRecording;
      final id = await upload(recording, apiKey);
      if (mounted) {
        setState(() => _datasetId = id);
        _key.clear();
      }
    } on AuthenticationException {
      if (mounted) {
        setState(
          () => _error =
              'The key was rejected. Use the project’s Device API write key.',
        );
      }
    } catch (_) {
      // API URLs contain the write key. Never display or log raw HTTP errors.
      if (mounted) {
        setState(
          () => _error =
              'Upload did not complete. Check your connection and Edge ML '
              'project before retrying: a partial dataset may have been created. '
              'Retrying creates a new dataset.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  void dispose() {
    _key.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return PopScope(
      canPop: !_uploading,
      child: AlertDialog(
        title: const Text('Upload to Edge ML'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_preparing) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    const Text('Preparing sensor data and labels…'),
                  ],
                  if (_datasetId != null) ...[
                    const Text('Sensor data and labels uploaded successfully.'),
                    const SizedBox(height: 12),
                    SelectableText('Dataset ID: $_datasetId'),
                    const SizedBox(height: 12),
                    const Text(
                      'Open your project at app.edge-ml.org to review the dataset.',
                    ),
                  ] else if (preview != null) ...[
                    Text(
                      '${preview.channelNames.length} channels · '
                      '${preview.recording.length} values · '
                      '${preview.recording.labels.length} label intervals',
                    ),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      title: const Text('Channels'),
                      children: [
                        SizedBox(
                          height: 110,
                          child: SingleChildScrollView(
                            child: SelectableText(
                              preview.channelNames.join('\n'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final warning in preview.warnings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(warning),
                      ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _name,
                      enabled: !_uploading,
                      decoration: const InputDecoration(
                        labelText: 'Dataset name',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a dataset name.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _key,
                      enabled: !_uploading,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Device API write key',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter the project’s write key.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Find the write key in Edge ML → project settings → Device API. '
                      'It is used for this upload and is not saved.',
                    ),
                    if (_uploading) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text(
                        'Uploading to app.edge-ml.org… Keep this window open.',
                      ),
                    ],
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _uploading ? null : () => Navigator.of(context).pop(),
            child: Text(_datasetId != null ? 'Done' : 'Close'),
          ),
          if (preview != null && _datasetId == null)
            FilledButton(
              onPressed: _uploading ? null : _upload,
              child: const Text('Upload to Edge ML'),
            ),
        ],
      ),
    );
  }
}
