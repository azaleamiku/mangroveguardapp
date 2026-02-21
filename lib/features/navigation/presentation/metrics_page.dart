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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricCard(
              title: "Root-First Scans Completed",
              value: "124 trees",
              icon: Icons.hub,
              trend: "This cycle",
              isPositive: true,
            ),
            const SizedBox(height: 12),
            _buildMetricCard(
              title: "Average Structural Score (S)",
              value: "79.0%",
              icon: Icons.account_tree,
              trend: "Tidal corrected",
              isPositive: true,
            ),
            const SizedBox(height: 12),
            _buildMetricCard(
              title: "Average Health Score (H)",
              value: "84.0%",
              icon: Icons.eco,
              trend: "Optional canopy scan",
              isPositive: true,
            ),
            const SizedBox(height: 12),
            _buildMetricCard(
              title: "Average Necrosis",
              value: "8.0%",
              icon: Icons.warning_amber_rounded,
              trend: "Leaf/canopy subset",
              isPositive: false,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle("Assessment Context"),
            const SizedBox(height: 12),
            _buildImpactMetrics(),
            const SizedBox(height: 24),
            _buildSectionTitle("Recent Scan Activity"),
            const SizedBox(height: 12),
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
      padding: const EdgeInsets.all(16),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: antiFlashWhite.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: antiFlashWhite,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 118),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isPositive ? caribbeanGreen.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isPositive ? Icons.trending_up : Icons.trending_down, size: 14, color: isPositive ? caribbeanGreen : Colors.red),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    trend,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isPositive ? caribbeanGreen : Colors.red),
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
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: caribbeanGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: antiFlashWhite,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _buildImpactMetrics() {
    return Container(
      padding: const EdgeInsets.all(16),
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
            icon: Icons.waves,
            label: "High Tide Scans",
            value: "31%",
          ),
          const Divider(color: bangladeshGreen, height: 20),
          _buildImpactRow(
            icon: Icons.water_drop,
            label: "Low Tide Scans",
            value: "69%",
          ),
          const Divider(color: bangladeshGreen, height: 20),
          _buildImpactRow(
            icon: Icons.tune,
            label: "Tidal Correction Factor",
            value: "x0.92 (high tide)",
          ),
          const Divider(color: bangladeshGreen, height: 20),
          _buildImpactRow(
            icon: Icons.route,
            label: "Primary Workflow",
            value: "Root-first",
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
        Icon(icon, color: caribbeanGreen, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: antiFlashWhite.withOpacity(0.8),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: caribbeanGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityList() {
    final activities = [
      {"time": "45 min ago", "action": "Root scan recorded • Tree #07", "icon": Icons.hub},
      {"time": "1 hr ago", "action": "Tidal context set to High Tide", "icon": Icons.waves},
      {"time": "2 hrs ago", "action": "Optional necrosis analysis completed", "icon": Icons.eco},
      {"time": "Today", "action": "Recent scan saved to local study record", "icon": Icons.save_alt},
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
            minVerticalPadding: 8,
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
                fontWeight: FontWeight.w600,
                fontSize: 13,
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
