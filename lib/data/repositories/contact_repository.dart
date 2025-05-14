import 'package:chatzilla/data/models/user_model.dart';
import 'package:chatzilla/data/services/base_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactRepository extends BaseRepository {
  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<bool> requestContactsPermission() async {
    return await FlutterContacts.requestPermission();
  }

  Future<List<Map<String, dynamic>>> getRegisteredContacts() async {
    try {
      bool hasPermission = await requestContactsPermission();
      if (!hasPermission) {
        print('Contacts permission denied');
        return [];
      }

      // Get device contacts with phone numbers
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );

      // Extract phone numbers and normalize them
      final phoneNumbers = contacts
          .where((contact) => contact.phones.isNotEmpty)
          .map((contact) => {
                'name': contact.displayName,
                'phoneNumber': contact.phones.first.number
                    .replaceAll(RegExp(r'[^\d+]'), ''),
                'photo': contact.photo, // Store contact photo if available
              })
          .toList();

      // Get all users from Firestore
      final usersSnapshot = await firestore.collection('users').get();

      final registeredUsers = usersSnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Match contacts with registered users
      final matchedContacts = phoneNumbers.where((contact) {
        String phoneNumber =
            contact["phoneNumber"].toString(); // Ensure it's a String

        // Remove +91 if present
        if (phoneNumber.startsWith("+91")) {
          phoneNumber = phoneNumber.substring(3);
        }

        return registeredUsers.any((user) =>
            user.phoneNumber == phoneNumber && user.uid != currentUserId);
      }).map((contact) {
        String phoneNumber =
            contact["phoneNumber"].toString(); // Ensure it's a String

        if (phoneNumber.startsWith("+91")) {
          phoneNumber = phoneNumber.substring(3);
        }

        final registeredUser = registeredUsers
            .firstWhere((user) => user.phoneNumber == phoneNumber);

        return {
          'id': registeredUser.uid,
          'name': contact['name'],
          'phoneNumber': contact['phoneNumber'],
        };
      }).toList();

      return matchedContacts;
    } catch (e) {
      print('Error getting registered contacts: $e');
      return [];
    }
  }
}