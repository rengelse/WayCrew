import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String? apkUrl;
  final String? releaseName;
  final String? releaseNotes;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    this.apkUrl,
    this.releaseName,
    this.releaseNotes,
  });

  String get downloadUrl => apkUrl ?? releaseUrl;
}

class AppUpdateCheckResult {
  final String currentVersion;
  final AppUpdateInfo? update;

  const AppUpdateCheckResult({required this.currentVersion, this.update});

  bool get hasUpdate => update != null;
}

class AppUpdateService {
  static const _owner = 'rengelse';
  static const _repository = 'WayCrew';
  static const _latestReleaseUri =
      'https://api.github.com/repos/$_owner/$_repository/releases/latest';

  const AppUpdateService();

  Future<AppUpdateCheckResult> check() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final response = await http.get(
      Uri.parse(_latestReleaseUri),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'WayCrew-Android',
      },
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode == 404) {
      // No published GitHub release yet.
      return AppUpdateCheckResult(currentVersion: currentVersion);
    }
    if (response.statusCode != 200) {
      throw Exception('GitHub svarte med HTTP ${response.statusCode}.');
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Ugyldig svar fra GitHub.');
    }

    final tag = (body['tag_name'] as String? ?? '').trim();
    final latestVersion = _normalizeVersion(tag);
    if (latestVersion.isEmpty || !_isNewer(latestVersion, currentVersion)) {
      return AppUpdateCheckResult(currentVersion: currentVersion);
    }

    String? apkUrl;
    final assets = body['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) continue;
        final name = (asset['name'] as String? ?? '').toLowerCase();
        final url = asset['browser_download_url'] as String?;
        if (url != null && name.endsWith('.apk')) {
          apkUrl = url;
          if (name.contains('waycrew')) break;
        }
      }
    }

    final releaseUrl = body['html_url'] as String? ??
        'https://github.com/$_owner/$_repository/releases/latest';

    return AppUpdateCheckResult(
      currentVersion: currentVersion,
      update: AppUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        releaseUrl: releaseUrl,
        apkUrl: apkUrl,
        releaseName: body['name'] as String?,
        releaseNotes: body['body'] as String?,
      ),
    );
  }

  static String _normalizeVersion(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
      return trimmed.substring(1);
    }
    return trimmed;
  }

  static bool _isNewer(String candidate, String current) {
    final candidateParts = _numericParts(candidate);
    final currentParts = _numericParts(current);
    final length = candidateParts.length > currentParts.length
        ? candidateParts.length
        : currentParts.length;

    for (var i = 0; i < length; i++) {
      final a = i < candidateParts.length ? candidateParts[i] : 0;
      final b = i < currentParts.length ? currentParts[i] : 0;
      if (a > b) return true;
      if (a < b) return false;
    }
    return false;
  }

  static List<int> _numericParts(String version) {
    final core = version.split(RegExp(r'[-+]')).first;
    return core
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
