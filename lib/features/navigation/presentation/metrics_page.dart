import 'package:flutter/material.dart';
import 'app_header.dart';

// Import the color constants
const Color caribbeanGreen = Color(0xFF00DF81);
const Color antiFlashWhite = Color(0xFFF1F7F6);
const Color bangladeshGreen = Color(0xFF03624C);
const Color darkGreen = Color(0xFF032221);
const Color richBlack = Color(0xFF021B1A);

class MetricsPage extends StatelessWidget {
  const MetricsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppHeader("Metrics"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricCard(
              title: "Total Trees Assessed",
              value: "124",
              icon: Icons.park,
              trend: "+12%",
              isPositive: true,
            ),
            const SizedBox(height: 16),
            _buildMetricCard(
              title: "Healthy Trees",
              value: "98",
              icon: Icons.check_circle,
              trend: "+8%",
              isPositive: true,
            ),
            const SizedBox(height: 16),
            _buildMetricCard(
              title: "Trees Needing Attention",
              value: "26",
              icon: Icons.warning,
              trend: "-4%",
              isPositive: false,
            ),
            const SizedBox(height: 16),
            _buildMetricCard(
              title: "Average Health Score",
              value: "82%",
              icon: Icons.analytics,
              trend: "+5%",
              isPositive: true,
            ),
            const SizedBox(height: 30),
            _buildSectionTitle("Conservation Impact"),
            const SizedBox(height: 16),
            _buildImpactMetrics(),
            const SizedBox(height: 30),
            _buildSectionTitle("Recent Activity"),
            const SizedBox(height: 16),
            _buildActivityList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required String trend,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bangladeshGreen),
        boxShadow: [
          BoxShadow(
            color: caribbeanGreen.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: caribbeanGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: caribbeanGreen, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: antiFlashWhite.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: antiFlashWhite,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isPositive 
                  ? caribbeanGreen.withOpacity(0.2) 
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  color: isPositive ? caribbeanGreen : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  trend,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? caribbeanGreen : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: caribbeanGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: antiFlashWhite,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildImpactMetrics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [darkGreen.withOpacity(0.8), bangladeshGreen.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: caribbeanGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _buildImpactRow(
            icon: Icons.eco,
            label: "Carbon Sequestered",
            value: "2.4 tons",
          ),
          const Divider(color: bangladeshGreen, height: 24),
          _buildImpactRow(
            icon: Icons.water_drop,
            label: "Water Quality Improved",
            value: "85%",
          ),
          const Divider(color: bangladeshGreen, height: 24),
          _buildImpactRow(
            icon: Icons.shield,
            label: "Shoreline Protected",
            value: "12 km",
          ),
          const Divider(color: bangladeshGreen, height: 24),
          _buildImpactRow(
            icon: Icons.bug_report,
            label: "Biodiversity Index",
            value: "High",
          ),
        ],
      ),
    );
  }

  Widget _buildImpactRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: caribbeanGreen, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: antiFlashWhite.withOpacity(0.8),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: caribbeanGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityList() {
    final activities = [
      {"time": "2 hours ago", "action": "Scanned 5 trees", "icon": Icons.center_focus_strong},
      {"time": "5 hours ago", "action": "Updated health status", "icon": Icons.edit},
      {"time": "1 day ago", "action": "Added new location", "icon": Icons.add_location},
      {"time": "2 days ago", "action": "Generated report", "icon": Icons.description},
    ];

    return Container(
      decoration: BoxDecoration(
        color: darkGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bangladeshGreen),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: activities.length,
        separatorBuilder: (context, index) => Divider(
          color: bangladeshGreen.withOpacity(0.5),
          height: 1,
        ),
        itemBuilder: (context, index) {
          final activity = activities[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: caribbeanGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                activity["icon"] as IconData,
                color: caribbeanGreen,
                size: 20,
              ),
            ),
            title: Text(
              activity["action"] as String,
              style: const TextStyle(
                color: antiFlashWhite,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              activity["time"] as String,
              style: TextStyle(
                fontSize: 12,
                color: antiFlashWhite.withOpacity(0.5),
              ),
            ),
          );
        },
      ),
    );
  }
}
