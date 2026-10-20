package com.travel.planner.service;
import com.travel.planner.entity.Place;
import com.travel.planner.dto.TransitLegDto;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;
class HikeAccessStoreTest {
 @TempDir Path temp;
 @Test void separateStoreRestoresParkingAndNegativeLookupAcrossInstances() throws Exception {
  String file=temp.resolve("access.sqlite").toString();
  var store=new HikeAccessStore(file);var p=new Place();p.setPlaceId("summit");p.setTrailheadLat(35.2);p.setTrailheadLng(138.4);p.setTrailheadName("Parking");store.save(p);
  var other=new Place();other.setPlaceId("other");other.setTrailheadName(HikeAccessService.NO_PARKING);store.save(other);
  var restored=new Place();restored.setPlaceId("summit");var second=new HikeAccessStore(file);second.restore(restored);
  assertEquals(35.2,restored.getTrailheadLat());assertEquals(138.4,restored.getTrailheadLng());assertEquals("Parking",restored.getTrailheadName());
  var missing=new Place();missing.setPlaceId("other");second.restore(missing);assertEquals("-",missing.getTrailheadName());assertNull(missing.getTrailheadLat());
  for(String field:new String[]{"trailheadLat","trailheadLng","trailheadName","hikeTransitGate"})assertNotNull(Place.class.getDeclaredField(field).getAnnotation(jakarta.persistence.Transient.class));
 }
 @Test void twentyPercentMovementPaddingDoesNotDoubleCountHikingVisitTime() {
  var leg=new TransitLegDto();leg.setMinutes(20);leg.setMode("버스·등산");leg.setSource("bus-stops");
  var ride=new TransitLegDto.Step();ride.setMinutes(20);ride.setCategory("버스");var hike=new TransitLegDto.Step();hike.setMinutes(90);hike.setCategory("등산");leg.getSteps().add(ride);leg.getSteps().add(hike);
  RailRouteService.padded(leg);assertEquals(24,leg.getMinutes());assertEquals(24,ride.getMinutes());assertEquals(90,hike.getMinutes());
 }
}
