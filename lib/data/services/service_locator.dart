import 'package:chatzilla/data/repositories/auth_repository.dart';
import 'package:chatzilla/data/repositories/chat_repository.dart';
import 'package:chatzilla/data/repositories/contact_repository.dart';
import 'package:chatzilla/data/repositories/group_repository.dart';
import 'package:chatzilla/data/services/notification_service.dart';
import 'package:chatzilla/firebase_options.dart';
import 'package:chatzilla/logic/cubit/auth/auth_cubit.dart';
import 'package:chatzilla/logic/cubit/chat/chat_cubit.dart';
import 'package:chatzilla/logic/cubit/group/group_chat_cubit.dart';
import 'package:chatzilla/logic/cubit/group/groups_cubit.dart';
import 'package:chatzilla/router/app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── OneSignal Notification Service ──────────────────────────────────
  // TODO: Replace with your real OneSignal App ID from the OneSignal dashboard.
  getIt.registerLazySingleton(() => NotificationService());
  getIt<NotificationService>().initialize('e031531f-e118-4f0b-b43d-22a423cea978');

  getIt.registerLazySingleton(() => AppRouter());
  getIt.registerLazySingleton<FirebaseFirestore>(
    () => FirebaseFirestore.instance,
  );
  getIt.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  getIt.registerLazySingleton(() => AuthRepository());
  getIt.registerLazySingleton(() => ContactRepository());
  getIt.registerLazySingleton(() => ChatRepository());
  getIt.registerLazySingleton(() => GroupRepository());
  getIt.registerLazySingleton(
    () => AuthCubit(authRepository: AuthRepository()),
  );
  getIt.registerLazySingleton(
    () => GroupsCubit(
      groupRepository: getIt<GroupRepository>(),
      currentUserId: getIt<FirebaseAuth>().currentUser!.uid,
    ),
  );
  getIt.registerFactory(
    () => ChatCubit(
      chatRepository: ChatRepository(),
      currentUserId: getIt<FirebaseAuth>().currentUser!.uid,
    ),
  );
  getIt.registerFactoryParam<GroupChatCubit, String, void>(
    (currentUserName, _) => GroupChatCubit(
      groupRepository: getIt<GroupRepository>(),
      currentUserId: getIt<FirebaseAuth>().currentUser!.uid,
      currentUserName: currentUserName,
    ),
  );
}
