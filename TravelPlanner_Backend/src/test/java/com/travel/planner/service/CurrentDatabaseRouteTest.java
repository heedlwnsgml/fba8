package com.travel.planner.service;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import java.time.LocalDate;
import static org.junit.jupiter.api.Assertions.*;
/** Read-only check against the user's current database. No collection or persistence. */
@SpringBootTest
class CurrentDatabaseRouteTest {
    @Autowired RailRouteService routes;
    @Test void tokyoRouteUsesDatabaseRideStepsEvenWithoutStoredTravelEstimate() {
        var leg=routes.leg(35.6909,139.7003,"신주쿠",35.6580,139.7016,"시부야",
                "도보 및 대중교통",0,LocalDate.of(2026,10,17),600);
        assertNotNull(leg);
        assertTrue(leg.getSource().contains("rail-network") || leg.getSource().contains("gtfs"),leg.getSource());
        assertTrue(leg.getSteps().stream().anyMatch(s -> "승차".equals(s.getType()) && s.getMinutes()>0));
        assertTrue(leg.getMinutes()>0);
    }
}
