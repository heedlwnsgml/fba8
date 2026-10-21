import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/planner_api.dart';
import '../../../core/router/app_router.dart';

class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key, this.api});
  final PlannerApi? api;
  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  String? _gender;
  String? _age;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = widget.api ?? PlannerApi.instance;
      if (_signup) {
        final message = await api.signup(
          email: _email.text,
          password: _password.text,
          gender: _gender!,
          ageGroup: _age!,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        _form.currentState?.reset();
        _email.clear();
        _password.clear();
        setState(() {
          _signup = false;
          _gender = null;
          _age = null;
          _error = null;
        });
      } else {
        await api.login(_email.text, _password.text);
        if (!mounted) return;
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '여행 플래너',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(_signup ? '회원가입' : '이메일로 로그인'),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: '이메일'),
                      validator: (v) => v != null && v.trim().contains('@')
                          ? null
                          : '이메일을 입력하세요.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '비밀번호'),
                      validator: (v) =>
                          v != null && v.length >= 8 ? null : '8자 이상 입력하세요.',
                    ),
                    if (_signup) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: const InputDecoration(labelText: '성별'),
                        validator: (v) => v == null ? '성별을 선택하세요.' : null,
                        items: ['남성', '여성']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _gender = v),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _age,
                        decoration: const InputDecoration(labelText: '연령대'),
                        validator: (v) => v == null ? '연령대를 선택하세요.' : null,
                        items: ['10대', '20대', '30대', '40대', '50대', '60대 이상']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _age = v),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy
                            ? '처리 중...'
                            : _signup
                            ? '회원가입'
                            : '로그인',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _form.currentState?.reset();
                              _email.clear();
                              _password.clear();
                              _gender = null;
                              _age = null;
                              _signup = !_signup;
                              _error = null;
                            }),
                      child: Text(_signup ? '로그인으로 돌아가기' : '새 계정 만들기'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
