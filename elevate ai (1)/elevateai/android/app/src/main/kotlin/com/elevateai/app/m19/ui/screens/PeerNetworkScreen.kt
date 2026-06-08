package com.elevateai.app.m19.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.elevateai.app.m19.data.models.SuccessStoryFeedItem
import com.elevateai.app.m19.ui.viewmodel.PeerNetworkState
import com.elevateai.app.m19.ui.viewmodel.PeerNetworkViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PeerNetworkScreen(
    viewModel: PeerNetworkViewModel,
    onStoryClick: (String) -> Unit
) {
    val state by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Peer Support Network") })
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding)) {
            Text(
                text = "Learn from students who already won scholarships.",
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(16.dp),
                color = MaterialTheme.colorScheme.secondary
            )

            when (val s = state) {
                is PeerNetworkState.Loading -> Box(Modifier.fillMaxSize()) { CircularProgressIndicator() }
                is PeerNetworkState.Success -> {
                    LazyColumn {
                        items(s.stories) { story ->
                            SuccessStoryCard(story, onClick = { onStoryClick(story.story_id) })
                        }
                    }
                }
                is PeerNetworkState.Error -> Text("Error: ${s.message}")
            }
        }
    }
}

@Composable
fun SuccessStoryCard(story: SuccessStoryFeedItem, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().padding(8.dp),
        onClick = onClick
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = story.opportunity_title, style = MaterialTheme.typography.titleLarge)
            Text(text = "Awarded to ${story.student_name} (${story.approval_year})", style = MaterialTheme.typography.labelSmall)
            Spacer(modifier = Modifier.height(8.dp))
            Text(text = story.journey_summary, maxLines = 2, style = MaterialTheme.typography.bodyMedium)
            Spacer(modifier = Modifier.height(8.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Badge { Text("₹${story.amount_received.toInt()}") }
                TextButton(onClick = onClick) { Text("Read Journey →") }
            }
        }
    }
}
