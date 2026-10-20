import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

Widget directionsSurface(Uri route, Uri embedded) {
  if (![
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform)) {
    return const Center(child: Text('지도 미리보기는 휴대폰 또는 웹에서 이용할 수 있습니다.'));
  }
  return _DirectionsWebView(route: route);
}

class _DirectionsWebView extends StatefulWidget {
  const _DirectionsWebView({required this.route});
  final Uri route;
  @override
  State<_DirectionsWebView> createState() => _DirectionsWebViewState();
}

class _DirectionsWebViewState extends State<_DirectionsWebView> {
  late final WebViewController controller;
  Timer? timeout;
  bool loading = true;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              Uri.tryParse(request.url)?.scheme == 'https'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (_) {
            timeout?.cancel();
            if (mounted) setState(() => loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              timeout?.cancel();
              setState(() {
                failed = true;
                loading = false;
              });
            }
          },
        ),
      );
    load();
  }

  void load() {
    timeout?.cancel();
    failed = false;
    loading = true;
    timeout = Timer(const Duration(seconds: 25), () {
      if (mounted && loading)
        setState(() {
          failed = true;
          loading = false;
        });
    });
    controller.loadRequest(
      widget.route.replace(
        queryParameters: {...widget.route.queryParameters, 'hl': 'ko'},
      ),
    );
  }

  @override
  void dispose() {
    timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (!failed) WebViewWidget(controller: controller),
      if (loading) const Center(child: CircularProgressIndicator()),
      if (failed)
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('지도 경로를 불러오지 못했습니다.'),
              TextButton(
                onPressed: () => setState(load),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
    ],
  );
}
