import 'package:chatzilla/data/repositories/auth_repository.dart';
import 'package:chatzilla/data/repositories/chat_repository.dart';
import 'package:chatzilla/data/repositories/contact_repository.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:chatzilla/logic/cubit/auth/auth_cubit.dart';
import 'package:chatzilla/presentation/chat/chat_message_screen.dart';
import 'package:chatzilla/presentation/screens/auth/login_screen.dart';
import 'package:chatzilla/presentation/widgets/chat_list_tile.dart';
import 'package:chatzilla/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ContactRepository _contactRepository;
  late final ChatRepository _chatRepository;
  late final String _currentUserId;

  @override
  void initState() {
    _contactRepository = getIt<ContactRepository>();
    _chatRepository = getIt<ChatRepository>();
    _currentUserId = getIt<AuthRepository>().currentUser?.uid ?? "";

    super.initState();
  }

  
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
              fontSize: 20,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout from ChatZilla?',
            style: TextStyle(fontSize: 16),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();  
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();  

                 
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const Center(child: CircularProgressIndicator());
                  },
                );

                try {
                   
                  await getIt<AuthCubit>().signOut();

                   
                  final navigator =
                      getIt<AppRouter>().navigatorKey.currentState;
                  if (navigator != null) {
                     
                    navigator.pop();

                     
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                } catch (e) {
                   
                  final navigator =
                      getIt<AppRouter>().navigatorKey.currentState;
                  if (navigator != null) {
                    navigator.pop();  

                     
                    ScaffoldMessenger.of(navigator.context).showSnackBar(
                      SnackBar(
                        content: Text('Logout failed: ${e.toString()}'),
                        backgroundColor: Theme.of(context).primaryColor,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColorDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showContactsList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                "Contacts",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _contactRepository.getRegisteredContacts(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final contacts = snapshot.data!;
                    if (contacts.isEmpty) {
                      return const Center(child: Text("No contacts found"));
                    }
                    return ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColorDark,
                            child: Text(contact["name"][0].toUpperCase()),
                            foregroundImage: NetworkImage(
                              "https://ui-avatars.com/api/?name=${contact["name"]}&background=${Theme.of(context).primaryColorDark.value.toRadixString(16).substring(2)}&color=fff",
                            ),
                          ),
                          title: Text(contact["name"]),
                          onTap: () {
                            getIt<AppRouter>().push(
                              ChatMessageScreen(
                                receiverId: contact['id'],
                                receiverName: contact['name'],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: Text("Chats"),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        foregroundColor: Colors.white,
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          InkWell(
            onTap: _showLogoutDialog,  
            child: const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.logout, size: 30, color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _chatRepository.getChatRooms(_currentUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print(snapshot.error);
            return Center(child: Text("error:${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snapshot.data!;
          if (chats.isEmpty) {
            return const Center(child: Text("No recent chats"));
          }
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return ChatListTile(
                chat: chat,
                currentUserId: _currentUserId,
                onTap: () {
                  final otherUserId = chat.participants.firstWhere(
                    (id) => id != _currentUserId,
                  );
                  print("home screen current user id $_currentUserId");
                  final outherUserName =
                      chat.participantsName?[otherUserId] ?? "Unknown";
                  getIt<AppRouter>().push(
                    ChatMessageScreen(
                      receiverId: otherUserId,
                      receiverName: outherUserName,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showContactsList(context),
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }
}
