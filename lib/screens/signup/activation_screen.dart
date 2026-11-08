import 'package:biletflow_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActivationScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Spacer(),
                Text(
                  "Check your email to activate your account",
                  style: TextTheme.of(context).titleLarge,
                  textAlign: .center,
                ),
                SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    ref.read(routerProvider).go("/sign-in");
                  },
                  child: Text("Back to sign in"),
                ),
                Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
