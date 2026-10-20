package com.travel.planner.controller;
import com.travel.planner.dto.PlanRequest;
import com.travel.planner.service.PlanGenerationJobs;
import com.travel.planner.service.PlanGenerationService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import tools.jackson.databind.ObjectMapper;
import java.util.Map;
import java.util.List;

/** Existing app background protocol, delegating all planning to the new engine. */
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/plans/generation-jobs")
public class PlanGenerationController {
    private final PlanGenerationJobs jobs;
    private final PlanGenerationService generator;
    private final ObjectMapper mapper;
    @PostMapping
    public PlanGenerationJobs.Result submit(Authentication auth,@RequestBody PlanRequest request) {
        String id=request.getClientRequestId();
        if(id==null || !id.matches("[A-Za-z0-9_-]{1,80}")) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"생성 요청 번호가 올바르지 않습니다.");
        if(request.getIncludeSnacks()!=null) request.setExcludeCafe(!request.getIncludeSnacks());
        String fingerprint=mapper.writeValueAsString(request);
        // The engine normalizes its input; keep the fingerprint independent of those mutations.
        PlanRequest input=mapper.readValue(fingerprint,PlanRequest.class);
        return jobs.submit(auth.getName(),id,fingerprint,()->generator.createPlan(auth.getName(),input));
    }
    @GetMapping("/{id}")
    public Object find(Authentication auth,@PathVariable String id) {
        var result=jobs.find(auth.getName(),id);
        return result==null ? Map.of("id",id,"status","NOT_FOUND") : result;
    }
    @GetMapping
    public List<PlanGenerationJobs.Result> list(Authentication auth) { return jobs.list(auth.getName()); }
    @DeleteMapping("/{id}")
    public PlanGenerationJobs.Result cancel(Authentication auth,@PathVariable String id) { return jobs.cancel(auth.getName(),id); }
}
