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
    final data = doc.data() as Map<String, dynamic>;
    return GroupModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      imageUrl: data['imageUrl'],
      createdBy: data['createdBy'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      admins: List<String>.from(data['admins'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      lastMessageTime: data['lastMessageTime'],
      lastMessage: data['lastMessage'],
      lastMessageSenderId: data['lastMessageSenderId'],
      participantsName: Map<String, String>.from(
        data['participantsName'] ?? {},
      ),
      isActive: data['isActive'] ?? true,
    );
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
