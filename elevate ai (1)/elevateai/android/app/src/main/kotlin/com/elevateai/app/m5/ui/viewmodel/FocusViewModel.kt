package com.elevateai.app.m5.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elevateai.app.m5.data.models.FocusIntelligence
import com.elevateai.app.m5.data.repository.FocusRepository
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class FocusState {
    object Idle : FocusState()
    data class Active(val seconds: Int, val mode: String) : FocusState()
    object Loading : FocusState()
    data class Error(val message: String) : FocusState()
}

class FocusViewModel(
    private val repository: FocusRepository,
    private val studentId: String
) : ViewModel() {

    private val _intelligence = MutableStateFlow<FocusIntelligence?>(null)
    val intelligence: StateFlow<FocusIntelligence?> = _intelligence

    private val _focusState = MutableStateFlow<FocusState>(FocusState.Idle)
    val focusState: StateFlow<FocusState> = _focusState

    private var timerJob: Job? = null

    init {
        loadIntelligence()
    }

    fun loadIntelligence() {
        viewModelScope.launch {
            try {
                val res = repository.getIntelligence(studentId)
                _intelligence.value = res
            } catch (e: Exception) {
                // Handle error
            }
        }
    }

    fun startSession(mode: String = "deep_work") {
        viewModelScope.launch {
            try {
                repository.manageSession("start", mode)
                _focusState.value = FocusState.Active(0, mode)
                startTimer()
            } catch (e: Exception) {
                _focusState.value = FocusState.Error(e.message ?: "Failed to start")
            }
        }
    }

    fun endSession() {
        val currentState = _focusState.value
        if (currentState is FocusState.Active) {
            viewModelScope.launch {
                try {
                    repository.manageSession("end", duration = currentState.seconds)
                    _focusState.value = FocusState.Idle
                    timerJob?.cancel()
                    loadIntelligence() // Refresh stats
                } catch (e: Exception) {
                    // Handle error
                }
            }
        }
    }

    private fun startTimer() {
        timerJob?.cancel()
        timerJob = viewModelScope.launch {
            while (true) {
                delay(1000)
                val current = _focusState.value
                if (current is FocusState.Active) {
                    _focusState.value = current.copy(seconds = current.seconds + 1)
                }
            }
        }
    }
}
