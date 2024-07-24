package r.r.refreezer.models;

import org.json.JSONArray;
import org.json.JSONObject;

public class LyricsClassic extends Lyrics {
    public LyricsClassic(){};

    public LyricsClassic(JSONObject json) {
        // Parse lyrics data
        if (json != null) {
            this.id = json.optString("LYRICS_ID");
            this.writers = json.optString("LYRICS_WRITERS");
            this.unsyncedLyrics = json.optString("LYRICS_TEXT");
            this.copyright = json.optString("LYRICS_COPYRIGHTS");

            JSONArray syncedJsonArray = json.optJSONArray("LYRICS_SYNC_JSON");
            if (syncedJsonArray != null) {
                for (int i = 0; i < syncedJsonArray.length(); i++) {
                    JSONObject syncedJson = syncedJsonArray.optJSONObject(i);
                    if ( syncedJson != null) {
                        SynchronizedLyric lyric = new SynchronizedLyric(syncedJson);
                        if (lyric.getOffset() != 0) { // Assuming 0 is not a valid offset
                            syncedLyrics.add(lyric);
                        }
                    }
                }
            }
        }
    }
}
