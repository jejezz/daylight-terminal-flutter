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
