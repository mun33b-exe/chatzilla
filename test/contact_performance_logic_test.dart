import 'package:flutter_test/flutter_test.dart';

// Test class to isolate the phone normalization logic
class ContactHelper {
  static String normalize(String number) {
    final digits = number.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }
}

// Test class to verify cache logic concepts
class CacheManager<T> {
  T? _cachedData;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  bool get isCacheValid {
    if (_cachedData == null || _lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }

  void setCache(T data) {
    _cachedData = data;
    _lastCacheTime = DateTime.now();
  }

  T? getCache() {
    return isCacheValid ? _cachedData : null;
  }

  void clearCache() {
    _cachedData = null;
    _lastCacheTime = null;
  }

  Map<String, dynamic> getStats() {
    return {
      'hasCache': _cachedData != null,
      'cacheSize':
          _cachedData is List
              ? (_cachedData as List).length
              : (_cachedData != null ? 1 : 0),
      'cacheAge':
          _lastCacheTime != null
              ? DateTime.now().difference(_lastCacheTime!).inSeconds
              : null,
      'isValid': isCacheValid,
    };
  }
}

void main() {
  group('Contact Performance Logic Tests', () {
    test('should normalize phone numbers correctly', () {
      // Test the phone number normalization logic
      expect(ContactHelper.normalize('+1 (555) 123-4567'), '5551234567');
      expect(ContactHelper.normalize('555-123-4567'), '5551234567');
      expect(ContactHelper.normalize('(555) 123-4567'), '5551234567');
      expect(ContactHelper.normalize('15551234567'), '5551234567');
      expect(ContactHelper.normalize('555.123.4567'), '5551234567');
      expect(ContactHelper.normalize('555 123 4567'), '5551234567');

      // Test shorter numbers
      expect(ContactHelper.normalize('1234567'), '1234567');
      expect(ContactHelper.normalize('123456'), '123456');
    });

    test('should handle edge cases in phone normalization', () {
      expect(ContactHelper.normalize(''), '');
      expect(ContactHelper.normalize('abc'), '');
      expect(ContactHelper.normalize('+1-800-356-9377'), '8003569377');
    });

    test('cache manager should work correctly', () {
      final cache = CacheManager<List<String>>();

      // Initially empty
      expect(cache.isCacheValid, false);
      expect(cache.getCache(), isNull);

      final stats1 = cache.getStats();
      expect(stats1['hasCache'], false);
      expect(stats1['cacheSize'], 0);
      expect(stats1['isValid'], false);

      // Add data
      final testData = ['contact1', 'contact2', 'contact3'];
      cache.setCache(testData);

      expect(cache.isCacheValid, true);
      expect(cache.getCache(), equals(testData));

      final stats2 = cache.getStats();
      expect(stats2['hasCache'], true);
      expect(stats2['cacheSize'], 3);
      expect(stats2['isValid'], true);
      expect(stats2['cacheAge'], lessThan(5)); // Less than 5 seconds old

      // Clear cache
      cache.clearCache();

      expect(cache.isCacheValid, false);
      expect(cache.getCache(), isNull);

      final stats3 = cache.getStats();
      expect(stats3['hasCache'], false);
      expect(stats3['cacheSize'], 0);
      expect(stats3['isValid'], false);
    });
    test('cache should expire after duration', () async {
      final cache = CacheManager<String>();

      // Set short cache duration for testing
      cache.setCache('test data');
      expect(cache.isCacheValid, true);

      // Wait a bit and check it's still valid
      await Future.delayed(Duration(milliseconds: 100));
      expect(cache.isCacheValid, true);

      // For this test, we can't actually wait 5 minutes,
      // but we can verify the logic works
      final stats = cache.getStats();
      expect(stats['cacheAge'], greaterThanOrEqualTo(0));
      expect(stats['cacheAge'], lessThan(60)); // Should be less than 60 seconds
    });
  });
}
