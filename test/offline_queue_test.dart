import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bigdogg_app/services/offline_queue.dart';

/// Tests for OfflineQueue.
///
/// We can't easily intercept `package:http` in unit tests without an
/// IOClient stub, so we exercise the storage contract directly:
/// `enqueue` -> `count` -> peek-via-prefs and the JSON shape we
/// persist. The drain logic that actually replays HTTP is best
/// covered by integration tests on a device, not unit tests.

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('count is zero on a fresh device', () async {
    expect(await OfflineQueue.count(), 0);
  });

  test('enqueue persists a request shape readable by drain', () async {
    await OfflineQueue.enqueue(
      method: 'POST',
      url: 'https://example.com/api/v1/expenses/',
      label: 'Kosten: lunch',
      headers: {'Authorization': 'Bearer abc', 'Content-Type': 'application/json'},
      body: {'description': 'lunch', 'amount_ex_btw': 12.5},
    );

    expect(await OfflineQueue.count(), 1);

    // Read back the underlying JSON to assert the wire shape we'll
    // replay later. Anyone refactoring the storage layer must update
    // this test in lockstep.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offline_queue_v1');
    expect(raw, isNotNull);
    final parsed = (jsonDecode(raw!) as List).cast<Map<String, dynamic>>();
    expect(parsed.length, 1);

    final item = parsed.first;
    expect(item['method'], 'POST');
    expect(item['url'], 'https://example.com/api/v1/expenses/');
    expect(item['label'], 'Kosten: lunch');
    expect(item['headers']['Authorization'], 'Bearer abc');
    expect(item['headers']['Content-Type'], 'application/json');
    // Body is JSON-encoded once; replay decodes back when needed.
    expect(item['body'], isA<String>());
    final bodyMap = jsonDecode(item['body'] as String) as Map<String, dynamic>;
    expect(bodyMap['description'], 'lunch');
    expect(bodyMap['amount_ex_btw'], 12.5);
    expect(item.containsKey('id'), true);
    expect(item.containsKey('enqueued_at'), true);
  });

  test('enqueue order is preserved (FIFO)', () async {
    await OfflineQueue.enqueue(
        method: 'POST', url: 'https://example.com/a',
        label: 'first');
    await OfflineQueue.enqueue(
        method: 'PUT', url: 'https://example.com/b',
        label: 'second');
    await OfflineQueue.enqueue(
        method: 'DELETE', url: 'https://example.com/c',
        label: 'third');

    expect(await OfflineQueue.count(), 3);

    final prefs = await SharedPreferences.getInstance();
    final parsed = (jsonDecode(prefs.getString('offline_queue_v1')!) as List)
        .cast<Map<String, dynamic>>();
    expect(parsed[0]['label'], 'first');
    expect(parsed[1]['label'], 'second');
    expect(parsed[2]['label'], 'third');
    expect(parsed[0]['method'], 'POST');
    expect(parsed[1]['method'], 'PUT');
    expect(parsed[2]['method'], 'DELETE');
  });

  test('clear wipes the queue', () async {
    await OfflineQueue.enqueue(
        method: 'POST', url: 'https://example.com/a',
        label: 'one');
    expect(await OfflineQueue.count(), 1);
    await OfflineQueue.clear();
    expect(await OfflineQueue.count(), 0);
  });

  test('null body persists as null, not the string "null"', () async {
    await OfflineQueue.enqueue(
      method: 'DELETE',
      url: 'https://example.com/api/v1/expenses/abc',
      label: 'Kosten verwijderen: abc',
      headers: {'Authorization': 'Bearer abc'},
    );
    final prefs = await SharedPreferences.getInstance();
    final parsed = (jsonDecode(prefs.getString('offline_queue_v1')!) as List)
        .cast<Map<String, dynamic>>();
    expect(parsed.first['body'], isNull);
  });

  test('postOrEnqueue persists on network failure', () async {
    // The url won't resolve in the test sandbox, so http.post throws.
    final result = await OfflineQueue.postOrEnqueue(
      url: 'http://0.0.0.0:1/api/v1/expenses/',
      headers: {'Authorization': 'Bearer abc'},
      body: {'description': 'offline lunch'},
      label: 'Kosten: offline lunch',
    );
    expect(result['success'], true);
    expect(result['offline'], true);
    expect(result['queued_label'], 'Kosten: offline lunch');
    expect(await OfflineQueue.count(), 1);
  });

  test('deleteOrEnqueue persists on network failure', () async {
    final result = await OfflineQueue.deleteOrEnqueue(
      url: 'http://0.0.0.0:1/api/v1/expenses/abc',
      headers: {'Authorization': 'Bearer abc'},
      label: 'Kosten verwijderen: abc',
    );
    expect(result['success'], true);
    expect(result['offline'], true);
    expect(await OfflineQueue.count(), 1);
  });

  test('putOrEnqueue persists on network failure', () async {
    final result = await OfflineQueue.putOrEnqueue(
      url: 'http://0.0.0.0:1/api/v1/clients/abc',
      headers: {'Authorization': 'Bearer abc'},
      body: {'contact_name': 'Acme'},
      label: 'Klant bijwerken: Acme',
    );
    expect(result['success'], true);
    expect(result['offline'], true);
    expect(await OfflineQueue.count(), 1);
  });
}
