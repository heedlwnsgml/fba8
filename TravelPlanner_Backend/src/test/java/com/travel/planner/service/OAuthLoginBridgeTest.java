package com.travel.planner.service;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
class OAuthLoginBridgeTest {
 @Test void secretsAreIndependentAndTokenIsOneUse(){
  var b=new OAuthLoginBridge();var t=b.begin("google");assertEquals(43,t.get("secret").length());assertNotEquals(t.get("secret"),t.get("browserKey"));
  assertThrows(ResponseStatusException.class,()->b.poll(t.get("id"),"wrong"));
  assertEquals("PENDING",b.poll(t.get("id"),t.get("secret")).get("status"));
  assertEquals("google",b.claim(t.get("id"),t.get("browserKey")));
  assertThrows(ResponseStatusException.class,()->b.claim(t.get("id"),t.get("browserKey")));
  b.complete(t.get("id"),"kakao","wrong-token");assertEquals("PENDING",b.poll(t.get("id"),t.get("secret")).get("status"));
  b.complete(t.get("id"),"google","test-jwt");assertEquals("test-jwt",b.poll(t.get("id"),t.get("secret")).get("token"));
  assertThrows(ResponseStatusException.class,()->b.poll(t.get("id"),t.get("secret")));
 }
 @Test void unclaimedRequestCannotReceiveToken(){var b=new OAuthLoginBridge();var t=b.begin("naver");b.complete(t.get("id"),"naver","token");assertEquals("PENDING",b.poll(t.get("id"),t.get("secret")).get("status"));}
 @Test void expiredRequestAndCanceledRequestCannotBeUsed(){
  class MutableClock extends Clock {Instant now=Instant.EPOCH;public ZoneId getZone(){return ZoneOffset.UTC;}public Clock withZone(ZoneId z){return this;}public Instant instant(){return now;}}
  var clock=new MutableClock();var b=new OAuthLoginBridge(clock);var t=b.begin("google");clock.now=clock.now.plusSeconds(300);
  assertThrows(ResponseStatusException.class,()->b.claim(t.get("id"),t.get("browserKey")));assertThrows(ResponseStatusException.class,()->b.poll(t.get("id"),t.get("secret")));
  var c=b.begin("google");b.cancel(c.get("id"),"wrong");assertEquals("PENDING",b.poll(c.get("id"),c.get("secret")).get("status"));b.cancel(c.get("id"),c.get("secret"));assertThrows(ResponseStatusException.class,()->b.poll(c.get("id"),c.get("secret")));
 }
 @Test void failureIsDeliveredWithoutTokens(){var b=new OAuthLoginBridge();var t=b.begin("google");b.fail(t.get("id"));var result=b.poll(t.get("id"),t.get("secret"));assertEquals("FAILED",result.get("status"));assertFalse(result.containsKey("token"));}
 @Test void unfinishedRequestsAreBounded(){var b=new OAuthLoginBridge();for(int i=0;i<256;i++)b.begin("google");assertThrows(ResponseStatusException.class,()->b.begin("google"));}
}
