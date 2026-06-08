package com.elevateai.app.m4.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.elevateai.app.m4.data.models.Notification
import com.elevateai.app.m4.ui.viewmodel.FocusAIViewModel
import com.elevateai.app.m4.ui.viewmodel.NotificationState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationCenterScreen(
    viewModel: FocusAIViewModel,
    onActionClick: (String) -> Unit
) {
    val state by viewModel.uiState.collectAsState()
    var currentFilter by remember { mutableStateOf<String?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("FocusAI Notifications") })
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding)) {
            // Filter Bar
            ScrollableTabRow(selectedTabIndex = 0, edgePadding = 16.dp) {
                listOf("All", "Critical", "High", "Medium", "Low").forEach { filter ->
                    val filterVal = if (filter == "All") null else filter.lowercase()
                    Tab(
                        selected = currentFilter == filterVal,
                        onClick = { 
                            currentFilter = filterVal
                            viewModel.loadNotifications(priority = filterVal)
                        },
                        text = { Text(filter) }
                    )
                }
            }

            when (val s = state) {
                is NotificationState.Loading -> Box(Modifier.fillMaxSize()) { CircularProgressIndicator(Modifier.align(Alignment.Center)) }
                is NotificationState.Success -> {
                    LazyColumn(modifier = Modifier.fillMaxSize()) {
                        items(s.notifications) { notif ->
                            NotificationItem(
                                notification = notif,
                                onRead = { viewModel.markAsRead(notif.id) },
                                onAction = { url -> onActionClick(url) }
                            )
                        }
                    }
                }
                is NotificationState.Error -> Text("Error: ${s.message}", modifier = Modifier.padding(16.dp))
            }
        }
    }
}

@Composable
fun NotificationItem(
    notification: Notification,
    onRead: () -> Unit,
    onAction: (String) -> Unit
) {
    val priorityColor = when (notification.priority) {
        "critical" -> Color.Red
        "high" -> Color(0xFFFFA500)
        "medium" -> Color.Yellow
        else -> Color.Gray
    }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (notification.is_read) Color.White else Color(0xFFF5F5FF)
        )
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Surface(
                    modifier = Modifier.size(8.dp),
                    shape = MaterialTheme.shapes.small,
                    color = priorityColor
                ) {}
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = notification.title,
                    style = MaterialTheme.typography.titleMedium,
                    color = if (notification.is_read) Color.Gray else Color.Black
                )
            }
            
            notification.body?.let {
                Spacer(modifier = Modifier.height(4.dp))
                Text(text = it, style = MaterialTheme.typography.bodySmall)
            }

            if (notification.action_label != null && notification.action_url != null) {
                Spacer(modifier = Modifier.height(12.dp))
                Button(
                    onClick = { onAction(notification.action_url) },
                    modifier = Modifier.align(Alignment.End)
                ) {
                    Text(notification.action_label)
                }
            }
        }
    }
}
