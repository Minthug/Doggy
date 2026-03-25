package com.doggy.backend.global.batch;

import com.doggy.backend.global.common.CoordinateConverter;
import com.opencsv.CSVReader;
import com.opencsv.exceptions.CsvException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.InputStreamReader;
import java.io.Reader;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "batch.public-data.enabled", havingValue = "true")
public class PublicDataLoader {

    private final JdbcTemplate jdbcTemplate;
    private final CoordinateConverter converter;

    private static final int BATCH_SIZE = 500;

    @EventListener(ApplicationReadyEvent.class)
    public void load() {
        log.info("공공데이터 적재 시작");
        loadHospitals();
        log.info("공공데이터 적재 완료");
    }

    private void loadHospitals() {
        ClassPathResource resource = new ClassPathResource("data/animal_hospitals.csv");
        if (!resource.exists()) {
            log.warn("animal_hospitals.csv 파일이 없습니다. resources/data/ 에 파일을 추가해주세요.");
            return;
        }

        List<Object[]> batch = new ArrayList<>();
        int total = 0;
        int skipped = 0;

        try (Reader reader = new InputStreamReader(resource.getInputStream(), Charset.forName("EUC-KR"));
             CSVReader csv = new CSVReader(reader)) {

            String[] header = csv.readNext(); // 헤더 스킵
            log.info("헤더: {}", String.join(", ", header));

            String[] row;
            while ((row = csv.readNext()) != null) {
                try {
                    Object[] params = parseHospitalRow(row);
                    if (params != null) {
                        batch.add(params);
                        total++;
                    } else {
                        skipped++;
                    }
                } catch (Exception e) {
                    skipped++;
                }

                if (batch.size() >= BATCH_SIZE) {
                    insertBatch(batch);
                    batch.clear();
                    log.info("{}건 적재 완료...", total);
                }
            }

            if (!batch.isEmpty()) {
                insertBatch(batch);
            }

        } catch (IOException | CsvException e) {
            log.error("CSV 파싱 오류", e);
            return;
        }

        log.info("동물병원 적재 완료 - 성공: {}건, 스킵: {}건", total, skipped);
    }

    /**
     * 행안부 동물병원 CSV 컬럼 순서:
     * 0:번호, 1:개방서비스명, 2:개방서비스ID, 3:개방자치단체코드, 4:관리번호,
     * 5:인허가일자, 6:인허가취소일자, 7:영업상태구분코드, 8:영업상태명,
     * 9:상세영업상태코드, 10:상세영업상태명, 11:폐업일자, 12:휴업시작일자,
     * 13:휴업종료일자, 14:재개업일자, 15:소재지전화, 16:소재지면적,
     * 17:소재지우편번호, 18:소재지전체주소, 19:도로명전체주소,
     * 20:도로명우편번호, 21:사업장명, 22:최종수정시점, 23:데이터갱신구분,
     * 24:데이터갱신일자, 25:업태구분명, 26:좌표정보(X), 27:좌표정보(Y)
     */
    private Object[] parseHospitalRow(String[] row) {
        if (row.length < 28) return null;

        String statusCode = row[7].trim();
        if (!"01".equals(statusCode)) return null; // 영업 중인 곳만

        String name = row[21].trim();
        String address = row[19].isBlank() ? row[18].trim() : row[19].trim();
        String phone = row[15].trim();

        String xStr = row[26].trim();
        String yStr = row[27].trim();
        if (xStr.isBlank() || yStr.isBlank()) return null;

        double tmX = Double.parseDouble(xStr);
        double tmY = Double.parseDouble(yStr);
        double[] wgs84 = converter.toWgs84(tmX, tmY);
        double lat = wgs84[0];
        double lng = wgs84[1];

        // 한국 영역 벗어난 좌표 필터링
        if (lat < 33.0 || lat > 39.0 || lng < 124.0 || lng > 132.0) return null;

        return new Object[]{ name, address, lat, lng, phone };
    }

    private void insertBatch(List<Object[]> batch) {
        String sql = """
                INSERT INTO places (name, category, address, lat, lng, location, source, is_verified, is_open24h, is_emergency, allows_dogs, created_at, updated_at)
                VALUES (?, 'HOSPITAL', ?, ?, ?, ST_MakePoint(?, ?), 'PUBLIC_DATA', false, false, false, true, now(), now())
                ON CONFLICT DO NOTHING
                """;

        jdbcTemplate.batchUpdate(sql, batch.stream()
                .map(p -> new Object[]{
                        p[0],           // name
                        p[1],           // address
                        p[2],           // lat
                        p[3],           // lng
                        p[3],           // lng (for ST_MakePoint x)
                        p[2]            // lat (for ST_MakePoint y)
                })
                .toList());
    }
}
