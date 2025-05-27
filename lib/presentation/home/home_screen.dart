import 'package:chatzilla/data/repositories/auth_repository.dart';
import 'package:chatzilla/data/repositories/chat_repository.dart';
import 'package:chatzilla/data/repositories/contact_repository.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:chatzilla/logic/cubit/auth/auth_cubit.dart';
import 'package:chatzilla/logic/cubit/auth/auth_state.dart';
import 'package:chatzilla/logic/cubit/group/groups_cubit.dart';
import 'package:chatzilla/logic/cubit/group/groups_state.dart';
import 'package:chatzilla/presentation/chat/chat_message_screen.dart';
import 'package:chatzilla/presentation/group/create_group_screen.dart';
import 'package:chatzilla/presentation/group/group_chat_screen.dart';
import 'package:chatzilla/presentation/screens/auth/login_screen.dart';
import 'package:chatzilla/presentation/widgets/chat_list_tile.dart';
import 'package:chatzilla/presentation/widgets/group_list_tile.dart';
import 'package:chatzilla/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final ContactRepository _contactRepository;
  late final ChatRepository _chatRepository;
  late final GroupsCubit _groupsCubit;
  late final String _currentUserId;
  late final TabController _tabController;
  @override
  void initState() {
    _contactRepository = getIt<ContactRepository>();
    _chatRepository = getIt<ChatRepository>();
    _groupsCubit = getIt<GroupsCubit>();
    _currentUserId = getIt<AuthRepository>().currentUser?.uid ?? "";
    _tabController = TabController(length: 2, vsync: this);

    // Add listener to update FloatingActionButton when tab changes
    _tabController.addListener(() {
      setState(() {});
    });

    // Load groups when the screen loads
    _groupsCubit.loadGroups();

    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          child: Text("ChatZilla"),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        foregroundColor: Colors.white,
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            onPressed: () {
              // Show search or other actions
            },
            icon: const Icon(Icons.search, color: Colors.white),
          ),
          // Add Group Creation Button in AppBar
          IconButton(
            onPressed: () {
              getIt<AppRouter>().push(const CreateGroupScreen());
            },
            icon: const Icon(Icons.group_add, color: Colors.white),
            tooltip: 'Create Group',
          ),
          InkWell(
            onTap: _showLogoutDialog,
            child: const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.logout, size: 30, color: Colors.white),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Chats"),
            Tab(text: "Groups"),
          ],
        ),
      ),
      drawer: _buildNavigationDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Individual Chats Tab
          _buildChatsTab(),
          // Groups Tab
          _buildGroupsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () => _showContactsList(context),
              child: const Icon(Icons.chat, color: Colors.white),
            )
          : FloatingActionButton(
              onPressed: () {
                getIt<AppRouter>().push(const CreateGroupScreen());
              },
              child: const Icon(Icons.group_add, color: Colors.white),
            ),
    );
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      child: Column(
        children: [
          // Drawer Header
          Container(
            padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColorDark,
                ],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: const Icon(
                    Icons.person,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [                      BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, authState) {
                          return Text(
                            authState.user?.email ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      const Text(
                        'ChatZilla User',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Drawer Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.group_add,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: const Text('Create Group'),
                  subtitle: const Text('Start a new group chat'),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    getIt<AppRouter>().push(const CreateGroupScreen());
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.groups,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: const Text('My Groups'),
                  subtitle: const Text('View all your groups'),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _tabController.animateTo(1); // Switch to Groups tab
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    Icons.contacts,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: const Text('Contacts'),
                  subtitle: const Text('Manage your contacts'),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _showContactsList(context);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.search,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: const Text('Search'),
                  subtitle: const Text('Find chats and groups'),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    // TODO: Implement search functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Search feature coming soon!')),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    Icons.settings,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: const Text('Settings'),
                  subtitle: const Text('App preferences'),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    // TODO: Implement settings screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings coming soon!')),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.help_outline,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: const Text('Help & Support'),
                  subtitle: const Text('Get help with ChatZilla'),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    // TODO: Implement help screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Help & Support coming soon!')),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Logout section at bottom
          Container(
            padding: const EdgeInsets.all(16),
            child: ListTile(
              leading: const Icon(
                Icons.logout,
                color: Colors.red,
              ),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _showLogoutDialog();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsTab() {
    return StreamBuilder(
      stream: _chatRepository.getChatRooms(_currentUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print(snapshot.error);
          return Center(child: Text("error:${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }        final chats = snapshot.data!;
        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  "No recent chats",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Start a conversation or create a group",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showContactsList(context),
                      icon: Icon(Icons.person_add),
                      label: Text("Start Chat"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        getIt<AppRouter>().push(const CreateGroupScreen());
                      },
                      icon: Icon(Icons.group_add),
                      label: Text("Create Group"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColorDark,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
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
    );
  }

  Widget _buildGroupsTab() {
    return BlocBuilder<GroupsCubit, GroupsState>(
      bloc: _groupsCubit,
      builder: (context, state) {
        if (state.status == GroupsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (state.status == GroupsStatus.error) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Error: ${state.error}"),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _groupsCubit.loadGroups(),
                  child: const Text("Retry"),
                ),
              ],
            ),
          );
        }
          if (state.groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.group,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  "No groups yet",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Create a group to start chatting with multiple people",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Tap the + button to create your first group",
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: state.groups.length,
          itemBuilder: (context, index) {
            final group = state.groups[index];
            return GroupListTile(
              group: group,
              currentUserId: _currentUserId,
              onTap: () {
                getIt<AppRouter>().push(
                  GroupChatScreen(
                    groupId: group.id,
                    groupName: group.name,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
