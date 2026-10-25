import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/planner_api.dart';
import '../../../core/theme/app_colors.dart';

/// 일정 카드의 장소 대표 사진 (구글 지도 사진 첫 장).
///
/// 서버에 작은 사진 주소를 물어보고, 사진이 있으면 [builder] 에 왼쪽 네모 사진 위젯을,
/// 없거나 아직 받는 중이면 null 을 넘긴다. 카드는 null 이면 원래 모양 그대로 그린다.
/// 작은 사진을 누르면 화면 가운데에 크게 띄운다 (그때 큰 사진을 한 번 더 받는다).
class PlacePhotoBuilder extends StatefulWidget {
  const PlacePhotoBuilder({
    super.key,
    required this.placeId,
    required this.title,
    required this.builder,
  });
  final String? placeId;
  final String title;
  final Widget Function(BuildContext context, Widget? photo) builder;

  /// 구글 장소 ID 처럼 생긴 것만 (자유 식사·공항 이동 같은 줄은 사진을 묻지 않는다)
  static bool canShow(String? placeId) =>
      placeId != null &&
      RegExp(r'^[A-Za-z0-9_-]{10,300}$').hasMatch(placeId) &&
      !placeId.startsWith('DUMMY_') &&
      !placeId.startsWith('AIRPORT_');

  @override
  State<PlacePhotoBuilder> createState() => _PlacePhotoBuilderState();
}

class _PlacePhotoBuilderState extends State<PlacePhotoBuilder> {
  static const double _size = 64;
  final Object _heroTag = Object();
  Map<String, dynamic>? _photo;
  bool _broken = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PlacePhotoBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeId != widget.placeId) {
      _photo = null;
      _broken = false;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.placeId;
    if (!PlacePhotoBuilder.canShow(id)) return;
    final photo = await PlannerApi.instance.getPlacePhoto(id!);
    if (!mounted || id != widget.placeId) return;
    if (photo['available'] == true && _https(photo['photoUri']) != null) {
      setState(() => _photo = photo);
    }
  }

  static String? _https(Object? value) {
    final text = value?.toString() ?? '';
    return text.startsWith('https://') ? text : null;
  }

  String get _author => (_photo?['author']?.toString() ?? '').trim();

  void _open() {
    final small = _https(_photo?['photoUri']);
    final id = widget.placeId;
    if (small == null || id == null) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierLabel: '사진 닫기',
        barrierColor: Colors.black.withValues(alpha: .78),
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: _PlacePhotoViewer(
            placeId: id,
            title: widget.title,
            heroTag: _heroTag,
            smallUri: small,
            author: _author,
            authorUri: _https(_photo?['authorUri']),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uri = _https(_photo?['photoUri']);
    if (uri == null || _broken) return widget.builder(context, null);
    final thumb = SizedBox(
      width: _size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: '${widget.title} 사진 크게 보기',
            child: GestureDetector(
              onTap: _open,
              child: Hero(
                tag: _heroTag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    uri,
                    width: _size,
                    height: _size,
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    frameBuilder: (context, child, frame, sync) =>
                        frame == null && !sync
                        ? Container(
                            width: _size,
                            height: _size,
                            color: AppColors.border.withValues(alpha: .5),
                          )
                        : child,
                    errorBuilder: (context, error, stack) {
                      // 주소가 만료되었거나 받지 못하면 사진 없이 원래 모양으로 돌아간다
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_broken) setState(() => _broken = true);
                      });
                      return const SizedBox(width: _size, height: _size);
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _author.isEmpty ? '사진: Google' : '사진: $_author',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
    return widget.builder(context, thumb);
  }
}

/// 눌렀을 때 화면 가운데에 크게 띄우는 사진. 바깥이나 ✕ 를 누르면 닫히고, 두 손가락으로 더 키울 수 있다.
class _PlacePhotoViewer extends StatelessWidget {
  const _PlacePhotoViewer({
    required this.placeId,
    required this.title,
    required this.heroTag,
    required this.smallUri,
    required this.author,
    required this.authorUri,
  });
  final String placeId, title, smallUri, author;
  final Object heroTag;
  final String? authorUri;

  Widget _image(String uri) => Image.network(
    uri,
    fit: BoxFit.contain,
    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
    errorBuilder: (context, error, stack) => Image.network(
      smallUri,
      fit: BoxFit.contain,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
    ),
  );

  @override
  Widget build(BuildContext context) {
    void close() => Navigator.of(context).maybePop();
    final maxHeight = MediaQuery.sizeOf(context).height * .62;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: close,
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: close,
                        tooltip: '닫기',
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      child: Hero(
                        tag: heroTag,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 4,
                            child: FutureBuilder<Map<String, dynamic>>(
                              future: PlannerApi.instance.getPlacePhoto(
                                placeId,
                                large: true,
                              ),
                              builder: (context, snapshot) {
                                final large =
                                    snapshot.data?['available'] == true
                                    ? snapshot.data!['photoUri']?.toString()
                                    : null;
                                // 큰 사진을 받는 동안에는 작은 사진을 그대로 보여 준다
                                return _image(
                                  large != null && large.startsWith('https://')
                                      ? large
                                      : smallUri,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: authorUri == null || authorUri!.isEmpty
                          ? null
                          : () => launchUrl(
                              Uri.parse(authorUri!),
                              mode: LaunchMode.externalApplication,
                            ),
                      child: Text(
                        author.isEmpty ? '사진: Google 지도' : '사진: $author · Google 지도',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFCBD5E1),
                          fontSize: 12,
                          decoration: authorUri == null || authorUri!.isEmpty
                              ? TextDecoration.none
                              : TextDecoration.underline,
                          decorationColor: const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
