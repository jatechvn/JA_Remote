import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/security/dpapi_helper.dart';

void main() {
  group('DpapiHelper', () {
    test('isSupported is true on Windows', () {
      expect(DpapiHelper.isSupported, isTrue);
    });

    test('encrypt and decrypt roundtrip matches original text', () {
      const original = 'SecretPassword123!@#';
      final encrypted = DpapiHelper.encrypt(original);

      expect(encrypted.startsWith('dpapi:'), isTrue);
      expect(encrypted, isNot(equals(original)));

      final decrypted = DpapiHelper.decrypt(encrypted);
      expect(decrypted, equals(original));
    });

    test('encrypt empty string returns empty string', () {
      expect(DpapiHelper.encrypt(''), equals(''));
    });

    test('decrypt non-dpapi string returns unmodified string', () {
      const plain = 'regular_plain_password';
      expect(DpapiHelper.decrypt(plain), equals(plain));
    });

    test('encrypt handles unicode / special characters properly', () {
      const complex = 'MậtKhẩu_TiếngViệt_测试_123456!@#\$%^&*()';
      final encrypted = DpapiHelper.encrypt(complex);
      final decrypted = DpapiHelper.decrypt(encrypted);
      expect(decrypted, equals(complex));
    });
  });
}
