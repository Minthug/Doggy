package com.doggy.backend.domain.walk.dto;

import java.util.List;

public record StartWalkRequest(List<Long> dogIds) {}
