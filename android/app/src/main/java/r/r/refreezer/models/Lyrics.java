package r.r.refreezer.models;

import java.util.ArrayList;
import java.util.List;

public abstract class Lyrics {
    protected String id;
    protected String writers;
    protected List<SynchronizedLyric> syncedLyrics;
    protected String errorMessage;
    protected String unsyncedLyrics;
    protected Boolean isExplicit;
    protected String copyright;

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getWriters() {
        return writers;
    }

    public void setWriters(String writers) {
        this.writers = writers;
    }

    public List<SynchronizedLyric> getSyncedLyrics() {
        return syncedLyrics;
    }

    public void setSyncedLyrics(List<SynchronizedLyric> syncedLyrics) {
        this.syncedLyrics = syncedLyrics;
    }

    public String getErrorMessage() {
        return errorMessage;
    }

    public void setErrorMessage(String errorMessage) {
        this.errorMessage = errorMessage;
    }

    public String getUnsyncedLyrics() {
        return unsyncedLyrics;
    }

    public void setUnsyncedLyrics(String unsyncedLyrics) {
        this.unsyncedLyrics = unsyncedLyrics;
    }

    public Boolean getExplicit() {
        return isExplicit;
    }

    public void setExplicit(Boolean explicit) {
        isExplicit = explicit;
    }

    public String getCopyright() {
        return copyright;
    }

    public void setCopyright(String copyright) {
        this.copyright = copyright;
    }

    public Lyrics() {
        this.syncedLyrics = new ArrayList<>();
    }

    public boolean isLoaded() {
        return (syncedLyrics != null && !syncedLyrics.isEmpty()) || (unsyncedLyrics != null && !unsyncedLyrics.isEmpty());
    }

    public boolean isSynced() {
        return syncedLyrics != null && syncedLyrics.size() > 1;
    }

    public boolean isUnsynced() {
        return !isSynced() && (unsyncedLyrics != null && !unsyncedLyrics.isEmpty());
    }
}