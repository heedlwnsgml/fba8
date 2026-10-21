import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/planner_api.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  Map<String, dynamic>? _ticket;
  bool _preparing = false, _polling = false;
  int _attempt = 0;
  @override
  void dispose() {
    _attempt++;
    final ticket = _ticket;
    if (ticket != null)
      unawaited(
        PlannerApi.instance.cancelSocialLogin(ticket).catchError((_) {}),
      );
    super.dispose();
  }

  void _notice(Object e) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  Future<void> _socialLogin(String provider) async {
    if (_preparing || _ticket != null) return;
    setState(() => _preparing = true);
    try {
      final ticket = await PlannerApi.instance.beginSocialLogin(provider);
      if (!mounted) {
        await PlannerApi.instance.cancelSocialLogin(ticket);
        return;
      }
      setState(() => _ticket = ticket);
      if (!kIsWeb) await _openSocialBrowser();
    } catch (e) {
      _notice(e);
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  void _cancelSocial() {
    _attempt++;
    final ticket = _ticket;
    setState(() {
      _ticket = null;
      _polling = false;
    });
    if (ticket != null)
      unawaited(
        PlannerApi.instance.cancelSocialLogin(ticket).catchError((_) {}),
      );
  }

  Future<void> _openSocialBrowser() async {
    final ticket = _ticket;
    if (ticket == null || _polling) return;
    // A separate web button keeps the browser launch within a direct user gesture.
    bool launched;
    try {
      launched = await launchUrl(
        Uri.parse(ticket['startUrl'].toString()),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      _notice(e);
      return;
    }
    if (!mounted || !identical(_ticket, ticket)) return;
    if (!launched) {
      _notice('브라우저를 열 수 없습니다. 팝업 허용 후 다시 눌러주세요.');
      return;
    }
    final attempt = ++_attempt, revision = PlannerApi.instance.sessionRevision;
    setState(() => _polling = true);
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    try {
      while (mounted &&
          attempt == _attempt &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted || attempt != _attempt) return;
        try {
          if (await PlannerApi.instance.pollSocialLogin(
            ticket,
            revision: revision,
            isActive: () => mounted && attempt == _attempt,
          )) {
            if (mounted && attempt == _attempt) {
              _ticket = null;
              context.go(AppRoutes.home);
            }
            return;
          }
        } on PlannerApiException catch (e) {
          if (!e.retryable) rethrow;
        }
      }
      if (mounted && attempt == _attempt) _notice('로그인 시간이 만료되었습니다. 다시 시도하세요.');
    } catch (e) {
      _notice(e);
    } finally {
      if (mounted && attempt == _attempt) {
        setState(() {
          _ticket = null;
          _polling = false;
        });
        unawaited(
          PlannerApi.instance.cancelSocialLogin(ticket).catchError((_) {}),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Container(
            height: 285,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(34),
                bottomRight: Radius.circular(34),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (_preparing) const LinearProgressIndicator(),
                  if (_ticket != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              _polling
                                  ? '브라우저에서 로그인한 뒤 이 화면으로 돌아오세요.'
                                  : '브라우저를 열어 로그인을 계속하세요.',
                            ),
                            if (!_polling)
                              FilledButton(
                                onPressed: _openSocialBrowser,
                                child: const Text('브라우저 로그인 열기'),
                              ),
                            TextButton(
                              onPressed: _cancelSocial,
                              child: const Text('로그인 취소'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 64),

                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'Travel Planner',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 58),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '여행 플래너에\n오신 것을 환영합니다.',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.35,
                              ),
                        ),

                        const SizedBox(height: 14),

                        Text(
                          '간편하게 로그인하고 나만의 일본 여행 일정을 만들어보세요.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.5),
                        ),

                        const SizedBox(height: 28),

                        _LoginButton(
                          text: 'Google로 계속하기',
                          iconText: 'G',
                          backgroundColor: Colors.white,
                          textColor: Colors.black,
                          borderColor: AppColors.border,
                          onTap: () => _socialLogin('google'),
                        ),

                        const SizedBox(height: 14),

                        _LoginButton(
                          text: 'NAVER로 계속하기',
                          iconText: 'N',
                          backgroundColor: const Color(0xFF03C75A),
                          textColor: Colors.white,
                          onTap: () => _socialLogin('naver'),
                        ),

                        const SizedBox(height: 14),

                        _LoginButton(
                          text: 'Kakao로 계속하기',
                          iconText: '●',
                          backgroundColor: const Color(0xFFFFE500),
                          textColor: Colors.black,
                          onTap: () => _socialLogin('kakao'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.emailLogin),
                    child: const Text('이메일 로그인 / 회원가입'),
                  ),
                  const SizedBox(height: 22),

                  Text(
                    '로그인 시 이용약관 및 개인정보처리방침에 동의하게 됩니다.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final String text;
  final String iconText;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _LoginButton({
    required this.text,
    required this.iconText,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!, width: 1),
          ),
          child: Row(
            children: [
              Text(
                iconText,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: textColor.withOpacity(0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
