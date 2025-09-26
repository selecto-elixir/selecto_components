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
  },

  destroyed() {
    if (this.handleMouseDown) {
      this.el.removeEventListener('mousedown', this.handleMouseDown);
    }
  }
};

export default {
  ColumnResize
};