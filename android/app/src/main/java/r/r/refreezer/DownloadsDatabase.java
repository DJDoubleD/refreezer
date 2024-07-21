package r.r.refreezer;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

public class DownloadsDatabase extends SQLiteOpenHelper {

    public static final int DATABASE_VERSION = 1;

    public DownloadsDatabase(Context context) {
        super(context, context.getDatabasePath("downloads").toString(), null, DATABASE_VERSION);
    }

    public void onCreate(SQLiteDatabase db) {
        /*
        Downloads:
        id - Download ID (to prevent private/public duplicates)
        path - Folder name, actual path calculated later,
        private - 1 = Offline, 0 = Download,
        quality = Deezer quality int,
        state = DownloadState value
        trackId - Track ID,
        md5origin - MD5Origin,
        mediaVersion - MediaVersion
        title - Download/Track name, for display,
        image - URL to art (for display),
        trackToken - Track Token for Hi-Fi download,
        streamTrackId - Track ID for the stream (differs from track ID when using FALLBACK stream)
        */

        db.execSQL("CREATE TABLE Downloads (id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT, " +
                "private INTEGER, quality INTEGER, state INTEGER, trackId TEXT, md5origin TEXT, " +
                "mediaVersion TEXT, title TEXT, image TEXT, trackToken TEXT, streamTrackId TEXT);");
    }



    //TODO: Currently does nothing
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        onCreate(db);
    }
    public void onDowngrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        onCreate(db);
    }
}
