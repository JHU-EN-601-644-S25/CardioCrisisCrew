// app/src/main/java/com/example/cardiocrisis/ble/DeviceConnectionActivity.kt
package com.example.cardiocrisis.ble

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.Button
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.example.cardiocrisis.R

class DeviceConnectionActivity : AppCompatActivity() {
    private lateinit var device: BluetoothDevice
    private var bluetoothGatt: BluetoothGatt? = null
    
    private lateinit var statusTextView: TextView
    private lateinit var deviceNameTextView: TextView
    private lateinit var deviceAddressTextView: TextView
    private lateinit var connectionProgressBar: ProgressBar
    private lateinit var disconnectButton: Button
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_device_connection)
        
        // Get the BluetoothDevice from the intent
        device = intent.getParcelableExtra(DeviceScanActivity.EXTRA_DEVICE)
            ?: throw IllegalArgumentException("Device not found in intent")
        
        // Initialize UI components
        statusTextView = findViewById(R.id.connection_status)
        deviceNameTextView = findViewById(R.id.device_name)
        deviceAddressTextView = findViewById(R.id.device_address)
        connectionProgressBar = findViewById(R.id.connection_progress)
        disconnectButton = findViewById(R.id.disconnect_button)
        
        // Set initial device info
        deviceNameTextView.text = device.name ?: "Unknown Device"
        deviceAddressTextView.text = device.address
        statusTextView.text = "Connecting..."
        connectionProgressBar.visibility = View.VISIBLE
        
        // Set up disconnect button
        disconnectButton.setOnClickListener {
            disconnect()
            finish()
        }
        
        // Connect to the device
        connectToDevice()
    }
    
    private fun connectToDevice() {
        Log.d(TAG, "Connecting to device: ${device.address}")
        
        // Connect to GATT server on the device
        bluetoothGatt = device.connectGatt(this, false, gattCallback)
    }
    
    private fun disconnect() {
        Log.d(TAG, "Disconnecting from device")
        bluetoothGatt?.disconnect()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        bluetoothGatt?.close()
        bluetoothGatt = null
    }
    
    // Callbacks for GATT events
    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            val deviceAddress = gatt.device.address
            
            if (status == BluetoothGatt.GATT_SUCCESS) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    Log.d(TAG, "Successfully connected to $deviceAddress")
                    
                    // Update UI on the main thread
                    runOnUiThread {
                        statusTextView.text = "Connected"
                        connectionProgressBar.visibility = View.GONE
                    }
                    
                    // Discover services
                    Log.d(TAG, "Discovering services...")
                    gatt.discoverServices()
                    
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    Log.d(TAG, "Disconnected from $deviceAddress")
                    
                    // Update UI on the main thread
                    runOnUiThread {
                        statusTextView.text = "Disconnected"
                        connectionProgressBar.visibility = View.GONE
                    }
                    
                    // Close the GATT connection
                    gatt.close()
                }
            } else {
                // Handle connection error
                Log.e(TAG, "Error $status encountered for $deviceAddress! Disconnecting...")
                
                runOnUiThread {
                    statusTextView.text = "Connection error: $status"
                    connectionProgressBar.visibility = View.GONE
                }
                
                // Close the GATT connection
                gatt.close()
            }
        }
        
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                Log.d(TAG, "Services discovered")
                
                // Log all discovered services
                for (service in gatt.services) {
                    Log.d(TAG, "Service: ${service.uuid}")
                    
                    // Log characteristics for each service
                    for (characteristic in service.characteristics) {
                        Log.d(TAG, "  Characteristic: ${characteristic.uuid}")
                    }
                }
                
                runOnUiThread {
                    statusTextView.text = "Connected - Services discovered"
                }
            } else {
                Log.e(TAG, "Service discovery failed with status: $status")
                
                runOnUiThread {
                    statusTextView.text = "Service discovery failed"
                }
            }
        }
    }
    
    companion object {
        private const val TAG = "DeviceConnection"
    }
}