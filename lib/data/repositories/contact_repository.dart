import 'package:chatzilla/data/models/user_model.dart';
import 'package:chatzilla/data/services/base_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactRepository extends BaseRepository {
  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  String normalize(String number) {
    final digits = number.replaceAll(RegExp(r'[^\d]'), '');
      
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

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

        
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );

        
      final phoneNumbers =
          contacts
              .where((contact) => contact.phones.isNotEmpty)
              .map(
                (contact) => {
                  'name': contact.displayName,
                  'phoneNumber': normalize(contact.phones.first.number),
                  'photo': contact.photo,   
                },
              )
              .toList();

        
      final usersSnapshot = await firestore.collection('users').get();

      final registeredUsers =
          usersSnapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();

        
      final matchedContacts =
          phoneNumbers
              .where((contact) {
                String phoneNumber = contact["phoneNumber"].toString();

                return registeredUsers.any(
                  (user) =>
                      normalize(user.phoneNumber) == phoneNumber &&
                      user.uid != currentUserId,
                );
              })
              .map((contact) {
                String phoneNumber = contact["phoneNumber"].toString();

                final registeredUser = registeredUsers.firstWhere(
                  (user) => normalize(user.phoneNumber) == phoneNumber,
                );

                return {
                  'id': registeredUser.uid,
                  'name': contact['name'],
                  'phoneNumber': contact['phoneNumber'],
                };
              })
              .toList();

      return matchedContacts;
    } catch (e) {
      print('Error getting registered contacts: $e');
      return [];
    }
  }
}
