import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart'; // supabase client
import 'add_volunteer_dialog.dart';
import '../theme/app_theme.dart';

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
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;

  String? _selectedCampusFilter;
  String _selectedCohortFilter = 'All';
  String _currentSort = 'Role Priority'; // Default sort

  final List<String> _campusOptions = ['All', 'BKC', 'CampusB', 'CampusC', 'CampusD'];
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
  
  // Custom Role Hierarchy
  final Map<String, int> _rolePriority = {
    'Faculty': 0,
    'OverallHead': 1,
    'CampusHead': 2, // Campus Ambassador
    'CohortRep': 3,
    'Volunteer': 4,
  };

  @override
  void initState() {
    super.initState();
    // Initialize filters based on admin role
    if (widget.adminRole == 'CampusHead') {
      _selectedCampusFilter = widget.adminCampusId;
    } else if (widget.adminRole == 'OverallHead') {
      _selectedCampusFilter = 'All';
    }
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    
    try {
      var query = supabase.from('users').select('*, user_cohort_links(cohort_name)');
      
      // We fetch broadly and filter locally for maximum sorting flexibility
      // But we still apply basic security filters at DB level if possible
      if (widget.adminRole == 'CampusHead') {
        query = query.eq('campusId', widget.adminCampusId!);
      }

      final response = await query;
      final data = (response as List<dynamic>).cast<Map<String, dynamic>>();
      
      if (data.isNotEmpty) {
        debugPrint("First user loaded: ${data.first['name']}");
        debugPrint("Cohort Links sample: ${data.first['user_cohort_links']}");
      }
      
      setState(() {
        _allUsers = data;
        _applyFiltersAndSort();
        _isLoading = false;
      });
      
    } catch (e) {
      debugPrint("Error fetching users: $e");
      setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndSort() {
    List<Map<String, dynamic>> temp = List.from(_allUsers);

    // 1. Filter by Campus
    if (_selectedCampusFilter != null && _selectedCampusFilter != 'All') {
      temp = temp.where((u) => u['campusId'] == _selectedCampusFilter).toList();
    }

    // 2. Filter by Cohort / View
    if (_selectedCohortFilter == 'LP (Leader Panel)') {
      // Show only leaders
      temp = temp.where((u) => ['CampusHead', 'CohortRep', 'OverallHead', 'Faculty'].contains(u['role'])).toList();
    } else if (_selectedCohortFilter != 'All') {
      // Logic for filtering by specific cohort name using the joined list
      temp = temp.where((u) {
         final links = u['user_cohort_links'] as List<dynamic>?;
         if (links == null) return false;
         return links.any((l) => l['cohort_name'] == _selectedCohortFilter);
      }).toList();
    } else {
      // 'All' view: generally we exclude Faculty/Heads if they are separate? 
      // User requirement implies mixing things. Let's keep everyone but allow sorting.
      // Or maybe filter out 'Volunteer' if user wants?
      // For now, 'All' shows everyone fetched.
    }

    // 3. APPLY SCALAR SORTING
    temp.sort((a, b) {
      if (_currentSort == 'Role Priority') {
        int pA = _rolePriority[a['role']] ?? 99;
        int pB = _rolePriority[b['role']] ?? 99;
        return pA.compareTo(pB); // Ascending (0 first)
      } else if (_currentSort == 'Name (A-Z)') {
        return (a['name'] ?? '').compareTo(b['name'] ?? '');
      } else if (_currentSort == 'Campus') {
        return (a['campusId'] ?? '').compareTo(b['campusId'] ?? '');
      } else if (_currentSort == 'Cohort') {
         // Sort by first cohort name found
         final String cA = _getFirstCohort(a).toLowerCase();
         final String cB = _getFirstCohort(b).toLowerCase();
         int compare = cA.compareTo(cB);
         if (compare == 0) {
           return (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase());
         }
         return compare;
      }
      return 0;
    });

    setState(() {
      _filteredUsers = temp;
    });
  }
  
  String _getFirstCohort(Map<String, dynamic> user) {
     final links = user['user_cohort_links'] as List<dynamic>?;
     if (links != null && links.isNotEmpty) {
       final name = links.first['cohort_name']?.toString();
       if (name != null && name.isNotEmpty) return name;
     }
     return "zzzz"; // Ensure strict bottom sorting
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Faculty': return Colors.amber;
      case 'OverallHead': return Colors.purpleAccent;
      case 'CampusHead': return Colors.cyanAccent;
      case 'CohortRep': return AppTheme.accentBlue;
      default: return AppTheme.white.withOpacity(0.7);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Manage Team", style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded, color: AppTheme.lightBlue),
            onPressed: _showSortSheet,
          )
        ],
      ),
      body: Column(
        children: [
          _buildFilterHeader(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue))
              : _filteredUsers.isEmpty 
                  ? Center(child: Text("No members found", style: TextStyle(color: AppTheme.white.withOpacity(0.5))))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        return _buildTeamCard(_filteredUsers[index], index);
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentBlue,
        child: const Icon(Icons.add, color: AppTheme.white),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AddVolunteerDialog(
              adminRole: widget.adminRole,
              adminCampusId: widget.adminCampusId,
              adminCohortId: widget.adminCohortId,
            ),
          ).then((_) => _fetchUsers());
        },
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryNavy.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: AppTheme.white.withOpacity(0.05))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.adminRole == 'OverallHead')
                Expanded(
                  child: _buildDropdown(
                    value: _selectedCampusFilter ?? 'All',
                    items: _campusOptions,
                    label: "Campus",
                    onChanged: (val) {
                      setState(() => _selectedCampusFilter = val);
                      _applyFiltersAndSort();
                    },
                  ),
                ),
              if (widget.adminRole == 'OverallHead') const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildDropdown(
                  value: _selectedCohortFilter,
                  items: _allCohortOptions,
                  label: "View",
                  onChanged: (val) {
                    setState(() => _selectedCohortFilter = val ?? 'All');
                    _applyFiltersAndSort();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildDropdown({required String value, required List<String> items, required String label, required Function(String?) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.lightBlue.withOpacity(0.7), fontSize: 10)),
        const SizedBox(height: 4),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: AppTheme.primaryNavy,
              style: const TextStyle(color: AppTheme.white, fontSize: 13),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.accentBlue),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> user, int index) {
    final name = user['name'] ?? 'Unknown';
    final role = user['role'] ?? 'Unknown';
    final regNo = user['registerNumber'] ?? '';
    final campus = user['campusId'] ?? '';
    final links = user['user_cohort_links'] as List<dynamic>?;
    String cohorts = (links != null && links.isNotEmpty) 
        ? links.map((l) => l['cohort_name']).join(", ") 
        : "No Cohort";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryNavy,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(role).withOpacity(0.2),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(color: _getRoleColor(role), fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(name, style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
             Row(
               children: [
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                   decoration: BoxDecoration(
                     color: _getRoleColor(role).withOpacity(0.1),
                     borderRadius: BorderRadius.circular(8),
                     border: Border.all(color: _getRoleColor(role).withOpacity(0.3), width: 0.5)
                   ),
                   child: Text(
                     role == 'CampusHead' ? 'Campus Amb' : role, // Display Alias
                     style: TextStyle(color: _getRoleColor(role), fontSize: 10, fontWeight: FontWeight.w500),
                   ),
                 ),
                 const SizedBox(width: 8),
                 Text("| $campus", style: TextStyle(color: AppTheme.white.withOpacity(0.5), fontSize: 12)),
               ],
             ),
             if (role == 'Volunteer' || role == 'CohortRep') 
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(cohorts, style: TextStyle(color: AppTheme.white.withOpacity(0.4), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                )
          ],
        ),
        trailing: Icon(Icons.more_vert_rounded, color: AppTheme.white.withOpacity(0.3)),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX();
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Sort By", style: TextStyle(color: AppTheme.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildSortOption('Role Priority'),
              _buildSortOption('Name (A-Z)'),
              _buildSortOption('Campus'),
              _buildSortOption('Cohort'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String label) {
    final isSelected = _currentSort == label;
    return InkWell(
      onTap: () {
        setState(() => _currentSort = label);
        _applyFiltersAndSort();
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.white.withOpacity(0.05))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: isSelected ? AppTheme.accentBlue : AppTheme.white.withOpacity(0.8), fontSize: 16)),
            if (isSelected) const Icon(Icons.check, color: AppTheme.accentBlue, size: 20),
          ],
        ),
      ),
    );
  }
}
