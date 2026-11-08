import 'package:biletflow_mobile/auth_repository.dart';
import 'package:biletflow_mobile/router.dart';
import 'package:biletflow_mobile/screens/home/home_screen.dart';
import 'package:biletflow_mobile/screens/signin/sign_in_screen.dart';
import 'package:biletflow_mobile/screens/signup/activation_screen.dart';
import 'package:biletflow_mobile/screens/signup/sign_up_screen.dart';
import 'package:biletflow_mobile/bilet_flow_service.dart';
import 'package:biletflow_mobile/token_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

late final Provider<Dio> biletFlowDioProvider;
late final Provider<BiletFlowService> biletFlowServiceProvider;
late final Provider<AuthRepository> authRepositoryProvider;

final flutterSecureStorageProvider = Provider((ref) => FlutterSecureStorage());

final routerProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final router = createRouter(authRepo);

  final subscription = authRepo.authState.listen((_) {
    router.refresh();
  });

  ref.onDispose(() {
    subscription.cancel();
    router.dispose();
  });

  // Start restoration after the listener is attached.
  Future.microtask(authRepo.restoreSession);

  return router;
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  biletFlowDioProvider = Provider(
    (ref) => Dio(BaseOptions(baseUrl: dotenv.get('BASE_URL'))),
  );

  biletFlowServiceProvider = Provider(
    (ref) => BiletFlowService(ref.watch(biletFlowDioProvider)),
  );

  authRepositoryProvider = Provider((ref) {
    final repository = AuthRepository(
      dio: ref.watch(biletFlowDioProvider),
      service: ref.watch(biletFlowServiceProvider),
      storage: SecureTokenStorageService(
        ref.watch(flutterSecureStorageProvider),
      ),
    );

    ref.onDispose(repository.dispose);

    return repository;
  });

  runApp(ProviderScope(retry: (retryCount, error) => null, child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
