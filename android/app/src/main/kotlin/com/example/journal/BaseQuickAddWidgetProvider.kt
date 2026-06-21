package com.example.journal

import android.appwidget.AppWidgetManager
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

abstract class BaseQuickAddWidgetProvider : HomeWidgetProvider() {
    abstract fun iconResId(): Int
    abstract fun launchUri(): String

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_quick_add).apply {
            applyCircleSize(context, appWidgetManager, appWidgetId)
            setImageViewResource(R.id.widget_icon, iconResId())
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse(launchUri()),
            )
            setOnClickPendingIntent(R.id.widget_root, pendingIntent)
        }
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun RemoteViews.applyCircleSize(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val sizeDp = resolveSquareSizeDp(context, appWidgetManager, appWidgetId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            setViewLayoutWidth(R.id.widget_circle, sizeDp.toFloat(), TypedValue.COMPLEX_UNIT_DIP)
            setViewLayoutHeight(R.id.widget_circle, sizeDp.toFloat(), TypedValue.COMPLEX_UNIT_DIP)
        }
    }

    private fun resolveSquareSizeDp(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ): Int {
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            .takeIf { it > 0 }
            ?: options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            .takeIf { it > 0 }
            ?: options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)

        val fallback = context.resources.getDimensionPixelSize(R.dimen.widget_circle_size).let { px ->
            (px / context.resources.displayMetrics.density).toInt()
        }

        if (width <= 0 || height <= 0) {
            return fallback
        }

        return minOf(width, height)
    }
}
