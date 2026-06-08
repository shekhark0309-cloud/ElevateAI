package com.elevateai.app.m7.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elevateai.app.m7.data.models.CareerIntelligence
import com.elevateai.app.m7.data.repository.CareerRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class CareerState {
    object Loading : CareerState()
    data class Success(val intelligence: CareerIntelligence) : CareerState()
    data class Error(val message: String) : CareerState()
}

class CareerPredictorViewModel(
    private val repository: CareerRepository,
    private val studentId: String
) : ViewModel() {

    private val _uiState = MutableStateFlow<CareerState>(CareerState.Loading)
    val uiState: StateFlow<CareerState> = _uiState

    init {
        loadIntelligence()
        listenForUpdates()
    }

    fun loadIntelligence() {
        viewModelScope.launch {
            _uiState.value = CareerState.Loading
            try {
                val data = repository.getCareerIntelligence(studentId)
                _uiState.value = CareerState.Success(data)
            } catch (e: Exception) {
                _uiState.value = CareerState.Error(e.message ?: "Failed to load career data")
            }
        }
    }

    private fun listenForUpdates() {
        viewModelScope.launch {
            repository.observeCareerUpdates(studentId).collect {
                loadIntelligence() // Trigger refresh on DNA change
            }
        }
    }
}
