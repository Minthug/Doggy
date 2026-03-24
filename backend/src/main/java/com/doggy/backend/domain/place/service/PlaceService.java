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

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PlaceService {

    private static final double DEFAULT_RADIUS_METERS = 1000;

    private final PlaceRepository placeRepository;
    private final PlaceVoteRepository placeVoteRepository;
    private final UserRepository userRepository;

    // 반경 내 전체 장소 검색
    public List<PlaceResponse> findNearby(double lat, double lng, Double radiusMeters) {
        double radius = radiusMeters != null ? radiusMeters : DEFAULT_RADIUS_METERS;
        return placeRepository.findNearby(lat, lng, radius).stream()
                .map(place -> PlaceResponse.of(place, countHelpful(place.getId())))
                .toList();
    }

    // 반경 내 카테고리별 장소 검색
    public List<PlaceResponse> findNearbyByCategory(double lat, double lng, Double radiusMeters, Category category) {
        double radius = radiusMeters != null ? radiusMeters : DEFAULT_RADIUS_METERS;
        return placeRepository.findNearbyByCategory(lat, lng, radius, category.name()).stream()
                .map(place -> PlaceResponse.of(place, countHelpful(place.getId())))
                .toList();
    }

    // 장소 단건 조회
    public PlaceResponse getPlace(Long placeId) {
        Place place = placeRepository.findById(placeId)
                .orElseThrow(() -> BusinessException.notFound("장소를 찾을 수 없습니다"));
        return PlaceResponse.of(place, countHelpful(placeId));
    }

    // 유저가 직접 장소 등록 (크라우드소싱)
    @Transactional
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
    @Transactional
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
}
