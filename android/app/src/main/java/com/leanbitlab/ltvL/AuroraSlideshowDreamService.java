package com.leanbitlab.ltvL;

/*
 * SPC Aurora photo screensaver.
 * Displays the 15 bundled pictures, with a gentle crossfade every 45 seconds.
 * Small Prague and Pittsburgh clocks update automatically, including DST changes.
 * No network, advertising, or third-party photo services are used.
 */
import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.Looper;
import android.service.dreams.DreamService;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.io.IOException;
import java.io.InputStream;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

public final class AuroraSlideshowDreamService extends DreamService {
    private static final long IMAGE_INTERVAL_MS = 45_000L;
    private static final long FADE_DURATION_MS = 1_400L;
    private static final long CLOCK_REFRESH_MS = 15_000L;
    private static final String ASSETS_PREFIX = "flutter_assets/assets/screensaver/";

    // Only the image files the user uploaded (the .gitkeep file is excluded).
    private static final String[] PHOTO_NAMES = {
        "screen_01.jpg", "screen_02.jpg", "screen_03.jpg",
        "screen_04.jpg", "screen_05.jpg", "screen_06.jpeg",
        "screen_07.jpg", "screen_08.jpg", "screen_09.jpg",
        "screen_10.jpg", "screen_11.png", "screen_12.jpg",
        "screen_13.jpg", "screen_14.jpg", "screen_15.jpg"
    };

    private final Handler handler = new Handler(Looper.getMainLooper());
    private FrameLayout root;
    private ImageView currentImage;
    private TextView pragueTime;
    private TextView pittsburghTime;
    private TextView dateText;
    private int photoIndex;
    private boolean active;

    private final Runnable slideshowTick = new Runnable() {
        @Override
        public void run() {
            if (!active) return;
            showNextPhoto();
            handler.postDelayed(this, IMAGE_INTERVAL_MS);
        }
    };

    private final Runnable clockTick = new Runnable() {
        @Override
        public void run() {
            if (!active) return;
            updateClock();
            handler.postDelayed(this, CLOCK_REFRESH_MS);
        }
    };

    @Override
    public void onAttachedToWindow() {
        super.onAttachedToWindow();
        setInteractive(false); // Remote button wakes/exits the dream.
        setFullscreen(true);
        setScreenBright(true);
        active = true;

        root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);
        setContentView(root);

        // Start with the first actual image, then advance in upload order.
        photoIndex = 0;
        currentImage = newImageView(PHOTO_NAMES[0]);
        if (currentImage != null) {
            root.addView(currentImage, fillScreenParams());
        }

