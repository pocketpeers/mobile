import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/remote_image.dart';
import '../../core/validators.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../groups/join_group_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final reputation = ref.watch(myReputationProvider);
    final badges = ref.watch(myBadgesProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final remindersEnabled = ref.watch(remindersEnabledProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: profile.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session?.username ?? 'Usuario'),
                    const Text('No se pudo cargar el perfil'),
                  ],
                ),
                data: (item) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        RemoteAvatar(
                          imageRef: item.photo,
                          fallbackIcon: Icons.person_outline,
                          size: 48,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.fullName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              Text(item.email),
                              Text(item.phoneNumber),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) =>
                              _EditProfileDialog(profile: item),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar perfil'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          reputation.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => const Card(
              child: ListTile(title: Text('No se pudo cargar el score')),
            ),
            data: (item) => item == null
                ? const SizedBox.shrink()
                : _ReputationCard(reputation: item),
          ),
          const SizedBox(height: 16),
          badges.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => const Card(
              child: ListTile(title: Text('No se pudieron cargar badges')),
            ),
            data: (items) => _BadgesCard(badges: items),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.group_add_outlined,
                      color: AppColors.blue),
                  title: const Text('Unirme a un grupo'),
                  subtitle: const Text('Ingresa el codigo de invitacion'),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => const JoinGroupDialog(),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Recordatorios de pago'),
                  subtitle: const Text(
                      'Se calculan localmente desde las fechas limite'),
                  value: remindersEnabled,
                  onChanged: (value) async {
                    ref.read(remindersEnabledProvider.notifier).state = value;
                    if (value) {
                      await ref.read(reminderServiceProvider).initialize();
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.help_outline, color: AppColors.blue),
                  title: const Text('Ayuda'),
                  subtitle: const Text('Ver nuevamente el onboarding'),
                  onTap: () => context.push('/onboarding'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.green),
                  title: const Text('Cerrar sesion'),
                  onTap: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (context.mounted) context.go('/auth');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends ConsumerStatefulWidget {
  const _EditProfileDialog({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  String _photo = '';
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final parts = widget.profile.fullName.trim().split(RegExp(r'\s+'));
    _firstName = TextEditingController(text: parts.isEmpty ? '' : parts.first);
    _lastName = TextEditingController(
        text: parts.length <= 1 ? '' : parts.sublist(1).join(' '));
    _phone = TextEditingController(text: widget.profile.phoneNumber);
    _email = TextEditingController(text: widget.profile.email);
    _photo = widget.profile.photo;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar perfil'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RemoteAvatar(
                  imageRef: _photo,
                  fallbackIcon: Icons.person_outline,
                  size: 64,
                  borderRadius: 32,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Actualizar foto'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: nameField,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Apellido'),
                  validator: nameField,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Telefono'),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  validator: phoneField,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: emailField,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => context.pop(),
            child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final uploaded = await ref.read(apiProvider).uploadImage(image.path);
    setState(() => _photo = uploaded.imageId);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).updateMyProfile(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            phoneNumber: _phone.text.trim(),
            photo: _photo,
            email: _email.text.trim(),
          );
      ref.invalidate(profileProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ReputationCard extends StatelessWidget {
  const _ReputationCard({required this.reputation});

  final Reputation reputation;

  @override
  Widget build(BuildContext context) {
    final progress = reputation.score / 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium_outlined,
                    color: AppColors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Score de reputacion',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text('${reputation.score}/100',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress.clamp(0, 1).toDouble()),
            const SizedBox(height: 12),
            Text(reputation.level,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
            Text(reputation.levelDescription),
            if (reputation.pointsToNextLevel > 0)
              Text(
                  'Faltan ${reputation.pointsToNextLevel} puntos para el siguiente nivel'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('Racha: ${reputation.onTimePaymentStreak}')),
                Chip(label: Text('Pagos: ${reputation.completedPayments}')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgesCard extends StatelessWidget {
  const _BadgesCard({required this.badges});

  final List<PblBadge> badges;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Badges', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (badges.isEmpty)
              const Text('Aun no hay badges disponibles')
            else
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.35,
                children: [
                  for (final badge in badges)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: badge.unlocked
                            ? AppColors.green.withOpacity(0.10)
                            : Colors.grey.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: badge.unlocked
                              ? AppColors.green
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            badge.unlocked
                                ? Icons.verified_outlined
                                : Icons.lock_outline,
                            color:
                                badge.unlocked ? AppColors.green : Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            badge.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            badge.unlocked && badge.unlockedAt != null
                                ? formatDate(badge.unlockedAt)
                                : badge.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
