package com.example.cardiocrisis.ble

import android.bluetooth.BluetoothDevice
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.TextView
import com.example.cardiocrisis.R

class LeDeviceListAdapter : BaseAdapter() {
    private val devices = ArrayList<BluetoothDevice>()
    private val deviceAddresses = HashSet<String>()

    fun addDevice(device: BluetoothDevice) {
        if (!deviceAddresses.contains(device.address)) {
            deviceAddresses.add(device.address)
            devices.add(device)
        }
    }

    fun getDevice(position: Int): BluetoothDevice {
        return devices[position]
    }

    fun clear() {
        devices.clear()
        deviceAddresses.clear()
    }

    override fun getCount(): Int {
        return devices.size
    }

    override fun getItem(position: Int): Any {
        return devices[position]
    }

    override fun getItemId(position: Int): Long {
        return position.toLong()
    }

    override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
        val view = convertView ?: LayoutInflater.from(parent.context)
            .inflate(R.layout.device_list_item, parent, false)

        val device = devices[position]
        val deviceName = view.findViewById<TextView>(R.id.device_name)
        val deviceAddress = view.findViewById<TextView>(R.id.device_address)

        deviceName.text = device.name ?: "Unknown Device"
        deviceAddress.text = device.address

        return view
    }
}