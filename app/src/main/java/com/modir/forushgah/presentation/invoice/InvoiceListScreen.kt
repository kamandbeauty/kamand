package com.modir.forushgah.presentation.invoice

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.ReceiptLong
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.modir.forushgah.core.common.InvoiceFormatting
import com.modir.forushgah.core.common.PersianNumberFormatter
import com.modir.forushgah.core.date.JalaliDateFormatter

// Rubi list palette (hardcoded per-screen in the reference app too).
private val ListOrange = Color(0xFFF97316)
private val ListCream = Color(0xFFFFFBEB)
private val ListSlate400 = Color(0xFF94A3B8)
private val ListSlate500 = Color(0xFF64748B)
private val ListSlate800 = Color(0xFF1E293B)
private val ListBorder = Color(0xFFE2E8F0)

private val PaidGreen = Color(0xFF059669)
private val PartialAmber = Color(0xFFD97706)
private val UnpaidRose = Color(0xFFE11D48)

@Composable
fun InvoiceListRoute(
    onInvoiceClick: (Long) -> Unit,
    onAddInvoice: () -> Unit,
    onReturnsClick: () -> Unit,
    viewModel: InvoiceListViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    var deleting by remember { mutableStateOf<InvoiceRowUi?>(null) }

    LaunchedEffect(state.message) {
        state.message?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.onMessageShown()
        }
    }

    InvoiceListScreen(
        state = state,
        snackbarHostState = snackbarHostState,
        deleting = deleting,
        onInvoiceClick = onInvoiceClick,
        onAddInvoice = onAddInvoice,
        onReturnsClick = onReturnsClick,
        onCopy = viewModel::copyInvoice,
        onDeleteRequest = { deleting = it },
        onDeleteConfirmed = { row ->
            row?.let { viewModel.deleteInvoice(it.id) }
            deleting = null
        },
        onDeleteDismiss = { deleting = null },
    )
}

/**
 * Rubi «لیست فاکتورها» (Phase 3.1): the reference list layout — card rows with
 * party name, «فاکتور #N • تاریخ • X قلم», amount + status pill, and the two
 * Rubi row actions (کپی فاکتور / حذف فاکتور) — connected to the Phase 3
 * Order engine (spec §12/§13).
 */
@Composable
fun InvoiceListScreen(
    state: InvoiceListUiState,
    snackbarHostState: SnackbarHostState,
    deleting: InvoiceRowUi?,
    onInvoiceClick: (Long) -> Unit,
    onAddInvoice: () -> Unit,
    onReturnsClick: () -> Unit,
    onCopy: (Long) -> Unit,
    onDeleteRequest: (InvoiceRowUi) -> Unit,
    onDeleteConfirmed: (InvoiceRowUi?) -> Unit,
    onDeleteDismiss: () -> Unit,
) {
    Scaffold(
        containerColor = ListCream,
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        "لیست فاکتورها",
                        fontWeight = FontWeight.W900,
                        fontSize = 15.sp,
                        color = ListSlate800,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onReturnsClick) {
                        Icon(Icons.Filled.History, contentDescription = "مرجوعی‌ها", tint = ListSlate800)
                    }
                },
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = onAddInvoice,
                containerColor = ListOrange,
                shape = RoundedCornerShape(16.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Add, contentDescription = null, tint = Color.White)
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("فاکتور جدید", color = Color.White, fontWeight = FontWeight.W900)
                }
            }
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            if (!state.isLoading && state.invoices.isEmpty()) {
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Icon(
                        Icons.Outlined.ReceiptLong,
                        contentDescription = null,
                        tint = ListSlate400,
                        modifier = Modifier.size(48.dp),
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text("هنوز فاکتوری ثبت نشده", color = ListSlate500, fontWeight = FontWeight.W700)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("فاکتور جدید از دکمهٔ نارنجی ثبت کنید", color = ListSlate400, fontSize = 12.sp)
                }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    items(state.invoices, key = { it.id }) { row ->
                        InvoiceRow(
                            row = row,
                            onClick = { onInvoiceClick(row.id) },
                            onCopy = { onCopy(row.id) },
                            onDelete = { onDeleteRequest(row) },
                        )
                    }
                }
            }
        }
    }

    if (deleting != null) {
        AlertDialog(
            onDismissRequest = onDeleteDismiss,
            title = { Text("حذف فاکتور") },
            text = {
                Text(
                    "فاکتور شماره ${PersianNumberFormatter.toPersianDigits(deleting!!.number)} حذف شود؟" +
                        " (اثر موجودی آن هم برمی‌گردد.)"
                )
            },
            confirmButton = {
                TextButton(onClick = { onDeleteConfirmed(deleting) }) {
                    Text("حذف", color = Color(0xFFE11D48), fontWeight = FontWeight.W800)
                }
            },
            dismissButton = {
                TextButton(onClick = onDeleteDismiss) { Text("انصراف") }
            },
        )
    }
}

