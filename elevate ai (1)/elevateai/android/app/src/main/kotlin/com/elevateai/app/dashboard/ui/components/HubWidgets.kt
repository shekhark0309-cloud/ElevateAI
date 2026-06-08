package com.elevateai.app.dashboard.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.serialization.json.*

@Composable
fun SectionHeader(title: String, icon: ImageVector) {
    Row(
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(20.dp), color = MaterialTheme.colorScheme.primary)
        Spacer(modifier = Modifier.width(8.dp))
        Text(text = title, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun OpportunityHubWidget(data: JsonObject?, onClick: () -> Unit) {
    if (data == null) return
    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), onClick = onClick) {
        Column(modifier = Modifier.padding(16.dp)) {
            SectionHeader("SMART OPPORTUNITY HUB", Icons.Default.Lightbulb)
            Spacer(modifier = Modifier.height(8.dp))
            Text(text = data["title"]?.jsonPrimitive?.content ?: "", style = MaterialTheme.typography.titleMedium)
            Text(text = "Match Score: ${data["match"]?.jsonPrimitive?.content}%", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
            data["reason"]?.jsonPrimitive?.content?.let {
                Text(text = "Why: $it", style = MaterialTheme.typography.bodySmall)
            }
            Spacer(modifier = Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = onClick, modifier = Modifier.weight(1f)) { Text("Quick Apply") }
                OutlinedButton(onClick = onClick, modifier = Modifier.weight(1f)) { Text("Save") }
            }
        }
    }
}

@Composable
fun CareerCenterWidget(data: JsonObject?, onClick: () -> Unit) {
    if (data == null) return
    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), onClick = onClick) {
        Column(modifier = Modifier.padding(16.dp)) {
            SectionHeader("CAREER COMMAND CENTER", Icons.Default.TrendingUp)
            Spacer(modifier = Modifier.height(8.dp))
            val scoreStr = data["score"]?.jsonPrimitive?.content ?: "0"
            val score = scoreStr.toFloatOrNull() ?: 0f
            LinearProgressIndicator(
                progress = score / 100f,
                modifier = Modifier.fillMaxWidth()
            )
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(text = "Readiness: $score%", style = MaterialTheme.typography.titleSmall)
                data["next_milestone"]?.jsonPrimitive?.content?.let {
                    Text(text = "Next: $it", style = MaterialTheme.typography.labelSmall)
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
            data["top_gap"]?.jsonPrimitive?.content?.let {
                Text(text = "Skill Gap: $it", color = MaterialTheme.colorScheme.error)
            }
        }
    }
}

@Composable
fun NetworkHubWidget(data: JsonObject?, onClick: () -> Unit) {
    if (data == null) return
    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), onClick = onClick) {
        Column(modifier = Modifier.padding(16.dp)) {
            SectionHeader("TEAM & NETWORK HUB", Icons.Default.Groups)
            Text(text = "Nearby Students: ${data["count"]?.jsonPrimitive?.content ?: "0"}", style = MaterialTheme.typography.bodyMedium)
            
            val buddies = data["nearby_buddies"]?.jsonPrimitive?.content?.toIntOrNull() ?: 0
            if (buddies > 0) {
                Text(
                    text = "🔥 $buddies Buddies studying ${data["trending_subject"]?.jsonPrimitive?.content ?: "now"}", 
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.labelMedium
                )
            }

            Text(text = "Open Invitations: ${data["invites"]?.jsonPrimitive?.content ?: "0"}", style = MaterialTheme.typography.bodySmall)
            TextButton(onClick = onClick) { Text("Find Collaborators →") }
        }
    }
}

