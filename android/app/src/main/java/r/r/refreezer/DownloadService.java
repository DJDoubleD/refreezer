package r.r.refreezer;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.os.Messenger;
import android.os.RemoteException;
import android.util.Log;

import androidx.core.app.ActivityCompat;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.channels.FileChannel;
import java.text.DecimalFormat;
import java.util.ArrayList;

import javax.net.ssl.HttpsURLConnection;

public class DownloadService extends Service {

    //Message commands
    static final int SERVICE_LOAD_DOWNLOADS = 1;
    static final int SERVICE_START_DOWNLOAD = 2;
    static final int SERVICE_ON_PROGRESS = 3;
    static final int SERVICE_SETTINGS_UPDATE = 4;
    static final int SERVICE_STOP_DOWNLOADS = 5;
    static final int SERVICE_ON_STATE_CHANGE = 6;
    static final int SERVICE_REMOVE_DOWNLOAD = 7;
    static final int SERVICE_RETRY_DOWNLOADS = 8;
    static final int SERVICE_REMOVE_DOWNLOADS = 9;

    static final String NOTIFICATION_CHANNEL_ID = "refreezerdownloads";
    static final int NOTIFICATION_ID_START = 6969;

    boolean running = false;
    DownloadSettings settings;
    Context context;
    SQLiteDatabase db;
    Deezer deezer = new Deezer();

    Messenger serviceMessenger;
    Messenger activityMessenger;
    NotificationManagerCompat notificationManager;

    ArrayList<Download> downloads = new ArrayList<>();
    ArrayList<DownloadThread> threads = new ArrayList<>();
    ArrayList<Boolean> updateRequests = new ArrayList<>();
    boolean updating = false;
    Handler progressUpdateHandler = new Handler();
    DownloadLog logger = new DownloadLog();

    public DownloadService() {
    }

    @Override
    public void onCreate() {
        super.onCreate();

        //Setup notifications
        context = this;
        notificationManager = NotificationManagerCompat.from(context);
        createNotificationChannel();
        createProgressUpdateHandler();

        //Setup logger, deezer api
        logger.open(context);
        deezer.init(logger, "");

        //Get DB
        DownloadsDatabase dbHelper = new DownloadsDatabase(getApplicationContext());
        db = dbHelper.getWritableDatabase();
    }

    @Override
    public void onDestroy() {
        //Cancel notifications
        notificationManager.cancelAll();
        //Logger
        logger.close();
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        //Set messengers
        serviceMessenger = new Messenger(new IncomingHandler(this));
        if (intent != null)
            activityMessenger = intent.getParcelableExtra("activityMessenger");

        return serviceMessenger.getBinder();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        //Get messenger
        if (intent != null) {
            activityMessenger = intent.getParcelableExtra("activityMessenger");
        }


        //return super.onStartCommand(intent, flags, startId);
        //Prevent battery savers I guess
        return START_STICKY;
    }

