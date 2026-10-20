package com.travel.planner.service;
import com.travel.planner.entity.Plan;
import jakarta.persistence.EntityManager;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
@SpringBootTest
@Transactional
class PlanPeriodListenerTest {
    @Autowired EntityManager em;
    @Test void undatedDaysSurviveReloadAndDeleteWithoutChangingPlannerSchema() {
        Plan p = new Plan(); p.setTitle("schema compatibility rollback test");
        p.setStartDate(Plan.UNDATED_BASE); p.setEndDate(Plan.UNDATED_BASE.plusDays(2)); p.setTripDays(3);
        em.persist(p); em.flush(); Long id=p.getId(); em.clear();
        Plan restored=em.find(Plan.class,id);
        assertTrue(restored.undated()); assertEquals(3,restored.totalDays()); assertNull(restored.dateOfDay(1));
        em.remove(restored); em.flush(); em.clear(); assertNull(em.find(Plan.class,id));
    }
}
