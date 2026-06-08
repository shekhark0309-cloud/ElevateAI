package com.elevateai.app.m5.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.elevateai.app.m5.ui.viewmodel.FocusState
import com.elevateai.app.m5.ui.viewmodel.FocusViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FocusModeScreen(viewModel: FocusViewModel) {
    val state by viewModel.focusState.collectAsState()
    val intelligence by viewModel.intelligence.collectAsState()

    Scaffold(
        topBar = { TopAppBar(title = { Text("Focus Intervention") }) }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            intelligence?.let { 
                FocusRiskIndicator(it.risk_level, it.intervention)
                Spacer(modifier = Modifier.height(32.dp))
            }

            when (val s = state) {
                is FocusState.Idle -> {
                    Text("Ready for Deep Work?", style = MaterialTheme.typography.headlineMedium)
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(
                        onClick = { viewModel.startSession() },
                        modifier = Modifier.fillMaxWidth().height(56.dp)
                    ) {
                        Text("Start Deep Work")
                    }
                }
                is FocusState.Active -> {
                    Text(text = s.mode.replace("_", " ").uppercase(), color = MaterialTheme.colorScheme.primary)
                    Text(
                        text = formatTime(s.seconds),
                        style = MaterialTheme.typography.displayLarge.copy(fontSize = 64.sp)
                    )
                    Spacer(modifier = Modifier.height(32.dp))
                    Button(
                        onClick = { viewModel.endSession() },
                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                        modifier = Modifier.fillMaxWidth().height(56.dp)
                    ) {
                        Text("End Session")
                    }
                }
                else -> CircularProgressIndicator()
            }
        }
    }
}

@Composable
fun FocusRiskIndicator(risk: String, msg: String) {
    val color = when (risk) {
        "critical" -> Color.Red
        "high" -> Color(0xFFFFA500)
        "medium" -> Color.Yellow
        else -> Color.Green
    }

    Card(colors = CardDefaults.cardColors(containerColor = color.copy(alpha = 0.1f))) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Surface(modifier = Modifier.size(12.dp), shape = MaterialTheme.shapes.small, color = color) {}
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = "Focus Risk: ${risk.uppercase()}", style = MaterialTheme.typography.labelLarge)
            }
            Text(text = msg, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

private fun formatTime(seconds: Int): String {
    val h = seconds / 3600
    val m = (seconds % 3600) / 60
    val s = seconds % 60
    return if (h > 0) "%02d:%02d:%02d".format(h, m, s) else "%02d:%02d".format(m, s)
}
