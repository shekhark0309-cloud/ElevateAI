package com.elevateai.app.m11.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.elevateai.app.m11.data.models.DiscoveryStudent

@Composable
fun RecommendedCollaboratorWidget(
    student: DiscoveryStudent,
    onClick: () -> Unit
) {
    ElevatedCard(
        modifier = Modifier
            .width(180.dp)
            .padding(8.dp),
        onClick = onClick
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text(text = "${student.match_score}% Match", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
            Text(text = student.full_name, style = MaterialTheme.typography.titleMedium, maxLines = 1)
            Text(text = student.archetype ?: "", style = MaterialTheme.typography.bodySmall)
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Shared: ${student.shared_skills.take(2).joinToString(", ")}",
                style = MaterialTheme.typography.labelSmall,
                maxLines = 1
            )
        }
    }
}
