package com.travel.planner.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.http.*;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.client.RestTemplate;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class LiveDirectionsControllerTest {
  @Test void readsCurrentGoogleStepsWithoutStoredEstimates() throws Exception {
    var json=new ObjectMapper();
    var result=LiveDirectionsController.route(json.readTree("""
      {"duration":"1501s","distanceMeters":2500,"legs":[{"steps":[
       {"travelMode":"WALK","staticDuration":"91s","navigationInstruction":{"instructions":"역으로 이동"}},
       {"travelMode":"TRANSIT","staticDuration":"1200s","transitDetails":{"transitLine":{"nameShort":"G"},"stopDetails":{"departureStop":{"name":"출발역"},"arrivalStop":{"name":"도착역"}},"headsign":"시부야","stopCount":3}}
      ]}]}
      """));
    assertEquals(26,result.get("minutes"));
    assertEquals(2,((java.util.List<?>)result.get("steps")).size());
    assertTrue(result.toString().contains("출발역"));
  }
  @Test void sendsAnOnDemandGoogleRequestWithNoCredentialsInTheResult() {
    var http=mock(RestTemplate.class);var controller=new LiveDirectionsController(http);
    ReflectionTestUtils.setField(controller,"key","test-secret");
    when(http.postForEntity(eq("https://routes.googleapis.com/directions/v2:computeRoutes"),any(HttpEntity.class),eq(String.class)))
      .thenReturn(ResponseEntity.ok("{\"routes\":[{\"duration\":\"120s\",\"legs\":[]}]}"));
    var result=controller.live(new LiveDirectionsController.Request("35.68,139.76","35.69,139.77","walking"));
    assertFalse(result.toString().contains("test-secret"));assertEquals("Google Maps",result.get("source"));
    verify(http).postForEntity(eq("https://routes.googleapis.com/directions/v2:computeRoutes"),argThat((HttpEntity<?> e)->e.getBody().toString().contains("WALK")),eq(String.class));
  }
  @Test void invalidCoordinatesAreNotInterpretedAsARequestUrl() {
    assertTrue(LiveDirectionsController.waypoint("35.68,139.76").containsKey("location"));
    assertTrue(LiveDirectionsController.waypoint("https://localhost/private").containsKey("address"));
  }
}
