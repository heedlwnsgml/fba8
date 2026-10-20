# Lodging integration status — 2026-10-18

Rakuten transport and error handling follow GitHub commit 80ddad1: Java HttpClient sends Referer, Origin and Accept directly (the former HttpURLConnection transport could suppress Origin). The only local client additions are the user-requested separate 24-hour cache and request synchronization. Secret YAML is unchanged. No main DB schema or data changes.

Hotel price lookup uses displayed per-room nightly minimum only. No dated availability search is performed. See HOTEL_SEARCH_CACHE.md.

Verified against the live Rakuten server using this Java client on 2026-10-18: HTTP success, 30 hotels parsed, sample hotelNo 7801 displayed nightly minimum 13,100 JPY. All 16 transport/cache/lodging tests passed. Original secret YAML remains byte-identical.
