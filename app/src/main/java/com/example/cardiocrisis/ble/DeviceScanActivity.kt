package com.example.cardiocrisis.ble

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
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
            Toast.makeText(this, "Bluetooth not supported on this device", Toast.LENGTH_SHORT).show()
            finish()
            return
        }
        
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
                scanning = false
                scanButton.text = "Scan"
                scanningProgressBar.visibility = View.GONE
                if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED) {
                    bluetoothAdapter.bluetoothLeScanner?.stopScan(leScanCallback)
                }
            }
        }
        
        deviceListView.setOnItemClickListener { _, _, position, _ ->
            val device = leDeviceListAdapter.getDevice(position)
            val intent = Intent()
            intent.putExtra(EXTRA_DEVICE, device)
            setResult(Activity.RESULT_OK, intent)
            finish()
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
            scanning = false
            scanButton.text = "Scan"
            scanningProgressBar.visibility = View.GONE
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED) {
                bluetoothAdapter.bluetoothLeScanner?.stopScan(leScanCallback)
            }
        }
    }
    
    private fun checkPermissionsAndScan() {
        // Different permission sets based on Android version
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
            // Show a toast explaining why we need these permissions
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
            // Check permissions again just to be safe
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S &&
                (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED ||
                 ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED)) {
                Toast.makeText(this, "Bluetooth permissions not granted", Toast.LENGTH_SHORT).show()
                return
            } else if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                Toast.makeText(this, "Location permission not granted", Toast.LENGTH_SHORT).show()
                return
            }
            
            // Clear the list of devices
            leDeviceListAdapter.clear()
            leDeviceListAdapter.notifyDataSetChanged()
            
            // Start scanning and show progress
            scanning = true
            scanButton.text = "Stop"
            scanningProgressBar.visibility = View.VISIBLE
            
            // Use a longer scan period (15 seconds instead of default)
            handler.postDelayed({
                if (scanning) {
                    scanning = false
                    scanButton.text = "Scan"
                    scanningProgressBar.visibility = View.GONE
                    if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED) {
                        bluetoothAdapter.bluetoothLeScanner?.stopScan(leScanCallback)
                        Toast.makeText(this, "Scan complete", Toast.LENGTH_SHORT).show()
                    }
                }
            }, 15000) // 15 seconds
            
            // Configure scan settings for better results
            val scanSettings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY) // Use highest power/performance
                .build()
                
            // Start the scan with our settings
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED) {
                bluetoothAdapter.bluetoothLeScanner?.startScan(null, scanSettings, leScanCallback)
                Toast.makeText(this, "Scanning for devices...", Toast.LENGTH_SHORT).show()
            }
        } else {
            // Stop scanning
            scanning = false
            scanButton.text = "Scan"
            scanningProgressBar.visibility = View.GONE
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED) {
                bluetoothAdapter.bluetoothLeScanner?.stopScan(leScanCallback)
            }
        }
    }
    
    // Device scan callback
    private val leScanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            super.onScanResult(callbackType, result)
            runOnUiThread {
                val device = result.device
                // Log device found
                Log.d("BLEScan", "Found device: ${device.address} - ${device.name ?: "Unknown"}")
                
                // Add to adapter and update UI
                leDeviceListAdapter.addDevice(device)
                leDeviceListAdapter.notifyDataSetChanged()
            }
        }

        override fun onScanFailed(errorCode: Int) {
            super.onScanFailed(errorCode)
            runOnUiThread {
                scanning = false
                scanButton.text = "Scan"
                scanningProgressBar.visibility = View.GONE
                
                // Show error message based on error code
                val errorMessage = when (errorCode) {
                    ScanCallback.SCAN_FAILED_ALREADY_STARTED -> "Scan already started"
                    ScanCallback.SCAN_FAILED_APPLICATION_REGISTRATION_FAILED -> "App registration failed"
                    ScanCallback.SCAN_FAILED_FEATURE_UNSUPPORTED -> "BLE not supported"
                    ScanCallback.SCAN_FAILED_INTERNAL_ERROR -> "Internal error"
                    else -> "Error code: $errorCode"
                }
                Toast.makeText(applicationContext, "Scan failed: $errorMessage", Toast.LENGTH_LONG).show()
                Log.e("BLEScan", "Scan failed: $errorMessage")
            }
        }
    }
    
    companion object {
        const val EXTRA_DEVICE = "com.example.cardiocrisis.ble.DEVICE"
    }
}