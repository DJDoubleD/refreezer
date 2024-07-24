package r.r.refreezer;

import android.util.Log;
import android.util.Pair;

import org.jaudiotagger.audio.AudioFile;
import org.jaudiotagger.audio.AudioFileIO;
import org.jaudiotagger.tag.FieldKey;
import org.jaudiotagger.tag.Tag;
import org.jaudiotagger.tag.TagOptionSingleton;
import org.jaudiotagger.tag.flac.FlacTag;
import org.jaudiotagger.tag.id3.ID3v23Tag;
import org.jaudiotagger.tag.id3.valuepair.ImageFormats;
import org.jaudiotagger.tag.images.Artwork;
import org.jaudiotagger.tag.images.ArtworkFactory;
import org.jaudiotagger.tag.reference.PictureTypes;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.RandomAccessFile;
import java.net.URL;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.Scanner;

import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;
import javax.net.ssl.HttpsURLConnection;

import r.r.refreezer.models.Lyrics;
import r.r.refreezer.models.LyricsNew;
import r.r.refreezer.models.SynchronizedLyric;

public class Deezer {

    static String USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.130 Safari/537.36";
    DownloadLog logger;
    String token;
    String arl;
    String sid;
    String licenseToken;
    String contentLanguage = "en";
    boolean authorized = false;
    boolean authorizing = false;

    Deezer() {}

    //Initialize for logging
    void init(DownloadLog logger, String arl) {
        //Load native
        //System.loadLibrary("decryptor-jni");

        this.logger = logger;
        this.arl = arl;
    }

    // Method for when using c libraries for decryption
    //public native void decryptFile(String trackId, String inputFilename, String outputFilename);

    //Authorize GWLight API
    public void authorize() {
        if (!authorized || sid == null || token == null) {
            authorizing = true;
            try {
                callGWAPI("deezer.getUserData", "{}");
                authorized = true;
            } catch (Exception e) {
                logger.warn("Error authorizing to Deezer API! " + e);
            }
        }
        authorizing = false;
    }

