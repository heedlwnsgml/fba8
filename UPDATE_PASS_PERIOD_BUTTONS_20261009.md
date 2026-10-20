# 일정 생성 버튼과 기간별 패스 추천 수정

수정 대상: `C:\Users\USER\Desktop\TravelPlanner_GitHub_refresh`

- 일정 이름 입력 창의 취소/다음을 같은 너비와 최소 높이로 배치했습니다. 취소는 왼쪽, 다음은 오른쪽입니다.
- 생성 중 화면의 생성 취소/홈으로 이동을 모두 전체 너비, 높이 56으로 맞췄습니다.
- 전국 및 지원 지역 JR 패스를 연속 사용 기간별로 비교합니다. 실제 첫 적용 이동일에 개시하고 기간이 겹치지 않는 패스 조합을 선택합니다.
- 추천에 시작~종료 일차, 실제 날짜, 패스 이름과 엔화 가격을 표시합니다. 교통비 합계에 동일 이동 요금을 두 번 할인하지 않습니다.
- 사업자·지역·노선 정보가 확인된 범위에서 지역 패스를 비교합니다. 지역 JR 서일본 신칸센 경계처럼 역 단위 적용 범위를 확인하지 못한 구간은 제외합니다. 미확인 사업자를 JR로 가정한 참고 비교는 구매 추천/최적 요금에 포함하지 않습니다.

## 가격 확인

DB 129개 패스 목록을 조회하고 주요 추천 상품을 공식 안내와 대조했습니다. 확인한 상품의 현재 DB 금액과 공식 금액이 일치해 숫자를 임의로 바꾸지 않았습니다. 129개 모든 상품에 대한 전체 재검증을 완료했다는 뜻은 아닙니다.

- [전국 JR PASS 공식 가격](https://japanrailpass.net/kr/purchase/price/): 온라인 보통차 7/14/21일 50,000/80,000/100,000엔. 외부 판매 방식과 그린차 상품은 별도 가격입니다.
- [JR EAST 2026 안내](https://www.jreast.co.jp/zh-CHT/press/2025/20260128_ho03.pdf): 5/10일 35,000/50,000엔.
- [JR 규슈](https://www.jrkyushu.co.jp/korean/railpass/): 일반 판매 전규슈 3/5/7일 22,000/24,000/26,000엔. 온라인 구매 할인은 별도 상품 조건입니다.
- [JR 홋카이도](https://www.jrhokkaido.co.jp/global/english/ticket/railpass/index.html): 사전 구매 5/7/10일 22,000/28,000/37,000엔. 역 구매는 가격이 다릅니다.
- [도쿄 메트로](https://www.tokyometro.jp/ticket/value/1day/index.html): 메트로 전용 24시간 700엔. 도에이 포함 Tokyo Subway Ticket과 구별해야 합니다.
- [Tokyo Subway QR 2026 개정](https://www.tokyometro.jp/lang_en/news/images_h/metroNews260130_g03-E.pdf): 24/48/72시간 1,000/1,500/2,000엔.
- [에노덴](https://www.enoden.co.jp/tourism/ticket/noriorikun/): 1일 성인 800엔.
- [유리카모메](https://www.yurikamome.co.jp/ride-guidance/fare.html): 1일 820엔, 24시간 900엔으로 다른 상품입니다.
- [요코하마 시영](https://www.city.yokohama.lg.jp/kotsu/bus/unchin/ichinichi.html): 버스 600엔, 지하철·버스 공통 830엔.
- [하코다테 시전](https://www.city.hakodate.hokkaido.jp/tram/value-ticket/index.html): 당일권 800엔, 24시간권 1,130엔으로 다른 상품입니다.

요금 기준은 성인 1인입니다. 평균 이동 요금이 포함된 일정의 절약액은 예상치입니다. 패스의 방문객 이용 자격 등은 해당 상품 조건을 충족해야 합니다. 이번 계산은 지원 상품의 연속 일 단위 JR 기간과 당일권을 대상으로 하며, 48/72시간권의 시각 단위 조합 최적화는 포함하지 않습니다. JR 기간끼리는 겹치지 않도록 비교하므로 같은 날 여러 지역 JR 패스를 함께 쓰는 모든 조합까지 탐색하지 않습니다.

## 검증 및 적용

- 백엔드 전체 140개: 실패/오류 0, 1개 건너뜀. 별도 기간 JR 패스 두 개, JR EAST→규슈, 지역/사업자 제외, JR 일일권 중복 할인, JR·지하철 공통권 중복 할인 회귀 테스트 추가.
- Flutter 전체 89개 통과.
- 변경 프론트 3개 파일 정적 분석: 오류/경고 없음, 기존 정보 수준 항목 18개.
- Android debug APK 빌드 완료: `A5front\build\app\outputs\flutter-apk\app-debug.apk`.
- 8080 백엔드는 생성 작업이 없는 것을 확인한 후 재시작했습니다.
- USB 연결 목록이 비어 있어 이번 APK의 휴대폰 설치 및 실제 화면 확인은 수행하지 못했습니다.
- 기존 저장 일정에 보관된 교통비 비교 결과는 이전 형식일 수 있습니다. 새 일정 생성 후 기간별 추천을 확인하세요.
