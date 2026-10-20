package com.travel.planner.service;

import com.travel.planner.entity.Place;
import com.travel.planner.util.PlaceDescriber;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import java.util.*;

/** Read-only overlays: the user-supplied place table is never modified. */
@Service
public class KoreanPlaceDescriptions {
    private final JdbcTemplate jdbc;
    private final Map<String,String> lodgingTimes=new java.util.concurrent.ConcurrentHashMap<>();
    private final Map<String,String> descriptions;
    public KoreanPlaceDescriptions(JdbcTemplate jdbc) {
        this.jdbc=jdbc;
        Map<String,String> loaded=new HashMap<>();
        jdbc.query("SELECT place_id,summary_ko FROM test_planner_app_metadata.place_description WHERE planner_database=DATABASE()", (org.springframework.jdbc.core.RowCallbackHandler)rs -> loaded.put(rs.getString(1),rs.getString(2)));
        descriptions=Map.copyOf(loaded);
    }
    static boolean genericLodging(String text) {
        if(text==null)return true;
        String value=text.trim();
        return value.equals("여행 중 머무는 숙소") || value.equals("숙소 출발") || value.equals("숙소 도착 및 휴식")
            || value.contains("하루 일정 후 휴식하고 다음 날 여행을 시작하는 거점")
            || value.contains("토요코인의 기본적인 숙박 서비스와 조식을 제공합니다");
    }
    public String hours(Place place,java.time.LocalDate date) {
        if(PlanService.isLodging(place) && place.getPlaceId()!=null) {
            String guide=lodgingTimes.computeIfAbsent(place.getPlaceId(),id -> {
                var rows=jdbc.queryForList("SELECT JSON_UNQUOTE(JSON_EXTRACT(place_json,'$.checkInTime')) AS check_in, JSON_UNQUOTE(JSON_EXTRACT(place_json,'$.checkOutTime')) AS check_out, JSON_UNQUOTE(JSON_EXTRACT(place_json,'$.frontDeskHours')) AS front_desk FROM test_planner_app_metadata.supplemental_lodging WHERE place_id=?",id);
                if(rows.isEmpty())return "";
                var row=rows.getFirst();Object in=row.get("check_in"),out=row.get("check_out"),desk=row.get("front_desk");
                if(in==null || out==null || "null".equals(in) || "null".equals(out))return "";
                return "체크인 "+in+" · 체크아웃 "+out+(desk==null || "null".equals(desk)?"":" · 프런트 "+desk);
            });
            if(!guide.isBlank())return guide;
        }
        return com.travel.planner.util.OpeningHours.describe(place,date);
    }
    public String summary(Place place) {
        if(place==null)return null;
        if(place.getSummary()!=null && !place.getSummary().isBlank() && !"정보 없음".equals(place.getSummary().trim()) && !genericLodging(place.getSummary()))return place.getSummary();
        String verified=descriptions.get(place.getPlaceId());
        if(verified!=null)return verified;
        if(PlanService.isLodging(place))return "";
        return PlaceDescriber.summaryOf(place);
    }
}
