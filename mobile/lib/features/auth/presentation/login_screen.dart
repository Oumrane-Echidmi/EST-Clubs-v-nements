import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
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

const _navy = Color(0xFF1E3A8A);

/// Brand block from the Stitch login screen: school pill, logo tile with the
/// orange ticket badge, app name and tagline.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified, size: 15, color: cs.primary),
          const SizedBox(width: 6),
          Flexible(
              child: Text('École Supérieure de Technologie • Université Ibn Zohr',
                  textAlign: TextAlign.center,
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
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B5BDB)]),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))]),
          child: const Icon(Icons.calendar_month_rounded, size: 52, color: Colors.white),
        ),
        const Positioned(
          right: -6,
          bottom: -6,
          child: CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.secondaryContainer,
              child: Icon(Icons.local_activity, size: 16, color: Colors.white)),
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

/// Auto-advancing 3-step intro card (Stitch "Étape 1 sur 3").
class _StepsCarousel extends StatefulWidget {
  const _StepsCarousel();
  @override
  State<_StepsCarousel> createState() => _StepsCarouselState();
}

class _StepsCarouselState extends State<_StepsCarousel> {
  final _c = PageController();
  Timer? _t;
  int _i = 0;

  static const _steps = [
    (Icons.groups, Color(0xFFDCE1FF), Color(0xFF00236F), 'Découvre les clubs',
        "Explore les 8 associations officielles du campus EST et trouve ta passion sportive, tech ou culturelle."),
    (Icons.notifications_active, Color(0xFFFFDBCA), Color(0xFF9D4300), 'Ne rate aucun événement',
        "Reçois des notifications en temps réel et des alertes de places limitées avant la clôture."),
    (Icons.qr_code_2, Color(0xFFD8E2FF), Color(0xFF00285E), "Inscris-toi en 1 clic",
        "Obtiens ton Pass instantané dans ton portefeuille numérique et valide ta présence aux ateliers."),
  ];

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_c.hasClients) return;
      _c.animateToPage((_i + 1) % _steps.length,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
        decoration: BoxDecoration(
            color: const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Column(children: [
          SizedBox(
            height: 190,
            child: PageView(
              controller: _c,
              onPageChanged: (v) => setState(() => _i = v),
              children: [
                for (final (i, s) in _steps.indexed)
                  Column(children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                          color: s.$2, borderRadius: BorderRadius.circular(16)),
                      child: Icon(s.$1, size: 28, color: s.$3),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                          color: s.$2, borderRadius: BorderRadius.circular(12)),
                      child: Text('Étape ${i + 1} sur 3',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700, color: s.$3)),
                    ),
                    const SizedBox(height: 6),
                    Text(s.$4,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(s.$5,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF444651))),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _steps.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                    color: i == _i ? const Color(0xFF00236F) : const Color(0xFFC5C5D3),
                    borderRadius: BorderRadius.circular(8)),
              ),
          ]),
        ]),
      );
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
  bool _student = true; // cosmetic: the backend decides the role from the account
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
    Widget segment(String text, IconData icon, bool on, VoidCallback tap) => Expanded(
          child: GestureDetector(
            onTap: tap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                  color: on ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: on
                      ? const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                      : null),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 18, color: on ? _navy : AppColors.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(text,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: on ? _navy : AppColors.onSurfaceVariant)),
              ]),
            ),
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const BrandHeader(),
              const SizedBox(height: AppSpacing.md),
              const _StepsCarousel(),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Espace de connexion',
                      style: TextStyle(fontSize: 13, color: Color(0xFF444651))),
                  Row(children: const [
                    Icon(Icons.school_outlined, size: 14, color: Color(0xFF9D4300)),
                    SizedBox(width: 4),
                    Text('Accès restreint UIZ',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9D4300))),
                  ]),
                ]),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: const Color(0xFFDCE9FF), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  segment('Étudiant EST', Icons.person_outline, _student,
                      () => setState(() => _student = true)),
                  segment('Bureau du Club', Icons.shield_outlined, !_student,
                      () => setState(() => _student = false)),
                ]),
              ),
              const SizedBox(height: AppSpacing.md),
              // White form card, as in the Stitch login screen.
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Icon(Icons.lock_outline, color: _navy),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            _student ? 'Authentification Étudiant' : 'Authentification Bureau',
                            style: const TextStyle(fontWeight: FontWeight.w800))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: const Color(0xFFDCE9FF), borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.circle, size: 7, color: Color(0xFFF97316)),
                        const SizedBox(width: 5),
                        Text(_student ? 'Compte académique UIZ' : 'Accès bureau club',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700, color: _navy)),
                      ]),
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
                  const SizedBox(height: 6),
                  Row(children: const [
                    Icon(Icons.apartment, size: 14, color: AppColors.onSurfaceVariant),
                    SizedBox(width: 6),
                    Text('Terminaison requise : ',
                        style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                    Text('@edu.uiz.ac.ma',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 14),
                  label(
                      'Mot de passe',
                      GestureDetector(
                          onTap: () => context.push('/forgot-password'),
                          child: const Text('Mot de passe oublié ?',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700, color: _navy)))),
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
                    style: FilledButton.styleFrom(
                        backgroundColor: _navy, minimumSize: const Size.fromHeight(56)),
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.login),
                    label: Text(
                        _student ? 'Se connecter avec mon compte étudiant' : "Accéder à l'espace bureau",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                  const Text.rich(
                    TextSpan(children: [
                      TextSpan(text: "Problème d'accès ? Contacte le guichet :\n"),
                      TextSpan(
                          text: 'scolarite.est@uiz.ac.ma',
                          style: TextStyle(fontWeight: FontWeight.w700, color: _navy)),
                    ]),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF444651)),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              TextButton(
                  onPressed: () => context.push('/register'),
                  child: const Text('Créer un compte')),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.shield, size: 14, color: _navy),
                    SizedBox(width: 6),
                    Flexible(
                        child: Text('Authentification officielle CAS Université Ibn Zohr',
                            style: TextStyle(fontSize: 11, color: Color(0xFF444651)))),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                  'Protection des données conforme CNDP & charte numérique UIZ Agadir - EST Guelmim / Agadir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: cs.outline)),
            ]),
          ),
        ),
      ),
    );
  }
}
