package com.elevateai.app.m18.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elevateai.app.m18.data.repository.SchemeBuddyRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.*

data class ChatMessage(val role: String, val content: String)

sealed class ChatState {
    object Idle : ChatState()
    object Sending : ChatState()
    data class Error(val message: String) : ChatState()
}

data class ScholarshipJourneyState(
    val path: JsonObject? = null,
    val peers: JsonArray? = null,
    val isLoading: Boolean = false,
    val error: String? = null
)

class SchemeBuddyViewModel(
    private val repository: SchemeBuddyRepository,
    private val studentId: String
) : ViewModel() {

    private val _messages = MutableStateFlow<List<ChatMessage>>(listOf(
        ChatMessage("assistant", "Hello! I am your Scheme Buddy. I can help you find government scholarships and guide you with documents in English, Hindi, Marathi, or Telugu. How can I help?")
    ))
    val messages: StateFlow<List<ChatMessage>> = _messages

    private val _chatState = MutableStateFlow<ChatState>(ChatState.Idle)
    val chatState: StateFlow<ChatState> = _chatState

    private val _selectedLanguage = MutableStateFlow("auto")
    val selectedLanguage: StateFlow<String> = _selectedLanguage

    private val _journeyState = MutableStateFlow(ScholarshipJourneyState())
    val journeyState: StateFlow<ScholarshipJourneyState> = _journeyState

    fun setLanguage(lang: String) {
        _selectedLanguage.value = lang
    }

    fun sendMessage(text: String) {
        if (text.isBlank()) return

        val currentMessages = _messages.value.toMutableList()
        currentMessages.add(ChatMessage("user", text))
        _messages.value = currentMessages

        viewModelScope.launch {
            _chatState.value = ChatState.Sending
            try {
                val history = buildJsonArray {
                    _messages.value.dropLast(1).forEach { msg ->
                        add(buildJsonObject {
                            put("role", msg.role)
                            put("content", msg.content)
                        })
                    }
                }

                val response = repository.chat(studentId, text, _selectedLanguage.value, history)
                val reply = response["reply"]?.jsonPrimitive?.content ?: "Sorry, I couldn't process that."
                
                val updatedMessages = _messages.value.toMutableList()
                updatedMessages.add(ChatMessage("assistant", reply))
                _messages.value = updatedMessages
                _chatState.value = ChatState.Idle
            } catch (e: Exception) {
                _chatState.value = ChatState.Error(e.message ?: "Failed to get reply")
            }
        }
    }

    fun loadScholarshipJourney(opportunityId: String) {
        viewModelScope.launch {
            _journeyState.value = _journeyState.value.copy(isLoading = true, error = null)
            try {
                val path = repository.getSchemePath(studentId, opportunityId)
                val peers = repository.getPeerSuccessStories(studentId, opportunityId)
                _journeyState.value = ScholarshipJourneyState(path = path, peers = peers, isLoading = false)
            } catch (e: Exception) {
                _journeyState.value = ScholarshipJourneyState(error = e.message, isLoading = false)
            }
        }
    }
}
