package com.elevateai.app.m11.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.elevateai.app.m11.data.models.DiscoveryStudent
import com.elevateai.app.m11.ui.viewmodel.DiscoveryState
import com.elevateai.app.m11.ui.viewmodel.CampusConnectViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CampusConnectScreen(
    viewModel: CampusConnectViewModel,
    onStudentClick: (String) -> Unit
) {
    val state by viewModel.uiState.collectAsState()
    var selectedFilter by remember { mutableStateOf("all") }

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Campus Connect") })
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding)) {
            // Filter Chips
            Row(modifier = Modifier.padding(8.dp).horizontalScroll(rememberScrollState())) {
                val filters = listOf("all", "skills", "dna", "college")
                filters.forEach { filter ->
                    FilterChip(
                        selected = selectedFilter == filter,
                        onClick = { 
                            selectedFilter = filter
                            viewModel.loadDiscovery(filter)
                        },
                        label = { Text(filter.replaceFirstChar { it.uppercase() }) },
                        modifier = Modifier.padding(horizontal = 4.dp)
                    )
                }
            }

            when (val s = state) {
                is DiscoveryState.Loading -> Box(Modifier.fillMaxSize()) { CircularProgressIndicator() }
                is DiscoveryState.Success -> {
                    LazyColumn {
                        items(s.students) { student ->
                            StudentMatchCard(
                                student = student,
                                onConnect = { type -> viewModel.connectWithStudent(student.student_id, type) },
                                onClick = { onStudentClick(student.student_id) }
                            )
                        }
                    }
                }
                is DiscoveryState.Error -> Text("Error: ${s.message}")
            }
        }
    }
}
