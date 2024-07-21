package r.r.refreezer;

import android.content.ContentValues;
import android.database.Cursor;
import java.util.HashMap;


public class Download {
    int id;
    String path;
    boolean priv;
    int quality;
    String trackId;
    String streamTrackId;
    String trackToken;
    String md5origin;
    String mediaVersion;
    DownloadState state;
    String title;
    String image;

    //Dynamic
    long received;
    long filesize;

    Download(int id, String path, boolean priv, int quality, DownloadState state, String trackId, String md5origin, String mediaVersion, String title, String image, String trackToken, String streamTrackId) {
        this.id = id;
        this.path = path;
        this.priv = priv;
        this.trackId = trackId;
        this.md5origin = md5origin;
        this.state = state;
        this.mediaVersion = mediaVersion;
        this.title = title;
        this.image = image;
        this.quality = quality;
        this.trackToken = trackToken;
        this.streamTrackId = streamTrackId;
    }

    enum DownloadState {
        NONE(0),
        DOWNLOADING (1),
        POST(2),
        DONE(3),
        DEEZER_ERROR(4),
        ERROR(5);

        private final int value;
        private DownloadState(int value) {
            this.value = value;
        }
        public int getValue() {
            return value;
        }
    }

    //Negative TrackIDs = User uploaded MP3s.
    public boolean isUserUploaded() {
        return trackId.startsWith("-");
    }

    //Get download from SQLite cursor, HAS TO ALIGN (see DownloadsDatabase onCreate)
    static Download fromSQL(Cursor cursor) {
        return new Download(cursor.getInt(0),
                cursor.getString(1),
                cursor.getInt(2) == 1,
                cursor.getInt(3),
                DownloadState.values()[cursor.getInt(4)],
                cursor.getString(5),
                cursor.getString(6),
                cursor.getString(7),
                cursor.getString(8),
                cursor.getString(9),
                cursor.getString(10),
                cursor.getString(11)
        );
    }

    //Convert object from method call to SQL ContentValues
    static ContentValues flutterToSQL(HashMap data) {
        ContentValues values = new ContentValues();
        values.put("path", (String)data.get("path"));
        values.put("private", ((boolean)data.get("private")) ? 1 : 0);
        values.put("state", 0);
        values.put("trackId", (String)data.get("trackId"));
        values.put("md5origin", (String)data.get("md5origin"));
        values.put("mediaVersion", (String)data.get("mediaVersion"));
        values.put("title", (String)data.get("title"));
        values.put("image", (String)data.get("image"));
        values.put("quality", (int)data.get("quality"));
        values.put("trackToken", (String)data.get("trackToken"));
        values.put("streamTrackId", (String)data.get("streamTrackId"));

        return values;
    }

    //Used to send data to Flutter
    HashMap toHashMap() {
        HashMap map = new HashMap();
        map.put("id", id);
        map.put("path", path);
        map.put("private", priv);
        map.put("quality", quality);
        map.put("trackId", trackId);
        map.put("state", state.getValue());
        map.put("title", title);
        map.put("image", image);
        //Only useful data, some are passed in updates
        return map;
    }
}

