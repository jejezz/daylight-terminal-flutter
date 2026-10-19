# xterm2 5.3.0 복사본의 고친 점

- 드래그로 글을 고르는 동안 화면이 스크롤되면(자동 스크롤, 마우스 휠) 선택의 시작점이 딴 줄로 옮겨가던 결함.
  시작점을 화면 좌표(`DragStartDetails.localPosition`)로 들고 있다가 매번 현재 스크롤 위치로 칸을 다시 계산해서 생겼다.
  - `lib/src/ui/gesture/gesture_handler.dart`: 드래그 시작 때 버퍼 기준 칸(`_dragStartCell`)을 저장해 쓴다.
  - `lib/src/ui/render.dart`: `selectCharactersFromCell` 추가(`selectCharacters`가 이걸 부른다).
- 원본이 고치면 되돌린다.

- 한글 IME(Windows)에서 글자가 되풀이되던 결함. 글자를 확정하면서 곧바로 다음 글자 조합이 시작되면 확정된 글과 조합 중인 글이
  한 값에 같이 오는데, 확정 때마다 값 전체를 새 입력으로 보내서 이미 보낸 글자가 또 나갔다.
  - `lib/src/ui/custom_text_edit.dart`: 이미 보낸 글(`_sentText`)을 기억하고 아직 안 보낸 부분만 보낸다.
    조합 앞에 확정된 글은 조합 중에도 바로 보낸다. 엔진의 글이 보낸 것과 이어지지 않으면 새로 시작한 글로 본다.
    테스트는 `test/ime_input_test.dart`(앱 쪽).
- 원본이 고치면 되돌린다.
  - 이 처리는 Windows에서만 쓴다(`_trackSentText`). macOS 등은 아래 별도 처리나 원래 방식(`_updateEditingValueSimple`)이다.

- macOS 한글 IME에서 글자가 자모로 풀어져(ㅎㅏㄴ…) 나오고 Backspace가 한 번 더 필요하던 결함. 원인은 셋이다.
  1. macOS는 한글을 키 이벤트의 `character`로 자모 하나씩 주는데, 키 이벤트 처리의 텍스트 폴백(`_shouldInsertTextFallback`)이 그걸 바로
     `textInput`으로 보내고 "처리됨"으로 돌려줘서 IME가 키를 받지 못했다. → `lib/src/terminal_view.dart`: macOS에서 비 ASCII 글자는 폴백을 쓰지 않는다.
  2. macOS 한글 IME는 편집 상태가 비어 있으면 자모를 따로따로 확정해서 보내고, 글이 남아 있으면 앞 글자를 바꿔 달라는 요청(insertText +
     replacementRange)이나 조합 표시(setMarkedText)로 이어 쓴다. → `lib/src/ui/custom_text_edit.dart`(`_updateEditingValueMac`): 한글이 이어지는 동안
     편집 상태에 글을 남기고 바뀐 부분만 보낸다(바뀌면 백스페이스 + 새 글). 한글이 아닌 글·Enter·방향키 등이 오면 비운다(`resetImeBuffer`).
  3. Backspace: 조합 중이 아닐 때 한글 뒤의 Backspace는 IME가 고치게 넘기고(`imeBufferActive`), 글이 안 바뀌면 직접 지운다(`backspaceFallback`).
     조합 중인 자음 하나에서 Backspace를 누르면 IME가 지우지 않고 그 글자를 확정해 버려서, 누른 직후 그대로 확정돼 오는 글은 버린다(`_macBackspaceAt`).
  테스트는 `test/ime_input_test.dart`. 진단은 앱에서 `FlutterTextInputPlugin`의 `insertText`/`setMarkedText`를 스위즐링해 호출을 로그로 보면 된다.
- 원본이 고치면 되돌린다.
