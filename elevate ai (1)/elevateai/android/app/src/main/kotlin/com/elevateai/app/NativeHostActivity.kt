package com.elevateai.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
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
import io.github.jan_tennert.supabase.gotrue.gotrue
import kotlinx.coroutines.runBlocking

class NativeHostActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val route = intent.getStringExtra("route") ?: "dashboard"
        val sessionJson = intent.getStringExtra("session")

        // Sync session before rendering
        runBlocking {
            SupabaseManager.syncSession(sessionJson)
        }

        val supabase = SupabaseManager.getClient()
        val studentId = supabase.gotrue.currentSessionOrNull()?.user?.id ?: ""

        setContent {
            MaterialTheme {
                Surface {
                    when (route) {
                        "dashboard" -> {
                            val repository = DashboardRepository(supabase)
                            val vm: OSDashboardViewModel = viewModel { OSDashboardViewModel(repository, studentId) }
                            OSDashboardScreen(vm, onNavigate = { /* Handle native-to-native or native-to-flutter */ })
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
