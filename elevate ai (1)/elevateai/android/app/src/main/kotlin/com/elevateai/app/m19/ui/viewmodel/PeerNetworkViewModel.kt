package com.elevateai.app.m19.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elevateai.app.m19.data.models.SuccessStoryFeedItem
import com.elevateai.app.m19.data.repository.PeerNetworkRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class PeerNetworkState {
    object Loading : PeerNetworkState()
    data class Success(val stories: List<SuccessStoryFeedItem>) : PeerNetworkState()
    data class Error(val message: String) : PeerNetworkState()
}

class PeerNetworkViewModel(
    private val repository: PeerNetworkRepository,
    private val studentId: String
) : ViewModel() {

    private val _uiState = MutableStateFlow<PeerNetworkState>(PeerNetworkState.Loading)
    val uiState: StateFlow<PeerNetworkState> = _uiState

    init {
        loadFeed()
    }

    fun loadFeed() {
        viewModelScope.launch {
            _uiState.value = PeerNetworkState.Loading
            try {
                val feed = repository.getSuccessStoryFeed(studentId)
                _uiState.value = PeerNetworkState.Success(feed)
            } catch (e: Exception) {
                _uiState.value = PeerNetworkState.Error(e.message ?: "Failed to load peer network feed")
            }
        }
    }
}
