import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:bp2/core/app_config.dart';
import 'package:bp2/main.dart' as application;

/// Opt-in, read-only device check. Never logs credentials or document contents.
Future<void> main() async {
  if (!const bool.fromEnvironment('RUN_APP_CHECK_PROBE') ||
      AppConfig.demoMode ||
      const String.fromEnvironment('EXPECTED_FIREBASE_PROJECT').isEmpty) {
    throw StateError('Explicit connected-mode probe flags required');
  }
  await application.main();
  final report = <String, Object?>{};
  try {
    if (Firebase.app().options.projectId !=
        const String.fromEnvironment('EXPECTED_FIREBASE_PROJECT')) {
      throw StateError('Unexpected Firebase project');
    }
    final token = await FirebaseAppCheck.instance.getToken(true);
    report['playIntegrityTokenIssued'] = token != null && token.isNotEmpty;
    if (token == null || token.isEmpty) {
      throw StateError('Missing App Check token');
    }
    final claims =
        jsonDecode(
              utf8.decode(
                base64Url.decode(base64Url.normalize(token.split('.')[1])),
              ),
            )
            as Map<String, dynamic>;
    report['appIdMatches'] = claims['sub'] == Firebase.app().options.appId;
    report['expiresAt'] = claims['exp'];
    final user = FirebaseAuth.instance.currentUser;
    report['signedIn'] = user != null;
    if (user != null) {
      final idToken = await user.getIdToken(true);
      report['authRefreshSucceeded'] = idToken != null && idToken.isNotEmpty;
      await FirebaseFirestore.instance
          .collection('posts')
          .where('deleted', isEqualTo: false)
          .limit(1)
          .get(const GetOptions(source: Source.server));
      report['firestoreServerReadSucceeded'] = true;
      if (idToken != null) {
        final options = Firebase.app().options;
        final endpoint = Uri.https(
          'firestore.googleapis.com',
          '/v1/projects/${options.projectId}/databases/(default)/documents:runQuery',
        );
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 20);
        try {
          for (final includeAppCheck in [true, false]) {
            final request = await client.postUrl(endpoint);
            request.headers.contentType = ContentType.json;
            request.headers.set('Authorization', 'Bearer $idToken');
            if (includeAppCheck) {
              request.headers.set('X-Firebase-AppCheck', token);
            }
            request.write(
              jsonEncode({
                'structuredQuery': {
                  'select': {
                    'fields': [
                      {'fieldPath': '__name__'},
                    ],
                  },
                  'from': [
                    {'collectionId': 'posts'},
                  ],
                  'where': {
                    'fieldFilter': {
                      'field': {'fieldPath': 'deleted'},
                      'op': 'EQUAL',
                      'value': {'booleanValue': false},
                    },
                  },
                  'limit': 1,
                },
              }),
            );
            final response = await request.close().timeout(
              const Duration(seconds: 25),
            );
            report[includeAppCheck
                    ? 'firestoreRestWithAppCheckHttp'
                    : 'firestoreRestWithoutAppCheckHttp'] =
                response.statusCode;
            await response.drain<void>();
          }
          report['firestoreMissingAppCheckBlocked'] =
              report['firestoreRestWithAppCheckHttp'] == 200 &&
              report['firestoreRestWithoutAppCheckHttp'] == 403;
          final signInEndpoint = Uri.https(
            'identitytoolkit.googleapis.com',
            '/v1/accounts:signInWithPassword',
            {'key': options.apiKey},
          );
          // A unique reserved-domain identity never touches an existing account.
          final nonce =
              '${DateTime.now().microsecondsSinceEpoch}'
              '${Random.secure().nextInt(1 << 32)}';
          final invalidCredentials = {
            'email': 'app-check-$nonce@example.invalid',
            'password': nonce,
            'returnSecureToken': true,
          };
          for (final includeAppCheck in [true, false]) {
            final request = await client.postUrl(signInEndpoint);
            request.headers.contentType = ContentType.json;
            request.headers.set('X-Firebase-GMPID', options.appId);
            if (includeAppCheck) {
              request.headers.set('X-Firebase-AppCheck', token);
            }
            request.write(jsonEncode(invalidCredentials));
            final response = await request.close().timeout(
              const Duration(seconds: 25),
            );
            report[includeAppCheck
                    ? 'authSignInWithAppCheckHttp'
                    : 'authSignInWithoutAppCheckHttp'] =
                response.statusCode;
            final body = await utf8.decoder.bind(response).join();
            final error = (jsonDecode(body) as Map<String, dynamic>)['error'];
            final message = error is Map ? error['message'] : null;
            report[includeAppCheck
                    ? 'authSignInWithAppCheckResult'
                    : 'authSignInWithoutAppCheckResult'] =
                message == 'INVALID_LOGIN_CREDENTIALS'
                ? 'INVALID_LOGIN_CREDENTIALS'
                : message == 'Firebase App Check token is invalid.'
                ? 'APP_CHECK_TOKEN_INVALID'
                : 'unexpected-response';
          }
          report['authMissingAppCheckBlocked'] =
              report['authSignInWithAppCheckHttp'] == 400 &&
              report['authSignInWithAppCheckResult'] ==
                  'INVALID_LOGIN_CREDENTIALS' &&
              report['authSignInWithoutAppCheckHttp'] == 401 &&
              report['authSignInWithoutAppCheckResult'] ==
                  'APP_CHECK_TOKEN_INVALID';
        } finally {
          client.close(force: true);
        }
      }
    }
    report['success'] = report['appIdMatches'] == true;
  } on FirebaseException catch (error) {
    report['success'] = false;
    report['errorPlugin'] = error.plugin;
    report['errorCode'] = error.code;
  } catch (_) {
    report['success'] = false;
    report['errorCode'] = 'probe-failed';
  }
  // ignore: avoid_print
  print('APP_CHECK_PROBE ${jsonEncode(report)}');
}