@Composable
fun FocusCenterWidget(data: JsonObject?, onClick: () -> Unit) {
    if (data == null) return
    val risk = data["risk_level"]?.jsonPrimitive?.content ?: "low"
    val intervention = data["intervention"]?.jsonPrimitive?.content
    
    val color = when(risk) {
        "critical" -> MaterialTheme.colorScheme.error
        "high" -> MaterialTheme.colorScheme.error.copy(alpha = 0.7f)
        else -> MaterialTheme.colorScheme.primary
    }

    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), onClick = onClick) {
        Column(modifier = Modifier.padding(16.dp)) {
            SectionHeader("FOCUS & PRODUCTIVITY", Icons.Default.Timer)
            
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "Today: ${data["today_minutes"]?.jsonPrimitive?.content ?: "0"}m", 
                    style = MaterialTheme.typography.titleMedium,
                    color = color
                )
                Spacer(modifier = Modifier.width(16.dp))
                if (risk != "low") {
                    Icon(Icons.Default.Warning, contentDescription = null, tint = color, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(text = "${risk.uppercase()} RISK", style = MaterialTheme.typography.labelSmall, color = color, fontWeight = FontWeight.Bold)
                }
            }

            intervention?.let {
                Spacer(modifier = Modifier.height(8.dp))
                Text(text = it, style = MaterialTheme.typography.bodySmall, fontStyle = androidx.compose.ui.text.font.FontStyle.Italic)
            }

            Spacer(modifier = Modifier.height(8.dp))
            data["recommended_session"]?.jsonPrimitive?.content?.let {
                Text(text = "Recommended: $it session", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)
            }

            TextButton(onClick = onClick) { Text("Start Focus Session") }
        }
    }
}

@Composable
fun ScholarshipHubWidget(data: JsonObject?, onClick: () -> Unit) {
    if (data == null) return
    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), onClick = onClick) {
        Column(modifier = Modifier.padding(16.dp)) {
            SectionHeader("SCHOLARSHIP & GOVT HUB", Icons.Default.AccountBalance)
            Text(text = "Eligible Schemes: ${data["matches"]?.jsonPrimitive?.content ?: "0"}", style = MaterialTheme.typography.bodyMedium)
            
            val mentorCount = data["mentors"]?.jsonPrimitive?.content?.toIntOrNull() ?: 0
            if (mentorCount > 0) {
                Text(text = "🌟 $mentorCount Peer Mentors Available", color = MaterialTheme.colorScheme.secondary, fontWeight = FontWeight.Bold)
            }

            data["deadline"]?.jsonPrimitive?.content?.let {
                Text(text = "Next Deadline: $it", color = MaterialTheme.colorScheme.error)
            }
            TextButton(onClick = onClick) { Text("View Scheme Buddy") }
        }
    }
}

