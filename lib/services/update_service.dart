import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum UpdateStatus {
  upToDate,
  updateAvailable,
  error,
}

class UpdateCheckResult {
  final UpdateStatus status;
  final String storeName;
  final String currentVersion;
  final int currentBuild;
  final String? latestVersion;
  final String? releaseTitle;
  final String? releaseNotes;
  final String? downloadUrl;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.status,
    required this.storeName,
    required this.currentVersion,
    required this.currentBuild,
    this.latestVersion,
    this.releaseTitle,
    this.releaseNotes,
    this.downloadUrl,
    this.errorMessage,
  });
}

class UpdateService {
  static const String defaultPackageName = 'com.shamim.landmeasurement';
  static const String unexpectedError =
      'Something went wrong while checking for updates. Please try again later.';

  /// Performs an in-app check for updates via Google Play Store (Android) or Apple App Store (iOS).
  static Future<UpdateCheckResult> checkForUpdate() async {
    String currentVersion = '1.0.0';
    int currentBuild = 1;
    String packageName = defaultPackageName;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      currentVersion =
          packageInfo.version.isNotEmpty ? packageInfo.version : '1.0.0';
      currentBuild = int.tryParse(packageInfo.buildNumber) ?? 1;
      if (packageInfo.packageName.isNotEmpty) {
        packageName = packageInfo.packageName;
      }
    } catch (_) {}

    if (kIsWeb) {
      return UpdateCheckResult(
        status: UpdateStatus.upToDate,
        storeName: 'Web',
        currentVersion: currentVersion,
        currentBuild: currentBuild,
      );
    }

