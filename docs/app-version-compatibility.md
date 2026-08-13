# App Version Compatibility

모바일 앱은 사용자가 바로 최신 버전으로 업데이트하지 않을 수 있습니다. 백엔드는 요청 헤더의 앱 버전을 보고 구버전 앱을 허용, 업데이트 권장, 강제 업데이트로 나눠 대응합니다.

## Request Headers

Flutter 앱은 모든 API 요청에 아래 헤더를 보냅니다.

```http
X-App-Version: 1.0.0
X-App-Platform: android
```

- `X-App-Version`: 앱 버전입니다. 기본값은 `1.0.0`이고, 빌드 시 `--dart-define=APP_VERSION=1.2.3`으로 바꿀 수 있습니다.
- `X-App-Platform`: `android`, `ios`, `unknown` 중 하나입니다.

## Version Check API

앱 시작 시 아래 API를 호출합니다.

```http
GET /api/app/version
```

응답 예시:

```json
{
  "platform": "android",
  "currentVersion": "1.0.0",
  "minimumVersion": "1.0.0",
  "latestVersion": "1.1.0",
  "updateRequired": false,
  "updateRecommended": true,
  "storeUrl": "",
  "message": "새 앱 버전이 있습니다"
}
```

## Server Settings

기본값은 체크만 켜고 강제 차단은 끕니다.

```properties
APP_VERSION_CHECK_ENABLED=true
APP_VERSION_ENFORCE_MINIMUM=false
APP_VERSION_ANDROID_MINIMUM=1.0.0
APP_VERSION_ANDROID_LATEST=1.0.0
APP_VERSION_ANDROID_STORE_URL=
APP_VERSION_IOS_MINIMUM=1.0.0
APP_VERSION_IOS_LATEST=1.0.0
APP_VERSION_IOS_STORE_URL=
```

- `MINIMUM`: 이 버전보다 낮으면 업데이트 필요입니다.
- `LATEST`: 이 버전보다 낮고 `MINIMUM` 이상이면 업데이트 권장입니다.
- `APP_VERSION_ENFORCE_MINIMUM=true`: 최소 지원 버전 미만의 `/api/**` 요청을 `426 Upgrade Required`로 차단합니다.

## Operation Memo

앱스토어/플레이스토어 출시 전에는 `STORE_URL`을 비워둬도 됩니다. 출시 후에는 각 스토어 URL을 넣어야 업데이트 버튼이 바로 스토어로 이동합니다.

강제 업데이트를 켜기 전에는 먼저 `LATEST`만 올려 권장 업데이트 상태를 확인하고, 문제가 없을 때 `MINIMUM`과 `APP_VERSION_ENFORCE_MINIMUM`을 올리는 순서가 안전합니다.
