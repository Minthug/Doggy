# Redis 캐시 재도입 가이드

Doggy는 현재 운영 환경에서 Redis를 사용하지 않습니다. 사용하지 않는 인프라와 안전하지 않은 serializer 설정이 런타임에 남지 않도록 Redis 캐시 코드와 의존성을 제거했습니다.

이 문서는 나중에 Redis를 의도적으로 다시 도입할 때 확인할 기준입니다.

## Redis를 추가할 시점

아래 조건 중 하나가 실제로 생겼을 때 Redis를 추가합니다.

- 백엔드가 여러 인스턴스로 늘어나 캐시 상태를 공유해야 한다.
- 날씨 응답처럼 외부 API 호출 결과를 TTL 있는 공유 캐시로 줄여야 한다.
- 반복 조회 API의 DB 부하가 측정됐고, 캐시가 해결책으로 결정됐다.
- rate limit을 여러 백엔드 인스턴스에서 일관되게 적용해야 한다.

단일 백엔드 인스턴스라면 캐시 없음 또는 명시적 TTL이 있는 작은 인프로세스 캐시를 우선 고려합니다.

## 필수 보안 원칙

- Redis는 백엔드 private network 안에만 둡니다. public internet에 노출하지 않습니다.
- 인증을 반드시 사용합니다. 강한 비밀번호 또는 managed Redis ACL을 사용합니다.
- 제공자가 TLS를 지원하면 TLS를 사용합니다.
- Jackson `LaissezFaireSubTypeValidator`를 사용하지 않습니다.
- `DefaultTyping.NON_FINAL`처럼 넓은 default typing을 켜지 않습니다.
- 타입 정보가 필요하면 Doggy 내부 DTO 패키지 또는 명시적 DTO 클래스만 허용합니다.
- 캐시별 TTL을 반드시 설정합니다. 무제한 캐시는 만들지 않습니다.
- JWT, refresh token, OAuth 로그인 코드, 비밀번호, 원본 위치 경로는 캐시하지 않습니다.

## Serializer 방향

가능하면 다형성 default typing이 필요 없는 캐시별 serializer를 사용합니다.

JSON 타입 정보가 꼭 필요하면 strict `PolymorphicTypeValidator` allowlist를 사용합니다. 예시는 방향만 보여주는 코드입니다.

```java
BasicPolymorphicTypeValidator validator = BasicPolymorphicTypeValidator.builder()
        .allowIfSubType("com.doggy.backend.domain.household.dto.")
        .allowIfSubType("com.doggy.backend.domain.place.dto.")
        .allowIfSubType("com.doggy.backend.global.weather.")
        .build();
```

실제 적용 전에는 캐시 대상 DTO 목록을 다시 검토합니다. JDK, Spring, 서드파티 패키지 루트는 allowlist에 넣지 않습니다.

## 도입 체크리스트

- `spring-boot-starter-data-redis`를 추가한다.
- 명시적 cache name과 TTL을 가진 Redis cache manager를 추가한다.
- 허용 타입과 거부 타입에 대한 serializer 테스트를 추가한다.
- 로컬/운영 Redis 환경 변수를 추가한다.
- Redis가 백엔드 네트워크에서만 접근 가능한지 확인한다.
- 배포 전 cache hit rate와 DB 부하 감소 효과를 측정한다.
