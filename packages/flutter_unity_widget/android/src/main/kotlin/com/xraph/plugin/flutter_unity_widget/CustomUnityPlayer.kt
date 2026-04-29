package com.xraph.plugin.flutter_unity_widget

import android.annotation.SuppressLint
import android.app.Activity
import com.unity3d.player.IUnityPlayerLifecycleEvents
import com.unity3d.player.UnityPlayerForActivityOrService

@SuppressLint("NewApi")
class CustomUnityPlayer(
    context: Activity,
    upl: IUnityPlayerLifecycleEvents?
) : UnityPlayerForActivityOrService(context, upl)
