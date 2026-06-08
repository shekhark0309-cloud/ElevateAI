package com.elevateai.app.m13.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elevateai.app.m13.data.models.*
import com.elevateai.app.m13.data.repository.CafeteriaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class CafeteriaState {
    object Loading : CafeteriaState()
    data class Success(
        val preferences: MealPreferences,
        val impact: SustainabilityImpact,
        val menu: DailyMenu
    ) : CafeteriaState()
    data class Error(val message: String) : CafeteriaState()
}

class CafeteriaViewModel(
    private val repository: CafeteriaRepository,
    private val studentId: String
) : ViewModel() {

    private val _uiState = MutableStateFlow<CafeteriaState>(CafeteriaState.Loading)
    val uiState: StateFlow<CafeteriaState> = _uiState

    init {
        loadData()
    }

    fun loadData() {
        viewModelScope.launch {
            _uiState.value = CafeteriaState.Loading
            try {
                val prefs = repository.getMealPreferences(studentId) ?: MealPreferences(studentId, true, true, true)
                val impact = repository.getSustainabilityImpact(studentId)
                
                val currentDay = java.time.LocalDate.now().dayOfWeek.name.lowercase().capitalize()
                val menu = repository.getWeeklyMenu().find { it.day == currentDay } ?: repository.getWeeklyMenu().first()

                _uiState.value = CafeteriaState.Success(prefs, impact, menu)
            } catch (e: Exception) {
                _uiState.value = CafeteriaState.Error(e.message ?: "Failed to load cafeteria data")
            }
        }
    }

    fun toggleMeal(type: String, enabled: Boolean) {
        val currentState = _uiState.value
        if (currentState is CafeteriaState.Success) {
            val newPrefs = when(type) {
                "breakfast" -> currentState.preferences.copy(opt_in_breakfast = enabled)
                "lunch" -> currentState.preferences.copy(opt_in_lunch = enabled)
                "dinner" -> currentState.preferences.copy(opt_in_dinner = enabled)
                else -> currentState.preferences
            }
            
            viewModelScope.launch {
                try {
                    repository.updateMealPreferences(studentId, newPrefs)
                    loadData() // Refresh impact
                } catch (e: Exception) {
                    // Handle error
                }
            }
        }
    }
}
