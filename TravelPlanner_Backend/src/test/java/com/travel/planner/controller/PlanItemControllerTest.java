package com.travel.planner.controller;
import com.travel.planner.service.*;
import com.travel.planner.entity.*;
import com.travel.planner.repository.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.http.MediaType;
import org.springframework.web.server.ResponseStatusException;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
class PlanItemControllerTest {
 @Test void existingClientPathsListAndReplaceSelectedPlace() throws Exception {
 var replacements=mock(PlanItemAdjustmentService.class);var saved=mock(SavedPlanQueryService.class);
 var mvc=MockMvcBuilders.standaloneSetup(new PlanItemController(replacements,saved)).build();
 var auth=new UsernamePasswordAuthenticationToken("owner@example.com","unused");
 when(replacements.alternatives("owner@example.com",12L,45L,null,null)).thenReturn(List.of(Map.of("placeId","p2","placeName","New place")));
 when(saved.detail("owner@example.com",12L)).thenReturn(Map.of("planId",12));
 mvc.perform(get("/api/v1/plans/12/items/45/alternatives").principal(auth)).andExpect(status().isOk()).andExpect(jsonPath("$[0].placeId").value("p2"));
 mvc.perform(patch("/api/v1/plans/12/items/45").principal(auth).contentType(MediaType.APPLICATION_JSON).content("{\"placeId\":\"p2\"}")).andExpect(status().isOk()).andExpect(jsonPath("$.planId").value(12));
 verify(replacements).replace("owner@example.com",12L,45L,"p2",null,null);
 }
 @Test void previewAndMutationRejectOtherUsersBeforeAnyPlaceLookup() {
 var plans=mock(PlanRepository.class);var places=mock(PlaceRepository.class);
 var user=new User();user.setEmail("owner@example.com");var plan=new Plan();plan.setUser(user);
 when(plans.findDetailById(12L)).thenReturn(Optional.of(plan));
 var service=new PlanReplaceService(plans,places,mock(PlanService.class),mock(PlanPersistenceService.class),mock(TimelineAssembler.class),mock(PlaceDescriptionService.class),mock(PlaceNameService.class));
 assertEquals(403,assertThrows(ResponseStatusException.class,()->service.alternatives("other@example.com",12L,45L)).getStatusCode().value());
 assertEquals(403,assertThrows(ResponseStatusException.class,()->service.replaceChosen("other@example.com",12L,45L,"p2")).getStatusCode().value());
 verifyNoInteractions(places);
 }
}
