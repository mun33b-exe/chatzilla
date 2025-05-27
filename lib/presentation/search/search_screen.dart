import 'package:chatzilla/data/models/chat_room_model.dart';
import 'package:chatzilla/data/models/group_model.dart';
import 'package:chatzilla/data/repositories/auth_repository.dart';
import 'package:chatzilla/data/repositories/chat_repository.dart';
import 'package:chatzilla/data/repositories/group_repository.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:chatzilla/presentation/chat/chat_message_screen.dart';
import 'package:chatzilla/presentation/group/group_chat_screen.dart';
import 'package:chatzilla/router/app_router.dart';
import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChatRepository _chatRepository = getIt<ChatRepository>();
  final GroupRepository _groupRepository = getIt<GroupRepository>();
  
  List<ChatRoomModel> _filteredChats = [];
  List<GroupModel> _filteredGroups = [];
  List<ChatRoomModel> _allChats = [];
  List<GroupModel> _allGroups = [];
  bool _isLoading = true;
  String _currentUserId = '';
  @override
  void initState() {
    super.initState();
    _currentUserId = getIt<AuthRepository>().currentUser?.uid ?? '';
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load chats
      final chatsStream = _chatRepository.getChatRooms(_currentUserId);
      final chatsSnapshot = await chatsStream.first;
      
      // Load groups
      final groupsStream = _groupRepository.getUserGroups(_currentUserId);
      final groupsSnapshot = await groupsStream.first;
      
      setState(() {
        _allChats = chatsSnapshot;
        _allGroups = groupsSnapshot;
        _filteredChats = chatsSnapshot;
        _filteredGroups = groupsSnapshot;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    
    if (query.isEmpty) {
      setState(() {
        _filteredChats = _allChats;
        _filteredGroups = _allGroups;
      });
      return;
    }
    
    setState(() {
      // Filter chats by participant names or last message
      _filteredChats = _allChats.where((chat) {
        final otherUserId = chat.participants.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => '',
        );
        final otherUserName = chat.participantsName?[otherUserId] ?? '';
        final lastMessage = chat.lastMessage ?? '';
        
        return otherUserName.toLowerCase().contains(query) ||
               lastMessage.toLowerCase().contains(query);
      }).toList();
      
      // Filter groups by name or description
      _filteredGroups = _allGroups.where((group) {      return group.name.toLowerCase().contains(query) ||
               group.description.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search chats and groups...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
              },
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildSearchResults(),
    );
  }

  Widget _buildSearchResults() {
    final hasResults = _filteredChats.isNotEmpty || _filteredGroups.isNotEmpty;
    
    if (!hasResults && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Search ChatZilla',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Find your chats and groups',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView(
      children: [
        // Groups Section
        if (_filteredGroups.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Groups (${_filteredGroups.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          ..._filteredGroups.map((group) => _buildGroupTile(group)),
          const Divider(),
        ],
        
        // Chats Section
        if (_filteredChats.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Chats (${_filteredChats.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          ..._filteredChats.map((chat) => _buildChatTile(chat)),
        ],
      ],
    );
  }

  Widget _buildGroupTile(GroupModel group) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColorDark,
        child: Text(
          group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(
        group.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),      subtitle: Text(
        group.description.isNotEmpty 
            ? group.description 
            : '${group.members.length} members',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.group),
      onTap: () {
        getIt<AppRouter>().push(
          GroupChatScreen(
            groupId: group.id,
            groupName: group.name,
          ),
        );
      },
    );
  }

  Widget _buildChatTile(ChatRoomModel chat) {
    final otherUserId = chat.participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => 'Unknown',
    );
    final otherUserName = chat.participantsName?[otherUserId] ?? 'Unknown User';
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColorDark,
        foregroundImage: NetworkImage(
          "https://ui-avatars.com/api/?name=${Uri.encodeComponent(otherUserName)}&background=${Theme.of(context).primaryColorDark.value.toRadixString(16).substring(2)}&color=fff",
        ),
        child: Text(
          otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : 'U',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(
        otherUserName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        chat.lastMessage ?? 'No messages yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chat),
      onTap: () {
        getIt<AppRouter>().push(
          ChatMessageScreen(
            receiverId: otherUserId,
            receiverName: otherUserName,
          ),
        );
      },
    );
  }
}
