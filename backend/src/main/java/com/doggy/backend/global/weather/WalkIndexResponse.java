package com.doggy.backend.global.weather;

public record WalkIndexResponse(
        WalkIndex index,
        String label,
        String emoji,
        String description,
        int temperature,
        int precipitationProbability,
        String precipitationType, // 없음, 비, 눈, 소나기
        Integer pm10,
        Integer pm25,
        String pm10Grade,  // 좋음, 보통, 나쁨, 매우나쁨, 정보 없음
        String pm25Grade,
        boolean airQualityAvailable
) {
    public static WalkIndexResponse of(WalkIndex index, int tmp, int pop, int pty, Integer pm10, Integer pm25, String pm10Grade, String pm25Grade) {
        boolean airQualityAvailable = pm10 != null && pm25 != null;
        return new WalkIndexResponse(
                index,
                index.label,
                index.emoji,
                airQualityAvailable
                        ? index.description
                        : index.description + " 미세먼지 정보는 현재 확인할 수 없어요.",
                tmp,
                pop,
                precipitationLabel(pty),
                pm10,
                pm25,
                pm10Grade,
                pm25Grade,
                airQualityAvailable
        );
    }

    private static String precipitationLabel(int pty) {
        return switch (pty) {
            case 1 -> "비";
            case 2 -> "비/눈";
            case 3 -> "눈";
            case 4 -> "소나기";
            default -> "없음";
        };
    }

}
