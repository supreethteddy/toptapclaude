package com.fourtech.toptap

import android.media.Image
import android.os.SystemClock
import android.util.Log
import com.deepar.ai.DeepArPlugin
import im.zego.zego_express_engine.IZegoFlutterCustomVideoCaptureHandler
import im.zego.zego_express_engine.ZGFlutterPublishChannel
import im.zego.zego_express_engine.ZGFlutterTrafficControlInfo
import im.zego.zego_express_engine.ZGFlutterVideoFrameFormat
import im.zego.zego_express_engine.ZGFlutterVideoFrameParam
import im.zego.zego_express_engine.ZegoCustomVideoCaptureManager
import im.zego.zegoexpress.ZegoExpressEngine
import im.zego.zegoexpress.constants.ZegoPublishChannel
import im.zego.zegoexpress.constants.ZegoVideoBufferType
import im.zego.zegoexpress.constants.ZegoVideoMirrorMode
import im.zego.zegoexpress.entity.ZegoCustomVideoCaptureConfig

/**
 * Bridges DeepAR's processed camera output into Zego's custom video capture,
 * so a LIVE broadcast (and the host's own preview) carries DeepAR filters
 * instead of Zego's own camera feed. Lives in the app module rather than the
 * vendored third_party/deepar_flutter_plus plugin purely so it can depend on
 * zego_express_engine's native classes without a cross-plugin Gradle
 * dependency.
 *
 * Android only — no iOS counterpart; the Dart side must only call this behind
 * a `Platform.isAndroid` check.
 *
 * Why this goes through the Zego *Flutter plugin's* ZegoCustomVideoCaptureManager
 * rather than calling the engine directly: the plugin's own Dart
 * `enableCustomVideoCapture` does exactly three native things (see
 * ZegoExpressEngineMethodHandler.enableCustomVideoCapture in the plugin
 * source) — registers the manager as the engine's IZegoCustomVideoCaptureHandler,
 * enables custom capture, and sets NO_MIRROR. The SDK only treats pushed
 * frames as valid once it has delivered `onStart` to that handler
 * ("Only those video data that are sent to the SDK after this callback is
 * received are valid" — IZegoFlutterCustomVideoCaptureHandler.onStart). An
 * earlier version of this file enabled capture directly on the engine with
 * no handler at all: confirmed on-device, Zego then rendered exactly one of
 * the pushed frames and ignored every later one, even though this bridge
 * was pushing ~48 fps of verifiably changing frames (per-frame fingerprint
 * log below). [start] now mirrors the plugin's wiring 1:1 and [onFrame]
 * only pushes between onStart and onStop.
 *
 * Assumptions (deepar.aar and ZegoExpressEngine ship without source):
 * - DeepAR owns the `Image` passed to [onFrame] and closes it itself after
 *   notifying listeners — this class never calls `image.close()`.
 * - `sendRawData` copies the buffer synchronously before returning (Zego's
 *   docs state this for sendCustomVideoCaptureRawData).
 */
