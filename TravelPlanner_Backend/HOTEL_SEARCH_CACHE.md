# Hotel search cache

Hotel searches run on demand during lodging cost lookup. Successful provider responses are stored only in `data/hotel-search-cache.sqlite`, separate from the main MariaDB datasource. No source hotel rows or application schema are updated.

Cached responses expire exactly 24 hours after retrieval; reading does not extend expiry. Expired results are never served. Physical cleanup runs at startup and hourly. A fresh search is made on a miss or expiry. Errors and empty results are not cached.

Search keys include provider endpoint and every public request parameter, including location, hotel identifier, check-in/out dates, adults and rooms when applicable. Credentials are excluded from keys and are never saved in this file. The file location can be overridden with `app.hotel-search-cache.path`.

`app.lodging-cost.enabled` enables on-demand lodging prices by default. Provider access must be working; HTTP 403 cannot be solved by caching. Missing prices remain missing rather than being fabricated. Saved itinerary snapshots remain separate from this expiring provider cache.

Only the hotel's displayed minimum per room per night (`hotelMinCharge`) is fetched, regardless of dated or undated travel. No availability search is performed. Therefore the same hotel's cached minimum can be reused across travel dates and party sizes for 24 hours. `lowestNightPerRoomYen` exposes that value separately; the estimated total is minimum × room count × night count. This is a displayed minimum, not a booking quote.
