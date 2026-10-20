package com.travel.planner.service;

import com.travel.planner.dto.AiRouteResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/** 일정 응답에 교통 패스 추천을 붙인다. 실패해도 일정 생성은 계속된다. */
@Service
@RequiredArgsConstructor
public class PassAdvisorService {

    private final FareDataService fareData;
    private final TransitNameService names;
    @org.springframework.beans.factory.annotation.Autowired
    private CollectedPassCatalog collected;

    public void apply(AiRouteResponse response) {
        try {
            var snapshot=collected!=null && collected.configured() ? collected.snapshot() : null;
            var passes=snapshot==null?fareData.passes():snapshot.passes();
            java.util.function.Function<String,com.travel.planner.entity.TransportPass> rows=snapshot==null?fareData::passRow:snapshot.rows()::get;
            PassAdvice.apply(response, passes, rows, names==null?null:names::line);
            MobilePassCosts.apply(response,passes,rows);

        } catch (Exception e) {
            System.out.println("[요금] 패스 추천을 계산하지 못했습니다: " + e.getMessage());
            // 화면이 항상 목록을 받도록 한다 (추천 없음)
            if (response != null) {
                response.setPasses(new java.util.ArrayList<>());
                response.setTransitFareWithPassesYen(null);
            }
        }
    }
}
