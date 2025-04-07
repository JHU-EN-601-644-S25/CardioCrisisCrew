// app/src/main/java/com/example/cardiocrisis/ble/DeviceScanActivity.kt
package com.example.cardiocrisis.ble

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.Button
import android.widget.ListView
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.example.cardiocrisis.R

class DeviceScanActivity : AppCompatActivity() {
    private lateinit var bluetoothAdapter: BluetoothAdapter
    private lateinit var leDeviceListAdapter: LeDeviceListAdapter
    private lateinit var deviceListView: ListView
    private lateinit var scanButton: Button
    private lateinit var scanningProgressBar: ProgressBar
    private lateinit var statusTextView: TextView

    private var scanning = false
    private val handler = Handler(Looper.getMainLooper())

    // Stops scanning after 10 seconds
    private val SCAN_PERIOD: Long = 10000

    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val allPermissionsGranted = permissions.entries.all { it.value }
        if (allPermissionsGranted) {
            scanLeDevice()
        } else {
            // Show which permissions are still missing
            val deniedPermissions = permissions.filter { !it.value }.keys.joinToString(", ") {
                it.split(".").last()
            }
            Toast.makeText(
                this,
                "Missing permissions: $deniedPermissions. These are required for BLE scanning.",
                Toast.LENGTH_LONG
            ).show()
        }
    }

    private val requestBluetoothEnable = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            scanLeDevice()
        } else {
            Toast.makeText(this, "Bluetooth is required for device scanning", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_device_scan)

        // Initializes Bluetooth adapter
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter

        // Ensures Bluetooth is available on the device
        if (bluetoothAdapter == null) {
            Log.e("BLEScan", "Bluetooth not supported on this device")
            Toast.makeText(this, "Bluetooth not supported on this device", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        // Log Bluetooth state
        logBluetoothState()

        leDeviceListAdapter = LeDeviceListAdapter()
        deviceListView = findViewById(R.id.device_list)
        deviceListView.adapter = leDeviceListAdapter
        scanButton = findViewById(R.id.scan_button)
        scanningProgressBar = findViewById(R.id.scanning_progress)
        statusTextView = findViewById(R.id.status_text)
        statusTextView.text = "Ready to scan"

        scanButton.setOnClickListener {
            if (!scanning) {
                checkPermissionsAndScan()
            } else {
                stopScan()
            }
        }

        deviceListView.setOnItemClickListener { _, _, position, _ ->
            val device = leDeviceListAdapter.getDevice(position)
            
            // Stop scanning if we're still scanning
            if (scanning) {
                stopScan()
            }
            
            // Show connecting status
            statusTextView.text = "Connecting to ${device.name ?: "Unknown Device"}..."
            
            // Start the DeviceConnectionActivity with the selected device
            val intent = Intent(this, DeviceConnectionActivity::class.java)
            intent.putExtra(EXTRA_DEVICE, device)
            startActivity(intent)
        }
    }

    override fun onResume() {
        super.onResume()
        // Ensures Bluetooth is enabled
        if (!bluetoothAdapter.isEnabled) {
            val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
            requestBluetoothEnable.launch(enableBtIntent)
        }
    }

    override fun onPause() {
        super.onPause()
        if (scanning) {
            stopScan()
        }
    }

    private fun checkPermissionsAndScan() {
        val requiredPermissions = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        } else {
            arrayOf(
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        }

        val missingPermissions = requiredPermissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }.toTypedArray()

        if (missingPermissions.isEmpty()) {
            scanLeDevice()
        } else {
            Toast.makeText(
                this,
                "Bluetooth and location permissions are required for device scanning",
                Toast.LENGTH_LONG
            ).show()
            requestPermissionLauncher.launch(missingPermissions)
        }
    }

    private fun scanLeDevice() {
        if (!scanning) {
            Log.d("BLEScan", "Starting BLE scan...")
            statusTextView.text = "Starting scan..."

            // Clear the list of devices
            leDeviceListAdapter.clear()
            leDeviceListAdapter.notifyDataSetChanged()

            // Start scanning and show progress
            scanning = true
            scanButton.text = "Stop"
            scanningProgressBar.visibility = View.VISIBLE

            // Check if bluetoothAdapter is enabled
            if (!bluetoothAdapter.isEnabled) {
                Log.e("BLEScan", "Bluetooth is not enabled")
                statusTextView.text = "Bluetooth is not enabled"
                return
            }

            // Start scanning
            val scanner = bluetoothAdapter.bluetoothLeScanner
            if (scanner != null) {
                val scanSettings = ScanSettings.Builder()
                    .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY) // Use high performance mode
                    .build()

                scanner.startScan(null, scanSettings, leScanCallback)
                Log.d("BLEScan", "Successfully started BLE scan")
                statusTextView.text = "Scanning for devices..."

                // Set a timeout for the scan
                handler.postDelayed({
                    if (scanning) {
                        Log.d("BLEScan", "Scan timeout reached")
                        stopScan()
                    }
                }, SCAN_PERIOD) // Use your defined SCAN_PERIOD
            } else {
                Log.e("BLEScan", "BluetoothLeScanner is null")
                statusTextView.text = "Bluetooth scanner unavailable"
                scanning = false
                scanButton.text = "Scan"
                scanningProgressBar.visibility = View.GONE
            }
        } else {
            stopScan()
        }
    }

    private fun stopScan() {
        Log.d("BLEScan", "Stopping scan by user request")
        scanning = false
        scanButton.text = "Scan"
        scanningProgressBar.visibility = View.GONE
        statusTextView.text = "Scan stopped"

        bluetoothAdapter.bluetoothLeScanner?.stopScan(leScanCallback)
        Log.d("BLEScan", "Scan stopped successfully")
    }

    // ScanCallback for BLE device discovery
    private val leScanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            super.onScanResult(callbackType, result)
            val device = result.device
            val deviceName = device.name ?: "Unknown"
            val deviceAddress = device.address
            val rssi = result.rssi

            Log.d("BLEScan", "Found device: $deviceName ($deviceAddress) with RSSI: $rssi")

            runOnUiThread {
                leDeviceListAdapter.addDevice(device)
                leDeviceListAdapter.notifyDataSetChanged()
                statusTextView.text = "Scanning... (${leDeviceListAdapter.count} found)"
            }
        }

        override fun onBatchScanResults(results: List<ScanResult>) {
            super.onBatchScanResults(results)
            Log.d("BLEScan", "Batch scan results: ${results.size} devices")

            runOnUiThread {
                for (result in results) {
                    leDeviceListAdapter.addDevice(result.device)
                }
                leDeviceListAdapter.notifyDataSetChanged()
                statusTextView.text = "Scanning... (${leDeviceListAdapter.count} found)"
            }
        }

        override fun onScanFailed(errorCode: Int) {
            super.onScanFailed(errorCode)
            val errorMessage = when (errorCode) {
                ScanCallback.SCAN_FAILED_ALREADY_STARTED -> "Scan already started"
                ScanCallback.SCAN_FAILED_APPLICATION_REGISTRATION_FAILED -> "App registration failed"
                ScanCallback.SCAN_FAILED_FEATURE_UNSUPPORTED -> "BLE not supported"
                ScanCallback.SCAN_FAILED_INTERNAL_ERROR -> "Internal error"
                else -> "Error code: $errorCode"
            }

            Log.e("BLEScan", "Scan failed: $errorMessage")

            runOnUiThread {
                scanning = false
                scanButton.text = "Scan"
                scanningProgressBar.visibility = View.GONE
                statusTextView.text = "Scan failed: $errorMessage"
            }
        }
    }

    private fun logBluetoothState() {
        Log.d("BLEScan", "Checking Bluetooth state")

        // Check if Bluetooth is supported
        if (bluetoothAdapter == null) {
            Log.e("BLEScan", "Bluetooth not supported on this device")
            return
        }

        // Check if Bluetooth is enabled
        if (!bluetoothAdapter.isEnabled) {
            Log.e("BLEScan", "Bluetooth is disabled")
        } else {
            Log.d("BLEScan", "Bluetooth is enabled")
        }

        // Check if BLE is supported
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)) {
            Log.e("BLEScan", "BLE not supported on this device")
        } else {
            Log.d("BLEScan", "BLE is supported")
        }

        // Check if scanning is supported
        if (bluetoothAdapter.isEnabled && bluetoothAdapter.bluetoothLeScanner == null) {
            Log.e("BLEScan", "BluetoothLeScanner is null despite Bluetooth being enabled")
        } else if (bluetoothAdapter.isEnabled) {
            Log.d("BLEScan", "BluetoothLeScanner is available")
        }
    }

    companion object {
        const val EXTRA_DEVICE = "com.example.cardiocrisis.ble.DEVICE"
    }
}