package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.entity.QWalkSession;
import com.doggy.backend.domain.walk.entity.WalkSession.Status;
import com.querydsl.core.types.dsl.BooleanExpression;
import com.querydsl.jpa.JPAExpressions;
import com.querydsl.jpa.impl.JPAQueryFactory;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
@RequiredArgsConstructor
public class WalkSessionRepositoryImpl implements WalkSessionRepositoryCustom {

    private final JPAQueryFactory queryFactory;

    private static final QWalkSession session = QWalkSession.walkSession;

    @Override
    public List<Long> findHistoryIdsByUserId(
            Long userId, Long householdId, LocalDateTime householdJoinedAt, Pageable pageable) {
        return queryFactory
                .select(session.id)
                .from(session)
                .where(
                        session.status.ne(Status.ABANDONED),
                        ownerOrHousehold(userId, householdId, householdJoinedAt)
                )
                .orderBy(session.startedAt.desc())
                .offset(pageable.getOffset())
                .limit(pageable.getPageSize())
                .fetch();
    }

    @Override
    public List<Long> findUserIdsNotWalkedSince(LocalDateTime since) {
        QWalkSession recentWalk = new QWalkSession("recentWalk");

        return queryFactory
                .selectDistinct(session.user.id)
                .from(session)
                .where(
                        session.status.eq(Status.COMPLETED),
                        session.user.fcmToken.isNotNull(),
                        JPAExpressions
                                .selectFrom(recentWalk)
                                .where(
                                        recentWalk.user.eq(session.user),
                                        recentWalk.status.eq(Status.COMPLETED),
                                        recentWalk.startedAt.goe(since)
                                )
                                .notExists()
                )
                .fetch();
    }

    // 내 미중단 세션 OR 산책 당시 같은 가족이었던 완료 세션
    private BooleanExpression ownerOrHousehold(
            Long userId, Long householdId, LocalDateTime householdJoinedAt) {
        BooleanExpression isOwner = session.user.id.eq(userId);
        if (householdId == null || householdJoinedAt == null) return isOwner;

        BooleanExpression isCompletedHouseholdWalk = session.householdId.eq(householdId)
                .and(session.status.eq(Status.COMPLETED))
                .and(session.startedAt.goe(householdJoinedAt));
        return isOwner.or(isCompletedHouseholdWalk);
    }
}
