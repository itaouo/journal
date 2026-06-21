package com.example.journal

class AddTodoWidgetProvider : BaseQuickAddWidgetProvider() {
    override fun iconResId(): Int = R.drawable.ic_widget_todo

    override fun launchUri(): String = "journal://add/todo"
}
