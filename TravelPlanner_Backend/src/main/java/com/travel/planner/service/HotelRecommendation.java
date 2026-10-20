package com.travel.planner.service;

import com.travel.planner.entity.Place;
import com.travel.planner.util.DistanceUtil;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import java.util.*;

/** Geography remains primary. Information quality and recent choices distinguish nearby hotels. */
@Service
public class HotelRecommendation {
    private final JdbcTemplate jdbc;
    private final KoreanPlaceDescriptions descriptions;
    public HotelRecommendation(JdbcTemplate jdbc,KoreanPlaceDescriptions descriptions){this.jdbc=jdbc;this.descriptions=descriptions;}
    public Place select(List<Place> hotels,double[] center,String email) {
        return selectNearby(hotels,center,recent(email),descriptions);
    }
    Set<String> recent(String email) {
        if(email==null || email.isBlank())return Set.of();
        return new HashSet<>(jdbc.queryForList("SELECT DISTINCT COALESCE(JSON_UNQUOTE(JSON_EXTRACT(m.place_json,'$.placeId')),pl.place_id) FROM itinerary i JOIN plan p ON p.id=i.plan_id JOIN users u ON u.id=p.user_id JOIN place pl ON pl.id=i.place_id LEFT JOIN test_planner_app_metadata.itinerary_place m ON m.itinerary_id=i.id AND m.planner_database=DATABASE() WHERE u.email=? AND p.id=(SELECT MAX(p2.id) FROM plan p2 WHERE p2.user_id=u.id) AND (pl.category='숙소' OR JSON_UNQUOTE(JSON_EXTRACT(m.place_json,'$.category'))='숙소')",String.class,email));
    }
    static Place selectNearby(List<Place> hotels,double[] center,Set<String> recent,KoreanPlaceDescriptions descriptions) {
        if(hotels.isEmpty())throw new IllegalArgumentException("No hotel candidates");
        double nearest=hotels.stream().mapToDouble(p->distance(p,center)).min().orElse(0);
        // Diversity must not send travelers across the city. Keep candidates within 1.5 km of the closest candidate's distance.
        return hotels.stream().filter(p->distance(p,center)<=nearest+1.5)
            .min(Comparator.comparingDouble((Place p)->distance(p,center)+missingInfo(p,descriptions)+(recent.contains(p.getPlaceId())?2.0:0))
                .thenComparing(p->p.getPlaceId()==null?"":p.getPlaceId())).orElse(hotels.getFirst());
    }
    static double distance(Place p,double[] center){return center==null?0:DistanceUtil.calculateDistance(center[0],center[1],p.getLatitude(),p.getLongitude());}
    static double missingInfo(Place p,KoreanPlaceDescriptions descriptions) {
        double penalty=0;
        if(p.getAddress()==null || p.getAddress().isBlank())penalty+=0.35;
        if(p.getPhone()==null || p.getPhone().isBlank())penalty+=0.15;
        String summary=descriptions==null?p.getSummary():descriptions.summary(p);
        if(summary==null || summary.isBlank() || KoreanPlaceDescriptions.genericLodging(summary))penalty+=0.5;
        // Missing opening hours do not mean a hotel is closed, and invented 24-hour hours must never be a prerequisite.
        return penalty;
    }
}
