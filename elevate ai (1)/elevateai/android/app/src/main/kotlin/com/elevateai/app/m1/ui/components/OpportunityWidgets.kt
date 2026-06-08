package com.elevateai.app.m1.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.elevateai.app.m1.data.models.RankedOpportunity

@Composable
fun TopOpportunityWidget(
    opp: RankedOpportunity,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = "Top Match for Your DNA", style = MaterialTheme.typography.labelSmall)
            Spacer(modifier = Modifier.height(4.dp))
            Text(text = opp.title, style = MaterialTheme.typography.titleLarge)
            Text(text = "${opp.match_score}% Compatibility • ${opp.type}", style = MaterialTheme.typography.bodySmall)
            
            Spacer(modifier = Modifier.height(12.dp))
            Button(onClick = onClick) {
                Text("Apply Now")
            }
        }
    }
}
