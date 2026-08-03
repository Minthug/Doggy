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
import com.doggy.backend.global.common.RequestLimits;
import com.doggy.backend.global.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PlaceService {

    private final PlaceRepository placeRepository;
    private final PlaceVoteRepository placeVoteRepository;
    private final UserRepository userRepository;

    public List<PlaceResponse> findNearby(double lat, double lng, Double radiusMeters) {
        RequestLimits.validateLatLng(lat, lng);
        double radius = RequestLimits.clampRadiusMeters(radiusMeters);
        List<Place> places = placeRepository.findNearby(lat, lng, radius);
        return toResponses(places);
    }

    public List<PlaceResponse> findNearbyByCategory(double lat, double lng, Double radiusMeters, Category category) {
        RequestLimits.validateLatLng(lat, lng);
        double radius = RequestLimits.clampRadiusMeters(radiusMeters);
        List<Place> places = placeRepository.findNearbyByCategory(lat, lng, radius, category.name());
        return toResponses(places);
    }

    public PlaceResponse getPlace(Long placeId) {
        Place place = placeRepository.findById(placeId)
                .orElseThrow(() -> BusinessException.notFound("장소를 찾을 수 없습니다"));
        return PlaceResponse.of(place, countHelpful(placeId));
    }

    @Transactional(readOnly = false)
    public PlaceResponse create(Long userId, CreatePlaceRequest request) {
        RequestLimits.validateLatLng(request.lat(), request.lng());
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
                                placeVoteRepository.delete(vote);
                            } else {
                                vote.updateVote(request.voteType());
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

    private long countHelpful(Long placeId) {
        return placeVoteRepository.countHelpfulByPlaceId(placeId);
    }
}