object DeepArZegoBridge : DeepArPlugin.RawFrameListener,
    IZegoFlutterCustomVideoCaptureHandler {

    private const val TAG = "DeepArZegoBridge"

    @Volatile private var started = false
    /** True between Zego's onStart and onStop for the main channel. */
    @Volatile private var capturing = false
    private var pushedFrames = 0L
    private val param = ZGFlutterVideoFrameParam()

    // DeepAR's offscreen renderer fires frameAvailable as fast as the camera
    // delivers frames (~45-50fps on this device, unthrottled) regardless of
    // Zego's own publish fps -- Zego's docs require the two to match, and
    // pushing well above the configured rate is wasted copy/encode work at
    // best. [onFrame] drops any frame that arrives before this interval has
    // elapsed since the last one actually pushed; the Dart side sets Zego's
    // own encode fps to the same number via ZegoVideoConfig (see
    // create_live_stream_screen_controller.dart's setVideoConfig call).
    private var minFrameIntervalMs = 1000L / 24L
    private var lastPushUptimeMs = 0L

    /** Starts routing DeepAR's output into Zego. Call once DeepAR's offscreen
     * rendering has been enabled (DeepArControllerPlus.enableRawFrameOutput)
     * and BEFORE Zego's preview/publish is (re)started — Zego only applies
     * custom capture to a preview/publish started after it was enabled.
     * [fps] must match whatever the Dart side just set Zego's own publish
     * video config to. */
    @Synchronized
    fun start(fps: Int = 24) {
        if (started) return
        minFrameIntervalMs = 1000L / fps.coerceAtLeast(1).toLong()
        lastPushUptimeMs = 0L
        val engine = ZegoExpressEngine.getEngine()
        if (engine == null) {
            Log.e(TAG, "start() called with no Zego engine created yet")
            return
        }
        val manager = ZegoCustomVideoCaptureManager.getInstance()
        manager.setCustomVideoCaptureHandler(this)
        engine.setCustomVideoCaptureHandler(manager)
        val config = ZegoCustomVideoCaptureConfig()
        config.bufferType = ZegoVideoBufferType.RAW_DATA
        engine.enableCustomVideoCapture(true, config, ZegoPublishChannel.MAIN)
        // Same as the plugin: DeepAR's output is already oriented for display.
        engine.setVideoMirrorMode(ZegoVideoMirrorMode.NO_MIRROR, ZegoPublishChannel.MAIN)
        DeepArPlugin.rawFrameListener = this
        pushedFrames = 0L
        started = true
        Log.d(TAG, "started: custom capture enabled via plugin manager, awaiting onStart")
    }

    /** Stops routing DeepAR's output and hands Zego back its own capture
     * (the caller restarts Zego's camera/preview afterwards). Mirrors the
     * plugin's own disable path so Zego is left exactly as the plugin
     * would leave it. */
    @Synchronized
    fun stop() {
        if (!started) return
        DeepArPlugin.rawFrameListener = null
        capturing = false
        val engine = ZegoExpressEngine.getEngine()
        engine?.enableCustomVideoCapture(false, null, ZegoPublishChannel.MAIN)
        engine?.setCustomVideoCaptureHandler(null)
        engine?.setVideoMirrorMode(ZegoVideoMirrorMode.ONLY_PREVIEW_MIRROR, ZegoPublishChannel.MAIN)
        ZegoCustomVideoCaptureManager.getInstance().setCustomVideoCaptureHandler(null)
        started = false
        Log.d(TAG, "stopped: custom capture disabled, pushed $pushedFrames frames total")
    }

    // ---- IZegoFlutterCustomVideoCaptureHandler ----

    override fun onStart(channel: ZGFlutterPublishChannel) {
        capturing = true
        Log.d(TAG, "Zego custom capture onStart ($channel)")
    }

    override fun onStop(channel: ZGFlutterPublishChannel) {
        capturing = false
        Log.d(TAG, "Zego custom capture onStop ($channel)")
    }

    override fun onEncodedDataTrafficControl(
        trafficControlInfo: ZGFlutterTrafficControlInfo,
        channel: ZGFlutterPublishChannel
    ) {
        // Raw-data capture: the SDK encodes, so there is nothing to adjust here.
    }

    // ---- DeepArPlugin.RawFrameListener ----

    override fun onFrame(image: Image?) {
        // DeepAR's interface declares this non-null but has been observed
        // passing null during state transitions; Kotlin's generated null
        // check would otherwise throw before the try below is reached.
        if (image == null || !started || !capturing) return
        val now = SystemClock.elapsedRealtime()
        if (now - lastPushUptimeMs < minFrameIntervalMs) return
        lastPushUptimeMs = now
        try {
            // DeepAR's offscreen rendering only supports RGBA_8888: a single
            // plane, no chroma-subsampling/stride juggling.
            val plane = image.planes[0]
            val buffer = plane.buffer
            buffer.rewind()

            param.format = ZGFlutterVideoFrameFormat.RGBA32
            param.width = image.width
            param.height = image.height
            param.rotation = 0
            param.strides[0] = plane.rowStride

            ZegoCustomVideoCaptureManager.getInstance().sendRawData(
                buffer,
                buffer.remaining(),
                param,
                // Monotonic, boot-relative clock, matching Zego's own capture
                // timestamps on Android.
                SystemClock.elapsedRealtime(),
                ZGFlutterPublishChannel.MAIN
            )

            // Throttled native progress log with a cheap content fingerprint
            // (256 bytes sampled across the frame). The test device hides the
            // app's Flutter logcat output, so this is the only direct evidence
            // that real, changing frames reach Zego.
            pushedFrames++
            if (pushedFrames == 1L || pushedFrames % 60L == 0L) {
                val n = buffer.remaining()
                val step = maxOf(1, n / 256)
                var sum = 0L
                var i = 0
                while (i < n) { sum += (buffer.get(i).toInt() and 0xff); i += step }
                Log.d(TAG, "pushed $pushedFrames frames to Zego " +
                    "(${image.width}x${image.height}, rowStride=${plane.rowStride}, " +
                    "fingerprint=$sum)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "onFrame failed: $e")
        }
    }
}
