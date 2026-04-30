import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import 'create_cluster_screen.dart';
import 'cluster_detail_screen.dart';

class ClustersScreen extends StatefulWidget {
  final String role;

  const ClustersScreen({super.key, required this.role});

  @override
  State<ClustersScreen> createState() => _ClustersScreenState();
}

class _ClustersScreenState extends State<ClustersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _clusters = [];

  @override
  void initState() {
    super.initState();
    _fetchClusters();
  }

  Future<void> _fetchClusters() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch clusters where user is creator OR member
      // For simplicity, fetching all clusters for admins, or filtering
      // Using a stored procedure or complex query might be better, but let's try simple RLS

      final response = await supabase
          .from('clusters')
          .select('*')
          .order('created_at', ascending: false);

      setState(() {
        _clusters = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error fetching clusters: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading clusters: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('My Clusters'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accentBlue,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CreateClusterScreen()),
          );
          _fetchClusters();
        },
        label: const Text("Create Cluster",
            style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_rounded),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentBlue))
          : _clusters.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 60, color: AppTheme.white.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text("No clusters found",
                          style: TextStyle(
                              color: AppTheme.white.withOpacity(0.5))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _clusters.length,
                  itemBuilder: (context, index) {
                    final cluster = _clusters[index];
                    return _buildClusterCard(cluster, index);
                  },
                ),
    );
  }

  Widget _buildClusterCard(Map<String, dynamic> cluster, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryNavy,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ClusterDetailScreen(
                        clusterId: cluster['id'],
                        clusterName: cluster['name'],
                      )),
            );
            _fetchClusters();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.groups_rounded,
                      color: Colors.indigoAccent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cluster['name'] ?? 'Untitled',
                        style: const TextStyle(
                            color: AppTheme.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      if (cluster['description'] != null)
                        Text(
                          cluster['description'],
                          style: TextStyle(
                              color: AppTheme.white.withOpacity(0.6),
                              fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: AppTheme.white.withOpacity(0.3)),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX();
  }
}
