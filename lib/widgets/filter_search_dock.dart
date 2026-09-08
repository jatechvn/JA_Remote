import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'glass_widgets.dart';

/// A search field + filter pills and optional droplist for long lists,
/// styled to match the glass design system. Use above a grid/list view (e.g. a device
/// list, a project list) to let the user narrow results.
class FilterSearchDock extends StatelessWidget {
  const FilterSearchDock({
    super.key,
    required this.colors,
    required this.filters,
    required this.selectedFilter,
    required this.onFilterSelected,
    this.searchController,
    this.onSearchChanged,
    this.searchHint = 'Search…',
    this.dropdownItems,
    this.selectedDropdownValue,
    this.onDropdownChanged,
    this.dropdownHint = 'Bộ lọc danh sách…',
  });

  final AppColors colors;
  final List<String> filters;
  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final String searchHint;
  final List<GlassDropdownItem<String>>? dropdownItems;
  final String? selectedDropdownValue;
  final ValueChanged<String>? onDropdownChanged;
  final String dropdownHint;

  @override
  Widget build(BuildContext context) {
    final hasDropdown =
        dropdownItems != null &&
        dropdownItems!.isNotEmpty &&
        onDropdownChanged != null;

    return GlassContainer(
      colors: colors,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: colors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: searchHint,
                    hintStyle: TextStyle(color: colors.textMuted),
                  ),
                ),
              ),
              if (hasDropdown) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 190,
                  child: GlassDropdown<String>(
                    colors: colors,
                    items: dropdownItems!,
                    value: selectedDropdownValue,
                    hintText: dropdownHint,
                    onChanged: onDropdownChanged!,
                    borderRadius: 10,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (filters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(color: colors.subCardBorder, height: 1),
            const SizedBox(height: 8),
            filters.length > 5
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: filters.map((f) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _buildFilterPill(f),
                        );
                      }).toList(),
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: filters.map(_buildFilterPill).toList(),
                  ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterPill(String f) {
    final isSelected = f == selectedFilter;
    return GestureDetector(
      onTap: () => onFilterSelected(f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentColor : colors.subCardBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? Colors.transparent : colors.subCardBorder,
          ),
        ),
        child: Text(
          f,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
