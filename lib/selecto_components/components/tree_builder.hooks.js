export default {
  mounted() {
    console.log('TreeBuilder hook mounted');
    this.setupDragAndDrop();
    this.setupDoubleClick();
    this.setupFilter();
  },

  destroyed() {
    console.log('TreeBuilder hook destroyed');
    this.cleanup();
  },

  setupDragAndDrop() {
    const el = this.el;
    let draggedElement = null;

    // Handle drag start
    el.addEventListener('dragstart', (e) => {
      if (e.target.draggable) {
        draggedElement = e.target;
        e.dataTransfer.effectAllowed = 'copy';
        e.dataTransfer.setData('text/html', e.target.innerHTML);
        e.dataTransfer.setData('item-id', e.target.dataset.itemId);
        e.target.classList.add('opacity-50');
      }
    });

    // Handle drag end
    el.addEventListener('dragend', (e) => {
      if (e.target.draggable) {
        e.target.classList.remove('opacity-50');
      }
    });

    // Handle drag over
    el.addEventListener('dragover', (e) => {
      if (e.target.closest('.drop-zone')) {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'copy';
        e.target.closest('.drop-zone').classList.add('bg-base-200');
      }
    });

    // Handle drag leave
    el.addEventListener('dragleave', (e) => {
      if (e.target.closest('.drop-zone')) {
        e.target.closest('.drop-zone').classList.remove('bg-base-200');
      }
    });

    // Handle drop
    el.addEventListener('drop', (e) => {
      const dropZone = e.target.closest('.drop-zone');
      if (dropZone) {
        e.preventDefault();
        dropZone.classList.remove('bg-base-200');
        
        const itemId = e.dataTransfer.getData('item-id');
        const dropZoneId = dropZone.dataset.dropZone;
        
        // Send event to LiveView
        this.pushEvent('tree_builder_drop', {
          item_id: itemId,
          drop_zone: dropZoneId,
          target_id: dropZone.id
        });
      }
    });
  },

  setupDoubleClick() {
    const el = this.el;
    
    el.addEventListener('dblclick', (e) => {
      const item = e.target.closest('.filterable-item');
      if (item) {
        const itemId = item.dataset.itemId;
        
        // Send event to LiveView
        this.pushEvent('tree_builder_add', {
          item_id: itemId
        });
      }
    });
  },

  setupFilter() {
    const filterInput = this.el.querySelector('#filter-input');
    const clearButton = this.el.querySelector('#clear-filter');
    const availableItems = this.el.querySelector('#available-items');
    
    if (!filterInput || !availableItems) return;

    filterInput.addEventListener('input', (e) => {
      const filterText = e.target.value.toLowerCase();
      const items = availableItems.querySelectorAll('.filterable-item');
      
      if (filterText) {
        clearButton.classList.remove('hidden');
      } else {
        clearButton.classList.add('hidden');
      }
      
      items.forEach(item => {
        const text = item.textContent.toLowerCase();
        if (text.includes(filterText) || filterText === '') {
          item.style.display = '';
        } else {
          item.style.display = 'none';
        }
      });
    });

    clearButton.addEventListener('click', () => {
      filterInput.value = '';
      filterInput.dispatchEvent(new Event('input'));
    });
  },

  cleanup() {
    // Clean up any event listeners if needed
  }
};