# xterm2 5.3.0 복사본의 고친 점

- 드래그로 글을 고르는 동안 화면이 스크롤되면(자동 스크롤, 마우스 휠) 선택의 시작점이 딴 줄로 옮겨가던 결함.
  시작점을 화면 좌표(`DragStartDetails.localPosition`)로 들고 있다가 매번 현재 스크롤 위치로 칸을 다시 계산해서 생겼다.
  - `lib/src/ui/gesture/gesture_handler.dart`: 드래그 시작 때 버퍼 기준 칸(`_dragStartCell`)을 저장해 쓴다.
  - `lib/src/ui/render.dart`: `selectCharactersFromCell` 추가(`selectCharacters`가 이걸 부른다).
- 원본이 고치면 되돌린다.