@Composable
private fun InvoiceRow(
    row: InvoiceRowUi,
    onClick: () -> Unit,
    onCopy: () -> Unit,
    onDelete: () -> Unit,
) {
    val statusColor = when (row.statusColor) {
        InvoiceRowUiStatus.PAID -> PaidGreen
        InvoiceRowUiStatus.PARTIAL -> PartialAmber
        InvoiceRowUiStatus.UNPAID, InvoiceRowUiStatus.CANCELLED -> UnpaidRose
    }
    Surface(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        shape = RoundedCornerShape(14.dp),
        color = Color.White,
        border = BorderStroke(1.dp, ListBorder),
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 12.dp, end = 12.dp, top = 8.dp, bottom = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        row.partyName.ifEmpty { "مشتری عمومی" },
                        fontWeight = FontWeight.W800,
                        fontSize = 13.sp,
                        color = ListSlate800,
                        maxLines = 1,
                    )
                    Text(
                        "فاکتور #${PersianNumberFormatter.toPersianDigits(row.number)} • " +
                            "${JalaliDateFormatter.formatJalali(row.date)} • " +
                            "${PersianNumberFormatter.toPersianDigits(row.itemCount.toString())} قلم" +
                            (if (row.isPurchase) "  •  خرید" else ""),
                        fontSize = 11.sp,
                        color = ListSlate500,
                    )
                }
                Spacer(modifier = Modifier.width(8.dp))
                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        InvoiceFormatting.formatCurrency(row.total),
                        fontWeight = FontWeight.W900,
                        fontSize = 12.sp,
                        color = ListSlate800,
                    )
                    Spacer(modifier = Modifier.height(3.dp))
                    Surface(
                        shape = RoundedCornerShape(20.dp),
                        color = statusColor.copy(alpha = 0.12f),
                    ) {
                        Text(
                            row.statusLabel,
                            fontSize = 9.sp,
                            fontWeight = FontWeight.W800,
                            color = statusColor,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                        )
                    }
                }
            }
            Row(
                modifier = Modifier.padding(start = 12.dp, end = 12.dp, bottom = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedButton(
                    onClick = onCopy,
                    modifier = Modifier
                        .weight(1f)
                        .height(36.dp),
                    shape = RoundedCornerShape(10.dp),
                    border = BorderStroke(1.dp, ListOrange.copy(alpha = 0.5f)),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 4.dp),
                ) {
                    Icon(Icons.Outlined.ReceiptLong, contentDescription = null, tint = ListOrange, modifier = Modifier.size(17.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("کپی فاکتور", color = ListOrange, fontSize = 11.sp, fontWeight = FontWeight.W800)
                }
                OutlinedButton(
                    onClick = onDelete,
                    modifier = Modifier
                        .weight(1f)
                        .height(36.dp),
                    shape = RoundedCornerShape(10.dp),
                    border = BorderStroke(1.dp, Color(0xFFE11D48).copy(alpha = 0.45f)),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 4.dp),
                ) {
                    Icon(Icons.Outlined.DeleteOutline, contentDescription = null, tint = Color(0xFFE11D48), modifier = Modifier.size(17.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("حذف فاکتور", color = Color(0xFFE11D48), fontSize = 11.sp, fontWeight = FontWeight.W800)
                }
            }
        }
    }
}
