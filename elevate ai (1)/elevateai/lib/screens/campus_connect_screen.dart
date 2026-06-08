import 'package:flutter/material.dart';
import '../services/campus_service.dart';
import '../flutter_integration.dart';
import '../models/campus_models.dart';
import '../models/profile_models.dart';
import 'package:go_router/go_router.dart';

class CampusConnectScreen extends StatefulWidget {
  const CampusConnectScreen({super.key});

  @override
  State<CampusConnectScreen> createState() => _CampusConnectScreenState();
}

class _CampusConnectScreenState extends State<CampusConnectScreen> {
  final _campusService = CampusService();
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  List<CampusResource> _resources = [];
  List<ResourceBooking> _bookings = [];
  List<StudentProfile> _studyBuddies = [];
  String? _collegeId;

  // Study Buddy Mode State
  bool _isStudyBuddyMode = false;
  String? _selectedSubject;
  String? _selectedAvailability;
  StudentProfile? _selectedBuddy;

  final List<String> _subjects = [
    'DSA', 'Java', 'Python', 'React', 'Node.js',
    'Android Development', 'Web Development', 'AI/ML',
    'Data Science', 'Cloud Computing', 'Cybersecurity', 'UI/UX', 'Other'
  ];

  final List<String> _availabilityOptions = [
    'Available Now', 'Studying Now', 'Open To Collaboration',
    'Hackathon Interested', 'Project Interested', 'Team Formation Interested'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final profileData = await supabase.from('student_profiles').select().eq('id', user.id).single();
        final profile = StudentProfile.fromJson(profileData);
        _collegeId = profile.collegeId;
        _isStudyBuddyMode = profile.isStudyBuddyMode;
        _selectedSubject = profile.currentStudySubject;
        _selectedAvailability = profile.availabilityStatus;

        if (_collegeId != null) {
          final resources = await _campusService.getCampusResources(_collegeId!);
          final bookings = await _campusService.getMyBookings(user.id);

          if (_isStudyBuddyMode) {
            _studyBuddies = await _campusService.getStudyBuddies(
              collegeId: _collegeId!,
              subject: _selectedSubject,
              availability: _selectedAvailability,
            );
          }

          if (mounted) {
            setState(() {
              _resources = resources;
              _bookings = bookings;
              _isLoading = false;
            });
          }
        } else {
           if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStudyBuddyMode(bool value) async {
    setState(() {
      _isStudyBuddyMode = value;
      _isLoading = true;
      _selectedBuddy = null;
    });

    try {
      await _campusService.updateStudyBuddyMode(
        enabled: value,
        subject: _selectedSubject,
        availability: _selectedAvailability,
      );
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating Study Buddy mode: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Digital Twin', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: _buildViewToggles(),
              ),
              if (_selectedTabIndex == 0) _buildStudyBuddyControls(),
              Expanded(
                child: _selectedTabIndex == 0 ? _buildLiveMap() : _buildBookingsTab(),
              ),
            ],
          ),
    );
  }

  Widget _buildViewToggles() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: _toggleButton(0, 'Live Map')),
          Expanded(child: _toggleButton(1, 'Bookings')),
        ],
      ),
    );
  }

  Widget _toggleButton(int index, String label) {
    final active = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF6200EE) : Colors.grey.shade600,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildStudyBuddyControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.people_outline, color: Color(0xFF6200EE), size: 20),
                  SizedBox(width: 8),
                  Text('Study Buddy Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Switch.adaptive(
                value: _isStudyBuddyMode,
                activeColor: const Color(0xFF6200EE),
                onChanged: _toggleStudyBuddyMode,
              ),
            ],
          ),
          if (_isStudyBuddyMode) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    value: _selectedSubject,
                    hint: 'Select Subject',
                    items: _subjects,
                    onChanged: (val) {
                      setState(() => _selectedSubject = val);
                      _toggleStudyBuddyMode(true);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterDropdown(
                    value: _selectedAvailability,
                    hint: 'Availability',
                    items: _availabilityOptions,
                    onChanged: (val) {
                      setState(() => _selectedAvailability = val);
                      _toggleStudyBuddyMode(true);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 12)),
          isExpanded: true,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildLiveMap() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedBuddy = null),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1523050853063-bd388f85e7ef?q=80&w=2070&auto=format&fit=crop'),
                fit: BoxFit.cover,
                opacity: 0.1,
              ),
            ),
            child: CustomPaint(painter: MapGridPainter()),
          ),
        ),

        // Campus Resources Pins
        ..._resources.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final isAvailable = r.isAvailable;
          final density = isAvailable ? 'Available' : 'Full';
          final color = isAvailable ? Colors.green : Colors.red;

          double top = 100 + (i * 150.0) % 400;
          double left = 50 + (i * 80.0) % 250;

          return Positioned(
            top: top,
            left: left,
            child: _mapPin(
              label: r.name,
              density: density,
              value: isAvailable ? 'High Free' : 'Occupied',
              color: color
            ),
          );
        }),

        // Study Buddy Pins
        if (_isStudyBuddyMode)
          ..._studyBuddies.asMap().entries.map((entry) {
            final i = entry.key;
            final buddy = entry.value;

            // Random-ish positioning for demo purposes, in real app use buddy.latitude/longitude
            double top = 150 + (i * 120.0) % 350;
            double left = 80 + (i * 100.0) % 280;

            return Positioned(
              top: top,
              left: left,
              child: GestureDetector(
                onTap: () => setState(() => _selectedBuddy = buddy),
                child: _studentPin(buddy),
              ),
            );
          }),

        if (_selectedBuddy != null)
          Positioned(
            bottom: 100,
            left: 24,
            right: 24,
            child: _buildBuddyPreviewCard(_selectedBuddy!),
          ),

        Positioned(
          bottom: 24,
          right: 24,
          child: Column(
            children: [
              _mapControl(Icons.add),
              const SizedBox(height: 8),
              _mapControl(Icons.remove),
              const SizedBox(height: 16),
              _mapControl(Icons.my_location, color: const Color(0xFF6200EE)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mapPin({required String label, required String density, required String value, required Color color}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('$density: $value', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        Container(width: 2, height: 10, color: color.withOpacity(0.5)),
      ],
    );
  }

  Widget _studentPin(StudentProfile buddy) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF6200EE),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
          ),
          child: CircleAvatar(
            radius: 16,
            backgroundImage: buddy.avatarUrl != null ? NetworkImage(buddy.avatarUrl!) : null,
            child: buddy.avatarUrl == null ? Text(buddy.fullName[0], style: const TextStyle(color: Colors.white, fontSize: 12)) : null,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)],
          ),
          child: Text(
            buddy.currentStudySubject ?? 'Studying',
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildBuddyPreviewCard(StudentProfile buddy) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: buddy.avatarUrl != null ? NetworkImage(buddy.avatarUrl!) : null,
                  child: buddy.avatarUrl == null ? Text(buddy.fullName[0], style: const TextStyle(fontSize: 24)) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(buddy.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text('${buddy.trustScore ?? 95}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(buddy.currentStudySubject ?? 'General Study', style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Text(buddy.availabilityStatus ?? 'Available', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (buddy.skills != null && buddy.skills!.isNotEmpty)
              SizedBox(
                height: 30,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: buddy.skills!.map((s) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Text(s, style: const TextStyle(fontSize: 10)),
                  )).toList(),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/profile/${buddy.id}'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Profile'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Integration with Team Finder / Invites
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Invitation sent to ${buddy.fullName} for your active team!')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Invite'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.push('/chat/${buddy.id}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6200EE),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Message'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapControl(IconData icon, {Color? color}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Icon(icon, color: color ?? Colors.grey.shade700, size: 20),
    );
  }

  Widget _buildBookingsTab() {
    if (_bookings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No bookings found.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Your Bookings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ..._bookings.map((b) {
          return _bookingCard('Resource ID: ${b.resourceId}', b.bookedFrom.toString(), b.status);
        }),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.calendar_today),
          label: const Text('New Resource Booking'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _bookingCard(String resource, String time, String status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(resource, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(time),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: status == 'Confirmed' || status == 'active' ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(status.toUpperCase(), style: TextStyle(color: status == 'Confirmed' || status == 'active' ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;

    for (var i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i.toDouble(), 0), Offset(i.toDouble(), size.height), paint);
    }
    for (var i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i.toDouble()), Offset(size.width, i.toDouble()), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
