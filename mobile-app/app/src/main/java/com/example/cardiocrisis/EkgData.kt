package com.example.cardiocrisis

data class EkgData(
    val readings: List<Float>,
    val timestamp: String,
    val heartRate: Int
) 