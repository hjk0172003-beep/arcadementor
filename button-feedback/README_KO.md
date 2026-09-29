# BATTLE ZONE 버튼 조작음 추가

이 파일은 새 게임 전체 프로젝트나 APK가 아니라, 현재 정상 실행되는 Android Studio 프로젝트에 **버튼 소리만 추가하는 업데이트**입니다.

## 바뀌는 것

결과 보기, 탄착 분석, 경기룰, 닫기, 기록 선택, 모드 선택, 시간 +/− 등 활성 버튼을 누르면 짧은 ‘톡’ 소리가 납니다. 약 0.055초입니다.

START는 기존 시작 삑을 그대로 사용합니다. 남녀 음성 선택·발사효과음 선택은 기존 미리듣기를 유지하고 소리를 겹쳐 추가하지 않습니다. 잠금/잠금해제도 기존 소리가 있으면 그대로 사용하고, 기존 소리가 꺼져 있으면 버튼 확인음이 납니다. 음성 OFF/효과음 OFF 선택에도 버튼 확인음은 납니다.

잠금으로 비활성화된 버튼, 표적 사격, 기록 스크롤에서는 추가 버튼 소리가 나지 않습니다. 버튼 소리는 사격 결과 영상의 오디오 믹스에 연결하지 않습니다.

## 1. ZIP 파일을 다운로드하고 모두 압축 해제하세요

압축 안에서 바로 실행하지 마세요. 압축을 푼 폴더에 다음 세 파일이 함께 있어야 합니다.

- APPLY_BUTTON_SOUND.cmd
- Apply_ButtonSound.ps1
- ui-button-sound.js

## 2. APPLY_BUTTON_SOUND.cmd를 더블클릭하세요

기존 안내대로 프로젝트가 아래 위치에 있으면 자동으로 찾습니다.

C:\BattleZone\BattleZone_AndroidStudio

다른 위치에 있다면 프로젝트 폴더 경로를 입력하고 Enter를 누르세요. app 폴더와 settings.gradle 파일이 보이는 위치입니다. 입력 대신 업데이트 폴더를 프로젝트 폴더 안에 넣고 실행해도 됩니다.

초록색 APPLIED 또는 ALREADY APPLIED가 보이면 적용 성공입니다. 그 뒤 아무 키나 눌러 창을 닫으세요. 오류가 나오면 기존 프로젝트를 삭제하지 말고 오류 내용을 확인하세요.

이 실행은 관리자 권한이나 인터넷이 필요 없습니다. PowerShell 실행 정책은 이 실행 프로세스에만 지정하며 PC의 영구 설정을 바꾸지 않습니다.

## 3. 기존 프로젝트에서 APK를 다시 만드세요

기존 BattleZone_AndroidStudio 폴더의 BUILD_DEBUG_APK.cmd를 더블클릭하세요. 또는 기존처럼 명령프롬프트에서 다음을 한 줄씩 실행하세요.

```bat
cd /d "C:\BattleZone\BattleZone_AndroidStudio"
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
gradlew.bat :app:assembleDebug
```

위 JAVA_HOME은 Android Studio 기본 설치 위치를 기준으로 합니다. 기존에 정상 빌드한 다른 Java 경로를 사용 중이라면 그 설정을 유지하세요.

BUILD SUCCESSFUL이 나오면 아래 위치의 app-debug.apk가 새 결과물입니다.

C:\BattleZone\BattleZone_AndroidStudio\app\build\outputs\apk\debug\app-debug.apk

## 4. 새 APK로 설치하고 확인하세요

기존 앱을 먼저 삭제할 필요는 없습니다. 본인 PC의 같은 프로젝트와 서명 설정으로 업데이트 APK를 만드세요. 서명 충돌이 발생하면 임의로 앱을 지우지 마세요. 앱 삭제 시 기기에 보관된 기록도 삭제될 수 있습니다.

## 변경 범위와 백업

기존 game.js, CSS, 음성·효과음·로딩 이미지, Gradle 설정, Android 코드, 서명 설정을 교체하지 않습니다.

index.html에 추가 스크립트 한 줄을 연결하고, ui-button-sound.js 파일 하나를 넣습니다. 변경 전 index.html은 프로젝트 안 .button-sound-backups/날짜-식별자/에 자동 백업합니다. 이미 적용했다면 중복으로 넣지 않습니다. 잘못된 프로젝트 구조에서는 적용을 중단합니다.

사용자의 휴대폰에 설치된 앱이나 기록을 직접 수정하는 작업은 아닙니다. 소스에 적용한 다음 APK를 다시 빌드·설치해야 소리가 추가됩니다.

## 확인 범위

업데이트 코드와 적용 스크립트는 별도로 시험합니다. 동봉된 테스트 결과의 scope를 확인하세요. 실제 사용자 프로젝트 전체 APK 재컴파일, 실제 휴대폰 스피커·전자타겟 시험을 완료했다는 의미는 아닙니다.

기존 게임의 실제 소스·음성 파일을 공개 저장소에 새로 업로드하지 않았습니다. 배포물은 추가 코드와 설치 스크립트입니다.
