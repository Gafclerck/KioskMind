import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/datasources/user_profile_remote_data_source.dart';
import '../../data/repositories/user_profile_repository_impl.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../../domain/usecases/update_user_profile.dart';

final userProfileRemoteDataSourceProvider =
    Provider<UserProfileRemoteDataSource>(
      (ref) => UserProfileRemoteDataSourceImpl(
        firestore: FirebaseFirestore.instance,
      ),
    );

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepositoryImpl(
    dataSource: ref.watch(userProfileRemoteDataSourceProvider),
  );
});

final updateUserProfileProvider = Provider<UpdateUserProfile>((ref) {
  return UpdateUserProfile(ref.watch(userProfileRepositoryProvider));
});

/// Profil de l'utilisateur connecté, ou `null` quand personne n'est connecté.
///
/// Réagit au changement de session : le flux est réabonné au document
/// `users/{uid}` à chaque connexion.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final String? uid = ref.watch(authStateProvider).valueOrNull;
  if (uid == null) {
    return Stream<UserProfile?>.value(null);
  }
  return ref.watch(userProfileRepositoryProvider).watchProfile(uid);
});
