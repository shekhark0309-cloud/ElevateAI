package com.elevateai.app.m7.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.elevateai.app.m7.data.models.CareerIntelligence
import com.elevateai.app.m7.ui.viewmodel.CareerPredictorViewModel
import com.elevateai.app.m7.ui.viewmodel.CareerState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CareerReadinessScreen(viewModel: CareerPredictorViewModel) {
    val state by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = { TopAppBar(title = { Text("Career Predictor") }) }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .padding(16.dp)
                .verticalScroll(rememberScrollState())
        ) {
            when (val s = state) {
                is CareerState.Loading -> CircularProgressIndicator()
                is CareerState.Success -> {
                    ReadinessHeader(s.intelligence)
                    Spacer(modifier = Modifier.height(24.dp))
                    ForecastSection(s.intelligence)
                    Spacer(modifier = Modifier.height(24.dp))
                    ActionCenterSection(s.intelligence)
                }
                is CareerState.Error -> Text("Error: ${s.message}")
            }
        }
    }
}

@Composable
fun ReadinessHeader(data: CareerIntelligence) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(20.dp)) {
            Text(text = "Current Readiness Score", style = MaterialTheme.typography.labelMedium)
            Text(
                text = "${data.score.toInt()}/100",
                style = MaterialTheme.typography.displayMedium,
                color = MaterialTheme.colorScheme.primary
            )
            LinearProgressIndicator(
                progress = { (data.score / 100).toFloat() },
                modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp)
            )
            Text(text = "Risk Level: ${data.risk_level}", color = if (data.risk_level == "High") Color.Red else Color.Gray)
        }
    }
}

@Composable
fun ForecastSection(data: CareerIntelligence) {
    Text(text = "Trajectory Forecast", style = MaterialTheme.typography.titleLarge)
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        ForecastCard("30 Days", data.forecast.d30)
        ForecastCard("90 Days", data.forecast.d90)
    }
}

@Composable
fun ForecastCard(label: String, score: Double) {
    Card(modifier = Modifier.width(160.dp)) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text(text = label, style = MaterialTheme.typography.labelSmall)
            Text(text = "${score.toInt()}%", style = MaterialTheme.typography.titleLarge)
            Text(text = "Potential", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
        }
    }
}

@Composable
fun ActionCenterSection(data: CareerIntelligence) {
    Text(text = "Next Best Actions", style = MaterialTheme.typography.titleLarge)
    data.next_actions.forEach { action ->
        ListItem(
            headlineContent = { Text(action.label) },
            supportingContent = { Text("Impact: ${action.impact}") },
            trailingContent = {
                Badge(containerColor = if (action.priority == "high") Color.Red else Color.Gray) {
                    Text(action.priority.uppercase())
                }
            }
        )
    }
}
