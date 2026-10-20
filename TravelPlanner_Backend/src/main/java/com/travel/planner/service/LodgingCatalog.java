package com.travel.planner.service;

import com.travel.planner.entity.Place;
import com.travel.planner.repository.PlaceRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import java.util.*;

/** Primary hotels take precedence. Supplemental hotel rows never change the supplied place table. */
@Service
public class LodgingCatalog {
    private final PlaceRepository places;
    private final JdbcTemplate jdbc;
    private static final ObjectMapper JSON = new ObjectMapper();
    public LodgingCatalog(PlaceRepository places, JdbcTemplate jdbc) { this.places=places;this.jdbc=jdbc; }
    static boolean located(Place p) {
        return p!=null && p.getLatitude()!=null && p.getLongitude()!=null
            && p.getLatitude()>=20 && p.getLatitude()<=46 && p.getLongitude()>=122 && p.getLongitude()<=154
            && p.getPlaceId()!=null && !p.getPlaceId().isBlank();
    }
    List<Place> supplemental(String city) {
        return jdbc.query("SELECT source_id,place_json FROM test_planner_app_metadata.supplemental_lodging WHERE city=? ORDER BY source_id",(rs,n)->{
            try {
                var j=JSON.readTree(rs.getString(2));Place p=new Place();p.setId(-rs.getLong(1));
                p.setName(j.path("name").asText());p.setNameKo(j.path("nameKo").asText(null));p.setCity(city);
                p.setCategory("숙소");p.setTheme("숙소");p.setPlaceId(j.path("placeId").asText());
                p.setLatitude(j.path("latitude").asDouble());p.setLongitude(j.path("longitude").asDouble());
                p.setAddress(j.path("address").asText(null));p.setPhone(j.path("phone").asText(null));
                p.setOpeningHours(j.path("openingHours").asText(null));p.setSummary(j.path("summary").asText(null));
                if(j.path("rating").isNumber())p.setRating(j.path("rating").asDouble());
                if(j.path("userRatingCount").isNumber())p.setUserRatingCount(j.path("userRatingCount").asInt());return p;
            } catch(Exception e) {throw new IllegalStateException("Stored hotel could not be read",e);}
        },city).stream().filter(LodgingCatalog::located).toList();
    }
    public List<Place> recommended(String city) {
        var primary=places.findByCity(city).stream().filter(PlanService::isLodging).filter(LodgingCatalog::located).toList();
        return primary.isEmpty()?supplemental(city):primary;
    }
    public Place findByName(String name,List<String> cities) {
        for(String city:cities) {
            var primary=places.findByCity(city).stream().filter(PlanService::isLodging).filter(LodgingCatalog::located).toList();
            for(Place p:primary)if(name.trim().equalsIgnoreCase(p.getName()) || name.trim().equalsIgnoreCase(p.shownName()))return p;
        }
        for(String city:cities)for(Place p:supplemental(city))
            if(name.trim().equalsIgnoreCase(p.getName()) || name.trim().equalsIgnoreCase(p.shownName()))return p;
        return null;
    }
    public Place storeFetched(Place p,String city) {
        if(!located(p))throw new PlanGenerationException(city+" 숙소의 위치를 확인하지 못했습니다.");
        var existing=places.findByPlaceId(p.getPlaceId());
        if(existing.isPresent() && PlanService.isLodging(existing.get()))return existing.get();
        Map<String,Object> values=new LinkedHashMap<>();values.put("name",p.getName());values.put("nameKo",p.getNameKo());
        values.put("placeId",p.getPlaceId());values.put("latitude",p.getLatitude());values.put("longitude",p.getLongitude());
        values.put("address",p.getAddress());values.put("phone",p.getPhone());values.put("openingHours",p.getOpeningHours());
        try {
            String json=JSON.writeValueAsString(values);
            jdbc.update("INSERT INTO test_planner_app_metadata.supplemental_lodging (city,place_id,place_json) VALUES (?,?,?) ON DUPLICATE KEY UPDATE city=VALUES(city),place_json=VALUES(place_json)",city,p.getPlaceId(),json);
            Long id=jdbc.queryForObject("SELECT source_id FROM test_planner_app_metadata.supplemental_lodging WHERE place_id=?",Long.class,p.getPlaceId());
            p.setId(-id);p.setCity(city);p.setCategory("숙소");return p;
        } catch(Exception e) {throw new IllegalStateException("Could not preserve recommended hotel",e);}
    }
}
