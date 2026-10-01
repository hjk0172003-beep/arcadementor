BATTLE ZONE - 표적지 색상 탭 정리

적용 내용
- 표적지 색상 선택에서 '흰색' 버튼 삭제
- '색상 1 / 밝은 크림색' -> '색상 1'
- '색상 2 / 진한 크림색' -> '색상 2'
- 기존 색상 선택 기능은 그대로 유지
- 기존에 흰색이 선택되어 있었다면 업데이트 후 색상 1을 선택하도록 처리

적용 순서
1. ZIP을 다운로드한 뒤 마우스 오른쪽 클릭 -> 모두 추출
2. 압축 푼 폴더의 APPLY_UPDATE.cmd 더블클릭
3. 지금 APK를 만드는 BattleZone_AndroidStudio 폴더 선택
   (app 폴더, settings.gradle, BUILD_DEBUG_APK.cmd가 같이 있는 위치)
4. 초록색 APPLIED가 나오면 적용 완료
5. 같은 프로젝트의 BUILD_DEBUG_APK.cmd 실행
6. BUILD SUCCESSFUL 후 app\build\outputs\apk\debug\app-debug.apk를 휴대폰에 다시 설치

기존 프로젝트와 휴대폰 앱은 먼저 삭제하지 마세요.
이번 업데이트는 색상 탭 표시만 바꾸며 게임 로직은 건드리지 않습니다.
