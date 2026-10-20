# 선택 가능한 50개 지역 대중교통·패스 적재 결과

작업 시작: 2026-10-07T17:56:18Z; 수집 종료 기한: 2026-10-07T18:56:18Z. 검증: 2026-10-07T18:55:04.563017+00:00.

패스 128개(성인/아동·기간·구매 방식 변형별 상품), 공식 GTFS 23개, GTFS 노선 레코드 1,678개, 정류장 레코드 27,344개, 운행편 127,916개, 정류장 시각 2,746,964개, 경로 좌표 375,693개. 노선·정류장은 변형/중복이 포함된 레코드 수입니다.

50개 지역 모두 관련 패스가 최소 1개 확보되었습니다. 모든 지역의 모든 교통망 확보를 뜻하지 않습니다.

수집 종료: 2026-10-07T18:56:40.931521+00:00; 종료 조건: 1시간 경과. 마지막 주간 잔여 사용량 81% (사용률 19%).

## 적용 범위와 남은 작업

- 공식 GTFS 운행일·시각과 정류장 좌표로 직접 운행편을 조회하는 백엔드 공급자를 연결했습니다. 운영사·노선명·승하차 정류장·대기 및 주행 시간을 반환합니다. 어린이 구간 요금·매칭 불명 요금은 임의 계산하지 않습니다.
- 신규 지역 패스의 자동 비용 비교는 아직 꺼져 있습니다. 등록 가격·범위·자격·이용기간은 조회되지만 정확한 노선 포함/사용일 조건까지 검증하기 전에는 절약 금액을 주장하지 않습니다.
- 환승 경로 검색은 미구현입니다. 저장한 GTFS shapes는 지도에 아직 연결하지 않아 기존 지도 선이 실제 도로/철도 경로로 바뀌지는 않습니다.
- 기존 API·철도 3개 노선과 요코하마 관광버스 시간표를 유지했습니다. MariaDB 장소 데이터는 이번 작업에서 수정하지 않았습니다.
- Google Routes API 비활성화 상태는 이번 적재와 별개입니다. 직접 운행편이 없거나 자료가 없는 구간은 여전히 조회할 수 없습니다.
- 일부 피드는 유효기간이 짧습니다. 특히 마쓰에 2026-10-31, 후라노·도호쿠 2026-11-30까지이며 해당 이후에는 새 시간표가 필요합니다.
- 회원 인증 후 GET /api/v1/transit/catalog, /gtfs-coverage에서 확인할 수 있습니다. 실행 중인 실제 백엔드는 코드 변경 적용을 위해 재시작해야 합니다.
- 신규 수집 도구는 tools/transit_catalog/gtfs_ingest.py, pass_ingest.py, reviewed_pass_ingest.py입니다. 공식 출처·라이선스·해시·확인일과 실패 기록을 보관하고, 실패 시 기존 정상 자료를 보존합니다. reviewed_web_passes.json은 HTTP가 실패했지만 공식 웹 검색 결과로 검토한 자료이며 자동 크롤링 성공으로 표시하지 않습니다.

## 검증

- 백엔드 기존/신규 단위 테스트 89개와 프론트 52개 통과.
- Python 크롤러·GTFS 적재 테스트 14개 통과.
- 실제 적재 DB의 피드별 공개 운행편 경로 검증과 인증 API 조회 검증 수행; 테스트 계정 삭제.
- SQLite 무결성 ok, 외래키 오류 0. 적재 전 백업: workspace work/transit-before-national.sqlite.

## 지역별 확보 상태

| 지역 | GTFS 피드/기존 일부 노선 | 관련 패스 수 | 상태 |
|---|---|---:|---|
| 삿포로 | SAPPORO_BANKEI, HOKKAIDO_CHUO, JOTETSU | 6 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 오타루 | HOKKAIDO_CHUO | 4 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 하코다테 | 시간표 미확보 | 7 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. 실패 자료: HAKODATE_TEISAN_AIRPORT: expired GTFS feed: 20230430 |
| 아사히카와 | ASAHIKAWA_DENKI, FURANO_BUS, DOHOKU | 4 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 후라노 | FURANO_BUS | 4 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 센다이 | SENDAI_CITY_BUS | 8 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 아오모리 | AOMORI_CITY_BUS | 2 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 히로사키 | 시간표 미확보 | 3 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 모리오카 | 시간표 미확보 | 3 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 야마가타 | 시간표 미확보 | 3 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. 실패 자료: YAMAGATA_CITY: HTTP Error 403: Forbidden; YAMAKO_BUS: HTTP Error 403: Forbidden |
| 아이즈와카마쓰 | 시간표 미확보 | 3 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 도쿄 | TOKYO_TOEI_RAIL, TOKYO_TOEI_BUS, YURIKAMOME_MAIN | 8 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 요코하마 | MM21_MAIN, 요코하마 관광버스 2개 순환 노선 | 7 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 가마쿠라 | ENODEN_MAIN | 5 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 닛코 | 시간표 미확보 | 6 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 가와고에 | 시간표 미확보 | 3 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 지바 | 시간표 미확보 | 5 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. 실패 자료: CHIBA_IZUMI_BUS: expired GTFS feed: 20230331 |
| 나고야 | NAGOYA_SRT, NAGOYA_CITY_BUS | 6 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 가나자와 | KANAZAWA_FLATBUS | 2 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 다카야마 | 시간표 미확보 | 2 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 마쓰모토 | 시간표 미확보 | 3 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. 실패 자료: MATSUMOTO_STATION_BUS: HTTP Error 403: Forbidden; MATSUMOTO_TOWN_BUS: HTTP Error 403: Forbidden |
| 시즈오카 | 시간표 미확보 | 3 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 니가타 | NIIGATA_WARD_BUS, NIIGATA_RESIDENT_BUS | 3 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 오사카 | 시간표 미확보 | 9 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 교토 | 시간표 미확보 | 7 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 고베 | 시간표 미확보 | 6 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 나라 | 시간표 미확보 | 9 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 히메지 | 시간표 미확보 | 8 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 와카야마 | 시간표 미확보 | 7 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 히로시마 | 시간표 미확보 | 3 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. 실패 자료: HIRODEN_BUS: HTTP Error 403: Forbidden; HIROSHIMA_BUS: HTTP Error 403: Forbidden; HIROSHIMA_KOTSU: HTTP Error 403: Forbidden |
| 오카야마 | 시간표 미확보 | 3 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 구라시키 | 시간표 미확보 | 2 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 돗토리 | TOTTORI_NIHONKOTSU, TOTTORI_HINOMARU, TOTTORI_CITY | 1 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 마쓰에 | MATSUE_CITY_ICHIBATA | 3 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 시모노세키 | 시간표 미확보 | 10 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 마쓰야마 | 시간표 미확보 | 3 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 다카마쓰 | KOTODEN_RAIL, KOTODEN_BUS | 4 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 고치 | 시간표 미확보 | 4 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 도쿠시마 | 시간표 미확보 | 4 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 나루토 | 시간표 미확보 | 1 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 후쿠오카 | 시간표 미확보 | 14 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 나가사키 | NAGASAKI_KENEI | 12 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 구마모토 | 시간표 미확보 | 16 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 벳푸 | 시간표 미확보 | 15 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 가고시마 | KAGOSHIMA_CITY_BUS | 12 | 확보 노선 범위만 직접 경로 조회 가능. 환승 포함 지역 전체망은 미완료. |
| 나하 | 시간표 미확보 | 8 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 이시가키 | 시간표 미확보 | 2 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 미야코지마 | 시간표 미확보 | 2 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 나고 | 시간표 미확보 | 4 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |
| 오키나와 | 시간표 미확보 | 4 | 패스 자료 확보. 조회 가능한 공식 노선 시간표 추가 적재 필요. |

## 미적재 피드

