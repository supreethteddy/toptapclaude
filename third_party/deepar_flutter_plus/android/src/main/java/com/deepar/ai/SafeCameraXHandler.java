package com.deepar.ai;

import android.app.Activity;
import android.graphics.ImageFormat;
import android.media.Image;
import android.util.DisplayMetrics;
import android.util.Log;
import android.util.Size;
import android.view.Surface;

import androidx.annotation.NonNull;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageProxy;
import androidx.camera.core.TorchState;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.LifecycleOwner;

import com.google.common.util.concurrent.ListenableFuture;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Executor;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import ai.deepar.ar.CameraResolutionPreset;
import ai.deepar.ar.DeepAR;
import ai.deepar.ar.DeepARImageFormat;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class SafeCameraXHandler implements MethodChannel.MethodCallHandler {
    private static final String TAG = "SafeCameraXHandler";
    private static final int NUMBER_OF_BUFFERS = 2;
    private static final int MIN_FRAMES_FOR_HEALTH_CHECK = 15;
    private static final int MAX_CONSECUTIVE_INVALID_FRAMES = 6;
    private static final double MAX_INVALID_FRAME_RATIO = 0.35;

    interface HealthEventListener {
        void onUnstablePipeline(String reason, String message, Map<String, Object> details);
    }

    interface DestroyListener {
        void onDestroyed(DeepAR destroyedDeepARInstance);
    }

    SafeCameraXHandler(
            Activity activity,
            long textureId,
            DeepAR deepAR,
            CameraResolutionPreset cameraResolutionPreset,
            Executor renderExecutor,
            HealthEventListener healthEventListener,
            DestroyListener destroyListener
    ) {
        this.activity = activity;
        this.deepAR = deepAR;
        this.textureId = textureId;
        this.resolutionPreset = cameraResolutionPreset;
        this.renderExecutor = renderExecutor;
        this.healthEventListener = healthEventListener;
        this.destroyListener = destroyListener;
    }

    private final Activity activity;
    private DeepAR deepAR;
    private final long textureId;
    private ProcessCameraProvider processCameraProvider;
    private ListenableFuture<ProcessCameraProvider> future;
    private ByteBuffer[] buffers;
    private int currentBuffer = 0;
    private final CameraResolutionPreset resolutionPreset;
    private int lensFacing = CameraSelector.LENS_FACING_FRONT;
    private androidx.camera.core.Camera camera;
    private ImageAnalysis imageAnalysisUseCase;
    private final ExecutorService analysisExecutor = Executors.newSingleThreadExecutor();
    private final Executor renderExecutor;
    private byte[] tempFrameData = new byte[0];
    private final HealthEventListener healthEventListener;
    private final DestroyListener destroyListener;

    // Safety state
    private final AtomicBoolean isDestroyed = new AtomicBoolean(false);
    private final AtomicBoolean isCameraStarted = new AtomicBoolean(false);
    private final AtomicBoolean unstableEventReported = new AtomicBoolean(false);
    private final AtomicBoolean legacyFallbackLogged = new AtomicBoolean(false);

    // Runtime health metrics
    private int totalFrames = 0;
    private int invalidFrames = 0;
    private int consecutiveInvalidFrames = 0;
    private int deliveredFrames = 0;
    private int timedOutFrames = 0;

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        try {
            switch (call.method) {
                case MethodStrings.startCamera:
                    startNative(result);
                    break;
                case "flip_camera":
                    flipCamera();
                    result.success(true);
                    break;
                case "toggle_flash":
                    boolean isFlash = toggleFlash();
                    result.success(isFlash);
                    break;
                case "destroy":
                    destroy();
                    result.success("SHUTDOWN");
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        } catch (Exception e) {
            Log.e(TAG, "Error in method call: " + call.method, e);
            result.error("ERROR", "Error in " + call.method + ": " + e.getMessage(), null);
        }
    }

    private boolean toggleFlash() {
        try {
            if (camera != null && camera.getCameraInfo().hasFlashUnit()) {
                boolean isFlashOn = camera.getCameraInfo().getTorchState().getValue() == TorchState.ON;
                camera.getCameraControl().enableTorch(!isFlashOn);
                return !isFlashOn;
            }
        } catch (Exception e) {
            Log.e(TAG, "Error toggling flash", e);
        }
        return false;
    }

    private void flipCamera() {
        if (isDestroyed.get()) {
            Log.w(TAG, "Trying to flip camera after destruction");
            return;
        }

        lensFacing = lensFacing == CameraSelector.LENS_FACING_FRONT
                ? CameraSelector.LENS_FACING_BACK
                : CameraSelector.LENS_FACING_FRONT;

        stopCameraUseCases();
        startNative(null);
    }

    private void startNative(MethodChannel.Result result) {
        if (isDestroyed.get()) {
            Log.w(TAG, "Trying to start camera after destruction");
            if (result != null) {
                result.error("DESTROYED", "Camera handler has been destroyed", null);
            }
            return;
        }

        if (isCameraStarted.get()) {
            Log.w(TAG, "Camera already started, restarting use cases");
            stopCameraUseCases();
        }

        unstableEventReported.set(false);
        legacyFallbackLogged.set(false);
        totalFrames = 0;
        invalidFrames = 0;
        consecutiveInvalidFrames = 0;

        future = ProcessCameraProvider.getInstance(activity);
        Executor mainExecutor = ContextCompat.getMainExecutor(activity);

        final Size cameraResolution = resolveCameraResolution();
        final int maxExpectedBytes = cameraResolution.getWidth() * cameraResolution.getHeight() * 3;

        try {
            buffers = new ByteBuffer[NUMBER_OF_BUFFERS];
            for (int i = 0; i < NUMBER_OF_BUFFERS; i++) {
                buffers[i] = ByteBuffer.allocateDirect(maxExpectedBytes);
                buffers[i].order(ByteOrder.nativeOrder());
                buffers[i].position(0);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error allocating buffers", e);
            if (result != null) {
                result.error("BUFFER_ERROR", "Failed to allocate camera buffers", e.getMessage());
            }
            return;
        }

        future.addListener(() -> {
            if (isDestroyed.get()) {
                Log.w(TAG, "Camera setup callback after destruction");
                if (result != null) {
                    result.error("DESTROYED", "Camera handler has been destroyed", null);
                }
                return;
            }

            try {
                processCameraProvider = future.get();

                ImageAnalysis.Analyzer analyzer = this::analyzeImage;

                CameraSelector cameraSelector = new CameraSelector.Builder()
                        .requireLensFacing(lensFacing)
                        .build();

                imageAnalysisUseCase = new ImageAnalysis.Builder()
                        .setTargetResolution(cameraResolution)
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .setTargetRotation(getDisplayRotation())
                        .build();

                imageAnalysisUseCase.setAnalyzer(analysisExecutor, analyzer);

                processCameraProvider.unbindAll();

                camera = processCameraProvider.bindToLifecycle(
                        (LifecycleOwner) activity,
                        cameraSelector,
                        imageAnalysisUseCase
                );

                isCameraStarted.set(true);
                Log.d(TAG, "Camera started successfully at "
                        + cameraResolution.getWidth() + "x" + cameraResolution.getHeight());

                if (result != null) {
                    result.success(textureId);
                }
            } catch (ExecutionException | InterruptedException e) {
                Log.e(TAG, "Error starting camera", e);
                if (result != null) {
                    result.error("CAMERA_ERROR", "Failed to start camera", e.getMessage());
                }
            } catch (Exception e) {
                Log.e(TAG, "Unexpected error starting camera", e);
                if (result != null) {
                    result.error("UNEXPECTED_ERROR", "Unexpected error starting camera", e.getMessage());
                }
            }
        }, mainExecutor);
    }

    private void analyzeImage(@NonNull ImageProxy image) {
        if (isDestroyed.get()) {
            image.close();
            return;
        }

        try {
            final Image rawImage = image.getImage();
            if (rawImage == null || rawImage.getFormat() != ImageFormat.YUV_420_888) {
                markInvalidFrame("invalid_image", "Image is null or format is not YUV_420_888");
                return;
            }

            final Image.Plane[] planes = rawImage.getPlanes();
            if (planes == null || planes.length < 3) {
                markInvalidFrame("invalid_planes", "YUV image does not provide 3 planes");
                return;
            }

            final int frameWidth = rawImage.getWidth();
            final int frameHeight = rawImage.getHeight();
            boolean delivered = false;
            String failureReason = "invalid_dimensions";
            String failureMessage = "Frame dimensions are invalid";

            if (frameWidth > 0 && frameHeight > 0) {
                final int chromaWidth = (frameWidth + 1) / 2;
                final int chromaHeight = (frameHeight + 1) / 2;

                if (!isPlaneReadable(planes[0], frameWidth, frameHeight)
                        || !isPlaneReadable(planes[1], chromaWidth, chromaHeight)
                        || !isPlaneReadable(planes[2], chromaWidth, chromaHeight)) {
                    failureReason = "invalid_plane_layout";
                    failureMessage = "Plane row/pixel stride layout is invalid";
                } else {
                    final int ySize = frameWidth * frameHeight;
                    final int uvSize = chromaWidth * chromaHeight;
                    final int requiredBytes = ySize + (uvSize * 2);

                    if (tempFrameData.length < requiredBytes) {
                        tempFrameData = new byte[requiredBytes];
                    }

                    final boolean copiedY = copyPlane(planes[0], frameWidth, frameHeight, tempFrameData, 0);
                    final boolean copiedV = copyPlane(planes[2], chromaWidth, chromaHeight, tempFrameData, ySize);
                    final boolean copiedU = copyPlane(planes[1], chromaWidth, chromaHeight, tempFrameData, ySize + uvSize);

                    if (!copiedY || !copiedU || !copiedV) {
                        failureReason = "copy_failure";
                        failureMessage = "Could not copy YUV planes into contiguous buffer";
                    } else {
                        final ByteBuffer frameBuffer = getFrameBuffer(requiredBytes);
                        frameBuffer.clear();
                        frameBuffer.put(tempFrameData, 0, requiredBytes);
                        frameBuffer.flip();

                        if (deepAR != null && !isDestroyed.get()) {
                            final String receiveError = deliverFrameOnRenderThread(
                                    frameBuffer,
                                    frameWidth,
                                    frameHeight,
                                    image.getImageInfo().getRotationDegrees(),
                                    1
                            );
                            if (receiveError != null) {
                                if (receiveError.toLowerCase().contains("timed out")) {
                                    // Counted as delivered so a slow render thread
                                    // doesn't trip the unstable-pipeline health
                                    // check, but tracked separately: a camera
                                    // frame that times out here never reaches
                                    // DeepAR.receiveFrame at all.
                                    timedOutFrames++;
                                    delivered = true;
                                } else {
                                    failureReason = "receive_frame_error";
                                    failureMessage = "DeepAR.receiveFrame failed: " + receiveError;
                                }
                            }
                        }
                        if ("receive_frame_error".equals(failureReason) == false) {
                            delivered = true;
                        }
                    }
                }
            }

            if (!delivered) {
                delivered = tryDeliverLegacyFrame(image, planes, frameWidth, frameHeight);
                if (delivered && legacyFallbackLogged.compareAndSet(false, true)) {
                    Log.w(TAG, "Recovered DeepAR frame using legacy YUV path. reason="
                            + failureReason + ", message=" + failureMessage);
                }
            }

            if (!delivered) {
                markInvalidFrame(failureReason, failureMessage);
                return;
            }

            markValidFrame();
            currentBuffer = (currentBuffer + 1) % NUMBER_OF_BUFFERS;
        } catch (Exception e) {
            markInvalidFrame("analyze_exception", "Analyzer exception: " + e.getMessage());
        } finally {
            image.close();
        }
    }

    private void markValidFrame() {
        totalFrames++;
        consecutiveInvalidFrames = 0;
        deliveredFrames++;
        if (deliveredFrames == 1 || deliveredFrames % 60 == 0) {
            Log.d(TAG, "camera frames handed to DeepAR: " + deliveredFrames
                    + " (receiveFrame timeouts so far: " + timedOutFrames + ")");
        }
    }

    private void markInvalidFrame(String reason, String message) {
        totalFrames++;
        invalidFrames++;
        consecutiveInvalidFrames++;

        final boolean reachedConsecutiveThreshold =
                consecutiveInvalidFrames >= MAX_CONSECUTIVE_INVALID_FRAMES;
        final boolean reachedRatioThreshold =
                totalFrames >= MIN_FRAMES_FOR_HEALTH_CHECK
                        && ((double) invalidFrames / (double) totalFrames) >= MAX_INVALID_FRAME_RATIO;

        if ((reachedConsecutiveThreshold || reachedRatioThreshold)
                && unstableEventReported.compareAndSet(false, true)) {
            final Map<String, Object> details = new HashMap<>();
            details.put("total_frames", totalFrames);
            details.put("invalid_frames", invalidFrames);
            details.put("consecutive_invalid_frames", consecutiveInvalidFrames);
            details.put("lens_facing", lensFacing == CameraSelector.LENS_FACING_FRONT ? "front" : "back");

            Log.w(TAG, "Unstable camera pipeline detected. reason=" + reason
                    + ", message=" + message
                    + ", totalFrames=" + totalFrames
                    + ", invalidFrames=" + invalidFrames);

            if (healthEventListener != null) {
                healthEventListener.onUnstablePipeline(reason, message, details);
            }
        }
    }

    private ByteBuffer getFrameBuffer(int requiredBytes) {
        if (buffers[currentBuffer] == null || buffers[currentBuffer].capacity() < requiredBytes) {
            buffers[currentBuffer] = ByteBuffer.allocateDirect(requiredBytes);
            buffers[currentBuffer].order(ByteOrder.nativeOrder());
        }
        return buffers[currentBuffer];
    }

    private boolean isPlaneReadable(Image.Plane plane, int width, int height) {
        if (plane == null || width <= 0 || height <= 0) {
            return false;
        }

        final ByteBuffer buffer = plane.getBuffer();
        final int rowStride = plane.getRowStride();
        final int pixelStride = plane.getPixelStride();

        if (buffer == null || rowStride <= 0 || pixelStride <= 0) {
            return false;
        }

        final long maxIndex = (long) (height - 1) * rowStride + (long) (width - 1) * pixelStride;
        return maxIndex >= 0 && maxIndex < buffer.limit();
    }

    private boolean copyPlane(Image.Plane plane, int width, int height, byte[] out, int outOffset) {
        if (!isPlaneReadable(plane, width, height)) {
            return false;
        }

        final ByteBuffer buffer = plane.getBuffer();
        final int rowStride = plane.getRowStride();
        final int pixelStride = plane.getPixelStride();

        int offset = outOffset;
        for (int row = 0; row < height; row++) {
            final int rowStart = row * rowStride;
            for (int col = 0; col < width; col++) {
                final int index = rowStart + (col * pixelStride);
                out[offset++] = buffer.get(index);
            }
        }
        return true;
    }

    private boolean tryDeliverLegacyFrame(
            ImageProxy image,
            Image.Plane[] planes,
            int frameWidth,
            int frameHeight
    ) {
        try {
            final ByteBuffer yBuffer = planes[0].getBuffer().duplicate();
            final ByteBuffer uBuffer = planes[1].getBuffer().duplicate();
            final ByteBuffer vBuffer = planes[2].getBuffer().duplicate();
            yBuffer.rewind();
            uBuffer.rewind();
            vBuffer.rewind();

            final int ySize = yBuffer.remaining();
            final int uSize = uBuffer.remaining();
            final int vSize = vBuffer.remaining();
            final int requiredBytes = ySize + uSize + vSize;

            if (requiredBytes <= 0 || frameWidth <= 0 || frameHeight <= 0) {
                return false;
            }

            if (tempFrameData.length < requiredBytes) {
                tempFrameData = new byte[requiredBytes];
            }

            yBuffer.get(tempFrameData, 0, ySize);
            vBuffer.get(tempFrameData, ySize, vSize);
            uBuffer.get(tempFrameData, ySize + vSize, uSize);

            final ByteBuffer frameBuffer = getFrameBuffer(requiredBytes);
            frameBuffer.clear();
            frameBuffer.put(tempFrameData, 0, requiredBytes);
            frameBuffer.flip();

            if (deepAR != null && !isDestroyed.get()) {
                final int pixelStride = Math.max(planes[1].getPixelStride(), 1);
                final String receiveError = deliverFrameOnRenderThread(
                        frameBuffer,
                        frameWidth,
                        frameHeight,
                        image.getImageInfo().getRotationDegrees(),
                        pixelStride
                );
                if (receiveError != null) {
                    if (receiveError.toLowerCase().contains("timed out")) {
                        return true;
                    }
                    return false;
                }
            }
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private String deliverFrameOnRenderThread(
            ByteBuffer frameBuffer,
            int frameWidth,
            int frameHeight,
            int rotationDegrees,
            int pixelStride
    ) {
        if (renderExecutor == null) {
            return "DeepAR render executor unavailable";
        }
        if (deepAR == null || isDestroyed.get()) {
            return "DeepAR instance unavailable";
        }

        final CountDownLatch latch = new CountDownLatch(1);
        final String[] errorHolder = new String[1];

        try {
            renderExecutor.execute(() -> {
                try {
                    if (deepAR == null || isDestroyed.get()) {
                        errorHolder[0] = "DeepAR instance unavailable";
                        return;
                    }
                    deepAR.receiveFrame(
                            frameBuffer,
                            frameWidth,
                            frameHeight,
                            rotationDegrees,
                            lensFacing == CameraSelector.LENS_FACING_FRONT,
                            DeepARImageFormat.YUV_420_888,
                            pixelStride
                    );
                } catch (Exception e) {
                    errorHolder[0] = e.getMessage();
                } finally {
                    latch.countDown();
                }
            });
        } catch (Exception e) {
            return "Failed to schedule render-thread frame delivery: " + e.getMessage();
        }

        try {
            if (!latch.await(400, TimeUnit.MILLISECONDS)) {
                return "Render-thread frame delivery timed out";
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return "Render-thread frame delivery interrupted";
        }

        return errorHolder[0];
    }

    public void destroy() {
        if (!isDestroyed.compareAndSet(false, true)) {
            Log.w(TAG, "SafeCameraXHandler already destroyed");
            return;
        }

        Log.d(TAG, "Destroying SafeCameraXHandler");
        try {
            stopCameraUseCases();

            if (!analysisExecutor.isShutdown()) {
                analysisExecutor.shutdownNow();
            }

            final DeepAR destroyedDeepAR = deepAR;
            deepAR = null;
            tempFrameData = new byte[0];

            if (buffers != null) {
                for (int i = 0; i < NUMBER_OF_BUFFERS; i++) {
                    buffers[i] = null;
                }
            }
            buffers = null;

            Log.d(TAG, "SafeCameraXHandler destroyed successfully");
            if (destroyListener != null) {
                destroyListener.onDestroyed(destroyedDeepAR);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error during destroy", e);
        }
    }

    private void stopCameraUseCases() {
        try {
            if (imageAnalysisUseCase != null) {
                imageAnalysisUseCase.clearAnalyzer();
                imageAnalysisUseCase = null;
            }
            if (processCameraProvider != null) {
                processCameraProvider.unbindAll();
            }
            camera = null;
            isCameraStarted.set(false);
        } catch (Exception e) {
            Log.e(TAG, "Error while stopping camera use cases", e);
        }
    }

    private Size resolveCameraResolution() {
        final int shortEdge = Math.min(resolutionPreset.getWidth(), resolutionPreset.getHeight());
        final int longEdge = Math.max(resolutionPreset.getWidth(), resolutionPreset.getHeight());
        return isDisplayPortrait() ? new Size(shortEdge, longEdge) : new Size(longEdge, shortEdge);
    }

    private boolean isDisplayPortrait() {
        final int rotation = getDisplayRotation();
        final DisplayMetrics dm = new DisplayMetrics();
        activity.getWindowManager().getDefaultDisplay().getMetrics(dm);
        final int width = dm.widthPixels;
        final int height = dm.heightPixels;

        final boolean naturalPortrait =
                ((rotation == Surface.ROTATION_0 || rotation == Surface.ROTATION_180) && height >= width)
                        || ((rotation == Surface.ROTATION_90 || rotation == Surface.ROTATION_270) && width >= height);

        if (naturalPortrait) {
            return rotation == Surface.ROTATION_0 || rotation == Surface.ROTATION_180;
        }
        return rotation == Surface.ROTATION_90 || rotation == Surface.ROTATION_270;
    }

    private int getDisplayRotation() {
        return activity.getWindowManager().getDefaultDisplay().getRotation();
    }
}
