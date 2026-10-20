package com.travel.planner.config;
import org.springframework.core.env.Environment;
/** Read supplied Spring OAuth settings; do not replace the registration repository. */
public final class OAuthProviderConfig {
    public static boolean configured(Environment e,String provider) {
        String prefix="spring.security.oauth2.client.registration."+provider+".";
        String id=e.getProperty(prefix+"client-id",e.getProperty("oauth."+provider+".client-id",""));
        String secret=e.getProperty(prefix+"client-secret",e.getProperty("oauth."+provider+".client-secret",""));
        return !id.isBlank() && !secret.isBlank();
    }
}
