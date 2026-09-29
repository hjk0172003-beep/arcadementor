BATTLE ZONE 메뉴·로딩·아이콘 업데이트

[적용 순서]
1. ZIP 파일을 다운로드한 뒤 마우스 오른쪽 클릭 → 모두 추출하세요.
2. 압축을 푼 BattleZone_MenuLogo_Update 폴더 안의 APPLY_UPDATE.cmd를 더블클릭하세요.
3. 프로젝트 위치를 물어보면 기존 BattleZone_AndroidStudio 폴더 경로를 입력하세요.
   예: C:\BattleZone\BattleZone_AndroidStudio
4. 초록색 APPLIED 또는 ALREADY APPLIED가 나오면 업데이트가 반영된 상태입니다.
5. 기존 프로젝트 폴더의 BUILD_DEBUG_APK.cmd를 실행하세요.
6. 새로 생성된 app\build\outputs\apk\debug\app-debug.apk를 휴대폰에 설치하세요.

이미 설치된 휴대폰 앱은 업데이트 스크립트 실행만으로 바뀌지 않습니다.
기존 프로젝트와 휴대폰 앱을 먼저 삭제하지 마세요. 설치 충돌이 나면 삭제 전에 기록을 보관하세요.
원본 변경 파일은 프로젝트의 .brand-menu-backups 폴더에 자동으로 백업합니다.

[변경 범위]
- 배경음 ON: 로딩, 모드 선택, 경기룰, 개인 기록, 결과 등 메뉴 화면에서 재생.
- 배경음 OFF: 위 모든 화면에서 정지. 기존 ON/OFF 선택을 유지.
- 사격 화면 및 START 준비 화면에서는 배경음 정지.
- 영상 생성 중과 앱이 백그라운드에 있을 때도 배경음 정지.
- 경기룰·개인 기록·결과창에도 배경음 ON/OFF 버튼을 제공.
- 영점 선택 시 소수점 표시와 소수점 합산 항목을 숨김.
- 공기권총·공기소총의 소수점 기능은 기존대로 유지.
- 로딩 그림과 Android 앱 아이콘 교체. 기존 로딩 대기시간은 변경하지 않음.

[변경하지 않는 파일]
game.js, audio-data.js, timeout-audio.js, ui-button-sound.js, 기존 배경음 WAV,
Gradle 설정, 서명키 설정, 시간제한·타임아웃·채점·입력·잠금·시작 삑 로직은 교체하지 않습니다.
이전 영점 표적지·탄착 번호 색상 수정도 그대로 유지됩니다.

[배경음 파일]
이미 추가한 app\src\main\assets\web\bz-menu-music.wav를 그대로 사용합니다.
기존 배경음이 없을 때만 다운로드 폴더의 Majestic_Modern_Electronic_Power_BGM.wav를 찾거나 파일 선택창을 엽니다.
이 ZIP에는 원본 음악을 다시 포함하지 않았습니다.

[미리보기]
payload\bz-clean-splash.png: 실제 적용하는 로딩 그림
payload\bz-app-icon.png: 앱 아이콘 미리보기 (홈 화면에 따라 가장자리 모양이 달라질 수 있음)

검증 범위와 로그는 verification 폴더에 포함합니다.
이번 파일은 기존 프로젝트용 업데이트이며 새 APK가 아닙니다.
