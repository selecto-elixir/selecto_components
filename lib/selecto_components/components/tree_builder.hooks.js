export default {
  draggedElement: null,

  mounted() {
    console.log('TreeBuilder hook mounted');
    const hook = this;

    this.el.addEventListener('dragstart', (e) => {
      if (e.target.getAttribute('draggable') === 'true') {
        hook.draggedElement = e.target.getAttribute('data-item-id') || e.target.id;
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/plain', hook.draggedElement);
        e.target.style.opacity = '0.5';
      }
    });

    this.el.addEventListener('dragend', (e) => {
      if (e.target.getAttribute('draggable') === 'true') {
        e.target.style.opacity = '';
      }
    });

    this.el.addEventListener('dblclick', (e) => {
      if (e.target.getAttribute('draggable') === 'true') {
        const elementId = e.target.getAttribute('data-item-id') || e.target.id;
        hook.pushEvent('treedrop', {
          target: 'filters',
          element: elementId
        });
      }
    });

    this.el.addEventListener('dragover', (e) => {
      const dropZone = e.target.closest('.drop-zone');
      if (dropZone) {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        dropZone.classList.add('bg-base-200');
      }
    });

    this.el.addEventListener('dragleave', (e) => {
      const dropZone = e.target.closest('.drop-zone');
      if (dropZone && !dropZone.contains(e.relatedTarget)) {
        dropZone.classList.remove('bg-base-200');
      }
    });

    this.el.addEventListener('drop', (e) => {
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
    });
  },

  destroyed() {
    console.log('TreeBuilder hook destroyed');
    this.draggedElement = null;
  }
};
