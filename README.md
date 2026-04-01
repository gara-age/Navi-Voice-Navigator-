# Voice Navigator

Voice Navigator는 시각장애인과 저시력 사용자를 위한 Windows 데스크톱 접근성 보조 애플리케이션입니다.

이 저장소는 다음 3개 레이어로 구성되어 있습니다.

- `app_flutter`: Flutter 기반 Windows 데스크톱 앱
- `background_service`: 핫키, 앱 활성화, 백그라운드 트리거를 담당하는 Python 프로세스
- `local_server`: 명령 오케스트레이션, STT, 자동화, 검증, TTS를 담당하는 FastAPI 서버

## 현재 구성 상태

현재 저장소에는 다음 내용이 포함되어 있습니다.

- 접근성 중심 Flutter 메인 UI 골격
- 로컬 HTTP / WebSocket 통신 계층
- FastAPI API 엔드포인트와 서비스 스켈레톤
- background 서비스 이벤트 흐름 구조
- YouTube / Naver Map 자동화 초안
- 보안 모드 차단 구조
- 실행 및 환경 준비용 PowerShell 스크립트

## 문서

- 부팅 체크리스트: [docs/boot_checklist.md](docs/boot_checklist.md)
- Windows 실행 런북: [docs/runbook_windows.md](docs/runbook_windows.md)
- 제품 구현 명세서: [docs/voice_navigator_spec.md](docs/voice_navigator_spec.md)

## 권장 초기 실행 순서

Windows 환경에서 처음 실행할 때는 아래 순서를 권장합니다.

1. `scripts/setup_server_env.ps1`
2. `scripts/setup_background_env.ps1`
3. `scripts/setup_flutter_windows.ps1`
4. `scripts/run_all.ps1`
5. `scripts/check_local_server.ps1`

## 현재 남아 있는 주요 과제

- 실제 Windows 글로벌 핫키 구현
- 실제 wake word 엔진 연결
- Windows UI Automation 정교화
- Flutter 오디오 재생 연결
- Playwright 자동화 안정화
- 실제 런타임 환경에서 빌드 및 부팅 검증
