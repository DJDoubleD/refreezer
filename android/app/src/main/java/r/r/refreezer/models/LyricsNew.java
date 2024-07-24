package r.r.refreezer.models;

import org.json.JSONArray;
import org.json.JSONObject;

public class LyricsNew extends Lyrics {
    public LyricsNew() {}

    public LyricsNew(JSONObject json) {
        // Check for errors in the json
        JSONArray errorsArray = json.optJSONArray("errors");
        if (errorsArray != null && errorsArray.length() > 0) {
            JSONObject firstError = errorsArray.optJSONObject(0);
            if (firstError != null) {
                this.errorMessage = firstError.optString("message");
            }
        } else {
            // Parse lyrics data
            JSONObject dataJson = json.optJSONObject("data");
            if (dataJson != null) {
                JSONObject trackJson = dataJson.optJSONObject("track");
                if (trackJson != null) {
                    JSONObject lyricsJson = trackJson.optJSONObject("lyrics");
                    if (lyricsJson != null) {
                        this.id = lyricsJson.optString("id");
                        this.writers = lyricsJson.optString("writers");
                        this.unsyncedLyrics = lyricsJson.optString("text");
                        this.isExplicit = trackJson.optBoolean("isExplicit");
                        this.copyright = lyricsJson.optString("copyright");

                        JSONArray syncedJsonArray = lyricsJson.optJSONArray("synchronizedLines");
                        if (syncedJsonArray != null) {
                            for (int i = 0; i < syncedJsonArray.length(); i++) {
                                JSONObject syncedJson = syncedJsonArray.optJSONObject(i);
                                if (syncedJson != null) {
                                    SynchronizedLyric lyric = new SynchronizedLyric(syncedJson);
                                    syncedLyrics.add(lyric);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}