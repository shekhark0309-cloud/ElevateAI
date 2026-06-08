import 'package:flutter/material.dart';
import '../flutter_integration.dart';

class SLGVisualizationScreen extends StatefulWidget {
  const SLGVisualizationScreen({super.key});

  @override
  State<SLGVisualizationScreen> createState() => _SLGVisualizationScreenState();
}

class _SLGVisualizationScreenState extends State<SLGVisualizationScreen> {
  final _taskService = TaskService();
  final _taskController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _tasks = [];
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await _taskService.getMyTasks();
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addTask() async {
    if (_taskController.text.trim().isEmpty) return;
    try {
      await _taskService.addTask(_taskController.text.trim());
      _taskController.clear();
      _loadTasks();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _toggleTask(String id, bool? value) async {
    if (value == null) return;
    try {
      await _taskService.toggleTask(id, value);
      _loadTasks();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('To do', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildTaskInput(),
              const SizedBox(height: 24),
              _buildCategoryFilters(),
              const SizedBox(height: 32),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_tasks.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Text('No tasks for today. Add one above!', style: TextStyle(color: Colors.grey)),
                ))
              else
                _buildTodaySchedule(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _taskController,
        onSubmitted: (_) => _addTask(),
        decoration: InputDecoration(
          hintText: 'Add a task...',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: const Icon(Icons.add, color: Color(0xFF6200EE)),
          suffixIcon: IconButton(
            icon: const Icon(Icons.send_rounded, color: Color(0xFF6200EE), size: 20),
            onPressed: _addTask,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('All'),
          _filterChip('Task'),
          _filterChip('Event'),
          _filterChip('Deadline'),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    final active = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6200EE) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: active ? const Color(0xFF6200EE) : Colors.grey.shade200),
          boxShadow: active ? [BoxShadow(color: const Color(0xFF6200EE).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySchedule() {
    final filteredTasks = _selectedFilter == 'All'
        ? _tasks
        : _tasks.where((t) => t['category'] == _selectedFilter.toLowerCase()).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Today\'s Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        ...filteredTasks.map((task) => _agendaItem(
          task['id'],
          task['title'],
          task['due_at'] != null ? 'Due: ${task['due_at'].toString().split('T')[0]}' : 'No deadline',
          _getCategoryColor(task['category']),
          task['is_completed'] ?? false,
        )),
      ],
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'event': return Colors.blue;
      case 'deadline': return Colors.red;
      case 'study': return Colors.teal;
      default: return Colors.orange;
    }
  }

  Widget _agendaItem(String id, String title, String time, Color color, bool isDone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? Colors.grey : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(time, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ],
                ),
              ),
            ),
            Checkbox(
              value: isDone,
              onChanged: (v) => _toggleTask(id, v),
              activeColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
