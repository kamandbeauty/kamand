package com.modir.forushgah.presentation.invoice

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.widget.Toast
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.SaveAlt

import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.modir.forushgah.core.common.InvoiceFormatting
import com.modir.forushgah.core.common.PersianNumberFormatter
import com.modir.forushgah.core.date.JalaliDateFormatter
import com.modir.forushgah.data.repository.OrderDetail
import com.modir.forushgah.domain.model.OrderKind
import com.modir.forushgah.domain.model.StoreProfile
import kotlinx.coroutines.launch

private val PreviewBg = Color(0xFFF8FAFC)
private val PreviewSlate400 = Color(0xFF94A3B8)
private val PreviewSlate500 = Color(0xFF64748B)
private val PreviewSlate700 = Color(0xFF334155)
private val PreviewSlate800 = Color(0xFF1E293B)
private val PreviewBorder = Color(0xFFE2E8F0)
private val PreviewCardGray = Color(0xFFF1F5F9)
private val AccentBlue = Color(0xFF0EA5E9)

@Composable
fun InvoicePreviewRoute(
    onBack: () -> Unit,
    onEdit: (Long) -> Unit,
    viewModel: InvoicePreviewViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    InvoicePreviewScreen(
        detail = state.detail,
        store = state.store,
        isLoading = state.isLoading,
        onBack = onBack,
        onEdit = onEdit,
    )
}

/**
 * Rubi invoice preview (Phase 3.1): the invoice paper on a light background,
 * the «ذخیره شد ✓» app bar with share, and the exact Rubi bottom actions —
 * ارسال عکس فاکتور / ارسال PDF / ذخیره فاکتور در گالری / منوی اشتراک‌گذاری /
 * ویرایش / کپی متن / بستن.
 */
