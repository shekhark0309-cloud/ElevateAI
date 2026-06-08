package com.elevateai.app.m2.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.elevateai.app.m2.data.models.*
import com.elevateai.app.m2.ui.viewmodel.TeamFinderState
import com.elevateai.app.m2.ui.viewmodel.TeamFinderViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TeamFinderScreen(
    viewModel: TeamFinderViewModel,
    onTeamClick: (String) -> Unit
) {
    val state by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = { TopAppBar(title = { Text("Smart Team Finder") }) }
    ) { padding ->
        Column(modifier = Modifier.padding(padding)) {
            AvailabilityHeader(onStatusChange = { viewModel.updateStatus(it) })

            when (val s = state) {
                is TeamFinderState.Loading -> CircularProgressIndicator()
                is TeamFinderState.Success -> {
                    LazyColumn {
                        item { NearbyTeammatesSection(s.nearby) }
                        item { Text("Top Team Matches", style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(16.dp)) }
                        items(s.matches) { team ->
                            TeamMatchCard(team, onClick = { onTeamClick(team.id) })
                        }
                    }
                }
                is TeamFinderState.Error -> Text("Error: ${s.message}")
            }
        }
    }
}

@Composable
fun NearbyTeammatesSection(nearby: List<NearbyTeammate>) {
    Column(modifier = Modifier.padding(vertical = 8.dp)) {
        Text(text = "Nearby on Campus", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(horizontal = 16.dp))
        LazyRow(contentPadding = PaddingValues(horizontal = 16.dp)) {
            items(nearby) { teammate ->
                NearbyTeammateCard(teammate)
            }
        }
    }
}

@Composable
fun TeamMatchCard(team: TeamMatch, onClick: () -> Unit) {
    ElevatedCard(modifier = Modifier.fillMaxWidth().padding(8.dp), onClick = onClick) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(text = team.name, style = MaterialTheme.typography.titleLarge)
                Badge { Text("${team.composite_score.toInt()}% Match") }
            }
            Text(text = team.tagline ?: "", style = MaterialTheme.typography.bodySmall)
            Spacer(modifier = Modifier.height(8.dp))
            Text(text = "Leader: ${team.leader_name} (${team.leader_availability ?: "Unknown"})", style = MaterialTheme.typography.labelSmall)
            
            if (team.match_explanation != null) {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant), modifier = Modifier.padding(top = 8.dp)) {
                    Text(text = team.match_explanation, modifier = Modifier.padding(8.dp), style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

@Composable
fun NearbyTeammateCard(teammate: NearbyTeammate) {
    Card(modifier = Modifier.width(160.dp).padding(end = 8.dp)) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text(text = teammate.full_name, style = MaterialTheme.typography.titleSmall, maxLines = 1)
            Text(text = "${teammate.distance_meters}m away", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
            Badge(containerColor = MaterialTheme.colorScheme.primaryContainer) { Text(teammate.availability) }
            Spacer(modifier = Modifier.height(8.dp))
            Text(text = teammate.archetype ?: "", style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
fun AvailabilityHeader(onStatusChange: (String) -> Unit) {
    var status by remember { mutableStateOf("Available Now") }
    val statuses = listOf("Available Now", "Busy", "Studying", "Working on Project")

    ScrollableTabRow(selectedTabIndex = statuses.indexOf(status), edgePadding = 16.dp) {
        statuses.forEach { s ->
            Tab(selected = status == s, onClick = { status = s; onStatusChange(s) }) {
                Text(text = s, modifier = Modifier.padding(8.dp))
            }
        }
    }
}
