# Doggy 운영 백업

`doggy-backup.timer`가 매일 03:20경 PostgreSQL 덤프와 `/var/doggy/images` 압축본을 생성합니다. 서버 안의 날짜별 백업은 3일간 보관합니다. 덤프·압축 파일을 검사하고 체크섬을 기록한 뒤에만 `latest`를 갱신합니다. 실패하면 기존 Discord 경보 채널에 알립니다.

## Object Storage 연결

1. 네이버 클라우드 Object Storage에 **비공개** 버킷을 만들고 업로드용 API 키를 준비합니다. 버킷 이름과 키 값은 Git이나 채팅에 남기지 않습니다.
2. 버킷 이름이 `doggy`이면 Mac 터미널에서 `scripts/connect-doggy-object-storage.sh`를 실행합니다. 키 두 개를 화면에 표시하지 않고 입력받아 서버의 root 소유, 권한 `0600`인 `/etc/doggy-backup-object-storage.env`에 저장합니다. 키를 채팅이나 Git에 붙여 넣지 않습니다. 다른 버킷 이름을 쓸 때는 스크립트의 버킷 이름을 먼저 수정합니다.

   ```sh
   DOGGY_OBJECT_BUCKET=버킷이름
   DOGGY_OBJECT_ACCESS_KEY='접근키'
   DOGGY_OBJECT_SECRET_KEY='비밀키'
   ```

3. 연결 스크립트가 실행한 첫 백업의 출력에서 `uploaded=doggy/날짜시간/...` 세 건과 `Result=success`를 확인합니다. 버킷에도 같은 경로의 `postgres.dump`, `images.tar.gz`, `SHA256SUMS`가 있어야 합니다.
4. 콘솔의 `Menu > All Services > Storage > Object Storage > Lifecycle Management > 수명주기 정책 추가`에서 `만료 삭제`, 생성 후 `30일`, 대상 버킷 `doggy`, Object 이름 접두어 `doggy/`를 설정합니다. 서버 안의 3일 보관과 별개입니다.

설정 파일이 없으면 로컬 백업만 생성하고 로그에 `offsite_upload=not_configured`를 남깁니다. 업로드가 실패하면 서비스가 실패 상태가 되며 `latest`를 갱신하지 않습니다.

## 복원 점검

운영 DB와 분리된 임시 DB에서 `pg_restore --exit-on-error`로 복원하고 테이블을 확인합니다. 이미지 압축본은 `tar -tzf`로 검사합니다. 운영 DB에는 복원하지 않습니다. 2026-11-23에 Object Storage에서 첫 백업을 다시 내려받아 체크섬과 임시 DB의 공개 스키마 테이블 29개를 확인했습니다. 이후에도 저장소에서 **다운로드한** 백업 파일로 주기적으로 복원 시험을 반복해야 합니다.
