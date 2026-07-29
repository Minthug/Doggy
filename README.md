# 🐶 Doggy

반려견 산책 기록 및 관리 앱

---

## 아키텍처 개요

```mermaid
graph TB
    subgraph Client["📱 Flutter App (Android/iOS)"]
        direction TB
        UI["UI Layer\n(Screens)"]
        PROV["State\n(Riverpod)"]
        REPO_F["Repository\n(Dio + Retrofit)"]
        LOCAL["Local Cache\n(SharedPreferences)"]

        UI --> PROV
        PROV --> REPO_F
        PROV --> LOCAL
    end

    subgraph Server["☕ Spring Boot 3.5 (JVM 21)"]
        direction TB
        CTRL["Controller Layer"]
        SVC["Service Layer"]
        REPO_B["Repository Layer\n(Spring Data JPA + QueryDSL)"]

        CTRL --> SVC
        SVC --> REPO_B
    end

    subgraph Cache["⚡ Redis 7.0"]
        REDIS["walkIndex · walkForecast\nhouseholdByUserId\nplaces · placesByCategory"]
    end

    subgraph DB["🗄️ PostgreSQL 16 + PostGIS"]
        USER_T["users"]
        DOG_T["dogs"]
        WALK_T["walk_sessions"]
        HOUSE_T["households"]
        PLACE_T["places (GIS)"]
        COMM_T["community_posts"]
    end

    subgraph External["🌐 외부 서비스"]
        KAKAO["Kakao OAuth2"]
        FCM["Firebase FCM\n(푸시 알림)"]
        WEATHER["기상청 API\n(산책 지수)"]
    end

    REPO_F -->|"HTTPS REST"| CTRL
    SVC <-->|"캐시 read/write"| Cache
    REPO_B --> DB
    SVC -->|"OAuth2 로그인"| KAKAO
    SVC -->|"푸시 발송"| FCM
    SVC -->|"날씨 조회"| WEATHER
```

---

## 도메인 관계도

```mermaid
erDiagram
    USER {
        Long id PK
        String email
        String nickname
        String profileImage
    }
    USER_AUTH {
        Long id PK
        Long userId FK
        String provider
        String providerId
    }
    HOUSEHOLD {
        Long id PK
        String name
        String inviteCode
    }
    HOUSEHOLD_MEMBER {
        Long id PK
        Long householdId FK
        Long userId FK
        String role
    }
    DOG {
        Long id PK
        Long userId FK
        Long householdId FK
        String name
        String breed
        Double weightKg
        Boolean isNeutered
    }
    WALK_SESSION {
        Long id PK
        Long userId FK
        Float distanceKm
        Integer durationSec
        String status
        Timestamp startedAt
    }
    WALK_POINT {
        Long id PK
        Long walkSessionId FK
        Double lat
        Double lng
        Integer sequence
    }
    PLACE {
        Long id PK
        String name
        String category
        Geometry location
    }
    COMMUNITY_POST {
        Long id PK
        Long userId FK
        String content
        Timestamp createdAt
    }

    USER ||--o{ USER_AUTH : "소셜 계정"
    USER ||--o{ HOUSEHOLD_MEMBER : "가구 소속"
    HOUSEHOLD ||--o{ HOUSEHOLD_MEMBER : ""
    HOUSEHOLD ||--o{ DOG : "가구 반려견"
    USER ||--o{ DOG : "내 반려견"
    USER ||--o{ WALK_SESSION : "산책 기록"
    WALK_SESSION ||--o{ WALK_POINT : "GPS 경로"
    USER ||--o{ COMMUNITY_POST : "게시글"
```

---

## 백엔드 도메인 구조

```mermaid
graph LR
    subgraph user["👤 User"]
        U_C["UserController"]
        U_S["UserService"]
        U_R["UserRepository"]
        U_C --> U_S --> U_R
    end

    subgraph dog["🐕 Dog"]
        D_C["DogController"]
        D_S["DogService"]
        D_R["DogRepository"]
        D_C --> D_S --> D_R
    end

    subgraph walk["🚶 Walk"]
        W_C["WalkController"]
        W_S["WalkService"]
        W_R["WalkSessionRepository"]
        W_C --> W_S --> W_R
        PING["WalkPingService\n(근처 강아지)"]
        W_S --> PING
    end

    subgraph household["🏠 Household"]
        H_C["HouseholdController"]
        H_S["HouseholdService"]
        H_R["HouseholdRepository"]
        H_C --> H_S --> H_R
        H_CACHE["Redis\nhouseholdByUserId (10분)"]
        H_S <--> H_CACHE
    end

    subgraph place["📍 Place"]
        P_C["PlaceController"]
        P_S["PlaceService"]
        P_R["PlaceRepository\n(PostGIS ST_DWithin)"]
        P_C --> P_S --> P_R
        P_CACHE["Redis\nplaces · placesByCategory (3분)"]
        P_S <--> P_CACHE
    end

    subgraph community["💬 Community"]
        C_C["CommunityController"]
        C_S["CommunityService"]
        C_R["CommunityPostRepository"]
        C_C --> C_S --> C_R
    end

    W_S -->|"가구 캐시 조회"| H_S
    D_S -->|"가구 캐시 조회"| H_S
```

