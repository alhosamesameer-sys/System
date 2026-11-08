package com.arsad.arsad

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val channelName = "arsad/local_bluetooth"
    private val permissionRequestCode = 4307
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val sppUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestConnectPermission" -> requestConnectPermission(result)
                "bondedDevices" -> {
                    if (!hasConnectPermission()) {
                        result.error("permission_required", "Bluetooth permission is required", null)
                    } else {
                        try {
                            val adapter = bluetoothAdapter()
                            val devices = adapter?.bondedDevices?.map { device ->
                                mapOf("name" to (device.name ?: "Bluetooth printer"), "address" to device.address)
                            } ?: emptyList<Map<String, String>>()
                            result.success(devices)
                        } catch (error: Exception) {
                            result.error("bluetooth_error", error.message, null)
                        }
                    }
                }
                "printBytes" -> {
                    val address = call.argument<String>("address")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (address.isNullOrBlank() || bytes == null || bytes.isEmpty()) {
                        result.error("invalid_arguments", "Printer address or print data is empty", null)
                    } else if (!hasConnectPermission()) {
                        result.error("permission_required", "Bluetooth permission is required", null)
                    } else {
                        Thread {
                            var socket: BluetoothSocket? = null
                            try {
                                val adapter = bluetoothAdapter() ?: throw IllegalStateException("Bluetooth is not available")
                                if (!adapter.isEnabled) throw IllegalStateException("Please turn on Bluetooth")
                                val device = adapter.getRemoteDevice(address)
                                socket = device.createRfcommSocketToServiceRecord(sppUuid)
                                socket.connect()
                                socket.outputStream.write(bytes)
                                socket.outputStream.flush()
                                Thread.sleep(250)
                                socket.close()
                                runOnUiThread { result.success(true) }
                            } catch (error: Exception) {
                                try { socket?.close() } catch (_: Exception) {}
                                runOnUiThread { result.error("print_failed", error.message, null) }
                            }
                        }.start()
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun bluetoothAdapter(): BluetoothAdapter? {
        val manager = getSystemService(BluetoothManager::class.java)
        return manager?.adapter
    }

    private fun hasConnectPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestConnectPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || hasConnectPermission()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_pending", "Bluetooth permission request is already pending", null)
            return
        }
        pendingPermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), permissionRequestCode)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionRequestCode) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }
}
