import 'package:biletflow_mobile/components/password_field.dart';
import 'package:biletflow_mobile/main.dart';
import 'package:biletflow_mobile/bilet_flow_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sign_up_screen.freezed.dart';

abstract class SignUpFailure {}

class PasswordsDontMatchFailure implements SignUpFailure {}

enum SignUpField { login, email, password }

class SignUpFieldFailure implements SignUpFailure {
  const SignUpFieldFailure(this.field, this.message);

  final SignUpField field;
  final String message;
}

class SignUpFormFailure implements SignUpFailure {
  const SignUpFormFailure(this.message);

  final String message;
}

List<SignUpFailure> signUpFailuresFrom(BiletFlowException error) {
  if (error is EmailAlreadyUsedException) {
    return const [
      SignUpFieldFailure(SignUpField.email, 'This email is already in use.'),
    ];
  }

  if (error is LoginAlreadyUsedException) {
    return const [
      SignUpFieldFailure(SignUpField.login, 'This login is already taken.'),
    ];
  }

  if (error is RequestValidationException) {
    final fields = error.fieldErrors.map((issue) => issue.field).toSet();
    final failures = <SignUpFailure>[
      if (fields.contains('login'))
        const SignUpFieldFailure(
          SignUpField.login,
          'Enter a valid login between 1 and 50 characters.',
        ),
      if (fields.contains('email'))
        const SignUpFieldFailure(
          SignUpField.email,
          'Enter a valid email address.',
        ),
      if (fields.contains('password'))
        const SignUpFieldFailure(
          SignUpField.password,
          'Enter a password between 4 and 100 characters.',
        ),
    ];

    if (failures.isNotEmpty) return failures;
  }

  return [
    SignUpFormFailure(switch (error) {
      RequestTimeoutException() =>
        'The server took too long to respond. Please try again.',
      ConnectionFailedException() =>
        "Couldn't reach BiletFlow. Check your connection and try again.",
      _ => "Couldn't create your account. Please try again.",
    }),
  ];
}

@freezed
class SignUpModel with _$SignUpModel {
  final String login;
  final String email;
  final String password;
  final String repeatedPassword;
  final Iterable<SignUpFailure> failures;
  final bool isCreatingAccount;

  new({
    required this.login,
    required this.email,
    required this.password,
    required this.repeatedPassword,
    required this.failures,
    required this.isCreatingAccount,
  });

  SignUpModel.empty()
    : login = "",
      email = "",
      password = "",
      repeatedPassword = "",
      isCreatingAccount = false,
      failures = Iterable.empty();

  SignUpModel clearFailures() {
    return copyWith(failures: Iterable.empty());
  }
}

class SignUpModelNotifier extends Notifier<SignUpModel> {
  @override
  SignUpModel build() {
    return .empty();
  }

  void update(SignUpModel Function(SignUpModel) mapper) {
    state = mapper(state).clearFailures();
  }

  Future<void> signUp() async {
    if (state.isCreatingAccount) return;

    final submitted = validate(state);
    if (submitted.failures.isNotEmpty) {
      state = submitted;
      return;
    }

    final requestRef = ref;
    final service = requestRef.read(biletFlowServiceProvider);
    state = submitted.copyWith(isCreatingAccount: true);

    var failures = const <SignUpFailure>[];
    try {
      await service.register(
        login: submitted.login,
        email: submitted.email,
        password: submitted.password,
      );

      ref.read(routerProvider).go("/activate");
    } on BiletFlowException catch (error) {
      failures = signUpFailuresFrom(error);
    } finally {
      if (requestRef.mounted) {
        state = state.copyWith(isCreatingAccount: false, failures: failures);
      }
    }
  }

  SignUpModel validate(SignUpModel value) {
    return value.copyWith(
      failures: List.unmodifiableOf([
        if (value.password != value.repeatedPassword)
          PasswordsDontMatchFailure(),
      ]),
    );
  }
}

final signUpModelProvider =
    NotifierProvider.autoDispose<SignUpModelNotifier, SignUpModel>(
      SignUpModelNotifier.new,
    );

class SignUpScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signUpModel = ref.watch(signUpModelProvider);
    final SignUpModel(:failures, :isCreatingAccount) = signUpModel;

    String? fieldError(SignUpField field) => failures
        .whereType<SignUpFieldFailure>()
        .where((failure) => failure.field == field)
        .firstOrNull
        ?.message;

    final formFailure = failures.whereType<SignUpFormFailure>().firstOrNull;

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
              Text("Sign up", style: TextTheme.of(context).titleLarge),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? '),
                  TextButton(
                    onPressed: () {
                      ref.read(routerProvider).go("/sign-in");
                    },
                    child: const Text('Sign in'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  label: Text("Login"),
                  border: OutlineInputBorder(),
                  errorText: fieldError(SignUpField.login),
                ),
                onChanged: (value) => ref
                    .read(signUpModelProvider.notifier)
                    .update((state) => state.copyWith(login: value)),
              ),
              SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  label: Text("Email"),
                  border: OutlineInputBorder(),
                  errorText: fieldError(SignUpField.email),
                ),
                onChanged: (value) => ref
                    .read(signUpModelProvider.notifier)
                    .update((state) => state.copyWith(email: value)),
              ),
              SizedBox(height: 20),
              PasswordField(
                onChanged: (value) => ref
                    .read(signUpModelProvider.notifier)
                    .update((state) => state.copyWith(password: value)),
                label: Text("Password"),
                errorText: fieldError(SignUpField.password),
              ),
              SizedBox(height: 20),
              PasswordField(
                onChanged: (value) => ref
                    .read(signUpModelProvider.notifier)
                    .update((state) => state.copyWith(repeatedPassword: value)),
                label: Text("Repeat password"),
                error:
                    failures.whereType<PasswordsDontMatchFailure>().isNotEmpty
                    ? Text("Password does not match")
                    : null,
              ),
              SizedBox(height: 20),
              if (formFailure != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    formFailure.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton.tonal(
                onPressed: isCreatingAccount
                    ? () {}
                    : ref.read(signUpModelProvider.notifier).signUp,
                style: ButtonStyle(
                  visualDensity: VisualDensity(
                    horizontal: VisualDensity.maximumDensity,
                    vertical: VisualDensity.maximumDensity,
                  ),
                ),
                child: Stack(
                  alignment: .center,
                  children: [
                    if (isCreatingAccount)
                      SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(),
                      ),
                    Visibility(
                      visible: !isCreatingAccount,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: Text("Create account"),
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
