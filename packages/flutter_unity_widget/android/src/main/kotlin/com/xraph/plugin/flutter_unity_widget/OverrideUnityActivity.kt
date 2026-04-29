package com.xraph.plugin.flutter_unity_widget

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import java.util.Objects

class OverrideUnityActivity : Activity() {
    private var mMainActivityClass: Class<*>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
            handleIntent(intent)
        }
    }

    private fun showMainActivity() {
        val target = mMainActivityClass ?: return
        val launchIntent = Intent(this, target)
        launchIntent.putExtra("showMain", true)
        launchIntent.flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP
        startActivity(launchIntent)
        finish()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
            handleIntent(intent)
        }
        setIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
            val extras = intent.extras ?: return
            val cls = extras.get("flutterActivity")
            if (cls is Class<*>) {
                mMainActivityClass = cls
            }

            if (extras.getBoolean("fullscreen", false)) {
                window.clearFlags(WindowManager.LayoutParams.FLAG_FORCE_NOT_FULLSCREEN)
                window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
            } else {
                window.addFlags(WindowManager.LayoutParams.FLAG_FORCE_NOT_FULLSCREEN)
                window.addFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS)
            }

            if (extras.containsKey("unload")) {
                UnityPlayerUtils.unload()
            }
        }
    }

    override fun onBackPressed() {
        Log.i(LOG_TAG, "onBackPressed called")
        showMainActivity()
        super.onBackPressed()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
    }

    override fun onPause() {
        super.onPause()
        UnityPlayerUtils.pause()
    }

    override fun onResume() {
        super.onResume()
        UnityPlayerUtils.resume()
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    companion object {
        var instance: OverrideUnityActivity? = null
        internal const val LOG_TAG = "OverrideUnityActivity"
    }
}
