package com.doggy.backend.global.weather;

public enum WalkIndex {
    GOOD("산책 좋음", "🟢", "오늘 산책하기 딱 좋은 날씨예요!"),
    CAUTION("산책 주의", "🟡", "산책은 가능하지만 짧게 다녀오세요."),
    AVOID("산책 자제", "🔴", "오늘은 실내에서 놀아주세요.");

    public final String label;
    public final String emoji;
    public final String description;

    WalkIndex(String label, String emoji, String description) {
        this.label = label;
        this.emoji = emoji;
        this.description = description;
    }
}