- HIRODEN_BUS: HTTP Error 403: Forbidden; [공식 자료](https://ajt-mobusta-gtfs.mcapps.jp/static/8/current_data.zip)
- HIROSHIMA_BUS: HTTP Error 403: Forbidden; [공식 자료](https://ajt-mobusta-gtfs.mcapps.jp/static/9/current_data.zip)
- HIROSHIMA_KOTSU: HTTP Error 403: Forbidden; [공식 자료](https://ajt-mobusta-gtfs.mcapps.jp/static/10/current_data.zip)
- YAMAGATA_CITY: HTTP Error 403: Forbidden; [공식 자료](https://api.gtfs-data.jp/v2/organizations/yamagata-yamagatacity/feeds/YamagataCity/files/feed.zip?rid=current)
- YAMAKO_BUS: HTTP Error 403: Forbidden; [공식 자료](https://api.gtfs-data.jp/v2/organizations/yamakobus/feeds/YAMAKOBUS/files/feed.zip?rid=current)
- MATSUMOTO_STATION_BUS: HTTP Error 403: Forbidden; [공식 자료](https://api.gtfs-data.jp/v2/organizations/matsumotocity/feeds/guruttomatsumotobus1/files/feed.zip?rid=current)
- MATSUMOTO_TOWN_BUS: HTTP Error 403: Forbidden; [공식 자료](https://api.gtfs-data.jp/v2/organizations/matsumotocity/feeds/guruttomatsumotobus2/files/feed.zip?rid=current)
- HAKODATE_TEISAN_AIRPORT: expired GTFS feed: 20230430; [공식 자료](https://ckan.hoda.jp/dataset/24d1dd70-5395-4d6b-b41f-0d83e8eabdb9/resource/e407ed56-37c0-4d70-92d6-0fdd3a05aac7/download/gtfs_hakodateteisanbus.zip)
- CHIBA_IZUMI_BUS: expired GTFS feed: 20230331; [공식 자료](https://www.city.chiba.jp/toshi/toshi/kotsu/documents/gtfs_for_google_chiba_izumiarea_cb.zip)

## 공식 시간표 출처·유효기간

- MATSUE_CITY_ICHIBATA: 2026-10-01~2026-10-31; 松江市交通局・一畑バス official open data; freely reusable with attribution; [출처](https://matsue-bus.jp/opendata)
- NIIGATA_WARD_BUS: 2026-10-01~2027-03-31; CC BY 2.1 JP / 新潟市; [출처](https://www.city.niigata.lg.jp/shisei/seisaku/it/open-data/opendata-kankou/od-busgtfsjp.html)
- NIIGATA_RESIDENT_BUS: 2026-10-01~2027-10-13; CC BY 2.1 JP / 新潟市; [출처](https://www.city.niigata.lg.jp/shisei/seisaku/it/open-data/opendata-kankou/od-busgtfsjp.html)
- NAGOYA_SRT: 2026-10-02~2027-03-29; CC BY 4.0 / 名古屋市住宅都市局 / SRT; [출처](https://ckan.odpt.org/dataset/?organization=nagoya_housing_city_planning_bureau&res_format=GTFS%2FGTFS-JP)
- TOKYO_TOEI_RAIL: 2026-10-01~2027-03-12; CC BY 4.0 / 東京都交通局・公共交通オープンデータ協議会 / 도에이 철도; [출처](https://ckan.odpt.org/dataset/train-toei)
- TOKYO_TOEI_BUS: 2026-10-07~2027-10-13; CC BY 4.0 / 東京都交通局・公共交通オープンデータ協議会 / 도에이 버스; [출처](https://ckan.odpt.org/dataset/b_bus_gtfs_jp-toei)
- AOMORI_CITY_BUS: 2026-10-01~2027-07-23; Official Aomori City GTFS-JP open data; attribution required; [출처](https://www.aomoricitybus.com/opendata/index.html)
- NAGASAKI_KENEI: 2026-10-01~2027-04-01; CC BY 4.0 / 長崎県交通局; [출처](https://www.keneibus.jp/local/OpenData)
- KOTODEN_RAIL: 2026-10-01~2027-02-28; CC BY 4.0 / 高松琴平電気鉄道株式会社; [출처](https://www.kotoden.co.jp/publichtm/gtfs/index.html)
- KOTODEN_BUS: 2026-10-01~2027-03-31; CC BY 4.0 / ことでんバス株式会社; [출처](https://www.kotoden.co.jp/publichtm/gtfs/index.html)
- ASAHIKAWA_DENKI: 2026-10-01~2027-10-13; CC BY / 北海道オープンデータ推進協議会・各交通事業者; [출처](https://ckan.hoda.jp/dataset/gtfs-data)
- SAPPORO_BANKEI: 2026-10-01~2027-02-28; CC BY / 北海道オープンデータ推進協議会・各交通事業者; [출처](https://ckan.hoda.jp/dataset/gtfs-data)
- FURANO_BUS: 2026-10-01~2026-11-30; CC BY / 北海道オープンデータ推進協議会・各交通事業者; [출처](https://ckan.hoda.jp/dataset/gtfs-data)
- HOKKAIDO_CHUO: 2026-10-01~2027-03-31; CC BY / 北海道オープンデータ推進協議会・各交通事業者; [출처](https://ckan.hoda.jp/dataset/gtfs-data)
- JOTETSU: 2026-10-01~2027-03-31; CC BY / 北海道オープンデータ推進協議会・各交通事業者; [출처](https://ckan.hoda.jp/dataset/gtfs-data)
- DOHOKU: 2026-10-01~2026-11-30; CC BY / 北海道オープンデータ推進協議会・各交通事業者; [출처](https://ckan.hoda.jp/dataset/gtfs-data)
- KANAZAWA_FLATBUS: 2026-10-01~2027-03-31; CC BY / 金沢市; [출처](https://catalog-data.city.kanazawa.ishikawa.jp/dataset/172014-flatbus)
- TOTTORI_NIHONKOTSU: 2026-10-01~2027-03-31; CC BY 2.1 JP / 鳥取県・各運行事業者（県オープンデータ利用規約）; [출처](https://odp-pref-tottori.tori-info.co.jp/bus.html)
- TOTTORI_HINOMARU: 2026-10-01~2027-03-31; CC BY 2.1 JP / 鳥取県・各運行事業者（県オープンデータ利用規約）; [출처](https://odp-pref-tottori.tori-info.co.jp/bus.html)
- TOTTORI_CITY: 2026-10-01~2027-03-31; CC BY 2.1 JP / 鳥取県・各運行事業者（県オープンデータ利用規約）; [출처](https://odp-pref-tottori.tori-info.co.jp/bus.html)
- KAGOSHIMA_CITY_BUS: 2026-10-01~2027-03-31; CC BY 4.0 / 鹿児島市交通局; [출처](https://data.bodik.jp/dataset/462012_bus-kagoshimacity-kagoshima-jp)
- SENDAI_CITY_BUS: 2026-10-07~2026-11-30; CC BY 4.0 / 仙台市交通局 / Bus information; [출처](https://ckan.odpt.org/dataset/sendai_municipal_bus_realtime_information)
- NAGOYA_CITY_BUS: 2026-10-01~2027-04-30; CC BY 4.0 / 名古屋市交通局自動車運転課 / 市バスGTFS-JP; [출처](https://data.bodik.jp/dataset/231002_7109030000_bus-gtfs-jp)

## 패스 상품·출처

| 상품 | 성인/아동(엔) | 도시 | 이용 조건 | 출처 |
|---|---:|---|---|---|
| 에노덴 노리오리쿤 1일권 | 800/400 | 가마쿠라 | 이용 당일 에노덴 전 노선 무제한. JR·버스 제외. | [공식 자료](https://www.enoden.co.jp/tourism/ticket/noriorikun/) |
| 요코하마 미나토부라리 티켓 | 700/350 | 요코하마 | 지정된 관광 구역 내 버스·지하철에만 적용. 시 전역·JR 제외. 이용 구간 확인 필요. | [공식 자료](https://www.city.yokohama.lg.jp/kotsu/bus/unchin/minatoburari.html) |
| JAPAN RAIL PASS 보통차 7일 | 50000/25000 | 일본 | 공식 온라인 구매 가격. 외국인 단기체류 자격 확인 필요. JR 지정 열차 적용. 노조미·미즈호 추가권, 사철·버스 예외 확인 필요. 구간 미확인 상태에서는 자동 추천 제외. | [공식 자료](https://japanrailpass.net/en/purchase/price/) |
| JAPAN RAIL PASS 보통차 14일 | 80000/40000 | 일본 | 공식 온라인 구매 가격. 외국인 단기체류 자격 확인 필요. JR 지정 열차 적용. 노조미·미즈호 추가권, 사철·버스 예외 확인 필요. 구간 미확인 상태에서는 자동 추천 제외. | [공식 자료](https://japanrailpass.net/en/purchase/price/) |
| JAPAN RAIL PASS 보통차 21일 | 100000/50000 | 일본 | 공식 온라인 구매 가격. 외국인 단기체류 자격 확인 필요. JR 지정 열차 적용. 노조미·미즈호 추가권, 사철·버스 예외 확인 필요. 구간 미확인 상태에서는 자동 추천 제외. | [공식 자료](https://japanrailpass.net/en/purchase/price/) |
| 에노시마·가마쿠라 프리패스 (신주쿠 출발) | 1640/430 | 가마쿠라 | 출발역별 가격. 오다큐 지정 구간·에노덴 적용, 출발역 왕복 조건 확인 필요. 로망스카 특급권 별도. | [공식 자료](https://odakyu-global.com/passes/enoshima-kamakura-freepass/) |
| 에노시마·가마쿠라 프리패스 (후지사와 출발) | 810/410 | 가마쿠라 | 출발역별 가격. 오다큐 지정 구간·에노덴 적용, 출발역 왕복 조건 확인 필요. 로망스카 특급권 별도. | [공식 자료](https://odakyu-global.com/passes/enoshima-kamakura-freepass/) |
| 미나토미라이선 1일권 | 460/230 | 요코하마 | 이용 당일 미나토미라이선 전 구간 무제한. JR·도큐·시영 지하철·버스 제외. | [공식 자료](https://www.mm21railway.co.jp/info/ticket.html) |
| 유리카모메 1일권 | 820/410 | 도쿄 | 이용 당일 유리카모메 전 구간 무제한. 린카이선·JR·도쿄메트로 제외. 24시간권과 별도 상품. | [공식 자료](https://www.yurikamome.co.jp/ride-guidance/fare.html) |
| 유리카모메 24시간권 | 900/450 | 도쿄 | 사용 시작부터 24시간. 자정에 갱신되는 1일권과 다름. 시간 창 비교 구현 전 자동 추천 제외. | [공식 자료](https://www.yurikamome.co.jp/ride-guidance/fare.html) |
| 요코하마 시영버스 1일권 | 600/300 | 요코하마 | 수집된 두 버스 노선의 확인된 요금만 자동 비교. 이용 당일 지정 시영 노선에 적용. JR·사철 제외. 노선별 수집 범위와 적용 조건을 확인 후 비교. | [공식 자료](https://www.city.yokohama.lg.jp/kotsu/bus/unchin/ichinichi.html) |
| 요코하마 시영지하철 1일권 | 740/370 | 요코하마 | 수집된 두 버스 노선의 확인된 요금만 자동 비교. 이용 당일 지정 시영 노선에 적용. JR·사철 제외. 노선별 수집 범위와 적용 조건을 확인 후 비교. | [공식 자료](https://www.city.yokohama.lg.jp/kotsu/bus/unchin/ichinichi.html) |
| 요코하마 버스·지하철 공통 1일권 | 830/420 | 요코하마 | 수집된 두 버스 노선의 확인된 요금만 자동 비교. 이용 당일 지정 시영 노선에 적용. JR·사철 제외. 노선별 수집 범위와 적용 조건을 확인 후 비교. | [공식 자료](https://www.city.yokohama.lg.jp/kotsu/bus/unchin/ichinichi.html) |
| 하코다테 시영 전차 1일권 | 800/400 | 하코다테 | 2025-12-01 개정 요금. 해당 상품 지정 전차/버스만 적용. 1일권은 이용 당일, 24시간권은 개시 후 24시간. 운임 적용 구간 확인 후 비교. | [공식 자료](https://www.city.hakodate.hokkaido.jp/docs/2025060500015/) |
| 하코다테 시영 전차 24시간권 | 1130/570 | 하코다테 | 2025-12-01 개정 요금. 해당 상품 지정 전차/버스만 적용. 1일권은 이용 당일, 24시간권은 개시 후 24시간. 운임 적용 구간 확인 후 비교. | [공식 자료](https://www.city.hakodate.hokkaido.jp/docs/2025060500015/) |
| 하코다테 버스·전차 1일권 | 1600/800 | 하코다테 | 2025-12-01 개정 요금. 해당 상품 지정 전차/버스만 적용. 1일권은 이용 당일, 24시간권은 개시 후 24시간. 운임 적용 구간 확인 후 비교. | [공식 자료](https://www.city.hakodate.hokkaido.jp/docs/2025060500015/) |
| 하코다테 버스·전차 2일권 | 2600/1300 | 하코다테 | 2025-12-01 개정 요금. 해당 상품 지정 전차/버스만 적용. 1일권은 이용 당일, 24시간권은 개시 후 24시간. 운임 적용 구간 확인 후 비교. | [공식 자료](https://www.city.hakodate.hokkaido.jp/docs/2025060500015/) |
| 센다이 지하철 전일 1일권 | 840/420 | 센다이 | 구매 당일 센다이 지하철 전 노선. 버스 제외. | [공식 자료](https://www.kotsu.city.sendai.jp/waribiki/) |
| 센다이 지하철 주말·휴일 1일권 | 620/310 | 센다이 | 토·일·공휴일 및 운영사 지정 연말연시만. 구매 당일 센다이 지하철. | [공식 자료](https://www.kotsu.city.sendai.jp/waribiki/) |
| 루플 센다이 1일권 | 700/350 | 센다이 | 이용 당일 루플 센다이만, 일반 시내버스 제외. | [공식 자료](https://www.kotsu.city.sendai.jp/waribiki/) |
| 루플 센다이·지하철 공통 1일권 | 1000/500 | 센다이 | 이용 당일 루플 센다이 및 센다이 지하철. 일반 시내버스 제외. | [공식 자료](https://www.kotsu.city.sendai.jp/waribiki/) |
| 센다이 시내 구역 버스 1일권 | 750/380 | 센다이 | 센다이역 기준 300엔 구역 시영버스. 루플 및 라쿠텐 셔틀 제외. | [공식 자료](https://www.kotsu.city.sendai.jp/waribiki/) |
| 센다이 근교 구역 버스 1일권 | 1150/580 | 센다이 | 센다이역 기준 410엔 구역 시영버스. 루플 및 라쿠텐 셔틀 제외. | [공식 자료](https://www.kotsu.city.sendai.jp/waribiki/) |
| 교토 지하철·버스 1일권 | 1100/550 | 교토 | 이용 당일 유효(24시간권 아님). 교토 시영 지하철/버스 및 지정 사철 버스 구간만. 외곽 제외 구간 확인 필요. | [공식 자료](https://oneday-pass.kyoto/overview/) |
| 아이즈와카마쓰 하이카라·아카베 1일권 | 700/350 | 아이즈와카마쓰 | 하이카라상·아카베 노선만 이용 당일 무제한. 일반 노선버스·철도 제외. | [공식 자료](https://www.aizubus.com/rosen/machinaka-shuyu.php?stt_lang=en) |
| 나라 공원·니시노쿄 1일권 | 600/300 | 나라 | 해당 상품 지도에 표시된 나라교통 버스 구간만. 이용 당일/연속 2일 유효. 정기 관광버스 제외. | [공식 자료](https://www.narakotsu.co.jp/route/ticket/1day-pass/) |
| 나라·호류지 광역 1일권 | 1100/550 | 나라 | 해당 상품 지도에 표시된 나라교통 버스 구간만. 이용 당일/연속 2일 유효. 정기 관광버스 제외. | [공식 자료](https://www.narakotsu.co.jp/route/ticket/1day-pass-wide/) |
| 나라·야마토지 2일권 | 1650/830 | 나라 | 해당 상품 지도에 표시된 나라교통 버스 구간만. 이용 당일/연속 2일 유효. 정기 관광버스 제외. | [공식 자료](https://www.narakotsu.co.jp/route/ticket/2day-pass/) |
| 후쿠오카 지하철 1일권 | 640/320 | 후쿠오카 | 이용 당일 후쿠오카 지하철 전 노선. JR·버스 제외. 아동 특별 시즌 100엔권은 별도. | [공식 자료](https://subway.city.fukuoka.lg.jp/fare/card/?lan=ja) |
| 후쿠오카 니시테쓰 시내 버스 1일권 | 1200/600 | 후쿠오카 | 후쿠오카 시내 니시테쓰 일반버스 지정 구간. 지하철·고속버스 제외. Kids Free 동반 아동 조건 별도. | [공식 자료](https://www.nishitetsu.jp/bus/jyousha/cityfree/) |
| 가나자와 시내 1일 프리패스 | 800/400 | 가나자와 | 공식 지도 지정 버스 및 호쿠테쓰 철도 일부 역. 관광·고속·특급·라이트업 버스 및 IR 제외. | [공식 자료](https://www.hokutetsu.co.jp/ticket/kanazawa-oneday/) |
| 히다 다카야마 시내 버스 2일권 | 1000/미확인 | 다카야마 | 사루보보·마치나미·다쿠미·노라마이카 지정 노선 연속 2일. 아동 가격 미확인. | [공식 자료](https://www.nouhibus.co.jp/ticket/) |
| 마쓰모토 가미코치선 전철 1일권 | 1420/710 | 마쓰모토 | 알피코 가미코치선 마쓰모토~신시마시마 전 구간. 버스는 포함되지 않음. | [공식 자료](https://www.alpico.co.jp/traffic/ticket/6/) |
| 지바 모노레일 평일 낮 패스 | 630/320 | 지바 | 지바 모노레일 전 노선. 평일 10~18시 승차만, 연말연시·골든위크는 별도. | [공식 자료](https://chiba-monorail.co.jp/index.php/ryoukin/free/) |
| 지바 모노레일 휴일 1일권 | 630/320 | 지바 | 지바 모노레일 전 노선. 토·일·공휴일 및 지정 연말연시·골든위크 당일. | [공식 자료](https://chiba-monorail.co.jp/index.php/ryoukin/free/) |
| 지바 모노레일 휴일 2일권 | 1050/530 | 지바 | 지바 모노레일 전 노선. 연속하는 토·일·공휴일 또는 운영사 지정 특수일 2일. | [공식 자료](https://chiba-monorail.co.jp/index.php/ryoukin/free/) |
| 가와고에 도부 버스 1일권 | 500/250 | 가와고에 | 고에도 명소 순환버스 및 도부 일반버스 지정 구간만. 철도 제외. | [공식 자료](https://www.tobu-bus.com/pc/area/koedo.php) |
| 닛코 세계유산 버스 1일권 | 600/300 | 닛코 | 상품별 도부 닛코 버스 지정 구간만. 철도 미포함. 기리후리 상품은 12/1~3/31 판매하지 않음. | [공식 자료](https://www.tobu-bus.com/pc/service/ticket/nikko.php) |
| 닛코 유모토 온천 버스 2일권 | 3500/1750 | 닛코 | 상품별 도부 닛코 버스 지정 구간만. 철도 미포함. 기리후리 상품은 12/1~3/31 판매하지 않음. | [공식 자료](https://www.tobu-bus.com/pc/service/ticket/nikko.php) |
| 닛코 주젠지 온천 버스 2일권 | 2300/1150 | 닛코 | 상품별 도부 닛코 버스 지정 구간만. 철도 미포함. 기리후리 상품은 12/1~3/31 판매하지 않음. | [공식 자료](https://www.tobu-bus.com/pc/service/ticket/nikko.php) |
| 닛코 기리후리 고원 버스 2일권 | 1500/750 | 닛코 | 상품별 도부 닛코 버스 지정 구간만. 철도 미포함. 기리후리 상품은 12/1~3/31 판매하지 않음. | [공식 자료](https://www.tobu-bus.com/pc/service/ticket/nikko.php) |
| 마쓰야마 이요테쓰 시내·교외 전철 1일권 | 2000/1000 | 마쓰야마 | 디지털 전용, 이요테쓰 시내전차 및 교외전철 전 노선. 봇짱열차·버스 제외. | [공식 자료](https://www.iyotetsu.co.jp/railbus/ticket/1day_rail.html) |
| 고치 도사덴 시내 전차 1일권 | 500/250 | 고치 | 고치역~산바시5 및 아케보노초히가시~게라도리 지정 구간만. | [공식 자료](https://www.tosaden.co.jp/train/oneday.php) |
| 고치 도사덴 전차 전 노선 1일권 | 1000/500 | 고치 | 도사덴 전차 전 노선, 버스 제외. 이용 당일. | [공식 자료](https://www.tosaden.co.jp/train/oneday.php) |
| 도쿠시마 시내 버스 1일권 | 500/미확인 | 도쿠시마 | 도쿠시마 버스 시내 250엔 균일 구역. 아동 반액이라는 공식 조건 확인. 고속버스 제외. | [공식 자료](https://www.tokubus.co.jp/routebus/ticket.html) |
| 도쿠시마·나루토 일반버스 1일권 | 1500/미확인 | 도쿠시마·나루토 | 도쿠시마 버스 일반노선 전 구간. 고속·공항버스 포함 여부 별도 확인. 아동 반액 조건 확인. | [공식 자료](https://www.tokubus.co.jp/routebus/ticket.html) |
| 다카마쓰 고토덴 전철 24시간권 | 1400/700 | 다카마쓰 | 고토덴 전철 전 노선. 버스 제외. 이용 개시 후 시간 단위 유효. | [공식 자료](https://www.kotoden.co.jp/publichtm/kotoden/ticket/quicktrip/index.html) |
| 다카마쓰 고토덴 전철 48시간권 | 2700/1350 | 다카마쓰 | 고토덴 전철 전 노선. 버스 제외. 이용 개시 후 시간 단위 유효. | [공식 자료](https://www.kotoden.co.jp/publichtm/kotoden/ticket/quicktrip/index.html) |
| 나하 유이레일 24시간권 | 1000/500 | 나하 | 유이레일 전 노선 발행 후 24시간, 버스 제외. | [공식 자료](https://www.yui-rail.co.jp/ticketinfo-ticket/ticketinfo/ticket/) |
| 나하 유이레일 48시간권 | 1800/900 | 나하 | 유이레일 전 노선 발행 후 48시간, 버스 제외. | [공식 자료](https://www.yui-rail.co.jp/ticketinfo-ticket/ticketinfo/ticket/) |
| 나가사키 노면전차 1일권 | 600/300 | 나가사키 | 이용 당일 나가사키 전차 전 노선. 매월 셋째 일요일 초등학생 이하 무료 조건 확인. 버스 제외. | [공식 자료](https://www.naga-den.com/pages/12/) |
| 오카야마 전차·지정 버스 1일권 | 400/200 | 오카야마 | 전차 전선 및 오카덴 후지와라단치·다카야선 지정 구간만. 료비 헬로키티버스 제외. 유효기한 2027-03-31 | [공식 자료](https://okayama-kido.co.jp/tram/tram-status-info/post-3248/) |
| 모리오카 덴덴무시 버스 1일권 | 400/200 | 모리오카 | 모리오카 중심 순환 덴덴무시만, 기재된 이용 당일. | [공식 자료](https://www.iwatekenkotsu.co.jp/denden-annai.html) |
| 히로사키 시내 순환버스 1일권 | 600/300 | 히로사키 | 2026-10-01 개정 요금. MegoICa·Suica·PASMO 전용, 시내 순환버스만 당일 유효. | [공식 자료](https://www.hirosaki-kanko.or.jp/edit.html?id=dotemachi_loop_bus) |
| 마쓰에 레이크라인 1일권 | 700/350 | 마쓰에 | 관광 순환 레이크라인만 당일 유효, 일반버스 미포함. | [공식 자료](https://matsue-bus.jp/otoku) |
| 마쓰에·이즈모 여행 패스 2일권 | 3500/1750 | 마쓰에 | 이치바타 전철·버스 및 마쓰에 시영버스·레이크라인. JR·공항연락·고속·임시버스 제외. 디지털 전용. | [공식 자료](https://matsue-bus.jp/otoku) |
| 와카야마 버스 1일권 | 1000/500 | 와카야마 | 와카야마 버스·와카야마 버스 나가 일반노선. 고속·공항리무진·커뮤니티버스 제외. 이용 당일. | [공식 자료](https://www.wakayamabus.co.jp/ticket/) |
| 시즈오카 시즈테쓰 전철 1일권 | 700/350 | 시즈오카 | 시즈테쓰 전철 전 노선, 구매 당일. 버스 미포함. | [공식 자료](https://train.shizutetsu.co.jp/ticket) |
| 시즈오카 전철·버스 1일권 | 1600/800 | 시즈오카 | 전철 전선, 시즈오카·히가시시즈오카·구사나기·시미즈역 기점 편도 730엔 구간 버스 지정 지역. 이용 당일. | [공식 자료](https://train.shizutetsu.co.jp/ticket) |
| 야마가타 버스 1일권 | 1200/600 | 야마가타 | 야마코 버스 지정 지역 당일. 타사·지자체·고속버스 제외. 구역 초과 별도 요금. | [공식 자료](https://www.yamagatakotsu.jp/blog/2022/02/1.html) |
| 히로시마 전차·미야지마 페리 1일권 | 1000/550 | 히로시마 | 히로덴 전철 전선·미야지마마쓰다이 페리만. 미야지마 방문세 100엔 포함. 지정 당일. | [공식 자료](https://www.hiroden.co.jp/ticket-pass/bargain-tickets/oneday.html) |
| 히로시마 전차 1일권 | 700/350 | 히로시마 | 히로덴 전철 전선 지정 당일. 페리·버스 제외. | [공식 자료](https://www.hiroden.co.jp/ticket-pass/bargain-tickets/oneday.html) |
| 가고시마 시영 전차·버스 1일권 | 700/350 | 가고시마 | 시영 전차·시영버스·시티뷰만 이용 당일. 민영버스·페리 제외. | [공식 자료](https://www.kotsu-city-kagoshima.jp/ticket-summary/oneday/) |
| 가고시마 시영 전차·버스 24시간권 | 900/450 | 가고시마 | 시영 전차·시영버스·시티뷰만 개시 후 24시간. 민영버스·페리 제외. | [공식 자료](https://www.kotsu-city-kagoshima.jp/ticket-summary/oneday/) |
| 벳푸 가메노이 벳푸 시내 지정 구간 1일권 | 1100/550 | 벳푸 | 가메노이 일반노선 벳푸 시내 지정 구간만. 고속·공항·관광·커뮤니티버스 제외. 이용 당일/연속 2일. 유효기한 2026-12-31 | [공식 자료](https://ticket-kamenoibus.book.ntmg.com/top/products/8d544699-eb13-5ac6-a9b1-d4976ca4e945?lng=ja-JP) |
| 벳푸 가메노이 벳푸·유후인·아프리칸사파리 지정 구간 1일권 | 1800/900 | 벳푸 | 가메노이 일반노선 벳푸·유후인·아프리칸사파리 지정 구간만. 고속·공항·관광·커뮤니티버스 제외. 이용 당일/연속 2일. 유효기한 2026-12-31 | [공식 자료](https://ticket-kamenoibus.book.ntmg.com/top/products/4c24c869-c341-5962-89d4-f13badb8cc60?lng=ja-JP) |
| 벳푸 가메노이 벳푸 시내 지정 구간 2일권 | 1700/850 | 벳푸 | 가메노이 일반노선 벳푸 시내 지정 구간만. 고속·공항·관광·커뮤니티버스 제외. 이용 당일/연속 2일. 유효기한 2026-12-31 | [공식 자료](https://ticket-kamenoibus.book.ntmg.com/top/products/f458697c-b948-5252-af11-b091c9ea00d9?lng=ja-JP) |
| 벳푸 가메노이 벳푸·유후인·아프리칸사파리 지정 구간 2일권 | 2800/1400 | 벳푸 | 가메노이 일반노선 벳푸·유후인·아프리칸사파리 지정 구간만. 고속·공항·관광·커뮤니티버스 제외. 이용 당일/연속 2일. 유효기한 2026-12-31 | [공식 자료](https://ticket-kamenoibus.book.ntmg.com/top/products/a8759f13-928e-5f82-bb6f-634ceb3e4ee3?lng=ja-JP) |
| 니가타 관광 순환버스 1일권 | 500/250 | 니가타 | 니가타 관광 순환버스만 이용 당일. 일반 노선 버스 제외. | [공식 자료](https://www.city.niigata.lg.jp/kanko/kanko/kankobus/pamphletdownload.files/20260331_ja_cover.pdf) |
| 오키나와 4사 버스 1일 패스 | 2500/1250 | 나하·나고·오키나와 | 오키나와 본섬 4사 일반노선 지정 구간. 고속·공항리무진 등 제외 구간은 상품 지도 확인. 유이레일 포함 상품은 별도 이용 개시·유효조건 적용. | [공식 자료](https://daiichibus.co.jp/ryukyubus/wp-content/uploads/2026/02/OtherCicket.pdf) |
| 오키나와 4사 버스 3일 패스 | 5000/2500 | 나하·나고·오키나와 | 오키나와 본섬 4사 일반노선 지정 구간. 고속·공항리무진 등 제외 구간은 상품 지도 확인. 유이레일 포함 상품은 별도 이용 개시·유효조건 적용. | [공식 자료](https://daiichibus.co.jp/ryukyubus/wp-content/uploads/2026/02/OtherCicket.pdf) |
| 오키나와 4사 버스 3일 패스·유이레일 | 5500/2750 | 나하·나고·오키나와 | 오키나와 본섬 4사 일반노선 지정 구간. 고속·공항리무진 등 제외 구간은 상품 지도 확인. 유이레일 포함 상품은 별도 이용 개시·유효조건 적용. | [공식 자료](https://daiichibus.co.jp/ryukyubus/wp-content/uploads/2026/02/OtherCicket.pdf) |
| 나고야 버스·지하철 1일권 | 870/430 | 나고야 | 시영버스·지하철 전선 당일. 메이테쓰 제외. | [공식 자료](https://www.kotsu.city.nagoya.jp/rp/ticket/TRP0000310.htm) |
| 나고야 시영버스 1일권 | 620/310 | 나고야 | 시영버스·관광 루트 버스 당일. 지하철·메이테쓰 제외. | [공식 자료](https://www.kotsu.city.nagoya.jp/rp/ticket/TRP0000310.htm) |
| 나고야 지하철 24시간권 | 760/380 | 나고야 | 지하철 전선 사용 개시 후 24시간. | [공식 자료](https://www.kotsu.city.nagoya.jp/rp/ticket/TRP0000310.htm) |
| 나고야 도니치 에코 패스 | 620/310 | 나고야 | 토·일·공휴일·매월 8일 및 특별 휴일 다이어 지정일. 시영버스·지하철, 유토리토 고가 구간은 18세 이하 실증 조건 확인. | [공식 자료](https://www.kotsu.city.nagoya.jp/rp/ticket/TRP0000310.htm) |
| ALL SHIKOKU Rail Pass 3일 | 12000/6000 | 마쓰야마·다카마쓰·고치·도쿠시마 | 외국인 단기체류 자격, JR 시코쿠·도사쿠로시오·아사카이간·고토덴·도사덴 철도 지정 구간. 이요테쓰·일반버스·쇼도시마 페리 제외. 2026-10-01 개정. 연속 이용일. | [공식 자료](https://shikoku-railwaytrip.com/railpass.html) |
| ALL SHIKOKU Rail Pass 7일 | 20000/10000 | 마쓰야마·다카마쓰·고치·도쿠시마 | 외국인 단기체류 자격, JR 시코쿠·도사쿠로시오·아사카이간·고토덴·도사덴 철도 지정 구간. 이요테쓰·일반버스·쇼도시마 페리 제외. 2026-10-01 개정. 연속 이용일. | [공식 자료](https://shikoku-railwaytrip.com/railpass.html) |
| JR 간사이 지역 1일 패스 | 2800/1400 | 오사카·교토·고베·나라·히메지·와카야마 | 외국인 단기체류 자격. 공식 지도 JR 일반·쾌속 및 하루카 지정석 2회까지. 신칸센·타 특급·A Seat 제외. 교토 지하철·게이한·한큐 교환권 별도 조건. 연속 이용일. | [공식 자료](https://www.westjr.co.jp/travel-information/en/tickets-passes/jrwest-rail-pass/kansai/) |
| JR 간사이 지역 2일 패스 | 4800/2400 | 오사카·교토·고베·나라·히메지·와카야마 | 외국인 단기체류 자격. 공식 지도 JR 일반·쾌속 및 하루카 지정석 2회까지. 신칸센·타 특급·A Seat 제외. 교토 지하철·게이한·한큐 교환권 별도 조건. 연속 이용일. | [공식 자료](https://www.westjr.co.jp/travel-information/en/tickets-passes/jrwest-rail-pass/kansai/) |
| JR 간사이 지역 3일 패스 | 5800/2900 | 오사카·교토·고베·나라·히메지·와카야마 | 외국인 단기체류 자격. 공식 지도 JR 일반·쾌속 및 하루카 지정석 2회까지. 신칸센·타 특급·A Seat 제외. 교토 지하철·게이한·한큐 교환권 별도 조건. 연속 이용일. | [공식 자료](https://www.westjr.co.jp/travel-information/en/tickets-passes/jrwest-rail-pass/kansai/) |
| JR 간사이 지역 4일 패스 | 7000/3500 | 오사카·교토·고베·나라·히메지·와카야마 | 외국인 단기체류 자격. 공식 지도 JR 일반·쾌속 및 하루카 지정석 2회까지. 신칸센·타 특급·A Seat 제외. 교토 지하철·게이한·한큐 교환권 별도 조건. 연속 이용일. | [공식 자료](https://www.westjr.co.jp/travel-information/en/tickets-passes/jrwest-rail-pass/kansai/) |
| JR 간사이·산인 7일 패스 | 18000/9000 | 오사카·교토·고베·나라·히메지·와카야마·오카야마·구라시키·돗토리·마쓰에 | 외국인 단기체류 자격, 공식 지도 JR 및 지정 사철 구간. 산요 신칸센 신오사카~오카야마만. 도카이도 신칸센 제외. 연속 7일. | [공식 자료](https://www.westjr.co.jp/travel-information/en/tickets-passes/jrwest-rail-pass/kansai_sanin/) |
| JR 오카야마·히로시마·야마구치 5일 패스 | 17000/8500 | 오카야마·구라시키·히로시마·시모노세키·후쿠오카 | 외국인 단기체류 자격, JR 공식 지정 지도 구간만. 산요 신칸센 오카야마~하카타 포함. 타사·규슈 신칸센 제외. 연속 5일. | [공식 자료](https://www.westjr.co.jp/travel-information/en/tickets-passes/jrwest-rail-pass/okayama_hiroshima_yamaguchi/) |
| 삿포로 지하철 1일권 | 830/420 | 삿포로 | 지하철 전선 이용 당일. 버스·전차 제외. | [공식 자료](https://www.city.sapporo.jp/st/josyaken/card.html) |
| 삿포로 도니치카 | 520/260 | 삿포로 | 토·일·공휴일 및 12/29~1/3만, 지하철 전선 당일. | [공식 자료](https://www.city.sapporo.jp/st/josyaken/card.html) |
| 홋카이도 레일 패스 5일 사전구매 | 22000/11000 | 삿포로·오타루·하코다테·아사히카와·후라노 | 일본 외 여권, 사전구매 가격·연속 이용일. JR 홋카이도 지정 철도·일부 버스. 신칸센·도난이사리비·지하철·전차 제외. | [공식 자료](https://www.jrhokkaido.co.jp/global/english/ticket/railpass/index.html) |
| 홋카이도 레일 패스 7일 사전구매 | 28000/14000 | 삿포로·오타루·하코다테·아사히카와·후라노 | 일본 외 여권, 사전구매 가격·연속 이용일. JR 홋카이도 지정 철도·일부 버스. 신칸센·도난이사리비·지하철·전차 제외. | [공식 자료](https://www.jrhokkaido.co.jp/global/english/ticket/railpass/index.html) |
| 홋카이도 레일 패스 10일 사전구매 | 37000/18500 | 삿포로·오타루·하코다테·아사히카와·후라노 | 일본 외 여권, 사전구매 가격·연속 이용일. JR 홋카이도 지정 철도·일부 버스. 신칸센·도난이사리비·지하철·전차 제외. | [공식 자료](https://www.jrhokkaido.co.jp/global/english/ticket/railpass/index.html) |
| 삿포로·후라노 4일 패스 사전구매 | 11000/5500 | 삿포로·오타루·아사히카와·후라노 | 일본 외 여권, 사전구매·연속 4일. 지정 JR 철도만. 도마무·버스·지하철·전차 제외. | [공식 자료](https://www.jrhokkaido.co.jp/global/english/ticket/railpass/index.html) |
| JR EAST PASS 5일 | 35000/17500 | 센다이·아오모리·히로사키·모리오카·야마가타·아이즈와카마쓰·도쿄·요코하마·가마쿠라·닛코·가와고에·지바·마쓰모토·니가타 | 일본 외 여권, 연속 이용일. JR 동일본·지정 타사 구간, 도부 직통 특급 조건 별도. 도카이도 신칸센·이즈큐·후지큐 제외. | [공식 자료](https://www.jreast.co.jp/en/multi/pass/eastpass.html) |
| JR EAST PASS 10일 | 50000/25000 | 센다이·아오모리·히로사키·모리오카·야마가타·아이즈와카마쓰·도쿄·요코하마·가마쿠라·닛코·가와고에·지바·마쓰모토·니가타 | 일본 외 여권, 연속 이용일. JR 동일본·지정 타사 구간, 도부 직통 특급 조건 별도. 도카이도 신칸센·이즈큐·후지큐 제외. | [공식 자료](https://www.jreast.co.jp/en/multi/pass/eastpass.html) |
| Tokyo Subway Ticket 24시간 | 1000/500 | 도쿄 | 방일 관광객 등 판매 자격 확인. 도쿄메트로·도에이 지하철 전선, JR·사철·버스 제외. 개시 후 시간 단위. | [공식 자료](https://www.kotsu.metro.tokyo.jp/eng/tickets/index.html) |
| Tokyo Subway Ticket 48시간 | 1500/750 | 도쿄 | 방일 관광객 등 판매 자격 확인. 도쿄메트로·도에이 지하철 전선, JR·사철·버스 제외. 개시 후 시간 단위. | [공식 자료](https://www.kotsu.metro.tokyo.jp/eng/tickets/index.html) |
| Tokyo Subway Ticket 72시간 | 2000/1000 | 도쿄 | 방일 관광객 등 판매 자격 확인. 도쿄메트로·도에이 지하철 전선, JR·사철·버스 제외. 개시 후 시간 단위. | [공식 자료](https://www.kotsu.metro.tokyo.jp/eng/tickets/index.html) |
| 도쿄 도에이 교통 1일권 | 700/350 | 도쿄 | 도에이 지하철·버스·도덴·닛포리토네리 당일. 메트로·JR 제외. | [공식 자료](https://www.kotsu.metro.tokyo.jp/eng/tickets/index.html) |
| 오사카 엔조이 에코 평일권 | 820/310 | 오사카 | 메트로·시티버스 당일, 유메시마·IKEA·USJ·온디맨드·지정 순환버스 제외. 달력 기준 평일/토일공휴일. | [공식 자료](https://subway-tr.osakametro.co.jp/ko/guide/page/enjoy-eco.php) |
| 오사카 엔조이 에코 휴일권 | 620/310 | 오사카 | 메트로·시티버스 당일, 유메시마·IKEA·USJ·온디맨드·지정 순환버스 제외. 달력 기준 평일/토일공휴일. | [공식 자료](https://subway-tr.osakametro.co.jp/ko/guide/page/enjoy-eco.php) |
| 구마모토 시영전차 모바일 1일권 | 500/250 | 구마모토 | 모바일 전용 당일 시영전차만, 버스 제외. 종이권과 가격 다름. | [공식 자료](https://www.kotsu-kumamoto.jp/14ga030111/kihon/pub/Detail.aspx?c_id=66&id=1433) |
| 구마모토 시영전차 24시간권 | 600/300 | 구마모토 | 모바일 개시 후 24시간 시영전차만, 버스 제외. | [공식 자료](https://www.kotsu-kumamoto.jp/kihon/pub/detail.aspx?c_id=66&id=1434) |
| 미야코지마 4사 버스 24시간 패스 | 1800/900 | 미야코지마 | 미야코교에이·야치요·교와·중앙교통 일반노선 및 지정 시모지공항 노선. 종료된 미야코지마 루프버스 제외. 아동 3세~초등학생. 앱 개시 후 시간 단위. 유효기한 2027-02-14 | [공식 자료](https://ticket.jorudan.co.jp/miyakojima-maas/ja/) |
| 미야코지마 4사 버스 48시간 패스 | 3000/1500 | 미야코지마 | 미야코교에이·야치요·교와·중앙교통 일반노선 및 지정 시모지공항 노선. 종료된 미야코지마 루프버스 제외. 아동 3세~초등학생. 앱 개시 후 시간 단위. 유효기한 2027-02-14 | [공식 자료](https://ticket.jorudan.co.jp/miyakojima-maas/ja/) |
| SUNQ 北部九州+下関・長門 3일 종이 | 12000/미확인 | 후쿠오카·나가사키·구마모토·벳푸·시모노세키 | 가맹 일반·고속버스 및 지정 선박만. JR·지하철·전차 제외. 지역 경계·제외 노선 확인, 예약 필요 노선 별도. 연속 3일. 1일은 03:00~다음 날 02:59. 아동 전용 가격 미확인. | [공식 자료](https://www.sunqpass.jp/information/info/2024-09-09/JP_20241001price.pdf) |
| SUNQ 北部九州+下関・長門 3일 디지털 | 10000/미확인 | 후쿠오카·나가사키·구마모토·벳푸·시모노세키 | 가맹 일반·고속버스 및 지정 선박만. JR·지하철·전차 제외. 지역 경계·제외 노선 확인, 예약 필요 노선 별도. 개시 후 5일 내 3일 선택. 1일은 03:00~다음 날 02:59. 아동 전용 가격 미확인. | [공식 자료](https://www.sunqpass.jp/information/info/2024-09-09/JP_20241001price.pdf) |
| SUNQ 南部九州 3일 종이 | 10000/미확인 | 구마모토·가고시마 | 가맹 일반·고속버스 및 지정 선박만. JR·지하철·전차 제외. 지역 경계·제외 노선 확인, 예약 필요 노선 별도. 연속 3일. 1일은 03:00~다음 날 02:59. 아동 전용 가격 미확인. | [공식 자료](https://www.sunqpass.jp/information/info/2024-09-09/JP_20241001price.pdf) |
| SUNQ 南部九州 3일 디지털 | 8500/미확인 | 구마모토·가고시마 | 가맹 일반·고속버스 및 지정 선박만. JR·지하철·전차 제외. 지역 경계·제외 노선 확인, 예약 필요 노선 별도. 개시 후 5일 내 3일 선택. 1일은 03:00~다음 날 02:59. 아동 전용 가격 미확인. | [공식 자료](https://www.sunqpass.jp/information/info/2024-09-09/JP_20241001price.pdf) |
| SUNQ 全九州+下関・長門 3일 종이 | 14000/미확인 | 후쿠오카·나가사키·구마모토·벳푸·가고시마·시모노세키 | 가맹 일반·고속버스 및 지정 선박만. JR·지하철·전차 제외. 지역 경계·제외 노선 확인, 예약 필요 노선 별도. 연속 3일. 1일은 03:00~다음 날 02:59. 아동 전용 가격 미확인. | [공식 자료](https://www.sunqpass.jp/information/info/2024-09-09/JP_20241001price.pdf) |
| SUNQ 全九州+下関・長門 3일 디지털 | 12000/미확인 | 후쿠오카·나가사키·구마모토·벳푸·가고시마·시모노세키 | 가맹 일반·고속버스 및 지정 선박만. JR·지하철·전차 제외. 지역 경계·제외 노선 확인, 예약 필요 노선 별도. 개시 후 5일 내 3일 선택. 1일은 03:00~다음 날 02:59. 아동 전용 가격 미확인. | [공식 자료](https://www.sunqpass.jp/information/info/2024-09-09/JP_20241001price.pdf) |
| SUNQ 全九州+下関・長門 4일 종이 | 17000/미확인 | 후쿠오카·나가사키·구마모토·벳푸·가고시마·시모노세키 | 가맹 일반·고속버스 및 지정 선박만. JR·지하철·전차 제외. 지역 경계·제외 노선 확인, 예약 필요 노선 별도. 연속 4일. 1일은 03:00~다음 날 02:59. 아동 전용 가격 미확인. | [공식 자료](https://www.sunqpass.jp/information/info/2024-09-09/JP_20241001price.pdf) |
| SUNQ 全九州+下関・長門 4일 디지털 | 15000/미확인 | 후쿠오카·나가사키·구마모토·벳푸·가고시마·시모노세키 | 가맹 일반·고속버스 및 지정 선박만. JR·지하철·전차 제외. 지역 경계·제외 노선 확인, 예약 필요 노선 별도. 개시 후 7일 내 4일 선택. 1일은 03:00~다음 날 02:59. 아동 전용 가격 미확인. | [공식 자료](https://www.sunqpass.jp/information/info/2024-09-09/JP_20241001price.pdf) |
| 이시가키 동버스 24시간권 | 1000/500 | 이시가키 | 동버스 일반 노선 전선. 정기 관광버스 제외. 24시간권은 구매 시각부터; 3일권은 운영사 이용일 기준 확인. | [공식 자료](https://www.azumabus.co.jp/ticket/) |
| 이시가키 동버스 미치쿠사 3일권 | 2000/1000 | 이시가키 | 동버스 일반 노선 전선. 정기 관광버스 제외. 24시간권은 구매 시각부터; 3일권은 운영사 이용일 기준 확인. | [공식 자료](https://www.azumabus.co.jp/ticket/) |
| JR 규슈 all 3일 일반 판매 | 22000/11000 | 후쿠오카·나가사키·구마모토·벳푸·가고시마·시모노세키 | 외국인 단기체류 관광객, 연속 이용일. 지정 JR 규슈 철도만. 고쿠라~하카타 산요 신칸센·버스·지하철·타사 철도 제외. 온라인 부킹 가격은 별도 상품. 시모노세키 포함 지정 지도. | [공식 자료](https://www.jrkyushu.co.jp/english/railpass/railpass.html) |
| JR 규슈 all 5일 일반 판매 | 24000/12000 | 후쿠오카·나가사키·구마모토·벳푸·가고시마·시모노세키 | 외국인 단기체류 관광객, 연속 이용일. 지정 JR 규슈 철도만. 고쿠라~하카타 산요 신칸센·버스·지하철·타사 철도 제외. 온라인 부킹 가격은 별도 상품. 시모노세키 포함 지정 지도. | [공식 자료](https://www.jrkyushu.co.jp/english/railpass/railpass.html) |
| JR 규슈 all 7일 일반 판매 | 26000/13000 | 후쿠오카·나가사키·구마모토·벳푸·가고시마·시모노세키 | 외국인 단기체류 관광객, 연속 이용일. 지정 JR 규슈 철도만. 고쿠라~하카타 산요 신칸센·버스·지하철·타사 철도 제외. 온라인 부킹 가격은 별도 상품. 시모노세키 포함 지정 지도. | [공식 자료](https://www.jrkyushu.co.jp/english/railpass/railpass.html) |
| JR 규슈 north 3일 일반 판매 | 15000/7500 | 후쿠오카·나가사키·구마모토·벳푸 | 외국인 단기체류 관광객, 연속 이용일. 지정 JR 규슈 철도만. 고쿠라~하카타 산요 신칸센·버스·지하철·타사 철도 제외. 온라인 부킹 가격은 별도 상품. 북규슈 구마모토·미스미 및 오이타 이북 지정 지도만. | [공식 자료](https://www.jrkyushu.co.jp/english/railpass/railpass.html) |
| JR 규슈 north 5일 일반 판매 | 17000/8500 | 후쿠오카·나가사키·구마모토·벳푸 | 외국인 단기체류 관광객, 연속 이용일. 지정 JR 규슈 철도만. 고쿠라~하카타 산요 신칸센·버스·지하철·타사 철도 제외. 온라인 부킹 가격은 별도 상품. 북규슈 구마모토·미스미 및 오이타 이북 지정 지도만. | [공식 자료](https://www.jrkyushu.co.jp/english/railpass/railpass.html) |
| JR 규슈 south 3일 일반 판매 | 12000/6000 | 구마모토·가고시마 | 외국인 단기체류 관광객, 연속 이용일. 지정 JR 규슈 철도만. 고쿠라~하카타 산요 신칸센·버스·지하철·타사 철도 제외. 온라인 부킹 가격은 별도 상품. 남규슈 구마모토~가고시마 신칸센 및 지정 지도만. | [공식 자료](https://www.jrkyushu.co.jp/english/railpass/railpass.html) |
| 오키나와 4사 버스·유이레일 1일권 | 3000/1500 | 나하·나고·오키나와 | 4사 지정 일반 노선 및 유이레일 당일. 고속·리무진 등 제외 노선 확인. | [공식 자료](https://daiichibus.co.jp/ryukyubus/wp-content/uploads/2026/02/OtherCicket.pdf) |
| 나하 버스 시내 1일권 | 840/420 | 나하 | 나하버스 지정 시내노선만. 시외버스·유이레일 제외. | [공식 자료](https://daiichibus.co.jp/ryukyubus/wp-content/uploads/2026/02/OtherCicket.pdf) |
| 나하 버스모노패스 | 1500/750 | 나하 | 나하버스 지정 시내노선+유이레일 당일. 4사 광역권과 다름. | [공식 자료](https://daiichibus.co.jp/ryukyubus/wp-content/uploads/2026/02/OtherCicket.pdf) |
| 히메지성 루프 버스 1일권 | 600/300 | 히메지 | 히메지성 루프 버스 및 운영사가 지정한 일반버스 정류장 구간만. 시설 입장료는 별도; 이용 당일. | [공식 자료](https://www.himeji-kanko.jp/oyakudachi/7/) |
| 고베 시영 지하철 QR 1일권 | 980/미확인 | 고베 | 성인만 판매. 고베 시영 지하철 전선, 버스·타사 제외. 구매 후 3개월 내 지정 1일, 사용 최종일 2027-03-31. 유효기한 2027-03-31 | [공식 자료](https://kotsu.city.kobe.lg.jp/ensen-navi/bus-railway/kobecitysubwayqr1dayticket/) |
| 다카야마·호쿠리쿠 관광 패스 | 19800/9900 | 나고야·가나자와·다카야마·오사카·교토 | 외국인 단기체류 관광객, 연속 이용일. 지정 JR·호쿠리쿠 신칸센·시라카와고 버스 구간만. 도카이도 신칸센 제외. 지정석 6회까지. | [공식 자료](https://touristpass.jp/en/takayama_hokuriku/) |
| 이세·구마노·와카야마 관광 패스 | 16500/8250 | 나고야·와카야마·나라·오사카 | 외국인 단기체류 관광객, 연속 이용일. 지정 JR·이세철도·와카야마 전철 및 지정 버스 구간만. 지정 지도상의 나라현 JR 구간 포함, 사철 제외. 지정석 6회까지. | [공식 자료](https://touristpass.jp/en/ise_kumano/) |
| 후지·시즈오카 관광 미니 패스 | 6500/3250 | 시즈오카 | 외국인 단기체류 관광객, 연속 이용일. 지정 JR 보통·쾌속 자유석 및 지정 버스·선박 구간만. 신칸센·특급·지정석 제외. | [공식 자료](https://touristpass.jp/en/fuji_shizuoka/) |
| 히메지 시로노마치 2일 종이권 | 1900/950 | 히메지 | 히메지역 250엔 구간·10계통 버스 2일, 쇼샤 로프웨이 왕복·루프버스 1회. 입장료 별도, 디지털권과 구성이 다름. | [공식 자료](https://www.himeji-kanko.jp/useful/21/) |
| 히메지 시로노마치 2일 디지털권 | 1900/미확인 | 히메지 | 1세 이상 동일 가격. 히메지역 250엔 구간·10계통 버스 2일 및 쇼샤 로프웨이 왕복. 종이권의 루프버스 1회권 미포함. 입장료 별도. | [공식 자료](https://www.himeji-kanko.jp/useful/21/) |

## 추가 조사에서 확인된 제한

- 고베 시영버스: 공식 교통국은 공공교통 데이터 HUB 등록이 필요하다고 안내합니다. 이번 작업은 계정 생성 없이 진행했습니다.
- 오키나와 OTTOP 공개 API 문서는 apiKey 인증을 요구합니다. 이번에는 해당 키가 없는 노선을 임의 시간표로 만들지 않았습니다.
- 고베 구형 종이 지하철/버스 1일권은 2026-09-30 사용 종료이므로 신규 등록하지 않고 현행 QR 지하철권을 등록했습니다.
- 히메지 2일 종이권/디지털권은 로프웨이와 루프버스 포함 범위가 서로 달라 별도 상품으로 저장했습니다.