@Composable
fun InvoicePreviewScreen(
    detail: OrderDetail?,
    store: StoreProfile?,
    isLoading: Boolean,
    onBack: () -> Unit,
    onEdit: (Long) -> Unit,
) {
    val snackbarHostState = remember { SnackbarHostState() }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var showShareMenu by remember { mutableStateOf(false) }

    val typeTitle = detail?.let {
        if (it.order.kind == OrderKind.PURCHASE) "فاکتور خرید" else "فاکتور فروش"
    } ?: "فاکتور"

    fun launchImageShare(saveToGallery: Boolean, pdfLike: Boolean) {
        val d = detail ?: return
        if (busy) return
        busy = true
        scope.launch {
            try {
                val bitmap = InvoiceImageExporter.renderInvoice {
                    InvoiceDocument(detail = d, store = store)
                }
                val number = d.order.orderNumber
                val text = buildShareText(d, store)
                if (saveToGallery) {
                    val ok = InvoiceImageExporter.saveToGallery(context, number, bitmap)
                    Toast.makeText(
                        context,
                        if (ok) "فاکتور در گالری ذخیره شد" else "ذخیره در گالری ناموفق بود",
                        Toast.LENGTH_SHORT,
                    ).show()
                } else {
                    val uri = InvoiceImageExporter.writePng(context, number, bitmap)
                    if (pdfLike) {
                        InvoiceImageExporter.sharePdfLike(context, uri, text, "$typeTitle $number")
                    } else {
                        InvoiceImageExporter.shareImage(context, uri, text, "$typeTitle $number")
                    }
                }
            } catch (e: Exception) {
                Toast.makeText(context, "ساخت تصویر فاکتور ناموفق بود", Toast.LENGTH_SHORT).show()
            } finally {
                busy = false
            }
        }
    }

    fun shareTextOnly() {
        val d = detail ?: return
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, buildShareText(d, store))
            putExtra(Intent.EXTRA_SUBJECT, "فاکتور ${d.order.orderNumber}")
        }
        context.startActivity(
            Intent.createChooser(intent, "اشتراک‌گذاری").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    fun copyText() {
        val d = detail ?: return
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("فاکتور", buildShareText(d, store)))
        Toast.makeText(context, "متن فاکتور کپی شد", Toast.LENGTH_SHORT).show()
    }

    Scaffold(
        containerColor = PreviewBg,
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Filled.Close, contentDescription = "بستن", tint = PreviewSlate800)
                    }
                },
                title = {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            "$typeTitle #${PersianNumberFormatter.toPersianDigits(detail?.order?.orderNumber.orEmpty())}",
                            fontWeight = FontWeight.W900,
                            fontSize = 14.sp,
                            color = PreviewSlate800,
                        )
                        Text(
                            "ذخیره شد ✓",
                            fontSize = 10.sp,
                            color = Color(0xFF059669),
                            fontWeight = FontWeight.W700,
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { showShareMenu = true }) {
                        Icon(Icons.Filled.Share, contentDescription = "اشتراک‌گذاری", tint = DocOrange)
                    }
                },
            )
        },
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            Box(modifier = Modifier.weight(1f)) {
                if (isLoading || detail == null) {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                } else {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                    ) {
                        Card(
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = Color.White),
                            elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
                            border = BorderStroke(1.dp, PreviewBorder),
                        ) {
                            InvoiceDocument(detail = detail, store = store)
                        }
                    }
                }
            }
            Surface(color = Color.White, border = BorderStroke(1.dp, PreviewBorder)) {
                Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(
                            onClick = { launchImageShare(saveToGallery = false, pdfLike = false) },
                            enabled = !busy && detail != null,
                            modifier = Modifier.weight(1f).height(48.dp),
                            shape = RoundedCornerShape(14.dp),
                            colors = ButtonDefaults.elevatedButtonColors(containerColor = DocOrange),
                        ) {
                            Icon(Icons.Outlined.Image, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("ارسال عکس فاکتور", color = Color.White, fontWeight = FontWeight.W900, fontSize = 12.sp)
                        }
                        Button(
                            onClick = { launchImageShare(saveToGallery = false, pdfLike = true) },
                            enabled = !busy && detail != null,
                            modifier = Modifier.weight(1f).height(48.dp),
                            shape = RoundedCornerShape(14.dp),
                            colors = ButtonDefaults.elevatedButtonColors(containerColor = AccentBlue),
                        ) {
                            Icon(Icons.Outlined.PictureAsPdf, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("ارسال PDF", color = Color.White, fontWeight = FontWeight.W900, fontSize = 12.sp)
                        }
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    OutlinedButton(
                        onClick = { launchImageShare(saveToGallery = true, pdfLike = false) },
                        enabled = !busy && detail != null,
                        modifier = Modifier.fillMaxWidth().height(44.dp),
                        shape = RoundedCornerShape(14.dp),
                        border = BorderStroke(1.dp, PreviewBorder),
                    ) {
                        Icon(Icons.Filled.SaveAlt, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("ذخیره فاکتور در گالری", fontWeight = FontWeight.W800, fontSize = 12.sp)
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    OutlinedButton(
                        onClick = { showShareMenu = true },
                        enabled = detail != null,
                        modifier = Modifier.fillMaxWidth().height(44.dp),
                        shape = RoundedCornerShape(14.dp),
                        border = BorderStroke(1.dp, PreviewBorder),
                    ) {
                        Icon(Icons.Outlined.Share, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("منوی اشتراک‌گذاری فاکتور", fontWeight = FontWeight.W800, fontSize = 12.sp)
                    }
                    Spacer(modifier = Modifier.height(6.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        TextButton(onClick = { detail?.let { onEdit(it.order.id) } }) {
                            Text("ویرایش", fontSize = 12.sp)
                        }
                        TextButton(onClick = { copyText() }) {
                            Text("کپی متن", fontSize = 12.sp)
                        }
                        Spacer(modifier = Modifier.weight(1f))
                        TextButton(onClick = onBack) {
                            Text("بستن", fontSize = 12.sp, fontWeight = FontWeight.W800)
                        }
                    }
                }
            }
        }
    }

    if (showShareMenu && detail != null) {
        ShareSheet(
            detail = detail,
            onShareImage = { launchImageShare(saveToGallery = false, pdfLike = false) },
            onSharePdfLike = { launchImageShare(saveToGallery = false, pdfLike = true) },
            onShareText = { shareTextOnly() },
            onDismiss = { showShareMenu = false },
        )
    }
}

/** Rubi share bottom sheet: image / PDF-like / text. */
@Composable
private fun ShareSheet(
    detail: OrderDetail,
    onShareImage: () -> Unit,
    onSharePdfLike: () -> Unit,
    onShareText: () -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val typeTitle =
        if (detail.order.kind == OrderKind.PURCHASE) "فاکتور خرید" else "فاکتور فروش"
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        dragHandle = null,
        shape = RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp),
    ) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
            Box(
                modifier = Modifier
                    .size(width = 40.dp, height = 4.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(PreviewBorder)
                    .align(Alignment.CenterHorizontally),
            )
            Spacer(modifier = Modifier.height(14.dp))
            Text("اشتراک‌گذاری فاکتور", fontWeight = FontWeight.W900, fontSize = 16.sp, color = PreviewSlate800)
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                "فاکتور #${PersianNumberFormatter.toPersianDigits(detail.order.orderNumber)} • " +
                    InvoiceFormatting.formatCurrency(detail.total),
                fontSize = 11.sp,
                color = PreviewSlate500,
            )
            Spacer(modifier = Modifier.height(16.dp))
            ShareTile(Icons.Outlined.Image, DocOrange, "ارسال عکس فاکتور", "اشتراک تصویر PNG", onShareImage)
            ShareTile(Icons.Outlined.PictureAsPdf, AccentBlue, "ارسال PDF", "اشتراک فایل فاکتور برای چاپ", onSharePdfLike)
            ShareTile(Icons.Outlined.ChatBubbleOutline, PreviewSlate700, "اشتراک متن فاکتور", "ارسال خلاصه متنی", onShareText)
            Spacer(modifier = Modifier.height(8.dp))
            TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) { Text("انصراف") }
            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

