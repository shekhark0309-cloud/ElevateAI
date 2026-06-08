package com.elevateai.app.m4.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elevateai.app.m4.data.models.Notification
import com.elevateai.app.m4.data.models.PriorityAlert
import com.elevateai.app.m4.data.repository.NotificationRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class NotificationState {
    object Loading : NotificationState()
    data class Success(val notifications: List<Notification>) : NotificationState()
    data class Error(val message: String) : NotificationState()
}

class FocusAIViewModel(
    private val repository: NotificationRepository,
    private val studentId: String
) : ViewModel() {

    private val _uiState = MutableStateFlow<NotificationState>(NotificationState.Loading)
    val uiState: StateFlow<NotificationState> = _uiState

    private val _aiPriorities = MutableStateFlow<List<PriorityAlert>>(emptyList())
    val aiPriorities: StateFlow<List<PriorityAlert>> = _aiPriorities

    init {
        loadNotifications()
        loadAIPriorities()
        listenForRealtime()
    }

    fun loadNotifications(priority: String? = null, unreadOnly: Boolean = false) {
        viewModelScope.launch {
            _uiState.value = NotificationState.Loading
            try {
                val list = repository.getNotifications(studentId, priority, unreadOnly)
                _uiState.value = NotificationState.Success(list)
            } catch (e: Exception) {
                _uiState.value = NotificationState.Error(e.message ?: "Unknown Error")
            }
        }
    }

    private fun loadAIPriorities() {
        viewModelScope.launch {
            try {
                _aiPriorities.value = repository.getAIPriorities(studentId)
            } catch (e: Exception) {
                // Ignore silent fail for dashboard
            }
        }
    }

    fun markAsRead(id: String) {
        viewModelScope.launch {
            repository.markAsRead(id)
            loadNotifications()
        }
    }

    private fun listenForRealtime() {
        viewModelScope.launch {
            repository.observeNotifications(studentId).collect {
                loadNotifications()
                loadAIPriorities()
            }
        }
    }
}
