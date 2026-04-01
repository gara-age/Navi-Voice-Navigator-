# Navi: Voice Navigator

Navi: Voice Navigator는 시각장애인과 저시력 사용자를 위한 Windows 데스크톱 접근성 보조 애플리케이션입니다.  
음성 입력, 단축키, 브라우저 자동화, Windows 자동화, 시뮬레이션 모드를 하나의 프로젝트 안에서 함께 개발하고 있습니다.

## 현재 프로젝트 상태

현재 저장소에는 아래 기능이 구현되어 있습니다.

- Flutter 기반 Windows 데스크톱 메인 앱
- 모드 선택 화면
  - 실제 모드
  - 데모 모드
  - 시뮬레이션 모드
- Python 백그라운드 서비스
  - 전역 단축키 감지
  - 앱 숨김 상태에서 재실행/재활성화 보조
- FastAPI 기반 로컬 서버 구조
- 시스템 팝업 알림
- 설정 저장
  - 테마
  - 단축키
  - 보안/기본 설정 일부
- 시뮬레이션 모드 시나리오
  - 네이버 지도 지하철 경로 조회
  - 메모장 일기 저장
  - Windows 라이트/다크 테마 전환
- HTML 기반 UI 시안 파일
  - `navi.html`

## 프로젝트 구조

- `app_flutter`
  Flutter Windows 앱

- `background_service`
  전역 단축키, 앱 상태 확인, 이벤트 전달을 담당하는 Python 백그라운드 프로세스

- `local_server`
  FastAPI 기반 로컬 오케스트레이션 서버 및 자동화/시뮬레이션 코드

- `scripts`
  환경 구성, 실행, 시뮬레이션, 팝업, 빌드용 PowerShell 스크립트

- `docs`
  제품 명세, 실행 가이드, 체크리스트

- `html_assets`, `navi.html`
  현재 UI를 HTML로 확인하기 위한 시안 자산

## 문서

- 제품 구현 명세: [docs/voice_navigator_spec.md](C:/Users/USER/Desktop/voiceNavigator/docs/voice_navigator_spec.md)
- 부팅 체크리스트: [docs/boot_checklist.md](C:/Users/USER/Desktop/voiceNavigator/docs/boot_checklist.md)
- Windows 실행 런북: [docs/runbook_windows.md](C:/Users/USER/Desktop/voiceNavigator/docs/runbook_windows.md)

## 개발 환경

권장 환경:

- Windows 10/11
- Python 3.11 이상
- Flutter SDK
- Visual Studio 2022 Build Tools
  - Windows Desktop C++ 워크로드 포함
- Git

## 최초 실행 준비

처음 한 번은 아래 순서대로 준비하는 것을 권장합니다.

1. 서버 가상환경 준비
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup_server_env.ps1
```

2. 백그라운드 가상환경 준비
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup_background_env.ps1
```

3. Flutter Windows 환경 준비
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup_flutter_windows.ps1
```

## 실행 방법

### 1. 모드 선택 화면 + 백그라운드 실행

가장 기본 실행 방식입니다.

```powershell
.\start_voice_navigator_launcher.bat
```

이 방식은 다음을 수행합니다.

- 백그라운드 서비스 실행
- Flutter 메인 앱 실행
- 메인 앱에서 모드 선택 화면 표시
  - 실제 모드
  - 데모 모드
  - 시뮬레이션 모드

### 2. 메인 앱만 실행

```powershell
.\start_flutter_gui.bat
```

### 3. 실제 모드 바로 실행

```powershell
.\start_flutter_connected.bat
```

### 4. 데모 모드 바로 실행

```powershell
.\start_flutter_demo.bat
```

### 5. 백그라운드만 실행

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_background.ps1
```

## 시뮬레이션 모드

시뮬레이션 모드는 외부 API에 의존하지 않거나 최소화된 상태에서, 특정 자동화 흐름을 직접 재현해보는 모드입니다.

현재 포함된 시나리오:

1. 네이버 지도 지하철 경로 조회
2. 메모장 일기 저장
3. Windows 테마 변경

### 네이버 지도 시뮬레이션

동작 개요:

1. 크롬 실행 또는 기존 시뮬레이션 세션 재사용
2. `https://map.naver.com/` 접속
3. 길찾기 진입
4. 출발지 입력
5. 도착지 입력
6. 지하철 탭 선택
7. 결과 수와 첫 번째 경로 시간 안내

### 메모장 시뮬레이션

동작 개요:

1. 메모장 실행
2. 제공된 일기 내용 입력
3. `현재날짜+일기.txt` 이름으로 저장
4. 저장된 파일 검증

### Windows 테마 변경 시뮬레이션

동작 개요:

1. Windows 설정 열기
2. 현재 테마 상태 확인
3. 라이트면 다크로, 다크면 라이트로 전환
4. 변경 결과 검증

## 설정 저장

설정은 로컬 `runtime/settings.json`에 저장됩니다.

현재 저장되는 주요 항목:

- 화면 모드
  - 다크 테마
  - 고대비
  - 큰 글씨
- 단축키 설정
- 일부 기본 설정
- 일부 보안 설정

## 트레이 동작

메인 창에서 `X`를 누르면 앱이 완전히 종료되지 않고 트레이 영역으로 숨겨집니다.

현재 지원:

- 트레이 아이콘 더블클릭: 창 복원
- 트레이 아이콘 우클릭 메뉴
  - 열기
  - 설정
  - 종료하기

## 현재 확인된 주의사항

- 팀원이 저장소를 `pull`만 해서는 바로 실행되지 않습니다.
  - Python, Flutter, Visual Studio Build Tools 설치가 필요합니다.
  - 초기 환경 구성 스크립트를 먼저 실행해야 합니다.
- 일부 자동화는 Windows 환경과 브라우저 상태에 따라 selector 보정이 필요할 수 있습니다.
- 시뮬레이션 모드는 실제 서비스 API 연동 없이도 동작하도록 설계됐지만, Windows/브라우저 환경 차이에 따라 세부 동작은 달라질 수 있습니다.

## 팀원 테스트 권장 순서

1. 저장소 클론
2. `scripts/setup_server_env.ps1`
3. `scripts/setup_background_env.ps1`
4. `scripts/setup_flutter_windows.ps1`
5. `start_voice_navigator_launcher.bat`
6. 모드 선택 화면에서
   - 실제 모드
   - 데모 모드
   - 시뮬레이션 모드
   를 각각 확인

## 배포 관련 참고

현재 저장소는 소스 저장소 기준입니다.  
다른 PC에서 Flutter 없이 바로 실행하려면, `exe` 단일 파일이 아니라 Windows 빌드 결과 폴더 전체가 필요합니다.

즉 배포 시에는 보통 아래 중 하나가 필요합니다.

- `Release` 빌드 결과 폴더 전체 배포
- 별도 설치 패키지 제작
- 압축 배포본 제공

## 저장소 상태

현재 GitHub 저장소:

- [gara-age/Navi-Voice-Navigator-](https://github.com/gara-age/Navi-Voice-Navigator-.git)

