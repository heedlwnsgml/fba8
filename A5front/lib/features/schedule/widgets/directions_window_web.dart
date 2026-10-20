import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

const supportsGoogleWindow = true;
web.Window? _active;
void Function()? _cleanup;

bool openGoogleDirectionsWindow(Uri route) {
  if (![
        'www.google.com',
        'maps.google.com',
        'google.com',
      ].contains(route.host) ||
      !route.path.startsWith('/maps'))
    return false;
  _cleanup?.call();
  _active?.close();
  final width = (web.window.outerWidth * .76).round().clamp(360, 920);
  final height = (web.window.outerHeight * .82).round().clamp(420, 760);
  final left = (web.window.screenX + (web.window.outerWidth - width) / 2)
      .round();
  final top = (web.window.screenY + (web.window.outerHeight - height) / 2)
      .round();
  bool leftApp = false;
  Timer? timer;
  late JSFunction focus, blur;
  void cleanup() {
    timer?.cancel();
    web.window.removeEventListener('focus', focus);
    web.window.removeEventListener('blur', blur);
    _cleanup = null;
  }

  blur = ((web.Event event) {
    leftApp = true;
  }).toJS;
  focus = ((web.Event event) {
    if (leftApp) {
      _active?.close();
      _active = null;
      cleanup();
    }
  }).toJS;
  web.window.addEventListener('blur', blur);
  web.window.addEventListener('focus', focus);
  _active = web.window.open(
    route
        .replace(queryParameters: {...route.queryParameters, 'hl': 'ko'})
        .toString(),
    'travel_google_directions',
    'popup=yes,width=$width,height=$height,left=$left,top=$top,resizable=yes,scrollbars=yes',
  );
  if (_active == null) {
    cleanup();
    return false;
  }
  _cleanup = cleanup;
  _active!.focus();
  timer = Timer.periodic(const Duration(seconds: 1), (_) {
    if (_active?.closed ?? true) {
      _active = null;
      cleanup();
    }
  });
  return true;
}
