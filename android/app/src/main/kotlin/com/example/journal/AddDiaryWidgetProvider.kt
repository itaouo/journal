package com.example.journal

class AddDiaryWidgetProvider : BaseQuickAddWidgetProvider() {
    override fun iconResId(): Int = R.drawable.ic_widget_diary

    override fun launchUri(): String = "journal://add/diary"
}
