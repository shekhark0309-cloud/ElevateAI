package com.elevateai.app.m3.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.elevateai.app.m3.data.models.IdeaFeedItem
import com.elevateai.app.m3.ui.viewmodel.InnovationFeedState
import com.elevateai.app.m3.ui.viewmodel.InnovationFeedViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InnovationHubScreen(
    viewModel: InnovationFeedViewModel,
    onIdeaClick: (String) -> Unit,
    onNavigateToValidate: () -> Unit
) {
    val state by viewModel.uiState.collectAsState()
    var selectedCategory by remember { mutableStateOf("All") }

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Innovation Hub") })
        },
        floatingActionButton = {
            FloatingActionButton(onClick = onNavigateToValidate) {
                Text("+ Idea")
            }
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding)) {
            // Category Filter Row
            ScrollableTabRow(selectedTabIndex = 0, edgePadding = 16.dp) {
                listOf("All", "Tech", "Social", "Business", "AI").forEach { cat ->
                    Tab(
                        selected = selectedCategory == cat,
                        onClick = { 
                            selectedCategory = cat
                            viewModel.loadFeed(category = cat)
                        },
                        text = { Text(cat) }
                    )
                }
            }

            when (val s = state) {
                is InnovationFeedState.Loading -> CircularProgressIndicator()
                is InnovationFeedState.Success -> {
                    LazyColumn {
                        items(s.ideas) { idea ->
                            IdeaCard(idea, onClick = { onIdeaClick(idea.idea_id) })
                        }
                    }
                }
                is InnovationFeedState.Error -> Text("Error: ${s.message}")
            }
        }
    }
}

@Composable
fun IdeaCard(idea: IdeaFeedItem, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(8.dp),
        onClick = onClick
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = idea.title, style = MaterialTheme.typography.titleLarge)
            Text(text = "By ${idea.creator_name}", style = MaterialTheme.typography.bodySmall)
            Spacer(modifier = Modifier.height(8.dp))
            Text(text = idea.description ?: "", maxLines = 2)
            Spacer(modifier = Modifier.height(8.dp))
            Row {
                Badge { Text("Score: ${idea.innovation_score ?: "N/A"}") }
                Spacer(modifier = Modifier.width(8.dp))
                Badge { Text("${idea.collaborator_count} members") }
            }
        }
    }
}
