// manage_volunteers_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'add_volunteer_dialog.dart';

class ManageVolunteersScreen extends StatefulWidget {
  final String adminRole;
  final String? adminCampusId;
  final String? adminCohortId;

  const ManageVolunteersScreen({
    super.key,
    required this.adminRole,
    this.adminCampusId,
    this.adminCohortId,
  });

  @override
  State<ManageVolunteersScreen> createState() => _ManageVolunteersScreenState();
}

class _ManageVolunteersScreenState extends State<ManageVolunteersScreen> {
  Future<List<Map<String, dynamic>>>? _userListFuture;
  String? _selectedCampusFilter;
  String? _selectedCohortFilter;

  final List<String> _campusOptions = [
    'All',
    'BKC',
    'CampusB',
    'CampusC',
    'CampusD'
  ];

  final List<String> _allCohortOptions = [
    'All',
    'LP (Leader Panel)',
    'Social Entrepreneurship',
    'Education & Skill Development',
    'Health & Hygiene',
    'Environment & Sustainability',
    'Media & Advocacy',
    'Child Sponsorship Programme',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.adminRole == 'CampusHead') {
      _selectedCampusFilter = widget.adminCampusId;
    } else if (widget.adminRole == 'OverallHead') {
      _selectedCampusFilter = null;
    }
    _selectedCohortFilter = null;
    _fetchUsers();
  }

  Future<List<Map<String, dynamic>>> _getUsersQuery() async {
    var query =
        supabase.from('users').select('*, user_cohort_links(cohort_name)');

    if (_selectedCohortFilter == 'LP (Leader Panel)') {
      query = query.inFilter('role', ['CampusHead', 'CohortRep', 'OverallHead']);
    } else {
      query = query.eq('role', 'Volunteer');
    }

    if (_selectedCampusFilter != null) {
      query = query.eq('campusId', _selectedCampusFilter!);
    }

    if (_selectedCohortFilter != null &&
        _selectedCohortFilter != 'All' &&
        _selectedCohortFilter != 'LP (Leader Panel)') {
      query = query.contains('user_cohort_links', {'cohort_name': _selectedCohortFilter!});
    }

    final response = await query.order('name', ascending: true);
    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  void _fetchUsers() {
    setState(() {
      _userListFuture = _getUsersQuery();
    });
  }

  Widget _buildFilterBar() {
    if (widget.adminRole == 'OverallHead' || widget.adminRole == 'CampusHead') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Campus filter
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: _selectedCampusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Campus',
                    border: OutlineInputBorder(),
                  ),
                  items: _campusOptions.map((String campus) {
                    return DropdownMenuItem<String>(
                      value: (campus == 'All') ? null : campus,
                      child: Text(
                        campus,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCampusFilter = newValue;
                    });
                    _fetchUsers();
                  },
                ),
              ),
              const SizedBox(width: 16),

              // Cohort filter
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  value: _selectedCohortFilter,
                  decoration: const InputDecoration(
                    labelText: 'View',
                    border: OutlineInputBorder(),
                  ),
                  items: _allCohortOptions.map((String cohort) {
                    return DropdownMenuItem<String>(
                      value: (cohort == 'All') ? null : cohort,
                      child: Text(
                        cohort,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCohortFilter = newValue;
                    });
                    _fetchUsers();
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedCohortFilter == 'LP (Leader Panel)'
            ? 'Leader Panel'
            : 'Manage Volunteers'),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _userListFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint("Error fetching users: ${snapshot.error}");
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final users = snapshot.data;
                if (users == null || users.isEmpty) {
                  return const Center(
                      child: Text('No users found matching criteria.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8.0),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final name = user['name'] as String? ?? 'No Name';
                    final registerNumber =
                        user['registerNumber'] as String? ?? 'No Reg No';
                    final campus = user['campusId'] as String? ?? 'N/A';
                    final role = user['role'] as String? ?? 'N/A';

                    final List<dynamic>? links =
                        user['user_cohort_links'] as List<dynamic>?;
                    final cohortsList = links
                            ?.map((l) => l['cohort_name'] as String)
                            .toList() ??
                        [];
                    final cohortsDisplay = cohortsList.isNotEmpty
                        ? cohortsList.join(', ')
                        : 'N/A';

                    return ListTile(
                      leading: Icon(
                        role == 'Volunteer'
                            ? Icons.person_outline
                            : Icons.admin_panel_settings,
                      ),
                      isThreeLine: true,
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: role != 'Volunteer'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$role | Reg No: $registerNumber',
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                          Text(
                            'Campus: $campus | Cohorts: $cohortsDisplay',
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton:
          _selectedCohortFilter == 'LP (Leader Panel)'
              ? null
              : FloatingActionButton.extended(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AddVolunteerDialog(
                          adminRole: widget.adminRole,
                          adminCampusId: widget.adminCampusId,
                          adminCohortId: widget.adminCohortId,
                        );
                      },
                    ).then((_) => _fetchUsers());
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add User'),
                ),
    );
  }
}
