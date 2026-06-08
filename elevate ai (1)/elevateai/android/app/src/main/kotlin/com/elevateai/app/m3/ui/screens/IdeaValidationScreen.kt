package com.elevateai.app.m3.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.elevateai.app.m3.ui.viewmodel.IdeaValidationViewModel
import com.elevateai.app.m3.ui.viewmodel.ValidationState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun IdeaValidationScreen(
    viewModel: IdeaValidationViewModel,
    onBack: () -> Unit
) {
    var title by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var problem by remember { mutableStateOf("") }
    var solution by remember { mutableStateOf("") }

    val state by viewModel.state.collectAsState()

    Scaffold(
        topBar = { TopAppBar(title = { Text("AI Idea Validator") }) }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState())
        ) {
            if (state is ValidationState.Idle || state is ValidationState.Processing) {
                OutlinedTextField(value = title, onValueChange = { title = it }, label = { Text("Idea Name") }, modifier = Modifier.fillMaxWidth())
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(value = description, onValueChange = { description = it }, label = { Text("Description") }, modifier = Modifier.fillMaxWidth())
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(value = problem, onValueChange = { problem = it }, label = { Text("Problem Statement") }, modifier = Modifier.fillMaxWidth())
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(value = solution, onValueChange = { solution = it }, label = { Text("Proposed Solution") }, modifier = Modifier.fillMaxWidth())
                
                Spacer(modifier = Modifier.height(24.dp))
                Button(
                    onClick = { viewModel.validate(title, description, problem, solution) },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = state !is ValidationState.Processing
                ) {
                    if (state is ValidationState.Processing) CircularProgressIndicator(color = MaterialTheme.colorScheme.onPrimary)
                    else Text("Analyze with AI")
                }
            }

            if (state is ValidationState.Result) {
                val res = (state as ValidationState.Result).validation
                Text("AI Analysis Result", style = MaterialTheme.typography.headlineSmall)
                Text("Innovation Score: ${res.innovation_score}/100")
                Text("Feasibility: ${res.feasibility_score}/100")
                Text("Market Potential: ${res.market_potential}")
                
                Spacer(modifier = Modifier.height(16.dp))
                Text("Suggested Improvements:", style = MaterialTheme.typography.titleMedium)
                res.suggested_improvements.forEach { Text("• $it") }

                Spacer(modifier = Modifier.height(24.dp))
                Button(onClick = { /* Save Idea Logic */ }, modifier = Modifier.fillMaxWidth()) {
                    Text("Save & Post Idea")
                }
                TextButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) {
                    Text("Back to Hub")
                }
            }
        }
    }
}
