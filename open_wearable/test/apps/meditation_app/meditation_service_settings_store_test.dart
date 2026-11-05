import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/meditation_app/model/meditation_session_generator.dart';
import 'package:open_wearable/apps/meditation_app/model/meditation_service_settings_store.dart';
import 'package:open_wearable/apps/meditation_app/model/meditation_user_settings_store.dart';
import 'package:open_wearable/apps/meditation_app/model/service_connection_manager.dart';
import 'package:open_wearable/apps/meditation_app/model/tts_service.dart';
import 'package:open_wearable/apps/meditation_app/model/user_account.dart';
import 'package:open_wearable/apps/meditation_app/views/pages/api_keys_page.dart';
import 'package:open_wearable/apps/meditation_app/views/pages/privacy_data_page.dart';
import 'package:open_wearable/apps/meditation_app/widgets/custom_dropdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('meditation service settings persistence', () {
    test('leaves preconfigured account values alone before the first save',
        () async {
      final secrets = _MemorySecretStorage()..values['unrelated'] = 'not-used';
      final store = MeditationServiceSettingsStore(secretStorage: secrets);
      final account = UserAccount(
        deepseekApiKey: 'preconfigured-deepseek',
        elevenLabsApiKey: 'preconfigured-elevenlabs',
        ttsProvider: TtsProviderOption.elevenLabs,
      )
        ..hasValidDeepseekKey = true
        ..hasValidElevenLabsKey = true;

      expect(await store.loadInto(account), isFalse);
      expect(account.deepseekApiKey, 'preconfigured-deepseek');
      expect(account.elevenLabsApiKey, 'preconfigured-elevenlabs');
      expect(account.ttsProvider, TtsProviderOption.elevenLabs);
      expect(account.hasValidDeepseekKey, isTrue);
      expect(account.hasValidElevenLabsKey, isTrue);
    });

    test('restores provider, voice settings, credentials and validity',
        () async {
      final secrets = _MemorySecretStorage();
      final store = MeditationServiceSettingsStore(secretStorage: secrets);
      final saved = UserAccount(
        voiceGender: Gender.male,
        deepseekApiKey: 'saved-deepseek',
        elevenLabsApiKey: 'saved-elevenlabs',
        ttsProvider: TtsProviderOption.tencent,
        tencentSecretId: 'saved-tencent-id',
        tencentSecretKey: 'saved-tencent-key',
        tencentTtsRegion: TencentTtsRegion.chinaGuangzhou,
      )
        ..elevenLabsVoiceId = 'saved-voice-id'
        ..hasValidDeepseekKey = true
        ..hasValidElevenLabsKey = true
        ..hasValidTencentKey = true;

      await store.save(saved);

      final restored = UserAccount();
      expect(await store.loadInto(restored), isTrue);

      expect(restored.deepseekApiKey, 'saved-deepseek');
      expect(restored.elevenLabsApiKey, 'saved-elevenlabs');
      expect(restored.ttsProvider, TtsProviderOption.tencent);
      expect(restored.voiceGender, Gender.male);
      expect(restored.elevenLabsVoiceId, 'saved-voice-id');
      expect(restored.tencentSecretId, 'saved-tencent-id');
      expect(restored.tencentSecretKey, 'saved-tencent-key');
      expect(
        restored.tencentTtsRegion,
        TencentTtsRegion.chinaGuangzhou,
      );
      expect(restored.hasValidDeepseekKey, isTrue);
      expect(restored.hasValidElevenLabsKey, isTrue);
      expect(restored.hasValidTencentKey, isTrue);

      final preferences = await SharedPreferences.getInstance();
      final ordinaryValues = preferences
          .getKeys()
          .map(preferences.get)
          .whereType<String>()
          .toList();
      expect(ordinaryValues, isNot(contains('saved-deepseek')));
      expect(ordinaryValues, isNot(contains('saved-elevenlabs')));
      expect(ordinaryValues, isNot(contains('saved-tencent-key')));
      expect(secrets.values.values, contains('saved-deepseek'));
      expect(secrets.values.values, contains('saved-tencent-key'));
    });

    test('an intentionally cleared key does not restore an earlier default',
        () async {
      final secrets = _MemorySecretStorage();
      final store = MeditationServiceSettingsStore(secretStorage: secrets);
      final account = UserAccount(
        deepseekApiKey: 'first-key',
        elevenLabsApiKey: 'first-voice-key',
      )
        ..hasValidDeepseekKey = true
        ..hasValidElevenLabsKey = true;
      await store.save(account);

      account.deepseekApiKey = '';
      account.elevenLabsApiKey = null;
      account.hasValidDeepseekKey = false;
      account.hasValidElevenLabsKey = false;
      await store.save(account);

      final restored = UserAccount(
        deepseekApiKey: 'earlier-deepseek',
        elevenLabsApiKey: 'earlier-elevenlabs',
      );
      expect(await store.loadInto(restored), isTrue);
      expect(restored.deepseekApiKey, isNull);
      expect(restored.elevenLabsApiKey, isNull);
      expect(restored.hasValidDeepseekKey, isFalse);
      expect(restored.hasValidElevenLabsKey, isFalse);
    });

    test('restored verified services start with an OK status', () {
      final account = UserAccount(
        cloudProcessingConsent: true,
        deepseekApiKey: 'deepseek',
        elevenLabsApiKey: 'elevenlabs',
        tencentSecretId: 'tencent-id',
        tencentSecretKey: 'tencent-key',
      )
        ..hasValidDeepseekKey = true
        ..hasValidElevenLabsKey = true
        ..hasValidTencentKey = true;
      final managers = <ConnectionManager>[
        DeepseekManager(userAccount: account),
        ElevenLabsManager(userAccount: account),
        TencentTtsManager(userAccount: account),
      ];

      for (final manager in managers) {
        expect(manager.status, ConnectionStatus.ok);
        manager.dispose();
      }
    });

    test('clear removes secrets and prevents earlier-default fallback',
        () async {
      final secrets = _MemorySecretStorage();
      final store = MeditationServiceSettingsStore(secretStorage: secrets);
      final account = UserAccount(
        voiceGender: Gender.female,
        deepseekApiKey: 'saved-deepseek',
        elevenLabsApiKey: 'saved-elevenlabs',
        tencentSecretId: 'saved-id',
        tencentSecretKey: 'saved-key',
      )
        ..hasValidDeepseekKey = true
        ..hasValidElevenLabsKey = true
        ..hasValidTencentKey = true;
      await store.save(account);

      await store.clear(account);

      expect(secrets.values, isEmpty);
      expect(account.deepseekApiKey, isNull);
      expect(account.elevenLabsApiKey, isNull);
      expect(account.tencentSecretId, isNull);
      expect(account.tencentSecretKey, isNull);
      expect(account.voiceGender, isNull);

      final restored = UserAccount(
        deepseekApiKey: 'earlier-deepseek',
        elevenLabsApiKey: 'earlier-elevenlabs',
      );
      expect(await store.loadInto(restored), isTrue);
      expect(restored.deepseekApiKey, isNull);
      expect(restored.elevenLabsApiKey, isNull);
    });

    testWidgets('changing the provider on the page requests a save',
        (tester) async {
      final account = UserAccount();
      final store = _RecordingSettingsStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiKeysPage(
              userAccount: account,
              settingsStore: store,
            ),
          ),
        ),
      );

      tester
          .widget<TtsProviderDropdown>(find.byType(TtsProviderDropdown))
          .onSelected(TtsProviderOption.tencent);
      await tester.pump();

      expect(account.ttsProvider, TtsProviderOption.tencent);
      expect(store.savedProvider, TtsProviderOption.tencent);
    });
  });

  group('meditation profile and privacy persistence', () {
    test('fresh account has no invented user profile', () {
      final account = UserAccount();

      expect(account.firstName, isNull);
      expect(account.age, isNull);
      expect(account.gender, isNull);
      expect(account.fitnessLevel, isNull);
      expect(account.demographicBaseline, isNull);
      expect(account.cloudProcessingConsent, isNull);
    });

    test('round-trips profile, meditation preferences, and privacy choice',
        () async {
      final store = MeditationUserSettingsStore();
      final source = UserAccount(
        firstName: 'Avery',
        age: 42,
        gender: Gender.nonBinary,
        fitnessLevel: FitnessLevel.active,
        speakingSpeed: SpeakingSpeed.medium,
        meditationType: MeditationType.bodyScan,
        meditationEnvironment: MeditationEnvironment.forest,
        additionalPreferences: 'Use gentle transitions',
        stressThreshold: 0.15,
        cloudProcessingConsent: true,
      );

      await store.save(source);
      final restored = UserAccount();
      expect(await store.loadInto(restored), isTrue);

      expect(restored.firstName, 'Avery');
      expect(restored.age, 42);
      expect(restored.gender, Gender.nonBinary);
      expect(restored.fitnessLevel, FitnessLevel.active);
      expect(restored.speakingSpeed, SpeakingSpeed.medium);
      expect(restored.meditationType, MeditationType.bodyScan);
      expect(restored.meditationEnvironment, MeditationEnvironment.forest);
      expect(restored.additionalPreferences, 'Use gentle transitions');
      expect(restored.stressThreshold, 0.15);
      expect(restored.cloudProcessingConsent, isTrue);
    });

    test('clear removes persisted user settings and resets account fields',
        () async {
      final store = MeditationUserSettingsStore();
      final account = UserAccount(
        firstName: 'Avery',
        age: 42,
        gender: Gender.female,
        fitnessLevel: FitnessLevel.moderate,
        voiceGender: Gender.female,
        meditationType: MeditationType.mindfulness,
        cloudProcessingConsent: false,
        baselineHeartRate: 70,
        baselineRMSSD: 35,
      );
      await store.save(account);

      await store.clear();
      MeditationUserSettingsStore.clearAccount(account);

      final restored = UserAccount();
      expect(await store.loadInto(restored), isFalse);
      expect(account.firstName, isNull);
      expect(account.voiceGender, isNull);
      expect(account.baselineHeartRate, isNull);
      expect(account.cloudProcessingConsent, isNull);
    });

    test('unspecified gender does not activate a demographic baseline', () {
      final account = UserAccount(
        age: 30,
        gender: Gender.unspecified,
        fitnessLevel: FitnessLevel.moderate,
      );

      expect(account.demographicBaseline, isNull);
    });

    test('local-only choice blocks generation, cloud TTS, and checks',
        () async {
      final account = UserAccount(
        cloudProcessingConsent: false,
        deepseekApiKey: 'deepseek-key',
        elevenLabsApiKey: 'eleven-key',
        tencentSecretId: 'secret-id',
        tencentSecretKey: 'secret-key',
      )
        ..hasValidDeepseekKey = true
        ..hasValidElevenLabsKey = true
        ..hasValidTencentKey = true;

      final script = createMeditationScript(account: account, maxSegments: 1);
      expect(script, isA<StaticMeditationScript>());
      script.dispose();
      expect(ElevenLabsTtsProvider(account).isAvailable, isFalse);
      expect(TencentTtsProvider(account).isAvailable, isFalse);

      final manager = DeepseekManager(userAccount: account);
      addTearDown(manager.dispose);
      await manager.checkConnection();
      expect(manager.status, ConnectionStatus.error);
      expect(manager.lastError, contains('Privacy & Data'));
      // Refusing cloud processing must not invalidate a previously verified
      // key.
      expect(account.hasValidDeepseekKey, isTrue);
    });

    test('explicit consent enables configured cloud routes', () {
      final account = UserAccount(
        cloudProcessingConsent: true,
        deepseekApiKey: 'deepseek-key',
        elevenLabsApiKey: 'eleven-key',
      )
        ..hasValidDeepseekKey = true
        ..hasValidElevenLabsKey = true;

      final script = createMeditationScript(account: account, maxSegments: 1);
      expect(script, isA<AdaptiveMeditationScript>());
      script.dispose();
      expect(ElevenLabsTtsProvider(account).isAvailable, isTrue);
    });

    testWidgets('first-use privacy page records a local-only choice',
        (tester) async {
      final account = UserAccount();
      bool? savedChoice;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivacyDataPage(
              userAccount: account,
              requireChoice: true,
              onCloudChoice: (enabled) async {
                account.cloudProcessingConsent = enabled;
                savedChoice = enabled;
              },
              onDeleteAll: () async {},
            ),
          ),
        ),
      );

      final localOnlyButton = find.text('Use local only');
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(localOnlyButton);
      await tester.pump();

      expect(savedChoice, isFalse);
      expect(account.cloudProcessingConsent, isFalse);
    });
  });
}

class _MemorySecretStorage implements MeditationSecretStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _RecordingSettingsStore extends MeditationServiceSettingsStore {
  TtsProviderOption? savedProvider;

  _RecordingSettingsStore() : super(secretStorage: _MemorySecretStorage());

  @override
  Future<void> save(UserAccount account) async {
    savedProvider = account.ttsProvider;
  }
}
