# Voice Navigator 구현 명세서

## 1. 제품 개요

### 1.1 제품 정의
Voice Navigator는 시각장애인 및 저시력 사용자를 위한 Windows 데스크톱 접근성 보조 애플리케이션입니다.  
사용자는 음성 또는 텍스트 명령으로 PC와 웹 서비스를 제어할 수 있으며, 시스템은 내부적으로 음성 인식, 명령 계획, 자동화 실행, 단계별 검증, 결과 요약, 음성 응답을 수행합니다.

### 1.2 핵심 목표

- wake word 또는 전역 단축키로 빠르게 실행
- 단순하고 큰 글씨의 접근성 중심 UI 제공
- 음성 입력, 텍스트 입력, 화면 읽기 기능 제공
- STT → Planner → Executor → Verifier → Formatter → TTS 파이프라인 구성
- 브라우저 및 OS 자동화를 안전하게 수행
- 민감한 작업은 보안 모드에서 차단

### 1.3 사용자 경험 원칙

- 단순함
- 신뢰감
- 큰 글씨와 높은 대비
- 불필요한 개발자용 정보 비노출
- 명확한 상태 피드백
- 민감 정보 보호 우선

## 2. 기술 스택

### 2.1 프론트엔드

- Flutter
- Windows 데스크톱 앱
- 사용자 UI 전담
- HTTP / WebSocket으로 로컬 서버와 통신

### 2.2 백그라운드 서비스

- Python
- 항상 실행되는 경량 프로세스
- 전역 핫키, wake word, 앱 활성화 담당

### 2.3 로컬 서버

- Python + FastAPI
- 세션 관리
- STT / Planner / Executor / Verifier / Formatter / TTS 오케스트레이션

### 2.4 자동화

- Playwright (Python)
- Windows UI Automation

### 2.5 AI / 음성

- OpenAI STT
- LLM Planner Agent
- Google Cloud Text-to-Speech

## 3. 3계층 아키텍처

### 3.1 A. Background Program

역할:

- Windows 시작 시 자동 실행
- 전역 단축키 감지
- wake word 감지
- 메인 앱 실행 여부 확인
- 앱 실행 또는 복원
- `WAKE_UP`, `SHOW_WINDOW`, `START_LISTENING` 이벤트 전송

현재 구현 상태:

- 이벤트 전송 구조 있음
- 실제 글로벌 핫키 / wake word / 창 제어는 미완성

### 3.2 B. Main Program (Flutter)

역할:

- 사용자 메인 UI 제공
- 마이크 상태, 현재 모드 표시
- 듣기 시작, 화면 읽기, 설정 제공
- 음성 녹음 및 텍스트 명령 전송
- 서버 응답과 WebSocket 상태 반영

현재 구현 상태:

- 메인 화면 골격 구현
- 텍스트 명령 실행 가능 구조 존재
- 녹음 시작/종료 및 업로드 구조 존재
- 실제 Windows 런너 생성은 로컬 환경 필요

### 3.3 C. Local Server

역할:

- 세션 생성 및 유지
- 음성 / 텍스트 명령 수신
- STT 호출
- Planner 실행
- 자동화 실행
- 단계별 검증
- 결과 요약 및 TTS 생성
- WebSocket 상태 이벤트 전송

현재 구현 상태:

- FastAPI 엔드포인트 구성 완료
- 오케스트레이션 서비스 존재
- 보안 차단 구조 존재
- 실제 verifier / UI Automation은 미완성

## 4. UI 명세

### 4.1 메인 윈도우

구성:

- 커스텀 타이틀 바
- 상단 상태 카드 2개
  - 마이크 상태
  - 현재 모드
- 좌측 액션 패널
  - 듣기 시작
  - 현재 화면 읽기
  - 설정
- 중앙 Ready State 영역
- 텍스트 명령 입력 영역

### 4.2 상태 카드

- `마이크 상태`
  - 대기
  - 듣는중
  - 처리중
- `현재 모드`
  - 일반 모드
  - 보안 입력 모드

### 4.3 모달

- 단축키 도움말 모달
- 화면 읽기 모달
- 설정 모달

### 4.4 설정 모달 탭

1. 기본 설정
2. 단축키
3. 보안

## 5. 명령 처리 파이프라인

1. background 프로그램이 wake word 또는 단축키 감지
2. 메인 앱 실행 또는 복원
3. `START_LISTENING` 이벤트 전송
4. Flutter 앱이 listening 상태로 전환
5. 음성 녹음 또는 텍스트 입력
6. 로컬 서버로 전달
7. STT 수행
8. transcript 검증
9. Planner Agent 실행
10. task plan 생성
11. Executor 실행
12. Verifier 단계별 검증
13. Formatter 결과 요약
14. TTS 생성
15. Flutter 앱이 transcript / summary / follow-up / playback 상태 반영

## 6. 내부 모듈 역할

### 6.1 Planner Agent

- 명령 정규화
- intent 분석
- slot 추출
- goal 생성
- task plan 생성

### 6.2 Executor

- Playwright 기반 브라우저 자동화
- Windows UI Automation 보조 사용
- 실행 결과 수집

### 6.3 Verifier

- URL 검증
- locator 존재 여부 검증
- visibility 검증
- enabled 상태 검증
- 입력 값 검증
- 결과 목록 검증
- 추출 성공 여부 검증

### 6.4 Response Formatter

- 사용자 친화적 요약 생성
- follow-up 질문 생성

### 6.5 TTS Service

