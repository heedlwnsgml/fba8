import 'package:flutter/material.dart';
import 'trip_draft.dart';

/// 입력 변경 시 화면 이동 방향과 무관하게 현재 편집 세션에 보관합니다.
mixin DraftAutosave<T extends StatefulWidget> on State<T> {
  late final int _draftRevision;
  bool get canSaveDraft => _draftRevision == TripDraft.instance.inputRevision;
  @override
  void initState() {
    super.initState();
    _draftRevision = TripDraft.instance.inputRevision;
  }

  void saveDraft();

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    saveDraft();
  }
}
