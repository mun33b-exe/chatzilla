import 'package:flutter_test/flutter_test.dart';
import 'package:chatzilla/data/repositories/contact_repository.dart';
import 'package:chatzilla/data/services/service_locator.dart';

void main() {
  group('Contact Performance Tests', () {
    late ContactRepository contactRepository;

    setUpAll(() async {
      // Initialize service locator for testing
      await setupServiceLocator();
      contactRepository = getIt<ContactRepository>();
    });

    test('should cache contacts to improve subsequent calls', () async {
      // Clear any existing cache
      contactRepository.clearCache();

      // First call - should be slower as it hits the database
      final stopwatch1 = Stopwatch()..start();
      final contacts1 = await contactRepository.getRegisteredContacts();
      stopwatch1.stop();
      final firstCallTime = stopwatch1.elapsedMilliseconds;

      // Second call - should be faster due to caching
      final stopwatch2 = Stopwatch()..start();
      final contacts2 = await contactRepository.getRegisteredContacts();
      stopwatch2.stop();
      final secondCallTime = stopwatch2.elapsedMilliseconds;

      // Verify that results are the same
      expect(contacts1.length, equals(contacts2.length));

      // Second call should be significantly faster (at least 50% faster)
      expect(secondCallTime, lessThan(firstCallTime * 0.5));

      print('First call took: ${firstCallTime}ms');
      print('Second call (cached) took: ${secondCallTime}ms');
      print(
        'Performance improvement: ${((firstCallTime - secondCallTime) / firstCallTime * 100).toStringAsFixed(1)}%',
      );
    });

    test('should clear cache when requested', () async {
      // Load contacts to populate cache
      await contactRepository.getRegisteredContacts();

      // Clear cache
      contactRepository.clearCache();

      // Next call should be slower again (hitting database)
      final stopwatch = Stopwatch()..start();
      await contactRepository.getRegisteredContacts();
      stopwatch.stop();

      // This is mainly to verify the cache was actually cleared
      // and we're hitting the database again
      expect(stopwatch.elapsedMilliseconds, greaterThan(10));
      print('Call after cache clear took: ${stopwatch.elapsedMilliseconds}ms');
    });

    test('should provide streaming contact results', () async {
      contactRepository.clearCache();

      final List<List<Map<String, dynamic>>> streamResults = [];

      await for (final contacts
          in contactRepository.getRegisteredContactsStream()) {
        streamResults.add(contacts);
        // Break after first few emissions to avoid infinite stream
        if (streamResults.length >= 3) break;
      }

      // Should have received at least one result
      expect(streamResults.isNotEmpty, true);

      // If we have multiple results, later ones should have same or more contacts
      // (due to progressive loading)
      if (streamResults.length > 1) {
        for (int i = 1; i < streamResults.length; i++) {
          expect(
            streamResults[i].length,
            greaterThanOrEqualTo(streamResults[i - 1].length),
          );
        }
      }

      print('Stream provided ${streamResults.length} updates');
      if (streamResults.isNotEmpty) {
        print('Final result had ${streamResults.last.length} contacts');
      }
    });

    test(
      'should handle photo requests separately for better performance',
      () async {
        // Get contacts first (without photos for speed)
        final contacts = await contactRepository.getRegisteredContacts();

        if (contacts.isNotEmpty) {
          final phoneNumber = contacts.first['phoneNumber'];

          // Test individual photo retrieval
          final stopwatch = Stopwatch()..start();
          final photo = await contactRepository.getContactPhoto(phoneNumber);
          stopwatch.stop();

          print('Photo retrieval took: ${stopwatch.elapsedMilliseconds}ms');
          print('Photo ${photo != null ? 'found' : 'not found'} for contact');

          // Should complete reasonably quickly
          expect(
            stopwatch.elapsedMilliseconds,
            lessThan(5000),
          ); // 5 seconds max
        }
      },
    );
  });
}
