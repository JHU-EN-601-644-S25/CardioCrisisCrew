package com.example.cardiocrisis.ble

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.Button
import android.widget.ListView
import android.widget.ProgressBar
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
            Toast.makeText(this, "Bluetooth and location permissions are required", Toast.LENGTH_SHORT).show()
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
        val requiredPermissions = arrayOf(
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.ACCESS_FINE_LOCATION
        )
        
        val missingPermissions = requiredPermissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }.toTypedArray()
        
        if (missingPermissions.isEmpty()) {
            scanLeDevice()
        } else {
            requestPermissionLauncher.launch(missingPermissions)
        }
    }
    
    private fun scanLeDevice() {
        if (!scanning) {
            // Clear the list of devices
            leDeviceListAdapter.clear()
            leDeviceListAdapter.notifyDataSetChanged()
            
            // Stop scanning after SCAN_PERIOD
            handler.postDelayed({
                if (scanning) {
                    scanning = false
                    scanButton.text = "Scan"
                    scanningProgressBar.visibility = View.GONE
                    if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED) {
                        bluetoothAdapter.bluetoothLeScanner?.stopScan(leScanCallback)
                    }
                }
            }, SCAN_PERIOD)
            
            scanning = true
            scanButton.text = "Stop"
            scanningProgressBar.visibility = View.VISIBLE
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED) {
                bluetoothAdapter.bluetoothLeScanner?.startScan(leScanCallback)
            }
        } else {
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
                leDeviceListAdapter.addDevice(result.device)
                leDeviceListAdapter.notifyDataSetChanged()
            }
        }
    }
    
    companion object {
        const val EXTRA_DEVICE = "com.example.cardiocrisis.ble.DEVICE"
    }
}