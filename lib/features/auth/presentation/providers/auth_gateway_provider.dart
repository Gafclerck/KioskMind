import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/firebase_auth_gateway.dart';
import '../../domain/auth_gateway.dart';

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => FirebaseAuthGateway(),
);
