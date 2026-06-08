package com.elevateai.app.m18.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.elevateai.app.m18.ui.viewmodel.ChatMessage
import com.elevateai.app.m18.ui.viewmodel.ChatState
import com.elevateai.app.m18.ui.viewmodel.SchemeBuddyViewModel
import kotlinx.serialization.json.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SchemeBuddyScreen(viewModel: SchemeBuddyViewModel, onNavigate: (String) -> Unit = {}) {
    val messages by viewModel.messages.collectAsState()
    val chatState by viewModel.chatState.collectAsState()
    val selectedLanguage by viewModel.selectedLanguage.collectAsState()
    val journeyState by viewModel.journeyState.collectAsState()
    var inputText by remember { mutableStateOf("") }
    var showJourney by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Scheme Buddy Chat") },
                actions = {
                    LanguageSwitcher(
                        selectedLanguage = selectedLanguage,
                        onLanguageSelected = { viewModel.setLanguage(it) }
                    )
                }
            )
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize()) {
            
            // Journey Drawer / Overlay
            AnimatedVisibility(visible = showJourney) {
                ScholarshipJourneyView(journeyState, onNavigate, onClose = { showJourney = false })
            }

            LazyColumn(
                modifier = Modifier.weight(1f).padding(horizontal = 16.dp),
                reverseLayout = false
            ) {
                items(messages) { msg ->
                    ChatBubble(msg, onAction = { 
                        // If AI suggests a scheme, we can trigger journey load
                        // For demo, we just trigger on specific keywords or a dedicated button
                        viewModel.loadScholarshipJourney("some-scholarship-uuid")
                        showJourney = true
                    })
                }
                if (chatState is ChatState.Sending) {
                    item {
                        Text("Buddy is thinking...", style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(8.dp))
                    }
                }
            }

            if (chatState is ChatState.Error) {
                Text(
                    text = (chatState as ChatState.Error).message,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(16.dp)
                )
            }

            Row(
                modifier = Modifier.padding(16.dp).fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = inputText,
                    onValueChange = { inputText = it },
                    modifier = Modifier.weight(1f),
                    placeholder = { Text("Ask in any language...") },
                    maxLines = 3
                )
                Spacer(modifier = Modifier.width(8.dp))
                Button(
                    onClick = {
                        viewModel.sendMessage(inputText)
                        inputText = ""
                    },
                    enabled = chatState !is ChatState.Sending && inputText.isNotBlank()
                ) {
                    Text("Send")
                }
            }
        }
    }
}

@Composable
fun ScholarshipJourneyView(state: com.elevateai.app.m18.ui.viewmodel.ScholarshipJourneyState, onNavigate: (String) -> Unit, onClose: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Default.Route, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("Complete Scholarship Journey", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.weight(1f))
                IconButton(onClick = onClose) { Icon(Icons.Default.Close, contentDescription = "Close") }
            }
            
            if (state.isLoading) {
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp))
            }

            state.path?.let { path ->
                val prob = path["success_probability"]?.jsonPrimitive?.content ?: "0"
                Text("Success Probability: $prob%", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                Text("Next Step: ${path["reason"]?.jsonPrimitive?.content ?: "Prepare documents"}", style = MaterialTheme.typography.bodySmall)
                
                Spacer(modifier = Modifier.height(12.dp))
                Text("PEERS WHO SUCCEEDED", style = MaterialTheme.typography.labelSmall)
                state.peers?.forEach { peer ->
                    val p = peer.jsonObject
                    Card(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                        Row(modifier = Modifier.padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.AccountCircle, contentDescription = null)
                            Spacer(modifier = Modifier.width(8.dp))
                            Column {
                                Text(p["peer_name"]?.jsonPrimitive?.content ?: "Peer", style = MaterialTheme.typography.bodyMedium)
                                Text("TrustScore: ${p["peer_trust_score"]?.jsonPrimitive?.content ?: "0"}", style = MaterialTheme.typography.labelSmall)
                            }
                            Spacer(modifier = Modifier.weight(1f))
                            TextButton(onClick = { onNavigate("/chat?user=${p["peer_id"]?.jsonPrimitive?.content}") }) {
                                Text("ASK HELP")
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ChatBubble(message: ChatMessage, onAction: () -> Unit) {
    val isUser = message.role == "user"
    val alignment = if (isUser) Alignment.CenterEnd else Alignment.CenterStart
    val color = if (isUser) MaterialTheme.colorScheme.primary else Color(0xFFF0F0F0)
    val textColor = if (isUser) MaterialTheme.colorScheme.onPrimary else Color.Black

    Column(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalAlignment = if (isUser) Alignment.End else Alignment.Start) {
        Surface(
            color = color,
            shape = RoundedCornerShape(
                topStart = 16.dp,
                topEnd = 16.dp,
                bottomStart = if (isUser) 16.dp else 0.dp,
                bottomEnd = if (isUser) 0.dp else 16.dp
            )
        ) {
            Text(
                text = message.content,
                modifier = Modifier.padding(12.dp),
                color = textColor
            )
        }
        
        if (!isUser && message.content.contains("scholarship", ignoreCase = true)) {
            TextButton(onClick = onAction) {
                Text("VIEW SUCCESS JOURNEY →", style = MaterialTheme.typography.labelLarge)
            }
        }
    }
}

@Composable
fun LanguageSwitcher(selectedLanguage: String, onLanguageSelected: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    val languages = mapOf(
        "auto" to "Auto ✨",
        "english" to "English",
        "hindi" to "Hindi",
        "marathi" to "Marathi",
        "telugu" to "Telugu"
    )

    Box {
        TextButton(onClick = { expanded = true }) {
            Text(languages[selectedLanguage] ?: "Language")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            languages.forEach { (key, label) ->
                DropdownMenuItem(
                    text = { Text(label) },
                    onClick = {
                        onLanguageSelected(key)
                        expanded = false
                    }
                )
            }
        }
    }
}
