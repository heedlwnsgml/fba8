package com.travel.planner.config;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.*;
import org.springframework.web.filter.CorsFilter;
import static org.junit.jupiter.api.Assertions.*;

class WebCorsConfigurationTest {
    private MockHttpServletResponse preflight(String origin) throws Exception {
        var filter=new CorsFilter(new WebCorsConfiguration().corsConfigurationSource("http://localhost:5173,http://127.0.0.1:5173"));
        var req=new MockHttpServletRequest("OPTIONS","/api/v1/plans");
        req.addHeader("Origin",origin);req.addHeader("Access-Control-Request-Method","GET");req.addHeader("Access-Control-Request-Headers","authorization,content-type");
        var res=new MockHttpServletResponse();filter.doFilter(req,res,new MockFilterChain());return res;
    }
    @Test void browserMayPreflightAuthenticatedApi() throws Exception {
        var res=preflight("http://localhost:5173");assertEquals(200,res.getStatus());assertEquals("http://localhost:5173",res.getHeader("Access-Control-Allow-Origin"));
    }
    @Test void arbitrarySitesAreNotAllowed() throws Exception {
        var res=preflight("https://untrusted.example");assertEquals(403,res.getStatus());assertNull(res.getHeader("Access-Control-Allow-Origin"));
    }
}
