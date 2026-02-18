export default {
  draggedElement: null,

  mounted() {
    const hook = this;

    this.onDragStart = (e) => {
      if (e.target.getAttribute('draggable') === 'true') {
        hook.draggedElement = e.target.getAttribute('data-item-id') || e.target.id;
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/plain', hook.draggedElement);
        e.target.style.opacity = '0.5';
      }
    };

    this.onDragEnd = (e) => {
      if (e.target.getAttribute('draggable') === 'true') {
        e.target.style.opacity = '';
      }
    };

    this.onDoubleClick = (e) => {
      if (e.target.getAttribute('draggable') === 'true') {
        const elementId = e.target.getAttribute('data-item-id') || e.target.id;
        hook.pushEvent('treedrop', {
          target: 'filters',
          element: elementId
        });
      }
    };

    this.onDragOver = (e) => {
      const dropZone = e.target.closest('.drop-zone');
      if (dropZone) {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        dropZone.classList.add('bg-base-200');
      }
    };

    this.onDragLeave = (e) => {
      const dropZone = e.target.closest('.drop-zone');
      if (dropZone && !dropZone.contains(e.relatedTarget)) {
        dropZone.classList.remove('bg-base-200');
      }
    };

    this.onDrop = (e) => {
      const dropZone = e.target.closest('.drop-zone');
      if (dropZone) {
        e.preventDefault();
        e.stopPropagation();
        dropZone.classList.remove('bg-base-200');

        const draggedId = e.dataTransfer.getData('text/plain') || hook.draggedElement;
        const targetId = dropZone.getAttribute('data-drop-zone') || dropZone.id;

        if (draggedId && targetId) {
          hook.pushEvent('treedrop', {
            target: targetId,
            element: draggedId
          });
        }
        hook.draggedElement = null;
      }
    };

    this.el.addEventListener('dragstart', this.onDragStart);
    this.el.addEventListener('dragend', this.onDragEnd);
    this.el.addEventListener('dblclick', this.onDoubleClick);
    this.el.addEventListener('dragover', this.onDragOver);
    this.el.addEventListener('dragleave', this.onDragLeave);
    this.el.addEventListener('drop', this.onDrop);
  },

  destroyed() {
    this.el.removeEventListener('dragstart', this.onDragStart);
    this.el.removeEventListener('dragend', this.onDragEnd);
    this.el.removeEventListener('dblclick', this.onDoubleClick);
    this.el.removeEventListener('dragover', this.onDragOver);
    this.el.removeEventListener('dragleave', this.onDragLeave);
    this.el.removeEventListener('drop', this.onDrop);
    this.draggedElement = null;
  }
};
