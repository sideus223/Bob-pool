import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/common_text_field.dart';
import '../widgets/common_button.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isNicknameLoading = false;
  bool _isPasswordLoading = false;

  @override
  void initState() {
    super.initState();
    _nicknameController.text = AuthService.currentUser?.name ?? "";
  }

  Future<void> _handleUpdateNickname() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('새 닉네임을 입력해주세요.')));
      return;
    }

    setState(() => _isNicknameLoading = true);
    try {
      await AuthService.updateNickname(nickname);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('닉네임이 변경되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isNicknameLoading = false);
      }
    }
  }

  Future<void> _handleChangePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 비밀번호 필드를 입력해주세요.')));
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('새 비밀번호가 일치하지 않습니다.')));
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('새 비밀번호는 6자 이상이어야 합니다.')));
      return;
    }

    setState(() => _isPasswordLoading = true);
    try {
      await AuthService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (mounted) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('비밀번호가 변경되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isPasswordLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '계정 설정',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF32201C),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle('닉네임 변경'),
            const SizedBox(height: 16),
            CommonTextField(hintText: '새 닉네임', controller: _nicknameController),
            const SizedBox(height: 16),
            _isNicknameLoading
                ? const Center(child: CircularProgressIndicator())
                : CommonButton(
                    text: '닉네임 변경',
                    onPressed: _handleUpdateNickname,
                  ),
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 40),
            _buildSectionTitle('비밀번호 변경'),
            const SizedBox(height: 16),
            CommonTextField(
              hintText: '현재 비밀번호',
              controller: _currentPasswordController,
              isPassword: true,
            ),
            const SizedBox(height: 12),
            CommonTextField(
              hintText: '새 비밀번호 (6자 이상)',
              controller: _newPasswordController,
              isPassword: true,
            ),
            const SizedBox(height: 12),
            CommonTextField(
              hintText: '새 비밀번호 확인',
              controller: _confirmPasswordController,
              isPassword: true,
            ),
            const SizedBox(height: 24),
            _isPasswordLoading
                ? const Center(child: CircularProgressIndicator())
                : CommonButton(
                    text: '비밀번호 변경',
                    onPressed: _handleChangePassword,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF32201C),
      ),
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
