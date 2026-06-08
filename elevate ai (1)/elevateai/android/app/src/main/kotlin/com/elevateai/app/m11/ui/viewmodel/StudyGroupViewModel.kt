package com.elevateai.app.m11.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elevateai.app.m11.data.models.StudyGroup
import com.elevateai.app.m11.data.repository.CampusConnectRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class StudyGroupState {
    object Loading : StudyGroupState()
    data class Success(val groups: List<StudyGroup>) : StudyGroupState()
    data class Error(val message: String) : StudyGroupState()
}

class StudyGroupViewModel(
    private val repository: CampusConnectRepository,
    private val studentId: String
) : ViewModel() {

    private val _uiState = MutableStateFlow<StudyGroupState>(StudyGroupState.Loading)
    val uiState: StateFlow<StudyGroupState> = _uiState

    init {
        loadGroups()
    }

    fun loadGroups() {
        viewModelScope.launch {
            _uiState.value = StudyGroupState.Loading
            try {
                val groups = repository.getStudyGroups(studentId)
                _uiState.value = StudyGroupState.Success(groups)
            } catch (e: Exception) {
                _uiState.value = StudyGroupState.Error(e.message ?: "Failed to load study groups")
            }
        }
    }

    fun createGroup(name: String, tagline: String) {
        viewModelScope.launch {
            try {
                repository.createStudyGroup(StudyGroup(id = "", name = name, tagline = tagline, leader_id = studentId))
                loadGroups()
            } catch (e: Exception) {
                // Handle error
            }
        }
    }
}
