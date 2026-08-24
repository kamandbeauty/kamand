package com.modir.forushgah.presentation.onboarding

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel

@Composable
fun OnboardingRoute(
    onFinished: () -> Unit,
    viewModel: OnboardingViewModel = hiltViewModel(),
) {
    val formState by viewModel.formState.collectAsState()
    OnboardingScreen(
        state = formState,
        onStoreNameChanged = viewModel::onStoreNameChanged,
        onOwnerNameChanged = viewModel::onOwnerNameChanged,
        onCategoryChanged = viewModel::onCategoryChanged,
        onStartingCashChanged = viewModel::onStartingCashChanged,
        onFinish = { viewModel.finishOnboarding(onFinished) },
    )
}

@Composable
fun OnboardingScreen(
    state: OnboardingFormState,
    onStoreNameChanged: (String) -> Unit,
    onOwnerNameChanged: (String) -> Unit,
    onCategoryChanged: (String) -> Unit,
    onStartingCashChanged: (String) -> Unit,
    onFinish: () -> Unit,
) {
    var step by remember { mutableIntStateOf(1) }

    Scaffold { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(24.dp),
            verticalArrangement = Arrangement.Center,
        ) {
            Text("خوش آمدید 👋", style = MaterialTheme.typography.headlineMedium)
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                "بیایید فروشگاهتان را در ۳ مرحله کوتاه راه‌اندازی کنیم",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(modifier = Modifier.height(28.dp))

            when (step) {
                1 -> Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    OutlinedTextField(
                        value = state.storeName,
                        onValueChange = onStoreNameChanged,
                        label = { Text("نام فروشگاه") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OutlinedTextField(
                        value = state.ownerName,
                        onValueChange = onOwnerNameChanged,
                        label = { Text("نام صاحب فروشگاه") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                2 -> Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    OutlinedTextField(
                        value = state.businessCategory,
                        onValueChange = onCategoryChanged,
                        label = { Text("دسته‌بندی اصلی کسب‌وکار") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                3 -> Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    OutlinedTextField(
                        value = state.startingCash,
                        onValueChange = onStartingCashChanged,
                        label = { Text("موجودی نقدی اولیه (اختیاری) — تومان") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            Spacer(modifier = Modifier.height(28.dp))

            Row(horizontalArrangement = Arrangement.End, modifier = Modifier.fillMaxWidth()) {
                Button(
                    enabled = step != 1 || state.canProceedFromStep1,
                    onClick = {
                        if (step < 3) step += 1 else onFinish()
                    },
                ) {
                    Text(if (step < 3) "مرحله بعد" else "شروع کنید")
                }
            }
        }
    }
}
