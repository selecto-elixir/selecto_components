# Denormalization Prevention Feature Plan

## Overview
Implement automatic denormalization prevention in Detail view by detecting when selected columns would cause row multiplication and converting them to subselects with nested table display.

## Implementation Plan

### 1. Add 'Prevent Denormalization' Checkbox
- **Location**: Detail view form UI
- **Default**: Checked by default
- **Storage**: Store preference in `view_config`
- **Implementation Files**:
  - `lib/selecto_components/views/detail/form.ex` - Add checkbox UI
  - Update view_config structure to include `prevent_denormalization` flag

### 2. Implement Denormalization Detection Logic
- **New Module**: `lib/selecto_components/denormalization_detector.ex`
- **Detection Criteria**:
  - One-to-many relationships (e.g., film → actors)
  - Many-to-many relationships (e.g., film → categories)
  - Multiple rows would be returned for single entity
- **Functions**:
  - `detect_denormalizing_columns/2` - Identify columns that would cause denormalization
  - `group_columns_by_relationship/2` - Group columns by their join path
  - `is_denormalizing_join?/2` - Check if a join would multiply rows

### 3. Generate Subselects for Denormalizing Columns
- **New Module**: `lib/selecto_components/subselect_builder.ex`
- **Functionality**:
  - For each denormalizing relationship group:
    - Create subselect query using `Selecto.subselect/3`
    - Include only columns from that relationship
    - Return as JSON aggregation or array format
  - Main query includes only non-denormalizing columns
- **Key Functions**:
  - `build_subselects/3` - Generate subselect queries for denormalizing columns
  - `separate_columns/2` - Split columns into main query vs subselects
  - `format_subselect_results/2` - Format subselect for proper aggregation

### 4. Render Nested Tables for Subselect Results
- **New Component**: `lib/selecto_components/components/nested_table.ex`
- **Features**:
  - Parse subselect results (JSON/array data)
  - Create expandable/collapsible nested table sections
  - Maintain column headers and formatting
  - Support multiple nested tables per row
- **UI Elements**:
  - Expand/collapse toggle for each nested section
  - Clear visual hierarchy (indentation, borders)
  - Column headers for nested data

### 5. Maintain Pivot Compatibility
- **Ensure Compatibility**:
  - Subselects work with pivot operations
  - Handle pivoted subselect results appropriately
  - Test pivot + subselect combinations
- **Implementation**:
  - Update pivot logic to recognize subselect columns
  - Ensure proper aggregation when pivoting with subselects

### 6. Add SQL Debug Display (Dev Mode Only)
- **New Component**: `lib/selecto_components/components/sql_debug.ex`
- **Features**:
  - Collapsible section between form and results
  - Display prettified SQL with syntax highlighting
  - Show query parameters separately
  - Copy-to-clipboard functionality
  - Only visible when `Mix.env() == :dev`
- **Implementation Details**:
  - Use Elixir's SQL formatting libraries or custom prettifier
  - Syntax highlighting using CSS classes
  - Alpine.js for collapse/expand functionality

### 7. Files to Modify/Create

#### New Files:
- `lib/selecto_components/denormalization_detector.ex`
- `lib/selecto_components/subselect_builder.ex`
- `lib/selecto_components/components/nested_table.ex`
- `lib/selecto_components/components/sql_debug.ex`

#### Modified Files:
- `lib/selecto_components/views/detail/form.ex` - Add checkbox and integration
- `lib/selecto_components/form.ex` - Handle denormalization prevention logic
- `lib/selecto_components/ui.ex` - Add SQL debug display
- `vendor/selecto/lib/selecto/builder.ex` - Enhance subselect support if needed

### 8. Testing Scenarios

#### Basic Scenarios:
- Single one-to-many relationship (e.g., Film → Actors)
- Multiple one-to-many relationships (e.g., Film → Actors, Film → Inventory)
- Many-to-many relationships (e.g., Film → Categories)
- Mixed relationships in single query

#### Advanced Scenarios:
- Pivot with subselects
- Nested relationships (e.g., Film → Actor → Actor Films)
- Performance with large datasets
- Toggle prevention on/off and verify behavior

#### Edge Cases:
- No denormalizing columns selected
- All columns would denormalize
- Circular relationships
- Self-referential joins

## Implementation Steps

1. **Phase 1**: Detection and UI
   - Add checkbox to Detail view form
   - Implement denormalization detection logic
   - Add SQL debug display component

2. **Phase 2**: Subselect Generation
   - Create subselect builder module
   - Integrate with existing query builder
   - Handle column separation logic

3. **Phase 3**: Display and Rendering
   - Implement nested table component
   - Update result rendering logic
   - Add expand/collapse functionality

4. **Phase 4**: Testing and Refinement
   - Test all scenarios
   - Optimize performance
   - Handle edge cases
   - Document the feature

## Success Criteria

- [ ] Checkbox appears in Detail view and toggles feature
- [ ] Denormalizing columns are automatically detected
- [ ] Subselects are generated for denormalizing relationships
- [ ] Nested tables display subselect results correctly
- [ ] Feature works with pivot operations
- [ ] SQL debug display shows in dev mode only
- [ ] No performance degradation for normal queries
- [ ] All test scenarios pass

## Notes

- This feature should be transparent to users - they select columns normally and the system handles denormalization prevention automatically
- Performance impact should be minimal for queries that don't need denormalization prevention
- The feature should gracefully degrade if issues occur (fallback to normal behavior)
- Consider caching detection results for repeated queries with same column sets