package r.r.refreezer;

import android.content.pm.PackageManager;
import android.util.Log;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.RandomAccessFile;
import java.net.URL;
import java.util.HashMap;
import java.util.Objects;

import javax.net.ssl.HttpsURLConnection;
import fi.iki.elonen.NanoHTTPD;

public class StreamServer {

    public HashMap<String, StreamInfo> streams = new HashMap<>();

    private WebServer server;
    private final String offlinePath;

    //Shared log & API
    private final DownloadLog logger;
    private final Deezer deezer;
    private boolean authorized = false;

    StreamServer(String arl, String offlinePath) {
        //Initialize shared variables
        logger = new DownloadLog();
        deezer = new Deezer();
        deezer.init(logger, arl);
        this.offlinePath = offlinePath;
    }

    //Create server
    void start() {
        try {
            String host = "127.0.0.1";
            int port = 36958;
            server = new WebServer(host, port);
            server.start();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    void stop() {
        if (server != null)
            server.stop();
    }

    //Information about streamed audio - for showing in UI
    public static class StreamInfo {
        String format;
        long size;
        //"Stream" or "Offline"
        String source;

        StreamInfo(String format, long size, String source) {
            this.format = format;
            this.size = size;
            this.source = source;
        }

        //For passing into UI
        public HashMap<String, Object> toJSON() {
            HashMap<String, Object> out = new HashMap<>();
            out.put("format", format);
            out.put("size", size);
            out.put("source", source);
            return out;
        }

    }

    private class WebServer extends NanoHTTPD {
        public WebServer(String hostname, int port) {
            super(hostname, port);
        }

        @Override
        public Response serve(IHTTPSession session) {
            //Must be only GET
            if (session.getMethod() != Method.GET)
                return newFixedLengthResponse(Response.Status.METHOD_NOT_ALLOWED, MIME_PLAINTEXT, "Only GET request supported!");

            try {
                //Parse range header
                String rangeHeader = session.getHeaders().get("range");
                int startBytes = 0;
                boolean isRanged = false;
                int end = -1;
                if (rangeHeader != null && rangeHeader.startsWith("bytes")) {
                    isRanged = true;
                    String[] ranges = rangeHeader.split("=")[1].split("-");
                    startBytes = Integer.parseInt(ranges[0]);
                    if (ranges.length > 1 && !ranges[1].equals(" ")) {
                        end = Integer.parseInt(ranges[1]);
                    }
                }

                //Check query parameters
                if (session.getParameters().keySet().size() < 6) {
                    //Play offline
                    if (session.getParameters().get("id") != null) {
                        return offlineStream(session, startBytes, end, isRanged);
                    }
                    //Missing QP
                    return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_PLAINTEXT, "Invalid / Missing QP");
                }

                //Stream
                return deezerStream(session, startBytes, end, isRanged);
            } catch (Exception e) {
                e.printStackTrace();
                return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_PLAINTEXT, "An error occurred while serving the request.");
            }
        }

        private Response offlineStream(IHTTPSession session, int startBytes, int end, boolean isRanged) {
            //Get path
            String trackId = Objects.requireNonNull(session.getParameters().get("id")).get(0);
            File file = new File(offlinePath, trackId);
            long size = file.length();
            //Read header
            boolean isFlac = false;
            try {
                InputStream inputStream = new FileInputStream(file);
                byte[] buffer = new byte[4];
                inputStream.read(buffer, 0, 4);
                inputStream.close();
                if (new String(buffer).equals("fLaC"))
                    isFlac = true;
            } catch (Exception e) {
                Log.d("StreamServer", "Invalid offline file: " + e.getMessage());
                return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_PLAINTEXT, "Invalid offline file!");
            }
            //Open file
            RandomAccessFile randomAccessFile;
            try {
                randomAccessFile = new RandomAccessFile(file, "r");
                randomAccessFile.seek(startBytes);
            } catch (Exception e) {
                Log.d("StreamServer", "Failed getting offline data: " + e.getMessage());
                return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_PLAINTEXT, "Failed getting data!");
            }

            //Generate response
            Response response = newFixedLengthResponse(
                    isRanged ? Response.Status.PARTIAL_CONTENT : Response.Status.OK,
                    isFlac ? "audio/flac" : "audio/mpeg",
                    new InputStream() {
                        @Override
                        public int read() throws IOException {
                            return 0;
                        }
                        //Pass thru
                        @Override
                        public int read(byte[] b, int off, int len) throws IOException {
                            return randomAccessFile.read(b, off, len);
                        }
                    },
                    ((end == -1) ? size : end) - startBytes
            );
            //Ranged header
            if (isRanged) {
                String range = "bytes " + Integer.toString(startBytes) + "-" + Long.toString((end == -1) ? size - 1 : end);
                range += "/" + Long.toString(size);
                response.addHeader("Content-Range", range);
            }
            response.addHeader("Accept-Ranges", "bytes");

            //Save stream info
            streams.put(trackId, new StreamInfo((isFlac ? "FLAC" : "MP3"), size, "Offline"));

