import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';

/// UI fixture only. This creates no account and makes no Firebase server calls.
Future<void> prepareMainModePreview() async {
  setupFirebaseCoreMocks();
  await Firebase.initializeApp();
  FirebaseAuthPlatform.instance = _PreviewAuth();
}

class _PreviewAuth extends FirebaseAuthPlatform {
  late final UserPlatform _user = _PreviewUser(this);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform get currentUser => _user;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream.value(_user);
}

class _PreviewUser extends UserPlatform {
  _PreviewUser(FirebaseAuthPlatform auth)
    : super(
        auth,
        _PreviewMultiFactor(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'readme-preview-user',
            displayName: '밥풀',
            email: 'bobpool@example.com',
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: [],
        ),
      );
}

class _PreviewMultiFactor extends MultiFactorPlatform {
  _PreviewMultiFactor(super.auth);
}
