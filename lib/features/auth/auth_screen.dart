import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_environment.dart';
import 'auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(authControllerProvider.notifier);
    if (_register) {
      await controller.signUp(_name.text, _email.text, _password.text);
    } else {
      await controller.signIn(_email.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(Icons.route_rounded, color: theme.colorScheme.onPrimary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(_register ? 'Opprett konto' : 'Velkommen tilbake', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    _register
                        ? 'Lag profilen som skal brukes på aktiviteter og i grupper.'
                        : 'Logg inn for å bruke den nye Supabase-backenden.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Logg inn')),
                      ButtonSegment(value: true, label: Text('Ny konto')),
                    ],
                    selected: {_register},
                    onSelectionChanged: state.loading ? null : (value) => setState(() {
                      _register = value.first;
                      ref.read(authControllerProvider.notifier).clearMessage();
                    }),
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (_register) ...[
                          TextFormField(
                            controller: _name,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(labelText: 'Navn', prefixIcon: Icon(Icons.person_outline)),
                            validator: (value) => (value == null || value.trim().length < 2) ? 'Skriv inn navnet ditt.' : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(labelText: 'E-post', prefixIcon: Icon(Icons.mail_outline)),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            return (!email.contains('@') || !email.contains('.')) ? 'Skriv inn en gyldig e-postadresse.' : null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) { if (!state.loading) _submit(); },
                          decoration: InputDecoration(
                            labelText: 'Passord',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _hidePassword = !_hidePassword),
                              icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                          ),
                          validator: (value) => (value == null || value.length < 8) ? 'Bruk minst 8 tegn.' : null,
                        ),
                      ],
                    ),
                  ),
                  if (state.message != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: state.error ? theme.colorScheme.errorContainer : theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(state.message!, style: TextStyle(color: state.error ? theme.colorScheme.onErrorContainer : theme.colorScheme.onSecondaryContainer)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: state.loading ? null : _submit,
                    icon: state.loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(_register ? Icons.person_add_alt_1 : Icons.login),
                    label: Text(_register ? 'Opprett konto' : 'Logg inn'),
                  ),
                  if (!_register)
                    TextButton(
                      onPressed: state.loading ? null : () {
                        final email = _email.text.trim();
                        if (email.contains('@')) {
                          ref.read(authControllerProvider.notifier).resetPassword(email);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skriv inn e-postadressen først.')));
                        }
                      },
                      child: const Text('Glemt passord?'),
                    ),
                  if (AppEnvironment.isDevelopment) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: state.loading ? null : () => ref.read(localDemoModeProvider.notifier).state = true,
                      icon: const Icon(Icons.science_outlined),
                      label: const Text('Fortsett i lokal demo'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Utviklingsmodus: lokal demo bruker fortsatt isolerte mockdata. Ekte konto bruker Supabase for profil, aktiviteter, grupper, chat og live tracking.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
