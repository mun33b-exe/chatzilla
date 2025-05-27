import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String createdBy;
  final List<String> participants;
  final List<String> admins;
  final Timestamp createdAt;
  final Timestamp? lastMessageTime;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final Map<String, String> participantsName;
  final bool isActive;

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.createdBy,
    required this.participants,
    required this.admins,
    required this.createdAt,
    this.lastMessageTime,
    this.lastMessage,
    this.lastMessageSenderId,
    required this.participantsName,
    this.isActive = true,
  });
  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data();

      // Check if document exists and has data
      if (data == null) {
        throw Exception('Group document does not exist or has no data');
      }

      final dataMap = data as Map<String, dynamic>;

      // Validate required fields
      if (dataMap['name'] == null || dataMap['name'].toString().isEmpty) {
        throw Exception('Group name is required');
      }

      if (dataMap['createdBy'] == null ||
          dataMap['createdBy'].toString().isEmpty) {
        throw Exception('Group creator is required');
      }

      return GroupModel(
        id: doc.id,
        name: dataMap['name']?.toString() ?? '',
        description: dataMap['description']?.toString(),
        imageUrl: dataMap['imageUrl']?.toString(),
        createdBy: dataMap['createdBy']?.toString() ?? '',
        participants: _parseStringList(dataMap['participants']),
        admins: _parseStringList(dataMap['admins']),
        createdAt: _parseTimestamp(dataMap['createdAt']),
        lastMessageTime: _parseTimestamp(dataMap['lastMessageTime']),
        lastMessage: dataMap['lastMessage']?.toString(),
        lastMessageSenderId: dataMap['lastMessageSenderId']?.toString(),
        participantsName: _parseParticipantsName(dataMap['participantsName']),
        isActive: dataMap['isActive'] as bool? ?? true,
      );
    } catch (e) {
      throw Exception('Failed to parse group data: $e');
    }
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  static Timestamp _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return Timestamp.now();
  }

  static Map<String, String> _parseParticipantsName(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      return Map<String, String>.from(
        value.map((key, val) => MapEntry(key.toString(), val.toString())),
      );
    }
    return {};
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'createdBy': createdBy,
      'participants': participants,
      'admins': admins,
      'createdAt': createdAt,
      'lastMessageTime': lastMessageTime,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'participantsName': participantsName,
      'isActive': isActive,
    };
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? createdBy,
    List<String>? participants,
    List<String>? admins,
    Timestamp? createdAt,
    Timestamp? lastMessageTime,
    String? lastMessage,
    String? lastMessageSenderId,
    Map<String, String>? participantsName,
    bool? isActive,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdBy: createdBy ?? this.createdBy,
      participants: participants ?? this.participants,
      admins: admins ?? this.admins,
      createdAt: createdAt ?? this.createdAt,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      participantsName: participantsName ?? this.participantsName,
      isActive: isActive ?? this.isActive,
    );
  }
}
