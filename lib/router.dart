import 'package:biletflow_mobile/auth_repository.dart';
import 'package:biletflow_mobile/screens/home/home_screen.dart';
import 'package:biletflow_mobile/screens/signin/sign_in_screen.dart';
import 'package:biletflow_mobile/screens/signup/activation_screen.dart';
import 'package:biletflow_mobile/screens/signup/sign_up_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

GoRouter createRouter(AuthRepository authRepo) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => HomeScreen()),
      GoRoute(path: '/sign-up', builder: (context, state) => SignUpScreen()),
      GoRoute(path: '/sign-in', builder: (context, state) => SignInScreen()),
      GoRoute(
        path: '/activate',
        builder: (context, state) => ActivationScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    ],
    redirect: (context, state) {
      final signedIn = authRepo.isSignedIn;
      final path = state.matchedLocation;

      if (signedIn == null) {
        return path == '/splash' ? null : '/splash';
      }

      final isAuthPage = {'/sign-in', '/sign-up', '/activate'}.contains(path);

      if (!signedIn && !isAuthPage) {
        return '/sign-in';
      }

      if (signedIn && (isAuthPage || path == '/splash')) {
        return '/';
      }

      return null;
    },
  );
}
