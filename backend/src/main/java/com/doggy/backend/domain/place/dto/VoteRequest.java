package com.doggy.backend.domain.place.dto;

import com.doggy.backend.domain.place.entity.PlaceVote.VoteType;
import jakarta.validation.constraints.NotNull;

public record VoteRequest(

        @NotNull
        VoteType voteType
) {}
