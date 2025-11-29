// lib/screens/emergency_contacts_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/add_contact_dialog.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _debugToken(); // Add debug for token
    _loadContacts();
  }

  // Add debug method for token
  Future<void> _debugToken() async {
    await _apiService.debugToken();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final contacts = await _apiService.getEmergencyContacts();
      setState(() {
        _contacts = contacts.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading contacts: $e')),
      );
    }
  }

  // In lib/screens/emergency_contacts_screen.dart

  Future<void> _addContact() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const AddContactDialog(),
    );

    if (result != null) {
      // Show loading state
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await _apiService.addEmergencyContact(result);

        if (response['id'] != null) {
          // Success - reload all contacts
          await _loadContacts();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact added successfully!')),
          );
        } else {
          // Handle API error
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response['error'] ?? 'Failed to add contact'}')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    }
  }

  Future<void> _editContact(Map<String, dynamic> contact) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AddContactDialog(
        initialName: contact['name'],
        initialPhone: contact['phone_number'],
        initialRelationship: contact['relationship'],
        isEdit: true,
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await _apiService.updateEmergencyContact(contact['id'], result);

        if (response['id'] != null || response['error'] == null) {
          // Success - reload all contacts
          await _loadContacts();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact updated successfully!')),
          );
        } else {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response['error'] ?? 'Failed to update contact'}')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    }
  }

  Future<void> _deleteContact(Map<String, dynamic> contact) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Delete Contact', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 20)),
        content: Text(
          'Are you sure you want to delete ${contact['name']}?',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).hintColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await _apiService.deleteEmergencyContact(contact['id']);

        if (response['success'] == true || response['message'] != null) {
          // Success - reload all contacts
          await _loadContacts();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact deleted successfully!')),
          );
        } else {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response['error'] ?? 'Failed to delete contact'}')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addContact,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contact_emergency_outlined,
              size: 80,
              color: Theme.of(context).hintColor.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            Text(
              'No Emergency Contacts',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Add contacts who will be notified\nin case of an emergency.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _addContact,
              icon: const Icon(Icons.person_add),
              label: const Text('Add First Contact'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadContacts,
        child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: _contacts.length,
          itemBuilder: (context, index) {
            final contact = _contacts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).hintColor,
                  child: Text(
                    contact['name'][0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  contact['name'],
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact['phone_number'],
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (contact['relationship']?.isNotEmpty == true)
                      Text(
                        contact['relationship'],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editContact(contact);
                    } else if (value == 'delete') {
                      _deleteContact(contact);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 10),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: _contacts.isNotEmpty
          ? FloatingActionButton(
        onPressed: _addContact,
        backgroundColor: Theme.of(context).hintColor,
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}