package com.travel.planner.util;
import com.travel.planner.entity.Region;
import java.util.Map;
import java.util.HashMap;
import java.util.Locale;
/** Exact known Japanese city/airport names; never guesses a region from an arbitrary substring. */
public final class JapanRegionDirectory {
    private static final Map<String, Region> KNOWN = new HashMap<>();
    static {
        register(Region.HOKKAIDO, "삿포로", "오타루", "하코다테", "아사히카와", "후라노");
        register(Region.TOHOKU, "센다이", "아오모리", "히로사키", "모리오카", "야마가타", "아이즈와카마쓰");
        register(Region.KANTO, "도쿄", "요코하마", "가마쿠라", "닛코", "가와고에", "지바");
        register(Region.CHUBU, "나고야", "가나자와", "다카야마", "마쓰모토", "시즈오카", "니가타");
        register(Region.KANSAI, "오사카", "교토", "고베", "나라", "히메지", "와카야마");
        register(Region.CHUGOKU, "히로시마", "오카야마", "구라시키", "돗토리", "마쓰에", "시모노세키");
        register(Region.SHIKOKU, "마쓰야마", "다카마쓰", "고치", "도쿠시마", "나루토");
        register(Region.KYUSHU, "후쿠오카", "나가사키", "구마모토", "벳푸", "가고시마");
        register(Region.OKINAWA, "나하", "이시가키", "미야코지마", "나고", "오키나와");
        register(Region.HOKKAIDO, "신치토세공항", "하코다테공항", "아사히카와공항", "CTS", "HKD", "AKJ");
        register(Region.TOHOKU, "센다이공항", "아오모리공항", "하나마키공항", "쇼나이공항", "후쿠시마공항", "SDJ", "AOJ", "HNA", "SYO", "FKS");
        register(Region.KANTO, "하네다공항", "도쿄국제공항(하네다)", "나리타국제공항", "이바라키공항", "HND", "NRT", "IBR", "도쿄도", "東京", "Tokyo", "치바");
        register(Region.CHUBU, "중부국제공항(센트레아)", "중부국제공항", "주부센트레아국제공항", "코마츠공항", "고마쓰공항", "도야마공항", "신슈마쓰모토공항", "시즈오카공항", "니가타공항", "NGO", "KMQ", "TOY", "MMJ", "FSZ", "KIJ");
        register(Region.KANSAI, "간사이국제공항", "고베공항", "오사카국제공항(이타미)", "이타미공항", "KIX", "UKB", "ITM");
        register(Region.CHUGOKU, "히로시마공항", "오카야마공항", "요나고공항", "이즈모공항", "야마구치우베공항", "HIJ", "OKJ", "YGJ", "IZO", "UBJ");
        register(Region.SHIKOKU, "마쓰야마공항", "타카마츠공항", "다카마쓰공항", "고치공항", "도쿠시마공항", "MYJ", "TAK", "KCZ", "TKS");
        register(Region.KYUSHU, "후쿠오카공항", "기타큐슈공항", "나가사키공항", "구마모토공항", "오이타공항", "사가공항", "미야자키공항", "가고시마공항", "FUK", "KKJ", "NGS", "KMJ", "OIT", "HSG", "KMI", "KOJ");
        register(Region.OKINAWA, "나하공항", "이시가키공항", "시모지시마공항", "미야코공항", "OKA", "ISG", "SHI", "MMY");
    }
    private static String normalize(String name) {
        return name == null ? "" : name.replaceAll("\\s+", "").toLowerCase(Locale.ROOT);
    }
    private static void register(Region region, String... names) {
        for (String name : names) KNOWN.put(normalize(name), region);
    }
    public static Region find(String name) { return KNOWN.get(normalize(name)); }
    private JapanRegionDirectory() {}
}
