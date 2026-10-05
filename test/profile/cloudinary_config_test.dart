import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/profile/data/cloudinary/cloudinary_config.dart';

void main() {
  group('CloudinaryConfig.isUsable', () {
    test('accepts a real cloud name and preset', () {
      expect(CloudinaryConfig.isUsable('demo'), isTrue);
      expect(CloudinaryConfig.isUsable('kioskmind_unsigned'), isTrue);
    });

    test('rejects an empty or blank value', () {
      expect(CloudinaryConfig.isUsable(''), isFalse);
      expect(CloudinaryConfig.isUsable('   '), isFalse);
    });

    test('rejects the placeholders left in .env.example', () {
      // Un .env copié tel quel ne doit pas passer pour une configuration
      // valide, sinon l'utilisateur voit une erreur Cloudinary brute.
      expect(CloudinaryConfig.isUsable('votre_cloud_name'), isFalse);
      expect(CloudinaryConfig.isUsable('votre_preset_unsigned'), isFalse);
      expect(CloudinaryConfig.isUsable('VOTRE_CLOUD_NAME'), isFalse);
    });

    test('ignores surrounding whitespace on a real value', () {
      expect(CloudinaryConfig.isUsable('  demo  '), isTrue);
    });
  });

  group('CloudinaryConfig.isConfigured', () {
    test('is false on a build without any dart-define', () {
      // Le runner de tests ne définit pas CLOUDINARY_CLOUD_NAME.
      expect(CloudinaryConfig.cloudName, isEmpty);
      expect(CloudinaryConfig.isConfigured, isFalse);
    });

    test('builds the upload endpoint from the cloud name', () {
      expect(
        CloudinaryConfig.uploadUrl,
        'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload',
      );
    });
  });
}
