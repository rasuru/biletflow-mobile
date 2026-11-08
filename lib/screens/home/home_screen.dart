import 'package:biletflow_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: FilledButton(
            onPressed: () {
              ref.read(authRepositoryProvider).signOut();
            },
            child: Text("Sign out"),
          ),
        ),
      ),
    );
  }
}
