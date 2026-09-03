import 'package:flutter_test/flutter_test.dart';
import 'package:truckfix/data/services/api_client.dart';

void main() {
  group('ApiClient.isAuthFailure', () {
    test('treats HTTP 401 as auth failure', () {
      expect(ApiClient.isAuthFailure(401, const {}), isTrue);
    });

    test('treats Invalid token message as auth failure', () {
      expect(
        ApiClient.isAuthFailure(403, {'message': 'Invalid token'}),
        isTrue,
      );
    });

    test('does not logout on 5xx', () {
      expect(
        ApiClient.isAuthFailure(500, {'message': 'Invalid token'}),
        isFalse,
      );
      expect(ApiClient.isAuthFailure(503, const {}), isFalse);
    });

    test('does not treat generic client errors as auth failure', () {
      expect(
        ApiClient.isAuthFailure(400, {'message': 'Missing field'}),
        isFalse,
      );
      expect(
        ApiClient.isAuthFailure(404, {'message': 'Not found'}),
        isFalse,
      );
    });
  });

  group('ApiClient.isJwtExpired', () {
    test('returns false for opaque non-jwt tokens', () {
      expect(ApiClient.isJwtExpired('not-a-jwt'), isFalse);
    });
  });
}
