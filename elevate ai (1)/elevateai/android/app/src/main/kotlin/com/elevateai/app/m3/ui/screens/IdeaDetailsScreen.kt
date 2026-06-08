package com.elevateai.app.m3.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.elevateai.app.m3.ui.viewmodel.IdeaDetailsState
import com.elevateai.app.m3.ui.viewmodel.IdeaDetailsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun IdeaDetailsScreen(
    viewModel: IdeaDetailsViewModel,
    studentId: String,
    onBack: () -> Unit
) {
    val state by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Idea Details") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Text("<") }
                }
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
                is IdeaDetailsState.Loading -> CircularProgressIndicator()
                is IdeaDetailsState.Success -> {
                    val idea = s.idea
                    Text(text = idea.title, style = MaterialTheme.typography.headlineMedium)
                    Text(text = "Stage: ${idea.stage}", color = MaterialTheme.colorScheme.primary)
                    
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(text = "Problem Statement", style = MaterialTheme.typography.titleMedium)
                    Text(text = idea.problem_statement ?: "No problem statement provided.")

                    Spacer(modifier = Modifier.height(16.dp))
                    Text(text = "Solution", style = MaterialTheme.typography.titleMedium)
                    Text(text = idea.solution ?: "No solution provided.")

                    Spacer(modifier = Modifier.height(16.dp))
                    Text(text = "Required Skills", style = MaterialTheme.typography.titleMedium)
                    idea.required_skills.forEach { skill ->
                        SuggestionChip(onClick = {}, label = { Text(skill) })
                    }

                    Spacer(modifier = Modifier.height(24.dp))
                    Button(
                        onClick = { viewModel.joinIdea(studentId) },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !idea.collaborators.contains(studentId)
                    ) {
                        Text(if (idea.collaborators.contains(studentId)) "Already a Member" else "Join Team")
                    }
                }
                is IdeaDetailsState.Error -> Text("Error: ${s.message}")
            }
        }
    }
}
