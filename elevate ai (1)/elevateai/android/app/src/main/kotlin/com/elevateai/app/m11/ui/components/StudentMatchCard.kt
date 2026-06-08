package com.elevateai.app.m11.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.elevateai.app.m11.data.models.DiscoveryStudent

@Composable
fun StudentMatchCard(
    student: DiscoveryStudent,
    onConnect: (String) -> Unit,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(8.dp),
        onClick = onClick
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Column {
                    Text(text = student.full_name, style = MaterialTheme.typography.titleLarge)
                    Text(text = "${student.course} • Year ${student.year_of_study}", style = MaterialTheme.typography.bodySmall)
                }
                Box {
                    CircularProgressIndicator(
                        progress = { student.match_score / 100f },
                        strokeWidth = 4.dp
                    )
                    Text(
                        text = "${student.match_score}%",
                        style = MaterialTheme.typography.labelSmall,
                        modifier = Modifier.padding(top = 10.dp, start = 8.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))
            Text(text = "DNA: ${student.archetype ?: "Unknown"}", color = MaterialTheme.colorScheme.primary)
            
            if (student.shared_skills.isNotEmpty()) {
                Text(text = "Shared Skills: ${student.shared_skills.joinToString(", ")}", style = MaterialTheme.typography.bodySmall)
            }

            Spacer(modifier = Modifier.height(16.dp))
            Row {
                Button(onClick = { onConnect("study_buddy") }, modifier = Modifier.weight(1f)) {
                    Text("Connect")
                }
                Spacer(modifier = Modifier.width(8.dp))
                OutlinedButton(onClick = { /* Message Logic */ }, modifier = Modifier.weight(1f)) {
                    Text("Message")
                }
            }
        }
    }
}
