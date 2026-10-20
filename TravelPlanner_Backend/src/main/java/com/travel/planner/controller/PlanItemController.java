package com.travel.planner.controller;
import com.travel.planner.service.PlanReplaceService;
import com.travel.planner.service.SavedPlanQueryService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.*;
@RestController
@RequestMapping("/api/v1/plans/{planId}/items")
@RequiredArgsConstructor
public class PlanItemController {
    private final com.travel.planner.service.PlanItemAdjustmentService replacements;
    private final SavedPlanQueryService saved;
    @GetMapping("/{itemId}/alternatives")
    public List<Map<String,Object>> alternatives(Authentication auth,@PathVariable Long planId,@PathVariable Long itemId) {
        return replacements.alternatives(auth.getName(),planId,itemId,null,null);
    }
    @PostMapping("/{itemId}/alternatives")
    public List<Map<String,Object>> filteredAlternatives(Authentication auth,@PathVariable Long planId,@PathVariable Long itemId,@RequestBody Map<String,String> body) {
        return replacements.alternatives(auth.getName(),planId,itemId,body.get("theme"),body.get("companion"));
    }
    @PatchMapping("/{itemId}")
    public Map<String,Object> replace(Authentication auth,@PathVariable Long planId,@PathVariable Long itemId,@RequestBody Map<String,String> body) {
        replacements.replace(auth.getName(),planId,itemId,body.get("placeId"),body.get("theme"),body.get("companion"));
        return saved.detail(auth.getName(),planId);
    }
}
