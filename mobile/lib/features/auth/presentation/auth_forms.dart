import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import 'auth_providers.dart';
import 'login_screen.dart' show validateEmail, validatePassword;

/// Shared page layout + submit handling for the three simple auth forms.
///
/// How it works (read this first if you are new):
///  1. The form validates locally (fast feedback).
///  2. `onSubmit` calls the repository (network).
///  3. While waiting, `_busy` disables the button so a double tap cannot send
///     the request twice.
///  4. An [AppException] (already translated to French) is shown under the form.
class _AuthFormPage extends StatefulWidget {
  const _AuthFormPage({
    required this.title,
    required this.fields,
    required this.formKey,
    required this.submitLabel,
    required this.onSubmit,
  });
  final String title;
  final List<Widget> fields;
  final GlobalKey<FormState> formKey;
  final String submitLabel;
  final Future<void> Function() onSubmit;

  @override
  State<_AuthFormPage> createState() => _AuthFormPageState();
}

class _AuthFormPageState extends State<_AuthFormPage> {
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy || !widget.formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit();
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Form(
              key: widget.formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final f in widget.fields) ...[
                      f,
                      const SizedBox(height: AppSpacing.md)
                    ],
                    if (_error != null)
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : Text(widget.submitLabel),
                    ),
                  ]),
            ),
          ),
        ),
      );
}

void _toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterState();
}

class _RegisterState extends ConsumerState<RegisterScreen> {
  final _key = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  @override
  Widget build(BuildContext context) => _AuthFormPage(
        title: 'Créer un compte',
        formKey: _key,
        submitLabel: "S'inscrire",
        fields: [
          TextFormField(
              controller: _first,
              decoration: const InputDecoration(labelText: 'Prénom'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Prénom requis' : null),
          TextFormField(
              controller: _last,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nom requis' : null),
          TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: validateEmail),
          TextFormField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
              validator: validatePassword),
        ],
        onSubmit: () async {
          final repo = ref.read(authRepositoryProvider);
          await repo.register(
              _first.text.trim(), _last.text.trim(), _email.text.trim(), _pass.text);
          // Sign in right away so the user lands on their home screen.
          await ref
              .read(authStateProvider.notifier)
              .login(_email.text.trim(), _pass.text);
        },
      );
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotState();
}

class _ForgotState extends ConsumerState<ForgotPasswordScreen> {
  final _key = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  Widget build(BuildContext context) => _AuthFormPage(
        title: 'Mot de passe oublié',
        formKey: _key,
        submitLabel: 'Envoyer le lien',
        fields: [
          TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: validateEmail),
        ],
        onSubmit: () async {
          await ref
              .read(authRepositoryProvider)
              .forgotPassword(_email.text.trim());
          if (!mounted) return;
          _toast(context, 'Si ce compte existe, un email a été envoyé.');
          context.go('/reset-password');
        },
      );
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetState();
}

class _ResetState extends ConsumerState<ResetPasswordScreen> {
  final _key = GlobalKey<FormState>();
  final _token = TextEditingController();
  final _pass = TextEditingController();

  @override
  Widget build(BuildContext context) => _AuthFormPage(
        title: 'Nouveau mot de passe',
        formKey: _key,
        submitLabel: 'Réinitialiser',
        fields: [
          TextFormField(
              controller: _token,
              decoration:
                  const InputDecoration(labelText: 'Code reçu par email'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Code requis' : null),
          TextFormField(
              controller: _pass,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Nouveau mot de passe'),
              validator: validatePassword),
        ],
        onSubmit: () async {
          await ref
              .read(authRepositoryProvider)
              .resetPassword(_token.text.trim(), _pass.text);
          if (!mounted) return;
          _toast(context, 'Mot de passe modifié. Connectez-vous.');
          context.go('/login');
        },
      );
}