@Composable
private fun ShareTile(
    icon: ImageVector,
    color: Color,
    title: String,
    subtitle: String,
    onTap: () -> Unit,
) {
    Surface(
        onClick = {
            onTap()
        },
        shape = RoundedCornerShape(16.dp),
        color = PreviewCardGray,
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp),
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .background(color, RoundedCornerShape(12.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(22.dp))
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.W800, fontSize = 13.sp, color = PreviewSlate800)
                Text(subtitle, fontSize = 11.sp, color = PreviewSlate500)
            }
            Icon(Icons.Filled.KeyboardArrowLeft, contentDescription = null, tint = PreviewSlate400)
        }
    }
}

/** Rubi `_shareText` template, exactly. */
private fun buildShareText(detail: OrderDetail, store: StoreProfile?): String {
    val typeTitle =
        if (detail.order.kind == OrderKind.PURCHASE) "فاکتور خرید" else "فاکتور فروش"
    return buildList {
        add("$typeTitle #${PersianNumberFormatter.toPersianDigits(detail.order.orderNumber)}")
        add("فروشگاه: ${(store?.storeName ?: "").ifEmpty { "فروشگاه روبی" }}")
        add("مشتری: " + (detail.customerName ?: detail.supplierName ?: "").ifEmpty { "مشتری عمومی" })
        detail.customerMobile?.takeIf { it.isNotEmpty() }?.let { add("موبایل: $it") }
        add("تاریخ: ${JalaliDateFormatter.formatJalali(detail.order.orderDate)}")
        add("مبلغ: ${InvoiceFormatting.formatCurrency(detail.total)}")
        detail.order.notes?.takeIf { it.isNotEmpty() }?.let { add("توضیحات: $it") }
        add("")
        add("— فاکتور ساز روبی")
    }.joinToString("\n")
}