---

## 프론트엔드 구조

```mermaid
graph TD
    subgraph App["Flutter App"]
        MAIN["main.dart\nProviderScope"]

        subgraph Features["features/"]
            AUTH["auth\n카카오 OAuth2 로그인"]
            HOME["home\n홈 · 산책지수 · 날씨"]
            WALK["walk\n산책 시작/기록/지도"]
            DOG["dog\n반려견 등록·수정·삭제"]
            PROFILE["profile\n프로필·사료재고·설정"]
            HOUSEHOLD["household\n가족 관리·초대코드"]
            PLACE["place\n장소 추천·투표"]
            COMMUNITY["community\n커뮤니티 게시판"]
        end

        subgraph Core["core/"]
            API["api_client.dart\nDio + 인터셉터"]
            CACHE["storage/local_cache.dart\nSharedPreferences"]
            NOTIF["notifications/\nFCM 서비스"]
        end
    end

    MAIN --> Features
    MAIN --> Core
    Features --> API
    Features --> CACHE
```

---

## 기술 스택 요약

### 백엔드
| 분류 | 기술 |
|------|------|
| 언어 / 런타임 | Java 21 (JVM) |
| 프레임워크 | Spring Boot 3.5 |
| 데이터베이스 | PostgreSQL 16 + PostGIS 3.4 |
| DB 마이그레이션 | Flyway (버전 관리, V1~V3) |
| ORM | Spring Data JPA + Hibernate Spatial |
| 쿼리 빌더 | QueryDSL 5.1 (타입 안전 동적 쿼리) |
| 인증 | Spring Security + OAuth2 + JWT |
| 캐시 | Redis 7.0 (분산 캐시, Spring Cache 추상화) |
| 커넥션 풀 | HikariCP |
| 푸시 알림 | Firebase Admin SDK (FCM) |
| 배치 | Spring Batch (생일 · 건강검진 알림) |

### 프론트엔드
| 분류 | 기술 |
|------|------|
| 프레임워크 | Flutter (Dart 3.11) |
| 상태 관리 | Riverpod 2.6 |
| HTTP 클라이언트 | Dio + Retrofit |
| 지도 | 네이버 지도 SDK |
| 위치 | Geolocator |
| 로컬 캐시 | SharedPreferences (stale-while-revalidate) |
| 푸시 알림 | Firebase Messaging |

### 인프라
| 분류 | 기술 |
|------|------|
| 로컬 개발 DB | Docker Compose (postgis/postgis:16-3.4) |
| 캐시 서버 | Redis 7.0 (systemctl, 단일 노드 → 멀티 인스턴스 대응 가능) |
| 배포 | Linux 서버 · systemctl JAR 실행 |
| 소셜 로그인 | Kakao / Google / Naver OAuth2 |
| OAuth redirect URI | 환경변수 `${SERVER_BASE_URL}` (IP 하드코딩 제거) |

### 운영 환경 변수

네이버클라우드 서버에는 실제 값을 환경 변수로 주입하고, repo에는 시크릿 값을 커밋하지 않습니다.
로컬 실행용 `backend/src/main/resources/application.properties`와 `application-local.properties`는 git ignore 대상입니다.
설정 키 목록은 `backend/src/main/resources/application.properties.example`을 기준으로 관리합니다.

필수:
- `DB_URL`
- `DB_USERNAME`
- `DB_PASSWORD`
- `JWT_SECRET`
- `SERVER_BASE_URL`
- `KAKAO_CLIENT_ID`
- `KAKAO_CLIENT_SECRET`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `NAVER_CLIENT_ID`
- `NAVER_CLIENT_SECRET`
- `WEATHER_API_KEY`
- `AIR_STATION_API_KEY`

선택:
- `PORT`
- `IMAGE_UPLOAD_DIR`
- `FCM_CREDENTIALS_PATH` 또는 `FCM_CREDENTIALS_BASE64`
- `REDIS_HOST`
- `REDIS_PORT`
- `REDIS_PASSWORD`
- `CACHE_TYPE`
