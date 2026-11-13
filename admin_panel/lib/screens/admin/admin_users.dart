part of 'admin_dashboard.dart';

extension _AdminUsers on _AdminDashboardState {
  // TAB 3: USERS & REGISTERED USER DATABASE
  Widget _buildCustomersTab(bool isDark) {
    if (_allUsers.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allUsers.isEmpty) {
      return FutureBuilder<List<UserModel>>(
        future: _apiService.getAdminUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 54,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No registered user accounts found.\nYou can create customer or driver accounts directly without waiting for sign-ups.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateUserDialog(isDark),
                    icon: const Icon(Icons.person_add_rounded, size: 16),
                    label: const Text('Create Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }
          return _buildUsersListPanel(isDark, users, users);
        },
      );
    }

    return _buildUsersListPanel(isDark, _filteredUsers, _allUsers);
  }

  Widget _buildUsersListPanel(
    bool isDark,
    List<UserModel> displayUsers,
    List<UserModel> allUsersSource,
  ) {
    final adminCount = allUsersSource
        .where((u) => u.role == UserRole.admin)
        .length;
    final driverCount = allUsersSource
        .where((u) => u.role == UserRole.driver)
        .length;
    final customerCount = allUsersSource
        .where((u) => u.role == UserRole.customer)
        .length;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Filter controls
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textAlignVertical: TextAlignVertical.center,
                  onChanged: (val) => _applyFilters(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search registered user database...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'Refresh user database',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loadAllDashboardData,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showCreateUserDialog(isDark),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text(
                  'Create Account',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Role Filter Quick Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRoleFilterChip(
                  label: 'All',
                  roleKey: 'All',
                  count: allUsersSource.length,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                _buildRoleFilterChip(
                  label: 'Admin',
                  roleKey: 'Admin',
                  count: adminCount,
                  color: const Color(0xFF7C3AED),
                ),
                const SizedBox(width: 8),
                _buildRoleFilterChip(
                  label: 'Driver',
                  roleKey: 'Driver',
                  count: driverCount,
                  color: const Color(0xFFEA580C),
                ),
                const SizedBox(width: 8),
                _buildRoleFilterChip(
                  label: 'Customers',
                  roleKey: 'Customers',
                  count: customerCount,
                  color: const Color(0xFF10B981),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // User list
          Expanded(
            child: displayUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No users found matching your filter.',
                          style: TextStyle(
                            color: const Color(0xFF475569),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _selectedRoleFilter = 'All';
                            });
                            _applyFilters();
                          },
                          child: const Text('Reset filters'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: displayUsers.length,
                    itemBuilder: (itemCtx, index) {
                      final cust = displayUsers[index];
                      final initial = cust.name.isNotEmpty
                          ? cust.name[0].toUpperCase()
                          : 'U';

                      // Explicit role label requested by the user: Admin , Driver , Customers
                      final String roleLabel;
                      final Color roleColor;
                      final Color roleBgColor;

                      switch (cust.role) {
                        case UserRole.admin:
                          roleLabel = 'Admin';
                          roleColor = const Color(0xFF7C3AED); // Purple
                          roleBgColor = const Color(
                            0xFF7C3AED,
                          ).withValues(alpha: 0.10);
                          break;
                        case UserRole.driver:
                          roleLabel = 'Driver';
                          roleColor = const Color(0xFFEA580C); // Orange
                          roleBgColor = const Color(
                            0xFFEA580C,
                          ).withValues(alpha: 0.10);
                          break;
                        case UserRole.customer:
                          roleLabel = 'Customers';
                          roleColor = const Color(0xFF10B981); // Emerald Green
                          roleBgColor = const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.10);
                          break;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: roleColor.withValues(alpha: 0.12),
                            child: Text(
                              initial,
                              style: TextStyle(
                                color: roleColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            cust.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${cust.email} • Role: $roleLabel'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'ID: ${cust.id}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: roleBgColor,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: roleColor.withValues(
                                          alpha: 0.35,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: roleColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          roleLabel,
                                          style: TextStyle(
                                            color: roleColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              if (cust.role == UserRole.admin)
                                const Tooltip(
                                  message: 'Admin account (Protected)',
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.lock_rounded,
                                      size: 16,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                )
                              else
                                PopupMenuButton<UserRole>(
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    size: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  onSelected: (newRole) =>
                                      _handleUpdateRole(cust, newRole),
                                  itemBuilder: (context) {
                                    final assignableRoles = [
                                      UserRole.customer,
                                      UserRole.driver,
                                    ];
                                    return assignableRoles.map((role) {
                                      final isCurrent = cust.role == role;
                                      return PopupMenuItem<UserRole>(
                                        value: role,
                                        enabled: !isCurrent,
                                        child: Row(
                                          children: [
                                            Icon(
                                              _getRoleIcon(role),
                                              size: 16,
                                              color: _getRoleColor(role),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Set to ${Helpers.capitalize(role.name)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isCurrent
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color: isCurrent
                                                    ? Colors.grey
                                                    : null,
                                              ),
                                            ),
                                            if (isCurrent) ...[
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.check_rounded,
                                                size: 14,
                                                color: Colors.green,
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterChip({
    required String label,
    required String roleKey,
    required int count,
    required Color color,
  }) {
    final isSelected =
        _selectedRoleFilter.toLowerCase() == roleKey.toLowerCase() ||
        (_selectedRoleFilter == 'All' && roleKey == 'All') ||
        (_selectedRoleFilter.toLowerCase() == 'customer' &&
            roleKey.toLowerCase() == 'customers');

    return InkWell(
      onTap: () {
        setState(() {
          _selectedRoleFilter = roleKey;
        });
        _applyFilters();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.35),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 3: USER / ROLES & PERMISSIONS TAB
  Widget _buildUsersTab(bool isDark) {
    final currentAdmin = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => _applyFilters(),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkSurface : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRoleFilter,
                    onChanged: (String? val) {
                      if (val != null) {
                        setState(() {
                          _selectedRoleFilter = val;
                        });
                        _applyFilters();
                      }
                    },
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.grey.shade800,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Roles')),
                      DropdownMenuItem(
                        value: 'Admin',
                        child: Text('Administrators'),
                      ),
                      DropdownMenuItem(value: 'Driver', child: Text('Drivers')),
                      DropdownMenuItem(
                        value: 'Customer',
                        child: Text('Customers'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showCreateUserDialog(isDark),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text(
                  'Create Account',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: const Color(0xFF475569),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No accounts match your criteria',
                          style: TextStyle(color: const Color(0xFF475569)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final bool isSelfAdmin =
                          user.role == UserRole.admin &&
                          (currentAdmin != null &&
                              (currentAdmin.id == user.id ||
                                  (currentAdmin.email.isNotEmpty &&
                                      currentAdmin.email.trim().toLowerCase() ==
                                          user.email.trim().toLowerCase())));
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: _getRoleColor(
                              user.role,
                            ).withValues(alpha: 0.12),
                            child: Icon(
                              _getRoleIcon(user.role),
                              color: _getRoleColor(user.role),
                              size: 16,
                            ),
                          ),
                          title: Text(
                            user.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            user.email,
                            style: TextStyle(
                              color: const Color(0xFF475569),
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getRoleColor(
                                    user.role,
                                  ).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _getRoleColor(
                                      user.role,
                                    ).withValues(alpha: 0.2),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  user.roleDisplayName,
                                  style: TextStyle(
                                    color: _getRoleColor(user.role),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isSelfAdmin)
                                Tooltip(
                                  message:
                                      'Active Admin Account (Protected - Cannot be deleted)',
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.lock_rounded,

                                      size: 16,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                )
                              else if (_isActionLoading)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    size: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  onSelected: (val) {
                                    if (val == 'delete') {
                                      _confirmDeleteUser(user, isDark);
                                    } else if (val == 'set_driver') {
                                      _handleUpdateRole(user, UserRole.driver);
                                    }
                                  },
                                  itemBuilder: (context) {
                                    final List<PopupMenuEntry<String>> items =
                                        [];

                                    if (user.role == UserRole.customer) {
                                      // Customer: role cannot be changed at all
                                      items.add(
                                        const PopupMenuItem<String>(
                                          enabled: false,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.lock_outline_rounded,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Customer Role (Fixed)',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                      items.add(
                                        const PopupMenuDivider(height: 1),
                                      );
                                      items.add(
                                        const PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline_rounded,
                                                size: 16,
                                                color: Colors.redAccent,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Delete Customer Account',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.redAccent,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    } else if (user.role == UserRole.driver) {
                                      items.add(
                                        const PopupMenuItem<String>(
                                          enabled: false,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.local_shipping_rounded,
                                                size: 16,
                                                color: AppTheme.secondaryColor,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Driver Role (Active)',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppTheme.secondaryColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                      items.add(
                                        const PopupMenuDivider(height: 1),
                                      );
                                      items.add(
                                        const PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline_rounded,
                                                size: 16,
                                                color: Colors.redAccent,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Delete Driver Account',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.redAccent,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    } else if (user.role == UserRole.admin) {
                                      // Another admin (not self)
                                      items.add(
                                        const PopupMenuItem<String>(
                                          enabled: false,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons
                                                    .admin_panel_settings_rounded,
                                                size: 16,
                                                color: Color(0xFF6366F1),
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Admin Role (Fixed)',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF6366F1),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                      items.add(
                                        const PopupMenuDivider(height: 1),
                                      );
                                      items.add(
                                        const PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline_rounded,
                                                size: 16,
                                                color: Colors.redAccent,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Delete Admin Account',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.redAccent,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    return items;
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AppTheme.primaryColor;
      case UserRole.driver:
        return AppTheme.secondaryColor;
      case UserRole.customer:
        return const Color(0xFF10B981);
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.driver:
        return Icons.local_shipping_rounded;
      case UserRole.customer:
        return Icons.person_rounded;
    }
  }
}
