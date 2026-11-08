import 'package:biletflow_mobile/components/password_field.dart';
import 'package:biletflow_mobile/main.dart';
import 'package:biletflow_mobile/bilet_flow_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sign_in_screen.freezed.dart';

class SignInFormFailure {
  const SignInFormFailure(this.message);

  final String message;
}

SignInFormFailure signInFormFailureFrom(BiletFlowException error) {
  final message = switch (error) {
    RequestTimeoutException() =>
      'The server took too long to respond. Please try again.',
    ConnectionFailedException() =>
      "Couldn't reach BiletFlow. Check your connection and try again.",
    _ => "Couldn't sign in to your account. Please try again.",
  };

  return SignInFormFailure(message);
}

@freezed
class SignInModel with _$SignInModel {
  final String email;
  final String password;
  final SignInFormFailure? failure;
  final bool isSigningIn;

  new({
    required this.email,
    required this.password,
    required this.failure,
    required this.isSigningIn,
  });

  SignInModel.empty()
    : email = "",
      password = "",
      isSigningIn = false,
      failure = null;
}

class SignInModelNotifier extends Notifier<SignInModel> {
  @override
  SignInModel build() {
    return .empty();
  }

  void update(SignInModel Function(SignInModel) mapper) {
    state = mapper(state).copyWith(failure: null);
  }

  Future<void> signIn() async {
    if (state.isSigningIn) return;

    final authRepository = ref.read(authRepositoryProvider);
    state = state.copyWith(isSigningIn: true);

    SignInFormFailure? failure;
    try {
      await authRepository.signIn(state.email, state.password);
      ref.read(routerProvider).go("/");
    } on BiletFlowException catch (error) {
      failure = signInFormFailureFrom(error);
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isSigningIn: false, failure: failure);
      }
    }
  }
}

final signInModelProvider = NotifierProvider.autoDispose(
  () => SignInModelNotifier(),
);

class SignInScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signUpModel = ref.watch(signInModelProvider);
    final SignInModel(:failure, :isSigningIn) = signUpModel;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              SizedBox(height: 20),
              Align(
                alignment: .centerLeft,
                child: SizedBox(
                  height: 50,
                  child: SvgPicture.asset(
                    "assets/biletflow-logo.svg",
                    semanticsLabel: 'Dart Logo',
                  ),
                ),
              ),
              Spacer(),
              Text("Sign in", style: TextTheme.of(context).titleLarge),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Don\'t have an account? '),
                  TextButton(
                    onPressed: () {
                      ref.read(routerProvider).go("/sign-up");
                    },
                    child: const Text('Create one'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  label: Text("Email"),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => ref
                    .read(signInModelProvider.notifier)
                    .update((state) => state.copyWith(email: value)),
              ),
              SizedBox(height: 20),
              PasswordField(
                onChanged: (value) => ref
                    .read(signInModelProvider.notifier)
                    .update((state) => state.copyWith(password: value)),
                label: Text("Password"),
              ),
              SizedBox(height: 20),
              if (failure != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    failure.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton.tonal(
                onPressed: isSigningIn
                    ? () {}
                    : ref.read(signInModelProvider.notifier).signIn,
                style: ButtonStyle(
                  visualDensity: VisualDensity(
                    horizontal: VisualDensity.maximumDensity,
                    vertical: VisualDensity.maximumDensity,
                  ),
                ),
                child: Stack(
                  alignment: .center,
                  children: [
                    if (isSigningIn)
                      SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(),
                      ),
                    Visibility(
                      visible: !isSigningIn,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: Text("Sign in"),
                    ),
                  ],
                ),
              ),
              Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
