import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/study_protocol/model/study_session.dart';
import 'package:open_wearable/apps/study_protocol/model/ymca_models.dart';

void main() {
  group('StudySession heart-rate limits', () {
    test('HR_max = 220 - age', () {
      expect(const StudySession(probandId: 'p', age: 20).maxHeartRate, 200);
      expect(const StudySession(probandId: 'p', age: 40).maxHeartRate, 180);
    });

    test('HR_submax = 85% of HR_max, rounded', () {
      // 220 - 20 = 200; 0.85 * 200 = 170.
      expect(const StudySession(probandId: 'p', age: 20).submaxHeartRate, 170);
      // 220 - 33 = 187; 0.85 * 187 = 158.95 -> 159.
      expect(const StudySession(probandId: 'p', age: 33).submaxHeartRate, 159);
    });
  });

  group('ymcaInitialWattForHeartRate', () {
    test('maps heart-rate bands to the first workload', () {
      expect(ymcaInitialWattForHeartRate(70), 130);
      expect(ymcaInitialWattForHeartRate(79), 130);
      expect(ymcaInitialWattForHeartRate(80), 100);
      expect(ymcaInitialWattForHeartRate(90), 100);
      expect(ymcaInitialWattForHeartRate(91), 70);
      expect(ymcaInitialWattForHeartRate(100), 70);
      expect(ymcaInitialWattForHeartRate(101), 40);
      expect(ymcaInitialWattForHeartRate(150), 40);
    });
  });

  test('stage protocol constants', () {
    expect(ymcaMinMeasurementsPerStage, 3);
    expect(ymcaSteadyStateBpmTolerance, 5);
    expect(ymcaStageIncrementWatt, 30);
  });
}
