package com.elevateai.app.m2.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.elevateai.app.m2.data.models.TeamMatch

@Composable
fun RecommendedTeammateWidget(
    match: TeamMatch,
    onInvite: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = "Top Team Match", style = MaterialTheme.typography.labelSmall)
            Text(text = match.name, style = MaterialTheme.typography.titleMedium)
            Text(text = "Fits your ${match.required_skills.take(2).joinToString(", ")} skills", style = MaterialTheme.typography.bodySmall)
            
            Spacer(modifier = Modifier.height(12.dp))
            Button(onClick = onInvite, modifier = Modifier.fillMaxWidth()) {
                Text("Join Team")
            }
        }
    }
}