    //Android O+ Notifications
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(NOTIFICATION_CHANNEL_ID, "Downloads", NotificationManager.IMPORTANCE_MIN);
            NotificationManager nManager = getSystemService(NotificationManager.class);
            nManager.createNotificationChannel(channel);
        }
    }

    //Update download tasks
    private void updateQueue() {
        db.beginTransaction();

        //Clear downloaded tracks
        for (int i = threads.size() - 1; i >= 0; i--) {
            Download.DownloadState state = threads.get(i).download.state;
            if (state == Download.DownloadState.NONE || state == Download.DownloadState.DONE || state == Download.DownloadState.ERROR || state == Download.DownloadState.DEEZER_ERROR) {
                Download d = threads.get(i).download;
                //Update in queue
                for (int j = 0; j < downloads.size(); j++) {
                    if (downloads.get(j).id == d.id) {
                        downloads.set(j, d);
                    }
                }
                updateProgress();
                //Save to DB
                ContentValues row = new ContentValues();
                row.put("state", state.getValue());
                row.put("quality", d.quality);
                db.update("Downloads", row, "id == ?", new String[]{Integer.toString(d.id)});

                //Update library
                if (state == Download.DownloadState.DONE && !d.priv) {
                    Uri uri = Uri.fromFile(new File(threads.get(i).outFile.getPath()));
                    sendBroadcast(new Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, uri));
                }

                //Remove thread
                threads.remove(i);
            }
        }

        db.setTransactionSuccessful();
        db.endTransaction();

        //Create new download tasks
        if (running) {
            int nThreads = settings.downloadThreads - threads.size();
            for (int i = 0; i < nThreads; i++) {
                for (int j = 0; j < downloads.size(); j++) {
                    if (downloads.get(j).state == Download.DownloadState.NONE) {
                        //Update download
                        Download d = downloads.get(j);
                        d.state = Download.DownloadState.DOWNLOADING;
                        downloads.set(j, d);

                        //Create thread
                        DownloadThread thread = new DownloadThread(d);
                        thread.start();
                        threads.add(thread);
                        break;
                    }
                }
            }
            //Check if last download
            if (threads.isEmpty()) {
                running = false;
            }
        }
        //Send updates to UI
        updateProgress();
        updateState();
    }

    //Send state change to UI
    private void updateState() {
        Bundle b = new Bundle();
        b.putBoolean("running", running);
        //Get count of not downloaded tracks
        int queueSize = 0;
        for (int i = 0; i < downloads.size(); i++) {
            if (downloads.get(i).state == Download.DownloadState.NONE)
                queueSize++;
        }
        b.putInt("queueSize", queueSize);
        sendMessage(SERVICE_ON_STATE_CHANGE, b);
    }

    //Wrapper to prevent threads racing
    private void updateQueueWrapper() {
        updateRequests.add(true);
        if (!updating) {
            updating = true;
            while (!updateRequests.isEmpty()) {
                updateQueue();
                //Because threading
                if (!updateRequests.isEmpty())
                    updateRequests.remove(0);
            }
        }
        updating = false;
    }

    //Loads downloads from database
    private void loadDownloads() {
        Cursor cursor = db.query("Downloads", null, null, null, null, null, null);

        //Parse downloads
        while (cursor.moveToNext()) {

            //Duplicate check
            int downloadId = cursor.getInt(0);
            Download.DownloadState state = Download.DownloadState.values()[cursor.getInt(1)];
            boolean skip = false;
            for (int i = 0; i < downloads.size(); i++) {
                if (downloads.get(i).id == downloadId) {
                    if (downloads.get(i).state != state) {
                        //Different state, update state, only for finished/error
                        if (downloads.get(i).state.getValue() >= 3) {
                            downloads.set(i, Download.fromSQL(cursor));
                        }
                    }
                    skip = true;
                    break;
                }
            }
            //Add to queue
            if (!skip)
                downloads.add(Download.fromSQL(cursor));
        }
        cursor.close();

        updateState();
    }

    //Stop downloads
    private void stop() {
        running = false;
        for (int i = 0; i < threads.size(); i++) {
            threads.get(i).stopDownload();
        }
        updateState();
    }


    public class DownloadThread extends Thread {

        Download download;
        File parentDir;
        File outFile;
        JSONObject trackJson;
        JSONObject albumJson;
        JSONObject privateJson;
        JSONObject lyricsData = null;
        boolean stopDownload = false;

        DownloadThread(Download download) {
            this.download = download;
        }

        @Override
        public void run() {
            //Set state
            download.state = Download.DownloadState.DOWNLOADING;

            //Authorize deezer api
            if (!deezer.authorized && !deezer.authorizing)
                deezer.authorize();

            while (deezer.authorizing)
                try {
                    Thread.sleep(50);
                } catch (Exception ignored) {
                }

            //Don't fetch meta if user uploaded mp3
            if (!download.isUserUploaded()) {
                try {
                    JSONObject privateRaw = deezer.callGWAPI("deezer.pageTrack", "{\"sng_id\": \"" + download.trackId + "\"}");
                    privateJson = privateRaw.getJSONObject("results").getJSONObject("DATA");
                    if (privateRaw.getJSONObject("results").has("LYRICS")) {
                        lyricsData = privateRaw.getJSONObject("results").getJSONObject("LYRICS");
                    }
                    trackJson = deezer.callPublicAPI("track", download.trackId);
                    albumJson = deezer.callPublicAPI("album", Integer.toString(trackJson.getJSONObject("album").getInt("id")));

                } catch (Exception e) {
                    logger.error("Unable to fetch track and album metadata! " + e.toString(), download);
                    e.printStackTrace();
                    download.state = Download.DownloadState.ERROR;
                    exit();
                    return;
                }
            }

            //Fallback
            Deezer.QualityInfo qualityInfo = new Deezer.QualityInfo(this.download.quality, this.download.streamTrackId, this.download.trackToken, this.download.md5origin, this.download.mediaVersion, logger);
            String sURL = null;
            if (!download.isUserUploaded()) {
                try {
                    sURL = qualityInfo.fallback(deezer);
                    if (sURL == null)
                        throw new Exception("No more to fallback!");

                    download.quality = qualityInfo.quality;
                } catch (Exception e) {
                    logger.error("Fallback failed " + e.toString());
                    download.state = Download.DownloadState.DEEZER_ERROR;
                    exit();
                    return;
                }
            } else {
                //User uploaded MP3
                qualityInfo.quality = 3;
            }

            if (!download.priv) {
                //Check file
                try {
                    if (download.isUserUploaded()) {
                        outFile = new File(Deezer.generateUserUploadedMP3Filename(download.path, download.title));
                    } else {
                        outFile = new File(Deezer.generateFilename(download.path, trackJson, albumJson, qualityInfo.quality));
                    }
                    parentDir = new File(outFile.getParent());
                } catch (Exception e) {
                    logger.error("Error generating track filename (" + download.path + "): " + e.toString(), download);
                    e.printStackTrace();
                    download.state = Download.DownloadState.ERROR;
                    exit();
                    return;
                }
            } else {
                //Private track
                outFile = new File(download.path);
                parentDir = new File(outFile.getParent());
            }
            //File already exists
            if (outFile.exists()) {
                //Delete if overwriting enabled
                if (settings.overwriteDownload) {
                    outFile.delete();
                } else {
                    download.state = Download.DownloadState.DONE;
                    exit();
                    return;
                }
            }

            //Temporary encrypted file
            File tmpFile = new File(getCacheDir(), download.id + ".ENC");

            //Get start bytes offset
            long start = 0;
            if (tmpFile.exists()) {
                start = tmpFile.length();
            }

            //Download
            try {
                URL url = new URL(sURL);
                HttpsURLConnection connection = (HttpsURLConnection) url.openConnection();
                //Set headers
                connection.setConnectTimeout(30000);
                connection.setRequestMethod("GET");
                connection.setRequestProperty("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.130 Safari/537.36");
                connection.setRequestProperty("Accept-Language", "*");
                connection.setRequestProperty("Accept", "*/*");
                connection.setRequestProperty("Range", "bytes=" + start + "-");
                connection.connect();

                //Open streams
                BufferedInputStream inputStream = new BufferedInputStream(connection.getInputStream());
                OutputStream outputStream = new FileOutputStream(tmpFile.getPath(), true);
                //Save total
                download.filesize = start + connection.getContentLength();
                //Download
                byte[] buffer = new byte[4096];
                long received = 0;
                int read;
                while ((read = inputStream.read(buffer, 0, 4096)) != -1) {
                    outputStream.write(buffer, 0, read);
                    received += read;
                    download.received = start + received;

                    //Stop/Cancel download
                    if (stopDownload) {
                        download.state = Download.DownloadState.NONE;
                        try {
                            inputStream.close();
                            outputStream.close();
                            connection.disconnect();
                        } catch (Exception ignored) {
                        }
                        exit();
                        return;
                    }
                }
                //On done
                inputStream.close();
                outputStream.close();
                connection.disconnect();
                //Update
                download.state = Download.DownloadState.POST;
                updateProgress();
            } catch (Exception e) {
                //Download error
                logger.error("Download error: " + e.toString(), download);
                e.printStackTrace();
                download.state = Download.DownloadState.ERROR;
                exit();
                return;
            }

            //Post processing

            //Decrypt
            if (qualityInfo.encrypted) {
                try {
                    File decFile = new File(tmpFile.getPath() + ".DEC");
                    DeezerDecryptor.decryptFile(download.streamTrackId, tmpFile.getPath(), decFile.getPath());
                    tmpFile.delete();
                    tmpFile = decFile;
                } catch (Exception e) {
                    logger.error("Decryption error: " + e.toString(), download);
                    e.printStackTrace();
                    //Shouldn't ever fail
                }
            }


            //If exists (duplicate download in DB), don't overwrite.
            if (outFile.exists()) {
                download.state = Download.DownloadState.DONE;
                exit();
                return;
            }

            //Create dirs and copy
            if (!parentDir.exists() && !parentDir.mkdirs()) {
                //Log & Exit
                logger.error("Couldn't create output folder: " + parentDir.getPath() + "! ", download);
                download.state = Download.DownloadState.ERROR;
                exit();
                return;
            }

            if (!tmpFile.renameTo(outFile)) {
                try {
                    //Copy file
                    FileInputStream inputStream = new FileInputStream(tmpFile);
                    FileOutputStream outputStream = new FileOutputStream(outFile);
                    FileChannel inputChannel = inputStream.getChannel();
                    FileChannel outputChannel = outputStream.getChannel();
                    inputChannel.transferTo(0, inputChannel.size(), outputChannel);
                    inputStream.close();
                    outputStream.close();
                    //Delete temp
                    tmpFile.delete();
                } catch (Exception e) {
                    //Clean
                    try {
                        outFile.delete();
                        tmpFile.delete();
                    } catch (Exception ignored) {
                    }
                    //Log & Exit
                    logger.error("Error moving file! " + outFile.getPath() + ", " + e.toString(), download);
                    e.printStackTrace();
                    download.state = Download.DownloadState.ERROR;
                    exit();
                    return;
                }
            }

            //Cover & Tags, ignore on user uploaded
            if (!download.priv && !download.isUserUploaded()) {

                //Download cover for each track
                File coverFile = new File(outFile.getPath().substring(0, outFile.getPath().lastIndexOf('.')) + ".jpg");

                try {
                    URL url = new URL("http://e-cdn-images.deezer.com/images/cover/" + trackJson.getString("md5_image") + "/" + Integer.toString(settings.albumArtResolution) + "x" + Integer.toString(settings.albumArtResolution) + "-000000-80-0-0.jpg");
                    HttpURLConnection connection = (HttpURLConnection) url.openConnection();
                    //Set headers
                    connection.setRequestMethod("GET");
                    connection.connect();
                    //Open streams
                    InputStream inputStream = connection.getInputStream();
                    OutputStream outputStream = new FileOutputStream(coverFile.getPath());
                    //Download
                    byte[] buffer = new byte[4096];
                    int read = 0;
                    while ((read = inputStream.read(buffer)) != -1) {
                        outputStream.write(buffer, 0, read);
                    }
                    //On done
                    try {
                        inputStream.close();
                        outputStream.close();
                        connection.disconnect();
                    } catch (Exception ignored) {
                    }

                } catch (Exception e) {
                    logger.error("Error downloading cover! " + e.toString(), download);
                    e.printStackTrace();
                }

                //Lyrics
                if (lyricsData != null) {
                    if (settings.downloadLyrics) {
                        try {
                            String lrcData = Deezer.generateLRC(lyricsData, trackJson);
                            //Create file
                            String lrcFilename = outFile.getPath().substring(0, outFile.getPath().lastIndexOf(".") + 1) + "lrc";
                            FileOutputStream fileOutputStream = new FileOutputStream(lrcFilename);
                            fileOutputStream.write(lrcData.getBytes());
                            fileOutputStream.close();

                        } catch (Exception e) {
                            logger.warn("Error downloading lyrics! " + e.toString(), download);
                        }
                    }
                }

                //Tag
                try {
                    deezer.tagTrack(outFile.getPath(), trackJson, albumJson, coverFile.getPath(), lyricsData, privateJson, settings);
                } catch (Exception e) {
                    Log.e("ERR", "Tagging error!");
                    e.printStackTrace();
                }

                //Delete cover if disabled
                if (!settings.trackCover)
                    coverFile.delete();

                //Album cover
                if (settings.albumCover)
                    downloadAlbumCover(albumJson);
            }

            download.state = Download.DownloadState.DONE;
            //Queue update
            updateQueueWrapper();
            stopSelf();
        }

        //Each track has own album art, this is to download cover.jpg
        void downloadAlbumCover(JSONObject albumJson) {
            //Checks
            if (albumJson == null || !albumJson.has("md5_image")) return;
            File coverFile = new File(parentDir, "cover.jpg");
            if (coverFile.exists()) return;
            //Don't download if doesn't have album
            if (!download.path.matches(".*/.*%album%.*/.*")) return;

            try {
                //Create to lock
                coverFile.createNewFile();

                URL url = new URL("http://e-cdn-images.deezer.com/images/cover/" + albumJson.getString("md5_image") + "/" + Integer.toString(settings.albumArtResolution) + "x" + Integer.toString(settings.albumArtResolution) + "-000000-80-0-0.jpg");
                HttpURLConnection connection = (HttpURLConnection) url.openConnection();
                //Set headers
                connection.setRequestMethod("GET");
                connection.connect();
                //Open streams
                InputStream inputStream = connection.getInputStream();
                OutputStream outputStream = new FileOutputStream(coverFile.getPath());
                //Download
                byte[] buffer = new byte[4096];
                int read = 0;
                while ((read = inputStream.read(buffer)) != -1) {
                    outputStream.write(buffer, 0, read);
                }
                //On done
                try {
                    inputStream.close();
                    outputStream.close();
                    connection.disconnect();
                } catch (Exception ignored) {
                }
                //Create .nomedia to not spam gallery
                if (settings.nomediaFiles)
                    new File(parentDir, ".nomedia").createNewFile();
            } catch (Exception e) {
                logger.warn("Error downloading album cover! " + e.toString(), download);
                coverFile.delete();
            }
        }

        void stopDownload() {
            stopDownload = true;
        }

        //Clean stop/exit
        private void exit() {
            updateQueueWrapper();
            stopSelf();
        }

    }

    //500ms loop to update notifications and UI
    private void createProgressUpdateHandler() {
        progressUpdateHandler.postDelayed(() -> {
            updateProgress();
            createProgressUpdateHandler();
        }, 500);
    }

    //Updates notification and UI
    private void updateProgress() {
        if (threads.size() > 0) {
            //Convert threads to bundles, send to activity;
            Bundle b = new Bundle();
            ArrayList<Bundle> down = new ArrayList<>();
            for (int i = 0; i < threads.size(); i++) {
                //Create bundle
                Download download = threads.get(i).download;
                down.add(createProgressBundle(download));
                //Notification
                updateNotification(download);
            }
            b.putParcelableArrayList("downloads", down);
            sendMessage(SERVICE_ON_PROGRESS, b);
        }
    }

    //Create bundle with download progress & state
    private Bundle createProgressBundle(Download download) {
        Bundle bundle = new Bundle();
        bundle.putInt("id", download.id);
        bundle.putLong("received", download.received);
        bundle.putLong("filesize", download.filesize);
        bundle.putInt("quality", download.quality);
        bundle.putInt("state", download.state.getValue());
        return bundle;
    }

    private void updateNotification(Download download) {
        //Cancel notification for done/none/error downloads
        if (download.state == Download.DownloadState.NONE || download.state.getValue() >= 3) {
            notificationManager.cancel(NOTIFICATION_ID_START + download.id);
            return;
        }

        NotificationCompat.Builder notificationBuilder = new NotificationCompat.Builder(context, DownloadService.NOTIFICATION_CHANNEL_ID)
                .setContentTitle(download.title)
                .setSmallIcon(R.drawable.ic_logo)
                .setPriority(NotificationCompat.PRIORITY_MIN);

        //Show progress when downloading
        if (download.state == Download.DownloadState.DOWNLOADING) {
            if (download.filesize <= 0) download.filesize = 1;
            notificationBuilder.setContentText(String.format("%s / %s", formatFilesize(download.received), formatFilesize(download.filesize)));
            notificationBuilder.setProgress(100, (int) ((download.received / (float) download.filesize) * 100), false);
        }

        //Indeterminate on PostProcess
        if (download.state == Download.DownloadState.POST) {
            //TODO: Use strings
            notificationBuilder.setContentText("Post processing...");
            notificationBuilder.setProgress(1, 1, true);
        }

        if (ActivityCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            notificationManager.notify(NOTIFICATION_ID_START + download.id, notificationBuilder.build());
        }

    }

    //https://stackoverflow.com/questions/3263892/format-file-size-as-mb-gb-etc
    public static String formatFilesize(long size) {
        if(size <= 0) return "0B";
        final String[] units = new String[] { "B", "KB", "MB", "GB", "TB" };
        int digitGroups = (int) (Math.log10(size)/Math.log10(1024));
        return new DecimalFormat("#,##0.##").format(size/Math.pow(1024, digitGroups)) + " " + units[digitGroups];
    }

    //Handler for incoming messages
    class IncomingHandler extends Handler {
        IncomingHandler(Context context) {
            context.getApplicationContext();
        }

        @Override
        public void handleMessage(Message msg) {
            switch (msg.what) {
                //Load downloads from DB
                case SERVICE_LOAD_DOWNLOADS:
                    loadDownloads();
                    break;

                //Start/Resume
                case SERVICE_START_DOWNLOAD:
                    running = true;
                    if (downloads.isEmpty())
                        loadDownloads();
                    updateQueue();
                    updateState();
                    break;

                //Load settings
                case SERVICE_SETTINGS_UPDATE:
                    settings = DownloadSettings.fromBundle(msg.getData());
                    deezer.arl = settings.arl;
                    deezer.contentLanguage = settings.deezerLanguage;
                    break;

                //Stop downloads
                case SERVICE_STOP_DOWNLOADS:
                    stop();
                    break;

                //Remove download
                case SERVICE_REMOVE_DOWNLOAD:
                    int downloadId = msg.getData().getInt("id");
                    for (int i=0; i<downloads.size(); i++) {
                        Download d = downloads.get(i);
                        //Only remove if not downloading
                        if (d.id == downloadId) {
                            if (d.state == Download.DownloadState.DOWNLOADING || d.state == Download.DownloadState.POST) {
                                return;
                            }
                            downloads.remove(i);
                            break;
                        }
                    }
                    //Remove from DB
                    db.delete("Downloads", "id == ?", new String[]{Integer.toString(downloadId)});
                    updateState();
                    break;

                //Retry failed downloads
                case SERVICE_RETRY_DOWNLOADS:
                    db.beginTransaction();
                    for (int i=0; i<downloads.size(); i++) {
                        Download d = downloads.get(i);
                        if (d.state == Download.DownloadState.DEEZER_ERROR || d.state == Download.DownloadState.ERROR) {
                            //Retry only failed
                            d.state = Download.DownloadState.NONE;
                            downloads.set(i, d);
                            //Update DB
                            ContentValues values = new ContentValues();
                            values.put("state", 0);
                            db.update("Downloads", values, "id == ?", new String[]{Integer.toString(d.id)});
                        }
                    }
                    db.setTransactionSuccessful();
                    db.endTransaction();
                    updateState();
                    break;

                //Remove downloads by state
                case SERVICE_REMOVE_DOWNLOADS:
                    //Don't remove currently downloading, user has to stop first
                    Download.DownloadState state = Download.DownloadState.values()[msg.getData().getInt("state")];
                    if (state == Download.DownloadState.DOWNLOADING || state == Download.DownloadState.POST) return;

                    db.beginTransaction();
                    int i = (downloads.size() - 1);
                    while (i >= 0) {
                        Download d = downloads.get(i);
                        if (d.state == state) {
                            //Remove
                            db.delete("Downloads", "id == ?", new String[]{Integer.toString(d.id)});
                            downloads.remove(i);
                        }
                        i--;
                    }
                    //Delete from DB, done downloads after app restart aren't in downloads array
                    db.delete("Downloads", "state == ?", new String[]{Integer.toString(msg.getData().getInt("state"))});
                    //Save
                    db.setTransactionSuccessful();
                    db.endTransaction();
                    updateState();
                    break;

                default:
                    super.handleMessage(msg);
            }
        }
    }

    //Send message to MainActivity
    void sendMessage(int type, Bundle data) {
        if (serviceMessenger != null) {
            Message msg = Message.obtain(null, type);
            msg.setData(data);
            try {
                activityMessenger.send(msg);
            } catch (RemoteException e) {
                e.printStackTrace();
            }
        }
    }

    static class DownloadSettings {

        int downloadThreads;
        boolean overwriteDownload;
        boolean downloadLyrics;
        boolean trackCover;
        String arl;
        boolean albumCover;
        boolean nomediaFiles;
        String artistSeparator;
        int albumArtResolution;
        String deezerLanguage = "en";
        String deezerCountry = "US";
        SelectedTags tags;

        private DownloadSettings(int downloadThreads, boolean overwriteDownload, boolean downloadLyrics, boolean trackCover, String arl, boolean albumCover, boolean nomediaFiles, String artistSeparator, int albumArtResolution, String deezerLanguage, String deezerCountry, SelectedTags tags) {
            this.downloadThreads = downloadThreads;
            this.overwriteDownload = overwriteDownload;
            this.downloadLyrics = downloadLyrics;
            this.trackCover = trackCover;
            this.arl = arl;
            this.albumCover = albumCover;
            this.nomediaFiles = nomediaFiles;
            this.artistSeparator = artistSeparator;
            this.albumArtResolution = albumArtResolution;
            this.deezerLanguage = deezerLanguage;
            this.deezerCountry = deezerCountry;
            this.tags = tags;
        }

        //Parse settings from bundle sent from UI
        static DownloadSettings fromBundle(Bundle b) {
            JSONObject json;
            try {
                json = new JSONObject(b.getString("json"));
                return new DownloadSettings(
                    json.getInt("downloadThreads"),
                    json.getBoolean("overwriteDownload"),
                    json.getBoolean("downloadLyrics"),
                    json.getBoolean("trackCover"),
                    json.getString("arl"),
                    json.getBoolean("albumCover"),
                    json.getBoolean("nomediaFiles"),
                    json.getString("artistSeparator"),
                    json.getInt("albumArtResolution"),
                    json.getString("deezerLanguage"),
                    json.getString("deezerCountry"),
                    new SelectedTags(json.getJSONArray("tags"))
                );
            } catch (Exception e) {
                //Shouldn't happen
                Log.e("ERR", "Error loading settings!");
                return null;
            }
        }
    }

    static class SelectedTags {
        boolean title = false;
        boolean album = false;
        boolean artist = false;
        boolean track = false;
        boolean disc = false;
        boolean albumArtist = false;
        boolean date = false;
        boolean label = false;
        boolean isrc = false;
        boolean upc = false;
        boolean trackTotal = false;
        boolean bpm = false;
        boolean lyrics = false;
        boolean genre = false;
        boolean contributors = false;
        boolean albumArt = false;

        SelectedTags(JSONArray json) {
            //Array of tags, check if exist
            try {
                for (int i=0; i<json.length(); i++) {
                    switch (json.getString(i)) {
                        case "title":
                            title = true; break;
                        case "album":
                            album = true; break;
                        case "artist":
                            artist = true; break;
                        case "track":
                            track = true; break;
                        case "disc":
                            disc = true; break;
                        case "albumArtist":
                            albumArtist = true; break;
                        case "date":
                            date = true; break;
                        case "label":
                            label = true; break;
                        case "isrc":
                            isrc = true; break;
                        case "upc":
                            upc = true; break;
                        case "trackTotal":
                            trackTotal = true; break;
                        case "bpm":
                            bpm = true; break;
                        case "lyrics":
                            lyrics = true; break;
                        case "genre":
                            genre = true; break;
                        case "contributors":
                            contributors = true; break;
                        case "art":
                            albumArt = true; break;
                    }
                }
            } catch (Exception e) {
                //Shouldn't happen
                Log.e("ERR", "Error toggling tag: " +  e.toString());
            }
        }
    }
}

