package com.doggy.backend.domain.walk.service;

import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.dog.repository.DogRepository;
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

@Service
@RequiredArgsConstructor
public class WalkMeetService {

    private final WalkPingLogRepository walkPingLogRepository;
    private final WalkSessionRepository walkSessionRepository;
    private final DogRepository dogRepository;

    @Transactional(readOnly = true)
    public List<WalkMeetResponse> getMeets(Long userId, Long sessionId) {
        WalkSession session = walkSessionRepository.findById(sessionId)
                .orElseThrow(() -> BusinessException.notFound("산책 세션을 찾을 수 없습니다"));

        if (!session.getUser().getId().equals(userId)) {
            throw BusinessException.badRequest("본인의 산책 세션이 아닙니다");
        }

        return walkPingLogRepository.findAllBySessionId(sessionId).stream()
                .map(log -> toResponse(sessionId, log))
                .toList();
    }

    private WalkMeetResponse toResponse(Long mySessionId, WalkPingLog log) {
        Long otherSessionId = log.getSessionAId().equals(mySessionId)
                ? log.getSessionBId()
                : log.getSessionAId();

        WalkSession otherSession = walkSessionRepository.findById(otherSessionId)
                .orElseThrow(() -> BusinessException.notFound("상대방 산책 세션을 찾을 수 없습니다"));

        var otherUser = otherSession.getUser();
        List<Dog> dogs = otherSession.getDogs().isEmpty()
                ? dogRepository.findAllByUserId(otherUser.getId())
                : otherSession.getDogs();

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
                        dog.getWarnings()
                ))
                .toList();

        return new WalkMeetResponse(log.getPingedAt(), userInfo, dogInfos);
    }
}
