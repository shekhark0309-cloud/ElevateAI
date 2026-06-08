package com.elevateai.app.m13.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.elevateai.app.m13.ui.viewmodel.CafeteriaState
import com.elevateai.app.m13.ui.viewmodel.CafeteriaViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CafeteriaScreen(viewModel: CafeteriaViewModel) {
    val state by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = { TopAppBar(title = { Text("Hostel & Cafeteria") }) }
    ) { padding ->
        when (val s = state) {
            is CafeteriaState.Loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            is CafeteriaState.Success -> {
                Column(
                    modifier = Modifier
                        .padding(padding)
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(16.dp)
                ) {
                    Text("Today's Menu", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    MenuCard("Breakfast", s.menu.breakfast, s.preferences.opt_in_breakfast) { viewModel.toggleMeal("breakfast", it) }
                    MenuCard("Lunch", s.menu.lunch, s.preferences.opt_in_lunch) { viewModel.toggleMeal("lunch", it) }
                    MenuCard("Dinner", s.menu.dinner, s.preferences.opt_in_dinner) { viewModel.toggleMeal("dinner", it) }

                    Spacer(modifier = Modifier.height(24.dp))
                    Text("Sustainability Impact", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    ImpactCard(s.impact)
                }
            }
            is CafeteriaState.Error -> Text("Error: ${s.message}", color = MaterialTheme.colorScheme.error)
        }
    }
}

@Composable
fun MenuCard(title: String, menu: String, isOptedIn: Boolean, onToggle: (Boolean) -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
        colors = CardDefaults.cardColors(containerColor = if (isOptedIn) MaterialTheme.colorScheme.surface else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(text = title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Text(text = menu, style = MaterialTheme.typography.bodyMedium, color = if (isOptedIn) Color.Unspecified else Color.Gray)
            }
            Switch(
                checked = isOptedIn,
                onCheckedChange = onToggle
            )
        }
    }
}

@Composable
fun ImpactCard(impact: com.elevateai.app.m13.data.models.SustainabilityImpact) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color(0xFFE8F5E9))
    ) {
        Column(modifier = Modifier.padding(20.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Eco, contentDescription = null, tint = Color(0xFF2E7D32))
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = "Your Contribution", style = MaterialTheme.typography.titleMedium, color = Color(0xFF2E7D32), fontWeight = FontWeight.Bold)
            }
            Spacer(modifier = Modifier.height(16.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                ImpactStat("Meals Saved", "${impact.personal_impact.meals_saved}")
                ImpactStat("Food Saved", "${impact.personal_impact.food_saved_kg}kg")
                ImpactStat("CO2 Reduced", "${impact.personal_impact.co2_saved_kg}kg")
            }
            Spacer(modifier = Modifier.height(16.dp))
            Divider(color = Color(0xFFC8E6C9))
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Campus Impact: ${impact.campus_impact.total_food_saved_kg}kg food waste prevented by ${impact.campus_impact.active_students} students.",
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFF1B5E20)
            )
        }
    }
}

@Composable
fun ImpactStat(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(text = value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Black, color = Color(0xFF2E7D32))
        Text(text = label, style = MaterialTheme.typography.labelSmall, color = Color(0xFF4CAF50))
    }
}