    //Make POST request
    private String POST(String _url, String data,  Map<String, String> additionalHeaders) {
        String result = null;

        try {
            URL url = new URL(_url);
            HttpsURLConnection connection = (HttpsURLConnection) url.openConnection();
            connection.setConnectTimeout(20000);
            connection.setDoOutput(true);
            connection.setRequestMethod("POST");
            connection.setRequestProperty("User-Agent", USER_AGENT);
            connection.setRequestProperty("Accept-Language", contentLanguage + ",*");
            connection.setRequestProperty("Content-Type", "application/json");
            connection.setRequestProperty("Accept", "*/*");

            // Add additional headers if provided
            if (additionalHeaders != null && !additionalHeaders.isEmpty()) {
                for (Map.Entry<String, String> entry : additionalHeaders.entrySet()) {
                    connection.setRequestProperty(entry.getKey(), entry.getValue());
                }
            }

            //Write body
            if (data != null) {
                try (DataOutputStream wr = new DataOutputStream(connection.getOutputStream())) {
                    wr.writeBytes(data);
                }
            }

            //Get response
            try (Scanner scanner = new Scanner(connection.getInputStream())) {
                StringBuilder output = new StringBuilder();
                while (scanner.hasNext()) {
                    output.append(scanner.nextLine());
                }
                result = output.toString();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

        return result;
    }

    public JSONObject callGWAPI(String method, String body) throws Exception {
        //Get token
        if (token == null) {
            token = "null";
            callGWAPI("deezer.getUserData", "{}");
        }

        // Construct cookie header
        Map<String, String> cookies = new HashMap<>();
        cookies.put("Cookie", "arl=" + arl + (sid == null ? "" : "; sid=" + sid));

        String data = POST(
                "https://www.deezer.com/ajax/gw-light.php?method=" + method + "&input=3&api_version=1.0&api_token=" + token,
                body,
                cookies
        );

        //Parse JSON
        JSONObject out = new JSONObject(data);

        //Save token
        if ((token == null || token.equals("null")) && method.equals("deezer.getUserData")) {
            token = out.getJSONObject("results").getString("checkForm");
            sid = out.getJSONObject("results").getString("SESSION_ID");

            // Get User license code
            try {
                JSONObject userData = out.getJSONObject("results").getJSONObject("USER");
                licenseToken = userData.getJSONObject("OPTIONS").getString("license_token");
            } catch (JSONException e) {
                e.printStackTrace();
                logger.warn("Error getting user License Token - FLAC not available! " + e);
            }
        }

        return out;
    }

    //api.deezer.com/$method/$param
    public JSONObject callPublicAPI(String method, String param) throws Exception {
        URL url = new URL("https://api.deezer.com/" + method + "/" + param);
        HttpsURLConnection connection = (HttpsURLConnection)url.openConnection();
        connection.setRequestMethod("GET");
        connection.setRequestProperty("Accept-Language", contentLanguage + ",*");
        connection.setConnectTimeout(20000);
        connection.connect();

        //Get string data
        StringBuilder data = new StringBuilder();
        InputStream inputStream = connection.getInputStream();
        try (Scanner scanner = new Scanner(new InputStreamReader(inputStream))) {
            while (scanner.hasNext()) {
                data.append(scanner.nextLine());
            }
        } finally {
            connection.disconnect();
        }

        //Parse JSON & return
        return new JSONObject(data.toString());
    }

    // Method to call the Pipe API
    public JSONObject callPipeApi(Map<String, Object> params) throws Exception {
        String jwtToken = "";
        try {
            jwtToken = getJsonWebToken();
        } catch (Exception e) {
            logger.error("Error getting JsonWebToken: " + e);
            throw e;
        }

        // Headers
        Map<String, String> headers = new HashMap<>();
        headers.put("Cookie", "arl=" + arl + (sid == null ? "" : "; sid=" + sid));
        headers.put("Authorization", "Bearer " + jwtToken);

        // Convert params to JSON string
        String paramsJsonString = null;
        if (params != null && !params.isEmpty()) {
            JSONObject paramsJsonObject = new JSONObject(params);
            paramsJsonString = paramsJsonObject.toString();
        }

        String response = POST("https://pipe.deezer.com/api/", paramsJsonString, headers);
        // Return response as JSONObject
        return new JSONObject(response);
    }

    // Method to get JSON Web Token
    public String getJsonWebToken() throws Exception{
        String urlString = "https://auth.deezer.com/login/arl?jo=p&rto=c&i=c";
        Map<String, String> cookies = new HashMap<>();
        cookies.put("Cookie", "arl=" + arl + (sid == null ? "" : "; sid=" + sid));
        String response = POST(urlString, "", cookies);

        // Parse JSON and return JWT
        JSONObject body = null;
        body = new JSONObject(response);
        return body.has("jwt") ? body.getString("jwt") : "";
    }

    public Lyrics getlyricsNew(String trackId) {
        try {
            // Create the GraphQL query string
            String queryStringGraphQL =
                    "query SynchronizedTrackLyrics($trackId: String!) {" +
                            "  track(trackId: $trackId) {" +
                            "    id" +
                            "    isExplicit" +
                            "    lyrics {" +
                            "      id" +
                            "      copyright" +
                            "      text" +
                            "      writers" +
                            "      synchronizedLines {" +
                            "        lrcTimestamp" +
                            "        line" +
                            "        milliseconds" +
                            "        duration" +
                            "      }" +
                            "    }" +
                            "  }" +
                            "}";

            // Create the request parameters
            Map<String, Object> requestParams = new HashMap<>();
            requestParams.put("operationName", "SynchronizedTrackLyrics");
            Map<String, String> variables = new HashMap<>();
            variables.put("trackId", trackId);
            requestParams.put("variables", variables);
            requestParams.put("query", queryStringGraphQL);

            // Call the API
            JSONObject data = callPipeApi(requestParams);

            // Parse the response into a LyricsFull object
            return new LyricsNew(data);

        } catch (Exception e) {
            e.printStackTrace();
            Lyrics errorLyrics = new LyricsNew();
            errorLyrics.setErrorMessage("An error occurred: " + e.getMessage());
            return errorLyrics;
        }
    }

    //Generate track download URL
    public String generateTrackUrl(String trackId, String md5origin, String mediaVersion, int quality) {
        try {
            int magic = 164;

            ByteArrayOutputStream step1 = new ByteArrayOutputStream();
            step1.write(md5origin.getBytes());
            step1.write(magic);
            step1.write(Integer.toString(quality).getBytes());
            step1.write(magic);
            step1.write(trackId.getBytes());
            step1.write(magic);
            step1.write(mediaVersion.getBytes());
            //Get MD5
            MessageDigest md5 = MessageDigest.getInstance("MD5");
            md5.update(step1.toByteArray());
            byte[] digest = md5.digest();
            String md5hex = DeezerDecryptor.bytesToHex(digest).toLowerCase();

            //Step 2
            ByteArrayOutputStream step2 = new ByteArrayOutputStream();
            step2.write(md5hex.getBytes());
            step2.write(magic);
            step2.write(step1.toByteArray());
            step2.write(magic);

            //Pad step2 with dots, to get correct length
            while(step2.size()%16 > 0) step2.write(46);

            //Prepare AES encryption
            Cipher cipher = Cipher.getInstance("AES/ECB/NoPadding");
            SecretKeySpec key = new SecretKeySpec("jo6aey6haid2Teih".getBytes(), "AES");
            cipher.init(Cipher.ENCRYPT_MODE, key);
            //Encrypt
            StringBuilder step3 = new StringBuilder();
            for (int i=0; i<step2.size()/16; i++) {
                byte[] b = Arrays.copyOfRange(step2.toByteArray(), i*16, (i+1)*16);
                step3.append(DeezerDecryptor.bytesToHex(cipher.doFinal(b)).toLowerCase());
            }
            //Return joined to URL
            return "https://e-cdns-proxy-" + md5origin.charAt(0) + ".dzcdn.net/mobile/1/" + step3;

        } catch (Exception e) {
            e.printStackTrace();
            logger.error("Error generating track URL! ID: " + trackId + " " + e);
        }
        return null;
    }

    // Returns URL and whether encrypted
    public Pair<String, Boolean> getTrackUrl(String trackId, String trackToken, String md5origin, String mediaVersion,
            int quality, int refreshAttempt) {
        // Hi-Fi url gen
        if (this.licenseToken != null && (quality == 3 || quality == 9)) {
            String url = null;
            String format = "FLAC";

            if (quality == 3) format = "MP3_320";

            try {
                //arl cookie
                Map<String, String> cookies = new HashMap<>();
                cookies.put("Cookie", "arl=" + arl);
                // Create track_url payload
                String payload = "{\n" +
                        "\"license_token\": \"" + licenseToken + "\",\n" +
                        "\"media\": [{ \"type\": \"FULL\", \"formats\": [{ \"cipher\": \"BF_CBC_STRIPE\", \"format\": \"" + format + "\"}]}],\n" +
                        "\"track_tokens\": [\"" + trackToken + "\"]\n" +
                        "}";
                String output = POST("https://media.deezer.com/v1/get_url", payload, cookies);

                JSONObject result = new JSONObject(output);

                if (result.has("data")){
                    for (int i = 0; i < result.getJSONArray("data").length(); i++){
                        JSONObject data = result.getJSONArray("data").getJSONObject(i);
                        if (data.has("errors")){
                            JSONArray errors = data.getJSONArray("errors");
                            for (int j = 0; j < errors.length(); j++) {
                                JSONObject error = errors.getJSONObject(j);
                                if (error.getInt("code") == 2001 && refreshAttempt < 1) {
                                    // Track token is expired, attempt 1 track data refresh
                                    JSONObject privateJson = callGWAPI("song.getListData", "{\"sng_ids\": [" + trackId + "]}");
                                    JSONObject trackData = privateJson.getJSONObject("results").getJSONArray("data").getJSONObject(0);
                                    trackId = trackData.getString("SNG_ID");
                                    trackToken = trackData.getString("TRACK_TOKEN");
                                    md5origin = trackData.getString("MD5_ORIGIN");
                                    mediaVersion = trackData.getString("MEDIA_VERSION");

                                    // Retry getTrackUrl with refreshed track data and increment retry count
                                    return getTrackUrl(trackId, trackToken, md5origin, mediaVersion, quality, refreshAttempt + 1);
                                }
                            }
                            logger.warn("Failed in getting streaming URL: " + data.get("errors"));
                        }
                        if (data.has("media") && data.getJSONArray("media").length() > 0){
                            url = data.getJSONArray("media").getJSONObject(0).getJSONArray("sources").getJSONObject(0).getString("url");
                            break;
                        }
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
                logger.warn("Error getting streaming URL: " + e);
            }
            return new Pair<String, Boolean>(url,true);
        }
        // Legacy url generation, now only for MP3_128
        return new Pair<String, Boolean>(generateTrackUrl(trackId, md5origin, mediaVersion, quality), true);
    }

    public static String sanitize(String input) {
        return input.replaceAll("[\\\\/?*:%<>|\"]", "").replace("$", "\\$");
    }

    public static String generateFilename(String original, JSONObject publicTrack, JSONObject publicAlbum, int newQuality) throws Exception {
        original = original.replaceAll("%title%", sanitize(publicTrack.getString("title")));
        original = original.replaceAll("%album%", sanitize(publicTrack.getJSONObject("album").getString("title")));
        original = original.replaceAll("%artist%", sanitize(publicTrack.getJSONObject("artist").getString("name")));
        // Album might not be available
        try {
            original = original.replaceAll("%albumArtist%", sanitize(publicAlbum.getJSONObject("artist").getString("name")));
        } catch (Exception e) {
            original = original.replaceAll("%albumArtist%", sanitize(publicTrack.getJSONObject("artist").getString("name")));
        }

        //Artists
        String artists = "";
        String feats = "";
        for (int i=0; i<publicTrack.getJSONArray("contributors").length(); i++) {
            String artist = publicTrack.getJSONArray("contributors").getJSONObject(i).getString("name");
            if (!artists.contains(artist))
                artists += ", " + artist;
            if (i > 0 && !artists.contains(artist) && !feats.contains(artist))
                feats += ", " + artist;
        }
        original = original.replaceAll("%artists%", sanitize(artists).substring(2));
        if (feats.length() >= 2)
            original = original.replaceAll("%feats%", sanitize(feats).substring(2));
        //Track number
        int trackNumber = publicTrack.getInt("track_position");
        original = original.replaceAll("%trackNumber%", Integer.toString(trackNumber));
        original = original.replaceAll("%0trackNumber%", String.format("%02d", trackNumber));
        //Year
        original = original.replaceAll("%year%", publicTrack.getString("release_date").substring(0, 4));
        original = original.replaceAll("%date%", publicTrack.getString("release_date"));

        //Remove leading dots
        original = original.replaceAll("/\\.+", "/");

        if (newQuality == 9) return original + ".flac";
        return original + ".mp3";
    }

    //Deezer patched something so getting metadata of user uploaded MP3s is not working anymore
    public static String generateUserUploadedMP3Filename(String original, String title) {
        String[] ignored = {"%feats%", "%trackNumber%", "%0trackNumber%", "%year%", "%date%", "%album%", "%artist%", "%artists%", "%albumArtist%"};
        for (String i : ignored) {
            original = original.replaceAll(i, "");
        }

        original = original.replace("%title%", sanitize(title));
        return original;
    }

    //Tag track with data from API
    public void tagTrack(String path, JSONObject publicTrack, JSONObject publicAlbum, String cover, Lyrics lyricsData, JSONObject privateJson, DownloadService.DownloadSettings settings) throws Exception {
        TagOptionSingleton.getInstance().setAndroid(true);
        //Load file
        AudioFile f = AudioFileIO.read(new File(path));
        boolean isFlac = true;
        if (f.getAudioHeader().getFormat().contains("MPEG")) {
            f.setTag(new ID3v23Tag());
            isFlac = false;
        }
        Tag tag = f.getTag();

        if (settings.tags.title) tag.setField(FieldKey.TITLE, publicTrack.getString("title"));
        if (settings.tags.album) tag.setField(FieldKey.ALBUM, publicTrack.getJSONObject("album").getString("title"));
        //Artist
        String artists = "";
        for (int i=0; i<publicTrack.getJSONArray("contributors").length(); i++) {
            String artist = publicTrack.getJSONArray("contributors").getJSONObject(i).getString("name");
            if (!artists.contains(artist))
                artists += settings.artistSeparator + artist;
        }
        boolean albumAvailable = !publicAlbum.has("error");
        if (settings.tags.artist) tag.addField(FieldKey.ARTIST, artists.substring(settings.artistSeparator.length()));
        if (settings.tags.track) tag.setField(FieldKey.TRACK, String.format("%02d", publicTrack.getInt("track_position")));
        if (settings.tags.disc) tag.setField(FieldKey.DISC_NO, Integer.toString(publicTrack.getInt("disk_number")));
        if (settings.tags.albumArtist && albumAvailable) tag.setField(FieldKey.ALBUM_ARTIST, publicAlbum.getJSONObject("artist").getString("name"));
        if (settings.tags.date) tag.setField(FieldKey.YEAR, publicTrack.getString("release_date").substring(0, 4));
        if (settings.tags.label && albumAvailable) tag.setField(FieldKey.RECORD_LABEL, publicAlbum.getString("label"));
        if (settings.tags.isrc) tag.setField(FieldKey.ISRC, publicTrack.getString("isrc"));
        if (settings.tags.upc && albumAvailable) tag.setField(FieldKey.BARCODE, publicAlbum.getString("upc"));
        if (settings.tags.trackTotal && albumAvailable) tag.setField(FieldKey.TRACK_TOTAL, Integer.toString(publicAlbum.getInt("nb_tracks")));

        //BPM
        if (publicTrack.has("bpm") && (int)publicTrack.getDouble("bpm") > 0)
            if (settings.tags.bpm) tag.setField(FieldKey.BPM, Integer.toString((int)publicTrack.getDouble("bpm")));

        //Unsynced lyrics
        if (settings.tags.lyrics && lyricsData != null && lyricsData.getUnsyncedLyrics() != null && !lyricsData.getUnsyncedLyrics().isEmpty()) {
            try {
                tag.setField(FieldKey.LYRICS, lyricsData.getUnsyncedLyrics());
            } catch (Exception e) {
                Log.w("WARN", "Error adding unsynced lyrics!");
            }
        }

        //Genres
        String genres = "";
        if (albumAvailable) {
            for (int i=0; i<publicAlbum.getJSONObject("genres").getJSONArray("data").length(); i++) {
                String genre = publicAlbum.getJSONObject("genres").getJSONArray("data").getJSONObject(0).getString("name");
                if (!genres.contains(genre)) {
                    genres += ", " + genre;
                }
            }
            if (genres.length() > 2 && settings.tags.genre)
                tag.setField(FieldKey.GENRE, genres.substring(2));
        }

        //Additional tags from private api
        if (settings.tags.contributors) {
            try {
                if (privateJson != null && privateJson.has("SNG_CONTRIBUTORS")) {
                    JSONObject contrib = privateJson.getJSONObject("SNG_CONTRIBUTORS");
                    //Composer
                    if (contrib.has("composer")) {
                        JSONArray composers = contrib.getJSONArray("composer");
                        String composer = "";
                        for (int i = 0; i < composers.length(); i++)
                            composer += settings.artistSeparator + composers.getString(i);
                        if (composer.length() > 2)
                            tag.setField(FieldKey.COMPOSER, composer.substring(settings.artistSeparator.length()));
                    }
                    //Engineer
                    if (contrib.has("engineer")) {
                        JSONArray engineers = contrib.getJSONArray("engineer");
                        String engineer = "";
                        for (int i = 0; i < engineers.length(); i++)
                            engineer += settings.artistSeparator + engineers.getString(i);
                        if (engineer.length() > 2)
                            tag.setField(FieldKey.ENGINEER, engineer.substring(settings.artistSeparator.length()));
                    }
                    //Mixer
                    if (contrib.has("mixer")) {
                        JSONArray mixers = contrib.getJSONArray("mixer");
                        String mixer = "";
                        for (int i = 0; i < mixers.length(); i++)
                            mixer += settings.artistSeparator + mixers.getString(i);
                        if (mixer.length() > 2)
                            tag.setField(FieldKey.MIXER, mixer.substring(settings.artistSeparator.length()));
                    }
                    //Producer
                    if (contrib.has("producer")) {
                        JSONArray producers = contrib.getJSONArray("producer");
                        String producer = "";
                        for (int i = 0; i < producers.length(); i++)
                            producer += settings.artistSeparator + producers.getString(i);
                        if (producer.length() > 2)
                            tag.setField(FieldKey.MIXER, producer.substring(settings.artistSeparator.length()));
                    }

                    //FLAC Only
                    if (isFlac) {
                        //Author
                        if (contrib.has("author")) {
                            JSONArray authors = contrib.getJSONArray("author");
                            String author = "";
                            for (int i = 0; i < authors.length(); i++)
                                author += settings.artistSeparator + authors.getString(i);
                            if (author.length() > 2)
                                ((FlacTag) tag).setField("AUTHOR", author.substring(settings.artistSeparator.length()));
                        }
                        //Writer
                        if (contrib.has("writer")) {
                            JSONArray writers = contrib.getJSONArray("writer");
                            String writer = "";
                            for (int i = 0; i < writers.length(); i++)
                                writer += settings.artistSeparator + writers.getString(i);
                            if (writer.length() > 2)
                                ((FlacTag) tag).setField("WRITER", writer.substring(settings.artistSeparator.length()));
                        }
                    }
                }
            } catch (Exception e) {
                logger.warn("Error writing contributors data: " + e);
            }
        }

        File coverFile = new File(cover);
        boolean addCover = (coverFile.exists() && coverFile.length() > 0);

        if (isFlac) {
            //FLAC Specific tags
            if (settings.tags.date) ((FlacTag)tag).setField("DATE", publicTrack.getString("release_date"));
            //Cover
            if (addCover && settings.tags.albumArt) {
                try (RandomAccessFile cf = new RandomAccessFile(coverFile, "r")) {
                    byte[] coverData = new byte[(int) cf.length()];
                    cf.read(coverData);
                    tag.setField(((FlacTag) tag).createArtworkField(
                            coverData,
                            PictureTypes.DEFAULT_ID,
                            ImageFormats.MIME_TYPE_JPEG,
                            "cover",
                            settings.albumArtResolution,
                            settings.albumArtResolution,
                            24,
                            0
                    ));
                } catch (Exception e) {
                    logger.warn("Error writing coverFile artwork: " + e);
                }
            }
        } else {
            if (addCover && settings.tags.albumArt) {
                Artwork art = ArtworkFactory.createArtworkFromFile(coverFile);
                tag.addField(art);
            }
        }

        //Save
        AudioFileIO.write(f);
    }

    //Create JSON file, privateJsonData = `song.getLyrics`
    public static String generateLRC(Lyrics lyricsData, JSONObject publicTrack) throws Exception {
        StringBuilder output = new StringBuilder();

        //Create metadata
        String title = publicTrack.getString("title");
        String album = publicTrack.getJSONObject("album").getString("title");
        String artists = "";
        for (int i=0; i<publicTrack.getJSONArray("contributors").length(); i++) {
            artists += ", " + publicTrack.getJSONArray("contributors").getJSONObject(i).getString("name");
        }
        //Write metadata
        output.append("[ar:").append(artists.substring(2)).append("]\r\n[al:").append(album).append("]\r\n[ti:").append(title).append("]\r\n");

        //Get lyrics
        int counter = 0;
        if (lyricsData.getSyncedLyrics() != null){
            for (int i=0; i<lyricsData.getSyncedLyrics().size(); i++) {
                SynchronizedLyric lyric = lyricsData.getSyncedLyrics().get(i);
                if (lyric.getLrcTimestamp() != null && lyric.getText() != null) {
                    output.append(lyric.getLrcTimestamp()).append(lyric.getText()).append("\r\n");
                    counter += 1;
                }
            }
        }

        if (counter == 0) throw new Exception("Empty Lyrics!");
        return output.toString();
    }

    static class QualityInfo {
        int quality;
        String md5origin;
        String mediaVersion;
        String trackId;
        String trackToken;
        int initialQuality;
        DownloadLog logger;
        boolean encrypted;

        QualityInfo(int quality, String trackId, String trackToken, String md5origin, String mediaVersion, DownloadLog logger) {
            this.quality = quality;
            this.initialQuality = quality;
            this.trackId = trackId;
            this.trackToken = trackToken;
            this.mediaVersion = mediaVersion;
            this.md5origin = md5origin;
            this.logger = logger;
        }

        String fallback(Deezer deezer) {
            //Quality fallback
            try {
                String url = qualityFallback(deezer);
                //No quality
                if (quality == -1)
                    throw new Exception("No quality to fallback to!");

                //Success
                return url;
            } catch (Exception e) {
                logger.warn("Quality fallback failed! ID: " + trackId + " " + e);
                quality = initialQuality;
            }

            //Track ID Fallback
            JSONObject privateJson = null;
            try {
                //Fetch meta
                JSONObject privateRaw = deezer.callGWAPI("deezer.pageTrack", "{\"sng_id\": \"" + trackId + "\"}");
                privateJson = privateRaw.getJSONObject("results").getJSONObject("DATA");
                if (privateJson.has("FALLBACK")) {
                    //Fetch new track
                    String fallbackId = privateJson.getJSONObject("FALLBACK").getString("SNG_ID");
                    if (!fallbackId.equals(trackId)) {
                        JSONObject newPrivate = deezer.callGWAPI("song.getListData", "{\"sng_ids\": [" + fallbackId + "]}");
                        JSONObject trackData = newPrivate.getJSONObject("results").getJSONArray("data").getJSONObject(0);
                        trackId = trackData.getString("SNG_ID");
                        trackToken = trackData.getString("TRACK_TOKEN");
                        md5origin = trackData.getString("MD5_ORIGIN");
                        mediaVersion = trackData.getString("MEDIA_VERSION");
                        return fallback(deezer);
                    }
                }
            } catch (Exception e) {
                logger.error("ID fallback failed! ID: " + trackId + " " + e);
            }

            //ISRC Fallback
            try {
                JSONObject newTrackJson = deezer.callPublicAPI("track", "isrc:" + privateJson.getString("ISRC"));
                //Same track check
                if (newTrackJson.getInt("id") == Integer.parseInt(trackId)) throw new Exception("No more to ISRC fallback!");
                //Get private data
                privateJson = deezer.callGWAPI("song.getListData", "{\"sng_ids\": [" + newTrackJson.getInt("id") + "]}");
                JSONObject trackData = privateJson.getJSONObject("results").getJSONArray("data").getJSONObject(0);
                trackId = trackData.getString("SNG_ID");
                trackToken = trackData.getString("TRACK_TOKEN");
                md5origin = trackData.getString("MD5_ORIGIN");
                mediaVersion = trackData.getString("MEDIA_VERSION");
                return fallback(deezer);
            } catch (Exception e) {
                logger.error("ISRC Fallback failed, track unavailable! ID: " + trackId + " " + e);
            }

            return null;
        }

        private String qualityFallback(Deezer deezer) throws Exception {
            Pair<String,Boolean> urlGen = deezer.getTrackUrl(trackId, trackToken, md5origin, mediaVersion, quality, 0);
            this.encrypted = urlGen.second;

            // initialise as "404 Not Found"
            int urlResponseCode = 404;

            if (urlGen.first != null) {
                //Create HEAD requests to check if exists
                URL url = new URL(urlGen.first);
                HttpsURLConnection connection = (HttpsURLConnection) url.openConnection();
                connection.setRequestMethod("HEAD");
                connection.setRequestProperty("User-Agent", USER_AGENT);
                connection.setRequestProperty("Accept-Language", "*");
                connection.setRequestProperty("Accept", "*/*");
                urlResponseCode = connection.getResponseCode();
            }
            //Track not available
            if (urlResponseCode > 400) {
                logger.warn("Quality fallback, response code: " + urlResponseCode + ", current: " + Integer.toString(quality));
                //-1 if no quality available
                if (quality == 1) {
                    quality = -1;
                    return null;
                }
                if (quality == 3) quality = 1;
                if (quality == 9) quality = 3;
                return qualityFallback(deezer);
            }
            return urlGen.first;
        }

    }
}
