package com.elevateai.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.lifecycle.viewmodel.compose.viewModel
import com.elevateai.app.dashboard.ui.screens.OSDashboardScreen
import com.elevateai.app.dashboard.ui.viewmodel.OSDashboardViewModel
import com.elevateai.app.dashboard.data.repository.DashboardRepository
import com.elevateai.app.m5.ui.screens.FocusModeScreen
import com.elevateai.app.m5.ui.viewmodel.FocusViewModel
import com.elevateai.app.m5.data.repository.FocusRepository
import com.elevateai.app.m19.ui.screens.PeerNetworkScreen
import com.elevateai.app.m19.ui.viewmodel.PeerNetworkViewModel
import com.elevateai.app.m19.data.repository.PeerNetworkRepository
import com.elevateai.app.m7.ui.screens.CareerReadinessScreen
import com.elevateai.app.m7.ui.viewmodel.CareerPredictorViewModel
import com.elevateai.app.m7.data.repository.CareerRepository
import com.elevateai.app.m2.ui.screens.TeamFinderScreen
import com.elevateai.app.m2.ui.viewmodel.TeamFinderViewModel
import com.elevateai.app.m2.data.repository.TeamRepository
import com.elevateai.app.m18.ui.screens.SchemeBuddyScreen
import com.elevateai.app.m18.ui.viewmodel.SchemeBuddyViewModel
import com.elevateai.app.m18.data.repository.SchemeBuddyRepository
import io.github.jan_tennert.supabase.gotrue.gotrue
import kotlinx.coroutines.runBlocking

class NativeHostActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val initialRoute = intent.getStringExtra("route") ?: "dashboard"
        val sessionJson = intent.getStringExtra("session")

        // Sync session before rendering
        runBlocking {
            SupabaseManager.syncSession(sessionJson)
        }

        val supabase = SupabaseManager.getClient()
        val studentId = supabase.gotrue.currentSessionOrNull()?.user?.id ?: ""

        setContent {
            var currentRoute by remember { mutableStateOf(initialRoute) }

            val handleNavigation: (String) -> Unit = { target ->
                when (target) {
                    "dashboard", "scheme_buddy", "focus_mode", "peer_network", "career_predictor", "team_finder" -> {
                        currentRoute = target
                    }
                    else -> {
                        // Return to Flutter for handling (e.g. /chat, /profile)
                        finishWithResult(mapOf("target" to target))
                    }
                }
            }

            MaterialTheme {
                Surface {
                    when (currentRoute) {
                        "dashboard" -> {
                            val repository = DashboardRepository(supabase)
                            val vm: OSDashboardViewModel = viewModel { OSDashboardViewModel(repository, studentId) }
                            OSDashboardScreen(vm, onNavigate = handleNavigation)
                        }
                        "scheme_buddy" -> {
                            val repository = SchemeBuddyRepository(supabase)
                            val vm: SchemeBuddyViewModel = viewModel { SchemeBuddyViewModel(repository, studentId) }
                            SchemeBuddyScreen(vm, onNavigate = handleNavigation)
                        }
                        "focus_mode" -> {
                            val repository = FocusRepository(supabase)
                            val vm: FocusViewModel = viewModel { FocusViewModel(repository, studentId) }
                            FocusModeScreen(vm)
                        }
                        "peer_network" -> {
                            val repository = PeerNetworkRepository(supabase)
                            val vm: PeerNetworkViewModel = viewModel { PeerNetworkViewModel(repository, studentId) }
                            PeerNetworkScreen(vm)
                        }
                        "career_predictor" -> {
                            val repository = CareerRepository(supabase)
                            val vm: CareerPredictorViewModel = viewModel { CareerPredictorViewModel(repository, studentId) }
                            CareerReadinessScreen(vm)
                        }
                        "team_finder" -> {
                            val repository = TeamRepository(supabase)
                            val vm: TeamFinderViewModel = viewModel { TeamFinderViewModel(repository, studentId) }
                            TeamFinderScreen(vm)
                        }
                    }
                }
            }
        }
    }

    fun finishWithResult(data: Map<String, Any>) {
        val intent = Intent()
        data.forEach { (k, v) ->
            when(v) {
                is String -> intent.putExtra(k, v)
                is Int -> intent.putExtra(k, v)
                is Boolean -> intent.putExtra(k, v)
            }
        }
        setResult(RESULT_OK, intent)
        finish()
    }
}
