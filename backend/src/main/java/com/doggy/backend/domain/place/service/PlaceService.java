package com.doggy.backend.domain.place.service;

import com.doggy.backend.domain.place.dto.CreatePlaceRequest;
import com.doggy.backend.domain.place.dto.PlaceResponse;
import com.doggy.backend.domain.place.dto.VoteRequest;
import com.doggy.backend.domain.place.entity.Place;
import com.doggy.backend.domain.place.entity.Place.Category;
import com.doggy.backend.domain.place.entity.Place.Source;
import com.doggy.backend.domain.place.entity.PlaceVote;
import com.doggy.backend.domain.place.repository.PlaceRepository;
import com.doggy.backend.domain.place.repository.PlaceVoteRepository;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.common.GeometryUtil;
import com.doggy.backend.global.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PlaceService {

    private static final double DEFAULT_RADIUS_METERS = 1000;
    private static final long CACHE_TTL_MS = 3 * 60 * 1000L; // 3분
    private final ConcurrentHashMap<String, Object[]> cache = new ConcurrentHashMap<>();

    private final PlaceRepository placeRepository;
    private final PlaceVoteRepository placeVoteRepository;
    private final UserRepository userRepository;

    // 반경 내 전체 장소 검색
    public List<PlaceResponse> findNearby(double lat, double lng, Double radiusMeters) {
        double radius = radiusMeters != null ? radiusMeters : DEFAULT_RADIUS_METERS;
        String key = cacheKey(lat, lng, radius, null);
        List<PlaceResponse> cached = fromCache(key);
        if (cached != null) return cached;

        List<Place> places = placeRepository.findNearby(lat, lng, radius);
        List<PlaceResponse> result = toResponses(places);
        toCache(key, result);
        return result;
    }

    // 반경 내 카테고리별 장소 검색
    public List<PlaceResponse> findNearbyByCategory(double lat, double lng, Double radiusMeters, Category category) {
        double radius = radiusMeters != null ? radiusMeters : DEFAULT_RADIUS_METERS;
        String key = cacheKey(lat, lng, radius, category.name());
        List<PlaceResponse> cached = fromCache(key);
        if (cached != null) return cached;

        List<Place> places = placeRepository.findNearbyByCategory(lat, lng, radius, category.name());
        List<PlaceResponse> result = toResponses(places);
        toCache(key, result);
        return result;
    }

    // N+1 없이 한 번에 vote count 조회
    private List<PlaceResponse> toResponses(List<Place> places) {
        if (places.isEmpty()) return List.of();
        List<Long> ids = places.stream().map(Place::getId).toList();
        Map<Long, Long> helpfulCounts = placeVoteRepository.countHelpfulByPlaceIds(ids)
                .stream()
                .collect(Collectors.toMap(
                        row -> ((Number) row[0]).longValue(),
                        row -> ((Number) row[1]).longValue()
                ));
        return places.stream()
                .map(p -> PlaceResponse.of(p, helpfulCounts.getOrDefault(p.getId(), 0L)))
                .toList();
    }

    // 장소 단건 조회
    public PlaceResponse getPlace(Long placeId) {
        Place place = placeRepository.findById(placeId)
                .orElseThrow(() -> BusinessException.notFound("장소를 찾을 수 없습니다"));
        return PlaceResponse.of(place, countHelpful(placeId));
    }

    // 유저가 직접 장소 등록 (크라우드소싱)
    @Transactional(readOnly = false)
    public PlaceResponse create(Long userId, CreatePlaceRequest request) {
        userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));

        Place place = placeRepository.save(
                Place.builder()
                        .name(request.name())
                        .category(request.category())
                        .address(request.address())
                        .lat(request.lat())
                        .lng(request.lng())
                        .location(GeometryUtil.toPoint(request.lat(), request.lng()))
                        .phone(request.phone())
                        .isOpen24h(request.isOpen24h())
                        .isEmergency(request.isEmergency())
                        .allowsDogs(request.allowsDogs())
                        .source(Source.USER)
                        .build()
        );

        return PlaceResponse.of(place, 0L);
    }

    // 도움이 됐어요 투표 (이미 투표했으면 변경, 같은 값이면 취소)
    @Transactional(readOnly = false)
    public void vote(Long userId, Long placeId, VoteRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));
        Place place = placeRepository.findById(placeId)
                .orElseThrow(() -> BusinessException.notFound("장소를 찾을 수 없습니다"));

        placeVoteRepository.findByPlaceIdAndUserId(placeId, userId)
                .ifPresentOrElse(
                        vote -> {
                            if (vote.getVoteType() == request.voteType()) {
                                placeVoteRepository.delete(vote); // 같은 값 재투표 → 취소
                            } else {
                                vote.updateVote(request.voteType()); // 다른 값 → 변경
                            }
                        },
                        () -> placeVoteRepository.save(
                                PlaceVote.builder()
                                        .place(place)
                                        .user(user)
                                        .voteType(request.voteType())
                                        .build()
                        )
                );
    }

    private long countHelpful(Long placeId) {
        return placeVoteRepository.countHelpfulByPlaceId(placeId);
    }

    private String cacheKey(double lat, double lng, double radius, String category) {
        return Math.round(lat * 1000) + ":" + Math.round(lng * 1000) + ":" + (int) radius + ":" + category;
    }

    @SuppressWarnings("unchecked")
    private <T> T fromCache(String key) {
        Object[] entry = cache.get(key);
        if (entry == null) return null;
        if (System.currentTimeMillis() > (long) entry[1]) { cache.remove(key); return null; }
        return (T) entry[0];
    }

    private void toCache(String key, Object value) {
        cache.put(key, new Object[]{value, System.currentTimeMillis() + CACHE_TTL_MS});
    }
}
