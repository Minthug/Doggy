package com.doggy.backend.global.batch;

import com.doggy.backend.domain.place.entity.Place;
import com.doggy.backend.global.common.GeometryUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Slf4j
@Component
@ConditionalOnProperty(name = "batch.kakao.enabled", havingValue = "true")
public class KakaoLocalLoader {

    private final JdbcTemplate jdbcTemplate;
    private final RestClient restClient;

    private static final int PAGE_SIZE = 15;  // 카카오 키워드 검색 API 최대값
    private static final int MAX_PAGES = 3;   // 카카오 API 최대 페이지

    // 검색할 키워드와 카테고리 매핑
    private static final List<KeywordCategory> TARGETS = List.of(
            new KeywordCategory("편의점", Place.Category.CONVENIENCE),
            new KeywordCategory("무인편의점", Place.Category.UNMANNED_STORE),
            new KeywordCategory("반려견 동반 식당", Place.Category.RESTAURANT),
            new KeywordCategory("애견 미용", Place.Category.GROOMING),
            new KeywordCategory("펫호텔", Place.Category.PET_HOTEL),
            new KeywordCategory("반려견 카페", Place.Category.CAFE)
    );

    // 전국 주요 도시/구 좌표
    private static final List<double[]> SEARCH_LOCATIONS = List.of(
            // 서울 (25개 구)
            new double[]{37.5665, 126.9780}, // 중구
            new double[]{37.5172, 127.0473}, // 강남구
            new double[]{37.5491, 126.9168}, // 마포구
            new double[]{37.5815, 127.0025}, // 성북구
            new double[]{37.5384, 127.0825}, // 광진구
            new double[]{37.6176, 127.0887}, // 노원구
            new double[]{37.5133, 126.8963}, // 양천구
            new double[]{37.4784, 126.9516}, // 관악구
            new double[]{37.5326, 126.9903}, // 동작구
            new double[]{37.5145, 127.1060}, // 송파구
            new double[]{37.5509, 127.0737}, // 강동구
            new double[]{37.6393, 127.0252}, // 도봉구
            new double[]{37.6027, 126.9291}, // 은평구
            new double[]{37.5791, 126.9368}, // 서대문구
            new double[]{37.5641, 126.9979}, // 종로구
            new double[]{37.5270, 127.0276}, // 서초구
            new double[]{37.5117, 126.9745}, // 동작구
            new double[]{37.5244, 126.8563}, // 강서구
            new double[]{37.5630, 126.8247}, // 구로구 (서울 서부)
            new double[]{37.4954, 126.9882}, // 금천구

            // 경기도
            new double[]{37.2636, 127.0286}, // 수원
            new double[]{37.4196, 127.1267}, // 성남 (분당)
            new double[]{37.6584, 126.8320}, // 고양 (일산)
            new double[]{37.2411, 127.1776}, // 용인
            new double[]{37.5035, 126.7660}, // 부천
            new double[]{37.3219, 126.8309}, // 안산
            new double[]{37.3943, 126.9568}, // 안양
            new double[]{37.6360, 127.2162}, // 남양주
            new double[]{37.1999, 127.0720}, // 화성
            new double[]{37.0637, 127.0674}, // 평택
            new double[]{37.7415, 127.0474}, // 의정부
            new double[]{37.3943, 127.2516}, // 광주(경기)
            new double[]{37.8813, 127.7298}, // 춘천 (강원)
            new double[]{37.4449, 126.7017}, // 시흥
            new double[]{37.2840, 127.4490}, // 이천

            // 인천
            new double[]{37.4563, 126.7052}, // 인천 남동구
            new double[]{37.4817, 126.6157}, // 인천 서구
            new double[]{37.5219, 126.6847}, // 인천 부평구

            // 부산
            new double[]{35.1796, 129.0756}, // 부산 중구
            new double[]{35.1579, 129.1600}, // 해운대구
            new double[]{35.1040, 129.0247}, // 사하구
            new double[]{35.2132, 129.0133}, // 북구
            new double[]{35.0960, 129.0219}, // 서구

            // 대구
            new double[]{35.8714, 128.6014}, // 대구 중구
            new double[]{35.8563, 128.5322}, // 달서구
            new double[]{35.9390, 128.5627}, // 북구

            // 광주
            new double[]{35.1595, 126.8526}, // 광주 서구
            new double[]{35.1468, 126.9229}, // 남구
            new double[]{35.2044, 126.8072}, // 북구

            // 대전
            new double[]{36.3504, 127.3845}, // 대전 유성구
            new double[]{36.3213, 127.4328}, // 서구
            new double[]{36.3741, 127.3933}, // 중구

            // 울산
            new double[]{35.5384, 129.3114}, // 울산 남구
            new double[]{35.5465, 129.2320}, // 중구

            // 세종
            new double[]{36.4800, 127.2890}, // 세종시

            // 강원도
            new double[]{37.8747, 127.7341}, // 춘천
            new double[]{37.3422, 127.9201}, // 원주
            new double[]{37.7519, 128.8761}, // 강릉

            // 충청북도
            new double[]{36.6424, 127.4890}, // 청주
            new double[]{36.9910, 127.9259}, // 충주

            // 충청남도
            new double[]{36.8151, 127.1139}, // 천안
            new double[]{36.7897, 126.9816}, // 아산

            // 전라북도
            new double[]{35.8242, 127.1480}, // 전주
            new double[]{35.9440, 126.9560}, // 군산
            new double[]{35.9477, 126.9477}, // 익산

            // 전라남도
            new double[]{34.7604, 127.6622}, // 여수
            new double[]{34.9506, 127.4872}, // 순천
            new double[]{34.8118, 126.3922}, // 목포

            // 경상북도
            new double[]{36.0190, 129.3435}, // 포항
            new double[]{35.8562, 129.2247}, // 경주
            new double[]{36.1195, 128.3446}, // 구미
            new double[]{36.5684, 128.7294}, // 안동

            // 경상남도
            new double[]{35.2282, 128.6811}, // 창원
            new double[]{35.1799, 128.1076}, // 진주
            new double[]{35.2285, 128.8893}, // 김해

            // 제주
            new double[]{33.4996, 126.5312}, // 제주시
            new double[]{33.2530, 126.5696}  // 서귀포시
    );

