package com.example.cardiocrisis

import android.content.Intent
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.ImageButton
import android.widget.PopupMenu
import android.widget.Spinner
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.example.cardiocrisis.ble.DeviceScanActivity
import java.text.SimpleDateFormat
import java.util.Locale
import kotlin.math.sin
import kotlin.math.PI

class MainActivity : AppCompatActivity() {
    
    private var isSignedIn = false
    private lateinit var ekgData: EkgData
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val ekgView = findViewById<EkgView>(R.id.ekgView)
        setupUserButton()
        setupExportButton()
        setupBleScanButton()

        loadEkgData()

        ekgView.updateData(ekgData.readings)

        updateTimestamp()
    }

    private fun loadEkgData() {
        val inputStream = resources.openRawResource(R.raw.ekg_data)
        ekgData = EkgXmlParser().parse(inputStream)
    }

    private fun updateTimestamp() {
        val timestampText = findViewById<TextView>(R.id.timestampText)
        val parser = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
        val formatter = SimpleDateFormat("h:mm a", Locale.getDefault())
        val date = parser.parse(ekgData.timestamp)
        timestampText.text = "Last Updated: ${formatter.format(date)}"
    }

    private fun setupUserButton() {
        val userButton = findViewById<ImageButton>(R.id.userButton)
        userButton.setOnClickListener { view ->
            val popup = PopupMenu(this, view)
            popup.menuInflater.inflate(R.menu.user_menu, popup.menu)
            
            // Update menu item based on sign-in state
            popup.menu.findItem(R.id.action_sign_in_out).setTitle(
                if (isSignedIn) R.string.sign_out else R.string.sign_in
            )
            
            popup.setOnMenuItemClickListener { menuItem ->
                when (menuItem.itemId) {
                    R.id.action_sign_in_out -> {
                        isSignedIn = !isSignedIn
                        // Handle sign in/out logic here
                        true
                    }
                    else -> false
                }
            }
            popup.show()
        }
    }

    private fun setupExportButton() {
        val exportButton = findViewById<Button>(R.id.exportButton)
        exportButton.setOnClickListener {
            showExportDialog()
        }
    }

    private fun setupBleScanButton() {
        val bleScanButton = findViewById<Button>(R.id.ble_scan_button)
        bleScanButton.setOnClickListener {
            val intent = Intent(this, DeviceScanActivity::class.java)
            startActivity(intent)
        }
    }

    private fun showExportDialog() {
        val dialogView = layoutInflater.inflate(R.layout.dialog_export, null)
        val spinner = dialogView.findViewById<Spinner>(R.id.hospitalSpinner)

        // EX hospital list - replace with real hospital list at some point
        val hospitals = arrayOf("General Hospital", "Baltimore City Medical Center", "Johns Hopkins Hospital")
        val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, hospitals)
        spinner.adapter = adapter

        val dialog = AlertDialog.Builder(this)
            .setView(dialogView)
            .create()

        dialogView.findViewById<Button>(R.id.cancelButton).setOnClickListener {
            dialog.dismiss()
        }

        dialogView.findViewById<Button>(R.id.sendButton).setOnClickListener {
            val selectedHospital = spinner.selectedItem as String
            // Add export logic here
            dialog.dismiss()
        }

        dialog.show()
    }
} 