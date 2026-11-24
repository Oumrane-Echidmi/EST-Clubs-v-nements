import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/paged.dart';
import '../auth/presentation/auth_providers.dart';
import '../auth/presentation/login_screen.dart' show validatePassword;

const maxImageBytes = 5 * 1024 * 1024;

/// Same rules as the backend (JPG/PNG/WebP, max 5 MB). The server re-checks.
String? validateImage(String path, int bytes) {
  final ext = path.toLowerCase().split('.').last;
  if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
    return 'Format non supporté (JPG, PNG ou WebP)';
  }
  if (bytes > maxImageBytes) return 'Image trop lourde (5 Mo max)';
  return null;
}

/// ASSUMED endpoints from the prompt: PATCH /me, PATCH /me/password,
/// POST /uploads/image?kind=avatar|poster|logo (multipart field "file"; response
/// field "url" is an assumption).
class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;

  Future<void> update({String? fullName, String? studentId, String? avatarUrl}) =>
      guarded(() => _dio.patch('/me', data: {
            if (fullName != null) 'fullName': fullName,
            if (studentId != null) 'studentId': studentId,
            if (avatarUrl != null) 'avatarUrl': avatarUrl,
          }));

  Future<void> changePassword(String current, String next) => guarded(() =>
      _dio.patch('/me/password',
          data: {'currentPassword': current, 'newPassword': next}));

  /// Uploads an image and returns its URL. [onProgress] gets 0..1.
  Future<String> uploadImage(String kind, String path,
          {void Function(double)? onProgress}) =>
      guarded(() async {
        final form = FormData.fromMap({'file': await MultipartFile.fromFile(path)});
        final r = await _dio.post('/uploads/image',
            queryParameters: {'kind': kind},
            data: form,
            onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        });
        final d = (r.data['data'] ?? r.data) as Map;
        return '${d['url']}';
      });
}

final profileRepositoryProvider =
    Provider((ref) => ProfileRepository(ref.watch(dioProvider)));

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditState();
}

class _ProfileEditState extends ConsumerState<ProfileEditScreen> {
  late final _name =
      TextEditingController(text: ref.read(authStateProvider).user?.fullName);
  final _studentId = TextEditingController();
  double? _progress; // non-null while uploading
  String? _msg;
  bool _busy = false;

  Future<void> _pickAvatar() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f == null) return;
    final err = validateImage(f.path, await File(f.path).length());
    if (err != null) return setState(() => _msg = err);
    setState(() {
      _progress = 0;
      _msg = null;
    });
    try {
      final repo = ref.read(profileRepositoryProvider);
      final url = await repo.uploadImage('avatar', f.path,
          onProgress: (p) => mounted ? setState(() => _progress = p) : null);
      await repo.update(avatarUrl: url);
      if (mounted) setState(() => _msg = 'Avatar mis à jour');
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await ref.read(profileRepositoryProvider).update(
          fullName: _name.text.trim(),
          studentId: _studentId.text.trim().isEmpty ? null : _studentId.text.trim());
      if (mounted) setState(() => _msg = 'Profil enregistré');
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Modifier le profil')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Center(
              child: OutlinedButton.icon(
                  onPressed: _progress == null ? _pickAvatar : null,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Changer la photo'))),
          if (_progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _progress),
          ],
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom complet')),
          const SizedBox(height: 12),
          TextField(
              controller: _studentId,
              decoration: const InputDecoration(labelText: 'Numéro étudiant')),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_msg!)),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _busy ? null : _save, child: const Text('Enregistrer')),
        ]),
      );
}

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends ConsumerState<ChangePasswordScreen> {
  final _key = GlobalKey<FormState>();
  final _cur = TextEditingController();
  final _new = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy || !_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).changePassword(_cur.text, _new.text);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Changer le mot de passe')),
        body: Form(
          key: _key,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(
                controller: _cur,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: _new,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
                validator: validatePassword),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _submit, child: const Text('Modifier')),
          ]),
        ),
      );
}