    public KakaoLocalLoader(
            JdbcTemplate jdbcTemplate,
            @Value("${kakao.rest-api-key}") String restApiKey) {
        this.jdbcTemplate = jdbcTemplate;
        this.restClient = RestClient.builder()
                .baseUrl("https://dapi.kakao.com")
                .defaultHeader("Authorization", "KakaoAK " + restApiKey)
                .build();
    }

    @EventListener(ApplicationReadyEvent.class)
    public void load() {
        Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM places", Integer.class);
        if (count != null && count > 0) {
            log.info("장소 데이터 {}건 존재 - 카카오 로컬 적재 스킵", count);
            return;
        }

        log.info("카카오 로컬 데이터 적재 시작 - {} 키워드 × {} 지역",
                TARGETS.size(), SEARCH_LOCATIONS.size());
        int total = 0;

        for (KeywordCategory target : TARGETS) {
            int keywordTotal = 0;
            for (double[] loc : SEARCH_LOCATIONS) {
                keywordTotal += searchAndSave(target.keyword(), target.category(), loc[0], loc[1]);
            }
            log.info("키워드 [{}] 완료 - {}건", target.keyword(), keywordTotal);
            total += keywordTotal;
        }

        log.info("카카오 로컬 데이터 적재 완료 - 총 {}건", total);
    }

    @SuppressWarnings("unchecked")
    private int searchAndSave(String keyword, Place.Category category, double lat, double lng) {
        int total = 0;

        for (int page = 1; page <= MAX_PAGES; page++) {
            try {
                final int currentPage = page;
                Map<String, Object> response = restClient.get()
                        .uri(uriBuilder -> uriBuilder
                                .path("/v2/local/search/keyword.json")
                                .queryParam("query", keyword)
                                .queryParam("x", lng)
                                .queryParam("y", lat)
                                .queryParam("radius", 5000)
                                .queryParam("size", PAGE_SIZE)
                                .queryParam("page", currentPage)
                                .build())
                        .retrieve()
                        .body(Map.class);

                if (response == null) break;

                List<Map<String, Object>> documents =
                        (List<Map<String, Object>>) response.get("documents");
                if (documents == null || documents.isEmpty()) break;

                List<Object[]> batch = new ArrayList<>();
                for (Map<String, Object> doc : documents) {
                    try {
                        String name = (String) doc.get("place_name");
                        String address = (String) doc.get("road_address_name");
                        if (address == null || address.isBlank()) {
                            address = (String) doc.get("address_name");
                        }
                        String phone = (String) doc.get("phone");
                        double placeLng = Double.parseDouble((String) doc.get("x"));
                        double placeLat = Double.parseDouble((String) doc.get("y"));

                        if (placeLat < 33.0 || placeLat > 39.0 ||
                                placeLng < 124.0 || placeLng > 132.0) continue;

                        batch.add(new Object[]{
                                name, category.name(), address,
                                placeLat, placeLng, placeLng, placeLat,
                                phone != null ? phone : ""
                        });
                    } catch (Exception e) {
                        log.debug("장소 파싱 실패: {}", e.getMessage());
                    }
                }

                if (!batch.isEmpty()) {
                    insertBatch(batch);
                    total += batch.size();
                }

                // 마지막 페이지 확인
                Map<String, Object> meta = (Map<String, Object>) response.get("meta");
                if (meta != null) {
                    Boolean isEnd = (Boolean) meta.get("is_end");
                    if (Boolean.TRUE.equals(isEnd)) break;
                }

            } catch (Exception e) {
                log.warn("카카오 검색 실패 [{}]: {}", keyword, e.getMessage());
                break;
            }
        }

        return total;
    }

    private void insertBatch(List<Object[]> batch) {
        String sql = """
                INSERT INTO places (name, category, address, lat, lng, location, source, phone,
                                    is_verified, is_open24h, is_emergency, allows_dogs, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ST_MakePoint(?, ?), 'KAKAO', ?, false, false, false, true, now(), now())
                ON CONFLICT DO NOTHING
                """;
        jdbcTemplate.batchUpdate(sql, batch);
    }

    private record KeywordCategory(String keyword, Place.Category category) {}
}