    if (Platform.isIOS || Platform.isMacOS) {
      return _checkAppleAppStore(
        packageName: packageName,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
      );
    } else {
      // Default to Google Play Store on Android and other platforms
      return _checkGooglePlayStore(
        packageName: packageName,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
      );
    }
  }

  /// Checks for updates on Apple App Store using official iTunes Lookup API.
  static Future<UpdateCheckResult> _checkAppleAppStore({
    required String packageName,
    required String currentVersion,
    required int currentBuild,
  }) async {
    const storeName = 'Apple App Store';
    final storeUrl =
        'https://apps.apple.com/app/lookup?bundleId=$packageName';

    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final uri = Uri.parse(
        'https://itunes.apple.com/lookup?bundleId=$packageName',
      );
      final request =
          await client.getUrl(uri).timeout(const Duration(seconds: 10));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)',
      );
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json',
      );

      final response =
          await request.close().timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data =
            jsonDecode(responseBody) as Map<String, dynamic>;

        final resultCount = data['resultCount'] as int? ?? 0;
        final results = data['results'] as List<dynamic>? ?? [];

        if (resultCount > 0 && results.isNotEmpty) {
          final firstResult = results[0] as Map<String, dynamic>;
          final String remoteVersionStr =
              (firstResult['version'] as String? ?? '').trim();
          final String trackViewUrl =
              (firstResult['trackViewUrl'] as String? ?? storeUrl).trim();
          final String releaseNotes =
              (firstResult['releaseNotes'] as String? ?? '').trim();
          final String trackName =
              (firstResult['trackName'] as String? ?? 'Encryptor').trim();
          // The lookup API rarely exposes a build number, but use it when present.
          final int? remoteBuild = int.tryParse(
            (firstResult['bundleVersion'] as String? ?? '').trim(),
          );

          if (remoteVersionStr.isEmpty) {
            // The store found the app but the payload carried no version.
            // Fail loudly instead of silently reporting "up to date".
            return UpdateCheckResult(
              status: UpdateStatus.error,
              storeName: storeName,
              currentVersion: currentVersion,
              currentBuild: currentBuild,
              errorMessage: unexpectedError,
            );
          }

          final bool hasNewer = _isNewerVersion(
            remoteVersionStr: remoteVersionStr,
            currentVersionStr: currentVersion,
            remoteBuild: remoteBuild,
            currentBuild: currentBuild,
          );

          if (hasNewer) {
            return UpdateCheckResult(
              status: UpdateStatus.updateAvailable,
              storeName: storeName,
              currentVersion: currentVersion,
              currentBuild: currentBuild,
              latestVersion: remoteVersionStr,
              releaseTitle: '$trackName v$remoteVersionStr',
              releaseNotes: releaseNotes.isNotEmpty
                  ? releaseNotes
                  : 'New version available on the $storeName.',
              downloadUrl: trackViewUrl,
            );
          } else {
            return UpdateCheckResult(
              status: UpdateStatus.upToDate,
              storeName: storeName,
              currentVersion: currentVersion,
              currentBuild: currentBuild,
              latestVersion: remoteVersionStr,
              downloadUrl: trackViewUrl,
            );
          }
        } else {
          // App not found on App Store yet; current installed version is latest
          return UpdateCheckResult(
            status: UpdateStatus.upToDate,
            storeName: storeName,
            currentVersion: currentVersion,
            currentBuild: currentBuild,
            downloadUrl: storeUrl,
          );
        }
      } else {
        return UpdateCheckResult(
          status: UpdateStatus.error,
          storeName: storeName,
          currentVersion: currentVersion,
          currentBuild: currentBuild,
          errorMessage:
              'Server responded with status code: ${response.statusCode}',
        );
      }
    } on SocketException {
      return UpdateCheckResult(
        status: UpdateStatus.error,
        storeName: storeName,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
        errorMessage:
            'Unable to connect to $storeName. Please check your internet connection.',
      );
    } on TimeoutException {
      return UpdateCheckResult(
        status: UpdateStatus.error,
        storeName: storeName,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
        errorMessage:
            'Connection to $storeName timed out. Please try again later.',
      );
    } catch (e) {
      return UpdateCheckResult(
        status: UpdateStatus.error,
        storeName: storeName,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
        errorMessage: unexpectedError,
      );
    } finally {
      client?.close();
    }
  }

  /// Checks for updates on Google Play Store.
  static Future<UpdateCheckResult> _checkGooglePlayStore({
    required String packageName,
    required String currentVersion,
    required int currentBuild,
  }) async {
    const storeName = 'Google Play Store';
    final storeUrl =
        'https://play.google.com/store/apps/details?id=$packageName';

    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final uri = Uri.parse('$storeUrl&hl=en');
      final request =
          await client.getUrl(uri).timeout(const Duration(seconds: 10));

      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      );
      request.headers.set(
          HttpHeaders.acceptHeader, 'text/html,application/xhtml+xml');

      final response =
          await request.close().timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();

        // Extract version from Google Play Store HTML payload
        final String? remoteVersion = _extractPlayStoreVersion(responseBody);

        if (remoteVersion != null && remoteVersion.isNotEmpty) {
          final bool hasNewer = _isNewerVersion(
            remoteVersionStr: remoteVersion,
            currentVersionStr: currentVersion,
          );

          if (hasNewer) {
            return UpdateCheckResult(
              status: UpdateStatus.updateAvailable,
              storeName: storeName,
              currentVersion: currentVersion,
              currentBuild: currentBuild,
              latestVersion: remoteVersion,
              releaseTitle: 'Version $remoteVersion on Google Play',
              releaseNotes:
                  'A newer version ($remoteVersion) is available on $storeName.',
              downloadUrl: storeUrl,
            );
          } else {
            return UpdateCheckResult(
              status: UpdateStatus.upToDate,
              storeName: storeName,
              currentVersion: currentVersion,
              currentBuild: currentBuild,
              latestVersion: remoteVersion,
              downloadUrl: storeUrl,
            );
          }
        } else {
          // The page loaded but no version could be parsed: the store payload
          // changed. Report a failed check rather than a false "up to date".
          return UpdateCheckResult(
            status: UpdateStatus.error,
            storeName: storeName,
            currentVersion: currentVersion,
            currentBuild: currentBuild,
            errorMessage: unexpectedError,
          );
        }
      } else if (response.statusCode == 404) {
        // App listing not found (e.g. unpublished/testing); current version is up to date
        return UpdateCheckResult(
          status: UpdateStatus.upToDate,
          storeName: storeName,
          currentVersion: currentVersion,
          currentBuild: currentBuild,
          downloadUrl: storeUrl,
        );
      } else {
        return UpdateCheckResult(
          status: UpdateStatus.error,
          storeName: storeName,
          currentVersion: currentVersion,
          currentBuild: currentBuild,
          errorMessage:
              'Server responded with status code: ${response.statusCode}',
        );
      }
    } on SocketException {
      return UpdateCheckResult(
        status: UpdateStatus.error,
        storeName: storeName,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
        errorMessage:
            'Unable to connect to $storeName. Please check your internet connection.',
      );
    } on TimeoutException {
      return UpdateCheckResult(
        status: UpdateStatus.error,
        storeName: storeName,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
        errorMessage:
            'Connection to $storeName timed out. Please try again later.',
      );
    } catch (e) {
      return UpdateCheckResult(
        status: UpdateStatus.error,
        storeName: storeName,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
        errorMessage: unexpectedError,
      );
    } finally {
      client?.close();
    }
  }

  /// Extracts version string from Google Play Store HTML.
  static String? _extractPlayStoreVersion(String html) {
    // Pattern 1: Play Store modern payload: [[["2.5"]]
    final pattern1 = RegExp(r'\[\[\["([0-9]+(?:\.[0-9]+)+)"\]\]');
    final match1 = pattern1.firstMatch(html);
    if (match1 != null) {
      return match1.group(1);
    }

    // Pattern 2: Payload key ds:5 format: ]]],"1.0.1",null
    final pattern2 = RegExp(r'\]\]\],\s*"([0-9]+(?:\.[0-9]+)+)"\s*,\s*null');
    final match2 = pattern2.firstMatch(html);
    if (match2 != null) {
      return match2.group(1);
    }

    // Pattern 3: itemprop softwareVersion
    final pattern3 = RegExp(
      r'itemprop="softwareVersion">\s*([0-9]+(?:\.[0-9]+)+)\s*<',
    );
    final match3 = pattern3.firstMatch(html);
    if (match3 != null) {
      return match3.group(1);
    }

    // Pattern 4: Generic JSON array format: ["1.0.1", [
    final pattern4 = RegExp(r'\["([0-9]+(?:\.[0-9]+)+)",\s*\[');
    final match4 = pattern4.firstMatch(html);
    if (match4 != null) {
      return match4.group(1);
    }

    return null;
  }

  /// Compares the store version against the installed one.
  ///
  /// When the version names are equal, the build numbers decide if both are
  /// known. Neither the App Store lookup API nor the Play Store page exposes a
  /// build number, so in practice this is a version-name comparison and a
  /// release that only bumps `versionCode` cannot be detected.
  static bool _isNewerVersion({
    required String remoteVersionStr,
    required String currentVersionStr,
    int? remoteBuild,
    int? currentBuild,
  }) {
    if (remoteVersionStr.isEmpty) return false;

    final remoteParts = _parseVersionParts(remoteVersionStr);
    final currentParts = _parseVersionParts(currentVersionStr);

    final maxLen = remoteParts.length > currentParts.length
        ? remoteParts.length
        : currentParts.length;

    for (int i = 0; i < maxLen; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;

      if (r > c) return true;
      if (r < c) return false;
    }

    // Same version name: a newer build of the same version is still an update.
    if (remoteBuild != null && currentBuild != null) {
      return remoteBuild > currentBuild;
    }

    return false;
  }

  static List<int> _parseVersionParts(String version) {
    return version
        .split('.')
        .map((part) => int.tryParse(RegExp(r'\d+').stringMatch(part) ?? '0') ?? 0)
        .toList();
  }
}
