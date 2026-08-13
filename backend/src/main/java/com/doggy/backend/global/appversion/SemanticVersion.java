package com.doggy.backend.global.appversion;

import java.util.ArrayList;
import java.util.List;

record SemanticVersion(List<Integer> numbers) implements Comparable<SemanticVersion> {

    static SemanticVersion parse(String value) {
        if (value == null || value.isBlank()) {
            return new SemanticVersion(List.of(0));
        }

        String version = value.trim();
        int buildIndex = version.indexOf('+');
        if (buildIndex >= 0) {
            version = version.substring(0, buildIndex);
        }
        int preReleaseIndex = version.indexOf('-');
        if (preReleaseIndex >= 0) {
            version = version.substring(0, preReleaseIndex);
        }

        String[] parts = version.split("\\.");
        List<Integer> numbers = new ArrayList<>();
        for (String part : parts) {
            numbers.add(parseNumber(part));
        }
        return new SemanticVersion(numbers);
    }

    private static int parseNumber(String value) {
        if (value == null || value.isBlank()) {
            return 0;
        }
        try {
            return Integer.parseInt(value);
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    @Override
    public int compareTo(SemanticVersion other) {
        int size = Math.max(numbers.size(), other.numbers.size());
        for (int i = 0; i < size; i++) {
            int left = i < numbers.size() ? numbers.get(i) : 0;
            int right = i < other.numbers.size() ? other.numbers.get(i) : 0;
            int result = Integer.compare(left, right);
            if (result != 0) {
                return result;
            }
        }
        return 0;
    }
}
