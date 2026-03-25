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
     * 실제 CSV 컬럼 순서 (EUC-KR):
     * 0:개방자치단체코드, 1:관리번호, 2:인허가일자, 3:인허가취소일자,
     * 4:영업상태명, 5:폐업일자, 6:휴업시작일자, 7:휴업종료일자,
     * 8:재개업일자, 9:소재지면적, 10:소재지우편번호, 11:도로명우편번호,
     * 12:사업장명, 13:데이터갱신구분, 14:권리주체일련번호, 15:데이터갱신시점,
     * 16:도로명주소, 17:상세영업상태명, 18:상세영업상태코드, 19:영업상태코드,
     * 20:전화번호, 21:좌표정보(X), 22:좌표정보(Y), 23:지번주소, 24:최종수정시점
     */
    private Object[] parseHospitalRow(String[] row) {
        if (row.length < 23) return null;

        String statusName = row[4].trim();
        if (!statusName.contains("영업") && !statusName.contains("정상")) return null; // 영업 중인 곳만

        String name = row[12].trim();
        String address = row[16].isBlank() ? row[23].trim() : row[16].trim();
        String phone = row[20].trim();

        String xStr = row[21].trim();
        String yStr = row[22].trim();
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
