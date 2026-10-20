package com.travel.planner.controller;
import com.travel.planner.service.UserProfileService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.Map;
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/auth/me")
public class UserProfileController {
    private final UserProfileService profiles;
    private final ExchangeRateController exchangeRates;
    record RenameRequest(String displayName) {}
    @GetMapping public Map<String,Object> get(Authentication authentication) {var result=new java.util.LinkedHashMap<>(profiles.get(authentication.getName()));result.put("isAdmin",authentication.getAuthorities().stream().anyMatch(a->a.getAuthority().equals("ROLE_ADMIN")));result.put("canEditExchangeRate",exchangeRates.canEdit(authentication));return result;}
    @PatchMapping public Map<String,Object> rename(Authentication authentication,@RequestBody RenameRequest request) {profiles.rename(authentication.getName(),request.displayName());return get(authentication);}
}
