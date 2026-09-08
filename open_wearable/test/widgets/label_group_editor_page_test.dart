import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/models/labels/label.dart';
import 'package:open_wearable/models/labels/label_group.dart';
import 'package:open_wearable/models/labels/label_group_manager.dart';
import 'package:open_wearable/models/labels/label_group_storage.dart';
import 'package:open_wearable/view_models/label_provider.dart';
import 'package:open_wearable/view_models/label_group_provider.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/labels/active_label_bar.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/labels/label_group_selector.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/labels/label_group_dropdown.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/labels/label_group_editor_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('autosaves label group name edits without save controls',
      (tester) async {
    final initialGroup = LabelGroup(
      name: 'Activities',
      labels: [
        Label(name: 'Walking', color: Colors.green),
      ],
    );
    final provider = _providerWithStorage([initialGroup]);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      _TestApp(
        provider: provider,
        child: LabelGroupEditorPage(initialGroup: initialGroup),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Save'), findsNothing);
    expect(find.text('Save label group'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Movement');
    await tester.pumpAndSettle();

    expect(
      provider.labelGroups.map((group) => group.name),
      <String>['Movement'],
    );
    expect(provider.labelGroups.single.labels.single.name, 'Walking');
  });

  testWidgets('shows a contrast checkmark on the selected color',
      (tester) async {
    final initialGroup = LabelGroup(
      name: 'Contrast',
      labels: [
        Label(name: 'Dark label', color: Colors.black),
      ],
    );
    final provider = _providerWithStorage([initialGroup]);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      _TestApp(
        provider: provider,
        child: LabelGroupEditorPage(initialGroup: initialGroup),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    final selectedCheck = tester.widget<Icon>(
      find.byIcon(Icons.check_rounded),
    );
    expect(selectedCheck.color, Colors.white);
  });

  testWidgets('prevents reusing a label color within the same label group',
      (tester) async {
    final initialGroup = LabelGroup(
      name: 'Activities',
      labels: [
        Label(name: 'Walking', color: Colors.green),
      ],
    );
    final provider = _providerWithStorage([initialGroup]);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      _TestApp(
        provider: provider,
        child: LabelGroupEditorPage(initialGroup: initialGroup),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();

    final greenSwatch = find.byKey(
      ValueKey('label-color-${Colors.green.toARGB32()}'),
    );
    expect(greenSwatch, findsOneWidget);
    expect(find.byIcon(Icons.block_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Running');
    await tester.tap(greenSwatch);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    final labelColors = provider.labelGroups.single.labels
        .map((label) => label.color.toARGB32())
        .toList();
    expect(labelColors, hasLength(2));
    expect(labelColors.first, Colors.green.toARGB32());
    expect(labelColors.last, isNot(Colors.green.toARGB32()));
  });

  testWidgets('uses natural label group selector wording', (tester) async {
    final provider = _providerWithStorage();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      _TestApp(
        provider: provider,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: LabelGroupSelector(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Create label group'), findsNothing);
    expect(find.byTooltip('Manage label groups'), findsOneWidget);
    expect(
      find.text('Pick a label group to add labels while recording.'),
      findsOneWidget,
    );
    expect(find.textContaining('in-recording'), findsNothing);
  });

  testWidgets('disables label dialog save until a label name is entered',
      (tester) async {
    final provider = _providerWithStorage();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      _TestApp(
        provider: provider,
        child: const LabelGroupEditorPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();

    var saveButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Save'),
    );
    expect(saveButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'Walking');
    await tester.pumpAndSettle();

    saveButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Save'),
    );
    expect(saveButton.onPressed, isNotNull);
  });

  testWidgets(
      'create checkmark confirms a valid group and switches to edit mode',
      (tester) async {
    final provider = _providerWithStorage();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      _TestApp(
        provider: provider,
        child: const LabelGroupEditorPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create label group'), findsOneWidget);
    var saveAction = _createPageSaveAction(tester);
    expect(saveAction.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Activities');
    await tester.pumpAndSettle();

    saveAction = _createPageSaveAction(tester);
    expect(saveAction.onPressed, isNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Walking');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(provider.labelGroups.single.name, 'Activities');
    expect(provider.labelGroups.single.labels.single.name, 'Walking');
    saveAction = _createPageSaveAction(tester);
    expect(saveAction.onPressed, isNotNull);

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Edit label group'), findsOneWidget);
    expect(find.byTooltip('Save'), findsNothing);
    expect(provider.labelGroups.single.name, 'Activities');
  });

  testWidgets('removes an autosaved create draft when it becomes invalid',
      (tester) async {
    final provider = _providerWithStorage();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      _TestApp(
        provider: provider,
        child: const LabelGroupEditorPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Activities');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Walking');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(provider.labelGroups, hasLength(1));

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(provider.labelGroups, isEmpty);
    expect(find.text('Create label group'), findsOneWidget);
    final saveAction = _createPageSaveAction(tester);
    expect(saveAction.onPressed, isNull);
  });

  testWidgets('warns before leaving a new named label group with no labels',
      (tester) async {
    final provider = _providerWithStorage();
    addTearDown(provider.dispose);

    await tester.pumpWidget(_EditorRouteApp(provider: provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Empty Set');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Leave without labels?'), findsOneWidget);
    expect(provider.labelGroups, isEmpty);

    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(find.text('Open editor'), findsOneWidget);
    expect(provider.labelGroups, isEmpty);
  });

  testWidgets('warns before leaving labels without a label group name',
      (tester) async {
    final provider = _providerWithStorage();
    addTearDown(provider.dispose);

    await tester.pumpWidget(_EditorRouteApp(provider: provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Walking');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Leave without group name?'), findsOneWidget);
    expect(
      find.text(
        'This label group cannot be saved because no group name was given. Leave anyway?',
      ),
      findsOneWidget,
    );
    expect(provider.labelGroups, isEmpty);

    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(find.text('Open editor'), findsOneWidget);
    expect(provider.labelGroups, isEmpty);
  });

  testWidgets('dropdown shows selected label group without floating label text',
      (tester) async {
    final initialGroup = LabelGroup(
      name: 'Activities',
      labels: [
        Label(name: 'Walking', color: Colors.green),
      ],
    );
    final provider = _providerWithStorage([initialGroup]);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      _TestApp(
        provider: provider,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: LabelGroupDropdown(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Labels'), findsOneWidget);
    expect(find.text('None'), findsNothing);

    provider.selectLabelGroup(initialGroup);
    await tester.pumpAndSettle();

    expect(find.text('Activities'), findsOneWidget);
    expect(find.text('Label group'), findsNothing);
  });

  testWidgets('label chips keep their size when selected', (tester) async {
    final labelGroup = LabelGroup(
      name: 'Activities',
      labels: [
        Label(name: 'Walking', color: Colors.green),
        Label(name: 'Running', color: Colors.red),
      ],
    );
    final labelProvider = LabelProvider(labelGroup);
    addTearDown(labelProvider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<LabelProvider>.value(
        value: labelProvider,
        child: MaterialApp(
          home: Scaffold(
            body: ActiveLabelBar(
              labelGroup: labelGroup,
              selectionEnabled: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final walkingChip = find.ancestor(
      of: find.text('Walking'),
      matching: find.byType(AnimatedContainer),
    );
    final sizeBefore = tester.getSize(walkingChip);

    await tester.tap(find.text('Walking'));
    await tester.pumpAndSettle();

    final sizeAfter = tester.getSize(walkingChip);
    expect(sizeAfter, sizeBefore);
  });

  testWidgets('recording label bar can clear the current segment label',
      (tester) async {
    final labelGroup = LabelGroup(
      name: 'Activities',
      labels: [
        Label(name: 'Walking', color: Colors.green),
        Label(name: 'Running', color: Colors.red),
      ],
    );
    final labelProvider = LabelProvider(labelGroup);
    addTearDown(labelProvider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<LabelProvider>.value(
        value: labelProvider,
        child: MaterialApp(
          home: Scaffold(
            body: ActiveLabelBar(
              labelGroup: labelGroup,
              selectionEnabled: true,
              showNoLabelOption: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Label'), findsOneWidget);
    expect(labelProvider.activeLabel, isNull);

    await tester.tap(find.text('Walking'));
    await tester.pumpAndSettle();
    expect(labelProvider.activeLabel, labelGroup.labels.first);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);

    await tester.tap(find.text('No Label'));
    await tester.pumpAndSettle();
    expect(labelProvider.activeLabel, isNull);
  });

  testWidgets('confirms before deleting a label from a label group',
      (tester) async {
    final initialGroup = LabelGroup(
      name: 'Activities',
      labels: [
        Label(name: 'Walking', color: Colors.green),
        Label(name: 'Running', color: Colors.red),
      ],
    );
    final provider = _providerWithStorage([initialGroup]);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      _TestApp(
        provider: provider,
        child: LabelGroupEditorPage(initialGroup: initialGroup),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();

    expect(find.text('Delete label?'), findsOneWidget);
    expect(
      find.text('Delete "Walking" from this label group?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(provider.labelGroups.single.labels.map((label) => label.name), [
      'Walking',
      'Running',
    ]);

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(provider.labelGroups.single.labels.map((label) => label.name), [
      'Running',
    ]);
  });
}

IconButton _createPageSaveAction(WidgetTester tester) {
  final finder = find.ancestor(
    of: find.byIcon(Icons.check),
    matching: find.byType(IconButton),
  );
  return tester.widget<IconButton>(finder);
}

LabelGroupProvider _providerWithStorage([List<LabelGroup>? groups]) {
  return LabelGroupProvider(
    manager: LabelGroupManager(
      storage: _MemoryLabelGroupStorage(groups ?? const []),
    ),
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.provider,
    required this.child,
  });

  final LabelGroupProvider provider;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LabelGroupProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }
}

class _EditorRouteApp extends StatelessWidget {
  const _EditorRouteApp({required this.provider});

  final LabelGroupProvider provider;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LabelGroupProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LabelGroupEditorPage(),
                    ),
                  );
                },
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoryLabelGroupStorage implements LabelGroupStorage {
  _MemoryLabelGroupStorage(List<LabelGroup> initialGroups)
      : _groups = List<LabelGroup>.of(initialGroups);

  List<LabelGroup> _groups;

  @override
  Future<List<LabelGroup>> loadLabelGroups() async {
    return List<LabelGroup>.of(_groups);
  }

  @override
  Future<void> saveLabelGroups(List<LabelGroup> groups) async {
    _groups = List<LabelGroup>.of(groups);
  }
}
