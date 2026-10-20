package com.travel.planner.service;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import java.security.SecureRandom;
import java.time.*;
import java.util.*;
@Service
public class OAuthLoginBridge {
 public static final String SESSION_KEY="planner.oauth.exchange";
 private static final SecureRandom RANDOM=new SecureRandom();
 private final Clock clock;
 public OAuthLoginBridge(){this(Clock.systemUTC());}
 OAuthLoginBridge(Clock clock){this.clock=clock;}
 private record Entry(String provider,String secret,String browser,Instant expires,String token,String error,boolean claimed){}
 private final Map<String,Entry> entries=new HashMap<>();
 private String random(){byte[] b=new byte[32];RANDOM.nextBytes(b);return Base64.getUrlEncoder().withoutPadding().encodeToString(b);}
 private void clean(){entries.entrySet().removeIf(e->!clock.instant().isBefore(e.getValue().expires()));}
 public synchronized Map<String,String> begin(String provider){
  clean();if(entries.size()>=256)throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,"잠시 후 다시 시도하세요.");
  String id=random(),secret=random(),browser=random();entries.put(id,new Entry(provider,secret,browser,clock.instant().plusSeconds(300),null,null,false));
  return Map.of("id",id,"secret",secret,"browserKey",browser);
 }
 public synchronized String claim(String id,String key){
  clean();var e=entries.get(id);if(e==null||e.claimed()||!e.browser().equals(key))throw new ResponseStatusException(HttpStatus.NOT_FOUND,"로그인 요청이 만료되었습니다.");
  entries.put(id,new Entry(e.provider(),e.secret(),"",e.expires(),null,null,true));return e.provider();
 }
 public synchronized void complete(String id,String provider,String token){
  clean();var e=entries.get(id);if(e!=null&&e.claimed()&&e.token()==null&&e.error()==null&&e.provider().equals(provider))entries.put(id,new Entry(e.provider(),e.secret(),"",e.expires(),token,null,true));
 }
 public synchronized void fail(String id){
  clean();var e=entries.get(id);if(e!=null&&e.token()==null)entries.put(id,new Entry(e.provider(),e.secret(),"",e.expires(),null,"공급자 로그인 실패: 동의 항목, 테스트 사용자 및 콜백 설정을 확인하세요.",true));
 }
 public synchronized Map<String,String> poll(String id,String secret){
  clean();var e=entries.get(id);if(e==null||!e.secret().equals(secret))throw new ResponseStatusException(HttpStatus.NOT_FOUND,"로그인 요청이 만료되었습니다.");
  if(e.error()!=null){entries.remove(id);return Map.of("status","FAILED","message",e.error());}
  if(e.token()==null)return Map.of("status","PENDING");
  entries.remove(id);return Map.of("status","SUCCEEDED","token",e.token());
 }
 public synchronized void cancel(String id,String secret){var e=entries.get(id);if(e!=null&&e.secret().equals(secret))entries.remove(id);}
}
