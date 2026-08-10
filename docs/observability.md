# Doggy Observability Guide

## 기본 구조

- 모든 HTTP 요청에는 `X-Request-Id`가 응답 헤더로 내려갑니다.
- 클라이언트가 `X-Request-Id`를 보내면 같은 값을 사용하고, 없으면 서버가 새로 만듭니다.
- 로그 패턴에는 request id가 포함됩니다.
- `/actuator/health`는 공개 상태 확인용입니다.
- `/actuator/metrics`는 인증된 운영자 확인용으로만 사용합니다.

## 운영에서 먼저 보는 로그

- `http_request`: API 요청 단위 로그입니다. 4xx/5xx는 항상 남기고, 2xx/3xx는 느린 요청만 기본 기록합니다.
- `rate_limit_exceeded`: 로그인, 회원가입, refresh, OAuth2 교환, 이미지 업로드 제한 초과입니다.
- `authentication_required`: 인증 없이 보호 API에 접근한 요청입니다.
- `access_denied`: 인증은 됐지만 권한이 부족한 요청입니다.
- `Unhandled exception`: 예상하지 못한 5xx 오류입니다.
- `Doggy API Alert`: Discord로 전송되는 운영자 알림입니다.

## 권장 알림 기준

- 5분 동안 5xx가 10회 이상 발생
- 5분 동안 `rate_limit_exceeded`가 50회 이상 발생
- `/actuator/health`가 실패
- 평균 응답 시간이 평소 대비 2배 이상 증가
- 디스크 사용량 80% 이상
- DB 커넥션 오류 또는 커넥션 풀 고갈

## 운영 환경 변수

```properties
LOG_FILE=/var/log/doggy/doggy-api.log
ERROR_INCLUDE_REQUEST_ID=true
ACCESS_LOG_SUCCESS_ENABLED=false
ACCESS_LOG_SLOW_THRESHOLD_MS=500
ALERT_DISCORD_WEBHOOK_URL=
ALERT_WINDOW_SECONDS=300
ALERT_COOLDOWN_SECONDS=300
ALERT_SERVER_ERROR_THRESHOLD=10
ALERT_DB_ERROR_THRESHOLD=1
ALERT_RATE_LIMIT_THRESHOLD=50
ALERT_IMAGE_STORAGE_THRESHOLD=3
```

컨테이너 기반 배포에서는 파일 로그와 함께 표준 출력 로그도 수집해야 합니다. 네이버클라우드에서 로그 수집기를 붙일 때는 `requestId`, `http_request`, `rate_limit_exceeded`, `Unhandled exception` 키워드를 기준으로 검색/알림을 구성합니다.

## 접근 로그 정책

- 5xx 응답은 항상 `ERROR`로 기록합니다.
- 4xx 응답은 항상 `WARN`으로 기록합니다.
- 2xx/3xx 정상 응답은 기본적으로 기록하지 않습니다.
- 정상 응답이라도 `ACCESS_LOG_SLOW_THRESHOLD_MS` 이상 걸리면 `INFO`로 기록합니다.
- 장애 조사 기간에만 `ACCESS_LOG_SUCCESS_ENABLED=true`로 정상 요청 전체 로그를 켭니다.
- 로그 파일은 `logging.logback.rollingpolicy.max-file-size`와 `max-history`로 보관량을 제한합니다.

## Discord 알림 정책

- `ALERT_DISCORD_WEBHOOK_URL`이 없으면 알림은 비활성화됩니다.
- 5xx 서버 에러는 `ALERT_SERVER_ERROR_THRESHOLD` 기준을 넘으면 알림을 보냅니다.
- DB 연결 계열 에러는 `ALERT_DB_ERROR_THRESHOLD` 기준을 넘으면 알림을 보냅니다.
- rate limit 초과는 `ALERT_RATE_LIMIT_THRESHOLD` 기준을 넘으면 알림을 보냅니다.
- 이미지 저장 실패는 `ALERT_IMAGE_STORAGE_THRESHOLD` 기준을 넘으면 알림을 보냅니다.
- 같은 유형 알림은 `ALERT_COOLDOWN_SECONDS` 동안 다시 보내지 않습니다.
- Discord webhook URL은 시크릿이므로 코드, 문서, git에 실제 값을 남기지 않습니다.

## 주의사항

- access token, refresh token, 비밀번호, OAuth code는 로그에 남기지 않습니다.
- 이메일, 전화번호, 주소 같은 개인정보 원문도 운영 로그에 남기지 않습니다.
- 장애 문의를 받을 때는 사용자에게 시간대와 가능하면 `X-Request-Id`를 확인해 로그를 좁힙니다.
