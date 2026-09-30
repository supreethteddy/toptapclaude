package com.fourtech.toptap

import android.media.Image
import android.util.Log
import com.deepar.ai.DeepArPlugin
import im.zego.zegoexpress.ZegoExpressEngine
import im.zego.zegoexpress.constants.ZegoPublishChannel
import im.zego.zegoexpress.constants.ZegoVideoBufferType
import im.zego.zegoexpress.constants.ZegoVideoFrameFormat
import im.zego.zegoexpress.entity.ZegoCustomVideoCaptureConfig
import im.zego.zegoexpress.entity.ZegoVideoFrameParam

/**
 * Bridges DeepAR's processed camera output into Zego's custom video capture,
 * so a LIVE broadcast can carry DeepAR beauty/filters instead of Zego's own
 * camera feed. Lives in the app module rather than the vendored
 * third_party/deepar_flutter_plus plugin purely so it can depend on
 * zego_express_engine's native classes without adding a cross-plugin Gradle
 * dependency — the app module already has both plugins' native code on its
 * compile classpath as ordinary Flutter plugin dependencies, so this file is
 * the natural place for code that needs both.
 *
 * Android only — there is no iOS counterpart; the Dart side must never call
 * into this except behind a `Platform.isAndroid` check.
 *
 * Assumptions this relies on (documented since deepar.aar and
 * ZegoExpressEngine.jar both ship without source, so neither could be
 * confirmed by reading vendor code):
 * - DeepAR retains ownership of the `Image` passed to [onFrame] and closes
 *   it itself after notifying listeners — this class never calls
 *   `image.close()`.
 * - `sendCustomVideoCaptureRawData` copies/consumes the buffer synchronously
 *   before returning, rather than retaining the reference for later async
 *   use (the standard contract for a per-call, per-timestamp frame-push
 *   API like this one).
 */
object DeepArZegoBridge : DeepArPlugin.RawFrameListener {
    private const val TAG = "DeepArZegoBridge"
    private var started = false

    /** Starts routing DeepAR's output into Zego's stream. Call once DeepAR's
     * offscreen rendering has been enabled (see
     * DeepArControllerPlus.enableRawFrameOutput on the Dart side) and before
     * Zego starts publishing, per enableCustomVideoCapture's documented
     * "call after createEngine, before startPublishingStream" requirement. */
    @Synchronized
    fun start() {
        if (started) return
        val engine = ZegoExpressEngine.getEngine()
        if (engine == null) {
            Log.e(TAG, "start() called with no Zego engine created yet")
            return
        }
        val config = ZegoCustomVideoCaptureConfig()
        config.bufferType = ZegoVideoBufferType.RAW_DATA
        engine.enableCustomVideoCapture(true, config, ZegoPublishChannel.MAIN)
        DeepArPlugin.rawFrameListener = this
        started = true
    }

    /** Stops routing DeepAR's output and hands the camera back to Zego's own
     * capture path (the caller is responsible for actually restarting
     * Zego's normal camera preview afterwards if still LIVE). */
    @Synchronized
    fun stop() {
        if (!started) return
        DeepArPlugin.rawFrameListener = null
        val engine = ZegoExpressEngine.getEngine()
        engine?.enableCustomVideoCapture(false, null, ZegoPublishChannel.MAIN)
        started = false
    }

    override fun onFrame(image: Image) {
        if (!started) return
        val engine = ZegoExpressEngine.getEngine() ?: return
        try {
            // DeepAR's offscreen rendering only supports RGBA_8888, which is
            // a single plane — no chroma-subsampling/stride juggling across
            // multiple planes to worry about, unlike YUV formats.
            val plane = image.planes[0]
            val buffer = plane.buffer
            buffer.rewind()

            val param = ZegoVideoFrameParam()
            param.format = ZegoVideoFrameFormat.RGBA32
            param.width = image.width
            param.height = image.height
            param.rotation = 0
            param.strides[0] = plane.rowStride

            engine.sendCustomVideoCaptureRawData(
                buffer,
                buffer.remaining(),
                param,
                System.currentTimeMillis(),
                ZegoPublishChannel.MAIN
            )
        } catch (e: Exception) {
            Log.e(TAG, "onFrame failed: $e")
        }
    }
}
