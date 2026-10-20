package com.travel.planner.config;
import com.travel.planner.util.JwtUtil;
import com.travel.planner.service.OAuthLoginBridge;
import jakarta.servlet.http.*;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.client.authentication.OAuth2AuthenticationToken;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.security.web.authentication.SimpleUrlAuthenticationSuccessHandler;
import org.springframework.stereotype.Component;
import java.io.IOException;
@Component @RequiredArgsConstructor
public class OAuth2SuccessHandler extends SimpleUrlAuthenticationSuccessHandler {
 private final JwtUtil jwtUtil;private final com.travel.planner.repository.UserRepository userRepository;private final OAuthLoginBridge bridge;
 @Override public void onAuthenticationSuccess(HttpServletRequest request,HttpServletResponse response,Authentication authentication)throws IOException{
  OAuth2User principal=(OAuth2User)authentication.getPrincipal();String email=principal.getAttribute("_planner_email");var user=userRepository.findByEmail(email).orElseThrow();
  var session=request.getSession(false);String id=session==null?null:(String)session.getAttribute(OAuthLoginBridge.SESSION_KEY);
  if(id!=null)bridge.complete(id,((OAuth2AuthenticationToken)authentication).getAuthorizedClientRegistrationId(),jwtUtil.generateToken(email));
  if(session!=null)session.invalidate();response.setHeader("Cache-Control","no-store");response.setHeader("Referrer-Policy","no-referrer");response.setContentType("text/html;charset=UTF-8");
  response.getWriter().write("<!doctype html><html lang='ko'><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>로그인 완료</title><body><h1>로그인 완료</h1><p>여행 플래너 앱 또는 원래 브라우저 탭으로 돌아가세요.</p></body></html>");
 }
}
