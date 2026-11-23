import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../sync/auth_providers.dart';
import '../../sync/sync_backend.dart';
import '../widgets/dialogs.dart';
import 'sign_in_screen.dart' show backendErrorText;

/// The controllers of first name, last name and nickname (ADR-0062).
class PersonNameControllers {
  PersonNameControllers([PersonName initial = const PersonName()])
    : first = TextEditingController(text: initial.firstName),
      last = TextEditingController(text: initial.lastName),
      nickname = TextEditingController(text: initial.nickname);

  final TextEditingController first;
  final TextEditingController last;
  final TextEditingController nickname;

  PersonName get value => PersonName(
    firstName: first.text.trim(),
    lastName: last.text.trim(),
    nickname: nickname.text.trim(),
  );

  void dispose() {
    first.dispose();
    last.dispose();
    nickname.dispose();
  }
}

/// First name and last name (required) and the nickname (optional) of an
/// account (ADR-0062), for sign-up and for changing the name. Validated by
/// the surrounding [Form].
class PersonNameFields extends StatelessWidget {
  const PersonNameFields({
    super.key,
    required this.controllers,
    this.autofocus = false,
  });

  final PersonNameControllers controllers;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String? required(String? v) =>
        v == null || v.trim().isEmpty ? l10n.accountFieldRequired : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const Key('account-first-name'),
          controller: controllers.first,
          autofocus: autofocus,
          decoration: InputDecoration(labelText: l10n.accountFirstName),
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.givenName],
          maxLength: 100,
          buildCounter: _noCounter,
          validator: required,
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const Key('account-last-name'),
          controller: controllers.last,
          decoration: InputDecoration(labelText: l10n.accountLastName),
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.familyName],
          maxLength: 100,
          buildCounter: _noCounter,
          validator: required,
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const Key('account-nickname'),
          controller: controllers.nickname,
          decoration: InputDecoration(
            labelText: l10n.accountNickname,
            helperText: l10n.accountNameHint,
            helperMaxLines: 3,
          ),
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.nickname],
          maxLength: 100,
          buildCounter: _noCounter,
        ),
      ],
    );
  }

  static Widget? _noCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;
}

/// Asks for first name, last name and nickname of the signed-in user and
/// saves them (ADR-0062). With [required] (an account without a full name)
/// the dialog cannot be dismissed and only offers saving. Returns whether
/// the names were saved.
Future<bool> showChangeNameDialog(
  BuildContext context, {
  bool required = false,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: !required,
      builder: (_) => _ChangeNameDialog(required: required),
    ) ??
    false;

class _ChangeNameDialog extends ConsumerStatefulWidget {
  const _ChangeNameDialog({required this.required});

  final bool required;

  @override
  ConsumerState<_ChangeNameDialog> createState() => _ChangeNameDialogState();
}

class _ChangeNameDialogState extends ConsumerState<_ChangeNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _names = PersonNameControllers(
    ref.read(authProvider)?.person ?? const PersonName(),
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _names.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(syncBackendProvider).changeName(_names.value);
      if (mounted) Navigator.pop(context, true);
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = backendErrorText(l10n, e.kind);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !widget.required,
      child: AlertDialog(
        title: Text(
          widget.required ? l10n.accountCompleteName : l10n.accountChangeName,
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.required) ...[
                    Text(l10n.accountCompleteNameMessage),
                    const SizedBox(height: 16),
                  ],
                  PersonNameFields(controllers: _names, autofocus: true),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (!widget.required)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
          FilledButton(
            key: const Key('account-name-save'),
            onPressed: _busy ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

/// Shown once after sign-in when the account lacks a first or last name
/// (an account from before ADR-0062): asks for it until it is saved.
class CompleteNamePrompt extends ConsumerStatefulWidget {
  const CompleteNamePrompt({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CompleteNamePrompt> createState() => _CompleteNamePromptState();
}

class _CompleteNamePromptState extends ConsumerState<CompleteNamePrompt> {
  bool _asking = false;

  void _check(AuthUser? user) {
    if (_asking || user == null || !user.needsFullName) return;
    _asking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      final l10n = AppLocalizations.of(context);
      final saved = await showChangeNameDialog(context, required: true);
      _asking = false;
      if (saved && messenger != null) {
        showMessageOn(messenger, l10n.accountNameChanged);
      }
      // Signed out or still incomplete (e.g. a failed save): ask again.
      if (mounted) _check(ref.read(authProvider));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, user) => _check(user));
    _check(ref.read(authProvider));
    return widget.child;
  }
}

/// The label of [format] in the settings (ADR-0062).
String nameFormatLabel(AppLocalizations l10n, NameFormat format) =>
    switch (format) {
      NameFormat.nickname => l10n.nameFormatNickname,
      NameFormat.firstLast => l10n.nameFormatFirstLast,
      NameFormat.lastFirst => l10n.nameFormatLastFirst,
      NameFormat.fullWithNickname => l10n.nameFormatFullWithNickname,
    };