- 최종 요약 문장을 오디오로 합성
- 재생 메타데이터 반환

## 7. API 구조

### 7.1 Main Program → Local Server

- `POST /session/start`
- `POST /command/voice`
- `POST /command/text`
- `POST /screen/read`
- `POST /settings/update`
- `GET /settings/current`
- `GET /session/{session_id}`

### 7.2 Background → Local Server

- `POST /background/event`

### 7.3 WebSocket

- `WS /ws`

이벤트 유형:

- `status`
- `transcript`
- `verification`
- `completed`
- `tts`
- `secure_warning`
- `background_event`

## 8. JSON 예시

### 8.1 YouTube 검색 계획 예시

```json
{
  "intent": "youtube_video_search",
  "platform": "youtube",
  "slots": {
    "keyword": "고양이 영상"
  },
  "goal": "유튜브에서 키워드를 검색하고 상위 결과를 사용자에게 안내한다",
  "task_plan": [
    {"step": 1, "action": "open_browser"},
    {"step": 2, "action": "open_website", "target": "youtube"},
    {"step": 3, "action": "verify_url", "contains": "youtube.com"},
    {"step": 4, "action": "find_search_box"},
    {"step": 5, "action": "input_keyword", "value": "고양이 영상"},
    {"step": 6, "action": "submit_search"},
    {"step": 7, "action": "collect_results"}
  ]
}
```

### 8.2 Naver Map 경로 검색 계획 예시

```json
{
  "intent": "map_route_search",
  "platform": "naver_map",
  "slots": {
    "origin": "서울역",
    "destination": "한국폴리텍대학 인천캠퍼스",
    "transport": "subway"
  },
  "goal": "네이버 지도에서 지하철 경로를 검색하고 결과를 요약한다",
  "task_plan": [
    {"step": 1, "action": "open_browser"},
    {"step": 2, "action": "open_website", "target": "naver_map"},
    {"step": 3, "action": "verify_url", "contains": "map.naver.com"},
    {"step": 4, "action": "enter_route_mode"},
    {"step": 5, "action": "set_origin", "value": "서울역"},
    {"step": 6, "action": "set_destination", "value": "한국폴리텍대학 인천캠퍼스"},
    {"step": 7, "action": "select_transport", "value": "subway"},
    {"step": 8, "action": "extract_route_result"}
  ]
}
```

## 9. 시나리오

### 9.1 시나리오 A: YouTube 검색

사용자 명령:

- `유튜브에서 고양이 영상 찾아줘`

흐름:

1. 듣기 시작
2. 음성 녹음
3. STT transcript 생성
4. Planner가 YouTube 검색 계획 생성
5. Playwright가 YouTube 열기
6. 검색창 찾기
7. 키워드 입력
8. 검색 실행
9. 상위 결과 수집
10. 요약 생성
11. TTS 생성
12. follow-up 제공

follow-up 예시:

- `첫 번째 영상을 재생할까요?`

### 9.2 시나리오 B: Naver Map 경로 검색

사용자 명령:

- `네이버 지도에서 서울역에서 한국폴리텍대학 인천캠퍼스 가는 지하철 경로 찾아줘`

흐름:

1. 듣기 시작
2. 음성 녹음
3. STT transcript 생성
4. Planner가 경로 검색 계획 생성
5. Playwright가 Naver Map 열기
6. 길찾기 모드 진입
7. 출발지 입력
8. 도착지 입력
9. 교통수단 선택
10. 결과 목록 수집
11. 요약 생성
12. TTS 생성
13. follow-up 제공

follow-up 예시:

- `경로를 안내할까요?`

## 10. 보안 설계

### 10.1 보안 입력 모드

보안 입력 모드에서는 아래 규칙을 적용합니다.

- 비밀번호 자동 입력 금지
- OTP 자동 입력 금지
- 민감 정보 로그 기록 금지
- 민감한 화면에서는 상세 읽기 제한
- 위험 자동화 차단

### 10.2 민감 명령 차단

차단 대상 예시:

- `enter password`
- `read otp code`
- 로그인 / 계좌 / 결제 관련 민감 조작

차단 시 동작:

- secure warning 이벤트 전송
- 사용자용 안내 문구 생성
- 안전한 수동 진행 유도

## 11. 현재 구현 상태 요약

### 구현된 항목

- Flutter 메인 UI 골격
- 설정 저장 / 로드 구조
- 텍스트 명령 처리
- 음성 녹음 업로드 구조
- FastAPI 세션 / 명령 / 화면읽기 / 설정 API
- WebSocket 상태 이벤트
- YouTube Playwright 자동화 초안
- Naver Map Playwright 자동화 초안
- OpenAI STT 호출 구조
- Google TTS 호출 구조
- background 이벤트 브리지
- 보안 차단 구조

### 미구현 또는 보완 필요한 항목

- 실제 Windows 글로벌 핫키 구현
- wake word 엔진
- Windows UI Automation 고도화
- verifier 실검증 로직
- Flutter 오디오 재생
- Naver Map 결과 파싱 정교화
- 실제 런타임 빌드 / 부팅 검증
- 테스트 코드 작성

## 12. 권장 다음 단계

1. Windows 개발 환경에서 실제 빌드와 부팅 검증 수행
2. 한글 문자열 및 인코딩 상태 점검
3. background 글로벌 핫키 실제 구현
4. Verifier와 Windows UI Automation 강화
5. Flutter 오디오 재생 및 접근성 검증 추가