@Composable
fun ScamProtectionWidget(data: JsonObject?, onClick: () -> Unit) {
    if (data == null) return
    val alertCount = data["alerts"]?.jsonPrimitive?.content?.toIntOrNull() ?: 0
    val riskLevel = data["risk"]?.jsonPrimitive?.content ?: "low"
    
    val containerColor = when(riskLevel) {
        "high" -> MaterialTheme.colorScheme.errorContainer
        "medium" -> MaterialTheme.colorScheme.secondaryContainer
        else -> MaterialTheme.colorScheme.surfaceVariant
    }

    Card(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        colors = CardDefaults.cardColors(containerColor = containerColor),
        onClick = onClick
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            SectionHeader("SCAM PROTECTION CENTER", Icons.Default.Shield)
            Text(text = "Recent Alerts: $alertCount", fontWeight = FontWeight.Bold)
            Text(text = "Risk Level: ${riskLevel.uppercase()}", style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
fun PortfolioCommandWidget(data: JsonObject?, onClick: () -> Unit) {
    if (data == null) return
    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), onClick = onClick) {
        Column(modifier = Modifier.padding(16.dp)) {
            SectionHeader("PORTFOLIO COMMAND CENTER", Icons.Default.AssignmentInd)
            Text(text = "Completion: ${data["completion"]?.jsonPrimitive?.content ?: "0"}%", style = MaterialTheme.typography.titleMedium)
            Text(text = "Skills Verified: ${data["verified_count"]?.jsonPrimitive?.content ?: "0"}", style = MaterialTheme.typography.bodySmall)
            TextButton(onClick = onClick) { Text("Export Resume") }
        }
    }
}

@Composable
fun CampusOSHubWidget(data: JsonObject?, onClick: () -> Unit) {
    if (data == null) return
    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), onClick = onClick) {
        Column(modifier = Modifier.padding(16.dp)) {
            SectionHeader("CAMPUS OS HUB", Icons.Default.School)
            
            val booking = data["current_booking"]?.jsonObject
            if (booking != null) {
                Card(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)
                ) {
                    Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.EventAvailable, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Active: ${booking["name"]?.jsonPrimitive?.content} until ${booking["booked_until"]?.jsonPrimitive?.content?.split("T")?.get(1)?.substring(0, 5)}",
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }

            val rec = data["recommendation"]?.jsonObject
            if (rec != null) {
                Text(text = "RECOMMENDED FOR YOU", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                Text(text = "${rec["name"]?.jsonPrimitive?.content} (${rec["location"]?.jsonPrimitive?.content})", style = MaterialTheme.typography.titleSmall)
                Text(text = "Reason: ${rec["reason"]?.jsonPrimitive?.content}", style = MaterialTheme.typography.bodySmall, fontStyle = androidx.compose.ui.text.font.FontStyle.Italic)
                Spacer(modifier = Modifier.height(8.dp))
            }

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(text = "Labs Open: ${data["labs"]?.jsonPrimitive?.content ?: "0"}", style = MaterialTheme.typography.bodyMedium)
                Text(text = "Seats Available: ${data["spaces"]?.jsonPrimitive?.content ?: "0"}", style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}

@Composable
fun CafeteriaHubWidget(data: JsonObject?, onClick: () -> Unit) {
    if (data == null) return
    Card(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        onClick = onClick
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            SectionHeader("DINING & SUSTAINABILITY", Icons.Default.Restaurant)
            
            val nextMeal = data["next_meal"]?.jsonPrimitive?.content ?: "Lunch"
            val status = if (data["is_skipped"]?.jsonPrimitive?.boolean == true) "SKIPPED" else "OPTED-IN"
            val statusColor = if (data["is_skipped"]?.jsonPrimitive?.boolean == true) MaterialTheme.colorScheme.error else Color(0xFF2E7D32)

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Column {
                    Text(text = "Next: $nextMeal", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Text(text = status, color = statusColor, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Black)
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text(text = "${data["saved"]?.jsonPrimitive?.content ?: "0"} kg", style = MaterialTheme.typography.titleMedium, color = Color(0xFF2E7D32))
                    Text(text = "Food Saved", style = MaterialTheme.typography.labelSmall)
                }
            }
            
            TextButton(onClick = onClick) { Text("Manage Meals →") }
        }
    }
}

@Composable
fun SmartNudgeCard(nudge: JsonObject, onClick: (String) -> Unit) {
    val type = nudge["type"]?.jsonPrimitive?.content ?: "info"
    val color = when(type) {
        "priority" -> MaterialTheme.colorScheme.secondaryContainer
        "alert" -> MaterialTheme.colorScheme.errorContainer
        "high" -> MaterialTheme.colorScheme.errorContainer
        else -> MaterialTheme.colorScheme.surfaceVariant
    }
    Card(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
        colors = CardDefaults.cardColors(containerColor = color),
        onClick = { onClick(nudge["action"]?.jsonPrimitive?.content ?: "") }
    ) {
        Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.NotificationsActive, contentDescription = null, modifier = Modifier.size(16.dp))
            Spacer(modifier = Modifier.width(12.dp))
            Column {
                Text(text = nudge["title"]?.jsonPrimitive?.content ?: "", style = MaterialTheme.typography.labelLarge)
                Text(text = nudge["message"]?.jsonPrimitive?.content ?: nudge["body"]?.jsonPrimitive?.content ?: "", style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}
