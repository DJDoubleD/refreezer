package r.r.refreezer;

import android.content.Context;
import android.util.Log;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Locale;

public class DownloadLog {

    BufferedWriter writer;

    //Open/Create file
    void open(Context context) {
        File file = new File(context.getExternalFilesDir(""), "download.log");
        try {
            if (!file.exists()) {
                file.createNewFile();
            }
            writer = new BufferedWriter(new FileWriter(file, true));
        } catch (Exception ignored) {
            Log.e("DOWN", "Error opening download log!");
        }
    }

    //Close log
    void close() {
        try {
            writer.close();
        } catch (Exception ignored) {
            Log.w("DOWN", "Error closing download log!");
        }
    }

    String time() {
        SimpleDateFormat format = new SimpleDateFormat("yyyy.MM.dd HH:mm:ss", Locale.US);
        return format.format(Calendar.getInstance().getTime());
    }

    //Write error to log
    void error(String info) {
        if (writer == null) return;
        String data = "E:" + time() + ": " + info;
        try {
            writer.write(data);
            writer.newLine();
            writer.flush();
        } catch (Exception ignored) {
            Log.w("DOWN", "Error writing into log.");
        }
        Log.e("DOWN", data);
    }

    //Write error to log with download info
    void error(String info, Download download) {
        if (writer == null) return;
        String data = "E:" +  time() + " (TrackID: " + download.trackId + ", ID: " + Integer.toString(download.id) + "): " +info;
        try {
            writer.write(data);
            writer.newLine();
            writer.flush();
        } catch (Exception ignored) {
            Log.w("DOWN", "Error writing into log.");
        }
        Log.e("DOWN", data);
    }

    //Write warning to log
    void warn(String info) {
        if (writer == null) return;
        String data = "W:" + time() + ": " + info;
        try {
            writer.write(data);
            writer.newLine();
            writer.flush();
        } catch (Exception ignored) {
            Log.w("DOWN", "Error writing into log.");
        }
        Log.w("DOWN", data);
    }

    //Write warning to log with download info
    void warn(String info, Download download) {
        if (writer == null) return;
        String data = "W:" +  time() + " (TrackID: " + download.trackId + ", ID: " + Integer.toString(download.id) + "): " +info;
        try {
            writer.write(data);
            writer.newLine();
            writer.flush();
        } catch (Exception ignored) {
            Log.w("DOWN", "Error writing into log.");
        }
        Log.w("DOWN", data);
    }

}
