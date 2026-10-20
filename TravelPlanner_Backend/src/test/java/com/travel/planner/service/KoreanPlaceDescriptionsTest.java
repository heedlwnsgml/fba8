package com.travel.planner.service;
import com.travel.planner.entity.Place;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowCallbackHandler;
import java.sql.ResultSet;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
class KoreanPlaceDescriptionsTest {
 @Test void suppliedSummaryWinsAndReadOnlyOverlayDoesNotChangeEntity() throws Exception {
  JdbcTemplate jdbc=mock(JdbcTemplate.class);ResultSet row=mock(ResultSet.class);
  when(row.getString(1)).thenReturn("hotel1");when(row.getString(2)).thenReturn("공식 자료로 확인한 온천 숙소");
  doAnswer(invocation->{invocation.getArgument(1,RowCallbackHandler.class).processRow(row);return null;}).when(jdbc).query(anyString(),any(RowCallbackHandler.class));
  var descriptions=new KoreanPlaceDescriptions(jdbc);
  Place p=new Place();p.setPlaceId("hotel1");p.setCategory("숙소");p.setCity("하코네");p.setName("테스트 숙소");
  assertEquals("공식 자료로 확인한 온천 숙소",descriptions.summary(p));assertNull(p.getSummary());
  p.setSummary("사용자가 제공한 소개");assertEquals("사용자가 제공한 소개",descriptions.summary(p));
  verify(jdbc).query(contains("test_planner_app_metadata.place_description"),any(RowCallbackHandler.class));verifyNoMoreInteractions(jdbc);
 }
 @Test void supplementalHotelWithoutVerifiedInfoUsesOnlyKnownLocationAndRole() {
  var descriptions=new KoreanPlaceDescriptions(mock(JdbcTemplate.class));
  Place p=new Place();p.setPlaceId("supplemental1");p.setCategory("숙소");p.setCity("도쿄");p.setName("테스트 호텔");
  assertEquals("",descriptions.summary(p));assertFalse(descriptions.summary(p).contains("온천"));assertNull(p.getSummary());
  assertNull(descriptions.summary(null));
 }
}
