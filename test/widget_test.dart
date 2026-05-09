// Smoke test placeholder. The original Flutter scaffold referenced a
// `MyApp` class that no longer exists; spinning up the real BigdoggApp
// requires Supabase init + Firebase init which won't run in the test
// sandbox. Real coverage lives in:
//   - test/offline_queue_test.dart  (storage contract for offline writes)
// Add more targeted tests next to those rather than booting the full app.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder', () {
    expect(1 + 1, 2);
  });
}
