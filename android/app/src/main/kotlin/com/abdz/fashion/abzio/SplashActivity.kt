package com.abdz.fashion.abzio

import android.content.Intent
import android.app.Activity
import android.os.Bundle
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.ImageView

class SplashActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_native_splash)

        val logo = findViewById<ImageView>(R.id.nativeSplashLogo)
        logo.alpha = 0f
        logo.scaleX = 0.94f
        logo.scaleY = 0.94f

        logo.animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(320L)
            .setInterpolator(AccelerateDecelerateInterpolator())
            .start()

        window.decorView.postDelayed({
            logo.animate()
                .alpha(0.98f)
                .scaleX(1.01f)
                .scaleY(1.01f)
                .setDuration(220L)
                .start()
        }, 420L)

        window.decorView.postDelayed({
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                },
            )
            overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out)
            finish()
        }, 1100L)
    }
}
