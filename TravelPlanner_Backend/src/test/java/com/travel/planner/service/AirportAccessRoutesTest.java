package com.travel.planner.service;
import com.travel.planner.dto.TransitLegDto;
import org.springframework.jdbc.core.JdbcTemplate;
import org.junit.jupiter.api.Test;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
class AirportAccessRoutesTest {
 @Test void hanedaGenericAirportUsesInternationalTerminalInsteadOfApron() {
  var point=AirportAccessService.routingPoint("도쿄 국제공항(하네다)",35.5533,139.7811);
  assertEquals(35.54498,point[0]);assertEquals(139.7670665,point[1]);
  assertEquals(35.5533,AirportAccessService.routingPoint("하네다 엑셀 호텔 도큐",35.5533,139.7811)[0]);
  assertEquals(35.550795,AirportAccessService.routingPoint("Haneda Terminal 2",35.5533,139.7811)[0]);
 }
 @Test void accessUrlUsesLobbyAndUnambiguousCoordinatesOfActualBoardingStation() {
  var jdbc=new JdbcTemplate(){
   @Override public <T> List<T> queryForList(String sql,Class<T> type,Object... args){return List.of();}
   @Override public List<Map<String,Object>> queryForList(String sql,Object... args){return sql.contains("transit_station")?List.of(Map.of("name","羽田空港第3ターミナル","latitude",35.54498,"longitude",139.7670665)):List.of();}
  };
  var leg=new TransitLegDto();var ride=new TransitLegDto.Step();ride.setType("승차");ride.setCategory("철도");ride.setFrom("하네다 제3터미널");ride.setFromOriginal("羽田空港第3ターミナル");leg.getSteps().add(ride);
  var data=new AirportAccessService(jdbc,null).details("하네다공항",35.5533,139.7811,leg);
  assertEquals("羽田空港第3ターミナル 到着ロビー",data.get("originQuery"));
  assertEquals("35.54498,139.7670665",data.get("destinationQuery"));assertEquals(3,data.get("walkMinutes"));
 }
}
