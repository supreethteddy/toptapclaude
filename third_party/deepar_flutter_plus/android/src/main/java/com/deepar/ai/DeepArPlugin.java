package com.deepar.ai;

import androidx.annotation.NonNull;
import android.app.Activity;
import android.graphics.Bitmap;
import android.graphics.SurfaceTexture;
import android.media.Image;
import android.media.MediaScannerConnection;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.text.format.DateFormat;
import android.util.Log;
import android.view.Surface;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.regex.PatternSyntaxException;
import java.io.IOException;
import java.io.InputStream;
import android.graphics.BitmapFactory;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import ai.deepar.ar.ARErrorType;
import ai.deepar.ar.AREventListener;
import ai.deepar.ar.CameraResolutionPreset;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import io.flutter.plugin.common.PluginRegistry;
import io.flutter.view.TextureRegistry;
import ai.deepar.ar.DeepAR;
import ai.deepar.ar.DeepARPixelFormat;

/**
 * DeepArPlugin
 */
public class DeepArPlugin implements FlutterPlugin, AREventListener, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
    /// Lets a separate, app-level native module (not this plugin) receive
    /// DeepAR's processed output frames without this plugin needing to know
    /// anything about where they end up — e.g. forwarding them into a
    /// streaming SDK's custom video capture. Only populated after
    /// setOffscreenRendering has been enabled via the "enable_offscreen_rendering"
    /// method call below; frameAvailable(Image) is otherwise never invoked by
    /// the native DeepAR SDK.
    public interface RawFrameListener {
        void onFrame(Image image);
    }

    public static volatile RawFrameListener rawFrameListener;

    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private MethodChannel cameraXChannel, channel;

    private final String TAG = "DEEPAR_LOGS";
    private Activity activity;
    private DeepAR deepAR;
    private Surface surface;
    private long textureId;
    private FlutterPluginBinding flutterPlugin;
    private TextureRegistry.SurfaceTextureEntry surfaceTextureEntry;
    private SurfaceTexture tempSurfaceTexture;
    private SafeCameraXHandler safeCameraXHandler;
    private HandlerThread deepArThread;
    private Handler deepArHandler;
    private final Object deepArThreadLock = new Object();
    private String videoFilePath;
    private String screenshotPath;

    private CameraResolutionPreset resolutionPreset;

    private enum DeepArResponse {
        videoStarted,
        videoCompleted,
        videoError,
        screenshotTaken
    }

    private interface DeepArTask<T> {
        T run() throws Exception;
    }


    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {

        onActivityAttached(binding);
    }


    private void onActivityAttached(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        setDeepArMethodChannel();
        binding.addRequestPermissionsResultListener(this);
    }

    private void setDeepArMethodChannel() {
        channel = new MethodChannel(flutterPlugin.getBinaryMessenger(), MethodStrings.generalChannel);
        channel.setMethodCallHandler(new MethodCallHandler() {
            @Override
            public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
                handleMethods(call, result);
            }
        });
    }

    private void ensureDeepArThread() {
        synchronized (deepArThreadLock) {
            if (deepArThread != null && deepArThread.isAlive() && deepArHandler != null) {
                return;
            }

            deepArThread = new HandlerThread("DeepARRenderThread");
            deepArThread.start();
            deepArHandler = new Handler(deepArThread.getLooper());
            Log.d(TAG, "DeepAR render thread started");
        }
    }

    private void shutdownDeepArThread() {
        synchronized (deepArThreadLock) {
            if (deepArThread == null) {
                deepArHandler = null;
                return;
            }

            try {
                deepArThread.quitSafely();
                deepArThread.join(500);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                Log.w(TAG, "Interrupted while stopping DeepAR render thread", e);
            } catch (Exception e) {
                Log.e(TAG, "Failed to stop DeepAR render thread", e);
            } finally {
                deepArThread = null;
                deepArHandler = null;
            }
        }
    }

    private void postToDeepArThread(@NonNull Runnable runnable) {
        ensureDeepArThread();

        final Handler handler;
        synchronized (deepArThreadLock) {
            handler = deepArHandler;
        }

        if (handler == null || !handler.post(runnable)) {
            Log.e(TAG, "Failed to post task to DeepAR render thread");
        }
    }

    @SuppressWarnings("unchecked")
    private <T> T runOnDeepArThreadBlocking(@NonNull DeepArTask<T> task, long timeoutMs)
            throws Exception {
        ensureDeepArThread();

        final Handler handler;
        synchronized (deepArThreadLock) {
            handler = deepArHandler;
        }

        if (handler == null) {
            throw new IllegalStateException("DeepAR render handler is unavailable");
        }

        if (Looper.myLooper() == handler.getLooper()) {
            return task.run();
        }

        final CountDownLatch latch = new CountDownLatch(1);
        final Object[] resultHolder = new Object[1];
        final Exception[] errorHolder = new Exception[1];

        final boolean posted = handler.post(() -> {
            try {
                resultHolder[0] = task.run();
            } catch (Exception e) {
                errorHolder[0] = e;
            } finally {
                latch.countDown();
            }
        });

        if (!posted) {
            throw new IllegalStateException("Failed to post task to DeepAR render thread");
        }

        if (!latch.await(timeoutMs, TimeUnit.MILLISECONDS)) {
            throw new IllegalStateException("DeepAR render task timed out");
        }

        if (errorHolder[0] != null) {
            throw errorHolder[0];
        }

        return (T) resultHolder[0];
    }

    private boolean executeDeepARAction(
            @NonNull Result result,
            @NonNull String operationName,
            long timeoutMs,
            @NonNull DeepArTask<Void> action,
            @NonNull String successMessage
    ) {
        if (deepAR == null) {
            result.error("NOT_INITIALIZED", "DeepAR is not initialized", null);
            return false;
        }

        try {
            runOnDeepArThreadBlocking(action, timeoutMs);
            result.success(successMessage);
            return true;
        } catch (Exception e) {
            Log.e(TAG, operationName + " failed", e);
            result.error("DEEPAR_ACTION_FAILED", operationName + " failed", e.getMessage());
            return false;
        }
    }

    @SuppressWarnings("unchecked")
    private void handleMethods(MethodCall call, Result result) {
        final Map<String, Object> arguments = call.arguments instanceof Map
                ? (Map<String, Object>) call.arguments
                : new HashMap<>();

        switch (call.method) {
            case MethodStrings.initialize:
                final String licenseKey = (String) arguments.get(MethodStrings.licenseKey);
                final String resolution = (String) arguments.get(MethodStrings.resolution);

                if ("veryHigh".equals(resolution)) {
                    resolutionPreset = CameraResolutionPreset.P1920x1080;
                } else if ("high".equals(resolution)) {
                    resolutionPreset = CameraResolutionPreset.P1280x720;
                } else if ("medium".equals(resolution)) {
                    resolutionPreset = CameraResolutionPreset.P640x480;
                } else {
                    resolutionPreset = CameraResolutionPreset.P640x360;
                }

                Log.d(TAG, "licenseKey = " + licenseKey);
                final boolean success = initializeDeepAR(licenseKey, resolutionPreset);
                if (!success) {
                    result.error("INITIALIZE_FAILED", "DeepAR initialization failed", null);
                    break;
                }
                setCameraXChannel(resolutionPreset);
                result.success(resolutionPreset.getWidth() + " " + resolutionPreset.getHeight());
                break;

            case MethodStrings.switchEffect:
                try (InputStream inputStream = _getAssetFileInputStream((String) arguments.get("effect"))) {
                    executeDeepARAction(
                            result,
                            "switchEffect",
                            1500,
                            () -> {
                                deepAR.switchEffect("effect", inputStream);
                                return null;
                            },
                            "switchEffect called successfully"
                    );
                } catch (IOException e) {
                    Log.e(TAG, "switchEffect failed", e);
                    result.error("111", "switchEffect failed", e.getMessage());
                }
                break;

            case MethodStrings.startRecordingVideo:
                try {
                    File file = File.createTempFile("deepar_", ".mp4");
                    videoFilePath = file.getPath();
                    final boolean started = executeDeepARAction(
                            result,
                            "startRecordingVideo",
                            1500,
                            () -> {
                                deepAR.startVideoRecording(videoFilePath);
                                return null;
                            },
                            "Video recording started"
                    );
                    if (!started) {
                        videoResult(DeepArResponse.videoError, "Unable to start recording");
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Video recording failed", e);
                    videoResult(DeepArResponse.videoError, "Exception while creating file");
                    result.error("111", "Video recording failed", e.getMessage());
                }
                break;

            case MethodStrings.stopRecordingVideo:
                executeDeepARAction(
                        result,
                        "stopRecordingVideo",
                        1500,
                        () -> {
                            deepAR.stopVideoRecording();
                            return null;
                        },
                        "STOPPING_RECORDING"
                );
                break;

            case "enable_offscreen_rendering":
                // Makes frameAvailable(Image) start firing (it's otherwise
                // never invoked) so a native listener can forward DeepAR's
                // processed frames elsewhere (see RawFrameListener above).
                // RGBA_8888 is the only pixel format this SDK's offscreen
                // rendering supports.
                final int rawFrameWidth = (int) arguments.get("width");
                final int rawFrameHeight = (int) arguments.get("height");
                executeDeepARAction(
                        result,
                        "enableOffscreenRendering",
                        1500,
                        () -> {
                            deepAR.setOffscreenRendering(rawFrameWidth, rawFrameHeight,
                                    DeepARPixelFormat.RGBA_8888);
                            return null;
                        },
                        "enableOffscreenRendering called successfully"
                );
                break;

            case "take_screenshot":
                executeDeepARAction(
                        result,
                        "takeScreenshot",
                        1500,
                        () -> {
                            deepAR.takeScreenshot();
                            return null;
                        },
                        "SCREENSHOT_TRIGGERED"
                );
                break;

            case "switch_face_mask":
                final String mask = (String) arguments.get("effect");
                if (mask == null || "null".equals(mask)) {
                    executeDeepARAction(
                            result,
                            "switchFaceMaskReset",
                            1500,
                            () -> {
                                deepAR.switchEffect("mask", "null");
                                return null;
                            },
                            "switchMask called & reset success"
                    );
                    break;
                }

                try (InputStream inputStream = _getAssetFileInputStream(mask)) {
                    executeDeepARAction(
                            result,
                            "switchFaceMask",
                            1500,
                            () -> {
                                deepAR.switchEffect("mask", inputStream);
                                return null;
                            },
                            "switchMask called successfully"
                    );
                } catch (IOException e) {
                    Log.e(TAG, "switchMask failed", e);
                    result.error("111", "switchMask failed", e.getMessage());
                }
                break;

            case "switch_filter":
                final String filter = (String) arguments.get("effect");
                if (filter == null || "null".equals(filter)) {
                    executeDeepARAction(
                            result,
                            "switchFilterReset",
                            1500,
                            () -> {
                                deepAR.switchEffect("filters", "null");
                                return null;
                            },
                            "switchFilter called & reset success"
                    );
                    break;
                }

                try (InputStream inputStream = _getAssetFileInputStream(filter)) {
                    executeDeepARAction(
                            result,
                            "switchFilter",
                            1500,
                            () -> {
                                deepAR.switchEffect("filters", inputStream);
                                return null;
                            },
                            "switchFilter called successfully"
                    );
                } catch (IOException e) {
                    Log.e(TAG, "switchFilter failed", e);
                    result.error("111", "switchFilter failed", e.getMessage());
                }
                break;

            case "switchEffectWithSlot":
                final String slot = (String) arguments.get("slot");
                final String path = (String) arguments.get("path");
                final Object faceRaw = arguments.get("face");
                final int face = faceRaw instanceof Number ? ((Number) faceRaw).intValue() : 0;
                final String targetGameObject = (String) arguments.get("targetGameObject");

                if (path != null && path.toLowerCase().endsWith("none")) {
                    executeDeepARAction(
                            result,
                            "switchEffectWithSlotReset",
                            1500,
                            () -> {
                                deepAR.switchEffect(slot, getResetPath());
                                return null;
                            },
                            "switchEffectWithSlot reset success"
                    );
                    break;
                }

                try (InputStream inputStream = _getAssetFileInputStream(path)) {
                    executeDeepARAction(
                            result,
                            "switchEffectWithSlot",
                            1500,
                            () -> {
                                if (targetGameObject != null && !targetGameObject.isEmpty()) {
                                    deepAR.switchEffect(slot, inputStream, face, targetGameObject);
                                } else {
                                    deepAR.switchEffect(slot, inputStream, face);
                                }
                                return null;
                            },
                            "switchEffectWithSlot called successfully"
                    );
                } catch (IOException e) {
                    Log.e(TAG, "switchEffectWithSlot failed", e);
                    result.error("111", "switchEffectWithSlot failed", e.getMessage());
                }
                break;

            case "fireTrigger":
                executeDeepARAction(
                        result,
                        "fireTrigger",
                        1500,
                        () -> {
                            deepAR.fireTrigger((String) arguments.get("trigger"));
                            return null;
                        },
                        "fireTrigger called successfully"
                );
                break;

            case "showStats":
                final boolean showStatsEnabled = (boolean) arguments.get("enabled");
                executeDeepARAction(
                        result,
                        "showStats",
                        1500,
                        () -> {
                            deepAR.showStats(showStatsEnabled);
                            return null;
                        },
                        "showStats called successfully"
                );
                break;

            case "simulatePhysics":
                final boolean simulateEnabled = (boolean) arguments.get("enabled");
                executeDeepARAction(
                        result,
                        "simulatePhysics",
                        1500,
                        () -> {
                            deepAR.simulatePhysics(simulateEnabled);
                            return null;
                        },
                        "simulatePhysics called successfully"
                );
                break;

            case "showColliders":
                final boolean showCollidersEnabled = (boolean) arguments.get("enabled");
                executeDeepARAction(
                        result,
                        "showColliders",
                        1500,
                        () -> {
                            deepAR.showColliders(showCollidersEnabled);
                            return null;
                        },
                        "showColliders called successfully"
                );
                break;

            case "moveGameObject":
                final String selectedGameObjectName = (String) arguments.get("selectedGameObjectName");
                final String targetGameObjectName = (String) arguments.get("targetGameObjectName");
                executeDeepARAction(
                        result,
                        "moveGameObject",
                        1500,
                        () -> {
                            deepAR.moveGameObject(selectedGameObjectName, targetGameObjectName);
                            return null;
                        },
                        "moveGameObject called successfully"
                );
                break;

            case "changeParameter":
                final String gameObject = (String) arguments.get("gameObject");
                final String component = (String) arguments.get("component");
                final String parameter = (String) arguments.get("parameter");
                final Object newParameter = arguments.get("newParameter");

                if (newParameter == null) {
                    final float x = ((Number) arguments.get("x")).floatValue();
                    final float y = ((Number) arguments.get("y")).floatValue();
                    final float z = ((Number) arguments.get("z")).floatValue();
                    final Object w = arguments.get("w");

                    if (w == null) {
                        executeDeepARAction(
                                result,
                                "changeParameterVec3",
                                1500,
                                () -> {
                                    deepAR.changeParameterVec3(gameObject, component, parameter, x, y, z);
                                    return null;
                                },
                                "changeParameter called successfully"
                        );
                    } else {
                        final float floatValueW = ((Number) w).floatValue();
                        executeDeepARAction(
                                result,
                                "changeParameterVec4",
                                1500,
                                () -> {
                                    deepAR.changeParameterVec4(gameObject, component, parameter, x, y, z, floatValueW);
                                    return null;
                                },
                                "changeParameter called successfully"
                        );
                    }
                } else if (newParameter instanceof Boolean) {
                    final boolean boolParam = (Boolean) newParameter;
                    executeDeepARAction(
                            result,
                            "changeParameterBool",
                            1500,
                            () -> {
                                deepAR.changeParameterBool(gameObject, component, parameter, boolParam);
                                return null;
                            },
                            "changeParameter called successfully"
                    );
                } else if (newParameter instanceof Double) {
                    final float floatParam = ((Double) newParameter).floatValue();
                    executeDeepARAction(
                            result,
                            "changeParameterFloat",
                            1500,
                            () -> {
                                deepAR.changeParameterFloat(gameObject, component, parameter, floatParam);
                                return null;
                            },
                            "changeParameter called successfully"
                    );
                } else if (newParameter instanceof String) {
                    try (InputStream inputStream = _getAssetFileInputStream((String) newParameter)) {
                        final Bitmap bitmap = BitmapFactory.decodeStream(inputStream);
                        if (bitmap == null) {
                            result.error("111", "changeParameter failed", "Failed to decode texture bitmap");
                            break;
                        }
                        executeDeepARAction(
                                result,
                                "changeParameterTexture",
                                1500,
                                () -> {
                                    deepAR.changeParameterTexture(gameObject, component, parameter, bitmap);
                                    return null;
                                },
                                "changeParameter called successfully"
                        );
                    } catch (IOException e) {
                        Log.e(TAG, "changeParameter failed", e);
                        result.error("111", "changeParameter failed", e.getMessage());
                    }
                } else {
                    result.error("INVALID_PARAMETER", "Unsupported changeParameter value type", null);
                }
                break;

            default:
                result.notImplemented();
                break;
        }
    }

    private String getResetPath(){
        return null;
    }

    private void setCameraXChannel(CameraResolutionPreset resolutionPreset) {
        cameraXChannel = new MethodChannel(flutterPlugin.getBinaryMessenger(), MethodStrings.cameraXChannel);
        // Ensure old handler is cleaned before re-binding.
        if (safeCameraXHandler != null) {
            try {
                safeCameraXHandler.destroy();
            } catch (Exception e) {
                Log.e(TAG, "Error cleaning old SafeCameraXHandler", e);
            }
            safeCameraXHandler = null;
        }

        safeCameraXHandler = new SafeCameraXHandler(activity,
                textureId, deepAR, resolutionPreset,
                this::postToDeepArThread,
                this::sendCameraHealthEvent,
                this::handleCameraHandlerDestroyed);
        cameraXChannel.setMethodCallHandler(safeCameraXHandler);
        Log.d(TAG, "Using SafeCameraXHandler for better stability");
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {

    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        onActivityAttached(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }


    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        flutterPlugin = flutterPluginBinding;
    }


    private boolean initializeDeepAR(String licenseKey, CameraResolutionPreset resolutionPreset) {
        try {
            if (activity == null || flutterPlugin == null) {
                Log.e(TAG, "initializeDeepAR failed: plugin not attached to Activity/Engine");
                return false;
            }

            // Clean up any existing resources first
            cleanupNativeResources();
            cleanupSurfaceResources();

            // Initialize with proper error handling
            int width = resolutionPreset.getHeight();
            int height = resolutionPreset.getWidth();

            Log.d(TAG, "Creating surface texture");
            surfaceTextureEntry = flutterPlugin.getTextureRegistry().createSurfaceTexture();
            tempSurfaceTexture = surfaceTextureEntry.surfaceTexture();
            tempSurfaceTexture.setDefaultBufferSize(width, height);
            surface = new Surface(tempSurfaceTexture);

            try {
                runOnDeepArThreadBlocking(() -> {
                    Log.d(TAG, "Creating new DeepAR instance on DeepAR render thread");
                    deepAR = new DeepAR(activity);
                    deepAR.setLicenseKey(licenseKey);
                    deepAR.initialize(activity, this);
                    deepAR.changeLiveMode(true);

                    Log.d(TAG, "Setting render surface on DeepAR render thread");
                    deepAR.setRenderSurface(surface, width, height);
                    textureId = surfaceTextureEntry.id();
                    return null;
                }, 3000);
                Log.d(TAG, "DeepAR initialized successfully with textureId: " + textureId);
            } catch (Exception initError) {
                Log.e(TAG, "DeepAR initialization failed", initError);
                cleanupNativeResources();
                cleanupSurfaceResources();
                return false;
            }

            return true;
        } catch (Exception e) {
            Log.e(TAG, "Error initializing DeepAR", e);
            // Clean up any partially initialized resources
            cleanupNativeResources();
            cleanupSurfaceResources();

            return false;
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        try {
            if (channel != null) {
                channel.setMethodCallHandler(null);
            }
            if (cameraXChannel != null) {
                cameraXChannel.setMethodCallHandler(null);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error detaching channels", e);
        }

        if (safeCameraXHandler != null) {
            try {
                safeCameraXHandler.destroy();
            } catch (Exception e) {
                Log.e(TAG, "Error destroying SafeCameraXHandler on detach", e);
            }
            safeCameraXHandler = null;
        }

        cleanupNativeResources();
        cleanupSurfaceResources();
        shutdownDeepArThread();

        cameraXChannel = null;
        channel = null;
        flutterPlugin = null;
    }

    @Override
    public void screenshotTaken(Bitmap bitmap) {
        CharSequence now = DateFormat.format("yyyy_MM_dd_hh_mm_ss", new Date());
        try {
            //File imageFile = new File(activity.getExternalFilesDir(Environment.DIRECTORY_PICTURES), "image_" + now + ".jpg");

            // TODO: 15/07/22 replace with correct path
            //File imageFile = new File("/storage/emulated/0/Download", "image_" + now + ".jpg");
            File imageFile = File.createTempFile("image_" + now, ".jpg");
            FileOutputStream outputStream = new FileOutputStream(imageFile);
            int quality = 100;
            bitmap.compress(Bitmap.CompressFormat.JPEG, quality, outputStream);
            outputStream.flush();
            outputStream.close();
            //MediaScannerConnection.scanFile(activity, new String[]{imageFile.toString()}, null, null);
            screenshotPath = imageFile.getPath();
            screenshotResult(DeepArResponse.screenshotTaken, "screenshot taken");
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void videoRecordingStarted() {
        Log.d(TAG, "videoRecordingStarted: "+videoFilePath);
        videoResult(DeepArResponse.videoStarted, "video success");
    }

    @Override
    public void videoRecordingFinished() {
        Log.d(TAG, "videoRecordingFinished: "+videoFilePath);
        videoResult(DeepArResponse.videoCompleted, "video success");
    }

    @Override
    public void videoRecordingFailed() {
        Log.d(TAG, "videoRecordingFailed: "+videoFilePath);
        videoResult(DeepArResponse.videoError, "video failed");
    }

    @Override
    public void videoRecordingPrepared() {

    }

    @Override
    public void shutdownFinished() {

    }

    @Override
    public void initialized() {
        Log.d(TAG, "initialized : DEEPAR");
    }

    @Override
    public void faceVisibilityChanged(boolean b) {

    }

    @Override
    public void imageVisibilityChanged(String s, boolean b) {

    }

    @Override
    public void frameAvailable(Image image) {
        // DeepAR owns this Image (it's acquired from its own internal
        // offscreen ImageReader) and is assumed to close it itself right
        // after notifying listeners here — this SDK ships as a compiled AAR
        // with no source to confirm that against, so deliberately never
        // call image.close() from here: double-closing would throw
        // IllegalStateException from inside DeepAR's own callback dispatch.
        RawFrameListener listener = rawFrameListener;
        if (listener != null) {
            try {
                listener.onFrame(image);
            } catch (Exception e) {
                Log.e(TAG, "RawFrameListener.onFrame failed: " + e);
            }
        }
    }

    @Override
    public void error(ARErrorType arErrorType, String s) {

    }

    @Override
    public void effectSwitched(String s) {

    }

    @Override
    public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        Log.d(TAG, "onRequestPermissionsResult: "+requestCode);
        return false;
    }

    private void videoResult(DeepArResponse callerResponse, String message){
        Map<String, Object> map= new HashMap<String, Object>();
        map.put("caller", callerResponse.name());
        map.put("message", message);
        if (callerResponse == DeepArResponse.videoCompleted){
            map.put("file_path", videoFilePath);
            videoFilePath = "";
        }
        channel.invokeMethod("on_video_result", map);
    }

    private void screenshotResult(DeepArResponse callerResponse, String message){
        Map<String, Object> map= new HashMap<String, Object>();
        map.put("caller", callerResponse.name());
        map.put("message", message);
        if (callerResponse == DeepArResponse.screenshotTaken){
            map.put("file_path", screenshotPath);
            screenshotPath = "";
        }
        channel.invokeMethod("on_screenshot_result", map);
    }

    /// Handle both asset paths and file paths
    InputStream _getAssetFileInputStream(String path) throws IOException {
        if (path == null) {
            throw new IOException("Path cannot be null");
        }

        // Check if the path is a file path
        File file = new File(path);
        if (file.exists()) {
            return new FileInputStream(file);
        }

        // Fall back to asset path handling
        try {
            String assetPath = flutterPlugin
                    .getFlutterAssets()
                    .getAssetFilePathBySubpath(path);
            return flutterPlugin.getApplicationContext().getAssets().open(assetPath);
        } catch (IOException e) {
            throw new IOException("Failed to load file from path: " + path, e);
        }
    }

    private void cleanupNativeResources() {
        if (deepAR != null) {
            Log.d(TAG, "Cleaning up existing DeepAR instance before initialization");
            final DeepAR deepARToRelease = deepAR;
            deepAR = null;
            try {
                runOnDeepArThreadBlocking(() -> {
                    deepARToRelease.setAREventListener(null);
                    deepARToRelease.release();
                    return null;
                }, 1500);
            } catch (Exception e) {
                Log.e(TAG, "Error cleaning up existing DeepAR instance", e);
            }
        }
    }

    private void cleanupSurfaceResources() {
        if (surface != null) {
            try {
                surface.release();
            } catch (Exception e) {
                Log.e(TAG, "Error releasing surface", e);
            }
            surface = null;
        }

        if (tempSurfaceTexture != null) {
            try {
                tempSurfaceTexture.release();
            } catch (Exception e) {
                Log.e(TAG, "Error releasing surface texture", e);
            }
            tempSurfaceTexture = null;
        }

        if (surfaceTextureEntry != null) {
            try {
                surfaceTextureEntry.release();
            } catch (Exception e) {
                Log.e(TAG, "Error releasing texture entry", e);
            }
            surfaceTextureEntry = null;
        }
    }

    private void sendCameraHealthEvent(
            String reason,
            String message,
            Map<String, Object> details
    ) {
        if (channel == null || activity == null) return;

        try {
            activity.runOnUiThread(() -> {
                try {
                    Map<String, Object> event = new HashMap<>();
                    event.put("reason", reason);
                    event.put("message", message);
                    if (details != null) {
                        event.putAll(details);
                    }
                    channel.invokeMethod("on_camera_health", event);
                } catch (Exception e) {
                    Log.e(TAG, "Failed to send camera health event", e);
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "Failed to dispatch camera health event", e);
        }
    }

    private void handleCameraHandlerDestroyed(DeepAR destroyedDeepARInstance) {
        try {
            if (activity != null) {
                activity.runOnUiThread(() -> {
                    if (destroyedDeepARInstance != null && deepAR == destroyedDeepARInstance) {
                        cleanupNativeResources();
                        cleanupSurfaceResources();
                    } else {
                        Log.d(TAG, "Ignoring stale SafeCameraXHandler destroy callback");
                    }
                });
            } else {
                if (destroyedDeepARInstance != null && deepAR == destroyedDeepARInstance) {
                    cleanupNativeResources();
                    cleanupSurfaceResources();
                } else {
                    Log.d(TAG, "Ignoring stale SafeCameraXHandler destroy callback");
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to cleanup DeepAR resources after handler destroy", e);
        }
    }
}
