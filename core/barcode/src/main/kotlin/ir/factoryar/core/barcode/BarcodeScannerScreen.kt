package ir.factoryar.core.barcode

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Keyboard
import androidx.compose.material.icons.filled.NoPhotography
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import java.util.concurrent.Executors

/**
 * دیالوگ اسکن بارکد.
 * - در صورت نبود مجوز دوربین → درخواست مجوز
 * - در صورت رد مجوز یا نبود دوربین → ورود دستی بارکد (fallback)
 */
@Composable
fun BarcodeScannerDialog(
    onDismiss: () -> Unit,
    onBarcode: (String) -> Unit,
    title: String = "اسکن بارکد کالا",
) {
    val context = LocalContext.current
    var hasPermission by remember { mutableStateOf(context.hasCameraPermission()) }
    var manualMode by remember { mutableStateOf(!context.hasCameraHardware()) }
    var manualValue by remember { mutableStateOf("") }
    var detectedInfo by remember { mutableStateOf<String?>(null) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        hasPermission = granted
        if (!granted) manualMode = true
    }

    LaunchedEffect(Unit) {
        if (!hasPermission && !manualMode) {
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column {
                Text(title, style = MaterialTheme.typography.titleMedium)
                if (detectedInfo != null) {
                    Text(
                        detectedInfo!!,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }
        },
        text = {
            if (manualMode || !hasPermission) {
                ManualEntry(
                    value = manualValue,
                    onValueChange = { manualValue = it },
                    showCameraHint = !hasPermission && context.hasCameraHardware(),
                    onRequestPermission = { permissionLauncher.launch(Manifest.permission.CAMERA) },
                )
            } else {
                Column {
                    CameraPreviewBox(
                        onDetected = { value, format, engine ->
                            detectedInfo = format
                            onBarcode(value)
                        },
                    )
                    Spacer(Modifier.height(8.dp))
                    TextButton(onClick = { manualMode = true }, modifier = Modifier.fillMaxWidth()) {
                        Icon(Icons.Filled.Keyboard, null)
                        Spacer(Modifier.fillMaxWidth(0.02f))
                        Text("ورود دستی بارکد")
                    }
                }
            }
        },
        confirmButton = {
            if (manualMode || !hasPermission) {
                Button(
                    onClick = { if (manualValue.isNotBlank()) onBarcode(manualValue.trim()) },
                    enabled = manualValue.isNotBlank(),
                ) { Text("تأیید") }
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("بستن") } },
    )
}

@Composable
private fun ManualEntry(
    value: String,
    onValueChange: (String) -> Unit,
    showCameraHint: Boolean,
    onRequestPermission: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(
            Icons.Filled.NoPhotography,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.outline,
        )
        Text(
            if (showCameraHint) {
                "دسترسی به دوربین داده نشده است. می‌توانید بارکد را دستی وارد کنید."
            } else {
                "بارکد کالا را وارد کنید."
            },
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        OutlinedTextField(
            value = value,
            onValueChange = { onValueChange(it.trim()) },
            label = { Text("بارکد") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            modifier = Modifier.fillMaxWidth(),
        )
        if (showCameraHint) {
            TextButton(onClick = onRequestPermission) { Text("اجازه دسترسی به دوربین") }
        }
    }
}

@Composable
private fun CameraPreviewBox(
    onDetected: (String, String, ScanEngine) -> Unit,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val executor = remember { Executors.newSingleThreadExecutor() }
    var error by remember { mutableStateOf<String?>(null) }

    DisposableEffect(Unit) {
        onDispose { executor.shutdown() }
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(260.dp),
        contentAlignment = Alignment.Center,
    ) {
        if (error != null) {
            Text(error!!, style = MaterialTheme.typography.bodySmall)
        } else {
            AndroidView(
                modifier = Modifier.fillMaxSize(),
                factory = { ctx ->
                    val previewView = PreviewView(ctx).apply {
                        scaleType = PreviewView.ScaleType.FILL_CENTER
                    }
                    val providerFuture = ProcessCameraProvider.getInstance(ctx)
                    providerFuture.addListener({
                        runCatching {
                            val provider = providerFuture.get()
                            val preview = Preview.Builder().build().also {
                                it.setSurfaceProvider(previewView.surfaceProvider)
                            }
                            val analysis = ImageAnalysis.Builder()
                                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                                .build()
                                .also { it.setAnalyzer(executor, BarcodeAnalyzer(onDetected)) }

                            provider.unbindAll()
                            provider.bindToLifecycle(
                                lifecycleOwner,
                                CameraSelector.DEFAULT_BACK_CAMERA,
                                preview,
                                analysis,
                            )
                        }.onFailure {
                            error = "دوربین در دسترس نیست — بارکد را دستی وارد کنید."
                        }
                    }, ContextCompat.getMainExecutor(ctx))
                    previewView
                },
            )
            ScanOverlay()
        }
    }
}

/** کادر راهنمای اسکن */
@Composable
private fun ScanOverlay() {
    Canvas(Modifier.fillMaxSize()) {
        val w = size.width * 0.8f
        val h = size.height * 0.45f
        val left = (size.width - w) / 2
        val top = (size.height - h) / 2
        drawRect(
            color = Color.White.copy(alpha = 0.9f),
            topLeft = Offset(left, top),
            size = Size(w, h),
            style = Stroke(width = 3f),
        )
        drawLine(
            color = Color.Red.copy(alpha = 0.8f),
            start = Offset(left + 8, top + h / 2),
            end = Offset(left + w - 8, top + h / 2),
            strokeWidth = 2f,
        )
    }
}

private fun Context.hasCameraPermission(): Boolean =
    ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

private fun Context.hasCameraHardware(): Boolean =
    packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)
