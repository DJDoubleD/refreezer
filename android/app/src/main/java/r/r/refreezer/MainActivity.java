package r.r.refreezer;

import android.content.ComponentName;
import android.content.ContentValues;
import android.content.Intent;
import android.content.ServiceConnection;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.Message;
import android.os.Messenger;
import android.os.Parcelable;
import android.os.RemoteException;
import android.provider.Settings;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.ryanheise.audioservice.AudioServiceActivity;

import java.lang.ref.WeakReference;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.HashMap;

import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends AudioServiceActivity {
    private static final String CHANNEL = "r.r.refreezer/native";
    private static final String EVENT_CHANNEL = "r.r.refreezer/downloads";
    EventChannel.EventSink eventSink;

    boolean serviceBound = false;
    Messenger serviceMessenger;
    Messenger activityMessenger;
    SQLiteDatabase db;
    StreamServer streamServer;

    //Data if started from intent
    String intentPreload;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        Intent intent = getIntent();
        intentPreload = intent.getStringExtra("preload");
        super.onCreate(savedInstanceState);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        //Flutter method channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL).setMethodCallHandler(((call, result) -> {

            //Add downloads to DB, then refresh service
            if (call.method.equals("addDownloads")) {
                ArrayList<HashMap<?,?>> downloads = call.arguments();

                if (downloads != null) {
                    //TX
                    db.beginTransaction();
                    for (int i = 0; i < downloads.size(); i++) {
                        //Check if exists
                        Cursor cursor = db.rawQuery("SELECT id, state, quality FROM Downloads WHERE trackId == ? AND path == ?",
                                new String[]{(String) downloads.get(i).get("trackId"), (String) downloads.get(i).get("path")});
                        if (cursor.getCount() > 0) {
                            //If done or error, set state to NONE - they should be skipped because file exists
                            cursor.moveToNext();
                            if (cursor.getInt(1) >= 3) {
                                ContentValues values = new ContentValues();
                                values.put("state", 0);
                                values.put("quality", cursor.getInt(2));
                                db.update("Downloads", values, "id == ?", new String[]{Integer.toString(cursor.getInt(0))});
                                Log.d("INFO", "Already exists in DB, updating to none state!");
                            } else {
                                Log.d("INFO", "Already exits in DB!");
                            }
                            cursor.close();
                            continue;
                        }
                        cursor.close();

                        //Insert
                        ContentValues row = Download.flutterToSQL(downloads.get(i));
                        db.insert("Downloads", null, row);
                    }
                    db.setTransactionSuccessful();
                    db.endTransaction();
                    //Update service
                    sendMessage(DownloadService.SERVICE_LOAD_DOWNLOADS, null);

                    result.success(null);
                    return;
                }
            }

            //Get all downloads from DB
            if (call.method.equals("getDownloads")) {
                Cursor cursor = db.query("Downloads", null, null, null, null, null, null);
                ArrayList<HashMap<?,?>> downloads = new ArrayList<>();
                //Parse downloads
                while (cursor.moveToNext()) {
                    Download download = Download.fromSQL(cursor);
                    downloads.add(download.toHashMap());
                }
                cursor.close();
                result.success(downloads);
                return;
            }
            //Update settings from UI
            if (call.method.equals("updateSettings")) {
                Bundle bundle = new Bundle();
                bundle.putString("json", call.argument("json").toString());
                sendMessage(DownloadService.SERVICE_SETTINGS_UPDATE, bundle);

                result.success(null);
                return;
            }
            //Load downloads from DB in service
            if (call.method.equals("loadDownloads")) {
                sendMessage(DownloadService.SERVICE_LOAD_DOWNLOADS, null);
                result.success(null);
                return;
            }
            //Start/Resume downloading
            if (call.method.equals("start")) {
                //Connected
                sendMessage(DownloadService.SERVICE_START_DOWNLOAD, null);
                result.success(serviceBound);
                return;
            }
            //Stop downloading
            if (call.method.equals("stop")) {
                sendMessage(DownloadService.SERVICE_STOP_DOWNLOADS, null);
                result.success(null);
                return;
            }
            //Remove download
            if (call.method.equals("removeDownload")) {
                Bundle bundle = new Bundle();
                bundle.putInt("id", (int)call.argument("id"));
                sendMessage(DownloadService.SERVICE_REMOVE_DOWNLOAD, bundle);
                result.success(null);
                return;
            }
            //Retry download
            if (call.method.equals("retryDownloads")) {
                sendMessage(DownloadService.SERVICE_RETRY_DOWNLOADS, null);
                result.success(null);
                return;
            }
            //Remove downloads by state
            if (call.method.equals("removeDownloads")) {
                Bundle bundle = new Bundle();
                bundle.putInt("state", (int)call.argument("state"));
                sendMessage(DownloadService.SERVICE_REMOVE_DOWNLOADS, bundle);
                result.success(null);
                return;
            }
            //If app was started with preload info (Android Auto)
            if (call.method.equals("getPreloadInfo")) {
                result.success(intentPreload);
                intentPreload = null;
                return;
            }
            //Get architecture
            if (call.method.equals("arch")) {
                result.success(System.getProperty("os.arch"));
                return;
            }
            //Start streaming server
            if (call.method.equals("startServer")) {
                if (streamServer == null) {
                    //Get offline path
                    String offlinePath = getExternalFilesDir("offline").getAbsolutePath();
                    //Start server
                    streamServer = new StreamServer(call.argument("arl"), offlinePath);
                    streamServer.start();
                }
                result.success(null);
                return;
            }
            //Get quality info from stream
            if (call.method.equals("getStreamInfo")) {
                if (streamServer == null) {
                    result.success(null);
                    return;
                }
                StreamServer.StreamInfo info = streamServer.streams.get(call.argument("id").toString());
                if (info != null)
                    result.success(info.toJSON());
                else
                    result.success(null);
                return;
            }
            //Stop services
            if (call.method.equals("kill")) {
                Intent intent = new Intent(this, DownloadService.class);
                stopService(intent);
                if (streamServer != null) {
                    streamServer.stop();
                    streamServer = null;
                }
                //System.exit(0);
                result.success(null);
                return;
            }
            // Check if can request package install permission
            if (call.method.equals("checkInstallPackagesPermission")) {
                result.success(canRequestPackageInstalls());
                return;
            }
            // Request package install permission
            if (call.method.equals("requestInstallPackagesPermission")) {
                requestInstallPackagesPermission();
                result.success(true);
                return;
            }

            result.error("0", "Not implemented!", "Not implemented!");
        }));

        //Event channel (for download updates)
        EventChannel eventChannel = new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), EVENT_CHANNEL);
        eventChannel.setStreamHandler((new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                eventSink = events;
            }

            @Override
            public void onCancel(Object arguments) {
                eventSink = null;
            }
        }));
    }

    private boolean canRequestPackageInstalls() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return getPackageManager().canRequestPackageInstalls();
        }
        return true;
    }

    private void requestInstallPackagesPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + getPackageName())));
        }
    }

    //Start/Bind/Reconnect to download service
    private void connectService() {
        if (serviceBound)
            return;
        //Create messenger
        activityMessenger = new Messenger(new IncomingHandler(this));
        //Start
        Intent intent = new Intent(this, DownloadService.class);
        intent.putExtra("activityMessenger", activityMessenger);
        startService(intent);
        bindService(intent, connection, BIND_AUTO_CREATE);
    }

    @Override
    protected void onStart() {
        super.onStart();

        connectService();
        //Get DB (and leave open!)
        DownloadsDatabase dbHelper = new DownloadsDatabase(getApplicationContext());
        db = dbHelper.getWritableDatabase();

        //Trust all SSL Certs - Credits to Kilowatt36
        TrustManager[] trustAllCerts = new TrustManager[]{
                new X509TrustManager() {
                    public java.security.cert.X509Certificate[] getAcceptedIssuers() {
                        return null;
                    }
                    public void checkClientTrusted(X509Certificate[] certs, String authType) {
                    }
                    public void checkServerTrusted(X509Certificate[] certs, String authType) {
                    }
                }
        };
        SSLContext sc;
        try {
            sc = SSLContext.getInstance("SSL");
            sc.init(null, trustAllCerts, new java.security.SecureRandom());
            HttpsURLConnection.setDefaultSSLSocketFactory(sc.getSocketFactory());
        } catch (NoSuchAlgorithmException | KeyManagementException e) {
            Log.e(this.getLocalClassName(), e.getMessage());
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        //Try reconnect
        connectService();
    }

    @Override
    protected void onStop() {
        super.onStop();
        db.close();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        //Stop server
        if (streamServer != null)
            streamServer.stop();

        //Unbind service on exit
        if (serviceBound) {
            unbindService(connection);
            serviceBound = false;
        }
    }

    //Connection to download service
    private final ServiceConnection connection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName componentName, IBinder iBinder) {
            serviceMessenger = new Messenger(iBinder);
            serviceBound = true;
            Log.d("DD", "Service Bound!");
        }

        @Override
        public void onServiceDisconnected(ComponentName componentName) {
            serviceMessenger = null;
            serviceBound = false;
            Log.d("DD", "Service UnBound!");
        }
    };

    //Handler for incoming messages from service
    private static class IncomingHandler extends Handler {
        private final WeakReference<MainActivity> weakReference;
        IncomingHandler(MainActivity activity) {
            super(Looper.getMainLooper());
            this.weakReference = new WeakReference<>(activity);
        }

        @Override
        public void handleMessage(@NonNull Message msg) {
            MainActivity activity = weakReference.get();

            if (activity != null) {
                EventChannel.EventSink eventSink = activity.eventSink;
                switch (msg.what) {
                    //Forward to flutter.
                    case DownloadService.SERVICE_ON_PROGRESS:
                        if (eventSink == null) break;
                        ArrayList<Bundle> downloads = getParcelableArrayList(msg.getData(), "downloads", Bundle.class);
                        if (downloads != null && downloads.size() > 0) {
                            //Generate HashMap ArrayList for sending to flutter
                            ArrayList<HashMap<String, Number>> data = new ArrayList<>();
                            for (Bundle bundle : downloads) {
                                HashMap<String, Number> out = new HashMap<>();
                                out.put("id", bundle.getInt("id"));
                                out.put("state", bundle.getInt("state"));
                                out.put("received", bundle.getLong("received"));
                                out.put("filesize", bundle.getLong("filesize"));
                                out.put("quality", bundle.getInt("quality"));
                                data.add(out);
                            }
                            //Wrapper
                            HashMap<String, Object> out = new HashMap<>();
                            out.put("action", "onProgress");
                            out.put("data", data);
                            eventSink.success(out);
                        }

                        break;
                    //State change, forward to flutter
                    case DownloadService.SERVICE_ON_STATE_CHANGE:
                        if (eventSink == null) break;
                        Bundle b = msg.getData();
                        HashMap<String, Object> out = new HashMap<>();
                        out.put("running", b.getBoolean("running"));
                        out.put("queueSize", b.getInt("queueSize"));

                        //Wrapper info
                        out.put("action", "onStateChange");

                        eventSink.success(out);
                        break;

                    default:
                        super.handleMessage(msg);
                }
            }
        }
    }

    //Send message to service
    void sendMessage(int type, Bundle data) {
        if (serviceBound && serviceMessenger != null) {
            Message msg = Message.obtain(null, type);
            msg.setData(data);
            try {
                serviceMessenger.send(msg);
            } catch (RemoteException e) {
                e.printStackTrace();
            }
        }
    }

    @Nullable
    public static <T extends Parcelable>  ArrayList<T> getParcelableArrayList(@Nullable Bundle bundle, @Nullable String key, @NonNull Class<T> clazz) {
        if (bundle != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                return bundle.getParcelableArrayList(key, clazz);
            } else {
                return bundle.getParcelableArrayList(key);
            }
        }
        return null;
    }
}
