import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStorageService {
  Future<String?> getToken();
  Future<void> saveToken(String token);
  Future<void> clearToken();
}

class SecureTokenStorageService implements TokenStorageService {
  SecureTokenStorageService(this.storage);

  final FlutterSecureStorage storage;

  static const _tokenKey = 'auth_token';

  @override
  Future<String?> getToken() {
    return storage.read(key: _tokenKey);
  }

  @override
  Future<void> saveToken(String token) {
    return storage.write(key: _tokenKey, value: token);
  }

  @override
  Future<void> clearToken() {
    return storage.delete(key: _tokenKey);
  }
}
