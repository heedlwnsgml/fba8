package com.travel.planner.dto;

import lombok.Getter;
import lombok.Setter;

/** 숙소 한 곳(연속으로 묵는 한 구간)의 숙박비 */
@Getter
@Setter
public class LodgingCostDto {
    private java.util.List<java.util.Map<String,Object>> priceComparisons;
    private String priceAsOfDate; // 조회 당일 기준일, 날짜 미정 일정도 동일
    private String placeId;
    private String name;              // 숙소 이름
    private int checkInDay;           // 체크인 일차 (1부터)
    private int checkOutDay;          // 체크아웃 일차
    private String checkIn;           // 체크인 날짜 "2026-10-17" (날짜 미정 일정이면 null)
    private String checkOut;
    private int nights;               // 박 수
    private Integer totalYen;         // 이 숙소의 숙박비 합계 (일행 전체, 엔). 알 수 없으면 null
    private Integer lowestNightPerRoomYen; // 호텔 표시 최저가 (객실 1개·1박, 엔)
    private Integer perNightYen;      // 1박 요금 (일행 전체, 엔)
    // 값의 출처: "user"(직접 입력) / "rakuten-estimate"(호텔 표시 1실 1박 최저가) / null
    private String source;
    private String basis;             // 어떻게 계산했는지 한 문장
    private String matchedHotelName;  // 라쿠텐에서 찾은 숙소 이름 (이름이 맞는지 화면에서 확인할 수 있게)
    private String url;               // 라쿠텐 숙소 안내 페이지
}
