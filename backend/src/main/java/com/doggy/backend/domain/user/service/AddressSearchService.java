package com.doggy.backend.domain.user.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.doggy.backend.global.exception.BusinessException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;
import java.util.ArrayList;
import java.util.List;

@Service
public class AddressSearchService {
    public record AddressResult(String address, double lat, double lng) {}
    private final RestClient client;

    public AddressSearchService(@Value("${kakao.rest-api-key}") String key) {
        var factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(3000);
        factory.setReadTimeout(5000);
        client = RestClient.builder().baseUrl("https://dapi.kakao.com")
                .requestFactory(factory).defaultHeader("Authorization", "KakaoAK " + key).build();
    }

    public List<AddressResult> search(String query) {
        if (query == null || query.trim().length() < 2 || query.length() > 100) {
            throw BusinessException.badRequest("주소를 2~100자로 입력해주세요");
        }
        try {
            JsonNode body = client.get().uri(builder -> builder.path("/v2/local/search/address.json")
                    .queryParam("query", query.trim()).queryParam("size", 10).build())
                    .retrieve().body(JsonNode.class);
            List<AddressResult> results = new ArrayList<>();
            if (body == null) return results;
            for (JsonNode item : body.path("documents")) {
                String address = item.path("road_address").path("address_name").asText("");
                if (address.isBlank()) address = item.path("address_name").asText();
                results.add(new AddressResult(address, Double.parseDouble(item.path("y").asText()),
                        Double.parseDouble(item.path("x").asText())));
            }
            return results;
        } catch (Exception exception) {
            throw BusinessException.badRequest("주소 검색을 일시적으로 사용할 수 없습니다. 다시 시도해주세요");
        }
    }
}
