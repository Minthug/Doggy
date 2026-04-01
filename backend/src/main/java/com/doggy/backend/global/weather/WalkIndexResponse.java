package com.doggy.backend.global.weather;

public record WalkIndexResponse(
        WalkIndex index,
        String label,
        String emoji,
        String description,
        int temperature,
        int precipitationProbability,
        String precipitationType, // 없음, 비, 눈, 소나기
        int pm10,
        int pm25,
        String pm10Grade,  // 좋음, 보통, 나쁨, 매우나쁨
        String pm25Grade
) {
    public static WalkIndexResponse of(WalkIndex index, int tmp, int pop, int pty, int pm10, int pm25) {
        return new WalkIndexResponse(
                index,
                index.label,
                index.emoji,
                index.description,
                tmp,
                pop,
                precipitationLabel(pty),
                pm10,
                pm25,
                pm10Grade(pm10),
                pm25Grade(pm25)
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

    private static String pm10Grade(int pm10) {
        if (pm10 < 30) return "좋음";
        if (pm10 < 80) return "보통";
        if (pm10 < 150) return "나쁨";
        return "매우나쁨";
    }

    private static String pm25Grade(int pm25) {
        if (pm25 < 15) return "좋음";
        if (pm25 < 35) return "보통";
        if (pm25 < 75) return "나쁨";
        return "매우나쁨";
    }
}
