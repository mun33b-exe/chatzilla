import 'package:flutter_test/flutter_test.dart';
import 'package:chatzilla/data/repositories/contact_repository.dart';

void main() {
  group('Contact Repository Cache Tests', () {
    late ContactRepository contactRepository;

    setUp(() {
      contactRepository = ContactRepository();
    });

    test('should report empty cache initially', () {
      final stats = contactRepository.getCacheStats();

      expect(stats['hasContactsCache'], false);
      expect(stats['contactsCacheSize'], 0);
      expect(stats['contactsCacheAge'], isNull);
      expect(stats['hasUsersCache'], false);
      expect(stats['usersCacheSize'], 0);
      expect(stats['usersCacheAge'], isNull);
      expect(stats['cacheValidDurationSeconds'], 300); // 5 minutes
    });

    test('should clear cache properly', () {
      // Start with clear cache
      contactRepository.clearCache();

      final stats = contactRepository.getCacheStats();
      expect(stats['hasContactsCache'], false);
      expect(stats['hasUsersCache'], false);
    });

    test('should normalize phone numbers correctly', () {
      // Test the phone number normalization logic
      expect(contactRepository.normalize('+1 (555) 123-4567'), '5551234567');
      expect(contactRepository.normalize('555-123-4567'), '5551234567');
      expect(contactRepository.normalize('(555) 123-4567'), '5551234567');
      expect(contactRepository.normalize('15551234567'), '5551234567');
      expect(contactRepository.normalize('555.123.4567'), '5551234567');
      expect(contactRepository.normalize('555 123 4567'), '5551234567');

      // Test shorter numbers
      expect(contactRepository.normalize('1234567'), '1234567');
      expect(contactRepository.normalize('123456'), '123456');
    });

    test('should handle edge cases in phone normalization', () {
      expect(contactRepository.normalize(''), '');
      expect(contactRepository.normalize('abc'), '');
      expect(
        contactRepository.normalize('+1-800-FLOWERS'),
        '18003569377',
      ); // Letters should be filtered out to just digits
      expect(contactRepository.normalize('1-800-FLOWERS'), '18003569377');
    });
  });
}
