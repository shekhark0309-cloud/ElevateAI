package com.elevateai.app.m5.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.elevateai.app.m5.data.models.FocusIntelligence

@Composable
fun FocusDashboardWidget(
    intelligence: FocusIntelligence,
    onStartClick: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(text = "Productivity Score", style = MaterialTheme.typography.titleMedium)
                Text(text = "${intelligence.productivity_score.toInt()}", style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.primary)
            }
            
            LinearProgressIndicator(
                progress = { (intelligence.productivity_score / 100).toFloat() },
                modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)
            )

            Text(text = intelligence.intervention, style = MaterialTheme.typography.bodySmall)

            Spacer(modifier = Modifier.height(16.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = onStartClick, modifier = Modifier.weight(1f)) {
                    Text("Start Focus")
                }
                OutlinedCard(modifier = Modifier.weight(1f)) {
                    Column(modifier = Modifier.padding(8.dp)) {
                        Text(text = "Streak", style = MaterialTheme.typography.labelSmall)
                        Text(text = "${intelligence.current_streak} Days", style = MaterialTheme.typography.titleMedium)
                    }
                }
            }
        }
    }
}
