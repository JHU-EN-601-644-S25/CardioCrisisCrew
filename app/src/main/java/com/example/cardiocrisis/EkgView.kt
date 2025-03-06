package com.example.cardiocrisis

import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.view.View
import androidx.core.content.ContextCompat

class EkgView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val cardPaint = Paint().apply {
        color = ContextCompat.getColor(context, R.color.card_background)
        setShadowLayer(12f, 0f, 4f, Color.argb(50, 0, 0, 0))
    }

    private val ekgPaint = Paint().apply {
        color = ContextCompat.getColor(context, R.color.ekg_line)
        strokeWidth = 3f
        style = Paint.Style.STROKE
        isAntiAlias = true
    }

    private val gridPaint = Paint().apply {
        color = ContextCompat.getColor(context, R.color.grid_line)
        strokeWidth = 1f
        style = Paint.Style.STROKE
        alpha = 50
    }

    private val path = Path()
    private var data: List<Float> = listOf()
    private val cornerRadius = 24f
    private val cardRect = RectF()
    
    init {
        setLayerType(LAYER_TYPE_SOFTWARE, null) // Enable software rendering for shadow
    }
    
    fun updateData(newData: List<Float>) {
        data = newData
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        cardRect.set(
            paddingLeft.toFloat(),
            paddingTop.toFloat(),
            (width - paddingRight).toFloat(),
            (height - paddingBottom).toFloat()
        )
        canvas.drawRoundRect(cardRect, cornerRadius, cornerRadius, cardPaint)

        val clipPath = Path()
        clipPath.addRoundRect(cardRect, cornerRadius, cornerRadius, Path.Direction.CW)
        canvas.clipPath(clipPath)

        val gridSize = 50f
        for (i in 0..(width/gridSize).toInt()) {
            canvas.drawLine(i * gridSize, 0f, i * gridSize, height.toFloat(), gridPaint)
        }
        for (i in 0..(height/gridSize).toInt()) {
            canvas.drawLine(0f, i * gridSize, width.toFloat(), i * gridSize, gridPaint)
        }

        if (data.isNotEmpty()) {
            path.reset()
            val xStep = width.toFloat() / (data.size - 1)
            val yScale = height / 2f
            val yOffset = height / 2f

            path.moveTo(0f, yOffset - (data[0] * yScale))
            
            for (i in 1 until data.size) {
                path.lineTo(i * xStep, yOffset - (data[i] * yScale))
            }
            
            canvas.drawPath(path, ekgPaint)
        }
    }
} 