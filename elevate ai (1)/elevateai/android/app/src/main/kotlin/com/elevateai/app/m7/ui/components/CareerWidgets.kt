package com.elevateai.app.m7.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.elevateai.app.m7.data.models.CareerIntelligence

@Composable
fun CareerDashboardWidget(
    intelligence: CareerIntelligence,
    onNavigate: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        onClick = onNavigate
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(text = "Career Readiness", style = MaterialTheme.typography.titleMedium)
                Text(text = "${intelligence.score.toInt()}%", style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.primary)
            }
            
            Text(text = "Top Gap: ${intelligence.gaps.firstOrNull() ?: "None"}", style = MaterialTheme.typography.bodySmall)

            Spacer(modifier = Modifier.height(12.dp))
            Button(onClick = onNavigate, modifier = Modifier.fillMaxWidth()) {
                Text("View Full Roadmap")
            }
        }
    }
}
