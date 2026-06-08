package com.elevateai.app.m4.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.elevateai.app.m4.data.models.PriorityAlert

@Composable
fun CriticalPrioritiesWidget(
    alerts: List<PriorityAlert>,
    onAction: (String) -> Unit
) {
    if (alerts.isEmpty()) return

    Card(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Top Priorities for You",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onErrorContainer
            )
            
            alerts.forEach { alert ->
                Spacer(modifier = Modifier.height(12.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(text = alert.title, style = MaterialTheme.typography.bodySmall)
                    }
                    TextButton(onClick = { onAction(alert.action_url) }) {
                        Text(alert.action_label)
                    }
                }
            }
        }
    }
}
