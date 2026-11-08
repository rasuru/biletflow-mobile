import 'dart:async';

import 'package:biletflow_mobile/bilet_flow_service.dart';
import 'package:biletflow_mobile/token_storage_service.dart';
import 'package:dio/dio.dart';

class AuthRepository {
  AuthRepository({
    required this.service,
    required this.storage,
    required this.dio,
  });

  final BiletFlowService service;
  final SecureTokenStorageService storage;
  final Dio dio;

  final _authState = StreamController<bool>.broadcast();

  Stream<bool> get authState => _authState.stream;

  bool? _isSignedIn;

  bool? get isSignedIn => _isSignedIn;

  void _setSignedIn(bool value) {
    _isSignedIn = value;
    _authState.add(value);
  }

  Future<void> signIn(String email, String password) async {
    final token = await service.signIn(email: email, password: password);

    await storage.saveToken(token);
    dio.options.headers['Authorization'] = 'Bearer $token';

    _setSignedIn(true);
  }

  Future<void> restoreSession() async {
    final token = await storage.getToken();

    if (token == null) {
      _setSignedIn(false);
      return;
    }

    dio.options.headers['Authorization'] = 'Bearer $token';
    _setSignedIn(true);
  }

  Future<void> signOut() async {
    await storage.clearToken();
    dio.options.headers.remove('Authorization');

    _setSignedIn(false);
  }

  void dispose() {
    _authState.close();
  }
}
