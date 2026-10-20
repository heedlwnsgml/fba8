package com.travel.planner.transit;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import static org.junit.jupiter.api.Assertions.*;
class BusActualDataTest {
 @Test @EnabledIfEnvironmentVariable(named="P11_ACTUAL_FILE_CHECK",matches="true")
 void readsNationalArchiveAndChecksTravelSamples() throws Exception {
 var idx=BusStopParser.read(Path.of("data/P11-22_SHP.zip"));
 System.out.println("ACTUAL stops="+idx.stopCount()+" routes="+idx.routeCount());
 assertTrue(idx.stopCount()>200000);assertTrue(idx.routeCount()>10000);
 var t0=idx.find(35.9097234,139.4688914,35.924393099999996,139.49150509999998,0.6);System.out.println("SAMPLE 2877->2879: "+(t0==null?"no route":t0.rides.stream().map(r->r.line).toList()));
var t1=idx.find(35.924393099999996,139.49150509999998,35.905271,139.5133528,0.6);System.out.println("SAMPLE 2879->2880: "+(t1==null?"no route":t1.rides.stream().map(r->r.line).toList()));
var t2=idx.find(35.905271,139.5133528,35.9192897,139.4854763,0.6);System.out.println("SAMPLE 2880->2881: "+(t2==null?"no route":t2.rides.stream().map(r->r.line).toList()));
var t3=idx.find(35.9192897,139.4854763,35.9171214,139.4834448,0.6);System.out.println("SAMPLE 2881->2882: "+(t3==null?"no route":t3.rides.stream().map(r->r.line).toList()));
 }
}