        addClockOverlay();
        addDateOverlay();
        updateClock();
        handler.postDelayed(slideshowTick, IMAGE_INTERVAL_MS);
        handler.postDelayed(clockTick, CLOCK_REFRESH_MS);
    }

    private FrameLayout.LayoutParams fillScreenParams() {
        return new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        );
    }

    private ImageView newImageView(String file) {
        Bitmap bitmap = decodeSizedBitmap(ASSETS_PREFIX + file);
        if (bitmap == null) return null;
        ImageView image = new ImageView(this);
        image.setScaleType(ImageView.ScaleType.CENTER_CROP);
        // Fills the entire screen without distorting aspect ratio.
        // A narrow strip may be cropped on images with a different aspect ratio.
        image.setImageBitmap(bitmap);
        return image;
    }

    private Bitmap decodeSizedBitmap(String assetPath) {
        DisplayMetrics metrics = getResources().getDisplayMetrics();
        int targetW = Math.max(1280, metrics.widthPixels);
        int targetH = Math.max(720, metrics.heightPixels);

        BitmapFactory.Options bounds = new BitmapFactory.Options();
        bounds.inJustDecodeBounds = true;
        try (InputStream stream = getAssets().open(assetPath)) {
            BitmapFactory.decodeStream(stream, null, bounds);
        } catch (IOException e) {
            android.util.Log.w("AuroraScreensaver", "Unable to read photo " + assetPath, e);
            return null;
        }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null;

        // Avoid decoding huge photo files at their original resolution.
        BitmapFactory.Options opts = new BitmapFactory.Options();
        opts.inPreferredConfig = Bitmap.Config.RGB_565;
        int sample = 1;
        while ((bounds.outWidth / (sample * 2)) >= targetW &&
               (bounds.outHeight / (sample * 2)) >= targetH) {
            sample *= 2;
        }
        opts.inSampleSize = sample;
        try (InputStream stream = getAssets().open(assetPath)) {
            return BitmapFactory.decodeStream(stream, null, opts);
        } catch (IOException | OutOfMemoryError e) {
            android.util.Log.w("AuroraScreensaver", "Unable to decode photo " + assetPath, e);
            return null;
        }
    }

    private void showNextPhoto() {
        if (root == null) return;
        // If a photo is unusable, skip it instead of stopping the slideshow.
        ImageView next = null;
        for (int attempts = 0; attempts < PHOTO_NAMES.length; attempts++) {
            photoIndex = (photoIndex + 1) % PHOTO_NAMES.length;
            next = newImageView(PHOTO_NAMES[photoIndex]);
            if (next != null) break;
        }
        if (next == null) return;

        if (currentImage == null) {
            root.addView(next, 0, fillScreenParams());
            currentImage = next;
            return;
        }

        final ImageView previous = currentImage;
        final ImageView incoming = next;
        incoming.setAlpha(0f);
        root.addView(incoming, root.indexOfChild(previous) + 1, fillScreenParams());
        currentImage = incoming;
        incoming.animate()
            .alpha(1f)
            .setDuration(FADE_DURATION_MS)
            .setListener(new AnimatorListenerAdapter() {
                @Override
                public void onAnimationEnd(Animator animation) {
                    incoming.animate().setListener(null);
                    if (root != null) root.removeView(previous);
                    // Release drawable reference after the crossfade finishes.
                    previous.setImageDrawable(null);
                }
            })
            .start();
    }

    private void addClockOverlay() {
        LinearLayout clockPanel = new LinearLayout(this);
        clockPanel.setOrientation(LinearLayout.VERTICAL);
        clockPanel.setPadding(dp(15), dp(10), dp(15), dp(10));

        GradientDrawable panelBackground = new GradientDrawable();
        panelBackground.setColor(0x74071120);
        panelBackground.setCornerRadius(dp(11));
        clockPanel.setBackground(panelBackground);

        pragueTime = newTimeText();
        pittsburghTime = newTimeText();
        clockPanel.addView(newClockRow("PRAGUE", pragueTime));
        clockPanel.addView(newClockRow("PITTSBURGH", pittsburghTime));

        FrameLayout.LayoutParams position = new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.RIGHT | Gravity.BOTTOM
        );
        position.setMargins(dp(20), dp(20), dp(30), dp(28));
        root.addView(clockPanel, position);
    }

    // A fixed label column keeps the Prague and Pittsburgh times perfectly aligned.
    private LinearLayout newClockRow(String cityName, TextView timeValue) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);

        TextView cityLabel = newTimeText();
        cityLabel.setText(cityName);
        cityLabel.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        cityLabel.setGravity(Gravity.LEFT | Gravity.CENTER_VERTICAL);
        cityLabel.setTypeface(Typeface.create("sans-serif", Typeface.NORMAL));
        row.addView(cityLabel, new LinearLayout.LayoutParams(
            dp(124), ViewGroup.LayoutParams.WRAP_CONTENT
        ));

        timeValue.setGravity(Gravity.RIGHT | Gravity.CENTER_VERTICAL);
        row.addView(timeValue, new LinearLayout.LayoutParams(
            dp(100), ViewGroup.LayoutParams.WRAP_CONTENT
        ));
        return row;
    }

    private void addDateOverlay() {
        dateText = newTimeText();
        dateText.setGravity(Gravity.LEFT | Gravity.CENTER_VERTICAL);
        dateText.setPadding(dp(15), dp(10), dp(15), dp(10));

        GradientDrawable panelBackground = new GradientDrawable();
        panelBackground.setColor(0x74071120);
        panelBackground.setCornerRadius(dp(11));
        dateText.setBackground(panelBackground);

        FrameLayout.LayoutParams position = new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.LEFT | Gravity.BOTTOM
        );
        position.setMargins(dp(30), dp(20), dp(20), dp(28));
        root.addView(dateText, position);
    }

    private TextView newTimeText() {
        TextView text = new TextView(this);
        text.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        text.setTextColor(Color.WHITE);
        text.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        text.setLetterSpacing(0.025f);
        text.setGravity(Gravity.RIGHT);
        text.setShadowLayer(dp(4), 0, dp(1), Color.BLACK);
        text.setPadding(0, dp(3), 0, dp(3));
        return text;
    }

    private void updateClock() {
        if (pragueTime == null || pittsburghTime == null || dateText == null) return;

        Date current = new Date();
        pragueTime.setText(formattedTime(current, "Europe/Prague"));
        // Pittsburgh observes Eastern Time: EST in winter, EDT in summer.
        pittsburghTime.setText(formattedTime(current, "America/New_York"));

        SimpleDateFormat dateFormat = new SimpleDateFormat("MMMM d", Locale.US);
        // Match the home screen's date convention (Prague local date).
        dateFormat.setTimeZone(TimeZone.getTimeZone("Europe/Prague"));
        dateText.setText(dateFormat.format(current));
    }

    private String formattedTime(Date moment, String zoneId) {
        SimpleDateFormat format = new SimpleDateFormat("h:mm a", Locale.US);
        format.setTimeZone(TimeZone.getTimeZone(zoneId));
        return format.format(moment);
    }

    private int dp(float n) {
        return Math.round(TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            n,
            getResources().getDisplayMetrics()
        ));
    }

    @Override
    public void onDetachedFromWindow() {
        active = false;
        handler.removeCallbacksAndMessages(null);
        if (currentImage != null) currentImage.animate().cancel();
        if (root != null) root.removeAllViews();
        currentImage = null;
        pragueTime = null;
        pittsburghTime = null;
        dateText = null;
        root = null;
        super.onDetachedFromWindow();
    }
}
