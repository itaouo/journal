package com.example.journal

class AddRecipeWidgetProvider : BaseQuickAddWidgetProvider() {
    override fun iconResId(): Int = R.drawable.ic_widget_recipe

    override fun launchUri(): String = "journal://add/recipe"
}
