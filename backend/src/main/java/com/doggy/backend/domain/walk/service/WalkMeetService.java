package com.doggy.backend.domain.walk.service;

import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.dog.repository.DogFavoriteRepository;
import com.doggy.backend.domain.dog.repository.DogRepository;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.walk.dto.WalkMeetResponse;
import com.doggy.backend.domain.walk.entity.WalkPingLog;
import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.repository.WalkPingLogRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import com.doggy.backend.global.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class WalkMeetService {

    private final WalkPingLogRepository walkPingLogRepository;
    private final WalkSessionRepository walkSessionRepository;
    private final DogRepository dogRepository;
    private final DogFavoriteRepository dogFavoriteRepository;

    @Transactional(readOnly = true)
    public List<WalkMeetResponse> getMeets(Long userId, Long sessionId) {
        WalkSession session = walkSessionRepository.findById(sessionId)
                .orElseThrow(() -> BusinessException.notFound("산책 세션을 찾을 수 없습니다"));

        if (!session.getUser().getId().equals(userId)) {
            throw BusinessException.badRequest("본인의 산책 세션이 아닙니다");
        }

        List<WalkPingLog> logs = walkPingLogRepository.findAllBySessionId(sessionId);
        if (logs.isEmpty()) return List.of();

        // 상대방 세션 ID 수집 (중복 제거)
        List<Long> otherIds = logs.stream()
                .map(log -> log.getSessionAId().equals(sessionId) ? log.getSessionBId() : log.getSessionAId())
                .distinct()
                .toList();

        // 1 query: JOIN FETCH user 로 상대방 세션 + 유저 한 번에 조회
        Map<Long, WalkSession> sessionMap = walkSessionRepository.findAllByIdWithUser(otherIds).stream()
                .collect(Collectors.toMap(WalkSession::getId, s -> s));

        // @BatchSize(30) 덕분에 getDogs() 접근 시 Hibernate가 세션들 dogs를 한 번에 IN 쿼리로 로드
        // dogs가 비어있는 세션의 유저 ID 수집 → 유저별 강아지 일괄 조회
        List<Long> emptyDogUserIds = sessionMap.values().stream()
                .filter(s -> s.getDogs().isEmpty())
                .map(s -> s.getUser().getId())
                .distinct()
                .toList();

        // 1 query: dogs 없는 세션들의 유저 강아지 한 번에 조회
        Map<Long, List<Dog>> dogsByUserId = emptyDogUserIds.isEmpty()
                ? Map.of()
                : dogRepository.findAllByUserIdIn(emptyDogUserIds).stream()
                        .collect(Collectors.groupingBy(d -> d.getUser().getId()));

        Set<Long> myFavoritedDogIds = dogFavoriteRepository.findFavoritedDogIdsByUserId(userId);

        return logs.stream()
                .map(log -> {
                    Long otherId = log.getSessionAId().equals(sessionId)
                            ? log.getSessionBId() : log.getSessionAId();
                    WalkSession other = sessionMap.get(otherId);
                    if (other == null) return null;
                    User otherUser = other.getUser();
                    List<Dog> dogs = !other.getDogs().isEmpty()
                            ? other.getDogs()
                            : dogsByUserId.getOrDefault(otherUser.getId(), List.of());
                    return buildResponse(log, otherUser, dogs, myFavoritedDogIds);
                })
                .filter(Objects::nonNull)
                .toList();
    }

    private WalkMeetResponse buildResponse(WalkPingLog log, User otherUser, List<Dog> dogs, Set<Long> favoritedDogIds) {
        var userInfo = new WalkMeetResponse.UserInfo(
                otherUser.getId(),
                otherUser.getNickname(),
                otherUser.getProfileImage()
        );
        List<WalkMeetResponse.DogInfo> dogInfos = dogs.stream()
                .map(dog -> new WalkMeetResponse.DogInfo(
                        dog.getId(),
                        dog.getName(),
                        dog.getBreed(),
                        dog.getProfileImage(),
                        dog.getWarnings(),
                        favoritedDogIds.contains(dog.getId())
                ))
                .toList();
        return new WalkMeetResponse(log.getPingedAt(), userInfo, dogInfos);
    }
}
