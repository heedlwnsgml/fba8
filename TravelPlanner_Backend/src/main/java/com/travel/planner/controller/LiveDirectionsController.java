package com.travel.planner.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.client.RestTemplate;
import java.time.Instant;
import java.util.*;

/** On-demand current Google routes, deliberately separate from saved itinerary estimates. */
@RestController
@RequestMapping("/api/v1/routes")
public class LiveDirectionsController {
    @Value("${google.maps.api-key:}") private String key;
    private final RestTemplate http;
    private final ObjectMapper json=new ObjectMapper();
    public LiveDirectionsController(RestTemplate http) {this.http=http;}
    public record Request(@NotBlank @Size(max=250) String origin,@NotBlank @Size(max=250) String destination,
        @Pattern(regexp="transit|walking|driving|bicycling") String mode) {}
    @PostMapping("/live")
    public Map<String,Object> live(@Valid @RequestBody Request request) {
        if(key.isBlank())return unavailable("경로 조회 설정을 확인해야 합니다.");
        String mode=switch(request.mode()==null?"transit":request.mode()) {
            case "walking" -> "WALK";case "driving" -> "DRIVE";case "bicycling" -> "BICYCLE";default -> "TRANSIT";
        };
        if(mode.equals("TRANSIT") && inJapan(request.origin()) && inJapan(request.destination()))
            return Map.of("routes",List.of(),"providerUnsupported",true,"message","일본 대중교통의 실시간 환승 안내는 Google 지도 화면에서 확인할 수 있습니다.");
        Map<String,Object> body=new LinkedHashMap<>();
        body.put("origin",waypoint(request.origin()));body.put("destination",waypoint(request.destination()));
        body.put("travelMode",mode);body.put("languageCode","ko");body.put("regionCode","JP");body.put("units","METRIC");
        body.put("computeAlternativeRoutes",true);
        if(mode.equals("TRANSIT") || mode.equals("DRIVE"))body.put("departureTime",Instant.now().plusSeconds(30).toString());
        if(mode.equals("DRIVE"))body.put("routingPreference","TRAFFIC_AWARE");
        HttpHeaders headers=new HttpHeaders();headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("X-Goog-Api-Key",key);headers.set("X-Goog-FieldMask","routes.duration,routes.distanceMeters,routes.legs.steps,routes.description");
        try {
            var response=http.postForEntity("https://routes.googleapis.com/directions/v2:computeRoutes",new HttpEntity<>(body,headers),String.class);
            JsonNode root=json.readTree(response.getBody());
            List<Map<String,Object>> routes=new ArrayList<>();
            for(JsonNode route:root.path("routes"))routes.add(route(route));
            if(routes.isEmpty())return unavailable("현재 출발 기준으로 이용 가능한 경로를 찾지 못했습니다.");
            return Map.of("routes",routes,"checkedAt",Instant.now().toString(),"source","Google Maps");
        } catch(RestClientResponseException e) {
            String reason="경로를 불러오지 못했습니다. 잠시 후 다시 조회해 주세요.";
            if(e.getStatusCode().value()==403)reason="Google 경로 조회 권한 또는 결제 설정을 확인해야 합니다.";
            if(e.getStatusCode().value()==429)reason="현재 경로 조회 한도를 초과했습니다. 잠시 후 다시 조회해 주세요.";
            System.out.println("[실시간 경로] Google HTTP "+e.getStatusCode().value());
            return unavailable(reason);
        } catch(Exception e) {return unavailable("실시간 경로를 불러오지 못했습니다. 다시 조회해 주세요.");}
    }
    private Map<String,Object> unavailable(String message) {return Map.of("routes",List.of(),"message",message);}
    static boolean inJapan(String value) {
        try {
            String[] p=value.split(",");if(p.length!=2)return false;
            double lat=Double.parseDouble(p[0]),lng=Double.parseDouble(p[1]);
            return lat>=24 && lat<=46 && lng>=122 && lng<=154;
        } catch(Exception e) {return false;}
    }
    static Map<String,Object> waypoint(String value) {
        if(value.matches("-?\\d+(?:\\.\\d+)?,-?\\d+(?:\\.\\d+)?")) {
            String[] p=value.split(",");double lat=Double.parseDouble(p[0]),lng=Double.parseDouble(p[1]);
            if(Math.abs(lat)<=90 && Math.abs(lng)<=180)return Map.of("location",Map.of("latLng",Map.of("latitude",lat,"longitude",lng)));
        }
        return Map.of("address",value);
    }
    static int minutes(JsonNode node) {
        try{return (int)Math.ceil(Double.parseDouble(node.asText("0s").replace("s",""))/60);}catch(Exception e){return 0;}
    }
    static Map<String,Object> route(JsonNode route) {
        List<Map<String,Object>> steps=new ArrayList<>();
        for(JsonNode leg:route.path("legs"))for(JsonNode step:leg.path("steps")) {
            JsonNode transit=step.path("transitDetails"),line=transit.path("transitLine"),stops=transit.path("stopDetails");
            Map<String,Object> row=new LinkedHashMap<>();
            row.put("mode",step.path("travelMode").asText());
            row.put("minutes",minutes(step.path("staticDuration")));row.put("instruction",step.path("navigationInstruction").path("instructions").asText());
            row.put("line",line.path("nameShort").asText(line.path("name").asText()));
            row.put("from",stops.path("departureStop").path("name").asText());row.put("to",stops.path("arrivalStop").path("name").asText());
            row.put("headsign",transit.path("headsign").asText());row.put("stopCount",transit.path("stopCount").asInt());
            row.put("departureTime",transit.path("localizedValues").path("departureTime").path("time").asText());
            row.put("arrivalTime",transit.path("localizedValues").path("arrivalTime").path("time").asText());
            steps.add(row);
        }
        return Map.of("title",route.path("description").asText(),"minutes",minutes(route.path("duration")),"distanceMeters",route.path("distanceMeters").asInt(),"steps",steps);
    }
}
