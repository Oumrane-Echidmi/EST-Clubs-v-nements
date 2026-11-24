import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_providers.dart';

String? validateEmail(String? v) =>
    (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
        ? 'Email invalide'
        : null;

String? validatePassword(String? v) => (v == null ||
        v.length < 8 ||
        !RegExp(r'[A-Za-z]').hasMatch(v) ||
        !RegExp(r'\d').hasMatch(v))
    ? '8 caractères minimum, avec lettre et chiffre'
    : null;

/// Brand block from the Stitch login screen: school pill, logo tile with the
/// orange ticket badge, app name and tagline.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified, size: 15, color: cs.primary),
          const SizedBox(width: 6),
          Flexible(
              child: Text('École Supérieure de Technologie',
                  style: TextStyle(
                      color: cs.primary, fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
      ),
      const SizedBox(height: AppSpacing.md),
      Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))]),
          child: Icon(Icons.school, size: 48, color: cs.primary),
        ),
        Positioned(
          right: -6,
          bottom: -6,
          child: CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.secondaryContainer,
              child: const Icon(Icons.local_activity, size: 16, color: Colors.white)),
        ),
      ]),
      const SizedBox(height: AppSpacing.md),
      Text('EST Clubs & Événements',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.onSurface, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('Le portail officiel de la vie associative et étudiante',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
    ]);
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authStateProvider.notifier)
          .login(_email.text.trim(), _pass.text);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    const navy = Color(0xFF1E3A8A);
    const field = Color(0xFFEFF4FF);
    InputDecoration deco(String hint, IconData icon, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.onSurfaceVariant),
        suffixIcon: suffix,
        fillColor: field,
        filled: true);
    Widget label(String l, [Widget? trailing]) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (trailing != null) trailing,
        ]));
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const BrandHeader(),
              const SizedBox(height: AppSpacing.lg),
              // White form card, as in the Stitch login screen.
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Icon(Icons.lock_outline, color: navy),
                    const SizedBox(width: 8),
                    const Expanded(
                        child: Text('Authentification Étudiant',
                            style: TextStyle(fontWeight: FontWeight.w800))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: const Color(0xFFDCE9FF), borderRadius: BorderRadius.circular(20)),
                      child: const Text('Compte académique UIZ',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: navy)),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  label('Email institutionnel',
                      const Text('Obligatoire', style: TextStyle(fontSize: 12, color: AppColors.outline))),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: deco('prenom.nom@edu.uiz.ac.ma', Icons.mail_outline),
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 16),
                  label(
                      t.password,
                      GestureDetector(
                          onTap: () => context.push('/forgot-password'),
                          child: Text(t.forgotPassword,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700, color: navy)))),
                  TextFormField(
                    controller: _pass,
                    obscureText: _hide,
                    decoration: deco('••••••••', Icons.key_outlined,
                        suffix: IconButton(
                            icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _hide = !_hide))),
                    validator: validatePassword,
                  ),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(_error!, style: TextStyle(color: cs.error))),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: navy, minimumSize: const Size.fromHeight(56)),
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.login),
                    label: const Text('Se connecter avec mon compte étudiant',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => context.push('/register'), child: Text(t.createAccount)),
              const SizedBox(height: 4),
              Text('Protection des données conforme CNDP & charte numérique UIZ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: cs.outline)),
            ]),
          ),
        ),
      ),
    );
  }
}
