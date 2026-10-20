package com.travel.planner.service;

import com.travel.planner.dto.PlanRequest;
import com.travel.planner.entity.Place;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import java.util.*;

/** Average room/night prices are an auxiliary catalogue, never invented prices. */
@Service
public class HotelBudgetService {
    private final JdbcTemplate jdbc;
    public HotelBudgetService(JdbcTemplate jdbc) { this.jdbc=jdbc; }
    public Long price(Place place) {
        if(place==null || !PlanService.isLodging(place))return null;
        var rows=jdbc.queryForList("SELECT average_yen_per_room_night FROM test_planner_app_metadata.hotel_average_price WHERE place_id=? AND average_yen_per_room_night>0",place.getPlaceId());
        return rows.isEmpty()?null:((Number)rows.getFirst().get("average_yen_per_room_night")).longValue();
    }
    public void saveSettings(Long planId,PlanRequest request) {
        if(request.getHotelBudgetYen()==null)return;
        jdbc.update("INSERT INTO test_planner_app_metadata.plan_hotel_budget (planner_database,plan_id,hotel_budget_yen,hotel_budget_mode) VALUES (DATABASE(),?,?,?) ON DUPLICATE KEY UPDATE hotel_budget_yen=VALUES(hotel_budget_yen),hotel_budget_mode=VALUES(hotel_budget_mode)",planId,request.getHotelBudgetYen(),request.getHotelBudgetMode()==null?"perNight":request.getHotelBudgetMode());
    }
    public Map<String,Object> settings(Long planId) {
        var rows=jdbc.queryForList("SELECT hotel_budget_yen,hotel_budget_mode FROM test_planner_app_metadata.plan_hotel_budget WHERE planner_database=DATABASE() AND plan_id=?",planId);
        if(rows.isEmpty())return Map.of();
        var row=rows.getFirst();return Map.of("hotelBudgetYen",row.get("hotel_budget_yen"),"hotelBudgetMode",row.get("hotel_budget_mode"));
    }
    static long nightlyLimit(PlanRequest request,int nights) {
        if(request.getHotelBudgetYen()==null)return Long.MAX_VALUE;
        return "total".equals(request.getHotelBudgetMode())?request.getHotelBudgetYen()/Math.max(1,nights):request.getHotelBudgetYen();
    }
    public List<Place> eligible(List<Place> hotels,PlanRequest request,int nights,List<String> warnings) {
        if(request.getHotelBudgetYen()==null)return hotels;
        long limit=nightlyLimit(request,nights);
        var priced=new ArrayList<Place>(); var unknown=new ArrayList<Place>();
        for(var hotel:hotels) { Long price=price(hotel);if(price==null)unknown.add(hotel);else if(price<=limit)priced.add(hotel); }
        if(!priced.isEmpty())return priced;
        if(!unknown.isEmpty()) {
            String warning="평균 숙박요금 자료가 없는 숙소는 숙소 예산 충족 여부를 확인할 수 없습니다. 예약 전 객실 1개 기준 숙박요금을 확인해주세요.";
            if(!warnings.contains(warning))warnings.add(warning);
            return unknown;
        }
        throw new PlanGenerationException("입력한 숙소 요금 상한을 만족하는 숙소가 없습니다. 숙소 예산을 조정해주세요.");
    }
}
