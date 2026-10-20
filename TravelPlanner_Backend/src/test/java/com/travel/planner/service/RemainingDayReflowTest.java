package com.travel.planner.service;
import com.travel.planner.dto.PlanRequest;
import com.travel.planner.entity.Place;
import org.junit.jupiter.api.Test;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

class RemainingDayReflowTest {
    private final PlanService engine=new PlanService();
    private final RemainingDayReflow reflow=new RemainingDayReflow(engine);
    static Place place(String id,double latitude){var p=new Place();p.setPlaceId(id);p.setName(id);p.setCategory("관광지");p.setLatitude(latitude);p.setLongitude(139.7);return p;}
    static PlanService.DayItem item(Place p,int start,Integer end){return new PlanService.DayItem(PlanService.SimulatedItinerary.Type.VISIT,p,null,start,end);}
    private PlanService.DayContext ctx(){var c=new PlanService.DayContext();c.startMin=540;c.endMin=1320;c.transportation="도보";return c;}
    @Test void earlierStopsStayPutAndAllRemainingIdentitiesAndDwellsSurvive(){
        var a=place("before",35.6);var b=place("replacement",35.61);var c=place("restaurant",35.62);var d=place("hotel",35.63);
        var rows=List.of(item(a,540,600),item(b,610,730),item(c,740,800),new PlanService.DayItem(PlanService.SimulatedItinerary.Type.END,d,null,850,null));
        var out=reflow.reflow(new PlanRequest(),ctx(),rows,1);
        assertEquals(4,out.size());assertSame(a,out.get(0).getPlace());assertEquals(540,out.get(0).getStartMin());assertEquals(600,out.get(0).getEndMin());
        assertSame(c,out.get(2).getPlace());assertSame(d,out.get(3).getPlace());assertEquals(60,out.get(2).getEndMin()-out.get(2).getStartMin());
        for(int i=1;i<out.size();i++)assertTrue(out.get(i).getStartMin()>=out.get(i-1).getEndMin()+out.get(i).getTravelMinutes());
    }
    @Test void impossibleFixedTimeRejectsInsteadOfDroppingAStop(){
        var a=place("before",35.6);var b=place("replacement",35.65);
        var rows=List.of(item(a,540,600),item(b,610,790),new PlanService.DayItem(PlanService.SimulatedItinerary.Type.FIXED,null,"예약",700,760));
        assertThrows(IllegalArgumentException.class,()->reflow.reflow(new PlanRequest(),ctx(),rows,1));
        assertEquals(3,rows.size());assertEquals(700,rows.get(2).startMin);
    }
    @Test void endOfDayOverflowRejectsInsteadOfRemovingRestaurantOrHotel(){
        var a=place("before",35.6);var b=place("replacement",35.65);var c=place("keep",35.66);
        var rows=List.of(item(a,1100,1200),item(b,1210,1310),item(c,1310,1370));
        assertThrows(IllegalArgumentException.class,()->reflow.reflow(new PlanRequest(),ctx(),rows,1));
    }

    @Test void flexibleReflowShortensReplacementBeforeChangingRemainingDurations(){
        var a=place("before",35.6);var b=place("replacement",35.61);var c=place("keep",35.62);
        var rows=List.of(item(a,540,600),item(b,610,730),item(c,740,800));
        var context=ctx();context.endMin=800;
        assertThrows(IllegalArgumentException.class,()->reflow.reflow(new PlanRequest(),context,rows,1));
        var out=reflow.reflowFlexible(new PlanRequest(),context,rows,1);
        int replacement=out.get(1).getEndMin()-out.get(1).getStartMin();
        assertTrue(replacement<120 && replacement>=15);
        assertEquals(60,out.get(2).getEndMin()-out.get(2).getStartMin());
        assertEquals(120,rows.get(1).endMin-rows.get(1).startMin,"preview does not mutate original input");
        assertTrue(out.getLast().getEndMin()<=800);
    }
    @Test void flexibleReflowRespectsMinimumStaysAndRejectsImpossibleTravel(){
        var a=place("before",35.6);var b=place("distant",40.0);
        var rows=List.of(item(a,540,600),item(b,610,730));
        var context=ctx();context.endMin=650;
        assertThrows(IllegalArgumentException.class,()->reflow.reflowFlexible(new PlanRequest(),context,rows,1));
    }
}
