package com.travel.planner.controller;
import com.travel.planner.service.OAuthLoginBridge;
import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.mock.web.*;
import org.springframework.web.server.ResponseStatusException;
import static org.junit.jupiter.api.Assertions.*;
class OAuthLoginControllerTest {
 @Test void missingKeysAreNamedAndUnsupportedProviderRejected(){var c=new OAuthLoginController(new OAuthLoginBridge(),new MockEnvironment());var e=assertThrows(ResponseStatusException.class,()->c.begin(new OAuthLoginController.Start("google"),new MockHttpServletResponse()));assertTrue(e.getReason().contains("OAUTH_GOOGLE_CLIENT_ID"));assertThrows(ResponseStatusException.class,()->c.begin(new OAuthLoginController.Start("attacker"),new MockHttpServletResponse()));}
 @Test void beginReturnsNoJwtAndBrowserStartCanOnlyBeUsedOnce() throws Exception {
  var b=new OAuthLoginBridge();var c=new OAuthLoginController(b,new MockEnvironment().withProperty("oauth.google.client-id","test-id").withProperty("oauth.google.client-secret","test-secret"));
  var t=c.begin(new OAuthLoginController.Start("google"),new MockHttpServletResponse());assertFalse(t.containsKey("token"));assertFalse(t.containsKey("browserKey"));
  var query=java.net.URI.create(t.get("startUrl")).getQuery();String key=query.substring(query.indexOf("&key=")+5);
  var request=new MockHttpServletRequest();var response=new MockHttpServletResponse();c.start(t.get("id"),key,request,response);
  assertEquals("/oauth2/authorization/google",response.getRedirectedUrl());assertEquals(t.get("id"),request.getSession().getAttribute(OAuthLoginBridge.SESSION_KEY));
  assertThrows(ResponseStatusException.class,()->c.start(t.get("id"),key,new MockHttpServletRequest(),new MockHttpServletResponse()));
 }
}
