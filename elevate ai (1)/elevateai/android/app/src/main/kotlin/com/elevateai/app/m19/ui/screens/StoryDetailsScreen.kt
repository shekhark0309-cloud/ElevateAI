package com.elevateai.app.m19.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.elevateai.app.m19.ui.viewmodel.StoryDetailsState
import com.elevateai.app.m19.ui.viewmodel.StoryDetailsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StoryDetailsScreen(
    viewModel: StoryDetailsViewModel,
    onBack: () -> Unit
) {
    val state by viewModel.uiState.collectAsState()
    var showGuidanceDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Success Journey") },
                navigationIcon = { IconButton(onClick = onBack) { Text("<") } }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState())
        ) {
            when (val s = state) {
                is StoryDetailsState.Loading -> CircularProgressIndicator()
                is StoryDetailsState.Success -> {
                    val story = s.story
                    Text(text = "The Journey to Success", style = MaterialTheme.typography.headlineMedium)
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    Section("Journey Summary", story.journey_summary)
                    Section("My Strategy", story.strategy ?: "N/A")
                    Section("Challenges I Faced", story.challenges_faced ?: "N/A")
                    Section("Mistakes to Avoid", story.mistakes_avoided ?: "N/A")
                    Section("Document Preparation Tips", story.document_tips ?: "N/A")

                    Spacer(modifier = Modifier.height(24.dp))
                    Button(
                        onClick = { showGuidanceDialog = true },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Request Guidance from Mentor")
                    }
                }
                is StoryDetailsState.Error -> Text("Error: ${s.message}")
            }
        }
    }

    if (showGuidanceDialog) {
        GuidanceRequestDialog(
            onDismiss = { showGuidanceDialog = false },
            onSubmit = { subject, msg ->
                val s = state as? StoryDetailsState.Success
                s?.let { 
                    viewModel.requestGuidance(it.story.opportunity_id, it.story.student_id, subject, msg)
                }
                showGuidanceDialog = false
            }
        )
    }
}

@Composable
fun Section(title: String, content: String) {
    Column(modifier = Modifier.padding(vertical = 8.dp)) {
        Text(text = title, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
        Text(text = content, style = MaterialTheme.typography.bodyLarge)
        HorizontalDivider(modifier = Modifier.padding(top = 8.dp))
    }
}

@Composable
fun GuidanceRequestDialog(onDismiss: () -> Unit, onSubmit: (String, String) -> Unit) {
    var subject by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Request Guidance") },
        text = {
            Column {
                OutlinedTextField(value = subject, onValueChange = { subject = it }, label = { Text("Subject") })
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(value = message, onValueChange = { message = it }, label = { Text("Message") }, minLines = 3)
            }
        },
        confirmButton = {
            Button(onClick = { onSubmit(subject, message) }) { Text("Send Request") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
