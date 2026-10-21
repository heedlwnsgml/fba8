package com.travel.planner.service;
import com.travel.planner.dto.PlanRequest;
import com.travel.planner.entity.Place;
import com.travel.planner.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import java.nio.file.*;
import java.util.*;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;
@SpringBootTest
@EnabledIfEnvironmentVariable(named="PLANNER_FAILURE_DIAGNOSTIC",matches="1")
class FailedMealDiagnosticTest {
 @Autowired PlanGenerationService generation;
 @Autowired tools.jackson.databind.ObjectMapper mapper;
 @MockitoBean PlanPersistenceService persistence;
 @MockitoBean MealCandidateRecovery recovery;
 static class DiagnosticStop extends RuntimeException {}
 @Test void inspectWithoutSavingAnyTrip() throws Exception {
  when(persistence.upsertPlace(any())).thenAnswer(call->call.getArgument(0));
  doAnswer(call->{
   PlanService.TripInput input=call.getArgument(0);PlanService.TripPlan plan=call.getArgument(1);
   List<Map<String,Object>> result=new ArrayList<>();
   for(var day:plan.getDays())for(int index=0;index<day.getItems().size();index++){
    var item=day.getItems().get(index);if(!MealCandidateRecovery.missing(item))continue;
    var row=new LinkedHashMap<String,Object>();row.put("day",day.getDayNumber());row.put("city",day.getCity());
    row.put("items",day.getItems().stream().map(i->{var m=new LinkedHashMap<String,Object>();m.put("name",i.getDisplayName());m.put("type",i.getType().name());m.put("start",i.getStartMin());m.put("end",i.getEndMin());m.put("travel",i.getTravelMinutes());m.put("lat",i.getLatitude());m.put("lng",i.getLongitude());return m;}).toList());
    row.put("restaurants",input.candidates.stream().filter(p->PlaceKind.of(p)==PlaceKind.RESTAURANT || PlaceKind.of(p)==PlaceKind.BAR).filter(p->Objects.equals(day.getCity(),p.getCity())).map(p->{var m=new LinkedHashMap<String,Object>();m.put("name",p.shownName());m.put("lat",p.getLatitude());m.put("lng",p.getLongitude());m.put("hours",p.getOpeningHours());m.put("theme",p.getTheme());m.put("intervals",OpeningHours.intervalsOn(p,day.getDate()));return m;}).toList());result.add(row);
   }
   Files.writeString(Path.of(System.getenv("FAILED_MEAL_REPORT")),mapper.writeValueAsString(result));
   throw new DiagnosticStop();
  }).when(recovery).complete(any(),any(),any());
  var request=mapper.readValue(Files.readString(Path.of(System.getenv("FAILED_MEAL_REQUEST"))),PlanRequest.class);
  assertThrows(DiagnosticStop.class,()->generation.createPlan(System.getenv("FAILED_MEAL_OWNER"),request));
 }
}
