# 공공데이터 CSV 파일 위치

## 동물병원 데이터

**파일명:** `animal_hospitals.csv`

**다운로드 경로:**
1. https://www.data.go.kr 접속
2. "동물병원" 검색
3. "전국 동물병원 인허가 정보" (행정안전부) 다운로드
4. 다운로드한 CSV 파일을 이 디렉토리에 `animal_hospitals.csv` 이름으로 저장

**적재 방법:**
application.properties에서 아래 값을 true로 변경 후 서버 실행:
```
batch.public-data.enabled=true
```

적재 완료 후 다시 false로 되돌릴 것 (중복 실행 방지)