            return response;
        }

        private Response deezerStream(IHTTPSession session, int startBytes, int end, boolean isRanged) {
            // Authorize
            if (!authorized) {
                deezer.authorize();
                authorized = true;
            }

            //Get QP into Quality Info
            Deezer.QualityInfo qualityInfo = new Deezer.QualityInfo(
                    Integer.parseInt(Objects.requireNonNull(session.getParameters().get("q")).get(0)),
                    Objects.requireNonNull(session.getParameters().get("streamTrackId")).get(0),
                    Objects.requireNonNull(session.getParameters().get("trackToken")).get(0),
                    Objects.requireNonNull(session.getParameters().get("md5origin")).get(0),
                    Objects.requireNonNull(session.getParameters().get("mv")).get(0),
                    logger
            );
            //Fallback
            String sURL;
            try {
                sURL = qualityInfo.fallback(deezer);
                if (sURL == null)
                    throw new Exception("No more to fallback!");
            } catch (Exception e) {
                return newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_PLAINTEXT, "Fallback failed!");
            }

            //Calculate Deezer offsets
            int _deezerStart = startBytes;
            if (qualityInfo.encrypted)
                _deezerStart -= startBytes % 2048;
            final int deezerStart = _deezerStart;
            int dropBytes = startBytes % 2048;

            //Start download
            try {
                URL url = new URL(sURL);
                HttpsURLConnection connection = (HttpsURLConnection) url.openConnection();
                //Set headers
                connection.setConnectTimeout(10000);
                connection.setRequestMethod("GET");
                connection.setRequestProperty("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.130 Safari/537.36");
                connection.setRequestProperty("Accept-Language", "*");
                connection.setRequestProperty("Accept", "*/*");
                connection.setRequestProperty("Range", "bytes=" + Integer.toString(deezerStart) + "-" + ((end == -1) ? "" : Integer.toString(end)));
                connection.connect();

                Response outResponse;
                // Encrypted response
                if (qualityInfo.encrypted) {
                    //Get decryption key
                    final byte[] key = DeezerDecryptor.getKey(qualityInfo.trackId);

                    outResponse = newFixedLengthResponse(
                            isRanged ? Response.Status.PARTIAL_CONTENT : Response.Status.OK,
                            (qualityInfo.quality == 9) ? "audio/flac" : "audio/mpeg",
                            new BufferedInputStream(new FilterInputStream(connection.getInputStream()) {

                                int counter = deezerStart / 2048;
                                int drop = dropBytes;

                                //Decryption stream
                                @Override
                                public int read(byte[] b, int off, int len) throws IOException {
                                    //Read 2048b or EOF
                                    byte[] buffer = new byte[2048];
                                    int read = 0;
                                    int totalRead = 0;
                                    while (read != -1 && totalRead != 2048) {
                                        read = in.read(buffer, totalRead, 2048 - totalRead);
                                        if (read != -1)
                                            totalRead += read;
                                    }
                                    if (totalRead == 0)
                                        return -1;

                                    //Not full chunk return unencrypted
                                    if (totalRead != 2048) {
                                        System.arraycopy(buffer, 0, b, off, totalRead);
                                        return totalRead;
                                    }
                                    //Decrypt every 3rd full chunk
                                    if ((counter % 3) == 0) {
                                        buffer = DeezerDecryptor.decryptChunk(key, buffer);
                                    }
                                    //Drop bytes from rounding to 2048
                                    if (drop > 0) {
                                        int output = 2048 - drop;
                                        System.arraycopy(buffer, drop, b, off, output);
                                        drop = 0;
                                        counter++;
                                        return output;
                                    }
                                    //Copy
                                    System.arraycopy(buffer, 0, b, off, 2048);
                                    counter++;
                                    return 2048;
                                }
                            }, 2048),
                            connection.getContentLength() - dropBytes
                    );
                } else {
                    // Decrypted
                    outResponse = newFixedLengthResponse(
                        isRanged ? Response.Status.PARTIAL_CONTENT : Response.Status.OK,
                        (qualityInfo.quality == 9) ? "audio/flac" : "audio/mpeg",
                        connection.getInputStream(),
                        connection.getContentLength()
                    );
                }

                //Ranged header
                if (isRanged) {
                    String range = "bytes " + Integer.toString(startBytes) + "-" + Integer.toString((end == -1) ? (connection.getContentLength() + deezerStart) - 1 : end);
                    range += "/" + Integer.toString(connection.getContentLength() + deezerStart);
                    outResponse.addHeader("Content-Range", range);
                }
                outResponse.addHeader("Accept-Ranges", "bytes");

                //Save stream info, use original track id since this is used to communicate with Flutter UI
                streams.put(Objects.requireNonNull(session.getParameters().get("id")).get(0), new StreamInfo(
                        ((qualityInfo.quality == 9) ? "FLAC" : "MP3"),
                        deezerStart + connection.getContentLength(),
                        "Stream"
                ));

                return outResponse;
            } catch (Exception e) {
                e.printStackTrace();
            }
            return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_PLAINTEXT, "Failed getting data!");
        }
    }
}