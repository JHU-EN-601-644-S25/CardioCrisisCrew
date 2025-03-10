package com.example.cardiocrisis

data class User(
    val username: String,
    val password: String,
    val role: String = "USER"
) 