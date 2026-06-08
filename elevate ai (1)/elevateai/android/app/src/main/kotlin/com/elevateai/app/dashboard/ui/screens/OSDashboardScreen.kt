package com.elevateai.app.dashboard.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.elevateai.app.dashboard.data.models.OSDashboardData
import com.elevateai.app.dashboard.ui.components.*
import com.elevateai.app.dashboard.ui.viewmodel.DashboardState
import com.elevateai.app.dashboard.ui.viewmodel.OSDashboardViewModel
import kotlinx.serialization.json.jsonObject

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OSDashboardScreen(
    viewModel: OSDashboardViewModel,
    onNavigate: (String) -> Unit
) {
    val state by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("ELEVATE OS", fontWeight = FontWeight.Black) },
                navigationIcon = {
                    IconButton(onClick = { onNavigate("back") }) {
                        Icon(Icons.Default.ArrowBack, "Back to Flutter")
                    }
                },
                actions = {
                    IconButton(onClick = { onNavigate("/notifications") }) {
                        Icon(Icons.Default.Notifications, "Notifications")
                    }
                }
            )
        },
        bottomBar = { QuickActionBar(onAction = onNavigate) }
    ) { padding ->
        when (val s = state) {
            is DashboardState.Loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            is DashboardState.Success -> {
                val data = s.data
                Column(
                    modifier = Modifier
                        .padding(padding)
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                ) {
                    // SECTION 1: DAILY OS SUMMARY
                    OSSummaryHeader(data.summary)
                    
                    // SECTION 2: TODAY'S MOST IMPORTANT ACTION
                    data.top_action?.let { action ->
                        TopActionCard(action, onAction = { onNavigate(action.action) })
                    }

                    // SECTION 11: SMART NUDGE CENTER
                    if (data.nudges.isNotEmpty()) {
                        Text("Smart Nudges", style = MaterialTheme.typography.labelMedium, modifier = Modifier.padding(start = 16.dp, top = 8.dp))
                        data.nudges.forEach { nudge ->
                            SmartNudgeCard(nudge.jsonObject, onClick = onNavigate)
                        }
                    }

                    // Module Hubs (Sections 3-10) - ZERO HARDCODED VALUES
                    OpportunityHubWidget(data.opportunity_hub, onClick = { onNavigate("/opportunities") })
                    CareerCenterWidget(data.career_center, onClick = { onNavigate("/career_predictor") })
                    NetworkHubWidget(data.network_hub, onClick = { onNavigate("/team_finder") })
                    FocusCenterWidget(data.focus_center, onClick = { onNavigate("focus_mode") })
                    ScholarshipHubWidget(data.scholarship_hub, onClick = { onNavigate("scheme_buddy") })
                    CampusOSHubWidget(data.campus_hub, onClick = { onNavigate("/campus_connect") })
                    CafeteriaHubWidget(data.cafeteria_hub, onClick = { onNavigate("cafeteria") })
                    PortfolioCommandWidget(data.portfolio_center, onClick = { onNavigate("/portfolio") })
                    ScamProtectionWidget(data.scam_center, onClick = { onNavigate("/scam_shield") })
                    
                    Spacer(modifier = Modifier.height(100.dp))
                }
            }
            is DashboardState.Error -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Error: ${s.message}", color = MaterialTheme.colorScheme.error)
                    Button(onClick = { viewModel.loadDashboard() }) { Text("Retry") }
                }
            }
        }
    }
}

@Composable
fun OSSummaryHeader(summary: com.elevateai.app.dashboard.data.models.DashboardSummary) {
    Column(modifier = Modifier.padding(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(text = "Today's Overview", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.width(8.dp))
            TrendIndicator(summary.trend)
        }
        Spacer(modifier = Modifier.height(12.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            SummaryMiniCard("Trust", "${summary.trust_score.toInt()}", Modifier.weight(1f), Icons.Default.Verified)
            SummaryMiniCard("Career", "${summary.career_readiness.toInt()}%", Modifier.weight(1f), Icons.Default.School)
            SummaryMiniCard("Focus", "${summary.focus_score.toInt()}", Modifier.weight(1f), Icons.Default.TrackChanges)
            SummaryMiniCard("Streak", "${summary.streak}d", Modifier.weight(1f), Icons.Default.Whatshot)
        }
    }
}

@Composable
fun TrendIndicator(trend: String) {
    val (icon, color) = when (trend) {
        "up" -> Icons.Default.TrendingUp to Color(0xFF4CAF50)
        "down" -> Icons.Default.TrendingDown to Color(0xFFF44336)
        else -> Icons.Default.TrendingFlat to Color(0xFF9E9E9E)
    }
    Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(20.dp))
}

@Composable
fun SummaryMiniCard(label: String, value: String, modifier: Modifier, icon: ImageVector) {
    Card(modifier = modifier, colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))) {
        Column(modifier = Modifier.padding(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary)
            Spacer(modifier = Modifier.height(4.dp))
            Text(text = value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Text(text = label, style = MaterialTheme.typography.labelSmall)
        }
    }
}

@Composable
fun TopActionCard(action: com.elevateai.app.dashboard.data.models.TopAction, onAction: () -> Unit) {
    val isCritical = action.priority == "critical" || action.priority == "high"
    val containerColor = if (isCritical) MaterialTheme.colorScheme.errorContainer else MaterialTheme.colorScheme.primaryContainer
    val contentColor = if (isCritical) MaterialTheme.colorScheme.onErrorContainer else MaterialTheme.colorScheme.onPrimaryContainer

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        colors = CardDefaults.cardColors(containerColor = containerColor, contentColor = contentColor),
        onClick = onAction,
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(modifier = Modifier.padding(20.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(if (isCritical) Icons.Default.Warning else Icons.Default.Star, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = "HIGHEST IMPACT ACTION", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold)
            }
            Spacer(modifier = Modifier.height(12.dp))
            Text(text = action.label, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Black)
            Spacer(modifier = Modifier.height(16.dp))
            Button(
                onClick = onAction,
                colors = ButtonDefaults.buttonColors(containerColor = contentColor, contentColor = containerColor),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("EXECUTE NOW", fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
fun QuickActionBar(onAction: (String) -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        tonalElevation = 12.dp,
        shadowElevation = 12.dp,
        color = MaterialTheme.colorScheme.surface
    ) {
        NavigationBar(modifier = Modifier.height(72.dp)) {
            NavigationBarItem(
                icon = { Icon(Icons.Default.Timer, "Focus") },
                label = { Text("Focus") },
                selected = false,
                onClick = { onAction("/focus") }
            )
            NavigationBarItem(
                icon = { Icon(Icons.Default.Groups, "Teams") },
                label = { Text("Teams") },
                selected = false,
                onClick = { onAction("/team_finder") }
            )
            NavigationBarItem(
                icon = { Icon(Icons.Default.AddCircle, "Action", modifier = Modifier.size(40.dp), tint = MaterialTheme.colorScheme.primary) },
                label = { },
                selected = false,
                onClick = { onAction("/quick_action") }
            )
            NavigationBarItem(
                icon = { Icon(Icons.Default.Explore, "Explore") },
                label = { Text("Explore") },
                selected = false,
                onClick = { onAction("/opportunities") }
            )
            NavigationBarItem(
                icon = { Icon(Icons.Default.Person, "Profile") },
                label = { Text("Profile") },
                selected = false,
                onClick = { onAction("/profile") }
            )
        }
    }
}
