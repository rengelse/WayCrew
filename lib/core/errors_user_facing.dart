/// Converts known backend/client exceptions into concise user-facing text.
/// Raw exception strings are intentionally not shown in production UI.
String userFacingError(Object error, {required String fallback}) {
  final text = error.toString().toLowerCase();

  if (text.contains('network') ||
      text.contains('socketexception') ||
      text.contains('connection') ||
      text.contains('timeout')) {
    return 'Nettverksforbindelsen ser ut til å være utilgjengelig. Prøv igjen.';
  }
  if (text.contains('invalidjwttoken') || text.contains('token has expired')) {
    return 'Økten din må fornyes. Prøv igjen, eller logg inn på nytt.';
  }
  if (text.contains('permission') || text.contains('not authorized') || text.contains('forbidden')) {
    return 'Du har ikke tilgang til å utføre denne handlingen.';
  }
  if (text.contains('group_owner_required')) {
    return 'Bare gruppeeieren kan gjøre dette.';
  }
  if (text.contains('group_admin_required')) {
    return 'Bare gruppeeier eller administrator kan gjøre dette.';
  }
  if (text.contains('leader_required') || text.contains('activity_owner_required')) {
    return 'Bare turlederen kan gjøre dette.';
  }
  if (text.contains('participant_required')) {
    return 'Du er ikke lenger godkjent deltaker på aktiviteten.';
  }
  if (text.contains('activity_not_live')) {
    return 'Aktiviteten er ikke lenger aktiv.';
  }
  return fallback;
}
