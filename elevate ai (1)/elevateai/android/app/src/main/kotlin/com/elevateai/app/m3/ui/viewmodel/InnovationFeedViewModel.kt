package com.elevateai.app.m3.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elevateai.app.m3.data.models.IdeaFeedItem
import com.elevateai.app.m3.data.repository.InnovationRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class InnovationFeedState {
    object Loading : InnovationFeedState()
    data class Success(val ideas: List<IdeaFeedItem>) : InnovationFeedState()
    data class Error(val message: String) : InnovationFeedState()
}

class InnovationFeedViewModel(
    private val repository: InnovationRepository,
    private val studentId: String
) : ViewModel() {

    private val _uiState = MutableStateFlow<InnovationFeedState>(InnovationFeedState.Loading)
    val uiState: StateFlow<InnovationFeedState> = _uiState

    init {
        loadFeed()
    }

    fun loadFeed(sortBy: String = "trending", category: String = "All") {
        viewModelScope.launch {
            _uiState.value = InnovationFeedState.Loading
            try {
                val feed = repository.getDiscoveryFeed(studentId, sortBy, category)
                _uiState.value = InnovationFeedState.Success(feed)
            } catch (e: Exception) {
                _uiState.value = InnovationFeedState.Error(e.message ?: "Failed to load feed")
            }
        }
    }
}
