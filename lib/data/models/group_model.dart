import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String? groupImageUrl;
  final List<String> members;
  final List<String> admins;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final Timestamp? lastMessageTime;
  final Map<String, Timestamp>? lastReadTime;
  final Map<String, String>? membersName;
  final bool isTyping;
  final String? typingUserId;
  final GroupSettings settings;

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    this.groupImageUrl,
    required this.members,
    required this.admins,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageTime,
    Map<String, Timestamp>? lastReadTime,
    Map<String, String>? membersName,
    this.isTyping = false,
    this.typingUserId,
    GroupSettings? settings,
  })  : lastReadTime = lastReadTime ?? {},
        membersName = membersName ?? {},
        settings = settings ?? GroupSettings();

  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      groupImageUrl: data['groupImageUrl'],
      members: List<String>.from(data['members'] ?? []),
      admins: List<String>.from(data['admins'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      lastMessage: data['lastMessage'],
      lastMessageSenderId: data['lastMessageSenderId'],
      lastMessageTime: data['lastMessageTime'],
      lastReadTime: Map<String, Timestamp>.from(data['lastReadTime'] ?? {}),
      membersName: Map<String, String>.from(data['membersName'] ?? {}),
      isTyping: data['isTyping'] ?? false,
      typingUserId: data['typingUserId'],
      settings: data['settings'] != null
          ? GroupSettings.fromMap(data['settings'])
          : GroupSettings(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'groupImageUrl': groupImageUrl,
      'members': members,
      'admins': admins,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageTime': lastMessageTime,
      'lastReadTime': lastReadTime,
      'membersName': membersName,
      'isTyping': isTyping,
      'typingUserId': typingUserId,
      'settings': settings.toMap(),
    };
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? groupImageUrl,
    List<String>? members,
    List<String>? admins,
    String? createdBy,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? lastMessage,
    String? lastMessageSenderId,
    Timestamp? lastMessageTime,
    Map<String, Timestamp>? lastReadTime,
    Map<String, String>? membersName,
    bool? isTyping,
    String? typingUserId,
    GroupSettings? settings,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      groupImageUrl: groupImageUrl ?? this.groupImageUrl,
      members: members ?? this.members,
      admins: admins ?? this.admins,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      membersName: membersName ?? this.membersName,
      isTyping: isTyping ?? this.isTyping,
      typingUserId: typingUserId ?? this.typingUserId,
      settings: settings ?? this.settings,
    );
  }
  bool isAdmin(String userId) => admins.contains(userId);
  bool isMember(String userId) => members.contains(userId);
  bool isCreator(String userId) => createdBy == userId;

  bool hasUnreadMessages(String userId) {
    if (lastMessageTime == null || lastReadTime == null) {
      return false;
    }
    
    final userLastReadTime = lastReadTime![userId];
    if (userLastReadTime == null) {
      return lastMessageTime != null;
    }
    
    return lastMessageTime!.millisecondsSinceEpoch > userLastReadTime.millisecondsSinceEpoch;
  }
}

class GroupSettings {
  final bool onlyAdminsCanMessage;
  final bool onlyAdminsCanAddMembers;
  final bool onlyAdminsCanEditInfo;
  final bool disappearingMessages;
  final int? disappearingMessagesDuration; // in hours

  GroupSettings({
    this.onlyAdminsCanMessage = false,
    this.onlyAdminsCanAddMembers = false,
    this.onlyAdminsCanEditInfo = true,
    this.disappearingMessages = false,
    this.disappearingMessagesDuration,
  });

  factory GroupSettings.fromMap(Map<String, dynamic> data) {
    return GroupSettings(
      onlyAdminsCanMessage: data['onlyAdminsCanMessage'] ?? false,
      onlyAdminsCanAddMembers: data['onlyAdminsCanAddMembers'] ?? false,
      onlyAdminsCanEditInfo: data['onlyAdminsCanEditInfo'] ?? true,
      disappearingMessages: data['disappearingMessages'] ?? false,
      disappearingMessagesDuration: data['disappearingMessagesDuration'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'onlyAdminsCanMessage': onlyAdminsCanMessage,
      'onlyAdminsCanAddMembers': onlyAdminsCanAddMembers,
      'onlyAdminsCanEditInfo': onlyAdminsCanEditInfo,
      'disappearingMessages': disappearingMessages,
      'disappearingMessagesDuration': disappearingMessagesDuration,
    };
  }

  GroupSettings copyWith({
    bool? onlyAdminsCanMessage,
    bool? onlyAdminsCanAddMembers,
    bool? onlyAdminsCanEditInfo,
    bool? disappearingMessages,
    int? disappearingMessagesDuration,
  }) {
    return GroupSettings(
      onlyAdminsCanMessage: onlyAdminsCanMessage ?? this.onlyAdminsCanMessage,
      onlyAdminsCanAddMembers: onlyAdminsCanAddMembers ?? this.onlyAdminsCanAddMembers,
      onlyAdminsCanEditInfo: onlyAdminsCanEditInfo ?? this.onlyAdminsCanEditInfo,
      disappearingMessages: disappearingMessages ?? this.disappearingMessages,
      disappearingMessagesDuration: disappearingMessagesDuration ?? this.disappearingMessagesDuration,
    );
  }
}
