import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../core/app_config.dart';

class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  /// 현재 사용자 정보 가져오기
  static UserModel? get currentUser {
    if (AppConfig.demoMode) {
      return UserModel(id: 'demo', name: '체험 사용자', email: '로컬 데모 · 계정 연결 없음');
    }
    final user = _auth.currentUser;
    if (user == null) return null;

    return UserModel(
      id: user.uid,
      name: user.displayName ?? '사용자',
      email: user.email ?? '',
    );
  }

  /// 인증 상태 변경 스트림
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 로그인 로직
  static Future<UserModel?> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        return currentUser;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw '알 수 없는 오류가 발생했습니다.';
    }
  }

  /// 회원가입 로직
  static Future<UserModel?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (name.trim().isEmpty || name.trim().length > 50) {
      throw '이름은 1~50자로 입력해주세요.';
    }
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await credential.user!.updateDisplayName(name.trim());
        await credential.user!.reload();
        return currentUser;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw '알 수 없는 오류가 발생했습니다.';
    }
  }

  /// 로그아웃 로직
  static Future<void> logout() async {
    if (AppConfig.demoMode) return;
    await _auth.signOut();
  }

  /// 현재 로그인 여부 확인
  static bool get isLoggedIn =>
      !AppConfig.demoMode && _auth.currentUser != null;

  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// 닉네임 변경
  static Future<void> updateNickname(String nickname) async {
    final user = _auth.currentUser;
    if (user == null) throw '로그인이 필요합니다.';
    if (nickname.trim().isEmpty) throw '닉네임을 입력해주세요.';
    if (nickname.trim().length > 50) throw '닉네임은 50자 이내로 입력해주세요.';

    try {
      await user.updateDisplayName(nickname);
      await user.reload();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw '닉네임 변경에 실패했습니다.';
    }
  }

  /// 비밀번호 변경
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw '로그인이 필요합니다.';
    if (newPassword.length < 6) throw '새 비밀번호는 최소 6자 이상이어야 합니다.';

    try {
      // 재인증 필요
      final email = user.email;
      if (email == null) throw '이메일 정보를 찾을 수 없습니다.';

      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw '비밀번호 변경에 실패했습니다.';
    }
  }

  /// Firebase 인증 에러 메시지 한국어 변환 보강
  static String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      case 'user-not-found':
        return '등록되지 않은 이메일입니다.';
      case 'wrong-password':
        return '현재 비밀번호가 올바르지 않습니다.';
      case 'email-already-in-use':
        return '이미 가입된 이메일입니다.';
      case 'invalid-email':
        return '유효하지 않은 이메일 형식입니다.';
      case 'weak-password':
        return '새 비밀번호가 너무 약합니다.';
      case 'user-disabled':
        return '비활성화된 계정입니다.';
      case 'too-many-requests':
        return '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.';
      case 'operation-not-allowed':
        return '허용되지 않은 작업입니다.';
      case 'network-request-failed':
        return '네트워크 연결이 원활하지 않습니다.';
      case 'requires-recent-login':
        return '보안을 위해 다시 로그인한 뒤 시도해주세요.';
      case 'no-such-provider':
        return '소셜 로그인 계정은 앱에서 비밀번호를 변경할 수 없습니다.';
      default:
        // 비밀번호 변경 시 소셜 계정 체크를 위한 추가 처리
        if (e.message != null &&
            e.message!.contains('this operation is sensitive')) {
          return '보안을 위해 다시 로그인한 뒤 시도해주세요.';
        }
        return e.message ?? '인증 오류가 발생했습니다.';
    }
  }
}
