package com.travel.planner.service;
import com.travel.planner.entity.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import com.travel.planner.util.TimeUtil;
import java.time.LocalDate;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

/** Explicit manual, read-only local-data check; never uses or creates authentication tokens. */
@EnabledIfEnvironmentVariable(named="CHECK_LOCAL_MEAL_CACHE",matches="true")
class LiveMealCacheCheckTest {
    @Test void existingAsakusaMealWindowSelectsARealOpenRestaurant(){
        var source=new DriverManagerDataSource(System.getenv("LOCAL_MEAL_DB_URL"),System.getenv("LOCAL_MEAL_DB_USER"),System.getenv("LOCAL_MEAL_DB_PASSWORD"));
        var jdbc=new JdbcTemplate(source);var food=new SupplementalFoodService(jdbc);
        var row=jdbc.queryForMap("SELECT i.id,i.time,i.end_time,p.start_date,p.end_date,p.transportation FROM itinerary i JOIN plan p ON p.id=i.plan_id WHERE i.day_number=1 AND i.sequence=3 AND i.custom_title LIKE '%주변 자유 식사%' ORDER BY p.id DESC LIMIT 1");
        var plan=new Plan();plan.setStartDate(((java.sql.Date)row.get("start_date")).toLocalDate());plan.setEndDate(((java.sql.Date)row.get("end_date")).toLocalDate());plan.setTransportation((String)row.get("transportation"));
        var item=new Itinerary();item.setDayNumber(1);item.setTime((String)row.get("time"));item.setEndTime((String)row.get("end_time"));
        Place previous=new Place();previous.setCity("도쿄");previous.setLatitude(35.7110594);previous.setLongitude(139.7968838);
        Place next=new Place();next.setCity("도쿄");next.setLatitude(35.711983);next.setLongitude(139.7923085);
        Place meal=food.mealAt(plan,item,previous,next,new HashSet<>(),List.of());assertNotNull(meal);
        assertNotNull(meal.getPlaceId());assertFalse(meal.getName().contains("자유 식사"));
        var window=food.mealWindow(plan,item,previous,meal,next);assertTrue(window[1]-window[0]>=30);assertTrue(window[1]<=TimeUtil.parseClock(item.getEndTime()));
        System.out.println("REAL_MEAL_CHECK: "+meal.getName()+" | "+TimeUtil.format(window[0])+"-"+TimeUtil.format(window[1])+" | "+meal.getPlaceId());
    }
}
