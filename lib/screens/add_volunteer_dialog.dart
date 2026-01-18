import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import '../main.dart'; // Import for the supabase client

class AddVolunteerDialog extends StatefulWidget {
  // Accept admin info passed from ManageVolunteersScreen
  final String adminRole;
  final String? adminCampusId;
  final String? adminCohortId;

  const AddVolunteerDialog({
    super.key,
    required this.adminRole,
    this.adminCampusId,
    this.adminCohortId,
  });

  @override
  State<AddVolunteerDialog> createState() => _AddVolunteerDialogState();
}

class _AddVolunteerDialogState extends State<AddVolunteerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _registerNumberController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedCampusId;
  String? _selectedRole; // Role for the NEW user
  List<String> _availableRoleOptions = [];
  bool _isLoading = false;

  // --- Cohort Data ---
  final List<String> _allCohortOptions = [
    'Social Entrepreneurship',
    'Education & Skill Development',
    'Health & Hygiene',
    'Environment & Sustainability',
    'Media & Advocacy',
    'Child Sponsorship Programme',
  ];
  // Map for multi-select (Volunteers)
  final Map<String, bool> _selectedCohortsMap = {};
  // String for single-select (Cohort Reps)
  String? _selectedSingleCohort; // <-- THIS WAS MISSING

  // Campus Data
  final List<String> _campusOptions = ['BKC', 'CampusB', 'CampusC', 'CampusD'];
  final Map<String, List<String>> _campusSpecificCohorts = {
    'BKC': ['Social Entrepreneurship', 'Education & Skill Development', 'Health & Hygiene', 'Environment & Sustainability', 'Media & Advocacy', 'Child Sponsorship Programme'],
    'CampusB': ['Social Entrepreneurship', 'Education & Skill Development', 'Health & Hygiene'],
    'CampusC': ['Environment & Sustainability', 'Media & Advocacy'],
    'CampusD': ['Child Sponsorship Programme'],
  };
  // List to show in dropdown/checkboxes
  List<String> _currentCohortOptionsList = []; // <-- THIS WAS MISSING

  @override
  void initState() {
    super.initState();

    // Initialize the selection map with all cohorts as false
    for (var cohortName in _allCohortOptions) {
      _selectedCohortsMap[cohortName] = false;
    }

    // --- Role Dropdown Logic ---
    if (widget.adminRole == 'OverallHead') {
      _availableRoleOptions = ['CampusHead', 'CohortRep', 'Volunteer'];
    } else if (widget.adminRole == 'CampusHead') {
      _availableRoleOptions = ['CohortRep', 'Volunteer'];
    } else if (widget.adminRole == 'CohortRep') {
      _availableRoleOptions = ['Volunteer'];
      _selectedRole = 'Volunteer'; // Auto-select
    }

    // --- Pre-fill/Disable Campus & Set Cohort Options ---
    bool canEditCampus = widget.adminRole == 'OverallHead';
    if (!canEditCampus && widget.adminCampusId != null && _campusOptions.contains(widget.adminCampusId)) {
      _selectedCampusId = widget.adminCampusId;
      _updateCohortOptionsList(_selectedCampusId); // Load cohorts for their campus
    } else {
      // Load all cohorts for OverallHead or if no campus is pre-filled
      _updateCohortOptionsList(null); 
    }

    // --- Pre-fill/Disable Cohort (for Cohort Rep creating a Volunteer) ---
    if (widget.adminRole == 'CohortRep' && widget.adminCohortId != null) {
      if (_selectedCohortsMap.containsKey(widget.adminCohortId!)) {
        _selectedCohortsMap[widget.adminCohortId!] = true; // Auto-check their own cohort
      }
    }
  }

  // --- THIS FUNCTION WAS MISSING ---
  // Update available cohort options based on selected campus
  void _updateCohortOptionsList(String? selectedCampus) {
    setState(() {
      if (widget.adminRole == 'OverallHead') {
        // Overall head always sees all cohorts
        _currentCohortOptionsList = _allCohortOptions;
      } else if (widget.adminRole == 'CampusHead' && widget.adminCampusId != null) {
        // Campus head sees only their campus's cohorts
        _currentCohortOptionsList = _campusSpecificCohorts[widget.adminCampusId] ?? [];
      } else if (widget.adminRole == 'CohortRep' && widget.adminCohortId != null) {
        // Cohort rep only sees their own cohort
         _currentCohortOptionsList = [widget.adminCohortId!];
      } else if (selectedCampus != null) {
        // Fallback for OverallHead when they select a campus (not strictly needed by logic but good)
         _currentCohortOptionsList = _campusSpecificCohorts[selectedCampus] ?? [];
      } else {
        _currentCohortOptionsList = _allCohortOptions;
      }
      _selectedSingleCohort = null; // Reset single cohort selection
    });
  }


  @override
  void dispose() {
    _registerNumberController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) { return; }
    
    setState(() { _isLoading = true; });

    final registerNumber = _registerNumberController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();
    final campusId = _selectedCampusId!;
    final roleToAssign = _selectedRole ?? 'Volunteer';

    // --- Build the cohorts list based on the selected role ---
    List<String> cohortsToSave = [];
    
    if (roleToAssign == 'Volunteer') {
      cohortsToSave = _selectedCohortsMap.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();
      if (cohortsToSave.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one cohort for the Volunteer')));
         setState(() { _isLoading = false; });
         return;
      }
    } else if (roleToAssign == 'CohortRep') {
      if (_selectedSingleCohort == null) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a cohort for the Cohort Rep')));
         setState(() { _isLoading = false; });
         return;
      }
      cohortsToSave = [_selectedSingleCohort!]; // Save as a list with one item
    }
    // If role is 'CampusHead', cohortsToSave remains an empty list []
    
    if (_selectedCampusId == null || (_availableRoleOptions.length > 1 && _selectedRole == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields (*)')));
      setState(() { _isLoading = false; });
      return;
    }

    debugPrint('--- Calling Supabase Function: createUser ---');
    debugPrint('Data: { registerNumber: $registerNumber, name: $name, roleToAssign: $roleToAssign, campusId: $campusId, cohorts: $cohortsToSave, password: (hidden) }');

    // --- Call the Supabase Edge Function ---
    try {
      final result = await supabase.functions.invoke('createUser',
        body: {
          'registerNumber': registerNumber,
          'name': name,
          'password': password,
          'roleToAssign': roleToAssign,
          'campusId': campusId,
          'cohorts': cohortsToSave, 
        },
      );

      final Map<String, dynamic> responseData = result.data as Map<String, dynamic>;

      if (mounted) {
        if (responseData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'] as String? ?? 'User created!')),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${responseData['error'] as String? ?? 'Unknown error from server.'}')),
          );
        }
      }
    } on FunctionException catch (e) {
      debugPrint('Supabase Function Error: ${e.toString()}');
      debugPrint('Details: ${e.details}');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Function Error: ${e.details?.toString() ?? e.toString()}')),
         );
      }
    } catch (e) {
      debugPrint('Generic Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }
  
  // --- This widget builds the cohort selection UI ---
  Widget _buildCohortSelector() {
    if (_selectedRole == null) {
      return const SizedBox.shrink(); // Empty space
    }

    if (_selectedRole == 'CampusHead') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: const Text(
          'Campus Heads are not assigned to specific cohorts.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    
    if (_selectedRole == 'CohortRep') {
      return DropdownButtonFormField<String>(
        value: _selectedSingleCohort,
        hint: const Text('Select Cohort*'),
        onChanged: (String? newValue) {
          setState(() {
            _selectedSingleCohort = newValue;
          });
        },
        items: _currentCohortOptionsList.map((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value, overflow: TextOverflow.ellipsis));
        }).toList(),
        validator: (value) => (value == null) ? 'Please select a cohort' : null,
        decoration: const InputDecoration(labelText: 'Assign to Cohort*'),
      );
    }

    if (_selectedRole == 'Volunteer') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Cohorts*', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(
            height: 200, // Fixed height for scrollable list
            width: double.maxFinite,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: ListView(
                shrinkWrap: true,
                children: _currentCohortOptionsList.map((cohortName) {
                  bool isEnabled = widget.adminRole != 'CohortRep';
                  
                  return CheckboxListTile(
                    title: Text(cohortName, style: const TextStyle(fontSize: 14)),
                    value: _selectedCohortsMap[cohortName],
                    onChanged: isEnabled ? (bool? newValue) {
                      setState(() {
                        _selectedCohortsMap[cohortName] = newValue ?? false;
                      });
                    } : null,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      );
    }
    
    return const SizedBox.shrink();
  }


  @override
  Widget build(BuildContext context) {
    bool canEditCampus = widget.adminRole == 'OverallHead';
    bool showRoleDropdown = _availableRoleOptions.length > 1;

    return AlertDialog(
      title: const Text('Add New User'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _registerNumberController,
                decoration: const InputDecoration(labelText: 'Register Number*'),
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name*'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              if (showRoleDropdown)
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  hint: const Text('Select Role*'),
                  onChanged: (String? newValue) { setState(() { _selectedRole = newValue; }); },
                  items: _availableRoleOptions.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value));
                  }).toList(),
                  validator: (value) => value == null ? 'Required' : null,
                  decoration: const InputDecoration(labelText: 'Assign Role*'),
                ),
              if (showRoleDropdown) const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCampusId,
                hint: const Text('Select Campus*'),
                onChanged: canEditCampus ? (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCampusId = newValue;
                      _updateCohortOptionsList(newValue); 
                    });
                  }
                } : null,
                items: _campusOptions.where((c) => c != 'All').map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                validator: (value) => value == null ? 'Required' : null,
                decoration: InputDecoration(
                  labelText: 'Campus ID*',
                  filled: !canEditCampus,
                  fillColor: !canEditCampus ? Theme.of(context).disabledColor.withOpacity(0.1) : null,
                ),
              ),
              const SizedBox(height: 16),
              
              _buildCohortSelector(), 
              
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Temporary Password*'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (value.length < 6) return 'Min 6 characters';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addUser,
          child: _isLoading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Add User'),
        ),
      ],
    );
  }
}