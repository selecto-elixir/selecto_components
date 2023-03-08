// Requires window.initScheme() and window.toggleScheme() functions defined (see `color_scheme_switch.ex`)
const PushEventHook = {
    mounted() {
      window.PushEventHook = this
    },
    destroyed() {
      window.PushEventHook = null
    }
  
  };
  
export default { PushEventHook };
  