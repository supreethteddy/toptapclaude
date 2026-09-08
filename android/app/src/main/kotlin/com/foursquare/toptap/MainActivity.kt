package com.fourtech.toptap

import com.baseflow.permissionhandler.PermissionHandlerPlugin
import com.retrytech.retrytech_plugin.RetrytechPlugin
import com.ryanheise.just_audio.JustAudioPlugin
import com.tekartik.sqflite.SqflitePlugin
import im.zego.zego_express_engine.ZegoExpressEnginePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.pathprovider.PathProviderPlugin
import io.flutter.plugins.videoplayer.VideoPlayerPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(PathProviderPlugin())
        flutterEngine.plugins.add(SqflitePlugin())
        flutterEngine.plugins.add(VideoPlayerPlugin())
        flutterEngine.plugins.add(ZegoExpressEnginePlugin())
        flutterEngine.plugins.add(PermissionHandlerPlugin())
        flutterEngine.plugins.add(JustAudioPlugin())
        flutterEngine.plugins.add(RetrytechPlugin())
        // Original Shortzz camera uses deepar_flutter_plus plugin (auto-registered)
        // and retrytech_plugin (registered above)
    }
}
