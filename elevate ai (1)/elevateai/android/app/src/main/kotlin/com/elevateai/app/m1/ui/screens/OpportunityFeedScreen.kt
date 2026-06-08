package com.elevateai.app.m1.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.elevateai.app.m1.data.models.OpportunitySection
import com.elevateai.app.m1.data.models.RankedOpportunity
import com.elevateai.app.m1.ui.viewmodel.OpportunityFeedState
import com.elevateai.app.m1.ui.viewmodel.OpportunityFeedViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OpportunityFeedScreen(
    viewModel: OpportunityFeedViewModel,
    onOppClick: (String) -> Unit
) {
    val state by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = { TopAppBar(title = { Text("Opportunity Engine") }) }
    ) { padding ->
        when (val s = state) {
            is OpportunityFeedState.Loading -> Box(Modifier.fillMaxSize()) { CircularProgressIndicator() }
            is OpportunityFeedState.Success -> {
                LazyColumn(modifier = Modifier.padding(padding)) {
                    items(s.sections) { section ->
                        OpportunitySectionRow(section, onOppClick)
                    }
                }
            }
            is OpportunityFeedState.Error -> Text("Error: ${s.message}")
        }
    }
}

@Composable
fun OpportunitySectionRow(
    section: OpportunitySection,
    onOppClick: (String) -> Unit
) {
    Column(modifier = Modifier.padding(vertical = 12.dp)) {
        Text(
            text = section.title,
            style = MaterialTheme.typography.titleLarge,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
        )
        LazyRow(contentPadding = PaddingValues(horizontal = 16.dp)) {
            items(section.opportunities) { opp ->
                OpportunityCard(opp, onClick = { onOppClick(opp.id) })
            }
        }
    }
}

@Composable
fun OpportunityCard(opp: RankedOpportunity, onClick: () -> Unit) {
    ElevatedCard(
        modifier = Modifier
            .width(280.dp)
            .padding(end = 12.dp),
        onClick = onClick
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Badge { Text(opp.type.uppercase()) }
                Text(text = "${opp.match_score}% Match", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
            }
            Spacer(modifier = Modifier.height(8.dp))
            Text(text = opp.title, style = MaterialTheme.typography.titleMedium, maxLines = 2)
            Text(text = opp.organizer_name, style = MaterialTheme.typography.bodySmall)
            
            Spacer(modifier = Modifier.height(12.dp))
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = opp.ai_reason,
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier.padding(8.dp),
                    maxLines = 2
                )
            }
        }
    }
}
