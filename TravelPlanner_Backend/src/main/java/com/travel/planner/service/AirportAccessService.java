package com.travel.planner.service;
import com.travel.planner.dto.*;
import com.travel.planner.entity.Place;
import com.travel.planner.util.DistanceUtil;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import java.util.*;

/** The airport's access is shown inside its card, using the actual boarding stop. */
@Service
public class AirportAccessService {
 private final JdbcTemplate jdbc;private final RailRouteService routes;
 public AirportAccessService(JdbcTemplate jdbc,RailRouteService routes){this.jdbc=jdbc;this.routes=routes;}
 public void add(List<PlanService.DayPlan> days,String mode,List<String> warnings) {
  // Access is part of the airport card, not another timed sightseeing visit.
 }
 public static boolean haneda(String name){
  return name!=null && name.matches("(?is).*(하네다|羽田|haneda|AIRPORT_HND).*")
    && !name.matches("(?is).*(hotel|호텔|숙소|ホテル|旅館|전망대|展望台|공원|公園).*")
    && (name.matches("(?is).*(공항|空港|airport|terminal|터미널|ターミナル).*") || name.matches("(?is)(하네다|羽田|haneda)"));
 }
 /** Terminal not specified: use the international T3 hub, never an airport centroid on the apron. */
 public static double[] routingPoint(String name,double lat,double lng) {
  if(!haneda(name))return new double[]{lat,lng};
  if(name.matches("(?is).*(제?\\s*2|第2|terminal\\s*2).*") )return new double[]{35.550795,139.7882};
  if(name.matches("(?is).*(제?\\s*1|第1|terminal\\s*1).*") )return new double[]{35.54914,139.78461};
  return new double[]{35.54498,139.7670665};
 }
 public Map<String,Object> details(String airport,double latitude,double longitude,TransitLegDto leg) {
  if(leg==null)return Map.of();
  var ride=leg.getSteps().stream().filter(s->"승차".equals(s.getType()) && !"택시".equals(s.getCategory())).findFirst().orElse(null);
  if(ride==null)return Map.of();
  String boarding=ride.getFromOriginal()!=null?ride.getFromOriginal():ride.getFrom();if(boarding==null || boarding.isBlank())return Map.of();
  var names=new LinkedHashSet<String>();names.add(boarding);
  names.addAll(jdbc.queryForList("SELECT ja FROM transit_name WHERE kind='STATION' AND ko=?",String.class,boarding));
  var points=new ArrayList<Map<String,Object>>();
  for(String name:names){
   points.addAll(jdbc.queryForList("SELECT name,latitude,longitude FROM transit_station WHERE name=?",name));
   points.addAll(jdbc.queryForList("SELECT name,latitude,longitude FROM transit_stop WHERE name=?",name));
  }
  var origin=routingPoint(airport,latitude,longitude);
  var point=points.stream().filter(p->p.get("latitude") instanceof Number && p.get("longitude") instanceof Number)
    .filter(p->DistanceUtil.calculateDistance(origin[0],origin[1],((Number)p.get("latitude")).doubleValue(),((Number)p.get("longitude")).doubleValue())<=3)
    .min(Comparator.comparingDouble(p->DistanceUtil.calculateDistance(origin[0],origin[1],((Number)p.get("latitude")).doubleValue(),((Number)p.get("longitude")).doubleValue()))).orElse(null);
  if(point==null)return Map.of();
  String original=(String)point.get("name");
  String terminal=original.replaceAll("駅$", "");
  String lobby=terminal;
  if(haneda(airport))lobby=original.contains("羽田")?terminal:"羽田空港第3ターミナル";
  else if(!terminal.matches("(?is).*(空港|ターミナル|terminal|공항|터미널).*"))lobby=airport+" 到着ロビー";
  if(!lobby.endsWith("到着ロビー"))lobby+=" 到着ロビー";
  var result=new LinkedHashMap<String,Object>();result.put("boardingName",ride.getFrom());result.put("boardingOriginal",original);
  result.put("originQuery",lobby);result.put("destinationQuery",point.get("latitude")+","+point.get("longitude"));
  result.put("line",ride.getLine()==null?ride.getCategory():ride.getLine());
  int walk=0;for(var step:leg.getSteps()){if(step==ride)break;if("도보".equals(step.getType()))walk+=step.getMinutes();}
  result.put("walkMinutes",Math.max(3,walk));
  if(haneda(airport))result.put("notice","국제선 제3터미널 기준입니다. 일부 항공편은 제2터미널을 이용하므로 항공권의 터미널을 확인하세요.");
  return result;
 }
 public void attach(AiRouteResponse response){
  var rows=response.getTimeline();if(rows==null)return;
  for(int i=0;i+1<rows.size();i++){
   var a=rows.get(i);var n=rows.get(i+1);
   if(a.getDay()!=n.getDay() || !isAirport(a.getPlaceId(),a.getPlaceName(),a.getCategory()) || a.getLatitude()==null || a.getLongitude()==null)continue;
   a.setAirportAccess(details(a.getPlaceName(),a.getLatitude(),a.getLongitude(),n.getTransit()));
  }
 }
 static boolean isAirport(String id,String name,String category){return "공항".equals(category) || (id!=null && id.startsWith("AIRPORT_")) || (name!=null && name.matches("(?is).*(공항|空港|airport).*"));}
}
