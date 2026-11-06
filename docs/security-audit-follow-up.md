# 보안 감사 후속 점검 목록

2026-11-05 기준 보안 감사에서 나온 12개 항목을 기록한다. 검토 기준은 커밋 `1f59fe9d0988b3f4e4cd47e45d13c15d833e1466`과 당시 미커밋 작업 트리다. 감사 당시 모두 **확정 취약점이 아닌 확인 대기 후보**였으며, 운영 서비스에는 시험 요청을 보내지 않았다. 아래 상태는 이후의 코드 변경과 제품 정책 확인을 반영한다.

| 번호 | 항목 | 코드 경계 | 결정적 확인 사항 | 상태 |
| --- | --- | --- | --- | --- |
| 1 | 8자리 가구 초대 코드의 추측 및 가입 시도 제한 부재 | `Household.java` · `HouseholdController.join` · `RateLimitService` | 20자리 난수 코드와 사용자별 시간당 5회 제한을 코드에 적용했다. 기존 코드 교체 마이그레이션과 더미 가구 가입 결과 확인 필요 | 코드 수정·검증 대기 |
| 2 | 가구원이 다른 구성원의 산책 보관 상태를 변경할 가능성 | `WalkService.archive/unarchive` · `findAccessibleWalk` | 공동 보호자 정책상 현재 가구원이 가입 이후 생성된 공유 산책을 열람·보관·해제할 수 있도록 유지했다. 더미 가구원과 비가구원 권한 확인 필요 | 제품 정책 확인·검증 대기 |
| 3 | 임의 위치 핑으로 활동 중인 사용자의 근접 여부·신원 노출 가능성 | `WalkPingService.updateLocationAndPing` · `WalkMeetService.getMeets` | 더미 산책 세션에서 조작 좌표의 만남 응답과 운영 요청 제한 확인 | 확인 대기 |
| 4 | 리프레시 토큰 동시 교환의 단일 사용 보장 불명확 | `RefreshTokenService.rotate` · `RefreshTokenRepository` | 격리 DB에서 같은 토큰의 동시 교환 결과·커밋 후 토큰 상태 확인 | 확인 대기 |
| 5 | 위치 갱신 시 사용자 ID와 정확한 GPS 좌표의 INFO 로그 기록 | `WalkPingService.updateLocationAndPing` | 운영 로그 수집·마스킹·접근권한·보관 기간 확인 | 확인 대기 |
| 6 | 익명 날씨 요청의 좌표별 캐시 키 누적 가능성 | `WeatherController` · `WeatherService.getCached` | 격리 서버에서 만료 키 잔존·메모리 증가와 운영 요청 제한 확인 | 확인 대기 |
| 7 | 전달 IP 헤더에 따른 인증 요청 제한 우회 가능성 | `RateLimitService.clientIp` | 운영 ingress의 `X-Forwarded-For`·`X-Real-IP` 정리 및 백엔드 직접 접근 여부 확인 | 확인 대기 |
| 8 | 계정 전환 후 이전 계정의 가구·반려견 캐시 표시 가능성 | `AuthAction` · `LocalCache` · 가구/반려견 provider | 격리 기기에서 더미 A→B 전환 중 화면 표시 확인 | 확인 대기 |
| 9 | OAuth 딥링크 코드와 앱의 현재 로그인 시도 미결합 | `main.dart`의 딥링크 처리 · Android/iOS URL 스킴 | 최종 패키지와 격리 기기에서 외부 링크의 계정 전환 결과 확인 | 확인 대기 |
| 10 | 로그아웃 후 이전 계정의 FCM 토큰 연결 잔존 가능성 | `AuthRepository.logout` · `UserService.updateFcmToken` | 같은 격리 기기의 더미 A/B에서 토큰 연결과 알림 수신 확인 | 확인 대기 |
| 11 | OAuth 요청 쿠키의 Java 역직렬화 | `HttpCookieOAuth2AuthorizationRequestRepository` | 격리 실행에서 객체 복원 도달 여부와 JVM 필터·클래스 경로 확인. 코드 실행 가능성은 단정하지 않음 | 확인 대기 |
| 12 | 공개 경로 검색에서 마스킹 전 출발점을 위치 필터에 사용 | `WalkSessionRepository.findPublicRoutesNearby` | 더미 PostGIS에서 좌표별 `sessionId` 포함 여부와 추정 정밀도 확인 | 확인 대기 |

상세 소스 경로, 근거, 비파괴 검증 절차는 저장소 밖의 `/Users/minthug/security-audit-skill/Doggy/run-1/REPORT.md` 및 같은 디렉터리의 `NEEDS-VALIDATION.md`에 기록되어 있다. 이 문서는 후속 작업 목록이며 심각도 순위나 수정 완료 기록이 아니다.

1번의 기존 8자리 초대 코드는 `V24` 마이그레이션 적용 시 모두 새 코드로 교체된다. 이미 공유한 초대 코드는 무효화되므로 가구 소유자가 새 코드를 다시 전달해야 한다.

2번은 공동 보호자 모델에서 의도된 권한이다. 산책 기록은 시작한 계정에 귀속되지만, 같은 가구에 현재 속하고 해당 산책 시작 전에 가입한 구성원도 공유 기록을 열람하고 보관 상태를 관리한다. 경로 공개·비공개 전환은 기록한 계정에만 허용한다.
