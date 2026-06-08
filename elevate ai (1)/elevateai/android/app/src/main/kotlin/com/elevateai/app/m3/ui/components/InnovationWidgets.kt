package com.elevateai.app.m3.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.elevateai.app.m3.data.models.IdeaFeedItem

@Composable
fun RecommendedIdeaWidget(
    idea: IdeaFeedItem,
    onClick: () -> Unit
) {
    ElevatedCard(
        modifier = Modifier
            .width(200.dp)
            .padding(8.dp),
        onClick = onClick
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text(text = "Match: ${(idea.match_score).toInt()}%", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
            Text(text = idea.title, style = MaterialTheme.typography.titleMedium, maxLines = 1)
            Text(text = idea.description ?: "", style = MaterialTheme.typography.bodySmall, maxLines = 2)
            Spacer(modifier = Modifier.height(8.dp))
            LinearProgressIndicator(
                progress = { (idea.match_score / 100).toFloat() },
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
fun TrendingProjectsRow(
    ideas: List<IdeaFeedItem>,
    onIdeaClick: (String) -> Unit
) {
    Column {
        Text(text = "Trending Innovation", style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(horizontal = 16.dp))
        Row(modifier = Modifier.horizontalScroll(rememberScrollState())) {
            ideas.forEach { idea ->
                RecommendedIdeaWidget(idea, onClick = { onIdeaClick(idea.idea_id) })
            }
        }
    }
}
