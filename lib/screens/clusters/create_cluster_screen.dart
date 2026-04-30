import 'package:flutter/material.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';

class CreateClusterScreen extends StatefulWidget {
  const CreateClusterScreen({super.key});

  @override
  State<CreateClusterScreen> createState() => _CreateClusterScreenState();
}

class _CreateClusterScreenState extends State<CreateClusterScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  bool _isLoading = false;
  List<Map<String, dynamic>> _volunteers = [];
  final Set<String> _selectedUserIds = {};

  // To handle searching/filtering
  String _searchQuery = "";
  List<Map<String, dynamic>> _filteredVolunteers = [];

  @override
  void initState() {
    super.initState();
    _fetchVolunteers();
  }

  Future<void> _fetchVolunteers() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('users')
          .select('id, name, role, registerNumber')
          .order('name', ascending: true);

      _volunteers = List<Map<String, dynamic>>.from(response);
      _filterVolunteers();
    } catch (e) {
      debugPrint('Error fetching volunteers: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterVolunteers() {
    final query = _searchQuery.toLowerCase();
    setState(() {
      _filteredVolunteers = _volunteers.where((u) {
        final name = (u['name'] ?? '').toString().toLowerCase();
        final reg = (u['registerNumber'] ?? '').toString().toLowerCase();
        return name.contains(query) || reg.contains(query);
      }).toList();
    });
  }

  Future<void> _createCluster() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a cluster name')),
      );
      return;
    }

    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("Not logged in");

      // 1. Create Cluster
      final clusterRes = await supabase
          .from('clusters')
          .insert({
            'name': name,
            'description': _descController.text.trim(),
            'created_by': user.id,
          })
          .select()
          .single();

      final clusterId = clusterRes['id'];

      // 2. Add Members
      final membersData = _selectedUserIds
          .map((uid) => {
                'cluster_id': clusterId,
                'user_id': uid,
                'role': 'member' // default role
              })
          .toList();

      // Add creator as admin? Optional, but good practice
      // membersData.add({
      //   'cluster_id': clusterId,
      //   'user_id': user.id,
      //   'role': 'admin'
      // });

      await supabase.from('cluster_members').insert(membersData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cluster created successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error creating cluster: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Create Cluster'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createCluster,
            child: const Text("Create",
                style: TextStyle(
                    color: AppTheme.accentBlue, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Column(
        children: [
          // Build Form
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Cluster Name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AppTheme.primaryNavy,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AppTheme.primaryNavy,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24),

          // Member Selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) {
                _searchQuery = val;
                _filterVolunteers();
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search members...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: AppTheme.primaryNavy,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
              ),
            ),
          ),

          Expanded(
            child: _isLoading && _volunteers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredVolunteers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredVolunteers[index];
                      final isSelected = _selectedUserIds.contains(user['id']);

                      return CheckboxListTile(
                        value: isSelected,
                        activeColor: AppTheme.accentBlue,
                        checkColor: Colors.white,
                        title: Text(user['name'] ?? 'No Name',
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(user['role'] ?? 'Volunteer',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.6))),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedUserIds.add(user['id']);
                            } else {
                              _selectedUserIds.remove(user['id']);
                            }
                          });
                        },
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}
