import 'dart:async';
import 'dart:convert';
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
  return _DirectionsWebView(route: embedded);
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
    controller = WebViewController();
    initialize();
  }

  Future<void> initialize() async {
    try {
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      // Finish configuring the map renderer before the first request. Otherwise
      // Android can request the mobile text directions page with its default UA.
      await controller.setUserAgent(
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              (request.url == 'about:blank' ||
                  Uri.tryParse(request.url)?.scheme == 'https')
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
      if (mounted) load();
    } catch (_) {
      if (mounted)
        setState(() {
          failed = true;
          loading = false;
        });
    }
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
    final embedded = widget.route.replace(
      queryParameters: {...widget.route.queryParameters, 'hl': 'ko'},
    );
    // Google embeds must be child frames, including inside a native WebView.
    // Opening the embed URL as the top-level document produces an iframe error.
    final source = const HtmlEscape(
      HtmlEscapeMode.attribute,
    ).convert(embedded.toString());
    controller.loadHtmlString('''<!doctype html>
<html lang="ko"><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;width:100%;height:100%;overflow:hidden}iframe{display:block;border:0;width:100%;height:100%}</style>
</head><body>
<iframe title="Google 지도 이동 경로" src="$source"
 referrerpolicy="no-referrer-when-downgrade"
 sandbox="allow-scripts allow-same-origin allow-forms" allowfullscreen></iframe>
</body></html>''');
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
