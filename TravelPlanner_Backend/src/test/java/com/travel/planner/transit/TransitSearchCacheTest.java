package com.travel.planner.transit;

import com.travel.planner.util.DistanceUtil;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class TransitSearchCacheTest {
    @Test void spatialTransferJoinMatchesExhaustiveSearchIncludingTies() throws Exception {
        var random=new Random(1234);var builder=new BusStopIndex.Builder();
        var lat=new double[300];var lng=new double[300];var routes=new ArrayList<List<Integer>>();
        for(int n=0;n<300;n++) {
            lat[n]=35.6+random.nextDouble()*.03;lng[n]=139.7+random.nextDouble()*.03;
            var memberships=new ArrayList<Integer>();memberships.add(n%3);if(n%4==0)memberships.add((n+1)%3);routes.add(memberships);
            builder.add("stop-"+n,"operator",lat[n],lng[n],memberships.stream().map(i->"route-"+i).toList(),List.of(1,1));
        }
        var index=builder.build("test");
        var method=BusStopIndex.class.getDeclaredMethod("transferPoint",int.class,int.class,int.class,int.class);method.setAccessible(true);
        // Route IDs follow their first occurrence: 0,1,2.
        for(int repeat=0;repeat<60;repeat++) {
            int a=random.nextInt(300),b=random.nextInt(300),r1=repeat%3,r2=(repeat+1)%3;
            int[] expected=null;double best=Double.MAX_VALUE;
            for(int x=0;x<300;x++)if(x!=a&&routes.get(x).contains(r1))for(int y=0;y<300;y++)if(y!=b&&routes.get(y).contains(r2)) {
                if(Math.abs(lat[x]-lat[y])>.003)continue;
                double walk=DistanceUtil.calculateDistance(lat[x],lng[x],lat[y],lng[y]);if(walk>BusStopIndex.TRANSFER_KM)continue;
                double cost=DistanceUtil.calculateDistance(lat[a],lng[a],lat[x],lng[x])+DistanceUtil.calculateDistance(lat[y],lng[y],lat[b],lng[b])+walk*2;
                if(cost<best){best=cost;expected=new int[]{x,y};}
            }
            assertArrayEquals(expected,(int[])method.invoke(index,r1,a,r2,b));
            assertArrayEquals(expected,(int[])method.invoke(index,r1,a,r2,b),"cached lookup must remain equivalent");
        }
    }
    @Test void routeWalkingBudgetCannotMutateCachedBoardingStops() throws Exception {
        var graph=new RailGraph(List.of(new RailGraph.Station(0,"station","operator","line","group",RailCategory.JR,35.6,139.7)),List.of());
        var method=RailGraph.class.getDeclaredMethod("accessNodes",double.class,double.class);method.setAccessible(true);
        @SuppressWarnings("unchecked") var first=(Map<Integer,Double>)method.invoke(graph,35.6,139.701);
        assertFalse(first.isEmpty());var expected=new HashMap<>(first);first.clear();
        assertEquals(expected,method.invoke(graph,35.6,139.701));
    }
}
