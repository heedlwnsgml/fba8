import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget directionsSurface(Uri route, Uri embedded) =>
    HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (element) {
        final frame = element as web.HTMLIFrameElement;
        frame.src = embedded.toString();
        frame.title = 'Google 지도 이동 경로';
        frame.style.border = '0';
        frame.style.width = '100%';
        frame.style.height = '100%';
        // Keep provider links inside this preview instead of spawning windows.
        frame.setAttribute(
          'sandbox',
          'allow-scripts allow-same-origin allow-forms',
        );
        frame.referrerPolicy = 'no-referrer-when-downgrade';
      },
    );
