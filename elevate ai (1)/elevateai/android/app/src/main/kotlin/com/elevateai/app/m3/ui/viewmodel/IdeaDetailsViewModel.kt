package com.elevateai.app.m3.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elevateai.app.m3.data.models.ProjectIdea
import com.elevateai.app.m3.data.repository.InnovationRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class IdeaDetailsState {
    object Loading : IdeaDetailsState()
    data class Success(val idea: ProjectIdea) : IdeaDetailsState()
    data class Error(val message: String) : IdeaDetailsState()
}

class IdeaDetailsViewModel(
    private val repository: InnovationRepository,
    private val ideaId: String
) : ViewModel() {

    private val _uiState = MutableStateFlow<IdeaDetailsState>(IdeaDetailsState.Loading)
    val uiState: StateFlow<IdeaDetailsState> = _uiState

    init {
        loadDetails()
        observeUpdates()
    }

    private fun loadDetails() {
        viewModelScope.launch {
            try {
                val idea = repository.getIdeaDetails(ideaId)
                _uiState.value = IdeaDetailsState.Success(idea)
            } catch (e: Exception) {
                _uiState.value = IdeaDetailsState.Error(e.message ?: "Failed to load details")
            }
        }
    }

    private fun observeUpdates() {
        viewModelScope.launch {
            repository.subscribeToIdeaUpdates(ideaId).collect {
                loadDetails() // Refresh on update
            }
        }
    }

    fun joinIdea(studentId: String) {
        viewModelScope.launch {
            try {
                repository.joinIdea(ideaId, studentId)
                loadDetails()
            } catch (e: Exception) {
                // Handle error
            }
        }
    }
}
