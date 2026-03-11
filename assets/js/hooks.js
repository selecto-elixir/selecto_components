// Phoenix LiveView hooks for SelectoComponents
// These hooks are for components that cannot use colocated hooks (e.g., function components)

export const ColumnResize = {
  mounted() {
    const columnId = this.el.dataset.columnId;
    let startX = 0;
    let startWidth = 0;
    let currentTable = null;
    let currentColumn = null;

    const handleMouseDown = (e) => {
      e.preventDefault();
      e.stopPropagation();

      currentTable = this.el.closest('table');
      if (!currentTable) return;

      // Find the column header
      currentColumn = currentTable.querySelector(`th[data-column-id="${columnId}"]`) ||
                     this.el.closest('th');

      if (!currentColumn) return;

      startX = e.pageX;
      startWidth = currentColumn.offsetWidth;

      document.body.style.cursor = 'col-resize';
      document.body.style.userSelect = 'none';

      // Add active state
      this.el.classList.add('bg-blue-500');

      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleMouseUp);
    };

    const handleMouseMove = (e) => {
      if (!currentColumn) return;

      const diff = e.pageX - startX;
      const newWidth = Math.max(50, Math.min(500, startWidth + diff));

      currentColumn.style.width = `${newWidth}px`;
      currentColumn.style.minWidth = `${newWidth}px`;
      currentColumn.style.maxWidth = `${newWidth}px`;

      // Update all cells in this column
      const columnIndex = Array.from(currentColumn.parentElement.children).indexOf(currentColumn);
      const rows = currentTable.querySelectorAll('tbody tr');
      rows.forEach(row => {
        const cell = row.children[columnIndex];
        if (cell) {
          cell.style.width = `${newWidth}px`;
          cell.style.minWidth = `${newWidth}px`;
          cell.style.maxWidth = `${newWidth}px`;
        }
      });
    };

    const handleMouseUp = (e) => {
      if (currentColumn) {
        const newWidth = currentColumn.offsetWidth;

        // Send the new width to the server
        this.pushEvent('column_resized', {
          column_id: columnId,
          width: newWidth
        });
      }

      // Reset
      document.body.style.cursor = '';
      document.body.style.userSelect = '';
      this.el.classList.remove('bg-blue-500');

      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);

      currentColumn = null;
      currentTable = null;
    };

    this.el.addEventListener('mousedown', handleMouseDown);

    // Store for cleanup
    this.handleMouseDown = handleMouseDown;
    this.handleMouseMove = handleMouseMove;
    this.handleMouseUp = handleMouseUp;
  },

  destroyed() {
    if (this.handleMouseMove) {
      document.removeEventListener('mousemove', this.handleMouseMove);
    }
    if (this.handleMouseUp) {
      document.removeEventListener('mouseup', this.handleMouseUp);
    }
    if (this.handleMouseDown) {
      this.el.removeEventListener('mousedown', this.handleMouseDown);
    }
    document.body.style.cursor = '';
    document.body.style.userSelect = '';
  }
};

export const ListPickerSortable = {
  mounted() {
    this.draggedItemId = null;

    const reorderButtonId = this.el.dataset.reorderButtonId;
    const reorderButton = reorderButtonId ? document.getElementById(reorderButtonId) : null;

    const itemElements = () => Array.from(this.el.querySelectorAll('[data-picker-item-id]'));

    const clearDropIndicators = () => {
      itemElements().forEach((item) => {
        item.classList.remove('ring-2', 'ring-primary/40');
      });
    };

    const bindItem = (item) => {
      if (item.dataset.sortableBound === 'true') {
        return;
      }

      item.dataset.sortableBound = 'true';

      item.addEventListener('dragstart', (event) => {
        this.draggedItemId = item.dataset.pickerItemId;
        item.classList.add('opacity-60');

        if (event.dataTransfer) {
          event.dataTransfer.effectAllowed = 'move';
          event.dataTransfer.setData('text/plain', this.draggedItemId || '');
        }
      });

      item.addEventListener('dragend', () => {
        item.classList.remove('opacity-60');
        clearDropIndicators();
      });

      item.addEventListener('dragover', (event) => {
        if (!this.draggedItemId || this.draggedItemId === item.dataset.pickerItemId) {
          return;
        }

        event.preventDefault();
        clearDropIndicators();
        item.classList.add('ring-2', 'ring-primary/40');
      });

      item.addEventListener('dragleave', () => {
        item.classList.remove('ring-2', 'ring-primary/40');
      });

      item.addEventListener('drop', (event) => {
        event.preventDefault();

        const targetItemId = item.dataset.pickerItemId;

        clearDropIndicators();

        if (!this.draggedItemId || !targetItemId || this.draggedItemId === targetItemId || !reorderButton) {
          return;
        }

        reorderButton.setAttribute('phx-value-item', this.draggedItemId);
        reorderButton.setAttribute('phx-value-target-item', targetItemId);
        reorderButton.click();
      });
    };

    this.bindItems = () => {
      itemElements().forEach(bindItem);
    };

    this.bindItems();
  },

  updated() {
    if (this.bindItems) {
      this.bindItems();
    }
  }
};

export default {
  ColumnResize,
  ListPickerSortable
};
