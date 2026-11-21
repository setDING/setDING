import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drift/drift.dart' hide Column;

import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../sync/auth_providers.dart';
import '../../sync/sync_backend.dart';
import '../widgets/dialogs.dart';
import 'sign_in_screen.dart' show backendErrorText;

/// Names of the organizations on this device in which [userId] is the only
/// admin; the server refuses deleting the account while there are any
/// (ADR-0052). The server checks again.
Future<List<String>> soleAdminOrganizations(
  AppDatabase db,
  String userId,
) async {
  final names = <String>[];
  for (final org in await (db.select(
    db.organizations,
  )..where((o) => o.deleted.equals(false))).get()) {
    final admins =
        await (db.select(db.orgMemberships)..where(
              (m) =>
                  m.organizationId.equals(org.id) &
                  m.role.equalsValue(OrgRole.admin),
            ))
            .get();
    if (admins.length == 1 && admins.single.userId == userId) {
      names.add(org.name);
    }
  }
  return names;
}

/// Deletes the account of the signed-in user after a confirmation with the
/// password (ADR-0052). Returns true when it was deleted.
Future<bool> showDeleteAccountDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final user = ref.read(authProvider);
  if (user == null) return false;
  final blocking = await soleAdminOrganizations(
    ref.read(databaseProvider),
    user.id,
  );
  if (!context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        builder: (_) => DeleteAccountDialog(soleAdminOf: blocking),
      ) ??
      false;
}

class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key, this.soleAdminOf = const []});

  /// Organizations the person must hand over or close first.
  final List<String> soleAdminOf;

  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _password.text.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).deleteAccount(_password.text);
      if (mounted) Navigator.pop(context, true);
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.kind == BackendErrorKind.invalidCredentials
            ? l10n.accountPasswordWrongCurrent
            : backendErrorText(l10n, e.kind);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final blocked = widget.soleAdminOf.isNotEmpty;
    return AlertDialog(
      title: Text(l10n.accountDeleteTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (blocked) ...[
                Text(l10n.accountDeleteSoleAdmin),
                const SizedBox(height: 8),
                for (final name in widget.soleAdminOf)
                  Text(
                    '• $name',
                    key: const Key('delete-account-blocking'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ] else ...[
                Text(l10n.accountDeleteMessage),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('delete-account-password'),
                  controller: _password,
                  autofocus: true,
                  obscureText: !_showPassword,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: l10n.accountPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      tooltip: _showPassword
                          ? l10n.accountPasswordHide
                          : l10n.accountPasswordShow,
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  autofillHints: const [AutofillHints.password],
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    key: const Key('delete-account-error'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(blocked ? l10n.close : l10n.cancel),
        ),
        if (!blocked)
          FilledButton(
            key: const Key('delete-account-confirm'),
            style: destructiveButtonStyle(context),
            onPressed: _busy || _password.text.isEmpty ? null : _submit,
            child: Text(l10n.accountDelete),
          ),
      ],
    );
  }
}
