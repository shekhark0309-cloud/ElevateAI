package com.elevateai.app.m3.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elevateai.app.m3.data.models.IdeaValidation
import com.elevateai.app.m3.data.repository.InnovationRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class ValidationState {
    object Idle : ValidationState()
    object Processing : ValidationState()
    data class Result(val validation: IdeaValidation) : ValidationState()
    data class Error(val message: String) : ValidationState()
}

class IdeaValidationViewModel(private val repository: InnovationRepository) : ViewModel() {

    private val _state = MutableStateFlow<ValidationState>(ValidationState.Idle)
    val state: StateFlow<ValidationState> = _state

    fun validate(title: String, description: String, problem: String?, solution: String?) {
        viewModelScope.launch {
            _state.value = ValidationState.Processing
            try {
                val res = repository.validateIdea(title, description, problem, solution)
                _state.value = ValidationState.Result(res)
            } catch (e: Exception) {
                _state.value = ValidationState.Error(e.message ?: "Validation failed")
            }
        }
    }
}
