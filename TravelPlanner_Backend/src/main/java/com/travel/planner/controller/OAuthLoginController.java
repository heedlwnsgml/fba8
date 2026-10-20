package com.travel.planner.controller;
import com.travel.planner.config.OAuthProviderConfig;
import com.travel.planner.service.OAuthLoginBridge;
import jakarta.servlet.http.*;
import org.springframework.core.env.Environment;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import java.io.IOException;
import java.util.*;
@RestController @RequestMapping("/api/v1/auth/oauth")
public class OAuthLoginController {
 private final OAuthLoginBridge bridge;private final Environment env;
 public OAuthLoginController(OAuthLoginBridge b,Environment e){bridge=b;env=e;}
 public record Start(String provider){} public record Poll(String id,String secret){}
 @PostMapping("/begin") public Map<String,String> begin(@RequestBody Start request,HttpServletResponse response){
  response.setHeader("Cache-Control","no-store");String p=request.provider();
  if(!List.of("google","kakao","naver").contains(p==null?"":p))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"지원하지 않는 공급자입니다.");
  if(!OAuthProviderConfig.configured(env,p))throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"백엔드에 OAUTH_"+p.toUpperCase()+"_CLIENT_ID 및 OAUTH_"+p.toUpperCase()+"_CLIENT_SECRET 설정이 필요합니다.");
  var ticket=new HashMap<>(bridge.begin(p));String key=ticket.remove("browserKey");String base=env.getProperty("oauth.public-base-url","http://localhost:8080").replaceAll("/$","");
  ticket.put("startUrl",base+"/api/v1/auth/oauth/start?id="+ticket.get("id")+"&key="+key);return ticket;
 }
 @GetMapping("/start") public void start(@RequestParam String id,@RequestParam String key,HttpServletRequest request,HttpServletResponse response)throws IOException{
  String p=bridge.claim(id,key);var old=request.getSession(false);if(old!=null)old.invalidate();
  request.getSession(true).setAttribute(OAuthLoginBridge.SESSION_KEY,id);response.setHeader("Cache-Control","no-store");response.setHeader("Referrer-Policy","no-referrer");response.sendRedirect("/oauth2/authorization/"+p);
 }
 @PostMapping("/poll") public Map<String,String> poll(@RequestBody Poll p,HttpServletResponse r){r.setHeader("Cache-Control","no-store");return bridge.poll(p.id(),p.secret());}
 @PostMapping("/cancel") @ResponseStatus(HttpStatus.NO_CONTENT) public void cancel(@RequestBody Poll p){bridge.cancel(p.id(),p.secret());}
}
