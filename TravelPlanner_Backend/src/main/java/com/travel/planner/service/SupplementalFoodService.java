package com.travel.planner.service;
import com.travel.planner.entity.*;
import com.travel.planner.util.*;
import org.springframework.stereotype.Service;
import org.springframework.jdbc.core.JdbcTemplate;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
import java.time.LocalDate;
@Service
public class SupplementalFoodService {
    private final JdbcTemplate jdbc;
    private static final ObjectMapper JSON=placeMapper();
    private static ObjectMapper placeMapper(){
        var module=new com.fasterxml.jackson.databind.module.SimpleModule();
        module.addSerializer(java.time.LocalDateTime.class,new com.fasterxml.jackson.databind.JsonSerializer<java.time.LocalDateTime>(){
            @Override public void serialize(java.time.LocalDateTime value,com.fasterxml.jackson.core.JsonGenerator generator,com.fasterxml.jackson.databind.SerializerProvider provider) throws java.io.IOException {generator.writeString(value.toString());}
        });
        module.addDeserializer(java.time.LocalDateTime.class,new com.fasterxml.jackson.databind.JsonDeserializer<java.time.LocalDateTime>(){
            @Override public java.time.LocalDateTime deserialize(com.fasterxml.jackson.core.JsonParser parser,com.fasterxml.jackson.databind.DeserializationContext context) throws java.io.IOException {return java.time.LocalDateTime.parse(parser.getText());}
        });
        return new ObjectMapper().registerModule(module);
    }
    public SupplementalFoodService(JdbcTemplate jdbc){this.jdbc=jdbc;}
    public static boolean supplemental(Place p){return p!=null && p.getId()!=null && p.getId()<0;}
    public List<Place> candidates(String city){
        return jdbc.query("SELECT place_json FROM test_planner_app_metadata.supplemental_food WHERE city=? ORDER BY source_id",(rs,n)->{
            try {
                var j=JSON.readTree(rs.getString(1));Place p=new Place();p.setId(-j.path("sourceId").asLong());
                p.setName(j.path("name").asText());p.setCity(j.path("city").asText());p.setCategory("식음");
                p.setLatitude(j.path("latitude").asDouble());p.setLongitude(j.path("longitude").asDouble());p.setPlaceId(j.path("placeId").asText());
                p.setOpeningPeriods(j.path("openingPeriods").asText(null));
                p.setRating(j.path("rating").isNumber()?j.path("rating").asDouble():null);p.setUserRatingCount(j.path("userRatingCount").isNumber()?j.path("userRatingCount").asInt():null);
                p.setOpeningHours(j.path("openingHours").asText(null));p.setTheme(j.path("theme").asText("맛집"));
                p.setAddress(j.path("address").asText(null));p.setPhone(j.path("phone").asText(null));
                int duration=j.path("recommendedDuration").asInt(60);p.setRecommendedDuration(duration<=0?60:duration);
                String summary=j.path("summary").asText("");if(summary.matches("(?s).*[가-힣].*"))p.setSummary(summary);
                return p;
            }catch(Exception e){throw new IllegalStateException("Supplemental food record is invalid",e);}
        },city).stream().filter(p->!p.getName().toLowerCase().matches(".*(museum|artopia|temple|shrine|박물관|미술관|동조궁|공원).*"))
          .filter(p->PlaceKind.of(p)==PlaceKind.RESTAURANT || PlaceKind.of(p)==PlaceKind.BAR).toList();
    }
    /** Search results belong to the auxiliary catalogue; primary places are never rewritten. */
    public List<Place> cacheSearchResults(String city,List<Place> found){
        List<Place> result=new ArrayList<>();
        for(Place p:found){
            if(p.getPlaceId()==null || p.getPlaceId().isBlank())continue;
            if(PlaceKind.of(p)!=PlaceKind.RESTAURANT && PlaceKind.of(p)!=PlaceKind.BAR)continue;
            var existing=jdbc.queryForList("SELECT source_id FROM test_planner_app_metadata.supplemental_food WHERE place_id=?",Long.class,p.getPlaceId());
            long id;
            try {id=existing.isEmpty()?Long.parseLong(java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(p.getPlaceId().getBytes(java.nio.charset.StandardCharsets.UTF_8))).substring(0,15),16):existing.getFirst();}
            catch(java.security.NoSuchAlgorithmException e){throw new IllegalStateException(e);}
            p.setId(-id);p.setCity(city);p.setCategory("식음");p.setTheme("맛집");
            if(p.getRecommendedDuration()==null || p.getRecommendedDuration()<=0)p.setRecommendedDuration(60);
            var record=JSON.valueToTree(p);((com.fasterxml.jackson.databind.node.ObjectNode)record).put("sourceId",id);
            jdbc.update("INSERT INTO test_planner_app_metadata.supplemental_food (source_id,city,place_id,place_json) VALUES (?,?,?,?) ON DUPLICATE KEY UPDATE place_json=VALUES(place_json)",id,city,p.getPlaceId(),record.toString());
            result.add(p);
        }
        return result;
    }

    public void supplement(List<Place> main,List<String> cities){
        Set<String> known=new HashSet<>();for(var p:main)known.add(p.getPlaceId());
        for(String city:cities) {
            // Primary entries always win for the same place identity; extra restaurants remain secondary candidates.
            for(Place p:candidates(city))if(known.add(p.getPlaceId()))main.add(p);
        }
    }
    public void save(Itinerary itinerary,Place place){
        try{jdbc.update("INSERT INTO test_planner_app_metadata.itinerary_place (planner_database,itinerary_id,place_json) VALUES (DATABASE(),?,?) ON DUPLICATE KEY UPDATE place_json=VALUES(place_json)",itinerary.getId(),JSON.writeValueAsString(place));}
        catch(Exception e){throw new IllegalStateException("Could not preserve supplemental itinerary place",e);}
    }
    public Map<Long,Place> load(List<Itinerary> items){
        Map<Long,Place> result=new HashMap<>();if(items.isEmpty())return result;
        var params=items.stream().map(Itinerary::getId).toArray();
        String placeholders=String.join(",",Collections.nCopies(params.length,"?"));
        jdbc.query("SELECT itinerary_id,place_json FROM test_planner_app_metadata.itinerary_place WHERE planner_database=DATABASE() AND itinerary_id IN ("+placeholders+")",(org.springframework.jdbc.core.RowCallbackHandler)rs->{
            try{result.put(rs.getLong(1),JSON.readValue(rs.getString(2),Place.class));}catch(Exception e){throw new IllegalStateException("Stored supplemental place could not be read",e);}
        },params);return result;
    }
    public int[] mealWindow(Plan plan,Itinerary item,Place previous,Place meal,Place next){
        int travel=TravelTimeEstimator.minutes(previous.getLatitude(),previous.getLongitude(),meal.getLatitude(),meal.getLongitude(),plan.getTransportation());
        int back=next==null?0:TravelTimeEstimator.minutes(meal.getLatitude(),meal.getLongitude(),next.getLatitude(),next.getLongitude(),plan.getTransportation());
        int arrival=TimeUtil.parseClock(item.getTime())+travel,limit=TimeUtil.parseClock(item.getEndTime())-back;
        for(var iv:OpeningHours.intervalsOn(meal,plan.dateOfDay(item.getDayNumber()))){
            int start=Math.max(arrival,iv[0]),end=Math.min(limit,iv[1]);
            if(end-start>=30)return new int[]{start,end};
        }
        throw new IllegalStateException("Meal no longer fits the available window");
    }
    public Place mealAt(Plan plan,Itinerary item,Place previous,Place next,Set<String> used,List<Place> main){
        if(previous==null || previous.getCity()==null || item.getEndTime()==null)return null;
        List<Place> pool=new ArrayList<>(main);supplement(pool,List.of(previous.getCity()));
        int begin=TimeUtil.parseClock(item.getTime()),end=TimeUtil.parseClock(item.getEndTime());LocalDate date=plan.dateOfDay(item.getDayNumber());
        return pool.stream().filter(p->previous.getCity().equals(p.getCity()))
            .filter(p->PlaceKind.of(p)==PlaceKind.RESTAURANT || PlaceKind.of(p)==PlaceKind.BAR)
            .filter(p->PlaceKind.of(p)!=PlaceKind.BAR || begin>=17*60+30)
            .filter(p->!used.contains(p.getPlaceId()))
            .filter(p->{
                int travel=TravelTimeEstimator.minutes(previous.getLatitude(),previous.getLongitude(),p.getLatitude(),p.getLongitude(),plan.getTransportation());
                if(travel>20)return false;
                int back=next==null?0:TravelTimeEstimator.minutes(p.getLatitude(),p.getLongitude(),next.getLatitude(),next.getLongitude(),plan.getTransportation());
                int arrival=begin+travel;if(arrival+30+back>end)return false;
                var hours=OpeningHours.intervalsOn(p,date);if(hours==null)return false;
                return hours.stream().anyMatch(iv->Math.max(arrival,iv[0])+30+back<=Math.min(end,iv[1]));
            }).min(Comparator.<Place>comparingInt(p->supplemental(p)?1:0).thenComparingDouble(p->DistanceUtil.calculateDistance(previous.getLatitude(),previous.getLongitude(),p.getLatitude(),p.getLongitude()))).orElse(null);
    }
}
