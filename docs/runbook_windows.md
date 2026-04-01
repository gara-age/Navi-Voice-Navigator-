# Voice Navigator Windows 실행 런북

## 1. 사전 준비

먼저 아래 도구를 설치합니다.

- Python 3.11 이상
- Flutter SDK
- Visual Studio 2022 Build Tools
  - Windows Desktop C++ 워크로드 포함
- Git

설치 후 아래 명령이 동작하는지 확인합니다.

- `python --version` 또는 `py -3 --version`
- `flutter --version`

## 2. 비밀키 설정

1. `.env.example` 파일을 `.env`로 복사합니다.
2. 아래 값을 채웁니다.
   - `OPENAI_API_KEY`
   - `GOOGLE_CLOUD_API_KEY`

권장 설정:

- 첫 부팅 단계에서는 `PLAYWRIGHT_HEADLESS=true` 유지

## 3. Python 환경 준비

다음 순서로 실행합니다.

1. `powershell -ExecutionPolicy Bypass -File scripts/setup_server_env.ps1`
2. `powershell -ExecutionPolicy Bypass -File scripts/setup_background_env.ps1`

정상 완료 기준:

- `.venv-server` 생성
- `.venv-background` 생성
- Playwright Chromium 설치 완료

## 4. Flutter Windows 앱 준비

다음 명령을 실행합니다.

- `powershell -ExecutionPolicy Bypass -File scripts/setup_flutter_windows.ps1`

정상 완료 기준:

- `app_flutter/windows/` 생성
- `flutter pub get` 완료

## 5. 서비스 실행

권장 방식:

- `powershell -ExecutionPolicy Bypass -File scripts/run_all.ps1`

개별 실행 방식:

1. `scripts/run_server.ps1`
2. `scripts/run_background.ps1`
3. `scripts/run_flutter.ps1`

## 6. 로컬 서버 확인

다음 명령을 실행합니다.

- `powershell -ExecutionPolicy Bypass -File scripts/check_local_server.ps1`

기대 결과:

- `/health`가 `ok` 반환
- `/session/start`에서 세션 ID 반환
- `/command/text`에서 요약 응답 반환

## 7. Flutter UI 확인

앱에서 아래를 점검합니다.

1. 메인 창이 열리는지 확인
2. 상단 상태 카드가 보이는지 확인
3. 설정 창을 열고 저장이 되는지 확인
4. 텍스트 명령 실행이 되는지 확인
5. 듣기 버튼으로 녹음 시작 / 종료가 되는지 확인
6. 화면 읽기 모달이 열리고 결과가 반영되는지 확인

## 8. 자동화 확인

테스트 명령 예시:

- `youtube cat videos search`
- `Naver Map route from Seoul Station to Korea Polytechnics Incheon Campus`

기대 결과:

- 결과 미리보기가 표시됨
- WebSocket 상태 이벤트 수신
- TTS 메타데이터 반환

## 9. 보안 모드 확인

1. 보안 입력 모드 활성화
2. 민감 명령 입력
   - `enter password`
   - `read otp code`
3. 아래 확인
   - 자동화 차단 여부
   - secure warning 이벤트 여부
   - 안전한 follow-up 안내 여부

## 10. 첫 부팅 후 이어서 해야 할 작업

첫 실행이 성공하더라도 아래 항목은 추가 구현이 필요합니다.

- 실제 Windows 글로벌 핫키 훅 연결
- 실제 wake word 엔진 연결
- Windows UI Automation 고도화
- DOM / UI 기반 verifier 고도화
- Naver Map 결과 파싱 정교화
- Flutter 내 실제 오디오 재생 연결
