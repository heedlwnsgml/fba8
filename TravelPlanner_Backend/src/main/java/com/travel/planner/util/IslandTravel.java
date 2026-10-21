package com.travel.planner.util;


/** Keep unsupported sea crossings out of terrestrial time and taxi fare estimates. */
public final class IslandTravel {
    private IslandTravel() {}

    public static String island(double lat, double lng) {
        if(lat>=24.5 && lat<=25.1 && lng>=125.0 && lng<=125.7)return "미야코섬";
        if(lat>=24.2 && lat<=24.7 && lng>=124.0 && lng<=124.5)return "이시가키섬";
        if(lat>=26.0 && lat<=27.0 && lng>=127.5 && lng<=128.5)return "오키나와섬";
        if(lat>=30.2 && lat<=30.5 && lng>=130.3 && lng<=130.8)return "야쿠섬";
        if(lat>=28.0 && lat<=28.6 && lng>=129.0 && lng<=129.8)return "아마미섬";
        if(lat>=37.7 && lat<=38.4 && lng>=138.1 && lng<=138.6)return "사도섬";
        return "육상 연결 지역"; // Honshu, Hokkaido, Shikoku and Kyushu have land/rail connections.
    }
    public static boolean crossesSea(double a,double b,double c,double d) {
        return !island(a,b).equals(island(c,d));
    }
}
