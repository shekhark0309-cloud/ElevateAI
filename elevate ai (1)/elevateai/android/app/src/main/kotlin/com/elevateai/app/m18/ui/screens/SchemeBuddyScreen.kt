package com.elevateai.app.m18.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.elevateai.app.m18.ui.viewmodel.ChatMessage
import com.elevateai.app.m18.ui.viewmodel.ChatState
import com.elevateai.app.m18.ui.viewmodel.SchemeBuddyViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SchemeBuddyScreen(viewModel: SchemeBuddyViewModel) {
    val messages by viewModel.messages.collectAsState()
    val chatState by viewModel.chatState.collectAsState()
    val selectedLanguage by viewModel.selectedLanguage.collectAsState()
    var inputText by remember { mutableStateOf("") }

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
            LazyColumn(
                modifier = Modifier.weight(1f).padding(horizontal = 16.dp),
                reverseLayout = false
            ) {
                items(messages) { msg ->
                    ChatBubble(msg)
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
fun ChatBubble(message: ChatMessage) {
    val isUser = message.role == "user"
    val alignment = if (isUser) Alignment.CenterEnd else Alignment.CenterStart
    val color = if (isUser) MaterialTheme.colorScheme.primary else Color(0xFFF0F0F0)
    val textColor = if (isUser) MaterialTheme.colorScheme.onPrimary else Color.Black

    Box(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp), contentAlignment = alignment) {
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
