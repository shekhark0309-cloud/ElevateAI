package com.elevateai.app.m1.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elevateai.app.m1.data.models.OpportunitySection
import com.elevateai.app.m1.data.models.RankedOpportunity
import com.elevateai.app.m1.data.repository.OpportunityRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class OpportunityFeedState {
    object Loading : OpportunityFeedState()
    data class Success(val sections: List<OpportunitySection>) : OpportunityFeedState()
    data class Error(val message: String) : OpportunityFeedState()
}

class OpportunityFeedViewModel(
    private val repository: OpportunityRepository,
    private val studentId: String
) : ViewModel() {

    private val _uiState = MutableStateFlow<OpportunityFeedState>(OpportunityFeedState.Loading)
    val uiState: StateFlow<OpportunityFeedState> = _uiState

    init {
        loadFeed()
        listenForRealtime()
    }

    fun loadFeed() {
        viewModelScope.launch {
            _uiState.value = OpportunityFeedState.Loading
            try {
                val allOpps = repository.getRankedOpportunities(studentId)
                
                val sections = mutableListOf<OpportunitySection>()

                // 1. Best Matches (Top Score)
                val bestMatches = allOpps.filter { it.match_score > 70 }.take(5)
                if (bestMatches.isNotEmpty()) {
                    sections.add(OpportunitySection("Best Matches for You", bestMatches))
                }

                // 2. Hackathons For You
                val hackathons = allOpps.filter { it.type == "hackathon" }.take(5)
                if (hackathons.isNotEmpty()) {
                    sections.add(OpportunitySection("Hackathons For You", hackathons))
                }

                // 3. Career Boosters (Internships/Jobs)
                val boosters = allOpps.filter { it.type == "internship" || it.type == "fellowship" }.take(5)
                if (boosters.isNotEmpty()) {
                    sections.add(OpportunitySection("Career Boosters", boosters))
                }

                // 4. Stretch Opportunities (Outside comfort zone)
                val stretch = allOpps.filter { it.is_stretch_opportunity }.take(3)
                if (stretch.isNotEmpty()) {
                    sections.add(OpportunitySection("Explore New Horizons", stretch))
                }

                _uiState.value = OpportunityFeedState.Success(sections)
            } catch (e: Exception) {
                _uiState.value = OpportunityFeedState.Error(e.message ?: "Failed to load feed")
            }
        }
    }

    private fun listenForRealtime() {
        viewModelScope.launch {
            repository.observeApplications(studentId).collect {
                loadFeed()
            }
        }
    }
}
