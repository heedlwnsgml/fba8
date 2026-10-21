package com.travel.planner.controller;
import com.travel.planner.service.*;
import com.travel.planner.entity.*;
import com.travel.planner.repository.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.server.ResponseStatusException;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
class PlanDeleteControllerTest {
 @Test void clientDeletePathReturnsNoContentAndUsesAuthenticatedOwner() throws Exception {
  var persistence=mock(PlanPersistenceService.class);
  var controller=new PlanController(mock(PlanGenerationService.class),mock(PlanValidationService.class),mock(PlanModifierService.class),mock(PlanReplaceService.class),mock(SavedPlanQueryService.class),persistence);
  var mvc=MockMvcBuilders.standaloneSetup(controller).build();
  mvc.perform(delete("/api/v1/plans/12").principal(new UsernamePasswordAuthenticationToken("owner@example.com","unused"))).andExpect(status().isNoContent());
  verify(persistence).deletePlan("owner@example.com",12L);
 }
 @Test void deleteTrafficBeforeCascadingPlanAndPreserveOtherPlans() {
  var plans=mock(PlanRepository.class);var traffic=mock(TrafficRepository.class);
  var service=new PlanPersistenceService(plans,mock(PlaceRepository.class),traffic,mock(RailRouteService.class));
  var plan=new Plan();var user=new User();user.setEmail("owner@example.com");plan.setUser(user);plan.addItinerary(new Itinerary());
  when(plans.findDetailById(12L)).thenReturn(Optional.of(plan));
  service.deletePlan("owner@example.com",12L);
  var order=inOrder(traffic,plans);order.verify(traffic).deleteByItineraryIn(plan.getItineraries());order.verify(traffic).flush();order.verify(plans).delete(plan);order.verify(plans).flush();
  verify(plans,never()).deleteAll(anyIterable());
 }
 @Test void rejectOtherOwnerAndMissingPlanWithoutDeletion() {
  var plans=mock(PlanRepository.class);var traffic=mock(TrafficRepository.class);
  var service=new PlanPersistenceService(plans,mock(PlaceRepository.class),traffic,mock(RailRouteService.class));
  var plan=new Plan();var user=new User();user.setEmail("owner@example.com");plan.setUser(user);
  when(plans.findDetailById(12L)).thenReturn(Optional.of(plan));when(plans.findDetailById(99L)).thenReturn(Optional.empty());
  assertEquals(403,assertThrows(ResponseStatusException.class,()->service.deletePlan("other@example.com",12L)).getStatusCode().value());
  assertEquals(404,assertThrows(ResponseStatusException.class,()->service.deletePlan("owner@example.com",99L)).getStatusCode().value());
  verify(plans,never()).delete(any(Plan.class));verifyNoInteractions(traffic);
 }
}
