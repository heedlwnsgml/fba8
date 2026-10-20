package com.travel.planner.service;
import com.travel.planner.dto.*;
import com.travel.planner.transit.*;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.beans.factory.annotation.Autowired;
import org.junit.jupiter.api.Test;
import java.time.LocalDate;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
@SpringBootTest
class CollectedPassCatalogTest {
    @Autowired CollectedPassCatalog catalog;
    @Autowired PassAdvisorService advisor;
    private AiRouteResponse.TimelineItem item(int day,int yen,String operator,RailCategory category) {
        var item=new AiRouteResponse.TimelineItem();item.setDay(day);item.setTime("10:00");
        var transit=new TransitLegDto();transit.setMinutes(20);transit.setFareYen(yen);
        var ride=new PassAdvisor.Ride();ride.fareYen=yen;
        var leg=new PassAdvisor.Leg();leg.operator=operator;leg.category=category;leg.line="銀座線";
        ride.legs=List.of(leg);transit.setFareRides(List.of(ride));item.setTransit(transit);return item;
    }
    @Test void ownPassPricesAndCoverageAreLoadedFromSeparateDatabase() {
        var snapshot=catalog.snapshot();assertTrue(catalog.configured());assertEquals(30,snapshot.passes().size());
        assertEquals(800,snapshot.rows().get("enoden-noriorikun").getPriceEnyen());
        assertEquals(700,snapshot.rows().get("tokyo-metro-24h").getPriceEnyen());
        assertEquals(50000,snapshot.rows().get("jr-national-7").getPriceEnyen());
        assertFalse(snapshot.rows().containsKey("yokohama-minatoburari"));
    }
    @Test void one24HourPurchaseCoversTwoDaysButDoesNotDiscountJr() {
        var response=new AiRouteResponse();
        var day1=new AiRouteResponse.DaySummary();day1.setDay(1);day1.setDate("2026-10-20");
        var day2=new AiRouteResponse.DaySummary();day2.setDay(2);day2.setDate("2026-10-21");
        var first=item(1,600,"東京地下鉄",RailCategory.SUBWAY);first.setTime("20:00");
        response.setDays(List.of(day1,day2));response.setTimeline(List.of(first,item(2,600,"東京地下鉄",RailCategory.SUBWAY),item(2,2000,"東日本旅客鉄道",RailCategory.JR)));
        response.setTransitFareYen(3200);advisor.apply(response);
        assertEquals(1,response.getPasses().size());assertEquals("tokyo-metro-24h",response.getPasses().getFirst().getKey());
        assertEquals(2700,response.getTransportCosts().get("knownOptimalFareYen"));
        var days=(List<?>)response.getTransportCosts().get("dailyCosts");
        assertEquals(700,((Map<?,?>)days.get(0)).get("passPurchaseFareYen"));
        assertEquals(0,((Map<?,?>)days.get(1)).get("passPurchaseFareYen"));
        assertEquals(2000,((Map<?,?>)days.get(1)).get("optimalFareYen"));
    }
    @Test void datedAndUndatedPassEligibilityRespectsSalesValidity() {
        var pass=new PassAdvisor.Pass();pass.validFrom=LocalDate.of(2026,10,1);pass.validUntil=LocalDate.of(2026,12,31);
        assertFalse(pass.usableOn(null));assertFalse(pass.usableOn(LocalDate.of(2026,9,30)));
        assertFalse(pass.usableOn(LocalDate.of(2027,1,1)));assertTrue(pass.usableOn(LocalDate.of(2026,10,20)));
    }
}
