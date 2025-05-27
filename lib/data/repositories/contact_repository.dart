import 'dart:async';
import 'dart:typed_data';
import 'package:chatzilla/data/models/user_model.dart';
import 'package:chatzilla/data/services/base_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactRepository extends BaseRepository {
  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Cache for registered contacts
  List<Map<String, dynamic>>? _cachedContacts;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  // Cache for registered users lookup
  Map<String, UserModel>? _registeredUsersCache;
  DateTime? _lastUsersCacheTime;

  String normalize(String number) {
    final digits = number.replaceAll(RegExp(r'[^\d]'), '');

    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  Future<bool> requestContactsPermission() async {
    return await FlutterContacts.requestPermission();
  }

  /// Clear the cache to force refresh of contacts
  void clearCache() {
    _cachedContacts = null;
    _lastCacheTime = null;
    _registeredUsersCache = null;
    _lastUsersCacheTime = null;
  }

  /// Check if cache is still valid
  bool _isCacheValid() {
    if (_cachedContacts == null || _lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }

  /// Check if users cache is still valid
  bool _isUsersCacheValid() {
    if (_registeredUsersCache == null || _lastUsersCacheTime == null)
      return false;
    return DateTime.now().difference(_lastUsersCacheTime!) <
        _cacheValidDuration;
  }

  /// Get registered users with caching
  Future<Map<String, UserModel>> _getRegisteredUsersMap() async {
    if (_isUsersCacheValid()) {
      return _registeredUsersCache!;
    }

    try {
      final usersSnapshot = await firestore.collection('users').get();
      final registeredUsers =
          usersSnapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();

      // Create a map for O(1) lookup by normalized phone number
      _registeredUsersCache = {};
      for (final user in registeredUsers) {
        if (user.uid != currentUserId) {
          final normalizedPhone = normalize(user.phoneNumber);
          _registeredUsersCache![normalizedPhone] = user;
        }
      }

      _lastUsersCacheTime = DateTime.now();
      return _registeredUsersCache!;
    } catch (e) {
      print('Error getting registered users: $e');
      return {};
    }
  }

  /// Stream version for progressive loading
  Stream<List<Map<String, dynamic>>> getRegisteredContactsStream() async* {
    try {
      // First, yield cached results if available
      if (_isCacheValid()) {
        yield _cachedContacts!;
        return;
      }

      bool hasPermission = await requestContactsPermission();
      if (!hasPermission) {
        print('Contacts permission denied');
        yield [];
        return;
      }

      // Get registered users map first
      final registeredUsersMap = await _getRegisteredUsersMap();
      if (registeredUsersMap.isEmpty) {
        yield [];
        return;
      }

      // Get contacts without photos first for faster initial load
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      final matchedContacts = <Map<String, dynamic>>[];

      // Process contacts in batches for better performance
      const batchSize = 50;
      for (int i = 0; i < contacts.length; i += batchSize) {
        final batch = contacts.skip(i).take(batchSize);

        for (final contact in batch) {
          if (contact.phones.isNotEmpty) {
            final normalizedPhone = normalize(contact.phones.first.number);
            final registeredUser = registeredUsersMap[normalizedPhone];

            if (registeredUser != null) {
              matchedContacts.add({
                'id': registeredUser.uid,
                'name': contact.displayName,
                'phoneNumber': normalizedPhone,
              });
            }
          }
        }

        // Yield intermediate results for progressive loading
        if (matchedContacts.isNotEmpty) {
          yield List.from(matchedContacts);
        }
      }

      // Cache the final results
      _cachedContacts = matchedContacts;
      _lastCacheTime = DateTime.now();

      yield matchedContacts;
    } catch (e) {
      print('Error getting registered contacts stream: $e');
      yield [];
    }
  }

  Future<List<Map<String, dynamic>>> getRegisteredContacts() async {
    try {
      // Return cached results if valid
      if (_isCacheValid()) {
        return _cachedContacts!;
      }

      bool hasPermission = await requestContactsPermission();
      if (!hasPermission) {
        print('Contacts permission denied');
        return [];
      }

      // Get registered users map for O(1) lookup
      final registeredUsersMap = await _getRegisteredUsersMap();
      if (registeredUsersMap.isEmpty) {
        return [];
      }

      // Get contacts without photos for faster loading
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      final matchedContacts = <Map<String, dynamic>>[];

      // Process contacts with optimized lookup
      for (final contact in contacts) {
        if (contact.phones.isNotEmpty) {
          final normalizedPhone = normalize(contact.phones.first.number);
          final registeredUser = registeredUsersMap[normalizedPhone];

          if (registeredUser != null) {
            matchedContacts.add({
              'id': registeredUser.uid,
              'name': contact.displayName,
              'phoneNumber': normalizedPhone,
            });
          }
        }
      }

      // Cache the results
      _cachedContacts = matchedContacts;
      _lastCacheTime = DateTime.now();

      return matchedContacts;
    } catch (e) {
      print('Error getting registered contacts: $e');
      return [];
    }
  }

  /// Get contact photo for a specific contact (called separately to avoid loading all photos upfront)
  Future<Uint8List?> getContactPhoto(String phoneNumber) async {
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );

      final contact = contacts.firstWhere(
        (c) =>
            c.phones.isNotEmpty &&
            normalize(c.phones.first.number) == normalize(phoneNumber),
        orElse: () => Contact(),
      );

      return contact.photo;
    } catch (e) {
      print('Error getting contact photo: $e');
      return null;
    }
  }

  /// Batch method to get photos for multiple contacts
  Future<Map<String, Uint8List?>> getContactPhotos(
    List<String> phoneNumbers,
  ) async {
    final result = <String, Uint8List?>{};

    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );

      final phoneSet = phoneNumbers.map(normalize).toSet();

      for (final contact in contacts) {
        if (contact.phones.isNotEmpty) {
          final normalizedPhone = normalize(contact.phones.first.number);
          if (phoneSet.contains(normalizedPhone)) {
            result[normalizedPhone] = contact.photo;
          }
        }
      }
    } catch (e) {
      print('Error getting contact photos: $e');
    }

    return result;
  }

  /// Get cache statistics for monitoring performance
  Map<String, dynamic> getCacheStats() {
    return {
      'hasContactsCache': _cachedContacts != null,
      'contactsCacheSize': _cachedContacts?.length ?? 0,
      'contactsCacheAge':
          _lastCacheTime != null
              ? DateTime.now().difference(_lastCacheTime!).inSeconds
              : null,
      'hasUsersCache': _registeredUsersCache != null,
      'usersCacheSize': _registeredUsersCache?.length ?? 0,
      'usersCacheAge':
          _lastUsersCacheTime != null
              ? DateTime.now().difference(_lastUsersCacheTime!).inSeconds
              : null,
      'cacheValidDurationSeconds': _cacheValidDuration.inSeconds,
    };
  }

  /// Preload contacts in background for better UX
  Future<void> preloadContacts() async {
    // This runs in background and populates the cache
    // so subsequent calls are faster
    try {
      await getRegisteredContacts();
      print('Contacts preloaded successfully');
    } catch (e) {
      print('Failed to preload contacts: $e');
    }
  }
}
