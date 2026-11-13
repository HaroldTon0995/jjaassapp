part of 'admin_dashboard.dart';

extension _AdminInventory on _AdminDashboardState {
  // Helper Dialog for Adding or Editing Inventory Items
  void _showAddEditInventoryItemDialog(
    bool isDark, [
    Map<String, dynamic>? itemToEdit,
  ]) {
    final isEditing = itemToEdit != null;
    final nameController = TextEditingController(
      text: isEditing ? (itemToEdit['name'] as String) : '',
    );
    final priceController = TextEditingController(
      text: isEditing ? (itemToEdit['price'] as num).toString() : '',
    );
    final stockController = TextEditingController(
      text: isEditing ? (itemToEdit['stock'] as num).toString() : '',
    );
    final capacityController = TextEditingController(
      text: isEditing ? (itemToEdit['capacity'] as num).toString() : '100',
    );
    final descController = TextEditingController(
      text: isEditing ? (itemToEdit['description'] as String? ?? '') : '',
    );

    String selectedCategory = isEditing
        ? (itemToEdit['category'] as String? ?? 'water')
        : 'water';
    String selectedUnit = isEditing
        ? (itemToEdit['unit'] as String? ?? 'Gallons')
        : 'Gallons';
    Color selectedColor = isEditing
        ? (itemToEdit['color'] as Color? ?? Colors.blue)
        : Colors.blue;
    IconData selectedIcon = isEditing
        ? (itemToEdit['icon'] as IconData? ?? Icons.water_drop_rounded)
        : Icons.water_drop_rounded;
    bool isRefill = isEditing
        ? ((itemToEdit['is_refill'] ??
                  (itemToEdit['category'] == 'water' &&
                      (itemToEdit['unit']?.toString().toLowerCase() ==
                              'gallons' ||
                          (itemToEdit['name']
                                  ?.toString()
                                  .toLowerCase()
                                  .contains('refill') ??
                              false) ||
                          (itemToEdit['name']
                                  ?.toString()
                                  .toLowerCase()
                                  .contains('19l') ??
                              false))))
              as bool)
        : (selectedCategory == 'water' && selectedUnit == 'Gallons');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              title: Row(
                children: [
                  Icon(
                    isEditing
                        ? Icons.edit_note_rounded
                        : Icons.add_business_rounded,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEditing
                        ? 'Edit Inventory Item'
                        : 'Add New Inventory Item',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Selector
                      Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'water',
                            child: Text(
                              '💧 Water Product / Refill (Customer App)',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'container',
                            child: Text('🪣 Container & Jug Reserve'),
                          ),
                          DropdownMenuItem(
                            value: 'accessory',
                            child: Text('📦 Accessory & Parts'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedCategory = val;
                              if (val == 'water') {
                                selectedUnit = 'Gallons';
                                selectedColor = Colors.blue;
                                selectedIcon = Icons.water_drop_rounded;
                                isRefill = true;
                              } else if (val == 'accessory') {
                                selectedUnit = 'Pieces';
                                selectedColor = Colors.amber;
                                selectedIcon = Icons.inventory_2_rounded;
                                isRefill = false;
                              } else {
                                selectedUnit = 'Units';
                                selectedColor = Colors.indigo;
                                selectedIcon = Icons.local_drink_rounded;
                                isRefill = false;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Customer App Ordering Mode Toggle
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isRefill
                              ? const Color(0xFF0284C7).withValues(alpha: 0.08)
                              : const Color(0xFF10B981).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isRefill
                                ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                                : const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Customer App Order Placement',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        isRefill = true;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isRefill
                                            ? const Color(0xFF0284C7)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.water_drop_rounded,
                                            size: 16,
                                            color: isRefill
                                                ? Colors.white
                                                : Colors.blueGrey,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              '5-Gallon Refill',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: isRefill
                                                    ? Colors.white
                                                    : Colors.blueGrey,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        isRefill = false;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: !isRefill
                                            ? const Color(0xFF10B981)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.storefront_rounded,
                                            size: 16,
                                            color: !isRefill
                                                ? Colors.white
                                                : Colors.blueGrey,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              'Standalone Product',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: !isRefill
                                                    ? Colors.white
                                                    : Colors.blueGrey,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isRefill
                                  ? '💧 Shows in Top Refills section (Customer selects 5-Gallon Slim / Round jug types).'
                                  : '📦 Shows in Station Products & Items (Direct [ - ] [ + ] quantity purchase, e.g. 500ml Bottled Water, Jugs, Accessories).',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Item Name
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Product / Item Name',
                          hintText:
                              'e.g. 19L Distilled Water or USB Dispenser Pump',
                          prefixIcon: Icon(Icons.label_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Price & Unit Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Price per Unit (₱)',
                                prefixIcon: Icon(Icons.payments_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedUnit,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Measurement Unit',
                                prefixIcon: Icon(Icons.straighten_rounded),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Gallons',
                                  child: Text('Gallons'),
                                ),
                                DropdownMenuItem(
                                  value: 'Jugs',
                                  child: Text('Jugs'),
                                ),
                                DropdownMenuItem(
                                  value: 'Units',
                                  child: Text('Units'),
                                ),
                                DropdownMenuItem(
                                  value: 'Pieces',
                                  child: Text('Pieces'),
                                ),
                                DropdownMenuItem(
                                  value: 'Packs',
                                  child: Text('Packs'),
                                ),
                                DropdownMenuItem(
                                  value: 'Sets',
                                  child: Text('Sets'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedUnit = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Stock & Capacity Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: stockController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: isEditing
                                    ? 'Current Stock ($selectedUnit)'
                                    : 'Initial Stock ($selectedUnit)',
                                prefixIcon: const Icon(
                                  Icons.inventory_2_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: capacityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Max Capacity ($selectedUnit)',
                                prefixIcon: const Icon(Icons.warehouse_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Description
                      TextField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description / Specifications (Optional)',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Theme Color
                      Text(
                        'Theme Color & Accent',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children:
                            [
                              Colors.blue,
                              Colors.cyan,
                              Colors.teal,
                              Colors.indigo,
                              Colors.deepPurple,
                              Colors.amber,
                              Colors.orange,
                              Colors.green,
                            ].map((c) {
                              final isSelected = selectedColor == c;
                              return GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selectedColor = c;
                                  });
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            width: 3,
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final price = double.tryParse(priceController.text) ?? 0.0;
                    final stock = double.tryParse(stockController.text) ?? 0.0;
                    final rawCap = double.tryParse(
                      capacityController.text.trim(),
                    );
                    final capacity = (rawCap == null || rawCap < stock)
                        ? stock
                        : rawCap;
                    final desc = descController.text.trim();

                    if (name.isEmpty || price < 0 || stock < 0) {
                      Helpers.showSnackBar(
                        context,
                        'Please enter valid item details.',
                        isError: true,
                      );
                      return;
                    }

                    final orderProvider = Provider.of<OrderProvider>(
                      context,
                      listen: false,
                    );
                    if (isEditing) {
                      orderProvider.updateInventoryItem(
                        id: itemToEdit['id'] as String,
                        name: name,
                        category: selectedCategory,
                        unit: selectedUnit,
                        price: price,
                        stock: stock,
                        capacity: capacity,
                        color: selectedColor,
                        icon: selectedIcon,
                        description: desc,
                        isRefill: isRefill,
                      );
                      Navigator.of(context).pop();
                      Helpers.showSnackBar(
                        context,
                        'Inventory item "$name" updated successfully!',
                      );
                    } else {
                      orderProvider.addInventoryItem(
                        name: name,
                        category: selectedCategory,
                        unit: selectedUnit,
                        price: price,
                        stock: stock,
                        capacity: capacity,
                        color: selectedColor,
                        icon: selectedIcon,
                        description: desc,
                        isRefill: isRefill,
                      );
                      Navigator.of(context).pop();
                      Helpers.showSnackBar(
                        context,
                        'New item "$name" added to inventory!',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: Text(
                    isEditing ? 'Save Changes' : 'Add Item',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSetStockDialog(bool isDark, Map<String, dynamic> item) {
    final currentStock = (item['stock'] as num).toDouble();
    final currentCap = (item['capacity'] as num).toDouble();
    final currentPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
    final String name = item['name'] as String;
    final String unit = item['unit'] as String? ?? 'Units';
    final Color color = item['color'] as Color? ?? AppTheme.primaryColor;

    final stockController = TextEditingController(
      text: currentStock == 0
          ? '0'
          : currentStock.toStringAsFixed(currentStock % 1 == 0 ? 0 : 1),
    );
    final capacityController = TextEditingController(
      text: currentCap == 0 ? '100' : currentCap.toStringAsFixed(0),
    );
    final priceController = TextEditingController(
      text: currentPrice.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.tune_rounded, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set Stock & Capacity',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Directly set your inventory count and max storage capacity. Replaces hardcoded defaults and persists permanently.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.blue.shade200
                                    : const Color(0xFF1E40AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: stockController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Current Available Stock ($unit)',
                        hintText: 'Enter real available stock',
                        prefixIcon: const Icon(Icons.inventory_2_outlined),
                        helperText:
                            'Recorded stock: ${currentStock.toStringAsFixed(0)} $unit',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: capacityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Max Storage Capacity',
                        hintText: 'e.g. 100, 200, 500',
                        prefixIcon: Icon(Icons.warehouse_rounded),
                        helperText:
                            'Capacity automatically expands if stock exceeds it',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Unit Price (₱)',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final newStock = double.tryParse(
                      stockController.text.trim(),
                    );
                    final newCap = double.tryParse(
                      capacityController.text.trim(),
                    );
                    final newPrice = double.tryParse(
                      priceController.text.trim(),
                    );

                    if (newStock == null || newStock < 0) {
                      Helpers.showSnackBar(
                        context,
                        'Please enter a valid stock amount.',
                        isError: true,
                      );
                      return;
                    }
                    final safeCap = (newCap == null || newCap < newStock)
                        ? newStock
                        : newCap;

                    final orderProvider = Provider.of<OrderProvider>(
                      context,
                      listen: false,
                    );
                    orderProvider.setInventoryStockAndCapacity(
                      item['id'] as String,
                      stock: newStock,
                      capacity: safeCap,
                      price: newPrice,
                    );

                    Navigator.of(context).pop();
                    Helpers.showSnackBar(
                      context,
                      'Updated $name: ${newStock.toInt()} / ${safeCap.toInt()} $unit available.',
                    );
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Save Stock & Capacity'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Set All Inventory Stocks Dialog (All-in-one Quick Table)
  void _showSetAllInventoryDialog(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final items = orderProvider.inventoryItems;

    final controllers = <String, Map<String, TextEditingController>>{};
    for (final item in items) {
      final id = item['id'] as String;
      final stock = (item['stock'] as num).toDouble();
      final cap = (item['capacity'] as num).toDouble();
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      controllers[id] = {
        'stock': TextEditingController(
          text: stock == 0
              ? '0'
              : stock.toStringAsFixed(stock % 1 == 0 ? 0 : 1),
        ),
        'capacity': TextEditingController(
          text: cap == 0 ? '100' : cap.toStringAsFixed(0),
        ),
        'price': TextEditingController(text: price.toStringAsFixed(2)),
      };
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set All Inventory Stocks',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Input actual warehouse inventory counts directly. Persists permanently across reloads.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Item Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Stock',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Max Cap',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Price (₱)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...items.map((item) {
                    final id = item['id'] as String;
                    final name = item['name'] as String;
                    final unit = item['unit'] as String? ?? 'Units';
                    final ctrls = controllers[id]!;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  unit,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: ctrls['stock'],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: ctrls['capacity'],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: ctrls['price'],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final updatedList = <Map<String, dynamic>>[];
                for (final item in items) {
                  final id = item['id'] as String;
                  final ctrls = controllers[id]!;
                  final s = double.tryParse(ctrls['stock']!.text.trim()) ?? 0.0;
                  final c =
                      double.tryParse(ctrls['capacity']!.text.trim()) ?? s;
                  final p =
                      double.tryParse(ctrls['price']!.text.trim()) ??
                      (item['price'] as num).toDouble();
                  updatedList.add({
                    'id': id,
                    'stock': max(0.0, s),
                    'capacity': max(c, s),
                    'price': p,
                  });
                }

                orderProvider.setAllInventoryLevels(updatedList);

                Navigator.of(context).pop();
                Helpers.showSnackBar(
                  context,
                  'All inventory stocks updated and saved successfully!',
                );
              },
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Save All Levels'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
            ),
          ],
        );
      },
    );
  }

  // Quick Restock Dialog
  void _showRestockDialog(bool isDark, Map<String, dynamic> item) {
    final amountController = TextEditingController(text: '15');
    final String name = item['name'] as String;
    final double stock = (item['stock'] as num).toDouble();
    final double capacity = (item['capacity'] as num).toDouble();
    final String unit = item['unit'] as String? ?? 'Units';
    final Color color = item['color'] as Color? ?? AppTheme.primaryColor;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final addAmt = double.tryParse(amountController.text) ?? 0.0;
            final projectedStock = stock + (addAmt > 0 ? addAmt : 0.0);

            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              title: Row(
                children: [
                  Icon(Icons.add_shopping_cart_rounded, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Restock / Refill $name',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Stock: ${stock.toStringAsFixed(0)} / ${capacity.toStringAsFixed(0)} $unit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'New Stock will be: ${projectedStock.toStringAsFixed(0)} $unit',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Quick Add Amount:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5.0, 10.0, 15.0, 25.0, 50.0, 100.0].map((amt) {
                      return ActionChip(
                        label: Text('+$amt $unit'),
                        onPressed: () {
                          setDialogState(() {
                            amountController.text = amt.toStringAsFixed(0);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    onChanged: (_) => setDialogState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Custom Restock Quantity ($unit)',
                      prefixIcon: const Icon(Icons.add_box_rounded),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amt = double.tryParse(amountController.text) ?? 0.0;
                    if (amt <= 0) {
                      Helpers.showSnackBar(
                        context,
                        'Please enter a valid positive quantity.',
                        isError: true,
                      );
                      return;
                    }
                    final orderProvider = Provider.of<OrderProvider>(
                      context,
                      listen: false,
                    );
                    orderProvider.restockInventoryItem(
                      item['id'] as String,
                      amt,
                      restockedBy: 'harold borbo (Admin)',
                      notes: 'Manual inventory restock',
                    );
                    Navigator.of(context).pop();
                    setState(() {});
                    Helpers.showSnackBar(
                      context,
                      'Restocked +$amt $unit to $name! Stock updated automatically.',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text(
                    'Confirm Restock',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Delete Item Dialog
  void _showDeleteItemDialog(bool isDark, Map<String, dynamic> item) {
    final String name = item['name'] as String;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          title: const Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Remove Item from Inventory'),
            ],
          ),
          content: Text(
            'Are you sure you want to remove "$name" from the inventory catalog? This action cannot be undone.',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final orderProvider = Provider.of<OrderProvider>(
                  context,
                  listen: false,
                );
                orderProvider.deleteInventoryItem(item['id'] as String);
                Navigator.of(context).pop();
                setState(() {});
                Helpers.showSnackBar(
                  context,
                  'Removed "$name" from inventory.',
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // Return Gallon Dialog
  void _showReturnGallonDialog(bool isDark, Map<String, dynamic> borrow) {
    final qtyController = TextEditingController(
      text: '${borrow['quantity'] ?? 1}',
    );
    final customerName = borrow['customerName'] ?? 'Customer';
    final gallonType = borrow['gallonType'] ?? '5-Gallon Slim';
    final int borrowedQty = (borrow['quantity'] as num?)?.toInt() ?? 1;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_return_rounded,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Return Containers',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.person_rounded,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            customerName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.water_drop_rounded,
                          size: 16,
                          color: Colors.cyan,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$gallonType • Borrowed: $borrowedQty unit(s)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    if (borrow['deliveryAddress'] != null &&
                        borrow['deliveryAddress'].toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              borrow['deliveryAddress'].toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Confirm Return Quantity:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Units to return to inventory',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Returning will automatically increase available inventory stock.',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(qtyController.text) ?? borrowedQty;
                if (qty <= 0) {
                  Helpers.showSnackBar(
                    context,
                    'Please enter a valid return quantity.',
                    isError: true,
                  );
                  return;
                }
                final orderProvider = Provider.of<OrderProvider>(
                  context,
                  listen: false,
                );
                orderProvider.returnBorrowedGallons(
                  orderId: borrow['orderId'] as String,
                  gallonType: gallonType,
                  quantity: qty,
                  customerName: customerName,
                );
                Navigator.of(context).pop();
                setState(() {});
                Helpers.showSnackBar(
                  context,
                  'Returned $qty x $gallonType from $customerName into inventory stock! Live stock updated.',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Confirm & Return to Stock',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Schedule Weekly Gallon Collection Dialog
  void _showScheduleCollectionDialog(
    bool isDark, {
    Map<String, dynamic>? preselectedBorrow,
  }) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final driversList = _allUsers
        .where((u) => u.role == UserRole.driver)
        .toList();
    final activeBorrows = orderProvider.customerBorrows
        .where((b) => b['isReturned'] == false)
        .toList();

    if (driversList.isEmpty) {
      Helpers.showSnackBar(
        context,
        'No drivers registered in the system yet. Please create a driver user first.',
        isError: true,
      );
      return;
    }

    if (activeBorrows.isEmpty && preselectedBorrow == null) {
      Helpers.showSnackBar(
        context,
        'There are no customers currently holding borrowed gallons to collect.',
        isError: true,
      );
      return;
    }

    // Calculate station totals across all borrowers
    int totalSlimAcrossAll = 0;
    int totalRoundAcrossAll = 0;
    for (final b in activeBorrows) {
      final s =
          b['gallonType']?.toString().toLowerCase().contains('slim') ?? false;
      final r =
          b['gallonType']?.toString().toLowerCase().contains('round') ?? false;
      final q = (b['quantity'] as num?)?.toInt() ?? 1;
      if (s) totalSlimAcrossAll += q;
      if (r) totalRoundAcrossAll += q;
    }

    String selectedBorrowKey = preselectedBorrow != null
        ? '${preselectedBorrow['orderId']}_${preselectedBorrow['gallonType']}'
        : 'all_borrowers';

    UserModel? selectedDriver = driversList.first;

    final isPreSlim = preselectedBorrow != null
        ? (preselectedBorrow['gallonType']?.toString().toLowerCase().contains(
                'slim',
              ) ??
              false)
        : false;
    final isPreRound = preselectedBorrow != null
        ? (preselectedBorrow['gallonType']?.toString().toLowerCase().contains(
                'round',
              ) ??
              false)
        : false;
    final preQty = preselectedBorrow != null
        ? ((preselectedBorrow['quantity'] as num?)?.toInt() ?? 1)
        : 0;

    final slimController = TextEditingController(
      text: preselectedBorrow != null
          ? (isPreSlim ? '$preQty' : '0')
          : '$totalSlimAcrossAll',
    );
    final roundController = TextEditingController(
      text: preselectedBorrow != null
          ? (isPreRound ? '$preQty' : '0')
          : '$totalRoundAcrossAll',
    );
    final notesController = TextEditingController();
    String selectedSchedule = 'Weekly Regular Collection (Every Monday)';

    final scheduleOptions = [
      'Weekly Regular Collection (Every Monday)',
      'Weekly Regular Collection (Every Wednesday)',
      'Weekly Regular Collection (Every Friday)',
      'Weekly Regular Collection (Every Weekend)',
      'Special Scheduled Dispatch Today',
      'Next Driver Route Run',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
            final textCol = isDark ? Colors.white : const Color(0xFF1E293B);
            final subCol = isDark ? Colors.white70 : const Color(0xFF64748B);
            final isAllSelected = selectedBorrowKey == 'all_borrowers';

            return AlertDialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_add,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule Weekly Gallon Collection',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textCol,
                          ),
                        ),
                        Text(
                          isAllSelected
                              ? 'Batch route: Assign driver to collect from all ${activeBorrows.length} borrowers'
                              : 'Assign driver to retrieve empty jugs from specific customer',
                          style: TextStyle(fontSize: 12, color: subCol),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Select Customer Holding Gallons or All Borrowers
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Borrower Customer Selection',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textCol,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isAllSelected
                                  ? const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.15)
                                  : Colors.blue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAllSelected
                                  ? 'All Borrowers Mode'
                                  : 'Single Customer Mode',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isAllSelected
                                    ? const Color(0xFF047857)
                                    : Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFFCBD5E1),
                          ),
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF8FAFC),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedBorrowKey,
                            dropdownColor: cardBg,
                            items: [
                              // OPTION 1: ALL BORROWERS
                              DropdownMenuItem<String>(
                                value: 'all_borrowers',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.route_rounded,
                                      size: 16,
                                      color: Color(0xFF10B981),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '🌟 ALL BORROWERS — Weekly Full Route (${activeBorrows.length} Customers • $totalSlimAcrossAll Slim, $totalRoundAcrossAll Round)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF047857),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // INDIVIDUAL BORROWERS
                              ...activeBorrows.map((b) {
                                final key =
                                    '${b['orderId']}_${b['gallonType']}';
                                final name =
                                    b['customerName'] as String? ?? 'Customer';
                                final gType =
                                    b['gallonType'] as String? ?? 'Gallon';
                                final qty = b['quantity']?.toString() ?? '1';
                                final addr =
                                    b['deliveryAddress'] as String? ?? '';
                                return DropdownMenuItem<String>(
                                  value: key,
                                  child: Text(
                                    '👤 $name (Owes $qty $gType) • $addr',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: textCol,
                                    ),
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedBorrowKey = val;
                                  if (val == 'all_borrowers') {
                                    slimController.text = '$totalSlimAcrossAll';
                                    roundController.text =
                                        '$totalRoundAcrossAll';
                                  } else {
                                    final found = activeBorrows.firstWhere(
                                      (b) =>
                                          '${b['orderId']}_${b['gallonType']}' ==
                                          val,
                                      orElse: () => activeBorrows.first,
                                    );
                                    final s =
                                        found['gallonType']
                                            ?.toString()
                                            .toLowerCase()
                                            .contains('slim') ??
                                        false;
                                    final r =
                                        found['gallonType']
                                            ?.toString()
                                            .toLowerCase()
                                            .contains('round') ??
                                        false;
                                    final q =
                                        (found['quantity'] as num?)?.toInt() ??
                                        1;
                                    slimController.text = s ? '$q' : '0';
                                    roundController.text = r ? '$q' : '0';
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      if (isAllSelected) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.alt_route_rounded,
                                size: 16,
                                color: Color(0xFF059669),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Full Route Mode: Dispatches weekly collection tasks to ${selectedDriver?.name ?? 'Driver'} for all ${activeBorrows.length} customers holding containers ($totalSlimAcrossAll Slim, $totalRoundAcrossAll Round).',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Select Driver
                      Text(
                        'Assign Driver / Rider',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textCol,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFFCBD5E1),
                          ),
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF8FAFC),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<UserModel>(
                            isExpanded: true,
                            value: selectedDriver,
                            dropdownColor: cardBg,
                            items: driversList.map((d) {
                              return DropdownMenuItem<UserModel>(
                                value: d,
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delivery_dining_rounded,
                                      size: 18,
                                      color: AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${d.name} (${d.email})',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textCol,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedDriver = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Weekly Schedule Selection
                      Text(
                        'Weekly Schedule / Timing',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textCol,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFFCBD5E1),
                          ),
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF8FAFC),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedSchedule,
                            dropdownColor: cardBg,
                            items: scheduleOptions.map((opt) {
                              return DropdownMenuItem<String>(
                                value: opt,
                                child: Text(
                                  opt,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textCol,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedSchedule = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Gallons to Collect
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: slimController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Slim Gallons Target',
                                prefixIcon: Icon(
                                  Icons.water_drop_rounded,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                                helperText: '5-Gallon Slim count',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: roundController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Round Gallons Target',
                                prefixIcon: Icon(
                                  Icons.radio_button_checked_rounded,
                                  size: 16,
                                  color: Colors.indigo,
                                ),
                                helperText: '5-Gallon Round count',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Dispatch Note
                      TextField(
                        controller: notesController,
                        decoration: InputDecoration(
                          labelText: 'Dispatch Instructions / Notes (Optional)',
                          hintText: isAllSelected
                              ? 'e.g. Weekly full route collection for all borrowing customers'
                              : 'e.g. Call customer before arrival at Purok 1 gate',
                          prefixIcon: const Icon(
                            Icons.note_alt_outlined,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (selectedDriver == null) return;
                    final slim = int.tryParse(slimController.text.trim()) ?? 0;
                    final round =
                        int.tryParse(roundController.text.trim()) ?? 0;
                    if (slim <= 0 && round <= 0) {
                      Helpers.showSnackBar(
                        ctx,
                        'Please set at least 1 Slim or Round gallon to collect.',
                        isError: true,
                      );
                      return;
                    }

                    if (isAllSelected) {
                      // BATCH ROUTE: Dispatch collection job orders for each active borrower
                      for (final b in activeBorrows) {
                        final s =
                            b['gallonType']?.toString().toLowerCase().contains(
                              'slim',
                            ) ??
                            false;
                        final r =
                            b['gallonType']?.toString().toLowerCase().contains(
                              'round',
                            ) ??
                            false;
                        final q = (b['quantity'] as num?)?.toInt() ?? 1;

                        await orderProvider.createCollectionJobOrder(
                          customerId:
                              b['customerId'] as String? ?? 'usr_borrower',
                          customerName:
                              b['customerName'] as String? ?? 'Customer',
                          customerPhone:
                              b['customerPhone'] as String? ??
                              '+63 912 345 6789',
                          deliveryAddress:
                              b['deliveryAddress'] as String? ?? 'Ligao City',
                          driverId: selectedDriver!.id,
                          driverName: selectedDriver!.name,
                          slimCount: s ? q : 0,
                          roundCount: r ? q : 0,
                          scheduledDate: selectedSchedule,
                          notes: notesController.text.trim().isNotEmpty
                              ? notesController.text.trim()
                              : 'Weekly Full Route Collection',
                        );
                      }

                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                      }
                      if (!mounted) return;
                      setState(() {});
                      Helpers.showSnackBar(
                        this.context,
                        'Weekly collection route created! Dispatched tasks for all ${activeBorrows.length} customers to ${selectedDriver!.name}.',
                      );
                    } else {
                      // SINGLE CUSTOMER SELECTION
                      final selectedBorrow = activeBorrows.firstWhere(
                        (b) =>
                            '${b['orderId']}_${b['gallonType']}' ==
                            selectedBorrowKey,
                        orElse: () => activeBorrows.first,
                      );

                      await orderProvider.createCollectionJobOrder(
                        customerId:
                            selectedBorrow['customerId'] as String? ??
                            'usr_borrower',
                        customerName:
                            selectedBorrow['customerName'] as String? ??
                            'Customer',
                        customerPhone:
                            selectedBorrow['customerPhone'] as String? ??
                            '+63 912 345 6789',
                        deliveryAddress:
                            selectedBorrow['deliveryAddress'] as String? ??
                            'Ligao City',
                        driverId: selectedDriver!.id,
                        driverName: selectedDriver!.name,
                        slimCount: slim,
                        roundCount: round,
                        scheduledDate: selectedSchedule,
                        notes: notesController.text.trim().isNotEmpty
                            ? notesController.text.trim()
                            : null,
                      );

                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                      }
                      if (!mounted) return;
                      setState(() {});
                      Helpers.showSnackBar(
                        this.context,
                        'Weekly collection task created! Dispatched to ${selectedDriver!.name} for ${selectedBorrow['customerName']}.',
                      );
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text(
                    isAllSelected
                        ? 'Dispatch Route (${activeBorrows.length} Customers)'
                        : 'Dispatch Task to Driver',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAllSelected
                        ? const Color(0xFF059669)
                        : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBorrowFilterChip(
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _borrowFilter == value;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white70 : const Color(0xFF64748B)),
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white70 : const Color(0xFF334155)),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? AppTheme.primaryColor
              : (isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _borrowFilter = value;
          });
        }
      },
    );
  }

  // TAB 4: INVENTORY & RESERVES (Comprehensive Catalog, Full CRUD, Filters & Stocks)
  Widget _buildInventoryTab(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final cardBgColor = isDark ? AppTheme.darkSurface : Colors.white;
    final titleTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final valueTextColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    final allItems = orderProvider.inventoryItems.where((i) {
      if (_inventoryCategoryFilter == 'all') return true;
      return i['category'] == _inventoryCategoryFilter;
    }).toList();

    // Gallon Metrics
    final slimRemaining = orderProvider.remainingSlimGallons;
    final slimCap = orderProvider.slimGallonCapacity;
    final slimRatio = slimCap > 0
        ? (slimRemaining / slimCap).clamp(0.0, 1.0)
        : 0.0;
    final activeSlimBorrows = orderProvider.activeSlimBorrowedGallons;

    final roundRemaining = orderProvider.remainingRoundGallons;
    final roundCap = orderProvider.roundGallonCapacity;
    final roundRatio = roundCap > 0
        ? (roundRemaining / roundCap).clamp(0.0, 1.0)
        : 0.0;
    final activeRoundBorrows = orderProvider.activeRoundBorrowedGallons;

    final totalActiveBorrows = orderProvider.totalActiveBorrowedGallons;
    final customerBorrows = orderProvider.customerBorrows;

    // Filter by search query for Container Items tab
    final query = _inventorySearchController.text.trim().toLowerCase();
    final filteredItems = query.isEmpty
        ? allItems
        : allItems.where((i) {
            final name = (i['name'] as String? ?? '').toLowerCase();
            final desc = (i['description'] as String? ?? '').toLowerCase();
            return name.contains(query) || desc.contains(query);
          }).toList();

    // Filter Borrows tab
    final borrowQuery = _borrowSearchController.text.trim().toLowerCase();
    final filteredBorrows = customerBorrows.where((b) {
      if (_borrowFilter == 'active' && b['isReturned'] == true) {
        return false;
      }
      if (_borrowFilter == 'returned' && b['isReturned'] == false) {
        return false;
      }
      if (_borrowFilter == 'slim' &&
          !(b['gallonType'] as String).toLowerCase().contains('slim')) {
        return false;
      }
      if (_borrowFilter == 'round' &&
          !(b['gallonType'] as String).toLowerCase().contains('round')) {
        return false;
      }

      if (borrowQuery.isNotEmpty) {
        final custName = (b['customerName'] as String? ?? '').toLowerCase();
        final phone = (b['customerPhone'] as String? ?? '').toLowerCase();
        final addr = (b['deliveryAddress'] as String? ?? '').toLowerCase();
        final gType = (b['gallonType'] as String? ?? '').toLowerCase();
        final txn = (b['txnId'] as String? ?? '').toLowerCase();
        final ordId = (b['orderId'] as String? ?? '').toLowerCase();
        return custName.contains(borrowQuery) ||
            phone.contains(borrowQuery) ||
            addr.contains(borrowQuery) ||
            gType.contains(borrowQuery) ||
            txn.contains(borrowQuery) ||
            ordId.contains(borrowQuery);
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inventory & Gallon Tracking',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage products, container stocks, and borrowed gallons.',
                    style: TextStyle(fontSize: 12, color: titleTextColor),
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showSetAllInventoryDialog(isDark),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text(
                      'Set All Stock Levels',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditInventoryItemDialog(isDark),
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Add Product / Item',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // SECTION 1: PURIFIED WATER (PRODUCT THAT NEVER RUNS OUT)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF0284C7).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Color(0xFF0284C7),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Purified Water',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: valueTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Primary water refill product • ₱30.00 / refill',
                        style: TextStyle(
                          fontSize: 12,
                          color: titleTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.all_inclusive_rounded,
                        size: 15,
                        color: Color(0xFF047857),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Always Available',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // SECTION 2: PHYSICAL CONTAINERS
          Text(
            'Container Stocks',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),

          // TOP HERO CARDS: Remaining Slim & Round Gallons
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 850;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                children: [
                  // CARD 1: 5-Gallon Slim Container
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: slimRemaining <= 10
                              ? Colors.red.withValues(alpha: 0.5)
                              : (slimRemaining <= 25
                                    ? Colors.orange.withValues(alpha: 0.5)
                                    : borderColor),
                          width: slimRemaining <= 25 ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.asset(
                                  'assets/images/slim_gallon.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.water_drop_rounded,
                                    color: Colors.blue,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '5-Gallon Slim Container',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: valueTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Faucet & Handle Dispenser Model',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: titleTextColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (slimRemaining <= 10
                                              ? Colors.red
                                              : (slimRemaining <= 25
                                                    ? Colors.orange
                                                    : Colors.green))
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  slimRemaining <= 10
                                      ? 'Low Stock'
                                      : (slimRemaining <= 0
                                            ? 'Out of Stock'
                                            : 'In Stock'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: slimRemaining <= 10
                                        ? Colors.red
                                        : (slimRemaining <= 25
                                              ? Colors.orange
                                              : Colors.green),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${slimRemaining.toInt()}',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.blueAccent
                                      : const Color(0xFF1D4ED8),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 6,
                                  left: 6,
                                ),
                                child: Text(
                                  '/ ${slimCap.toInt()} Remaining Stock',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: titleTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: slimRatio,
                              minHeight: 8,
                              backgroundColor: isDark
                                  ? Colors.white10
                                  : const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                slimRemaining <= 10
                                    ? Colors.red
                                    : (slimRemaining <= 25
                                          ? Colors.orange
                                          : Colors.blue),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.people_alt_rounded,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Borrowed: $activeSlimBorrows Gallons',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.amberAccent
                                            : const Color(0xFFB45309),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      final slimItem = allItems.firstWhere(
                                        (i) =>
                                            i['id'] == 'item_slim_gallon' ||
                                            i['name']
                                                .toString()
                                                .toLowerCase()
                                                .contains('slim'),
                                        orElse: () => allItems.isNotEmpty
                                            ? allItems.first
                                            : <String, dynamic>{},
                                      );
                                      if (slimItem.isNotEmpty) {
                                        _showSetStockDialog(isDark, slimItem);
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.tune_rounded,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Set Stock',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      final slimItem = allItems.firstWhere(
                                        (i) =>
                                            i['id'] == 'item_slim_gallon' ||
                                            i['name']
                                                .toString()
                                                .toLowerCase()
                                                .contains('slim'),
                                        orElse: () => allItems.isNotEmpty
                                            ? allItems.first
                                            : <String, dynamic>{},
                                      );
                                      if (slimItem.isNotEmpty) {
                                        _showRestockDialog(isDark, slimItem);
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.add_shopping_cart_rounded,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Restock Slim',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isWide)
                    const SizedBox(width: 16)
                  else
                    const SizedBox(height: 16),

                  // CARD 2: 5-Gallon Round Container
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: roundRemaining <= 10
                              ? Colors.red.withValues(alpha: 0.5)
                              : (roundRemaining <= 25
                                    ? Colors.orange.withValues(alpha: 0.5)
                                    : borderColor),
                          width: roundRemaining <= 25 ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.asset(
                                  'assets/images/round_gallon.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.water_drop_rounded,
                                    color: Colors.indigo,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '5-Gallon Round Container',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: valueTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Standard Water Dispenser Model',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: titleTextColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (roundRemaining <= 10
                                              ? Colors.red
                                              : (roundRemaining <= 25
                                                    ? Colors.orange
                                                    : Colors.green))
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  roundRemaining <= 10
                                      ? 'Low Stock'
                                      : (roundRemaining <= 0
                                            ? 'Out of Stock'
                                            : 'In Stock'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: roundRemaining <= 10
                                        ? Colors.red
                                        : (roundRemaining <= 25
                                              ? Colors.orange
                                              : Colors.green),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${roundRemaining.toInt()}',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.indigoAccent
                                      : const Color(0xFF4338CA),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 6,
                                  left: 6,
                                ),
                                child: Text(
                                  '/ ${roundCap.toInt()} Remaining Stock',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: titleTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: roundRatio,
                              minHeight: 8,
                              backgroundColor: isDark
                                  ? Colors.white10
                                  : const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                roundRemaining <= 10
                                    ? Colors.red
                                    : (roundRemaining <= 25
                                          ? Colors.orange
                                          : Colors.indigo),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.people_alt_rounded,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Borrowed: $activeRoundBorrows Gallons',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.amberAccent
                                            : const Color(0xFFB45309),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      final roundItem = allItems.firstWhere(
                                        (i) =>
                                            i['id'] == 'item_round_gallon' ||
                                            i['name']
                                                .toString()
                                                .toLowerCase()
                                                .contains('round'),
                                        orElse: () => allItems.isNotEmpty
                                            ? allItems.first
                                            : <String, dynamic>{},
                                      );
                                      if (roundItem.isNotEmpty) {
                                        _showSetStockDialog(isDark, roundItem);
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.tune_rounded,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Set Stock',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      final roundItem = allItems.firstWhere(
                                        (i) =>
                                            i['id'] == 'item_round_gallon' ||
                                            i['name']
                                                .toString()
                                                .toLowerCase()
                                                .contains('round'),
                                        orElse: () => allItems.isNotEmpty
                                            ? allItems.first
                                            : <String, dynamic>{},
                                      );
                                      if (roundItem.isNotEmpty) {
                                        _showRestockDialog(isDark, roundItem);
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.add_shopping_cart_rounded,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Restock Round',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // SUBTAB SWITCHER: Container Catalog vs Customer Gallon Borrows Log
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _inventorySubTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _inventorySubTab == 0
                            ? (isDark ? AppTheme.darkSurface : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _inventorySubTab == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_rounded,
                            size: 16,
                            color: _inventorySubTab == 0
                                ? AppTheme.primaryColor
                                : titleTextColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Products & Inventory Stock',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _inventorySubTab == 0
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _inventorySubTab == 0
                                  ? valueTextColor
                                  : titleTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _inventorySubTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _inventorySubTab == 1
                            ? (isDark ? AppTheme.darkSurface : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _inventorySubTab == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_ind_rounded,
                            size: 16,
                            color: _inventorySubTab == 1
                                ? AppTheme.primaryColor
                                : titleTextColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Customer Borrowed Gallons Log',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _inventorySubTab == 1
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _inventorySubTab == 1
                                  ? valueTextColor
                                  : titleTextColor,
                            ),
                          ),
                          if (totalActiveBorrows > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$totalActiveBorrows',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _inventorySubTab = 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _inventorySubTab == 2
                            ? (isDark ? AppTheme.darkSurface : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _inventorySubTab == 2
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 16,
                            color: _inventorySubTab == 2
                                ? AppTheme.primaryColor
                                : titleTextColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Restock Activity History',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _inventorySubTab == 2
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _inventorySubTab == 2
                                  ? valueTextColor
                                  : titleTextColor,
                            ),
                          ),
                          if (orderProvider.restockLogs.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${orderProvider.restockLogs.length}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // SUBTAB CONTENT
          if (_inventorySubTab == 0) ...[
            // Recent Restock Quick Alert Banner
            if (orderProvider.restockLogs.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Latest Restock: +${orderProvider.restockLogs.first['amount'].toInt()} ${orderProvider.restockLogs.first['unit']} to ${orderProvider.restockLogs.first['itemName']} (Now: ${orderProvider.restockLogs.first['newStock'].toInt()} ${orderProvider.restockLogs.first['unit']}) • ${orderProvider.restockLogs.first['restockedBy']}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.greenAccent
                              : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _inventorySubTab = 2),
                      child: const Text(
                        'View Full History',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Products Catalog Search Bar & Category Filter
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _inventorySearchController,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText:
                          'Search products, refills, containers, or accessories...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _inventorySearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _inventorySearchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildInventoryCategoryFilterChip(
                          'all',
                          'All Items (${orderProvider.inventoryItems.length})',
                          Icons.grid_view_rounded,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildInventoryCategoryFilterChip(
                          'water',
                          'Water Products (${orderProvider.inventoryItems.where((i) => i['category'] == 'water').length})',
                          Icons.water_drop_rounded,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildInventoryCategoryFilterChip(
                          'container',
                          'Containers (${orderProvider.inventoryItems.where((i) => i['category'] == 'container').length})',
                          Icons.inventory_2_rounded,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildInventoryCategoryFilterChip(
                          'accessory',
                          'Accessories (${orderProvider.inventoryItems.where((i) => i['category'] == 'accessory').length})',
                          Icons.shopping_bag_rounded,
                          isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Container Items Grid
            if (filteredItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No inventory items match your search or category filter.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: titleTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditInventoryItemDialog(isDark),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Product / Item'),
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredItems.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 420,
                  mainAxisExtent: 220,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (context, index) {
                  final prod = filteredItems[index];
                  final String name = prod['name'] as String;
                  final double stock = (prod['stock'] as num).toDouble();
                  final double capacity = (prod['capacity'] as num).toDouble();
                  final double price = (prod['price'] as num).toDouble();
                  final String unit = prod['unit'] as String? ?? 'Units';
                  final Color color =
                      prod['color'] as Color? ?? AppTheme.primaryColor;
                  final String? imagePath = prod['image'] as String?;
                  final IconData icon =
                      prod['icon'] as IconData? ?? Icons.inventory_2_rounded;

                  final ratio = capacity > 0
                      ? (stock / capacity).clamp(0.0, 1.0)
                      : 0.0;
                  final bool isOutOfStock = stock <= 0;
                  final bool isLowStock = !isOutOfStock && ratio < 0.3;

                  String statusLabel = 'In Stock';
                  Color statusColor = Colors.green;
                  if (isOutOfStock) {
                    statusLabel = 'Out of Stock';
                    statusColor = Colors.red;
                  } else if (isLowStock) {
                    statusLabel = 'Low Stock';
                    statusColor = Colors.orange;
                  }

                  final String category =
                      prod['category'] as String? ?? 'container';
                  final bool isUnlimitedWater =
                      prod['id'] == 'prod_purified' ||
                      name.toLowerCase() == 'purified water';
                  final bool isRefillItem =
                      prod['is_refill'] == true ||
                      (category == 'water' &&
                          (unit.toLowerCase() == 'gallons' ||
                              name.toLowerCase().contains('refill') ||
                              name.toLowerCase().contains('purified') ||
                              name.toLowerCase().contains('19l')));
                  if (isUnlimitedWater) {
                    statusLabel = 'Always Available';
                    statusColor = const Color(0xFF047857);
                  }
                  final String categoryBadgeText = isRefillItem
                      ? 'Water Refill'
                      : (category == 'water'
                            ? 'Water Product'
                            : (category == 'accessory'
                                  ? 'Accessory'
                                  : 'Container'));

                  return Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: !isUnlimitedWater && isLowStock
                            ? Colors.orange.withValues(alpha: 0.4)
                            : (!isUnlimitedWater && isOutOfStock
                                  ? Colors.red.withValues(alpha: 0.4)
                                  : borderColor),
                        width:
                            (!isUnlimitedWater && (isLowStock || isOutOfStock))
                            ? 1.5
                            : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: imagePath != null
                                        ? Image.asset(
                                            imagePath,
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Icon(
                                                      icon,
                                                      color: color,
                                                      size: 20,
                                                    ),
                                          )
                                        : Icon(icon, color: color, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: valueTextColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          categoryBadgeText,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: titleTextColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Stock Available Text
                        Text(
                          isUnlimitedWater
                              ? 'Unlimited Supply • Never Runs Out'
                              : '${stock.toStringAsFixed(stock % 1 == 0 ? 0 : 1)} / ${capacity.toStringAsFixed(0)} $unit',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: valueTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Progress Indicator
                        if (!isUnlimitedWater)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 6,
                              backgroundColor: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                statusColor,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 6),
                        const SizedBox(height: 8),

                        // Price and actions row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₱${price.toStringAsFixed(2)} / $unit',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.cyanAccent
                                    : AppTheme.primaryColor,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Set Stock & Capacity',
                                  icon: Icon(
                                    Icons.tune_rounded,
                                    size: 18,
                                    color: color,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _showSetStockDialog(isDark, prod),
                                ),
                                IconButton(
                                  tooltip: 'Restock',
                                  icon: Icon(
                                    Icons.add_shopping_cart_rounded,
                                    size: 18,
                                    color: color,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _showRestockDialog(isDark, prod),
                                ),
                                IconButton(
                                  tooltip: 'Edit Details',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _showAddEditInventoryItemDialog(
                                        isDark,
                                        prod,
                                      ),
                                ),
                                IconButton(
                                  tooltip: 'Delete Item',
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _showDeleteItemDialog(isDark, prod),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ] else if (_inventorySubTab == 1) ...[
            // CUSTOMER BORROWED GALLONS LOG VIEW
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Input
                  TextField(
                    controller: _borrowSearchController,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText:
                          'Search borrowers by customer name, phone, address, or order ID...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _borrowSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _borrowSearchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildBorrowFilterChip(
                          'All Records',
                          'all',
                          Icons.list_alt_rounded,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildBorrowFilterChip(
                          'Currently Holding Gallons',
                          'active',
                          Icons.pending_actions_rounded,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildBorrowFilterChip(
                          'Returned Gallons',
                          'returned',
                          Icons.check_circle_outline_rounded,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildBorrowFilterChip(
                          'Slim Gallons',
                          'slim',
                          Icons.water_drop_rounded,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildBorrowFilterChip(
                          'Round Gallons',
                          'round',
                          Icons.radio_button_checked_rounded,
                          isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Borrows List
            if (filteredBorrows.isEmpty)
              Container(
                padding: const EdgeInsets.all(48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 52,
                      color: const Color(0xFF64748B).withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No borrowed gallons match this filter.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: valueTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'When customers place orders with gallon containers, their borrowing log will appear here automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: titleTextColor),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredBorrows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final borrow = filteredBorrows[index];
                  final String phone =
                      borrow['customerPhone'] as String? ?? 'No phone';
                  String custName =
                      borrow['customerName'] as String? ?? 'Customer';
                  if (custName.trim().isEmpty ||
                      custName.trim().toLowerCase() == 'new user') {
                    final cid = (borrow['customerId'] ?? '').toString();
                    final match = _allUsers.cast<UserModel?>().firstWhere(
                      (u) =>
                          u != null &&
                          u.id == cid &&
                          u.name.trim().isNotEmpty &&
                          u.name.trim().toLowerCase() != 'new user',
                      orElse: () => null,
                    );
                    if (match != null) {
                      custName = match.name.trim();
                    } else if (phone.isNotEmpty &&
                        phone != 'No phone' &&
                        phone != '+63 912 345 6789') {
                      custName = 'Customer ($phone)';
                    } else {
                      custName = 'Customer';
                    }
                  }
                  final String address =
                      borrow['deliveryAddress'] as String? ?? 'No address';
                  final String displayAddress = address
                      .replaceAll(RegExp(r'\[BORROWED_[A-Z]+:\d+\]'), '')
                      .replaceAll('[GALLONS_RETURNED]', '')
                      .trim();
                  final String gType =
                      borrow['gallonType'] as String? ?? '5-Gallon Container';
                  final int qty = (borrow['quantity'] as num?)?.toInt() ?? 1;
                  final bool isReturned =
                      borrow['isReturned'] as bool? ?? false;
                  final String txn = borrow['txnId'] as String? ?? '';
                  final DateTime? date = borrow['borrowedAt'] as DateTime?;
                  final dateStr = date != null
                      ? '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                      : 'Recent';

                  final isSlim = gType.toLowerCase().contains('slim');

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isReturned
                            ? borderColor
                            : Colors.amber.withValues(alpha: 0.4),
                        width: isReturned ? 1.0 : 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Container Icon
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSlim
                                ? Colors.blue.withValues(alpha: 0.12)
                                : Colors.indigo.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            isSlim
                                ? 'assets/images/slim_gallon.png'
                                : 'assets/images/round_gallon.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.water_drop_rounded,
                              color: isSlim ? Colors.blue : Colors.indigo,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Customer & Container Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    custName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: valueTextColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (isSlim ? Colors.blue : Colors.indigo)
                                              .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      gType,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSlim
                                            ? Colors.blue
                                            : Colors.indigo,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Qty: $qty',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone_rounded,
                                    size: 12,
                                    color: titleTextColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    phone,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: titleTextColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 12,
                                    color: titleTextColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      displayAddress.isNotEmpty
                                          ? displayAddress
                                          : address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: titleTextColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Order: $txn',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey.shade500,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '• $dateStr',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Return Status & Action
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (isReturned ? Colors.green : Colors.amber)
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isReturned
                                        ? Icons.check_circle_rounded
                                        : Icons.pending_rounded,
                                    size: 13,
                                    color: isReturned
                                        ? Colors.green
                                        : Colors.amber.shade800,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isReturned ? 'Returned' : 'Holding Gallons',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isReturned
                                          ? Colors.green
                                          : (isDark
                                                ? Colors.amberAccent
                                                : Colors.amber.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (!isReturned) ...[
                              Builder(
                                builder: (context) {
                                  final activeCollectionJob = orderProvider
                                      .orders
                                      .cast<OrderModel?>()
                                      .firstWhere(
                                        (o) =>
                                            o != null &&
                                            o.isCollectionJob &&
                                            (o.customerId ==
                                                    (borrow['customerId'] ??
                                                        '') ||
                                                o.customerName
                                                        .trim()
                                                        .toLowerCase() ==
                                                    custName
                                                        .trim()
                                                        .toLowerCase()) &&
                                            o.orderStatus !=
                                                OrderStatus.cancelled &&
                                            o.orderStatus !=
                                                OrderStatus.completed,
                                        orElse: () => null,
                                      );

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (activeCollectionJob != null)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.blue.withValues(
                                                alpha: 0.3,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.delivery_dining_rounded,
                                                size: 13,
                                                color: Colors.blue,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Dispatched: ${activeCollectionJob.driverName ?? 'Driver'} (${activeCollectionJob.orderStatus.displayName})',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        alignment: WrapAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                _showScheduleCollectionDialog(
                                                  isDark,
                                                  preselectedBorrow: borrow,
                                                ),
                                            icon: const Icon(
                                              Icons.send_rounded,
                                              size: 13,
                                            ),
                                            label: Text(
                                              activeCollectionJob != null
                                                  ? 'Reassign'
                                                  : 'Dispatch to Driver',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppTheme.primaryColor,
                                              side: const BorderSide(
                                                color: AppTheme.primaryColor,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _showReturnGallonDialog(
                                                  isDark,
                                                  borrow,
                                                ),
                                            icon: const Icon(
                                              Icons.assignment_return_rounded,
                                              size: 13,
                                              color: Colors.white,
                                            ),
                                            label: const Text(
                                              'Return Gallons',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ] else if (_inventorySubTab == 2) ...[
            // RESTOCK ACTIVITY HISTORY VIEW
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Restock & Inventory Audit Trail',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: valueTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Live chronological log of all container replenishments and returns.',
                        style: TextStyle(fontSize: 12, color: titleTextColor),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${orderProvider.restockLogs.length} Total Logs',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (orderProvider.restockLogs.isEmpty)
              Container(
                padding: const EdgeInsets.all(48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 52,
                      color: const Color(0xFF64748B).withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No restock history logged yet.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: valueTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Click "Restock Slim" or "Restock Round" above. Whenever you add containers, they will appear here automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: titleTextColor),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orderProvider.restockLogs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final log = orderProvider.restockLogs[index];
                  final itemName = log['itemName'] ?? 'Container';
                  final amount = (log['amount'] as num?)?.toInt() ?? 0;
                  final prev = (log['previousStock'] as num?)?.toInt() ?? 0;
                  final newStk = (log['newStock'] as num?)?.toInt() ?? 0;
                  final unit = log['unit'] ?? 'Units';
                  final by = log['restockedBy'] ?? 'Admin';
                  final notes = log['notes'] ?? '';
                  final DateTime? ts = log['timestamp'] as DateTime?;
                  final dateStr = ts != null
                      ? '${ts.month}/${ts.day}/${ts.year} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
                      : 'Just now';

                  final isReturn = log['id'].toString().startsWith('return');

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isReturn
                            ? Colors.blue.withValues(alpha: 0.3)
                            : Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: (isReturn ? Colors.blue : Colors.green)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isReturn
                                ? Icons.assignment_return_rounded
                                : Icons.add_shopping_cart_rounded,
                            color: isReturn ? Colors.blue : Colors.green,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    itemName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: valueTextColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (isReturn
                                                  ? Colors.blue
                                                  : Colors.green)
                                              .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '+$amount $unit',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isReturn
                                            ? Colors.blue
                                            : Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Stock Change: $prev $unit ➔ $newStk $unit Available',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: titleTextColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'By: $by • Notes: $notes',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: (isReturn ? Colors.blue : Colors.green)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isReturn ? 'Return Restock' : 'Admin Restock',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isReturn ? Colors.blue : Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildInventoryCategoryFilterChip(
    String filterValue,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _inventoryCategoryFilter == filterValue;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _inventoryCategoryFilter = filterValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
