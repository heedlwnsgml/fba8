package com.travel.planner.service;
import com.travel.planner.util.JapanRegionDirectory;
import com.travel.planner.entity.Region;
import java.util.List;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
class CityRegionValidationTest {
    @Test void billingDisabledStillAllowsTokyoAndSelectedAirports() {
        var maps=mock(GoogleMapsService.class);
        when(maps.getFormalizedJapanCity(anyString())).thenThrow(new RuntimeException("REQUEST_DENIED"));
        var result=new PlanValidationService(maps).validateMultiCityPlan(List.of("도쿄","요코하마","가마쿠라"),"하네다공항","나리타국제공항",5);
        assertFalse(result.isWarning); verifyNoInteractions(maps);
    }
    @Test void distantRegionsStillProduceTheTripLengthWarning() {
        var maps=mock(GoogleMapsService.class);
        assertTrue(new PlanValidationService(maps).validateMultiCityPlan(List.of("삿포로","나하"),null,null,1).isWarning);
        assertEquals(Region.KANTO,JapanRegionDirectory.find(" Tokyo "));
        assertEquals(Region.CHUGOKU,JapanRegionDirectory.find("시모노세키"));
        verifyNoInteractions(maps);
    }
    @Test void customJapaneseCitiesStillUseLookupAndInvalidCitiesAreNotAccepted() {
        var maps=mock(GoogleMapsService.class);
        when(maps.getFormalizedJapanCity("쓰쿠바")).thenReturn("일본 이바라키현 쓰쿠바시");
        var service=new PlanValidationService(maps);
        assertFalse(service.validateMultiCityPlan(List.of("쓰쿠바"),null,null,2).isWarning);
        verify(maps).getFormalizedJapanCity("쓰쿠바");
        when(maps.getFormalizedJapanCity("서울")).thenThrow(new RuntimeException("ZERO_RESULTS"));
        assertThrows(IllegalArgumentException.class,()->service.validateMultiCityPlan(List.of("서울"),null,null,2));
        assertNull(JapanRegionDirectory.find("서울 도쿄"));
    }
}
