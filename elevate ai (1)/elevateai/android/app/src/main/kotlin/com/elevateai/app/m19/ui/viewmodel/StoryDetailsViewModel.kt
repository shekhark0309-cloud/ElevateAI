package com.elevateai.app.m19.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elevateai.app.m19.data.models.SuccessStory
import com.elevateai.app.m19.data.repository.PeerNetworkRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class StoryDetailsState {
    object Loading : StoryDetailsState()
    data class Success(val story: SuccessStory) : StoryDetailsState()
    data class Error(val message: String) : StoryDetailsState()
}

class StoryDetailsViewModel(
    private val repository: PeerNetworkRepository,
    private val storyId: String
) : ViewModel() {

    private val _uiState = MutableStateFlow<StoryDetailsState>(StoryDetailsState.Loading)
    val uiState: StateFlow<StoryDetailsState> = _uiState

    init {
        loadDetails()
    }

    private fun loadDetails() {
        viewModelScope.launch {
            try {
                val details = repository.getStoryDetails(storyId)
                _uiState.value = StoryDetailsState.Success(details)
            } catch (e: Exception) {
                _uiState.value = StoryDetailsState.Error(e.message ?: "Failed to load story details")
            }
        }
    }

    fun requestGuidance(opportunityId: String, mentorId: String, subject: String, message: String) {
        viewModelScope.launch {
            try {
                repository.requestGuidance(mentorId, opportunityId, subject, message)
            } catch (e: Exception) {
                // Handle error
            }
        }
    }
}
