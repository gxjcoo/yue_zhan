package com.xingchuiye.yuezhan

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val URL_SCHEME_CHANNEL = "com.xingchuiye.yuezhan/url_scheme"
    }
    
    private var urlSchemeChannel: MethodChannel? = null
    private var initialUrl: String? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 启用透明系统栏支持（让 Flutter 完全控制系统UI）
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // 设置导航栏为完全透明（在某些设备上需要）
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
        
        // 处理启动时的URL
        handleIntent(intent)
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // URL Scheme Channel
        urlSchemeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, URL_SCHEME_CHANNEL)
        urlSchemeChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialUrl" -> {
                    result.success(initialUrl)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent?) {
        val action = intent?.action
        val data: Uri? = intent?.data
        
        if (Intent.ACTION_VIEW == action && data != null) {
            val url = data.toString()
            
            // 如果Flutter引擎还未准备好，保存URL
            if (urlSchemeChannel == null) {
                initialUrl = url
            } else {
                // 发送URL到Flutter
                urlSchemeChannel?.invokeMethod("onUrl", url)
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
    }
}

