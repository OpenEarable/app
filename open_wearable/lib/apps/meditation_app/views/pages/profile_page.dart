import 'package:flutter/material.dart';
import 'drawer_page.dart';
import '../../model/user_account.dart';
import '../../widgets/gender_selector.dart';

class ProfilePage extends StatefulWidget implements DrawerPage {
  final UserAccount userAccount;
  final Future<void> Function()? onSaved;

  const ProfilePage({
    super.key,
    required this.userAccount,
    this.onSaved,
  });

  @override
  String get label => "Profile";

  @override
  IconData get icon => Icons.person_outline;

  @override
  IconData get selectedIcon => Icons.person;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late Gender _selectedGender;
  late FitnessLevel _fitnessLevel;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.userAccount.firstName ?? '');
    _ageController =
        TextEditingController(text: widget.userAccount.age?.toString() ?? '');
    _selectedGender = widget.userAccount.gender ?? Gender.unspecified;
    _fitnessLevel = widget.userAccount.fitnessLevel ?? FitnessLevel.sedentary;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        widget.userAccount.firstName = _nameController.text.trim();
        widget.userAccount.age = int.tryParse(_ageController.text.trim());
        widget.userAccount.gender = _selectedGender;
        widget.userAccount.fitnessLevel = _fitnessLevel;
      });

      try {
        await widget.onSaved?.call();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save the profile: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors in the form before saving.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Card(
          margin: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tell EarStreAM about you',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'These values personalize meditation guidance and provide sensible defaults when no measured baseline is available.',
                    style: TextStyle(color: Colors.grey[700], height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'Enter the participant name',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name before starting a meditation.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Age',
                      hintText: 'Enter the age in years',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      final age = int.tryParse(value?.trim() ?? '');
                      if (age == null || age < 13 || age > 120) {
                        return 'Please enter a valid age between 13 and 120.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Gender',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  GenderSelector(
                    currentSelection: _selectedGender,
                    onChanged: (Gender newGender) {
                      setState(() {
                        _selectedGender = newGender;
                      });
                    },
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Fitness level',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _buildFitnessOption(
                    title: 'Sedentary',
                    subtitle: 'Little to no exercise',
                    value: FitnessLevel.sedentary,
                    icon: Icons.weekend,
                  ),
                  _buildFitnessOption(
                    title: 'Moderate',
                    subtitle: 'Exercise 1-3 times per week',
                    value: FitnessLevel.moderate,
                    icon: Icons.directions_walk,
                  ),
                  _buildFitnessOption(
                    title: 'Active',
                    subtitle: 'Exercise 4-5 times per week',
                    value: FitnessLevel.active,
                    icon: Icons.directions_run,
                  ),
                  _buildFitnessOption(
                    title: 'Athlete',
                    subtitle: 'Daily intense training',
                    value: FitnessLevel.athlete,
                    icon: Icons.fitness_center,
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    onPressed: _saveProfile,
                    child: const Text(
                      'Save Profile',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFitnessOption({
    required String title,
    required String subtitle,
    required FitnessLevel value,
    required IconData icon,
  }) {
    final selected = _fitnessLevel == value;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => setState(() => _fitnessLevel = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.45)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
