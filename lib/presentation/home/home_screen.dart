import 'package:chatzilla/data/repositories/auth_repository.dart';
import 'package:chatzilla/data/repositories/chat_repository.dart';
import 'package:chatzilla/data/repositories/contact_repository.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:chatzilla/logic/cubit/auth/auth_cubit.dart';
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

  // Search functionality
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

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

    // Add search listener
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // Load groups when the screen loads
    _groupsCubit.loadGroups();

    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _navigateToCreateGroup() {
    try {
      getIt<AppRouter>().push(const CreateGroupScreen());
    } catch (e) {
      // Fallback to direct Navigator if AppRouter fails
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
      );
    }
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
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Individual Chats Tab
          _buildChatsTab(),
          // Groups Tab
          _buildGroupsTab(),
        ],
      ),
      floatingActionButton:
          _tabController.index == 0
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

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
    _searchFocusNode.requestFocus();
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title:
          _isSearching
              ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search chats and groups...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                autofocus: true,
              )
              : const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Text(
                  "Chatzilla",
                  style: TextStyle(
                    fontFamily: 'Billabong',
                    fontSize: 40,
                    letterSpacing: 3.0,
                  ),
                ),
              ),
      titleTextStyle: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      foregroundColor: Colors.white,
      backgroundColor: Theme.of(context).primaryColor,
      leading:
          _isSearching
              ? IconButton(
                onPressed: _stopSearch,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              )
              : null,
      actions:
          _isSearching
              ? [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    icon: const Icon(Icons.clear, color: Colors.white),
                  ),
              ]
              : [
                IconButton(
                  onPressed: _startSearch,
                  icon: const Icon(Icons.search, color: Colors.white),
                  tooltip: 'Search',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'create_group') {
                      _navigateToCreateGroup();
                    } else if (value == 'logout') {
                      _showLogoutDialog();
                    }
                  },
                  itemBuilder:
                      (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'create_group',
                          child: Row(
                            children: [
                              Icon(Icons.group_add),
                              SizedBox(width: 12),
                              Text('Create Group'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout),
                              SizedBox(width: 12),
                              Text('Logout'),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [Tab(text: "Chats"), Tab(text: "Groups")],
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
        }
        final allChats = snapshot.data!;

        // Filter chats based on search query
        final chats =
            _searchQuery.isEmpty
                ? allChats
                : allChats.where((chat) {
                  final otherUserId = chat.participants.firstWhere(
                    (id) => id != _currentUserId,
                    orElse: () => '',
                  );
                  final userName =
                      chat.participantsName?[otherUserId] ?? "Unknown";
                  final lastMessage = chat.lastMessage ?? "";

                  return userName.toLowerCase().contains(_searchQuery) ||
                      lastMessage.toLowerCase().contains(_searchQuery);
                }).toList();
        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _searchQuery.isEmpty
                      ? Icons.chat_bubble_outline
                      : Icons.search_off,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty ? "No recent chats" : "No chats found",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _searchQuery.isEmpty
                      ? "Start a conversation or create a group"
                      : "No chats match your search",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                if (_searchQuery.isEmpty) ...[
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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

        // Filter groups based on search query
        final allGroups = state.groups;
        final groups =
            _searchQuery.isEmpty
                ? allGroups
                : allGroups.where((group) {
                  final groupName = group.name.toLowerCase();
                  final lastMessage = group.lastMessage?.toLowerCase() ?? "";

                  return groupName.contains(_searchQuery) ||
                      lastMessage.contains(_searchQuery);
                }).toList();
        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _searchQuery.isEmpty ? Icons.group : Icons.search_off,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty ? "No groups yet" : "No groups found",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _searchQuery.isEmpty
                      ? "Create a group to start chatting with multiple people"
                      : "No groups match your search",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                if (_searchQuery.isEmpty) ...[
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
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return GroupListTile(
              group: group,
              currentUserId: _currentUserId,
              onTap: () {
                getIt<AppRouter>().push(
                  GroupChatScreen(groupId: group.id, groupName: group.name),
                );
              },
            );
          },
        );
      },
    );
  }
}
