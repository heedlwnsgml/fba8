package com.travel.planner.service;
import com.travel.planner.entity.Place;
import java.util.Locale;
import java.util.regex.Pattern;

/** Distinguish a collection of vendors from one restaurant without claiming every vendor sells one dish. */
public final class DiningInformation {
    private DiningInformation(){}
    private static final Pattern AREA=Pattern.compile("식당가|먹자골목|음식거리|푸드코트|푸드홀|라멘.*거리|라멘.*골목|족발.*거리|横丁|商店街|food court|food hall|yokocho",Pattern.CASE_INSENSITIVE);
    public static String type(Place p) {
        if(p==null)return null;
        String text=(p.getName()+" "+p.getSubType()).toLowerCase(Locale.ROOT);
        if(AREA.matcher(text).find())return "식당가";
        boolean food= com.travel.planner.util.PlaceKind.of(p).isFood() || "식음".equals(p.getCategory()) || "식사".equals(p.getCategory()) || "간식".equals(p.getCategory());
        if(!food)return null;
        if(p.getName()==null || p.getName().contains("자유 식사"))return "식사 장소 미확인";
        if(java.util.regex.Pattern.compile("(시장|市場|market)$",Pattern.CASE_INSENSITIVE).matcher(p.getName()).find() || "시장".equals(p.getSubType()))return "시장";
        return "식당";
    }
    public static String guide(Place p) {
        if("시장".equals(type(p)))return "여러 판매점이 모인 시장입니다. 식사 메뉴와 좌석·영업시간은 점포마다 다릅니다.";
        if(!"식당가".equals(type(p)))return null;
        String name=p.getName()==null?"":p.getName();
        String specialty=name.contains("라멘") || name.contains("ラーメン")?"대표 먹거리는 라멘입니다. ":name.contains("족발")?"대표 먹거리는 족발입니다. ":"";
        return "여러 식당·판매점 중에서 선택하는 구역입니다. "+specialty+"점포별 메뉴·가격·영업시간이 다르며, 다른 음식의 판매 여부는 방문할 점포에서 확인해주세요.";
    }
}
