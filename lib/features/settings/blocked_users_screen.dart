import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_widgets.dart';
import '../../data/providers.dart';
import '../../core/errors_user_facing.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blockedUsersProvider);
    final repository = ref.watch(safetyRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/settings'),
        title: const Text('Blokkerte brukere'),
      ),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Message(
            icon: Icons.error_outline,
            title: 'Kunne ikke hente blokkerte brukere',
            body: userFacingError(error, fallback: 'Kunne ikke hente blokkerte brukere.'),
          ),
          data: (items) {
            if (repository == null) {
              return const _Message(
                icon: Icons.shield_outlined,
                title: 'Krever innlogging',
                body: 'Blokkering lagres på WayCrew-kontoen din når du er innlogget.',
              );
            }
            if (items.isEmpty) {
              return const _Message(
                icon: Icons.person_off_outlined,
                title: 'Ingen blokkerte brukere',
                body: 'Brukere du blokkerer fra deltakerlisten vises her.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(_initial(item.displayName))),
                    title: Text(item.displayName),
                    subtitle: Text('Blokkert ${_date(item.blockedAt)}'),
                    trailing: TextButton(
                      onPressed: () async {
                        try {
                          await repository.unblockUser(item.userId);
                          ref.invalidate(blockedUsersProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Blokkeringen er fjernet.')));
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingError(error, fallback: 'Kunne ikke oppheve blokkeringen. Prøv igjen.'))));
                          }
                        }
                      },
                      child: const Text('Opphev'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  static String _initial(String name) => name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
  static String _date(DateTime date) => '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Message({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
          ]),
        ),
      );
}
