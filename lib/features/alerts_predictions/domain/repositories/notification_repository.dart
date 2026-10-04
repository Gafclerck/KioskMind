abstract class NotificationRepository {
  Future<void> enregistrerToken(String userId, String token);
  Future<String?> obtenirToken();
}
