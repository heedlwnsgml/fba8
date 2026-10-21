package com.travel.planner.service;
import com.travel.planner.controller.PlanGenerationController;
import com.travel.planner.dto.*;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.Authentication;
import org.springframework.web.server.ResponseStatusException;
import tools.jackson.databind.json.JsonMapper;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class EndTimeDecisionControllerTest {
 @Test void requestRecoveryPreservesFingerprintAndOnlyOwnerCanAnswer() throws Exception {
  var jobs=new PlanGenerationJobs();try {
   var generator=mock(PlanGenerationService.class);
   when(generator.createPlan(eq("owner"),any())).thenAnswer(call->{
    PlanGenerationJobs.requestEndTimeExtension(3,LocalDate.of(2026,10,23),1320,1400,"a","b");
    var result=new AiRouteResponse();result.setTimeline(List.of(new AiRouteResponse.TimelineItem()));return result;
   });
   var controller=new PlanGenerationController(jobs,generator,JsonMapper.builder().build());
   var owner=mock(Authentication.class);when(owner.getName()).thenReturn("owner");var other=mock(Authentication.class);when(other.getName()).thenReturn("other");
   var request=new PlanRequest();request.setClientRequestId("request");request.setCities(List.of("도쿄"));request.setTripDays(5);request.setPreferredEndTime(LocalTime.of(22,0));
   controller.submit(owner,request);EndTimeApprovalTest.await(()->jobs.find("owner","request").approval()!=null);
   var recovered=controller.originalRequest(owner,"request");assertEquals(LocalTime.of(22,0),recovered.getPreferredEndTime());
   controller.submit(owner,recovered);verify(generator,times(1)).createPlan(eq("owner"),any());
   assertEquals(404,assertThrows(ResponseStatusException.class,()->controller.originalRequest(other,"request")).getStatusCode().value());
   var pending=jobs.find("owner","request").approval();
   assertEquals(400,assertThrows(ResponseStatusException.class,()->controller.decideEndTime(owner,"request",new PlanGenerationController.EndTimeDecision(pending.decisionId(),null))).getStatusCode().value());
   assertEquals(404,assertThrows(ResponseStatusException.class,()->controller.decideEndTime(other,"request",new PlanGenerationController.EndTimeDecision(pending.decisionId(),true))).getStatusCode().value());
   controller.decideEndTime(owner,"request",new PlanGenerationController.EndTimeDecision(pending.decisionId(),true));
   EndTimeApprovalTest.await(()->"SUCCEEDED".equals(jobs.find("owner","request").status()));
  }finally{jobs.close();}
 }
}
