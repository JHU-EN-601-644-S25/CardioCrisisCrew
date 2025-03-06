package com.example.cardiocrisis

import android.content.Context
import org.xmlpull.v1.XmlPullParser
import org.xmlpull.v1.XmlPullParserFactory
import java.io.InputStream

class EkgXmlParser {
    fun parse(inputStream: InputStream): EkgData {
        val readings = mutableListOf<Float>()
        var timestamp = ""
        var heartRate = 0

        val parserFactory = XmlPullParserFactory.newInstance()
        val parser = parserFactory.newPullParser()
        parser.setInput(inputStream, null)

        var eventType = parser.eventType
        var currentTag = ""

        while (eventType != XmlPullParser.END_DOCUMENT) {
            when (eventType) {
                XmlPullParser.START_TAG -> {
                    currentTag = parser.name
                }
                XmlPullParser.TEXT -> {
                    val text = parser.text.trim()
                    if (text.isNotEmpty()) {
                        when (currentTag) {
                            "reading" -> readings.add(text.toFloat())
                            "timestamp" -> timestamp = text
                            "heartRate" -> heartRate = text.toInt()
                        }
                    }
                }
            }
            eventType = parser.next()
        }

        return EkgData(readings, timestamp, heartRate)
    }
} 