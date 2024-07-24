package r.r.refreezer.models;

import org.json.JSONException;
import org.json.JSONObject;

public class SynchronizedLyric {
    private long offset; // in milliseconds
    private long duration; // in milliseconds
    private String text;
    private String lrcTimestamp;

    public SynchronizedLyric(JSONObject json) {
        try {
            if (json.has("milliseconds") && json.has("line")) {
                this.offset = json.getLong("milliseconds");
                this.duration = json.getLong("duration");
                this.text = json.getString("line");
                this.lrcTimestamp = json.optString("lrcTimestamp", json.optString("lrc_timestamp"));
            }
        } catch (JSONException e) {
            // Handle JSON parsing exceptions
            System.err.println("Error parsing SynchronizedLyric JSON: " + e.getMessage());
        }
    }

    // Getters
    public long getOffset() {
        return offset;
    }

    public long getDuration() {
        return duration;
    }

    public String getText() {
        return text;
    }

    public String getLrcTimestamp() {
        return lrcTimestamp;
    }
}