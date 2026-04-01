# Voice Navigator 부팅 체크리스트

## 우선순위 1: 개발 도구 설치

- Python 3.11 이상 설치
- Flutter SDK 설치
- Flutter용 Windows 데스크톱 빌드 환경 설치
- Visual Studio 2022 Build Tools 설치
  - Windows Desktop C++ 워크로드 포함
- PowerShell에서 아래 명령이 동작하는지 확인
  - `python --version` 또는 `py -3 --version`
  - `flutter --version`

## 우선순위 2: 환경 변수 및 비밀키 준비

- `.env.example`을 `.env`로 복사
- 아래 값 입력
  - `OPENAI_API_KEY`
  - `GOOGLE_CLOUD_API_KEY`
- 첫 부팅 단계에서는 아래 설정 유지 권장
  - `PLAYWRIGHT_HEADLESS=true`

## 우선순위 3: Python / Flutter 환경 준비

- 서버 가상환경 준비
  - `powershell -ExecutionPolicy Bypass -File scripts/setup_server_env.ps1`
- background 서비스 가상환경 준비
  - `powershell -ExecutionPolicy Bypass -File scripts/setup_background_env.ps1`
- Flutter Windows 앱 준비
  - `powershell -ExecutionPolicy Bypass -File scripts/setup_flutter_windows.ps1`

확인 항목:

- `.venv-server` 생성
- `.venv-background` 생성
- `app_flutter/windows/` 생성
- Playwright Chromium 설치 완료
- `flutter pub get` 완료

## 우선순위 4: 서비스 부팅

권장 방식:

- `powershell -ExecutionPolicy Bypass -File scripts/run_all.ps1`

개별 실행 방식:

1. `scripts/run_server.ps1`
2. `scripts/run_background.ps1`
3. `scripts/run_flutter.ps1`

## 우선순위 5: 로컬 서버 스모크 테스트

- `powershell -ExecutionPolicy Bypass -File scripts/check_local_server.ps1`

확인 항목:

- `/health` 응답 정상
- `/session/start` 응답 정상
- `/command/text` 응답 정상

## 우선순위 6: 기본 기능 확인

Flutter 앱에서 아래 항목을 확인합니다.

1. 앱 창이 정상적으로 열리는지 확인
2. 상단 카드에 마이크 상태와 현재 모드가 보이는지 확인
3. 설정 창을 열고 저장이 되는지 확인
4. 텍스트 명령 실행이 되는지 확인
5. 듣기 버튼으로 녹음 시작 / 종료가 되는지 확인
6. 화면 읽기 모달이 열리고 상태가 갱신되는지 확인

## 우선순위 7: 자동화 기능 확인

테스트 예시:

- `youtube cat videos search`
- `Naver Map route from Seoul Station to Korea Polytechnics Incheon Campus`

확인 항목:

- 결과 미리보기가 반환되는지 확인
- WebSocket 상태 이벤트가 수신되는지 확인
- TTS 메타데이터가 반환되는지 확인

## 우선순위 8: 보안 모드 확인

1. 보안 입력 모드 활성화
2. 민감 명령 입력
   - `enter password`
   - `read otp code`
3. 아래 결과 확인
   - 자동화가 차단되는지
   - secure warning 이벤트가 오는지
   - 사용자 안내 문구가 안전하게 표시되는지

## 아직 남아 있는 주요 blocker

- Windows 글로벌 핫키 실제 구현 미완료
- wake word 엔진 미구현
- Windows UI Automation 실구현 미완료
- verifier 실검증 로직 미완료
- Naver Map 파싱 정교화 필요
- Flutter 오디오 재생 미완료
- 실제 런타임 부팅 검증 미완료
