import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EmergencyPopup extends StatelessWidget {
  final Map<String, dynamic> emergency;
  final VoidCallback onClose;

  const EmergencyPopup({
    super.key,
    required this.emergency,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFF1e293b),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Header
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 500),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFef4444),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFef4444).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.emergency,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '🚨 EMERGENCY ASSIGNMENT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        emergency['emergency_id'] ?? 'N/A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Emergency Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0f172a),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF334155),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      Icons.warning_amber_rounded,
                      'Type',
                      _formatType(emergency['emergency_type']),
                      const Color(0xFFf59e0b),
                    ),
                    const Divider(color: Color(0xFF334155), height: 24),
                    _buildDetailRow(
                      Icons.priority_high,
                      'Priority',
                      (emergency['priority'] ?? 'medium').toUpperCase(),
                      _getPriorityColor(emergency['priority']),
                    ),
                    const Divider(color: Color(0xFF334155), height: 24),
                    _buildDetailRow(
                      Icons.location_on,
                      'Location',
                      emergency['address'] ?? 'No address provided',
                      const Color(0xFF3b82f6),
                    ),
                    const Divider(color: Color(0xFF334155), height: 24),
                    _buildDetailRow(
                      Icons.description,
                      'Description',
                      emergency['description'] ?? 'No description available',
                      const Color(0xFF94a3b8),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _declineEmergency(context),
                      icon: const Icon(Icons.close),
                      label: const Text(
                        'Decline',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF475569),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _acceptEmergency(context),
                      icon: const Icon(Icons.check_circle),
                      label: const Text(
                        'Accept',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10b981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF94a3b8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatType(String? type) {
    if (type == null) return 'Unknown';
    return type.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'critical':
        return const Color(0xFFef4444);
      case 'high':
        return const Color(0xFFf59e0b);
      case 'medium':
        return const Color(0xFF3b82f6);
      default:
        return const Color(0xFF10b981);
    }
  }

  void _acceptEmergency(BuildContext context) async {
    try {
      final apiService = ApiService();
      await apiService.acceptEmergency(emergency['id']);
      
      if (context.mounted) {
        Navigator.of(context).pop();
        onClose();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Emergency accepted! Navigating to location...'),
                ),
              ],
            ),
            backgroundColor: Color(0xFF10b981),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: \${e.toString()}'),
            backgroundColor: const Color(0xFFef4444),
          ),
        );
      }
    }
  }

  void _declineEmergency(BuildContext context) async {
    String? reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1e293b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Decline Reason',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide a reason for declining this emergency:',
              style: TextStyle(color: Color(0xFF94a3b8)),
            ),
            const SizedBox(height: 16),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter reason...',
                hintStyle: const TextStyle(color: Color(0xFF64748b)),
                filled: true,
                fillColor: const Color(0xFF0f172a),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
              ),
              maxLines: 3,
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94a3b8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('Not available at the moment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFef4444),
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    
    if (reason != null && reason.isNotEmpty) {
      try {
        final apiService = ApiService();
        await apiService.declineEmergency(emergency['id'], reason);
        
        if (context.mounted) {
          Navigator.of(context).pop();
          onClose();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency declined'),
              backgroundColor: Color(0xFF475569),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: \${e.toString()}'),
              backgroundColor: const Color(0xFFef4444),
            ),
          );
        }
      }
    }
  }
}