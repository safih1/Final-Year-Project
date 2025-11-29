// screens/profile_screen.dart
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> loggedInUser;
  final Function(Map<String, dynamic> updatedDetails) onUpdateProfile;

  const ProfileScreen({
    super.key,
    required this.loggedInUser,
    required this.onUpdateProfile,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false; // <--- ADDED: State for edit mode

  // Store initial values to reset if editing is cancelled
  String _initialFullName = '';
  String _initialEmail = ''; // Though email is read-only for editing by user

  @override
  void initState() {
    super.initState();
    _initialFullName = widget.loggedInUser['fullName'] ?? '';
    _initialEmail = widget.loggedInUser['email'] ?? '';

    _fullNameController = TextEditingController(text: _initialFullName);
    _emailController = TextEditingController(text: _initialEmail);
    // Password fields are initially empty
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      // If cancelling edit mode, reset fields to initial values
      if (!_isEditing) {
        _fullNameController.text = _initialFullName;
        // Password fields are usually cleared when cancelling, or not shown in read-only mode
        _passwordController.clear();
        _confirmPasswordController.clear();
        // Reset validation state if form was used
        _formKey.currentState?.reset();
      }
    });
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      Map<String, dynamic> updatedDetails = {
        'fullName': _fullNameController.text.trim(),
        // Email is not included here as it's read-only in this example
      };

      if (_passwordController.text.isNotEmpty) {
        updatedDetails['password'] = _passwordController.text;
      }

      widget.onUpdateProfile(updatedDetails);

      // After saving, exit edit mode and clear loading state
      setState(() {
        _isLoading = false;
        _isEditing = false; // Exit edit mode after saving
        // Update initial values to reflect the saved changes
        _initialFullName = _fullNameController.text.trim();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      // No need to pop here, user stays on profile screen in view mode
      // Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the text for the avatar based on the current controller value or initial
    String currentDisplayName = _isEditing ? _fullNameController.text : _initialFullName;
    String avatarLetter = (currentDisplayName.isNotEmpty)
        ? currentDisplayName[0].toUpperCase()
        : (widget.loggedInUser['fullName']?[0].toUpperCase() ?? "?");


    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Profile' : 'View Profile'),
        elevation: 1,
        actions: [
          // Edit/Cancel Button
          IconButton(
            icon: Icon(_isEditing ? Icons.cancel_outlined : Icons.edit_outlined),
            tooltip: _isEditing ? 'Cancel Editing' : 'Edit Profile',
            onPressed: _toggleEditMode,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).hintColor.withOpacity(0.2),
                    child: Text(
                      avatarLetter,
                      style: TextStyle(fontSize: 40, color: Theme.of(context).hintColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                TextFormField(
                  controller: _fullNameController,
                  readOnly: !_isEditing, // <--- MODIFIED
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: !_isEditing, // More visual cue for read-only
                    fillColor: !_isEditing ? Theme.of(context).disabledColor.withOpacity(0.05) : null,
                  ),
                  validator: (value) {
                    if (_isEditing && (value == null || value.isEmpty)) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _emailController,
                  readOnly: true, // Email is always read-only in this design
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true, // Always visually distinct as read-only
                    fillColor: Theme.of(context).disabledColor.withOpacity(0.05),
                  ),
                ),
                const SizedBox(height: 20),

                // Conditionally show password fields only when editing
                if (_isEditing) ...[
                  const Divider(height: 30),
                  Text(
                    "Change Password (optional)",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Leave blank to keep current password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value != null && value.isNotEmpty && value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (_passwordController.text.isNotEmpty && value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 40),
                ],

                // Conditionally show Save Changes button
                if (_isEditing)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('Save Changes'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}