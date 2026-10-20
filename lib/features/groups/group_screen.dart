import 'package:flutter/material.dart';
import 'group_details_screen.dart';
import '../../core/theme/app_colors.dart';
import 'group_storage.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => GroupsScreenState();
}

class GroupsScreenState extends State<GroupsScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadGroups();
  }

  Future<void> loadGroups() async {
    try {
      final groups = await GroupStorage.getGroups();

      if (!mounted) return;

      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load saved groups.'),
        ),
      );
    }
  }

  Future<void> _showCreateGroupDialog() async {
    final nameController = TextEditingController();
    final memberController = TextEditingController();
    final members = <String>[];
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Group'),
              content: SizedBox(
                width: double.maxFinite,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Group name',
                            hintText: 'e.g. Weekend Trip',
                            prefixIcon: Icon(Icons.group_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter a group name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Members',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryFor(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: memberController,
                                textCapitalization:
                                    TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText: 'Member name',
                                  isDense: true,
                                ),
                                onSubmitted: (_) {
                                  addMember(
                                    memberController,
                                    members,
                                    setDialogState,
                                  );
                                },
                              ),
                            ),
                            IconButton(
                              tooltip: 'Add member',
                              onPressed: () {
                                addMember(
                                  memberController,
                                  members,
                                  setDialogState,
                                );
                              },
                              icon: Icon(
                                Icons.add_circle,
                                color: AppColors.primaryFor(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (members.isEmpty)
                          Text(
                            'Add at least one member to continue.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryFor(context),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: members.map((member) {
                              return Chip(
                                label: Text(member),
                                onDeleted: () {
                                  setDialogState(() {
                                    members.remove(member);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;

                    if (members.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please add at least one member.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true && mounted) {
      await GroupStorage.addGroup(
        name: nameController.text,
        members: members,
      );

      await loadGroups();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group created successfully.'),
          ),
        );
      }
    }

    nameController.dispose();
    memberController.dispose();
  }

  void addMember(
  TextEditingController controller,
  List<String> members,
  void Function(void Function()) setDialogState,
) {
  final name = controller.text.trim();

  if (name.isEmpty) return;

  final alreadyExists = members.any(
    (member) => member.toLowerCase() == name.toLowerCase(),
  );

  if (alreadyExists) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This member has already been added.'),
      ),
    );
    return;
  }

  setDialogState(() {
    members.add(name);
    controller.clear();
  });
}

  Future<void> _confirmDelete(
    Map<String, dynamic> group,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Group?'),
          content: Text(
            'Delete "${group['name']}"? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final id = group['id']?.toString();
    if (id == null) return;

    final deleted = await GroupStorage.deleteGroup(id);

    if (!mounted) return;

    await loadGroups();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted ? 'Group deleted.' : 'Group could not be found.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadGroups,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Groups',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryFor(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Share expenses with friends and family',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondaryFor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Create group',
                    onPressed: _showCreateGroupDialog,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryFor(context),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 55),
                  child: Column(
                    children: [
                      Icon(
                        Icons.groups_outlined,
                        size: 64,
                        color: AppColors.textSecondaryFor(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No groups yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryFor(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a group to start organizing shared expenses.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondaryFor(context),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _showCreateGroupDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Group'),
                      ),
                    ],
                  ),
                )
              else ...[
                Text(
                  '${_groups.length} ${_groups.length == 1 ? 'Group' : 'Groups'}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryFor(context),
                  ),
                ),
                const SizedBox(height: 12),
                ..._groups.map(_buildGroupCard),
              ],
            ],
          ),
        ),
      ),
    );
  }

 
Widget _buildGroupCard(Map<String, dynamic> group) {
  final name = group['name']?.toString() ?? 'Unnamed Group';

  final members = (group['members'] as List<dynamic>? ?? [])
      .map((member) => member.toString())
      .toList();

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: AppColors.surfaceFor(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.borderFor(context)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupDetailsScreen(
              group: group,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: AppColors.mint,
              child: Icon(
                Icons.groups_outlined,
                color: AppColors.primaryFor(context),
                size: 27,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryFor(context),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${members.length} '
                    '${members.length == 1 ? 'member' : 'members'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryFor(context),
                    ),
                  ),
                  if (members.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      members.join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryFor(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Tap to view shared expenses',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryFor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _confirmDelete(group);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                      SizedBox(width: 8),
                      Text('Delete group'),
                    ],
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

}