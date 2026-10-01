package com.darling.cloud

import android.content.Context
import android.os.Bundle
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
    private lateinit var webView: WebView
    private lateinit var urlInput: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val prefs = getSharedPreferences("config", Context.MODE_PRIVATE)
        val savedUrl = prefs.getString("server_url", "")

        if (savedUrl.isNullOrEmpty()) {
            // 显示地址输入页
            showSetupPage()
        } else {
            // 直接加载 WebView
            showWebView(savedUrl)
        }
    }

    private fun showSetupPage() {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(40, 100, 40, 40)
        }

        urlInput = EditText(this).apply {
            hint = "输入网盘地址，例如 http://23.147.68.16:17817"
            setText("http://")
        }

        val btn = Button(this).apply {
            text = "连接"
            setOnClickListener {
                val url = urlInput.text.toString().trim()
                getSharedPreferences("config", Context.MODE_PRIVATE)
                    .edit().putString("server_url", url).apply()
                showWebView(url)
            }
        }

        layout.addView(urlInput)
        layout.addView(btn)
        setContentView(layout)
    }

    private fun showWebView(url: String) {
        webView = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.setSupportZoom(true)
            webViewClient = WebViewClient()
            loadUrl(url)
        }
        setContentView(webView)
    }

    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }
}
